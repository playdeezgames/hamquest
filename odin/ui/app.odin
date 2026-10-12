package ui

import content "../content"
import game "../game"

// The application layer shared by every platform shell: a game, a framebuffer, modal dialogs and the
// mapping from keys to game commands. Shells feed it keys and ask it to draw.

Key :: enum u8 {
	None,
	Up,
	Down,
	Left,
	Right,
	Space, // rest
	Tab, // attack/defend
	Enter,
	Escape,
	F2, // new game
	Y, // invoke the amulet
	A, // west while playing; buy all in a shop
	S, // south
	W, // north
	D, // east
	N, // no (confirm)
	T, // stop showing tips (while a tip is open)
	C, // credits
	H, // show the tutorial lesson again
}

Title_Item :: enum u8 {
	Continue,
	Real_Game, // back to the real game that the tutorial pushed aside (only then)
	New_Game,
	Tutorial,
	Credits,
	Quit,
}

MAX_TIPS :: 8
MAX_LOG :: 200_000
IO_SIZE :: MAX_LOG + 1024

App :: struct {
	world:      game.World,
	fb:         Framebuffer,
	seed:       u64,
	shop_sel:   int,
	tips:       [MAX_TIPS]content.Message_Id, // tutorial pop-ups waiting to be shown
	tip_count:  int,
	confirm_new: bool,
	credits:    bool, // the credits screen is open
	title:      bool, // the title menu is open (over a game that may be in progress)
	title_sel:  Title_Item,
	can_quit:   bool, // set by a shell that has a window to close: adds Quit to the title menu
	quit:       bool, // Quit was chosen; the shell closes
	real_over:  bool, // while the tutorial runs: the real game it pushed aside had ended
	coach_hidden: bool, // the lesson was dismissed for this room (D29)
	coach_room: int, // the room the player was in at the last command
	pulse:      int, // frame counter for the highlight
	error:      game.Gen_Error,
	dirty:      bool, // something changed since the last app_draw

	// Saving replays the game from its seed (see save.odin): every command that took effect is logged.
	log:         [MAX_LOG]u8,
	log_len:     int,
	log_full:    bool, // the log overflowed: the game can no longer be saved
	save_dirty:  bool, // the save text is out of date
	io:          [IO_SIZE]u8, // save text out / load text in (shared with the page)
}

app_new_game :: proc(a: ^App, seed: u64) {
	a.dirty = true
	a.save_dirty = true
	a.log_len = 0
	a.log_full = false
	a.seed = seed
	a.error = game.new_game(&a.world, seed)
	a.shop_sel = 0
	a.tip_count = 0
	a.confirm_new = false
	a.title = false
	a.credits = false
	a.real_over = false
	a.coach_hidden = false
	collect_events(a)
}

// The training level (D18). The real game's seed and log are left alone, so it is neither saved over nor lost.
app_new_tutorial :: proc(a: ^App, seed: u64) {
	if a.world.mode == .Normal {a.real_over = a.world.state != .Play}
	seen := a.world.tutorial_seen
	off := a.world.tutorial_off
	a.error = game.new_tutorial(&a.world, seed)
	a.world.tutorial_seen = seen
	a.world.tutorial_off = off
	a.shop_sel = 0
	a.tip_count = 0
	a.confirm_new = false
	a.title = false
	a.credits = false
	a.coach_hidden = false
	a.coach_room = room_id(&a.world)
	a.pulse = 0
	a.dirty = true
}

room_id :: proc(w: ^game.World) -> int {
	return int(w.player.maze_row) * game.MAZE_COLS + int(w.player.maze_col)
}

// Back to the real game by replaying its save text.
app_resume_real :: proc(a: ^App) {
	text := save_encode(a)
	if save_decode(a, text) != .Ok {app_new_game(a, a.seed + 1)}
	a.title = false
}

// ---------------------------------------------------------------- title menu

