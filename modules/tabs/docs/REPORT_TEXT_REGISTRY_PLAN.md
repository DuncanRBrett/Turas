# Authored report text for Tabs v2 — feasibility and plan

Status: proposal, nothing built. Written 2026-08-17.

The ask: the explanatory text in the v2 report should come from a file Duncan
edits in a GUI, the way callouts already do for brand/confidence/conjoint —
not from string literals inside the renderer, and not written by a model at
build time.

---

## 1. What exists today

**The callout system** (`modules/shared/lib/callouts/`) is three parts:

| Part | File | What it does |
|---|---|---|
| Store | `callouts.json` (105 KB) | `module → key → {title, text, context, page}`, plus `_meta.pages` listing the pages each module has |
| Reader | `callout_registry.R` (194 lines) | `turas_callout(module, key)` → styled HTML; `turas_callout_text()` → raw entry; cached, with a `TURAS_ROOT`-aware path search |
| Editor | `run_callout_editor_gui.R` (826 lines) | Shiny app, launched from `launch_turas.R` (tile `callout_editor`). Filter by module + page, edit title/text/page, live preview, add, delete. Writes `callouts.json` with `jsonlite::write_json(pretty, auto_unbox)` |

Current contents: brand 27 entries, confidence 11, keydriver 5, catdriver 5,
weighting 3, pricing 3, conjoint 3, maxdiff 2, segment 2, tracker 2, **tabs 3**.

The three `tabs` entries (`significance_testing`, `dashboard_overview`,
`composite_scores`) are **orphaned** — nothing reads them. `grep turas_callout`
over `modules/tabs` returns no production hits. Tabs never adopted the system,
and tabs no longer has an R-built HTML report at all (`modules/tabs/lib/` has
`html_report_v2` only).

**How v2 is built.** `build_report_v2.R` inlines CSS, 42 JS modules and four
JSON data islands into `assets/template.html` by replacing `{{TOKEN}}`s in a
single pass. Adding a fifth island is a two-line change plus a token in the
template. There is already precedent for authored text riding in:
`data_layer_writer.R` puts `proj$report_meta` (analyst, company, fieldwork,
`background_text`, `executive_summary`, `report_construction`) into the data
layer from the config's Comments sheet, and `32_report.js` renders it read-only.

**Where the report's words live now.** Measured by extracting string literals
from `assets/js/*.js`, dropping comments, markup-only fragments and non-prose
files (`31_selftest`, `14_pptx_parts`, `13_zip`, `03_svg`, `20_data`,
`23y_xlsx`, `24_shell`, `01_format`), then joining fragments that sit on
adjacent source lines into one block:

**~70 prose blocks (≥15 words) and ~181 short microcopy fragments, across 22
files.** The split is a heuristic — adjacency grouping splits some real
paragraphs and merges some neighbours — so treat it as sizing, not a manifest.

| Renderer file | Report surface | Prose blocks | Microcopy |
|---|---|---|---|
| `25_cards.js` | Crosstabs question cards, table legend, "Understanding the significance testing" | 11 | 11 |
| `27h_takeout_read.js` | Patterns — how the scan works, empty states | 8 | 9 |
| `27q_qualitative.js` | Qualitative — salience, hubs, withheld text | 8 | 25 |
| `32_report.js` | Report tab — About, Report construction, study slides | 7 | 13 |
| `21c_confidence.js` | "How sure can I be of these numbers?" footer | 6 | 9 |
| `27u_summary.js` | Tracking summary — pulse legend, wave-test method | 6 | 8 |
| `26_filter.js` | Audience/filter bar, weighting note | 4 | 14 |
| `27g_takeout_components.js` | Patterns — portrait tension sentences | 4 | 16 |
| `24a_reader.js` | "How to read this report" panel, plain-language significance | 3 | 10 |
| `27v_visualise.js` | Tracking visualise — band and test notes | 3 | 7 |
| `30_story.js` | Story/deck help, export choices | 3 | 15 |
| `21d_disclosure.js` | Confidentiality suppression notices | 2 | 0 |
| `23_render.js` | Cell/base notes (withheld, FPC, effective base) | 1 | 8 |
| `27d_diffs.js` | Differences tab explainer | 1 | 1 |
| `27e_takeout_engine.js` | Patterns — flat-fallback wording | 1 | 2 |
| `27t_tracking.js` | Tracking empty state | 1 | 1 |
| `28a_ai.js` | AI labels + model attribution | 1 | 1 |
| `29_export.js` | Export/PPTX affordances | 0 | 15 |
| `27_views.js` | Dashboard notes | 0 | 9 |
| others (`23za`, `27k`, `30x`) | misc | 0 | 7 |

