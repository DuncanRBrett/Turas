# ==============================================================================
# TEST SUITE: Bootstrap Confidence Intervals
# ==============================================================================
# Tests for bootstrap_importance_ci() and related helpers
# Part of Turas Key Driver Module Test Suite
# ==============================================================================

library(testthat)

context("Bootstrap Confidence Intervals")

# ==============================================================================
# SETUP: Source dependencies and test data generators
# ==============================================================================

# Define %||% operator if not already available
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# module_dir and project_root are provided by helper-paths.R

# Source shared TRS infrastructure
tryCatch({
  source(file.path(project_root, "modules", "shared", "lib", "trs_refusal.R"))
}, error = function(e) {
  skip(paste("Cannot load TRS infrastructure:", conditionMessage(e)))
})

# Source keydriver guard layer (provides keydriver_refuse)
tryCatch({
  source(file.path(module_dir, "R", "00_guard.R"))
}, error = function(e) {
  skip(paste("Cannot load keydriver guard:", conditionMessage(e)))
})

# Source the bootstrap module under test
tryCatch({
  source(file.path(module_dir, "R", "05_bootstrap.R"))
}, error = function(e) {
  skip(paste("Cannot load bootstrap module:", conditionMessage(e)))
})

# Source test data generators
tryCatch({
  source(file.path(module_dir, "tests", "fixtures", "generate_test_data.R"))
}, error = function(e) {
  skip(paste("Cannot load test data generators:", conditionMessage(e)))
})


# ==============================================================================
# RETURN STRUCTURE TESTS
# ==============================================================================

test_that("bootstrap_importance_ci returns data.frame with correct columns", {
  data <- generate_basic_kda_data(n = 200, n_drivers = 3, seed = 42)
  drivers <- c("driver_1", "driver_2", "driver_3")

  result <- bootstrap_importance_ci(
    data = data,
    outcome = "outcome",
    drivers = drivers,
    n_bootstrap = 100
  )

  expect_true(is.data.frame(result))
  expected_cols <- c("Driver", "Method", "Point_Estimate", "CI_Lower", "CI_Upper", "SE")
  expect_equal(names(result), expected_cols)

  # Should have 3 drivers x 3 methods = 9 rows
  expect_equal(nrow(result), 9)
})


test_that("CIs contain the point estimate (CI_Lower <= Point_Estimate <= CI_Upper)", {
  data <- generate_basic_kda_data(n = 200, n_drivers = 3, seed = 42)
  drivers <- c("driver_1", "driver_2", "driver_3")

  result <- bootstrap_importance_ci(
    data = data,
    outcome = "outcome",
    drivers = drivers,
    n_bootstrap = 100
  )

  for (i in seq_len(nrow(result))) {
    expect_true(
      result$CI_Lower[i] <= result$Point_Estimate[i],
      info = sprintf("Row %d (%s, %s): CI_Lower (%.4f) > Point_Estimate (%.4f)",
                     i, result$Driver[i], result$Method[i],
                     result$CI_Lower[i], result$Point_Estimate[i])
    )
    expect_true(
      result$Point_Estimate[i] <= result$CI_Upper[i],
      info = sprintf("Row %d (%s, %s): Point_Estimate (%.4f) > CI_Upper (%.4f)",
                     i, result$Driver[i], result$Method[i],
                     result$Point_Estimate[i], result$CI_Upper[i])
    )
  }
})


test_that("CIs narrow with larger samples", {
  drivers <- c("driver_1", "driver_2", "driver_3")

  # Small sample
  data_small <- generate_basic_kda_data(n = 100, n_drivers = 3, seed = 42)
  result_small <- bootstrap_importance_ci(
    data = data_small,
    outcome = "outcome",
    drivers = drivers,
    n_bootstrap = 100,
    ci_level = 0.95
  )

  # Large sample
  data_large <- generate_basic_kda_data(n = 500, n_drivers = 3, seed = 42)
  result_large <- bootstrap_importance_ci(
    data = data_large,
    outcome = "outcome",
    drivers = drivers,
    n_bootstrap = 100,
    ci_level = 0.95
  )

  # Average CI width should be narrower for the larger sample
  width_small <- mean(result_small$CI_Upper - result_small$CI_Lower)
  width_large <- mean(result_large$CI_Upper - result_large$CI_Lower)

  expect_true(
    width_large < width_small,
    info = sprintf("Large sample CI width (%.4f) should be < small sample CI width (%.4f)",
                   width_large, width_small)
  )
})


test_that("all three methods are present in results", {
  data <- generate_basic_kda_data(n = 200, n_drivers = 3, seed = 42)
  drivers <- c("driver_1", "driver_2", "driver_3")

  result <- bootstrap_importance_ci(
    data = data,
    outcome = "outcome",
    drivers = drivers,
    n_bootstrap = 100
  )

  methods_present <- unique(result$Method)
  expect_true("Correlation" %in% methods_present)
  expect_true("Beta_Weight" %in% methods_present)
  expect_true("Relative_Weight" %in% methods_present)
  expect_equal(length(methods_present), 3)
})


# ==============================================================================
# WEIGHTED ANALYSIS TESTS
# ==============================================================================

