#!/usr/bin/env node
/**
 * Exec-summary cover gate (READER_EXPERIENCE_PLAN bundle D) — two contracts:
 *
 * D1 Landing = exec summary: a saved/shared copy (user-state island present)
 *    that carries story content (pins incl. promoted hub insights, and/or an
 *    authored Report-tab executive summary / background) OPENS on a cover —
 *    title/client/wave, the analyst sections, 3–5 leading findings (each pin
 *    as its insight sentence over an evidence thumbnail rendered by the pin's
 *    OWN renderer) and an "Explore the dashboard →" action. Deep links
 *    (#tab=…) always win; analyst-fresh reports keep today's landing; the
 *    cover is a route, never a READ-group tab; a header "Cover" link exists
 *    only when the cover does.
 * D2 Pins read as insights: pinCurrent's default title is the insight line
 *    (q.headline > analyst-insight first sentence via reader.insightTitle),
 *    else "" so each surface keeps its existing default; the stored title
 *    leads the story item, present mode, PNG and PPTX slide; older pins carry
 *    no title field and render byte-identically (no migration).
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/cover_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const CSS = readFileSync(path.join(HERE, "..", "assets", "styles.css"), "utf8");
const SHELL_SRC = readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8");
const READER_SRC = readFileSync(path.join(JS_DIR, "24a_reader.js"), "utf8");
const STORY_SRC = readFileSync(path.join(JS_DIR, "30_story.js"), "utf8");
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
/** indexOf that refuses -1 — asserts presence AND returns the position. */
function at(hay, needle, msg) {
  const i = hay.indexOf(needle);
  if (i === -1) throw new Error(msg + ": missing " + JSON.stringify(needle));
  return i;
}
const count = (hay, needle) => hay.split(needle).length - 1;

/* ---------------- sandbox: the cover stack (reader + story + report) -------- */

function coverSandbox(opts) {
  opts = opts || {};
  const sb = { console };
  sb.globalThis = sb;
  sb.window = sb;
  vm.createContext(sb);
  load(sb, "00_namespace.js");
  load(sb, "01_format.js");
  const TR = sb.TR;
  TR.AGG = {
    project: opts.project || { name: "CCS 2026", client: "CCS", wave: "Wave 2" },
    questions: opts.questions || [],
    banner_groups: []
  };
  TR.userState = opts.userState !== undefined ? opts.userState : null;
  TR.d2 = {
    storeKey: (b) => b + ":proj",
    state: { tab: "cover", banner: "", filters: [], sorts: {}, hiddenRows: {},
      hiddenChartRows: {}, sigMode: "95", showIntervals: false, showCounts: false,
      activeQ: null },
    questionByCode: (c) => TR.AGG.questions.find((q) => q.code === c) || null,
    shortLabel: (q) => q.short_label || q.title || "",
    rowScope: () => "all",
    hiddenFor: () => [],
    bannerDescription: () => "All respondents",
    tracking: () => ({ enabled: false }),
    qualitative: () => ({ enabled: false })
  };
  TR.shell = { toast: () => {} };
  TR.charts = { clip: (s, n) => (String(s).length > n ? String(s).slice(0, n - 1) + "…" : String(s)) };
  TR.model = { forQuestion: (code) => (opts.models && opts.models[code]) || null };
  TR.render = { tableHtml: () => "<table>TBL</table>", chartBy: () => "<svg>CH</svg>" };
  TR.exhibit = { titleFor: () => "EXTITLE", models: () => [], panelsHtml: () => "<div>EXPANELS</div>" };
  TR.cards2 = { chartState: () => ({ type: "bar", kind: "auto", cols: [0] }) };
  load(sb, "24a_reader.js");
  load(sb, "28_insights.js");
  load(sb, "30_story.js");
  load(sb, "32_report.js");
  return sb;
}

const snap = (title) => ({ kind: "snapshot", source: "hub", title: title,
  context: "", html: "<div class='hx'>EVIDENCE</div>", lines: [], note: "" });

console.log("Exec-summary cover (bundle D) — suite:");

/* ---------------- D1: availability (all four combinations) ---------------- */

run("D1: cover opens only when userState AND content — all four combinations", () => {
  // fresh + no content
  eq(coverSandbox({}).TR.reader.coverAvailable(), false, "fresh, no content");
  // fresh + content (the analyst's own local story) — still no cover
  const fresh = coverSandbox({});
  fresh.TR.story2.pinSnapshot(snap("Local pin"));
  eq(fresh.TR.reader.coverAvailable(), false, "fresh + content stays dashboard-first");
  // saved copy + no content
  eq(coverSandbox({ userState: { insights: {} } }).TR.reader.coverAvailable(), false,
    "saved copy without story content");
  // saved copy + content
  eq(coverSandbox({ userState: { story: [snap("A finding")] } }).TR.reader.coverAvailable(),
    true, "saved copy + story pins");
});

