# Part 2: Configuration, Testing & Validation Specification

## 1. Configuration File Detailed Specification

### 1.1 Settings Sheet (Complete)

```xlsx
Setting                     | Value              | Type      | Required | Default           | Validation
---------------------------|--------------------|-----------|-----------|--------------------|---------------------------
analysis_type              | "choice"           | string    | Yes      | "choice"          | Must be "choice"
estimation_method          | "auto"             | string    | No       | "auto"            | auto|mlogit|clogit|hb
baseline_handling          | "first_level_zero" | string    | No       | "first_level_zero"| first_level_zero|all_levels_explicit
confidence_level           | 0.95               | numeric   | No       | 0.95              | 0.80 to 0.99
choice_set_column          | "choice_set_id"    | string    | No       | "choice_set_id"   | Must exist in data
chosen_column              | "chosen"           | string    | No       | "chosen"          | Must exist in data
respondent_id_column       | "resp_id"          | string    | No       | "resp_id"         | Must exist in data
alternative_id_column      | "alternative_id"   | string    | No       | NA                | If provided, must exist
data_file                  | "data.csv"         | string    | Yes      | NA                | File must exist
output_file                | "results.xlsx"     | string    | No       | "conjoint_results.xlsx" | Valid path
generate_market_simulator  | TRUE               | logical   | No       | TRUE              | TRUE|FALSE
include_diagnostics        | TRUE               | logical   | No       | TRUE              | TRUE|FALSE
bootstrap_iterations       | 1000               | integer   | No       | 1000              | 100 to 10000
min_responses_per_level    | 10                 | integer   | No       | 10                | Warning if violated
verbose                    | TRUE               | logical   | No       | TRUE              | TRUE|FALSE
```

### 1.2 Attributes Sheet Validation Rules

```r
Validation Rules:
1. AttributeName: Must be unique, alphanumeric + underscore only
2. NumLevels: Integer, 2 to 10 (warning if >6)
3. LevelNames: Comma-separated, count must equal NumLevels
4. No empty values allowed
5. Total attributes: 2 to 12 (error if <2, warning if >6)
6. Level names must match data exactly (case-sensitive)
```

**Example validation function:**
```r
validate_config <- function(config) {
  errors <- character()
  warnings <- character()
  
  # Check attributes
  if (nrow(config$attributes) < 2) {
    errors <- c(errors, "Minimum 2 attributes required")
  }
  if (nrow(config$attributes) > 6) {
    warnings <- c(warnings, "More than 6 attributes may confuse respondents")
  }
  
  # Check levels
  for (i in 1:nrow(config$attributes)) {
    levels <- strsplit(config$attributes$LevelNames[i], ",")[[1]]
    levels <- trimws(levels)
    
    if (length(levels) != config$attributes$NumLevels[i]) {
      errors <- c(errors, sprintf(
        "Attribute '%s': Expected %d levels, found %d",
        config$attributes$AttributeName[i],
        config$attributes$NumLevels[i],
        length(levels)
      ))
    }
    
    if (length(levels) > 6) {
      warnings <- c(warnings, sprintf(
        "Attribute '%s': >6 levels may reduce statistical power",
        config$attributes$AttributeName[i]
      ))
    }
  }
  
  list(
    is_valid = length(errors) == 0,
    errors = errors,
    warnings = warnings
  )
}
```

## 2. Data Validation Specification

### 2.1 Pre-Estimation Validation Checks

**CRITICAL CHECKS (Stop execution):**

