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

# ==============================================================================
# END TO END: the question pipeline sizes intervals on the exact n_eff
# ==============================================================================

test_that("a weighted proportion question shows n_eff 19 and sizes its MOE on 18.846", {
  # Review 2026-09-24: 20 respondents weighted 1 and 5 weighted 3 give
  # n_eff = 35^2 / 65 = 18.846. The output still shows the whole number, the
  # interval now uses the exact value. p = (8 + 6) / 35 = 0.4.
  survey_data <- data.frame(
    Q1 = c(rep(1, 8), rep(0, 12), rep(1, 2), rep(0, 3)),
    wt = c(rep(1, 20), rep(3, 5)))
  q_row <- make_q_row(run_moe = "Y")
  q_row$Categories <- "1"

  out <- process_proportion_question(q_row, survey_data, "wt", make_config())

  expect_equal(out$result$n_eff, 19)
  expect_equal(out$result$moe$moe, qnorm(0.975) * sqrt(0.4 * 0.6 / (35^2 / 65)),
               tolerance = 1e-10)
})

# ==============================================================================
# NPS STANDARD ERROR: promoters and detractors are NOT independent
# ==============================================================================
# Review 2026-09-24. The normal and Bayesian NPS intervals used
# Var = p_p(1 - p_p)/n + p_d(1 - p_d)/n, "assuming independence". Promoters and
# detractors are shares of the same respondents, so Cov = -p_p p_d / n and
# Var(NPS) = [p_p(1 - p_p) + p_d(1 - p_d) + 2 p_p p_d] / n
#          = [(p_p + p_d) - (p_p - p_d)^2] / n,
# the formula docs/AUTHORITATIVE_GUIDE.md states and the tracker uses. Known
# answer: 50% promoters, 20% detractors, n = 100:
# Var = (0.70 - 0.09) / 100 = 0.0061, SE = 7.8102 NPS points (the old code
# gave 6.4031, an interval 18% too narrow).

nps_stats_fixture <- function(n_eff = 100) {
  list(nps_score = 30, pct_promoters = 50, pct_detractors = 20, pct_passives = 30,
       n_eff = n_eff, n_eff_exact = n_eff)
}

test_that("the NPS normal interval includes the promoter-detractor covariance", {
  result <- dispatch_nps_ci(nps_stats_fixture(), values = NULL, promoter_codes = 9:10,
                            detractor_codes = 0:6, weights = NULL,
                            q_row = make_q_row(run_moe = "Y"), config = make_config())
  expect_equal(result$moe_normal$se, 7.810250, tolerance = 1e-6)
  expect_equal(result$moe_normal$upper - 30, qnorm(0.975) * 7.810250, tolerance = 1e-6)
})

test_that("the NPS Bayesian interval uses the same standard error", {
  # A prior this wide leaves the posterior SD equal to the data SE.
  q_row <- make_q_row(run_moe = "N", run_credible = "Y", prior_mean = 0, prior_sd = 1e6)
  result <- dispatch_nps_ci(nps_stats_fixture(), values = NULL, promoter_codes = 9:10,
                            detractor_codes = 0:6, weights = NULL,
                            q_row = q_row, config = make_config())
  implied_sd <- (result$bayesian$upper - result$bayesian$lower) / (2 * qnorm(0.975))
  expect_equal(implied_sd, 7.810250, tolerance = 1e-5)
})

# ==============================================================================
# END TO END: mean and NPS questions through the real pipeline
# ==============================================================================
# 00_main.R now loads under testthat (setup.R sets script_dir_override), so
# the per-question processors are tested directly. Weights: 20 respondents at 1
# and 5 at 3, n_eff = 35^2 / 65 = 18.846, displayed as 19.

fractional_weights <- c(rep(1, 20), rep(3, 5))

test_that("a weighted mean question sizes its t interval on the exact n_eff", {
  survey_data <- data.frame(Q2 = c(rep(c(4, 6), 10), c(3, 5, 7, 9, 5)),
                            wt = fractional_weights)
  out <- process_mean_question(make_q_row(q_id = "Q2", run_moe = "Y"),
                               survey_data, "wt", make_config())
  expect_equal(out$result$n_eff, 19)
  expect_equal(out$result$t_dist$df, 35^2 / 65 - 1)
  expect_equal(out$result$t_dist$se, out$result$t_dist$sd / sqrt(35^2 / 65))
})

test_that("a weighted NPS question sizes its interval on the exact n_eff", {
  # Respondents 1-20 (weight 1): 10 promoters (10), 5 detractors (3), 5 passives (8).
  # Respondents 21-25 (weight 3): 2 promoters, 3 detractors.
  # Weighted: promoters 10 + 6 = 16, detractors 5 + 9 = 14, of 35.
  survey_data <- data.frame(
    Q3 = c(rep(10, 10), rep(3, 5), rep(8, 5), 10, 10, 0, 0, 0),
    wt = fractional_weights)
  q_row <- make_q_row(q_id = "Q3", run_moe = "Y")
  q_row$Promoter_Codes <- "9,10"
  q_row$Detractor_Codes <- "0,1,2,3,4,5,6"
  out <- process_nps_question(q_row, survey_data, "wt", make_config())

  pp <- 16 / 35; pd <- 14 / 35; n_eff <- 35^2 / 65
  expect_equal(out$result$n_eff, 19)
  expect_equal(out$result$moe_normal$se,
               100 * sqrt(((pp + pd) - (pp - pd)^2) / n_eff), tolerance = 1e-10)
})
