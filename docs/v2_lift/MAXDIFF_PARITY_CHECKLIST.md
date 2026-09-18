# MaxDiff classic report to v2 tab: parity checklist

Written 18 Sep 2026 on `feature/maxdiff-tab-parity`, off `main` at `370c2b1c`.

This is the enumeration for section 6 of
`HANDOVER_MAXDIFF_V2_FOLLOWUPS_FOR_OPUS.md`. It lists every piece of content
the classic report renders, and says for each whether the v2 tab already has
it, will get it, or is dropped with a reason.

Duncan uses this at step 3: open the classic report and the v2 tab side by
side and walk the table. Nothing is retired until he has.

Sources: `modules/maxdiff/lib/html_report/03_page_builder.R` for the panels,
`04_chart_builder.R` for the seven chart functions, `02_table_builder.R` for
the twelve table builders, `99_html_report_main.R:340-680` for what is
actually assembled. The v2 side is
`modules/tabs/lib/html_report_v2/assets/js/27y_maxdiff.js` and
`modules/maxdiff/R/13_v2_island.R`.

## The two sides as found

The classic report has seven analytical panels: Overview, Preferences, Items,
Head-to-Head, TURF, Segments, Diagnostics. It also has About, Custom Slides
and Pinned Views, which are report-shell features the v2 report already
provides in its own way and which are out of scope here.

The v2 tab has five sections in one panel: provenance, scores, TURF, anchor,
discrimination. The island carries five blocks: `meta`, `scores`,
`discrimination`, `turf`, `anchor`.

## Content inventory

Status values: HAVE (already in the tab), BUILD (this branch adds it),
DROP (deliberately not carried, with the reason).

### Panel 1, Overview

| Content | Status | Note |
|---|---|---|
| Method callout | HAVE | `provenanceHtml` |
| Stat card: Items Tested | HAVE | `meta.nItems` |
| Stat card: Respondents | HAVE | `meta.nRespondents` |
| Stat card: Top Share + item name | BUILD | derivable in the tab from `scores` |
| Stat card: Share Range, top minus bottom | BUILD | derivable in the tab from `scores` |
| Top Items share bar chart | HAVE | the scores table draws share bars in `md-barcell` |

### Panel 2, Preferences

| Content | Status | Note |
|---|---|---|
| Preference scores table | HAVE | `scoresHtml` |
| Utility score bar chart | HAVE | the same table carries the utility column |
| Anchor threshold chart | HAVE in part | `anchorHtml` draws essential-percent bars; the threshold line is not drawn. BUILD the threshold marker |
| Utility distribution, raincloud per item | BUILD | needs a new `distributions` island block carrying per-item density x and y |
| Per-segment preference share charts | BUILD | as a segment table plus one chart per segment variable, not a dropdown |
| Per-segment utility charts | DROP | the same numbers as the segment table; one view per variable is enough |
| Per-segment distribution charts | DROP | island size. Ten items times six segment levels is sixty densities |
| Per-segment anchor charts | DROP | as above |
| Segment dropdown filter | DROP | the v2 tab is frozen and hides the audience filter by design. Segments render as static tables |

### Panel 3, Items

| Content | Status | Note |
|---|---|---|
| Count scores table with discrimination | HAVE | `scoresHtml` plus `discriminationHtml` |
| Diverging best versus worst chart | HAVE | the scores table draws the `md-bwcell` diverging bar |
| Item strategy quadrant, mean against SD | BUILD | a scatter. Not covered by any existing table |
| Per-segment diverging charts | DROP | covered by the segment table |
| Per-segment quadrant charts | DROP | island size, and the aggregate quadrant carries the decision |

### Panel 4, Head-to-Head

| Content | Status | Note |
|---|---|---|
| n by n win-probability matrix | BUILD | new `headToHead` island block |
| Callout | BUILD | rewritten as a plain note, the classic prose uses em dashes |
| Per-segment H2H matrices | DROP | n squared per segment level. The aggregate matrix is the decision view |
| Segment dropdown | DROP | frozen tab |

### Panel 5, TURF

| Content | Status | Note |
|---|---|---|
| TURF step table | HAVE | `turfHtml` |
| Reach curve chart | BUILD | the table shows reach bars but not the curve's shape and plateau |

### Panel 6, Segments

| Content | Status | Note |
|---|---|---|
| Segment scores table | BUILD | new `segments` island block |
| Segment grouped bar chart | BUILD | one chart per segment variable |
| Segment base sizes | BUILD | carried as `base` so the tab can flag levels below `Min_Respondents_Per_Segment` |

### Panel 7, Diagnostics

