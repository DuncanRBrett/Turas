#!/usr/bin/env node
/**
 * PPTX boardroom style gate (PPTX_BOARDROOM_SPEC.md WP0–WP2) — regressions
 * where the editable deck drifted from the boardroom template:
 *   - WP0: TR.pptx.STYLE is the single style source (Arial theme + text runs,
 *     no ad-hoc sizes/colours in the slide builders), shared header/footer
 *     chrome on every content slide;
 *   - WP1: metadata footer everywhere — question text, n= (weighted Σw +
 *     effective n on weighted reports), sig note, wave, Turas wordmark, page
 *     numbers; question code demoted from the title to the subtitle;
 *   - WP2: emphasis series in brand vs muted context greys, data labels on
 *     the emphasis series only, honest axes (scale_min/scale_max, % floor 25
 *     cap 100), ▲▼ sig marker boxes, charts still natively editable.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/pptx_style_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console, TextEncoder };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const file of ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js",
  "14_pptx_parts.js", "23_render.js", "23z_charts.js", "23za_trend.js",
  "23y_xlsx.js", "29_export.js"]) {
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });
}
const TR = sandbox.TR;
const STYLE = TR.pptx.STYLE;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) { if (a !== b) throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a)); }
function at(hay, needle, msg) {
  if (String(hay).indexOf(needle) === -1) throw new Error(msg + ": missing " + JSON.stringify(needle));
}
function notAt(hay, needle, msg) {
  if (String(hay).indexOf(needle) !== -1) throw new Error(msg + ": unexpected " + JSON.stringify(needle));
}
function count(hay, needle) {
  return String(hay).split(needle).length - 1;
}

/* ---------------- fixtures ---------------- */

function proj(extra) {
  TR.AGG = { project: Object.assign(
    { name: "Style fixture", wave: "Wave 3", brand_colour: "#123ABC" }, extra || {}) };
}

// single Total column, plain (non-sentiment) categories, small values
function flatModel() {
  proj();
  return {
    code: "Q7", title: "Which channel did you use?", category: "Service",
    columns: [{ label: "Total", base: 412 }],
    rows: [
      { kind: "category", label: "Branch", cells: [{ pct: 8 }] },
      { kind: "category", label: "App", cells: [{ pct: 6 }] },
      { kind: "category", label: "Call centre", cells: [{ pct: 3 }] }
    ]
  };
}

function twoColModel() {
  proj();
  return {
    code: "Q8", title: "Satisfaction by cut", category: "Service",
    columns: [{ label: "Total", base: 400 }, { label: "Male", base: 190 }],
    rows: [
      { kind: "category", label: "Branch", cells: [{ pct: 62 }, { pct: 58 }] },
      { kind: "category", label: "App", cells: [{ pct: 30 }, { pct: 34 }] }
    ]
  };
}

function sentimentModel() {
  proj({ chart_palette: { negative: "#D0021B", mod_negative: "#E98A00",
    neutral: "#B8B8B8", mod_positive: "#7ED321", positive: "#1B8E3E",
    dk_na: "#999999", other: "#777777" } });
  return {
    code: "Q9", title: "NPS groups", category: "Loyalty",
    columns: [{ label: "Total", base: 400 }],
    rows: [
      { kind: "category", label: "Detractor (0-6)", cells: [{ pct: 20 }] },
      { kind: "category", label: "Passive (7-8)", cells: [{ pct: 30 }] },
      { kind: "category", label: "Promoter (9-10)", cells: [{ pct: 50 }] }
    ]
  };
}

function meanModel() {
  proj();
  return {
    code: "Q10", title: "Rate the service", category: "Service", valueKind: "mean",
    scale_min: 1, scale_max: 5,
    columns: [{ label: "Total", base: 400 }, { label: "Male", base: 190 }],
    rows: [{ kind: "mean", label: "Mean rating",
      cells: [{ mean: 4.1 }, { mean: 3.9 }] }]
  };
}

