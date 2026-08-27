#!/usr/bin/env node
/**
 * The confidentiality ship keeps its trend line.
 *
 * `html_report_v2_microdata = FALSE` ships no per-respondent records, so the
 * current wave's island entry carries no `scores`. That used to mean no
 * Tracking tab at all, which put anonymity and a trend line in competition.
 * The R side now builds the current wave from published figures
 * (`published_wave_contribution()`); this suite proves the RENDERER does the
 * rest — that a scores-free current wave still:
 *
 *   1. pairs with history (waves.history) and carries a delta;
 *   2. is significance-tested, with the current SD derived from the published
 *      category distribution (sdFromModel), not from records;
 *   3. calls a small movement NOT significant — so (2) is a real test;
 *   4. reports currentPoint() as null, which is what makes the callers fall
 *      back to the published cell;
 *   5. keys history by question CODE when the current wave carries codes, and
 *      by normalised title when it does not;
 *   6. plots a mean-ONLY question untested — the one honest degrade, since a
 *      hidden distribution leaves no spread to test with;
 *   7. behaves identically to today on the proportion path (proportions never
 *      carried scores).
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/published_wave_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";
import { installText } from "./_text.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.createContext(sandbox);
installText(sandbox);
for (const file of ["00_namespace.js", "01_format.js", "03_svg.js", "20_data.js",
  "21_stats.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js", "22_model.js",
  "23_render.js", "26_filter.js"]) {
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });
}
const TR = sandbox.TR;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) {
  if (a !== b) throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a));
}

/* ---------------- fixtures ----------------
 * One rating question published as a 50/50 split between 7.86 and 9.86, mean
 * 8.9 on a base of 800. The distribution is the ONLY source of spread once the
 * records are gone, and it gives sd ~= 1.0.
 */
function publishedRating(meanCell) {
  TR.PREV = null;
  TR.userState = null;
  TR.MICRO = null;                       // the confidentiality ship: no records
  TR.AGG = {
    project: { name: "No-micro ship", low_base_threshold: 30, weighted: false },
    banner_groups: [],
    columns: [{ label: "Total", letter: "", group: null }],
    questions: [
      { code: "QM", title: "Overall rating", type: "scale", scale_max: 10, category: "T",
        bases: [{ n: 800, low: false }],
        rows: [
          { kind: "category", label: "7.86", pct: [50], n: [400], sig: [""] },
          { kind: "category", label: "9.86", pct: [50], n: [400], sig: [""] },
          { kind: "mean", label: "Mean", pct: [meanCell], n: [null], sig: [""] }
        ] }
    ]
  };
  if (TR.d2) TR.d2._qIndex = null;
}

/** A prior wave, published-figures shape (mean + sd + base) — no records. */
const priorMean = (wave, year, mean, sd) => ({
  wave: wave, year: year, current: false, segments: [],
  questions: [{ match_key: "overall rating", title: "Overall rating",
    base: 800, stats: { mean: mean, sd: sd } }]
});

/** The current wave as published_wave_contribution() builds it: no scores. */
const currentPublished = (wave, year, withCode) => ({
  wave: wave, year: year, current: true, segments: [],
  questions: [Object.assign(
    { match_key: "overall rating", title: "Overall rating",
      base: 800, score_type: "mean" },
    withCode ? { code: "QM" } : {})]
});

function meanRow(meanCell, waves) {
  publishedRating(meanCell);
  TR.PREV = { waves: waves };
  if (TR.waves.reset) TR.waves.reset();
  return TR.model.forQuestion("QM", null, [], {}).rows[2];
}

console.log("Published (no-microdata) current wave — suite:");

run("a scores-free current wave still pairs with history and carries a delta", () => {
  const row = meanRow(8.9, [priorMean("2025", 2025, 7.0, 1.0),
    currentPublished("2026", 2026, true)]);
  assert(row.delta, "the mean row carries a wave delta with no records present");
  eq(row.delta.diff, 1.9, "displayed delta subtracts the published ends (8.9 - 7.0)");
});

run("a real movement is still called significant (SD from the published distribution)", () => {
  const row = meanRow(8.9, [priorMean("2025", 2025, 7.0, 1.0),
    currentPublished("2026", 2026, true)]);
  assert(row.delta.sig,
    "1.9 points on sd ~1.0 and base 800 must test significant without records");
});

run("a small movement is NOT significant — the test is real, not a rubber stamp", () => {
  const row = meanRow(8.9, [priorMean("2025", 2025, 8.85, 1.0),
    currentPublished("2026", 2026, true)]);
  assert(!row.delta.sig,
    "0.05 points on sd ~1.0 must not test significant (got sig=" +
    JSON.stringify(row.delta.sig) + ")");
});

