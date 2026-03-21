---
editor_options: 
  markdown: 
    wrap: 72
---

# Keydriver Module: Comprehensive Review & Implementation Plan

**Date:** 20 March 2026 **Module Version:** 10.3 **Reviewer:** Claude
Code **Scope:** Full line-by-line code review, documentation audit,
output quality assessment, feature gap analysis

------------------------------------------------------------------------

## PART 1: CURRENT STATE RATINGS

### Overall Score: 78/100

| Dimension                | Score  | Weight | Weighted  |
|--------------------------|--------|--------|-----------|
| **Code Quality**         | 75/100 | 20%    | 15.0      |
| **Stability**            | 70/100 | 20%    | 14.0      |
| **Maintainability**      | 80/100 | 15%    | 12.0      |
| **Functionality**        | 85/100 | 15%    | 12.75     |
| **Statistical Accuracy** | 72/100 | 15%    | 10.8      |
| **Excel Output**         | 78/100 | 5%     | 3.9       |
| **HTML Output**          | 82/100 | 10%    | 8.2       |
| **Overall**              |        |        | **76.65** |

### Why Not 95+

The module has an impressive feature set and solid architecture, but
falls short of 95 due to **critical bugs that can produce incorrect
results**, missing test coverage for those bugs, and documentation
inconsistencies. The issues are fixable and well-defined.

------------------------------------------------------------------------

## PART 2: CRITICAL BUGS (Must Fix)

### ~~BUG-1: RETRACTED~~ — Not a Bug

`keydriver_refuse()` calls `turas_refuse()` which calls `stop(cond)`.
Execution always halts. The missing `return()` wrappers are cosmetically
poor but functionally harmless since the error condition is thrown
before the next line executes.

------------------------------------------------------------------------

### BUG-2: Double-Weighted Bootstrap

**Severity:** HIGH **File:** `05_bootstrap.R` line 274 + 380 **Impact:**
Bootstrap CIs are biased — high-weight observations are
over-represented.

**Details:** When weights are provided, `bootstrap_importance_ci()`
resamples with `prob = w_prob` (weighted resampling, line 274). Then
`calculate_single_bootstrap()` fits `lm(..., weights = data[[weights]])`
(line 380). Weights are applied **twice**: once during resampling
(choosing rows proportional to weight) and again as analytic weights in
the model. This inflates the influence of high-weight observations.

**Standard approach:** Either (a) resample proportional to weights, then
fit unweighted, OR (b) resample uniformly, then fit weighted. Not both.

**Fix:** Remove the `weights` argument from the `lm()` call inside
`calculate_single_bootstrap()` when weighted resampling is used. Or
resample uniformly and keep the weights in the model.

------------------------------------------------------------------------

### BUG-3: Shapley Sub-Models Are Unweighted

**Severity:** HIGH **File:** `03_analysis.R` line 375 **Impact:** When
the main model uses survey weights, the Shapley value decomposition
ignores them entirely. The decomposition is inconsistent with the main
model.

**Details:** `calculate_shapley_values()` fits all subset models with
`stats::lm(as.formula(formula_str), data = data)` — no `weights`
argument. The main model at line 91 correctly uses `weights`, but
Shapley's internal fits do not.

**Fix:** Pass `config$weight_var` through to
`calculate_shapley_values()` and apply weights to all subset model fits.

------------------------------------------------------------------------

### BUG-4: CV Metric Reports Training Instead of Test

**Severity:** HIGH **File:** `R/kda_shap/shap_model.R` line 182-184
**Impact:** The SHAP model's reported CV performance is the training
metric, not the holdout metric.

**Details:** `cv_result$evaluation_log[[2]][best_iter]` accesses column
by position `[[2]]`, which is typically the mean training metric. The
test metric is usually in column 4 (e.g., `test_rmse_mean`).

**Fix:** Use named column access:
`cv_result$evaluation_log$test_rmse_mean[best_iter]` (or the appropriate
metric column).

------------------------------------------------------------------------

### BUG-5: Broken NA Fallback in Effect Size Interpretation

