#+build !js
package tests

import "core:log"
import "core:slice"
import "core:testing"
import content "../content"
import game "../game"

// Finishability playtesting (November 20, 2026). Three questions, from the weakest claim to the strongest:
//
//   1. Structure: on every seed, can all sixteen pieces of the MegaHam, the Summoner and the Exit be
//      reached from the start, picking up keys and opening doors only as they are found?
//   2. Immortal bot: on the real engine (thieves, teleports, wandering monsters, the Amulet), does a
//      bot that cannot die always finish? A failure here is a soft lock, not a hard game.
//   3. Mortal bot: how far does a careful bot with full knowledge of the map get, and what kills it?
//      This is a report, not a pass/fail: the difficulty is the original's, on purpose (D14, D15).
//      It fights through what is in its way, leaves for an empty room when nearly dead (monsters never
//      follow), rests when alone with no food, and shops for potions and armour first. A careful version
//      (walk round monsters, leave when hurt) did worse: it never got a single piece in 24 seeds.
//
// More seeds (about 2.5 s per bot seed): -define:HQ_PLAYTEST_SEEDS=100 -define:HQ_STRUCT_SEEDS=5000

PT_SEEDS :: #config(HQ_PLAYTEST_SEEDS, 4) // small: tools/test.sh (and so tools/ship.sh) runs these
PT_STRUCT_SEEDS :: #config(HQ_STRUCT_SEEDS, 300)
PT_MAX_COMMANDS :: 40000
PT_MORTAL_MAX_COMMANDS :: 8000 // the mortal bot either dies early or stalls (fleeing and resting); longer runs add nothing

Pt_Search :: struct {
	dist:   [NODES]i32,
	parent: [NODES]i32,
	via:    [NODES]game.Direction,
	queue:  [2 * NODES]i32, // a node can be queued twice: once from across a cell edge, once from inside
	edge:   [NODES]bool, // reached so far only by crossing a cell edge (an item there is not picked up)
	inner:  [NODES]bool, // reached a second time, from inside: parent2/via2 hold that step
	parent2: [NODES]i32,
	via2:   [NODES]game.Direction,
	count:  int, // entries in queue order (nearest first)
	busy:   [game.MAZE_ROWS][game.MAZE_COLS]bool, // a live creature is in the cell (a shop there will not open)
	found:  int, // with a goal: the nearest node that meets it, or -1
}

// What a bot is looking for; a search with a goal stops at the nearest node that meets it.
Pt_Goal :: struct {
	active:       bool,
	hunt_summoner: bool,
	ready:        bool,
}

pt_is_target :: proc(w: ^game.World, t: ^game.Tile, g: ^Pt_Goal) -> bool {
	if t.creature != 0 {
		// the Summoner holds the Rainbow Key; anything else is fought only when it is in the way
		return g.hunt_summoner && w.creatures[t.creature - 1].kind == .Summoner
	}
	if t.item == .None {return false}
	if pt_type(t.item) == .Exit {return g.ready}
	return pt_wanted(w, t.item)
}

// Item types looked up once (copying a whole Item_Def per tile made the search slow).
pt_types: [content.Item_Kind]content.Item_Type
pt_types_ready: bool

pt_type :: #force_inline proc(k: content.Item_Kind) -> content.Item_Type {
	if !pt_types_ready {
		for kind in content.Item_Kind {pt_types[kind] = content.ITEMS[kind].item_type}
		pt_types_ready = true
	}
	return pt_types[k]
}

Pt_Policy :: struct {
	keys:         ^[content.Item_Kind]u32,
	traps_ok:     bool,
	portals_ok:   bool,
	exit_ok:      bool,
	amulet_ok:    bool,
	creatures_ok: bool,
}

pt_unpack :: proc(n: int) -> (mc, mr, c, r: int) {
	c = n % game.MAP_COLS
	rest := n / game.MAP_COLS
	r = rest % game.MAP_ROWS
	rest /= game.MAP_ROWS
	mc = rest % game.MAZE_COLS
	mr = rest / game.MAZE_COLS
	return
}

