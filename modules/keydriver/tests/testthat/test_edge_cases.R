# ==============================================================================
# KEYDRIVER EDGE CASE TESTS
# ==============================================================================
#
# Tests for edge case handling in modules/keydriver/R/03_analysis.R
# and modules/keydriver/R/00_guard.R
#
# Covers:
#   - Single driver -> importance is 100%
#   - Near-zero variance driver -> TRS refusal
#   - Small sample -> TRS refusal with DATA_INSUFFICIENT_SAMPLE
#   - Data with NAs -> handled gracefully (complete cases or refusal)
#   - Large sample -> runs without error
#   - Empty data frame -> TRS refusal
#   - Non-numeric outcome -> TRS refusal
#   - Perfect collinearity -> TRS refusal
#   - Too many drivers for Shapley -> TRS refusal
#
# ==============================================================================

# Source test data generators
source(file.path(dirname(dirname(testthat::test_path())), "fixtures", "generate_test_data.R"))

# Source shared TRS infrastructure (required by guard/analysis functions)
shared_lib <- file.path(dirname(dirname(dirname(dirname(testthat::test_path())))), "shared", "lib")
source(file.path(shared_lib, "trs_refusal.R"))

# Source the modules under test
module_r_dir <- file.path(dirname(dirname(dirname(testthat::test_path()))), "R")
source(file.path(module_r_dir, "00_guard.R"))
source(file.path(module_r_dir, "02_term_mapping.R"))
source(file.path(module_r_dir, "03_analysis.R"))

# Define %||% locally in case it is not already available
`%||%` <- function(a, b) if (is.null(a)) b else a


# ==============================================================================
# SETUP: Generate edge case data
# ==============================================================================

edge_cases <- generate_edge_case_data(seed = 789)


# ==============================================================================
# Single driver
# ==============================================================================

test_that("single driver gets 100% importance for Shapley", {
  data <- edge_cases$single_driver
  config <- list(
    outcome_var = "outcome",
    driver_vars = "driver_1",
    weight_var = NULL,
    variables = data.frame(
      VariableName = c("outcome", "driver_1"),
      Label = c("Outcome", "Driver 1"),
      stringsAsFactors = FALSE
    )
  )

  model <- fit_keydriver_model(data, config)
  shapley <- calculate_shapley_values(model, data, config)

  expect_equal(length(shapley), 1)
  expect_equal(shapley[1], 100, tolerance = 0.01)
})

test_that("single driver gets 100% importance for Beta Weights", {
  data <- edge_cases$single_driver
  config <- list(
    outcome_var = "outcome",
    driver_vars = "driver_1",
    weight_var = NULL,
    variables = data.frame(
      VariableName = c("outcome", "driver_1"),
      Label = c("Outcome", "Driver 1"),
      stringsAsFactors = FALSE
    )
  )

  model <- fit_keydriver_model(data, config)
  beta_pct <- calculate_beta_weights(model, data, config)

  expect_equal(length(beta_pct), 1)
  expect_equal(as.numeric(beta_pct[1]), 100, tolerance = 0.01)
})

test_that("single driver gets 100% importance for Partial R2", {
  data <- edge_cases$single_driver
  config <- list(
    outcome_var = "outcome",
    driver_vars = "driver_1",
    weight_var = NULL,
    variables = data.frame(
      VariableName = c("outcome", "driver_1"),
      Label = c("Outcome", "Driver 1"),
      stringsAsFactors = FALSE
    )
  )

  pr2 <- calculate_importance_partial_r2(data, config)
  expect_equal(as.numeric(pr2), 100, tolerance = 0.01)
})


# ==============================================================================
# Near-zero variance driver
# ==============================================================================

test_that("zero variance driver produces TRS refusal in beta weights", {
  data <- edge_cases$zero_variance
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver_1", "driver_2", "driver_3"),
    weight_var = NULL,
    variables = data.frame(
      VariableName = c("outcome", "driver_1", "driver_2", "driver_3"),
      Label = c("Outcome", "Driver 1", "Driver 2 (constant)", "Driver 3"),
      stringsAsFactors = FALSE
    )
  )

  model <- fit_keydriver_model(data, config)

  # driver_2 has zero variance -> should refuse
  err <- tryCatch(
    calculate_beta_weights(model, data, config),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_true(grepl("ZERO_VARIANCE|ALIASED", err$code),
              info = paste0("Expected zero-variance or aliased refusal, got: ", err$code))
})

