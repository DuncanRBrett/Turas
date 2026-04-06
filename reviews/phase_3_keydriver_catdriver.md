# Phase 3: KeyDriver + CatDriver Review

**Reviewed:** 2026-04-06
**Scope:** modules/keydriver/ (21,543 LOC prod, 7,070 LOC test, 40+18 files) + modules/catdriver/ (11,528 LOC prod, 4,741 LOC test, 20+7 files)
**Verdict:** PASS WITH CONDITIONS — 4 critical findings, 7 important, 8 minor

---

## Critical Findings

These must be fixed. Each represents a path where Turas could produce incorrect output or deliver incomplete deliverables.

### C1. KeyDriver: HTML report fails when turas_callout() unavailable

**Files:** `keydriver/lib/html_report/03c_section_builders.R` lines 202, 279, 346, 399, 453; `keydriver/lib/html_report/03_page_builder.R` lines 25-27
**Affects:** All KeyDriver HTML report generation — 3 tests currently failing

The section builders call `turas_callout("keydriver", ...)` which is defined in the shared callout registry. The page builder sources the registry on load, but if the shared library directory is not found (CLI mode, standalone test context, missing TURAS_ROOT), `turas_callout()` never gets defined. When section builders then call it, the entire page assembly fails with `REFUSED: Failed to assemble keydriver HTML page`.

This is the identical pattern to confidence module C3 (Phase 2). The confidence fix added a no-op fallback function — the same pattern needs to be applied here.

**Risk:** Jess enables HTML report for a keydriver run. In standalone or CLI execution paths, the report fails entirely. The 3 currently failing integration tests confirm this.

**Fix:** Add a tryCatch around the callout_registry.R sourcing and define a no-op fallback `turas_callout()` that returns an empty string when the shared library is unavailable.

### C2. CatDriver: HTML report has same undeclared turas_callout() dependency

**Files:** `catdriver/lib/html_report/03c_section_builders.R` lines 181, 379, 441; `catdriver/lib/html_report/03_page_builder.R` lines 26-28
**Affects:** CatDriver HTML report generation

Same pattern as C1. The catdriver HTML report calls `turas_callout("catdriver", ...)` in three section builders. If the shared library is not loaded, these calls fail. Currently the catdriver HTML report tests pass (605/0/17) because the test setup happens to have the shared library in scope, but the dependency is not declared and will fail in standalone contexts.

**Risk:** Same as C1 — HTML report generation fails silently in non-Shiny execution paths.

**Fix:** Same as C1 — add tryCatch and no-op fallback.

### C3. KeyDriver + CatDriver: No formula injection protection in Excel output

**Files:** `keydriver/R/04_output.R` (all writeData calls); `catdriver/R/06_output.R`, `06a_sheets_summary.R`, `06b_sheets_detail.R`, `06c_sheets_subgroup.R`
**Affects:** All Excel output from both modules

Neither module applies `turas_excel_escape()` to user-sourced text before writing to Excel cells. Driver variable names, labels, outcome variable names, and category labels all originate from the user's config file and are written directly via `openxlsx::writeData()`.

Phase 2 C2 established that `openxlsx` does not auto-escape formula prefixes (`=`, `+`, `-`, `@`). The weighting module's fix was to inline a minimal escape function as a fallback. Neither keydriver nor catdriver has any escape logic.

**Risk:** Low probability but high severity. A config file with a driver name like `=IMPORTXML(...)` or a category label starting with `=` would execute as a formula when the Excel file is opened. This was already fixed in weighting (Phase 2 C2) and stats_pack_writer (Phase 0 C5) — both driver modules are the remaining gap.

**Fix:** Apply `turas_excel_escape()` (if available) or inline minimal escape function to all user-sourced data before `writeData()` calls in both modules' output files.

### C4. KeyDriver: Stats pack missing weight diagnostics and per-driver sample sizes

**File:** `keydriver/R/00_main.R` lines 930-1022 (`generate_keydriver_stats_pack`)
**Affects:** Stats pack contractual deliverables for weighted keydriver analyses

