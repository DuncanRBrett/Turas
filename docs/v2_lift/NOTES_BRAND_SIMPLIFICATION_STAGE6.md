# Brand simplification, Stage 6 implementation log

**Date:** 7 September 2026. Worktree `/Users/duncan/Dev/Turas-brand-simplify`,
branch `feature/brand-qa`, cut from main at e94c2b30.
Scope: the QA sweep. Close the gaps Stages 2 to 5 recorded; add no features.

Brief: the Stage 6 task message, against
`docs/v2_lift/HANDOVER_BRAND_SIMPLIFICATION_FOR_OPUS.md` section 7,
`modules/brand/docs/SIMPLIFICATION_IMPACT_MAP.md` and the Stage 2, 3, 4 and 5
logs.

## Baseline, executed before the first edit

- Brand suite: `TURAS_ROOT=/Users/duncan/Dev/Turas-brand-simplify Rscript -e
  'testthat::test_dir("modules/brand/tests/testthat")'` gave
  **FAIL 0, WARN 1, SKIP 2, PASS 3560**, 120.0 s. Matches the brief.
- IPK fixture report generated to the scratchpad as the before baseline:
  `run_brand()` on `modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx`
  with `project_root` = the fixture directory, then
  `generate_brand_html_report()`. Status PASS, **4,044,194 bytes**, which is
  the byte count the Stage 5 log ends on. Nothing was written into the repo or
  into any project folder.

## Item 1: the element flag matrix, and the bug it found

Duncan's ruling was that "a destination with nothing configured hides cleanly
rather than rendering empty" must be proved by toggling the real config flags
against the IPK fixture, because the three synthetic example projects cannot
run: their generators call `.build_questions_columns()`, which exists nowhere
in the repository, so `run_brand()` refuses before any report code executes.
Stage 2 asserted the rule on stub fragments handed straight to
`build_br_category_panel()` instead. The ruling was never carried out.

**Built:** `modules/brand/tests/qa/drive_element_flags.R`. It writes a variant
`Brand_Config.xlsx` into a scratch project directory, runs the real pipeline,
and reads the destinations out of the generated HTML. Eighteen runs, about
four minutes.

- **all on**, then **all off**.
- **twelve single-flag runs**, one flag on and eleven off.
- **four destination-off runs**: every flag that one destination holds turned
  off, the rest left on.

**A count correction, made rather than guessed.** The task message says
thirteen `element_*` flags. There are **twelve**: the list `01_config.R` reads
at its lines 112 to 116. `element_ma` at `00_guard.R:631` is a local variable
holding `element_mental_avail`'s value, not a config key. The harness names all
twelve and drives all twelve.

**A control before the matrix.** A config rewritten through
`read.xlsx` + `write.xlsx` with no change at all produced a report of
**4,044,194 bytes**, identical to the baseline. So a difference in the matrix
is the flag, not the rewrite.

### The bug

`03_page_builder.R` decided whether a category deserved a tab at all with

    has_content <- !is.null(cr$mental_availability) || !is.null(cr$funnel)

while `build_br_category_panel()` a few hundred lines below built leaves from
**eight** elements. A study configured with Word of Mouth and Demographics and
neither Mental Availability nor the funnel therefore got **no category tab**,
and every analysis it had configured was absent from the report with no
warning anywhere. The first matrix run caught it: `only element_wom`,
`only element_demographics` and `only element_repertoire` each rendered no
destination and no category tab.

The line dates from `fa0d9713`, 16 April 2026, the commit that first built the
HTML report. It is not a simplification regression. It is, though, exactly the
rule Stage 6 was asked to prove, failing in the other direction: hiding
content that **is** configured.

**Fixed** by giving both places one source of truth. `.br_cat_renderable()`
holds the eight per-element conditions, unchanged, moved out of
`build_br_category_panel()`; `.br_cat_has_content()` is any of them; the tab
bar calls it. The IPK fixture report after the fix is **4,044,194 bytes**, and
diffing it against the baseline shows one changed line, the generation
timestamp. No number moved.

### What the matrix now proves

    81 checks, 0 failed

