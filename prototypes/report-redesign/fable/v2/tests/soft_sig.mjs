#!/usr/bin/env node
/**
 * Standalone gate for the Tracking tab's dual-significance (95% + 80%) soft
 * flagging. Drives TR.waves.cellsFor directly with crafted points so the z is
 * exact, and asserts:
 *   - strong (|z|>1.96)  → sig_*=true,  soft_*=false (both modes)
 *   - soft   (1.28<|z|<1.96) → sig_*=false; soft_*=true ONLY in dual mode
 *   - none   (|z|<1.28)  → both false
 *   - single mode never sets soft_* (byte-identical to pre-feature output)
 * Covers the mean (Welch) and proportion (pooled-z) paths. Exits non-zero on
 * any failure. Spawned by run_tests_v2.mjs.
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
TR.AGG = { project: { low_base_threshold: 30 } };   // all bases below = 100, above floor

let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log("  ✓ " + m); } else { fail++; console.log("  ✗ " + m); } };

// SE for n=100, sd=10 each side = sqrt(1+1) = 1.4142; Δ = z * SE.
function meanPair(z) {
  var d = z * Math.SQRT2;
  return [{ value: 50, base: 100, sd: 10 }, { value: 50 + d, base: 100, sd: 10 }];
}
function lastCell(points, mode) {
  return TR.waves.cellsFor(points, false, mode)[1];   // canSig=false → mean path
}
// proportion points: x = count, base = n; canSig=true → propLevel(propZ).
function propLast(x1, x2, mode) {
  var pts = [{ value: x1, x: x1, base: 100 }, { value: x2, x: x2, base: 100 }];
  return TR.waves.cellsFor(pts, true, mode)[1];
}

// ---- means · mode = "off" | "95" | "dual" ----
var strong = lastCell(meanPair(2.5), "dual");
ok(strong.sig_prev === true && strong.soft_prev === false, "mean strong (z=2.5) DUAL: sig, not soft");
var strongS = lastCell(meanPair(2.5), "95");
ok(strongS.sig_prev === true && strongS.soft_prev === false, "mean strong 95%: sig unchanged, no soft");
var strongOff = lastCell(meanPair(2.5), "off");
ok(strongOff.sig_prev === false && strongOff.soft_prev === false, "mean strong OFF: no flag at all");

var soft = lastCell(meanPair(1.5), "dual");
ok(soft.sig_prev === false && soft.soft_prev === true, "mean soft (z=1.5) DUAL: soft flagged, not strong");
var softSingle = lastCell(meanPair(1.5), "95");
ok(softSingle.sig_prev === false && softSingle.soft_prev === false, "mean soft (z=1.5) 95%: nothing flagged");

var none = lastCell(meanPair(1.0), "dual");
ok(none.sig_prev === false && none.soft_prev === false, "mean weak (z=1.0) DUAL: nothing flagged");

// default (mode omitted) keeps strong-only behaviour (back-compat)
ok(lastCell(meanPair(2.5)).sig_prev === true && lastCell(meanPair(2.5)).soft_prev === false,
   "mode omitted → strong-only (byte-compatible default)");

// boundary: just above/below the 80% cut (Z80 = 1.2816)
ok(lastCell(meanPair(1.30), "dual").soft_prev === true, "mean z=1.30 (>Z80) DUAL: soft");
ok(lastCell(meanPair(1.26), "dual").soft_prev === false, "mean z=1.26 (<Z80) DUAL: not soft");

// ---- proportions (pooled z) ----
// 50 vs 70 of 100 → |z|≈2.89 (strong); 58 vs 70 → ≈1.77 (soft); 65 vs 70 → ≈0.76 (none)
ok(propLast(50, 70, "dual").sig_prev === true && propLast(50, 70, "dual").soft_prev === false,
   "prop strong (50→70): sig, not soft");
ok(propLast(50, 70, "off").sig_prev === false, "prop strong (50→70) OFF: no flag");
ok(propLast(58, 70, "dual").sig_prev === false && propLast(58, 70, "dual").soft_prev === true,
   "prop soft (58→70) DUAL: soft flagged");
ok(propLast(58, 70, "95").soft_prev === false,
   "prop soft (58→70) 95%: not flagged");
ok(propLast(65, 70, "dual").sig_prev === false && propLast(65, 70, "dual").soft_prev === false,
   "prop weak (65→70): nothing flagged");

// sig_base mirrors sig_prev on a 2-point series (first === prev)
var sb = lastCell(meanPair(1.5), "dual");
ok(sb.soft_base === true && sb.sig_base === false, "soft_base mirrors soft_prev on a 2-point series");

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
