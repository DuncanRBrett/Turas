#!/usr/bin/env node
/**
 * Native-export fidelity gate — regressions where the downloaded deck/workbook
 * silently disagreed with the on-screen report:
 *   - wave axis keys sorted lexicographically ([10, 11, 9]) on both the
 *     on-screen trend chart and the PPTX trend chart;
 *   - a question pinned on the trend chart ("line") exported as a bar chart
 *     of current-wave values, dropping the wave history;
 *   - PPTX trend export plotted 0-10 means and percentage NETs on one axis
 *     while the screen splits scales and keeps the dominant group;
 *   - series column letters built with String.fromCharCode(66+k) broke past
 *     25 series (Sheet1!$[$1);
 *   - render.matrix (Excel/Copy/TSV source) showed one mislabelled base row
 *     on weighted reports while the screen shows unweighted/weighted/effective.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/exports_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console, TextEncoder };   // 13_zip.js encodes part bytes
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const file of ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js",
  "14_pptx_parts.js", "23_render.js", "23z_charts.js", "23za_trend.js",
  "23y_xlsx.js", "29_export.js"]) {
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });
}
const TR = sandbox.TR;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) { if (a !== b) throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a)); }

/* ---------------- fixtures ---------------- */

// Tracker on sequential wave numbers (9, 10, 11 + current 12): the exact case
// a lexicographic sort scrambles. History arrives unsorted (assembler order).
function trendModel() {
  TR.AGG = { project: { name: "Trend fixture", wave: "Wave 12", wave_order: 12 } };
  return {
    code: "Q1", title: "KPI over waves", chartKind: "summary",
    columns: [{ label: "Total", base: 200 }],
    rows: [
      { kind: "net", label: "Top2 (NET)",
        waves: [{ year: 9, value: 50 }, { year: 11, value: 60 }, { year: 10, value: 55 }],
        cells: [{ pct: 62 }] },
      { kind: "mean", label: "Mean rating",
        waves: [{ year: 9, value: 7.5 }, { year: 10, value: 7.8 }],
        cells: [{ mean: 7.9 }] }
    ]
  };
}

// Current-wave-only question (no history) for the line -> bar fallback.
function flatModel() {
  TR.AGG = { project: { name: "Flat fixture", wave: "Wave 12" } };
  return {
    code: "Q2", title: "Flat single-select",
    columns: [{ label: "Total", base: 100 }],
    rows: [
      { kind: "category", label: "Yes", cells: [{ pct: 60 }] },
      { kind: "category", label: "No", cells: [{ pct: 40 }] }
    ]
  };
}

// 27 response options: the 26th+ series must still get valid column letters.
function wideModel() {
  TR.AGG = { project: { name: "Wide fixture", wave: "Wave 12" } };
  return {
    code: "Q3", title: "27-option single-select",
    columns: [{ label: "Total", base: 500 }],
    rows: Array.from({ length: 27 }, (_, i) => (
      { kind: "category", label: "Option " + (i + 1), cells: [{ pct: 3 }] }
    ))
  };
}

console.log("Native export fidelity — suite:");

/* ---------------- 1. wave keys sort numerically (screen + PPTX) ---------------- */
run("waveKeySort orders numeric keys chronologically, not lexicographically", () => {
  eq(TR.render.waveKeySort([10, 11, 9]).join(","), "9,10,11", "numbers");
  eq(TR.render.waveKeySort(["10", "9", "11"]).join(","), "9,10,11", "numeric strings");
  eq(TR.render.waveKeySort([2024, 2025.5, 2025]).join(","), "2024,2025,2025.5",
    "twice-yearly wave_order keys");
  eq(TR.render.waveKeySort(["W10", "A", "W2"]).join(","), "A,W10,W2",
    "non-numeric keys fall back to lexicographic");
});

run("on-screen trendChart x-axis runs 9 -> 12 (was 10-9 under string sort)", () => {
  const svg = TR.render.trendChart(trendModel());
  assert(svg.indexOf("Published wave Totals · 9–12") !== -1,
    "axis note spans first to last wave chronologically; got: " +
    (svg.match(/Published wave Totals[^<]*/) || ["<no note>"])[0]);
});

run("PPTX trend chart categories run 9,10,11,12 in order", () => {
  const chart = TR.exporter.buildTrendChart(trendModel());
  assert(chart, "chart built");
  const cats = [...chart.xml.matchAll(/<c:pt idx="\d+"><c:v>(\d+)<\/c:v><\/c:pt>/g)]
    .map((m) => m[1]).slice(0, 4);
  eq(cats.join(","), "9,10,11,12", "category cache order");
});

