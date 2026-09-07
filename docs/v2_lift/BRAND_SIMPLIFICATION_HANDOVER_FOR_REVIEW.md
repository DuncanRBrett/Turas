# Brand report simplification: handover for the pre-merge review

**Date:** 7 September 2026. Written at the end of Stage 6 for a reviewer
briefed as independent of the six sessions that built this.
**Branch under review:** `feature/brand-qa`, in the worktree
`/Users/duncan/Dev/Turas-brand-simplify`, cut from main at `e94c2b30`.
Stages 1 to 5 are already merged into main; Stage 6 is every commit on
this branch. Nothing is merged and nothing is pushed.

**The branch is behind main by six commits**, all of them another programme's
work on `modules/shared/`, `scripts/` and `docs/disclosure/` (composed report
hardening, merged at `c415245d`). None of them touches `modules/brand`, so a
`git diff main..HEAD` will show them as apparent deletions. Diff against the
base instead: `git diff e94c2b30..HEAD`. That is exactly twelve files, all
under `modules/brand/` and `docs/v2_lift/`.

You were not here. This tells you what changed, what to attack, every number
that moved and why, what is still broken, and the exact command for each gate.

---

## 1. What the programme was for

A reader opening a brand report faced **nineteen places to click inside one
category**: eleven flat sub-tabs, one of which (Category Buying) opened eight
more. The brief was to put them behind **five destinations** with an Advanced
drawer each, without deleting an analysis, moving an anchor, or changing a
number.

The five: Overview, Mental Availability, Brand and Buying, Brand Meaning,
Audience.

Two documents define the intent and are the right things to check the code
against:

- `docs/v2_lift/HANDOVER_BRAND_SIMPLIFICATION_FOR_OPUS.md`, the build brief,
  whose section 8 lists the acceptance criteria.
- `modules/brand/docs/SIMPLIFICATION_IMPACT_MAP.md`, the Stage 1 deliverable
  Duncan approved before any shell code was written. It has one row per
  sub-tab, its ids and anchors, and its new home. Section 7, "What must not
  change", is the contract the whole programme is measured against.

Per-stage logs: `docs/v2_lift/NOTES_BRAND_SIMPLIFICATION_STAGE2.md` through
`STAGE6.md`. They are long and they are honest; the "Known limits" section of
each is the fastest way in.

---

## 2. What each stage changed

**Stage 1, the impact map and a mockup.** No code. It produced the impact map
and a static mockup Duncan approved. Its section 9 raised six findings needing
a ruling; the one that shaped everything was that the funnel and Mental
Availability panels each straddle two destinations, and one DOM host cannot be
in two places. Duncan ruled for option (a): split the render.

**Stage 2, the five-destination shell.** `build_br_category_panel()` in
`lib/html_report/03_page_builder.R` now emits **one `.br-subpanel` host per
internal tab** rather than one per panel, so each of the nineteen leaves has
its own host and can live in its own destination. Only the primary host of
each panel carries the section wrapper id, the `data-section` anchor and the
JSON island; the others read the payload through `data-island-host`. Two
registries were added, `.BR_DESTINATIONS` and `.BR_LEAF_HOMES`, and they are
the single source of truth for where a leaf lives. Rehoming only: no analysis
changed.

**Stage 3, the Overview.** Extended `panels/14_summary_panel.R` and
`js/brand_summary_panel.js`: headline tiles with the gap to category average,
a verdict sentence, three strengths and three gaps, an Actions block labelled
Protect, Build and Investigate, and a collapsed "How this works". All
rules-based, no AI. It also fixed the Summary hero's rank clause, which had
never rendered because `heroAnchors()` read `rank` off the wrong object.

**Stage 4, the funnel.** Added a nested-chain view fed by
`base_chain_filtered / base` and made it the default, keeping absolute and
"% of aware" as toggles. It also added `detect_instrument_gating()` in
`R/03a_funnel_derive.R`, which decides from the respondent rows whether the
questionnaire routed the questions, and draws a nested funnel only when it
did. **Duncan's ruling of 7 September, not to be reopened:** an ungated
instrument gets four separate measures with conversion ratios and a statement
of why there is no funnel. The IPK instrument did not gate; the fixture does.

