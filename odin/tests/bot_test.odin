#+build !js
package tests

import "core:log"
import "core:testing"
import content "../content"
import game "../game"

// A bot that plays with full knowledge of the world. It is not meant to be good, only to reach the
// deep parts of the rules (keys and doors, shops, quest pieces, bosses) so the invariants are checked
// there and not only in the first dozen turns.

NODES :: game.MAZE_COLS * game.MAZE_ROWS * game.MAP_COLS * game.MAP_ROWS

node_of :: proc(mc, mr, c, r: int) -> int {
	return ((mr * game.MAZE_COLS + mc) * game.MAP_ROWS + r) * game.MAP_COLS + c
}

Bot :: struct {
	dist:   [NODES]i32,
	parent: [NODES]i32,
	queue:  [NODES]i32,
}

node_passable :: proc(w: ^game.World, mc, mr, c, r: int, allow_exit: bool) -> bool {
	tl := w.cells[mr][mc].map_.tiles[r][c]
	if !game.player_can_enter_terrain(tl.terrain) {return false}
	if tl.item == .None {return true}
	d := content.ITEMS[tl.item]
	#partial switch d.item_type {
	case .Door:
		for i in d.unlocks.start ..< d.unlocks.start + d.unlocks.count {
			e := content.COUNT_POOL[i]
			if w.inventory[e.item] >= e.count {return true}
		}
		return false
	case .Trap, .Hidden, .Portal, .Amulet:
		return false
	case .Exit:
		return allow_exit
	}
	return true
}

wanted_item :: proc(w: ^game.World, kind: content.Item_Kind) -> bool {
	#partial switch content.ITEMS[kind].item_type {
	case .Quest, .Key, .RainbowKey, .Weapon, .Armor, .Treasure, .Healing, .Light, .Tools, .Shop, .Chest, .Compass:
		return true
	}
	return false
}

// Returns the command that takes the first step toward the nearest target, or .None.
bot_choose :: proc(b: ^Bot, w: ^game.World) -> game.Command {
	if w.wounds > 0 && !game.map_has_creature(w) && w.inventory[.Food] == 0 {return .Rest}
	quest := w.inventory[content.PLAYER.quest_item]
	total := game.quest_item_total()
	exit_ready := quest == total && w.inventory[.RainbowKey] > 0
	hunt_summoner := quest == total && w.inventory[.RainbowKey] == 0

	for i in 0 ..< NODES {b.dist[i] = -1}
	start := node_of(int(w.player.maze_col), int(w.player.maze_row), int(w.player.col), int(w.player.row))
	head, tail := 0, 0
	b.queue[tail] = i32(start)
	tail += 1
	b.dist[start] = 0
	b.parent[start] = -1
	found := -1
	for head < tail && found < 0 {
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
			if (nmc != mc || nmr != mr) {
				// crossing needs the doorway tile on this side to be passable
				if !game.terrain_passable(w.cells[mr][mc].map_.tiles[r][c].terrain) {continue}
			}
			n := node_of(nmc, nmr, nc, nr)
			if b.dist[n] >= 0 {continue}
			if !node_passable(w, nmc, nmr, nc, nr, exit_ready) {continue}
			b.dist[n] = b.dist[cur] + 1
			b.parent[n] = i32(cur)
			b.queue[tail] = i32(n)
			tail += 1
			tl := w.cells[nmr][nmc].map_.tiles[nr][nc]
			good := false
			if tl.item != .None && wanted_item(w, tl.item) {good = true}
			if tl.item == .Exit && exit_ready {good = true}
			if tl.creature != 0 {
				kind := w.creatures[tl.creature - 1].kind
				if hunt_summoner && kind == .Summoner {good = true}
				if !hunt_summoner && !exit_ready && kind != .Dragon && kind != .Minotaur {good = true}
			}
			if good {
				found = n
				break
			}
		}
	}
	if found < 0 {return .None}
	step := found
	for b.parent[step] != i32(start) && b.parent[step] >= 0 {step = int(b.parent[step])}
	pc := int(w.player.col)
	pr := int(w.player.row)
	sc := step % game.MAP_COLS
	sr := (step / game.MAP_COLS) % game.MAP_ROWS
	sm := step / (game.MAP_COLS * game.MAP_ROWS)
	smc := sm % game.MAZE_COLS
	if smc != int(w.player.maze_col) {
		return .Move_East if smc > int(w.player.maze_col) else .Move_West
	}
	if sm / game.MAZE_COLS != int(w.player.maze_row) {
		return .Move_South if sm / game.MAZE_COLS > int(w.player.maze_row) else .Move_North
	}
	if sc > pc {return .Move_East}
	if sc < pc {return .Move_West}
	if sr > pr {return .Move_South}
	return .Move_North
}

@(test)
bot_reaches_the_deep_rules :: proc(t: ^testing.T) {
	b := new(Bot)
	defer free(b)
	doors, shops, quests, wins, losses, kills, levels := 0, 0, 0, 0, 0, 0, 0
	for seed in 1 ..= u64(12) {
		w := new(game.World)
		defer free(w)
		testing.expect_value(t, game.new_game(w, seed), game.Gen_Error.None)
		locked0 := 0
		for i in 0 ..< w.portal_count {if w.portals[i].locked {locked0 += 1}}
		pick: game.Rng
		game.rng_seed(&pick, seed)
		for step in 0 ..< 6000 {
			if w.state != .Play {break}
			if w.shop.active {
				shops += 1
				for slot in 0 ..< w.shop.count {
					for _ in 0 ..< 4 {game.step_command(w, .Shop_Buy_One, slot)}
				}
				game.step_command(w, .Shop_Close)
				continue
			}
			cmd := bot_choose(b, w)
			if cmd == .None {
				cmd = game.Command(int(game.Command.Move_North) + game.rng_int(&pick, 4))
			}
			game.step_command(w, cmd)
			if step % 100 == 0 {check_world_invariants(t, w, seed)}
		}
		check_world_invariants(t, w, seed)
		locked1 := 0
		for i in 0 ..< w.portal_count {if w.portals[i].locked {locked1 += 1}}
		doors += locked0 - locked1
		quests += int(w.inventory[.Quest])
		levels += int(w.level)
		if w.state == .Win {wins += 1}
		if w.state == .Lose {losses += 1}
		kills += 0
	}
	log.infof("bot: doors opened %d, shops visited %d, quest pieces %d, levels %d, wins %d, losses %d of 12", doors, shops, quests, levels, wins, losses)
	testing.expect(t, doors > 0, "the bot never opened a door")
	testing.expect(t, quests > 0, "the bot never collected a quest piece")
	testing.expect(t, levels > 0, "the bot never gained a level")
	_ = kills
}
