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

const recPay = Q3.records[0];          // coded Pay + Workload, fragment for Pay
const recAll = Q3.records[1];          // coded Pay + Workload, "all" fragment

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
  eq(workload.n, 2, "Workload is still raised by both commenters");
  eq(pay.n, 2, "and so is Pay");
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

run("9. the comment list drops a comment with nothing to say here, and keeps its count", () => {
  const q = load();
  const st = { tier: "all", sentiment: null, theme: WORKLOAD };
  const visible = q.visibleRecords(Q3, st, Q3.records);
  eq(visible.length, 1, "only the 'all' comment is quotable under Workload");
  eq(visible[0].idx, recAll.idx, "and it is the right one");
  const both = q.visibleRecords(Q3, { tier: "all", sentiment: null, theme: PAY }, Q3.records);
  eq(both.length, 2, "both are quotable under Pay");
});

run("10. a champion quote is never a fragment from another theme", () => {
  const q = load();
  const champs = q.championQuotes(Q3.records, WORKLOAD, "Q3", 2);
  eq(champs.length, 1, "only one comment can champion Workload");
  eq(champs[0].idx, recAll.idx, "the 'all' comment");
  const payChamps = q.championQuotes(Q3.records, PAY, "Q3", 2);
  eq(payChamps.length, 2, "both champion Pay");
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

run("12. drawerTheme is the one definition of which theme is on screen", () => {
  const q = load();
  eq(q.drawerTheme(Q3, { theme: PAY }), PAY, "a theme selection");
  eq(q.drawerTheme(Q3, { theme: null }), null, "all comments");
  eq(q.drawerTheme(Q3, { theme: q.OTHER_THEME }), null, "everything else is not a theme");
  eq(q.drawerTheme(ISLAND.questions[1], { theme: PAY }), null, "a raw question has no themes");
});

run("13. a mark on one fragment does not move to another fragment", () => {
  const q = load();
  q.addHighlight("Q3", recPay, 0, 3, PAY);
  eq(q.getHighlights("Q3", recPay, PAY).length, 1, "the Pay fragment carries the mark");
  eq(q.getHighlights("Q3", recPay, WORKLOAD).length, 0, "the Workload page does not");
  eq(q.getHighlights("Q3", recPay).length, 0, "nor does the unscoped text");
  // The base key format is untouched, so a mark made before extracts existed still loads.
  q.addHighlight("Q3", recAll, 0, 4);
  eq(q.getHighlights("Q3", recAll).length, 1, "an unscoped mark still keys the old way");
  assert(Object.keys(q.highlightsAll()).some((k) => k.indexOf(":t" + PAY) > 0),
         "a themed mark carries its theme in the key");
});

run("14. one comment pools once, however many fragments carry marks", () => {
  const q = load();
  q.addHighlight("Q3", recPay, 0, 3, PAY);
  q.addHighlight("Q3", recPay, 4, 7, WORKLOAD);
  const pool = q.collectPool(ISLAND, {}, q.highlightsAll(), {});
  eq(pool.items.length, 1, "the collection holds the comment once, not once per fragment");
  eq(pool.items[0].highlighted, true, "and knows it is marked up");
  eq(pool.orphans, 0, "a themed key is not an orphan");
});

run("15. clearing a comment's marks clears every fragment's marks", () => {
  const q = load();
  q.addHighlight("Q3", recPay, 0, 3, PAY);
  q.addHighlight("Q3", recPay, 4, 7, WORKLOAD);
  q.clearHighlights("Q3", recPay);
  eq(q.getHighlights("Q3", recPay, PAY).length, 0, "Pay cleared");
  eq(q.getHighlights("Q3", recPay, WORKLOAD).length, 0, "Workload cleared");
});

run("16. splitMark reads a themed key back, and keeps the bare ref", () => {
  const q = load();
  const themed = q.hlKeyFor("Q3", recPay, WORKLOAD);
  const m = q.splitMark(themed);
  eq(m.qcode, "Q3", "question");
  eq(m.theme, WORKLOAD, "theme");
  eq(m.ref, q.splitMark(q.markKeyFor("Q3", recPay)).ref, "the ref is the comment's, not the fragment's");
  eq(q.splitMark(q.markKeyFor("Q3", recPay)).theme, null, "an unscoped key has no theme");
  eq(q.bareMark(themed), q.markKeyFor("Q3", recPay), "bareMark strips the suffix");
  eq(q.bareMark("Q3#@abc"), "Q3#@abc", "and leaves a key that never had one");
});

run("17. the drawer card keys its marks to the fragment it is showing", () => {
  const q = load();
  const onWorkload = q._quoteCard(recAll, "Q3", WORKLOAD);
  const onPay = q._quoteCard(recAll, "Q3", PAY);
  const unscoped = q._quoteCard(recAll, "Q3", null);
  assert(onWorkload.indexOf('data-hl-key="Q3#') >= 0, "the card carries a highlight key");
  assert(onWorkload.indexOf(":t" + WORKLOAD + '"') >= 0, "keyed to the theme on screen");
  assert(onPay.indexOf(":t" + PAY + '"') >= 0, "a different theme, a different key");
  assert(unscoped.indexOf(":t") < 0, "and no suffix at all away from a theme page");
  // The shortlist is deliberately NOT per theme: a comment is starred once.
  const save = /data-qual-save="([^"]+)"/.exec(onWorkload);
  assert(save && save[1].indexOf(":t") < 0, "the shortlist key stays the comment's own");
  // The fragment on screen is the one quoted in the card.
  assert(q._quoteCard(recPay, "Q3", WORKLOAD).indexOf("quote hidden") >= 0,
         "under Workload the Pay-only comment shows no quote");
  assert(q._quoteCard(recPay, "Q3", PAY).indexOf("the pay half of the comment") >= 0,
         "under Pay it shows its fragment");
});

run("18. STATIC GATE: every record-text read goes through the accessor", () => {
  const src = readFileSync(SRC, "utf8").split("\n");
  const READ = /\b(r|rec|recs\[[^\]]*\])\.text\b/;
  // The accessor itself is the one place allowed to read the raw field.
  const accessorStart = src.findIndex((l) => l.indexOf("qual.textFor = function") >= 0);
  assert(accessorStart > 0, "the accessor is still here");
  let accessorEnd = accessorStart;
  while (accessorEnd < src.length && src[accessorEnd].indexOf("  };") !== 0) accessorEnd++;
  const offenders = [];
  src.forEach((line, i) => {
    if (!READ.test(line)) return;
    if (i >= accessorStart && i <= accessorEnd) return;      // inside qual.textFor
    if (line.indexOf("unscoped-text") >= 0) return;          // a considered read, marked
    if (/^\s*(\*|\/\/)/.test(line)) return;                  // prose, not code
    offenders.push((i + 1) + ": " + line.trim());
  });
  assert(offenders.length === 0,
    "a record's text is read outside qual.textFor without an 'unscoped-text' marker. " +
    "Use qual.textFor(rec, themeId), or mark the line if the context really has no theme:\n    " +
    offenders.join("\n    "));
});

console.log(failed ? "\n✗ " + passed + " passed, " + failed + " failed"
                   : "\n✓ " + passed + " passed, 0 failed");
process.exit(failed ? 1 : 0);
