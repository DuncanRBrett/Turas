#!/usr/bin/env node
/**
 * Gate for the SUMMARY ROWS of a numeric question under an audience filter.
 *
 * Every one of these rows is `kind: "mean"` in the data layer, and the reader
 * used to recognise only "Standard Deviation" — by its LABEL. Everything else
 * fell through to the recomputed mean. So a filtered view printed the mean in
 * the Median row: on the Electrum VAS electricity table, R563.68 under a Male
 * filter in a row whose real value for that audience is R300. Found 2026-08-14
 * by driving the real report, not by reading the code.
 *
 * The row now says WHICH statistic it is (`mstat`, from the RowType in R) and
 * each is recomputed its own way — or left blank. A blank cell is a cell the
 * reader can question; a plausible wrong number is not.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/numeric_stat_rows_tests.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console };
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
  assert(got !== null && Math.abs(got - want) < 0.005,
    msg + " — got " + got + ", expected " + want);
}

/* ---------------------------------------------------------------------------
 * Eight respondents. Four men, four women, with a deliberately skewed spend so
 * the mean, the median and the ratio of totals are three different numbers.
 *
 *   value  100 100 100 700 | 200 200 200 200      (per-person value per txn)
 *   spend  100 100 100 7000| 200 200 200 200
 *   txn      1   1   1   10|   1   1   1   1
 *
 *   men   : mean 250, median 100, ratio 7300/13 = 561.54
 *   women : mean 200, median 200, ratio 800/4   = 200
 *   all   : mean 225, median 200, ratio 8100/17 = 476.47
 * ------------------------------------------------------------------------- */
const VALUE = [100, 100, 100, 700, 200, 200, 200, 200];
const SPEND = [100, 100, 100, 7000, 200, 200, 200, 200];
const TXN = [1, 1, 1, 10, 1, 1, 1, 1];
const SEX = [0, 0, 0, 0, 1, 1, 1, 1];      // 0 = male, 1 = female

function island() {
  return {
    n: 8,
    // VALUE's answers are the BIN each respondent falls in — what the R island
    // now writes for a binned numeric. SEX's are its row indices, which is what
    // a filter matches on.
    answers: { VALUE: [0, 0, 0, 1, 1, 1, 1, 1], SEX: [0, 0, 0, 0, 1, 1, 1, 1] },
    scores: { VALUE: VALUE, SPEND: SPEND, TXN: TXN },
    // banner_vars hold the COLUMN index: 1 = Male, 2 = Female
    banner_vars: { Sex: SEX.map(function (s) { return s + 1; }) },
    weights: [1, 1, 1, 1, 1, 1, 1, 1]
  };
}

function question(rows, extra) {
  return Object.assign({
    code: "VALUE", title: "Value per transaction", type: "numeric",
    category: "Test", bases: [{ n: 8 }, { n: 4 }, { n: 4 }], rows: rows
  }, extra || {});
}

const MEAN_ROWS = [
  { kind: "category", label: "Under R150", pct: [37.5, 75, 0], n: [3, 3, 0], sig: ["", "", ""] },
  { kind: "category", label: "R150+", pct: [62.5, 25, 100], n: [5, 1, 4], sig: ["", "", ""] },
  { kind: "mean", label: "Mean per buyer", mstat: "mean", pct: [225, 250, 200], n: [null, null, null], sig: ["", "", ""] },
  { kind: "mean", label: "Mean per transaction", mstat: "ratio", pct: [476.47, 561.54, 200], n: [null, null, null], sig: ["", "", ""] },
  { kind: "mean", label: "Median", mstat: "median", pct: [200, 100, 200], n: [null, null, null], sig: ["", "", ""] },
  { kind: "mean", label: "Standard Deviation", mstat: "sd", pct: [212, 300, 0], n: [null, null, null], sig: ["", "", ""] }
];

function setup(q) {
  sandbox.TR.PREV = null;
  sandbox.TR.userState = null;
  sandbox.TR.MICRO = island();
  sandbox.TR.AGG = {
    project: { name: "Numeric fixture", low_base_threshold: 2 },
    banner_groups: [{ id: "Sex", name: "Sex" }],
    columns: [
      { label: "Total", letter: "", group: null },
      { label: "Male", letter: "B", group: "Sex" },
      { label: "Female", letter: "C", group: "Sex" }
    ],
    questions: [q, {
      code: "SEX", title: "Sex", type: "single", category: "Test",
      bases: [{ n: 8 }, { n: 4 }, { n: 4 }],
      rows: [{ kind: "category", label: "Male", pct: [50, 100, 0], n: [4, 4, 0], sig: ["", "", ""] },
             { kind: "category", label: "Female", pct: [50, 0, 100], n: [4, 0, 4], sig: ["", "", ""] }]
    }]
  };
  if (TR.d2) TR.d2._qIndex = null;
}