**Stage 5, the chrome.** One export toolbar per destination view and one per
Advanced drawer instead of one per table; significance as a toggle, default
off; one commentary box per destination; every explanatory block behind a
collapsed "How this works". The destination controls resolve by destination,
never by `data-section`, which is why the anchor set could stay frozen.

**Stage 6, the QA sweep.** This branch. It carried out the one ruling Stage 2
had not (the element flag matrix), rendered the four elements that had never
rendered, opened the capture files for the first time, ran every gate on a
gated and an ungated report, and decided the two rulings Stage 5 left open.
It found and fixed two bugs, described in section 3.

---

## 3. What to attack first

In this order. The first three are where a reviewer's time is worth most.

### 3.1 The Excel export garbles the category average. Not fixed.

Open a workbook and look at it. The category average row of `funnel-dss` reads
**615172, 241731, 10515, 629**, where the page reads 61% with a 51% to 72%
rail beneath it. `cell.textContent` in `_brTablesToWorkbook()`
(`js/brand_report.js` around line 1027) swallows the rail spans, so
"61%51%72%" loses its percent signs and parses as one number. Two more in the
same place: purchase bands 1x, 2x, 3-5x, 6+x arrive as 1, 2, 3, 6, and the
workbook carries all 18 brands where the page and the image export carry the 4
the brand filter leaves visible.

**Why it was not fixed here:** that extraction dates from `fa0d9713`,
16 April 2026, the commit that first built the HTML report. Stage 5 split
`_brExportPanel()` so `_brExportRoot()` is the one workbook builder, and did
not touch the reader. Fixing it changes numbers in a file a client may open,
on a path five stages did not disturb, and this stage was told to add no
features and change no numbers. **Duncan's call, and it should be made.**

### 3.2 The one production behaviour change Stage 6 made, on purpose

`03_page_builder.R` decided whether a category deserved a tab at all from

    has_content <- !is.null(cr$mental_availability) || !is.null(cr$funnel)

while `build_br_category_panel()` built leaves from **eight** elements. A study
with Word of Mouth and Demographics and neither of those two got **no category
tab**, silently. Both now go through `.br_cat_renderable()`, which holds the
eight per-element conditions unchanged.

**The risk to check:** a category that today has no tab will now get one if any
element produces a renderable result for it. The evidence that this is safe on
the fixture is that its eight awareness-only categories still produce no tab
and the report is byte-identical but for the timestamp. **What a reviewer
should do:** read the `cat_depth == "full"` gating on every element in
`R/00_main.R` and satisfy yourself that an awareness-only category cannot
produce a renderable result for a config that differs from the fixture's.

### 3.3 The general lesson: driving a handler is not driving a control

Stage 5's `drive_chrome.py` passed **115 of 115** while a reader clicking Pin
or PNG on a destination toolbar got **nothing at all**. `brand_pins.js` closed
any open popover on a document click unless the target was inside one of four
named classes, and Stage 5's `.br-dest-pin` and `.br-dest-png` were not among
them, so the click that opened the picker removed it. The harness passed
because it called `brPinFrom()` and `brExportPngFrom()` directly and the only
control it clicked was Excel, which has no picker.

Fixed, and the harness now clicks all three. **But the question generalises:**
look for other controls in this branch that are only ever exercised through
their handler. The significance toggle, the "How this works" toggles, the
Advanced accordion and the category switcher are all clicked by the harness;
the destination commentary box is typed into. Check that list against the DOM
yourself rather than taking it from here.

### 3.4 Then the acceptance criteria

`HANDOVER_BRAND_SIMPLIFICATION_FOR_OPUS.md` section 8, against a report you
generated yourself. In particular: no metric relabelled in a way that
misstates its computation, "Funnel" appearing only on a nested view, and
missing optional sections hiding cleanly.

---

## 4. Every number that moved, and why