---

## 2. The watermark objective is already met

Nothing needs building for this. `enable_ai_insights` defaults to `FALSE`
(`crosstabs_config.R:409`, template default `"FALSE"` at
`generate_config_templates.R:692`). With it off, `data_layer_writer.R:1089`
returns `NULL`, so `TR.AGG.ai` is absent and every accessor in `28a_ai.js`
returns `""` — no "AI-assisted insight" head, no "AI-assisted key findings"
card, no model-attribution paragraph.

The remaining mention of AI in a stock report is one paragraph of the About
card's *Report construction* note (`32_report.js:constructionHtml`), which is
already Duncan's own authored wording, and which a study can replace wholesale
via `_REPORT_CONSTRUCTION` in the config's Comments sheet.

So this work is about **authorship control**, not about removing watermarks.

---

## 3. Is it feasible?

Yes, and the mechanism is the one already in the repo. What does **not** carry
over is `turas_callout_html()` — v2 has its own CSS and its own collapsible
callout pattern (`callout-ico`, the shared "How to read" panel), and no
`t-callout` class anywhere. Only the **store** and the **editor** are reused.

Proposed shape:

1. **Catalogue.** Tabs v2 text lives in `callouts.json` under the `tabs`
   module, keyed by surface: `cards.sig_explainer`, `reader.legend.arrows`,
   `confidence.footer.fpc`, `report.construction.default`, and so on. The
   catalogue is **the source of truth**, seeded verbatim from today's wording —
   nothing is rewritten during extraction, so the report reads identically the
   day it lands.
2. **Injection.** `build_report_v2.R` gains a `{{DATA_TEXT}}` island (or the
   dictionary rides in the existing agg island — one line either way; the
   separate island keeps it diffable and keeps text out of the data payload).
   R reads the `tabs` block from `callouts.json` at build time.
3. **Access.** A small `TR.txt(key, vars)` in a new `02_text.js`: looks the key
   up, substitutes `{tokens}`, returns the string. Trusted HTML — inline
   `<strong>`/`<li>` in authored text renders, as it does in brand callouts.
4. **No silent gaps.** A key the renderer asks for but the catalogue lacks is a
   **build-time TRS refusal** (`CFG_REPORT_TEXT_MISSING`, naming the key), not a
   blank in a client report. Enforced by a manifest of keys the renderer
   declares, checked before the HTML is written.
5. **Placeholder contract.** The manifest also declares which `{tokens}` each
   key may use. A token in the catalogue that the key doesn't declare, or a
   declared-required token missing from the text, refuses the build. This is
   what stops a typo in the editor reaching a client.
6. **Editor.** Works as-is once `_meta.pages.tabs` lists the real v2 tabs
   (today it says only `Crosstabs`, `Summary`). One UI question is worth
   settling before extraction: with ~70–250 tabs keys the card list is long, so
   the page filter has to be genuinely useful — key naming should mirror it.

### What must not move, and why

- **Generated narrative** — the Patterns tension sentences
  (`27g_takeout_components.js:portraitTension`) and the plain-language
  significance sentences (`24a_reader.js`) are assembled from branching logic
  around live cell values. Externalising them needs a template language with
  conditionals, and the payoff is small because they are **already editable in
  the report** and persisted (`27k_takeout.js` — "your wording is saved", carried
  through the JSON export/import). Leave them. If the wording still grates, the
  cheap move is to externalise only the fixed stems and connectors as a phrase
  table.
- **`conf.labels()` terminology** (`21c_confidence.js:50-63`) — the
  standard/softened pair ("margin of error" vs "precision range") has an R twin
  in `modules/confidence/R/sampling_labels.R` that also feeds Excel. Moving one
  side invites drift. Keep the map in code; catalogue entries reference
  `{precision_term}` and friends so one authored sentence serves both framings.
- **Conditions stay in code.** Only words move. `priorWavesArePublished()`,
  `p.weighted`, the disclosure gate — the logic deciding *whether* a sentence
  renders stays where it is.

### Two costs beyond typing

- **The node test suite.** 33 `.mjs` files boot the renderer in a `vm` sandbox
  with a hand-built `TR`; there are 238 assertions matching string literals of
  15+ characters, some of them on prose that would become editable (e.g.
  `indexOf("published figures are computed in R")`,
  `indexOf("stable to about ±")`). Every assertion touching moved prose must
  assert against the catalogue value or a key/DOM attribute — never a wording
  literal — or the suite goes red the first time Duncan edits a sentence. The
  boot helpers need to load the catalogue (or a fixture) too.
