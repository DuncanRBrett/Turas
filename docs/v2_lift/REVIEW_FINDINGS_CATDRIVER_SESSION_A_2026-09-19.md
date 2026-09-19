# CatDriver Session A. Independent pre-merge review findings

**Date:** 2026-09-19
**Branch:** `feature/catdriver-correctness` at `9de57c83`, cut from main `46eb9a01`, thirteen commits, unmerged, unpushed
**Reviewer:** Claude Fable 5.1, briefed as independent (no shared working notes; the author's session notes were read only after section 4 below was written)
**Stack:** R (glm, ordinal::clm, MASS::polr, nnet::multinom, car::Anova), openxlsx, testthat

I did not write these changes. Every claim in the brief, the commit messages and the code comments was treated as a claim to test. Every "verified by execution" below names the script or command; the scripts sit in the scratchpad folder of this session and are quoted where the number is load-bearing.

## 1. Verification gates

Run from the repo root with plain `Rscript`, counts from `as.data.frame(testthat::test_dir(..., reporter = "silent"))`.

| Gate | Command | Result |
|------|---------|--------|
| catdriver suite, branch | `testthat::test_dir("modules/catdriver/tests/testthat")` | PASS. 278 tests, 921 expectations, 0 failed, 1 skipped, 1 warning |
| shared suite, branch | `testthat::test_dir("modules/shared/tests/testthat")` | PASS. 469 tests, 1,353 expectations, 0 failed, 4 skipped (the summary reporter lists 7 skips, three of them code outside `test_that`), 19 warnings, all pre-existing minify size-ratio notes |
| catdriver suite, main `46eb9a01` (detached worktree) | same command | 227 tests, 676 expectations, 0 failed, 1 skipped, 2 warnings |

The author's figures were 278 / 919 / 0 / 1 and 469 / 1,330 / 0; mine differ by two and twenty-three expectations. The cause was not traced (unverified); the test and failure counts agree. The one surviving catdriver warning is a raw `glm()` call at `test_catdriver.R:873`, not the engine.

The skip is the same skip as on main (`write_catdriver_output creates valid Excel file`, mock structure incomplete). It was there before this session and is not new green.

## 2. Method

Four independent readers on separate concerns (the weighted likelihood machinery; the refusal and guard layer in the GUI's source order; the subgroup comparison, the output sheets and the unweighted-path regression; the test suite's honesty), each told not to read the author's notes, each writing only to its own scratch folder. I re-verified every CRITICAL and every load-bearing HIGH myself, in both directions, against implementations written from the statistical definition:

- A detached worktree of main `46eb9a01` reproduces the old behaviour.
- A loader that sources the module in the GUI's literal order (`run_catdriver_gui.R:583-600`, identical on both trees) runs the pipeline the way a real run takes it.
- My own fixture set, regenerated from `examples/demo/generate_demo.R` into the scratchpad, plus a weighted multinomial config the shipped generator deliberately does not make (its own comment: "Unweighted - nnet::multinom has limited weight support"). The author's files under `examples/demo/` were not used.

## 3. The three CRITICALs and the load-bearing HIGHs, re-derived

All verified by execution, both directions, unless stated.

### C1. Weighted multinomial importance (`05_importance.R`, `04b_multinomial.R`)

Independent implementation (`coord/c1_independent.R`): fit `nnet::multinom` with mean-1 weights on the 456 rows the module kept, compute the weighted log-likelihood myself as `sum(w_i * log p_i(y_i))` from `predict(type = "probs")` (no `logLik()`), refit without each driver, LR = -2(ll_reduced - ll_full), share = LR / sum(LR).

| Driver | main chi-square | main share | branch chi-square | independent chi-square | branch share | independent share |
|---|---|---|---|---|---|---|
| service_quality | -212.23 | 0 | 28.467 | 28.467 | 40.6 | 40.65 |
| price_perception | -226.53 | 0 | 20.516 | 20.516 | 29.3 | 29.30 |
| age_group | -230.77 | 0 | 12.122 | 12.122 | 17.3 | 17.31 |
| support_experience | -242.29 | 0 | 4.741 | 4.741 | 6.8 | 6.77 |
| contract_type | -241.51 | 0 | 4.187 | 4.187 | 6.0 | 5.98 |

Main shipped every driver at 0 per cent with p = 1 under PASS. Branch: max absolute chi-square difference from my implementation 4.0e-4 (optimiser tolerance), max share difference 0.05 points, ranks identical. The method column reads "LR-test share (weighted multinomial refits)".

### H1. Weighted null models (`04a_ordinal.R`, `04b_multinomial.R`)

Independent weighted null: `ll_null = sum(w_i * log(pi_hat[y_i]))` with `pi_hat` the weighted outcome proportions on the same rows.

| Path | main McFadden | branch McFadden | independent McFadden | branch LR vs null | independent LR |
|---|---|---|---|---|---|
| multinomial, weighted | -0.174 | 0.0713 | 0.0713 | 71.326 | 71.326 |
| ordinal (clm), weighted | 0.135 | 0.3149 | 0.3149 | 306.892 | 306.892 |

Main's ordinal 0.135 came from a raw-scale weighted full log-likelihood (-421.7) against an unweighted null; when the weights are multiplied by five, main's ordinal McFadden becomes -3.32 (`coord/h2_scale.R`). The branch's log-likelihoods equal mine to four decimals.

### H2. Weight scale invariance (`07_utilities.R::normalise_catdriver_weights`)

`coord/h2_scale.R`: the same config run with `survey_weight` and with `survey_weight * 5`.

| Tree | Path | max abs diff in SE | median SE ratio (x5 / x1) | max abs diff in importance chi-square |
|---|---|---|---|---|
| main | binary | 0.267 | 0.4472 | 257.3 |
| main | ordinal | 0.243 | 0.4472 | 706.3 |
| branch | binary | 2.8e-16 | 1.0000 | 2.3e-13 |
| branch | ordinal | 5.6e-16 | 1.0000 | 2.3e-13 |

0.4472 is 1/sqrt(5): on main every standard error followed the weight total. On the branch estimates, SEs, p-values, CIs, importance and McFadden are identical to machine precision, and the degraded reason names the raw mean (1.2631 and 6.3156 respectively).

### The binary and ordinal importance stamp ("LR chi-square share (car::Anova type II)")

`coord/anova_weights.R`: on a weighted binomial glm fitted exactly as `04_analysis.R` fits it (local `fit_data`, `weights = .wt`), `car::Anova(type = "II")` reports 50.920 for service_quality; my manual weighted deviance difference between the full and the reduced weighted fits is 50.92049; the unweighted difference is 50.287 and the Wald chi-square is 44.06. Anova's refits carry the weights, and for a glm the statistic is the likelihood-ratio one, so the new stamp is right there and the old hardcoded "Type II Wald" was wrong. For the clm the same call dispatches to `Anova.default`, which is Wald (139.788 against a manual LR of 203.593); the stamp is wrong on every ordinal run. That is F1.

### C3. The refusal system (`00_main.R`, `08_guard.R`, deleted `00_guard.R`)

`coord/c3_repro.R`, sourced in GUI order on each tree, with `outcome_type = nominal`:

- main: `run_status = "ERROR"`, class `catdriver_error_result`, message `unused arguments (reason = "CFG_OUTCOME_TYPE_INVALID", fix = paste0(...))`, printed as "BUG_INTERNAL_ERROR: Unexpected CatDriver Error ... Report this error to the Turas development team". `code`, `title` and `how_to_fix` all NULL.
- branch: `run_status = "REFUSE"`, class `catdriver_refusal_result`, `code = "CFG_OUTCOME_TYPE_INVALID"`, `how_to_fix = "Change outcome_type to one of: binary, ordinal, multinomial"`.

The same pair was observed by accident with an empty data file (`DATA_EMPTY`), and again inside the subgroup loop on main, where the 61+ group's refusal surfaces as `Subgroup '61+' error: unused arguments (reason = "MAPPER_DRIVER_LEVEL_MISMATCH", ...)` and on the branch as `Subgroup '61+' failed: MAPPER_DRIVER_LEVEL_MISMATCH`.

### C2. The subgroup comparison (`11_subgroup_comparison.R`)

`coord/h5_c2.R` on `demo_config_binary_subgroup.xlsx`:

- main: console `[WARNING] Subgroup comparison generation failed: missing value where TRUE/FALSE needed`; `subgroup_comparison` NULL; status PARTIAL for unrelated reasons.
- branch: `or_comparison` 9 rows x 17 columns, `importance_matrix` 4 x 14 with a `classification` column (one Universal, three Mixed), `model_fit` 4 rows, two insights, "[OK] Subgroup comparison sheets added". Reader C rebuilt the comparison independently from each group's mapper-schema `odds_ratios` frame (`readerC/scripts/check_subgroup.R`): max absolute difference 0 on every `_or`, `_p` and `or_ratio` column, `_ci` and `notable` identical, Excel OR sheet against the object 4e-15, Summary sheet ranks and shares 0, classification identical, matrix ranks equal to each group's own `importance$rank`. Built from the four survivors after 61+ refused; the refusal is disclosed on Run_Status.

### H5. Bootstrap under weights (`07_utilities.R::fit_model_for_bootstrap`)

Same script, `bootstrap_ci = TRUE` on the weighted binary config:

- main: `[WARNING] Initial model fit failed - cannot run bootstrap`, `bootstrap_results` NULL, no boot columns, status PASS, no degraded reason.
- branch: 200 of 200 resamples usable, `boot_ci_lower` / `boot_ci_upper` / `boot_median_or` present and finite (service_quality Excellent OR 0.079, Wald CI 0.035 to 0.181, bootstrap CI 0.027 to 0.166), caveat "All resamples were usable."

### M3. Proportional odds on the default clm engine

`coord/h1_ordinal.R`: my own `ordinal::nominal_test` on my own weighted clm gives p = 0.3000, 0.4037, 0.1320, 0.4608, 0.2434 for the five drivers; the module's `proportional_odds$p_values` are 0.2999936, 0.4036756, 0.1319936, 0.4607780, 0.2433729. Agreement to 1e-6. Where that result is written is another matter (F-series below).

## 4. Findings

Numbered from F1 so they do not collide with the July review's IDs. Each says how it was verified and by whom (the coordinator, or one of the four readers, whose scripts sit under the session scratchpad in `readerA/`, `readerB/`, `readerC/` and `readerD/`). Severity follows the production-review tiers: CRITICAL is a silently wrong client-facing number and blocks the path it sits on; HIGH should be fixed before Duncan regenerates for a client; MEDIUM after; LOW is polish; OBSERVATION is context.

### CRITICAL

**F3. The subgroup comparison collapses a multinomial outcome's levels into one unlabelled row.** Scope: every multinomial run with a `subgroup_var`; binary and ordinal subgroup runs are unaffected. `11_subgroup_comparison.R:324-353` keys the comparison on `driver || level` only. A multinomial OR frame has K-1 rows per driver level, one per `outcome_level` (`09_mapper.R:333-372`), so the loop overwrites and keeps whichever outcome level came last. My own run (`coord/fx_branch/multi_sub`, plan_preference by age_group, `baseline_category`, unweighted): the Total group's OR frame has 18 rows over outcome levels Premium and Standard, and for service_quality Excellent holds Premium vs Basic OR 11.356 (p 3.5e-06) and Standard vs Basic OR 2.180 (p 0.062); `or_comparison` has 9 rows, no `outcome_level` column, and that driver level reads `Total_or 2.18, Total_p 0.062, or_ratio 2.16, notable Yes`. The same numbers reach the "Subgroup OR Compare" sheet with no outcome level (Reader C first, coordinator re-run). The run is PARTIAL for unrelated reasons; nothing says the table is one level of two. Main shipped nothing on this path because the comparison was dead. Verified by execution (coordinator and Reader C). Fix: key on `driver || level || outcome_level` and carry the level into the sheet, or refuse the comparison for multinomial outcomes until it does, with a reason.

**F4. The ordinal probability lift is not a lift of any outcome level.** Scope: every ordinal run, because `probability_lifts` defaults on and the HTML report is the deliverable that shows it; binary and multinomial lifts are correct. `04a_ordinal.R:253-256` stores `predict(model, type = "prob")$fit` with no `newdata`, which for a clm is each respondent's probability of their own observed category. `calculate_probability_lift` then averages that by driver level. On the unweighted ordinal demo `pred_probs` is a numeric vector of 456; its maximum difference from P(observed category) is 0 and from P(High) is 0.978. The lift table says service_quality Excellent +0.125 (0.748 vs 0.624) labelled `outcome_level = "the modelled outcome"`; the P(High) means by service_quality are 0.072 / 0.229 / 0.472 / 0.829, so a real lift would be +0.757. Main produces the identical numbers; the branch added a label and a callout ("difference in mean fitted probability between the respondents in a category and the respondents in the reference category") that makes a meaningless number read as a defined one. Verified by execution (coordinator and Reader C). Fix: for ordinal, predict the full probability matrix with `newdata` and difference a named column (top category, or each), and say which.

### HIGH

**F1. The ordinal importance statistic is a Wald chi-square stamped as likelihood-ratio.** `05_importance.R`, the line `importance_df$method <- "LR chi-square share (car::Anova type II)"`, and the comment above it saying this was "verified by running it against a manual deviance difference". It was verified for glm only. `car:::Anova.clm` is `class(mod) <- c("clmAnova", class(mod)); Anova.default(mod, ...)`, and `Anova.default` is the vcov-based Wald test; its output column is `Chisq`, not `LR Chisq`. On the weighted ordinal demo, Anova gives 139.788 for service_quality; my manual weighted Wald is 139.7878 and my manual weighted LR is 203.593. Reader A's shares on the same run: LR 53.3 / 24.2 / 13.1 / 6.0 / 3.3 against the shipped 47.0 / 26.3 / 15.2 / 7.3 / 4.2 (ranks identical there). The polr fallback does get LR from `car::Anova.polr`, so the two ordinal engines ship different statistics under one stamp, and the stamp reaches the stats pack Assumptions sheet. The numbers are unchanged from main; the provenance is new and wrong, which is the D5 failure this session was meant to close. Verified by execution (coordinator and Reader A). Fix: stamp the clm path "Wald chi-square share (car::Anova type II on clm)", or compute the LR shares by refitting as the multinomial path does.

**F2. A weight variable that cannot be used runs unweighted under PASS, and the stats pack Declaration still says weighted.** Three routes. (a) A misspelled weight name: `00_main.R:697` enters the weight block only when the column exists, `02_validation.R:455-458` warns. My run with the Weight row pointing at `survey_wieght`: `run_status PASS`, `degraded FALSE`, Run_Status sheet carries nothing, Model Summary reads "Unweighted", and the Declaration reads "Weighting | Yes [em dash] weight variable: survey_wieght" because `00_main.R:1448` sets `weight_variable = config$weight_var` regardless and the shared writer builds that line from it before looking at `weighted`. (b) A character weight column and (c) an all-NA weight column: `normalise_catdriver_weights` imputes every NA to 1 and reports `usable = TRUE`, so the fit is unweighted (all weights 1) while the inference stamp reads "Weighted by 'survey_weight' ... Kish effective n = 456 of 456" (Reader A, `inspect_br_binary_char.log`, `inspect_br_binary_allna.log`). The only disclosure in (b) and (c) is "Weight repairs: 456 missing set to 1", which does not say the analysis is unweighted. The July H11(b) defect (typo'd weight ships unweighted numbers stamped weighted) is therefore closed on the Model Summary and the `weighted` flag, and still open on the Declaration and in the run status. Verified by execution (coordinator for (a), Readers A and B for all three). Fix: refuse with a CFG_ code when the named weight column is absent or non-numeric, or at least degrade with a reason; set `weight_variable` in the payload from what was applied.

**F5. The stats pack Declaration inverts the respondent counts.** `00_main.R:1300-1307` passes `survey_data = prep_data$data` (456 rows after listwise deletion) into `generate_catdriver_stats_pack`, whose `data_receipt$n_rows = nrow(survey_data)` (:1420) prints 456 under DATA RECEIVED, while `data_used$n_respondents = as.integer(n_original)` (:1451) is 500 and the shared writer prints it as "Respondents Analysed" (`stats_pack_writer.R:288-309`). The Declaration of my weighted multinomial run reads "Respondents | 456" and "Respondents Analysed | 500 (44 excluded)". Main printed 456 and 456. The 44 is right; both labels are wrong, and the pack says more respondents were analysed than received. Verified by execution (coordinator, Readers A and B). Fix: `n_rows` from `result$diagnostics$original_n`, `n_respondents` from `n_analysed`.

### MEDIUM

**F6. Every degraded reason reaches the stats pack Warnings sheet as a row with no text.** `00_main.R:1247` records each reason with `turas_run_state_partial(trs_state, "CATD_DEGRADED", "Degraded output", problem = reason)`; the shared writer prints `e$detail` and `e$fix` (`stats_pack_writer.R:521`), never `problem`. The sheet shows "PARTIAL | CATD_DEGRADED | Degraded output" and blanks. The reasons do reach the results workbook's Run_Status sheet and the HTML "Degraded Output" line. Verified by execution (coordinator, Reader B). Fix: pass the reason as `detail`, or have the writer fall back to `problem`.

**F7. The importance method stamp never reaches a client-facing table.** The frame carries `method` (verified: both strings) and the stats pack Assumptions sheet prints it, but `add_importance_sheet` (`06a_sheets_summary.R:310-315`) selects a fixed column list without it and the HTML importance section does not render it (zero hits for "LR-test share" in the generated report). Handover A7 asked for the column because the v2 island needs it; the deliverables do not show it. Verified by execution and reading (coordinator). Fix: add the column to the sheet and a one-line stamp under the HTML importance table.

**F8. The probability-lift outcome level is labelled in the R frame only, and for multinomial it is an arbitrary level.** No workbook has a lift sheet (sheet list: Run_Status, Executive Summary, Importance Summary, Factor Patterns, Model Summary, Odds Ratios, Diagnostics, Interpretation & Limits); the HTML transformer (`lib/html_report/01_data_transformer.R:135-165`) drops `outcome_level`; the rendered lift table header is "Category / Pred. Prob / Ref. Prob / Lift (pp) / Direction". For the multinomial run the probabilities are P(Standard), the alphabetically last level, because `prepare_outcome` (`03_preprocessing.R:311-326`) ignores Order for multinomial; the Variables sheet declares `Basic;Standard;Premium`. TECHNIQUE_GUIDE.md now says "the lift table names in its outcome_level column", which no deliverable does. Verified by execution (coordinator, Reader C). Fix: carry `outcome_level` into the transformer and print "Probability of: <level>" above each lift table; pick the level deliberately (last in the declared Order, or all).

**F9. The proportional-odds result (M3) is written nowhere unless it is a WARNING, and a WARNING arrives without its drivers.** `test_proportional_odds_clm` runs and its p-values match my own `ordinal::nominal_test` to 1e-6. `guard_check_proportional_odds` (`08b_guards_soft.R:130-141`) acts only on `status == "WARNING"`; PASS and NOT_TESTED go nowhere; no output file reads `model_result$proportional_odds`. The ordinal Diagnostics sheet has no proportional-odds row; the HTML has zero hits for "Proportional odds". A WARNING reaches Run_Status only as the flag "Proportional odds assumption may be violated" (F10). Handover A8 asked for "PO assumption not tested" to be disclosed in diagnostics. Verified by execution (coordinator, Reader C). Fix: a Diagnostics row and an HTML diagnostics line for all three states.

**F10. Guard warnings have no consumer; only the terse stability flags reach the workbook, and `result$guard` is the pre-analysis guard.** `guard_summary()` returns `warnings` (`08_guard.R:292`); nothing in `00_main.R` or `06*.R` reads them; `00_main.R:850-855` copies `stability_flags` into `local_degraded`. So the EPP message with its numbers ("Low events-per-parameter ratio (2.5, from 30 minority-class events over 12 parameters). Recommend >= 10") arrives on Run_Status as "Low events-per-parameter ratio"; the direction-sanity text with the current order would arrive as "OR direction mismatch in 3/3 comparisons"; a PO violation naming its drivers would arrive as F9's flag. `00_main.R:305-323` never unpacks `primary$guard`, so `result$guard` holds 0 warnings while `result$guard_summary` holds 2 (Reader B). Pre-existing plumbing, but three of this session's fixes (H3, M2, M3) put their substance into the channel that goes nowhere. Verified by execution (coordinator, Readers B and C). Fix: write `guard_summary$warnings` to the Diagnostics sheet and carry the message text into the degraded reason.

**F11. The direction-sanity guard cannot detect a reversed outcome order.** `08b_guards_soft.R:207-235` compares each OR with the raw share in `outcome_levels[n_levels]`, the level the model itself calls highest. Reversing the Order flips both, so the mismatch count is zero by construction: Reader B instrumented the guard on the ordinal demo and got `checked = 7, mismatches = 0` under `Low;Medium;High` and under `High;Medium;Low`. The H3 fix (return the guard, two-argument flag call) is correct and the crash is gone; the guard it repairs is tautological on the case it is named for, and `CFG_OUTCOME_ORDER_MISSING` checks presence only. `test_ordinal_safety.R` fires the guard with a hand-built coefficient frame, which is why the suite shows it working. Verified by execution (Reader B), by reading (coordinator). Fix: compare against a fixed, order-independent reference (the level the config lists last), or drop the guard and say so.

**F12. The EPP gate's denominator is the single-equation slope count (M2 half fixed).** `08b_guards_soft.R:368` passes `prep_data$n_terms`, the sum of dummies (`03_preprocessing.R:708`). Fitted parameters on the demo: binary 13, ordinal 14 (12 slopes + 2 thresholds), multinomial 26 (2 x 13). On the multinomial demo the gate computes 143 / 12 = 11.9 (no warning) where the true figure is 143 / 24 = 6.0. A second EPP lives in `02_validation.R:427-448` and lands in the Diagnostics sheet with a different number (2.4 versus the guard's 2.5 on Reader B's subsample). Verified by execution (Readers B and C). Fix: count parameters from the fitted model (`length(coef())` or the Hessian dimension) and keep one EPP.

**F13. A bootstrap requested on a multinomial outcome is silently not produced, under PASS.** `00_main.R:967` gates the block on `outcome_info$type != "multinomial"`, so the new "requested but could not be produced" degrade (:1013-1019) never fires. My run with `bootstrap_ci = TRUE` on the multinomial config: PASS, `bootstrap_results` NULL, no degraded reason, not one console line mentioning bootstrap. This is the H5 defect class in a new place, against the A5 rule. Verified by execution (coordinator, Reader A). Fix: a degraded reason "Bootstrap intervals are not implemented for multinomial outcomes" whenever the setting is on.

**F14. The z-squared fallback reports dummy terms, not drivers, and the run cannot use it.** `05_importance.R` `calculate_fallback_importance` calls `aggregate_dummy_importance(importance_df, config)` with no mapping or `prep_data`, so terms are never mapped. With `car::Anova` stubbed to fail, the Importance Summary sheet rows are `service_qualityExcellent | 33.6 ...` through twelve per-level rows, and the branch's new reason fires as "Drivers configured but absent from the importance table: service_quality, price_perception, ..." (all five). The stamp and the degraded reason are the branch's honest addition; the table beneath them is unusable. Pre-existing shape; no natural trigger was found. Verified by execution with a stub (Readers A and B). Fix: pass the mapping through, or refuse instead of falling back.

**F15. With zero or negative weights the delivered vector is not mean 1 and the reported n disagree.** `normalise_catdriver_weights` takes `raw_mean` over positive weights only. `c(2, 4, 6, 0, -3)` returns weights `0.5, 1, 1.5, 0, 0`, mean 0.6, with the stamp "normalised to mean 1". In a pipeline run with zeros (Reader A, `inspect_br_binary_zeros.log`) the model's weight sum is 407 over 456 rows, the stamp says "Kish effective n = 367 of 407", `n_observations` says 456 and the Declaration says 456; the zero-weight disclosure is a `cat()` only (`00_main.R:738-740`), not a degraded reason, not in the workbook. Verified by execution (coordinator, Reader A). Fix: say "mean 1 over the respondents with positive weight" and put the zero-weight count in the degraded reasons.

**F16. `subgroup_min_n` cannot exclude a group and its warning is orphaned.** `00_main.R:465-467` with `08b_guards_soft.R:282-304` warns into the outer guard, whose warnings nothing writes (F10). With `subgroup_min_n = 120`, group 46-60 (113 rows) is fitted and sits in the comparison; the warning "Subgroup '46-60' has 113 observations (below minimum 120)" reaches no degraded reason and no sheet. Verified by execution (Reader C). Fix: treat the setting as a floor (skip the group with a reason) or write the warning.

**F17. Every ordinal run is PARTIAL for a multicollinearity check that is meaningless on a clm.** `04_analysis.R:341` calls `car::vif(model)` on the clm; on both trees the result is GVIF 35847, df 0, adjusted Inf for all five drivers, R's own warning "No intercept: vifs may not be sensible", and the degraded reason "High multicollinearity detected in: service_quality, price_perception, support_experience, contract_type, age_group". Pre-existing, main identical. Verified by execution (Reader B; the coordinator's ordinal runs show the same reason). Fix: compute VIF on an auxiliary linear model of the design matrix, or skip with a stamp for clm as is already done for multinom.

**F18. H1 has no discriminating test.** Reader D reverted all three null-model refits (`04a_ordinal.R:231`, `:479`, `04b_multinomial.R:193`) to unweighted and the whole suite stayed green (`readerD/result_H1.log`, `TOTAL_FAILED: 0`). With mean-1 weights the two nulls are close (LR 319.05 versus 320.85 on the test fixture), and `test_weighted_inference.R:199-228` asserts only that McFadden lies in [0, 1]. The fix is right (section 3); the suite cannot tell. Verified by execution (Reader D). Fix: assert `lr_statistic` equals `-2 * (logLik(weighted null) - logLik(full))` from two fits made in the test, for clm and multinom, with a tolerance that excludes the unweighted null.

**F19. M1 has no discriminating test, and its fixture never raises the warning it is named for.** Reverting `fit_model_for_bootstrap` to discard any resample with a non-integer warning leaves the suite green; on the "separation-prone fixture" `n_discarded = 0` and `kept_flags` is empty on both trees (`readerD/m1_probe.R`), so the keep-and-caveat path has never executed under test. That fixture's bootstrap interval for `servicePerfect` runs from 1.7e7 to 6.6e7, an interval for a separated term. Verified by execution (Reader D).

**F20. The C1 headline test passes on the reverted code.** "weighted multinomial importance is non-negative and recovers the true order" (`test_weighted_inference.R:119-138`) holds with the reduced models refitted unweighted; only the companion at `:141-175` (independent weighted LR, 11.1 versus 16.9) and the `grepl("weighted", method)` string discriminate. The spec asked for a rank-correlation-against-truth test; what shipped is a positional check on three drivers with one dominant effect. The row-alignment test at `:177-195` also passes with its fix reverted, because a reduced model on more rows has a lower log-likelihood so the LR inflates upward, and the code clamps negatives anyway. Verified by execution (Reader D).

**F21. Two tests the handover required were not written.** A3's failure-injection test (comparison handler at `00_main.R:523-545` degrades the run with a reason) and A5's enabled-but-failed bootstrap test (`00_main.R:1013-1019`). `test_subgroup_schema.R:117` only asserts that the builder throws. I executed both handlers myself (the injected comparison failure reaches Run_Status as "Subgroup comparison could not be built: injected comparison failure", status PARTIAL), so the code works; the suite does not know. Verified by reading (Reader D) and execution (coordinator).

### LOW

**F22. Bootstrap edge cases.** A perfectly separated resample hits `maxit` with `converged = FALSE` and is discarded as `non_convergence`, so the M1 narrowing survives for perfect separation and only quasi-separation that still converges is kept (Reader A, `probe06_bootstrap.log`); `kept_flagged` counts flag strings, so a fit raising two warning classes counts as two resamples; the kept-with-warning caveat enters the degraded reasons only when `n_discarded > 0` (`00_main.R:1029`). The caveat text reaches Run_Status when it fires (Reader B) but no other sheet. Verified by execution and reading (Reader A).

**F23. Refusals raised under two `tryCatch` sites lose their identity.** `00_main.R:918-940` wraps `map_terms_to_levels` in `error =`; a `turas_refusal` inherits error, so the nine `catdriver_refuse` sites in `09_mapper.R` surface as `MAPPER_TERM_MAPPING_FAILED` with a generic fix and the original box embedded in `problem`. `00_main.R:1003-1008` records a bootstrap refusal as "Bootstrap CI failed: " with nothing after the colon (`e$message` is empty on a refusal object). Verified by execution with stubs (Reader B). Fix: a `turas_refusal = function(e) stop(e)` handler first, as `05_importance.R:50` now does.

**F24. `PKG_CAR_MISSING` refuses the multinomial path, which does not use car.** `05_importance.R:30-37` checks before the multinomial branch; the refusal text says importance uses `car::Anova`, false for that path. Verified by execution with a shadowed `requireNamespace` (Reader B).

**F25. Subgroup sheets.** `11_subgroup_comparison.R:431` reports `res$group_n`, the pre-deletion count (500 / 147 / 167 / 113 against fitted 456 / 133 / 153 / 105); `06c_sheets_subgroup.R:209-213` writes `_or` and `_p` only, so the `_ci` strings built at `11:346-350` never reach the sheet; Total is classified as a subgroup ("Total has weakest explanatory power"). Pre-existing. Verified by execution (Reader C).

**F26. `diagnostics$analysis_n` is never set.** `02_validation.R:212-213` sets `original_n` only; the Interpretation sheet prints "Sample size: n = " and "Effective n: 409 (% of actual)" with the blanks, on main and branch, and the weighted Executive Summary has no weighting line (`06a:96-99` sprintf over `numeric(0)`). The branch's stats-pack count works only through the `%||% nrow(prep_data$data)` fallback. Pre-existing. Verified by execution (coordinator, Reader B).

**F27. `test_catdriver.R` changes.** The deleted test "extract_odds_ratios uses mapping not substring parsing" tested the deleted deprecated function (legitimate, unmentioned); the comment at `:205-207` says two `prepare_analysis_data` tests were ported to `handle_missing_data`, and only two of three were, so no test now runs the live handler with a mixed drop_row / missing_as_level config (Reader D's probe shows it would pass). The H2b expected code change follows locked decision 3. Verified by reading and execution (Reader D).

**F28. Documentation drift left on the branch.** `CODE_INVENTORY.md` says `00_main.R` is 1,625 lines; it is 1,636 after `04ff7be4`. README.md:67 and four docs still say `source("modules/catdriver/R/00_main.R")` then run, which fails with `could not find function "with_refusal_handler"` on both trees (July H9, Session B's). TECHNIQUE_GUIDE's new lift paragraph promises an `outcome_level` column the deliverables lack (F8). Verified by `wc -l` and execution (coordinator, Reader B).

**F29. Two small honesty gaps in the weight path.** A weight column stored as numeric text (" 0.95") is parsed and applied correctly, but `diagnostics$warnings` still says "Weight variable is not numeric. Proceeding unweighted." (Reader A, `inspect_br_binary_numtext.log`). A refused subgroup reaches Run_Status as code only ("Subgroup '61+' failed: MAPPER_DRIVER_LEVEL_MISMATCH"); the new group-label fix text is console only (Reader B). Verified by execution.

**F30. The shared stats-pack writer emits em dashes into client-facing Declaration text** ("44 excluded [em dash] see Data_Used sheet"), and its "see Data_Used sheet for detail" points at a sheet reading "No per-item statistics available." Shared file, outside the diff, CLAUDE.md wording rule. Verified by execution (coordinator, Reader B).

### OBSERVATIONS

**F31. Every ordinary weighted run is now PARTIAL for the rescale alone.** Tolerance 1e-3 at `07_utilities.R:833`; the demo's raw mean 1.2631 (computed after listwise deletion, not the file's 1.2654) exceeds it, with affected outputs "Standard errors, Confidence intervals, P-values". This is the locked decision 4 design and it is stated so Duncan knows a rim-weighted study on mean 1 will not trip it while an expansion-weighted one always will.

**F32. The goldens cannot catch a module regression.** `test_golden_fixtures.R` fits `glm`, `car::Anova`, `clm` and `polr` directly and asserts signs, ranges and the top driver; `golden_expected.rds` is written and read by nothing. The unweighted regression evidence in this review is the main-versus-branch diff in section 3, not the suite.

**F33. C3's fix is invisible to a GUI user today.** `run_catdriver_gui.R:710-711` tests `run_status == "REFUSED"`; the handler returns `"REFUSE"`, so a branch refusal is printed as "complete (status: REFUSE)" and appended to the unified report (Reader B applied those two lines to a branch refusal). July H8, Session B's, but it means the module-wide refusal repair only reaches a user who runs from R until B lands.

### Q4: what the branch broke

Nothing in the unweighted paths. `coord/q4_regression.R` on both trees: unweighted binary and unweighted ordinal give identical coefficients, standard errors, p-values, odds ratios and CIs, importance chi-squares, shares and ranks, McFadden, LR, AIC, probability lifts and factor patterns (max absolute difference 0 in every table), the same sheet lists, and the same status (PASS, PARTIAL). The only differences: the lift frame gains `outcome_level`, and the ordinal run gains the degraded reason "Low events-per-parameter ratio" from the M2 numerator change (113 minority events / 12 = 9.4). Reader C's independent diff (`readerC/scripts/regress.R`) agrees and adds the unweighted multinomial: identical. Weighted binary and ordinal differ from main by exactly the July defects: SE ratio 1.12388 = sqrt(1.2631) and chi-square ratio 0.7917 = 1/1.2631 (H2), ordinal McFadden 0.135 to 0.315 (H1), status PASS to PARTIAL (F31).

## 5. What was not verified

- No Shiny GUI run and no `launch_turas()`; the GUI's own status classification was applied to a result object, not driven live.
- The HTML report path was exercised by the coordinator on three configs (weighted multinomial, weighted binary, weighted ordinal) and by Reader C on one; the unified multi-config report was not generated.
- A genuinely missing `car` package and a genuine `car::Anova` failure were simulated with stubs, not reproduced naturally.
- `CALC_IMPORTANCE_DATA_UNAVAILABLE` was reached only by a direct call; `04b` always returns `estimation_data` through the pipeline.
- Any Order under which the direction guard fires on real data (F11 says there is none for a strict reversal).
- The polr fallback importance inside the pipeline (clm is the default engine and never failed on the fixtures).
- Weighted subgroup comparison numbers against main are not comparable, because main's comparison is NULL.
- Whether the bootstrap caveat text reaches any sheet other than Run_Status.
- The author's suite numbers (919 and 1,330 expectations) were not reproduced exactly; mine are 921 and 1,353, both 0 failed.
- Readers A, B and C were cut by an account rate limit before writing their reports and replied from their transcripts afterwards; every number they report was produced in their session and is on disk under the scratchpad. The coordinator re-ran F1, F2 (the misspelled-name route), F3, F4, F5, F13, F21 and the Q4 regression; F11, F12, F14, F16 and F17 rest on the readers' executions and were checked by reading only.

## 6. Verdict

**PASS WITH FIXES for the merge; BLOCK on two paths until fixed.** 2 CRITICAL, 3 HIGH, 16 MEDIUM, 9 LOW, 3 OBSERVATIONS.

The three July CRITICALs are closed and were re-derived by execution in both directions against implementations written from the definitions: weighted multinomial importance agrees with my own weighted log-likelihood machinery to 4e-4 on every chi-square where main shipped -212 to -242 and 0 per cent for every driver; the subgroup comparison builds and its cells match an independently assembled table; a broken config reaches the user as a named refusal with its fix text where main said "report this to the Turas development team". H1, H2 and H5 are closed the same way, and the unweighted paths are numerically identical to main.

The two CRITICALs are wrong client-facing numbers on paths the July review did not reach, and both should be treated as blocking those paths, not the merge: a multinomial subgroup comparison overwrites outcome levels into one unlabelled row (F3), and every ordinal report's probability-lift table is each respondent's probability of their own observed category, which main also shipped, but the branch has now labelled and explained as a lift (F4). Until F3 is fixed, no multinomial subgroup comparison should go to a client; until F4 is fixed, ordinal reports should be run with `probability_lifts = FALSE`.

The three HIGHs are provenance defects in the session's own subject: an ordinal importance stamp that names the wrong statistic (F1), a weight variable that does not exist or cannot be read running unweighted under PASS with a Declaration that says weighted (F2), and a Declaration whose two respondent counts are swapped (F5). None needs a design decision; each is a few lines. The MEDIUMs are mostly one pattern: the branch put the right words into channels (guard warnings, `proportional_odds`, `method`, `outcome_level`, the stats-pack event `problem`) that no sheet reads.

Recommended order before Duncan's `launch_turas()` eyeball: F1, F2, F5, F6 (an afternoon, all with tests that fail on the current branch), then F3 and F4 with their own tests, then the test gaps F18 to F21 so the next session cannot regress H1 in silence.

## 7. Where the author's notes and this review disagree

Read after sections 1 to 6 were written, as the brief required. `docs/v2_lift/SESSION_A_NOTES_CATDRIVER.md`.

- **"Every fix was watched failing on the code before it."** True of the author's manual runs; not true of the tests that shipped. Reverting H1's three null refits and M1's resample rule leaves the whole suite green (F18, F19), and C1's headline test passes with the reduced models refitted unweighted (F20). The notes' own C1 evidence (chi-squares of -250.3 and -258.7 on the session fixture) is what the test should pin and does not.
- **The `car::Anova` comment.** The notes do not mention it, but `05_importance.R` says the LR claim was "verified by running it against a manual deviance difference". It was, for glm. For clm it is a Wald statistic (F1). The stats pack stamp is wrong on every ordinal run.
- **Deviation 6 (missing weight set to 1 before normalisation, "a semantic choice, not a bug").** At the extreme it is a bug: a character or all-NA weight column becomes a vector of ones, the fit is unweighted, and the stamp says weighted with effective n equal to n (F2). The counts are reported, as the notes say; the word "unweighted" is not.
- **Deviation 14 (H4 checked against a working ordinal project) and the H3 fix.** Both hold. What the notes do not say is that the guard H3 repairs cannot fire on a reversed Order, because it compares against the level the model itself calls highest (F11). H3 and H4 together still leave a present-but-wrong Order with no automated protection.
- **Deviation 17 (two dead-twin tests retargeted).** Two of three; the mixed-strategy test was deleted, not ported, and the comment in `test_catdriver.R:205-207` says otherwise (F27).
- **Deviation 18 (`n_excluded` is original minus analysed).** The count is right and the labels around it are swapped (F5): the Declaration now says 456 received and 500 analysed.
- **Deviation 20 (em dashes became en dashes).** In the module's strings, yes. The shared stats-pack writer still prints em dashes into the Declaration and the branch's own quoted Declaration lines carry them (F30).
- **"The EPP change flips three of the demo's subgroups into a low-EPP stability flag. That is the gate working."** The numerator is now events, which is the fix. The denominator is still the single-equation slope count, so the multinomial gate is roughly (K-1)-fold optimistic (F12), and the message with the numbers never leaves the guard (F10).
- **"M4 probability lift relabelled for what it is"** (the tracker row). For binary and multinomial, yes. For ordinal the quantity is each respondent's probability of their own observed category, and the new label and callout describe it as a lift it is not (F4).
- **"What a reviewer should look at hardest": the refusal-through-`tryCatch` pattern in `05_importance.R`.** Agreed, and it is right there. The same pattern is still wrong at the mapper call and the bootstrap call in `00_main.R` (F23).
- **Deviation 9 (H7 already fixed on main).** Not verified by this review; Session B should check as the notes say.
- **The pipeline test's discrimination check.** Confirmed: reverting the column contract fails the pipeline test and four schema tests (Reader D's C2 row).
- **Suite numbers.** The notes say 919 and 1,330 expectations; this review measured 921 and 1,353, 0 failed both times. The difference is not a disagreement about the code.
- **The dead JS pair (deviation 16).** Agreed that it stays until Session B fixes the startup guard's file list; it is not held against this session.

Nothing in the notes changes a severity above. The notes are candid about what was not run, and the one claim this review contradicts outright is the blanket "watched failing", which held for the author's probes and not for the suite.
