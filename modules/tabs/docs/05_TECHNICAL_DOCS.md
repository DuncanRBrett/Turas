---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tabs - Technical Documentation

**Version:** 10.8 **Date:** 14 March 2026 **Audience:** Developers,
Technical Contributors, Module Maintainers

This document covers the internal architecture, code structure, and
implementation details of the Tabs module. For user-facing
documentation, see the [User Manual](04_USER_MANUAL.md).

------------------------------------------------------------------------

## Architecture Overview

### Design Philosophy

Tabs follows a pipeline architecture with clear separation of concerns:

```         
Input → Load → Validate → Process → Calculate → Write → Output
```

The design emphasizes: - **Modularity:** Each component has a single
responsibility - **Testability:** Functions are pure where possible with
explicit dependencies - **Fail-Fast:** Validation occurs early with
clear error messages - **Memory Efficiency:** Vectorized operations,
minimal data duplication - **Extensibility:** New question types can be
added without modifying core logic

### Design Patterns

The module uses several established patterns:

**Pipeline Pattern:** Data flows through sequential processing stages.

**Strategy Pattern:** Different processors handle different question
types. The dispatcher routes to the appropriate processor based on
question type.

**Factory Pattern:** The question dispatcher creates processor instances
based on configuration.

**Builder Pattern:** The Excel writer constructs complex output
incrementally, adding sheets and formatting as it goes.

**Modular Extraction Pattern (Phase 2):** Large modules are decomposed
into a core orchestration file with specialized submodules in dedicated
subdirectories. The core file sources submodules using `tabs_source()`
with fallback patterns for backward compatibility:

``` r
if (exists("tabs_source", mode = "function")) {
  tabs_source("validation", "structure_validators.R")
} else {
  # Fallback for direct sourcing
  source(file.path(.validation_dir, "structure_validators.R"))
}
```

------------------------------------------------------------------------

## Module Structure

### File Organization

```
modules/tabs/
├── run_tabs.R                    # Main entry point (~92 lines)
├── run_tabs_gui.R                # Shiny GUI interface (~651 lines)
├── lib/
│   ├── 00_guard.R                # TRS guard layer & sourcing utilities (~786 lines)
│   ├── run_crosstabs.R           # Core orchestration (~636 lines)
│   ├── run_crosstabs_helpers.R   # Helper functions (~291 lines)
│   ├── config_loader.R           # Configuration management (~684 lines)
│   ├── config_utils.R            # Configuration utilities (~293 lines)
│   ├── generate_config_templates.R # Professional config template generator (~1,354 lines)
│   ├── validation.R              # Input validation core (~1,672 lines)
│   ├── validation_utils.R        # Validation utility functions (~428 lines)
│   ├── question_orchestrator.R   # Question preparation (~675 lines)
│   ├── question_dispatcher.R     # Question type routing (~423 lines)
│   ├── standard_processor.R      # Single/Multi processing (~1,338 lines)
│   ├── numeric_processor.R       # Numeric/Rating/NPS processing (~592 lines)
│   ├── composite_processor.R     # Composite metrics (~825 lines)
│   ├── ranking.R                 # Ranking question processing (~1,019 lines)
│   ├── cell_calculator.R         # Cell/row calculations (~756 lines)
│   ├── banner.R                  # Banner structure (~588 lines)
│   ├── banner_indices.R          # Banner indexing (~555 lines)
│   ├── weighting.R               # Weight calculations (~1,590 lines)
│   ├── shared_functions.R        # Utilities (~347 lines)
│   ├── excel_writer.R            # Excel output + Guide sheet (~1,768 lines)
│   ├── excel_utils.R             # Excel utilities (~151 lines)
│   ├── summary_builder.R         # Summary statistics (~658 lines)
│   ├── logging_utils.R           # Logging utilities (~189 lines)
│   ├── type_utils.R              # Type utilities (~166 lines)
│   ├── path_utils.R              # Path handling utilities (~208 lines)
│   ├── filter_utils.R            # Base filter utilities (~211 lines)
│   │
│   ├── validation/               # Validation submodules (Phase 2-3)
│   │   ├── structure_validators.R   # Survey structure validation (~208 lines)
│   │   ├── weight_validators.R      # Weight validation (~375 lines)
│   │   ├── config_validators.R      # Configuration validation (~253 lines)
│   │   ├── data_validators.R        # Data type/format validation (~398 lines)
│   │   └── preflight_validators.R   # Cross-referential pre-flight checks (~927 lines)
│   │
│   ├── ranking/                  # Ranking submodules (Phase 2)
│   │   ├── ranking_validation.R     # Ranking question validation (~200 lines)
│   │   ├── ranking_metrics.R        # Metric calculations (~557 lines)
│   │   └── ranking_crosstabs.R      # Crosstab row creation (~312 lines)
│   │
│   ├── crosstabs/                # Crosstabs submodules (Phase 4)
│   │   ├── crosstabs_config.R       # Config object builder (~486 lines)
│   │   ├── data_setup.R             # Data loading orchestration (~317 lines)
│   │   ├── analysis_runner.R        # Analysis processing orchestration (~570 lines)
│   │   ├── workbook_builder.R       # Excel workbook assembly (~657 lines)
│   │   └── checkpoint.R             # Checkpoint/resume system (~146 lines)
│   │
│   └── html_report/              # HTML report system (V10.3+)
│       ├── 00_html_guard.R          # HTML report input validation (~181 lines)
│       ├── 01_data_transformer.R    # Transform results for HTML (~533 lines)
│       ├── 02_table_builder.R       # Build HTML <table> elements (~327 lines)
│       ├── 03_page_builder.R        # Assemble complete HTML page (~2,097 lines)
│       ├── 04_html_writer.R         # Write HTML to file (~111 lines)
│       ├── 05_dashboard_transformer.R # Extract dashboard metrics (~503 lines)
│       ├── 06_dashboard_builder.R   # Build dashboard components (~1,951 lines)
│       ├── 07_chart_builder.R       # Inline SVG chart generation (~608 lines)
│       ├── 99_html_report_main.R    # HTML report entry point (~434 lines)
│       └── js/                      # Client-side JavaScript
│           ├── core_navigation.js      # Navigation, search, help (~572 lines)
│           ├── chart_picker.js         # Chart column picker, export (~613 lines)
│           ├── table_export_init.js    # CSV/Excel export, sort (~443 lines)
│           ├── pinned_views.js         # View pinning, Markdown editor (~1,381 lines)
│           └── slide_export.js         # Slide PNG export (~479 lines)
```

