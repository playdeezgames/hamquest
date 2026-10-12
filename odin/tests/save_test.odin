#+build !js
package tests

import "core:mem"
import "core:testing"
import content "../content"
import game "../game"
import ui "../ui"

// Play with the full-knowledge bot (and some noise) for n commands through the app, so the log is realistic.
play_app :: proc(a: ^ui.App, seed: u64, n: int) {
	b := new(Bot)
	defer free(b)
	ui.app_new_game(a, seed)
	pick: game.Rng
	game.rng_seed(&pick, seed + 99)
	w := &a.world
	for _ in 0 ..< n {
		for a.tip_count > 0 {ui.app_key(a, .Enter)}
		if w.state != .Play {break}
		if w.shop.active {
			ui.app_key(a, .Enter)
			ui.app_key(a, .Escape)
			continue
		}
		cmd := bot_choose(b, w)
		switch {
		case game.rng_int(&pick, 25) == 0: ui.app_key(a, .Tab)
		case game.rng_int(&pick, 40) == 0: ui.app_key(a, .Space)
		case cmd == .Move_North: ui.app_key(a, .Up)
		case cmd == .Move_East: ui.app_key(a, .Right)
		case cmd == .Move_South: ui.app_key(a, .Down)
		case cmd == .Move_West: ui.app_key(a, .Left)
		case cmd == .Rest: ui.app_key(a, .Space)
		case: ui.app_key(a, .Up)
		}
	}
}

@(test)
save_roundtrip_restores_the_exact_world :: proc(t: ^testing.T) {
	for seed in ([?]u64{1, 5, 23, 77}) {
		a := new(ui.App)
		b := new(ui.App)
		defer free(a)
		defer free(b)
		play_app(a, seed, 150)
		if a.world.state != .Play {continue} // died early: nothing to resume (covered by the empty-marker test)
		text := ui.save_encode(a)
		testing.expectf(t, len(text) > 50 && len(text) < 6000, "seed %d: save is %d bytes", seed, len(text))
		copied := make([]u8, len(text))
		defer delete(copied)
		copy(copied, text)
		res := ui.save_decode(b, string(copied))
		testing.expect_value(t, res, ui.Save_Result.Ok)
		testing.expectf(t, mem.compare_ptrs(&a.world, &b.world, size_of(game.World)) == 0, "seed %d: restored world differs", seed)
		testing.expect_value(t, b.log_len, a.log_len)
		testing.expect_value(t, b.seed, a.seed)
		testing.expect_value(t, b.tip_count, 0)
		// the restored game goes on exactly like the original
		for k in ([?]ui.Key{.Right, .Down, .Space, .Left, .Up, .Up}) {
			ui.app_key(a, k)
			ui.app_key(b, k)
			for a.tip_count > 0 {ui.app_key(a, .Enter)}
			for b.tip_count > 0 {ui.app_key(b, .Enter)}
		}
		testing.expect(t, mem.compare_ptrs(&a.world, &b.world, size_of(game.World)) == 0, "worlds diverged after loading")
	}
}

@(test)
save_of_a_finished_game_is_the_empty_marker :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	play_app(a, 3, 20)
	a.world.state = .Lose
	text := ui.save_encode(a)
	testing.expect_value(t, text, `{"format":"hamquest-save","version":1,"empty":true}`)
	b := new(ui.App)
	defer free(b)
	ui.app_new_game(b, 9)
	ui.app_key(b, .Right)
	before := b.log_len
	testing.expect_value(t, ui.save_decode(b, text), ui.Save_Result.Empty)
	testing.expect_value(t, b.log_len, before) // nothing was touched
}

@(test)
save_rejects_damaged_and_foreign_text :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	play_app(a, 11, 120)
	text := ui.save_encode(a)
	good := make([]u8, len(text))
	copy(good, text)
	defer delete(good)
	b := new(ui.App)
	defer free(b)
	ui.app_new_game(b, 4)
	ui.app_key(b, .Down)
	ref_len := b.log_len
	ref_seed := b.seed

	check :: proc(t: ^testing.T, b: ^ui.App, s: string, want: ui.Save_Result, ref_len: int, ref_seed: u64, what: string) {
		got := ui.save_decode(b, s)
		testing.expectf(t, got == want, "%s: got %v, want %v", what, got, want)
		testing.expectf(t, b.log_len == ref_len && b.seed == ref_seed, "%s: the game was changed", what)
	}
	check(t, b, "", .Invalid, ref_len, ref_seed, "empty text")
	check(t, b, "{}", .Invalid, ref_len, ref_seed, "empty object")
	check(t, b, "not json at all", .Invalid, ref_len, ref_seed, "garbage")
	check(t, b, string(good[:len(good) / 2]), .Invalid, ref_len, ref_seed, "truncated")
	check(t, b, `{"format":"other","version":1,"empty":true}`, .Invalid, ref_len, ref_seed, "wrong format")
	check(t, b, `{"format":"hamquest-save","version":2,"empty":true}`, .Incompatible, ref_len, ref_seed, "future version")

	// flip one command to something illegal
	bad := make([]u8, len(good))
	defer delete(bad)
	copy(bad, good)
	idx := len(bad) - 4
	bad[idx] = 'Z'
	check(t, b, string(bad), .Invalid, ref_len, ref_seed, "illegal command")
	// a shop letter with no slot
	copy(bad, good)
	bad[len(bad) - 3] = 'b'
	bad[len(bad) - 2] = '"'
	check(t, b, string(bad), .Invalid, ref_len, ref_seed, "shop command without a slot")
	// other content hash: refused as incompatible
	copy(bad, good)
	pos := 0
	for i in 0 ..< len(bad) - 10 {
		if string(bad[i:i + 11]) == `"content":"` {
			pos = i + 11
			break
		}
	}
	bad[pos] = '0' if bad[pos] != '0' else '1'
	check(t, b, string(bad), .Incompatible, ref_len, ref_seed, "other content")
	// trailing junk
	extra := make([]u8, len(good) + 1)
	defer delete(extra)
	copy(extra, good)
	extra[len(good)] = ' '
	check(t, b, string(extra), .Invalid, ref_len, ref_seed, "trailing junk")
}