run("currentPoint() is null without scores — which is what makes the callers fall back", () => {
  publishedRating(8.9);
  TR.PREV = { waves: [priorMean("2025", 2025, 7.0, 1.0),
    currentPublished("2026", 2026, true)] };
  if (TR.waves.reset) TR.waves.reset();
  const q = TR.AGG.questions[0];
  eq(TR.waves.currentPoint(q), null, "no scores -> no microdata recompute");
  eq(TR.waves.currentScores(q), null, "and no per-respondent scores are exposed");
  eq(TR.waves.history(q).length, 1, "history is still found (the current wave is excluded)");
  eq(TR.waves.history(q)[0].wave, "2025", "and it is the prior wave");
});

run("history keys by question CODE when the current wave carries one", () => {
  // The code map is what makes a canonical key (Track_01) survive a rewording.
  publishedRating(8.9);
  TR.PREV = { waves: [
    { wave: "2025", year: 2025, current: false, segments: [],
      questions: [{ match_key: "track01", title: "Old wording", base: 800,
        stats: { mean: 7.0, sd: 1.0 } }] },
    { wave: "2026", year: 2026, current: true, segments: [],
      questions: [{ code: "QM", match_key: "track01", title: "Overall rating",
        base: 800, score_type: "mean" }] }
  ] };
  if (TR.waves.reset) TR.waves.reset();
  const hist = TR.waves.history(TR.AGG.questions[0]);
  eq(hist.length, 1, "the reworded question still finds its history by code");
});

run("and by normalised title when it does not", () => {
  const row = meanRow(8.9, [priorMean("2025", 2025, 7.0, 1.0),
    currentPublished("2026", 2026, false)]);
  assert(row.delta, "title-keyed pairing is unchanged by the no-records path");
  eq(row.delta.diff, 1.9, "same delta");
});

run("a mean-ONLY question plots untested — the one real difference vs a microdata build", () => {
  // The current wave's spread comes from the published category distribution.
  // A rating question that publishes only its mean (every category hidden) has
  // no distribution to derive one from, so its trend still draws but carries no
  // significance call. The microdata build WOULD test it, off the records. This
  // is an honest degrade, and it is the only behavioural difference.
  TR.PREV = null;
  TR.userState = null;
  TR.MICRO = null;
  TR.AGG = {
    project: { name: "No-micro ship", low_base_threshold: 30, weighted: false },
    banner_groups: [],
    columns: [{ label: "Total", letter: "", group: null }],
    questions: [
      { code: "QM", title: "Overall rating", type: "scale", scale_max: 10, category: "T",
        bases: [{ n: 800, low: false }],
        rows: [{ kind: "mean", label: "Mean", pct: [8.9], n: [null], sig: [""] }] }
    ]
  };
  if (TR.d2) TR.d2._qIndex = null;
  TR.PREV = { waves: [priorMean("2025", 2025, 7.0, 1.0),
    currentPublished("2026", 2026, true)] };
  if (TR.waves.reset) TR.waves.reset();
  const row = TR.model.forQuestion("QM", null, [], {}).rows[0];
  assert(row.delta, "the trend still draws");
  eq(row.delta.diff, 1.9, "and the movement is still shown");
  assert(!row.delta.sig, "but it is NOT tested — no distribution, no spread");
});

run("the proportion path is untouched (it never carried scores)", () => {
  TR.PREV = null;
  TR.userState = null;
  TR.MICRO = null;
  TR.AGG = {
    project: { name: "No-micro ship", low_base_threshold: 30, weighted: false },
    banner_groups: [],
    columns: [{ label: "Total", letter: "", group: null }],
    questions: [
      { code: "QP", title: "Uses the service", type: "single", category: "T",
        bases: [{ n: 800, low: false }],
        rows: [
          { kind: "category", label: "Yes", pct: [60], n: [480], sig: [""] },
          { kind: "category", label: "No", pct: [40], n: [320], sig: [""] }
        ] }
    ]
  };
  if (TR.d2) TR.d2._qIndex = null;
  TR.PREV = { waves: [
    { wave: "2025", year: 2025, current: false, segments: [],
      questions: [{ match_key: "uses the service", title: "Uses the service",
        base: 800, rows: { yes: { pct: 50 }, no: { pct: 50 } } }] },
    { wave: "2026", year: 2026, current: true, segments: [],
      questions: [{ code: "QP", match_key: "uses the service",
        title: "Uses the service", base: 800, score_type: "mean" }] }
  ] };
  if (TR.waves.reset) TR.waves.reset();
  const row = TR.model.forQuestion("QP", null, [], {}).rows[0];
  assert(row.delta, "the Yes row carries a wave delta");
  eq(row.delta.diff, 10, "60% - 50%");
  assert(row.delta.sig, "10 points on bases of 800 is significant");
});

console.log("\n  " + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
