#+build !js
package tests

import "core:testing"
import content "../content"
import game "../game"

// ---- scenario helpers

// A fresh game with the player alone in an empty room of an interior cell, standing at (7,7).
arena :: proc(t: ^testing.T, seed: u64 = 11) -> ^game.World {
	w := new(game.World)
	err := game.new_game(w, seed)
	testing.expect_value(t, err, game.Gen_Error.None)
	w.player.maze_col = 3
	w.player.maze_row = 3
	w.player.col = 7
	w.player.row = 7
	cell := &w.cells[3][3]
	for r in 0 ..< game.MAP_ROWS {
		for c in 0 ..< game.MAP_COLS {
			cell.map_.tiles[r][c] = game.Tile{terrain = content.MAP_ROOM[r][c]}
		}
	}
	for i in 0 ..< w.creature_count {
		if w.creatures[i].maze_col == 3 && w.creatures[i].maze_row == 3 {w.creatures[i].alive = false}
	}
	cell.visit_count = 1
	w.wounds = 0
	w.msg_count = 0
	w.event_count = 0
	game.update_pathing(w)
	return w
}

put_item :: proc(w: ^game.World, col, row: int, kind: content.Item_Kind) {
	w.cells[3][3].map_.tiles[row][col].item = kind
}

put_creature :: proc(w: ^game.World, kind: content.Creature_Kind, col, row: int) -> int {
	for i in 0 ..< w.creature_count {
		if !w.creatures[i].alive {
			w.creatures[i] = game.Creature{kind = kind, maze_col = 3, maze_row = 3, col = u8(col), row = u8(row), alive = true}
			w.cells[3][3].map_.tiles[row][col].creature = i16(i + 1)
			return i
		}
	}
	idx := w.creature_count
	w.creature_count += 1
	w.creatures[idx] = game.Creature{kind = kind, maze_col = 3, maze_row = 3, col = u8(col), row = u8(row), alive = true}
	w.cells[3][3].map_.tiles[row][col].creature = i16(idx + 1)
	return idx
}

has_msg :: proc(w: ^game.World, id: content.Message_Id) -> bool {
	for i in 0 ..< w.msg_count {
		if w.msgs[i].id == id {return true}
	}
	return false
}

tile :: proc(w: ^game.World, col, row: int) -> game.Tile {
	return w.cells[3][3].map_.tiles[row][col]
}

// ---- movement and blocked moves

@(test)
turn_free_move_and_wall :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	game.step_command(w, .Move_East)
	testing.expect_value(t, int(w.player.col), 8)
	w.player.col = 1
	w.player.row = 1
	game.update_pathing(w)
	before := w.step_count
	turn := w.turn
	game.step_command(w, .Move_North) // the ring of tiles is wall
	testing.expect_value(t, int(w.player.row), 1)
	// D12: a blocked move still costs a step
	testing.expect(t, w.step_count != before || w.turn != turn, "blocked move did not advance time")
}

@(test)
turn_treasure_pays_within_range :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	d := content.ITEMS[.Gold]
	before := w.inventory[.Gold]
	put_item(w, 8, 7, .Gold)
	game.step_command(w, .Move_East)
	gained := int(w.inventory[.Gold] - before)
	testing.expect(t, gained >= int(d.min_value) && gained <= int(d.max_value), "gold outside range")
	testing.expect_value(t, tile(w, 8, 7).item, content.Item_Kind.None)
	testing.expect_value(t, int(w.player.col), 8)
	testing.expect(t, has_msg(w, .PickUpGold))
}

@(test)
turn_door_needs_its_key :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	// lock the east portal of the arena cell
	pt := game.portal_of(w, 3, 3, .East)
	pt.open = true
	pt.locked = true
	pt.lock_type = 0
	put_item(w, 8, 7, .RedDoorEast)
	w.inventory[.RedKey] = 0
	game.step_command(w, .Move_East)
	testing.expect_value(t, int(w.player.col), 7)
	testing.expect(t, has_msg(w, .BumpRedDoor))
	testing.expect(t, pt.locked)
	testing.expect_value(t, tile(w, 8, 7).item, content.Item_Kind.RedDoorEast)
	w.inventory[.RedKey] = 1
	game.step_command(w, .Move_East)
	testing.expect_value(t, int(w.player.col), 8)
	testing.expect_value(t, w.inventory[.RedKey], u32(0))
	testing.expect(t, !pt.locked)
	testing.expect_value(t, tile(w, 8, 7).item, content.Item_Kind.None)
	testing.expect(t, has_msg(w, .UnlockRedDoor))
}

