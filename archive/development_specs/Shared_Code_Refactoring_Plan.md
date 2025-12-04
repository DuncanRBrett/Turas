# TURAS Shared Code Refactoring Plan

**Purpose:** Guide for extracting shared code between TurasTabs and TurasTracker
**Status:** Planning Document
**Created:** November 2025
**Module Versions:** TurasTabs V10.1, TurasTracker MVT Phase 1

---

## Overview

TurasTabs (within-wave crosstabulation) and TurasTracker (across-wave tracking) share significant common functionality. This document identifies code that should be extracted to a shared library (`/shared/`) to:

- **Eliminate duplication** - Single source of truth for calculations
- **Ensure consistency** - Same algorithms produce same results
- **Reduce maintenance** - Fix bugs once, benefit both modules
- **Enable reuse** - Future modules can leverage shared code

---

## Architectural Vision

```
/Turas/
├── modules/
│   ├── tabs/                          # TurasTabs (within-wave)
│   │   ├── run_crosstabs.R
│   │   └── lib/
│   │       ├── config_loader.R        → Uses shared/config_utils.R
│   │       ├── weights.R              → REPLACE with shared/weights.R
│   │       ├── significance.R         → REPLACE with shared/significance_tests.R
│   │       └── ...
│   │
│   ├── tracker/                       # TurasTracker (across-wave)
│   │   ├── run_tracker.R
│   │   ├── tracker_config_loader.R    → Uses shared/config_utils.R
│   │   ├── wave_loader.R              → Uses shared/weights.R
│   │   └── ...
│   │
│   └── shared/                        # SHARED CODE (NEW)
│       ├── config_utils.R             # Configuration utilities
│       ├── weights.R                  # Weight calculations
│       ├── significance_tests.R       # Statistical testing
│       ├── composite_calculator.R     # Composite score logic
│       ├── formatting.R               # Number formatting
│       ├── excel_styles.R             # Excel output styles
│       ├── validation_utils.R         # Common validation
│       └── data_utils.R               # Data loading/handling
│
└── docs/
    └── Shared_Code_Refactoring_Plan.md  # This document
```

---

## Phase 1: Shared Code to Extract

### 1. `/shared/config_utils.R`

**Purpose:** Common configuration file handling

**Functions to Extract:**

#### From TurasTabs `config_loader.R` and TurasTracker `tracker_config_loader.R`:

```r
#' Read Configuration Sheet
#'
#' Generic function to read a sheet from Excel config file with error handling.
#'
#' @param config_path Character. Path to .xlsx config file
#' @param sheet_name Character. Name of sheet to read
#' @param detect_dates Logical. Parse dates automatically
#' @return Data frame, or stops with informative error
#'
#' @export
read_config_sheet <- function(config_path, sheet_name, detect_dates = FALSE) {
  # EXTRACT FROM: Both modules have nearly identical code
  # SOURCE: TurasTabs config_loader.R lines ~50-70
  # SOURCE: TurasTracker tracker_config_loader.R lines ~30-45
}

#' Parse Settings to Named List
#'
#' Converts settings dataframe (Setting, Value columns) to named list.
#' Handles type conversion (Y/N → logical, numeric strings → numbers).
#'
#' @param settings_df Data frame with 'Setting' and 'Value' columns
#' @return Named list
#'
#' @export
parse_settings_to_list <- function(settings_df) {
  # EXTRACT FROM: TurasTracker tracker_config_loader.R lines 140-165
  # ALSO IN: TurasTabs config_loader.R (similar pattern)
}

#' Get Setting with Default
#'
#' Safely retrieve setting value with fallback.
#'
#' @param config Configuration object (list)
#' @param setting_name Character. Setting to retrieve
#' @param default Default value if not found
#' @return Setting value or default
#'
#' @export
get_setting <- function(config, setting_name, default = NULL) {
  # EXTRACT FROM: TurasTracker tracker_config_loader.R lines 206-214
  # ALSO IN: TurasTabs (used throughout)
}

#' Validate Required Columns
#'
#' Check that required columns exist in dataframe.
#'
#' @param df Data frame to validate
#' @param required_cols Character vector of required column names
#' @param context_name Character. Name for error messages
#' @return Invisible TRUE or stops with error
#'
#' @export
validate_required_columns <- function(df, required_cols, context_name) {
  # NEW UTILITY - Pattern used in both modules
}
```

