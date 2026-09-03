#!/usr/bin/env node
/**
 * Shell snapshot export gate. shell.snapshotLines() turns a pinned card into the
 * plain-text lines the PPTX/PNG deck renders (that path can't rasterise arbitrary
 * HTML). It harvested headings and prose but NOT table cells, so a theme×banner
 * crosstab pinned to the Story exported with its title and none of its numbers
 * (I1). This checks the numbers now survive, row by row.
 *
 * Also gates shell.autoGrowNotes. The analyst note boxes (crosstab Insight,
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

console.log("Shell snapshot export. Suite:");

run("snapshotLines harvests table rows with their numbers (I1)", () => {
  const card = fakeCard(
    ["Theme crosstab. Course", "Salience by course"],
    [["Theme", "Total", "Diploma"], ["Financial", "45%", "50%"], ["Educators", "62%", "70%"]]
  );
  const lines = TR.shell.snapshotLines(card);
  assert(lines.indexOf("Theme crosstab. Course") !== -1, "title still harvested");
  assert(lines.indexOf("Financial · 45% · 50%") !== -1, "data row + numbers harvested");
  assert(lines.indexOf("Educators · 62% · 70%") !== -1, "second data row harvested");
  assert(lines.indexOf("Theme · Total · Diploma") !== -1, "header row harvested");
});

run("empty cells are dropped, no orphan separators", () => {
  const card = fakeCard(["Title"], [["Row", "", "10%"]]);
  const lines = TR.shell.snapshotLines(card);
  assert(lines.indexOf("Row · 10%") !== -1, "blank middle cell dropped: " + JSON.stringify(lines));
});

/* ---------------- analyst notes in a snapshot ---------------- */
/*
 * A tiny DOM, modelling the cloning rule snapshotCard depends on: a cloned
 * textarea DOES carry the analyst's typed value, not the markup default. The
 * HTML spec has textarea's cloning steps propagate the API value and the dirty
 * flag, and Chrome was checked directly. That is what lets a pin freeze a note
 * typed since the last render, which matters because the qual insight boxes
 * persist on input WITHOUT re-rendering.
 */
let uid = 0;
function node(tag, opts) {
  opts = opts || {};
  const n = { tag: tag, id: ++uid, kids: [], parent: null,
    textContent: opts.text || "", contentEditable: opts.contentEditable };
  let cls = String(opts.cls || "").split(" ").filter(Boolean);
  Object.defineProperty(n, "className", {
    get: () => cls.join(" "),
    set: (v) => { cls = String(v).split(" ").filter(Boolean); }
  });
  if (tag === "textarea") {
    n.defaultValue = opts.text || "";
    n.value = ("value" in opts) ? opts.value : n.defaultValue;
  }
  n.matches = (sel) => String(sel).split(",").map((x) => x.trim()).some((x) =>
    x === n.tag || (x === "[contenteditable]" && n.contentEditable != null) ||
    (x.charAt(0) === "." && cls.indexOf(x.slice(1)) !== -1));
  n.closest = (sel) => { let c = n; while (c) { if (c.matches(sel)) return c; c = c.parent; } return null; };
  n.querySelectorAll = (sel) => {
    const out = [];
    (function walk(x) { x.kids.forEach((k) => { if (k.matches(sel)) out.push(k); walk(k); }); })(n);
    return out;
  };
  n.append = (k) => { k.parent = n; n.kids.push(k); return n; };
  n.remove = () => {
    if (!n.parent) return;
    n.parent.kids = n.parent.kids.filter((k) => k !== n);
    n.parent = null;
  };
  n.replaceWith = (other) => {
    if (!n.parent) return;
    other.parent = n.parent;
    n.parent.kids.splice(n.parent.kids.indexOf(n), 1, other);
    n.parent = null;
  };
  n.removeAttribute = () => {};
  n.cloneNode = () => {
    const c = node(n.tag, { cls: n.className, text: n.textContent,
      contentEditable: n.contentEditable,
      // per spec: the typed value travels with the clone; the raw text content
      // stays the markup default
      value: n.tag === "textarea" ? n.value : undefined });
    n.kids.forEach((k) => c.append(k.cloneNode(true)));
    return c;
  };
  Object.defineProperty(n, "outerHTML", { get: () =>
    "<" + n.tag + (n.className ? ' class="' + n.className + '"' : "") + ">" +
    n.textContent + n.kids.map((k) => k.outerHTML).join("") + "</" + n.tag + ">" });
  (opts.kids || []).forEach((k) => n.append(k));
  return n;
}
sandbox.document = { createElement: (t) => node(t) };