@(test)
turn_crossing_into_the_neighbour :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	w.player.col = 14
	w.player.row = 7
	// the doorway tile at the east edge; the arena room has ring walls, so open it
	w.cells[3][3].map_.tiles[7][14].terrain = content.MAP_PWAY[15][7][14]
	game.step_command(w, .Move_East)
	testing.expect_value(t, int(w.player.maze_col), 4)
	testing.expect_value(t, int(w.player.col), 0)
	testing.expect_value(t, int(w.player.row), 7)
	testing.expect(t, w.cells[3][4].visit_count >= 1)
}

// ---- combat

@(test)
turn_player_kills_and_gains_xp :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	w.inventory[.Longsword] = 1
	w.durability[.Longsword] = 1000
	game.auto_equip(w)
	idx := put_creature(w, .Goblin, 8, 7)
	xp0 := w.xp + w.level * 100
	dead := false
	for _ in 0 ..< 400 {
		game.step_command(w, .Move_East)
		if w.state != .Play {break}
		if game.creature_dead(&w.creatures[idx]) {
			dead = true
			break
		}
	}
	testing.expect(t, dead || w.state == .Lose, "goblin never died")
	if dead {
		testing.expect(t, w.xp + w.level * 100 > xp0)
		testing.expect(t, has_msg(w, .KilledGoblin))
	}
}

@(test)
turn_dead_creatures_are_cleared_after_the_turn :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	idx := put_creature(w, .Goblin, 8, 7)
	w.creatures[idx].wounds = 999
	game.remove_dead_creatures(w)
	testing.expect(t, !w.creatures[idx].alive)
	testing.expect_value(t, tile(w, 8, 7).creature, i16(0))
}

@(test)
turn_creatures_chase_and_hit :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	// a fast, strong creature next to an unarmoured player
	for at in content.Armor_Type {w.armor[at] = .None}
	idx := put_creature(w, .Dragon, 9, 7)
	hit := false
	for _ in 0 ..< 200 {
		game.step_command(w, .Rest) // refused with a creature present, but time passes
		if w.wounds > 0 || w.state == .Lose {
			hit = true
			break
		}
	}
	testing.expect(t, hit, "a dragon two tiles away never hurt the player")
	_ = idx
}

// ---- health

@(test)
turn_eats_when_wounded :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	w.inventory[.Food] = 5
	w.wounds = 3
	game.step_command(w, .Move_East)
	testing.expect_value(t, w.wounds, i32(0))
	testing.expect_value(t, w.inventory[.Food], u32(2))
}

@(test)
turn_potion_saves_from_death :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	w.inventory[.Potion] = 1
	game.take_damage(w, game.player_health(w), 0) // exactly fatal
	testing.expect_value(t, w.state, game.Play_State.Play)
	testing.expect_value(t, w.inventory[.Potion], u32(0))
	testing.expect(t, w.wounds < game.player_health(w))
	game.take_damage(w, 999, 0)
	testing.expect_value(t, w.state, game.Play_State.Lose)
	testing.expect(t, has_msg(w, .YouHaveDied))
}

@(test)
turn_experience_levels_up :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	goal := w.xp_goal
	w.wounds = 2
	game.add_experience(w, goal)
	testing.expect_value(t, w.level, i32(1))
	testing.expect_value(t, w.xp_goal, goal * content.PLAYER.xp_goal_mul / content.PLAYER.xp_goal_div)
	testing.expect_value(t, w.wounds, i32(0))
	testing.expect_value(t, w.xp, i32(0))
}

// ---- equipment and wear

@(test)
turn_auto_equip_prefers_better_and_respects_two_handed :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	for k in content.Item_Kind {w.inventory[k] = 0}
	w.inventory[.Dagger] = 1
	w.inventory[.TwoHandedSword] = 1
	w.inventory[.Shield] = 1
	w.config = .Attack
	game.auto_equip(w)
	testing.expect_value(t, w.weapon, content.Item_Kind.TwoHandedSword)
	testing.expect_value(t, w.armor[.Shield], content.Item_Kind.None) // shield is left out with a two-handed weapon
	w.config = .Defend
	game.auto_equip(w)
	testing.expect_value(t, w.armor[.Shield], content.Item_Kind.Shield)
	testing.expect_value(t, w.weapon, content.Item_Kind.Dagger) // two-handed no longer fits
}

