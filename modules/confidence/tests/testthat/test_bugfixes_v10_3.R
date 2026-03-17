# ==============================================================================
# TEST SUITE: Bug Fixes and New Features (v10.3)
# ==============================================================================
# Covers all bugs fixed and features added during the v10.3 review:
#   1. safe_extract_numeric() in ci_dispatcher.R
#   2. Type coercion in calculate_proportion_stats()
#   3. validate_conf_level() accepting non-standard levels
#   4. build_subset_callout() HTML generation
#   5. Sampling labels switch fallback for unknown methods
#   6. Weighted bootstrap CIs
#   7. Edge cases (n=2, zero variance, extreme proportions)
# ==============================================================================

library(testthat)

# ==============================================================================
# HELPERS (duplicated from test_ci_dispatcher.R for test isolation)
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
# 1. safe_extract_numeric() — ci_dispatcher.R
# ==============================================================================

test_that("safe_extract_numeric handles NULL", {
  expect_null(safe_extract_numeric(NULL))
})

test_that("safe_extract_numeric handles numeric input", {
  expect_equal(safe_extract_numeric(0.5), 0.5)
  expect_equal(safe_extract_numeric(100), 100)
  expect_equal(safe_extract_numeric(0), 0)
})

test_that("safe_extract_numeric handles NA", {
  expect_null(safe_extract_numeric(NA))
  expect_null(safe_extract_numeric(NA_real_))
  expect_null(safe_extract_numeric(NA_character_))
})

test_that("safe_extract_numeric handles character numeric strings", {
  expect_equal(safe_extract_numeric("0.5"), 0.5)
  expect_equal(safe_extract_numeric("100"), 100)
  expect_equal(safe_extract_numeric(" 3.14 "), 3.14)
})

test_that("safe_extract_numeric handles empty strings", {
  expect_null(safe_extract_numeric(""))
  expect_null(safe_extract_numeric("  "))
})

test_that("safe_extract_numeric handles non-numeric strings", {
  result <- safe_extract_numeric("abc")
  expect_true(is.na(result))
})

test_that("safe_extract_numeric handles length-0 input", {
  expect_null(safe_extract_numeric(character(0)))
  expect_null(safe_extract_numeric(numeric(0)))
})

# ==============================================================================
# 2. Type coercion in calculate_proportion_stats()
# ==============================================================================

test_that("calculate_proportion_stats coerces numeric values with character categories", {
  values <- c(1, 2, 3, 1, 2, 3, 1, 2, 3, 1)
  categories <- c("1", "2")  # character, but values are numeric
  result <- calculate_proportion_stats(values, categories)
  expect_true(result$success)
  expect_equal(result$proportion, 0.7)  # 7 out of 10
})

test_that("calculate_proportion_stats coerces character values with numeric categories", {
  values <- c("1", "2", "3", "1", "2", "3")
  categories <- c(1, 2)  # numeric, but values are character
  result <- calculate_proportion_stats(values, categories)
  expect_true(result$success)
  expect_equal(result$proportion, 4/6, tolerance = 1e-10)
})

test_that("calculate_proportion_stats handles matching types correctly", {
  # Baseline: types already match
  values <- c("Yes", "No", "Yes", "No", "Yes")
  result <- calculate_proportion_stats(values, "Yes")
  expect_true(result$success)
  expect_equal(result$proportion, 0.6)
})

test_that("calculate_proportion_stats handles non-convertible character categories gracefully", {
  values <- c(1, 2, 3, 4, 5)
  categories <- c("abc", "def")  # Can't convert to numeric
  result <- calculate_proportion_stats(values, categories)
  expect_true(result$success)
  expect_equal(result$proportion, 0)  # No matches after failed conversion
})

# ==============================================================================
# 3. validate_conf_level() accepting non-standard levels
# ==============================================================================

test_that("validate_conf_level accepts non-standard but valid levels", {
  expect_invisible(validate_conf_level(0.80))
  expect_invisible(validate_conf_level(0.85))
  expect_invisible(validate_conf_level(0.975))
  expect_invisible(validate_conf_level(0.50))
})