| Content | Status | Note |
|---|---|---|
| Model Summary: method, respondents, items, segments | HAVE in part | method, respondents and items are in `meta`. BUILD the segment count |
| Sampler diagnostics: divergences, treedepth, R-hat, ESS | HAVE | added by F6 on 17 Sep, lives in `meta`. The classic never renders these either |
| Model fit: log-likelihood, AIC, BIC | ADDED | not parity. The classic never renders these, see the defects section |
| Population utility statistics: range, mean, SD, discrimination | BUILD | new `diagnostics` block |
| Model quality: mean max share, chance level, sharpness ratio, entropy ratio, heterogeneity | BUILD | new `diagnostics` block |
| Respondent utility distribution: mean, min, max range | BUILD | new `diagnostics` block |
| Item-level diagnostics table | HAVE | the scores and discrimination tables carry the per-item numbers |

## Two defects in the classic report, found while mapping

Neither is worth fixing in a report that is being retired, but both change
what parity means, so they are recorded here.

`transform_diagnostics_section()` at
`modules/maxdiff/lib/html_report/01_data_transformer.R` reads the aggregate
logit fit from `results$logit_results$fit_stats`. Nothing in the module writes
that key; `modules/maxdiff/R/06_logit.R:170` writes `model_fit`. So `logit_fit`
has always been NULL and the log-likelihood, AIC, BIC and pseudo R-squared have
never reached the report. `fit_stats` appears nowhere in the module outside
that file and one line of `docs/TECHNICAL_REFERENCE.md:295`.

Separately, `build_diagnostics_table()` at `02_table_builder.R:246` is the only
thing that would render `logit_fit` and `hb_diagnostics`, and no panel calls
it. `build_diagnostics_panel()` builds stat cards instead and never references
either. It also reads `hd$max_rhat`, which the Stan path never sets; `07_hb.R`
writes `mean_rhat`, `n_divergences` and `min_ess`.

The island therefore reads `model_fit`, and model fit is marked ADDED rather
than BUILD above. The sampler diagnostics were already added to `meta` by F6
on 17 Sep, from the field names that exist.

## What stays in the Excel deliverable

Only the per-respondent utilities. They are one row per respondent per item,
which is the whole point of the Excel file and far too large for an island
that ships inside a report. The island header comment currently also claims
HB diagnostics and the per-segment tables stay in Excel; that sentence is
rewritten by this branch.

## Charts to redraw

Duncan ruled on 17 Sep 2026 that charts are redrawn in the v2 report's own
charting, not ported from the classic 767-line `04_chart_builder.R`. The v2
tab draws nothing in SVG today; it uses CSS bar cells inside tables. Three of
the classic seven are already covered that way. Four need drawing, using the
`TR.svg` primitives in `modules/tabs/lib/html_report_v2/assets/js/03_svg.js`
and the `27z_pricing.js` inline-SVG pattern.

| Classic chart | Decision |
|---|---|
| `build_preference_chart` | covered by the scores table bars |
| `build_diverging_chart` | covered by the scores table diverging bars |
| `build_anchor_threshold_chart` | bars covered; add the threshold marker only |
| `build_turf_chart` | REDRAW, reach curve |
| `build_strategy_quadrant` | REDRAW, scatter |
| `build_segment_chart` | REDRAW, grouped bars per segment variable |
| `build_utility_distribution_chart` | REDRAW, violin from island densities |

## Dependency that dies at retirement

`.md_drop_id_cols()` is defined at
`modules/maxdiff/lib/html_report/01_data_transformer.R:461` and is used to
strip respondent id columns before computing densities. The whole directory
is deleted at step 4, so this helper moves into `modules/maxdiff/R/` with the
distributions work.

`compute_head_to_head()` is already at `modules/maxdiff/R/utils.R:783` and
survives retirement untouched.

## The whitelist trap, stated correctly

`.maxdiff_island_keep_arrays()` is an inverted whitelist. It lists the SCALAR
fields of each block, and wraps every OTHER field in `I()` so it serialises as
a JSON array. A new block that is not named in that list has every field
wrapped, so its scalars ship as one-element arrays and the panel reads them
wrong. Every new block adds an entry naming its scalars.

## Order, which does not change

1. Widen the island. Three new blocks plus `distributions`.
2. Widen the tab. Three new panels plus the four redrawn charts.
3. Duncan eyeballs the classic report and the v2 tab side by side against
   this checklist, through `launch_turas()`. A session does not do this.
4. Only then retire: `Generate_HTML_Report` joins `MAXDIFF_RETIRED_SETTINGS`,
   `modules/maxdiff/lib/html_report/` and `test_html_report.R` are deleted,
   and the Karoo config cell is turned off in openpyxl, never `loadWorkbook()`.
