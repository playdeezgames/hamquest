#+build !js
package tests

import "core:os"
import "core:testing"
import content "../content"
import game "../game"
import ui "../ui"

write_ppm :: proc(path: string, fb: ^ui.Framebuffer) {
	hdr := "P6\n800 600\n255\n"
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

new_app :: proc(seed: u64) -> ^ui.App {
	a := new(ui.App)
	ui.app_new_game(a, seed)
	return a
}

count_colors :: proc(fb: ^ui.Framebuffer, x0, y0, x1, y1: int) -> int {
	seen: map[u32]bool
	defer delete(seen)
	for y in y0 ..< y1 {
		for x in x0 ..< x1 {
			seen[fb.pixels[y * ui.FRAME_W + x]] = true
		}
	}
	return len(seen)
}

@(test)
ui_atlas_rects_are_inside_the_atlas :: proc(t: ^testing.T) {
	testing.expect_value(t, len(content.ATLAS_PIXELS), content.ATLAS_W * content.ATLAS_H * 4)
	for id in content.Image_Id {
		if id == .None {continue}
		r := content.IMAGE_RECTS[id]
		testing.expectf(t, r.w > 0 && r.h > 0, "%v has no rect", id)
		testing.expectf(t, int(r.x + r.w) <= content.ATLAS_W && int(r.y + r.h) <= content.ATLAS_H, "%v outside the atlas", id)
	}
	// every image the game data refers to must have art
	for k in content.Item_Kind {
		if k == .None {continue}
		testing.expectf(t, content.ITEMS[k].image != .None, "%v has no image", k)
	}
	for k in content.Creature_Kind {
		if k == .None {continue}
		testing.expectf(t, content.CREATURES[k].image != .None, "%v has no image", k)
	}
	for id in 0 ..< 256 {
		if content.TERRAIN_DEFINED[id] {
			testing.expectf(t, content.TERRAINS[id].image != .None, "terrain %d has no image", id)
		}
	}
	for lr in content.Light_Radius {
		if lr == .None {continue}
		p := content.LIGHT_PROFILES[lr]
		testing.expect_value(t, p[0], u8(0)) // clear at the light
		testing.expect_value(t, p[len(p) - 1], u8(255)) // dark far away
	}
}

@(test)
ui_text_measures_and_wraps :: proc(t: ^testing.T) {
	testing.expect_value(t, ui.text_width(""), 0)
	testing.expect(t, ui.text_width("WWWW") > ui.text_width("iiii"))
	lines: [16]string
	n := ui.wrap_text("You have picked up a small bundle of sapphires from the floor.", 120, &lines)
	testing.expect(t, n >= 2)
	for i in 0 ..< n {testing.expect(t, ui.text_width(lines[i]) <= 120)}
}

@(test)
ui_first_frame_looks_like_the_game :: proc(t: ^testing.T) {
	a := new_app(1)
	defer free(a)
	// dismiss any opening tips so the HUD shows
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	ui.app_draw(a)
	fb := &a.fb
	testing.expect(t, count_colors(fb, ui.MAP_X, ui.MAP_Y, ui.MAP_X + ui.MAP_PX, ui.MAP_Y + ui.MAP_PX) > 20, "map pane is almost blank")
	testing.expect(t, count_colors(fb, ui.PANEL_X, ui.INV_Y, ui.PANEL_X + 160, ui.INV_Y + 224) >= 2, "inventory is empty")
	testing.expect(t, count_colors(fb, ui.LOG_X, ui.LOG_Y, ui.LOG_X + ui.LOG_W, ui.LOG_Y + ui.LOG_H) >= 2, "message pane is empty")
	// the minimap panel starts gray with the first cell lit
	testing.expect_value(t, fb.pixels[(ui.MINI_Y + 5) * ui.FRAME_W + ui.PANEL_X + 5], ui.pack(ui.GRAY))
	_ = os.make_directory("build/frames")
	write_ppm("build/frames/start.ppm", fb)
}

@(test)
ui_scenes_render_and_dump :: proc(t: ^testing.T) {
	a := new_app(7)
	defer free(a)
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	// walk around so there is something to see
	keys := [?]ui.Key{.Right, .Right, .Down, .Down, .Left, .Up, .Space, .Right, .Right, .Right, .Down, .Down}
	for k in keys {
		ui.app_key(a, k)
		for a.tip_count > 0 {ui.app_key(a, .Enter)}
	}
	ui.app_draw(a)
	write_ppm("build/frames/walk.ppm", &a.fb)

	// a shop
	w := &a.world
	w.cells[w.player.maze_row][w.player.maze_col].map_.tiles[w.player.row][w.player.col].item = .None
	game.open_shop(w, .WeaponShop)
	w.inventory[.Gold] = 300
	ui.app_draw(a)
	write_ppm("build/frames/shop.ppm", &a.fb)
	testing.expect(t, w.shop.active)
	ui.app_key(a, .Down)
	ui.app_key(a, .Escape)
	testing.expect(t, !w.shop.active)

	// a tip
	a.tips[0] = .PickUpAmulet
	a.tip_count = 1
	ui.app_draw(a)
	write_ppm("build/frames/tip.ppm", &a.fb)
	ui.app_key(a, .Enter)
	testing.expect_value(t, a.tip_count, 0)

	// game over
	w.state = .Lose
	ui.app_draw(a)
	write_ppm("build/frames/over.ppm", &a.fb)
	seed := a.seed
	ui.app_key(a, .F2)
	testing.expect_value(t, a.seed, seed + 1)
	testing.expect_value(t, w.state, game.Play_State.Play)
}

@(test)
ui_keys_drive_the_game :: proc(t: ^testing.T) {
	a := new_app(3)
	defer free(a)
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	w := &a.world
	col, row := w.player.col, w.player.row
	moved := false
	for k in ([?]ui.Key{.Up, .Right, .Down, .Left}) {
		ui.app_key(a, k)
		if w.player.col != col || w.player.row != row {moved = true}
		for a.tip_count > 0 {ui.app_key(a, .Enter)}
	}
	testing.expect(t, moved || w.state != .Play, "arrow keys did not move the player")
	before := w.config
	ui.app_key(a, .Tab)
	testing.expect(t, w.config != before)
	// new game needs confirmation
	ui.app_key(a, .F2)
	testing.expect(t, a.confirm_new)
	ui.app_key(a, .Escape)
	testing.expect(t, !a.confirm_new)
	// stop tips: turns them off and survives a new game
	a.tips[0] = .PickUpGold
	a.tip_count = 1
	ui.app_key(a, .T)
	testing.expect(t, w.tutorial_off)
	ui.app_key(a, .F2)
	ui.app_key(a, .Enter)
	testing.expect(t, w.tutorial_off)
}

@(test)
ui_credits_open_and_close :: proc(t: ^testing.T) {
	a := new_app(2)
	defer free(a)
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	log_before := a.log_len
	ui.app_key(a, .C)
	testing.expect(t, a.credits)
	// keys do not reach the game while the screen is open
	ui.app_key(a, .Right)
	testing.expect_value(t, a.log_len, log_before)
	ui.app_draw(a)
	testing.expect(t, count_colors(&a.fb, 90, 90, 550, 420) > 3)
	_ = os.make_directory("build/frames")
	write_ppm("build/frames/credits.ppm", &a.fb)
	ui.app_key(a, .Enter)
	testing.expect(t, !a.credits)
	ui.app_key(a, .C)
	ui.app_tap(a, 10, 10)
	testing.expect(t, !a.credits)
}
