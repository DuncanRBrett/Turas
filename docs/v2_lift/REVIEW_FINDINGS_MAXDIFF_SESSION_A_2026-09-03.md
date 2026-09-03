# MaxDiff Session A: Independent Pre-merge Review Findings

> **Status, added the same day:** Duncan asked for the next actions to be taken. All six items in section 6 are done, as six new commits on `feature/maxdiff-correctness` (`7ddb716b`..`9f12a31e`, unmerged, not pushed); section 7 at the foot records what changed and how each was verified. The findings below are left as written, so the record of what was found stays separate from the record of what was done about it.

**Date:** 2026-09-03. Reviewing session (Fable); did not write the code under review and did not read the implementing session's working notes beyond the committed `SESSION_A_NOTES_MAXDIFF.md`, which was treated as a set of claims to test.
**Scope:** branch `feature/maxdiff-correctness` at `6d3e0165`, nine commits `0a61efd4`..`6d3e0165` off local main `f03ee8df` (33 files, +1618/-516), unmerged and already pushed to `origin/feature/maxdiff-correctness` (so fix-ups must be new commits, never amends), judged against `HANDOVER_MAXDIFF_FOR_OPUS.md` (A1 to A8) and `MAXDIFF_PRODUCTION_REVIEW_2026-07-10.md` (C1 to C3, H1 to H6, M1 to M15, section 5).
**Verification:** everything marked verified below was read or executed in this session, from the repo root with renv active. Old-code checks ran against a `git archive` export of `f03ee8df` in the session scratchpad. Nothing was run against a project folder and nothing was written into OneDrive. Anything I did not check myself is labelled unverified next to the claim. No code was changed; the branch is untouched.

---

## 0. Verdict: FAILED

The branch cannot be merged as it stands, for one reason that is disqualifying on its own and two that are serious:

1. **The branch fails its own definition of done, and its record says otherwise.** The handover's completion bar is "suite green with the new tests in". At `6d3e0165` four tests error and never reach an assertion. The session notes, the A8 commit message and the programme tracker row all state "902 pass / 0 fail / 0 skip". That figure is the expectation count with the four erroring tests contributing zero expectations; it was never a green run. One of the four is the test that was supposed to prove the headline C3 fix (non-zero counts from position-coded data). It could never have passed because it asserts on columns that do not exist. See F1.
2. **A refused HTML report still ends in `[TRS PASS] ... COMPLETED SUCCESSFULLY`.** The H4 fix makes the GUI check the run's status, but a report refusal never changes that status, so the green toast survives one layer down. Observed by execution. See F2.
3. **C2 (numeric respondent ID as a phantom item) survives in seven report and simulator consumers.** Session A fixed the four sites the handover named. The handover missed the report layer. With numeric IDs the report refuses outright (a crash in the diagnostics transformer) and the simulator, were that crash fixed alone, would ship every respondent's utilities shifted by one item. See F3.

The engine work is sound. Every CRITICAL and HIGH fix was executed in both directions: the failing case reproduces on the old code and passes on this branch, with at least one number hand-recomputed per fix (section 2). The four erroring tests are test bugs, not engine bugs; the corrected versions of those three files from `feature/maxdiff-v2-report` pass against this branch's engine with 83 expectations and 0 failures. What turns this into a pass is small: land those test corrections on this branch, fix F2 and F3, and rewrite the suite claim wherever it appears. Section 6 lists it.

---

## 1. Suite runs, my own numbers

Command in both cases: `testthat::test_dir("modules/maxdiff/tests/testthat")` with the silent reporter, counts taken from `as.data.frame()` of the result.

| Tree | Expectations passing | Failed | Skipped | Tests erroring |
|---|---|---|---|---|
| old export (`f03ee8df`) | 801 | 0 | 4 | 0 |
| branch tip (`6d3e0165`) | 902 | 0 | 0 | 4 |

The notes give the old baseline as 797; I observed 801. The difference is not material and I did not chase it.

The four erroring tests at the tip, with the cause read from the test and the engine:

| Test | Cause | Test or engine bug |
|---|---|---|
| `test_design.R:13` generate_random_design creates correct structure | Calls `num_versions =`; the function signature is `n_versions` (`R/04_design.R:608-609`). The old version of this test swallowed the error and skipped. | Test |
| `test_logit.R:262` fit_aggregate_logit uses last item as anchor | Hand-built long data gives `item_id` values "3", "5" (from `Shown_*`) but compares to `paste0("I", ...)` (`test_logit.R:240, 247-248`), so no task ever has a best; the engine correctly refuses `DATA_NO_VALID_CHOICES`. | Test |
| `test_logit.R:305` fit_aggregate_logit uses designated anchor | Same fixture defect (`test_logit.R:284`). | Test |
| `test_data_reshape.R:323` C3: position-coded data produces NON-ZERO count scores | Fixture items lack `Item_Group` and `Display_Order`, which `compute_maxdiff_counts` selects at `R/05_counts.R:117`; the production loader always adds them (`R/01_config.R:666-690`). Behind that, the assertions name `Best_Count` and `Worst_Count` (`test_data_reshape.R:319-323`); the frame has `Times_Best` / `Times_Worst`. | Test |

Judgement: all four are test-only. Evidence beyond reading: I extracted the three corrected files from `feature/maxdiff-v2-report` (`git show`) and ran each with `test_file` against this branch's engine after sourcing this branch's `setup.R`: `test_design.R` 7 expectations, `test_logit.R` 36, `test_data_reshape.R` 40, all 0 failed, 0 errors, 0 skipped. The other branch's characterisation is confirmed.

The A8 commit message states "Suite after Session A: 902 pass / 0 fail / 0 skip". That run cannot have happened with these files as committed.

---

## 2. Fix-by-fix verification (both directions)

Probe scripts and their outputs are in the session scratchpad (`probes/p1_c2.R` .. `p11_oldtpl.R`, `out/old_all.txt`, `out/new_all.txt`, `out/e2e_num.txt`, `out/e2e_chr.txt`). "Old" is the `f03ee8df` export; "new" is the branch tip.

### C2 / A1: numeric resp_id as a phantom item
Fixture: 20 respondents, `resp_id = 10001..10020` numeric, items A, B, C with true means 1.0, 0.2, -1.2.
Hand computation (per-respondent softmax, averaged): A 65.861, B 27.525, C 6.615.
- Old: `compute_preference_shares` returned resp_id 100, A 0, B 0, C 0. `classify_item_discrimination` listed resp_id as an item. TURF step 1 picked "resp_id" at 100% reach.
- New: shares A 65.861, B 27.525, C 6.615 (matches hand); discrimination lists A, B, C; TURF step 1 is A at 100%. `strip_respondent_id_cols` at `R/utils.R:1010-1022`, applied at `:741`, `:791`, `:844` and `R/11_turf.R:138-143`. The shared engine (`modules/shared/lib/turf_engine.R:254-257`) is untouched, as ordered.
- Head-to-head A vs C: 90.6 / 9.4 on both trees (the old function matched the two item columns by name, so resp_id never entered that comparison).
- Remnants: see F3.

