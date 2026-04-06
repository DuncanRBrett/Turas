# Phase 5 Re-Review: Pricing

**Reviewed:** 2026-04-07
**Reviewer:** Independent session (did not write the Phase 5 fixes)
**Commit reviewed:** `8c93405` on branch `polish/phase-5`
**Scope:** All 7 production files changed in the Phase 5 fix commit
**Method:** Read every line of the diff, then read full file context for each changed file. Audited every `writeData()` call in `06_output.R` individually. Verified escape function implementation against Phase 3 re-review R3 requirements. Checked stats pack writer compatibility. Grepped for downstream breakage from column rename. Verified test coverage of new code. Ran full test suite.

**Verdict:** PASS — 1 important finding, 1 minor

---

## Summary

The Phase 5 fixes are well-executed across the board. The formula injection protection (C1) is the most thorough implementation in the codebase to date — 44 writeData paths escaped (more than the claimed 34), vapply+substr with `\n` coverage, column-name escaping, and every remaining unescaped writeData call writes only hardcoded string literals. The callout fallback (C2) correctly uses `message()` on error (not silent — addressing Phase 3 re-review R8). The start_time fix (C3) is correctly placed before all analysis. The stats pack expansion (I2) is comprehensive and writer-compatible. The GUI/template cat() fixes (I1, I5), write.csv encoding (I3), and column rename (I4) are all clean with no downstream breakage.

The recurring gap is test coverage: zero new tests were added for any fix, including the security-critical escape functions. This is the third consecutive phase with this pattern (Phase 3 R2, Phase 4 R2). However, unlike Phase 4 where a functional bug was found (R1: convergence flag dead code), no functional bugs were found in the Phase 5 fixes. All code paths are correct as implemented.

---

## Important Findings

### R1. Zero test coverage for all new code

**Severity:** IMPORTANT
**Files:** Absence across all test directories

No automated tests were added for any of the Phase 5 fixes. `git diff 8c93405^..8c93405 --stat -- modules/pricing/tests/` returns empty — zero test files were changed.

Specifically untested:

- `pricing_escape_cell()` / `pricing_escape_df()` — security-critical formula injection protection. No test verifies that an injection payload (`=cmd|'/C calc'!A0`) is prefixed with a single quote.
- Expanded stats pack assumptions — no test verifies the method-specific results, weight diagnostics, or expanded config echo fields render correctly through the writer.
- `turas_callout_text` no-op fallback — no test verifies the NULL return value is compatible with the usage sites at lines 1801-1803.
- `weighted_n` column rename — no test asserts the new column name exists in `calculate_demand_curve()` output.

This is the same pattern flagged in Phase 3 re-review R2 and Phase 4 re-review R2. Three consecutive phases have introduced security-critical escape logic with zero test coverage.

**Recommendation:** Before merge to main, add at minimum:
1. A test for `pricing_escape_cell()` with injection payloads (`=`, `+`, `-`, `@`, `\t`, `\r`, `\n` prefixes) confirming the quote prefix is applied.
2. A test for `pricing_escape_df()` confirming both column values and column names are escaped.
3. A test for `calculate_demand_curve()` asserting `weighted_n` (not `effective_n`) is in the output column names.

---

## Minor Findings

### R2. Fix description claims 34 writeData paths but actual count is 44

**Severity:** MINOR
**File:** `reviews/phase_5_pricing.md` fix status table

The fix status table says:

> Applied to all 34 data frame and scalar string writeData paths in `06_output.R`

An exhaustive audit of the diff counts 44 writeData calls that were modified to use `pricing_escape_df()` or `pricing_escape_cell()`. The coverage is better than claimed. The 10-path discrepancy appears to be a counting error in the fix description — possibly counting unique data frames rather than total writeData call sites.

**Recommendation:** Update the review document to reflect the actual count (44 paths). Not blocking.

---

## Verified Correct (Probe List Items)

These items were independently verified and found to be correctly implemented:

