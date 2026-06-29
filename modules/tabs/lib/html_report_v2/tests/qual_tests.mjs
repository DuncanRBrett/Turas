// Qualitative tab — pure-helper known-answer suite (node, no DOM).
// Loads 27q_qualitative.js with a TR.fmt stub and checks the prevalence,
// tier-filter and theme-record helpers against hand-computable answers.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const jsDir = path.join(here, "..", "assets", "js");

globalThis.TR = { fmt: { escapeHtml: (s) => String(s == null ? "" : s) } };
new Function(fs.readFileSync(path.join(jsDir, "27q_qualitative.js"), "utf8"))();
const qual = globalThis.TR.qual;

let passed = 0, failed = 0;
function assert(cond, msg) {
  if (cond) { passed++; console.log("  ✓ " + msg); }
  else { failed++; console.log("  ✗ " + msg); }
}

// Themed question: Price mentioned by 2 of 4 commenters (1 pos, 1 neg); Service by 1
// (neutral); one commenter coded no theme. Tiers: must-read(2), noteworthy(1), other(0).
const q = {
  code: "Q1", title: "Why?", type: "themed",
  themes: [{ id: 0, label: "Price" }, { id: 1, label: "Service" }],
  records: [
    { idx: 0, tier: 1, sentiment: 1, themeVals: { "0": 1 } },
    { idx: 1, tier: 0, sentiment: 3, themeVals: { "0": 3 } },
    { idx: 2, tier: 2, sentiment: 2, themeVals: { "1": 2 } },
    { idx: 3, tier: 0, themeVals: {} }
  ]
};

console.log("Qualitative tab — pure helpers:");

const prev = qual.prevalence(q);
assert(prev[0].label === "Price" && prev[0].n === 2 && prev[0].pct === 50,
  "prevalence: Price = 2 mentions = 50% of 4 commenters");
assert(prev[0].pos === 1 && prev[0].neg === 1 && prev[0].net === 0,
  "prevalence: Price split pos 1 / neg 1, net 0");
assert(prev[1].label === "Service" && prev[1].pct === 25,
  "prevalence: Service 25%, sorted after Price (by volume)");

assert(qual.tierFilter(q.records, "all").length === 4, "tierFilter all -> 4");
assert(qual.tierFilter(q.records, "noteworthy").length === 2, "tierFilter noteworthy+ -> 2 (tier>=1)");
assert(qual.tierFilter(q.records, "must_read").length === 1, "tierFilter must-read -> 1 (tier>=2)");

assert(qual.recordsForTheme(q, 0, "all").length === 2, "recordsForTheme Price (all) -> 2");
assert(qual.recordsForTheme(q, 0, "noteworthy").length === 1,
  "recordsForTheme Price (noteworthy+) -> 1 (drops the tier-0 mention)");

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
