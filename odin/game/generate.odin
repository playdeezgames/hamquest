package game

import content "../content"

// World generation (M3). Mirrors the structure of the original Maze.populateMaze and Map.Generate
// (see docs/game-reference.md section 2): a random spanning tree maze, locks on every dead end,
// doors beside them, keys in cells that are not dead ends, items and creatures by placement rule,
// and the player in a cell that is not a dead end. All searches are bounded (A8).

RANDOM_TRIES :: 200
CHAIN_LIMIT :: 32

Generator :: struct {
	w:             ^World,
	leaves:        [MAZE_COLS * MAZE_ROWS][2]u8, // (col,row)
	leaf_count:    int,
	inner:         [MAZE_COLS * MAZE_ROWS][2]u8,
	inner_count:   int,
	lock_weight:   [LOCK_TYPES]u32,
	lock_total:    u32,
	key_for_lock:  [LOCK_TYPES]content.Item_Kind,
	door_for:      [LOCK_TYPES][Direction]content.Item_Kind,
	err:           Gen_Error,
}

generate :: proc(w: ^World, seed: u64) -> Gen_Error {
	w^ = {}
	w.seed = seed
	rng_seed(&w.rng, seed)
	g := Generator{w = w}
	build_item_tables(&g)
	build_portals(w)
	carve_maze(w)
	classify_cells(&g)
	if g.inner_count == 0 {return .No_Cells}
	for row in 0 ..< MAZE_ROWS {
		for col in 0 ..< MAZE_COLS {
			assemble_terrain(w, col, row)
		}
	}
	place_locks_and_doors(&g)
	if g.err != .None {return g.err}
	place_keys(&g)
	if g.err != .None {return g.err}
	place_items(&g)
	if g.err != .None {return g.err}
	place_creatures(&g)
	if g.err != .None {return g.err}
	place_player(&g)
	if g.err != .None {return g.err}
	roll_start_inventory(w)
	return .None
}

build_item_tables :: proc(g: ^Generator) {
	for kind in content.Item_Kind {
		if kind == .None {continue}
		d := content.ITEMS[kind]
		#partial switch d.item_type {
		case .Key:
			if d.lock_type >= 0 && d.lock_type < LOCK_TYPES {
				g.lock_weight[d.lock_type] = u32(d.lock_type_weight)
				g.lock_total += u32(d.lock_type_weight)
				if g.key_for_lock[d.lock_type] == .None {g.key_for_lock[d.lock_type] = kind}
			}
		case .Door:
			if d.lock_type >= 0 && d.lock_type < LOCK_TYPES && d.direction >= 0 && d.direction < 4 {
				g.door_for[d.lock_type][Direction(d.direction)] = kind
			}
		}
	}
}

build_portals :: proc(w: ^World) {
	for row in 0 ..< MAZE_ROWS {
		for col in 0 ..< MAZE_COLS {
			for d in Direction {
				w.cells[row][col].portal[d] = -1
			}
		}
	}
	for row in 0 ..< MAZE_ROWS {
		for col in 0 ..< MAZE_COLS {
			for d in Direction {
				if w.cells[row][col].portal[d] >= 0 {continue}
				nc := col + DIR_DCOL[d]
				nr := row + DIR_DROW[d]
				if nc < 0 || nr < 0 || nc >= MAZE_COLS || nr >= MAZE_ROWS {continue}
				idx := i16(w.portal_count)
				w.portal_count += 1
				w.portals[idx] = Portal{lock_type = -1}
				w.cells[row][col].portal[d] = idx
				w.cells[nr][nc].portal[opposite(d)] = idx
			}
		}
	}
}

