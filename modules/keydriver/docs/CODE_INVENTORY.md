# Key Driver Module -- Code Inventory

**Module:** `modules/keydriver/`
**Version:** 10.4
**Platform:** Turas Analytics (The Research LampPost)
**Last Updated:** 2026-03-20

---

## Overview

The Turas Key Driver module performs key driver analysis, identifying which
variables most strongly predict a continuous outcome. It supports five
classical importance methods (Pearson correlation, Spearman correlation,
standardized regression coefficients, relative importance, and Shapley
regression), plus optional SHAP-based machine-learning importance via XGBoost
and Importance-Performance Analysis (IPA/Quadrant charts).

v10.3 introduced bootstrap confidence intervals, Cohen's-d effect-size
interpretation, cross-segment driver comparison, and plain-English executive
summaries.

**v10.4** adds four advanced analytical methods: Elastic Net regularized
regression (glmnet), Necessary Condition Analysis (NCA), Dominance Analysis
(domir), and Generalized Additive Models (GAM/mgcv) for nonlinear effect
detection. The config template now supports CustomSlides for qualitative
commentary and an Insights sheet for pre-populating analyst insights
(with optional base64-encoded images) into the HTML report. All 14 report
sections accept config-driven insight pre-population.

Results are delivered as formatted Excel workbooks and interactive HTML reports
with embedded SVG charts, sticky navigation, pinned-view snapshots, and
1280x720 PNG slide export.

---

## Summary Statistics

| Metric                        | Value       |
|-------------------------------|-------------|
| Total R lines                 | ~21,429     |
| Total JS lines                | ~2,329      |
| **Grand total (R + JS)**      | **~23,758** |
| R source files                | 38          |
| JS source files               | 5           |
| **Total source files**        | **43**      |
| Test files                    | 14          |
| Test lines                    | ~5,484      |
| Test assertions               | 711 pass, 0 fail, 14 skip |
| Submodules                    | 3 (SHAP, Quadrant, HTML Report) |
| Classical importance methods  | 5           |
| ML importance methods         | 1 (SHAP/XGBoost) |
| v10.4 advanced methods        | 4 (Elastic Net, NCA, Dominance, GAM) |
| HTML chart types              | 7 SVG + quadrant |
| Config template sheets        | 6 (Settings, Variables, Segments, StatedImportance, CustomSlides, Insights) |
| Largest file                  | `03_page_builder.R` (3,748 lines) |
| Smallest file                 | `00_html_guard.R` / `04_html_writer.R` (~112 lines each) |

---

## Detailed File Inventory

### Root Entry Point

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `run_keydriver_gui.R` | 422 | Shiny GUI for interactive key driver analysis | 87 | Launches standalone Shiny app; `withProgress()` bar during analysis; wires GUI controls to core pipeline |

