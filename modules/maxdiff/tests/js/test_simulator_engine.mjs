#!/usr/bin/env node
/**
 * Gate: the MaxDiff simulator's numbers against hand calculation.
 *
 * Runs the SHIPPED engine (lib/html_simulator/js/simulator_engine.js) in a vm
 * and checks it against values worked out in the comments:
 *   - shares: mean of each respondent's softmax, x 100
 *   - head-to-head: mean of each respondent's two-item logit, x 100
 *   - TURF: greedy on top-K appeal, ties to the earlier item
 *   - a segment filter picks that segment's respondents, including a segment
 *     value that contains a colon
 *
 * e = 2.718282, 1/e = 0.367879.
 *
 * Run with:  node modules/maxdiff/tests/js/test_simulator_engine.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const ENGINE = path.join(ROOT, "modules/maxdiff/lib/html_simulator/js/simulator_engine.js");

let failures = 0;
function check(label, actual, expected, tol = 1e-9) {
  const ok = Object.is(actual, expected) ||
    (typeof actual === "number" && typeof expected === "number" &&
     Math.abs(actual - expected) <= tol);
  if (!ok) failures++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${ok ? "" : `: expected ${expected}, got ${actual}`}`);
}

function loadEngine(simData) {
  const ctx = vm.createContext({ console, Math });
  vm.runInContext(readFileSync(ENGINE, "utf8") + "\nthis.SimEngine = SimEngine;", ctx);
  ctx.SimEngine.init(simData);
  return ctx.SimEngine;
}

// --- Shares and head-to-head ------------------------------------------------
// R1 (A, B, C) = (1, 0, -1) -> softmax 66.524, 24.473, 9.003
// R2           = (0, 0, 0)  -> 33.333 each
// Mean: A 49.929, B 28.903, C 21.168.
// Head-to-head A vs B: R1 plogis(1) = 0.731059, R2 0.5 -> 61.6 / 38.4.
{
  const eng = loadEngine({
    items: [{ id: "A", label: "A", utility: 0.5 }, { id: "B", label: "B", utility: 0 },
            { id: "C", label: "C", utility: -0.5 }],
    individual_utils: [
      { id: "R1", utilities: [1, 0, -1], segments: { Shift: "Day" } },
      { id: "R2", utilities: [0, 0, 0], segments: { Shift: "Night: late" } },
    ],
    segments: [{ id: "Shift:Day" }, { id: "Shift:Night: late" }],
  });
  const s = eng.computeShares();
  check("share A", s[0].share, 49.929, 1e-3);
  check("share B", s[1].share, 28.903, 1e-3);
  check("share C", s[2].share, 21.168, 1e-3);
  check("shares sum to 100", s[0].share + s[1].share + s[2].share, 100, 1e-9);
  const h = eng.headToHead("A", "B");
  check("head-to-head A", h.probA, 61.6);
  check("head-to-head B", h.probB, 38.4);

  // Segment "Shift:Day" is R1 alone: shares 66.524, 24.473, 9.003.
  const day = eng.computeShares("Shift:Day");
  check("segment Day share A", day[0].share, 66.524, 1e-3);
  // Segment "Shift:Night: late" is R2 alone: 33.333 each. Its value contains
  // a colon, and the filter used to split the key on every colon, give up on
  // three parts and return the WHOLE sample, so this segment showed 49.929.
  const night = eng.computeShares("Shift:Night: late");
  check("segment with a colon in its value share A", night[0].share, 100 / 3, 1e-3);
}

// --- TURF, top-2 appeal -----------------------------------------------------
// Utilities (A, B, C, D) and each respondent's top two (ties to the earlier):
//   R1 ( 1,  1, -1, -1) -> A B
//   R2 ( 3, -1, -1, -1) -> A B
//   R3 (-1, -1,  3, -1) -> C A
//   R4 (-1, -1,  1,  1) -> C D
//   R5 (-1,  1, -1,  1) -> B D
// Step 1: A 3/5, B 3/5, C 2/5, D 2/5 -> A (first of the tie), 60%.
// Step 2: A+B 4/5, A+C 4/5, A+D 5/5 -> D, 100%, +40. Stops at 100%.
// Frequency of {A, D}: every respondent has exactly one of them -> 1.
{
  const U = [[1, 1, -1, -1], [3, -1, -1, -1], [-1, -1, 3, -1], [-1, -1, 1, 1], [-1, 1, -1, 1]];
  const eng = loadEngine({
    items: ["A", "B", "C", "D"].map((id) => ({ id, label: id, utility: 0 })),
    individual_utils: U.map((u, i) => ({ id: "R" + (i + 1), utilities: u, segments: {} })),
  });
  const t = eng.turfOptimize(4, 2);
  check("TURF step count", t.length, 2);
  check("TURF step 1 item", (t[0] || {}).itemId, "A");
  check("TURF step 1 reach", (t[0] || {}).reach, 60);
  check("TURF step 2 item", (t[1] || {}).itemId, "D");
  check("TURF step 2 reach", (t[1] || {}).reach, 100);
  check("TURF step 2 increment", (t[1] || {}).incremental, 40);
  check("TURF frequency of A + D", eng.turfReach(["A", "D"], 2).frequency, 1);
}

console.log(failures === 0 ? "\nALL PASS" : `\n${failures} FAILURE(S)`);
process.exit(failures === 0 ? 0 : 1);
