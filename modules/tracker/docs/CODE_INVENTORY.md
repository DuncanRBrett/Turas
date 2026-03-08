# Turas Tracker Module -- Code Inventory

**Module:** Tracker **Version:** v10.1 **Last Updated:** 2026-03-08 **Platform:** Turas Analytics (The Research LampPost Pty Ltd)

------------------------------------------------------------------------

## Module Overview

Turas Tracker performs longitudinal tracking analysis across multiple survey waves. It detects trends, calculates the significance of changes between waves, and generates comprehensive Excel and interactive HTML reports. The module supports weighted data, banner segment breakdowns, and five report types: detailed, wave_history, dashboard, sig_matrix, and tracking_crosstab.

All code follows TRS v1.0 (Turas Refusal System) conventions -- structured refusals with actionable error messages replace silent failures or `stop()` calls throughout.

------------------------------------------------------------------------

## Summary Statistics

| Category                     |  Files |        Lines | \% of Total |
|------------------------------|-------:|-------------:|------------:|
| Root Entry Points            |      2 |        1,506 |        7.0% |
| Core Library (lib/)          |     19 |       13,296 |       61.9% |
| Validation (lib/validation/) |      1 |        1,141 |        5.3% |
| HTML Report -- R             |      6 |        3,373 |       15.7% |
| HTML Report -- JS            |      8 |        4,532 |       21.1% |
| HTML Report -- CSS           |      1 |          511 |        2.4% |
| **Total R**                  | **28** | **\~19,316** |             |
| **Total JS**                 |  **8** |  **\~4,532** |             |
| **Total CSS**                |  **1** |      **511** |             |
| **Grand Total**              | **37** | **\~24,359** |             |

> Note: "Total R" includes root entry points, core library, validation, and HTML report R files. Percentages in the category column are relative to the grand total across all languages.

------------------------------------------------------------------------

## Detailed File Inventory

### Root Entry Points

| File | Lines | Purpose | Quality | Notes |
|----|---:|----|---:|----|
| `run_tracker.R` | 790 | Main orchestration script; entry point for tracking analysis. Coordinates config loading, data loading, validation, computation, and output generation. | 88 | Large orchestration file; handles all five report types. Could benefit from further decomposition. |
| `run_tracker_gui.R` | 716 | Shiny GUI providing file pickers, project memory, and progress tracking for interactive use. | 85 | Tightly coupled to Shiny; handles UI state and reactive logic. Progress tracking is well implemented. |

**Subtotal:** 2 files, 1,506 lines

------------------------------------------------------------------------

### Core Library (lib/)

