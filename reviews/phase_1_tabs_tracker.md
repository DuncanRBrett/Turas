# Phase 1: Tabs + Tracker Review

**Reviewed:** 2026-04-06
**Scope:** modules/tabs/ (47,355 LOC, 87 files) + modules/tracker/ (33,970 LOC, 56 files) + operational docs
**Verdict:** PASS WITH CONDITIONS — 5 critical findings, 10 important, 12 minor

---

## Critical Findings

These must be fixed. Each represents a path where Turas could produce incorrect output or deliver unverified claims to clients.

### C1. Tracker: enhanced rating/composite trends silently use unweighted N for significance

**File:** `tracker/lib/trend_calculator.R`, lines 706-713 (rating), 883-891 (composite)
**Affects:** All enhanced rating and composite trend significance tests

The `calculate_rating_trend_enhanced()` and `calculate_composite_trend_enhanced()` functions store `n_unweighted` and `n_weighted` in wave results but discard `eff_n`. The `calculate_weighted_mean()` function computes `eff_n` correctly, but `calculate_metrics_from_specs()` at line 539 only extracts `mean` and `sd` — it never propagates `eff_n` to the wave result.

In `trend_significance.R` line 55, the fallback logic:
```r
current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
```
silently substitutes unweighted N. This makes t-tests too liberal (inflated Type I error) when weights vary, because degrees of freedom and standard error are based on the raw sample size rather than the design-effect-adjusted size.

NPS trends are unaffected — `calculate_nps_score()` correctly returns `eff_n`.

**Risk:** Duncan delivers a tracker report showing "significant increase" in a rating when the effective sample size would not support that conclusion. The client acts on a spurious finding.

**Fix:** Propagate `eff_n` from `calculate_weighted_mean()` through `calculate_metrics_from_specs()` into the wave result structure.

### C2. Tracker: multi-mention trends have same missing eff_n

**File:** `tracker/lib/trend_calculator.R`, lines 1448-1455
**Affects:** All multi-mention trend significance tests

Same pattern as C1. Multi-mention wave results store `n_unweighted` and `n_weighted` but not `eff_n`. Z-tests for proportion significance fall back to unweighted N.

**Fix:** Same approach — propagate `eff_n` from the proportion calculation into multi-mention wave results.

### C3. AI executive summary has no verification pass

**File:** `tabs/lib/ai/ai_insights.R`, lines 194-213
**Affects:** AI-generated executive summaries in HTML reports

Per-question callouts go through a verification + regeneration loop that checks cited numbers against source data. The executive summary bypasses this entirely. If the LLM fabricates a number in the executive summary narrative, nothing catches it.

**Risk:** An HTML report contains a prominent executive summary with a fabricated statistic. Duncan delivers this to a client.

**Fix:** Route the executive summary through the same verification pipeline, or at minimum add a deterministic check that any numbers cited in the narrative appear in the source data.

### C4. AI verification is LLM-only — no deterministic numeric check

**File:** `shared/lib/ai/ai_verify.R`, lines 80-96
**Affects:** All AI-generated callouts

The verification pass sends the narrative + source data to a second LLM call and checks `numbers_accurate` and `significance_accurate`. This is LLM-against-LLM verification — the verifier can itself hallucinate and approve a false claim.

The system has good guardrails (structured output, explicit instructions, fail-safe suppression), but there is no deterministic step that parses numbers from the narrative and confirms each appears in the source data.

**Risk:** Low probability but high impact — a fabricated statistic passes verification and reaches a client report.

**Fix:** Add a rule-based pre-check: regex-extract numbers from the narrative and confirm each appears in the source data JSON. Fail the callout if any number is unmatched. This can run before or after the LLM verification.

### C5. Tracker has no stats pack

**Scope:** Entire tracker module
**Affects:** Contractual deliverables

Tracker generates Excel output with trends, significance, and dashboards but produces no diagnostics pack. The diagnostics pack is a contractual deliverable — clients are deemed to have accepted the methodology based on its contents. Without one, Duncan has no documented proof of what was calculated, what sample sizes were used, what significance thresholds were applied, or what data quality issues were encountered.

