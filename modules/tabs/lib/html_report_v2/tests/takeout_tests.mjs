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

run("GROUP pattern finds the column behind on the most questions", () => {
  const mk = (col, code, gap, dir) => ({ column: col, bannerGroup: "Campus", code: code,
    title: code, isMean: true, value: 3.4, rest: 4.0, overall: 3.9, gap: gap, direction: dir,
    scaleMin: 0, scaleMax: 5 });
  const standouts = [
    mk("Cape Town", "Q1", -0.6, "behind"), mk("Cape Town", "Q2", -0.5, "behind"),
    mk("Cape Town", "Q3", -0.4, "behind"),
    { column: "Durban", bannerGroup: "Campus", code: "Q1", title: "Q1", isMean: true,
      value: 4.5, rest: 3.9, overall: 3.9, gap: 0.6, direction: "ahead", scaleMin: 0, scaleMax: 5 },
    { column: "Durban", bannerGroup: "Campus", code: "Q2", title: "Q2", isMean: true,
      value: 4.4, rest: 3.9, overall: 3.9, gap: 0.5, direction: "ahead", scaleMin: 0, scaleMax: 5 }
  ];
  const g = takeout._groupPattern(standouts);
  assert(g && g.subject === "Cape Town", "Cape Town is the group under strain");
  assert(g.hits === 3, "behind on 3 questions, got " + g.hits);
  assert(g.secondary === "Durban", "Durban is the thriving group");
  assert(g.evidence.length === 3, "evidence rows present");
});

run("GROUP pattern needs enough hits (else null)", () => {
  const one = [{ column: "X", code: "Q1", title: "Q1", isMean: true, value: 3, rest: 4,
    overall: 3.9, gap: -1, direction: "behind", scaleMin: 0, scaleMax: 5 }];
  assert(takeout._groupPattern(one) === null, "a single behind-finding is not a pattern");
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
    standouts: [
      { column: "Cape Town", bannerGroup: "Campus", code: "Q08", title: "Recognition", isMean: true,
        value: 3.0, rest: 3.8, overall: 3.6, gap: -0.8, direction: "behind", scaleMin: 0, scaleMax: 5 },
      { column: "Cape Town", bannerGroup: "Campus", code: "Q11", title: "Opinions", isMean: true,
        value: 3.1, rest: 3.9, overall: 3.7, gap: -0.8, direction: "behind", scaleMin: 0, scaleMax: 5 }
    ],
    levels: [
      { code: "Q08", title: "Recognition", section: "Engagement", theme: "Recognition & voice", value: 3.4, scaleMax: 5, delta: { sig: true, diff: -0.2 } },
      { code: "Q11", title: "Opinions", section: "Engagement", theme: "Recognition & voice", value: 3.7, scaleMax: 5, delta: null },
      { code: "Q12", title: "Mission", section: "Engagement", theme: "Belonging", value: 4.4, scaleMax: 5, delta: null },
      { code: "Q13", title: "Co-workers", section: "Engagement", theme: "Belonging", value: 4.2, scaleMax: 5, delta: null }
    ],
    apex: [{ label: "Engagement", value: 4.08, delta: { sig: true, diff: -0.6, year: 2024 }, waves: [{ year: 2023, value: 4.3 }, { year: 2025, value: 4.08, current: true }] }],
    reliability: { n: 167 }
  });
  const ids = t.patterns.map((p) => p.id);
  assert(ids.indexOf("group") !== -1, "group pattern present");
  assert(ids.indexOf("weak") !== -1 && ids.indexOf("strong") !== -1, "weak + strong areas present");
  assert(ids.indexOf("moved") !== -1, "movement pattern present");
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
  const netRows = [{ kind: "net", label: "Agree" }, { kind: "net", label: "Disagree" },
    { kind: "net", label: "NET POSITIVE" }, { kind: "mean", label: "Index" }];
  const qmodel = (mean, top, delta, waves) => ({ columns: [{ base: 167 }], rows: [
    { kind: "net", cells: [{ pct: top }] }, { kind: "net", cells: [{ pct: 6 }] },
    { kind: "net", cells: [{ pct: top - 6 }] },
    { kind: "mean", cells: [{ mean: mean }], delta: delta || null, waves: waves || null }] });
  const meanOnly = (mean, delta, waves) => ({ columns: [{ base: 167 }],
    rows: [{ kind: "mean", cells: [{ mean: mean }], delta: delta || null, waves: waves || null }] });
  const M = {
    Q28: qmodel(3.9, 69, { sig: true, diff: 0.1, year: 2024 }, [{ year: 2023, value: 4.08 }, { year: 2025, value: 3.9, current: true }]),
    Q_Engage: meanOnly(4.08, { sig: true, diff: -0.08, year: 2024 }, [{ year: 2023, value: 4.31 }, { year: 2025, value: 4.08, current: true }]),
    Q08: qmodel(3.44, 41, null), Q11: qmodel(3.72, 58, null),
    Q12: qmodel(4.40, 86, null), Q13: qmodel(4.20, 82, null)
  };
  const seg = (col, val, gap) => ({ code: "Q28", title: "Overall satisfaction", category: "",
    column: col, label: "Index", isMean: true, soft: false, value: val, rest: 3.95, overall: 3.9,
    gap: gap, direction: gap < 0 ? "behind" : "ahead", decimals: 1, scaleMin: 0, scaleMax: 5, beaten: [], base: 38 });
  TR.views = {
    _collectFindings: (g) => {
      if (g === "Q02") return [seg("Cape Town", 3.38, -0.6), seg("Cape Town", 3.40, -0.5), seg("Durban", 4.5, 0.6)];
      if (g === "Q03") return [seg("Marketing", 3.43, -0.5)];
      return [];
    },
    indexQuestions: () => ([
      { code: "Q28", title: "Overall satisfaction with SACAP", category: "", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: netRows, net_diffs: { "2": true } },
      { code: "Q_Engage", title: "Engagement", category: "", type: "single", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: [{ kind: "mean", label: "Engagement" }] },
      { code: "Q08", title: "Recognition", category: "Engagement", theme: "Recognition & voice", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: netRows, net_diffs: { "2": true } },
      { code: "Q11", title: "Opinions count", category: "Engagement", theme: "Recognition & voice", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: netRows, net_diffs: { "2": true } },
      { code: "Q12", title: "Mission matters", category: "Engagement", theme: "Belonging & purpose", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: netRows, net_diffs: { "2": true } },
      { code: "Q13", title: "Co-workers commit", category: "Engagement", theme: "Belonging & purpose", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: netRows, net_diffs: { "2": true } }
    ]),
    _modelFor: (code) => M[code],
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
