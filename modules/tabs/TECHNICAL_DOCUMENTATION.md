# Turas Tabs - Technical Documentation

**Version:** 9.9
**Last Updated:** 2025-11-18
**Target Audience:** Developers, Technical Contributors, Module Maintainers

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Module Structure](#module-structure)
3. [Core Components](#core-components)
4. [Data Flow](#data-flow)
5. [API Reference](#api-reference)
6. [Statistical Algorithms](#statistical-algorithms)
7. [Extension Points](#extension-points)
8. [Performance Optimization](#performance-optimization)
9. [Known Issues](#known-issues)
10. [Testing Strategy](#testing-strategy)
11. [Debugging Guide](#debugging-guide)

---

## Architecture Overview

### Design Philosophy

The Tabs module follows a **Pipeline Architecture** with clear separation of concerns:

```
Input → Load → Validate → Process → Calculate → Write → Output
```

**Key Principles:**
- **Modularity:** Each component has a single, well-defined responsibility
- **Testability:** Functions are pure where possible with explicit dependencies
- **Fail-Fast:** Validation occurs early with clear error messages
- **Memory Efficiency:** Vectorized operations, minimal data duplication
- **Extensibility:** New question types and statistical methods can be added without modifying core logic

### Design Patterns

1. **Pipeline Pattern:** Data flows through sequential stages
2. **Strategy Pattern:** Different processors for different question types
3. **Factory Pattern:** Question dispatcher creates appropriate processors
4. **Builder Pattern:** Excel writer constructs complex output incrementally
5. **Observer Pattern:** Logging system monitors execution progress

---

## Module Structure

### File Organization

```
modules/tabs/
├── run_tabs.R                    # Main entry point
├── run_tabs_gui.R                # Shiny GUI interface
├── lib/
│   ├── run_crosstabs.R           # Core orchestration (1,800 lines)
│   ├── config_loader.R           # Configuration management (450 lines)
│   ├── validation.R              # Input validation (1,400 lines)
│   ├── question_orchestrator.R   # Question preparation (200 lines)
│   ├── question_dispatcher.R     # Question type routing (350 lines)
│   ├── standard_processor.R      # Single/Multi question processing (550 lines)
│   ├── numeric_processor.R       # Numeric/Rating/NPS processing (400 lines)
│   ├── composite_processor.R     # Composite metrics (300 lines)
│   ├── ranking.R                 # Ranking question processing (250 lines)
│   ├── cell_calculator.R         # Cell/row calculations (450 lines)
│   ├── banner.R                  # Banner structure (300 lines)
│   ├── banner_indices.R          # Banner indexing (250 lines)
│   ├── weighting.R               # Weight calculations (400 lines)
│   ├── shared_functions.R        # Utilities (1,640 lines)
│   ├── excel_writer.R            # Excel output (600 lines)
│   └── summary_builder.R         # Summary statistics (200 lines)
├── QUICK_START.md
├── USER_MANUAL.md
├── TECHNICAL_DOCUMENTATION.md    # This file
└── EXAMPLE_WORKFLOWS.md
```

**Total Lines of Code:** ~9,500 lines

### Module Dependencies

```r
# Required R Packages
- openxlsx      # Excel file I/O
- readxl        # Reading Excel configuration
- data.table    # High-performance data operations (optional)

# Internal Dependencies
- None (standalone module)

# Shared Utilities (future)
- Will integrate with shared/statistics/weighting.R
- Will integrate with shared/config/config_utils.R
```

---

## Core Components

### 1. Configuration Loader (`config_loader.R`)

**Purpose:** Load and parse Excel configuration files

**Key Functions:**

```r
load_crosstab_configuration(config_file, project_root = NULL)
# Returns: list(config, paths, selection, validation, project_root)
# - config: Parsed settings object
# - paths: Resolved file paths
# - selection: Banner and stub questions
# - validation: Validation results
# - project_root: Project directory path

load_config_settings(config_file, sheet_name = "Settings")
# Returns: Named list of setting values
# Handles duplicate detection, type conversion, NA handling

get_config_value(config_list, setting_name, default_value = NULL, required = FALSE)
# Safely retrieve configuration value with defaults
# Stops execution if required setting is missing
```

**Configuration Structure:**

```r
config <- list(
  # File paths
  survey_structure_file = "Survey_Structure.xlsx",
  data_file = "data.csv",
  output_file = "output.xlsx",

  # Analysis settings
  show_significance = TRUE,
  significance_level = 0.05,
  minimum_base = 30,
  decimal_places = 0,
  decimal_places_average = 1,

  # Statistical options
  use_effective_base = TRUE,
  weight_column = NA,
  stat_test = "chi-square",  # or "z-test", "t-test"

  # Display options
  show_frequencies = TRUE,
  show_percentages = TRUE,
  show_bases = TRUE,
  show_row_percentages = FALSE
)
```

---

### 2. Validation Module (`validation.R`)

**Purpose:** Comprehensive input validation with clear error messages

**Version:** 9.9.5

**Key Functions:**

```r
validate_survey_structure(survey_structure, error_log = NULL)
# Validates:
# - Required columns (QuestionCode, QuestionText, Variable_Type)
# - No duplicate QuestionCodes
# - Valid Variable_Type values
# - Questions have matching options
# - No orphan options
# Returns: error_log with validation results

validate_survey_data(data, survey_structure, error_log = NULL)
# Validates:
# - Required question columns exist
# - Data types match expectations (numeric for Numeric questions)
# - No completely empty columns
# - Multi-mention column counts match structure
# Returns: error_log with validation results

validate_weights(weights, data, error_log = NULL,
                 weight_na_threshold = 10,
                 weight_zero_threshold = 5,
                 weight_deff_warning = 3)
# Validates:
# - Weights are numeric
# - Length matches data
# - NA count < threshold (default 10%)
# - Zero count < threshold (default 5%)
# - DEFF warnings if DEFF > threshold (default 3)
# Returns: error_log with validation results

validate_banner_selection(banner_cols, data, survey_structure, error_log = NULL)
# Validates:
# - All banner questions exist in survey structure
# - Banner questions exist in data
# - Banner questions are appropriate types (not Open_End)
# Returns: error_log with validation results
```

**Error Logging:**

```r
# Error log structure
error_log <- list(
  errors = list(),    # Critical issues (stop execution)
  warnings = list(),  # Non-critical issues
  info = list()       # Informational messages
)

# Each entry:
list(
  source = "Validation",
  category = "Missing Data",
  message = "Column Q01 not found in data",
  details = "Expected column Q01 for question 'Brand Awareness'",
  severity = "Error"  # or "Warning", "Info"
)
```

**Known Issues:**
- **CR-TABS-001:** `MAX_DECIMAL_PLACES` constant used at line 1260 but not defined
  - **Workaround:** Add `MAX_DECIMAL_PLACES <- 6` at top of file
  - **Status:** Documented for fixing in v10.0

---

### 3. Question Orchestrator (`question_orchestrator.R`)

**Purpose:** Prepare question data for processing

**Key Function:**

```r
prepare_question_data(question_code, base_filter,
                      survey_data, survey_structure,
                      banner_info, master_weights)
# Returns: list or NULL
# - question_info: Metadata for question
# - question_options: Response options
# - filtered_data: Data with base filter applied
# - question_weights: Weights for filtered data
# - banner_row_indices: Row indices by banner column
# - banner_bases: Base sizes by banner column
# - base_filter: Applied filter expression
```

**Processing Steps:**

1. **Load Metadata:** Extract question info and options from structure
2. **Apply Filter:** Subset data based on base filter (if specified)
3. **Create Indices:** Build row indices for each banner column
4. **Calculate Bases:** Compute unweighted, weighted, and effective bases

**Multi-Mention Handling:**

```r
# Multi-mention questions store options in column names
# Example: Q01 with 3 mentions → Q01_1, Q01_2, Q01_3

if (question_info$Variable_Type == "Multi_Mention") {
  pattern <- paste0("^", question_code, "_")
  question_options <- survey_structure$options[
    grepl(pattern, survey_structure$options$QuestionCode),
  ]
}
```

---

### 4. Question Dispatcher (`question_dispatcher.R`)

**Purpose:** Route questions to appropriate processors

**Strategy Pattern Implementation:**

```r
process_question(question_code, base_filter, survey_data,
                 survey_structure, banner_info, master_weights,
                 config, error_log)
# Returns: Question result object or NULL

# Internal routing:
if (is_composite_question(question_code, survey_structure)) {
  # Route to composite processor
  process_composite_question(...)
} else if (question_type %in% c("Single_Response", "Multi_Mention", "Ranking")) {
  # Route to standard processor
  process_standard_question(...)
} else if (question_type %in% c("Numeric", "Rating", "NPS")) {
  # Route to numeric processor
  process_numeric_question(...)
} else {
  # Unsupported type
  warning(...)
  return(NULL)
}
```

**Supported Question Types:**

| Type | Processor | Output |
|------|-----------|--------|
| Single_Response | standard_processor | Frequency, Column %, Sig |
| Multi_Mention | standard_processor | Frequency, Column %, Sig |
| Rating | numeric_processor | Frequency, Column %, Average, Sig |
| Likert | numeric_processor | Frequency, Column %, Average, Sig |
| NPS | numeric_processor | Promoters/Passives/Detractors %, NPS Score |
| Numeric | numeric_processor | Average, Std Dev, Median, Min/Max |
| Ranking | ranking.R | Mean rank, First choice %, Sig |
| Composite | composite_processor | Custom metrics, Scores, Indices |

---

### 5. Standard Processor (`standard_processor.R`)

**Purpose:** Process Single_Response and Multi_Mention questions

**Main Function:**

```r
process_standard_question(prepared_data, config, error_log)
# Returns: Question result object

# Result structure:
list(
  question_code = "Q01",
  question_text = "Which brand do you prefer?",
  question_type = "Single_Response",
  base_filter = NA,
  bases = list(
    Total = list(unweighted = 500, weighted = 500, effective = 450),
    Male = list(unweighted = 250, weighted = 240, effective = 220),
    Female = list(unweighted = 250, weighted = 260, effective = 230)
  ),
  table = data.frame(
    RowLabel = c("Brand A", "", "Brand B", "", "Brand C", ""),
    RowType = c("Frequency", "Column %", "Frequency", "Column %", "Frequency", "Column %"),
    Total = c(200, 40, 180, 36, 120, 24),
    Male = c(100, 40, 90, 36, 60, 24),
    Female = c(100, 38, 90, 35, 60, 23)
  ),
  significance = data.frame(
    RowLabel = c("Brand A", "Brand B", "Brand C"),
    Total = c("", "", ""),
    Male = c("F", "", ""),
    Female = c("", "", "")
  )
)
```

**Processing Algorithm:**

```r
# For each response option:
for (option in question_options) {

  # 1. Calculate weighted counts across banner columns
  row_counts <- calculate_row_counts(
    data = filtered_data,
    banner_row_indices = banner_row_indices,
    option_text = option$OptionText,
    question_col = question_code,
    is_multi_mention = (question_type == "Multi_Mention"),
    existing_cols = multi_mention_cols,
    internal_keys = banner_info$internal_keys,
    master_weights = master_weights
  )

  # 2. Create frequency row (optional)
  if (config$show_frequencies) {
    freq_row <- create_frequency_row(row_counts, ...)
    result_table <- rbind(result_table, freq_row)
  }

  # 3. Create percentage row
  pct_row <- create_percentage_row(
    row_counts, banner_bases, internal_keys,
    display_text = option$OptionText,
    decimal_places = config$decimal_places
  )
  result_table <- rbind(result_table, pct_row)

  # 4. Calculate significance (if enabled)
  if (config$show_significance) {
    sig_row <- calculate_column_significance(
      row_counts, banner_bases,
      test_type = config$stat_test,
      alpha = config$significance_level,
      ...
    )
    sig_table <- rbind(sig_table, sig_row)
  }
}
```

---

### 6. Numeric Processor (`numeric_processor.R`)

**Purpose:** Process Numeric, Rating, NPS, and Likert questions

**Main Function:**

```r
process_numeric_question(prepared_data, config, error_log)
# Returns: Question result object
```

**Rating Questions:**

```r
# Rating questions show both frequencies and average
# Example: 1-5 satisfaction scale

# Output includes:
# - Frequency and % for each rating point (1, 2, 3, 4, 5)
# - Average rating (weighted mean)
# - Significance testing on averages (t-test or z-test)
# - Optional: Top-2-box, Bottom-2-box percentages

# Calculation:
weighted_mean <- sum(values * weights) / sum(weights)
```

**NPS Questions:**

```r
# NPS (Net Promoter Score) calculation
# Scale: 0-10
# - Detractors: 0-6
# - Passives: 7-8
# - Promoters: 9-10

# Output includes:
# - % Detractors
# - % Passives
# - % Promoters
# - NPS Score = % Promoters - % Detractors
# - Significance testing on NPS score

# Calculation:
pct_promoters <- sum(weights[score >= 9]) / sum(weights) * 100
pct_detractors <- sum(weights[score <= 6]) / sum(weights) * 100
nps <- pct_promoters - pct_detractors
```

**Numeric Questions:**

```r
# Numeric questions show summary statistics
# Example: Age, Income, Purchase amount

# Output includes:
# - Average (weighted mean)
# - Standard Deviation
# - Median
# - Min/Max
# - Optional: Percentiles (25th, 75th)
# - Significance testing on averages (t-test)
```

---

### 7. Cell Calculator (`cell_calculator.R`)

**Purpose:** Core calculation functions for cells and rows

**Memory Optimization:**

The module uses **index-based subsetting** to avoid weight duplication:

```r
# GOOD: Use master_weights[row_idx] - no duplication
subset_weights <- master_weights[row_idx]

# BAD: Create new weight vector - duplicates data
subset_weights <- rep(master_weights, each = n)
```

**Key Functions:**

```r
calculate_row_counts(data, banner_row_indices, option_text,
                     question_col, is_multi_mention, existing_cols,
                     internal_keys, master_weights)
# Calculates weighted counts for one response option across all banner columns
# Returns: Named numeric vector of weighted counts

calculate_weighted_percentage(weighted_count, weighted_base)
# Safely calculates percentage with zero-division handling
# Returns: Percentage or NA

create_percentage_row(row_counts, banner_bases, internal_keys,
                      display_text, show_label = TRUE,
                      decimal_places = 0)
# Creates formatted percentage row for output table
# Returns: Data frame with one row

create_frequency_row(row_counts, internal_keys, display_text,
                     show_label = TRUE)
# Creates formatted frequency row for output table
# Returns: Data frame with one row
```

**Safe Equality Comparison:**

```r
# handles factor, character, numeric comparison
safe_equal <- function(x, y) {
  if (is.factor(x)) x <- as.character(x)
  if (is.factor(y)) y <- as.character(y)
  x == y
}
```

---

### 8. Banner Management (`banner.R`, `banner_indices.R`)

**Purpose:** Manage banner (column) structure and indexing

**Banner Structure:**

```r
# Banner can be:
# 1. Total only (no crosstabulation)
# 2. Single question (e.g., Gender)
# 3. Multiple questions (e.g., Gender + Age Group)
# 4. Nested questions (future enhancement)

# Example banner_info object:
banner_info <- list(
  display_labels = c("Total", "Male", "Female", "18-34", "35-54", "55+"),
  internal_keys = c("Total", "Q99_Male", "Q99_Female", "Q98_18-34", "Q98_35-54", "Q98_55+"),
  questions = c(NA, "Q99", "Q99", "Q98", "Q98", "Q98"),
  values = c(NA, "Male", "Female", "18-34", "35-54", "55+"),
  column_count = 6
)
```

**Banner Index Creation:**

```r
create_banner_row_indices(data, banner_info)
# Returns: list(row_indices = list(), validation = list())

# row_indices structure:
list(
  Total = 1:500,                    # All rows
  Q99_Male = c(1, 3, 5, 7, ...),   # Rows where Q99 == "Male"
  Q99_Female = c(2, 4, 6, 8, ...),  # Rows where Q99 == "Female"
  Q98_18-34 = c(1, 2, 10, 15, ...),  # Rows where Q98 == "18-34"
  ...
)
```

**Overlapping Banners:**

Banners can overlap (not mutually exclusive):
- A Male respondent can also be in the 18-34 age group
- Banner bases are calculated independently
- Significance testing accounts for overlaps

---

### 9. Weighting (`weighting.R`)

**Purpose:** Weight loading, validation, and base calculations

**Key Functions:**

```r
load_weights(data, weight_column)
# Loads weight column from data
# Returns: Numeric vector of weights or vector of 1s if no weighting

calculate_weighted_base(data, question_info, weights)
# Calculates three types of base sizes
# Returns: list(unweighted, weighted, effective)

calculate_deff(weights)
# Calculates Design Effect for weighted sample
# DEFF = 1 + CV² where CV = coefficient of variation
# Returns: Numeric DEFF value

calculate_effective_base(weighted_base, deff)
# Calculates effective sample size
# n_eff = n_weighted / DEFF
# Returns: Numeric effective base
```

**Base Size Calculations:**

```r
# 1. Unweighted base
n_unweighted <- sum(!is.na(data[[question_col]]))

# 2. Weighted base
n_weighted <- sum(weights[!is.na(data[[question_col]])])

# 3. Design Effect (DEFF)
weight_cv <- sd(weights) / mean(weights)
deff <- 1 + weight_cv^2

# 4. Effective base
n_effective <- n_weighted / deff
```

**When to Use Each Base:**

- **Unweighted:** For sample size reporting, determining if base is too small
- **Weighted:** For percentage calculations (denominator)
- **Effective:** For significance testing (accounts for weighting impact)

---

### 10. Excel Writer (`excel_writer.R`)

**Purpose:** Format and write results to Excel workbook

**Known Issues:**
- **CR-TABS-002:** Uses `source(..., local = FALSE)` causing namespace pollution
  - **Workaround:** Load dependencies before excel_writer
  - **Status:** Will fix in v10.0

**Key Functions:**

```r
write_crosstab_excel(all_results, config, output_file)
# Writes complete crosstab workbook
# - One sheet per question (or combined if many questions)
# - Formatted with colors, borders, number formats
# - Includes metadata sheet

format_crosstab_sheet(wb, sheet_name, question_result, config)
# Formats one question sheet
# - Bold headers
# - Percentage number formats
# - Significance highlighting (letters in bold)
# - Freeze panes on row 1
```

**Excel Formatting:**

```r
# Percentage cells
pct_style <- createStyle(numFmt = "0%")

# Significance highlighting
sig_style <- createStyle(fontBold = TRUE, fontColour = "#0066CC")

# Header row
header_style <- createStyle(
  fontBold = TRUE,
  fillColor = "#4472C4",
  fontColour = "#FFFFFF",
  border = "TopBottomLeftRight",
  borderColour = "#000000"
)
```

---

### 11. Shared Functions (`shared_functions.R`)

**Purpose:** Utility functions used across the module

**Size:** 1,640 lines (needs refactoring)

**Known Issues:**
- **CR-TABS-003:** `log_issue()` function name is misleading
  - Current behavior: Pure function that returns updated log (no side effects)
  - Expected behavior: Function that logs issues (side effect)
  - **Workaround:** Remember to capture return value: `error_log <- log_issue(error_log, ...)`
  - **Fix:** Rename to `add_log_entry()` in v10.0

**Key Functions:**

```r
safe_equal(x, y)
# Type-safe equality comparison
# Handles factor/character/numeric conversions

safe_execute(expr, default = NULL, error_msg = NULL)
# TryCatch wrapper for safe execution
# Returns result or default on error

format_output_value(value, type, decimal_places_percent = 0,
                    decimal_places_average = 1)
# Formats numeric values for output
# Types: "percent", "average", "frequency", "count"

apply_base_filter(data, filter_expression)
# Applies filter expression to data
# Returns: Filtered data with .original_row column

log_issue(error_log, source, category, message, details, severity)
# Adds entry to error log (pure function - returns new log!)
# Severity: "Error", "Warning", "Info"
```

---

## Data Flow

### Complete Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│ 1. CONFIGURATION LOADING                                    │
│    - Load Tabs_Config.xlsx (Settings, Banner, Stub sheets)  │
│    - Load Survey_Structure.xlsx (Questions, Options)        │
│    - Resolve file paths                                     │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│ 2. VALIDATION                                               │
│    - Validate survey structure (questions, options)         │
│    - Validate survey data (columns, types)                  │
│    - Validate weights (if specified)                        │
│    - Validate banner selection                              │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│ 3. DATA LOADING                                             │
│    - Load survey data (CSV, XLSX, SAV, DTA)                 │
│    - Load weights (if specified)                            │
│    - Create banner structure                                │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│ 4. QUESTION LOOP (for each stub question)                   │
│    ┌────────────────────────────────────────────────────┐   │
│    │ 4a. Prepare Question Data                          │   │
│    │     - Load metadata and options                    │   │
│    │     - Apply base filter                            │   │
│    │     - Create banner indices                        │   │
│    │     - Calculate bases                              │   │
│    └────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│    ┌────────────────▼───────────────────────────────────┐   │
│    │ 4b. Dispatch to Processor                          │   │
│    │     - Detect question type                         │   │
│    │     - Route to appropriate processor               │   │
│    │     - Process question                             │   │
│    └────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│    ┌────────────────▼───────────────────────────────────┐   │
│    │ 4c. Process Question                               │   │
│    │     For each response option:                      │   │
│    │       - Calculate counts across banner             │   │
│    │       - Calculate percentages                      │   │
│    │       - Calculate significance                     │   │
│    │       - Build result rows                          │   │
│    └────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│    ┌────────────────▼───────────────────────────────────┐   │
│    │ 4d. Store Result                                   │   │
│    │     - Add to all_results list                      │   │
│    └────────────────────────────────────────────────────┘   │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│ 5. EXCEL OUTPUT                                             │
│    - Create workbook                                        │
│    - Write each question to sheet                           │
│    - Apply formatting (colors, borders, number formats)     │
│    - Write metadata sheet                                   │
│    - Save workbook                                          │
└─────────────────────────────────────────────────────────────┘
```

### Memory Flow

```
Configuration (small)
    ↓
Survey Structure (medium) ────────┐
    ↓                             │
Survey Data (large) ──────────────┼──> Kept in memory
    ↓                             │
Weights (medium) ─────────────────┘
    ↓
Banner Indices (medium)
    ↓
For each question:
    Filtered Data (large subset) ─────> Created, used, discarded
    Question Result (small) ──────────> Accumulated in all_results
    ↓
All Results (medium)
    ↓
Excel Workbook (large) ───────────────> Written to disk, memory freed
```

**Memory Optimization Strategies:**
1. Keep master weights and data - don't duplicate
2. Use index-based subsetting (`master_weights[row_idx]`)
3. Process questions sequentially - discard intermediate results
4. Write Excel incrementally if many questions
5. Use `gc()` after large operations

---

## API Reference

### Main Entry Point

```r
run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx",
  data_file = NULL,  # Can specify in config or here
  output_file = NULL,  # Can specify in config or here
  project_root = getwd()
)
```

**Returns:** List with results and validation info

**Example:**

```r
result <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)

# Check for errors
if (result$validation$has_errors) {
  print(result$validation$error_log$errors)
} else {
  cat("Success! Output written to:", result$output_file, "\n")
}
```

### Configuration Functions

```r
# Load configuration
config <- load_crosstab_configuration("Config.xlsx")

# Access settings
sig_level <- get_config_value(config$config, "significance_level", default = 0.05)

# Validate configuration
validation <- validate_configuration(config$config, config$paths, config$selection)
```

### Processing Functions

```r
# Prepare question data
prepared <- prepare_question_data(
  question_code = "Q01",
  base_filter = NA,
  survey_data = data,
  survey_structure = structure,
  banner_info = banner,
  master_weights = weights
)

# Process question (auto-detects type)
result <- process_question(
  question_code = "Q01",
  base_filter = NA,
  survey_data = data,
  survey_structure = structure,
  banner_info = banner,
  master_weights = weights,
  config = config,
  error_log = error_log
)

# Process specific question type
result <- process_standard_question(prepared, config, error_log)
result <- process_numeric_question(prepared, config, error_log)
result <- process_composite_question(prepared, config, error_log)
```

### Calculation Functions

```r
# Calculate weighted counts
counts <- calculate_row_counts(
  data, banner_row_indices, option_text,
  question_col, is_multi_mention, existing_cols,
  internal_keys, master_weights
)

# Calculate percentages
pct <- calculate_weighted_percentage(weighted_count, weighted_base)

# Create output rows
pct_row <- create_percentage_row(counts, banner_bases, internal_keys, "Brand A")
freq_row <- create_frequency_row(counts, internal_keys, "Brand A")

# Calculate bases
base_info <- calculate_weighted_base(data, question_info, weights)
# Returns: list(unweighted = 500, weighted = 500, effective = 450)

deff <- calculate_deff(weights)
effective_n <- calculate_effective_base(weighted_base, deff)
```

### Banner Functions

```r
# Create banner structure
banner_info <- create_banner_structure(banner_questions, survey_structure)

# Create banner indices
indices <- create_banner_row_indices(data, banner_info)

# Access specific banner column
male_indices <- indices$row_indices[["Q99_Male"]]
male_data <- data[male_indices, ]
```

### Validation Functions

```r
# Validate survey structure
error_log <- validate_survey_structure(survey_structure, error_log)

# Validate survey data
error_log <- validate_survey_data(data, survey_structure, error_log)

# Validate weights
error_log <- validate_weights(weights, data, error_log,
                               weight_na_threshold = 10,
                               weight_zero_threshold = 5)

# Check for errors
has_errors <- any(sapply(error_log$errors, function(x) x$severity == "Error"))
```

### Output Functions

```r
# Write Excel workbook
write_crosstab_excel(all_results, config, "output.xlsx")

# Format specific sheet
wb <- createWorkbook()
addWorksheet(wb, "Q01")
format_crosstab_sheet(wb, "Q01", question_result, config)
saveWorkbook(wb, "output.xlsx")
```

---

## Statistical Algorithms

### 1. Chi-Square Test (Categorical Data)

**Use Case:** Testing independence between categorical variables

**Implementation:**

```r
# For each cell in the table:
# O = Observed count (weighted)
# E = Expected count = (row total × column total) / grand total

chi_square <- sum((O - E)^2 / E)
df <- (n_rows - 1) * (n_cols - 1)
p_value <- pchisq(chi_square, df, lower.tail = FALSE)

# Significance: p_value < alpha (typically 0.05)
```

**Assumptions:**
- Expected counts should be ≥ 5 in at least 80% of cells
- Independent observations
- Random sampling

**Letter Assignment:**

```r
# Column A is significantly higher than columns with letter 'A' in their sig row
# Example: If Male column shows 'F', Male is significantly higher than Female
```

### 2. Z-Test (Proportions)

**Use Case:** Testing difference between two proportions

**Implementation:**

```r
# Compare column i vs column j
p1 <- count1 / base1  # Proportion in column i
p2 <- count2 / base2  # Proportion in column j

# Pooled proportion
p_pool <- (count1 + count2) / (base1 + base2)

# Standard error
se <- sqrt(p_pool * (1 - p_pool) * (1/base1 + 1/base2))

# Z statistic
z <- (p1 - p2) / se

# P-value (two-tailed)
p_value <- 2 * pnorm(-abs(z))

# Significance: p_value < alpha
```

**When to Use:**
- Comparing percentages between two groups
- Large sample sizes (n > 30)
- Simple, fast calculation

### 3. T-Test (Means)

**Use Case:** Testing difference between two means (averages)

**Implementation:**

```r
# Compare means from two columns
# Welch's t-test (unequal variances)

mean1 <- weighted.mean(values1, weights1)
mean2 <- weighted.mean(values2, weights2)

var1 <- weighted.var(values1, weights1)
var2 <- weighted.var(values2, weights2)

# Effective sample sizes (accounts for weighting)
n1_eff <- base1 / deff1
n2_eff <- base2 / deff2

# Standard error
se <- sqrt(var1/n1_eff + var2/n2_eff)

# T statistic
t <- (mean1 - mean2) / se

# Degrees of freedom (Welch-Satterthwaite)
df <- (var1/n1_eff + var2/n2_eff)^2 /
      ((var1/n1_eff)^2/(n1_eff-1) + (var2/n2_eff)^2/(n2_eff-1))

# P-value (two-tailed)
p_value <- 2 * pt(-abs(t), df)
```

**When to Use:**
- Comparing averages (Rating, Numeric questions)
- Any sample size
- Accounts for variance differences

### 4. Design Effect (DEFF)

**Purpose:** Measure impact of weighting on effective sample size

**Formula:**

```r
# Method: Coefficient of Variation
weight_mean <- mean(weights)
weight_sd <- sd(weights)
cv <- weight_sd / weight_mean

deff <- 1 + cv^2

# Effective base
n_effective <- n_weighted / deff
```

**Interpretation:**
- DEFF = 1.0: No weighting impact (all weights equal)
- DEFF = 1.5: Moderate weighting (effective n = 67% of weighted n)
- DEFF = 2.0: Strong weighting (effective n = 50% of weighted n)
- DEFF > 3.0: Very strong weighting (warning threshold)

**Impact on Significance Testing:**

```r
# Without DEFF: Use weighted base (inflated significance)
z <- (p1 - p2) / se_weighted

# With DEFF: Use effective base (correct significance)
z <- (p1 - p2) / se_effective

# se_effective > se_weighted, so significance is more conservative
```

### 5. Composite Metrics

**Top-2-Box:**

```r
# For 5-point scale: % who answered 4 or 5
top2_count <- sum(weights[values >= 4])
top2_pct <- top2_count / sum(weights) * 100
```

**Bottom-2-Box:**

```r
# For 5-point scale: % who answered 1 or 2
bottom2_count <- sum(weights[values <= 2])
bottom2_pct <- bottom2_count / sum(weights) * 100
```

**Net Score:**

```r
# Difference between top and bottom
net_score <- top2_pct - bottom2_pct
```

---

## Extension Points

### Adding a New Question Type

**Step 1:** Define the question type in `Survey_Structure.xlsx`:

```
QuestionCode | QuestionText        | Variable_Type
Q50          | Custom Question     | Custom_Type
```

**Step 2:** Add processor function in new file `lib/custom_processor.R`:

```r
process_custom_question <- function(prepared_data, config, error_log) {

  # Extract prepared data
  question_info <- prepared_data$question_info
  filtered_data <- prepared_data$filtered_data
  banner_bases <- prepared_data$banner_bases
  # ...

  # Perform custom calculations
  result_table <- data.frame()

  # ... build result table ...

  # Return standard result structure
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

**Step 3:** Update dispatcher in `question_dispatcher.R`:

```r
# Add to process_question() routing logic
if (question_type == "Custom_Type") {
  result <- process_custom_question(prepared_data, config, error_log)
}
```

**Step 4:** Source new file in `run_crosstabs.R`:

```r
source(file.path(script_dir, "custom_processor.R"))
```

### Adding a New Statistical Test

**Step 1:** Add test function in `lib/statistical_tests.R` (create if needed):

```r
calculate_custom_test <- function(count1, base1, count2, base2, alpha = 0.05) {

  # Perform statistical test
  # ...

  # Return test result
  return(list(
    statistic = test_stat,
    p_value = p_val,
    significant = (p_val < alpha)
  ))
}
```

**Step 2:** Update significance calculation in processors:

```r
if (config$stat_test == "custom-test") {
  test_result <- calculate_custom_test(...)
  if (test_result$significant) {
    # Add significance letter
  }
}
```

**Step 3:** Add to configuration options in documentation.

### Adding Excel Formatting Options

**Step 1:** Add configuration setting in `Tabs_Config.xlsx`:

```
Setting              | Value
highlight_color      | #FFFF00
```

**Step 2:** Use in `excel_writer.R`:

```r
highlight_color <- config$highlight_color
highlight_style <- createStyle(fillColor = highlight_color)

conditionalFormatting(wb, sheet, cols, rows,
                      rule = ">50", style = highlight_style)
```

### Creating Custom Output Formats

**Step 1:** Create new output writer (e.g., `lib/html_writer.R`):

```r
write_crosstab_html <- function(all_results, config, output_file) {

  html <- "<html><body>"

  for (result in all_results) {
    # Convert result to HTML table
    html <- paste0(html, "<h2>", result$question_text, "</h2>")
    html <- paste0(html, convert_to_html_table(result$table))
  }

  html <- paste0(html, "</body></html>")

  writeLines(html, output_file)
}
```

**Step 2:** Add output format option to config and dispatcher.

---

## Performance Optimization

### Current Performance Characteristics

**Benchmark (tested on MacBook Pro M1):**

| Dataset Size | Questions | Banner Cols | Processing Time |
|--------------|-----------|-------------|-----------------|
| 500 rows     | 20        | 5           | 2-3 seconds     |
| 2,000 rows   | 50        | 10          | 8-12 seconds    |
| 10,000 rows  | 100       | 15          | 45-60 seconds   |
| 50,000 rows  | 200       | 20          | 5-8 minutes     |

**Memory Usage:**
- 10,000 rows × 100 cols: ~200 MB RAM
- 50,000 rows × 200 cols: ~1 GB RAM

### Optimization Strategies

**1. Vectorization (Already Implemented)**

```r
# GOOD: Vectorized operations
matching <- data[[col]] == value
count <- sum(weights[matching])

# BAD: Loop-based operations
count <- 0
for (i in 1:nrow(data)) {
  if (data[[col]][i] == value) {
    count <- count + weights[i]
  }
}
```

**2. Index-Based Subsetting (Already Implemented)**

```r
# GOOD: Subset by index
subset_weights <- master_weights[row_idx]

# BAD: Filter and extract
subset_weights <- data$weight[data$segment == "A"]
```

**3. Batch Processing (Partially Implemented)**

```r
# For very large datasets, process questions in batches
batch_size <- 20
for (batch_start in seq(1, length(questions), by = batch_size)) {
  batch_end <- min(batch_start + batch_size - 1, length(questions))
  batch_questions <- questions[batch_start:batch_end]

  # Process batch
  batch_results <- lapply(batch_questions, process_question, ...)

  # Write batch to Excel
  # Free memory
  rm(batch_results)
  gc()
}
```

**4. Parallel Processing (Not Yet Implemented)**

```r
# Future enhancement: Process questions in parallel
library(parallel)

cl <- makeCluster(detectCores() - 1)
clusterExport(cl, c("data", "config", "banner_info", ...))

all_results <- parLapply(cl, questions, function(q) {
  process_question(q, ...)
})

stopCluster(cl)
```

**5. Data.table for Large Datasets (Optional)**

```r
# Convert to data.table for faster operations
library(data.table)
dt <- as.data.table(data)

# Fast subsetting and aggregation
dt[segment == "A", sum(weight)]
```

### Memory Monitoring

```r
# Check memory usage
if (requireNamespace("pryr", quietly = TRUE)) {
  mem_used <- pryr::mem_used()
  if (mem_used > 6e9) {  # 6 GB
    warning("High memory usage detected. Consider processing in batches.")
  }
}

# Force garbage collection after large operations
gc()
```

### Profiling

```r
# Profile code to identify bottlenecks
Rprof("profile.out")
result <- run_crosstabs(...)
Rprof(NULL)

# View profile
summaryRprof("profile.out")
```

---

## Known Issues

### Critical Issues (Fix in v10.0)

**CR-TABS-001: Undefined Constant**
- **File:** `modules/tabs/lib/validation.R:1260`
- **Issue:** `MAX_DECIMAL_PLACES` constant used but never defined
- **Impact:** Runtime error when validating decimal places
- **Workaround:** Add `MAX_DECIMAL_PLACES <- 6` at top of validation.R
- **Fix:** Define in constants section

**CR-TABS-002: Global Namespace Pollution**
- **File:** `modules/tabs/lib/excel_writer.R:68`
- **Issue:** `source(..., local = FALSE)` loads functions into global environment
- **Impact:** Function name collisions, hard-to-debug errors
- **Workaround:** Load dependencies before excel_writer
- **Fix:** Change to `source(..., local = TRUE)` or use explicit environment

**CR-TABS-003: Misleading Function Name**
- **File:** `modules/tabs/lib/shared_functions.R:992`
- **Issue:** `log_issue()` is a pure function but name suggests side effect
- **Impact:** Users forget to capture return value, losing log entries
- **Workaround:** Always use `error_log <- log_issue(error_log, ...)`
- **Fix:** Rename to `add_log_entry()` and document clearly

### High-Priority Issues

**Eliminate Filter Validation Duplication**
- **Issue:** Filter validation logic duplicated across multiple files
- **Impact:** Inconsistent validation, maintenance burden
- **Fix:** Centralize in validation.R

**Extract Magic Numbers**
- **Issue:** Hard-coded thresholds (30, 0.05, etc.) scattered in code
- **Impact:** Hard to change settings, unclear assumptions
- **Fix:** Define all constants at module level

**Split shared_functions.R**
- **Issue:** 1,640 lines in single file, multiple responsibilities
- **Impact:** Hard to navigate, test, and maintain
- **Fix:** Split into focused modules (formatting.R, filtering.R, logging.R, etc.)

### Medium-Priority Issues

**Improve Error Messages**
- Some validation errors don't specify which question/option failed
- Add question context to all error messages

**Add Progress Indicators**
- No progress feedback for long-running analyses
- Add progress bar for question loop

**Enhance Excel Formatting**
- Limited customization options
- Add configurable color schemes, fonts, etc.

### Low-Priority Issues

**Performance on Very Large Datasets**
- Processing slows significantly above 50,000 rows
- Consider parallel processing or C++ implementation for bottlenecks

**Limited Statistical Tests**
- Only chi-square, z-test, t-test available
- Add Fisher's exact test, Mann-Whitney U, etc.

**No Interactive Output**
- Only Excel output supported
- Add HTML, PDF, or Shiny app output options

---

## Testing Strategy

### Current Test Coverage

**Estimated Coverage:** <10% (mostly manual testing)

**Priority for v10.0:** Increase to 80%+

### Test Structure (Planned)

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

### Unit Testing Example

```r
# test_cell_calculator.R
library(testthat)

test_that("calculate_weighted_percentage handles zero base", {
  result <- calculate_weighted_percentage(50, 0)
  expect_true(is.na(result))
})

test_that("calculate_weighted_percentage calculates correctly", {
  result <- calculate_weighted_percentage(50, 200)
  expect_equal(result, 25)
})

test_that("calculate_row_counts handles multi-mention correctly", {
  # Setup test data
  data <- data.frame(
    Q01_1 = c("A", "B", NA),
    Q01_2 = c("A", NA, "C"),
    Q01_3 = c(NA, "B", "A")
  )
  weights <- c(1, 1, 1)
  banner_row_indices <- list(Total = 1:3)

  # Test
  counts <- calculate_row_counts(
    data, banner_row_indices, "A",
    "Q01", TRUE, c("Q01_1", "Q01_2", "Q01_3"),
    c("Total"), weights
  )

  # Expect 3 mentions of "A" (rows 1, 1, 3)
  expect_equal(counts["Total"], 3)
})
```

### Integration Testing

```r
test_that("full crosstab pipeline works end-to-end", {
  # Setup test files
  config_file <- "fixtures/test_config.xlsx"
  structure_file <- "fixtures/test_structure.xlsx"

  # Run pipeline
  result <- run_crosstabs(
    config_file = config_file,
    survey_structure_file = structure_file
  )

  # Verify results
  expect_false(result$validation$has_errors)
  expect_true(file.exists(result$output_file))
  expect_gt(length(result$all_results), 0)

  # Cleanup
  unlink(result$output_file)
})
```

### Manual Testing Checklist

- [ ] Single_Response questions display correctly
- [ ] Multi_Mention questions count mentions correctly
- [ ] Rating questions calculate averages
- [ ] NPS questions calculate NPS score
- [ ] Numeric questions show summary statistics
- [ ] Ranking questions calculate mean rank
- [ ] Composite questions aggregate correctly
- [ ] Significance testing shows correct letters
- [ ] Base filters subset data correctly
- [ ] Weighted analysis calculates DEFF
- [ ] Excel formatting applies correctly
- [ ] Large datasets (10,000+ rows) process without errors
- [ ] Missing data handled gracefully
- [ ] Invalid configuration files produce clear errors

---

## Debugging Guide

### Common Issues and Solutions

**Issue: "Configuration file not found"**

```r
# Check file path
file.exists("Tabs_Config.xlsx")  # Should be TRUE

# Check working directory
getwd()  # Should be project directory

# Fix: Use absolute path or setwd()
config_file <- file.path(project_path, "Tabs_Config.xlsx")
```

**Issue: "Question not found: Q01"**

```r
# Check Survey_Structure.xlsx
questions <- readxl::read_excel("Survey_Structure.xlsx", sheet = "Questions")
View(questions)

# Verify QuestionCode matches exactly (case-sensitive)
"Q01" %in% questions$QuestionCode

# Check for whitespace
questions$QuestionCode <- trimws(questions$QuestionCode)
```

**Issue: "Column Q01 not found in data"**

```r
# Check data column names
names(data)

# Check for case differences
grep("q01", names(data), ignore.case = TRUE, value = TRUE)

# Check Survey_Structure QuestionCode matches data column name
```

**Issue: "All weights are NA"**

```r
# Check weight column name
config$weight_column  # e.g., "weight"

# Check data has weight column
"weight" %in% names(data)

# Check weight values
summary(data$weight)

# Fix: Specify correct weight column or set to NA for unweighted
```

**Issue: "Significance testing shows no significant differences"**

```r
# Check significance level
config$significance_level  # Should be 0.05 or 0.10

# Check base sizes (need sufficient power)
summary(banner_bases)

# Check if differences exist
table(data$Q01, data$Gender)

# Try different statistical test
config$stat_test <- "z-test"  # vs "chi-square"
```

**Issue: "Excel file is huge (>100 MB)"**

```r
# Check number of questions × banner columns
n_questions * n_banner_cols  # If > 10,000, consider splitting

# Disable frequencies if not needed
config$show_frequencies <- FALSE

# Reduce decimal places
config$decimal_places <- 0
config$decimal_places_average <- 1
```

**Issue: "Processing is very slow"**

```r
# Profile the code
Rprof("profile.out")
result <- run_crosstabs(...)
Rprof(NULL)
summaryRprof("profile.out")

# Check for:
# - Very large dataset (>50,000 rows)
# - Many banner columns (>20)
# - Complex filters
# - Slow data file format (Excel vs CSV)

# Solutions:
# - Convert Excel data to CSV
# - Reduce banner columns
# - Process in batches
# - Use data.table for large datasets
```

### Enabling Debug Mode

```r
# Add debug messages to code
DEBUG <- TRUE

if (DEBUG) {
  cat("Processing question:", question_code, "\n")
  cat("Base filter:", base_filter, "\n")
  cat("Banner bases:", str(banner_bases), "\n")
}

# Or use browser() for interactive debugging
process_question <- function(...) {
  browser()  # Execution will pause here
  # ... rest of function
}
```

### Checking Intermediate Results

```r
# After run_crosstabs(), examine results
result <- run_crosstabs(...)

# Check validation
View(result$validation$error_log)

# Check all_results structure
str(result$all_results[[1]])

# Check specific question
q01_result <- result$all_results[[1]]
View(q01_result$table)
View(q01_result$bases)

# Check significance
if (!is.null(q01_result$significance)) {
  View(q01_result$significance)
}
```

### Logging

```r
# Enable detailed logging (future enhancement)
config$log_level <- "DEBUG"  # vs "INFO", "WARNING", "ERROR"
config$log_file <- "crosstabs.log"

# Write log messages
log_message <- function(level, message) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  entry <- sprintf("[%s] %s: %s\n", timestamp, level, message)
  cat(entry, file = config$log_file, append = TRUE)
}
```

---

## Version History

**v9.9 (2025-11-04) - Current Production Release**
- Modular architecture with 16 specialized files
- Enhanced validation with configurable thresholds
- Composite metrics support
- Design Effect (DEFF) calculations
- Memory optimization (index-based subsetting)
- Support for integer64 and labelled data types

**v9.0 (2024-09-15)**
- Complete rewrite from v8.0
- Breaking changes in configuration structure
- Added question orchestrator pattern
- Improved error handling and validation

**v8.0 (2024-03-20)**
- Legacy version (incompatible with v9.x)
- Monolithic architecture (single file)
- Limited question type support

---

## Future Roadmap

### v10.0 (Planned - Q1 2026)

**Bug Fixes:**
- Fix CR-TABS-001, CR-TABS-002, CR-TABS-003
- Eliminate filter validation duplication
- Extract all magic numbers to constants

**Refactoring:**
- Split shared_functions.R into focused modules
- Improve function naming consistency
- Add comprehensive inline documentation

**Testing:**
- Achieve 80%+ test coverage
- Automated test suite with CI/CD
- Performance regression testing

### v10.1 (Planned - Q2 2026)

**New Features:**
- Parallel processing for large datasets
- Progress indicators for long-running jobs
- HTML and PDF output formats
- Interactive Shiny dashboard

**Statistical Enhancements:**
- Fisher's exact test
- Mann-Whitney U test
- Bonferroni correction for multiple comparisons
- Confidence intervals for percentages

### v11.0 (Planned - Q3 2026)

**Advanced Features:**
- Nested banner support (Gender × Age Group)
- Custom composite metric builder
- Time-series trend analysis
- Integration with Turas Tracker module

**Performance:**
- C++ implementation of bottleneck functions (Rcpp)
- Database backend support for very large datasets
- Incremental processing (process new data only)

---

## Contributing

### Code Style

```r
# Function naming: snake_case
calculate_weighted_percentage <- function(...) { }

# Variable naming: snake_case
weighted_base <- 500

# Constants: SCREAMING_SNAKE_CASE
MAX_DECIMAL_PLACES <- 6

# Internal functions: prefix with dot
.helper_function <- function(...) { }
```

### Documentation Standards

```r
#' Function Title
#'
#' Detailed description of what the function does.
#' Can span multiple lines.
#'
#' @param param1 Description of param1
#' @param param2 Description of param2
#' @return Description of return value
#' @export
#' @examples
#' result <- my_function("value1", 123)
my_function <- function(param1, param2) {
  # Implementation
}
```

### Pull Request Process

1. Create feature branch from main: `git checkout -b feature/my-feature`
2. Make changes with clear commit messages
3. Add/update tests for new functionality
4. Update documentation (this file, USER_MANUAL.md)
5. Run test suite: `testthat::test_dir("tests")`
6. Submit pull request with description of changes

### Testing Requirements

- All new functions must have unit tests
- Test coverage should not decrease
- All tests must pass before merging
- Include edge cases and error conditions

---

## Support

### Getting Help

1. **Documentation:** Read QUICK_START.md, USER_MANUAL.md first
2. **Examples:** Check EXAMPLE_WORKFLOWS.md for common patterns
3. **Issues:** Check known issues section above
4. **Debugging:** Use debugging guide above

### Reporting Bugs

Include:
1. Turas Tabs version (check `SCRIPT_VERSION` in run_crosstabs.R)
2. R version (`R.version.string`)
3. Operating system
4. Minimal reproducible example
5. Error message (full text)
6. Expected vs actual behavior

### Feature Requests

Feature requests are welcome! Please describe:
1. Use case (what problem does it solve?)
2. Proposed solution (how should it work?)
3. Alternatives considered
4. Priority (nice-to-have vs critical)

---

## License

Turas Analytics Toolkit - Proprietary

---

**Document Version:** 1.0
**Last Updated:** 2025-11-18
**Maintainer:** Turas Analytics Team
