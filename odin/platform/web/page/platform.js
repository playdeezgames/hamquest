"use strict";
// Page glue for HamQuest of SPLORR!! (see odin/platform/web/main.odin for the exports it calls).
// Query options: ?seed=N (up to 15 digits) fixes the world; ?log=1 logs every key to the console.
(function () {
	const W = 640, H = 560;
	const params = new URLSearchParams(location.search);
	const canvas = document.getElementById("screen");
	const msg = document.getElementById("msg");
	const ctx2d = canvas.getContext("2d", { alpha: false });
	const image = ctx2d.createImageData(W, H);
	const logKeys = params.get("log") === "1";

	// ui.Key numbers (odin/ui/app.odin) in declaration order.
	const KEY = { Up: 1, Down: 2, Left: 3, Right: 4, Space: 5, Tab: 6, Enter: 7, Escape: 8, F2: 9, Y: 10, A: 11, S: 12, W: 13, D: 14, N: 15, T: 16 };

	// Read the logical `e.key` first (remote desktops send odd `e.code` values), then fall back to `e.code`
	// for the numpad.
	function keyOf(e) {
		switch (e.key) {
			case "ArrowUp": return KEY.Up;
			case "ArrowDown": return KEY.Down;
			case "ArrowLeft": return KEY.Left;
			case "ArrowRight": return KEY.Right;
			case " ": case "Spacebar": return KEY.Space;
			case "Tab": return KEY.Tab;
			case "Enter": return KEY.Enter;
			case "Escape": return KEY.Escape;
			case "F2": return KEY.F2;
			case "y": case "Y": return KEY.Y;
			case "a": case "A": return KEY.A;
			case "s": case "S": return KEY.S;
			case "w": case "W": return KEY.W;
			case "d": case "D": return KEY.D;
			case "n": case "N": return KEY.N;
			case "t": case "T": return KEY.T;
		}
		switch (e.code) {
			case "Numpad8": return KEY.Up;
			case "Numpad2": return KEY.Down;
			case "Numpad4": return KEY.Left;
			case "Numpad6": return KEY.Right;
			case "Numpad5": return KEY.Space;
			case "NumpadEnter": return KEY.Enter;
		}
		return 0;
	}

	function seedFromPage() {
		const s = params.get("seed");
		if (s && /^\d{1,15}$/.test(s)) {
			const n = Number(s);
			return [n >>> 0, Math.floor(n / 4294967296) >>> 0];
		}
		const r = new Uint32Array(2);
		(window.crypto || window.msCrypto).getRandomValues(r);
		return [r[0], r[1] & 0xFFFFF];
	}

	// Scale the canvas by the largest whole number that fits (crisp pixels), or fractionally below 1x.
	function layout() {
		const s = Math.min(window.innerWidth / W, window.innerHeight / H);
		const k = s >= 1 ? Math.floor(s) : s;
		canvas.style.width = Math.floor(W * k) + "px";
		canvas.style.height = Math.floor(H * k) + "px";
	}
	window.addEventListener("resize", layout);
	layout();

	async function start() {
		const memory = new odin.WasmMemoryInterface();
		await odin.runWasm("hamquest.wasm", null, {}, memory);
		const ex = memory.exports;
		const [lo, hi] = seedFromPage();
		const err = ex.platform_init(lo, hi);
		if (err !== 0) {
			msg.textContent = "world generation failed (" + err + ")";
			return;
		}
		msg.style.display = "none";
		canvas.focus();

		function press(code) {
			if (code) ex.platform_key(code);
		}
		window.addEventListener("keydown", function (e) {
			if (e.ctrlKey || e.metaKey || e.altKey) return;
			const code = keyOf(e);
			if (logKeys) console.log("key", e.key, e.code, "->", code);
			if (!code) return;
			e.preventDefault();
			press(code);
		});
		canvas.addEventListener("pointerdown", function () { canvas.focus(); });

		// debugging and the browser test harness
		window.hq = { press: press, ex: ex, seed: [lo, hi] };

		function frame() {
			if (ex.platform_frame()) {
				const ptr = ex.platform_frame_ptr();
				image.data.set(new Uint8ClampedArray(memory.memory.buffer, ptr, W * H * 4));
				ctx2d.putImageData(image, 0, 0);
			}
			window.requestAnimationFrame(frame);
		}
		window.requestAnimationFrame(frame);
	}

	start().catch(function (e) {
		msg.textContent = "could not start: " + e;
		console.error(e);
	});
})();
