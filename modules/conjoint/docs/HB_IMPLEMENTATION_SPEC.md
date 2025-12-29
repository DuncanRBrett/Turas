# Hierarchical Bayes Implementation Specification

**Module:** Conjoint Analysis
**Feature:** Hierarchical Bayes (HB) Estimation
**Status:** Phase 2 - Not Yet Implemented
**Version:** 1.0.0
**Date:** 2025-12

---

## Executive Summary

This document specifies the implementation requirements for adding Hierarchical Bayes (HB) estimation to the Turas Conjoint Analysis module. HB provides individual-level part-worth utilities, enabling preference heterogeneity analysis and respondent-level predictions.

### Current State

| Component | Status | Location |
|-----------|--------|----------|
| Aggregate estimation (mlogit) | ✅ Implemented | `R/03_estimation.R` |
| Aggregate estimation (clogit) | ✅ Implemented | `R/03_estimation.R` |
| Convergence diagnostics | ✅ Implemented | `modules/shared/lib/hb_diagnostics.R` |
| HB estimation | ❌ Placeholder | `R/11_hierarchical_bayes.R` |
| Individual utilities | ❌ Not implemented | - |

---

## 1. Business Requirements

### 1.1 What HB Provides

| Capability | Aggregate Methods | HB Methods |
|------------|------------------|------------|
| Population-level utilities | ✅ Yes | ✅ Yes |
| Individual-level utilities | ❌ No | ✅ Yes |
| Preference heterogeneity | ❌ No | ✅ Yes |
| Latent class discovery | ❌ No | ✅ Yes |
| Small sample stability | ⚠️ Limited | ✅ Better |
| Respondent-level predictions | ❌ No | ✅ Yes |

### 1.2 When HB is Needed

- Large samples (200+ respondents) where heterogeneity matters
- Need to predict individual respondent choices
- Want to discover preference-based market segments
- Academic/research contexts requiring individual-level analysis
- Product customization based on individual preferences

### 1.3 When Aggregate Methods Suffice

- General market-level insights
- Small to medium samples (<100 respondents)
- Quick turnaround analyses
- Pricing and product optimization decisions
- Most commercial conjoint applications

---

## 2. Technical Specification

### 2.1 Recommended Package: bayesm

The `bayesm` package is the recommended foundation for HB implementation.

**Why bayesm:**
- Industry-standard for marketing research
- Well-documented with academic backing
- Native support for hierarchical multinomial logit
- Robust MCMC implementation
- Active maintenance

**Key Function:** `bayesm::rhierMnlRwMixture`

```r
# Conceptual usage
result <- bayesm::rhierMnlRwMixture(
  Data = list(
    lgtdata = lgtdata,  # List of respondent choice data
    Z = Z               # Optional: respondent covariates
  ),
  Prior = list(
    ncomp = 1           # Number of mixture components
  ),
  Mcmc = list(
    R = 10000,          # Total iterations
    keep = 10           # Thinning interval
  )
)
```

### 2.2 Alternative Package: RSGHB

RSGHB can be used as a fallback or alternative.

**Pros:**
- Designed specifically for choice modeling
- Good documentation for conjoint
- Flexible model specification

**Cons:**
- Less widely used than bayesm
- Different API patterns

### 2.3 Data Structure Requirements

#### Input Format (bayesm)

```r
# lgtdata: List of length n_respondents
# Each element contains:
lgtdata[[i]] <- list(
  y = choice_vector,      # Integer: which alternative chosen (1, 2, 3, ...)
  X = design_matrix       # Matrix: alternatives x parameters
)
```

#### Current Turas Format

```r
# From load_conjoint_data():
data_list <- list(
  data = df,              # Long-format data frame
  n_respondents = n,
  n_choice_sets = m,
  n_alternatives = k,
  attributes = attr_info
)
```

#### Required Transformation Function

```r
#' Convert Turas data to bayesm format
#'
#' @param data_list Turas data list from load_conjoint_data()
#' @param config Configuration object
#' @return List in bayesm lgtdata format
prepare_bayesm_data <- function(data_list, config) {
  # Implementation needed:
  # 1. Split data by respondent

  # 2. Create design matrix for each choice set
  # 3. Extract choice indicators
  # 4. Return lgtdata list structure
}
```

### 2.4 MCMC Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `mcmc_iterations` | 10,000 | Total MCMC iterations |
| `burn_in` | 2,000 | Iterations to discard |
| `thin` | 10 | Keep every Nth draw |
| `n_chains` | 1 | Number of parallel chains |

