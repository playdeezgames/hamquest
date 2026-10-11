#+build !js
package tests

import "core:mem"
import "core:testing"
import content "../content"
import game "../game"

SEEDS :: 200

@(test)
rng_matches_reference_vectors :: proc(t: ^testing.T) {
	// Computed with an independent Python implementation of splitmix64 + xoshiro256**.
	r: game.Rng
	game.rng_seed(&r, 0)
	want0 := [4]u64{0x99ec5f36cb75f2b4, 0xbf6e1f784956452a, 0x1a5f849d4933e6e0, 0x6aa594f1262d2d2c}
	for w in want0 {testing.expect_value(t, game.rng_u64(&r), w)}
	game.rng_seed(&r, 12345)
	want1 := [4]u64{0xbe6a36374160d49b, 0x214aaa0637a688c6, 0xf69d16de9954d388, 0x0c60048c4e96e033}
	for w in want1 {testing.expect_value(t, game.rng_u64(&r), w)}
}

@(test)
rng_bounds_and_spread :: proc(t: ^testing.T) {
	r: game.Rng
	game.rng_seed(&r, 99)
	counts: [6]int
	for _ in 0 ..< 60000 {
		v := game.rng_int(&r, 6)
		testing.expect(t, v >= 0 && v < 6)
		counts[v] += 1
	}
	for c in counts {testing.expectf(t, c > 9000 && c < 11000, "uneven die: %v", counts)}
	for _ in 0 ..< 1000 {
		v := game.rng_range(&r, 1, 13)
		testing.expect(t, v >= 1 && v <= 13)
	}
	testing.expect_value(t, game.rng_int(&r, 0), 0)
}

@(test)
weighted_pick_follows_weights :: proc(t: ^testing.T) {
	// white-die-1 is {0: weight 2, 1: weight 1}
	r: game.Rng
	game.rng_seed(&r, 7)
	rg := content.GENERATORS[.WhiteDie1]
	ones := 0
	n := 30000
	for _ in 0 ..< n {
		if game.pick_weighted(&r, rg) == 1 {ones += 1}
	}
	testing.expectf(t, ones > n / 3 - 600 && ones < n / 3 + 600, "ones = %d of %d", ones, n)
}

@(test)
spawn_chains_settle :: proc(t: ^testing.T) {
	// following spawn_as must reach a fixed point without a cycle longer than a self loop
	for kind in content.Item_Kind {
		if kind == .None {continue}
		seen: [len(content.Item_Kind)]bool
		stack: [len(content.Item_Kind)]content.Item_Kind
		sp := 0
		stack[sp] = kind
		sp += 1
		seen[int(kind)] = true
		for sp > 0 {
			sp -= 1
			cur := stack[sp]
			rg := content.ITEMS[cur].spawn_as
			for i in rg.start ..< rg.start + rg.count {
				next := content.Item_Kind(content.WEIGHT_POOL[i].value)
				if next == cur || next == .None {continue}
				// a path that comes back to `kind` is a cycle
				testing.expectf(t, next != kind, "spawn_as cycle through %v and %v", kind, cur)
				if !seen[int(next)] {
					seen[int(next)] = true
					stack[sp] = next
					sp += 1
				}
			}
		}
	}
}

new_world :: proc(t: ^testing.T, seed: u64) -> (w: ^game.World, ok: bool) {
	w = new(game.World)
	err := game.generate(w, seed)
	testing.expectf(t, err == .None, "seed %d: %v", seed, err)
	return w, err == .None
}

EDGE_TILE := [game.Direction][2]int {
	.North = {7, 0},
	.East  = {14, 7},
	.South = {7, 14},
	.West  = {0, 7},
}

@(test)
world_is_deterministic :: proc(t: ^testing.T) {
	a := new(game.World)
	b := new(game.World)
	c := new(game.World)
	defer free(a)
	defer free(b)
	defer free(c)
	testing.expect_value(t, game.generate(a, 4242), game.Gen_Error.None)
	testing.expect_value(t, game.generate(b, 4242), game.Gen_Error.None)
	testing.expect_value(t, game.generate(c, 4243), game.Gen_Error.None)
	testing.expect(t, mem.compare_ptrs(a, b, size_of(game.World)) == 0, "same seed produced different worlds")
	testing.expect(t, mem.compare_ptrs(a, c, size_of(game.World)) != 0, "different seeds produced the same world")
}

