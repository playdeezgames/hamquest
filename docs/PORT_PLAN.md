# HamQuest of SPLORR!! Odin/wasm port plan (reviewed; decisions D1-D10 in PORT.md)

Source of truth for decisions D1-D4 is `CLAUDE.md`. This file is the plan; nothing here is built yet.

## Goal

A browser build of HamQuest in Odin (`js_wasm32`), no emscripten, uploaded to itch.io as an HTML5 zip. Keyboard + touch, save/resume, `?seed=N`, no audio in v1. The C# stays in the repo as the reference until v1 ships.

## Target shape

```
odin/
  game/        pure core, no platform imports (world, rules, generation, ai, rng, save)
  content/     GENERATED: enums + const tables from XML and .cqm (never hand-edited)
  platform/web/  js_wasm32 main + page/ (index.html, platform.js, keys, touch, storage)
  platform/native/  SDL2 dev client over the same core (D8)
  tests/       #+build !js, runs with odin test
tools/
  gen_content.py   XML + CQM -> odin/content/*.odin   (D2)
  build.sh  test.sh  serve.sh  ship.sh   (ship pushes only with --push)
docs/
  PORT_PLAN.md  game-reference.md (rules spec)  PORT.md (decision + findings log)
```

Core/platform split follows Kordanor's Cabal: the page owns the `requestAnimationFrame` loop and calls exported `proc "c"` functions (`platform_frame`, `platform_key`, `platform_tap`, `platform_frame_ptr`); the core draws into an RGBA framebuffer or a tile/command list. Platform services (storage, entropy, log) are passed in once so tests inject fakes.

## Key design choices (proposed, open for review)

| # | Choice | Why |
|---|---|---|
| A1 | **Render a CPU framebuffer** (tile blits from one packed atlas) and let the page stretch it, rather than a per-sprite JS API | One foreign call; pixel-exact; works where WebGL does not; trivially testable natively |
| A2 | **Atlas packed at build time** from the 555 PNGs (32x32 map, 20x20 minimap, digits, statistics) into one PNG + generated rect table | Avoids ~180 image loads, avoids runtime paths |
| A3 | **World as flat arrays and enums**, not descriptors: `Item_Kind`, `Creature_Kind`, `Terrain_Kind` enums with const `[Kind]Def` tables | Kills reflection, string property names and silent-default reads (quirk 1) |
| A4 | **Typed, validated generator output**: the generator fails loudly on a missing/misspelled property or unknown type | Replaces `GetProperty` swallowing exceptions |
| A5 | **Own seeded RNG** (xoshiro256**), state in the save, seed from URL or entropy | Reproducible QA; ends the default-RNG question; `rand` not used |
| A6 | **Weighted tables are explicit ordered arrays** | No dictionary-order dependence (quirk 2) |
| A7 | **No globals**: `Game` struct passed everywhere; player is a field, not a static | Quirk 3; enables new-game, tests, saves |
| A8 | **All placement loops bounded**, with a deterministic fallback scan | Quirk 4 |
| A9 | **Turn = one `take_turn(game, command)`**; animations (if any) live in the platform layer | Roomba Rights pattern; tests and solver skip animation |
| A10 | **Single logical resolution** = original layout (640x560: 480x480 map + 160 panel, 15x15 of 32 px) scaled by integer factor to fit | Keeps the art and HUD intact; touch overlays outside the frame |

## Milestones

Each milestone ends with `tools/test.sh` green and a findings entry in `docs/PORT.md` (done / verified / not verified / consequences).

**M0 Repo hygiene (small).** Add `.gitignore`; decide whether to `git rm --cached` the committed `bin/`, `obj/`, `*.deploy`, `.pfx`. Create `odin/`, `tools/`, `docs/`. Verify Odin nightly and `odin check` on a hello-wasm. Add the vault `Games/HamQuest` note (or defer, see open questions).

**M1 Rules spec.** Write `docs/game-reference.md` from the C#: turn order, combat roll, defend rollers, step/speed model, light burn, equipment auto-equip (Attack vs Defend config), healing items (Eaten/Save), shops (Vanish/Teleport/Persist), doors/keys/locks, portals/teleport, traps/hidden, spawners, special attacks (thief, ghoul, teleport, generator/summon, dragon), quest + rainbow key + amulet win logic, XP/levels. List every place the spec departs from the C# (D1) with a reason.

