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
  var html = TR.render.tableHtml(model, { heatmap: true });
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