function weightedModel() {
  proj({ weighted: true });
  return {
    code: "Q4", title: "Weighted question", category: "Profile",
    columns: [{ label: "Total", base: 412, baseW: 640, baseEff: 371 }],
    rows: [{ kind: "category", label: "Yes", cells: [{ pct: 55 }] }]
  };
}

function sigModel() {
  proj();
  return {
    code: "Q11", title: "KPI with wave movement", category: "KPI",
    columns: [{ label: "Total", base: 400 }],
    rows: [
      { kind: "category", label: "Up a lot",
        cells: [{ pct: 48 }], delta: { diff: 6, sig: true, isMean: false } },
      { kind: "category", label: "Down a lot",
        cells: [{ pct: 22 }], delta: { diff: -5, sig: true, isMean: false } },
      { kind: "category", label: "Flat",
        cells: [{ pct: 30 }], delta: { diff: 1, sig: false, isMean: false } }
    ]
  };
}

console.log("PPTX boardroom style — suite:");

/* ---------------- WP0: style foundation ---------------- */

run("TR.pptx.STYLE carries the spec constants (font, palette, scale, grid)", () => {
  eq(STYLE.FONT, "Arial", "one face");
  eq(STYLE.INK, "1C2333", "ink");
  eq(STYLE.CONTEXT.join(","), "AEB4C2,C6CBD6,8F97A8,D8DCE5", "context greys");
  eq(STYLE.SIZE.title, 20, "title step");
  eq(STYLE.SIZE.footer, 8.5, "footer step");
  eq(STYLE.MARGIN, 0.6, "margin");
  eq(STYLE.BODY.y, 1.86, "body top");
  eq(STYLE.FOOTER.rule.y, 6.72, "footer hairline y");
});

run("theme fonts are Arial — no Calibri anywhere in the package", () => {
  proj();
  const bytes = TR.pptx.package([TR.exporter.dividerSlide("Section", "sub")],
    { project: TR.AGG.project });
  const pkg = Buffer.from(bytes).toString("latin1");
  at(pkg, '<a:majorFont><a:latin typeface="Arial"/>', "major font Arial");
  at(pkg, '<a:minorFont><a:latin typeface="Arial"/>', "minor font Arial");
  notAt(pkg, "Calibri", "Calibri fully retired");
});

run("every latin run on a slide + its chart is Arial (no text/chart mismatch)", () => {
  const slide = TR.exporter.slideForModel(twoColModel(), "A note.",
    { chart: true, table: true, insight: true, chartType: "bar", chartCols: [0, 1] });
  const all = slide.xml + slide.charts.map((c) => c.xml).join("");
  const faces = [...all.matchAll(/<a:latin typeface="([^"]*)"/g)].map((m) => m[1]);
  assert(faces.length > 0, "latin runs present");
  assert(faces.every((f) => f === "Arial"), "every typeface Arial, got: " +
    [...new Set(faces)].join(","));
});