test_that("validate_conf_level still rejects out-of-range values", {
  expect_error(validate_conf_level(0), class = "turas_refusal")
  expect_error(validate_conf_level(1), class = "turas_refusal")
  expect_error(validate_conf_level(-0.5), class = "turas_refusal")
  expect_error(validate_conf_level(1.5), class = "turas_refusal")
})

test_that("validate_conf_level enforces allowed_values when specified", {
  expect_invisible(validate_conf_level(0.95, allowed_values = c(0.90, 0.95, 0.99)))
  expect_error(validate_conf_level(0.80, allowed_values = c(0.90, 0.95, 0.99)),
               class = "turas_refusal")
})

# ==============================================================================
# 4. build_subset_callout() — HTML data transformer
# ==============================================================================

test_that("build_subset_callout returns empty for non-subset results", {
  result <- list(is_subset = FALSE)
  expect_equal(build_subset_callout(result), "")
})

test_that("build_subset_callout returns empty when is_subset is NULL", {
  result <- list()
  expect_equal(build_subset_callout(result), "")
})

test_that("build_subset_callout generates HTML for subset results", {
  result <- list(
    is_subset = TRUE,
    filter_variable = "Region",
    filter_values = "North,South",
    subset_n = 150
  )
  html <- build_subset_callout(result)
  expect_true(grepl("Subset question", html))
  expect_true(grepl("Region", html))
  expect_true(grepl("North,South", html))
  expect_true(grepl("150", html))
  expect_true(grepl("ci-callout-warning", html))
})

test_that("build_subset_callout handles missing fields gracefully", {
  result <- list(is_subset = TRUE)
  html <- suppressWarnings(build_subset_callout(result))  # as.integer("unknown") warns
  expect_true(grepl("Subset question", html))
  expect_true(grepl("unknown", html))
})

test_that("build_subset_callout formats large n with comma separator", {
  result <- list(
    is_subset = TRUE,
    filter_variable = "Q1",
    filter_values = "1",
    subset_n = 1500
  )
  html <- build_subset_callout(result)
  expect_true(grepl("1,500", html))
})

# ==============================================================================
# 5. Sampling labels switch fallback
# ==============================================================================

test_that("get_sampling_labels returns not_specified for bizarre input", {
  labels <- get_sampling_labels("!@#$%^&*()")
  expect_equal(labels$sampling_method_normalised, "not_specified")
  expect_false(labels$is_probability)
})

test_that("get_sampling_labels returns not_specified for numeric input coerced to char", {
  labels <- get_sampling_labels("42")
  expect_equal(labels$sampling_method_normalised, "not_specified")
  expect_false(labels$is_probability)
})

test_that("get_sampling_labels handles whitespace-padded valid methods", {
  labels <- get_sampling_labels("  Random  ")
  expect_equal(labels$sampling_method_normalised, "random")
  expect_true(labels$is_probability)
})

# ==============================================================================
# 6. Weighted bootstrap CIs
# ==============================================================================

test_that("bootstrap_proportion_ci works with weights", {
  skip_if_not(exists("bootstrap_proportion_ci", mode = "function"),
              "bootstrap_proportion_ci not available")

  set.seed(42)
  values <- sample(c("Yes", "No"), 100, replace = TRUE, prob = c(0.6, 0.4))
  weights <- runif(100, 0.5, 2.0)

  result <- bootstrap_proportion_ci(
    data = values, categories = "Yes",
    weights = weights, B = 1000, conf_level = 0.95
  )

  expect_true(!is.null(result$lower))
  expect_true(!is.null(result$upper))
  expect_true(result$lower < result$upper)
  expect_true(result$lower >= 0)
  expect_true(result$upper <= 1)
})

