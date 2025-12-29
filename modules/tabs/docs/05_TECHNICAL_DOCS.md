---
editor_options:
  markdown:
    wrap: 72
---

# Turas Tabs - Technical Documentation

**Version:** 10.2 **Date:** 29 December 2025 **Audience:** Developers,
Technical Contributors, Module Maintainers

This document covers the internal architecture, code structure, and
implementation details of the Tabs module. For user-facing
documentation, see the [User Manual](04_USER_MANUAL.md).

------------------------------------------------------------------------

## Architecture Overview

### Design Philosophy

Tabs follows an **orchestrator pattern** with clear separation of concerns:

```
Config → Data → Validate → Process → Output
  ↓        ↓        ↓          ↓         ↓
load_    load_    run_      run_     create_
config   data    validation analysis workbook
```

The design emphasizes:
- **Orchestrator Pattern:** Main script coordinates focused modules
- **Modularity:** Each component has a single responsibility
- **Testability:** Functions are pure where possible with explicit dependencies
- **Fail-Fast:** Validation occurs early with clear error messages
- **Memory Efficiency:** Vectorized operations, minimal data duplication
- **Extensibility:** New question types can be added without modifying core logic

### Design Patterns

The module uses several established patterns:

**Orchestrator Pattern (V10.2):** The main `run_crosstabs.R` file coordinates
high-level functions, delegating implementation to focused modules.

**Pipeline Pattern:** Data flows through sequential processing stages.

**Strategy Pattern:** Different processors handle different question
types. The dispatcher routes to the appropriate processor based on
question type.

**Factory Pattern:** The question dispatcher creates processor instances
based on configuration.

**Builder Pattern:** The Excel writer constructs complex output
incrementally, adding sheets and formatting as it goes.

------------------------------------------------------------------------

## Module Structure

### File Organization (V10.2 - Refactored)

```
modules/tabs/
├── run_tabs.R                    # Main entry point
├── run_tabs_gui.R                # Shiny GUI interface
├── REFACTORING_NOTES.md          # Refactoring documentation
├── lib/
│   ├── run_crosstabs.R           # Core orchestrator (~580 lines)
│   ├── shared_functions.R        # Shared utilities orchestrator (~334 lines)
│   ├── 00_guard.R                # TRS error handling (~763 lines)
│   │
│   ├── # --- Utility Modules (Phase 1/3) ---
│   ├── type_utils.R              # Type conversion utilities (~166 lines)
│   ├── logging_utils.R           # Logging utilities (~189 lines)
│   ├── config_utils.R            # Config helper utilities (~267 lines)
│   ├── excel_utils.R             # Excel formatting utilities (~151 lines)
│   ├── path_utils.R              # Path resolution utilities (~208 lines)
│   ├── validation_utils.R        # Validation utilities (~428 lines)
│   ├── data_loader.R             # Data loading utilities (~362 lines)
│   ├── filter_utils.R            # Filter expression utilities (~211 lines)
│   ├── run_crosstabs_helpers.R   # Crosstabs helper functions (~291 lines)
│   │
│   ├── # --- Crosstabs Modules (Phase 4) ---
│   ├── crosstabs/
│   │   ├── checkpoint.R          # Checkpoint system (~146 lines)
│   │   ├── crosstabs_config.R    # Configuration loading (~242 lines)
│   │   ├── data_setup.R          # Data and weight setup (~316 lines)
│   │   ├── analysis_runner.R     # Processing orchestration (~534 lines)
│   │   └── workbook_builder.R    # Excel output creation (~649 lines)
│   │
│   ├── # --- Core Processing Modules ---
│   ├── config_loader.R           # Configuration management (~450 lines)
│   ├── validation.R              # Input validation orchestrator (~1,400 lines)
│   ├── question_orchestrator.R   # Question preparation (~200 lines)
│   ├── question_dispatcher.R     # Question type routing (~350 lines)
│   ├── standard_processor.R      # Single/Multi processing (~550 lines)
│   ├── numeric_processor.R       # Numeric/Rating/NPS processing (~400 lines)
│   ├── composite_processor.R     # Composite metrics (~300 lines)
│   ├── ranking.R                 # Ranking question processing (~250 lines)
│   ├── cell_calculator.R         # Cell/row calculations (~450 lines)
│   ├── banner.R                  # Banner structure (~300 lines)
│   ├── banner_indices.R          # Banner indexing (~250 lines)
│   ├── weighting.R               # Weight calculations (~400 lines)
│   ├── excel_writer.R            # Excel output (~600 lines)
│   ├── summary_builder.R         # Summary statistics (~200 lines)
│   │
│   ├── # --- Subdirectory Modules (Phase 2) ---
│   ├── validation/               # Validation subdirectory modules
│   │   ├── structure_validators.R
│   │   ├── data_validators.R
│   │   ├── config_validators.R
│   │   └── composite_validators.R
│   └── ranking/                  # Ranking subdirectory modules
│       ├── ranking_processor.R
│       ├── ranking_metrics.R
│       └── ranking_crosstabs.R
```