@(test)
turn_weapon_breaks_when_durability_runs_out :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	for k in content.Item_Kind {w.inventory[k] = 0}
	w.inventory[.Dagger] = 1
	w.durability[.Dagger] = 1
	game.auto_equip(w)
	game.check_weapon_breakage(w, 5)
	testing.expect_value(t, w.inventory[.Dagger], u32(0))
	testing.expect(t, has_msg(w, .BrokenDagger))
	testing.expect_value(t, w.weapon, content.Item_Kind.None)
}

@(test)
turn_armour_slows_the_turn_clock :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	for k in content.Item_Kind {w.inventory[k] = 0}
	w.inventory[.Platemail] = 1
	w.durability[.Platemail] = 15
	game.auto_equip(w)
	for _ in 0 ..< 200 {
		game.roll_speed(w)
		testing.expect(t, w.step_total >= 1 && w.step_total <= 6, "platemail speed outside 1..6")
	}
	w.inventory[.Boots] = 1
	game.auto_equip(w)
	for _ in 0 ..< 200 {
		game.roll_speed(w)
		testing.expect(t, w.step_total >= 2 && w.step_total <= 12, "boots+plate speed outside 2..12")
	}
}

@(test)
turn_light_burns_out :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	for k in content.Item_Kind {w.inventory[k] = 0}
	w.inventory[.Torch] = 1
	w.durability[.Torch] = u32(content.ITEMS[.Torch].duration)
	w.step_total = 1
	w.step_count = 0
	moved := 0
	for i in 0 ..< 200 {
		w.player.col = 7 // keep inside the room
		w.step_total = 1
		game.step_command(w, .Move_East)
		moved += 1
		if w.inventory[.Torch] == 0 {break}
	}
	testing.expect_value(t, w.inventory[.Torch], u32(0))
	testing.expect(t, has_msg(w, .GoOutTorch))
	testing.expect_value(t, moved, int(content.ITEMS[.Torch].duration))
}

// ---- traps, hidden things, shops, exit

@(test)
turn_trap_hurts_unless_disarmed :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	for k in content.Item_Kind {w.inventory[k] = 0}
	put_item(w, 8, 7, .DartTrap)
	w.inventory[.Tools] = 0
	game.step_command(w, .Move_East)
	testing.expect_value(t, w.wounds, content.ITEMS[.DartTrap].attack_value)
	w.wounds = 0
	put_item(w, 9, 7, .DartTrap)
	w.inventory[.Tools] = 1
	game.step_command(w, .Move_East)
	testing.expect_value(t, w.wounds, i32(0))
	testing.expect_value(t, w.inventory[.Tools], u32(0))
	testing.expect(t, has_msg(w, .DisarmDartTrap))
}

@(test)
turn_hidden_traps_show_when_adjacent :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	put_item(w, 8, 7, .HiddenDartTrap)
	game.reveal_traps(w)
	testing.expect_value(t, tile(w, 8, 7).item, content.Item_Kind.DartTrap)
}

@(test)
turn_shop_charges_the_displayed_price :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	// find a seed where the torch shop has a torch in stock
	put_item(w, 8, 7, .TorchShop)
	w.inventory[.Gold] = 0
	game.step_command(w, .Move_East)
	testing.expect(t, w.shop.active)
	testing.expect_value(t, tile(w, 8, 7).item, content.Item_Kind.None) // vanishes once visited
	if w.shop.count == 0 {return}
	slot := 0
	item := w.shop.slots[slot].item
	price := u32(content.ITEMS[item].price)
	stock := w.shop.slots[slot].count
	testing.expect(t, !game.shop_buy(w, slot, false), "bought with no money")
	w.inventory[.Gold] = price + 7
	testing.expect(t, game.shop_buy(w, slot, false))
	testing.expect_value(t, w.inventory[.Gold], u32(7))
	testing.expect_value(t, w.shop.slots[slot].count, stock - 1)
	game.step_command(w, .Shop_Close)
	testing.expect(t, !w.shop.active)
}

