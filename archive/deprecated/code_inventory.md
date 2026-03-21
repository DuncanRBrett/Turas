---
editor_options: 
  markdown: 
    wrap: 72
---

# Pricing Module — Code Inventory

**Generated:** 2026-03-20 **Status:** Production (95+ quality target)
**Total source lines:** 10,251 (core R) + 5,977 (lib/support) + 313
(GUI) = **16,541** **Total test lines:** 5,793 across 22 test files
**Total test cases:** 289 (`test_that` blocks), all passing (800
assertions)

------------------------------------------------------------------------

## Core R Source Files (R/)

| File | Lines | Functions | Purpose |
|----|---:|---:|----|
| `00_guard.R` | 758 | 18 | TRS guard layer, input validation, console error formatting, status helpers |
| `00_main.R` | 590 | 4 | Pipeline orchestration (`run_pricing_analysis`, `run_pricing_analysis_from_config`) |
| `01_config.R` | 1,102 | 20 | Excel config loading, settings parsing, defaults, config template creation |
| `02_validation.R` | 536 | 4 | Data loading (CSV/XLSX/RDS), DK recoding, data validation, monotonicity checks |
| `03_van_westendorp.R` | 790 | 4 | VW validation, PSM analysis via `pricesensitivitymeter`, bootstrap CIs |
| `04_gabor_granger.R` | 958 | 17 | GG data prep, demand curves, smoothing (3 methods), interpolation, revenue/profit, elasticity, bootstrap |
| `05_visualization.R` | 495 | 8 | ggplot2 chart generation for VW curves, GG demand/revenue/profit |
| `06_output.R` | 1,012 | 2 | Excel workbook output with formatted sheets, CSV export |
| `07_wtp_distribution.R` | 306 | 6 | WTP extraction (VW/GG), density estimation, percentiles, summary stats, distribution plots |
| `08_competitive_scenarios.R` | 283 | 5 | Choice simulation, multi-scenario comparison, price-response curves |
| `09_price_volume_optimisation.R` | 1,014 | 12 | Constrained optimization, continuous optimization, sensitivity analysis, Pareto frontier, point elasticity |
| `10_segmentation.R` | 673 | 5 | Segmented analysis runner, segment comparison tables, insights, statistical tests (permutation/bootstrap) |
| `11_price_ladder.R` | 453 | 5 | Tiered price ladder construction, rounding, gap analysis, demand estimation |
| `12_recommendation_synthesis.R` | 839 | 6 | Cross-method synthesis, psychological rounding, confidence assessment, risk identification, executive summary |
| `13_monadic.R` | 442 | 3 | Monadic concept test analysis, elasticity computation, bootstrap CIs |
| **Total** | **10,251** | **119** |  |

## Support Files

| File | Lines | Purpose |
|----|---:|----|
| `run_pricing_gui.R` | 313 | Shiny GUI interface (stripped to essentials: config browse + run) |
| `lib/html_report/01_data_transformer.R` | 499 | Transform analysis results for HTML report |
| `lib/html_report/02_table_builder.R` | 439 | HTML table construction |
| `lib/html_report/03_page_builder.R` | 1,925 | Full HTML page assembly with CSS/JS |
| `lib/html_report/04_chart_builder.R` | 666 | SVG chart generation for HTML reports |
| `lib/html_report/99_html_report_main.R` | 305 | HTML report orchestration |
| `lib/simulator/simulator_builder.R` | 468 | Interactive pricing simulator (standalone HTML) |
| `lib/generate_config_templates.R` | 986 | Excel config template generator |
| `sample_config_comprehensive.R` | 362 | Sample config creation script |
| `TEST_NEW_FEATURES.R` | 327 | Manual feature testing script (dev-only) |

## Test Files (tests/testthat/)