**Severity:** MEDIUM **File:** `06_effect_size.R` lines 406, 427, 449
**Impact:** Interpretation strings contain literal "NA" text instead of
the intended fallback.

**Details:** `tolower(effect_sizes[i]) %||% "an unclassified"` — the
`%||%` operator checks for `NULL`, but `tolower(NA)` returns `NA`, not
`NULL`. The fallback is never triggered.

**Fix:** Use `if (is.na(x)) "an unclassified" else tolower(x)` pattern.

------------------------------------------------------------------------

### BUG-6: Stated Importance Column Rename Lost

**Severity:** MEDIUM **File:** `01_config.R` line 338 **Impact:** If a
user names the stated importance column something other than
`"stated_importance"`, downstream code expecting that column name will
fail.

**Details:** `validate_stated_importance_sheet()` renames a column in a
local copy of `si_df` but returns `invisible(TRUE)`, not the modified
data frame. The caller never receives the renamed column.

**Fix:** Return the modified data frame or rename in the caller's scope.

------------------------------------------------------------------------

### BUG-7: Feature Map Regex Over-Matching

**Severity:** MEDIUM **File:** `R/kda_shap/shap_calculate.R` line 135
**Impact:** `create_feature_map` using `paste0("^", col)` as regex:
driver `"Q1"` matches `"Q10"`, `"Q100"`, etc.

**Fix:** Use anchored regex: `paste0("^", col, "(?=$|[^[:alnum:]_])")`
with `perl = TRUE`.

------------------------------------------------------------------------

### BUG-8: Term Mapping Prefix Collision

**Severity:** MEDIUM **File:** `02_term_mapping.R`
`find_matching_terms()` **Impact:** If driver names share prefixes
(e.g., `"price"` and `"price_premium"`), model terms can be mapped to
the wrong driver.

**Fix:** Sort drivers by name length (longest first) before matching, or
use exact boundary matching.

------------------------------------------------------------------------

## PART 3: STATISTICAL ACCURACY ISSUES

### STAT-1: Non-Standard Effect Size Thresholds

**File:** `06_effect_size.R` line 58 Cohen's f² benchmarks are labeled
`negligible=0.02, small=0.15, medium=0.35`. Cohen (1988) defines
`small=0.02, medium=0.15, large=0.35`. The module inserts a "negligible"
category below Cohen's definitions, shifting the standard labels. This
is defensible but must be clearly documented as a Turas-specific
convention, not Cohen's original.

### STAT-2: Bootstrap Point Estimate vs Original-Sample Statistic

**File:** `05_bootstrap.R` line 499 The "Point_Estimate" is the mean of
the bootstrap distribution, not the original-sample importance. These
can differ. Users may be confused when bootstrap point estimates don't
match the main analysis output.

### STAT-3: Inconsistent `use` Arguments in Bootstrap Relative Weights

**File:** `05_bootstrap.R` lines 405 vs 407 `pairwise.complete.obs` for
R_xx vs `complete.obs` for r_xy can use different observation subsets,
making relative weights inconsistent within a bootstrap iteration.

### STAT-4: Executive Summary Wording

**File:** `08_executive_summary.R` The headline says a driver "explains
X% of the model's variance." Shapley values are a share of R², not total
variance. If R²=0.40 and Shapley=30%, the driver explains 12% of total
variance, not 30%. Should say "accounts for X% of explained variance" or
"X% of driver importance."

### STAT-5: Diagnostic Verdict Doesn't Factor in VIF

**File:** `lib/html_report/03_page_builder.R` lines 2500-2541 The
verdict banner uses only R² and F-test significance. A high R² with VIF
\> 10 should downgrade confidence. Consider cross-referencing VIF in the
verdict.

### STAT-6: Non-Positive-Definite Correlation Matrix Risk

**File:** `03_analysis.R` line 49
`stats::cor(..., use = "pairwise.complete.obs")` can produce
non-positive-definite matrices with different missing patterns. This
feeds into `calculate_relative_weights()` which does eigen decomposition
and could get negative eigenvalues. No check for positive-definiteness
exists.