**Effective samples:** `(mcmc_iterations - burn_in) / thin = 800`

Recommendations:
- Minimum 400 effective samples for reliable inference
- Increase iterations if R-hat > 1.1 or ESS < 100

### 2.5 Convergence Diagnostics

Use the shared diagnostics module: `modules/shared/lib/hb_diagnostics.R`

```r
# After HB estimation
diagnostics <- check_hb_convergence(
  mcmc_draws = hb_result$betadraw,
  verbose = TRUE
)

# Check convergence
if (!diagnostics$converged) {
  warning("HB estimation may not have converged")
  print(diagnostics$recommendations)
}
```

**Convergence Criteria:**
- R-hat < 1.1 for all parameters
- ESS > 100 for all parameters
- No significant Geweke z-scores (|z| < 1.96)
- Lag-1 autocorrelation < 0.9

---

## 3. Implementation Roadmap

### Phase 2a: Core HB Estimation

**Priority:** High
**Effort:** 3-5 days

1. **Data transformation** (`prepare_bayesm_data`)
   - Convert Turas long format to bayesm lgtdata
   - Handle effect coding for attributes
   - Support respondent covariates (optional)

2. **Estimation wrapper** (`estimate_hb_bayesm`)
   - Call bayesm::rhierMnlRwMixture
   - Set appropriate priors
   - Configure MCMC parameters

3. **Result extraction** (`extract_hb_results`)
   - Individual-level betas
   - Population means
   - Posterior standard deviations

4. **Integration with existing pipeline**
   - Update `estimate_choice_model()` to support `method = "hb"`
   - Ensure output format compatible with downstream functions

### Phase 2b: Individual Utilities

**Priority:** High
**Effort:** 2-3 days

1. **Individual utility extraction**
   - Per-respondent part-worth utilities
   - Posterior means and credible intervals

2. **Utility output formatting**
   - Excel output with individual sheets
   - CSV export option
   - Integration with existing output module

### Phase 2c: Heterogeneity Analysis

**Priority:** Medium
**Effort:** 2-3 days

1. **Heterogeneity metrics**
   - Standard deviation of individual utilities
   - Range and percentile distributions
   - Correlation between attributes

2. **Visualization support**
   - Utility distribution plots (data prep)
   - Heterogeneity summary tables

### Phase 2d: Advanced Features

**Priority:** Low
**Effort:** 3-5 days

1. **Latent class support**
   - Multi-component mixture models
   - Segment identification

2. **Covariate integration**
   - Demographics as upper-level predictors
   - Segment-specific utilities

3. **RSGHB fallback**
   - Alternative estimation engine
   - Automatic fallback if bayesm fails

---

## 4. API Specification

### 4.1 Main Function

```r
#' Estimate Hierarchical Bayes Conjoint Model
#'
#' @param data_list Data list from load_conjoint_data()
#' @param config Configuration object
#' @param mcmc_iterations Integer: total MCMC iterations (default 10000)
#' @param burn_in Integer: burn-in iterations (default 2000)
#' @param thin Integer: thinning interval (default 10)
#' @param n_components Integer: mixture components for latent class (default 1)
#' @param covariates Character vector: respondent covariate columns (optional)
#' @param package Character: "bayesm", "RSGHB", or "auto"
#' @param verbose Logical: print progress
#'
#' @return List with:
#'   - method: "hierarchical_bayes"
#'   - individual_utilities: matrix (respondents x parameters)
#'   - aggregate_utilities: named vector
#'   - posterior_sd: matrix of posterior standard deviations
#'   - convergence: diagnostics from check_hb_convergence()
#'   - mcmc_draws: raw MCMC output (if requested)
#'   - model_fit: AIC, BIC, log-likelihood
#'
#' @export
estimate_hierarchical_bayes <- function(
  data_list,
  config,
  mcmc_iterations = 10000,
  burn_in = 2000,
  thin = 10,
  n_components = 1,
  covariates = NULL,
  package = "auto",
  verbose = TRUE
)
```

### 4.2 Output Structure

