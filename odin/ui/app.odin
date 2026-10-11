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
	collect_events(a)
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
	if a.world.state == .Play {record(a, cmd, arg)}
	game.step_command(&a.world, cmd, arg)
	collect_events(a)
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
			app_new_game(a, a.seed + 1)
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
	case:
		return false
	}
	return true
}

// ---------------------------------------------------------------- drawing

SHOP_X :: 60
SHOP_Y :: 60
SHOP_W :: 360
SHOP_H :: 344

app_draw :: proc(a: ^App) {
	a.dirty = false
	fb := &a.fb
	w := &a.world
	draw_world(fb, w)
	if w.state != .Play {
		draw_game_over(fb, w)
	} else if w.shop.active {
		draw_shop(fb, w, a.shop_sel)
	}
	if a.confirm_new {
		draw_box(fb, 140, 220, 360, 80, "New game?")
		draw_text_centered(fb, 320, 260, "Start a new game and abandon this one?", BLACK)
		draw_text_centered(fb, 320, 276, "Enter: yes     Esc: no", BLACK)
	}
	if a.tip_count > 0 {draw_tip(fb, a.tips[0], a.tip_count)}
}

draw_box :: proc(fb: ^Framebuffer, x, y, w, h: int, title: string) {
	fill_rect(fb, x, y, w, h, SILVER)
	rect_outline(fb, x, y, w, h, GRAY)
	fill_rect(fb, x, y, w, 32, BLUE)
	rect_outline(fb, x, y, w, 32, NAVY)
	draw_text_centered(fb, x + w / 2, y + 11, title, WHITE)
}

draw_game_over :: proc(fb: ^Framebuffer, w: ^game.World) {
	title := "You have won!" if w.state == .Win else "You have died."
	draw_box(fb, 140, 200, 360, 120, title)
	draw_text_centered(fb, 320, 252, "The adventure is over.", BLACK)
	draw_text_centered(fb, 320, 272, "Press F2 or Enter to start a new game.", BLACK)
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
	x, y, wd, ht := 100, 130, 440, 240
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

// A tap at a point of the 640 by 560 picture. Mirrors what the keys do.
app_tap :: proc(a: ^App, x, y: int) {
	a.dirty = true
	w := &a.world
	switch {
	case a.tip_count > 0:
		pop_tip(a)
		return
	case a.confirm_new:
		if x >= 140 && x < 500 && y >= 220 && y < 300 {
			app_new_game(a, a.seed + 1)
		} else {
			a.confirm_new = false
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
		app_new_game(a, a.seed + 1)
		return
	}
	if x < MAP_PX && y < MAP_PX {
		// toward the tap, one step; on the player's own tile: rest
		px := int(w.player.col) * TILE + TILE / 2
		py := int(w.player.row) * TILE + TILE / 2
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
	if y >= STAT_Y + 64 && y < STAT_Y + 96 {
		if x >= PANEL_X && x < PANEL_X + 32 && w.config != .Attack {command(a, .Toggle_Config)}
		if x >= PANEL_X + 32 && x < PANEL_X + 64 && w.config != .Defend {command(a, .Toggle_Config)}
	}
}
