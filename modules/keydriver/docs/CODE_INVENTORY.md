# Key Driver Module -- Code Inventory

**Module:** `modules/keydriver/`
**Version:** 10.3
**Platform:** Turas Analytics (The Research LampPost)
**Last Updated:** 2026-03-08

---

## Overview

The Turas Key Driver module performs key driver analysis, identifying which
variables most strongly predict a continuous outcome. It supports five
classical importance methods (Pearson correlation, Spearman correlation,
standardized regression coefficients, relative importance, and Shapley
regression), plus optional SHAP-based machine-learning importance via XGBoost
and Importance-Performance Analysis (IPA/Quadrant charts).

Additional capabilities introduced in v10.3 include bootstrap confidence
intervals, Cohen's-d effect-size interpretation, cross-segment driver
comparison, and plain-English executive summaries. Results are delivered as
formatted Excel workbooks and interactive HTML reports with embedded SVG charts,
sticky navigation, pinned-view snapshots, and 1280x720 PNG slide export.

---

## Summary Statistics

| Metric                        | Value       |
|-------------------------------|-------------|
| Total R lines                 | ~19,483     |
| Total JS lines                | ~1,960      |
| **Grand total (R + JS)**      | **~21,443** |
| R source files                | 31          |
| JS source files               | 4           |
| **Total source files**        | **35**      |
| Submodules                    | 3 (SHAP, Quadrant, HTML Report) |
| Classical importance methods  | 5           |
| ML importance methods         | 1 (SHAP/XGBoost) |
| HTML chart types              | 6 SVG + quadrant |
| Largest file                  | `03_page_builder.R` (3,116 lines) |
| Smallest file                 | `00_html_guard.R` / `04_html_writer.R` (112 lines each) |

---

## Detailed File Inventory

### Root Entry Point

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `run_keydriver_gui.R` | 469 | Shiny GUI for interactive key driver analysis | 88 | Launches standalone Shiny app; wires GUI controls to core pipeline |

### Core Pipeline -- `R/`

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `00_guard.R` | 523 | TRS v1.1 guard layer; validates all inputs before analysis begins | 92 | Comprehensive type/range/existence checks; structured refusals with actionable messages |
| `00_main.R` | 965 | 11-step orchestration pipeline; single public entry point | 91 | Coordinates guard, config, validation, analysis, optional SHAP/Quadrant, bootstrap, effect sizes, segment comparison, executive summary, output |
| `01_config.R` | 704 | Loads and validates Excel-based configuration | 90 | Reads sheets, normalises column names, applies defaults, returns structured config list |
| `02_term_mapping.R` | 495 | Mixed predictor handling (continuous + categorical variables) | 90 | Maps survey terms to analysis-ready columns; handles dummy expansion for categoricals |
| `02_validation.R` | 261 | Data validation (sample size, zero-variance columns) | 91 | Checks minimum N, detects degenerate predictors, returns TRS refusals |
| `03_analysis.R` | 989 | Core algorithms: correlation, regression, 5 importance methods | 93 | Pearson, Spearman, standardised beta, relative importance (Lindeman-Merenda-Gold), Shapley regression; handles missing data, multicollinearity |
| `04_output.R` | 441 | Excel workbook generation | 88 | Creates formatted multi-sheet `.xlsx` with styles, conditional formatting, summary sheet |
| `05_bootstrap.R` | 524 | Bootstrap confidence intervals (v10.3) | 90 | BCa and percentile methods; configurable replications; handles weighted data |
| `06_effect_size.R` | 495 | Effect-size interpretation (v10.3) | 90 | Cohen's d, confidence intervals on effect sizes; magnitude labels (small/medium/large) |
| `07_segment_comparison.R` | 610 | Cross-segment driver importance comparison (v10.3) | 88 | Runs analysis per segment, aligns results, flags divergent drivers |
| `08_executive_summary.R` | 907 | Plain-English narrative findings (v10.3) | 88 | Template-based text generation; identifies top drivers, at-risk areas, segment differences |

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
| `validation/preflight_validators.R` | 1,023 | 14 cross-referential preflight checks | 92 | Validates config-to-data consistency: column existence, scale ranges, segment definitions, predictor overlap, outcome validity |