- Registry cross-check: the harness's hand-written destination-to-flag table
  agrees with `.BR_LEAF_HOMES`, all 19 leaves.
- Every destination hides when everything it holds is off, with no nav button
  and no container left behind, while the other destinations stay up, so a
  pass cannot come from the whole panel having vanished.
- No destination appears from a flag it does not hold.
- Every flag that lit a destination alone still lights it with everything on.

Which flag lights which destination on this fixture:

| Flag | Destination |
|---|---|
| `element_funnel` | buying, meaning |
| `element_mental_avail` | mental |
| `element_repertoire` | buying |
| `element_wom` | meaning |
| `element_demographics` | audience |
| `element_cep_turf` | on, no content on this fixture |
| `element_dba` | on, no content on this fixture |
| `element_portfolio` | on, no content on this fixture |
| `element_drivers_barriers` | on, no content on this fixture |
| `element_branded_reach` | on, no content on this fixture |
| `element_adhoc` | on, no content on this fixture |
| `element_audience_lens` | on, no content on this fixture |

The seven "no content" rows are reported, not asserted either way. A flag can
be on and produce nothing because the fixture carries no data for it, and the
harness never claims a flag was proved when the data was absent. Four of the
seven are item 2's subject; `element_cep_turf` runs inside Mental Availability
and owns no leaf; `element_dba` and `element_portfolio` own top-level tabs,
not category destinations; `element_drivers_barriers` has no HTML tab any more
(its engine still writes Excel and CSV).

**The designed exception, stated as it behaves.** Overview always renders when
the category renders. With every element off the category has nothing at all
and its **whole tab** is absent, which is the strongest form of hiding
cleanly: the reader is not offered a tab that opens on a route card and
nothing else. The harness asserts both halves.

### Also added

Four `testthat` blocks in `test_destination_nav.R` covering the same ground at
unit speed: every element carries a category on its own; a category with
nothing renderable earns no tab; a refused or empty element does not earn one;
and a category carried by Word of Mouth alone renders the Brand Meaning
destination and no other. That file goes from 268 to 301 assertions, verified by running the
pre-change version of the file in place.

## Fixture drift, found by a control and left alone

Regenerating the fixture from `00_generate.R` into a scratch directory and
comparing it sheet by sheet against the committed workbooks: the data file
differs in 15 columns and `Survey_Structure` in two sheets. Every difference
is an em dash replaced by a colon or a full stop, from the project's own
no-em-dash rule being applied to the generator after the workbooks were last
written. `BRANDATT2_DSS_*` (rejection verbatims), the `Project` sheet's
`project_name`. No number differs, and both files carry 1200 rows and 847
columns. Recorded so the next session knows the on-disk fixture is one
cosmetic commit behind its generator, and does not go looking for a data bug.

## Item 2: the four elements that had never rendered

Branded Reach, Ad Hoc, Audience Lens and Shopper Behaviour had never rendered
through the five-destination shell with real panel fragments. Stage 2, Stage 4
and Stage 5 all recorded it. Their toolbars and drawers were exercised on stub
fragments only.

**Chosen: extend the fixture generator, behind an opt-in flag, and write the
extended bundle to a scratch directory only.** `ipk_generate_fixture()` gains
`extras = FALSE`; `modules/brand/tests/fixtures/ipk_wave1/08_qa_extras.R`
holds everything it does. The committed fixture and the 3560-assertion
baseline are untouched, which was proved rather than assumed: regenerating
with `extras = FALSE` and comparing every sheet of all three workbooks against
a regeneration from before the change gives **no differing sheet in any of the
three files**. Every extra column is appended after the last existing builder
has run, and the two that need random numbers set their own seed there, so the
stream that produces the committed fixture never moves.

### Provenance, which is the part that had to be got right

The brief said to extend the generator rather than stub, but only without
inventing survey answers that misrepresent the study. The Wave 1 instrument
(`IPK_Brand_Health_Wave_1-2.doc`, an Alchemer HTML export) was read to settle
that, and it splits the four cleanly.

**Two are faithful.** The instrument asked them, and the extras only re-shape
answers the fixture already generates. Neither draws a random number.

