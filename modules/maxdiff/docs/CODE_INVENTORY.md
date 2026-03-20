# MaxDiff Module — Code Inventory

**Version:** 11.1 | **Date:** March 2026 | **Platform:** Turas Analytics

---

## Aggregate Metrics

| Metric | Value |
|--------|-------|
| **Total code lines** | 16,240 (14,043 R + 2,197 JS) |
| **Total functions** | 296 (220 R + 76 JS) |
| **R script files** | 23 |
| **JS modules** | 5 |
| **Test files** | 12 testthat + 3 infrastructure |
| **Test blocks** | ~120 |

---

## R/ — Core Analysis (14 files, 10,519 lines, 149 functions)

| File | Lines | Funcs | Version | Key Functions | Dependencies |
|------|------:|------:|---------|---------------|-------------|
| `00_guard.R` | 592 | 23 | 1.0 | `maxdiff_refuse()`, `validate_maxdiff_config()`, `validate_maxdiff_items()`, `validate_maxdiff_design()`, `validate_design_balance()` | sources `shared/lib/trs_refusal.R` |
| `00_main.R` | 1,079 | 12 | 11.1 | `run_maxdiff()`, `run_maxdiff_analysis_mode()`, `run_maxdiff_design_mode()`, `quick_maxdiff()`, `get_script_dir()` | openxlsx, survival, ggplot2 |
| `01_config.R` | 1,189 | 13 | 11.1 | `load_maxdiff_config()`, `parse_yes_no()`, `safe_numeric()`, `safe_integer()` | openxlsx:: |
| `02_validation.R` | 617 | 5 | 11.1 | `validate_design()`, `compute_pair_frequencies()`, `estimate_d_efficiency()`, `validate_survey_data()`, `validate_maxdiff_weights()` | — |
| `03_data.R` | 680 | 7 | 11.1 | `load_survey_data()`, `load_design_file()`, `build_maxdiff_long()`, `validate_filter_expression()`, `compute_study_summary()` | openxlsx::, tools:: |
| `04_design.R` | 821 | 11 | 11.1 | `generate_maxdiff_design()`, `generate_balanced_design()`, `generate_optimal_design()`, `compute_design_diagnostics()` | AlgDesign:: (optional) |
| `05_counts.R` | 334 | 4 | 11.1 | `compute_maxdiff_counts()`, `compute_respondent_counts()`, `compute_count_standard_errors()`, `add_count_confidence_intervals()` | — |
| `06_logit.R` | 459 | 5 | 11.1 | `fit_aggregate_logit()`, `prepare_logit_data()`, `extract_logit_utilities()`, `fit_simple_logit()` | survival:: (clogit, strata, Surv, coxph) |
| `07_hb.R` | 966 | 10 | 11.1 | `fit_hb_model()`, `prepare_stan_data()`, `fit_approximate_hb()`, `extract_hb_results()`, `check_cmdstanr_availability()` | cmdstanr:: (optional), parallel:: |
| `08_segments.R` | 612 | 6 | 11.1 | `compute_segment_scores()`, `compute_single_segment()`, `compare_segment_utilities()`, `validate_safe_expression()` | — |
| `09_output.R` | 1,297 | 14 | 11.2 | `generate_maxdiff_output()` + Excel formatting helpers | openxlsx:: |
| `10_charts.R` | 469 | 8 | 11.1 | `generate_maxdiff_charts()`, `create_utility_bar_chart()`, `create_best_worst_chart()`, `create_segment_chart()` | ggplot2:: (optional) |
| `11_turf.R` | 432 | 6 | 11.1 | `run_turf_analysis()`, `classify_appeal()`, `calculate_reach()`, `calculate_frequency()`, `compute_reach_sensitivity()` | — |
| `utils.R` | 972 | 25 | 11.1 | `log_message()`, `parse_yes_no()`, `rescale_utilities()`, `compute_preference_shares()`, `compute_head_to_head()`, `classify_item_discrimination()`, `process_anchor_data()` | tools::; sources `shared/lib/data_utils.R`, `shared/lib/logging_utils.R` |

