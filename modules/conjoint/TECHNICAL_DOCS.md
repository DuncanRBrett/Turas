# Conjoint Analysis Module - Technical Documentation

**Version:** 1.0 (Turas v10.0)
**Last Updated:** December 6, 2025
**Module Status:** ✅ Production Ready
**Target Audience:** Developers, Technical Maintainers, Market Researchers

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Architecture](#2-architecture)
3. [Core Components](#3-core-components)
4. [Statistical Methods](#4-statistical-methods)
5. [API Reference](#5-api-reference)
6. [Extension Points](#6-extension-points)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Module Overview

### 1.1 Purpose

The Conjoint Analysis module estimates consumer preferences for product features through choice-based or rating-based experiments. It calculates part-worth utilities and attribute importance scores to guide product development and pricing decisions.

### 1.2 Key Features

**Analysis Types:**
- **Rating-Based Conjoint:** Regression on profile ratings
- **Choice-Based Conjoint:** Multinomial logit modeling
- **Best-Worst Scaling:** Maximum difference scaling

**Estimation Methods:**
- OLS regression (rating-based)
- Multinomial logit (choice-based)
- Conditional logit with `mlogit` package
- Hierarchical Bayes (advanced, optional)

**Output & Simulation:**
- Part-worth utilities (individual and aggregate)
- Attribute importance scores
- Product preference simulator
- Market share prediction
- NONE option handling
- Interaction effects (optional)

### 1.3 Input/Output

**Input:**
- **Choice Data** (CSV/Excel): Experiment responses
- **Configuration** (Excel): Attributes, levels, analysis settings

**Output:**
- **Excel Workbook** with:
  - Part-worth utilities
  - Attribute importance
  - Model fit statistics
  - Preference simulator
  - Market predictions

---

## 2. Architecture

### 2.1 File Structure

```
modules/conjoint/R/
├── 00_main.R              # Main orchestration (~400 lines)
├── 01_config.R            # Configuration loading (~350 lines)
├── 02_data.R              # Data loading & validation (~450 lines)
├── 03_estimation.R        # Model estimation (~800 lines)
├── 04_utilities.R         # Utility calculations (~600 lines)
├── 05_simulator.R         # Product simulator (~500 lines)
├── 06_interactions.R      # Interaction effects (~400 lines)
├── 07_output.R            # Excel output (~900 lines)
├── 08_market_simulator.R  # Market simulator (~650 lines)
├── 09_none_handling.R     # NONE option logic (~350 lines)
├── 10_best_worst.R        # BWS scaling (~400 lines)
├── 11_hierarchical_bayes.R# HB estimation (~500 lines)
└── 99_helpers.R           # Utilities (~500 lines)
```

**Total:** ~5,800 lines

### 2.2 Data Flow

```
CONFIG → DATA → ESTIMATION → UTILITIES → SIMULATION → OUTPUT
   ↓        ↓         ↓            ↓           ↓          ↓
 Excel   Choice   Regression   Part-worths  Predict   Excel
         Data      /Logit      Importance   Shares   Report
```

---

## 3. Core Components

### 3.1 Configuration (01_config.R)

**Structure:**
```r
# Sheet: Settings
analysis_type        # "rating" or "choice"
estimation_method    # "regression" or "logit"
include_interactions # TRUE/FALSE
none_option          # TRUE/FALSE if NONE is an option

# Sheet: Attributes
attribute_name   | attribute_levels
Brand            | "Brand A, Brand B, Brand C"
Price            | "10, 15, 20, 25"
Quality          | "Standard, Premium"
```

### 3.2 Estimation (03_estimation.R)

**Rating-Based (OLS Regression):**
```r
estimate_rating_based <- function(data, config) {
  # Effects coding for categorical attributes
  # Linear regression: Rating ~ Brand + Price + Quality

  # Create design matrix with effects coding
  X <- create_effects_coded_matrix(data, config$attributes)

  # OLS regression
  model <- lm(Rating ~ ., data = X)

  # Extract coefficients as part-worths
  coefficients <- coef(model)

  return(list(
    model = model,
    part_worths = coefficients,
    r_squared = summary(model)$r.squared,
    residuals = residuals(model)
  ))
}
```

**Choice-Based (Multinomial Logit):**
```r
estimate_choice_based <- function(data, config) {
  library(mlogit)

  # Prepare data in mlogit format
  data_mlogit <- mlogit.data(
    data,
    choice = "chosen",
    shape = "long",
    alt.var = "alternative"
  )

  # Estimate conditional logit
  model <- mlogit(
    chosen ~ Brand + Price + Quality | 0,  # | 0 = no alternative-specific constants
    data = data_mlogit
  )

  # Extract utilities
  coefficients <- coef(model)

  return(list(
    model = model,
    part_worths = coefficients,
    log_likelihood = logLik(model),
    aic = AIC(model)
  ))
}
```

### 3.3 Utilities Calculation (04_utilities.R)

**Part-Worth Utilities:**
- Utility of each attribute level
- Scale: Relative to omitted level (effects coding)

**Attribute Importance:**
```r
calculate_importance <- function(part_worths, attributes) {

  importance <- numeric()

  for (attr in attributes) {
    # Get part-worths for this attribute's levels
    attr_utilities <- part_worths[grepl(attr, names(part_worths))]

    # Range of utilities for this attribute
    range_attr <- max(attr_utilities) - min(attr_utilities)

    importance[attr] <- range_attr
  }

  # Convert to percentages
  importance_pct <- 100 * importance / sum(importance)

  return(importance_pct)
}
```

### 3.4 Market Simulator (05_simulator.R, 08_market_simulator.R)

**Product Preference:**
```r
predict_preference <- function(product_profile, part_worths) {

  # Calculate total utility for product
  total_utility <- sum(part_worths[product_profile])

  # For choice models, convert to probability
  # Using multinomial logit formula

  return(total_utility)
}
```

**Market Share Prediction:**
```r
predict_market_share <- function(products, part_worths) {

  # Calculate utilities for all products
  utilities <- sapply(products, function(p) {
    predict_preference(p, part_worths)
  })

  # Logit choice probabilities
  exp_utilities <- exp(utilities)
  shares <- exp_utilities / sum(exp_utilities)

  return(shares)
}
```

---

## 4. Statistical Methods

### 4.1 Effects Coding

**Why Effects Coding:**
- Centers part-worths around zero
- Omitted level = negative sum of other levels
- More intuitive interpretation than dummy coding

**Example:**
```
Brand: A, B, C

Effects coding:
  Brand_A: 1 if A, -1 if C, 0 otherwise
  Brand_B: 1 if B, -1 if C, 0 otherwise
  Brand_C: (omitted, calculated as -(A + B))
```

### 4.2 Multinomial Logit Model

**Formula:**
```
P(choose product j) = exp(U_j) / Σ exp(U_k)

Where:
  U_j = utility of product j
      = β₁·Brand_j + β₂·Price_j + β₃·Quality_j + ...
```

**Properties:**
- IIA assumption (Independence of Irrelevant Alternatives)
- Substitution patterns proportional to shares
- Random utility maximization framework

### 4.3 Model Fit Statistics

**R² (Rating-Based):**
```r
# Proportion of variance explained
R² = 1 - (SS_residual / SS_total)
```

**Log-Likelihood (Choice-Based):**
```r
# Maximum log-likelihood value
# Higher (less negative) = better fit
```

**AIC/BIC:**
```r
# Akaike/Bayesian Information Criterion
# Lower = better (penalizes complexity)
AIC = -2·log(L) + 2·k
BIC = -2·log(L) + k·log(n)
```

---

## 5. API Reference

### 5.1 Main Entry Point

```r
run_conjoint_analysis(
  config_file,                  # Path to Excel config
  data_file = NULL,             # Path to data (or in config)
  output_file = NULL,           # Path to output (or in config)
  include_simulator = TRUE      # Include market simulator sheet
) -> list
```

**Returns:**
```r
list(
  config = list(...),
  data = data.frame(...),
  estimation = list(
    model = lm/mlogit object,
    part_worths = numeric(...),
    importance = numeric(...),
    fit_stats = list(...)
  ),
  simulator = list(...),
  output_file = "path/to/output.xlsx"
)
```

### 5.2 Component Functions

**Configuration:**
```r
load_conjoint_config(config_file) -> list
validate_conjoint_config(config) -> list
```

**Data:**
```r
load_conjoint_data(data_file, config) -> data.frame
prepare_mlogit_data(data, config) -> mlogit.data
```

**Estimation:**
```r
estimate_rating_based(data, config) -> list
estimate_choice_based(data, config) -> list
estimate_hierarchical_bayes(data, config) -> list
```

**Utilities:**
```r
extract_part_worths(model, config) -> numeric
calculate_importance(part_worths, attributes) -> numeric
```

**Simulation:**
```r
predict_preference(product, part_worths) -> numeric
predict_market_share(products, part_worths) -> numeric
create_simulator_table(part_worths, config) -> data.frame
```

---

## 6. Extension Points

### 6.1 Adding Interaction Effects

```r
# In 06_interactions.R

estimate_with_interactions <- function(data, config) {

  # Define interactions
  interactions <- config$interactions  # e.g., "Brand:Price"

  # Create interaction terms
  X <- create_effects_coded_matrix(data, config$attributes)

  for (interaction in interactions) {
    vars <- strsplit(interaction, ":")[[1]]
    X[[interaction]] <- X[[vars[1]]] * X[[vars[2]]]
  }

  # Estimate model with interactions
  model <- lm(Rating ~ ., data = X)

  return(model)
}
```

### 6.2 Hierarchical Bayes Estimation

```r
# In 11_hierarchical_bayes.R

estimate_hb <- function(data, config, mcmc_iterations = 10000) {

  # Bayesian estimation with individual-level heterogeneity
  # Uses MCMC sampling

  # Prior distributions
  # Individual utilities ~ Multivariate Normal(μ, Σ)
  # Hyperparameters: μ ~ Normal, Σ ~ Inverse-Wishart

  # MCMC sampling...

  return(list(
    individual_utilities = matrix(...),
    population_mean = numeric(...),
    population_covariance = matrix(...)
  ))
}
```

---

## 7. Troubleshooting

### Issue: "mlogit convergence failure"

**Cause:** Collinearity, too many parameters, separation

**Solution:**
```r
# Reduce attribute levels
# Check for perfect predictors
# Try different starting values
# Simplify model (remove interactions)
```

### Issue: "Negative importance scores"

**Cause:** Effects coding artifact

**Solution:**
```r
# Use absolute range for importance calculation
# Or use dummy coding instead
```

### Issue: "Market shares sum to >100%"

**Cause:** Incorrect probability calculation

**Solution:**
```r
# Ensure using exp(utilities) and proper normalization
# Check for NONE option handling
```

---

**Document Version:** 1.0
**Last Updated:** December 6, 2025
**Maintained By:** Turas Development Team

---

**End of Conjoint Module Technical Documentation**