- **Shopper Behaviour.** Q63, where the respondent bought in the last three
  months, and Q64, the pack sizes bought. The fixture already stores both as
  slot-indexed code columns. The shopper engine wants one 0 or 1 column per
  option, so the extras transpose the slots. The same answers in another
  shape.
- **Audience Lens.** Q66, the brands bought. The audience is focal-brand buyer
  against non-buyer, a cut of an answer the instrument collected. 197 buyers
  and 241 non-buyers, both well over the 50 suppression floor.

**Two are not.** IPK Wave 1 asked no advertising or asset recognition question
and no study-specific extra question, so there is nothing to re-shape.
**Branded Reach and Ad Hoc are invented outright.** They are written only into
the scratch QA fixture, never the committed one, and every label they carry
says so on its face: the assets are "QA synthetic asset A (not asked in IPK
Wave 1)" and B, and the ad hoc question text opens "QA synthetic question, not
asked in IPK Wave 1". Read out of a report they cannot be mistaken for an IPK
answer. That is the line this session drew: inventing data and calling it IPK
would have been the failure; inventing data, labelling it, and keeping it out
of the study's own fixture is render coverage.

### What each one needed, and what was blocking it

Each of the four was blocked by something different, and none of the four was
blocked by the shell.

| Element | What was missing |
|---|---|
| Audience Lens | The `AudienceLens_Use` column on the Categories sheet. Without it `parse_audience_lens_definitions()` returns an empty list and logs nothing, which is why the lens has been silently absent although `element_audience_lens = Y`. The `AudienceLens` sheet was also in the wrong workbook, `Brand_Config.xlsx`, which nothing reads it from, and carried a free-text `Definition` the engine has no parser for. |
| Shopper Behaviour | A `QuestionMap` sheet. `resolve_shopper_role_columns()` reads `structure$questionmap` directly and never consults the inferred role map, so convention inference cannot reach it. Plus one 0 or 1 column per option, where the fixture had slots. |
| Branded Reach | `element_branded_reach = N` in the fixture's own Settings, and no `MarketingReach` or `ReachMedia` sheet. |
| Ad Hoc | No `ADHOC_*` row on the Questions sheet and no matching data column. The `AdHoc` sheet in `Brand_Config.xlsx` is read by nothing. |

**A latent bug found on the way and worked around, not fixed in place.**
`.shopper_code_list_spec()` keys the pack size list on `PackSizeCode` and
`PackSizeLabel`; the fixture's `.ipk_build_packs_df()` writes `PackCode` and
`PackLabel`, so pack size resolves to NULL even once a QuestionMap exists. The
extras writer emits both pairs rather than renaming the committed fixture's
columns, so nothing that already reads the old names breaks. **Owed:** decide
whether the fixture or the engine has the right name. It is recorded here
rather than changed, because changing it means regenerating the committed
fixture, which is a separate decision.

### Executed

All four now render, with real payloads and real numbers, read out of the
generated HTML:

| Element | What is on the page |
|---|---|
| Branded Reach | 2 assets, n = 438. The misattribution table gives the focal brand 40 percent of those who recognised the asset, n = 76, with named rivals and a "Don't know" row at 11 percent. |
| Ad Hoc | 1 question, n = 438, three options with their labels, with brand cuts. |
| Audience Lens | The pair card: n = 197 bought the focal brand against n = 241 who did not, with aided awareness 100 against 86 and a +14pp chip. |
| Shopper Behaviour | Shopping location by brand across all six channels (focal 19 percent Supermarket, n = 37) and the pack size table across all four sizes. |

`data-leaf` values in the extras report: **all nineteen**, against fifteen in
the committed fixture's report.

**One artefact of the audience definition, stated so nobody reads it as a
finding.** The Audience Lens pair shows "P3M usage 100 percent against 0
percent, +100pp, DEFEND". That is a tautology: the audience is defined by
buying the brand, so its usage is 100 and the other side's is 0 by
construction. The engine is right, the audience is trivially separable, and a
real study would pick a cut that is not the metric. Left as it is, because a
tautological pair still exercises every render path and inventing a subtler
audience would have meant inventing data.