### STAT-7: Segment Comparison Uses Different Method Than Main Analysis

**File:** `07_segment_comparison.R` lines 529-541 Segment importance
uses standardized betas, while the main analysis defaults to Shapley
values. The comparison matrix column is named `Importance_Pct` without
clarifying which method was used. Users could mistakenly compare to main
analysis Shapley percentages.

------------------------------------------------------------------------

## PART 4: CODE QUALITY ISSUES

### CQ-1: Repeated `source()` at Runtime

**File:** `00_main.R` lines 566, 597, 628, 658, 812-818, 846-851, 944,
954 Every analysis invocation re-sources all helper files. Should source
once at load time.

### CQ-2: `source(... local = FALSE)` Pollutes Global Environment

**File:** `00_main.R` All sourced functions land in `.GlobalEnv`. Should
use `local = TRUE` or source into a module environment.

### CQ-3: `%||%` Operator Defined in 7+ Files

Should be defined once in `modules/shared/` and sourced by all files.

### CQ-4: `sapply` Without Type Safety

**File:** `00_main.R` lines 880, 883 (`add_shap_to_importance`) `sapply`
can return unexpected types. Use `vapply` with a type template.

### CQ-5: Dead Guard Functions

**File:** `00_guard.R` - `validate_keydriver_data()` — defined but never
called from main pipeline - `guard_validate_model_assumptions()` —
defined but never wired in (VIF + normality checks never run) -
`guard_check_feature_packages()` — defined but never called

### CQ-6: `03_page_builder.R` Is 3,100 Lines

Monolithic file handles CSS, header, nav, all section builders, pinned
panel, footer, JS inlining. Should be split.

### CQ-7: Global CSS Reset

**File:** `03_page_builder.R` line 250
`* { box-sizing: border-box; margin: 0; padding: 0; }` will conflict if
embedded in Report Hub.

### CQ-8: Hardcoded SVG Dimensions

Chart widths (700px), label widths (200px), bar areas (430px) are fixed
across all charts. Long driver names can overflow.

### CQ-9: `<<-` for Error Accumulation

**File:** `00_main.R` lines 579-580, 724-725 Bootstrap and HTML report
`tryCatch` blocks use `<<-` to modify outer-scope variables. Should use
the cleaner `handle_optional_feature()` pattern already used for
SHAP/quadrant.

### CQ-10: Duplicate `<body>` Tag in Demo HTML

**File:** `examples/keydriver/demo_showcase/Demo_KeyDriver_Results.html`
lines 1213-1214

------------------------------------------------------------------------

## PART 5: DOCUMENTATION ISSUES

### DOC-1: Version Inconsistency

-   `02_KEYDRIVER_OVERVIEW.md` — v10.0 (stale, missing all v10.3
    features)
-   `04_USER_MANUAL.md` — v11.0 (ahead of module)
-   All others — v10.3 These must be synchronized.

### DOC-2: Setting Name Conflicts

-   `enable_html_report` vs `html_report` (Template Reference vs User
    Manual)
-   `accent_colour` default: `#f59e0b` (Template Reference) vs `#CC9900`
    (User Manual)
-   10+ settings in User Manual appendix not documented in Template
    Reference

### DOC-3: Method Count Inconsistency

Documents variously describe "5 methods," "5 plus SHAP," or list 6-7
when counting Pearson/Spearman separately or including partial R² and
permutation importance. Need a canonical method list.

### DOC-4: Stale Line Counts

`05_TECHNICAL_DOCS.md` lists `05_bootstrap.R` at "\~200 lines" (actual:
524), `06_effect_size.R` at "\~150 lines" (actual: 495), and similar
discrepancies for 5+ other files.

### DOC-5: No Package Version Table

No document lists minimum versions for all dependencies. Only the README
lists versions for 2 of 15+ packages.

### DOC-6: Multi-Analysis Unified Report Not Documented

