#!/usr/bin/env node
/**
 * v2 verification gate. Runs the in-browser selftest cases headlessly,
 * the golden parity suite (separate file, spawned), a native-PPTX
 * structural validation via python, artifact checks, and the source
 * structure rule. Zero dependencies beyond node + python3.
 */
import { readFileSync, readdirSync, writeFileSync, existsSync, statSync, mkdirSync } from "node:fs";
import { execFileSync, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const BASE = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const V1_JS = path.join(path.dirname(BASE), "src", "js");
const V2_JS = path.join(BASE, "src", "js");
const MAX_ACTIVE_LINES = 300;

const sandbox = { console, TextEncoder, URL };
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js", "14_pptx_parts.js"]) {
  vm.runInContext(readFileSync(path.join(V1_JS, f), "utf8"), sandbox, { filename: f });
}
for (const f of readdirSync(V2_JS).filter((x) => x.endsWith(".js")).sort()) {
  vm.runInContext(readFileSync(path.join(V2_JS, f), "utf8"), sandbox, { filename: f });
}
const TR = sandbox.TR;
TR.AGG = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_2025.json"), "utf8"));
TR.MICRO = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_microdata.json"), "utf8"));
TR.PREV = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_waves.json"), "utf8"));

let passed = 0, failed = 0;
function run(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e) {
    failed++;
    console.log(`  ✗ ${name}\n    ${e.message}`);
  }
}
const assert = (cond, msg) => { if (!cond) throw new Error(msg); };

console.log("Shared selftest cases (same as in-browser #selftest):");
for (const c of TR.selftest2.cases()) run(c.name, c.fn);

console.log("Node-only suite:");

run("no-banner (Total-only) report validates and renders without crashing", () => {
  // Regression: a survey with no banner cuts. boot used to do
  // banner_groups[0].id unconditionally and threw on the empty array.
  const noBannerAgg = {
    schema_version: 2,
    project: { name: "Total Only", low_base_threshold: 30,
      sampling_method: "Not_Specified", tracking: { enabled: false } },
    columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
    banner_groups: [],
    categories: ["Cat"],
    questions: [{
      code: "Q1", title: "Q1", category: "Cat", type: "scale",
      bases: [{ n: 60, low: false }],
      rows: [
        { kind: "category", label: "Poor", pct: [20], n: [12], sig: [""] },
        { kind: "category", label: "Good", pct: [80], n: [48], sig: [""] },
        { kind: "mean", label: "Mean", pct: [7.4], n: [null], sig: [""] }
      ]
    }]
  };
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex };
  try {
    TR.AGG = noBannerAgg; TR.MICRO = null; TR.PREV = null; TR.d2._qIndex = null;
    assert(TR.d2.validate(noBannerAgg, null, null).ok, "no-banner agg should validate");
    // boot's fallback for no groups is "" — which must match no column group
    const defBanner = (noBannerAgg.banner_groups && noBannerAgg.banner_groups.length)
      ? noBannerAgg.banner_groups[0].id : "";
    assert(defBanner === "", 'no-banner default should be ""');
    assert(TR.d2.groupCols("").length === 0, 'groupCols("") should be empty');
    const m = TR.model.forQuestion("Q1", defBanner, []);
    assert(m && m.columns.length === 1, "expected a single Total column");
    assert(m.columns[0].label === "Total", "the only column should be Total");
    assert(m.rows.length === 3 && m.rows[0].cells.length === 1, "Total-only cells");
  } finally {
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev; TR.d2._qIndex = saved.idx;
  }
});

run("dashboard excludes numeric questions (open counts are not rated touchpoints)", () => {
  // A Numeric open-count (type "numeric", e.g. "hours lost") carries a Mean row
  // but has NO scale maximum, so the index dashboard must skip it — only
  // scale / nps questions with a mean row are rated touchpoints. Regression for
  // numeric questions being colour-banded as a % of a 10-point scale.
  const agg = { schema_version: 2,
    project: { name: "N", low_base_threshold: 30, tracking: { enabled: false } },
    columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
    banner_groups: [], categories: ["c"],
    questions: [
      { code: "QR", title: "Rate quality", category: "c", type: "scale",
        scale_max: 10, bases: [{ n: 60, low: false }],
        rows: [{ kind: "mean", label: "Mean", pct: [7.4], n: [null], sig: [""] }] },
      { code: "QN", title: "Hours lost", category: "c", type: "numeric",
        bases: [{ n: 60, low: false }],
        rows: [{ kind: "mean", label: "Mean", pct: [9], n: [null], sig: [""] },
               { kind: "mean", label: "Standard Deviation", pct: [2], n: [null], sig: [""] }] }
    ] };
  const saved = { agg: TR.AGG, idx: TR.d2._qIndex };
  try {
    TR.AGG = agg; TR.d2._qIndex = null;
    const codes = TR.views._indexQuestions().map((q) => q.code);
    assert(codes.indexOf("QR") !== -1, "rated scale question must be on the dashboard");
    assert(codes.indexOf("QN") === -1, "numeric question must be excluded from the dashboard");
  } finally {
    TR.AGG = saved.agg; TR.d2._qIndex = saved.idx;
  }
});

run("pinning a table carries the Counts toggle (showCounts round-trips into the pin)", () => {
  // Regression: pinCurrent captured intervals but not showCounts, so a table
  // pinned with "Counts" on rendered without n= in the Story. The flag must
  // travel with the pin and drive the rendered table.
  const agg = { schema_version: 2,
    project: { name: "C", low_base_threshold: 30, tracking: { enabled: false } },
    columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
    banner_groups: [], categories: ["c"],
    questions: [{ code: "Q1", title: "Q1", category: "c", type: "single",
      bases: [{ n: 60, low: false }],
      rows: [{ kind: "category", label: "Yes", pct: [60], n: [36], sig: [""] },
             { kind: "category", label: "No", pct: [40], n: [24], sig: [""] }] }] };
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex,
    state: JSON.parse(JSON.stringify(TR.d2.state)), len: TR.story2.items().length };
  try {
    TR.AGG = agg; TR.MICRO = null; TR.PREV = null; TR.d2._qIndex = null;
    TR.d2.state.activeQ = "Q1"; TR.d2.state.banner = ""; TR.d2.state.filters = [];
    TR.d2.state.showIntervals = false; TR.d2.state.sigMode = "single";

    TR.d2.state.showCounts = true;
    TR.story2.pinCurrent();
    var on = TR.story2.items()[TR.story2.items().length - 1];
    assert(on.counts === true, "pinCurrent must capture showCounts=true");
    // The per-cell count is a <div class="fq">; the Base row always says "n="
    // so match the count cell specifically.
    var htmlOn = TR.render.tableHtml(TR.story2._modelFor(on), { showCounts: !!on.counts });
    assert(htmlOn.indexOf('class="fq"') !== -1, "pinned table shows count cells when captured");

    TR.d2.state.showCounts = false;
    TR.story2.pinCurrent();
    var off = TR.story2.items()[TR.story2.items().length - 1];
    assert(off.counts === false, "pinCurrent must capture showCounts=false");
    var htmlOff = TR.render.tableHtml(TR.story2._modelFor(off), { showCounts: !!off.counts });
    assert(htmlOff.indexOf('class="fq"') === -1, "pinned table omits count cells when off");
  } finally {
    TR.story2.items().length = saved.len;   // drop the pins this test added
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev; TR.d2._qIndex = saved.idx;
    Object.keys(saved.state).forEach(function (k) { TR.d2.state[k] = saved.state[k]; });
  }
});

run("chart colours follow the configured semantic palette", () => {
  // The data layer carries the resolved preset; categories colour semantically
  // (negative=red, positive=green) like the classic report — not a navy ramp.
  const pal = { negative: "#b85450", mod_negative: "#d4918e", neutral: "#c9a96e",
    mod_positive: "#7daa8c", positive: "#4a7c6f", dk_na: "#d1cdc7", other: "#c5c0b8" };
  const savedProj = TR.AGG.project;
  try {
    TR.AGG.project = Object.assign({}, savedProj, { chart_palette: pal });
    assert(TR.charts.semanticColour("Poor", 0, 3) === pal.negative, "Poor -> negative");
    assert(TR.charts.semanticColour("Good", 1, 3) === pal.mod_positive, "Good -> mod_positive");
    assert(TR.charts.semanticColour("Promoter", 2, 3) === pal.positive, "Promoter -> positive");
    assert(TR.charts.semanticColour("Don't know", 2, 3) === pal.dk_na, "DK -> dk_na");
    // unknown ordinal label -> negative->positive gradient (valid hex)
    assert(/^#[0-9a-f]{6}$/i.test(TR.charts.semanticColour("Box 9 - 10", 2, 3)),
      "gradient fallback returns a hex colour");
    var cols = TR.render.categoryColours([{ label: "Poor" }, { label: "Good" }]);
    assert(cols[0] === pal.negative, "categoryColours maps Poor -> negative");
  } finally {
    TR.AGG.project = savedProj;
  }
});

run("charts fall back to brand shades when no palette is configured", () => {
  // Older islands / the SACAP prototype carry no chart_palette -> the charts
  // must keep their brand-shade ramp (golden parity depends on this).
  const savedProj = TR.AGG.project;
  try {
    var p = Object.assign({}, savedProj); delete p.chart_palette; TR.AGG.project = p;
    assert(TR.charts.semanticColour("Poor", 0, 3) === null,
      "no palette -> null so the caller falls back");
    var cols = TR.render.categoryColours([{ label: "Poor" }, { label: "Good" }]);
    assert(/^#[0-9a-f]{6}$/i.test(cols[0]), "fallback returns a brand-shade hex");
  } finally {
    TR.AGG.project = savedProj;
  }
});

run("heatmap differentiates magnitude (73% clearly darker than 3%)", () => {
  // Regression: per-row normalisation made every cell in a single-column table
  // its own row max -> identical shade. Tint now scales with the absolute %.
  var model = { columns: [{ label: "Total", letter: "", base: 60, low: false }],
    rows: [
      { kind: "category", label: "High", cells: [{ pct: 73, n: 44, mean: null, sig: "" }] },
      { kind: "category", label: "Low",  cells: [{ pct: 3,  n: 2,  mean: null, sig: "" }] }
    ] };
  var html = TR.render.tableHtml(model, { heatmap: "heat" });
  var alphas = [];
  html.replace(/rgba\(\d+,\d+,\d+,([0-9.]+)\)/g, function (_, a) { alphas.push(parseFloat(a)); return _; });
  assert(alphas.length === 2, "two heated category cells, got " + alphas.length);
  assert(alphas[0] > alphas[1] + 0.2,
    "73% tint must read clearly darker than 3% (alphas " + alphas.join(", ") + ")");
});

run("tracking keeps the full current-wave name (date not truncated)", () => {
  // Regression: the current wave showed "Wave 25" while history showed
  // "Wave 22 - Oct 2024" — a /wave \d+/ extract dropped the configured date.
  const savedW = TR.AGG.project.wave;
  try {
    TR.AGG.project.wave = "Wave 25 - May 2026";
    assert(TR.trk.currentWaveLabel() === "Wave 25 - May 2026",
      "current wave label must keep the date, got: " + TR.trk.currentWaveLabel());
    TR.AGG.project.wave = "";   // no configured name -> sensible fallback, never blank
    assert(TR.trk.currentWaveLabel().length > 0, "empty wave still yields a label");
  } finally {
    TR.AGG.project.wave = savedW;
  }
});

run("Visualise header keeps the full question (wraps, no mid-word ellipsis)", () => {
  // Regression: clip(title, 60) truncated the question mid-word in the panel
  // header; the .heathead h3 wraps, so the full text should travel.
  var longTitle = "How would you rate your satisfaction with the merchandiser(s) in your store overall?";
  var sel = { metrics: [{ key: "Q38::Mean" }], segs: [{}] };
  var specs = [{ metric: { code: "Q38", title: longTitle, label: "Mean" }, segLabel: "Total" }];
  var title = TR.trkVis._visTitle(sel, specs);
  assert(title.indexOf(longTitle) !== -1, "full question text retained, got: " + title);
  assert(title.indexOf("…") === -1, "no ellipsis truncation");
});

run("native PPTX charts colour categories with the semantic palette + clean styling", () => {
  // Regression: native charts coloured from the series palette (navy bar /
  // brand-accent pie). They now use the same semantic per-category colours as
  // the pins, drop gridlines, and carry % data labels.
  const pal = { negative: "#b85450", mod_negative: "#d4918e", neutral: "#c9a96e",
    mod_positive: "#7daa8c", positive: "#4a7c6f", dk_na: "#d1cdc7", other: "#c5c0b8" };
  const savedProj = TR.AGG.project;
  try {
    TR.AGG.project = Object.assign({}, savedProj, { chart_palette: pal });
    var model = { code: "Q1", title: "Rate it", chartKind: "detail",
      columns: [{ label: "Total", letter: "", base: 60, low: false }],
      rows: [
        { kind: "category", label: "Poor", cells: [{ pct: 20, n: 12, mean: null, sig: "" }] },
        { kind: "category", label: "Excellent", cells: [{ pct: 80, n: 48, mean: null, sig: "" }] }
      ] };
    var bar = TR.exporter.buildChart(model, "bar", [0]);
    assert(bar.xml.indexOf("B85450") !== -1, "Poor bar -> negative (red) palette colour");
    assert(bar.xml.indexOf("4A7C6F") !== -1, "Excellent bar -> positive (green) palette colour");
    assert(bar.xml.indexOf("<c:dLbls>") !== -1, "bar carries % data labels");
    assert(bar.xml.indexOf("majorGridlines") === -1, "gridlines removed");
    var pie = TR.exporter.buildChart(model, "pie", [0]);
    assert(pie.xml.indexOf("B85450") !== -1 && pie.xml.indexOf("4A7C6F") !== -1,
      "pie slices use the semantic palette");
  } finally {
    TR.AGG.project = savedProj;
  }
});

run("PPTX table keeps the report formatting (style id, brand header, accent stat row)", () => {
  // Regression: with no tableStyleId PowerPoint dropped the cell fills and
  // showed a blank default table.
  const m = TR.model.forQuestion("Q008", TR.AGG.banner_groups[0].id, []);
  const slide = TR.exporter.slideForModel(m, "", { chart: false, table: true, insight: false });
  assert(slide.xml.indexOf("2D5ABB26-0587-4C30-8999-92F81FD0307C") !== -1,
    "No-Style-No-Grid table style id present so PowerPoint honours the fills");
  assert(slide.xml.indexOf(TR.charts.brandOf().replace("#", "").toUpperCase()) !== -1,
    "brand-coloured header fill present");
  assert(slide.xml.indexOf("CC9900") !== -1, "stat-row gold accent edge present");
});

run("tracking view pins on a Total-only report (no banner_groups)", () => {
  // Regression: pinTrackingView (and the composite-exhibit builder) read
  // banner_groups[0].id unguarded, so on a no-banner survey (e.g. CCS) the Pin
  // click threw and nothing pinned at all.
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex,
    len: TR.story2.items().length };
  try {
    TR.AGG = { schema_version: 2,
      project: { name: "T", wave: "W25", low_base_threshold: 30, tracking: { enabled: true } },
      columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
      banner_groups: [], categories: ["c"],
      questions: [{ code: "Q1", title: "Q1", category: "c", type: "scale",
        bases: [{ n: 60, low: false }],
        rows: [{ kind: "mean", label: "Mean", pct: [7.6], n: [null], sig: [""] }] }] };
    TR.MICRO = null; TR.PREV = null; TR.d2._qIndex = null;
    TR.story2.pinTrackingView({ title: "Q1 trend", ci: false, qs: ["Q1"],
      series: [{ code: "Q1", ri: 0, label: "Mean", seg: null }], annotations: [], note: "" },
      { trend: true, insight: true });
    var item = TR.story2.items()[TR.story2.items().length - 1];
    assert(item && item.kind === "exhibit", "tracking view pinned as an exhibit item");
    assert(item.banner === "", "no-banner report resolves to the Total banner");
    assert(TR.exhibit.slide(item) !== null, "the pinned exhibit produces an export slide");
  } finally {
    TR.story2.items().length = saved.len;
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev; TR.d2._qIndex = saved.idx;
  }
});