| Probe | Verdict | Notes |
|-------|---------|-------|
| C1 all writeData paths covered | **CORRECT** | 44 writeData calls escaped. All remaining unescaped calls write hardcoded string literals only ("REVENUE VS PROFIT COMPARISON", "EXCLUSION BREAKDOWN", etc.). Zero user-sourced text reaches Excel unescaped. |
| C1 escape includes `\n` | **CORRECT** | Dangerous prefix list: `c("=", "+", "-", "@", "\t", "\r", "\n")`. All 7 characters from shared `.EXCEL_FORMULA_PREFIXES`. |
| C1 vapply+substr not regex | **CORRECT** | Uses `substr(val, 1, 1)` + `%in%` check. No `gsub()`, no regex. Matches Phase 3 re-review R3 requirement. |
| C1 column names escaped | **CORRECT** | `pricing_escape_df()` escapes `names(df)` before column values. Same pattern as Phase 4 segment. |
| C1 shared function priority | **CORRECT** | `if (exists("turas_excel_escape", mode = "function"))` delegates to shared function when available; inline fallback only when shared is missing. |
| C2 tryCatch + message() | **CORRECT** | `error = function(e) message(sprintf("[PRICING] Callout registry load failed: %s", e$message))`. NOT silent — addresses Phase 3 re-review R8 lesson. |
| C2 turas_callout no-op | **CORRECT** | Returns `""` (empty string). Compatible with HTML insertion sites. |
| C2 turas_callout_text no-op | **CORRECT** | Returns `NULL`. Usage sites at lines 1801-1803 wrap calls in `tryCatch(..., error = function(e) NULL)` — NULL return is compatible. |
| C2 `<<-` scoping | **CORRECT** | `<<-` inside `local()` assigns to global env. Guard prevents overwriting a successfully-loaded real function. |
| C3 start_time placement | **CORRECT** | `start_time <- Sys.time()` at line 168, immediately after function entry (line 166). Before TRS init (line 174), config validation, data load, and all analysis steps. |
| C3 start_time passed through | **CORRECT** | `start_time = start_time` at line 579 (was `start_time = Sys.time()`). Stats pack now measures full pipeline duration. |
| I1 GUI cat() before stop() | **CORRECT** | `cat(msg)` at line 39, `stop(msg, call. = FALSE)` at line 40. Formatted box visible in Shiny console. |
| I2 stats pack writer compatibility | **CORRECT** | Writer's `sp_write_assumptions_sheet()` takes arbitrary-length named list, flattens with `vapply(x, paste(as.character(x), collapse = "; "))`. No schema requirement. Expanded assumptions (method results + weight info + base) render correctly. |
| I2 method-specific results | **CORRECT** | VW price points (PMC/OPP/IDP/PME), GG optimal price + revenue index, Mon model fit (pseudo-R2, AIC, price_coef_p) all included. Per-method sample sizes included. |
| I2 weight diagnostics | **CORRECT** | Effective N, weight range, weight mean+SD from `validation$weight_summary`. "No" when unweighted. |
| I2 bootstrap parameters | **CORRECT** | Iterations and confidence level from VW config; iterations and success rate from monadic CI. |
| I2 config echo expanded | **CORRECT** | Uses `intersect(names(config), ...)` for safe subsetting. Includes VW column mappings, GG data format + price sequence length, Mon model type + intent type, segment column, weight_var, unit_cost. |
| I3 write.csv encoding | **CORRECT** | `fileEncoding = "UTF-8"` added to all 4 `write.csv()` calls at lines 1024, 1029, 1038, 1043. |
| I4 weighted_n no breakage | **CORRECT** | Grepped all pricing test files. `effective_n` appears only in WTP distribution tests (testing `07_wtp_distribution.R`, a different function). GG demand curve test (`test_gabor_granger.R:123-146`) does not assert column names — checks `result$purchase_intent` only. No breakage. |
| I5 template generator | **CORRECT** | `cat("\n", msg, "\n")` before `stop(msg, call. = FALSE)` with `[PRICING]` prefix. |

---

## Test Suite Results

| Gate | Command | Result |
|------|---------|--------|
| Tests | `testthat::test_dir("modules/pricing/tests/testthat", reporter = "summary")` | PASS — 0 failures, 0 errors, 63 warnings (all pre-existing: VW bootstrap consistency + visualization edge case) |

---

## Disposition

| Finding | Severity | Action | When |
|---------|----------|--------|------|
| R1 | IMPORTANT | Add tests for escape functions and weighted_n column name | Before merge to main |
| R2 | MINOR | Update review document path count (34 → 44) | Anytime |

**Merge recommendation:** R1 should be addressed before merging `polish/phase-5` to main. The escape logic is security-critical and has been shipped without tests for three consecutive phases. At minimum, add a test that passes an injection payload through `pricing_escape_cell()` and confirms the quote prefix. R2 is cosmetic.

The functional quality of the Phase 5 fixes is high — no bugs found, all code paths verified correct, all probe list items pass. The only gap is the test coverage pattern that has been flagged consistently since Phase 3.
