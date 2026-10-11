#+build !js
package tests

import "core:testing"
import ui "../ui"

// The title menu (D20, D21): it sits over a game without touching it.

menu_app :: proc(seed: u64) -> ^ui.App {
	a := new(ui.App)
	ui.app_new_game(a, seed)
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	return a
}

play_some :: proc(a: ^ui.App) {
	ui.app_key(a, .Space)
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
}

@(test)
menu_fresh_game_has_no_continue_and_new_game_keeps_the_world :: proc(t: ^testing.T) {
	a := menu_app(5)
	defer free(a)
	seed := a.seed
	ui.app_open_title(a)
	testing.expect(t, a.title)
	testing.expect_value(t, a.title_sel, ui.Title_Item.New_Game)
	testing.expect(t, !ui.title_enabled(a, .Continue))
	testing.expect(t, !ui.title_enabled(a, .Tutorial))
	ui.app_key(a, .Enter)
	testing.expect(t, !a.title)
	testing.expect_value(t, a.seed, seed) // untouched world is the new game
}

@(test)
menu_continue_resumes_and_keys_do_not_reach_the_game :: proc(t: ^testing.T) {
	a := menu_app(6)
	defer free(a)
	play_some(a)
	n := a.log_len
	testing.expect(t, n > 0)
	ui.app_key(a, .Escape) // in play: opens the menu
	testing.expect(t, a.title)
	testing.expect_value(t, a.title_sel, ui.Title_Item.Continue)
	ui.app_key(a, .Right)
	ui.app_key(a, .Space)
	testing.expect(t, !a.title) // Space activates Continue
	testing.expect_value(t, a.log_len, n)
	ui.app_key(a, .Escape)
	ui.app_key(a, .Escape) // Escape on the title also continues
	testing.expect(t, !a.title)
	testing.expect_value(t, a.log_len, n)
}

@(test)
menu_new_game_asks_first_when_a_game_is_in_progress :: proc(t: ^testing.T) {
	a := menu_app(7)
	defer free(a)
	play_some(a)
	seed := a.seed
	ui.app_open_title(a)
	ui.app_key(a, .Down) // New Game
	testing.expect_value(t, a.title_sel, ui.Title_Item.New_Game)
	ui.app_key(a, .Enter)
	testing.expect(t, a.confirm_new)
	ui.app_key(a, .Escape)
	testing.expect(t, !a.confirm_new && a.title)
	testing.expect_value(t, a.seed, seed)
	ui.app_key(a, .Enter)
	ui.app_key(a, .Enter) // confirm
	testing.expect(t, !a.title)
	testing.expect(t, a.seed != seed)
	testing.expect_value(t, a.log_len, 0)
}

@(test)
menu_selection_skips_disabled_and_quit_needs_a_window :: proc(t: ^testing.T) {
	a := menu_app(8)
	defer free(a)
	ui.app_open_title(a)
	ui.app_key(a, .Down) // New Game -> Credits (Tutorial is disabled, Quit hidden)
	testing.expect_value(t, a.title_sel, ui.Title_Item.Credits)
	ui.app_key(a, .Down)
	testing.expect_value(t, a.title_sel, ui.Title_Item.New_Game) // wraps
	testing.expect(t, !ui.title_visible(a, .Quit))
	a.can_quit = true
	ui.app_key(a, .Up)
	testing.expect_value(t, a.title_sel, ui.Title_Item.Quit)
	ui.app_key(a, .Enter)
	testing.expect(t, a.quit)
}

@(test)
menu_credits_return_to_the_title_and_taps_work :: proc(t: ^testing.T) {
	a := menu_app(9)
	defer free(a)
	a.can_quit = true
	play_some(a)
	ui.app_open_title(a)
	ui.app_key(a, .C)
	testing.expect(t, a.credits && a.title)
	ui.app_key(a, .Enter)
	testing.expect(t, !a.credits && a.title)
	// tap rows: Continue is row 0, Credits row 3, Quit row 4
	ui.app_tap(a, ui.TITLE_ITEM_X + 10, ui.TITLE_ITEM_Y + 3 * ui.TITLE_ITEM_STEP + 5)
	testing.expect(t, a.credits)
	ui.app_tap(a, 10, 10)
	testing.expect(t, !a.credits && a.title)
	ui.app_tap(a, 5, 5) // outside any item
	testing.expect(t, a.title)
	ui.app_tap(a, ui.TITLE_ITEM_X + 10, ui.TITLE_ITEM_Y + 5)
	testing.expect(t, !a.title) // Continue
	ui.app_draw(a)
}

@(test)
menu_game_over_escape_opens_title_and_new_game_starts_fresh :: proc(t: ^testing.T) {
	a := menu_app(10)
	defer free(a)
	play_some(a)
	seed := a.seed
	a.world.state = .Lose
	ui.app_key(a, .Escape)
	testing.expect(t, a.title)
	testing.expect(t, !ui.title_enabled(a, .Continue))
	ui.app_key(a, .Enter)
	testing.expect(t, !a.title)
	testing.expect(t, a.seed != seed)
	testing.expect_value(t, int(a.world.state), 0)
}