// The node one step away, as player_move would take it (crossing a cell edge wraps into the neighbour).
pt_step :: proc(n: int, d: game.Direction) -> (next: int, crossing: bool) {
	mc, mr, c, r := pt_unpack(n)
	nc := c + game.DIR_DCOL[d]
	nr := r + game.DIR_DROW[d]
	if nc < 0 || nr < 0 || nc >= game.MAP_COLS || nr >= game.MAP_ROWS {
		tc := mc + game.DIR_DCOL[d]
		tr := mr + game.DIR_DROW[d]
		if tc < 0 || tr < 0 || tc >= game.MAZE_COLS || tr >= game.MAZE_ROWS {return -1, false}
		return node_of(tc, tr, (nc + game.MAP_COLS) % game.MAP_COLS, (nr + game.MAP_ROWS) % game.MAP_ROWS), true
	}
	return node_of(mc, mr, nc, nr), false
}

pt_tile :: proc(w: ^game.World, n: int) -> ^game.Tile {
	mc, mr, c, r := pt_unpack(n)
	return &w.cells[mr][mc].map_.tiles[r][c]
}

pt_door_opens :: proc(keys: ^[content.Item_Kind]u32, door: content.Item_Kind) -> bool {
	d := &content.ITEMS[door]
	for i in d.unlocks.start ..< d.unlocks.start + d.unlocks.count {
		e := content.COUNT_POOL[i]
		if keys[e.item] >= e.count {return true}
	}
	return false
}

pt_enterable :: proc(s: ^Pt_Search, w: ^game.World, n: int, crossing: bool, pol: ^Pt_Policy) -> bool {
	t := pt_tile(w, n)
	// player_move does not look at the tile it lands on when it crosses into the next cell
	if !crossing && !game.player_can_enter_terrain(t.terrain) {return false}
	if t.creature != 0 && !pol.creatures_ok {return false}
	if t.item == .None {return true}
	#partial switch pt_type(t.item) {
	case .Door:
		return pt_door_opens(pol.keys, t.item)
	case .Shop:
		mc, mr, _, _ := pt_unpack(n)
		return !s.busy[mr][mc]
	case .Trap, .Hidden:
		return pol.traps_ok
	case .Portal:
		return pol.portals_ok
	case .Amulet:
		return pol.amulet_ok
	case .Exit:
		return pol.exit_ok
	}
	return true
}

pt_player_node :: proc(w: ^game.World) -> int {
	p := w.player
	return node_of(int(p.maze_col), int(p.maze_row), int(p.col), int(p.row))
}

// Breadth-first search from the player over the whole maze.
pt_search :: proc(s: ^Pt_Search, w: ^game.World, pol_in: Pt_Policy, goal_in: Pt_Goal = {}) {
	pol := pol_in
	goal := goal_in
	s.found = -1
	for i in 0 ..< NODES {s.dist[i] = -1}
	s.edge = {}
	s.inner = {}
	s.busy = {}
	for i in 0 ..< w.creature_count {
		c := &w.creatures[i]
		if c.alive {s.busy[c.maze_row][c.maze_col] = true}
	}
	start := pt_player_node(w)
	s.dist[start] = 0
	s.parent[start] = -1
	s.queue[0] = i32(start)
	head, tail := 0, 1
	for head < tail {
		u := int(s.queue[head])
		head += 1
		// crossing into a cell lands on the edge tile without picking up what lies there
		if goal.active && u != start && !s.edge[u] && pt_is_target(w, pt_tile(w, u), &goal) {
			s.found = u
			s.count = tail
			return
		}
		// the exit is a place to arrive at, not to walk through (a creature in the way is fought through)
		t := pt_tile(w, u)
		if u != start && t.item != .None && pt_type(t.item) == .Exit {continue}
		for d in game.Direction {
			v, crossing := pt_step(u, d)
			if v < 0 {continue}
			// a second visit only to arrive from inside where the first came across the edge
			if s.dist[v] >= 0 && (crossing || !s.edge[v]) {continue}
			if !pt_enterable(s, w, v, crossing, &pol) {continue}
			if s.dist[v] < 0 {
				s.dist[v] = s.dist[u] + 1
				s.parent[v] = i32(u)
				s.via[v] = d
			} else {
				s.inner[v] = true
				s.parent2[v] = i32(u)
				s.via2[v] = d
			}
			s.edge[v] = crossing
			s.queue[tail] = i32(v)
			tail += 1
		}
	}
	s.count = tail
}

pt_first_step :: proc(s: ^Pt_Search, target: int) -> game.Command {
	n := target
	for i in 0 ..< NODES {
		p := int(s.parent[n])
		dir := s.via[n]
		if i == 0 && s.inner[n] {
			p = int(s.parent2[n])
			dir = s.via2[n]
		}
		if p < 0 {return .None}
		if s.parent[p] < 0 {return game.Command(int(game.Command.Move_North) + int(dir))}
		n = p
	}
	return .None
}

