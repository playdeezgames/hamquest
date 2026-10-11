#!/usr/bin/env python3
"""Generate odin/content/*_gen.odin from the original HamQuest XML config and .cqm maps (D2).

Usage:
  tools/gen_content.py            write the generated files
  tools/gen_content.py --check    fail if the generated files are stale (no writes)

Strict by design (A4): every property of every entity must be consumed by the schema below or
be listed in IGNORED with a reason; required fields must be present; every cross reference
must resolve; every image must exist. Anything else is an error, never a silent default.
"""
import os
import re
import sys
import json

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hqxml  # noqa: E402
import atlas_layout  # noqa: E402

ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, 'HamQuestSLClient')       # canonical data (see CLAUDE.md)
OUT = os.path.join(ROOT, 'odin', 'content')

MAP_COLS = MAP_ROWS = 15

errors = []


def err(msg):
    errors.append(msg)


# Properties present in the data that the C# engine never reads. They are dropped on purpose.
IGNORED = {
    'item': {
        'defendRoll': 'legacy: never read (C# only uses a local variable of this name)',
        'defendValue': 'legacy: never read',
        'woundsHealed': 'legacy: never read',
        'stolenMessage': 'legacy: never read',
    },
    'creature': {
        'itemRemoves': 'legacy: constant exists, nothing reads it',
        'attack-roll': 'legacy: never read (attack uses attack + attack-die)',
    },
}

IMAGE_FIXES = {
    'images/map/items/armor/boots.png': 'images/map/items/armors/boots.png',  # tutorial image: wrong folder in XML
}

# Data bugs fixed in the port (D1). (entity kind, identifier, property): (old, new, reason)
DATA_FIXES = {
    ('item', 'Tools', 'price'): (
        0, 50,
        'sold by the TorchShop with price 0 (free in the original, where all shopping was free); '
        'D11 charges prices, so it needs one. 50 is a D7 balance choice, revisit when tuning'),
    ('creature', 'minotaur', 'defend-generator'): (
        4, 'white-die-4',
        'XML held the integer 4 instead of a generator name; the C# looked up a null key and '
        'would crash on the first hit against a minotaur'),
}


# Messages the C# engine asks for but messages.xml never defined: the original showed the raw
# identifier (e.g. "NeedRainbowKey") in the message log. The port supplies real text (D1).
EXTRA_MESSAGES = {
    'PickUpPlatemail': 'You have picked up a suit of platemail.',
    'PickUpClothes': 'You have picked up some clothes.',
    'BrokenClothes': 'Your clothes have fallen to rags.',
    'PickUpSapphires': 'You have picked up a small bundle of sapphires.',
    'PickUpRubies': 'You have picked up a small bundle of rubies.',
    'PickUpEmeralds': 'You have picked up a small bundle of emeralds.',
    'PickUpDiamonds': 'You have picked up a small bundle of diamonds.',
    'PickUpChest': 'You have opened a chest.',
    'KilledByDartTrap': 'You have been killed by a dart trap.',
    'KilledByArrowTrap': 'You have been killed by an arrow trap.',
    'DisarmBladeTrap': "You use a set of thieves' tools to disarm the blade trap.",
    'PickUpQuest': 'You have picked up a piece of the Megaham!',
    'PickUpExit': 'You have found the exit.',
    'PickUpPortal': 'You have stepped into a portal.',
    'PickUpCompass': 'You have picked up a compass.',
    'KilledByPoisonHam': 'A poison ham killed you.',
    'GoOutLantern': 'Your lantern has gone out.',
    'GoOutMagicLantern': 'Your magic lantern has gone out.',
    'CannotExitWithAmulet': 'You cannot leave while carrying the Amulet of Yendor.',
    'NeedRainbowKey': 'You need the rainbow key to leave!',
}

# Typos / copy-paste errors in the original message text (D1). identifier: (old, new)
MESSAGE_TEXT_FIXES = {
    'PickUpLantern': ('You have picked up a torch.', 'You have picked up a lantern.'),
    'PickUpRainbowKey': ('You have picked up the raindbow key.', 'You have picked up the rainbow key.'),
}

# ---------------------------------------------------------------- naming helpers

def pascal(s):
    parts = re.split(r'[^A-Za-z0-9]+', s)
    out = ''.join(p[:1].upper() + p[1:] for p in parts if p)
    if not out or out[0].isdigit():
        out = 'N' + out
    return out


def odin_str(s):
    r = s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')
    return '"' + r + '"'


def odin_float(f):
    s = repr(float(f))
    return s


class Ent:
    """An entity's resolved properties with consumption tracking."""

    def __init__(self, kind, ident, props, typed_node_type=None):
        self.kind = kind
        self.ident = ident
        self.props = props
        self.used = set()
        self.node_type = typed_node_type

    def has(self, name):
        return name in self.props

    def raw(self, name):
        if name not in self.props:
            return None
        self.used.add(name)
        v = self.props[name][0]
        fix = DATA_FIXES.get((self.kind, self.ident, name))
        if fix and v == fix[0]:
            v = fix[1]
        return v

    def _where(self, name):
        return '%s %s.%s' % (self.kind, self.ident, name)

    def req(self, name):
        if name not in self.props:
            err('%s %s: missing required property %s' % (self.kind, self.ident, name))
            return None
        return self.raw(name)

    def int_(self, name, default=0, required=False):
        if name not in self.props:
            if required:
                err('%s: missing required %s' % (self._where(name), name))
            return default
        v = self.raw(name)
        if isinstance(v, bool) or not isinstance(v, int):
            err('%s: expected int, got %r' % (self._where(name), v))
            return default
        return v

    def float_(self, name, default=0.0, required=False):
        if name not in self.props:
            if required:
                err('%s: missing required %s' % (self._where(name), name))
            return default
        v = self.raw(name)
        if isinstance(v, bool) or not isinstance(v, (int, float)):
            err('%s: expected number, got %r' % (self._where(name), v))
            return default
        return float(v)

    def bool_(self, name, default=False, required=False):
        if name not in self.props:
            if required:
                err('%s: missing required %s' % (self._where(name), name))
            return default
        v = self.raw(name)
        if not isinstance(v, bool):
            err('%s: expected bool, got %r' % (self._where(name), v))
            return default
        return v

    def str_(self, name, default='', required=False):
        if name not in self.props:
            if required:
                err('%s: missing required %s' % (self._where(name), name))
            return default
        v = self.raw(name)
        if not isinstance(v, str):
            err('%s: expected string, got %r' % (self._where(name), v))
            return default
        return v

    def typed(self, name, type_names, required=False):
        if name not in self.props:
            if required:
                err('%s: missing required %s' % (self._where(name), name))
            return None
        v = self.raw(name)
        if not isinstance(v, hqxml.Typed) or v.type_name not in type_names:
            err('%s: expected type %s, got %r' % (self._where(name), type_names, v))
            return None
        return v

    def leftover(self):
        ign = IGNORED.get(self.kind, {})
        for n in self.props:
            if n not in self.used and n not in ign:
                err('%s %s: unknown property %s (from %s)' % (self.kind, self.ident, n, self.props[n][1]))


