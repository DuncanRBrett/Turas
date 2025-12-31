# ==============================================================================
# TEST SUITE: Proportion Confidence Intervals
# ==============================================================================
# Tests for proportion CI calculations across multiple methods
# Part of Turas Confidence Module Test Suite
# ==============================================================================

library(testthat)

context("Proportion Confidence Intervals")

# ==============================================================================
# TEST DATA SETUP
# ==============================================================================

# Create synthetic test data with known properties
create_test_proportion_data <- function(n = 100, p = 0.5, seed = 12345) {
  set.seed(seed)
  list(
    values = sample(c(0, 1), n, replace = TRUE, prob = c(1-p, p)),
    weights = NULL,
    expected_p = p,
    expected_n = n
  )
}

# Create weighted test data
create_weighted_proportion_data <- function(n = 100, p = 0.5, seed = 12345) {
  set.seed(seed)
  list(
    values = sample(c(0, 1), n, replace = TRUE, prob = c(1-p, p)),
    weights = runif(n, 0.5, 2.0),  # Random weights
    expected_p = p,
    expected_n = n
  )
}

# ==============================================================================
# BASIC PROPORTION CALCULATION TESTS
# ==============================================================================

test_that("Basic proportion calculation works correctly", {
  # Test with p = 0.5
  data <- create_test_proportion_data(n = 100, p = 0.5)

  # Calculate observed proportion
  obs_p <- mean(data$values)

  # Should be approximately 0.5 (allowing for sampling variation)
  expect_true(obs_p >= 0.3 && obs_p <= 0.7)

  # Test with extreme proportions
  all_ones <- rep(1, 50)
  expect_equal(mean(all_ones), 1.0)

  all_zeros <- rep(0, 50)
  expect_equal(mean(all_zeros), 0.0)
})

test_that("Proportion calculation handles edge cases", {
  # Empty vector should error
  expect_error(mean(numeric(0)))

  # Single value
  expect_equal(mean(1), 1.0)
  expect_equal(mean(0), 0.0)

  # All NA should return NA
  expect_true(is.na(mean(c(NA, NA, NA), na.rm = FALSE)))
})

# ==============================================================================
# WILSON SCORE INTERVAL TESTS
# ==============================================================================

test_that("Wilson score intervals have correct coverage", {
  skip_if_not_installed("PropCIs")

  # Known values from statistical tables
  # For p=0.5, n=100, 95% CI should be approximately [0.40, 0.60]

  n <- 100
  x <- 50
  p <- x / n

  # Calculate Wilson interval
  ci <- PropCIs::scoreci(x, n, conf.level = 0.95)

  # Check properties
  expect_true(ci$conf.int[1] < p)  # Lower bound below p
  expect_true(ci$conf.int[2] > p)  # Upper bound above p
  expect_true(ci$conf.int[2] - ci$conf.int[1] > 0)  # Positive width

  # Approximate known value check (Wilson interval for p=0.5, n=100)
  expect_true(abs(ci$conf.int[1] - 0.40) < 0.05)
  expect_true(abs(ci$conf.int[2] - 0.60) < 0.05)
})

test_that("Wilson score handles extreme proportions better than normal", {
  skip_if_not_installed("PropCIs")

  # For p=0 or p=1, Wilson score should give reasonable intervals
  # while normal approximation would give nonsensical results

  # p = 0 (0 successes)
  ci_zero <- PropCIs::scoreci(0, 100, conf.level = 0.95)
  expect_true(ci_zero$conf.int[1] >= 0)  # Lower bound at or above 0
  expect_true(ci_zero$conf.int[2] < 0.05)  # Upper bound small but positive

  # p = 1 (all successes)
  ci_one <- PropCIs::scoreci(100, 100, conf.level = 0.95)
  expect_true(ci_one$conf.int[1] > 0.95)  # Lower bound near 1
  expect_true(ci_one$conf.int[2] <= 1.0)  # Upper bound at or below 1
})

# ==============================================================================
# NORMAL APPROXIMATION TESTS
# ==============================================================================

