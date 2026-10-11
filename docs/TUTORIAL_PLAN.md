# Tutorial mode: plan (draft, not agreed)

Written 2026-10-11 after the manual. Decisions get D18+ in `docs/PORT.md` once taken.
This is TODO item 9's "short guided first run" made concrete; D15 (difficulty stays as the original) is untouched:
the tutorial teaches the real game, it does not soften it.

## Why

A cold player today gets a random 8x8 maze, a 640x560 screen of unlabelled icons, a few pop-ups that fire on
*events* (a torch, a key) rather than on *understanding*, and a lethal opening (D14). The manual explains the UI,
but nobody reads a PDF before pressing Play in an itch embed. The tutorial's job: in about ten minutes a new
player can read the screen, survive a fight, use a key, shop, and knows what winning means.

## What exists to build on

- `Tutorial` events and per-message pop-ups (`msg()` in `game/player.odin`): modal, once-only, global "stop tips".
  They teach *things met*, in random order, and say nothing about the HUD.
- A deterministic flat `World` + replay saves (seed + command log): any scripted state must live in `World` so a
  save made mid-tutorial replays identically.
- Generation is `generate(w, seed)`: spanning-tree maze (8x8, `MAZE_COLS/ROWS` from the XML), random placement.
  There is no way today to place a *specific* thing in a *specific* tile.
- The UI has no title or menu (TODO item 5); `F2` starts a new game after a confirm.

## Proposed design

### 1. A hand-authored training level, not a tagged random run

A fixed, small, linear-ish dungeon (6 to 8 rooms) built from the **real** content tables, rooms and rules, so
everything learned transfers. Authored in a hand-written Odin file (`game/tutorial_level.odin`), not in the XML
(nothing here should reach the generator or `CONTENT_HASH`):

