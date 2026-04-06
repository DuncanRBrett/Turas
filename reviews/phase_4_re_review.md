# Phase 4 Re-Review: Segment

**Reviewed:** 2026-04-06
**Reviewer:** Independent session (did not write the Phase 4 fixes)
**Commits reviewed:** `b30abdd` and `e14f974` on branch `polish/phase-4`
**Scope:** All 18 production files changed in the Phase 4 fix commits
**Method:** Read every line of the diff, then read full file context for each changed file. Audited all Excel write paths. Traced convergence-warning propagation through dispatcher chain. Verified stats pack payload against shared writer expectations. Checked test coverage of new code. Ran full test suite.

**Verdict:** CONDITIONAL PASS — 1 critical, 3 important, 2 minor findings

---

## Summary

The Phase 4 fixes are well-executed overall. The formula injection protection (C1) is the strongest implementation seen so far — vapply+substr with \n coverage, column-name escaping, and full coverage of all 8 production writeData paths. The epsilon-squared correction (C2) is mathematically correct. The callout fallback (C3), stats pack enrichment (C4), and DB index guard (C5) are all correctly implemented. The GUI cat() fix (I2) and chi-square expected-frequency flag (I5) are clean. The config template rewrite (claimed as deferred I3 but actually done) brings the module to Tabs standard.

However, the k-means convergence fix (I6) is broken: the convergence_warning field is set on a nested object that the guard never reaches, and the primary code path bypasses the convergence check entirely. The golden fixtures are dead code (no test consumes them). And zero new tests were added for any of the security-critical or statistical-formula changes.

---

## Critical Findings

### R1. K-means convergence flag (I6) is dead code on the primary path

**Severity:** CRITICAL
**Files:** `segment/R/03a_kmeans.R:347`, `segment/R/03_clustering.R:163`, `segment/R/00b_guards_soft.R:327`

The I6 fix has two independent bugs that together render it non-functional:

**Bug 1 — Wrong code path:** The convergence check (`ifault != 0`) is inside `run_kmeans_single()` at `03a_kmeans.R:342`. But the main module flow is:

```
00_main.R:235  →  run_clustering()
                    →  run_kmeans_dispatch()     [03_clustering.R:144]
                        →  kmeans()  directly    [03_clustering.R:163]
```

`run_kmeans_dispatch()` calls `kmeans()` directly and never checks `ifault`. The `run_kmeans_single()` function (which has the check) is only used by `run_kmeans_final()` — a legacy/alternative path not invoked by `run_clustering()`.

**Bug 2 — Wrong nesting level:** Even if `run_kmeans_single()` were reached, it sets `result$convergence_warning` on the raw kmeans object. This object is then wrapped as `list(model = model, ...)`. The guard at `00b_guards_soft.R:327` checks `cluster_result$convergence_warning` (top-level), but the field is at `cluster_result$model$convergence_warning`.

Net effect: the guard's convergence check never fires on any code path.

**Recommendation:** Move the `ifault` check into `run_kmeans_dispatch()` after the `kmeans()` call at line 163-170, and set `convergence_warning` on the returned list (not nested inside `model`). Alternatively, have the guard check `cluster_result$model$convergence_warning`.

---

## Important Findings

### R2. Zero test coverage for all new code

**Severity:** IMPORTANT
**Files:** Absence across all test directories

No automated tests were added for any of the Phase 4 fixes. Specifically untested:

- `seg_escape_cell()` / `seg_escape_df()` — formula escape logic (security-critical)
- Epsilon-squared formula `H / (n - 1)` (C2 — statistical correctness)
- DB index `between_dist < 1e-10` guard (C5)
- GMM degenerate component warning (I7)
- K-means convergence warning (I6 — broken per R1, but also untested)
- Stats pack enrichment fields (C4)
- Chi-square `Low_Expected` flag (I5)

The epsilon-squared formula is trivial to verify with a known-H, known-n pair. The escape logic should have at least one test with an injection payload (`=cmd|...`) confirming the prefix quote is applied. These are the same gaps as Phase 3 re-review R2.

**Recommendation:** Add test coverage for at minimum the escape functions and the epsilon-squared formula before merge.

### R3. Golden fixture files are dead code

**Severity:** IMPORTANT
**Files:** `segment/tests/fixtures/golden/golden_metrics.rds`, `golden_structure.rds`, `golden_file_list.rds`

The I4 fix ran the golden file generator and committed 3 RDS files. However, no test file loads or references these files. A comprehensive grep of all 21 test files under `tests/testthat/` returns zero matches for "golden", "golden_metrics", or any `readRDS` loading from the golden fixtures directory.

This is the identical pattern found in Phase 3 re-review R6 (catdriver `golden_expected.rds`).

**Recommendation:** Either write a `test_golden.R` that loads and asserts against these files, or remove them to avoid confusion. Dead fixture files create a false sense of regression coverage.

### R4. GMM degenerate component detection (I7) warns but does not set guard flag

**Severity:** IMPORTANT
**Files:** `segment/R/03c_gmm.R:100`, `segment/R/00b_guards_soft.R:327-331`

The I7 fix detects GMM components with fewer than 5 members and emits a `cat()` warning to console. However, it does not set any field on the returned result that the guard layer can detect. The guard at `00b_guards_soft.R:327` only checks `cluster_result$convergence_warning` — there is no analogous check for degenerate GMM components.

The original review recommendation was: "Set guard state flag if either threshold is violated." The fix only does the detection and logging, not the guard-flag propagation.

**Recommendation:** Either set a field on the GMM result (e.g., `result$degenerate_components <- small_components`) and add a guard check for it, or document that the console warning is the intended diagnostic mechanism.