Total lines of code: approximately 36,330 (R: 32,840 + JS: 3,490).

### Dependencies

**Required R Packages:** - openxlsx: Excel file I/O (no Java
dependency) - htmltools: HTML generation for reports - jsonlite: JSON
serialization

**Optional R Packages:** - data.table: High-performance data operations
(faster CSV reading) - haven: SPSS file support

**Internal Dependencies:** Integrates with `/modules/shared/lib/` for
common utilities (validation_utils, config_utils, formatting_utils).

### HTML Report Subsystem

The HTML report is generated as a post-processing step after Excel output. The pipeline is:

```
Config → Data Transform → Page Build → Dashboard Build → JS Injection → Single-File Output
```

**R files (in `lib/html_report/`):**
| File | Purpose |
|------|---------|
| `99_html_report_main.R` | Orchestrator — coordinates all HTML report generation |
| `01_data_transformer.R` | Transforms crosstab results into HTML-ready data structures |
| `02_chart_builder.R` | Generates SVG charts (bar, stacked bar, line) |
| `03_page_builder.R` | Assembles HTML pages with CSS, tables, and navigation |
| `04_added_slides_builder.R` | Builds the Added Slides tab from config and in-browser content |
| `05_significance_builder.R` | Generates significance findings summary |
| `06_dashboard_builder.R` | Builds the Summary Dashboard with gauges and heatmaps |
| `07_comments_builder.R` | Injects analyst comments into question pages |
| `08_pin_builder.R` | Builds the Pinned Views infrastructure |

**JS files (in `lib/html_report/js/`):**
| File | Purpose |
|------|---------|
| `core_navigation.js` | Tab switching, search, sidebar, keyboard navigation |
| `table_interactions.js` | Heatmap toggle, sort, banner switching, clipboard copy |
| `chart_manager.js` | Chart rendering, resize handling, visibility toggling |
| `pinned_views.js` | Pin/unpin, reorder, SVG-to-PNG export, state persistence |
| `table_export_init.js` | Initialization, PNG export, DOMContentLoaded setup |

**Key design decisions:**
- Single self-contained HTML file — all CSS, JS, and data inline (no external dependencies)
- SVG-native charts — no canvas; enables clean PNG export via SVG serialization
- `BRAND_COLOUR` global JS variable — set once at page load, consumed by all chart/style functions
- Clipboard API detection with `execCommand` fallback for older browsers

