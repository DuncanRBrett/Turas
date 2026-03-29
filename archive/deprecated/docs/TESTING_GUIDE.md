# Turas Testing Guide

**Version:** 1.0
**Date:** 2025-12-30
**Purpose:** Comprehensive testing strategy for Turas R package modules

---

## Overview

This document outlines the testing strategy for the Turas R package, including test organization, synthetic data generation, and best practices for ensuring production-ready code quality.

## Testing Philosophy

### Core Principles

1. **Comprehensive Coverage** - Aim for 80%+ code coverage across all modules
2. **Synthetic Data** - Use generated data with known properties for validation
3. **Edge Case Testing** - Explicitly test boundary conditions and failure modes
4. **Performance Testing** - Ensure acceptable performance for typical use cases
5. **Regression Prevention** - Golden file tests to prevent output changes
6. **Integration Testing** - Test complete workflows end-to-end

### Testing Pyramid

```
        /\
       /  \        E2E Tests (5%)
      /----\       - Full workflow validation
     /      \      - User acceptance scenarios
    /--------\     Integration Tests (15%)
   /          \    - Module interactions
  /------------\   - Cross-module validation
 /              \  Unit Tests (80%)
/________________\ - Function-level testing
                   - Edge cases and boundaries
```

---

## Test Directory Structure

### Standard Layout

Each module should follow this structure:

```
modules/{module}/
├── R/
│   └── *.R                    # Source files
├── tests/
│   ├── testthat/              # Unit tests (testthat framework)
│   │   ├── test_{function}.R  # Function-specific tests
│   │   └── helper.R           # Test helper functions
│   ├── fixtures/              # Test data
│   │   ├── golden/            # Golden file outputs
│   │   │   └── *.rds          # Expected output objects
│   │   └── synthetic_data/    # Generated test data
│   │       ├── generate_test_data.R
│   │       └── *.csv/*.rds    # Synthetic datasets
│   ├── integration/           # Integration tests
│   │   └── test_e2e_{workflow}.R
│   └── run_tests.R            # Test runner script
└── README.md
```

---

## Test Categories

### 1. Unit Tests

**Purpose:** Test individual functions in isolation

**Location:** `tests/testthat/test_{function}.R`

**Example Structure:**

```r
# tests/testthat/test_proportion_ci.R

library(testthat)
context("Proportion Confidence Intervals")

test_that("Wilson score interval calculation is correct", {
  # Arrange
  n <- 100
  x <- 50

  # Act
  ci <- calculate_wilson_ci(x, n, conf.level = 0.95)

  # Assert
  expect_true(ci$lower < 0.5)
  expect_true(ci$upper > 0.5)
  expect_equal(ci$upper - ci$lower, expected_width, tolerance = 0.01)
})
```

**Best Practices:**

- One test file per source file
- Use descriptive test names
- Follow AAA pattern (Arrange, Act, Assert)
- Test both success and failure paths
- Use `skip_if_not_installed()` for optional dependencies

### 2. Edge Case Tests

**Purpose:** Validate behavior at boundaries and extreme conditions

**Common Edge Cases:**

- Empty inputs (`n = 0`, `length(x) = 0`)
- Single-element inputs (`n = 1`)
- Missing data (`NA`, `NULL`)
- Extreme values (0%, 100%, Inf, -Inf)
- Very large inputs (performance testing)
- Very small samples (statistical validity)

**Example:**

```r
test_that("Handle proportion of 0%", {
  values <- rep(0, 100)
  ci <- calculate_proportion_ci(values)

  expect_equal(ci$proportion, 0)
  expect_true(ci$lower >= 0)
  expect_true(ci$upper > 0)
})
```

### 3. Integration Tests

**Purpose:** Test complete workflows across multiple functions

**Location:** `tests/integration/test_e2e_{workflow}.R`

**Example:**

```r
test_that("Complete confidence analysis workflow", {
  # Load config
  config <- load_confidence_config("fixtures/test_config.xlsx")

  # Load data
  data <- load_survey_data(config$data_file)

  # Run analysis
  results <- run_confidence_analysis(config)

  # Validate output
  expect_true(file.exists(results$output_file))
  expect_equal(results$run_status, "PASS")
  expect_true(nrow(results$proportion_results) > 0)
})
```

### 4. Golden File Tests

**Purpose:** Detect unintended changes in output

**Location:** `tests/fixtures/golden/`

**Workflow:**

1. Generate "golden" output from known-good code version
2. Save as RDS file
3. In tests, compare new output to golden file
4. Flag any differences for review

**Example:**

```r
test_that("Output matches golden file", {
  # Run analysis
  results <- run_analysis(test_config)

  # Load golden output
  golden <- readRDS("fixtures/golden/expected_output.rds")

  # Compare (allowing for small numerical differences)
  expect_equal(results$utilities, golden$utilities, tolerance = 1e-6)
})
```

### 5. Performance Tests

**Purpose:** Ensure acceptable performance for typical use cases

**Example:**

