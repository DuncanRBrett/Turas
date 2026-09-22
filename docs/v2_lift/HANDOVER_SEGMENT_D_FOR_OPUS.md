# Segment Session D: demographic profiling commissioned, combined-mode export refused

**Date:** 2026-09-21. Written by the Fable review session for an Opus 5 implementation session at high effort, with the `fable-method` skill loaded and the project CLAUDE.md rules in force (TRS refusals, console-visible errors, tests before "done", no em dashes in anything a user reads).
**Findings under work:** `docs/v2_lift/REVIEW_FINDINGS_SEGMENT_2026-09-21.md`, rows F2 and F14, plus three LOW wording items (F8, F9, F17). Read those rows first; they carry the file:line evidence. Do not read the three `SESSION_*_NOTES_SEGMENT.md` files for this job; they predate the review and describe demographics as working.
**Branch:** `feature/segment-demographics`, cut from `review/segment-v2-lift` at `324a642f` if that branch is still unmerged, otherwise from `main` after Duncan merges it. Check with `git branch --contains 324a642f` before cutting.
**Baseline suite:** `Rscript -e 'testthat::test_dir("modules/segment/tests/testthat")'` from the repo root gives FAIL 0, WARN 0, SKIP 0, PASS 1258 at `324a642f`. Run it before the first change and after every work item.

Duncan's rulings, 21 September 2026: commission demographic profiling rather than remove it; refuse `tabs_export` in combined mode rather than export from one method.

## 0. What is true today

`demographic_vars` is parsed (`R/01_config.R:463`), carried into the validated config (`:542`), offered by the template as "categorical variables for demographic profiling" (`R/10_utilities.R:1669`), and gated by a second template setting `html_show_demographics` (`:1725`, parsed at `01_config.R:448`, carried at `:537`). Nothing consumes it. `profile_demographics()` exists at `R/05_profiling.R:467` with a passing unit test (`tests/testthat/test_profiling.R:91-106`) and no caller anywhere in `modules/segment`. The HTML table builder `build_seg_demographics_table()` (`lib/html_report/02_table_builder.R:355`) reads `html_data$enhanced$demographic_profiles` and returns NULL when it is absent, which is always; `99_html_report_main.R:190` builds that table and no page builder places it. The worked example `examples/segment/Thornhill_Segment_Config.xlsx` names `demographic_vars = age_band,region,shops_online` and its README says they are "along for profiling", which is not so.

The pieces already fit each other. `profile_demographics(data, clusters, demo_vars, segment_names)` returns `list(categorical_profiles, numeric_profiles, chi_sq_tests, segment_names)`; each categorical profile is a data frame with columns `Category`, `Overall` and one column per segment name, holding column percentages (`05_profiling.R:530-546`); that is exactly the shape `build_seg_demographics_table()` renders (`02_table_builder.R:368-434`). The transformer copies `results$enhanced` into `html_data$enhanced` unchanged (`01_data_transformer.R:86,124`). So the work is wiring, a section builder, the Excel sheets, and proof.

## 1. Work items

### D1. Refuse `tabs_export = Y` in combined mode (F14)

`tabs_export` is read only on the single-method final path (`R/00_main.R:501`); the multi-method output block from `:997` has no equivalent, and the setting is silently ignored there. Refuse it instead, at validation, so the user learns before a seven-second run.

- In `validate_segment_config()` (`R/01_config.R`), after `req` and `features` are both parsed and before the validated config is assembled: if `req$is_multi_method` and `features$tabs_export == "Y"`, `segment_refuse()` with code `CFG_TABS_EXPORT_COMBINED`. The message must say that combined mode compares methods and the export belongs to the single-method run made after choosing one, and tell the user either to set `tabs_export = N` or to set `method` to the one method they want exported.
- Console line before the refusal, as `refuse_removed_settings()` does.
- Docs: one sentence in `docs/01_README.md` under "Segment to Tabs", and the template description of `tabs_export` (`10_utilities.R`, the `add_field` row) gains "single-method final mode only".
- Tests (`test_tabs_export.R`, wiring block): `method = kmeans,hclust` with `tabs_export = Y` refuses with that code; the same config with `tabs_export = N` validates; a single-method config with `Y` still validates. Watch the first one fail before the change.

### D2. Wire demographic profiling end to end (F2)

**Validation.** A demographic variable named in the config but absent from the data must refuse at load, not warn at profiling. In `load_segment_data()` (`R/02_data_prep.R`, where clustering variables are checked with `validate_column_exists` around `:35`), check every `config$demographic_vars` the same way; refuse `CFG_DEMOGRAPHIC_VARS_MISSING` naming the missing ones and the first twelve columns the file does have. `profile_demographics()` has its own refusal for the all-missing case (`05_profiling.R:495`); leave it, it becomes unreachable from the pipeline.

**Computation.** In `turas_segment_impl()` (`R/00_main.R`), in the enhanced-features block, after the segment cards (the block starting at `:341`) and following the same `tryCatch` and `guard_warn` pattern the cards use: when `length(config$demographic_vars) > 0`, set `enhanced$demographic_profiles <- profile_demographics(data = data_list$data, clusters = cluster_result$clusters, demo_vars = config$demographic_vars, segment_names = segment_names)`. Note the `tryCatch(error = ...)` in that block will also catch a TRS refusal, which inherits from `error`; that is acceptable here only because D2's validation step makes the refusal unreachable. Say so in a comment. `data_list$data` is the post-preparation data, so the demographics are profiled on the respondents who were clustered; state that in the section's base note.

