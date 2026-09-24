#!/usr/bin/env node
/**
 * Gate: an NPS answer outside 0-10 is never scored (review 24 Sep 2026).
 *
 * waves.scoreMap() rebuilds each category's score from its label to derive a
 * history wave's spread. For NPS it bucketed any label >= 9 as a promoter, so a
 * don't-know shown as "99" counted as +100, the same fault R's
 * nps_bucket_score() had (it now returns NA above 10). Hand check, categories
 * 10 / 8 / 5 / 99: scores +100 / 0 / -100 / (none).
 *
 * Run with:  node modules/tabs/tests/js/test_nps_score_range.mjs
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

let failures = 0;
function check(label, ok, detail) {
  if (!ok) failures++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${ok ? "" : `: ${detail}`}`);
}

const q = { code: "QN", type: "nps", rows: [
  { kind: "category", label: "10" }, { kind: "category", label: "8" },
  { kind: "category", label: "5" }, { kind: "category", label: "99" },
  { kind: "mean", label: "NPS Score" }] };
const map = TR.waves.scoreMap(q, q.rows[4]);
check("10 is a promoter", map && map[0] === 100, JSON.stringify(map));
check("8 is a passive", map && map[1] === 0, JSON.stringify(map));
check("5 is a detractor", map && map[2] === -100, JSON.stringify(map));
check("99 is not scored at all", map && !(3 in map), JSON.stringify(map));

// A plain mean still scores every numeric label (the bound is NPS-only).
const qm = { code: "QM", type: "scale", rows: [
  { kind: "category", label: "1" }, { kind: "category", label: "20" },
  { kind: "mean", label: "Mean" }] };
const mm = TR.waves.scoreMap(qm, qm.rows[2]);
check("a mean row still scores 20", mm && mm[1] === 20, JSON.stringify(mm));

console.log(failures ? `\n${failures} FAILED` : "\nall passed");
process.exit(failures ? 1 : 0);
