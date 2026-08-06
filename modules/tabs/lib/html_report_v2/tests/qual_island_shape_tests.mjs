#!/usr/bin/env node
/**
 * Qualitative tab — the island shape R ACTUALLY EMITS (production review 2026-08, I12a).
 *
 * The blind spot this closes: the main qual suite (qual_tests.mjs) runs on
 * hand-authored records, not one of which carries a `rid` — a pre-I20 shape. The
 * rekey suite (qual_rekey_tests.mjs) has rids but no `band`, no `suppressed` and
 * no `demos`. So the record production emits — all four on one record — was
 * exercised by no JS test, and every mark helper (which keys on `rid` whenever
 * the island carries one) was only ever tested on its legacy idx fallback.
 *
 * This suite reads a COMMITTED island built by the real R builder:
 *   fixture    : ../../../tests/fixtures/qual_island/qual_island.json
 *   generator  : Rscript modules/tabs/tests/fixtures/qual_island/generate_qual_island.R
 *   drift gate : modules/tabs/tests/testthat/test_qual_island_fixture.R rebuilds
 *                the island in memory every run and fails if the JSON is stale.
 *
 * So this file cannot drift away from the engine by transcription error: if R
 * changes shape, the R gate goes red until the fixture is regenerated, and these
 * assertions then run against the new shape.
 *
 * The fixture, in one island: 5 respondents over 2 questions; Q1 themed and
 * band-split (NPS Detractor/Passive/Promoter), Q2 plain raw; every record with a
 * rid and two demographic tags; three records withheld (two tier-0 under
 * verbatim_scope = "noteworthy", one tier-2 hide-marked); respondent "1" in BOTH
 * questions under one rid.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/qual_island_shape_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const FIXTURE = path.join(HERE, "..", "..", "..", "tests", "fixtures",
                          "qual_island", "qual_island.json");

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) {
  if (a !== b) throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a));
}

const ISLAND = JSON.parse(readFileSync(FIXTURE, "utf8"));
const Q1 = ISLAND.questions[0], Q2 = ISLAND.questions[1];
const RID = {};                                   // idx -> rid, straight off the fixture
ISLAND.questions.forEach((q) => q.records.forEach((r) => { RID[q.code + ":" + r.idx] = r.rid; }));

/** A fresh module load over a fresh in-memory localStorage — one "reload". */
function load() { return loadWith(ISLAND); }

/** The same, against a specific island (for the confidentiality-dial cases). */
function loadWith(island) {
  const store = {};
  const box = {
    console,
    localStorage: {
      getItem: (k) => (k in store ? store[k] : null),
      setItem: (k, v) => { store[k] = String(v); },
      removeItem: (k) => { delete store[k]; }
    }
  };
  box.globalThis = box; box.window = box;
  vm.createContext(box);
  box.TR = {
    fmt: {
      escapeHtml: (s) => String(s == null ? "" : s),
      score: (v) => Number(v).toFixed(1),
      base: (n) => String(n)
    },
    d2: { storeKey: (k) => k + "::fixture" },
    QUAL: island,
    // The ResponseID join that points a closed question at its open-end — what
    // priorityQuotes resolves through in production.
    AGG: { project: { qualLinks: { QC1: { qcode: "Q1", title: "Why that score?" } } } }
  };
  vm.runInContext(readFileSync(path.join(JS_DIR, "21_stats.js"), "utf8"), box,
                  { filename: "21_stats.js" });
  vm.runInContext(readFileSync(path.join(JS_DIR, "27q_qualitative.js"), "utf8"), box,
                  { filename: "27q_qualitative.js" });
  box.TR.qual._resetRekey();
  return box.TR.qual;
}

console.log("Qualitative island — the shape R emits (I12a):");

/* ===== 1. the record shape itself ========================================== */

run("1. the fixture is the production shape: rid + band + suppressed + demos", () => {
  // Guards the suite against a fixture that silently lost the fields it exists
  // to carry — which would leave everything below testing the legacy path green.
  const r = Q1.records[2];
  assert(/^[0-9a-f]{16}$/.test(r.rid), "record carries a 16-hex rid");
  eq(r.band, "Passive", "record carries its split band");
  assert(r.suppressed === true, "a withheld record carries suppressed");
  eq(r.demos.Dept, "Admin", "record carries its demographic tags");
  assert(Q1.records.every((x) => x.rid), "every Q1 record has a rid");
  assert(Q2.records.every((x) => x.rid), "every Q2 record has a rid");
});