// A game in progress: something has been done in it and it is not over.
game_in_progress :: proc(a: ^App) -> bool {
	if a.world.mode == .Tutorial {return a.world.state == .Play && a.world.tut.commands > 0}
	return a.world.state == .Play && a.log_len > 0
}

// The real game (not the tutorial) has something worth keeping.
real_in_progress :: proc(a: ^App) -> bool {
	if a.world.mode == .Tutorial {return !a.real_over && a.log_len > 0}
	return a.world.state == .Play && a.log_len > 0
}

title_enabled :: proc(a: ^App, item: Title_Item) -> bool {
	switch item {
	case .Continue: return game_in_progress(a)
	case .Real_Game: return a.world.mode == .Tutorial && real_in_progress(a)
	case .New_Game, .Credits, .Tutorial: return true
	case .Quit: return a.can_quit
	}
	return false
}

title_visible :: proc(a: ^App, item: Title_Item) -> bool {
	#partial switch item {
	case .Quit: return a.can_quit
	case .Real_Game: return a.world.mode == .Tutorial && real_in_progress(a)
	}
	return true
}

// Show the title menu. Continue is preselected when there is a game to continue.
app_open_title :: proc(a: ^App) {
	a.title = true
	a.credits = false
	a.confirm_new = false
	a.title_sel = .Continue if game_in_progress(a) else .New_Game
	a.dirty = true
}

title_move :: proc(a: ^App, step: int) {
	n := len(Title_Item)
	i := int(a.title_sel)
	for _ in 0 ..< n {
		i = (i + step + n) % n
		item := Title_Item(i)
		if title_visible(a, item) && title_enabled(a, item) {
			a.title_sel = item
			return
		}
	}
}

title_activate :: proc(a: ^App, item: Title_Item) {
	if !title_enabled(a, item) {return}
	a.title_sel = item
	switch item {
	case .Continue:
		a.title = false
	case .Real_Game:
		app_resume_real(a)
	case .New_Game:
		switch {
		case real_in_progress(a):
			a.confirm_new = true
		case a.world.mode == .Normal && a.world.state == .Play:
			a.title = false // nothing has happened yet: this world is already a new game
		case:
			app_new_game(a, a.seed + 1)
		}
	case .Credits:
		a.credits = true
	case .Quit:
		a.quit = true
	case .Tutorial:
		app_new_tutorial(a, a.seed + 7919)
	}
}

collect_events :: proc(a: ^App) {
	w := &a.world
	for i in 0 ..< w.event_count {
		e := w.events[i]
		if e.kind == .Tutorial && a.tip_count < MAX_TIPS {
			a.tips[a.tip_count] = e.msg
			a.tip_count += 1
		}
	}
}

pop_tip :: proc(a: ^App) {
	if a.tip_count == 0 {return}
	for i in 1 ..< a.tip_count {a.tips[i - 1] = a.tips[i]}
	a.tip_count -= 1
}

command :: proc(a: ^App, cmd: game.Command, arg: int = 0) {
	if a.world.state == .Play && a.world.mode == .Normal {record(a, cmd, arg)}
	game.step_command(&a.world, cmd, arg)
	collect_events(a)
	if room_id(&a.world) != a.coach_room {
		a.coach_room = room_id(&a.world)
		a.coach_hidden = false // the lesson of a new room is shown again (D29)
	}
	if !a.world.shop.active {a.shop_sel = 0}
}

// Append the command to the replay log as one character (shop commands: letter + slot digit).
record :: proc(a: ^App, cmd: game.Command, arg: int) {
	ch: u8
	two := false
	#partial switch cmd {
	case .Move_North: ch = 'n'
	case .Move_East: ch = 'e'
	case .Move_South: ch = 's'
	case .Move_West: ch = 'w'
	case .Rest: ch = 'r'
	case .Use_Amulet: ch = 'y'
	case .Toggle_Config: ch = 't'
	case .Shop_Close: ch = 'x'
	case .Shop_Buy_One:
		ch = 'b'
		two = true
	case .Shop_Buy_All:
		ch = 'B'
		two = true
	case:
		return
	}
	need := 2 if two else 1
	if a.log_full || a.log_len + need > MAX_LOG {
		a.log_full = true
		return
	}
	a.log[a.log_len] = ch
	a.log_len += 1
	if two {
		slot := arg
		if slot < 0 || slot > 7 {slot = 0}
		a.log[a.log_len] = u8('0' + slot)
		a.log_len += 1
	}
	a.save_dirty = true
}