### C1 + M1 / A2: Stan data block and the anchor's seat (data-contract level only)
cmdstanr is not installed here (`requireNamespace` FALSE), so no sampling ran. PROG-1 stands.
- Old `prepare_stan_data` returns character members `item_ids`, `resp_ids` in the same list that went to `$sample()`; designated anchor I2 sat at index 2 while the model fixes `beta[r,J]` (`stan/maxdiff_hb.stan:40, 52`).
- New: `stan_declared_data()` (`R/07_hb.R:319-343`) returns exactly N, R, J, K, resp, choice, shown, is_best, all numeric. With Anchor_Item on I2, `item_ids` becomes I1, I3, I4, I2 and `anchor_item` is 4 = J (`R/07_hb.R:191-211`); `original_item_order` is retained and `extract_hb_results` maps back (`:439-445`); `reorder_utility_columns` round-trips resp_id, I1..I4.
- Cross-check of the encoding: for respondent R1 task 1, the items decoded from the `shown` matrix through the reordered `item_ids` equal the long data's items, and the encoded best equals the long data's best.
- Anchor edge cases (asked for): a designated anchor with Include = 0 is ignored and the last included item becomes the anchor on both the Stan prep and the logit path (I4 in the probe), consistently. An Include = 0 item still present in the fielded data yields NA in `shown` on both trees; the new M4 validation (`R/02_validation.R:413-437`) refuses that case before it gets here (executed, see A7). A single-item study is refused upstream by `parse_items_sheet` (`R/01_config.R:684-694`, read, not executed).
- Unverified: whether cmdstanr's `write_stan_json` accepts the declared list, whether sampling converges, and everything downstream of `fit$summary()`. Also read-only: see F5 on what `HB_Utility_SD` means under Stan.

### C3 / A3: position-coded choices
Fixture: 2 respondents, 2 tasks; design T1 = APPLE, BANANA, CHERRY and T2 = CHERRY, DATE, APPLE; positions T1 best 1, worst 3; T2 best 3, worst 2 for both respondents.
Hand computation: APPLE shown 4, best 4, Best% 100, Net 100; CHERRY shown 4, worst 2, Worst% 50, Net -50; DATE shown 2, worst 2, Worst% 100, Net -100; BANANA shown 2, Net 0.
- Old: `validate_survey_data` passed the data as valid; counts came out 0 for every item on every column, exactly the shipped defect.
- New: validation under ITEM_ID refuses naming the setting ("look like task positions ... set Choice_Value_Type = ITEM_POSITION", `R/02_validation.R:473-478`); under ITEM_POSITION the decode (`R/03_data.R:526-546`) produces the hand-computed table to the digit.
- End to end (section 3): a 60-respondent, 6-task, weighted, position-coded run through the regenerated template matched a hand computation of weighted Best% and Worst% for all eight fielded items to 6 decimal places.
- Edge cases (asked for): position 0 refuses (`DATA_CHOICE_POSITION_INVALID`); a position of 7 with 3 items per task refuses at validation and at decode; NA decodes to no choice, silently, and the task is then counted by the M2 disclosure. Two gaps: see F6 (NA design slot) and F7 (fractional position).

### H1 / A4: segments join on the configured ID
Fixture: `Region` deliberately column 1, `RespID` column 2, four respondents (North: R1, R3; South: R2, R4).
- Old: `compute_segment_scores` returned NULL (join on column 1 matched nothing).
- New: with `resp_id_var = "RespID"` the segment levels North and South both resolve (`R/08_segments.R:203-235`); the production caller passes the configured variable (`R/00_main.R:1049-1050`). A missing ID column refuses `DATA_SEGMENT_ID_MISSING`.

### H2 / A4: configured weight or ID column absent
- Old: `Weight_Variable = "Wieght"` validated clean; `build_maxdiff_long` used weight 1 for everyone and `compute_study_summary` reported `weighted = TRUE`. All-NA, negative, zero and character weight columns all validated clean.
- New: the typo refuses with the exact consequence in the message (`R/02_validation.R:331-350`); all-NA refuses ("Weights contain 2 NA values"); negative and zero refuse ("non-positive"); a single NA refuses; a blank `Weight_Variable` cell is NULL after `get_scalar` and means unweighted. `validate_maxdiff_weights` (`R/02_validation.R:629`) is now on the production path via `R/00_main.R:640-648`.
- Gap: a character weight column throws an uncaught R error instead of refusing. See F8.

