#+build !js
package tests

import "core:testing"
import content "../content"

// Golden counts: change these only when the XML data changes on purpose.
@(test)
content_counts :: proc(t: ^testing.T) {
	testing.expect_value(t, len(content.Item_Kind) - 1, 78)
	testing.expect_value(t, len(content.Creature_Kind) - 1, 16)
	testing.expect_value(t, len(content.Message_Id) - 1, 199) // 179 from messages.xml + 20 supplied by the port
	testing.expect_value(t, len(content.Generator_Id) - 1, 41)
	testing.expect_value(t, content.MAZE_COLS, 8)
	testing.expect_value(t, content.MAZE_ROWS, 8)
	testing.expect_value(t, content.MAP_COLS, 15)
	testing.expect_value(t, content.MAP_ROWS, 15)
}

range_ok :: proc(r: content.Range, pool_len: int) -> bool {
	return int(r.start) + int(r.count) <= pool_len
}

weight_total :: proc(r: content.Range) -> u64 {
	total: u64
	for i in r.start ..< r.start + r.count {
		total += u64(content.WEIGHT_POOL[i].weight)
	}
	return total
}

@(test)
content_ranges_in_bounds :: proc(t: ^testing.T) {
	for kind in content.Item_Kind {
		if kind == .None {continue}
		d := content.ITEMS[kind]
		testing.expectf(t, range_ok(d.spawn_as, len(content.WEIGHT_POOL)), "%v spawn_as", kind)
		testing.expectf(t, range_ok(d.x_gen, len(content.WEIGHT_POOL)), "%v x_gen", kind)
		testing.expectf(t, range_ok(d.y_gen, len(content.WEIGHT_POOL)), "%v y_gen", kind)
		testing.expectf(t, range_ok(d.unlocks, len(content.COUNT_POOL)), "%v unlocks", kind)
		testing.expectf(t, range_ok(d.shop_inventory, len(content.SHOP_POOL)), "%v shop", kind)
		testing.expectf(t, weight_total(d.spawn_as) > 0, "%v spawn_as has no weight", kind)
		testing.expectf(t, weight_total(d.x_gen) > 0 && weight_total(d.y_gen) > 0, "%v has no placement weight", kind)
	}
	for g in content.Generator_Id {
		if g == .None {continue}
		testing.expectf(t, range_ok(content.GENERATORS[g], len(content.WEIGHT_POOL)), "%v", g)
		testing.expectf(t, weight_total(content.GENERATORS[g]) > 0, "%v has no weight", g)
	}
}

@(test)
content_placement_is_inside_map :: proc(t: ^testing.T) {
	for kind in content.Item_Kind {
		if kind == .None {continue}
		d := content.ITEMS[kind]
		for gen in ([2]content.Range{d.x_gen, d.y_gen}) {
			for i in gen.start ..< gen.start + gen.count {
				v := content.WEIGHT_POOL[i].value
				testing.expectf(t, v >= 0 && v < content.MAP_COLS, "%v placement value %d outside the map", kind, v)
			}
		}
	}
}

// Doors and keys: lock types pair up, each lock type has a key and a door for all four directions,
// and a door is opened by a key of the same lock type.
@(test)
content_locks_are_consistent :: proc(t: ^testing.T) {
	keys: [16]content.Item_Kind
	door_dirs: [16][4]bool
	for kind in content.Item_Kind {
		if kind == .None {continue}
		d := content.ITEMS[kind]
		#partial switch d.item_type {
		case .Key:
			testing.expectf(t, d.lock_type >= 0 && d.lock_type < 16, "%v lock_type %d", kind, d.lock_type)
			testing.expectf(t, d.lock_type_weight > 0, "%v lock_type_weight", kind)
			testing.expectf(t, keys[d.lock_type] == .None, "two keys for lock type %d", d.lock_type)
			keys[d.lock_type] = kind
		case .Door:
			testing.expectf(t, d.direction >= 0 && d.direction < 4, "%v direction", kind)
			testing.expectf(t, d.unlocks.count > 0, "%v unlocks nothing", kind)
			door_dirs[d.lock_type][d.direction] = true
		}
	}
	for lt in 0 ..< 16 {
		if keys[lt] == .None {continue}
		for dir in 0 ..< 4 {
			testing.expectf(t, door_dirs[lt][dir], "lock type %d has no door for direction %d", lt, dir)
		}
	}
	for kind in content.Item_Kind {
		d := content.ITEMS[kind]
		if d.item_type != .Door {continue}
		ok := false
		for i in d.unlocks.start ..< d.unlocks.start + d.unlocks.count {
			k := content.COUNT_POOL[i].item
			if content.ITEMS[k].lock_type == d.lock_type {ok = true}
		}
		testing.expectf(t, ok, "%v is not opened by a key of its own lock type", kind)
	}
}

