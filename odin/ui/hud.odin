package ui

import content "../content"
import game "../game"
import "core:math"

// Draws the whole game screen (the layout of the original MainPage.xaml, 640 by 560):
//   map 480x480 at (0,0) | minimap 160x160, inventory 160x224, statistics 160x96 at x=480 | messages 640x80 at y=480

MAP_PX :: 480
TILE :: 32
PANEL_X :: 480
INV_Y :: 160
STAT_Y :: 384
MSG_Y :: 480

BACKGROUND :: WHITE
MINIMAP_BG :: GRAY


draw_world :: proc(fb: ^Framebuffer, w: ^game.World) {
	fill(fb, BACKGROUND)
	draw_map(fb, w)
	draw_minimap(fb, w)
	draw_inventory(fb, w)
	draw_statistics(fb, w)
	draw_messages(fb, w)
}

// ---------------------------------------------------------------- the map and its light

draw_map :: proc(fb: ^Framebuffer, w: ^game.World) {
	m := game.player_map(w)
	p := w.player
	for row in 0 ..< game.MAP_ROWS {
		for col in 0 ..< game.MAP_COLS {
			t := m.tiles[row][col]
			x := col * TILE
			y := row * TILE
			blit(fb, content.TERRAINS[t.terrain].image, x, y)
			is_player := int(p.col) == col && int(p.row) == row
			if is_player {
				blit(fb, content.CREATURES[.Player].image, x, y)
				if w.been_hit {blit(fb, .MapCreaturesMiscSplat, x, y)}
			} else if t.creature != 0 {
				c := w.creatures[t.creature - 1]
				blit(fb, content.CREATURES[c.kind].image, x, y)
				if c.been_hit {blit(fb, .MapCreaturesMiscSplat, x, y)}
			}
			if t.item != .None {blit(fb, content.ITEMS[t.item].image, x, y)}
		}
	}
	apply_light(fb, w)
}

// Darken the map pane by the light's radial profile, centred on the player's tile.
apply_light :: proc(fb: ^Framebuffer, w: ^game.World) {
	ls := game.light_source(w)
	lr := content.Light_Radius.LightsMatch
	if ls != .None && content.ITEMS[ls].light_radius != .None {lr = content.ITEMS[ls].light_radius}
	profile := &content.LIGHT_PROFILES[lr]
	cx := int(w.player.col) * TILE + TILE / 2
	cy := int(w.player.row) * TILE + TILE / 2
	for y in 0 ..< MAP_PX {
		dy := y - cy
		for x in 0 ..< MAP_PX {
			dx := x - cx
			d2 := dx * dx + dy * dy
			r := int(math.sqrt(f32(d2)))
			if r >= content.LIGHT_PROFILE_LEN {r = content.LIGHT_PROFILE_LEN - 1}
			a := u32(profile[r])
			if a == 0 {continue}
			idx := y * FRAME_W + x
			px := fb.pixels[idx]
			k := 255 - a
			nr := (px & 0xFF) * k / 255
			ng := ((px >> 8) & 0xFF) * k / 255
			nb := ((px >> 16) & 0xFF) * k / 255
			fb.pixels[idx] = nr | ng << 8 | nb << 16 | 0xFF000000
		}
	}
}

// ---------------------------------------------------------------- minimap

cell_has_creature :: proc(w: ^game.World, col, row: int) -> bool {
	for i in 0 ..< w.creature_count {
		c := &w.creatures[i]
		if c.alive && int(c.maze_col) == col && int(c.maze_row) == row {return true}
	}
	return false
}

cell_has_tag :: proc(m: ^game.Map, tag: content.Tag) -> bool {
	for row in 0 ..< game.MAP_ROWS {
		for col in 0 ..< game.MAP_COLS {
			k := m.tiles[row][col].item
			if k != .None && tag in content.ITEMS[k].tags {return true}
		}
	}
	return false
}

minimap_marker :: proc(creature, item, exit, portal: bool) -> content.Image_Id {
	switch {
	case creature && item: return .MinimapMarkersRedgreen
	case creature && exit: return .MinimapMarkersRedyellow
	case creature && portal: return .MinimapMarkersRedblue
	case creature: return .MinimapMarkersRed
	case item && exit: return .MinimapMarkersYellowgreen
	case portal && exit: return .MinimapMarkersYellowblue
	case item && portal: return .MinimapMarkersGreenblue
	case item: return .MinimapMarkersGreen
	case exit: return .MinimapMarkersYellow
	case portal: return .MinimapMarkersBlue
	}
	return .None
}