// An insight box as the qual tab renders it: seeded text in the markup, the
// analyst's newer text typed over it since the last render.
const noteBox = (seeded, typed) => node("div", { cls: "insight", kids: [
  node("textarea", { text: seeded, value: typed }) ] });

run("snapshotCard freezes the note the analyst TYPED, not the markup default", () => {
  const card = node("section", { kids: [
    node("h2", { text: "Placing orders" }),
    noteBox("Seeded from the config.", "Delivery reliability is the story.")
  ] });
  const html = TR.shell.snapshotCard(card);
  assert(html.indexOf("Delivery reliability is the story.") !== -1,
    "typed note frozen into the snapshot: " + html);
  assert(html.indexOf("Seeded from the config.") === -1,
    "the stale default did not survive: " + html);
  assert(html.indexOf("snap-frozen-note") !== -1, "frozen as inert text, not a textarea");
});

run("the pin control and anything inside it leave the snapshot", () => {
  const card = node("section", { kids: [
    node("span", { cls: "snap-pin", kids: [ node("textarea", { text: "pin-default", value: "pin-typed" }) ] }),
    noteBox("old", "the real note")
  ] });
  const html = TR.shell.snapshotCard(card);
  assert(html.indexOf("the real note") !== -1, "the real note froze correctly: " + html);
  assert(html.indexOf("pin-typed") === -1 && html.indexOf("pin-default") === -1,
    "the pin control and its contents left the snapshot: " + html);
});

run("snapshotLines carries the analyst note into the deck (it never did)", () => {
  const card = node("section", { kids: [
    node("h2", { text: "Placing orders" }),
    noteBox("", "Delivery reliability is the story.")
  ] });
  const lines = TR.shell.snapshotLines(card);
  assert(lines.indexOf("Delivery reliability is the story.") !== -1,
    "note harvested for the PPTX path: " + JSON.stringify(lines));
  assert(lines.indexOf("Placing orders") < lines.indexOf("Delivery reliability is the story."),
    "the title still leads, the note follows it");
});

run("snapshotLines also reads a note already frozen upstream", () => {
  const card = node("section", { kids: [
    node("div", { cls: "snap-frozen-note", text: "Frozen earlier." }) ] });
  assert(TR.shell.snapshotLines(card).indexOf("Frozen earlier.") !== -1,
    "a re-harvested snapshot keeps its note");
});

run("a note inside the pin control is never harvested", () => {
  const card = node("section", { kids: [
    node("span", { cls: "snap-pin", kids: [ node("textarea", { text: "", value: "control chatter" }) ] }) ] });
  assert(TR.shell.snapshotLines(card).indexOf("control chatter") === -1,
    "pin-control text stays out of the deck");
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

run("one selector, matching the CSS rule. Both the insight box and the pin note", () => {
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

run("typing keeps the box in step. One delegated input listener", () => {
  assert(SHELL_SRC.indexOf('document.addEventListener("input"') !== -1,
    "delegated input listener wired in the shell");
  assert(SHELL_SRC.indexOf("e.target.matches(NOTE_SEL)") !== -1,
    "it grows exactly the note boxes");
});

run("show_save_copy: the header carries the button unless the study says otherwise", () => {
  const SRC = readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8");
  assert(SRC.indexOf("save_copy === false") !== -1,
    "the header gates the button on project.tabs.save_copy");
  assert(SRC.indexOf('data-savecopy title=') !== -1, "the button itself is still built");
  // Only an explicit false hides it: absent, null and true all keep the button,
  // so every report built before the setting existed is unchanged.
  const gate = (flags) => (flags || {}).save_copy === false;
  assert(gate(undefined) === false, "no tabs block keeps the button");
  assert(gate({}) === false, "no flag keeps the button");
  assert(gate({ save_copy: true }) === false, "true keeps the button");
  assert(gate({ save_copy: null }) === false, "null keeps the button");
  assert(gate({ save_copy: false }) === true, "only an explicit false hides it");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
