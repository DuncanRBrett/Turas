// Qualitative tab — pure-helper known-answer suite (node, no DOM).
// Loads 27q_qualitative.js with a TR.fmt stub and checks the prevalence,
// tier-filter and theme-record helpers against hand-computable answers.
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const jsDir = path.join(here, "..", "assets", "js");

globalThis.TR = { fmt: { escapeHtml: (s) => String(s == null ? "" : s) } };
new Function(fs.readFileSync(path.join(jsDir, "21_stats.js"), "utf8"))();   // TR.stats.propZ for crosstab sig
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

// Prevalence recomputes over whatever audience it is given (here: the 2 Cape Town
// records, 1 Price + 1 Service) — the audience now comes from the global cut mask,
// not a per-tab facet row, so prevalence is just handed the filtered pool.
const capeTown = q.records.filter((r) => r.demos && r.demos.Campus === "Cape Town");
const cpt = qual.prevalence(capeTown, q.themes);
assert(cpt[0].pct === 50 && cpt[1].pct === 50, "prevalence recomputes over the given audience (Cape Town)");

// ---- theme x banner crosstab (column base = commenters; salience + valence + sig) ----
console.log("\nQualitative theme x banner crosstab:");
const xrecs = [
  { idx: 0, themeVals: { "0": 1 } },   // theme A, positive — in ColX
  { idx: 1, themeVals: { "0": 3 } },   // theme A, negative — in ColX
  { idx: 2, themeVals: { "0": 1 } },   // theme A, positive — outside ColX
  { idx: 3, themeVals: {} }            // commented, no theme — outside ColX
];
const xthemes = [{ id: 0, label: "A" }];
const xcols = [{ label: "Total", member: null }, { label: "ColX", member: [1, 1, 0, 0] }];
const xt = qual.themeCrosstab(xrecs, xthemes, xcols, { mode: "salience" });
assert(xt.columns[0].base === 4 && xt.columns[1].base === 2,
  "column base = commenters in the column (Total 4, ColX 2)");
const tot = xt.rows[0].cells[0], colx = xt.rows[0].cells[1];
assert(tot.salience === 75 && tot.net === 33,
  "Total: 3 of 4 raised A, net (2 pos - 1 neg)/3 = +33");
assert(tot.ofBase.pos === 50 && tot.ofBase.neg === 25,
  "of-base split sums toward salience (50 pos + 25 neg of 75)");
assert(tot.ofMen.pos === 67 && tot.ofMen.neg === 33, "of-mentioners split sums to 100");
assert(colx.salience === 100 && colx.net === 0, "ColX: both commenters raised A, 1 pos 1 neg = net 0");
assert(tot.men === 3 && tot.pos === 2 && tot.neg === 1 && tot.mix === 0,
  "cell carries raw counts (men/pos/mix/neg) for the Counts tickbox to display");
assert(xt.rows[0].cells.every((c) => c.sig === ""),
  "tiny bases fail the sig preconditions -> no false significance");
const sup = qual.themeCrosstab(xrecs, xthemes, xcols, { minBase: 3 });
assert(sup.columns[1].suppressed === true && sup.columns[0].suppressed === false,
  "a column below the disclosure threshold is flagged suppressed (Total never is)");

// C-round: a 3-way even split (1 pos / 1 mix / 1 neg) must reconcile —
// independently rounding each to 33 would sum to 99, not the 100 salience.
const drecs = [
  { idx: 0, themeVals: { "0": 1 } }, { idx: 1, themeVals: { "0": 2 } }, { idx: 2, themeVals: { "0": 3 } }
];
const dc = qual.themeCrosstab(drecs, [{ id: 0, label: "A" }], [{ label: "Total", member: null }], {}).rows[0].cells[0];
assert(dc.salience === 100, "all 3 raised the theme -> salience 100");
assert(dc.ofBase.pos + dc.ofBase.mix + dc.ofBase.neg === dc.salience,
  "of-base split reconciles with salience, no ±1 drift: " + JSON.stringify(dc.ofBase));
