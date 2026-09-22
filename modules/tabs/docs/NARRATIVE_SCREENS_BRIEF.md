# Narrative screens: the executive summary from a Word document

Build brief, written 22 September 2026 after a planning session with Duncan.
Design decisions are made. The build session implements, it does not redesign.

## The problem

The tabs v2 report shows the Background and Executive summary as two cards on
the Report tab. Each comes from one cell in the config workbook's Comments
sheet (`_BACKGROUND`, `_EXECUTIVE_SUMMARY`), read in
`modules/tabs/lib/crosstabs/crosstabs_config.R` (around line 1118, last row
wins) and carried to the island as `project.report_meta` by
`modules/tabs/lib/data_layer_writer.R` (around line 340).

Three things are wrong with it today, all verified against the SACS 2026
report on 22 September 2026:

1. The card renders one escaped paragraph per line and honours nothing else
   (`report.sectionsHtml` in `assets/js/32_report.js`). Bullets typed as `* `
   show as literal asterisks. The study-slide renderer in the same file,
   `report.slideBodyHtml`, already honours paragraphs and bullets.
2. Pinning the card stores a frozen copy of its HTML (`TR.story2.pinSnapshot`
   via `shell.snapshotCard` in `24_shell.js`). The story lives in localStorage
   per project, so after the text is edited and the report regenerated, the
   pinned slide still shows the old text. Study slides avoid this by pinning
   by reference (`story2.pinSlide(idx)` in `30_story.js`).
3. The deck export of that pin is a one-column list of plain lines
   (`snapshotMatrix` in `30_story.js`). Present mode shows the frozen HTML
   in a box.

The goal is an executive summary that is attractive, automated, survives
regeneration, is written by anyone in a tool they already know, and moves
Turas toward not needing a PowerPoint hand-over. The ASSA annuity deck
(18 slides: title, intro, method, sample, two summary slides, eleven
finding slides each with commentary plus one small table or chart) is the
reference for what the output must be able to carry.

## Decisions already made

- The narrative is written in a Word document in the project folder. One
  new Settings key points to it, path relative to the config file, the same
  way AddedSlides `image_path` resolves (`load_qualitative_sheet`,
  `crosstabs_config.R` line 1448). Proposed key name `narrative_file`.
- Word covers both Background and Executive summary. When the key is blank
  the two Comments cells are used exactly as today, so no existing project
  changes behaviour. When the key names a file that does not exist, the run
  refuses (TRS, `IO_` prefix) with the resolved path printed to the console.
- Each Heading 1 in the document is one screen. Screens appear on the
  Report tab as cards with a pin button, exactly like study slides. A pin is
  a reference, never a copy, so a regeneration refreshes it. Once pinned, a
  screen sorts like any other story item.
- The reference is the heading text, not the position. Reordering sections
  in Word keeps each pin on its section. A deleted section leaves its pin
  showing "unavailable", the way a pin to a removed question does today.
  Duplicate headings get an occurrence suffix.
- Screens-first default: when a story is empty and not owned (see the
  `_owns` marker in `story2.load()`), the screens are seeded at the front in
  document order. After that they are ordinary pins. A new section added in
  Word is pinned from the Report tab by hand; it does not insert itself.
- The cover (`html_report_v2_cover`) shows the first screen, read from the
  island, never from a pin.
- The Word file is for words. Charts and result tables are Turas pins placed
  after the screen they support. Native Word charts are not imported.
- Rendering is built once, as blocks to HTML, and used by the Report tab,
  the cover, the story card, Present and the deck. No surface keeps its own
  paragraph splitter.
- The existing export of all pins to PPTX is untouched. Every current pin
  kind exports exactly as it does today. The deck work in this build is
  additive only: one new slide type for a pinned narrative screen, and the
  cover slide reading its summary text from the new source.

## Scope: the fixed list

This list is the scope. Clean and simple beats complete. Anything not on
it is unsupported, named as such in the console at run time, and not
half-supported.

Honoured from Word:

- Heading 1: new screen, its text is the title.
- Heading 2: sub-heading inside the screen.
- Normal paragraphs, with bold and italic runs kept.
- Bulleted and numbered lists, with nesting level.
- Quote style paragraph: a callout band.
- Pictures: embedded as base64 the way AddedSlides pictures are, at the
  point where they sit in the text.
- Simple tables: text cells by row and column. No merged cells, no fills.

Ignored with a console line naming what was skipped and how many: text
boxes, shapes, SmartArt, native charts, columns, footnotes, comments,
tracked changes, headers and footers. A document with no headings at all is
one screen titled "Executive summary".

Not in this build, deliberately: placeholders in the text that pull a live
figure or chart from the data; side-by-side layout of a screen with its
evidence; matching headings to story dividers; any in-browser editing of
the narrative.

## What exists to copy