Cross-reference: [HTML Report Technical Manual](TABS_HTML_REPORT_TECHNICAL_MANUAL.md) for full implementation details.

------------------------------------------------------------------------

## Core Components

### Guard Module (00_guard.R)

Infrastructure module providing path resolution and sourcing utilities.
This module enables the modular architecture by providing reliable
submodule loading regardless of invocation context.

**Key Functions:**

``` r
tabs_lib_path()
```

Returns the path to the lib directory. Uses global caching for performance
and handles various invocation scenarios (RStudio, command line, sourced).

``` r
tabs_source(subdir, filename)
```

Sources a file from a subdirectory of lib. Provides reliable path
resolution for submodules:

``` r
# Example usage in validation.R
tabs_source("validation", "structure_validators.R")
# Loads: lib/validation/structure_validators.R
```

``` r
tabs_refuse(message, error_log = NULL)
```

TRS (Turas Refusal Standard) error handling. Logs an error and stops
execution with a clear message.

**Global Variables:**
- `.tabs_lib_dir`: Cached library directory path

### Configuration Loader (config_loader.R)

Loads and parses Excel configuration files into R data structures.

**Key Functions:**

``` r
load_crosstab_configuration(config_file, project_root = NULL)
```

Returns a list containing: - `config`: Parsed settings - `paths`:
Resolved file paths - `selection`: Banner and stub question selections -
`validation`: Validation results - `project_root`: Project directory
path

``` r
load_config_settings(config_file, sheet_name = "Settings")
```

Reads the Settings sheet and returns a named list. Handles duplicate
detection, type conversion, and NA handling.

``` r
get_config_value(config_list, setting_name, default_value = NULL, required = FALSE)
```

Safely retrieves a configuration value with a default fallback. Stops
execution if required = TRUE and the value is missing.

### Validation Module (validation.R)

Comprehensive input validation with clear error messages. The validation
module has been refactored into a core file with four specialized submodules.

**Module Structure:**

```
validation.R                      # Core validation orchestration
├── validation/structure_validators.R   # Survey structure validation
├── validation/weight_validators.R      # Weight validation
├── validation/config_validators.R      # Configuration validation
├── validation/data_validators.R        # Data type/format validation
└── validation/preflight_validators.R   # Cross-referential pre-flight checks
```

**Key Functions (Core):**

``` r
validate_survey_structure(survey_structure, error_log = NULL)
```

Validates the Survey Structure file: - Required columns present
(QuestionCode, QuestionText, Variable_Type) - No duplicate
QuestionCodes - Valid Variable_Type values - Questions have matching
options - No orphan options

``` r
validate_survey_data(data, survey_structure, error_log = NULL)
```

Validates the survey data file: - Required question columns exist - Data
types match expectations - No completely empty columns - Multi-mention
column counts match structure

``` r
validate_weights(weights, data, error_log = NULL,
                 weight_na_threshold = 10,
                 weight_zero_threshold = 5,
                 weight_deff_warning = 3)
```

Validates weight values: - Weights are numeric - Length matches data -
NA count below threshold - Zero count below threshold - DEFF below
warning threshold

**Submodule: structure_validators.R**

Validates survey structure file integrity:
- `check_required_columns()` - Verifies required columns exist
- `check_duplicate_codes()` - Detects duplicate QuestionCodes
- `check_variable_types()` - Validates Variable_Type values
- `check_orphan_options()` - Finds options without parent questions

**Submodule: weight_validators.R**

Validates weight column and values:
- `check_weight_column()` - Verifies weight column exists
- `check_weight_numeric()` - Validates numeric type
- `check_weight_length()` - Confirms length matches data
- `check_weight_thresholds()` - Checks NA/zero thresholds
- `check_weight_deff()` - Calculates and validates design effect

**Submodule: config_validators.R**

Validates configuration settings:
- `check_config_required()` - Verifies required settings present
- `check_config_paths()` - Validates file path settings
- `check_config_types()` - Validates setting value types
- `check_banner_selection()` - Validates banner question selection

**Submodule: data_validators.R**

Validates data types and formats:
- `check_multi_mention_columns()` - Validates multi-mention column counts
- `check_single_column()` - Validates single column existence
- `check_numeric_min_max()` - Validates numeric range constraints
- `check_bin_structure()` - Validates binning configuration
- `check_bin_overlaps()` - Detects overlapping bins
- `check_bin_coverage()` - Validates bin coverage
- `validate_numeric_question()` - Comprehensive numeric validation