assert(dc.ofMen.pos + dc.ofMen.mix + dc.ofMen.neg === 100,
  "of-mentioners split sums to exactly 100: " + JSON.stringify(dc.ofMen));

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
// Disclosure control: a too-small audience (safeDemos=false) exports the demographic
// columns AND the verbatim as [hidden], so a small cut can't be exported with any
// identifying detail — the text is just as identifying as the tags on a named sub-k cut.
const exposed = qual.exportRows(island, q, [
  { idx: 5, demos: { Campus: "Cape Town", NPS: "Promoter" }, tier: 2, sentiment: 1, themeVals: {}, text: "great value" }
], false);
assert(exposed[1][1] === "[hidden]" && exposed[1][2] === "[hidden]",
  "exportRows safeDemos=false -> demographic columns hidden");
assert(exposed[1][6] === "[hidden]", "exportRows safeDemos=false also withholds the verbatim (no text leak on a sub-k export)");
assert(rows[1][1] === "Cape Town", "exportRows default (safeDemos omitted) -> demographics shown");

// ---- sentiment filter + counts ----------------------------------------------
// Fixture q: record 0 pos(1), record 1 neg(3), record 2 mixed(2), record 3 no sentiment.
console.log("\nQualitative sentiment filter:");
const scAll = qual.sentimentCounts(q.records);
assert(scAll.pos === 1 && scAll.neu === 1 && scAll.neg === 1, "sentimentCounts: 1 pos / 1 mixed / 1 neg (4th has none)");
assert(qual.sentimentFilter(q.records, null).length === 4, "sentimentFilter null -> all");
assert(qual.sentimentFilter(q.records, 1).length === 1 && qual.sentimentFilter(q.records, 1)[0].idx === 0,
  "sentimentFilter positive -> the 1 positive record");
assert(qual.sentimentFilter(q.records, 3).length === 1, "sentimentFilter negative -> 1");
// visibleRecords composes sentiment after theme/tier/saved.
assert(qual.visibleRecords(q, { tier: "all", sentiment: 2 }, q.records).length === 1, "visibleRecords sentiment=mixed -> 1");
assert(qual.visibleRecords(q, { tier: "all", sentiment: null }, q.records).length === 4, "visibleRecords sentiment=null -> all");
// poolBeforeSentiment ignores the sentiment pick (so the filter buttons can tally).
assert(qual.poolBeforeSentiment(q, { tier: "must_read", sentiment: 1 }, q.records).length === 1,
  "poolBeforeSentiment applies tier but NOT sentiment (must-read -> 1)");

// hasSentiment gates the whole sentiment control: only a question with real overall
// sentiment coding gets the filter (a raw/un-coded question would show "0 positive").
const rawQ = { code: "QR", title: "Raw", type: "raw", themes: [], records: [
  { idx: 0, tier: 1, sentiment: null, themeVals: {}, demos: {} },
  { idx: 1, tier: 0, sentiment: null, themeVals: {}, demos: {} },
  { idx: 2, tier: 0, sentiment: 0,    themeVals: {}, demos: {} } ] };
assert(qual.hasSentiment(q) === true, "hasSentiment true when records carry 1/2/3");
assert(qual.hasSentiment(rawQ) === false, "hasSentiment false when no record is sentiment-coded");
assert(qual.hasSentiment({ records: [] }) === false, "hasSentiment false for an empty question");
// A sentiment pick carried over from a coded question must NOT empty an un-coded one.
assert(qual.visibleRecords(rawQ, { tier: "all", sentiment: 1 }, rawQ.records).length === 3,
  "visibleRecords ignores a stale sentiment pick on an un-coded question (no silent empty)");

// ---- highlight a passage -----------------------------------------------------
console.log("\nQualitative highlight:");
assert(qual.renderHighlighted("hello world", [[0, 5]]).indexOf('<mark class="ql-hl" data-s="0">hello</mark>') === 0,
  "renderHighlighted wraps the range in a mark");
