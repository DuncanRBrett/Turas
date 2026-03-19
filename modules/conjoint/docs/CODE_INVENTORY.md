# Conjoint Module - Code Inventory

**Version:** 3.1.0 **Generated:** 2026-03-19 **Module:** `modules/conjoint/`

------------------------------------------------------------------------

## 1. Module Overview

| Metric | Value |
|----|----|
| Core R files (`R/`) | 19 |
| HTML Report R files (`lib/html_report/`) | 7 |
| HTML Simulator R files (`lib/html_simulator/`) | 4 |
| JavaScript files (report) | 7 |
| JavaScript files (simulator) | 3 |
| **Total source files** | **40** |
| Total R functions | 232 |
| Total R lines of code | 15,424 |
| Total JS lines of code | 2,546 |
| Total HTML report R lines | 3,183 |
| Total HTML simulator R lines | 345 |
| **Grand total LOC** | **18,776** (across R + JS + HTML/R) |
| Test files | 14 |

------------------------------------------------------------------------

## 2. Core R Files

| File | Purpose | Functions | Lines | Key Dependencies |
|----|----|----|----|----|
| `00_main.R` | Entry point, module loader, orchestration | 4 | 636 | dplyr, openxlsx, mlogit, dfidx, survival |
| `00_guard.R` | TRS guard layer, validation gates, status helpers | 20 | 768 | shared/lib/trs_refusal.R |
| `01_config.R` | Config loading, autodetect heading, validation | 5 | 814 | openxlsx |
| `02_data.R` | Data loading, validation, statistics | 5 | 521 | dplyr, haven (optional) |
| `03_estimation.R` | MNL/clogit/rating estimation with fallback | 9 | 681 | mlogit, dfidx, survival |
| `04_utilities.R` | Part-worth utilities, importance, diagnostics | 7 | 540 | dplyr |
| `05_alchemer_import.R` | Alchemer CBC data transformer | 12 | 937 | openxlsx |
| `05_simulator.R` | Market share prediction, sensitivity, SOV, demand curves | 18 | 796 | (none beyond base R) |
| `06_interactions.R` | Config-driven interaction effects | 16 | 650 | mlogit |
| `07_output.R` | Excel workbook writer (8-11 sheets) | 14 | 1,231 | openxlsx |
| `08_market_simulator.R` | Interactive Excel simulator sheet | 8 | 572 | openxlsx |
| `09_none_handling.R` | None/opt-out detection and handling | 9 | 393 | dplyr |
| `10_best_worst.R` | Best-worst scaling estimation | 10 | 496 | (reuses 03_estimation) |
| `11_hierarchical_bayes.R` | Individual-level HB via bayesm MCMC | 10 | 847 | bayesm, coda (optional) |
| `12_config_template.R` | Branded Excel config template generator | 16 | 747 | openxlsx |
| `13_latent_class.R` | Latent class segmentation | 11 | 699 | bayesm |
| `14_willingness_to_pay.R` | WTP with delta-method CIs | 8 | 444 | (none beyond base R) |
| `15_product_optimizer.R` | Exhaustive/greedy product optimization | 5 | 343 | (none beyond base R) |
| `99_helpers.R` | Shared utilities, stats, formatting, logging | 29 | 587 | openxlsx |
| **Totals** |  | **206** | **12,702** |  |

------------------------------------------------------------------------

## 3. HTML Report Files (`lib/html_report/`)

| File | Purpose | Functions | Lines | Key Dependencies |
|----|----|----|----|----|
| `00_html_guard.R` | Input validation for HTML generation | 7 | 145 | (none) |
| `01_data_transformer.R` | Transform conjoint results to HTML data model | 10 | 264 | jsonlite |
| `02_table_builder.R` | Build HTML tables for each panel | 11 | 390 | (none) |
| `03_page_builder.R` | Full page assembly: CSS, header, panels, JS | 18 | 1,401 | (none) |
| `04_html_writer.R` | Write final HTML file to disk | 1 | 49 | (none) |
| `05_chart_builder.R` | Inline SVG chart generation | 14 | 665 | (none) |
| `99_html_report_main.R` | Top-level orchestrator for HTML report | 4 | 269 | jsonlite |
| **Totals** |  | **65** | **3,183** |  |

------------------------------------------------------------------------

## 4. HTML Simulator Files (`lib/html_simulator/`)

| File | Purpose | Functions | Lines |
|----|----|----|----|
| `00_simulator_guard.R` | Validate simulator inputs | 1 | 29 |
| `01_simulator_data_transformer.R` | Build simulator JSON data | 2 | 101 |
| `02_simulator_page_builder.R` | Assemble standalone simulator HTML | 3 | 141 |
| `99_simulator_main.R` | Top-level orchestrator | 1 | 74 |
| **Totals** |  | **7** | **345** |

------------------------------------------------------------------------

## 5. JavaScript Modules

### HTML Report JS (`lib/html_report/js/`)

| File | Purpose | Lines |
|----|----|----|
| `conjoint_charts.js` | Chart rendering (SVG toggle visibility) | 145 |
| `conjoint_export.js` | PNG/CSV export from report panels | 342 |
| `conjoint_navigation.js` | Tab switching, sidebar scroll, keyboard nav | 561 |
| `conjoint_pins.js` | Pin items to pinned-items panel | 370 |
| `simulator_charts.js` | Simulator bar chart rendering | 272 |
| `simulator_engine.js` | MNL share calculation in browser | 201 |
| `simulator_ui.js` | Simulator dropdowns, product config UI | 288 |
| **Total** |  | **2,179** |

