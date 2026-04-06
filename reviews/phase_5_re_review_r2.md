# Phase 5 Re-Review Round 2: Pricing (Broader Scope)

**Reviewed:** 2026-04-07
**Reviewer:** Independent session (did not write the Phase 5 fixes or the narrow re-review)
**Commits reviewed:** `8c93405` (fixes) and `a6d5f58` (re-review R1-R2 tests) on branch `polish/phase-5`
**Scope:** Part 1 — fix verification with focused probes; Part 2 — full audit of 13 production files for issues the original review missed
**Method:** Read all prior reviews independently, then read every production file listed in the task brief. Traced the stats pack payload through the shared writer. Verified test isolation. Audited for silent failure modes, config validation gaps, statistical correctness, and edge cases. Ran the full test suite.

**Verdict:** PASS (Part 1) / 3 important, 6 minor new findings (Part 2)

---

## Test Suite Results

| Gate | Command | Result |
|------|---------|--------|
| Tests | `testthat::test_dir("modules/pricing/tests/testthat", reporter = "summary")` | PASS -- 845 passed, 0 failures, 0 skipped, 63 warnings (all pre-existing) |

---

## Part 1: Fix Verification Probes

### Probe 1: Do the escape tests exercise production code, or replicate in isolation?

**Verdict: Replicated in isolation -- acceptable with caveats.**

`test_escape_and_fixes.R` defines `local_pricing_escape_cell()` and `local_pricing_escape_df()` as local copies of the inline fallback defined inside `write_pricing_output()` at `06_output.R:54-83`. The comment at line 5 is explicit: "we replicate the inline fallback here for direct testing."

This approach is pragmatically necessary because the production functions are closures scoped inside `write_pricing_output()` -- they cannot be imported or called from outside. The tests verify that the **logic** is correct (7 injection prefixes, NA handling, vector behavior, column-name escaping, non-character passthrough, empty data frames). The `weighted_n` test at lines 113-130 **does** exercise the actual production `calculate_demand_curve()` function, so that test is properly integrated.

**Limitation:** If someone modifies the production escape functions without updating the test copies, the tests become stale. This risk is low in practice -- the functions are small and stable -- but it means the tests provide logic assurance, not integration assurance. The alternative would be to define the escape functions at module scope (like `seg_escape_cell()` in segment), which would allow direct import in tests. Not blocking, but worth noting for Phase 10.

### Probe 2: Does the expanded stats pack render correctly through the shared writer?

**Verdict: Correct. Traced end-to-end.**

The payload is constructed at `00_main.R:809-829`. The `assumptions` field is a named list merging base assumptions (method descriptions, TRS status) + `method_results` (VW price points, GG optimal, monadic model fit, bootstrap params) + `weight_info` (effective N, range, mean/SD).

The shared writer's `sp_write_assumptions_sheet()` at `stats_pack_writer.R:445-481` flattens any named list to a 2-column data frame using:

```r
vapply(assumptions, function(x) {
  if (is.null(x) || (length(x) == 1 && is.na(x))) "---"
  else paste(as.character(x), collapse = "; ")
}, character(1))
```

All pricing payload values are scalar character strings produced by `sprintf()` -- no vectors, no NULLs, no nested lists. The writer handles this correctly. The expanded config echo at lines 779-807 uses `intersect(names(config), ...)` for safe subsetting. Confirmed compatible.

---

## Part 2: New Findings (Original Review Gaps)

These are issues found by reading the full production files that were not in the original review's 3 critical + 5 important + 6 minor findings.

### Important Findings

#### N1. VW bootstrap has no success-rate check -- CIs can be based on very few iterations

**Severity:** IMPORTANT
**File:** `pricing/R/03_van_westendorp.R`, lines 745-790
**Affects:** VW confidence interval reliability

The VW bootstrap loop at lines 745-773 silently skips failed `psm_analysis()` calls via `tryCatch({ ... }, error = function(e) { })`. Failed iterations leave `NA` rows in `boot_results`. The CI computation at lines 777-780 uses `quantile(..., na.rm = TRUE)` and `colMeans(..., na.rm = TRUE)`.

Unlike the monadic bootstrap (`13_monadic.R:402`), which checks `if (successful < n_boot * 0.5)` and warns, the VW bootstrap has **no success-rate check**. If 990 of 1000 iterations fail (e.g., degenerate resampled data), the CIs would be computed from 10 iterations with no warning. Worse, if all iterations fail, `quantile()` of all-NA values returns `NaN` with only an R-level warning that may not be visible in Shiny.

