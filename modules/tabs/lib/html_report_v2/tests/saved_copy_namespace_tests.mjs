#!/usr/bin/env node
/**
 * Gate: four saved copies of ONE report keep four independent sets of pins.
 *
 * localStorage is shared across every page on a browser origin, and for
 * file:// reports that is every report file on the machine. The store key was
 * scoped to project name + wave, which keeps two DIFFERENT surveys apart but
 * not two copies of the SAME one: an analyst who saves four differently-pinned
 * copies of the CCPB report and opens them side by side got one shared story,
 * because merely rendering the Story tab persists the current list and a stored
 * list beats the copy's own baked-in island (30_story.js load()).
 *
 * report.saveCopy now mints a copyId per save and d2.storeKey appends it. This
 * asserts the whole chain: distinct keys per copy, each copy loading its OWN
 * pins, no bleed when one is opened after another, and originals plus copies
 * saved before this shipped keeping the old project-level key.
 *
 * Each copy opens in a fresh vm context ("a page load") over ONE shared in-memory
 * localStorage, exactly like four report files on one browser origin. Sits beside
 * state_tests.mjs, which gates the island/ownership half of the same design.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/saved_copy_namespace_tests.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS = path.join(HERE, "..", "assets", "js");

/** One localStorage shared by every "file" in the run. Exactly the trap. */
const STORE = new Map();
const localStorage = {
  getItem: (k) => (STORE.has(k) ? STORE.get(k) : null),
  setItem: (k, v) => { STORE.set(k, String(v)); },
};

function makeTarget() {
  const listeners = {};
  return {
    addEventListener(type, fn) { (listeners[type] = listeners[type] || []).push(fn); },
    removeEventListener() {},
  };
}

/** A fresh sandbox = a fresh page load of one report file. */
function openReport(userState) {
  const sandbox = Object.assign(makeTarget(), {
    console, TextEncoder, URL, localStorage,
    document: undefined,          // headless: story2 persist() returns before any DOM
  });
  sandbox.window = sandbox;
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  for (const f of readdirSync(JS).filter((x) => x.endsWith(".js")).sort()) {
    vm.runInContext(readFileSync(path.join(JS, f), "utf8"), sandbox, { filename: f });
  }
  const TR = sandbox.TR;
  // What shell.boot() installs from the islands, minus everything this gate
  // does not touch.
  TR.AGG = { project: { name: "CCPB 2026 Main Study", wave: "W2026" } };
  TR.userState = userState;
  TR._gateWindow = sandbox;   // so the saveCopy case below can give it a DOM
  return TR;
}

let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log("  ✓ " + m); } else { fail++; console.log("  ✗ " + m); } };

const pin = (code) => ({ kind: "question", q: code, banner: "b1", flags: {} });
const codes = (items) => items.map((i) => i.q).join(",");

// ---- the original report: no copyId, so the key is unchanged ----------------
const orig = openReport(null);
const ORIG_KEY = "turas_v2_story:CCPB_2026_Main_Study_W2026";
ok(orig.d2.storeKey("turas_v2_story") === ORIG_KEY,
  "an original report keeps the project+wave key");

// A copy saved before this shipped carries state but no id, also unchanged.
const legacy = openReport({ saved: true, story: [pin("Q1")] });
ok(legacy.d2.storeKey("turas_v2_story") === ORIG_KEY,
  "a copy saved before copyId shipped keeps that key too, so nothing already annotated moves");

// ---- four copies saved out of one report ------------------------------------
// saveCopy mints the id; it needs a DOM, so mint through the same expression it
// uses and assert the ids differ, then feed them in as four saved files.
const four = ["A", "B", "C", "D"].map((label, i) => ({
  label,
  state: { saved: true, copyId: "cp" + i + "x", story: [pin("Q" + label)] },
}));

const keys = four.map((c) => openReport(c.state).d2.storeKey("turas_v2_story"));
ok(new Set(keys).size === 4, "four saved copies produce four distinct store keys");
ok(keys.every((k) => k.indexOf(ORIG_KEY + ":") === 0),
  "each key extends the project+wave key rather than replacing it");

// ---- open them one after another, in the same browser -----------------------
// Every open renders its Story tab (the passive persist) before the next opens.
// Under the old shared key the SECOND open showed the FIRST copy's pins.
const seen = [];
for (const c of four) {
  const TR = openReport(c.state);
  seen.push(codes(TR.story2.items()));
  // renderTab ends with a passive persist; reproduce it without a DOM. This is
  // the write that used to poison the next copy.
  localStorage.setItem(TR.d2.storeKey("turas_v2_story"),
    JSON.stringify(TR.story2.items()));
}
ok(seen.join(" | ") === "QA | QB | QC | QD",
  "each copy loads its OWN pins, in a browser where the others were already opened");

// Re-open the first one last: it must still be its own story, not D's.
const reopened = openReport(four[0].state);
ok(codes(reopened.story2.items()) === "QA",
  "re-opening the first copy after the others still shows its own pins");

