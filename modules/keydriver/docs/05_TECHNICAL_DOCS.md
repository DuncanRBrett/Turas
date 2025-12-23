# Turas Key Driver Analysis - Technical Documentation

**Version:** 10.0
**Last Updated:** 22 December 2025
**Target Audience:** Developers, Technical Maintainers, Data Scientists

---

## Table of Contents

1. [Module Overview](#module-overview)
2. [Architecture](#architecture)
3. [Core Components](#core-components)
4. [API Reference](#api-reference)
5. [Algorithm Implementations](#algorithm-implementations)
6. [SHAP Integration](#shap-integration)
7. [Extension Points](#extension-points)
8. [Testing](#testing)
9. [Performance](#performance)
10. [Known Issues](#known-issues)

---

## Module Overview

### Purpose

The KeyDriver module performs driver analysis using multiple regression to identify which factors have the greatest impact on key outcome metrics. It provides five complementary importance measures for robust prioritization.

### Key Features

- **Five Importance Methods**: Shapley, Relative Weights, Beta, Correlations, SHAP
- **Survey Weights**: Full weighted analysis support
- **VIF Diagnostics**: Multicollinearity detection
- **Quadrant Analysis**: Importance-Performance Analysis
- **Segment Comparison**: Driver analysis by customer segments
- **Excel Output**: Charts, tables, documentation

### Input/Output

**Input:**
- Survey data (CSV/Excel/SPSS/Stata)
- Configuration Excel (Settings, Variables, optional Segments)

**Output:**
- Excel workbook with 6+ sheets
- Optional: SHAP sheets, Quadrant sheets

---

## Architecture

### File Structure

```
modules/keydriver/
├── R/
│   ├── 00_main.R           # Main orchestration (~400 lines)
│   ├── 01_config.R         # Configuration loading (~250 lines)
│   ├── 02_validation.R     # Data validation (~300 lines)
│   ├── 03_analysis.R       # Statistical analysis (~600 lines)
│   └── 04_output.R         # Excel output (~300 lines)
└── docs/
    ├── 01_README.md
    ├── 02_KEYDRIVER_OVERVIEW.md
    ├── 03_REFERENCE_GUIDE.md
    ├── 04_USER_MANUAL.md
    ├── 05_TECHNICAL_DOCS.md
    ├── 06_TEMPLATE_REFERENCE.md
    ├── 07_EXAMPLE_WORKFLOWS.md
    └── templates/
        └── KeyDriver_Config_Template.xlsx
```

**Total:** ~1,850 lines of R code

### Data Flow

```
CONFIG → DATA → VALIDATION → REGRESSION → IMPORTANCE → OUTPUT
   ↓        ↓         ↓            ↓            ↓          ↓
 Excel  Variables  VIF Check   Estimate   5 Methods   Excel
                                Model     Calculate   Report
```

### Dependency Graph

```
00_main.R
├─→ 01_config.R (load_keydriver_config)
├─→ Data loading (CSV/Excel/SPSS)
├─→ 02_validation.R (validate_keydriver_config, validate_data)
├─→ 03_analysis.R
│   ├─→ fit_regression_model
│   ├─→ calculate_shapley_importance
│   ├─→ calculate_relative_weights
│   ├─→ calculate_beta_weights
│   ├─→ calculate_correlations
│   ├─→ calculate_vif
│   └─→ (optional) calculate_shap_importance
└─→ 04_output.R (write_keydriver_output)
```

---

## Core Components

### 00_main.R - Orchestration

**Main Function:**
```r
run_keydriver_analysis <- function(
  config_file,
  data_file = NULL,
  output_file = NULL
) {
  # 1. Load configuration
  config <- load_keydriver_config(config_file)

  # 2. Load data
  data <- load_survey_data(data_file %||% config$data_file)

  # 3. Validate
  validate_keydriver_config(config, data)
  validate_data(data, config)

  # 4. Prepare analysis data
  analysis_data <- prepare_analysis_data(data, config)

  # 5. Fit regression model
  model <- fit_regression_model(analysis_data, config)

  # 6. Calculate importance (all methods)
  importance <- calculate_all_importance(analysis_data, model, config)

  # 7. Calculate VIF
  vif_values <- calculate_vif(analysis_data, config)

  # 8. Optional: SHAP analysis
  if (config$enable_shap) {
    shap_results <- calculate_shap_importance(analysis_data, config)
  }

  # 9. Optional: Quadrant analysis
  if (config$enable_quadrant) {
    quadrant_results <- calculate_quadrant_analysis(importance, analysis_data, config)
  }

  # 10. Generate output
  output_path <- write_keydriver_output(results, config)

  return(results)
}
```

### 01_config.R - Configuration

**Key Functions:**
```r
load_keydriver_config(config_file)
  # Returns: list(settings, variables, segments, stated_importance)

get_setting(config, setting_name, default = NULL)
  # Safe setting retrieval with defaults

validate_config_structure(config)
  # Validates required sheets and columns
```

**Configuration Structure:**
```r
list(
  settings = list(
    analysis_name = "...",
    data_file = "...",
    output_file = "...",
    enable_shap = FALSE,
    enable_quadrant = FALSE,
    ...
  ),
  variables = data.frame(
    VariableName, Type, Label
  ),
  segments = data.frame(
    segment_name, segment_variable, segment_values
  ),
  stated_importance = data.frame(
    driver, stated_importance
  )
)
```

### 02_validation.R - Validation

**Key Functions:**
```r
validate_keydriver_config(config, data)
  # Validates config against data

validate_data(data, config)
  # Validates data quality

check_sample_size(n, k)
  # Ensures n >= max(30, 10*k)

check_variable_variance(data, vars)
  # Detects zero-variance variables

check_aliased_coefficients(model)
  # Detects perfect multicollinearity
```

**Sample Size Rule:**
```r
min_n <- max(30, 10 * n_drivers)
if (nrow(complete_data) < min_n) {
  stop(sprintf("Insufficient complete cases (%d). Need at least %d.",
               nrow(complete_data), min_n))
}
```

### 03_analysis.R - Statistical Analysis

**Key Functions:**
```r
fit_regression_model(data, config)
  # Fits weighted OLS regression

calculate_shapley_importance(data, outcome, drivers, weights)
  # Game-theoretic R² decomposition

calculate_relative_weights(data, outcome, drivers, weights)
  # Johnson (2000) orthogonalization method

calculate_beta_weights(data, outcome, drivers, weights)
  # Standardized regression coefficients

calculate_correlations(data, outcome, drivers, weights)
  # Zero-order correlations

calculate_vif(data, drivers)
  # Variance inflation factors

calculate_shap_importance(data, config)
  # XGBoost + TreeSHAP (when enabled)
```

### 04_output.R - Excel Output

**Key Functions:**
```r
write_keydriver_output(results, config)
  # Master output function

write_importance_summary(wb, results)
  # Importance Summary sheet

write_method_rankings(wb, results)
  # Method Rankings sheet

write_model_summary(wb, results)
  # Model Summary + VIF sheet

write_correlations(wb, results)
  # Correlation matrix sheet

write_charts(wb, results)
  # Shapley bar chart

write_readme(wb)
  # Methodology documentation
```

---

## API Reference

### Main Entry Point

```r
run_keydriver_analysis(
  config_file,           # Path to configuration Excel
  data_file = NULL,      # Optional: override data path
  output_file = NULL     # Optional: override output path
) -> list
```

**Returns:**
```r
list(
  config = list(...),
  data_summary = list(n = ..., drivers = ...),
  model = lm object,
  r_squared = numeric,
  adj_r_squared = numeric,
  vif = named numeric vector,
  importance = list(
    shapley = named numeric,
    relative_weights = named numeric,
    beta_weights = named numeric,
    beta_coefficients = named numeric (signed),
    correlations = named numeric (signed)
  ),
  rankings = data.frame(...),
  correlation_matrix = matrix,
  shap = list(...),      # If enabled
  quadrant = list(...),  # If enabled
  output_file = "path/to/output.xlsx"
)
```

### Configuration Functions

```r
load_keydriver_config(config_file) -> list
get_setting(config, name, default) -> value
```

### Validation Functions

```r
validate_keydriver_config(config, data) -> NULL (or error)
validate_data(data, config) -> NULL (or error)
check_sample_size(n, k) -> NULL (or error)
check_variable_variance(data, vars) -> NULL (or error)
```

### Analysis Functions

```r
fit_regression_model(data, config) -> lm object
calculate_shapley_importance(data, outcome, drivers, weights) -> numeric
calculate_relative_weights(data, outcome, drivers, weights) -> numeric
calculate_beta_weights(data, outcome, drivers, weights) -> numeric
calculate_correlations(data, outcome, drivers, weights) -> numeric
calculate_vif(data, drivers) -> numeric
calculate_shap_importance(data, config) -> list
```

### Output Functions

```r
write_keydriver_output(results, config) -> file_path
```

---

## Algorithm Implementations

### Shapley Value Decomposition

```r
calculate_shapley_importance <- function(data, outcome_var, driver_vars, weights) {

  k <- length(driver_vars)
  shapley_values <- numeric(k)
  names(shapley_values) <- driver_vars

  # Check driver limit
  if (k > 15) {
    stop("Too many drivers for exact Shapley (max 15)")
  }

  # For each driver
  for (i in seq_along(driver_vars)) {
    driver <- driver_vars[i]
    other_drivers <- setdiff(driver_vars, driver)

    # Generate all 2^(k-1) subsets
    subsets <- generate_all_subsets(other_drivers)

    marginal_contributions <- numeric(length(subsets))

    for (s in seq_along(subsets)) {
      subset <- subsets[[s]]

      # R² without driver
      if (length(subset) == 0) {
        r2_without <- 0
      } else {
        formula_without <- as.formula(
          paste(outcome_var, "~", paste(subset, collapse = "+"))
        )
        model_without <- lm(formula_without, data = data, weights = weights)
        r2_without <- summary(model_without)$r.squared
      }

      # R² with driver
      formula_with <- as.formula(
        paste(outcome_var, "~", paste(c(subset, driver), collapse = "+"))
      )
      model_with <- lm(formula_with, data = data, weights = weights)
      r2_with <- summary(model_with)$r.squared

      # Marginal contribution
      marginal_contributions[s] <- r2_with - r2_without
    }

    # Shapley value = weighted average of marginal contributions
    # Weight = |S|!(k-|S|-1)!/k!
    subset_sizes <- sapply(subsets, length)
    weights_shapley <- factorial(subset_sizes) * factorial(k - subset_sizes - 1) / factorial(k)
    shapley_values[driver] <- sum(weights_shapley * marginal_contributions)
  }

  # Convert to percentages
  shapley_pct <- 100 * shapley_values / sum(shapley_values)

  return(shapley_pct)
}
```

### Relative Weights (Johnson 2000)

```r
calculate_relative_weights <- function(data, outcome_var, driver_vars, weights) {

  # Extract and standardize
  Y <- scale(data[[outcome_var]])
  X <- scale(as.matrix(data[, driver_vars]))

  # Apply weights if provided
  if (!is.null(weights)) {
    sqrt_w <- sqrt(weights / sum(weights) * nrow(X))
    Y <- Y * sqrt_w
    X <- X * sqrt_w
  }

  # Step 1: SVD of X
  svd_X <- svd(X)

  # Step 2: Create orthogonal predictors
  # Z = U (left singular vectors)
  Z <- svd_X$u

  # Step 3: Transform matrix (V * D^-1)
  # Maps Z back to X space
  Lambda <- svd_X$v %*% diag(1/svd_X$d)

  # Step 4: Regress Y on Z
  beta_Z <- as.vector(t(Z) %*% Y / nrow(Z))

  # Step 5: Calculate relative weights
  # RW_j = sum over components of (lambda_ji * beta_Zi)^2
  relative_weights <- numeric(length(driver_vars))

  for (j in seq_along(driver_vars)) {
    rw <- sum((Lambda[j, ] * beta_Z)^2)
    relative_weights[j] <- rw
  }

  # Normalize to sum to R²
  Y_hat <- Z %*% beta_Z
  r_squared <- cor(as.vector(Y), as.vector(Y_hat))^2

  relative_weights <- relative_weights * r_squared / sum(relative_weights)

  # Convert to percentages
  rw_pct <- 100 * relative_weights / r_squared
  names(rw_pct) <- driver_vars

  return(rw_pct)
}
```

### VIF Calculation

```r
calculate_vif <- function(data, driver_vars) {

  vif_values <- numeric(length(driver_vars))
  names(vif_values) <- driver_vars

  for (i in seq_along(driver_vars)) {
    driver <- driver_vars[i]
    other_drivers <- setdiff(driver_vars, driver)

    # Regress this driver on all others
    formula <- as.formula(
      paste(driver, "~", paste(other_drivers, collapse = "+"))
    )
    model <- lm(formula, data = data)

    # VIF = 1 / (1 - R²)
    r_squared <- summary(model)$r.squared
    vif_values[driver] <- 1 / (1 - r_squared)
  }

  return(vif_values)
}
```

---

## SHAP Integration

### Dependencies

```r
# Required packages for SHAP
required_packages <- c("xgboost", "shapviz")
optional_packages <- c("ggplot2")  # For visualizations
```

### SHAP Calculation

```r
calculate_shap_importance <- function(data, config) {

  # Check packages
  if (!requireNamespace("xgboost", quietly = TRUE)) {
    stop("Package 'xgboost' required for SHAP analysis")
  }
  if (!requireNamespace("shapviz", quietly = TRUE)) {
    stop("Package 'shapviz' required for SHAP analysis")
  }

  # Prepare data
  outcome_var <- config$outcome_variable
  driver_vars <- config$driver_variables

  X <- as.matrix(data[, driver_vars])
  Y <- data[[outcome_var]]

  # Apply sample limit
  sample_size <- min(nrow(X), config$shap_sample_size %||% 1000)
  if (nrow(X) > sample_size) {
    idx <- sample(nrow(X), sample_size)
    X_sample <- X[idx, ]
    Y_sample <- Y[idx]
  } else {
    X_sample <- X
    Y_sample <- Y
  }

  # Prepare weights
  weights <- if (!is.null(config$weight_variable)) {
    data[[config$weight_variable]]
  } else {
    NULL
  }

  # Create DMatrix
  dtrain <- xgboost::xgb.DMatrix(
    data = X_sample,
    label = Y_sample,
    weight = weights[idx] %||% NULL
  )

  # XGBoost parameters
  params <- list(
    objective = "reg:squarederror",
    max_depth = config$max_depth %||% 6,
    eta = config$learning_rate %||% 0.1,
    subsample = 0.8,
    colsample_bytree = 0.8
  )

  # Train model
  model <- xgboost::xgb.train(
    params = params,
    data = dtrain,
    nrounds = config$n_trees %||% 100,
    verbose = 0
  )

  # Calculate SHAP values using shapviz
  shap_obj <- shapviz::shapviz(model, X_pred = X_sample)

  # Extract importance (mean |SHAP|)
  shap_importance <- colMeans(abs(shapviz::get_shap_values(shap_obj)))
  shap_pct <- 100 * shap_importance / sum(shap_importance)

  # Calculate interactions if requested
  interactions <- NULL
  if (config$include_interactions %||% FALSE) {
    interactions <- calculate_shap_interactions(model, X_sample)
  }

  return(list(
    importance = shap_pct,
    shap_values = shapviz::get_shap_values(shap_obj),
    shap_object = shap_obj,
    model = model,
    interactions = interactions
  ))
}
```

### SHAP Visualizations

```r
create_shap_plots <- function(shap_results) {

  shap_obj <- shap_results$shap_object

  plots <- list()

  # 1. Importance bar plot
  plots$importance <- shapviz::sv_importance(shap_obj, kind = "bar")

  # 2. Beeswarm plot
  plots$beeswarm <- shapviz::sv_importance(shap_obj, kind = "beeswarm")

  # 3. Waterfall plot (first observation)
  plots$waterfall <- shapviz::sv_waterfall(shap_obj, row_id = 1)

  # 4. Dependence plots for top drivers
  top_drivers <- names(sort(shap_results$importance, decreasing = TRUE))[1:3]
  plots$dependence <- lapply(top_drivers, function(v) {
    shapviz::sv_dependence(shap_obj, v = v)
  })
  names(plots$dependence) <- top_drivers

  return(plots)
}
```

---

## Extension Points

### Adding New Importance Methods

```r
# Example: Dominance Analysis
calculate_dominance_analysis <- function(data, outcome_var, driver_vars, weights) {

  # Implementation
  # ...

  return(dominance_pct)
}

# Register in calculate_all_importance()
importance$dominance <- calculate_dominance_analysis(
  data, outcome_var, driver_vars, weights
)
```

### Adding New Output Sheets

```r
# In 04_output.R
write_custom_sheet <- function(wb, results) {

  # Create sheet
  openxlsx::addWorksheet(wb, "Custom Analysis")

  # Write data
  openxlsx::writeData(wb, "Custom Analysis", custom_data)

  # Apply formatting
  # ...
}

# Register in write_keydriver_output()
write_custom_sheet(wb, results)
```

### Adding New Settings

```r
# 1. Document in 06_TEMPLATE_REFERENCE.md

# 2. Use in code with default
custom_setting <- get_setting(config, "custom_setting", default = FALSE)

# 3. Add validation if needed
if (!is.logical(custom_setting)) {
  warning("custom_setting should be TRUE/FALSE")
}
```

---

## Testing

### Test Files

```
tests/
└── keydriver/
    ├── test_shapley.R
    ├── test_relative_weights.R
    ├── test_validation.R
    └── test_data/
        ├── test_config.xlsx
        └── test_data.csv
```

### Running Tests

```r
source("tests/keydriver/test_shapley.R")
source("tests/keydriver/test_relative_weights.R")
source("tests/keydriver/test_validation.R")
```

### Test Coverage

**Current:** ~20% automated

**Recommended Unit Tests:**
- Shapley values sum to R²
- Relative weights sum to 100%
- VIF calculation correctness
- Sample size validation
- Zero variance detection
- Aliased coefficient detection

---

## Performance

### Execution Times

| Drivers | Sample Size | Time |
|---------|-------------|------|
| 5 | 500 | 1-2 sec |
| 10 | 1,000 | 5-10 sec |
| 15 | 5,000 | 30-60 sec |
| 15 + SHAP | 5,000 | 2-3 min |

### Bottlenecks

**Shapley Calculation:**
- O(2^k) models
- Practical limit: k ≤ 15

**SHAP Calculation:**
- XGBoost training time
- TreeSHAP calculation time
- Sample size impact

### Optimization Opportunities

```r
# Parallel Shapley
library(parallel)
shapley_values <- mclapply(driver_vars, function(driver) {
  calculate_single_shapley(data, outcome_var, driver, other_drivers, weights)
}, mc.cores = 4)

# Approximate Shapley (for k > 15)
# Monte Carlo sampling of permutations
```

---

## Known Issues

### Resolved Issues

**ISSUE-001: Relative Weights Bug** (v2.0)
- Status: RESOLVED
- Description: Previous implementation didn't match Johnson (2000)
- Fix: Corrected eigendecomposition and component allocation

**ISSUE-002: Aliased Coefficients Crash** (v2.0)
- Status: RESOLVED
- Description: Perfect multicollinearity caused silent failures
- Fix: Added detection and informative error messages

### Current Limitations

1. **Shapley Limit**: Maximum 15 drivers for exact computation
2. **SHAP Dependencies**: Requires xgboost and shapviz packages
3. **Weighted Shapley**: Minor inconsistency in subset model weighting
4. **Weighted Beta**: Uses unweighted SD for normalization
5. **Listwise Deletion**: No imputation option

### Weighting Notes

| Method | Weighting Status |
|--------|------------------|
| Correlations | Fully correct |
| Regression | Fully correct |
| Relative Weights | Fully correct (RECOMMENDED) |
| Beta Weights | Minor inconsistency |
| Shapley | Minor inconsistency |
| SHAP | Fully correct (XGBoost weights) |

**Recommendation:** When using weights, prioritize Relative Weights or SHAP.

---

## Code Style

### Function Documentation

```r
#' Calculate Shapley Value Importance
#'
#' Uses game-theoretic approach to fairly allocate R² among drivers.
#'
#' @param data Data frame with outcome and drivers
#' @param outcome_var Name of outcome variable
#' @param driver_vars Vector of driver variable names
#' @param weights Optional survey weights
#' @return Named numeric vector of importance percentages
#'
#' @export
calculate_shapley_importance <- function(data, outcome_var, driver_vars, weights = NULL) {
  ...
}
```

### Error Handling

```r
# Validate inputs
if (length(driver_vars) > 15) {
  stop("Too many drivers (", length(driver_vars),
       ") for exact Shapley. Maximum is 15.")
}

# Informative warnings
if (any(vif_values > 10)) {
  warning("High VIF detected for: ",
          paste(names(vif_values[vif_values > 10]), collapse = ", "))
}
```

---

## Version Control

### Branch Strategy

- `main` - Production code
- `develop` - Integration
- `feature/*` - New features
- `bugfix/*` - Bug fixes

### Commit Messages

```
feat: Add SHAP analysis capability
fix: Correct relative weights calculation
docs: Update technical documentation
test: Add unit tests for VIF calculation
refactor: Extract common validation functions
```

---

## Future Development

### Planned Features

**v11.0:**
- Approximate Shapley for k > 15 (Monte Carlo)
- Bootstrapped confidence intervals
- Interaction effects in linear model
- Non-linear transformations (polynomial, spline)

**v12.0:**
- Hierarchical driver models
- Time-series driver analysis
- Automated driver selection
- PowerPoint export

### Technical Debt

1. Increase test coverage to 80%
2. Extract shared code to /shared/
3. Implement approximate Shapley
4. Add confidence intervals for all methods
5. Improve weighted analysis consistency
