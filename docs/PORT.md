# HamQuest port record

Decisions and findings log, in the style of Kordanor's Cabal's `PORT.md`. Plan: `PORT_PLAN.md`. Rules: `game-reference.md`.

## Decisions

- **D1 Fidelity: modernise freely.** C# is a design reference. Log each departure.
- **D2 Content: generate Odin tables** from XML + CQM at build time.
- **D3 Audio: none in v1.** Provenance of samples and tile art unconfirmed.
- **D4 Extras in v1:** save/resume, touch controls, `?seed=N`.
- **D5 Rendering: framebuffer + packed atlas** (A1/A2 in the plan). Page only stretches the frame.
- **D6 Maze: fixed 8x8**; size stays a single generator constant.
- **D7 Balance: tune as I go.** Rules are tuned while implementing M4, not held for M8; every change is logged here with the old and new value so regressions stay distinguishable.
- **D8 Native SDL2 client: yes.** A second platform shell (`odin/platform/native`) over the same core, in the style of Murder Hobo. Core stays free of platform imports; audio and file IO sit behind the services struct.
- **D9 Name: "HamQuest of SPLORR!!"** (itch.io and vault). Repo and code keep `hamquest`.
- **D10 Vault note now; 640x560 logical size, landscape, integer scaling**; phones landscape with side touch controls.
- **D11 Shop prices: charge the displayed price.** Fixes the `uint`-from-`int` bug (original charged 0). Prices in the data run 25 to 1,000; treasure and stock may be retuned under D7.
- **D12 Blocked moves cost a step: keep.** Any arrow key counts as a step, as in the original; Space remains the deliberate pass.
- **D13 Tutorials: keep first-time pop-ups with a persistent "stop tutorial"** (remembered in localStorage and the save). `always-tutorial` messages still show. No separate help screen in v1.

## Findings

### M0 (2026-10-10)
- Done: `.gitignore` added (build output, legacy `bin/obj`); `odin/{game,content,platform/web/page,tests}`, `tools/`, `docs/` created.
- Verified: Odin `dev-2026-07-nightly:ab0131c` builds a minimal `js_wasm32` module with `-o:size` (17.6 KB). Python 3.12 and node 22 available (node for running wasm tests).
- Done (approved): `git rm --cached` of 782 tracked build files (`bin/`, `obj/`, `Bin/`, `app.publish/*.deploy`, `*.csproj.user`, the WPF temporary `.pfx`). Files remain on disk; removal is staged, not committed. No unique asset lived only under `bin/` (checked). `*.pfx` added to `.gitignore`.
- Not verified: nothing about the C# can be built or run here.

### M1 (in progress)
- **[CHECK] items resolved from the data (not from play):** (a) speed: player `speed-roll` is 2 to 12 moves per turn, scaled by armour (boots x2.0, clothes/chainmail x0.75, platemail x0.5, helmet/shield x1.0), and creatures get `speed / playerSpeed` steps per player move; so plate is slow *and* lets monsters act more often per move. Direction is consistent, so port as written. (b) The Amulet drops **only** from the Necromancer (`item-drops`, 100%; `item-count` 0, placement None). While carried it blocks portals and portal-monster teleports but also blocks the exit; `Y` drops it and teleports you. A boss reward with a trade-off, not a curse. Keep.
- `docs/game-reference.md` drafted from code. Findings with consequences for the port:
  1. **The maze is a spanning tree.** All locks sit on leaf portals and all keys on non-leaf cells, so key/door ordering is solvable by construction. Port generation tests can assert this instead of solving.
  2. **Shopping is free** (price read as `uint` from an `int`; exception swallowed). Decision needed: keep, or charge the displayed price. Affects economy and whether gold matters at all beyond thieves.
  3. **`SpawnMonsters` can hang** when no visited cell has a trap or no `spawns` item is present. The port needs a defined fallback (spawn at a random free interior tile).
  4. **A blocked move still ends a step** (step tracker is advanced by the UI after any arrow key). Probably intended (walls cost time) but changes light burn and monster speed; confirm.
  5. Hard-coded item names in the rules: `Amulet`, `RainbowKey`, `Tools`, `Quest`, `Gold`. The generator should expose them as constants and fail if missing.
  6. Creature speed is relative to the player's rolled speed; heavier armour *slows the player's turn clock*, which makes monsters faster per move. Verify direction with the user before porting the formula.
- Not verified: everything in the reference marked **[CHECK]**; no values (item stats, creature stats) are in the doc yet, they will come from the generator (M2).
- Not yet reviewed: `Maps/Map.cs` creature placement tail, `PlayerMessageStatistics`, `ThemeTable`, `TerrainTable`, `MessageTable` (themes may swap images; check).

### M2 content generator (2026-10-10)
- Done: `tools/hqxml.py` (loader mirroring the C# template/identifier/typing rules) and `tools/gen_content.py` (strict schema; writes `odin/content/content_gen.odin`, `--check` for staleness). Hand-written `odin/content/types.odin`. `tools/test.sh` runs: stale check, `odin check -vet` native and `js_wasm32`, then 9 tests in `odin/tests/content_test.odin`.
- Output: 78 items, 16 creatures (player separate as `PLAYER`), 199 messages, 25 terrains, 41 named generators, 108 images (paths only; atlas packing is M5), 28 tags, 2,178 weight entries, 29 maps (room, 16 passage, 4 passage-door, 4 room-open, 4 room-door). 211 KB of Odin.
- Verified: generator strictness caught 23 real data issues on first run (below). All tests pass natively; the content package type-checks for wasm. **Not verified:** that the generated tables equal what the C# loads at runtime (no way to run it here); parity of weighted-pool *order* is by construction (XML order) but unobservable.
- **Data fixes applied** (all logged in the generator, D1/D7):
  1. `minotaur.defend-generator` was the integer `4`, not a generator name. The C# looked up a null key and would have crashed on the first hit against a minotaur. Now `white-die-4`.
  2. `Tools` price 0 (sold by the TorchShop): now 50 because D11 charges prices. Balance placeholder.
  3. 20 messages the engine references but `messages.xml` never defined (the original showed the raw id, e.g. `NeedRainbowKey` or `PickUpQuest`, in the log). Supplied text in `EXTRA_MESSAGES`; includes the exit-refusal messages.
  4. Text: `PickUpLantern` said "torch"; `PickUpRainbowKey` had "raindbow".
  5. Tutorial image path `images/map/items/armor/boots.png` -> `armors/`.
- Dropped as unread by the engine (`IGNORED`): item `defendRoll`, `defendValue`, `woundsHealed`, `stolenMessage`; creature `itemRemoves`, `attack-roll`.
- Findings for later milestones:
  - The `unlocks` of every door lists exactly its colour key; the `RainbowKey` and `all` template only set shared fields, so **the rainbow key does not open any door** (it is only the exit key). This resolves the earlier [CHECK].
  - Spawn tables (`spawn`, `necromancer`, `summoner`) are precomputed in creature-table order as the C# did; summoners/necromancers draw from their own weights.
  - The `player` creature carries computed stats (attack, health, speed = 0 in the table); `PLAYER` holds its constants.
  - Terrain ids are bytes 0..254; 255 is the overlay's transparent value (checked: no map uses an undefined terrain).
- Repo: `.gitignore` had a `/odin` rule (for the stray test binary) that hid the whole `odin/` directory; narrowed to `/odin/*/odin`.
