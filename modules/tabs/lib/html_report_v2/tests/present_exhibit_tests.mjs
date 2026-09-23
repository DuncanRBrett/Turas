#!/usr/bin/env node
/**
 * The distribution + trend exhibit as a boardroom slide. Contracts:
 *
 * E1 A mean trend runs over the question's declared scale (a 1 to 5 score on
 *    0 to 5, one gridline per point), not the fixed 0 to 10 that flattened
 *    the line into the middle of an empty chart. A model with no declared
 *    scale (Visualise, composites) keeps the 0 to 10 axis and its quarters.
 * E2 The first wave's value label starts at its point, clear of the axis
 *    tick labels; the footnote sits a clear line under the wave labels and a
 *    legend sits under the footnote, never on it.
 * E3 An exhibit's insight is the pin's note, else, for a one-question pin,
 *    that question's own insight, the rule a question pin already follows.
 * E4 Each panel of a one-question exhibit is captioned on the slide: this
 *    wave, and the trend's series and span.
 * E5 On the Present stage the insight sits in its callout box and the panels
 *    in one captioned exhibit card.
 * E6 The slide's context line says who is charted and how many answered,
 *    never the banner and history source the Story card shows an analyst.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/present_exhibit_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";
import { installText } from "./_text.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const load = (sb, file) =>
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sb, { filename: file });

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

/* ---------------- fixtures ---------------- */

/** A tracked agreement question: 1 to 5 mean with three prior waves. */
function meanRow(label, values, current) {
  return { kind: "mean", label: label, cells: [{ pct: null, mean: current }],
    waves: values.map((v, i) => ({ year: 2023 + i, value: v, base: 480 })) };
}
function pctRow(label, values, current) {
  return { kind: "net", label: label, cells: [{ pct: current, mean: null }],
    waves: values.map((v, i) => ({ year: 2023 + i, value: v, base: 480 })) };
}
function q07Model(rows, scaleMax) {
  const m = { code: "Q07", title: "I have the opportunity to do what I am best at",
    chartKind: "summary", columns: [{ label: "Total", base: 500 }], rows: rows };
  if (scaleMax !== undefined) m.scale_max = scaleMax;
  return m;
}

/** A sandbox with the renderers and the exhibit engine; `questions` feeds
 *  questionByCode (scale_min), `insight` the question's own insight. */
function sandbox(opts) {
  opts = opts || {};
  const sb = { console, TextEncoder, atob,
    localStorage: { getItem: () => null, setItem: () => {}, removeItem: () => {} } };
  sb.globalThis = sb;
  sb.window = sb;
  vm.createContext(sb);
  for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "21_stats.js",
    "23_render.js", "23z_charts.js", "23za_trend.js"]) load(sb, f);
  installText(sb);
  const TR = sb.TR;
  TR.AGG = { project: { name: "SACS 2026", wave: "SACS 2026" }, questions: [],
    banner_groups: [] };
  const questions = opts.questions || {};
  TR.d2 = { questionByCode: (c) => questions[c] || null, state: { tab: "story", filters: [] },
    tracking: () => ({ enabled: true, waves: [] }), storeKey: (b) => b + ":x",
    bannerDescription: (b) => "Banner: " + b };
  TR.trk = { yLabel: (y) => "SACS " + y };
  TR.insights = { get: (code) => (opts.insight && code === "Q07" ? opts.insight : "") };
  TR.model = { forQuestion: () => opts.model || null };
  load(sb, "30x_exhibit.js");
  return sb;
}

const ticks = (svg) => [...svg.matchAll(/text-anchor="end"[^>]*>([^<]+)</g)].map((m) => m[1]);

console.log("Present exhibit (distribution + trend as a slide): suite:");

/* ---------------- E1: the declared scale ------------------------------------ */

run("E1: a 1 to 5 mean runs on 0 to 5 with a gridline per point", () => {
  const TR = sandbox({}).TR;
  const svg = TR.render.trendChart(q07Model([meanRow("Mean", [4.2, 4.2, 4.1], 4.2)], 5));
  eq(ticks(svg), ["0", "1", "2", "3", "4", "5"], "ticks");
});

run("E1: a declared Scale_Min starts the axis there", () => {
  const TR = sandbox({ questions: { Q07: { code: "Q07", scale_min: 1, scale_max: 5 } } }).TR;
  const svg = TR.render.trendChart(q07Model([meanRow("Mean", [4.2, 4.2, 4.1], 4.2)], 5));
  eq(ticks(svg), ["1", "2", "3", "4", "5"], "ticks");
});

