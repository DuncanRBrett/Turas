# ==============================================================================
# TEST SUITE: CI Dispatcher
# ==============================================================================
# Unit tests for dispatch_proportion_ci(), dispatch_mean_ci(), dispatch_nps_ci()
# Verifies correct method routing based on configuration flags.
# ==============================================================================

library(testthat)

context("CI Dispatcher")

# ==============================================================================
# HELPERS
# ==============================================================================

make_config <- function(conf_level = 0.95, boot_iter = 1000) {
  list(
    study_settings = list(
      Confidence_Level = conf_level,
      Bootstrap_Iterations = boot_iter
    )
  )
}

make_q_row <- function(q_id = "Q1", run_moe = "Y", run_wilson = "N",
                        run_bootstrap = "N", run_credible = "N",
                        prior_mean = NA, prior_sd = NA, prior_n = NA) {
  data.frame(
    Question_ID = q_id,
    Run_MOE = run_moe,
    Run_Wilson = run_wilson,
    Run_Bootstrap = run_bootstrap,
    Run_Credible = run_credible,
    Prior_Mean = prior_mean,
    Prior_SD = prior_sd,
    Prior_N = prior_n,
    stringsAsFactors = FALSE
  )
}

# ==============================================================================
# PROPORTION CI DISPATCH
# ==============================================================================

test_that("dispatch_proportion_ci: MOE only", {
  set.seed(42)
  values <- sample(c(0, 1), 100, replace = TRUE, prob = c(0.4, 0.6))
  p <- mean(values)
  n_eff <- 100
  config <- make_config()
  q_row <- make_q_row(run_moe = "Y", run_wilson = "N", run_bootstrap = "N", run_credible = "N")

  result <- dispatch_proportion_ci(p, n_eff, values, categories = 1, weights = NULL, q_row, config)

  expect_true("moe" %in% names(result))
  expect_false("wilson" %in% names(result))
  expect_false("bootstrap" %in% names(result))
  expect_false("bayesian" %in% names(result))
})

test_that("dispatch_proportion_ci: Wilson only", {
  set.seed(42)
  values <- sample(c(0, 1), 100, replace = TRUE, prob = c(0.4, 0.6))
  p <- mean(values)
  config <- make_config()
  q_row <- make_q_row(run_moe = "N", run_wilson = "Y")

  result <- dispatch_proportion_ci(p, 100, values, 1, NULL, q_row, config)

  expect_false("moe" %in% names(result))
  expect_true("wilson" %in% names(result))
})

test_that("dispatch_proportion_ci: all methods enabled", {
  set.seed(42)
  values <- sample(c(0, 1), 100, replace = TRUE, prob = c(0.5, 0.5))
  p <- mean(values)
  config <- make_config(boot_iter = 1000)
  q_row <- make_q_row(run_moe = "Y", run_wilson = "Y", run_bootstrap = "Y", run_credible = "Y")

  result <- dispatch_proportion_ci(p, 100, values, 1, NULL, q_row, config)

  expect_true("moe" %in% names(result))
  expect_true("wilson" %in% names(result))
  expect_true("bootstrap" %in% names(result))
  expect_true("bayesian" %in% names(result))
})

test_that("dispatch_proportion_ci: skips MOE when n_eff <= 0", {
  config <- make_config()
  q_row <- make_q_row(run_moe = "Y")

  result <- dispatch_proportion_ci(0.5, 0, c(0, 1), 1, NULL, q_row, config)

  expect_false("moe" %in% names(result))
  expect_true(length(result$warnings) > 0)
  expect_true(grepl("Effective n <= 0", result$warnings[1]))
})

test_that("dispatch_proportion_ci: warns on invalid prior_mean for Bayesian", {
  set.seed(42)
  values <- sample(c(0, 1), 100, replace = TRUE)
  config <- make_config()
  q_row <- make_q_row(run_credible = "Y", prior_mean = 2.0)  # Invalid: > 1

  result <- dispatch_proportion_ci(0.5, 100, values, 1, NULL, q_row, config)

  expect_false("bayesian" %in% names(result))
  expect_true(any(grepl("Prior_Mean=2.00 invalid", result$warnings)))
})