// Handle one key press. Returns true if the key was used.
app_key :: proc(a: ^App, key: Key) -> bool {
	a.dirty = true
	w := &a.world
	switch {
	case a.credits:
		#partial switch key {
		case .Enter, .Escape, .C, .Space:
			a.credits = false
		case:
			return false
		}
		return true
	case key == .C && a.tip_count == 0 && !w.shop.active:
		a.credits = true
		return true
	case a.tip_count > 0:
		#partial switch key {
		case .Enter, .Escape, .Space:
			pop_tip(a)
		case .T:
			w.tutorial_off = true
			// drop tips that are not always-on
			n := 0
			for i in 0 ..< a.tip_count {
				if content.MESSAGES[a.tips[i]].always_tutorial {
					a.tips[n] = a.tips[i]
					n += 1
				}
			}
			a.tip_count = n
			if a.tip_count > 0 {pop_tip(a)}
		case:
			return false
		}
		return true
	case a.confirm_new:
		#partial switch key {
		case .Enter:
			app_new_game(a, a.seed + 1)
		case .Escape, .N:
			a.confirm_new = false
		case:
			return false
		}
		return true
	case a.title:
		#partial switch key {
		case .Up, .W:
			title_move(a, -1)
		case .Down, .S:
			title_move(a, 1)
		case .Enter, .Space:
			title_activate(a, a.title_sel)
		case .Escape:
			title_activate(a, .Continue)
		case .C:
			a.credits = true
		case:
			return false
		}
		return true
	case w.shop.active:
		#partial switch key {
		case .Up:
			if a.shop_sel > 0 {a.shop_sel -= 1}
		case .Down:
			if a.shop_sel < w.shop.count - 1 {a.shop_sel += 1}
		case .Enter:
			command(a, .Shop_Buy_One, a.shop_sel)
		case .A:
			command(a, .Shop_Buy_All, a.shop_sel)
		case .Escape:
			command(a, .Shop_Close)
		case:
			return false
		}
		return true
	case w.state != .Play:
		#partial switch key {
		case .F2, .Enter:
			if w.mode == .Tutorial {
				tutorial_finished(a)
			} else {
				app_new_game(a, a.seed + 1)
			}
			return true
		case .Escape:
			app_open_title(a)
			return true
		}
		return false
	}
	#partial switch key {
	case .Up, .W:
		command(a, .Move_North)
	case .Right, .D:
		command(a, .Move_East)
	case .Down, .S:
		command(a, .Move_South)
	case .Left, .A:
		command(a, .Move_West)
	case .Space:
		command(a, .Rest)
	case .Y:
		command(a, .Use_Amulet)
	case .Tab:
		command(a, .Toggle_Config)
	case .F2:
		a.confirm_new = true
	case .Escape:
		app_open_title(a)
	case .Enter:
		if w.mode != .Tutorial {return false}
		a.coach_hidden = true
	case .H:
		if w.mode != .Tutorial {return false}
		a.coach_hidden = false
	case:
		return false
	}
	return true
}

// ---------------------------------------------------------------- drawing

SHOP_W :: 360
SHOP_H :: 344
SHOP_X :: MAP_X + (MAP_PX - SHOP_W) / 2 // dialogs sit over the map
SHOP_Y :: MAP_Y + (MAP_PX - SHOP_H) / 2

MAP_CX :: MAP_X + MAP_PX / 2 // centre of the map pane
MAP_CY :: MAP_Y + MAP_PX / 2
CX :: FRAME_W / 2 // centre of the whole frame
CY :: FRAME_H / 2

