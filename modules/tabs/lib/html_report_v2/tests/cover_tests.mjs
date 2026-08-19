#!/usr/bin/env node
/**
 * Exec-summary cover gate (READER_EXPERIENCE_PLAN bundle D) — three contracts:
 *
 * G  Opt-in: the cover exists only where the study asked for it. The config's
 *    html_report_v2_cover rides the island as project.cover and gates every
 *    cover behaviour ahead of the saved-copy and content checks, so a report
 *    built from a config that never mentions it behaves exactly as reports did
 *    before the cover was written.
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
  // Every contract below is "GIVEN the study asked for a cover" (config
  // html_report_v2_cover -> project.cover), so the sandbox opts in by default
  // and the gate itself is asserted on its own. opts.cover === false opts out.
  TR.AGG = {
    project: Object.assign({ cover: opts.cover !== false },
      opts.project || { name: "CCS 2026", client: "CCS", wave: "Wave 2" }),
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

/* ---------------- the config gate (html_report_v2_cover) ---------------- */

run("gate: without html_report_v2_cover there is no cover, whatever else is true", () => {
  // The strongest form of the contract: the combination that WOULD open a cover
  // (saved copy + story pins + authored sections) still does not, because the
  // study never asked for one. A config that never mentions the setting emits no
  // project.cover, so every report built before this existed behaves as it did.
  const off = coverSandbox({ cover: false,
    userState: { story: [snap("A finding")] },
    project: { name: "P", report_meta: { exec_summary: "The findings that matter." } } });
  eq(off.TR.reader.coverAvailable(), false, "opted out -> never a cover");
  // and the landing / header link follow the same gate
  eq(shellSandbox(false).TR.shell.landingTab("", "takeout"), "takeout",
    "opted out -> today's landing");
  // the same sandbox with the study opted in DOES open a cover — so the test
  // above is failing on the gate, not on missing content
  const on = coverSandbox({ userState: { story: [snap("A finding")] },
    project: { name: "P", report_meta: { exec_summary: "The findings that matter." } } });
  eq(on.TR.reader.coverAvailable(), true, "opted in + saved + content -> cover");
});

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
  // NB the section headings are inserted raw, so the literal is "&", not "&amp;".
  // This assertion used to name the escaped form and so could never fail.
  assert(html.indexOf("Background & method") === -1,
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

run("D1: findings default to the first 5, in story order", () => {
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

run("D2: default-title chain — headline > surface default; the insight never titles", () => {
  const sb = pinSandbox();
  const TR = sb.TR;
  TR.insights.set("Q7", "Course choice splits the campuses. More detail here.");
  TR.d2.state.activeQ = "Q8"; TR.story2.pinCurrent();
  TR.d2.state.activeQ = "Q7"; TR.story2.pinCurrent();
  TR.d2.state.activeQ = "Q6"; TR.story2.pinCurrent();
  const items = TR.story2.items();
  eq(items[0].title, "Registration is the pain point", "q.headline wins");
  eq(items[1].title, "",
    "a stored insight does NOT title the pin — the pin body prints it in full");
  eq(TR.story2.pinTitle(items[1]), "Which course?",
    "the display chain falls to the question, not the insight");
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

// Priority comments ride the same question pin as the numbers: the block sits
// between the table and the editable commentary, and an old pin (no comments
// flag) renders exactly as before.
run("priority comments render inside the pinned question card", () => {
  const sb = pinSandbox();
  const TR = sb.TR;
  TR.qual = { priorityQuotes: () => [{ text: "Invoices are easy to read",
    q: "Any niggles?", tags: ["Paarl"], sentiment: "pos" }],
    priorityBlockHtml: (qs) => '<div class="si-quotes">' +
      qs.map((x) => "<blockquote>" + x.text + "</blockquote>").join("") + "</div>" };
  TR.d2.state.activeQ = "Q8";
  TR.story2.pinCurrent({ chart: false, table: true, insight: true, comments: true });
  const item = TR.story2.items()[0];
  eq(item.flags.comments, true, "the flag is stored on the pin");
  const html = TR.story2._itemHtml(item, 0);
  at(html, "Invoices are easy to read", "the verbatim renders in the story card");
  assert(html.indexOf('class="si-quotes"') < html.indexOf('class="si-note"'),
    "quotes sit above the analyst's commentary box");
  eq(TR.story2._quotesFor(item).length, 1, "quotesFor resolves the pin's comments");

  // the same pin without the flag asks the qual module for nothing
  const off = Object.assign({}, item, { flags: { table: true, insight: true } });
  eq(TR.story2._quotesFor(off).length, 0, "no flag -> no comments, no call-through");
  assert(TR.story2._itemHtml(off, 0).indexOf("si-quotes") === -1,
    "an older pin renders unchanged");
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


/* ---------------- I20: stale qualitative pins never render frozen quotes --- */

run("I20: a qualitative pin goes stale when any frozen quote is no longer published", () => {
  const sb = coverSandbox({});
  const TR = sb.TR;
  TR.qual = { textPublished: (text) => text === "still here" };
  const freshPin = { kind: "snapshot", source: "qualitative", title: "Hub",
    context: "", html: "<div>Q</div>", lines: [], note: "",
    quotes: [{ text: "still here", q: "Q1" }] };
  const stalePin = { kind: "snapshot", source: "qualitative", title: "Hub",
    context: "", html: "<div>“withheld words”</div>", lines: [], note: "",
    quotes: [{ text: "still here", q: "Q1" }, { text: "withheld words", q: "Q1" }] };
  eq(TR.story2._qualPinStale(freshPin), false, "every quote published -> not stale");
  eq(TR.story2._qualPinStale(stalePin), true, "one withheld quote -> stale");
  const nonQual = { kind: "snapshot", source: "card", html: "<div>x</div>", quotes: [] };
  eq(TR.story2._qualPinStale(nonQual), false, "non-qual snapshots are never gated");
});

run("I20: a stale pin's body renders the notice, never the frozen html", () => {
  const sb = coverSandbox({});
  const TR = sb.TR;
  TR.qual = { textPublished: () => false };   // disclosure tightened: nothing published
  const pin = { kind: "snapshot", source: "qualitative", title: "Hub",
    context: "", html: "<div>“the withheld verbatim”</div>", lines: [], note: "",
    quotes: [{ text: "the withheld verbatim", q: "Q1" }] };
  const body = TR.story2.itemBodyHtml(pin);
  assert(body.indexOf("the withheld verbatim") < 0, "frozen quote text must not render");
  assert(body.indexOf("no longer publishes") >= 0, "the stale notice renders instead");
});

run("I20: a copy with NO qual island treats qualitative pins as stale", () => {
  const sb = coverSandbox({});
  const TR = sb.TR;
  TR.qual = undefined;   // island absent from this copy
  const pin = { kind: "snapshot", source: "qualitative", title: "Hub",
    context: "", html: "<div>“secret”</div>", lines: [], note: "",
    quotes: [{ text: "secret", q: "Q1" }] };
  eq(TR.story2._qualPinStale(pin), true, "no island -> frozen quotes must not surface");
});

/* -------- 2026-08-19: order, the configurable pin count, slide thumbnails ---- */

const manyPins = (n) => ({ userState: { story:
  Array.from({ length: n }, (_, i) => snap("F" + (i + 1))) } });

run("sections read background BEFORE executive summary (as the Report tab does)", () => {
  // Duncan's order. The Report tab's own SECTIONS list has always been
  // [background, exec]; the cover was the one surface disagreeing with it.
  const sb = coverSandbox({ userState: { story: [] },
    project: { name: "P", report_meta: {
      background: "How it was done.", exec_summary: "What we found." } } });
  const html = sb.TR.reader.coverHtml();
  const bg = at(html, "Background & method", "background section");
  const ex = at(html, "Executive summary", "exec section");
  assert(bg < ex, "background must render above the executive summary");
  at(READER_SRC, '[["background", "Background & method"], ["exec", "Executive summary"]]',
    "the order is the literal in coverHtml, not an accident of the data");
});

run("limit: absent cover_findings keeps the default of 5", () => {
  const sb = coverSandbox(manyPins(9));
  eq(sb.TR.reader.coverLimit(), 5, "default when the study set no count");
  eq(sb.TR.reader.coverFindings().length, 5, "five findings");
  eq(sb.TR.reader.coverEvidence().length, 9, "all nine still visible to the count line");
});

run("limit: a configured number is honoured", () => {
  const sb = coverSandbox(manyPins(9));
  sb.TR.AGG.project.cover_findings = 8;
  eq(sb.TR.reader.coverLimit(), 8, "eight");
  eq(sb.TR.reader.coverFindings().map((f) => f.title).slice(-1), ["F8"], "up to the eighth pin");
  eq(count(sb.TR.reader.coverHtml(), 'class="cf-title"'), 8, "eight findings rendered");
});

run("limit: 0 means ALL — every pin, however many", () => {
  const sb = coverSandbox(manyPins(14));
  sb.TR.AGG.project.cover_findings = 0;
  assert(sb.TR.reader.coverLimit() === Infinity, "0 is the no-limit sentinel");
  eq(sb.TR.reader.coverFindings().length, 14, "all fourteen pins");
  const html = sb.TR.reader.coverHtml();
  eq(count(html, 'class="cf-title"'), 14, "fourteen findings rendered");
  assert(html.indexOf("pinned findings") === -1, "nothing held back -> no count line");
});

run("limit: junk on the island falls back to 5 rather than showing nothing", () => {
  for (const bad of [undefined, null, "", "lots", -3, 0.4]) {
    const sb = coverSandbox(manyPins(9));
    sb.TR.AGG.project.cover_findings = bad;
    eq(sb.TR.reader.coverLimit(), 5, "fallback for " + JSON.stringify(bad));
  }
});

run("no silent truncation: the cover says how many of how many it shows", () => {
  const sb = coverSandbox(manyPins(12));
  const html = sb.TR.reader.coverHtml();
  at(html, "Showing 5 of 12 pinned findings", "the count line states both numbers");
  // client-facing surface: the numbers, never an operator's config key
  assert(html.indexOf("html_report_v2_cover_findings") === -1,
    "no config setting name on a page a client opens");
  at(CSS, ".cover-more {", "and the line is styled rather than raw");
  // and it disappears the moment nothing is held back
  const all = coverSandbox(manyPins(3));
  assert(all.TR.reader.coverHtml().indexOf("pinned findings") === -1,
    "three pins under a limit of five -> no count line");
});

run("slide pins get the fit-whole thumbnail, tables keep the cropped peek", () => {
  const sb = coverSandbox({ userState: {
    story: [{ kind: "slide", slide: 0, title: "Ratings map" }, snap("A table")],
    report: { sections: {}, about: {}, slides: [] } } });
  sb.TR.AGG.project.slides = [{ title: "Ratings map",
    image: "data:image/png;base64,AAAA", text: "" }];
  const html = sb.TR.reader.coverHtml();
  eq(count(html, '<div class="cover-thumb is-slide">'), 1, "the slide pin is marked");
  eq(count(html, '<div class="cover-thumb">'), 1, "the table pin is not");
  at(html, "si-slide-img", "the slide renders its image");
});

run("CSS: .is-slide undoes the crop, the scale and the fade", () => {
  at(CSS, ".cover-thumb.is-slide { max-height: none; overflow: visible; }",
    "no 280px crop on a slide");
  at(CSS, ".cover-thumb.is-slide > * { transform: none; width: 100%; }",
    "no scale(.82)/122% on a slide body");
  at(CSS, ".cover-thumb.is-slide::after { content: none; }", "no fade-out over a picture");
  assert(/\.cover-thumb\.is-slide \.si-slide-img \{[^}]*max-height: 520px/.test(CSS),
    "the image is bounded by height so a tall slide cannot run away with the page");
  // the generic rules the slide variant overrides must still exist, or the
  // override is silently guarding nothing
  at(CSS, ".cover-thumb { max-height: 280px; overflow: hidden;", "generic crop still there");
});

run("the PPTX cover slide stays at 5 by design, and says so", () => {
  at(STORY_SRC, "Deliberately 5, and NOT html_report_v2_cover_findings",
    "the deck's fixed limit is documented at the call site");
  assert(STORY_SRC.indexOf("TR.AGG.project.cover_findings") === -1,
    "the deck cover must not read the HTML cover's setting");
});

run("'Explore the dashboard' lands at the TOP of the tab, not part-way down", () => {
  // The foot button sits far down a long cover and the tab switch does not
  // reset scroll, so the reader used to arrive mid-page on a tab they had
  // never seen.
  const sb = coverSandbox({ userState: { story: [snap("A")] } });
  const TR = sb.TR;
  let scrolled = null, tab = null;
  sb.window.scrollTo = (a, b) => { scrolled = (typeof a === "object") ? a : { top: a, left: b }; };
  sb.document = { documentElement: { scrollTop: 900 }, body: { scrollTop: 900 },
    createElement: () => ({ set innerHTML(v) { this._h = v; },
      addEventListener: (_, fn) => { sb._click = fn; } }) };
  TR.shell.goTab = (t) => { tab = t; };
  TR.shell.tabGroups = () => [{ tabs: [["dashboard"]] }];
  TR.reader.renderCover({ replaceChildren: () => {} });
  sb._click({ target: { closest: (sel) => (sel === "[data-cover-explore]" ? {} : null) } });
  eq(tab, TR.reader.exploreTarget(), "still routes to the first READ tab");
  eq(scrolled, { top: 0, behavior: "auto" }, "and scrolls the window back to the top");
  eq(sb.document.documentElement.scrollTop, 0, "documentElement reset too");
  eq(sb.document.body.scrollTop, 0, "and body, for the browsers that scroll it");
});

run("scrollToTop is safe where there is no window scrolling at all", () => {
  const sb = coverSandbox({});
  delete sb.window.scrollTo;
  sb.document = undefined;
  sb.TR.reader.scrollToTop();   // must not throw
  assert(true, "no throw without scrollTo or document");
});

/* -------- a pinned narrative section must not appear twice on the cover ----- */

// what pinning the Report tab's "Executive summary" card actually stores:
// snap-source="report", the heading as the title (32_report.js sectionsHtml)
const sectionPin = (heading) => ({ kind: "snapshot", source: "report",
  title: heading, context: "", html: "<div>the authored words</div>",
  lines: [], note: "" });

run("a pinned section is NOT repeated as a leading finding", () => {
  // The cover renders background + exec from the authored text already. Duncan
  // pinned them as well and got each one twice.
  const sb = coverSandbox({
    userState: { story: [sectionPin("Executive summary"),
      sectionPin("Background & method"), snap("A real finding")] },
    project: { name: "P", report_meta: {
      background: "How it was done.", exec_summary: "What we found." } } });
  eq(sb.TR.reader.coverEvidence().map((f) => f.title), ["A real finding"],
    "the two section pins are not evidence for the cover");
  const html = sb.TR.reader.coverHtml();
  // each section's words appear exactly once — as the section, not again below
  eq(count(html, "What we found."), 1, "exec summary rendered once");
  eq(count(html, "How it was done."), 1, "background rendered once");
  eq(count(html, 'class="cf-title"'), 1, "one finding, not three");
  assert(html.indexOf("the authored words") === -1,
    "the pin's captured html must not render as a finding thumbnail");
});

run("the count line counts findings, not the sections it drops", () => {
  // 5 real pins + 2 section pins must read "5 of 5" and so print nothing,
  // never "5 of 7" — the two it excludes are not findings being held back.
  const sb = coverSandbox({ userState: { story: [
    sectionPin("Executive summary"), snap("F1"), snap("F2"), snap("F3"),
    snap("F4"), snap("F5"), sectionPin("Background & method")] } });
  eq(sb.TR.reader.coverEvidence().length, 5, "five findings");
  assert(sb.TR.reader.coverHtml().indexOf("pinned findings") === -1,
    "nothing held back -> no count line");
});

run("only the narrative sections are dropped — every other pin source stays", () => {
  const other = ["dashboard", "patterns", "differences", "qualitative", "slide", "card"];
  const sb = coverSandbox({ userState: { story:
    other.map((src) => Object.assign(snap("P-" + src), { source: src })) } });
  eq(sb.TR.reader.coverEvidence().length, other.length,
    "no other snapshot source is treated as a section");
  eq(sb.TR.reader.isCoverSectionPin(sectionPin("Executive summary")), true, "report source");
  eq(sb.TR.reader.isCoverSectionPin(snap("x")), false, "hub snapshot is a finding");
  // a slide pin is kind "slide", not a snapshot at all
  eq(sb.TR.reader.isCoverSectionPin({ kind: "slide", slide: 0 }), false, "slide pin kept");
});

run("the cover still opens when the ONLY pins are narrative sections", () => {
  // findings are now empty, so coverAvailable has to fall through to the
  // authored-section check or the cover would vanish for this analyst.
  const sb = coverSandbox({
    userState: { story: [sectionPin("Executive summary")] },
    project: { name: "P", report_meta: { exec_summary: "What we found." } } });
  eq(sb.TR.reader.coverFindings().length, 0, "no findings");
  eq(sb.TR.reader.coverAvailable(), true, "but the authored section keeps the cover");
});

run("the PPTX cover drops section pins too, and keeps them as their own slides", () => {
  at(STORY_SRC, "isCoverSectionPin", "the deck cover reuses the reader's test");
  const sb = coverSandbox({});
  const list = [sectionPin("Executive summary"), snap("F1")];
  // the deck's own filter, exercised through the shared predicate
  const kept = list.filter((it) => !sb.TR.reader.isCoverSectionPin(it));
  eq(kept.map((f) => f.title), ["F1"], "only the real finding reaches the cover slide");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