### H3 + M13 / A4: no positional design fallback; task number infix
- Old: with design Task_Number 101/102 against mapped tasks 1/2, `build_maxdiff_long` silently used design rows 1 and 2 by position and attributed every choice. Same with tasks 1 and 3 in the design.
- New: both cases refuse `DATA_DESIGN_TASK_MISMATCH` with counts and examples (`R/03_data.R:511-518, 587-600`). Note the production caller wraps this in `DATA_RESHAPE_FAILED` and carries the original text in `details` (`R/00_main.R:665-680`); the context survives.
- M13, `parse_survey_mapping` (`R/01_config.R:955-965`), old then new: `MaxDiff_T1_Best` NA then 1; `Q12_T1_BestT2` NA then 1 (first T-infix wins, which is the right reading); `Best_3` 3 then 3; `Task_12_Best` NA then 12; `T1Best` NA then 1; `Item10_T2_Worst` NA then 2; `MD_Best_T04` 4 on both; `Q5_task 3_worst` NA then 3; `MD_10_Best` NA on both (no T-infix, no trailing digit); `Best` NA on both.

### H4 + H5 / A5: GUI honesty (source level, plus the object contract)
- `maxdiff_with_refusal_handler(maxdiff_refuse(...))` returns an object of class `turas_refusal_result` carrying `code` and `message` on both trees, so the new GUI branch (`run_maxdiff_gui.R:420-442`) has what it tests for. The `sink(type = "message")` pairing (`:387-397`) is read only. No Shiny session was run.
- But see F2: `run_maxdiff` returns a non-refused list when the HTML report refuses, so the GUI branch would still show success in that case.

