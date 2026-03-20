# Conjoint Module - Code Inventory

**Version:** 3.1.0
**Generated:** 2026-03-20
**Module:** `modules/conjoint/`

---

## Summary

| Metric | Value |
|---|---|
| Core R files (`R/`) | 20 |
| HTML Report R files (`lib/html_report/`) | 7 |
| **Total R source files** | **27** |
| **Total functions** | **178** |
| **Total lines of code** | **17,154** |

---

## Core R Files (`modules/conjoint/R/`)

### 00_guard.R (774 lines)

TRS guard layer: refusal handling, guard state, validation gates for conjoint module.

| Function | Line | Type | Description |
|---|---|---|---|
| `conjoint_refuse` | 95 | internal | Module-specific TRS refusal wrapper with conjoint error codes |
| `conjoint_with_refusal_handler` | 129 | exported | Wraps main analysis expression with TRS error handling |
| `conjoint_guard_init` | 148 | exported | Initialize conjoint-specific guard state with design/estimation fields |
| `guard_record_design_issue` | 169 | internal | Record a design issue for an attribute in guard state |
| `guard_record_estimation_warning` | 182 | internal | Record an estimation warning in guard state |
| `guard_record_convergence` | 197 | internal | Record model convergence status in guard state |
| `conjoint_guard_summary` | 217 | exported | Get summary of conjoint guard state with all issue types |
| `validate_conjoint_config` | 243 | internal | Validate that config is a properly structured list |
| `validate_conjoint_attributes` | 263 | internal | Validate attribute definitions (min 2 attrs, min 2 levels each) |
| `validate_conjoint_design` | 323 | internal | Validate experimental design matrix existence and structure |
| `validate_conjoint_convergence` | 356 | internal | Validate model convergence status |
| `guard_check_data_exists` | 401 | internal | Quick pre-check that choice data exists and is non-empty |
| `validate_hb_config` | 431 | internal | Validate HB-specific settings (iterations, burn-in, thinning, bayesm) |
| `validate_latent_class_config` | 490 | internal | Validate latent class settings (min/max classes, criterion) |
| `validate_html_config` | 548 | internal | Validate HTML output settings (brand/accent colour hex codes) |
| `validate_wtp_config` | 584 | internal | Validate WTP settings (price attribute, method) |
| `conjoint_status_pass` | 631 | exported | Create TRS PASS status with conjoint-specific details |
| `conjoint_status_partial` | 649 | exported | Create TRS PARTIAL status with degradation reasons |
| `conjoint_status_refuse` | 673 | exported | Create TRS REFUSE status for user-fixable issues |
| `conjoint_determine_status` | 700 | exported | Determine final TRS status from guard state and model fit |

### 00_main.R (698 lines)

Main entry point: sources all components, runs the full conjoint analysis pipeline.

| Function | Line | Type | Description |
|---|---|---|---|
| `.get_guard_dir` | 30 | internal | Resolve directory containing 00_guard.R |
| `.source_trs_infrastructure` | 51 | internal | Source shared TRS run state management files |
| `run_conjoint_analysis` | 316 | exported | Main entry point for conjoint analysis with optional pre-flight |
| `run_conjoint_analysis_impl` | 351 | internal | Internal implementation of the full analysis pipeline |
| `conjoint` | 698 | exported | Alias for run_conjoint_analysis |

### 00_preflight.R (381 lines)

Pre-flight validation: checks files, packages, JS syntax, TRS infrastructure before analysis.

| Function | Line | Type | Description |
|---|---|---|---|
| `conjoint_preflight` | 40 | exported | Run all pre-flight checks and report pass/fail summary |
| `.preflight_find_module_dir` | 326 | internal | Auto-detect conjoint module R/ directory from working directory |
| `.preflight_print_summary` | 344 | internal | Print formatted pre-flight summary table to console |

### 01_config.R (880 lines)

Configuration loader: reads Excel config with autodetect heading, validates all settings.

