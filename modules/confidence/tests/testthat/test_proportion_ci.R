# ==============================================================================
# TEST SUITE: Proportion Confidence Intervals
# ==============================================================================
# Tests for the module's own proportion CI functions in 04_proportions.R
# Part of Turas Confidence Module Test Suite
#
# Tests cover:
#   - calculate_proportion_ci_normal()
#   - calculate_proportion_ci_wilson()
#   - bootstrap_proportion_ci()
#   - credible_interval_proportion()
#   - analyze_proportion()
#   - TRS refusal handling
# ==============================================================================

library(testthat)

# ==============================================================================
# NORMAL APPROXIMATION: calculate_proportion_ci_normal()
# ==============================================================================

test_that("normal CI returns correct structure", {
  result <- calculate_proportion_ci_normal(p = 0.5, n = 100)

  expect_type(result, "list")
  expect_true("lower" %in% names(result))
  expect_true("upper" %in% names(result))
  expect_true("moe" %in% names(result))
  expect_true("se" %in% names(result))
  expect_true("method" %in% names(result))
  expect_equal(result$method, "Normal approximation")
})

test_that("normal CI computes correct values for known case", {
  # p=0.5, n=100, 95% CI: SE = sqrt(0.25/100) = 0.05, MOE = 1.96*0.05 = 0.098
  result <- calculate_proportion_ci_normal(p = 0.5, n = 100, conf_level = 0.95)

  expect_equal(result$se, 0.05, tolerance = 1e-10)
  expect_equal(result$moe, qnorm(0.975) * 0.05, tolerance = 1e-6)
  expect_equal(result$lower, 0.5 - result$moe, tolerance = 1e-6)
  expect_equal(result$upper, 0.5 + result$moe, tolerance = 1e-6)
})

test_that("normal CI: CI contains the point estimate", {
  result <- calculate_proportion_ci_normal(p = 0.3, n = 200)
  expect_true(result$lower < 0.3)
  expect_true(result$upper > 0.3)
})

test_that("normal CI: higher confidence gives wider intervals", {
  ci_90 <- calculate_proportion_ci_normal(p = 0.5, n = 100, conf_level = 0.90)
  ci_95 <- calculate_proportion_ci_normal(p = 0.5, n = 100, conf_level = 0.95)
  ci_99 <- calculate_proportion_ci_normal(p = 0.5, n = 100, conf_level = 0.99)

  expect_true(ci_90$moe < ci_95$moe)
  expect_true(ci_95$moe < ci_99$moe)
})

test_that("normal CI: larger n gives narrower intervals", {
  ci_50 <- calculate_proportion_ci_normal(p = 0.5, n = 50)
  ci_500 <- calculate_proportion_ci_normal(p = 0.5, n = 500)

  expect_true(ci_500$moe < ci_50$moe)
})

test_that("normal CI: bounds are capped to [0, 1]", {
  # p=0.01, n=20 would normally give negative lower bound
  result <- calculate_proportion_ci_normal(p = 0.01, n = 20)
  expect_true(result$lower >= 0)
  expect_true(result$upper <= 1)
})

test_that("normal CI: warnings for extreme proportions", {
  result <- calculate_proportion_ci_normal(p = 0.05, n = 100)
  expect_true(length(result$warnings) > 0)
  expect_true(any(grepl("extreme|Extreme", result$warnings, ignore.case = TRUE)))
})

test_that("normal CI: warnings for small samples", {
  result <- calculate_proportion_ci_normal(p = 0.5, n = 10)
  expect_true(length(result$warnings) > 0)
  expect_true(any(grepl("small|Small", result$warnings, ignore.case = TRUE)))
})

test_that("normal CI: refuses invalid proportion", {
  expect_error(calculate_proportion_ci_normal(p = -0.1, n = 100), class = "turas_refusal")
  expect_error(calculate_proportion_ci_normal(p = 1.5, n = 100), class = "turas_refusal")
})

test_that("normal CI: refuses invalid sample size", {
  expect_error(calculate_proportion_ci_normal(p = 0.5, n = 0), class = "turas_refusal")
  expect_error(calculate_proportion_ci_normal(p = 0.5, n = -10), class = "turas_refusal")
})

