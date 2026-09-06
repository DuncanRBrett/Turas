# Brand: a number check for authored analyst insights

**Date:** 6 September 2026. Worktree `/Users/duncan/Dev/Turas-brand-simplify`,
branch `feature/brand-insight-number-check`, cut from main at 088736c9.
Scope: `modules/brand` plus this log. No file outside those was touched.

## The problem, as observed

Stage 4 made the funnel open on the nested chain. On Duncan's real IPK report
the Dry Seasonings table then read aware 42, prefer 35, past 12m 22, past 3m
16. Directly above it sat an analyst insight reading:

> Aware 42%, prefer 59%, past 12m 31%, past 3m 20%. Below category average
> (47% / 64% / 39% / 27%) at every stage. Prefer (59%) exceeds aware (42%) by
> 17pp.

Every figure past the first is the old absolute view, and the last sentence
asserts something the table now visibly contradicts.

That text is not generated. It comes from the `Section_Insights` sheet in the
config workbook, loaded by `modules/brand/R/01b_section_insights.R`, which
logs "Loaded 12 insights from Section_Insights sheet". It was true when it was
written, it is wrong now, and nothing checked it.

## Baseline, executed before the first edit

- Brand suite, from the repo root:
  `TURAS_ROOT=/Users/duncan/Dev/Turas-brand-simplify Rscript -e
  'testthat::test_dir("modules/brand/tests/testthat")'` gave
  **FAIL 0, WARN 1, SKIP 2, PASS 3247**, 91.9 s. Matches the brief.
- IPK fixture report generated to the scratchpad and kept as the before
  baseline: `run_brand()` on the fixture config with `project_root` = the
  fixture directory, then `generate_brand_html_report()`. Status PASS,
  **4,020,334 bytes**, `$warnings` empty. Nothing written into the repo or into
  any project folder.
- `git status --short` clean at the start; the worktree is
  `feature/brand-insight-number-check` at 088736c9.

## What was built

`modules/brand/lib/html_report/03b_insight_number_check.R`, sourced from the
`layer_file` vector in `99_html_report_main.R`. That vector is a whitelist in
the same class as `.source_brand_module()`: a new file that is not in it is
never loaded in production while tests that source it directly still pass.

The check runs inside `generate_brand_html_report()`, between the panel
transform and page assembly. It has to run there and not in `run_brand()`,
because the funnel's nested figures are derived at render time by
`panels/03_funnel_panel_table.R`, which the report generator sources.

Reporting, three ways, in order of who sees it:

1. **Console box** in the CLAUDE.md shape. Turas runs inside a Shiny app and
   the operator debugs from the R console.
2. **Run warning**, appended to `generate_brand_html_report()`'s `$warnings`,
   which is what `brand_gui_outcome()` puts in front of the operator.
3. **A marker in the HTML**, a `.br-insight-check` div rendered inside the
   insight container, next to the sentence, so the reader of the report knows
   the note was not checked out rather than only the operator seeing it in a
   terminal.

It never refuses. Every path is wrapped: an unreadable section, a missing
shared helper, a malformed results object, all mean the insight is left alone.
The report is still written.

## Decisions, and why

### The comparison reuses the shared helper

`deterministic_number_check()` and `extract_all_numbers()` from
`modules/shared/lib/ai/ai_verify.R`, the pair `reader_ai_prose.R` uses for AI
prose. Nothing here re-implements extraction or matching. Two things were
carried across from how the reader calls them:

- **The pool must be finite.** The helper does `any(abs(pool - n) < tol)`; one
  `NA` in the pool makes that `NA` and the check throws. `reader_ai_prose.R`
  filters for the same reason. `.bin_clean_pool()` does it here, and a test
  asserts no pool ever carries a non-finite value.
- **The pool is a plain numeric vector**, because `extract_all_numbers()` is
  the identity on one.

`ai_verify.R` sits in an `ai/` subdirectory that no brand source path recurses
into, so `.bin_ensure_shared_check()` sources it on demand from `TURAS_ROOT`,
`find_turas_root()` or the working directory, and returns FALSE rather than
failing if it cannot. `modules/shared` was read and not modified.

