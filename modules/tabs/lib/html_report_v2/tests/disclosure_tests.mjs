// Disclosure control. Re-identification protection threshold. Node, no DOM.
// Stubs TR.AGG.project / TR.MICRO / TR.stats / TR.d2 and checks the threshold logic,
// the live audience base, and the "set k = N to forbid any drill-down" property.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { TXT, CATALOGUE, installText, blockOf } from "./_text.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const jsDir = path.join(here, "..", "assets", "js");
globalThis.TR = {};
// disc.note() reads its wording from the catalogue (02_text.js), like the rest
// of the renderer.
new Function(fs.readFileSync(path.join(jsDir, "02_text.js"), "utf8"))();
globalThis.TR.txt.load(CATALOGUE);
new Function(fs.readFileSync(path.join(jsDir, "21d_disclosure.js"), "utf8"))();
const disc = globalThis.TR.disclosure;

let passed = 0, failed = 0;
function assert(cond, msg) {
  if (cond) { passed++; console.log("  ✓ " + msg); }
  else { failed++; console.log("  ✗ " + msg); }
}

console.log("Disclosure control:");

// Off by default (no config / k<=1): existing reports are unaffected.
TR.AGG = { project: {} };
assert(disc.minBase() === 1 && disc.active() === false, "no config -> k=1, control off");
TR.AGG.project.min_reporting_base = 1;
assert(disc.active() === false, "k=1 is treated as off");
TR.AGG.project.min_reporting_base = 10;
assert(disc.minBase() === 10 && disc.active() === true, "k=10 -> active");

// Audience base: the whole sample when unfiltered, the mask count when filtered.
TR.MICRO = { n: 200 };
TR.d2 = { state: { filters: [] } };
assert(disc.audienceBase() === 200, "unfiltered audience base = N");
TR.stats = { mask: function (f) { return f; }, maskCount: function () { return 3; } };
TR.d2.state.filters = [{ q: "X", rows: [0] }];
assert(disc.audienceBase() === 3, "filtered audience base = maskCount");
assert(disc.audienceTooSmall() === true, "base 3 < k 10 -> too small");

// The k = N property Duncan asked for: only the full-sample view shows detail; any
// sub-group filter trips the gate.
TR.AGG.project.min_reporting_base = 200;   // k = full sample
TR.d2.state.filters = [];
assert(disc.audienceTooSmall() === false, "k=N, unfiltered (base=N) -> shows detail");
TR.d2.state.filters = [{ q: "X", rows: [0] }];
assert(disc.audienceTooSmall() === true, "k=N, any filter (base<N) -> withholds detail");

// Cell-level safety (for the crosstab suppression increment): 0 is fine, 1..k-1 suppressed.
TR.AGG.project.min_reporting_base = 10;
assert(disc.cellOk(0) === true, "cellOk: an empty cell (0) is fine to show");
assert(disc.cellOk(10) === true && disc.cellOk(25) === true, "cellOk: count >= k is fine");
assert(disc.cellOk(1) === false && disc.cellOk(9) === false, "cellOk: 1..k-1 is suppressed");
// off -> everything shows
TR.AGG.project.min_reporting_base = 1;
assert(disc.cellOk(2) === true, "cellOk: control off -> any count shows");

// Fail CLOSED: disclosure engaged and the base cannot be established AT ALL (an island
// with no published bases) must NOT reveal identifying detail.
const savedMicro = TR.MICRO;
TR.AGG.project.min_reporting_base = 10;
TR.MICRO = null;
assert(disc.audienceBase() === null, "no microdata AND no published bases -> unknown (null)");
assert(disc.audienceTooSmall() === true, "unknown base -> fail closed (too small)");
assert(disc.note() === TXT("disclosure.note_unverified", { k: 10 }),
  "note explains the base is unverifiable");
// ...but with the control off, an unknown base gates nothing (existing reports unaffected).
TR.AGG.project.min_reporting_base = 1;
assert(disc.audienceTooSmall() === false, "control off + unknown base -> nothing gated");

/* The confidentiality ship (html_report_v2_microdata = FALSE). No microdata, so no
 * filter bar, so the audience IS the published full sample. Before this, audienceBase()
 * returned null here and the whole report's comment detail failed closed, which pushed
 * the operator into clearing min_reporting_base and losing the COLUMN suppression that
 * protects a three-person department. Both must now hold at once. */
TR.AGG.questions = [
  { code: "Q1", bases: [{ n: 229 }, { n: 3 }] },
  { code: "Q2", bases: [{ n: 180 }, { n: 3 }] }   // a routed question: smaller base
];
TR.AGG.project.min_reporting_base = 10;
assert(disc.audienceBase() === 229, "no microdata -> audience base = largest published Total base");
assert(disc.audienceTooSmall() === false, "k=10 on a 229-person sample -> comment detail SHOWS");
assert(disc.cellOk(3) === false && disc.cellOk(229) === true,
  "…while cell/column suppression still bites at k=10");