**Submodule: preflight_validators.R**

Cross-referential validation that runs after data loading, checking
consistency between config, structure, and data:

- `check_selection_vs_questions()` - Selection sheet questions exist in structure
- `check_option_values_vs_data()` - Configured options appear in actual data
- `check_preflight_multi_mention()` - Multi_Mention binary columns exist
- `check_numeric_data_types()` - Numeric questions contain numeric data
- `check_create_index_config()` - CreateIndex + Index_Weight consistency
- `check_banner_variables()` - Banner questions exist in structure + data
- `check_conflicting_display()` - All display metrics disabled warning
- `check_preflight_weight_variable()` - Weight variable existence and validity
- `check_duplicate_options()` - Duplicate OptionCodes within same question
- `check_open_end_selection()` - Open_End questions selected for crosstabs
- `check_base_filter_variables()` - Filter expression variable verification
- `check_data_column_coverage()` - Data columns exist for selected questions
- `check_preflight_logo_files()` - Logo files exist when HTML report enabled
- `check_preflight_colour_codes()` - Valid hex colour codes for HTML report
- `check_preflight_dashboard_scales()` - Dashboard threshold ordering
- `check_preflight_bonferroni()` - Bonferroni with few columns advisory

All preflight functions are prefixed with `check_preflight_` or
`check_` to avoid name collisions with functions in other validator
submodules that share the same global namespace.

**Error Log Structure:**

``` r
error_log <- list(
  errors = list(),    # Critical issues (stop execution)
  warnings = list(),  # Non-critical issues
  info = list()       # Informational messages
)
```

Each entry contains: - `source`: Which component detected the issue -
`category`: What type of issue - `message`: What went wrong - `details`:
Additional context - `severity`: Error, Warning, or Info

### Question Orchestrator (question_orchestrator.R)

Prepares question data for processing.

``` r
prepare_question_data(question_code, base_filter,
                      survey_data, survey_structure,
                      banner_info, master_weights)
```

Returns a list containing: - `question_info`: Metadata for the
question - `question_options`: Response options - `filtered_data`: Data
with base filter applied - `question_weights`: Weights for filtered
data - `banner_row_indices`: Row indices by banner column -
`banner_bases`: Base sizes by banner column - `base_filter`: The applied
filter expression

**Processing steps:** 1. Load metadata from structure 2. Extract
question options 3. Apply base filter (if specified) 4. Create row
indices for each banner column 5. Calculate base sizes (unweighted,
weighted, effective)

### Question Dispatcher (question_dispatcher.R)

Routes questions to the appropriate processor based on type.

``` r
process_question(question_code, base_filter, survey_data,
                 survey_structure, banner_info, master_weights,
                 config, error_log)
```

**Routing logic:** - Composite questions → composite_processor -
Single_Response, Multi_Mention, Rating, NPS, Likert → standard_processor -
Ranking → ranking_processor - Numeric → numeric_processor -
Allocation → allocation_processor

### Standard Processor (standard_processor.R)

Processes Single_Response, Multi_Mention, Rating, NPS, and Likert questions.

``` r
process_standard_question(prepared_data, config, error_log)
```

**Algorithm:** 1. For each response option: - Calculate weighted counts
across banner columns - Create frequency row (if enabled) - Create
percentage row - Calculate significance (if enabled) 2. Combine rows
into result table 3. Return structured result object

**Result structure:**

``` r
list(
  question_code = "Q01",
  question_text = "Which brand do you prefer?",
  question_type = "Single_Response",
  base_filter = NA,
  bases = list(
    Total = list(unweighted = 500, weighted = 500, effective = 450),
    Male = list(unweighted = 250, weighted = 240, effective = 220),
    ...
  ),
  table = data.frame(...),
  significance = data.frame(...)
)
```

### Numeric Processor (numeric_processor.R)

Processes Numeric, Rating, NPS, and Likert questions.

``` r
process_numeric_question(prepared_data, config, error_log)
```

**Rating Questions:** - Shows frequency and percentage for each scale
point - Calculates weighted mean - Optional: Top-2-Box, Bottom-2-Box
percentages - Significance testing on means (t-test)

**NPS Questions:** - Calculates Detractor, Passive, Promoter
percentages - Calculates NPS score (Promoters - Detractors) -
Significance testing on NPS score

**Numeric Questions:** - Calculates mean, median (optional), mode
(optional), standard deviation - Optional: Min/Max, percentiles -
Significance testing on means