run("2. an un-themed record's themeVals arrives as [] and is handled as empty", () => {
  // R serialises an empty named list as a JSON ARRAY, not an object. A
  // hand-written {} fixture hides this; Object.keys([]) is [] so the helpers
  // must — and do — treat it as no themes rather than throwing.
  const q = load();
  const bare = Q2.records[0];
  assert(Array.isArray(bare.themeVals), "the fixture really does carry [] here");
  eq(q.recordsForTheme(Q2.records, 0).length, 0, "no record answers a theme Q2 has not got");
  const prev = q.prevalence(Q2.records, Q2.themes || []);
  eq(prev.length, 0, "prevalence over a theme-less question is empty, not a crash");
});

/* ===== 2. marks key on the rid, not the position ========================== */

run("3. a mark on a real record keys on @rid", () => {
  const q = load();
  const rec = Q1.records[0];
  eq(q.markRef(rec), "@" + rec.rid, "markRef prefers the rid");
  eq(q.markKeyFor("Q1", rec), "Q1#@" + rec.rid, "the mark key is qcode#@rid");
  assert(q.isSaved("Q1", rec) === false, "not saved before saving");
  assert(q.toggleSave("Q1", rec) === true, "toggleSave turns it on");
  eq(Object.keys(q.savedAll()).join(","), "Q1#@" + rec.rid,
     "the persisted shortlist key carries the rid, not the idx");
  assert(q.isSaved("Q1", rec) === true, "and reads back as saved");
});

run("4. the SAME respondent in two questions gets one identity, two marks", () => {
  // Respondent "1" is idx 0 in both Q1 and Q2. A mark on their Q1 comment must
  // not mark their Q2 comment, and both must resolve to the same person.
  const q = load();
  const a = Q1.records[0], b = Q2.records[0];
  eq(a.rid, b.rid, "the fixture gives them one rid across both questions");
  q.toggleSave("Q1", a);
  assert(q.isSaved("Q1", a) === true, "the Q1 comment is shortlisted");
  assert(q.isSaved("Q2", b) === false, "the Q2 comment is NOT");
  eq(q.savedCount("Q1"), 1, "counted under Q1");
  eq(q.savedCount("Q2"), 0, "and not under Q2");
});

run("5. two records that share an idx across questions do not collide", () => {
  // Q1 idx 0 and Q2 idx 0 are the same person; Q1 idx 1 and Q2 idx 4 are not.
  // Under legacy idx keying "Q1#0" and "Q2#0" were already distinct by qcode —
  // what rid keying adds is that the key survives a re-export.
  const q = load();
  q.toggleSave("Q1", Q1.records[1]);
  q.toggleSave("Q2", Q2.records[1]);
  const keys = Object.keys(q.savedAll()).sort();
  eq(keys.length, 2, "two distinct marks");
  assert(keys.every((k) => k.indexOf("#@") > 0), "both keyed by rid: " + keys.join(","));
});

run("6. highlights and hub marks key on the rid too", () => {
  const q = load();
  const rec = Q1.records[0];
  q.addHighlight("Q1", rec, 0, 5);
  eq(Object.keys(q.highlightsAll()).join(","), "Q1#@" + rec.rid,
     "the highlight store is rid-keyed");
  eq(JSON.stringify(q.getHighlights("Q1", rec)), "[[0,5]]", "the range reads back");
  const hub = q.hubCreate("Board pack");
  q.hubToggleMark(hub, "Q1", rec);
  assert(q.hubHasMark(hub, "Q1", rec) === true, "the hub mark is on the record");
  eq(Object.keys(q.hubMarksUnion()).join(","), "Q1#@" + rec.rid, "and is rid-keyed");
});

run("7. the pool resolves rid keys back to the real records", () => {
  const q = load();
  const a = Q1.records[0], b = Q2.records[0];       // both readable
  const saved = {}; saved["Q1#@" + a.rid] = 1;
  const hl = {}; hl["Q2#@" + b.rid] = [[0, 4]];
  hl["Q1#@0000000000000000"] = [[0, 2]];            // a stale token: nobody in this island
  const pool = q.collectPool(ISLAND, saved, hl);
  eq(pool.items.length, 2, "both live marks resolve");
  eq(pool.orphans, 1, "the stale rid is one orphan, skipped not rendered");
  eq(pool.items.map((it) => it.qcode).sort().join(","), "Q1,Q2", "one item per question");
});

