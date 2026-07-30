#!/usr/bin/env node
/**
 * Shell snapshot export gate. shell.snapshotLines() turns a pinned card into the
 * plain-text lines the PPTX/PNG deck renders (that path can't rasterise arbitrary
 * HTML). It harvested headings and prose but NOT table cells, so a theme×banner
 * crosstab pinned to the Story exported with its title and none of its numbers
 * (I1). This checks the numbers now survive, row by row.
 *
 * Also gates shell.autoGrowNotes — the analyst note boxes (crosstab Insight,
 * story-pin commentary, qual/visualise insights) open at their full height
 * instead of clipping a long note at three lines with nothing to say so.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/shell_snapshot_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console };
sandbox.globalThis = sandbox;                 // 24_shell.js IIFE binds to globalThis in node
sandbox.TR = { fmt: { escapeHtml: (s) => String(s == null ? "" : s) } };
vm.createContext(sandbox);
vm.runInContext(readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8"), sandbox, { filename: "24_shell.js" });
const TR = sandbox.TR;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }

// Minimal DOM stubs: only the methods snapshotLines calls.
const cell = (t) => ({ textContent: t });
const tr = (cells) => ({ closest: () => null, querySelectorAll: (s) => (s === "th,td" ? cells.map(cell) : []) });
const prose = (t) => ({ textContent: t, closest: () => null });
function fakeCard(proseTexts, rows) {
  return {
    querySelectorAll(sel) {
      if (sel === "table tr") return rows.map(tr);
      return proseTexts.map(prose);           // the headings/prose selector
    }
  };
}

console.log("Shell snapshot export — suite:");

run("snapshotLines harvests table rows with their numbers (I1)", () => {
  const card = fakeCard(
    ["Theme crosstab — Course", "Salience by course"],
    [["Theme", "Total", "Diploma"], ["Financial", "45%", "50%"], ["Educators", "62%", "70%"]]
  );
  const lines = TR.shell.snapshotLines(card);
  assert(lines.indexOf("Theme crosstab — Course") !== -1, "title still harvested");
  assert(lines.indexOf("Financial · 45% · 50%") !== -1, "data row + numbers harvested");
  assert(lines.indexOf("Educators · 62% · 70%") !== -1, "second data row harvested");
  assert(lines.indexOf("Theme · Total · Diploma") !== -1, "header row harvested");
});

run("empty cells are dropped, no orphan separators", () => {
  const card = fakeCard(["Title"], [["Row", "", "10%"]]);
  const lines = TR.shell.snapshotLines(card);
  assert(lines.indexOf("Row · 10%") !== -1, "blank middle cell dropped: " + JSON.stringify(lines));
});

/* ---------------- self-sizing note boxes ---------------- */

const SHELL_SRC = readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8");

// A textarea stub: scrollHeight is content+padding (border-box), as in a browser.
const fakeNote = (scrollHeight) => ({ scrollHeight: scrollHeight, style: {} });
function fakeRoot(notes) {
  const seen = [];
  return {
    seen,
    querySelectorAll(sel) { seen.push(sel); return notes; }
  };
}

run("autoGrowNotes sizes each note box to its content (+ the border-box border)", () => {
  const notes = [fakeNote(140), fakeNote(56)];
  TR.shell.autoGrowNotes(fakeRoot(notes));
  assert(notes[0].style.height === "142px", "tall note grew: " + notes[0].style.height);
  assert(notes[1].style.height === "58px", "short note sized too: " + notes[1].style.height);
});

run("one selector, matching the CSS rule — both the insight box and the pin note", () => {
  const root = fakeRoot([]);
  TR.shell.autoGrowNotes(root);
  assert(root.seen[0] === ".insight textarea, textarea.si-note",
    "selector was: " + root.seen[0]);
});

run("a note in a hidden tab measures 0 and is left alone, never collapsed", () => {
  const note = fakeNote(0);
  TR.shell.autoGrowNotes(fakeRoot([note]));
  assert(note.style.height === "auto", "left at auto, not 0px: " + note.style.height);
});

run("typing keeps the box in step — one delegated input listener", () => {
  assert(SHELL_SRC.indexOf('document.addEventListener("input"') !== -1,
    "delegated input listener wired in the shell");
  assert(SHELL_SRC.indexOf("e.target.matches(NOTE_SEL)") !== -1,
    "it grows exactly the note boxes");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
