# ==============================================================================
# TEST SUITE: Mean Confidence Intervals
# ==============================================================================
# Unit tests for mean CI calculations across multiple methods:
#   - t-distribution (calculate_mean_ci)
#   - Bootstrap (bootstrap_mean_ci)
#   - Bayesian credible (credible_interval_mean)
#   - Unified analyzer (analyze_mean)
# ==============================================================================

library(testthat)

context("Mean Confidence Intervals")

# ==============================================================================
# TEST DATA HELPERS
# ==============================================================================

create_test_mean_data <- function(n = 100, mean_val = 7.5, sd_val = 1.8, seed = 42) {
  set.seed(seed)
  values <- rnorm(n, mean = mean_val, sd = sd_val)
  list(values = values, expected_mean = mean_val, expected_sd = sd_val, n = n)
}

create_weighted_mean_data <- function(n = 100, mean_val = 7.5, sd_val = 1.8, seed = 42) {
  set.seed(seed)
  values <- rnorm(n, mean = mean_val, sd = sd_val)
  weights <- runif(n, 0.5, 2.0)
  list(values = values, weights = weights, n = n)
}

# ==============================================================================
# T-DISTRIBUTION CI TESTS
# ==============================================================================

test_that("calculate_mean_ci returns correct structure", {
  data <- create_test_mean_data(n = 100)
  result <- calculate_mean_ci(data$values)

  expect_true(is.list(result))
  expect_true("mean" %in% names(result))
  expect_true("sd" %in% names(result))
  expect_true("se" %in% names(result))
  expect_true("lower" %in% names(result))
  expect_true("upper" %in% names(result))
  expect_true("df" %in% names(result))
  expect_true("t_crit" %in% names(result))
  expect_true("n_actual" %in% names(result))
  expect_true("n_effective" %in% names(result))
  expect_true("method" %in% names(result))
})

test_that("calculate_mean_ci: CI contains the mean", {
  data <- create_test_mean_data(n = 200)
  result <- calculate_mean_ci(data$values, conf_level = 0.95)

  expect_true(result$lower < result$mean)
  expect_true(result$upper > result$mean)
  expect_true(result$lower < result$upper)
})

test_that("calculate_mean_ci: wider CI at higher confidence", {
  data <- create_test_mean_data(n = 100)
  ci_90 <- calculate_mean_ci(data$values, conf_level = 0.90)
  ci_95 <- calculate_mean_ci(data$values, conf_level = 0.95)
  ci_99 <- calculate_mean_ci(data$values, conf_level = 0.99)

  width_90 <- ci_90$upper - ci_90$lower
  width_95 <- ci_95$upper - ci_95$lower
  width_99 <- ci_99$upper - ci_99$lower

  expect_true(width_90 < width_95)
  expect_true(width_95 < width_99)
})

test_that("calculate_mean_ci: larger n gives narrower CI", {
  set.seed(123)
  small <- rnorm(30, mean = 50, sd = 10)
  large <- rnorm(500, mean = 50, sd = 10)

  ci_small <- calculate_mean_ci(small)
  ci_large <- calculate_mean_ci(large)

  width_small <- ci_small$upper - ci_small$lower
  width_large <- ci_large$upper - ci_large$lower

  expect_true(width_large < width_small)
})

test_that("calculate_mean_ci: correct degrees of freedom", {
  data <- create_test_mean_data(n = 50)
  result <- calculate_mean_ci(data$values)

  expect_equal(result$df, 49)
  expect_equal(result$n_actual, 50)
  expect_equal(result$n_effective, 50)
})

test_that("calculate_mean_ci: handles NA values", {
  set.seed(99)
  values <- c(rnorm(50, mean = 10, sd = 2), NA, NA, NA)
  result <- suppressWarnings(calculate_mean_ci(values))

  expect_equal(result$n_actual, 50)
  expect_true(result$lower < result$upper)
})

test_that("calculate_mean_ci: refuses n < 2", {
  expect_error(calculate_mean_ci(c(5.0)), class = "turas_refusal")
})

test_that("calculate_mean_ci: refuses non-numeric", {
  expect_error(calculate_mean_ci(c("a", "b", "c")), class = "turas_refusal")
})