No document explains how to run multiple KDA analyses (different
outcomes) and combine into a single report, or how Report Hub
integration works.

### DOC-7: SHAP/Quadrant File Counts Wrong in README

README lists SHAP as "(4 files)" (actual: 6) and quadrant as "(5 files)"
(actual: 6).

------------------------------------------------------------------------

## PART 6: TEST COVERAGE GAPS

### TEST-1: No Test for Double-Weighted Bootstrap

The bootstrap bug (BUG-2) has no test coverage. Need a test comparing
weighted bootstrap CIs to a known-correct implementation.

### TEST-2: No Test for Unweighted Shapley

BUG-3 has no test. Need a test verifying Shapley values change when
weights are applied.

### TEST-3: No Full Pipeline Integration Test

No test runs `run_keydriver_analysis()` end-to-end with real data
through to output file generation.

### TEST-4: Integration Tests Silently Skip on Failure

Many integration tests use `tryCatch -> NULL -> skip_if(is.null)`,
masking real failures.

### TEST-5: Bootstrap Test Uses n=10 (Below Minimum Guard)

`test_integration.R` line 214 uses `n_bootstrap = 10`, which is below
the min-100 guard. The test may bypass validation.

### TEST-6: No Golden File Tests

Golden file directory exists but is empty. Deterministic seeds make
golden files feasible.

### TEST-7: Mixed Predictor Fixture Never Used in Tests

`generate_mixed_kda_data()` exists in fixtures but no test exercises
mixed predictor paths.

------------------------------------------------------------------------

## PART 7: HTML REPORT ASSESSMENT

### Strengths

-   **Visual quality:** Excellent. Consistent Turas design system:
    rounded bars, muted palette, soft charcoal labels, font-weight
    hierarchy, no gradients/shadows.
-   **Statistical callouts:** All accurate and defensible. Correctly
    avoids causal language. Interpretation guide DO/DON'T is
    well-crafted.
-   **Pinned views:** Fully functional pin/unpin/reorder/export workflow
    with dedicated tab panel.
-   **Slide export:** Presentation-quality PNG rendering at 3840x2160
    with branded headers/footers.
-   **Print stylesheet:** Present and well-implemented.

### Gaps vs Tabs Module

| Feature                                             | Tabs | Keydriver |
|-----------------------------------------------------|------|-----------|
| Chart picker (interactive chart type switching)     | Yes  | **No**    |
| Qualitative slides (markdown editor + image upload) | Yes  | **No**    |
| Per-table CSV/Excel export                          | Yes  | **No**    |
| Dashboard/summary tab                               | Yes  | **No**    |
| Image upload to custom slides                       | Yes  | **No**    |

### Other HTML Issues

-   Label truncation missing — long driver names overflow SVG charts
-   Accessibility: SHAP/segment charts missing `role="img"`, no
    skip-to-content link
-   R² confidence thresholds hardcoded (should be configurable)
-   Effect size benchmarks hardcoded in charts (should match config)
-   Verdict banner doesn't factor in VIF warnings
-   Global CSS `*` reset could conflict with Report Hub embedding

------------------------------------------------------------------------

## PART 8: EXCEL OUTPUT ASSESSMENT

### Strengths

-   Professional blue-header styling with auto column widths
-   VIF diagnostics sheet with threshold flagging
-   Run_Status sheet with method notes (good audit trail)
-   Bar chart embedded as PNG

### Gaps

-   Bar chart is base R `barplot()` PNG — basic compared to SVG charts
    in HTML
-   README sheet uses plain text in a single column — could use styled
    headers
-   `saveWorkbook` non-atomic path not wrapped in `tryCatch`
-   Empty VIF table when \< 2 predictors (confusing)

------------------------------------------------------------------------

## PART 9: CONFIG ASSESSMENT

### Strengths

-   Uses shared `template_styles.R` for consistent branding (actually
    ahead of tabs which still inlines styles)
-   Data validation dropdowns on all enum fields
-   Example rows in all table sheets
-   Professional visual quality matching platform standard

### Gaps