// A genuinely tiny sample still gates, with no microdata to tell us so.
TR.AGG.questions = [{ code: "Q1", bases: [{ n: 4 }] }];
assert(disc.audienceBase() === 4, "tiny published sample is reported as itself");
assert(disc.audienceTooSmall() === true, "…and a 4-person report still fails the k=10 gate");
// A question with no bases block at all must not throw or poison the maximum.
TR.AGG.questions = [{ code: "Q1" }, { code: "Q2", bases: [{ n: 50 }] }];
assert(disc.audienceBase() === 50, "a question with no bases is skipped, not fatal");
delete TR.AGG.questions;
TR.MICRO = savedMicro;

/* ==========================================================================
 * A suppressed column's BASE (production review 2026-08, CRITICAL C2)
 *
 * applyDisclosureSuppression blanks a sub-k column's cells and strips the
 * letters pointing at it, but the base row still printed the exact headcount,
 * "4 ⚠" on screen, in the TSV, and in the PPTX / XLSX matrix, while the
 * Excel writer for the same run withholds it as "n<10"
 * (excel_writer.R write_base_rows + disclosure_marker). Two deliverables of
 * one run enforced different disclosure standards, and the HTML named the
 * headcount of an identifiable subgroup.
 *
 * Its derivations leak the same number: the worst-case margin of error is
 * 98/sqrt(n), so "±49.0pp" inverts to n=4 exactly, and a census column's
 * coverage note ("2% of 200") does the same.
 *
 * Its own sandbox: this section needs the model + render layers, which the
 * unit section above deliberately does without.
 * ======================================================================== */
const vm = await import("node:vm");
const jsFiles = ["00_namespace.js", "01_format.js", "03_svg.js", "20_data.js",
  "21_stats.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js",
  "22_model.js", "23_render.js", "23z_charts.js", "23za_trend.js", "26_filter.js"];

function renderSandbox() {
  const box = { console };
  box.globalThis = box;
  box.window = box;
  vm.createContext(box);
  installText(box);
  for (const f of jsFiles) {
    vm.runInContext(fs.readFileSync(path.join(jsDir, f), "utf8"), box, { filename: f });
  }
  return box.TR;
}

/** Total (200) + Sales (196) + Legal (4). k = 10, so Legal is suppressed.
 *  Weighted, so all three base rows render. `k` = 1 turns the control off. */
function suppressionFixture(R, k) {
  R.PREV = null; R.userState = null; R.MICRO = null;
  R.AGG = {
    project: { name: "Disclosure", low_base_threshold: 30, weighted: true,
      min_reporting_base: k },
    banner_groups: [{ id: "Dept", name: "Dept" }],
    columns: [
      { label: "Total", letter: "", group: null },
      { label: "Sales", letter: "A", group: "Dept" },
      { label: "Legal", letter: "B", group: "Dept" }
    ],
    questions: [{
      code: "Q1", title: "Satisfied?", type: "single", category: "X",
      bases: [{ n: 200, nWeighted: 200, nEff: 190, low: false },
        { n: 196, nWeighted: 196, nEff: 186, low: false },
        { n: 4, nWeighted: 4, nEff: 4, low: true }],
      rows: [
        { kind: "category", label: "Yes", pct: [70, 70, 75], n: [140, 137, 3], sig: ["", "", ""] },
        { kind: "category", label: "No", pct: [30, 30, 25], n: [60, 59, 1], sig: ["", "", ""] }
      ]
    }]
  };
  if (R.d2) R.d2._qIndex = null;
  R.waves.reset();
  return R.model.forQuestion("Q1", "Dept", [], { dual: false, intervals: true });
}

console.log("\nSuppressed-column base masking (C2):");

/** A check that survives a thrown error (a missing helper is a failure, not a
 *  crash that hides the checks below it). */
function check(msg, fn) {
  let ok = false, why = "";
  try { ok = fn() === true; } catch (e) { why = " [" + e.message + "]"; }
  assert(ok, msg + why);
}

const RS = renderSandbox();
const supModel = suppressionFixture(RS, 10);
check("fixture: only the 4-person column is suppressed",
  () => supModel.columns[2].suppressed === true && !supModel.columns[1].suppressed);

const supHtml = RS.render.tableHtml(supModel, { intervals: true });
const supBaseBlock = supHtml.slice(supHtml.indexOf('<tr class="rb">'),
  supHtml.indexOf('<tr class="rc">'));
const supTsv = RS.render.tsv(supModel);

// The marker itself must read exactly as the workbook's disclosure_marker(k).
check("the marker mirrors the workbook's disclosure_marker(k): n<10",
  () => RS.render.baseMarker(supModel.columns[2]) === "n<10");
check("an unsuppressed column has no marker",
  () => RS.render.baseMarker(supModel.columns[1]) === null);

