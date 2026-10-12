# TODO: what stands between HamQuest of SPLORR!! and a Steam release

Written October 11, 2026 from the repo as it stands (itch.io build #2105958) and the vault's
[Steam pivot evaluation](../../bok-of-splorr/splorr/Strategy/Steam%20pivot%20evaluation.md), where this game scores **8, rank 5**.
Its assessment in one line: the best-engineered of the small games and the easiest to extend with content,
but short on variety and meta progression, with no sound and a brutal cold start.

Sizes: **S** under a day, **M** a few days, **L** a week or more. Items marked **[user]** need a decision or an
asset from the user. Nothing here is started. Rules that are already decided (D1 to D17 in `docs/PORT.md`)
stay decided unless an item below says it should be reopened.

## A. Blockers: Steam will not take it, or the page cannot be built, without these

1. **Sound** (L, [user]). Today there is none, and the three original samples (`carrotnom`, `KeyPickup`, `Lock_open`)
   have no recorded author or licence, so they cannot ship.
   - Find the real source of the three, or drop them. Replace with licence-clean effects (CC0 or bought), kept in
     `assets/CREDITS.md` with their licences.
   - Effects needed: step/bump, hit, miss, hurt, death, pick-up per item class, door unlock, key, shop, level up,
     trap, teleport, light going out, win. The engine already emits `Sound` events and messages carry a `sound`
     field (only 12 messages use it); extend the data and add a hand-written sound table.
   - Platform side: Web Audio in the page (unlock on first key), SDL2_mixer in the native client, a master/effects
     volume and mute in a settings screen.
   - Music: optional but a paid game with none feels unfinished; budget a few looping tracks (CC0 or commissioned)
     and say how they were made (the AI disclosure rules cover music too; see the vault's Steam notes).
2. **Native builds for the platforms Steam players use** (M, [user]). The SDL2 client runs on this Linux machine; a
   Windows build cannot be cross-built by Odin from here (see the vault's Bootstrapper plan).
   - Needs a Windows machine or CI runner, SDL2 and SDL2_mixer DLLs packaged, a Linux build in the Steam Linux
     depot, and (if wanted) macOS.
   - Add a release build script (`tools/package_native.sh` and a Windows twin) with version stamps and a smoke test.
3. **Steamworks integration** (M). `odin-steamworks` (jakubtomsu) exists for SDK 1.60 but is only documented for
   Windows and tested on one 2024 Odin build; our toolchain is `dev-2026-07`.
   - Initialise, run in the Steam client, overlay-friendly main loop, Steam app id handling (`steam_appid.txt` for dev).
   - Achievements and stats (see item 8), cloud saves (see item 14), rich presence optional.
   - Verify it builds and runs before committing to this path; have a fallback of "no SDK calls, achievements off".
4. **Controller support** (M). There is none on the web or native build.
   - Gamepad mapping (standard layout): move, rest, attack/defend mode, amulet, menu, shop navigation, confirm/back.
   - Steam Input: action sets and glyphs, and the "controller support" flag requirements (not read yet; see the
     vault's "Things to verify", item 8).
   - On screen: button hints that follow the device in use.
5. **A menu and settings shell** (M). **Title menu done (D21)**; pause, options and settings remain. The game boots straight into a run and has no title, options, pause or quit.
   - Title screen (new game, continue, options, credits, quit), pause menu, an options screen: volume, mute, window
     mode, UI scale, tips on/off, key bindings, colourblind markers, reset.
   - Native quit handling, window state persistence, and a consistent "abandon run" confirmation.
6. **Store page assets and admin** (M, [user]). Capsule art in all required sizes (header, small, main, vertical,
   library hero, logo), a trailer, 5 or more screenshots, a short and long description, tags, age rating
   questionnaire, system requirements, price, and the AI-use disclosure in Valve's survey.
   - The itch.io cover, screenshots and description in the repo are drafts for itch, not Steam.
   - Verify Valve's current fee, review time, "coming soon" period and wishlist advice (vault items 1 and 2).
7. **Name and hook** (S, [user]). Check that "HamQuest" and "MegaHam" are clear on Steam and in trademark search.
   Write one sentence that sells it on a capsule: the current page reads "locks, keys, ham and monsters".

## B. Game depth: what makes a player stay past the first hour

8. **Meta progression and a reason to retry** (L). A run is short and ends in a blank slate.
   - Persistent profile: runs, best level, kills, quest pieces, wins, time played (local file plus Steam stats).
   - Unlocks between runs (starting kit options, a new class or two, new shops/items entering the pool), a hall of
     fame, and a "legacy" token from a death.
   - Achievements (20 or so, about half hidden): first key, first shop, level 5, kill each boss, win, win with no
     armour, win in X turns, etc.
9. **Difficulty, onboarding and the cold start** (M, [user]). The user confirmed the original is this brutal
   (D14, D15). On Steam that is a refund risk even though the game can be won.
   - Keep the original as **Classic**. Add an easier mode and a hard mode (more starting health, fewer wandering
     monsters, fewer starting monsters near the start, shop-visit ageing off).
   - A short guided first run or tutorial room so the first three minutes teach: move, doors and keys, fight,
     eat, rest, amulet.
   - Reopen D15 with data: use the bot to measure early deaths and a human playtest before choosing numbers.
10. **More content** (L). About 15 creatures and 80 items, one room set and an 8 by 8 maze.
    - New creatures with distinct behaviours (ranged, fast, summoners, pack, thief variants), more bosses, bosses
      with phases, new traps and hazards, new consumables and equipment, set pieces.
    - New room layouts (more `.cqm` layers: cross-rooms, pillars, vaults, secret rooms), themed areas.
    - The pipeline is built for this: data in XML, a strict generator, a flat engine; most of it is data work plus a
      handful of special attacks in `game/turn.odin`.
11. **Run structure and variety** (L). Add what makes two runs differ:
    - Multiple floors (descend after the exit, or a seeded series of mazes of growing size; maze size is already a
      single constant), modifiers, shrines/events, a daily seed with a shared leaderboard (Steam).
    - Seed shown and enterable in the menu; copy a seed to share.
12. **A balance pass with measurement** (M). Nothing has been tuned (D7) except one price.
    - Build a bot that can actually win to measure win rate, not only survival; track deaths by cause, XP curve,
      gold income versus shop prices (D11 made prices real), light consumption, armour speed trade-offs, boss rewards.
    - Review the carried-over quirks flagged "kept": a shop opening ages every visited cell by seven visits
      (spawns wandering monsters), single-use shops, creature action rate against player speed.
13. **A bestiary, item descriptions and an in-game help** (M). D13 deferred a help screen. Add inspect/hover text
    for items and creatures, a controls page, and a codex that fills in as things are met.

## C. Platform and quality

14. **Saves that survive updates** (M). A replay save only fits the rules that made it (the content hash and
    `RULES_VERSION` refuse anything else). That is fine for a jam game and wrong for a paid one that gets patches.
    - Decide the policy: freeze rules per major version and keep old rules versions replayable, or switch to a
      binary snapshot of the `World` (about 70 KB, versioned, validated) and keep the replay log for verification.
    - Multiple save slots, a Continue button, Steam Cloud sync of the (small) save, and corruption handling.
15. **Accessibility** (S to M). The six lock colours are only distinguishable by hue (add shapes or letters),
    text size and UI scale options, high-contrast option, a reduced-flash option, full keyboard and controller
    navigation, rebindable keys.
16. **Performance and robustness** (S). Measure frame time in wasm and native on a low-end machine. The light
    pass does a square root per pixel of the map pane and could be a lookup. Soak the game for memory and the
    save log cap (200,000 commands). Fuzz the save decoder in CI.
17. **Display** (S). Native window and fullscreen toggle, resolution list, vsync, DPI scaling, borderless
    fullscreen, alt-tab handling. (The web build already fits the window.)
18. **Localisation** (M, optional). Text is English only and lives in generated tables and a few UI strings; a
    string table and a font with more glyphs would be needed. Defer unless the store wants it.

22. **Rethink the screen layout** (M, [user], noted 2026-10-12). The 640 by 560 picture is far too tight:
    the 480 by 480 map, the 160-pixel panel (minimap, pack, statistics) and the 80-pixel message strip
    are packed edge to edge with no borders, no breathing room, and nowhere to put the tutorial coach, the
    shop or a larger font without covering something.
    - Give every area a border and some padding; decide what each area is for before moving anything.
    - Reconsider the logical size (a wider frame would give the panel and a message/coach area real room;
      the web build already fits any window, D17) and whether the 32 by 32 map stays at 15 by 15 tiles.
    - Touch buttons and tap targets, the coach strip (tutorial T2), shop and tip dialogs, accessibility text
      size (item 15) and the future options screen all depend on this, so settle it before more UI is built.

## D. Legal and release hygiene

19. **Third-party credits and licences** (S, [user]). In-game credits already name David Gervais (CC BY 3.0),
    m5x7 (CC0) and the AI disclosure. Still to do: a `THIRD_PARTY_LICENSES` file in the build, the SDL2/SDL2_mixer
    (zlib) notices, a per-tile provenance list (which tiles are Gervais's and which are the user's) so a claim can be
    answered, and the licence for any new sound or music.
20. **Valve's rules on external links** (S). The user's stance is "no links to anything but the Steam page". The
    credits screen shows the Creative Commons URL as plain text because CC BY asks for it; check that this is
    allowed, or satisfy the licence another way (link in the store description).
21. **Release checks** (S). Clean-machine install test, antivirus false-positive check on the Windows build,
    store build channels (beta branch for patches), crash handling and a log file, version number in the title.

## Suggested order

1. Decide the scope question: **Steam release of this game, or use it as the content-driven second roguelike
   while a different game is the first Steam project** (the vault's recommendation is Kordanor's Cabal first).
2. Prove the platform risk early: items 2 and 3 (a Windows build that runs under Steam with one achievement).
3. Fix the experience: items 5, 9, 13, then 1 (sound), then 4 (controller).
4. Add the game: items 8, 10, 11, 12 in that order, with a playtest after each.
5. Ship the page: items 6, 7, 14, 15, 19 to 21.

Quick wins that are independent of everything else: 16 (measure), 15 (lock colour shapes), 19 (provenance list),
13 (help page), and the bot that can win (part of 12).