app_draw :: proc(a: ^App) {
	a.dirty = false
	fb := &a.fb
	w := &a.world
	if a.title {
		draw_title(fb, a)
	} else {
		draw_world(fb, w)
		if w.mode == .Tutorial && w.state == .Play {draw_coach(a)}
		if w.state != .Play {
			if w.mode == .Tutorial {
				draw_tutorial_done(fb)
			} else {
				draw_game_over(fb, w)
			}
		} else if w.shop.active {
			draw_shop(fb, w, a.shop_sel)
		}
	}
	if a.confirm_new {
		draw_box(fb, CONFIRM_X, CONFIRM_Y, 360, 80, "New game?")
		draw_text_centered(fb, CX, CONFIRM_Y + 40, "Start a new game and abandon this one?", BLACK)
		draw_text_centered(fb, CX, CONFIRM_Y + 56, "Enter: yes     Esc: no", BLACK)
	}
	if a.tip_count > 0 && !a.title {draw_tip(fb, a.tips[0], a.tip_count)}
	if a.credits {draw_credits(fb)}
}

CONFIRM_X :: CX - 180
CONFIRM_Y :: CY - 40

TITLE_ITEM_W :: 240
TITLE_ITEM_X :: CX - TITLE_ITEM_W / 2
TITLE_ITEM_Y :: 300
TITLE_ITEM_H :: 32
TITLE_ITEM_STEP :: 40

title_label :: proc(a: ^App, item: Title_Item) -> string {
	switch item {
	case .Continue: return "Continue tutorial" if a.world.mode == .Tutorial else "Continue"
	case .Real_Game: return "Return to your game"
	case .New_Game: return "New Game"
	case .Tutorial: return "Restart tutorial" if a.world.mode == .Tutorial && game_in_progress(a) else "Tutorial"
	case .Credits: return "Credits"
	case .Quit: return "Quit"
	}
	return ""
}

// Row (0 at the top) of a visible title item, or -1.
title_row :: proc(a: ^App, item: Title_Item) -> int {
	row := 0
	for i in 0 ..< len(Title_Item) {
		it := Title_Item(i)
		if !title_visible(a, it) {continue}
		if it == item {return row}
		row += 1
	}
	return -1
}

draw_title :: proc(fb: ^Framebuffer, a: ^App) {
	fill(fb, Color{16, 16, 56, 255})
	rect_outline(fb, 12, 12, FRAME_W - 24, FRAME_H - 24, BOX_BORDER)
	draw_text_centered_scaled(fb, CX, 70, "HamQuest", WHITE, 6)
	draw_text_centered_scaled(fb, CX, 130, "of SPLORR!!", CYAN, 3)
	// a row of the cast
	art := [?]content.Image_Id {
		.MapCreaturesPlayerPlayer, .MapItemsKeysRed, .MapItemsConsumablesHam, .MapItemsKeysRainbow,
		.MapCreaturesUndeadSkeleton, .MapCreaturesBossesDragon,
	}
	x0 := CX - (len(art) * 48) / 2
	for i in 0 ..< len(art) {blit(fb, art[i], x0 + i * 48 + 8, 190, 1)}
	draw_text_centered(fb, CX, 242, "Locks, keys, ham and monsters.", Color{200, 200, 255, 255})
	for i in 0 ..< len(Title_Item) {
		item := Title_Item(i)
		if !title_visible(a, item) {continue}
		y := TITLE_ITEM_Y + title_row(a, item) * TITLE_ITEM_STEP
		enabled := title_enabled(a, item)
		selected := a.title_sel == item
		bg := Color{40, 40, 90, 255}
		if selected {bg = BLUE}
		fill_rect(fb, TITLE_ITEM_X, y, TITLE_ITEM_W, TITLE_ITEM_H, bg)
		rect_outline(fb, TITLE_ITEM_X, y, TITLE_ITEM_W, TITLE_ITEM_H, NAVY if !selected else WHITE)
		col := WHITE if enabled else GRAY
		draw_text_centered(fb, TITLE_ITEM_X + TITLE_ITEM_W / 2, y + 12, title_label(a, item), col)
	}
	draw_text_centered(fb, CX, FRAME_H - 40, "Up/Down and Enter, or tap.   Esc in a game returns here.", Color{160, 160, 220, 255})
}