# ---------------------------------------------------------------- typed value parsing

def parse_weighted(typed, kind, what):
    """IntGenerator / StringGenerator / BoolGenerator -> list of (value, weight)."""
    out = []
    for e in typed.element.findall('entry'):
        v = e.findtext('value')
        w = e.findtext('weight')
        if v is None or w is None or not re.match(r'^\d+$', w.strip()):
            err('%s: bad generator entry in %s' % (what, typed.source))
            continue
        if kind == 'int':
            if not re.match(r'^[+-]?\d+$', v.strip()):
                err('%s: bad int %r' % (what, v))
                continue
            out.append((int(v), int(w)))
        elif kind == 'bool':
            vv = v.strip().lower()
            if vv not in ('true', 'false'):
                err('%s: bad bool %r' % (what, v))
                continue
            out.append((1 if vv == 'true' else 0, int(w)))
        else:
            out.append((v, int(w)))
    if not out:
        err('%s: empty generator in %s' % (what, typed.source))
    return out


def parse_counter(typed, what):
    out = []
    for e in typed.element.findall('entry'):
        v = e.findtext('value')
        c = e.findtext('count')
        if v is None or c is None or not re.match(r'^\d+$', c.strip()):
            err('%s: bad counter entry' % what)
            continue
        out.append((v, int(c)))
    return out


def parse_tags(typed):
    return [t.text for t in typed.element.findall('tag')]


def parse_stat(typed, what):
    t = (typed.element.text or '').strip()
    if typed.type_name == 'PlayerStatisticHolder':
        return 0
    if not re.match(r'^[+-]?\d+$', t):
        err('%s: bad statistic %r' % (what, t))
        return 0
    return int(t)


# ---------------------------------------------------------------- the generator

class Pools:
    def __init__(self):
        self.weights = []   # (value:int, weight:int)
        self.counts = []    # (item_ident, count)
        self.shop = []      # (item_ident, stock, roll, die)
        self.creature_refs = []  # creature identifiers (spawn tables)
        self._wcache = {}

    def add_weights(self, entries):
        # entries: list of (int value or ('ref', kind, ident), weight)
        start = len(self.weights)
        self.weights.extend(entries)
        return (start, len(entries))

    def add_counts(self, entries):
        start = len(self.counts)
        self.counts.extend(entries)
        return (start, len(entries))


def load_all():
    items = hqxml.load_index(os.path.join(SRC, 'config', 'items.xml'), SRC, 'item')
    creatures = hqxml.load_index(os.path.join(SRC, 'config', 'creatures.xml'), SRC, 'creature')
    return items, creatures


def check_unique(label, idents):
    seen = set()
    for i in idents:
        if i in seen:
            err('duplicate %s identifier %s' % (label, i))
        seen.add(i)


def load_messages():
    root = hqxml.load_root(os.path.join(SRC, 'config', 'messages.xml'))
    out = []
    for n in root.findall('message'):
        props, ident = hqxml.load_properties(n, SRC, 'messages.xml')
        out.append(Ent('message', ident, hqxml.resolve(props)))
    return out


def load_terrains():
    root = hqxml.load_root(os.path.join(SRC, 'config', 'terrains.xml'))
    out = []
    for n in root.findall('terrain'):
        props, ident = hqxml.load_properties(n, SRC, 'terrains.xml')
        out.append(Ent('terrain', ident, hqxml.resolve(props)))
    return out


def load_groups():
    root = hqxml.load_root(os.path.join(SRC, 'config', 'propertyGroups.xml'))
    out = {}
    for n in root.findall('property-group'):
        props, ident = hqxml.load_properties(n, SRC, 'propertyGroups.xml')
        out[ident] = hqxml.resolve(props)
    return out


def load_cqm():
    d = os.path.join(SRC, 'maps')
    out = {}
    for f in sorted(os.listdir(d)):
        if not f.endswith('.cqm'):
            continue
        b = open(os.path.join(d, f), 'rb').read()
        if b[0] != MAP_COLS or b[1] != MAP_ROWS or len(b) != 2 + MAP_COLS * MAP_ROWS:
            err('%s: unexpected size %dx%d (%d bytes)' % (f, b[0], b[1], len(b)))
            continue
        out[f[:-4]] = [list(b[2 + r * MAP_COLS: 2 + (r + 1) * MAP_COLS]) for r in range(MAP_ROWS)]
    return out


