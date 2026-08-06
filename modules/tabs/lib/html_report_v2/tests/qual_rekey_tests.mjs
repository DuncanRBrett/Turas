#!/usr/bin/env node
/**
 * Reader-mark re-keying gate (production review 2026-08, I20).
 *
 * A reader mark used to key on `qcode#idx`, and `idx` is POSITIONAL — re-export
 * the data and every shortlist star, highlighted passage and hub membership
 * silently re-attached to a DIFFERENT respondent's comment. Marks now key on the
 * respondent's opaque `rid` token (`qcode#@<rid>`) whenever the island carries
 * one, and fall back to `qcode#<idx>` byte-identically when it does not.
 *
 * What is gated here (design §5, JS 1-9):
 *   1. a rid island keys new marks qcode#@<rid> in all three stores;
 *   2. a rid-less island keys them qcode#<idx> exactly as before (regression);
 *   3. a version-less idx store + a rid island migrates once — values intact,
 *      _owns preserved (owned AND un-owning), _v: 2 stamped;
 *   4. hubs migrate their marks only — seq / order / name / insight untouched;
 *   5. highlight range arrays ride across verbatim;
 *   6. unresolved idx keys are dropped and the count is logged;
 *   7. migrating an already-migrated store is a byte-level no-op;
 *   8. a _v: 2 store read against a rid-less island is NEVER re-keyed back;
 *   9. savedAll()/highlightsAll() — what saveCopy embeds — emit rid keys.
 *
 * Each scenario runs in a fresh vm context ("a reload") over a shared in-memory
 * localStorage, exactly like a browser session (mirrors state_tests.mjs).
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/qual_rekey_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) {
  if (a !== b) throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a));
}
function keysOf(o) { return Object.keys(o).sort().join(","); }

const RID = ["r0000000000000a1", "r0000000000000b2", "r0000000000000c3"];

/** Two questions over three respondents; `withRids` decides whether the island
 *  carries the stable tokens (a build after I20 with a healthy sidecar) or not
 *  (a pre-I20 build, or one whose sidecar was missing/corrupt). */
function island(withRids) {
  const rec = (idx, text) => {
    const r = { idx: idx, text: text, tier: 0, sentiment: 2, themeVals: {} };
    if (withRids) r.rid = RID[idx];
    return r;
  };
  return {
    textMode: "full", demographicCuts: "block", noteworthyDefault: "all", verbatimScope: "all", n: 3,
    questions: [
      { code: "Q1", title: "Why?", type: "raw", themes: [],
        base: { answered: 3 }, records: [rec(0, "alpha"), rec(1, "bravo"), rec(2, "charlie")] },
      { code: "Q2", title: "What else?", type: "raw", themes: [],
        base: { answered: 2 }, records: [rec(0, "delta"), rec(1, "echo")] }
    ]
  };
}

/** A fresh page load over the given island + localStorage map. Captures
 *  console.info so the "N marks dropped" note can be asserted. */
function boot(qualIsland, store) {
  store = store || new Map();
  const infos = [];
  const sandbox = {
    console: { log: console.log, warn: () => {}, error: console.error, info: (m) => infos.push(String(m)) },
    localStorage: {
      getItem: (k) => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => { store.set(k, String(v)); },
      removeItem: (k) => { store.delete(k); }
    }
  };
  sandbox.globalThis = sandbox;
  sandbox.window = sandbox;
  vm.createContext(sandbox);
  sandbox.TR = {
    fmt: { escapeHtml: (s) => String(s == null ? "" : s), slug: (s) => String(s) },
    d2: { storeKey: (base) => base + ":proj", questionByCode: () => null, state: { filters: [] } },
    QUAL: qualIsland,
    userState: null
  };
  vm.runInContext(readFileSync(path.join(JS_DIR, "27q_qualitative.js"), "utf8"), sandbox,
                  { filename: "27q_qualitative.js" });
  return { qual: sandbox.TR.qual, TR: sandbox.TR, store, infos, island: qualIsland };
}

const SAVED = "turas_v2_qualsaved:proj";
const HL = "turas_v2_qualhl:proj";
const HUBS = "turas_v2_qualhubs:proj";
const rec = (b, qi, ri) => b.island.questions[qi].records[ri];

console.log("Reader-mark re-keying (I20):");

