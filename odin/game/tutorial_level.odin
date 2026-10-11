package game

import content "../content"

// The training level (D18): a small hand-built dungeon made of the real rooms, items and creatures,
// laid out so the lessons in tutorial.odin come one after another. It sits in the top left of the
// ordinary 8 by 8 grid; every other cell is solid rock that nothing links to.
//
//        col 0   col 1   col 2   col 3   col 4
//  row 0   A   --  B   --  C   --  D
//                                  |
//  row 1                   K   --  E
//                                  |
//  row 2                           F  ==red door==  G (shoppe)
//                                  |
//  row 3                           H (a row of hidden traps)
//                                  |
//  row 4                   M   --  I   --  L
//                                  |
//  row 5                           N (exit)

TUT_QUEST_PIECES :: 2
TUT_START_MC :: 0
TUT_START_MR :: 0
TUT_START_COL :: 3
TUT_START_ROW :: 7

Tut_Cell :: struct {
	col, row: u8,
	kind:     Cell_Type,
}

Tut_Link :: struct {
	col, row: u8,
	dir:      Direction,
}

Tut_Item :: struct {
	mc, mr: u8,
	col, row: u8,
	kind:   content.Item_Kind,
}

Tut_Creature :: struct {
	mc, mr: u8,
	col, row: u8,
	kind:   content.Creature_Kind,
}

TUT_CELLS := [?]Tut_Cell {
	{0, 0, .Room}, // A start
	{1, 0, .Passageway}, // B
	{2, 0, .Room}, // C gold
	{3, 0, .Room}, // D skeleton
	{3, 1, .Passageway}, // E junction
	{2, 1, .Room}, // K key
	{3, 2, .Room}, // F red door
	{4, 2, .Room}, // G shoppe
	{3, 3, .Passageway}, // H traps
	{3, 4, .Room}, // I hub, zombie
	{4, 4, .Room}, // L megaham
	{2, 4, .Room}, // M rainbow key
	{3, 5, .Room}, // N exit
}

// Each link opens the portal on that side of the cell (and so its neighbour's opposite side).
TUT_LINKS := [?]Tut_Link {
	{0, 0, .East},
	{1, 0, .East},
	{2, 0, .East},
	{3, 0, .South},
	{3, 1, .West},
	{3, 1, .South},
	{3, 2, .East}, // locked: the red door
	{3, 2, .South},
	{3, 3, .South},
	{3, 4, .East},
	{3, 4, .West},
	{3, 4, .South},
}

TUT_DOOR_MC :: 3
TUT_DOOR_MR :: 2

TUT_ITEMS := [?]Tut_Item {
	{2, 0, 4, 4, .Gold},
	{2, 0, 10, 4, .Gold},
	{2, 0, 4, 10, .Gold},
	{2, 0, 10, 10, .Gold},
	{2, 0, 7, 3, .Gold},
	{2, 0, 7, 11, .Gold},
	{2, 1, 7, 7, .RedKey},
	{4, 2, 8, 7, .TorchShop},
	{3, 3, 5, 7, .HiddenDartTrap}, // five across the passage: one must be dealt with
	{3, 3, 6, 7, .HiddenDartTrap},
	{3, 3, 7, 7, .HiddenDartTrap},
	{3, 3, 8, 7, .HiddenDartTrap},
	{3, 3, 9, 7, .HiddenDartTrap},
	{4, 4, 6, 7, .Quest},
	{4, 4, 9, 7, .Quest},
	{2, 4, 7, 7, .RainbowKey},
	{3, 5, 7, 7, .Exit},
}

// The index of a creature here is its index in World.creatures (the mercy rule relies on it).
TUT_CREATURES := [?]Tut_Creature {
	{3, 0, 9, 5, .Skeleton},
	{3, 4, 10, 9, .Zombie},
}

build_tutorial :: proc(w: ^World) -> Gen_Error {
	g := Generator{w = w}
	build_item_tables(&g)
	build_portals(w)
	for l in TUT_LINKS {
		idx := w.cells[l.row][l.col].portal[l.dir]
		if idx < 0 {return .No_Cells}
		w.portals[idx].open = true
	}
	for row in 0 ..< MAZE_ROWS {
		for col in 0 ..< MAZE_COLS {
			c := &w.cells[row][col]
			open := 0
			for d in Direction {
				if c.portal[d] >= 0 && w.portals[c.portal[d]].open {open += 1}
			}
			c.open_count = u8(open)
			c.dead_end = open == 1
			c.cell_type = .Passageway
		}
	}
	for tc in TUT_CELLS {w.cells[tc.row][tc.col].cell_type = tc.kind}

	// the red door: the portal is locked and the door stands in the room on this side of it
	door_portal := portal_of(w, TUT_DOOR_MC, TUT_DOOR_MR, .East)
	if door_portal == nil {return .No_Cells}
	door_portal.locked = true
	door_portal.lock_type = 0
	for row in 0 ..< MAZE_ROWS {
		for col in 0 ..< MAZE_COLS {assemble_terrain(w, col, row)}
	}
	door := g.door_for[0][.East]
	if door == .None {return .No_Space}
	w.cells[TUT_DOOR_MR][TUT_DOOR_MC].map_.tiles[7][14].item = door

	for it in TUT_ITEMS {
		m := &w.cells[it.mr][it.mc].map_
		if !tile_free(m, int(it.col), int(it.row)) {return .No_Space}
		m.tiles[it.row][it.col].item = it.kind
	}
	for cr in TUT_CREATURES {
		m := &w.cells[cr.mr][cr.mc].map_
		if !tile_free(m, int(cr.col), int(cr.row)) {return .No_Space}
		if w.creature_count >= MAX_CREATURES {return .Too_Many_Creatures}
		w.creatures[w.creature_count] = Creature {
			kind     = cr.kind,
			maze_col = cr.mc,
			maze_row = cr.mr,
			col      = cr.col,
			row      = cr.row,
			alive    = true,
		}
		w.creature_count += 1
		m.tiles[cr.row][cr.col].creature = i16(w.creature_count)
	}

	w.player = Player {
		maze_col = TUT_START_MC,
		maze_row = TUT_START_MR,
		col      = TUT_START_COL,
		row      = TUT_START_ROW,
	}
	w.cells[TUT_START_MR][TUT_START_MC].visit_count = 1
	tutorial_note_entry(w)
	return .None
}

// The same kit every game starts with, without the dice: dagger, five hams, three potions, clothes,
// a match and a torch.
tutorial_kit :: proc(w: ^World) {
	w.start_inventory[.Dagger] = 1
	w.start_inventory[.Food] = 5
	w.start_inventory[.Potion] = 3
	w.start_inventory[.Clothes] = 1
	w.start_inventory[.Match] = 1
	w.start_inventory[.Torch] = 1
}

// The shoppe's shelf: one torch and one set of thieves' tools, always.
tutorial_stock_shop :: proc(w: ^World) {
	w.shop.slots[0] = Shop_Slot{.Torch, 1}
	w.shop.slots[1] = Shop_Slot{.Tools, 1}
	w.shop.count = 2
}