### Tolerance: 0.6, the shared helper's own constant

The brand tables render a percentage with `sprintf("%.0f%%", ...)`, so the
largest honest gap between a stored figure and the figure a reader sees is
0.5. An insight saying 42% against a stored 41.7 is correct and passes. 0.6
leaves a tenth of slack for an analyst who read the figure off an export at
one decimal. The fixture funnel makes the case concretely: IPK's nested past
12 months is 44.5, the table prints 45, and 45 has to pass. It does, at 0.5,
which is why the tolerance is not 0.5.

### The funnel pool is the view the report opens on, only

This is the decision that decides whether the real case is caught.

The funnel carries four views of the same counts. 59 is a real figure on
Duncan's report: it is the focal brand's absolute percentage at the preference
stage. It is a real figure the reader cannot see, because the page opens on
the nested chain. **Matching any available view would have passed the sentence
that started this**, so the pool is the opened view and nothing else.

The values come from `.fn_chain_pct()` and `.fn_chain_stats_by_stage()` in
`panels/03_funnel_panel_table.R`, the two helpers the table is rendered with,
so the check and the table cannot drift apart. The pool carries, per brand and
stage, the nested percentage and the chain count printed under it, plus the
category-average row's mean and its two range-bar bounds, plus the panel's
weighted and unweighted totals. `base_unweighted`, the stage's own raw count,
is deliberately out: it belongs to the absolute view and is not on screen.

The cells come from `.panel_table()` rather than the whole
`build_funnel_panel_data()`. `.panel_table()` builds exactly the cells the
table renders from and needs nothing from the attitude pipeline that the cards
half of the panel data pulls in, which throws when the funnel modules are only
partly sourced.

Mental Availability's sub-tabs get the same treatment by construction: their
default base mode is "total" (`02a_ma_panel_data.R:169`), and
`cep_brand_matrix` / `attribute_brand_matrix` hold the total-base percentages,
with the aware-base figures derived at render. Pooling the matrices pools the
default view.

### Which numbers are not claims about the section

A check that fires constantly is ignored and is worse than none. Four kinds of
number are left alone. The first two the shared helper already does; the rest
are masked out of the text before it reaches the helper, so the digits are
never extracted.

| Left alone | Rule | Covers |
|---|---|---|
| 0 to 10, and exactly 100 | shared helper | "top 3", "wave 2", ranks, a difference of a few points |
| 1900 to 2100, four digits | masked as a year | "the 2026 wave, up on 2023" |
| a number carrying a difference unit | masked: `pp`, `ppt`, `pts`, `points`, `percentage points` | "17pp", "down 7 points" |
| a base quoted inline | masked: `n=1,200`, "base of 1,200" | a base quoted from another section |

On differences: the alternative was to pool every pairwise difference of the
section's figures so a derived "by 17pp" would match. On a 15 brand by 4 stage
funnel that is roughly 1,800 differences over a 0 to 100 range, which would
cover nearly every integer and gut the check. Masking the difference and still
checking the two levels either side is strictly better, and it is what catches
the real case: 17pp is left alone, while the 59 it is derived from is flagged.

Thousands separators are stripped first. The shared regex reads "1,200" as 1
and 200; percentages, decimals and signs it already handles.

### Cross-cutting anchors are not checked

`_EXECUTIVE_SUMMARY`, `_BACKGROUND` and `summary-cards` quote figures from
anywhere in the report by design. A section pool would fire on every sentence
and a report-wide pool would pass every sentence. They are skipped, and the
skip is stated here rather than pretended away. An anchor with no data mapping
behind it, including an unrecognised one the loader passed through, is skipped
the same way.

### The known limit: a dense section pool

The pool is the whole section, all brands, because the insight box sits under
a table that shows all brands and an analyst may legitimately write about a
competitor. Restricting the pool to the focal brand would fire on correct
sentences, which is the failure mode the brief calls worse than none.