### Ranking Processor (ranking.R)

Processes Ranking questions. The ranking module has been refactored into
a core file with three specialized submodules.

**Module Structure:**

```
ranking.R                         # Core ranking orchestration
├── ranking/ranking_validation.R  # Ranking question validation
├── ranking/ranking_metrics.R     # Metric calculations
└── ranking/ranking_crosstabs.R   # Crosstab row creation
```

``` r
process_ranking_question(prepared_data, config, error_log)
```

**Ranking Format Support:**
- **Position Format:** Each column represents a rank position (1st, 2nd, etc.)
- **Item Format:** Each column represents an item being ranked

**Key Metrics:**
- Percent ranked first
- Percent in top N
- Mean rank
- Rank variance

**Submodule: ranking_validation.R**

Validates ranking question configuration:
- `check_ranking_format()` - Validates Ranking_Format setting
- `check_ranking_positions()` - Validates position configuration
- `check_ranking_options()` - Validates ranking options
- `validate_ranking_question()` - Comprehensive validation

**Submodule: ranking_metrics.R**

Calculates ranking-specific metrics:
- `calculate_percent_ranked_first()` - Percent choosing item as #1
- `calculate_percent_top_n()` - Percent choosing item in top N
- `calculate_mean_rank()` - Weighted mean rank for each item
- `calculate_rank_variance()` - Variance of rank positions
- `prepare_rank_comparison_data()` - Prepares data for statistical tests
- `run_mean_rank_test()` - Statistical test on mean ranks
- `compare_mean_ranks()` - Compares mean ranks across banner columns

**Submodule: ranking_crosstabs.R**

Creates crosstab output rows:
- `get_banner_subset_and_weights()` - Extracts banner-specific data
- `format_ranking_value()` - Formats ranking values for output
- `calculate_banner_ranking_metrics()` - Calculates metrics per banner
- `create_ranking_rows_for_item()` - Creates output rows for each item

### Cell Calculator (cell_calculator.R)

Core calculation functions for cells and rows.

**Key Functions:**

``` r
calculate_row_counts(data, banner_row_indices, option_text,
                     question_col, is_multi_mention, existing_cols,
                     internal_keys, master_weights)
```

Calculates weighted counts for one response option across all banner
columns. Returns a named numeric vector.

``` r
calculate_weighted_percentage(weighted_count, weighted_base)
```

Safely calculates percentage with zero-division handling.

``` r
create_percentage_row(row_counts, banner_bases, internal_keys,
                      display_text, show_label = TRUE, decimal_places = 0)
```

Creates a formatted percentage row for the output table.

**Memory Optimization:** The module uses index-based subsetting to avoid
weight duplication:

``` r
# Efficient: Use master_weights[row_idx]
subset_weights <- master_weights[row_idx]

# Inefficient: Create new weight vector
subset_weights <- rep(master_weights, each = n)
```

### Banner Management (banner.R, banner_indices.R)

Manages banner (column) structure and indexing.

**Banner Structure:**

``` r
banner_info <- list(
  display_labels = c("Total", "Male", "Female", "18-34", "35-54", "55+"),
  internal_keys = c("Total", "Q99_Male", "Q99_Female", "Q98_18-34", ...),
  questions = c(NA, "Q99", "Q99", "Q98", "Q98", "Q98"),
  values = c(NA, "Male", "Female", "18-34", "35-54", "55+"),
  column_count = 6
)
```

**Banner Index Creation:**

``` r
create_banner_row_indices(data, banner_info)
```

Returns row indices for each banner column:

``` r
list(
  Total = 1:500,
  Q99_Male = c(1, 3, 5, ...),
  Q99_Female = c(2, 4, 6, ...),
  ...
)
```

### Weighting (weighting.R)

Weight loading, validation, and base calculations.

**Key Functions:**

``` r
load_weights(data, weight_column)
```

Loads weight column from data. Returns vector of weights or vector of 1s
if no weighting.

``` r
calculate_weighted_base(data, question_info, weights)
```

Calculates three base sizes: unweighted, weighted, effective.

``` r
calculate_deff(weights)
```

Calculates Design Effect using coefficient of variation method:

``` r
DEFF = 1 + CV²
```

where CV = standard deviation of weights / mean of weights.

``` r
calculate_effective_base(weighted_base, deff)
```

Calculates effective sample size: n_effective = n_weighted / DEFF

### Excel Writer (excel_writer.R)

Formats and writes results to Excel workbook.