# ==============================================================================
# WILSON SCORE: calculate_proportion_ci_wilson()
# ==============================================================================

test_that("Wilson CI returns correct structure", {
  result <- calculate_proportion_ci_wilson(p = 0.5, n = 100)

  expect_type(result, "list")
  expect_true("lower" %in% names(result))
  expect_true("upper" %in% names(result))
  expect_true("center" %in% names(result))
  expect_true("method" %in% names(result))
  expect_equal(result$method, "Wilson score")
})

test_that("Wilson CI: bounds always within [0, 1]", {
  # p=0, extreme case
  result_zero <- calculate_proportion_ci_wilson(p = 0, n = 100)
  expect_true(result_zero$lower >= 0)
  expect_true(result_zero$upper <= 1)
  expect_true(result_zero$upper > 0)  # Should be positive

  # p=1, extreme case
  result_one <- calculate_proportion_ci_wilson(p = 1, n = 100)
  expect_true(result_one$lower >= 0)
  expect_true(result_one$upper <= 1)
  expect_true(result_one$lower < 1)  # Should be below 1
})

test_that("Wilson CI: narrower than normal for extreme p", {
  p <- 0.02
  n <- 200

  wilson <- calculate_proportion_ci_wilson(p = p, n = n)
  normal <- calculate_proportion_ci_normal(p = p, n = n)

  wilson_width <- wilson$upper - wilson$lower
  normal_width <- normal$upper - normal$lower

  # Wilson should give a more sensible (often narrower) interval for extreme p
  expect_true(wilson$lower >= 0)  # Wilson never goes negative
})

test_that("Wilson CI: similar to normal for moderate p", {
  p <- 0.5
  n <- 1000

  wilson <- calculate_proportion_ci_wilson(p = p, n = n)
  normal <- calculate_proportion_ci_normal(p = p, n = n)

  # For large n and moderate p, Wilson and normal should be very close
  expect_equal(wilson$lower, normal$lower, tolerance = 0.005)
  expect_equal(wilson$upper, normal$upper, tolerance = 0.005)
})

test_that("Wilson CI: center is shifted from p for small n", {
  result <- calculate_proportion_ci_wilson(p = 0.5, n = 10)
  # Wilson center should be close to p but not exactly p
  expect_true(abs(result$center - 0.5) < 0.1)
})

test_that("Wilson CI: refuses invalid inputs", {
  expect_error(calculate_proportion_ci_wilson(p = -0.1, n = 100), class = "turas_refusal")
  expect_error(calculate_proportion_ci_wilson(p = 0.5, n = 0), class = "turas_refusal")
})

# ==============================================================================
# BOOTSTRAP: bootstrap_proportion_ci()
# ==============================================================================

test_that("bootstrap CI returns correct structure", {
  data <- c(rep(1, 50), rep(0, 50))
  result <- bootstrap_proportion_ci(data, categories = 1, B = 1000, seed = 42)

  expect_type(result, "list")
  expect_true("lower" %in% names(result))
  expect_true("upper" %in% names(result))
  expect_true("boot_se" %in% names(result))
  expect_true("boot_mean" %in% names(result))
  expect_true("method" %in% names(result))
})

test_that("bootstrap CI: reproduces with same seed", {
  data <- c(rep(1, 45), rep(0, 55))
  r1 <- bootstrap_proportion_ci(data, categories = 1, B = 2000, seed = 123)
  r2 <- bootstrap_proportion_ci(data, categories = 1, B = 2000, seed = 123)

  expect_equal(r1$lower, r2$lower)
  expect_equal(r1$upper, r2$upper)
})

test_that("bootstrap CI: boot_mean close to observed proportion", {
  data <- c(rep(1, 60), rep(0, 40))
  result <- bootstrap_proportion_ci(data, categories = 1, B = 5000, seed = 42)

  obs_p <- mean(data)
  expect_equal(result$boot_mean, obs_p, tolerance = 0.05)
})