# ==============================================================================
# MEAN CI DISPATCH
# ==============================================================================

test_that("dispatch_mean_ci: t-distribution only (Run_MOE = Y)", {
  set.seed(42)
  values <- rnorm(100, mean = 7, sd = 2)
  config <- make_config()
  q_row <- make_q_row(run_moe = "Y", run_bootstrap = "N", run_credible = "N")

  result <- dispatch_mean_ci(mean(values), sd(values), 100, values, NULL, q_row, config)

  expect_true("t_dist" %in% names(result))
  expect_false("bootstrap" %in% names(result))
  expect_false("bayesian" %in% names(result))
})

test_that("dispatch_mean_ci: all methods enabled", {
  set.seed(42)
  values <- rnorm(100, mean = 7, sd = 2)
  config <- make_config(boot_iter = 1000)
  q_row <- make_q_row(run_moe = "Y", run_bootstrap = "Y", run_credible = "Y")

  result <- dispatch_mean_ci(mean(values), sd(values), 100, values, NULL, q_row, config)

  expect_true("t_dist" %in% names(result))
  expect_true("bootstrap" %in% names(result))
  expect_true("bayesian" %in% names(result))
})

test_that("dispatch_mean_ci: no methods produces empty result", {
  set.seed(42)
  values <- rnorm(50)
  config <- make_config()
  q_row <- make_q_row(run_moe = "N", run_bootstrap = "N", run_credible = "N")

  result <- dispatch_mean_ci(mean(values), sd(values), 50, values, NULL, q_row, config)

  expect_false("t_dist" %in% names(result))
  expect_false("bootstrap" %in% names(result))
  expect_false("bayesian" %in% names(result))
  expect_true("warnings" %in% names(result))
})

# ==============================================================================
# NPS CI DISPATCH
# ==============================================================================

test_that("dispatch_nps_ci: MOE returns NPS CI", {
  set.seed(42)
  values <- sample(0:10, 200, replace = TRUE)
  promoter_codes <- 9:10
  detractor_codes <- 0:6

  is_prom <- values %in% promoter_codes
  is_detr <- values %in% detractor_codes
  nps_stats <- list(
    nps_score = 100 * mean(is_prom) - 100 * mean(is_detr),
    pct_promoters = 100 * mean(is_prom),
    pct_detractors = 100 * mean(is_detr),
    n_eff = 200
  )

  config <- make_config()
  q_row <- make_q_row(run_moe = "Y", run_bootstrap = "N", run_credible = "N")

  result <- dispatch_nps_ci(nps_stats, values, promoter_codes, detractor_codes,
                             NULL, q_row, config)

  expect_true("moe_normal" %in% names(result))
  expect_true(result$moe_normal$lower < result$moe_normal$upper)
})

test_that("dispatch_nps_ci: bootstrap returns valid CI", {
  set.seed(42)
  values <- sample(0:10, 100, replace = TRUE)
  promoter_codes <- 9:10
  detractor_codes <- 0:6

  is_prom <- values %in% promoter_codes
  is_detr <- values %in% detractor_codes
  nps_stats <- list(
    nps_score = 100 * mean(is_prom) - 100 * mean(is_detr),
    pct_promoters = 100 * mean(is_prom),
    pct_detractors = 100 * mean(is_detr),
    n_eff = 100
  )

  config <- make_config(boot_iter = 1000)
  q_row <- make_q_row(run_bootstrap = "Y")

  result <- dispatch_nps_ci(nps_stats, values, promoter_codes, detractor_codes,
                             NULL, q_row, config)

  expect_true("bootstrap" %in% names(result))
  expect_true(result$bootstrap$lower < result$bootstrap$upper)
})