run("composite-exhibit builder resolves a custom banner without crashing (CCS)", () => {
  // Regression: addExhibit recorded TR.AGG.banner_groups[0].id unguarded, so on
  // a Total-only survey (e.g. CCS) with a custom banner active, "Add exhibit"
  // threw and nothing pinned. pinBanner() must resolve safely in every case.
  const savedAgg = TR.AGG, savedBanner = TR.d2.state.banner;
  try {
    TR.AGG = { banner_groups: [] };           // no preset banners (CCS)
    TR.d2.state.banner = "custom:Q1:net";     // the stuck custom-banner state
    assert(TR.story2._pinBanner() === "",
      "custom banner resolves to the Total column on a no-banner survey");
    TR.AGG = { banner_groups: [{ id: "REGION", name: "Region" }] };
    assert(TR.story2._pinBanner() === "REGION",
      "custom banner resolves to the first preset when one exists");
    TR.d2.state.banner = "REGION";
    assert(TR.story2._pinBanner() === "REGION", "a concrete banner passes through");
  } finally {
    TR.AGG = savedAgg; TR.d2.state.banner = savedBanner;
  }
});

run("Total-only survey offers a Total banner tab so a custom banner can be cleared", () => {
  // Regression: with no preset banner_groups, a custom banner left no other tab
  // to click, so it could never be switched off (CCS). A "Total" tab restores
  // the Total column; surveys that already have presets don't get an extra one.
  const savedAgg = TR.AGG, savedBanner = TR.d2.state.banner, savedIdx = TR.d2._qIndex;
  try {
    TR.AGG = { banner_groups: [],
      questions: [{ code: "Q1", title: "Q1", category: "c", rows: [] }] };
    TR.d2._qIndex = null;
    TR.d2.state.banner = "";
    assert(/data-banner=""/.test(TR.cards2._bannerTabsHtml()),
      "no-banner survey shows a Total tab");
    TR.d2.state.banner = "custom:Q1:net";
    const custom = TR.cards2._bannerTabsHtml();
    assert(/data-banner=""/.test(custom) && /class="btab on custom"/.test(custom),
      "with a custom banner active, both the Total tab and the custom tab show");
    TR.AGG = { banner_groups: [{ id: "REGION", name: "Region" }], questions: [] };
    TR.d2._qIndex = null;
    TR.d2.state.banner = "REGION";
    assert(!/data-banner=""/.test(TR.cards2._bannerTabsHtml()),
      "surveys with preset banners do not get an extra Total tab");
  } finally {
    TR.AGG = savedAgg; TR.d2.state.banner = savedBanner; TR.d2._qIndex = savedIdx;
  }
});

run("audience filter suppresses wave deltas/trend (prior waves are full-sample totals)", () => {
  // Regression: prior waves are published full-sample Totals with no microdata
  // to filter, so under an audience filter a wave delta compared filtered-now
  // against unfiltered-prior — misleading. A filtered model must read untracked.
  const banner = TR.AGG.banner_groups[0].id;
  const tracked = TR.AGG.questions.find((x) => {
    const m = TR.model.forQuestion(x.code, banner, []);
    return m && m.prevWave && m.rows.some((r) => r.delta && r.waves);
  });
  assert(tracked, "fixture has a tracked question with deltas + trend");
  const plain = TR.model.forQuestion(tracked.code, banner, []);
  assert(plain.prevWave && plain.rows.some((r) => r.delta && r.waves),
    "unfiltered tracked model keeps its wave deltas + trend");
  const fq = TR.AGG.questions.find((x) => TR.d2.catRows(x).length >= 1);
  const filtered = TR.model.forQuestion(tracked.code, banner,
    [{ q: fq.code, rows: [TR.d2.catRows(fq)[0].index] }]);
  assert(filtered.filtered === true, "filtered model is flagged");
  assert(filtered.prevWave === null, "filtered model reads as untracked (no prevWave)");
  assert(filtered.rows.every((r) => !r.delta && !r.waves),
    "filtered model carries no wave deltas or trend series");
});

run("per-segment prior-wave trends: published segment values flow through the wave API", () => {
  // Phase 1a (segment wave trends): the renderer already reads per-segment hooks
  // (seg_stats / bases) but the writer never populated them. This locks the
  // island schema and proves waves.series(q,row,ri,seg) returns the published
  // per-segment values + bases for prior waves (Total stays seg = null).
  const saved = { agg: TR.AGG, prev: TR.PREV, micro: TR.MICRO, idx: TR.d2._qIndex };
  try {
    TR.AGG = { schema_version: 2,
      project: { name: "Seg", low_base_threshold: 30, tracking: { enabled: true } },
      columns: [
        { key: "TOTAL::Total", group: "total", label: "Total", letter: "" },
        { key: "REGION::WC", group: "Region", label: "Western Cape", letter: "a" },
        { key: "REGION::GP", group: "Region", label: "Gauteng", letter: "b" }],
      banner_groups: [{ id: "Region", name: "Region" }], categories: ["c"],
      questions: [{ code: "Q1", title: "Overall satisfaction", category: "c", type: "scale",
        bases: [{ n: 200, low: false }, { n: 90, low: false }, { n: 80, low: false }],
        rows: [{ kind: "mean", label: "Mean", pct: [7.6, 7.4, 7.8],
          n: [null, null, null], sig: ["", "", ""] }] }] };
    TR.MICRO = null; TR.d2._qIndex = null;
    // a prior-wave question payload carrying Total + per-segment means and bases
    const wq = (mean, wc, gp, base, wcN, gpN) => ({
      match_key: "overall satisfaction", title: "Overall satisfaction", base: base,
      stats: { mean: mean },
      seg_stats: { "western cape": { mean: wc }, "gauteng": { mean: gp } },
      bases: { "western cape": wcN, "gauteng": gpN }, rows: {} });
    const segs = [{ norm: "western cape" }, { norm: "gauteng" }];
    TR.PREV = { waves: [
      { wave: "W1", year: 2024, segments: segs, questions: [wq(7.0, 6.8, 7.2, 180, 85, 75)] },
      { wave: "W2", year: 2025, segments: segs, questions: [wq(7.3, 7.1, 7.5, 190, 88, 78)] }] };
    TR.waves.reset();
    const q = TR.AGG.questions[0], row = q.rows[0];
    const segNorms = TR.waves.segments().map((s) => s.norm);
    assert(segNorms.includes("western cape") && segNorms.includes("gauteng"),
      "Region categories recognised as tracked segments: " + segNorms.join(","));
    const tot = TR.waves.series(q, row, 0, null);
    assert(tot.length === 2 && tot[0].value === 7.0 && tot[1].value === 7.3 && tot[1].base === 190,
      "Total series uses the published totals + total bases");
    const wc = TR.waves.series(q, row, 0, "western cape");
    assert(wc.length === 2 && wc[0].value === 6.8 && wc[1].value === 7.1,
      "Western Cape series uses the published segment means");
    assert(wc[0].base === 85 && wc[1].base === 88, "Western Cape series uses the segment bases");
    const gp = TR.waves.series(q, row, 0, "gauteng");
    assert(gp[1].value === 7.5 && gp[1].base === 78, "Gauteng series is distinct from Western Cape");
  } finally {
    TR.AGG = saved.agg; TR.PREV = saved.prev; TR.MICRO = saved.micro; TR.d2._qIndex = saved.idx;
    TR.waves.reset();
  }
});

run("per-segment prior-wave PROPORTIONS flow through the wave API", () => {
  // Phase 2 (proportions): a category/proportion row trends per segment off the
  // published-distribution path rows[norm(label)].pct (Total) / .seg[segKey].
  const saved = { agg: TR.AGG, prev: TR.PREV, micro: TR.MICRO, idx: TR.d2._qIndex };
  try {
    TR.AGG = { schema_version: 2,
      project: { name: "Seg", low_base_threshold: 30, tracking: { enabled: true } },
      columns: [
        { key: "TOTAL::Total", group: "total", label: "Total", letter: "" },
        { key: "REGION::WC", group: "Region", label: "Western Cape", letter: "a" },
        { key: "REGION::GP", group: "Region", label: "Gauteng", letter: "b" }],
      banner_groups: [{ id: "Region", name: "Region" }], categories: ["c"],
      questions: [{ code: "Q1", title: "Channel used", category: "c", type: "single",
        bases: [{ n: 200, low: false }, { n: 90, low: false }, { n: 80, low: false }],
        rows: [{ kind: "category", label: "Online", pct: [40, 50, 35] },
          { kind: "category", label: "In-store", pct: [60, 50, 65] }] }] };
    TR.MICRO = null; TR.d2._qIndex = null;
    const wq = (onTot, onWC, onGP, base, wcN, gpN) => ({
      match_key: "channel used", title: "Channel used", base: base,
      bases: { "western cape": wcN, "gauteng": gpN },
      rows: {
        "online": { pct: onTot, n: Math.round(onTot / 100 * base),
          seg: { "western cape": onWC, "gauteng": onGP } },
        "instore": { pct: 100 - onTot,
          seg: { "western cape": 100 - onWC, "gauteng": 100 - onGP } } } });
    const segs = [{ norm: "western cape" }, { norm: "gauteng" }];
    TR.PREV = { waves: [
      { wave: "W1", year: 2024, segments: segs, questions: [wq(40, 50, 35, 180, 85, 75)] },
      { wave: "W2", year: 2025, segments: segs, questions: [wq(45, 55, 38, 190, 88, 78)] }] };
    TR.waves.reset();
    const q = TR.AGG.questions[0], online = q.rows[0];
    const tot = TR.waves.series(q, online, 0, null);
    assert(tot.length === 2 && tot[0].value === 40 && tot[1].value === 45 && tot[1].base === 190,
      "Total 'Online' proportion trends from rows[].pct + total base");
    const wc = TR.waves.series(q, online, 0, "western cape");
    assert(wc[0].value === 50 && wc[1].value === 55 && wc[0].base === 85,
      "Western Cape 'Online' proportion trends from rows[].seg + segment base");
    const gp = TR.waves.series(q, online, 0, "gauteng");
    assert(gp[1].value === 38 && gp[1].base === 78, "Gauteng proportion series is distinct");
  } finally {
    TR.AGG = saved.agg; TR.PREV = saved.prev; TR.MICRO = saved.micro; TR.d2._qIndex = saved.idx;
    TR.waves.reset();
  }
});