### Standalone Simulator JS (`lib/html_simulator/js/`)

| File                  | Purpose                              | Lines   |
|-----------------------|--------------------------------------|---------|
| `simulator_charts.js` | Bar chart for standalone simulator   | 86      |
| `simulator_engine.js` | MNL engine for standalone simulator  | 104     |
| `simulator_ui.js`     | UI controls for standalone simulator | 177     |
| **Total**             |                                      | **367** |

------------------------------------------------------------------------

## 6. Complete Function Index

Alphabetical listing of all 232 R functions across the module.

| Function | File | Line | Description |
|----|----|----|----|
| `.build_all_charts` | `lib/html_report/99_html_report_main.R` | 216 | Generate all SVG charts for HTML report |
| `.build_all_tables` | `lib/html_report/99_html_report_main.R` | 152 | Generate all HTML tables for report |
| `.build_callout` | `lib/html_report/03_page_builder.R` | 1260 | Build a styled callout box |
| `.build_diagnostics_callouts` | `lib/html_report/03_page_builder.R` | 1272 | Build diagnostics insight callouts |
| `.build_export_bar` | `lib/html_report/03_page_builder.R` | 1324 | Build export button bar for a panel |
| `.build_sidebar_nav` | `lib/html_report/01_data_transformer.R` | 251 | Build sidebar navigation from utilities |
| `.build_simulator_data` | `lib/html_report/01_data_transformer.R` | 153 | Build simulator JSON data for embedded sim |
| `.build_summary` | `lib/html_report/01_data_transformer.R` | 80 | Build summary statistics object |
| `.chr_load_conjoint_submodules` | `lib/html_report/99_html_report_main.R` | 45 | Source HTML report submodule files |
| `.clean_settings_df` | `R/01_config.R` | 73 | Remove help/divider/empty rows from settings |
| `.extract_about` | `lib/html_report/01_data_transformer.R` | 233 | Extract about page data from config |
| `.extract_hb_data` | `lib/html_report/01_data_transformer.R` | 95 | Extract HB-specific data for HTML |
| `.extract_insights` | `lib/html_report/01_data_transformer.R` | 218 | Extract analyst insight text from config |
| `.extract_lc_data` | `lib/html_report/01_data_transformer.R` | 119 | Extract latent class data for HTML |
| `.extract_wtp_data` | `lib/html_report/01_data_transformer.R` | 133 | Extract WTP data for HTML |
| `.generate_class_palette` | `lib/html_report/05_chart_builder.R` | 595 | Generate colour palette for LC classes |
| `.get_conjoint_js_dir` | `lib/html_report/03_page_builder.R` | 1371 | Resolve JS directory path |
| `.get_conjoint_settings_definition` | `R/12_config_template.R` | 154 | Define all config settings with metadata |
| `.get_guard_dir` | `R/00_main.R` | 30 | Resolve guard file directory |
| `.get_method_template_overrides` | `R/12_config_template.R` | 699 | Get preset overrides for method templates |
| `.html_esc` | `lib/html_report/03_page_builder.R` | 1393 | Escape HTML special characters |
| `.html_escape` | `lib/html_report/02_table_builder.R` | 9 | Escape HTML entities in strings |
| `.load_hb_diagnostics` | `R/11_hierarchical_bayes.R` | 37 | Load shared HB diagnostics module |
| `.make_tpl_example_style` | `R/12_config_template.R` | 141 | Template example row style |
| `.make_tpl_header_style` | `R/12_config_template.R` | 49 | Template header style (navy) |
| `.make_tpl_help_style` | `R/12_config_template.R` | 91 | Template help text style |
| `.make_tpl_input_style` | `R/12_config_template.R` | 83 | Template input cell style (yellow) |
| `.make_tpl_locked_style` | `R/12_config_template.R` | 100 | Template locked/read-only cell style |
| `.make_tpl_optional_label_style` | `R/12_config_template.R` | 132 | Template optional label style (green) |
| `.make_tpl_optional_style` | `R/12_config_template.R` | 75 | Template optional row style |
| `.make_tpl_required_label_style` | `R/12_config_template.R` | 123 | Template required label style (red) |
| `.make_tpl_required_style` | `R/12_config_template.R` | 67 | Template required row style |
| `.make_tpl_section_style` | `R/12_config_template.R` | 58 | Template section header style |
| `.make_tpl_subtitle_style` | `R/12_config_template.R` | 116 | Template subtitle style |
| `.make_tpl_title_style` | `R/12_config_template.R` | 109 | Template title style |
| `.nice_tick_step` | `lib/html_report/05_chart_builder.R` | 397 | Calculate nice axis tick spacing |
| `.source_trs_infrastructure` | `R/00_main.R` | 51 | Source shared TRS run-state files |
| `.svg_axis_label` | `lib/html_report/05_chart_builder.R` | 28 | SVG axis label element |
| `.svg_gridline` | `lib/html_report/05_chart_builder.R` | 21 | SVG gridline element |
| `.svg_value_label` | `lib/html_report/05_chart_builder.R` | 35 | SVG value label element |
| `.svg_wrap` | `lib/html_report/05_chart_builder.R` | 14 | Wrap SVG content in container div |
| `.validate_colours` | `lib/html_report/00_html_guard.R` | 119 | Validate hex colour codes |
| `.validate_importance` | `lib/html_report/00_html_guard.R` | 78 | Validate importance data frame |
| `.validate_insights` | `lib/html_report/00_html_guard.R` | 133 | Validate insight text fields |
| `.validate_model_result` | `lib/html_report/00_html_guard.R` | 91 | Validate model result structure |
| `.validate_utilities` | `lib/html_report/00_html_guard.R` | 59 | Validate utilities data frame |
| `.validate_wtp` | `lib/html_report/00_html_guard.R` | 104 | Validate WTP data structure |
| `add_interactions_to_config` | `R/06_interactions.R` | 198 | Add interaction attributes to config |
| `analyze_interaction` | `R/06_interactions.R` | 302 | Analyze interaction coefficients |
| `assess_hit_rate` | `R/99_helpers.R` | 333 | Interpret hit rate quality |
| `assess_mcfadden_r2` | `R/99_helpers.R` | 302 | Interpret McFadden R-squared |
| `build_bic_chart` | `lib/html_report/05_chart_builder.R` | 220 | SVG BIC comparison chart for LC |
| `build_class_importance_chart` | `lib/html_report/05_chart_builder.R` | 506 | SVG grouped bar chart for class importance |
| `build_class_importance_table` | `lib/html_report/02_table_builder.R` | 290 | HTML table of class-level importance |
| `build_class_size_chart` | `lib/html_report/05_chart_builder.R` | 618 | SVG donut chart for class sizes |
| `build_conjoint_css` | `lib/html_report/03_page_builder.R` | 122 | Generate full CSS stylesheet |
| `build_conjoint_header` | `lib/html_report/03_page_builder.R` | 543 | Build HTML header with branding |
| `build_conjoint_js` | `lib/html_report/03_page_builder.R` | 1343 | Assemble all JS into script block |
| `build_conjoint_meta` | `lib/html_report/03_page_builder.R` | 99 | Build HTML meta tags |
| `build_conjoint_page` | `lib/html_report/03_page_builder.R` | 21 | Assemble complete HTML page |
| `build_conjoint_print_css` | `lib/html_report/03_page_builder.R` | 502 | Print-specific CSS rules |
| `build_convergence_table` | `lib/html_report/02_table_builder.R` | 137 | HTML table of HB convergence metrics |
| `build_demand_curve_chart` | `lib/html_report/05_chart_builder.R` | 415 | SVG demand curve line chart |
| `build_demand_table` | `lib/html_report/02_table_builder.R` | 258 | HTML table of demand curve data |
| `build_formula_with_interactions` | `R/06_interactions.R` | 521 | Build mlogit formula including interactions |
| `build_help_overlay` | `lib/html_report/03_page_builder.R` | 1205 | Build keyboard shortcut help overlay |
| `build_importance_chart` | `lib/html_report/05_chart_builder.R` | 55 | SVG horizontal bar chart for importance |
| `build_importance_table` | `lib/html_report/02_table_builder.R` | 22 | HTML table of attribute importance |
| `build_insight_area` | `lib/html_report/03_page_builder.R` | 1232 | Editable insight text area for a panel |
| `build_interaction_formula` | `R/06_interactions.R` | 273 | Build formula with interaction-only terms |
| `build_latent_class_result` | `R/13_latent_class.R` | 553 | Assemble LC result into standard model object |
| `build_lc_comparison_table` | `lib/html_report/02_table_builder.R` | 171 | HTML table of K-class BIC/AIC comparison |
| `build_mlogit_formula` | `R/03_estimation.R` | 359 | Build mlogit formula from config attributes |
| `build_model_fit_table` | `lib/html_report/02_table_builder.R` | 95 | HTML table of model fit statistics |
| `build_product_design_vector` | `R/05_simulator.R` | 571 | Build binary design vector for HB simulation |
| `build_report_tab_nav` | `lib/html_report/03_page_builder.R` | 613 | Build tab navigation bar |
| `build_respondent_quality_table` | `lib/html_report/02_table_builder.R` | 354 | HTML table of respondent RLH quality |
| `build_simulator_css` | `lib/html_simulator/02_simulator_page_builder.R` | 101 | CSS for standalone simulator |
| `build_simulator_data` | `lib/html_simulator/01_simulator_data_transformer.R` | 19 | Build standalone simulator data |
| `build_simulator_page` | `lib/html_simulator/02_simulator_page_builder.R` | 16 | Assemble standalone simulator HTML |
| `build_utilities_table` | `lib/html_report/02_table_builder.R` | 49 | HTML table of part-worth utilities |
| `build_utility_chart` | `lib/html_report/05_chart_builder.R` | 124 | SVG horizontal bar chart per attribute |
| `build_wtp_chart` | `lib/html_report/05_chart_builder.R` | 294 | SVG WTP bar chart with error bars |
| `build_wtp_table` | `lib/html_report/02_table_builder.R` | 203 | HTML table of WTP values |
| `build_about_panel` | `lib/html_report/03_page_builder.R` | 1081 | Build About/contact panel |
| `build_diagnostics_panel` | `lib/html_report/03_page_builder.R` | 791 | Build diagnostics panel |
| `build_lc_panel` | `lib/html_report/03_page_builder.R` | 869 | Build latent class panel |
| `build_overview_panel` | `lib/html_report/03_page_builder.R` | 655 | Build overview panel |
| `build_pinned_panel` | `lib/html_report/03_page_builder.R` | 1141 | Build pinned items panel |
| `build_simulator_panel` | `lib/html_report/03_page_builder.R` | 1011 | Build embedded simulator panel |
| `build_slides_panel` | `lib/html_report/03_page_builder.R` | 1173 | Build slides panel |
| `build_utilities_panel` | `lib/html_report/03_page_builder.R` | 709 | Build utilities panel |
| `build_wtp_panel` | `lib/html_report/03_page_builder.R` | 942 | Build WTP panel |
| `calculate_aggregate_wtp` | `R/14_willingness_to_pay.R` | 265 | WTP table with delta-method CIs |
| `calculate_attribute_diagnostics` | `R/04_utilities.R` | 515 | Per-attribute significance and range |
| `calculate_attribute_importance` | `R/04_utilities.R` | 188 | Relative importance from utility ranges |
| `calculate_attribute_importance_hb` | `R/11_hierarchical_bayes.R` | 722 | Individual-level importance, then average |
| `calculate_best_worst_diagnostics` | `R/10_best_worst.R` | 401 | BWS model fit statistics |
| `calculate_best_worst_utilities` | `R/10_best_worst.R` | 364 | Extract utilities from BWS model |
| `calculate_choice_fit_stats` | `R/04_utilities.R` | 295 | McFadden R-squared, AIC, BIC, hit rate |
| `calculate_ci` | `R/99_helpers.R` | 190 | Normal-approximation confidence interval |
| `calculate_data_statistics` | `R/02_data.R` | 475 | Respondent counts, selection rates |
| `calculate_entropy_r2` | `R/13_latent_class.R` | 496 | Classification quality metric for LC |
| `calculate_hit_rate` | `R/04_utilities.R` | 354 | Prediction accuracy for mlogit/clogit |
| `calculate_individual_wtp` | `R/14_willingness_to_pay.R` | 327 | Per-respondent WTP from HB betas |
| `calculate_lc_log_likelihood` | `R/13_latent_class.R` | 451 | Point-estimate log-likelihood for LC |
| `calculate_model_diagnostics` | `R/04_utilities.R` | 238 | Comprehensive model diagnostics |
| `calculate_none_diagnostics` | `R/09_none_handling.R` | 367 | None-option specific statistics |
| `calculate_product_utility` | `R/05_simulator.R` | 124 | Sum utilities for a product configuration |
| `calculate_respondent_rlh` | `R/11_hierarchical_bayes.R` | 532 | Root-likelihood quality per respondent |
| `calculate_utilities` | `R/04_utilities.R` | 25 | Extract part-worth utilities from model |
| `calculate_wtp` | `R/14_willingness_to_pay.R` | 49 | Main WTP calculation entry point |
| `check_hb_requirements` | `R/11_hierarchical_bayes.R` | 71 | Check bayesm/coda availability |
| `check_perfect_separation` | `R/99_helpers.R` | 361 | Detect always/never chosen levels |
| `clean_alchemer_level` | `R/05_alchemer_import.R` | 372 | Clean Alchemer compound level names |
| `clean_levels_with_config` | `R/05_alchemer_import.R` | 427 | Apply custom cleaning rules to levels |
| `compare_class_solutions` | `R/13_latent_class.R` | 523 | Add delta columns to LC comparison table |
| `compare_scenarios` | `R/05_simulator.R` | 331 | Compare multiple product scenarios |
| `compute_class_probabilities` | `R/13_latent_class.R` | 377 | Softmax on distances for class probs |
| `conjoint` | `R/00_main.R` | 636 | Alias for run_conjoint_analysis |
| `conjoint_determine_status` | `R/00_guard.R` | 694 | Final TRS status from guard state |
| `conjoint_guard_init` | `R/00_guard.R` | 148 | Initialize conjoint guard state |
| `conjoint_guard_summary` | `R/00_guard.R` | 217 | Summarize guard state |
| `conjoint_refuse` | `R/00_guard.R` | 95 | Module-specific TRS refusal |
| `conjoint_status_partial` | `R/00_guard.R` | 644 | Create PARTIAL status |
| `conjoint_status_pass` | `R/00_guard.R` | 626 | Create PASS status |
| `conjoint_status_refuse` | `R/00_guard.R` | 668 | Create REFUSE status |
| `conjoint_with_refusal_handler` | `R/00_guard.R` | 129 | Wrap expression with TRS error handling |
| `convert_best_worst_to_choice` | `R/10_best_worst.R` | 133 | Convert BWS to standard choice format |
| `create_best_worst_template` | `R/10_best_worst.R` | 456 | Generate empty BWS data template |
| `create_class_comparison_sheet` | `R/07_output.R` | 978 | Excel sheet: LC K-comparison |
| `create_class_membership_sheet` | `R/07_output.R` | 1191 | Excel sheet: respondent class membership |
| `create_class_profiles_sheet` | `R/07_output.R` | 1077 | Excel sheet: class-level utilities |
| `create_config_from_alchemer` | `R/05_alchemer_import.R` | 794 | Auto-generate config from Alchemer data |
| `create_configuration_sheet` | `R/07_output.R` | 539 | Excel sheet: study configuration |
| `create_data_summary_sheet` | `R/07_output.R` | 484 | Excel sheet: response statistics |
| `create_error` | `R/99_helpers.R` | 57 | Format error message |
| `create_hb_diagnostics_sheet` | `R/07_output.R` | 693 | Excel sheet: MCMC convergence |
| `create_header_style` | `R/99_helpers.R` | 390 | Standard Excel header style |
| `create_importance_sheet` | `R/07_output.R` | 421 | Excel sheet: attribute importance |
| `create_individual_utilities_sheet` | `R/07_output.R` | 577 | Excel sheet: per-respondent utilities |
| `create_interaction_terms` | `R/06_interactions.R` | 174 | Add interaction columns to data |
| `create_market_simulator_sheet` | `R/08_market_simulator.R` | 30 | Build interactive Excel simulator |
| `create_negative_style` | `R/99_helpers.R` | 415 | Red cell style for Excel |
| `create_none_rows` | `R/09_none_handling.R` | 267 | Create explicit none alternative rows |
| `create_positive_style` | `R/99_helpers.R` | 405 | Green cell style for Excel |
| `create_raw_coefficients_sheet` | `R/07_output.R` | 338 | Excel sheet: raw model coefficients |
| `create_respondent_quality_sheet` | `R/07_output.R` | 844 | Excel sheet: RLH quality scores |
| `create_simulator_data_sheet` | `R/08_market_simulator.R` | 499 | Hidden lookup sheet for simulator |
| `create_title_style` | `R/99_helpers.R` | 425 | Title cell style for Excel |
| `create_utilities_sheet` | `R/07_output.R` | 443 | Excel sheet: part-worth utilities |
| `create_utility_chart_data_sheet` | `R/07_output.R` | 180 | Excel sheet: chart-ready data |
| `create_warning` | `R/99_helpers.R` | 68 | Format warning message |
| `detect_none_option` | `R/09_none_handling.R` | 26 | Auto-detect none/opt-out in data |
| `escape_attr_for_formula` | `R/99_helpers.R` | 557 | Backtick-wrap special-char attributes |
| `escape_attr_for_regex` | `R/99_helpers.R` | 574 | Escape regex metacharacters in attr names |
| `estimate_auto_method` | `R/03_estimation.R` | 104 | Try mlogit then clogit fallback |
| `estimate_best_worst_model` | `R/10_best_worst.R` | 191 | Main BWS estimation entry point |
| `estimate_best_worst_sequential` | `R/10_best_worst.R` | 254 | Separate best/worst models, combine |
| `estimate_best_worst_simultaneous` | `R/10_best_worst.R` | 324 | Joint best-worst estimation |
| `estimate_choice_model` | `R/03_estimation.R` | 33 | Main estimation dispatcher |
| `estimate_hierarchical_bayes` | `R/11_hierarchical_bayes.R` | 221 | HB estimation via bayesm MCMC |
| `estimate_latent_class` | `R/13_latent_class.R` | 46 | Fit LC models for K=min..max |
| `estimate_mlogit_with_interactions` | `R/06_interactions.R` | 221 | mlogit with interaction terms |
| `estimate_price_coefficient` | `R/14_willingness_to_pay.R` | 126 | Regress utilities on numeric prices |
| `estimate_price_coefficient_se` | `R/14_willingness_to_pay.R` | 179 | SE of price coefficient |
| `estimate_rating_based_conjoint` | `R/03_estimation.R` | 616 | OLS for rating-based designs |
| `estimate_with_clogit` | `R/03_estimation.R` | 494 | clogit fallback estimation |
| `estimate_with_interactions` | `R/06_interactions.R` | 121 | Estimate model with interaction effects |
| `estimate_with_mlogit` | `R/03_estimation.R` | 160 | Primary mlogit estimation |
| `evaluate_product` | `R/15_product_optimizer.R` | 262 | Score a product against objective |
| `excel_to_product` | `R/05_simulator.R` | 469 | Convert Excel selections to product list |
| `extract_attribute_utilities` | `R/04_utilities.R` | 92 | Extract utilities for one attribute |
| `extract_clogit_results` | `R/03_estimation.R` | 566 | Standardize clogit output |
| `extract_hb_results` | `R/11_hierarchical_bayes.R` | 306 | Process bayesm output into standard form |
| `extract_hb_utilities` | `R/11_hierarchical_bayes.R` | 621 | Convert HB betas to utilities data frame |
| `extract_lc_solution` | `R/13_latent_class.R` | 205 | Extract solution for a given K |
| `extract_lc_utilities` | `R/13_latent_class.R` | 656 | Aggregate and class-level utilities |
| `extract_mlogit_results` | `R/03_estimation.R` | 422 | Standardize mlogit output |
| `extract_numeric_prices` | `R/14_willingness_to_pay.R` | 208 | Parse numeric values from price labels |
| `find_config_header_row` | `R/01_config.R` | 37 | Autodetect header row in config sheet |
| `fit_latent_class_k` | `R/13_latent_class.R` | 154 | Fit single K-class model |
| `format_interaction` | `R/06_interactions.R` | 641 | Format interaction term for display |
| `format_p_value` | `R/99_helpers.R` | 215 | Format p-value for display |
| `format_product` | `R/05_simulator.R` | 479 | Format product config as string |
| `generate_conjoint_config_template` | `R/12_config_template.R` | 281 | Generate branded Excel config template |
| `generate_conjoint_html_report` | `lib/html_report/99_html_report_main.R` | 93 | Main HTML report generator |
| `generate_conjoint_html_simulator` | `lib/html_simulator/99_simulator_main.R` | 36 | Main standalone simulator generator |
| `generate_demand_curve` | `R/05_simulator.R` | 765 | Sweep price levels for demand curve |
| `get_alchemer_attributes` | `R/05_alchemer_import.R` | 753 | Extract attribute summary from data |
| `get_attribute_levels` | `R/99_helpers.R` | 157 | Get levels for an attribute from config |
| `get_conjoint_version` | `R/99_helpers.R` | 585 | Return module version string |
| `get_interaction_terms` | `R/06_interactions.R` | 627 | Get interaction terms from model |
| `get_product_cost` | `R/15_product_optimizer.R` | 320 | Look up product cost from cost data |
| `get_product_price` | `R/15_product_optimizer.R` | 306 | Extract numeric price from product |
| `get_required_columns` | `R/02_data.R` | 459 | List required data columns |
| `get_significance_stars` | `R/99_helpers.R` | 227 | Convert p-value to significance stars |
| `guard_record_convergence` | `R/00_guard.R` | 197 | Record convergence status in guard |
| `guard_record_design_issue` | `R/00_guard.R` | 169 | Record design issue in guard |
| `guard_record_estimation_warning` | `R/00_guard.R` | 182 | Record estimation warning in guard |
| `handle_explicit_none` | `R/09_none_handling.R` | 149 | Flag explicit none rows |
| `handle_implicit_none` | `R/09_none_handling.R` | 182 | Add explicit none rows for implicit none |
| `handle_none_option` | `R/09_none_handling.R` | 115 | Main none-option handler |
| `has_interactions` | `R/06_interactions.R` | 617 | Check if model has interactions |
| `identify_none_rows` | `R/09_none_handling.R` | 231 | Find none rows by pattern matching |
| `import_alchemer_conjoint` | `R/05_alchemer_import.R` | 81 | Main Alchemer import function |
| `int2col` | `R/08_market_simulator.R` | 555 | Convert column number to Excel letter |
| `interpret_importance` | `R/99_helpers.R` | 284 | Interpret importance percentage |
| `interpret_interaction` | `R/06_interactions.R` | 437 | Interpret interaction effect magnitude |
| `interpret_utility` | `R/99_helpers.R` | 262 | Interpret utility direction and significance |
| `interpret_utility_magnitude` | `R/99_helpers.R` | 245 | Classify utility magnitude |
| `is_best_worst_model` | `R/10_best_worst.R` | 443 | Check if model is BWS |
| `likelihood_ratio_test` | `R/99_helpers.R` | 512 | LR test between two models |
| `load_alchemer_file` | `R/05_alchemer_import.R` | 194 | Load Excel/CSV Alchemer export |
| `load_conjoint_config` | `R/01_config.R` | 119 | Main config loader with autodetect |
| `load_conjoint_data` | `R/02_data.R` | 36 | Main data loader with source dispatch |
| `load_data_by_type` | `R/02_data.R` | 166 | Load data based on file extension |
| `log_verbose` | `R/99_helpers.R` | 445 | Conditional message printing |
| `normalize_score_column` | `R/05_alchemer_import.R` | 299 | Normalize Alchemer Score to 0/1 |
| `optimize_product` | `R/05_simulator.R` | 376 | Greedy product optimization (legacy) |
| `optimize_product_exhaustive` | `R/15_product_optimizer.R` | 48 | Exhaustive search optimization |
| `optimize_product_greedy` | `R/15_product_optimizer.R` | 160 | Multi-start greedy hill-climbing |
| `parse_interactions_from_config` | `R/06_interactions.R` | 475 | Parse interaction_terms config string |
| `parse_level_names` | `R/99_helpers.R` | 133 | Parse comma-separated level string |
| `predict_market_shares` | `R/05_simulator.R` | 32 | Aggregate market share prediction |
| `predict_market_shares_individual` | `R/05_simulator.R` | 505 | Individual-level share prediction (HB/LC) |
| `predict_shares_first_choice` | `R/05_simulator.R` | 183 | Deterministic first-choice rule |
| `predict_shares_logit` | `R/05_simulator.R` | 161 | Multinomial logit share prediction |
| `predict_shares_randomized_first_choice` | `R/05_simulator.R` | 204 | RFC with tie handling |
| `prepare_bayesm_data` | `R/11_hierarchical_bayes.R` | 110 | Convert to bayesm lgtdata format |
| `prepare_interaction_plot` | `R/06_interactions.R` | 400 | Prepare data for interaction plot |
| `prepare_mlogit_data` | `R/03_estimation.R` | 260 | Convert to dfidx mlogit format |
| `print_section` | `R/99_helpers.R` | 459 | Print formatted section header |
| `read_simulator_js` | `lib/html_simulator/02_simulator_page_builder.R` | 88 | Read JS file for embedding |
| `require_package` | `R/99_helpers.R` | 478 | Check and refuse if package missing |
| `resolve_config_path` | `R/01_config.R` | 779 | Resolve relative/absolute config paths |
| `run_conjoint_analysis` | `R/00_main.R` | 306 | Main entry point (public API) |
| `run_conjoint_analysis_impl` | `R/00_main.R` | 326 | Internal implementation |
| `run_hb_convergence_diagnostics` | `R/11_hierarchical_bayes.R` | 418 | Geweke test and ESS for MCMC |
| `run_interaction_analysis` | `R/06_interactions.R` | 558 | Config-driven interaction pipeline |
| `safe_logical` | `R/99_helpers.R` | 89 | Safe conversion to logical |
| `safe_numeric` | `R/99_helpers.R` | 115 | Safe conversion to numeric |
| `save_config_to_excel` | `R/05_alchemer_import.R` | 840 | Save config list to Excel |
| `sensitivity_one_way` | `R/05_simulator.R` | 237 | One-way attribute sensitivity analysis |
| `sensitivity_two_way` | `R/05_simulator.R` | 286 | Two-way attribute sensitivity analysis |
| `simulate_first_choice_individual` | `R/05_simulator.R` | 633 | Deterministic first choice per respondent |
| `simulate_logit_individual` | `R/05_simulator.R` | 651 | Softmax per respondent, then average |
| `simulate_rfc` | `R/05_simulator.R` | 600 | Randomized first choice with Gumbel error |
| `simulator_data_to_json` | `lib/html_report/01_data_transformer.R` | 207 | Serialize simulator data to JSON |
| `simulator_data_to_json` | `lib/html_simulator/01_simulator_data_transformer.R` | 84 | Serialize standalone simulator to JSON |
| `source_of_volume` | `R/05_simulator.R` | 692 | Share-shift analysis for new product |
| `specify_interactions` | `R/06_interactions.R` | 50 | Define interaction terms |
| `summarize_wtp_distribution` | `R/14_willingness_to_pay.R` | 401 | WTP percentiles across respondents |
| `test_alchemer_import` | `R/05_alchemer_import.R` | 890 | Quick smoke test for Alchemer import |
| `test_interaction_significance` | `R/06_interactions.R` | 362 | LR test for interaction significance |
| `transform_conjoint_for_html` | `lib/html_report/01_data_transformer.R` | 21 | Transform results to HTML data model |
| `validate_alchemer_columns` | `R/05_alchemer_import.R` | 246 | Check required Alchemer columns |
| `validate_alchemer_data` | `R/05_alchemer_import.R` | 479 | Comprehensive Alchemer data validation |
| `validate_alchemer_with_refusal` | `R/05_alchemer_import.R` | 692 | Validation wrapper with TRS refusal |
| `validate_best_worst_data` | `R/10_best_worst.R` | 40 | Validate BWS data format |
| `validate_config` | `R/01_config.R` | 527 | Validate settings and attributes |
| `validate_conjoint_attributes` | `R/00_guard.R` | 263 | Gate: attribute definitions |
| `validate_conjoint_config` | `R/00_guard.R` | 243 | Gate: config structure |
| `validate_conjoint_convergence` | `R/00_guard.R` | 356 | Gate: model convergence |
| `validate_conjoint_data` | `R/00_guard.R` | 396 | Gate: data sufficiency |
| `validate_conjoint_data` | `R/02_data.R` | 219 | Comprehensive data validation |
| `validate_conjoint_design` | `R/00_guard.R` | 323 | Gate: design matrix |
| `validate_conjoint_html_inputs` | `lib/html_report/00_html_guard.R` | 17 | Validate all HTML report inputs |
| `validate_hb_config` | `R/00_guard.R` | 426 | Gate: HB iteration/burn-in settings |
| `validate_hb_data` | `R/11_hierarchical_bayes.R` | 799 | Validate data for HB estimation |
| `validate_html_config` | `R/00_guard.R` | 543 | Gate: HTML colour codes |
| `validate_latent_class_config` | `R/00_guard.R` | 485 | Gate: LC min/max/criterion |
| `validate_none_choices` | `R/09_none_handling.R` | 304 | Validate choice integrity with none |
| `validate_simulator_inputs` | `lib/html_simulator/00_simulator_guard.R` | 7 | Validate standalone simulator inputs |
| `validate_wtp_config` | `R/00_guard.R` | 579 | Gate: WTP price attribute |
| `write_conjoint_html_report` | `lib/html_report/04_html_writer.R` | 13 | Write HTML string to file |
| `write_conjoint_output` | `R/07_output.R` | 40 | Main Excel output writer |
| `write_market_share_section` | `R/08_market_simulator.R` | 194 | Excel simulator: share calculations |
| `write_product_configuration` | `R/08_market_simulator.R` | 122 | Excel simulator: product dropdowns |
| `write_sensitivity_analysis` | `R/08_market_simulator.R` | 416 | Excel simulator: sensitivity section |
| `write_simulator_instructions` | `R/08_market_simulator.R` | 84 | Excel simulator: instructions header |
| `write_utilities_breakdown` | `R/08_market_simulator.R` | 315 | Excel simulator: utility decomposition |
| `zero_center_utilities` | `R/99_helpers.R` | 540 | Zero-center a utility vector |

