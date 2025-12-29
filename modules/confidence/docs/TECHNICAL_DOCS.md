---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Confidence Module - Technical Documentation

**Version:** 10.1 **Last Updated:** December 2025 **Audience:**
Developers, Technical Maintainers

------------------------------------------------------------------------

## Table of Contents

1.  [Architecture Overview](#architecture-overview)
2.  [Code Structure](#code-structure)
3.  [Data Flow](#data-flow)
4.  [Core Components](#core-components)
5.  [Configuration System](#configuration-system)
6.  [Statistical Implementations](#statistical-implementations)
7.  [Testing Framework](#testing-framework)
8.  [Error Handling](#error-handling)
9.  [Performance Considerations](#performance-considerations)
10. [Extension Points](#extension-points)
11. [Code Style Guidelines](#code-style-guidelines)
12. [Maintenance Procedures](#maintenance-procedures)
13. [Troubleshooting Development
    Issues](#troubleshooting-development-issues)
14. [Version Control](#version-control)
15. [Dependencies](#dependencies)

------------------------------------------------------------------------

## Architecture Overview {#architecture-overview}

### Design Principles

1.  **Orchestrator Pattern:** Main script coordinates focused modules
2.  **Single Responsibility:** Each R file has one clear purpose
3.  **DRY (Don't Repeat Yourself):** Shared logic extracted to reusable modules
4.  **Testability:** Functions are pure and testable in isolation
5.  **Robustness:** Comprehensive validation and error handling
6.  **Performance:** Optimized for typical survey datasets (1K-10K
    respondents)
7.  **Maintainability:** Clear naming, documentation, and structure

### Module Structure

```
modules/confidence/
├── R/                          # Core R code
│   ├── 00_guard.R              # TRS refusal handling
│   ├── 00_main.R               # Main orchestration (orchestrator pattern)
│   ├── 01_load_config.R        # Configuration loading
│   ├── 02_load_data.R          # Data loading
│   ├── 03_study_level.R        # Study-level calculations
│   ├── 04_proportions.R        # Proportion CI methods
│   ├── 05_means.R              # Mean CI methods
│   ├── 07_output.R             # Excel output generation
│   ├── utils.R                 # Utility functions
│   ├── question_processor.R    # Shared question processing logic (NEW)
│   ├── ci_dispatcher.R         # CI calculation dispatch (NEW)
│   └── output_helpers.R        # Output building helpers (NEW)
├── tests/                      # Test suite
│   ├── test_representativeness.R
│   ├── test_nps.R
│   ├── test_weighted_data.R
│   └── test_real_config_ccpb.R
├── docs/                       # Documentation
├── run_confidence_gui.R        # Shiny GUI launcher
└── examples/                   # Example configs and data
```

### Refactored Architecture (v10.1)

The v10.1 refactoring introduced an **orchestrator pattern** where `00_main.R`
coordinates focused modules instead of containing all processing logic:

```
00_main.R (Orchestrator)
    │
    ├── question_processor.R    # Data preparation & base statistics
    │   ├── validate_question_in_data()
    │   ├── get_question_weights()
    │   ├── prepare_question_data()
    │   ├── calculate_proportion_stats()
    │   ├── calculate_mean_stats()
    │   └── calculate_nps_stats()
    │
    ├── ci_dispatcher.R         # CI method dispatch
    │   ├── dispatch_proportion_ci()
    │   ├── dispatch_mean_ci()
    │   └── dispatch_nps_ci()
    │
    └── output_helpers.R        # Result formatting
        ├── build_base_result_row()
        ├── build_proportion_result_row()
        ├── build_mean_result_row()
        └── build_nps_result_row()
```

------------------------------------------------------------------------

## Code Structure {#code-structure}

### File Responsibilities

#### R/utils.R

Utility functions used across the module:

``` r
format_number_for_output()  # Decimal separator formatting
parse_codes()               # Parse comma-separated code lists
calculate_effective_n()     # Kish effective sample size
is_package_available()      # Check package availability
```

**Dependencies:** None (base R only)

------------------------------------------------------------------------

#### R/01_load_config.R

Configuration file loading and validation.

``` r
load_confidence_config(config_path) -> list

# Returns:
list(
  file_paths = data.frame(...),
  study_settings = data.frame(...),
  questions = data.frame(...),
  population_margins = data.frame(...)  # Optional
)
```

**Validation Rules:** - Sheet existence checks - Required column
validation - Value range checks - 200 question limit enforcement

------------------------------------------------------------------------

#### R/02_load_data.R

Data file loading with format detection.

``` r
load_survey_data(data_file_path, verbose) -> data.frame

# Supported formats:
# - CSV (via data.table::fread)
# - XLSX (via readxl::read_excel)
```

**Performance:** Uses `data.table::fread()` for CSV (5-10x faster than
base R).

------------------------------------------------------------------------

#### R/03_study_level.R

Study-level statistics and diagnostics.

``` r
calculate_study_level_stats(data, weights) -> data.frame
compute_weight_concentration(weights) -> data.frame
compute_margin_comparison(data, weights, targets) -> data.frame
```

**Calculations:** - Effective n: `n_eff = (sum(w))^2 / sum(w^2)` - DEFF:
`n_actual / n_eff` - Weight concentration: Top K% share of total weight

------------------------------------------------------------------------

#### R/04_proportions.R

Proportion confidence interval methods.

``` r
calculate_proportion_ci_normal(p, n, conf_level)
calculate_proportion_ci_wilson(p, n, conf_level)
bootstrap_proportion_ci(data, categories, weights, B, conf_level)
credible_interval_proportion(p, n, conf_level, prior_mean, prior_n)
```

------------------------------------------------------------------------

#### R/05_means.R

Mean confidence interval methods.

``` r
calculate_mean_ci_t(values, conf_level)
bootstrap_mean_ci(values, weights, B, conf_level)
credible_interval_mean(mean, sd, n, conf_level, prior_mean, prior_sd, prior_n)
```

------------------------------------------------------------------------

#### R/question_processor.R (NEW in v10.1)

Shared question processing logic extracted from the three `process_*_question()` functions.

``` r
# Question validation
validate_question_in_data(q_id, survey_data) -> list(valid, message)

# Weight handling
get_question_weights(survey_data, weight_var) -> numeric vector or NULL

# Data preparation (aligns values and weights, handles NA)
prepare_question_data(values, weights, require_numeric) -> list

# Base statistics
calculate_proportion_stats(values, categories, weights) -> list
calculate_mean_stats(values, weights) -> list
calculate_nps_stats(values, promoter_codes, detractor_codes, weights) -> list

# Unified processing
process_question_data(q_id, survey_data, weight_var, require_numeric) -> list
```

**Key Pattern:** All question types share ~70% common preprocessing logic,
now centralized here.

------------------------------------------------------------------------

#### R/ci_dispatcher.R (NEW in v10.1)

Unified CI calculation dispatch based on config flags.

``` r
dispatch_proportion_ci(p, n_eff, values, categories, weights, q_row, config)
dispatch_mean_ci(mean_val, sd_val, n_eff, values, weights, q_row, config)
dispatch_nps_ci(nps_stats, values, promoter_codes, detractor_codes, weights, q_row, config)

# Each dispatcher:
# 1. Checks Run_MOE, Run_Bootstrap, Run_Credible flags
# 2. Validates prior parameters if Bayesian enabled
# 3. Calls appropriate CI calculation functions
# 4. Handles errors gracefully with warnings
# 5. Returns results and warnings list
```

**Error Handling:** All CI calculations wrapped in tryCatch to prevent
silent failures.

------------------------------------------------------------------------

#### R/output_helpers.R (NEW in v10.1)

Common output building patterns extracted from 07_output.R.

``` r
build_base_result_row(q_id, base_fields) -> data.frame row
add_ci_fields_to_row(row, ci_result, prefix) -> data.frame row
build_proportion_result_row(q_id, q_result) -> data.frame row
build_mean_result_row(q_id, q_result) -> data.frame row
build_nps_result_row(q_id, q_result) -> data.frame row
combine_result_rows(rows_list) -> data.frame
build_results_dataframe(results, result_type) -> data.frame
```

------------------------------------------------------------------------

#### R/07_output.R

Excel workbook generation.

``` r
write_confidence_output(results, config, output_path)

# Creates workbook with:
# 1. Summary
# 2. Study_Level
# 3. Proportions_Detail
# 4. Means_Detail
# 5. NPS_Detail (if applicable)
# 6. Representativeness_Weights (if applicable)
# 7. Methodology
# 8. Warnings
# 9. Inputs
```

------------------------------------------------------------------------

#### R/00_main.R

Main orchestration script using the **orchestrator pattern**.

``` r
run_confidence_analysis(config_path, verbose = TRUE) -> list

# Execution flow (6 steps):
# 1. Load and validate configuration
# 2. Load survey data
# 3. Calculate study-level statistics
# 4. Process all questions via process_all_questions()
#    └── Delegates to process_proportion/mean/nps_question()
#        └── Uses question_processor.R for data prep
#        └── Uses ci_dispatcher.R for CI calculations
# 5. Collect and handle warnings
# 6. Generate Excel output via 07_output.R
```

**Orchestrator Functions:**

``` r
# Step functions (internal)
load_config_step(config_path)
load_data_step(config, verbose)
calculate_study_stats_step(survey_data, weight_var, config, verbose)
process_all_questions(config, survey_data, weight_var, verbose)
handle_warnings_step(warnings_list, verbose, stop_on_warnings)
generate_output_step(config, study_stats, proportion_results, ...)

# Question processors (delegate to shared modules)
process_proportion_question(q_row, survey_data, weight_var, config)
process_mean_question(q_row, survey_data, weight_var, config)
process_nps_question(q_row, survey_data, weight_var, config)
```

**Version Constant:**

``` r
MAIN_VERSION <- "10.1"
```

------------------------------------------------------------------------

## Data Flow {#data-flow}

```
Config File (Excel)
    ↓
load_confidence_config()         [01_load_config.R]
    ↓
[Validated Config Object]
    ↓
load_survey_data()               [02_load_data.R]
    ↓
[Survey Data Frame]
    ↓
calculate_study_level_stats()    [03_study_level.R]
    ↓
process_all_questions()          [00_main.R]
    │
    ├─→ process_proportion_question()
    │       ├── process_question_data()      [question_processor.R]
    │       ├── calculate_proportion_stats() [question_processor.R]
    │       └── dispatch_proportion_ci()     [ci_dispatcher.R]
    │               ├── calculate_proportion_ci_normal()  [04_proportions.R]
    │               ├── calculate_proportion_ci_wilson()  [04_proportions.R]
    │               ├── bootstrap_proportion_ci()         [04_proportions.R]
    │               └── credible_interval_proportion()    [04_proportions.R]
    │
    ├─→ process_mean_question()
    │       ├── process_question_data()      [question_processor.R]
    │       ├── calculate_mean_stats()       [question_processor.R]
    │       └── dispatch_mean_ci()           [ci_dispatcher.R]
    │               ├── calculate_mean_ci()              [05_means.R]
    │               ├── bootstrap_mean_ci()              [05_means.R]
    │               └── credible_interval_mean()         [05_means.R]
    │
    └─→ process_nps_question()
            ├── process_question_data()      [question_processor.R]
            ├── calculate_nps_stats()        [question_processor.R]
            └── dispatch_nps_ci()            [ci_dispatcher.R]
    ↓
[Results Lists]
    ↓
write_confidence_output()        [07_output.R]
    └── build_*_result_row()     [output_helpers.R]
    ↓
[Excel Workbook]
```

------------------------------------------------------------------------

## Core Components {#core-components}

### Values/Weights Alignment

**Critical Pattern:** Always align values and weights to avoid
mismatched CIs.

``` r
# CORRECT pattern:
valid_value_idx <- !is.na(values) & is.finite(values)

if (!is.null(weights)) {
  good_idx <- valid_value_idx & !is.na(weights) & weights > 0
  values_valid <- values[good_idx]
  weights_valid <- weights[good_idx]
} else {
  values_valid <- values[valid_value_idx]
  weights_valid <- NULL
}
```

### Numeric Conversion

Handles text-formatted numeric columns:

``` r
if (!is.numeric(values)) {
  values_converted <- suppressWarnings(as.numeric(values))
  n_non_missing_before <- sum(!is.na(values) & values != "")
  n_valid_after <- sum(!is.na(values_converted))

  if (n_valid_after >= 10) {
    conversion_rate <- n_valid_after / n_non_missing_before
    if (conversion_rate >= 0.80) {
      values <- values_converted
    }
  }
}
```

### Backward Compatibility

Check for optional columns before accessing:

``` r
use_wilson_flag <- if ("Use_Wilson" %in% names(q_row)) {
  q_row$Use_Wilson
} else {
  NULL
}
```

------------------------------------------------------------------------

## Configuration System {#configuration-system}

### Config Object Structure

``` r
config <- list(
  file_paths = data.frame(
    Parameter = c("Data_File", "Output_Path"),
    Value = c("/path/to/data.csv", "/path/to/output.xlsx")
  ),

  study_settings = data.frame(
    Parameter = c("Confidence_Level", "Bootstrap_Iterations", ...),
    Value = c("0.95", "5000", ...)
  ),

  questions = data.frame(
    Question_ID = c("Q1", "Q2", ...),
    Statistic_Type = c("proportion", "mean", ...),
    Categories = c("1,2", NA, ...),
    Run_MOE = c("Y", "Y", ...),
    ...
  ),

  population_margins = data.frame(...)  # Optional
)
```

### Validation Rules

| Parameter             | Valid Values     | Default |
|-----------------------|------------------|---------|
| Confidence_Level      | 0.90, 0.95, 0.99 | 0.95    |
| Bootstrap_Iterations  | 1000-10000       | 5000    |
| Decimal_Separator     | "." or ","       | "."     |
| Calculate_Effective_N | "Y" or "N"       | "Y"     |

------------------------------------------------------------------------

## Statistical Implementations {#statistical-implementations}

### Effective Sample Size

``` r
calculate_effective_n <- function(weights) {
  if (is.null(weights) || length(weights) == 0) return(length(weights))
  n_eff <- (sum(weights))^2 / sum(weights^2)
  return(n_eff)
}
```

### Bootstrap Resampling

``` r
bootstrap_proportion_ci <- function(data, categories, weights, B, conf_level) {
  n <- length(data)
  boot_props <- numeric(B)

  for (i in 1:B) {
    if (!is.null(weights)) {
      idx <- sample(1:n, size = n, replace = TRUE, prob = weights)
      boot_sample <- data[idx]
      boot_weights <- weights[idx]
      boot_props[i] <- weighted_proportion(boot_sample, categories, boot_weights)
    } else {
      idx <- sample(1:n, size = n, replace = TRUE)
      boot_sample <- data[idx]
      boot_props[i] <- mean(boot_sample %in% categories)
    }
  }

  alpha <- 1 - conf_level
  ci_lower <- quantile(boot_props, alpha/2)
  ci_upper <- quantile(boot_props, 1 - alpha/2)

  return(c(lower = ci_lower, upper = ci_upper))
}
```

### Bayesian (Beta-Binomial)

``` r
# Prior: Beta(α, β)
# Posterior: Beta(α + x, β + n - x)

# Default: Jeffrey's prior (α=0.5, β=0.5)
# Informed: α = prior_mean * prior_n, β = (1 - prior_mean) * prior_n

# Credible interval from posterior quantiles
```

------------------------------------------------------------------------

## Testing Framework {#testing-framework}

### Test Suite Structure

```         
tests/
├── test_representativeness.R  # Quota checking
├── test_nps.R                 # NPS calculations
├── test_weighted_data.R       # Weighted data handling
└── test_real_config_ccpb.R    # Backward compatibility
```

### Running Tests

``` r
# Individual tests
source("modules/confidence/tests/test_representativeness.R")
source("modules/confidence/tests/test_nps.R")
source("modules/confidence/tests/test_weighted_data.R")

# Real config test
source("modules/confidence/tests/test_real_config_ccpb.R")
```

### Writing Tests

``` r
test_that("Description of test", {
  # Setup
  data <- create_test_data()

  # Execute
  result <- function_under_test(data)

  # Assert
  expect_true(result$lower < result$upper)
  expect_true(result$lower >= 0)
  expect_true(result$upper <= 1)
})
```

------------------------------------------------------------------------

## Error Handling {#error-handling}

### Strategy

1.  **Configuration Errors:** Stop with clear message
2.  **Data Loading Errors:** Stop with file path and reason
3.  **Question-Level Errors:** Log warning, continue processing
4.  **Output Errors:** Log warning, attempt to continue

### Error Message Template

``` r
stop(sprintf(
  "Configuration Error: [Specific Issue]\n\n",
  "Location: [Sheet/Parameter]\n",
  "Value: [Problematic Value]\n",
  "Expected: [What was expected]\n\n",
  "Action: [How to fix]\n"
))
```

### Warning Collection

``` r
warnings_list <- character()

if (some_issue) {
  warnings_list <- c(
    warnings_list,
    sprintf("Question %s: [Issue description]", q_id)
  )
}
```

------------------------------------------------------------------------

## Performance Considerations {#performance-considerations}

### Benchmarks

| Task                   | Dataset Size | Time      |
|------------------------|--------------|-----------|
| Config + Data load     | 10K × 50     | \~1 sec   |
| Wilson CI (1 question) | 10K          | \<0.1 sec |
| Bootstrap CI (5K iter) | 1K           | \~1 sec   |
| Bootstrap CI (5K iter) | 10K          | \~10 sec  |
| Full analysis (50Q)    | 1K           | \~30 sec  |

### Optimization Techniques

1.  **Fast CSV Loading:** `data.table::fread()`
2.  **Vectorized Operations:** Avoid loops where possible
3.  **Preallocate Vectors:** `boot_props <- numeric(B)`
4.  **Avoid Unnecessary Computation:** Calculate once, reuse

------------------------------------------------------------------------

## Extension Points {#extension-points}

### Adding New CI Methods

1.  Create function in 04_proportions.R or 05_means.R
2.  Add config column (e.g., `Run_NewMethod`)
3.  Add processing logic in 00_main.R
4.  Update output in 07_output.R
5.  Add tests
6.  Update documentation

### Adding New Question Types

1.  Create processing function
2.  Update dispatcher in 00_main.R
3.  Add output sheet in 07_output.R
4.  Update config validation
5.  Add tests
6.  Update documentation

------------------------------------------------------------------------

## Code Style Guidelines {#code-style-guidelines}

### Naming Conventions

-   **Functions:** `snake_case` (e.g., `calculate_effective_n`)
-   **Variables:** `snake_case` (e.g., `study_level_stats`)
-   **Constants:** `SCREAMING_SNAKE_CASE` (e.g., `MAIN_VERSION`)

### Function Structure

``` r
function_name <- function(param1, param2, param3 = default) {
  # Brief description

  # Input validation
  if (invalid_input) stop("Clear error message")

  # Main logic
  result <- ...

  # Return
  return(result)
}
```

### Comments

``` r
# ========================================================================
# SECTION NAME
# ========================================================================

# -------------------------------------------------------------------------
# Subsection name
# -------------------------------------------------------------------------
```

------------------------------------------------------------------------

## Maintenance Procedures {#maintenance-procedures}

### Before Each Release

-   [ ] Run full test suite
-   [ ] Test with real config files
-   [ ] Update version number in all locations
-   [ ] Update documentation
-   [ ] Test GUI and command line
-   [ ] Verify backward compatibility

### Updating Version Number

Locations to update: 1. `R/00_main.R` → `MAIN_VERSION` 2. `README.md` →
Version badge 3. `docs/` → All documentation files

### Adding New Sheet to Output

1.  Create function in 07_output.R:

``` r
add_mysheet_detail <- function(wb, data, config) {
  sheet_name <- "MySheet"
  openxlsx::addWorksheet(wb, sheet_name)
  openxlsx::writeData(wb, sheet_name, data)
  invisible(wb)
}
```

2.  Call from `write_confidence_output()`:

``` r
wb <- add_mysheet_detail(wb, results$mysheet_data, config)
```

------------------------------------------------------------------------

## Troubleshooting Development Issues {#troubleshooting-development-issues}

### "Function not found"

**Cause:** Sourcing order incorrect **Fix:** Source files in order:
utils → 01 → 02 → ... → 00

### Bootstrap Taking Too Long

**Cause:** Too many iterations or large dataset **Fix:** Reduce B for
testing, or optimize sampling code

### Excel Output Fails

**Cause:** Permission issues or file already open **Fix:** Check
permissions, close Excel

### Tests Failing After Changes

**Cause:** Breaking changes to API **Fix:** Update tests, add regression
tests

------------------------------------------------------------------------

## Version Control {#version-control}

### Branches

-   `main`: Production-ready code
-   `develop`: Integration branch
-   `feature/xxx`: Feature development
-   `bugfix/xxx`: Bug fixes

### Commit Messages

```         
Fix: Description of fix
Feat: Description of new feature
Docs: Documentation update
Test: Test additions/changes
Refactor: Code restructuring
```

### Version Numbering

**Semantic Versioning:** MAJOR.MINOR.PATCH

-   **MAJOR:** Breaking changes
-   **MINOR:** New features (backward compatible)
-   **PATCH:** Bug fixes only

------------------------------------------------------------------------

## Dependencies {#dependencies}

### Required Packages

| Package      | Version | Purpose            |
|--------------|---------|--------------------|
| `readxl`     | ≥1.4.0  | Read Excel config  |
| `openxlsx`   | ≥4.2.5  | Write Excel output |
| `data.table` | ≥1.14.0 | Fast CSV loading   |

### Optional Packages

| Package    | Purpose                                |
|------------|----------------------------------------|
| `dplyr`    | Data manipulation (fallback available) |
| `testthat` | Unit testing                           |

### Checking Dependencies

``` r
check_dependencies <- function() {
  required <- c("readxl", "openxlsx", "data.table")
  missing <- character(0)

  for (pkg in required) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      missing <- c(missing, pkg)
    }
  }

  if (length(missing) > 0) {
    stop(sprintf(
      "Missing required packages: %s",
      paste(missing, collapse = ", ")
    ))
  }

  return(TRUE)
}
```

------------------------------------------------------------------------

## API Reference

### Main Entry Point

``` r
run_confidence_analysis(
  config_path,     # Path to Excel config
  verbose = TRUE   # Print progress
) -> list
```

**Returns:**

``` r
list(
  study_level_stats = data.frame(...),
  proportion_results = list(...),
  mean_results = list(...),
  nps_results = list(...),
  config = list(...),
  warnings = character(...)
)
```

### Key Functions

| Function                           | File                  | Purpose              |
|------------------------------------|-----------------------|----------------------|
| `load_confidence_config()`         | 01_load_config.R      | Load config          |
| `load_survey_data()`               | 02_load_data.R        | Load data            |
| `calculate_study_level_stats()`    | 03_study_level.R      | DEFF, n_eff          |
| `calculate_proportion_ci_normal()` | 04_proportions.R      | MOE                  |
| `calculate_proportion_ci_wilson()` | 04_proportions.R      | Wilson               |
| `bootstrap_proportion_ci()`        | 04_proportions.R      | Bootstrap            |
| `credible_interval_proportion()`   | 04_proportions.R      | Bayesian             |
| `calculate_mean_ci_t()`            | 05_means.R            | t-dist               |
| `bootstrap_mean_ci()`              | 05_means.R            | Bootstrap            |
| `credible_interval_mean()`         | 05_means.R            | Bayesian             |
| `write_confidence_output()`        | 07_output.R           | Excel output         |
| `process_question_data()`          | question_processor.R  | Data preparation     |
| `calculate_proportion_stats()`     | question_processor.R  | Proportion stats     |
| `calculate_mean_stats()`           | question_processor.R  | Mean stats           |
| `calculate_nps_stats()`            | question_processor.R  | NPS stats            |
| `dispatch_proportion_ci()`         | ci_dispatcher.R       | Proportion CI router |
| `dispatch_mean_ci()`               | ci_dispatcher.R       | Mean CI router       |
| `dispatch_nps_ci()`                | ci_dispatcher.R       | NPS CI router        |
| `build_proportion_result_row()`    | output_helpers.R      | Format proportion    |
| `build_mean_result_row()`          | output_helpers.R      | Format mean          |
| `build_nps_result_row()`           | output_helpers.R      | Format NPS           |

------------------------------------------------------------------------

## Future Development

### Phase 3 Possibilities

-   Banner column support
-   Multiple comparison adjustments
-   Subgroup analysis
-   Trend analysis
-   Interactive dashboard
-   API mode
-   Parallel processing

### Enhancements

-   Auto-detect question types
-   Smart prior selection
-   Adaptive bootstrap
-   Result caching
-   Export to other formats

------------------------------------------------------------------------

## Version History

### v10.1 (December 2025) - Refactoring Release

**Architecture Changes:**
-   Adopted orchestrator pattern in 00_main.R
-   Extracted shared logic into focused modules
-   Reduced 00_main.R from 1,396 to ~960 lines (31% reduction)

**New Files:**
-   `question_processor.R` - Shared question processing logic (~466 lines)
-   `ci_dispatcher.R` - Unified CI calculation dispatch (~380 lines)
-   `output_helpers.R` - Common output building patterns (~399 lines)

**Bug Fixes:**
-   Fixed NA handling in Statistic_Type comparisons
-   Added NULL checks before is.na() for config column access
-   Fixed parse_codes() NULL input handling
-   Added tryCatch around CI calculations to prevent silent failures
-   Added Prior_Mean validation for proportion Bayesian CI (must be 0-1)

### v2.0.0 (December 2025)

-   Net Promoter Score (NPS) support
-   Quota representativeness checking
-   Weight concentration diagnostics
-   Improved error handling

### v1.0.0 (November 2025)

-   Initial release

------------------------------------------------------------------------

**End of Technical Documentation**

*Turas Confidence Module v10.1* *Last Updated: December 2025*