- **Extraction is semi-manual.** Paragraphs are split across concatenated
  fragments interleaved with values and conditionals; there is no mechanical
  sed. Budget per surface, verifying the rendered report each time.

### Operational caveat

Reports are self-contained. Editing text changes nothing in an HTML file that
already exists — it applies at the **next regeneration**, which is Duncan's job
via `launch_turas()`. Same as brand today.

---

## 4. Decisions — settled 2026-08-17 (Duncan)

1. **Only the interpretive blocks move.** The ~181 microcopy fragments
   (aria-labels, toasts, button text, chart-error strings) stay in code.
2. **The registry is platform-wide.** Project-specific wording is an override
   in the crosstab config file, not a second registry and not a second copy of
   the text.
3. **Reader report and Excel notes are out of scope.** Same mechanism when
   their turn comes.
4. **The three orphaned `tabs` keys**: fold `significance_testing` into the new
   `cards.sig_explainer`; delete `dashboard_overview` and `composite_scores`,
   whose text no longer describes what v2 shows.
5. **Nothing the reader can already edit in the HTML goes in the editor.**
   Insight boxes, the Patterns takeaway seeds, hub insights, story notes — a
   platform default for text the reader overwrites in the report is pointless.
   This makes the "generated narrative stays in code" rule above a hard line,
   not a judgement call.
6. **No backwards compatibility.** Reports generated from this branch onward
   use the catalogue; existing HTML files are untouched and stay as they are.
   There is therefore no code-side fallback wording — the catalogue is the only
   source, and a build without it refuses.

---

## 4a. Risk

Ranked by what would actually hurt. Each has a mitigation that is part of the
build, not an afterthought.

**1. A malformed or truncated `callouts.json` stops report generation.**
Removing the code-side fallback means the catalogue is a hard build dependency
for every project, including ones mid-flight. The editor rewrites the whole
file with a plain `jsonlite::write_json` — no temp-file-and-rename, no backup —
so a crash or a full disk mid-save leaves a truncated file and every subsequent
report build refuses.
*Mitigation:* make the editor write atomically (temp file, parse it back,
then rename) and keep the last N saves as timestamped backups. Half a day, and
it protects the other ten modules that already depend on this file.

**2. The first editor save churns the entire file.** Verified, not predicted: a
no-op round trip through the editor's own `write_registry()` rewrites 100+ lines
of *other modules'* entries, escaping every `/` as `\/`. Functionally identical
after parsing, but it makes the diff unreadable, and with sessions running in
parallel it is exactly the shape of accident that sweeps someone else's work
into a commit.
*Mitigation:* normalise the file once on this branch so the on-disk form matches
what the editor writes, and add a test asserting a read-write round trip is
byte-identical.

**3. A wording edit turns the test suite red.** Baseline today: 33 `.mjs` files,
**854 assertions, all passing**. 238 of those assertions match string literals
of 15+ characters, and some are on prose that becomes editable.
*Mitigation:* the rule is that no test may assert on authored wording — assert
on the catalogue value or a DOM key. Enforced by a **catalogue mutation check**
run at the end of every stage: rebuild with every catalogue value suffixed with
a marker, and the suite must still pass. If it fails, a test is still pinned to
words Duncan is entitled to change.

**4. Authored HTML breaks the page.** The text is trusted and rendered as HTML,
so a forgotten `</strong>` or a stray `<div>` typed in the editor can distort a
client report. Script injection is not the concern (the island escaping already
neutralises `<`); layout damage is.
*Mitigation:* validate tag balance and reject unknown tags at build time, with a
whitelist (`strong em b i br p ul ol li h3 h4 span code`). Same check in the
editor's preview so it is caught while typing.

**5. Silent behaviour change during extraction.** Paragraphs are interleaved
with conditionals and live values; it is easy to "tidy" a condition while moving
words.
*Mitigation:* each stage is a **pure refactor, verified by diff** — generate a
report from a fixture config before and after, and the rendered HTML must be
identical apart from the new text island. That is a real gate, not an eyeball.

**6. Placeholder typos reaching a client.** `{levl}` instead of `{level}` renders
literally in a deliverable.
*Mitigation:* the key manifest declares the tokens each key may use; unknown or
missing tokens refuse the build, naming the key.

**7. Wording drift against the Excel workbook.** Some HTML explainers restate
what the stats pack says in the workbook. Editing one no longer changes the
other.
*Mitigation:* accepted knowingly under decision 3; the affected keys are noted
in the catalogue's `context` field so it is visible when editing.