### Core Pipeline -- `R/`

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `00_guard.R` | 523 | TRS v1.1 guard layer; validates all inputs before analysis begins | 92 | Comprehensive type/range/existence checks; structured refusals with actionable messages |
| `00_main.R` | 1,064 | 18-step orchestration pipeline; single public entry point | 90 | Coordinates guard, config, validation, analysis, optional SHAP/Quadrant, bootstrap, effect sizes, segment comparison, elastic net, NCA, dominance, GAM, executive summary, output, HTML report |
| `01_config.R` | 749 | Loads and validates Excel-based configuration | 90 | Reads 6 sheets (Settings, Variables, Segments, StatedImportance, CustomSlides, Insights); normalises column names; applies defaults; returns structured config list |
| `02_term_mapping.R` | 495 | Mixed predictor handling (continuous + categorical variables) | 90 | Maps survey terms to analysis-ready columns; handles dummy expansion for categoricals |
| `02_validation.R` | 261 | Data validation (sample size, zero-variance columns) | 91 | Checks minimum N, detects degenerate predictors, returns TRS refusals |
| `03_analysis.R` | 997 | Core algorithms: correlation, regression, 5 importance methods | 93 | Pearson, Spearman, standardised beta, relative importance (Lindeman-Merenda-Gold), Shapley regression; handles missing data, multicollinearity |
| `04_output.R` | 483 | Excel workbook generation | 85 | Creates formatted multi-sheet `.xlsx`; **v10.4 gap: does not yet write Elastic Net, NCA, Dominance, GAM sheets** |
| `05_bootstrap.R` | 524 | Bootstrap confidence intervals (v10.3) | 90 | BCa and percentile methods; configurable replications (min 100); handles weighted data |
| `06_effect_size.R` | 495 | Effect-size interpretation (v10.3) | 90 | Cohen's d, confidence intervals on effect sizes; magnitude labels (small/medium/large) |
| `07_segment_comparison.R` | 610 | Cross-segment driver importance comparison (v10.3) | 88 | Runs analysis per segment, aligns results, flags divergent drivers |
| `08_executive_summary.R` | 907 | Plain-English narrative findings (v10.3) | 88 | Template-based text generation; identifies top drivers, at-risk areas, segment differences |
| `09_elastic_net.R` | 185 | Elastic Net regularized regression (v10.4) | 89 | glmnet with CV; zero-variance guard; lambda.1se and lambda.min; handles weighted data |
| `10_nca.R` | 185 | Necessary Condition Analysis (v10.4) | 88 | NCA package; CE-FDH method; bottleneck table with API validation; identifies hygiene factors |
| `11_dominance.R` | 177 | Dominance Analysis (v10.4) | 89 | domir package; general/conditional/complete dominance; closure-safe weight handling; top-15 driver limit |
| `12_gam.R` | 194 | GAM nonlinear effects (v10.4) | 89 | mgcv with REML; auto-reduces k when sample too small; classifies nonlinearity shape |

### SHAP Submodule -- `R/kda_shap/`

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `shap_model.R` | 203 | XGBoost model building | 87 | Hyperparameter defaults, early stopping, handles categorical encoding |
| `shap_calculate.R` | 273 | SHAP value computation | 86 | Wraps `shapr`/`treeshap`; aggregates to mean |SHAP| per feature |
| `shap_visualize.R` | 427 | Beeswarm, waterfall, and dependence plots | 85 | ggplot2-based; colour-coded by feature value; supports segment overlay |
| `shap_segment.R` | 254 | Per-segment SHAP analysis | 86 | Runs SHAP pipeline within each segment; aligns feature ordering |
| `shap_interaction.R` | 212 | Feature interaction detection | 85 | SHAP interaction values; flags top-N interactions |
| `shap_export.R` | 323 | SHAP results to Excel | 88 | Multi-sheet export with summary, raw values, and plot metadata |

### SHAP Orchestrator -- `R/kda_methods/`

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `method_shap.R` | 382 | SHAP pipeline orchestrator | 87 | Coordinates model build, SHAP calc, visualisation, segment, interaction, export; configurable `on_fail` policy (warn vs refuse) |

### Quadrant / IPA Submodule -- `R/kda_quadrant/`

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `quadrant_main.R` | 270 | Quadrant pipeline orchestration | 88 | Coordinates data prep, calculation, plotting, comparison, export |
| `quadrant_data_prep.R` | 444 | Data normalisation for quadrant analysis | 87 | Scales importance and performance to 0-100; handles missing segments |
| `quadrant_calculate.R` | 328 | Quadrant classification logic | 88 | Assigns drivers to quadrants (Concentrate Here, Keep Up, Low Priority, Possible Overkill) based on configurable thresholds |
| `quadrant_plot.R` | 468 | SVG/ggplot2 quadrant charts | 86 | Labelled scatter with quadrant shading; handles overlapping labels |
| `quadrant_comparison.R` | 269 | Cross-segment quadrant analysis | 86 | Compares quadrant assignments across segments; flags movers |
| `quadrant_export.R` | 293 | Quadrant data to Excel | 88 | Multi-sheet export with classification, coordinates, and plot metadata |

### Configuration & Validation -- `lib/`

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `generate_config_templates.R` | 832 | Professional Excel template generator | 90 | Creates pre-formatted config workbooks with validation dropdowns, instructions, and example data |
| `validation/preflight_validators.R` | 1,023 | 14 cross-referential preflight checks | 90 | Validates config-to-data consistency: column existence, scale ranges, segment definitions, predictor overlap, outcome validity. **Untested** |