run("D1: a config-authored exec summary or background alone is cover content", () => {
  // Sections are authored in the config (report_meta from the Comments sheet)
  // and read-only in the app — the cover reads the SAME value the Report tab
  // shows, so config sections alone (on a saved copy) are content…
  const exec = coverSandbox({ userState: {},
    project: { name: "P", report_meta: { exec_summary: "The findings that matter." } } });
  eq(exec.TR.reader.coverAvailable(), true, "config exec summary alone");
  const bg = coverSandbox({ userState: {},
    project: { name: "P", report_meta: { background: "Fieldwork in May." } } });
  eq(bg.TR.reader.coverAvailable(), true, "config background alone");
  const blank = coverSandbox({ userState: {},
    project: { name: "P", report_meta: { exec_summary: "   " } } });
  eq(blank.TR.reader.coverAvailable(), false, "whitespace-only section is not content");
  // …and legacy locally-typed sections in stored state no longer count
  const legacy = coverSandbox({ userState: { report: {
    sections: { exec: "Old locally-typed summary." }, about: {}, slides: [] } } });
  eq(legacy.TR.reader.coverAvailable(), false, "legacy stored edits are ignored");
});

/* ---------------- D1: landing decision + routing ---------------- */

function shellSandbox(coverAvailable) {
  const sb = { console };
  sb.globalThis = sb;
  sb.window = sb;
  sb.TR = {
    fmt: { escapeHtml: (s) => String(s == null ? "" : s) },
    AGG: { project: {} },
    d2: { tracking: () => ({ enabled: true }), qualitative: () => ({ enabled: true }) },
    reader: { coverAvailable: () => coverAvailable }
  };
  vm.createContext(sb);
  load(sb, "24_shell.js");
  return sb;
}

run("D1: deep links (#tab=…) always win over the cover", () => {
  const shell = shellSandbox(true).TR.shell;
  eq(shell.landingTab("#tab=crosstabs&q=Q8", "crosstabs"), "crosstabs",
    "a tab deep link keeps its tab");
  eq(shell.landingTab("#tab=cover", "cover"), "cover", "a cover deep link stays on the cover");
  eq(shell.landingTab("", "takeout"), "cover", "no deep link -> the cover opens");
  eq(shell.landingTab("#selftest", "takeout"), "cover",
    "a non-tab hash does not suppress the cover");
});

run("D1: analyst-fresh reports keep today's landing exactly", () => {
  const shell = shellSandbox(false).TR.shell;
  eq(shell.landingTab("", "takeout"), "takeout", "no cover -> default landing unchanged");
  eq(shell.landingTab("#tab=story", "story"), "story", "deep link unchanged");
});

run("D1: the cover is a route, never a tab in the READ group", () => {
  const groups = shellSandbox(true).TR.shell.tabGroups();
  const ids = groups.reduce((a, g) => a.concat(g.tabs.map((t) => t[0])), []);
  assert(ids.indexOf("cover") === -1, "no cover tab button in either group");
  // route() dispatches the cover to the reader's renderer…
  const route = SHELL_SRC.slice(at(SHELL_SRC, "shell.route = function"));
  at(route, 'if (d2.state.tab === "cover") TR.reader.renderCover(host);', "cover route");
  // …and a cover deep link without cover content falls back to the dashboard
  at(route, 'd2.state.tab = "dashboard";', "unavailable-cover fallback");
  // no analysis chrome on the landing page: filter bar hidden on the cover
  assert(/fb\.hidden = [^;]*"cover"/.test(route), "filter bar hidden on the cover");
  // …and the audience strip renders empty there (:empty hides the container)
  assert(/tab === "cover"\s*\?\s*""/.test(READER_SRC), "audience strip empty on the cover");
  assert(CSS.indexOf(".audstrip:empty { display: none; }") !== -1, "strip container collapses");
});

run("D1: header 'Cover' link exists only when the cover does, and routes to it", () => {
  const frame = SHELL_SRC.slice(at(SHELL_SRC, "function frameHtml"),
    at(SHELL_SRC, "shell.route = function"));
  const gate = at(frame, "TR.reader.coverAvailable()", "link gated on coverAvailable");
  const link = at(frame, "data-cover-open", "header Cover link");
  assert(gate < link && link - gate < 300, "the link sits behind the gate");
  at(SHELL_SRC, 'if (e.target.closest("[data-cover-open]")) shell.goTab("cover");',
    "click routes to the cover like any tab");
});

/* ---------------- D1: cover content ---------------- */