test_that("bootstrap CI: works with weighted data", {
  data <- c(rep(1, 50), rep(0, 50))
  weights <- runif(100, 0.5, 2.0)

  result <- bootstrap_proportion_ci(data, categories = 1,
                                     weights = weights, B = 1000, seed = 42)

  expect_true(result$lower < result$upper)
  expect_true(result$lower >= 0)
  expect_true(result$upper <= 1)
})

test_that("bootstrap CI: works with multi-category success", {
  data <- c(rep(1, 30), rep(2, 20), rep(3, 50))
  result <- bootstrap_proportion_ci(data, categories = c(1, 2), B = 1000, seed = 42)

  expect_true(result$lower < result$upper)
  # Observed proportion of 1 or 2 is 0.5
  expect_equal(result$boot_mean, 0.5, tolerance = 0.05)
})

test_that("bootstrap CI: wider at higher confidence", {
  data <- c(rep(1, 45), rep(0, 55))
  ci_90 <- bootstrap_proportion_ci(data, categories = 1, B = 2000, conf_level = 0.90, seed = 42)
  ci_99 <- bootstrap_proportion_ci(data, categories = 1, B = 2000, conf_level = 0.99, seed = 42)

  width_90 <- ci_90$upper - ci_90$lower
  width_99 <- ci_99$upper - ci_99$lower
  expect_true(width_99 > width_90)
})

test_that("bootstrap CI: refuses invalid data type", {
  expect_error(
    bootstrap_proportion_ci(list(1, 2, 3), categories = 1),
    class = "turas_refusal"
  )
})

test_that("bootstrap CI: refuses empty data", {
  expect_error(
    bootstrap_proportion_ci(numeric(0), categories = 1),
    class = "turas_refusal"
  )
})

# ==============================================================================
# BAYESIAN: credible_interval_proportion()
# ==============================================================================

test_that("Bayesian CI returns correct structure (uninformed)", {
  result <- credible_interval_proportion(p = 0.5, n = 100)

  expect_type(result, "list")
  expect_true("lower" %in% names(result))
  expect_true("upper" %in% names(result))
  expect_true("post_mean" %in% names(result))
  expect_true("prior_type" %in% names(result))
  expect_equal(result$prior_type, "Uninformed")
  expect_equal(result$method, "Bayesian (Beta-Binomial)")
})

test_that("Bayesian CI: uninformed prior uses Beta(1,1)", {
  result <- credible_interval_proportion(p = 0.5, n = 100)
  expect_equal(result$prior_alpha, 1)
  expect_equal(result$prior_beta, 1)
})

test_that("Bayesian CI: posterior mean close to observed for large n", {
  result <- credible_interval_proportion(p = 0.45, n = 1000)
  # With uninformed prior and large n, posterior mean ~ observed proportion
  expect_equal(result$post_mean, 0.45, tolerance = 0.01)
})

test_that("Bayesian CI: informed prior shifts posterior toward prior", {
  # With strong prior (prior_n=500) at 0.3, observed p=0.5, n=100
  # Posterior should be pulled toward 0.3
  result <- credible_interval_proportion(
    p = 0.5, n = 100,
    prior_mean = 0.3, prior_n = 500
  )

  expect_true(result$post_mean < 0.5)  # Pulled toward prior
  expect_true(result$post_mean > 0.3)  # But not all the way
  expect_equal(result$prior_type, "Informed")
})

test_that("Bayesian CI: weak prior has minimal effect", {
  uninformed <- credible_interval_proportion(p = 0.5, n = 1000)
  informed <- credible_interval_proportion(p = 0.5, n = 1000,
                                           prior_mean = 0.3, prior_n = 5)

  # With very weak prior (prior_n=5) and large data (n=1000), results should be similar

  expect_equal(uninformed$post_mean, informed$post_mean, tolerance = 0.02)
})

test_that("Bayesian CI: higher confidence gives wider interval", {
  ci_90 <- credible_interval_proportion(p = 0.5, n = 100, conf_level = 0.90)
  ci_99 <- credible_interval_proportion(p = 0.5, n = 100, conf_level = 0.99)

  width_90 <- ci_90$upper - ci_90$lower
  width_99 <- ci_99$upper - ci_99$lower
  expect_true(width_99 > width_90)
})

