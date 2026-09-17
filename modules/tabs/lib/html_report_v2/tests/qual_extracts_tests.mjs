#!/usr/bin/env node
/**
 * Qualitative EXTRACTS. A fragment is quotable beside the themes it evidences,
 * and nowhere else.
 *
 * The bug: a coded row carries one verbatim and N theme codes, so a fragment the
 * analyst extracted for one theme was shown beside all N, reading as evidence for
 * something the respondent may not have said.
 *
 * These run against the COMMITTED island built by the real R builder
 *   fixture   : ../../../tests/fixtures/qual_island/qual_island.json
 *   generator : Rscript modules/tabs/tests/fixtures/qual_island/generate_qual_island.R
 *   drift gate: modules/tabs/tests/testthat/test_qual_island_fixture.R
 * so nothing here can pass against a shape R does not emit. Q3 of that fixture
 * holds the shape that matters: respondent 6 is coded Pay AND Workload, with a
 * fragment written for Pay only; respondent 7 carries an "all" fragment.
 *
 * The last test is a STATIC gate over the module source. The fix works by having
 * exactly one accessor read a comment's text for display, so any new raw read is
 * a place where the bug can come back. A deliberate read outside a theme context
 * must say so with an "unscoped-text" marker on its line.
 *
 * Design and decisions: modules/tabs/docs/QUALITATIVE_EXTRACTS_PLAN.md
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const SRC = path.join(JS_DIR, "27q_qualitative.js");
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
const Q3 = ISLAND.questions[2];
const PAY = 0, WORKLOAD = 1;                 // theme ids, straight off the fixture

function load(island) {
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
    fmt: { escapeHtml: (s) => String(s == null ? "" : s),
           score: (v) => Number(v).toFixed(1), base: (n) => String(n) },
    d2: { storeKey: (k) => k + "::fixture" },
    QUAL: island || ISLAND
  };
  vm.runInContext(readFileSync(path.join(JS_DIR, "21_stats.js"), "utf8"), box,
                  { filename: "21_stats.js" });
  vm.runInContext(readFileSync(SRC, "utf8"), box, { filename: "27q_qualitative.js" });
  box.TR.qual._resetRekey();
  return box.TR.qual;
}

/** Loads the module with TR.xlsx stubbed, and returns what the download was handed.
 *  The point is to drive the REAL wiring rather than the inner row builder. */
function loadWithXlsx(island) {
  const captured = {};
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
    fmt: { escapeHtml: (s) => String(s == null ? "" : s),
           score: (v) => Number(v).toFixed(1), base: (n) => String(n),
           slug: (s) => String(s).toLowerCase().replace(/[^a-z0-9]+/g, "_") },
    d2: { storeKey: (k) => k + "::fixture" },
    QUAL: island || ISLAND,
    xlsx: { download: (name, sheet, rows, opts) => {
      captured.name = name; captured.rows = rows; captured.opts = opts;
    } }
  };
  vm.runInContext(readFileSync(path.join(JS_DIR, "21_stats.js"), "utf8"), box,
                  { filename: "21_stats.js" });
  vm.runInContext(readFileSync(SRC, "utf8"), box, { filename: "27q_qualitative.js" });
  box.TR.qual._resetRekey();
  return { q: box.TR.qual, captured: captured };
}

const recPay = Q3.records[0];          // coded Pay + Workload, fragment for Pay
const recAll = Q3.records[1];          // coded Pay + Workload, "all" fragment
const recTwo = Q3.records[2];          // coded Pay + Workload, a DIFFERENT fragment each

console.log("Qualitative extracts. A fragment beside the theme it evidences:");

run("1. the fixture carries the shape R emits for a fragment", () => {
  eq(recPay.extracts["0"], "the pay half of the comment", "the Pay fragment is on the record");
  eq(recPay.hasExtracts, true, "hasExtracts");
  eq(recPay.textTheme, PAY, "textTheme names the theme the unscoped text speaks to");
  eq(recAll.extractAll, "a trim that covers both", "the 'all' fragment ships once");
  assert(recAll.extracts === undefined, "an 'all' fragment is not repeated per theme");
});

run("2. a fragment shows beside the theme it was written for", () => {
  const q = load();
  eq(q.textFor(recPay, PAY), "the pay half of the comment", "Pay page shows the Pay fragment");
});