@(test)
turn_exit_rules :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	for k in content.Item_Kind {w.inventory[k] = 0}
	total := game.quest_item_total()
	put_item(w, 8, 7, .Exit)
	game.step_command(w, .Move_East)
	testing.expect(t, has_msg(w, .NeedCompletedMegaham))
	testing.expect_value(t, w.state, game.Play_State.Play)

	w.inventory[.Quest] = total
	w.msg_count = 0
	game.step_command(w, .Move_East)
	testing.expect(t, has_msg(w, .NeedRainbowKey))
	testing.expect_value(t, w.state, game.Play_State.Play)

	w.inventory[.RainbowKey] = 1
	w.inventory[.Amulet] = 1
	w.msg_count = 0
	game.step_command(w, .Move_East)
	testing.expect(t, has_msg(w, .CannotExitWithAmulet))
	testing.expect_value(t, w.state, game.Play_State.Play)

	w.inventory[.Amulet] = 0
	game.step_command(w, .Move_East)
	testing.expect_value(t, w.state, game.Play_State.Win)
	// nothing moves once the game is over
	col := w.player.col
	game.step_command(w, .Move_West)
	testing.expect_value(t, w.player.col, col)
}

@(test)
turn_rest_heals_unless_monsters_lurk :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	w.wounds = 2
	idx := put_creature(w, .Skeleton, 12, 12)
	game.step_command(w, .Rest)
	testing.expect(t, has_msg(w, .CannotRest))
	testing.expect(t, w.wounds >= 2)
	w.creatures[idx].alive = false
	w.cells[3][3].map_.tiles[12][12].creature = 0
	w.wounds = 2
	w.msg_count = 0
	game.step_command(w, .Rest)
	testing.expect(t, has_msg(w, .PlayerRest))
	testing.expect_value(t, w.wounds, i32(1))
}

@(test)
turn_amulet_drops_and_teleports :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	w.inventory[.Amulet] = 1
	game.step_command(w, .Use_Amulet)
	testing.expect_value(t, w.inventory[.Amulet], u32(0))
	testing.expect_value(t, tile(w, 7, 7).item, content.Item_Kind.Amulet)
	cell := &w.cells[w.player.maze_row][w.player.maze_col]
	testing.expect(t, !cell.dead_end)
	pt := cell.map_.tiles[w.player.row][w.player.col]
	testing.expect(t, game.terrain_passable(pt.terrain))
	// with no amulet the key does nothing
	game.step_command(w, .Use_Amulet)
	testing.expect_value(t, w.inventory[.Amulet], u32(0))
}

@(test)
turn_thief_steals_gold :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	for at in content.Armor_Type {w.armor[at] = .None}
	w.inventory[.Gold] = 5000
	w.inventory[.Quest] = 0
	put_creature(w, .Thief, 9, 7)
	stolen := false
	for _ in 0 ..< 400 {
		w.player.col = 7
		game.step_command(w, .Rest)
		if w.state != .Play {break}
		if w.inventory[.Gold] < 5000 {
			stolen = true
			break
		}
	}
	testing.expect(t, stolen || w.state == .Lose, "thief never stole anything")
}

@(test)
turn_summoner_calls_helpers :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	for at in content.Armor_Type {w.armor[at] = .None}
	w.wounds = 0
	put_creature(w, .Summoner, 11, 7)
	before := 0
	for i in 0 ..< w.creature_count {
		if w.creatures[i].alive {before += 1}
	}
	grew := false
	for _ in 0 ..< 300 {
		w.wounds = 0
		game.step_command(w, .Rest)
		n := 0
		for i in 0 ..< w.creature_count {
			if w.creatures[i].alive {n += 1}
		}
		if n > before {
			grew = true
			break
		}
	}
	testing.expect(t, grew, "summoner never summoned")
}

@(test)
turn_quest_pieces_wake_traps :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	put_item(w, 3, 3, .ArrowTrap)
	put_item(w, 4, 3, .DartTrap)
	put_item(w, 5, 3, .BladeTrap)
	put_item(w, 6, 3, .ArrowTrap)
	before := 0
	for i in 0 ..< w.creature_count {
		if w.creatures[i].alive {before += 1}
	}
	game.spawn_monsters(w, 1.0)
	after := 0
	for i in 0 ..< w.creature_count {
		if w.creatures[i].alive && w.creatures[i].maze_col == 3 && w.creatures[i].maze_row == 3 {after += 1}
	}
	testing.expect(t, after >= 4, "expected the four traps in the arena to become monsters")
	testing.expect_value(t, tile(w, 3, 3).item, content.Item_Kind.None)
	_ = before
}