| Function | Line | Type | Description |
|---|---|---|---|
| `find_config_header_row` | 37 | internal | Scan first 20 rows of sheet for expected column headers |
| `.clean_settings_df` | 73 | internal | Remove help rows, section dividers, and empty rows from settings |
| `load_conjoint_config` | 119 | exported | Load and validate conjoint config from Excel (.xlsx) file |
| `validate_config` | 593 | internal | Validate settings and attributes (types, ranges, consistency) |
| `resolve_config_path` | 845 | internal | Resolve relative/absolute file paths from config |

### 02_data.R (521 lines)

Data loading and validation: loads CSV/XLSX/SAV/DTA, validates structure and quality.

| Function | Line | Type | Description |
|---|---|---|---|
| `load_conjoint_data` | 36 | exported | Load and validate conjoint data with auto source detection |
| `load_data_by_type` | 166 | internal | Load data file based on extension (CSV, XLSX, SAV, DTA) |
| `validate_conjoint_data` | 219 | internal | Comprehensive validation: columns, choices, levels, separation |
| `get_required_columns` | 459 | internal | Get list of required column names from config |
| `calculate_data_statistics` | 475 | internal | Calculate respondent/choice set/selection rate statistics |

### 03_estimation.R (681 lines)

Model estimation: mlogit (primary), clogit (fallback), auto-selection, rating-based OLS.

| Function | Line | Type | Description |
|---|---|---|---|
| `estimate_choice_model` | 33 | exported | Main estimation function with multi-method dispatch |
| `estimate_auto_method` | 104 | internal | Try mlogit first, fall back to clogit |
| `estimate_with_mlogit` | 160 | internal | Estimate model using mlogit package |
| `prepare_mlogit_data` | 260 | internal | Convert data to mlogit format with dfidx indexing |
| `build_mlogit_formula` | 359 | internal | Build mlogit formula with optional interaction terms |
| `extract_mlogit_results` | 422 | internal | Extract coefficients, vcov, log-likelihoods from mlogit model |
| `estimate_with_clogit` | 494 | internal | Estimate model using survival::clogit |
| `extract_clogit_results` | 566 | internal | Extract results from clogit model into standard format |
| `estimate_rating_based_conjoint` | 616 | internal | OLS regression for rating-based conjoint designs |

### 04_utilities.R (540 lines)

Utility calculation: part-worth utilities, confidence intervals, importance, diagnostics.

| Function | Line | Type | Description |
|---|---|---|---|
| `calculate_utilities` | 25 | exported | Extract and process part-worth utilities from estimated model |
| `extract_attribute_utilities` | 92 | internal | Extract utilities for one attribute from model coefficients |
| `calculate_attribute_importance` | 188 | exported | Calculate relative importance as % of total utility range |
| `calculate_model_diagnostics` | 238 | exported | Comprehensive model fit statistics and diagnostics |
| `calculate_choice_fit_stats` | 295 | internal | Calculate McFadden R-squared, hit rate, AIC, BIC |
| `calculate_hit_rate` | 354 | internal | Percentage of choices correctly predicted by model |
| `calculate_attribute_diagnostics` | 515 | internal | Per-attribute significance counts and ranges |

### 05_alchemer_import.R (937 lines)

Alchemer CBC data import: transforms Alchemer format to Turas internal format.

| Function | Line | Type | Description |
|---|---|---|---|
| `import_alchemer_conjoint` | 81 | exported | Main entry point for Alchemer CBC data import and transformation |
| `load_alchemer_file` | 194 | internal | Load Alchemer export file (Excel or CSV) |
| `validate_alchemer_columns` | 246 | internal | Check and fix required Alchemer column names |
| `normalize_score_column` | 299 | internal | Convert Alchemer Score values (0/1 or 0/100) to binary |
| `clean_alchemer_level` | 372 | exported | Clean Alchemer compound level names (Price_071 -> Price) |
| `clean_levels_with_config` | 427 | internal | Apply custom cleaning rules from config to levels |
| `validate_alchemer_data` | 479 | exported | Comprehensive validation of imported Alchemer data |
| `validate_alchemer_with_refusal` | 692 | internal | Validation wrapper that issues TRS refusal on failure |
| `get_alchemer_attributes` | 753 | exported | Extract attribute summary from imported Alchemer data |
| `create_config_from_alchemer` | 794 | exported | Auto-generate config list from imported Alchemer data |
| `save_config_to_excel` | 840 | internal | Save configuration list to formatted Excel file |
| `test_alchemer_import` | 890 | exported | Quick test of Alchemer import functionality |