run("no ad-hoc font sizes or colour literals left in the slide builders", () => {
  const src = readFileSync(path.join(JS_DIR, "29_export.js"), "utf8");
  assert(!/[{,(\s]size: \d/.test(src), "para sizes all flow from STYLE.SIZE");
  assert(!/colour: "[0-9A-Fa-f]{6}"/.test(src), "para colours all flow from STYLE");
});

run("content slides share the header/footer grid (brand rule, hairline, zones)", () => {
  const slide = TR.exporter.slideForModel(flatModel(), "", { table: true });
  const inch = (v) => Math.round(v * 914400);
  at(slide.xml, '<a:off x="0" y="0"/><a:ext cx="' + inch(13.333) + '" cy="' +
    inch(0.06) + '"/>', "full-width brand header rule at spec height");
  at(slide.xml, '<a:off x="' + inch(0.6) + '" y="' + inch(6.72) + '"/>',
    "footer hairline on the grid");
  at(slide.xml, '<a:off x="' + inch(10.8) + '" y="' + inch(6.8) + '"/>',
    "footer right (wordmark/page) box on the grid");
  at(slide.xml, 'val="123ABC"', "brand rule in project brand colour");
});

/* ---------------- WP1: metadata everywhere ---------------- */

run("footer carries question text, n=, wave, wordmark and page tokens", () => {
  const slide = TR.exporter.slideForModel(flatModel(), "", { table: true });
  at(slide.xml, "Q7 · Which channel did you use?", "question code + full text");
  at(slide.xml, "n=412", "unweighted base");
  at(slide.xml, "Turas · Wave 3 · " + TR.pptx.PAGE_TOKEN + "/" + TR.pptx.PAGE_TOTAL_TOKEN,
    "wordmark · wave · page tokens footer-right");
});

run("question code moves out of the title into the subtitle", () => {
  const slide = TR.exporter.slideForModel(flatModel(), "",
    { table: true, title: "Branch still dominates" });
  at(slide.xml, "Branch still dominates", "insight title leads");
  notAt(slide.xml, "Q7 — ", "no code prefix on the title");
  at(slide.xml, "SERVICE", "category kicker in grey caps");
});

run("weighted reports add Σw and effective n to the footer base", () => {
  const slide = TR.exporter.slideForModel(weightedModel(), "", { table: true });
  at(slide.xml, "n=412 (weighted 640 · effective 371)", "full weighted base line");
});

run("footer base honours show_weighted_base / show_effective_n", () => {
  const model = weightedModel();
  TR.AGG.project.show_weighted_base = false;
  const noW = TR.exporter.slideForModel(model, "", { table: true });
  notAt(noW.xml, "weighted 640", "weighted segment dropped by flag");
  at(noW.xml, "n=412 (effective 371)", "effective still shows");
  TR.AGG.project.show_weighted_base = true;
  TR.AGG.project.show_effective_n = false;
  const noE = TR.exporter.slideForModel(model, "", { table: true });
  notAt(noE.xml, "effective 371", "effective segment dropped by flag");
});

run("a pin without question/base fields drops those segments gracefully", () => {
  proj();
  const xml = TR.exporter.matrixSlide("Index heatmap", "context line",
    { head: ["Metric", "Total"], body: [{ kind: "row", cells: ["KPI", "7.2"] }] },
    { kicker: "Dashboard" });
  notAt(xml, "<a:t>n=", "no orphan base segment");
  at(xml, "Turas · Wave 3", "wordmark + wave still present");
  at(xml, "DASHBOARD", "kicker present");
  at(xml, TR.pptx.PAGE_TOKEN, "page token present");
});

run("exhibit slides carry the same chrome with a Tracking kicker", () => {
  proj();
  const slide = TR.exporter.exhibitSlide({ title: "KPI over waves",
    meta: "Series: Total · published wave history", charts: [], matrix: null, note: "" });
  at(slide.xml, "TRACKING", "default kicker");
  at(slide.xml, "Turas · Wave 3", "footer wordmark");
  at(slide.xml, TR.pptx.PAGE_TOKEN, "page token");
});

run("paginate resolves page tokens across the deck", () => {
  proj();
  const slides = [TR.exporter.titleSlide(1),
    TR.exporter.slideForModel(flatModel(), "", { table: true })];
  TR.exporter.paginate(slides);
  at(slides[1].xml, "2/2", "page 2 of 2 on the content slide");
  notAt(slides[1].xml, TR.pptx.PAGE_TOKEN, "no unresolved tokens");
  notAt(slides[0], TR.pptx.PAGE_TOKEN, "cover has no tokens");
});

/* ---------------- WP2: chart restyle ---------------- */

run("multi-series: emphasis series in brand, context series in muted grey", () => {
  const chart = TR.exporter.buildChart(twoColModel(), "bar", [0, 1]);
  const sers = chart.xml.split("<c:ser>").slice(1);
  eq(sers.length, 2, "two series");
  at(sers[0], 'val="123ABC"', "series 0 = brand");
  at(sers[1], 'val="' + STYLE.CONTEXT[0] + '"', "series 1 = first context grey");
  notAt(sers[1], 'val="123ABC"', "context series never brand");
});

run("data labels sit on the emphasis series only", () => {
  const chart = TR.exporter.buildChart(twoColModel(), "bar", [0, 1]);
  eq(count(chart.xml, "<c:dLbls>"), 1, "exactly one dLbls block");
  const sers = chart.xml.split("<c:ser>").slice(1);
  at(sers[0], "<c:dLbls>", "labels on series 0");
  notAt(sers[1], "<c:dLbls>", "no labels on the context series");
});

run("single-series non-sentiment bars: all grey with the headline row in brand", () => {
  const chart = TR.exporter.buildChart(flatModel(), "bar", [0]);
  eq(chart.sentiment, false, "not flagged as sentiment");
  const fills = [...chart.xml.matchAll(/<c:dPt>.*?val="([0-9A-F]{6})"/g)].map((m) => m[1]);
  eq(fills.length, 3, "one dPt per bar");
  eq(fills.filter((f) => f === "123ABC").length, 1, "exactly one brand bar");
  eq(fills.filter((f) => f === STYLE.CONTEXT[0]).length, 2, "the rest context grey");
  eq(fills[0], "123ABC", "the headline (max value) row carries the brand");
});

run("sentiment scales keep the semantic palette and flag it for the footer", () => {
  const model = sentimentModel();
  const chart = TR.exporter.buildChart(model, "bar", [0]);
  eq(chart.sentiment, true, "sentiment flag set");
  at(chart.xml, 'val="D0021B"', "negative red kept");
  at(chart.xml, 'val="1B8E3E"', "positive green kept");
  const slide = TR.exporter.slideForModel(model, "",
    { chart: true, table: false, chartType: "bar", chartCols: [0] });
  at(slide.xml, "bar colours mark sentiment", "footer names the colour meaning");
});

run("percent axes are honest: anchored at 0, floored at 25, capped at 100", () => {
  const small = TR.exporter.buildChart(flatModel(), "bar", [0]);   // max 8%
  at(small.xml, '<c:max val="25"/>', "tiny distribution cannot inflate past the 25 floor");
  at(small.xml, '<c:min val="0"/>', "min anchored at 0");
  const big = TR.exporter.buildChart(twoColModel(), "column", [0, 1]);   // max 62%
  at(big.xml, '<c:max val="75"/>', "niceMax kept when between floor and cap");
});

run("mean axes consume the question's declared scale_min/scale_max", () => {
  const chart = TR.exporter.buildChart(meanModel(), "column", [0, 1]);
  at(chart.xml, '<c:max val="5"/>', "scale_max honoured");
  at(chart.xml, '<c:min val="1"/>', "scale_min honoured");
});

run("category axis dressed with the 0.75pt FAINT line, charts stay editable", () => {
  const chart = TR.exporter.buildChart(flatModel(), "bar", [0]);
  at(chart.xml, '<c:spPr><a:ln w="9525"><a:solidFill><a:srgbClr val="' +
    STYLE.FAINT + '"/>', "faint category axis line");
  at(chart.xml, '<c:externalData r:id="rId1">', "Edit Data link intact");
  assert(chart.workbook && chart.workbook.length > 0, "embedded workbook present");
});

run("significant wave deltas draw ▲▼ marker boxes and the footer sig note", () => {
  const slide = TR.exporter.slideForModel(sigModel(), "",
    { chart: true, table: false, chartType: "bar", chartCols: [0] });
  eq(count(slide.xml, ">▲<"), 1, "one up marker");
  eq(count(slide.xml, ">▼<"), 1, "one down marker");
  at(slide.xml, 'val="' + STYLE.GOOD + '"', "up marker in GOOD green");
  at(slide.xml, 'val="' + STYLE.BAD + '"', "down marker in BAD red");
  at(slide.xml, "▲▼ = 95% significance vs prior wave", "plain-language footer note");
});

run("no markers or sig note without significant deltas / off-Total emphasis", () => {
  const plain = TR.exporter.slideForModel(flatModel(), "",
    { chart: true, table: false, chartType: "bar", chartCols: [0] });
  notAt(plain.xml, ">▲<", "no markers without deltas");
  notAt(plain.xml, "significance vs prior wave", "no sig note without markers");
  const offTotal = TR.exporter.slideForModel(sigModel(), "",
    { chart: true, table: false, chartType: "bar", chartCols: [0, 0] });
  at(offTotal.xml, ">▲<", "Total emphasis still marked");
  const cut = TR.exporter.slideForModel(twoColModel(), "",
    { chart: true, table: false, chartType: "bar", chartCols: [1] });
  notAt(cut.xml, ">▲<", "non-Total emphasis gets no wave markers");
});

run("trend chart: emphasis line in brand, context grey, labels on emphasis only", () => {
  proj();
  const model = {
    code: "Q1", title: "KPI over waves", chartKind: "summary",
    columns: [{ label: "Total", base: 200 }],
    rows: [
      { kind: "net", label: "Top2 (NET)",
        waves: [{ year: 9, value: 50 }, { year: 10, value: 55 }],
        cells: [{ pct: 62 }] },
      { kind: "net", label: "Bottom2 (NET)",
        waves: [{ year: 9, value: 20 }, { year: 10, value: 18 }],
        cells: [{ pct: 15 }] }
    ]
  };
  TR.AGG.project.wave_order = 11;
  const chart = TR.exporter.buildTrendChart(model);
  const sers = chart.xml.split("<c:ser>").slice(1);
  at(sers[0], 'val="123ABC"', "emphasis wave line in brand");
  at(sers[1], 'val="' + STYLE.CONTEXT[0] + '"', "context wave line grey");
  eq(count(chart.xml, "<c:dLbls>"), 1, "labels on the emphasis series only");
});

/* ---------------- WP3: exec-summary cover + numbered dividers ---------------- */

run("coverSlide: brand edge, REPORT kicker, head, exec text + numbered findings", () => {
  proj({ client: "CCS", wave: "Wave 3" });
  const xml = TR.exporter.coverSlide({
    exec: "Overall service holds up.\nSecond paragraph here.",
    findings: ["Registration is the pain point", "Value beats price"] });
  const inch = (v) => Math.round(v * 914400);
  at(xml, '<a:ext cx="' + inch(0.18) + '" cy="' + inch(7.5) + '"/>',
    "full-height brand rule down the left edge");
  at(xml, 'val="123ABC"', "edge in the project brand colour");
  at(xml, ">REPORT<", "cover kicker");
  at(xml, ">Style fixture<", "project name");
  at(xml, "CCS · Wave 3 · ", "client · wave · date line");
  at(xml, "Overall service holds up.", "authored exec summary, para 1");
  at(xml, "Second paragraph here.", "exec summary para 2");
  at(xml, "Registration is the pain point", "finding 1 as an insight line");
  at(xml, "Value beats price", "finding 2 as an insight line");
  at(xml, ">1<", "gold chip number 1");
  at(xml, ">2<", "gold chip number 2");
  at(xml, "Turas · The Research LampPost", "text wordmark (cover only)");
  notAt(xml, TR.pptx.PAGE_TOKEN, "no page tokens on the cover");
});

run("coverSlide degrades to a clean title cover without exec text / findings", () => {
  proj({ client: "CCS", wave: "Wave 3" });
  const xml = TR.exporter.coverSlide({});
  at(xml, ">Style fixture<", "project name still leads");
  eq(count(xml, 'prst="roundRect"'), 0, "no finding chips when there are no findings");
  notAt(xml, "exhibits · built natively", "no machine-y title-slide copy");
});

run("dividerSlide: 20%-alpha two-digit ordinal when numbered; unnumbered stays clean", () => {
  proj();
  const numbered = TR.exporter.dividerSlide("Drivers of choice", "", { num: 2 });
  at(numbered, ">02<", "two-digit section ordinal");
  at(numbered, '<a:srgbClr val="FFFFFF"><a:alpha val="20000"/></a:srgbClr>',
    "ordinal at 20%-alpha white");
  at(numbered, "Drivers of choice", "title kept");
  const plain = TR.exporter.dividerSlide("Section", "sub");
  notAt(plain, "<a:alpha", "no ordinal without a number (back-compat)");
});

/* ---------------- WP4: verbatim quote slide ---------------- */

const QUOTES = [
  { text: "Great value for money", q: "Why recommend?", tags: ["Female", "25–34"], sentiment: "pos" },
  { text: "Support is too slow", q: "Anything else?", tags: ["Male"], sentiment: "neg" },
  { text: "It is fine I suppose", q: "Anything else?", tags: [], sentiment: "neu" }
];

run("quoteSlide: quote typography — glyph, italic quote, attribution, NO table", () => {
  proj();
  const slide = TR.exporter.quoteSlide({ title: "Masters",
    meta: "Faster support wanted", quotes: QUOTES, moreN: 0, note: "" });
  at(slide.xml, ">“<", "gold opening-quote glyph");
  at(slide.xml, 'i="1"', "quote runs italic");
  at(slide.xml, "Great value for money", "quote text");
  at(slide.xml, "Why recommend? · Female · 25–34 · Positive",
    "attribution chip: question · demo tags · sentiment word");
  at(slide.xml, "Anything else? · Male · Negative", "negative attribution");
  at(slide.xml, "Anything else? · Mixed", "tag-less quote still names its sentiment");
  notAt(slide.xml, "<a:tbl>", "never a one-column table");
  at(slide.xml, 'val="' + STYLE.GOOD + '"', "positive sentiment edge");
  at(slide.xml, 'val="' + STYLE.BAD + '"', "negative sentiment edge");
  at(slide.xml, "VERBATIMS", "default kicker");
  at(slide.xml, "Faster support wanted", "insight in the subtitle");
});

run("quoteSlide caps at 4 quotes and counts the rest in the footer", () => {
  proj();
  const many = Array.from({ length: 6 }, (_, i) => (
    { text: "Quote number " + i, q: "Q", tags: [], sentiment: "neu" }));
  const slide = TR.exporter.quoteSlide({ title: "Big", quotes: many, moreN: 2 });
  at(slide.xml, "Quote number 3", "fourth quote shown");
  notAt(slide.xml, "Quote number 4", "fifth quote dropped");
  at(slide.xml, "+4 more in the report",
    "footer counts slide overflow (2) + pin overflow (2)");
});

run("quoteSlide renders the analyst note as the gold callout band", () => {
  proj();
  const slide = TR.exporter.quoteSlide({ title: "T", quotes: QUOTES.slice(0, 1),
    note: "The verbatims explain the drop." });
  at(slide.xml, "ANALYST INSIGHT", "callout band present");
  at(slide.xml, "The verbatims explain the drop.", "note text in the band");
});

/* ---------------- WP5: wave-delta chip + CI note on exhibit slides ------------ */

run("exhibitSlide: delta chip on the callout chrome + CI note in the footer", () => {
  proj();
  const slide = TR.exporter.exhibitSlide({ title: "KPI", meta: "", charts: [],
    matrix: null, note: "", chip: { text: "▲ +4pp •", up: true },
    footer: { notes: ["Wilson 95% confidence bands shown"] } });
  at(slide.xml, "▲ +4pp •", "delta chip text");
  at(slide.xml, 'val="' + STYLE.CALLOUT_BG + '"', "chip on the callout background");
  at(slide.xml, 'val="' + STYLE.GOOD + '"', "up chip edged GOOD");
  at(slide.xml, "Wilson 95% confidence bands shown", "CI note in the footer-mid");
  const down = TR.exporter.exhibitSlide({ title: "KPI", meta: "", charts: [],
    matrix: null, note: "", chip: { text: "▼ −2pp", up: false } });
  at(down.xml, 'val="' + STYLE.BAD + '"', "down chip edged BAD");
  const none = TR.exporter.exhibitSlide({ title: "KPI", meta: "", charts: [],
    matrix: null, note: "" });
  notAt(none.xml, 'val="' + STYLE.CALLOUT_BG + '"', "no chip chrome without a chip");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
