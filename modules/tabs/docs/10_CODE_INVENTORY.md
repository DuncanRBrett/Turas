# Turas Tabs Module - Code Inventory

**Generated:** 8 March 2026 **Total Files:** 52 R + 5 JS = 57 files **Total Lines:** 32,843 R + 3,488 JS = 36,331 lines

------------------------------------------------------------------------

## Summary

| Category                   | Files | Lines | \% of Total |
|----------------------------|-------|-------|-------------|
| Core Orchestration         | 4     | 1,726 | 4.8%        |
| Configuration & Loading    | 4     | 2,817 | 7.8%        |
| Validation System          | 7     | 4,261 | 11.7%       |
| Guard Layer                | 1     | 786   | 2.2%        |
| Question Processing        | 4     | 3,028 | 8.3%        |
| Ranking System             | 4     | 2,088 | 5.7%        |
| Banner & Cell Calculations | 3     | 1,899 | 5.2%        |
| Weighting & Statistics     | 1     | 1,590 | 4.4%        |
| Excel Output               | 4     | 3,234 | 8.9%        |
| HTML Report (R)            | 9     | 6,745 | 18.6%       |
| HTML Report (JS)           | 5     | 3,488 | 9.6%        |
| Utilities                  | 6     | 1,342 | 3.7%        |
| Config Templates           | 1     | 1,354 | 3.7%        |
| Shiny GUI                  | 1     | 651   | 1.8%        |
| Tests                      | 1     | 1,313 | 3.6%        |

------------------------------------------------------------------------

## Detailed File Inventory

### Core Orchestration & Entry Points

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `run_tabs.R` | 92 | Entry point; loads Turas framework before running tabs | Basic loader; sets TURAS_HOME |
| `run_tabs_gui.R` | 651 | Shiny GUI launcher with file browser and progress | Roxygen docs; early_refuse() for TRS; comprehensive UI |
| `lib/run_crosstabs.R` | 636 | Main crosstabs orchestrator (lean V10.2 refactor) | Well-structured; delegates to submodules; clear flow |
| `lib/run_crosstabs_helpers.R` | 291 | Helper functions for run_crosstabs | Print summary, timing estimation |
|  | **1,670** |  |  |

### Configuration & Loading

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/config_loader.R` | 684 | Load and parse Excel config files | V1.1; comprehensive; shared utility integration |
| `lib/config_utils.R` | 293 | Typed getter functions for config values | V10.0; modular; safe type conversion |
| `lib/data_loader.R` | 433 | Survey structure and data loading (.xlsx, .csv, .sav) | V10.1; smart caching; multi-format |
| `lib/generate_config_templates.R` | 1,354 | Generate professional hardened Excel templates | Dropdowns, validation, colour coding, help text |
|  | **2,764** |  |  |

### Crosstabs Submodules (Phase 4 Refactoring)

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/crosstabs/crosstabs_config.R` | 486 | Build config_obj with 62 typed settings | V10.2; overwrites config_loader at source time |
| `lib/crosstabs/data_setup.R` | 317 | Orchestrate structure/data/weight loading | V10.2; extracted from run_crosstabs |
| `lib/crosstabs/analysis_runner.R` | 570 | Validation, banner creation, question processing | V10.2; print_config_summary, progress callbacks |
| `lib/crosstabs/workbook_builder.R` | 657 | Excel workbook assembly (all sheets) | V10.2; builds Summary, Guide, Index, Error Log, Crosstabs |
| `lib/crosstabs/checkpoint.R` | 146 | Save/load/cleanup for resumable analysis | V10.2; enables long-running analysis recovery |
|  | **2,176** |  |  |

### Validation System

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/validation.R` | 1,672 | Core validation orchestrator | V10.1; coordinates 5 validator submodules |
| `lib/validation_utils.R` | 428 | Input validation functions | V10.1; data frame, numeric, logical, file checks |
| `lib/validation/structure_validators.R` | 208 | Survey structure validation | V10.1; duplicate questions, option validity |
| `lib/validation/config_validators.R` | 253 | Configuration parameter validation | V10.1; alpha, min_base, decimal places |
| `lib/validation/weight_validators.R` | 375 | Weight column and value validation | V10.1; DEFF calculation, distribution checks |
| `lib/validation/data_validators.R` | 398 | Data type and format validation | V10.1; multi-mention, single column, numeric |
| `lib/validation/preflight_validators.R` | 927 | Cross-referential pre-flight checks | V10.3; 16 checks; config ↔ structure ↔ data |
|  | **4,261** |  |  |

### Guard Layer

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/00_guard.R` | 786 | TRS guard layer, path resolution, sourcing | V1.0 TRS; tabs_refuse(), tabs_source(), guard state |
|  | **786** |  |  |

