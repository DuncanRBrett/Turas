# Phase 3 Re-Review: KeyDriver + CatDriver

**Reviewed:** 2026-04-06
**Reviewer:** Independent session (did not write the Phase 3 fixes)
**Commit reviewed:** `fb3d78b` on branch `polish/phase-3`
**Scope:** All 9 production files changed in the Phase 3 fix commit
**Method:** Read every line of the diff, then read full file context for each changed file. Audited all Excel write paths across both modules. Verified statistical formulas empirically. Checked test coverage of new code.

**Verdict:** CONDITIONAL PASS — 2 critical, 5 important, 3 minor findings

---

## Summary

The Phase 3 fixes are directionally correct. The callout fallback (C1/C2), stats pack enrichment (C4), GUI console visibility (I2/I3), golden fixtures (I5), and bootstrap documentation (I6) are all well-implemented. The statistical formulas (Kish eff_n, DEFF, nobs for listwise count) are verified correct.

However, the formula injection fix (C3) has significant coverage gaps. It only escapes the importance data frames in each module's main output entry point, leaving 35+ other Excel write paths with user-sourced text unescaped. More critically, there are zero automated tests for any of the escape logic. These gaps need to be addressed before the branch can be considered production-hardened.

---

## Critical Findings

### R1. Formula injection escaping covers < 10% of user-sourced Excel write paths

**Severity:** CRITICAL
**Files:** `keydriver/R/04_output.R`, `catdriver/R/06_output.R`, plus 6 additional output files

The C3 fix adds `escape_text()` to the importance data frame columns in each module's main output function. However, a full audit of all `writeData()` calls across both modules reveals **79 total writeData calls**, of which approximately **35 receive user-sourced text** that could contain formula injection payloads. The fix only covers 7 columns across 2 data frames.

**Unescaped user-sourced text reaches Excel in:**

KeyDriver (19 paths):
- VIF Diagnostics sheet: driver names from `names(vif_vals)`
- Correlations sheet: driver names as row/column names
- Run_Status sheet: `config$outcome_var`, degraded reasons
- README sheet: `config$outcome_var`, `config$weight_var`
- Elastic_Net sheet: `Driver` column
- NCA sheet: `Driver` column (2 tables)
- Dominance sheet: `Driver` column
- GAM sheet: `Driver` column
- Quadrant sheets (3): driver names, segment names
- SHAP sheets (3): driver names, interaction pairs

CatDriver (16 paths):
- Executive Summary: `config$analysis_name`, `config$outcome_label`, category names, driver labels
- Factor Patterns: `pattern_df$category` (survey response categories), `patterns$label`
- Odds Ratios: `factor_label`, `comparison`, `reference` (factor level names)
- Diagnostics: `Variable`, `Label` columns
- Subgroup sheets (3): `subgroup_var`, group names, driver/label/level columns
- Run_Status: degraded reasons, affected outputs

The most dangerous vectors are **category names** (catdriver Factor Patterns, Odds Ratios) and **driver variable names** (both modules, every sheet), because these come directly from survey data or config files that end users control.

**Recommendation:** This is too large to fix as a patch — defer to a dedicated horizontal pass that applies `escape_text()` to all user-sourced text before any `writeData()` call, across all 12 modules. The architectural fix would be to wrap `openxlsx::writeData()` in a Turas-level function that auto-escapes character columns.

### R2. Zero test coverage for formula injection escaping

**Severity:** CRITICAL
**Files:** Absence across all test directories