test_that("bootstrap_mean_ci works with weights", {
  skip_if_not(exists("bootstrap_mean_ci", mode = "function"),
              "bootstrap_mean_ci not available")

  set.seed(42)
  values <- rnorm(100, mean = 50, sd = 10)
  weights <- runif(100, 0.5, 2.0)

  result <- bootstrap_mean_ci(
    values = values, weights = weights,
    B = 1000, conf_level = 0.95
  )

  expect_true(!is.null(result$lower))
  expect_true(!is.null(result$upper))
  expect_true(result$lower < result$upper)
  # CI should contain the approximate true mean
  expect_true(result$lower < 55 && result$upper > 45)
})

# ==============================================================================
# 7. Edge cases
# ==============================================================================

test_that("calculate_proportion_stats handles n=2 correctly", {
  values <- c("Yes", "No")
  result <- calculate_proportion_stats(values, "Yes")
  expect_true(result$success)
  expect_equal(result$proportion, 0.5)
  expect_equal(result$n_raw, 2)
})

test_that("calculate_mean_stats handles n=2 correctly", {
  values <- c(10, 20)
  result <- calculate_mean_stats(values)
  expect_true(result$success)
  expect_equal(result$mean, 15)
  expect_true(result$sd > 0)
})

test_that("calculate_mean_stats handles single value", {
  values <- c(42)
  result <- calculate_mean_stats(values)
  expect_true(result$success)
  expect_equal(result$mean, 42)
  # sd of single value is NA in base R
  expect_true(is.na(result$sd))
})

test_that("prepare_question_data handles single valid value", {
  values <- c(NA, 42, NA)
  result <- prepare_question_data(values)
  expect_true(result$success)
  expect_equal(result$values, 42)
  expect_equal(result$n_raw, 1)
})

test_that("calculate_proportion_stats handles extreme proportion p=0", {
  values <- c("No", "No", "No", "No", "No")
  result <- calculate_proportion_stats(values, "Yes")
  expect_true(result$success)
  expect_equal(result$proportion, 0)
})

test_that("calculate_proportion_stats handles extreme proportion p=1", {
  values <- c("Yes", "Yes", "Yes", "Yes", "Yes")
  result <- calculate_proportion_stats(values, "Yes")
  expect_true(result$success)
  expect_equal(result$proportion, 1)
})

test_that("calculate_nps_stats handles n=2 all promoters", {
  values <- c(9, 10)
  result <- calculate_nps_stats(values, c(9, 10), c(0:6))
  expect_true(result$success)
  expect_equal(result$nps_score, 100)
})

test_that("dispatch_proportion_ci handles Bayesian with numeric prior_mean from readxl", {
  # Simulates what happens when readxl reads Prior_Mean as numeric (not character)
  set.seed(42)
  values <- sample(c(0, 1), 100, replace = TRUE)
  p <- mean(values)
  config <- make_config()

  # Prior_Mean as numeric (the bug case)
  q_row <- data.frame(
    Question_ID = "Q1",
    Run_MOE = "N", Run_Wilson = "N",
    Run_Bootstrap = "N", Run_Credible = "Y",
    Prior_Mean = 0.5,  # numeric, not character
    Prior_SD = NA,
    Prior_N = 10,      # numeric
    stringsAsFactors = FALSE
  )

  result <- dispatch_proportion_ci(p, 100, values, 1, NULL, q_row, config)
  expect_true("bayesian" %in% names(result))
  expect_true(result$bayesian$lower < result$bayesian$upper)
})

test_that("dispatch_mean_ci handles Bayesian with numeric priors from readxl", {
  set.seed(42)
  values <- rnorm(50, mean = 7, sd = 2)
  config <- make_config()

  q_row <- data.frame(
    Question_ID = "Q1",
    Run_MOE = "N", Run_Wilson = "N",
    Run_Bootstrap = "N", Run_Credible = "Y",
    Prior_Mean = 7.0,   # numeric
    Prior_SD = 2.0,     # numeric
    Prior_N = 10,       # numeric
    stringsAsFactors = FALSE
  )

  result <- dispatch_mean_ci(mean(values), sd(values), 50, values, NULL, q_row, config)
  expect_true("bayesian" %in% names(result))
  expect_true(result$bayesian$lower < result$bayesian$upper)
})

