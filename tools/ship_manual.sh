#!/usr/bin/env bash
# Rebuild the player's manual and upload it to its own itch.io channel. Uploads ONLY with --push.
#   tools/ship_manual.sh          rebuilds manual/HamQuest-of-SPLORR-Manual.pdf, prints "not pushed"
#   tools/ship_manual.sh --push   also runs butler push (channel `manual`, a plain download on the page)
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${ITCH_MANUAL_TARGET:-thegrumpygamedev/hamquest-of-splorr:manual}"
python3 tools/make_manual.py
ls -l manual/HamQuest-of-SPLORR-Manual.pdf
if [ "${1:-}" = "--push" ]; then
	butler push manual/HamQuest-of-SPLORR-Manual.pdf "$TARGET"
else
	echo "not pushed (use --push to upload to $TARGET)"
fi
