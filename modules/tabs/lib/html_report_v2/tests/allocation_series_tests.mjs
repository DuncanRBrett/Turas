#!/usr/bin/env node
/**
 * Gate for a live-recomputed ALLOCATION (constant-sum) question.
 *
 * An Allocation publishes one MEAN row per item, so it needs k score series
 * under one question code, and TR.MICRO.scores holds exactly one number per
 * respondent. Before this the writer emitted a full column of NA for the type
 * and every filtered view of a MaxDiff share table, a conjoint importance
 * table or a wallet-share question said "n/a under filter". The series island
 * (TR.MICRO.series[code][rowIndex]) carries them instead.
 *
 * What is pinned here: each item recomputes off its OWN column, the base is
 * the published base rule (anyone with a non-NA slot, zero included), the
 * letters are the same per-item Welch R runs, a row with no series entry
 * blanks rather than borrowing a sibling's number, and the Excel export of
 * the computed view carries the recomputed figures rather than the published
 * ones.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/allocation_series_tests.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console, TextEncoder };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const file of readdirSync(JS_DIR).filter((f) => f.endsWith(".js")).sort()) {
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });
}
const TR = sandbox.TR;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function near(got, want, msg) {
  assert(got !== null && got !== undefined && Math.abs(got - want) < 0.005,
    msg + ", got " + got + ", expected " + want);
}

/* ---------------------------------------------------------------------------
 * Ten respondents split five men / five women, allocating 100 points across
 * three wallets. Respondent 10 allocated nothing at all (every slot null) and
 * must fall OUT of the base, exactly as calculate_allocation_base() drops them.
 * Respondent 9 allocated zero to Bank: zero is an answer, so they stay IN.
 *
 *   BANK    men  80 80 70 90 80   women  20 20 30 10  0
 *   RETAIL  men  10 10 20  5 10   women  70 70 60 80 90
 *   OTHER   men  10 10 10  5 10   women  10 10 10 10 10
 *
 * Every mean is over the item's OWN base (the empty form is never a zero):
 *   Bank  : men 80 (sd 7.0711), women 20 (sd 8.1650), all 480/9 = 53.333
 *   Retail: men 11,             women 70,             all 335/9 = 37.222
 *   Other : men 9  (sd 2.2361), women 10 (sd 0),      all  85/9 =  9.444
 *
 * Bank and Retail separate hugely (men vs women); Other barely moves, which is
 * what pins "each item is tested on its own, not on its siblings".
 * ------------------------------------------------------------------------- */
const BANK   = [80, 80, 70, 90, 80, 20, 20, 30, 10, null];
const RETAIL = [10, 10, 20,  5, 10, 70, 70, 60, 80, null];
const OTHER  = [10, 10, 10,  5, 10, 10, 10, 10, 10, null];
const SEX    = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1];
const N = 10;

// -2 = answered but no category row to land on (the writer's marker for an
// allocation respondent). Respondent 10 filled nothing, so null.
const ANSWERED = [-2, -2, -2, -2, -2, -2, -2, -2, -2, null];

function island(extra) {
  return Object.assign({
    n: N,
    answers: { WALLET: ANSWERED.slice(), SEX: SEX.slice() },
    series: { WALLET: { "0": BANK.slice(), "1": RETAIL.slice(), "2": OTHER.slice() } },
    banner_vars: { Sex: SEX.map((s) => s + 1) },
    weights: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  }, extra || {});
}

// Three mean rows, one per item, in option order. Published values are the
// Total column's real means so the unfiltered view can be checked too.
function walletRows() {
  return [
    { kind: "mean", label: "Bank", mstat: "mean",
      pct: [53.33, 80, 20], n: [null, null, null], sig: ["", "B", ""] },
    { kind: "mean", label: "Retailer", mstat: "mean",
      pct: [37.22, 11, 70], n: [null, null, null], sig: ["", "", "C"] },
    { kind: "mean", label: "Other", mstat: "mean",
      pct: [9.44, 9, 10], n: [null, null, null], sig: ["", "", ""] }
  ];
}

function walletQ(rows) {
  return {
    code: "WALLET", title: "Share of wallet", type: "single", category: "Test",
    bases: [{ n: 9 }, { n: 5 }, { n: 4 }], rows: rows || walletRows()
  };
}

