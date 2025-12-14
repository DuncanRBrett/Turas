# ==============================================================================
# Unit Tests for Shared Weights Utilities
# ==============================================================================
# Tests for /modules/shared/lib/weights_utils.R
# ==============================================================================

# Setup: Source the shared utilities
test_that("weights_utils.R can be sourced", {
  # Find Turas root
  current_dir <- getwd()
  while (current_dir != dirname(current_dir)) {
    if (file.exists(file.path(current_dir, "launch_turas.R")) ||
        dir.exists(file.path(current_dir, "modules", "shared"))) {
      break
    }
    current_dir <- dirname(current_dir)
  }

  weights_path <- file.path(current_dir, "modules", "shared", "lib", "weights_utils.R")
  expect_true(file.exists(weights_path))
  source(weights_path)
  expect_true(exists("calculate_weight_efficiency", mode = "function"))
})

# Source for remaining tests
current_dir <- getwd()
while (current_dir != dirname(current_dir)) {
  if (file.exists(file.path(current_dir, "launch_turas.R")) ||
      dir.exists(file.path(current_dir, "modules", "shared"))) {
    break
  }
  current_dir <- dirname(current_dir)
}
source(file.path(current_dir, "modules", "shared", "lib", "weights_utils.R"))

# ==============================================================================
# Tests for calculate_weight_efficiency()
# ==============================================================================

test_that("calculate_weight_efficiency returns n for equal weights", {
  # Equal weights should give efficiency = n
  weights <- rep(1, 100)
  result <- calculate_weight_efficiency(weights)
  expect_equal(result, 100)
})

test_that("calculate_weight_efficiency returns n for any equal weights", {
  # Equal weights of any value
  weights <- rep(2.5, 50)
  result <- calculate_weight_efficiency(weights)
  expect_equal(result, 50)
})

test_that("calculate_weight_efficiency handles varying weights", {
  # Varying weights should give efficiency < n
  weights <- c(1, 1, 1, 2, 2, 2)  # n=6
  result <- calculate_weight_efficiency(weights)
  expect_lt(result, 6)
  expect_gt(result, 0)
})

test_that("calculate_weight_efficiency handles extreme variation", {
  # One very large weight dominates
  weights <- c(100, 1, 1, 1, 1)
  result <- calculate_weight_efficiency(weights)
  # Efficiency should be much less than n=5
  expect_lt(result, 3)
})

test_that("calculate_weight_efficiency handles NA values", {
  weights <- c(1, 1, NA, 1, 1)
  result <- calculate_weight_efficiency(weights)
  expect_equal(result, 4)  # Only 4 valid weights
})

test_that("calculate_weight_efficiency warns for empty weights", {
  expect_warning(result <- calculate_weight_efficiency(c()))
  expect_equal(result, 0)
})

test_that("calculate_weight_efficiency warns for negative weights", {
  expect_warning(result <- calculate_weight_efficiency(c(1, -1, 1)))
  expect_equal(result, 2)  # Only 2 valid weights
})

test_that("calculate_weight_efficiency handles zero weights", {
  expect_warning(result <- calculate_weight_efficiency(c(1, 0, 1)))
  expect_equal(result, 2)
})

# ==============================================================================
# Tests for calculate_design_effect()
# ==============================================================================

test_that("calculate_design_effect returns 1 for equal weights", {
  weights <- rep(1, 100)
  result <- calculate_design_effect(weights)
  expect_equal(result, 1)
})

test_that("calculate_design_effect > 1 for varying weights", {
  weights <- c(1, 1, 1, 2, 2, 2)
  result <- calculate_design_effect(weights)
  expect_gt(result, 1)
})

test_that("calculate_design_effect handles NA", {
  result <- calculate_design_effect(c())
  expect_true(is.na(result))
})

# ==============================================================================
# Tests for validate_weights_comprehensive()
# ==============================================================================

test_that("validate_weights_comprehensive passes for valid weights", {
  weights <- c(1, 1.5, 2, 0.5)
  result <- validate_weights_comprehensive(weights)
  expect_true(result$valid)
  expect_equal(result$n_total, 4)
  expect_equal(length(result$issues), 0)
})

test_that("validate_weights_comprehensive detects NA", {
  weights <- c(1, NA, 2)
  result <- validate_weights_comprehensive(weights)
  expect_false(result$valid)
  expect_equal(result$n_na, 1)
  expect_true(any(grepl("NA", result$issues)))
})

test_that("validate_weights_comprehensive allows NA when specified", {
  weights <- c(1, NA, 2)
  result <- validate_weights_comprehensive(weights, allow_na = TRUE)
  expect_true(result$valid)
  expect_equal(result$n_na, 1)
})

test_that("validate_weights_comprehensive detects zero weights", {
  weights <- c(1, 0, 2)
  result <- validate_weights_comprehensive(weights)
  expect_false(result$valid)
  expect_equal(result$n_zero, 1)
  expect_true(any(grepl("zero", result$issues)))
})

test_that("validate_weights_comprehensive detects negative weights", {
  weights <- c(1, -0.5, 2)
  result <- validate_weights_comprehensive(weights)
  expect_false(result$valid)
  expect_equal(result$n_negative, 1)
  expect_true(any(grepl("negative", result$issues)))
})

test_that("validate_weights_comprehensive enforces max_weight", {
  weights <- c(1, 2, 10)
  result <- validate_weights_comprehensive(weights, max_weight = 5)
  expect_false(result$valid)
  expect_equal(result$n_too_large, 1)
})

# ==============================================================================
# Tests for get_weight_summary()
# ==============================================================================

test_that("get_weight_summary returns correct statistics", {
  weights <- c(1, 2, 3, 4)
  result <- get_weight_summary(weights)

  expect_equal(result$n, 4)
  expect_equal(result$n_valid, 4)
  expect_equal(result$min, 1)
  expect_equal(result$max, 4)
  expect_equal(result$mean, 2.5)
  expect_equal(result$median, 2.5)
  expect_equal(result$sum, 10)
})

test_that("get_weight_summary handles NA values", {
  weights <- c(1, NA, 3)
  result <- get_weight_summary(weights)

  expect_equal(result$n, 3)
  expect_equal(result$n_valid, 2)
})

test_that("get_weight_summary handles empty/invalid weights", {
  result <- get_weight_summary(c(NA, NA))

  expect_equal(result$n, 2)
  expect_equal(result$n_valid, 0)
  expect_true(is.na(result$mean))
})

# ==============================================================================
# Tests for standardize_weight_variable()
# ==============================================================================

test_that("standardize_weight_variable creates target column", {
  df <- data.frame(id = 1:3, wt = c(1, 1.5, 2))
  result <- standardize_weight_variable(df, "wt", "weight_var")

  expect_true("weight_var" %in% names(result))
  expect_equal(result$weight_var, c(1, 1.5, 2))
})

test_that("standardize_weight_variable errors on missing column", {
  df <- data.frame(id = 1:3, wt = c(1, 1.5, 2))
  expect_error(standardize_weight_variable(df, "nonexistent"))
})

test_that("standardize_weight_variable validates weights", {
  df <- data.frame(id = 1:3, wt = c(1, -1, 2))
  expect_error(standardize_weight_variable(df, "wt"))
})

test_that("standardize_weight_variable can skip validation", {
  df <- data.frame(id = 1:3, wt = c(1, 0, 2))
  result <- standardize_weight_variable(df, "wt", validate = FALSE)
  expect_true("weight_var" %in% names(result))
})

# ==============================================================================
# Summary
# ==============================================================================

cat("\n=== Weights Utilities Tests Complete ===\n")