```r
critical_validation_checks <- function(data, config) {
  
  # Check 1: Required columns exist
  required_cols <- c(
    config$settings$respondent_id_column,
    config$settings$choice_set_column,
    config$settings$chosen_column,
    config$attributes$AttributeName
  )
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }
  
  # Check 2: Exactly one chosen per choice set
  chosen_per_set <- data %>%
    group_by(!!sym(config$settings$choice_set_column)) %>%
    summarise(n_chosen = sum(!!sym(config$settings$chosen_column)))
  
  if (any(chosen_per_set$n_chosen != 1)) {
    bad_sets <- chosen_per_set$choice_set_id[chosen_per_set$n_chosen != 1]
    stop(sprintf(
      "Invalid choice sets (must have exactly 1 chosen): %s",
      paste(head(bad_sets, 10), collapse = ", ")
    ))
  }
  
  # Check 3: Attribute levels match config
  for (attr in config$attributes$AttributeName) {
    config_levels <- get_config_levels(config, attr)
    data_levels <- unique(data[[attr]])
    
    # Check for levels in data not in config
    extra_levels <- setdiff(data_levels, config_levels)
    if (length(extra_levels) > 0) {
      stop(sprintf(
        "Attribute '%s': Data contains levels not in config: %s",
        attr, paste(extra_levels, collapse = ", ")
      ))
    }
    
    # Check for levels in config not in data
    missing_levels <- setdiff(config_levels, data_levels)
    if (length(missing_levels) > 0) {
      warning(sprintf(
        "Attribute '%s': Config levels not in data: %s",
        attr, paste(missing_levels, collapse = ", ")
      ))
    }
  }
  
  # Check 4: No missing values in critical columns
  for (col in required_cols) {
    if (any(is.na(data[[col]]))) {
      stop(sprintf("Missing values found in column: %s", col))
    }
  }
  
  # Check 5: Chosen is binary (0/1)
  chosen_vals <- unique(data[[config$settings$chosen_column]])
  if (!all(chosen_vals %in% c(0, 1))) {
    stop("'chosen' column must contain only 0 and 1")
  }
}
```

**WARNING CHECKS (Continue with warnings):**

```r
warning_validation_checks <- function(data, config) {
  warnings <- character()
  
  # Warn 1: Low response counts per level
  min_responses <- config$settings$min_responses_per_level %||% 10
  
  for (attr in config$attributes$AttributeName) {
    level_counts <- data %>%
      filter(!!sym(config$settings$chosen_column) == 1) %>%
      count(!!sym(attr))
    
    low_counts <- level_counts %>% 
      filter(n < min_responses)
    
    if (nrow(low_counts) > 0) {
      warnings <- c(warnings, sprintf(
        "Attribute '%s': Low selection counts for levels: %s (<%d responses)",
        attr,
        paste(low_counts[[attr]], collapse = ", "),
        min_responses
      ))
    }
  }
  
  # Warn 2: Some cards never chosen
  never_chosen <- data %>%
    group_by(across(all_of(config$attributes$AttributeName))) %>%
    summarise(
      n_shown = n(),
      n_chosen = sum(!!sym(config$settings$chosen_column)),
      .groups = "drop"
    ) %>%
    filter(n_chosen == 0)
  
  if (nrow(never_chosen) > 0) {
    warnings <- c(warnings, sprintf(
      "%d unique card combinations were never chosen (may affect estimation)",
      nrow(never_chosen)
    ))
  }
  
  # Warn 3: Unbalanced choice set sizes
  set_sizes <- data %>%
    count(!!sym(config$settings$choice_set_column))
  
  if (length(unique(set_sizes$n)) > 1) {
    warnings <- c(warnings, sprintf(
      "Unbalanced choice sets (sizes: %s). Ensure this is intentional.",
      paste(unique(set_sizes$n), collapse = ", ")
    ))
  }
  
  # Warn 4: Sample size adequacy
  n_respondents <- length(unique(data[[config$settings$respondent_id_column]]))
  n_attributes <- nrow(config$attributes)
  max_levels <- max(config$attributes$NumLevels)
  
  # Rule of thumb: Need 300+ responses per segment
  # More if many attributes or levels
  recommended_n <- 300 * (n_attributes / 4) * (max_levels / 4)
  
  if (n_respondents < recommended_n) {
    warnings <- c(warnings, sprintf(
      "Sample size (%d respondents) may be insufficient. Recommended: %d+",
      n_respondents, ceiling(recommended_n)
    ))
  }
  
  warnings
}
```

### 2.2 Post-Estimation Validation