run("3. and shows NOTHING beside a theme it makes no claim about", () => {
  const q = load();
  eq(q.textFor(recPay, WORKLOAD), null, "the Workload page quotes nothing from this comment");
  eq(q.quotableUnder(recPay, WORKLOAD), false, "so it is not quotable there");
});

run("4. but the comment still COUNTS under both themes", () => {
  const q = load();
  const rows = q.prevalence(Q3.records, Q3.themes);
  const workload = rows.filter((r) => r.id === WORKLOAD)[0];
  const pay = rows.filter((r) => r.id === PAY)[0];
  eq(workload.n, 3, "Workload is still raised by all three commenters");
  eq(pay.n, 3, "and so is Pay");
  eq(workload.pct, 100, "the distribution is untouched by where quotes appear");
});

run("5. an 'all' fragment stands in on every coded theme", () => {
  const q = load();
  eq(q.textFor(recAll, PAY), "a trim that covers both", "Pay");
  eq(q.textFor(recAll, WORKLOAD), "a trim that covers both", "Workload");
});

run("6. away from a theme page the record's own unscoped text is used", () => {
  const q = load();
  eq(q.textFor(recPay, null), "the pay half of the comment", "the lead fragment leads");
  eq(q.textFor(recPay, undefined), "the pay half of the comment", "undefined reads as no theme");
  eq(q.textFor(recPay, q.OTHER_THEME), "the pay half of the comment",
     "'everything else' is not a theme claim either");
  assert(q.textFor(recPay, null) !== "a long comment about pay and about workload",
         "the verbatim itself never ships for a comment with a fragment");
});

run("7. a comment with no fragments is completely unaffected", () => {
  const q = load();
  const plain = ISLAND.questions[0].records[0];      // Q1, no extracts
  eq(q.textFor(plain, 0), plain.text, "its verbatim shows beside its theme");
  eq(q.textFor(plain, 1), plain.text, "and beside a theme it is not coded on (the caller filters that)");
  eq(q.quotableUnder(plain, 1), true, "the extracts rule never touches it");
});

run("8. a withheld comment stays withheld, fragments or not", () => {
  const q = load();
  const suppressed = ISLAND.questions[0].records[2];  // scope withheld it
  eq(suppressed.text, null, "the fixture really withholds it");
  eq(q.textFor(suppressed, 0), null, "and no theme page shows it");
});

run("8b. a withheld comment carrying fragments still shows nothing", () => {
  // The R builder cannot currently emit text: null WITH fragments, because the
  // dial withholds both together. This pins the guard against a future builder
  // change or a hand-edited island; the check that claimed to pin it was passing
  // through a different branch entirely (review 2026-09-17, C11).
  const q = load();
  const handBuilt = { idx: 99, text: null, hasExtracts: true,
                      extracts: { "0": "would leak" }, extractAll: "would also leak",
                      themeVals: { "0": 1 } };
  eq(q.textFor(handBuilt, 0), null, "no theme page shows it");
  eq(q.textFor(handBuilt, null), null, "and neither does any unscoped context");
  eq(q.quotableUnder(handBuilt, 0), false, "so it is not quotable anywhere");
});

run("9. the comment list drops a comment with nothing to say here, and keeps its count", () => {
  const q = load();
  const st = { tier: "all", sentiment: null, theme: WORKLOAD };
  const visible = q.visibleRecords(Q3, st, Q3.records);
  eq(visible.length, 2, "the 'all' comment and the two-fragment one are quotable here");
  assert(visible.every((r) => r.idx !== recPay.idx),
         "and the Pay-only comment is not among them");
  const all3 = q.visibleRecords(Q3, { tier: "all", sentiment: null, theme: PAY }, Q3.records);
  eq(all3.length, 3, "all three are quotable under Pay");
});

run("10. a champion quote is never a fragment from another theme", () => {
  const q = load();
  const champs = q.championQuotes(Q3.records, WORKLOAD, "Q3", 3);
  eq(champs.length, 2, "only the two comments with something to say here can champion it");
  assert(champs.every((r) => r.idx !== recPay.idx),
         "the Pay-only comment can never champion Workload");
  // And what each champion SHOWS is this theme's fragment, not its default one.
  const two = champs.filter((r) => r.idx === recTwo.idx)[0];
  eq(q.textFor(two, WORKLOAD), "the workload half only", "its Workload half champions");
  eq(q.championQuotes(Q3.records, PAY, "Q3", 3).length, 3, "all three champion Pay");
});