### 05_simulator.R (920 lines)

Market simulator: share prediction (logit, first-choice, RFC), sensitivity, source of volume.

| Function | Line | Type | Description |
|---|---|---|---|
| `predict_market_shares` | 32 | exported | Predict market shares using multinomial logit model |
| `calculate_product_utility` | 124 | exported | Calculate total utility for a single product configuration |
| `predict_shares_logit` | 161 | internal | MNL share prediction with log-sum-exp stability |
| `predict_shares_first_choice` | 183 | internal | Deterministic first-choice rule (winner takes all) |
| `predict_shares_randomized_first_choice` | 204 | internal | First-choice with tie-breaking tolerance |
| `sensitivity_one_way` | 237 | exported | One-way sensitivity analysis for an attribute |
| `sensitivity_two_way` | 286 | exported | Two-way sensitivity analysis for two attributes |
| `compare_scenarios` | 331 | exported | Compare multiple product scenarios |
| `optimize_product` | 376 | exported | Greedy product optimization to maximize market share |
| `excel_to_product` | 469 | helper | Convert Excel dropdown selections to product list |
| `format_product` | 479 | helper | Format product configuration for display |
| `predict_market_shares_individual` | 505 | exported | Predict shares using individual-level HB/LC utilities |
| `build_product_design_vector` | 571 | internal | Build design vector for a product from HB column map |
| `simulate_rfc` | 600 | internal | Randomized First Choice with Gumbel error draws |
| `simulate_first_choice_individual` | 633 | internal | Deterministic first choice per respondent |
| `simulate_logit_individual` | 651 | internal | Logit share per respondent, then average |
| `source_of_volume` | 692 | exported | Calculate share shifts when adding a new product |
| `generate_demand_curve` | 765 | exported | Sweep price levels to generate demand curve |
| `predict_shares_with_ci` | 824 | exported | Predict shares with bootstrap confidence intervals |

### 06_interactions.R (650 lines)

Interaction effects: specification, estimation, analysis, config-driven pipeline.

| Function | Line | Type | Description |
|---|---|---|---|
| `specify_interactions` | 50 | exported | Specify interaction terms between attributes |
| `estimate_with_interactions` | 121 | exported | Estimate choice model with interaction effects |
| `create_interaction_terms` | 174 | internal | Create interaction columns in data frame |
| `add_interactions_to_config` | 198 | internal | Add interaction attributes to configuration object |
| `estimate_mlogit_with_interactions` | 221 | internal | Estimate mlogit model with interaction terms |
| `build_interaction_formula` | 273 | internal | Build formula string with main and interaction terms |
| `analyze_interaction` | 302 | exported | Analyze interaction effects from model coefficients |
| `test_interaction_significance` | 362 | exported | Likelihood ratio test for interaction significance |
| `prepare_interaction_plot` | 400 | exported | Create data frame for interaction effect plotting |
| `interpret_interaction` | 437 | exported | Interpret interaction effect magnitude and direction |
| `parse_interactions_from_config` | 475 | exported | Parse "Price:Brand,Size:Color" interaction string from config |
| `build_formula_with_interactions` | 521 | internal | Build mlogit formula with main effects and interactions |
| `run_interaction_analysis` | 558 | exported | Config-driven entry point for full interaction analysis |
| `has_interactions` | 617 | helper | Check if model has interaction effects |
| `get_interaction_terms` | 627 | helper | Get list of interaction terms from model |
| `format_interaction` | 641 | helper | Format interaction term for display |

### 07_output.R (1,231 lines)

Excel output writer: creates formatted 8+ sheet workbook with results, simulator, diagnostics.