Total lines of code: approximately 11,000 (including new modules).
Organized into 18+ focused modules.

### Dependencies

**Required R Packages:** - openxlsx: Excel file I/O - readxl: Reading
Excel configuration files

**Optional R Packages:** - data.table: High-performance data operations
(faster CSV reading) - haven: SPSS file support

**Internal Dependencies:** Currently standalone. Future versions may
integrate with shared Turas utilities.

------------------------------------------------------------------------

## Core Components

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

Comprehensive input validation with clear error messages.

**Key Functions:**

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
Single_Mention, Multi_Mention, Ranking → standard_processor - Numeric,
Rating, NPS, Likert → numeric_processor

### Standard Processor (standard_processor.R)

Processes Single_Mention and Multi_Mention questions.

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
  question_type = "Single_Mention",
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

------------------------------------------------------------------------

## Crosstabs Orchestration Modules (V10.2)

The Phase 4 refactoring introduced focused modules in `lib/crosstabs/` that
implement the orchestrator pattern for `run_crosstabs.R`.

### Main Execution Flow

``` r
# STEP 1: LOAD CONFIGURATION
config_result <- load_crosstabs_config(config_file)

# STEP 2: LOAD DATA
data_result <- load_crosstabs_data(config_result)

# STEP 3: RUN ANALYSIS
analysis_result <- run_crosstabs_analysis(config_result, data_result)

# STEP 4: CREATE EXCEL OUTPUT
workbook_result <- create_crosstabs_workbook(...)

# STEP 5: COMPLETION SUMMARY
```

### Checkpoint Module (crosstabs/checkpoint.R)

Manages checkpoint state for resuming interrupted analysis runs.

**Key Functions:**

``` r
save_checkpoint(checkpoint_file, all_results, processed_questions)
```

Saves current analysis progress to disk as an RDS file.

``` r
load_checkpoint(checkpoint_file)
```

Loads saved progress. Returns NULL if no checkpoint exists.

``` r
setup_checkpointing(enable_checkpointing, checkpoint_file, crosstab_questions)
```

Initializes checkpoint state. Returns list with `all_results`,
`processed_questions`, `remaining_questions`, and `resumed` flag.

``` r
cleanup_checkpoint(checkpoint_file)
```

Removes checkpoint file after successful completion.

### Configuration Module (crosstabs/crosstabs_config.R)

Handles configuration loading and config object building.

**Key Functions:**

``` r
load_crosstabs_config(config_file)
```

Main entry point. Returns list containing:
- `project_root`: Project directory path
- `config_file`: Path to config file
- `config_obj`: All configuration settings
- `structure_file_path`: Path to survey structure
- `output_path`: Full output file path

``` r
build_config_object(config, default_alpha, default_min_base)
```

Builds the config_obj list with all analysis settings including weighting,
display options, decimal places, and significance testing parameters.

### Data Setup Module (crosstabs/data_setup.R)

Manages survey structure, data, and weight setup.

**Key Functions:**

``` r
load_crosstabs_data(config_result)
```

Main entry point. Returns list containing:
- `survey_structure`: Questions, options, project info
- `survey_data`: Survey response data
- `composite_defs`: Composite metric definitions
- `master_weights`: Weight vector
- `effective_n`: Effective sample size
- `selection_df`: Question selection
- `crosstab_questions`: Filtered questions to process

``` r
load_and_validate_structure(structure_file_path, project_root)
```

Loads and validates the survey structure file.

``` r
setup_weights(survey_data, config_obj)
```

Configures weighting. Returns `master_weights`, `effective_n`, `is_weighted`.

``` r
load_question_selection(config_file)
```

Loads and validates the Selection sheet from config file.

