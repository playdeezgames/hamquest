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
	fresh:     bool, // arrived this turn: does not act until the next one
	been_hit:  bool, // struck by the player this command (the UI shows a splat until the next one)
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

Play_State :: enum u8 {
	Play,
	Win,
	Lose,
}

Command :: enum u8 {
	None,
	Move_North,
	Move_East,
	Move_South,
	Move_West,
	Rest, // Space
	Use_Amulet, // Y
	Toggle_Config, // Tab: Attack <-> Defend (decides what auto-equip fills first)
	Shop_Close,
	Shop_Buy_One, // arg: stock index
	Shop_Buy_All, // arg: stock index
}

// What the UI should react to after a command (cleared at the start of each command).
Event_Kind :: enum u8 {
	Sound, // msg names the message that carries the sound
	Tutorial, // msg carries the tutorial text; shown once unless always_tutorial
	Hit_Player, // the player was struck this command
}

Event :: struct {
	kind: Event_Kind,
	msg:  content.Message_Id,
}

Msg :: struct {
	id:  content.Message_Id,
	arg: i32, // value for a {0} placeholder (experience gained)
}

MSG_LOG :: 5
MAX_EVENTS :: 64
SHOP_SLOTS :: 8
PATH_UNREACHABLE :: max(i32)

Shop_Slot :: struct {
	item:  content.Item_Kind,
	count: u32,
}

Shop_State :: struct {
	active: bool,
	shop:   content.Item_Kind,
	slots:  [SHOP_SLOTS]Shop_Slot,
	count:  int,
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

	// --- run state (M4)
	state:           Play_State,
	wounds:          i32,
	been_hit:        bool, // set by damage, cleared by the UI when it has shown the flash
	xp:              i32,
	xp_goal:         i32,
	level:           i32,
	inventory:       [content.Item_Kind]u32,
	durability:      [content.Item_Kind]u32,
	weapon:          content.Item_Kind,
	armor:           [content.Armor_Type]content.Item_Kind,
	config:          content.Player_Config,
	step_count:      i32,
	step_total:      i32,
	turn:            u32, // commands that took game time
	msgs:            [MSG_LOG]Msg,
	msg_count:       int,
	msg_serial:      u32, // grows with every message so the UI can tell when something new arrived
	events:          [MAX_EVENTS]Event,
	event_count:     int,
	tutorial_seen:   [content.Message_Id]bool,
	tutorial_off:    bool,
	shop:            Shop_State,
	pathing:         [MAP_ROWS][MAP_COLS]i32, // steps from the player over tiles a creature can walk
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
