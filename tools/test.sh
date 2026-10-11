#!/usr/bin/env bash
# Run every check. Must end with ALL TESTS PASSED.
set -euo pipefail
cd "$(dirname "$0")/.."
ODIN="${ODIN:-$HOME/ODIN/odin}"
echo "== content is up to date"
python3 tools/gen_content.py --check
echo "== atlas and font are up to date"
python3 tools/pack_atlas.py --check
python3 tools/gen_font.py --check
echo "== odin check (vet) content, wasm and native"
"$ODIN" check odin/content -no-entry-point -vet
"$ODIN" check odin/content -no-entry-point -vet -target:js_wasm32
"$ODIN" check odin/game -no-entry-point -vet
"$ODIN" check odin/game -no-entry-point -vet -target:js_wasm32
"$ODIN" check odin/ui -no-entry-point -vet
"$ODIN" check odin/ui -no-entry-point -vet -target:js_wasm32
echo "== odin test"
"$ODIN" test odin/tests -define:ODIN_TEST_THREADS=1 -o:speed -out:build/tests.bin
echo "== native client builds and runs a few frames headless"
mkdir -p build
"$ODIN" build odin/platform/native -vet -out:build/hamquest
SDL_VIDEODRIVER=dummy build/hamquest --seed 1 --frames 3 > /dev/null
echo "== web build and wasm-versus-native parity"
tools/build_web.sh > /dev/null
tools/parity.sh
echo "ALL TESTS PASSED"