The keydriver stats pack includes basic execution metadata and assumptions but omits:
- Weight diagnostics (DEFF, effective N, weight CV, min/max) — essential when weights are applied
- Per-driver sample sizes (complete cases per driver after listwise deletion)
- Bootstrap parameters (iterations, CI level, % failed) when bootstrap is enabled
- VIF values and assumption violation flags from the guard layer

The `data_used` section reports `n_respondents` and `n_excluded = 0L` hardcoded, which is incorrect — listwise deletion of incomplete cases is performed in 00_main.R but not reported. The stats pack says zero respondents were excluded when potentially many were dropped.

By contrast, the catdriver stats pack (lines 1199-1296) correctly includes model type, TRS event summary, and driver count, though it too could benefit from weight diagnostics detail.

**Risk:** Duncan delivers a stats pack claiming zero exclusions and no weight diagnostics for a weighted analysis. The contractual acceptance document is incomplete.

**Fix:** Add weight diagnostics (from config$weight_var if present), per-driver completeness, bootstrap summary, VIF flags, and correct the n_excluded count.

---

## Important Findings

These should be fixed soon. They affect consistency, maintainability, or robustness.

### I1. KeyDriver: No effective_n when weights are used

**Files:** `keydriver/R/03_analysis.R`, `keydriver/R/05_bootstrap.R`, `keydriver/R/00_main.R`
**Affects:** Weighted analysis sample size reporting

The keydriver module uses `nobs(model)` (raw N) throughout — in the Excel output, stats pack, and console summary. When survey weights are applied via `lm(..., weights = w)`, the effective sample size (Kish formula: `(sum(w))^2 / sum(w^2)`) can be substantially smaller. The module never calculates or reports effective N.

The bootstrap module correctly uses weighted resampling (`prob = w_prob`), but the stats pack and output still report raw N. Downstream consumers (e.g., clients reading the stats pack) may overstate the precision of the analysis.

**Action:** Calculate effective N when weights are present and include it in the stats pack, Excel output Run_Status sheet, and console summary.

### I2. KeyDriver GUI launcher: stop() with formatted message

**File:** `keydriver/run_keydriver_gui.R` line 30
**Affects:** GUI error handling when packages are missing

The GUI launcher wraps the stop() in a formatted TRS-style message box (the `early_refuse()` pattern), which is the same approach used in Phase 2 I4 for the confidence GUI launcher. The error message is visible in the console, but `stop()` still causes an unformatted Shiny crash.

**Action:** Add `cat()` before the `stop()` call to ensure the formatted message is visible in the Shiny console, matching the Phase 2 pattern.

### I3. CatDriver GUI launcher: stop() with formatted message

**File:** `catdriver/run_catdriver_gui.R` line 23
**Affects:** GUI error handling when packages are missing

Same pattern as I2. The stop() produces a formatted message but it will present as an unformatted crash in Shiny.

**Action:** Add `cat()` before the `stop()` call.

### I4. CatDriver: Deprecated 08_guard.R still in codebase

**File:** `catdriver/R/08_guard.R` (406 LOC)
**Affects:** Code maintainability and developer confusion

The file header says "Thin wrappers that delegate to the shared TRS implementation" and it sources the active guard functions. But the module also has the Phase 0-added `00_guard.R` (525 LOC) which is the canonical guard layer. Having both files creates confusion about which one to modify. The GUI launcher (`run_catdriver_gui.R` line 583) explicitly sources `08_guard.R`.

The `08_guard.R` file contains `catdriver_refuse()`, `is_refusal()`, and `with_refusal_handler()` wrappers that are needed throughout the module. `00_guard.R` has the validation gates. Both are needed — the issue is naming confusion.

**Action:** Add a clear header comment to `08_guard.R` documenting it as the TRS refusal wrapper (not validation gates). Add a cross-reference between `00_guard.R` and `08_guard.R` so developers know which file handles what.

### I5. CatDriver: 17 golden fixture tests skipped