------------------------------------------------------------------------

## 7. Package Dependency Matrix

| Package | 00_main | 01_config | 02_data | 03_estimation | 04_utilities | 05_alchemer | 05_simulator | 07_output | 08_market_sim | 11_hb | 12_template | 13_lc | 14_wtp | 99_helpers |
|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|
| **dplyr** | load | \- | use | \- | use | \- | \- | \- | \- | \- | \- | \- | \- | \- |
| **openxlsx** | load | use | \- | \- | \- | use | \- | use | use | \- | use | \- | \- | use |
| **mlogit** | load | \- | \- | use | \- | \- | \- | \- | \- | \- | \- | \- | \- | \- |
| **dfidx** | load | \- | \- | use | \- | \- | \- | \- | \- | \- | \- | \- | \- | \- |
| **survival** | load | \- | \- | use | \- | \- | \- | \- | \- | \- | \- | \- | \- | \- |
| **bayesm** | \- | \- | \- | \- | \- | \- | \- | \- | \- | use | \- | use | \- | \- |
| **coda** | \- | \- | \- | \- | \- | \- | \- | \- | \- | optional | \- | \- | \- | \- |
| **haven** | \- | \- | optional | \- | \- | \- | \- | \- | \- | \- | \- | \- | \- | \- |
| **jsonlite** | \- | \- | \- | \- | \- | \- | \- | \- | \- | \- | \- | \- | \- | \- |

