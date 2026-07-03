#!/usr/bin/env node
/**
 * PPTX visual QA gate (PPTX_BOARDROOM_SPEC.md WP6) — the last line of
 * defence before a deck reaches a boardroom: the other suites assert slide
 * XML strings; this one builds a REAL fixture deck covering every slide
 * archetype, validates the .pptx package structurally (every zip part —
 * including the embedded chart workbooks — must be well-formed XML) and
 * renders it through LibreOffice so a human (or agent) can eyeball the PNGs
 * for layout defects no string assert can see.
 *
 * Deck fixture (7 slides):
 *   1. cover            — authored exec summary + leading findings
 *   2. section divider  — numbered 01
 *   3. insight + bar    — weighted fixture (footer shows weighted/effective
 *                         bases), sig ▲▼ markers, analyst-insight callout
 *   4. quote slide      — 4 quotes incl. one with dropped (below-k) tags
 *   5. trend exhibit    — wave-delta chip + CI note in the footer
 *   6. Detail divider   — numbered 02 (auto-inserted for matrix pins)
 *   7. matrix slide     — index heatmap table
 *
 * Rendering needs `soffice` (LibreOffice) on PATH and, for per-slide PNGs,
 * `pdftoppm` (poppler). Either being absent SKIPs the render checks with a
 * clear message — the structural gate still runs and CI stays green.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/pptx_visual_qa.mjs
 */
import { readFileSync, writeFileSync, mkdtempSync, existsSync, readdirSync, statSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { inflateRawSync } from "node:zlib";
import os from "node:os";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console, TextEncoder };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const file of ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js",
  "14_pptx_parts.js", "23_render.js", "23z_charts.js", "23za_trend.js",
  "23y_xlsx.js", "29_export.js", "30_story.js", "30x_exhibit.js"]) {
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });
}
const TR = sandbox.TR;

let passed = 0, failed = 0, skipped = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function skip(name, why) { skipped++; console.log("  ~ SKIPPED " + name + " — " + why); }
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) { if (a !== b) throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a)); }

/* ================= fixture deck — every archetype, weighted ================= */

function setupFixture() {
  TR.AGG = {
    project: { name: "Turas visual QA fixture", client: "CCS", wave: "Wave 12",
      brand_colour: "#123ABC", accent_colour: "#CC9900", weighted: true },
    questions: [], banner_groups: []
  };
  TR.d2 = { storeKey: (b) => b, bannerDescription: () => "All respondents",
    tracking: () => ({ enabled: false, waves: [] }),
    questionByCode: () => null, state: { filters: [] } };
  TR.insights = { get: () => "" };
  TR.shell = { toast: () => {} };
  TR.report = { sectionText: (s) => s === "exec"
    ? "Overall service holds up this wave: satisfaction is stable and the " +
      "branch channel keeps gaining share at the call centre's expense.\n" +
      "The risk sits with recent graduates — their verbatims say support is " +
      "too slow, and their KPI recovery is the most fragile."
    : "" };
  TR.conf = { methodNote: () => "Wilson 95%", modelIntervalKind: () => "props" };
  TR.views = {
    _indexQuestions: () => [],
    _heatMatrix: () => ({
      head: ["Metric", "Total", "18–24", "25–34", "35+"],
      rows: [
        ["Q10 — Overall Index", "7.4", "6.9", "7.5", "7.8"],
        ["Q11 — Value Index", "7.1", "6.6", "7.2", "7.4"],
        ["Q12 — Support Index", "6.2", "5.4", "6.3", "6.8"]
      ]
    })
  };
  // tracked wave history for the exhibit's trend chart + delta chip
  TR.trk = {
    yLabel: (y) => "Wave " + y,
    points: () => [
      { year: 8, value: 58 }, { year: 9, value: 52 }, { year: 10, value: 47 },
      { year: 11, value: 51 },
      { year: 12, value: 55, change_prev: 4, sig_prev: true, current: true }
    ]
  };
  // question models by code: Q4 = the weighted bar-chart pin, Q1 = the
  // exhibit's tracked KPI
  const MODELS = {
    Q4: () => ({
      code: "Q4", title: "Which channel did you use most often this wave?",
      category: "Service", source: "published",
      columns: [{ label: "Total", base: 412, baseW: 640, baseEff: 371 }],
      rows: [
        { kind: "category", label: "Branch", cells: [{ pct: 34 }],
          delta: { diff: 6, sig: true, isMean: false } },
        { kind: "category", label: "App", cells: [{ pct: 28 }] },
        { kind: "category", label: "Call centre", cells: [{ pct: 18 }],
          delta: { diff: -5, sig: true, isMean: false } },
        { kind: "category", label: "Website", cells: [{ pct: 12 }] },
        { kind: "category", label: "Other", cells: [{ pct: 8 }] }
      ]
    }),
    Q1: () => ({
      code: "Q1", title: "Overall satisfaction with the service",
      short_label: "Overall satisfaction", source: "published",
      columns: [{ label: "Total", base: 412 }],
      rows: [{ kind: "net", label: "Top2 (NET)", waves: [], cells: [{ pct: 55 }] }]
    })
  };
  TR.model = { forQuestion: (code) => (MODELS[code] ? MODELS[code]() : null) };
}