### HTML Report R Files -- `lib/html_report/`

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `00_html_guard.R` | 112 | Input validation for HTML report generation | 88 | Guards report inputs; checks result object structure |
| `01_data_transformer.R` | 781 | Transforms analysis results for HTML rendering | 87 | Reshapes, ranks, and annotates data; passes through v10.4 results with `has_*` flags |
| `02_table_builder.R` | 953 | Builds 9+ HTML table types | 86 | Driver rankings, correlation matrices, bootstrap CIs, segment comparisons, effect sizes; inline styling |
| `03_page_builder.R` | 3,748 | CSS, page layout, section assembly, insight areas | 83 | **Largest file in module.** 14 section builders; v10.4 sections (elastic net, NCA, dominance, GAM); config-driven insight pre-population with base64 image support. Candidate for future decomposition |
| `04_html_writer.R` | 112 | Atomic HTML file writing | 90 | Writes final HTML string to disk; ensures atomic write (temp + rename) |
| `05_chart_builder.R` | 758 | 7 SVG chart types | 86 | Bar, grouped bar, horizontal bar, lollipop, heatmap, radar, bootstrap CI; inline SVG with viewBox scaling |
| `06_quadrant_section.R` | 640 | SVG quadrant plot embedded in HTML report | 85 | Standalone SVG quadrant with interactive legend toggles; coordinates with JS navigation |
| `99_html_report_main.R` | 397 | HTML report orchestrator | 88 | Coordinates guard, transform, tables, charts, quadrant, page build, write |

### JavaScript -- `lib/html_report/js/`

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `kd_utils.js` | 186 | DOM manipulation, string helpers, localStorage utilities | 88 | Shared utility namespace; no global pollution |
| `kd_navigation.js` | 428 | Sticky navigation bar, section scrolling, active-section tracking | 87 | Scroll-spy with debounce; smooth-scroll to sections; responsive collapse |
| `kd_table_export.js` | 45 | Table export to clipboard | 88 | CSV clipboard export for individual tables |
| `kd_pinned_views.js` | 676 | Pin and restore analysis snapshots | 86 | Serialises visible state to localStorage; restore with visual diff indicator |
| `kd_slide_export.js` | 670 | 1280x720 PNG slide export | 85 | html2canvas-based capture; adds title bar and branding; download trigger |

### Test Suite -- `tests/testthat/`

| File | Lines | Tests | Notes |
|------|------:|------:|-------|
| `test_config.R` | 265 | 18 | Config loading, sheet validation, settings parsing |
| `test_guard.R` | 225 | 15 | TRS guard layer, refusal codes, edge cases |
| `test_core_importance.R` | 380 | 28 | 5 importance methods, weighted data, rankings |
| `test_edge_cases.R` | 398 | 30 | Missing data, zero variance, single driver, negative correlations |
| `test_effect_size.R` | 210 | 14 | Cohen's d, classification, TRS refusals for invalid input |
| `test_bootstrap.R` | 310 | 22 | BCa/percentile, weighted, minimum iterations guard |
| `test_segment_comparison.R` | 285 | 20 | Multi-segment analysis, alignment, classification |
| `test_executive_summary.R` | 320 | 24 | Narrative generation, template interpolation |
| `test_quadrant.R` | 275 | 18 | IPA classification, threshold methods, normalization |
| `test_html_report.R` | 350 | 25 | Data transformer, table builder, guard, full report gen |
| `test_term_mapping.R` | 180 | 12 | Continuous/categorical/ordinal mapping, dummy expansion |
| `test_integration.R` | 520 | 38 | End-to-end pipeline, bootstrap, HTML report, mixed predictors |
| `test_v104_features.R` | 430 | 41 | Elastic Net, NCA, Dominance, GAM with edge cases |
| `test_bug_fixes.R` | 150 | 8 | Regression tests for BUG-2 through BUG-8 |

### Test Fixtures -- `tests/fixtures/`

| File | Purpose |
|------|---------|
| `generate_test_data.R` | Synthetic data generator with v10.4 mock results (elastic net, NCA, dominance, GAM) |

