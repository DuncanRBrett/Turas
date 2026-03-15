# Turas Tabs Module - Code Inventory

**Generated:** 15 March 2026 | **Version:** 10.8.2 | **R Files:** 52 lib + 9 tests + 2 entry = 63 | **JS Files:** 5 | **Total Lines:** 34,749 (lib R+JS) + 4,915 (tests) + 696 (entry) = 40,360

------------------------------------------------------------------------

## R Package Dependencies

All packages managed via `renv.lock`. Versions current as of 15 March 2026.

| Package | Version | Purpose | Required |
|---------|---------|---------|----------|
| R | 4.5.1 | Runtime | Yes |
| readxl | 1.4.5 | Read Excel config and structure files | Yes |
| openxlsx | 4.2.8 | Write Excel workbook output | Yes |
| data.table | 1.17.8 | Fast CSV reading and caching | Yes |
| htmltools | 0.5.8.1 | HTML report generation and escaping | Yes |
| jsonlite | 2.0.0 | JSON encoding for HTML report data | Yes |
| haven | 2.5.5 | Read SPSS (.sav) data files | Yes |
| lobstr | 1.1.2 | Memory monitoring during analysis | Optional |
| base64enc | 0.1.3 | Embed logo images in HTML reports | Optional |
| shiny | 1.11.1 | GUI launcher (run_tabs_gui.R) | GUI only |
| shinyFiles | 0.9.3 | File browser widget in GUI | GUI only |

**Monitor for:** Major version changes in readxl, openxlsx, data.table, htmltools (breaking API changes possible). Haven 3.x may change .sav import behaviour.

------------------------------------------------------------------------

## Summary

| Category | Files | Lines | % of Total |
|---|---|---|---|
| Core Orchestration | 3 | 1,332 | 3.8% |
| Configuration & Loading | 4 | 2,222 | 6.4% |
| Crosstabs Submodules | 5 | 2,280 | 6.5% |
| Validation System | 7 | 4,347 | 12.4% |
| Guard Layer | 1 | 786 | 2.2% |
| Question Processing | 4 | 3,035 | 8.6% |
| Composite Metrics | 1 | 826 | 2.3% |
| Ranking System | 4 | 2,088 | 5.9% |
| Banner & Cell Calculations | 3 | 1,895 | 5.4% |
| Weighting & Statistics | 1 | 1,578 | 4.5% |
| Excel Output | 3 | 2,577 | 7.3% |
| HTML Report (R) | 13 | 7,280 | 18.8% |
| HTML Report (JS) | 5 | 4,155 | 10.7% |
| Utilities | 5 | 1,142 | 3.2% |
| Config Templates | 1 | 1,373 | 3.9% |
| Tests | 9 | 4,915 | 12.2% |
| Entry Points & GUI | 2 | 696 | 2.0% |

**Note on test locations:**
- `modules/tabs/tests/testthat/` — 9 files, 4,915 lines: tabs-specific business logic (core guard/config 243, calculations 56, utilities 96, V10.8 regressions 56, banner 46, data loading 35, numeric processor 32, Excel output 63, HTML report 45 = 560 assertions total)
- `tests/testthat/` (project root) — 10 files, ~2,389 lines: shared infrastructure (TRS compliance, shared utilities, code quality scans)
- See `tests/testthat/README.md` and `modules/tabs/tests/README.md` for rationale.

------------------------------------------------------------------------

## Detailed File Inventory

### Core Orchestration & Entry Points

| File | Lines | Purpose |
|---|---:|---|
| `run_tabs.R` | 92 | Entry point; loads Turas framework before running tabs |
| `run_tabs_gui.R` | 604 | Shiny GUI launcher with file browser and progress |
| `lib/run_crosstabs.R` | 636 | Main crosstabs orchestrator (lean V10.2 refactor) |
| | **1,332** | |

### Configuration & Loading

| File | Lines | Purpose |
|---|---:|---|
| `lib/config_loader.R` | 14 | Stub — retained as source target in run_crosstabs.R (all functions moved to crosstabs_config.R, config_utils.R, data_setup.R) |
| `lib/config_utils.R` | 297 | Typed getter functions for config values (canonical versions) |
| `lib/data_loader.R` | 438 | Survey structure and data loading (.xlsx, .csv, .sav) with CSV caching |
| `lib/generate_config_templates.R` | 1,373 | Generate professional hardened Excel config templates |
| | **2,122** | |

### Crosstabs Submodules (Phase 4 Refactoring)

