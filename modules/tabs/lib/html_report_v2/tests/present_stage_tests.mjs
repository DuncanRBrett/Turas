#!/usr/bin/env node
/**
 * The Present stage (boardroom and Teams). Every slide is laid out on one
 * fixed 16:9 stage (1280 x 720 logical pixels) and the stage is scaled to the
 * window it is in, so a slide looks the same on a projector, a shared Teams
 * window or a laptop. Contracts:
 *
 * P1 The fit: full scale is the window over the stage; a taller slide shrinks
 *    to fit, never below 55% of full nor below 0.9, and never past the
 *    window's own width; below the floor the slide scrolls.
 * P2 The markup: sizer > stage > progress + slide; the counter, full screen,
 *    exit and key hint are the fading controls; a divider is centred.
 * P3 The fit is applied to the stage and re-applied on resize, from a
 *    listener installed when Present opens and removed when it closes.
 * P4 The controls fade after the idle time and return when the mouse moves.
 * P5 Full screen is a button, only where the browser offers it; it toggles.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/present_stage_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";
import { TXT, installText } from "./_text.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const load = (sandbox, file) =>
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(actual, expected, msg) {
  const a = JSON.stringify(actual), e = JSON.stringify(expected);
  if (a !== e) throw new Error(msg + ": expected " + e + ", got " + a);
}
function at(hay, needle, msg) {
  if (String(hay).indexOf(needle) === -1) {
    throw new Error(msg + ": missing " + JSON.stringify(needle));
  }
}
const near = (a, b, msg) => assert(Math.abs(a - b) < 1e-6, msg + ": expected " + b + ", got " + a);

/* ---------------- fake DOM: an overlay that measures ------------------------ */

function classList() {
  const set = new Set();
  return {
    add: (...c) => c.forEach((x) => set.add(x)),
    remove: (...c) => c.forEach((x) => set.delete(x)),
    toggle: (c, on) => { if (on) set.add(c); else set.delete(c); },
    contains: (c) => set.has(c),
    set
  };
}

/** The overlay with a window of vw x vh and a slide contentH tall. The slide's
 *  height reads as its own only while the stage is being measured; otherwise
 *  it is at least the stage's 720, as the CSS min-height makes it. */
function overlay(vw, vh, contentH) {
  const listeners = {};
  const stage = { style: {}, classList: classList() };
  const sizer = { style: {} };
  const deck = {};
  Object.defineProperty(deck, "offsetHeight", {
    get: () => (stage.classList.contains("pr-measuring") ? o.contentH : Math.max(720, o.contentH))
  });
  const o = {
    hidden: true, innerHTML: "", clientWidth: vw, clientHeight: vh, contentH,
    classList: classList(), listeners, stage, sizer,
    addEventListener(type, fn) { (listeners[type] = listeners[type] || []).push(fn); },
    querySelector(sel) {
      if (sel === ".pr-sizer") return sizer;
      if (sel === ".pr-stage") return stage;
      if (sel === ".present") return deck;
      if (sel === "#pr-close") return { addEventListener: () => {} };
      return null;
    }
  };
  return o;
}

function sandbox(opts) {
  opts = opts || {};
  const ov = overlay(opts.vw || 1920, opts.vh || 1080, opts.contentH || 500);
  const winListeners = {};
  const docListeners = {};
  const timers = [];
  const fs = { requested: 0, exited: 0 };
  const root = opts.fullscreen === false ? {} : {
    requestFullscreen: () => { fs.requested++; return Promise.resolve(); }
  };
  const sb = { console, TextEncoder, atob,
    localStorage: { getItem: () => null, setItem: () => {}, removeItem: () => {} },
    addEventListener: (t, fn) => { (winListeners[t] = winListeners[t] || []).push(fn); },
    removeEventListener: (t, fn) => {
      winListeners[t] = (winListeners[t] || []).filter((f) => f !== fn);
    },
    setTimeout: (fn, ms) => { timers.push({ fn, ms, live: true }); return timers.length; },
    clearTimeout: (id) => { if (timers[id - 1]) timers[id - 1].live = false; },
    document: {
      documentElement: root,
      fullscreenElement: null,
      exitFullscreen: () => { fs.exited++; return Promise.resolve(); },
      getElementById: (id) => (id === "present-overlay" ? ov : null),
      addEventListener: (t, fn) => { (docListeners[t] = docListeners[t] || []).push(fn); },
      removeEventListener: (t, fn) => {
        docListeners[t] = (docListeners[t] || []).filter((f) => f !== fn);
      }
    } };
  sb.globalThis = sb;
  sb.window = sb;
  vm.createContext(sb);
  for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "21_stats.js",
    "23_render.js", "23z_charts.js", "23za_trend.js"]) load(sb, f);
  installText(sb);
  const TR = sb.TR;
  TR.AGG = { project: { name: "CCPB 2026" }, questions: [], banner_groups: [] };
  TR.userState = { story: opts.story || [
    { kind: "divider", title: "Satisfaction", note: "How members rate us" },
    { kind: "divider", title: "Next", note: "" }] };
  TR.d2 = { storeKey: (b) => b + ":p", state: { tab: "story", filters: [] },
    questionByCode: () => null, tracking: () => ({ enabled: false }) };
  TR.shell = { toast: () => {} };
  TR.insights = { get: () => "" };
  TR.model = { forQuestion: () => null };
  TR.exporter = {};
  load(sb, "30_story.js");
  return { sb, TR, ov, winListeners, docListeners, timers, fs };
}