### Config Templates -- `docs/templates/`

| File | Sheets | Purpose |
|------|--------|---------|
| `KeyDriver_Config_Template.xlsx` | 6 | Production template with v10.4 settings, CustomSlides, and Insights sheets |

### Demo -- `examples/keydriver/demo_showcase/`

| File | Purpose |
|------|---------|
| `create_demo_config.R` | Generates demo Excel config with all 6 sheets including example insights |
| `generate_demo_data.R` | Creates synthetic 800-respondent telecom survey dataset |
| `run_demo.R` | End-to-end demo runner with all 18 analysis steps |
| `README.md` | Demo documentation with v10.4 feature table |

---

## Architecture Diagram

```
                         run_keydriver_gui.R (Shiny + withProgress)
                                  |
                                  v
                            00_main.R
                       (18-step pipeline)
                                  |
          +-------------------+---+---+-----------------+
          |                   |       |                 |
          v                   v       v                 v
     00_guard.R          01_config.R  |       lib/generate_config_templates.R
     (TRS v1.1)          (6 sheets)   |       (template generator)
                                      |
                                      v
                    +---------+-------+--------+
                    |         |                |
                    v         v                v
           02_validation.R  02_term_mapping.R  lib/validation/
           (data checks)    (predictor map)    preflight_validators.R
                    |         |                (14 cross-ref checks)
                    +---------+
                         |
                         v
                    03_analysis.R
               (5 importance methods)
              /          |          \
             /           |           \
            v            v            v
    [Pearson]    [Spearman]    [Std. Regression]
    [Rel. Importance]         [Shapley Regression]
                         |
         +-------+-------+-------+-------+
         |       |       |       |       |
         v       v       v       v       v
  kda_methods/ kda_quad/ 05_boot  06_eff  07_seg
  method_shap  quad_main 05_boot  06_eff  07_seg
         |       |       |       |       |
         v       |       v       v       v
  R/kda_shap/   |  08_executive_summary.R
  (6 files)     |  (plain-English narrative)
         |       |       |
         +---+---+       |
             |           |
             v           v
        09_elastic_net.R (v10.4)
        10_nca.R         (v10.4)
        11_dominance.R   (v10.4)
        12_gam.R         (v10.4)
             |
             v
        04_output.R
        (Excel .xlsx)
             |
             v
      lib/html_report/
      99_html_report_main.R
         |
         +-- 00_html_guard.R
         +-- 01_data_transformer.R
         +-- 02_table_builder.R  (9+ table types)
         +-- 03_page_builder.R   (CSS + layout + insights, 3748 lines)
         +-- 04_html_writer.R    (atomic write)
         +-- 05_chart_builder.R  (7 SVG chart types)
         +-- 06_quadrant_section.R (SVG quadrant)
              |
              +-- js/kd_utils.js
              +-- js/kd_navigation.js
              +-- js/kd_table_export.js
              +-- js/kd_pinned_views.js
              +-- js/kd_slide_export.js
```

---

## v10.4 Changelog (2026-03-20)

### New Features
- **Elastic Net** (`09_elastic_net.R`): Regularized regression via glmnet with CV lambda selection
- **NCA** (`10_nca.R`): Necessary Condition Analysis identifying hygiene factors
- **Dominance Analysis** (`11_dominance.R`): Budescu general/conditional/complete dominance
- **GAM** (`12_gam.R`): Nonlinear effect detection with auto-adaptive basis dimension
- **Insights sheet**: Config-driven pre-populated insights with base64 image support
- **CustomSlides sheet**: Qualitative commentary slides for HTML report pinned views
- **Progress bar**: Shiny GUI now shows `withProgress()` during analysis