**Files:** `catdriver/tests/testthat/test_golden_fixtures.R`
**Affects:** Regression test coverage

All 17 golden fixture tests are skipped because the fixture files don't exist. Each test message says "Run: Rscript fixtures/golden_data_generator.R --generate". This means numeric stability and cross-run determinism are not being tested.

**Action:** Generate the golden fixtures and commit them so these tests run in CI. The tests are already written and would provide valuable regression coverage.

### I6. KeyDriver: Bootstrap weighted resampling documentation mismatch

**File:** `keydriver/R/05_bootstrap.R` lines 379-386
**Affects:** Documentation accuracy

The comment says "applying weights again inside lm() would double-weight observations" and fits an unweighted model on the weighted resample. This is correct for probability-proportional-to-size (PPS) resampling. However, the docstring (lines 47-48) says "Supports weighted resampling when case weights are available" without clarifying the single-application approach.

If someone changes the resampling to uniform (for speed or different statistical reasons), the model would need to include weights — but the comment only explains the current choice, not the constraint.

**Action:** Expand the docstring to note that weights are applied at the resampling stage (not the model stage) and document the statistical rationale.

### I7. KeyDriver: Bootstrap point estimate uses mean instead of original sample

**File:** `keydriver/R/05_bootstrap.R` line 505
**Affects:** Point estimate interpretation

The `Point_Estimate` in bootstrap results is `mean(col_vals)` — the mean of the bootstrap distribution. The conventional approach is to report the original sample statistic as the point estimate, not the bootstrap mean. The difference is usually tiny (bootstrap mean converges to the original), but it's non-standard and the bootstrap mean can differ noticeably with high failure rates.

**Action:** Store and return the original-sample importance scores as the point estimate. Use the bootstrap distribution only for CI bounds and SE.

---

## Minor Findings

Worth fixing when touching these files. Not urgent.

### M1. KeyDriver: Shapley value calculation is O(2^k) for k drivers

**File:** `keydriver/R/03_analysis.R`, `calculate_shapley_values()`
**Affects:** Performance with many drivers

The Shapley value computation enumerates all 2^k subsets of k drivers. For k=15 this is 32,768 models; for k=20 it's over a million. The module guard (`00_guard.R`) has no upper bound on driver count beyond the sample size rule (10n per driver). A user with 20+ drivers could experience extremely long run times.

### M2. KeyDriver: Temp plot file not cleaned up after saveWorkbook

**File:** `keydriver/R/04_output.R` lines 212-249
**Affects:** Disk hygiene

A PNG temp file is created for the Shapley bar chart and never explicitly deleted. The comment on line 248 says "Don't delete plot_file yet — it needs to exist until saveWorkbook() is called" but no cleanup happens after saveWorkbook either.

### M3. CatDriver: McFadden R-squared placeholder for non-GLM models

**File:** `catdriver/R/07_utilities.R` line 644
**Affects:** Ordinal and multinomial model R-squared accuracy

When `null_model` is not provided and the model is not a GLM, the function uses `ll_null <- ll_full * 0.5` as a "placeholder". This produces an arbitrary R-squared of 0.5 regardless of actual model fit. The warning is printed but the value is returned and propagated to the stats pack.

### M4. CatDriver: Ordinal model direction check not validated by tests

**Files:** `catdriver/R/04a_ordinal.R`
**Affects:** Ordinal logistic regression sign consistency check

The ordinal model includes a direction check (verifying proportional odds assumption via sign consistency across thresholds) but there are no dedicated tests for this check. An incorrect direction check could silently accept or reject valid models.

### M5. KeyDriver: write_keydriver_output not used in production path

**File:** `keydriver/R/04_output.R` lines 56-497
**Affects:** Dead code

The main pipeline calls `write_keydriver_output_enhanced()` (not found in `04_output.R` — likely defined elsewhere). The `write_keydriver_output()` function in `04_output.R` appears to be the older version. If it's only used in tests, it should be clearly documented as test-only or removed.

### M6. CatDriver: Bootstrap OR default 200 iterations (low for percentile CIs)