const click = (w, sel) => (w.ov.listeners.click || []).forEach((fn) => fn({
  target: { closest: (s) => (s === sel ? {} : null) } }));

console.log("Present stage (a 16:9 stage scaled to any window): suite:");

/* ---------------- P1: the fit ----------------------------------------------- */

run("P1: a slide that fits is shown at the window's full scale", () => {
  const fit = (vw, vh, h) => sandbox({}).TR.story2._presentFit(vw, vh, h);
  eq(fit(1920, 1080, 500), { scale: 1.5, height: 720, scrolls: false }, "1080p projector");
  eq(fit(1280, 720, 500), { scale: 1, height: 720, scrolls: false }, "a 720p Teams share");
  near(fit(1440, 900, 500).scale, 1.125, "a laptop window: width decides");
  near(fit(2560, 1080, 500).scale, 1.5, "a wide screen: height decides");
});

run("P1: a taller slide shrinks to fit; past the floor it scrolls", () => {
  const f = sandbox({}).TR.story2._presentFit;
  const tall = f(1920, 1080, 950);
  near(tall.scale, 1080 / 950, "fits exactly");
  eq([tall.height, tall.scrolls], [950, false], "no scroll");
  const huge = f(1920, 1080, 1469);
  near(huge.scale, 0.9, "the 0.9 floor, above 55% of 1.5");
  assert(huge.scrolls, "and it scrolls");
  const teams = f(1280, 720, 950);
  near(teams.scale, 0.9, "on 720p a long table keeps readable text");
  assert(teams.scrolls, "and scrolls a little");
  const small = f(800, 450, 2000);
  near(small.scale, 0.625, "the floor never widens the stage past a small window");
});

/* ---------------- P2: the markup -------------------------------------------- */

run("P2: sizer > stage > progress + slide; the controls are marked to fade", () => {
  const w = sandbox({});
  w.TR.story2.presentFrom(0);
  const h = w.ov.innerHTML;
  const order = ['<div class="pr-sizer">', '<div class="pr-stage">',
    '<div class="pr-progress"><span style="width:50.00%"></span></div>',
    '<div class="present pr-is-divider">', '<div class="pr-head pr-chrome">',
    '<div class="pr-body">', '<div class="pr-divider"><h1>Satisfaction</h1>',
    '<div class="pr-foot pr-chrome">'];
  let from = 0;
  order.forEach((s) => {
    const i = h.indexOf(s, from);
    assert(i >= from, "in order: " + s);
    from = i;
  });
  w.TR.story2.presentFrom(1);
  at(w.ov.innerHTML, 'style="width:100.00%"', "the last slide fills the progress line");
});

/* ---------------- P3: fitted, and refitted on resize ------------------------ */

run("P3: the stage is scaled and the sizer takes its size on screen", () => {
  const w = sandbox({ vw: 1920, vh: 1080, contentH: 500 });
  w.TR.story2.presentFrom(0);
  const { stage, sizer } = w.ov;
  eq([stage.style.transform, stage.style.height], ["scale(1.5)", "720px"], "stage");
  eq([sizer.style.width, sizer.style.height, sizer.style.marginTop],
    ["1920px", "1080px", "0px"], "sizer");
  assert(!stage.classList.contains("pr-measuring"), "the measuring class is removed");
  assert(!w.ov.classList.contains("pr-scrolls"), "no scroll");
});

