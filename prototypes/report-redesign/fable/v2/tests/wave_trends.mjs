#!/usr/bin/env node
/**
 * Standalone known-answer gate for the wave engine's weighted trend + the
 * question-mapping's canonical cross-wave linkage. Run in a FRESH VM (the wave
 * engine caches its indexes per load) so it never pollutes the shared suite.
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

// Current wave (weighted) carries its own code Q9 + a canonical match_key, so it
// links to a prior wave with a DIFFERENT code Q1 (a rename). Current weighted
// mean of [5,5,8] w[2,1,1] = 23/4 = 5.75; prior unweighted (6+8+7)/3 = 7.
TR.AGG = { schema_version: 2,
  project: { name: "W", low_base_threshold: 1, alpha: 0.05,
    tracking: { enabled: true, default_scope: "all" } },
  columns: [{ key: "TOTAL::Total", group: "total", label: "Total", letter: "" }],
  banner_groups: [], categories: ["c"],
  questions: [{ code: "Q9", title: "Overall", category: "c", type: "scale",
    bases: [{ n: 3, low: false }],
    rows: [{ kind: "mean", label: "Mean", pct: [7], n: [null], sig: [""] }] }] };
TR.MICRO = null;
TR.PREV = { schema_version: 1, kind: "tracking_microdata", waves: [
  { wave: "W1", year: 2024, current: false, segments: [],
    questions: [{ code: "Q1", match_key: "track_overall", title: "Overall",
      base: 3, score_type: "mean", scores: [6, 8, 7] }] },
  { wave: "W2", year: 2025, current: true, segments: [],
    questions: [{ code: "Q9", match_key: "track_overall", title: "Overall",
      base: 3, score_type: "mean", scores: [5, 5, 8], weights: [2, 1, 1] }] } ] };

let failed = 0;
const ok = (cond, msg) => { console.log((cond ? "  ✓ " : "  ✗ ") + msg); if (!cond) failed++; };
const close = (a, b, msg) => ok(a !== null && Math.abs(a - b) < 1e-9, msg + " (" + a + ")");

const q = TR.d2.questionByCode("Q9");
const cp = TR.waves.currentPoint(q);
close(cp.value, 23 / 4, "current-wave weighted trend mean = 5.75");
const h = TR.waves.history(q);
ok(h.length === 1, "history linked via canonical key across codes (1 prior wave)");
close(TR.waves.valueAt(q, q.rows[0], 0, h[0].q, null), 7, "prior-wave unweighted mean = 7");
// the current SD is weighted too (Kish-effN sample SD), and finite for n>1
ok(cp.sd !== null && isFinite(cp.sd), "current-wave weighted SD is defined");

console.log(failed ? `\n${failed} failed` : "\nwave trends OK");
process.exit(failed ? 1 : 0);
