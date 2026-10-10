package game

import content "../content"

// xoshiro256** seeded by splitmix64 (A5): the same seed gives the same world on every target.
Rng :: struct {
	s: [4]u64,
}

splitmix64 :: proc(state: ^u64) -> u64 {
	state^ += 0x9E3779B97F4A7C15
	z := state^
	z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ~ (z >> 27)) * 0x94D049BB133111EB
	return z ~ (z >> 31)
}

rng_seed :: proc(r: ^Rng, seed: u64) {
	st := seed
	for i in 0 ..< 4 {
		r.s[i] = splitmix64(&st)
	}
}

rotl64 :: #force_inline proc(x: u64, k: u64) -> u64 {
	return (x << k) | (x >> (64 - k))
}

rng_u64 :: proc(r: ^Rng) -> u64 {
	result := rotl64(r.s[1] * 5, 7) * 9
	t := r.s[1] << 17
	r.s[2] ~= r.s[0]
	r.s[3] ~= r.s[1]
	r.s[1] ~= r.s[2]
	r.s[0] ~= r.s[3]
	r.s[2] ~= t
	r.s[3] = rotl64(r.s[3], 45)
	return result
}

// Uniform in [0, n) without modulo bias. n == 0 returns 0.
rng_below :: proc(r: ^Rng, n: u64) -> u64 {
	if n == 0 {return 0}
	threshold := (0 - n) % n
	for {
		x := rng_u64(r)
		if x >= threshold {return x % n}
	}
}

// Uniform integer in [0, n).
rng_int :: proc(r: ^Rng, n: int) -> int {
	if n <= 0 {return 0}
	return int(rng_below(r, u64(n)))
}

// Uniform integer in [lo, hi] (inclusive).
rng_range :: proc(r: ^Rng, lo, hi: int) -> int {
	return lo + rng_int(r, hi - lo + 1)
}

weight_total :: proc(rg: content.Range) -> u64 {
	total: u64
	for i in rg.start ..< rg.start + rg.count {
		total += u64(content.WEIGHT_POOL[i].weight)
	}
	return total
}

// Pick a value from a weighted list in content.WEIGHT_POOL. An empty or zero-weight list yields 0.
pick_weighted :: proc(r: ^Rng, rg: content.Range) -> i32 {
	total := weight_total(rg)
	if total == 0 {return 0}
	roll := rng_below(r, total)
	for i in rg.start ..< rg.start + rg.count {
		e := content.WEIGHT_POOL[i]
		if roll < u64(e.weight) {return e.value}
		roll -= u64(e.weight)
	}
	return 0
}
