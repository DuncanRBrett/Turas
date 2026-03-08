# Tracker Module - Script Inventory

> Last updated: 2026-03-08

## Overview

The Tracker module provides longitudinal tracking analysis for multi-wave survey studies. It supports wave-over-wave trend analysis, significance testing, NPS tracking, banner subgroup analysis, and both Excel and HTML report output.

## Script Inventory

| File | Lines | Purpose | Status | Quality |
|------|-------|---------|--------|---------|
| `run_tracker.R` | 790 | Main 8-step pipeline | Active | 4/5 |
| `run_tracker_gui.R` | 716 | Shiny GUI wrapper | Active | 4/5 |
| `lib/00_guard.R` | 787 | TRS v1.0 guard layer | Active | 5/5 |
| `lib/tracker_config_loader.R` | 572 | Config loading | Active | 4/5 |
| `lib/wave_loader.R` | 1238 | Wave data loading | Active | 4/5 |
| `lib/question_mapper.R` | 929 | Cross-wave question mapping | Active | 5/5 |
| `lib/validation_tracker.R` | 574 | 7-point validation suite | Active | 4/5 |
| `lib/metric_types.R` | 327 | Metric type constants | Active | 5/5 |
| `lib/constants.R` | 102 | Statistical constants | Active | 5/5 |
| `lib/statistical_core.R` | 553 | Core statistics | Active | 5/5 |
| `lib/trend_calculator.R` | 1508 | Trend orchestration | Active | 4/5 |
| `lib/trend_changes.R` | 298 | Wave-over-wave changes | Active | 4/5 |
| `lib/trend_significance.R` | 418 | Significance testing | Active | 5/5 |
| `lib/banner_trends.R` | 462 | Banner segment calculation | Active | 4/5 |
| `lib/tracker_output.R` | 2282 | Main Excel output | Active | 4/5 |
| `lib/tracker_dashboard_reports.R` | 1325 | Dashboard/sig matrix | Active | 4/5 |
| `lib/tracking_crosstab_engine.R` | 701 | Crosstab calculation | Active | 4/5 |
| `lib/tracking_crosstab_excel.R` | 855 | Crosstab Excel export | Active | 4/5 |
| `lib/output_formatting.R` | 92 | Formatting helpers | Active | 4/5 |
| `lib/formatting_utils.R` | 83 | String formatting | Active | 4/5 |
| `lib/generate_config_templates.R` | NEW | Professional templates | Active | 5/5 |
| `lib/validation/preflight_validators.R` | NEW | Pre-flight checks | Active | 5/5 |
| `lib/html_report/00_html_guard.R` | 102 | HTML guard | Active | 4/5 |
| `lib/html_report/01_data_transformer.R` | 332 | HTML data transform | Active | 4/5 |
| `lib/html_report/02_table_builder.R` | 347 | HTML tables | Active | 4/5 |
| `lib/html_report/03_page_builder.R` | 1865 | HTML page structure | Active | 4/5 |
| `lib/html_report/04_html_writer.R` | 102 | HTML file output | Active | 4/5 |
| `lib/html_report/05_chart_builder.R` | 519 | SVG charts | Active | 4/5 |
| `lib/html_report/99_html_report_main.R` | 106 | HTML orchestration | Active | 4/5 |