| File | Lines | Purpose | Quality | Notes |
|----|---:|----|---:|----|
| `00_guard.R` | 787 | TRS v1.0 guard layer. Validates all inputs, resolves file paths, checks config structure before processing begins. | 93 | Comprehensive validation with clear refusal codes. Central to module reliability. |
| `constants.R` | 102 | Statistical thresholds and formatting constants (significance levels, colour palettes, label formats). | 82 | Simple and stable. Rarely changes. |
| `metric_types.R` | 327 | Metric type enumerations and validation logic (v10.1). Defines supported metric types and their properties. | 88 | Clean enum pattern. Centralises metric definitions. |
| `formatting_utils.R` | 83 | String formatting utilities for labels, percentages, and display values. | 80 | Small utility file. Functional and straightforward. |
| `output_formatting.R` | 92 | Excel cell formatting helpers (v10.1). Creates reusable `openxlsx` style objects for consistent report appearance. | 82 | Well-scoped. Works with openxlsx style system. |
| `generate_config_templates.R` | 650 | Generates professional Excel configuration templates (tracking_config.xlsx and question_mapping.xlsx) with formatting, validation dropdowns, and instructional sheets. | 87 | Thorough template generation. Good user experience for config setup. |
| `tracker_config_loader.R` | 572 | Parses tracking_config.xlsx and question_mapping.xlsx into structured R config objects. Handles sheet selection, column mapping, and defaults. | 88 | Robust parsing with clear error messages for malformed configs. |
| `wave_loader.R` | 1,238 | Loads survey data from CSV, XLSX, SAV, and DTA formats. Auto-detects file type, handles encoding, applies column type coercion, supports multiple waves. | 90 | Largest loader file. Multi-format support is well implemented. Good auto-detection logic. |
| `question_mapper.R` | 929 | Cross-wave question mapping and variable resolution. Maps variable names across waves when surveys change column names between fielding periods. | 89 | Critical for multi-wave tracking. Handles renamed and merged variables. |
| `validation_tracker.R` | 574 | Seven-point validation suite for data integrity. Checks completeness, type consistency, range validity, and cross-wave compatibility. | 91 | Thorough validation. Each check returns structured results with clear diagnostics. |
| `statistical_core.R` | 553 | Core statistical calculations: means, proportions, weighted estimates, standard errors, and design-effect adjustments. | 92 | Well-tested statistical engine. Uses `survey` package for design-aware estimation where applicable. |
| `trend_calculator.R` | 1,508 | Main trend orchestration and routing. Dispatches to appropriate calculation methods based on metric type and aggregation level. | 88 | Largest core file. Central routing logic is clear but file size warrants attention. |
| `trend_changes.R` | 298 | Wave-over-wave change calculations (v10.1). Computes absolute and relative differences between consecutive waves. | 90 | Clean, focused module. Clear separation from significance testing. |
| `trend_significance.R` | 418 | Statistical significance testing: Z-tests for proportions, T-tests for means, significance indicator assignment (v10.1). | 91 | Correct test selection logic. Handles weighted and unweighted cases. |
| `banner_trends.R` | 462 | Banner segment and demographic breakdown analysis. Calculates trends within subgroups defined by banner variables. | 87 | Extends trend analysis to segments. Good integration with trend_calculator. |
| `tracker_output.R` | 2,282 | Main Excel output generation. Produces detailed, wave_history, and dashboard report sheets with formatting, conditional highlighting, and summary rows. | 85 | Largest file in the module. Functional but a candidate for decomposition into smaller, focused writers. |
| `tracker_dashboard_reports.R` | 1,325 | Dashboard and significance matrix report generation. Produces compact executive summary and pairwise significance comparison sheets. | 85 | Large output file. Works well but closely coupled to tracker_output.R formatting conventions. |
| `tracking_crosstab_engine.R` | 701 | Crosstab calculation engine for tracking data. Computes cross-tabulations with wave-awareness and weighting support. | 88 | Solid engine. Integrates with the tabs module pattern for consistency. |
| `tracking_crosstab_excel.R` | 855 | Crosstab-format Excel export. Writes cross-tabulation results with professional formatting, banding, and significance markers. | 85 | Well-formatted output. Handles multi-level headers and merged cells. |

**Subtotal:** 19 files, 13,296 lines

------------------------------------------------------------------------

### Validation (lib/validation/)

| File | Lines | Purpose | Quality | Notes |
|----|---:|----|---:|----|
| `preflight_validators.R` | 1,141 | Pre-flight cross-referential validation checks (v10.1). Validates config-to-data alignment, wave ordering, variable existence across all waves, and banner variable availability before computation starts. | 92 | Thorough pre-flight system. Catches config-data mismatches early. Returns detailed diagnostic lists. |

**Subtotal:** 1 file, 1,141 lines

------------------------------------------------------------------------

### HTML Report -- R Files (lib/html_report/)

| File | Lines | Purpose | Quality | Notes |
|----|---:|----|---:|----|
| `00_html_guard.R` | 102 | Input validation for HTML report generation. Checks that transformed data and config are valid before building HTML. | 90 | Small, focused guard layer. TRS compliant. |
| `01_data_transformer.R` | 332 | Transforms tracker output data into HTML-ready structures. Reshapes tables, computes display values, prepares chart data series. | 88 | Clean transformation pipeline. Good separation from rendering logic. |
| `02_table_builder.R` | 347 | Builds HTML table elements with significance highlighting, banding, and responsive column headers. | 87 | Well-structured table generation. Handles multi-wave layouts. |
| `03_page_builder.R` | 1,865 | Main HTML page structure and layout. Assembles all sections, injects inline CSS and JS, builds navigation, produces self-contained HTML document. Largest R file in the HTML report subsystem. | 86 | Very large file. Produces fully self-contained reports (no external dependencies). Could benefit from further modularisation. |
| `04_html_writer.R` | 102 | Writes the assembled HTML string to a self-contained .html file with proper encoding and BOM handling. | 85 | Simple writer. Handles file I/O edge cases. |
| `05_chart_builder.R` | 519 | SVG trend line chart generation. Produces inline SVG charts with data points, trend lines, axis labels, and responsive scaling. | 88 | Good chart quality. Follows the Turas visual style guidelines (rounded corners, muted palette, decluttered grids). |
| `99_html_report_main.R` | 106 | HTML report orchestration entry point. Coordinates the guard, transformer, table builder, page builder, chart builder, and writer into a single pipeline. | 88 | Clean orchestration. Follows the standard Turas module pattern. |