draw_text_centered_scaled :: proc(fb: ^Framebuffer, cx, y: int, s: string, c: Color, scale: int) {
	draw_text_scaled(fb, cx - text_width_scaled(s, scale) / 2, y, s, c, scale)
}

CREDITS_LINES := [?]string {
	"HamQuest of SPLORR!!",
	"",
	"Game, doors and walls:",
	"TheGrumpyGameDev",
	"",
	"Tiles: David Gervais, Angband 32x32 tileset,",
	"Creative Commons Attribution 3.0",
	"creativecommons.org/licenses/by/3.0",
	"",
	"Font: m5x7 by Daniel Linssen (managore), CC0",
	"",
	"The 2026 Odin and WebAssembly port was written",
	"with Claude Code (Anthropic).",
	"",
	"Original game: C#, 2007 to 2011 (WinForms, then Silverlight).",
}

draw_credits :: proc(fb: ^Framebuffer) {
	wd, ht := 460, 330
	x, y := CX - wd / 2, CY - ht / 2
	draw_box(fb, x, y, wd, ht, "Credits")
	for i in 0 ..< len(CREDITS_LINES) {
		line := CREDITS_LINES[i]
		if i == 0 {
			draw_text_centered(fb, x + wd / 2, y + 44, line, NAVY)
		} else {
			draw_text_centered(fb, x + wd / 2, y + 48 + i * 15, line, BLACK)
		}
	}
	draw_text_centered(fb, x + wd / 2, y + ht - 24, "Enter or C: close", NAVY)
}

draw_box :: proc(fb: ^Framebuffer, x, y, w, h: int, title: string) {
	fill_rect(fb, x, y, w, h, SILVER)
	rect_outline(fb, x, y, w, h, GRAY)
	fill_rect(fb, x, y, w, 32, BLUE)
	rect_outline(fb, x, y, w, 32, NAVY)
	draw_text_centered(fb, x + w / 2, y + 11, title, WHITE)
}

// ---------------------------------------------------------------- tutorial coach (D27 to D30)

COACH_BG :: Color{255, 252, 226, 255}
HIGHLIGHT :: Color{255, 214, 0, 255}

// The box the coach points at, in frame pixels.
highlight_box :: proc(h: game.Highlight) -> (x, y, w, ht: int, ok: bool) {
	switch h {
	case .None: return 0, 0, 0, 0, false
	case .Map: return MAP_BOX_X, MAP_BOX_Y, MAP_BOX_W, MAP_BOX_W, true
	case .Minimap: return PANEL_BOX_X, MINI_BOX_Y, PANEL_BOX_W, MINI_BOX_H, true
	case .Stats: return PANEL_BOX_X, STAT_BOX_Y, PANEL_BOX_W, STAT_BOX_H, true
	case .Pack: return PANEL_BOX_X, PACK_BOX_Y, PANEL_BOX_W, PACK_BOX_H, true
	case .Log: return LOG_BOX_X, LOG_BOX_Y, LOG_BOX_W, LOG_BOX_H, true
	}
	return 0, 0, 0, 0, false
}

// What the coach box says now, or ok = false when it has nothing to say (or was dismissed for this room).
Coach_Text :: struct {
	title:     string,
	text:      string,
	highlight: game.Highlight,
	ok:        bool,
}