test_that("Normal approximation CI calculation is correct", {
  # Standard normal approximation formula:
  # p +/- z * sqrt(p(1-p)/n)

  n <- 100
  p <- 0.5
  z <- 1.96  # 95% CI

  se <- sqrt(p * (1 - p) / n)
  lower <- p - z * se
  upper <- p + z * se

  # Expected values
  expect_equal(round(lower, 3), 0.402)
  expect_equal(round(upper, 3), 0.598)

  # Check properties
  expect_true(lower < p)
  expect_true(upper > p)
  expect_equal(upper - lower, 2 * z * se)
})

test_that("Normal approximation fails appropriately for extreme proportions", {
  # For p near 0 or 1, normal approximation can give invalid intervals
  # (outside [0, 1])

  n <- 20
  p <- 0.05  # 1 success out of 20
  z <- 1.96

  se <- sqrt(p * (1 - p) / n)
  lower <- p - z * se

  # Lower bound would be negative - this is why we need Wilson score!
  expect_true(lower < 0)
})

# ==============================================================================
# BOOTSTRAP CI TESTS
# ==============================================================================

test_that("Bootstrap confidence intervals are reasonable", {
  skip_if_not_installed("boot")

  # Create test data
  data <- create_test_proportion_data(n = 100, p = 0.6)

  # Bootstrap function
  boot_prop <- function(data, indices) {
    mean(data[indices])
  }

  # Run bootstrap
  boot_results <- boot::boot(
    data = data$values,
    statistic = boot_prop,
    R = 1000
  )

  # Get percentile CI
  ci <- boot::boot.ci(boot_results, type = "perc", conf = 0.95)

  # Check properties
  expect_true(!is.null(ci$percent))
  expect_true(ci$percent[4] < ci$percent[5])  # Lower < Upper
  expect_true(ci$percent[4] >= 0 && ci$percent[5] <= 1)  # Valid bounds
})

test_that("Bootstrap handles small samples appropriately", {
  skip_if_not_installed("boot")

  # Small sample (n=10)
  data <- create_test_proportion_data(n = 10, p = 0.5)

  boot_prop <- function(data, indices) mean(data[indices])

  # Bootstrap should still work
  boot_results <- boot::boot(data = data$values, statistic = boot_prop, R = 500)

  expect_true(!is.null(boot_results))
  expect_equal(length(boot_results$t), 500)
})

# ==============================================================================
# WEIGHTED PROPORTION TESTS
# ==============================================================================

test_that("Weighted proportions calculate correctly", {
  # Create weighted data
  values <- c(1, 1, 0, 0, 1)
  weights <- c(2, 1, 1, 1, 2)

  # Weighted proportion = sum(values * weights) / sum(weights)
  weighted_p <- sum(values * weights) / sum(weights)

  # Expected: (1*2 + 1*1 + 0*1 + 0*1 + 1*2) / (2+1+1+1+2) = 5/7
  expect_equal(weighted_p, 5/7)
})

test_that("Effective n calculation for weighted data", {
  # Effective n = (sum(weights))^2 / sum(weights^2)

  weights <- c(1, 1, 1, 1, 1)  # Equal weights
  n_eff_equal <- sum(weights)^2 / sum(weights^2)
  expect_equal(n_eff_equal, 5)  # Should equal actual n

  # Unequal weights reduce effective n
  weights_unequal <- c(5, 1, 1, 1, 1)
  n_eff_unequal <- sum(weights_unequal)^2 / sum(weights_unequal^2)
  expect_true(n_eff_unequal < 5)  # Less than actual n
  expect_true(n_eff_unequal > 1)  # But greater than 1
})

# ==============================================================================
# EDGE CASE TESTS
# ==============================================================================

test_that("Handle proportion of 0%", {
  # All zeros
  values <- rep(0, 100)
  p <- mean(values)

  expect_equal(p, 0)

  # Wilson score should give [0, small positive number]
  skip_if_not_installed("PropCIs")
  ci <- PropCIs::scoreci(0, 100, conf.level = 0.95)
  expect_equal(ci$conf.int[1], 0)
  expect_true(ci$conf.int[2] > 0)
  expect_true(ci$conf.int[2] < 0.05)
})