The monadic module already has the correct pattern. The VW bootstrap should match it.

**Recommendation:** Add a success-rate counter and warning threshold (50%) matching the monadic pattern. Return `NULL` CIs if insufficient successful iterations, with a console warning.

#### N2. Price ladder produces nonsensical tiers when VW price points are NA or inverted

**Severity:** IMPORTANT
**File:** `pricing/R/11_price_ladder.R`, lines 94-104, 152-189
**Affects:** Price ladder output correctness

VW price points are extracted at lines 94-104 without NA checks:

```r
reference_prices$PMC <- vw_results$price_points$PMC   # Could be NA
reference_prices$OPP <- vw_results$price_points$OPP   # Could be NA
```

The floor/ceiling guard at lines 152-159 uses `!is.null()` but does not check `!is.na()`. NA prices pass through, producing NA step sizes at lines 168/179, which propagate into the entire tier table. The output would be a price ladder with all-NA prices.

Similarly, if PMC > PME (inverted range -- possible with noisy VW data), floor > ceiling, step sizes become negative, and tier prices collapse or reverse without warning.

**Recommendation:** Add `!is.na()` checks alongside `!is.null()` for all reference price points. Add a guard that `PMC <= PME` (or fall back to +/- 40% range if violated).

#### N3. Competitive scenarios share calculation has division-by-zero risk and NA propagation

**Severity:** IMPORTANT
**File:** `pricing/R/08_competitive_scenarios.R`, lines 56, 82-84
**Affects:** Competitive scenario output correctness

The share calculation at line 84:

```r
shares$share <- shares$total_weight / sum(shares$total_weight)
```

If all respondents choose no-purchase (e.g., all WTP < all prices and `allow_no_purchase = TRUE`), `sum(shares$total_weight)` can be 0, producing `NaN` shares. Additionally, if `wtp_df$wtp` or `wtp_df$weight` contains NA values (not checked), these propagate through the surplus calculation at line 56 into the aggregation, potentially producing NA shares.

The function has no input validation on the WTP data frame -- no checks for NA, negative, or zero WTP values.

**Recommendation:** Add a guard for `sum(shares$total_weight) < 1e-10` with a meaningful return value (e.g., 100% no-purchase share with a warning). Validate that `wtp_df$wtp` and `wtp_df$weight` contain no NA values.

---

### Minor Findings

#### N4. WTP distribution uses `effective_n = sum(w)` -- same naming issue as original I4

**Severity:** MINOR
**File:** `pricing/R/07_wtp_distribution.R`, line 251
**Affects:** Output column naming consistency

The original review's I4 finding identified that `effective_n` in the GG demand curve was `sum(weights)`, not the Kish effective N. The fix renamed it to `weighted_n` in GG. However, the WTP distribution module at line 251 has the same pattern:

```r
effective_n = sum(w),
```

This is `sum(weights)`, not `(sum(w))^2 / sum(w^2)`. The column name `effective_n` is equally misleading here. This file was not in scope for the I4 fix (which targeted only `04_gabor_granger.R`), but a test at `test_wtp_distribution.R:274` asserts the column name is `effective_n`, so renaming would require a test update.

**Recommendation:** Rename to `weighted_n` for consistency with the GG fix, and update the test assertion. Defer to Phase 10.

#### N5. Kruskal-Wallis test failure is silent in segment comparison

**Severity:** MINOR
**File:** `pricing/R/10_segmentation.R`, lines 528-532
**Affects:** Diagnostic completeness for segment comparisons

```r
kw_result <- tryCatch({ kruskal.test(df$.metric, factor(df$.segment)) }, error = function(e) NULL)
overall_p <- if (!is.null(kw_result)) kw_result$p.value else NA_real_
```

If the Kruskal-Wallis test fails (e.g., all values identical across segments, or single-value segment), the error is silently discarded. `overall_p` becomes `NA_real_` with no warning or console output. An analyst reviewing the segment comparison output would see a blank p-value with no explanation.

This is a minor diagnostic gap, not a correctness issue -- the pairwise permutation tests proceed independently.

**Recommendation:** Add `message()` in the error handler to log the failure reason.

#### N6. Price ladder `analyze_gaps()` divides by price without zero-guard

**Severity:** MINOR
**File:** `pricing/R/11_price_ladder.R`, line 325
**Affects:** Edge case with very low-price products

