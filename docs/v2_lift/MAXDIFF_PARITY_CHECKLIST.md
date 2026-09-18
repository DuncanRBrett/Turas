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

Status values: HAVE (was already in the tab before this branch), DONE (this
branch added it), DROP (deliberately not carried, with the reason). Everything
marked DONE was built and gated on 18 Sep 2026; see the status section at the
end.

### Panel 1, Overview

| Content | Status | Note |
|---|---|---|
| Method callout | HAVE | `provenanceHtml` |
| Stat card: Items Tested | HAVE | `meta.nItems` |
| Stat card: Respondents | HAVE | `meta.nRespondents` |
| Stat card: Top Share + item name | DONE | derivable in the tab from `scores` |
| Stat card: Share Range, top minus bottom | DONE | derivable in the tab from `scores` |
| Top Items share bar chart | HAVE | the scores table draws share bars in `md-barcell` |

### Panel 2, Preferences

| Content | Status | Note |
|---|---|---|
| Preference scores table | HAVE | `scoresHtml` |
| Utility score bar chart | HAVE | the same table carries the utility column |
| Anchor threshold chart | DONE | corrected 18 Sep: `anchorHtml` is a plain table with no bars at all. It gets bars and a threshold marker |
| Utility distribution, raincloud per item | DONE | needs a new `distributions` island block carrying per-item density x and y |
| Per-segment preference share charts | DONE | as a segment table plus one chart per segment variable, not a dropdown |
| Per-segment utility charts | DROP | the same numbers as the segment table; one view per variable is enough |
| Per-segment distribution charts | DROP | island size. Ten items times six segment levels is sixty densities |
| Per-segment anchor charts | DROP | as above |
| Segment dropdown filter | DROP | the v2 tab is frozen and hides the audience filter by design. Segments render as static tables |

### Panel 3, Items

| Content | Status | Note |
|---|---|---|
| Count scores table with discrimination | HAVE | `scoresHtml` plus `discriminationHtml` |
| Diverging best versus worst chart | HAVE | the scores table draws the `md-bwcell` diverging bar |
| Item strategy quadrant, mean against SD | DONE | a scatter. Not covered by any existing table |
| Per-segment diverging charts | DROP | covered by the segment table |
| Per-segment quadrant charts | DROP | island size, and the aggregate quadrant carries the decision |

### Panel 4, Head-to-Head

| Content | Status | Note |
|---|---|---|
| n by n win-probability matrix | DONE | new `headToHead` island block |
| Callout | DONE | rewritten as a plain note, the classic prose uses em dashes |
| Per-segment H2H matrices | DROP | n squared per segment level. The aggregate matrix is the decision view |
| Segment dropdown | DROP | frozen tab |

### Panel 5, TURF

| Content | Status | Note |
|---|---|---|
| TURF step table | HAVE | `turfHtml` |
| Reach curve chart | DONE | the table shows reach bars but not the curve's shape and plateau |

### Panel 6, Segments

| Content | Status | Note |
|---|---|---|
| Segment scores table | DONE | new `segments` island block. The classic table is broken, see the defects section |
| Segment grouped bar chart | DONE | one chart per segment variable. The classic chart draws nothing at all |
| Segment base sizes | DONE | carried as `base` so the tab can flag levels below `Min_Respondents_Per_Segment` |

### Panel 7, Diagnostics

| Content | Status | Note |
|---|---|---|
| Model Summary: method, respondents, items, segments | HAVE in part | method, respondents and items are in `meta`. BUILD the segment count |
| Sampler diagnostics: divergences, treedepth, R-hat, ESS | HAVE | added by F6 on 17 Sep, lives in `meta`. The classic never renders these either |
| Model fit: log-likelihood, AIC, BIC | DONE (addition) | not parity. The classic never renders these, see the defects section |
| Population utility statistics: range, mean, SD, discrimination | DONE | new `diagnostics` block |
| Model quality: mean max share, chance level, sharpness ratio, entropy ratio, heterogeneity | DONE | new `diagnostics` block |
| Respondent utility distribution: mean, min, max range | DONE | new `diagnostics` block |
| Item-level diagnostics table | HAVE | the scores and discrimination tables carry the per-item numbers |