---

## lib/html_report/ — HTML Report Pipeline (5 files, 2,561 lines, 48 functions)

| File | Lines | Funcs | Key Functions |
|------|------:|------:|---------------|
| `99_html_report_main.R` | 242 | 2 | `generate_maxdiff_html_report()`, `.md_load_report_submodules()` |
| `01_data_transformer.R` | 583 | 11 | `transform_maxdiff_for_html()`, `transform_summary_section()`, `transform_preferences_section()`, `transform_turf_section()`, `transform_methodology_section()` |
| `02_table_builder.R` | 317 | 6 | `build_preference_scores_table()`, `build_count_scores_table()`, `build_turf_table()`, `build_segment_table()`, `build_diagnostics_table()` |
| `03_page_builder.R` | 1,025 | 18 | `build_maxdiff_page()`, `build_md_header()`, `build_summary_panel()`, `build_preferences_panel()`, `build_turf_panel()`, `build_segments_panel()`, `build_methodology_panel()`, `build_md_css()`, `build_md_js()` |
| `04_chart_builder.R` | 394 | 11 | `build_preference_chart()`, `build_diverging_chart()`, `build_turf_chart()`, `build_segment_chart()`, `generate_md_palette()` |

Dependencies: base64enc:: or jsonlite:: (optional, for logo encoding), tools::

---

## lib/html_simulator/ — Interactive Simulator (4 R + 5 JS files)

### R files (963 lines, 23 functions)

| File | Lines | Funcs | Key Functions |
|------|------:|------:|---------------|
| `99_simulator_main.R` | 202 | 5 | `generate_maxdiff_html_simulator()`, `build_simulator_html_string()` |
| `00_simulator_guard.R` | 42 | 2 | `validate_simulator_inputs()`, `is_valid_hex_colour()` |
| `01_simulator_data_transformer.R` | 153 | 2 | `build_simulator_data()` |
| `02_simulator_page_builder.R` | 566 | 14 | `build_simulator_page()`, `build_simulator_css()`, `build_about_html()` |

Dependencies: jsonlite::toJSON()

### JS files (2,197 lines, 76 functions)

| File | Lines | Funcs | Module | Key Exports |
|------|------:|------:|--------|-------------|
| `simulator_engine.js` | 446 | 11 | SimEngine | `init`, `computeShares`, `headToHead`, `turfReach`, `turfOptimize`, `getDiagnostics` |
| `simulator_ui.js` | 491 | 15 | SimUI | Tab wiring, form handling, state management |
| `simulator_charts.js` | 407 | 16 | SimCharts | `renderShareBars`, `renderHeadToHead`, `renderTurfReach`, `renderDiagnostics` |
| `simulator_pins.js` | 472 | 19 | SimPins | `captureView`, `addCustomSlide`, `renderPins` |
| `simulator_export.js` | 381 | 15 | SimExport | `exportPNG`, `exportPinPNG`, `exportExcel` |

---

## External R Package Dependencies

| Package | Type | Used In |
|---------|------|---------|
| **openxlsx** | Required | config, data, output, templates |
| **survival** | Required | logit (clogit, strata, Surv, coxph) |
| **jsonlite** | Required | simulator page builder (toJSON); optional logo fallback in report |
| **ggplot2** | Optional | charts (PNG generation) |
| **cmdstanr** | Optional | HB estimation (full Bayesian) |
| **AlgDesign** | Optional | optimal experimental designs |
| **base64enc** | Optional | logo encoding in HTML report |
| **parallel** | Base R | HB (detectCores) |
| **tools** | Base R | file extension detection |

---

## Test Coverage