run("per-segment mean trend carries a stored SD so significance can be tested", () => {
  // Phase 2 (significance): a stored seg_stats[seg].sd lets the renderer's Welch
  // test flag a wave-on-wave move on adequate base, without the distribution.
  const saved = { agg: TR.AGG, prev: TR.PREV, micro: TR.MICRO, idx: TR.d2._qIndex };
  try {
    TR.AGG = { schema_version: 2,
      project: { name: "Seg", low_base_threshold: 30, tracking: { enabled: true } },
      columns: [
        { key: "TOTAL::Total", group: "total", label: "Total", letter: "" },
        { key: "REGION::WC", group: "Region", label: "Western Cape", letter: "a" }],
      banner_groups: [{ id: "Region", name: "Region" }], categories: ["c"],
      questions: [{ code: "Q1", title: "Overall satisfaction", category: "c", type: "scale",
        bases: [{ n: 200, low: false }, { n: 100, low: false }],
        rows: [{ kind: "mean", label: "Mean", pct: [7.0, 7.0], n: [null, null], sig: ["", ""] }] }] };
    TR.MICRO = null; TR.d2._qIndex = null;
    const wq = (wcMean, base) => ({
      match_key: "overall satisfaction", title: "Overall satisfaction", base: base,
      stats: { mean: wcMean, sd: 1.0 }, seg_stats: { "western cape": { mean: wcMean, sd: 1.0 } },
      bases: { "western cape": base } });
    const segs = [{ norm: "western cape" }];
    TR.PREV = { waves: [
      { wave: "W1", year: 2024, segments: segs, questions: [wq(6.0, 100)] },
      { wave: "W2", year: 2025, segments: segs, questions: [wq(7.5, 100)] }] };
    TR.waves.reset();
    const q = TR.AGG.questions[0], row = q.rows[0];
    const wc = TR.waves.series(q, row, 0, "western cape");
    assert(wc.length === 2 && wc[0].sd === 1.0 && wc[1].sd === 1.0,
      "series carries the stored segment SD");
    const cells = TR.waves.cellsFor(wc, false, "95");
    assert(cells[1].sig_prev === true,
      "a large WC mean move (6.0->7.5, sd 1.0, n 100) flags significant");
    TR.PREV.waves[1].questions[0] = wq(6.05, 100);
    TR.waves.reset();
    const trivial = TR.waves.cellsFor(TR.waves.series(q, row, 0, "western cape"), false, "95");
    assert(trivial[1].sig_prev === false, "a trivial move (6.0->6.05) is not significant");
  } finally {
    TR.AGG = saved.agg; TR.PREV = saved.prev; TR.MICRO = saved.micro; TR.d2._qIndex = saved.idx;
    TR.waves.reset();
  }
});

run("Total-only island degrades gracefully — Total trends, no segments", () => {
  // Robustness: a tracker with no segment breakouts (computed Total only, no
  // seg_stats/segments). Total trends from stats.mean; segment queries are empty.
  const saved = { agg: TR.AGG, prev: TR.PREV, micro: TR.MICRO, idx: TR.d2._qIndex };
  try {
    TR.AGG = { schema_version: 2,
      project: { name: "T", low_base_threshold: 30, tracking: { enabled: true } },
      columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
      banner_groups: [], categories: ["c"],
      questions: [{ code: "Q1", title: "Overall satisfaction", category: "c", type: "scale",
        bases: [{ n: 200, low: false }],
        rows: [{ kind: "mean", label: "Mean", pct: [7.0], n: [null], sig: [""] }] }] };
    TR.MICRO = null; TR.d2._qIndex = null;
    const wq = (mean, base) => ({ match_key: "overall satisfaction",
      title: "Overall satisfaction", base: base, stats: { mean: mean } });
    TR.PREV = { waves: [
      { wave: "W1", year: 2024, segments: [], questions: [wq(7.0, 180)] },
      { wave: "W2", year: 2025, segments: [], questions: [wq(7.3, 190)] }] };
    TR.waves.reset();
    const q = TR.AGG.questions[0], row = q.rows[0];
    assert(TR.waves.segments().length === 0, "no segments offered when none are published");
    const tot = TR.waves.series(q, row, 0, null);
    assert(tot.length === 2 && tot[1].value === 7.3 && tot[1].base === 190,
      "Total trend works from stats.mean even with no per-respondent scores");
    const none = TR.waves.series(q, row, 0, "western cape");
    assert(none.length === 0, "a segment query on a Total-only island yields nothing (no crash)");
  } finally {
    TR.AGG = saved.agg; TR.PREV = saved.prev; TR.MICRO = saved.micro; TR.d2._qIndex = saved.idx;
    TR.waves.reset();
  }
});

run("PPTX image deck: PNG slides pack into a structurally valid deck (python)", () => {
  // The "download as PNGs" path renders each card to a PNG and packs it as a
  // full-slide image. Validates imageSlide + the packer's media-part support.
  const png = Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
    "base64");
  const slide = TR.exporter.imageSlide({ bytes: png, w: 660, h: 400 });
  assert(slide.images && slide.images.length === 1, "slide declares one image");
  assert(slide.xml.indexOf("<p:pic>") !== -1 && slide.xml.indexOf('r:embed="rId2"') !== -1,
    "slide has a picture referencing rId2");
  const bytes = TR.pptx.package([TR.exporter.titleSlide(1), slide], { project: TR.AGG.project });
  // the PNG media part must actually be embedded (the zip names it) — the python
  // check below does not verify the pic->media rel resolves.
  assert(new TextDecoder("latin1").decode(bytes).indexOf("ppt/media/image1.png") !== -1,
    "image media part embedded in the package");
  const tmp = path.join(BASE, "tests", "tmp");
  mkdirSync(tmp, { recursive: true });
  const out = path.join(tmp, "v2_imagedeck.pptx");
  writeFileSync(out, bytes);
  const report = execFileSync("python3",
    [path.join(path.dirname(BASE), "tests", "verify_pptx.py"), out, "--no-table"],
    { encoding: "utf8" });
  assert(report.startsWith("OK"), report);
});

run("export matrix carries the wave delta (export tables render it)", () => {
  // The PPTX tables (image svgTable + editable tableFrame) colour the ▼/▲ chip
  // from this — it must survive into the matrix the exports consume.
  const m = TR.model.forQuestion("Q008", TR.AGG.banner_groups[0].id, []);
  const mat = TR.render.matrix(m);
  var d = mat.body.find((r) => r.delta && r.delta.text);
  assert(d, "at least one row carries a delta chip");
  assert(typeof d.delta.up === "boolean" && /[▲▼]/.test(d.delta.text),
    "delta has a direction + arrow");
  // editable table emits the delta as a second coloured run
  const slide = TR.exporter.slideForModel(m, "", { chart: false, table: true, insight: false });
  assert(slide.xml.indexOf("1B6E53") !== -1 || slide.xml.indexOf("B3372F") !== -1,
    "native table renders a green/red delta run");
});

run("composite exhibit (2+ questions) scorecards instead of overlapping trend lines", () => {
  const qs = TR.AGG.questions.filter((q) => q.type === "scale" &&
    q.rows.some((r) => r.kind === "mean")).slice(0, 3);
  const banner = TR.AGG.banner_groups[0].id;
  const series = qs.map((q) => {
    const m = TR.model.forQuestion(q.code, banner, []);
    return { code: q.code, ri: m.rows.findIndex((r) => r.kind === "mean"), label: "Mean", seg: null };
  });
  const len = TR.story2.items().length;
  try {
    TR.story2.pinTrackingView({ title: "3 metrics", ci: false, qs: qs.map((q) => q.code),
      series: series, annotations: [], note: "" }, { trend: true, table: true });
    const item = TR.story2.items()[TR.story2.items().length - 1];
    const models = TR.exhibit.models(item);
    assert(TR.exhibit.isComposite(item, models), "3 distinct questions -> composite");
    var rows = TR.exhibit.scorecardRows(item, models);
    assert(rows.length === 3 && rows.every((r) => r.code && Array.isArray(r.vals) && r.latest != null),
      "a scorecard row per metric, with values");
    var html = TR.exhibit.panelsHtml(item);
    assert(html.indexOf("ex-scorecard") !== -1, "composite panel uses the scorecard");
    assert(html.indexOf("ex-chart") === -1, "no overlapping trend-line chart in a composite");
    var slide = TR.exhibit.slide(item);
    assert(slide.charts.length === 0 && slide.xml.indexOf("<a:tbl>") !== -1,
      "editable composite is the wave table, no native charts");
  } finally {
    TR.story2.items().length = len;
  }
});

run("dashboard cards carry a value-vs-scale gauge bar and a wave sparkline", () => {
  const savedBanner = TR.d2.state.banner;
  let cap = "";
  const host = { set innerHTML(v) { cap = v; }, get innerHTML() { return cap; },
    querySelectorAll() { return { forEach() {} }; }, querySelector() { return null; } };
  try {
    TR.d2.state.banner = TR.AGG.banner_groups[0].id;
    TR.views.dashboard(host);
    var cards = (cap.match(/class="gauge"/g) || []).length;
    var bars = (cap.match(/class="gbar"/g) || []).length;
    var sparks = (cap.match(/class="gspark"/g) || []).length;
    assert(cards > 0 && bars === cards, "every gauge card has a gauge bar (" + bars + "/" + cards + ")");
    assert(sparks > 0, "tracked cards carry a wave sparkline (" + sparks + ")");
  } finally {
    TR.d2.state.banner = savedBanner;
  }
});

run("table magnitude modes: bars (default) / heat tint / off", () => {
  var model = { columns: [{ label: "Total", letter: "", base: 60, low: false }],
    rows: [{ kind: "category", label: "High", cells: [{ pct: 73, n: 44, mean: null, sig: "" }] }] };
  var bars = TR.render.tableHtml(model, { heatmap: "bars" });
  assert(bars.indexOf('class="dbf"') !== -1 && bars.indexOf("width:73%") !== -1,
    "bars mode renders a 73% data bar");
  assert(bars.indexOf("rgba(") === -1, "bars mode has no background tint");
  var heat = TR.render.tableHtml(model, { heatmap: "heat" });
  assert(heat.indexOf("rgba(") !== -1 && heat.indexOf('class="dbf"') === -1,
    "heat mode tints the cell, no bar");
  var off = TR.render.tableHtml(model, { heatmap: "off" });
  assert(off.indexOf("rgba(") === -1 && off.indexOf('class="dbf"') === -1,
    "off mode shows neither");
  assert(TR.render.tableHtml(model, { heatmap: true }).indexOf('class="dbf"') !== -1,
    "older pins (heatmap:true) fall back to the bars default");
});

