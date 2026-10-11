package ui

import content "../content"

// A software framebuffer: 640 by 560 RGBA, one u32 per pixel with the bytes in R,G,B,A order in memory
// (little-endian u32 = A<<24 | B<<16 | G<<8 | R). The page or SDL window only has to show it.

FRAME_W :: 640
FRAME_H :: 560

Framebuffer :: struct {
	pixels: [FRAME_W * FRAME_H]u32,
}

Color :: [4]u8 // r, g, b, a

pack :: #force_inline proc(c: Color) -> u32 {
	return u32(c.r) | u32(c.g) << 8 | u32(c.b) << 16 | u32(c.a) << 24
}

WHITE :: Color{255, 255, 255, 255}
BLACK :: Color{0, 0, 0, 255}
GRAY :: Color{128, 128, 128, 255}
SILVER :: Color{192, 192, 192, 255}
BLUE :: Color{0, 0, 255, 255}
NAVY :: Color{0, 0, 128, 255}
CYAN :: Color{0, 255, 255, 255}
RED :: Color{255, 0, 0, 255}

fill :: proc(fb: ^Framebuffer, c: Color) {
	p := pack(c)
	for i in 0 ..< len(fb.pixels) {fb.pixels[i] = p}
}

fill_rect :: proc(fb: ^Framebuffer, x, y, w, h: int, c: Color) {
	p := pack(c)
	for yy in max(y, 0) ..< min(y + h, FRAME_H) {
		for xx in max(x, 0) ..< min(x + w, FRAME_W) {
			fb.pixels[yy * FRAME_W + xx] = p
		}
	}
}

// One pixel of colour `c` over the framebuffer with straight alpha.
blend_pixel :: #force_inline proc(fb: ^Framebuffer, x, y: int, r, g, b, a: u32) {
	if x < 0 || y < 0 || x >= FRAME_W || y >= FRAME_H || a == 0 {return}
	idx := y * FRAME_W + x
	if a == 255 {
		fb.pixels[idx] = r | g << 8 | b << 16 | 0xFF000000
		return
	}
	d := fb.pixels[idx]
	dr := d & 0xFF
	dg := (d >> 8) & 0xFF
	db := (d >> 16) & 0xFF
	nr := (r * a + dr * (255 - a)) / 255
	ng := (g * a + dg * (255 - a)) / 255
	nb := (b * a + db * (255 - a)) / 255
	fb.pixels[idx] = nr | ng << 8 | nb << 16 | 0xFF000000
}

rect_outline :: proc(fb: ^Framebuffer, x, y, w, h: int, c: Color) {
	fill_rect(fb, x, y, w, 1, c)
	fill_rect(fb, x, y + h - 1, w, 1, c)
	fill_rect(fb, x, y, 1, h, c)
	fill_rect(fb, x + w - 1, y, 1, h, c)
}

// Draw an atlas sprite with its top-left at (x, y), scaled by an integer factor.
blit :: proc(fb: ^Framebuffer, id: content.Image_Id, x, y: int, scale: int = 1) {
	if id == .None {return}
	r := content.IMAGE_RECTS[id]
	w, h := int(r.w), int(r.h)
	for sy in 0 ..< h {
		for sx in 0 ..< w {
			i := ((int(r.y) + sy) * content.ATLAS_W + int(r.x) + sx) * 4
			a := u32(content.ATLAS_PIXELS[i + 3])
			if a == 0 {continue}
			pr := u32(content.ATLAS_PIXELS[i])
			pg := u32(content.ATLAS_PIXELS[i + 1])
			pb := u32(content.ATLAS_PIXELS[i + 2])
			for oy in 0 ..< scale {
				for ox in 0 ..< scale {
					blend_pixel(fb, x + sx * scale + ox, y + sy * scale + oy, pr, pg, pb, a)
				}
			}
		}
	}
}

// ---------------------------------------------------------------- text (m5x7, proportional)

glyph_index :: #force_inline proc(ch: u8) -> int {
	if ch < 32 || ch > 126 {return int('?') - 32}
	return int(ch) - 32
}

text_width :: proc(s: string) -> int {
	n := 0
	for i in 0 ..< len(s) {n += int(FONT_ADVANCE[glyph_index(s[i])])}
	return n
}

// (x, y) is the top of the line box; glyphs are 7 rows above the baseline and 2 below.
draw_text :: proc(fb: ^Framebuffer, x, y: int, s: string, c: Color) {
	cx := x
	for i in 0 ..< len(s) {
		gi := glyph_index(s[i])
		rows := FONT_ROWS[gi]
		for ry in 0 ..< FONT_CELL_H {
			bits := rows[ry]
			if bits == 0 {continue}
			for rx in 0 ..< 8 {
				if bits & (0x80 >> uint(rx)) != 0 {
					blend_pixel(fb, cx + rx, y + ry, u32(c.r), u32(c.g), u32(c.b), u32(c.a))
				}
			}
		}
		cx += int(FONT_ADVANCE[gi])
	}
}

draw_text_centered :: proc(fb: ^Framebuffer, cx, y: int, s: string, c: Color) {
	draw_text(fb, cx - text_width(s) / 2, y, s, c)
}

// Greedy word wrap into at most `max_lines` lines of `max_w` pixels; returns the number of lines.
wrap_text :: proc(s: string, max_w: int, lines: ^[16]string) -> int {
	n := 0
	start := 0
	last_space := -1
	i := 0
	for i < len(s) && n < 16 {
		if s[i] == ' ' {last_space = i}
		if text_width(s[start:i + 1]) > max_w {
			brk := last_space if last_space > start else i
			lines[n] = s[start:brk]
			n += 1
			start = brk
			if start < len(s) && s[start] == ' ' {start += 1}
			last_space = -1
			i = start
			continue
		}
		i += 1
	}
	if start < len(s) && n < 16 {
		lines[n] = s[start:]
		n += 1
	}
	return n
}

// ---------------------------------------------------------------- number and text building

Text_Buf :: struct {
	data: [160]u8,
	n:    int,
}

tb_str :: proc(b: ^Text_Buf, s: string) {
	for i in 0 ..< len(s) {
		if b.n < len(b.data) {
			b.data[b.n] = s[i]
			b.n += 1
		}
	}
}

tb_int :: proc(b: ^Text_Buf, v: i64) {
	if v < 0 {
		tb_str(b, "-")
		tb_int(b, -v)
		return
	}
	digits: [20]u8
	n := 0
	x := v
	if x == 0 {
		digits[0] = '0'
		n = 1
	}
	for x > 0 {
		digits[n] = u8('0' + x % 10)
		n += 1
		x /= 10
	}
	for i := n - 1; i >= 0; i -= 1 {
		if b.n < len(b.data) {
			b.data[b.n] = digits[i]
			b.n += 1
		}
	}
}

tb_string :: proc(b: ^Text_Buf) -> string {
	return string(b.data[:b.n])
}

// FNV-1a over the pixel bytes (R,G,B,A order): lets the native and wasm builds be compared frame for frame.
frame_hash :: proc(fb: ^Framebuffer) -> u64 {
	h: u64 = 0xcbf29ce484222325
	for p in fb.pixels {
		for shift in ([4]uint{0, 8, 16, 24}) {
			h = (h ~ u64((p >> shift) & 0xFF)) * 0x100000001b3
		}
	}
	return h
}