```r
test_that("Analysis completes in reasonable time for typical study", {
  # 500 respondents, 50 questions
  data <- generate_synthetic_survey(n = 500, q = 50)

  start_time <- Sys.time()
  results <- run_analysis(data)
  elapsed <- difftime(Sys.time(), start_time, units = "secs")

  # Should complete in under 30 seconds
  expect_true(elapsed < 30)
})
```

---

## Synthetic Data Generation

### Why Synthetic Data?

1. **Known Properties** - Ground truth for validation
2. **Reproducibility** - Seeded random generation
3. **Edge Cases** - Generate extreme scenarios easily
4. **No Privacy Issues** - No real respondent data
5. **Scalability** - Create datasets of any size

### Data Generator Template

Each module should have a data generator in `tests/fixtures/synthetic_data/generate_test_data.R`:

```r
#' Generate Synthetic Survey Data
#'
#' @param n_respondents Number of respondents
#' @param seed Random seed for reproducibility
#' @return List with data and metadata
#'
generate_synthetic_survey <- function(n_respondents = 500, seed = 12345) {
  set.seed(seed)

  # Generate data with known properties
  data <- data.frame(
    id = 1:n_respondents,
    q1 = rbinom(n_respondents, 1, 0.6),  # 60% incidence
    q2 = round(rnorm(n_respondents, 7, 1.5))  # Mean = 7, SD = 1.5
  )

  # Return with metadata for validation
  list(
    data = data,
    metadata = list(
      n = n_respondents,
      q1_true_p = 0.6,
      q2_true_mean = 7,
      q2_true_sd = 1.5,
      seed = seed
    )
  )
}
```

### Common Data Patterns

**Confidence Module:**
- Binary variables (proportions)
- Numeric scales (means)
- NPS scores (0-10)
- Weighted data (log-normal weight distribution)

**Conjoint Module:**
- Choice sets with alternatives
- Attribute-level data
- Random utility generation
- Known part-worth utilities

**Key Driver Module:**
- Continuous predictors
- Categorical predictors
- Mixed predictors
- Known R-squared and coefficients

**MaxDiff Module:**
- Best-worst pairs
- Item sets
- Balanced designs
- Individual preferences

---

## Running Tests

### Manual Testing

**Single Module:**

```r
# Set working directory to Turas root
setwd("/path/to/Turas")

# Run tests for a specific module
testthat::test_dir("modules/confidence/tests/testthat")
```

**All Modules:**

```r
# Run all module tests
source("tools/run_all_tests.R")
```

### Automated Testing (Future)

**GitHub Actions Workflow:**

```yaml
name: R Package Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: r-lib/actions/setup-r@v2
      - name: Install dependencies
        run: |
          install.packages(c("testthat", "devtools"))
      - name: Run tests
        run: |
          devtools::test()
```

---

## Test Writing Guidelines

### 1. Test Naming

**Good:**
```r
test_that("Wilson score interval handles p=0 correctly", { ... })
test_that("Bootstrap CI with n=10 completes without error", { ... })
```

**Bad:**
```r
test_that("test 1", { ... })
test_that("it works", { ... })
```

### 2. Arrange-Act-Assert Pattern

```r
test_that("Calculate mean correctly", {
  # Arrange - Set up test data
  values <- c(1, 2, 3, 4, 5)

  # Act - Execute function
  result <- calculate_mean(values)

  # Assert - Verify outcome
  expect_equal(result, 3)
})
```

### 3. Test Independence

Each test should be **independent** - able to run in any order:

**Good:**
```r
test_that("Test A", {
  data <- create_test_data()
  result <- analyze(data)
  expect_true(result$success)
})

test_that("Test B", {
  data <- create_test_data()  # Create fresh data
  result <- analyze(data)
  expect_equal(result$value, 42)
})
```

**Bad:**
```r
# Don't rely on previous test state
data <- NULL

test_that("Test A", {
  data <<- create_test_data()  # Side effect!
  ...
})

test_that("Test B", {
  # Depends on Test A running first
  result <- analyze(data)
  ...
})
```

### 4. Tolerance for Numerical Comparisons

Always use `tolerance` for floating point comparisons:

```r
# Good
expect_equal(result, 3.14159, tolerance = 1e-5)

# Bad - may fail due to floating point precision
expect_equal(result, 3.14159)
```

### 5. Skip Tests Conditionally

For tests requiring optional packages:

```r
test_that("SHAP analysis works", {
  skip_if_not_installed("xgboost")

  results <- run_shap_analysis(data)
  expect_true(!is.null(results))
})
```

For long-running tests:

```r
test_that("Performance test with 1M records", {
  skip_on_cran()
  skip_if(Sys.getenv("QUICK_TESTS") == "true")

  # Long-running test
  ...
})
```

---

## Code Coverage

### Using covr Package

**Check coverage:**

```r
library(covr)

# Single module
cov <- file_coverage(
  source_files = "modules/confidence/R/04_proportions.R",
  test_files = "modules/confidence/tests/testthat/test_proportion_ci.R"
)

# View report
report(cov)

# Target: 80%+ coverage
```