**jsonlite** is used by `lib/html_report/01_data_transformer.R` and `lib/html_simulator/01_simulator_data_transformer.R` for JSON serialization.

------------------------------------------------------------------------

## 8. Test Coverage Map

| Test File | Lines | Covers |
|----|----|----|
| `tests/testthat/test_config.R` | \- | `01_config.R`: config loading, validation, autodetect |
| `tests/testthat/test_estimation.R` | \- | `03_estimation.R`: mlogit, clogit, auto, rating-based |
| `tests/testthat/test_utilities.R` | \- | `04_utilities.R`: utilities, importance, diagnostics |
| `tests/testthat/test_simulation.R` | \- | `05_simulator.R`: market shares, logit, first-choice, RFC |
| `tests/testthat/test_interactions.R` | \- | `06_interactions.R`: specify, estimate, analyze interactions |
| `tests/testthat/test_edge_cases.R` | \- | Cross-cutting: NA handling, empty data, single-level attrs |
| `tests/testthat/test_bws.R` | \- | `10_best_worst.R`: BWS validation, conversion, estimation |
| `tests/testthat/test_wtp.R` | \- | `14_willingness_to_pay.R`: price parsing, WTP, delta method |
| `tests/testthat/test_optimizer.R` | \- | `15_product_optimizer.R`: exhaustive, greedy, evaluation |
| `tests/testthat/test_html_report.R` | \- | `lib/html_report/`: HTML generation pipeline |
| `tests/testthat/test_html_simulator.R` | \- | `lib/html_simulator/`: standalone simulator |
| `tests/test_unit_tests.R` | \- | Standalone unit test runner (no testthat dependency) |
| `tests/test_integration.R` | \- | End-to-end: config -\> data -\> estimation -\> output |
| `tests/fixtures/synthetic_data/generate_conjoint_test_data.R` | \- | Synthetic data generators for all test scenarios |

