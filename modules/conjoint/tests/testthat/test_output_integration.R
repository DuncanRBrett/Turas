# ==============================================================================
# INTEGRATION TEST SUITE: Excel Output Generation (07_output.R)
# ==============================================================================
# End-to-end tests for write_conjoint_output() verifying:
#   - Excel file creation and sheet structure
#   - Core 8-sheet output for aggregate estimation
#   - Conditional HB-specific sheets
#   - Column presence in key sheets
#   - Error handling for invalid inputs
#
# Run with:
#   testthat::test_file("modules/conjoint/tests/testthat/test_output_integration.R")
# ==============================================================================

library(testthat)

# ==============================================================================
# MOCK DATA BUILDERS
# ==============================================================================

build_mock_utilities <- function() {
  data.frame(
    Attribute = c("Brand", "Brand", "Brand", "Price", "Price", "Price"),
    Level     = c("Alpha", "Beta", "Gamma", "Low", "Medium", "High"),
    Utility   = c(0.45, -0.10, -0.35, 0.60, 0.05, -0.65),
    Std_Error = c(0.08, 0.07, 0.09, 0.10, 0.06, 0.11),
    stringsAsFactors = FALSE
  )
}

build_mock_importance <- function() {
  data.frame(
    Attribute  = c("Brand", "Price"),
    Importance = c(35.2, 64.8),
    stringsAsFactors = FALSE
  )
}

build_mock_diagnostics <- function() {
  list(
    fit_statistics = list(
      mcfadden_r2    = 0.32,
      hit_rate       = 0.78,
      log_likelihood = -450.2,
      aic            = 920.4,
      bic            = 955.1
    ),
    n_parameters = 6
  )
}

build_mock_model_result <- function(method = "aggregate") {
  coefs <- c(Brand_Alpha = 0.45, Brand_Beta = -0.10, Brand_Gamma = -0.35,
             Price_Low = 0.60, Price_Medium = 0.05, Price_High = -0.65)
  se    <- c(Brand_Alpha = 0.08, Brand_Beta = 0.07, Brand_Gamma = 0.09,
             Price_Low = 0.10, Price_Medium = 0.06, Price_High = 0.11)

  list(
    method       = method,
    coefficients = coefs,
    std_errors   = se,
    converged    = TRUE
  )
}

build_mock_config <- function() {
  list(
    attributes = data.frame(
      AttributeName = c("Brand", "Price"),
      NumLevels     = c(3, 3),
      LevelNames    = c("Alpha,Beta,Gamma", "Low,Medium,High"),
      stringsAsFactors = FALSE
    ),
    estimation_method = "aggregate",
    n_alternatives    = 3
  )
}

build_mock_data_info <- function() {
  list(
    n_respondents = 200,
    n_choice_sets = 12,
    n_profiles    = 7200,
    has_none      = FALSE
  )
}


# ==============================================================================
# FULL PIPELINE: write_conjoint_output() - Happy Path
# ==============================================================================

test_that("write_conjoint_output creates an Excel file", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_conjoint_output(
    utilities    = build_mock_utilities(),
    importance   = build_mock_importance(),
    diagnostics  = build_mock_diagnostics(),
    model_result = build_mock_model_result(),
    config       = build_mock_config(),
    data_info    = build_mock_data_info(),
    output_file  = out_path
  )

  expect_true(file.exists(out_path))
  expect_true(file.info(out_path)$size > 0)
})

test_that("write_conjoint_output produces core 8 sheets for aggregate method", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_conjoint_output(
    utilities    = build_mock_utilities(),
    importance   = build_mock_importance(),
    diagnostics  = build_mock_diagnostics(),
    model_result = build_mock_model_result("aggregate"),
    config       = build_mock_config(),
    data_info    = build_mock_data_info(),
    output_file  = out_path
  )

  wb <- openxlsx::loadWorkbook(out_path)
  sheet_names <- names(wb)

  # Core sheets
  expect_true("Market Simulator" %in% sheet_names)
  expect_true("Attribute Importance" %in% sheet_names)
  expect_true("Part-Worth Utilities" %in% sheet_names)
  expect_true("Utility Chart Data" %in% sheet_names)
  expect_true("Model Fit" %in% sheet_names)
  expect_true("Configuration" %in% sheet_names)
  expect_true("Raw Coefficients" %in% sheet_names)
  expect_true("Data Summary" %in% sheet_names)

  # HB-specific sheets should NOT be present for aggregate
  expect_false("Individual Utilities" %in% sheet_names)
  expect_false("HB Diagnostics" %in% sheet_names)
  expect_false("Respondent Quality" %in% sheet_names)
})

