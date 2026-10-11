package game

import content "../content"

// Player rules (docs/game-reference.md sections 5 to 8). The player is not in World.creatures: its
// position is World.player and its inventory, equipment and wounds live directly on the World.

MAX_CHAIN :: 64

item_def :: proc(kind: content.Item_Kind) -> ^content.Item_Def {
	return &content.ITEMS[kind]
}

msg :: proc(w: ^World, id: content.Message_Id, arg: i32 = 0) {
	if id == .None {return}
	if w.msg_count == MSG_LOG {
		for i in 1 ..< MSG_LOG {w.msgs[i - 1] = w.msgs[i]}
		w.msg_count -= 1
	}
	w.msgs[w.msg_count] = Msg{id, arg}
	w.msg_count += 1
	w.msg_serial += 1
	def := &content.MESSAGES[id]
	if def.sound != .None {push_event(w, .Sound, id)}
	if w.mode == .Normal && len(def.tutorial_title) > 0 && (def.always_tutorial || (!w.tutorial_off && !w.tutorial_seen[id])) {
		w.tutorial_seen[id] = true
		push_event(w, .Tutorial, id)
	}
}

push_event :: proc(w: ^World, kind: Event_Kind, id: content.Message_Id) {
	if w.event_count < MAX_EVENTS {
		w.events[w.event_count] = Event{kind, id}
		w.event_count += 1
	}
}

count_of :: proc(w: ^World, kind: content.Item_Kind) -> u32 {
	return w.inventory[kind]
}

has_item :: proc(w: ^World, kind: content.Item_Kind) -> bool {
	return kind != .None && w.inventory[kind] > 0
}

remove_items :: proc(w: ^World, kind: content.Item_Kind, n: u32) {
	if w.inventory[kind] <= n {
		w.inventory[kind] = 0
	} else {
		w.inventory[kind] -= n
	}
}

money :: proc(w: ^World) -> u32 {
	return w.inventory[content.PLAYER.currency_item]
}

player_health :: proc(w: ^World) -> i32 {
	return w.level * content.PLAYER.health_per_level + content.PLAYER.initial_health
}

player_dead :: proc(w: ^World) -> bool {
	return w.wounds >= player_health(w)
}

player_attack :: proc(w: ^World) -> i32 {
	if w.weapon == .None {return 0}
	return item_def(w.weapon).attack_value
}

// Pieces of megaham needed to leave: all of them in a real game, a handful in the training level.
quest_required :: proc(w: ^World) -> u32 {
	if w.mode == .Tutorial {return TUT_QUEST_PIECES}
	return quest_item_total()
}

quest_item_total :: proc() -> u32 {
	total: u32
	for kind in content.Item_Kind {
		if kind != .None && content.ITEMS[kind].item_type == .Quest {
			total += u32(content.ITEMS[kind].item_count)
		}
	}
	return total
}

gen_max :: proc(g: content.Generator_Id) -> i32 {
	rg := content.GENERATORS[g]
	best: i32
	for i in rg.start ..< rg.start + rg.count {
		if content.WEIGHT_POOL[i].value > best {best = content.WEIGHT_POOL[i].value}
	}
	return best
}

// Dice: `count` dice, each succeeding when Next(6) < die. With no dice, unarmed: 1 point 1 time in 6.
roll_attack :: proc(w: ^World, count, die: i32) -> i32 {
	if count > 0 {
		result: i32
		for _ in 0 ..< count {
			if rng_int(&w.rng, 6) < int(die) {result += 1}
		}
		return result
	}
	if rng_int(&w.rng, 6) == 0 {return 1}
	return 0
}

roll_player_defend :: proc(w: ^World) -> i32 {
	total: i32
	for at in content.Armor_Type {
		if at == .None {continue}
		k := w.armor[at]
		if k != .None {total += pick_weighted(&w.rng, content.GENERATORS[item_def(k).defend_gen])}
	}
	return total
}

roll_creature_defend :: proc(w: ^World, kind: content.Creature_Kind) -> i32 {
	return pick_weighted(&w.rng, content.GENERATORS[content.CREATURES[kind].defend_gen])
}

// ---------------------------------------------------------------- equipment

auto_equip_weapon :: proc(w: ^World) {
	best_attack: i32 = -1
	for kind in content.Item_Kind {
		if kind == .None || w.inventory[kind] == 0 {continue}
		d := item_def(kind)
		if d.item_type != .Weapon {continue}
		if d.two_handed && w.armor[.Shield] != .None {continue}
		if w.weapon == .None || d.attack_value > best_attack {
			w.weapon = kind
			best_attack = d.attack_value
		}
	}
}

