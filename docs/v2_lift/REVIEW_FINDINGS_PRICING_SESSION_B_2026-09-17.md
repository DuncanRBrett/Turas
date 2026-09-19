# Pricing Session B. Independent review findings

**Reviewed:** 2026-09-17, on main at `917b26b6`, by a session that did not build Session B. The author's notes (`SESSION_B_NOTES_PRICING.md`) were not read at any point in this review, so the disagreement section the brief asked for is not written; a later pass owes it.
**Commission:** `docs/v2_lift/REVIEW_BRIEF_PRICING_SESSION_B.md`.
**Work under review:** commits `ed19c98a`, `c9914973`, `67ba8195`, `089ef7d2`, read in the context of current main, which carries the Session A review follow-ups (`cf56b220` to `9ad4ce85`) on top.

## Verdict: BLOCK on the tabs export and on Present mode; PASS WITH FIXES on the island, the Pricing tab and the withdrawal

The island and the Pricing tab show the numbers the engine computed, the withdrawal broke nothing, and the two authored contract facts hold. Two surfaces are blocked until fixed. The tabs export (F1, CRITICAL): its crosstab share sits on tabs' any-mention base, which the module does not use, so on the shipped stop-early-imputed Karoo config the cheapest rung reads 100.00% in tabs against 93.77% in the pricing report, by construction, and the METHOD sheet's two pieces of advice (the direction of the difference, and filtering on `pricing_valid`) are both false on that table. Present mode (F2, HIGH): a CSS class collision restyles it in every tabs report on main, pricing or not. Two further HIGHs are dead surface a client can reach: a VW-only run links the tab to a simulator that was never written (F11), and a long-format study cannot use the export at all and is told to fix its ids (F15). The rest is wording, a false sheet name, and tests that pin wrong claims.

The verdict is scoped to what this session executed itself (sections 0, 2 and 4). Of the four readers the brief's method calls for, three (island and view; simulator; export against tabs' processors) reported and their load-bearing claims were re-run or re-read here before entering section 1; the withdrawal-plus-demo reader stopped without findings, so that surface rests on this session's own withdrawal runs and is otherwise a hole named in section 4.

## 0. What was executed

All from the repo root, this session, on 2026-09-17.

| Suite | Command | Result |
|---|---|---|
| Pricing R suite | `testthat::test_dir("modules/pricing/tests/testthat")` | 28 files, 379 tests, 1,092 expectations, 0 failed, 0 skipped, 0 errors, 14 warnings |
| Tabs R suite | `testthat::test_dir("modules/tabs/tests/testthat")` | 79 files, 1,741 tests, 5,945 expectations, 0 failed, 1 skipped, 0 errors. The skip is `test_config_templates.R:719`, "tracking_island.R not sourced in this run", not a pricing test |
| Node gates | `node` on every `modules/tabs/lib/html_report_v2/tests/*_tests.mjs` | 45 files, 1,157 passed, 0 failed. The author quoted 41 files; `git ls-tree 089ef7d2` shows 41 gate files then, and the four since added (`computed_parity`, `island_encoding`, `production_bundle`, `renderer_presence`) came in on 2026-09-04 by commits after `089ef7d2`. `pricing_view_tests.mjs` alone: 16 passed, 0 failed |

Scratch runs, none of them under `examples/` or OneDrive: the Karoo pricing example was built into the scratchpad with `build_pricing_example()` (bootstrap 100) and run headless through `run_pricing_analysis()` five times: the shipped both-methods config, the monadic config, the stop-early-imputed config, an "all on" config (simulator, tabs export, WTP, and `Generate_HTML_Report = TRUE` on the Settings sheet) and a control identical to it without the withdrawn row. All five returned `status = "PASS"` with an empty events list and no `[TRS PARTIAL]` line on the console.