**Notes:**
- Both modules have nearly identical config reading code
- Parse_settings logic is duplicated
- Extraction will eliminate ~80 lines of duplicate code

---

### 2. `/shared/weights.R`

**Purpose:** Weight calculation and validation

**Functions to Extract:**

#### From TurasTabs and TurasTracker:

```r
#' Apply Weights to Data
#'
#' Standardizes weight variable and validates weight values.
#'
#' @param data_df Data frame containing survey data
#' @param weight_var Character. Name of weight variable
#' @param context_name Character. Name for error messages (e.g., "Wave W1")
#' @return Data frame with standardized weight_var column
#'
#' @export
apply_weights <- function(data_df, weight_var, context_name = "Data") {
  # EXTRACT FROM: TurasTracker wave_loader.R lines 112-150
  # SIMILAR IN: TurasTabs data handling
  #
  # Key logic:
  # - Check weight variable exists
  # - Validate weights (no NA, no <=0)
  # - Create standardized weight_var column
  # - Report warnings for invalid weights
}

#' Calculate Weight Efficiency
#'
#' Calculates effective sample size (design effect).
#' Formula: (sum of weights)^2 / sum of squared weights
#'
#' @param weights Numeric vector of weight values
#' @return Numeric. Effective sample size
#'
#' @export
calculate_weight_efficiency <- function(weights) {
  # EXTRACT FROM: TurasTracker wave_loader.R lines 153-163
  # USED IN: Both modules for reporting
  #
  # This is CRITICAL to extract - calculation must be identical
}

#' Validate Weight Distribution
#'
#' Checks weight distribution for potential issues.
#'
#' @param weights Numeric vector
#' @param min_weight Minimum acceptable weight (default 0)
#' @param max_weight Maximum acceptable weight (default Inf)
#' @return List with warnings and statistics
#'
#' @export
validate_weight_distribution <- function(weights, min_weight = 0, max_weight = Inf) {
  # NEW UTILITY - Combines patterns from both modules
}

#' Get Weight Summary Statistics
#'
#' Returns descriptive statistics for weights.
#'
#' @param weights Numeric vector
#' @return Data frame with min, max, mean, median, efficiency
#'
#' @export
get_weight_summary <- function(weights) {
  # NEW UTILITY - Standardized reporting
}
```

**Notes:**
- Weight efficiency calculation is IDENTICAL - must be shared
- Both modules validate weights similarly
- ~100 lines of code to extract

---

### 3. `/shared/significance_tests.R`

**Purpose:** Statistical significance testing

**Functions to Extract:**

#### From TurasTabs `significance.R`:

```r
#' Z-Test for Proportions
#'
#' Two-sample z-test for comparing proportions.
#'
#' @param p1 Proportion in group 1
#' @param n1 Sample size group 1
#' @param p2 Proportion in group 2
#' @param n2 Sample size group 2
#' @param alpha Significance level (default 0.05)
#' @return List with z_stat, p_value, significant
#'
#' @export
z_test_proportions <- function(p1, n1, p2, n2, alpha = 0.05) {
  # EXTRACT FROM: TurasTabs significance.R
  # WILL BE USED: TurasTracker Phase 2 (trend testing)
}

#' T-Test for Means
#'
#' Two-sample t-test for comparing means.
#'
#' @param mean1 Mean of group 1
#' @param sd1 Standard deviation group 1
#' @param n1 Sample size group 1
#' @param mean2 Mean of group 2
#' @param sd2 Standard deviation group 2
#' @param n2 Sample size group 2
#' @param alpha Significance level (default 0.05)
#' @return List with t_stat, df, p_value, significant
#'
#' @export
t_test_means <- function(mean1, sd1, n1, mean2, sd2, n2, alpha = 0.05) {
  # EXTRACT FROM: TurasTabs significance.R
  # WILL BE USED: TurasTracker Phase 2 (trend testing)
}

#' Apply Significance Letters
#'
#' Assigns significance letters (A, B, C, etc.) based on test results.
#'
#' @param sig_matrix Matrix of significance test results
#' @param column_labels Character vector of column names
#' @return Character vector of letter codes
#'
#' @export
apply_significance_letters <- function(sig_matrix, column_labels) {
  # EXTRACT FROM: TurasTabs significance.R
  # WILL BE USED: TurasTracker Phase 2
}
```

**Notes:**
- TurasTracker Phase 2 will need identical sig testing logic
- Tracker will compare waves (W1 vs W2) instead of banner columns
- ~200 lines to extract from TurasTabs

---

### 4. `/shared/composite_calculator.R`

**Purpose:** Composite score calculations

**Functions to Extract:**

#### From TurasTabs `composite_processor.R`:

```r
#' Calculate Composite Mean
#'
#' Calculates mean composite score from source questions.
#'
#' @param data_df Data frame with source question columns
#' @param source_questions Character vector of question codes
#' @param weight_var Character. Weight variable name
#' @return Numeric vector of composite scores
#'
#' @export
calculate_composite_mean <- function(data_df, source_questions, weight_var = "weight_var") {
  # EXTRACT FROM: TurasTabs composite_processor.R
  # WILL BE USED: TurasTracker Phase 3 (composite tracking)
}

#' Calculate Composite Sum
#'
#' Calculates sum composite score.
#'
#' @export
calculate_composite_sum <- function(data_df, source_questions, weight_var = "weight_var") {
  # EXTRACT FROM: TurasTabs composite_processor.R
}

#' Calculate Composite Weighted Mean
#'
#' Calculates weighted mean composite with custom weights per question.
#'
#' @export
calculate_composite_weighted_mean <- function(data_df, source_questions,
                                               question_weights, weight_var = "weight_var") {
  # EXTRACT FROM: TurasTabs composite_processor.R
}

#' Validate Composite Definition
#'
#' Checks composite definition for completeness and validity.
#'
#' @export
validate_composite_definition <- function(composite_def, available_questions) {
  # EXTRACT FROM: TurasTabs composite_processor.R
}
```

**Notes:**
- TurasTracker Phase 3 will track composites across waves
- Calculation logic MUST be identical to TurasTabs
- ~150 lines to extract

---

### 5. `/shared/formatting.R`

**Purpose:** Number and text formatting utilities

**Functions to Extract:**

```r
#' Format Number for Output
#'
#' Formats number with specified decimal places and separator.
#'
#' @param value Numeric value
#' @param decimal_places Integer (0-3)
#' @param decimal_separator Character. "." or ","
#' @return Character. Formatted value
#'
#' @export
format_number <- function(value, decimal_places = 1, decimal_separator = ".") {
  # EXTRACT FROM: TurasTabs formatting utilities
  # USED IN: Both modules for consistent output
}

#' Format Percentage
#'
#' Formats percentage value.
#'
#' @export
format_percentage <- function(value, decimal_places = 0, decimal_separator = ".",
                               include_percent_sign = FALSE) {
  # EXTRACT FROM: TurasTabs
}

#' Format Index Value
#'
#' Formats index/rating score.
#'
#' @export
format_index <- function(value, decimal_places = 1, decimal_separator = ".") {
  # EXTRACT FROM: TurasTabs
}
```

---

### 6. `/shared/excel_styles.R`