// Randomised Prim's algorithm on the grid; every cell ends up inside, so open portals form a
// spanning tree (no loops, every cell reachable).
carve_maze :: proc(w: ^World) {
	Cell_State :: enum u8 {
		Outside,
		Frontier,
		Inside,
	}
	state: [MAZE_ROWS][MAZE_COLS]Cell_State
	frontier: [MAZE_COLS * MAZE_ROWS][2]u8
	n := 0

	mark_neighbours :: proc(state: ^[MAZE_ROWS][MAZE_COLS]Cell_State, frontier: ^[MAZE_COLS * MAZE_ROWS][2]u8, n: ^int, col, row: int) {
		for d in Direction {
			nc := col + DIR_DCOL[d]
			nr := row + DIR_DROW[d]
			if nc < 0 || nr < 0 || nc >= MAZE_COLS || nr >= MAZE_ROWS {continue}
			if state[nr][nc] == .Outside {
				state[nr][nc] = .Frontier
				frontier[n^] = {u8(nc), u8(nr)}
				n^ += 1
			}
		}
	}

	sc := rng_int(&w.rng, MAZE_COLS)
	sr := rng_int(&w.rng, MAZE_ROWS)
	state[sr][sc] = .Inside
	mark_neighbours(&state, &frontier, &n, sc, sr)
	for n > 0 {
		pick := rng_int(&w.rng, n)
		col := int(frontier[pick][0])
		row := int(frontier[pick][1])
		frontier[pick] = frontier[n - 1]
		n -= 1
		state[row][col] = .Inside
		options: [4]Direction
		count := 0
		for d in Direction {
			nc := col + DIR_DCOL[d]
			nr := row + DIR_DROW[d]
			if nc < 0 || nr < 0 || nc >= MAZE_COLS || nr >= MAZE_ROWS {continue}
			// a neighbour already inside (not merely the frontier cell just marked) can be joined
			if state[nr][nc] == .Inside {
				options[count] = d
				count += 1
			}
		}
		d := options[rng_int(&w.rng, count)]
		w.portals[w.cells[row][col].portal[d]].open = true
		mark_neighbours(&state, &frontier, &n, col, row)
	}
}

classify_cells :: proc(g: ^Generator) {
	w := g.w
	for row in 0 ..< MAZE_ROWS {
		for col in 0 ..< MAZE_COLS {
			c := &w.cells[row][col]
			open := 0
			for d in Direction {
				if c.portal[d] >= 0 && w.portals[c.portal[d]].open {open += 1}
			}
			c.open_count = u8(open)
			c.dead_end = open == 1
			total := content.ROOM_CHANCE_TOTAL
			chance := content.ROOM_CHANCE_BY_DOORS[open]
			if int(rng_below(&w.rng, u64(total))) < int(chance) {
				c.cell_type = .Room
			} else {
				c.cell_type = .Passageway
			}
			if c.dead_end {
				g.leaves[g.leaf_count] = {u8(col), u8(row)}
				g.leaf_count += 1
			} else {
				g.inner[g.inner_count] = {u8(col), u8(row)}
				g.inner_count += 1
			}
		}
	}
}

// Terrain of a cell: blend the passage or room layers; 255 is transparent in overlays.
assemble_terrain :: proc(w: ^World, col, row: int) {
	c := &w.cells[row][col]
	blend :: proc(dst: ^Map, layer: ^content.Map_Layer) {
		for r in 0 ..< MAP_ROWS {
			for cc in 0 ..< MAP_COLS {
				if layer[r][cc] != 255 {dst.tiles[r][cc].terrain = layer[r][cc]}
			}
		}
	}
	m := &c.map_
	switch c.cell_type {
	case .Passageway:
		mask := 0
		for d in Direction {
			p := portal_of(w, col, row, d)
			if p != nil && p.open {mask |= 1 << uint(d)}
		}
		blend(m, &content.MAP_PWAY[mask])
		for d in Direction {
			p := portal_of(w, col, row, d)
			if p != nil && p.open && p.locked {blend(m, &content.MAP_PWAY_DOOR[int(d)])}
		}
	case .Room:
		blend(m, &content.MAP_ROOM)
		for d in Direction {
			p := portal_of(w, col, row, d)
			if p != nil && p.open {
				if p.locked {
					blend(m, &content.MAP_ROOM_DOOR[int(d)])
				} else {
					blend(m, &content.MAP_ROOM_OPEN[int(d)])
				}
			}
		}
	}
}

