# ==============================================================================
# TEST SUITE: Output Generation (07_output.R)
# ==============================================================================
# Tests for Excel output generation functions:
#   - write_confidence_output()
#   - validate_confidence_output_path()
#   - add_summary_sheet()
#   - add_study_level_sheet()
#   - add_proportions_detail_sheet()
#   - add_means_detail_sheet()
#   - add_methodology_sheet()
#   - add_warnings_sheet()
#   - add_inputs_sheet()
#   - build_proportions_dataframe()
#   - build_means_dataframe()
#
# Run with:
#   testthat::test_file("modules/confidence/tests/testthat/test_output.R")
# ==============================================================================

library(testthat)

context("Output Generation")

# ==============================================================================
# HELPERS
# ==============================================================================

#' Create mock proportion results
mock_proportion_results <- function() {
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

#' Create mock mean results
mock_mean_results <- function() {
  list(
    Q3 = list(
      mean = 7.2,
      sd = 1.5,
      n = 150,
      n_eff = 140,
      t_dist = list(lower = 6.95, upper = 7.45, se = 0.12, df = 139)
    )
  )
}

#' Create mock study-level stats
mock_study_stats <- function() {
  data.frame(
    Metric = c("DEFF", "Effective_N", "Weight_CV"),
    Value = c(1.15, 870, 0.22),
    stringsAsFactors = FALSE
  )
}

#' Create mock config
mock_config <- function() {
  list(
    confidence_level = 0.95,
    study_settings = list(
      Confidence_Level = "0.95",
      Decimal_Separator = "."
    )
  )
}


# ==============================================================================
# validate_confidence_output_path()
# ==============================================================================

test_that("validate_confidence_output_path accepts valid path and decimal_sep", {
  output_path <- file.path(tempdir(), "test_output.xlsx")

  result <- validate_confidence_output_path(output_path, ".")

  expect_true(result)
})

test_that("validate_confidence_output_path accepts comma decimal separator", {
  output_path <- file.path(tempdir(), "test_output.xlsx")

  result <- validate_confidence_output_path(output_path, ",")

  expect_true(result)
})

test_that("validate_confidence_output_path refuses invalid decimal_sep", {
  output_path <- file.path(tempdir(), "test_output.xlsx")

  expect_error(
    validate_confidence_output_path(output_path, ";"),
    class = "turas_refusal"
  )
})

test_that("validate_confidence_output_path refuses nonexistent output directory", {
  output_path <- file.path("/nonexistent/dir/output.xlsx")

  expect_error(
    validate_confidence_output_path(output_path, "."),
    class = "turas_refusal"
  )
})


# ==============================================================================
# build_proportions_dataframe()
# ==============================================================================

test_that("build_proportions_dataframe returns empty df for empty input", {
  result <- build_proportions_dataframe(list())

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 0)
})

test_that("build_proportions_dataframe builds correct structure from results", {
  prop_results <- mock_proportion_results()

  result <- build_proportions_dataframe(prop_results)

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 2)
  expect_true("Question_ID" %in% names(result))
  expect_true("Proportion" %in% names(result))
  expect_true("Sample_Size" %in% names(result))
})

test_that("build_proportions_dataframe includes MOE columns when present", {
  prop_results <- mock_proportion_results()

  result <- build_proportions_dataframe(prop_results)

  # Q1 has moe_normal
  expect_true("MOE_Normal_Lower" %in% names(result))
  expect_true("MOE_Normal_Upper" %in% names(result))
  expect_true("MOE" %in% names(result))
})

test_that("build_proportions_dataframe includes Wilson columns when present", {
  prop_results <- mock_proportion_results()

  result <- build_proportions_dataframe(prop_results)

  # Q2 has wilson
  expect_true("Wilson_Lower" %in% names(result))
  expect_true("Wilson_Upper" %in% names(result))
})


# ==============================================================================
# build_means_dataframe()
# ==============================================================================

test_that("build_means_dataframe returns empty df for empty input", {
  result <- build_means_dataframe(list())

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 0)
})