run("11. the drawer export writes the text the drawer is showing", () => {
  const q = load();
  const rows = q.exportRows(ISLAND, Q3, Q3.records, true, WORKLOAD);
  const verbatimCol = rows[0].length - 1;
  eq(rows[1][verbatimCol], "[hidden]", "the Pay-only comment exports as withheld under Workload");
  eq(rows[2][verbatimCol], "a trim that covers both", "the 'all' comment exports its fragment");
  const payRows = q.exportRows(ISLAND, Q3, Q3.records, true, PAY);
  eq(payRows[1][verbatimCol], "the pay half of the comment", "and under Pay it exports the Pay fragment");
});

run("11b. the Excel file the reader downloads carries the theme's fragment", () => {
  // exportXlsx took a themeId and never passed it on, so a Workload-scoped export
  // carried the Pay fragment: the feature's own bug, in a file, with the screen
  // showing the right text (review 2026-09-17, C1). Test 11 could not see it
  // because it called exportRows directly and skipped the wiring.
  const { q, captured } = loadWithXlsx();
  q.exportXlsx(ISLAND, Q3, Q3.records, WORKLOAD);
  const verbatimCol = captured.rows[0].length - 1;
  const texts = captured.rows.slice(1).map((r) => r[verbatimCol]);
  assert(texts.indexOf("the workload half only") >= 0,
         "the downloaded file carries the Workload fragment: " + JSON.stringify(texts));
  assert(texts.indexOf("the pay half only") < 0,
         "and never the Pay fragment of the same comment");
  assert(texts.indexOf("[hidden]") >= 0, "the Pay-only comment exports as withheld here");

  const pay = loadWithXlsx();
  pay.q.exportXlsx(ISLAND, Q3, Q3.records, PAY);
  const payTexts = pay.captured.rows.slice(1).map((r) => r[verbatimCol]);
  assert(payTexts.indexOf("the pay half only") >= 0, "and the Pay export carries the Pay half");
});

run("12. drawerTheme is the one definition of which theme is on screen", () => {
  const q = load();
  eq(q.drawerTheme(Q3, { theme: PAY }), PAY, "a theme selection");
  eq(q.drawerTheme(Q3, { theme: null }), null, "all comments");
  eq(q.drawerTheme(Q3, { theme: q.OTHER_THEME }), null, "everything else is not a theme");
  eq(q.drawerTheme(ISLAND.questions[1], { theme: PAY }), null, "a raw question has no themes");
});

run("13. a mark on one fragment does not move to another fragment", () => {
  const q = load();
  // recTwo shows a DIFFERENT string on each theme page, so each needs its own mark.
  q.addHighlight("Q3", recTwo, 0, 3, WORKLOAD);
  eq(q.getHighlights("Q3", recTwo, WORKLOAD).length, 1, "the Workload fragment carries it");
  eq(q.getHighlights("Q3", recTwo, PAY).length, 0, "the Pay page does not");
  assert(Object.keys(q.highlightsAll()).some((k) => k.indexOf(":t" + WORKLOAD) > 0),
         "a fragment's mark carries its theme in the key");
});

run("13b. a comment that shows the SAME text everywhere keeps ONE mark", () => {
  // The regression this guards (review C2): suffixing every card's key on a theme
  // page retired every reader mark in every saved copy ever made, including on
  // projects with no extracts sheet at all.
  const q = load();
  const plain = ISLAND.questions[0].records[0];        // no extracts anywhere
  q.addHighlight("Q1", plain, 0, 5);                   // as an older build wrote it
  eq(q.getHighlights("Q1", plain).length, 1, "the mark is there unscoped");
  eq(q.getHighlights("Q1", plain, 0).length, 1, "and still there on a theme page");
  eq(q.getHighlights("Q1", plain, 1).length, 1, "and on any other theme");
  assert(Object.keys(q.highlightsAll()).every((k) => k.indexOf(":t") < 0),
         "a comment with no fragments never gets a per-theme key");
  // The key itself, which is what the original line got wrong for every record.
  eq(q.hlKeyFor("Q1", plain, 0), q.markKeyFor("Q1", plain),
     "no suffix for a comment with no fragments");
  eq(q.hlKeyFor("Q3", recAll, WORKLOAD), q.markKeyFor("Q3", recAll),
     "nor for an 'all' fragment, which is the same string on every page");
  eq(q.hlKeyFor("Q3", recPay, PAY), q.markKeyFor("Q3", recPay),
     "nor for a fragment that IS the comment's unscoped text");
  // The same holds for a fragment whose text IS the comment's unscoped text.
  q.addHighlight("Q3", recPay, 0, 3, PAY);
  eq(q.getHighlights("Q3", recPay).length, 1, "one mark, reachable from both views");
  eq(q.getHighlights("Q3", recPay, PAY).length, 1, "because it is the same string");
});

