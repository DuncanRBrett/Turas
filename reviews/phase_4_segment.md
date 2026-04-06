# Phase 4: Segment Review

**Reviewed:** 2026-04-06
**Scope:** modules/segment/ (26,303 LOC prod, 6,714 LOC test, 38+21 files)
**Verdict:** PASS WITH CONDITIONS — 5 critical findings, 8 important, 9 minor

---

## Verification Gates

| Gate | Command | Result |
|------|---------|--------|
| Tests | `testthat::test_dir("modules/segment/tests/testthat")` | PASS — 1 skipped, 0 failures |
| Lint | Manual review | No blocking issues |

---

## Critical Findings

These must be fixed. Each represents a path where Turas could produce incorrect output or deliver incomplete deliverables.

### C1. No formula injection protection in any Excel output path

**Files:** `segment/R/09a_excel_styles.R` line 203 (`seg_write_branded_sheet`), `segment/R/09_output.R` line 890, `segment/R/10_utilities.R` line 1558
**Affects:** All Excel output from the segment module

The module sources `turas_excel_escape()` in `00_main.R:42` but never calls it. The central `seg_write_branded_sheet()` function at `09a_excel_styles.R:203` writes data frames directly to Excel via `openxlsx::writeData()` without escaping. This function is used ~10 times to write:

- Segment assignments (custom segment names from config)
- Segment profiles (variable labels from data/config)
- Config echo (user-entered text)
- Labels sheet (question labels)
- Insights sheet (analyst-authored text)
- About sheet (project name, analyst name, description)
- Run_Status sheet (guard messages, degraded reasons)

Additionally, `merge_segment_results()` at `10_utilities.R:1558` writes merged survey data + segment names to Excel, and `add_segment_run_status_sheet()` at `09_output.R:890` writes guard warnings and stability flags.

No inline escape fallback is defined. No calls to `turas_excel_escape()` or `turas_write_data_safe()` exist anywhere in the module.

**Risk:** A config file with a segment name like `=IMPORTXML(...)` or a variable label starting with `=` would execute as a formula when the Excel file is opened. This was fixed in weighting (Phase 2 C2), stats_pack_writer (Phase 0 C5), and keydriver/catdriver (Phase 3 C3).

**Fix:** Define an inline escape fallback using vapply+substr (not regex per Phase 3 re-review R3). Apply to all character columns in `seg_write_branded_sheet()` before the `writeData()` call, and to the other two direct `writeData()` sites.

### C2. Eta-squared formula incorrect for Kruskal-Wallis test

**File:** `segment/R/05a_profiling_stats.R`, line 63
**Affects:** All segment profiling effect sizes for variables with < 10 unique values

The formula applied is:
```r
eta_sq <- (test_result$statistic - k + 1) / (n - k)
```

This formula is derived from the F-statistic in one-way ANOVA (eta_sq = SS_between/SS_total). The Kruskal-Wallis H statistic is a chi-squared approximation, not an F-statistic. The correct epsilon-squared for Kruskal-Wallis is:

```
epsilon_sq = (H - k + 1) / (n - k)    # approximate, only when H >> k
```

However, this approximation is unreliable when H is small relative to k. The standard approach is `epsilon_sq = H / ((n^2 - 1) / (n + 1))` which simplifies to `H / (n - 1)`. The current formula can produce values outside [0, 1] and may be negative when H < (k - 1).

The code clamps at zero with `max(0, eta_sq)` which hides the negative case but still produces inflated values.

**Risk:** Effect sizes reported in segment profiles are systematically wrong for categorical/ordinal variables. Duncan delivers a segment profile claiming "large effect" (eta_sq = 0.35) when the correct value is 0.12. Client prioritises the wrong differentiating variable.

**Fix:** Replace with the standard epsilon-squared formula: `epsilon_sq = H / (n - 1)`. Label the output column as "Epsilon_Sq" (not "Eta_Sq") to be methodologically accurate, or use `effectsize::rank_epsilon_squared()` if available.

### C3. HTML report callout sourcing has no tryCatch or no-op fallback

**File:** `segment/lib/html_report/03_page_builder.R`, line 29
**Affects:** HTML report generation in standalone/CLI contexts

The callout registry sourcing is a bare `source()` call:
```r
if (!exists("turas_callout", mode = "function") && dir.exists(callout_dir)) {
  source(file.path(callout_dir, "callout_registry.R"), local = FALSE)
```

