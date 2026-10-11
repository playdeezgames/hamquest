// Run the web build under node and print the frame hash after a scripted key sequence.
//   node tools/run_wasm_node.js <seed> <comma separated ui.Key numbers>
// The native client prints the same hash for the same input: `hamquest --seed N --keys ...`.
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const web = path.join(__dirname, "..", "build", "web");
const seed = Number(process.argv[2] || 1);
const keys = (process.argv[3] || "").split(",").filter(Boolean).map(Number);

// odin.js is a browser script that installs window.odin
globalThis.window = globalThis;
globalThis.requestAnimationFrame = function () {};
globalThis.fetch = async function (p) {
	const buf = fs.readFileSync(path.join(web, p));
	return { arrayBuffer: async () => buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength) };
};
vm.runInThisContext(fs.readFileSync(path.join(web, "odin.js"), "utf8"), { filename: "odin.js" });

(async function () {
	const memory = new odin.WasmMemoryInterface();
	await odin.runWasm("hamquest.wasm", null, {}, memory);
	const ex = memory.exports;
	const err = ex.platform_init(seed >>> 0, Math.floor(seed / 4294967296) >>> 0);
	if (err !== 0) { console.error("init failed", err); process.exit(1); }
	for (const k of keys) ex.platform_key(k);
	ex.platform_frame();
	const hex = (n) => (n >>> 0).toString(16).padStart(8, "0");
	console.log("hash " + hex(ex.platform_hash_hi()) + hex(ex.platform_hash_lo()));
})().catch((e) => { console.error(e); process.exit(1); });