test_that("zero variance driver detected by validate_keydriver_data", {
  data <- edge_cases$zero_variance
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver_1", "driver_2", "driver_3"),
    weight_var = NULL
  )

  guard <- keydriver_guard_init()

  err <- tryCatch(
    validate_keydriver_data(data, config, guard),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_DRIVERS_ZERO_VARIANCE")
})


# ==============================================================================
# Small sample
# ==============================================================================

test_that("small sample (n=15) produces TRS refusal for 3 drivers", {
  data <- edge_cases$small_sample
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver_1", "driver_2", "driver_3"),
    weight_var = NULL
  )

  guard <- keydriver_guard_init()

  err <- tryCatch(
    validate_keydriver_data(data, config, guard),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_INSUFFICIENT_SAMPLE")
  expect_match(err$message, "sample", ignore.case = TRUE)
})

test_that("small sample refusal mentions minimum required size", {
  data <- edge_cases$small_sample
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver_1", "driver_2", "driver_3"),
    weight_var = NULL
  )

  guard <- keydriver_guard_init()

  err <- tryCatch(
    validate_keydriver_data(data, config, guard),
    turas_refusal = function(e) e
  )

  # min_n = max(30, 10 * 3) = 30
  expect_match(err$problem, "30",
               info = "Refusal should mention the minimum sample size requirement")
})


# ==============================================================================
# Data with NAs
# ==============================================================================

test_that("data with NAs is handled by complete cases in model fitting", {
  data <- edge_cases$with_nas
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver_1", "driver_2", "driver_3"),
    weight_var = NULL,
    variables = data.frame(
      VariableName = c("outcome", "driver_1", "driver_2", "driver_3"),
      Label = c("Outcome", "Driver 1", "Driver 2", "Driver 3"),
      stringsAsFactors = FALSE
    )
  )

  # lm() uses na.omit by default, so should work
  model <- fit_keydriver_model(data, config)
  expect_s3_class(model, "lm")

  # Correlations should also work (pairwise.complete.obs)
  correlations <- calculate_correlations(data, config)
  expect_true(is.matrix(correlations))
  expect_false(any(is.na(diag(correlations))))
})

test_that("data with NAs still produces valid importance scores", {
  data <- edge_cases$with_nas
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver_1", "driver_2", "driver_3"),
    weight_var = NULL,
    variables = data.frame(
      VariableName = c("outcome", "driver_1", "driver_2", "driver_3"),
      Label = c("Outcome", "Driver 1", "Driver 2", "Driver 3"),
      stringsAsFactors = FALSE
    )
  )

  correlations <- calculate_correlations(data, config)
  model <- fit_keydriver_model(data, config)
  importance <- calculate_importance_scores(model, data, correlations, config)

  expect_s3_class(importance, "data.frame")
  expect_equal(nrow(importance), 3)
  expect_true(all(importance$Shapley_Value >= 0))
})


# ==============================================================================
# Large sample
# ==============================================================================

test_that("large sample (n=2000) runs without error", {
  data <- edge_cases$large_sample
  config <- list(
    outcome_var = "outcome",
    driver_vars = paste0("driver_", 1:5),
    weight_var = NULL,
    variables = data.frame(
      VariableName = c("outcome", paste0("driver_", 1:5)),
      Label = c("Outcome", paste0("Driver ", 1:5)),
      stringsAsFactors = FALSE
    )
  )

  correlations <- calculate_correlations(data, config)
  model <- fit_keydriver_model(data, config)
  importance <- calculate_importance_scores(model, data, correlations, config)

  expect_s3_class(importance, "data.frame")
  expect_equal(nrow(importance), 5)
  expect_true(abs(sum(importance$Shapley_Value) - 100) < 1)
})


# ==============================================================================
# Empty data frame
# ==============================================================================

test_that("empty data frame produces TRS refusal", {
  data <- data.frame(
    outcome = numeric(0),
    driver_1 = numeric(0),
    driver_2 = numeric(0)
  )
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver_1", "driver_2"),
    weight_var = NULL
  )

  guard <- keydriver_guard_init()

  err <- tryCatch(
    validate_keydriver_data(data, config, guard),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_INSUFFICIENT_SAMPLE")
})


# ==============================================================================
# Non-numeric outcome
# ==============================================================================