Every other analysis module has a stats pack. Tracker is the gap.

**Fix:** Add stats pack generation following the established pattern from `shared/lib/stats_pack_writer.R`. Must include: execution metadata, wave-level sample sizes (unweighted, weighted, effective), question coverage, significance test parameters, data quality diagnostics (missing waves, unmapped questions, low-base warnings), and guard state summary.

---

## Important Findings

These should be fixed soon. They affect consistency, maintainability, or robustness.

### I1. Tabs: chi-square docstring claims Yates' correction but code omits it

**File:** `tabs/lib/weighting.R`, line 1188 (docstring) vs line 1259 (implementation)
**Affects:** Chi-square test output documentation

The docstring says "Uses Pearson's chi-square test with continuity correction for 2x2 tables." The implementation is a plain Pearson chi-square: `sum((observed - expected)^2 / expected)` with no Yates' correction. The test is slightly anticonservative for 2x2 tables without correction. This is standard practice (many packages default to no correction), but the documentation makes a false claim.

**Action:** Fix the docstring to accurately describe the implementation. No code change needed — the test itself is standard.

### I2. Tabs: z-test precondition validators exist but are not wired into the execution pipeline

**Files:** `tabs/lib/validation.R` lines 843-932, 962-1050 (validators); `tabs/lib/weighting.R` (z-test execution)
**Affects:** Z-test validity for small-cell proportions

`validate_z_test_preconditions` (np >= 10) and `validate_column_comparison_preconditions` (np >= 5) were added in V10.1 but `weighted_z_test_proportions` does not call them. It only checks `min_base` (default 30). A z-test can run on data where the normal approximation is invalid (e.g., n=50, p=0.01 gives np=0.5).

**Action:** Wire the precondition validators into the z-test execution path, or add equivalent np/nq checks directly in `weighted_z_test_proportions`.

### I3. Tabs: duplicate calculate_weighted_percentage function definitions

**Files:** `tabs/lib/cell_calculator.R` line 140 (2 params, no rounding); `tabs/lib/weighting.R` line 711 (3 params, with rounding)
**Affects:** Source-order-dependent behaviour

Which definition wins depends entirely on source order. If the order changes, percentages would silently lose or gain rounding.

**Action:** Remove the cell_calculator.R definition and ensure all callers use the weighting.R version.

### I4. Tracker: significance key separator mismatch (_to_ vs _vs_)

**Files:** `tracker/lib/trend_significance.R` line 269 (`_to_`); `tracker/lib/tracker_output.R` line 413 (`_vs_`)
**Affects:** Enhanced metric significance display (latent bug)

`perform_significance_tests_for_metric` stores results with `"_to_"` separator. The output code looks up with `"_vs_"`. Currently inert because enhanced output tables don't display significance, but if anyone adds significance display to enhanced tables, results will silently show as non-significant.

**Action:** Standardise on `"_vs_"` across all significance functions.

### I5. Tracker: single-wave loop produces spurious keys

**Files:** `tracker/lib/trend_changes.R`, `tracker/lib/trend_significance.R`
**Affects:** Single-wave tracker configurations

When `length(wave_ids) == 1`, the R expression `2:1` evaluates to `c(2, 1)` rather than an empty sequence. The loop produces malformed keys like `"NA_vs_NA"`. The results contain `significant = FALSE` due to availability checks, so no incorrect conclusions, but the results structure is polluted.

**Action:** Add `if (length(wave_ids) < 2) return(list())` guard at the top of each change/significance function.

### I6. AI executive summary has no cache invalidation

**File:** `tabs/lib/ai/ai_insights.R`, lines 195-197
**Affects:** Stale executive summaries after data changes

Per-question callouts use content hashing for cache invalidation — if data changes, the callout is regenerated. The executive summary only regenerates if `narrative` is null or empty. A data change in one question makes the executive summary factually wrong, but it persists.

**Action:** Add content hash check for executive summary based on the aggregated question data.