```r
validate_estimation_results <- function(model, data, config) {
  
  issues <- list(
    errors = character(),
    warnings = character(),
    info = character()
  )
  
  # Check 1: Model convergence
  if (!model$convergence$converged) {
    issues$errors <- c(issues$errors, sprintf(
      "Model failed to converge: %s",
      model$convergence$message
    ))
  }
  
  # Check 2: Coefficient significance
  p_values <- summary(model$model)$CoefTable[, "Pr(>|z|)"]
  n_nonsig <- sum(p_values > 0.05)
  pct_nonsig <- n_nonsig / length(p_values) * 100
  
  if (pct_nonsig > 30) {
    issues$warnings <- c(issues$warnings, sprintf(
      "%.0f%% of coefficients are non-significant (p > 0.05). Model may be overfit.",
      pct_nonsig
    ))
  }
  
  # Check 3: McFadden R² quality
  r2 <- 1 - (model$loglik["fitted"] / model$loglik["null"])
  
  if (r2 < 0.10) {
    issues$warnings <- c(issues$warnings, sprintf(
      "Low McFadden R² (%.3f). Model has weak explanatory power.",
      r2
    ))
  } else if (r2 > 0.40) {
    issues$info <- c(issues$info, sprintf(
      "Excellent McFadden R² (%.3f). Model fits well.",
      r2
    ))
  }
  
  # Check 4: Hit rate quality
  hit_rate <- calculate_hit_rate(model, data)
  
  chance_rate <- 1 / mean(table(data[[config$settings$choice_set_column]]))
  
  if (hit_rate < chance_rate * 1.5) {
    issues$warnings <- c(issues$warnings, sprintf(
      "Hit rate (%.1f%%) barely exceeds chance (%.1f%%). Poor predictive accuracy.",
      hit_rate * 100, chance_rate * 100
    ))
  }
  
  # Check 5: Utility ranges
  utilities <- calculate_utilities(model, config)
  
  for (attr in unique(utilities$Attribute)) {
    attr_utils <- utilities$Utility[utilities$Attribute == attr]
    range_val <- max(attr_utils) - min(attr_utils)
    
    if (range_val < 0.1) {
      issues$warnings <- c(issues$warnings, sprintf(
        "Attribute '%s': Very small utility range (%.3f). May be unimportant to respondents.",
        attr, range_val
      ))
    }
  }
  
  issues
}
```

## 3. Testing Strategy

### 3.1 Unit Tests (test each function)

```r
# Test suite structure:
tests/
├── test_config_loading.R
├── test_data_validation.R
├── test_mlogit_estimation.R
├── test_clogit_estimation.R
├── test_utility_calculation.R
├── test_importance_calculation.R
├── test_diagnostics.R
└── test_output_generation.R

# Example test:
test_that("Utility calculation produces zero-centered values", {
  # Setup
  model <- create_test_model()
  config <- create_test_config()
  
  # Execute
  utilities <- calculate_utilities(model, config)
  
  # Verify
  for (attr in unique(utilities$Attribute)) {
    attr_utils <- utilities$Utility[utilities$Attribute == attr]
    expect_equal(sum(attr_utils), 0, tolerance = 1e-10)
  }
})
```

### 3.2 Integration Tests (test with real data)

```r
# Test cases:
1. DE_noodle_conjoint_raw.xlsx
   - Expected: Successful estimation with mlogit
   - Validate against ChatGPT results
   
2. Minimal dataset (2 attributes, 2 levels, 50 responses)
   - Expected: Warning about sample size, but successful estimation
   
3. Complex dataset (6 attributes, 5 levels each, 500 responses)
   - Expected: Successful estimation, no warnings
   
4. Bad data cases:
   a. Missing chosen values → Error
   b. Multiple chosen per set → Error  
   c. Attribute level mismatch → Error
   d. Never-chosen cards → Warning, continue
```

### 3.3 Validation Against Known Results

```r
# Compare against statsmodels results:
test_that("Results match statsmodels for DE noodle dataset", {
  
  # Statsmodels results (from documentation):
  expected_utilities <- data.frame(
    Attribute = c("Price", "Price", "MSG", "MSG", ...),
    Level = c("Low_071", "Mid_089", "Present", "Absent", ...),
    Utility = c(0.7921, 0.5952, -0.4256, 0.4256, ...),
    stringsAsFactors = FALSE
  )
  
  # Run Turas analysis
  results <- run_conjoint_analysis(
    config_file = "test_data/DE_noodle_config.xlsx",
    estimation_method = "mlogit"
  )
  
  # Compare (allow 5% tolerance due to different packages)
  for (i in 1:nrow(expected_utilities)) {
    actual <- results$utilities %>%
      filter(Attribute == expected_utilities$Attribute[i],
             Level == expected_utilities$Level[i]) %>%
      pull(Utility)
    
    expect_equal(actual, expected_utilities$Utility[i], 
                 tolerance = 0.05)
  }
})
```

### 3.4 Edge Case Testing