assert(qual.renderHighlighted("abc", []) === "abc", "renderHighlighted with no ranges = plain text");
assert(qual.renderHighlighted(null, [[0, 1]]) === "", "renderHighlighted of hidden/null text = empty");
qual.addHighlight("HLQ", 0, 0, 5);
assert(JSON.stringify(qual.getHighlights("HLQ", 0)) === "[[0,5]]", "addHighlight stores the range");
qual.addHighlight("HLQ", 0, 3, 9);
assert(JSON.stringify(qual.getHighlights("HLQ", 0)) === "[[0,9]]", "overlapping ranges merge");
qual.addHighlight("HLQ", 0, 20, 25);
assert(qual.getHighlights("HLQ", 0).length === 2, "a disjoint range is kept separate");
qual.removeHighlight("HLQ", 0, 0);
assert(JSON.stringify(qual.getHighlights("HLQ", 0)) === "[[20,25]]", "removeHighlight drops the range by start offset");

// ---- collection: the pool (all marks) aggregated across questions -----------
// A stand-alone island with two questions; the pool is passed in explicitly (not the
// module's mutable store), so every count below is hand-computable.
console.log("\nQualitative collection (the pool, all marks):");
const colIsland = {
  demographics: [{ label: "Campus" }],
  questions: [
    { code: "Q1", title: "Why recommend?", type: "themed",
      themes: [{ id: 0, label: "Price" }, { id: 1, label: "Service" }],
      records: [
        { idx: 0, tier: 2, sentiment: 1, themeVals: { "0": 1 }, demos: { Campus: "Cape Town" }, text: "great value" },
        { idx: 2, tier: 0, sentiment: 3, themeVals: { "1": 3 }, demos: { Campus: "Durban" }, text: "slow support" }
      ] },
    { code: "Q2", title: "Anything else?", type: "raw", themes: [],
      records: [ { idx: 1, tier: 1, sentiment: null, themeVals: {}, demos: { Campus: "Cape Town" }, text: "more parking" } ] }
  ]
};
// shortlist Q1#0 + Q2#1; highlight Q1#0 (so it's both) + Q1#2; and one stale mark (Q9#7).
const colSaved = { "Q1#0": 1, "Q2#1": 1 };
const colHl = { "Q1#0": [[0, 5]], "Q1#2": [[0, 4]], "Q9#7": [[0, 2]] };
const pool = qual.collectPool(colIsland, colSaved, colHl);
assert(pool.items.length === 3, "collectPool: 3 distinct marks resolve (Q1#0, Q2#1, Q1#2)");
assert(pool.orphans === 1, "collectPool: the stale Q9#7 mark is 1 orphan, skipped not rendered");
const colByKey = {}; pool.items.forEach((it) => { colByKey[it.qcode + "#" + it.idx] = it; });
assert(colByKey["Q1#0"].saved === true && colByKey["Q1#0"].highlighted === true,
  "collectPool: a comment BOTH shortlisted and highlighted is ONE item carrying both flags");
assert(colByKey["Q1#2"].saved === false && colByKey["Q1#2"].highlighted === true,
  "collectPool: a highlight-only mark carries the highlighted flag only");
assert(colByKey["Q2#1"].question.title === "Anything else?", "collectPool: each item carries its source question");
assert(qual.splitMark("Q1#0").qcode === "Q1" && qual.splitMark("Q1#0").idx === 0, "splitMark parses qcode + idx");
assert(qual.splitMark("bad") === null, "splitMark is null on a malformed key");

// A comment filed ONLY in a hub (not shortlisted/highlighted) is still pooled — so
// "add to a hub" is itself a way to save a comment (shortlist + hub in one).
const poolH = qual.collectPool(colIsland, {}, {}, { "Q2#1": 1 });
assert(poolH.items.length === 1 && poolH.items[0].qcode === "Q2" && poolH.items[0].idx === 1,
  "collectPool: a hub-only mark is pooled (add-to-hub = save)");
assert(poolH.items[0].hubbed === true && poolH.items[0].saved === false && poolH.items[0].highlighted === false,
  "collectPool: a hub-only item carries hubbed=true, saved/highlighted=false");
const poolU = qual.collectPool(colIsland, { "Q1#0": 1 }, {}, { "Q1#0": 1 });
assert(poolU.items.length === 1 && poolU.items[0].saved === true && poolU.items[0].hubbed === true,
  "collectPool: a shortlisted + hubbed mark is ONE item carrying both flags");