-   No fields for slide templates, image paths, or presentation export
-   No GUI-level toggles for SHAP/quadrant/bootstrap (users must edit
    Excel)
-   Missing several SHAP/quadrant parameters that exist in code but not
    template

------------------------------------------------------------------------

## PART 10: NEW ANALYTICAL FEATURES TO CONSIDER

Based on research into published methods suitable for survey data
(200-2000 respondents, 5-30 drivers):

### Priority 1: Penalized Regression (Elastic Net)

-   **Package:** `glmnet` (Friedman, Hastie, Tibshirani — Stanford)
-   **Value:** Handles multicollinearity gracefully, performs automatic
    variable selection, answers "which drivers can we ignore?"
-   **Effort:** Low — `cv.glmnet()` does most of the work
-   **Literature:** Tibshirani (1996), Zou & Hastie (2005)

### Priority 2: Necessary Condition Analysis (NCA)

-   **Package:** `NCA` (Dul — CRAN, actively maintained)
-   **Value:** Identifies "hygiene factors" (necessary but not
    differentiating) vs "motivators" — fundamentally different insight
    from regression. Creates a powerful 2×2 framework when combined with
    derived importance.
-   **Effort:** Low-Medium
-   **Literature:** Dul (2016) Organizational Research Methods

### Priority 3: GAMs for Nonlinear Driver Effects

-   **Package:** `mgcv` (Wood — part of base R recommended packages)
-   **Value:** Reveals diminishing returns, thresholds, and S-curves in
    driver-outcome relationships. Directly actionable: shows where
    investment will and won't pay off.
-   **Effort:** Medium
-   **Literature:** Wood (2017) "Generalized Additive Models" 2nd ed.

### Priority 4: Dominance Analysis (Complete + Conditional)

-   **Package:** `domir` (Luchman — CRAN)
-   **Value:** Extends Shapley (= general dominance) with complete
    dominance (pairwise in every context) and conditional dominance (by
    model size). Reveals suppressor effects.
-   **Effort:** Low
-   **Literature:** Budescu (1993), Azen & Budescu (2003)

### Deferred: Conditional RF Importance, Bayesian Networks

-   Conditional RF: Corrects correlated-predictor bias but SHAP
    partially addresses this. Medium effort for moderate incremental
    value.
-   Bayesian Networks: Highest insight value (discovers mediation
    structure) but high implementation complexity and difficult to
    present to non-technical clients. Best saved for a future release.

------------------------------------------------------------------------

## PART 11: IMPLEMENTATION PLAN

### Phase 1: Critical Bug Fixes (Estimated: 2-3 days)

#### 1.1 Fix missing `return()` on all `keydriver_refuse()` calls

-   `03_analysis.R`: 6 locations (lines 181, 199, 212, 269, 344, 556)
-   `06_effect_size.R`: 10 locations (every `keydriver_refuse()` call)
-   Verify no other files have the same pattern

#### 1.2 Fix double-weighted bootstrap

-   `05_bootstrap.R`: Remove `weights` from inner `lm()` when weighted
    resampling is used
-   Add test comparing weighted bootstrap output to known-correct values

#### 1.3 Fix unweighted Shapley

-   `03_analysis.R` `calculate_shapley_values()`: Pass weight variable
    through, apply to all subset models
-   Add test verifying weighted Shapley differs from unweighted

#### 1.4 Fix CV metric column access

-   `R/kda_shap/shap_model.R` line 183: Use named column access instead
    of position `[[2]]`

#### 1.5 Fix NA fallback in effect size interpretation

-   `06_effect_size.R` lines 406, 427, 449: Replace `%||%` with explicit
    `is.na()` check

#### 1.6 Fix stated importance column rename

-   `01_config.R` `validate_stated_importance_sheet()`: Return modified
    data frame

#### 1.7 Fix regex over-matching

-   `R/kda_shap/shap_calculate.R` line 135: Use anchored regex
-   `02_term_mapping.R`: Sort by name length or use boundary matching

#### 1.8 Wire in dead guard functions