### Question Processing

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/question_orchestrator.R` | 675 | Question data preparation and coordination | V1.0; prepare_question_data(); base filter application |
| `lib/question_dispatcher.R` | 423 | Route questions to processors by Variable_Type | Routes to standard, ranking, numeric processors |
| `lib/standard_processor.R` | 1,338 | Process Single/Multi/Likert/Rating questions | V1.0; boxcategory summaries; net calculations |
| `lib/numeric_processor.R` | 592 | Process Numeric questions with bins | V1.0; mean, median, mode, SD; outlier detection |
|  | **3,028** |  |  |

### Composite Metrics

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/composite_processor.R` | 825 | Composite metrics combining multiple questions | V1.0.1; validates definitions; weighted significance |
|  | **825** |  |  |

### Ranking System

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/ranking.R` | 1,019 | Ranking question orchestration | V10.1; refactored with 3 submodules |
| `lib/ranking/ranking_validation.R` | 200 | Ranking format/position validation | V10.1; format detection, option checks |
| `lib/ranking/ranking_metrics.R` | 557 | Ranking metric calculations | V10.1; percent_ranked_first, mean_rank, variance |
| `lib/ranking/ranking_crosstabs.R` | 312 | Ranking crosstab row creation | V10.1; banner subsets, formatted output |
|  | **2,088** |  |  |

### Banner & Cell Calculations

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/banner.R` | 588 | Create banner (column) structure | Roxygen docs; complete banner metadata; letter assignment |
| `lib/banner_indices.R` | 555 | Memory-optimised banner row indices | V1.0; returns indices only (no weight duplication) |
| `lib/cell_calculator.R` | 756 | Core cell and row calculation functions | Weighted counts, percentages, indices; all row types |
|  | **1,899** |  |  |

### Weighting & Statistics

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/weighting.R` | 1,590 | Weighted analysis and significance testing | V9.9.4 production; Kish effective-n; comprehensive policy |
|  | **1,590** |  |  |

### Excel Output

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/excel_writer.R` | 1,768 | Write crosstab workbook + Guide sheet | V1.2.0; openxlsx; comprehensive styling; config-aware Guide |
| `lib/excel_utils.R` | 151 | Excel column letter generation | V10.0; proper base-26 algorithm; supports up to XFD |
| `lib/summary_builder.R` | 658 | Build Index_Summary sheet with metrics | V1.0; means, indices, NPS, top box; section grouping |
|  | **2,577** |  |  |

### HTML Report System (R)

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/html_report/00_html_guard.R` | 181 | Input validation for HTML report | V10.3.2; TRS refusals; package checks |
| `lib/html_report/01_data_transformer.R` | 533 | Transform results → HTML structures | V10.3; banner groups, metric sections |
| `lib/html_report/02_table_builder.R` | 327 | Build HTML `<table>` elements | V10.3.3; data attributes for heatmap; CSS classes |
| `lib/html_report/03_page_builder.R` | 2,097 | Assemble complete HTML page | V10.3.2; header, sidebar, controls, CSS, JS |
| `lib/html_report/04_html_writer.R` | 111 | Write self-contained HTML file | V10.3.2; validates output paths |
| `lib/html_report/05_dashboard_transformer.R` | 503 | Extract headline metrics for dashboard | V10.4.2; config-driven; gauges, heatmap grids |
| `lib/html_report/06_dashboard_builder.R` | 1,951 | Dashboard components (gauges, heatmap, findings) | V10.4.3; configurable colour breaks; Excel export |
| `lib/html_report/07_chart_builder.R` | 608 | Inline SVG chart generation | V10.5.0; stacked/horizontal bars; semantic palette |
| `lib/html_report/99_html_report_main.R` | 434 | HTML report entry point | V10.3.2; guard → transform → build → write |
|  | **6,745** |  |  |

### HTML Report (JavaScript)

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/html_report/js/core_navigation.js` | 572 | Question navigation, search, help overlay | Banner switching, insight management per banner |
| `lib/html_report/js/chart_picker.js` | 613 | Chart column picker, SVG rebuild, PNG export | Multi-column SVG; luminance-aware text contrast |
| `lib/html_report/js/table_export_init.js` | 443 | CSV/Excel export, column toggle, sort | Excel XML export; stable sort; chart bar sync |
| `lib/html_report/js/pinned_views.js` | 1,381 | Multi-pin, view capture, Markdown editor | Persistent storage; Markdown rendering; sign cards |
| `lib/html_report/js/slide_export.js` | 479 | Slide PNG export (chart/table/both) | 1280x720 at 3x; stacked layout; multi-mode |
|  | **3,488** |  |  |

### Utility Modules

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `lib/shared_functions.R` | 347 | Module orchestrator for utility functions | V10.1; sources utility modules in order |
| `lib/logging_utils.R` | 189 | Logging and monitoring utilities | V10.0; timestamp logging, memory monitoring |
| `lib/type_utils.R` | 166 | Safe type conversion and comparison | V10.0; safe_logical, safe_numeric; NA-aware |
| `lib/path_utils.R` | 208 | Path handling and module sourcing | V10.1; tabs_lib_path, tabs_source |
| `lib/filter_utils.R` | 211 | Base filter application and validation | V10.1; filter expression security |
|  | **1,121** |  |  |

### Tests

