#!/usr/bin/env node
/**
 * Saved-copy state resurrection gate (audit 2026-07-02) — the ownership marker.
 *
 * Every user-state store seeds from the saved-copy island (#user-state) and
 * merges localStorage. Two defect shapes are checked here across ALL stores:
 *   (a) tombstone-less merge — a deletion is key-absence, so an island-seeded
 *       item resurrected on every reload (qual shortlist/highlights, story,
 *       insights, chart annotations);
 *   (b) wholesale replacement — stale pre-existing localStorage for the same
 *       project key hid the island's authored content entirely (report
 *       sections, saved banners, composites).
 * The fix (one design, applied per store): persisted state carries _owns:true
 * once the READER changes anything; owning state is authoritative on load (the
 * island seed is ignored — deletions durable); un-owning legacy state seeds
 * from the island and merges WITHOUT claiming ownership (for the array/section
 * stores: additively, so the island's authored content stays visible).
 *
 * Each scenario runs in a fresh vm context ("a reload") over a shared
 * in-memory localStorage, exactly like a browser session.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/state_tests.mjs
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
function eq(a, b, msg) { if (a !== b) throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a)); }

/** A fresh page load: new vm context + engine files over the given island and
 *  the given localStorage map (shared across "reloads" like a real browser). */
function boot(files, island, store) {
  store = store || new Map();
  const sandbox = {
    console,
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
    d2: { storeKey: (base) => base + ":proj", questionByCode: () => null,
          state: { filters: [] } },
    shell: { toast: () => {} },
    AGG: { project: { name: "proj" } },
    userState: island || null
  };
  for (const f of files) {
    vm.runInContext(readFileSync(path.join(JS_DIR, f), "utf8"), sandbox, { filename: f });
  }
  return { TR: sandbox.TR, store };
}
const parse = (store, key) => JSON.parse(store.get(key + ":proj"));

/* ================= (a) tombstone-less merge — deletions must survive ======= */
console.log("Ownership marker — deletions survive reload:");

run("qual shortlist: un-starring an island-seeded comment stays deleted", () => {
  const island = { qualSaved: { "Q1#0": 1, "Q1#2": 1 } };
  const a = boot(["27q_qualitative.js"], island);
  eq(a.TR.qual.isSaved("Q1", 0), true, "island seeds the shortlist");
  eq(a.TR.qual.toggleSave("Q1", 0), false, "reader un-stars Q1#0");
  const raw = parse(a.store, "turas_v2_qualsaved");
  eq(raw._owns, true, "the reader change marks ownership");
  assert(!("Q1#0" in raw), "the deleted key is absent from the owned state");
  const b = boot(["27q_qualitative.js"], island, a.store);        // reload
  eq(b.TR.qual.isSaved("Q1", 0), false, "the un-starred mark STAYS deleted");
  eq(b.TR.qual.isSaved("Q1", 2), true, "the untouched mark survives");
  eq(b.TR.qual.savedCount(), 1, "count = the 1 surviving mark");
  assert(!("_owns" in b.TR.qual.savedAll()), "savedAll (what saveCopy embeds) never carries the marker");
});

run("qual highlights: removing an island-seeded highlight stays deleted", () => {
  const island = { qualHighlights: { "Q1#0": [[0, 4]], "Q2#1": [[2, 6]] } };
  const a = boot(["27q_qualitative.js"], island);
  eq(a.TR.qual.getHighlights("Q1", 0).length, 1, "island seeds the highlight");
  a.TR.qual.removeHighlight("Q1", 0, 0);
  const b = boot(["27q_qualitative.js"], island, a.store);        // reload
  eq(b.TR.qual.getHighlights("Q1", 0).length, 0, "the removed highlight STAYS removed");
  eq(JSON.stringify(b.TR.qual.getHighlights("Q2", 1)), "[[2,6]]", "the untouched highlight survives");
  assert(!("_owns" in b.TR.qual.highlightsAll()), "highlightsAll never carries the marker");
});

