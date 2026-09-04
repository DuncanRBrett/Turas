#!/usr/bin/env node
/**
 * ISLAND ENCODING. The two halves must agree, byte for byte.
 *
 * A client deliverable encodes each marked data island: UTF-8 bytes XORed
 * against a keystream from a linear congruential generator seeded per build,
 * then base64. R writes it in .minify_encode_island() and the browser undoes it
 * in decodeIsland() (24_shell.js). Two implementations of one format is exactly
 * the arrangement that drifts, and the failure is silent: an island that will
 * not decode becomes null, and TR.AGG null is a blank report.
 *
 * So the fixture is written by R and read here. Regenerate it only when the
 * format deliberately changes:
 *   Rscript -e 'source("modules/shared/lib/turas_minify.R"); ...'
 *   (the generator is documented in the build note)
 *
 * Cases: ASCII, UTF-8 with an em dash and an emoji and an accent, a body
 * carrying an escaped </script and <!--, a nested structure, and a long one.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/island_encoding_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const FIXTURE = path.join(HERE, "fixtures", "island_encoding.json");

const sandbox = { console, atob, TextDecoder };
sandbox.globalThis = sandbox;
sandbox.TR = { fmt: { escapeHtml: (s) => String(s == null ? "" : s) } };
vm.createContext(sandbox);
vm.runInContext(readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8"), sandbox,
  { filename: "24_shell.js" });
const TR = sandbox.TR;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) {
  if (a !== b) throw new Error(msg + ":\n      expected " + JSON.stringify(b) +
    "\n      got      " + JSON.stringify(a));
}

const fx = JSON.parse(readFileSync(FIXTURE, "utf8"));

run("the shell exposes the decoder", () => {
  assert(typeof TR.shell._decodeIsland === "function",
    "TR.shell._decodeIsland is not a function");
});

for (const c of fx.cases) {
  run("R-encoded " + c.name + " decodes to the same text", () => {
    eq(TR.shell._decodeIsland(c.encoded, String(fx.seed)), c.plain,
      c.name + " round trip");
  });
  run("R-encoded " + c.name + " then parses as the same JSON", () => {
    const got = JSON.parse(TR.shell._decodeIsland(c.encoded, String(fx.seed)));
    eq(JSON.stringify(got), JSON.stringify(JSON.parse(c.plain)), c.name + " JSON");
  });
  run("R-encoded " + c.name + " is not readable JSON before decoding", () => {
    let parsed = true;
    try { JSON.parse(c.encoded); } catch (e) { parsed = false; }
    assert(!parsed, c.name + " encoded body still parses as JSON");
  });
}

run("a plain island passes through untouched", () => {
  const plain = '{"n":600}';
  eq(TR.shell._decodeIsland(plain, null), plain, "null seed");
  eq(TR.shell._decodeIsland(plain, ""), plain, "empty seed");
});

run("the wrong seed does not silently return the right text", () => {
  const c = fx.cases[0];
  const wrong = TR.shell._decodeIsland(c.encoded, String(fx.seed + 1));
  assert(wrong !== c.plain, "a wrong seed decoded to the right text");
});

console.log((failed ? "\n✗ " : "\n✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
