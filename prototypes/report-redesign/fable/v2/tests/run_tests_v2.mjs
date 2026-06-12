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