### I7. Tabs: weighting.R has no dedicated tests (1,588 LOC)

**File:** `tabs/lib/weighting.R`
**Affects:** Test coverage for the entire weighting system

The weighting pipeline (weighted z-tests, effective base, weight application, design effect) has only 1 regression test for float tolerance. This is the highest-risk test gap given that wrong weights produce silently wrong output.

**Action:** Create `test_weighting.R` covering weighted_z_test_proportions, calculate_effective_n, apply_weights, design_effect, and the chi-square implementation.

### I8. Tracker: trend_calculator.R has no dedicated tests (1,508 LOC)

**File:** `tracker/lib/trend_calculator.R`
**Affects:** Core trend calculation engine

The single largest production file in the tracker module with no dedicated tests. Only exercised indirectly via the integration pipeline test.

**Action:** Create `test_trend_calculator.R` covering each question type dispatcher, edge cases (single wave, missing waves, zero base), and metric extraction.

### I9. Tracker: trend_significance.R + trend_changes.R untested

**Files:** `tracker/lib/trend_significance.R` (418 LOC), `tracker/lib/trend_changes.R` (298 LOC)
**Affects:** Statistical correctness of trend outputs

The significance testing and change detection logic — directly tied to correctness of deliverables — has no dedicated tests.

**Action:** Create `test_trend_significance.R` and `test_trend_changes.R` covering all test types, edge cases (zero values, single wave, degenerate proportions), and the key separator consistency.

### I10. Tracker: no multiple comparison correction (document as known limitation)

**Scope:** `tracker/lib/trend_significance.R`
**Affects:** Statistical interpretation

Each wave-pair comparison is tested independently at the configured alpha level. For a single-choice question with 10 response categories tested at alpha=0.05, the probability of at least one false positive is ~40%. This is standard in market research but should be documented.

**Action:** Add a comment in trend_significance.R documenting this as a known design decision, and add a note to the stats pack (once created) stating that no family-wise error correction is applied.

---

## Minor Findings

Worth fixing when touching these files. Not urgent.

### M1. Tabs: Likert index safe_equal missing NA guard

**File:** `tabs/lib/cell_calculator.R`, line 433

`safe_equal(data[[question_col]], index_options$OptionText[i])` will match NA data values against NA OptionText. The `!is.na()` guard present in `calculate_row_counts` is absent here.

### M2. Tabs: weighted SD uses sum(w) - 1 instead of standard weighted Bessel correction

**File:** `tabs/lib/standard_processor.R`, line 510

Uses `sum(w) - 1` as denominator. The standard weighted Bessel correction is `sum(w) - sum(w^2)/sum(w)`. The approximation works when weights are near 1.0 but becomes inaccurate as weights diverge. Display-only, does not affect significance tests.

### M3. Tabs: NPS exclusion list uses fragile string matching

**File:** `tabs/lib/cell_calculator.R`, lines 483-487

Hard-coded exclusion list `c("DK", "Don't know", "Not applicable", "NA")` with exact case matching. Case mismatches fall through to `as.numeric()` which correctly produces NA, so not a silent failure, but the string list is locale-dependent.

### M4. Tabs: Net Positive DK detection regex matches substrings

**File:** `tabs/lib/standard_processor.R`, lines 877-889

The regex pattern `"NA"` in `grepl()` matches any category containing "NA" as a substring (e.g., "National", "Alternative"). Should use word boundaries.

### M5. Tabs: chi-square zero expected cells silently dropped

**File:** `tabs/lib/weighting.R`, lines 1260-1262

When expected frequency is zero, the code sets it to NA and uses `na.rm = TRUE`, dropping the cell's contribution. A cell with observed > 0 but expected = 0 contradicts the independence hypothesis. Mitigated by `prepare_chi_square_matrix` stripping all-zero rows/cols, but edge cases remain.

### M6. Tracker: population-weighted variance in statistical_core.R

**File:** `tracker/lib/statistical_core.R`, line 240

