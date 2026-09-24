#!/usr/bin/env node
/**
 * Gate: a weighted proportion test pools the way R does (review 24 Sep 2026).
 *
 * R (weighting.R weighted_z_test_proportions) pools on the design-weighted
 * counts and bases, p = (xw1 + xw2) / (bw1 + bw2), and sizes the SE on the
 * Kish effective bases. The report fed propZ x = p * n_eff over n_eff, which
 * pools weighted by n_eff instead: a different pooled p whenever the columns'
 * design effects differ, so a pair near a threshold, or near the n*p >= 5
 * precondition, could letter differently in a filtered view than in R.
 *
 * Case: the weighted parity fixture, Q5 answer "2", no FPC (the computed
 * path's rule). Inputs from generate_parity_project.R (weights 1.6/0.8/1.2/1.0,
 * every third x1.75):
 *   Alpha xw 7.6  bw 79.6  n_eff 37.0449017774
 *   Beta  xw 0    bw 60    n_eff 55.5555555556
 *   Gamma xw 14.7 bw 74.4  n_eff 46.313253012
 *   Delta xw 25.25 bw 62   n_eff 46.313253012
 * R's rule, computed in R with Bonferroni over choose(4, 2): 95% letters
 * "", "", "B", "AB"; 80% "", "", "B", "ABC"; dual string "", "", "B", "ABc".
 * Gamma vs Beta: R pooled p = 14.7 / 134.4 = 0.1094, Beta's n*p = 6.08, the
 * test runs and letters B. n_eff pooling gave p = 0.0898, n*p = 4.99 < 5, and
 * the test was skipped.
 *
 * Run with:  node modules/tabs/tests/js/test_weighted_prop_pooling.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const JS = path.join(ROOT, "modules/tabs/lib/html_report_v2/assets/js");
const sandbox = { console };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const f of ["00_namespace.js", "01_format.js", "20_data.js", "21_stats.js"]) {
  vm.runInContext(readFileSync(path.join(JS, f), "utf8"), sandbox, { filename: f });
}
const TR = sandbox.TR;
TR.AGG = { project: { alpha: 0.05, alpha_secondary: 0.2, bonferroni: true } };

let failures = 0;
function check(label, ok, detail) {
  if (!ok) failures++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${ok ? "" : `: ${detail}`}`);
}

const xw = [7.6, 0, 14.7, 25.25];
const bw = [79.6, 60, 74.4, 62];
const ne = [37.0449017774, 55.5555555556, 46.313253012, 46.313253012];
const cells = [{ x: 0, base: 0 }].concat(xw.map((x, i) =>
  ({ x: x / bw[i] * ne[i], base: ne[i], wbase: bw[i] })));
const got = TR.stats.sigLetters(cells, ["", "A", "B", "C", "D"], 30, false, true);
check("weighted Q5 '2' letters equal R's rule", JSON.stringify(got) ===
  JSON.stringify(["", "", "", "B", "ABc"]), `got ${JSON.stringify(got)}`);

// Unweighted cells carry no wbase: the counts pool as before, byte-identical.
const un = TR.stats.propZ(39, 60, 20, 50);
check("unweighted pooled z unchanged (hand: 2.61810)", Math.abs(un - 2.6181) < 1e-4, `got ${un}`);

// The pooled p itself, R's formula, on Gamma vs Beta.
const z = TR.stats.propZ(cells[3].x, ne[2], cells[2].x, ne[1], bw[2], bw[1]);
const pp = 14.7 / 134.4, p1 = 14.7 / 74.4;
const want = p1 / Math.sqrt(pp * (1 - pp) * (1 / ne[2] + 1 / ne[1]));
check("Gamma vs Beta z on R's pooled p", z !== null && Math.abs(z - want) < 1e-9,
  `want ${want}, got ${z}`);

console.log(failures ? `\n${failures} FAILED` : "\nall passed");
process.exit(failures ? 1 : 0);
