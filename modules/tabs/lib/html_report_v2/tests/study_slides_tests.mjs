#!/usr/bin/env node
/**
 * Study slides — exhibits authored in the config's AddedSlides sheet, carried
 * on the island as project.slides. Four contracts:
 *
 * S1 Authored, read-only: they render in their own Report-tab card, one per
 *    row, and are NEVER merged into the reader's own Added-slides store. That
 *    store takes ownership on first edit and would then ignore anything a later
 *    run authored, so the two must not share a home.
 * S2 Pinned by reference: a pinned slide stores an INDEX, not the picture. The
 *    base64 is embedded once on the island; copying it into the story item
 *    would duplicate it in localStorage and in every saved copy.
 * S3 Into PowerPoint as a picture: the original file's bytes go into the deck
 *    (both the editable and the image deck), never a rasterised card, and the
 *    media part is named for the real format.
 * S4 Survives its slide going away: a pin whose row was deleted from the sheet
 *    renders a plain note everywhere and never crashes a render or a deck.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/study_slides_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const SHELL_SRC = readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8");
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
  const i = hay.indexOf(needle);
  if (i === -1) throw new Error(msg + ": missing " + JSON.stringify(needle));
  return i;
}

/* The picture is never decoded as an image by any of this code — it is decoded
 * as BYTES and handed to the pptx writer. So the fixtures carry known bytes
 * behind a real data-URI prefix; asserting the round-trip is the actual
 * contract. (The R suite parses genuine PNG/JPEG headers; that is its job.) */
const PNG_BYTES = "PNGPAYLOAD-0123";
const JPG_BYTES = "JPEGPAYLOAD-45";
const b64 = (s) => Buffer.from(s, "binary").toString("base64");
const SLIDES = [
  { title: "Qual phase — what customers said", text: "Six focus groups, March.",
    image: "data:image/png;base64," + b64(PNG_BYTES), w: 1280, h: 720 },
  { title: "Method note", text: "Fieldwork ran in July." },
  { title: "Photo board", image: "data:image/jpeg;base64," + b64(JPG_BYTES), w: 800, h: 600 }
];

/* ---------------- sandbox: report + story over the real exporter ---------- */

function slideSandbox(opts) {
  opts = opts || {};
  const store = {};
  const sb = { console, TextEncoder, atob,
    localStorage: {
      getItem: (k) => (k in store ? store[k] : null),
      setItem: (k, v) => { store[k] = String(v); },
      removeItem: (k) => { delete store[k]; }
    } };
  sb.globalThis = sb;
  sb.window = sb;
  vm.createContext(sb);
  for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js",
    "14_pptx_parts.js", "23_render.js", "23z_charts.js", "23za_trend.js",
    "23y_xlsx.js", "29_export.js"]) load(sb, f);
  const TR = sb.TR;
  TR.AGG = {
    // "slides" in opts, not opts.slides — a test needs to express an island
    // that carries no slides key at all (every report built before this)
    project: { name: "CCPB 2026", client: "CCPB", wave: "W2026",
      slides: "slides" in opts ? opts.slides : SLIDES },
    questions: [], banner_groups: []
  };
  TR.userState = null;
  TR.d2 = {
    storeKey: (b) => b + ":proj",
    state: { tab: "report", banner: "", filters: [], sorts: {}, hiddenRows: {},
      hiddenChartRows: {}, sigMode: "95", showIntervals: false, showCounts: false,
      activeQ: null },
    questionByCode: () => null,
    shortLabel: (q) => q.title || "",
    rowScope: () => "all", hiddenFor: () => [],
    bannerDescription: () => "All respondents",
    categories: () => [],
    tracking: () => ({ enabled: false }),
    qualitative: () => ({ enabled: false })
  };
  TR.shell = { toast: () => {} };
  TR.charts = Object.assign(TR.charts || {},
    { clip: (s, n) => (String(s).length > n ? String(s).slice(0, n - 1) + "…" : String(s)) });
  TR.model = { forQuestion: () => null };
  TR.exhibit = { titleFor: () => "EX", models: () => [], panelsHtml: () => "<div>EX</div>" };
  TR.cards2 = { chartState: () => ({ type: "bar", kind: "auto", cols: [0] }) };
  TR.ai = { execSummaryHtml: () => "", methodologyHtml: () => "" };
  load(sb, "28_insights.js");
  load(sb, "32_report.js");
  load(sb, "30_story.js");
  return sb;
}

console.log("Study slides (config AddedSlides -> report, story, deck) — suite:");

/* ---------------- S1: authored, read-only, in their own card ------------- */

run("S1: no authored slides -> no card at all", () => {
  eq(slideSandbox({ slides: [] }).TR.report.studySlidesHtml(), "", "empty list");
  eq(slideSandbox({ slides: undefined }).TR.report.studySlidesHtml(), "",
    "project.slides absent from an older island");
});