function fixtureItems() {
  return [
    { kind: "divider", title: "What moved this wave", note: "Service experience" },
    // insight + weighted bar chart with analyst note (archetype 3: the chart
    // fills the body — chart+table+note on one slide squeezes fitMatrix down
    // to a bases-only table, which is not the archetype)
    { q: "Q4", banner: "", filters: [], chartType: "bar", chartCols: [0],
      title: "Branch dominates and is pulling away",
      note: "Branch keeps growing at the call centre's expense.",
      flags: { chart: true, table: false, insight: true } },
    // quote slide — 4 quotes, one with dropped below-k tags (archetype 5)
    { kind: "snapshot", source: "qualitative",
      title: "Graduates want faster support",
      context: "4 of 12 shortlisted comments · Overall audience",
      html: "", lines: ["x"], moreN: 8, note: "",
      quotes: [
        { text: "The branch staff sorted my registration in ten minutes — the app kept rejecting my documents.",
          q: "Why that score?", tags: ["Female", "25–34", "Promoter"], sentiment: "pos" },
        { text: "Support is far too slow. I waited three weeks for a reply and then had to phone anyway.",
          q: "Anything else?", tags: ["Male", "18–24", "Detractor"], sentiment: "neg" },
        { text: "It does what it says, nothing more.",
          q: "Anything else?", tags: [], sentiment: "neu" },   // below-k tags dropped at pin time
        { text: "The call centre is friendly but they never actually resolve the query first time.",
          q: "Why that score?", tags: ["Female", "35+"], sentiment: "neg" }
      ] },
    // tracking trend exhibit — delta chip + CI note (archetype 6)
    { kind: "exhibit", title: "Service KPI recovers after the dip",
      qs: ["Q1"], banner: "", filters: [], ci: true,
      series: [{ code: "Q1", ri: 0, seg: "total", label: "Total" }],
      flags: { dist: false, trend: true, table: false, insight: true },
      note: "Recovery is real but fragile — watch Wave 13." },
    // matrix pin — auto-grouped behind the Detail divider (archetype 4)
    { kind: "heatmap", banner: "", filters: [], note: "" }
  ];
}

/* ================= minimal zip reader (STORE + DEFLATE) ================= */