coach_text :: proc(a: ^App, hint: ^Text_Buf) -> Coach_Text {
	w := &a.world
	if w.tut.mercy {
		return {
			"That would have been the end of you",
			"In the real game that blow ends your run. Here we shall pretend it did not happen. Back to the door with you, and your hams are restocked.",
			.None,
			true,
		}
	}
	if a.coach_hidden {return {}}
	cur := game.tutorial_current(w)
	if cur.lesson < 0 {return {}}
	l := &game.TUT_LESSONS[cur.lesson]
	if cur.here {return {l.title, l.text, l.highlight, true}}
	dir, ok := game.tutorial_direction(w, int(l.col), int(l.row))
	if !ok {return {}}
	tb_str(hint, "Head ")
	switch dir {
	case .North: tb_str(hint, "north")
	case .East: tb_str(hint, "east")
	case .South: tb_str(hint, "south")
	case .West: tb_str(hint, "west")
	}
	tb_str(hint, " to find ")
	tb_str(hint, l.place)
	tb_str(hint, ".")
	return {"Where to?", tb_string(hint), .None, true}
}

draw_coach :: proc(a: ^App) {
	hint: Text_Buf
	c := coach_text(a, &hint)
	if !c.ok {return}
	fb := &a.fb
	// the lesson takes the message box
	fill_rect(fb, LOG_BOX_X, LOG_BOX_Y, LOG_BOX_W, LOG_BOX_H, BOX_BORDER)
	fill_rect(fb, LOG_X, LOG_Y, LOG_W, LOG_H, COACH_BG)
	draw_text(fb, LOG_X + 8, LOG_Y + 6, c.title, NAVY)
	lines: [16]string
	n := wrap_text(c.text, LOG_W - 16, &lines)
	for i in 0 ..< min(n, 4) {
		draw_text(fb, LOG_X + 8, LOG_Y + 22 + i * 14, lines[i], BLACK)
	}
	label := "H: show again" if a.coach_hidden else "Enter: hide"
	if !a.coach_hidden {draw_text(fb, LOG_X + LOG_W - 8 - text_width(label), LOG_Y + 6, label, GRAY)}
	// pulse the border of the box it is about: a triangle wave between its colour and yellow
	if x, y, bw, bh, ok := highlight_box(c.highlight); ok {
		phase := a.pulse % 60
		k := phase if phase < 30 else 60 - phase // 0..30
		col := Color {
			u8((int(BOX_BORDER.r) * (30 - k) + int(HIGHLIGHT.r) * k) / 30),
			u8((int(BOX_BORDER.g) * (30 - k) + int(HIGHLIGHT.g) * k) / 30),
			u8((int(BOX_BORDER.b) * (30 - k) + int(HIGHLIGHT.b) * k) / 30),
			255,
		}
		rect_outline(fb, x, y, bw, bh, col)
		rect_outline(fb, x + 1, y + 1, bw - 2, bh - 2, col)
	}
	a.pulse += 1
	a.dirty = true // keep animating
}

draw_tutorial_done :: proc(fb: ^Framebuffer) {
	draw_box(fb, MAP_CX - 190, MAP_CY - 70, 380, 140, "Tutorial complete")
	draw_text_centered(fb, MAP_CX, MAP_CY - 22, "You have escaped the training cellar.", BLACK)
	draw_text_centered(fb, MAP_CX, MAP_CY - 6, "The real dungeon is less polite.", BLACK)
	draw_text_centered(fb, MAP_CX, MAP_CY + 30, "Enter: a real game     Esc: the menu", NAVY)
}

// After the exit: back to the real game if there is one in progress, otherwise a new one (D30, D31).
tutorial_finished :: proc(a: ^App) {
	if real_in_progress(a) {
		app_resume_real(a)
	} else {
		app_new_game(a, a.seed + 1)
	}
}

draw_game_over :: proc(fb: ^Framebuffer, w: ^game.World) {
	title := "You have won!" if w.state == .Win else "You have died."
	draw_box(fb, MAP_CX - 180, MAP_CY - 60, 360, 120, title)
	draw_text_centered(fb, MAP_CX, MAP_CY - 8, "The adventure is over.", BLACK)
	draw_text_centered(fb, MAP_CX, MAP_CY + 12, "Press F2 or Enter to start a new game.", BLACK)
	draw_text_centered(fb, MAP_CX, MAP_CY + 32, "C: credits, Esc: menu", NAVY)
}

