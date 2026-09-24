#!/usr/bin/env node
/**
 * What if tab timing check (not a gate: it prints times, it does not fail).
 *
 * Times the live tab the way a reader uses it: the first render, a re-render,
 * scenario picks, a filter change and filtering back to everyone.
 *
 * Run on the synthetic fixture:
 *   node modules/tabs/lib/html_report_v2/tests/whatif_timing.mjs
 * Run on a real study: pass an island already cut to open mode by the tabs
 * reader (.read_whatif_contribution(..., "records", survey_data) written to a
 * scratch file, never into a project folder or git):
 *   node modules/tabs/lib/html_report_v2/tests/whatif_timing.mjs <open_island.json>
 *
 * SACAP 2025 (1,361 students, 101 fits, 8 levers), 24 Sep 2026, node, weighted:
 *   before: first render 1,210 ms, filter change 630 ms, back to everyone
 *           1,260 ms, every other render 450 to 510 ms
 *   after:  first render 315 ms, filter change 145 ms, back to everyone 1 ms,
 *           re-render 1 ms,
 *           a new scenario pick about 12 ms
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS = path.join(HERE, "..", "assets", "js", "27w_whatif.js");
const FIXTURE = path.join(HERE, "..", "..", "..", "tests", "fixtures", "whatif", "synthetic_whatif_island.json");

function fixtureOpen() {
  const w = JSON.parse(readFileSync(FIXTURE, "utf8")).variants.weighted;
  w.meta.mode = "open";
  delete w.safe;
  return w;
}
const W = process.argv[2] ? JSON.parse(readFileSync(process.argv[2], "utf8")) : fixtureOpen();
if (!W.open) { console.log("This island has no open rows; the live tab is not used."); process.exit(0); }
const n = W.open.n;

const sb = { console, Math, JSON };
sb.globalThis = sb;
sb.window = sb;
sb.TR = { fmt: { escapeHtml: (s) => String(s == null ? "" : s) } };
sb.TR.d2 = { state: { filters: [] }, filterDescription: () => "the group",
             tracking: () => ({ enabled: false }), qualitative: () => ({ enabled: false }) };
// A stand-in filter: every other respondent.
const half = Array.from({ length: n }, (_, i) => i % 2 === 0);
sb.TR.stats = { source: () => "micro", mask: (f) => (f.length ? half : null) };
vm.createContext(sb);
vm.runInContext(readFileSync(JS, "utf8"), sb, { filename: "27w_whatif.js" });
sb.TR.WI = W;

const host = { innerHTML: "", querySelectorAll: () => [] };
const time = (label, fn) => {
  const t = process.hrtime.bigint();
  fn();
  console.log(label.padEnd(32), (Number(process.hrtime.bigint() - t) / 1e6).toFixed(0).padStart(6), "ms");
};
const L = W.model.levers;
console.log("What if timing: " + n + " rows, " + W.model.fits.length + " fits, " + L.length + " levers");
time("first render", () => sb.TR.whatif.render(host));
time("render again, nothing changed", () => sb.TR.whatif.render(host));
sb.TR.whatif.state.scen[L[0].key] = L[0].kind === "coverage" ? "extend" : "up1";
time("a scenario pick", () => sb.TR.whatif.render(host));
if (L.length > 1) {
  sb.TR.whatif.state.scen[L[1].key] = L[1].kind === "coverage" ? "extend" : "floor";
  time("a second pick", () => sb.TR.whatif.render(host));
}
sb.TR.d2.state.filters = [{ q: "timing", rows: [0] }];
time("a filter change", () => sb.TR.whatif.render(host));
time("render again on that filter", () => sb.TR.whatif.render(host));
sb.TR.d2.state.filters = [];
time("back to everyone", () => sb.TR.whatif.render(host));