run("7b. a mark on a WITHHELD comment is counted as withheld, not as an orphan", () => {
  // A quote collection has nothing to show for a comment whose text this report
  // does not publish — but the mark is not stale either, and must not be
  // reported as a broken reference.
  const q = load();
  const gone = Q1.records[2];                       // suppressed: text is null
  assert(gone.suppressed === true && gone.text === null, "the fixture record is withheld");
  const saved = {}; saved["Q1#@" + gone.rid] = 1;
  const pool = q.collectPool(ISLAND, saved, {});
  eq(pool.items.length, 0, "nothing to render");
  eq(pool.withheld, 1, "counted as withheld");
  eq(pool.orphans, 0, "and NOT as an orphan — the record exists, its text does not");
});

run("7c. an idx key never resolves against this rid-bearing island", () => {
  // The I20 rule: in a rid-keyed report a stray positional key reads as an
  // orphan rather than silently re-attaching to whoever sits at that slot now.
  const q = load();
  const pool = q.collectPool(ISLAND, { "Q1#0": 1 }, {});
  eq(pool.items.length, 0, "the idx key resolves to nobody");
  eq(pool.orphans, 1, "it is an orphan, not respondent 0's comment");
});

/* ===== 3. withheld comments count but never list ========================== */

run("8. shown() drops exactly the three withheld records", () => {
  const q = load();
  eq(Q1.records.length, 4, "Q1 has 4 records");
  eq(q.shown(Q1.records).length, 2, "2 of Q1's 4 are readable");
  eq(q.shown(Q2.records).length, 1, "1 of Q2's 2 is readable");
  // The withheld ones are still in the pool the distributions read.
  const prev = q.prevalence(Q1.records, Q1.themes);
  const service = prev.filter((p) => p.label === "Service")[0];
  eq(service.n, 2, "Service is mentioned twice — including by a withheld comment");
  eq(service.pct, 50, "…and that mention still counts toward the 4-commenter base");
});

run("9. a hide-marked comment is withheld even though its tier would ship it", () => {
  const q = load();
  const hidden = Q1.records[3];
  eq(hidden.tier, 2, "tier 2 — must-read");
  assert(hidden.suppressed === true, "and yet withheld");
  assert(q.shown(Q1.records).indexOf(hidden) === -1, "so it is not in the readable list");
  // It still passes the tier filter, because the distribution counts it.
  assert(q.tierFilter(Q1.records, "must_read").indexOf(hidden) >= 0,
    "tierFilter is about the tier, not about whether the text ships");
});

run("10. the scope chip tells the reader the list is not the whole distribution", () => {
  // Under verbatim_scope = "noteworthy" the scope chip wins over the hide chip and
  // states the policy plus the FULL count, so a reader looking at 2 comments knows
  // the theme percentages beside them are computed over 4.
  const q = load();
  const chip = q.scopeChip(ISLAND, Q1);
  assert(chip.indexOf("<") === 0, "it is rendered markup");
  assert(/Noteworthy comments only/.test(chip), "it names the scope: " + chip);
  assert(/All 4 comments are still counted/.test(chip),
    "and states the full base, not the readable count: " + chip);
});

run("11. a withheld comment exports as [hidden], never as its text", () => {
  const q = load();
  const rows = q.exportRows(ISLAND, Q1, Q1.records);
  const verbatim = rows.slice(1).map((r) => r[r.length - 1]);
  eq(verbatim.filter((t) => t === "[hidden]").length, 2, "both withheld rows export [hidden]");
  assert(verbatim.indexOf("Great value for the price") >= 0, "the shown one exports its text");
});

/* ===== 4. the split band ================================================== */

run("12. bandFilter cuts Q1 by its declared bands", () => {
  const q = load();
  eq(q.bandFilter(Q1, Q1.records, "Detractor").length, 2, "2 detractors in the fixture");
  eq(q.bandFilter(Q1, Q1.records, "Promoter").length, 1, "1 promoter");
  eq(q.bandFilter(Q1, Q1.records, "").length, 4, "All (empty band) passes everything");
});