function readZip(buf) {
  // locate the end-of-central-directory record
  let eocd = -1;
  for (let i = buf.length - 22; i >= 0; i--) {
    if (buf.readUInt32LE(i) === 0x06054B50) { eocd = i; break; }
  }
  if (eocd === -1) throw new Error("no end-of-central-directory record");
  const count = buf.readUInt16LE(eocd + 10);
  let p = buf.readUInt32LE(eocd + 16);
  const entries = [];
  for (let n = 0; n < count; n++) {
    if (buf.readUInt32LE(p) !== 0x02014B50) throw new Error("bad central directory signature at " + p);
    const method = buf.readUInt16LE(p + 10);
    const csize = buf.readUInt32LE(p + 20);
    const nameLen = buf.readUInt16LE(p + 28);
    const extraLen = buf.readUInt16LE(p + 30);
    const commentLen = buf.readUInt16LE(p + 32);
    const lho = buf.readUInt32LE(p + 42);
    const name = buf.toString("utf8", p + 46, p + 46 + nameLen);
    if (buf.readUInt32LE(lho) !== 0x04034B50) throw new Error(name + ": bad local header signature");
    const lNameLen = buf.readUInt16LE(lho + 26);
    const lExtraLen = buf.readUInt16LE(lho + 28);
    const start = lho + 30 + lNameLen + lExtraLen;
    const raw = buf.subarray(start, start + csize);
    const data = method === 0 ? raw
      : method === 8 ? inflateRawSync(raw)
        : (() => { throw new Error(name + ": unsupported compression method " + method); })();
    entries.push({ name, data: Buffer.from(data) });
    p += 46 + nameLen + extraLen + commentLen;
  }
  return entries;
}

/* ================= XML well-formedness checker ================= */

