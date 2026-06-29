// Qualitative tab — pure-helper known-answer suite (node, no DOM).
// Loads 27q_qualitative.js with a TR.fmt stub and checks the prevalence,
// tier-filter and theme-record helpers against hand-computable answers.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const jsDir = path.join(here, "..", "assets", "js");

globalThis.TR = { fmt: { escapeHtml: (s) => String(s == null ? "" : s) } };
new Function(fs.readFileSync(path.join(jsDir, "27q_qualitative.js"), "utf8"))();
const qual = globalThis.TR.qual;

let passed = 0, failed = 0;
function assert(cond, msg) {
  if (cond) { passed++; console.log("  ✓ " + msg); }
  else { failed++; console.log("  ✗ " + msg); }
}

// Themed question: Price mentioned by 2 of 4 commenters (1 pos, 1 neg); Service by 1
// (neutral); one commenter coded no theme. Tiers: must-read(2), noteworthy(1), other(0).
// Demographics: Campus + NPS, for the facet filter.
const q = {
  code: "Q1", title: "Why?", type: "themed",
  themes: [{ id: 0, label: "Price" }, { id: 1, label: "Service" }],
  records: [
    { idx: 0, tier: 1, sentiment: 1, themeVals: { "0": 1 }, demos: { Campus: "Cape Town", NPS: "Promoter" } },
    { idx: 1, tier: 0, sentiment: 3, themeVals: { "0": 3 }, demos: { Campus: "Durban", NPS: "Detractor" } },
    { idx: 2, tier: 2, sentiment: 2, themeVals: { "1": 2 }, demos: { Campus: "Cape Town", NPS: "Detractor" } },
    { idx: 3, tier: 0, themeVals: {}, demos: { Campus: "Durban", NPS: "Promoter" } }
  ]
};

console.log("Qualitative tab — pure helpers:");

const prev = qual.prevalence(q.records, q.themes);
assert(prev[0].label === "Price" && prev[0].n === 2 && prev[0].pct === 50,
  "prevalence: Price = 2 mentions = 50% of 4 commenters");
assert(prev[0].pos === 1 && prev[0].neg === 1 && prev[0].net === 0,
  "prevalence: Price split pos 1 / neg 1, net 0");
assert(prev[1].label === "Service" && prev[1].pct === 25,
  "prevalence: Service 25%, sorted after Price (by volume)");

assert(qual.tierFilter(q.records, "all").length === 4, "tierFilter all -> 4");
assert(qual.tierFilter(q.records, "noteworthy").length === 2, "tierFilter noteworthy+ -> 2 (tier>=1)");
assert(qual.tierFilter(q.records, "must_read").length === 1, "tierFilter must-read -> 1 (tier>=2)");

assert(qual.recordsForTheme(q.records, 0).length === 2, "recordsForTheme Price -> 2");

// Demographic facets: single dim, AND across dims, and empty = no filter.
assert(qual.facetFilter(q.records, {}).length === 4, "facetFilter {} -> all 4");
assert(qual.facetFilter(q.records, { Campus: "Cape Town" }).length === 2,
  "facetFilter Campus=Cape Town -> 2");
assert(qual.facetFilter(q.records, { Campus: "Cape Town", NPS: "Promoter" }).length === 1,
  "facetFilter Campus=Cape Town AND NPS=Promoter -> 1 (record 0)");
// Prevalence recomputes over the facet-cut audience (Cape Town: 1 Price, 1 Service).
const cpt = qual.prevalence(qual.facetFilter(q.records, { Campus: "Cape Town" }), q.themes);
assert(cpt[0].pct === 50 && cpt[1].pct === 50, "prevalence recomputes over the facet cut (Cape Town)");

// ---- Phase-2 jump helpers (linkFor / commentCount / maskFilter / affordanceHtml) ----
// Stubs: Q28 (a closed question) links to the QUAL_SAT open-end; the cut mask keeps
// respondents 0 and 2 (a "filtered" call), or all when no filter.
const TR = globalThis.TR;
TR.AGG = { project: { qualLinks: { Q28: { qcode: "QUAL_SAT", sheet: "Satisfaction", title: "Satisfaction" } } } };
TR.QUAL = { questions: [{ code: "QUAL_SAT", records: [{ idx: 0 }, { idx: 1 }, { idx: 2 }, { idx: 3 }] }] };
TR.MICRO = { n: 4 };
TR.stats = { mask: function (filters) {
  const m = new Uint8Array(4);
  if (filters && filters.length) { m[0] = 1; m[2] = 1; } else { m.fill(1); }
  return m;
} };