function cellsFor(q, filters, label) {
  setup(q);
  const m = TR.model.forQuestion("VALUE", "Sex", filters || []);
  const row = m.rows.filter((r) => r.label === label)[0];
  return { model: m, row: row };
}

const MALE = [{ q: "SEX", rows: [0], label: "Male" }];

console.log("\nNumeric summary rows under a filter\n");

run("unfiltered, the published values are shown verbatim", () => {
  const got = cellsFor(question(MEAN_ROWS), [], "Median");
  assert(got.model.source === "published", "no filter means the published view");
  near(got.row.cells[0].mean, 200, "published median");
});

run("the median recomputes as a median, not as the mean", () => {
  const got = cellsFor(question(MEAN_ROWS), MALE, "Median");
  assert(got.model.source === "computed", "a filter recomputes");
  // the bug: this cell used to read 250, the men's MEAN
  near(got.row.cells[0].mean, 100, "median of the four men");
});

run("the mean still recomputes as the mean", () => {
  const got = cellsFor(question(MEAN_ROWS), MALE, "Mean per buyer");
  near(got.row.cells[0].mean, 250, "mean of the four men");
});

run("the median and the mean are different numbers, which is the point", () => {
  const med = cellsFor(question(MEAN_ROWS), MALE, "Median").row.cells[0].mean;
  const avg = cellsFor(question(MEAN_ROWS), MALE, "Mean per buyer").row.cells[0].mean;
  assert(med !== avg, "median " + med + " must not equal mean " + avg);
});

run("an even-sized audience takes the midpoint of the two middle values", () => {
  const got = cellsFor(question(MEAN_ROWS), [], "Median");
  setup(question(MEAN_ROWS));
  const med = TR.stats.medians(TR.d2.questionByCode("VALUE"),
    TR.stats.columnsFor("Sex").columns, TR.stats.mask([]));
  near(med[0].mean, 200, "the two middle values are both 200");
  assert(got !== null, "sanity");
});

run("the standard deviation still reports the spread, not the centre", () => {
  const got = cellsFor(question(MEAN_ROWS), MALE, "Standard Deviation");
  const avg = cellsFor(question(MEAN_ROWS), MALE, "Mean per buyer").row.cells[0].mean;
  assert(got.row.cells[0].mean !== avg, "SD must not be the mean");
  assert(got.row.cells[0].mean > 0, "SD is positive on a spread audience");
});

run("the ratio row totals both columns over the audience", () => {
  const q = question(MEAN_ROWS, { ratio: { num: "SPEND", den: "TXN" } });
  const all = cellsFor(q, [], "Mean per transaction");
  assert(all.model.source === "published", "unfiltered stays published");

  const men = cellsFor(q, MALE, "Mean per transaction");
  near(men.row.cells[0].mean, 7300 / 13, "men's total spend over total transactions");
});

run("the unfiltered recompute reproduces the published ratio", () => {
  const q = question(MEAN_ROWS, { ratio: { num: "SPEND", den: "TXN" } });
  setup(q);
  const rat = TR.stats.ratioOfTotals(q.ratio, TR.stats.columnsFor("Sex").columns,
    TR.stats.mask([]));
  near(rat[0].mean, 8100 / 17, "R's published figure, recomputed");
});

run("a ratio row with no pairing goes blank rather than showing the mean", () => {
  // an older report, built before the pairing travelled in the payload
  const got = cellsFor(question(MEAN_ROWS), MALE, "Mean per transaction");
  assert(got.row.cells[0].mean === null,
    "expected blank, got " + got.row.cells[0].mean);
});

run("a respondent with a zero denominator is left out of the ratio", () => {
  const q = question(MEAN_ROWS, { ratio: { num: "SPEND", den: "TXN" } });
  setup(q);
  sandbox.TR.MICRO.scores.TXN = [1, 1, 1, 0, 1, 1, 1, 1];   // the big one has none
  const rat = TR.stats.ratioOfTotals(q.ratio, TR.stats.columnsFor("Sex").columns,
    TR.stats.mask(MALE));
  near(rat[0].mean, 100, "300 / 3 — the 7000 leaves with its zero denominator");
});

