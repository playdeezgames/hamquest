# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands (Odin port)

```bash
python3 tools/gen_content.py          # regenerate odin/content/content_gen.odin from the XML + .cqm
python3 tools/gen_content.py --check  # fail if the generated file is stale
python3 tools/pack_atlas.py           # repack odin/content/atlas.rgba + atlas_gen.odin (needs Pillow); --check for staleness
python3 tools/gen_font.py             # odin/ui/font_gen.odin from assets/fonts/m5x7.png
~/ODIN/odin build odin/platform/native -vet -out:build/hamquest && build/hamquest --seed 1   # native SDL2 client
tools/build_web.sh                    # build/web (wasm + page); serve with python3 -m http.server 8137 -d build/web
tools/parity.sh                       # native vs wasm frame hashes (needs build/hamquest and build/web)
tools/ship.sh [--push]                # tests, zip build/hamquest-html5.zip, butler push only with --push
tools/test.sh                         # stale checks, odin check -vet (native + js_wasm32), odin test; must end ALL TESTS PASSED
~/ODIN/odin test odin/tests -define:ODIN_TEST_THREADS=1 -define:ODIN_TEST_NAMES=tests.content_counts  # one test
```

Never hand-edit `odin/content/content_gen.odin`; change `tools/gen_content.py` (its `EXTRA_MESSAGES`, `DATA_FIXES`, `IGNORED` tables hold every deliberate departure from the XML). Odin is `~/ODIN/odin` (`dev-2026-07-nightly`).

## Status: legacy C# source, being ported to Odin + wasm (itch.io web build)

HamQuest is a C# roguelike the user wrote between 2007 and 2011: first a WinForms app, then a Silverlight port (the client that carries the canonical data), then an attempted WPF port that was abandoned (.NET 4.5, solution-less `.csproj` files). The goal is an **Odin `js_wasm32` port** shipped as an HTML5 build on itch.io (thegrumpygamedev). The C# is the **reference implementation**: keep it intact and read-only until the port is verified, then decide what to delete.

Nothing here builds on this Linux machine (WPF, Silverlight, .NET Framework 4.x, `PresentationCore`/`WindowsBase`). There are no build, lint or test commands for the C#. `dotnet` is installed but cannot target these projects as-is. The Odin port lives in `odin/`: `content` (generated tables + atlas), `game` (pure rules), `ui` (framebuffer, HUD, input, dialogs) and `platform/native` (SDL2); `platform/web` (wasm export glue; page in `platform/web/page`).

