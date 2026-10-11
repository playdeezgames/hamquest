package main

// Web shell (js_wasm32). The page owns the animation loop and calls these exports; the game and
// the UI are the same packages the native client uses. Build: tools/build_web.sh

import "base:runtime"
import ui "../../ui"

app: ui.App
ctx: runtime.Context

main :: proc() {
	ctx = context
}

// odin.js calls `step` every animation frame; the page drives everything else itself.
@(export)
step :: proc(dt: f64, c: runtime.Context) -> bool {
	return true
}

// Start a game. Returns 0, or the generation error number.
@(export)
platform_init :: proc "c" (seed_lo, seed_hi: u32) -> i32 {
	context = ctx
	ui.app_new_game(&app, u64(seed_hi) << 32 | u64(seed_lo))
	return i32(app.error)
}

// Show the title menu (a normal start; a fixed ?seed= skips it).
@(export)
platform_open_title :: proc "c" () {
	context = ctx
	ui.app_open_title(&app)
}

// `key` is a ui.Key number (see page/platform.js).
@(export)
platform_key :: proc "c" (key: i32) -> i32 {
	context = ctx
	if key <= 0 || key > i32(max(ui.Key)) {return 0}
	return 1 if ui.app_key(&app, ui.Key(key)) else 0
}

// Draw if anything changed. Returns 1 when the framebuffer holds a new picture.
@(export)
platform_frame :: proc "c" () -> i32 {
	context = ctx
	if !app.dirty {return 0}
	ui.app_draw(&app)
	return 1
}

@(export)
platform_frame_ptr :: proc "c" () -> rawptr {
	return &app.fb.pixels[0]
}

@(export)
platform_width :: proc "c" () -> i32 {
	return ui.FRAME_W
}

@(export)
platform_height :: proc "c" () -> i32 {
	return ui.FRAME_H
}

// The shared text buffer (save text out, load text in), IO_SIZE bytes.
@(export)
platform_io_ptr :: proc "c" () -> rawptr {
	return &app.io[0]
}

@(export)
platform_io_size :: proc "c" () -> i32 {
	return i32(ui.IO_SIZE)
}

// Has the game changed since the page last stored it?
@(export)
platform_save_dirty :: proc "c" () -> i32 {
	return 1 if app.save_dirty else 0
}

// Write the save text into the shared buffer; returns its length.
@(export)
platform_save_encode :: proc "c" () -> i32 {
	context = ctx
	return i32(len(ui.save_encode(&app)))
}

@(export)
platform_save_ack :: proc "c" () {
	app.save_dirty = false
}

// Restore from `n` bytes the page put in the shared buffer: 0 restored, 1 empty save, 2 invalid, 3 other rules.
@(export)
platform_load :: proc "c" (n: i32) -> i32 {
	context = ctx
	if n <= 0 || int(n) > ui.IO_SIZE {return 2}
	return i32(ui.save_decode(&app, string(app.io[:n])))
}

// A tap or click at a point of the 640 by 560 picture.
@(export)
platform_tap :: proc "c" (x, y: i32) {
	context = ctx
	ui.app_tap(&app, int(x), int(y))
}

// The game state: 0 playing, 1 won, 2 lost.
@(export)
platform_state :: proc "c" () -> i32 {
	return i32(app.world.state)
}

// Hash of the current picture as two halves, for the parity test against the native client.
@(export)
platform_hash_lo :: proc "c" () -> u32 {
	context = ctx
	return u32(ui.frame_hash(&app.fb))
}

@(export)
platform_hash_hi :: proc "c" () -> u32 {
	context = ctx
	return u32(ui.frame_hash(&app.fb) >> 32)
}