run("weighted recompute: weighted %, Kish effective base, weighted mean (known answers)", () => {
  // 4 respondents, weights [3,1,1,1].
  //   Q1 single Yes/No, answers [0,0,1,1]: Yes Σw = 3+1 = 4, No = 1+1 = 2,
  //     wbase = 6 -> Yes 66.667%. Kish n_eff = 6^2 / (9+1+1+1) = 36/12 = 3.
  //   Q2 scale rows 1/2/3 + Mean, index_scores {1,2,3}, answers [0,2,2,1]:
  //     weighted mean = (3*1 + 1*3 + 1*3 + 1*2) / 6 = 11/6.
  const agg = { schema_version: 2,
    project: { name: "W", low_base_threshold: 1, alpha: 0.05, tracking: { enabled: false } },
    columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
    banner_groups: [], categories: ["c"],
    questions: [
      { code: "Q1", title: "Q1", category: "c", type: "single", bases: [{ n: 4, low: false }],
        rows: [{ kind: "category", label: "Yes", pct: [66.7], n: [4], sig: [""] },
               { kind: "category", label: "No", pct: [33.3], n: [2], sig: [""] }] },
      { code: "Q2", title: "Q2", category: "c", type: "scale", bases: [{ n: 4, low: false }],
        index_scores: { "1": 1, "2": 2, "3": 3 },
        rows: [{ kind: "category", label: "1", pct: [25], n: [1], sig: [""] },
               { kind: "category", label: "2", pct: [25], n: [1], sig: [""] },
               { kind: "category", label: "3", pct: [50], n: [2], sig: [""] },
               { kind: "mean", label: "Mean", pct: [2], n: [null], sig: [""] }] }
    ] };
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex };
  try {
    TR.AGG = agg; TR.PREV = null; TR.d2._qIndex = null;
    TR.MICRO = { n: 4, answers: { Q1: [0, 0, 1, 1], Q2: [0, 2, 2, 1] }, banner_vars: {}, weights: [3, 1, 1, 1] };
    const total = [{ label: "Total", member: null }], mask = new Uint8Array(4).fill(1);
    const t = TR.stats.tabulate(agg.questions[0], total, mask)[0];
    assert(t.base === 4, "unweighted base 4");
    assert(t.wbase === 6, "weighted base Σw = 6");
    assert(t.counts[0] === 4, "Yes weighted count 4");
    assert(Math.abs(t.effBase - 3) < 1e-9, "Kish effBase 36/12 = 3");
    assert(Math.abs(TR.stats.pct(t, 0) - (4 / 6 * 100)) < 1e-9, "Yes weighted % 66.667");
    const m = TR.stats.indexMeans(agg.questions[1], total, mask)[0];
    assert(Math.abs(m.mean - 11 / 6) < 1e-9, "Q2 weighted mean 11/6");
    assert(Math.abs(m.k - 3) < 1e-9, "Q2 mean effBase 3");
    // Invariant: with no weights, wbase === base === effBase === count
    TR.MICRO = { n: 4, answers: { Q1: [0, 0, 1, 1], Q2: [0, 2, 2, 1] }, banner_vars: {} };
    const u = TR.stats.tabulate(agg.questions[0], total, mask)[0];
    assert(u.base === u.wbase && u.wbase === u.effBase && u.effBase === 4,
      "unweighted: base = wbase = effBase = 4");
  } finally {
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev; TR.d2._qIndex = saved.idx;
  }
});

run("microdata scores: means recompute from per-respondent scores (hidden categories + NPS)", () => {
  // Q1 rating publishes ONLY a Mean (all categories hidden — no category rows);
  //   the per-respondent scores [4,7,9] still give mean (4+7+9)/3 = 6.6667.
  // Q2 NPS scores via ±100 mapping [100,100,-100] -> (100+100-100)/3 = 33.33.
  const agg = { schema_version: 2,
    project: { name: "S", low_base_threshold: 1, alpha: 0.05, tracking: { enabled: false } },
    columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
    banner_groups: [], categories: ["c"],
    questions: [
      { code: "Q1", title: "Q1", category: "c", type: "scale", bases: [{ n: 3, low: false }],
        rows: [{ kind: "mean", label: "Mean", pct: [6.7], n: [null], sig: [""] }] },
      { code: "Q2", title: "Q2", category: "c", type: "nps", bases: [{ n: 3, low: false }],
        rows: [{ kind: "mean", label: "NPS Score", pct: [33], n: [null], sig: [""] }] }
    ] };
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex };
  try {
    TR.AGG = agg; TR.PREV = null; TR.d2._qIndex = null;
    TR.MICRO = { n: 3, answers: { Q1: [null, null, null], Q2: [null, null, null] },
      banner_vars: {}, weights: [1, 1, 1], scores: { Q1: [4, 7, 9], Q2: [100, 100, -100] } };
    const total = [{ label: "Total", member: null }], mask = new Uint8Array(3).fill(1);
    const m1 = TR.stats.indexMeans(agg.questions[0], total, mask)[0];
    assert(Math.abs(m1.mean - 20 / 3) < 1e-9, "rating mean from scores = 6.667 (no category rows)");
    const m2 = TR.stats.indexMeans(agg.questions[1], total, mask)[0];
    assert(Math.abs(m2.mean - 100 / 3) < 1e-9, "NPS from ±100 scores = 33.33");
  } finally {
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev; TR.d2._qIndex = saved.idx;
  }
});

run("weighted wave trend + canonical-key linkage (subprocess)", () => {
  // Spawned in a fresh VM (the wave engine caches indexes per load, so a custom
  // TR.PREV must not pollute the shared SACAP wave tests).
  const res = spawnSync("node", [path.join(BASE, "tests", "wave_trends.mjs")],
    { encoding: "utf8" });
  assert(res.status === 0, "wave trends failed:\n" + res.stdout);
});

run("Report tab pre-fills Background / About from config report_meta (subprocess)", () => {
  // Spawned fresh: report.store() memoises a per-page cache, so the override /
  // cleared-field cases need an isolated VM each, mirroring one page load.
  const res = spawnSync("node", [path.join(BASE, "tests", "report_prefill.mjs")],
    { encoding: "utf8" });
  assert(res.status === 0, "report pre-fill failed:\n" + res.stdout);
});

run("Tracking dual-significance: soft (80%) flagging in dual mode (subprocess)", () => {
  const res = spawnSync("node", [path.join(BASE, "tests", "soft_sig.mjs")],
    { encoding: "utf8" });
  assert(res.status === 0, "soft-sig flagging failed:\n" + res.stdout);
});

run("Tracking Summary: 'Nearly significant' cards render in dual mode (subprocess)", () => {
  const res = spawnSync("node", [path.join(BASE, "tests", "tracking_render.mjs")],
    { encoding: "utf8" });
  assert(res.status === 0, "tracking render failed:\n" + res.stdout);
});

run("AI insights: read-only callouts / exec summary / methodology render (subprocess)", () => {
  const res = spawnSync("node", [path.join(BASE, "tests", "ai_render.mjs")],
    { encoding: "utf8" });
  assert(res.status === 0, "AI insights render failed:\n" + res.stdout);
});

run("box-category NETs recompute from per-respondent box membership", () => {
  // A hidden-scale rating that publishes only its boxes: rows Low(0) / High(1) /
  // NET POSITIVE(2) / Mean(3). boxes [0,1,0,1,null] -> Low 2/4=50%, High 50%,
  // NET POSITIVE = High - Low = 0. Recomputes with no displayed category rows.
  const agg = { schema_version: 2,
    project: { name: "B", low_base_threshold: 1, alpha: 0.05, tracking: { enabled: false } },
    columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
    banner_groups: [], categories: ["c"],
    questions: [{ code: "QB", title: "QB", category: "c", type: "scale",
      bases: [{ n: 4, low: false }],
      net_diffs: { "2": { plus: 1, minus: 0 } },
      rows: [{ kind: "net", label: "Low", pct: [50], n: [null], sig: [""] },
             { kind: "net", label: "High", pct: [50], n: [null], sig: [""] },
             { kind: "net", label: "NET POSITIVE (High - Low)", pct: [0], n: [null], sig: [""] },
             { kind: "mean", label: "Mean", pct: [3], n: [null], sig: [""] }] }] };
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex };
  try {
    TR.AGG = agg; TR.PREV = null; TR.d2._qIndex = null;
    TR.MICRO = { n: 4, answers: { QB: [null, null, null, null] }, banner_vars: {},
      weights: [1, 1, 1, 1], boxes: { QB: [0, 1, 0, 1] } };
    const m = TR.model.forQuestion("QB", "custom:QB", []);   // force a computed view
    const tot = m.columns.findIndex(c => c.label === "Total");
    const byLabel = (l) => m.rows.find(r => r.label === l).cells[tot].pct;
    assert(Math.abs(byLabel("Low") - 50) < 1e-9, "Low box = 50%");
    assert(Math.abs(byLabel("High") - 50) < 1e-9, "High box = 50%");
    assert(Math.abs(byLabel("NET POSITIVE (High - Low)") - 0) < 1e-9, "NET POSITIVE = High - Low = 0");
  } finally {
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev; TR.d2._qIndex = saved.idx;
  }
});

run("hidden-scale box-only question: filtered base counts box members, not null answers", () => {
  // The CCPB regression. A satisfaction question whose 1-10 scale is hidden
  // publishes only its boxes, so TR.MICRO.answers[code] is all null and the
  // respondents live in TR.MICRO.boxes. Under a filter the box cells recompute
  // correctly, but the displayed base used to read 0 (tabulate skipped every
  // null answer) -> "COMPUTED · n=0 / low base" beside real box counts. The
  // base must fall back to box membership so it matches the box-row counts.
  const agg = { schema_version: 2,
    project: { name: "B", low_base_threshold: 30, alpha: 0.05, tracking: { enabled: false } },
    columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
    banner_groups: [], categories: ["c"],
    questions: [{ code: "QS", title: "QS", category: "c", type: "scale",
      bases: [{ n: 5, low: false }],
      rows: [{ kind: "net", label: "Low", pct: [40], n: [null], sig: [""] },
             { kind: "net", label: "High", pct: [60], n: [null], sig: [""] },
             { kind: "mean", label: "Mean", pct: [7], n: [null], sig: [""] }] }] };
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex };
  try {
    TR.AGG = agg; TR.PREV = null; TR.d2._qIndex = null;
    // 5 respondents, ALL answered (box set), raw answers all null. boxes:
    // High(1)=resp 0,1,3 ; Low(0)=resp 2,4. group G: 0=resp 0,1,2 ; 1=resp 3,4.
    TR.MICRO = { n: 5, answers: { QS: [null, null, null, null, null] },
      banner_vars: { G: [0, 0, 0, 1, 1] }, weights: [1, 1, 1, 1, 1],
      boxes: { QS: [1, 1, 0, 1, 0] } };
    // Forced compute, unfiltered: base must be all 5 box members (not 0).
    const m = TR.model.forQuestion("QS", "custom:QS", []);
    assert(m.source === "computed", "custom banner forces a computed view");
    assert(m.columns[0].base === 5, "unfiltered box-only base = 5 (got " + m.columns[0].base + ")");
    // Filter G=0 -> respondents 0,1,2: base 3, High = 2/3, and the box-row
    // counts must sum back to the base (the heart of the bug).
    const mf = TR.model.forQuestion("QS", null, [{ q: "G", rows: [0] }]);
    assert(mf.source === "computed", "filter forces a computed view");
    assert(mf.columns[0].base === 3, "filtered base = masked box members = 3 (got " + mf.columns[0].base + ")");
    const high = mf.rows.find((r) => r.label === "High").cells[0];
    const low = mf.rows.find((r) => r.label === "Low").cells[0];
    assert(high.n === 2 && low.n === 1, "filtered box counts High=2 Low=1 (got " + high.n + "/" + low.n + ")");
    assert(low.n + high.n === mf.columns[0].base, "box-row counts sum to the base");
    assert(Math.abs(high.pct - 200 / 3) < 1e-9, "filtered High = 2/3 (got " + high.pct + ")");
  } finally {
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev; TR.d2._qIndex = saved.idx;
  }
});

run("derived-metric question (no microdata) reports 'not recomputable', not a 0 base", () => {
  // Ranking / derived questions carry NO per-respondent data (answers all null,
  // no boxes, no scores). A filtered or custom-banner recompute must flag the
  // model notRecomputable and null the base — never "COMPUTED · n=0 / low base"
  // against a real published base (the CCPB Q73/Q76 case found while fixing the
  // box-only base bug above).
  const agg = { schema_version: 2,
    project: { name: "B", low_base_threshold: 30, alpha: 0.05, tracking: { enabled: false } },
    columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
    banner_groups: [], categories: ["c"],
    questions: [{ code: "QR", title: "QR", category: "c", type: "single",
      bases: [{ n: 200, low: false }],
      rows: [{ kind: "category", label: "Stock - % Ranked 1st", pct: [30], n: [null], sig: [""] },
             { kind: "mean", label: "Stock - Mean Rank", pct: [2.1], n: [null], sig: [""] }] }] };
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex };
  try {
    TR.AGG = agg; TR.PREV = null; TR.d2._qIndex = null;
    TR.MICRO = { n: 3, answers: { QR: [null, null, null] },
      banner_vars: { G: [0, 0, 1] }, weights: [1, 1, 1] };   // no boxes, no scores
    const m = TR.model.forQuestion("QR", null, [{ q: "G", rows: [0] }]);
    assert(m.source === "computed", "filter forces a computed view");
    assert(m.notRecomputable === true, "derived-metric question flagged notRecomputable");
    assert(m.columns[0].base === null, "base is null (renders '–'), not 0 (got " + m.columns[0].base + ")");
    assert(m.columns[0].low === false, "no false low-base flag on a null base");
    // Give the same question box membership and it becomes recomputable again.
    TR.MICRO.boxes = { QR: [0, 1, 0] };
    const m2 = TR.model.forQuestion("QR", null, [{ q: "G", rows: [0] }]);
    assert(m2.notRecomputable === false, "box membership makes it recomputable");
    assert(m2.columns[0].base === 2, "recomputable base counts masked box members (got " + m2.columns[0].base + ")");
  } finally {
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev; TR.d2._qIndex = saved.idx;
  }
});