| File | Lines | Purpose |
|---|---:|---|
| `lib/crosstabs/crosstabs_config.R` | 591 | Build config_obj with 71 typed settings + unrecognised-setting detection (canonical) |
| `lib/crosstabs/data_setup.R` | 317 | Orchestrate structure/data/weight loading |
| `lib/crosstabs/analysis_runner.R` | 570 | Validation, banner creation, question processing loop |
| `lib/crosstabs/workbook_builder.R` | 657 | Excel workbook assembly (all sheets) |
| `lib/crosstabs/checkpoint.R` | 146 | Save/load/cleanup for resumable analysis |
| | **2,281** | |

### Validation System

| File | Lines | Purpose |
|---|---:|---|
| `lib/validation.R` | 1,672 | Core validation orchestrator; coordinates 5 validator submodules |
| `lib/validation_utils.R` | 439 | Input validation functions (data frame, numeric, file path) |
| `lib/validation/structure_validators.R` | 208 | Survey structure validation (duplicates, option validity) |
| `lib/validation/config_validators.R` | 256 | Configuration parameter validation (alpha, min_base) |
| `lib/validation/weight_validators.R` | 375 | Weight column and value validation (DEFF, distribution) |
| `lib/validation/data_validators.R` | 398 | Data type and format validation (multi-mention, numeric) |
| `lib/validation/preflight_validators.R` | 969 | Cross-referential pre-flight checks (16 checks) |
| | **4,317** | |

### Guard Layer

| File | Lines | Purpose |
|---|---:|---|
| `lib/00_guard.R` | 786 | TRS guard layer; tabs_refuse(), tabs_source(), guard state |
| | **786** | |

### Question Processing

| File | Lines | Purpose |
|---|---:|---|
| `lib/question_orchestrator.R` | 678 | Question data preparation and coordination |
| `lib/question_dispatcher.R` | 423 | Route questions to processors by Variable_Type |
| `lib/standard_processor.R` | 1,340 | Process Single/Multi/Likert/Rating questions |
| `lib/numeric_processor.R` | 599 | Process Numeric questions with bins |
| | **3,031** | |

### Composite Metrics

| File | Lines | Purpose |
|---|---:|---|
| `lib/composite_processor.R` | 830 | Composite metrics combining multiple questions |
| | **830** | |

### Ranking System

| File | Lines | Purpose |
|---|---:|---|
| `lib/ranking.R` | 1,019 | Ranking question orchestration with 3 submodules |
| `lib/ranking/ranking_validation.R` | 200 | Ranking format/position validation |
| `lib/ranking/ranking_metrics.R` | 557 | Ranking metric calculations (mean_rank, %first, %top-n) |
| `lib/ranking/ranking_crosstabs.R` | 318 | Ranking crosstab row creation per banner |
| | **2,088** | |

### Banner & Cell Calculations

| File | Lines | Purpose |
|---|---:|---|
| `lib/banner.R` | 588 | Create banner (column) structure with metadata |
| `lib/banner_indices.R` | 555 | Memory-optimised banner row indices |
| `lib/cell_calculator.R` | 752 | Core cell and row calculations (vectorised rating mean) |
| | **1,895** | |

### Weighting & Statistics

| File | Lines | Purpose |
|---|---:|---|
| `lib/weighting.R` | 1,587 | Weighted analysis, Kish effective-n, z-test, t-test, chi-square |
| | **1,587** | |

### Excel Output

| File | Lines | Purpose |
|---|---:|---|
| `lib/excel_writer.R` | 1,768 | Write crosstab workbook + config-aware Guide sheet |
| `lib/excel_utils.R` | 151 | Excel column letter generation and value formatting |
| `lib/summary_builder.R` | 658 | Build Index_Summary sheet with metrics |
| | **2,577** | |

### HTML Report System (R)

| File | Lines | Purpose |
|---|---:|---|
| `lib/html_report/00_html_guard.R` | 181 | Input validation; package checks (htmltools, jsonlite) |
| `lib/html_report/01_data_transformer.R` | 541 | Transform results to HTML structures |
| `lib/html_report/02_table_builder.R` | 327 | Build HTML table elements with data attributes |
| `lib/html_report/03_page_builder.R` | 342 | Page assembler + JS module loader (V10.8 split) |
| `lib/html_report/03a_page_styling.R` | 926 | CSS stylesheet + print CSS (extracted from 03) |
| `lib/html_report/03b_page_components.R` | 1,105 | Layout components, question containers, qualitative (extracted from 03) |
| `lib/html_report/04_html_writer.R` | 111 | Write self-contained HTML file |
| `lib/html_report/05_dashboard_transformer.R` | 510 | Extract headline metrics for dashboard |
| `lib/html_report/06_dashboard_builder.R` | 1,037 | Dashboard orchestrator + component builders (V10.8 split) |
| `lib/html_report/06a_dashboard_js.R` | 492 | Dashboard JavaScript (heatmap export, gauge interactions, extracted from 06) |
| `lib/html_report/06b_dashboard_styling.R` | 488 | Dashboard CSS + colour system (extracted from 06) |
| `lib/html_report/07_chart_builder.R` | 767 | Inline SVG chart generation (semantic palettes) |
| `lib/html_report/99_html_report_main.R` | 452 | HTML report entry point (guard, transform, build, write) |
| | **7,279** | |