| Function | Line | Type | Description |
|---|---|---|---|
| `write_conjoint_output` | 40 | exported | Main function: create formatted Excel workbook with all results |
| `create_utility_chart_data_sheet` | 180 | internal | Write pre-formatted chart data sheet for Excel charting |
| `create_model_fit_sheet` | 253 | internal | Write model fit diagnostics sheet (McFadden R-sq, hit rate, etc.) |
| `create_raw_coefficients_sheet` | 338 | internal | Write uncentered model coefficients with standard errors |
| `create_importance_sheet` | 421 | internal | Write attribute importance scores sheet |
| `create_utilities_sheet` | 443 | internal | Write zero-centered part-worth utilities sheet |
| `create_data_summary_sheet` | 484 | internal | Write response counts and completion rates sheet |
| `create_configuration_sheet` | 539 | internal | Write study design summary sheet |
| `create_individual_utilities_sheet` | 577 | internal | Write per-respondent HB utilities sheet |
| `create_hb_diagnostics_sheet` | 693 | internal | Write MCMC convergence metrics (Geweke, ESS) sheet |
| `create_respondent_quality_sheet` | 844 | internal | Write RLH scores and quality flags sheet |
| `create_class_comparison_sheet` | 978 | internal | Write latent class BIC/AIC comparison sheet |
| `create_class_profiles_sheet` | 1077 | internal | Write class-level utility profiles sheet |
| `create_class_membership_sheet` | 1191 | internal | Write respondent class membership assignments sheet |

### 08_market_simulator.R (572 lines)

Excel market simulator: interactive sheet with dropdowns, formulas, sensitivity analysis.

| Function | Line | Type | Description |
|---|---|---|---|
| `create_market_simulator_sheet` | 30 | exported | Create interactive market simulator sheet in Excel workbook |
| `write_simulator_instructions` | 84 | internal | Write simulator instructions at top of sheet |
| `write_product_configuration` | 122 | internal | Write product config section with dropdown cells |
| `write_market_share_section` | 194 | internal | Write market share calculation section with formulas |
| `write_utilities_breakdown` | 315 | internal | Write per-attribute utility contribution breakdown |
| `write_sensitivity_analysis` | 416 | internal | Write sensitivity analysis section for Product 1 |
| `create_simulator_data_sheet` | 499 | internal | Create hidden lookup table sheet for simulator formulas |
| `int2col` | 555 | helper | Convert column number to Excel column letter (A, AA, etc.) |

### 09_none_handling.R (393 lines)

None option detection and handling: auto-detect, explicit/implicit none, validation.

| Function | Line | Type | Description |
|---|---|---|---|
| `detect_none_option` | 26 | exported | Auto-detect "none of these" option using multiple methods |
| `handle_none_option` | 115 | exported | Process data based on detected none option method |
| `handle_explicit_none` | 149 | internal | Handle data with explicit none rows (flag them) |
| `handle_implicit_none` | 182 | internal | Handle implicit none (add explicit rows for unchosen sets) |
| `identify_none_rows` | 231 | internal | Identify none rows by pattern matching in attribute values |
| `create_none_rows` | 267 | internal | Create explicit none alternative rows for choice sets |
| `validate_none_choices` | 304 | internal | Validate data integrity with none option present |
| `calculate_none_diagnostics` | 367 | internal | Calculate none-specific diagnostics (selection rate, utility) |

### 10_best_worst.R (496 lines)

Best-worst scaling: BWS data validation, conversion, sequential/simultaneous estimation.

| Function | Line | Type | Description |
|---|---|---|---|
| `validate_best_worst_data` | 40 | internal | Validate best-worst data format (best/worst columns, exclusivity) |
| `convert_best_worst_to_choice` | 133 | internal | Convert best-worst data to standard choice format |
| `estimate_best_worst_model` | 191 | exported | Estimate BWS model (sequential or simultaneous method) |
| `estimate_best_worst_sequential` | 254 | internal | Estimate best and worst models separately, then combine |
| `estimate_best_worst_simultaneous` | 324 | internal | Joint best-worst estimation with choice type indicator |
| `calculate_best_worst_utilities` | 364 | exported | Calculate utilities from best-worst model result |
| `calculate_best_worst_diagnostics` | 401 | exported | Calculate BWS-specific diagnostics (LL, R-sq, best vs worst) |
| `is_best_worst_model` | 443 | helper | Check if model is best-worst scaling |
| `create_best_worst_template` | 456 | exported | Create empty BWS data template with attributes |

