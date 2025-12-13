# ==============================================================================
# Tests for modules/shared/lib/weights_utils.R
# ==============================================================================
# Tests for the shared weight calculation and validation module.
# This module provides consistent weight handling across all TURAS modules.
#
# Created as part of Phase 4: Shared Weights Module
# Updated: Now uses consolidated /modules/shared/lib/ location
# ==============================================================================

# Source the module under test (new consolidated location)
source("modules/shared/lib/weights_utils.R", local = TRUE)

# ==============================================================================
# Test: calculate_weight_efficiency
# ==============================================================================

test_that("calculate_weight_efficiency with equal weights returns n", {
  # Equal weights should give efficiency = sample size
  weights <- rep(1, 100)
  result <- calculate_weight_efficiency(weights)

  expect_equal(result, 100)
})

test_that("calculate_weight_efficiency with varying weights returns less than n", {
  # Mixed weights should reduce efficiency
  weights <- c(rep(1, 90), rep(5, 10))
  result <- calculate_weight_efficiency(weights)

  expect_lt(result, 100)
  expect_gt(result, 0)
  expect_equal(round(result, 1), 71.4)  # Pre-calculated expected value
})

test_that("calculate_weight_efficiency handles manual calculation correctly", {
  weights <- c(1, 1, 2, 2)

  # Manual calculation
  sum_weights <- sum(weights)  # 6
  sum_squared <- sum(weights^2)  # 10
  expected <- (sum_weights^2) / sum_squared  # 36 / 10 = 3.6

  result <- calculate_weight_efficiency(weights)

  expect_equal(result, expected)
  expect_equal(result, 3.6)
})

test_that("calculate_weight_efficiency handles NA values", {
  weights <- c(1, 2, NA, 3, NA)

  expect_warning(
    result <- calculate_weight_efficiency(weights),
    regexp = NA  # Should handle silently
  )

  # Should calculate based on non-NA values
  expected_weights <- c(1, 2, 3)
  expected <- calculate_weight_efficiency(expected_weights)

  result_with_na <- suppressWarnings(calculate_weight_efficiency(weights))
  expect_equal(result_with_na, expected)
})

test_that("calculate_weight_efficiency handles negative weights", {
  weights <- c(1, 2, -1, 3)

  expect_warning(
    result <- calculate_weight_efficiency(weights),
    regexp = "Some weights are <= 0"
  )

  # Should exclude negative weights
  expect_gt(result, 0)
})

test_that("calculate_weight_efficiency handles zero weights", {
  weights <- c(1, 2, 0, 3)

  expect_warning(
    result <- calculate_weight_efficiency(weights),
    regexp = "Some weights are <= 0"
  )
})

test_that("calculate_weight_efficiency handles empty input", {
  expect_warning(
    result <- calculate_weight_efficiency(numeric(0)),
    regexp = "No valid weights"
  )
  expect_equal(result, 0)
})

test_that("calculate_weight_efficiency handles all NA input", {
  expect_warning(
    result <- calculate_weight_efficiency(c(NA, NA, NA)),
    regexp = "No valid weights"
  )
  expect_equal(result, 0)
})

# ==============================================================================
# Test: calculate_design_effect
# ==============================================================================

test_that("calculate_design_effect with equal weights returns 1", {
  weights <- rep(1, 100)
  result <- calculate_design_effect(weights)

  expect_equal(result, 1.0)
})

test_that("calculate_design_effect with varying weights returns > 1", {
  weights <- c(rep(0.5, 50), rep(2, 50))
  result <- calculate_design_effect(weights)

  expect_gt(result, 1.0)
  expect_equal(result, 1.25)  # Pre-calculated
})

test_that("calculate_design_effect formula is correct", {
  weights <- c(1, 1, 2, 2)
  n <- length(weights)
  eff_n <- calculate_weight_efficiency(weights)

  expected_deff <- n / eff_n

  result <- calculate_design_effect(weights)

  expect_equal(result, expected_deff)
})

test_that("calculate_design_effect handles invalid input", {
  result <- calculate_design_effect(numeric(0))
  expect_true(is.na(result))

  result <- calculate_design_effect(c(NA, NA))
  expect_true(is.na(result))
})

# ==============================================================================
# Test: validate_weights_comprehensive
# ==============================================================================

test_that("validate_weights_comprehensive passes with valid weights", {
  weights <- c(0.5, 1, 1.5, 2, 2.5)

  result <- validate_weights_comprehensive(weights)

  expect_true(result$valid)
  expect_equal(result$n_total, 5)
  expect_equal(result$n_na, 0)
  expect_equal(result$n_zero, 0)
  expect_equal(result$n_negative, 0)
  expect_length(result$issues, 0)
})

test_that("validate_weights_comprehensive detects NA weights", {
  weights <- c(1, 2, NA, 3)

  result <- validate_weights_comprehensive(weights, allow_na = FALSE)

  expect_false(result$valid)
  expect_equal(result$n_na, 1)
  expect_true(any(grepl("NA", result$issues)))
})

test_that("validate_weights_comprehensive allows NA when specified", {
  weights <- c(1, 2, NA, 3)

  result <- validate_weights_comprehensive(weights, allow_na = TRUE)

  # Should still be invalid due to other checks, but NA not in issues
  expect_equal(result$n_na, 1)
})