run("E1: no declared scale keeps the 0 to 10 axis in quarters", () => {
  const TR = sandbox({}).TR;
  const svg = TR.render.trendChart(q07Model([meanRow("Mean", [4.2, 4.2, 4.1], 4.2)]));
  eq(ticks(svg), ["0", "2.5", "5", "7.5", "10"], "ticks unchanged");
  const ten = TR.render.trendChart(q07Model([meanRow("Mean", [7.1, 7.4, 7.2], 7.5)], 10));
  eq(ticks(ten), ["0", "2.5", "5", "7.5", "10"], "a declared 0 to 10 scale is unchanged too");
});

run("E1: a value above a mis-declared maximum still shows", () => {
  const TR = sandbox({}).TR;
  const svg = TR.render.trendChart(q07Model([meanRow("Mean", [4.2, 5.6, 4.1], 4.2)], 5));
  const top = ticks(svg).slice(-1)[0];
  assert(parseFloat(top) >= 5.6, "the axis reaches the value, got top " + top);
});

/* ---------------- E2: labels and footnote ----------------------------------- */

run("E2: the first wave's label starts at its point, the rest are centred", () => {
  const TR = sandbox({}).TR;
  const svg = TR.render.trendChart(q07Model([meanRow("Mean", [4.2, 4.2, 4.1], 4.2)], 5));
  const labels = [...svg.matchAll(/<text x="([\d.]+)"[^>]*text-anchor="(start|middle)"[^>]*font-size="9.5"[^>]*>(4\.\d)</g)]
    .map((m) => [m[2], m[3]]);
  eq(labels[0], ["start", "4.2"], "first point");
  assert(labels.slice(1).every((l) => l[0] === "middle"), "the others centred: " +
    JSON.stringify(labels));
});

run("E2: the footnote clears the wave labels and the legend clears the footnote", () => {
  const TR = sandbox({}).TR;
  const svg = TR.render.trendChart(q07Model([
    pctRow("Agree", [81, 80, 78], 82), pctRow("Neutral", [12, 13, 14], 12)]));
  const yOf = (re) => { const m = re.exec(svg); assert(m, "found " + re); return parseFloat(m[1]); };
  const waveY = yOf(/<text x="[\d.]+" y="([\d.]+)"[^>]*>SACS 2023</);
  const noteY = yOf(/<text x="46" y="([\d.]+)"[^>]*>Published wave Totals/);
  const legendTop = yOf(/<rect x="[\d.]+" y="([\d.]+)" width="11" height="11"/);
  assert(noteY - waveY >= 16, "footnote a clear line under the wave labels: " + waveY + " / " + noteY);
  assert(legendTop > noteY + 2, "legend swatches below the footnote: " + noteY + " / " + legendTop);
});

/* ---------------- E3: the insight ------------------------------------------- */

run("E3: the pin's note wins; else a one-question pin shows its question's insight", () => {
  const TR = sandbox({ insight: "Four in five agree." }).TR;
  const pin = { kind: "exhibit", qs: ["Q07"], banner: "Dept", flags: { insight: true }, note: "" };
  eq(TR.exhibit.noteFor(pin), "Four in five agree.", "the question's insight");
  eq(TR.exhibit.noteFor(Object.assign({}, pin, { note: "Typed on the pin." })),
    "Typed on the pin.", "the note");
  eq(TR.exhibit.noteFor(Object.assign({}, pin, { flags: { insight: false } })), "",
    "pinned without the insight");
  eq(TR.exhibit.noteFor(Object.assign({}, pin, { qs: ["Q07", "Q08"] })), "",
    "a composite has no one question");
  eq(TR.exhibit.noteFor(Object.assign({}, pin, { series: [{ code: "Q07", ri: 0 }] })), "",
    "a pinned tracking view keeps its own note only");
});

/* ---------------- E4: captions ---------------------------------------------- */

run("E4: this wave, and a single series named with its span", () => {
  const model = q07Model([meanRow("Mean", [4.2, 4.2, 4.1], 4.2)], 5);
  const TR = sandbox({ model }).TR;
  const pin = { kind: "exhibit", qs: ["Q07"], flags: { dist: true, trend: true } };
  eq(TR.exhibit.captions(pin, [model]),
    { dist: "SACS 2026", trend: "Mean · SACS 2023 to SACS 2026" }, "captions");
});