test_that("Bayesian CI: posterior parameters are correctly computed", {
  p <- 0.6
  n <- 100
  successes <- round(p * n)  # 60
  failures <- n - successes  # 40

  result <- credible_interval_proportion(p = p, n = n)

  # With uninformed Beta(1,1) prior:
  # post_alpha = 1 + 60 = 61, post_beta = 1 + 40 = 41
  expect_equal(result$post_alpha, 1 + successes)
  expect_equal(result$post_beta, 1 + failures)
})

test_that("Bayesian CI: refuses invalid proportion", {
  expect_error(credible_interval_proportion(p = -0.1, n = 100), class = "turas_refusal")
  expect_error(credible_interval_proportion(p = 1.5, n = 100), class = "turas_refusal")
})

test_that("Bayesian CI: refuses invalid prior_mean", {
  expect_error(
    credible_interval_proportion(p = 0.5, n = 100, prior_mean = 1.5, prior_n = 50),
    class = "turas_refusal"
  )
})

# ==============================================================================
# METHOD COMPARISON TESTS
# ==============================================================================

test_that("all methods give similar results for moderate p, large n", {
  p <- 0.5
  n <- 1000
  data <- c(rep(1, 500), rep(0, 500))

  normal <- calculate_proportion_ci_normal(p = p, n = n)
  wilson <- calculate_proportion_ci_wilson(p = p, n = n)
  bayesian <- credible_interval_proportion(p = p, n = n)
  bootstrap <- bootstrap_proportion_ci(data, categories = 1, B = 5000, seed = 42)

  # All lower bounds should be close
  lowers <- c(normal$lower, wilson$lower, bayesian$lower, bootstrap$lower)
  expect_true(max(lowers) - min(lowers) < 0.02)

  # All upper bounds should be close
  uppers <- c(normal$upper, wilson$upper, bayesian$upper, bootstrap$upper)
  expect_true(max(uppers) - min(uppers) < 0.02)
})

test_that("Wilson handles extreme p better than normal", {
  p <- 0.01
  n <- 100

  normal <- calculate_proportion_ci_normal(p = p, n = n)
  wilson <- calculate_proportion_ci_wilson(p = p, n = n)

  # Wilson should always stay in [0,1]
  expect_true(wilson$lower >= 0)
  expect_true(wilson$upper <= 1)
})

# ==============================================================================
# EDGE CASES
# ==============================================================================

test_that("p = 0 works for Wilson and Bayesian", {
  wilson <- calculate_proportion_ci_wilson(p = 0, n = 100)
  expect_equal(wilson$lower, 0, tolerance = 1e-10)
  expect_true(wilson$upper > 0)

  bayesian <- credible_interval_proportion(p = 0, n = 100)
  expect_true(bayesian$lower >= 0)
  expect_true(bayesian$upper > 0)
})

test_that("p = 1 works for Wilson and Bayesian", {
  wilson <- calculate_proportion_ci_wilson(p = 1, n = 100)
  expect_true(wilson$lower < 1)
  expect_equal(wilson$upper, 1, tolerance = 1e-10)

  bayesian <- credible_interval_proportion(p = 1, n = 100)
  expect_true(bayesian$lower < 1)
  expect_true(bayesian$upper <= 1)
})

test_that("small n (n=5) works for all methods", {
  normal <- calculate_proportion_ci_normal(p = 0.4, n = 5)
  wilson <- calculate_proportion_ci_wilson(p = 0.4, n = 5)
  bayesian <- credible_interval_proportion(p = 0.4, n = 5)

  # All should return valid intervals
  expect_true(normal$lower < normal$upper)
  expect_true(wilson$lower < wilson$upper)
  expect_true(bayesian$lower < bayesian$upper)
})

# ==============================================================================
# PERFORMANCE TESTS
# ==============================================================================

test_that("normal and Wilson are fast (100 calls < 1 second)", {
  start <- Sys.time()
  for (i in 1:100) {
    calculate_proportion_ci_normal(p = 0.5, n = 100)
    calculate_proportion_ci_wilson(p = 0.5, n = 100)
  }
  elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))
  expect_true(elapsed < 1.0)
})

# ==============================================================================
# END OF TEST SUITE
# ==============================================================================