There are no automated tests that verify:
- The `escape_text` inline fallback produces correct output
- Formula injection characters (`=`, `+`, `-`, `@`, `\t`, `\r`) are escaped before writing to Excel
- The fallback is exercised when `turas_excel_escape` is not available
- Category names, odds ratio labels, or factor patterns are escaped (they aren't, per R1)

The shared `turas_excel_escape.R` also has no dedicated test file. The C3 fix introduced security-critical code with no regression safety net.

**Recommendation:** Add a test file for `turas_excel_escape` in `modules/shared/tests/` that covers all OWASP CSV injection vectors. Add module-level tests that verify escaped output in Excel workbooks.

---

## Important Findings

### R3. escape_text inline fallback regex is inconsistent with shared function

**Severity:** IMPORTANT
**Files:** `keydriver/R/04_output.R:71`, `catdriver/R/06_output.R:81`

The inline fallback regex is:
```r
gsub("^([\t\r=+\\-@])", "'\\1", x)
```

The shared `turas_excel_escape()` function in `modules/shared/lib/turas_excel_escape.R` defines its dangerous prefix list as `c("=", "+", "-", "@", "\t", "\r", "\n")` — **including `\n`**. The inline fallback omits `\n` from its character class.

A cell containing `\n=cmd|'/C calc'!A0` (newline followed by injection payload) would pass through the inline fallback unescaped. Additionally, the `^` anchor only matches the start of each string, not the start of each line within a multi-line string (R's `gsub` is not in multiline mode by default), so embedded-newline attacks bypass the regex entirely.

**Recommendation:** Add `\n` to the inline fallback character class. For multi-line defense, either use `perl = TRUE` with `(?m)` flag, or replace embedded newlines before the prefix check.

### R4. CatDriver stats pack hardcodes n_excluded = 0L

**Severity:** IMPORTANT
**File:** `catdriver/R/00_main.R` (in `generate_catdriver_stats_pack()`)

The C4 fix correctly computes `n_excluded` for KeyDriver using `nobs(result$model)`. However, the CatDriver stats pack still hardcodes `n_excluded = 0L`. CatDriver's validation function (`02_validation.R:602`) already computes `n_excluded <- n_original - n_complete` and passes it through `result$diagnostics`, so the correct value is available — it's just not used.

This wasn't in the C4 fix scope (which targeted KeyDriver only), but it's the same bug pattern. An auditor reviewing CatDriver's stats pack would see zero exclusions regardless of actual listwise deletion.

**Recommendation:** Replace the hardcoded `0L` with `result$diagnostics$n_excluded %||% 0L` in a future pass. Not blocking for this branch since it's a pre-existing issue, not a regression.

### R5. Two competing catdriver_refuse() definitions with incompatible signatures

**Severity:** IMPORTANT
**Files:** `catdriver/R/08_guard.R:53`, `catdriver/R/00_guard.R:42`

The I4 fix improved the 08_guard.R header to clarify that it provides "TRS Refusal Wrappers" while 00_guard.R provides "Validation Gates." The documentation is accurate. However, both files define `catdriver_refuse()` with **incompatible signatures**:

- `08_guard.R`: `catdriver_refuse(reason, message, title, problem, ...)`
- `00_guard.R`: `catdriver_refuse(code, title, problem, why_it_matters, how_to_fix, ...)`

Which definition wins depends on source order. In `run_catdriver_gui.R`, 08_guard.R is sourced before 00_guard.R (line 585 vs 587), so 00_guard.R's version overwrites. Currently all callers use the new-style signature, so this works. But it's fragile — if source order changes or anyone calls the legacy interface, failures would be silent (wrong parameter mapping).

**Recommendation:** Remove the legacy definition from 08_guard.R in a cleanup pass, or alias it to the new signature.

### R6. golden_expected.rds is dead code

**Severity:** IMPORTANT
**Files:** `catdriver/tests/fixtures/golden_expected.rds`, `catdriver/tests/fixtures/golden_data_generator.R`

The I5 fix generated golden fixture files including `golden_expected.rds`. However, no test file loads or references this file. It contains hardcoded numeric values (intercept, odds ratios, chi-square values) that are sensitive to R version and package version changes, but since no test reads it, the values are inert.

The golden fixture tests that DO run (`test_golden_fixtures.R`) are well-designed — they check structural/directional properties (top driver rank, OR > 1, convergence) rather than exact numeric values, which is the correct approach for cross-platform stability.

**Recommendation:** Either write tests that use `golden_expected.rds`, or remove it to avoid confusion. If removed, update `golden_data_generator.R` to not generate it.

---

## Minor Findings

### R7. early_refuse() pattern inconsistency between modules

**Severity:** MINOR
**Files:** `keydriver/run_keydriver_gui.R:15`, `catdriver/run_catdriver_gui.R:23`

KeyDriver defines a reusable `early_refuse()` helper; CatDriver uses inline string construction. Both produce identical output and both correctly `cat()` before `stop()`. Worth harmonizing in a future pass.

### R8. turas_callout fallback silently swallows source errors

**Severity:** MINOR
**Files:** `keydriver/lib/html_report/03_page_builder.R:26-29`, `catdriver/lib/html_report/03_page_builder.R:26-29`

The `tryCatch(source(...), error = function(e) NULL)` around the callout registry sourcing discards all errors. If the registry partially loads but fails before defining `turas_callout`, the no-op stub masks the failure with no diagnostic output. Reports would be generated with empty callout sections and no indication that the real implementation was supposed to be available.

**Recommendation:** Change `error = function(e) NULL` to emit at least a `message()` with the error, so it appears in console logs.

### R9. Shapley vs Dominance: inconsistent over-k degradation strategy

**Severity:** MINOR
**Files:** `keydriver/R/03_analysis.R:336-355`, `keydriver/R/11_dominance.R:79`

Both use 2^k enumeration with k capped at 15. However, Shapley refuses outright with a TRS refusal (`FEATURE_SHAPLEY_TOO_MANY_DRIVERS`), while Dominance silently truncates to the top 15 drivers by correlation magnitude. The behavioral inconsistency could surprise users — one method fails, the other quietly drops drivers.

**Recommendation:** Document the different behaviors in the module README. Consider aligning on one strategy (preferably graceful degradation with a warning, since Shapley refusing while other methods succeed is confusing).

---

## Verified Correct (Probe List Items)

These items from the handover probe list were independently verified and found to be correctly implemented:

| Probe | Verdict | Notes |
|-------|---------|-------|
| C1/C2 `<<-` scoping | **CORRECT** | `<<-` inside `local()` correctly assigns to global env. Guard prevents overwriting a successfully-loaded real function. |
| C1/C2 masking risk | **LOW RISK** | Only triggers if `turas_callout` was never defined. Real function always wins. See R8 for edge case. |
| C4 `nobs(result$model)` | **CORRECT** | Returns complete cases used by `lm()`, correctly reflecting listwise deletion. `result$model` is always a valid `lm` object at stats pack time. |
| C4 eff_n formula | **CORRECT** | Standard Kish formula: `(sum(w))^2 / sum(w^2)`. Verified with equal and skewed weights. |
| C4 DEFF formula | **CORRECT** | Standard `n / n_eff`. |
| C4 data_receipt vs data_used | **CORRECT** | Receipt = input rows, Used = model rows, n_excluded bridges them. |
| Bootstrap PPS | **CORRECT** | Weights applied at resampling only. Per-iteration `lm()` is unweighted. Documentation matches code. No double-weighting. |
| Shapley 2^k bound | **BOUNDED** | Hard cap at k=15 (TRS refusal). 2^15 = 32,768 subsets — feasible. |
| Golden fixture stability | **GOOD DESIGN** | Tests check structural properties, not numeric values. Robust to platform/version drift. |
| I2/I3 cat() + stop() | **CORRECT** | Both modules correctly `cat()` before `stop()` with `call. = FALSE`. |

---

## Disposition

| Finding | Severity | Action | When |
|---------|----------|--------|------|
| R1 | CRITICAL | Horizontal escape pass across all Excel output | Phase 10 (too large for this branch) |
| R2 | CRITICAL | Add tests for turas_excel_escape + module escape paths | Before merge to main |
| R3 | IMPORTANT | Add `\n` to inline fallback, consider multiline defense | With R2 |
| R4 | IMPORTANT | Fix catdriver n_excluded (pre-existing, not a regression) | Phase 10 |
| R5 | IMPORTANT | Remove legacy catdriver_refuse() definition | Phase 10 cleanup |
| R6 | IMPORTANT | Remove dead golden_expected.rds or write tests for it | Phase 10 cleanup |
| R7 | MINOR | Harmonize early_refuse() pattern | Phase 10 |
| R8 | MINOR | Add message() to callout tryCatch error handler | Phase 10 |
| R9 | MINOR | Document Shapley vs Dominance degradation difference | Phase 10 |

**Merge recommendation:** R2 and R3 should be addressed before merging `polish/phase-3` to main. R1 is too large for this branch but must be tracked for Phase 10. All other findings can be deferred.