run("only the headline mean carries significance letters", () => {
  const q = question(MEAN_ROWS, { ratio: { num: "SPEND", den: "TXN" } });
  ["Median", "Mean per transaction", "Standard Deviation"].forEach((lbl) => {
    const got = cellsFor(q, MALE, lbl);
    got.row.cells.forEach((c) => {
      assert(!c.sig, lbl + " must carry no letters — a test nobody specified");
    });
  });
});

run("a report built before mstat existed still handles its SD row", () => {
  const legacy = MEAN_ROWS.map((r) => {
    const copy = Object.assign({}, r); delete copy.mstat; return copy;
  });
  const got = cellsFor(question(legacy), MALE, "Standard Deviation");
  const avg = cellsFor(question(legacy), MALE, "Mean per buyer").row.cells[0].mean;
  assert(got.row.cells[0].mean !== avg, "the label fallback still catches the SD");
});

run("a weighted report reports no median rather than a wrong one", () => {
  setup(question(MEAN_ROWS));
  sandbox.TR.MICRO.weights = [2, 1, 1, 1, 1, 1, 1, 1];
  // the cached flag is computed per page; clear it the way a fresh load would
  const fresh = { console };
  fresh.globalThis = fresh; fresh.window = fresh;
  vm.createContext(fresh);
  for (const f of readdirSync(JS_DIR).filter((x) => x.endsWith(".js")).sort()) {
    vm.runInContext(readFileSync(path.join(JS_DIR, f), "utf8"), fresh, { filename: f });
  }
  fresh.TR.MICRO = island();
  fresh.TR.MICRO.weights = [2, 1, 1, 1, 1, 1, 1, 1];
  assert(fresh.TR.stats.isWeighted() === true, "weights that are not all 1 mean weighted");
  const med = fresh.TR.stats.medians({ code: "VALUE" },
    [{ label: "Total" }], fresh.TR.stats.mask([]));
  assert(med[0].mean === null, "a weighted median is not defined here, so it is blank");
});

run("the distribution rows recompute now that the island bins respondents", () => {
  const got = cellsFor(question(MEAN_ROWS), MALE, "Under R150");
  // three of the four men sit in the first bin; before the island carried bin
  // indices this whole table read 0% on a base of 0
  assert(got.model.columns[0].base === 4, "base is the four men, got " + got.model.columns[0].base);
  near(got.row.cells[0].pct, 75, "three men of four in the first bin");
});

/* --------------------------------------------------------------------------
 * The same question, asked by every other surface that treats a mean-kind row
 * as "the question's number". Each of these tested the LABEL, so each caught
 * the SD and let a Median through as if it were the mean.
 * ----------------------------------------------------------------------- */

run("fmt.meanStat reads the row's own statistic, with a label fallback", () => {
  assert(TR.fmt.meanStat({ mstat: "median", label: "Median" }) === "median", "mstat wins");
  assert(TR.fmt.meanStat({ label: "Standard Deviation" }) === "sd", "label fallback for old reports");
  assert(TR.fmt.meanStat({ label: "Mean" }) === "mean", "anything else is the headline mean");
  assert(TR.fmt.isHeadlineMean({ mstat: "ratio" }) === false, "a ratio is not the headline");
});

run("only the headline mean is trended across waves", () => {
  setup(question(MEAN_ROWS));
  const q = TR.d2.questionByCode("VALUE");
  q.rows.forEach((r) => {
    if (r.kind !== "mean" || TR.fmt.isHeadlineMean(r)) return;
    // a mean-kind row's wave history resolves to each wave's MEAN, so a
    // median trended that way would be a line of means under a median's label
    assert(TR.waves.series(q, r, q.rows.indexOf(r), null).length === 0,
      r.label + " must not carry a wave series");
  });
});

run("the Differences tab builds its finding on the mean, not the median", () => {
  setup(question(MEAN_ROWS));
  const q = TR.d2.questionByCode("VALUE");
  let chosen = null;
  q.rows.forEach((r) => {
    if (!chosen && r.kind === "mean" && TR.fmt.isHeadlineMean(r)) chosen = r;
  });
  assert(chosen && chosen.label === "Mean per buyer",
    "expected the mean row, got " + (chosen && chosen.label));
});

console.log("\n" + passed + " passed, " + failed + " failed\n");
process.exit(failed ? 1 : 0);
