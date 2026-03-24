# ==============================================================================
# INTEGRATION TEST SUITE: Excel Output Generation (07_output.R)
# ==============================================================================
# End-to-end tests for write_confidence_output() verifying:
#   - Excel file creation
#   - Sheet names and structure
#   - Column presence in each sheet
#   - TRS-compliant error handling
#
# Run with:
#   testthat::test_file("modules/confidence/tests/testthat/test_output_integration.R")
# ==============================================================================

library(testthat)

# ==============================================================================
# MOCK DATA BUILDERS
# ==============================================================================

build_mock_study_stats <- function() {
  data.frame(
    Metric = c("DEFF", "Effective_N", "Weight_CV"),
    Value = c(1.15, 870, 0.22),
    stringsAsFactors = FALSE
  )
}

build_mock_proportion_results <- function() {
  list(
    Q1 = list(
      proportion = 0.45,
      n = 100,
      n_eff = 90,
      category = "Yes",
      moe_normal = list(lower = 0.35, upper = 0.55, moe = 0.098)
    ),
    Q2 = list(
      proportion = 0.72,
      n = 200,
      n_eff = 180,
      category = "Agree",
      wilson = list(lower = 0.65, upper = 0.78)
    )
  )
}

build_mock_mean_results <- function() {
  list(
    Q3 = list(
      mean = 7.2,
      sd = 1.5,
      n = 150,
      n_eff = 140,
      t_dist = list(lower = 6.95, upper = 7.45, se = 0.12, df = 139)
    ),
    Q4 = list(
      mean = 3.8,
      sd = 0.9,
      n = 120,
      n_eff = 110,
      t_dist = list(lower = 3.62, upper = 3.98, se = 0.08, df = 109)
    )
  )
}

build_mock_nps_results <- function() {
  list(
    NPS1 = list(
      nps_score = 42,
      n = 300,
      n_eff = 280,
      promoters = 0.55,
      passives = 0.32,
      detractors = 0.13,
      ci = list(lower = 35, upper = 49)
    )
  )
}

build_mock_config <- function() {
  list(
    confidence_level = 0.95,
    sampling_method = "Not_Specified",
    study_settings = list(
      Confidence_Level = "0.95",
      Decimal_Separator = "."
    )
  )
}


# ==============================================================================
# FULL PIPELINE: write_confidence_output() - Happy Path
# ==============================================================================

test_that("write_confidence_output creates Excel file with all sheets when full data provided", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  result <- write_confidence_output(
    output_path       = out_path,
    study_level_stats = build_mock_study_stats(),
    proportion_results = build_mock_proportion_results(),
    mean_results      = build_mock_mean_results(),
    nps_results       = build_mock_nps_results(),
    config            = build_mock_config(),
    warnings          = c("Sample size below recommended minimum for Q1"),
    decimal_sep       = "."
  )

  expect_true(file.exists(out_path))
  expect_true(result)
})

test_that("write_confidence_output produces expected sheet names", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_confidence_output(
    output_path       = out_path,
    study_level_stats = build_mock_study_stats(),
    proportion_results = build_mock_proportion_results(),
    mean_results      = build_mock_mean_results(),
    nps_results       = build_mock_nps_results(),
    config            = build_mock_config(),
    warnings          = character(),
    decimal_sep       = "."
  )

  wb <- openxlsx::loadWorkbook(out_path)
  sheet_names <- names(wb)

  expect_true("Summary" %in% sheet_names)
  expect_true("Study_Level" %in% sheet_names)
  expect_true("Proportions_Detail" %in% sheet_names)
  expect_true("Means_Detail" %in% sheet_names)
  expect_true("Methodology" %in% sheet_names)
  expect_true("Warnings" %in% sheet_names)
  expect_true("Inputs" %in% sheet_names)
})

test_that("Summary sheet contains expected content", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_confidence_output(
    output_path       = out_path,
    study_level_stats = build_mock_study_stats(),
    proportion_results = build_mock_proportion_results(),
    mean_results      = build_mock_mean_results(),
    config            = build_mock_config(),
    decimal_sep       = "."
  )

  summary_data <- openxlsx::read.xlsx(out_path, sheet = "Summary")

  # Summary sheet should have content (not empty)
  expect_true(nrow(summary_data) > 0)
})

test_that("Study_Level sheet contains study statistics", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  study_stats <- build_mock_study_stats()

  write_confidence_output(
    output_path       = out_path,
    study_level_stats = study_stats,
    proportion_results = build_mock_proportion_results(),
    config            = build_mock_config(),
    decimal_sep       = "."
  )

  study_data <- openxlsx::read.xlsx(out_path, sheet = "Study_Level")

  # Should contain data rows
  expect_true(nrow(study_data) > 0)
})