The user's notes vault (`/home/yermom/git/bok-of-splorr/splorr`, Obsidian markdown) is an additional working directory and holds what the port needs: `Tech/Odin wasm recipe.md` (build, frame loop, input, canvas/framebuffer variants), `Tech/Shipping to itch.io.md`, `Tech/Kordanor's Cabal Odin port.md` (closest prior art: a roguelike port with a pure core, tests and a shipping script) and `Gotchas.md` (read it before writing Odin; it has wasm, RNG, JSON and test pitfalls). HamQuest is **not yet listed** in that vault's `Home.md`; per its standing rules, add a `Games/` note with frontmatter and link it from `Home.md` once the port starts.

## Repository layout

Eight project directories, no solution file. Most are duplicated, so **do not assume edits to one propagate**:

| Dir | What it is |
|---|---|
| `HamQuestEngine/` | Game engine library, desktop flavour (WPF `System.Windows.Media`, `System.Drawing`). Newer: has `ShopBehaviors.cs`. |
| `HamQuestEngineSL/` | Silverlight copy of the engine. Same classes, different usings/regions, and **drifted** (lacks `ShopBehaviors.cs`; most files differ textually even ignoring line endings). Treat `HamQuestEngine/` as canonical unless a diff shows otherwise. |
| `PDGBoardGames/`, `PDGBoardGamesSL/` | Generic board/maze library the engine builds on (`Board<T>`, `MazeBase`, `CQMFile`, `WeightedGenerator<T>`, `CountedCollection<T>`, `IRandomNumberGenerator`). SL copy is flattened into one directory. |
| `PDBBoardGames.Tests/` | The only tests: `CountedCollection` and `RandomNumberGenerator` (note the `PDB` typo). Nothing tests the game. |
| `HamQuestWpfClient/` | The attempted WPF port, abandoned. A copy of the Silverlight client; `MainPage.xaml.cs` (845 lines) is the entire UI/game loop. |
| `HamQuestSLClient/` | Silverlight UI client, near-identical to the WPF one. Holds the **canonical data**: `config/*.xml`, `maps/*.cqm`, `images/`, `sounds/`. The WPF client has its own copy of the same assets. |

`bin/`, `obj/`, `*.deploy`, `.pfx`, `.csproj.user` are committed build output (about 1,000 of the 1,650 tracked files). Ignore them; never treat `bin/Debug/...` copies as source.

## Architecture (big picture)

**Data-driven, stringly-typed engine.** Almost all game content is XML in `HamQuestSLClient/config/` (`creatures.xml`, `items.xml`, `messages.xml`, `terrains.xml`, `themes.xml`, `propertyGroups.xml`, plus per-entity files under `creatures/` and `items/`). Each top-level XML lists files; entities can inherit with a `template="a.xml,b.xml"` attribute (comma list, concatenated, later wins; identifiers are *appended*).

**`Descriptor`** (`Item/Descriptor.cs`) is the one universal object: a `Dictionary<string, object>` of properties. Property names are constants in `GameConstants/Properties.cs`. Everything (items, creatures, terrain, messages, property groups, the player) is a `Descriptor` read with `GetProperty<T>(name)`. XML values with a `type="Name"` attribute are instantiated **by reflection**: `PropertyValuePair.LoadPropertyValuesFromXmlNode` finds a class by `Type.Name`, calls its static `LoadFromNode(XElement)`. Untyped values are parsed as int, then float, then bool, then string. To port, that reflection registry becomes an explicit table of "property kinds" (see `DescriptorProperties/`: generators, rollers, bump handlers, key handlers, movers, step tracker, statistic holders, tag sets, counters).

**Two-level world.** `Game` → `Maze` (8x8 grid of cells, `mazeDimensions` property group; generated by `MazeBase` in PDGBoardGames, with portals/doors between cells) → each maze cell owns a `Map` (15x15 tiles, `mapDimensions`). `CellInfo` records what each maze cell holds (items, creatures, visit count). `Maze.populateMaze` (hooked to `OnPostGenerate`) decides room vs passageway, puts locks on dead-end portals, scatters keys/doors/items/creatures by `placement` (`Either`/`DeadEnd`/`NonDeadEnd`/`None`), places the player, then asks each `Map` to `Generate`.

**Map terrain comes from binary `.cqm` files** (`maps/`): byte 0 = width, byte 1 = height, then width*height row-major terrain IDs. All 29 are 15x15 (227 bytes). A cell's terrain is built by *blending* files in order with 255 as the transparent value: `pway{mask}.cqm` (mask = open-portal bitmask, 16 variants) plus `pwaydoor{dir}.cqm` per locked portal, or `room.cqm` + `roomopen{dir}`/`roomdoor{dir}`. The byte value, stringified, is the terrain identifier looked up in `terrains.xml` (`passable`, `bump-handler`, image).

**Turn model.** The UI (`MainPage.xaml.cs` ~line 650-725) maps arrow keys to `Creature.Move(direction)` on the player; `Creature.Move` delegates to the descriptor's `mover` (`PlayerMoveHandler` / `CreatureMoveHandler`). After a move: `PlayerDescriptor.Step()` (a `PlayerStepTracker`; an end-of-turn fires every `speed` steps, which burns the light source and re-rolls speed from armor), `Map.MoveCreatures(1/speed)` (creatures accumulate fractional `Steps` from their `speed` stat), `RemoveDeadCreatures`. Creature AI is BFS "pathfinding value" flooding from the player (`PlayerDescriptor.UpdatePathfinding`), with a `morale-roll` chance of a random step instead.

**Content semantics worth knowing:** keys/doors are colour-coded lock types with weighted spawn; quest items ("MegaHam" pieces) plus a Rainbow Key are needed to use the exit; the Amulet blocks exiting; traps are `Hidden` items revealed when adjacent; some items `spawn-as` other items (re-rolled in a loop); thieves, ghouls, summoners, necromancers and teleporting dragons have `special-attack` behaviours hard-coded in `CreatureMoveHandler`; shops have `ShopBehaviors` Vanish/Teleport/Persist.

**Client** is a thin view: layered image grids (`ImageCellMap`, 4 map layers, 11 minimap layers), 32x32 map tiles, 20x20 minimap tiles, 7x9 digit sprites, tutorial pop-ups driven by message descriptors, sounds triggered from the `MessageQueue` callback by message id (3 samples: key pickup, lock open, carrot nom).

## Quirks and traps for the port

Each of these is a decision to take with the user before "fixing" it; the Odin port should be deliberate about whether to preserve or repair.

1. **`Descriptor.GetProperty<T>` swallows every exception and returns `default(T)`.** A missing property, a wrong type, or a typo silently becomes 0/null/false. Much of the game's behaviour (including bugs) may depend on that. Port with an explicit "missing → zero" rule, and consider a debug mode that logs misses.
2. **Iteration-order dependence.** `WeightedGenerator<T>.Generate` walks a `Dictionary`, so results for a given random roll depend on insertion order (which is XML order today). Reproducing the same weighted results needs the same order. `MinimalValue` is wrong (starts at `default`, so it is never above 0).
3. **Static global player.** `Map.PlayerCreature` is a `static` field; the whole engine assumes one game at a time. `CreatureTable.Reset()` is called on every `Game.Initialize()`; descriptors (including `PlayerDescriptor`, which holds live state: inventory, equipment, XP) are **shared singletons in the table**, so "new game" mutates shared state.
4. **Retry loops with no cap**: `Map.Generate` item/creature placement, `Maze.RespawnItem`, `Maze.SpawnMonsters`, `PlayerDescriptor.Teleport`, and the player-start `do/while`. A `tally > 100` check only writes `"blah"` to the debug log. A full or oddly shaped map hangs forever; on wasm that freezes the browser tab (see vault `Gotchas.md`). Cap every one.
5. **Off-by-one / typo bugs in the original**: `CreatureMoveHandler` compares `nextRow` against `Map.Columns - 1` (works only because maps are square); `Maze.populateMaze` uses string literals (`"roomChance"`, `"total"`, `"doorCount{n}"`) instead of constants; `PlayerDescriptor.AddItem` has a `Portal` case that teleports and `PlayerMoveHandler` has another; `ShopState` is created on every shop bump and adds `AddVisits(7)` to every visited cell as a side effect.
6. **Pathfinding blocks on items**, not just walls: cells holding any item are never entered by the BFS, so creatures can be walled off by pickups. Preserve unless asked.
7. **Game rules live in the move handlers**, not in descriptors: bump → attack → item pickup → door/portal/shop/exit/chest branches in `PlayerMoveHandler.DoMove` is one long if/else chain whose order matters. Door unlocking removes keys and unlocks the *maze portal*; the map tile image changes only because `Map.Generate` is re-derived from portal state.
8. **Coordinates**: `Directions` is an int enum (North, East, South, West = 0..3, with `Opposite`), maze/map are `[column][row]` (column first), and `.cqm` is row-major in the file. Mixed up easily when porting.
9. **XML / file encoding**: sources and configs are UTF-8 with BOM and CRLF. Tool output of these files shows `\r`.
10. **Paths are relative to the working directory** (`config/...`, `./maps/...`, `images/...`) and loaded at runtime with `XDocument.Load` / file IO. In wasm there is no filesystem: content must be baked into the binary (`#load`/`#embed`-style generated Odin tables) or fetched by the page. Odin's `core:os` **panics at start-up on `js_wasm32`** (vault gotcha).
11. **Random numbers**: `System.Random` via `IRandomNumberGenerator` (`Next(max)`, `Next(min,max)`). Not reproducible across platforms, so exact seed parity with the C# build is impossible; plan on an Odin-side seedable generator (the vault's xoshiro256**) and statistical/rule-level equivalence tests instead.
12. **No save/load, no persistence** in the original: a game is a single session. Adding saves is new scope (use a namespaced `localStorage` key; itch.io games share one origin).
13. **No automated game tests exist.** The only way to check behaviour is to play the WPF build on Windows. Any equivalence testing must be written fresh.
14. **Assets**: 32x32 PNG tiles in per-folder files (555 PNGs, duplicated between clients), 3 sound samples (`.wav`/`.mp3`) of unknown licence (filenames carry freesound-style IDs and author names: `j1987`, `wildweasel`, `CGEffex`; unused in v1). **Tile art provenance is settled (user, 2026-10-11):** David Gervais's 32x32 Angband tiles (CC BY 3.0, needs credit and a licence link) plus the user's own doors and walls; see `assets/CREDITS.md`. The samples still need provenance before sound returns.

Port documents (read these before touching port code): `docs/PORT_PLAN.md` (plan and milestones), `docs/game-reference.md` (rules extracted from the C#, with **[CHECK]**/**[BUG?]** markers), `docs/PORT.md` (decision and findings log; add an entry per milestone). Extra quirks found while writing the reference: the maze is a spanning tree (locks only on leaves, keys only on non-leaves, so key order is solvable by construction); shop purchases are free because the price is read as `uint` from an `int` and the exception is swallowed; a blocked move still advances the step tracker; `SpawnMonsters` can spin forever.