## The ungated funnel, both modes exercised

Duncan's ruling of 7 September: Turas draws a nested funnel only when the
questionnaire gated the questions. The fixture builds attitude and purchase
answers only over brands the respondent named as known, so it reads as gated.
The real IPK instrument did not gate.

`ipk_generate_fixture(ungated = TRUE)` makes the second mode by the smallest
change that flips `detect_instrument_gating()`: it clears the focal brand from
the awareness slots of 25 respondents who hold an attitude towards it, leaving
every other answer alone. That is exactly the row an ungated instrument
produces and a gated one cannot.

    gated report    data-fn-gating="gated"    gating-mode="nested"
    ungated report  data-fn-gating="ungated"  gating-mode="separate"

and the ungated report carries the reason on the page, naming the three stages
that breached and saying the nested view is not offered because it would show
an ordering the survey never enforced.

## The QA suite on both reports

Every script under `modules/brand/tests/qa/`, on the gated extras report and
on the ungated one.

| Script | Gated | Ungated |
|---|---|---|
| `drive_element_flags.R` | 89 checks, 0 failed | see below |
| `drive_destinations.py` | 384 checks, 0 failed | 384 checks, 0 failed |
| `drive_chrome.py` | 136 checks, 0 failed | 138 checks, 0 failed |
| `drive_save_roundtrip.py` | 117 checks, 0 failed | 117 checks, 0 failed |
| `drive_overview.py` | 60 checks, 0 failed | 58 checks, 0 failed |
| `drive_funnel_base.py` | 99 checks, 0 failed | 79 checks, 0 failed |
| `drive_two_categories.py` | 15 checks, 0 failed | 15 checks, 0 failed |

`drive_funnel_base.py` and `drive_overview.py` run fewer checks on the ungated
report because some of their checks are about the nested view, which an
ungated report does not offer. They are mode-aware already: the ungated run
asserts the notice, its reason and the separate-measures wording, and it was
read to confirm it does that rather than skipping the funnel.

The two-report gates, run on the pairs that make sense (a comparison across
two different fixtures would differ by construction):

- `reachability_check.py base.html ctl2.html`, the committed fixture before
  and after this stage's page-builder change: **PASS**, every island's numeric
  content identical.
- `anchor_resolution.py` on the committed fixture pair: **41 of 41** anchors
  and section ids resolve to content. On the extras report: **69 of 69**,
  which includes the 14 anchors the four new elements bring. On the ungated
  report: **69 of 69**.

### The 15 failures the extras fixture found, and what was done with them

`drive_destinations.py` failed 15 checks the first time it saw the extras
report: the comparison-set brand filter does not reach Branded Reach, Ad Hoc
or Audience Lens. None of the three carries a brand-code attribute or
subscribes to the category store.

This is not a simplification regression. Those panels have never been inside
the shell before and nothing about them changed. It is also not wrong for all
three: Audience Lens is a focal-brand view whose two audiences are buyer and
non-buyer of that one brand, so it has no brand list to narrow. For Branded
Reach and Ad Hoc, which do show brand-keyed content, it is a real gap.

Rather than mark them "no brands here" and quietly bless it, the harness
gained a third classification, `unwired`, which asserts they show **no** brand
code at all. The day one of them is wired to the comparison set the check
fails and forces the classification to be revisited. **Open gap, recorded:**
wire Branded Reach and Ad Hoc to the comparison set, or rule that they are
whole-category views. Not this stage's work: it is a feature, and Stage 6 adds
none.

## Item 5: the two rulings Stage 5 left open, decided

Both are decided against changing anything, and both for the same underlying
reason: this is the QA stage before an independent review, and the two things
a reviewer most needs are that the scope Duncan signed off at Stage 1 held,
and that the "nothing changed" gates mean what they say. Neither ruling is
closed forever; both are written up as post-merge work with what it would
take.

### Ruling A. The Mental Availability and funnel panel-native controls stay.