test_that("build_means_dataframe builds correct structure from results", {
  mean_results <- mock_mean_results()

  result <- build_means_dataframe(mean_results)

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 1)
  expect_true("Question_ID" %in% names(result))
  expect_true("Mean" %in% names(result))
  expect_true("SD" %in% names(result))
  expect_true("Sample_Size" %in% names(result))
})

test_that("build_means_dataframe includes t-dist columns when present", {
  mean_results <- mock_mean_results()

  result <- build_means_dataframe(mean_results)

  expect_true("tDist_Lower" %in% names(result))
  expect_true("tDist_Upper" %in% names(result))
  expect_true("SE" %in% names(result))
})


# ==============================================================================
# write_confidence_output() — FULL PIPELINE
# ==============================================================================

test_that("write_confidence_output creates workbook with all sheets", {
  output_path <- file.path(tempdir(), paste0("test_full_output_",
                                              sample(10000:99999, 1), ".xlsx"))
  on.exit(unlink(output_path))

  result <- write_confidence_output(
    output_path = output_path,
    study_level_stats = mock_study_stats(),
    proportion_results = mock_proportion_results(),
    mean_results = mock_mean_results(),
    config = mock_config(),
    warnings = c("Some test warning"),
    decimal_sep = "."
  )

  expect_true(file.exists(output_path))
  sheets <- openxlsx::getSheetNames(output_path)
  expect_true("Summary" %in% sheets)
  expect_true("Methodology" %in% sheets)
  expect_true("Warnings" %in% sheets)
  expect_true("Inputs" %in% sheets)
  expect_true("Proportions_Detail" %in% sheets)
  expect_true("Means_Detail" %in% sheets)
})

test_that("write_confidence_output works with only proportion results", {
  output_path <- file.path(tempdir(), paste0("test_prop_only_",
                                              sample(10000:99999, 1), ".xlsx"))
  on.exit(unlink(output_path))

  result <- write_confidence_output(
    output_path = output_path,
    proportion_results = mock_proportion_results(),
    config = mock_config(),
    decimal_sep = "."
  )

  expect_true(file.exists(output_path))
  sheets <- openxlsx::getSheetNames(output_path)
  expect_true("Proportions_Detail" %in% sheets)
  # No Means_Detail when no mean results
  expect_false("Means_Detail" %in% sheets)
})

test_that("write_confidence_output works with no results (summary only)", {
  output_path <- file.path(tempdir(), paste0("test_no_results_",
                                              sample(10000:99999, 1), ".xlsx"))
  on.exit(unlink(output_path))

  expect_warning(
    write_confidence_output(
      output_path = output_path,
      config = mock_config(),
      decimal_sep = "."
    ),
    "No analysis results"
  )

  expect_true(file.exists(output_path))
  sheets <- openxlsx::getSheetNames(output_path)
  expect_true("Summary" %in% sheets)
  expect_true("Methodology" %in% sheets)
})


# ==============================================================================
# INDIVIDUAL SHEET BUILDERS
# ==============================================================================

test_that("add_methodology_sheet creates Methodology sheet", {
  wb <- openxlsx::createWorkbook()

  add_methodology_sheet(wb)

  expect_true("Methodology" %in% names(wb))
})

test_that("add_warnings_sheet creates Warnings sheet with content", {
  wb <- openxlsx::createWorkbook()
  test_warnings <- c("Warning 1", "Warning 2", "Warning 3")

  add_warnings_sheet(wb, test_warnings)

  expect_true("Warnings" %in% names(wb))
})

test_that("add_warnings_sheet handles empty warnings", {
  wb <- openxlsx::createWorkbook()

  add_warnings_sheet(wb, character(0))

  expect_true("Warnings" %in% names(wb))
})

test_that("add_inputs_sheet creates Inputs sheet", {
  wb <- openxlsx::createWorkbook()

  add_inputs_sheet(wb, mock_config(), ".")

  expect_true("Inputs" %in% names(wb))
})

test_that("add_study_level_sheet creates sheet with study stats", {
  wb <- openxlsx::createWorkbook()

  add_study_level_sheet(wb, mock_study_stats(), ".")

  expect_true("Study_Level" %in% names(wb))
})