The Pricing tab was rendered against the real islands from those runs (27z_pricing.js in a node vm, the gate file's own sandbox pattern). The Present-mode probe for F2 was run in headless Chrome (`--headless=new --dump-dom`) on a page carrying the live `styles.css`.

Two shipped artefacts were read, not written: `examples/integrated_demo/Output/tabs/report/Karoo_Demo_Crosstabs_data.json` and `examples/integrated_demo/Output/tabs/Karoo_Demo_Survey_Data.xlsx`, both dated 2026-09-04.

## 1. Findings

Only findings this session verified itself are here. Severity: CRITICAL (a client sees a wrong number with no way to know), HIGH (a wrong or misdescribed number is reachable on real data, or a regression reaches shipped reports), MEDIUM (misleading text or a missing safeguard), LOW, INFO.

### F1. CRITICAL, blocking for the export. The crosstabbed acceptance share sits on a different base from the module's, in the direction the export's own METHOD sheet denies, and on the shipped stop-early config the cheapest rung reads 100% by construction. Verified by execution.

This is the third tabs contract fact the brief asked for. The two the author found are real and are confirmed under question 2 in section 3; this one was missed. The export reader found it independently and added the stop-early case, which is re-run below and is what lifts the severity.

The mechanism. `15_tabs_export.R:326-329` writes a `GGACC_k` cell as the rung's label where the respondent would buy and leaves it blank both where they would not and where they did not answer. Tabs computes a Multi_Mention base in `modules/tabs/lib/weighting.R:524-559` (`calculate_multimention_base`): a respondent is in the base only when at least one of the question's columns holds a non-blank value. So a respondent who would not buy at any rung has five blank cells and is not in the base. The module, by contrast, keeps that respondent in the denominator at every rung (`gg$demand_curve$n_respondents` is 356 at all five prices on the Karoo run).

The direction. Every rung's share in tabs is the module's share divided by the share of analysed respondents who accept at least one rung. It can only read higher, never lower.

Worked example, Karoo scratch run (all-on config, 400 respondents, 356 analysed, `pricing_valid = 1` applied as the filter the METHOD sheet recommends). Tabs' own functions, `calculate_weighted_base()` then `calculate_multi_mention_count()` sourced from `modules/tabs/lib/`, unweighted:

| Rung | Mentions | Module share (over 356) | Tabs share (over 354) |
|---|---|---|---|
| R60.00 | 334 | 93.8% | 94.4% |
| R80.00 | 308 | 86.5% | 87.0% |
| R100.00 | 264 | 74.2% | 74.6% |
| R120.00 | 175 | 49.2% | 49.4% |
| R140.00 | 112 | 31.5% | 31.6% |

Base from tabs' own function: 354 of the 356 valid rows. The two respondents who rejected every rung (counted directly from `gg_data`: 2 of 356 with zero `response == 1`) are out.

The same rule is visible in the shipped integrated demo, read from disk. `Karoo_Demo_Survey_Data.xlsx` has 600 rows, 524 with `pricing_valid = 1`, of whom 520 have at least one `GGACC_k` mention and 4 have none. `Karoo_Demo_Crosstabs_data.json` reports the GGACC total base as 520 and rung 1 as 484 mentions, 93%. On the module's base that is 484 / 524 = 92.4%; on tabs' base 484 / 520 = 93.1%.

How large it gets. The both-methods Karoo run is a benign fixture: 93.8% accept the cheapest rung, so almost nobody accepts nothing and the gap is under a point. The shipped stop-early-imputed config (`Karoo_Pricing_Config_StopEarly_Imputed.xlsx`, `GG_Stop_Early_Imputation = NO_AFTER_STOP`) is not. Under that rule a respondent whose first answer is No is coded No at every rung, so every first-rung No is an all-blank row and leaves the tabs base. Re-run here on the scratch stop-early result, exported with `export_pricing_for_tabs()` and read back through tabs' own functions:

| Rung | Tabs share (base 375) | Module, unweighted (400) | Module, weighted (published) |
|---|---|---|---|
| R60.00 | 100.00% | 93.75% | 93.77% |
| R80.00 | 87.20% | 81.75% | 81.03% |
| R100.00 | 69.60% | 65.25% | 64.26% |
| R120.00 | 42.93% | 40.25% | 39.64% |
| R140.00 | 24.00% | 22.50% | 22.57% |

25 of 400 respondents accept no rung; tabs' base is 375; the cheapest rung reads 100.00% in the client's crosstab whatever the data say, because under NO_AFTER_STOP the only way to be in the base is to have said Yes at the bottom rung. In general, every rung's share in tabs is inflated by 1 / (share accepting at least one rung), and the effect is invisible on the crosstab itself because the base row simply shows the smaller number.

The `pricing_valid` filter does not help. The METHOD sheet tells the reader to "Filter on it to reproduce the pricing report's base". On the stop-early run all 400 rows have `pricing_valid = 1` (the run excluded nobody), and applying the filter leaves tabs' base at 375; on the both-methods run it leaves 354 of 356. The rows tabs drops are all-blank rows, and those are never marked invalid, so the filter cannot restore them. That is a second false statement in the same place.

What the METHOD sheet says instead. `15_tabs_export.R:551-556` says filtering on `pricing_valid` reproduces the report's base (see above). `15_tabs_export.R:526-530` ("Per-rung answered base" row): "The pricing report divides by these; tabs divides by the banner base. Where they differ, a rung with unanswered cells reads lower in tabs." And the console note at `15_tabs_export.R:152-158`: "Tabs reports over the banner base, so those rungs read lower there than in the pricing report." Both statements are wrong on two counts: tabs does not divide by the banner base for a Multi_Mention, and the difference runs the other way. The comment at `15_tabs_export.R:163-166` shows the author saw that a no-mention respondent "reads as would not buy at any price", but not that tabs then drops them from the base.

Why the suite is green. `test_tabs_export.R:286-329` is the integration proof B3 asked for. It sources tabs' `calculate_row_counts()` and checks the counts (10, 8, 4 on the fixture) and that a 0/1 grid counts zero. It never calls `calculate_weighted_base()` or compares a share with the module's, so the base rule is not exercised anywhere. Worse, two tests pin the false wording: `test_tabs_export.R:249` expects the `pricing_valid` row to say "reproduce the pricing report's base" and `:266` expects the per-rung base row to say "reads lower in tabs" (see F20).

What this does not affect. The mention counts themselves are right (the DATA sheet's non-blank counts 334 / 308 / 264 / 175 / 112 equal `response == 1` per price in `gg_data`), the island and the Pricing tab are unaffected, and the two authored contract facts hold. Not fixed here. A fix will have to give the "would not buy at any price" respondent a mention (a further column carrying a "None of these" label is the tabs-native shape) or say on the METHOD sheet, correctly, that the tabs base is respondents who accept at least one rung.

### F2. HIGH, blocking for every tabs report. The Pricing tab's CSS classes collide with Present mode's, so Present mode is restyled in every report built from main. Verified by execution.

Raised by the island-and-view reader; re-verified here. `styles.css:502-507` and `:612` define `.pr-head`, `.pr-ctx`, `.pr-note`, `.pr-table` and `.pr-chart` for Present mode, which `30_story.js:1048-1062` emits (that file was last touched on 2026-09-02, before Session B). Session B added `.pr-note` (`styles.css:1436`), `.pr-table` and `.pr-table th, td` (`:1446-1451`) and `.pr-chart`, `.pr-chart svg` (`:1453-1454`) for the Pricing tab, at the same specificity, later in the same file, so they win in both directions. The stylesheet is inlined whole into every report, pricing island or not.

Computed styles from headless Chrome on a page carrying the live stylesheet: a Present-mode `.pr-note` now has `font-size 13.6px` and `color rgb(85, 85, 85)` (the pricing values; Present's own are 15px and `var(--ink)`) while keeping Present's amber box; every `td` inside a Present `.pr-table` gets `padding-left 9px`, a 1px bottom border and 14.08px text; the `svg` inside a Present `.pr-chart` gets `max-width 720px` and `display block`. In the other direction the pricing `.pr-note` gets Present's amber background, 4px left border and 8px radius, and the pricing `.pr-table` gets Present's white card, 1px border and shadow. No number changes; every shipped report's Present mode does.

### F3. MEDIUM. The byte-identity test proves the default argument, not "unchanged from before". By reading.

Handover B2 asked for a test that "a report without pricing is byte-identical to before". `test_pricing_island.R:194-204` builds the live builder twice, with and without `pr_json = NULL`, and expects the two to be identical. That is true by construction and proves nothing about the pre-Session-B build; F2 is exactly the kind of change it cannot see. The test's own title is honest ("identical whether or not pr_json is named"); the claim the handover wanted is not tested.

### F4. MEDIUM. The Gabor-Granger note promises a comparison the tab does not show. Verified by execution.

`14_v2_island.R:549-552` appends "The published curve is smoothed (isotonic) so it never rises with price; the observed acceptance is shown beside it" whenever `diagnostics$smoothing` is not "none". When smoothing changed nothing, which is the Karoo case (`purchase_intent` equals `purchase_intent_raw`), `14_v2_island.R:371` omits `smoothedPct` and the view draws no second series. The rendered both-methods and stop-early tabs both carry the sentence and neither has an observed-versus-published column.

### F5. MEDIUM. The monadic "Would buy" column carries no coding rule. Verified by execution.

The rendered monadic tab says "The fitted curve is a logistic regression of purchase intent on price across 4 price cells" and shows 76.5% at R70. That figure is the weighted share with `MON_Intent >= 4` on a 1 to 5 scale (config `Intent_Type = scale`, `Scale_Threshold = 4`; recomputed by hand in section 2). Nothing on the tab says so, where the Gabor-Granger note states its coding. The island only repeats what the engine recorded, and `13_monadic.R` does not record the intent type or threshold, so this is an engine-side gap.

### F6. LOW. The Van Westendorp estimation note reads as 44 of 356 when it means 44 of 400. Verified by execution.

`14_v2_island.R:531-542` builds: "Price points are the curve intersections computed by pricesensitivitymeter (psm_analysis_weighted (survey design)) on 356 respondents; respondents whose four prices are not in ascending order were excluded. That was 44 of them (11.0%)." On the Karoo run `n_violations_before_handling` is 44 and `violation_rate_before_handling` is 0.11, which is 44 / 400 (`validation$n_total`). After a sentence about 356 respondents, "44 of them (11.0%)" reads as 44 of the 356, which would be 12.4%. The rendered tab carries the sentence verbatim.

### F7. LOW. The GUI still tells the user to open an HTML report that is no longer written. By reading.

`modules/pricing/run_pricing_gui.R:222`: "Full results written to Excel. Open the HTML file for the interactive report." After Session B no HTML report exists; the deliverables are the Excel workbook, the island, the optional export and the optional simulator. The GUI was in the author's own unverified list. The sourcing side is fine: `00_main.R:76-89` sources `14_v2_island.R` and `15_tabs_export.R` as siblings, so the GUI's own `pricing_source_files` list (`run_pricing_gui.R:130-136`, which stops at `13_monadic.R`) does not starve the island or the export.

### F8. LOW. An internal token reaches the client. Verified by execution.

The stop-early tab renders "Imputation: NO_AFTER_STOP: unanswered rungs after a respondent's first No coded as No." (`14_v2_island.R:554-555`). The setting's value is not a sentence a client should read.

### F9. LOW. "Across 1 estimates" on a one-method run. Verified by execution.

`27z_pricing.js:461-463` renders "the methods' own prices spread 0.0% across 1 estimates" on the stop-early island (`nMethodPrices = 1`). A one-estimate spread is not information.

### F10. LOW. Profit is mentioned in prose and absent from the table. Verified by execution.

The rendered both-methods tab says "With the unit cost in the config, profit is highest at R100.00" and the island carries `profitIndex` per rung, but the Gabor-Granger table's columns are Price, Base, Weighted base, Would buy, Interval, Revenue index, Elasticity. A reader is told a profit optimum exists and cannot see the curve it came from.

### F11. HIGH. A Van Westendorp-only run with `Generate_Simulator = TRUE` puts a dead link on the Pricing tab. Verified by execution.

Raised by the simulator reader; re-run here. A VW-only Karoo config with the simulator on (`write_pricing_config(method = "van_westendorp", simulator = TRUE)`) ran to `[TRS PASS]`; step 9 printed "Simulator not written: This run produced no demand curve" and a `[TRS PARTIAL] DATA_SIMULATOR_NO_CURVE` line, and no simulator file exists. The island written at step 8b, before step 9 decides, carries `meta.simulatorFile = "Karoo_VWonly_Results_simulator.html"`; `file.exists()` on it is FALSE. `.pricing_island_simulator_file()` (`14_v2_island.R:616-619`) tests only the config flag, and its own roxygen (`:610-611`) claims it "follows the same condition step 9 uses", which has a second condition. The tab then renders "Simulator: Karoo_VWonly_Results_simulator.html. Open it beside this report" as a link to nothing. `test_v2_island.R:311-317` pins the wrong behaviour: a VW-only results list with the flag on is asserted to name the file. Also noted: the run's `run_result$status` stayed PASS with the PARTIAL on the console.

### F12. HIGH. Preset scenarios on the Simulator sheet never reach the page. Verified by reading, with the reader's executed output read from disk.

Raised by the simulator reader. `01_config.R:393-396` stores a Simulator sheet at `settings$simulator_scenarios`; `01_simulator_parts.R:152` reads `config$simulator$scenarios`, which is a different name (it resolves to NULL, or by R's partial `$` matching to the whole sheet, in which case `$scenarios` on it is NULL either way). Independently, `build_scenarios_list()` (`01_simulator_parts.R:175-178`) looks up a `price` or `Price` column while the template writes `Product_Price` (`generate_config_templates.R:767`). The reader's Karoo run with a two-row Simulator sheet wrote `"scenarios":[` empty into its simulator HTML (read from the reader's scratch output; not re-run here). The reader reports that the retired report read the same `config$simulator$scenarios`, so this is carried across rather than introduced by Session B, but `README.md` and `docs/USER_MANUAL.md` still promise scenario cards and no test runs a loaded config through to the page.

### F15. HIGH. A long-format Gabor-Granger study cannot use the export, and the refusal blames the study's ids. Verified by execution.

Raised by the export reader; re-run here. `00_main.R:633` hands the export `data = data_result$data`, the frame as loaded. For a long-format ladder that frame has one row per respondent per rung, so the id column repeats. `15_tabs_export.R:103-115` then refuses `DATA_TABS_EXPORT_ID_NOT_UNIQUE` with "Give every respondent one unique id. Repeated values include: R0001, R0002, R0003, R0004, R0005". Reproduced with a 2,000-row long frame built from the Karoo data (400 distinct ids, five rungs). The ids are unique; the layout is long, which is the layout the module's own `Data_Format = long` setting supports, and the exporter is never told. Nothing in the docs says the export is wide-only.

### F16. MEDIUM. A refused island, export or simulator still ends the run at TRS PASS. Verified by execution and reading.

The export reader found it for the export; it is wider. `00_main.R:539-543` snapshots `run_result` from the TRS state before steps 8b (island), 8c (export) and 9 (simulator). A refusal in any of them prints `[TRS PARTIAL]` through `turas_run_state_partial()` after the snapshot was taken, so `run_result$status` stays "PASS" and `events` stays empty. Seen on the VW-only run in F11 (PARTIAL DATA_SIMULATOR_NO_CURVE on the console, `run_result$status` PASS, `events` empty) and reported by the export reader for a refused export (its idgate case A). The GUI reads `rv$results` and reports success from it.

### F17. MEDIUM. The QUESTIONMAP_SNIPPET sheet names a sheet tabs does not read for that purpose and carries columns tabs does not have. By reading.

`15_tabs_export.R:215` writes "Paste these rows into your tabs QuestionMap sheet". Tabs reads question definitions from the Survey_Structure workbook's "Questions" sheet (`modules/tabs/lib/data_loader.R:172`); "QuestionMap" is the tracking mapping sheet (`generate_config_templates.R:1573`). The snippet's `Data_Source` and `Note` columns are not tabs columns, and its Note text (`15_tabs_export.R:406`) still says "one 0/1 column per rung", which is the coding the file itself says tabs cannot read. The export reader reports the same naming is inherited from the maxdiff export. An analyst following the sheet literally does not get a working config.

### F18. MEDIUM. With an empty Currency_Symbol the labels survive Excel but not CSV. Verified by execution.

`Currency_Symbol` blank gives labels like "60.00". Written by `openxlsx` and read back by `read.xlsx` they stay character and match `OptionText` "60.00". Written to CSV with `data.table::fwrite()` and read with `fread()`, the column comes back numeric 60, and `calculate_multi_mention_count()` with OptionText "60.00" returns 0 mentions. Tabs accepts CSV survey data, and an operator who converts the export to CSV, or pastes it into a survey workbook where Excel types the cells as numbers, gets a question that reports 0% at every rung. The export reader also reports a hand paste into Excel producing numeric cells and OptionText "60". The shipped default currency is "$" (`01_config.R:1110`), so the blank case is opt-in.

### F19. LOW. Ten or more rungs sort as text. Verified by execution.

The export writes `DisplayOrder` 1..k. Tabs' loader reads every structure sheet with `col_types = "text"` (`data_loader.R:84-111`) and `standard_processor.R:80-84` sorts with `order()` on that column, so a ladder of ten or more rungs displays as 1, 10, 11, 12, 2, 3, ... (`order(as.character(1:12))` gives exactly that). The same gotcha is already recorded for banner DisplayOrder in CLAUDE.md; the export does not warn.

### F20. MEDIUM, under question 4. `test_tabs_export.R` pins wording F1 shows to be false. By reading.

`test_tabs_export.R:249` asserts the `pricing_valid` METHOD row says "reproduce the pricing report's base" and `:266` asserts the per-rung base row says "reads lower in tabs". Both sentences are wrong (F1), so a correct fix must change these tests too, and their existence is why the suite could not catch F1. The export reader's own run of the file: 64 expectations, 0 failed.

### F13. INFO. Step label. By reading.

`00_main.R:617` prints "8b. Writing the tabs export..." for the block its own comment calls STEP 8c; the island step above it is also 8b. Console only.

### F14. INFO. A comment misnames the four method prices. Verified by execution.

`14_v2_island.R:466-467` says the spread is taken across "two VW points, GG, the ladder". `synthesis$method_prices` on the run holds OPP, IDP, the VW optimal-zone midpoint and the Gabor-Granger optimum; the price ladder is not one of them. The figure (`nMethodPrices = 4`, spread 4.72%) is right; the comment is not.

## 2. Hand recomputation, one figure per surface

All by execution, from the scratch run's raw objects and the raw data file, compared with the island JSON, the rendered tab and the export workbook.

| Surface | Figure | Hand computation | What the surface shows |
|---|---|---|---|
| Island, GG | acceptance at R60, weighted | sum(w x response) / sum(w) over the 356 analysed rows of `gg_data` = 0.9389622 | `acceptancePct[1]` = 93.89622 |
| Island, GG | revenue index at R100 | 0.7318622 x 100 = 73.18622 (`04_gabor_granger.R:1139`, price x intent) | `revenueIndex[3]` = 73.186215 |
| Island, GG | profit index at R100 | 0.7318622 x (100 - 38) = 45.37545 (unit cost 38 from the config) | `profitIndex[3]` = 45.375453 |
| Island, GG | arc elasticity R60 to R80 | midpoint formula on 0.9389622 and 0.8559530 = -0.3237282 | `arcElasticity[2]` = -0.323728 |
| Island, VW | four price points and intervals | `vw$price_points` and `vw$confidence_intervals` from the run: PMC 61.47641 [59.61405, 63.43749], OPP 89.74206 [86.76398, 94.77261], IDP 93.86404 [89.77566, 97.21197], PME 135.87938 [130.95865, 140.39953]; the Results workbook's VW_Price_Points and VW_Confidence_Intervals sheets carry the same values. This is the result object compared with the island, not a re-estimation of psm | `value`, `ciLower`, `ciUpper` identical to 6 places |
| Island, meta | effective n | Kish (sum w)^2 / sum w^2 over the 356 analysed respondents' weights in the data file = 331.7581 | `effectiveN` = 331.758105 |
| Island, recommendation | method spread | sd / mean of the four `synthesis$method_prices` (89.742, 93.864, 91.803, 100.000) = 0.0472071 (`12_recommendation_synthesis.R:341`) | `methodSpreadPct` = 4.72071 |
| Island, monadic | cell intent | weighted share with MON_Intent >= 4 in each cell of the raw data: 76.5, 51.6, 42.6, 23.5; weighted n 102.0, 99.3, 96.5, 102.3 | `cellIntentPct` 76.45625, 51.57080, 42.61677, 23.48751; `cellWeightedN` 101.95, 99.30, 96.49, 102.25 |
| Tab | the same figures rendered | rendered text carries 93.9%, 56.34, 73.2%, R89.74, R93.86, R61.48, R135.88, R99.99, 4.7%, 331.8, R59.61 to R63.44; the monadic tab carries 76.5%, 51.6%, 42.6%, 23.5% | no NaN, no "undefined", no "null", no dollar sign, no em dash in any of the three rendered tabs (both-methods 16,155 characters, monadic 5,517, stop-early imputed 5,627). No double scaling: the R side multiplies by 100 once and the view formats what it is given |
| Export | mentions at each rung | count of non-blank `GGACC_k` cells in the DATA sheet: 334, 308, 264, 175, 112 | equals `sum(response == 1)` at each price in `gg_data`: 334, 308, 264, 175, 112. The tabs share is F1 |

## 3. The four questions

**1. Does the client see the right numbers?** On the island and the tab, yes, for every figure recomputed above. On the export, no: the counts are right and the share is not (F1), and on the shipped stop-early config the cheapest rung is 100% by construction. On the simulator, the reader reports the JS math matches R and the two HIGHs re-run here (F11, F12) are about a missing file and a missing feature, not a wrong figure.

**2. Is the tabs contract honoured?** The two authored facts hold, by reading tabs' code and by execution. `cell_calculator.R:110-125` (`calculate_multi_mention_count`) counts a mention where `safe_equal(data[[col]], option_text)`, and `type_utils.R:43-73` compares trimmed character values, so a 0/1 grid would match no label; executing it on the export's DATA sheet with the label "R60.00" returned 334, the hand count. `question_orchestrator.R:94-103` selects options with `^\Q{code}\E_[0-9]+$`, so the rows must be keyed `GGACC_1` and so on; the shipped demo's data JSON carries five rung rows for GGACC, which it could not if the lookup had failed. The third fact is F1: the Multi_Mention base is any-mention (`weighting.R:537-548`), not the banner base.

**3. What did the retirement break?** Nothing found. The all-on run (with `Generate_HTML_Report = TRUE`) and the control (without) wrote the same file set (Results workbook, stats pack, island, tabs export, simulator, plots), with identical sheet lists in the Results workbook and in the stats pack. The withdrawal notice reached the console exactly once on the all-on run and not at all on the control. The returned object names `simulator_path`, `island_path` and `tabs_export_path` and nothing that claims a report; `run_result$events` is empty. The GUI help text (F7) is the one place that still believes a report exists.

**4. Is the new green earned?** Not on the export. The suites reproduce at the numbers in section 0, and the rendered tab against a real island (not the gate's hand-written fixture) shows the numbers the engine computed. But four tests assert what the code does rather than what is correct: the byte-identity test compares the builder to itself (F3); the export integration test never reaches the base rule (F1); two export tests pin METHOD wording that is false (F20); and `test_v2_island.R:311-317` pins the dead simulator link (F11). The readers' sorts of `test_v2_island.R`, `test_pricing_island.R` and `test_simulator.R` are leads in section 4.

## 4. What could not be verified

The brief's method is four independent readers plus a coordinator. Four were commissioned (island and view; export against tabs' processors; simulator; withdrawal path plus demo). Three reported; the claims of theirs that entered section 1 (F2, F3, F4, F5, F8, F10, F11, F12, F14, the stop-early half of F1, F15 to F20) were each re-run or re-read here first. The withdrawal-plus-demo reader stopped without findings. Nothing of its is in the record and that surface is only as covered as this session's own runs made it.

Per concern, what this session's own execution covered:

- **Island and view: covered for the numbers and the render, partly for the wiring.** Covered: every figure in section 2, the three rendered tabs, the absent-block rule on three islands (monadic-only carries `meta, monadic, recommendation`; GG-only carries `meta, gg, recommendation`; the runs without `Generate_Simulator` carry no `simulatorFile`), the F5 follow-up field reaching the tab through the note sentence, and F2 in headless Chrome. Not executed here: `24_shell.js` tab placement and the filter-hidden list, `build_report_v2.R` inlining, `.read_pricing_contribution()` on a stale path or a maxdiff-kind file, the two-place settings whitelist, the SVG chart internals and the `089ef7d2` label fix. The reader reports these as correct by reading plus the suite log; treat as leads, not findings.
- **Export against tabs' processors: covered.** This session's own execution: the mention counts, the base rule on the both-methods and the stop-early runs (F1), the `pricing_valid` no-op, both authored contract facts, the long-format refusal (F15), the empty-currency CSV path (F18), the DisplayOrder sort (F19), and the tests' reach (F20). The export reader's claims not re-run here, offered as its findings: the coding rules ZERO_ONE, ONE_TWO and Yes/No produce 0 mismatches between the engine's `gg_data` and the exported cells, and 1/2 data declared ZERO_ONE refuses; `pricing_valid` follows ids under a shuffled row order and marks the 41 completeness-excluded ladders on its F4 fixture; the WTP column matches a hand computation for all 400 Karoo respondents and carries the RIGHT-CENSORED stamp; both ID gates fire with the console box printed by `00_main.R:640`, not by the exporter. Its scripts are under the scratchpad's `readerB/` folder.
- **Simulator: reader covered, coordinator re-ran the two HIGHs only.** This session's own execution: the all-on run wrote `Karoo_AllOn_Results_simulator.html` (40 KB), the island names it, and F11 was re-run end to end. The simulator reader reports, by execution in node vm and headless Chrome, that the JS math matches R (R100: 73.2%, 73.19, 45.38 against 0.7318622, 73.18622, 45.37545; R110 between rungs matches a hand interpolation), that P1c, P2a and P3a hold, that `turas_prepare_deliverable()` exists at `turas_minify.R:2325`, no-ops unless `TURAS_PREPARE_DELIVERABLE` is TRUE, and on a copy took the file from 41 KB to 68 KB with the same card values afterwards, and that the deleted directories have no live references. None of that was re-run here; treat it as the reader's claim. The reader's further leads: on a segment, "vs optimum" is measured against the total sample's optimal price (`01_simulator_parts.R:78-87` drops each segment's own optimum; `pricing_simulator.js:171-172, 439-442`), carried across from the old JS; `docs/README.md:21, 186, 232-241`, `docs/TECHNICAL_REFERENCE.md:74, 456, 618` and `docs/USER_MANUAL.md:78, 90-94, 870-889, 947` still describe the retired report or the deleted `lib/simulator/` tree, against B4; the slider is bound to the total's grid so a segment with a narrower ladder extrapolates flat past its last rung; segments reach the simulator only on a GG-only run; `pricing_simulator.js:629` returns an em dash for a NaN price and `test_simulator.R:220, 297` grep the six-character escape so they pass; `.pricing_island_simulator_file()` lacks `ignore.case` where step 9 has it; and no test in `test_simulator.R` executes the engine's arithmetic (lines 262-290 grep the source for names).
- **Withdrawal path plus demo: withdrawal covered by this session, demo and follow-ups a permanent hole.** The reader for this concern stopped without findings, waiting on a demo build it did not run, so nothing from it exists. Withdrawal is in question 3. The demo was read from disk (the 2026-09-04 build) for F1 only; the build script, the README, the tabs config wiring and a rebuild were not checked, and the tabs run without a pricing island was not executed. The Session A follow-up interaction was checked only by the diff stat (`14_v2_island.R`, `15_tabs_export.R`, `run_pricing_gui.R`, `build_report_v2.R`, `run_crosstabs.R` moved after `089ef7d2`) and by the F5 note rendering; the retired-settings refusal was not executed.

Unverified leads from the island-and-view reader, for a later session: `.read_pricing_contribution()` (`run_crosstabs.R:674-703`) resolves the island path relative to the R working directory, not the config file, and accepts any file whose kind is "pricing" with no project cross-check, the same as maxdiff; `simulatorFile` is a bare basename the tab links relative to the report, so the simulator must be copied beside the report (the demo does this; maxdiff and conjoint follow the same pattern); `monadic.optimalProfitPrice`, `meta.nAnalysed`, `vw.ciPolicy`, `vw.monotonicityBehavior` and `gg.missingN` are carried and never drawn; one-rung and one-cell arrays are covered only by a fixture test (`test_v2_island.R:351-368`); Gabor-Granger loses the 44 respondents validation dropped for a Van Westendorp ordering reason, which is a Session A engine question, not a Session B one; and the reader's sort of `test_v2_island.R` and `test_pricing_island.R` into independent goldens versus self-comparison versus source-text assertions (it names `test_pricing_island.R:36-75` and `:153-170` and `pricing_view_tests.mjs:172-177` as source-text checks) was not repeated here.

Also outside this session: the GUI path was read, not run; no workbook was opened in Excel itself; the author's notes were not read.