| File | Lines | Purpose | Quality |
|----|---:|----|----|
| `tests/testthat/test_tabs_core.R` | 1,313 | Core unit tests | Guard state, config loading, validation; testthat |
|  | **1,313** |  |  |

------------------------------------------------------------------------

## Quality Assessment

### Scoring Criteria

| Criterion      | Weight | Description                                        |
|----------------|--------|----------------------------------------------------|
| TRS Compliance | 20%    | Uses structured refusals, never stop()             |
| Documentation  | 15%    | Roxygen headers, version history, inline comments  |
| Error Handling | 15%    | Guard layers, validation, console output for Shiny |
| Modularity     | 15%    | Single responsibility, clear interfaces            |
| Test Coverage  | 15%    | Unit tests, edge cases, integration tests          |
| Code Style     | 10%    | Consistent naming, formatting, no hardcoded paths  |
| Performance    | 10%    | Vectorised operations, memory management           |

### Module Ratings

| Module | Score | Strengths | Improvement Areas |
|----|---:|----|----|
| Guard Layer | 90 | Solid TRS integration; reliable path resolution | \- |
| Configuration | 88 | Comprehensive; typed defaults; template generator | \- |
| Validation | 92 | 5 validator submodules; 16 pre-flight checks; excellent error messages | \- |
| Question Processing | 85 | Clean dispatcher pattern; handles all types | Some long functions in standard_processor |
| Ranking | 88 | Well-decomposed submodules; rigorous metrics | \- |
| Banner/Cell Calc | 87 | Memory-optimised; index-based subsetting | \- |
| Weighting | 90 | Correct Kish formula; comprehensive weight policy | \- |
| Excel Output | 85 | Config-aware Guide sheet; comprehensive formatting | excel_writer.R at 1,768 lines could split further |
| HTML Report (R) | 88 | Self-contained; zero dependencies; dashboard system | page_builder at 2,097 lines is large |
| HTML Report (JS) | 85 | Feature-rich; persistent state; export capabilities | No minification; interdependent modules |
| Utilities | 82 | Clean extraction from shared_functions | \- |
| Tests | 40 | Good patterns where they exist | Only 1 test file; coverage well below 80% target |
| **Overall** | **85** | Production-ready with strong architecture | Test coverage is the primary gap |

### Key Strengths

1.  **Comprehensive validation pipeline** — 7 validator modules with 16 pre-flight cross-checks catch most configuration mistakes before analysis runs
2.  **TRS compliance** — Structured refusals throughout; never uses stop(); console output for Shiny debugging
3.  **Modular architecture** — Phase 2-4 refactoring decomposed large files into focused submodules
4.  **Self-documenting output** — Guide sheet adapts to config; Error Log captures all issues
5.  **Zero-dependency HTML reports** — Pure SVG charts; self-contained files; interactive features
6.  **Memory-efficient design** — Index-based banner subsetting; no weight duplication

### Primary Gap

**Test coverage** is estimated at under 10%. The single test file (`test_tabs_core.R`, 1,313 lines) covers guard state, config loading, and basic validation. The CLAUDE.md target is 80%+ coverage. Priority test areas:

1.  `standard_processor.R` — Most-used processor, many code paths
2.  `cell_calculator.R` — Core calculations, edge cases with zero bases
3.  `weighting.R` — Statistical correctness is critical
4.  `preflight_validators.R` — 16 checks need verification
5.  `excel_writer.R` — Guide sheet content generation

------------------------------------------------------------------------

## Architecture Diagram

```         
┌─────────────────────────────────────────────────────────────┐
│                    run_tabs_gui.R (Shiny)                    │
│                    run_tabs.R (Script)                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   run_crosstabs.R                            │
│                   (Main Orchestrator)                        │
└──┬──────────────┬──────────────┬──────────────┬─────────────┘
   │              │              │              │
   ▼              ▼              ▼              ▼
┌────────┐  ┌──────────┐  ┌──────────┐  ┌────────────────┐
│ Config │  │ Data     │  │ Analysis │  │ Workbook       │
│ Loader │  │ Setup    │  │ Runner   │  │ Builder        │
└────┬───┘  └────┬─────┘  └────┬─────┘  └───┬────────────┘
     │           │              │             │
     ▼           ▼              ▼             ▼
 crosstabs   data_setup   ┌─────────┐   ┌─────────────┐
 _config.R   .R           │Validate │   │ Excel Writer │
                          │(5 mods) │   │ + Guide      │
                          └────┬────┘   ├─────────────┤
                               │        │ HTML Report  │
                               ▼        │ (9 R + 5 JS) │
                          ┌─────────┐   └─────────────┘
                          │Question │
                          │Dispatch │
                          └──┬──┬───┘
                    ┌────────┘  └────────┐
                    ▼                    ▼
              ┌──────────┐        ┌──────────┐
              │ Standard │        │ Numeric  │
              │ Processor│        │ Processor│
              └──────────┘        └──────────┘
                    │                    │
                    ▼                    ▼
              ┌──────────────────────────────┐
              │     Cell Calculator          │
              │     Banner Indices           │
              │     Weighting                │
              └──────────────────────────────┘
```
