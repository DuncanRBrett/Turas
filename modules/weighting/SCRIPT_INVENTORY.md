# Weighting Module - Script Inventory
Generated: 2026-03-08

## Summary
- Total R scripts: 21
- Total JS files: 1
- Total lines of code: 9993
- Production code: 9693 lines
- Test code: 0 lines (tests reside in `tests/testthat/` and are not counted here)

## Core Scripts

| File | Lines | Purpose | Key Functions | Quality | Status |
|------|-------|---------|---------------|---------|--------|
| `run_weighting.R` | 757 | Main entry point orchestration | `run_weighting()`, pipeline control, shared infrastructure loading | 4/5 | Active |
| `run_weighting_gui.R` | 750 | Shiny GUI interface | `run_weighting_gui()`, reactive UI, input binding, observer handlers | 4/5 | Active |

## Library Scripts

| File | Lines | Purpose | Key Functions | Quality | Status |
|------|-------|---------|---------------|---------|--------|
| `lib/00_guard.R` | 261 | TRS guard layer - validates all inputs before processing | `weighting_refuse()`, `guard_config_file()`, `guard_data_file()`, `guard_config_object()` | 5/5 | Active |
| `lib/config_loader.R` | 725 | Excel config parsing and normalisation | `load_weighting_config()`, sheet readers, field mapping, defaults | 4/5 | Active |
| `lib/validation.R` | 410 | Pre-calculation data validation | `validate_weighting_data()`, type checks, completeness checks | 4/5 | Active |
| `lib/design_weights.R` | 362 | Stratified design weight calculation | `calculate_design_weights()`, stratum matching, population proportions | 5/5 | Active |
| `lib/rim_weights.R` | 655 | Rim/raking weight calculation via iterative proportional fitting | `calculate_rim_weights()`, IPF loop, convergence tracking, margin matching | 4/5 | Active |
| `lib/cell_weights.R` | 437 | Cell/interlocked weight calculation | `calculate_cell_weights()`, cross-classification, joint target matching | 4/5 | Active |
| `lib/trimming.R` | 386 | Weight capping and percentile trimming | `apply_weight_trimming()`, cap method, percentile method, rescaling | 4/5 | Active |
| `lib/diagnostics.R` | 498 | Weighting quality metrics and diagnostics | `compute_diagnostics()`, design effect, weight efficiency, distribution stats | 5/5 | Active |
| `lib/output.R` | 820 | Excel/CSV output generation | `write_weighting_output()`, formatted workbook, diagnostics sheet, CSV export | 4/5 | Active |
| `lib/generate_config_templates.R` | 662 | Professional config template generator | `generate_weight_config_template()`, `generate_all_weighting_templates()` | 5/5 | Active |
| `lib/validation/preflight_validators.R` | 960 | Pre-flight cross-referential validation | `validate_weighting_preflight()`, 14 check functions, `log_preflight_issue()` | 5/5 | Active |

## HTML Report Scripts

| File | Lines | Purpose | Key Functions | Quality | Status |
|------|-------|---------|---------------|---------|--------|
| `lib/html_report/00_html_guard.R` | 37 | HTML report input validation | Guard checks for HTML report parameters | 4/5 | Active |
| `lib/html_report/01_data_transformer.R` | 95 | Data preparation for HTML report | Transforms weighting results into report-ready structures | 4/5 | Active |
| `lib/html_report/02_table_builder.R` | 231 | HTML table generation | Builds formatted tables for weight summaries and diagnostics | 4/5 | Active |
| `lib/html_report/03_page_builder.R` | 1044 | HTML page structure and layout | Page template, CSS, section assembly, responsive layout | 4/5 | Active |
| `lib/html_report/04_html_writer.R` | 99 | HTML file output | Writes assembled HTML to disk | 4/5 | Active |
| `lib/html_report/05_chart_builder.R` | 145 | SVG chart generation for HTML report | Weight distribution charts, efficiency visualisations | 4/5 | Active |
| `lib/html_report/99_html_report_main.R` | 295 | HTML report orchestration | `generate_weighting_html_report()`, pipeline coordination | 4/5 | Active |

## JavaScript Files

| File | Lines | Purpose | Quality | Status |
|------|-------|---------|---------|--------|
| `lib/html_report/js/weighting_navigation.js` | 64 | Client-side navigation for HTML report | 4/5 | Active |

## Legacy / Superseded Scripts

| File | Lines | Purpose | Key Functions | Quality | Status |
|------|-------|---------|---------------|---------|--------|
| `templates/create_template.R` | 300 | Legacy template generator (replaced by `lib/generate_config_templates.R`) | `create_weight_template()` | 3/5 | Superseded |

## Test Files (not counted in totals above)

Tests reside in `tests/testthat/` with fixtures in `tests/fixtures/synthetic_data/`.

| File | Purpose |
|------|---------|
| `tests/testthat/test_cell_weights.R` | Cell weight calculation tests |
| `tests/testthat/test_config_loader.R` | Config parsing tests |
| `tests/testthat/test_design_weights.R` | Design weight calculation tests |
| `tests/testthat/test_diagnostics.R` | Diagnostics computation tests |
| `tests/testthat/test_edge_cases.R` | Boundary and edge case tests |
| `tests/testthat/test_guard.R` | TRS guard layer tests |
| `tests/testthat/test_html_report.R` | HTML report generation tests |
| `tests/testthat/test_integration.R` | End-to-end integration tests |
| `tests/testthat/test_output.R` | Output generation tests |
| `tests/testthat/test_rim_weights.R` | Rim weight calculation tests |
| `tests/testthat/test_trimming.R` | Weight trimming tests |
| `tests/testthat/test_validation.R` | Data validation tests |
| `tests/testthat/setup.R` | Test setup and helpers |
| `tests/testthat.R` | Test runner entry point |
| `tests/fixtures/synthetic_data/generate_test_data.R` | Synthetic data generator |

## Architecture Notes

- **Entry point:** `run_weighting.R` orchestrates the full pipeline: guard -> config load -> validate -> calculate -> trim -> diagnose -> output
- **GUI:** `run_weighting_gui.R` provides the Shiny interface and calls into the same pipeline
- **Config:** Excel-based configuration with 7 sheets (Settings, Weight_Specifications, Design_Targets, Rim_Targets, Cell_Targets, Advanced_Settings, Notes)
- **Validation:** Two layers - `lib/validation.R` (data quality) and `lib/validation/preflight_validators.R` (cross-referential config checks)
- **Template:** `lib/generate_config_templates.R` supersedes `templates/create_template.R` with shared infrastructure support
- **HTML report:** 7-file pipeline following the standard TURAS report pattern (guard -> transform -> build -> write)