**Notable gaps:** No dedicated test files for `05_alchemer_import.R`, `09_none_handling.R`, `11_hierarchical_bayes.R`, `12_config_template.R`, or `13_latent_class.R` (some are tested indirectly via integration tests).

------------------------------------------------------------------------

## 9. Architecture Flow

```         
Config Excel (.xlsx)
    |
    v
[01_config.R] load_conjoint_config()
    |-- Autodetect header row
    |-- Validate settings + attributes
    |-- Resolve file paths
    |
    v
[05_alchemer_import.R] (if data_source = "alchemer")
    |-- Transform Alchemer CBC format
    |-- Clean level names
    |-- Normalize Score column
    |
    v
[02_data.R] load_conjoint_data()
    |-- Load CSV/XLSX/SAV/DTA
    |-- [09_none_handling.R] detect & handle none option
    |-- Validate choice structure
    |-- Calculate data statistics
    |
    v
[03_estimation.R] estimate_choice_model()
    |-- auto: mlogit -> clogit fallback
    |-- hb: [11_hierarchical_bayes.R] bayesm MCMC
    |-- latent_class: [13_latent_class.R] K-class search
    |-- best_worst: [10_best_worst.R] exploded logit
    |-- rating: OLS regression
    |
    v
[04_utilities.R] calculate_utilities() + calculate_attribute_importance()
    |-- Extract part-worth utilities
    |-- Zero-center within attributes
    |-- Confidence intervals + p-values
    |-- McFadden R-squared + hit rate
    |
    v
[06_interactions.R] (optional, if interaction_terms configured)
    |-- Parse config, build formula
    |-- Estimate with interactions
    |-- LR test vs main-effects model
    |
    v
[14_willingness_to_pay.R] (optional, if wtp_price_attribute set)
    |-- Estimate price coefficient
    |-- Delta-method CIs for WTP
    |-- Individual-level WTP (HB)
    |
    v
[07_output.R] write_conjoint_output()          Excel Workbook (8-11 sheets)
    |-- Importance, Utilities, Model Fit
    |-- [08_market_simulator.R] interactive simulator sheet
    |-- HB: Individual Utilities, Diagnostics, Quality
    |-- LC: Class Comparison, Profiles, Membership
    |
    v
[lib/html_report/99_html_report_main.R]        HTML Analysis Report
    |-- [01_data_transformer.R] transform data model
    |-- [02_table_builder.R] build HTML tables
    |-- [05_chart_builder.R] build SVG charts
    |-- [03_page_builder.R] assemble full page
    |-- [04_html_writer.R] write to disk
    |-- js/: navigation, export, pins, charts, simulator
    |
    v
[lib/html_simulator/99_simulator_main.R]        Standalone HTML Simulator
    |-- [01_simulator_data_transformer.R] build JSON
    |-- [02_simulator_page_builder.R] assemble page
    |-- js/: engine, charts, ui
```