```r
Edge cases to test:

1. Minimum viable dataset:
   - 2 attributes, 2 levels each
   - 3 choice sets, 2 alternatives each  
   - 20 respondents
   - Expected: Warning but successful

2. Maximum complexity:
   - 12 attributes, 10 levels each
   - Expected: Warning about complexity

3. Perfect separation:
   - One level always chosen
   - Expected: Warning about quasi-complete separation

4. All cards shown equally:
   - Orthogonal design, each card shown to each respondent
   - Expected: Successful, note balanced design

5. Highly unbalanced:
   - Some cards shown 10x more than others
   - Expected: Warning about imbalanced design
```

## 4. Error Handling Strategy

### 4.1 Error Message Standards

```r
# Good error message format:
"[MODULE] Error: [SPECIFIC PROBLEM]
 → [ACTIONABLE SOLUTION]
 → [WHERE TO LOOK]"

# Examples:

# Good:
"[DATA] Error: Choice set 15 has 2 alternatives marked as chosen
 → Each choice set must have exactly ONE chosen alternative (chosen=1)
 → Check rows 145-148 in your data file"

# Bad:
"Error in validate_data: invalid structure"

# Implementation:
create_error <- function(module, problem, solution, location = NULL) {
  msg <- sprintf("[%s] Error: %s\n → %s", module, problem, solution)
  if (!is.null(location)) {
    msg <- paste0(msg, sprintf("\n → %s", location))
  }
  stop(msg, call. = FALSE)
}
```

### 4.2 Error Recovery

```r
# When estimation fails:
1. Try alternative method (auto mode)
2. Provide diagnostic information
3. Suggest data fixes if possible

estimate_with_fallback <- function(data, config) {
  
  # Try primary method
  result <- tryCatch(
    estimate_mlogit(data, config),
    error = function(e) {
      list(success = FALSE, error = e$message)
    }
  )
  
  if (!result$success) {
    # Log failure reason
    log_estimation_failure("mlogit", result$error)
    
    # Try fallback
    message("mlogit failed, trying clogit...")
    result <- tryCatch(
      estimate_clogit(data, config),
      error = function(e) {
        list(success = FALSE, error = e$message)
      }
    )
    
    if (!result$success) {
      # Both failed - provide helpful error
      stop(sprintf(
        "[ESTIMATION] Both mlogit and clogit failed.
 → mlogit error: %s
 → clogit error: %s
 → Possible causes:
   1. Perfect separation (one level always chosen)
   2. Insufficient variation in attribute levels
   3. Data quality issues
 → Run validate_conjoint_data() for detailed diagnostics",
        result$error_mlogit,
        result$error_clogit
      ))
    }
  }
  
  result
}
```

## 5. Performance & Scalability

```r
# Expected performance targets:

Dataset Size          | Estimation Time | Output Time | Total
---------------------|-----------------|-------------|-------
Small (n=100)        | <5 sec         | <2 sec      | <10 sec
Medium (n=500)       | <15 sec        | <5 sec      | <20 sec
Large (n=2000)       | <60 sec        | <10 sec     | <90 sec
Very Large (n=5000)  | <180 sec       | <20 sec     | <200 sec

# If exceeding these, add progress indicators
# For n>1000, consider:
1. Data.table for faster manipulation
2. Parallel processing for bootstrap CIs
3. Sparse matrix representation if applicable
```

## 6. Logging & Debugging

### 6.1 Verbose Mode Output

```r
# When verbose = TRUE, provide detailed progress:

"
═══════════════════════════════════════════════════════════════
TURAS CONJOINT ANALYSIS
═══════════════════════════════════════════════════════════════

1. Loading configuration...
   ✓ Loaded 6 attributes with 23 total levels
   ✓ Config validation passed

2. Loading and validating data...
   ✓ Loaded 335 respondents with 1,005 choice sets
   ⚠ Warning: Attribute 'I+G' has low variance (consider removing)
   
3. Estimating model...
   → Method: mlogit (auto-selected)
   → Baseline handling: first_level_zero
   ✓ Model converged successfully
   ✓ McFadden R² = 0.147 (acceptable fit)

4. Calculating utilities and importance...
   ✓ Calculated 23 part-worth utilities
   ✓ All utilities zero-centered within attributes
   
5. Running diagnostics...
   ✓ Hit rate: 47.3% (vs. 33.3% by chance)
   ✓ 22 of 23 coefficients significant (p < 0.05)

6. Generating outputs...
   ✓ Excel workbook: conjoint_results.xlsx
   ✓ Market simulator: Ready for use

═══════════════════════════════════════════════════════════════
ANALYSIS COMPLETE
═══════════════════════════════════════════════════════════════
"
```