const gq = qual.groupCollection(colIsland, pool.items, "question");
assert(gq.length === 2 && gq[0].key === "Q1" && gq[1].key === "Q2", "groupCollection question: groups in island order");
assert(gq[0].items.length === 2 && gq[0].label === "Why recommend?", "groupCollection question: Q1 holds its 2 marks, labelled by title");

const gt = qual.groupCollection(colIsland, pool.items, "theme");
const gtBy = {}; gt.forEach((g) => { gtBy[g.label] = g; });
assert(gtBy["Price"] && gtBy["Price"].items.length === 1, "groupCollection theme: Price holds the Q1#0 comment");
assert(gtBy["Service"] && gtBy["Service"].items.length === 1, "groupCollection theme: Service holds the Q1#2 comment");
assert(gtBy["No theme"] && gtBy["No theme"].items.length === 1, "groupCollection theme: the raw Q2 comment falls under No theme");
assert(gt[gt.length - 1].label === "No theme", "groupCollection theme: No theme sorts last");

const crows = qual.collectionExportRows(colIsland, pool.items);
assert(crows[0].join("|") === "ID|Question|Campus|Noteworthy|Sentiment|Themes|Shortlisted|Highlighted|Verbatim",
  "collectionExportRows header = ID + Question + demos + meta + flags + verbatim");
const cRowByText = {}; crows.slice(1).forEach((r) => { cRowByText[r[8]] = r; });
assert(cRowByText["great value"][1] === "Why recommend?" && cRowByText["great value"][2] === "Cape Town",
  "collectionExportRows carries the source question + demographics");
assert(cRowByText["great value"][6] === "Yes" && cRowByText["great value"][7] === "Yes",
  "collectionExportRows flags the shortlisted + highlighted columns");
const csafe = qual.collectionExportRows(colIsland, pool.items, false);
assert(csafe[1][2] === "[hidden]" && csafe[1][8] === "[hidden]",
  "collectionExportRows safeDemos=false hides demographics + verbatim (no sub-k leak)");

// ---- named reader hubs (named lenses over the pool) -------------------------
// The store is the module singleton (empty at process start: no userState/localStorage).
console.log("\nQualitative reader hubs:");
assert(qual.hubList().length === 0, "hubs: none to start");
const h1 = qual.hubCreate("  Masters students  ");
assert(qual.hubGet(h1).name === "Masters students", "hubCreate trims the name");
const h2 = qual.hubCreate("");
assert(qual.hubGet(h2).name === "Untitled hub", "hubCreate blank name -> 'Untitled hub'");
assert(qual.hubList().length === 2 && qual.hubList()[0].id === h1, "hubList is in creation order");
assert(qual.hubToggleMark(h1, "Q1", 0) === true && qual.hubHasMark(h1, "Q1", 0) === true, "hubToggleMark adds a mark");
assert(qual.hubList()[0].count === 1, "hubList count reflects membership");
assert(qual.hubToggleMark(h1, "Q1", 0) === false && qual.hubHasMark(h1, "Q1", 0) === false,
  "hubToggleMark removes it (the mark itself is untouched — hub is only a reference)");
qual.hubToggleMark(h1, "Q1", 0); qual.hubToggleMark(h2, "Q1", 0);   // same comment in two hubs
assert(qual.hubsForMark("Q1", 0).length === 2, "hubsForMark lists every hub the mark is in (overlap)");
assert(qual.hubRename(h1, "  Master's  ") === true && qual.hubGet(h1).name === "Master's", "hubRename trims");
assert(qual.hubRename(h1, "   ") === true && qual.hubGet(h1).name === "Master's", "hubRename all-blank keeps the old name");
assert(qual.hubRename("nope", "x") === false, "hubRename false on an unknown id");
qual.hubDelete(h1);
assert(qual.hubGet(h1) === null && qual.hubList().length === 1, "hubDelete removes the hub definition");
assert(qual.hubsForMark("Q1", 0).length === 1 && qual.hubsForMark("Q1", 0)[0].id === h2,
  "after delete, the same mark's membership of OTHER hubs survives (mark never touched)");