run("P3: a slide past the floor scrolls, centred when it does not", () => {
  const w = sandbox({ vw: 1920, vh: 1080, contentH: 1469 });
  w.TR.story2.presentFrom(0);
  eq([w.ov.stage.style.transform, w.ov.stage.style.height], ["scale(0.9)", "1469px"],
    "the slide's own height, at the floor");
  assert(w.ov.classList.contains("pr-scrolls"), "marked as scrolling");
  eq(w.ov.sizer.style.marginTop, "0px", "top-aligned when it scrolls");
  const c = sandbox({ vw: 1920, vh: 1200, contentH: 500 });
  c.TR.story2.presentFrom(0);
  eq(c.ov.sizer.style.marginTop, "60px", "a 16:10 window centres the stage");
});

run("P3: one resize listener while presenting, refitting; gone on close", () => {
  const w = sandbox({ vw: 1920, vh: 1080, contentH: 500 });
  w.TR.story2.presentFrom(0);
  eq((w.winListeners.resize || []).length, 1, "installed once");
  w.TR.story2.presentFrom(1);
  eq((w.winListeners.resize || []).length, 1, "not stacked by the next slide");
  w.ov.clientWidth = 1280; w.ov.clientHeight = 720;
  w.winListeners.resize[0]();
  eq(w.ov.stage.style.transform, "scale(1)", "the Teams window refits");
  const esc = (w.docListeners.keydown || []).slice();
  esc.forEach((fn) => fn({ key: "Escape", target: null }));
  eq((w.winListeners.resize || []).length, 0, "removed on close");
  assert(w.ov.hidden, "Present closed");
});

/* ---------------- P4: the controls fade ------------------------------------- */

run("P4: the controls fade after the idle time and return on mouse move", () => {
  const w = sandbox({});
  w.TR.story2.presentFrom(0);
  assert(!w.ov.classList.contains("pr-idle"), "visible on open");
  const live = () => w.timers.filter((t) => t.live);
  eq(live().length, 1, "one idle timer");
  assert(live()[0].ms >= 1500 && live()[0].ms <= 4000, "a couple of seconds");
  live()[0].fn();
  assert(w.ov.classList.contains("pr-idle"), "faded");
  (w.ov.listeners.mousemove || []).forEach((fn) => fn({}));
  assert(!w.ov.classList.contains("pr-idle"), "back on mouse move");
  eq(live().length, 1, "the old timer is cleared, a new one set");
  (w.docListeners.keydown || []).slice().forEach((fn) => fn({ key: "Escape", target: null }));
  eq(live().length, 0, "no timer outlives Present");
  assert(!w.ov.classList.contains("pr-idle"), "and the overlay is reset");
});

/* ---------------- P5: full screen ------------------------------------------- */

run("P5: full screen is a button where the browser offers it, and it toggles", () => {
  const w = sandbox({});
  w.TR.story2.presentFrom(0);
  at(w.ov.innerHTML, 'data-pr-fullscreen', "the button");
  at(w.ov.innerHTML, 'data-txt-key="story.present.fullscreen"', "its authored label");
  click(w, "[data-pr-fullscreen]");
  eq(w.fs.requested, 1, "asks the browser for full screen");
  w.sb.document.fullscreenElement = {};
  (w.docListeners.fullscreenchange || []).forEach((fn) => fn());
  at(w.ov.innerHTML, 'data-txt-key="story.present.exit_fullscreen"', "the label follows");
  click(w, "[data-pr-fullscreen]");
  eq(w.fs.exited, 1, "and leaves it");
  assert(TXT("story.present.fullscreen") && TXT("story.present.exit_fullscreen"),
    "both labels are in the registry");
});

run("P5: in full screen, the first Esc leaves full screen and the next closes Present", () => {
  const w = sandbox({});
  w.TR.story2.presentFrom(0);
  w.sb.document.fullscreenElement = {};
  const esc = () => (w.docListeners.keydown || []).slice()
    .forEach((fn) => fn({ key: "Escape", target: null }));
  esc();
  eq(w.fs.exited, 1, "full screen left");
  assert(!w.ov.hidden, "Present still open");
  w.sb.document.fullscreenElement = null;
  esc();
  assert(w.ov.hidden, "the next Esc closes Present");
});

run("P5: no full screen button where the browser has none", () => {
  const w = sandbox({ fullscreen: false });
  w.TR.story2.presentFrom(0);
  assert(w.ov.innerHTML.indexOf("data-pr-fullscreen") === -1, "no button");
  at(w.ov.innerHTML, 'id="pr-close"', "the exit stays");
});

console.log((failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
if (failed) process.exit(1);