minimap_side :: proc(room: bool, quest: bool, d: game.Direction) -> content.Image_Id {
	if !room {
		switch d {
		case .North: return .MinimapPassagewayNorth
		case .East: return .MinimapPassagewayEast
		case .South: return .MinimapPassagewaySouth
		case .West: return .MinimapPassagewayWest
		}
	}
	if quest {
		switch d {
		case .North: return .MinimapQuestNorth
		case .East: return .MinimapQuestEast
		case .South: return .MinimapQuestSouth
		case .West: return .MinimapQuestWest
		}
	}
	switch d {
	case .North: return .MinimapChamberNorth
	case .East: return .MinimapChamberEast
	case .South: return .MinimapChamberSouth
	case .West: return .MinimapChamberWest
	}
	return .None
}

DOOR_IMAGES := [6][game.Direction]content.Image_Id {
	{.North = .MinimapDoorsRedNorth, .East = .MinimapDoorsRedEast, .South = .MinimapDoorsRedSouth, .West = .MinimapDoorsRedWest},
	{.North = .MinimapDoorsYellowNorth, .East = .MinimapDoorsYellowEast, .South = .MinimapDoorsYellowSouth, .West = .MinimapDoorsYellowWest},
	{.North = .MinimapDoorsGreenNorth, .East = .MinimapDoorsGreenEast, .South = .MinimapDoorsGreenSouth, .West = .MinimapDoorsGreenWest},
	{.North = .MinimapDoorsCyanNorth, .East = .MinimapDoorsCyanEast, .South = .MinimapDoorsCyanSouth, .West = .MinimapDoorsCyanWest},
	{.North = .MinimapDoorsBlueNorth, .East = .MinimapDoorsBlueEast, .South = .MinimapDoorsBlueSouth, .West = .MinimapDoorsBlueWest},
	{.North = .MinimapDoorsMagentaNorth, .East = .MinimapDoorsMagentaEast, .South = .MinimapDoorsMagentaSouth, .West = .MinimapDoorsMagentaWest},
}

minimap_door :: proc(lock: int, d: game.Direction) -> content.Image_Id {
	if lock < 0 || lock >= len(DOOR_IMAGES) {return .None}
	return DOOR_IMAGES[lock][d]
}

draw_minimap :: proc(fb: ^Framebuffer, w: ^game.World) {
	fill_rect(fb, PANEL_X, 0, 160, 160, MINIMAP_BG)
	has_compass := w.inventory[.Compass] > 0
	for row in 0 ..< game.MAZE_ROWS {
		for col in 0 ..< game.MAZE_COLS {
			c := &w.cells[row][col]
			if c.visit_count <= 0 {continue}
			x := PANEL_X + col * 20
			y := row * 20
			if col == int(w.player.maze_col) && row == int(w.player.maze_row) {
				blit(fb, .MinimapMiscHighlight, x, y)
			}
			room := c.cell_type == .Room
			quest := room && has_compass && cell_has_tag(&c.map_, .Quest)
			// base
			switch {
			case !room: blit(fb, .MinimapPassagewayBase, x, y)
			case quest: blit(fb, .MinimapQuestBase, x, y)
			case: blit(fb, .MinimapChamberBase, x, y)
			}
			for d in game.Direction {
				pt := game.portal_of(w, col, row, d)
				if pt != nil && pt.open {blit(fb, minimap_side(room, quest, d), x, y)}
			}
			for d in game.Direction {
				pt := game.portal_of(w, col, row, d)
				if pt != nil && pt.open && pt.locked {blit(fb, minimap_door(int(pt.lock_type), d), x, y)}
			}
			marker := minimap_marker(
				cell_has_creature(w, col, row),
				cell_has_tag(&c.map_, .Item),
				cell_has_tag(&c.map_, .Exit),
				cell_has_tag(&c.map_, .Portal),
			)
			blit(fb, marker, x, y)
		}
	}
}

// ---------------------------------------------------------------- inventory

format_count :: proc(b: ^Text_Buf, n: u32) {
	switch {
	case n > 10_000_000:
		tb_int(b, i64(n / 1_000_000))
		tb_str(b, "M")
	case n > 1_000_000:
		tb_int(b, i64(n / 1_000_000))
		tb_str(b, ".")
		tb_int(b, i64((n % 1_000_000) / 100_000))
		tb_str(b, "M")
	case n > 10_000:
		tb_int(b, i64(n / 1000))
		tb_str(b, "K")
	case n > 1000:
		tb_int(b, i64(n / 1000))
		tb_str(b, ".")
		tb_int(b, i64((n % 1000) / 100))
		tb_str(b, "K")
	case:
		tb_int(b, i64(n))
	}
}