class Gen:
    def __init__(self):
        self.pools = Pools()
        self.images = {}          # path -> True (ordered): images the config refers to
        self.lights = {}          # light radius masks (not atlas sprites)
        self.all_images = set(atlas_layout.list_images())
        self.items, self.creatures = load_all()
        self.messages = load_messages()
        for mid, text in EXTRA_MESSAGES.items():
            if mid in [m.ident for m in self.messages]:
                err('EXTRA_MESSAGES entry %s already defined in messages.xml' % mid)
            self.messages.append(Ent('message', mid, {'text': (text, 'gen_content.py'), 'text-color': ('default', 'gen_content.py')}))
        for mid, (old, new) in MESSAGE_TEXT_FIXES.items():
            for m in self.messages:
                if m.ident == mid:
                    if m.props['text'][0] != old:
                        err('message %s text fix no longer applies' % mid)
                    m.props['text'] = (new, 'gen_content.py')
        self.terrains = load_terrains()
        self.groups = load_groups()
        self.maps = load_cqm()
        self.item_ids = [e['identifier'] for e in self.items]
        self.creature_ids = [e['identifier'] for e in self.creatures]
        self.message_ids = [m.ident for m in self.messages]
        check_unique('item', self.item_ids)
        check_unique('creature', self.creature_ids)
        check_unique('message', self.message_ids)
        self.gen_ids = []
        self.tags = []
        self.enums = {}           # enum name -> ordered values (without None)

    # -- enums
    def enum(self, name, value):
        lst = self.enums.setdefault(name, [])
        if value not in lst:
            lst.append(value)
        return value

    def image(self, path):
        if path == '':
            return ''
        path = IMAGE_FIXES.get(path, path)
        full = os.path.join(SRC, path)
        if not os.path.isfile(full):
            err('image not found: %s' % path)
        if path.startswith('images/lights/'):
            self.lights.setdefault(path, True)
        elif path not in self.all_images:
            err('image not in the atlas list: %s' % path)
        self.images.setdefault(path, True)
        return path

    def ref_item(self, ident, what):
        if ident == '':
            return None
        if ident not in self.item_ids:
            err('%s: unknown item %r' % (what, ident))
        return ident

    def ref_msg(self, ident, what):
        if ident == '':
            return None
        if ident not in self.message_ids:
            err('%s: unknown message %r' % (what, ident))
        return ident

    # -- generators group
    def build_generators(self):
        g = self.groups['generators']
        out = []
        for name, (v, src) in g.items():
            if not isinstance(v, hqxml.Typed) or v.type_name != 'IntGenerator':
                err('generators.%s: not an IntGenerator' % name)
                continue
            w = parse_weighted(v, 'int', 'generators.' + name)
            out.append((name, self.pools.add_weights([(a, b) for a, b in w])))
        self.gen_ids = [n for n, _ in out]
        self.gen_ranges = dict(out)

    def gen_ref(self, name, what):
        if name == '':
            return None
        if name not in self.gen_ranges:
            err('%s: unknown generator %r' % (what, name))
        return name

    # -- tags
    def tagset(self, ent, name='tags'):
        t = ent.typed(name, ('TagSet',))
        if t is None:
            return []
        tags = parse_tags(t)
        for tag in tags:
            if tag not in self.tags:
                self.tags.append(tag)
        return tags

    # -- items
    def build_items(self):
        defs = []
        for e in self.items:
            ent = Ent('item', e['identifier'], e['props'])
            what = 'item ' + ent.ident
            d = {'ident': ent.ident}
            d['name'] = ent.str_('name', required=True)
            d['item_type'] = self.enum('Item_Type', ent.str_('item-type', required=True))
            d['placement'] = self.enum('Placement', ent.str_('placement', required=True))
            d['image'] = self.image(ent.str_('image-path', required=True))
            d['tags'] = self.tagset(ent)
            d['item_count'] = ent.int_('item-count', required=True)
            d['price'] = ent.int_('price', required=True)
            d['inv_col'] = ent.int_('inventory-column', required=True)
            d['inv_row'] = ent.int_('inventory-row', required=True)
            for field, prop in (('spawn_as', 'spawn-as'),):
                t = ent.typed(prop, ('StringGenerator',), required=True)
                d[field] = [(self.ref_item(v, what + '.' + prop), w) for v, w in parse_weighted(t, 'str', what + '.' + prop)] if t else []
            for field, prop in (('x_gen', 'x-generator'), ('y_gen', 'y-generator'), ('initial_inventory', 'initial-inventory')):
                t = ent.typed(prop, ('IntGenerator',), required=True)
                d[field] = parse_weighted(t, 'int', what + '.' + prop) if t else []
            for field, prop in (('pick_up_msg', 'pick-up-message'), ('bump_msg', 'bump-message'),
                                ('use_msg', 'use-message'), ('broken_msg', 'broken-message'),
                                ('go_out_msg', 'go-out-message'), ('disarm_msg', 'disarm-message'),
                                ('killed_by_msg', 'killed-by-message'), ('item_block_msg', 'item-block-message')):
                d[field] = self.ref_msg(ent.str_(prop), what + '.' + prop)
            d['attack_value'] = ent.int_('attack-value')
            d['durability'] = ent.int_('durability')
            d['duration'] = ent.int_('duration')
            d['light_level'] = ent.int_('light-level')
            li = ent.str_('light-radius-image-path')
            d['light_radius_image'] = self.image(li) if li else ''
            d['two_handed'] = ent.bool_('two-handed')
            at = ent.str_('armor-type')
            d['armor_type'] = self.enum('Armor_Type', at) if at else None
            dg = ent.str_('defend-generator')
            d['defend_gen'] = self.gen_ref(dg, what + '.defend-generator') if dg else None
            d['speed_multiplier'] = ent.float_('speed-multiplier', 1.0)
            ht = ent.str_('healing-type')
            d['healing_type'] = self.enum('Healing_Type', ht) if ht else None
            d['healing_amount'] = ent.int_('healing-amount')
            d['lock_type'] = ent.int_('lockType', -1)
            d['lock_type_weight'] = ent.int_('lock-type-weight')
            d['direction'] = ent.int_('direction', -1)
            u = ent.typed('itemUnlocks', ('StringCounter',))
            d['unlocks'] = [(self.ref_item(v, what + '.itemUnlocks'), c) for v, c in parse_counter(u, what)] if u else []
            u = ent.typed('item-disarms', ('StringCounter',))
            d['disarms'] = [(self.ref_item(v, what + '.item-disarms'), c) for v, c in parse_counter(u, what)] if u else []
            d['item_blocks'] = self.ref_item(ent.str_('item-blocks'), what + '.item-blocks')
            d['min_value'] = ent.int_('minimumValue')
            d['max_value'] = ent.int_('maximumValue')
            t = ent.typed('generated-item', ('StringGenerator',))
            d['generated_item'] = [(self.ref_item(v, what + '.generated-item'), w) for v, w in parse_weighted(t, 'str', what)] if t else []
            d['hidden_item'] = self.ref_item(ent.str_('hidden-item-identifier'), what + '.hidden-item-identifier')
            d['shop_title'] = ent.str_('shop-title')
            inv = ent.typed('inventory', ('ShopInventoryEntry',))
            shop = []
            if inv:
                for en in inv.element:
                    shop.append((self.ref_item(en.findtext('item-identifier') or '', what + '.inventory'),
                                 int(en.findtext('number-in-stock') or 0),
                                 int(en.findtext('number-in-stock-roll') or 0),
                                 int(en.findtext('number-in-stock-die') or 0)))
            d['shop'] = shop
            ent.leftover()
            self.check_item(d)
            defs.append(d)
        return defs

    def check_item(self, d):
        t = d['item_type']
        what = 'item ' + d['ident']
        need = {
            'Door': ['unlocks', 'direction', 'lock_type'],
            'Key': ['lock_type', 'lock_type_weight'],
            'Weapon': ['durability'],
            'Armor': ['armor_type', 'defend_gen', 'durability'],
            'Light': ['light_level', 'light_radius_image'],
            'Treasure': ['max_value'],
            'Healing': ['healing_type', 'healing_amount'],
            'Shop': ['shop_title', 'shop'],
            'Hidden': ['hidden_item'],
            'Trap': ['attack_value', 'disarms'],
            'Chest': ['generated_item'],
        }.get(t, [])
        for f in need:
            v = d[f]
            if v in (None, '', [], -1):
                err('%s (%s): missing required %s' % (what, t, f))

    # -- creatures
    def build_creatures(self):
        defs = []
        player = None
        for e in self.creatures:
            ent = Ent('creature', e['identifier'], e['props'], e['node_type'])
            what = 'creature ' + ent.ident
            is_player = (ent.node_type == 'PlayerDescriptor')
            d = {'ident': ent.ident, 'is_player': is_player}
            d['name'] = ent.str_('name', required=True)
            d['image'] = self.image(ent.str_('image-path', required=True))
            d['tags'] = self.tagset(ent)
            mv = ent.typed('mover', ('PlayerMoveHandler', 'CreatureMoveHandler'), required=True)
            d['mover'] = self.enum('Mover', mv.type_name) if mv else None
            d['attack_die'] = ent.int_('attack-die', required=True)
            d['creature_count'] = ent.int_('creature-count', required=True)
            d['spawn_weight'] = ent.int_('spawn-weight', required=True)
            d['necromancer_weight'] = ent.int_('necromancer-weight', required=True)
            d['summoner_weight'] = ent.int_('summoner-weight', required=True)
            d['number_of_attacks'] = ent.int_('number-of-attacks', required=True)
            d['placement'] = self.enum('Placement', ent.str_('placement', required=True))
            d['special_attack'] = self.enum('Special_Attack', ent.str_('special-attack', required=True))
            for f in ('attack', 'health', 'speed'):
                t = ent.typed(f, ('StatisticHolder', 'PlayerStatisticHolder'), required=True)
                d[f] = parse_stat(t, what + '.' + f) if t else 0
            if is_player:
                ent.typed('defend', ('PlayerStatisticHolder',))
                ent.typed('defend-roller', ('PlayerDefendRoller',), required=True)
                d['defend_roller'] = 'Player'
                d['defend_gen'] = None
            else:
                dr = ent.typed('defend-roller', ('CreatureDefendRoller', 'SimpleRoller'), required=True)
                d['defend_roller'] = 'Creature'
                if dr and dr.type_name == 'SimpleRoller':
                    # SimpleRoller carries the generator name as its element text
                    dg = (dr.element.text or '').strip()
                    if ent.has('defend-generator'):
                        err('%s: SimpleRoller and defend-generator both present' % what)
                else:
                    dg = ent.str_('defend-generator', required=True)
                d['defend_gen'] = self.gen_ref(dg, what + '.defend-roller')
            for field, prop in (('hit_msg', 'hit-message'), ('miss_msg', 'miss-message'), ('kill_msg', 'kill-message'),
                                ('hit_by_msg', 'hit-by-message'), ('missed_by_msg', 'missed-by-message'),
                                ('killed_by_msg', 'killed-by-message'), ('item_block_msg', 'item-block-message')):
                d[field] = self.ref_msg(ent.str_(prop, required=not is_player and field != 'item_block_msg'), what + '.' + prop)
            d['experience_points'] = ent.int_('experience-points', required=not is_player)
            d['item_blocks'] = self.ref_item(ent.str_('item-blocks'), what + '.item-blocks')
            t = ent.typed('morale-roll', ('BoolGenerator',), required=not is_player)
            d['morale'] = parse_weighted(t, 'bool', what + '.morale-roll') if t else []
            t = ent.typed('item-drops', ('StringGenerator',), required=not is_player)
            d['item_drops'] = [(self.ref_item(v, what + '.item-drops'), w) for v, w in parse_weighted(t, 'str', what)] if t else []
            gt = ent.str_('generatorTable')
            if gt:
                if gt not in ('necromancer-weight', 'summoner-weight'):
                    err('%s: unknown generatorTable %r' % (what, gt))
                d['generator_table'] = gt
            else:
                d['generator_table'] = None
            if d['special_attack'] == 'Generator' and not gt:
                err('%s: Generator special attack without generatorTable' % what)
            if is_player:
                player = self.build_player(ent, what)
            else:
                ent.leftover() if False else None
            defs.append((d, ent))
        # player-specific props are consumed in build_player; then leftovers for all
        for d, ent in defs:
            ent.leftover()
        return [d for d, _ in defs], player

    def build_player(self, ent, what):
        p = {}
        for f, prop in (('initial_health', 'initial-health'), ('health_per_level', 'health-per-experience-level'),
                        ('initial_xp', 'initial-experience-points'), ('initial_xp_goal', 'initial-experience-point-goal'),
                        ('xp_goal_mul', 'experience-goal-multiplier'), ('xp_goal_div', 'experience-goal-divisor'),
                        ('initial_level', 'initial-experience-level')):
            p[f] = ent.int_(prop, required=True)
        if p.get('xp_goal_div') == 0:
            err('%s: experience-goal-divisor is 0' % what)
        t = ent.typed('speed-roll', ('IntGenerator',), required=True)
        p['speed_roll'] = parse_weighted(t, 'int', what + '.speed-roll') if t else []
        p['quest_item'] = self.ref_item(ent.str_('quest-item-name', required=True), what + '.quest-item-name')
        for f, prop in (('gain_xp_point_msg', 'gain-experience-point-message'),
                        ('gain_xp_points_msg', 'gain-experience-points-message'),
                        ('gain_level_msg', 'gain-experience-level-message'),
                        ('killed_msg', 'killed-message'), ('rest_msg', 'rest-message'),
                        ('cannot_rest_msg', 'cannot-rest-message'),
                        ('cannot_exit_amulet_msg', 'cannot-exit-with-amulet-message'),
                        ('need_rainbow_msg', 'need-rainbow-key-message'),
                        ('need_megaham_msg', 'need-completed-megaham-message'),
                        ('won_msg', 'won-game-message'), ('quest_completed_msg', 'quest-completed-message'),
                        ('thief_gold_msg', 'thief-took-gold-message'),
                        ('thief_megaham_msg', 'thief-took-megaham-message'),
                        ('ghoul_msg', 'ghoul-drained-energy-message')):
            p[f] = self.ref_msg(ent.str_(prop, required=True), what + '.' + prop)
        pc = ent.typed('player-configuration', ('PlayerConfiguration',), required=True)
        p['config'] = self.enum('Player_Config', (pc.element.text or '').strip()) if pc else None
        self.enum('Player_Config', 'Defend')  # the Tab toggle's other value; not named in the data
        kh = ent.typed('key-handlers', ('TagSet',), required=True)
        handlers = parse_tags(kh) if kh else []
        p['key_handlers'] = handlers
        for h in handlers:
            hv = ent.typed(h, ('AmuletOfYendorKeyHandler', 'PlayerRestKeyHandler'), required=True)
            if hv and hv.type_name == 'AmuletOfYendorKeyHandler':
                p['amulet_item'] = self.ref_item(hv.element.findtext('amulet-item-name') or '', what + '.amulet')
        for n in ('step-tracker', 'message-statistics', 'item-durabilities'):
            ent.typed(n, ('PlayerStepTracker', 'PlayerMessageStatistics', 'StringCounter'))
        return p

    # -- messages / terrains / groups
    def build_messages(self):
        out = []
        for m in self.messages:
            d = {'ident': m.ident}
            d['text'] = m.str_('text', required=True)
            d['color'] = m.str_('text-color', required=True)
            d['sound'] = m.str_('sound-effect')
            d['always_tutorial'] = m.has('always-tutorial')
            if d['always_tutorial']:
                m.raw('always-tutorial')
            d['tutorial_image'] = self.image(m.str_('tutorial-image-path')) if m.has('tutorial-image-path') else ''
            d['tutorial_title'] = m.str_('tutorial-title-text')
            d['tutorial_text'] = m.str_('tutorial-description-text')
            if d['sound']:
                self.enum('Sound_Effect', d['sound'])
            m.leftover()
            out.append(d)
        return out

    def build_terrains(self):
        out = []
        seen = set()
        for t in self.terrains:
            d = {'id': t.ident}
            if not re.match(r'^\d+$', t.ident) or int(t.ident) > 254:
                err('terrain id %r is not a byte below 255' % t.ident)
                continue
            if t.ident in seen:
                err('duplicate terrain %s' % t.ident)
            seen.add(t.ident)
            d['id'] = int(t.ident)
            d['image'] = self.image(t.str_('image-path', required=True))
            d['passable'] = t.bool_('passable', required=True)
            bh = t.typed('bump-handler', ('AlwaysDenyBumpHandler', 'AlwaysAllowBumpHandler', 'PlayerOnlyBumpHandler'), required=True)
            d['bump'] = self.enum('Bump_Handler', bh.type_name.replace('BumpHandler', '')) if bh else None
            d['tags'] = self.tagset(t)
            t.leftover()
            out.append(d)
        return out

    def build_groups(self):
        g = self.groups
        out = {}
        rc = g['roomChance']
        out['room_chance_total'] = rc['total'][0]
        out['room_chance'] = [rc['doorCount%d' % n][0] for n in (1, 2, 3, 4)]
        out['maze'] = (g['mazeDimensions']['columns'][0], g['mazeDimensions']['rows'][0])
        md = (g['mapDimensions']['columns'][0], g['mapDimensions']['rows'][0])
        if md != (MAP_COLS, MAP_ROWS):
            err('mapDimensions %r != cqm size' % (md,))
        out['currency'] = self.ref_item(g['playerConstants']['currency-item-identifier'][0], 'playerConstants.currency')
        at = g['playerConstants']['armor-types'][0]
        out['armor_types'] = [self.enum('Armor_Type', t.text) for t in at.element]
        colors = []
        for name, (v, _) in g['colorTable'].items():
            if name == 'identifier':
                continue
            el = {c.tag: int(c.text) for c in v.element}
            colors.append((self.enum('Text_Color', name), (el['red'], el['green'], el['blue'], el['alpha'])))
        out['colors'] = colors
        return out


