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
	case .UP, .W, .KP_8: return .Up
	case .DOWN, .S, .KP_2: return .Down
	case .LEFT, .KP_4: return .Left
	case .RIGHT, .D, .KP_6: return .Right
	case .SPACE, .KP_5: return .Space
	case .TAB: return .Tab
	case .RETURN, .KP_ENTER: return .Enter
	case .ESCAPE: return .Escape
	case .F2: return .F2
	case .Y: return .Y
	case .A: return .A
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
	args := os.args
	for i := 1; i < len(args); i += 1 {
		switch args[i] {
		case "--seed":
			i += 1
			if i < len(args) {
				v, _ := strconv.parse_u64(args[i])
				seed = v
			}
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
	if app.error != .None {
		fmt.eprintln("world generation failed:", app.error)
		os.exit(1)
	}
	fmt.printf("seed %d\n", seed)

	frames := 0
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
		ui.app_draw(app)
		SDL.UpdateTexture(texture, nil, raw_data(app.fb.pixels[:]), ui.FRAME_W * 4)
		SDL.RenderClear(renderer)
		SDL.RenderCopy(renderer, texture, nil, nil)
		SDL.RenderPresent(renderer)
		frames += 1
		if max_frames >= 0 && frames >= max_frames {running = false}
		if max_frames < 0 {SDL.Delay(16)}
	}
	if dump != "" {write_ppm(dump, &app.fb)}
}
