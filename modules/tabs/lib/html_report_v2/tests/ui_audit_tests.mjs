#!/usr/bin/env node
/**
 * UI audit gate (2026-07 findings) — three fixes:
 *
 * 1. Wave labels: the PUBLISHED badge, "new in …" badge and the dashboard's
 *    "▲▼ chips show change vs …" intro hard-coded 2025/2024. They must derive
 *    both wave names from the report's own tracking island, and drop the
 *    vs-wave phrasing entirely on non-tracking reports.
 * 2. Selftest: the #selftest panel hardcodes SACAP-prototype golden data; on
 *    other projects those cases must be skipped ("fixture not present"), not
 *    falsely reported as a broken stats engine. Data-independent cases still
 *    run everywhere.
 * 3. Filter picker: mixing a box grouping with category values set box=true
 *    for the whole row set, so the category picks were matched against box
 *    membership and silently dropped. A mixed selection must keep BOTH parts.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/ui_audit_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const load = (sandbox, file) =>
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(actual, expected, msg) {
  const a = JSON.stringify(actual), e = JSON.stringify(expected);
  if (a !== e) throw new Error(msg + ": expected " + e + ", got " + a);
}

/* ---------- 1. wave labels (25_cards.js + 27_views.js) ---------- */

const cv = { console };
cv.globalThis = cv;
cv.window = cv;
let tracking = { enabled: false, waves: [] };
cv.TR = {
  fmt: { escapeHtml: (s) => String(s), base: (n) => String(n) },
  charts: { clip: (s) => s },
  d2: { tracking: () => tracking },
  AGG: { project: {} },
  PREV: null
};
vm.createContext(cv);
load(cv, "25_cards.js");
load(cv, "27_views.js");
const cards2 = cv.TR.cards2, views = cv.TR.views;

console.log("UI audit fixes — suite:");

run("non-tracking report: no wave named anywhere, no vs-wave phrasing", () => {
  tracking = { enabled: false, waves: [] };
  eq(cards2.waveLabels(), { tracking: false, current: "", prev: "" }, "waveLabels");
  eq(cards2._publishedBadgeHtml(),
    '<span class="badge-published" title="Published value, verbatim">PUBLISHED</span>',
    "PUBLISHED badge");
  eq(cards2._noHistoryBadgeHtml(), "", "no-history badge dropped entirely");
  eq(views._deltaIntro(true), "", "dashboard intro sentence omitted");
});

run("tracker: wave names come from the island, not hard-coded years", () => {
  tracking = { enabled: true,
    waves: [{ wave: "2023", year: 2023 }, { wave: "2025 H1", year: 2025 }] };
  cv.TR.PREV = { waves: [{ wave: "2023", year: 2023 },
    { wave: "2025 H1", year: 2025 },
    { wave: "2026", year: 2026, current: true }] };
  eq(cards2.waveLabels(),
    { tracking: true, current: "2026", prev: "2025 H1" }, "waveLabels");
  assert(cards2._publishedBadgeHtml().indexOf(
    'title="Published 2026 value, verbatim"') !== -1,
    "PUBLISHED badge names the current wave: " + cards2._publishedBadgeHtml());
  eq(cards2._noHistoryBadgeHtml(),
    '<span class="badge-prev off">new in 2026</span>', "new-in badge");
  eq(views._deltaIntro(true), "▲▼ chips show change vs 2025 H1. ",
    "dashboard intro names the latest prior wave");
  eq(views._deltaIntro(false), "",
    "intro omitted when no gauge carries a delta chip");
});

run("current wave label falls back to project.wave when the island has no current flag", () => {
  tracking = { enabled: true, waves: [{ wave: "W1", year: 2024 }] };
  cv.TR.PREV = { waves: [{ wave: "W1", year: 2024 }] };
  cv.TR.AGG.project.wave = "Wave 2 - Jun 2026";
  eq(cards2.waveLabels(),
    { tracking: true, current: "Wave 2 - Jun 2026", prev: "W1" }, "waveLabels");
  eq(cards2._noHistoryBadgeHtml(),
    '<span class="badge-prev off">new in Wave 2 - Jun 2026</span>', "new-in badge");
});