const h3 = qual.hubCreate("Third");
assert(h3 !== h1 && parseInt(h3, 10) > parseInt(h2, 10), "hub ids are monotonic — a deleted id is never reissued");

// hub insight + distinct-respondent gate + Story exhibit (step 3)
assert(qual.hubSetInsight(h2, "Masters want faster support") === true, "hubSetInsight true on a real hub");
assert(qual.hubGet(h2).insight === "Masters want faster support", "hubSetInsight stores the finding");
assert(qual.hubSetInsight("nope", "x") === false, "hubSetInsight false on an unknown id");
assert(qual.hubDistinctRespondents([{ record: { idx: 0 } }, { record: { idx: 0 } }, { record: { idx: 3 } }]) === 2,
  "hubDistinctRespondents counts distinct respondents (idx), not comments");

const exItems = [
  { qcode: "Q1", record: { idx: 0, sentiment: 1, text: "great value", demos: { Campus: "Cape Town" } }, question: { title: "Why recommend?" } },
  { qcode: "Q2", record: { idx: 1, sentiment: 3, text: "slow", demos: { Campus: "Durban" } }, question: { title: "Anything else?" } }
];
const ex = qual.hubExhibit({ name: "Masters", insight: "Faster support wanted" }, exItems, { coverage: "2 of 5 marks", safeDemos: true });
assert(ex.title === "Masters" && ex.context === "Faster support wanted", "hubExhibit: title = hub name, context = insight");
assert(ex.html.indexOf("Masters") >= 0 && ex.html.indexOf("Faster support wanted") >= 0 &&
  ex.html.indexOf("great value") >= 0 && ex.html.indexOf("Cape Town") >= 0,
  "hubExhibit html carries the name, insight, quotes + demo code (safeDemos)");
assert(ex.lines[0] === "Masters" && ex.lines.indexOf("Faster support wanted") >= 0 &&
  ex.lines.some((l) => l.indexOf("great value") >= 0), "hubExhibit lines carry the finding + quotes for the deck");
const exSafe = qual.hubExhibit({ name: "X", insight: "" }, exItems, { safeDemos: false });
assert(exSafe.html.indexOf("Cape Town") < 0, "hubExhibit safeDemos=false drops the demographic code");
const many = [];
for (let i = 0; i < 11; i++) many.push({ qcode: "Q1", record: { idx: i, text: "c" + i, demos: {} }, question: { title: "Q" } });
assert(qual.hubExhibit({ name: "Big", insight: "" }, many, { cap: 8 }).html.indexOf("+ 3 more comments in this hub") >= 0,
  "hubExhibit caps quotes at `cap` and notes the remainder");

// ---- disclosure leaks (audit 2026-07-02) -------------------------------------
// 1. the 💬 affordance counts within the ACTIVE cut (and shows no number below k);
// 2. exportXlsx refuses below k (the drawer withholds the list — so must the export);
// 3. the controls row hides live counts + the export button below k (render-level).
console.log("\nQualitative disclosure leaks:");

// affordanceHtml: the stubbed cut mask (set up above) keeps idx 0 and 2 -> 2 of 4.
TR.d2 = { state: { filters: [{ q: "Q1", rows: [1] }] } };
TR.disclosure = null;
assert(qual.affordanceHtml("Q28").indexOf("💬 2 comments") >= 0,
  "affordanceHtml counts within the ACTIVE cut (2 of 4, matching what the jump reveals)");
TR.d2.state.filters = [];
assert(qual.affordanceHtml("Q28").indexOf("💬 4 comments") >= 0,
  "affordanceHtml with no cut -> the unfiltered 4");
TR.d2.state.filters = [{ q: "Q1", rows: [1] }];
TR.disclosure = { audienceTooSmall: () => true };
const gatedAff = qual.affordanceHtml("Q28");
assert(gatedAff.indexOf("💬 comments") >= 0 && !/💬 \d/.test(gatedAff),
  "below k the affordance shows NO number (the count itself would leak)");

