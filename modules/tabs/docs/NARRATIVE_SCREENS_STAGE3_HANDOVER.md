# Narrative screens: stage 3 handover

> **Stage 3 is BUILT** (22 Sep 2026): aefd0c05 (the deck slide, the seed) and
> b0f82755 (the template, the docs), on `feature/narrative-screens-reader`,
> not merged, not pushed. The list below is kept as the record of what was
> asked. What is owed now is Duncan's SACS 2026 eyeball and an independent
> review in a fresh session. Known limits a reviewer should not re-report:
> the image deck still shows a narrative pin as a text card (its words in the
> card's subtitle line), not a laid-out slide; the deck slide's height
> estimate is conservative (about 0.5 em per character plus a 6pt gap), so a
> table or last paragraph can start a "(continued)" slide when it would have
> fitted, but no words are ever dropped; the "Summary" kicker and the
> "(continued)" suffix are hard-coded, like the deck's other kickers; the
> template regeneration also brought in about ten generator rows the shipped
> binary had fallen behind on (see b0f82755).

Written 22 September 2026 at the end of the stage 2 session. Read this with
`NARRATIVE_SCREENS_BRIEF.md` (the settled design) before touching code. This
note says what exists, what was decided after the brief, and exactly what
stage 3 owes. It does not reopen any decision.

## Where things stand

Branch `feature/narrative-screens-reader`, not merged, not pushed.

| Commit | What |
|---|---|
| 482f2e0b | the brief (also on main) |
| 0a57dd58, 496fbc1c | stage 1, the R Word reader |
| 1d0530e1 | stage 2, the JS surfaces |
| a9115ea0 | fieldwork stand-in restored in the R fallback |
| 62e53eae | the cover leads with the executive summary screen |

Suites at 62e53eae: every `tests/*_tests.mjs` passes run one file at a time
(49 files; narrative 22, cover 37, report 30, exports 20). `mutate_text_check.mjs`
passes. `pptx_visual_qa.mjs` 7. R `test_dir("modules/tabs/tests/testthat")`
6304 passed, 0 failed, 1 skip (the pre-existing tracking_island skip). Run R
suites with `TURAS_ROOT` set to the repo root.

## What stage 2 built, the API stage 3 builds on

`modules/tabs/lib/html_report_v2/assets/js/24b_narrative.js` is `TR.narrative`:

- `screens()`: `project.narrative`, or `[]`.
- `byId(id)`: one screen, or null.
- `coverScreen()`: the first screen whose title starts with "Executive summary"
  (case, spacing and punctuation ignored), else the first screen, else null.
- `blocksHtml(blocks, {lead})`: the ONE block renderer. Every value escaped.
  Word's flat list levels are nested here; a jump of two levels reads as one.
  Only `data:image/png|jpeg|gif` pictures render.
- `blocksText(blocks)`: the same blocks as plain lines (list items as "• ",
  table rows as cells joined " | ", pictures left out).
- `presentHtml(screen)`: the Present layout. Classes `pr-narrative`,
  `has-pic`, `long-list` (a list of more than 6 items), `nar-lead`,
  `nar-callout`, `nar-pics`; CSS in `styles.css`.

The block schema is in the header of `modules/tabs/lib/crosstabs/narrative_reader.R`.
`tests/fixtures/narrative_island.json` is the R reader's real output for the
stage 1 fixture document plus the Comments fallback. Regenerate it from R if
the schema changes; never edit it by hand.

Pinning: a Report tab card carries `data-snap-narrative="<screen id>"`. The
shell (`24_shell.js`, the snap-pin click handler) calls
`story2.pinNarrative(id, heading)`, which stores
`{kind: "narrative", screen, heading, note}`. `heading` is only there to name
the pin once its screen is gone. `30_story.js` resolves the screen on every
render in `pinTitle`, `itemBodyHtml`, `itemHtml` and `renderPresent`. A gone
screen shows the authored text key `story.narrative_gone`.

The cover (`24a_reader.js coverHtml`) and the deck cover text
(`30_story.js coverSlideFor`) both read `coverScreen()`. Narrative pins, and
the frozen `source: "report"` snapshots older stories still hold, are never
cover findings (`reader.isCoverSectionPin`).

## Decided after the brief (do not relitigate)

1. **Cover screen.** Duncan, 22 Sep: the first screen titled "Executive
   summary..." rather than the plain first screen. The SACS file opens
   "Background and method", then "Executive summary : In a nutshell"; the rule
   picks the second. A Comments-sheet project's HTML cover now shows only its
   executive summary (it used to show background too).
2. **Fieldwork stand-in.** A blank `_BACKGROUND` with `fieldwork_dates` set
   still gives a one-line "Fieldwork: <dates>." background. This now lives in
   `narrative_from_comments` (R), on the blank-key path only.
3. **Unset hints.** The two "Not set" Comments-row hints show only when there
   are no screens at all.
4. **Labels.** The story tag "SUMMARY" and the title fallback "Summary" are
   hard-coded, matching their "SLIDE" / "Study slide" neighbours. Moving the
   story labels to `TR.txt` is a separate job, not stage 3.

## Stage 3: the fixed list

### 1. A text-and-bullets slide in the deck

Replace the stage 2 BRIDGE. Today a narrative pin exports as
`exporter.dividerSlide(title, blocksText(...))` in `30_story.js slidesFor`,
and as `exporter.cardSvgRaw(...)` in `itemCardSvg` for the image deck. The
`slidesFor` branch carries a comment naming stage 3; the `itemCardSvg` one
does not.

Add `exporter.narrativeSlide(screen, opts)` to `29_export.js`, built from the
same blocks, laid out like Present: brand title, the first paragraph as the
lead, sub-headings, bullets with their nesting level, a long list in two
columns, the Quote style as a band (`rectShape` behind a text box), pictures
beside the words, simple tables. The pin's `note` goes where every other
slide puts commentary (`slideForModel` draws it as the gold insight band).

What exists and what does not, checked 22 Sep:

- `para(text, o)` (near line 246) writes ONE run with whole-paragraph bold
  and italic, and has no bullet support (no `a:buChar`, no `lvl`). You need a
  runs-aware paragraph builder that keeps per-run bold and italic and writes
  `<a:pPr lvl marL indent>` with `a:buChar` or `a:buAutoNum`. Do not change
  `para` itself; every existing slide uses it.
- `textBox` already sets `<a:normAutofit/>`.
- Pictures: `exporter.slidePicture(slide)` decodes a `{image, w, h}` data URI
  into `{bytes, w, h, ext}`. A narrative image block is `{src, width, height}`,
  so adapt the field names rather than duplicating the decoder. A slide
  object may carry several pictures: `TR.pptx.package` (`14_pptx_parts.js`,
  near line 233) numbers `slide.images` rels after any charts, so the k-th
  picture is `rId(2 + charts + k)`. `imageSlide` hard-codes `rId2` because it
  has one picture and no charts; yours must not.
- Tables: `tableFrame(id, box, matrix, brand, fontSize)` with `fitMatrix`,
  as `matrixSlide` uses them. A narrative table has no header row, so decide
  whether the first row is styled as one, and note it.
- A long screen must never lose words. Decide overflow at block boundaries
  (a "continued" slide is the conservative choice), log it, and test it.

The image deck (`itemCardSvg`) may keep a text card if a faithful card
render is large; say which in the commit.

The existing export of every other pin kind is untouched. `coverSlide` needs
nothing: it already receives the cover screen's text.

### 2. The screens-first seed

In `story2` `load()` (`30_story.js`, top of file): when the story comes out
empty AND not owned AND `TR.narrative.screens()` is non-empty, put one
narrative item per screen at the front, in document order. After that they
are ordinary pins.

Traps:

- Do not call `touch()`. Seeding is not a reader change and must not set the
  `_owns` marker. The passive persist in `renderTab` then stores the seeded
  list as un-owned state, and the next load finds a non-empty story and does
  not seed again (a load before any persist seeds the same list, so it is
  harmless). That is the behaviour the brief wants: a section added to Word
  later is pinned by hand.
- Clear sets ownership, so a cleared story stays empty. Test that.
- A saved copy's `TR.userState.story` that is `[]` and un-owned seeds; one
  with items does not. Test both, plus the legacy array form of stored state
  (see the comments in `load()`).
- Seeded narrative items are not cover findings (`isCoverSectionPin`), so the
  cover is unchanged. Assert that too.
- `state_tests.mjs` covers the `_owns` marker; extend it rather than
  inventing a new harness.

### 3. The template binary

The generator already offers `narrative_file`
(`modules/tabs/lib/generate_config_templates.R`, near line 592), but the
shipped `modules/tabs/templates/Crosstab_Config_Template.xlsx` was not
regenerated. Snapshot the binary first, regenerate with
`generate_crosstab_config_template()` (it saves through
`turas_saveWorkbook`), then read the Settings sheet back to prove the new row
is there and nothing else moved. Precedent: commit 5e3f6285. While in the
generator, the `html_report_v2_cover` description still says the cover shows
"the Comments sheet's background and executive summary"; bring it in line
with decision 1.

### 4. The docs

- `06_TEMPLATE_REFERENCE.md`: a `narrative_file` row in the Settings table;
  the `html_report_v2_cover` row (near line 882); the `_BACKGROUND` /
  `_EXECUTIVE_SUMMARY` rows (near line 2277) saying they are used only when
  `narrative_file` is blank.
- `04_USER_MANUAL.md` (near line 524): how to write the Word file, what is
  honoured and what is skipped (the brief's fixed list), that pins are
  references, the cover rule.
- `11_DATA_CENTRIC_REPORT_V2.md` (near line 153) still describes
  `project.report_meta.background` as the source of the Report tab cards; it
  is now `project.narrative`.

No em dashes anywhere in these, or in any string or commit message.

## Checks that end stage 3

1. Node, one file at a time:
   `node modules/tabs/lib/html_report_v2/tests/<name>_tests.mjs` for
   `narrative`, `exports`, `pptx_style`, `state`, `cover`, then the whole
   loop, then `mutate_text_check.mjs`.
2. `pptx_visual_qa.mjs`: add a narrative pin (with a picture, a nested list,
   a callout and a table) to its fixture deck, then open the slide PNGs it
   prints and look at them. LibreOffice renders the deck; that is the check.
3. R: `test_dir("modules/tabs/tests/testthat")` with `TURAS_ROOT` set, which
   includes `test_config_templates.R`.
4. Commit on the branch. Do not merge or push.
5. Then Duncan, not the session: set `narrative_file` in the SACS 2026
   config's Settings sheet to the Word file
   (`05_Reporting/SACS-2026_Narrative.docx`, relative to the config), run
   `launch_turas()`, and look at the Report tab (8 cards), pinning, the story
   card, Present, a saved copy's cover, and the exported deck. Nothing is
   done until that eyeball. The session never writes into the OneDrive
   project folders and never headless-runs the pipeline on a real config.

After stage 3, an independent review in a fresh session (brief, "Model and
effort").