The conflict: the impact map section 7 lists them under "What must not change"
and says in terms that "Stage 5 consolidates the shared toolbars, not the
panel-native ones". The Stage 5 brief's "one toolbar per destination, not one
per table" reads as though they should go. Stage 5 kept them and asked.

**Decision: keep them.** Three reasons, the first two checked in the code
rather than repeated from the Stage 5 log.

1. **They are strictly finer than what would replace them.** Read out of
   `js/brand_ma_panel.js` around line 2175, the MA pin dropdown offers up to
   seven named pieces: Matrix table, Bar chart, Insight note, Headline metric
   cards, Brand metric table, Mental Space scatter, MMS vs SOM chart. Read out
   of `js/brand_funnel_panel.js` around line 2579, the funnel's offers up to
   seven: Relationship table, Relationship chart, Insights, Table, Chart, Mini
   funnels, and AI insights where present. The destination toolbar's picker
   offers whole leaves and anchors: five on Mental Availability's main view.
   Removing the panel controls would not remove capability from the report, it
   would coarsen it, and a reader who wants the Mental Space scatter alone
   would have to pin the whole leaf.
2. **The scope was reviewed.** The impact map was the Stage 1 deliverable
   Duncan approved before any shell code was written, and it drew this line
   explicitly. Redrawing it at the QA stage, after five stages have been built
   on top, is the wrong moment. If the line is wrong it should be moved
   deliberately, not as a side effect of a sweep.
3. **It is feature work, and this stage adds none.** In the extras report the
   panel-native controls number 5 funnel pin dropdowns, 4 funnel PNG, 3 funnel
   Excel, 2 funnel relationship Excel, 8 MA pin dropdowns, 7 MA PNG and 7 MA
   Excel. Taking those out means editing two panel files and their JS, and
   then re-driving every capture path in Chrome, immediately before the review
   that is supposed to look at a settled branch.

**If Duncan wants them gone**, it is one change in two panel files plus the
two JS pin-menu builders, and `drive_chrome.py` and `drive_destinations.py`
both need re-running because both count controls per view. Budget it as its
own stage, not as a patch to this one.

### Ruling B. Section_Insights does not pre-fill a destination commentary box.

The cost Stage 5 stated: a destination box carries `data-dest-note`, not
`data-section`, so a Section_Insights sheet cannot pre-fill it. Giving it one
needs a new anchor name and a rebaselined reachability comparison.

**Decision: no, not in this merge.** Four reasons.

1. **It would weaken the one gate the reviewer most needs.**
   `reachability_check.py` passes today with the `data-section` set unchanged,
   which is what lets the branch claim that no analyst's saved pin and no
   Section_Insights anchor moved. Adding an anchor makes that gate a
   rebaselined comparison, and a rebaselined gate proves less. The proof that
   nothing moved is worth more right now than the convenience.
2. **Authored text is not lost today, and that was checked, not assumed.** The
   fixture's Section_Insights sheet authors three DSS anchors: Brand Funnel,
   Category Entry Points and Word of Mouth. In the generated report each one
   renders a leaf commentary box carrying its text, on `funnel-dss`,
   `ceps-dss` and `wom-dss`. So a sheet written before the refactor still
   lands, on the leaf where it was written. Nothing is stranded; the gap is
   only that an analyst cannot address the destination as such.
3. **It is a config contract change, and the contract is Duncan's.** The
   anchor names are typed into Section_Insights sheets by analysts. A new
   family of names, one per destination per category, is a decision about what
   analysts have to learn, not a decision a QA session should take.
4. **It is purely additive later.** A new anchor on a box that exists can be
   added without touching anything this merge changes, on a branch of its own
   with its own rebaselined gate.

**If Duncan wants it**, the shape is a `dest-<cat>-<destination>` anchor
alongside the existing `data-dest-note`, one row per destination in the
Section_Insights anchor map in `R/01b_section_insights.R`, and a reachability
baseline regenerated on purpose with the additions listed and justified rather
than silently absorbed.

## Item 3: the capture paths opened in a viewer, and the regression that found

