package content

// Hand-written types for the generated tables in content_gen.odin.
// Weighted lists are ranges into WEIGHT_POOL (value, weight); what `value` means depends on the field:
//   spawn_as, generated_item, item_drops: an Item_Kind ordinal (0 = None)
//   x_gen, y_gen, initial_inventory, speed_roll, GENERATORS: a plain integer
//   morale: 0 or 1

Range :: struct {
	start, count: u16,
}

Weighted :: struct {
	value:  i32,
	weight: u32,
}

Item_Count :: struct {
	item:  Item_Kind,
	count: u32,
}

Shop_Entry :: struct {
	item:     Item_Kind,
	in_stock: i32, // number of independent stock trials
	roll:     i32, // a trial succeeds when Next(die) < roll
	die:      i32,
}

Map_Layer :: [MAP_ROWS][MAP_COLS]u8 // [row][column]; 255 is transparent in overlay layers

Item_Def :: struct {
	name:               string,
	item_type:          Item_Type,
	placement:          Placement,
	image:              Image_Id,
	tags:               Tag_Set,
	item_count:         i32,
	price:              i32,
	inventory_col:      i32, // -1: never shown in the inventory grid
	inventory_row:      i32,
	spawn_as:           Range,
	x_gen, y_gen:       Range,
	initial_inventory:  Range,
	pick_up_msg:        Message_Id,
	bump_msg:           Message_Id,
	use_msg:            Message_Id,
	broken_msg:         Message_Id,
	go_out_msg:         Message_Id,
	disarm_msg:         Message_Id,
	killed_by_msg:      Message_Id,
	item_block_msg:     Message_Id,
	attack_value:       i32,
	durability:         i32,
	duration:           i32,
	light_level:        i32,
	light_radius_image: Image_Id,
	two_handed:         bool,
	armor_type:         Armor_Type,
	defend_gen:         Generator_Id,
	speed_multiplier:   f32,
	healing_type:       Healing_Type,
	healing_amount:     i32,
	lock_type:          i32, // -1 when not a lock/key
	lock_type_weight:   i32,
	direction:          i32, // 0..3 North East South West, -1 when not directional
	unlocks:            Range, // into COUNT_POOL
	disarms:            Range, // into COUNT_POOL
	item_blocks:        Item_Kind,
	min_value:          i32,
	max_value:          i32,
	generated_item:     Range,
	hidden_item:        Item_Kind,
	shop_title:         string,
	shop_inventory:     Range, // into SHOP_POOL
}

Creature_Def :: struct {
	name:               string,
	image:              Image_Id,
	tags:               Tag_Set,
	mover:              Mover,
	is_player:          bool,
	attack:             i32, // 0 for the player (computed from the weapon)
	health:             i32, // 0 for the player (level + initial_health)
	speed:              i32, // 0 for the player (rolled)
	attack_die:         i32,
	number_of_attacks:  i32,
	experience_points:  i32,
	defend_player:      bool, // true: sum of worn armour generators
	defend_gen:         Generator_Id,
	morale:             Range,
	item_drops:         Range,
	creature_count:     i32,
	spawn_weight:       i32,
	necromancer_weight: i32,
	summoner_weight:    i32,
	placement:          Placement,
	special_attack:     Special_Attack,
	generator_table:    Spawn_Table, // which table a Generator special attack summons from
	item_blocks:        Item_Kind,
	hit_msg:            Message_Id,
	miss_msg:           Message_Id,
	kill_msg:           Message_Id,
	hit_by_msg:         Message_Id,
	missed_by_msg:      Message_Id,
	killed_by_msg:      Message_Id,
	item_block_msg:     Message_Id,
}

Player_Def :: struct {
	initial_health:         i32,
	health_per_level:       i32,
	initial_xp:             i32,
	initial_xp_goal:        i32,
	xp_goal_mul:            i32,
	xp_goal_div:            i32,
	initial_level:          i32,
	speed_roll:             Range,
	quest_item:             Item_Kind,
	amulet_item:            Item_Kind,
	currency_item:          Item_Kind,
	config:                 Player_Config,
	gain_xp_point_msg:      Message_Id,
	gain_xp_points_msg:     Message_Id,
	gain_level_msg:         Message_Id,
	killed_msg:             Message_Id,
	rest_msg:               Message_Id,
	cannot_rest_msg:        Message_Id,
	cannot_exit_amulet_msg: Message_Id,
	need_rainbow_msg:       Message_Id,
	need_megaham_msg:       Message_Id,
	won_msg:                Message_Id,
	quest_completed_msg:    Message_Id,
	thief_gold_msg:         Message_Id,
	thief_megaham_msg:      Message_Id,
	ghoul_msg:              Message_Id,
}

Message_Def :: struct {
	text:           string,
	color:          Text_Color,
	sound:          Sound_Effect,
	always_tutorial: bool,
	tutorial_image: Image_Id,
	tutorial_title: string,
	tutorial_text:  string,
}

Terrain_Def :: struct {
	passable: bool,
	bump:     Bump_Handler,
	image:    Image_Id,
	tags:     Tag_Set,
}