auto_equip_armors :: proc(w: ^World) {
	two_handed := w.weapon != .None && item_def(w.weapon).two_handed
	for kind in content.Item_Kind {
		if kind == .None || w.inventory[kind] == 0 {continue}
		d := item_def(kind)
		if d.item_type != .Armor {continue}
		at := d.armor_type
		if at == .Shield && two_handed {continue}
		cur := w.armor[at]
		if cur == .None {
			w.armor[at] = kind
		} else if gen_max(d.defend_gen) > gen_max(item_def(cur).defend_gen) {
			w.armor[at] = kind
		}
	}
}

auto_equip :: proc(w: ^World) {
	w.weapon = .None
	for at in content.Armor_Type {w.armor[at] = .None}
	if w.config == .Defend {
		auto_equip_armors(w)
		auto_equip_weapon(w)
	} else {
		auto_equip_weapon(w)
		auto_equip_armors(w)
	}
}

is_equipped :: proc(w: ^World, kind: content.Item_Kind) -> bool {
	if kind == .None {return false}
	if kind == w.weapon || kind == light_source(w) {return true}
	for at in content.Armor_Type {
		if w.armor[at] == kind {return true}
	}
	return false
}

// ---------------------------------------------------------------- light, speed, steps

light_source :: proc(w: ^World) -> content.Item_Kind {
	best: i32 = -1
	result := content.Item_Kind.None
	for kind in content.Item_Kind {
		if kind == .None || w.inventory[kind] == 0 {continue}
		d := item_def(kind)
		if d.item_type == .Light && d.light_level > best {
			best = d.light_level
			result = kind
		}
	}
	return result
}

decrement_light :: proc(w: ^World) {
	ls := light_source(w)
	if ls == .None {return}
	d := item_def(ls)
	if d.duration == 0 {return}
	if w.durability[ls] > 0 {w.durability[ls] -= 1}
	if w.durability[ls] % u32(d.duration) == 0 {
		msg(w, d.go_out_msg)
		remove_items(w, ls, 1)
		if w.mode == .Tutorial {w.tut.outages += 1}
	}
}

roll_speed :: proc(w: ^World) {
	speed := pick_weighted(&w.rng, content.PLAYER.speed_roll)
	mult: f32 = 1.0
	for at in content.Armor_Type {
		if w.armor[at] != .None {mult *= item_def(w.armor[at]).speed_multiplier}
	}
	speed = i32(f32(speed) * mult)
	if speed == 0 {speed = 1}
	w.step_total = speed
	w.step_count = 0
}

// One step of game time for the player; every `step_total` steps is a turn (light burns, speed rerolls).
do_step :: proc(w: ^World) {
	w.step_count += 1
	if w.step_count >= w.step_total {
		decrement_light(w)
		roll_speed(w)
		w.turn += 1
	}
}

// ---------------------------------------------------------------- items

add_durability :: proc(w: ^World, kind: content.Item_Kind) {
	d := item_def(kind)
	if (d.item_type == .Weapon || d.item_type == .Armor) && d.durability > 0 {
		w.durability[kind] += u32(d.durability)
	}
}

// `report` false is used for the starting inventory. Mirrors PlayerDescriptor.AddItem.
add_item :: proc(w: ^World, kind: content.Item_Kind, report: bool) {
	d := item_def(kind)
	say := report
	#partial switch d.item_type {
	case .Portal:
		if say {msg(w, d.pick_up_msg)}
		teleport_player(w)
	case .Treasure:
		if say {msg(w, d.pick_up_msg)}
		span := int(d.max_value - d.min_value + 1)
		w.inventory[content.PLAYER.currency_item] += u32(rng_int(&w.rng, span) + int(d.min_value))
	case .Quest:
		if say {msg(w, d.pick_up_msg)}
		total := quest_required(w)
		held := w.inventory[content.PLAYER.quest_item]
		if total > held && w.mode == .Normal {spawn_monsters(w, 1.0 / f32(total - held))}
		w.inventory[content.PLAYER.quest_item] += 1
		if w.inventory[content.PLAYER.quest_item] == total {msg(w, content.PLAYER.quest_completed_msg)}
	case .Chest:
		if say {msg(w, d.pick_up_msg)}
	case .Armor, .Weapon:
		if say {msg(w, d.pick_up_msg)}
		add_durability(w, kind)
		w.inventory[kind] += 1
		auto_equip(w)
	case .Trap:
		can := true
		for i in d.disarms.start ..< d.disarms.start + d.disarms.count {
			e := content.COUNT_POOL[i]
			if e.count > w.inventory[e.item] {can = false}
		}
		if can {
			for i in d.disarms.start ..< d.disarms.start + d.disarms.count {
				e := content.COUNT_POOL[i]
				remove_items(w, e.item, e.count)
			}
			if say {msg(w, d.disarm_msg)}
		} else {
			if say {msg(w, d.pick_up_msg)}
			take_damage(w, d.attack_value, 0)
			w.been_hit = true
			if player_dead(w) && say {msg(w, d.killed_by_msg)}
		}
	case .Light:
		if say {msg(w, d.pick_up_msg)}
		w.inventory[kind] += 1
		w.durability[kind] += u32(d.duration)
	case:
		if say {msg(w, d.pick_up_msg)}
		w.inventory[kind] += 1
	}
}