- a list of portals (which cells connect, which are locked and by what colour);
- per cell: terrain layer choice (room or passage, as the generator's `assemble_terrain` already does);
- per tile: item kind or creature kind at fixed positions;
- player start tile and the exit.

Reuse `assemble_terrain`, `add_visits` etc. Cells outside the training area simply have no portals and are never
visited, so the minimap stays small and honest (it draws only visited cells already; to be confirmed).

Why not "normal run plus hints": the order of discovery is random (the first key may come after the first boss),
so a script cannot say "now do X". A fixed level makes the script a one-way corridor of lessons.

### 2. Coach steps (the script)

A table of steps `{id, title, text, highlight, goal}`:

- `highlight`: a HUD region (map, minimap, inventory, stats, message log, a specific inventory slot) drawn with a
  pulsing outline, so "how to read the cryptic UI" is taught on the live screen, not in prose.
- `goal`: a predicate evaluated after every command on plain `World` state, no engine hooks needed:
  `Reached_Tile`, `Has_Item(kind)`, `Killed_Any`, `Level_At_Least`, `Door_Opened`, `Shop_Visited`, `Wounds_Zero`,
  `Won`, `Key_Pressed(cmd)` (for "press Space to rest").
- `tutorial_step` lives in `World`; `tutorial_advance(w)` runs after each command in `take_turn`. Pure, bounded,
  testable natively.

The coach text is a strip, not a modal: the player can keep playing while it is shown (a modal for every line
would be the pop-up problem again). Enter/Esc hides it; it returns on the next step. Touch: tap the strip.

### 3. Lessons (as built in T1; wording is draft)

Lessons are keyed to rooms. The player's room decides which lesson is shown; goals are latched; a pointer
leads back to the first unfinished lesson. Layout in `game/tutorial_level.odin` (A to N), lessons in
`game/tutorial.odin`.

| Room | Lesson | Goal |
|---|---|---|
| A start | Moving: map pane, arrows/WASD | enter B |
| B passage | The minimap | enter C |
| C hall | Your pack (the real starting kit), then Gold (six piles, 156 or more) | any gold; 150 gold |
| D | Fighting a skeleton (bump, dice, Tab, mercy), then Resting (Space) | one kill; one rest |
| K | Keys: the red key | have it |
| F | Doors: the red door (torch is made nearly spent when it opens) | enter G |
| G | The shoppe: Up/Down, Enter, A, Esc, real prices; fixed shelf of a torch and tools | one purchase |
| anywhere | Darkness, shown only when only the match is left | a flame again |
| H passage | Traps: a row of five hidden traps, tools disarm | one trap tile cleared |
| I hub | A zombie | second kill |
| L | The megaham: two pieces | both |
| M | The rainbow key | have it |
| N | The exit | win |

Left out on purpose: the Amulet, portal monsters, thieves, ghouls, bosses.

### 4. Failure policy

The tutorial must not be a second brutal opening. Proposal: the player cannot die in the tutorial; a lethal blow
instead restores health, puts the player back at the room entrance, resets that room's creatures, and shows
"In the real game, that would have ended your run." This is a tutorial-only rule, in one place, behind
`w.mode == .Tutorial`.

### 5. Entry, exit and persistence

- Entry (D20): a **title menu is built first** (TODO item 5); "Tutorial" is one of its entries. No first-launch
  prompt stopgap. Whether the menu offers it prominently to new players (no `hq:tutorial` flag yet) is a menu detail.
- Exit: the final step's dialog: Enter starts a normal game with a fresh seed; the tutorial is marked done.
- Persistence: `hq:tutorial = done` in localStorage (native: a small file), so the prompt shows once. A
  tutorial run is saved like any run (replay), with a new top-level `"mode":"tutorial"` field; absent means the
  normal game, so existing saves stay valid and `RULES_VERSION` does not need to change (normal-mode rules are
  untouched; the content hash is unchanged because the level is hand-written, not generated).

### 6. What changes in code

| Area | Change |
|---|---|
| `game/world.odin` | `mode: Game_Mode`, `tutorial_step: u8` on `World` |
| `game/tutorial_level.odin` (new) | the level data and `build_tutorial(w)` |
| `game/tutorial.odin` (new) | step table, `tutorial_advance`, mercy rule hook |
| `game/turn.odin` | call `tutorial_advance`; mercy on lethal damage when `mode == .Tutorial`; bump the shop-visit ageing off (spawns would wreck the script) |
| `ui/app.odin`, `hud.odin` | coach strip, highlight outline, first-launch prompt, `H` key, tap target |
| `ui/save.odin` | optional `mode` field; strict decode keeps rejecting unknown modes |
| `platform/web` | `hq:tutorial` flag (small export + page code); touch button |
| `tests/` | below |

### 7. Tests (the project's rule: nothing ships on a "looks fine")

- **Walkthrough bot**: a scripted command list completes the tutorial from `Start` to `Won` on several RNG
  seeds (dice differ; the mercy rule must make it always finish).
- Every step goal reachable: for each step, the goal predicate is false at step start and true after the
  scripted commands; no step can be skipped into a state where later goals are unsatisfiable (a key lost, a door
  opened early).
- Replay round trip mid-tutorial (save, load, identical `World`); parity natively vs wasm for the walkthrough.
- Normal-mode regression: frame hashes and `bot_test` unchanged (`mode == .Normal` takes the same paths).
- Mercy rule: forced lethal hit resets room and never reaches `Lose`.

### 8. Docs and release material

`docs/game-reference.md` gets a short "tutorial mode" section; `docs/PORT.md` D18+ and a milestone entry; the
manual gets one paragraph ("or press H"); the itch description and a devlog entry; vault game note.

## Milestones (each ends with `tools/test.sh` green and a findings entry)

- **T0 Decisions** (this document; questions below).
- **T-menu Title menu** (prerequisite, D20/D21): minimal title (Continue, New Game, Tutorial, Credits, Quit on native); the tutorial plugs in as an entry.
- **T1 Engine (done 2026-10-11)**: `Game_Mode`, level data, `build_tutorial`, room-keyed lessons and
  `tutorial_update`, mercy rule, walkthrough test. Headless; no UI.
- **T2 Coach UI**: strip, highlight regions, first-launch prompt, `H`, touch; native screenshots for review.
- **T3 Persistence and web**: save `mode`, `hq:tutorial`, wasm parity, browser check.
- **T4 Playtest and ship**: the user plays it cold, text pass, manual/itch/devlog updates; ship only on the
  user's explicit word.

Size: T1 about a day, T2 about a day, T3 and T4 small. The text and the level layout are the real work, and want
the user's eye.

## Risks

1. **Script drift**: rules change, level breaks. Mitigated by the walkthrough bot being in `test.sh`.
2. **Mercy rule hides a real difficulty problem**: the tutorial teaches, but the cold-start wall (D14/D15)
   remains in the real game. The tutorial is necessary but not a fix; revisit D15 with data afterwards.
3. **Text volume**: the HUD is 160 px wide and the font is 5x7. Coach strip lines must be short; long
   explanations stay in the manual.
4. **Entry without a menu** is a stopgap and may be redone with TODO item 5.
5. **Saves**: adding a field to a strict decoder is fine; forgetting to reset `mode` in `app_new_game` would
   leak tutorial rules into a normal game. A test covers it.

## Questions for the user (decided: D18 fixed level, D19 mercy rule, D20 title menu first)

1. Fixed hand-authored level (recommended) or a normal random run with hints?
2. Failure policy: cannot die (mercy rule, recommended), real death with a quick retry, or real death?
3. Entry: first-launch prompt plus `H` (recommended), or wait for a proper title menu?
4. Length and scope: the eleven rooms above (about ten minutes), or shorter (movement, fight, key, exit only)?
5. Voice: plain and brisk, or in the game's own tone (the original's pop-ups are jokey: "I'd be embarrassed.")?
6. Should finishing it give anything (a flag, a credits line, a starting-kit bonus in the real game), or nothing?