### Bug Fixes (10 bugs fixed)
- **BUG-1**: `invisible()` return in `validate_stated_importance_sheet()` caused downstream data loss
- **BUG-2**: NCA bottleneck table API mismatch caused silent crash
- **BUG-3**: Elastic Net NaN from zero-variance columns after scaling
- **BUG-4**: GAM `k` exceeding sample size caused mgcv failure
- **BUG-5**: Dominance analysis closure didn't capture `weight_var` in local scope
- **BUG-6**: Division by zero when general dominance sums to ~0
- **BUG-7**: CustomSlides error handling inconsistency
- **BUG-8**: HTML report v10.4 sections failed silently with no console logging
- **BUG-9**: `test_path()` resolution failure in all test files when run via `test_file()`
- **BUG-10**: Bootstrap integration test always skipped (n_bootstrap=10 < guard minimum 100)

### Known Gaps
- `04_output.R` does not yet write v10.4 method results (Elastic Net, NCA, Dominance, GAM) to Excel
- SHAP submodule (6 files) has zero test coverage
- Preflight validators (14 checks) have zero test coverage
- HTML report builders (page, chart, quadrant) have minimal test coverage
- Insight text not sanitized for HTML injection

---

## Quality Scoring Criteria

Each file is scored on a 0-100 scale across five dimensions. The per-file
quality score is the weighted average of these dimensions.

| Dimension | Weight | What It Measures |
|-----------|-------:|------------------|
| **Correctness** | 30% | Does the code produce accurate results? Are edge cases handled? Are statistical methods implemented faithfully? |
| **TRS Compliance** | 20% | Does the code use structured refusals (never `stop()`)? Are error messages specific, actionable, and console-visible? Does it follow the guard-then-process pattern? |
| **Maintainability** | 20% | Is the code readable? Are functions under 100 lines? Are variable names clear? Is the structure consistent with the module pattern? |
| **Test Coverage** | 15% | Are there unit tests, integration tests, edge-case tests, and golden-file tests? Is coverage above 80%? |
| **Documentation** | 15% | Does every exported function have Roxygen2 docs? Are parameters, return values, and examples documented? |

### Score Bands

| Band | Range | Meaning |
|------|------:|---------|
| Excellent | 93-100 | Production-grade, comprehensive tests, exemplary documentation |
| Strong | 88-92 | Production-ready, good coverage, minor improvements possible |
| Good | 82-87 | Functional and reliable, some areas could be tightened |
| Adequate | 70-81 | Works correctly but needs attention on tests or docs |
| Needs Work | <70 | Significant gaps in one or more dimensions |

### Module-Wide Quality Summary

| Component | Score | Notes |
|-----------|------:|-------|
| Guard layer (`00_guard.R`) | 92 | TRS v1.1 compliant, comprehensive validation |
| Core analysis (`03_analysis.R`) | 93 | Five methods, well-validated against reference implementations |
| v10.4 methods (`09-12_*.R`) | 89 | Well-implemented; proper guards; weighted data support |
| SHAP submodule (`R/kda_shap/`) | 85 | Optional subsystem; configurable `on_fail` policy; **untested** |
| Quadrant submodule (`R/kda_quadrant/`) | 87 | Well-decomposed; clean separation of concerns |
| Bootstrap / Effect Size / Segment | 90 | Solid test coverage; BCa method with guard minimum |
| Executive summary | 88 | Complex narrative generation; template-driven |
| Excel output (`04_output.R`) | 85 | **Missing v10.4 method sheets** |
| HTML report R files | 84 | Feature-rich; insights support; `03_page_builder.R` is large (3748 lines) |
| JavaScript | 87 | Clean namespacing; no global pollution; good export workflow |
| Config & validation | 90 | 6 sheets; 14 preflight checks; professional template generation |
| Test suite | 85 | 711 assertions, 0 failures; v10.4 covered; gaps in SHAP/HTML/validators |

**Overall Module Quality: 87/100 (Good → Strong)**

### Path to 95+

| Action | Impact |
|--------|--------|
| Add v10.4 Excel output sheets to `04_output.R` | +2 |
| Add SHAP submodule tests (30+ functions) | +2 |
| Add preflight validator tests (14 checks) | +1 |
| Add HTML builder unit tests | +1 |
| Add insight sanitization | +1 |
| Fix version banner in `00_main.R` | +0.5 |
| Decompose `03_page_builder.R` (3748 lines) | +0.5 |

---

*Generated for Turas Analytics Platform v10.4 -- The Research LampPost (Pty) Ltd*
