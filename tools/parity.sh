#!/usr/bin/env bash
# The native client and the wasm build must draw identical frames for the same seed and keys.
# Needs build/hamquest (native) and build/web (tools/build_web.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
for seed in 1 7 42 31337; do
	keys=$(python3 - "$seed" <<'PY'
import random, sys
random.seed(int(sys.argv[1]))
# moves, rest, tab, enter, y, wasd, a, s, d (number = ui.Key; see odin/ui/app.odin)
pool = [1,2,3,4]*4 + [5,6,7,10,13,11,12,14,16,17]
print(','.join(str(random.choice(pool)) for _ in range(600)))
PY
)
	native=$(SDL_VIDEODRIVER=dummy timeout 60 build/hamquest --seed "$seed" --keys "$keys" | grep '^hash')
	web=$(node tools/run_wasm_node.js "$seed" "$keys" | grep '^hash')
	if [ "$native" = "$web" ]; then
		echo "seed $seed: $native  (same)"
	else
		echo "seed $seed: MISMATCH native [$native] web [$web]"
		fail=1
	fi
done
exit $fail