-   Call `validate_keydriver_data()` from the main pipeline
-   Call `guard_validate_model_assumptions()` after model fitting
-   Call `guard_check_feature_packages()` during guard phase

### Phase 2: Statistical Accuracy Fixes (Estimated: 1-2 days)

#### 2.1 Document effect size thresholds as Turas convention

-   Add clear note in HTML callout and documentation that thresholds
    include a "negligible" category below Cohen's "small"
-   Ensure the 4-tier labels are consistent between code, HTML, and docs

#### 2.2 Fix executive summary wording

-   Change "explains X% of the model's variance" → "accounts for X% of
    driver importance"

#### 2.3 Add positive-definiteness check for correlation matrix

-   Before eigen decomposition in `calculate_relative_weights()`, check
    eigenvalues \> 0
-   Fall back to nearPD() from `Matrix` package if needed, with a
    warning

#### 2.4 Fix bootstrap point estimate

-   Return original-sample importance alongside bootstrap distribution
    mean
-   Label columns as `Bootstrap_Mean` and `Original_Estimate`

#### 2.5 Fix bootstrap relative weights consistency

-   Use `complete.obs` for both R_xx and r_xy, or
    `pairwise.complete.obs` for both

#### 2.6 Add VIF to diagnostic verdict

-   Cross-reference VIF results in the verdict banner (downgrade if max
    VIF \> 10)

#### 2.7 Clarify segment comparison method

-   Add column or note indicating the segment comparison uses
    standardized betas (not Shapley)

### Phase 3: Code Quality Improvements (Estimated: 2-3 days)

#### 3.1 Consolidate `source()` calls

-   Move all file sourcing to module load time (top of `00_main.R` or a
    dedicated loader)
-   Use `local = TRUE` or a module environment

#### 3.2 Centralize `%||%` operator

-   Define once in `modules/shared/` utilities
-   Remove all 7+ duplicate definitions

#### 3.3 Replace `sapply` with `vapply`

-   `00_main.R` lines 880, 883

#### 3.4 Apply `handle_optional_feature()` pattern consistently

-   Refactor bootstrap and HTML report error handling to match
    SHAP/quadrant pattern (eliminate `<<-`)

#### 3.5 Split `03_page_builder.R`

-   Extract CSS into `03a_page_styling.R` (matching tabs module pattern)
-   Extract section builders into separate files if they exceed 200
    lines each

#### 3.6 Scope CSS

-   Replace `* { ... }` global reset with `.kd-body * { ... }` or use
    `:where(.kd-body)` scoping

#### 3.7 Add SVG label truncation

-   Implement `truncate_label()` for all chart builders with
    configurable max width

### Phase 4: HTML Report Enhancement (Estimated: 3-4 days)

#### 4.1 Add qualitative slides + image upload

-   Port qualitative slide system from tabs module (`addQualSlide()`,
    markdown editor, file input image upload)
-   Adapt for keydriver context (analyst commentary slides between
    analysis sections)

#### 4.2 Add per-table CSV/Excel export

-   Port `table_export_init.js` from tabs module
-   Add export buttons to all HTML tables

#### 4.3 Add chart picker (where applicable)

-   For importance visualization: allow switching between horizontal
    bar, lollipop, and dot plot
-   For correlation: allow switching between heatmap and bubble chart

#### 4.4 Improve label collision in quadrant charts

-   Implement a repulsion-based label placement algorithm (or port from
    tabs if exists)
-   Increase minimum point opacity from 0.45 to 0.55

#### 4.5 Add accessibility improvements

-   Add `role="img"` and `aria-label` to SHAP and segment charts
-   Add skip-to-content link
-   Add ARIA labels to contenteditable insight editors

#### 4.6 Make thresholds configurable

-   R² confidence tiers, effect size benchmarks, VIF thresholds, top-n
    drivers: read from config with current values as defaults

#### 4.7 Add config-driven slide/image support

-   Add `custom_slides` config sheet for R-side slide generation
-   Support image paths in config for branded slide backgrounds

