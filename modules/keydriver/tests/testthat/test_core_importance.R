# ==============================================================================
# KEYDRIVER CORE IMPORTANCE CALCULATION TESTS
# ==============================================================================
#
# Tests for modules/keydriver/R/03_analysis.R
#
# Covers:
#   - calculate_importance_scores() overall structure and invariants
#   - Importance percentages sum to ~100%
#   - Correct number of rows (one per driver)
#   - Ranks are valid (no duplicates within method, range 1..n_drivers)
#   - Non-negativity of each importance method
#   - Top driver has highest percentage and rank 1
#   - Expected column names in output
#   - Weighted correlation helper correctness
#
# ==============================================================================

# Locate module root robustly (works with test_file and test_dir)
.find_module_dir <- function() {
  ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(ofile)) {
    return(normalizePath(file.path(dirname(ofile), "..", ".."), mustWork = FALSE))
  }
  tp <- tryCatch(testthat::test_path(), error = function(e) ".")
  normalizePath(file.path(tp, "..", ".."), mustWork = FALSE)
}
module_dir <- .find_module_dir()
project_root <- normalizePath(file.path(module_dir, "..", ".."), mustWork = FALSE)

# Source test data generators
source(file.path(module_dir, "tests", "fixtures", "generate_test_data.R"))

# Source shared TRS infrastructure (required by guard/analysis functions)
shared_lib <- file.path(project_root, "modules", "shared", "lib")
source(file.path(shared_lib, "trs_refusal.R"))

# Source the modules under test
module_r_dir <- file.path(module_dir, "R")
source(file.path(module_r_dir, "00_guard.R"))
source(file.path(module_r_dir, "02_term_mapping.R"))
source(file.path(module_r_dir, "03_analysis.R"))

# Define %||% locally in case it is not already available
`%||%` <- function(a, b) if (is.null(a)) b else a


# ==============================================================================
# SETUP: Generate test data and config
# ==============================================================================

basic_data <- generate_basic_kda_data(n = 200, n_drivers = 5, seed = 42)

basic_config <- list(
  outcome_var = "outcome",
  driver_vars = paste0("driver_", 1:5),
  weight_var = NULL,
  variables = data.frame(
    VariableName = c("outcome", paste0("driver_", 1:5)),
    Label = c("Outcome", paste0("Driver ", 1:5)),
    stringsAsFactors = FALSE
  )
)


# ==============================================================================
# Helper: run full importance pipeline on basic data
# ==============================================================================

run_basic_importance <- function(data = basic_data, config = basic_config) {
  correlations <- calculate_correlations(data, config)
  model <- fit_keydriver_model(data, config)
  calculate_importance_scores(model, data, correlations, config)
}


# ==============================================================================
# Importance structure and invariants
# ==============================================================================

test_that("calculate_importance_scores returns data.frame with expected columns", {
  importance <- run_basic_importance()

  expect_s3_class(importance, "data.frame")

  expected_cols <- c(
    "Driver", "Label",
    "Beta_Weight", "Beta_Coefficient",
    "Relative_Weight", "Shapley_Value", "Correlation",
    "Beta_Rank", "RelWeight_Rank", "Shapley_Rank", "Corr_Rank",
    "Average_Rank"
  )
  for (col in expected_cols) {
    expect_true(col %in% names(importance),
                info = paste0("Missing expected column: ", col))
  }
})

test_that("importance has one row per driver", {
  importance <- run_basic_importance()
  expect_equal(nrow(importance), length(basic_config$driver_vars))
})

test_that("all driver names are present in results", {
  importance <- run_basic_importance()
  expect_setequal(importance$Driver, basic_config$driver_vars)
})


# ==============================================================================
# Importance percentages sum to ~100%
# ==============================================================================

test_that("Beta Weight percentages sum to approximately 100%", {
  importance <- run_basic_importance()
  expect_true(abs(sum(importance$Beta_Weight) - 100) < 1,
              info = paste0("Beta_Weight sum = ", sum(importance$Beta_Weight)))
})

test_that("Relative Weight percentages sum to approximately 100%", {
  importance <- run_basic_importance()
  expect_true(abs(sum(importance$Relative_Weight) - 100) < 1,
              info = paste0("Relative_Weight sum = ", sum(importance$Relative_Weight)))
})

test_that("Shapley Value percentages sum to approximately 100%", {
  importance <- run_basic_importance()
  expect_true(abs(sum(importance$Shapley_Value) - 100) < 1,
              info = paste0("Shapley_Value sum = ", sum(importance$Shapley_Value)))
})


# ==============================================================================
# Non-negativity of importance methods
# ==============================================================================

test_that("Beta Weight importance values are non-negative", {
  importance <- run_basic_importance()
  expect_true(all(importance$Beta_Weight >= 0),
              info = "Beta_Weight contains negative values")
})

test_that("Relative Weight importance values are non-negative", {
  importance <- run_basic_importance()
  expect_true(all(importance$Relative_Weight >= 0),
              info = "Relative_Weight contains negative values")
})

test_that("Shapley Value importance values are non-negative", {
  importance <- run_basic_importance()
  expect_true(all(importance$Shapley_Value >= 0),
              info = "Shapley_Value contains negative values")
})