### 6.2 Debug Mode

```r
# When debug = TRUE, save intermediate objects:

debug_output/
├── 01_config.rds            # Loaded configuration
├── 02_data_raw.rds          # Raw data
├── 03_data_validated.rds    # After validation
├── 04_model_object.rds      # Fitted model
├── 05_utilities.rds         # Calculated utilities
├── 06_diagnostics.rds       # All diagnostics
└── 07_session_info.txt      # R session info
```

## 7. Documentation Requirements

### 7.1 Function Documentation (roxygen2)

```r
#' Run Conjoint Analysis
#'
#' Estimates part-worth utilities and attribute importance from choice-based
#' conjoint data using logistic regression.
#'
#' @param config_file Path to configuration Excel file (.xlsx)
#' @param data_file Path to respondent data (CSV, XLSX, SAV, DTA). 
#'   If NULL, reads from config Settings sheet.
#' @param output_file Path for results Excel file.
#'   If NULL, reads from config Settings sheet.
#' @param estimation_method Method for estimation:
#'   \itemize{
#'     \item "auto" (default): Try mlogit, fallback to clogit
#'     \item "mlogit": Force mlogit estimation
#'     \item "clogit": Force conditional logit (survival package)
#'     \item "hb": Hierarchical Bayes (requires ChoiceModelR)
#'   }
#' @param baseline_handling How to handle baseline levels:
#'   \itemize{
#'     \item "first_level_zero" (default): First level = 0 utility
#'     \item "all_levels_explicit": All levels estimated
#'   }
#' @param market_simulator Logical. Generate market simulator sheet?
#' @param verbose Logical. Print detailed progress?
#'
#' @return List containing:
#'   \itemize{
#'     \item utilities: Data frame of part-worth utilities
#'     \item importance: Data frame of attribute importance scores
#'     \item fit: Model fit statistics
#'     \item diagnostics: Detailed diagnostics
#'     \item config: Processed configuration
#'     \item model: Fitted model object
#'   }
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' results <- run_conjoint_analysis(
#'   config_file = "conjoint_config.xlsx"
#' )
#'
#' # With specific method
#' results <- run_conjoint_analysis(
#'   config_file = "conjoint_config.xlsx",
#'   estimation_method = "mlogit",
#'   verbose = TRUE
#' )
#' }
#'
#' @export
```

### 7.2 User Guide Structure

```
User Guide Contents:

1. Quick Start
   - Installation
   - First analysis (10 minutes)
   - Understanding outputs

2. Data Preparation
   - Alchemer export format
   - Required columns
   - Common data issues

3. Configuration
   - Settings sheet explained
   - Attributes sheet explained
   - Advanced options

4. Interpretation
   - Part-worth utilities
   - Attribute importance
   - Model diagnostics
   - Market simulator

5. Troubleshooting
   - Common errors and fixes
   - Data quality issues
   - Estimation problems

6. Advanced Topics
   - Baseline handling options
   - Estimation methods comparison
   - Hierarchical Bayes
   - Segmentation analysis

7. Technical Details
   - Statistical methodology
   - Formulas and calculations
   - Package dependencies
```

## 8. Quality Assurance Checklist

### Pre-Release Checklist

- [ ] All unit tests passing
- [ ] Integration tests with real data passing
- [ ] Results match statsmodels within 5% tolerance
- [ ] Excel output generates correctly
- [ ] Market simulator formulas work
- [ ] Error messages are clear and actionable
- [ ] Performance targets met
- [ ] Documentation complete
- [ ] Examples run successfully
- [ ] Code reviewed for quality
- [ ] Memory usage acceptable
- [ ] No hard-coded paths
- [ ] Handles edge cases gracefully

### Validation Checklist

- [ ] Zero-centered utilities verified
- [ ] Importance sums to 100%
- [ ] Market shares sum to 100%
- [ ] Confidence intervals reasonable
- [ ] Significance tests correct
- [ ] Diagnostics accurate
- [ ] Excel formulas correct
- [ ] Dropdowns work properly
- [ ] Charts update automatically
- [ ] Formatting consistent

---

**See Part 1 for Core Technical Specification**
**See Part 3 for Excel Output & Market Simulator details**