Stage 5's log recorded: "No pinned card, PNG or workbook was opened."
`drive_chrome.py` intercepted them and inspected the bytes; nobody had looked.
`modules/brand/tests/qa/capture_artifacts.py` drives Brand and Buying, the
destination with the most tables, produces all three for real and saves them,
and this session opened each one.

### The regression looking found

**Clicking Pin or PNG on a destination toolbar did nothing at all.** Not an
error, not a wrong result: nothing.

`brand_pins.js` registers a document-level click listener that closes any open
popover unless the click is inside `.br-pin-btn`, `.br-png-btn`, `.ma-png-btn`
or `.fn-png-btn`. Stage 5's controls are `.br-dest-pin` and `.br-dest-png`,
neither of them on that list. The inline `onclick` opened the picker and the
same click, still bubbling, removed it.

Reproduced independently before the fix was written, in headless Chrome on the
committed fixture's report:

    {"found_pin":true,
     "popovers_after_CLICK":0,  "popovers_after_DIRECT":1,
     "png_after_CLICK":0,       "png_after_DIRECT":1}

**Why Stage 5's own harness passed 115 of 115 over it.** `drive_chrome.py`
called `brPinFrom()` and `brExportPngFrom()` directly, because that is what
the picker calls once the reader has chosen, and the only control it clicked
was Excel, which has no picker. Driving the handler is not driving the
control. That is the general lesson of this item and it is worth more than the
bug.

**Fixed** in `js/brand_pins.js`: one `POPOVER_OPENERS` selector list, in one
place, now including the two destination controls. After the fix, on the same
probe: pin and PNG each open one popover on a click, and a click on the body
still closes it, so the close behaviour is intact.

**The harness hole is closed too.** `drive_chrome.py` now clicks the pin and
PNG controls, before driving their handlers, and asserts that a click either
opens the picker or pins. It goes from 115 checks to 125 on the committed
fixture, 150 on the extras report and 152 on the ungated one.

### What the three artefacts actually are, having been opened

- **The pinned card**, screenshotted on the Pinned Views tab. The tab is
  active, its badge reads 1, and the card is complete: title "Summary" with
  the mode dot, "Base: Funnel, % of all", the authored insight, the funnel
  chart with the focal line at 92, 67, 45, 32 against a dashed category
  average and a min-max band, and the table beneath with base n=438, the focal
  row and the category average at 61, 24, 10, 6 with its min-max rails. No
  significance marker, which is right with the toggle off.
- **The exported image**, opened. Complete, well composed, and identical to
  the pinned card row for row. **But it is JPEG bytes under a `.png` name.**
  `TurasPins.EXPORT_QUALITY` defaults to "standard", whose preset is
  `image/jpeg` at 0.85, while `exportContentAsPNG` hardcodes the `.png`
  suffix. That is in `modules/shared/`, which this branch must not touch, and
  it is not Stage 5's doing. Recorded, not fixed.
- **The workbook**, converted to PDF with LibreOffice headless and the first
  page opened. Four sheets for the four tables, none empty, and the focal row
  is right: 92, 67, 45, 32.

### Three things wrong with the workbook, all older than this programme

Read off the rendered page, not inferred.

1. **The category average row is garbled.** It reads **615172, 241731, 10515,
   629**. The page shows 61% with a 51% to 72% rail beneath it, and
   `cell.textContent` swallows the rail spans, so "61%51%72%" loses its
   percent signs and parses as one number.
2. **Category labels are coerced to numbers.** The purchase bands 1x, 2x,
   3-5x and 6+x arrive as 1, 2, 3 and 6. "3-5x" silently becomes 3.
3. **The workbook carries rows the reader cannot see.** All 18 brands are in
   `funnel-dss` while the page, with the chip reading "Brands: focal only",
   shows 4. The image export and the pinned card carry the 4. So the two
   capture paths disagree about what the view is.

Smaller: sheets are named from anchor ids (`funnel-dss`) rather than the
labels the picker showed the reader, and header cells carry the sort glyph.