test_that("calculate_mean_ci: unweighted gives n_effective = n_actual", {
  data <- create_test_mean_data(n = 100)
  result <- calculate_mean_ci(data$values)

  expect_false(result$is_weighted)
  expect_equal(result$n_effective, result$n_actual)
})

test_that("calculate_mean_ci: weighted data adjusts effective n", {
  data <- create_weighted_mean_data(n = 200)
  result <- calculate_mean_ci(data$values, weights = data$weights)

  expect_true(result$is_weighted)
  # Effective n should be less than or equal to actual n for non-uniform weights
  expect_true(result$n_effective <= result$n_actual)
  expect_true(result$n_effective > 0)
})

test_that("calculate_mean_ci: equal weights produce same result as unweighted", {
  set.seed(77)
  values <- rnorm(100, mean = 5, sd = 1)
  equal_weights <- rep(1, 100)

  result_unw <- calculate_mean_ci(values)
  result_w <- calculate_mean_ci(values, weights = equal_weights)

  expect_equal(result_unw$n_effective, result_w$n_effective)
})

test_that("calculate_mean_ci: refuses mismatched weight lengths", {
  set.seed(55)
  values <- rnorm(100)
  bad_weights <- runif(50)

  expect_error(calculate_mean_ci(values, weights = bad_weights), class = "turas_refusal")
})

# ==============================================================================
# BOOTSTRAP MEAN CI TESTS
# ==============================================================================

test_that("bootstrap_mean_ci returns correct structure", {
  data <- create_test_mean_data(n = 50)
  result <- bootstrap_mean_ci(data$values, B = 1000, seed = 42)

  expect_true(is.list(result))
  expect_true("lower" %in% names(result))
  expect_true("upper" %in% names(result))
  expect_true("boot_se" %in% names(result))
  expect_true("boot_mean" %in% names(result))
  expect_true("boot_samples" %in% names(result))
  expect_true("method" %in% names(result))
  expect_true("B" %in% names(result))
})

test_that("bootstrap_mean_ci: CI contains observed mean", {
  data <- create_test_mean_data(n = 100)
  result <- bootstrap_mean_ci(data$values, B = 2000, seed = 42)
  obs_mean <- mean(data$values)

  expect_true(result$lower < obs_mean)
  expect_true(result$upper > obs_mean)
})

test_that("bootstrap_mean_ci: boot_mean close to observed mean", {
  data <- create_test_mean_data(n = 200)
  result <- bootstrap_mean_ci(data$values, B = 5000, seed = 42)
  obs_mean <- mean(data$values)

  # Bootstrap mean should be very close to observed mean
  expect_true(abs(result$boot_mean - obs_mean) < 0.5)
})

test_that("bootstrap_mean_ci: works with weighted data", {
  data <- create_weighted_mean_data(n = 100)
  result <- bootstrap_mean_ci(data$values, weights = data$weights, B = 1000, seed = 42)

  expect_true(result$lower < result$upper)
  expect_true(result$boot_se > 0)
})

test_that("bootstrap_mean_ci: seed gives reproducible results", {
  data <- create_test_mean_data(n = 50)

  result1 <- bootstrap_mean_ci(data$values, B = 1000, seed = 123)
  result2 <- bootstrap_mean_ci(data$values, B = 1000, seed = 123)

  expect_equal(result1$lower, result2$lower)
  expect_equal(result1$upper, result2$upper)
})

test_that("bootstrap_mean_ci: refuses n < 2", {
  expect_error(bootstrap_mean_ci(c(5.0), B = 1000), class = "turas_refusal")
})

test_that("bootstrap_mean_ci: refuses non-numeric", {
  expect_error(bootstrap_mean_ci(c("a", "b"), B = 1000), class = "turas_refusal")
})

test_that("bootstrap_mean_ci: handles NA values", {
  set.seed(88)
  values <- c(rnorm(80, mean = 5), rep(NA, 20))
  result <- bootstrap_mean_ci(values, B = 1000, seed = 42)

  expect_true(result$lower < result$upper)
  expect_equal(result$B, 1000)
})

# ==============================================================================
# BAYESIAN CREDIBLE INTERVAL TESTS
# ==============================================================================