| File | Lines | Tests | Coverage Target |
|----|---:|---:|----|
| `setup.R` | 194 | — | Test infrastructure, synthetic data generators |
| `test_added_slides.R` | 193 | 9 | Added slides / insights config loading |
| `test_competitive_scenarios.R` | 227 | 14 | Choice simulation, scenarios, price-response |
| `test_config.R` | 102 | 6 | Config loading, settings parsing |
| `test_edge_cases.R` | 352 | 24 | Boundary conditions across all methods |
| `test_gabor_granger.R` | 298 | 15 | GG demand, revenue, elasticity, monotonicity, edge cases |
| `test_guard.R` | 257 | 18 | TRS guard layer, validation, refusals |
| `test_html_report.R` | 408 | 19 | HTML report generation |
| `test_integration.R` | 248 | 8 | Cross-module integration |
| `test_main_pipeline.R` | 222 | 7 | End-to-end VW & GG pipelines, error handling |
| `test_monadic.R` | 252 | 9 | Monadic analysis, elasticity, bootstrap |
| `test_optimization.R` | 476 | 32 | Constrained/continuous optimization, sensitivity, Pareto |
| `test_output_files.R` | 252 | 4 | Excel/CSV output generation |
| `test_point_elasticity.R` | 178 | 13 | Point elasticity, marginal revenue, revenue-maximizing price |
| `test_price_ladder.R` | 149 | 8 | Price ladder construction, rounding, gaps |
| `test_segment_statistical.R` | 262 | 16 | Permutation tests, bootstrap CIs, Holm-Bonferroni |
| `test_segmentation.R` | 149 | 5 | Segmented analysis runner |
| `test_simulator.R` | 254 | 17 | Interactive simulator builder |
| `test_synthesis.R` | 253 | 11 | Recommendation synthesis, confidence, risks |
| `test_validation.R` | 300 | 16 | Data loading, validation, DK recoding, weights |
| `test_van_westendorp.R` | 269 | 14 | VW analysis, bootstrap, edge cases |
| `test_visualization.R` | 195 | 8 | Plot generation for all chart types |
| `test_wtp_distribution.R` | 303 | 16 | WTP extraction, density, percentiles |
| **Total** | **5,793** | **289** |  |

## Test Coverage Map

| Source File | Test Files | Tests |
|----|----|---:|
| `00_guard.R` | test_guard | 18 |
| `00_main.R` | test_main_pipeline | 7 |
| `01_config.R` | test_config, test_added_slides | 15 |
| `02_validation.R` | test_validation | 16 |
| `03_van_westendorp.R` | test_van_westendorp, test_edge_cases (partial) | 14+ |
| `04_gabor_granger.R` | test_gabor_granger, test_edge_cases (partial) | 15+ |
| `05_visualization.R` | test_visualization | 8 |
| `06_output.R` | test_output_files, test_html_report | 23 |
| `07_wtp_distribution.R` | test_wtp_distribution | 16 |
| `08_competitive_scenarios.R` | test_competitive_scenarios | 14 |
| `09_price_volume_optimisation.R` | test_optimization, test_point_elasticity | 45 |
| `10_segmentation.R` | test_segmentation, test_segment_statistical | 21 |
| `11_price_ladder.R` | test_price_ladder | 8 |
| `12_recommendation_synthesis.R` | test_synthesis | 11 |
| `13_monadic.R` | test_monadic | 9 |
| Cross-cutting | test_integration, test_main_pipeline | 15 |

## Documentation

| File | Purpose |
|----|----|
| `docs/README.md` | Module overview |
| `docs/USER_MANUAL.md` | End-user manual (all features incl. point elasticity, segment tests) |
| `docs/TECHNICAL_REFERENCE.md` | API reference |
| `docs/METHODOLOGY_COMPARISON.md` | VW vs GG vs Monadic methodology guide |
| `docs/QUESTIONNAIRE_DESIGN_GUIDE.md` | Survey design guidance |
| `docs/AUTHORITATIVE_GUIDE.md` | Comprehensive pricing research guide |
| `docs/EXAMPLE_WORKFLOWS.md` | Step-by-step workflow examples |
| `docs/MARKETING.md` | Feature marketing copy |
| `docs/TEMPLATE_README.txt` | Config template instructions |

## Quality Assessment

**Strengths:** - 289 test cases across 22 files with zero failures -
Every source file has dedicated test coverage - TRS v1.0 compliant
throughout — no raw `stop()` calls - Full edge case coverage (small
samples, all-zero/all-one data, NAs, extreme ranges) - End-to-end
pipeline tests for both VW and GG methods - Statistical methods
validated (point elasticity, permutation tests, bootstrap CIs) - GUI
stripped to essentials, critical sourcing bug fixed

**No known bugs.** All 800 test assertions pass. The module is
production-ready at 95+ quality.

## Dependencies

| Package                 | Required | Purpose                        |
|-------------------------|----------|--------------------------------|
| `pricesensitivitymeter` | Yes (VW) | Van Westendorp PSM analysis    |
| `ggplot2`               | Yes      | Visualization                  |
| `openxlsx`              | Yes      | Excel I/O                      |
| `data.table`            | Yes      | Fast data manipulation         |
| `jsonlite`              | Optional | JSON config export             |
| `survey`                | Optional | Design-aware weighted analysis |