// 1. on screen. Every base row: unweighted, weighted, effective.
check("all three base rows mask the suppressed column",
  () => (supBaseBlock.match(/n&lt;10/g) || []).length === 3);
check("the exact headcount 4 appears nowhere in the base block",
  () => !/>4 ?⚠?</.test(supBaseBlock) && supBaseBlock.indexOf(">4<") === -1);
check("the worst-case margin (98/√n) is dropped, ±49.0pp inverts to n=4",
  () => supBaseBlock.indexOf("±49.0pp") === -1);

// 2. the unsuppressed columns are untouched, ⚠ flag and margins included.
check("the safe columns still print their bases",
  () => supBaseBlock.indexOf(">200<") !== -1 && supBaseBlock.indexOf(">196<") !== -1);
check("…and their effective bases",
  () => supBaseBlock.indexOf(">190<") !== -1 && supBaseBlock.indexOf(">186<") !== -1);
check("…and their margins of error", () => supBaseBlock.indexOf("±6.9pp") !== -1);

// 3. the export matrix / TSV. The PPTX and clipboard read the same rows.
const supTsvBases = supTsv.split("\n").filter((l) => /^(Base|Effective)/.test(l));
check("three base rows in the export", () => supTsvBases.length === 3);
check("every exported base row masks the suppressed column",
  () => supTsvBases.length === 3 && supTsvBases.every((l) => l.split("\t")[3] === "n<10"));
check("no bare 4 anywhere in the export", () => !/\t4( |\t|$)/.test(supTsv));

// 4. the wave strip prints the CURRENT column-0 base, which is suppressed when
//    the whole filtered audience falls below k (the n=1-cut case): the strip
//    sits on the same card as the table, so it must mask it too.
const strip = RS.render.waveStripHtml({
  history: [{ year: 2025, base: 190 }],
  rows: [{ kind: "category", label: "Yes", cells: [supModel.rows[0].cells[2]],
    waves: [{ year: 2025, value: 70 }] }],
  columns: [supModel.columns[2]], lowBaseThreshold: 30
});
check("the wave strip masks a suppressed current base too",
  () => strip.indexOf(">4<") === -1 && strip.indexOf("n&lt;10") !== -1);

// 5. the confidence explainer's "small groups swing more" example picks the
//    SMALLEST column by construction, so it volunteered the withheld group by
//    name and headcount ("Legal has only 4 respondents") in prose.
const supCallout = RS.conf.calloutHtml();
check("the explainer does not name the withheld group's headcount",
  () => supCallout.indexOf("Legal") === -1 &&
    supCallout.indexOf(">4 respondents") === -1);
check("…it falls back to the smallest DISCLOSABLE column",
  () => supCallout.indexOf('data-txt-key="conf.footer.small_samples"') !== -1 &&
    supCallout.indexOf("Sales") !== -1 && supCallout.indexOf("196") !== -1);

// 5b. the worked example's percentage is generated, so its indefinite article
//     has to be chosen rather than written. CCPB W2026 read "a 88%" on the page.
check("the worked example takes the right indefinite article",
  () => [[1, "a"], [5, "a"], [8, "an"], [11, "an"], [12, "a"], [18, "an"], [19, "a"],
     [42, "a"], [79, "a"], [80, "an"], [88, "an"], [89, "an"], [90, "a"], [100, "a"]]
      .every(([n, want]) => RS.conf._article(n) === want));
check("…and the rendered example never reads \"a 8\" or \"a 88\"",
  () => !/\ba (8|11|18|8\d)%/.test(supCallout));

// with no disclosable banner column at all, the bullet is dropped entirely
const RS3 = renderSandbox();
suppressionFixture(RS3, 250);            // k above every column
check("no disclosable column -> no small-group bullet at all",
  () => RS3.conf.calloutHtml().indexOf("Small samples are inherently more volatile") === -1);

// 6. control off (k = 1): nothing is suppressed, rendering is unchanged.
const RS2 = renderSandbox();
const openModel = suppressionFixture(RS2, 1);
check("k=1 suppresses nothing", () => !openModel.columns.some((c) => c.suppressed));
const openHtml = RS2.render.tableHtml(openModel, { intervals: true });
check("an unprotected report still prints the small base and its margin",
  () => openHtml.indexOf("4 ⚠") !== -1 && openHtml.indexOf("±49.0pp") !== -1);
check("…and carries no marker", () => openHtml.indexOf("n&lt;") === -1);
check("…and exports it unchanged", () => /\t4 ⚠/.test(RS2.render.tsv(openModel)));
check("…and its explainer still uses the genuinely smallest column",
  () => {
    const b = blockOf(RS2.conf.calloutHtml(), "conf.footer.small_samples");
    return b.indexOf("Legal") !== -1 && b.indexOf("4") !== -1;
  });

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
if (failed) process.exit(1);