// Names the rules rely on (see docs/game-reference.md section 4).
@(test)
content_rule_items_exist :: proc(t: ^testing.T) {
	testing.expect_value(t, content.PLAYER.quest_item, content.Item_Kind.Quest)
	testing.expect_value(t, content.PLAYER.amulet_item, content.Item_Kind.Amulet)
	testing.expect_value(t, content.PLAYER.currency_item, content.Item_Kind.Gold)
	testing.expect(t, content.ITEMS[.RainbowKey].item_type == .RainbowKey)
	testing.expect(t, content.ITEMS[.Tools].item_type == .Tools)
	testing.expect(t, content.ITEMS[.Exit].item_type == .Exit)
	testing.expect(t, content.PLAYER.xp_goal_div != 0)
	testing.expect(t, weight_total(content.PLAYER.speed_roll) > 0)
}

// D11: shops charge the displayed price, so everything for sale needs a price.
@(test)
content_shop_stock_has_prices :: proc(t: ^testing.T) {
	shops := 0
	for kind in content.Item_Kind {
		d := content.ITEMS[kind]
		if d.item_type != .Shop {continue}
		shops += 1
		testing.expectf(t, d.shop_inventory.count > 0, "%v sells nothing", kind)
		for i in d.shop_inventory.start ..< d.shop_inventory.start + d.shop_inventory.count {
			e := content.SHOP_POOL[i]
			testing.expectf(t, content.ITEMS[e.item].price > 0, "%v sells %v with no price", kind, e.item)
			testing.expectf(t, e.die > 0 && e.roll >= 0 && e.roll <= e.die, "%v stock odds for %v", kind, e.item)
		}
	}
	testing.expect_value(t, shops, 4)
}

@(test)
content_creatures_are_playable :: proc(t: ^testing.T) {
	for kind in content.Creature_Kind {
		if kind == .None {continue}
		d := content.CREATURES[kind]
		if d.is_player {
			testing.expect_value(t, kind, content.Creature_Kind.Player)
			continue
		}
		testing.expectf(t, d.health > 0, "%v has no health", kind)
		testing.expectf(t, d.speed > 0, "%v has no speed", kind)
		testing.expectf(t, d.defend_gen != .None, "%v has no defend generator", kind)
		testing.expectf(t, weight_total(d.morale) > 0, "%v has no morale roll", kind)
		testing.expectf(t, weight_total(d.item_drops) > 0, "%v drops nothing", kind)
		testing.expectf(t, d.hit_msg != .None && d.miss_msg != .None && d.kill_msg != .None, "%v messages", kind)
	}
	for table in content.Spawn_Table {
		testing.expectf(t, content.SPAWN_TABLES[table].count > 0, "%v table empty", table)
	}
}

@(test)
content_terrain_covers_maps :: proc(t: ^testing.T) {
	check :: proc(t: ^testing.T, name: string, layer: content.Map_Layer) {
		for row in layer {
			for v in row {
				testing.expectf(t, v == 255 || content.TERRAIN_DEFINED[v], "%s uses undefined terrain %d", name, v)
			}
		}
	}
	check(t, "room", content.MAP_ROOM)
	for i in 0 ..< 16 {check(t, "pway", content.MAP_PWAY[i])}
	for i in 0 ..< 4 {
		check(t, "pwaydoor", content.MAP_PWAY_DOOR[i])
		check(t, "roomopen", content.MAP_ROOM_OPEN[i])
		check(t, "roomdoor", content.MAP_ROOM_DOOR[i])
	}
}

@(test)
content_messages_have_text :: proc(t: ^testing.T) {
	for id in content.Message_Id {
		if id == .None {continue}
		testing.expectf(t, len(content.MESSAGES[id].text) > 0, "%v has no text", id)
	}
	// fixed typos from the original text
	testing.expect_value(t, content.MESSAGES[.PickUpRainbowKey].text, "You have picked up the rainbow key.")
}