### HTML Report R Files -- `lib/html_report/`

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `00_html_guard.R` | 112 | Input validation for HTML report generation | 88 | Guards report inputs; checks result object structure |
| `01_data_transformer.R` | 781 | Transforms analysis results for HTML rendering | 87 | Reshapes, ranks, and annotates data for table/chart consumption |
| `02_table_builder.R` | 953 | Builds 9+ HTML table types | 86 | Driver rankings, correlation matrices, bootstrap CIs, segment comparisons, effect sizes; inline styling |
| `03_page_builder.R` | 3,116 | CSS, page layout, section assembly | 82 | **Largest file in module.** Generates full HTML document with embedded CSS, navigation, sections. Candidate for future decomposition |
| `04_html_writer.R` | 112 | Atomic HTML file writing | 90 | Writes final HTML string to disk; ensures atomic write (temp + rename) |
| `05_chart_builder.R` | 758 | 6 SVG chart types | 86 | Bar, grouped bar, horizontal bar, lollipop, heatmap, radar; inline SVG with viewBox scaling |
| `06_quadrant_section.R` | 640 | SVG quadrant plot embedded in HTML report | 85 | Standalone SVG quadrant with interactive legend toggles; coordinates with JS navigation |
| `99_html_report_main.R` | 397 | HTML report orchestrator | 88 | Coordinates guard, transform, tables, charts, quadrant, page build, write |

### JavaScript -- `lib/html_report/js/`

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `kd_utils.js` | 186 | DOM manipulation, string helpers, localStorage utilities | 88 | Shared utility namespace; no global pollution |
| `kd_navigation.js` | 428 | Sticky navigation bar, section scrolling, active-section tracking | 87 | Scroll-spy with debounce; smooth-scroll to sections; responsive collapse |
| `kd_pinned_views.js` | 676 | Pin and restore analysis snapshots | 86 | Serialises visible state to localStorage; restore with visual diff indicator |
| `kd_slide_export.js` | 670 | 1280x720 PNG slide export | 85 | html2canvas-based capture; adds title bar and branding; download trigger |

---

## Architecture Diagram

```
                         run_keydriver_gui.R (Shiny)
                                  |
                                  v
                            00_main.R
                       (11-step pipeline)
                                  |
          +-------------------+---+---+-----------------+
          |                   |       |                 |
          v                   v       v                 v
     00_guard.R          01_config.R  |       lib/generate_config_templates.R
     (TRS v1.1)          (Excel cfg)  |       (template generator)
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
         +---------------+---------------+
         |               |               |
         v               v               v
  R/kda_methods/    R/kda_quadrant/  05_bootstrap.R
  method_shap.R     quadrant_main.R  (BCa / percentile)
         |               |               |
         v               |               v
  R/kda_shap/            |          06_effect_size.R
  +- shap_model.R        |          (Cohen's d)
  +- shap_calculate.R    |               |
  +- shap_visualize.R    |               v
  +- shap_segment.R      |     07_segment_comparison.R
  +- shap_interaction.R  |     (cross-segment drivers)
  +- shap_export.R       |               |
         |               |               v
         +-------+-------+     08_executive_summary.R
                 |              (plain-English narrative)
                 v                        |
            04_output.R  <----------------+
            (Excel .xlsx)
                 |
                 v
      lib/html_report/
      99_html_report_main.R
         |
         +-- 00_html_guard.R
         +-- 01_data_transformer.R
         +-- 02_table_builder.R  (9+ table types)
         +-- 03_page_builder.R   (CSS + layout, 3116 lines)
         +-- 04_html_writer.R    (atomic write)
         +-- 05_chart_builder.R  (6 SVG chart types)
         +-- 06_quadrant_section.R (SVG quadrant)
              |
              +-- js/kd_utils.js
              +-- js/kd_navigation.js
              +-- js/kd_pinned_views.js
              +-- js/kd_slide_export.js
```

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

| Component | Score Range | Notes |
|-----------|------------|-------|
| Guard layer (`00_guard.R`) | 92 | TRS v1.1 compliant, comprehensive validation |
| Core analysis (`03_analysis.R`) | 90-93 | Five methods, well-validated against reference implementations |
| SHAP submodule (`R/kda_shap/`) | 85-88 | Optional subsystem; configurable `on_fail` policy |
| Quadrant submodule (`R/kda_quadrant/`) | 85-88 | Well-decomposed; clean separation of concerns |
| Bootstrap / Effect Size / Segment | 88-92 | New in v10.3; solid test coverage |
| Executive summary | 88 | Complex narrative generation; template-driven |
| HTML report R files | 82-88 | Feature-rich; `03_page_builder.R` is large (decomposition candidate) |
| JavaScript | 85-88 | Clean namespacing; no global pollution; good export workflow |
| Config & validation | 90-92 | 14 preflight checks; professional template generation |

**Overall Module Quality: 88/100 (Strong)**

---

*Generated for Turas Analytics Platform v10.3 -- The Research LampPost (Pty) Ltd*