@(test)
maze_is_a_spanning_tree :: proc(t: ^testing.T) {
	for seed in 1 ..= u64(SEEDS) {
		w, ok := new_world(t, seed)
		defer free(w)
		if !ok {continue}
		open := 0
		for i in 0 ..< w.portal_count {
			if w.portals[i].open {open += 1}
		}
		testing.expectf(t, open == game.MAZE_COLS * game.MAZE_ROWS - 1, "seed %d: %d open portals", seed, open)
		// BFS over open portals reaches every cell
		seen: [game.MAZE_ROWS][game.MAZE_COLS]bool
		queue: [game.MAZE_ROWS * game.MAZE_COLS][2]int
		head, tail := 0, 1
		queue[0] = {0, 0}
		seen[0][0] = true
		for head < tail {
			cur := queue[head]
			head += 1
			for d in game.Direction {
				p := game.portal_of(w, cur.x, cur.y, d)
				if p == nil || !p.open {continue}
				nc := cur.x + game.DIR_DCOL[d]
				nr := cur.y + game.DIR_DROW[d]
				if !seen[nr][nc] {
					seen[nr][nc] = true
					queue[tail] = {nc, nr}
					tail += 1
				}
			}
		}
		testing.expectf(t, tail == game.MAZE_COLS * game.MAZE_ROWS, "seed %d: maze not connected (%d)", seed, tail)
	}
}

@(test)
locks_doors_and_keys_line_up :: proc(t: ^testing.T) {
	for seed in 1 ..= u64(SEEDS) {
		w, ok := new_world(t, seed)
		defer free(w)
		if !ok {continue}
		locked_total := 0
		leaves := 0
		locks_by_type: [game.LOCK_TYPES]int
		for row in 0 ..< game.MAZE_ROWS {
			for col in 0 ..< game.MAZE_COLS {
				c := &w.cells[row][col]
				open := 0
				for d in game.Direction {
					p := game.portal_of(w, col, row, d)
					if p != nil && p.open {open += 1}
				}
				testing.expect_value(t, int(c.open_count), open)
				testing.expect_value(t, c.dead_end, open == 1)
				if !c.dead_end {continue}
				leaves += 1
				for d in game.Direction {
					p := game.portal_of(w, col, row, d)
					if p == nil || !p.open {continue}
					testing.expectf(t, p.locked && p.lock_type >= 0, "seed %d: leaf (%d,%d) portal not locked", seed, col, row)
					locked_total += 1
					locks_by_type[p.lock_type] += 1
					// the door sits in the neighbour, on the side facing the leaf
					nc := col + game.DIR_DCOL[d]
					nr := row + game.DIR_DROW[d]
					found := 0
					for tr in 0 ..< game.MAP_ROWS {
						for tc in 0 ..< game.MAP_COLS {
							k := w.cells[nr][nc].map_.tiles[tr][tc].item
							if k == .None {continue}
							def := content.ITEMS[k]
							if def.item_type == .Door && def.direction == i32(game.opposite(d)) {
								found += 1
								testing.expect_value(t, def.lock_type, i32(p.lock_type))
								// a door stands in its doorway
								edge := EDGE_TILE[game.opposite(d)]
								testing.expect_value(t, tc, edge[0])
								testing.expect_value(t, tr, edge[1])
							}
						}
					}
					testing.expectf(t, found == 1, "seed %d: %d doors for the portal of leaf (%d,%d)", seed, found, col, row)
				}
			}
		}
		testing.expect_value(t, locked_total, leaves)
		// every other portal is unlocked
		locked_portals := 0
		for i in 0 ..< w.portal_count {
			if w.portals[i].locked {locked_portals += 1}
		}
		testing.expect_value(t, locked_portals, leaves)
		// keys: one per lock, of the right type, never in a dead end
		keys_by_type: [game.LOCK_TYPES]int
		for row in 0 ..< game.MAZE_ROWS {
			for col in 0 ..< game.MAZE_COLS {
				for tr in 0 ..< game.MAP_ROWS {
					for tc in 0 ..< game.MAP_COLS {
						k := w.cells[row][col].map_.tiles[tr][tc].item
						if k == .None {continue}
						def := content.ITEMS[k]
						if def.item_type == .Key {
							keys_by_type[def.lock_type] += 1
							testing.expectf(t, !w.cells[row][col].dead_end, "seed %d: key in a dead end", seed)
						}
					}
				}
			}
		}
		testing.expect_value(t, keys_by_type, locks_by_type)
	}
}