```r
gaps[i] <- (prices[i + 1] - prices[i]) / prices[i]
```

If `prices[i] == 0`, this produces `Inf`. While zero-priced tiers are unlikely in practice (the ladder is built from VW price points which are validated as positive), the gap analysis function takes arbitrary price vectors and has no guard.

**Recommendation:** Add `if (prices[i] < 1e-10)` guard, or document that the function assumes positive prices.

#### N7. Config template generator claims different sample sizes than TECHNIQUE_GUIDE

**Severity:** MINOR
**Files:** `pricing/lib/generate_config_templates.R`, `pricing/TECHNIQUE_GUIDE.md`
**Affects:** User guidance consistency

The config template generator's help text states:
- VW: "Minimum 100 respondents (200+ recommended for stable CIs)"
- GG: "Minimum 200 respondents"

The TECHNIQUE_GUIDE states:
- VW: "Minimum 100 respondents"
- GG: "Minimum 30 respondents per price point tested"

These are compatible (200 total / 6 points ~ 33 per point), but the framing differs. A user reading the template help might think GG needs 200 total regardless of price points, while the technique guide correctly frames it per-point.

The code enforces n >= 30 per price point (`00_guard.R` validate_sample_by_price line 306), which aligns with the technique guide.

**Recommendation:** Update the template help text to match the technique guide's per-point framing.

#### N8. Weighted mean helper in segmentation can produce NaN

**Severity:** MINOR
**File:** `pricing/R/10_segmentation.R`, lines 522-525
**Affects:** Segment comparison edge case

```r
wmean <- function(x, w) {
  valid <- !is.na(x) & !is.na(w)
  sum(x[valid] * w[valid]) / sum(w[valid])
}
```

If all weights in a segment are NA, `sum(w[valid])` is 0, producing `NaN`. This NaN would propagate into the `observed_diff` for pairwise permutation tests. The permutation test's p-value would be `mean(abs(perm_diffs) >= abs(NaN))`, which is `NaN`.

An unlikely edge case (requires all weights in a segment to be NA), but the guard is trivial.

**Recommendation:** Add `if (sum(w[valid]) < 1e-10) return(NA_real_)` before the division.

#### N9. `unit_cost` not validated as non-negative

**Severity:** MINOR
**Files:** `pricing/R/01_config.R`, line 770; `pricing/R/00_guard.R` (absent)
**Affects:** Profit calculations with negative unit cost

Config loading coerces `unit_cost` to numeric at line 770 but does not validate it is non-negative. The guard layer (`00_guard.R`) has no check for `unit_cost`. A negative `unit_cost` would produce profit indices where `profit = (price - (-cost)) * intent = (price + cost) * intent`, which would always exceed revenue index and produce misleading profit-optimal prices.

**Recommendation:** Add a guard that `unit_cost >= 0` when it is specified and not NA.

---

## Verified Correct (Spot Checks)

These items were independently verified and found correct:

| Item | Verdict | Notes |
|------|---------|-------|
| Escape tests cover all 7 OWASP prefixes | **CORRECT** | `=`, `+`, `-`, `@`, `\t`, `\r`, `\n` -- all tested in `test_escape_and_fixes.R:38-47` |
| Escape tests verify NA/empty passthrough | **CORRECT** | NA returns NA, empty string returns empty string |
| `weighted_n` test exercises production code | **CORRECT** | Calls actual `calculate_demand_curve()`, not a local copy |
| Stats pack duration uses real start_time | **CORRECT** | `start_time <- Sys.time()` at line 168, passed through at line 579 |
| Stats pack expanded assumptions render | **CORRECT** | Writer flattens named list to 2-column df, all values are scalar character |
| Arc elasticity (GG) midpoint formula | **CORRECT** | Standard midpoint method with three division-by-zero guards |
| Point elasticity (PVO) central difference | **CORRECT** | `dQ/dP ~ [Q(p+d) - Q(p-d)] / (2d)`, bounded to data range |
| Monadic logistic regression | **CORRECT** | `glm(intents ~ prices, family = binomial)`, McFadden's pseudo-R2 = `1 - resid_dev/null_dev` |
| Monadic bootstrap resamples respondents | **CORRECT** | `sample(n, n, replace = TRUE, prob = resample_prob)`, degenerate check before fitting |
| PCHIP monotonicity preservation | **CORRECT** | Fritsch-Carlson: harmonic mean when same sign, zero when sign change |
| PAVA isotonic regression | **CORRECT** | Weighted pooling of adjacent violators, monotone decreasing |
| Confidence scoring algorithm | **REASONABLE** | Proprietary heuristic, not a statistical test. CV thresholds, sample-size bands, and zone-fit scoring are defensible for triangulation |
| Recommendation synthesis | **CORRECT** | Triangulates across available methods, applies psychological rounding with 10% drift guard |
| Callout fallback (C2 fix) | **CORRECT** | `tryCatch` + `message()` on error, no-op stubs for both `turas_callout` and `turas_callout_text` |
| Pipeline tryCatch patterns | **ACCEPTABLE** | Steps 4-6 (segment, ladder, synthesis) catch errors with `message()` + `cat()`. Step failures degrade gracefully to NULL results. Downstream code checks for NULL. |
| Documentation consistency | **GOOD** | TECHNIQUE_GUIDE, AUTHORITATIVE_GUIDE, and QUESTIONNAIRE_DESIGN_GUIDE are internally consistent and methodologically sound. No statistical claims contradicted by the code. |