run("story: a reader deletion survives reload; a cleared story stays cleared", () => {
  const island = { story: [{ kind: "divider", title: "A", note: "" },
                           { kind: "divider", title: "B", note: "" }] };
  const a = boot(["30_story.js"], island);
  eq(a.TR.story2.items().length, 2, "island seeds the story");
  a.TR.story2.items().splice(0, 1);          // the ✕ remove path splices…
  a.TR.story2.merge([]);                     // …then persists via the owning path
  const raw = parse(a.store, "turas_v2_story");
  eq(raw._owns, true, "the reader change marks ownership");
  eq(raw.items.length, 1, "owned state carries the remaining item only");
  const b = boot(["30_story.js"], island, a.store);               // reload
  eq(b.TR.story2.items().length, 1, "the deleted item STAYS deleted");
  eq(b.TR.story2.items()[0].title, "B", "the surviving item is the right one");
  // Clear persists an owned EMPTY story — it must beat the island on reload.
  const cleared = new Map([["turas_v2_story:proj", JSON.stringify({ _owns: true, items: [] })]]);
  const c = boot(["30_story.js"], island, cleared);
  eq(c.TR.story2.items().length, 0, "a cleared story stays cleared (empty owned array wins)");
});

run("story: pinning marks ownership; a plain load never does", () => {
  const island = { story: [{ kind: "divider", title: "A", note: "" }] };
  const a = boot(["30_story.js"], island);
  a.TR.story2.items();                       // plain load
  eq(a.store.size, 0, "loading alone writes nothing (no ownership claim)");
  a.TR.story2.pinSnapshot({ source: "qualitative", title: "T", html: "", lines: [] });
  const raw = parse(a.store, "turas_v2_story");
  eq(raw._owns, true, "a pin (reader change) takes ownership");
  eq(raw.items.length, 2, "owned state = island item + the new pin");
});

run("insights: deleting an island-seeded insight stays deleted", () => {
  const island = { insights: { Q10: "old text", Q11: "keep me" } };
  const a = boot(["28_insights.js"], island);
  eq(a.TR.insights.get("Q10"), "old text", "island seeds the insight");
  a.TR.insights.set("Q10", "");              // clearing the box deletes the key
  const b = boot(["28_insights.js"], island, a.store);            // reload
  eq(b.TR.insights.get("Q10"), "", "the cleared insight STAYS cleared");
  eq(b.TR.insights.get("Q11"), "keep me", "the untouched insight survives");
  assert(!("_owns" in b.TR.insights.all()), "insights.all (saveCopy/export payload) never carries the marker");
});

run("chart annotations: deleting an island-seeded tag stays deleted", () => {
  const island = { annotations: { "X::2024": "Campaign launched", "X::2025": "COVID wave" } };
  const a = boot(["27s_notes.js"], island);
  eq(a.TR.notes.get("X", 2024), "Campaign launched", "island seeds the tag");
  a.TR.notes.set("X", 2024, "");             // the chip's ✕ clears the note
  const b = boot(["27s_notes.js"], island, a.store);              // reload
  eq(b.TR.notes.get("X", 2024), "", "the removed tag STAYS removed");
  eq(b.TR.notes.forMetric("X").length, 1, "only the untouched tag remains on the chart");
  eq(b.TR.notes.forMetric("X")[0].text, "COVID wave", "and it is the right one");
});

/* ====== (b) wholesale replacement — island content must stay visible ======= */
console.log("\nOwnership marker — stale un-owning localStorage never hides the island:");

run("report sections: the island's authored content beats stale un-owning local state", () => {
  const island = { report: {
    sections: { background: "authored bg", exec: "authored exec" },
    about: {}, slides: [{ text: "qual slide", title: "" }] } };
  const stale = new Map([["turas_v2_report:proj", JSON.stringify(
    { sections: { exec: "stale reader text", extra: "reader extra" }, about: {}, slides: [] })]]);
  const a = boot(["32_report.js"], island, stale);
  eq(a.TR.report.data().sections.exec, "authored exec", "the authored exec summary is visible (island wins the key)");
  eq(a.TR.report.data().sections.background, "authored bg", "the authored background is visible");
  eq(a.TR.report.data().sections.extra, "reader extra", "an un-owning local key the island lacks fills the gap");
  eq(a.TR.report.data().slides.length, 1, "the island's added slide is visible");
  eq(a.store.size, 1, "loading alone claims no ownership (nothing rewritten)");
});