```r
# Result structure
hb_result <- list(
  # Identification
  method = "hierarchical_bayes",
  package = "bayesm",
  is_hierarchical_bayes = TRUE,


  # Individual-level results
  individual_utilities = matrix(
    # rows = respondents, cols = parameters
    # Posterior means
  ),
  individual_posterior_sd = matrix(
    # Posterior standard deviations
  ),

  # Aggregate results
  aggregate_utilities = named_vector,
  aggregate_se = named_vector,

  # Convergence
  convergence = list(
    converged = TRUE/FALSE,
    gelman_rubin = data.frame(...),
    effective_n = data.frame(...),
    recommendations = character()
  ),

  # Model fit
  model_fit = list(
    log_lik = numeric,
    aic = numeric,
    bic = numeric
  ),

  # MCMC details
  mcmc_settings = list(
    iterations = 10000,
    burn_in = 2000,
    thin = 10,
    effective_samples = 800
  ),

  # Raw output (optional)
  mcmc_draws = NULL  # Set if save_draws = TRUE
)
```

---

## 5. Testing Requirements

### 5.1 Unit Tests

```r
# tests/testthat/test_hb_estimation.R

test_that("HB estimation runs without error", {
  # Load test data
  data_list <- load_conjoint_data(test_config_path)
  config <- load_conjoint_config(test_config_path)


  # Run HB
  result <- estimate_hierarchical_bayes(
    data_list, config,
    mcmc_iterations = 1000,  # Reduced for testing
    burn_in = 200
  )

  expect_true(result$is_hierarchical_bayes)
  expect_equal(nrow(result$individual_utilities), data_list$n_respondents)
})

test_that("HB convergence diagnostics work", {
  # Check diagnostics integration
  diagnostics <- check_hb_convergence(test_mcmc_draws)
  expect_true(is.logical(diagnostics$converged))
})
```

### 5.2 Integration Tests

- Test with Alchemer import data
- Test with various sample sizes (30, 100, 500 respondents)
- Test convergence across different data complexities

### 5.3 Performance Benchmarks

| Sample Size | Expected Time | Memory |
|-------------|---------------|--------|
| 50 resp, 10k iter | 1-2 min | ~500 MB |
| 200 resp, 10k iter | 5-10 min | ~1 GB |
| 500 resp, 20k iter | 20-40 min | ~2 GB |

---

## 6. Dependencies

### Required Packages

```r
# Core HB
install.packages("bayesm")    # Primary HB engine

# Optional
install.packages("RSGHB")     # Alternative HB engine
install.packages("coda")      # Enhanced diagnostics
```

### Internal Dependencies

- `modules/shared/lib/hb_diagnostics.R` - Convergence checking
- `modules/conjoint/R/03_estimation.R` - Integration point
- `modules/conjoint/R/04_utilities.R` - Utility formatting
- `modules/conjoint/R/07_output.R` - Excel output

---

## 7. Migration Notes

### Updating from Placeholder

When implementing, update `R/11_hierarchical_bayes.R`:

1. Remove `CONJOINT_HB_STATUS <- "PLACEHOLDER"`
2. Replace `conjoint_refuse()` in `estimate_hierarchical_bayes()` with actual implementation
3. Add data transformation functions
4. Add result extraction functions
5. Update `R/03_estimation.R` to enable `method = "hb"`

### Backward Compatibility

- Existing `estimation_method = "auto"` will continue to use mlogit/clogit
- HB requires explicit `estimation_method = "hb"`
- All existing outputs remain unchanged

---

## 8. References

### Academic

- Rossi, P.E., Allenby, G.M., & McCulloch, R. (2005). *Bayesian Statistics and Marketing*. Wiley.
- Train, K. (2009). *Discrete Choice Methods with Simulation* (2nd ed.). Cambridge University Press.

### Package Documentation

- bayesm: https://cran.r-project.org/package=bayesm
- RSGHB: https://cran.r-project.org/package=RSGHB
- coda: https://cran.r-project.org/package=coda

### Turas Internal

- Shared diagnostics: `modules/shared/lib/hb_diagnostics.R`
- Conjoint technical docs: `modules/conjoint/docs/TECHNICAL_DOCS.md`

---

## Appendix A: bayesm Data Format Example

```r
# Example: 3 respondents, 4 choice sets each, 3 alternatives per set
# 2 attributes: Price (3 levels), Brand (2 levels)

# Respondent 1, Choice Set 1
lgtdata[[1]]$y[1] <- 2  # Chose alternative 2
lgtdata[[1]]$X[1:3, ] <- matrix(c(
  # Price_Med, Price_High, Brand_B (effect coded)
  -1,  0,  1,   # Alt 1: Low price, Brand B
   1,  0, -1,   # Alt 2: Med price, Brand A
   0,  1,  1    # Alt 3: High price, Brand B
), nrow = 3, byrow = TRUE)
```

---

*Document maintained by Turas Development Team*
*Last updated: 2025-12*
