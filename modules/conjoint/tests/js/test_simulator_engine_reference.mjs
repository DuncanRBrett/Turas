#!/usr/bin/env node
/**
 * Gate: the conjoint market simulator's shares against hand calculation.
 *
 * Runs the SHIPPED engine (lib/html_simulator/js/simulator_engine.js) in a vm.
 * Part-worths: Brand A 0.5, B -0.5; Price Low 0.3, High -0.3.
 * Products: P1 = A + Low (U 0.8), P2 = B + High (U -0.8), P3 = A + High (U 0.2).
 *
 *   exp(0.8) = 2.225541, exp(-0.8) = 0.449329, exp(0.2) = 1.221403, sum 3.896273
 *   logit:  57.120, 11.532, 31.348
 *   first choice: 100, 0, 0
 *   purchase likelihood plogis(U): 68.997, 31.003, 54.983
 *   scale factor 2: exp(1.6) = 4.953032, exp(-1.6) = 0.201897, exp(0.4) = 1.491825,
 *     sum 6.646754 -> 74.518, 3.038, 22.444
 *   RFC (Gumbel error on each product's total utility) has the logit shares as
 *   its expectation; with 2000 draws each share is within 3 x 100 x
 *   sqrt(p (1 - p) / 2000) of them (at most 3.4 points).
 *
 * Math.random is replaced by a seeded generator so the RFC check is repeatable.
 *
 * Run with:  node modules/conjoint/tests/js/test_simulator_engine_reference.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const ENGINE = path.join(ROOT, "modules/conjoint/lib/html_simulator/js/simulator_engine.js");

let failures = 0;
function check(label, actual, expected, tol = 1e-3) {
  const ok = typeof actual === "number" && Math.abs(actual - expected) <= tol;
  if (!ok) failures++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${ok ? "" : `: expected ${expected}, got ${actual}`}`);
}

// Park-Miller minimal standard generator, seeded.
let seed = 20260925;
const seededMath = Object.create(Math);
seededMath.random = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };

const ctx = vm.createContext({ console, Math: seededMath });
vm.runInContext(readFileSync(ENGINE, "utf8") + "\nthis.SimEngine = SimEngine;", ctx);
const eng = ctx.SimEngine;
eng.init({
  attributes: [
    { name: "Brand", levels: [{ name: "A", utility: 0.5 }, { name: "B", utility: -0.5 }] },
    { name: "Price", levels: [{ name: "Low", utility: 0.3 }, { name: "High", utility: -0.3 }] },
  ],
});
const P = [{ Brand: "A", Price: "Low" }, { Brand: "B", Price: "High" }, { Brand: "A", Price: "High" }];

const logit = eng.predictShares(P, "logit");
[57.120, 11.532, 31.348].forEach((v, i) => check(`logit P${i + 1}`, logit[i], v));
const fc = eng.predictShares(P, "first_choice");
[100, 0, 0].forEach((v, i) => check(`first choice P${i + 1}`, fc[i], v));
const pl = eng.predictShares(P, "purchase_likelihood");
[68.997, 31.003, 54.983].forEach((v, i) => check(`purchase likelihood P${i + 1}`, pl[i], v));

eng.setScaleFactor(2);
const scaled = eng.predictShares(P, "logit");
[74.518, 3.038, 22.444].forEach((v, i) => check(`logit at scale 2, P${i + 1}`, scaled[i], v));
eng.setScaleFactor(1);

const rfc = eng.predictShares(P, "rfc");
[57.120, 11.532, 31.348].forEach((v, i) => {
  const p = v / 100;
  check(`RFC P${i + 1} within 3 MC SE of logit`, rfc[i], v, 300 * Math.sqrt(p * (1 - p) / 2000));
});
check("RFC shares sum to 100", rfc[0] + rfc[1] + rfc[2], 100, 1e-9);

console.log(failures === 0 ? "\nALL PASS" : `\n${failures} FAILURE(S)`);
process.exit(failures === 0 ? 0 : 1);