The cost is measurable. On the IPK fixture's funnel, 15 brands by 4 stages,
111 pool values: of the integers 11 to 99, **40 are outside the pool and 49
are inside it**, so an arbitrary wrong integer is caught a little under half
the time. This does not weaken the case the check exists for, where the stale
figures came from a different view of the same brand and the whole set of them
was outside the opened view's pool. It does mean the check is a net, not a
proof. It is stated in the module header and asserted in a test comment so the
next reader does not over-trust it.

## Verification, executed

### Duncan's exact case

`modules/brand/tests/testthat/test_insight_number_check.R` rebuilds it: a
funnel result whose focal brand's nested chain is 42 / 35 / 22 / 16 and whose
absolute view is 42 / 59 / 31 / 20, a weighted total of 1000 so the chain
counts are exact, and a second brand so the category-average row has something
to average. The pool is built by the real pool builder from a real results
shape, not hand-fed to the shared helper.

Fed the sentence quoted at the top of this log, the check **flags 59, 31 and
20** (and 47, 64, 39 and 27, the equally stale category averages), and does
**not** flag 42, the one figure still right. Asserted directly:

    expect_true(all(c("59", "31", "20") %in% figs))
    expect_false("42" %in% figs)
    expect_false(any(abs(pool - 59) < 0.6))   # the absolute view is not pooled

The same note rewritten on the nested figures produces zero findings.

### No false positive on the fixture's own authored insights

The IPK fixture's `Brand_Config.xlsx` had no `Section_Insights` sheet, so
there was nothing for the check to run over on a real generation.
`ipk_write_brand_config()` in
`modules/brand/tests/fixtures/ipk_wave1/07_structure_writers.R` now writes
one: four entries, an executive summary and three anchored to real sections
(`funnel-dss`, `ceps-dss`, `wom-dss`), every figure read off an actual
`run_brand()` on this branch. The funnel note quotes the nested chain, IPK at
92 / 67 / 45 / 32 against a category average of 61 then 24, which is what the
funnel page opens on.

Only `Brand_Config.xlsx` was regenerated, through the writer's own
`createWorkbook()` path, so the `loadWorkbook()` round-trip trap does not
apply. The file was snapshotted first and the four pre-existing sheets were
read back and compared as data frames: Settings, Categories, AdHoc and
AudienceLens are all `all.equal` TRUE against the snapshot. The data file and
`Survey_Structure.xlsx` were not regenerated.

**The fixture workbooks are gitignored** (`.gitignore:22`, `*.xlsx`): they are
generated locally from `00_generate.R`, so no binary is committed by this
change, and a checkout elsewhere will have a `Brand_Config.xlsx` that predates
the new sheet. The tests therefore do not read the on-disk fixture config at
all. They call `ipk_write_brand_config()` into `tempdir()` and run `run_brand()`
against that, with `project_root` pointing at the fixture directory so
`load_brand_config()` resolves the data file and the survey structure from
there. Nothing is written into the repo by a test. The copy in this worktree
was regenerated by hand so a manual report generation here shows the notes.

On a real generation the console logs "Loaded 4 insights from Section_Insights
sheet", the check reports `funnel-dss`, `ceps-dss` and `wom-dss` as checked,
`_EXECUTIVE_SUMMARY` as skipped, and **zero findings**. The report is PASS with
an empty `$warnings`.

### The run completes, and the marker reaches the reader

With the stale sentence swapped into the same run, `generate_brand_html_report()`
returned **status PASS**, wrote 4,022,086 bytes, printed the console box, and
returned one warning:

    authored insight on section funnel-dss cites a figure the section does not
    carry: 42, 47, 27 does not appear in this section's data on the nested
    funnel, the view this page opens on

(42, 47 and 27 rather than 59, 31 and 20 because that probe read the sentence
against the *fixture's* funnel, where IPK is at 92, not against a funnel whose
nested chain is 42 / 35 / 22 / 16. The dense-pool limit above is why the other
four coincided with a real figure for another brand. Duncan's own figures are
asserted in the unit test, on a funnel with his numbers.)

The generated HTML carries exactly one `br-insight-check` marker, on
`funnel-dss`:

