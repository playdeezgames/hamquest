#+build !js
package tests

import "core:os"
import "core:testing"
import content "../content"
import game "../game"
import ui "../ui"

// Real frames from the real renderer for the itch.io page (copied to assets/screenshots/ by hand with
// tools/make_screenshots.py). A cheat keeps the player alive so the bot can explore far; nothing here is
// asserted beyond "it drew something".

visited_cells :: proc(w: ^game.World) -> int {
	n := 0
	for r in 0 ..< game.MAZE_ROWS {
		for c in 0 ..< game.MAZE_COLS {
			if w.cells[r][c].visit_count > 0 {n += 1}
		}
	}
	return n
}

monster_near :: proc(w: ^game.World, dist: int) -> bool {
	for i in 0 ..< w.creature_count {
		c := w.creatures[i]
		if !c.alive || c.maze_col != w.player.maze_col || c.maze_row != w.player.maze_row {continue}
		dx := abs(int(c.col) - int(w.player.col))
		dy := abs(int(c.row) - int(w.player.row))
		if dx <= dist && dy <= dist {return true}
	}
	return false
}

hit_visible :: proc(w: ^game.World) -> bool {
	if w.been_hit {return true}
	for i in 0 ..< w.creature_count {
		if w.creatures[i].alive && w.creatures[i].been_hit {return true}
	}
	return false
}

drive_step :: proc(a: ^ui.App, b: ^Bot, cheat: bool) {
	w := &a.world
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	if w.shop.active {
		ui.app_key(a, .Escape)
		return
	}
	if cheat {w.wounds = 0}
	cmd := bot_choose(b, w)
	#partial switch cmd {
	case .Move_North: ui.app_key(a, .Up)
	case .Move_East: ui.app_key(a, .Right)
	case .Move_South: ui.app_key(a, .Down)
	case .Move_West: ui.app_key(a, .Left)
	case: ui.app_key(a, .Space)
	}
}

shot :: proc(a: ^ui.App, name: string) {
	ui.app_draw(a)
	_ = os.make_directory("build/shots")
	write_ppm(name, &a.fb)
}

@(test)
shots_for_the_itch_page :: proc(t: ^testing.T) {
	b := new(Bot)
	defer free(b)
	a := new(ui.App)
	defer free(a)
	ui.app_new_game(a, 4)
	w := &a.world
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	shot(a, "build/shots/01_start.ppm")

	// a fight in the dark
	for _ in 0 ..< 3000 {
		drive_step(a, b, true)
		if hit_visible(w) && monster_near(w, 3) {break}
	}
	shot(a, "build/shots/02_fight.ppm")

	// explored enough to fill the minimap
	for _ in 0 ..< 4000 {
		drive_step(a, b, true)
		if visited_cells(w) >= 22 && !monster_near(w, 5) && w.state == .Play {break}
	}
	shot(a, "build/shots/03_explored.ppm")

	// a shop (opened where the player stands, as walking into one does)
	w.inventory[.Gold] = 640
	game.open_shop(w, .ArmorShop)
	shot(a, "build/shots/04_shop.ppm")
	ui.app_key(a, .Escape)

	// a first-time tip
	a.tips[0] = .PickUpRedKey
	a.tip_count = 1
	shot(a, "build/shots/05_tip.ppm")
	ui.app_key(a, .Enter)

	// credits
	ui.app_key(a, .C)
	shot(a, "build/shots/06_credits.ppm")
	ui.app_key(a, .Escape)
	testing.expect(t, w.state != .Win)
	_ = content.PLAYER
}