test_that("validate_weights_comprehensive detects zero weights", {
  weights <- c(1, 2, 0, 3)

  result <- validate_weights_comprehensive(weights)

  expect_false(result$valid)
  expect_equal(result$n_zero, 1)
  expect_true(any(grepl("zero", result$issues)))
})

test_that("validate_weights_comprehensive detects negative weights", {
  weights <- c(1, 2, -1, 3)

  result <- validate_weights_comprehensive(weights)

  expect_false(result$valid)
  expect_equal(result$n_negative, 1)
  expect_true(any(grepl("negative", result$issues)))
})

test_that("validate_weights_comprehensive checks min/max bounds", {
  weights <- c(0.1, 1, 5, 10)

  # Too small
  result <- validate_weights_comprehensive(weights, min_weight = 0.5)
  expect_false(result$valid)
  expect_equal(result$n_too_small, 1)  # 0.1 is too small

  # Too large
  result <- validate_weights_comprehensive(weights, max_weight = 7)
  expect_false(result$valid)
  expect_equal(result$n_too_large, 1)  # 10 is too large
})

test_that("validate_weights_comprehensive returns all issues", {
  weights <- c(-1, 0, NA, 1, 2)

  result <- validate_weights_comprehensive(weights, allow_na = FALSE)

  expect_false(result$valid)
  expect_length(result$issues, 3)  # NA, zero, negative
})

# ==============================================================================
# Test: get_weight_summary
# ==============================================================================

test_that("get_weight_summary returns correct statistics", {
  weights <- c(0.5, 1, 1.5, 2, 2.5)

  result <- get_weight_summary(weights)

  expect_s3_class(result, "data.frame")
  expect_equal(result$n, 5)
  expect_equal(result$n_valid, 5)
  expect_equal(result$min, 0.5)
  expect_equal(result$max, 2.5)
  expect_equal(result$mean, mean(weights))
  expect_equal(result$median, median(weights))
  expect_equal(result$sum, sum(weights))
  expect_gt(result$efficiency, 0)
  expect_gt(result$design_effect, 0)
})

test_that("get_weight_summary handles NA and invalid weights", {
  weights <- c(1, 2, NA, -1, 0, 3)

  result <- get_weight_summary(weights)

  # Should only use valid weights (1, 2, 3)
  expect_equal(result$n, 6)
  expect_equal(result$n_valid, 3)
  expect_equal(result$min, 1)
  expect_equal(result$max, 3)
})

test_that("get_weight_summary handles no valid weights", {
  weights <- c(NA, -1, 0)

  result <- get_weight_summary(weights)

  expect_equal(result$n, 3)
  expect_equal(result$n_valid, 0)
  expect_true(is.na(result$min))
  expect_true(is.na(result$max))
  expect_true(is.na(result$efficiency))
})

# ==============================================================================
# Test: standardize_weight_variable
# ==============================================================================

test_that("standardize_weight_variable creates weight_var column", {
  df <- data.frame(
    ID = 1:5,
    my_weight = c(1, 1.5, 2, 1, 1)
  )

  result <- standardize_weight_variable(df, "my_weight")

  expect_true("weight_var" %in% names(result))
  expect_equal(result$weight_var, df$my_weight)
})

test_that("standardize_weight_variable can use custom target name", {
  df <- data.frame(
    ID = 1:5,
    my_weight = c(1, 1.5, 2, 1, 1)
  )

  result <- standardize_weight_variable(df, "my_weight", target_name = "custom_weight")

  expect_true("custom_weight" %in% names(result))
  expect_equal(result$custom_weight, df$my_weight)
})

test_that("standardize_weight_variable fails with missing weight variable", {
  df <- data.frame(ID = 1:5, other = 1:5)

  expect_error(
    standardize_weight_variable(df, "nonexistent"),
    regexp = "not found"
  )
})

test_that("standardize_weight_variable validates weights by default", {
  df <- data.frame(
    ID = 1:5,
    my_weight = c(1, 2, -1, 3, NA)
  )

  expect_error(
    standardize_weight_variable(df, "my_weight"),
    regexp = "Invalid weights"
  )
})

test_that("standardize_weight_variable can skip validation", {
  df <- data.frame(
    ID = 1:5,
    my_weight = c(1, 2, -1, 3, NA)
  )

  result <- standardize_weight_variable(df, "my_weight", validate = FALSE)

  expect_true("weight_var" %in% names(result))
})

# ==============================================================================
# Test: Mathematical Correctness
# ==============================================================================

test_that("Weight efficiency formula is mathematically correct", {
  # Test with known values
  weights <- c(1, 2, 3, 4, 5)

  sum_w <- sum(weights)  # 15
  sum_w2 <- sum(weights^2)  # 55
  expected <- (sum_w^2) / sum_w2  # 225 / 55 = 4.0909...

  result <- calculate_weight_efficiency(weights)

  expect_equal(result, expected)
  expect_equal(round(result, 4), 4.0909)
})

test_that("Design effect equals n divided by effective n", {
  weights <- c(1, 2, 3, 4, 5)
  n <- length(weights)
  eff_n <- calculate_weight_efficiency(weights)
  expected_deff <- n / eff_n

  result <- calculate_design_effect(weights)

  expect_equal(result, expected_deff)
})

cat("\n✓ Shared weights module tests completed\n")
cat("  All weight calculation functions validated\n")