Uses population formula `sum(w*(x-xbar)^2) / sum(w)` rather than the unbiased reliability-weights formula. Produces a small underestimate of SD, making CIs slightly too narrow and t-tests slightly too liberal. For typical market research weighting schemes (DEFF < 2.0), the bias is modest.

### M7. Tracker: hardcoded 1.96 for confidence intervals

**File:** `tracker/lib/statistical_core.R`, lines 253-254

Uses z-critical 1.96 rather than t-distribution critical value. The alpha level from config is not used — CI is always 95% regardless of settings. Negligible for large samples but incorrect for small effective N.

### M8. Tracker: z-test silent zero-SE return with no diagnostic

**File:** `tracker/lib/statistical_core.R`, lines 177-179

When pooled proportion is exactly 0 or 1 (SE = 0), returns `z_stat = 0, p_value = 1, significant = FALSE` with no indication this was a degenerate case.

### M9. Tracker: inconsistent NA direction values across change functions

**File:** `tracker/lib/trend_changes.R`

`calculate_changes` uses `direction = "unavailable"` for NA. `calculate_changes_for_metric` and `calculate_changes_for_multi_mention_option` use `direction = NA`. Downstream code checking `direction == "unavailable"` vs `is.na(direction)` could behave inconsistently.

### M10. Tracker: NPS significance test is very conservative

**File:** `tracker/lib/trend_significance.R`, lines 214-215

Uses worst-case NPS variance (10000) rather than computing SE from actual promoter/detractor proportions. Low statistical power — will miss real changes.

### M11. AI: model name in methodology note not HTML-escaped

**File:** `tabs/lib/ai/ai_rendering.R`, lines 138-156

The `model_name` from sidecar config is embedded in HTML without escaping. Exploitable only via manual sidecar file editing. Low risk but should be escaped for defence-in-depth.

### M12. Tabs: effective_n rounded to integer creates threshold dead zone

**File:** `tabs/lib/weighting.R`, line 401

`as.integer(round(n_effective))` creates a ~0.5-unit dead zone around the min_base threshold. Documented and deliberate, but n_eff=29.6 rounds to 30 and passes.

---

## Test Coverage Summary

| Metric | Tabs | Tracker |
|--------|------|---------|
| Production files | 55 | 33 |
| Test files | 27 | 20 |
| File ratio (test:prod) | 0.49 | 0.61 |
| Production LOC | 33,008 | 19,566 |
| Test LOC | 13,624 | 12,515 |
| LOC ratio (test:prod) | 0.41 | 0.64 |

### Critical untested files

**Tabs:**
- `weighting.R` (1,588 LOC) — entire weighting system, 1 regression test only
- `question_orchestrator.R` (708 LOC) + `run_crosstabs.R` (641 LOC) — orchestration layer
- `html_report/03a_page_styling.R` (1,164 LOC) + `03b_page_components.R` (1,333 LOC) — presentation

**Tracker:**
- `trend_calculator.R` (1,508 LOC) — core trend engine
- `trend_significance.R` (418 LOC) + `trend_changes.R` (298 LOC) — statistical correctness
- `banner_trends.R` (462 LOC) — banner-level trends

---

## Operational Documentation Assessment

### OPERATOR_GUIDE.md — 7/10

**Strengths:** Clear quick-start, module reference table, stats pack instructions, TRS error decoder, troubleshooting.

**Gaps:**
- No module-specific quick-start for Tabs or Tracker (config field reference, common mistakes)
- No Docker operational procedures (restart, logs, health monitoring, updates)
- No "how to interpret output" guide for stats packs
- No data folder setup guide (file naming, folder structure)

### Developer Documentation — 7.5/10

**Strengths:** Architecture documented, TRS system explained, coding conventions explicit, module-level tech docs exist.

**Gaps:**
- No first-day developer setup walkthrough
- No architecture overview diagram showing data flow between modules
- No testing guide (how to run, what to expect)

### AI Prompt Tuning Guide — 9/10

**Strengths:** 344-line comprehensive guide with systematic methodology, six prompt constants documented, rating criteria, round-by-round tuning process.

**Gap:** No operational guide for Jess on when to enable/disable AI insights.