run("Differences view: findings compare the group with THE REST, reconciling to overall", () => {
  // Each card's headline baseline is "everyone except this group" (recomputed
  // weighted-safely from microdata), with the whole-sample 'overall' kept in
  // brackets. The rest must be a real complement (not an echo of overall), the
  // gap is measured against it, and — since overall is the weighted average of
  // the group and the rest — overall sits between them and the vs-rest gap is
  // at least as wide as vs-overall.
  const banner = TR.AGG.banner_groups[0].id;
  const findings = TR.views._collectFindings(banner);
  assert(findings.length > 0, "SACAP produces differences findings");
  const withRest = findings.filter((f) => f.rest !== null && f.rest !== undefined);
  assert(withRest.length > 0, "findings carry a recomputed rest %");
  assert(withRest.some((f) => Math.abs(f.rest - f.overall) > 0.01),
    "the rest is the complement, not a copy of overall");
  withRest.forEach((f) => {
    assert(typeof f.overall === "number", "overall carried for the bracket");
    assert(Math.abs(f.gap - (f.value - f.rest)) < 1e-9, "gap is measured vs the rest");
    const lo = Math.min(f.value, f.rest) - 1.5, hi = Math.max(f.value, f.rest) + 1.5;
    assert(f.overall >= lo && f.overall <= hi,
      "overall " + f.overall + " between group " + f.value + " and rest " + f.rest);
    assert(Math.abs(f.value - f.rest) >= Math.abs(f.value - f.overall) - 1.5,
      "vs-rest gap is at least as wide as vs-overall");
  });
  // the rendered sentence reads "of the rest" and brackets the overall figure
  const line = TR.views._diffLineHtml(withRest.find((f) => !f.isMean));
  assert(/of the rest/.test(line), "headline reads 'of the rest'");
  assert(/% overall\)/.test(line), "overall carried in brackets");
});

run("Differences view: surfaces significant MEAN / index / NPS standouts (recomputed)", () => {
  // The published tables carry no significance for mean-kind rows, so the diffs
  // view recomputes per-column means + a Welch t-test of each group vs THE REST
  // from microdata. It is bidirectional — a group significantly above OR below
  // the rest is a finding, in the metric's OWN units (no %/pp). Fixture: 3 groups
  // on one mean; A high (ahead of the rest), B and C low (behind the rest).
  const agg = { schema_version: 2,
    project: { name: "B", low_base_threshold: 5, alpha: 0.05, tracking: { enabled: false } },
    columns: [{ key: "T::Total", group: "total", label: "Total", letter: "" },
              { key: "G::A", group: "G", label: "A", letter: "A" },
              { key: "G::B", group: "G", label: "B", letter: "B" },
              { key: "G::C", group: "G", label: "C", letter: "C" }],
    banner_groups: [{ id: "G", name: "G" }], categories: ["c"],
    questions: [{ code: "QM", title: "Satisfaction", category: "c", type: "scale",
      bases: [{ n: 90, low: false }, { n: 30, low: false }, { n: 30, low: false }, { n: 30, low: false }],
      rows: [{ kind: "mean", label: "Mean", pct: [6.2, 9.5, 4.5, 4.5], n: [null, null, null, null], sig: ["", "", "", ""] }] }] };
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex };
  try {
    TR.AGG = agg; TR.PREV = null; TR.d2._qIndex = null;
    // group A high (~9.5), B and C low (~4.5); column index per respondent.
    const sc = [], bv = [];
    for (let i = 0; i < 30; i++) { sc.push(i % 2 ? 9 : 10); bv.push(1); }  // A
    for (let i = 0; i < 30; i++) { sc.push(i % 2 ? 4 : 5); bv.push(2); }   // B
    for (let i = 0; i < 30; i++) { sc.push(i % 2 ? 4 : 5); bv.push(3); }   // C
    TR.MICRO = { n: 90, answers: { QM: sc.map(() => null) }, banner_vars: { G: bv },
      weights: sc.map(() => 1), scores: { QM: sc } };
    const findings = TR.views._collectFindings("G");
    const a = findings.find((f) => f.isMean && f.column === "A");
    assert(a, "group A surfaces as a MEAN finding");
    assert(a.direction === "ahead", "A is ahead of the rest (got " + a.direction + ")");
    assert(Math.abs(a.value - 9.5) < 0.2, "value is the recomputed mean ~9.5 (got " + a.value + ")");
    assert(Math.abs(a.rest - 4.5) < 0.2, "rest is the other groups' mean ~4.5 (got " + a.rest + ")");
    assert(a.overall > a.rest && a.overall < a.value, "overall sits between rest and group");
    assert(Math.abs(a.gap - (a.value - a.rest)) < 1e-9, "gap is group - rest, in points");
    // bidirectional: B sits BELOW the rest (A+C) and must surface as 'behind'.
    const b = findings.find((f) => f.isMean && f.column === "B");
    assert(b && b.direction === "behind", "B surfaces as 'behind the rest'");
    assert(b.gap < 0 && b.value < b.rest, "behind finding has a negative gap");
    const line = TR.views._diffLineHtml(a);
    assert(/Mean 9\.5/.test(line), "sentence names the metric + value in its own units");
    const sentence = (line.match(/<div class="df-sentence">([\s\S]*?)<\/div>/) || [])[1] || "";
    assert(sentence && !/%/.test(sentence), "no percent signs in a mean finding's sentence");
    assert(/of the rest/.test(line) && /overall\)/.test(line), "vs the rest, overall bracketed");
    assert(/ahead of the rest/.test(line), "A's verdict reads 'ahead of the rest'");
    assert(/behind the rest/.test(TR.views._diffLineHtml(b)), "B's verdict reads 'behind the rest'");
  } finally {
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev; TR.d2._qIndex = saved.idx;
  }
});

run("Differences view: 95%+80% dual mode adds soft 'nearly significant' findings", () => {
  // The report's significance toggle (off | 95 | dual) applies here. A group ~1.5
  // SE above the rest is significant at 80% but not 95%: absent at "95", and
  // present-but-flagged-soft at "dual" with a "nearly significant (80%)" verdict.
  const agg = { schema_version: 2,
    project: { name: "B", low_base_threshold: 5, alpha: 0.05, tracking: { enabled: false } },
    columns: [{ key: "T::Total", group: "total", label: "Total", letter: "" },
              { key: "G::A", group: "G", label: "A", letter: "A" },
              { key: "G::B", group: "G", label: "B", letter: "B" },
              { key: "G::C", group: "G", label: "C", letter: "C" }],
    banner_groups: [{ id: "G", name: "G" }], categories: ["c"],
    questions: [{ code: "QM", title: "Mean", category: "c", type: "scale",
      bases: [{ n: 90, low: false }, { n: 30, low: false }, { n: 30, low: false }, { n: 30, low: false }],
      rows: [{ kind: "mean", label: "Mean", pct: [6.3, 7, 6, 6], n: [null, null, null, null], sig: ["", "", "", ""] }] }] };
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex, sig: TR.d2.state.sigMode };
  try {
    TR.AGG = agg; TR.PREV = null; TR.d2._qIndex = null;
    const sc = [], bv = [];
    for (let i = 0; i < 30; i++) { sc.push(i % 2 ? 4 : 10); bv.push(1); }  // A: mean 7, wide spread
    for (let i = 0; i < 30; i++) { sc.push(i % 2 ? 3 : 9); bv.push(2); }   // B: mean 6
    for (let i = 0; i < 30; i++) { sc.push(i % 2 ? 3 : 9); bv.push(3); }   // C: mean 6
    TR.MICRO = { n: 90, answers: { QM: sc.map(() => null) }, banner_vars: { G: bv },
      weights: sc.map(() => 1), scores: { QM: sc } };
    TR.d2.state.sigMode = "95";
    assert(!TR.views._collectFindings("G").some((f) => f.isMean && f.column === "A"),
      "A is NOT a finding at 95% (z ~1.5 < 1.96)");
    TR.d2.state.sigMode = "dual";
    const a = TR.views._collectFindings("G").find((f) => f.isMean && f.column === "A");
    assert(a, "A surfaces as a finding in dual mode");
    assert(a.soft === true, "A is flagged soft (nearly significant)");
    const line = TR.views._diffLineHtml(a);
    assert(/nearly significant \(80%\)/.test(line), "soft verdict reads 'nearly significant (80%)'");
    assert(/df-line soft/.test(line), "soft finding carries the soft class");
  } finally {
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev;
    TR.d2._qIndex = saved.idx; TR.d2.state.sigMode = saved.sig;
  }
});

run("Crosstabs panel: 'Select all' bulk-sets table/chart columns and rows", () => {
  // The Rows & columns panel's header "Select all" toggle. Hidden-lists store
  // what's OFF (empty = everything shown); chartColLabels stores what's ON and
  // always keeps the Total column so the chart has at least one.
  const saved = { banner: TR.d2.state.banner, q: TR.d2.state.activeQ,
    hc: TR.d2.state.hiddenCols, hr: TR.d2.state.hiddenRows,
    hcr: TR.d2.state.hiddenChartRows, ccl: TR.d2.state.chartColLabels };
  try {
    const banner = TR.AGG.banner_groups[0].id;
    const q = TR.AGG.questions.filter((x) => x.type === "scale")[0] || TR.AGG.questions[0];
    TR.d2.state.banner = banner; TR.d2.state.activeQ = q.code;
    TR.d2.state.hiddenCols = {}; TR.d2.state.hiddenRows = {};
    TR.d2.state.hiddenChartRows = {}; TR.d2.state.chartColLabels = ["Total"];
    const nCols = TR.cards2.chartModel().columns.length;   // Total + banner columns
    assert(nCols > 1, "banner has columns to toggle");

    TR.cards2._setAll("col-table", false);
    assert(TR.d2.state.hiddenCols[banner].length === nCols - 1, "clear table-cols hides all but Total");
    TR.cards2._setAll("col-table", true);
    assert(TR.d2.state.hiddenCols[banner].length === 0, "select table-cols hides none");

    TR.cards2._setAll("col-chart", true);
    assert(TR.d2.state.chartColLabels.length === nCols, "select chart-cols charts every column");
    TR.cards2._setAll("col-chart", false);
    assert(TR.d2.state.chartColLabels.length === 1 && TR.d2.state.chartColLabels[0] === "Total",
      "clear chart-cols keeps only Total");

    TR.cards2._setAll("row-table", false);
    assert(TR.d2.state.hiddenRows[q.code].length === q.rows.length, "clear table-rows hides every row");
    TR.cards2._setAll("row-table", true);
    assert(TR.d2.state.hiddenRows[q.code].length === 0, "select table-rows hides none");

    TR.cards2._setAll("row-chart", false);
    assert(TR.d2.state.hiddenChartRows[q.code].length > 0, "clear chart-rows hides the chartable rows");
    TR.cards2._setAll("row-chart", true);
    assert(TR.d2.state.hiddenChartRows[q.code].length === 0, "select chart-rows hides none");
  } finally {
    TR.d2.state.banner = saved.banner; TR.d2.state.activeQ = saved.q;
    TR.d2.state.hiddenCols = saved.hc; TR.d2.state.hiddenRows = saved.hr;
    TR.d2.state.hiddenChartRows = saved.hcr; TR.d2.state.chartColLabels = saved.ccl;
  }
});