// ---------------------------------------------------------------- 1. structure

Pt_Struct_Result :: struct {
	ok:          bool,
	needs_traps: bool,
	missing:     [4]int, // quest pieces, summoner, exit, rainbow-key drop
}

// Walk the maze with full knowledge: pick up every key found, open every door those keys open, repeat.
pt_structure :: proc(s: ^Pt_Search, w0: ^game.World, traps_ok: bool) -> (pieces_seen, pieces_total: int, summoner_ok, exit_ok: bool) {
	w := new(game.World)
	defer free(w)
	w^ = w0^
	keys := w.inventory
	for _ in 0 ..< 128 {
		pt_search(s, w, Pt_Policy{keys = &keys, traps_ok = traps_ok, creatures_ok = true})
		changed := false
		for i in 0 ..< s.count {
			n := int(s.queue[i])
			t := pt_tile(w, n)
			if t.item == .None {continue}
			#partial switch pt_type(t.item) {
			case .Key:
				keys[t.item] += 1
				t.item = .None
				changed = true
			case .Door:
				// open it with the first key that fits, as player_move does
				d := &content.ITEMS[t.item]
				for k in d.unlocks.start ..< d.unlocks.start + d.unlocks.count {
					e := content.COUNT_POOL[k]
					if keys[e.item] >= e.count {
						keys[e.item] -= e.count
						t.item = .None
						changed = true
						break
					}
				}
			}
		}
		if !changed {break}
	}
	pt_search(s, w, Pt_Policy{keys = &keys, traps_ok = traps_ok, creatures_ok = true, exit_ok = true})
	for mr in 0 ..< game.MAZE_ROWS {
		for mc in 0 ..< game.MAZE_COLS {
			for r in 0 ..< game.MAP_ROWS {
				for c in 0 ..< game.MAP_COLS {
					n := node_of(mc, mr, c, r)
					t := pt_tile(w, n)
					if t.item == .None {continue}
					#partial switch content.ITEMS[t.item].item_type {
					case .Quest:
						pieces_total += 1
						if s.dist[n] >= 0 {pieces_seen += 1}
					case .Exit:
						if s.dist[n] >= 0 {exit_ok = true}
					}
				}
			}
		}
	}
	for i in 0 ..< w.creature_count {
		c := w.creatures[i]
		if c.alive && c.kind == .Summoner {
			if s.dist[node_of(int(c.maze_col), int(c.maze_row), int(c.col), int(c.row))] >= 0 {summoner_ok = true}
		}
	}
	return
}

@(test)
summoner_always_drops_the_rainbow_key :: proc(t: ^testing.T) {
	rg := content.CREATURES[.Summoner].item_drops
	total: u32
	for i in rg.start ..< rg.start + rg.count {
		e := content.WEIGHT_POOL[i]
		if e.weight == 0 {continue}
		total += u32(e.weight)
		testing.expectf(t, content.Item_Kind(e.value) == .RainbowKey, "the Summoner can drop %v", content.Item_Kind(e.value))
	}
	testing.expect(t, total > 0, "the Summoner drops nothing")
	n := 0
	for k in content.Creature_Kind {
		if k != .None && content.CREATURES[k].creature_count > 0 && k == .Summoner {n += int(content.CREATURES[k].creature_count)}
	}
	testing.expect_value(t, n, 1)
}

@(test)
every_seed_is_structurally_finishable :: proc(t: ^testing.T) {
	s := new(Pt_Search)
	defer free(s)
	w := new(game.World)
	defer free(w)
	total := int(game.quest_item_total())
	strict, with_traps, failed, gen_failed := 0, 0, 0, 0
	for i in 0 ..< PT_STRUCT_SEEDS {
		seed := u64(1000 + i)
		if game.new_game(w, seed) != .None {
			gen_failed += 1
			continue
		}
		seen, placed, summ, exit := pt_structure(s, w, false)
		testing.expectf(t, placed == total, "seed %d: %d pieces placed, %d expected", seed, placed, total)
		if seen == total && summ && exit {
			strict += 1
			continue
		}
		seen, placed, summ, exit = pt_structure(s, w, true)
		if seen == total && summ && exit {
			with_traps += 1
			continue
		}
		failed += 1
		log.errorf("seed %d: not finishable: %d of %d pieces reachable, summoner %v, exit %v", seed, seen, total, summ, exit)
	}
	log.infof("structure over %d seeds: %d finishable without stepping on a trap, %d only through a trap, %d not finishable, %d failed to generate",
		PT_STRUCT_SEEDS, strict, with_traps, failed, gen_failed)
	testing.expect_value(t, failed, 0)
	testing.expect_value(t, gen_failed, 0)
}