# ---------------------------------------------------------------- emission

def emit(gen, items, creatures, player, messages, terrains, groups):
    L = []
    w = L.append
    P = gen.pools
    item_enum = {i: pascal(i) for i in gen.item_ids}
    creature_enum = {i: pascal(i) for i in gen.creature_ids}
    msg_enum = {i: pascal(i) for i in gen.message_ids}
    for label, m in (('item', item_enum), ('creature', creature_enum), ('message', msg_enum)):
        if len(set(m.values())) != len(m):
            err('%s enum names collide after PascalCase' % label)

    def E(enum_name, v):
        return '.None' if v in (None, '') else '.' + pascal(v)

    def item_ref(v):
        return '.None' if v is None else '.' + item_enum[v]

    def msg_ref(v):
        return '.None' if v is None else '.' + msg_enum[v]

    img_names = {}
    all_paths = atlas_layout.list_images()
    for path in all_paths + list(gen.lights):
        stem = re.sub(r'^images/', '', path)
        stem = re.sub(r'\.png$', '', stem)
        img_names[path] = pascal(stem)
    if len(set(img_names.values())) != len(img_names):
        err('image enum names collide')
    light_paths = sorted(gen.lights)

    # weight pools: resolve to ints
    def weights_int(entries):
        return P.add_weights([(v, wt) for v, wt in entries])

    def weights_item(entries):
        return P.add_weights([('item', v, wt) for v, wt in entries])

    pool_w = []  # list of str lines for the final pool
    # Build ranges first (they populate P.weights); emit pool after

    gen_ranges = gen.gen_ranges
    gen_names = {n: pascal(n.replace('-', '_')) for n in gen.gen_ids}
    if len(set(gen_names.values())) != len(gen_names):
        err('generator enum names collide')

    # pool entries are normalised to ints; item refs need enum values: use ordinals (None=0)
    item_ord = {i: n + 1 for n, i in enumerate(gen.item_ids)}

    def norm(entries, kind):
        res = []
        for v, wt in entries:
            if kind == 'item':
                res.append((item_ord[v] if v is not None else 0, wt))
            else:
                res.append((v, wt))
        return res

    def rng(r):
        return 'Range{%d, %d}' % r

    # ---- enums file
    w('// Code generated by tools/gen_content.py from HamQuestSLClient/config and maps. DO NOT EDIT.')
    w('package content')
    w('')
    w('MAP_COLS :: %d' % MAP_COLS)
    w('MAP_ROWS :: %d' % MAP_ROWS)
    w('MAZE_COLS :: %d' % groups['maze'][0])
    w('MAZE_ROWS :: %d' % groups['maze'][1])
    w('')

    def enum_block(name, values, backing='u8'):
        w('%s :: enum %s {' % (name, backing))
        w('\tNone,')
        for v in values:
            if v != 'None':
                w('\t%s,' % v)
        w('}')
        w('')

    enum_block('Item_Kind', [item_enum[i] for i in gen.item_ids], 'u8')
    enum_block('Creature_Kind', [creature_enum[i] for i in gen.creature_ids], 'u8')
    enum_block('Message_Id', [msg_enum[i] for i in gen.message_ids], 'u8')
    enum_block('Generator_Id', [gen_names[n] for n in gen.gen_ids], 'u8')
    enum_block('Image_Id', [img_names[p] for p in all_paths], 'u16')
    enum_block('Light_Radius', [img_names[p] for p in light_paths], 'u8')
    for name in ('Item_Type', 'Placement', 'Armor_Type', 'Healing_Type', 'Special_Attack', 'Mover',
                 'Bump_Handler', 'Text_Color', 'Sound_Effect', 'Player_Config'):
        enum_block(name, [pascal(v) for v in gen.enums.get(name, [])])
    tags = sorted(gen.tags)
    if len(tags) > 64:
        err('more than 64 tags')
    w('Tag :: enum u8 {')
    for t in tags:
        w('\t%s,' % pascal(t))
    w('}')
    w('Tag_Set :: bit_set[Tag; u64]')
    w('')
    w('Spawn_Table :: enum u8 { Spawn, Necromancer, Summoner }')
    w('')

    # ---- tables
    w('IMAGE_PATHS := [Image_Id]string{')
    w('\t.None = "",')
    for p in all_paths:
        w('\t.%s = %s,' % (img_names[p], odin_str(p)))
    w('}')
    w('')

    # generators first so that their ranges are fixed
    w('GENERATORS := [Generator_Id]Range{')
    w('\t.None = {0, 0},')
    for n in gen.gen_ids:
        w('\t.%s = %s,' % (gen_names[n], rng(gen_ranges[n])))
    w('}')
    w('')

    def tag_set(tags_):
        if not tags_:
            return '{}'
        return '{' + ', '.join('.' + pascal(t) for t in tags_) + '}'

    # items
    ranges = {}
    w('ITEMS := [Item_Kind]Item_Def{')
    w('\t.None = {},')
    for d in items:
        spawn = P.add_weights(norm(d['spawn_as'], 'item'))
        xg = P.add_weights(norm(d['x_gen'], 'int'))
        yg = P.add_weights(norm(d['y_gen'], 'int'))
        ii = P.add_weights(norm(d['initial_inventory'], 'int'))
        gi = P.add_weights(norm(d['generated_item'], 'item'))
        un = P.add_counts([(item_ord[v], c) for v, c in d['unlocks']])
        di = P.add_counts([(item_ord[v], c) for v, c in d['disarms']])
        sh_start = len(P.shop)
        for (iid, stock, roll, die) in d['shop']:
            P.shop.append((item_ord[iid], stock, roll, die))
        sh = (sh_start, len(d['shop']))
        w('\t.%s = {' % item_enum[d['ident']])
        w('\t\tname = %s, item_type = %s, placement = %s, image = %s, tags = %s,' % (
            odin_str(d['name']), E('', d['item_type']), E('', d['placement']),
            '.None' if not d['image'] else '.' + img_names[d['image']], tag_set(d['tags'])))
        w('\t\titem_count = %d, price = %d, inventory_col = %d, inventory_row = %d,' % (
            d['item_count'], d['price'], d['inv_col'], d['inv_row']))
        w('\t\tspawn_as = %s, x_gen = %s, y_gen = %s, initial_inventory = %s,' % (rng(spawn), rng(xg), rng(yg), rng(ii)))
        w('\t\tpick_up_msg = %s, bump_msg = %s, use_msg = %s, broken_msg = %s,' % (
            msg_ref(d['pick_up_msg']), msg_ref(d['bump_msg']), msg_ref(d['use_msg']), msg_ref(d['broken_msg'])))
        w('\t\tgo_out_msg = %s, disarm_msg = %s, killed_by_msg = %s, item_block_msg = %s,' % (
            msg_ref(d['go_out_msg']), msg_ref(d['disarm_msg']), msg_ref(d['killed_by_msg']), msg_ref(d['item_block_msg'])))
        w('\t\tattack_value = %d, durability = %d, duration = %d, light_level = %d, light_radius = %s,' % (
            d['attack_value'], d['durability'], d['duration'], d['light_level'],
            '.None' if not d['light_radius_image'] else '.' + img_names[d['light_radius_image']]))
        w('\t\ttwo_handed = %s, armor_type = %s, defend_gen = %s, speed_multiplier = %s,' % (
            'true' if d['two_handed'] else 'false', E('', d['armor_type']),
            '.None' if not d['defend_gen'] else '.' + gen_names[d['defend_gen']], odin_float(d['speed_multiplier'])))
        w('\t\thealing_type = %s, healing_amount = %d, lock_type = %d, lock_type_weight = %d, direction = %d,' % (
            E('', d['healing_type']), d['healing_amount'], d['lock_type'], d['lock_type_weight'], d['direction']))
        w('\t\tunlocks = %s, disarms = %s, item_blocks = %s, min_value = %d, max_value = %d,' % (
            rng(un), rng(di), item_ref(d['item_blocks']), d['min_value'], d['max_value']))
        w('\t\tgenerated_item = %s, hidden_item = %s, shop_title = %s, shop_inventory = %s,' % (
            rng(gi), item_ref(d['hidden_item']), odin_str(d['shop_title']), rng(sh)))
        w('\t},')
    w('}')
    w('')

    # spawn tables (CreatureTable.GetGeneratorTable): creature repeated `weight` times, creature table order
    st = {'Spawn': [], 'Necromancer': [], 'Summoner': []}
    cord = {i: n + 1 for n, i in enumerate(gen.creature_ids)}
    for d in creatures:
        st['Spawn'] += [cord[d['ident']]] * d['spawn_weight']
        st['Necromancer'] += [cord[d['ident']]] * d['necromancer_weight']
        st['Summoner'] += [cord[d['ident']]] * d['summoner_weight']
    spawn_pool = []
    spawn_rng = {}
    for k in ('Spawn', 'Necromancer', 'Summoner'):
        spawn_rng[k] = (len(spawn_pool), len(st[k]))
        spawn_pool += st[k]
        if not st[k]:
            err('spawn table %s is empty' % k)

    w('CREATURES := [Creature_Kind]Creature_Def{')
    w('\t.None = {},')
    for d in creatures:
        mo = P.add_weights(norm(d['morale'], 'int'))
        dr = P.add_weights(norm(d['item_drops'], 'item'))
        gt = {'necromancer-weight': 'Necromancer', 'summoner-weight': 'Summoner', None: 'Spawn'}[d['generator_table']]
        w('\t.%s = {' % creature_enum[d['ident']])
        w('\t\tname = %s, image = .%s, tags = %s, mover = %s, is_player = %s,' % (
            odin_str(d['name']), img_names[d['image']], tag_set(d['tags']), E('', d['mover']),
            'true' if d['is_player'] else 'false'))
        w('\t\tattack = %d, health = %d, speed = %d, attack_die = %d, number_of_attacks = %d, experience_points = %d,' % (
            d['attack'], d['health'], d['speed'], d['attack_die'], d['number_of_attacks'], d['experience_points']))
        w('\t\tdefend_player = %s, defend_gen = %s, morale = %s, item_drops = %s,' % (
            'true' if d['defend_roller'] == 'Player' else 'false',
            '.None' if not d['defend_gen'] else '.' + gen_names[d['defend_gen']], rng(mo), rng(dr)))
        w('\t\tcreature_count = %d, spawn_weight = %d, necromancer_weight = %d, summoner_weight = %d,' % (
            d['creature_count'], d['spawn_weight'], d['necromancer_weight'], d['summoner_weight']))
        w('\t\tplacement = %s, special_attack = %s, generator_table = .%s, item_blocks = %s,' % (
            E('', d['placement']), E('', d['special_attack']), gt, item_ref(d['item_blocks'])))
        w('\t\thit_msg = %s, miss_msg = %s, kill_msg = %s, hit_by_msg = %s, missed_by_msg = %s, killed_by_msg = %s, item_block_msg = %s,' % (
            msg_ref(d['hit_msg']), msg_ref(d['miss_msg']), msg_ref(d['kill_msg']), msg_ref(d['hit_by_msg']),
            msg_ref(d['missed_by_msg']), msg_ref(d['killed_by_msg']), msg_ref(d['item_block_msg'])))
        w('\t},')
    w('}')
    w('')

    w('SPAWN_TABLES := [Spawn_Table]Range{')
    for k in ('Spawn', 'Necromancer', 'Summoner'):
        w('\t.%s = %s,' % (k, rng(spawn_rng[k])))
    w('}')
    w('SPAWN_POOL := [%d]Creature_Kind{%s}' % (len(spawn_pool), ', '.join(
        '.' + creature_enum[gen.creature_ids[o - 1]] for o in spawn_pool)))
    w('')

    # player
    sr = P.add_weights(norm(player['speed_roll'], 'int'))
    w('PLAYER := Player_Def{')
    w('\tinitial_health = %d, health_per_level = %d, initial_xp = %d, initial_xp_goal = %d,' % (
        player['initial_health'], player['health_per_level'], player['initial_xp'], player['initial_xp_goal']))
    w('\txp_goal_mul = %d, xp_goal_div = %d, initial_level = %d, speed_roll = %s,' % (
        player['xp_goal_mul'], player['xp_goal_div'], player['initial_level'], rng(sr)))
    w('\tquest_item = %s, amulet_item = %s, currency_item = %s, config = %s,' % (
        item_ref(player['quest_item']), item_ref(player.get('amulet_item')), item_ref(groups['currency']),
        E('', player['config'])))
    for f in ('gain_xp_point_msg', 'gain_xp_points_msg', 'gain_level_msg', 'killed_msg', 'rest_msg',
              'cannot_rest_msg', 'cannot_exit_amulet_msg', 'need_rainbow_msg', 'need_megaham_msg', 'won_msg',
              'quest_completed_msg', 'thief_gold_msg', 'thief_megaham_msg', 'ghoul_msg'):
        w('\t%s = %s,' % (f, msg_ref(player[f])))
    w('}')
    w('')
    w('ARMOR_TYPES :: bit_set[Armor_Type; u8]')
    w('PLAYER_ARMOR_TYPES :: ARMOR_TYPES{%s}' % ', '.join('.' + pascal(a) for a in groups['armor_types']))
    w('')

    # messages
    w('MESSAGES := [Message_Id]Message_Def{')
    w('\t.None = {},')
    for m in messages:
        w('\t.%s = {text = %s, color = %s, sound = %s, always_tutorial = %s, tutorial_image = %s, tutorial_title = %s, tutorial_text = %s},' % (
            msg_enum[m['ident']], odin_str(m['text']), E('', m['color']), E('', m['sound']) if m['sound'] else '.None',
            'true' if m['always_tutorial'] else 'false',
            '.None' if not m['tutorial_image'] else '.' + img_names[m['tutorial_image']],
            odin_str(m['tutorial_title']), odin_str(m['tutorial_text'])))
    w('}')
    w('')

    w('COLORS := [Text_Color][4]u8{')
    w('\t.None = {0, 0, 0, 255},')
    for name, rgba in groups['colors']:
        w('\t.%s = {%d, %d, %d, %d},' % (pascal(name), *rgba))
    w('}')
    w('')

    # terrains: byte-indexed
    w('TERRAIN_DEFINED := [256]bool{')
    for t in terrains:
        w('\t%d = true,' % t['id'])
    w('}')
    w('TERRAINS := [256]Terrain_Def{')
    for t in terrains:
        w('\t%d = {passable = %s, bump = %s, image = .%s, tags = %s},' % (
            t['id'], 'true' if t['passable'] else 'false', E('', t['bump']), img_names[t['image']], tag_set(t['tags'])))
    w('}')
    w('')

    # room chance
    w('ROOM_CHANCE_TOTAL :: %d' % groups['room_chance_total'])
    w('ROOM_CHANCE_BY_DOORS := [5]i32{0, %s}' % ', '.join(str(x) for x in groups['room_chance']))
    w('')

    # pools last
    w('WEIGHT_POOL := [%d]Weighted{' % len(P.weights))
    for v, wt in P.weights:
        w('\t{%d, %d},' % (v, wt))
    w('}')
    w('COUNT_POOL := [%d]Item_Count{' % len(P.counts))
    for v, c in P.counts:
        w('\t{.%s, %d},' % (item_enum[gen.item_ids[v - 1]], c))
    w('}')
    w('SHOP_POOL := [%d]Shop_Entry{' % len(P.shop))
    for iid, stock, roll, die in P.shop:
        w('\t{.%s, %d, %d, %d},' % (item_enum[gen.item_ids[iid - 1]], stock, roll, die))
    w('}')
    w('')

    # maps
    def layer(name, rows):
        w('%s := Map_Layer{' % name)
        for r in rows:
            w('\t{%s},' % ', '.join(str(v) for v in r))
        w('}')

    maps = gen.maps
    expect = ['room'] + ['pway%d' % i for i in range(16)] + ['pwaydoor%d' % i for i in range(4)] + \
             ['roomopen%d' % i for i in range(4)] + ['roomdoor%d' % i for i in range(4)]
    for n in expect:
        if n not in maps:
            err('missing map %s' % n)
    for n in maps:
        if n not in expect:
            err('unexpected map %s' % n)
    # every terrain byte used must be defined (255 is transparent in overlays)
    defined = {t['id'] for t in terrains}
    for n, rows in maps.items():
        for r in rows:
            for v in r:
                if v != 255 and v not in defined:
                    err('map %s uses undefined terrain %d' % (n, v))
    w('MAP_ROOM := Map_Layer{')
    for r in maps.get('room', [[0] * MAP_COLS] * MAP_ROWS):
        w('\t{%s},' % ', '.join(str(v) for v in r))
    w('}')
    for label, prefix, count in (('MAP_PWAY', 'pway', 16), ('MAP_PWAY_DOOR', 'pwaydoor', 4),
                                 ('MAP_ROOM_OPEN', 'roomopen', 4), ('MAP_ROOM_DOOR', 'roomdoor', 4)):
        w('%s := [%d]Map_Layer{' % (label, count))
        for i in range(count):
            w('\t{')
            for r in maps.get('%s%d' % (prefix, i), [[0] * MAP_COLS] * MAP_ROWS):
                w('\t\t{%s},' % ', '.join(str(v) for v in r))
            w('\t},')
        w('}')
    return '\n'.join(L) + '\n'