### H6 + M10 + M14 + M15 / A6: template and config
- Old committed template through the old loader: refused. Through the new loader: refused `CFG_SURVEY_MAPPING_MISSING_COLUMNS`. (The old loader's refusal code was not captured by my probe; the refusal itself was observed.)
- New committed template through the new loader: loads, mode DESIGN, `Data_File_Sheet` integer, mapping columns Field_Type / Field_Name / Task_Number, three segment rows.
- ANALYSIS mode (asked for, the round-trip test only covers DESIGN): I regenerated the template from `create_maxdiff_template.R`, rewrote PROJECT_SETTINGS to ANALYSIS with a synthetic CSV and design workbook, and it loaded (mode ANALYSIS, Choice_Value_Type ITEM_POSITION, Weight_Variable Weight) and ran to a results workbook. Details in section 3.
- M10: duplicate `Seed` rows refuse `CFG_DUPLICATE_SETTING`; an unknown name prints `MAXD_UNKNOWN_SETTINGS` (test executed as part of the suite; `R/01_config.R:439-449, 1093-1114`).
- Doc drift left behind: see F9.

### A7: M3, M4, M7, M8, M9
- M4: an Include = 0 item present in the fielded design fails validation (suite test executed; `R/02_validation.R:413-437`).
- M7: SUMMARY sheet carries four per-engine weighting rows (observed in the end-to-end workbook, `R/09_output.R:392-410`). TURF weights change the numbers: on a 40-respondent synthetic set with weights 5 on ten respondents and 0.2 on thirty, step-1 reach moved from 72.5% unweighted to 96.1% weighted, so the weights reach the engine (`R/00_main.R:1087-1093`).
- M8: `add_count_confidence_intervals` is gone (`R/05_counts.R:278-286` note); the deviation (bootstrap functions kept) is logged and reasonable.
- M9: NA-version respondents are counted (`R/03_data.R:486-490`; suite test executed).
- M3: manual caveat present (`docs/USER_MANUAL.md:636-641`). No code change; acceptable under the handover's "at minimum".

### A8: recovery and counts math
- Counts math tests: the hand-computed unweighted and weighted expectations in `test_recovery_and_counts_math.R:913-951` are correct (I re-derived them) and they pass.
- Recovery seed question (asked for): the seeds do not make rho > 0.9 trivial, the truth does. Running the test's simulator with seeds 1 to 8 at n = 80, 30 and 15 respondents gave Spearman rho = 1.000 for both the logit and the EB estimator in every case, because the six true utilities span 3.3 logits. The test still discriminates: choices generated from a flat truth give rho = 0.6 against the test's truth vector, which fails the bar. A weaker truth (say a 0.3-logit spread) would make the test informative about estimator precision; as written it is a sign-and-order check.

---

## 3. End-to-end synthetic run (not in the handover, run to see the deliverable)

Loaded the module the way `R/00_main.R` loads itself (shared lib, then `R/00_main.R` only, which sources the rest once). How `launch_turas()` loads the module was not checked. Regenerated the template, switched it to ANALYSIS, and ran `run_maxdiff()` on 60 synthetic respondents, 6 tasks of 4 items from the template's 10, choices simulated from a known utility vector, position-coded, with a `Weight` column (0.5 to 2), `Region` as column 1, and the respondent ID as column 2. Run twice: numeric IDs (10001..10060) and character IDs (R001..R060). Output went to the scratchpad only.

What matched: ITEM_SCORES weighted Best% and Worst% equal a hand computation from the raw data and design for every fielded item (for example ITEM_02: shown 312.436, Best% 59.998848, Worst% 1.546877 on both sides). SUMMARY carries the four weighting rows. INDIVIDUAL_UTILS has resp_id plus one column per fielded item. TURF_RESULTS is populated. MODEL_DIAGNOSTICS says `Method empirical_bayes_shrinkage`. With character IDs the HTML report was produced, shows "Spread (SD)" once and ">SE<" never, and contains no "resp_id" string.

What did not:
- Numeric IDs: HTML report refused (`MAXD_HTML_TRANSFORM_FAILED: row names contain missing values`), no simulator written, and the run ended `[TRS PASS] MAXDIFF - ANALYSIS COMPLETED SUCCESSFULLY`. Findings F2 and F3.
- Both runs: ITEM_SCORES has no `Logit_Utility`, `Logit_SE`, `HB_Utility_Mean` or `HB_Utility_SD` column although both models ran. Finding F4.
- Both runs: two template items my random design never fielded came out with NA percentages, and the report then dropped its counts table and diverging chart with two one-line console notices. Finding F10.
- The template ships `Generate_Stats_Pack = NO`, so no stats pack was produced and the M6 provenance string was verified by reading `R/00_main.R:798-807` only, plus the M6 source-level test.

---

## 4. Findings

Severity is about client-facing consequence, not effort.

### F1. The suite is red at the tip and every record says it is green (BLOCKING)
`modules/maxdiff/tests/testthat/test_design.R:13`, `test_logit.R:240, 284`, `test_data_reshape.R:253-256, 319-323`; `docs/v2_lift/SESSION_A_NOTES_MAXDIFF.md` ("902 pass / 0 fail / 0 skip"); commit `525bcc30` message; `docs/v2_lift/V2_LIFT_PROGRAM.md:41`.
Section 1 has the numbers. The specific loss: the one test that asserts non-zero counts from position-coded data, the proof of the headline C3 fix, never executed. The fix is test-only and already exists as commit `992d945c` on `feature/maxdiff-v2-report`; it belongs on this branch, not a downstream one, and the three documents need the true figures.

### F2. A refused HTML report leaves the run status PASS (HIGH)
`modules/maxdiff/R/00_main.R:1264-1274`: when `html_result$status` is not PASS the code only `cat`s "HTML report failed"; it never calls `add_warning`, so `run_result` records no event and the banner prints `[TRS PASS] ... COMPLETED SUCCESSFULLY`. Observed in the numeric-ID run (section 3). The `error =` branch at `:1279-1284` does add a warning, so a crash counts and a refusal does not. Consequence in the GUI: the new H4 branch sees a non-refused result and shows "MaxDiff completed successfully!" while the client deliverable was not written. Fix: `add_warning` in the else branch, and consider returning PARTIAL.

### F3. C2 survives in the report and simulator layer (HIGH)
The handover named four sites; these seven still keep every numeric column, so a numeric `resp_id` stays an item:
- `modules/maxdiff/lib/html_simulator/01_simulator_data_transformer.R:52-58` and `:97`: each respondent's `utilities` vector gets the ID as element 1 while the item list comes from `config$items`. Observed: 3 items, 4 utilities per respondent, first value 10001. The engine indexes by item position (`lib/html_simulator/js/simulator_engine.js:89-90, 338, 407`), so every item would read the previous item's utility and the last item would read nothing. Not observed live only because F3's next line refuses the report first.
- `modules/maxdiff/lib/html_report/01_data_transformer.R:497-500` (diagnostics): crashes on numeric IDs with "row names contain missing values", which the wrapper at `99_html_report_main.R:205-215` turns into a report refusal. This is the crash behind F2's observation.
- `01_data_transformer.R:742` (head-to-head matrix): observed a `resp_id` row and column of 50s.
- `01_data_transformer.R:914-916` (utility distributions, violin), `:995-996` (segment enrichment), `:1158-1159` (segment head-to-head), `99_html_report_main.R:603` (per-segment distributions): same filter, read, not each executed.
This was a handover gap rather than an instruction ignored, but it is the same silent-wrong-number class as C2 and the branch's notes record C2 as closed. Fix: apply `strip_respondent_id_cols` at each site (it exists for exactly this).

### F4. ITEM_SCORES never carries the logit or HB utility columns (HIGH, pre-existing, out of Session A scope)
`modules/maxdiff/R/00_main.R:1013-1016, 1030-1033` merge `Logit_Utility`, `Logit_SE`, `HB_Utility_Mean`, `HB_Utility_SD` into `count_scores`. `modules/maxdiff/R/09_output.R:463-473` then merges the same columns in again, so R names them `.x` and `.y`; the column pick at `:513-522` finds neither and drops all four. `Rescaled_Score` and `Rank` then derive from `Net_Score` (`:476-488`), not from any utility, while the manual (`docs/USER_MANUAL.md:722-727`) documents the utility columns as present. Reproduced by calling `write_item_scores_sheet` directly on both trees: with utilities already in `count_scores` the sheet has 11 columns and no utility; with them absent from `count_scores` it has all four. The old main merges the same way (`f03ee8df` `00_main.R:990`), so this predates Session A and the July review missed it. It should not be lost: it is the flagship sheet.

### F5. `HB_Utility_SD` means two different things on the two HB paths, and the display fix covers one (MEDIUM, read only)
Under EB, `HB_Utility_SD` is the across-respondent spread of shrunken scores (`R/07_hb.R:609`), and the M5 fix labels it "Spread (SD)" in the report. Under Stan it is `mu_summary$sd` (`R/07_hb.R:410`), the posterior standard deviation of the population mean: a precision, not a spread. The manual row (`docs/USER_MANUAL.md:725`, "Standard deviation of HB utility across respondents") describes the EB meaning only. The strategy quadrant (`lib/html_report/04_chart_builder.R:497, 575, 596`) plots the column as "Standard Deviation" and labels its quadrants "Divisive" / "Polarising Leaders", a heterogeneity reading, which would be wrong on a real Stan run. The 07_hb.R comment at `:614-616` that the stamp "travels into the Excel output beside the numbers" is not true: `Estimation_Method` is never written to a sheet; only `model_fit$method` reaches MODEL_DIAGNOSTICS (`R/09_output.R:798-805`). Not executable here (cmdstanr absent).

### F6. A position that lands on an empty design slot decodes to NA silently (MEDIUM)
`modules/maxdiff/R/03_data.R:529`: the range check is `p > length(items_shown)`, and `items_shown` keeps NA slots, so a design row with 3 columns but 2 items and a chosen position 3 passes the check and decodes to `NA`. Observed: the task shows no best and an NA `is_worst` row. Under ITEM_ID coding the same design yields an `NA` item row with NA flags on both trees (pre-existing). Neither refuses and neither is counted by the M2 notice as a dropped task in the counts path.

### F7. A fractional position truncates silently (LOW)
`R/03_data.R:527`: `as.integer("2.7")` and `as.integer(2.7)` both give 2, so "2.7" decodes to BANANA. Observed. A non-integer in a position column is a corrupt export and should refuse.

### F8. A character weight column crashes instead of refusing (LOW)
`R/02_validation.R:629-680` (`validate_maxdiff_weights`): `weights_valid <= 0` on character input throws "non-numeric argument to binary operator". Observed with values "1,2" and "0,8" (a locale export). The run would end as `BUG_INTERNAL_ERROR` rather than a `DATA_*` refusal naming the column.

### F9. Doc drift the A6 pass left behind (LOW)
`modules/maxdiff/README.md:127-130` and `:225` still describe a `STUDY_IDENTIFICATION` sheet that A6 deleted (its rows moved to PROJECT_SETTINGS). `docs/README.md` and `TECHNICAL_REFERENCE.md` were checked and are clean.

### F10. Items in ITEMS but never fielded silently drop two report sections (LOW, pre-existing)
With two Include = 1 items absent from every design row, counts come out NA for them and the report logs "Table error (counts): missing value where TRUE/FALSE needed" and "Chart error (diverging) ..." then omits both. M4 checks the design against ITEMS in one direction (`R/02_validation.R:413-437`); the other direction (included but never shown) is not checked. Observed in the character-ID end-to-end run.

### F11. M2 disclosure reaches the console only (LOW, undeclared deviation)
A5 asked for dropped-task counts "in the summary and stats pack". `MAXD_TASKS_DROPPED` is printed by `prepare_logit_data` (`R/06_logit.R:262-266`) and `prepare_stan_data` (`R/07_hb.R:277-282`) and nowhere else: no hit in `R/09_output.R`, the stats pack builder in `R/00_main.R`, or `lib/html_report`. The notes do not list this as a deviation.

### F12. Small things (LOW)
- `stan_declared_data`'s refusal code `CALC_STAN_DATA_INVALID` is rewritten to `CFG_CALC_STAN_DATA_INVALID` by the guard's prefix whitelist (`R/00_guard.R:89-91`). Observed.
- The template ships `Generate_Stats_Pack = NO` while `get_default_output_settings()` says TRUE (`R/01_config.R:1203`). Explicit, so not silent, but the two defaults disagree.
- `options(turas.generate_stats_pack = ...)` set by the GUI (`run_maxdiff_gui.R:395`) persists for the R session, so a later headless run in the same session inherits the checkbox (`R/00_main.R:420-427`).
- Pre-existing, seen only because my first harness sourced `11_turf.R` twice: `.shared_run_turf <- run_turf_analysis` (`R/11_turf.R:108`) captures the wrapper itself on a second source and every TURF call then fails with "unused arguments". Production sources `00_main.R` once, so this is a hazard for interactive re-sourcing, not for the GUI.
- Name collisions with other modules are pre-existing and not Session A's: `validate_survey_data` also exists in `modules/confidence/R/02_load_data.R:132` and `extract_hb_results` in `modules/conjoint/R/11_hierarchical_bayes.R:395`. Whether the launcher isolates module environments was not checked.

---

## 5. What I could not verify

- The Stan sampling path end to end: cmdstanr is absent (PROG-1). A2 is verified at the data-contract level only, as the notes also say.
- Whether cmdstanr's JSON writer accepts the declared list. The review's claim that it refuses character members is taken from the July review, not re-checked.
- The Shiny GUI (H4, H5): object contract and source read only. No Shiny session ran.
- F3's four read-only sites (`:914`, `:995`, `:1158`, `99_html_report_main.R:603`): the same filter pattern, not each executed.
- The stats pack provenance string (M6): read at `R/00_main.R:798-807` and covered by the source-level test; no stats pack was generated because the template default is NO.
- The old loader's refusal code on the old template: the refusal was observed, the code string was not captured.

---

## 6. What would turn this into a pass

1. Land the three test corrections on this branch (they exist as `992d945c` on `feature/maxdiff-v2-report`), rerun the suite from the repo root, and write the observed numbers into the notes, the tracker row and (if rewritten) the commit message. Do not amend a pushed commit; `feature/maxdiff-correctness` is on `origin`.
2. F2: `add_warning` when the HTML report refuses.
3. F3: `strip_respondent_id_cols` at the seven report and simulator sites, plus one test that runs the report transformer and the simulator transformer on numeric IDs.
4. Decide F4 (out of Session A scope but one line to fix: drop the second merge or merge only columns not already present) and add a test that reads ITEM_SCORES back and finds `Logit_Utility`.
5. F6, F7, F8 are each a few lines and belong with the C3 and H2 work they sit beside.
6. F5 needs a ruling on what `HB_Utility_SD` should mean; the honest minimum is a manual row and a quadrant caption that say which path produced it.

Then Duncan regenerates through `launch_turas()` and eyeballs; a second look at this document's F2 and F3 lines in the regenerated output would close the review.

---

## 7. What was done about it (same session, same day)

Six new commits on `feature/maxdiff-correctness`, on top of `6d3e0165`, none amended:

| Commit | Findings | What changed |
|---|---|---|
| `7ddb716b` test | F1 | The three test corrections, taken from `992d945c` on the v2-report branch. |
| `e32c7b2f` fix | F3 | `.md_drop_id_cols()` in the report transformer, applied at the five transformer sites, the per-segment distribution in the report main, and the simulator transformer. |
| `f76ae536` fix | F6, F7, F8, F10 | Decode range counts real items and refuses fractional positions; a non-numeric weight column refuses; an included item no design row shows refuses. Also the study summary's dropped-task count. |
| `dc9af3ab` fix | F2, F4, F11 | Late events (simulator, report) fold into the TRS state and `run_result` is rebuilt; the ITEM_SCORES writer merges only columns not already present; SUMMARY row and stats-pack assumption for dropped tasks. |
| `54dd9d30` fix | F5, F9, F12 | Quadrant axis and title name the statistic by estimator; manual row gives both meanings; 07_hb.R comment corrected; README drift removed; `CALC_` accepted by the guard; 11_turf.R captures the shared engine once; template ships `Generate_Stats_Pack = YES` and was regenerated. |
| `9f12a31e` test | all | `test_review_followups.R`: unit tests per finding plus one integration run. |

Verified by execution, from the repo root:
- Suite: 945 expectations, 0 failed, 0 skipped, 0 errors (from 902 with 4 erroring tests).
- Numeric-ID end-to-end run (60 respondents, weighted, position-coded, ID in column 2): HTML report written, no `resp_id` string in it, 10 utilities per respondent for 10 items in the simulator island, ITEM_SCORES with `Logit_Utility`, `Logit_SE`, `HB_Utility_Mean`, `HB_Utility_SD`, counts matching the hand computation to 1e-13, stats pack written with the honest EB method string, quadrant axis reading "Spread across respondents (SD)".
- Character-ID run: same, report produced.
- F2 by a stubbed refusing report module: the banner reads `COMPLETED WITH 1 EVENT(S)` and `run_result$status` is PARTIAL with the refusal in `warnings`. Before the fix the same probe ended `[TRS PASS]` with zero warnings.
- F10 fired on my own earlier probe config (two template items never fielded) and named them; the probe was corrected to field every item.

F5, ruled and implemented later the same day (`9591c187`): `HB_Utility_SD`, `Q5` and `Q95` are the spread of utilities across respondents on both HB paths, computed by one helper from the shipped individual utilities; the precision of the population mean moves to `HB_Mean_SE` (with `HB_Mean_Q5` / `HB_Mean_Q95`), NA under the fallback. The report always labels the column Spread (SD) and shows an SE column only when a posterior exists. Under the fallback the spread numbers narrow, because they were measured on the unshrunken scores before and on the shrunken individual utilities now. Suite 957 / 0 / 0 / 0.

Not done, deliberately:
- The Run_Status sheet in the results workbook is written before the report step, so a report refusal appears in the console, the banner, the GUI and `run_result`, but not on that sheet.
- The Stan sampling path is still not executed (PROG-1).
- The F12 name collisions with the confidence and conjoint modules are untouched.