tile_free :: proc(m: ^Map, col, row: int) -> bool {
	t := m.tiles[row][col]
	return terrain_passable(t.terrain) && t.item == .None && t.creature == 0
}

// Put `kind` on a free tile drawn from the item's x and y generators; on failure fall back to a
// deterministic scan of every tile those generators can produce.
place_on_item_tile :: proc(g: ^Generator, col, row: int, listed, put: content.Item_Kind) -> bool {
	w := g.w
	m := &w.cells[row][col].map_
	d := content.ITEMS[listed]
	for tries in 1 ..= RANDOM_TRIES {
		tc := int(pick_weighted(&w.rng, d.x_gen))
		tr := int(pick_weighted(&w.rng, d.y_gen))
		if tc < 0 || tr < 0 || tc >= MAP_COLS || tr >= MAP_ROWS {continue}
		if tile_free(m, tc, tr) {
			m.tiles[tr][tc].item = put
			if tries > w.stats.random_tries_max {w.stats.random_tries_max = tries}
			return true
		}
	}
	w.stats.fallback_scans += 1
	for yi in d.y_gen.start ..< d.y_gen.start + d.y_gen.count {
		if content.WEIGHT_POOL[yi].weight == 0 {continue}
		for xi in d.x_gen.start ..< d.x_gen.start + d.x_gen.count {
			if content.WEIGHT_POOL[xi].weight == 0 {continue}
			tc := int(content.WEIGHT_POOL[xi].value)
			tr := int(content.WEIGHT_POOL[yi].value)
			if tc < 0 || tr < 0 || tc >= MAP_COLS || tr >= MAP_ROWS {continue}
			if tile_free(m, tc, tr) {
				m.tiles[tr][tc].item = put
				return true
			}
		}
	}
	return false
}

// Follow spawn_as until it names the item itself: this is how a generic item becomes a specific one.
resolve_spawn :: proc(g: ^Generator, kind: content.Item_Kind) -> (content.Item_Kind, bool) {
	cur := kind
	for _ in 0 ..< CHAIN_LIMIT {
		next := content.Item_Kind(pick_weighted(&g.w.rng, content.ITEMS[cur].spawn_as))
		if next == .None || next == cur {return cur, true}
		cur = next
	}
	return cur, false
}

place_locks_and_doors :: proc(g: ^Generator) {
	w := g.w
	if g.lock_total == 0 {
		return
	}
	for i in 0 ..< g.leaf_count {
		col := int(g.leaves[i][0])
		row := int(g.leaves[i][1])
		c := &w.cells[row][col]
		for d in Direction {
			if c.portal[d] < 0 {continue}
			p := &w.portals[c.portal[d]]
			if !p.open {continue}
			// pick a lock type by weight
			roll := u32(rng_below(&w.rng, u64(g.lock_total)))
			lt := 0
			for t in 0 ..< LOCK_TYPES {
				if roll < g.lock_weight[t] {
					lt = t
					break
				}
				roll -= g.lock_weight[t]
			}
			p.locked = true
			p.lock_type = i8(lt)
			nc := col + DIR_DCOL[d]
			nr := row + DIR_DROW[d]
			door := g.door_for[lt][opposite(d)]
			if door == .None || !place_on_item_tile(g, nc, nr, door, door) {
				g.err = .No_Space
				return
			}
			// the locked portal changes the terrain of both cells (door layers)
			assemble_terrain(w, col, row)
			assemble_terrain(w, nc, nr)
		}
	}
}

place_keys :: proc(g: ^Generator) {
	w := g.w
	for i in 0 ..< w.portal_count {
		p := w.portals[i]
		if !p.locked {continue}
		key := g.key_for_lock[p.lock_type]
		pos := g.inner[rng_int(&w.rng, g.inner_count)]
		if key == .None || !place_on_item_tile(g, int(pos[0]), int(pos[1]), key, key) {
			g.err = .No_Space
			return
		}
	}
}