run("no hard-coded wave years remain in the UI strings", () => {
  const cards = readFileSync(path.join(JS_DIR, "25_cards.js"), "utf8");
  const viewsSrc = readFileSync(path.join(JS_DIR, "27_views.js"), "utf8");
  assert(cards.indexOf("Published 2025") === -1, "25_cards: 'Published 2025' gone");
  assert(cards.indexOf("new in 2025") === -1, "25_cards: 'new in 2025' gone");
  assert(viewsSrc.indexOf("vs 2024") === -1, "27_views: 'vs 2024' gone");
});

/* ---------- 2. selftest fixture gating (31_selftest.js) ---------- */

const FIXTURE_CASES = [
  "filter mask + recompute (golden vs published)",
  "filtered base shrinks and stays consistent",
  "custom banner columns from any question",
  "hash state round-trip",
  "wave matching present",
  "multi-wave known answers (registration: NET, Index, sig)",
  "per-segment tracking known answers (campus, published)",
  "pptx deck builds from a story model",
  "crosstab intervals: golden spot-check, additive only"
];
function selftestSandbox(questions) {
  const st = { console };
  st.globalThis = st;
  st.window = st;
  const prepended = [];
  st.document = {
    createElement: () => ({ className: "", innerHTML: "" }),
    getElementById: () => ({ prepend: (el) => prepended.push(el) })
  };
  st.TR = {
    fmt: { escapeHtml: (s) => String(s) },
    model: { norm: (s) => String(s).toLowerCase().replace(/[^a-z0-9 ]+/g, "")
      .replace(/\s+/g, " ").trim() },
    d2: { questionByCode: (c) => (questions && questions[c]) || null },
    MICRO: questions ? { n: 100 } : null,
    PREV: questions ? { waves: [{ wave: "2024", year: 2024 }] } : null
  };
  vm.createContext(st);
  load(st, "31_selftest.js");
  return { st, prepended };
}

run("fixturePresent: true only on the SACAP prototype dataset", () => {
  const sacap = {
    Q002: { title: "x" }, Q005: { title: "x" }, Q010: { title: "x" },
    Q008: { title: "How would you rate your experience with the Registration process at SACAP?" }
  };
  eq(selftestSandbox(sacap).st.TR.selftest2.fixturePresent(), true, "SACAP shape");
  eq(selftestSandbox(null).st.TR.selftest2.fixturePresent(), false, "no questions");
  const other = { Q002: { title: "x" }, Q005: { title: "x" }, Q010: { title: "x" },
    Q008: { title: "How satisfied are you with your branch?" } };
  eq(selftestSandbox(other).st.TR.selftest2.fixturePresent(), false,
    "same codes, different survey");
});

run("golden cases are flagged fixture; data-independent cases are not", () => {
  const { st } = selftestSandbox(null);
  const cases = st.TR.selftest2.cases();
  const flagged = cases.filter((c) => c.fixture).map((c) => c.name).sort();
  eq(flagged, FIXTURE_CASES.slice().sort(), "exact fixture partition");
  ["z-test known answer (production formula)",
    "sparkline geometry known answer",
    "Wilson intervals match the R confidence module",
    "sampling labels switch on the sampling method",
    "max margin-of-error known answers (dashboard chip)",
    "renderer survives a broken model"].forEach((name) => {
    const c = cases.filter((x) => x.name === name)[0];
    assert(c && !c.fixture, name + " must run everywhere");
  });
});

run("run() skips the golden cases when the fixture is absent", () => {
  const { st, prepended } = selftestSandbox(null);
  const results = st.TR.selftest2.run();
  const skipped = results.filter((r) => r.skipped);
  eq(skipped.map((r) => r.name).sort(), FIXTURE_CASES.slice().sort(),
    "every golden case skipped, nothing else");
  skipped.forEach((r) => {
    assert(r.ok === true && r.error === undefined,
      r.name + " skipped without executing (no error, not a failure)");
  });
  // the data-independent cases actually ran (they error in this bare sandbox,
  // which proves their fn was invoked rather than skipped)
  const ran = results.filter((r) => !r.skipped);
  eq(ran.length, results.length - FIXTURE_CASES.length, "the rest executed");
  const panel = prepended[0];
  assert(panel && panel.innerHTML.indexOf("· 9 skipped") !== -1,
    "panel reports the skip count");
  assert(panel.innerHTML.indexOf("skipped (fixture not present)") !== -1,
    "panel labels skips as fixture-not-present");
});

