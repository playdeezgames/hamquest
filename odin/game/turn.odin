package game

import content "../content"

// The turn engine (M4): commands in, world changed, messages and events out. Mirrors
// PlayerMoveHandler, CreatureMoveHandler, Creature, Map.MoveCreatures and Maze (docs/game-reference.md
// sections 3 to 9). Every loop is bounded.

CREATURE_STEPS_PER_TURN_CAP :: 64

// ---------------------------------------------------------------- new game

new_game :: proc(w: ^World, seed: u64) -> Gen_Error {
	// tips already seen, and whether the player turned them off, survive a new game (as in the original)
	seen := w.tutorial_seen
	off := w.tutorial_off
	err := generate(w, seed)
	w.tutorial_seen = seen
	w.tutorial_off = off
	if err != .None {return err}
	begin_run(w)
	msg(w, .Welcome1)
	msg(w, .Welcome2)
	msg(w, .Welcome3)
	msg(w, .Welcome4)
	msg(w, .Welcome5)
	w.event_count = 0
	return .None
}

// The training level (D18): a fixed layout and a fixed starting kit; `seed` only drives the dice.
new_tutorial :: proc(w: ^World, seed: u64) -> Gen_Error {
	w^ = {}
	w.seed = seed
	rng_seed(&w.rng, seed)
	w.mode = .Tutorial
	if err := build_tutorial(w); err != .None {return err}
	tutorial_kit(w)
	begin_run(w)
	w.event_count = 0
	return .None
}

// Everything after the world exists: the starting kit, equipment, speed and the first pathing.
begin_run :: proc(w: ^World) {
	w.state = .Play
	w.level = content.PLAYER.initial_level
	w.xp = content.PLAYER.initial_xp
	w.xp_goal = content.PLAYER.initial_xp_goal
	w.config = content.PLAYER.config
	for kind in content.Item_Kind {
		n := w.start_inventory[kind]
		for _ in 0 ..< n {add_item(w, kind, false)}
	}
	// the starting kit is not "picked up": nothing to flash
	w.been_hit = false
	auto_equip(w)
	roll_speed(w)
	update_pathing(w)
	reveal_traps(w)
}

// ---------------------------------------------------------------- geometry helpers

player_cell :: proc(w: ^World) -> ^Maze_Cell {
	return &w.cells[w.player.maze_row][w.player.maze_col]
}

player_map :: proc(w: ^World) -> ^Map {
	return &player_cell(w).map_
}

is_player_tile :: proc(w: ^World, mcol, mrow, col, row: int) -> bool {
	p := w.player
	return int(p.maze_col) == mcol && int(p.maze_row) == mrow && int(p.col) == col && int(p.row) == row
}

in_map :: proc(col, row: int) -> bool {
	return col >= 0 && row >= 0 && col < MAP_COLS && row < MAP_ROWS
}

// A creature may enter a tile with this terrain (PlayerOnly doorways and walls deny it).
creature_can_enter_terrain :: proc(terrain: u8) -> bool {
	t := content.TERRAINS[terrain]
	if !t.passable {return false}
	#partial switch t.bump {
	case .AlwaysDeny, .PlayerOnly:
		return false
	}
	return true
}

player_can_enter_terrain :: proc(terrain: u8) -> bool {
	t := content.TERRAINS[terrain]
	return t.passable && t.bump != .AlwaysDeny
}