### The brand suite

Read the chain, not the endpoints. Two of the steps are not this programme.

| Stage | Before | After | What the added assertions cover |
|---|---|---|---|
| lift tip, where the programme starts | | 2360 | |
| Stage 2 | 2542 | 2740 | the destination and leaf registries, the shell |
| Stage 3 | 3047 | 3077 | the Overview |
| Stage 4 | 3077 | 3247 | the nested funnel, gating detection |
| Stage 5 | 3486 | 3560 | toolbars, the significance toggle, commentary |
| Stage 6 | 3560 | 3593 | the category tab bar, `.br_cat_renderable()` |

**The two gaps are honest and are not this programme's tests.** 2740 to 3047
and 3247 to 3486 are work that landed on main between one stage's branch and
the next's. Each stage cut from main and recorded its own baseline before its
first edit, and every one of those baselines was reproduced by the session
that followed.

Stage 6's baseline was reproduced at the start of this session:
**FAIL 0, WARN 1, SKIP 2, PASS 3560**, 120.0 s. At the tip:
**FAIL 0, WARN 1, SKIP 2, PASS 3593**. The one warning and two skips are
pre-existing and named in the run output.

### The IPK fixture report

| Point | Bytes | Why it moved |
|---|---|---|
| before Stage 2 | 3,870,211 | |
| after Stage 2 | 3,918,223 | one host per leaf repeats the panel chrome |
| before Stage 3 | 3,962,385 | main moved under it |
| after Stage 3 | 3,989,976 | the Overview |
| after Stage 4 | 4,020,334 | the nested view and the gating notice |
| before Stage 5 | 4,024,208 | main moved under it |
| after Stage 5 | 4,044,194 | destination toolbars and drawers |
| Stage 6, after the tab-bar fix | 4,044,194 | **unchanged**; only the timestamp line differs |
| Stage 6, at the tip | 4,044,916 | +722 bytes, the popover fix and its comment |

**Nothing in Stage 6 changed a number in the report.**
`reachability_check.py` on the pre-edit and post-edit reports of the committed
fixture passes with every `data-subpanel`, every `data-section`, every section
id and every JSON island's numeric content identical.

### Control counts, in a browser, on the committed fixture

Stage 5's consolidation, measured on what is on screen rather than in the DOM:

| Measure | Before Stage 5 | After Stage 5 | Stage 6 tip |
|---|---|---|---|
| Pin controls | 29 | 25 | 25 |
| PNG controls | 21 | 17 | 17 |
| Excel controls | 20 | 16 | 16 |
| All export controls | 72 | 60 | 60 |
| Commentary textareas | 21 | 14 | 14 |
| "significan" visible across the five destinations | 14 | 5 | 5 |
| Significance markers rendered on screen | 37 | 0, and 37 with the toggle on | same |
| Destination export toolbars | 0 | 5 | 5 |
| "How this works" drawers holding something | 0 | 5 | 5 |

**The Stage 6 column is identical to the Stage 5 column**, measured on the
committed fixture's report at this branch's tip. Stage 6 added no control and
removed none: it made two of them work.

The extras report carries more of each, because it renders four more leaves in
two more views: 38 pin, 30 PNG, 18 Excel, 17 textareas, 7 destination toolbars
and 6 drawers. The ungated report matches it except for the significance
markers in the DOM, 311 against 276, because the separate-measures funnel
marks stages the nested view leaves unmarked.

### The QA gates, at the Stage 6 tip

Three reports: the committed fixture (gated, 15 of 19 leaves), the extras
fixture (gated, all 19), and the ungated variant (all 19, separate measures).

| Gate | committed | extras | ungated |
|---|---|---|---|
| `drive_element_flags.R` | 81, 0 failed | 89, 0 | 89, 0 |
| `drive_destinations.py` | 353, 0 | 384, 0 | 384, 0 |
| `drive_chrome.py` | 125, 0 | 150, 0 | 152, 0 |
| `drive_save_roundtrip.py` | 113, 0 | 117, 0 | 117, 0 |
| `drive_overview.py` | 60, 0 | 60, 0 | 58, 0 |
| `drive_funnel_base.py` | 99, 0 | 99, 0 | 79, 0 |
| `drive_two_categories.py` | 15, 0 | 15, 0 | 15, 0 |
| `anchor_resolution.py` | 41 of 41 | 69 of 69 | 69 of 69 |

