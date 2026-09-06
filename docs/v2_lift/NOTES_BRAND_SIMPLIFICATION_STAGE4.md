# Brand simplification, Stage 4 implementation log

**Date:** 6 September 2026. Worktree `/Users/duncan/Dev/Turas-brand-simplify`,
branch `feature/brand-funnel`, cut from main at 29bae816.
Scope: the funnel. This is the only stage that changes a number on the page.

Brief: the Stage 4 task message, against
`docs/v2_lift/HANDOVER_BRAND_SIMPLIFICATION_FOR_OPUS.md` section 5,
`docs/v2_lift/BRIEF_BRAND_SIMPLIFICATION_2026-09-04.md` section 2, and the
Stage 2 and Stage 3 logs.

## Baseline, executed before the first edit

- Brand suite: `TURAS_ROOT=/Users/duncan/Dev/Turas-brand-simplify Rscript -e
  'testthat::test_dir("modules/brand/tests/testthat")'` gave
  **FAIL 0, WARN 1, SKIP 2, PASS 3077**, 90.0 s. Matches the brief.
- IPK fixture report generated and kept as the before baseline: `run_brand()`
  on `modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx` with
  `project_root` = the fixture directory, then `generate_brand_html_report()`
  to the scratchpad. Status PASS, **3,989,976 bytes**, which is the byte count
  the Stage 3 log recorded at its tip. Nothing was written into the repo or
  into any project folder.

## The problem, restated from the code rather than the brief

`derive_funnel_stages()` in `modules/brand/R/03a_funnel_derive.R` builds each
stage from its own survey response and does **not** AND it into the next. The
comment in its loop says so and gives the reason (a 2026-05-24 change: the
cumulative AND was dropping about 11pp of IPK POS past-three-month buyers
against the raw count). So the aggregate funnel is not nested, and a later
stage can read higher than an earlier one.

Three things then contradicted each other on the same page:

1. the figures, where preference could exceed awareness;
2. `.FUNNEL_DEFAULT_DEFINITIONS`, whose consideration entry read "Aware
   respondents who actively prefer the brand" and whose three behaviour
   entries each claimed to be gated on the stage before them;
3. two roxygen blocks in the same file, one on `derive_funnel_stages` saying
   "Every stage after the first ANDs the previous stage's matrix, so nesting
   is guaranteed by construction", and one on `validate_nesting` saying a
   violation "indicates a logic bug, never operator error". The body of
   `validate_nesting` says the opposite, in its own v3 note.

## The arithmetic, proved before anything was written

The denominator is `meta$n_weighted`, which `.funnel_meta()` in
`R/03_funnel.R` sets to `sum(weights)`, the same denominator `pct_weighted`
already divides by. So:

    nested % at stage k  ==  base_chain_filtered[k] / n_weighted

Read off the baseline report's own funnel island before any code changed
(`stage4/probe_chain.py`), focal brand IPK in Dry Seasonings and Spices,
n_weighted 438:

| stage | chain count | nested % | absolute % |
|---|---|---|---|
| Aware | 405 | 92.5 | 92.5 |
| Prefer | 293 | 66.9 | 66.9 |
| Past 12 months | 195 | 44.5 | 62.3 |
| Past 3 months | 142 | 32.4 | 45.0 |

