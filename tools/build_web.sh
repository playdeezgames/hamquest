#!/usr/bin/env bash
# Build the web release into build/web (wasm, odin.js, index.html, platform.js).
set -euo pipefail
cd "$(dirname "$0")/.."
ODIN="${ODIN:-$HOME/ODIN/odin}"
mkdir -p build/web
"$ODIN" build odin/platform/web -target:js_wasm32 -o:size -vet -out:build/web/hamquest.wasm
cp "$("$ODIN" root)/core/sys/wasm/js/odin.js" build/web/odin.js
cp odin/platform/web/page/index.html odin/platform/web/page/platform.js build/web/
ls -l build/web