**Section.** A `build_seg_demographics_section(tables, html_data)` in `lib/html_report/03c_section_builders.R`, following `build_seg_rules_section()` (`:683`) for shape: title row, insight area, then `tables$demographics`. Under the tables, one paragraph in the module's plain register: percentages are column percentages within each segment among respondents with an answer; the chi-square p-values are descriptive, the same caveat `05a_profiling_stats.R` states for profiling; n per segment from `html_data$segment_sizes`. Numeric demographics: `profile_demographics()` routes a numeric variable with more than ten distinct values to `numeric_profiles` (means and an ANOVA p-value); render those as a second table (Variable, Overall mean, one column per segment, p-value) or state at the top of the section that they are in the Excel report. Decide and note; rendering them is preferred.

**Page.** In `lib/html_report/03_page_builder.R`: `show_demographics <- isTRUE(config$html_show_demographics %||% TRUE) && !is.null(html_data$enhanced$demographic_profiles)`; a `demographics` entry in `sections_config` (label "Demographics") placed after `profiles`; the section built and placed in the same order. Check `07a_combined_builders.R` builds its own page and decide whether combined mode gets the section too; final mode only is acceptable, logged.

**Excel.** In `export_final_report()` (`R/09_output.R:490`), which already receives `enhanced`: when `enhanced$demographic_profiles` exists, add `Demographics_Tests` (the `chi_sq_tests` frame) and one sheet per variable named `Demo_<var>` truncated to 31 characters, the way `export_demographic_profiles()` (`05_profiling.R:694`) builds its sheets. Reuse its logic rather than its workbook.

**Docs.** `docs/02_SEGMENT_OVERVIEW.md:120` ("Demographic Profiling | Chi-square analysis of segment composition") becomes true; leave it. `docs/06_TEMPLATE_REFERENCE.md` needs a `demographic_vars` entry (there is none; `grep -n demographic` finds only a note under clustering variables at `:304`) and an `html_show_demographics` entry. `docs/08_HTML_REPORT_GUIDE.md` lists the report's sections; add Demographics. `examples/segment/README.md` says the three demographics are "along for profiling"; after this session that is true, and add one sentence saying where they appear.

**Tests** (a new `test_demographics.R`, plus additions where noted):
1. `profile_demographics()` on a hand-built frame where region is a pure recoding of the segment: the region row percentages are 100 on the diagonal and the chi-square p-value is tiny; on a random region the p-value is not small. Watch it pass already; it is the existing function.
2. The pipeline: a 400-row fixture (the sample-size guard refuses smaller ones for the default `k_max`) with `demographic_vars = region,gender`, run through `turas_segment_from_config()` with `html_report = TRUE`. Assert `res$enhanced$demographic_profiles$categorical_profiles` has both variables; the HTML file contains a Demographics section heading and the variable names; the Excel report has `Demographics_Tests` and `Demo_region`. Watch this fail before D2.
3. `html_show_demographics = FALSE`: the section is absent from the HTML while the Excel sheets remain.
4. A missing demographic variable refuses `CFG_DEMOGRAPHIC_VARS_MISSING` at load, before clustering.
5. The section builder alone with a hand-built `html_data`: renders percentages with a `%` sign and the segment names as column headings; NULL when there are no profiles.
6. Numbers against an independent computation: from the pipeline run in test 2, read `segment_assignments.xlsx`, compute `prop.table(table(region, segment_name), margin = 2) * 100` yourself, and assert it equals the profile frame to 0.1. This is the test that proves the percentages are right rather than present.

### D3. Three wording items while in the files

- F8: the comment at `run_segment_gui.R:377-378` says the console block lands "as well as the terminal behind the app"; it does not (the sink has no `split`). Correct the comment; do not add `split = TRUE`, which would double every line in the terminal for a user who launched from one.
- F9: `R/03_clustering.R:184-189` tells a mini-batch run to "consider increasing nstart", which mini-batch ignores. Branch the wording on `use_minibatch`: for mini-batch say the batch size or the seed is the lever.
- F17: `lib/html_report/03c_section_builders.R`, the Variable Importance intro paragraph (search for "one quarter of the total distinction"), still promises a variance share that the F-statistic basis does not deliver. Reword so the paragraph says the percentages rank the variables by how sharply they separate the segments, and leave the footnote to say what the basis is.

## 2. Ground rules

- One branch, one commit per work item, tests watched failing first where the item changes behaviour. Do not merge; Duncan merges after the review and his `launch_turas()` eyeball.
- Never run the pipeline against a real project folder or write into OneDrive. The Thornhill example under `examples/segment/` is the fixture; point `output_folder` at a scratch path when you run it yourself, and do not commit anything under `examples/segment/Output/`.
- For minor choices, pick a reasonable option and note it rather than asking. For scope changes or destructive actions, ask first. Deliver what this document asks for, at the scope it intends: no v2 island, no weighting, no per-cell significance letters, no changes to `modules/shared`.
- Keep an implementation-notes log at `docs/v2_lift/SESSION_D_NOTES_SEGMENT.md`: what was executed, deviations, what was not verified. Update the segment row in `V2_LIFT_PROGRAM.md` section 4 and add a section 5 log line.
- If you do not know or cannot verify something, say so. A named gap is fine; an invented number, path or test result is not.

## 3. Definition of done

Suite green with zero skips and the new tests in it; the Thornhill example, run to a scratch folder, produces an HTML report with a Demographics section showing `age_band`, `region` and `shops_online` by segment, an Excel report with the four new sheets, and a combined-mode config with `tabs_export = Y` refuses by name before clustering. Then the independent review in `REVIEW_BRIEF_SEGMENT_D.md`.
