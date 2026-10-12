package ui

import content "../content"
import game "../game"

// Saving works by replay. The game is deterministic from its seed, so a save is the seed plus the
// commands that took effect (one character each): a few kilobytes of JSON, portable between the
// native and the wasm build. The price is that a save only fits the rules and content it was made
// with: it carries RULES_VERSION (bump it when game rules change) and CONTENT_HASH (changes with the
// XML data) and an older save is refused, not guessed at.
//
//   {"format":"hamquest-save","version":1,"rules":1,"content":"<16 hex>","seed":"<hex>",
//    "tips_off":0,"seen":"<hex, one digit per 4 messages>","commands":"nnerbx..."}
// A finished game is stored as {"format":"hamquest-save","version":1,"empty":true}; the page writes
// that marker instead of deleting the key (a deleted key would let an older save come back).

SAVE_FORMAT :: "hamquest-save"
SAVE_VERSION :: 1
RULES_VERSION :: 1

Save_Result :: enum u8 {
	Ok, // a game was restored
	Empty, // a valid save that holds no game in progress
	Invalid, // not a save, damaged, or hostile: nothing was changed
	Incompatible, // a save from other rules or content: nothing was changed
}

// ---------------------------------------------------------------- writing

io_writer :: struct {
	buf: []u8,
	n:   int,
}

w_str :: proc(w: ^io_writer, s: string) {
	for i in 0 ..< len(s) {
		if w.n < len(w.buf) {
			w.buf[w.n] = s[i]
			w.n += 1
		}
	}
}

w_hex :: proc(w: ^io_writer, v: u64, digits: int) {
	for i := digits - 1; i >= 0; i -= 1 {
		d := (v >> uint(i * 4)) & 0xF
		if w.n < len(w.buf) {
			w.buf[w.n] = u8('0' + d) if d < 10 else u8('a' + d - 10)
			w.n += 1
		}
	}
}

// Build the save text in a.io and return it. A game that is over, or too long to log, is the empty marker.
save_encode :: proc(a: ^App) -> string {
	w := io_writer{buf = a.io[:]}
	w_str(&w, `{"format":"`)
	w_str(&w, SAVE_FORMAT)
	w_str(&w, `","version":`)
	w_hex_dec(&w, SAVE_VERSION)
	// while the tutorial runs the real game is the one saved, from its own seed and log
	over := a.world.state != .Play
	if a.world.mode == .Tutorial {over = a.real_over}
	if over || a.log_full {
		w_str(&w, `,"empty":true}`)
		return string(a.io[:w.n])
	}
	w_str(&w, `,"rules":`)
	w_hex_dec(&w, RULES_VERSION)
	w_str(&w, `,"content":"`)
	w_hex(&w, content.CONTENT_HASH, 16)
	w_str(&w, `","seed":"`)
	w_hex(&w, a.seed, 16)
	w_str(&w, `","tips_off":`)
	w_str(&w, "1" if a.world.tutorial_off else "0")
	w_str(&w, `,"seen":"`)
	ids := len(content.Message_Id)
	for d := 0; d < (ids + 3) / 4; d += 1 {
		v: u64
		for b in 0 ..< 4 {
			idx := d * 4 + b
			if idx < ids && a.world.tutorial_seen[content.Message_Id(idx)] {v |= 1 << uint(b)}
		}
		w_hex(&w, v, 1)
	}
	w_str(&w, `","commands":"`)
	for i in 0 ..< a.log_len {
		if w.n < len(w.buf) {
			w.buf[w.n] = a.log[i]
			w.n += 1
		}
	}
	w_str(&w, `"}`)
	return string(a.io[:w.n])
}

w_hex_dec :: proc(w: ^io_writer, v: int) {
	digits: [8]u8
	n := 0
	x := v
	if x == 0 {
		digits[0] = '0'
		n = 1
	}
	for x > 0 && n < len(digits) {
		digits[n] = u8('0' + x % 10)
		n += 1
		x /= 10
	}
	for i := n - 1; i >= 0; i -= 1 {
		if w.n < len(w.buf) {
			w.buf[w.n] = digits[i]
			w.n += 1
		}
	}
}

// ---------------------------------------------------------------- reading

Parser :: struct {
	s:   string,
	pos: int,
	ok:  bool,
}

p_lit :: proc(p: ^Parser, lit: string) {
	if !p.ok {return}
	if p.pos + len(lit) > len(p.s) || p.s[p.pos:p.pos + len(lit)] != lit {
		p.ok = false
		return
	}
	p.pos += len(lit)
}

// Text up to the next double quote (the quote is consumed).
p_quoted :: proc(p: ^Parser) -> string {
	if !p.ok {return ""}
	start := p.pos
	for p.pos < len(p.s) && p.s[p.pos] != '"' {p.pos += 1}
	if p.pos >= len(p.s) {
		p.ok = false
		return ""
	}
	r := p.s[start:p.pos]
	p.pos += 1
	return r
}