// Flood fill from the player over tiles a creature could stand on (no walls, no items).
update_pathing :: proc(w: ^World) {
	m := player_map(w)
	for r in 0 ..< MAP_ROWS {
		for c in 0 ..< MAP_COLS {w.pathing[r][c] = PATH_UNREACHABLE}
	}
	queue: [MAP_ROWS * MAP_COLS][2]u8
	head, tail := 0, 0
	pc, pr := int(w.player.col), int(w.player.row)
	w.pathing[pr][pc] = 0
	queue[tail] = {u8(pc), u8(pr)}
	tail += 1
	for head < tail {
		cur := queue[head]
		head += 1
		cc, cr := int(cur[0]), int(cur[1])
		for d in Direction {
			nc := cc + DIR_DCOL[d]
			nr := cr + DIR_DROW[d]
			if !in_map(nc, nr) {continue}
			if w.pathing[nr][nc] != PATH_UNREACHABLE {continue}
			t := m.tiles[nr][nc]
			if t.item != .None || !terrain_passable(t.terrain) {continue}
			w.pathing[nr][nc] = w.pathing[cr][cc] + 1
			queue[tail] = {u8(nc), u8(nr)}
			tail += 1
		}
	}
}

// Hidden traps next to the player become the real thing.
reveal_traps :: proc(w: ^World) {
	m := player_map(w)
	for d in Direction {
		c := int(w.player.col) + DIR_DCOL[d]
		r := int(w.player.row) + DIR_DROW[d]
		if !in_map(c, r) {continue}
		k := m.tiles[r][c].item
		if k != .None && item_def(k).item_type == .Hidden && item_def(k).hidden_item != .None {
			m.tiles[r][c].item = item_def(k).hidden_item
		}
	}
}

// Any creature (even one killed this turn but not yet cleared) in the player's cell.
map_has_creature :: proc(w: ^World) -> bool {
	for i in 0 ..< w.creature_count {
		c := &w.creatures[i]
		if c.alive && c.maze_col == w.player.maze_col && c.maze_row == w.player.maze_row {return true}
	}
	return false
}

creature_dead :: proc(c: ^Creature) -> bool {
	return c.wounds >= content.CREATURES[c.kind].health
}

// ---------------------------------------------------------------- creatures

spawn_creature :: proc(w: ^World, kind: content.Creature_Kind, mcol, mrow, col, row: int, summoned, fresh: bool) -> bool {
	slot := -1
	for i in 0 ..< w.creature_count {
		if !w.creatures[i].alive {
			slot = i
			break
		}
	}
	if slot < 0 {
		if w.creature_count >= MAX_CREATURES {return false}
		slot = w.creature_count
		w.creature_count += 1
	}
	w.creatures[slot] = Creature {
		kind     = kind,
		maze_col = u8(mcol),
		maze_row = u8(mrow),
		col      = u8(col),
		row      = u8(row),
		alive    = true,
		summoned = summoned,
		fresh    = fresh,
	}
	w.cells[mrow][mcol].map_.tiles[row][col].creature = i16(slot + 1)
	return true
}

pick_spawn_kind :: proc(w: ^World, table: content.Spawn_Table) -> content.Creature_Kind {
	rg := content.SPAWN_TABLES[table]
	if rg.count == 0 {return .None}
	return content.SPAWN_POOL[int(rg.start) + rng_int(&w.rng, int(rg.count))]
}

// A free interior tile of a cell (random, then a scan).
free_interior_tile :: proc(w: ^World, mcol, mrow: int) -> (col, row: int, ok: bool) {
	m := &w.cells[mrow][mcol].map_
	for _ in 0 ..< RANDOM_TRIES {
		col = rng_range(&w.rng, 1, MAP_COLS - 2)
		row = rng_range(&w.rng, 1, MAP_ROWS - 2)
		if tile_free(m, col, row) && !is_player_tile(w, mcol, mrow, col, row) {return col, row, true}
	}
	for row = 1; row < MAP_ROWS - 1; row += 1 {
		for col = 1; col < MAP_COLS - 1; col += 1 {
			if tile_free(m, col, row) && !is_player_tile(w, mcol, mrow, col, row) {return col, row, true}
		}
	}
	return 0, 0, false
}

