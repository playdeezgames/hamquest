#+build !js
package tests

import "core:testing"
import content "../content"
import game "../game"

// The training level (D18 to D20): it must be finishable from the first command to the exit with
// any dice, the lessons must follow the player, the mercy rule must hold, and nothing may wander in.

// One step toward tile (c, r) of room (mc, mr). Everything the lessons need is walkable here: doors
// only with their key, the exit only as the target. Returns false when there is no way.
tut_step :: proc(b: ^Bot, w: ^game.World, tmc, tmr, tc, tr: int) -> bool {
	for i in 0 ..< NODES {b.dist[i] = -1}
	start := node_of(int(w.player.maze_col), int(w.player.maze_row), int(w.player.col), int(w.player.row))
	goal := node_of(tmc, tmr, tc, tr)
	if start == goal {return false}
	head, tail := 0, 0
	b.queue[tail] = i32(start)
	tail += 1
	b.dist[start] = 0
	b.parent[start] = -1
	for head < tail && b.dist[goal] < 0 {
		cur := int(b.queue[head])
		head += 1
		c := cur % game.MAP_COLS
		r := (cur / game.MAP_COLS) % game.MAP_ROWS
		cell := cur / (game.MAP_COLS * game.MAP_ROWS)
		mc := cell % game.MAZE_COLS
		mr := cell / game.MAZE_COLS
		for d in game.Direction {
			nc := c + game.DIR_DCOL[d]
			nr := r + game.DIR_DROW[d]
			nmc, nmr := mc, mr
			if nc < 0 {nc = game.MAP_COLS - 1; nmc -= 1}
			if nc >= game.MAP_COLS {nc = 0; nmc += 1}
			if nr < 0 {nr = game.MAP_ROWS - 1; nmr -= 1}
			if nr >= game.MAP_ROWS {nr = 0; nmr += 1}
			if nmc < 0 || nmr < 0 || nmc >= game.MAZE_COLS || nmr >= game.MAZE_ROWS {continue}
			if nmc != mc || nmr != mr {
				if !game.terrain_passable(w.cells[mr][mc].map_.tiles[r][c].terrain) {continue}
				if game.portal_of(w, mc, mr, d) == nil {continue}
			}
			n := node_of(nmc, nmr, nc, nr)
			if b.dist[n] >= 0 {continue}
			tl := w.cells[nmr][nmc].map_.tiles[nr][nc]
			if !game.player_can_enter_terrain(tl.terrain) {continue}
			if tl.item == .Exit && n != goal {continue}
			if tl.item != .None && content.ITEMS[tl.item].item_type == .Door {
				open := false
				dd := content.ITEMS[tl.item]
				for k in dd.unlocks.start ..< dd.unlocks.start + dd.unlocks.count {
					if w.inventory[content.COUNT_POOL[k].item] >= content.COUNT_POOL[k].count {open = true}
				}
				if !open {continue}
			}
			b.dist[n] = b.dist[cur] + 1
			b.parent[n] = i32(cur)
			b.queue[tail] = i32(n)
			tail += 1
		}
	}
	if b.dist[goal] < 0 {return false}
	step := goal
	for b.parent[step] != i32(start) {step = int(b.parent[step])}
	sc := step % game.MAP_COLS
	sr := (step / game.MAP_COLS) % game.MAP_ROWS
	sm := step / (game.MAP_COLS * game.MAP_ROWS)
	smc := sm % game.MAZE_COLS
	smr := sm / game.MAZE_COLS
	cmd: game.Command
	switch {
	case smc != int(w.player.maze_col): cmd = .Move_East if smc > int(w.player.maze_col) else .Move_West
	case smr != int(w.player.maze_row): cmd = .Move_South if smr > int(w.player.maze_row) else .Move_North
	case sc > int(w.player.col): cmd = .Move_East
	case sc < int(w.player.col): cmd = .Move_West
	case sr > int(w.player.row): cmd = .Move_South
	case: cmd = .Move_North
	}
	game.step_command(w, cmd)
	return true
}