// Share of the item currently in use that is left (0..1); used to colour the wear marker.
condition_fraction :: proc(w: ^game.World, k: content.Item_Kind) -> f32 {
	d := &content.ITEMS[k]
	per: i32
	#partial switch d.item_type {
	case .Weapon, .Armor:
		per = d.durability
	case .Light:
		per = d.duration
	}
	if per <= 0 {return 1}
	held := i64(w.durability[k]) - i64(w.inventory[k] - 1) * i64(per)
	return f32(held) / f32(per)
}

draw_inventory :: proc(fb: ^Framebuffer, w: ^game.World) {
	for k in content.Item_Kind {
		if k == .None || w.inventory[k] == 0 {continue}
		d := &content.ITEMS[k]
		if d.inventory_col < 0 || d.inventory_row < 0 || d.inventory_col >= 5 || d.inventory_row >= 7 {continue}
		x := PANEL_X + int(d.inventory_col) * 32
		y := INV_Y + int(d.inventory_row) * 32
		equipped := game.is_equipped(w, k)
		if equipped {blit(fb, .MapUiSelection, x, y)}
		if equipped {
			f := condition_fraction(w, k)
			if f <= 0.25 {
				blit(fb, .MapUiReddurability, x, y)
			} else if f <= 0.5 {
				blit(fb, .MapUiYellowdurability, x, y)
			}
		}
		blit(fb, d.image, x, y)
		b: Text_Buf
		format_count(&b, w.inventory[k])
		s := tb_string(&b)
		draw_text(fb, x + 1 + 1, y + 1 + 1, s, CYAN)
		draw_text(fb, x + 1, y + 1, s, BLACK)
	}
}

// ---------------------------------------------------------------- statistics

defend_maximum :: proc(w: ^game.World) -> i32 {
	total: i32
	for at in content.Armor_Type {
		if at == .None {continue}
		k := w.armor[at]
		if k != .None {total += game.gen_max(content.ITEMS[k].defend_gen)}
	}
	return total
}

stat_line :: proc(fb: ^Framebuffer, icon: content.Image_Id, x, y: int, a: i64, b: i64 = -1) {
	blit(fb, icon, x, y)
	t: Text_Buf
	tb_int(&t, a)
	if b >= 0 {
		tb_str(&t, "/")
		tb_int(&t, b)
	}
	draw_text(fb, x + 18, y + 3, tb_string(&t), BLACK)
}

draw_statistics :: proc(fb: ^Framebuffer, w: ^game.World) {
	x0 := PANEL_X
	y0 := STAT_Y
	health := i64(game.player_health(w))
	stat_line(fb, .StatisticsAttack, x0, y0, i64(game.player_attack(w)))
	stat_line(fb, .StatisticsDefend, x0, y0 + 16, i64(defend_maximum(w)))
	stat_line(fb, .StatisticsHealth, x0, y0 + 32, max(health - i64(w.wounds), 0), health)
	stat_line(fb, .StatisticsSpeed, x0 + 80, y0, i64(w.step_total))
	stat_line(fb, .StatisticsExperience, x0 + 80, y0 + 16, i64(w.xp), i64(w.xp_goal))
	stat_line(fb, .StatisticsLevel, x0 + 80, y0 + 32, i64(w.level))
	// fight mode: the chosen one is outlined
	if w.config == .Defend {
		blit(fb, .MapUiSelection, x0 + 32, y0 + 64)
	} else {
		blit(fb, .MapUiSelection, x0, y0 + 64)
	}
	blit(fb, .MapUiAttackmode, x0, y0 + 64)
	blit(fb, .MapUiDefendmode, x0 + 32, y0 + 64)
}

// ---------------------------------------------------------------- messages

// The text of a message with {0} replaced by its argument.
message_text :: proc(b: ^Text_Buf, m: game.Msg) {
	text := content.MESSAGES[m.id].text
	i := 0
	for i < len(text) {
		if i + 2 < len(text) && text[i] == '{' && text[i + 1] == '0' && text[i + 2] == '}' {
			tb_int(b, i64(m.arg))
			i += 3
		} else {
			if b.n < len(b.data) {
				b.data[b.n] = text[i]
				b.n += 1
			}
			i += 1
		}
	}
}

draw_messages :: proc(fb: ^Framebuffer, w: ^game.World) {
	for i in 0 ..< w.msg_count {
		m := w.msgs[i]
		b: Text_Buf
		message_text(&b, m)
		col := content.COLORS[content.MESSAGES[m.id].color]
		draw_text(fb, 4, MSG_Y + i * 16 + 4, tb_string(&b), Color{col.r, col.g, col.b, 255})
	}
}
