# Phase 4 Re-Review Round 2: Segment

**Reviewed:** 2026-04-06
**Reviewer:** Independent session (did not write the R1-R6 fixes)
**Commit reviewed:** `32a0c42` on branch `polish/phase-4`
**Scope:** All 6 files changed in the re-review fix commit (diff `e14f974...polish/phase-4`)
**Method:** Read every line of the diff, then read full file context for each changed file. Traced convergence-warning and degenerate-flag propagation through dispatcher, guard, stats pack, and HTML report paths. Verified DB index NA handling in all downstream consumers. Verified test file path resolution for golden fixtures. Ran full test suite.

**Verdict:** PASS — 0 critical, 1 important, 2 minor findings

---

## Summary

All 6 findings from the first re-review are correctly addressed. The k-means convergence fix (R1) is on the right code path and at the right nesting level. The new test file (R2) covers the most important items — formula escape with OWASP vectors and epsilon-squared range validation. The golden fixture tests (R3) consume the previously-dead RDS files with structural assertions. The GMM degenerate flag (R4) now propagates through to the guard layer. The DB index (R5) returns NA instead of an underestimate, and all downstream consumers handle NA correctly. The review document (R6) is corrected.

The one important gap is that the test file header claims coverage of "convergence flag, chi-square low expected" but contains no tests for either. Additionally, the DB index degenerate-case NA behavior (the actual R5 fix) is not tested — the DB test only exercises the non-degenerate path. These are not blocking.

---

## R1. K-means convergence flag — VERIFIED CORRECT

**Files:** `03_clustering.R:172-180`, `00b_guards_soft.R:327-331`

Both bugs identified in the first re-review are fixed:

**Bug 1 (wrong code path):** The `ifault` check is now in `run_kmeans_dispatch()` at `03_clustering.R:172-180`, which is the primary path called by `run_clustering() -> run_kmeans_dispatch() -> kmeans()`. The check fires for both the standard and mini-batch paths because it sits after the if/else block. Traced: `run_minibatch_kmeans()` returns `ifault = if (converged) 0L else 1L` at `03a_kmeans.R:156`, so the check covers both algorithms.

**Bug 2 (wrong nesting level):** `convergence_warning = conv_warn` is set at the top level of the returned list at `03_clustering.R:188`, not nested inside `model`. The guard at `00b_guards_soft.R:327` checks `cluster_result$convergence_warning` — field names match.

**Note:** The legacy `run_kmeans_single()` at `03a_kmeans.R:347` still sets `convergence_warning` on the raw kmeans object, and `run_kmeans_final()` wraps this as `list(model = model, ...)`, so the legacy path still has the nesting bug. However, `run_kmeans_single/final` is not invoked by `run_clustering()` (the primary path), so this is a pre-existing issue outside R1's scope.

---

## R2. Test coverage — SUBSTANTIALLY ADDRESSED

**File:** `tests/testthat/test_phase4_fixes.R` (249 lines, 13 test_that blocks)

The new test file covers the two items the first re-review marked as minimum requirements:

| Item | Tests | Assessment |
|------|-------|------------|
| `seg_escape_cell()` | 4 tests: OWASP injection vectors (`=`, `+`, `-`, `@`, `\t`, `\r`, `\n`), safe passthrough, non-character types, vectorisation | **Comprehensive** |
| `seg_escape_df()` | 3 tests: character column escaping, column name escaping, empty data frame | **Good** |
| Epsilon-squared | 2 tests: range [0,1] with perfect separation, Kruskal-Wallis path verification | **Adequate** (integration-level, not formula-level) |
| Golden fixtures | 3 tests: structural checks on all 3 RDS files with skip_if_not for portability | **Good** |
| DB index guard | 1 test: inline logic replication for non-degenerate case | **Partial** (see S1) |

### S1. Test gaps in claimed coverage

**Severity:** IMPORTANT

The test file header states it covers "convergence flag, chi-square low expected, golden fixtures" but:

1. **No convergence flag test** — no test creates a scenario where `ifault != 0` and verifies the warning propagates through the guard to `guard$warnings` and `guard$stability_flags`.
2. **No chi-square `Low_Expected` test** — the profiling code at `05_profiling.R:559-571` adds a `Low_Expected` flag, but no test verifies it.
3. **No GMM degenerate guard propagation test** — no test verifies the `degenerate_components` field reaches `guard$stability_flags`.
4. **DB index test doesn't test the NA case** — the test data has cluster centers ~0.00014 apart (well above the 1e-10 threshold), so the degenerate guard never fires. The test verifies the non-degenerate case is finite, but the R5 fix (return NA for degenerate case) is unverified.

These are all difficult to test in isolation (they require running the full clustering pipeline or mocking complex objects), so the gap is understandable. The security-critical items (formula escape) and the statistical formula (epsilon-squared) are covered, which was the minimum requirement.

**Recommendation:** Defer to Phase 10. If unit-testable, add a DB index test with two clusters at identical centers (`between_dist = 0`) to verify `NA_real_` is returned.

---