## Three defects in the classic report, found while mapping

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

Third, the whole Segments panel is broken. `transform_segments_section()`
passes `results$segment_results` straight through, which is the two-element
list `list(segment_scores, segment_summary)` that `08_segments.R` returns.
`build_segment_table()` expects a named list of per-variable wide frames, so it
iterates those two names and prints them as the client-facing headings,
"segment_scores" and "segment_summary", with Times_Shown, Times_Best,
Times_Worst, Rank, Segment_N and N as its columns. No segment level appears
anywhere in it. `build_segment_chart()` looks for wide `BW_Score_<level>`
columns, which nothing in the module produces, so it returns an empty string
and no chart is drawn.

Both were run against the real long-format shape on 18 Sep 2026 to confirm
this rather than infer it. The per-segment variants inside the Preferences and
Items panels are a different path and do work: they use
`enrich_segment_scores()` on `html_data$segment_filter$segment_scores`. Those
are the ones dropped above on the frozen-tab grounds.

So the island's `segments` block is a build, not a port. There is no working
classic behaviour to match.

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
| `build_anchor_threshold_chart` | REDRAWN as bars with a threshold marker. An earlier line here said the bars were already covered; they were not |
| `build_turf_chart` | REDRAWN, reach curve |
| `build_strategy_quadrant` | REDRAWN, numbered scatter with a key |
| `build_segment_chart` | REDRAWN, grouped bars per segment variable |
| `build_utility_distribution_chart` | REDRAWN, violin from island densities |

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

## Status, 18 Sep 2026

Stages 1 and 2 are complete on `feature/maxdiff-tab-parity`. Stage 3 is
Duncan's, and stage 4 waits on it.

The island grew four blocks in `modules/maxdiff/R/13_v2_island.R`:
`diagnostics`, `headToHead`, `segments` and `distributions`.
`MAXDIFF_ISLAND_VERSION` is 1.1.0; the schema number did not move because the
change is purely additive. Each block has its own tests in
`modules/maxdiff/tests/testthat/test_v2_island.R`, including the F2 case of a
length-1 per-row field, and every one of them failed on the code as found.

The tab grew four panels in
`modules/tabs/lib/html_report_v2/assets/js/27y_maxdiff.js`: item strategy,
utility distributions, head-to-head and scores by segment, plus model
diagnostics, and four charts drawn in `TR.svg`. The gate is
`modules/tabs/tests/js/test_maxdiff_parity_panels.mjs`, 45 checks against the
shipped JS in a vm.

Three problems were found by rendering the tab to HTML and looking at it, not
by the gate. The TURF chart clipped its last axis label. The quadrant
truncated every item label to 22 characters, so an item read as a different
item; it now numbers its points against a key. The head-to-head matrix used
full item labels as column headers, which made a ten-item matrix several
screens wide; columns are numbered to match the rows. Two smaller ones came
from the same look: the diagnostics panel printed the same number twice, as
"Utility spread" and "Heterogeneity", and the quadrant silently dropped the
reference item, which has no spread to place. Both are fixed and gated.

### What Duncan does next, stage 3

Generate a MaxDiff project through `launch_turas()` with both
`Generate_HTML_Report` and the v2 report on. Open the classic report and the
MaxDiff tab of the v2 report side by side and walk the tables above. Anything
marked DONE that is not there, or is there and wrong, comes back to a session.
Anything marked DROP that you want after all is a scope decision, not a bug.

Only after that does stage 4 run: `Generate_HTML_Report` joins
`MAXDIFF_RETIRED_SETTINGS`, `modules/maxdiff/lib/html_report/` and
`test_html_report.R` are deleted, and the Karoo config cell is turned off in
openpyxl, never `loadWorkbook()`.