The ungated columns are shorter because the nested-view checks do not apply.
Diffing the two `drive_overview.py` runs, the ungated one drops exactly "the
card says on its face that it is nested" and "the nested series really differs
from the absolute one", and nothing else.

---

## 5. Every gap that remains

Nothing here is hidden in a log. This is the whole list.

1. **The Excel export garbles the category average**, coerces category labels
   to numbers, and carries rows the reader has filtered out. Section 3.1.
   Pre-existing since April. Not fixed.
2. **The image export is JPEG bytes under a `.png` name.**
   `TurasPins.EXPORT_QUALITY` defaults to "standard", whose preset is
   `image/jpeg` at 0.85, while `exportContentAsPNG` hardcodes `.png`. It lives
   in `modules/shared/`, which this branch must not touch. Recorded, not
   fixed.
3. **The brand comparison set does not reach Branded Reach or Ad Hoc.**
   Neither carries a brand-code attribute nor subscribes to the category
   store. Audience Lens is the same but for a good reason: it is a focal-brand
   view with no brand list to narrow. `drive_destinations.py` pins this as
   `unwired` and fails the day one of them is wired, so it cannot drift.
4. **The Mental Availability and funnel panel-native pin, PNG and Excel
   controls stay**, roughly twenty per category. Ruled on in Stage 6: they are
   strictly finer than the destination toolbar (up to seven named pieces each,
   against whole leaves), the impact map scoped them out at Stage 1, and
   removing them is feature work. Reversible: Stage 6 log, ruling A.
5. **Section_Insights cannot pre-fill a destination commentary box.** Ruled on
   in Stage 6: it needs a new anchor and a rebaselined reachability gate,
   which proves less than the one that passes today. Authored text is not
   stranded meanwhile: the fixture's three authored anchors each render a leaf
   box carrying their text, checked in the generated report. Stage 6 log,
   ruling B.
6. **The three synthetic example projects still cannot run.** `examples/1brand`,
   `3cat` and `9cat` all call `.build_questions_columns()`, which exists
   nowhere in the repository. Broken on main, untouched by this programme, and
   the reason the element flag matrix drives the IPK fixture instead. A
   separate task is raised.
7. **The funnel Summary cards are unreachable**, and were before this
   programme. `.fn_cards_section()` renders them, no leaf routes to them, and
   `.fn-subnav` is hidden by CSS. Impact map section 9 item 1. Left dead
   deliberately rather than switched on as a side effect.
8. **The comparison set does not survive Save.** A checkbox's `checked` is a
   property, not an attribute, and Save serialises `outerHTML`. Stage 2
   recorded it; no commentary or pin is affected.
9. **A latent fixture bug.** `.shopper_code_list_spec()` keys the pack size
   list on `PackSizeCode` and `PackSizeLabel`; the fixture's
   `.ipk_build_packs_df()` writes `PackCode` and `PackLabel`. The QA extras
   writer emits both pairs rather than renaming the committed fixture's
   columns. Somebody should decide which name is right.
10. **The committed fixture workbooks are one cosmetic commit behind their
    generator.** Regenerating changes 15 `BRANDATT2_DSS_*` verbatim columns
    and the `Project` sheet's `project_name`, every difference an em dash
    replaced by a colon. No number differs.
11. **Nothing has been run on weighted data**, and nothing in the report layer
    reads a weight.
12. **The Portfolio tab is not a destination and was left alone**, including
    its own significance column and its "significant after BH correction"
    wording.
13. **Two of the four QA extras are invented.** Branded Reach and Ad Hoc have
    no basis in the Wave 1 instrument, which asked nothing about advertising
    and nothing study-specific. They are written only into the scratch QA
    fixture and every label says so. Shopper Behaviour and Audience Lens are
    faithful re-shapes of answers the instrument did collect.