// exportXlsx: below k the drawer withholds the whole list — the export must too.
let dl = null;
TR.xlsx = { download: (name, sheet, rows, opts) => { dl = { name, sheet, rows, opts }; } };
TR.disclosure = { audienceTooSmall: () => true };
qual.exportXlsx(island, q, q.records);
assert(dl === null, "exportXlsx below k refuses — no file, not even row-level metadata");
TR.disclosure = { audienceTooSmall: () => false };
qual.exportXlsx(island, q, q.records.slice(0, 1));
assert(dl !== null && dl.rows.length === 2 && dl.rows[1][1] === "Cape Town",
  "exportXlsx at/above k exports normally (header + 1 row, demographics shown)");

// controls row + header, via qual.render on an inert host (no DOM needed: wire()
// finds no elements). Question: 4 answered, cut mask keeps idx 0 + 2 (2 shown),
// sentiment-coded 2 pos / 0 mixed / 1 neg over the cut? — counts are over the FULL
// pool passed (audience = the 2 masked records: idx 0 pos, idx 2 pos -> 2 pos).
TR.QUAL = {
  textMode: "full", noteworthyDefault: "all", demographicCuts: "safe",
  demographics: [{ label: "Campus" }],
  questions: [{ code: "QS", title: "Open feedback", type: "raw", themes: [],
    base: { answered: 4 },
    records: [
      { idx: 0, tier: 0, sentiment: 1, themeVals: {}, demos: {}, text: "a" },
      { idx: 1, tier: 0, sentiment: 3, themeVals: {}, demos: {}, text: "b" },
      { idx: 2, tier: 0, sentiment: 1, themeVals: {}, demos: {}, text: "c" },
      { idx: 3, tier: 0, sentiment: 3, themeVals: {}, demos: {}, text: "d" }
    ] }]
};
TR.d2 = { state: { filters: [{ q: "Q1", rows: [1] }], qualQ: null, qualFrom: null },
  questionByCode: () => null, filterDescription: () => "cut" };
const host = { innerHTML: "", querySelectorAll: () => [], querySelector: () => null };

TR.disclosure = null;                                  // ungated render first
qual._state = null;
qual.render(host);
const openHtml = host.innerHTML;
assert(openHtml.indexOf("2 of 4 answered") >= 0, "ungated header shows the cut count (2 of 4 answered)");
assert(openHtml.indexOf("data-qual-export") >= 0, "ungated controls render the ⬇ Export button");
assert(openHtml.indexOf('All <span class="ql-segn">2</span>') >= 0 &&
  openHtml.indexOf('Positive <span class="ql-segn">2</span>') >= 0 &&
  openHtml.indexOf('Negative <span class="ql-segn">0</span>') >= 0,
  "ungated sentiment chips carry live counts (All 2 · Positive 2 · Negative 0 over the cut)");

TR.disclosure = { active: () => true, minBase: () => 10,
  audienceTooSmall: () => true, note: () => "Withheld to protect confidentiality." };
qual._state = null;
qual.render(host);
const gatedHtml = host.innerHTML;
assert(gatedHtml.indexOf("data-qual-export") < 0, "below k the ⬇ Export button is NOT rendered at all");
assert(gatedHtml.indexOf("ql-segn") < 0, "below k the sentiment chips carry NO counts");
assert(gatedHtml.indexOf("2 of 4 answered") < 0 && gatedHtml.indexOf("4 answered") >= 0,
  "below k the header shows only the unfiltered total (4 answered), never the cut count");
assert(gatedHtml.indexOf('data-tier="all" disabled') >= 0 &&
  gatedHtml.indexOf('data-sent="" disabled') >= 0,
  "below k the tier + sentiment controls render disabled");
assert(gatedHtml.indexOf("Withheld to protect confidentiality.") >= 0,
  "below k the controls row carries the standard disclosure note");

TR.disclosure = null;   // leave no gate behind for anything after