pick_cell :: proc(g: ^Generator, placement: content.Placement) -> (col, row: int) {
	w := g.w
	switch placement {
	case .None, .Either:
		return rng_int(&w.rng, MAZE_COLS), rng_int(&w.rng, MAZE_ROWS)
	case .DeadEnd:
		p := g.leaves[rng_int(&w.rng, g.leaf_count)]
		return int(p[0]), int(p[1])
	case .NonDeadEnd:
		p := g.inner[rng_int(&w.rng, g.inner_count)]
		return int(p[0]), int(p[1])
	}
	return 0, 0
}

place_items :: proc(g: ^Generator) {
	w := g.w
	for kind in content.Item_Kind {
		if kind == .None {continue}
		d := content.ITEMS[kind]
		if d.item_count <= 0 || d.placement == .None {continue}
		for _ in 0 ..< d.item_count {
			col, row := pick_cell(g, d.placement)
			final, ok := resolve_spawn(g, kind)
			if !ok {
				g.err = .Chain_Cycle
				return
			}
			// the tile comes from the generators of the item as listed; the item placed is the resolved one
			if !place_on_item_tile(g, col, row, kind, final) {
				g.err = .No_Space
				return
			}
		}
	}
	_ = w
}

// Interior tiles only (1..13), as in the original; random first, then a deterministic scan.
find_interior_tile :: proc(g: ^Generator, col, row: int) -> (tc, tr: int, ok: bool) {
	w := g.w
	m := &w.cells[row][col].map_
	for tries in 1 ..= RANDOM_TRIES {
		tc = rng_range(&w.rng, 1, MAP_COLS - 2)
		tr = rng_range(&w.rng, 1, MAP_ROWS - 2)
		if tile_free(m, tc, tr) {
			if tries > w.stats.random_tries_max {w.stats.random_tries_max = tries}
			return tc, tr, true
		}
	}
	w.stats.fallback_scans += 1
	for tr = 1; tr < MAP_ROWS - 1; tr += 1 {
		for tc = 1; tc < MAP_COLS - 1; tc += 1 {
			if tile_free(m, tc, tr) {return tc, tr, true}
		}
	}
	return 0, 0, false
}

place_creatures :: proc(g: ^Generator) {
	w := g.w
	for kind in content.Creature_Kind {
		if kind == .None {continue}
		d := content.CREATURES[kind]
		if d.is_player || d.creature_count <= 0 || d.placement == .None {continue}
		for _ in 0 ..< d.creature_count {
			if w.creature_count >= MAX_CREATURES {
				g.err = .Too_Many_Creatures
				return
			}
			col, row := pick_cell(g, d.placement)
			tc, tr, ok := find_interior_tile(g, col, row)
			if !ok {
				g.err = .No_Space
				return
			}
			w.creature_count += 1
			w.creatures[w.creature_count - 1] = Creature {
				kind     = kind,
				maze_col = u8(col),
				maze_row = u8(row),
				col      = u8(tc),
				row      = u8(tr),
				alive    = true,
			}
			w.cells[row][col].map_.tiles[tr][tc].creature = i16(w.creature_count)
		}
	}
}

place_player :: proc(g: ^Generator) {
	w := g.w
	pos := g.inner[rng_int(&w.rng, g.inner_count)]
	col := int(pos[0])
	row := int(pos[1])
	tc, tr, ok := find_interior_tile(g, col, row)
	if !ok {
		g.err = .No_Space
		return
	}
	w.player = Player {
		maze_col = u8(col),
		maze_row = u8(row),
		col      = u8(tc),
		row      = u8(tr),
	}
	w.cells[row][col].visit_count = 1
}

// Items the player starts with (initial_inventory generators). Applying them (durability, auto-equip)
// belongs to the turn engine (M4).
roll_start_inventory :: proc(w: ^World) {
	for kind in content.Item_Kind {
		if kind == .None {continue}
		n := pick_weighted(&w.rng, content.ITEMS[kind].initial_inventory)
		if n > 0 {w.start_inventory[kind] = u32(n)}
	}
}