14. **Duncan has not yet regenerated a real report through `launch_turas()`.**
    Every stage owes this and none of the sessions did it: they generate the
    IPK fixture into a scratchpad and never touch OneDrive or TurasProjects.

---

## 6. Reproducing every gate

From the worktree root. Prefix every R run with `TURAS_ROOT` set to it.

    cd /Users/duncan/Dev/Turas-brand-simplify
    export TURAS_ROOT=$PWD
    export S=/tmp/brand_qa          # any scratch directory; never a project folder

**The brand suite.** Expect FAIL 0, WARN 1, SKIP 2, PASS 3593, about two
minutes.

    Rscript -e 'testthat::test_dir("modules/brand/tests/testthat")'

**Build the three reports.** About 35 seconds. Expect 4,044,916 /
4,154,885 / 4,154,908 bytes.

    Rscript modules/brand/tests/qa/generate_qa_reports.R --out $S

**The element flag matrix.** 18 pipeline runs, about four minutes each time.

    Rscript modules/brand/tests/qa/drive_element_flags.R
    Rscript modules/brand/tests/qa/drive_element_flags.R --fixture $S/fixture_extras
    Rscript modules/brand/tests/qa/drive_element_flags.R --fixture $S/fixture_ungated

**The browser drives.** Each takes 30 seconds to two minutes and needs Chrome
at `/Applications/Google Chrome.app`.

    for r in committed extras ungated; do
      for s in drive_destinations drive_chrome drive_save_roundtrip \
               drive_overview drive_funnel_base drive_two_categories; do
        python3 modules/brand/tests/qa/$s.py $S/$r.html
      done
    done

**The capture files, and open them.** Writes a pinned-card screenshot, an
image export and a workbook.

    python3 modules/brand/tests/qa/capture_artifacts.py $S/committed.html --out $S/art
    soffice --headless --convert-to pdf --outdir $S/art $S/art/dss-buying.xls
    pdftoppm -png -r 100 -f 1 -l 1 $S/art/dss-buying.pdf $S/art/page

Then open `$S/art/pinned.png`, `$S/art/export_Summary___as_delivered.jpg` and
`$S/art/page-1.png` and look at them. The workbook page is where section 3.1
is visible.

**The numeric-identity gate.** It needs a before report, which means
generating one at the branch's base commit:

    git stash list                                  # make sure yours is clean
    git worktree add /tmp/brand-before e94c2b30
    cd /tmp/brand-before && TURAS_ROOT=$PWD Rscript \
      modules/brand/tests/qa/generate_qa_reports.R --out /tmp/before --only committed
    cd /Users/duncan/Dev/Turas-brand-simplify
    python3 modules/brand/tests/qa/reachability_check.py \
      /tmp/before/committed.html $S/committed.html
    python3 modules/brand/tests/qa/anchor_resolution.py \
      /tmp/before/committed.html $S/committed.html

Expect `Result: PASS` and `41 of 41 anchors and ids resolve to content`. Note
that `generate_qa_reports.R` exists only on this branch, so at `e94c2b30` you
will need to run `run_brand()` and `generate_brand_html_report()` by hand, or
copy the script across; the recipe is in the script's own header.

**Control counts.**

    python3 modules/brand/tests/qa/count_chrome.py $S/committed.html $S/extras.html

---

## 7. What Duncan still owes, before or after your review

1. **A `launch_turas()` run on a real project, and an eyeball.** No session in
   this programme has generated a real report. Four things to look at: the
   five destinations and the nav, the toolbar at the top of each view, the
   significance toggle reading "Significance: off", and "How this works" at
   the foot of each view. On the real four-category IPK project the funnel
   should show **separate measures with conversion ratios**, not a nested
   funnel, because that instrument did not gate.
2. **A ruling on the Excel export**, section 3.1.
3. Then the merge. Nothing here is merged and nothing is pushed.