**Not fixed, deliberately.** `_brTablesToWorkbook()` and its
`cell.textContent` reader date from `fa0d9713`, 16 April 2026, the commit that
first built the HTML report. Stage 5 only split `_brExportPanel()` so that
`_brExportRoot()` is the one workbook builder; it did not touch the
extraction. Fixing it changes numbers in a file a client may open, on a path
five stages of work did not disturb, and it needs its own verification. This
stage adds no features and changes no numbers. **It is the first thing the
reviewer should look at**, and the diagnosis above is the whole of it.

## Item 4: the sweep proper

Every script under `modules/brand/tests/qa/`, on three reports: the committed
fixture (gated, 15 leaves), the extras fixture (gated, all 19 leaves) and the
ungated variant (all 19 leaves, separate measures).

| Script | committed | extras, gated | ungated |
|---|---|---|---|
| `drive_element_flags.R` | 81 checks, 0 failed | 89 checks, 0 failed | 89 checks, 0 failed |
| `drive_destinations.py` | 353, 0 | 384, 0 | 384, 0 |
| `drive_chrome.py` | 125, 0 | 150, 0 | 152, 0 |
| `drive_save_roundtrip.py` | 113, 0 | 117, 0 | 117, 0 |
| `drive_overview.py` | 60, 0 | 60, 0 | 58, 0 |
| `drive_funnel_base.py` | 99, 0 | 99, 0 | 79, 0 |
| `drive_two_categories.py` | 15, 0 | 15, 0 | 15, 0 |
| `capture_artifacts.py` | all artefacts, 1 known defect | same | same |
| `count_chrome.py` | control counts, below | | |

**The ungated runs are shorter because two checks do not apply, and that was
read rather than assumed.** Diffing the two `drive_overview.py` runs, the
ungated one drops exactly "the card says on its face that it is nested" and
"the nested series really differs from the absolute one". `drive_funnel_base.py`
drops the nested-view checks and asserts the ungated notice, its reason and
the separate-measures wording in their place.

**The two-report gates**, on the pairs that mean something:

- `reachability_check.py base.html base2.html`, the committed fixture before
  this stage's first edit and after its last: **PASS**. Every `data-subpanel`,
  every `data-section`, every section id and every island's numeric content
  identical. So neither the tab-bar fix nor the popover fix moved a number.
- `anchor_resolution.py`: 41 of 41 on the committed fixture, **69 of 69** on
  the extras report, which includes the 14 anchors the four new elements
  bring, and 69 of 69 on the ungated one.
- There is no ungated report from before this stage, so there is no ungated
  before-and-after pair. Said rather than faked: the numeric-identity gate is
  the committed-fixture pair above.

### Control counts, from `count_chrome.py` in a browser

| Measure | committed | extras | ungated |
|---|---|---|---|
| Pin controls | 29 | 38 | 38 |
| PNG controls | 21 | 30 | 30 |
| Excel controls | 15 | 18 | 18 |
| Commentary textareas | 14 | 17 | 17 |
| Destination toolbars | 5 | 7 | 7 |
| Significance toggles | 4 | 4 | 4 |
| "How this works" drawers | 5 | 6 | 6 |
| Destination buttons | 5 | 5 | 5 |
| Significance markers in the DOM | 276 | 276 | 311 |
| "significan" visible across the destinations | 5 | 5 | 5 |

The extras report carries more of everything because it renders four more
leaves in two more views, and the ungated one has 311 markers rather than 276
because the separate-measures funnel marks stages the nested view leaves
unmarked.

### One consequence of the extras fixture, recorded

On the committed fixture, Category Context draws a buying-location bar chart:
`compute_buying_location()` is the fallback that runs when the shopper engine
has nothing, and it renders **6 bars**. On the extras fixture the shopper
engine succeeds, so the fallback does not run and Category Context draws
**0**. Nothing is lost: the same information is on the Shopper Behaviour leaf,
per brand and with bases, instead of as a category-level bar chart. Recorded
because a reviewer comparing the two reports will see it.

## Reproducing all of it

`modules/brand/tests/qa/generate_qa_reports.R` builds all three reports and
both scratch fixtures into one directory, so nothing in this log depends on a
recipe that lives only in a scratchpad. It reproduced 4,044,916 / 4,154,885 /
4,154,908 bytes, the three reports every gate above was run against.