run("Box filter + box custom-banner work from per-respondent box membership", () => {
  // Hidden-scale question (NPS-style): only boxes are published — no category
  // rows, no net_members. boxes = [0,1,2,0,1,2] so each box has exactly 2
  // respondents. The box NETs must back both a filter and a custom banner.
  const agg = { schema_version: 2,
    project: { name: "B", low_base_threshold: 1, alpha: 0.05, tracking: { enabled: false } },
    columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
    banner_groups: [], categories: ["c"],
    questions: [{ code: "QB", title: "NPS", category: "c", type: "scale",
      bases: [{ n: 6, low: false }], net_diffs: { "3": { plus: 2, minus: 0 } },
      rows: [{ kind: "net", label: "Low", pct: [33], n: [2], sig: [""] },
             { kind: "net", label: "Mid", pct: [33], n: [2], sig: [""] },
             { kind: "net", label: "High", pct: [33], n: [2], sig: [""] },
             { kind: "net", label: "NET POSITIVE (High - Low)", pct: [0], n: [null], sig: [""] },
             { kind: "mean", label: "Mean", pct: [5], n: [null], sig: [""] }] }] };
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex };
  try {
    TR.AGG = agg; TR.PREV = null; TR.d2._qIndex = null;
    TR.MICRO = { n: 6, answers: { QB: [null, null, null, null, null, null] },
      banner_vars: {}, weights: [1, 1, 1, 1, 1, 1], boxes: { QB: [0, 1, 2, 0, 1, 2] } };
    const br = TR.d2.boxRows(TR.d2.questionByCode("QB"));
    assert(br.map((b) => b.label).join(",") === "Low,Mid,High",
      "boxRows = the 3 box NETs, not the diff / mean (" + br.map((b) => b.label) + ")");
    const mask = TR.stats.mask([{ q: "QB", rows: [2], box: true }]);
    assert(TR.stats.maskCount(mask) === 2, "box filter (High) matches 2 respondents");
    const spec = TR.stats.columnsFor("custom:QB:net");
    assert(spec.columns.map((c) => c.label).join("|") === "Total|Low|Mid|High",
      "box banner columns = Total + the 3 boxes");
    const counts = spec.columns.map((c) => c.member ? c.member.reduce((a, b) => a + b, 0) : 6);
    assert(counts.join(",") === "6,2,2,2", "each box column has 2 members (got " + counts + ")");
    const m = TR.model.forQuestion("QB", null, [{ q: "QB", rows: [2], box: true }]);
    assert(m.source === "computed" && m.columns[0].base === 2,
      "box-filtered base = 2 promoters (got " + m.columns[0].base + ")");
  } finally {
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev; TR.d2._qIndex = saved.idx;
  }
});

run("Box filters round-trip through the URL hash", () => {
  const saved = { f: TR.d2.state.filters, agg: TR.AGG, micro: TR.MICRO, idx: TR.d2._qIndex };
  try {
    TR.AGG = { questions: [{ code: "QB", rows: [{ kind: "net", label: "Low" },
      { kind: "net", label: "High" }] }], columns: [], banner_groups: [] };
    TR.MICRO = { boxes: { QB: [0, 1] } };
    TR.d2._qIndex = null;
    TR.d2.state.filters = [{ q: "QB", box: true, rows: [1] }];
    const hash = TR.d2.encodeHash();
    assert(/filter=QB:b1/.test(hash), "box filter encodes with a 'b' marker (" + hash + ")");
    TR.d2.state.filters = [];
    TR.d2.decodeHash(hash);
    assert(TR.d2.state.filters.length === 1 && TR.d2.state.filters[0].box === true &&
      TR.d2.state.filters[0].rows[0] === 1, "box flag + rows survive the round-trip");
  } finally {
    TR.d2.state.filters = saved.f; TR.AGG = saved.agg;
    TR.MICRO = saved.micro; TR.d2._qIndex = saved.idx;
  }
});

run("Total-only study: custom box banner works; no empty-banner deref", () => {
  // CCS-style report with no banner groups. firstBanner() is "", the custom box
  // banner still yields columns, and the differences view (which reduces a
  // custom banner to firstBanner) returns no findings without throwing.
  const agg = { schema_version: 2,
    project: { name: "B", low_base_threshold: 1, alpha: 0.05, tracking: { enabled: false } },
    columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
    banner_groups: [], categories: ["c"],
    questions: [{ code: "QB", title: "NPS", category: "c", type: "scale",
      bases: [{ n: 4, low: false }],
      rows: [{ kind: "net", label: "Low", pct: [50], n: [2], sig: [""] },
             { kind: "net", label: "High", pct: [50], n: [2], sig: [""] }] }] };
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex };
  try {
    TR.AGG = agg; TR.PREV = null; TR.d2._qIndex = null;
    TR.MICRO = { n: 4, answers: { QB: [null, null, null, null] }, banner_vars: {},
      weights: [1, 1, 1, 1], boxes: { QB: [0, 1, 0, 1] } };
    assert(TR.d2.firstBanner() === "", "firstBanner() is empty for a Total-only study");
    const m = TR.model.forQuestion("QB", "custom:QB:net", []);
    assert(m && m.columns.length === 3, "custom box banner = Total + 2 box columns");
    assert(m.columns[1].base === 2 && m.columns[2].base === 2, "box columns recompute their bases");
    const f = TR.views._collectFindings(TR.d2.firstBanner());
    assert(Array.isArray(f) && f.length === 0, "Total-only differences = no findings, no crash");
  } finally {
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev; TR.d2._qIndex = saved.idx;
  }
});

run("Differences view: drops tautological standouts (answer exclusive to a group)", () => {
  // The S03 Plant case: each centre is 100% "its own plant" vs 0% of the rest —
  // a defining trait, not a discovered difference. A categorical finding whose
  // rest rounds to 0% (or 100%) is suppressed; a normal one (rest 20%) stays.
  const agg = { schema_version: 2,
    project: { name: "B", low_base_threshold: 1, alpha: 0.05, tracking: { enabled: false } },
    columns: [{ key: "T::Total", group: "total", label: "Total", letter: "" },
              { key: "G::A", group: "G", label: "A", letter: "A" },
              { key: "G::B", group: "G", label: "B", letter: "B" },
              { key: "G::C", group: "G", label: "C", letter: "C" }],
    banner_groups: [{ id: "G", name: "G" }], categories: ["c"],
    questions: [{ code: "QX", title: "Plant", category: "c", type: "single",
      bases: [{ n: 60, low: false }, { n: 20, low: false }, { n: 20, low: false }, { n: 20, low: false }],
      rows: [{ kind: "category", label: "Excl", pct: [17, 50, 0, 0], n: [10, 10, 0, 0], sig: ["", "BC", "", ""] },
             { kind: "category", label: "Shared", pct: [30, 50, 20, 20], n: [18, 10, 4, 4], sig: ["", "BC", "", ""] },
             { kind: "category", label: "Other", pct: [53, 0, 80, 80], n: [32, 0, 16, 16], sig: ["", "", "", ""] }] }] };
  const saved = { agg: TR.AGG, micro: TR.MICRO, prev: TR.PREV, idx: TR.d2._qIndex };
  try {
    TR.AGG = agg; TR.PREV = null; TR.d2._qIndex = null;
    const ans = [], bv = [], w = [];
    for (let i = 0; i < 20; i++) { ans.push(i < 10 ? 0 : 1); bv.push(1); w.push(1); } // A: 10 Excl, 10 Shared
    for (let i = 0; i < 20; i++) { ans.push(i < 4 ? 1 : 2); bv.push(2); w.push(1); }  // B: 4 Shared, 16 Other
    for (let i = 0; i < 20; i++) { ans.push(i < 4 ? 1 : 2); bv.push(3); w.push(1); }  // C: 4 Shared, 16 Other
    TR.MICRO = { n: 60, answers: { QX: ans }, banner_vars: { G: bv }, weights: w };
    const f = TR.views._collectFindings("G");
    assert(!f.some((x) => x.label === "Excl"),
      "exclusive answer (rest 0%) is suppressed as definitional");
    const shared = f.find((x) => x.label === "Shared");
    assert(shared, "a normal answer (rest 20%) survives");
    assert(Math.round(shared.rest) === 20, "kept finding has rest 20% (got " + shared.rest + ")");
  } finally {
    TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.PREV = saved.prev; TR.d2._qIndex = saved.idx;
  }
});

run("stacked chart export is transposed (segments=series, columns=bars)", () => {
  // Regression: the PPTX stacked export reused the bar layout (rows as
  // categories, one series per column), so each option rendered as its own
  // 100% bar. A 100% stacked bar must transpose — columns are the bars,
  // segments are the stacked series — matching render.stackedChart + the PNG.
  const q = TR.AGG.questions.filter((x) => x.type === "scale")[0] || TR.AGG.questions[0];
  const m = TR.model.forQuestion(q.code, TR.AGG.banner_groups[0].id, []);
  const segs = TR.render.chartRows(m).rows.length;
  const stacked = TR.exporter.buildChart(m, "stacked", [0]);
  const bar = TR.exporter.buildChart(m, "bar", [0]);
  assert(stacked, "stacked chart should build");
  assert(/grouping val="percentStacked"/.test(stacked.xml), "stacked must be percentStacked");
  const serCount = (stacked.xml.match(/<c:ser>/g) || []).length;
  assert(serCount === segs, "stacked needs one series per segment; got " + serCount + " of " + segs);
  const catCount = (stacked.xml.match(/<c:cat>[\s\S]*?ptCount val="(\d+)"/) || [])[1];
  assert(catCount === "1", "Total-only stacked should have one category bar; got " + catCount);
  assert(/<c:legend>/.test(stacked.xml), "stacked needs a legend to label its segments");
  assert((bar.xml.match(/<c:ser>/g) || []).length === 1, "a plain bar over Total stays one series");
  // segments use the brand ramp (mirrors render.stackedChart), not the
  // categorical palette — which would inject the gold accent colour.
  const accent = TR.charts.accentOf().replace("#", "").toUpperCase();
  assert(!new RegExp('srgbClr val="' + accent + '"').test(stacked.xml),
    "stacked segments must use the brand ramp, not the accent palette");
});

