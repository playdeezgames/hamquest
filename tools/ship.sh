#!/usr/bin/env bash
# Test, build and zip the web release for itch.io. Uploads ONLY with --push.
#   tools/ship.sh           builds build/hamquest-html5.zip and prints "not pushed"
#   tools/ship.sh --push    also runs butler push (needs butler logged in and the itch page to exist)
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${ITCH_TARGET:-thegrumpygamedev/hamquest-of-splorr:html}"   # page: https://thegrumpygamedev.itch.io/hamquest-of-splorr
tools/test.sh
rm -f build/hamquest-html5.zip
(cd build/web && zip -q -9 -r ../hamquest-html5.zip index.html platform.js odin.js hamquest.wasm)
ls -l build/hamquest-html5.zip
if [ "${1:-}" = "--push" ]; then
	butler push build/web "$TARGET"
else
	echo "not pushed (use --push to upload to $TARGET)"
fi
