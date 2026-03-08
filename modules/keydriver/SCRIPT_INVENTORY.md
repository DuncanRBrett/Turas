# Key Driver Analysis Module - Script Inventory

> Last updated: 2026-03-08

## Overview

The keydriver module provides production-ready key driver analysis including correlation, regression, relative importance, SHAP ML-based importance, Importance-Performance (quadrant) analysis, bootstrap confidence intervals, segment comparison, and executive summary generation.

## File Inventory

| File | Lines | Purpose | Status | Quality |
|------|------:|---------|--------|---------|
| R/00_guard.R | 523 | TRS v1.1 guard layer | Active | 5/5 |
| R/00_main.R | 965 | Main 11-step pipeline | Active | 4/5 |
| R/01_config.R | 704 | Config loading & validation | Active | 4/5 |
| R/02_term_mapping.R | 495 | Mixed predictor term mapping | Active | 5/5 |
| R/02_validation.R | 261 | Data validation | Active | 4/5 |
| R/03_analysis.R | 989 | Core algorithms (correlation, regression, importance) | Active | 5/5 |
| R/04_output.R | 441 | Excel workbook generation | Active | 4/5 |
| R/05_bootstrap.R | 524 | Bootstrap CI | Active | 4/5 |
| R/06_effect_size.R | 495 | Effect size interpretation | Active | 5/5 |
| R/07_segment_comparison.R | 610 | Segment analysis | Active | 4/5 |
| R/08_executive_summary.R | 907 | Narrative summary | Active | 4/5 |
| R/kda_methods/method_shap.R | 382 | SHAP orchestration | Active | 4/5 |
| R/kda_shap/shap_model.R | 203 | XGBoost model building | Active | 4/5 |
| R/kda_shap/shap_calculate.R | 273 | SHAP value extraction | Active | 5/5 |
| R/kda_shap/shap_visualize.R | 427 | SHAP visualizations | Active | 4/5 |
| R/kda_shap/shap_segment.R | 254 | Segment-level SHAP | Active | 4/5 |
| R/kda_shap/shap_interaction.R | 212 | Feature interactions | Active | 4/5 |
| R/kda_shap/shap_export.R | 323 | SHAP Excel export | Active | 4/5 |
| R/kda_quadrant/quadrant_main.R | 270 | Quadrant orchestration | Active | 4/5 |
| R/kda_quadrant/quadrant_data_prep.R | 444 | Quadrant data prep | Active | 4/5 |
| R/kda_quadrant/quadrant_calculate.R | 328 | Quadrant calculations | Active | 5/5 |
| R/kda_quadrant/quadrant_plot.R | 468 | Quadrant visualization | Active | 4/5 |
| R/kda_quadrant/quadrant_comparison.R | 269 | Segment comparison | Active | 4/5 |
| R/kda_quadrant/quadrant_export.R | 293 | Quadrant Excel export | Active | 4/5 |
| lib/generate_config_templates.R | NEW | Professional config templates | Active | 5/5 |
| lib/validation/preflight_validators.R | NEW | Pre-flight validation checks | Active | 5/5 |
| lib/html_report/00_html_guard.R | 112 | HTML validation | Active | 4/5 |
| lib/html_report/01_data_transformer.R | 781 | Data transformer | Active | 4/5 |
| lib/html_report/02_table_builder.R | 953 | HTML tables | Active | 4/5 |
| lib/html_report/03_page_builder.R | 3116 | Main HTML page | Active | 4/5 |
| lib/html_report/04_html_writer.R | 112 | HTML file I/O | Active | 4/5 |
| lib/html_report/05_chart_builder.R | 758 | SVG charts | Active | 4/5 |
| lib/html_report/06_quadrant_section.R | 640 | Quadrant HTML section | Active | 4/5 |
| lib/html_report/99_html_report_main.R | 397 | HTML orchestration | Active | 4/5 |
| run_keydriver_gui.R | - | Shiny GUI | Active | 4/5 |

## Architecture Notes

- **Pipeline:** The main entry point (`00_main.R`) orchestrates an 11-step pipeline from config loading through output generation.
- **Guard layer:** `00_guard.R` implements TRS v1.1 refusal system for all input validation.
- **SHAP subsystem:** Six files under `R/kda_shap/` handle XGBoost model building, SHAP value computation, visualization, segment-level analysis, interactions, and Excel export.
- **Quadrant subsystem:** Six files under `R/kda_quadrant/` handle Importance-Performance Analysis from data prep through visualization and export.
- **HTML report:** Eight files under `lib/html_report/` generate interactive HTML output with SVG charts and quadrant sections.
- **Config templates:** `lib/generate_config_templates.R` produces professional Excel config templates using the shared template infrastructure.
- **Pre-flight validation:** `lib/validation/preflight_validators.R` implements 14 cross-referential checks between config, variables, and data.