with two identities the same probe checked: at the first stage the nested
figure equals the absolute one (to the payload's six decimals), and
`chain[k] / chain[k-1]` equals the engine's `pct_nested_filtered` to 2.1e-07.

## Before and after, every category in the fixture

The IPK fixture carries nine categories. **Only Dry Seasonings and Spices has
a funnel**; the other eight have no funnel block at all (awareness-only
categories), so there is nothing to move in them. Read off the baseline
results object:

| category | funnel |
|---|---|
| Dry Seasonings & Spices | yes, focal IPK, n_weighted 438 |
| Pour Over Sauces | none |
| Pasta Sauces | none |
| Baking Mixes | none |
| Salad Dressings | none |
| Stock Powder / Liquid | none |
| Pestos | none |
| Cook-in Sauces | none |
| Anti-pasta | none |

Dry Seasonings and Spices, every brand, Aware / Prefer / Past 12 months /
Past 3 months, rounded as the table rounds them:

| brand | before, each stage on its own | after, nested funnel |
|---|---|---|
| IPK (focal) | 92 / 67 / 62 / 45 | 92 / 67 / 45 / 32 |
| ROB | 85 / 31 / 31 / 15 | 85 / 31 / 11 / 5 |
| KNORR | 85 / 31 / 29 / 16 | 85 / 31 / 11 / 5 |
| CART | 75 / 26 / 30 / 13 | 75 / 26 / 12 / 5 |
| CHS | 77 / 31 / 26 / 13 | 77 / 31 / 12 / 7 |
| FNF | 73 / 26 / 23 / 14 | 73 / 26 / 7 / 4 |
| WWT | 68 / 25 / 23 / 12 | 68 / 25 / 9 / 5 |
| PNP | 66 / 22 / 23 / 11 | 66 / 22 / 7 / 4 |
| SSG | 58 / 19 / 21 / 11 | 58 / 19 / 8 / 5 |
| RAJ | 50 / 16 / 16 / 7 | 50 / 16 / 6 / 3 |
| SAF | 50 / 21 / 16 / 7 | 50 / 21 / 8 / 3 |
| SPM | 43 / 13 / 14 / 7 | 43 / 13 / 5 / 3 |
| CHK | 39 / 15 / 13 / 6 | 39 / 15 / 6 / 2 |
| HND | 34 / 12 / 14 / 7 | 34 / 12 / 5 / 2 |
| DEL | 25 / 10 / 10 / 5 | 25 / 10 / 4 / 2 |
| Category average row | 61 / 24 / 23 / 13 | 61 / 24 / 10 / 6 |

Two things to expect when reading these. The first two stages are unchanged
for every brand, because on this data preference is a subset of awareness, so
the chain has not bitten yet. The behaviour stages fall a long way, most of
all for the smaller brands, because a brand that many people say they bought
without having named it as known loses those respondents from the chain.
That is the honest reading of the same data, not a new computation.

The brief quotes IPK Baking as 34 / 23 / 15 / 12. That is the real IPK
project report, not this fixture, and this session never opened it.

## What was built

### The funnel panel

- A fourth base view, `chain`, made the default. It is derived from
  `base_chain_filtered` and `meta.n_weighted`, both already in the panel
  payload, so **no number was added to the funnel island**. The reachability
  gate confirms it: `fn-panel-data` is numerically identical before and after.
- The four labels, in toggle order: **Funnel, % of all** (default), **Each
  stage on its own**, **% of previous stage**, **% of those aware**. The word
  funnel appears on the nested one only, which a test asserts button by
  button.
- R renders the table, the counts and the summary cards in the default view,
  so the emitted file reads correctly before any script runs and when it is
  printed. The JS default (`pctMode: "chain"`) only has to agree with what R
  wrote.
- Every mode-dependent site in `brand_funnel_panel.js` gained the branch: the
  cell text, the heatmap and CI shading, the base row, the per-cell counts,
  the mini funnels, the slope chart, the bar chart, the sort attributes, the
  category-average range bars and the Excel export.

### Three things the first cut of this stage got wrong

All three were found by an independent review of the session's own work and
are fixed, with a check each.

1. **The category-average row's range bar was left at the absolute base.**
   The cell's figure moved to the chain but the bar behind it, its tick and
   its lo/hi labels did not, so on the fixture a mean of 6% sat inside a band
   of 8% to 17%. `.fn_chain_stats_by_stage()` now returns the mean, the CI
   bounds and the column maximum together and the whole cell is drawn at one
   base; `updateAvgRowRangeBars()` is called once at init as well as on every
   toggle. A testthat case asserts the figure sits inside its own band, and
   `drive_funnel_base.py` asserts it in the browser in all four views.
2. **The bar chart read `pct_absolute` whatever the toggle said.** It was not
   in the grep of mode-dependent sites because it builds its own value map.
   Under the nested default that meant the Bar view contradicted the table
   above it on every report. It now reads `cellValueForMode()`, its
   category-average reference line follows, and the base toggle repaints
   whichever chart view is on screen rather than always the slope chart. The
   drive script checks the bar figure at a LATE stage, where the chain and
   the absolute figure are different numbers, so a chart that ignored the
   toggle would fail.
3. **The bar chart's title said "% of total respondents" in every view**, and
   indexed the stage-label array by key rather than by position, so it titled
   itself with the raw stage key. Both fixed in the same string; the title now
   reads, for example, "Past 3 months: the nested funnel, % of all
   respondents".
- A collapsed "How this works" under the toggle explains the four views and
  the missing significance mark. It sits outside `.fn-controls` on purpose:
  the controls bar is hidden in print and a printed page cannot be opened.

### Significance

The table carries two marks and they are different things.

- The **triangle** is the engine's `sig_vs_avg`, a test of one brand against
  the category average computed on each stage's own base. It never moved with
  the toggle and still does not.
- The **arrow** is `applyTableSigMarkers()`, a comparison against the spread
  of brands at whichever base is active. It recomputes on every toggle.

Neither was computed on the chain, so the nested view shows neither. The
triangle is **left out of the markup** rather than hidden with CSS: TurasPins'
capture inliner skips values it reads as defaults, `display: none` among them
(`modules/shared/js/turas_pins_utils.js`, and the note in the project
CLAUDE.md), so a hidden badge would come back on a pinned card or a PNG. The
direction rides on the cell as `data-fn-sig-avg` and `applySigBadges()` writes
the badge back in the three views the test belongs to.

### Everything downstream names its view

- **Excel**: the export already wrote a `Base:` row above the header. Each
  view now spells out its computation there, not just its name.
- **Pin and PNG**: `brReadBaseLabel()` in `brand_pins.js` reads the active
  button's text out of the `.sig-level-switcher` labelled "Base:", and that
  becomes the pin subtitle and the PNG meta line. The labels were written to
  read correctly after the word "Base:" for that reason, and the switcher's
  prefix was left alone because `brReadBaseLabel` matches on it.
- **The summary card strip** sits on a different sub-tab from the toggle, so
  it carries its own base line, filled by R in the default view and updated by
  the JS on every change.

### The Overview

The Stage 3 mini funnel drew the absolute series. Left alone it would have
shown 92 / 67 / 62 / 45 on a card titled "Buying funnel" while the funnel
destination showed 92 / 67 / 45 / 32, from one dataset, with nothing on the
page saying which was which. It now draws the nested chain, and
`biggestFunnelDrop()` reads the same series, so the sentence under the card
always describes the funnel the card drew.

## The one number added to a payload, and the gate

`reachability_check.py` asserts every JSON island's numeric content is
identical. The funnel panel needed nothing from it. **The Overview did.**

The `brsum-data` island carried only `pct_weighted` per stage. The chain count
is not in it and cannot be derived from percentages. Reading the funnel
panel's island from the Overview was considered and rejected: it would couple
the Overview to the funnel panel's presence in the DOM, and would fall back
silently to the absolute series whenever the funnel element is switched off,
which is the same defect in a quieter form.

So `.brsum_funnel_minif()` now writes three fields per category:
`funnel.brands_nested`, `funnel.cat_avg_nested` and
`funnel.base_label_nested`. On the IPK fixture that is **65 numeric values**
added to one island: 15 brands times 4 stages, plus the 4 category averages,
plus the base count inside the new label string.

The gate was changed deliberately rather than quietly. It now carries an
`ADDITIVE` allowlist with the reason written into it, and for a class on that
list it requires the old payload's numbers to still all be present **in
order**, prints how many were added and lists them. Every other class stays
on exact equality, and a number that disappears is still a failure everywhere.
The run reports:

    brsum-data: numeric content GREW, nothing lost (+65 values)

## Decisions taken, with reasons

1. **Four views, not three.** The task message named three labels. Dropping
   "% of previous stage" would delete a working analysis, which section 9 of
   the handover forbids, and it is a legitimate conversion read on the same
   chain the nested view uses. It was kept and relabelled. **Duncan may veto
   this**; removing it is a one-line change plus its branches.
2. **Mode key `chain`, not `nested`.** The payload field `pct_nested` already
   means percentage of the previous stage. A second meaning for the same word
   inside one file would have collided.
3. **The nested figure is derived in R for the table and in JS for the
   toggle**, from the same two payload fields. R renders the default so the
   file is right before any script runs; the JS recomputes when the reader
   toggles. A test asserts the two defaults agree.
4. **The category average at the chain base is the per-brand figure averaged
   across brands**, which is the convention `.avg_all_brands_row()` already
   uses for the other three views. Not the pooled chain over one base. The
   difference is asserted.
5. **The summary cards' category average stays the mean over the NON-focal
   brands**, which is what `.card_for_stage()` computes and is a different set
   from the table's Category average row. The two have always disagreed and
   this stage did not change it; changing it would have moved a figure in the
   absolute view that nobody asked to move.
6. **The cards drop their significance direction after a focal switch.** The
   card's `sig_vs_avg` is the `focal_vs_cat_avg` comparison, computed for the
   report's own focal brand, and it is a different test from the per-brand one
   the table cells carry. Before this stage a focal switch left the old
   brand's badge in place. It now clears rather than mislabels. This is a
   change beyond the brief, and a small one, but the alternative was to
   preserve a wrong mark.
7. **The headline purchase tile on the Overview stays absolute.** It is a
   penetration figure, which is what the rest of the report means by
   penetration, and moving it would change a number nobody asked to change.
   The Overview's "How this works" drawer now carries a paragraph saying why
   the tile and the funnel card differ.
8. **The "Which penetration is which" table was not touched.** It is
   category-level and states that it does not change with the selected brand;
   the nested figure is per brand, so it does not fit that table's contract.
9. **Two stale roxygen blocks in `03a_funnel_derive.R` were corrected** along
   with the definitions. They made the same false nesting claim. Comment-only,
   no behaviour change, in the one engine file already in scope.
10. **The definitions carry no digits.** They ride in the funnel payload and
    the gate reads every number in it, so a digit in a definition would read
    as a changed number. A test asserts it.

## Deviations and losses, logged

- **The shared callout was not edited.** The funnel's main explainer lives in
  `modules/shared/lib/callouts/callouts.json` under `brand.funnel`, and this
  stage may not touch `modules/shared`. That text still describes three base
  toggles and still says Turas "refuses to render a brand whose aggregate
  counts violate nesting", which `validate_nesting()` stopped doing in
  May 2026. **Owed:** someone with the Callout Editor should bring it in line;
  it is the one place on the page that now under-describes the control.
- **The relationship sub-tab's own base default was left on % of total.** Its
  rows are the six attitude positions, not funnel stages, so there is no chain
  to nest. Only the stale comment beside it was corrected.
- **The triangle badge still shows in the "% of previous stage" and "% of
  those aware" views**, where it is the engine's verdict about a different
  figure from the one on screen. That is pre-existing, it is not what this
  stage was asked to fix, and changing it would alter what an analyst sees in
  a view Duncan says his analysts use routinely. It is written into the
  "How this works" drawer as it stands ("computed on each stage's own base
  whichever view is showing") rather than left silent. **Owed as a ruling.**
- **The `data-fn-sort-<k>` legacy attribute and `data-sort-val` still hold
  the absolute figure.** They are the fallback path in `setSort()`; the active
  view reads `data-fn-sort-<k>-chn`. Left as they were.
- **The four-button switcher is wider than the three-button one** and will
  wrap on a narrow window. `.fn-meta-row` already wraps, so it wraps cleanly.
- **`.fn_sig_badge()` in `03_funnel_panel_table.R` is now dead code.** Nothing
  calls it: the cell emits the direction as an attribute and the JS writes the
  badge. Its twin of the same name in `03_funnel_panel.R` is dead too. Both
  left in place rather than removed in a stage about numbers.
- **The pre-written funnel workbook was not touched.** `99_output.R` writes a
  `funnel_<cat>.xlsx` next to the report, and `01_data_transformer.R` still
  passes its filename to the panel as `data-fn-excel-filename`. Nothing reads
  that attribute any more: the Export button always calls `exportTable()`,
  the in-browser path this stage labelled, so what an analyst downloads from
  the report is labelled. The workbook on disk is an engine output, carries
  the unnested figures and has no view label. Out of scope for this stage.
  **Owed as a ruling**, together with the stale comment at the top of
  `brand_funnel_panel.js` that still describes the download path.
- **The weighted-data test landed in the Overview commit** (e8c582c5) rather
  than the funnel one, because a `git add -A` swept it in. Noted rather than
  rewritten into history.

## Executed, with the numbers

| Check | Result |
|---|---|
| Brand suite, before the first edit | FAIL 0, WARN 1, SKIP 2, PASS 3077 |
| Brand suite, at the tip | FAIL 0, WARN 1, SKIP 2, PASS 3247 |
| `node modules/brand/tests/js/test_funnel_nested.js` | 40 passed, 0 failed |
| `node modules/brand/tests/js/test_summary_overview.js` | 116 passed, 0 failed (101 before) |
| `reachability_check.py before after` | PASS. data-subpanel 5, data-section 29, section ids 13, all identical; 7 of 8 island classes numerically identical, `brsum-data` grew by 65 values with nothing lost |
| `drive_funnel_base.py after.html` | 95 checks, 0 failed, no console error |
| `testthat::test_file("test_funnel_nested_default.R")` | 139 assertions, 0 failed |
| `testthat::test_file("test_summary_funnel_step.R")` | 34 assertions, 0 failed |
| `drive_overview.py after.html` | 60 checks, 0 failed |
| `drive_destinations.py after.html` | 353 checks, 0 failed |
| `drive_save_roundtrip.py after.html` | 113 checks, 0 failed |
| `drive_two_categories.py after.html` | 15 checks, 0 failed |
| IPK fixture report | PASS, 4,020,334 bytes against 3,989,976 before |

`drive_funnel_base.py` is new. It clicks all four toggles in headless Chrome
and, for each, reads the figures off the screen and compares them with the
panel's own JSON island, computed independently in the harness rather than
read out of the markup the island produced. It also asserts the chain never
rises, that the two views actually differ on this report (so a toggle that
silently did nothing would fail), that no significance mark of either kind is
on screen in the nested view while the other views do carry them, that the
card strip names its base in every view, that the drawer opens and closes,
that the Excel export's base row names the nested view, that the
category-average figure sits inside its own range band in every view, and
that the bar chart carries the right figure and names its base and its stage
at a late stage where the chain and the absolute figure differ. On the
fixture:

    chain     Funnel, % of all         92% 67% 45% 32%
    total     Each stage on its own    92% 67% 62% 45%   marks=35
    previous  % of previous stage      100% 72% 67% 73%  marks=19
    aware     % of those aware         100% 72% 67% 49%  marks=12

## Known limits, stated rather than left to be discovered

- **Nothing here has been executed on weighted data.** The IPK fixture is
  unweighted, so `n_weighted` equals `n_unweighted` and every chain count is a
  head count. The formula divides a weighted count by `sum(weights)`, which is
  the same pair `pct_weighted` uses, and a unit test drives
  `calculate_stage_metrics()` with eight respondents on unequal weights and
  asserts the chain is a weighted proportion, is monotone, is not the head
  count over n, and drops a respondent who bought a brand without naming it
  as known. But no weighted report has been rendered in this session.
- **One category carried a funnel.** Eight of the fixture's nine categories
  have no funnel block, so the multi-funnel case (several panels, several
  toggles, one page) is covered by the shell tests from Stage 2 rather than by
  a fixture with two funnels.
- **No brand in the fixture carries a significant cell from the engine.**
  Every `data-fn-sig-avg` on the generated report reads `na`, so the triangle
  path is proved by the node and testthat assertions and by
  `drive_funnel_base.py`'s arrow counts, not by a triangle rendered on real
  data.
- **The example configs still do not render, on this branch or on main.**
  They were rebuilt from their own generators in this session and all three
  then refuse inside `run_brand()`'s data loading, before any report-layer
  code runs, with the message that the column-per-brand format is deprecated
  and the fixture should be regenerated. The Stage 2 log records the same
  breakage and raised a separate task for it. Nothing in this stage touches
  that path, and nothing in this stage has therefore been exercised against
  those three element mixes except through the unit tests Stage 2 wrote for
  them.
- **No PPTX or pin was exported and opened.** The pin and PNG base line is
  read from the active toggle by `brReadBaseLabel()`, which
  `drive_funnel_base.py` exercises indirectly through the button labels, and
  the Excel base row is captured and read in that run. A pinned card was not
  opened in a browser.

## What Duncan still owes

1. **A `launch_turas()` run on a real project, and an eyeball of the funnel.**
   This session generated the IPK fixture into a scratchpad only, and never
   touched OneDrive or TurasProjects. The numbers on a real report will move
   the way the table above moves: the first stages unchanged, the behaviour
   stages lower.
2. **A ruling on the fourth view.** The task message named three labels; this
   build kept "% of previous stage" as a fourth rather than delete an
   analysis. Say if it should go.
3. **A ruling on the triangle in the "% of previous stage" and "% of those
   aware" views**, which is the same defect this stage fixed in the nested
   view, one step out.
4. **The shared callout text**, which still describes three toggles.
5. Then a Fable pre-merge review, briefed as independent of this session.

**Not merged and not pushed.** Branch `feature/brand-funnel`, on top of
29bae816.
