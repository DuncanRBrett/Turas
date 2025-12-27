# KeyDriver Analysis Module - Technical Documentation

**Version:** 1.0 (Turas v10.0)
**Last Updated:** December 6, 2025
**Module Status:** ✅ Production Ready
**Target Audience:** Developers, Technical Maintainers, Data Scientists

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Architecture](#2-architecture)
3. [Statistical Methods](#3-statistical-methods)
4. [Core Components](#4-core-components)
5. [API Reference](#5-api-reference)
6. [Extension Points](#6-extension-points)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Module Overview

### 1.1 Purpose

The KeyDriver module performs driver analysis using multiple regression to identify which factors (drivers) have the greatest impact on key outcome metrics (e.g., satisfaction, loyalty, NPS). It provides four complementary importance measures to guide strategic decisions.

### 1.2 Key Features

**Four Importance Methods:**
1. **Shapley Value Decomposition** - Game-theoretic fair attribution
2. **Relative Weights (Johnson's Method)** - Handles multicollinearity
3. **Standardized Coefficients (Beta Weights)** - Direct effect sizes
4. **Zero-Order Correlations** - Bivariate relationships

**Analysis Capabilities:**
- Multiple regression framework
- Weighted analysis support
- Multicollinearity diagnostics (VIF)
- Model fit statistics (R², adjusted R²)
- Automatic variable transformation
- Excel output with charts

### 1.3 Input/Output

**Input:**
- **Survey Data** (CSV/Excel): Respondent-level data
- **Configuration** (Excel): Outcome and driver variable specifications

**Output:**
- **Excel Workbook** with:
  - Importance scores (all 4 methods)
  - Model fit statistics
  - VIF diagnostics
  - Correlation matrix
  - Importance ranking charts

**Typical Performance:**
- 1,000 respondents, 10 drivers: 5-10 seconds
- 10,000 respondents, 20 drivers: 15-30 seconds

---

## 2. Architecture

### 2.1 File Structure

```
modules/keydriver/R/
├── 00_main.R           # Main orchestration (~350 lines)
├── 01_config.R         # Configuration loading (~200 lines)
├── 02_validation.R     # Data validation (~250 lines)
├── 03_analysis.R       # Statistical analysis (~500 lines)
└── 04_output.R         # Excel output (~200 lines)
```

**Total:** ~1,100 lines

### 2.2 Data Flow

```
CONFIG → DATA → VALIDATION → REGRESSION → IMPORTANCE → OUTPUT
   ↓        ↓         ↓            ↓            ↓          ↓
 Excel  Variables  VIF Check   Estimate   4 Methods   Excel
                                Model     Calculate   Report
```

---

## 3. Statistical Methods

### 3.1 Multiple Regression

**Framework:**
```
Y = β₀ + β₁X₁ + β₂X₂ + ... + βₖXₖ + ε

Where:
  Y = Outcome variable (e.g., Overall Satisfaction)
  Xᵢ = Driver variables (e.g., Product Quality, Service Quality)
  βᵢ = Regression coefficients
  ε = Error term
```

**Estimation:**
```r
# OLS estimation
model <- lm(Outcome ~ Driver1 + Driver2 + Driver3, data = data, weights = weight)

# Extract coefficients
coefficients <- coef(model)

# Model fit
r_squared <- summary(model)$r.squared
adj_r_squared <- summary(model)$adj.r.squared
```

---

### 3.2 Importance Method 1: Shapley Value Decomposition

**Concept:**
- Game-theoretic approach
- Each driver's "fair share" of R²
- Considers all possible driver combinations

**Algorithm:**
```r
calculate_shapley_importance <- function(data, outcome_var, driver_vars, weights) {

  shapley_values <- numeric(length(driver_vars))
  names(shapley_values) <- driver_vars

  # For each driver
  for (i in seq_along(driver_vars)) {
    driver <- driver_vars[i]
    other_drivers <- setdiff(driver_vars, driver)

    # Generate all subsets of other drivers
    subsets <- generate_all_subsets(other_drivers)

    # For each subset
    marginal_contributions <- numeric()

    for (subset in subsets) {

      # R² with subset
      if (length(subset) == 0) {
        r2_without <- 0
      } else {
        model_without <- lm(
          as.formula(paste(outcome_var, "~", paste(subset, collapse = "+"))),
          data = data,
          weights = weights
        )
        r2_without <- summary(model_without)$r.squared
      }

      # R² with subset + driver
      model_with <- lm(
        as.formula(paste(outcome_var, "~", paste(c(subset, driver), collapse = "+"))),
        data = data,
        weights = weights
      )
      r2_with <- summary(model_with)$r.squared

      # Marginal contribution
      marginal <- r2_with - r2_without

      marginal_contributions <- c(marginal_contributions, marginal)
    }

    # Shapley value = average marginal contribution
    shapley_values[driver] <- mean(marginal_contributions)
  }

  # Convert to percentages
  shapley_pct <- 100 * shapley_values / sum(shapley_values)

  return(shapley_pct)
}
```

**Advantages:**
- ✅ Theoretically sound (axiomatically justified)
- ✅ Handles multicollinearity well
- ✅ Fair attribution across all drivers

**Disadvantages:**
- ❌ Computationally expensive (2^k subsets)
- ❌ Slow for many drivers (k > 15)

---

### 3.3 Importance Method 2: Relative Weights (Johnson's Method)

**Concept:**
- Decompose R² into driver-specific contributions
- Orthogonalizes drivers to remove multicollinearity
- Weighted by correlation with outcome

**Algorithm:**
```r
calculate_relative_weights <- function(data, outcome_var, driver_vars, weights) {

  # Extract variables
  Y <- data[[outcome_var]]
  X <- as.matrix(data[, driver_vars])

  # Apply weights if provided
  if (!is.null(weights)) {
    sqrt_w <- sqrt(weights)
    Y <- Y * sqrt_w
    X <- X * sqrt_w
  }

  # Step 1: Orthogonalize X via PCA
  # X = Z * Λ, where Z is orthogonal
  pca <- prcomp(X, center = TRUE, scale. = TRUE)
  Z <- pca$x  # Orthogonal components
  Λ <- pca$rotation  # Transformation matrix

  # Step 2: Regress Y on Z
  # β_Z = (Z'Z)⁻¹ Z'Y
  beta_z <- solve(t(Z) %*% Z) %*% t(Z) %*% Y

  # Step 3: Transform back to X space
  # β_X = Λ * β_Z
  beta_x <- Λ %*% beta_z

  # Step 4: Calculate relative weights
  # RW_i = Σ_j (λ_ij * β_zj)² * (Y'Y / Y'Ŷ)
  # Where Ŷ = X * β_X

  Y_hat <- X %*% beta_x
  r_squared <- cor(Y, Y_hat)^2

  relative_weights <- numeric(length(driver_vars))

  for (i in seq_along(driver_vars)) {
    rw <- sum((Λ[i, ] * beta_z)^2)
    relative_weights[i] <- rw
  }

  # Normalize to sum to R²
  relative_weights <- relative_weights * r_squared / sum(relative_weights)

  # Convert to percentages
  rw_pct <- 100 * relative_weights / r_squared

  names(rw_pct) <- driver_vars

  return(rw_pct)
}
```

**Advantages:**
- ✅ Fast (single PCA + regression)
- ✅ Handles multicollinearity
- ✅ Always sums to 100%

**Disadvantages:**
- ❌ Less intuitive interpretation
- ❌ Sensitive to driver selection

---

### 3.4 Importance Method 3: Standardized Coefficients (Beta Weights)

**Concept:**
- Standardize all variables (mean=0, SD=1)
- Regression coefficients become beta weights
- Directly interpretable as effect sizes

**Algorithm:**
```r
calculate_beta_weights <- function(data, outcome_var, driver_vars, weights) {

  # Standardize all variables
  data_std <- data
  data_std[[outcome_var]] <- scale(data[[outcome_var]])

  for (var in driver_vars) {
    data_std[[var]] <- scale(data[[var]])
  }

  # Regression on standardized data
  formula <- as.formula(paste(outcome_var, "~", paste(driver_vars, collapse = "+")))

  model <- lm(formula, data = data_std, weights = weights)

  # Extract standardized coefficients
  beta_weights <- coef(model)[-1]  # Exclude intercept

  # Convert to importance percentages
  # Use absolute values (direction doesn't matter for importance)
  importance <- abs(beta_weights)
  importance_pct <- 100 * importance / sum(importance)

  return(importance_pct)
}
```

**Advantages:**
- ✅ Simple and fast
- ✅ Direct interpretation (effect sizes)
- ✅ Shows direction of effect

**Disadvantages:**
- ❌ Affected by multicollinearity
- ❌ Unstable with correlated drivers

---

### 3.5 Importance Method 4: Zero-Order Correlations

**Concept:**
- Bivariate correlation between each driver and outcome
- Ignores other drivers
- Simplest measure

**Algorithm:**
```r
calculate_correlations <- function(data, outcome_var, driver_vars, weights) {

  correlations <- numeric(length(driver_vars))
  names(correlations) <- driver_vars

  Y <- data[[outcome_var]]

  for (driver in driver_vars) {
    X <- data[[driver]]

    # Weighted correlation
    if (!is.null(weights)) {
      cor_val <- cov.wt(cbind(Y, X), wt = weights, cor = TRUE)$cor[1, 2]
    } else {
      cor_val <- cor(Y, X, use = "complete.obs")
    }

    correlations[driver] <- cor_val
  }

  # Convert to importance percentages
  # Use squared correlations (proportion of variance)
  r_squared <- correlations^2
  importance_pct <- 100 * r_squared / sum(r_squared)

  return(importance_pct)
}
```

**Advantages:**
- ✅ Very fast
- ✅ Easy to interpret
- ✅ Shows bivariate relationships

**Disadvantages:**
- ❌ Ignores multicollinearity
- ❌ Doesn't control for other drivers
- ❌ Can overestimate importance of correlated drivers

---

### 3.6 Variance Inflation Factor (VIF)

**Purpose:** Diagnose multicollinearity

**Formula:**
```
VIF_i = 1 / (1 - R²_i)

Where:
  R²_i = R² from regressing X_i on all other X variables
```

**Implementation:**
```r
calculate_vif <- function(data, driver_vars) {

  vif_values <- numeric(length(driver_vars))
  names(vif_values) <- driver_vars

  for (i in seq_along(driver_vars)) {
    driver <- driver_vars[i]
    other_drivers <- setdiff(driver_vars, driver)

    # Regress this driver on other drivers
    formula <- as.formula(paste(driver, "~", paste(other_drivers, collapse = "+")))
    model <- lm(formula, data = data)

    # VIF = 1 / (1 - R²)
    r_squared <- summary(model)$r.squared
    vif <- 1 / (1 - r_squared)

    vif_values[driver] <- vif
  }

  return(vif_values)
}
```

**Interpretation:**
- **VIF < 5:** No multicollinearity concern
- **VIF 5-10:** Moderate multicollinearity
- **VIF > 10:** High multicollinearity (consider removing variable)

---

## 4. Core Components

### 4.1 Configuration (01_config.R)

**Structure:**
```r
# Excel: keydriver_config.xlsx
# Sheet: Settings
analysis_name       # Project name
min_sample_size     # Minimum n required (default: 100)
weight_variable     # Weight column (optional)

# Sheet: Variables
variable_name   | variable_type | variable_label
Overall_Sat     | outcome       | Overall Satisfaction
Product_Qual    | driver        | Product Quality
Service_Qual    | driver        | Service Quality
Price_Value     | driver        | Price/Value Ratio
```

**Validation:**
```r
validate_keydriver_config <- function(config) {
  # Check exactly one outcome variable
  # Check at least 2 driver variables
  # Check max 20 drivers (for Shapley performance)
  # Validate variable names exist in data
}
```

---

### 4.2 Analysis (03_analysis.R)

**Main Function:**
```r
run_keydriver_analysis <- function(data, config) {

  # 1. Extract variables
  outcome_var <- config$outcome_variable
  driver_vars <- config$driver_variables
  weights <- if (!is.null(config$weight_variable)) data[[config$weight_variable]] else NULL

  # 2. Validate sample size
  n <- nrow(data)
  if (n < config$min_sample_size) {
    stop(sprintf("Sample size (%d) below minimum (%d)", n, config$min_sample_size))
  }

  # 3. Calculate VIF
  vif_values <- calculate_vif(data, driver_vars)

  # Warn if high multicollinearity
  high_vif <- vif_values[vif_values > 10]
  if (length(high_vif) > 0) {
    warning(sprintf(
      "High multicollinearity detected: %s",
      paste(names(high_vif), collapse = ", ")
    ))
  }

  # 4. Fit regression model
  formula <- as.formula(paste(outcome_var, "~", paste(driver_vars, collapse = "+")))
  model <- lm(formula, data = data, weights = weights)

  # 5. Calculate importance (all 4 methods)
  shapley <- calculate_shapley_importance(data, outcome_var, driver_vars, weights)
  relative_weights <- calculate_relative_weights(data, outcome_var, driver_vars, weights)
  beta_weights <- calculate_beta_weights(data, outcome_var, driver_vars, weights)
  correlations <- calculate_correlations(data, outcome_var, driver_vars, weights)

  # 6. Compile results
  results <- list(
    model = model,
    r_squared = summary(model)$r.squared,
    adj_r_squared = summary(model)$adj.r.squared,
    vif = vif_values,
    importance = list(
      shapley = shapley,
      relative_weights = relative_weights,
      beta_weights = beta_weights,
      correlations = correlations
    )
  )

  return(results)
}
```

---

## 5. API Reference

### 5.1 Main Entry Point

```r
run_keydriver_analysis(
  config_file         # Path to Excel configuration
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
    correlations = named numeric
  ),
  correlation_matrix = matrix,
  output_file = "path/to/output.xlsx"
)
```

### 5.2 Component Functions

**Configuration:**
```r
load_keydriver_config(config_file) -> list
validate_keydriver_config(config, data) -> NULL (or error)
```

**Analysis:**
```r
calculate_shapley_importance(data, outcome, drivers, weights) -> numeric
calculate_relative_weights(data, outcome, drivers, weights) -> numeric
calculate_beta_weights(data, outcome, drivers, weights) -> numeric
calculate_correlations(data, outcome, drivers, weights) -> numeric
calculate_vif(data, drivers) -> numeric
```

**Output:**
```r
write_keydriver_output(results, output_path) -> NULL
```

---

## 6. Extension Points

### 6.1 Adding New Importance Methods

**Example: Dominance Analysis**

```r
calculate_dominance_analysis <- function(data, outcome_var, driver_vars, weights) {

  # Dominance analysis compares R² contributions
  # Across all model subsets

  n_drivers <- length(driver_vars)
  dominance <- matrix(0, nrow = n_drivers, ncol = n_drivers)

  # For each pair of drivers
  for (i in 1:n_drivers) {
    for (j in 1:n_drivers) {
      if (i != j) {
        # Compare across all subsets
        # Count how often driver i dominates driver j
        # (i.e., i contributes more to R² than j)
      }
    }
  }

  # Calculate dominance scores
  return(dominance_scores)
}
```

### 6.2 Categorical Driver Handling

```r
# Automatic dummy coding for categorical drivers

handle_categorical_drivers <- function(data, driver_vars) {

  for (var in driver_vars) {
    if (is.factor(data[[var]]) || is.character(data[[var]])) {

      # Create dummy variables
      dummies <- model.matrix(~ data[[var]] - 1)
      colnames(dummies) <- paste0(var, "_", levels(factor(data[[var]])))

      # Add to data
      data <- cbind(data, dummies)

      # Remove original
      data[[var]] <- NULL
    }
  }

  return(data)
}
```

---

## 7. Troubleshooting

### Issue: "Shapley calculation very slow"

**Cause:** Too many drivers (>15)

**Solution:**
```r
# Use relative weights instead
# Or sample drivers
# Or use approximate Shapley (Monte Carlo sampling)
```

### Issue: "High VIF values"

**Cause:** Multicollinearity among drivers

**Solution:**
```r
# Remove highly correlated drivers
# Use PCA to create orthogonal components
# Focus on Shapley/Relative Weights (handle collinearity better)
# Avoid using Beta Weights
```

### Issue: "Different methods give different rankings"

**Cause:** This is expected - methods measure different aspects

**Solution:**
```r
# Use all 4 methods together
# Shapley = most robust
# Relative Weights = practical compromise
# Beta Weights = if no multicollinearity
# Correlations = descriptive only
```

### Issue: "Negative importance scores"

**Cause:** Should not happen (all methods use absolute values or squares)

**Solution:**
```r
# Check calculation implementation
# Ensure using abs() or squaring appropriately
```

---

**Document Version:** 1.0
**Last Updated:** December 6, 2025
**Maintained By:** Turas Development Team

---

**End of KeyDriver Module Technical Documentation**