/* ===== 1. a rid island keys new marks by the token, in all three stores ===== */

run("1a. shortlist keys on the rid token", () => {
  const b = boot(island(true));
  b.qual.toggleSave("Q1", rec(b, 0, 1));
  eq(keysOf(b.qual.savedAll()), "Q1#@" + RID[1], "the shortlist key carries @<rid>");
  assert(b.qual.isSaved("Q1", rec(b, 0, 1)), "the record reads back as shortlisted");
  assert(!b.qual.isSaved("Q1", rec(b, 0, 0)), "its neighbour is untouched");
});

run("1b. highlights key on the rid token", () => {
  const b = boot(island(true));
  b.qual.addHighlight("Q1", rec(b, 0, 2), 0, 4);
  eq(keysOf(b.qual.highlightsAll()), "Q1#@" + RID[2], "the highlight key carries @<rid>");
  eq(JSON.stringify(b.qual.getHighlights("Q1", rec(b, 0, 2))), "[[0,4]]", "the range reads back");
});

run("1c. hub marks key on the rid token", () => {
  const b = boot(island(true));
  const h = b.qual.hubCreate("Pricing");
  b.qual.hubToggleMark(h, "Q2", rec(b, 1, 0));
  eq(keysOf(b.qual.hubMarksUnion()), "Q2#@" + RID[0], "the hub mark key carries @<rid>");
  assert(b.qual.hubHasMark(h, "Q2", rec(b, 1, 0)), "the hub reads its own mark back");
});

run("1d. the same respondent keys the same across questions", () => {
  const b = boot(island(true));
  b.qual.toggleSave("Q1", rec(b, 0, 0));
  b.qual.toggleSave("Q2", rec(b, 1, 0));
  eq(keysOf(b.qual.savedAll()), ["Q1#@" + RID[0], "Q2#@" + RID[0]].sort().join(","),
    "one respondent, one token, two questions");
});

/* ===== 2. a rid-less island is byte-identical to the pre-I20 behaviour ====== */

run("2. rid-less island keeps the legacy qcode#idx keys (regression)", () => {
  const b = boot(island(false));
  b.qual.toggleSave("Q1", rec(b, 0, 1));
  b.qual.addHighlight("Q2", rec(b, 1, 0), 1, 3);
  const h = b.qual.hubCreate("Legacy");
  b.qual.hubToggleMark(h, "Q1", rec(b, 0, 2));
  eq(keysOf(b.qual.savedAll()), "Q1#1", "shortlist stays qcode#idx");
  eq(keysOf(b.qual.highlightsAll()), "Q2#0", "highlights stay qcode#idx");
  eq(keysOf(b.qual.hubMarksUnion()), "Q1#2", "hub marks stay qcode#idx");
  assert(!("_v" in JSON.parse(b.store.get(SAVED))), "a legacy-keyed store is NOT stamped _v");
});

run("2b. a bare idx argument still keys qcode#idx (existing callers)", () => {
  const b = boot(island(false));
  b.qual.toggleSave("QX", 7);
  eq(keysOf(b.qual.savedAll()), "QX#7", "a bare index concatenates exactly as before");
});

/* ===== 3. migration of a version-less idx store against a rid island ======= */

run("3a. an OWNED legacy shortlist migrates, keeps _owns, stamps _v: 2", () => {
  const store = new Map([[SAVED, JSON.stringify({ _owns: true, "Q1#0": 1, "Q2#1": 1 })]]);
  const b = boot(island(true), store);
  eq(keysOf(b.qual.savedAll()), ["Q1#@" + RID[0], "Q2#@" + RID[1]].sort().join(","),
    "both marks re-keyed onto their tokens");
  const persisted = JSON.parse(b.store.get(SAVED));
  eq(persisted._owns, true, "ownership is preserved exactly as found");
  eq(persisted._v, 2, "the migrated store is stamped _v: 2");
  eq(persisted["Q1#@" + RID[0]], 1, "the value rides across verbatim");
});

run("3b. an UN-OWNING legacy store migrates without claiming ownership", () => {
  const store = new Map([[SAVED, JSON.stringify({ "Q1#2": 1 })]]);
  const b = boot(island(true), store);
  eq(keysOf(b.qual.savedAll()), "Q1#@" + RID[2], "re-keyed on first read");
  const persisted = JSON.parse(b.store.get(SAVED));
  assert(!("_owns" in persisted), "migration must not claim ownership — the island seed must keep merging");
  eq(persisted._v, 2, "still stamped _v: 2");
});

