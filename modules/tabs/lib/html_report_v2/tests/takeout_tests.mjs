#!/usr/bin/env node
/**
 * Verification gate for the Executive Takeout Patterns engine. Runs:
 *   1. known-answer tests for the pure engine (Cohen's h, effect size, the group
 *      / area / movement patterns, build + graceful fallback) and the curation
 *      state — hand-verifiable expected values.
 *   2. an end-to-end render over stubbed live surfaces (gather -> build -> both
 *      views) exercising tagging, index+top-box, multi-banner and participation.
 *   3. a source structure check (no takeout JS file over 300 active lines).
 * Exit 0 = everything passed. No dependencies beyond node.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/takeout_tests.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const MAX_ACTIVE_LINES = 300;

const sandbox = { console };
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
const takeoutFiles = readdirSync(JS_DIR).filter((f) => /takeout.*\.js$/.test(f)).sort();
for (const file of ["00_namespace.js", "01_format.js"].concat(takeoutFiles)) {
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });
}
const TR = sandbox.TR;
const takeout = TR.takeout;
const C = takeout.CONST;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function close(a, e, tol, msg) { if (Math.abs(a - e) > tol) throw new Error(msg + ": expected ~" + e + ", got " + a); }

console.log("Executive Takeout — Patterns engine known-answer suite:");

run("Cohen's h known answers", () => {
  close(takeout.cohenH(0.5, 0.5), 0, 1e-9, "h(.5,.5)=0");
  close(takeout.cohenH(0.86, 0.74), 0.3033, 1e-3, "h(.86,.74)");
  assert(takeout.cohenH(0.9, 0.5) > 0 && takeout.cohenH(0.5, 0.9) < 0, "sign follows direction");
});

run("effect size is comparable across metrics", () => {
  close(takeout.effectSize({ isMean: false, value: 86, rest: 74, overall: 80 }), 0.3033 / 0.8, 1e-3, "proportion");
  close(takeout.effectSize({ isMean: true, gap: 0.6, scaleMin: 0, scaleMax: 10 }), 0.06, 1e-9, "mean");
});

run("GROUP pattern: the column most below the overall is under strain", () => {
  const g = (value, total) => ({ title: "Q", value: value, total: total, scaleMax: 5 });
  const col = (column, group, gaps) => ({ column: column, group: group, gaps: gaps });
  const columns = [
    col("Cape Town", "Campus", [g(3.2, 3.9), g(3.4, 4.1), g(3.0, 3.8)]),  // consistently below overall
    col("Durban", "Campus", [g(4.5, 3.9), g(4.4, 4.1), g(4.3, 3.8)]),     // consistently above
    col("Joburg", "Campus", [g(3.9, 3.9), g(4.1, 4.1), g(3.8, 3.8)])      // roughly average
  ];
  const p = takeout._groupPattern(columns);
  assert(p && p.subject === "Cape Town", "Cape Town is the group under strain");
  assert(p.secondary === "Durban", "Durban is the thriving group");
  assert(p.hits === 3, "below the overall on all 3, got " + p.hits);
  assert(p.evidence.length === 3 && p.evidence[0].isMean === true, "evidence is index comparisons");
  // the most-below question leads the evidence
  assert(p.evidence[0].value < p.evidence[0].rest, "evidence reads as genuinely behind");
});

run("GROUP pattern: null when no column is materially below the overall", () => {
  const flat = [{ column: "A", group: "G", gaps: [{ title: "Q", value: 3.95, total: 4.0, scaleMax: 5 }] }];
  assert(takeout._groupPattern(flat) === null, "one near-average gap is not a pattern");
  const slightly = [{ column: "B", group: "G",
    gaps: [{ title: "Q1", value: 3.98, total: 4.0, scaleMax: 5 }, { title: "Q2", value: 3.97, total: 4.0, scaleMax: 5 }] }];
  assert(takeout._groupPattern(slightly) === null, "below by <2% of scale is not 'under strain'");
});

run("AREA patterns rank weakest and strongest theme", () => {
  const lv = (code, theme, value) => ({ code, title: code, section: "Engagement", theme,
    value, scaleMin: 0, scaleMax: 5, delta: null });
  const levels = [
    lv("Q08", "Recognition & voice", 3.4), lv("Q11", "Recognition & voice", 3.7),
    lv("Q12", "Belonging & purpose", 4.4), lv("Q13", "Belonging & purpose", 4.5)
  ];
  const ps = takeout._areaPatterns(levels);
  const weak = ps.filter((p) => p.id === "weak")[0];
  const strong = ps.filter((p) => p.id === "strong")[0];
  assert(weak && weak.subject === "Recognition & voice", "weakest area is Recognition & voice");
  close(weak.avg, 3.55, 1e-9, "weak area average");
  assert(strong && strong.subject === "Belonging & purpose", "strongest area is Belonging & purpose");
  close(strong.avg, 4.45, 1e-9, "strong area average");
});

run("AREA patterns: single-question themes don't count; untagged falls back", () => {
  const levels = [
    { code: "Q1", title: "Q1", section: "", theme: "", value: 3, scaleMax: 5 },
    { code: "Q2", title: "Q2", section: "", theme: "", value: 4, scaleMax: 5 }
  ];
  assert(takeout._areaPatterns(levels).length === 0, "untagged levels yield no area pattern");
  const lone = [{ code: "Q1", title: "Q1", section: "S", theme: "Solo", value: 3, scaleMax: 5 }];
  assert(takeout._areaPatterns(lone).length === 0, "a one-question theme is not an area");
});

run("buildPatterns assembles group + areas + movement, and degrades gracefully", () => {
  const empty = takeout.buildPatterns({});
  assert(empty.patterns.length === 0, "nothing in, nothing out — no crash");
  const t = takeout.buildPatterns({
    columns: [
      { column: "Cape Town", group: "Campus", gaps: [
        { title: "Recognition", value: 3.0, total: 3.8, scaleMax: 5 },
        { title: "Opinions", value: 3.1, total: 3.9, scaleMax: 5 }] },
      { column: "Durban", group: "Campus", gaps: [
        { title: "Recognition", value: 4.4, total: 3.8, scaleMax: 5 },
        { title: "Opinions", value: 4.3, total: 3.9, scaleMax: 5 }] }
    ],
    levels: [
      { code: "Q08", title: "Recognition", section: "Engagement", theme: "Recognition & voice", value: 3.4, scaleMax: 5, delta: { sig: true, diff: -0.2 } },
      { code: "Q11", title: "Opinions", section: "Engagement", theme: "Recognition & voice", value: 3.7, scaleMax: 5, delta: null },
      { code: "Q12", title: "Mission", section: "Engagement", theme: "Belonging", value: 4.4, scaleMax: 5, delta: null },
      { code: "Q13", title: "Co-workers", section: "Engagement", theme: "Belonging", value: 4.2, scaleMax: 5, delta: null }
    ],
    apex: [{ label: "Engagement", value: 4.08, scaleMax: 5, delta: { sig: true, diff: -0.6, year: 2024 }, waves: [{ year: 2023, value: 4.3 }, { year: 2025, value: 4.08, current: true }] }],
    reliability: { n: 167 }
  });
  const ids = t.patterns.map((p) => p.id);
  assert(ids.indexOf("group") !== -1, "group pattern present");
  assert(ids.indexOf("weak") !== -1 && ids.indexOf("strong") !== -1, "weak + strong areas present");
  assert(ids.indexOf("moved") !== -1, "movement pattern present");
});

run("MOVEMENT is two-sided and ignores trivial moves", () => {
  const mv = (label, diff) => ({ label, value: 4, scaleMax: 5,
    delta: { sig: true, diff: diff, year: 2024 }, waves: [{ year: 2023, value: 4 }, { year: 2024, value: 4 + diff, current: true }] });
  // 0.1 / 0.08 on a 5-point scale is within noise -> broadly stable, not "a move"
  const stable = takeout._movementPattern([mv("A", 0.1), mv("B", -0.08)]);
  assert(stable && stable.stable === true, "trivial moves report as broadly stable");
  // material moves both ways -> two-sided, biggest absolute leads
  const t = takeout._movementPattern([mv("Risen", 0.4), mv("Fallen", -0.6)]);
  assert(t && !t.stable, "material moves surface");
  assert(t.up && t.up.subject === "Risen", "biggest riser captured");
  assert(t.down && t.down.subject === "Fallen", "biggest faller captured");
  assert(t.subject === "Fallen", "the bigger absolute move leads the card");
  // no significant movers at all -> no movement pattern
  assert(takeout._movementPattern([{ label: "Z", scaleMax: 5, delta: { sig: false, diff: -1 } }]) === null,
    "no significant change -> no movement pattern");
});

run("curation state round-trips and resets", () => {
  takeout.state.setText("weak", "takeaway", "Client wording");
  assert(takeout.state.getText("weak", "takeaway", "seed") === "Client wording", "edit wins");
  assert(takeout.state.getText("strong", "takeaway", "seed") === "seed", "seed fallback");
  takeout.state.setApex("My one-line answer");
  assert(takeout.state.getApex("seed") === "My one-line answer", "apex saved");
  takeout.state.reset();
  assert(takeout.state.getText("weak", "takeaway", "seed") === "seed", "reset clears");
});

run("every takeout module loaded and exposes its API", () => {
  ["buildPatterns", "gather", "compute", "render"].forEach((fn) =>
    assert(typeof takeout[fn] === "function", fn + " is a function"));
  assert(takeout.ui && typeof takeout.ui.areaRow === "function", "ui atoms present");
  assert(takeout.readView && typeof takeout.readView.html === "function", "read view present");
  assert(takeout.presentView && typeof takeout.presentView.html === "function", "present view present");
});

run("end-to-end: tagging, index+top-box, multi-banner, participation, both views", () => {
  TR.charts = { clip: (s, n) => String(s == null ? "" : s).slice(0, n) };
  TR.conf = { maxMoePct: () => 0.0, reportHasPopulation: () => true,
    labels: () => ({ sampling_method_normalised: "census", is_probability: false }),
    calloutHtml: () => '<div class="callout collapsed"><button data-callout></button></div>" ' };
  TR.render = { wavePoints: (row) => row.waves || null, sparkline: () => '<svg class="spark"></svg>' };
  TR.AGG = { project: { name: "Climate 2025", low_base_threshold: 30, population_size: 220 },
    banner_groups: [{ id: "Q02", name: "Campus" }, { id: "Q03", name: "Department" }] };
  TR.d2 = { state: { banner: "Q02" }, firstBanner: () => "Q02" };
  // every rated question returns a 3-column model (Total · Cape Town · Durban);
  // Cape Town sits 0.6 below the Total on every question -> the strain group.
  const TOTAL = { Q28: 3.9, Q_Engage: 4.08, Q08: 3.44, Q11: 3.72, Q12: 4.40, Q13: 4.20 };
  const TOP = { Q28: 69, Q08: 41, Q11: 58, Q12: 86, Q13: 82 };
  const mk = (code) => {
    const t = TOTAL[code], ct = t - 0.6, du = t + 0.4;
    const cols = [{ base: 167 }, { label: "Cape Town", base: 38 }, { label: "Durban", base: 33 }];
    const delta = code === "Q28" ? { sig: true, diff: 0.1, year: 2024 }
      : (code === "Q_Engage" ? { sig: true, diff: -0.08, year: 2024 } : null);
    const waves = (code === "Q28" || code === "Q_Engage")
      ? [{ year: 2023, value: t + 0.2 }, { year: 2025, value: t, current: true }] : null;
    const meanRow = { kind: "mean", cells: [{ mean: t }, { mean: ct }, { mean: du }], delta: delta, waves: waves };
    if (code === "Q_Engage") return { columns: cols, rows: [meanRow] };
    const top = TOP[code];
    return { columns: cols, rows: [
      { kind: "net", label: "Agree", cells: [{ pct: top }, { pct: top - 20 }, { pct: top + 10 }] },
      { kind: "net", label: "Disagree", cells: [{ pct: 6 }, { pct: 16 }, { pct: 3 }] },
      { kind: "net", label: "NET POSITIVE", cells: [{ pct: top - 6 }, { pct: 0 }, { pct: 0 }] },
      meanRow] };
  };
  TR.views = {
    indexQuestions: () => ([
      { code: "Q28", title: "Overall satisfaction with SACAP", category: "", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: mk("Q28").rows, net_diffs: { "2": true } },
      { code: "Q_Engage", title: "Engagement", category: "", type: "single", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: [{ kind: "mean", label: "Engagement" }] },
      { code: "Q08", title: "Recognition", category: "Engagement", theme: "Recognition & voice", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: mk("Q08").rows, net_diffs: { "2": true } },
      { code: "Q11", title: "Opinions count", category: "Engagement", theme: "Recognition & voice", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: mk("Q11").rows, net_diffs: { "2": true } },
      { code: "Q12", title: "Mission matters", category: "Engagement", theme: "Belonging & purpose", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: mk("Q12").rows, net_diffs: { "2": true } },
      { code: "Q13", title: "Co-workers commit", category: "Engagement", theme: "Belonging & purpose", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: mk("Q13").rows, net_diffs: { "2": true } }
    ]),
    _modelFor: (code) => mk(code),
    _meanRow: (m) => m.rows.find((r) => r.kind === "mean")
  };
  TR.model = { forQuestion: (code) => TR.views._modelFor(code) };

  const t = takeout.compute();
  assert(t.patterns.some((p) => p.id === "group"), "group pattern built");
  assert(t.patterns.some((p) => p.id === "weak"), "weakest-area pattern built");
  const read = takeout.readView.html(t);
  const present = takeout.presentView.html(t);
  assert(read.indexOf("Recognition &amp; voice") !== -1, "weakest area named");
  assert(read.indexOf("Belonging &amp; purpose") !== -1, "strongest area named");
  assert(read.indexOf("Cape Town") !== -1, "group under strain named");
  assert(read.indexOf("Satisfaction") !== -1, "satisfaction leads the apex");
  assert(read.indexOf("69% agree") !== -1, "apex shows index + top-box");
  assert(read.indexOf("% response of") !== -1, "participation shown");
  assert(read.indexOf('data-edit="') !== -1, "editable hooks present");
  assert(present.indexOf("tko-slide") !== -1, "present renders");
});

console.log("Source structure check (<=" + MAX_ACTIVE_LINES + " active lines/file):");
function activeLines(src) {
  let inBlock = false, count = 0;
  for (const raw of src.split("\n")) {
    const t = raw.trim();
    if (!t) continue;
    if (inBlock) { if (t.includes("*/")) inBlock = false; continue; }
    if (t.startsWith("/*")) { if (!t.includes("*/")) inBlock = true; continue; }
    if (t.startsWith("//") || t.startsWith("*")) continue;
    if (/^[{}()\[\];,]+$/.test(t)) continue;
    count++;
  }
  return count;
}
for (const file of readdirSync(JS_DIR).filter((f) => /takeout.*\.js$/.test(f)).sort()) {
  const n = activeLines(readFileSync(path.join(JS_DIR, file), "utf8"));
  run(file + " (" + n + " active lines)", () =>
    assert(n <= MAX_ACTIVE_LINES, file + " has " + n + " active lines (max " + MAX_ACTIVE_LINES + ")"));
}

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