| Test File | Tests | Covers |
|-----------|------:|--------|
| `test_config.R` | 26 | Config parsing, validation, yes/no, safe_numeric |
| `test_data_reshape.R` | 16 | Filter security, valid filters, long format reshaping |
| `test_turf.R` | 16 | TURF reach, frequency, greedy selection, edge cases |
| `test_html_report.R` | 16 | All chart builders, table builders, panel assembly |
| `test_edge_cases.R` | 12 | Empty data, single item, NA handling |
| `test_logit.R` | 10 | Logit data prep, simple logit, anchor handling |
| `test_counts.R` | 8 | Count scores, bootstrap SE, CI calculation |
| `test_preference_shares.R` | 8 | Share computation, rescaling |
| `test_guard.R` | 7 | TRS refusals, input validation |
| `test_output.R` | 7 | Excel output styles, path generation |
| `test_html_simulator.R` | 5 | Simulator guard, data transformer |
| `test_design.R` | 2 | Design generation |

---

## Code Quality Checks

| Check | Status |
|-------|--------|
| `stop()` in production code | None (only in TRS plumbing in `00_guard.R`) |
| `library()` in production code | None (only in GUI launcher, examples, templates) |
| Hardcoded file paths | None |
| Version consistency | All 11.1 except `09_output.R` (11.2), simulator (2.0) |
| Namespace-qualified calls | All external packages use `pkg::fn()` |
| TRS compliance | Full — all errors return structured refusals |

---

## Known Duplications

| Item | Locations | Notes |
|------|-----------|-------|
| `%||%` operator | `01_data_transformer.R`, `01_simulator_data_transformer.R`, `02_simulator_page_builder.R` | Acceptable — independently sourced pipelines |
| `htmlEscape()` | `01_data_transformer.R`, `02_simulator_page_builder.R` | Acceptable — same reason |
| `escapeHtml()` (JS) | `simulator_charts.js`, `simulator_ui.js`, `simulator_pins.js` | Local copies in each module |
| Unsafe function blacklist | `03_data.R`, `08_segments.R` | Duplicate security lists for filter expression evaluation |

---

## File Structure

```
modules/maxdiff/
├── R/                          # Core analysis (14 files)
│   ├── 00_guard.R              # TRS guard layer
│   ├── 00_main.R               # Main orchestration
│   ├── 01_config.R             # Configuration loading
│   ├── 02_validation.R         # Design & data validation
│   ├── 03_data.R               # Data loading & reshaping
│   ├── 04_design.R             # Experimental design generation
│   ├── 05_counts.R             # Count-based scoring
│   ├── 06_logit.R              # Aggregate logit model
│   ├── 07_hb.R                 # Hierarchical Bayes estimation
│   ├── 08_segments.R           # Segment analysis
│   ├── 09_output.R             # Excel output generation
│   ├── 10_charts.R             # PNG chart generation
│   ├── 11_turf.R               # TURF portfolio optimization
│   └── utils.R                 # Shared utility functions
├── lib/
│   ├── html_report/            # HTML report pipeline (5 files)
│   │   ├── 01_data_transformer.R
│   │   ├── 02_table_builder.R
│   │   ├── 03_page_builder.R
│   │   ├── 04_chart_builder.R
│   │   └── 99_html_report_main.R
│   └── html_simulator/         # Interactive simulator (4 R + 5 JS)
│       ├── 00_simulator_guard.R
│       ├── 01_simulator_data_transformer.R
│       ├── 02_simulator_page_builder.R
│       ├── 99_simulator_main.R
│       └── js/
│           ├── simulator_engine.js
│           ├── simulator_charts.js
│           ├── simulator_ui.js
│           ├── simulator_pins.js
│           └── simulator_export.js
├── tests/testthat/             # 12 test files
├── templates/                  # Config template generator
├── docs/                       # Documentation (3 files)
│   ├── README.md
│   ├── TECHNICAL_REFERENCE.md
│   └── USER_MANUAL.md
└── run_maxdiff_gui.R           # Shiny GUI launcher
```

---

*Generated by Turas Code Inventory — March 2026*