/* ---------------- 2. pinned trend chart exports as a line chart ---------------- */
run("buildChart type 'line' routes to the wave-history line chart", () => {
  const chart = TR.exporter.buildChart(trendModel(), "line", [0]);
  assert(chart, "chart built");
  assert(chart.xml.indexOf("<c:lineChart>") !== -1, "a real c:lineChart part");
  assert(chart.xml.indexOf("<c:barChart>") === -1, "not a bar chart of current values");
  assert(chart.xml.indexOf(">50<") !== -1 && chart.xml.indexOf(">55<") !== -1 &&
    chart.xml.indexOf(">60<") !== -1, "wave history values carried in the series");
});

run("buildChart type 'line' with no wave history falls back to the bar chart", () => {
  const chart = TR.exporter.buildChart(flatModel(), "line", [0]);
  assert(chart, "chart built");
  assert(chart.xml.indexOf("<c:barChart>") !== -1 &&
    chart.xml.indexOf('<c:barDir val="bar"/>') !== -1, "horizontal bar fallback");
  assert(chart.xml.indexOf("<c:lineChart>") === -1, "no empty line chart");
});

/* ---------------- 3. PPTX trend export splits mixed scales like the screen ------ */
run("buildTrendChart keeps the dominant scale group and notes the dropped rows", () => {
  const chart = TR.exporter.buildTrendChart(trendModel());
  // screen: pct group (1 NET) vs mean group (1 row) -> pct wins the tie; the
  // 0-10 mean must NOT share the percentage axis
  assert(chart.xml.indexOf("Top2 (NET)") !== -1, "percentage series kept");
  assert(chart.xml.indexOf("Mean rating") === -1, "0-10 mean dropped from the % axis");
  eq(chart.note, "1 series hidden (mixed scales or >6)", "mixed-scale note for the slide");
});

run("buildTrendChart with means only uses the anchored 0-10 mean axis", () => {
  const m = trendModel();
  m.rows = [m.rows[1]];                          // just the 0-10 mean
  const chart = TR.exporter.buildTrendChart(m);
  assert(chart.xml.indexOf("Mean rating") !== -1, "mean series kept when dominant");
  assert(chart.xml.indexOf('<c:max val="10"/>') !== -1,
    "mean axis anchored to 10, not a percentage max");
  eq(chart.note, "", "no note when nothing is dropped");
});

/* ---------------- 4. series column letters past Z ---------------- */
run("seriesLetter is base-26: B..Z then AA, AB (mirrors generate_excel_letters)", () => {
  const L = TR.exporter._seriesLetter;
  eq(L(0), "B", "series 0 -> B (col A holds labels)");
  eq(L(24), "Z", "series 24 -> Z");
  eq(L(25), "AA", "series 25 -> AA (was '[' via fromCharCode)");
  eq(L(26), "AB", "series 26 -> AB");
  eq(L(50), "AZ", "series 50 -> AZ");
  eq(L(51), "BA", "series 51 -> BA");
});

run("a 27-row stacked chart makes valid Sheet1!$AA$ refs, never Sheet1!$[$", () => {
  const chart = TR.exporter.buildChart(wideModel(), "stacked", [0]);
  assert(chart, "chart built");
  assert(chart.xml.indexOf("Sheet1!$AA$1") !== -1, "26th series lands in column AA");
  assert(chart.xml.indexOf("$[$") === -1, "no bracket pseudo-letters in formulas");
});

/* ---------------- 5. export matrix mirrors the weighted base block ---------------- */
function weightedModel() {
  TR.AGG = { project: { name: "Weighted fixture", weighted: true } };
  return {
    code: "Q4", title: "Weighted",
    columns: [
      { label: "Total", base: 412, baseW: 640, baseEff: 371 },
      { label: "Male", base: 200, baseW: 310, baseEff: 180 }
    ],
    rows: [{ kind: "category", label: "Yes",
      cells: [{ pct: 55, sig: "" }, { pct: 52, sig: "" }] }]
  };
}

run("render.matrix emits unweighted/weighted/effective base rows when weighted", () => {
  const m = TR.render.matrix(weightedModel());
  const rows = m.body.map((r) => r.cells);
  eq(rows[0][0], "Base (unweighted)", "primary base row relabelled");
  eq(rows[0][1], "412", "unweighted n");
  eq(rows[1][0], "Base (weighted)", "weighted base row present");
  eq(rows[1][1], "640", "Total weighted base");
  eq(rows[1][2], "310", "Male weighted base");
  eq(rows[2][0], "Effective base", "effective base row present");
  eq(rows[2][1], "371", "Total effective base");
  eq(m.body[1].kind, "base", "weighted row styled as a base row");
  eq(m.body[2].kind, "base", "effective row styled as a base row");
});