// tag = name + double/single-quoted attributes; quotes respected when
// scanning for the closing ">"
const TAG_RE = /^<(\/)?([A-Za-z_][A-Za-z0-9._:-]*)((?:\s+[A-Za-z_][A-Za-z0-9._:-]*\s*=\s*(?:"[^"<]*"|'[^'<]*'))*)\s*(\/)?>$/;
const ENTITY_RE = /&(?!amp;|lt;|gt;|quot;|apos;|#\d+;|#x[0-9A-Fa-f]+;)/;

function xmlWellFormed(str, partName) {
  const fail = (why) => { throw new Error(partName + ": " + why); };
  const s = str.replace(/^﻿/, "");
  const text = (t) => {
    if (ENTITY_RE.test(t)) fail("raw '&' in text: " + JSON.stringify(t.slice(0, 60)));
  };
  let i = 0;
  const stack = [];
  let sawElement = false;
  while (i < s.length) {
    const lt = s.indexOf("<", i);
    if (lt === -1) { text(s.slice(i)); break; }
    text(s.slice(i, lt));
    if (s.startsWith("<?", lt)) {
      const end = s.indexOf("?>", lt);
      if (end === -1) fail("unterminated processing instruction");
      i = end + 2; continue;
    }
    if (s.startsWith("<!--", lt)) {
      const end = s.indexOf("-->", lt);
      if (end === -1) fail("unterminated comment");
      i = end + 3; continue;
    }
    if (s.startsWith("<![CDATA[", lt)) {
      const end = s.indexOf("]]>", lt);
      if (end === -1) fail("unterminated CDATA");
      i = end + 3; continue;
    }
    // find the tag's closing ">" honouring quoted attribute values
    let j = lt + 1, quote = null;
    while (j < s.length) {
      const c = s[j];
      if (quote) { if (c === quote) quote = null; }
      else if (c === '"' || c === "'") quote = c;
      else if (c === ">") break;
      j++;
    }
    if (j >= s.length) fail("unterminated tag at offset " + lt);
    const tag = s.slice(lt, j + 1);
    const m = tag.match(TAG_RE);
    if (!m) fail("malformed tag: " + JSON.stringify(tag.slice(0, 100)));
    if (m[1]) {
      const open = stack.pop();
      if (open !== m[2]) fail("mismatched </" + m[2] + "> (open element: <" + open + ">)");
    } else if (!m[4]) {
      stack.push(m[2]);
    }
    sawElement = true;
    i = j + 1;
  }
  if (!sawElement) fail("no elements");
  if (stack.length) fail("unclosed elements: " + stack.join(", "));
}

/* ================= build the deck ================= */

console.log("PPTX visual QA gate — suite:");

setupFixture();
let slides, bytes;

run("fixture deck assembles: cover + divider 01 + bar + quotes + trend + Detail 02 + matrix", () => {
  slides = TR.story2._slidesFor(fixtureItems());
  eq(slides.length, 7, "slide count");
  const xmlOf = (s) => (typeof s === "string" ? s : s.xml);
  assert(xmlOf(slides[0]).indexOf("Turas visual QA fixture") !== -1, "cover leads");
  assert(xmlOf(slides[0]).indexOf("Overall service holds up") !== -1, "authored exec summary on the cover");
  assert(xmlOf(slides[0]).indexOf("Branch dominates and is pulling away") !== -1, "findings listed");
  assert(xmlOf(slides[1]).indexOf(">01<") !== -1, "story divider numbered 01");
  // WP6 render finding: a roundRect full-bleed background leaves white
  // notched corners on the rendered divider — the background must be sharp
  const FULL_BLEED = '<a:off x="0" y="0"/><a:ext cx="' +
    Math.round(13.333 * 914400) + '" cy="' + Math.round(7.5 * 914400) +
    '"/></a:xfrm><a:prstGeom prst="rect">';
  assert(xmlOf(slides[1]).indexOf(FULL_BLEED) !== -1 &&
    xmlOf(slides[5]).indexOf(FULL_BLEED) !== -1,
    "divider backgrounds are sharp full-bleed rects, not roundRects");
  assert(slides[2].charts && slides[2].charts.length === 1, "bar-chart slide carries a native chart");
  assert(xmlOf(slides[2]).indexOf("n=412 (weighted 640 · effective 371)") !== -1,
    "weighted footer base line");
  assert(xmlOf(slides[3]).indexOf(">“<") !== -1, "quote slide glyph");
  assert(xmlOf(slides[4]).indexOf("▲ +4pp •") !== -1, "trend slide delta chip");
  assert(xmlOf(slides[4]).indexOf("Wilson 95% confidence bands shown") !== -1, "trend slide CI note");
  assert(xmlOf(slides[5]).indexOf("Detail") !== -1 && xmlOf(slides[5]).indexOf(">02<") !== -1,
    "Detail divider numbered 02");
  assert(xmlOf(slides[6]).indexOf("Index heatmap") !== -1, "matrix slide last");
});

const tmpDir = mkdtempSync(path.join(os.tmpdir(), "turas-pptx-qa-"));
const pptxPath = path.join(tmpDir, "visual_qa_deck.pptx");

run("deck packages and lands in the OS tmpdir", () => {
  bytes = TR.pptx.package(slides, { project: TR.AGG.project });
  assert(bytes && bytes.length > 10000, "plausible package size, got " + (bytes && bytes.length));
  writeFileSync(pptxPath, Buffer.from(bytes));
  assert(existsSync(pptxPath), "file written");
});
console.log("    deck: " + pptxPath);

/* ================= structural gate: every part parses ================= */

let parts = null;

run("zip structure: central directory reads, expected part inventory present", () => {
  parts = readZip(Buffer.from(bytes));
  const names = parts.map((p) => p.name);
  const need = ["[Content_Types].xml", "_rels/.rels", "ppt/presentation.xml",
    "ppt/theme/theme1.xml", "ppt/slideMasters/slideMaster1.xml",
    "ppt/slideLayouts/slideLayout1.xml"];
  for (let i = 1; i <= 7; i++) {
    need.push("ppt/slides/slide" + i + ".xml", "ppt/slides/_rels/slide" + i + ".xml.rels");
  }
  need.forEach((n) => assert(names.indexOf(n) !== -1, "missing part " + n));
  // two native charts (bar + trend), each with its embedded workbook
  eq(names.filter((n) => /^ppt\/charts\/chart\d+\.xml$/.test(n)).length, 2, "chart parts");
  eq(names.filter((n) => /^ppt\/embeddings\/chart_data\d+\.xlsx$/.test(n)).length, 2,
    "embedded workbooks");
  assert(names.indexOf("ppt/slides/slide8.xml") === -1, "no phantom slides");
});

run("every XML part in the package is well-formed (incl. embedded workbook parts)", () => {
  let checkedOuter = 0, checkedInner = 0;
  parts.forEach((p) => {
    if (/\.(xml|rels)$/.test(p.name)) {
      xmlWellFormed(p.data.toString("utf8"), p.name);
      checkedOuter++;
    } else if (/\.xlsx$/.test(p.name)) {
      readZip(p.data).forEach((inner) => {
        if (/\.(xml|rels)$/.test(inner.name)) {
          xmlWellFormed(inner.data.toString("utf8"), p.name + "::" + inner.name);
          checkedInner++;
        }
      });
    }
  });
  assert(checkedOuter >= 25, "outer XML parts checked, got " + checkedOuter);
  assert(checkedInner >= 6, "workbook XML parts checked, got " + checkedInner);
});

run("no unresolved page tokens or template placeholders anywhere in the package", () => {
  const pkg = Buffer.from(bytes).toString("utf8");
  assert(pkg.indexOf(TR.pptx.PAGE_TOKEN) === -1, "page tokens all resolved");
  assert(pkg.indexOf("Calibri") === -1, "no Calibri");
  assert(pkg.indexOf("undefined") === -1, "no stringified undefined leaked into a part");
});

/* ================= render gate: soffice -> pdf -> PNGs ================= */

const haveSoffice = !spawnSync("soffice", ["--version"], { timeout: 30000 }).error;
const havePdftoppm = !spawnSync("pdftoppm", ["-v"], { timeout: 20000 }).error;
const pdfPath = path.join(tmpDir, "visual_qa_deck.pdf");
let pngs = [];

if (!haveSoffice) {
  skip("render deck to PDF via soffice", "soffice (LibreOffice) not on PATH");
  skip("per-slide PNG render checks", "no PDF to rasterise");
} else {
  run("soffice renders the deck to PDF", () => {
    const r = spawnSync("soffice",
      ["--headless", "--convert-to", "pdf", "--outdir", tmpDir, pptxPath],
      { timeout: 180000 });
    assert(!r.error && r.status === 0,
      "soffice exit " + (r.error ? r.error.message : r.status) +
      (r.stderr ? " — " + String(r.stderr).slice(0, 300) : ""));
    assert(existsSync(pdfPath), "PDF written");
    assert(statSync(pdfPath).size > 10000, "PDF has substance");
  });

  if (!havePdftoppm) {
    skip("per-slide PNG render checks", "pdftoppm (poppler) not on PATH — PDF at " + pdfPath);
  } else if (existsSync(pdfPath)) {
    run("pdftoppm rasterises one PNG per slide, none blank", () => {
      const r = spawnSync("pdftoppm",
        ["-png", "-r", "110", pdfPath, path.join(tmpDir, "slide")],
        { timeout: 120000 });
      assert(!r.error && r.status === 0, "pdftoppm failed: " +
        (r.error ? r.error.message : String(r.stderr).slice(0, 300)));
      pngs = readdirSync(tmpDir).filter((f) => /^slide-\d+\.png$/.test(f)).sort();
      eq(pngs.length, 7, "one PNG per slide");
      pngs.forEach((f) => {
        const size = statSync(path.join(tmpDir, f)).size;
        assert(size > 4000, f + " looks blank (" + size + " bytes)");
      });
    });
    console.log("    renders: " + tmpDir + "/slide-*.png  (eyeball these)");
  } else {
    skip("per-slide PNG render checks", "PDF render failed upstream");
  }
}

/* ================= summary ================= */

const note = skipped ? " (" + skipped + " render check(s) SKIPPED — structural gate still ran)" : "";
console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed" + note);
process.exit(failed ? 1 : 0);