// A free tile anywhere on the 15x15 map (used by teleporting and respawning).
free_any_tile :: proc(w: ^World, mcol, mrow: int) -> (col, row: int, ok: bool) {
	m := &w.cells[mrow][mcol].map_
	for _ in 0 ..< RANDOM_TRIES {
		col = rng_int(&w.rng, MAP_COLS)
		row = rng_int(&w.rng, MAP_ROWS)
		if tile_free(m, col, row) && !is_player_tile(w, mcol, mrow, col, row) {return col, row, true}
	}
	for row = 0; row < MAP_ROWS; row += 1 {
		for col = 0; col < MAP_COLS; col += 1 {
			if tile_free(m, col, row) && !is_player_tile(w, mcol, mrow, col, row) {return col, row, true}
		}
	}
	return 0, 0, false
}

// A visit to a cell can call a wandering monster (the more visits, the likelier).
add_visit :: proc(w: ^World, mcol, mrow: int) {
	cell := &w.cells[mrow][mcol]
	if w.mode == .Tutorial {
		// no wandering monsters in the training level; a visit only marks the room as seen
		if cell.visit_count <= 0 {cell.visit_count = 1}
		return
	}
	roll := rng_range(&w.rng, 1, 5) + rng_range(&w.rng, 1, 5)
	if roll <= int(cell.visit_count) - 1 {
		cell.visit_count -= i32(roll)
		col, row, ok := free_interior_tile(w, mcol, mrow)
		kind := pick_spawn_kind(w, .Spawn)
		if ok && kind != .None {
			spawn_creature(w, kind, mcol, mrow, col, row, true, true)
		}
	}
	cell.visit_count += 1
}

add_visits :: proc(w: ^World, mcol, mrow, n: int) {
	for _ in 0 ..< n {add_visit(w, mcol, mrow)}
}

// Picking up a quest piece turns a share of the traps seen so far into monsters.
spawn_monsters :: proc(w: ^World, fraction: f32) {
	candidates: [MAZE_ROWS * MAZE_COLS * 8][3]u8 // (maze index, col, row); capped
	n := 0
	for mr in 0 ..< MAZE_ROWS {
		for mc in 0 ..< MAZE_COLS {
			c := &w.cells[mr][mc]
			if c.visit_count <= 0 {continue}
			for r in 0 ..< MAP_ROWS {
				for cc in 0 ..< MAP_COLS {
					k := c.map_.tiles[r][cc].item
					if k != .None && .Spawns in item_def(k).tags && n < len(candidates) {
						candidates[n] = {u8(mr * MAZE_COLS + mc), u8(cc), u8(r)}
						n += 1
					}
				}
			}
		}
	}
	count := int(f32(n) * fraction)
	for _ in 0 ..< count {
		if n == 0 {break}
		pick := rng_int(&w.rng, n)
		cand := candidates[pick]
		candidates[pick] = candidates[n - 1]
		n -= 1
		mc := int(cand[0]) % MAZE_COLS
		mr := int(cand[0]) / MAZE_COLS
		col, row := int(cand[1]), int(cand[2])
		kind := pick_spawn_kind(w, .Spawn)
		tile := &w.cells[mr][mc].map_.tiles[row][col]
		tile.item = .None
		if kind != .None {spawn_creature(w, kind, mc, mr, col, row, false, false)}
	}
}

// Put an item back somewhere in the maze (a stolen coin pile or quest piece).
respawn_item :: proc(w: ^World, kind: content.Item_Kind) {
	d := item_def(kind)
	if d.placement == .None {return}
	for _ in 0 ..< RANDOM_TRIES {
		mc := rng_int(&w.rng, MAZE_COLS)
		mr := rng_int(&w.rng, MAZE_ROWS)
		c := &w.cells[mr][mc]
		if d.placement == .DeadEnd && !c.dead_end {continue}
		if d.placement == .NonDeadEnd && c.dead_end {continue}
		col, row, ok := free_any_tile(w, mc, mr)
		if !ok {continue}
		c.map_.tiles[row][col].item = kind
		return
	}
}