// ---------------------------------------------------------------- 2 and 3. bots on the real engine

Pt_Outcome :: enum {
	Win,
	Lose,
	Timeout,
}

Pt_Result :: struct {
	outcome:  Pt_Outcome,
	commands: int,
	turns:    u32,
	pieces:   u32,
	level:    i32,
	killer:   string,
	potions:  int, // immortal only: potions the bot was handed to stay alive
}

pt_buy_rank :: proc(kind: content.Item_Kind) -> int {
	d := &content.ITEMS[kind]
	#partial switch d.item_type {
	case .Healing:
		if d.healing_type == .Save {return 0}
		return 3
	case .Armor:
		return 1
	case .Weapon:
		return 2
	case .Light:
		return 4
	case .Tools, .Antidote:
		return 5
	}
	return 9
}

pt_shop :: proc(w: ^game.World) {
	// best things first: potions that save a life, then armour, weapons, food, light, tools
	for rank in 0 ..< 9 {
		for i in 0 ..< w.shop.count {
			if pt_buy_rank(w.shop.slots[i].item) != rank {continue}
			for _ in 0 ..< 16 {
				before := w.shop.slots[i].count
				game.step_command(w, .Shop_Buy_One, i)
				if w.shop.slots[i].count == before {break}
			}
		}
	}
	game.step_command(w, .Shop_Close)
}

pt_wanted :: proc(w: ^game.World, kind: content.Item_Kind) -> bool {
	#partial switch pt_type(kind) {
	case .Quest, .Key, .RainbowKey, .Weapon, .Armor, .Treasure, .Healing, .Light, .Chest, .Compass, .Tools, .Antidote, .Door:
		return true
	case .Shop:
		return game.money(w) >= 50
	}
	return false
}

pt_has_save_potion :: proc(w: ^game.World) -> bool {
	return game.first_healer(w, .Save) != .None
}

// The nearest node in an empty room: monsters only act in the player's room and never follow.
pt_flee :: proc(s: ^Pt_Search, w: ^game.World) -> game.Command {
	pt_search(s, w, Pt_Policy{keys = &w.inventory})
	mc, mr := int(w.player.maze_col), int(w.player.maze_row)
	for i in 1 ..< s.count {
		n := int(s.queue[i])
		nmc, nmr, _, _ := pt_unpack(n)
		if (nmc != mc || nmr != mr) && !s.busy[nmr][nmc] {return pt_first_step(s, n)}
	}
	return .None
}

pt_choose :: proc(s: ^Pt_Search, w: ^game.World, immortal: bool) -> game.Command {
	quest := w.inventory[content.PLAYER.quest_item]
	total := game.quest_required(w)
	ready := quest == total && w.inventory[.RainbowKey] > 0
	amulet := content.PLAYER.amulet_item

	if ready && game.has_item(w, amulet) {return .Use_Amulet}

	in_room := game.map_has_creature(w)
	hp := game.player_health(w) - w.wounds
	if !immortal {
		// resting calls wandering monsters, so rest only when there is no food left to eat on the move
		if !in_room && w.wounds > 0 && game.first_healer(w, .Eaten) == .None {return .Rest}
		// nearly dead with nothing to save us: leave for an empty room (monsters never follow)
		if in_room && hp <= 2 && !pt_has_save_potion(w) {
			if cmd := pt_flee(s, w); cmd != .None {return cmd}
		}
	}

	// anything next to us gets hit first: it will hit us anyway, and a thief left alone robs us blind
	for d in game.Direction {
		v, crossing := pt_step(pt_player_node(w), d)
		if v >= 0 && !crossing && pt_tile(w, v).creature != 0 {
			return game.Command(int(game.Command.Move_North) + int(d))
		}
	}

	ladder := [3]Pt_Policy {
		{keys = &w.inventory, creatures_ok = true, exit_ok = ready},
		{keys = &w.inventory, creatures_ok = true, exit_ok = ready, traps_ok = true},
		{keys = &w.inventory, creatures_ok = true, exit_ok = ready, traps_ok = true, portals_ok = true},
	}
	goal := Pt_Goal{active = true, hunt_summoner = quest == total, ready = ready}
	for pol in ladder {
		pt_search(s, w, pol, goal)
		if s.found >= 0 {return pt_first_step(s, s.found)}
	}
	// nothing to fetch: rest if we can
	if !in_room {return .Rest}
	return .None
}