``` r
write_crosstab_excel(all_results, config, output_file)
```

Creates complete crosstab workbook with one sheet per question,
formatted with colors, borders, and number formats.

``` r
format_crosstab_sheet(wb, sheet_name, question_result, config)
```

Formats one question sheet with headers, percentage formats,
significance highlighting, and frozen panes.

### Config Template Generator (generate_config_templates.R)

Generates professionally formatted Excel config templates with
validation, dropdowns, and help text.

``` r
generate_survey_structure_template(output_dir)
generate_crosstab_config_template(output_dir)
```

Templates include:
- openxlsx data validation (dropdowns for Variable_Type, Y/N fields)
- Colour-coded cells (green = editable, blue = reference, grey = auto)
- Cover sheet with instructions
- All valid options pre-populated

### Guide Sheet (excel_writer.R::create_guide_sheet)

Auto-generated "Guide" sheet added to every Excel workbook output.
Content is conditional on the config object:

``` r
create_guide_sheet(wb, config_obj, banner_info, styles)
```

Sections included dynamically:
- **ROW TYPES** - Only shows enabled row types (frequency, column %,
  row %, SD, net positive, mean, index)
- **SIGNIFICANCE TESTING** - Only if `enable_significance_testing=TRUE`
- **WEIGHTED DATA** - Only if `apply_weighting=TRUE`
- **INDEX SCORES** - Always shown
- **BASE SIZE WARNINGS** - Always shown
- **BANNER COLUMN LETTERS** - Lists letter-to-column mappings from
  `banner_info$column_letters`
- **FORMATTING** - Decimal separator and places

### HTML Report System (html_report/)

Self-contained interactive HTML report generated alongside Excel output
when `html_report=TRUE`.

**Architecture:**

```
99_html_report_main.R    # Entry point: guard → transform → build → write
├── 00_html_guard.R      # Input validation (TRS pattern)
├── 01_data_transformer.R # Transform all_results → HTML-ready structures
├── 02_table_builder.R   # Build <table> elements with data attributes
├── 03_page_builder.R    # Assemble complete HTML page (CSS + JS + HTML)
├── 04_html_writer.R     # Write self-contained HTML file
├── 05_dashboard_transformer.R # Extract headline metrics for dashboard
├── 06_dashboard_builder.R     # Build gauge charts, heatmap, findings
└── 07_chart_builder.R   # Pure SVG chart generation (zero dependencies)
```

**JavaScript modules (js/):**

| File | Responsibility |
|------|---------------|
| core_navigation.js | Question navigation, search, banner switching, help overlay |
| chart_picker.js | Column picker for charts, SVG rebuild, PNG export |
| table_export_init.js | CSV/Excel export, column toggle, column sort |
| pinned_views.js | View capture, pin cards, Markdown editor |
| slide_export.js | Slide PNG export (1280x720 at 3x resolution) |

### Crosstabs Submodules (crosstabs/)

Phase 4 refactoring extracted orchestration into focused submodules:

| File | Responsibility |
|------|---------------|
| crosstabs_config.R | `build_config_object()` with 62 config settings |
| data_setup.R | Survey structure, data, and weight loading |
| analysis_runner.R | Validation, banner creation, question processing |
| workbook_builder.R | Excel workbook assembly (Summary, Guide, Index_Summary, etc.) |
| checkpoint.R | Save/load/cleanup for resumable analysis |

------------------------------------------------------------------------

## Data Flow

### Complete Pipeline

```
1. CONFIGURATION LOADING
   - Load Tabs_Config.xlsx (Settings, Selection sheets)
   - Load Survey_Structure.xlsx (Questions, Options, Composite_Metrics)
   - Resolve file paths relative to project root
   - Build config_obj (62 settings with typed defaults)

2. VALIDATION (5 sequential validators)
   - Structure validators: questions, options, duplicates
   - Data validators: columns, types, multi-mention
   - Weight validators: column, values, DEFF
   - Config validators: alpha, alpha_secondary, alpha_default, min_base, paths
   - Pre-flight validators: cross-reference config ↔ structure ↔ data

3. DATA LOADING
   - Load survey data (CSV, XLSX, SAV)
   - Load weights (if specified)
   - Create banner structure
   - Print config summary (questions, respondents, features)

4. QUESTION LOOP (for each stub question)
   4a. Prepare Question Data
       - Load metadata and options
       - Apply base filter
       - Create banner indices
       - Calculate bases

   4b. Dispatch to Processor
       - Detect question type
       - Route to appropriate processor

   4c. Process Question
       - Calculate counts/percentages across banner
       - Calculate significance
       - Build result rows

   4d. Store Result
       - Add to all_results list

5. EXCEL OUTPUT
   - Create workbook
   - Write Summary sheet (project info, question list)
   - Write Guide sheet (config-aware legend)
   - Write Index_Summary sheet (consolidated metrics)
   - Write Error Log sheet
   - Write Run_Status sheet
   - Write Sample Composition sheet (if enabled)
   - Write Crosstabs sheet (all question tables)
   - Save workbook

6. HTML REPORT (if html_report=TRUE)
   - Guard: validate inputs and packages
   - Transform: convert all_results to HTML-ready structures
   - Dashboard: extract headline metrics, sig findings
   - Tables: build HTML tables with heatmap data attributes
   - Charts: generate inline SVG charts
   - Page: assemble complete self-contained HTML
   - Write: save HTML file
```