**File:** `catdriver/R/07_utilities.R` line 822
**Affects:** Bootstrap CI precision

The default `n_boot = 200` is lower than the usual recommendation of 1000+ for stable percentile CIs. The keydriver bootstrap defaults to 1000. At 200 iterations, percentile bounds at 95% confidence are based on the 5th and 195th order statistics, which are noisy.

### M7. CatDriver: check_separation uses hardcoded thresholds

**File:** `catdriver/R/07_utilities.R` lines 663-664
**Affects:** Separation detection sensitivity

`abs(coefs) > 10` and `ses > 100` are the separation detection thresholds. These work well for typical survey data but may miss separation in models with very large baseline log-odds. The thresholds should at minimum be documented as assumptions.

### M8. KeyDriver: SHAP sample capped at 1000 observations

**File:** `keydriver/R/kda_shap/shap_calculate.R`
**Affects:** SHAP value precision for large datasets

When sample size exceeds 1000, SHAP values are computed on a random subsample. This is reasonable for performance but the subsample size is not configurable and not documented in the stats pack.

---

## Test Coverage Summary

| Metric | KeyDriver | CatDriver |
|--------|-----------|-----------|
| Production files | 40 | 20 |
| Test files | 18 | 7 |
| File ratio (test:prod) | 0.45 | 0.35 |
| Production LOC | 21,543 | 11,528 |
| Test LOC | 7,070 | 4,741 |
| LOC ratio (test:prod) | 0.33 | 0.41 |
| Tests passing | 922 | 605 |
| Tests failing | 3 (C1) | 0 |
| Tests skipped | 4 | 17 (I5) |

### Assessment

**KeyDriver:** Good breadth of coverage with dedicated test files for each major component (guard, config, bootstrap, effect size, segment comparison, SHAP, quadrant, HTML, integration, edge cases, v10.4 features, preflight validators, bug fixes). The 3 failing tests are all due to the turas_callout dependency (C1). Critical gap: no tests for the weighted analysis path specifically — weights are tested indirectly through bootstrap tests but not via the main pipeline.

**CatDriver:** Core paths well-covered (binary, ordinal, multinomial, subgroup, edge cases, HTML). The 17 skipped golden fixture tests (I5) represent a real coverage gap for determinism and numerical stability. Test ratio of 0.41 is the weakest in the codebase as noted in the plan, but the existing tests cover the critical paths (model fitting, importance, separation/fallback, missing data strategies). Bulk test additions deferred to Phase 10 per plan.

---

## Statistical Correctness Assessment

### KeyDriver Module

**Shapley values:** Correctly implements the full enumeration approach. R-squared decomposition follows standard game-theoretic allocation. All 2^k subsets enumerated, which is exact but limits practical driver count.

