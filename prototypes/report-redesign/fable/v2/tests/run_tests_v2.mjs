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

run("native trend chart: year categories + one series per metric", () => {
  const m = TR.model.forQuestion("Q017", TR.AGG.banner_groups[0].id, []);
  m.chartKind = "summary";
  const chart = TR.exporter.buildTrendChart(m);
  const sers = (chart.xml.match(/<c:ser>/g) || []).length;
  assert(sers >= 3 && sers <= 6, "series count " + sers);
  assert(chart.xml.includes("<c:v>2018</c:v>") && chart.xml.includes("<c:v>2025</c:v>"),
    "categories span 2018 to the current wave");
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