run("S1: one card per row — picture, words and caption", () => {
  const html = slideSandbox({}).TR.report.studySlidesHtml();
  at(html, "<h3>Study slides</h3>", "the card is headed as authored slides");
  eq(html.split('class="added-slide"').length - 1, 3, "one tile per sheet row");
  at(html, 'src="data:image/png;base64,', "the picture is embedded");
  at(html, "Six focus groups, March.", "the row's text renders");
  at(html, '<span class="as-cap">Method note</span>', "the caption is static text");
  assert(html.indexOf('class="as-title"') === -1,
    "no editable caption input — the report author owns these");
  // a text-only row is a slide too
  const textOnly = slideSandbox({ slides: [{ title: "T", text: "Just words" }] })
    .TR.report.studySlidesHtml();
  at(textOnly, "Just words", "a row with no image still renders");
  assert(textOnly.indexOf("<img") === -1, "…and no empty img tag");
});

run("S1: authored slides never enter the reader's own Added-slides store", () => {
  const TR = slideSandbox({}).TR;
  eq(TR.report.data().slides, [], "the reader's store stays empty");
  // the two cards are separate: the reader's card keeps its import controls
  const tab = TR.report.studySlidesHtml();
  assert(tab.indexOf("+ Import image") === -1,
    "the authored card carries no import controls");
});

run("S1: every tile is pinnable, and each pin names its own row", () => {
  const html = slideSandbox({}).TR.report.studySlidesHtml();
  eq(html.split("data-snap-pin").length - 1, 3, "a pin per slide");
  at(html, 'data-snap-source="slide" data-snap-slide="0"', "first pin points at row 0");
  at(html, 'data-snap-slide="2"', "third pin points at row 2");
  at(html, 'data-snap-card', "each tile is a snap card for the shared pin handler");
  // the shared pin handler routes a slide pin by reference instead of
  // snapshotting the card (which would copy the base64 into the story)
  at(SHELL_SRC, 'var slideIdx = pin.getAttribute("data-snap-slide");',
    "the shell reads the slide index");
  at(SHELL_SRC, "TR.story2.pinSlide(parseInt(slideIdx, 10),", "…and pins by reference");
});

/* ---------------- S2: pinned by reference, not by copy ------------------- */

run("S2: a pinned slide stores an index — the picture is never duplicated", () => {
  const TR = slideSandbox({}).TR;
  TR.story2.pinSlide(0, "Qual phase — what customers said");
  const items = TR.story2.items();
  eq(items.length, 1, "one story item");
  eq(items[0].kind, "slide", "its own item kind");
  eq(items[0].slide, 0, "…carrying the row index");
  const json = JSON.stringify(items);
  assert(json.indexOf("base64") === -1, "no data URI in the story item");
  assert(json.indexOf(b64(PNG_BYTES)) === -1, "no picture bytes in the story item");
  // pinning the same slide three times must not grow the payload three pictures
  TR.story2.pinSlide(0, "again"); TR.story2.pinSlide(0, "and again");
  assert(JSON.stringify(TR.story2.items()).indexOf("base64") === -1,
    "still no picture in stored state after repeated pins");
});

run("S2: the story resolves the picture from the island at render time", () => {
  const TR = slideSandbox({}).TR;
  TR.story2.pinSlide(0, "");
  const item = TR.story2.items()[0];
  eq(TR.story2.pinTitle(item), "Qual phase — what customers said",
    "an untitled pin takes the slide's own caption");
  const body = TR.story2.itemBodyHtml(item);
  at(body, "data:image/png;base64,", "the body renders the current picture");
  at(body, "Six focus groups, March.", "…and the current words");
  at(TR.story2._itemHtml(item, 0), "SLIDE", "the story card is labelled a slide");
  at(TR.story2._itemHtml(item, 0), '<textarea class="si-note"',
    "commentary stays editable, as on every other pin");
});

/* ---------------- S3: into PowerPoint as a real picture ------------------ */

run("S3: slidePicture decodes the original bytes and names the format", () => {
  const TR = slideSandbox({}).TR;
  const pic = TR.exporter.slidePicture(SLIDES[0]);
  eq(Array.from(pic.bytes).map((b) => String.fromCharCode(b)).join(""), PNG_BYTES,
    "the original bytes, unaltered");
  eq([pic.w, pic.h, pic.ext], [1280, 720, "png"], "size from the config, real extension");
  eq(TR.exporter.slidePicture(SLIDES[2]).ext, "jpeg", "jpeg keeps its own extension");
  eq(TR.exporter.slidePicture(SLIDES[1]), null, "a text-only slide has no picture");
  // formats the package cannot declare are refused rather than mislabelled
  eq(TR.exporter.slidePicture({ image: "data:image/svg+xml;base64," + b64("<svg/>") }),
    null, "svg refused");
  eq(TR.exporter.slidePicture({ image: "data:image/webp;base64," + b64("x") }),
    null, "webp refused");
  eq(TR.exporter.slidePicture({ image: "not a data uri" }), null, "junk refused");
});