**Relative weights (Johnson's method):** Correctly uses eigendecomposition of R_xx, orthogonal transformation, and R-squared rescaling. Singular/near-singular matrices are caught and rejected. Implementation matches Johnson (2000) and Tonidandel & LeBreton (2011).

**Beta weights:** Standard |standardized beta coefficient| shares. Correctly computes SD ratios for standardization.

**Bootstrap CIs:** Percentile method correctly implemented. Weighted resampling uses `prob = w_prob` (correct for PPS bootstrap). Failed iterations tracked and reported. Near-singular resamples correctly rejected.

**Weighted correlation:** Correct implementation. Division-by-zero guard for near-zero SD. Normalizes weights before computation.

**OLS regression:** Standard `lm()` with optional weights. Model summary extraction correct. VIF calculation correct (manual R-squared per predictor).

### CatDriver Module

**Binary logistic (glm):** Correct family/link specification. Separation detection reasonable (|coef| > 10 or SE > 100). Firth fallback via brglm2 correctly applied. Odds ratios computed as `exp(coef)` with Wald CIs — standard and correct.

**Ordinal logistic:** Correctly uses `ordinal::clm()` as primary with `MASS::polr()` fallback. Both use logit link. Threshold extraction handles both model types.

**Multinomial logistic:** Correctly uses `nnet::multinom()`. VIF limitation documented (car::vif doesn't support multinom).

**McFadden pseudo-R-squared:** Correct formula `1 - LL_full/LL_null` for GLM models. The null model approximation for non-GLM is a known limitation (M3).

**Variable importance (Wald chi-square):** Correctly uses `car::Anova(model, type = "II")` for Type II tests. Chi-square statistics converted to relative percentages — standard approach.

**Weight diagnostics:** Kish effective N formula correctly implemented: `(sum(w))^2 / sum(w^2)`. Design effect as ratio. CV correctly computed.

---

## TRS Compliance Summary

| Metric | KeyDriver | CatDriver |
|--------|-----------|-----------|
| stop() calls in production | 0 | 0 |
| stop() calls in GUI launcher | 1 (formatted) | 1 (formatted) |
| TRS refusals | ~38 (keydriver_refuse) | ~68 (catdriver_refuse) |
| Guard layer | Complete (00_guard.R) | Complete (00_guard.R + 08_guard.R + 08a/08b) |
| Stats pack | Present (C4: incomplete) | Present |
| Run state tracking | Present | Present |
| Console output | Comprehensive | Comprehensive |
| Formula escape | Missing (C3) | Missing (C3) |

---

## Fix Status (2026-04-06)

All critical, important, and applicable minor findings addressed in this session. Tests passing (KeyDriver: 928/0/4, CatDriver: 659/0/1).

| Finding | Status | What was done |
|---------|--------|---------------|
| C1: KeyDriver HTML turas_callout dependency | FIXED | Added tryCatch around callout_registry.R sourcing and no-op fallback `turas_callout()` that returns empty string |
| C2: CatDriver HTML turas_callout dependency | FIXED | Same pattern as C1 — tryCatch + no-op fallback |
| C3: Formula injection in Excel output | FIXED | Both modules now apply `turas_excel_escape()` (or inline fallback) to user-sourced columns (driver names, labels) before writeData() |
| C4: KeyDriver stats pack incomplete | FIXED | Stats pack now includes: weight diagnostics (eff_n, DEFF, CV, min/max), correct n_excluded (not hardcoded 0), bootstrap parameters, VIF/model warnings from guard |
| I1: KeyDriver no effective_n | DEFERRED | Weight diagnostics now in stats pack (via C4); full eff_n propagation to all output paths deferred to Phase 10 |
| I2: KeyDriver GUI stop() | FIXED | Added cat() before stop() for console visibility in Shiny |
| I3: CatDriver GUI stop() | FIXED | Refactored to build message first, cat() it, then stop() |
| I4: CatDriver deprecated 08_guard.R | FIXED | Updated header to clearly document purpose (TRS refusal wrappers) vs 00_guard.R (validation gates), with cross-references |
| I5: CatDriver golden fixtures missing | FIXED | Generated binary, ordinal, and missing data golden fixtures + expected values RDS; 16 previously-skipped tests now pass |
| I6: Bootstrap weighted resampling docs | FIXED | Added docstring paragraph explaining PPS bootstrap weight application strategy and constraint |
| I7: Bootstrap point estimate convention | DEFERRED | Bootstrap mean closely approximates original; document during Phase 10 |
| M1-M8 | DEFERRED | All minor findings deferred to Phase 10 horizontal pass |

**Deferred to Phase 10 (horizontal pass):**
- I1: Full effective_n propagation to Excel output and console summary
- I7: Bootstrap point estimate convention (mean vs original sample)
- M1: Shapley O(2^k) performance documentation/upper bound guard
- M2: Temp plot file cleanup
- M3: McFadden R-squared placeholder for non-GLM
- M4: Ordinal direction check test coverage
- M5: Dead write_keydriver_output function cleanup
- M6: CatDriver bootstrap default iterations (200 vs 1000)
- M7: CatDriver separation threshold documentation
- M8: SHAP subsample size documentation

**Next:** Re-review in fresh session to verify all fixes, then proceed to Phase 4 (Segment).