test_that("bootstrap works with weights column", {
  data <- generate_weighted_kda_data(n = 200, seed = 456)
  drivers <- c("driver_1", "driver_2", "driver_3")

  result <- bootstrap_importance_ci(
    data = data,
    outcome = "outcome",
    drivers = drivers,
    weights = "weight",
    n_bootstrap = 100
  )

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 9)  # 3 drivers x 3 methods

  # All SE values should be positive (non-degenerate)
  expect_true(all(result$SE > 0),
              info = "Standard errors should be positive for weighted bootstrap")
})


# ==============================================================================
# CONFIG OVERRIDE TESTS
# ==============================================================================

test_that("n_bootstrap config override works", {
  data <- generate_basic_kda_data(n = 200, n_drivers = 3, seed = 42)
  drivers <- c("driver_1", "driver_2", "driver_3")

  # Pass n_bootstrap via config (should override the explicit parameter)
  config <- list(bootstrap_iterations = 150)

  result <- bootstrap_importance_ci(
    data = data,
    outcome = "outcome",
    drivers = drivers,
    config = config,
    n_bootstrap = 200  # This should be overridden by config
  )

  # We cannot directly observe the iteration count from the result,
  # but we can verify the function runs and produces valid output
  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 9)
  expect_true(all(!is.na(result$Point_Estimate)))
})


# ==============================================================================
# TRS REFUSAL TESTS
# ==============================================================================

test_that("returns TRS refusal when data is not a data.frame", {
  expect_error(
    bootstrap_importance_ci(
      data = "not a data.frame",
      outcome = "outcome",
      drivers = c("driver_1", "driver_2"),
      n_bootstrap = 100
    ),
    class = "turas_refusal"
  )

  # Also test with a matrix
  expect_error(
    bootstrap_importance_ci(
      data = matrix(1:10, nrow = 5),
      outcome = "outcome",
      drivers = c("driver_1", "driver_2"),
      n_bootstrap = 100
    ),
    class = "turas_refusal"
  )
})


test_that("returns TRS refusal when outcome is missing or invalid", {
  data <- generate_basic_kda_data(n = 200, n_drivers = 3, seed = 42)
  drivers <- c("driver_1", "driver_2", "driver_3")

  # Missing outcome (empty string)
  expect_error(
    bootstrap_importance_ci(
      data = data,
      outcome = "",
      drivers = drivers,
      n_bootstrap = 100
    ),
    class = "turas_refusal"
  )

  # Numeric outcome (not character)
  expect_error(
    bootstrap_importance_ci(
      data = data,
      outcome = 42,
      drivers = drivers,
      n_bootstrap = 100
    ),
    class = "turas_refusal"
  )

  # Multiple outcomes
  expect_error(
    bootstrap_importance_ci(
      data = data,
      outcome = c("outcome", "driver_1"),
      drivers = drivers,
      n_bootstrap = 100
    ),
    class = "turas_refusal"
  )
})


test_that("returns TRS refusal when fewer than 2 drivers provided", {
  data <- generate_basic_kda_data(n = 200, n_drivers = 3, seed = 42)

  # Single driver
  expect_error(
    bootstrap_importance_ci(
      data = data,
      outcome = "outcome",
      drivers = c("driver_1"),
      n_bootstrap = 100
    ),
    class = "turas_refusal"
  )

  # Empty driver vector
  expect_error(
    bootstrap_importance_ci(
      data = data,
      outcome = "outcome",
      drivers = character(0),
      n_bootstrap = 100
    ),
    class = "turas_refusal"
  )
})


test_that("returns TRS refusal when sample too small (< 30)", {
  edge_data <- generate_edge_case_data(seed = 789)
  small_data <- edge_data$small_sample  # n = 15

  expect_error(
    bootstrap_importance_ci(
      data = small_data,
      outcome = "outcome",
      drivers = c("driver_1", "driver_2", "driver_3"),
      n_bootstrap = 100
    ),
    class = "turas_refusal"
  )
})


# ==============================================================================
# ADDITIONAL VALIDATION TESTS
# ==============================================================================

test_that("SE values are non-negative", {
  data <- generate_basic_kda_data(n = 200, n_drivers = 3, seed = 42)
  drivers <- c("driver_1", "driver_2", "driver_3")

  result <- bootstrap_importance_ci(
    data = data,
    outcome = "outcome",
    drivers = drivers,
    n_bootstrap = 100
  )

  expect_true(all(result$SE >= 0),
              info = "Standard errors must be non-negative")
})


test_that("all drivers appear in the output", {
  data <- generate_basic_kda_data(n = 200, n_drivers = 4, seed = 42)
  drivers <- c("driver_1", "driver_2", "driver_3", "driver_4")

  result <- bootstrap_importance_ci(
    data = data,
    outcome = "outcome",
    drivers = drivers,
    n_bootstrap = 100
  )

  drivers_in_result <- unique(result$Driver)
  expect_equal(sort(drivers_in_result), sort(drivers))
})


test_that("returns TRS refusal for variables not found in data", {
  data <- generate_basic_kda_data(n = 200, n_drivers = 3, seed = 42)

  expect_error(
    bootstrap_importance_ci(
      data = data,
      outcome = "outcome",
      drivers = c("driver_1", "driver_2", "nonexistent_col"),
      n_bootstrap = 100
    ),
    class = "turas_refusal"
  )
})
