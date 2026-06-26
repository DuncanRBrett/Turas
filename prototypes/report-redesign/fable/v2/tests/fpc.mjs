#!/usr/bin/env node
/**
 * Standalone gate for the finite population correction (FPC). Two layers:
 *   1. KERNEL — TR.conf.fpcMul / fpcBase / coverage / responseRate /
 *      reportHasPopulation, and the narrowing of wilson / meanCI on an
 *      FPC-adjusted base. Known answers mirror modules/confidence/R
 *      (03_study_level.R apply_fpc / calculate_fpc_factor).
 *   2. MODEL — drives TR.model.forQuestion against the real SACAP fixture with
 *      a universe injected onto the "Masters" column, and asserts the default
 *      view becomes fpcDefault, the column carries population/coverage/ciBase,
 *      the displayed interval narrows, significance is sized on the corrected
 *      base, and removing the population restores byte-identical output.
 * Exits non-zero on any failure. Spawned by run_tests_v2.mjs.
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const BASE = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const V1 = path.join(path.dirname(BASE), "src", "js");
const V2 = path.join(BASE, "src", "js");

const sandbox = { console, TextEncoder, URL };
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js", "14_pptx_parts.js"]) {
  vm.runInContext(readFileSync(path.join(V1, f), "utf8"), sandbox, { filename: f });
}
for (const f of readdirSync(V2).filter((x) => x.endsWith(".js")).sort()) {
  vm.runInContext(readFileSync(path.join(V2, f), "utf8"), sandbox, { filename: f });
}
const TR = sandbox.TR;
TR.AGG = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_2025.json"), "utf8"));
TR.MICRO = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_microdata.json"), "utf8"));
TR.PREV = null;

let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log("  ✓ " + m); } else { fail++; console.log("  ✗ " + m); } };
const near = (a, b, t) => Math.abs(a - b) <= (t || 1e-9);
const width = (ci) => ci ? ci.hi - ci.lo : null;

const conf = TR.conf;

/* ---------------- 1. kernel ---------------- */

ok(near(conf.fpcMul(20, 27), 26 / 7), "fpcMul(20,27) = (N-1)/(N-n) = 26/7");
ok(conf.fpcMul(27, 27) === Infinity && conf.fpcMul(30, 27) === Infinity,
  "fpcMul full census (n>=N) -> Infinity");
ok(conf.fpcMul(50, 1) === 1 && conf.fpcMul(50, undefined) === 1 &&
   conf.fpcMul(50, NaN) === 1 && conf.fpcMul(0, 100) === 1,
  "fpcMul -> 1 when population or n is unusable (no correction)");

ok(near(conf.fpcBase(20, 20, 27), 20 * 26 / 7), "fpcBase unweighted = n*(N-1)/(N-n)");
ok(near(conf.fpcBase(18, 20, 27), 18 * 26 / 7), "fpcBase weighted scales the Kish n_eff");
ok(conf.fpcBase(27, 27, 27) === Infinity, "fpcBase full census -> Infinity");
ok(conf.fpcBase(50, 50, undefined) === 50, "fpcBase passes through with no population");

ok(near(conf.coverage(20, 27), 20 / 27) && conf.coverage(20, undefined) === null,
  "coverage = n/N, null when unknown");

// wilson / meanCI narrow on the corrected base; census -> zero width.
const wRaw = conf.wilson(0.5, 20), wFpc = conf.wilson(0.5, conf.fpcBase(20, 20, 27));
ok((wFpc.upper - wFpc.lower) < (wRaw.upper - wRaw.lower),
  "wilson interval narrows on the FPC base (20 of 27)");
const wCensus = conf.wilson(0.5, conf.fpcBase(27, 27, 27));
ok(near(wCensus.lower, 0.5) && near(wCensus.upper, 0.5),
  "wilson full census -> zero-width interval");
const mRaw = conf.meanCI(7, 2, 20), mFpc = conf.meanCI(7, 2, conf.fpcBase(20, 20, 27));
ok((mFpc.hi - mFpc.lo) < (mRaw.hi - mRaw.lo), "meanCI narrows on the FPC base");
const mCensus = conf.meanCI(7, 2, conf.fpcBase(27, 27, 27));
ok(near(mCensus.lo, 7) && near(mCensus.hi, 7), "meanCI full census -> zero-width interval");

// significance: a difference not significant at the raw base becomes
// significant once the high coverage is taken into account.
const zRaw = conf.fpcMul && TR.stats.propZ(14, 20, 8, 20); // 0.7 vs 0.4, n=20 each
const eff = conf.fpcBase(20, 20, 27);
const zFpc = TR.stats.propZ(0.7 * eff, eff, 0.4 * eff, eff);
ok(zRaw !== null && Math.abs(zRaw) < 1.96, "raw z (n=20) is NOT significant (|z|<1.96)");
ok(zFpc !== null && Math.abs(zFpc) > 1.96, "FPC z (74% coverage) IS significant (|z|>1.96)");

/* ---------------- 2. reportHasPopulation gating ---------------- */

ok(conf.reportHasPopulation() === false, "no population configured -> reportHasPopulation false");

/* ---------------- 3. model: intervals on the SACAP fixture ---------------- */
// The default view stays PUBLISHED (numbers verbatim); FPC only overlays the
// intervals + significance. So m0 and m1 share the same published base.