test_that("dispatch_proportion_ci handles character prior_mean from config", {
  set.seed(42)
  values <- sample(c(0, 1), 100, replace = TRUE)
  config <- make_config()

  q_row <- data.frame(
    Question_ID = "Q1",
    Run_MOE = "N", Run_Wilson = "N",
    Run_Bootstrap = "N", Run_Credible = "Y",
    Prior_Mean = "0.5",  # character from CSV
    Prior_SD = NA,
    Prior_N = "10",      # character
    stringsAsFactors = FALSE
  )

  result <- dispatch_proportion_ci(mean(values), 100, values, 1, NULL, q_row, config)
  expect_true("bayesian" %in% names(result))
})

test_that("dispatch_proportion_ci handles empty string priors gracefully", {
  set.seed(42)
  values <- sample(c(0, 1), 100, replace = TRUE)
  config <- make_config()

  q_row <- data.frame(
    Question_ID = "Q1",
    Run_MOE = "N", Run_Wilson = "N",
    Run_Bootstrap = "N", Run_Credible = "Y",
    Prior_Mean = "",   # empty string
    Prior_SD = "",
    Prior_N = "",
    stringsAsFactors = FALSE
  )

  # Should use defaults, not crash
  result <- dispatch_proportion_ci(mean(values), 100, values, 1, NULL, q_row, config)
  expect_true("bayesian" %in% names(result))
})

# ==============================================================================
# 8. output_helpers.R — build_base_result_row preserves FALSE/0
# ==============================================================================

test_that("build_base_result_row preserves FALSE values", {
  row <- build_base_result_row("Q1", list(flag = FALSE, count = 0, name = "test"))
  expect_equal(row$flag, FALSE)
  expect_equal(row$count, 0)
  expect_equal(row$name, "test")
})

test_that("build_base_result_row converts NULL to NA", {
  row <- build_base_result_row("Q1", list(value = NULL))
  expect_true(is.na(row$value))
})

# ==============================================================================
# 9. NPS bootstrap with weights (dispatch_nps_ci)
# ==============================================================================

test_that("dispatch_nps_ci bootstrap works with weights", {
  set.seed(42)
  values <- sample(0:10, 100, replace = TRUE)
  weights <- runif(100, 0.5, 2.0)
  promoter_codes <- 9:10
  detractor_codes <- 0:6

  is_prom <- values %in% promoter_codes
  is_detr <- values %in% detractor_codes
  total_w <- sum(weights)
  pct_prom <- 100 * sum(weights[is_prom]) / total_w
  pct_detr <- 100 * sum(weights[is_detr]) / total_w

  nps_stats <- list(
    nps_score = pct_prom - pct_detr,
    pct_promoters = pct_prom,
    pct_detractors = pct_detr,
    n_eff = sum(weights)^2 / sum(weights^2)
  )

  config <- make_config(boot_iter = 1000)
  q_row <- make_q_row(run_moe = "N", run_bootstrap = "Y")

  result <- dispatch_nps_ci(nps_stats, values, promoter_codes, detractor_codes,
                             weights, q_row, config)

  expect_true("bootstrap" %in% names(result))
  expect_true(result$bootstrap$lower < result$bootstrap$upper)
})

# ==============================================================================
# 10. Wilson CI at boundary proportions
# ==============================================================================

test_that("Wilson CI handles p=0 without error", {
  skip_if_not(exists("calculate_proportion_ci_wilson", mode = "function"),
              "calculate_proportion_ci_wilson not available")

  result <- calculate_proportion_ci_wilson(0, 100, 0.95)
  expect_true(result$lower >= 0)
  expect_true(result$upper > 0)
})

test_that("Wilson CI handles p=1 without error", {
  skip_if_not(exists("calculate_proportion_ci_wilson", mode = "function"),
              "calculate_proportion_ci_wilson not available")

  result <- calculate_proportion_ci_wilson(1, 100, 0.95)
  expect_true(result$upper <= 1)
  expect_true(result$lower < 1)
})

# ==============================================================================
# END OF TEST SUITE
# ==============================================================================