### Memory Management

```         
Configuration (small) → kept in memory
Survey Structure (medium) → kept in memory
Survey Data (large) → kept in memory
Weights (medium) → kept in memory
Banner Indices (medium) → kept in memory

For each question:
  Filtered Data (large subset) → created, used, discarded
  Question Result (small) → accumulated in all_results

All Results (medium) → written to Excel, then discarded
Excel Workbook (large) → written to disk, memory freed
```

**Optimization Strategies:** 1. Keep master weights and data without
duplication 2. Use index-based subsetting 3. Process questions
sequentially, discard intermediate results 4. Write Excel incrementally
for many questions 5. Call gc() after large operations

------------------------------------------------------------------------

## Statistical Algorithms

### Chi-Square Test

Used for categorical data (Single_Response, Multi_Mention).

``` r
chi_square <- sum((O - E)^2 / E)
df <- (n_rows - 1) * (n_cols - 1)
p_value <- pchisq(chi_square, df, lower.tail = FALSE)
```

Where O = observed count, E = expected count = (row total × column
total) / grand total.

### Z-Test for Proportions

Used for comparing two proportions.

``` r
p1 <- count1 / base1
p2 <- count2 / base2
p_pool <- (count1 + count2) / (base1 + base2)
se <- sqrt(p_pool * (1 - p_pool) * (1/base1 + 1/base2))
z <- (p1 - p2) / se
p_value <- 2 * pnorm(-abs(z))
```

### T-Test for Means

