#!/usr/bin/env node
/**
 * Verification gate for the fable prototype. Runs:
 *  1. the shared known-answer suite (same cases as the in-browser #selftest)
 *  2. node-only tests: demo data validation, deck -> pptx -> python
 *     structural validation, build artifact checks, source structure check
 * Exit 0 = everything passed. No dependencies beyond node + python3.
 */
import { readFileSync, readdirSync, writeFileSync, existsSync, statSync, mkdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const BASE = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const JS_DIR = path.join(BASE, "src", "js");
const MAX_ACTIVE_LINES = 300;

/* ---- load the renderer modules into a sandbox ---- */
const sandbox = { console, TextEncoder, URL };
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
for (const file of readdirSync(JS_DIR).filter((f) => f.endsWith(".js")).sort()) {
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox,
    { filename: file });
}
const TR = sandbox.TR;

let passed = 0;
let failed = 0;
function run(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e) {
    failed++;
    console.log(`  ✗ ${name}\n    ${e.message}`);
  }
}
function assert(condition, message) {
  if (!condition) throw new Error(message);
}

/* ---- 1. shared known-answer suite ---- */
console.log("Shared known-answer suite (same cases as in-browser #selftest):");
for (const testCase of TR.selftest.cases()) {
  run(testCase.name, testCase.fn);
}

/* ---- 2. node-only tests ---- */
console.log("Node-only suite:");

const demo = JSON.parse(
  readFileSync(path.join(BASE, "data", "demo_data.json"), "utf8"));

run("demo_data.json passes validation", () => {
  const res = TR.data.validate(demo);
  assert(res.ok, "errors: " + JSON.stringify(res.errors));
});

run("demo table matrix known answers", () => {
  const q1 = TR.data.questionById(demo, "q1");
  const matrix = TR.tables.matrix(q1, demo);
  assert(matrix.head.length === 5, "head should be label + 4 banner columns");
  assert(matrix.head[1] === "Total (T)", "first banner head, got " + matrix.head[1]);
  assert(matrix.body[0].kind === "base", "first body row is the base row");
  assert(matrix.body[0].cells[1] === "500", "base Total = 500");
  // Meridian 18-34 = 41% with sig letter C appended
  assert(matrix.body[1].cells[2] === "41% C",
    "Meridian 18–34 cell, got " + matrix.body[1].cells[2]);
});

run("scale question renders mean + waves", () => {
  const q3 = TR.data.questionById(demo, "q3");
  const stacked = TR.charts.stackedScale(q3, demo);
  assert(stacked.includes("3.7"), "mean label in stacked chart");
  const trend = TR.charts.trend(q3, demo, 0);
  assert(trend.includes("polyline"), "trend has polylines");
});

run("clipboard html escapes + carries sig letters", () => {
  const q1 = TR.data.questionById(demo, "q1");
  const html = TR.tables.clipboardHtml(q1, demo);
  assert(html.includes("41% C"), "sig letter in clipboard cell");
  assert(!html.includes("<script"), "no script tags");
});

run("composer end-to-end on demo data (q3 + q7 trends)", () => {
  const res = TR.composer.compose(demo, ["q3", "q7"], 0);
  assert(res.ok, JSON.stringify(res.errors));
  assert(res.model.trends.length === 2, "two trend strips");
  assert(res.model.waveLabels.length === 3, "three waves");
  const svg = TR.composer.renderSvg(res.model, demo);
  assert(svg.startsWith("<svg"), "renders svg");
  assert(svg.includes("Shared axis"), "shared axis note");
});

run("deck builds a multi-slide native pptx; python validates structure", () => {
  const slides = [TR.pptxSlides.titleSlide(demo, 3)];
  slides.push(...TR.pptxSlides.questionSlides(
    TR.data.questionById(demo, "q1"), demo, 0));
  slides.push(...TR.pptxSlides.questionSlides(
    TR.data.questionById(demo, "q3"), demo, 0));
  const compose = TR.composer.compose(demo, ["q3", "q7"], 0);
  slides.push(TR.pptxSlides.compositeSlide(compose.model, demo));
  const bytes = TR.pptx.package(slides, demo);
  const tmpDir = path.join(BASE, "tests", "tmp");
  mkdirSync(tmpDir, { recursive: true });
  const out = path.join(tmpDir, "test_deck.pptx");
  writeFileSync(out, bytes);
  const report = execFileSync("python3",
    [path.join(BASE, "tests", "verify_pptx.py"), out], { encoding: "utf8" });
  assert(report.startsWith("OK"), report);
});

run("pptx slide xml contains editable shapes (not images)", () => {
  const slides = TR.pptxSlides.questionSlides(
    TR.data.questionById(demo, "q1"), demo, 0);
  assert(slides[0].includes("<a:tbl>"), "native table present");
  assert(slides[0].includes("<p:sp>"), "shapes present");
  assert(!slides[0].includes("blip"), "no embedded images");
});

run("built artifacts exist, are self-contained, within size targets", () => {
  const demoOut = path.join(BASE, "turas_report.html");
  const scaleOut = path.join(BASE, "turas_report_scale.html");
  assert(existsSync(demoOut), "turas_report.html missing — run: Rscript build.R");
  const html = readFileSync(demoOut, "utf8");
  assert(html.includes('id="turas-data"'), "data island present");
  assert(!/(src|href)="https?:\/\//.test(html), "no external fetches");
  assert(statSync(demoOut).size < 250 * 1024,
    "demo report should be < 250 KB, is " + statSync(demoOut).size);
  if (existsSync(scaleOut)) {
    const scaleSize = statSync(scaleOut).size;
    assert(scaleSize < 3 * 1024 * 1024,
      "scale report should be < 3 MB (spec stretch target), is " + scaleSize);
    const scaleHtml = readFileSync(scaleOut, "utf8");
    assert(!/(src|href)="https?:\/\//.test(scaleHtml), "scale: no external fetches");
  }
});

run("structure check: no source file exceeds 300 active lines", () => {
  const offenders = [];
  for (const file of readdirSync(JS_DIR).filter((f) => f.endsWith(".js"))) {
    const text = readFileSync(path.join(JS_DIR, file), "utf8");
    if (/SIZE-EXCEPTION/.test(text)) continue;
    const active = text.split("\n").filter((line) => {
      const t = line.trim();
      return t !== "" && !t.startsWith("//") && !t.startsWith("/*") &&
        !t.startsWith("*") && !/^[})\];]*$/.test(t);
    }).length;
    if (active > MAX_ACTIVE_LINES) offenders.push(`${file}: ${active}`);
  }
  assert(offenders.length === 0, "over limit: " + offenders.join(", "));
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