- Word reading: `officer` 0.7.0 is in `renv.lock` and
  `modules/AlchemerParser/R/03_parse_word_doc.R` already uses
  `officer::read_docx` and `officer::docx_summary`. That summary gives
  paragraphs with style names, list levels and table cells. It does not
  list pictures; picture positions need the document XML and its
  relationships (xml2 is in the lockfile). Treat picture extraction as the
  one piece of the reader with real unknowns and prove it on the fixture
  before building the rest of the reader around it.
- Authored, pinnable, read-only content: the AddedSlides path end to end.
  `load_qualitative_sheet` (R), `proj$slides` in `data_layer_writer.R`,
  `report.studySlidesHtml` and `report.slideBodyHtml` (32_report.js),
  `story2.pinSlide` and the `kind === "slide"` branches of the story card
  and `renderPresent` (30_story.js), and the slide branch of the deck.
- Settings keys are whitelisted three times in `crosstabs_config.R`: the
  known-keys lists near lines 999 and 1908 and the `build_config_object`
  fields near line 311 (`html_report_v2_cover` is the pattern). A key read
  downstream is NULL until all three know it. Test at that layer, not with a
  hand-built list.
- Deck slide types in `assets/js/29_export.js`: `coverSlide`,
  `dividerSlide`, `quoteSlide`, `titleSlide`. There is no text-and-bullets
  slide; this build adds one.
- UI strings go through `TR.txt` and `assets/text_manifest.json`;
  `tests/mutate_text_check.mjs` guards that.

## Stages, each ending in a check that can fail

Stage 1, the reader. R only. A function that takes the document path and
returns a list of screens, each `{id, title, blocks}`, with the block
kinds above. A fixture `.docx` in the tabs test fixtures exercising every
honoured feature and every ignored one, plus a headingless document and a
missing file. Carried on the island as `project.narrative`. When no file is
set, the two Comments cells are converted to the same shape (two screens,
paragraphs and bullets only) so every downstream surface has one input.
Check: `testthat::test_dir("modules/tabs/tests")` green, with the new
tests asserting the exact block list from the fixture, and the refusal for
the missing file.

Stage 2, the surfaces. JavaScript. One `TR.narrative.blocksHtml()` used by
the Report tab cards, the cover's first screen, the story card, and Present.
A new story item kind `narrative` referenced by screen id, with the
unavailable fallback. Present lays a screen out like a slide: brand-coloured
title, first paragraph as a lead, bullets in two columns when long, callout
band, picture beside the text when present. The old `sectionsHtml`,
`coverParas` and the exec text in `coverSlideFor` are replaced by the same
function, not left alongside. Check: the node suites, run one file at a
time as `node modules/tabs/lib/html_report_v2/tests/<name>_tests.mjs`.
`cover_tests.mjs` line 255 asserts today's exact paragraph HTML and will
change; `report_tests`, `state_tests`, `exports_tests`, `study_slides_tests`
and `shell_snapshot_tests` are the others most likely touched.

Stage 3, the deck and the seed. A text-and-bullets slide in `29_export.js`
built from the same blocks, with pictures and simple tables. The
screens-first seeding of an empty, unowned story. The template row and the
docs (`06_TEMPLATE_REFERENCE.md`, `04_USER_MANUAL.md`). Check:
`exports_tests.mjs`, `pptx_style_tests.mjs`, `pptx_visual_qa.mjs`, then
Duncan regenerates SACS 2026 through `launch_turas()` with a Word file of
the current SACS summary and eyeballs Report tab, cover, story, Present and
the exported deck. Nothing is done until that eyeball.

## Rules that apply

- No `stop()`. TRS refusals with console output, per `CLAUDE.md`.
- `read.xlsx(..., skipEmptyRows = FALSE)` for any workbook read.
- No em dashes in any string that reaches Duncan or a client: labels,
  template text, console lines, commit messages.
- No new dependency. `officer` and `xml2` are already in the lockfile.
- Edit surgically. Do not rewrite files where an edit does.
- Do not widen the scope. If a Word feature outside the list looks easy,
  it still goes on the ignored list with a console line.
- Check the branch and `git status --short` before the first edit. Work on
  a feature branch.

## Open items the build session decides and notes

- Exact key name and template wording for `narrative_file`.
- Whether the Quote style is the only callout trigger or whether an italic
  single-line paragraph also qualifies. Recommendation: Quote style only.
- How a Heading 1 named "Background" or "Executive summary" maps onto the
  About card fields that read `report_meta` today. Recommendation: the
  first screen is the cover text whatever it is called; About keeps reading
  `report_meta`, which the fallback still fills.
- Picture size cap on the island, following whatever AddedSlides does.

## Model and effort

Design was done on Fable in this session. Implement on Opus 5 at high
effort with the fable-method skill, one session per stage, suites run per
stage. Independent review on Opus 5 in a fresh session after stage 3.
Escalate to Fable only if the review keeps finding things or picture
extraction turns out to be much harder than the fixture suggests.
