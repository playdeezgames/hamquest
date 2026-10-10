# HamQuest rules reference (extracted from the C# code)

Status: **M1 draft**, written from `HamQuestEngine/` (canonical) and `HamQuestSLClient/config/`. Not yet checked against play. Items marked **[CHECK]** need the user, who has played the game, to confirm. Items marked **[BUG?]** look unintended; the port decides per D1 (see `PORT.md`).

Notation: `file:Class.method`. "Roll" values come from weighted tables in `config/propertyGroups.xml` (`generators` group). `Next(n)` is a uniform integer in `[0, n)`.

## 1. World

- **Maze**: 8 columns x 8 rows of cells (`mazeDimensions`). Generated as a **spanning tree** (randomised Prim's: `MazeBase.Generate`). Consequences: no loops, every cell reachable, "dead end" = a leaf cell with exactly one open portal.
- **Cell type**: each cell is a *Room* with probability `doorCountN / 100` by its open-door count N (1: 100, 2: 50, 3: 75, 4: 25), otherwise a *Passageway*. Dead ends are therefore always rooms.
- **Map**: every cell has a 15x15 tile map. Terrain is assembled by blending `.cqm` layers (255 = transparent, later layer wins): passageways use `pway{mask}` (mask = open directions, bit 0 = North ... bit 3 = West; the C# loop builds it from West down to North so North is the lowest bit) plus `pwaydoor{d}` per locked portal; rooms use `room` + `roomopen{d}` / `roomdoor{d}`.
- Directions: North 0, East 1, South 2, West 3. Opposite = (d+2)%4. Row increases downward (North = row-1).
- Moving off a map edge enters the neighbouring maze cell and wraps the coordinate (`PlayerMoveHandler`). Only the player may step through the doorway terrain (`PlayerOnlyBumpHandler`).
- Terrain has `passable` and a bump handler: `AlwaysDeny` (walls), `AlwaysAllow` (floor), `PlayerOnly` (doorways).

## 2. Generation (`Maze.populateMaze`, `Map.Generate`)

Order matters because it consumes the RNG; the port need not match the order (D1) but must keep the **structure**:

1. Generate the maze tree; for each cell choose Room/Passageway; build the cell's terrain.
2. **Locks**: the single portal of every dead-end cell is locked with a `lockType` drawn from `LockTypeGenerator` (weights come from key items' `lock-type-weight`). Lock counts per type are tallied.
3. **Doors**: for each locked portal, a door item for that lock type and direction is added to the *neighbouring* cell's item list (the door sits on the non-dead-end side).
4. **Keys**: for every lock of type T, one key item of type T goes into a random **non-dead-end** cell. So keys are never behind locks (all locks guard leaves). Solvability by construction. **[CHECK]** the rainbow key / "all" key.
5. **Items**: every item with `item-count` > 0 is added that many times, by `placement`: `Either` (any cell), `DeadEnd`, `NonDeadEnd`, `None`. Then `Map.Generate` places each at a tile drawn from the item's `x-generator`/`y-generator` (retry until the tile is passable and empty), and re-rolls through `spawn-as` chains until the identifier stops changing (this is how generic "treasure" or "trap" become specific ones, and how `Hidden` traps appear).
6. **Creatures**: every creature with `creature-count` > 0, by `placement`; placed at a random interior tile (1..13) that is passable, empty, creature-free.
7. **Player** starts in a random **non-dead-end** cell. Initial inventory comes from each item's `initial-inventory` generator. `AutoEquip()` then picks gear.
8. `PlayerDescriptor.UpdatePathfinding()` and `RevealTraps()`.

## 3. The turn (`MainPage.moveCommand/updateGameCommand`)

For each arrow key while `PlayerState == Play`:

1. `player.Move(dir)`: mover resolves the target tile (section 4).
2. `StepTracker.DoStep()`: `steps++`; when `steps >= total` the **end-of-turn** fires: `decrementLightSource()` then `rollSpeed()` (which resets `steps = 0`). So a "turn" is `total` player moves, where `total` = `speed-roll` (2..12, triangular) scaled by the product of worn armour `speed-multiplier`, min 1.
3. `Map.MoveCreatures(1 / speed)` for the *current* map: each live creature accumulates `speed_stat / player_speed` steps and moves/attacks once per whole step (heavier armour = more monster moves per player move). The divisor is `speed` = `StepTracker.Total` (confirmed from data, see PORT.md).
4. `Map.RemoveDeadCreatures()`; the UI redraws; a pending `ShopState` opens the shop dialog.

Other keys: **Tab** toggles *Attack*/*Defend* configuration (affects `AutoEquip` order of weapon vs armour, matters with two-handed weapons and shields); **F2** new game; **Space** rest; **Y** use the Amulet; **Enter/Escape** dismiss dialogs. A blocked move (wall, door without key) still consumes a step. **[CHECK]**

### Rest (Space)
Refused with a message if any (non-player) creature is on the map. Otherwise heals 1 wound, runs out the remaining steps of the current turn, and counts as one visit of the cell (wandering-monster check).

### Wandering monsters (`CellInfo.AddVisit`)
Called on entering a cell and on rest. `roll = Next(1,6)+Next(1,6)` (2..10); if `roll <= VisitCount - 1`, `VisitCount -= roll` and a creature drawn from the `spawn-weight` table appears on a random interior free tile and joins `SummonedCreatures`. Shops add 7 visits to every visited cell as a side effect of opening.

## 4. Moving and bumping (`PlayerMoveHandler.DoMove`)

Evaluated in this order (first match wins):

1. `EatIfNeeded()` first: while wounds > 0 and an item of healing type `Eaten` is carried, consume one (message `use-message`, wounds -= `healing-amount`).
2. Off the map edge: change maze cell (sections 1) and `AddVisit`.
3. Terrain bump handler denies: stay put.
4. Creature on the target tile: **melee**. `damage = RollAttack() - target.RollDefend()`. Hit if > 0: target wounds += damage, flags `BeenHit`, weapon durability reduced by damage (breakage section 6). Dead if `wounds >= health`: item drop from creature's `item-drops` onto its tile, kill message, XP unless the creature was *summoned*. Miss gives the `miss-message`. The player never moves into the tile.
5. Item on the target tile, by `item-type`:
   - **Door**: needs `item-unlocks` keys (any one of the listed key sets), consumes them, unlocks the maze portal in that direction, door item removed (the tile becomes passable). Otherwise `bump-message`, stay.
   - **Portal**: blocked by `item-blocks` item (e.g. Amulet); otherwise item consumed and `Teleport()`.
   - **Shop**: if any creature is on the map, refused. Otherwise open `ShopState`; `shop-behavior`: Vanish (shop item disappears), Teleport (respawn elsewhere), Persist (stays, player does not enter).
   - **Exit**: with the Amulet refuse; with all Quest items **and** `RainbowKey` => **Win**; with all quest items but no rainbow key / not all quest items: message. (Item names "Amulet", "RainbowKey" are hard-coded.)
   - **Chest**: item added to inventory, tile replaced by a `generated-item` roll. Stay.
   - anything else: `AddItem` (section 5) and the tile clears; the player moves onto it.
6. Otherwise the player moves.

Creatures (`CreatureMoveHandler`): cannot leave the map, cannot enter items, cannot enter the outer ring of tiles (rows/cols 0 and 14 [BUG?] row bound compares against `Columns`, harmless on square maps); attack the player when the target tile holds the player (`number-of-attacks` times, each `RollAttack() - player.RollDefend()`), see section 7. A creature with `special-attack == Generator` instead summons with probability 1/6 per move.

## 5. Picking things up (`PlayerDescriptor.AddItem`)

| item-type | effect |
|---|---|
| Treasure | gold += uniform in [`minimum-value`, `maximum-value`]; treasure items are *not* kept |
| Quest | `SpawnMonsters(1 / (questTotal - questHeld))` (more monsters as pieces collected), `QuestItems++`, message when complete |
| Armor / Weapon | stored; durability += `durability`; `AutoEquip()` |
| Light | stored; `durability[item] += duration`; best `light-level` is the lit light |
| Trap | if carried `Tools` >= `item-disarms` requirement: consume them, disarm message; else take `attack-value` damage with defend roll 0 and flag hit |
| Portal | teleport immediately |
| Healing / key / misc | stored; counted |

Traps of `Hidden` type become their real item when the player is adjacent (`RevealHiddens`, 4-neighbours, called after every move).

## 6. Equipment, durability, light

- `AutoEquip`: clear; in **Attack** config pick weapon first then armours, in **Defend** config armours first. Weapon: highest `attack-value`; a two-handed weapon is not picked if a shield is already worn; a shield is not worn with a two-handed weapon. Armour per slot (`armor-type`: Body, Feet, Helmet, Shield, Torso): the one with the larger *maximal defend roll*.
- **Weapon breakage**: each hit reduces `durability[weapon]` by damage dealt; when `ceil(durability / perItem) < count`, one copy breaks (message) and `AutoEquip` reruns.
- **Armour breakage** (on damage taken): damage points are spread over *worn items tagged Durable*, chosen at random, one point each.
- **Light**: each end-of-turn burns 1 durability of the best light; when `durability % duration == 0` the light goes out and is removed (message). `duration == 0` means never burns out. Light radius is a map-draw concern (client).
- **Attack roll** (`Creature.RollAttack`): `attack` dice each succeeding when `Next(6) < attack-die`; if `attack == 0` unarmed: 1 point with probability 1/6. Player `attack` = equipped weapon's `attack-value`.
- **Defend roll**: creature = a draw from its named generator (`white-die-N` etc.); player = sum of one draw per worn armour piece's generator.
- **Health**: player = `experience level + initial-health`; wounds clamp at 0.

## 7. Damage to the player

`damage = attack - defend`; on > 0 the creature's `special-attack` decides:

| special-attack | on a successful hit |
|---|---|
| Thief | 1/10 chance to steal a Quest item (respawned elsewhere) else steal `Next(100*damage)` gold (respawned as a gold pile) |
| Ghoul | drains XP by `damage` |
| Teleport | teleports the player (unless an `item-blocks` item is carried) |
| other (RedDragon etc.) | normal: wounds += damage, armour breakage |
| (none) | normal |

Death: when wounds >= health, a carried `Save` healing item is consumed (wounds -= amount) repeatedly; otherwise **Lose**. After the creature's attacks, if the player died, `killed-by-message`.

## 8. Progression and win

- XP from kills (`experience-points`) except summoned creatures. When `xp >= goal`: level up (message), `xp -= goal`, `goal = goal * multiplier / divisor` (integer), wounds reset to 0.
- Win: stand on the Exit with all Quest pieces ("MegaHam") **and** the Rainbow Key and without the Amulet.
- The Amulet: picking it blocks portals and exit; `Y` drops it on the floor and teleports the player away. Source: dropped only by the Necromancer. A boss reward with a trade-off (protects against portals and teleporting monsters, blocks the exit); keep.

## 9. Shops

`ShopState` rolls stock when opened: for each entry, `number-in-stock` independent trials, each in stock when `Next(number-in-stock-die) < number-in-stock-roll`. Buy one or buy all. **[BUG?, fixed in the port: D11]** `BuyOne`/`BuyAll` read the price with `GetProperty<uint>` but the XML value is an `int`; the cast throws and `GetProperty` swallows it, so the price is **0** and shopping is free (the dialog still shows and gates on the real price).

## 10. Messages and tutorial

`MessageQueue` keeps the last 5 messages with colours from the message's `text-color`; each message may carry `sound-effect`, `tutorial-tag`, `tutorial-*` fields that trigger a pop-up the first time (unless `always-tutorial`). Messages are keyed by id and translated by `MessageTable` (179 messages).

## 11. Known hazards in the original (see also `CLAUDE.md`)

- `SpawnMonsters` loops until it finds a **visited cell with a trap** and then a tile carrying an item tagged `spawns`; with no such cell it spins forever. Reachable when all traps are already used.
- `Maze.RespawnItem` and `Teleport` loop with no cap.
- `WeightedGenerator.MinimalValue` is wrong (starts at 0).
- Death while a `Save` item exists loops until wounds < health.