run("14. one comment pools once, however many fragments carry marks", () => {
  const q = load();
  q.addHighlight("Q3", recTwo, 0, 3, PAY);
  q.addHighlight("Q3", recTwo, 4, 7, WORKLOAD);
  const pool = q.collectPool(ISLAND, {}, q.highlightsAll(), {});
  eq(pool.items.length, 1, "the collection holds the comment once, not once per fragment");
  eq(pool.items[0].highlighted, true, "and knows it is marked up");
  eq(pool.orphans, 0, "a themed key is not an orphan");
});

run("15. clearing a comment's marks clears every fragment's marks", () => {
  const q = load();
  q.addHighlight("Q3", recTwo, 0, 3, PAY);
  q.addHighlight("Q3", recTwo, 4, 7, WORKLOAD);
  q.clearHighlights("Q3", recTwo);
  eq(q.getHighlights("Q3", recTwo, PAY).length, 0, "Pay cleared");
  eq(q.getHighlights("Q3", recTwo, WORKLOAD).length, 0, "Workload cleared");
});

run("16. splitMark reads a themed key back, and keeps the bare ref", () => {
  const q = load();
  const themed = q.hlKeyFor("Q3", recTwo, WORKLOAD);
  const m = q.splitMark(themed);
  eq(m.qcode, "Q3", "question");
  eq(m.theme, WORKLOAD, "theme");
  eq(m.ref, q.splitMark(q.markKeyFor("Q3", recTwo)).ref, "the ref is the comment's, not the fragment's");
  eq(q.splitMark(q.markKeyFor("Q3", recTwo)).theme, null, "an unscoped key has no theme");
  eq(q.bareMark(themed), q.markKeyFor("Q3", recTwo), "bareMark strips the suffix");
  eq(q.bareMark("Q3#@abc"), "Q3#@abc", "and leaves a key that never had one");
});

run("17. the drawer card keys its marks to the fragment it is showing", () => {
  const q = load();
  const onWorkload = q._quoteCard(recTwo, "Q3", WORKLOAD, Q3);
  const onPay = q._quoteCard(recTwo, "Q3", PAY, Q3);
  const unscoped = q._quoteCard(recTwo, "Q3", null, Q3);
  assert(onWorkload.indexOf('data-hl-key="Q3#') >= 0, "the card carries a highlight key");
  assert(onWorkload.indexOf(":t" + WORKLOAD + '"') >= 0,
         "the Workload fragment is a different string, so it is keyed to the theme");
  assert(onPay.indexOf(":t") < 0,
         "the Pay fragment IS this comment's unscoped text, so it keeps the bare key");
  assert(unscoped.indexOf(":t") < 0, "and no suffix at all away from a theme page");
  // A comment with no fragments must never get a per-theme key (review C2).
  assert(q._quoteCard(ISLAND.questions[0].records[0], "Q1", 0, ISLAND.questions[0])
           .indexOf(":t") < 0, "a comment with no fragments keeps its old key");
  // The shortlist is deliberately NOT per theme: a comment is starred once.
  const save = /data-qual-save="([^"]+)"/.exec(onWorkload);
  assert(save && save[1].indexOf(":t") < 0, "the shortlist key stays the comment's own");
  // The fragment on screen is the one quoted in the card.
  assert(q._quoteCard(recPay, "Q3", WORKLOAD).indexOf("quote hidden") >= 0,
         "under Workload the Pay-only comment shows no quote");
  assert(q._quoteCard(recPay, "Q3", PAY).indexOf("the pay half of the comment") >= 0,
         "under Pay it shows its fragment");
});

run("18. a fragment says on its face that it is an extract", () => {
  const q = load();
  eq(q.extractLabel(recPay, PAY, Q3).indexOf("extract") >= 0, true, "labelled on its theme page");
  assert(q.extractLabel(recPay, PAY, Q3).indexOf("on Pay") < 0,
         "the theme is not named where the reader already is");
  // Away from a theme page the fragment's own theme IS named, so a partial quote is
  // never presented as the whole comment with no clue which part it is.
  assert(q.extractLabel(recPay, null, Q3).indexOf("extract on Pay") >= 0,
         "named away from its theme page");
  eq(q.extractLabel(ISLAND.questions[0].records[0], 0, ISLAND.questions[0]), "",
     "a comment quoted in full carries no label");
  eq(q.extractLabel(recPay, WORKLOAD, Q3), "",
     "and no label where there is no quote to label");
});