// Move the player to a random free tile of a random cell that is not a dead end.
teleport_player :: proc(w: ^World) {
	for _ in 0 ..< RANDOM_TRIES {
		mc := rng_int(&w.rng, MAZE_COLS)
		mr := rng_int(&w.rng, MAZE_ROWS)
		if w.cells[mr][mc].dead_end {continue}
		// the player's old tile is free once it leaves
		old := w.player
		w.player.maze_col = u8(mc)
		w.player.maze_row = u8(mr)
		col, row, ok := free_any_tile(w, mc, mr)
		if !ok {
			w.player = old
			continue
		}
		w.player.col = u8(col)
		w.player.row = u8(row)
		add_visit(w, mc, mr)
		update_pathing(w)
		reveal_traps(w)
		return
	}
}

// One creature step in `dir` (mirrors Creature.Move + CreatureMoveHandler.DoMove).
creature_move :: proc(w: ^World, ci: int, dir: Direction) {
	c := &w.creatures[ci]
	mc, mr := int(c.maze_col), int(c.maze_row)
	m := &w.cells[mr][mc].map_
	d := &content.CREATURES[c.kind]
	nc := int(c.col) + DIR_DCOL[dir]
	nr := int(c.row) + DIR_DROW[dir]
	if !in_map(nc, nr) {return}
	if !creature_can_enter_terrain(m.tiles[nr][nc].terrain) {return}
	if m.tiles[nr][nc].creature != 0 {return}
	if is_player_tile(w, mc, mr, nc, nr) {
		c.steps = 0 // avoid several hits per move
		creature_attacks_player(w, c)
		return
	}
	if m.tiles[nr][nc].item != .None {return}
	if nc == 0 || nc >= MAP_COLS - 1 || nr == 0 || nr >= MAP_ROWS - 1 {return}
	if d.special_attack == .Generator && rng_int(&w.rng, 6) < 1 {
		kind := pick_spawn_kind(w, d.generator_table)
		if kind != .None {spawn_creature(w, kind, mc, mr, nc, nr, true, true)}
		return
	}
	m.tiles[int(c.row)][int(c.col)].creature = 0
	c.col = u8(nc)
	c.row = u8(nr)
	m.tiles[nr][nc].creature = i16(ci + 1)
}

creature_attacks_player :: proc(w: ^World, c: ^Creature) {
	d := &content.CREATURES[c.kind]
	attacks := d.number_of_attacks
	for attacks > 0 && !player_dead(w) {
		attack_roll := roll_attack(w, d.attack, d.attack_die)
		defend_roll := roll_player_defend(w)
		damage := attack_roll - defend_roll
		if damage > 0 {
			push_event(w, .Hit_Player, .None)
			switch {
			case d.special_attack == .Thief && w.inventory[content.PLAYER.quest_item] > 0 && rng_int(&w.rng, 10) == 0:
				remove_items(w, content.PLAYER.quest_item, 1)
				respawn_item(w, content.PLAYER.quest_item)
				msg(w, content.PLAYER.thief_megaham_msg)
			case d.special_attack == .Thief && money(w) > 0:
				gold := u32(rng_int(&w.rng, int(100 * damage)))
				cur := money(w)
				if gold > cur {gold = cur}
				w.inventory[content.PLAYER.currency_item] = cur - gold
				respawn_item(w, content.PLAYER.currency_item)
				msg(w, content.PLAYER.thief_gold_msg)
			case d.special_attack == .Ghoul && w.xp > 0:
				w.xp -= damage
				if w.xp < 0 {w.xp = 0}
				msg(w, content.PLAYER.ghoul_msg)
			case d.special_attack == .Teleport:
				if d.item_blocks != .None && has_item(w, d.item_blocks) {
					msg(w, d.item_block_msg)
				} else {
					msg(w, d.hit_by_msg)
					teleport_player(w)
				}
			case:
				msg(w, d.hit_by_msg)
				take_damage(w, damage, defend_roll)
				if player_dead(w) {msg(w, d.killed_by_msg)}
			}
		} else {
			msg(w, d.missed_by_msg)
		}
		attacks -= 1
	}
}