run("Index (mean) chart mode plots the mean row as a rating, not a distribution", () => {
  const q = TR.AGG.questions.filter((x) => x.type === "scale")
    .find((x) => x.rows.some((r) => r.kind === "mean")) || TR.AGG.questions[0];
  const m = TR.model.forQuestion(q.code, TR.AGG.banner_groups[0].id, []);
  assert(TR.render.hasMeanRow(m), "a scale question should expose a chartable mean row");

  // the distribution path never sources the mean row
  assert(TR.render.chartRows(m).rows.every((r) => r.kind !== "mean"),
    "the distribution chart must not source the mean row");

  // mean mode: the mean row becomes the chart source, rating carried in the pct slot
  m.chartKind = "mean"; m.valueKind = "mean";
  const data = TR.render.chartRows(m);
  assert(data.rows.length >= 1 && data.rows[0].kind === "mean", "mean mode sources the mean row");
  const srcMean = m.rows.find((r) => r.kind === "mean").cells[0].mean;
  assert(data.rows[0].cells[0].pct === srcMean,
    "the rating is exposed in the chartable slot (" + data.rows[0].cells[0].pct + " vs " + srcMean + ")");

  // both value charts label the rating (e.g. "4.1"), never the percentage ("4%")
  const rating = Number(srcMean).toFixed(1), asPct = Math.round(srcMean) + "%";
  const barSvg = TR.render.barChart(m, [0]), colSvg = TR.render.columnChart(m, [0]);
  assert(barSvg.indexOf(rating) !== -1 && barSvg.indexOf(asPct) === -1,
    "the horizontal bar is labelled with the rating, not a percentage");
  assert(colSvg.indexOf(rating) !== -1 && colSvg.indexOf(asPct) === -1,
    "the column is labelled with the rating, not a percentage");

  // bar + column are honoured for a mean; stacked / pie / dot / line fall back
  // to the (default) bar chart — never a percentage chart
  assert(TR.render.chartBy("bar", m, [0]) === barSvg, "a mean plot honours the bar chart");
  assert(TR.render.chartBy("column", m, [0]) === colSvg, "a mean plot honours the column chart");
  assert(TR.render.chartBy("stacked", m, [0]) === barSvg,
    "a mean plot falls back to the bar chart when a percentage type is selected");

  // native PPTX export of a mean bar labels ratings (0.0) on a fixed axis, not "0%"
  const pptxBar = TR.exporter.buildChart(m, "bar", [0]);
  assert(pptxBar.xml.indexOf('formatCode="0.0"') !== -1, "PPTX mean bar uses one-decimal rating labels");
  assert(pptxBar.xml.indexOf('formatCode="0&quot;%&quot;"') === -1, "PPTX mean bar must not carry a % format");
  assert(/<c:max val="/.test(pptxBar.xml), "PPTX mean bar fixes the rating axis max");

  // a question with no mean row exposes no mean plot (the dropdown won't offer it)
  const noMean = { code: "X", rows: [{ kind: "category", label: "A", cells: [{ pct: 50 }] }] };
  assert(!TR.render.hasMeanRow(noMean) && TR.render.meanChartRows(noMean).rows.length === 0,
    "no mean row -> no mean chart");
});

run("golden parity suite passes (subprocess)", () => {
  const res = spawnSync("node", [path.join(BASE, "tests", "golden_parity.mjs")],
    { encoding: "utf8" });
  assert(res.status === 0, "golden parity failed:\n" + res.stdout);
});

run("NET filter expansion reproduces the published banner base", () => {
  const q002 = TR.d2.questionByCode("Q002");
  const netIdx = q002.rows.findIndex((r) => r.kind === "net" && r.label === "Online campus");
  const members = q002.net_members[String(netIdx)];
  assert(members && members.length, "Online campus net decomposed");
  const n = TR.stats.maskCount(TR.stats.mask([{ q: "Q002", rows: members }]));
  assert(n === 561, "expected 561 Online-campus respondents, got " + n);
  const m = TR.model.forQuestion("Q008", TR.AGG.banner_groups[3].id,
    [{ q: "Q002", rows: members }]);
  assert(m.columns[0].base === 191,
    "Q008 filtered base should equal published Q008xOnline base 191, got " + m.columns[0].base);
});

run("story deck -> structurally valid native pptx (python)", () => {
  const m1 = TR.model.forQuestion("Q008", TR.AGG.banner_groups[0].id, []);
  const m2 = TR.model.forQuestion("Q017", TR.AGG.banner_groups[0].id, []);
  const slides = [TR.exporter.titleSlide(2),
    TR.exporter.slideForModel(m1, "Admissions support stays strong."),
    TR.exporter.slideForModel(m2, "")];
  const bytes = TR.pptx.package(slides, { project: TR.AGG.project });
  const tmp = path.join(BASE, "tests", "tmp");
  mkdirSync(tmp, { recursive: true });
  const out = path.join(tmp, "v2_story.pptx");
  writeFileSync(out, bytes);
  const report = execFileSync("python3",
    [path.join(path.dirname(BASE), "tests", "verify_pptx.py"), out], { encoding: "utf8" });
  assert(report.startsWith("OK"), report);
});

run("dot-plot pin -> native shapes (no chart part), packs to valid pptx", () => {
  // PowerPoint has no horizontal dot-plot chart type, so a dot pin renders as
  // positioned ellipse shapes — one per category, no chart object — and the
  // deck must still package and validate structurally.
  const m = TR.model.forQuestion("Q008", TR.AGG.banner_groups[0].id, []);
  const segs = TR.render.chartRows(m).rows.length;
  const slide = TR.exporter.slideForModel(m, "dot note",
    { chart: true, chartType: "dot", chartCols: [0], table: true, insight: true });
  assert(slide.charts.length === 0, "a dot pin must not create a chart part");
  assert(!/<c:chart /.test(slide.xml), "a dot pin must not embed a chart frame");
  const dots = (slide.xml.match(/prst="ellipse"/g) || []).length;
  assert(dots >= segs, "expected one dot per category; got " + dots + " of " + segs);
  const bytes = TR.pptx.package([TR.exporter.titleSlide(1), slide], { project: TR.AGG.project });
  const tmp = path.join(BASE, "tests", "tmp");
  mkdirSync(tmp, { recursive: true });
  const out = path.join(tmp, "v2_dotplot.pptx");
  writeFileSync(out, bytes);
  const report = execFileSync("python3",
    [path.join(path.dirname(BASE), "tests", "verify_pptx.py"), out], { encoding: "utf8" });
  assert(report.startsWith("OK"), report);
});

run("wave history: per-year question-match rates meet thresholds", () => {
  const floor = { 2018: 0.45, 2019: 0.45, 2020: 0.45, 2021: 0.55,
    2022: 0.70, 2023: 0.80, 2024: 0.85 };
  const report = TR.PREV.match_report || {};
  for (const year of Object.keys(floor)) {
    assert(report[year], `match report missing ${year}`);
    assert(report[year].rate >= floor[year],
      `${year}: rate ${report[year].rate} below floor ${floor[year]}`);
  }
});

run("exhibit slide: TWO native chart objects on one slide (python)", () => {
  const item = { kind: "exhibit", qs: ["Q008"], banner: TR.AGG.banner_groups[0].id,
    filters: [], flags: { dist: true, trend: true, table: false, insight: true },
    distType: "column", chartKind: "summary", chartCols: [0],
    note: "two-panel flagship known answer" };
  const slide = TR.exhibit.slide(item);
  assert(slide.charts.length === 2, "expected 2 chart parts, got " + slide.charts.length);
  assert(slide.xml.includes('r:id="rId2"') && slide.xml.includes('r:id="rId3"'),
    "both chart frames referenced");
  // the trend panel plots summary metrics, not raw scale categories
  const trendXml = slide.charts[1].xml;
  assert(trendXml.includes("Index"), "Index series present in trend chart");
  assert(!/<c:tx>[\s\S]{0,200}?<c:v>Excellent<\/c:v>/.test(trendXml),
    "raw category rows are not trend series");
  // cross-section composite: 2 charts + the metric-by-wave native table
  const composite = TR.exhibit.slide({ kind: "exhibit",
    qs: ["Q017", "Q016", "Q008"], banner: TR.AGG.banner_groups[0].id,
    filters: [], flags: { dist: true, trend: true, table: true, insight: true },
    distType: "column", note: "composite known answer" });
  assert(composite.charts.length === 2, "composite chart parts");
  const bytes = TR.pptx.package([TR.exporter.titleSlide(2), slide, composite],
    { project: TR.AGG.project });
  const tmp = path.join(BASE, "tests", "tmp");
  mkdirSync(tmp, { recursive: true });
  const out = path.join(tmp, "v2_exhibit.pptx");
  writeFileSync(out, bytes);
  const report = execFileSync("python3",
    [path.join(path.dirname(BASE), "tests", "verify_pptx.py"), out], { encoding: "utf8" });
  assert(report.startsWith("OK"), report);
});

run("segment extraction: per-year coverage matches the workbooks", () => {
  const report = TR.PREV.match_report;
  const want = { 2018: 0, 2019: 0, 2020: 5, 2021: 5, 2022: 5, 2023: 0, 2024: 24 };
  for (const [year, n] of Object.entries(want)) {
    assert(report[year].segments === n,
      `${year}: ${report[year].segments} segments, expected ${n}`);
  }
  const segs = TR.waves.segments();
  assert(segs.length === 24, "tracked segments " + segs.length);
  const campus = segs.filter((s) => s.group === "Q002");
  assert(campus.length === 5 && campus[0].label === "Online campus",
    "campus segments resolved incl. the Online alias");
});

run("segment pin exhibit: 2 native charts + table (python)", () => {
  const nps = TR.trk.metricList("key").find((m) =>
    TR.model.norm(m.label) === "nps score");
  const item = { kind: "exhibit", qs: [nps.code], metricRi: nps.ri,
    metricLabel: nps.label, segments: ["total", "online campus", "cape town"],
    banner: TR.AGG.banner_groups[0].id, filters: [],
    flags: { dist: true, trend: true, table: true, insight: true },
    distType: "column", note: "segment trend known answer" };
  const slide = TR.exhibit.slide(item);
  assert(slide.charts.length === 2, "chart parts " + slide.charts.length);
  assert((slide.charts[1].xml.match(/<c:ser>/g) || []).length === 3,
    "one trend series per pinned segment");
  const bytes = TR.pptx.package([TR.exporter.titleSlide(1), slide],
    { project: TR.AGG.project });
  const tmp = path.join(BASE, "tests", "tmp");
  mkdirSync(tmp, { recursive: true });
  const out = path.join(tmp, "v2_segpin.pptx");
  writeFileSync(out, bytes);
  const report = execFileSync("python3",
    [path.join(path.dirname(BASE), "tests", "verify_pptx.py"), out], { encoding: "utf8" });
  assert(report.startsWith("OK"), report);
});

run("means significance: Welch on distribution-derived SDs", () => {
  // SD known answer (hand-computed): Q008 2025 Index distribution
  // 0/3/12/37/47 over scores 0/25/50/75/100 -> SD 19.86
  const idx8 = TR.trk.metricList("key").find((m) =>
    m.code === "Q008" && m.isMean);
  const sd = TR.trk.sdAt(idx8, null, TR.render.currentYear());
  assert(Math.abs(sd - 19.86) < 0.05, "Q008 Index SD " + sd);
  // big index moves flag, small ones don't
  const means = TR.trk.metricList("key").filter((m) => m.isMean);
  let sig = 0;
  for (const m of means) {
    const cells = TR.trk.points(m, null);
    const last = cells[cells.length - 1];
    if (last && last.current && last.sig_prev) sig++;
  }
  assert(sig >= 5 && sig < means.length / 2,
    "significant mean changes: " + sig + " of " + means.length);
  const m10 = TR.model.forQuestion("Q010", TR.AGG.banner_groups[0].id, []);
  const idxRow = m10.rows.find((r) => r.kind === "mean");
  assert(idxRow.delta.sig === false, "Q010 Index -0.9 must NOT flag");
});

run("native trend chart: wave-label categories, fixed axis, one series per metric", () => {
  const m = TR.model.forQuestion("Q017", TR.AGG.banner_groups[0].id, []);
  m.chartKind = "summary";
  const chart = TR.exporter.buildTrendChart(m);
  const sers = (chart.xml.match(/<c:ser>/g) || []).length;
  assert(sers >= 3 && sers <= 6, "series count " + sers);
  // X categories are the wave labels (yLabel), not the raw year keys — matches
  // the pin (e.g. "Annual 2018", not "2018").
  assert(chart.xml.includes("Annual 2018"), "categories use wave labels");
  assert(!chart.xml.includes("<c:v>2018</c:v>"), "raw year key not used as a category");
  // Y axis is a fixed 0-to-max scale (matches the pin), not auto-scaled.
  assert(/<c:max val="[\d.]+"\/>/.test(chart.xml) && chart.xml.includes('<c:min val="0"/>'),
    "value axis carries an explicit 0-to-max scale");
  assert(chart.workbook && chart.workbook.length > 500, "embedded workbook present");
});

run("deltas: most questions tracked, new ones flagged", () => {
  let tracked = 0, withDeltaRows = 0;
  for (const q of TR.AGG.questions) {
    const m = TR.model.forQuestion(q.code, TR.AGG.banner_groups[0].id, []);
    if (m.prevWave) {
      tracked++;
      if (m.rows.some((r) => r.delta)) withDeltaRows++;
    }
  }
  assert(tracked >= 60 && tracked < 79, "tracked questions: " + tracked);
  assert(withDeltaRows >= 55, "questions with row-level deltas: " + withDeltaRows);
});

run("composite exhibit: one scale per chart, everything in the table", () => {
  // Q017 NPS (0-100 family) + Q016 trust mean (0-10) + Q008 Index (0-100)
  const item = { kind: "exhibit", qs: ["Q017", "Q016", "Q008"],
    banner: TR.AGG.banner_groups[0].id, filters: [],
    flags: { dist: true, trend: true, table: true }, distType: "column",
    note: "" };
  const models = TR.exhibit.models(item);
  const dist = TR.exhibit.distModel(item, models);
  assert(dist.rows.length === 2, "dominant 0-100 family plots: " +
    dist.rows.map((r) => r.label).join(" | "));
  assert(dist._dropped.length === 1 && /trust/i.test(dist._dropped[0]),
    "the 0-10 trust mean is named as table-only");
  const matrix = TR.exhibit.matrix(item, models);
  assert(matrix.body.length === 3, "the table keeps all three metrics");
  for (const row of matrix.body) {
    const label = row.cells[0];
    const tail = label.split("·").pop().trim();
    assert(label.split(tail).length === 2,
      "metric label not duplicated: " + label);
  }
  const html = TR.exhibit.panelsHtml(item);
  assert(html.includes("Different scale — not on this chart"),
    "story card carries the scale note");
  const slide = TR.exhibit.slide(item);
  assert(slide.xml.includes("different scale, table only"),
    "PPTX meta carries the scale note");
});

run("composite this-wave chart renders 0-10 mean ratings as ratings, not %", () => {
  // Regression: the multi-question composite dist chart pushed each headline
  // mean into a category/pct cell, so 0-10 mean ratings (e.g. CCS) charted as
  // "8%" on a % scale. The mean family must read as ratings (7.6, 0-10 axis).
  const mk = (code, title, mean) => ({ code: code, title: title, rows: [
    { kind: "mean", label: "Mean", delta: null,
      waves: [{ year: 2024, value: mean - 0.2 }],
      cells: [{ mean: mean, pct: null, n: null, sig: "" }] }] });
  const models = [mk("Q1", "Overall satisfaction", 7.6), mk("Q2", "Relationship", 8.1)];
  const item = { kind: "exhibit", qs: ["Q1", "Q2"], banner: "", filters: [],
    flags: { dist: true }, distType: "column", note: "" };
  const dist = TR.exhibit.distModel(item, models);
  assert(dist.valueKind === "mean", "an all-mean composite flags valueKind=mean");
  assert(dist.rows.length === 2, "both 0-10 means share one chart");
  const svg = TR.render.columnChart(dist, [0]);
  assert(/>7\.6</.test(svg), "the column label shows the rating 7.6, got: " +
    (svg.match(/>[\d.]+%?</g) || []).join(","));
  assert(!/>[\d.]+%</.test(svg), "no percentage labels on a rating chart");
  const chart = TR.exporter.buildChart(dist, "column", [0]);
  assert(chart && chart.xml.indexOf("0&quot;%&quot;") === -1,
    "native PPTX chart drops the forced % number format");
  // a non-mean composite (NPS) keeps the percentage path untouched
  const np = (code, pct, wv) => ({ code: code, title: code, rows: [
    { kind: "net", label: "NPS", diff: false, delta: null,
      waves: [{ year: 2024, value: wv }], cells: [{ pct: pct, mean: null, n: null, sig: "" }] }] });
  const npsDist = TR.exhibit.distModel(
    { kind: "exhibit", qs: ["N1", "N2"], banner: "", filters: [], flags: { dist: true } },
    [np("N1", 33, 30), np("N2", 41, 40)]);
  assert(npsDist.valueKind === "pct", "a non-mean composite stays on the % path");
});

run("per-row chart selection: unticked rows leave the chart only", () => {
  const m = TR.model.forQuestion("Q008", TR.AGG.banner_groups[0].id, []);
  m.chartKind = "detail";
  const all = TR.render.chartRows(m).rows.map((r) => r.label);
  assert(all.includes("Good"), "baseline includes the Good row");
  m.hiddenChartRows = ["Good"];
  const picked = TR.render.chartRows(m).rows.map((r) => r.label);
  assert(!picked.includes("Good"), "Good removed from the chart");
  assert(picked.length === all.length - 1, "exactly one row removed");
  // the table is governed separately — its rows are untouched
  assert(m.rows.some((r) => r.label === "Good"), "table row still present");
  // trend rows honour the same selection
  m.chartKind = "summary";
  m.hiddenChartRows = ["Good or excellent"];
  const trend = TR.render.trendRows(m).map((r) => r.label);
  assert(!trend.includes("Good or excellent"), "trend row removed");
});

run("trend chart draws the interval band from {lo, hi} bounds", () => {
  const m = TR.model.forQuestion("Q008", TR.AGG.banner_groups[0].id, []);
  m.chartKind = "summary";
  const ci = (row, p) => p.base ? TR.conf.wilsonPct(p.value, p.base) : null;
  const banded = TR.render.trendChart(m, { ci });
  assert(banded.includes('fill-opacity="0.12"'), "band path missing");
  const plain = TR.render.trendChart(m, {});
  assert(!plain.includes('fill-opacity="0.12"'), "band must be opt-in");
});

run("pins + slides carry the interval vocabulary", () => {
  // pinned NPS Visualise view: the bands are z·SD/√n on the
  // distribution-derived SD — the context line must NOT claim Wilson
  const nps = TR.trk.metricList("key").find((m) =>
    TR.model.norm(m.label) === "nps score");
  const item = { kind: "exhibit", qs: [nps.code], ci: true,
    series: [{ code: nps.code, ri: nps.ri, label: "Total", seg: "total" }],
    banner: TR.AGG.banner_groups[0].id, filters: [],
    flags: { trend: true }, distType: "column", note: "" };
  const models = TR.exhibit.models(item);
  const ctx = TR.exhibit.contextLine(item, models);
  assert(ctx.includes("95% SI (z·SD/√n) bands"), "exhibit context: " + ctx);
  assert(!ctx.includes("Wilson"), "mean-metric bands must not claim Wilson");
  // crosstab pin with intervals: Q008 carries an Index (mean) row, so the
  // PPTX meta line names both methods
  const model = TR.model.forQuestion("Q008", TR.AGG.banner_groups[0].id, [],
    { intervals: true });
  const slide = TR.exporter.slideForModel(model, "", {
    table: true, insight: false, intervals: true });
  assert(slide.xml.includes("95% SI (Wilson; means z·SD/√n)"),
    "mixed slide meta misses both methods");
  // a question with no mean row stays pure Wilson
  const propsModel = TR.model.forQuestion("Q002", TR.AGG.banner_groups[1].id,
    [], { intervals: true });
  const propsSlide = TR.exporter.slideForModel(propsModel, "", {
    table: true, insight: false, intervals: true });
  assert(propsSlide.xml.includes("95% SI (Wilson)") &&
    !propsSlide.xml.includes("z·SD"), "props-only slide meta");
  const plainSlide = TR.exporter.slideForModel(model, "", { table: true });
  assert(!plainSlide.xml.includes("95% SI"), "method note must be opt-in");
});

run("negative values floor at the axis in dist charts (NPS composites)", () => {
  // a composite exhibit charts headline metrics as pseudo category rows —
  // an NPS can be negative; SVG must stay valid and the label honest
  const model = { code: "NEG", title: "t", chartKind: "detail",
    lowBaseThreshold: 30,
    columns: [{ label: "Total", letter: "", base: null, low: false }],
    rows: [
      { kind: "category", label: "NPS A", cells: [{ pct: -22, n: null, mean: null, sig: "" }] },
      { kind: "category", label: "NPS B", cells: [{ pct: 35, n: null, mean: null, sig: "" }] }
    ] };
  const column = TR.render.columnChart(model, [0]);
  assert(!/height="-/.test(column), "no negative-height rects");
  assert(column.includes("-22%"), "true negative value still labelled");
  const bar = TR.render.barChart(model, [0]);
  assert(!/width="-/.test(bar) && bar.includes("-22%"), "bar chart honest");
  const dot = TR.render.dotChart(model, [0]);
  assert(!/cx="-/.test(dot), "dots never draw left of the axis");
  const pie = TR.render.pieChart(model, 0);
  assert(pie.includes("35%") && !pie.includes("-22%"),
    "pie floors negatives at zero share");
});

run("pins reproduce the table view state (sort, hidden rows/cols, dual)", () => {
  const s = TR.d2.state;
  const banner = TR.AGG.banner_groups[0].id;
  const hideCol = TR.model.forQuestion("Q008", banner, []).columns[1].label;
  const saved = { activeQ: s.activeQ, banner: s.banner, sigMode: s.sigMode };
  try {
    s.activeQ = "Q008";
    s.banner = banner;
    s.hiddenRows.Q008 = ["Good"];
    s.hiddenCols[banner] = [hideCol];
    s.sorts.Q008 = { col: 0, dir: "desc" };
    s.sigMode = "dual";
    TR.story2.pinCurrent({ chart: false, table: true, insight: false });
    const item = TR.story2.items()[TR.story2.items().length - 1];
    assert(item.hiddenRows.indexOf("Good") !== -1 && item.dual === true &&
      item.sort && item.sort.dir === "desc" &&
      item.hiddenCols.indexOf(hideCol) !== -1, "pin captured the view state");
    const model = TR.story2._modelFor(item);
    assert(!model.rows.some((r) => r.label === "Good"),
      "hidden table row stays hidden on the story card");
    assert(!model.columns.some((c) => c.label === hideCol),
      "hidden column stays hidden on the story card");
    const cats = model.rows.filter((r) => r.kind === "category");
    for (let i = 1; i < cats.length; i++) {
      const a = cats[i - 1].cells[0].pct, b = cats[i].cells[0].pct;
      assert(b === null || (a !== null && a >= b), "sort travels with the pin");
    }
    // an old pin without the new fields renders the full default table
    const legacy = TR.story2._modelFor({ q: "Q008", banner: banner });
    assert(legacy.rows.some((r) => r.label === "Good") &&
      legacy.columns.some((c) => c.label === hideCol),
      "legacy pins keep the historic full-table behaviour");
  } finally {
    TR.story2.items().pop();
    delete s.hiddenRows.Q008;
    delete s.hiddenCols[banner];
    delete s.sorts.Q008;
    s.activeQ = saved.activeQ; s.banner = saved.banner; s.sigMode = saved.sigMode;
  }
});

run("PPTX tables that cannot fit say so instead of truncating silently", () => {
  const tall = { head: ["Metric", "Total"],
    body: Array.from({ length: 30 }, (_, i) =>
      ({ kind: "row", cells: ["Row " + i, String(i)] })) };
  const xml = TR.exporter.matrixSlide("Tall table", "", tall);
  assert(xml.includes("+16 more rows"), "truncation note missing");
  assert((xml.match(/<a:tr /g) || []).length === 16,
    "head + 14 data rows + the note row");
  // a table that fits is left alone
  const small = { head: ["Metric", "Total"],
    body: [{ kind: "row", cells: ["Only row", "1"] }] };
  assert(!TR.exporter.matrixSlide("Small", "", small).includes("more rows"),
    "no note when nothing was dropped");
});

run("confidence labels: sampling_method normalisation + Convenience alias", () => {
  // Probability designs speak "Confidence Interval"; everything else softens to
  // "Stability Interval". Convenience and Self_Selected are synonyms, and an
  // unrecognised value falls back to the cautious framing.
  const L = (m) => TR.conf.labels(m);
  assert(L("Random").is_probability === true &&
    L("Random").interval_name === "Confidence Interval", "Random is a probability design (CI)");
  ["Stratified", "Cluster", "Census"].forEach((m) =>
    assert(L(m).is_probability === true, m + " is a probability design"));
  ["Quota", "Online_Panel", "Self_Selected", "Convenience", "Not_Specified"].forEach((m) =>
    assert(L(m).is_probability === false &&
      L(m).interval_name === "Stability Interval", m + " softens to a stability interval"));
  assert(L("Convenience").sampling_method_normalised === "convenience" &&
    L("Self_Selected").sampling_method_normalised === "convenience",
    "Convenience and Self_Selected normalise to the same key");
  assert(L("Online_Panel").sampling_method_normalised === "panel", "Online_Panel -> panel");
  assert(L("nonsense").sampling_method_normalised === "not_specified",
    "an unrecognised value falls back to not_specified");
});

run("confidence: explainer + sampling vocabulary ship in the artifact", () => {
  // the callout is built live from the report's own data
  const callout = TR.conf.calloutHtml();
  assert(callout.includes("How sure can I be of these numbers"),
    "callout headline missing");
  // fmt.base uses a narrow no-break space as the thousands separator
  assert(/Based on \d[\d,\s  ]* answers, this \d+% would likely land between/
    .test(callout), "worked example not computed from the data");
  assert(/has only \d[\d,\s  ]* respondents/.test(callout),
    "small-group example not computed from the data");
  assert(callout.includes("stability intervals (SI)"),
    "SACAP (Not_Specified) must use the honest SI vocabulary");
  const out = path.join(BASE, "sacap_report_v2.html");
  const html = readFileSync(out, "utf8");
  assert(html.includes('"sampling_method":"Not_Specified"'),
    "project config in the artifact misses sampling_method");
  assert(html.includes("How sure can I be of these numbers"),
    "explainer builder missing from the artifact bundle");
});

run("built artifact exists, self-contained, < 2 MB", () => {
  const out = path.join(BASE, "sacap_report_v2.html");
  assert(existsSync(out), "run Rscript build.R first");
  const html = readFileSync(out, "utf8");
  assert(html.includes('id="data-agg"'), "aggregate island present");
  assert(html.includes('id="data-micro"'), "microdata island present");
  assert(!/(src|href)="https?:\/\//.test(html), "no external fetches");
  assert(statSync(out).size < 2 * 1024 * 1024, "size " + statSync(out).size);
});

run("structure: no v2 source file exceeds 300 active lines (or is excepted)", () => {
  const offenders = [];
  for (const f of readdirSync(V2_JS).filter((x) => x.endsWith(".js"))) {
    const text = readFileSync(path.join(V2_JS, f), "utf8");
    if (/SIZE-EXCEPTION/.test(text)) continue;
    const active = text.split("\n").filter((line) => {
      const t = line.trim();
      return t !== "" && !t.startsWith("//") && !t.startsWith("/*") &&
        !t.startsWith("*") && !/^[})\];]*$/.test(t);
    }).length;
    if (active > MAX_ACTIVE_LINES) offenders.push(`${f}: ${active}`);
  }
  assert(offenders.length === 0, "over limit: " + offenders.join(", "));
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