// ---- and the shared store really was shared ---------------------------------
ok(STORE.size === 4, "the four copies wrote four separate entries into one localStorage");

// ---- run the real report.saveCopy, twice ------------------------------------
// Everything above feeds saveCopy's OUTPUT back in. This drives saveCopy itself,
// through the smallest DOM that lets it clone a page and fill the island, and
// reads the id out of the JSON it actually wrote.
function saveCopyIsland(TR) {
  const island = { textContent: "" };
  const clone = {
    querySelector: (sel) => (sel === "#user-state" ? island
      : sel === "#app" ? { innerHTML: "x" } : null),
    outerHTML: "<html></html>",
  };
  const link = { href: "", download: "", click() {} };
  const sandbox = TR._gateWindow;
  sandbox.document = {
    documentElement: { cloneNode: () => clone },
    createElement: () => link,
    body: { appendChild() {}, removeChild() {} },
  };
  sandbox.Blob = function () {};
  sandbox.URL = { createObjectURL: () => "blob:x", revokeObjectURL() {} };
  TR.shell = TR.shell || {};
  TR.shell.toast = function () {};
  TR.report.saveCopy();
  return JSON.parse(island.textContent.replace(/\\u003c/g, "<"));
}

const donor = openReport(null);            // the ORIGINAL report saves a copy
const savedA = saveCopyIsland(donor);
const savedB = saveCopyIsland(donor);      // ...and a second, from the same page
ok(typeof savedA.copyId === "string" && savedA.copyId.length > 0,
  "report.saveCopy writes a copyId into the copy's user-state island");
ok(savedA.copyId !== savedB.copyId,
  "two copies saved from the SAME report get different ids, which is the whole point");
ok(donor.d2.storeKey("turas_v2_story") === ORIG_KEY,
  "saving a copy does not move the workspace of the report you saved it from");
ok(openReport(savedA).d2.storeKey("turas_v2_story") !== openReport(savedB).d2.storeKey("turas_v2_story"),
  "opening those two copies gives two different store keys");


/* ---- what the copy actually contains ---------------------------------------
 * saveCopy clones the whole document, so a copy of a report that carries the
 * per-respondent island carries it too. That is right for a copy and wrong to
 * leave unsaid: the button exists to make the file portable, and the analyst
 * clicking it is usually about to email it on. The old toast read "Single file,
 * send it to anyone", which was the last thing they saw.
 * -------------------------------------------------------------------------- */

/** Drive saveCopy with a stubbed confirm/toast and report what each one saw. */
function saveCopyWith(TR, micro, confirmAnswer) {
  const island = { textContent: "" };
  const clone = {
    querySelector: (sel) => (sel === "#user-state" ? island
      : sel === "#app" ? { innerHTML: "x" } : null),
    outerHTML: "<html></html>",
  };
  const link = { href: "", download: "", click() {} };
  const sandbox = TR._gateWindow;
  sandbox.document = {
    documentElement: { cloneNode: () => clone },
    createElement: () => link,
    body: { appendChild() {}, removeChild() {} },
  };
  sandbox.Blob = function () {};
  sandbox.URL = { createObjectURL: () => "blob:x", revokeObjectURL() {} };
  let asked = null, toast = null;
  sandbox.confirm = function (msg) { asked = msg; return confirmAnswer; };
  TR.shell = TR.shell || {};
  TR.shell.toast = function (m) { toast = m; };
  const before = TR.MICRO;
  TR.MICRO = micro;
  TR.report.saveCopy();
  TR.MICRO = before;
  return { asked, toast, wrote: island.textContent };
}

const MICRO = { n: 600, answers: { Q1: [0] }, weights: [1] };

const carrying = saveCopyWith(donor, MICRO, true);
ok(carrying.asked !== null, "a copy carrying respondent records asks before it writes");
ok(/600 records/.test(carrying.asked || ""),
  "…and the question names how many records are in it");
ok(/rebuild a respondent-by-question dataset/.test(carrying.asked || ""),
  "…and says plainly what someone can do with the file, not just that data is present");
ok(/no names, IDs or raw text/.test(carrying.asked || ""),
  "…while still stating the real mitigation, so the warning is accurate both ways");
ok(carrying.wrote.length > 0, "…and saying yes still writes the copy");
ok(/respondent-level data/.test(carrying.toast || ""),
  "…and the toast no longer invites the analyst to send it to anyone");

const declined = saveCopyWith(donor, MICRO, false);
ok(declined.wrote === "", "saying no writes nothing at all");
ok(/cancelled/i.test(declined.toast || ""), "…and says so");

const clean = saveCopyWith(donor, null, false);
ok(clean.asked === null,
  "a confidentiality ship (no island) saves straight through, unchanged");
ok(clean.wrote.length > 0 && /no respondent data/.test(clean.toast || ""),
  "…and its toast can honestly promise a portable file");

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
