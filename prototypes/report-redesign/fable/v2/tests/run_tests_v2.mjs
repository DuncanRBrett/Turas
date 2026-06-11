#!/usr/bin/env node
/**
 * v2 verification gate. Runs the in-browser selftest cases headlessly,
 * the golden parity suite (separate file, spawned), a native-PPTX
 * structural validation via python, artifact checks, and the source
 * structure rule. Zero dependencies beyond node + python3.
 */
import { readFileSync, readdirSync, writeFileSync, existsSync, statSync, mkdirSync } from "node:fs";
import { execFileSync, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const BASE = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const V1_JS = path.join(path.dirname(BASE), "src", "js");
const V2_JS = path.join(BASE, "src", "js");
const MAX_ACTIVE_LINES = 300;

const sandbox = { console, TextEncoder, URL };
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js", "14_pptx_parts.js"]) {
  vm.runInContext(readFileSync(path.join(V1_JS, f), "utf8"), sandbox, { filename: f });
}
for (const f of readdirSync(V2_JS).filter((x) => x.endsWith(".js")).sort()) {
  vm.runInContext(readFileSync(path.join(V2_JS, f), "utf8"), sandbox, { filename: f });
}
const TR = sandbox.TR;
TR.AGG = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_2025.json"), "utf8"));
TR.MICRO = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_microdata.json"), "utf8"));
TR.PREV = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_2024.json"), "utf8"));

let passed = 0, failed = 0;
function run(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e) {
    failed++;
    console.log(`  ✗ ${name}\n    ${e.message}`);
  }
}
const assert = (cond, msg) => { if (!cond) throw new Error(msg); };

console.log("Shared selftest cases (same as in-browser #selftest):");
for (const c of TR.selftest2.cases()) run(c.name, c.fn);

console.log("Node-only suite:");

run("golden parity suite passes (subprocess)", () => {
  const res = spawnSync("node", [path.join(BASE, "tests", "golden_parity.mjs")],
    { encoding: "utf8" });
  assert(res.status === 0, "golden parity failed:\n" + res.stdout);
});

run("NET filter expansion reproduces the published banner base", () => {
  const q002 = TR.d2.questionByCode("Q002");
  const netIdx = q002.rows.findIndex((r) => r.kind === "net" && r.label === "Online campus");
  const members = q002.net_members[String(netIdx)];
  assert(members && members.length, "Online campus net decomposed");
  const n = TR.stats.maskCount(TR.stats.mask([{ q: "Q002", rows: members }]));
  assert(n === 561, "expected 561 Online-campus respondents, got " + n);
  const m = TR.model.forQuestion("Q008", TR.AGG.banner_groups[3].id,
    [{ q: "Q002", rows: members }]);
  assert(m.columns[0].base === 191,
    "Q008 filtered base should equal published Q008xOnline base 191, got " + m.columns[0].base);
});

run("story deck -> structurally valid native pptx (python)", () => {
  const m1 = TR.model.forQuestion("Q008", TR.AGG.banner_groups[0].id, []);
  const m2 = TR.model.forQuestion("Q017", TR.AGG.banner_groups[0].id, []);
  const slides = [TR.exporter.titleSlide(2),
    TR.exporter.slideForModel(m1, "Admissions support stays strong."),
    TR.exporter.slideForModel(m2, "")];
  const bytes = TR.pptx.package(slides, { project: TR.AGG.project });
  const tmp = path.join(BASE, "tests", "tmp");
  mkdirSync(tmp, { recursive: true });
  const out = path.join(tmp, "v2_story.pptx");
  writeFileSync(out, bytes);
  const report = execFileSync("python3",
    [path.join(path.dirname(BASE), "tests", "verify_pptx.py"), out], { encoding: "utf8" });
  assert(report.startsWith("OK"), report);
});

run("deltas: most questions tracked, new ones flagged", () => {
  let tracked = 0, withDeltaRows = 0;
  for (const q of TR.AGG.questions) {
    const m = TR.model.forQuestion(q.code, TR.AGG.banner_groups[0].id, []);
    if (m.prevWave) {
      tracked++;
      if (m.rows.some((r) => r.delta)) withDeltaRows++;
    }
  }
  assert(tracked >= 60 && tracked < 79, "tracked questions: " + tracked);
  assert(withDeltaRows >= 55, "questions with row-level deltas: " + withDeltaRows);
});

run("built artifact exists, self-contained, < 2 MB", () => {
  const out = path.join(BASE, "sacap_report_v2.html");
  assert(existsSync(out), "run Rscript build.R first");
  const html = readFileSync(out, "utf8");
  assert(html.includes('id="data-agg"'), "aggregate island present");
  assert(html.includes('id="data-micro"'), "microdata island present");
  assert(!/(src|href)="https?:\/\//.test(html), "no external fetches");
  assert(statSync(out).size < 2 * 1024 * 1024, "size " + statSync(out).size);
});

run("structure: no v2 source file exceeds 300 active lines (or is excepted)", () => {
  const offenders = [];
  for (const f of readdirSync(V2_JS).filter((x) => x.endsWith(".js"))) {
    const text = readFileSync(path.join(V2_JS, f), "utf8");
    if (/SIZE-EXCEPTION/.test(text)) continue;
    const active = text.split("\n").filter((line) => {
      const t = line.trim();
      return t !== "" && !t.startsWith("//") && !t.startsWith("/*") &&
        !t.startsWith("*") && !/^[})\];]*$/.test(t);
    }).length;
    if (active > MAX_ACTIVE_LINES) offenders.push(`${f}: ${active}`);
  }
  assert(offenders.length === 0, "over limit: " + offenders.join(", "));
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