### Analysis Runner Module (crosstabs/analysis_runner.R)

Orchestrates the main analysis processing.

**Key Functions:**

``` r
run_crosstabs_analysis(config_result, data_result, checkpoint_frequency, total_column)
```

Main entry point. Returns list containing:
- `all_results`: All question results
- `composite_results`: Composite metric results
- `banner_info`: Banner structure
- `error_log`: Validation issues
- `run_status`: "PASS" or "PARTIAL"
- `skipped_questions`: Questions that couldn't be processed
- `partial_questions`: Questions with missing sections

``` r
run_validation(survey_structure, survey_data, config_obj, composite_defs)
```

Runs comprehensive validation including composite definition validation.

``` r
create_banner_safe(selection_df, survey_structure)
```

Creates banner structure with error handling.

``` r
process_questions(remaining_questions, survey_data, ...)
```

Processes all questions using the question orchestrator.

``` r
process_composites(composite_defs, survey_data, survey_structure, banner_info, config_obj)
```

Processes composite metrics.

### Workbook Builder Module (crosstabs/workbook_builder.R)

Creates and populates the Excel workbook.

**Key Functions:**

``` r
create_crosstabs_workbook(all_results, composite_results, ...)
```

Main entry point. Creates complete workbook with all sheets:
- Summary sheet
- Index_Summary sheet (if composites defined)
- Error Log sheet
- Run_Status sheet
- Sample Composition sheet (if enabled)
- Crosstabs sheet with all questions

Returns list with `output_path`, `run_result`, `project_name`.

``` r
get_style_config(config_obj)
```

Extracts decimal places and separator settings with safe defaults.

``` r
write_crosstabs_sheet(wb, all_results, banner_info, config_obj, styles)
```

Creates and populates the main Crosstabs sheet.

``` r
write_single_question(wb, sheet, question_results, q_code, ...)
```

Writes a single question's results to the sheet.

``` r
save_workbook_safe(wb, output_path, run_result)
```

Saves workbook with TRS atomic save if available.

------------------------------------------------------------------------

## Data Flow

### Complete Pipeline (V10.2 - Refactored)

```         
1. CONFIGURATION LOADING
   - Load Tabs_Config.xlsx (Settings, Selection sheets)
   - Load Survey_Structure.xlsx (Questions, Options, Composite_Metrics)
   - Resolve file paths relative to project root

2. VALIDATION
   - Validate survey structure (questions, options)
   - Validate survey data (columns, types)
   - Validate weights (if specified)
   - Validate banner selection

3. DATA LOADING
   - Load survey data (CSV, XLSX, SAV)
   - Load weights (if specified)
   - Create banner structure

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
   - Write each question sheet
   - Apply formatting
   - Write metadata sheet
   - Save workbook
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

Used for categorical data (Single_Mention, Multi_Mention).

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

### CR-TABS-001: Undefined Constant ✓ RESOLVED (V10.2)

-   **Location:** validation.R line \~1260
-   **Issue:** MAX_DECIMAL_PLACES used but not defined
-   **Resolution:** Constants now defined in run_crosstabs.R and available
    to all modules through proper sourcing order.

### CR-TABS-002: Global Namespace Pollution ✓ RESOLVED (V10.2)

-   **Location:** excel_writer.R line \~68
-   **Issue:** `source(..., local = FALSE)` loads into global environment
-   **Resolution:** Modules now use `tabs_source()` helper which handles
    proper dependency loading order. The orchestrator pattern ensures
    dependencies are loaded before they are needed.

### CR-TABS-003: Misleading Function Name ✓ RESOLVED (V10.1)

-   **Location:** shared_functions.R line \~992
-   **Issue:** `log_issue()` is pure function but name suggests side effect
-   **Resolution:** Function renamed to `add_log_entry()` in V10.1.
    Original `log_issue()` kept as alias for backward compatibility.

### CR-TABS-004: Large Monolithic Files (V10.2 Status)

-   **Original Issue:** Several files over 1,000 lines
-   **V10.2 Status:**
    -   `run_crosstabs.R`: Reduced from 1,716 to 580 lines ✓
    -   `shared_functions.R`: Reduced from 2,001 to 334 lines ✓
    -   `standard_processor.R`: 1,312 lines (future refactoring candidate)
    -   `validation.R`: 1,400 lines (orchestrates subdirectory modules)

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