---

## Minor Findings

### R5. DB index degenerate guard produces underestimate, not NA

**Severity:** MINOR
**Files:** `segment/R/04_validation.R:364-385`

When two clusters have near-identical centers (`between_dist < 1e-10`), the fix skips the pair. If a cluster has only degenerate pairings, its `max_ratio` remains at the initialized value of 0. This makes `db_scores[i] = 0`, pulling the overall DB index artificially low (i.e., making a degenerate solution look good rather than bad).

The `cat()` warning compensates by alerting the user, and fully degenerate solutions (all clusters identical) are rare in practice. But if the DB index value is consumed programmatically (e.g., in k-selection), an artificially low value could mislead.

**Recommendation:** Consider returning `NA` for the DB index when any degenerate pair is detected, or at minimum note this limitation in the stats pack when the warning fires.

### R6. Review document says I3 DEFERRED but templates were actually rebuilt

**Severity:** MINOR
**Files:** `reviews/phase_4_segment.md` fix status table

The fix status table says:

> | I3: Config templates polish | DEFERRED | Requires manual Excel editing; deferred to Phase 10 horizontal pass |

But commit `e14f974` ("Segment config templates brought to Tabs standard") completely rewrote the template generator with 5-column layout, section headers, Required/Optional markers, Valid Values column, and added 15+ missing fields. The binary templates also changed (16KB → 21KB). The fix was done, not deferred.

**Recommendation:** Update the review document to reflect the actual status.

---

## Verified Correct (Probe List Items)

These items were independently verified and found to be correctly implemented:

| Probe | Verdict | Notes |
|-------|---------|-------|
| C1 formula escape: vapply+substr not regex | **CORRECT** | Inline fallback uses `vapply` + `substr(val, 1, 1)` + `%in%` check. No regex. |
| C1 formula escape: \n included | **CORRECT** | Character list is `c("=", "+", "-", "@", "\t", "\r", "\n")`. Matches shared `.EXCEL_FORMULA_PREFIXES`. |
| C1 all production writeData paths covered | **CORRECT** | All 8 production `writeData()` calls pass through `seg_escape_df()` or `seg_escape_cell()`. 4 test/fixture calls use hardcoded values only. |
| C1 column names escaped | **CORRECT** | `seg_escape_df()` escapes both column values AND `names(df)`. Better than shared `turas_excel_escape_df()` which only escapes values. |
| C1 source order | **CORRECT** | `turas_excel_escape.R` sourced at `00_main.R:42`, `09a_excel_styles.R` at line 76. Binding evaluates correctly. |
| C2 epsilon-squared formula | **CORRECT** | `H / (n - 1)` is the standard formula (Tomczak & Tomczak 2014). Clamped to `[0, 1]`. |
| C3 callout tryCatch + fallback | **CORRECT** | `tryCatch(source(...), error = function(e) message(...))` with no-op fallback after. `<<-` inside `local()` assigns to global env. Matches keydriver/catdriver pattern. |
| C3 callout diagnostic output | **CORRECT** | Error handler uses `message()` with module prefix `[SEGMENT]`. Not silently swallowed (addresses Phase 3 re-review R8 lesson). |
| C4 implementation label | **CORRECT** | `switch()` on `method_used` produces correct label for kmeans/hclust/gmm. |
| C4 per-cluster sizes | **CORRECT** | `table(cluster_result$clusters)` with percentage formatting. |
| C4 validation metrics | **CORRECT** | Includes silhouette, CH, DB (with `is.finite()` guard for DB). |
| C4 stats pack payload vs writer | **ACCEPTABLE** | Writer falls back via `du$questions_analysed %||% dr$questions_in_config` — segment doesn't provide `questions_analysed` but the fallback produces correct output. |
| C4 config echo | **CORRECT** | Uses `intersect(names(config), ...)` for safe subsetting. Includes outlier/varsel/linkage/gmm fields. |
| C5 DB guard | **CORRECT** | `between_dist < 1e-10` check with `next` and warning. Prevents Inf. See R5 for edge case. |
| I1 multiple comparison note | **CORRECT** | Added to docstring and stats pack assumptions. |
| I2 GUI cat() before stop() | **CORRECT** | Formatted box with `cat()` before `stop(msg, call. = FALSE)`. |
| I5 chi-square low expected | **CORRECT** | `suppressWarnings()` around `chisq.test()`, `Low_Expected` flag added to output, console note when significant + low expected. |
| I7 GMM degenerate detection | **PARTIAL** | Detects and logs to console, but doesn't set guard flag. See R4. |
| M9 write.csv encoding | **CORRECT** | `fileEncoding = "UTF-8"` added. |

---

## Disposition

| Finding | Severity | Action | When |
|---------|----------|--------|------|
| R1 | CRITICAL | Fix convergence check on primary code path + correct nesting level | Before merge to main |
| R2 | IMPORTANT | Add tests for escape functions and epsilon-squared formula at minimum | Before merge to main |
| R3 | IMPORTANT | Write tests that consume golden fixtures, or remove the dead files | Phase 10 cleanup |
| R4 | IMPORTANT | Propagate GMM degenerate flag to guard, or document as console-only | Phase 10 |
| R5 | MINOR | Return NA for DB index when degenerate pairs detected | Phase 10 |
| R6 | MINOR | Update review document fix status for I3 | Anytime |

**Merge recommendation:** R1 and R2 should be addressed before merging `polish/phase-4` to main. R1 is a functional bug (the convergence check doesn't work). R2 is the same pattern flagged in Phase 3 re-review R2 — security-critical and statistical code without test coverage. R3 and R4 can be deferred.
