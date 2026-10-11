#!/usr/bin/env python3
"""Build the player's manual: manual/HamQuest-of-SPLORR-Manual.pdf (needs Pillow and google-chrome).

Every number in it (item stats, prices, monster stats) comes from the game's own data through the
content generator, so the manual cannot drift from the game. Figures are drawn from the game's art.
"""
import html
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_content as g  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

ROOT = os.path.dirname(HERE)
IMG = os.path.join(ROOT, 'HamQuestSLClient')
BUILD = os.path.join(ROOT, 'build', 'manual')
OUT_DIR = os.path.join(ROOT, 'manual')
PDF = os.path.join(OUT_DIR, 'HamQuest-of-SPLORR-Manual.pdf')

# ---------------------------------------------------------------- data

G = g.Gen()
G.build_generators()
ITEMS = G.build_items()
CREATURES, PLAYER = G.build_creatures()
if g.errors:
    raise SystemExit('\n'.join(g.errors))
POOL = G.pools.weights
ITEM = {d['ident']: d for d in ITEMS}
CREATURE = {d['ident']: d for d in CREATURES}


def gen_max(name):
    s, c = G.gen_ranges[name]
    return max(v for v, _ in POOL[s:s + c])


def sprite_path(rel):
    return os.path.join(IMG, rel)


def ensure(name):
    os.makedirs(BUILD, exist_ok=True)
    return os.path.join(BUILD, name)


def item_img(ident, px=40):
    d = ITEM[ident]
    return '<img class="sp" style="width:%dpx" src="../../%s">' % (px, 'HamQuestSLClient/' + d['image'])


def creature_img(ident, px=40):
    return '<img class="sp" style="width:%dpx" src="../../%s">' % (px, 'HamQuestSLClient/' + CREATURE[ident]['image'])


def minimap_img(rel, px=40):
    return '<img class="sp" style="width:%dpx" src="../../HamQuestSLClient/images/minimap/%s.png">' % (px, rel)


def esc(s):
    return html.escape(s)


# ---------------------------------------------------------------- figures

def annotated_screen():
    """The in-game screenshot at 2x with numbered markers."""
    src = os.path.join(ROOT, 'assets', 'screenshots', '03-explored.png')
    im = Image.open(src).convert('RGBA')
    im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
    d = ImageDraw.Draw(im)
    marks = {1: (30, 30), 2: (610, 30), 3: (610, 190), 4: (610, 404), 5: (586, 464), 6: (624, 508)}
    for n, (x, y) in marks.items():
        cx, cy, r = x * 2, y * 2, 20
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(200, 0, 0, 255), outline=(255, 255, 255, 255), width=3)
        d.text((cx - 5, cy - 8), str(n), fill=(255, 255, 255, 255), font=None)
    # PIL's default font is tiny: redraw digits larger by pixel scaling
    big = Image.new('RGBA', im.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(big)
    for n, (x, y) in marks.items():
        cx, cy, r = x * 2, y * 2, 20
        bd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(200, 0, 0, 255), outline=(255, 255, 255, 255), width=3)
        digit = Image.new('RGBA', (8, 11), (0, 0, 0, 0))
        ImageDraw.Draw(digit).text((0, 0), str(n), fill=(255, 255, 255, 255))
        digit = digit.resize((24, 33), Image.NEAREST)
        big.alpha_composite(digit, (cx - 9, cy - 14))
    out = ensure('annotated.png')
    Image.alpha_composite(Image.open(src).convert('RGBA').resize(im.size, Image.NEAREST), big).convert('RGB').save(out)
    return 'annotated.png'