run("19. the theme page says how many comments it counts but does not quote", () => {
  const q = load();
  const chip = q.elsewhereChip(Q3, { theme: WORKLOAD }, Q3.records);
  assert(chip.indexOf("1 counted here, quoted elsewhere") >= 0,
         "Workload counts a comment it cannot quote: " + chip);
  assert(chip.indexOf("counted in this theme") >= 0, "and says they are still counted");
  assert(chip.indexOf("describe the comments quoted here") >= 0,
         "and that the list and its filters describe what is quoted here (review C13)");
  eq(q.elsewhereChip(Q3, { theme: PAY }, Q3.records), "",
     "Pay quotes everything it counts, so it says nothing");
  eq(q.elsewhereChip(Q3, { theme: null }, Q3.records), "",
     "and the all-comments list is not a theme page");
});

run("19c. the chip never counts a comment the filter already removed", () => {
  // The reviewer's case: a tier-0 comment with a fragment for another theme. The
  // old chip counted it even on a Priority-only view, so the page claimed a
  // comment the filter had excluded for an unrelated reason (review C5).
  const q = load();
  const hand = {
    code: "QH", title: "Why?", type: "themed",
    themes: [{ id: 0, label: "Pay" }, { id: 1, label: "Workload" }],
    records: [
      { idx: 0, tier: 3, sentiment: 3, themeVals: { "0": 3, "1": 3 },
        text: "pay half", hasExtracts: true, extracts: { "0": "pay half" } },
      { idx: 1, tier: 0, sentiment: 3, themeVals: { "0": 3, "1": 3 },
        text: "other pay half", hasExtracts: true, extracts: { "0": "other pay half" } },
      { idx: 2, tier: 3, sentiment: 3, themeVals: { "1": 3 }, text: "a plain comment" }
    ]
  };
  const all = q.elsewhereChip(hand, { tier: "all", sentiment: null, theme: 1 }, hand.records);
  assert(all.indexOf("2 counted here") >= 0, "both are counted with no filter: " + all);
  const prio = q.elsewhereChip(hand, { tier: "priority", sentiment: null, theme: 1 },
                               hand.records);
  assert(prio.indexOf("1 counted here") >= 0,
         "and only the priority one on a Priority view: " + prio);
  eq(q.visibleRecords(hand, { tier: "priority", sentiment: null, theme: 1 },
                      hand.records).length, 1, "which reconciles with the list's own count");
});

run("19b. the chip counts the same comments the list counted, under any filter", () => {
  // It used to count over every comment coded to the theme, so a tier filter that
  // excluded a comment for an unrelated reason still had the chip claiming it
  // (review C5). recPay is tier 3, recTwo tier 2, recAll tier 1.
  const q = load();
  const state = { tier: "priority", sentiment: null, theme: WORKLOAD };
  const visible = q.visibleRecords(Q3, state, Q3.records);
  const chip = q.elsewhereChip(Q3, state, Q3.records);
  eq(visible.length, 0, "no priority comment can be quoted under Workload");
  assert(chip.indexOf("1 counted here") >= 0,
         "and exactly the one priority comment is reported as quoted elsewhere: " + chip);
  // With the filter off, the same chip counts only the one comment the list dropped
  // for the extracts reason, not the hide-marked or scope-withheld ones.
  const openChip = q.elsewhereChip(Q3, { tier: "all", sentiment: null, theme: WORKLOAD },
                                   Q3.records);
  assert(openChip.indexOf("1 counted here") >= 0, "one, with no filter on: " + openChip);
});

run("19d. a pinned quote, the priority block and the deck all say 'extract'", () => {
  const q = load();
  const quotes = q.priorityQuotesFor(Q3, "What would you change?");
  assert(quotes.length > 0, "Q3 has a priority comment to lead with");
  const frag = quotes.filter((x) => x.text === "the pay half of the comment")[0];
  assert(frag, "the priority comment's fragment is in the payload");
  eq(frag.extract, "extract on Pay", "and the payload carries the note, which a pin freezes");
  // The screen renders from that payload, so the block shows it too.
  assert(q.priorityBlockHtml(quotes).indexOf("extract on Pay") >= 0,
         "the priority block shows it");
  // A comment quoted in full must not be labelled.
  const plainQuotes = q.priorityQuotesFor(ISLAND.questions[0], "Why that score?");
  assert(plainQuotes.every((x) => !x.extract), "a full verbatim carries no note");
});