function setup(q, micro) {
  sandbox.TR.PREV = null;
  sandbox.TR.userState = null;
  sandbox.TR.MICRO = micro || island();
  sandbox.TR.AGG = {
    project: { name: "Allocation fixture", low_base_threshold: 2 },
    banner_groups: [{ id: "Sex", name: "Sex" }],
    columns: [
      { label: "Total", letter: "", group: null },
      { label: "Male", letter: "B", group: "Sex" },
      { label: "Female", letter: "C", group: "Sex" }
    ],
    questions: [q, {
      code: "SEX", title: "Sex", type: "single", category: "Test",
      bases: [{ n: 10 }, { n: 5 }, { n: 5 }],
      rows: [
        { kind: "category", label: "Male", pct: [50, 100, 0], n: [5, 5, 0], sig: ["", "", ""] },
        { kind: "category", label: "Female", pct: [50, 0, 100], n: [5, 0, 5], sig: ["", "", ""] }
      ]
    }]
  };
  if (TR.d2) TR.d2._qIndex = null;
}

function modelFor(q, filters, micro) {
  setup(q, micro);
  return TR.model.forQuestion("WALLET", "Sex", filters || []);
}
function rowOf(model, label) {
  return model.rows.filter((r) => r.label === label)[0];
}

const MALE = [{ q: "SEX", rows: [0], label: "Male" }];
const FEMALE = [{ q: "SEX", rows: [1], label: "Female" }];

console.log("\nAllocation questions recompute under a filter\n");

/* ---------------- 1. the channel is open at all ---------------- */

run("an allocation question is recomputable (it was not, before the series)", () => {
  const m = modelFor(walletQ(), MALE);
  assert(m.source === "computed",
    "a filtered allocation must recompute, got source=" + m.source);
});

run("unfiltered, the published values are shown verbatim", () => {
  const m = modelFor(walletQ(), []);
  assert(m.source === "published", "no filter means the published view");
  near(rowOf(m, "Bank").cells[0].mean, 53.33, "published Bank total");
});

/* ---------------- 2. each item off its OWN column ---------------- */

run("each item recomputes off its own series, not off item 1", () => {
  const m = modelFor(walletQ(), MALE);
  // Every cell here is the men's mean for that item. If the reader took item 1
  // as "the question", Retailer and Other would both read 80.
  near(rowOf(m, "Bank").cells[0].mean, 80, "men's Bank mean");
  near(rowOf(m, "Retailer").cells[0].mean, 11, "men's Retailer mean");
  near(rowOf(m, "Other").cells[0].mean, 9, "men's Other mean");
});

run("the banner columns inside a filter are right too", () => {
  const m = modelFor(walletQ(), []);
  setup(walletQ());
  const spec = TR.stats.columnsFor("Sex");
  const mask = TR.stats.mask([]);
  const bank = TR.stats.seriesMeans(walletQ(), 0, spec.columns, mask);
  near(bank[0].mean, 53.3333, "Bank, everyone in the base");
  near(bank[1].mean, 80, "Bank, men");
  near(bank[2].mean, 20, "Bank, women");
  const other = TR.stats.seriesMeans(walletQ(), 2, spec.columns, mask);
  near(other[1].mean, 9, "Other, men");
  near(other[2].mean, 10, "Other, women");
});

/* ---------------- 3. the base is the published base rule ---------------- */

run("the base counts the -2 markers: zero is an answer, an empty form is not", () => {
  const m = modelFor(walletQ(), []);
  // Nine of ten allocated something. Respondent 10 filled nothing and is out,
  // which is calculate_allocation_base()'s Reduce(`|`) over the slot columns.
  setup(walletQ());
  const spec = TR.stats.columnsFor("Sex");
  const tabs = TR.stats.tabulate(walletQ(), spec.columns, TR.stats.mask([]));
  assert(tabs[0].base === 9, "total base, got " + tabs[0].base);
  assert(tabs[1].base === 5, "men's base, got " + tabs[1].base);
  assert(tabs[2].base === 4, "women's base (one filled nothing), got " + tabs[2].base);
});

run("a filter moves the means and the base together", () => {
  const men = modelFor(walletQ(), MALE);
  const women = modelFor(walletQ(), FEMALE);
  assert(men.columns[0].base === 5, "men's filtered base, got " + men.columns[0].base);
  assert(women.columns[0].base === 4,
    "women's filtered base drops the empty form, got " + women.columns[0].base);
  near(rowOf(men, "Bank").cells[0].mean, 80, "men's Bank");
  near(rowOf(women, "Bank").cells[0].mean, 20, "women's Bank");
});

/* ---------------- 4. significance, per item ---------------- */