test_that("Attribute Importance sheet contains importance data", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_conjoint_output(
    utilities    = build_mock_utilities(),
    importance   = build_mock_importance(),
    diagnostics  = build_mock_diagnostics(),
    model_result = build_mock_model_result(),
    config       = build_mock_config(),
    data_info    = build_mock_data_info(),
    output_file  = out_path
  )

  imp_data <- openxlsx::read.xlsx(out_path, sheet = "Attribute Importance")

  expect_true(nrow(imp_data) > 0)
})

test_that("Part-Worth Utilities sheet contains utility values", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_conjoint_output(
    utilities    = build_mock_utilities(),
    importance   = build_mock_importance(),
    diagnostics  = build_mock_diagnostics(),
    model_result = build_mock_model_result(),
    config       = build_mock_config(),
    data_info    = build_mock_data_info(),
    output_file  = out_path
  )

  util_data <- openxlsx::read.xlsx(out_path, sheet = "Part-Worth Utilities")

  expect_true(nrow(util_data) > 0)
})

test_that("Configuration sheet reflects attribute structure from config", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_conjoint_output(
    utilities    = build_mock_utilities(),
    importance   = build_mock_importance(),
    diagnostics  = build_mock_diagnostics(),
    model_result = build_mock_model_result(),
    config       = build_mock_config(),
    data_info    = build_mock_data_info(),
    output_file  = out_path
  )

  config_data <- openxlsx::read.xlsx(out_path, sheet = "Configuration")

  expect_true(nrow(config_data) >= 2) # Two attributes
  expect_true("Attribute" %in% names(config_data) ||
              "AttributeName" %in% names(config_data))
})

test_that("Data Summary sheet has sample statistics", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_conjoint_output(
    utilities    = build_mock_utilities(),
    importance   = build_mock_importance(),
    diagnostics  = build_mock_diagnostics(),
    model_result = build_mock_model_result(),
    config       = build_mock_config(),
    data_info    = build_mock_data_info(),
    output_file  = out_path
  )

  data_summary <- openxlsx::read.xlsx(out_path, sheet = "Data Summary")

  expect_true(nrow(data_summary) > 0)
})

test_that("Raw Coefficients sheet contains coefficient data", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_conjoint_output(
    utilities    = build_mock_utilities(),
    importance   = build_mock_importance(),
    diagnostics  = build_mock_diagnostics(),
    model_result = build_mock_model_result(),
    config       = build_mock_config(),
    data_info    = build_mock_data_info(),
    output_file  = out_path
  )

  raw_data <- openxlsx::read.xlsx(out_path, sheet = "Raw Coefficients")

  expect_true(nrow(raw_data) > 0)
})

test_that("Model Fit sheet contains fit statistics", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_conjoint_output(
    utilities    = build_mock_utilities(),
    importance   = build_mock_importance(),
    diagnostics  = build_mock_diagnostics(),
    model_result = build_mock_model_result(),
    config       = build_mock_config(),
    data_info    = build_mock_data_info(),
    output_file  = out_path
  )

  fit_data <- openxlsx::read.xlsx(out_path, sheet = "Model Fit")

  expect_true(nrow(fit_data) > 0)
})


# ==============================================================================
# ERROR CASES
# ==============================================================================

test_that("write_conjoint_output creates output directory if it does not exist", {
  skip_if_not_installed("openxlsx")

  # The function creates the directory itself (line 129 of 07_output.R)
  nested_dir <- file.path(tempdir(), paste0("conjoint_test_", Sys.getpid()))
  out_path <- file.path(nested_dir, "output.xlsx")
  on.exit(unlink(nested_dir, recursive = TRUE), add = TRUE)

  write_conjoint_output(
    utilities    = build_mock_utilities(),
    importance   = build_mock_importance(),
    diagnostics  = build_mock_diagnostics(),
    model_result = build_mock_model_result(),
    config       = build_mock_config(),
    data_info    = build_mock_data_info(),
    output_file  = out_path
  )

  expect_true(file.exists(out_path))
})

test_that("write_conjoint_output handles model_result with no coefficients", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  empty_model <- build_mock_model_result()
  empty_model$coefficients <- NULL
  empty_model$std_errors <- NULL

  # Should still succeed - Raw Coefficients sheet shows "No coefficients available"
  write_conjoint_output(
    utilities    = build_mock_utilities(),
    importance   = build_mock_importance(),
    diagnostics  = build_mock_diagnostics(),
    model_result = empty_model,
    config       = build_mock_config(),
    data_info    = build_mock_data_info(),
    output_file  = out_path
  )

  expect_true(file.exists(out_path))
})

test_that("write_conjoint_output handles diagnostics with NULL fit_statistics", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  empty_diag <- list(fit_statistics = NULL, n_parameters = 0)

  write_conjoint_output(
    utilities    = build_mock_utilities(),
    importance   = build_mock_importance(),
    diagnostics  = empty_diag,
    model_result = build_mock_model_result(),
    config       = build_mock_config(),
    data_info    = build_mock_data_info(),
    output_file  = out_path
  )

  expect_true(file.exists(out_path))
})