### 11_hierarchical_bayes.R (896 lines)

Hierarchical Bayes: individual-level utilities via bayesm MCMC, convergence diagnostics.

| Function | Line | Type | Description |
|---|---|---|---|
| `.load_hb_diagnostics` | 37 | internal | Load shared HB diagnostics infrastructure |
| `check_hb_requirements` | 71 | exported | Check if bayesm and coda packages are available |
| `prepare_bayesm_data` | 110 | internal | Convert Turas data to bayesm lgtdata list structure |
| `estimate_hierarchical_bayes` | 270 | exported | Main HB estimation using bayesm::rhierMnlRwMixture |
| `extract_hb_results` | 355 | internal | Process raw bayesm output into standard model result |
| `run_hb_convergence_diagnostics` | 467 | internal | Check MCMC convergence (Geweke z, ESS) |
| `calculate_respondent_rlh` | 581 | internal | Calculate respondent-level Root Likelihood for quality flagging |
| `extract_hb_utilities` | 670 | internal | Convert HB results to standard utilities data frame |
| `calculate_attribute_importance_hb` | 771 | internal | Compute importance at individual level, then average |
| `validate_hb_data` | 848 | internal | Validate data suitability for HB estimation |

### 12_config_template.R (751 lines)

Configuration template generator: creates branded Excel config templates.

| Function | Line | Type | Description |
|---|---|---|---|
| `.make_tpl_header_style` | 49 | internal | Create navy header style for template |
| `.make_tpl_section_style` | 58 | internal | Create section divider style |
| `.make_tpl_required_style` | 67 | internal | Create orange required field style |
| `.make_tpl_optional_style` | 75 | internal | Create green optional field style |
| `.make_tpl_input_style` | 83 | internal | Create yellow user-input style |
| `.make_tpl_help_style` | 91 | internal | Create grey italic help text style |
| `.make_tpl_locked_style` | 100 | internal | Create read-only locked field style |
| `.make_tpl_title_style` | 109 | internal | Create large navy title style |
| `.make_tpl_subtitle_style` | 117 | internal | Create italic grey subtitle style |
| `.make_tpl_required_label_style` | 123 | internal | Create bold red "REQUIRED" label style |
| `.make_tpl_optional_label_style` | 132 | internal | Create green "Optional" label style |
| `.make_tpl_example_style` | 141 | internal | Create light blue example row style |
| `.get_conjoint_settings_definition` | 154 | internal | Return full settings definition data frame with all fields |
| `generate_conjoint_config_template` | 285 | exported | Generate branded Excel configuration template |
| `.get_method_template_overrides` | 703 | internal | Get preset overrides for standard_cbc, cbc_hb, etc. |

### 13_latent_class.R (725 lines)

Latent class analysis: discover preference segments, BIC/AIC model selection, membership.

| Function | Line | Type | Description |
|---|---|---|---|
| `estimate_latent_class` | 46 | exported | Fit LC models for K=min..max, select optimal by BIC/AIC |
| `fit_latent_class_k` | 154 | internal | Fit a single K-class latent class model via bayesm |
| `extract_lc_solution` | 205 | internal | Extract class assignments, betas, info criteria from bayesm output |
| `compute_class_probabilities` | 380 | internal | Convert k-means distances to soft class probabilities |
| `assign_respondents_to_classes` | 413 | internal | Provide modal (hard) and probability-weighted (soft) assignment |
| `calculate_lc_log_likelihood` | 459 | internal | Compute mixture log-likelihood for BIC/AIC comparison |
| `calculate_entropy_r2` | 522 | internal | Measure classification quality (0=poor, 1=clear separation) |
| `compare_class_solutions` | 549 | internal | Create comparison table with delta columns across K solutions |
| `build_latent_class_result` | 579 | internal | Assemble standardized turas_conjoint_model for optimal LC |
| `extract_lc_utilities` | 682 | internal | Extract aggregate and class-level utilities in standard format |