p_uint :: proc(p: ^Parser) -> (v: int) {
	if !p.ok {return 0}
	start := p.pos
	for p.pos < len(p.s) && p.s[p.pos] >= '0' && p.s[p.pos] <= '9' && p.pos - start < 9 {
		v = v * 10 + int(p.s[p.pos] - '0')
		p.pos += 1
	}
	if p.pos == start {p.ok = false}
	return
}

hex_value :: proc(s: string, max_digits: int) -> (v: u64, ok: bool) {
	if len(s) == 0 || len(s) > max_digits {return 0, false}
	for i in 0 ..< len(s) {
		c := s[i]
		d: u64
		switch {
		case c >= '0' && c <= '9': d = u64(c - '0')
		case c >= 'a' && c <= 'f': d = u64(c - 'a') + 10
		case: return 0, false
		}
		v = v << 4 | d
	}
	return v, true
}

// Are the commands well formed? (b and B carry one slot digit 0..7; nothing else is allowed.)
commands_valid :: proc(s: string) -> bool {
	i := 0
	for i < len(s) {
		switch s[i] {
		case 'n', 'e', 's', 'w', 'r', 'y', 't', 'x':
			i += 1
		case 'b', 'B':
			if i + 1 >= len(s) || s[i + 1] < '0' || s[i + 1] > '7' {return false}
			i += 2
		case:
			return false
		}
	}
	return true
}

// Restore a game from save text. Nothing in `a` is touched unless the result is .Ok.
save_decode :: proc(a: ^App, text: string) -> Save_Result {
	if len(text) == 0 || len(text) > IO_SIZE {return .Invalid}
	p := Parser{s = text, ok = true}
	p_lit(&p, `{"format":"`)
	if p_quoted(&p) != SAVE_FORMAT {return .Invalid}
	p_lit(&p, `,"version":`)
	if p_uint(&p) != SAVE_VERSION || !p.ok {return .Incompatible if p.ok else .Invalid}
	if p.ok && p.pos < len(p.s) && p.s[p.pos:] == `,"empty":true}` {return .Empty}
	p_lit(&p, `,"rules":`)
	rules := p_uint(&p)
	p_lit(&p, `,"content":"`)
	chash, hash_ok := hex_value(p_quoted(&p), 16)
	p_lit(&p, `,"seed":"`)
	seed, seed_ok := hex_value(p_quoted(&p), 16)
	p_lit(&p, `,"tips_off":`)
	tips_off := p_uint(&p)
	p_lit(&p, `,"seen":"`)
	seen := p_quoted(&p)
	p_lit(&p, `,"commands":"`)
	cmds := p_quoted(&p)
	p_lit(&p, `}`)
	if !p.ok || p.pos != len(p.s) || !hash_ok || !seed_ok || tips_off > 1 {return .Invalid}
	ids := len(content.Message_Id)
	if len(seen) != (ids + 3) / 4 {return .Invalid}
	for i in 0 ..< len(seen) {
		if _, ok := hex_value(seen[i:i + 1], 1); !ok {return .Invalid}
	}
	if len(cmds) > MAX_LOG || !commands_valid(cmds) {return .Invalid}
	if rules != RULES_VERSION || chash != content.CONTENT_HASH {return .Incompatible}

	// replay
	tutorial_reset(a)
	app_new_game(a, seed)
	if a.error != .None {return .Invalid}
	w := &a.world
	i := 0
	for i < len(cmds) && w.state == .Play {
		cmd: game.Command
		arg := 0
		switch cmds[i] {
		case 'n': cmd = .Move_North
		case 'e': cmd = .Move_East
		case 's': cmd = .Move_South
		case 'w': cmd = .Move_West
		case 'r': cmd = .Rest
		case 'y': cmd = .Use_Amulet
		case 't': cmd = .Toggle_Config
		case 'x': cmd = .Shop_Close
		case 'b':
			cmd = .Shop_Buy_One
			arg = int(cmds[i + 1] - '0')
			i += 1
		case 'B':
			cmd = .Shop_Buy_All
			arg = int(cmds[i + 1] - '0')
			i += 1
		}
		i += 1
		game.step_command(w, cmd, arg)
	}
	// tips seen and the stop-tips choice are the saved ones, and no pop-up is waiting
	for d in 0 ..< len(seen) {
		v, _ := hex_value(seen[d:d + 1], 1)
		for b in 0 ..< 4 {
			idx := d * 4 + b
			if idx < ids {w.tutorial_seen[content.Message_Id(idx)] = v & (1 << uint(b)) != 0}
		}
	}
	w.tutorial_off = tips_off == 1
	a.tip_count = 0
	a.shop_sel = 0
	for k in 0 ..< len(cmds) {a.log[k] = cmds[k]}
	a.log_len = len(cmds)
	a.log_full = false
	a.save_dirty = false
	a.dirty = true
	return .Ok
}

tutorial_reset :: proc(a: ^App) {
	a.world.tutorial_seen = {}
	a.world.tutorial_off = false
}