console.log("\nQualitative jump helpers:");
assert(qual.linkFor("Q28") && qual.linkFor("Q28").qcode === "QUAL_SAT", "linkFor resolves a linked closed question");
assert(qual.linkFor("Q99") === null, "linkFor returns null for an unlinked code");
assert(qual.commentCount("QUAL_SAT") === 4, "commentCount (no cut) = all records");
assert(qual.commentCount("QUAL_SAT", [{ q: "Q1", rows: [1] }]) === 2, "commentCount within the cut mask = 2");
assert(qual.commentCount("NOPE") === 0, "commentCount for a missing question = 0");

const recs = TR.QUAL.questions[0].records;
assert(qual.maskFilter(recs, [{ q: "Q1", rows: [1] }]).length === 2, "maskFilter keeps masked respondents (idx 0,2)");
assert(qual.maskFilter(recs, []).length === 4, "maskFilter with no cut keeps all");

const aff = qual.affordanceHtml("Q28");
assert(aff.indexOf("💬 4 comments") >= 0 && aff.indexOf('data-qual-jump="Q28"') >= 0,
  "affordanceHtml renders a 💬 button carrying the jump target");
assert(qual.affordanceHtml("Q99") === "", "affordanceHtml is empty for an unlinked card");

// ---- shortlist (save) + export ----------------------------------------------
console.log("\nQualitative shortlist + export:");
assert(qual.isSaved("Q1", 0) === false, "isSaved false before saving");
assert(qual.toggleSave("Q1", 0) === true && qual.isSaved("Q1", 0) === true, "toggleSave on -> saved");
qual.toggleSave("Q1", 2);
assert(qual.savedCount("Q1") === 2, "savedCount per question counts both");
assert(qual.toggleSave("Q1", 0) === false && qual.isSaved("Q1", 0) === false, "toggleSave off -> unsaved");
assert(qual.savedFilter(q.records, "Q1").length === 1, "savedFilter keeps only shortlisted (idx 2)");

// visibleRecords composes theme -> tier -> shortlist on the passed audience.
const all4 = q.records;
assert(qual.visibleRecords(q, { tier: "all", savedOnly: false }, all4).length === 4, "visibleRecords: all");
assert(qual.visibleRecords(q, { tier: "must_read", savedOnly: false }, all4).length === 1, "visibleRecords: tier must-read -> 1");
assert(qual.visibleRecords(q, { tier: "all", theme: 0, savedOnly: false }, all4).length === 2, "visibleRecords: theme Price -> 2");
assert(qual.visibleRecords(q, { tier: "all", savedOnly: true }, all4).length === 1, "visibleRecords: savedOnly -> the 1 shortlisted");

// exportRows: header + a row per record; hidden text exports as [hidden].
const island = { demographics: [{ label: "Campus" }, { label: "NPS" }] };
const rows = qual.exportRows(island, q, [
  { idx: 5, demos: { Campus: "Cape Town", NPS: "Promoter" }, tier: 2, sentiment: 1, themeVals: { "0": 1 }, text: "great value" },
  { idx: 6, demos: { Campus: "Durban" }, tier: 0, sentiment: 3, themeVals: {}, text: null }
]);
assert(rows[0].join("|") === "ID|Campus|NPS|Noteworthy|Sentiment|Themes|Verbatim", "exportRows header = ID + demos + meta");
assert(rows[1][0] === 5 && rows[1][1] === "Cape Town" && rows[1][5] === "Price" && rows[1][6] === "great value",
  "exportRows maps idx/demos/theme/verbatim");
assert(rows[1][3] === "Must-read" && rows[1][4] === "Positive", "exportRows labels tier + sentiment");
assert(rows[2][6] === "[hidden]", "exportRows: hidden verbatim exports as [hidden] (confidentiality honoured)");

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