### Phase 5: Config & Excel Output Polish (Estimated: 1-2 days)

#### 5.1 Add missing config fields

-   Slide/image configuration fields
-   All SHAP/quadrant parameters that exist in code but not template
-   Researcher/client logo paths

#### 5.2 Polish Excel output

-   Replace base R `barplot()` PNG with higher-quality chart
-   Add styled headers to README sheet
-   Fix empty VIF table for \< 2 predictors (show "N/A" message)
-   Wrap non-atomic `saveWorkbook` in `tryCatch`

#### 5.3 Fix duplicate function calls in executive summary

-   `08_executive_summary.R`: Remove duplicate calls to
    `assess_method_agreement` and `assess_model_quality`

### Phase 6: New Analytical Features (Estimated: 4-5 days)

#### 6.1 Elastic Net Importance

-   Add `09_elastic_net.R` with `cv.glmnet()` pipeline
-   Integrate as optional importance method (like SHAP)
-   Add config toggle: `enable_elastic_net`
-   Add HTML section with coefficient path plot and selected/zeroed
    drivers

#### 6.2 Necessary Condition Analysis

-   Add `10_nca.R` with `NCA::NCA()` pipeline
-   Integrate ceiling line visualization
-   Add bottleneck table to HTML report
-   Combine with derived importance for hygiene/motivator classification

#### 6.3 Dominance Analysis (Complete + Conditional)

-   Add `11_dominance.R` with `domir::domin()` pipeline
-   Extend Shapley section with conditional dominance rankings
-   Add dominance heatmap to HTML report

#### 6.4 GAMs for Nonlinear Effects (Optional)

-   Add `12_gam.R` with `mgcv::gam()` pipeline
-   Add smooth function visualization per driver
-   Flag drivers with significant nonlinear effects

### Phase 7: Documentation Overhaul (Estimated: 2-3 days)

#### 7.1 Synchronize all versions to current (e.g., v11.0)

#### 7.2 Complete package version table (all 15+ packages with minimum versions)

#### 7.3 Rewrite `02_KEYDRIVER_OVERVIEW.md` to include all v10.3+ features

#### 7.4 Resolve all setting name conflicts between documents

#### 7.5 Fix file counts and line counts in README and Technical Docs

#### 7.6 Add multi-analysis unified report documentation

#### 7.7 Add complete R package dependency table with versions to User Manual

#### 7.8 Ensure User Manual covers new features (Elastic Net, NCA, Dominance)

#### 7.9 Update CODE_INVENTORY.md with new files and quality scores

### Phase 8: Test Suite Hardening (Estimated: 2-3 days)

#### 8.1 Add tests for all critical bugs

-   Test weighted bootstrap produces correct CIs (compare to manual
    calculation)
-   Test weighted Shapley differs from unweighted
-   Test missing `return()` scenarios don't fall through
-   Test effect size NA handling

#### 8.2 Add full pipeline integration test

-   `run_keydriver_analysis()` end-to-end with demo data
-   Verify Excel and HTML output files are created and valid

#### 8.3 Remove silent skip pattern

-   Replace `tryCatch -> NULL -> skip_if` with proper expects

#### 8.4 Add golden file tests

-   Generate reference outputs with known seed
-   Compare new outputs to golden files with tolerance

#### 8.5 Add mixed predictor tests

-   Exercise `generate_mixed_kda_data()` fixture through full pipeline

#### 8.6 Fix bootstrap integration test

-   Use n_bootstrap \>= 100 to match the production guard

### Phase 9: Demo Regeneration (Estimated: 1 day)

#### 9.1 Update `generate_demo_data.R` if new features need demo data

#### 9.2 Update `create_demo_config.R` with new config fields

#### 9.3 Regenerate all demo outputs (Excel, HTML, CSVs, executive summary)

#### 9.4 Verify demo is fully runnable from scratch

#### 9.5 Update demo README with new features

------------------------------------------------------------------------

## PART 12: ESTIMATED EFFORT SUMMARY