draw_shop :: proc(fb: ^Framebuffer, w: ^game.World, sel: int) {
	s := &w.shop
	title := content.ITEMS[s.shop].shop_title
	draw_box(fb, SHOP_X, SHOP_Y, SHOP_W, SHOP_H, title)
	// stock list
	lx, ly := SHOP_X + 8, SHOP_Y + 40
	fill_rect(fb, lx, ly, 344, 160, WHITE)
	rect_outline(fb, lx, ly, 344, 160, GRAY)
	for i in 0 ..< s.count {
		slot := s.slots[i]
		y := ly + 2 + i * 16
		if i == sel {fill_rect(fb, lx + 1, y, 342, 16, NAVY)}
		b: Text_Buf
		tb_str(&b, content.ITEMS[slot.item].name)
		tb_str(&b, " (In Stock:")
		tb_int(&b, i64(slot.count))
		tb_str(&b, ", Price:")
		tb_int(&b, i64(content.ITEMS[slot.item].price))
		tb_str(&b, ")")
		draw_text(fb, lx + 4, y + 4, tb_string(&b), WHITE if i == sel else BLACK)
	}
	if s.count == 0 {draw_text_centered(fb, lx + 172, ly + 70, "The shelves are bare.", BLACK)}
	gold: Text_Buf
	tb_str(&gold, "Gold Available: ")
	tb_int(&gold, i64(game.money(w)))
	draw_text_centered(fb, SHOP_X + SHOP_W / 2, SHOP_Y + 212, tb_string(&gold), BLACK)
	price, stock := i64(0), i64(0)
	if sel < s.count {
		price = i64(content.ITEMS[s.slots[sel].item].price)
		stock = i64(s.slots[sel].count)
	}
	buttons := [3]string{"", "", "Leave Shoppe (Esc)"}
	one: Text_Buf
	tb_str(&one, "Buy One (Enter) - Costs ")
	tb_int(&one, price)
	tb_str(&one, " Gold")
	all: Text_Buf
	tb_str(&all, "Buy All (A) - Costs ")
	tb_int(&all, price * stock)
	tb_str(&all, " Gold")
	can_one := stock > 0 && i64(game.money(w)) >= price
	can_all := stock > 0 && i64(game.money(w)) >= price * stock
	draw_button(fb, SHOP_X + 8, SHOP_Y + 240, 344, tb_string(&one), can_one)
	draw_button(fb, SHOP_X + 8, SHOP_Y + 272, 344, tb_string(&all), can_all)
	draw_button(fb, SHOP_X + 8, SHOP_Y + 304, 344, buttons[2], true)
}

draw_button :: proc(fb: ^Framebuffer, x, y, w: int, label: string, enabled: bool) {
	fill_rect(fb, x, y, w, 24, WHITE if enabled else Color{224, 224, 224, 255})
	rect_outline(fb, x, y, w, 24, GRAY)
	draw_text_centered(fb, x + w / 2, y + 8, label, BLACK if enabled else GRAY)
}

draw_tip :: proc(fb: ^Framebuffer, id: content.Message_Id, remaining: int) {
	def := &content.MESSAGES[id]
	wd, ht := 440, 240
	x, y := MAP_CX - wd / 2, MAP_CY - ht / 2
	draw_box(fb, x, y, wd, ht, def.tutorial_title)
	// picture at 2x on the left
	blit(fb, def.tutorial_image, x + 16, y + 48, 2)
	lines: [16]string
	n := wrap_text(def.tutorial_text, wd - 16 - 64 - 16 - 16, &lines)
	for i in 0 ..< n {
		draw_text(fb, x + 16 + 64 + 16, y + 48 + i * 14, lines[i], BLACK)
	}
	hint := "Enter: continue" if def.always_tutorial else "Enter: continue     T: stop showing tips"
	draw_text_centered(fb, x + wd / 2, y + ht - 24, hint, NAVY)
	if remaining > 1 {
		b: Text_Buf
		tb_int(&b, i64(remaining - 1))
		tb_str(&b, " more")
		draw_text(fb, x + wd - 8 - text_width(tb_string(&b)), y + 11, tb_string(&b), WHITE)
	}
}