/* ---------- 3. mixed box + category filter (26_filter.js) ---------- */

function filterSandbox(micro) {
  const fs2 = { console };
  fs2.globalThis = fs2;
  fs2.window = fs2;
  fs2.TR = {
    fmt: { escapeHtml: (s) => String(s), base: (n) => String(n) },
    charts: { clip: (s) => s },
    d2: {},
    MICRO: micro
  };
  vm.createContext(fs2);
  load(fs2, "26_filter.js");
  load(fs2, "21_stats.js");   // real mask so the fix is verified end-to-end
  return fs2.TR;
}

// Shown 5-point scale (rows 0-4) with a box-category NET "Top-2 box" (row 5,
// no net_members — as real reports ship) and a decomposable NET (row 6).
const Q1 = {
  code: "Q1",
  net_members: { "6": [0, 1] },
  rows: [
    { kind: "category", label: "Very dissatisfied" },
    { kind: "category", label: "Dissatisfied" },
    { kind: "category", label: "Neutral" },
    { kind: "category", label: "Satisfied" },
    { kind: "category", label: "Very satisfied" },
    { kind: "net", label: "Top-2 box" },
    { kind: "net", label: "Bottom-2 (NET)" }
  ]
};
const MICRO = {
  n: 8,
  answers: { Q1: [3, 4, 0, 1, 4, 2, 1, null] },
  boxes: { Q1: [5, 5, null, null, 5, null, null, null] },
  banner_vars: {}
};

run("mixed box + category selection keeps BOTH parts (union, exact mask)", () => {
  const TR = filterSandbox(MICRO);
  const built = TR.filterBar.selectionToFilter(Q1, ["c0", "b5"]);
  // box 5 holds respondents answering rows 3/4 -> expands to categories,
  // ORed with the picked category in answer space; no box flag
  eq(built, { filter: { q: "Q1", rows: [0, 3, 4] } }, "built filter");
  const mask = TR.stats.mask([built.filter]);
  eq(TR.stats.maskCount(mask), 4, "audience = Top-2 (3) + Very dissatisfied (1)");
  eq(mask[2], 1, "the category pick (respondent 2, 'Very dissatisfied') kept");
  eq(mask[0], 1, "the box pick (respondent 0, Top-2) kept");
  // the OLD shape dropped the category selection: box=true over both rows
  eq(TR.stats.maskCount(TR.stats.mask([{ q: "Q1", rows: [0, 5], box: true }])), 3,
    "old single-box-flag shape loses the category pick (regression contrast)");
});

run("pure box / pure category / NET selections are unchanged", () => {
  const TR = filterSandbox(MICRO);
  eq(TR.filterBar.selectionToFilter(Q1, ["b5"]),
    { filter: { q: "Q1", rows: [5], box: true } }, "pure box keeps box space");
  eq(TR.stats.maskCount(TR.stats.mask([{ q: "Q1", rows: [5], box: true }])), 3,
    "pure box audience");
  eq(TR.filterBar.selectionToFilter(Q1, ["c0", "c1"]),
    { filter: { q: "Q1", rows: [0, 1] } }, "categories");
  eq(TR.filterBar.selectionToFilter(Q1, ["n6"]),
    { filter: { q: "Q1", rows: [0, 1] } }, "decomposable NET expands to members");
  eq(TR.filterBar.selectionToFilter(Q1, []),
    { error: "Pick at least one value" }, "empty selection refused");
});

run("mixing is refused when a box member has no shown category answer", () => {
  const micro2 = { n: 8,
    answers: { Q1: [-2, 4, 0, 1, 4, 2, 1, null] },   // r0: answered-unshown
    boxes: { Q1: [5, 5, null, null, 5, null, null, null] },
    banner_vars: {} };
  const TR = filterSandbox(micro2);
  const built = TR.filterBar.selectionToFilter(Q1, ["c0", "b5"]);
  assert(built.error && built.error.indexOf("own filter") !== -1,
    "not decomposable -> explicit refusal, never a silently-wrong audience");
  eq(TR.filterBar.selectionToFilter(Q1, ["b5"]),
    { filter: { q: "Q1", rows: [5], box: true } }, "pure box still fine");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
