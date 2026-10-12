# HamQuest of SPLORR!!

A turn-based maze crawl: eight by eight rooms, locks and keys, shops, traps, light that burns down, and a lot of things that want to eat you. Collect the pieces of the MegaHam, find the Rainbow Key, get out.

Play it in the browser: https://thegrumpygamedev.itch.io/hamquest-of-splorr

The original was written in C# between 2007 and 2011 (WinForms, then Silverlight, then an abandoned WPF port). This repository is the **Odin and WebAssembly** rebuild of it, with a native SDL2 client over the same code. The C# source is in git history under the tag `csharp-final`; its data (`data/`) is what the content generator reads.

```bash
tools/test.sh                 # stale checks, vet, tests, wasm build, native-versus-wasm parity
tools/build_web.sh            # build/web (serve with python3 -m http.server 8137 -d build/web)
~/ODIN/odin build odin/platform/native -vet -out:build/hamquest && build/hamquest
```

See `CLAUDE.md` for the layout and rules, `docs/PORT.md` for the decision log and `docs/TODO.md` for what a Steam release would need.

Art: David Gervais's Angband 32x32 tiles (CC BY 3.0) and the author's own doors and walls; font m5x7 by Daniel Linssen (CC0). See `assets/CREDITS.md`.