### 14_willingness_to_pay.R (448 lines)

WTP estimation: marginal rate of substitution, individual-level WTP, confidence intervals.

| Function | Line | Type | Description |
|---|---|---|---|
| `calculate_wtp` | 49 | exported | Main WTP calculation with optional individual-level WTP |
| `estimate_price_coefficient` | 126 | internal | Estimate price coefficient from part-worth utilities |
| `estimate_price_coefficient_se` | 179 | internal | Estimate standard error of price coefficient |
| `extract_numeric_prices` | 208 | internal | Extract numeric values from price level labels |
| `calculate_aggregate_wtp` | 265 | internal | Calculate WTP table with full delta method CIs |
| `calculate_individual_wtp` | 331 | internal | Calculate per-respondent WTP from HB betas |
| `summarize_wtp_distribution` | 405 | internal | Summarize WTP distribution (mean, median, percentiles) |

### 15_product_optimizer.R (343 lines)

Product optimization: exhaustive search, greedy hill-climbing, revenue/profit objectives.

| Function | Line | Type | Description |
|---|---|---|---|
| `optimize_product_exhaustive` | 48 | exported | Exhaustive enumeration of all product configurations |
| `optimize_product_greedy` | 160 | exported | Greedy hill-climbing with multiple random starts |
| `evaluate_product` | 262 | internal | Evaluate product against objective (share, utility, revenue) |
| `get_product_price` | 306 | internal | Extract numeric price from product configuration |
| `get_product_cost` | 320 | internal | Get total cost from cost data lookup |

### 99_helpers.R (589 lines)

Shared utility functions: type conversion, statistics, formatting, logging.

| Function | Line | Type | Description |
|---|---|---|---|
| `%\|\|%` | 40 | internal | Null coalescing operator |
| `create_error` | 57 | internal | Create formatted error message with module/problem/solution |
| `create_warning` | 68 | internal | Create formatted warning message |
| `safe_logical` | 89 | internal | Safely convert various TRUE/FALSE representations to logical |
| `safe_numeric` | 115 | internal | Safely convert to numeric with default fallback |
| `parse_level_names` | 133 | internal | Parse comma-separated level names string to vector |
| `get_attribute_levels` | 157 | internal | Get levels for a specific attribute from config |
| `calculate_ci` | 190 | internal | Calculate normal-approximation confidence interval |
| `calculate_p_value` | 201 | internal | Calculate two-sided p-value from z-statistic |
| `format_p_value` | 215 | internal | Format p-value for display ("<0.001" for small values) |
| `get_significance_stars` | 227 | internal | Return significance stars (*, **, ***) for p-value |
| `interpret_utility_magnitude` | 245 | internal | Interpret utility as Strongly/Moderately/Somewhat/Slightly |
| `interpret_utility` | 262 | internal | Full interpretation with direction, magnitude, significance |
| `interpret_importance` | 284 | internal | Interpret importance percentage as driver category |
| `assess_mcfadden_r2` | 302 | internal | Assess McFadden R-squared quality level |
| `assess_hit_rate` | 333 | internal | Assess hit rate quality relative to chance |
| `check_perfect_separation` | 361 | internal | Check for levels always/never chosen |
| `create_header_style` | 390 | internal | Create standard Excel header style |
| `create_positive_style` | 405 | internal | Create green cell style for positive values |
| `create_negative_style` | 415 | internal | Create red cell style for negative values |
| `create_title_style` | 425 | internal | Create Excel title style |
| `log_verbose` | 445 | internal | Print message only when verbose=TRUE |
| `print_section` | 459 | internal | Print section header with line separators |
| `require_package` | 478 | internal | Check if required package is available, refuse if not |
| `likelihood_ratio_test` | 514 | internal | Compare two nested models using LR test |
| `zero_center_utilities` | 542 | internal | Zero-center utilities within attribute |
| `escape_attr_for_formula` | 559 | internal | Wrap special-character attribute names in backticks |
| `escape_attr_for_regex` | 576 | internal | Escape regex special characters in attribute names |
| `get_conjoint_version` | 587 | internal | Return current module version string ("3.1.0") |