run("3c. the un-owning migrated store still merges the island seed", () => {
  const store = new Map([[SAVED, JSON.stringify({ "Q1#2": 1 })]]);
  const b = boot(island(true), store);
  b.TR.userState = { qualSaved: { ["Q2#@" + RID[1]]: 1 } };
  eq(keysOf(b.qual.savedAll()), ["Q1#@" + RID[2], "Q2#@" + RID[1]].sort().join(","),
    "seed + migrated local state merge (ownership was not claimed)");
});

run("3d. a reader edit after migration re-persists WITH the _v stamp", () => {
  const store = new Map([[SAVED, JSON.stringify({ _owns: true, "Q1#0": 1 })]]);
  const b = boot(island(true), store);
  b.qual.toggleSave("Q2", rec(b, 1, 1));
  const persisted = JSON.parse(b.store.get(SAVED));
  eq(persisted._v, 2, "the stamp survives an ordinary persist (else the next load re-migrates)");
  const b2 = boot(island(true), store);          // a reload must not re-migrate
  eq(keysOf(b2.qual.savedAll()), ["Q1#@" + RID[0], "Q2#@" + RID[1]].sort().join(","),
    "both marks survive the reload intact");
});

/* ===== 4. hubs: marks migrate, everything else is untouched ================ */

run("4. hub marks migrate; seq / order / name / insight untouched", () => {
  const legacy = {
    seq: 4,
    order: ["3", "4"],
    byId: {
      "3": { id: "3", name: "Pricing", insight: "price is the whole story", marks: { "Q1#0": 1, "Q2#1": 1 } },
      "4": { id: "4", name: "Service", insight: "", marks: { "Q1#2": 1 } }
    }
  };
  const store = new Map([[HUBS, JSON.stringify(legacy)]]);
  const b = boot(island(true), store);
  const s = b.qual.hubsAll();
  eq(s.seq, 4, "seq untouched");
  eq(s.order.join(","), "3,4", "order untouched");
  eq(s.byId["3"].name, "Pricing", "name untouched");
  eq(s.byId["3"].insight, "price is the whole story", "insight untouched");
  eq(keysOf(s.byId["3"].marks), ["Q1#@" + RID[0], "Q2#@" + RID[1]].sort().join(","), "hub 3 marks re-keyed");
  eq(keysOf(s.byId["4"].marks), "Q1#@" + RID[2], "hub 4 marks re-keyed");
  eq(JSON.parse(b.store.get(HUBS))._v, 2, "the hub store is stamped _v: 2");
});

/* ===== 5. highlights: the range arrays ride across verbatim ================ */

run("5. highlight range arrays survive migration verbatim", () => {
  const store = new Map([[HL, JSON.stringify({ _owns: true, "Q1#1": [[0, 3], [7, 12]] })]]);
  const b = boot(island(true), store);
  eq(JSON.stringify(b.qual.getHighlights("Q1", rec(b, 0, 1))), "[[0,3],[7,12]]",
    "both ranges carried, in order, unaltered");
  eq(keysOf(b.qual.highlightsAll()), "Q1#@" + RID[1], "under the new key");
});

/* ===== 6. unresolved keys are dropped, and said so ========================= */

run("6. unresolved idx keys dropped, resolvable ones kept, count logged", () => {
  const store = new Map([[SAVED, JSON.stringify({ _owns: true, "Q1#0": 1, "Q1#99": 1, "QZ#0": 1 })]]);
  const b = boot(island(true), store);
  eq(keysOf(b.qual.savedAll()), "Q1#@" + RID[0], "only the resolvable mark survives");
  const note = b.infos.filter((m) => m.indexOf("reader mark(s) dropped") >= 0);
  eq(note.length, 1, "exactly one console note");
  assert(note[0].indexOf("2 reader mark(s) dropped") >= 0,
    "the note names the count (2): got " + note[0]);
});

/* ===== 7. idempotence ===================================================== */