**M2 Content generator.** `tools/gen_content.py` (stdlib only): resolves `template=` chains, types the untyped values, maps `type="X"` to a closed set of Odin variants, emits enums + tables for items, creatures, terrains, messages, property groups, themes, generator tables, and the 29 CQM maps as `[15][15]u8`. Also emits the atlas rects. Test: golden counts (items, creatures, terrains, messages = 179) and a stale-file check.

**M3 World + generation.** Maze generation (port `MazeBase`: carve, portals, dead ends), room/passage choice from `roomChance`, locks on dead ends with doors placed in the neighbour, keys on non-dead-ends, item/creature placement, player start, per-cell map assembly by blending CQM layers. Tests: maze connected, every lock type has a reachable key before its door, quest items and exit reachable, no placement exhausts its cap, 1,000 seeds.

**M4 Turn engine.** Move/bump/attack/pickup/door/portal/shop/exit/chest, creature movement with BFS flood and morale, step tracker, spawning from traps, respawn. Unit tests per rule from the spec; a **solver/soak test** (random + greedy bot over many seeds: never hangs, invariants hold, a bot with perfect knowledge can win on most seeds).

**M5 Rendering + HUD.** Framebuffer renderer for map (terrain, items, creature, splat layers), light radius, minimap (11 layers), inventory grid, stats (digit sprites), message log, shop dialog, tutorial pop-ups, win/lose screens. Native golden-image tests against a handful of recorded states (our own renders; the original cannot be run here).

**M6 Web shell.** `index.html` + `platform.js`: canvas stretch, keyboard (`e.key` first), Tab/F2/Enter/Escape equivalents, focus handling inside the itch iframe, `?seed=`, `?log=1`. wasm size check with `-o:size`.

**M6b Native SDL2 shell (D8).** Window, keyboard/gamepad, file saves, optional audio hook; same `core_step` and framebuffer as the web shell. Used for fast playtesting and golden-image capture.

**M7 Save/resume + touch.** JSON save (versioned, validated on load; unknown enum names rejected; 64-bit values as hex; namespaced key `hq:save`; explicit "empty" marker instead of deleting). Touch: on-screen d-pad + action buttons, tap-to-select in shop/inventory, no pinch/scroll.

**M8 Polish and ship.** Balance pass (D1 allows it): difficulty curve, thieves/ghouls annoyance, light consumption, shop prices. ITCH_DESCRIPTION.md, cover, screenshots, credits (tile art + any future audio). Playtest in the user's Chrome and a phone. Ship script; the user runs `--push` (or says so explicitly).

**Later (not v1):** sound (after provenance), more levels/content, selectable maze size.

## Risks

1. **Unknown asset provenance** (tile art, samples). Blocks release, not development. Fallback: Urizen (CC0, already in the vault) re-skinned to the 32x32 grid, at the cost of art redo.
2. **Hidden behaviour in the C#** that only shows in play (no tests, cannot run it here). Mitigation: the rules spec is written from code, reviewed with the user who has played it, and the user plays builds early (M4 text/ASCII dump, M5 visuals).
3. **Silent-default semantics**: some properties may be missing in XML and rely on 0/null defaults. The generator's strict mode will surface every one; each gets an explicit default in the spec.
4. **`int` is 32 bits on wasm**: use `i64` for XP/gold totals and timestamps; run the wasm build in `test.sh`, not only native tests.
5. **Two engines have drifted** (`HamQuestEngine` vs `...SL`). Mitigation: M1 diffs them semantically (not textually) and records which wins.
6. **Scope creep** from D1 "modernise freely". Mitigation: every departure is a logged decision; balance changes only in M8.
7. **Test hang**: any loop in tests bounded (vault gotcha); `ODIN_TEST_THREADS=1`; tests built `-o:speed`.

## Review checklist (for us)

- Is the framebuffer-plus-atlas approach (A1/A2) what you want, or would you rather keep crisp per-sprite canvas draws (A1 alt) so assets can stay separate files?
- Is 640x560 right as the logical size for itch's embed, and do you want a landscape-only phone layout?
- M3: keep the original 8x8 maze, or make size a setting?
- Should combat/economy be re-tuned only in M8, or as part of M4?
- Is a native SDL2 client wanted (Murder Hobo style), or wasm + node tests only?
- Vault: create `Games/HamQuest of SPLORR!!` now (name?), or after M5?
- Title/branding: "HamQuest" vs "of SPLORR!!" suffix.