run("matrix base rows honour show_weighted_base / show_effective_n flags", () => {
  const model = weightedModel();
  TR.AGG.project.show_weighted_base = false;
  let labels = TR.render.matrix(model).body.map((r) => r.cells[0]);
  assert(labels.indexOf("Base (weighted)") === -1, "weighted row dropped by flag");
  assert(labels.indexOf("Effective base") !== -1, "effective row still shows");
  TR.AGG.project.show_weighted_base = true;
  TR.AGG.project.show_effective_n = false;
  labels = TR.render.matrix(model).body.map((r) => r.cells[0]);
  assert(labels.indexOf("Base (weighted)") !== -1, "weighted row back");
  assert(labels.indexOf("Effective base") === -1, "effective row dropped by flag");
});

run("unweighted report keeps the single 'Base (n=)' matrix row (byte-identical)", () => {
  const model = weightedModel();
  TR.AGG = { project: { name: "Unweighted", weighted: false } };
  const m = TR.render.matrix(model);
  eq(m.body[0].cells[0], "Base (n=)", "plain label when unweighted");
  eq(m.body.filter((r) => r.kind === "base").length, 1, "exactly one base row");
});

run("weighted base rows land in TSV and carry '–' for a column missing baseW", () => {
  const model = weightedModel();
  TR.AGG = { project: { weighted: true } };
  delete model.columns[1].baseW;
  const tsv = TR.render.tsv(model);
  assert(tsv.indexOf("Base (weighted)\t640\t–") !== -1,
    "TSV weighted row: label, Total 640, missing Male as en dash");
  assert(tsv.indexOf("Effective base\t371\t180") !== -1, "TSV effective row");
});

/* ---------------- 6. WP3–WP5 deck spine: cover, order, quotes, appendix -------- */
// Real exporter + real story assembler (30_story) and exhibit engine (30x)
// over minimal state stubs — the asserts run against genuine slide XML.

vm.runInContext(readFileSync(path.join(JS_DIR, "30_story.js"), "utf8"), sandbox,
  { filename: "30_story.js" });
vm.runInContext(readFileSync(path.join(JS_DIR, "30x_exhibit.js"), "utf8"), sandbox,
  { filename: "30x_exhibit.js" });

function storyDeckSetup() {
  TR.AGG = { project: { name: "Deck fixture", client: "CCS", wave: "Wave 12",
    brand_colour: "#123ABC" }, questions: [], banner_groups: [] };
  TR.d2 = { storeKey: (b) => b, bannerDescription: () => "All respondents",
    tracking: () => ({ enabled: false, waves: [] }),
    questionByCode: () => null, state: { filters: [] } };
  TR.insights = { get: () => "" };
  TR.shell = { toast: () => {} };
  TR.views = { _indexQuestions: () => [],
    _heatMatrix: () => ({ head: ["Metric"], rows: [] }) };
  TR.report = { sectionText: (s) =>
    s === "exec" ? "Overall service holds up.\nSecond paragraph." : "" };
  TR.conf = { methodNote: () => "Wilson 95%" };
}

const quotePin = { kind: "snapshot", source: "qualitative",
  title: "Masters want faster support", context: "3 of 9 comments", html: "",
  lines: ["x"], moreN: 1, note: "",
  quotes: [{ text: "slow support", q: "Anything else?", tags: ["Durban"],
    sentiment: "neg" }] };
const oldPin = { kind: "snapshot", source: "patterns", title: "Old pinned card",
  context: "", html: "", lines: ["line one"], note: "" };
const heatPin = { kind: "heatmap", banner: "", filters: [], note: "" };
const xmlOf = (s) => (typeof s === "string" ? s : s.xml);