// Every live creature in the player's cell acts according to its speed relative to the player's.
move_creatures :: proc(w: ^World, fraction: f32) {
	mc, mr := int(w.player.maze_col), int(w.player.maze_row)
	existing := w.creature_count
	for ci in 0 ..< existing {
		c := &w.creatures[ci]
		if !c.alive || c.fresh || int(c.maze_col) != mc || int(c.maze_row) != mr || creature_dead(c) {continue}
		d := &content.CREATURES[c.kind]
		c.steps += f32(d.speed) * fraction
		guard := 0
		for c.steps >= 1.0 && guard < CREATURE_STEPS_PER_TURN_CAP {
			guard += 1
			c.steps -= 1.0
			if pick_weighted(&w.rng, d.morale) == 0 {
				creature_move(w, ci, Direction(rng_int(&w.rng, 4)))
			} else {
				lowest := PATH_UNREACHABLE
				chosen := -1
				for dir in Direction {
					nc := int(c.col) + DIR_DCOL[dir]
					nr := int(c.row) + DIR_DROW[dir]
					if !in_map(nc, nr) {continue}
					p := w.pathing[nr][nc]
					if p == PATH_UNREACHABLE {continue}
					if p < lowest {
						lowest = p
						chosen = int(dir)
					}
				}
				if chosen >= 0 {creature_move(w, ci, Direction(chosen))}
			}
		}
	}
	for ci in 0 ..< w.creature_count {w.creatures[ci].fresh = false}
}

remove_dead_creatures :: proc(w: ^World) {
	for ci in 0 ..< w.creature_count {
		c := &w.creatures[ci]
		if c.alive && creature_dead(c) {
			w.cells[c.maze_row][c.maze_col].map_.tiles[c.row][c.col].creature = 0
			c.alive = false
		}
	}
}

// ---------------------------------------------------------------- the player's move

