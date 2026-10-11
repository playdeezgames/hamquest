package game

import content "../content"

// Tutorial lessons (D18 to D20, docs/TUTORIAL_PLAN.md). A lesson belongs to a room and has a goal
// that is checked after every command; once met it stays done. Which lesson to show is a pure
// function of the world (tutorial_current), so a replayed save shows the same thing, and a player
// who wanders off the intended path simply gets the lesson of whatever room they are in, or a
// pointer back to the first one they have not finished.

Show_When :: enum u8 {
	Always,
	No_Flame, // only while the torch or lantern is gone and only the match is left
}

Goal_Kind :: enum u8 {
	Visited, // the room (col, row) has been entered
	Gold_At_Least,
	Kills_At_Least,
	Rests_At_Least,
	Has_Item,
	Purchases_At_Least,
	Light_Cycle, // the light went out and a flame has been found again
	Row_Open, // some tile x0..x1 of tile row n in the room (col, row) no longer holds an item
	Quest_At_Least,
	Won,
}

Goal :: struct {
	kind:     Goal_Kind,
	col, row: u8,
	n:        u32,
	item:     content.Item_Kind,
	x0, x1:   u8,
}

Action :: enum u8 {
	None,
	Torch_Low, // the torch is nearly spent: it goes out within a turn or two
}

// Part of the screen the coach points at (drawn by the UI).
Highlight :: enum u8 {
	None,
	Map,
	Minimap,
	Pack,
	Stats,
	Log,
}

Lesson :: struct {
	col, row:  i8, // the room it is shown in; -1 for any
	show:      Show_When,
	goal:      Goal,
	on_done:   Action,
	highlight: Highlight,
	title:     string,
	text:      string,
	place:     string, // where to find it, for "head north to ..."
}

// Draft wording (voice still open); the order is the order of the level.
TUT_LESSONS := [?]Lesson {
	{
		col = 0, row = 0,
		goal = {kind = .Visited, col = 1, row = 0},
		highlight = .Map,
		title = "Moving",
		text = "Move with the arrow keys or W A S D. This big picture is the room you are in. Walk east through the opening in the right wall.",
		place = "the start",
	},
	{
		col = 1, row = 0,
		goal = {kind = .Visited, col = 2, row = 0},
		highlight = .Minimap,
		title = "The minimap",
		text = "The little map at the top right shows the rooms you have visited. Your room is the bright one, and gaps in its edge show where passages lead. Keep going east.",
		place = "the passage east of the start",
	},
	{
		col = 2, row = 0,
		goal = {kind = .Gold_At_Least, n = 1},
		highlight = .Pack,
		title = "Your pack",
		text = "The grid on the right is your pack: a dagger, hams, potions and a torch. Hams heal you by themselves when you are hurt. Walk onto the gold to pick it up.",
		place = "the hall of gold",
	},
	{
		col = 2, row = 0,
		goal = {kind = .Gold_At_Least, n = 150},
		highlight = .Stats,
		title = "Gold",
		text = "Gold buys things in shoppes, and you will want about 150. Collect all six piles.",
		place = "the hall of gold",
	},
	{
		col = 3, row = 0,
		goal = {kind = .Kills_At_Least, n = 1},
		highlight = .Stats,
		title = "Fighting",
		text = "A skeleton. Walk into a monster to attack it. Both of you roll dice each round, and a hit that gets past the defence wounds. Tab swaps Attack and Defend gear. Here you cannot die.",
		place = "the skeleton's room",
	},
	{
		col = 3, row = 0,
		goal = {kind = .Rests_At_Least, n = 1},
		highlight = .Stats,
		title = "Resting",
		text = "With no monster in the room, Space rests: time passes and you recover a point.",
		place = "the skeleton's room",
	},
	{
		col = 2, row = 1,
		goal = {kind = .Has_Item, item = .RedKey},
		highlight = .Map,
		title = "Keys",
		text = "Keys come in colours. This red one opens a red door. Walk onto it.",
		place = "the key room",
	},
	{
		col = 3, row = 2,
		goal = {kind = .Visited, col = 4, row = 2},
		on_done = .Torch_Low,
		highlight = .Map,
		title = "Doors",
		text = "The red door on the east side is locked. Walk into it with the red key.",
		place = "the red door",
	},
	{
		col = 4, row = 2,
		goal = {kind = .Purchases_At_Least, n = 1},
		highlight = .Stats,
		title = "The shoppe",
		text = "Walk into the shoppe. Up and Down choose, Enter buys one, A buys all, Esc leaves. Prices are in gold.",
		place = "the shoppe",
	},
	{
		col = -1, row = -1,
		show = .No_Flame,
		goal = {kind = .Light_Cycle},
		highlight = .Pack,
		title = "Darkness",
		text = "Your torch has burned out. Light is a clock: each torch lasts a while, and without one you see very little. The shoppe sells torches.",
		place = "the shoppe",
	},
	{
		col = 3, row = 3,
		goal = {kind = .Row_Open, col = 3, row = 3, n = 7, x0 = 5, x1 = 9},
		highlight = .Map,
		title = "Traps",
		text = "Traps hide until you stand next to them. Walk onto one with thieves' tools to disarm it; the tools are used up. Without tools it hurts.",
		place = "the trapped passage",
	},
	{
		col = 3, row = 4,
		goal = {kind = .Kills_At_Least, n = 2},
		highlight = .Map,
		title = "Zombie",
		text = "A zombie. Zombies are slower than you and hit as hard as skeletons.",
		place = "the hub",
	},
	{
		col = 4, row = 4,
		goal = {kind = .Quest_At_Least, n = TUT_QUEST_PIECES},
		highlight = .Stats,
		title = "The megaham",
		text = "Pieces of the megaham. You need them all to leave: two here, sixteen in a real game.",
		place = "the megaham room",
	},
	{
		col = 2, row = 4,
		goal = {kind = .Has_Item, item = .RainbowKey},
		highlight = .Pack,
		title = "The rainbow key",
		text = "The rainbow key. With every piece and this key, the exit lets you out.",
		place = "the rainbow key room",
	},
	{
		col = 3, row = 5,
		goal = {kind = .Won},
		highlight = .Map,
		title = "The exit",
		text = "The way out. Walk onto it.",
		place = "the exit",
	},
}

