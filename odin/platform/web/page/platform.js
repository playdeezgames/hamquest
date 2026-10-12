"use strict";
// Page glue for HamQuest of SPLORR!! (see odin/platform/web/main.odin for the exports it calls).
// Query options: ?seed=N (up to 15 digits) fixes the world and turns saving off; ?log=1 logs every key;
// ?touch=1 shows the touch controls on any device;
// ?menu=1 opens the title menu even with a fixed seed; ?tutorial=1 starts the training level.

(function () {
	const W = 800, H = 600;
	const SAVE_KEY = "hq:save";             // itch.io games share one origin: keep the key namespaced
	const params = new URLSearchParams(location.search);
	const canvas = document.getElementById("screen");
	const msg = document.getElementById("msg");
	const ctx2d = canvas.getContext("2d", { alpha: false });
	const picture = document.createElement("canvas");   // the 800x600 frame as the game drew it
	picture.width = W; picture.height = H;
	const pctx = picture.getContext("2d", { alpha: false });
	const image = pctx.createImageData(W, H);
	const logKeys = params.get("log") === "1";
	const fixedSeed = params.get("seed") !== null;
	const touch = params.get("touch") === "1" || (window.matchMedia && window.matchMedia("(pointer: coarse)").matches);

	// ui.Key numbers (odin/ui/app.odin) in declaration order.
	const KEY = { Up: 1, Down: 2, Left: 3, Right: 4, Space: 5, Tab: 6, Enter: 7, Escape: 8, F2: 9, Y: 10, A: 11, S: 12, W: 13, D: 14, N: 15, T: 16, C: 17, H: 18 };

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
			case "c": case "C": return KEY.C;
			case "h": case "H": return KEY.H;
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

	// ---- fit to the window (the itch.io page launches full screen) ------------------------------------
	// The picture is enlarged by a whole number (nearest neighbour, crisp), at least as large as the screen
	// needs, and the browser then resizes that canvas smoothly to the exact best fit.
	const pad = document.getElementById("pad"), acts = document.getElementById("acts");
	let haveFrame = false;
	function layout() {
		const side = touch ? Math.max(90, Math.min(170, Math.floor(window.innerWidth * 0.16))) : 0;
		pad.classList.toggle("on", touch);
		acts.classList.toggle("on", touch);
		const availW = Math.max(1, window.innerWidth - 2 * side);
		const availH = Math.max(1, window.innerHeight);
		const fit = Math.min(availW / W, availH / H);
		const dpr = window.devicePixelRatio || 1;
		const k = Math.max(1, Math.min(8, Math.ceil(fit * dpr)));
		if (canvas.width !== W * k) {
			canvas.width = W * k;
			canvas.height = H * k;
		}
		canvas.style.width = Math.floor(W * fit) + "px";
		canvas.style.height = Math.floor(H * fit) + "px";
		if (haveFrame) present();
	}
	function present() {
		ctx2d.imageSmoothingEnabled = false;
		ctx2d.drawImage(picture, 0, 0, canvas.width, canvas.height);
	}
	window.addEventListener("resize", layout);
	document.addEventListener("fullscreenchange", layout);
	layout();

	function toggleFullscreen() {
		try {
			if (document.fullscreenElement) document.exitFullscreen();
			else document.documentElement.requestFullscreen();
		} catch (e) { /* not allowed here (for example an iframe without permission) */ }
	}

	// ---- saving -----------------------------------------------------------------------------------------
	function storageGet() { try { return window.localStorage.getItem(SAVE_KEY); } catch (e) { return null; } }
	function storageSet(v) { try { window.localStorage.setItem(SAVE_KEY, v); return true; } catch (e) { return false; } }

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
		let resumed = false;
		if (!fixedSeed) {
			const saved = storageGet();
			if (saved) {
				const bytes = new TextEncoder().encode(saved);
				if (bytes.length > 0 && bytes.length <= ex.platform_io_size()) {
					new Uint8Array(memory.memory.buffer, ex.platform_io_ptr(), bytes.length).set(bytes);
					const r = ex.platform_load(bytes.length);
					resumed = r === 0;
					if (logKeys) console.log("load result", r);
					// 2 or 3 (damaged, or from other rules): the stored text is left alone until the first new save
				}
			}
		}
		// a normal start opens at the title menu; a fixed ?seed= goes straight into that world
		if (params.get("tutorial") === "1") ex.platform_start_tutorial(lo, hi);
		else if (!fixedSeed || params.get("menu") === "1") ex.platform_open_title();
		msg.style.display = "none";
		canvas.focus();

		function press(code) {
			if (code) ex.platform_key(code);
		}
		window.addEventListener("keydown", function (e) {
			if (e.ctrlKey || e.metaKey || e.altKey) return;
			if (e.key === "f" || e.key === "F") { e.preventDefault(); toggleFullscreen(); return; }
			const code = keyOf(e);
			if (logKeys) console.log("key", e.key, e.code, "->", code);
			if (!code) return;
			e.preventDefault();
			press(code);
		});

		// pointer: tap on the picture
		canvas.addEventListener("pointerdown", function (e) {
			canvas.focus();
			const r = canvas.getBoundingClientRect();
			const x = Math.floor((e.clientX - r.left) * W / r.width);
			const y = Math.floor((e.clientY - r.top) * H / r.height);
			if (x >= 0 && y >= 0 && x < W && y < H) ex.platform_tap(x, y);
			e.preventDefault();
		});

		// touch buttons (held direction keys repeat)
		document.querySelectorAll(".touch button").forEach(function (b) {
			const code = KEY[b.dataset.key];
			let timer = null;
			const repeats = ["Up", "Down", "Left", "Right"].includes(b.dataset.key);
			function stop() { if (timer) { clearInterval(timer); timer = null; } }
			b.addEventListener("pointerdown", function (e) {
				e.preventDefault();
				press(code);
				if (repeats) { stop(); timer = setInterval(function () { press(code); }, 160); }
			});
			["pointerup", "pointercancel", "pointerleave"].forEach(function (n) { b.addEventListener(n, stop); });
		});

		// ---- save: after a change, at most once a second, and when the page is hidden
		let lastSave = 0;
		function flush() {
			if (fixedSeed || !ex.platform_save_dirty()) return;
			const n = ex.platform_save_encode();
			const bytes = new Uint8Array(memory.memory.buffer, ex.platform_io_ptr(), n);
			if (storageSet(new TextDecoder().decode(bytes))) {
				ex.platform_save_ack();
				lastSave = Date.now();
			}
		}
		document.addEventListener("visibilitychange", function () { if (document.hidden) flush(); });
		window.addEventListener("pagehide", flush);

		// debugging and the browser test harness
		window.hq = { press: press, ex: ex, seed: [lo, hi], resumed: resumed, flush: flush };

		function frame() {
			if (ex.platform_frame()) {
				const ptr = ex.platform_frame_ptr();
				image.data.set(new Uint8ClampedArray(memory.memory.buffer, ptr, W * H * 4));
				pctx.putImageData(image, 0, 0);
				haveFrame = true;
				present();
			}
			if (Date.now() - lastSave > 1000) flush();
			window.requestAnimationFrame(frame);
		}
		window.requestAnimationFrame(frame);
	}

	start().catch(function (e) {
		msg.textContent = "could not start: " + e;
		console.error(e);
	});
})();