**Purpose:** Excel output styling (already partially exists)

**Functions to Harmonize:**

```r
#' Create Standard Styles
#'
#' Creates standard Excel styles for TURAS output.
#'
#' @export
create_standard_styles <- function() {
  # ALREADY EXISTS: TurasTabs excel_writer.R
  # WILL BE USED: TurasTracker Phase 2 output
}

#' Apply Header Style
#' Apply Data Style
#' Apply Significance Style
# etc.
```

**Notes:**
- TurasTabs has robust Excel styling
- Extract to `/shared/excel_styles.R`
- TurasTracker will use for consistent output

---

### 7. `/shared/validation_utils.R`

**Purpose:** Common validation patterns

**Functions to Extract:**

```r
#' Validate Date Range
#'
#' Checks that end_date >= start_date.
#'
#' @export
validate_date_range <- function(start_date, end_date, context_name) {
  # PATTERN FROM: Both modules validate fieldwork dates
}

#' Check for Duplicates
#'
#' Validates uniqueness of identifiers.
#'
#' @export
check_duplicates <- function(values, value_name, context_name) {
  # PATTERN FROM: Both modules check for duplicate IDs
}

#' Merge Validation Results
#'
#' Combines multiple validation result lists.
#'
#' @export
merge_validation_results <- function(results1, results2) {
  # EXTRACT FROM: TurasTracker validation_tracker.R line 241-247
}

#' Create Validation Result
#'
#' Standard structure for validation results.
#'
#' @export
create_validation_result <- function(errors = character(0),
                                     warnings = character(0),
                                     info = character(0)) {
  # NEW UTILITY - Standardizes validation patterns
}
```

---

### 8. `/shared/data_utils.R`

**Purpose:** Data loading and handling

**Functions to Extract:**

```r
#' Load Data File
#'
#' Generic data loader supporting CSV and Excel.
#'
#' @param file_path Character. Path to data file
#' @param sheet Integer/Character. Sheet name/number for Excel (default 1)
#' @param context_name Character. For error messages
#' @return Data frame
#'
#' @export
load_data_file <- function(file_path, sheet = 1, context_name = "Data") {
  # EXTRACT FROM: TurasTracker wave_loader.R lines 50-80
  # PATTERN IN: TurasTabs data loading
}

#' Resolve File Path
#'
#' Handles absolute and relative paths.
#'
#' @export
resolve_file_path <- function(file_path, base_dir = NULL) {
  # EXTRACT FROM: TurasTracker wave_loader.R lines 83-98
}

#' Validate Data Structure
#'
#' Basic data validation (non-empty, has columns, etc.).
#'
#' @export
validate_data_structure <- function(data_df, min_rows = 1, required_cols = NULL) {
  # PATTERN FROM: Both modules validate loaded data
}
```

---

## Refactoring Roadmap

### Immediate (Before Phase 2)

**Priority:** HIGH
**Modules:** `weights.R`, `significance_tests.R`

These are needed for TurasTracker Phase 2 (trend calculation):

1. Extract `calculate_weight_efficiency()` to `/shared/weights.R`
2. Extract significance testing functions to `/shared/significance_tests.R`
3. Update TurasTabs to source from `/shared/`
4. Update TurasTracker to source from `/shared/`
5. Test both modules to ensure identical results

**Estimated Effort:** 2-3 hours
**Risk:** Low (well-defined functions with clear inputs/outputs)

---

### Short Term (Before Phase 3)

**Priority:** MEDIUM
**Modules:** `config_utils.R`, `formatting.R`, `composite_calculator.R`

Needed for TurasTracker Phase 3 (composites):

1. Extract composite calculation logic
2. Extract configuration utilities
3. Extract formatting functions
4. Update both modules to use shared code

**Estimated Effort:** 4-5 hours
**Risk:** Medium (more integration points)

---

### Long Term (After MVT Complete)

