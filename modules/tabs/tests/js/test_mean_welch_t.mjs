#!/usr/bin/env node
/**
 * Gate: every mean test in the v2 report is Welch's t, not a normal z.
 *
 * The R engine letters means with Welch's t-test (Welch-Satterthwaite df), and
 * Duncan chose the same test for the tracker on 24 Sep 2026. The report
 * computed the same Welch statistic but compared it with the NORMAL critical
 * value (stats.meanZ against zPrimary), so a pair whose statistic sat between
 * 1.96 and the t cutoff was significant in the report and not in R. That
 * reached four places: crosstab letters recomputed under a filter
 * (stats.sigLetters), the Tracking tab's wave-on-wave arrows (22w_waves.js
 * meanLevel), composite arrows (22_model.js) and Differences (27d_diffs.js).
 *
 * Reference values, from R (not from this code):
 *   two columns, mean 7 + 1.0058410058 vs 7, sd 2 and 2, n 31 and 31
 *     t = 1.98, df = 60, 2*pt(-1.98, 60) = 0.05229542  (normal: 0.04770353)
 *     -> not significant at 95%, significant at 80%
 *   the same with t = 2.10: p = 0.03994176 -> significant at 95%
 *   7.9 (sd 1.2, n_eff 33.5) vs 7.3 (sd 1.9, n_eff 45.2):
 *     t = 1.71182573, df = 75.02492597, p = 0.09105989
 *   t.test(c(rep(7,15),rep(9,16)), c(rep(6,16),rep(8,15)), var.equal = FALSE)
 *     p = 0.0001159084 (means 8.032258 / 6.967742, sd 1.016001 each)
 *
 * Runs against the SHIPPED module JS.
 * Run with:  node modules/tabs/tests/js/test_mean_welch_t.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const JS = path.join(ROOT, "modules/tabs/lib/html_report_v2/assets/js");
const TESTS = path.join(ROOT, "modules/tabs/lib/html_report_v2/tests");

const { installText } = await import(path.join(TESTS, "_text.mjs"));
const sandbox = { console };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.createContext(sandbox);
installText(sandbox);
for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "20_data.js",
  "21_stats.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js", "22_model.js"]) {
  vm.runInContext(readFileSync(path.join(JS, f), "utf8"), sandbox, { filename: f });
}
const TR = sandbox.TR;
TR.AGG = { project: { name: "Welch", low_base_threshold: 30, alpha: 0.05,
  alpha_secondary: 0.2, bonferroni: true, weighted: false },
  banner_groups: [], columns: [], questions: [] };

let failures = 0;
function check(label, ok, detail) {
  if (!ok) failures++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${ok ? "" : `: ${detail}`}`);
}
function near(label, actual, expected, tol) {
  check(label, actual !== null && Math.abs(actual - expected) <= tol,
    `expected ${expected}, got ${actual}`);
}

const SE = Math.sqrt(4 / 31 + 4 / 31);
const D198 = 1.0058410058;

// --- the test itself ----------------------------------------------------------
check("stats.welch exists", typeof TR.stats.welch === "function", "no stats.welch");
if (typeof TR.stats.welch === "function") {
  const a = TR.stats.welch(7 + D198, 2, 31, 7, 2, 31);
  near("t at the engineered pair", a && a.t, 1.98, 1e-8);
  near("Welch-Satterthwaite df", a && a.df, 60, 1e-8);
  near("two-sided p on t(60), R 2*pt(-1.98, 60)", a && a.p, 0.05229542, 1e-7);
  const b = TR.stats.welch(7.9, 1.2, 33.5, 7.3, 1.9, 45.2);
  near("unequal-variance df, R 75.02492597", b && b.df, 75.02492597, 1e-6);
  near("unequal-variance p, R 0.09105989", b && b.p, 0.09105989, 1e-7);
  const c = TR.stats.welch(8.032258064516129, 1.016001016001524, 31,
    6.967741935483871, 1.016001016001524, 31);
  near("equals t.test on raw data, R 0.0001159084", c && c.p, 0.0001159084, 1e-9);
}

// meanZ is the normal equivalent of the Welch t: the z with the same two-sided
// p, so every caller that compares |z| with zCrit(alpha) is testing p < alpha.
const z198 = TR.stats.meanZ(7 + D198, 2, 31, 7, 2, 31);
check("t = 1.98 on 60 df is NOT past the 95% line",
  Math.abs(z198) < TR.stats.zPrimary(1), `|z| ${z198} vs ${TR.stats.zPrimary(1)}`);
check("t = 1.98 on 60 df IS past the 80% line",
  Math.abs(z198) > TR.stats.zSecondary(1), `|z| ${z198}`);
const z210 = TR.stats.meanZ(7 + 2.1 * SE, 2, 31, 7, 2, 31);
check("t = 2.10 on 60 df is past the 95% line",
  Math.abs(z210) > TR.stats.zPrimary(1), `|z| ${z210}`);
check("meanZ keeps the sign of the difference", TR.stats.meanZ(7, 2, 31, 7 + D198, 2, 31) < 0,
  "sign lost");
check("an undefined test is still null", TR.stats.meanZ(7, 0, 31, 7, 0, 31) === null,
  "zero SE should be null");
const huge = TR.stats.meanZ(100, 0.01, 500, 0, 0.01, 500);
check("an overwhelming difference stays finite and large", isFinite(huge) && huge > 30,
  `got ${huge}`);

// --- crosstab letters under a filter (stats.sigLetters) -----------------------
const cells = [{ mean: 7.5, sd: 2, k: 62 }, { mean: 7 + D198, sd: 2, k: 31 },
  { mean: 7, sd: 2, k: 31 }];
const letters = TR.stats.sigLetters(cells, ["", "A", "B"], 30, true, true);
check("crosstab: t = 1.98 earns the 80% letter only (lowercase b)", letters[1] === "b",
  `got "${letters[1]}"`);

// --- the Tracking tab's wave-on-wave arrows (22w_waves.js meanLevel) ----------
const pts = [{ value: 7, sd: 2, base: 31 }, { value: 7 + D198, sd: 2, base: 31 }];
const cellsW = TR.waves.cellsFor(pts, false, "dual", 1);
check("tracking: t = 1.98 is not a 95% move", cellsW[1].sig_prev === false,
  `sig_prev ${cellsW[1].sig_prev}`);
check("tracking: t = 1.98 is an 80% move", cellsW[1].soft_prev === true,
  `soft_prev ${cellsW[1].soft_prev}`);
const pts2 = [{ value: 7, sd: 2, base: 31 }, { value: 7 + 2.1 * SE, sd: 2, base: 31 }];
check("tracking: t = 2.10 is a 95% move", TR.waves.cellsFor(pts2, false, "dual", 1)[1].sig_prev === true,
  "not flagged");

// --- exact parity with R on the committed parity fixture ---------------------
// The JS computed path, unfiltered, on the R-built respondent island
// (parity_micro.json) against the letters R published for the SAME data with no
// Population sheet (the computed path applies no FPC, so that is the like-for-
// like R run). R letters from Parity_Crosstab_Config_NoPop.xlsx, 24 Sep 2026,
// written as the dual-mode string the report shows: UPPERCASE at 95%,
// lowercase at 80% only. Before this fix the JS side put an 80% "d" on Q6
// Retailer / Beta that R's t-test does not give.
{
  const { readFileSync: rf } = await import("node:fs");
  const FX = path.join(ROOT, "modules/tabs/tests/fixtures/parity_project");
  const s2 = { console };
  s2.globalThis = s2; s2.window = s2;
  vm.createContext(s2);
  installText(s2);
  for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "20_data.js", "21_stats.js",
    "21b_cube.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js", "22_model.js",
    "23_render.js", "26_filter.js"]) {
    vm.runInContext(rf(path.join(JS, f), "utf8"), s2, { filename: f });
  }
  const T2 = s2.TR;
  T2.PREV = null; T2.userState = null; T2.CUBE = null;
  T2.AGG = JSON.parse(rf(path.join(FX, "parity_island.json"), "utf8"));
  T2.MICRO = JSON.parse(rf(path.join(FX, "parity_micro.json"), "utf8"));
  const R_NOPOP = {
    "Q2|Mean": ["", "c", "C", "", "c"],
    "Q4|NPS Score": ["", "C", "C", "", "C"],
    "Q5|NET POSITIVE (Top 2 Box - Bottom 2 Box)": ["", "D", "D", "D", ""],
    "Q6|Bank": ["", "C", "C", "", "C"],
    "Q6|Retailer": ["", "", "", "", ""],
    "Q6|Other": ["", "B", "", "ABD", "B"]
  };
  Object.keys(R_NOPOP).forEach((key) => {
    const [code, label] = key.split("|");
    const m = T2.model._computedModel(T2.d2.questionByCode(code), "Cohort", [], true);
    const row = m.rows.filter((r) => r.label === label)[0];
    const got = row ? row.cells.map((c) => c.sig || "") : null;
    check("R parity, " + key, JSON.stringify(got) === JSON.stringify(R_NOPOP[key]),
      `R ${JSON.stringify(R_NOPOP[key])}, JS ${JSON.stringify(got)}`);
  });
}

console.log(failures ? `\n${failures} FAILED` : "\nall passed");
process.exit(failures ? 1 : 0);