## Port plan (draft: not yet agreed with the user)

Follow the shape that worked for Kordanor's Cabal (see vault note):

1. **Freeze the reference.** Keep C# as-is; extract a written rules spec (`docs/game-reference.md`) from `PlayerMoveHandler`, `CreatureMoveHandler`, `PlayerDescriptor`, `Maze`, `Map` and the XML property groups. Record decisions as D1..Dn the way the vault's port notes do.
2. **Data pipeline.** A small script (Python or Odin) that reads `config/**/*.xml` and `maps/*.cqm` and **generates Odin enums + read-only tables** (items, creatures, terrains, messages, generators, 29 maps). Resolve `template=` inheritance at generation time; fail the build if generated files are stale. This removes the runtime reflection and file IO.
3. **Pure game core** (`game` package, no platform imports): world as plain structs, `core_step(input) -> state`, bounded message queue, own seeded RNG, capped retry loops. Rules as plain procedures; creature "special attacks" as one `switch`.
4. **Platform shell** under `#+build js`: wasm page with 2D canvas or software framebuffer (WebGL does not work on the user's machine), keyboard (read `e.key` first, then `e.code`), optional touch, audio, `localStorage`. Native `odin test` runs the core; `#+build !js` on the test file; `-define:ODIN_TEST_THREADS=1`.
5. **Tests**: rule-level unit tests, a maze-solvability test (every generated game must be winnable: keys reachable before their doors, quest items reachable), soak test with random inputs, and a wasm-build check (remember `int` is 32-bit on `js_wasm32`).
6. **Ship**: script in the style of the vault's `tools/ship.sh` (tests, `-o:size` build, zip with `index.html` at the root, push **only** with `--push`). Never run butler or any publish step unless the user says so.

## Decisions (settled with the user)

- **D1 Fidelity: modernise freely.** The C# is a design reference, not a spec to match. Fix bugs and rebalance where it helps; still log each notable change in the port record so it is a choice, not an accident.
- **D2 Content: generate Odin tables** from `config/**/*.xml` and `maps/*.cqm` at build time; no runtime XML parsing or file IO in wasm. Generated files must be checked for staleness by the test script.
- **D3 Audio: ship without sound at first.** Port visuals only; the three samples are excluded until their provenance and licences are confirmed. The 32x32 tile art is kept for now, but its author is also unrecorded: confirm before release.
- **D5-D10 (see `docs/PORT.md`):** framebuffer + packed atlas rendering; fixed 8x8 maze; tune balance while implementing; native SDL2 client in addition to wasm; title "HamQuest of SPLORR!!"; vault note now; 640x560 landscape.
- **D4 Release scope beyond a straight port:** save and resume (namespaced `localStorage` key, validated JSON), touch/phone controls, and `?seed=N` for reproducible runs.

- **D17 (see `docs/PORT.md`):** the web build fits the window (itch.io launches it full screen).
- **D11-D13 (see `docs/PORT.md`):** shops charge the displayed price (original bug: free); blocked moves still cost a step; first-time tutorial pop-ups kept with a persistent "stop tutorial".

- **D14-D16 (see `docs/PORT.md`):** the original's lethality is confirmed, so M4 rules stand and difficulty stays as the original for v1; next is M5 (renderer/HUD, native SDL2 window first).

## Still open

- Sound sample provenance (needed before sound returns). Tile art is settled: Gervais CC BY 3.0 + the user's own, credited in `assets/CREDITS.md` and to be shown in the game's About/itch page.
- Remaining **[CHECK]** items in `docs/game-reference.md` (rainbow/"all" key behaviour).