const COVER_OPTS = {
  userState: {
    story: [
      snap("Value beats price in every region"),
      { kind: "divider", title: "Part 2", note: "" },
      // an OLD question pin (no title field) — must still read as an insight
      { kind: "question", q: "Q8", banner: "", filters: [],
        flags: { chart: false, table: true, insight: true }, note: "" }
    ],
    // legacy locally-typed section — ignored now that sections are config-authored
    report: { sections: { exec: "STALE LOCAL EDIT" }, about: {}, slides: [] }
  },
  project: { name: "CCS 2026", client: "CCS", wave: "Wave 2",
    report_meta: { exec_summary: "Line one.\nLine two." } },
  questions: [{ code: "Q8", title: "How was registration?",
    headline: "Registration is the pain point" }],
  models: { Q8: { code: "Q8", title: "How was registration?", rows: [], columns: [] } }
};

run("D1: cover = title/client/wave + authored sections + explore action", () => {
  const html = coverSandbox(COVER_OPTS).TR.reader.coverHtml();
  const name = at(html, "<h1>CCS 2026</h1>", "report title");
  const sub = at(html, '<div class="cover-sub">CCS · Wave 2</div>', "client · wave");
  assert(name < sub, "title above the client/wave line");
  at(html, "<h3>Executive summary</h3><p>Line one.</p><p>Line two.</p>",
    "authored exec summary as paragraphs");
  assert(html.indexOf("STALE LOCAL EDIT") === -1,
    "a legacy locally-typed section never reaches the cover");
  assert(html.indexOf("Background &amp; method") === -1,
    "unauthored section omitted, never an empty card");
  assert(count(html, "data-cover-explore") >= 1, "Explore the dashboard action present");
});

run("D1: findings = pins as insight sentences over their OWN evidence renderers", () => {
  const html = coverSandbox(COVER_OPTS).TR.reader.coverHtml();
  eq(count(html, 'class="cf-title"'), 2, "two findings (the divider is not a finding)");
  assert(html.indexOf("Part 2") === -1, "divider skipped entirely");
  // snapshot pin: its title is the sentence; its stored HTML is the thumbnail
  const t1 = at(html, "Value beats price in every region", "snapshot pin title");
  const ev1 = at(html, '<div class="snap-body"><div class=\'hx\'>EVIDENCE</div></div>',
    "snapshot evidence via the pin's own HTML");
  assert(t1 < ev1, "sentence above the evidence");
  // old question pin: the reader chain supplies the sentence; the evidence is
  // the pin's own table render (disclosure gates ride the renderer)
  const t2 = at(html, "Registration is the pain point", "question pin insight sentence");
  const ev2 = at(html, "<table>TBL</table>", "question evidence via tableHtml");
  assert(t2 < ev2 && t1 < t2, "findings in story order, each sentence over its evidence");
  eq(count(html, '<div class="cover-thumb">'), 2, "one thumbnail per finding");
});

run("D1: findings cap at 5, in story order", () => {
  const many = { userState: { story: [
    snap("F1"), snap("F2"), { kind: "divider", title: "D", note: "" },
    snap("F3"), snap("F4"), snap("F5"), snap("F6"), snap("F7")
  ] } };
  const sb = coverSandbox(many);
  eq(sb.TR.reader.coverFindings().map((f) => f.title),
    ["F1", "F2", "F3", "F4", "F5"], "first five evidence items");
  const html = sb.TR.reader.coverHtml();
  eq(count(html, 'class="cf-title"'), 5, "exactly five findings rendered");
  assert(html.indexOf("F6") === -1, "the sixth pin stays off the cover");
});

run("D1: 'Explore the dashboard' routes to the first READ tab", () => {
  const sb = coverSandbox({ userState: { story: [snap("A")] } });
  load(sb, "24_shell.js");   // real tabGroups over the same stubs
  eq(sb.TR.reader.exploreTarget(), "dashboard", "dashboard when present");
  sb.TR.AGG.project.tabs = { dashboard: false };
  eq(sb.TR.reader.exploreTarget(), "takeout", "flag-gated dashboard -> next READ tab");
  at(READER_SRC, "TR.shell.goTab(reader.exploreTarget())", "the click routes via goTab");
});

/* ---------------- D2: pins read as insights ---------------- */

function pinSandbox() {
  return coverSandbox({
    questions: [
      { code: "Q8", title: "How was registration?", headline: "Registration is the pain point" },
      { code: "Q7", title: "Which course?" },
      { code: "Q6", title: "Plain question", short_label: "Plain short" }
    ],
    models: {
      Q8: { code: "Q8", title: "How was registration?", rows: [], columns: [] },
      Q6: { code: "Q6", title: "Plain question", rows: [], columns: [] }
    }
  });
}