run("20. the question says once that some comments are quoted by extract", () => {
  const q = load();
  const chip = q.scopeChip(ISLAND, Q3);
  assert(chip.indexOf("Some comments quoted by extract") >= 0, "Q3 says so");
  assert(chip.indexOf("every comment is counted in full") >= 0, "and reassures on the counts");
  assert(q.scopeChip(ISLAND, ISLAND.questions[1]).indexOf("quoted by extract") < 0,
         "a question with no extracts never says it");
  eq(q.scopeChip({ verbatimScope: "all" }, { records: [{ idx: 0, text: "plain" }] }), "",
     "and a question with nothing to declare shows no chip at all");
  // The fixture ships on the "noteworthy" scope, so Q3 has two facts to state. The
  // extract chip is APPENDED rather than replacing the scope chip, or the older
  // fact would silently disappear the moment a question gained an extract.
  const both = q.scopeChip(ISLAND, Q3);
  assert(both.indexOf("Noteworthy comments only") >= 0 &&
         both.indexOf("Some comments quoted by extract") >= 0, "both facts survive");
});

run("21. the cards carry the label the reader needs", () => {
  const q = load();
  assert(q._quoteCard(recPay, "Q3", PAY, Q3).indexOf(">extract<") >= 0,
         "the drawer card on the Pay page");
  assert(q._collectionCard({ question: Q3, record: recPay, qcode: "Q3", saved: true })
           .indexOf("extract on Pay") >= 0,
         "and a collected comment names the theme its fragment speaks to");
});

run("25. STATIC GATE: every record-text read goes through the accessor", () => {
  // The gate exists because the fix works by having ONE reader, so any new raw read
  // is a place the bug can come back. The first version matched three spellings and
  // missed seven the review planted, including `record.text`, `records[i].text` and
  // `it.record.text`, all of which this module already uses (review 2026-09-17, C4).
  // This version matches ANY receiver, allows the known payload objects by name, and
  // reads the whole file rather than line by line so a read split over two lines is
  // still caught.
  const src = readFileSync(SRC, "utf8");
  const lines = src.split("\n");
  const RE = /([A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*|\[[^\]]*\])*)\s*(?:\.\s*text\b|\[\s*["']text["']\s*\])/g;
  // Receivers that are NOT island records: the quote payload a pin or a slide carries.
  const PAYLOAD = { qt: 1, sl: 1, ins: 1, spec: 1 };
  const accessorStart = lines.findIndex((l) => l.indexOf("qual.textFor = function") >= 0);
  assert(accessorStart > 0, "the accessor is still here");
  let accessorEnd = accessorStart;
  while (accessorEnd < lines.length && lines[accessorEnd].indexOf("  };") !== 0) accessorEnd++;

  const offenders = [];
  const flag = (index, note) => {
    const lineNo = src.slice(0, index).split("\n").length;
    const line = lines[lineNo - 1];
    if (lineNo - 1 >= accessorStart && lineNo - 1 <= accessorEnd) return;
    if (line.indexOf("unscoped-text") >= 0) return;
    if (/^\s*(\*|\/\/)/.test(line)) return;
    offenders.push(lineNo + ": " + line.trim() + (note ? "   [" + note + "]" : ""));
  };
  // A parenthesised receiver, e.g. (rec).text, has no name to allowlist, so any
  // such read is flagged outright.
  const PAREN = /\)\s*\.\s*text\b/g;
  let pm;
  while ((pm = PAREN.exec(src))) flag(pm.index, "parenthesised receiver");
  let m;
  while ((m = RE.exec(src))) {
    const receiver = m[1].split(/[.[]/)[0];
    if (PAYLOAD[receiver] || PAYLOAD[m[1]]) continue;
    flag(m.index, "");
  }
  assert(offenders.length === 0,
    "a record's text is read outside qual.textFor without an 'unscoped-text' marker. " +
    "Use qual.textFor(rec, themeId), or mark the line if the context really has no theme:\n    " +
    offenders.join("\n    "));
});

console.log(failed ? "\n✗ " + passed + " passed, " + failed + " failed"
                   : "\n✓ " + passed + " passed, 0 failed");
process.exit(failed ? 1 : 0);
