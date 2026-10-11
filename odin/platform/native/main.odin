package main

// Native development client (D8): an SDL2 window over the same core and UI as the web build.
//   hamquest [--seed N] [--scale N] [--frames N] [--dump file.ppm]
// --frames N runs N frames and exits (for smoke tests with SDL_VIDEODRIVER=dummy); --dump writes the last frame.

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:time"
import SDL "vendor:sdl2"
import ui "../../ui"

keymap :: proc(sc: SDL.Scancode) -> ui.Key {
	#partial switch sc {
	case .UP, .KP_8: return .Up
	case .DOWN, .KP_2: return .Down
	case .LEFT, .KP_4: return .Left
	case .RIGHT, .KP_6: return .Right
	case .W: return .W
	case .A: return .A
	case .S: return .S
	case .D: return .D
	case .T: return .T
	case .C: return .C
	case .SPACE, .KP_5: return .Space
	case .TAB: return .Tab
	case .RETURN, .KP_ENTER: return .Enter
	case .ESCAPE: return .Escape
	case .F2: return .F2
	case .Y: return .Y
	case .N: return .N
	}
	return .None
}

write_ppm :: proc(path: string, fb: ^ui.Framebuffer) {
	hdr := "P6\n640 560\n255\n"
	data := make([]u8, len(hdr) + ui.FRAME_W * ui.FRAME_H * 3)
	defer delete(data)
	copy(data, hdr)
	o := len(hdr)
	for p in fb.pixels {
		data[o] = u8(p & 0xFF)
		data[o + 1] = u8((p >> 8) & 0xFF)
		data[o + 2] = u8((p >> 16) & 0xFF)
		o += 3
	}
	_ = os.write_entire_file(path, data)
}

main :: proc() {
	seed := u64(time.now()._nsec)
	scale := 2
	max_frames := -1
	dump := ""
	save_path := "hamquest.save"
	use_save := true
	seed_given := false
	keys := "" // comma separated ui.Key numbers: run them, print the frame hash, exit (parity with the wasm build)
	args := os.args
	for i := 1; i < len(args); i += 1 {
		switch args[i] {
		case "--seed":
			i += 1
			if i < len(args) {
				v, _ := strconv.parse_u64(args[i])
				seed = v
				seed_given = true
			}
		case "--save-file":
			i += 1
			if i < len(args) {save_path = args[i]}
		case "--no-save":
			use_save = false
		case "--scale":
			i += 1
			if i < len(args) {
				v, _ := strconv.parse_int(args[i])
				if v >= 1 && v <= 4 {scale = v}
			}
		case "--frames":
			i += 1
			if i < len(args) {max_frames, _ = strconv.parse_int(args[i])}
		case "--dump":
			i += 1
			if i < len(args) {dump = args[i]}
		case "--keys":
			i += 1
			if i < len(args) {keys = args[i]}
		}
	}

	if SDL.Init({.VIDEO}) != 0 {
		fmt.eprintln("SDL_Init failed:", SDL.GetError())
		os.exit(1)
	}
	defer SDL.Quit()
	window := SDL.CreateWindow(
		"HamQuest of SPLORR!!",
		SDL.WINDOWPOS_CENTERED,
		SDL.WINDOWPOS_CENTERED,
		i32(ui.FRAME_W * scale),
		i32(ui.FRAME_H * scale),
		{.SHOWN, .RESIZABLE},
	)
	if window == nil {
		fmt.eprintln("CreateWindow failed:", SDL.GetError())
		os.exit(1)
	}
	defer SDL.DestroyWindow(window)
	renderer := SDL.CreateRenderer(window, -1, {.ACCELERATED, .PRESENTVSYNC})
	if renderer == nil {renderer = SDL.CreateRenderer(window, -1, {.SOFTWARE})}
	if renderer == nil {
		fmt.eprintln("CreateRenderer failed:", SDL.GetError())
		os.exit(1)
	}
	defer SDL.DestroyRenderer(renderer)
	SDL.RenderSetLogicalSize(renderer, ui.FRAME_W, ui.FRAME_H)
	SDL.RenderSetIntegerScale(renderer, true)
	texture := SDL.CreateTexture(renderer, .ABGR8888, .STREAMING, ui.FRAME_W, ui.FRAME_H)
	defer SDL.DestroyTexture(texture)

	app := new(ui.App)
	ui.app_new_game(app, seed)
	// resume the saved game unless a seed was asked for (a seed means "this exact world", and scripted runs)
	if use_save && !seed_given && keys == "" {
		if data, err := os.read_entire_file_from_path(save_path, context.allocator); err == nil {
			if len(data) > 0 && len(data) <= ui.IO_SIZE {
				copy(app.io[:], data)
				res := ui.save_decode(app, string(app.io[:len(data)]))
				fmt.printf("save file: %v\n", res)
			}
			delete(data)
		}
	}
	if app.error != .None {
		fmt.eprintln("world generation failed:", app.error)
		os.exit(1)
	}

	if keys != "" {
		// scripted run: no window needed beyond what is already open
		rest := keys
		for len(rest) > 0 {
			end := 0
			for end < len(rest) && rest[end] != ',' {end += 1}
			v, _ := strconv.parse_int(rest[:end])
			ui.app_key(app, ui.Key(v))
			rest = rest[min(end + 1, len(rest)):]
		}
		ui.app_draw(app)
		fmt.printf("hash %016x\n", ui.frame_hash(&app.fb))
		if dump != "" {write_ppm(dump, &app.fb)}
		return
	}

	fmt.printf("seed %d\n", app.seed)

	frames := 0
	last_save: u32
	running := true
	for running {
		ev: SDL.Event
		for SDL.PollEvent(&ev) {
			#partial switch ev.type {
			case .QUIT:
				running = false
			case .KEYDOWN:
				k := keymap(ev.key.keysym.scancode)
				if k != .None {ui.app_key(app, k)}
			}
		}
		if use_save && !seed_given && app.save_dirty && SDL.GetTicks() - last_save > 1000 {
			write_save(app, save_path)
			last_save = SDL.GetTicks()
		}
		ui.app_draw(app)
		SDL.UpdateTexture(texture, nil, raw_data(app.fb.pixels[:]), ui.FRAME_W * 4)
		SDL.RenderClear(renderer)
		SDL.RenderCopy(renderer, texture, nil, nil)
		SDL.RenderPresent(renderer)
		frames += 1
		if max_frames >= 0 && frames >= max_frames {running = false}
		if max_frames < 0 {SDL.Delay(16)}
	}
	if use_save && !seed_given && keys == "" {write_save(app, save_path)}
	if dump != "" {write_ppm(dump, &app.fb)}
}

// Write the replay save (or the empty marker for a finished game) next to the executable's working directory.
write_save :: proc(app: ^ui.App, path: string) {
	text := ui.save_encode(app)
	if os.write_entire_file(path, transmute([]u8)text) == nil {
		app.save_dirty = false
	}
}