**Subtotal:** 6 files, 3,373 lines

------------------------------------------------------------------------

### HTML Report -- JavaScript Files (lib/html_report/js/)

| File | Lines | Purpose | Quality | Notes |
|----|---:|----|---:|----|
| `chart_controls.js` | 401 | Multi-metric chart selection UI and SVG rendering controls. Manages chart type switching and metric visibility toggles. | 85 | Feature-rich. Handles dynamic SVG updates. |
| `core_navigation.js` | 1,095 | Main navigation and interaction controller. Handles section switching, scroll state, keyboard shortcuts, and responsive layout adjustments. Largest JS file. | 84 | Central controller. Complex interaction state management. Could benefit from splitting navigation and interaction concerns. |
| `metric_nav_filter.js` | 46 | Metric filtering for navigation sidebar. Provides quick-filter input for metric lists. | 80 | Minimal utility. Functional. |
| `metrics_view.js` | 877 | Metrics display and interaction. Renders metric cards, handles selection, manages comparison views between waves. | 85 | Good separation of display logic. Manages complex card states. |
| `pinned_views.js` | 1,373 | Pinned panel management with localStorage persistence. Allows users to pin metrics for persistent cross-section comparison. Largest feature file. | 86 | Sophisticated persistence layer. Handles edge cases around storage limits and data staleness. |
| `slide_export.js` | 509 | Export report sections as PNG slides. Uses html2canvas for client-side rendering with custom slide layouts. | 83 | Functional export. Depends on html2canvas being available inline. |
| `tab_navigation.js` | 35 | Banner tab switching logic. Handles click events for banner segment tabs. | 80 | Minimal utility. Straightforward event handling. |
| `table_export.js` | 196 | CSV export functionality. Extracts table data from HTML and generates downloadable CSV files. | 83 | Clean extraction logic. Handles merged cells and multi-row headers. |

**Subtotal:** 8 files, 4,532 lines

------------------------------------------------------------------------

### HTML Report -- CSS (lib/html_report/)

| File | Lines | Purpose | Quality | Notes |
|----|---:|----|---:|----|
| `tracker_styles.css` | 511 | Complete styling for the interactive HTML report. Covers layout, tables, charts, navigation, print media queries, and responsive breakpoints. | 85 | Comprehensive stylesheet. Follows Turas visual identity. Single-file approach keeps reports self-contained. |

**Subtotal:** 1 file, 511 lines

------------------------------------------------------------------------

## Architecture Diagram

```         
                          TURAS TRACKER -- DATA FLOW
  ===========================================================================

  +-----------------------+     +------------------------+
  | tracking_config.xlsx  |     | question_mapping.xlsx  |
  | (report settings,     |     | (cross-wave variable   |
  |  metric definitions,  |     |  name mappings)        |
  |  banner specs)        |     |                        |
  +-----------+-----------+     +-----------+------------+
              |                             |
              v                             v
  +-----------------------------------------------------------+
  |                    00_guard.R                              |
  |         TRS v1.0 Input Validation & Path Resolution       |
  +----------------------------+------------------------------+
                               |
                               v
  +-----------------------------------------------------------+
  |                tracker_config_loader.R                     |
  |         Parse Excel configs into R structures              |
  +----------------------------+------------------------------+
                               |
              +----------------+----------------+
              |                                 |
              v                                 v
  +------------------------+     +----------------------------+
  |    wave_loader.R       |     |   question_mapper.R        |
  |  Load survey data      |     |  Map variables across      |
  |  (CSV/XLSX/SAV/DTA)    |     |  waves                     |
  +----------+-------------+     +-------------+--------------+
             |                                 |
             +----------------+----------------+
                              |
                              v
  +-----------------------------------------------------------+
  |  preflight_validators.R + validation_tracker.R            |
  |      Pre-flight checks & 7-point data validation          |
  +----------------------------+------------------------------+
                               |
                               v
  +-----------------------------------------------------------+
  |                  statistical_core.R                        |
  |     Means, proportions, weighted estimates, std errors     |
  +----------------------------+------------------------------+
                               |
                               v
  +-----------------------------------------------------------+
  |                  trend_calculator.R                        |
  |           Main trend orchestration & routing               |
  +------+-----------------+-----------------+----------------+
         |                 |                 |
         v                 v                 v
  +--------------+  +---------------+  +----------------+
  | trend_       |  | trend_        |  | banner_        |
  | changes.R    |  | significance.R|  | trends.R       |
  | Wave-over-   |  | Z-tests,     |  | Segment/demo   |
  | wave deltas  |  | T-tests      |  | breakdowns     |
  +-------+------+  +-------+------+  +--------+-------+
          |                 |                   |
          +--------+--------+-------------------+
                   |
                   v
  +------------------------------+    +---------------------------+
  |       EXCEL OUTPUT           |    |       HTML OUTPUT          |
  |------------------------------|    |---------------------------|
  | tracker_output.R             |    | 99_html_report_main.R     |
  | tracker_dashboard_reports.R  |    |   00_html_guard.R         |
  | tracking_crosstab_engine.R   |    |   01_data_transformer.R   |
  | tracking_crosstab_excel.R    |    |   02_table_builder.R      |
  | output_formatting.R         |    |   03_page_builder.R       |
  |                              |    |   04_html_writer.R        |
  |  Report Types:               |    |   05_chart_builder.R      |
  |  - Detailed                  |    |                           |
  |  - Wave History              |    |  Assets:                  |
  |  - Dashboard                 |    |  - js/ (8 files)          |
  |  - Significance Matrix       |    |  - tracker_styles.css     |
  |  - Tracking Crosstab         |    |                           |
  +------------------------------+    +---------------------------+

  ===========================================================================
  Supporting Files:
    constants.R            -- Statistical thresholds, formatting constants
    metric_types.R         -- Metric type enums and validation
    formatting_utils.R     -- String formatting utilities
    generate_config_templates.R -- Excel template generator

  Entry Points:
    run_tracker.R          -- CLI / script entry point
    run_tracker_gui.R      -- Shiny GUI entry point
  ===========================================================================
```