player_move :: proc(w: ^World, dir: Direction) {
	eat_if_needed(w)
	p := &w.player
	mc, mr := int(p.maze_col), int(p.maze_row)
	m := &w.cells[mr][mc].map_
	nc := int(p.col) + DIR_DCOL[dir]
	nr := int(p.row) + DIR_DROW[dir]

	// crossing into the neighbouring cell
	if nc < 0 || nr < 0 || nc >= MAP_COLS || nr >= MAP_ROWS {
		tc := mc + DIR_DCOL[dir]
		tr := mr + DIR_DROW[dir]
		if tc < 0 || tr < 0 || tc >= MAZE_COLS || tr >= MAZE_ROWS {return}
		p.maze_col = u8(tc)
		p.maze_row = u8(tr)
		p.col = u8((nc + MAP_COLS) % MAP_COLS)
		p.row = u8((nr + MAP_ROWS) % MAP_ROWS)
		add_visit(w, tc, tr)
		if w.mode == .Tutorial {tutorial_note_entry(w)}
		return
	}
	tile := &m.tiles[nr][nc]
	if !player_can_enter_terrain(tile.terrain) {return}

	if tile.creature != 0 {
		attack_creature(w, int(tile.creature) - 1)
		return
	}

	if tile.item == .None {
		p.col = u8(nc)
		p.row = u8(nr)
		return
	}

	kind := tile.item
	d := item_def(kind)
	move := true
	clear_item := true
	#partial switch d.item_type {
	case .Door:
		unlocked := false
		for i in d.unlocks.start ..< d.unlocks.start + d.unlocks.count {
			e := content.COUNT_POOL[i]
			if w.inventory[e.item] >= e.count {
				remove_items(w, e.item, e.count)
				unlocked = true
				msg(w, d.pick_up_msg)
				if d.direction >= 0 && d.direction < 4 {
					pt := portal_of(w, mc, mr, Direction(d.direction))
					if pt != nil {pt.locked = false}
				}
				break
			}
		}
		if !unlocked {
			msg(w, d.bump_msg)
			move = false
			clear_item = false
		}
	case .Portal:
		if d.item_blocks != .None && has_item(w, d.item_blocks) {
			msg(w, d.item_block_msg)
			move = false
			clear_item = false
		} else {
			tile.item = .None
			msg(w, d.pick_up_msg)
			teleport_player(w)
			return
		}
	case .Shop:
		move = false
		clear_item = false
		if map_has_creature(w) {
			msg(w, d.bump_msg)
		} else {
			open_shop(w, kind)
			if w.mode == .Normal {
				// the original defined no shop behaviour in the data, so a shop vanished once visited
				tile.item = .None
				p.col = u8(nc)
				p.row = u8(nr)
			}
		}
	case .Exit:
		move = false
		clear_item = false
		total := quest_required(w)
		quest := w.inventory[content.PLAYER.quest_item]
		switch {
		case has_item(w, content.PLAYER.amulet_item):
			msg(w, content.PLAYER.cannot_exit_amulet_msg)
		case quest == total && has_item(w, .RainbowKey):
			msg(w, content.PLAYER.won_msg)
			w.state = .Win
			move = true
		case quest == total:
			msg(w, content.PLAYER.need_rainbow_msg)
		case:
			msg(w, content.PLAYER.need_megaham_msg)
		}
	case .Chest:
		add_item(w, kind, true)
		gen := d.generated_item
		tile.item = content.Item_Kind(pick_weighted(&w.rng, gen))
		move = false
		clear_item = false
	case:
		add_item(w, kind, true)
		// a portal pickup moved the player; do not also step onto the old tile
		if player_moved_away(w, mc, mr) {return}
	}
	if clear_item {tile.item = .None}
	if move {
		p.col = u8(nc)
		p.row = u8(nr)
	}
}

player_moved_away :: proc(w: ^World, mc, mr: int) -> bool {
	return int(w.player.maze_col) != mc || int(w.player.maze_row) != mr
}

attack_creature :: proc(w: ^World, ci: int) {
	c := &w.creatures[ci]
	d := &content.CREATURES[c.kind]
	damage := roll_attack(w, player_attack(w), content.CREATURES[.Player].attack_die) - roll_creature_defend(w, c.kind)
	if damage > 0 {
		c.wounds += damage
		c.been_hit = true
		check_weapon_breakage(w, damage)
		if creature_dead(c) {
			drop := content.Item_Kind(pick_weighted(&w.rng, d.item_drops))
			w.cells[c.maze_row][c.maze_col].map_.tiles[c.row][c.col].item = drop
			msg(w, d.kill_msg)
			if w.mode == .Tutorial {w.tut.kills += 1}
			if !c.summoned {add_experience(w, d.experience_points)}
		} else {
			msg(w, d.hit_msg)
		}
	} else {
		msg(w, d.miss_msg)
	}
}

// ---------------------------------------------------------------- shops

open_shop :: proc(w: ^World, kind: content.Item_Kind) {
	d := item_def(kind)
	w.shop = {}
	w.shop.active = true
	w.shop.shop = kind
	if w.mode == .Tutorial {
		// a fixed shelf, and no ageing of the rooms
		w.tut.shops += 1
		tutorial_stock_shop(w)
		return
	}
	for i in d.shop_inventory.start ..< d.shop_inventory.start + d.shop_inventory.count {
		e := content.SHOP_POOL[i]
		for _ in 0 ..< e.in_stock {
			if rng_int(&w.rng, int(e.die)) < int(e.roll) {
				slot := -1
				for s in 0 ..< w.shop.count {
					if w.shop.slots[s].item == e.item {slot = s}
				}
				if slot < 0 && w.shop.count < SHOP_SLOTS {
					slot = w.shop.count
					w.shop.count += 1
					w.shop.slots[slot].item = e.item
				}
				if slot >= 0 {w.shop.slots[slot].count += 1}
			}
		}
	}
	// the original ages every visited cell by seven visits when a shop opens
	for mr in 0 ..< MAZE_ROWS {
		for mc in 0 ..< MAZE_COLS {
			if w.cells[mr][mc].visit_count > 0 {add_visits(w, mc, mr, 7)}
		}
	}
}