| Phase                       | Days      | Priority |
|-----------------------------|-----------|----------|
| 1\. Critical Bug Fixes      | 2-3       | **P0**   |
| 2\. Statistical Accuracy    | 1-2       | **P0**   |
| 3\. Code Quality            | 2-3       | **P1**   |
| 4\. HTML Enhancement        | 3-4       | **P1**   |
| 5\. Config & Excel Polish   | 1-2       | **P1**   |
| 6\. New Analytical Features | 4-5       | **P2**   |
| 7\. Documentation Overhaul  | 2-3       | **P1**   |
| 8\. Test Suite Hardening    | 2-3       | **P1**   |
| 9\. Demo Regeneration       | 1         | **P1**   |
| **Total**                   | **18-26** |          |

### Path to 95+

Completing Phases 1-5 + 7-9 would bring the module to approximately
**90/100**. Adding Phase 6 (new analytical features) would push it to
**95+** by establishing it as a genuinely comprehensive, best-in-class
key driver analysis tool.

------------------------------------------------------------------------

## PART 13: R PACKAGE DEPENDENCIES

### Required (Core)

| Package      | Purpose                        | Min Version |
|--------------|--------------------------------|-------------|
| `stats`      | Base regression, correlation   | Base R      |
| `utils`      | CSV reading, general utilities | Base R      |
| `openxlsx`   | Excel I/O                      | \>= 4.2.5   |
| `data.table` | Fast data manipulation         | \>= 1.14.0  |
| `jsonlite`   | JSON output                    | \>= 1.8.0   |

### Required (Analysis)

| Package      | Purpose                      | Min Version |
|--------------|------------------------------|-------------|
| `survey`     | Weighted variance estimation | \>= 4.1     |
| `effectsize` | Effect size calculations     | \>= 0.8.0   |

### Optional (SHAP)

| Package   | Purpose                         | Min Version |
|-----------|---------------------------------|-------------|
| `xgboost` | Gradient boosting models        | \>= 1.7.0   |
| `shapviz` | TreeSHAP values + visualization | \>= 0.9.0   |
| `ggplot2` | SHAP plots                      | \>= 3.4.0   |
| `scales`  | Axis formatting                 | \>= 1.2.0   |

### Optional (Quadrant)

| Package   | Purpose         | Min Version |
|-----------|-----------------|-------------|
| `ggplot2` | IPA plots       | \>= 3.4.0   |
| `ggrepel` | Label repulsion | \>= 0.9.0   |

### Optional (Data Import)

| Package  | Purpose                   | Min Version |
|----------|---------------------------|-------------|
| `haven`  | SPSS/Stata import         | \>= 2.5.0   |
| `readxl` | Alternative Excel reading | \>= 1.4.0   |

### Optional (GUI)

| Package      | Purpose        | Min Version |
|--------------|----------------|-------------|
| `shiny`      | GUI framework  | \>= 1.7.0   |
| `shinyFiles` | File browser   | \>= 0.9.0   |
| `shinyjs`    | JS integration | \>= 2.1.0   |

### Proposed New Dependencies

| Package  | Purpose                      | Min Version        |
|----------|------------------------------|--------------------|
| `glmnet` | Elastic Net regression       | \>= 4.1            |
| `NCA`    | Necessary Condition Analysis | \>= 3.2.0          |
| `domir`  | Dominance Analysis           | \>= 1.0.0          |
| `mgcv`   | GAMs (nonlinear effects)     | Base R recommended |
| `Matrix` | nearPD for correlation fix   | Base R recommended |

------------------------------------------------------------------------

## APPENDIX: FILES REVIEWED

**35 R source files** across R/, R/kda_shap/, R/kda_quadrant/, lib/,
lib/html_report/, lib/validation/ **4 JavaScript files** in
lib/html_report/js/ **12 test files** in tests/testthat/ **1 test
fixture generator** + 1 test runner **10 documentation files** in docs/
**8 demo files** in examples/keydriver/demo_showcase/ **1 GUI launcher**
**1 config template generator**

**Total files reviewed: 72**