@(test)
save_stays_small_and_log_overflow_disables_it :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	ui.app_new_game(a, 2)
	a.log_full = true
	testing.expect_value(t, ui.save_encode(a), `{"format":"hamquest-save","version":1,"empty":true}`)
}

@(test)
save_log_records_shop_commands :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	ui.app_new_game(a, 1)
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	game.open_shop(&a.world, .PotionShop)
	a.world.inventory[.Gold] = 5000
	ui.app_key(a, .Down)
	ui.app_key(a, .Enter) // buy one of slot 1
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	ui.app_key(a, .A) // buy all of slot 1
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	ui.app_key(a, .Escape)
	testing.expect_value(t, string(a.log[:a.log_len]), "b1B1x")
}

// ---- touch / tap

@(test)
tap_moves_toward_the_tap_and_rests_on_the_player :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	ui.app_new_game(a, 21)
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	w := &a.world
	// clear a cross of floor around the player so the steps are not blocked
	cell := &w.cells[w.player.maze_row][w.player.maze_col]
	pc, pr := int(w.player.col), int(w.player.row)
	px, py := ui.MAP_X + pc * 32 + 16, ui.MAP_Y + pr * 32 + 16
	ui.app_tap(a, px, py)
	testing.expect_value(t, string(a.log[:a.log_len]), "r")
	ui.app_tap(a, px + 90, py + 5)
	testing.expect_value(t, a.log[a.log_len - 1], u8('e'))
	ui.app_tap(a, px - 90, py)
	testing.expect_value(t, a.log[a.log_len - 1], u8('w'))
	ui.app_tap(a, px, py + 100)
	testing.expect_value(t, a.log[a.log_len - 1], u8('s'))
	ui.app_tap(a, px, py - 100)
	testing.expect_value(t, a.log[a.log_len - 1], u8('n'))
	_ = cell
}

@(test)
tap_dismisses_tips_and_drives_shops :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	ui.app_new_game(a, 21)
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	w := &a.world
	a.tips[0] = .PickUpGold
	a.tip_count = 1
	ui.app_tap(a, 300, 300)
	testing.expect_value(t, a.tip_count, 0)

	game.open_shop(w, .WeaponShop)
	w.inventory[.Gold] = 100000
	if w.shop.count < 2 {return}
	lx, ly := ui.SHOP_X + 8, ui.SHOP_Y + 40
	ui.app_tap(a, lx + 20, ly + 2 + 16 + 4) // second row
	testing.expect_value(t, a.shop_sel, 1)
	stock := w.shop.slots[1].count
	ui.app_tap(a, lx + 20, ly + 2 + 16 + 4) // tap again: buy one
	testing.expect_value(t, w.shop.slots[1].count, stock - 1)
	for a.tip_count > 0 {ui.app_tap(a, 300, 300)} // a pick-up tip may have opened
	ui.app_tap(a, lx + 100, ui.SHOP_Y + 310) // Leave
	testing.expect(t, !w.shop.active)
}

@(test)
tap_toggles_fight_mode_and_restarts_after_death :: proc(t: ^testing.T) {
	a := new(ui.App)
	defer free(a)
	ui.app_new_game(a, 21)
	for a.tip_count > 0 {ui.app_key(a, .Enter)}
	w := &a.world
	testing.expect_value(t, w.config, content.Player_Config.Attack)
	ui.app_tap(a, ui.STAT_X + 40, ui.STAT_Y + ui.MODE_DY + 6) // the shield icon
	testing.expect_value(t, w.config, content.Player_Config.Defend)
	ui.app_tap(a, ui.STAT_X + 10, ui.STAT_Y + ui.MODE_DY + 6) // the sword icon
	testing.expect_value(t, w.config, content.Player_Config.Attack)
	w.state = .Lose
	seed := a.seed
	ui.app_tap(a, 100, 100)
	testing.expect_value(t, a.seed, seed + 1)
	testing.expect_value(t, w.state, game.Play_State.Play)
}