No `tryCatch` wraps the `source()`. No no-op fallback `turas_callout()` is defined if sourcing fails. The usage sites in `03c_section_builders.R` lines 1500-1508 are correctly guarded with `if (exists("turas_callout", mode = "function"))` checks, but the architecture is fragile — a partial source failure or corrupted registry file would cause the entire page assembly to crash.

This is the identical pattern found in confidence (Phase 2 C3), keydriver (Phase 3 C1), and catdriver (Phase 3 C2).

**Risk:** In standalone or CLI execution paths, HTML report generation fails entirely if the shared library is not found or partially loads.

**Fix:** Apply the established pattern: `tryCatch(source(...), error = function(e) message(...))` around the registry sourcing, plus a no-op fallback `turas_callout <<- function(module, key, ...) ""` after.

### C4. Stats pack missing per-cluster sample sizes and method-specific parameters

**File:** `segment/R/00_main.R`, lines 1068-1162
**Affects:** Contractual deliverables

The stats pack includes basic execution metadata and TRS events but omits:

1. **Per-cluster sample sizes** — the fundamental diagnostic for segmentation. Users cannot verify segment distribution without inspecting the main output files.
2. **Method-specific parameters** — `linkage_method` for hclust, `gmm_model_type` for GMM are not included.
3. **Implementation field is hardcoded** — line 1116 says `"base R kmeans() / hclust()"` even when GMM (mclust package) is used.
4. **Validation metrics** — silhouette, CH, DB index values are computed but not included in the stats pack.
5. **Config echo is incomplete** — missing `outlier_detection`, `outlier_method`, `variable_selection`, `linkage_method`, `gmm_model_type`.

By contrast, Phase 2 (weighting) includes per-weight diagnostics and Phase 3 (keydriver) includes VIF flags and bootstrap parameters.

**Risk:** Duncan delivers a stats pack for a GMM analysis that claims "base R kmeans()" as the implementation and shows no segment sizes. The contractual acceptance document is incomplete and misleading.

**Fix:** Add per-cluster sizes (from `table(cluster_result$clusters)`), correct the implementation field based on `config$method`, add validation metrics, and expand the config echo.

### C5. Davies-Bouldin index produces Inf with identical cluster centers

**File:** `segment/R/04_validation.R`, line 370
**Affects:** Cluster validation metrics

```r
between_dist <- sqrt(sum((centers[i, ] - centers[j, ])^2))
ratio <- (avg_within[i] + avg_within[j]) / between_dist
```

When two clusters have identical centers (possible with degenerate initial conditions or very similar data), `between_dist = 0` and the division produces `Inf`. This propagates through `mean(db_scores)` to produce `Inf` as the final DB index, which then appears in the validation output and HTML report with no diagnostic warning.

**Risk:** A degenerate clustering result shows DB index = Inf in the Excel output and HTML report. Jess doesn't know this means the solution is invalid.

**Fix:** Guard `between_dist == 0` and either skip that pair with a warning, or return NA for the DB index with a diagnostic message.

---

## Important Findings

These should be fixed soon. They affect consistency, maintainability, or robustness.

### I1. No multiple comparison correction in profiling tests

**File:** `segment/R/05a_profiling_stats.R`, `test_segment_differences()`
**Affects:** False positive rate in segment profiling

Each variable is tested independently at alpha=0.05. For a typical segmentation with 30+ profiling variables, the probability of at least one false positive is ~79%. The profiling output reports significance without any family-wise or FDR correction.

This is the same pattern noted in tracker (Phase 1 I10). Market research convention is no correction, but it should be documented.

**Action:** Add a note to the profiling results indicating no multiple comparison correction is applied. Add a documentation comment in the function header. Include this as an assumption in the stats pack.

### I2. GUI launcher stop() has no cat() for Shiny console visibility

**File:** `segment/run_segment_gui.R`, lines 14-22
**Affects:** Error display when required packages are missing

The `stop()` call produces a well-formatted TRS message but has no preceding `cat()` output. In Shiny, the formatted error may not reach the console. The bootstrap `stop()` in `00_guard.R:35` correctly has `cat()` before it (lines 31-34), but the GUI launcher does not.

This is the same pattern fixed in Phase 2 I4 (confidence), Phase 3 I2 (keydriver), and Phase 3 I3 (catdriver).

**Action:** Add `cat()` output before the `stop()` call to ensure the formatted error is visible in the Shiny console.

### I3. Config template missing 6+ fields and lacking polish

**Files:** `segment/docs/templates/Segment_Config_Template.xlsx`, `VarSel_Config_Template.xlsx`
**Affects:** Jess's ability to configure the module without touching R code

The config template is functional but below the Tabs module standard:

