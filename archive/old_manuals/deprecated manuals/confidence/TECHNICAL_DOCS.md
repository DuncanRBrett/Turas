# Confidence Module - Technical Documentation

**Version:** 2.0.0
**Last Updated:** December 1, 2025
**Audience:** Developers, Technical Maintainers

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Code Structure](#code-structure)
3. [Data Flow](#data-flow)
4. [Core Components](#core-components)
5. [Statistical Methods](#statistical-methods)
6. [Configuration System](#configuration-system)
7. [Testing Framework](#testing-framework)
8. [Error Handling](#error-handling)
9. [Performance Considerations](#performance-considerations)
10. [Extension Points](#extension-points)

---

## Architecture Overview

### Design Philosophy

The module follows these principles:

1. **Modularity** - Each R file has a single, clear responsibility
2. **Testability** - Functions are pure and testable in isolation
3. **Robustness** - Comprehensive validation and error handling
4. **Performance** - Optimized for typical survey datasets (1K-10K respondents)
5. **Maintainability** - Clear naming, documentation, and structure

### Module Structure

```
modules/confidence/
├── R/                          # Core R code
│   ├── utils.R                 # Utility functions
│   ├── 01_load_config.R        # Configuration loading
│   ├── 02_load_data.R          # Data loading
│   ├── 03_study_level.R        # Study-level calculations
│   ├── 04_proportions.R        # Proportion CI methods
│   ├── 05_means.R              # Mean CI methods
│   ├── 06_nps.R                # NPS calculations
│   ├── 07_output.R             # Excel output generation
│   └── 00_main.R               # Main orchestration
├── tests/                      # Test suite
│   ├── test_representativeness.R
│   ├── test_nps.R
│   ├── test_weighted_data.R
│   └── test_real_config_ccpb.R
├── run_confidence_gui.R        # Shiny GUI launcher
└── [documentation files]
```

---

## Code Structure

### File Responsibilities

#### **R/utils.R**

Utility functions used across the module:

```r
# Key functions:
- format_number_for_output()  # Decimal separator formatting
- parse_codes()                # Parse comma-separated code lists
- calculate_effective_n()      # Kish effective sample size
- is_package_available()       # Check package availability
```

**Dependencies:** None (base R only)
**Used by:** All other R files

---

#### **R/01_load_config.R**

Configuration file loading and validation.

```r
# Main function:
load_confidence_config(config_path) -> list

# Returns:
config <- list(
  file_paths = data.frame(...),
  study_settings = data.frame(...),
  questions = data.frame(...),        # Max 200 rows enforced
  population_margins = data.frame(...) # Optional
)

# Key validations:
- Sheet existence checks
- Required column validation
- Value range checks (confidence level, bootstrap iterations)
- 200 question limit enforcement
```

**Validation Rules:**

| Parameter | Valid Values | Default |
|-----------|--------------|---------|
| Confidence_Level | 0.90, 0.95, 0.99 | 0.95 |
| Bootstrap_Iterations | 1000-10000 | 5000 |
| Decimal_Separator | "." or "," | "." |
| Calculate_Effective_N | "Y" or "N" | "Y" |

**Error Handling:**
- Missing sheets → Stop with clear message
- Invalid values → Stop with validation error
- Too many questions → Stop at 200 limit

---

#### **R/02_load_data.R**

Data file loading with format detection.

```r
# Main function:
load_survey_data(data_file_path, verbose) -> data.frame

# Supported formats:
- CSV (via data.table::fread or base::read.csv)
- XLSX (via readxl::read_excel)
- XLS (via readxl::read_excel)

# Features:
- Automatic format detection by extension
- Fast loading with data.table if available
- Preserves column names (check.names = FALSE)
- Returns data.frame (never data.table)
```

**Performance Note:**
Uses `data.table::fread()` for CSV files when available (5-10x faster than base R for large files).

---

#### **R/03_study_level.R**

Study-level statistics and diagnostics.

```r
# Main functions:
calculate_study_level_stats(data, weights) -> data.frame
compute_weight_concentration(weights) -> data.frame
compute_margin_comparison(data, weights, targets) -> data.frame

# Study-level stats:
- Actual n (raw respondent count)
- Effective n (Kish formula: n_eff = (sum(w))^2 / sum(w^2))
- DEFF (Design effect: n_actual / n_eff)

# Weight concentration:
- Top 1%, 5%, 10% weight shares
- Concentration flag: LOW (<15%), MODERATE (15-25%), HIGH (>25%)

# Margin comparison:
- Simple quotas (single variable)
- Nested quotas (multi-variable interactions)
- Traffic-light flags: GREEN (<2pp), AMBER (2-5pp), RED (≥5pp)
```

**Design Effect Interpretation:**
```
DEFF = 1.0  → No impact from weighting
DEFF = 1.5  → 50% variance inflation
DEFF > 2.0  → Consider reviewing weights
```

---

#### **R/04_proportions.R**

Proportion confidence interval methods.

```r
# CI Methods:

1. calculate_proportion_ci_normal(p, n, conf_level)
   - Normal approximation: SE = sqrt(p(1-p)/n)
   - Fast, works well for moderate p and large n

2. calculate_proportion_ci_wilson(p, n, conf_level)
   - Wilson score interval
   - Better for small n or extreme p (near 0 or 1)
   - Recommended by statisticians over normal approximation

3. bootstrap_proportion_ci(data, categories, weights, B, conf_level)
   - Resampling with replacement
   - Handles weighted data correctly
   - Empirical percentile method
   - B = 5000-10000 typical

4. credible_interval_proportion(p, n, conf_level, prior_mean, prior_n)
   - Beta-Binomial conjugate prior
   - Default: Jeffrey's prior (alpha=0.5, beta=0.5)
   - Returns Bayesian credible interval
```

**Method Selection Guide:**

| Scenario | Recommended Method |
|----------|-------------------|
| Standard case | MOE (Normal) or Wilson |
| Small sample (n < 30) | Wilson or Bootstrap |
| Extreme proportion (p < 0.05 or p > 0.95) | Wilson |
| Weighted data | Bootstrap |
| Incorporate prior knowledge | Bayesian |

---

#### **R/05_means.R**

Mean confidence interval methods.

```r
# CI Methods:

1. calculate_mean_ci_t(values, conf_level)
   - Student's t-distribution
   - SE = SD / sqrt(n)
   - Works for weighted data (uses effective n)

2. bootstrap_mean_ci(values, weights, B, conf_level)
   - Weighted resampling
   - No distributional assumptions
   - Robust to outliers (when used with trimmed mean)

3. credible_interval_mean(mean, sd, n, conf_level, prior_mean, prior_sd, prior_n)
   - Normal-Normal conjugate prior
   - Default: non-informative prior
   - Posterior: weighted average of prior and data
```

**Weighted Mean Calculation:**
```r
weighted_mean = sum(values * weights) / sum(weights)
weighted_var = sum(weights * (values - weighted_mean)^2) / sum(weights)
```

---

#### **R/06_nps.R**

Net Promoter Score calculations (currently integrated in 00_main.R).

```r
# NPS Calculation:
process_nps_question(q_row, survey_data, weight_var, config)

# Steps:
1. Identify promoters (codes 9-10 by default)
2. Identify detractors (codes 0-6 by default)
3. Calculate: NPS = %Promoters - %Detractors (range: -100 to +100)
4. Standard error: sqrt(var_p + var_d - 2*cov(p,d))
5. Apply CI methods (Normal, Bootstrap, Bayesian)

# Configuration:
- Promoter_Codes: comma-separated list (e.g., "9,10")
- Detractor_Codes: comma-separated list (e.g., "0,1,2,3,4,5,6")
```

**NPS Variance Formula:**
```
var(NPS) = var(p_promoter) + var(p_detractor) - 2*cov(p_promoter, p_detractor)

Where:
- p_promoter = proportion of promoters
- p_detractor = proportion of detractors
- Covariance term accounts for mutual exclusivity
```

---

#### **R/07_output.R**

Excel workbook generation.

```r
# Main function:
write_confidence_output(results, config, output_path)

# Workbook structure:
1. Summary             - High-level overview
2. Study_Level         - Sample size, DEFF, weight metrics
3. Proportions_Detail  - Full results for all proportion questions
4. Means_Detail        - Full results for all mean questions
5. NPS_Detail          - NPS results (if any)
6. Representativeness_Weights - Quota checks (if applicable)
7. Methodology         - Statistical methods documentation
8. Warnings            - Errors and warnings log
9. Inputs              - Configuration snapshot

# Features:
- Decimal separator formatting
- Conditional formatting (representativeness flags)
- Column width auto-sizing
- Professional styling
```

**Conditional Formatting:**
- RED cells: `#FFC7CE` background, `#9C0006` text
- AMBER cells: `#FFF4CE` background, `#9C6500` text
- GREEN cells: `#C6EFCE` background, `#006100` text

---

#### **R/00_main.R**

Main orchestration script.

```r
# Main entry point:
run_confidence_analysis(config_path, verbose = TRUE) -> list

# Execution flow:
1. Load and validate configuration
2. Load survey data
3. Calculate study-level statistics
4. Process questions in parallel-safe loop:
   - Proportions → process_proportion_question()
   - Means → process_mean_question()
   - NPS → process_nps_question()
5. Generate Excel output
6. Return results object

# Return structure:
list(
  study_level_stats = data.frame(...),
  proportion_results = list(...),
  mean_results = list(...),
  nps_results = list(...),
  config = list(...),
  warnings = character(...)
)
```

**Version Constant:**
```r
MAIN_VERSION <- "2.0.0"  # Update this for new releases
```

---

## Data Flow

### High-Level Flow Diagram

```
Config File (Excel)
    ↓
load_confidence_config()
    ↓
[Validated Config Object]
    ↓
load_survey_data()
    ↓
[Survey Data Frame]
    ↓
calculate_study_level_stats()
    ↓
[Loop through questions]
    ├→ Proportion: process_proportion_question()
    ├→ Mean: process_mean_question()
    └→ NPS: process_nps_question()
    ↓
[Results Lists]
    ↓
write_confidence_output()
    ↓
[Excel Workbook]
```

### Detailed Execution Flow

```
1. INITIALIZATION
   - Source R files
   - Set up constants (version, limits)

2. CONFIGURATION LOADING
   - Read Excel sheets
   - Validate structure
   - Validate values
   - Enforce limits (200 questions)
   - Parse optional Population_Margins

3. DATA LOADING
   - Detect file format
   - Load data (CSV or Excel)
   - Validate data structure

4. STUDY-LEVEL ANALYSIS
   - Calculate actual n
   - Calculate effective n (if weighted)
   - Calculate DEFF
   - Compute weight concentration (if weighted)
   - Compare to population margins (if provided)

5. QUESTION-LEVEL ANALYSIS
   For each question:
     a. Extract data and weights
     b. Align values and weights (critical!)
     c. Calculate point estimate
     d. Calculate effective n for this question
     e. Apply requested CI methods
     f. Handle errors gracefully
     g. Log warnings if issues occur

6. OUTPUT GENERATION
   - Format numbers (decimal separator)
   - Create workbook
   - Add sheets with results
   - Apply conditional formatting
   - Save to file

7. RETURN
   - Return results object
   - Print summary if verbose
```

---

## Core Components

### Values/Weights Alignment

**Critical Pattern:** Always align values and weights to avoid mismatched CIs.

```r
# CORRECT pattern (used throughout module):

# Step 1: Identify valid indices
valid_value_idx <- !is.na(values) & is.finite(values)

if (!is.null(weights)) {
  # Step 2: Keep only rows with BOTH valid value AND valid weight
  good_idx <- valid_value_idx & !is.na(weights) & weights > 0

  # Step 3: Subset both in parallel
  values_valid <- values[good_idx]
  weights_valid <- weights[good_idx]
} else {
  values_valid <- values[valid_value_idx]
  weights_valid <- NULL
}

# Now values_valid and weights_valid are perfectly aligned
```

**Why this matters:**
Bug #2 from external review was caused by misalignment leading to incorrect confidence intervals.

---

### Numeric Conversion Logic

Handles text-formatted numeric columns automatically.

```r
# Smart conversion (added in v2.0):
if (!is.numeric(values)) {
  values_converted <- suppressWarnings(as.numeric(values))

  # Count non-missing before conversion
  n_non_missing_before <- sum(!is.na(values) & values != "")

  # Count valid after conversion
  n_valid_after <- sum(!is.na(values_converted))

  # Accept if ≥80% of non-missing values convert AND n≥10
  if (n_valid_after >= 10) {
    conversion_rate <- n_valid_after / n_non_missing_before
    if (conversion_rate >= 0.80) {
      values <- values_converted  # Use converted values
    }
  }
}
```

**Handles:**
- Text-formatted numbers in Excel
- Rating questions stored as character
- Routed questions with low response rates

---

### Backward Compatibility

Checks for optional columns before accessing.

```r
# Example: Use_Wilson column (added in v2.0)
use_wilson_flag <- if ("Use_Wilson" %in% names(q_row)) {
  q_row$Use_Wilson
} else {
  NULL  # Column doesn't exist in old configs
}

# Then check flag normally
if (!is.null(use_wilson_flag) && toupper(use_wilson_flag) == "Y") {
  # Run Wilson interval
}
```

**Pattern:** Always check column existence for optional/new features.

---

## Statistical Methods

### Effective Sample Size (Kish Formula)

```r
calculate_effective_n <- function(weights) {
  if (is.null(weights) || length(weights) == 0) return(length(weights))

  n_eff <- (sum(weights))^2 / sum(weights^2)
  return(n_eff)
}
```

**Interpretation:**
- Measures the "equivalent unweighted sample size"
- Always ≤ actual sample size
- Larger weights variation → smaller n_eff

---

### Design Effect (DEFF)

```r
deff <- n_actual / n_eff

# Alternative formula (for means):
deff <- 1 + CV²
where CV = coefficient of variation of weights
```

**Usage:**
- Adjust CIs for weighting impact
- Assess weight quality
- Report alongside weighted results

---

### Bootstrap Resampling

```r
bootstrap_proportion_ci <- function(data, categories, weights, B, conf_level) {
  n <- length(data)
  boot_props <- numeric(B)

  for (i in 1:B) {
    if (!is.null(weights)) {
      # Weighted sampling: sample with probability ~ weights
      idx <- sample(1:n, size = n, replace = TRUE, prob = weights)
      boot_sample <- data[idx]
      boot_weights <- weights[idx]
      # Calculate weighted proportion
      boot_props[i] <- weighted_proportion(boot_sample, categories, boot_weights)
    } else {
      # Unweighted sampling
      idx <- sample(1:n, size = n, replace = TRUE)
      boot_sample <- data[idx]
      boot_props[i] <- mean(boot_sample %in% categories)
    }
  }

  # Percentile method
  alpha <- 1 - conf_level
  ci_lower <- quantile(boot_props, alpha/2)
  ci_upper <- quantile(boot_props, 1 - alpha/2)

  return(c(lower = ci_lower, upper = ci_upper))
}
```

**Key Points:**
- Weighted bootstrap samples with probability ∝ weight
- Recomputes weights after sampling
- Percentile method for CI construction
- B = 5000-10000 for stable results

---

### Bayesian Methods

#### Proportions (Beta-Binomial)

```r
# Prior: Beta(α, β)
# Data: k successes out of n trials
# Posterior: Beta(α + k, β + n - k)

# Default prior (Jeffrey's): α = β = 0.5
# User can specify: prior_mean and prior_n
# Then: α = prior_mean * prior_n, β = (1 - prior_mean) * prior_n

# Credible interval: quantiles of posterior distribution
```

#### Means (Normal-Normal)

```r
# Prior: N(μ₀, σ₀²)
# Data: sample with mean x̄, variance s², size n
# Posterior: N(μ', σ'²)

# Where:
# Precision (τ) = 1/σ²
# τ' = τ₀ + n*τ_data
# μ' = (τ₀*μ₀ + n*τ_data*x̄) / τ'

# Credible interval: μ' ± z * σ'
```

---

## Configuration System

### Configuration Object Structure

```r
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
    Run_Bootstrap = c("Y", "N", ...),
    Run_Credible = c("N", "Y", ...),
    Use_Wilson = c("Y", "N", ...),  # Optional (v2.0+)
    Promoter_Codes = c(NA, NA, ...),  # For NPS only
    Detractor_Codes = c(NA, NA, ...),  # For NPS only
    Prior_Mean = c(NA, 0.5, ...),  # Optional Bayesian prior
    Prior_N = c(NA, 10, ...)  # Optional Bayesian prior
  ),

  population_margins = data.frame(  # Optional sheet
    Variable = c("Gender", "Gender", "Age_Group", ...),
    Category_Label = c("Male", "Female", "18-34", ...),
    Target_Prop = c(0.49, 0.51, 0.30, ...),
    Include = c("Y", "Y", "Y", ...)
  )
)
```

### Validation Rules

**File_Paths:**
- Data_File: Must be valid path (checked at load time)
- Output_Path: Directory must exist or be creatable

**Study_Settings:**
- Confidence_Level ∈ {0.90, 0.95, 0.99}
- Bootstrap_Iterations ∈ [1000, 10000]
- Decimal_Separator ∈ {".", ","}
- Calculate_Effective_N ∈ {"Y", "N"}

**Question_Analysis:**
- Max 200 rows (enforced)
- Question_ID: Must be non-empty
- Statistic_Type ∈ {"proportion", "mean", "nps"}
- If proportion: Categories required
- If NPS: Promoter_Codes and Detractor_Codes required
- Run flags ∈ {"Y", "N", NA}

**Population_Margins:**
- Variable: Can include "," for nested quotas
- Target_Prop: Must sum to ~1.0 for each variable
- Values ∈ (0, 1)

---

## Testing Framework

### Test Suite Structure

```
tests/
├── test_representativeness.R  # Tests quota checking feature
├── test_nps.R                 # Tests NPS calculations
├── test_weighted_data.R       # Tests weighted data handling
└── test_real_config_ccpb.R    # Real-world backward compatibility
```

### Running Tests

```r
# Individual tests
source("modules/confidence/tests/test_representativeness.R")
source("modules/confidence/tests/test_nps.R")
source("modules/confidence/tests/test_weighted_data.R")

# Real config test (requires actual data file)
source("modules/confidence/tests/test_real_config_ccpb.R")
```

### Writing New Tests

**Template:**

```r
#!/usr/bin/env Rscript
# Test: [Description]
# Purpose: [What this tests]
# Date: [Date]

cat("====================================\n")
cat("TEST: [Name]\n")
cat("====================================\n\n")

# Setup
# ...

# Run test
tryCatch({
  # Test code here
  result <- some_function(...)

  # Assertions
  stopifnot(expected_condition)

  cat("✓ Test passed\n")

}, error = function(e) {
  cat("❌ Test failed\n")
  cat("Error:", e$message, "\n")
  stop(e)
})
```

**Best Practices:**
- Use synthetic data when possible (no external dependencies)
- Test both success and failure cases
- Check edge cases (empty data, missing weights, etc.)
- Verify output structure
- Test backward compatibility

---

## Error Handling

### Error Handling Strategy

1. **Configuration Errors:** Stop immediately with clear message
2. **Data Loading Errors:** Stop with file path and reason
3. **Question-Level Errors:** Log warning, continue processing
4. **Output Errors:** Log warning, attempt to continue

### Error Message Template

```r
stop(sprintf(
  "Configuration Error: [Specific Issue]\n\n" ,
  "Location: [Sheet/Parameter]\n",
  "Value: [Problematic Value]\n",
  "Expected: [What was expected]\n\n",
  "Action: [How to fix]\n"
))
```

### Warning Collection Pattern

```r
# Initialize at function start
warnings_list <- character()

# Add warnings as you go
if (some_issue) {
  warnings_list <- c(
    warnings_list,
    sprintf("Question %s: [Issue description]", q_id)
  )
  # Return early with NULL result
  return(list(result = NULL, warnings = warnings_list))
}

# Return warnings with result
return(list(result = result_obj, warnings = warnings_list))
```

---

## Performance Considerations

### Optimization Techniques

1. **Fast CSV Loading**
   ```r
   # Use data.table when available (5-10x faster)
   if (is_package_available("data.table")) {
     data <- data.table::fread(file, data.table = FALSE)
   }
   ```

2. **Vectorized Operations**
   ```r
   # Good: Vectorized
   valid_idx <- !is.na(values) & is.finite(values)

   # Bad: Loop
   valid_idx <- sapply(values, function(x) !is.na(x) && is.finite(x))
   ```

3. **Preallocate Vectors**
   ```r
   # Good
   boot_props <- numeric(B)  # Preallocate
   for (i in 1:B) boot_props[i] <- ...

   # Bad
   boot_props <- c()  # Grows each iteration
   for (i in 1:B) boot_props <- c(boot_props, ...)
   ```

4. **Avoid Unnecessary Computation**
   ```r
   # Calculate once, reuse
   n_eff <- calculate_effective_n(weights)
   # Use n_eff multiple times
   ```

### Performance Benchmarks

**Typical Performance (MacBook Pro M1, 16GB RAM):**

| Task | Dataset Size | Time |
|------|--------------|------|
| Load config | N/A | <1 sec |
| Load CSV (10K rows) | 10,000 × 50 | ~1 sec (with data.table) |
| Study-level stats | 10,000 respondents | <1 sec |
| Proportion CI (Normal) | 10,000 respondents | <0.1 sec |
| Bootstrap CI (5K iter) | 1,000 respondents | ~1 sec |
| Bootstrap CI (5K iter) | 10,000 respondents | ~10 sec |
| Full analysis (50Q) | 1,000 respondents | ~30 sec |

**Bottlenecks:**
- Bootstrap with many iterations and large samples
- Excel file writing for large result sets

---

## Extension Points

### Adding New CI Methods

1. **Create function in appropriate file** (04_proportions.R or 05_means.R)

```r
calculate_proportion_ci_newmethod <- function(p, n, conf_level, ...) {
  # Implementation
  # ...

  return(list(
    lower = ci_lower,
    upper = ci_upper,
    method = "NewMethod"
  ))
}
```

2. **Add config column** in Question_Analysis sheet: `Run_NewMethod`

3. **Add processing logic** in 00_main.R:

```r
run_newmethod_flag <- q_row$Run_NewMethod
if (!is.null(run_newmethod_flag) &&
    !is.na(run_newmethod_flag) &&
    toupper(run_newmethod_flag) == "Y") {
  result$newmethod <- calculate_proportion_ci_newmethod(...)
}
```

4. **Update output** in 07_output.R to include new columns

5. **Add tests** in test suite

6. **Update documentation**

---

### Adding New Question Types

Example: Adding "median" statistic type

1. **Create processing function** in appropriate file (R/05_means.R or new file)

```r
process_median_question <- function(q_row, survey_data, weight_var, config, warnings_list) {
  # Similar structure to process_mean_question
  # Calculate median
  # Apply CI methods appropriate for median
  # Return result and warnings
}
```

2. **Update dispatcher** in 00_main.R:

```r
if (stat_type == "median") {
  result <- process_median_question(q_row, survey_data, weight_var, config, warnings)
  median_results[[q_id]] <- result$result
  warnings <- c(warnings, result$warnings)
}
```

3. **Add output sheet** in 07_output.R:

```r
add_median_detail_sheet(wb, median_results, config)
```

4. **Update config validation** to allow "median" in Statistic_Type

5. **Add tests**

6. **Update documentation**

---

### Adding New Representativeness Checks

Example: Adding "intersectional" quota check

1. **Create function** in 03_study_level.R:

```r
compute_intersectional_margin <- function(data, weights, target_margins) {
  # Handle 3-way or 4-way interactions
  # Return comparison data frame
}
```

2. **Call from main** margin comparison logic

3. **Update output** to display intersectional results

4. **Add test cases**

---

## API Reference

### Main Entry Point

```r
run_confidence_analysis(
  config_path,     # Character: Path to Excel config file
  verbose = TRUE   # Logical: Print progress messages
) -> list
```

**Returns:**
```r
list(
  study_level_stats = data.frame(...),
  proportion_results = list(...),
  mean_results = list(...),
  nps_results = list(...),
  config = list(...),
  warnings = character(...)
)
```

### Key Internal Functions

**Configuration:**
```r
load_confidence_config(config_path) -> list
validate_study_settings(df) -> NULL (stops on error)
```

**Data:**
```r
load_survey_data(data_file_path, verbose) -> data.frame
```

**Study-Level:**
```r
calculate_study_level_stats(data, weights) -> data.frame
calculate_effective_n(weights) -> numeric
compute_weight_concentration(weights) -> data.frame
compute_margin_comparison(data, weights, targets) -> data.frame
```

**Proportions:**
```r
calculate_proportion_ci_normal(p, n, conf_level) -> list(lower, upper)
calculate_proportion_ci_wilson(p, n, conf_level) -> list(lower, upper)
bootstrap_proportion_ci(data, categories, weights, B, conf_level) -> list(lower, upper)
credible_interval_proportion(p, n, conf_level, prior_mean, prior_n) -> list(lower, upper)
```

**Means:**
```r
calculate_mean_ci_t(values, conf_level) -> list(lower, upper)
bootstrap_mean_ci(values, weights, B, conf_level) -> list(lower, upper)
credible_interval_mean(mean, sd, n, conf_level, prior_mean, prior_sd, prior_n) -> list(lower, upper)
```

**Output:**
```r
write_confidence_output(results, config, output_path) -> NULL
format_number_for_output(x, decimal_sep, digits) -> character
```

---

## Common Development Tasks

### Updating Version Number

**Locations to update:**
1. `R/00_main.R` → `MAIN_VERSION` constant
2. `README.md` → Version badge
3. `TECHNICAL_DOCUMENTATION.md` → Header
4. `USER_MANUAL.md` → Header

### Adding a New Sheet to Excel Output

1. Create function in `R/07_output.R`:

```r
add_mysheet_detail <- function(wb, data, config) {
  sheet_name <- "MySheet"
  openxlsx::addWorksheet(wb, sheet_name)

  # Write data
  openxlsx::writeData(wb, sheet_name, data, startRow = 1)

  # Formatting
  # ...

  invisible(wb)
}
```

2. Call from `write_confidence_output()`:

```r
wb <- add_mysheet_detail(wb, results$mysheet_data, config)
```

### Debugging Tips

**Enable verbose output:**
```r
result <- run_confidence_analysis(config_path, verbose = TRUE)
```

**Check warnings:**
```r
if (length(result$warnings) > 0) {
  cat("Warnings:\n")
  print(result$warnings)
}
```

**Inspect intermediate results:**
```r
# Add temporary prints in code
cat("DEBUG: values length =", length(values), "\n")
cat("DEBUG: weights length =", length(weights), "\n")
```

**Run specific question:**
```r
# Modify config to process single question
# Easier to debug than full run
```

---

## Code Style Guidelines

### Naming Conventions

- **Functions:** `snake_case` (e.g., `calculate_effective_n`)
- **Variables:** `snake_case` (e.g., `study_level_stats`)
- **Constants:** `SCREAMING_SNAKE_CASE` (e.g., `MAIN_VERSION`)
- **Data frames:** descriptive names (e.g., `survey_data`, `config`)

### Function Structure

```r
function_name <- function(param1, param2, param3 = default_value) {
  # -------------------------------------------------------------------------
  # Brief description of what function does
  # -------------------------------------------------------------------------

  # Input validation
  if (invalid_input) stop("Clear error message")

  # Main logic
  result <- ...

  # Return
  return(result)
}
```

### Comments

- Use `#` for single-line comments
- Use section dividers for major blocks:
  ```r
  # ========================================================================
  # SECTION NAME
  # ========================================================================
  ```
- Use subsection dividers:
  ```r
  # -------------------------------------------------------------------------
  # Subsection name
  # -------------------------------------------------------------------------
  ```

---

## Maintenance Checklist

### Before Each Release

- [ ] Run full test suite
- [ ] Test with real config files
- [ ] Update version number in all locations
- [ ] Update README with new features
- [ ] Update USER_MANUAL with new features
- [ ] Review and update TECHNICAL_DOCUMENTATION
- [ ] Check all documentation links work
- [ ] Test GUI and command line interfaces
- [ ] Verify backward compatibility
- [ ] Update version history in README

### Monthly

- [ ] Review open issues/bugs
- [ ] Check for R package updates
- [ ] Review performance on large datasets
- [ ] Update dependencies if needed

### Quarterly

- [ ] Review code for potential optimizations
- [ ] Update statistical methods if new research available
- [ ] Consider user feedback for feature additions
- [ ] Review and update examples

---

## Troubleshooting Development Issues

### "Function not found" errors

**Cause:** Sourcing order incorrect
**Fix:** Always source files in order: utils → 01 → 02 → ... → 00

### Bootstrap taking too long

**Cause:** Too many iterations or large dataset
**Fix:** Reduce B for testing, or optimize sampling code

### Excel output fails

**Cause:** Usually permission issues or file already open
**Fix:** Check file permissions, close Excel, ensure directory writable

### Tests failing after changes

**Cause:** Breaking changes to API or output structure
**Fix:** Update tests to match new behavior, add regression tests

---

## Future Development Ideas

### Phase 3 Possibilities

- **Banner column support** - Analyze by demographic breaks
- **Multiple comparison adjustments** - Bonferroni, Holm, FDR
- **Subgroup analysis** - Automatic subgroup detection
- **Trend analysis** - Compare across waves
- **Interactive dashboard** - Shiny app for exploring results
- **API mode** - JSON input/output for integration
- **Parallel processing** - Speed up bootstrap
- **GPU acceleration** - For very large datasets

### Enhancements

- **Auto-detect question types** - From data patterns
- **Smart prior selection** - Bayesian methods
- **Adaptive bootstrap** - Stop when stable
- **Result caching** - For iterative analysis
- **Export to other formats** - CSV, JSON, RDS

---

## Contact & Support

For technical questions or contributions:

**Project:** Turas Analytics Platform
**Module:** Confidence Analysis
**Version:** 2.0.0
**Last Updated:** December 1, 2025

---

**End of Technical Documentation**

---

## Maintenance Guide

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

---

## Testing Guide

# CONFIDENCE MODULE - TESTING GUIDE

**Date:** November 30, 2025
**Status:** All critical bugs fixed - Ready for testing

---

## STEP 1: Run Weighted Data Test (Verify Bug Fixes)

This comprehensive test verifies all the weighted data bug fixes work correctly.

### Run the Test:

```r
setwd("~/Documents/Turas/modules/confidence")
source("tests/test_weighted_data.R")
```

### What It Tests:

1. **Standard weighted data** - Normal scenario
2. **NA weights** - Critical bug fix #2 verification
3. **Zero weights** - Critical bug fix #2 verification
4. **Mixed messy data** - Worst case scenario (NA + zeros + missing)
5. **Extreme weight variation** - Stress test with high DEFF

### Expected Output:

```
================================================================================
ALL WEIGHTED DATA TESTS PASSED!
================================================================================

Tests completed:
  ✓ TEST 1: Standard weighted data
  ✓ TEST 2: NA weights (critical bug fix verified)
  ✓ TEST 3: Zero weights (critical bug fix verified)
  ✓ TEST 4: Mixed messy data (worst case)
  ✓ TEST 5: Extreme weight variation (stress test)

Critical verifications:
  ✓ No length mismatch errors
  ✓ No crashes in weighted.mean()
  ✓ No crashes in bootstrap functions
  ✓ Values and weights correctly aligned
  ✓ NA and zero weights properly excluded
  ✓ Effective n calculated correctly
  ✓ DEFF reflects weight variation

The weighted data bug fixes are confirmed working!
Ready for production use with weighted survey data.
```

**If this test passes:** ✅ All weighted data handling is working correctly!

---

## STEP 2: Test Through Turas GUI

Now test with your real data using the GUI.

### Launch Turas:

```r
setwd("~/Documents/Turas")
source("launch_turas.R")
```

### Steps in GUI:

1. **Click "Launch Confidence"** button (orange button with 📊 icon)
2. **New window opens** with the Confidence GUI
3. **Select your project directory** (click "Browse for Project Folder")
4. **Choose config file** from detected .xlsx files
5. **Click "RUN ANALYSIS"**

---

## STEP 3: Prepare Your Real Data

### Required Files:

1. **Survey data** (CSV or XLSX):
   - Must have columns for each question
   - Optional: weight variable
   - Example: `survey_data.csv`

2. **Configuration file** (XLSX with 3 sheets):
   - `File_Paths` - Points to data file, output location, weight variable
   - `Study_Settings` - Analysis settings
   - `Question_Analysis` - Questions to analyze

---

## Configuration Template

### Sheet 1: File_Paths

| Parameter | Value |
|-----------|-------|
| Data_File | path/to/survey_data.csv |
| Output_File | path/to/results.xlsx |
| Weight_Variable | weight |

### Sheet 2: Study_Settings

| Setting | Value | Valid Options |
|---------|-------|---------------|
| Calculate_Effective_N | Y | Y/N |
| Multiple_Comparison_Adjustment | N | Y/N (not implemented yet) |
| Multiple_Comparison_Method | None | None/Bonferroni/Holm/FDR |
| Bootstrap_Iterations | 5000 | 1000-10000 |
| Confidence_Level | 0.95 | 0.90/0.95/0.99 |
| Decimal_Separator | . | . or , |

### Sheet 3: Question_Analysis

| Question_ID | Statistic_Type | Categories | Run_MOE | Use_Wilson | Run_Bootstrap | Run_Credible |
|-------------|----------------|------------|---------|------------|---------------|--------------|
| Q1_Aware | proportion | 1 | Y | Y | Y | N |
| Q2_Satisfaction | mean | NA | Y | N | Y | N |

**Important:**
- `Statistic_Type` must be `proportion` or `mean` (NOT `nps` - that's Phase 2)
- For proportions: Specify `Categories` (codes to count as success)
- For means: Leave `Categories` as NA
- `Use_Wilson` flag (not `Run_Wilson`) for Wilson score intervals

---

## What to Watch For

### ✅ Good Signs:

- Analysis completes without errors
- Output Excel file created with 7 sheets
- Results look reasonable (proportions 0-1, sensible CIs)
- Warnings are informative (e.g., "Small base n=25")

### ⚠️ Warning Messages (Normal):

These are **informative**, not errors:

```
Weight variable 'weight' contains X zero values (these will be excluded from analysis)
Weight variable 'weight' contains X NA values (these will be excluded from analysis)
Question Q5: Small base (n=45) - interpret with caution
```

### 🔴 Error Messages (Report These):

If you see any of these, please report:

```
ERROR: Question X: different lengths
ERROR: weights must have same length as data
ERROR: if(logical(0)) ...
ERROR: Statistic_Type must be 'proportion' or 'mean' (NPS support planned for Phase 2)
```

---

## Output File Structure

The Excel workbook will have **7 sheets**:

1. **Summary** - High-level overview
2. **Study_Level** - DEFF, effective n, weight statistics
3. **Proportions_Detail** - All proportion results with CIs
4. **Means_Detail** - All mean results with CIs
5. **Methodology** - Statistical formulas and references
6. **Warnings** - Data quality warnings
7. **Inputs** - Configuration summary for reproducibility

---

## Common Issues & Solutions

### Issue: "Config file not detected"
**Solution:** Config file must be `.xlsx` and contain "confidence" in filename (case-insensitive)

### Issue: "Question X not found in data"
**Solution:** Check Question_ID spelling matches data column names exactly

### Issue: "Weight variable 'X' not found"
**Solution:** Check Weight_Variable spelling in File_Paths sheet

### Issue: "Prior_SD required when Prior_Mean specified for mean"
**Solution:** For Bayesian mean CIs, must specify both Prior_Mean AND Prior_SD

### Issue: Analysis runs but some questions missing
**Solution:** Check warnings in console or Warnings sheet - likely small sample or all NA

---

## Weighted Data Specifics

### If Using Weights:

1. **Specify Weight_Variable** in File_Paths sheet
2. **Set Calculate_Effective_N = Y** in Study_Settings
3. **Check Study_Level sheet** in output for:
   - Actual n (raw sample size)
   - Effective n (precision-adjusted)
   - DEFF (design effect)
   - Weight statistics (min, max, CV)

### Understanding DEFF:

- **DEFF = 1.0** → No precision loss from weighting
- **DEFF = 1.1-1.2** → Modest loss (5-20%)
- **DEFF = 1.2-2.0** → Moderate loss (20-50%)
- **DEFF > 2.0** → Substantial loss (>50%) - check weights!

### Weight Quality Checks:

Look for warnings in Study_Level sheet:
- High CV (> 0.30) → Extreme weight variation
- Wide range (max/min > 10) → Some cases heavily weighted
- High DEFF (> 2.0) → Significant precision loss

---

## Real Data Testing Checklist

Before testing with real data:

- [ ] Run `test_weighted_data.R` and confirm all tests pass
- [ ] Create config file with 3 required sheets
- [ ] Verify Question_IDs match data column names
- [ ] Check weight variable name if using weights
- [ ] Ensure Statistic_Type is only "proportion" or "mean"
- [ ] Use `Use_Wilson` flag (not `Run_Wilson`)

During testing:

- [ ] Launch through `launch_turas.R` GUI
- [ ] Browse to project directory
- [ ] Select config file
- [ ] Click "RUN ANALYSIS"
- [ ] Watch console output for errors
- [ ] Check Excel output has 7 sheets

After testing:

- [ ] Verify proportions are in [0, 1] range
- [ ] Check confidence intervals make sense (lower < upper)
- [ ] Review warnings for data quality issues
- [ ] Compare weighted vs unweighted results (if applicable)
- [ ] Verify n and n_eff values are reasonable

---

## Performance Expectations

### Typical Run Times:

- **10 questions, n=1000, unweighted:** ~5 seconds
- **10 questions, n=1000, weighted, bootstrap:** ~10 seconds
- **50 questions, n=5000, weighted, bootstrap:** ~30-60 seconds
- **200 questions, n=10000, all methods:** ~5-10 minutes

**Note:** Bootstrap with 10,000 iterations is slower than 1,000 iterations

---

## Example Real Data Scenario

### Scenario: Customer Satisfaction Survey

**Data:**
- 2,500 respondents
- 15 satisfaction questions (0-10 scale)
- 5 brand awareness questions (binary 0/1)
- Design weights to correct for demographics

**Config:**
- Means for satisfaction questions (Run_MOE=Y, Run_Bootstrap=Y)
- Proportions for awareness (categories="1", Use_Wilson=Y, Run_Bootstrap=Y)
- Calculate_Effective_N = Y
- Bootstrap_Iterations = 5000
- Confidence_Level = 0.95

**Expected Output:**
- Study DEFF around 1.1-1.3 (typical for demo weighting)
- Effective n around 2,000-2,200 (from 2,500 actual)
- Satisfaction means with ~±0.15 CIs
- Awareness proportions with ~±0.04 CIs (depending on base)

---

## Support & Troubleshooting

### If Tests Fail:

1. Check you pulled latest changes: `git pull`
2. Verify R packages installed: `openxlsx`, `readxl`
3. Review error messages carefully
4. Check file paths are absolute (not relative)

### If GUI Doesn't Launch:

1. Verify `shiny` and `shinyFiles` packages installed
2. Check working directory: `getwd()` should be Turas root
3. Look for error in R console

### If Analysis Crashes:

1. Check config file format (3 sheets with exact names)
2. Verify Question_IDs match data columns
3. Ensure Statistic_Type is only "proportion" or "mean"
4. Review console output for specific error location

---

## Next Steps After Successful Testing

Once your real data test completes successfully:

1. **Review output thoroughly** - Check all sheets make sense
2. **Validate against known benchmarks** - Compare to previous analysis if available
3. **Test edge cases** - Try with small samples, extreme proportions, etc.
4. **Consider Phase 2 features** - NPS, multiple comparisons, etc.

---

## Summary

**Testing Path:**
1. ✅ Run `test_weighted_data.R` → Verify bug fixes
2. ✅ Launch Turas GUI → Test user interface
3. ✅ Run real data analysis → Production verification

**All critical bugs fixed and tested. Ready for production use!**

---

**Document Version:** 1.0
**Last Updated:** November 30, 2025
