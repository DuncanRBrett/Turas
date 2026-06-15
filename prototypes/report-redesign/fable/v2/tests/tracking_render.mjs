#!/usr/bin/env node
/**
 * Standalone gate for the Tracking Summary render across significance modes —
 * specifically the "Nearly significant (80%)" cards that let you inspect which
 * metrics the pulse's "≈ N nearly significant" count refers to. Renders the
 * SACAP tracking summary through a DOM stub and asserts:
 *   - "95":  no soft section, no soft cards, no 80% badge
 *   - "off": no soft section, and no strong significant-change cards either
 *   - "dual": the soft section appears, soft cards > 0, every soft card carries
 *             exactly one 80% badge, and the badge count matches the card count
 * Exits non-zero on any failure. Spawned by run_tests_v2.mjs.
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const BASE = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const V1 = path.join(path.dirname(BASE), "src", "js");
const V2 = path.join(BASE, "src", "js");

function makeEl() {
  return { _html: "", set innerHTML(v) { this._html = v; }, get innerHTML() { return this._html; },
    addEventListener() {}, appendChild() {}, replaceChildren() {},
    querySelector() { return null; }, querySelectorAll() { return []; } };
}
const documentStub = { createElement() { return makeEl(); }, getElementById() { return makeEl(); }, addEventListener() {} };

const sandbox = { console, TextEncoder, URL, document: documentStub };
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js", "14_pptx_parts.js"]) {
  vm.runInContext(readFileSync(path.join(V1, f), "utf8"), sandbox, { filename: f });
}
for (const f of readdirSync(V2).filter((x) => x.endsWith(".js")).sort()) {
  vm.runInContext(readFileSync(path.join(V2, f), "utf8"), sandbox, { filename: f });
}
const TR = sandbox.TR;
TR.AGG = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_2025.json"), "utf8"));
TR.MICRO = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_microdata.json"), "utf8"));
TR.PREV = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_waves.json"), "utf8"));
TR.VERIFY = {};
TR.userState = null;
TR.d2.state = TR.d2.state || {};
TR.d2.state.banner = TR.AGG.banner_groups.length ? TR.AGG.banner_groups[0].id : "";
TR.render.currentYear = TR.render.currentYear || function () { return 2025; };

function render(mode) {
  TR.d2.state.sigMode = mode;
  const host = makeEl();
  TR.trkSummary.render(host);
  return host._html;
}
const count = (h, re) => (h.match(re) || []).length;

let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log("  ✓ " + m); } else { fail++; console.log("  ✗ " + m); } };

// ---- 95%: strong only, no soft anything ----
const h95 = render("95");
ok(!h95.includes("Nearly significant"), "95%: no 'Nearly significant' section");
ok(count(h95, /class="sigcard [^"]*soft"/g) === 0, "95%: no soft cards");
ok(count(h95, /sig-badge/g) === 0, "95%: no 80% badge");

// ---- off: nothing flagged at all (strong suppressed too) ----
const hOff = render("off");
ok(!hOff.includes("Nearly significant"), "off: no 'Nearly significant' section");
// match actual cards (class="sigcard up/down…"), not the "sigcards" grid container
ok(count(hOff, /class="sigcard /g) === 0, "off: no significant-change cards at all");

// ---- dual: the soft cards appear and are inspectable ----
const hDual = render("dual");
const softCards = count(hDual, /class="sigcard [^"]*soft"/g);
const badges = count(hDual, /sig-badge/g);
ok(hDual.includes("Nearly significant"), "dual: 'Nearly significant' section present");
ok(softCards > 0, "dual: soft cards rendered (" + softCards + ")");
ok(badges === softCards, "dual: one 80% badge per soft card (" + badges + " === " + softCards + ")");
ok(hDual.includes("nearly significant (80%)"), "dual: pulse carries the 'nearly significant' tally");

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
