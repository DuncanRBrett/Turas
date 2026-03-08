# Catdriver Module - Script Inventory

## Overview

The catdriver module performs categorical key driver analysis using ordinal, binary, and multinomial logistic regression. It identifies which categorical predictor variables (drivers) have the strongest influence on a categorical outcome variable, using SHAP values, marginal effects, and standard regression coefficients.

## Script Inventory

| File | Lines | Purpose | Status | Quality |
|------|------:|---------|--------|:-------:|
| R/00_main.R | 1230 | Main orchestration | Active | 4/5 |
| R/01_config.R | 705 | Config loading & validation | Active | 4/5 |
| R/02_validation.R | 651 | Data loading & validation | Active | 4/5 |
| R/03_preprocessing.R | 727 | Variable type detection & prep | Active | 4/5 |
| R/04_analysis.R | 378 | Analysis dispatch | Active | 5/5 |
| R/04a_ordinal.R | 537 | Ordinal logistic regression | Active | 5/5 |
| R/04b_multinomial.R | 247 | Multinomial logistic regression | Active | 4/5 |
| R/05_importance.R | 681 | Driver importance (SHAP, effects) | Active | 5/5 |
| R/06_output.R | 577 | Excel output generation | Active | 4/5 |
| R/06a_sheets_summary.R | 413 | Summary output sheets | Active | 4/5 |
| R/06b_sheets_detail.R | 384 | Detailed output sheets | Active | 4/5 |
| R/06c_sheets_subgroup.R | 278 | Subgroup comparison sheets | Active | 4/5 |
| R/07_utilities.R | 881 | General utilities | Active | 4/5 |
| R/08_guard.R | 368 | TRS guard framework | Active | 5/5 |
| R/08a_guards_hard.R | 579 | Hard error guards | Active | 5/5 |
| R/08b_guards_soft.R | 347 | Soft warning guards | Active | 4/5 |
| R/09_mapper.R | 533 | Design matrix term mapping | Active | 5/5 |
| R/10_missing.R | 441 | Missing data handling | Active | 4/5 |
| R/11_subgroup_comparison.R | 475 | Subgroup analysis | Active | 4/5 |
| lib/generate_config_templates.R | NEW | Professional templates | Active | 5/5 |
| lib/validation/preflight_validators.R | NEW | Pre-flight checks | Active | 5/5 |
| lib/html_report/00_html_guard.R | 109 | HTML validation | Active | 4/5 |
| lib/html_report/01_data_transformer.R | 328 | Data formatting | Active | 4/5 |
| lib/html_report/02_table_builder.R | 402 | HTML table construction | Active | 4/5 |
| lib/html_report/03_page_builder.R | 2345 | Page layout & charts | Active | 4/5 |
| lib/html_report/04_html_writer.R | 112 | File writing | Active | 4/5 |
| lib/html_report/05_chart_builder.R | 548 | Chart generation | Active | 4/5 |
| lib/html_report/06_comparison_report.R | 797 | Comparison views | Active | 4/5 |
| lib/html_report/07_unified_report.R | 866 | Unified layout | Active | 4/5 |
| lib/html_report/08_subgroup_report.R | 421 | Subgroup reports | Active | 4/5 |
| lib/html_report/99_html_report_main.R | 309 | HTML entry point | Active | 4/5 |
| create_config_template.R | 431 | Legacy template generator | Superseded | 3/5 |
| run_catdriver_gui.R | 904 | Shiny GUI interface | Active | 4/5 |

## Pipeline Flow

```
00_main.R
  |-> 01_config.R         Load & validate config (Settings, Variables, Driver_Settings)
  |-> 02_validation.R     Load & validate data file
  |-> lib/validation/     Pre-flight cross-referential checks
  |-> 03_preprocessing.R  Type detection, factor ordering, reference levels
  |-> 08_guard.R          TRS guard checks (hard + soft)
  |-> 10_missing.R        Missing data handling per driver strategy
  |-> 04_analysis.R       Dispatch to ordinal/multinomial/binary engine
  |   |-> 04a_ordinal.R   Ordinal logistic regression (clm)
  |   |-> 04b_multinomial.R  Multinomial logistic regression (nnet)
  |-> 09_mapper.R         Map design matrix terms back to driver names
  |-> 05_importance.R     SHAP values, marginal effects, importance ranking
  |-> 11_subgroup_comparison.R  Per-subgroup analysis (if configured)
  |-> 06_output.R         Excel workbook generation
  |   |-> 06a_sheets_summary.R  Summary & ranking sheets
  |   |-> 06b_sheets_detail.R   Per-driver detail sheets
  |   |-> 06c_sheets_subgroup.R Subgroup comparison sheets
  |-> lib/html_report/    HTML report generation (if configured)
      |-> 99_html_report_main.R  Entry point
      |-> 00_html_guard.R        Validate report inputs
      |-> 01_data_transformer.R  Format data for HTML
      |-> 02_table_builder.R     Build HTML tables
      |-> 03_page_builder.R      Assemble page layout
      |-> 05_chart_builder.R     Generate SVG charts
      |-> 04_html_writer.R       Write final HTML file
      |-> 06_comparison_report.R Comparison view layout
      |-> 07_unified_report.R    Unified report layout
      |-> 08_subgroup_report.R   Subgroup report layout
```

## Support Files

| File | Purpose | Status |
|------|---------|--------|
| lib/generate_config_templates.R | Professional Excel config template generator using shared infrastructure | Active |
| lib/validation/preflight_validators.R | 15 pre-flight cross-referential checks between config and data | Active |
| create_config_template.R | Legacy template generator (superseded by lib/generate_config_templates.R) | Superseded |
| run_catdriver_gui.R | Shiny GUI for interactive catdriver analysis | Active |

## Notes

- `create_config_template.R` is superseded by `lib/generate_config_templates.R` which uses the shared template infrastructure from `modules/shared/template_styles.R`.
- `lib/validation/preflight_validators.R` depends on `log_issue()` and `create_error_log()` from `modules/shared/lib/logging_utils.R`.
- The HTML report subsystem (lib/html_report/) is self-contained with its own guard, data transformation, and rendering pipeline.
- Quality scores reflect code maturity: 5/5 = production-hardened with comprehensive error handling; 4/5 = production-ready with good coverage; 3/5 = functional but needs modernisation.