## R3. Golden fixtures — VERIFIED CORRECT

**Files:** `test_phase4_fixes.R:186-249`, `tests/fixtures/golden/`

All 3 golden RDS files (`golden_metrics.rds`, `golden_structure.rds`, `golden_file_list.rds`) are now consumed by tests. The tests use structural/directional assertions (status, k, silhouette range, segment count) rather than exact numeric values — correct for cross-platform stability.

Path resolution: `dirname(dirname(getwd()))` from the testthat working directory resolves to `modules/segment`, then appends `tests/fixtures/golden` — verified correct. Fallback to `TURAS_ROOT` environment variable handles alternative execution contexts. `skip_if_not` ensures graceful degradation if fixtures are missing.

---

## R4. GMM degenerate guard flag — VERIFIED CORRECT

**Files:** `03c_gmm.R:97-106, 160`, `00b_guards_soft.R:333-338`

The fix correctly:
1. Sets `degenerate_warning` string when any component has < 5 members (`03c_gmm.R:100-103`)
2. Emits console warning (`03c_gmm.R:104-105`)
3. Includes `degenerate_components = degenerate_warning` in the returned list (`03c_gmm.R:160`)
4. Guard checks `cluster_result$degenerate_components` and adds to `guard$warnings` + `guard$stability_flags` with "gmm_degenerate" tag (`00b_guards_soft.R:334-337`)

The field name (`degenerate_components`) is consistent between the GMM return value and the guard check.

---

## R5. DB index NA — VERIFIED CORRECT

**Files:** `04_validation.R:383-388`

When `has_degenerate` is TRUE, `db_index` is now set to `NA_real_` instead of `mean(db_scores)` (which would underestimate). Downstream handling verified:

| Consumer | File | Handling | Correct? |
|----------|------|----------|----------|
| Stats pack | `00_main.R:1135` | `is.finite(validation_metrics$davies_bouldin)` — excludes NA | Yes |
| Console | `04_validation.R:392` | `sprintf("%.2f", NA_real_)` produces "NA" in R | Yes |
| HTML exploration | `06_exploration_report.R:257` | `if (!is.na(val)) sprintf(...) else "-"` | Yes |
| Existing tests | `test_validation.R:269` | `expect_true(metrics$davies_bouldin > 0)` — test uses well-separated data, NA never produced | Not triggered |

### S2. Console interpretation text prints when DB is NA

**Severity:** MINOR

At `04_validation.R:392-393`:
```r
cat(sprintf("\nDavies-Bouldin Index: %.2f\n", db_index))
cat("  Lower is better. Good segmentation: < 1.0\n\n")
```

When `db_index` is NA, the output is "Davies-Bouldin Index: NA" followed by "Lower is better. Good segmentation: < 1.0" — the interpretation line is misleading when the value is not available.

**Recommendation:** Wrap the interpretation line in `if (!is.na(db_index))`. Phase 10.

---

## R6. Review document I3 status — VERIFIED CORRECT

**File:** `reviews/phase_4_segment.md`

Changed from `DEFERRED | Requires manual Excel editing; deferred to Phase 10 horizontal pass` to `FIXED | Generator rewritten with 5-column format...`. Accurately reflects the work done in commit `e14f974`.

---

## Additional Finding

### S3. Legacy convergence nesting bug remains on non-primary path

**Severity:** MINOR
**Files:** `03a_kmeans.R:347`, `03a_kmeans.R:496`

`run_kmeans_single()` at line 347 sets `result$convergence_warning` on the raw kmeans object. `run_kmeans_final()` at line 496 wraps this as `list(model = model, ...)`, so the warning ends up at `result$model$convergence_warning`. The guard checks `cluster_result$convergence_warning` (top level) — mismatch.

This is the original Bug 2 from R1 on a non-primary path (`run_kmeans_final` is not called by `run_clustering()`). It was out of scope for R1, which targeted the primary path only.

**Recommendation:** If `run_kmeans_final` is still used anywhere (exploration mode, CLI), propagate `convergence_warning` to the top level of its return list. Phase 10.

---

## Test Results

```
[ FAIL 0 | WARN 1 | SKIP 1 | PASS 978 ]
```

- 1 pre-existing skip: `validate_input_data` non-numeric variance check
- 1 pre-existing warning: NAs introduced by coercion in `validate_input_data`
- No regressions from the R1-R6 fixes

---

## Disposition

| Finding | Severity | Action | When |
|---------|----------|--------|------|
| S1 | IMPORTANT | Add tests for convergence flag, chi-square Low_Expected, GMM degenerate propagation, DB NA case | Phase 10 |
| S2 | MINOR | Guard DB interpretation text with `!is.na()` | Phase 10 |
| S3 | MINOR | Propagate convergence_warning in `run_kmeans_final` return list | Phase 10 |

**Merge recommendation:** PASS. All 6 original findings are correctly addressed. S1 identifies remaining test gaps but the minimum coverage bar (escape functions + epsilon-squared) is met. S2 and S3 are cosmetic/legacy-path issues. No blocking items remain for merging `polish/phase-4` to main.