#assert(len(TUT_LESSONS) <= MAX_LESSONS)

has_flame :: proc(w: ^World) -> bool {
	ls := light_source(w)
	return ls != .None && item_def(ls).light_level > 0
}

goal_met :: proc(w: ^World, g: Goal) -> bool {
	switch g.kind {
	case .Visited: return w.cells[g.row][g.col].visit_count > 0
	case .Gold_At_Least: return money(w) >= g.n
	case .Kills_At_Least: return w.tut.kills >= g.n
	case .Rests_At_Least: return w.tut.rests >= g.n
	case .Has_Item: return has_item(w, g.item)
	case .Purchases_At_Least: return w.tut.purchases >= g.n
	case .Light_Cycle: return w.tut.outages >= 1 && has_flame(w)
	case .Row_Open:
		m := &w.cells[g.row][g.col].map_
		for x in g.x0 ..= g.x1 {
			if m.tiles[g.n][x].item == .None {return true}
		}
		return false
	case .Quest_At_Least: return w.inventory[content.PLAYER.quest_item] >= g.n
	case .Won: return w.state == .Win
	}
	return false
}

// After every command: latch the goals that have been met and run what they trigger.
tutorial_update :: proc(w: ^World) {
	for i in 0 ..< len(TUT_LESSONS) {
		if w.tut.done[i] {continue}
		if !goal_met(w, TUT_LESSONS[i].goal) {continue}
		w.tut.done[i] = true
		switch TUT_LESSONS[i].on_done {
		case .None:
		case .Torch_Low:
			if w.inventory[.Torch] > 0 {w.durability[.Torch] = 1}
		}
	}
}

// What the coach says now. `lesson` is an index into TUT_LESSONS, or -1 when everything is done.
// `here` is true when the lesson belongs to this room (or to anywhere and is due); false means the
// lesson is elsewhere and the UI should only point toward it.
Tutorial_Pointer :: struct {
	lesson: int,
	here:   bool,
}