### HTML Report (JavaScript)

| File | Lines | Purpose |
|---|---:|---|
| `lib/html_report/js/core_navigation.js` | 658 | Question navigation, search, help overlay |
| `lib/html_report/js/chart_picker.js` | 731 | Chart column picker, SVG rebuild, PNG export |
| `lib/html_report/js/table_export_init.js` | 495 | CSV/Excel export, column toggle, sort |
| `lib/html_report/js/pinned_views.js` | 1,804 | Multi-pin, view capture, Markdown editor |
| `lib/html_report/js/slide_export.js` | 467 | Slide PNG export (1280x720 at 3x) |
| | **4,155** | |

### Utility Modules

| File | Lines | Purpose |
|---|---:|---|
| `lib/shared_functions.R` | 347 | Module orchestrator; sources utility modules in order |
| `lib/logging_utils.R` | 191 | Logging, progress, memory monitoring |
| `lib/type_utils.R` | 170 | Safe type conversion (safe_logical, safe_numeric, safe_equal) |
| `lib/path_utils.R` | 234 | Path handling (resolve_path with absolute path detection + trimws, tabs_lib_path, tabs_source) |
| `lib/filter_utils.R` | 211 | Base filter application and security validation |
| | **1,150** | |

### Tests

| File | Lines | Assertions | Coverage |
|---|---:|---:|---|
| `tests/testthat/test_tabs_core.R` | 1,317 | 243 | Guard state, status, type conversion, config, validation gates |
| `tests/testthat/test_calculations.R` | 508 | 56 | Rating mean, cell data, significance testing (weighted/unweighted) |
| `tests/testthat/test_utilities.R` | 428 | 96 | safe_logical, safe_numeric, safe_equal, config, path, filter, format, excel_col, validate |
| `tests/testthat/test_bugfixes_v10_8.R` | 575 | 56 | V10.8 regression tests: FP tolerance, Bessel SD, closure scoping, sig letters, tie-breaking, banner labels |
| `tests/testthat/test_banner.R` | 464 | 46 | Banner structure, excel letters, banner labels, row indices, bases, Kish formula |
| `tests/testthat/test_data_loading.R` | 301 | 35 | resolve_path (absolute/relative/whitespace), config header auto-detect, survey structure, table sheets |
| `tests/testthat/test_numeric_processor.R` | 287 | 32 | IQR outliers, numeric bins, statistics (mean/SD/median/mode, weighted/unweighted) |
| `tests/testthat/test_excel_output.R` | 581 | 63 | Excel styles, row style mapping, banner headers, base rows, question tables, summary/guide/error sheets, E2E file write |
| `tests/testthat/test_html_report.R` | 454 | 45 | Guard validation, banner groups, data transformation, E2E HTML generation with content verification |
| | **4,915** | **560** | |

------------------------------------------------------------------------

## Error Handling Compliance

### stop() Usage Audit

| File | Line | Context | Justified |
|---|---|---|---|
| `00_guard.R:67` | TRS fallback stub | Yes - must halt when TRS not loaded |
| `00_guard.R:70` | with_refusal_handler fallback | Yes - re-throw pattern |
| `config_utils.R:142` | Re-throw turas_refusal | Yes - re-throw pattern |
| `data_loader.R:148` | Re-throw turas_refusal | Yes - re-throw pattern |
| `question_orchestrator.R:246` | Re-throw turas_refusal | Yes - re-throw pattern |
| `99_html_report_main.R:78` | Halt after console output | Yes - top-level, must halt sourcing |
| `generate_config_templates.R:31` | Standalone tool fallback | Yes - TRS may not be loaded |

**Zero unjustified stop() calls remain.** All error paths use either TRS refusals or console-visible cat() output.

### warning() Usage Audit

**Zero warning() calls remain in active code.** All converted to `cat("[WARNING] ...")` for guaranteed Shiny console visibility.