run("E4: several series are named by the legend, so the caption is the span", () => {
  const model = q07Model([pctRow("Agree", [81, 80, 78], 82), pctRow("Neutral", [12, 13, 14], 12)]);
  const TR = sandbox({ model }).TR;
  const pin = { kind: "exhibit", qs: ["Q07"], flags: { dist: true, trend: true } };
  eq(TR.exhibit.captions(pin, [model]).trend, "SACS 2023 to SACS 2026", "span only");
  eq(TR.exhibit.captions(Object.assign({}, pin, { qs: ["Q07", "Q08"] }), [model, model]),
    { dist: "", trend: "" }, "a composite carries none");
});

run("E4: captions appear only when asked for (Present), never on the story card", () => {
  const model = q07Model([meanRow("Mean", [4.2, 4.2, 4.1], 4.2)], 5);
  const TR = sandbox({ model }).TR;
  const pin = { kind: "exhibit", qs: ["Q07"], flags: { dist: true, trend: true }, distType: "bar" };
  assert(TR.exhibit.panelsHtml(pin).indexOf("ex-cap") === -1, "story card: none");
  const html = TR.exhibit.panelsHtml(pin, { captions: true });
  eq((html.match(/class="ex-cap"/g) || []).length, 2, "one per panel");
  assert(html.indexOf(">SACS 2026<") !== -1 && html.indexOf(">Mean · SACS 2023 to SACS 2026<") !== -1,
    "both captions");
});

/* ---------------- E5: the Present slide ------------------------------------- */

run("E5: Present puts the insight in its box and the panels in one exhibit card", () => {
  const model = q07Model([meanRow("Mean", [4.2, 4.2, 4.1], 4.2)], 5);
  const sb = sandbox({ model, insight: "Four in five agree." });
  const TR = sb.TR;
  const overlay = { hidden: true, innerHTML: "", clientWidth: 1920, clientHeight: 1080,
    scrollTop: 0, classList: { add() {}, remove() {}, toggle() {}, contains: () => false },
    addEventListener() {}, querySelector: (s) => (s === "#pr-close" ? { addEventListener() {} } : null) };
  sb.addEventListener = () => {};
  sb.removeEventListener = () => {};
  sb.setTimeout = () => 1;
  sb.clearTimeout = () => {};
  sb.document = { documentElement: {}, fullscreenElement: null,
    getElementById: (id) => (id === "present-overlay" ? overlay : null),
    addEventListener() {}, removeEventListener() {} };
  TR.userState = { story: [{ kind: "exhibit", qs: ["Q07"], banner: "Dept", filters: [],
    flags: { dist: true, trend: true, table: false, insight: true, comments: false },
    distType: "bar", chartKind: "summary", note: "" }] };
  TR.shell = { toast() {} };
  TR.exporter = {};
  load(sb, "30_story.js");
  TR.story2.presentFrom(0);
  const h = overlay.innerHTML;
  const note = h.indexOf('<div class="pr-note">Four in five agree.</div>');
  const card = h.indexOf('<div class="pr-table pr-chart pr-exhibit">');
  assert(note !== -1, "the question's insight in its callout box");
  assert(card > note, "the exhibit card follows the insight");
  assert(h.indexOf('<p class="pr-ctx">Total (n = 500)</p>') !== -1, "the plain context line");
  assert(h.indexOf("Banner:") === -1, "no banner jargon on the slide");
  eq((h.match(/class="ex-cap"/g) || []).length, 2, "both panels captioned");
});

/* ---------------- E6: the slide's context line ----------------------------- */

run("E6: who is charted and how many; other columns note the trend is Total", () => {
  const model = q07Model([meanRow("Mean", [4.2, 4.2, 4.1], 4.2)], 5);
  model.columns = [{ label: "Total", base: 1234 }, { label: "Academic", base: 250 },
    { label: "Support", base: 984 }];
  const TR = sandbox({ model }).TR;
  const pin = { kind: "exhibit", qs: ["Q07"], banner: "Dept", filters: [],
    flags: { dist: true, trend: true }, chartCols: [0] };
  eq(TR.exhibit.slideContext(pin, [model]), "Total (n = 1\u202F234)", "Total only");
  eq(TR.exhibit.slideContext(Object.assign({}, pin, { chartCols: [1, 2] }), [model]),
    "Academic (n = 250) · Support (n = 984) · trend: Total", "two departments");
  eq(TR.exhibit.slideContext(Object.assign({}, pin, { filters: [{ q: "X" }] }), [model]),
    "Total (n = 1\u202F234) · filtered, SACS 2026 only", "a filter names its wave");
  const composite = Object.assign({}, pin, { qs: ["Q07", "Q08"] });
  eq(TR.exhibit.slideContext(composite, [model, model]),
    TR.exhibit.contextLine(composite, [model, model]), "a composite keeps the analyst line");
});

console.log((failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
if (failed) process.exit(1);