// Walk (and bump) until `done` holds; fails the test if it takes too long or there is no way.
tut_goto :: proc(t: ^testing.T, b: ^Bot, w: ^game.World, what: string, tmc, tmr, tc, tr: int, until: proc(w: ^game.World) -> bool = nil) {
	for _ in 0 ..< 2000 {
		if w.state != .Play {return}
		if until != nil {
			if until(w) {return}
		} else if int(w.player.maze_col) == tmc && int(w.player.maze_row) == tmr && int(w.player.col) == tc && int(w.player.row) == tr {
			return
		}
		if w.shop.active {return}
		if !tut_step(b, w, tmc, tmr, tc, tr) {
			testing.expectf(t, false, "no way to %s", what)
			return
		}
	}
	testing.expectf(t, false, "gave up on %s", what)
}

new_tut :: proc(t: ^testing.T, seed: u64) -> ^game.World {
	w := new(game.World)
	testing.expect_value(t, game.new_tutorial(w, seed), game.Gen_Error.None)
	return w
}

@(test)
tutorial_level_is_well_formed :: proc(t: ^testing.T) {
	w := new_tut(t, 1)
	defer free(w)
	testing.expect_value(t, w.mode, game.Game_Mode.Tutorial)
	testing.expect_value(t, w.state, game.Play_State.Play)
	testing.expect_value(t, w.creature_count, len(game.TUT_CREATURES))
	testing.expect_value(t, game.quest_required(w), u32(game.TUT_QUEST_PIECES))
	// the fixed kit
	testing.expect_value(t, w.inventory[.Dagger], u32(1))
	testing.expect_value(t, w.inventory[.Food], u32(5))
	testing.expect_value(t, w.inventory[.Potion], u32(3))
	testing.expect_value(t, w.inventory[.Torch], u32(1))
	testing.expect_value(t, w.weapon, content.Item_Kind.Dagger)
	// every item and creature stands on a floor tile
	for it in game.TUT_ITEMS {
		tl := w.cells[it.mr][it.mc].map_.tiles[it.row][it.col]
		testing.expect(t, game.terrain_passable(tl.terrain), "item on a wall")
	}
	// exactly the intended rooms were ever linked
	open := 0
	for i in 0 ..< w.portal_count {if w.portals[i].open {open += 1}}
	testing.expect_value(t, open, len(game.TUT_LINKS))
	// the one locked portal is the red door
	locked := 0
	for i in 0 ..< w.portal_count {if w.portals[i].locked {locked += 1}}
	testing.expect_value(t, locked, 1)
	p := game.portal_of(w, game.TUT_DOOR_MC, game.TUT_DOOR_MR, .East)
	testing.expect(t, p != nil && p.locked && p.open)
	// the first lesson is the one for the start room
	cur := game.tutorial_current(w)
	testing.expect_value(t, cur.lesson, 0)
	testing.expect(t, cur.here)
}