const Q = "Q002", BANNER = "Q006";   // cross-tab Campus by Year (has Masters)
const m0 = TR.model.forQuestion(Q, BANNER, [], { intervals: true });
const mi = m0.columns.findIndex((c) => c.label === "Masters");
ok(mi > 0, "fixture exposes a Masters column under the Year banner");
const base = m0.columns[mi].base;

ok(m0.fpcDefault === false && m0.columns[mi].population === undefined &&
   m0.columns[mi].ciBase === undefined,
  "no population -> default view is published, columns carry no FPC fields");
ok(m0.source === "published", "default view is the published report of record");

const catRi = m0.rows.findIndex((r) => r.kind === "category" &&
  r.cells[mi] && r.cells[mi].ci);
const ci0 = m0.rows[catRi].cells[mi].ci;

const N = Math.round(base / 0.75);   // ~75% coverage of the known universe
TR.AGG.columns.forEach((c) => { if (c.label === "Masters") c.population = N; });
TR.AGG._hasPop = undefined;
ok(conf.reportHasPopulation() === true, "injected population -> reportHasPopulation true");

const m1 = TR.model.forQuestion(Q, BANNER, [], { intervals: true });
const col1 = m1.columns[mi];
ok(m1.fpcDefault === true && m1.source === "published",
  "population -> FPC overlay on the still-published default view");
ok(col1.base === base, "displayed base is unchanged (numbers stay verbatim)");
ok(col1.population === N && near(col1.coverage, base / N, 1e-9),
  "Masters column carries population N and coverage n/N");
ok(near(col1.ciBase, conf.fpcBase(base, base, N), 1e-9),
  "Masters ciBase = FPC-adjusted effective base");

const cell1 = m1.rows[catRi].cells[mi];
ok(near(cell1.pct, m0.rows[catRi].cells[mi].pct, 1e-9),
  "the shown % is identical with and without the correction");
// attachIntervals uses the exact point estimate n/base (not the rounded %).
const refFpc = conf.wilson(cell1.n / base, col1.ciBase);
ok(near(cell1.ci.lo, refFpc.lower * 100, 1e-9) && near(cell1.ci.hi, refFpc.upper * 100, 1e-9),
  "Masters interval == Wilson on the FPC effective base");
ok(width(cell1.ci) < width(ci0) - 1e-9,
  "FPC interval is narrower than the uncorrected interval at the same %");

const other = m1.columns.find((c, i) => i > 0 && i !== mi && c.label !== "Masters");
ok(!other || other.population === undefined,
  "columns with no configured universe are left uncorrected");

TR.AGG.columns.forEach((c) => { if (c.label === "Masters") delete c.population; });
TR.AGG._hasPop = undefined;
const m2 = TR.model.forQuestion(Q, BANNER, [], { intervals: true });
ok(m2.fpcDefault === false &&
   near(width(m2.rows[catRi].cells[mi].ci), width(ci0), 1e-9),
  "removing the population restores the uncorrected interval (reversible)");

/* ---------------- 4. model: significance re-letters on the FPC base ------- */
// Synthetic published report: A=70% vs B=40%, n=20 each. At raw n the gap is
// NOT significant; once each column is known to be 20 of a 27-strong universe
// (74% coverage) the FPC makes it significant. Numbers shown never change.
const synth = {
  schema_version: 2,
  project: { name: "Synthetic", low_base_threshold: 30,
    sampling_method: "Census", tracking: { enabled: false } },
  columns: [
    { key: "TOTAL::Total", group: "total", label: "Total", letter: "" },
    { key: "G::A", group: "G", label: "A", letter: "A" },
    { key: "G::B", group: "G", label: "B", letter: "B" }
  ],
  banner_groups: [{ id: "G", name: "Group" }],
  categories: ["Cat"],
  questions: [{
    code: "QX", title: "QX", category: "Cat", type: "single",
    bases: [{ n: 40, low: false }, { n: 20, low: true }, { n: 20, low: true }],
    rows: [
      { kind: "category", label: "Yes", pct: [55, 70, 40], n: [22, 14, 8], sig: ["", "", ""] },
      { kind: "category", label: "No", pct: [45, 30, 60], n: [18, 6, 12], sig: ["", "", ""] }
    ]
  }]
};
const saved = { agg: TR.AGG, micro: TR.MICRO, idx: TR.d2._qIndex };
try {
  TR.AGG = synth; TR.MICRO = null; TR.d2._qIndex = null;
  const noPop = TR.model.forQuestion("QX", "G", []);
  ok(noPop.rows[0].cells[1].sig === "",
    "raw n=20: A (70%) vs B (40%) is NOT significant (no letter)");

  TR.AGG.columns.forEach((c) => { if (c.label === "A" || c.label === "B") c.population = 27; });
  TR.AGG._hasPop = undefined;
  const withPop = TR.model.forQuestion("QX", "G", []);
  ok(withPop.rows[0].cells[1].pct === 70,
    "the shown % is still 70 (FPC never changes the number)");
  ok(withPop.rows[0].cells[1].sig.indexOf("B") !== -1,
    "with 74% coverage the A>B gap becomes significant (letter B appears)");

  // A weighted report keeps standard significance (design effect not in layer).
  TR.AGG.project.weighted = true;
  TR.AGG._hasPop = undefined;
  const wtd = TR.model.forQuestion("QX", "G", []);
  ok(wtd.rows[0].cells[1].sig === "",
    "weighted report: significance is NOT re-lettered (intervals still FPC'd)");
} finally {
  TR.AGG = saved.agg; TR.MICRO = saved.micro; TR.d2._qIndex = saved.idx;
}

console.log(`\nFPC: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
