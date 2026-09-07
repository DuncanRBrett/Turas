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
destination and no other. That file goes from 253 to 301 assertions.

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
