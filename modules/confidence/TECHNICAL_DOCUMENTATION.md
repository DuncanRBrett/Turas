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