1. **Missing fields**: `k_selection_metrics`, `use_lca`, `varsel_min_variance`, `varsel_max_correlation`, `outlier_alpha`, and 11 `html_show_*` toggle fields are used in code but not documented in the template.
2. **No Required/Optional markers** — Tabs template clearly marks required vs optional fields.
3. **No section grouping** — 47 parameters in a flat list without visual sections.
4. **Limited validation dropdowns** — only 7 fields have dropdowns; numeric fields lack range guidance.
5. **No cross-field dependency notes** — e.g., `linkage_method` only applies when `method=hclust`.
6. **VarSel template lacks descriptions** — single-column values without guidance.

**Action:** Regenerate templates via the R generator with missing fields added, section headers, Required/Optional column, validation ranges for numeric fields, and cross-field notes. Bring to Tabs module standard.

### I4. Golden fixture tests not operationalized

**File:** `segment/tests/fixtures/generate_golden_files.R` (135 LOC)
**Affects:** Regression test coverage

The golden fixture generator infrastructure exists but has never been run:
- No `tests/fixtures/golden/` directory exists
- No golden RDS files have been generated
- No tests reference golden files

**Action:** Run the golden fixture generator, commit the fixtures, and verify the test infrastructure picks them up. If no tests exist to consume them, create `test_golden.R` following the catdriver pattern.

### I5. Profiling chi-square test does not check expected frequency assumption

**File:** `segment/R/05_profiling.R`, approximate lines 557-583
**Affects:** Validity of chi-square tests for demographic profiling

The `chisq.test(cross_tab)` call proceeds without checking whether expected frequencies meet the minimum threshold (conventionally 5). If any cell has expected frequency < 5, the chi-square approximation is invalid. R's `chisq.test` emits a warning, but this is caught by `tryCatch` and discarded.

**Action:** Check expected frequencies and either fall back to Fisher's exact test or add a diagnostic flag to the profiling output.

### I6. K-means convergence failure logged as INFO, not WARNING

**File:** `segment/R/03a_kmeans.R`
**Affects:** Detection of non-converged clustering solutions

When k-means reaches max iterations without converging (`ifault != 0`), the code logs this as an informational message and returns results as if valid. No guard state flag is set. The stats pack and HTML report don't indicate the solution may be suboptimal.

**Action:** Set `guard_record_cluster_stability("kmeans_not_converged", ...)` when convergence fails. Include convergence status in the stats pack assumptions.

### I7. GMM degenerate components not detected

**File:** `segment/R/03c_gmm.R`
**Affects:** Quality of GMM clustering solutions

When `mclust::Mclust()` returns a model with near-singular covariance matrices or very small component membership (< 5 observations), no warning is issued. The model may produce unreliable cluster assignments but appears valid to downstream code.

**Action:** Check `gmm_fit$parameters$variance$sigma` for near-zero determinant and component membership for minimum size. Set guard state flag if either threshold is violated.

### I8. Config template generator does not validate against actual config parser

**File:** `segment/docs/templates/create_config_template.R`
**Affects:** Template accuracy over time

The generator creates a template with hardcoded field lists. When new config fields are added to `01_config.R`, the template is not automatically updated. The 6 missing fields (I3) confirm this drift has already occurred.

**Action:** Add a test that compares template fields against `01_config.R` parsed defaults to catch drift. This is a Phase 10 item but should be noted.

---

## Minor Findings

Worth fixing when touching these files. Not urgent.

### M1. ANOVA eta-squared is SS_between/SS_total (correct but could use partial eta-squared)

**File:** `segment/R/05a_profiling_stats.R`, lines 87-89

The ANOVA effect size is `SS_between / SS_total`, which is eta-squared. Partial eta-squared (`SS_between / (SS_between + SS_within)`) is more standard in psychology/MR literature. Both are defensible; document the choice.

### M2. Distance matrix recomputed multiple times in validation

**File:** `segment/R/04_validation.R`, lines 427, 552

The distance matrix is recomputed for silhouette calculation each time, not cached. For n > 5000 this is a significant memory and performance hit. The module guards should enforce an upper bound for hclust (O(n^2) memory) but not for validation.

### M3. Cohen's d with single-point clusters produces NA silently

**File:** `segment/R/05a_profiling_stats.R`, line 206

When a cluster has a single observation, `sd()` returns `NA`, and Cohen's d becomes `NA` without any diagnostic. The pairwise comparison matrix has a missing entry with no explanation.

### M4. Hard-coded aov() output extraction is brittle

**File:** `segment/R/05_profiling.R`, line 142 (approx)

`test_result[[1]]$"F value"[1]` relies on aov summary structure remaining constant. If R changes the summary format, this extraction breaks silently.

