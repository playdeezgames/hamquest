# HamQuest of SPLORR!!

*A brutal little maze crawl. Collect the sixteen pieces of the MegaHam, find the Rainbow Key, and get out alive. You will not get out alive.*

HamQuest is a turn-based dungeon crawl on an eight by eight maze of rooms and passages. Every dead end is locked, every key is lying in the open somewhere else, and almost everything between you and the exit would like to eat you. Your character has five hit points, a dagger, some ham and a torch. Good luck.

This is a **rebuild**: the original was a C# game written between 2007 and 2011 (WinForms first, then Silverlight) that no browser can run any more. It has been brought back to life in Odin and WebAssembly, so it plays right here on the page.

## What you do

- Explore the maze. Rooms are dark; your light source decides how far you can see, and it burns down.
- Collect the **16 pieces of the MegaHam**. They sit in dead ends behind locked doors.
- Find the **coloured keys** that open the coloured doors. Keys are never behind locks, so the maze can always be solved. It just does not feel like it.
- Fight what you meet by walking into it, or do not. Armour makes you tougher and *slower*. Boots make you quick.
- Spend your gold in the four shops (one visit each).
- Kill the **Summoner** for the Rainbow Key, then walk out of the exit with all sixteen pieces.

Easy? The original was not, and neither is this one. Monsters get more numerous every time you pick up a piece of the MegaHam.

## Controls

| | Keyboard | Touch |
|---|---|---|
| Move / attack | Arrow keys or W A S D | Tap toward where you want to go, or use the pad |
| Rest (heals 1, only when nothing is around) | Space | Tap yourself, or **Rest** |
| Switch between attack and defend gear | Tab | Tap the sword or shield icon, or **Mode** |
| Invoke the Amulet (drops it and teleports you) | Y | **Amulet** |
| New game | F2 | **New** |
| Credits | C | **Credits** |
| Full screen | F | |
| Close a pop-up | Enter / Esc | Tap |
| In a shop: choose, buy one, buy all, leave | Up/Down, Enter, A, Esc | Tap a row (tap again to buy) or a button |

The game **saves by itself** in your browser and picks up where you left off when you come back. Starting a new game (F2) replaces it. If you die, that is that.

## Tips

- Food heals one point of damage whenever you are hurt, and a potion will pull you back from death once. Do not go anywhere without them.
- Look at the minimap: red marks a room with monsters, green marks items.
- Opening a shop is noisy. Expect company.
- Picking up the Amulet of Yendor protects you from teleporting monsters, but you cannot leave the dungeon while you carry it.

## Credits

- Game and the doors and walls: **TheGrumpyGameDev**
- Tiles: **David Gervais**, Angband 32x32 tileset, [Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/)
- Font: **m5x7** by Daniel Linssen (managore), CC0
- The 2026 Odin and WebAssembly port was written with **Claude Code** (Anthropic). The original game was written by hand.

There is no sound in this build.