---

## HTML Report Files (`modules/conjoint/lib/html_report/`)

### 00_html_guard.R (145 lines)

Input validation for HTML report generation.

| Function | Line | Type | Description |
|---|---|---|---|
| `validate_conjoint_html_inputs` | 17 | internal | Validate conjoint results and config before HTML generation |
| `.validate_utilities` | 59 | internal | Validate utilities data frame structure |
| `.validate_importance` | 78 | internal | Validate importance data frame structure |
| `.validate_model_result` | 91 | internal | Validate model result method and convergence |
| `.validate_wtp` | 104 | internal | Validate WTP table columns |
| `.validate_colours` | 119 | internal | Validate hex colour codes for brand/accent |
| `.validate_insights` | 133 | internal | Validate insight text fields are character type |

### 01_data_transformer.R (282 lines)

Transform conjoint results into HTML-ready data structures for all panels.

| Function | Line | Type | Description |
|---|---|---|---|
| `transform_conjoint_for_html` | 21 | internal | Main transformer: results to HTML-ready data for all panels |
| `.build_summary` | 85 | internal | Build summary metadata (project name, method, respondent count) |
| `.extract_hb_data` | 100 | internal | Extract HB-specific data (individual betas, convergence, quality) |
| `.extract_lc_data` | 124 | internal | Extract latent class data (classes, sizes, entropy) |
| `.extract_wtp_data` | 138 | internal | Extract WTP table and demand curve data |
| `.build_simulator_data` | 159 | internal | Build JSON-ready simulator data from utilities and config |
| `simulator_data_to_json` | 225 | internal | Convert simulator data list to JSON string |
| `.extract_insights` | 236 | internal | Extract per-tab insight seed text from config |
| `.extract_about` | 251 | internal | Extract about page fields (analyst, company, closing notes) |
| `.build_sidebar_nav` | 269 | internal | Build sidebar navigation items from attribute list |

### 02_table_builder.R (401 lines)

HTML table construction with export-ready data attributes.

| Function | Line | Type | Description |
|---|---|---|---|
| `.html_escape` | 9 | internal | Escape HTML special characters in text |
| `build_importance_table` | 22 | internal | Build importance summary table with interpretation column |
| `build_utilities_table` | 54 | internal | Build utilities table for one attribute with baseline tags |
| `build_model_fit_table` | 100 | internal | Build model fit metrics table (R-sq, hit rate, AIC, etc.) |
| `build_convergence_table` | 142 | internal | Build HB convergence table (Geweke z, ESS per parameter) |
| `build_lc_comparison_table` | 176 | internal | Build LC class comparison table (K, AIC, BIC, Entropy R-sq) |
| `build_wtp_table` | 208 | internal | Build WTP table with currency formatting and CI columns |
| `build_demand_table` | 268 | internal | Build demand curve table (price vs market share) |
| `build_class_importance_table` | 301 | internal | Build LC class importance table with class size labels |
| `build_respondent_quality_table` | 365 | internal | Build HB respondent quality metrics table |

### 03_page_builder.R (1,716 lines)

Full HTML page assembly: header, panels, CSS, JavaScript, navigation, overlays.