**8. Encoding.** The text carries ▲▼ ± – — “ ” ² and emoji. It now makes an
extra trip through the editor, `write_json`, R, and the HTML writer.
*Mitigation:* a round-trip test on a key holding the full character set.

Not a risk, for the record: report size (the whole catalogue is ~25 KB), and
existing reports (untouched — the change only affects new builds).

---

## 4b. What the plan was missing

Six things worth adding, all of which serve "something I can add intuitively to
reports going forward".

**a. A way to see which key produced which block.** Editing 70 entries by
guesswork is unworkable. The R callouts already solve this — `turas_callout_html`
tags each block with `module / key`. v2 should have an author-only **"show text
keys" toggle** that overlays the catalogue key on every authored block, off by
default and never present in pins, exports or saved copies. Without this the
editor is a list of keys with no map back to the page.

**b. Empty means hidden.** An empty `text` value should render nothing at all,
so Duncan can switch off an explanatory block he doesn't want without touching
code — and without deleting the key, which would refuse the build. Deleting is
for keys that no longer exist in the renderer; emptying is for "not on this
report".

**c. The config override needs to be discoverable.** Under decision 2, overrides
live in the crosstab config. The intuitive form is a `ReportText` sheet with
`Key | Text` that `generate_config_templates.R` **emits pre-populated with the
platform text**, so opening a new project's config shows the wording that will
be used and the analyst edits the cell for that study only. A blank cell means
"use the platform text". This is what makes the whole thing part of the normal
config workflow rather than a separate thing to remember.

**d. Adding a new block later must be a two-step job.** Documented as: add the
key to the manifest with its tokens, call `TR.txt('key')` where it renders. If
the catalogue lacks it, the build refuses and names it — so the loop closes
itself. Written into the module's technical manual, not just this plan.

**e. Editing a whole report's text has no preview.** The editor's live preview
shows brand-callout styling, not v2's. Cheapest honest answer: edit, regenerate
the report, look. Worth saying out loud so it isn't a surprise.

**f. Committing the edits.** `callouts.json` is in git but the editor just writes
the file; edits sit uncommitted until someone commits them. Worth a line in the
editor UI and a habit: text changes are part of the repo, not local state.

---

## 5. Staging

Branch: `feature/tabs-v2-text-registry`, cut from `main` at f99b8e65.

Each stage ends with four things, in this order:

1. the node suite green (baseline: 33 files, 854 assertions, 0 failures);
2. the **mutation check** — rebuild with every catalogue value marked, suite
   still green, proving no test is pinned to authored wording;
3. a **before/after render diff** on a fixture project showing no change apart
   from the text island;
4. the loop closed by hand — change a word in the editor, regenerate, see it
   move in the report.

- **Stage 0 — plumbing and safety.** Editor: atomic write, backups, round-trip
  normalisation of `callouts.json`. Renderer: `{{DATA_TEXT}}` island,
  `TR.txt()` in a new `02_text.js`, the key manifest with its placeholder
  contract, build-time refusal on a missing key or bad token, the HTML tag
  whitelist, the empty-means-hidden rule, the "show text keys" author toggle,
  test-harness catalogue loader, `_meta.pages.tabs` filled in with the real v2
  tabs. One surface moved end to end as the proof: the About card's Report
  construction block.
- **Stage 1 — the reading layer.** "How to read this report" (`24a_reader.js`),
  "Understanding the significance testing" and the table legend (`25_cards.js`),
  "How sure can I be of these numbers?" (`21c_confidence.js`). The blocks most
  already in Duncan's voice, and the ones clients read most.
- **Stage 2 — Tracking.** `27u_summary.js`, `27v_visualise.js`,
  `27t_tracking.js`.
- **Stage 3 — Patterns and Differences.** `27h_takeout_read.js`,
  `27d_diffs.js`, the fixed stems only in `27g`/`27e`.
- **Stage 4 — Qualitative.** `27q_qualitative.js`.
- **Stage 5 — remaining Report tab, filter/audience, disclosure and base notes.**
  `32_report.js`, `26_filter.js`, `21d_disclosure.js`, `23_render.js`.
- **Stage 6 — the per-project override.** `ReportText` sheet in the crosstab
  config, emitted pre-populated by `generate_config_templates.R`, blank cell =
  platform text. Same validation as the catalogue.
- **Stage 7 — documentation.** How to add a new authored block, how the
  override works, what refuses a build and why — into
  `11_DATA_CENTRIC_REPORT_V2.md` and the user manual, not left in this plan.

Story/export affordances (`30_story.js`, `29_export.js`) are microcopy and stay
out under decision 1 unless Duncan wants them.