@(test)
tutorial_can_be_completed_with_any_dice :: proc(t: ^testing.T) {
	b := new(Bot)
	defer free(b)
	for seed in 1 ..= u64(8) {
		w := new_tut(t, seed)
		defer free(w)

		// room C: all six gold piles
		for it in game.TUT_ITEMS {
			if it.kind != .Gold {continue}
			tut_goto(t, b, w, "gold", int(it.mc), int(it.mr), int(it.col), int(it.row))
		}
		testing.expect(t, game.money(w) >= 150, "six piles are at least 156 gold")
		// room D: the skeleton, wherever it has wandered
		for _ in 0 ..< 600 {
			c := &w.creatures[0]
			if !c.alive || w.tut.kills >= 1 {break}
			// walk to D first, then bump the skeleton
			if !tut_step(b, w, int(c.maze_col), int(c.maze_row), int(c.col), int(c.row)) {break}
		}
		testing.expect(t, w.tut.kills >= 1, "the skeleton fight never ended")
		// rest once the room is clear
		for _ in 0 ..< 20 {
			if w.tut.rests >= 1 {break}
			game.step_command(w, .Rest)
		}
		testing.expect(t, w.tut.rests >= 1)
		// K: the key
		tut_goto(t, b, w, "key", 2, 1, 7, 7)
		testing.expect(t, game.has_item(w, .RedKey))
		// the door in F, then the shoppe in G
		tut_goto(t, b, w, "door", 3, 2, 14, 7)
		for _ in 0 ..< 10 {
			if w.cells[2][4].visit_count > 0 {break}
			tut_step(b, w, 4, 2, 0, 7)
		}
		testing.expect(t, w.cells[2][4].visit_count > 0, "the red door did not open")
		tut_goto(t, b, w, "shoppe", 4, 2, 8, 7)
		testing.expect(t, w.shop.active, "the shoppe did not open")
		game.step_command(w, .Shop_Buy_One, 0) // torch
		game.step_command(w, .Shop_Buy_One, 1) // tools
		testing.expect_value(t, w.tut.purchases, u32(2))
		game.step_command(w, .Shop_Close)
		testing.expect(t, !w.shop.active)
		testing.expect(t, w.inventory[.Tools] == 1)
		// the shoppe is still there to bump again
		testing.expect_value(t, w.cells[2][4].map_.tiles[7][8].item, content.Item_Kind.TorchShop)

		// H: a row of traps, then I with the zombie
		tut_goto(t, b, w, "trap", 3, 3, 7, 7)
		testing.expect(t, w.tut.done[10], "traps lesson not done")
		for _ in 0 ..< 600 {
			c := &w.creatures[1]
			if !c.alive || w.tut.kills >= 2 {break}
			if !tut_step(b, w, int(c.maze_col), int(c.maze_row), int(c.col), int(c.row)) {break}
		}
		testing.expect(t, w.tut.kills >= 2, "the zombie fight never ended")
		tut_goto(t, b, w, "piece 1", 4, 4, 6, 7)
		tut_goto(t, b, w, "piece 2", 4, 4, 9, 7)
		tut_goto(t, b, w, "rainbow key", 2, 4, 7, 7)
		tut_goto(t, b, w, "the exit", 3, 5, 7, 7)
		testing.expect_value(t, w.state, game.Play_State.Win)
		for i in 0 ..< len(game.TUT_LESSONS) {
			testing.expectf(t, w.tut.done[i], "seed %d: lesson %d (%s) not done", seed, i, game.TUT_LESSONS[i].title)
		}
		// nothing wandered in
		testing.expect_value(t, w.creature_count, len(game.TUT_CREATURES))
	}
}

@(test)
tutorial_lessons_follow_the_player :: proc(t: ^testing.T) {
	w := new_tut(t, 3)
	defer free(w)
	cur := game.tutorial_current(w)
	testing.expect_value(t, cur.lesson, 0)
	// walk into B by hand: eight steps east from (3,7) reaches the doorway and beyond
	for _ in 0 ..< 14 {game.step_command(w, .Move_East)}
	testing.expect_value(t, int(w.player.maze_col), 1)
	cur = game.tutorial_current(w)
	testing.expect_value(t, cur.lesson, 1)
	testing.expect(t, cur.here)
	// go back: the first lesson is done, so the pointer is the next unfinished one, here or not
	for _ in 0 ..< 15 {game.step_command(w, .Move_West)}
	testing.expect_value(t, int(w.player.maze_col), 0)
	cur = game.tutorial_current(w)
	testing.expect_value(t, cur.lesson, 1)
	testing.expect(t, !cur.here)
	dir, ok := game.tutorial_direction(w, int(game.TUT_LESSONS[cur.lesson].col), int(game.TUT_LESSONS[cur.lesson].row))
	testing.expect(t, ok)
	testing.expect_value(t, dir, game.Direction.East)
	// to the key room from the start: east first
	dir, ok = game.tutorial_direction(w, 2, 1)
	testing.expect(t, ok)
	testing.expect_value(t, dir, game.Direction.East)
	// from the hall of gold (C) toward the exit: still east (D, then south)
	w.player.maze_col = 2
	w.player.maze_row = 0
	dir, ok = game.tutorial_direction(w, 3, 5)
	testing.expect(t, ok)
	testing.expect_value(t, dir, game.Direction.East)
	// from D toward the exit: south
	w.player.maze_col = 3
	dir, ok = game.tutorial_direction(w, 3, 5)
	testing.expect(t, ok)
	testing.expect_value(t, dir, game.Direction.South)
	_, ok = game.tutorial_direction(w, 3, 0)
	testing.expect(t, !ok) // already there
}