test_that("Standardized beta coefficients can be negative (direction matters)", {
  importance <- run_basic_importance()
  # Beta_Coefficient is the signed standardized beta -- it can be negative

  expect_true(is.numeric(importance$Beta_Coefficient))
  expect_true(all(!is.na(importance$Beta_Coefficient)))
})


# ==============================================================================
# Rank validity
# ==============================================================================

test_that("Beta_Rank values are valid (1..n_drivers, no gaps)", {

  importance <- run_basic_importance()
  n <- nrow(importance)
  ranks <- sort(importance$Beta_Rank)
  # With ties.method = "average", ranks should be a permutation of 1..n
  # if no ties, or averaged ranks that still sum to n*(n+1)/2
  expect_equal(sum(ranks), n * (n + 1) / 2)
  expect_true(all(ranks >= 1 & ranks <= n))
})

test_that("RelWeight_Rank values are valid (1..n_drivers)", {
  importance <- run_basic_importance()
  n <- nrow(importance)
  ranks <- sort(importance$RelWeight_Rank)
  expect_equal(sum(ranks), n * (n + 1) / 2)
  expect_true(all(ranks >= 1 & ranks <= n))
})

test_that("Shapley_Rank values are valid (1..n_drivers)", {
  importance <- run_basic_importance()
  n <- nrow(importance)
  ranks <- sort(importance$Shapley_Rank)
  expect_equal(sum(ranks), n * (n + 1) / 2)
  expect_true(all(ranks >= 1 & ranks <= n))
})

test_that("Corr_Rank values are valid (1..n_drivers)", {
  importance <- run_basic_importance()
  n <- nrow(importance)
  ranks <- sort(importance$Corr_Rank)
  expect_equal(sum(ranks), n * (n + 1) / 2)
  expect_true(all(ranks >= 1 & ranks <= n))
})


# ==============================================================================
# Top driver correctness
# ==============================================================================

test_that("top driver by Shapley has rank 1 and highest Shapley percentage", {
  importance <- run_basic_importance()
  # Results are sorted by Shapley_Value descending
  top_driver <- importance[1, ]
  expect_equal(top_driver$Shapley_Rank, 1)
  expect_equal(top_driver$Shapley_Value, max(importance$Shapley_Value))
})

test_that("driver_1 has highest importance (known from data generation)", {
  # In generate_basic_kda_data, betas = seq(0.5, 0.1, length.out = 5)

  # so driver_1 has the strongest effect (beta = 0.5)
  importance <- run_basic_importance()
  top_shapley <- importance$Driver[which.max(importance$Shapley_Value)]
  expect_equal(top_shapley, "driver_1",
               info = "driver_1 should be the top driver given the data generation process")
})


# ==============================================================================
# Weighted analysis
# ==============================================================================

test_that("weighted correlations produce valid results", {
  wdata <- generate_weighted_kda_data(n = 200, seed = 456)
  wconfig <- list(
    outcome_var = "outcome",
    driver_vars = paste0("driver_", 1:5),
    weight_var = "weight",
    variables = data.frame(
      VariableName = c("outcome", paste0("driver_", 1:5)),
      Label = c("Outcome", paste0("Driver ", 1:5)),
      stringsAsFactors = FALSE
    )
  )

  correlations <- calculate_correlations(wdata, wconfig)

  # Correlation matrix should be square, symmetric, with 1s on diagonal
  vars <- c(wconfig$outcome_var, wconfig$driver_vars)
  expect_equal(nrow(correlations), length(vars))
  expect_equal(ncol(correlations), length(vars))
  expect_true(all(abs(diag(correlations) - 1) < 1e-10))
  # Symmetric
  expect_true(all(abs(correlations - t(correlations)) < 1e-10))
  # Values in [-1, 1]
  expect_true(all(correlations >= -1 - 1e-10 & correlations <= 1 + 1e-10))
})

test_that("weighted model produces valid importance scores", {
  wdata <- generate_weighted_kda_data(n = 200, seed = 456)
  wconfig <- list(
    outcome_var = "outcome",
    driver_vars = paste0("driver_", 1:5),
    weight_var = "weight",
    variables = data.frame(
      VariableName = c("outcome", paste0("driver_", 1:5)),
      Label = c("Outcome", paste0("Driver ", 1:5)),
      stringsAsFactors = FALSE
    )
  )

  correlations <- calculate_correlations(wdata, wconfig)
  model <- fit_keydriver_model(wdata, wconfig)
  importance <- calculate_importance_scores(model, wdata, correlations, wconfig)

  expect_s3_class(importance, "data.frame")
  expect_equal(nrow(importance), 5)
  expect_true(abs(sum(importance$Shapley_Value) - 100) < 1)
})


# ==============================================================================
# Partial R-squared importance
# ==============================================================================

test_that("calculate_importance_partial_r2 returns valid percentages", {
  importance <- calculate_importance_partial_r2(basic_data, basic_config)

  expect_true(is.numeric(importance))
  expect_equal(length(importance), length(basic_config$driver_vars))
  expect_true(all(importance >= 0))
  # Should sum to approximately 100% (partial R2 values normalized)
  expect_true(abs(sum(importance) - 100) < 1,
              info = paste0("Partial R2 sum = ", sum(importance)))
})