@(test)
items_and_creatures_are_placed_legally :: proc(t: ^testing.T) {
	expected_items := 0
	for kind in content.Item_Kind {
		d := content.ITEMS[kind]
		if kind != .None && d.item_count > 0 && d.placement != .None {expected_items += int(d.item_count)}
	}
	expected_creatures := 0
	for kind in content.Creature_Kind {
		d := content.CREATURES[kind]
		if kind != .None && !d.is_player && d.placement != .None {expected_creatures += int(d.creature_count)}
	}
	max_tries := 0
	fallbacks := 0
	for seed in 1 ..= u64(SEEDS) {
		w, ok := new_world(t, seed)
		defer free(w)
		if !ok {continue}
		if w.stats.random_tries_max > max_tries {max_tries = w.stats.random_tries_max}
		fallbacks += w.stats.fallback_scans
		item_tiles := 0
		doors_and_keys := 0
		creature_tiles := 0
		quest, exits := 0, 0
		for row in 0 ..< game.MAZE_ROWS {
			for col in 0 ..< game.MAZE_COLS {
				c := &w.cells[row][col]
				for tr in 0 ..< game.MAP_ROWS {
					for tc in 0 ..< game.MAP_COLS {
						tile := c.map_.tiles[tr][tc]
						testing.expectf(t, content.TERRAIN_DEFINED[tile.terrain], "seed %d: undefined terrain", seed)
						if tile.item != .None {
							item_tiles += 1
							def := content.ITEMS[tile.item]
							testing.expectf(t, game.terrain_passable(tile.terrain), "seed %d: item on a wall", seed)
							testing.expect_value(t, tile.creature, 0)
							#partial switch def.item_type {
							case .Door, .Key:
								doors_and_keys += 1
							case .Quest:
								quest += 1
								testing.expectf(t, c.dead_end, "seed %d: quest item outside a dead end", seed)
							case .Exit:
								exits += 1
								testing.expectf(t, c.dead_end, "seed %d: exit outside a dead end", seed)
							}
						}
						if tile.creature != 0 {
							creature_tiles += 1
							cr := w.creatures[tile.creature - 1]
							testing.expect_value(t, int(cr.col), tc)
							testing.expect_value(t, int(cr.row), tr)
							testing.expect_value(t, int(cr.maze_col), col)
							testing.expect_value(t, int(cr.maze_row), row)
							testing.expectf(t, tc >= 1 && tc <= 13 && tr >= 1 && tr <= 13, "seed %d: creature on the edge ring", seed)
							testing.expect(t, game.terrain_passable(tile.terrain))
							if content.CREATURES[cr.kind].placement == .DeadEnd {
								testing.expect(t, c.dead_end)
							}
						}
					}
				}
			}
		}
		testing.expect_value(t, item_tiles - doors_and_keys, expected_items)
		testing.expect_value(t, creature_tiles, expected_creatures)
		testing.expect_value(t, w.creature_count, expected_creatures)
		testing.expect_value(t, exits, 1)
		testing.expect_value(t, quest, int(content.ITEMS[.Quest].item_count))
	}
	testing.expectf(t, max_tries < game.RANDOM_TRIES, "random placement needed %d tries", max_tries)
	testing.expectf(t, fallbacks == 0, "the deterministic fallback ran %d times", fallbacks)
}

@(test)
player_starts_somewhere_safe :: proc(t: ^testing.T) {
	for seed in 1 ..= u64(SEEDS) {
		w, ok := new_world(t, seed)
		defer free(w)
		if !ok {continue}
		p := w.player
		c := &w.cells[p.maze_row][p.maze_col]
		testing.expectf(t, !c.dead_end, "seed %d: player starts in a dead end", seed)
		tile := c.map_.tiles[p.row][p.col]
		testing.expect(t, game.terrain_passable(tile.terrain))
		testing.expect_value(t, tile.item, content.Item_Kind.None)
		testing.expect_value(t, tile.creature, i16(0))
		testing.expect_value(t, c.visit_count, i32(1))
	}
}

@(test)
terrain_doorways_follow_portals :: proc(t: ^testing.T) {
	for seed in 1 ..= u64(SEEDS) {
		w, ok := new_world(t, seed)
		defer free(w)
		if !ok {continue}
		for row in 0 ..< game.MAZE_ROWS {
			for col in 0 ..< game.MAZE_COLS {
				for d in game.Direction {
					p := game.portal_of(w, col, row, d)
					open := p != nil && p.open
					edge := EDGE_TILE[d]
					tile := w.cells[row][col].map_.tiles[edge[1]][edge[0]]
					testing.expectf(
						t,
						game.terrain_passable(tile.terrain) == open,
						"seed %d cell (%d,%d) %v: doorway passable=%v but portal open=%v",
						seed, col, row, d, game.terrain_passable(tile.terrain), open,
					)
				}
			}
		}
	}
}

@(test)
start_inventory_is_rolled :: proc(t: ^testing.T) {
	total := 0
	for seed in 1 ..= u64(SEEDS) {
		w, ok := new_world(t, seed)
		defer free(w)
		if !ok {continue}
		for n in w.start_inventory {total += int(n)}
	}
	testing.expectf(t, total > 0, "no seed gave the player any starting item")
}