// ---- dashboard: the 💬 pill renders in its own footer slot, never over the score ----
// Regression for the overlap bug: the pill was absolutely positioned at the card's
// top-left, on top of the "8.0/10" headline. The card must now (a) flag the wrap
// with .has-qual so CSS reserves a footer slot, and (b) emit the pill as a SIBLING
// of the gauge button, outside the score/title markup.
console.log("\nDashboard comment-pill slot:");
{
  const sandbox = { console };
  sandbox.globalThis = sandbox;
  sandbox.window = sandbox;
  const mkModel = () => ({
    rows: [{ kind: "mean", cells: [{ mean: 8.03 }], delta: null }],
    columns: [{ label: "Total", base: 1155 }]
  });
  sandbox.TR = {
    fmt: { escapeHtml: (s) => String(s == null ? "" : s), base: (n) => String(n) },
    charts: { clip: (s) => String(s) },
    render: { wavePoints: () => null, sparkline: () => "" },
    model: { forQuestion: () => mkModel() },
    d2: { state: { banner: "b1", filters: [] }, firstBanner: () => "b1", filtersActive: () => false },
    cards2: { waveLabels: () => ({ prev: null }) },
    conf: { labels: () => ({ interval_abbrev: "SI", precision_term: "margin of error",
      moe_name: "Margin of error", moe_abbrev: "MoE" }), maxMoePct: () => 2.9, fmtRange: () => "" },
    AGG: {
      project: {},
      banner_groups: [{ id: "b1", name: "Banner" }],
      questions: [
        { code: "Q1", title: "A deliberately long question title that wraps across several lines of the card",
          type: "scale", scale_max: 10, category: "Experience", rows: [{ kind: "mean" }] },
        { code: "Q2", title: "Unlinked question", type: "scale", scale_max: 10,
          category: "Experience", rows: [{ kind: "mean" }] }
      ]
    },
    // Only Q1 carries linked comments — Q2 proves the slot is conditional.
    qual: { affordanceHtml: (code) => code === "Q1"
      ? '<button class="ql-jumpbtn" data-qual-jump="Q1">💬 1155 comments</button>' : "" }
  };
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(path.join(jsDir, "27_views.js"), "utf8"), sandbox,
    { filename: "27_views.js" });
  const host = { innerHTML: "", querySelectorAll: () => [], querySelector: () => null };
  sandbox.TR.views.dashboard(host);
  const dash = host.innerHTML;

  const q1 = dash.slice(dash.indexOf('data-goq="Q1"') - 200, dash.indexOf('data-goq="Q2"'));
  assert(q1.indexOf('class="gauge-wrap has-qual"') >= 0,
    "linked card: wrap carries .has-qual so CSS reserves the pill's footer slot");
  const gaugeClose = q1.indexOf("</button>");   // the gauge button closes after the title
  const pillAt = q1.indexOf("ql-jumpbtn");
  assert(pillAt >= 0 && gaugeClose >= 0 && pillAt > gaugeClose,
    "linked card: pill is a sibling AFTER the gauge button, not inside the score/title markup");
  assert(q1.indexOf("💬 1155 comments") >= 0, "linked card: pill text + jump wiring intact");

  const q2 = dash.slice(dash.indexOf('data-goq="Q2"') - 200);
  assert(q2.indexOf("has-qual") < 0 && q2.indexOf("ql-jumpbtn") < 0,
    "unlinked card: no .has-qual flag and no pill");

  // CSS contract: the pill is pinned to the card FOOTER (bottom, never top) and
  // .has-qual reserves the slot's height with bottom padding on the gauge.
  const css = fs.readFileSync(path.join(here, "..", "assets", "styles.css"), "utf8");
  const pillRule = (css.match(/\.gauge-wrap \.ql-jumpbtn\s*\{[^}]*\}/) || [""])[0];
  assert(/bottom:/.test(pillRule) && !/[^-]top:/.test(pillRule),
    "CSS: .gauge-wrap .ql-jumpbtn anchors to the bottom of the card, never the top");
  const slotRule = (css.match(/\.gauge-wrap\.has-qual[^{]*\{[^}]*\}/) || [""])[0];
  assert(/padding-bottom:/.test(slotRule),
    "CSS: .has-qual reserves the footer slot with padding-bottom on the gauge");
}

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