// ---------------------------------------------------------------- touch and mouse

// A tap at a point of the 800 by 600 picture. Mirrors what the keys do.
app_tap :: proc(a: ^App, x, y: int) {
	a.dirty = true
	w := &a.world
	switch {
	case a.credits:
		a.credits = false
		return
	case a.tip_count > 0:
		pop_tip(a)
		return
	case a.confirm_new:
		if x >= CONFIRM_X && x < CONFIRM_X + 360 && y >= CONFIRM_Y && y < CONFIRM_Y + 80 {
			app_new_game(a, a.seed + 1)
		} else {
			a.confirm_new = false
		}
		return
	case a.title:
		for i in 0 ..< len(Title_Item) {
			item := Title_Item(i)
			if !title_visible(a, item) {continue}
			ty := TITLE_ITEM_Y + title_row(a, item) * TITLE_ITEM_STEP
			if x >= TITLE_ITEM_X && x < TITLE_ITEM_X + TITLE_ITEM_W && y >= ty && y < ty + TITLE_ITEM_H {
				title_activate(a, item)
			}
		}
		return
	case w.shop.active:
		lx, ly := SHOP_X + 8, SHOP_Y + 40
		switch {
		case x >= lx && x < lx + 344 && y >= ly && y < ly + 160:
			row := (y - ly - 2) / 16
			if row >= 0 && row < w.shop.count {
				if row == a.shop_sel {
					command(a, .Shop_Buy_One, row)
				} else {
					a.shop_sel = row
				}
			}
		case x >= lx && x < lx + 344 && y >= SHOP_Y + 240 && y < SHOP_Y + 264:
			command(a, .Shop_Buy_One, a.shop_sel)
		case x >= lx && x < lx + 344 && y >= SHOP_Y + 272 && y < SHOP_Y + 296:
			command(a, .Shop_Buy_All, a.shop_sel)
		case x >= lx && x < lx + 344 && y >= SHOP_Y + 304 && y < SHOP_Y + 328:
			command(a, .Shop_Close)
		}
		return
	case w.state != .Play:
		if w.mode == .Tutorial {
			tutorial_finished(a)
		} else {
			app_new_game(a, a.seed + 1)
		}
		return
	}
	if w.mode == .Tutorial && x >= LOG_BOX_X && x < LOG_BOX_X + LOG_BOX_W && y >= LOG_BOX_Y && y < LOG_BOX_Y + LOG_BOX_H {
		a.coach_hidden = !a.coach_hidden
		return
	}
	if x >= MAP_X && y >= MAP_Y && x < MAP_X + MAP_PX && y < MAP_Y + MAP_PX {
		// toward the tap, one step; on the player's own tile: rest
		px := MAP_X + int(w.player.col) * TILE + TILE / 2
		py := MAP_Y + int(w.player.row) * TILE + TILE / 2
		dx, dy := x - px, y - py
		switch {
		case abs(dx) < TILE / 2 && abs(dy) < TILE / 2:
			command(a, .Rest)
		case abs(dx) >= abs(dy):
			command(a, .Move_East if dx > 0 else .Move_West)
		case:
			command(a, .Move_South if dy > 0 else .Move_North)
		}
		return
	}
	// the attack and defend icons under the statistics
	if y >= STAT_Y + MODE_DY && y < STAT_Y + MODE_DY + 32 {
		if x >= STAT_X && x < STAT_X + 32 && w.config != .Attack {command(a, .Toggle_Config)}
		if x >= STAT_X + 32 && x < STAT_X + 64 && w.config != .Defend {command(a, .Toggle_Config)}
	}
}