run("S3: the editable deck carries the picture itself, not a rendered card", () => {
  const TR = slideSandbox({}).TR;
  TR.story2.pinSlide(0, "");
  const slides = TR.story2._slidesFor(TR.story2.items());
  const withImg = slides.filter((s) => s.images && s.images.length);
  eq(withImg.length, 1, "exactly one image slide");
  eq(Array.from(withImg[0].images[0].bytes).map((b) => String.fromCharCode(b)).join(""),
    PNG_BYTES, "the authored bytes reach the deck untouched");
  eq(withImg[0].images[0].ext, "png", "the part extension travels with it");
});

run("S3: the image deck passes the picture through instead of rasterising it", () => {
  const TR = slideSandbox({}).TR;
  TR.story2.pinSlide(2, "");
  const cards = TR.story2._imageCards(TR.story2.items());
  eq(cards.length, 1, "one card");
  assert(cards[0] && cards[0].png, "a pre-rendered picture, not an SVG string");
  eq(cards[0].png.ext, "jpeg", "…carrying its format");
  // downloadImageDeck must recognise that shape rather than trying to rasterise
  const EXPORT_SRC = readFileSync(path.join(JS_DIR, "29_export.js"), "utf8");
  at(EXPORT_SRC, "if (card && card.png) return Promise.resolve(card.png);",
    "the image deck short-circuits an already-rendered picture");
});

run("S3: the package names the media part for the real format", () => {
  const TR = slideSandbox({}).TR;
  const jpg = TR.exporter.imageSlide(TR.exporter.slidePicture(SLIDES[2]));
  const bytes = TR.pptx.package([jpg], { project: { name: "P" } });
  const zip = Buffer.from(bytes).toString("binary");
  assert(zip.indexOf("ppt/media/image1.jpeg") !== -1, "the jpeg is stored as .jpeg");
  assert(zip.indexOf("ppt/media/image1.png") === -1, "…never renamed to .png");
  assert(zip.indexOf('Extension="jpeg"') !== -1, "and the content type is declared");
  // a rasterised card (no ext) still lands as png, exactly as before
  const png = TR.exporter.imageSlide({ bytes: new Uint8Array([1, 2, 3]), w: 10, h: 5 });
  const zip2 = Buffer.from(TR.pptx.package([png], { project: { name: "P" } })).toString("binary");
  assert(zip2.indexOf("ppt/media/image1.png") !== -1, "extension-less callers unchanged");
});

run("S3: the picture keeps its aspect ratio on the slide", () => {
  const TR = slideSandbox({}).TR;
  const wide = TR.exporter.imageSlide({ bytes: new Uint8Array([1]), w: 1600, h: 400, ext: "png" });
  const tall = TR.exporter.imageSlide({ bytes: new Uint8Array([1]), w: 400, h: 1600, ext: "png" });
  const ext = (xml) => xml.match(/<a:ext cx="(\d+)" cy="(\d+)"\/>/g).pop();
  const [, wCx, wCy] = /cx="(\d+)" cy="(\d+)"/.exec(ext(wide.xml));
  const [, tCx, tCy] = /cx="(\d+)" cy="(\d+)"/.exec(ext(tall.xml));
  assert(Math.abs((wCx / wCy) - 4) < 0.05, "a 4:1 picture is placed 4:1");
  assert(Math.abs((tCx / tCy) - 0.25) < 0.01, "a 1:4 picture is placed 1:4");
});

/* ---------------- S4: the slide goes away -------------------------------- */

run("S4: a pin whose row was deleted says so, everywhere, without crashing", () => {
  const sb = slideSandbox({});
  const TR = sb.TR;
  TR.story2.pinSlide(0, "");
  // the config was edited and the report rebuilt with that row gone
  TR.AGG.project.slides = [];
  const item = TR.story2.items()[0];
  eq(TR.story2._slideOf(item), null, "the pin no longer resolves");
  at(TR.story2.itemBodyHtml(item), "no longer in the project configuration",
    "the story body says so");
  at(TR.story2._itemHtml(item, 0), "no longer in the project configuration",
    "…and so does the story card");
  eq(TR.story2.pinTitle(item), "Study slide", "the title falls back, never blank");
  // and the deck still builds — a missing picture must not lose the slide
  const slides = TR.story2._slidesFor(TR.story2.items());
  assert(slides.length >= 1, "the deck still has a slide for the pin");
  const cards = TR.story2._imageCards(TR.story2.items());
  assert(cards[0] && !cards[0].png, "the image deck falls back to a rendered card");
});

run("S4: a text-only slide exports as a slide, not as nothing", () => {
  const TR = slideSandbox({}).TR;
  TR.story2.pinSlide(1, "");
  const slides = TR.story2._slidesFor(TR.story2.items());
  assert(slides.length >= 1, "a text slide still reaches the deck");
  assert(!slides.some((s) => s.images && s.images.length), "with no picture part");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