test_that("non-numeric outcome is detected at model fitting stage", {
  data <- data.frame(
    outcome = sample(c("Low", "Medium", "High"), 100, replace = TRUE),
    driver_1 = rnorm(100),
    driver_2 = rnorm(100),
    stringsAsFactors = FALSE
  )
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver_1", "driver_2"),
    weight_var = NULL,
    variables = data.frame(
      VariableName = c("outcome", "driver_1", "driver_2"),
      Label = c("Outcome", "Driver 1", "Driver 2"),
      stringsAsFactors = FALSE
    )
  )

  # lm() will error or produce unexpected results with character outcome
  # The guard layer checks variance, but character outcome is not numeric
  # so sd() returns NA, which means the zero-variance check does not fire.
  # Instead, the model fitting itself should produce an error.
  result <- tryCatch(
    fit_keydriver_model(data, config),
    error = function(e) e
  )

  # Either a TRS refusal or a base R error is acceptable
  is_error <- inherits(result, "error") || inherits(result, "turas_refusal")
  expect_true(is_error,
              info = "Non-numeric outcome should cause an error at model fitting")
})


# ==============================================================================
# Perfect collinearity
# ==============================================================================

test_that("perfect collinearity causes TRS refusal in relative weights", {
  data <- edge_cases$perfect_correlation
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver_1", "driver_2", "driver_3"),
    weight_var = NULL,
    variables = data.frame(
      VariableName = c("outcome", "driver_1", "driver_2", "driver_3"),
      Label = c("Outcome", "Driver 1", "Driver 2 (=Driver 1)", "Driver 3"),
      stringsAsFactors = FALSE
    )
  )

  correlations <- calculate_correlations(data, config)
  model <- fit_keydriver_model(data, config)

  # Relative weights should refuse because correlation matrix is singular
  err <- tryCatch(
    calculate_relative_weights(model, correlations, config),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "MODEL_SINGULAR_MATRIX")
})


# ==============================================================================
# Too many drivers for Shapley
# ==============================================================================

test_that("more than 15 drivers causes TRS refusal for Shapley", {
  set.seed(99)
  n <- 200
  n_drivers <- 16

  drivers <- matrix(rnorm(n * n_drivers), nrow = n, ncol = n_drivers)
  colnames(drivers) <- paste0("driver_", seq_len(n_drivers))
  outcome <- rowSums(drivers[, 1:5]) + rnorm(n)
  data <- as.data.frame(cbind(outcome = outcome, drivers))

  config <- list(
    outcome_var = "outcome",
    driver_vars = paste0("driver_", seq_len(n_drivers)),
    weight_var = NULL,
    variables = data.frame(
      VariableName = c("outcome", paste0("driver_", seq_len(n_drivers))),
      Label = c("Outcome", paste0("Driver ", seq_len(n_drivers))),
      stringsAsFactors = FALSE
    )
  )

  model <- fit_keydriver_model(data, config)

  err <- tryCatch(
    calculate_shapley_values(model, data, config),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "FEATURE_SHAPLEY_TOO_MANY_DRIVERS")
})


# ==============================================================================
# Outcome with zero variance
# ==============================================================================

test_that("constant outcome produces TRS refusal in beta weights", {
  set.seed(100)
  data <- data.frame(
    outcome = rep(5, 100),
    driver_1 = rnorm(100),
    driver_2 = rnorm(100)
  )
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver_1", "driver_2"),
    weight_var = NULL,
    variables = data.frame(
      VariableName = c("outcome", "driver_1", "driver_2"),
      Label = c("Outcome", "Driver 1", "Driver 2"),
      stringsAsFactors = FALSE
    )
  )

  model <- fit_keydriver_model(data, config)

  err <- tryCatch(
    calculate_beta_weights(model, data, config),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_OUTCOME_ZERO_VARIANCE")
})

test_that("constant outcome detected by validate_keydriver_data", {
  data <- data.frame(
    outcome = rep(5, 100),
    driver_1 = rnorm(100),
    driver_2 = rnorm(100)
  )
  config <- list(
    outcome_var = "outcome",
    driver_vars = c("driver_1", "driver_2"),
    weight_var = NULL
  )

  guard <- keydriver_guard_init()

  err <- tryCatch(
    validate_keydriver_data(data, config, guard),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "DATA_OUTCOME_ZERO_VARIANCE")
})