| Function | Line | Type | Description |
|---|---|---|---|
| `build_conjoint_page` | 21 | internal | Main orchestrator assembling all HTML components |
| `build_conjoint_meta` | 120 | internal | Build HTML meta tags (charset, viewport, title) |
| `build_conjoint_css` | 143 | internal | Build complete CSS stylesheet with brand/accent colours |
| `build_conjoint_print_css` | 551 | internal | Build print-specific CSS media query styles |
| `build_conjoint_header` | 597 | internal | Build dark gradient header with logo, title, KPIs |
| `build_report_tab_nav` | 670 | internal | Build tab navigation bar with panel buttons |
| `build_overview_panel` | 713 | internal | Build overview panel with importance chart and KPIs |
| `build_utilities_panel` | 767 | internal | Build utilities panel with per-attribute charts and tables |
| `build_diagnostics_panel` | 882 | internal | Build diagnostics panel with model fit, convergence, quality |
| `build_lc_panel` | 1111 | internal | Build latent class panel with class comparison and profiles |
| `build_wtp_panel` | 1184 | internal | Build WTP panel with chart, table, and demand curve |
| `build_simulator_panel` | 1254 | internal | Build embedded market simulator panel with JS engine |
| `build_about_panel` | 1367 | internal | Build about page with analyst info and closing notes |
| `build_pinned_panel` | 1427 | internal | Build pinned insights sidebar panel |
| `build_slides_panel` | 1459 | internal | Build custom slides presentation panel |
| `build_help_overlay` | 1491 | internal | Build help overlay with keyboard shortcuts |
| `build_insight_area` | 1518 | internal | Build editable insight text area for a tab |
| `.build_callout` | 1546 | internal | Build callout box with title and body HTML |
| `.build_diagnostics_callouts` | 1558 | internal | Build contextual diagnostic callouts (trust, method, quality) |
| `.build_export_bar` | 1628 | internal | Build export toolbar (CSV, PNG, Excel buttons) |
| `build_conjoint_js` | 1647 | internal | Load and inline all JavaScript modules from js/ directory |
| `.get_conjoint_js_dir` | 1675 | internal | Resolve path to conjoint JS directory |
| `.html_esc` | 1697 | internal | Escape HTML special characters (local variant) |

### 04_html_writer.R (52 lines)

Write assembled HTML to disk as UTF-8 file.

| Function | Line | Type | Description |
|---|---|---|---|
| `write_conjoint_html_report` | 13 | internal | Write complete HTML string to file with size reporting |

### 05_chart_builder.R (852 lines)

SVG chart construction following Turas visual standards (rounded bars, muted palette).

| Function | Line | Type | Description |
|---|---|---|---|
| `.svg_esc` | 15 | internal | Escape text for SVG text elements |
| `.svg_wrap` | 25 | internal | Wrap SVG content in chart container div |
| `.svg_gridline` | 32 | internal | Generate SVG gridline element |
| `.svg_axis_label` | 39 | internal | Generate SVG axis label text element |
| `.svg_value_label` | 46 | internal | Generate SVG data value label text element |
| `build_importance_chart` | 66 | internal | Build horizontal importance bar chart (SVG) |
| `build_utility_chart` | 165 | internal | Build vertical utility bar chart per attribute (SVG) |
| `build_utility_dot_plot` | 268 | internal | Build horizontal lollipop chart per attribute (SVG) |
| `build_bic_chart` | 363 | internal | Build BIC line chart for LC comparison (SVG) |
| `build_wtp_chart` | 446 | internal | Build WTP horizontal bar chart with CI whiskers (SVG) |
| `.nice_tick_step` | 579 | internal | Compute nice tick step for axis labels |
| `build_demand_curve_chart` | 598 | internal | Build demand curve line chart (SVG) |
| `build_class_importance_chart` | 693 | internal | Build grouped bar chart for class importance (SVG) |
| `.generate_class_palette` | 782 | internal | Generate muted colour palette for latent classes |
| `build_class_size_chart` | 805 | internal | Build class size horizontal bar chart (SVG) |

### 99_html_report_main.R (280 lines)

Lazy-load orchestrator: sources submodules, generates combined report + simulator.

| Function | Line | Type | Description |
|---|---|---|---|
| `.chr_load_conjoint_submodules` | 45 | internal | Lazy-load all HTML report submodule files |
| `generate_conjoint_html_report` | 93 | exported | Main entry point for HTML report generation |
| `.build_all_tables` | 152 | internal | Build all HTML tables from transformed data |
| `.build_all_charts` | 219 | internal | Build all SVG charts from transformed data |