// ---------------------------------------------------------------- wear

// Weapons wear by the damage they deal; one copy breaks when the stock no longer covers the count.
check_weapon_breakage :: proc(w: ^World, damage: i32) {
	k := w.weapon
	if k == .None {return}
	d := item_def(k)
	if d.durability <= 0 {return}
	if u32(damage) > w.durability[k] {
		w.durability[k] = 0
	} else {
		w.durability[k] -= u32(damage)
	}
	per := u32(d.durability)
	if (w.durability[k] + per - 1) / per < w.inventory[k] {
		msg(w, d.broken_msg)
		remove_items(w, k, 1)
		auto_equip(w)
	}
}

// Armour wears by the points of damage it absorbed, spread over worn items tagged Durable.
check_armor_breakage :: proc(w: ^World, damage_in: i32) {
	damage := damage_in
	if damage <= 0 {return}
	worn: [len(content.Armor_Type)]content.Item_Kind
	n := 0
	for at in content.Armor_Type {
		k := w.armor[at]
		if k != .None && .Durable in item_def(k).tags && item_def(k).durability > 0 {
			worn[n] = k
			n += 1
		}
	}
	broken: [len(content.Armor_Type)]content.Item_Kind
	nb := 0
	for damage > 0 && n > 0 {
		idx := rng_int(&w.rng, n)
		k := worn[idx]
		if w.durability[k] > 0 {
			w.durability[k] -= 1
			damage -= 1
		}
		per := u32(item_def(k).durability)
		if (w.durability[k] + per - 1) / per < w.inventory[k] {
			msg(w, item_def(k).broken_msg)
			broken[nb] = k
			nb += 1
			worn[idx] = worn[n - 1]
			n -= 1
		}
	}
	if nb > 0 {
		for i in 0 ..< nb {remove_items(w, broken[i], 1)}
		auto_equip(w)
	}
}

// ---------------------------------------------------------------- health

first_healer :: proc(w: ^World, kind: content.Healing_Type) -> content.Item_Kind {
	for k in content.Item_Kind {
		if k == .None || w.inventory[k] == 0 {continue}
		d := item_def(k)
		if d.item_type == .Healing && d.healing_type == kind {return k}
	}
	return .None
}

heal :: proc(w: ^World, amount: i32) {
	w.wounds -= amount
	if w.wounds < 0 {w.wounds = 0}
}

take_damage :: proc(w: ^World, damage, defend_roll: i32) {
	w.wounds += damage
	w.been_hit = true
	check_armor_breakage(w, defend_roll)
	for _ in 0 ..< MAX_CHAIN {
		if !player_dead(w) {return}
		k := first_healer(w, .Save)
		if k == .None && w.mode == .Tutorial {
			tutorial_mercy(w)
			return
		}
		if k == .None {
			w.state = .Lose
			msg(w, content.PLAYER.killed_msg)
			return
		}
		msg(w, item_def(k).use_msg)
		heal(w, item_def(k).healing_amount)
		remove_items(w, k, 1)
	}
}

// Eat before moving while wounded (and food remains).
eat_if_needed :: proc(w: ^World) {
	for _ in 0 ..< MAX_CHAIN {
		if w.wounds <= 0 {return}
		k := first_healer(w, .Eaten)
		if k == .None {return}
		msg(w, item_def(k).use_msg)
		heal(w, item_def(k).healing_amount)
		remove_items(w, k, 1)
	}
}

add_experience :: proc(w: ^World, points: i32) {
	if points == 1 {
		msg(w, content.PLAYER.gain_xp_point_msg, points)
	} else {
		msg(w, content.PLAYER.gain_xp_points_msg, points)
	}
	w.xp += points
	if w.xp >= w.xp_goal {
		msg(w, content.PLAYER.gain_level_msg)
		w.xp -= w.xp_goal
		w.xp_goal = w.xp_goal * content.PLAYER.xp_goal_mul / content.PLAYER.xp_goal_div
		w.wounds = 0
		w.level += 1
	}
}