> **Number check.** 42, 47, 27 in this note could not be found in this
> section's data on the nested funnel, the view this page opens on. Read the
> note against the table below before this report goes out.

The marker sits between the rendered view and the dismiss button, never inside
the `<textarea class="br-insight-editor">`. That matters: the funnel and MA
pin dropdowns read `.br-insight-editor` for their "Insights" item, so a marker
in there would be pinned and exported as part of the analyst's own words. A
test asserts the placement, and another asserts a toolbar with no marker is
byte-identical to the one built before this change.

### Suites and drivers

From the runs themselves, on this branch with every change in place.

| Gate | Result |
|---|---|
| Brand suite, repo root, `testthat::test_dir("modules/brand/tests/testthat")` | **FAIL 0, WARN 1, SKIP 2, PASS 3358**, 102.9 s (baseline 3247) |
| `test_insight_number_check.R` alone | FAIL 0, WARN 0, SKIP 0, PASS 111 |
| `drive_destinations.py` | 353 checks, 0 failed, exit 0 |
| `drive_save_roundtrip.py` | 113 checks, 0 failed, exit 0 |
| `drive_two_categories.py` | 15 checks, 0 failed, exit 0 |
| `drive_overview.py` | 60 checks, 0 failed, exit 0 |
| `drive_funnel_base.py` | 95 checks, 0 failed, exit 0 |
| `reachability_check.py` before vs after | PASS, exit 0, every JSON island numerically identical |

The five drivers all report "no console error and no uncaught exception" in
their own output. The two skips are the pre-existing ones,
`test_dirichlet_norms.R:274` and `test_integration.R:375`; the new file adds
none. The regenerated fixture report is PASS at 4,021,727 bytes with an empty
`$warnings`, against a before baseline of 4,020,334 bytes.

No em dash appears in any new file, and `test_no_em_dash.R` passes in the
suite above.

## Files changed

| File | Change |
|---|---|
| `modules/brand/lib/html_report/03b_insight_number_check.R` | new, the check |
| `modules/brand/lib/html_report/99_html_report_main.R` | sources it, runs it, console box, run warnings |
| `modules/brand/lib/html_report/03_page_builder.R` | `check_note` on the toolbar builder, `.br_insight_check_note()` accessor, four call sites plus the Category Buying footer |
| `modules/brand/lib/html_report/panels/09_portfolio_panel.R` | the portfolio sub-tabs build their own insight container, so they get the marker through a matching stash |
| `modules/brand/tests/fixtures/ipk_wave1/07_structure_writers.R` | writes a `Section_Insights` sheet |
| `modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx` | regenerated locally, one sheet added, the other four unchanged as data. Gitignored, so not part of the commit |
| `modules/brand/tests/testthat/test_insight_number_check.R` | new |
| `docs/v2_lift/NOTES_BRAND_INSIGHT_NUMBER_CHECK.md` | this log |

## Deviations from the plan

- The funnel pool reads `.panel_table()` rather than
  `build_funnel_panel_data()`. The full builder throws in a partly sourced
  context because its cards half calls `.funnel_canonical_attitude_role()`,
  which lives in another file. Observed, not reasoned: the first probe failed
  on exactly that.
- `.bin_funnel_pool()` returns an empty pool when no nested percentage could
  be computed at all, rather than a pool of bare counts. A count-only pool
  would flag every percentage in the sentence. Found by a test that expected
  an empty pool and got nine counts.
- Mental Availability sub-tabs get the default-view pool for free, through
  `cep_brand_matrix` and `attribute_brand_matrix` holding total-base figures,
  rather than through a hand-written view scoping. Same outcome, no new code.
- `ipk_write_brand_config()` keeps its existing `openxlsx::saveWorkbook()`
  call rather than moving to `turas_saveWorkbook()`. It is a fixture writer
  with no data validation to lose, and switching it is outside this task.

## Not done, and not verified

- Real client configs are untouched. Any project whose `Section_Insights`
  sheet carries stale figures will start reporting them on the next run, which
  is the point, but Duncan will see warnings on projects that generated
  silently before.
- No headless run of a real project. The fixture is the only report generated,
  and only into the scratchpad.