run("letters follow a Welch on the item's own mean, per item", () => {
  setup(walletQ());
  const spec = TR.stats.columnsFor("Sex");
  const mask = TR.stats.mask([]);
  const letters = spec.columns.map((c) => c.letter);
  const threshold = 2;

  // Bank: men 80 (sd 7.0711, n 5) vs women 20 (sd 8.1650, n 4). Hand-computed
  // Welch t = (80-20)/sqrt(50/5 + 66.667/4) = 60/sqrt(26.667) = 11.62, far
  // past 95%.
  const bank = TR.stats.seriesMeans(walletQ(), 0, spec.columns, mask);
  near(bank[1].sd, 7.0711, "men's Bank sd");
  near(bank[2].sd, 8.1650, "women's Bank sd");
  // A cell carries the letters of the columns it BEATS, so the men's cell (B)
  // shows C and the women's cell shows nothing.
  const bankSig = TR.stats.sigLetters(bank, letters, threshold, true, false);
  assert(/C/.test(bankSig[1]), "men beat women on Bank, got '" + bankSig[1] + "'");
  assert(!/B/.test(bankSig[2]), "women do not beat men on Bank, got '" + bankSig[2] + "'");

  // Retailer is the mirror image (women 70 vs men 11), so the letters flip.
  // Same island, same call, opposite direction: nothing carries over from the
  // row above.
  const retail = TR.stats.seriesMeans(walletQ(), 1, spec.columns, mask);
  const retailSig = TR.stats.sigLetters(retail, letters, threshold, true, false);
  assert(/B/.test(retailSig[2]), "women beat men on Retailer, got '" + retailSig[2] + "'");
  assert(!/C/.test(retailSig[1]), "men do not beat women on Retailer, got '" + retailSig[1] + "'");

  // Other: men 9 (sd 2.2361) vs women 10 (sd 0). t = -1/sqrt(5/5+0/4) = -1.0,
  // nowhere near either threshold, so NEITHER cell is lettered. Same island,
  // same call, opposite verdict: the items are tested independently.
  const other = TR.stats.seriesMeans(walletQ(), 2, spec.columns, mask);
  const otherSig = TR.stats.sigLetters(other, letters, threshold, true, false);
  assert(!/[BC]/.test(otherSig[1]), "Other is not significant, got '" + otherSig[1] + "'");
  assert(!/[BC]/.test(otherSig[2]), "Other is not significant, got '" + otherSig[2] + "'");
});

run("the model attaches those letters to the item rows", () => {
  // A filter that keeps BOTH sexes still recomputes, so the banner columns are
  // populated and the letters are visible on the rows themselves.
  const m = modelFor(walletQ(), [{ q: "SEX", rows: [0, 1], label: "All" }]);
  assert(m.source === "computed", "an everyone-filter still recomputes");
  const bank = rowOf(m, "Bank"), retail = rowOf(m, "Retailer"), other = rowOf(m, "Other");
  // Male is column 1, Female column 2. Bank goes to the men, Retailer to the
  // women, and Other to nobody: three verdicts off one island.
  assert(/C/.test(bank.cells[1].sig),
    "Bank's Male cell beats Female, got '" + bank.cells[1].sig + "'");
  assert(/B/.test(retail.cells[2].sig),
    "Retailer's Female cell beats Male, got '" + retail.cells[2].sig + "'");
  assert(!/[BC]/i.test(other.cells[1].sig) && !/[BC]/i.test(other.cells[2].sig),
    "Other separates for nobody, got '" + other.cells[1].sig + "' / '" +
    other.cells[2].sig + "'");
});

/* ---------------- 5. a row with no series blanks ---------------- */

run("an item row with no series entry renders null cells, not a sibling's mean", () => {
  const micro = island();
  delete micro.series.WALLET["1"];     // Retailer's series is missing
  const m = modelFor(walletQ(), MALE, micro);
  near(rowOf(m, "Bank").cells[0].mean, 80, "Bank still recomputes");
  const retail = rowOf(m, "Retailer");
  assert(retail.cells[0].mean === null,
    "Retailer must be blank, got " + retail.cells[0].mean);
  assert(retail.cells[0].sig === "", "and carries no letters");
});

run("with no series at all the question is not recomputable", () => {
  const micro = island();
  delete micro.series;
  micro.answers.WALLET = new Array(N).fill(null);   // the pre-series island
  const m = modelFor(walletQ(), MALE, micro);
  assert(m.source !== "computed" || m.columns[0].base === null,
    "an allocation with no microdata must not claim a base");
});