pt_killer :: proc(w: ^game.World) -> string {
	for i in 0 ..< w.msg_count {
		id := w.msgs[i].id
		for k in content.Creature_Kind {
			if k != .None && content.CREATURES[k].killed_by_msg == id {return content.CREATURES[k].name}
		}
		for k in content.Item_Kind {
			if k != .None && content.ITEMS[k].item_type == .Trap && content.ITEMS[k].killed_by_msg == id {return content.ITEMS[k].name}
		}
	}
	return "unknown"
}

pt_play :: proc(s: ^Pt_Search, w: ^game.World, seed: u64, immortal: bool) -> (res: Pt_Result) {
	if game.new_game(w, seed) != .None {
		res.outcome = .Timeout
		return
	}
	pick: game.Rng
	game.rng_seed(&pick, seed ~ 0x9e3779b97f4a7c15)
	limit := immortal ? PT_MAX_COMMANDS : PT_MORTAL_MAX_COMMANDS
	for res.commands < limit && w.state == .Play {
		res.commands += 1
		if w.shop.active {
			pt_shop(w)
			continue
		}
		if immortal {
			// never die: hand over potions (the Save healing) and close every wound before each command
			if w.inventory[.Potion] < 20 {
				res.potions += int(20 - w.inventory[.Potion])
				w.inventory[.Potion] = 20
			}
			w.wounds = 0
		}
		cmd := pt_choose(s, w, immortal)
		if cmd == .None {cmd = game.Command(int(game.Command.Move_North) + game.rng_int(&pick, 4))}
		game.step_command(w, cmd)
	}
	res.turns = w.turn
	res.pieces = w.inventory[content.PLAYER.quest_item]
	res.level = w.level
	switch w.state {
	case .Win:
		res.outcome = .Win
	case .Lose:
		res.outcome = .Lose
		res.killer = pt_killer(w)
	case .Play:
		res.outcome = .Timeout
	}
	return
}

@(test)
immortal_bot_always_finishes :: proc(t: ^testing.T) {
	s := new(Pt_Search)
	defer free(s)
	w := new(game.World)
	defer free(w)
	wins, potions := 0, 0
	cmds: [dynamic]int
	defer delete(cmds)
	for i in 0 ..< PT_SEEDS {
		seed := u64(5000 + i)
		r := pt_play(s, w, seed, true)
		if r.outcome == .Win {
			wins += 1
			append(&cmds, r.commands)
		} else {
			log.errorf("seed %d: immortal bot did not finish (%v after %d commands): %d pieces, rainbow key %d, amulet %d",
				seed, r.outcome, r.commands, r.pieces, w.inventory[.RainbowKey], w.inventory[content.PLAYER.amulet_item])
		}
		potions += r.potions
	}
	slice.sort(cmds[:])
	median := 0
	if len(cmds) > 0 {median = cmds[len(cmds) / 2]}
	log.infof("immortal bot: %d of %d seeds finished; median %d commands to win; %d potions handed over in all", wins, PT_SEEDS, median, potions)
	testing.expect_value(t, wins, PT_SEEDS)
}

@(test)
mortal_bot_report :: proc(t: ^testing.T) {
	s := new(Pt_Search)
	defer free(s)
	w := new(game.World)
	defer free(w)
	wins, losses, timeouts := 0, 0, 0
	pieces_hist: [17]int
	killers: map[string]int
	defer delete(killers)
	for i in 0 ..< PT_SEEDS {
		seed := u64(5000 + i)
		r := pt_play(s, w, seed, false)
		switch r.outcome {
		case .Win:
			wins += 1
		case .Lose:
			losses += 1
			killers[r.killer] += 1
		case .Timeout:
			timeouts += 1
		}
		pieces_hist[min(int(r.pieces), 16)] += 1
	}
	log.infof("mortal bot over %d seeds: %d won, %d died, %d stalled (the bot's own limit, not the game)", PT_SEEDS, wins, losses, timeouts)
	log.infof("mortal bot, MegaHam pieces held at the end (0..16): %v", pieces_hist)
	for name, n in killers {log.infof("mortal bot killed by %s: %d", name, n)}
	testing.expect(t, wins + losses + timeouts == PT_SEEDS)
}