run("D2: default-title chain — headline > insight first sentence > surface default", () => {
  const sb = pinSandbox();
  const TR = sb.TR;
  TR.insights.set("Q7", "Course choice splits the campuses. More detail here.");
  TR.d2.state.activeQ = "Q8"; TR.story2.pinCurrent();
  TR.d2.state.activeQ = "Q7"; TR.story2.pinCurrent();
  TR.d2.state.activeQ = "Q6"; TR.story2.pinCurrent();
  const items = TR.story2.items();
  eq(items[0].title, "Registration is the pain point", "q.headline wins");
  eq(items[1].title, "Course choice splits the campuses.",
    "else the analyst insight's first sentence (reader.insightTitle chain)");
  eq(items[2].title, "", "else empty — each surface keeps its existing default");
  eq(TR.story2.pinTitle(items[2]), "Plain short",
    "the display chain then falls to short_label/title");
});

run("D2: story item + present title = the pin title; note stays editable as today", () => {
  const sb = pinSandbox();
  const TR = sb.TR;
  TR.d2.state.activeQ = "Q8";
  TR.story2.pinCurrent();
  const html = TR.story2._itemHtml(TR.story2.items()[0], 0);
  at(html, "<strong>Registration is the pain point</strong>", "insight title leads the item");
  assert(html.indexOf("How was registration?") === -1, "question text no longer the headline");
  at(html, '<textarea class="si-note"', "commentary stays an editable textarea");
  assert(html.indexOf('input') === -1 && html.indexOf("contenteditable") === -1,
    "no new title-editing control added");
  // present mode reads the same stored title
  at(STORY_SRC, "model.code + \" — \" + (item.title || model.title)", "present title = pin title");
});

run("D2: existing pins in saved copies render unchanged — no migration", () => {
  const sb = coverSandbox(COVER_OPTS);
  const TR = sb.TR;
  const old = TR.story2.items()[2];   // the island's title-less question pin
  eq(old.title, undefined, "loading never writes a title onto an old pin");
  const html = TR.story2._itemHtml(old, 2);
  at(html, "<strong>How was registration?</strong>",
    "an old pin keeps the question title in the story");
  assert(html.indexOf("Registration is the pain point") === -1,
    "the insight chain is never applied retroactively in the story");
});

run("D2: the PPTX/PNG paths carry the pin title (plumbing in 30_story)", () => {
  at(STORY_SRC, "title: item.title || null }));   // D2: slide title = pin title",
    "slidesFor passes the pin title to slideForModel");
  at(STORY_SRC, "title: item.title || null });   // D2: card title = pin title",
    "itemCardSvg passes the pin title to cardSvg");
  at(STORY_SRC, "title: item.title || null   // D2: PNG title = pin title",
    "downloadPng passes the pin title");
});

/* ---------------- D2: 29_export inherits the pin title ---------------- */

function exporterSandbox() {
  const sb = { console, TextEncoder };
  sb.globalThis = sb;
  sb.window = sb;
  vm.createContext(sb);
  for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js",
    "14_pptx_parts.js", "23_render.js", "23z_charts.js", "23za_trend.js",
    "23y_xlsx.js", "29_export.js"]) {
    load(sb, f);
  }
  sb.TR.AGG = { project: { name: "P", wave: "W2" } };
  return sb;
}
const EXPORT_MODEL = {
  code: "Q2", title: "Flat single-select", short_label: "Flat short",
  columns: [{ label: "Total", base: 100 }],
  rows: [{ kind: "category", label: "Yes", cells: [{ pct: 60 }] }]
};

run("D2: PPTX slide title = pin title when set, short_label/title default when not", () => {
  // WP1 (boardroom spec): the question code no longer prefixes the slide title
  // — it moves to the subtitle ("Q2 · <question text>") and the footer.
  const exporter = exporterSandbox().TR.exporter;
  const withTitle = exporter.slideForModel(EXPORT_MODEL, "",
    { table: false, title: "Registration is the pain point" });
  at(withTitle.xml, "Registration is the pain point", "insight title on the slide");
  at(withTitle.xml, "Q2 · Flat single-select", "code + question text in the subtitle");
  assert(withTitle.xml.indexOf("Q2 — ") === -1, "code no longer prefixes the title");
  assert(withTitle.xml.indexOf("Flat short") === -1, "default title replaced");
  const without = exporter.slideForModel(EXPORT_MODEL, "", { table: false });
  at(without.xml, "Flat short", "title-less pins keep the existing default");
});

run("D2: image-deck/PNG card title = pin title when set, default when not", () => {
  const exporter = exporterSandbox().TR.exporter;
  const withTitle = exporter.cardSvg(EXPORT_MODEL, "",
    { includeTable: false, title: "Registration is the pain point" });
  at(withTitle, "Q2 — Registration is the pain point", "insight title on the card");
  const without = exporter.cardSvg(EXPORT_MODEL, "", { includeTable: false });
  at(without, "Q2 — Flat short", "title-less pins keep the existing default");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
