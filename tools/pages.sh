#!/usr/bin/env bash
# Builds the shipping web build and copies it to docs/ for GitHub Pages (served from master, /docs):
# https://playdeezgames.github.io/hamquest/
# docs/ is generated and wiped on each run; the port's notes live in design/. Never commits or pushes.
set -euo pipefail
cd "$(dirname "$0")/.."
tools/build_web.sh > /dev/null
rm -rf docs
mkdir docs
cp -r build/web/. docs/
touch docs/.nojekyll
echo "docs/ ready: $(du -sh docs | cut -f1)"