def inventory_grid():
    """A 5 by 7 grid with each item at its fixed slot; the column letter and row number name the slot."""
    cell = 72
    pad = 28
    w, h = pad + 5 * cell, pad + 7 * cell
    im = Image.new('RGB', (w, h), (255, 255, 255))
    d = ImageDraw.Draw(im)
    for c in range(5):
        for r in range(7):
            x, y = pad + c * cell, pad + r * cell
            d.rectangle((x, y, x + cell - 1, y + cell - 1), outline=(200, 200, 200))
    def label(x, y, text):
        glyph = Image.new('RGB', (8 * len(text), 11), (255, 255, 255))
        ImageDraw.Draw(glyph).text((0, 0), text, fill=(0, 0, 0))
        glyph = glyph.resize((glyph.width * 2, glyph.height * 2), Image.NEAREST)
        im.paste(glyph, (x, y))
    for c in range(5):
        label(pad + c * cell + cell // 2 - 5, 4, 'ABCDE'[c])
    for r in range(7):
        label(6, pad + r * cell + cell // 2 - 10, str(r + 1))
    for it in ITEMS:
        if it['inv_col'] < 0 or it['inv_row'] < 0:
            continue
        p = sprite_path(it['image'])
        if not os.path.exists(p):
            continue
        s = Image.open(p).convert('RGBA').resize((64, 64), Image.NEAREST)
        x, y = pad + it['inv_col'] * cell + 4, pad + it['inv_row'] * cell + 4
        im.paste(s, (x, y), s)
    out = ensure('inventory.png')
    im.save(out)
    return 'inventory.png'


def compose_minimap(layers, scale=4):
    base = Image.new('RGBA', (20, 20), (128, 128, 128, 255))
    for rel in layers:
        s = Image.open(os.path.join(IMG, 'images', 'minimap', rel + '.png')).convert('RGBA')
        base.alpha_composite(s)
    return base.resize((20 * scale, 20 * scale), Image.NEAREST)


def minimap_examples():
    for color in ('red', 'yellow', 'green', 'cyan', 'blue', 'magenta'):
        compose_minimap(['chamber/base', 'chamber/north', 'doors/%s/north' % color]).save(ensure('door_%s.png' % color))
    items = [
        ('room.png', ['chamber/base', 'chamber/north', 'chamber/east']),
        ('pass.png', ['passageway/base', 'passageway/west', 'passageway/east']),
        ('quest.png', ['quest/base', 'quest/south']),
        ('deadend.png', ['chamber/base', 'chamber/west', 'doors/red/west']),
        ('here.png', ['misc/highlight', 'chamber/base', 'chamber/north']),
        ('mon.png', ['chamber/base', 'chamber/north', 'markers/red']),
    ]
    for name, layers in items:
        compose_minimap(layers).save(ensure(name))
    return [n for n, _ in items]


# ---------------------------------------------------------------- html

CSS = '''
@page { size: A4; margin: 16mm 15mm 18mm 15mm; @bottom-center { content: counter(page); font: 9pt sans-serif; color: #666; } }
@page :first { margin: 0; @bottom-center { content: none; } }
* { box-sizing: border-box; }
body { font: 10.5pt/1.42 "DejaVu Sans", "Liberation Sans", Arial, sans-serif; color: #1c1c1c; }
h1 { font-size: 22pt; margin: 0 0 4mm; color: #0b2a6f; border-bottom: 2px solid #0b2a6f; padding-bottom: 2mm; }
h2 { font-size: 13pt; margin: 4mm 0 1.5mm; color: #0b2a6f; }
h3 { font-size: 11.5pt; margin: 4mm 0 1mm; }
p { margin: 0 0 2mm; }
.page { page-break-after: always; }
.cover { height: 280mm; overflow: hidden; background: #101014; color: #fff; text-align: center; padding-top: 18mm; }
.cover img.c { width: 160mm; image-rendering: pixelated; border: 2px solid #444; }
.cover h1 { color: #ffe88c; border: 0; font-size: 34pt; margin-top: 12mm; }
.cover p { font-size: 13pt; color: #ccc; }
.sp { image-rendering: pixelated; vertical-align: middle; background: #d9dce6; border-radius: 2px; }
table { border-collapse: collapse; width: 100%; margin: 2mm 0 4mm; font-size: 9.5pt; }
th, td { border: 1px solid #c8c8d0; padding: 1.1mm 2mm; text-align: left; vertical-align: middle; }
th { background: #e8ecf8; }
td.i { width: 14mm; text-align: center; }
.fig { text-align: center; margin: 3mm 0; }
.fig img { image-rendering: pixelated; max-width: 100%; border: 1px solid #bbb; }
.cap { font-size: 9pt; color: #555; }
.n { display: inline-block; background: #c80000; color: #fff; border-radius: 50%; width: 5.2mm; height: 5.2mm; text-align: center; line-height: 5.2mm; font-size: 8.5pt; font-weight: bold; }
.box { border: 1px solid #0b2a6f; background: #f1f4fc; padding: 2.5mm 3.5mm; margin: 3mm 0; }
.tip { border-left: 4px solid #c80000; padding-left: 3mm; margin: 2mm 0; }
.cols { display: flex; gap: 6mm; }
.cols > div { flex: 1; }
.mon table { font-size: 8.8pt; }
.mon td { padding: 0.7mm 1.6mm; }
kbd { border: 1px solid #888; border-bottom-width: 2px; border-radius: 3px; padding: 0 1.5mm; background: #f6f6f6; font: 9pt monospace; }
.small { font-size: 9pt; }
'''


def money_note():
    return 'about %d to %d gold' % (ITEM['Gold']['min_value'], ITEM['Gold']['max_value'])


def weapons_table():
    rows = []
    for ident in ('Dagger', 'Shortsword', 'Longsword', 'TwoHandedSword', 'BattleAxe'):
        d = ITEM[ident]
        hands = 'two hands (no shield)' if d['two_handed'] else 'one hand'
        price = ('%d' % d['price']) if d['price'] else 'not sold; found only'
        rows.append('<tr><td class="i">%s</td><td>%s</td><td>%d</td><td>%d</td><td>%s</td><td>%s</td></tr>' % (
            item_img(ident), esc(d['name']), d['attack_value'], d['durability'], hands, price))
    return ('<table><tr><th></th><th>Weapon</th><th>Attack dice</th><th>Lasts (damage dealt)</th><th>Held in</th><th>Price</th></tr>'
            + ''.join(rows) + '</table>')


def armour_table():
    rows = []
    for ident in ('Clothes', 'Helmet', 'Shield', 'Chainmail', 'Platemail', 'Boots'):
        d = ITEM[ident]
        slot = d['armor_type']
        price = ('%d' % d['price']) if d['price'] else 'you start with them'
        if ident == 'Clothes':
            img = '<span class="small">(no icon)</span>'
        else:
            img = item_img(ident)
        sp = d['speed_multiplier']
        spd = {2.0: 'twice as many moves per turn', 1.0: 'no change', 0.75: 'three quarters', 0.5: 'half'}.get(sp, 'x%s' % sp)
        rows.append('<tr><td class="i">%s</td><td>%s</td><td>%s</td><td>up to %d</td><td>%s</td><td>%s</td><td>%s</td></tr>' % (
            img, esc(d['name']), esc(slot), gen_max(d['defend_gen']), spd,
            ('%d' % d['durability']) if d['durability'] else 'never wears out', price))
    return ('<table><tr><th></th><th>Armour</th><th>Slot</th><th>Defence roll</th><th>Speed</th><th>Lasts (damage absorbed)</th><th>Price</th></tr>'
            + ''.join(rows) + '</table>')


def lights_table():
    rows = ['<tr><td class="i"></td><td>match</td><td>dimmest</td><td>never goes out; you always have it</td><td>-</td></tr>']
    for ident in ('Torch', 'Lantern', 'MagicLantern'):
        d = ITEM[ident]
        rows.append('<tr><td class="i">%s</td><td>%s</td><td>level %d</td><td>%d turns each</td><td>%d</td></tr>' % (
            item_img(ident), esc(d['name']), d['light_level'], d['duration'], d['price']))
    return ('<table><tr><th></th><th>Light</th><th>Brightness</th><th>Burns for</th><th>Price</th></tr>' + ''.join(rows) + '</table>')


def monsters_table():
    order = ['skeleton', 'zombie', 'goblin', 'orc', 'mummy', 'fimir', 'ghoul', 'warrior', 'thief', 'gargoyle',
             'portal', 'minotaur', 'necromancer', 'summoner', 'dragon']
    notes = {
        'thief': 'Very fast. Steals gold, and now and then a piece of the MegaHam (which goes back into the maze).',
        'ghoul': 'Drains your experience points when it hits.',
        'portal': 'Teleports you to another room when it hits (the Amulet blocks it).',
        'necromancer': 'Calls more of the dead to fight beside it. Carries the Amulet of Yendor.',
        'summoner': 'Calls monsters to fight beside it. **Carries the Rainbow Key.**',
        'dragon': 'The strongest thing in the maze, and it hits hard.',
        'minotaur': 'Two attacks every time. Carries a battleaxe.',
        'goblin': 'Many of them, and quick. Sometimes drops ham (not always the good kind).',
        'skeleton': 'Plentiful and fragile.',
        'warrior': 'Often guards armour or a good sword.',
        'gargoyle': 'Tough for its size.',
        'mummy': 'Slow but hits hard for its health.',
        'orc': 'Often carries a torch, a shield or a dagger.',
        'fimir': 'Sometimes carries a lantern or chainmail.',
        'zombie': 'Slow.',
    }
    rows = []
    for ident in order:
        c = CREATURE[ident]
        attack = '%d dice' % c['attack']
        if c['number_of_attacks'] > 1:
            attack += ', %d attacks' % c['number_of_attacks']
        note = notes.get(ident, '').replace('**', '')
        rows.append('<tr><td class="i">%s</td><td>%s</td><td>%s</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td><td class="small">%s</td></tr>' % (
            creature_img(ident, 26), esc(c['name']), attack, c['health'], c['speed'], gen_max(c['defend_gen']),
            c['experience_points'], esc(note)))
    return ('<table><tr><th></th><th>Monster</th><th>Attack</th><th>Health</th><th>Speed</th><th>Defence up to</th><th>XP</th><th>Notes</th></tr>'
            + ''.join(rows) + '</table>')


def inventory_legend():
    rows = []
    colname = 'ABCDE'
    desc = {
        'RedKey': 'Opens carnelian (red) doors. Used up when it opens one.',
        'YellowKey': 'Opens citrine (yellow) doors.',
        'GreenKey': 'Opens jade (green) doors.',
        'CyanKey': 'Opens aquamarine (cyan) doors.',
        'BlueKey': 'Opens sapphire (blue) doors.',
        'MagentaKey': 'Opens amethyst (magenta) doors.',
        'RainbowKey': 'Needed at the exit. Carried by the Summoner.',
        'Food': 'Eaten by itself when you are hurt: heals 1 each.',
        'Potion': 'Used by itself when you would die: heals %d.' % ITEM['Potion']['healing_amount'],
        'Antidote': 'Lets you eat a poison ham safely (used up).',
        'Amulet': 'Blocks portals and teleporting monsters, but you cannot leave the maze while you carry it. Press Y to put it down and be carried off.',
        'Tools': 'Disarms a trap you walk onto (used up).',
        'Quest': 'Piece of the MegaHam. You need all %d.' % ITEM['Quest']['item_count'],
        'Compass': 'The Ring of Detection: quest rooms show on your minimap.',
        'Gold': 'Money. Every coin pile you pick up is added to this.',
    }
    for it in sorted(ITEMS, key=lambda d: (d['inv_row'], d['inv_col'])):
        if it['inv_col'] < 0:
            continue
        ident = it['ident']
        text = desc.get(ident)
        if text is None:
            t = it['item_type']
            if t == 'Weapon':
                text = 'Weapon: %d attack dice.' % it['attack_value']
            elif t == 'Armor':
                text = '%s armour.' % it['armor_type']
            elif t == 'Light':
                text = 'Light source.'
            else:
                text = ''
        rows.append('<tr><td>%s%d</td><td class="i">%s</td><td>%s</td><td class="small">%s</td></tr>' % (
            colname[it['inv_col']], it['inv_row'] + 1, item_img(ident, 32), esc(it['name']), esc(text)))
    return '<table><tr><th>Slot</th><th></th><th>Item</th><th>What it does</th></tr>' + ''.join(rows) + '</table>'


def page_html(figs):
    annotated, inv, mm = figs
    shops = []
    for ident in ('TorchShop', 'WeaponShop', 'ArmorShop', 'PotionShop'):
        d = ITEM[ident]
        names = []
        s, c = d['shop'], None
        for (iid, stock, roll, die) in d['shop']:
            names.append('%s (%d)' % (ITEM[iid]['name'], ITEM[iid]['price']))
        shops.append('<tr><td class="i">%s</td><td>%s</td><td class="small">%s</td></tr>' % (
            item_img(ident), esc(d['shop_title']), esc(', '.join(names))))
    doors = ''.join('<td style="text-align:center"><img class="sp" style="width:30px" src="door_%s.png"><br><span class="small">%s</span></td>' % (c, n)
                    for c, n in (('red', 'carnelian'), ('yellow', 'citrine'), ('green', 'jade'),
                                 ('cyan', 'aquamarine'), ('blue', 'sapphire'), ('magenta', 'amethyst')))
    ldoors = ''.join('<td class="i">%s</td>' % item_img(i, 36) for i in
                     ('RedDoorNorth', 'YellowDoorNorth', 'GreenDoorNorth', 'CyanDoorNorth', 'BlueDoorNorth', 'MagentaDoorNorth'))
    lkeys = ''.join('<td class="i">%s</td>' % item_img(i, 36) for i in
                    ('RedKey', 'YellowKey', 'GreenKey', 'CyanKey', 'BlueKey', 'MagentaKey'))
    cover = os.path.relpath(os.path.join(ROOT, 'assets', 'cover.png'), BUILD)
    return f'''<!doctype html><html><head><meta charset="utf-8"><title>HamQuest of SPLORR!! manual</title><style>{CSS}</style></head><body>

<div class="page cover">
  <img class="c" src="{cover}">
  <h1>HamQuest of SPLORR!!</h1>
  <p>Player's manual: how to play, and how to read the screen</p>
  <p style="margin-top:24mm;font-size:10pt;color:#888">thegrumpygamedev.itch.io/hamquest-of-splorr</p>
</div>

<div class="page">
<h1>The goal</h1>
<p>You are alone in a maze of {G.groups_maze[0] if hasattr(G,'groups_maze') else 8} by 8 rooms and passages. Every dead end is a locked room. Somewhere in those rooms lie <b>{ITEM['Quest']['item_count']} pieces of the MegaHam</b>. Collect all of them, take the <b>Rainbow Key</b> from the <b>Summoner</b>, and walk into the <b>exit</b> (it is in a dead end too). Anything else you pick up along the way is there to keep you alive until then.</p>
<div class="box"><b>You start with</b> {PLAYER['initial_health']} health, a dagger, five hams, three potions, some clothes, a match and a torch. Each level adds one health. The game is hard on purpose: many new characters die in their first few rooms. Avoid fights you cannot win, find better gear, and eat.</div>
<p>The game saves itself in your browser as you play, so closing the page does not lose your place. If you die, the run is over: the next game is a new maze.</p>

<div class="page"></div><h1>The screen</h1>
<div class="fig"><img src="{annotated}" style="max-width:92%"><div class="cap">The whole screen. The numbers match the list below.</div></div>
<table>
<tr><td><span class="n">1</span></td><td><b>The room.</b> The map of the room you are in, 15 by 15 tiles. It is dark: you only see what your light reaches, so a torch shows more than a match. Monsters outside your light are not drawn.</td></tr>
<tr><td><span class="n">2</span></td><td><b>The minimap.</b> The maze, 8 by 8 rooms. Only rooms you have been in are drawn. See the next page.</td></tr>
<tr><td><span class="n">3</span></td><td><b>Inventory.</b> What you carry. Every kind of item has a fixed slot; the number is how many you have.</td></tr>
<tr><td><span class="n">4</span></td><td><b>Statistics</b>: attack, defence, health, speed, experience and level.</td></tr>
<tr><td><span class="n">5</span></td><td><b>Fight mode</b>: the sword (attack) or shield (defend) is outlined. It decides which gear the game picks first. <kbd>Tab</kbd> switches.</td></tr>
<tr><td><span class="n">6</span></td><td><b>Messages.</b> The last five things that happened, one line each. The colour hints at the kind: blue is ordinary, red is experience.</td></tr>
</table>
</div>

<div class="page">
<h1>Reading the minimap</h1>
<p>The minimap is your map of the maze: each room you have visited is a small square in the grey panel, and it fills in as you explore. A room shows its <b>shape</b>, its <b>open sides</b>, any <b>locked doors</b> and a <b>marker</b>.</p>
<h2>Shapes and sides</h2>
<table>
<tr><td class="i"><img class="sp" style="width:34px" src="room.png"></td><td><b>A chamber</b> (a room). The dark bars on the edge show which sides open onto a neighbouring room.</td></tr>
<tr><td class="i"><img class="sp" style="width:34px" src="pass.png"></td><td><b>A passage.</b> A narrower connection, usually between other rooms.</td></tr>
<tr><td class="i"><img class="sp" style="width:34px" src="quest.png"></td><td><b>A chamber that holds a piece of the MegaHam.</b> Only shown while you carry the Ring of Detection.</td></tr>
<tr><td class="i"><img class="sp" style="width:34px" src="here.png"></td><td><b>You are here.</b> The white and magenta box on a room is your current room.</td></tr>
<tr><td class="i"><img class="sp" style="width:34px" src="deadend.png"></td><td><b>A dead end with its door.</b> Dead ends have one way in and it is locked. The coloured bar on the side is the lock; its colour tells you which key opens it.</td></tr>
</table>
<h2>Door colours</h2>
<p>Six locks, six keys; the colour on the minimap, on the door and on the key match.</p>
<table><tr>{doors}</tr></table>
<table><tr>{ldoors}</tr><tr>{lkeys}</tr></table>
<p class="cap">Doors (top) and the key for each (bottom), same order. A key is used up when it opens a door. Doors stand in the room beside the dead end, and keys always lie in rooms that are not dead ends.</p>
<h2>Markers</h2>
<p>A small coloured mark in the corner of a room tells you what it holds right now:</p>
<table>
<tr><td class="i">{minimap_img('markers/red', 24)}</td><td>Monsters</td>
<td class="i">{minimap_img('markers/green', 24)}</td><td>Items lying on the floor</td></tr>
<tr><td class="i">{minimap_img('markers/yellow', 24)}</td><td>The exit</td>
<td class="i">{minimap_img('markers/blue', 24)}</td><td>A portal</td></tr>
<tr><td class="i">{minimap_img('markers/redgreen', 24)}</td><td>Monsters and items</td>
<td class="i">{minimap_img('markers/redyellow', 24)}</td><td>Monsters and the exit</td></tr>
<tr><td class="i">{minimap_img('markers/redblue', 24)}</td><td>Monsters and a portal</td>
<td class="i">{minimap_img('markers/yellowgreen', 24)}</td><td>The exit and items</td></tr>
<tr><td class="i">{minimap_img('markers/yellowblue', 24)}</td><td>The exit and a portal</td>
<td class="i">{minimap_img('markers/greenblue', 24)}</td><td>Items and a portal</td></tr>
</table>
<p>Markers are live: they show what a room holds <i>right now</i>, for every room you have visited, even across the maze.</p>
</div>

<div class="page">
<h1>Inventory and statistics</h1>
<div class="cols"><div>
<div class="fig"><img src="{inv}"><div class="cap">The inventory grid. Letters are columns, numbers are rows.</div></div>
</div><div>
<h3>Reading a slot</h3>
<p>Each kind of thing has its own square, so the key to a red door is always in the same place. The small number is how many you carry. A <b>teal frame</b> means it is in use (your weapon, your armour, your light). A <b>red or yellow bar</b> on an item in use means it is nearly worn out: yellow under half, red under a quarter.</p>
<p>Counts abbreviate: 1.5K is fifteen hundred, 12K twelve thousand.</p>
<h3>Statistics (bottom right)</h3>
<table class="small">
<tr><td class="i"><img class="sp" style="width:28px" src="../../HamQuestSLClient/images/statistics/attack.png"></td><td><b>Attack</b>: the dice you roll with your weapon. No weapon is 0 (you can still punch).</td></tr>
<tr><td class="i"><img class="sp" style="width:28px" src="../../HamQuestSLClient/images/statistics/defend.png"></td><td><b>Defence</b>: the most your armour can absorb from one hit.</td></tr>
<tr><td class="i"><img class="sp" style="width:28px" src="../../HamQuestSLClient/images/statistics/health.png"></td><td><b>Health</b>: what you have left, over the most you can have.</td></tr>
<tr><td class="i"><img class="sp" style="width:28px" src="../../HamQuestSLClient/images/statistics/speed.png"></td><td><b>Speed</b>: the moves in this turn.</td></tr>
<tr><td class="i"><img class="sp" style="width:28px" src="../../HamQuestSLClient/images/statistics/experience.png"></td><td><b>Experience</b>: points over the amount for the next level.</td></tr>
<tr><td class="i"><img class="sp" style="width:28px" src="../../HamQuestSLClient/images/statistics/level.png"></td><td><b>Level</b>.</td></tr>
</table>
</div></div>
<h2>What every slot is</h2>
{inventory_legend()}
</div>

<div class="page">
<h1>How the rules work</h1>
<h2>Moves and turns</h2>
<p>Every key press that does something is one <b>move</b>, and bumping into a wall or a locked door still counts. Your <b>speed</b> (the number next to the boot) is how many moves make a <b>turn</b>; it is rolled again at the end of each turn, between 2 and 12, and your armour changes it (see below). Your light burns a little at the end of every turn.</p>
<p>Monsters have their own speed. For every move you make, each monster in the room acts <i>its speed divided by yours</i> times. A fast monster against a slow, armoured you can hit you twice in a move.</p>
<h2>Fighting</h2>
<p>Walk into a monster to hit it. You roll a number of dice equal to your <b>attack</b>; each die has a one in two chance of hitting. Your hits minus a random <b>defence roll</b> from the monster is the damage. If that is zero or less you missed. With no weapon you have a one in six chance of scratching for 1.</p>
<p>Monsters hit you the same way: their attack dice, minus a defence roll from your armour (one roll per piece you wear). The points of damage your armour absorbs wear it down, and the damage you deal wears your weapon. Which gear you wear is picked for you: in attack mode a two-handed weapon wins and the shield stays off; in defend mode the shield stays on and you use the best one-handed weapon.</p>
{weapons_table()}
{armour_table()}
<h2>Staying alive</h2>
<ul>
<li><b>Hams</b> are eaten automatically as soon as you are hurt and move: each heals one point.</li>
<li>A <b>potion</b> is used automatically when a hit would kill you, and restores {ITEM['Potion']['healing_amount']}. It saves you once per potion.</li>
<li><b>Rest</b> with <kbd>Space</kbd>: heals one point and finishes your turn, but only when no monster is in the room.</li>
<li>Levelling up heals you completely. The first level needs {PLAYER['initial_xp_goal']} XP and every level after that needs twice as much.</li>
</ul>
<h2>Light</h2>
<p>Everything beyond your light is black. A brighter light shows more of the room and more monsters before they reach you.</p>
{lights_table()}
</div>

<div class="page">
<h1>Things you will meet</h1>
<table>
<tr><td class="i">{item_img('RedDoorNorth')}</td><td><b>Doors.</b> Walk into one with the right key to open it. Without the key it just blocks you.</td></tr>
<tr><td class="i">{item_img('Quest')}</td><td><b>A piece of the MegaHam.</b> Pick up all {ITEM['Quest']['item_count']}. Each one you take wakes up some of the traps you have seen so far, so the maze gets more dangerous as you go.</td></tr>
<tr><td class="i">{item_img('Exit')}</td><td><b>The exit.</b> It only lets you through with all the pieces and the Rainbow Key, and never while you carry the Amulet.</td></tr>
<tr><td class="i">{item_img('Chest')}</td><td><b>A chest.</b> Walk into it to open it: something appears in its place (food, gold, a weapon, armour, a light, even a trap or a portal), and you walk onto it to take it.</td></tr>
<tr><td class="i">{item_img('DartTrap')}</td><td><b>A trap.</b> Hidden until you stand next to it, then it shows as this. Walking onto one hurts; with thieves' tools in your pack it is disarmed and the tools are used up. Walking <i>around</i> it is free.</td></tr>
<tr><td class="i">{item_img('Food')}</td><td><b>Ham.</b> A poison ham looks exactly like a lovely one. Walking onto it without the mysterious green liquid (the antidote) hurts you; goblins drop them now and then.</td></tr>
<tr><td class="i">{item_img('Portal')}</td><td><b>A portal.</b> Throws you to a random room, once (the portal is used up). Useful for escape, a nuisance when you wanted to be here. The Amulet makes you immune.</td></tr>
<tr><td class="i">{item_img('Amulet')}</td><td><b>The Amulet of Yendor.</b> Protects you from portals and teleporting monsters, but you cannot leave while you hold it. <kbd>Y</kbd> drops it and sends you away.</td></tr>
<tr><td class="i">{item_img('Compass')}</td><td><b>The Ring of Detection.</b> Shows the rooms that hold pieces of the MegaHam on your minimap.</td></tr>
</table>
<h2>Shops</h2>
<p>There are four shops, each in a dead end. A shop sells what its shelves happen to hold when you enter (the stock is random), and it <b>disappears once you have been in it</b>, so spend what you can. Entering a shop makes noise: expect more monsters to find you afterwards.</p>
<table>{''.join(shops)}</table>
<p class="small">Prices in gold. Gold piles are {money_note()} each, and every coin you pick up goes into one total.</p>
</div>

<div class="page">
<h1>The monsters</h1>
<p class="small">Attack dice each hit on one chance in two. Defence is the largest number the monster can roll to cancel your hits. Speed is its actions per <i>your</i> turn. Most monsters drop something when they die: coins, food, and often better weapons and armour than you will find on the floor. <b>Wandering monsters:</b> the more often you walk through a room, the likelier a monster appears there.</p>
<div class="mon">{monsters_table()}</div>
</div>

<div class="page">
<h1>Controls</h1>
<table>
<tr><th>Action</th><th>Keyboard</th><th>Touch</th></tr>
<tr><td>Move, or attack what is in the way</td><td><kbd>&#8593;</kbd> <kbd>&#8595;</kbd> <kbd>&#8592;</kbd> <kbd>&#8594;</kbd> or <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd></td><td>Tap toward where you want to go, or use the pad</td></tr>
<tr><td>Rest (needs a quiet room)</td><td><kbd>Space</kbd></td><td>Tap yourself, or the Rest button</td></tr>
<tr><td>Switch attack and defend gear</td><td><kbd>Tab</kbd></td><td>Tap the sword or shield icon, or Mode</td></tr>
<tr><td>Use the Amulet (drop it and be teleported)</td><td><kbd>Y</kbd></td><td>Amulet</td></tr>
<tr><td>New game</td><td><kbd>F2</kbd> (asks first)</td><td>New</td></tr>
<tr><td>Credits</td><td><kbd>C</kbd></td><td>Credits</td></tr>
<tr><td>Full screen</td><td><kbd>F</kbd></td><td></td></tr>
<tr><td>Close a pop-up or screen</td><td><kbd>Enter</kbd> or <kbd>Esc</kbd></td><td>Tap</td></tr>
<tr><td>Stop the tip pop-ups for good</td><td><kbd>T</kbd> while one is open</td><td></td></tr>
<tr><td>In a shop: choose, buy one, buy all, leave</td><td><kbd>&#8593;</kbd><kbd>&#8595;</kbd>, <kbd>Enter</kbd>, <kbd>A</kbd>, <kbd>Esc</kbd></td><td>Tap a row (again to buy), or a button</td></tr>
</table>
<h2>Tips</h2>
<ul>
<li>Do not fight at the start. Walk away from what you do not have to kill; a fast monster is only dangerous while you are slow.</li>
<li>Boots double your moves per turn. Platemail halves them. Heavy armour makes everything else around you act more often per move.</li>
<li>Check the minimap before you open a door: a red mark means someone is in there.</li>
<li>Each piece of the MegaHam you pick up wakes some of the traps you have seen: pick them up when you are healthy and have an exit.</li>
<li>Keep one potion in reserve for the boss rooms. Dead ends are where the dangerous things live.</li>
<li>Food and potions are cheap in the potion shop; buy before you need them.</li>
<li>The Summoner and the Necromancer are the only monsters that call help. Kill them fast or leave.</li>
</ul>
<h2>Credits</h2>
<p class="small">Game, doors and walls: TheGrumpyGameDev. Tiles: David Gervais, Angband 32x32 tileset, Creative Commons Attribution 3.0 (creativecommons.org/licenses/by/3.0). Font: m5x7 by Daniel Linssen (managore), CC0. The 2026 Odin and WebAssembly port was written with Claude Code (Anthropic). The original game is a C# program written between 2007 and 2011 (WinForms, then Silverlight). There is no sound in this build.</p>
</div>

</body></html>'''


def main():
    os.makedirs(BUILD, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    figs = (annotated_screen(), inventory_grid(), minimap_examples())
    page = page_html(figs)
    html_path = os.path.join(BUILD, 'index.html')
    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(page)
    subprocess.check_call([
        'google-chrome', '--headless=new', '--no-sandbox', '--disable-gpu', '--hide-scrollbars',
        '--no-pdf-header-footer', '--print-to-pdf=' + PDF, 'file://' + html_path,
    ], stderr=subprocess.DEVNULL)
    print('wrote', os.path.relpath(PDF, ROOT), os.path.getsize(PDF), 'bytes')


if __name__ == '__main__':
    main()