def main():
    check = '--check' in sys.argv
    gen = Gen()
    gen.build_generators()
    items = gen.build_items()
    creatures, player = gen.build_creatures()
    if player is None:
        err('no player creature')
    messages = gen.build_messages()
    terrains = gen.build_terrains()
    groups = gen.build_groups()
    if errors:
        for e in errors:
            print('ERROR:', e)
        print('%d errors' % len(errors))
        return 1
    text = emit(gen, items, creatures, player, messages, terrains, groups)
    if errors:
        for e in errors:
            print('ERROR:', e)
        print('%d errors' % len(errors))
        return 1
    path = os.path.join(OUT, 'content_gen.odin')
    if check:
        cur = open(path, encoding='utf-8').read() if os.path.exists(path) else ''
        if cur != text:
            print('STALE: %s is out of date; run tools/gen_content.py' % os.path.relpath(path, ROOT))
            return 1
        print('content up to date')
        return 0
    os.makedirs(OUT, exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    print('wrote %s: %d items, %d creatures, %d messages, %d terrains, %d generators, %d images, %d tags, %d weights' % (
        os.path.relpath(path, ROOT), len(items), len(creatures), len(messages), len(terrains), len(gen.gen_ids),
        len(gen.images) + len(gen.lights), len(gen.tags), len(gen.pools.weights)))
    for k, (old, new, why) in DATA_FIXES.items():
        print('data fix %s: %r -> %r (%s)' % ('/'.join(k), old, new, why))
    return 0


if __name__ == '__main__':
    sys.exit(main())
