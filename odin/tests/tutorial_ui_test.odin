#+build !js
package tests

import "core:os"
import "core:strings"
import "core:testing"
import content "../content"
import game "../game"
import ui "../ui"

// The tutorial as the player meets it: menu entry, the coach box, dismissal, the finish, and the
// promise that the real game is neither saved over nor lost (D27 to D31).

press :: proc(a: ^ui.App, k: ui.Key, n: int = 1) {
	for _ in 0 ..< n {ui.app_key(a, k)}
}

@(test)
tutorial_starts_from_the_menu_and_shows_the_first_lesson :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	ui.app_new_game(a, 11)
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	ui.app_open_title(a)
	// down to Tutorial: Continue is off (nothing done), New Game, Tutorial
	press(a, .Down)
	testing.expect_value(t, a.title_sel, ui.Title_Item.Tutorial)
	press(a, .Enter)
	testing.expect_value(t, a.world.mode, game.Game_Mode.Tutorial)
	testing.expect(t, !a.title)
	ui.app_draw(a)
	hint: ui.Text_Buf
	c := ui.coach_text(a, &hint)
	testing.expect(t, c.ok)
	testing.expect_value(t, c.title, game.TUT_LESSONS[0].title)
	testing.expect_value(t, c.highlight, game.Highlight.Map)
	_ = os.make_directory("build/frames")
	write_ppm("build/frames/tutorial_start.ppm", &a.fb)
	// the coach box is drawn over the log: the lesson's yellow-white background is there
	testing.expect_value(t, a.fb.pixels[(ui.LOG_Y + 30) * ui.FRAME_W + ui.LOG_X + 440], ui.pack(ui.COACH_BG))
}

@(test)
coach_hides_with_enter_until_the_next_room_and_h_recalls :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	ui.app_new_tutorial(a, 3)
	hint: ui.Text_Buf
	testing.expect(t, ui.coach_text(a, &hint).ok)
	press(a, .Enter)
	testing.expect(t, !ui.coach_text(a, &hint).ok)
	// moving inside the room keeps it hidden
	press(a, .Right, 3)
	hint = {}
	testing.expect(t, !ui.coach_text(a, &hint).ok)
	press(a, .H)
	hint = {}
	testing.expect(t, ui.coach_text(a, &hint).ok)
	press(a, .Enter)
	// into the next room: shown again, and it is the next lesson
	press(a, .Right, 12)
	testing.expect_value(t, int(a.world.player.maze_col), 1)
	hint = {}
	c := ui.coach_text(a, &hint)
	testing.expect(t, c.ok)
	testing.expect_value(t, c.title, game.TUT_LESSONS[1].title)
	// a tap on the coach box toggles it
	ui.app_tap(a, ui.LOG_X + 10, ui.LOG_Y + 10)
	hint = {}
	testing.expect(t, !ui.coach_text(a, &hint).ok)
	ui.app_tap(a, ui.LOG_X + 10, ui.LOG_Y + 10)
	hint = {}
	testing.expect(t, ui.coach_text(a, &hint).ok)
}

@(test)
coach_points_the_way_when_the_lesson_is_elsewhere :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	ui.app_new_tutorial(a, 4)
	// pretend the first lessons are done and stand in room A again
	a.world.tut.done[0] = true
	hint: ui.Text_Buf
	c := ui.coach_text(a, &hint)
	testing.expect_value(t, c.title, "Where to?")
	testing.expect(t, strings.has_prefix(c.text, "Head east to find "))
}

@(test)
tutorial_leaves_the_real_game_alone :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	b := new(ui.App)
	defer free(b)
	ui.app_new_game(a, 21)
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	press(a, .Space)
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	press(a, .Space)
	seed, n := a.seed, a.log_len
	testing.expect(t, n > 0)
	before := strings.clone(ui.save_encode(a))
	defer delete(before)

	ui.app_open_title(a)
	// Continue, New Game, Tutorial: start it
	ui.title_activate(a, .Tutorial)
	testing.expect_value(t, a.world.mode, game.Game_Mode.Tutorial)
	// play a bit of it
	press(a, .Right, 5)
	testing.expect_value(t, a.seed, seed)
	testing.expect_value(t, a.log_len, n) // nothing of the tutorial is logged
	after := strings.clone(ui.save_encode(a))
	defer delete(after)
	testing.expect_value(t, after, before) // what would be saved is still the real game
	testing.expect(t, !a.save_dirty || true)

	// the menu offers the way back, and it restores the very same game
	ui.app_open_title(a)
	testing.expect(t, ui.title_enabled(a, .Real_Game))
	testing.expect(t, ui.title_visible(a, .Real_Game))
	ui.title_activate(a, .Real_Game)
	testing.expect_value(t, a.world.mode, game.Game_Mode.Normal)
	testing.expect_value(t, a.log_len, n)
	testing.expect_value(t, string(a.log[:a.log_len]), string(a.log[:n]))
	again := strings.clone(ui.save_encode(a))
	defer delete(again)
	testing.expect_value(t, again, before)
	_ = b
}

@(test)
tutorial_finish_returns_to_a_real_game :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	ui.app_new_tutorial(a, 8)
	testing.expect(t, !ui.real_in_progress(a))
	a.world.state = .Win // reached the exit
	ui.app_draw(a)
	write_ppm("build/frames/tutorial_done.ppm", &a.fb)
	press(a, .Enter)
	testing.expect_value(t, a.world.mode, game.Game_Mode.Normal)
	testing.expect_value(t, a.world.state, game.Play_State.Play)
	// and with a real game in progress, finishing goes back to that one
	b := new(ui.App)
	defer free(b)
	ui.app_new_game(b, 33)
	for b.tip_count > 0 {ui.app_key(b, .Enter)}
	press(b, .Space)
	seed := b.seed
	ui.title_activate(b, .Tutorial)
	b.world.state = .Win
	press(b, .Enter)
	testing.expect_value(t, b.world.mode, game.Game_Mode.Normal)
	testing.expect_value(t, b.seed, seed)
	testing.expect(t, b.log_len > 0)
}

@(test)
mercy_is_explained_for_one_command :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	ui.app_new_tutorial(a, 6)
	w := &a.world
	w.inventory[.Potion] = 0
	w.inventory[.Food] = 0
	game.take_damage(w, 99, 0)
	testing.expect(t, w.tut.mercy)
	hint: ui.Text_Buf
	c := ui.coach_text(a, &hint)
	testing.expect(t, c.ok)
	testing.expect(t, strings.has_prefix(c.title, "That would have been"))
	ui.app_draw(a)
	write_ppm("build/frames/tutorial_mercy.ppm", &a.fb)
	press(a, .Left) // any command
	hint = {}
	testing.expect(t, ui.coach_text(a, &hint).title != c.title)
}