---

## Statistical Correctness: Items Not Covered by Original Review

The original review verified VW, GG demand/revenue/elasticity, monadic regression, and PAVA. This round additionally checked:

| Formula / Algorithm | File | Verdict |
|---------------------|------|---------|
| Confidence scoring (CV, sample bands, zone fit) | `12_recommendation_synthesis.R:330-467` | **REASONABLE** -- proprietary heuristic, not a statistical test. Thresholds are defensible. NA/Inf guards present. |
| Psychological price rounding | `12_recommendation_synthesis.R:288-319` | **CORRECT** -- 10% drift guard prevents excessive rounding. Division-by-zero guarded (`price == 0` check). |
| Point elasticity via central difference | `09_price_volume_optimisation.R:972-995` | **CORRECT** -- `E(p) = (dQ/dP) * (P/Q)` with `q > 1e-10` guard. |
| Marginal revenue zero-crossing | `09_price_volume_optimisation.R:1004-1018` | **CORRECT** -- linear interpolation between sign-change points. |
| Golden section search | `09_price_volume_optimisation.R:578-614` | **CORRECT** -- standard implementation with phi = `(1 + sqrt(5)) / 2`. |
| Pareto frontier dominance | `09_price_volume_optimisation.R:787-799` | **CORRECT** -- standard weak dominance check: better-or-equal on all objectives, strictly better on at least one. |
| Competitive scenario surplus model | `08_competitive_scenarios.R:56-84` | **CORRECT** (formula) -- `surplus = WTP - price`, max-surplus choice rule. Implementation gaps in N3 (edge cases). |
| Permutation test for segment differences | `10_segmentation.R:551-567` | **CORRECT** -- pool-and-permute with weighted means. Two-sided p-value. Fixed seed for reproducibility. |
| VW bootstrap weighted resampling | `03_van_westendorp.R:720-790` | **CORRECT** (formula) -- probability proportional to normalized weights. Missing success-rate check (N1). |

---

## Disposition

| Finding | Severity | Action | When |
|---------|----------|--------|------|
| N1 | IMPORTANT | Add VW bootstrap success-rate check matching monadic pattern | Phase 10 |
| N2 | IMPORTANT | Add NA/inversion guards to price ladder reference prices | Phase 10 |
| N3 | IMPORTANT | Add division-by-zero guard and NA validation to competitive scenarios | Phase 10 |
| N4 | MINOR | Rename WTP `effective_n` to `weighted_n` for consistency | Phase 10 |
| N5 | MINOR | Add `message()` to Kruskal-Wallis error handler | Phase 10 |
| N6 | MINOR | Add zero-price guard to `analyze_gaps()` | Phase 10 |
| N7 | MINOR | Align config template sample-size text with technique guide | Phase 10 |
| N8 | MINOR | Add zero-weight guard to `wmean()` helper | Phase 10 |
| N9 | MINOR | Add `unit_cost >= 0` validation to guard layer | Phase 10 |

**Merge recommendation:** No new blocking findings. The narrow re-review's R1 (test coverage) was addressed in commit `a6d5f58` with comprehensive escape function tests and a `weighted_n` integration test. The R2 (document count) is cosmetic. All 9 new findings (N1-N9) are pre-existing issues not introduced by the Phase 5 fixes -- they can be deferred to Phase 10.

The Phase 5 fixes are correct, complete, and tested. The branch is ready to merge to main.