### M5. Chi-square zero expected cells risk

**File:** `segment/R/05_profiling.R`

Same pattern as Tabs M5 — when a demographic category has zero observations in a segment, expected frequency is zero. Division-free but the chi-square approximation is invalid.

### M6. No weight support documented as design decision

**Scope:** Entire module

The module does not support survey weights. This is appropriate for clustering (weighted k-means is non-standard), but profiling tests (ANOVA, chi-square, Cohen's d) should ideally use effective N when weights are present in the source data. Currently unweighted profiling is the only option.

**Action:** Document as known design decision in the module README and stats pack methodology notes.

### M7. Index calculation silently skips variables with near-zero mean

**File:** `segment/R/05a_profiling_stats.R`, line 147

When `abs(overall_mean) < 1e-10`, the variable is skipped with `next` and the index matrix row remains NA. No indication in the output that this variable was excluded from indexing.

### M8. hclust cut height fallback when k > number of merge heights

**File:** `segment/R/03b_hclust.R`, lines 131-134

When `k > length(heights_sorted)`, uses `min(hc_model$height) * 0.5` as a fallback cut height. This is arbitrary and the visualization may show an incorrect cut line. The guard layer should prevent this case but it's not defensive.

### M9. write.csv in merge_segment_results has no encoding specification

**File:** `segment/R/10_utilities.R`, line 1553

`write.csv(merged, output_path, row.names = FALSE)` without `fileEncoding = "UTF-8"`. Same pattern fixed in Phase 2 I6 (weighting) and M9.

---

## Test Coverage Summary

| Metric | Segment |
|--------|---------|
| Production files | 38 |
| Test files | 21 |
| File ratio (test:prod) | 0.55 |
| Production LOC | 26,303 |
| Test LOC | 6,714 |
| LOC ratio (test:prod) | 0.26 |
| Tests passing | All |
| Tests skipped | 1 |
| Golden fixtures | Not generated |

### Critical untested files

- `02b_outliers.R` (749 LOC) — Mahalanobis, LOF, Tukey outlier detection, no dedicated tests
- `lib/html_report/03c_section_builders.R` (2,015 LOC) — largest file, no unit tests
- `lib/html_report/07a_combined_builders.R` (1,694 LOC) — 2nd largest, no unit tests
- `06_rules.R` (809 LOC) — decision rule generation, no tests
- `02_data_prep.R` (606 LOC) — data loading and missing data handling, no tests
- `02a_variable_selection.R` (510 LOC) — feature importance variable selection, no tests

### Assessment

Core clustering algorithms (k-means, hclust, GMM) have good dedicated tests. Guard framework is well-tested. Validation metrics, scoring, and ensemble have reasonable coverage. The major gaps are in the data processing pipeline (02*.R files — 1,865 LOC untested), the HTML report builders (9,054 LOC of 10,180 lib LOC untested), and rule generation. Bulk test additions deferred to Phase 10 per plan.

---

## Statistical Correctness Assessment

### K-means (03a_kmeans.R)

Standard k-means via `stats::kmeans()` with configurable nstart and seed. Mini-batch variant implemented for large datasets. K-means++ initialization correctly implemented with distance-weighted probability selection. Degenerate cluster handling: empty clusters cause frozen centers (logged as INFO, not flagged — see I6). Single-k early return is correct.

### Hierarchical Clustering (03b_hclust.R)

Correct delegation to `stats::hclust()` with `fastcluster` fallback. Distance matrix uses Euclidean. Linkage method validated against allowed list with case conversion. Cophenetic correlation computed with tryCatch. Dendrogram cut via `cutree()` — relies on guard layer to prevent k > n. Cut height calculation has a fallback for edge cases (M8).

### GMM (03c_gmm.R)

Correct use of `mclust::Mclust()` with model type and G parameter. NULL result check for convergence failure is good. BIC stored correctly. Exploration mode uses `mclustBIC()` for model selection. Missing: degenerate component detection (I7).

### Cluster Validation (04_validation.R)

Calinski-Harabasz: mathematically correct. Handles k=1 (returns NA). Handles n <= k.
Davies-Bouldin: correct formula but missing zero-distance guard (C5).
Silhouette: delegates to `cluster::silhouette()` — correct.
Gap statistic: follows Tibshirani et al. (2001). Reference distribution sampling correct.

### Profiling (05_profiling.R, 05a_profiling_stats.R)

ANOVA: correct via `aov()`. Eta-squared correct (SS_between/SS_total).
Kruskal-Wallis: correct test, **incorrect effect size formula** (C2).
Chi-square: correct via `chisq.test()`. Expected frequency assumption not checked (I5).
Cohen's d: correct pooled SD formula. Single-point cluster produces NA silently (M3).
Index scores: correct standardisation to overall mean. Near-zero mean skip is silent (M7).

---

## TRS Compliance Summary

| Metric | Segment |
|--------|---------|
| stop() calls in production | 1 (00_guard.R:35, acceptable bootstrap) |
| stop() calls in GUI launcher | 1 (now has cat() — I2 fixed) |
| stop() calls in tests/infra | 2 (acceptable) |
| TRS refusals (segment_refuse) | 19 hard guards |
| Guard layer | Complete (00_guard.R + 00a/00b) |
| Stats pack | Present (C4: now complete) |
| Run state tracking | Present |
| Console output | Comprehensive |
| Formula escape | Present (C1: now applied) |

---

## Fix Status (2026-04-06)

All critical, important, and applicable minor findings addressed in this session. Tests passing (Segment: all pass, 1 pre-existing skip).

| Finding | Status | What was done |
|---------|--------|---------------|
| C1: Formula injection in Excel output | FIXED | Added `seg_escape_cell()`/`seg_escape_df()` inline fallback using vapply+substr (not regex). Applied in `seg_write_branded_sheet()`, `seg_write_title()`, `seg_write_metrics()`, `add_segment_run_status_sheet()`, and `merge_segment_results()` |
| C2: Kruskal-Wallis effect size formula | FIXED | Replaced incorrect `(H - k + 1) / (n - k)` with standard epsilon-squared `H / (n - 1)` (Tomczak & Tomczak 2014). Clamped to [0, 1] |
| C3: HTML callout tryCatch + fallback | FIXED | Added `tryCatch()` around `source(callout_registry.R)` with `message()` on error. Added no-op fallback `turas_callout <<- function(module, key, ...) ""` |
| C4: Stats pack incomplete | FIXED | Added per-cluster sample sizes, validation metrics (silhouette/CH/DB), correct method-specific implementation label, outlier/variable selection details, expanded config echo, multiple comparison limitation note |
| C5: Davies-Bouldin Inf with identical centers | FIXED | Added `between_dist < 1e-10` guard that skips pair and emits console warning about near-identical centers |
| I1: Multiple comparison note | FIXED | Added documentation note in `test_segment_differences()` docstring about no family-wise correction and expected false positive rate. Added "Multiple comparisons" assumption to stats pack |
| I2: GUI launcher cat() before stop() | FIXED | Added `cat()` output with formatted error box before `stop()` for Shiny console visibility |
| I3: Config templates polish | FIXED | Generator rewritten with 5-column format (Setting, Value, Required?, Description, Valid Values), section headers, 16 missing fields added, all boolean dropdowns. Both templates regenerated. |
| I4: Golden fixtures generation | FIXED | Ran `generate_golden_files.R`; committed 3 golden RDS files to `tests/fixtures/golden/` |
| I5: Chi-square expected frequency | FIXED | Added `low_expected` flag to chi-square results; console message when significant result has expected frequency < 5 |
| I6: K-means convergence flag | FIXED | Added `convergence_warning` field to k-means result. Soft guard now records convergence issues in `guard$warnings` and `guard$stability_flags` |
| I7: GMM degenerate components | FIXED | Added component size check after Mclust() fit; warns when components have fewer than 5 members |
| I8: Config template drift test | DEFERRED | Phase 10 |
| M1-M8 | DEFERRED | All minor findings deferred to Phase 10 horizontal pass |
| M9: write.csv encoding | FIXED | Added `fileEncoding = "UTF-8"` to `write.csv()` call in `merge_segment_results()` |

**Also completed:**
- Technique guide written at `modules/segment/TECHNIQUE_GUIDE.md` covering questionnaire design, method selection, choosing k, profiling/validation, watchouts, and future directions

**Deferred to Phase 10 (horizontal pass):**
- I3: Config template polish (bring to Tabs standard — needs manual Excel work)
- I8: Config template drift test (automated field coverage check)
- M1: ANOVA eta-squared vs partial eta-squared documentation
- M2: Distance matrix caching in validation
- M3: Cohen's d single-point cluster diagnostic
- M4: Brittle aov() output extraction
- M5: Chi-square zero expected cells
- M6: Weight support design decision documentation (in module README)
- M7: Index calculation silent variable skip diagnostic
- M8: hclust cut height fallback documentation

**Next:** Re-review in fresh session to verify all fixes, then proceed to Phase 5 (Pricing).
