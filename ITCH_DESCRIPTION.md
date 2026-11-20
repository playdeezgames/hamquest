# itch.io page copy: HamQuest of SPLORR!!

Page: https://thegrumpygamedev.itch.io/hamquest-of-splorr (game id 5137469, edit page https://itch.io/game/edit/5137469). `TARGET` in `tools/ship.sh` matches (channel `html`; the manual is the `manual` channel, `tools/ship_manual.sh`). No jam. Pasted in by hand; nothing here is published by the repo.
Refreshed November 20, 2026 for the first proper release (Coxswain ship 28, November 21, 2026). Cover: `assets/cover.png` (630 by 500, `tools/make_cover.py`); screenshots `assets/screenshots/01-start` to `05-tip` (`tools/make_screenshots.py`).

## Notes (not for the page)

**What the live page has (read in the dashboard November 20, 2026):** **Published** (not a draft), Kind HTML, the October 12 builds (html upload #19690398 played in the browser; manual upload #19690937 as Documentation), embed "Click to launch in fullscreen", genre Survival, no tags, a cover and five screenshots, comments as a topic board, short description "A brutal little maze crawl", and the page text below **without** the Latest version line. AI disclosure Yes with **Graphics, Sounds, Text and Code all ticked**; the game has no sound and the art is David Gervais's and the author's, so Sounds and Graphics look wrong (unticking is the user's call). Not set: mobile friendly, any external link, tags.

Page settings on ship day: tick **mobile friendly** (on-screen pad and buttons; landscape fits best). External link "Latest version (GitHub Pages)" (type Other) to https://playdeezgames.github.io/hamquest/ (Pages set up locally November 20, 2026 at the user's go-ahead; live once pushed and enabled). Tags, if the user wants: roguelike, dungeon-crawler, turn-based, maze, pixel-art.

## Short description (at most 120 characters)

A brutal little maze crawl

(Already on the page; 26 characters.)

## Page text

**Latest version:** https://playdeezgames.github.io/hamquest/

*A brutal little maze crawl. Collect the sixteen pieces of the MegaHam, find the Rainbow Key, and get out alive. You will not get out alive.*

HamQuest is a turn-based dungeon crawl on an eight by eight maze of rooms and passages. Every dead end is locked, every key is lying in the open somewhere else, and almost everything between you and the exit would like to eat you. Yer character has five hit points, a dagger, some ham and a torch. Good luck.

This is a **rebuild**: the original was a C# game written between 2007 and 2011 (WinForms first, then Silverlight) that no browser can run any more. It has been brought back to life in Odin and WebAssembly, so it plays right here on the page.

## New here? Play the tutorial

Pick **Tutorial** on the title screen. It is a short training cellar of thirteen rooms that teaches the lot: moving, the minimap, yer pack, fighting, resting, keys and doors, shops, darkness, traps and the exit. It will not let you die in it, and it tells you so with some embarrassment. It does not touch yer saved game, and finishing it gives you nothing but knowing what you are doing.

## What you do

- Explore the maze. Rooms are dark; yer light source decides how far you can see, and it burns down.
- Collect the **16 pieces of the MegaHam**. They sit in dead ends behind locked doors.
- Find the **coloured keys** that open the coloured doors. Keys are never behind locks, so the maze can always be solved. It just does not feel like it.
- Fight what you meet by walking into it, or do not. Armour makes you tougher and *slower*. Boots make you quick.
- Spend yer gold in the four shops (one visit each).
- Kill the **Summoner** for the Rainbow Key, then walk out of the exit with all sixteen pieces.

Easy? The original was not, and neither is this one. Monsters get more numerous every time you pick up a piece of the MegaHam.

## Controls

| | Keyboard | Touch |
|---|---|---|
| Move / attack | Arrow keys or W A S D | Tap toward where you want to go, or use the pad |
| Rest (heals 1, only when nothing is around) | Space | Tap yourself, or **Rest** |
| Switch between attack and defend gear | Tab | Tap the sword or shield icon, or **Mode** |
| Invoke the Amulet (drops it and teleports you) | Y | **Amulet** |
| Menu (continue, new game, tutorial, credits) | Esc | **Esc** |
| New game | F2 | **New** |
| Credits | C | **Credits** |
| Full screen | F | |
| Close a pop-up | Enter / Esc | Tap |
| Tutorial: hide a lesson, or show it again | Enter, H | Tap the message box |
| In a shop: choose, buy one, buy all, leave | Up/Down, Enter, A, Esc | Tap a row (tap again to buy) or a button |

The game **saves by itself** in yer browser and picks up where you left off when you come back. Starting a new game (F2) replaces it. If you die, that is that.

## Tips

- Food heals one point of damage whenever you are hurt, and a potion will pull you back from death once. Do not go anywhere without them.
- Look at the minimap: red marks a room with monsters, green marks items.
- Opening a shop is noisy. Expect company.
- Picking up the Amulet of Yendor protects you from teleporting monsters, but you cannot leave the dungeon while you carry it.

## Credits

- Game and the doors and walls: **TheGrumpyGameDev**
- Tiles: **David Gervais**, Angband 32x32 tileset, [Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/)
- Font: **m5x7** by Daniel Linssen (managore), CC0
- The 2026 Odin and WebAssembly port was written by an AI agent (**Claude Code**, Anthropic) at the author's direction. The original game was written by hand.

There is no sound in this build.

*This page copy was posted by Claude, an AI agent, on behalf of The Grumpy GameDev.*