run("7. migrating an already-migrated store is a byte-level no-op", () => {
  const bytes = JSON.stringify({ _owns: true, _v: 2, ["Q1#@" + RID[0]]: 1 });
  const store = new Map([[SAVED, bytes]]);
  const b = boot(island(true), store);
  eq(keysOf(b.qual.savedAll()), "Q1#@" + RID[0], "the mark is read, not re-keyed");
  eq(b.store.get(SAVED), bytes, "localStorage is untouched byte for byte");
  eq(b.infos.filter((m) => m.indexOf("dropped") >= 0).length, 0, "and nothing is reported dropped");
});

/* ===== 8. no down-migration =============================================== */

run("8. a _v: 2 store read against a rid-less island is left completely alone", () => {
  const bytes = JSON.stringify({ _owns: true, _v: 2, ["Q1#@" + RID[0]]: 1, ["Q2#@" + RID[1]]: [[0, 2]] });
  const store = new Map([[SAVED, bytes], [HL, bytes]]);
  const b = boot(island(false), store);          // the corrupt-sidecar case
  eq(b.qual.savedCount(), 2, "the marks are still in the store (invisible, not deleted)");
  assert(!b.qual.isSaved("Q1", rec(b, 0, 0)), "they simply do not resolve against an idx-keyed island");
  eq(b.store.get(SAVED), bytes, "shortlist bytes untouched");
  eq(b.store.get(HL), bytes, "highlight bytes untouched");
});

run("8b. a rid island returning makes those marks visible again", () => {
  const bytes = JSON.stringify({ _owns: true, _v: 2, ["Q1#@" + RID[0]]: 1 });
  const store = new Map([[SAVED, bytes]]);
  boot(island(false), store);                     // the broken build, then a fixed one
  const b = boot(island(true), store);
  assert(b.qual.isSaved("Q1", rec(b, 0, 0)), "the mark comes back once the tokens return");
});

/* ===== 9. what saveCopy embeds =========================================== */

run("9. savedAll()/highlightsAll() emit rid keys post-migration, no meta fields", () => {
  const store = new Map([
    [SAVED, JSON.stringify({ _owns: true, "Q1#0": 1 })],
    [HL, JSON.stringify({ _owns: true, "Q2#1": [[1, 4]] })]
  ]);
  const b = boot(island(true), store);
  const saved = b.qual.savedAll(), hl = b.qual.highlightsAll();
  eq(keysOf(saved), "Q1#@" + RID[0], "the saveCopy shortlist embed is rid-keyed");
  eq(keysOf(hl), "Q2#@" + RID[1], "the saveCopy highlight embed is rid-keyed");
  assert(!("_owns" in saved) && !("_v" in saved), "no meta fields ride into the embed");
  assert(!("_owns" in hl) && !("_v" in hl), "…nor into the highlight embed");
});

run("9b. a rid-keyed saved copy re-opens with its marks (the seed is a no-op)", () => {
  const b = boot(island(true));
  b.TR.userState = { qualSaved: { ["Q1#@" + RID[2]]: 1 }, qualHighlights: { ["Q1#@" + RID[2]]: [[0, 2]] } };
  assert(b.qual.isSaved("Q1", rec(b, 0, 2)), "the embedded shortlist seeds through untouched");
  eq(JSON.stringify(b.qual.getHighlights("Q1", rec(b, 0, 2))), "[[0,2]]",
    "…and so does the embedded highlight");
});

/* ===== the pool resolves rid keys back to their records =================== */

run("10. collectPool resolves rid keys, and reports a stale one as an orphan", () => {
  const b = boot(island(true));
  const pool = b.qual.collectPool(b.island,
    { ["Q1#@" + RID[0]]: 1, ["Q1#@deadbeefdeadbeef"]: 1 }, {}, {});
  eq(pool.items.length, 1, "the live mark resolves");
  eq(pool.items[0].record.text, "alpha", "…to the right record");
  eq(pool.items[0].idx, 0, "the item still carries the record's idx (masks + export read it)");
  eq(pool.items[0].key, "Q1#@" + RID[0], "and the mark key it came from");
  eq(pool.orphans, 1, "the token that no longer exists is an orphan, not a wrong attachment");
});

run("11. a stale idx key never resolves against a rid island", () => {
  const b = boot(island(true));
  const pool = b.qual.collectPool(b.island, { "Q1#1": 1 }, {}, {});
  eq(pool.items.length, 0, "a positional key must not silently grab whoever is at that position now");
  eq(pool.orphans, 1, "it reads as an orphan");
});

console.log((failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