shop_buy :: proc(w: ^World, slot: int, all: bool) -> bool {
	if !w.shop.active || slot < 0 || slot >= w.shop.count {return false}
	s := &w.shop.slots[slot]
	price := u32(item_def(s.item).price)
	n: u32 = 1
	if all {n = s.count}
	if s.count == 0 || n == 0 {return false}
	cost := price * n
	if money(w) < cost {return false}
	w.inventory[content.PLAYER.currency_item] -= cost
	s.count -= n
	for _ in 0 ..< n {add_item(w, s.item, true)}
	if w.mode == .Tutorial {w.tut.purchases += 1}
	return true
}

// ---------------------------------------------------------------- commands

// Run one command. Does nothing once the game is won or lost.
step_command :: proc(w: ^World, cmd: Command, arg: int = 0) {
	w.tut.mercy = false
	run_command(w, cmd, arg)
	if w.mode == .Tutorial {tutorial_update(w)}
}

run_command :: proc(w: ^World, cmd: Command, arg: int = 0) {
	w.event_count = 0
	w.been_hit = false
	for i in 0 ..< w.creature_count {w.creatures[i].been_hit = false}
	if w.state != .Play {return}
	if w.shop.active {
		#partial switch cmd {
		case .Shop_Close:
			w.shop.active = false
		case .Shop_Buy_One:
			shop_buy(w, arg, false)
		case .Shop_Buy_All:
			shop_buy(w, arg, true)
		}
		return
	}
	acted := false
	#partial switch cmd {
	case .Move_North, .Move_East, .Move_South, .Move_West:
		player_move(w, Direction(int(cmd) - int(Command.Move_North)))
		update_pathing(w)
		reveal_traps(w)
		acted = true
	case .Rest:
		acted = rest(w)
	case .Use_Amulet:
		acted = use_amulet(w)
	case .Toggle_Config:
		if w.config == .Attack {w.config = .Defend} else {w.config = .Attack}
		auto_equip(w)
		return
	case:
		return
	}
	if acted {end_of_command(w)}
}

end_of_command :: proc(w: ^World) {
	if w.state != .Play {return}
	do_step(w)
	update_pathing(w)
	if w.state == .Play {
		move_creatures(w, 1.0 / f32(w.step_total))
	}
	remove_dead_creatures(w)
}

rest :: proc(w: ^World) -> bool {
	if map_has_creature(w) {
		msg(w, content.PLAYER.cannot_rest_msg)
		return true // the original still spent the step
	}
	msg(w, content.PLAYER.rest_msg)
	if w.mode == .Tutorial {w.tut.rests += 1}
	if w.wounds > 0 {w.wounds -= 1}
	remaining := w.step_total - w.step_count
	for remaining > 0 {
		do_step(w)
		remaining -= 1
	}
	add_visit(w, int(w.player.maze_col), int(w.player.maze_row))
	return true
}

// Invoke the Amulet: drop it where you stand and be carried elsewhere.
use_amulet :: proc(w: ^World) -> bool {
	am := content.PLAYER.amulet_item
	if !has_item(w, am) {return false}
	msg(w, item_def(am).use_msg)
	player_map(w).tiles[w.player.row][w.player.col].item = am
	remove_items(w, am, 1)
	teleport_player(w)
	return true
}