------------------------------------------------------------------------

## Quality Assessment

### Test Coverage

| Area | Tested | Not Tested |
|---|---|---|
| Guard state initialisation | Yes (24 assertions) | |
| Status determination | Yes (18 assertions) | |
| Type conversion | Yes (45 assertions) | |
| Config retrieval | Yes (24 assertions) | |
| Validation gates | Yes (42 assertions) | |
| Cell calculations | Yes (24 assertions) | |
| Rating mean (weighted/unweighted) | Yes (16 assertions) | |
| Significance testing (z-test) | Yes (16 + 14 V10.8 assertions) | |
| Path resolution | Yes (12 assertions) | |
| Filter security | Yes (8 assertions) | |
| Excel column letters | Yes (6 assertions) | |
| Floating-point tolerance (weighted z-test) | Yes (6 V10.8 assertions) | |
| Bessel-corrected weighted variance | Yes (4 V10.8 assertions) | |
| Ranking metrics (tie-breaking) | Yes (4 V10.8 assertions) | |
| Ranking crosstab row creation | Yes (8 V10.8 assertions) | |
| Composite sig_letters lookup | Yes (3 V10.8 assertions) | |
| Banner label priority (HTML report) | Yes (5 V10.8 assertions) | |
| Banner creation & indices | Yes (46 assertions) | |
| Data loading & path resolution | Yes (35 assertions) | |
| Numeric processor (outliers, bins, stats) | Yes (32 assertions) | |
| Excel output (styles, headers, tables, E2E) | Yes (63 assertions) | |
| HTML report generation (guard, transform, E2E) | Yes (45 assertions) | |

**Honest assessment:** 560 assertions across 9 test files cover core calculations, guard logic, utilities, validation, V10.8 bug fix regressions, banner creation, data loading, numeric processing, Excel output, and HTML report generation end-to-end. All 7 bugs found during systematic code review have regression tests. The Excel output tests also uncovered and fixed a missing `config` argument bug in `write_question_table` → `write_base_rows`.

### Key Strengths

1. **Zero silent failures** - All errors visible in Shiny console via cat() or TRS refusals
2. **Comprehensive validation** - 7 validator modules with 16 pre-flight cross-checks
3. **No function shadowing** - Duplicate definitions removed from config_loader.R
4. **No dead code** - Deprecated run_crosstabs_helpers.R deleted; config_loader.R reduced to stub (all functions moved to canonical modules)
5. **Memory-efficient** - Index-based banner subsetting; vectorised rating mean
6. **Self-contained HTML** - Zero external dependencies; pure SVG charts
7. **Config safety** - Unrecognised settings trigger console warning (typo detection)
8. **Modular HTML report** - Largest files split into focused submodules (V10.8.1: no file > 1,105 lines)
9. **Bessel-corrected statistics** - Weighted SD uses sample variance (V10.8)
10. **Floating-point safe** - Weighted z-test tolerates FP noise in 100% cells (V10.8)

### Known Limitations

1. `run_crosstabs.R` uses `return()` at top-level scope (works in Shiny but not from bare R console)

------------------------------------------------------------------------

## Architecture Diagram

```
+-----------------------------------------------------------+
|              run_tabs_gui.R (Shiny)                       |
|              run_tabs.R (Script)                          |
+--------------------------+--------------------------------+
                           |
                           v
+--------------------------+--------------------------------+
|                   run_crosstabs.R                         |
|                   (Main Orchestrator)                     |
+--+------------+------------+------------+-----------------+
   |            |            |            |
   v            v            v            v
+--------+ +----------+ +----------+ +----------------+
| Config | | Data     | | Analysis | | Workbook       |
| Loader | | Setup    | | Runner   | | Builder        |
+---+----+ +----+-----+ +----+-----+ +---+------------+
    |           |             |            |
    v           v             v            v
crosstabs  data_setup   +----------+  +--------------+
_config.R  .R            | Validate |  | Excel Writer |
                         | (5 mods) |  | + Guide      |
                         +----+-----+  +--------------+
                              |        | HTML Report   |
                              v        | (13 R + 5 JS) |
                         +----------+  +--------------+
                         | Question |
                         | Dispatch |
                         +--+--+----+
                   +--------+  +--------+
                   v                    v
             +----------+        +----------+
             | Standard |        | Numeric  |
             | Processor|        | Processor|
             +----------+        +----------+
                   |                    |
                   v                    v
             +------------------------------+
             |     Cell Calculator          |
             |     Banner Indices           |
             |     Weighting                |
             +------------------------------+
```