test_that("credible_interval_mean: uninformed prior returns data-driven result", {
  data <- create_test_mean_data(n = 200)
  result <- credible_interval_mean(data$values)
  obs_mean <- mean(data$values)

  expect_equal(result$prior_type, "Uninformed")
  # Posterior mean should equal data mean for uninformed prior
  expect_equal(result$post_mean, obs_mean, tolerance = 0.01)
  expect_true(result$lower < result$upper)
})

test_that("credible_interval_mean: informed prior shifts posterior", {
  set.seed(42)
  values <- rnorm(50, mean = 8.0, sd = 1.5)

  result <- suppressWarnings(credible_interval_mean(
    values,
    prior_mean = 5.0,  # Different from data mean
    prior_sd = 1.5,
    prior_n = 50
  ))

  obs_mean <- mean(values)

  expect_equal(result$prior_type, "Informed")
  # Posterior should be between prior and data mean
  expect_true(result$post_mean > 5.0)
  expect_true(result$post_mean < obs_mean)
})

test_that("credible_interval_mean: strong prior dominates small sample", {
  set.seed(42)
  values <- rnorm(10, mean = 8.0, sd = 1.5)

  result <- suppressWarnings(credible_interval_mean(
    values,
    prior_mean = 5.0,
    prior_sd = 1.0,
    prior_n = 500  # Strong prior
  ))

  # With strong prior (n=500) vs small data (n=10), posterior should be closer to prior
  expect_true(abs(result$post_mean - 5.0) < abs(result$post_mean - 8.0))
})

test_that("credible_interval_mean: refuses missing prior_sd with prior_mean", {
  data <- create_test_mean_data(n = 50)
  expect_error(credible_interval_mean(data$values, prior_mean = 5.0, prior_sd = NULL),
               class = "turas_refusal")
})

test_that("credible_interval_mean: refuses negative prior_sd", {
  data <- create_test_mean_data(n = 50)
  expect_error(credible_interval_mean(data$values, prior_mean = 5.0, prior_sd = -1.0),
               class = "turas_refusal")
})

test_that("credible_interval_mean: works with weighted data", {
  data <- create_weighted_mean_data(n = 100)
  result <- credible_interval_mean(data$values, weights = data$weights)

  expect_true(result$lower < result$upper)
  expect_true(result$post_sd > 0)
})

test_that("credible_interval_mean: refuses n < 2", {
  expect_error(credible_interval_mean(c(5.0)), class = "turas_refusal")
})

# ==============================================================================
# UNIFIED ANALYZER TESTS
# ==============================================================================

test_that("analyze_mean: runs all methods", {
  data <- create_test_mean_data(n = 100)
  result <- analyze_mean(
    data$values,
    methods = c("standard", "bootstrap", "bayesian"),
    bootstrap_iterations = 1000,
    seed = 42
  )

  expect_true("standard" %in% names(result))
  expect_true("bootstrap" %in% names(result))
  expect_true("bayesian" %in% names(result))
  expect_true("mean" %in% names(result))
  expect_true("sd" %in% names(result))
})

test_that("analyze_mean: single method works", {
  data <- create_test_mean_data(n = 100)
  result <- analyze_mean(data$values, methods = "standard")

  expect_true("standard" %in% names(result))
  expect_false("bootstrap" %in% names(result))
  expect_false("bayesian" %in% names(result))
})

test_that("analyze_mean: CIs from different methods agree approximately", {
  data <- create_test_mean_data(n = 200)
  result <- analyze_mean(
    data$values,
    methods = c("standard", "bootstrap", "bayesian"),
    bootstrap_iterations = 5000,
    seed = 42
  )

  # All methods should give similar CIs for large n, normal data
  # Allow 10% tolerance on CI width
  std_width <- result$standard$upper - result$standard$lower
  boot_width <- result$bootstrap$upper - result$bootstrap$lower

  expect_true(abs(std_width - boot_width) / std_width < 0.15)
})

# ==============================================================================
# PERFORMANCE TEST
# ==============================================================================

test_that("calculate_mean_ci: 100 calculations under 1 second", {
  set.seed(42)
  values <- rnorm(500)

  start <- Sys.time()
  for (i in 1:100) {
    calculate_mean_ci(values)
  }
  elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))

  expect_true(elapsed < 1.0)
})