run("13. bandCount counts only the comments the reader can actually read", () => {
  const q = load();
  // 2 detractors, but one of them is the hide-marked record — the button must
  // match the list it navigates to.
  eq(q.bandCount(Q1, Q1.records, "Detractor"), 1, "1 readable detractor");
  eq(q.bandCount(Q1, Q1.records, "Promoter"), 1, "1 readable promoter");
  eq(q.bandCount(Q1, Q1.records, "Passive"), 0, "the passive comment is withheld");
});

run("14. a question with no split ignores the band entirely", () => {
  const q = load();
  eq(q.bandFilter(Q2, Q2.records, "Detractor").length, 2,
     "a band pick carried over from Q1 must not empty Q2");
});

run("15. the export carries the band column only for the split question", () => {
  const q = load();
  const h1 = q.exportRows(ISLAND, Q1, Q1.records)[0];
  const h2 = q.exportRows(ISLAND, Q2, Q2.records)[0];
  eq(h1.join("|"), "ID|NPS|Dept|Tenure|Noteworthy|Sentiment|Themes|Verbatim",
     "Q1 exports its NPS band between the ID and the demographics");
  eq(h2.join("|"), "ID|Dept|Tenure|Noteworthy|Sentiment|Themes|Verbatim",
     "Q2 has no band column at all");
  eq(q.exportRows(ISLAND, Q1, Q1.records)[1][1], "Promoter", "and the value rides along");
});

run("16. priority quotes group by band in the question's declared order", () => {
  const q = load();
  // Resolved through the ResponseID join from the closed question, as in the report.
  const quotes = q.priorityQuotes("QC1");
  eq(quotes.length, 2, "the two tier-3 comments quote");
  // The fixture lists the Promoter FIRST, but the declared band order is
  // Detractor -> Passive -> Promoter, so reading order must not follow record id.
  eq(quotes.map((qt) => qt.band).join(","), "Detractor,Promoter",
     "reading order follows the declared bands, not the record order");
  const groups = q.groupQuotesByBand(quotes);
  eq(groups.map((g) => g.band).join(","), "Detractor,Promoter", "one group per band");
  eq(groups[0].quotes[0].text, "Support is slow to respond", "each group carries its quote");
});

run("16b. a withheld comment never becomes a priority quote", () => {
  const q = load();
  const quotes = q.priorityQuotes("QC1");
  assert(quotes.every((qt) => qt.text != null && qt.text !== ""),
    "no null-text quote reaches the pin");
  assert(quotes.every((qt) => qt.idx !== 3), "the hide-marked tier-2 record is not quoted");
});

/* ===== 5. demographics ==================================================== */

run("17. the export header and values come from the island's demographics", () => {
  const q = load();
  const rows = q.exportRows(ISLAND, Q1, Q1.records);
  eq(rows[1].slice(2, 4).join("|"), "Admin|5+ yrs", "both tags export, in island order");
  eq(rows[2].slice(2, 4).join("|"), "Finance|1-4 yrs", "…for every record");
});

run("18. a sub-k audience withholds the tags AND the text on export", () => {
  const q = load();
  const rows = q.exportRows(ISLAND, Q1, Q1.records, false);
  eq(rows[1][2], "[hidden]", "Dept withheld");
  eq(rows[1][3], "[hidden]", "Tenure withheld");
  eq(rows[1][rows[1].length - 1], "[hidden]", "and the verbatim with them");
  eq(rows[1][1], "Promoter",
     "…but the band still exports — it mirrors a closed question already reported");
});

run("19. a quote carries its demographic tags as attribution", () => {
  const q = load();
  const quotes = q.priorityQuotes("QC1");
  const promoter = quotes.filter((qt) => qt.band === "Promoter")[0];
  eq(promoter.tags.join(" · "), "Admin · 5+ yrs",
     "both tags ride the quote, in island order");
  eq(promoter.sentiment, "pos", "and the sentiment maps to its class");
});

run("20. blocking demographic cuts strips the tags from a quote, keeping the band", () => {
  // The band mirrors a closed question already reported, so it is never treated
  // as a demographic tag and is not subject to the cuts dial.
  const blocked = JSON.parse(JSON.stringify(ISLAND));
  blocked.demographicCuts = "block";
  const quotes = loadWith(blocked).priorityQuotes("QC1");
  eq(quotes.length, 2, "the quotes still appear");
  assert(quotes.every((qt) => qt.tags.length === 0), "with no demographic tags");
  eq(quotes.map((qt) => qt.band).join(","), "Detractor,Promoter", "but keeping their bands");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
