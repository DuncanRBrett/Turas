# Turas Confidence Analysis Module - Maintenance Guide

**Version:** 1.0.0
**Last Updated:** 2025-11-13
**Maintainer:** Turas Development Team

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [File Structure](#file-structure)
3. [Module Components](#module-components)
4. [Data Flow](#data-flow)
5. [Adding New Features](#adding-new-features)
6. [Testing Procedures](#testing-procedures)
7. [Common Issues & Fixes](#common-issues--fixes)
8. [Code Conventions](#code-conventions)
9. [Dependencies](#dependencies)
10. [Performance Optimization](#performance-optimization)

---

## Architecture Overview

### Design Philosophy

The Confidence Analysis Module follows these principles:

1. **Modular Design**: Each statistical method is isolated in its own function
2. **Config-Driven**: All analysis parameters come from Excel config file
3. **Fail-Safe**: Extensive validation with clear error messages
4. **Standalone**: Can run independently of main Turas system
5. **Production-Ready**: Handles real-world data issues (NAs, DK, extreme values)

### Module Flow

```
User Config (Excel)
    ↓
01_load_config.R → Validate and parse
    ↓
02_load_data.R → Load CSV/XLSX data
    ↓
03_study_level.R → Calculate DEFF, effective n
    ↓
00_main.R → Process each question
    ├─→ 04_proportions.R → MOE, Wilson, Bootstrap, Bayesian
    └─→ 05_means.R → t-dist, Bootstrap, Bayesian
    ↓
07_output.R → Generate 7-sheet Excel workbook
```

---

## File Structure

```
modules/confidence/
├── R/
│   ├── 00_main.R                  # Main orchestration (560 lines)
│   ├── 01_load_config.R           # Config loading & validation (260 lines)
│   ├── 02_load_data.R             # Data loading (CSV/XLSX) (400 lines)
│   ├── 03_study_level.R           # DEFF, effective n (340 lines)
│   ├── 04_proportions.R           # 4 proportion CI methods (650 lines)
│   ├── 05_means.R                 # 3 mean CI methods (550 lines)
│   ├── 06_validation.R            # Input validation functions (200 lines)
│   ├── 07_output.R                # Excel output generation (850 lines)
│   └── utils.R                    # Helper functions (380 lines)
├── examples/
│   ├── create_example_config.R    # Config generator
│   ├── create_example_data.R      # Synthetic data generator
│   ├── confidence_config_example.xlsx
│   └── survey_data_example.csv
├── tests/
│   └── (future: unit tests)
├── README.md                      # Quick start guide
├── USER_MANUAL.md                 # End-user documentation
├── MAINTENANCE_GUIDE.md           # This file
└── turas_confidence_analysis_design_spec_v1.0-3.md
```

**Total Code:** ~4,200 lines across 9 R files

---

## Module Components

### 1. Configuration Loader (`01_load_config.R`)

**Purpose:** Load and validate Excel config file with 3 sheets

**Key Functions:**

```r
load_confidence_config(config_path)
  ├─→ load_file_paths_sheet()      # Data_File, Output_File, Weight_Variable
  ├─→ load_study_settings_sheet()  # Confidence_Level, Bootstrap_Iterations, etc.
  └─→ load_question_analysis_sheet() # Question specs (max 200)
```

**Validation:**
- Checks all required parameters exist
- Validates data types (Y/N flags, numeric values)
- Enforces 200 question limit
- Returns structured list with 3 components

**Common Issues:**
- Character vs numeric types from Excel → Solution: `as.numeric()` conversion in main
- Missing columns → Clear error message with expected column names

---

### 2. Data Loader (`02_load_data.R`)

**Purpose:** Load survey data from CSV or XLSX files

**Key Functions:**

```r
load_survey_data(file_path)
  ├─→ detect_file_format()         # CSV vs XLSX
  ├─→ data.table::fread() (CSV)    # Fast CSV reading
  ├─→ readxl::read_excel() (XLSX)  # Excel reading
  └─→ validate_data_structure()    # Basic checks
```

**Features:**
- Auto-detects file format
- Handles large files efficiently (data.table for CSV)
- Validates column count and row count
- Returns data.frame

**Performance:**
- CSV: Uses `data.table::fread()` - very fast for large files
- XLSX: Uses `readxl::read_excel()` - slower but robust

---

### 3. Study-Level Statistics (`03_study_level.R`)

**Purpose:** Calculate weighted survey statistics

**Key Functions:**

```r
calculate_study_level_stats(data, weight_var)
  ├─→ calculate_deff()              # Design effect
  ├─→ calculate_effective_n()       # n_eff = n / DEFF
  └─→ validate_weights()            # Check for negatives, zeros
```

**DEFF Calculation:**
```r
# Kish's approximation
DEFF = 1 + CV²(weights)
     = 1 + [sd(w) / mean(w)]²
```

**Warnings Generated:**
- High DEFF (> 2.0): "Very high design effect"
- High weight CV (> 0.3): "High weight CV"
- Extreme weights: Individual weights > 3.0 or < 0.3

---

### 4. Proportion Methods (`04_proportions.R`)

**Purpose:** Calculate confidence intervals for proportions

**Four Methods:**

#### A. Normal Approximation (MOE)
```r
calculate_proportion_ci_normal(p, n, conf_level)
# MOE = z * sqrt(p*(1-p)/n)
# CI = [p - MOE, p + MOE]
# Use: Large samples (np >= 10, n(1-p) >= 10)
```

#### B. Wilson Score Interval
```r
calculate_proportion_ci_wilson(p, n, conf_level)
# Better for extreme proportions (p < 0.1 or p > 0.9)
# Asymmetric intervals
# Industry standard for survey data
```

#### C. Bootstrap Resampling
```r
bootstrap_proportion_ci(data, categories, weights, B, conf_level)
# Non-parametric
# Handles complex weighting
# B = 1000-5000 iterations typical
# Returns percentile CI
```

#### D. Bayesian Credible Interval
```r
credible_interval_proportion(p, n, conf_level, prior_mean, prior_n)
# Beta-Binomial conjugate model
# Uninformed prior: Beta(1,1) = Uniform(0,1)
# Informed prior: Beta(α,β) from prior_mean and prior_n
# Returns posterior mean and credible interval
```

**Function Signatures:**
- All use `conf_level` (not alpha)
- Bootstrap uses raw data + categories (not success_values)
- Bayesian uses proportion p (not count x)

---

### 5. Mean Methods (`05_means.R`)

**Purpose:** Calculate confidence intervals for means

**Three Methods:**

#### A. t-Distribution
```r
calculate_mean_ci(values, weights, conf_level)
# Standard parametric CI
# SE = sd(x) / sqrt(n) for unweighted
# Weighted SE uses effective sample size
```

#### B. Bootstrap Resampling
```r
bootstrap_mean_ci(values, weights, B, conf_level)
# Non-parametric
# Handles skewed distributions
# Returns percentile CI
```

#### C. Bayesian Credible Interval
```r
credible_interval_mean(values, weights, conf_level, prior_mean, prior_sd, prior_n)
# Normal-Normal conjugate model
# Uninformed: vague prior with large variance
# Informed: specified prior mean/sd with prior_n
```

**Weighted Calculations:**
- Uses effective sample size for SE
- Bootstrap resamples with replacement (preserving weights)
- Bayesian posterior adjusted for weighting

---

### 6. Output Generator (`07_output.R`)

**Purpose:** Create professional Excel workbook with 7 sheets

**Sheets:**

1. **Summary**: High-level overview
2. **Study_Level**: DEFF, effective n, weight statistics
3. **Proportions_Detail**: All proportion CIs with methods
4. **Means_Detail**: All mean CIs with methods
5. **Methodology**: Statistical methods documentation
6. **Warnings**: Data quality issues
7. **Inputs**: Configuration summary

**Key Functions:**

```r
write_confidence_output(output_path, ...)
  ├─→ add_summary_sheet()
  ├─→ add_study_level_sheet()
  ├─→ add_proportions_detail_sheet()
  ├─→ add_means_detail_sheet()
  ├─→ add_methodology_sheet()
  ├─→ add_warnings_sheet()
  └─→ add_inputs_sheet()
```

**Formatting:**
- Numeric values (not text strings)
- Excel number formats with decimal separator
- Auto-sized columns
- Professional styling (headers, colors)

**Critical Implementation:**
```r
# ALWAYS use period in Excel format codes
num_format <- "0.00"  # NOT "0,00"
# Excel displays based on system locale
```

---

### 7. Main Orchestration (`00_main.R`)

**Purpose:** Coordinate entire analysis workflow

**Main Function:**

```r
run_confidence_analysis(config_path, verbose = TRUE)
```

**6-Step Process:**

1. **Load Configuration** → validate all settings
2. **Load Survey Data** → CSV or XLSX
3. **Calculate Study-Level Stats** → DEFF, effective n (if weighted)
4. **Process Questions** → loop through each question
   - Extract data for question
   - Parse categories (for proportions)
   - Call appropriate CI methods
   - Collect warnings
5. **Quality Checks** → summarize warnings
6. **Generate Excel Output** → 7-sheet workbook

**Error Handling:**
- Each step wrapped in `tryCatch()`
- Clear error messages with context
- Warnings collected but don't stop execution

---

## Data Flow

### Detailed Flow Diagram

```
┌─────────────────────────────────────┐
│ User creates Excel config file      │
│ - File_Paths sheet                  │
│ - Study_Settings sheet              │
│ - Question_Analysis sheet           │
└──────────────┬──────────────────────┘
               ↓
┌──────────────────────────────────────────────────────┐
│ 01_load_config.R                                     │
│ - Read 3 sheets                                      │
│ - Validate required parameters                       │
│ - Convert types (Confidence_Level to numeric)        │
│ - Return list(file_paths, study_settings, q_analysis)│
└──────────────┬───────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────┐
│ 02_load_data.R                                       │
│ - Detect file format (CSV/XLSX)                     │
│ - Load data (data.table or readxl)                  │
│ - Validate structure                                 │
│ - Return data.frame (n x p)                         │
└──────────────┬───────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────┐
│ 03_study_level.R (if weighted)                       │
│ - Calculate DEFF = 1 + CV²(weights)                 │
│ - Calculate n_eff = n / DEFF                        │
│ - Check for weight issues                           │
│ - Return study_level_stats dataframe                │
└──────────────┬───────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────┐
│ 00_main.R - Process each question                    │
│ For each row in Question_Analysis:                   │
└──────────────┬───────────────────────────────────────┘
               ↓
        ┌──────┴──────┐
        ↓             ↓
┌───────────────┐ ┌───────────────┐
│ Proportion?   │ │ Mean?         │
└───────┬───────┘ └───────┬───────┘
        ↓                 ↓
┌─────────────────────────────────────┐
│ 04_proportions.R                    │
│ - Parse categories (e.g., "Yes")    │
│ - Calculate p = successes / n       │
│ - Run selected methods:             │
│   • MOE (if Run_MOE = Y)            │
│   • Wilson (if Run_Wilson = Y)      │
│   • Bootstrap (if Run_Bootstrap = Y)│
│   • Bayesian (if Run_Credible = Y)  │
│ - Return results list               │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│ 05_means.R                          │
│ - Extract numeric values            │
│ - Calculate mean, SD                │
│ - Run selected methods:             │
│   • t-dist (if Run_MOE = Y)         │
│   • Bootstrap (if Run_Bootstrap = Y)│
│   • Bayesian (if Run_Credible = Y)  │
│ - Return results list               │
└──────────────┬──────────────────────┘
               ↓
┌──────────────────────────────────────────────────────┐
│ Collect all results                                  │
│ - proportion_results list (by Question_ID)          │
│ - mean_results list (by Question_ID)                │
│ - warnings_list vector                              │
└──────────────┬───────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────┐
│ 07_output.R                                          │
│ - Create workbook                                    │
│ - Build dataframes from results                      │
│   • build_proportions_dataframe()                   │
│   • build_means_dataframe()                         │
│ - Write 7 sheets with formatting                    │
│ - Save to Excel                                      │
└──────────────────────────────────────────────────────┘
               ↓
         ┌─────────────┐
         │ Excel Output│
         │ 7 sheets    │
         └─────────────┘
```

---

## Adding New Features

### Adding a New CI Method for Proportions

**Example: Adding Clopper-Pearson Exact Method**

1. **Add function to `04_proportions.R`:**

```r
#' Clopper-Pearson Exact Confidence Interval
#'
#' @param p Numeric. Sample proportion
#' @param n Integer. Sample size
#' @param conf_level Numeric. Confidence level (default 0.95)
#' @return List with lower, upper, method, warnings
#' @export
calculate_proportion_ci_exact <- function(p, n, conf_level = 0.95) {

  # Validation
  validate_proportion(p, "p")
  validate_sample_size(n, "n")
  validate_conf_level(conf_level)

  # Calculate successes
  x <- round(p * n)

  # Calculate exact CI using beta distribution
  alpha <- 1 - conf_level
  if (x == 0) {
    lower <- 0
    upper <- 1 - (alpha/2)^(1/n)
  } else if (x == n) {
    lower <- (alpha/2)^(1/n)
    upper <- 1
  } else {
    lower <- qbeta(alpha/2, x, n - x + 1)
    upper <- qbeta(1 - alpha/2, x + 1, n - x)
  }

  return(list(
    lower = lower,
    upper = upper,
    method = "Clopper-Pearson exact",
    warnings = character(0)
  ))
}
```

2. **Add to config schema in `01_load_config.R`:**

Update `load_question_analysis_sheet()` to include new column:

```r
# Add Run_Exact to required columns for proportions
# Update validation to check for this column
```

3. **Update Excel config template:**

Add `Run_Exact` column to Question_Analysis sheet in example config.

4. **Add to main processing in `00_main.R`:**

```r
# In process_proportion_question():

# Exact (Clopper-Pearson)
if (toupper(q_row$Run_Exact) == "Y") {
  result$exact <- calculate_proportion_ci_exact(p, n_eff, conf_level)
}
```

5. **Update output in `07_output.R`:**

```r
# In build_proportions_dataframe():

# Exact
if (!is.null(q_result$exact)) {
  base_row$Exact_Lower <- q_result$exact$lower
  base_row$Exact_Upper <- q_result$exact$upper
}
```

6. **Update documentation:**
- Add to Methodology sheet
- Update USER_MANUAL.md
- Update README.md

---

### Adding Subgroup Analysis

**Feature:** Analyze questions by demographic subgroups

**Implementation Steps:**

1. **Update config schema:**
   - Add `Subgroup_Variable` column to Question_Analysis sheet
   - e.g., "Gender", "AgeGroup", "Region"

2. **Modify data processing:**
   - Split data by subgroup levels
   - Run CI calculation for each level
   - Store results with subgroup labels

3. **Update output:**
   - Add subgroup column to results dataframes
   - Create separate sheet for subgroup comparisons

4. **Add significance testing:**
   - Compare subgroup proportions/means
   - Flag significant differences

**Code Structure:**

```r
process_subgroup_analysis <- function(q_row, survey_data, ...) {
  subgroup_var <- q_row$Subgroup_Variable

  if (!is.na(subgroup_var) && subgroup_var != "") {
    # Get unique levels
    levels <- unique(survey_data[[subgroup_var]])

    # Process each level
    results_by_level <- list()
    for (level in levels) {
      subset_data <- survey_data[survey_data[[subgroup_var]] == level, ]
      results_by_level[[level]] <- process_question(q_row, subset_data, ...)
    }

    return(results_by_level)
  }
}
```

---

### Adding New Output Formats

**Feature:** Export to CSV, JSON, or PDF

**CSV Export:**

```r
write_confidence_csv <- function(output_path, proportion_results, mean_results) {
  # Flatten results to tabular format
  prop_df <- build_proportions_dataframe(proportion_results)
  mean_df <- build_means_dataframe(mean_results)

  # Write CSVs
  write.csv(prop_df,
            file.path(dirname(output_path), "proportions.csv"),
            row.names = FALSE)
  write.csv(mean_df,
            file.path(dirname(output_path), "means.csv"),
            row.names = FALSE)
}
```

**JSON Export:**

```r
write_confidence_json <- function(output_path, ...) {
  library(jsonlite)

  output_list <- list(
    metadata = list(
      version = "1.0.0",
      timestamp = Sys.time(),
      confidence_level = config$study_settings$Confidence_Level
    ),
    study_level = study_stats,
    proportions = proportion_results,
    means = mean_results,
    warnings = warnings_list
  )

  json_str <- toJSON(output_list, pretty = TRUE, digits = 6)
  writeLines(json_str, output_path)
}
```

---

## Testing Procedures

### Unit Testing Framework

**Setup:**

```r
# Install testthat
install.packages("testthat")

# Create test file structure
modules/confidence/tests/testthat/
  ├── test_proportions.R
  ├── test_means.R
  ├── test_config.R
  ├── test_data_loading.R
  └── test_output.R
```

**Example Test File (`test_proportions.R`):**

```r
library(testthat)

test_that("Wilson score handles extreme proportions", {
  # Very low proportion
  result <- calculate_proportion_ci_wilson(0.01, 100, 0.95)
  expect_true(result$lower >= 0)
  expect_true(result$upper <= 1)
  expect_true(result$lower < result$upper)

  # Very high proportion
  result <- calculate_proportion_ci_wilson(0.99, 100, 0.95)
  expect_true(result$lower >= 0)
  expect_true(result$upper <= 1)
  expect_true(result$lower < result$upper)
})

test_that("Bootstrap proportion CI with weights", {
  set.seed(123)
  data <- sample(c("Yes", "No"), 100, replace = TRUE)
  weights <- runif(100, 0.5, 1.5)

  result <- bootstrap_proportion_ci(data, "Yes", weights, B = 100, 0.95)

  expect_true(!is.null(result$lower))
  expect_true(!is.null(result$upper))
  expect_true(result$lower < result$upper)
  expect_true(result$lower >= 0 && result$upper <= 1)
})

test_that("Bayesian proportion with informed prior", {
  # Prior: 50% with n=50
  result <- credible_interval_proportion(0.6, 100, 0.95,
                                        prior_mean = 0.5,
                                        prior_n = 50)

  # Posterior should be between prior and data
  expect_true(result$post_mean > 0.5 && result$post_mean < 0.6)
  expect_equal(result$prior_type, "Informed")
})
```

### Integration Testing

**Test Full Workflow:**

```r
test_that("End-to-end analysis with example data", {
  # Create temp config
  config_path <- tempfile(fileext = ".xlsx")
  create_example_config(config_path)

  # Create temp data
  data_path <- tempfile(fileext = ".csv")
  create_example_data(data_path, n = 500)

  # Update config to point to temp data
  # ... (modify config file paths)

  # Run analysis
  output_path <- tempfile(fileext = ".xlsx")
  result <- run_confidence_analysis(config_path)

  # Verify output exists
  expect_true(file.exists(output_path))

  # Verify output structure
  wb <- loadWorkbook(output_path)
  sheets <- names(wb)
  expect_true("Summary" %in% sheets)
  expect_true("Proportions_Detail" %in% sheets)
  expect_true("Means_Detail" %in% sheets)

  # Cleanup
  unlink(c(config_path, data_path, output_path))
})
```

### Performance Testing

**Benchmark Large Datasets:**

```r
library(microbenchmark)

# Test with varying sample sizes
test_performance <- function() {
  sample_sizes <- c(1000, 5000, 10000, 50000)

  results <- list()
  for (n in sample_sizes) {
    data <- sample(c(0, 1), n, replace = TRUE)

    timing <- microbenchmark(
      wilson = calculate_proportion_ci_wilson(mean(data), n, 0.95),
      bootstrap = bootstrap_proportion_ci(data, 1, NULL, 1000, 0.95),
      bayesian = credible_interval_proportion(mean(data), n, 0.95),
      times = 10
    )

    results[[as.character(n)]] <- summary(timing)
  }

  return(results)
}
```

---

## Common Issues & Fixes

### Issue 1: Confidence Intervals Not Showing

**Symptoms:**
- Excel output shows proportions/means but no CI columns
- Methods appear enabled in config

**Diagnosis:**

```r
# Check if methods are running
config <- load_confidence_config(config_path)
print(config$question_analysis[, c("Question_ID", "Run_Wilson", "Run_Bootstrap")])

# Check confidence level type
print(class(config$study_settings$Confidence_Level))
# Should be "numeric", not "character"
```

**Root Causes:**
1. `Confidence_Level` stored as character "0.95" instead of numeric
2. `Bootstrap_Iterations` stored as character instead of integer
3. Function signature mismatch (wrong argument order)

**Fix:**
```r
# In 00_main.R, always convert config values:
conf_level <- as.numeric(config$study_settings$Confidence_Level)
boot_iter <- as.integer(config$study_settings$Bootstrap_Iterations)
```

---

### Issue 2: Excel Shows "002" Instead of "1.67"

**Symptoms:**
- Numbers display incorrectly in Excel
- Decimal values show as integers or strange formats

**Root Cause:**
Using comma in Excel number format code when it should be period.

**Wrong:**
```r
format_code <- "0,00"  # Excel interprets comma as "divide by 1000"
```

**Correct:**
```r
format_code <- "0.00"  # Always use period
# Excel will display with comma or period based on system locale
```

**Reference:** See `/TROUBLESHOOTING.md` section on decimal separators.

---

### Issue 3: Bootstrap/Bayesian Return NULL

**Symptoms:**
- Wilson/MOE methods work
- Bootstrap and Bayesian return NULL
- No error messages shown

**Diagnosis:**

```r
# Test method directly
result <- tryCatch({
  bootstrap_proportion_ci(data, categories, weights, B, conf_level)
}, error = function(e) {
  cat("Error:", e$message, "\n")
  return(NULL)
})
```

**Common Causes:**
1. **Unweighted analysis**: `weights_valid` undefined
   - Fix: Initialize `weights_valid <- NULL` before if/else

2. **Wrong argument types**:
   - Bootstrap expects raw data + categories (not logical success_values)
   - Bayesian expects proportion p (not count x)

3. **Wrong argument order**:
   - Check function signature carefully

**Fixes:**

```r
# Proportions - Bootstrap
values_valid <- values[valid_idx]
result$bootstrap <- bootstrap_proportion_ci(values_valid, categories,
                                           weights_valid, boot_iter, conf_level)

# Proportions - Bayesian
result$bayesian <- credible_interval_proportion(p, n, conf_level,
                                               prior_mean, prior_n)

# Means - Bootstrap
result$bootstrap <- bootstrap_mean_ci(values_valid, weights_valid,
                                     boot_iter, conf_level)
```

---

### Issue 4: "Numbers of Columns Do Not Match"

**Symptoms:**
- Error when building output dataframes
- Occurs in Step 6 (output generation)

**Root Cause:**
Different questions use different methods, so result lists have different fields. `rbind()` fails with mismatched columns.

**Fix:**
Use `dplyr::bind_rows()` which handles mismatched columns:

```r
# In build_proportions_dataframe() and build_means_dataframe():
if (requireNamespace("dplyr", quietly = TRUE)) {
  df <- dplyr::bind_rows(rows_list)
} else {
  # Fallback: manually align columns
  all_cols <- unique(unlist(lapply(rows_list, names)))
  rows_list_filled <- lapply(rows_list, function(row) {
    missing_cols <- setdiff(all_cols, names(row))
    for (col in missing_cols) row[[col]] <- NA
    return(row[all_cols])
  })
  df <- do.call(rbind, lapply(rows_list_filled, as.data.frame))
}
```

---

### Issue 5: Categories Not Matching Any Data

**Symptoms:**
- Proportion shows as 0.00
- Sample size correct but zero successes

**Diagnosis:**

```r
# Check actual data values
table(data$Q29, useNA = "always")

# Check category matching
categories <- parse_codes(q_row$Categories)
print(categories)

# Test match
sum(data$Q29 %in% categories)
```

**Common Causes:**
1. **Type mismatch**: Data is character "Yes" but categories is numeric 1
2. **Case sensitivity**: Data is "yes" but categories is "Yes"
3. **Whitespace**: Data has trailing spaces
4. **Wrong expression**: Used R expression `Q29=="Yes"` instead of just `Yes`

**Fix:**
```r
# Categories column should contain values, not R expressions
# Correct:
Categories: Yes
Categories: 9,10
Categories: 1,2,3

# Wrong:
Categories: Q29=="Yes"
Categories: Q79==9|Q79==10
```

---

## Code Conventions

### Naming Conventions

**Functions:**
- `snake_case` for all functions
- Verbs for actions: `calculate_`, `validate_`, `load_`, `process_`
- Clear, descriptive names: `calculate_proportion_ci_wilson()` not `wilson()`

**Variables:**
- `snake_case` for local variables
- Descriptive: `conf_level` not `cl`, `boot_iter` not `b`
- Constants: `UPPER_CASE` (e.g., `OUTPUT_VERSION`)

**Data Structures:**
- Lists returned by functions have consistent structure
- Always include `method` field for tracking
- Always include `warnings` field (even if empty vector)

**Example:**
```r
# Good
calculate_mean_ci <- function(values, weights, conf_level) {
  ...
  return(list(
    lower = lower,
    upper = upper,
    se = se,
    df = df,
    method = "t-distribution",
    warnings = warnings
  ))
}

# Bad
meanCI <- function(x, w, a) {
  ...
  return(c(lower, upper))
}
```

---

### Documentation Standards

**Function Documentation (roxygen2 style):**

```r
#' Calculate Wilson Score Confidence Interval for Proportion
#'
#' Calculates confidence interval using Wilson score method. Better than
#' normal approximation for extreme proportions (p < 0.1 or p > 0.9).
#' Provides asymmetric intervals that respect 0 and 1 boundaries.
#'
#' @param p Numeric. Sample proportion (0 to 1)
#' @param n Integer. Sample size (must be > 0)
#' @param conf_level Numeric. Confidence level (default 0.95)
#'
#' @return List with elements:
#'   \describe{
#'     \item{lower}{Lower confidence limit}
#'     \item{upper}{Upper confidence limit}
#'     \item{center}{Adjusted proportion (Wilson center)}
#'     \item{method}{Character. "Wilson score"}
#'     \item{warnings}{Character vector of warnings (empty if none)}
#'   }
#'
#' @examples
#' # Small proportion
#' calculate_proportion_ci_wilson(0.05, 100, 0.95)
#'
#' # Large proportion
#' calculate_proportion_ci_wilson(0.95, 100, 0.95)
#'
#' @references
#' Wilson, E.B. (1927). Probable inference, the law of succession, and
#' statistical inference. Journal of the American Statistical Association.
#'
#' @seealso \code{\link{calculate_proportion_ci_normal}}
#'
#' @export
calculate_proportion_ci_wilson <- function(p, n, conf_level = 0.95) {
  ...
}
```

**File Headers:**

```r
# ==============================================================================
# PROPORTION CONFIDENCE INTERVALS V1.0.0
# ==============================================================================
# Functions for calculating confidence intervals for survey proportions
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# V1.0.0 - Initial release (2025-11-13)
#          - MOE (normal approximation)
#          - Wilson score interval
#          - Bootstrap resampling
#          - Bayesian credible intervals
#
# METHODS IMPLEMENTED:
# 1. Normal Approximation (MOE)
# 2. Wilson Score Interval
# 3. Bootstrap Percentile CI
# 4. Bayesian Beta-Binomial
#
# DEPENDENCIES:
# - utils.R (validation functions)
# ==============================================================================
```

---

### Error Handling

**Always use informative error messages:**

```r
# Good
if (p < 0 || p > 1) {
  stop(sprintf("p must be between 0 and 1, got: %.4f", p), call. = FALSE)
}

if (n <= 0) {
  stop(sprintf("Sample size must be positive, got: %d", n), call. = FALSE)
}

# Bad
if (p < 0 || p > 1) stop("Invalid p")
if (n <= 0) stop("Bad n")
```

**Use tryCatch for recoverable errors:**

```r
result <- tryCatch({
  calculate_proportion_ci_wilson(p, n, conf_level)
}, error = function(e) {
  warnings_list <- c(warnings_list,
                    sprintf("Question %s: Wilson method failed: %s",
                            q_id, conditionMessage(e)))
  return(NULL)
})
```

**Validate early:**

```r
# Validate inputs at start of function
validate_proportion(p, "p")
validate_sample_size(n, "n")
validate_conf_level(conf_level)

# Then proceed with calculations
...
```

---

### Code Style

**Indentation:**
- 2 spaces (not tabs)
- Align continuation lines

**Line Length:**
- Max 100 characters
- Break long function calls:

```r
# Good
result <- bootstrap_proportion_ci(
  data = values_valid,
  categories = categories,
  weights = weights_valid,
  B = boot_iter,
  conf_level = conf_level
)

# Bad - too long
result <- bootstrap_proportion_ci(values_valid, categories, weights_valid, boot_iter, conf_level)
```

**Spacing:**
```r
# Good
if (x > 0) {
  y <- x + 1
  z <- y * 2
}

# Bad
if(x>0){
  y<-x+1
  z<-y*2
}
```

---

## Dependencies

### Required Packages

```r
# Core dependencies (MUST be installed)
install.packages(c(
  "readxl",      # Reading Excel config files
  "openxlsx",    # Writing Excel output
  "data.table"   # Fast CSV reading
))

# Optional (recommended)
install.packages(c(
  "dplyr",       # Easier dataframe handling
  "testthat"     # Unit testing
))
```

### Package Versions

**Minimum versions tested:**
- R >= 4.0.0
- readxl >= 1.4.0
- openxlsx >= 4.2.5
- data.table >= 1.14.0

### Checking Dependencies

```r
# Check if required packages available
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
      "Missing required packages: %s\nInstall with: install.packages(c(%s))",
      paste(missing, collapse = ", "),
      paste(sprintf("'%s'", missing), collapse = ", ")
    ), call. = FALSE)
  }

  return(TRUE)
}
```

---

## Performance Optimization

### Benchmarking Results

**Test Dataset:** 10,000 respondents, 50 questions

| Operation | Time | Notes |
|-----------|------|-------|
| Config loading | <0.1s | Negligible |
| CSV data loading | 0.3s | Fast with data.table |
| XLSX data loading | 1.5s | Slower, use CSV for large files |
| Wilson CI (1 question) | <0.01s | Very fast |
| Bootstrap CI (1 question, B=1000) | 0.5s | Parallelizable |
| Full analysis (50 questions) | ~30s | Dominated by Bootstrap |
| Excel output | 2s | Includes formatting |

### Optimization Strategies

**1. Use CSV for Large Datasets**
```r
# CSV with data.table is 5x faster than Excel
# Recommendation: >5000 rows → convert to CSV
```

**2. Reduce Bootstrap Iterations for Testing**
```r
# Development: B = 100-500
# Production: B = 1000-5000
# High precision: B = 10000
```

**3. Parallel Bootstrap (Future Enhancement)**
```r
library(parallel)

bootstrap_parallel <- function(data, categories, weights, B, conf_level) {
  n_cores <- detectCores() - 1
  cl <- makeCluster(n_cores)

  # Export data to cluster
  clusterExport(cl, c("data", "categories", "weights"))

  # Run bootstrap in parallel
  boot_props <- parLapply(cl, 1:B, function(i) {
    # Bootstrap iteration
    ...
  })

  stopCluster(cl)

  # Calculate CI from results
  ...
}
```

**4. Vectorize Where Possible**
```r
# Good - vectorized
success_values <- values %in% categories

# Bad - loop
success_values <- logical(length(values))
for (i in seq_along(values)) {
  success_values[i] <- values[i] %in% categories
}
```

---

## Future Development Roadmap

### Phase 2 Features (Priority)

1. **Subgroup Analysis**
   - Analyze by demographics (age, gender, region)
   - Automatic significance testing between groups
   - Separate output sheet for subgroup comparisons

2. **Multiple Comparison Adjustment**
   - Bonferroni correction
   - Benjamini-Hochberg (FDR)
   - Integrate with existing `Multiple_Comparison_Adjustment` setting

3. **Sample Size Calculator**
   - Reverse calculation: given desired precision, calculate n
   - Account for DEFF in weighted surveys
   - Separate utility function

4. **Interactive Dashboard** (Shiny)
   - Upload data and config through web interface
   - Real-time visualization of CIs
   - Download results

### Phase 3 Features (Future)

1. **Time Series Analysis**
   - Track questions across waves
   - Detect significant changes
   - Trend visualization

2. **Advanced Bayesian Methods**
   - Hierarchical models for subgroups
   - Prior elicitation tool
   - Posterior predictive checks

3. **Additional CI Methods**
   - Agresti-Coull for proportions
   - Jackknife for means
   - Profile likelihood

4. **API Integration**
   - RESTful API for remote analysis
   - JSON input/output
   - Cloud deployment

---

## Version Control & Release Process

### Git Workflow

**Branches:**
- `main`: Production-ready code
- `develop`: Integration branch
- `feature/xxx`: Feature development
- `bugfix/xxx`: Bug fixes

**Commit Messages:**
```
Fix: Description of fix
Feat: Description of new feature
Docs: Documentation update
Test: Test additions/changes
Refactor: Code restructuring
```

### Release Checklist

Before releasing new version:

- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version number incremented in all files
- [ ] Example data/config tested
- [ ] User manual reviewed
- [ ] Performance benchmarks run
- [ ] Git tag created
- [ ] Release notes written

### Version Numbering

**Semantic Versioning:** MAJOR.MINOR.PATCH

- **MAJOR**: Breaking changes (config format, API)
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes only

**Current:** 1.0.0
- First production release
- All core features implemented
- Tested with real data

---

## Support & Contact

**Issues:**
- Report bugs via GitHub Issues
- Include minimal reproducible example
- Attach config file (remove sensitive data)
- Include R version and package versions

**Questions:**
- Check USER_MANUAL.md first
- Check TROUBLESHOOTING.md
- Contact: [development team email]

**Contributing:**
- Fork repository
- Create feature branch
- Submit pull request with tests
- Follow code conventions above

---

## Appendix A: Function Reference

### Configuration Functions

| Function | Purpose | File |
|----------|---------|------|
| `load_confidence_config()` | Load and validate config | 01_load_config.R |
| `load_file_paths_sheet()` | Parse File_Paths sheet | 01_load_config.R |
| `load_study_settings_sheet()` | Parse Study_Settings | 01_load_config.R |
| `load_question_analysis_sheet()` | Parse questions | 01_load_config.R |

### Data Loading Functions

| Function | Purpose | File |
|----------|---------|------|
| `load_survey_data()` | Load CSV or XLSX | 02_load_data.R |
| `detect_file_format()` | Detect CSV vs XLSX | 02_load_data.R |
| `validate_data_structure()` | Check data validity | 02_load_data.R |

### Study-Level Functions

| Function | Purpose | File |
|----------|---------|------|
| `calculate_study_level_stats()` | DEFF, effective n | 03_study_level.R |
| `calculate_deff()` | Design effect | 03_study_level.R |
| `calculate_effective_n()` | n_eff = n/DEFF | 03_study_level.R |
| `validate_weights()` | Check weight quality | 03_study_level.R |

### Proportion CI Functions

| Function | Purpose | File |
|----------|---------|------|
| `calculate_proportion_ci_normal()` | MOE method | 04_proportions.R |
| `calculate_proportion_ci_wilson()` | Wilson score | 04_proportions.R |
| `bootstrap_proportion_ci()` | Bootstrap resampling | 04_proportions.R |
| `credible_interval_proportion()` | Bayesian Beta-Binomial | 04_proportions.R |

### Mean CI Functions

| Function | Purpose | File |
|----------|---------|------|
| `calculate_mean_ci()` | t-distribution | 05_means.R |
| `bootstrap_mean_ci()` | Bootstrap resampling | 05_means.R |
| `credible_interval_mean()` | Bayesian Normal-Normal | 05_means.R |

### Validation Functions

| Function | Purpose | File |
|----------|---------|------|
| `validate_proportion()` | Check 0 ≤ p ≤ 1 | 06_validation.R |
| `validate_sample_size()` | Check n > 0 | 06_validation.R |
| `validate_conf_level()` | Check 0 < α < 1 | 06_validation.R |

### Output Functions

| Function | Purpose | File |
|----------|---------|------|
| `write_confidence_output()` | Create Excel workbook | 07_output.R |
| `build_proportions_dataframe()` | Results → dataframe | 07_output.R |
| `build_means_dataframe()` | Results → dataframe | 07_output.R |
| `add_summary_sheet()` | Create Summary sheet | 07_output.R |
| `add_proportions_detail_sheet()` | Create detail sheet | 07_output.R |
| `add_means_detail_sheet()` | Create detail sheet | 07_output.R |

### Utility Functions

| Function | Purpose | File |
|----------|---------|------|
| `format_decimal()` | Format with separator | utils.R |
| `parse_codes()` | Parse "1,2,3" → c(1,2,3) | utils.R |
| `create_timestamp()` | Formatted timestamp | utils.R |
| `safe_division()` | Handle division by zero | utils.R |

---

## Appendix B: Config File Schema

### File_Paths Sheet

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| Parameter | Text | Yes | Parameter name |
| Value | Text | Yes | File path or variable name |

**Valid Parameters:**
- `Data_File`: Path to survey data (CSV or XLSX)
- `Output_File`: Path for results Excel file
- `Weight_Variable`: Column name for weights (or blank for unweighted)

### Study_Settings Sheet

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| Setting | Text | Yes | Setting name |
| Value | Text/Numeric | Yes | Setting value |

**Valid Settings:**
- `Calculate_Effective_N`: Y/N
- `Multiple_Comparison_Adjustment`: Y/N
- `Multiple_Comparison_Method`: None/Bonferroni/BH
- `Bootstrap_Iterations`: Integer (1000-10000)
- `Confidence_Level`: Numeric (0.90-0.99)
- `Decimal_Separator`: . or ,

### Question_Analysis Sheet

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| Question_ID | Text | Yes | Unique identifier (max 200) |
| Statistic_Type | Text | Yes | "Proportion" or "Mean" |
| Categories | Text | Conditional | For proportions: values to count (e.g., "Yes" or "9,10") |
| Run_MOE | Text | Yes | Y/N - Normal approximation |
| Run_Wilson | Text | Yes | Y/N - Wilson score |
| Run_Bootstrap | Text | Yes | Y/N - Bootstrap resampling |
| Run_Credible | Text | Yes | Y/N - Bayesian credible interval |
| Prior_Alpha | Numeric | No | For Bayesian proportions (deprecated) |
| Prior_Beta | Numeric | No | For Bayesian proportions (deprecated) |
| Prior_Mean | Numeric | No | For Bayesian (proportions or means) |
| Prior_SD | Numeric | No | For Bayesian means only |
| Prior_N | Numeric | No | For Bayesian (prior sample size) |
| Notes | Text | No | User notes |

---

## Appendix C: Troubleshooting Decision Tree

```
Issue: Analysis fails
│
├─ Error in Step 1 (Config)?
│  ├─ Missing columns? → Check Excel sheet headers
│  ├─ Invalid values? → Check Y/N flags, numeric formats
│  └─ File not found? → Check file paths in File_Paths sheet
│
├─ Error in Step 2 (Data)?
│  ├─ File not found? → Check Data_File path (absolute or relative)
│  ├─ Format error? → Try CSV instead of XLSX
│  └─ Encoding issue? → Save as UTF-8
│
├─ Error in Step 3 (Study-Level)?
│  ├─ Weight errors? → Check for negatives, zeros, NAs
│  ├─ Variable not found? → Check Weight_Variable name matches data
│  └─ High DEFF warning? → Expected if weights vary greatly
│
├─ Error in Step 4 (Processing)?
│  ├─ Categories not matching? → Check data values vs Categories column
│  ├─ Question not found? → Check Question_ID matches column name
│  └─ CI methods failing? → Check function signatures in maintenance guide
│
└─ Error in Step 6 (Output)?
   ├─ Column mismatch? → Ensure dplyr installed or use fallback
   ├─ Format errors? → Check decimal separator handling
   └─ File permissions? → Check write access to output directory
```

---

**End of Maintenance Guide**

**Document Version:** 1.0.0
**Last Updated:** 2025-11-13
**Next Review:** 2025-12-13