**Generate coverage report:**

```r
# Full package coverage
cov <- package_coverage()

# HTML report
covr::report(cov, file = "coverage_report.html")
```

---

## Module-Specific Test Priorities

### Confidence Module

**Priority Tests:**
1. All CI methods (Wilson, bootstrap, Bayesian)
2. Edge cases (p=0, p=1, small n)
3. Weighted vs unweighted
4. 200 question limit
5. Effective n calculation

**Example Datasets Needed:**
- Standard survey (n=500, 20 questions)
- Small sample (n=20)
- Extreme proportions (0%, 100%)
- Heavily weighted data

### Conjoint Module

**Priority Tests:**
1. Model estimation (mlogit, clogit)
2. Utility calculation and zero-centering
3. Attribute importance
4. Market simulator
5. None option handling

**Example Datasets Needed:**
- Simple CBC (2 attributes, 2 levels)
- Realistic CBC (4 attributes, 3 levels)
- With/without none option
- Alchemer import format

### Key Driver Module

**Priority Tests:**
1. Multiple importance methods agreement
2. Mixed predictors (continuous + categorical)
3. SHAP analysis (if available)
4. Quadrant analysis
5. Multicollinearity detection

**Example Datasets Needed:**
- Continuous predictors only
- Mixed predictors
- High multicollinearity case
- Perfect separation case

### MaxDiff Module

**Priority Tests:**
1. Design generation (balanced, random)
2. Count-based scoring
3. Logit model estimation
4. HB model (if cmdstanr available)
5. Segment analysis

**Example Datasets Needed:**
- Generated design (10 items, 5 tasks)
- Survey responses matching design
- Multi-segment data

### CatDriver Module

**Priority Tests:**
1. Binary, ordinal, multinomial logistic
2. Firth fallback for separation
3. Rare level collapsing
4. Importance calculation
5. Probability lifts

**Example Datasets Needed:**
- Binary outcome
- Ordinal outcome (3-5 levels)
- Multinomial outcome (5+ levels)
- Separation case (Firth needed)

---

## Troubleshooting Tests

### Common Issues

**Issue:** Tests fail randomly
- **Cause:** Missing `set.seed()` in data generation
- **Fix:** Always seed random number generators

**Issue:** Tests fail on CI but pass locally
- **Cause:** Different package versions or OS differences
- **Fix:** Use `session_info()` to document environment

**Issue:** Tests are very slow
- **Cause:** Too many bootstrap iterations or large datasets
- **Fix:** Use smaller datasets for unit tests, mark slow tests with `skip_on_cran()`

**Issue:** Numerical tests fail intermittently
- **Cause:** Tolerance too strict for floating point
- **Fix:** Use appropriate `tolerance` parameter

---

## Test Maintenance

### When to Update Tests

1. **Bug Fixes:** Add test reproducing bug before fixing
2. **New Features:** Add tests for new functionality
3. **Refactoring:** Update tests if interface changes
4. **Performance:** Add benchmarks for optimization

### Test Review Checklist

- [ ] All tests have descriptive names
- [ ] Edge cases covered
- [ ] Tests are independent
- [ ] Appropriate tolerance for numerical comparisons
- [ ] Optional dependencies handled with `skip_if_not_installed()`
- [ ] Synthetic data uses `set.seed()` for reproducibility
- [ ] Performance tests marked appropriately
- [ ] Integration tests cover main workflows

---

## Example Test Suites

### Complete Test Suite Example

See implementations in:
- `/modules/confidence/tests/testthat/test_proportion_ci.R`
- `/modules/conjoint/tests/testthat/test_utilities.R`
- `/modules/confidence/tests/fixtures/synthetic_data/generate_test_data.R`

---

## Future Enhancements

### Planned Improvements

1. **Automated CI/CD**
   - GitHub Actions workflow
   - Automated coverage reporting
   - Nightly builds with full test suite

2. **Property-Based Testing**
   - Use `quickcheck` package
   - Generate random test cases
   - Validate properties hold across all inputs

3. **Mutation Testing**
   - Use `mutator` package
   - Verify tests catch code changes
   - Improve test quality

4. **Load Testing**
   - Test with very large datasets (1M+ rows)
   - Memory profiling
   - Performance benchmarks

5. **Visual Regression Testing**
   - Snapshot testing for plots
   - Detect unintended chart changes

---

## Resources

### R Testing Packages

- **testthat** - Main testing framework
- **covr** - Code coverage
- **mockery** - Mocking functions
- **withr** - Temporary state management
- **vdiffr** - Visual regression testing

### References

- [R Packages - Testing](https://r-pkgs.org/tests.html)
- [testthat Documentation](https://testthat.r-lib.org/)
- [Advanced R - Testing](http://adv-r.had.co.nz/Testing.html)

---

**Document Version:** 1.0
**Last Updated:** 2025-12-30
**Maintained By:** Turas Development Team