@(test)
tutorial_mercy_never_ends_the_run :: proc(t: ^testing.T) {
	w := new_tut(t, 5)
	defer free(w)
	// stand in D as if just arrived, with the skeleton away from home and hurt-proof
	w.player.maze_col = 3
	w.player.maze_row = 0
	w.player.col = 0
	w.player.row = 7
	game.tutorial_note_entry(w)
	m := &w.cells[0][3].map_
	sk := &w.creatures[0]
	m.tiles[sk.row][sk.col].creature = 0
	sk.col, sk.row = 2, 7
	m.tiles[7][2].creature = 1
	w.inventory[.Potion] = 0
	w.inventory[.Food] = 0
	w.player.col = 5
	game.take_damage(w, 99, 0)
	testing.expect_value(t, w.state, game.Play_State.Play)
	testing.expect_value(t, w.wounds, i32(0))
	testing.expect(t, w.tut.mercy)
	testing.expect_value(t, w.tut.mercies, u32(1))
	testing.expect_value(t, int(w.player.col), 0)
	testing.expect_value(t, int(w.player.row), 7)
	// the skeleton is back home and the kit topped up
	testing.expect_value(t, int(sk.col), 9)
	testing.expect_value(t, int(sk.row), 5)
	testing.expect_value(t, m.tiles[5][9].creature, i16(1))
	testing.expect_value(t, m.tiles[7][2].creature, i16(0))
	testing.expect_value(t, w.inventory[.Potion], u32(3))
	testing.expect_value(t, w.inventory[.Food], u32(5))
	// the flag is the UI's to read for one command only
	game.step_command(w, .Move_East)
	testing.expect(t, !w.tut.mercy)
}

@(test)
tutorial_has_no_wandering_monsters_or_tips :: proc(t: ^testing.T) {
	w := new_tut(t, 9)
	defer free(w)
	for _ in 0 ..< 60 {game.step_command(w, .Rest)}
	testing.expect_value(t, w.creature_count, len(game.TUT_CREATURES))
	for i in 0 ..< w.event_count {
		testing.expect(t, w.events[i].kind != .Tutorial, "pop-up tips are off in the tutorial")
	}
	// normal games keep their rules
	n := new(game.World)
	defer free(n)
	testing.expect_value(t, game.new_game(n, 4), game.Gen_Error.None)
	testing.expect_value(t, n.mode, game.Game_Mode.Normal)
	testing.expect_value(t, game.quest_required(n), game.quest_item_total())
}

// The voice (vault rule, D32): "yer", never "your" or "you're", in anything the player reads.
has_word :: proc(s, word: string) -> bool {
	lower := make([]u8, len(s))
	defer delete(lower)
	for i in 0 ..< len(s) {
		c := s[i]
		if c >= 'A' && c <= 'Z' {c += 32}
		lower[i] = c
	}
	l := string(lower)
	for i in 0 ..= len(l) - len(word) {
		if l[i:i + len(word)] != word {continue}
		before_ok := i == 0 || !(l[i - 1] >= 'a' && l[i - 1] <= 'z')
		j := i + len(word)
		after_ok := j >= len(l) || !(l[j] >= 'a' && l[j] <= 'z')
		if before_ok && after_ok {return true}
	}
	return false
}

@(test)
text_uses_the_yer_voice :: proc(t: ^testing.T) {
	for m in content.Message_Id {
		d := content.MESSAGES[m]
		for s in ([?]string{d.text, d.tutorial_title, d.tutorial_text}) {
			testing.expectf(t, !has_word(s, "your") && !has_word(s, "you're"), "message %v says your/you're: %s", m, s)
		}
	}
	for l in game.TUT_LESSONS {
		testing.expectf(t, !has_word(l.title, "your") && !has_word(l.text, "your") && !has_word(l.text, "you're"), "lesson says your: %s", l.title)
	}
}
