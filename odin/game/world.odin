package game

import content "../content"

MAZE_COLS :: content.MAZE_COLS
MAZE_ROWS :: content.MAZE_ROWS
MAP_COLS :: content.MAP_COLS
MAP_ROWS :: content.MAP_ROWS
MAX_PORTALS :: 2 * MAZE_COLS * MAZE_ROWS // upper bound; a grid has fewer
MAX_CREATURES :: 512
LOCK_TYPES :: 16

// Directions match the original: North 0, East 1, South 2, West 3. Row grows downward.
Direction :: enum u8 {
	North,
	East,
	South,
	West,
}

DIR_DCOL := [Direction]int {
	.North = 0,
	.East  = 1,
	.South = 0,
	.West  = -1,
}
DIR_DROW := [Direction]int {
	.North = -1,
	.East  = 0,
	.South = 1,
	.West  = 0,
}

opposite :: proc(d: Direction) -> Direction {
	return Direction((int(d) + 2) % 4)
}

Cell_Type :: enum u8 {
	Passageway,
	Room,
}

// A portal is shared by the two cells on either side of it.
Portal :: struct {
	open:      bool,
	locked:    bool,
	lock_type: i8, // -1 when not locked
}

Tile :: struct {
	terrain:  u8, // key into content.TERRAINS
	item:     content.Item_Kind,
	creature: i16, // 0 none, otherwise index+1 into World.creatures
}

Map :: struct {
	tiles: [MAP_ROWS][MAP_COLS]Tile, // [row][column]
}

Maze_Cell :: struct {
	portal:      [Direction]i16, // index into World.portals, -1 when the cell has no such neighbour
	cell_type:   Cell_Type,
	open_count:  u8,
	dead_end:    bool, // exactly one open portal
	visit_count: i32,
	map_:        Map,
}

Creature :: struct {
	kind:      content.Creature_Kind,
	maze_col:  u8,
	maze_row:  u8,
	col:       u8,
	row:       u8,
	wounds:    i32,
	steps:     f32,
	alive:     bool,
	summoned:  bool,
	been_hit:  bool,
}

Player :: struct {
	maze_col: u8,
	maze_row: u8,
	col:      u8,
	row:      u8,
}

Gen_Error :: enum {
	None,
	No_Cells, // the maze has no non-dead-end cell to hold keys or the player
	No_Space, // no free tile found for an item or creature
	Chain_Cycle, // spawn_as chain did not settle
	Too_Many_Creatures,
}

Gen_Stats :: struct {
	random_tries_max: int, // longest random search for a free tile
	fallback_scans:   int, // times the deterministic scan had to take over
}

World :: struct {
	seed:            u64,
	rng:             Rng,
	portals:         [MAX_PORTALS]Portal,
	portal_count:    int,
	cells:           [MAZE_ROWS][MAZE_COLS]Maze_Cell,
	creatures:       [MAX_CREATURES]Creature,
	creature_count:  int,
	player:          Player,
	start_inventory: [content.Item_Kind]u32,
	stats:           Gen_Stats,
}

cell_at :: proc(w: ^World, col, row: int) -> ^Maze_Cell {
	return &w.cells[row][col]
}

tile_at :: proc(m: ^Map, col, row: int) -> ^Tile {
	return &m.tiles[row][col]
}

portal_of :: proc(w: ^World, col, row: int, d: Direction) -> ^Portal {
	idx := w.cells[row][col].portal[d]
	if idx < 0 {return nil}
	return &w.portals[idx]
}

terrain_passable :: proc(t: u8) -> bool {
	return content.TERRAINS[t].passable
}
