#!/usr/bin/env bash
# Run every check. Must end with ALL TESTS PASSED.
set -euo pipefail
cd "$(dirname "$0")/.."
ODIN="${ODIN:-$HOME/ODIN/odin}"
echo "== content is up to date"
python3 tools/gen_content.py --check
echo "== odin check (vet) content, wasm and native"
"$ODIN" check odin/content -no-entry-point -vet
"$ODIN" check odin/content -no-entry-point -vet -target:js_wasm32
echo "== odin test"
"$ODIN" test odin/tests -define:ODIN_TEST_THREADS=1 -o:speed -out:build/tests.bin
echo "ALL TESTS PASSED"