tutorial_current :: proc(w: ^World) -> Tutorial_Pointer {
	pc, pr := int(w.player.maze_col), int(w.player.maze_row)
	for i in 0 ..< len(TUT_LESSONS) {
		l := &TUT_LESSONS[i]
		if w.tut.done[i] {continue}
		due := false
		switch l.show {
		case .Always: due = int(l.col) == pc && int(l.row) == pr
		case .No_Flame: due = !has_flame(w) // an interrupt: shown wherever the player is
		}
		if due {return {i, true}}
	}
	for i in 0 ..< len(TUT_LESSONS) {
		if !w.tut.done[i] && TUT_LESSONS[i].show == .Always {return {i, false}}
	}
	return {-1, false}
}

// Which way to walk from the player's room toward room (col, row) through open portals (a locked
// door counts: the player is told where to go, the door is its own lesson). ok is false when the
// player is already there or there is no way.
tutorial_direction :: proc(w: ^World, col, row: int) -> (dir: Direction, ok: bool) {
	pc, pr := int(w.player.maze_col), int(w.player.maze_row)
	if pc == col && pr == row {return .North, false}
	first: [MAZE_ROWS][MAZE_COLS]i8
	seen: [MAZE_ROWS][MAZE_COLS]bool
	for r in 0 ..< MAZE_ROWS {
		for c in 0 ..< MAZE_COLS {first[r][c] = -1}
	}
	queue: [MAZE_ROWS * MAZE_COLS][2]u8
	head, tail := 0, 0
	queue[tail] = {u8(pc), u8(pr)}
	tail += 1
	seen[pr][pc] = true
	for head < tail {
		cur := queue[head]
		head += 1
		cc, cr := int(cur[0]), int(cur[1])
		for d in Direction {
			p := portal_of(w, cc, cr, d)
			if p == nil || !p.open {continue}
			nc, nr := cc + DIR_DCOL[d], cr + DIR_DROW[d]
			if seen[nr][nc] {continue}
			seen[nr][nc] = true
			first[nr][nc] = first[cr][cc] if first[cr][cc] >= 0 else i8(d)
			if nc == col && nr == row {return Direction(first[nr][nc]), true}
			queue[tail] = {u8(nc), u8(nr)}
			tail += 1
		}
	}
	return .North, false
}

tutorial_note_entry :: proc(w: ^World) {
	w.tut.entry_mc = w.player.maze_col
	w.tut.entry_mr = w.player.maze_row
	w.tut.entry_col = w.player.col
	w.tut.entry_row = w.player.row
}

// D19: in the tutorial a lethal blow never ends the run. Health comes back, the player is put at
// the door of the room, the room's monsters start over, and the kit is topped up to what it began
// with. The UI reads `tut.mercy` to say what would have happened.
tutorial_mercy :: proc(w: ^World) {
	t := &w.tut
	t.mercies += 1
	t.mercy = true
	w.wounds = 0
	mc, mr := int(w.player.maze_col), int(w.player.maze_row)
	for i in 0 ..< min(len(TUT_CREATURES), w.creature_count) {
		c := &w.creatures[i]
		home := TUT_CREATURES[i]
		if int(c.maze_col) != mc || int(c.maze_row) != mr {continue}
		if !c.alive {continue}
		w.cells[mr][mc].map_.tiles[c.row][c.col].creature = 0
		c.col = home.col
		c.row = home.row
		c.wounds = 0
		c.steps = 0
		c.fresh = false
		w.cells[mr][mc].map_.tiles[c.row][c.col].creature = i16(i + 1)
	}
	w.player.maze_col = t.entry_mc
	w.player.maze_row = t.entry_mr
	w.player.col = t.entry_col
	w.player.row = t.entry_row
	if w.inventory[.Food] < w.start_inventory[.Food] {w.inventory[.Food] = w.start_inventory[.Food]}
	if w.inventory[.Potion] < w.start_inventory[.Potion] {w.inventory[.Potion] = w.start_inventory[.Potion]}
	update_pathing(w)
	reveal_traps(w)
}
