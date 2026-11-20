#!/usr/bin/env bash
# Test, build and zip the web release for itch.io. Uploads ONLY with --push. Never commits, never deletes anything.
#   tools/ship.sh           builds build/hamquest-html5.zip and prints "not pushed"
#   tools/ship.sh --push    also runs butler push (needs butler logged in and the itch page to exist)
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${ITCH_TARGET:-thegrumpygamedev/hamquest-of-splorr:html}"   # page: https://thegrumpygamedev.itch.io/hamquest-of-splorr
tools/test.sh
rm -f build/hamquest-html5.zip
(cd build/web && zip -q -9 -r ../hamquest-html5.zip index.html platform.js lootlocker.js odin.js hamquest.wasm)
ls -l build/hamquest-html5.zip
unzip -l build/hamquest-html5.zip | tail -4
if [ "${1:-}" = "--push" ]; then
	if [ -n "$(git status --porcelain)" ]; then echo "note: the working tree has uncommitted changes; what is pushed is the working tree, not a commit"; fi
	butler push build/web "$TARGET"
	echo "pushed to $TARGET. It goes live after itch.io processes it; check: butler status $TARGET"
else
	echo "not pushed (use --push to upload to $TARGET)"
fi
