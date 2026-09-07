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