@(test)
turn_wandering_monsters_arrive_with_visits :: proc(t: ^testing.T) {
	w := arena(t)
	defer free(w)
	w.cells[3][3].visit_count = 60
	count := 0
	for i in 0 ..< w.creature_count {
		if w.creatures[i].alive && w.creatures[i].maze_col == 3 && w.creatures[i].maze_row == 3 {count += 1}
	}
	game.add_visit(w, 3, 3)
	after := 0
	for i in 0 ..< w.creature_count {
		if w.creatures[i].alive && w.creatures[i].maze_col == 3 && w.creatures[i].maze_row == 3 {
			after += 1
			testing.expect(t, w.creatures[i].summoned)
		}
	}
	testing.expect_value(t, after, count + 1)
	testing.expect(t, w.cells[3][3].visit_count < 60)
}

// ---- soak

@(test)
turn_soak_random_play_keeps_the_world_valid :: proc(t: ^testing.T) {
	cmds := [?]game.Command{.Move_North, .Move_East, .Move_South, .Move_West, .Move_North, .Move_East, .Move_South, .Move_West, .Rest, .Toggle_Config, .Use_Amulet}
	wins, losses := 0, 0
	for seed in 1 ..= u64(25) {
		w := new(game.World)
		defer free(w)
		testing.expect_value(t, game.new_game(w, seed), game.Gen_Error.None)
		pick: game.Rng
		game.rng_seed(&pick, seed * 7919)
		for step in 0 ..< 4000 {
			if w.state != .Play {break}
			if w.shop.active {
				// buy what we can afford, then leave
				game.step_command(w, .Shop_Buy_One, game.rng_int(&pick, 4))
				game.step_command(w, .Shop_Close)
				continue
			}
			game.step_command(w, cmds[game.rng_int(&pick, len(cmds))])
			if step % 25 == 0 {check_world_invariants(t, w, seed)}
		}
		check_world_invariants(t, w, seed)
		if w.state == .Win {wins += 1}
		if w.state == .Lose {losses += 1}
	}
	_ = wins
	_ = losses
}

check_world_invariants :: proc(t: ^testing.T, w: ^game.World, seed: u64) {
	p := w.player
	testing.expectf(t, int(p.maze_col) < game.MAZE_COLS && int(p.maze_row) < game.MAZE_ROWS, "seed %d: player outside the maze", seed)
	tl := w.cells[p.maze_row][p.maze_col].map_.tiles[p.row][p.col]
	testing.expectf(t, game.terrain_passable(tl.terrain), "seed %d: player on a wall", seed)
	testing.expectf(t, tl.creature == 0, "seed %d: player shares a tile with a creature", seed)
	testing.expectf(t, w.wounds >= 0, "seed %d: negative wounds", seed)
	testing.expectf(t, w.step_total >= 1, "seed %d: step total", seed)
	testing.expectf(t, w.inventory[.Gold] < 100_000_000, "seed %d: gold overflow", seed)
	for i in 0 ..< w.creature_count {
		c := w.creatures[i]
		if !c.alive {continue}
		t2 := w.cells[c.maze_row][c.maze_col].map_.tiles[c.row][c.col]
		testing.expectf(t, t2.creature == i16(i + 1), "seed %d: creature %d not on its tile", seed, i)
		testing.expectf(t, game.terrain_passable(t2.terrain), "seed %d: creature in a wall", seed)
	}
	// every tile that names a creature names a live one standing there
	for mr in 0 ..< game.MAZE_ROWS {
		for mc in 0 ..< game.MAZE_COLS {
			for r in 0 ..< game.MAP_ROWS {
				for c in 0 ..< game.MAP_COLS {
					ci := w.cells[mr][mc].map_.tiles[r][c].creature
					if ci == 0 {continue}
					cr := w.creatures[ci - 1]
					testing.expectf(
						t,
						cr.alive && int(cr.col) == c && int(cr.row) == r && int(cr.maze_col) == mc && int(cr.maze_row) == mr,
						"seed %d: stale creature reference",
						seed,
					)
				}
			}
		}
	}
	// the equipped things are carried
	if w.weapon != .None {testing.expectf(t, w.inventory[w.weapon] > 0, "seed %d: weapon not carried", seed)}
	for at in content.Armor_Type {
		k := w.armor[at]
		if k != .None {testing.expectf(t, w.inventory[k] > 0, "seed %d: armour not carried", seed)}
	}
}
