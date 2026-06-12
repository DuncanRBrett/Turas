#!/usr/bin/env node
/**
 * Golden parity gate: the JS stats engine, recomputing from the synthetic
 * microdata with NO filter, must reproduce the published 2025 tables.
 *
 *  - Campus banner: bases and category counts EXACT for every question.
 *  - NETs (incl. unions and NET POSITIVE diffs): within 1.2pp of published
 *    (published values are display-rounded).
 *  - Index means: within 1.0 of published (published means come from raw
 *    data; ours from banded scores).
 *  - Sig letters: report agreement rate vs the published ▲ letters.
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const BASE = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const V1_JS = path.join(path.dirname(BASE), "src", "js");
const V2_JS = path.join(BASE, "src", "js");

const sandbox = { console, TextEncoder, URL };
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
const V1_KEEP = ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js",
  "14_pptx_parts.js"];
for (const f of V1_KEEP) {
  vm.runInContext(readFileSync(path.join(V1_JS, f), "utf8"), sandbox, { filename: f });
}
for (const f of readdirSync(V2_JS).filter((x) => x.endsWith(".js")).sort()) {
  vm.runInContext(readFileSync(path.join(V2_JS, f), "utf8"), sandbox, { filename: f });
}
const TR = sandbox.TR;
TR.AGG = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_2025.json"), "utf8"));
TR.MICRO = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_microdata.json"), "utf8"));
TR.PREV = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_waves.json"), "utf8"));

const campus = TR.AGG.banner_groups[0].id;
let baseMismatch = 0, cellMismatch = 0, cells = 0;
let netChecked = 0, netOff = 0, meanChecked = 0, meanOff = 0;
let sigAgree = 0, sigTotal = 0;
const examples = [];

for (const q of TR.AGG.questions) {
  const pub = TR.model._publishedModel(q, campus);
  const comp = TR.model._computedModel(q, campus, []);
  pub.columns.forEach((pc, i) => {
    if ((pc.base ?? 0) !== comp.columns[i].base) {
      baseMismatch++;
      if (examples.length < 5) examples.push(`${q.code} base col${i}: pub=${pc.base} comp=${comp.columns[i].base}`);
    }
  });
  q.rows.forEach((r, ri) => {
    const pubRow = pub.rows[ri], compRow = comp.rows[ri];
    pubRow.cells.forEach((pcell, i) => {
      if (r.kind === "category") {
        cells++;
        if (pcell.n !== null && pcell.n !== compRow.cells[i].n) {
          cellMismatch++;
          if (examples.length < 10) examples.push(`${q.code} '${r.label.slice(0, 18)}' col${i}: pub n=${pcell.n} comp n=${compRow.cells[i].n}`);
        }
        // sig letters agreement (published vs recomputed)
        if (i > 0) {
          sigTotal++;
          const pubSig = (pcell.sig || "").split("").sort().join("");
          const compSig = (compRow.cells[i].sig || "").split("").sort().join("");
          if (pubSig === compSig) sigAgree++;
        }
      }
      if (r.kind === "net" && pcell.pct !== null && compRow.cells[i].pct !== null) {
        netChecked++;
        if (Math.abs(pcell.pct - compRow.cells[i].pct) > 1.2) netOff++;
      }
      if (r.kind === "mean" && pcell.mean !== null && compRow.cells[i].mean !== null) {
        meanChecked++;
        if (Math.abs(pcell.mean - compRow.cells[i].mean) > 1.0) meanOff++;
      }
    });
  });
}

console.log(`questions: ${TR.AGG.questions.length}`);
console.log(`category cells: ${cells}, count mismatches: ${cellMismatch}`);
console.log(`base mismatches: ${baseMismatch}`);
console.log(`nets checked: ${netChecked}, off>1.2pp: ${netOff}`);
console.log(`means checked: ${meanChecked}, off>1.0: ${meanOff}`);
console.log(`sig letter agreement: ${sigAgree}/${sigTotal} (${(sigAgree / sigTotal * 100).toFixed(1)}%)`);
examples.forEach((e) => console.log("  ", e));

// sig agreement is a documented property (~90%, README) — enforce a floor
// so a regression in the engine can't slip through as a printed statistic
const SIG_AGREEMENT_FLOOR = 0.85;
const hardFail = cellMismatch > 0 || baseMismatch > 0 || netOff > netChecked * 0.02 ||
  meanOff > meanChecked * 0.1 ||
  (sigTotal > 0 && sigAgree / sigTotal < SIG_AGREEMENT_FLOOR);
console.log(hardFail ? "\nGOLDEN PARITY: FAIL" : "\nGOLDEN PARITY: PASS");
process.exit(hardFail ? 1 : 0);