test_that("Handle proportion of 100%", {
  # All ones
  values <- rep(1, 100)
  p <- mean(values)

  expect_equal(p, 1)

  # Wilson score should give [large number near 1, 1]
  skip_if_not_installed("PropCIs")
  ci <- PropCIs::scoreci(100, 100, conf.level = 0.95)
  expect_true(ci$conf.int[1] < 1)
  expect_true(ci$conf.int[1] > 0.95)
  expect_equal(ci$conf.int[2], 1)
})

test_that("Handle very small sample sizes", {
  # n = 1
  expect_equal(mean(1), 1.0)

  # n = 2
  values <- c(1, 0)
  expect_equal(mean(values), 0.5)

  # CI should still be calculable
  skip_if_not_installed("PropCIs")
  ci <- PropCIs::scoreci(1, 2, conf.level = 0.95)
  expect_true(!is.null(ci))
})

test_that("Handle missing values appropriately", {
  values <- c(1, 0, 1, NA, 0)

  # With na.rm = TRUE
  expect_equal(mean(values, na.rm = TRUE), 0.5)

  # With na.rm = FALSE
  expect_true(is.na(mean(values, na.rm = FALSE)))
})

# ==============================================================================
# CONFIDENCE LEVEL VARIATION TESTS
# ==============================================================================

test_that("Different confidence levels produce expected interval widths", {
  skip_if_not_installed("PropCIs")

  n <- 100
  x <- 50

  # 90% CI
  ci_90 <- PropCIs::scoreci(x, n, conf.level = 0.90)
  width_90 <- ci_90$conf.int[2] - ci_90$conf.int[1]

  # 95% CI
  ci_95 <- PropCIs::scoreci(x, n, conf.level = 0.95)
  width_95 <- ci_95$conf.int[2] - ci_95$conf.int[1]

  # 99% CI
  ci_99 <- PropCIs::scoreci(x, n, conf.level = 0.99)
  width_99 <- ci_99$conf.int[2] - ci_99$conf.int[1]

  # Higher confidence should give wider intervals
  expect_true(width_90 < width_95)
  expect_true(width_95 < width_99)
})

# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

test_that("Multiple CI methods give similar results for moderate proportions", {
  skip_if_not_installed("PropCIs")
  skip_if_not_installed("boot")

  n <- 100
  p <- 0.5
  set.seed(123)
  values <- rbinom(n, 1, p)
  x <- sum(values)

  # Wilson score
  ci_wilson <- PropCIs::scoreci(x, n, conf.level = 0.95)

  # Normal approximation
  p_obs <- x / n
  se <- sqrt(p_obs * (1 - p_obs) / n)
  ci_normal <- c(p_obs - 1.96 * se, p_obs + 1.96 * se)

  # Bootstrap
  boot_prop <- function(data, indices) mean(data[indices])
  boot_results <- boot::boot(values, boot_prop, R = 1000)
  ci_boot <- boot::boot.ci(boot_results, type = "perc", conf = 0.95)

  # All methods should be reasonably close for moderate p and large n
  wilson_width <- ci_wilson$conf.int[2] - ci_wilson$conf.int[1]
  normal_width <- ci_normal[2] - ci_normal[1]
  boot_width <- ci_boot$percent[5] - ci_boot$percent[4]

  # Widths should be within 20% of each other
  expect_true(abs(wilson_width - normal_width) / wilson_width < 0.2)
  expect_true(abs(wilson_width - boot_width) / wilson_width < 0.3)  # Bootstrap has more variation
})

# ==============================================================================
# PERFORMANCE TESTS
# ==============================================================================

test_that("Proportion CI calculations are reasonably fast", {
  skip_if_not_installed("PropCIs")

  # Should calculate 100 CIs in under 1 second
  start_time <- Sys.time()

  for (i in 1:100) {
    PropCIs::scoreci(50, 100, conf.level = 0.95)
  }

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  expect_true(elapsed < 1.0)
})

# ==============================================================================
# END OF TEST SUITE
# ==============================================================================