Used for comparing means (Welch's t-test with unequal variances).

``` r
mean1 <- weighted.mean(values1, weights1)
mean2 <- weighted.mean(values2, weights2)
var1 <- weighted.var(values1, weights1)
var2 <- weighted.var(values2, weights2)
n1_eff <- base1 / deff1
n2_eff <- base2 / deff2
se <- sqrt(var1/n1_eff + var2/n2_eff)
t <- (mean1 - mean2) / se
df <- welch_satterthwaite_df(var1, var2, n1_eff, n2_eff)
p_value <- 2 * pt(-abs(t), df)
```

### Design Effect

``` r
weight_mean <- mean(weights)
weight_sd <- sd(weights)
cv <- weight_sd / weight_mean
deff <- 1 + cv^2
n_effective <- n_weighted / deff
```

------------------------------------------------------------------------

## Extension Points

### Adding a New Question Type

1.  **Define the type** in Survey_Structure Questions sheet
    (Variable_Type column)

2.  **Create processor** in new file `lib/custom_processor.R`:

``` r
process_custom_question <- function(prepared_data, config, error_log) {
  # Extract prepared data
  question_info <- prepared_data$question_info
  filtered_data <- prepared_data$filtered_data

  # Perform calculations
  result_table <- data.frame()
  # ... build result table ...

  # Return standard structure
  return(list(
    question_code = question_info$QuestionCode,
    question_text = question_info$QuestionText,
    question_type = question_info$Variable_Type,
    base_filter = prepared_data$base_filter,
    bases = banner_bases,
    table = result_table
  ))
}
```

3.  **Update dispatcher** in `question_dispatcher.R`:

``` r
if (question_type == "Custom_Type") {
  result <- process_custom_question(prepared_data, config, error_log)
}
```

4.  **Source new file** in `run_crosstabs.R`:

``` r
source(file.path(script_dir, "custom_processor.R"))
```

### Adding a New Statistical Test

1.  **Add test function** in `lib/statistical_tests.R`:

``` r
calculate_custom_test <- function(count1, base1, count2, base2, alpha = 0.05) {
  # Perform test
  # ...
  return(list(
    statistic = test_stat,
    p_value = p_val,
    significant = (p_val < alpha)
  ))
}
```

2.  **Update processors** to use the new test when configured.

3.  **Document** the new option in configuration.

------------------------------------------------------------------------

## Performance Benchmarks

Tested on MacBook Pro M1:

| Dataset Size | Questions | Banner Cols | Time          |
|--------------|-----------|-------------|---------------|
| 500 rows     | 20        | 5           | 2-3 seconds   |
| 2,000 rows   | 50        | 10          | 8-12 seconds  |
| 10,000 rows  | 100       | 15          | 45-60 seconds |
| 50,000 rows  | 200       | 20          | 5-8 minutes   |

**Memory Usage:** - 10,000 rows × 100 cols: \~200 MB RAM - 50,000 rows ×
200 cols: \~1 GB RAM

------------------------------------------------------------------------

## Known Issues

### CR-TABS-001: Undefined Constant

-   **Location:** validation.R line \~1260
-   **Issue:** MAX_DECIMAL_PLACES used but not defined
-   **Workaround:** Add `MAX_DECIMAL_PLACES <- 6` at top of validation.R

### CR-TABS-002: Global Namespace Pollution

-   **Location:** excel_writer.R line \~68
-   **Issue:** `source(..., local = FALSE)` loads into global
    environment
-   **Workaround:** Load dependencies before excel_writer

### CR-TABS-003: Misleading Function Name

-   **Location:** shared_functions.R line \~992
-   **Issue:** `log_issue()` is pure function but name suggests side
    effect
-   **Workaround:** Always capture return value:
    `error_log <- log_issue(error_log, ...)`

------------------------------------------------------------------------

## Testing

### Current Coverage

Estimated coverage is under 10% (mostly manual testing).

### Recommended Test Structure

```         
modules/tabs/tests/
├── test_config_loader.R
├── test_validation.R
├── test_question_orchestrator.R
├── test_question_dispatcher.R
├── test_standard_processor.R
├── test_numeric_processor.R
├── test_cell_calculator.R
├── test_banner.R
├── test_weighting.R
├── test_shared_functions.R
├── test_excel_writer.R
└── fixtures/
    ├── test_config.xlsx
    ├── test_structure.xlsx
    └── test_data.csv
```

### Unit Test Example

``` r
library(testthat)

test_that("calculate_weighted_percentage handles zero base", {
  result <- calculate_weighted_percentage(50, 0)
  expect_true(is.na(result))
})

test_that("calculate_weighted_percentage calculates correctly", {
  result <- calculate_weighted_percentage(50, 200)
  expect_equal(result, 25)
})
```

------------------------------------------------------------------------

## Code Style Guidelines

### Naming Conventions

``` r
# Functions: snake_case
calculate_weighted_percentage <- function(...) { }

# Variables: snake_case
weighted_base <- 500

# Constants: SCREAMING_SNAKE_CASE
MAX_DECIMAL_PLACES <- 6

# Internal functions: prefix with dot
.helper_function <- function(...) { }
```

### Documentation Standards

``` r
#' Function Title
#'
#' Detailed description of what the function does.
#'
#' @param param1 Description of param1
#' @param param2 Description of param2
#' @return Description of return value
#' @examples
#' result <- my_function("value1", 123)
my_function <- function(param1, param2) {
  # Implementation
}
```

------------------------------------------------------------------------

## Debugging

### Common Diagnostic Steps

**Configuration issues:**

``` r
file.exists("Tabs_Config.xlsx")  # Should be TRUE
getwd()  # Check working directory
```

**Question not found:**

``` r
questions <- readxl::read_excel("Survey_Structure.xlsx", sheet = "Questions")
"Q01" %in% questions$QuestionCode
```

**Weight issues:**

``` r
summary(data$weight)
hist(data$weight)
```

### Enabling Debug Output

``` r
DEBUG <- TRUE

if (DEBUG) {
  cat("Processing question:", question_code, "\n")
  cat("Base filter:", base_filter, "\n")
  cat("Banner bases:", str(banner_bases), "\n")
}
```

### Interactive Debugging

``` r
process_question <- function(...) {
  browser()  # Execution pauses here
  # ... rest of function
}
```

### Profiling

``` r
Rprof("profile.out")
result <- run_crosstabs(...)
Rprof(NULL)
summaryRprof("profile.out")
```