------------------------------------------------------------------------

## Quality Scoring Criteria

Each file is assigned a quality score out of 100 based on the following criteria:

| Score Range | Rating | Description |
|----|----|----|
| 95 -- 100 | Exceptional | Production-hardened code with comprehensive error handling, thorough documentation, full TRS v1.0 compliance, extensive test coverage, and exemplary code structure. |
| 90 -- 94 | Production-Ready | Reliable production code with good error handling, clear documentation, TRS compliance, and solid test coverage. Minor improvements possible but not urgent. |
| 85 -- 89 | Solid | Strong production code with effective error handling and documentation. May have minor areas for improvement such as large file size or opportunities for further decomposition. |
| 80 -- 84 | Good | Functional and reliable code that meets requirements. Some areas could be more robust, better documented, or more thoroughly tested. |
| 75 -- 79 | Adequate | Code that works correctly but has noticeable gaps in error handling, documentation, or test coverage. Functional but would benefit from a focused improvement pass. |

### Scoring Dimensions

Quality scores reflect assessment across five dimensions:

1.  **Error Handling (25%)** -- TRS v1.0 compliance, structured refusals, actionable error messages, console visibility for Shiny debugging. No use of `stop()` for expected failure modes.

2.  **Code Structure (25%)** -- Single responsibility adherence, function length (target: under 100 lines), clear naming conventions, logical file organisation, appropriate separation of concerns.

3.  **Documentation (20%)** -- Roxygen2 headers on exported functions, inline comments for non-obvious logic, parameter descriptions, return value documentation, usage examples where helpful.

4.  **Robustness (20%)** -- Edge case handling, NA/NULL tolerance, input validation depth, graceful degradation for partial data, weighted data support where applicable.

5.  **Maintainability (10%)** -- Readability, consistent style (styler-compliant), avoidance of magic numbers, use of constants, minimal coupling between files, clear data flow.

### Module-Wide Quality Summary

| Category | Avg Quality | Assessment |
|----|---:|----|
| Guard / Validation | 92 | Strongest area. TRS compliance is thorough and consistent. |
| Core Statistical | 90 | Well-tested and reliable. Correct test selection and weighting support. |
| Config / Loaders | 88 | Solid parsing with good error messages. Multi-format support is well handled. |
| Output (Excel) | 85 | Functional and well-formatted. Largest files in the module; candidates for decomposition. |
| HTML Report (R) | 87 | Good self-contained architecture. Page builder is very large. |
| HTML Report (JS) | 84 | Feature-rich interactive layer. No minification; could benefit from a build step for production. |
| Small Utilities | 81 | Simple, stable files. Low risk, low complexity. |
| **Module Overall** | **87** | **Solid production code. Primary improvement opportunities are in decomposing the largest files (tracker_output.R, page_builder.R, trend_calculator.R) and adding minification for JS assets.** |

------------------------------------------------------------------------

*Generated for the Turas Analytics Platform -- The Research LampPost (Pty) Ltd*