**Priority:** LOW
**Modules:** `excel_styles.R`, `validation_utils.R`, `data_utils.R`

Polish and optimization:

1. Harmonize Excel styling
2. Consolidate validation patterns
3. Create comprehensive shared utilities

**Estimated Effort:** 3-4 hours
**Risk:** Low (incremental improvements)

---

## Testing Strategy

### For Each Shared Module:

1. **Create Unit Tests**
   - Test each shared function in isolation
   - Use synthetic test data
   - Verify edge cases (NA, empty, extremes)

2. **Verify TurasTabs Compatibility**
   - Run existing TurasTabs test suite
   - Confirm identical output to pre-refactoring
   - Check performance is not degraded

3. **Verify TurasTracker Compatibility**
   - Run TurasTracker test suite
   - Confirm expected behavior
   - Validate with real data

4. **Integration Testing**
   - Run both modules on same dataset
   - Verify calculations match (e.g., composite scores)
   - Confirm consistent formatting

---

## Specific Code Locations

### TurasTabs Code to Share:

| File | Lines | Function | Extract To |
|------|-------|----------|------------|
| `modules/tabs/lib/config_loader.R` | 50-70 | Config reading | `shared/config_utils.R` |
| `modules/tabs/lib/significance.R` | * | All sig tests | `shared/significance_tests.R` |
| `modules/tabs/lib/composite_processor.R` | 200-350 | Composite calcs | `shared/composite_calculator.R` |
| `modules/tabs/lib/excel_writer.R` | 50-200 | Style creation | `shared/excel_styles.R` |

### TurasTracker Code to Share:

| File | Lines | Function | Extract To |
|------|-------|----------|------------|
| `tracker_config_loader.R` | 140-165 | parse_settings | `shared/config_utils.R` |
| `tracker_config_loader.R` | 206-214 | get_setting | `shared/config_utils.R` |
| `wave_loader.R` | 112-163 | Weight functions | `shared/weights.R` |
| `wave_loader.R` | 50-98 | Data loading | `shared/data_utils.R` |
| `validation_tracker.R` | 241-247 | merge_validation | `shared/validation_utils.R` |

---

## Implementation Notes

### Backward Compatibility

When extracting code:

1. **Do NOT break TurasTabs** - It's production code
2. **Preserve function signatures** - Keep same parameters
3. **Maintain Roxygen docs** - Transfer to shared functions
4. **Add deprecation warnings** if changing interfaces

### Shared Module Structure

Each shared `.R` file should have:

```r
# ==============================================================================
# TURAS Shared Library - [Module Name]
# ==============================================================================
#
# Shared between: TurasTabs, TurasTracker
#
# [Description]
#
# IMPORTANT: Changes to this file affect multiple modules.
#             Test thoroughly before committing.
#
# ==============================================================================

# All functions with full Roxygen documentation
# @export tags for public functions
# @keywords internal for helper functions
```

### Sourcing Shared Code

In both modules:

```r
# Load shared libraries
shared_dir <- file.path(dirname(sys.frame(1)$ofile), "..", "..", "shared")
source(file.path(shared_dir, "weights.R"))
source(file.path(shared_dir, "significance_tests.R"))
# etc.
```

---

## Success Criteria

Refactoring is successful when:

- ✅ TurasTabs produces identical output (bit-for-bit)
- ✅ TurasTracker uses shared calculations
- ✅ No duplicate calculation logic between modules
- ✅ All shared functions have unit tests
- ✅ Documentation updated to reference shared code
- ✅ Both modules source from `/shared/`

---

## Document Maintenance

**Update this document when:**
- New shared code is identified
- Shared modules are created
- Refactoring is completed
- Function signatures change

**Owner:** Development Team
**Review Frequency:** After each TurasTracker phase completion

---

**Document Version:** 1.0
**Last Updated:** November 2025
**Status:** Planning - Ready for Implementation