test_that("Proportions_Detail sheet has expected columns", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_confidence_output(
    output_path       = out_path,
    proportion_results = build_mock_proportion_results(),
    config            = build_mock_config(),
    decimal_sep       = "."
  )

  # Title row occupies row 1-2; actual data table starts at row 3
  prop_data <- openxlsx::read.xlsx(out_path, sheet = "Proportions_Detail", startRow = 3)

  # Core columns from build_proportions_dataframe
  expect_true("Question_ID" %in% names(prop_data))
  expect_true(nrow(prop_data) >= 2) # Two questions in mock data
})

test_that("Means_Detail sheet has expected columns", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_confidence_output(
    output_path       = out_path,
    mean_results      = build_mock_mean_results(),
    config            = build_mock_config(),
    decimal_sep       = "."
  )

  means_data <- openxlsx::read.xlsx(out_path, sheet = "Means_Detail")

  expect_true(nrow(means_data) >= 2) # Two questions in mock data
})

test_that("NPS_Detail sheet is created when NPS results provided", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_confidence_output(
    output_path       = out_path,
    nps_results       = build_mock_nps_results(),
    config            = build_mock_config(),
    decimal_sep       = "."
  )

  wb <- openxlsx::loadWorkbook(out_path)
  sheet_names <- names(wb)

  expect_true("NPS_Detail" %in% sheet_names)
})


# ==============================================================================
# CONDITIONAL SHEETS
# ==============================================================================

test_that("Study_Level sheet is omitted when no study-level stats provided", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_confidence_output(
    output_path       = out_path,
    study_level_stats = NULL,
    proportion_results = build_mock_proportion_results(),
    config            = build_mock_config(),
    decimal_sep       = "."
  )

  wb <- openxlsx::loadWorkbook(out_path)
  sheet_names <- names(wb)

  expect_false("Study_Level" %in% sheet_names)
})

test_that("Proportions_Detail sheet is omitted when no proportion results", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_confidence_output(
    output_path       = out_path,
    mean_results      = build_mock_mean_results(),
    config            = build_mock_config(),
    decimal_sep       = "."
  )

  wb <- openxlsx::loadWorkbook(out_path)
  sheet_names <- names(wb)

  expect_false("Proportions_Detail" %in% sheet_names)
})

test_that("Means_Detail sheet is omitted when no mean results", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  write_confidence_output(
    output_path       = out_path,
    proportion_results = build_mock_proportion_results(),
    config            = build_mock_config(),
    decimal_sep       = "."
  )

  wb <- openxlsx::loadWorkbook(out_path)
  sheet_names <- names(wb)

  expect_false("Means_Detail" %in% sheet_names)
})


# ==============================================================================
# DECIMAL SEPARATOR SUPPORT
# ==============================================================================

test_that("write_confidence_output works with comma decimal separator", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  result <- write_confidence_output(
    output_path       = out_path,
    proportion_results = build_mock_proportion_results(),
    mean_results      = build_mock_mean_results(),
    config            = build_mock_config(),
    decimal_sep       = ","
  )

  expect_true(file.exists(out_path))
  expect_true(result)
})


# ==============================================================================
# ALWAYS-PRESENT SHEETS
# ==============================================================================

test_that("Methodology sheet is always created even with no analysis results", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  # No analysis results at all
  suppressWarnings(
    write_confidence_output(
      output_path = out_path,
      config      = build_mock_config(),
      decimal_sep = "."
    )
  )

  wb <- openxlsx::loadWorkbook(out_path)
  sheet_names <- names(wb)

  expect_true("Summary" %in% sheet_names)
  expect_true("Methodology" %in% sheet_names)
  expect_true("Warnings" %in% sheet_names)
  expect_true("Inputs" %in% sheet_names)
})


# ==============================================================================
# ERROR CASES
# ==============================================================================

test_that("write_confidence_output refuses invalid decimal separator", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  expect_error(
    write_confidence_output(
      output_path       = out_path,
      proportion_results = build_mock_proportion_results(),
      config            = build_mock_config(),
      decimal_sep       = ";"
    ),
    class = "turas_refusal"
  )
})

test_that("write_confidence_output refuses nonexistent output directory", {
  skip_if_not_installed("openxlsx")

  bad_path <- file.path("/nonexistent_dir_xyz", "output.xlsx")

  expect_error(
    write_confidence_output(
      output_path       = bad_path,
      proportion_results = build_mock_proportion_results(),
      config            = build_mock_config(),
      decimal_sep       = "."
    ),
    class = "turas_refusal"
  )
})

test_that("write_confidence_output warns when no results are provided", {
  skip_if_not_installed("openxlsx")

  out_path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out_path), add = TRUE)

  expect_warning(
    write_confidence_output(
      output_path = out_path,
      config      = build_mock_config(),
      decimal_sep = "."
    ),
    "No analysis results"
  )
})