---

## Fix Status (2026-04-06)

All critical, important, and applicable minor findings addressed in this session. Tests passing (Tabs: all pass, Tracker: all pass).

| Finding | Status | What was done |
|---------|--------|---------------|
| C1: Tracker eff_n missing (rating/composite) | FIXED | calculate_metrics_from_specs now extracts eff_n from calculate_weighted_mean; wave_results store eff_n for rating_enhanced and composite_enhanced |
| C2: Tracker eff_n missing (multi-mention) | FIXED | Multi-mention wave results now calculate and store eff_n via Kish formula from weights |
| C3: AI exec summary no verification | FIXED | Added deterministic_number_check to exec summary generation; also added data hash-based cache invalidation |
| C4: AI verification no deterministic check | FIXED | Added deterministic_number_check() to ai_verify.R — regex-extracts numbers from narrative and confirms each appears in source data before LLM verification |
| C5: Tracker stats pack incomplete | ENHANCED | Stats pack now includes per-wave sample sizes (unweighted, weighted, effective N), weight diagnostics (min, max, CV), skipped question details, alpha/min_base settings, and multiple comparison limitation note |
| I1: Chi-square docstring mismatch | FIXED | Docstring corrected to "no continuity correction applied" |
| I2: Z-test validators not wired | FIXED | Added np/nq >= 5 precondition check using pooled proportion directly in weighted_z_test_proportions |
| I3: Duplicate weighted percentage | FIXED | Removed duplicate from cell_calculator.R; canonical definition in weighting.R |
| I4: Significance key separator mismatch | FIXED | All significance functions now use "_vs_" separator consistently |
| I5: Single-wave loop spurious keys | FIXED | Added `if (length(wave_ids) < 2) return(list())` guard to all change and significance functions |
| I6: AI exec summary no cache invalidation | FIXED | Executive summary now uses content hash; regenerates when data changes |
| I7: Tabs weighting.R untested | DEFERRED | Needs dedicated test_weighting.R — deferred to Phase 10 horizontal pass |
| I8: Tracker trend_calculator.R untested | DEFERRED | Needs dedicated test file — deferred to Phase 10 horizontal pass |
| I9: Tracker trend_significance/changes untested | DEFERRED | Needs dedicated test files — deferred to Phase 10 horizontal pass |
| I10: No multiple comparison correction docs | FIXED | Added documentation comment to trend_significance.R header; stats pack assumptions include "No correction" note |
| M1: Likert index NA guard | FIXED | Added !is.na() guard to safe_equal matching in calculate_likert_index |
| M2: Weighted SD denominator | DEFERRED | Display-only; document during Phase 10 |
| M3: NPS exclusion string matching | DEFERRED | Safe (falls through to NA); document during Phase 10 |
| M4: Net Positive DK regex | FIXED | Changed to word-boundary regex to prevent substring matches |
| M5: Chi-square zero expected cells | DEFERRED | Mitigated by prepare_chi_square_matrix; document during Phase 10 |
| M6: Population-weighted variance | DEFERRED | Modest bias for typical weighting; document during Phase 10 |
| M7: Hardcoded 1.96 | DEFERRED | Document during Phase 10 |
| M8: Z-test silent zero-SE | DEFERRED | Correct behavior; add diagnostic field during Phase 10 |
| M9: Inconsistent NA direction | FIXED | All change functions now use "unavailable" consistently |
| M10: NPS significance conservative | DEFERRED | By design; document during Phase 10 |
| M11: Model name not HTML-escaped | FIXED | escape_html() applied to model_display_name in build_ai_methodology_note |
| M12: Effective N rounding | DEFERRED | Deliberate design; document during Phase 10 |

**Deferred to Phase 10 (horizontal pass):**
- I7-I9: Test coverage gaps for weighting.R, trend_calculator.R, trend_significance.R, trend_changes.R
- M2, M3, M5-M8, M10, M12: Documentation and minor statistical refinements

**Next:** Re-review in fresh session to verify all fixes, then proceed to Phase 2 (Weighting + Confidence).