run("deck spine: cover leads, quote slide, divider 01, old-pin table, Detail 02", () => {
  storyDeckSetup();
  const slides = TR.story2._slidesFor([
    quotePin, { kind: "divider", title: "Part 2", note: "" }, heatPin, oldPin]);
  eq(slides.length, 6, "cover + quote + divider + old pin + Detail divider + heatmap");
  const cover = xmlOf(slides[0]);
  assert(cover.indexOf("Deck fixture") !== -1, "cover carries the project name");
  assert(cover.indexOf("Overall service holds up.") !== -1,
    "cover carries the authored exec summary");
  assert(cover.indexOf("Masters want faster support") !== -1,
    "cover lists pin titles as insight lines");
  assert(cover.indexOf("Old pinned card") !== -1, "every evidence pin named");
  assert(cover.indexOf("Turas · The Research LampPost") !== -1, "wordmark on the cover");
  assert(cover.indexOf("Part 2") === -1, "dividers are structure, not findings");
  const quote = xmlOf(slides[1]);
  assert(quote.indexOf(">“<") !== -1, "quote glyph on the qual pin's slide");
  assert(quote.indexOf("<a:tbl>") === -1, "new quotes payload is never a table");
  assert(quote.indexOf("Anything else? · Durban · Negative") !== -1,
    "attribution chip line under the quote");
  assert(quote.indexOf("+1 more in the report") !== -1, "pin overflow in the footer");
  assert(xmlOf(slides[2]).indexOf("Part 2") !== -1 &&
    xmlOf(slides[2]).indexOf(">01<") !== -1, "story divider numbered 01");
  assert(xmlOf(slides[3]).indexOf("<a:tbl>") !== -1,
    "OLD pin (no quotes payload) keeps the table fallback");
  assert(xmlOf(slides[3]).indexOf("line one") !== -1, "old pin lines rendered");
  assert(xmlOf(slides[4]).indexOf("Detail") !== -1 &&
    xmlOf(slides[4]).indexOf(">02<") !== -1,
    "matrix pins group behind a numbered Detail divider");
  assert(xmlOf(slides[5]).indexOf("Index heatmap") !== -1,
    "heatmap slide after the Detail divider");
  assert(slides.every((s) => xmlOf(s).indexOf(TR.pptx.PAGE_TOKEN) === -1),
    "page tokens resolved across the deck");
});

run("appendix flag: marked pins move behind an Appendix divider, APPENDIX kicker", () => {
  storyDeckSetup();
  const slides = TR.story2._slidesFor([
    Object.assign({}, oldPin), Object.assign({}, heatPin, { appendix: true })]);
  eq(slides.length, 4, "cover + pin + Appendix divider + appendix slide");
  assert(xmlOf(slides[2]).indexOf("Appendix") !== -1, "Appendix divider");
  assert(xmlOf(slides[3]).indexOf("APPENDIX") !== -1, "appendix slide kicker");
  // with explicit appendix marks, unmarked matrix pins keep their story place
  const keep = TR.story2._slidesFor([
    Object.assign({}, heatPin), Object.assign({}, oldPin, { appendix: true })]);
  assert(xmlOf(keep[1]).indexOf("Index heatmap") !== -1,
    "analyst-marked decks are never re-sorted");
});

run("an all-tables deck keeps its order — no Detail divider inserted", () => {
  storyDeckSetup();
  const slides = TR.story2._slidesFor([
    Object.assign({}, heatPin), Object.assign({}, heatPin)]);
  eq(slides.length, 3, "cover + two heatmaps, nothing inserted");
});

run("WP5: exhibit trend slide carries the wave-delta chip and the CI note", () => {
  storyDeckSetup();
  TR.AGG.project.wave_order = 11;
  TR.d2.questionByCode = (c) => ({ code: c, title: "KPI" });
  TR.trk = { points: () => [{ year: 9, value: 50 },
    { year: 10, value: 55, change_prev: 5, sig_prev: true, current: true }] };
  const model = { code: "Q1", title: "KPI question",
    columns: [{ label: "Total", base: 200 }],
    rows: [{ kind: "net", label: "Top2 (NET)", waves: [], cells: [{ pct: 55 }] }] };
  TR.model = { forQuestion: () => model };
  const item = { kind: "exhibit", qs: ["Q1"], banner: "", filters: [], ci: true,
    series: [{ code: "Q1", ri: 0, seg: "total", label: "Total" }],
    flags: { dist: false, trend: true, table: false, insight: true }, note: "" };
  const slide = TR.exhibit.slide(item);
  assert(slide.xml.indexOf("▲ +5pp •") !== -1, "delta chip from the headline series");
  assert(slide.xml.indexOf("Wilson 95% confidence bands shown") !== -1,
    "CI note in the footer when interval bands are pinned on");
  const noCi = TR.exhibit.slide(Object.assign({}, item, { ci: false }));
  assert(noCi.xml.indexOf("confidence bands shown") === -1, "no CI note when bands off");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