/* ---------------- 6. the island contract ---------------- */

run("d2.validate refuses a series row that is not length n", () => {
  const micro = island();
  micro.series.WALLET["1"] = [1, 2, 3];             // short
  const agg = { questions: [walletQ()], columns: [{ label: "Total" }] };
  const res = TR.d2.validate(agg, micro, null);
  assert(!res.ok, "a short series must not validate");
  assert(res.errors.some((e) => e.code === "DATA_MICRO_SERIES"),
    "expected DATA_MICRO_SERIES, got " + JSON.stringify(res.errors));
});

run("a full-length series validates", () => {
  const agg = { questions: [walletQ()], columns: [{ label: "Total" }] };
  const res = TR.d2.validate(agg, island(), null);
  assert(res.ok, "a well-formed series must validate: " + JSON.stringify(res.errors));
});

run("a question code of 'constructor' does not read back the inherited function", () => {
  const micro = island();
  micro.series = { constructor: { "0": BANK.slice() } };
  const q = Object.assign(walletQ(), { code: "WALLET" });
  setup(q, micro);
  const spec = TR.stats.columnsFor("Sex");
  // WALLET has no series here, and the poisoned key must not leak into it.
  assert(TR.stats.seriesMeans(q, 0, spec.columns, TR.stats.mask([])) === null,
    "a missing code must return null, not Object.prototype.constructor");
});

/* ---------------- 6b. weighted designs ---------------- */
// Every allocation study so far (VAS 2026, the Karoo demo) has been unweighted,
// so TR.MICRO.weights was all 1s and the weighted and unweighted paths were the
// same path. This is the only place the JS side's weighted allocation arithmetic
// is exercised at all; the R side's is pinned by parity_island_weighted.json.

run("a weighted design weights the series, and sizes it on the Kish base", () => {
  // Four respondents, weights 3/1/1/1, one item worth 10/20/30/40.
  //   weighted mean = (3*10 + 20 + 30 + 40) / 6 = 120/6 = 20
  //   unweighted mean would be 25, so a path that ignored the weights is visible
  //   effective base = (Sw)^2 / Sw^2 = 36/12 = 3, below the raw n of 4
  const micro = {
    n: 4, answers: { WALLET: [-2, -2, -2, -2] },
    series: { WALLET: { "0": [10, 20, 30, 40] } },
    banner_vars: { Sex: [1, 1, 2, 2] }, weights: [3, 1, 1, 1]
  };
  sandbox.TR.PREV = null;
  sandbox.TR.userState = null;
  sandbox.TR.MICRO = micro;
  sandbox.TR.AGG = {
    project: { name: "Weighted allocation", low_base_threshold: 1, weighted: true },
    banner_groups: [], columns: [{ label: "Total", letter: "", group: null }],
    questions: []
  };
  assert(TR.stats.isWeighted(), "the fixture is a weighted report");
  const got = TR.stats.seriesMeans({ code: "WALLET" }, 0,
    [{ member: null }], new Uint8Array(4).fill(1));
  near(got[0].mean, 20, "weighted mean (25 would mean the weights were ignored)");
  near(got[0].k, 3, "Kish effective base, not the raw n of 4");
});

/* ---------------- 7. the Excel export of the computed view ---------------- */

run("the Excel export carries the recomputed means, not the published ones", () => {
  const m = modelFor(walletQ(), MALE);
  const matrix = TR.render.matrix(m, { intervals: false });
  const flat = matrix.body.map((r) => r.cells.join("\t")).join("\n");
  // Under a Male filter the Total column IS the men, so Bank's Total cell
  // reads 80. The published 53.33 must not survive anywhere in the export.
  const bankRow = matrix.body.filter((r) => String(r.cells[0]) === "Bank")[0];
  assert(bankRow, "Bank row is in the export matrix");
  assert(String(bankRow.cells[1]).indexOf("80") === 0,
    "exported Bank Total is the men's 80, got '" + bankRow.cells[1] + "'");
  assert(flat.indexOf("53.3") === -1,
    "the published total must not appear in a filtered export");
  // Retailer moved too, from a published 37.22 to the men's 11.
  const retailRow = matrix.body.filter((r) => String(r.cells[0]) === "Retailer")[0];
  assert(String(retailRow.cells[1]).indexOf("11") === 0,
    "exported Retailer Total is the men's 11, got '" + retailRow.cells[1] + "'");
});

console.log("\n" + passed + " passed, " + failed + " failed\n");
process.exit(failed ? 1 : 0);
