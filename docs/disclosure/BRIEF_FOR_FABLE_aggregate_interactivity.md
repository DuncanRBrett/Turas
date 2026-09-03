# Brief for Fable: aggregate interactivity for Turas client-safe reports

Design review requested before any code is written. The ask is a design and a
recommendation, not an implementation.

## Background you need

Turas tabs produces a single self-contained HTML report. It carries several JSON
islands, of which two matter here.

`data-agg` holds the published crosstabs: every question's display rows, every
banner column, the figures as published, and each column's base.

`data-micro` holds one array position per respondent: for each question the
zero-based index of the display row their answer landed on, for each banner
variable the index of the column they fall in, plus their weight, and optional
score / box / series arrays. No identifiers, no raw strings, no free text. See
`modules/tabs/lib/microdata_writer.R`.

`data-micro` exists so the browser can recompute weighted figures when an analyst
applies a live filter or builds a custom banner. `TR.MICRO` is read in fourteen
renderer files: `20_data`, `21_stats`, `21c_confidence`, `21d_disclosure`,
`22_model`, `24_shell`, `24a_reader`, `26_filter`, `27d_diffs`, `27f_takeout_data`,
`27fa_takeout_shares`, `27q_qualitative`, `31_selftest`, `32_report`.

## The problem, demonstrated not asserted

Given only the delivered HTML, `data-micro` indices join to `data-agg` labels and
reproduce a respondent by question dataset. Verified on
`examples/integrated_demo/Output/tabs/report/Karoo_Demo_Crosstabs_report.html`
(600 respondents, 4 banner variables, 11 question arrays): about twenty lines of
Python produced rows like

```
row 0: KwaZulu-Natal, Female, 55+, Premium, weight 1,
       Q001=7 Q002=9 Q003=8 Q004=6 Q005=7 Q006=Agree Q007=Strongly agree
       Q008=Monthly Q009=In store
```

There is already an off switch, `html_report_v2_microdata = N`, which ships
`TR.MICRO = null`. It costs the live filter bar, custom and composite banners,
the Differences tab, Pattern Recognition, confidence detail, filtered qualitative
views and the Reader's computed passages. Tracking already survives it.

So today the choice is full interactivity with a reconstructable dataset, or
published tables with no interactivity. The brief is to design the middle.

## The direction we think is right, and want challenged

Ship precomputed sufficient statistics instead of respondents. Per cell, per
display row, five numbers: n, sum of weights, sum of squared weights, sum of
weight times value, sum of weight times value squared. Those support weighted
proportions, weighted means, SD, effective base, and z and Welch tests, which is
what the current engine computes.

## What we measured on the demo, which you should treat as the reality check

Four banner variables: Region 4 levels, Gender 2, Age 5, Segment 4. 113 display
rows across the report. 600 respondents.

| filtering supported | occupied cells | cells with n<5 | numbers to store |
|---|---|---|---|
| one variable at a time | 15 | 0 | 8,475 |
| any two combined | 82 | 0 | 46,330 |
| any three combined | 189 | 39 | 106,785 |
| all four combined | 139 | 89 | 78,535 |

Median occupancy of the full 4-way cube is 4 people per cell, and 89 of 139
occupied cells hold fewer than five.

The conclusion we draw, and want tested: a fully filterable cube is the
respondents in another arrangement, and the privacy gain comes entirely from
suppressing cells below a threshold at build time, not from the format. One and
two variable filtering is both cheap and genuinely safe at this sample size.

## Questions we want your view on

1. Is five statistics per cell per row the right set, or is something missing for
   what Turas actually computes? Note the engine also handles allocation
   (constant-sum) questions, which publish one mean row per item, multi-mention
   questions where a respondent occupies several rows, top and bottom box scores,
   NPS bands, and composite banners built from several questions.

2. Where should the cut be? Our instinct is to precompute one-way and two-way
   margins over the declared banner and filter variables only, and refuse three
   or more. Is there a better rule, for example a build-time decision driven by
   actual occupancy rather than a fixed order limit?

3. The suppression rule. Suppressing a cell below k is not sufficient on its own:
   a suppressed cell can be recovered by subtraction from the margins that
   remain. Turas already knows this. `22_model.js:655` says "complementary
   subtraction suppression across a banner group is the next increment". What is
   the right rule here that is defensible without being so aggressive it empties
   the report?

4. Custom banners. The "+ Custom" feature lets an analyst build a banner from any
   question in the study, which makes the filterable variable set the whole
   questionnaire and the cube unbuildable. We think a client-safe report must
   restrict live filtering to declared banner and filter variables. Is there a
   design that keeps more than that without reopening the disclosure hole?

5. Is there a fundamentally better approach we have not considered? We are aware
   of, and are not proposing, a server round trip. These reports are single
   files sent by email and must work offline forever.

## Acceptance criteria we would hold the build to

A figure computed from the cube must equal the figure the current microdata
engine computes, to displayed precision, across weighted and unweighted,
percentages and means, every question type, and both significance tests. The
existing JS gate suite and the R testthat suites are the harness.

And the disclosure test: given only the delivered HTML, no respondent by question
dataset can be reconstructed, and no individual's answers can be recovered by
arithmetic across the shipped aggregates.

## Out of scope for this brief

The qualitative layer, which already removes text and k-anonymises demographic
tags in R before anything ships. The IP and obfuscation work, which is a separate
brief. And SACS specifically, which turns out to need only non-interlocking
single-variable banners and can therefore ship on the published tables with no
cube at all.