run("report sections: owning local state wins outright (reader edits durable)", () => {
  const island = { report: { sections: { background: "authored bg", exec: "authored exec" },
    about: {}, slides: [] } };
  const owned = new Map([["turas_v2_report:proj", JSON.stringify(
    { _owns: true, sections: { exec: "reader owns" }, about: {}, slides: [] })]]);
  const a = boot(["32_report.js"], island, owned);
  eq(a.TR.report.data().sections.exec, "reader owns", "owning exec text wins");
  eq(a.TR.report.data().sections.background, undefined, "an owned deletion stays deleted (island ignored)");
});

run("saved banners: the island's banner survives stale un-owning local state", () => {
  const island = { banners: [{ code: "Q2", mode: "box", name: "Authored" }] };
  const stale = new Map([["turas_v2_banners:proj", JSON.stringify(
    [{ code: "Q9", mode: "net", name: "Mine" }])]]);
  const a = boot(["28b_banners.js"], island, stale);
  eq(a.TR.savedBanners.all().length, 2, "island + stale banner merge additively by id");
  eq(a.TR.savedBanners.has("custom:Q2:box"), true, "the island's authored banner is visible");
  eq(a.TR.savedBanners.has("custom:Q9:net"), true, "the reader's old banner is kept too");
  // A reader change takes ownership; a later removal of the island banner is durable.
  a.TR.savedBanners.remove("custom:Q2:box");
  eq(parse(a.store, "turas_v2_banners")._owns, true, "remove marks ownership");
  const b = boot(["28b_banners.js"], island, a.store);            // reload
  eq(b.TR.savedBanners.has("custom:Q2:box"), false, "the removed island banner STAYS removed");
  eq(b.TR.savedBanners.all().length, 1, "only the reader's banner remains");
});

run("composites: the island's composite survives stale un-owning local state", () => {
  const cols = [{ code: "Q1", label: "X", rows: [0] }];
  const island = { composites: [{ id: "composite:2", name: "Authored", columns: cols }] };
  const stale = new Map([["turas_v2_composites:proj", JSON.stringify(
    [{ id: "composite:1", name: "Mine", columns: cols }])]]);
  const a = boot(["28c_composite.js"], island, stale);
  eq(a.TR.compositeBanners.all().length, 2, "island + stale composite merge additively by id");
  assert(a.TR.compositeBanners.get("composite:2"), "the island's composite is visible (story pins resolve)");
  assert(a.TR.compositeBanners.get("composite:1"), "the reader's old composite is kept too");
  // Owning empty state (the reader deleted everything) beats the island.
  const owned = new Map([["turas_v2_composites:proj", JSON.stringify({ _owns: true, items: [] })]]);
  const c = boot(["28c_composite.js"], island, owned);
  eq(c.TR.compositeBanners.all().length, 0, "an owned deletion of every composite stays deleted");
  // And a reader change takes ownership going forward.
  const d = boot(["28c_composite.js"], island, new Map());
  d.TR.compositeBanners.remove("composite:2");
  eq(parse(d.store, "turas_v2_composites")._owns, true, "remove marks ownership");
  const e = boot(["28c_composite.js"], island, d.store);          // reload
  eq(e.TR.compositeBanners.get("composite:2"), null, "the removed composite STAYS removed");
});

run("legacy un-owning map state still merges over the island (back-compat)", () => {
  const island = { qualSaved: { "Q1#0": 1 } };
  const legacy = new Map([["turas_v2_qualsaved:proj", JSON.stringify({ "Q5#1": 1 })]]);
  const a = boot(["27q_qualitative.js"], island, legacy);
  eq(a.TR.qual.isSaved("Q1", 0), true, "island mark visible");
  eq(a.TR.qual.isSaved("Q5", 1), true, "legacy local mark visible");
  eq(a.store.get("turas_v2_qualsaved:proj"), JSON.stringify({ "Q5#1": 1 }),
    "loading rewrites nothing — legacy state stays un-owning until the reader changes something");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
