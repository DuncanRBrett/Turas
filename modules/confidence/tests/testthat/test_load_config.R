# ==============================================================================
# TEST SUITE: Config Loading (01_load_config.R)
# ==============================================================================
# Tests for configuration loading and validation functions:
#   - load_confidence_config()
#   - load_file_paths_sheet()
#   - load_study_settings_sheet()
#   - load_question_analysis_sheet()
#   - auto_detect_header_read()
#   - validate_config()
#
# Run with:
#   testthat::test_file("modules/confidence/tests/testthat/test_load_config.R")
# ==============================================================================

library(testthat)

context("Config Loading")

# ==============================================================================
# HELPERS
# ==============================================================================

#' Create a minimal valid config workbook in a temp directory
#' Returns the path to the .xlsx file.
create_mock_config <- function(
  file_paths_settings = list(Data_File = "data.csv", Output_File = "output.xlsx"),
  study_settings = list(
    Calculate_Effective_N = "Y",
    Multiple_Comparison_Adjustment = "N",
    Multiple_Comparison_Method = "bonferroni",
    Bootstrap_Iterations = "1000",
    Confidence_Level = "0.95",
    Decimal_Separator = "."
  ),
  question_rows = data.frame(
    Question_ID = c("Q1", "Q2"),
    Statistic_Type = c("Proportion", "Mean"),
    Run_MOE = c("Y", "Y"),
    Run_Bootstrap = c("N", "N"),
    Run_Credible = c("N", "N"),
    stringsAsFactors = FALSE
  ),
  include_file_paths = TRUE,
  include_study_settings = TRUE,
  include_question_analysis = TRUE
) {
  wb <- openxlsx::createWorkbook()

  if (include_file_paths) {
    openxlsx::addWorksheet(wb, "File_Paths")
    fp_df <- data.frame(
      Setting = names(file_paths_settings),
      Value = unlist(file_paths_settings, use.names = FALSE),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(wb, "File_Paths", fp_df)
  }

  if (include_study_settings) {
    openxlsx::addWorksheet(wb, "Study_Settings")
    ss_df <- data.frame(
      Setting = names(study_settings),
      Value = unlist(study_settings, use.names = FALSE),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(wb, "Study_Settings", ss_df)
  }

  if (include_question_analysis) {
    openxlsx::addWorksheet(wb, "Question_Analysis")
    openxlsx::writeData(wb, "Question_Analysis", question_rows)
  }

  tmp_path <- file.path(tempdir(), paste0("test_config_", format(Sys.time(), "%H%M%S"), "_",
                                           sample(1000:9999, 1), ".xlsx"))
  openxlsx::saveWorkbook(wb, tmp_path, overwrite = TRUE)
  return(tmp_path)
}


# ==============================================================================
# load_confidence_config() — HAPPY PATH
# ==============================================================================

test_that("load_confidence_config loads valid config successfully", {
  config_path <- create_mock_config()
  on.exit(unlink(config_path))

  config <- load_confidence_config(config_path)

  expect_type(config, "list")
  expect_true("file_paths" %in% names(config))
  expect_true("study_settings" %in% names(config))
  expect_true("question_analysis" %in% names(config))
  expect_true("max_questions" %in% names(config))
  expect_equal(config$max_questions, DEFAULT_MAX_QUESTIONS)
})

test_that("load_confidence_config returns file_paths as named list", {
  config_path <- create_mock_config()
  on.exit(unlink(config_path))

  config <- load_confidence_config(config_path)

  # Relative Data_File / Output_File entries in the config are resolved
  # against the config file's directory by load_confidence_config(). The
  # returned values are absolute paths ending in the original basenames.
  expect_type(config$file_paths, "list")
  expect_equal(basename(config$file_paths$Data_File), "data.csv")
  expect_equal(basename(config$file_paths$Output_File), "output.xlsx")
  expect_true(startsWith(config$file_paths$Data_File,
                         normalizePath(dirname(config_path),
                                       winslash = "/", mustWork = FALSE)) ||
              startsWith(config$file_paths$Data_File, dirname(config_path)))
})

test_that("load_confidence_config returns study_settings as named list", {
  config_path <- create_mock_config()
  on.exit(unlink(config_path))

  config <- load_confidence_config(config_path)

  expect_type(config$study_settings, "list")
  expect_equal(config$study_settings$Confidence_Level, "0.95")
  expect_equal(config$study_settings$Decimal_Separator, ".")
})

test_that("load_confidence_config returns question_analysis as data frame", {
  config_path <- create_mock_config()
  on.exit(unlink(config_path))

  config <- load_confidence_config(config_path)

  expect_true(is.data.frame(config$question_analysis))
  expect_equal(nrow(config$question_analysis), 2)
  expect_true("Question_ID" %in% names(config$question_analysis))
})


# ==============================================================================
# load_confidence_config() — TRS REFUSALS
# ==============================================================================

test_that("load_confidence_config refuses on missing file", {
  expect_error(
    load_confidence_config("/nonexistent/path/config.xlsx"),
    class = "turas_refusal"
  )
})

test_that("load_confidence_config refuses on non-xlsx file", {
  tmp_csv <- file.path(tempdir(), "bad_config.csv")
  writeLines("a,b", tmp_csv)
  on.exit(unlink(tmp_csv))

  expect_error(
    load_confidence_config(tmp_csv),
    class = "turas_refusal"
  )
})


# ==============================================================================
# Max_Questions CONFIGURATION
# ==============================================================================

test_that("load_confidence_config respects Max_Questions setting", {
  config_path <- create_mock_config(
    study_settings = list(
      Calculate_Effective_N = "Y",
      Multiple_Comparison_Adjustment = "N",
      Multiple_Comparison_Method = "bonferroni",
      Bootstrap_Iterations = "1000",
      Confidence_Level = "0.95",
      Decimal_Separator = ".",
      Max_Questions = "500"
    )
  )
  on.exit(unlink(config_path))

  config <- load_confidence_config(config_path)

  expect_equal(config$max_questions, 500)
})

test_that("load_confidence_config caps Max_Questions at MAX_QUESTION_LIMIT", {
  config_path <- create_mock_config(
    study_settings = list(
      Calculate_Effective_N = "Y",
      Multiple_Comparison_Adjustment = "N",
      Multiple_Comparison_Method = "bonferroni",
      Bootstrap_Iterations = "1000",
      Confidence_Level = "0.95",
      Decimal_Separator = ".",
      Max_Questions = "9999"
    )
  )
  on.exit(unlink(config_path))

  config <- load_confidence_config(config_path)

  expect_equal(config$max_questions, MAX_QUESTION_LIMIT)
})


# ==============================================================================
# load_study_settings_sheet() — VALIDATION
# ==============================================================================

test_that("load_study_settings_sheet refuses when required settings missing", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Study_Settings")
  # Only include one setting, missing required ones
  openxlsx::writeData(wb, "Study_Settings", data.frame(
    Setting = "Calculate_Effective_N",
    Value = "Y",
    stringsAsFactors = FALSE
  ))
  tmp_path <- file.path(tempdir(), paste0("test_ss_", sample(1000:9999, 1), ".xlsx"))
  openxlsx::saveWorkbook(wb, tmp_path, overwrite = TRUE)
  on.exit(unlink(tmp_path))

  expect_error(
    load_study_settings_sheet(tmp_path),
    class = "turas_refusal"
  )
})


# ==============================================================================
# load_question_analysis_sheet() — VALIDATION
# ==============================================================================

test_that("load_question_analysis_sheet refuses when no questions present", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Question_Analysis")
  # Write headers but no data rows
  empty_df <- data.frame(
    Question_ID = character(0),
    Statistic_Type = character(0),
    Run_MOE = character(0),
    Run_Bootstrap = character(0),
    Run_Credible = character(0),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Question_Analysis", empty_df)
  tmp_path <- file.path(tempdir(), paste0("test_qa_", sample(1000:9999, 1), ".xlsx"))
  openxlsx::saveWorkbook(wb, tmp_path, overwrite = TRUE)
  on.exit(unlink(tmp_path))

  expect_error(
    load_question_analysis_sheet(tmp_path),
    class = "turas_refusal"
  )
})

test_that("load_question_analysis_sheet refuses when question limit exceeded", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Question_Analysis")
  # Create 10 questions but set limit to 5
  qa_df <- data.frame(
    Question_ID = paste0("Q", 1:10),
    Statistic_Type = rep("Proportion", 10),
    Run_MOE = rep("Y", 10),
    Run_Bootstrap = rep("N", 10),
    Run_Credible = rep("N", 10),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Question_Analysis", qa_df)
  tmp_path <- file.path(tempdir(), paste0("test_qa_limit_", sample(1000:9999, 1), ".xlsx"))
  openxlsx::saveWorkbook(wb, tmp_path, overwrite = TRUE)
  on.exit(unlink(tmp_path))

  expect_error(
    load_question_analysis_sheet(tmp_path, max_questions = 5),
    class = "turas_refusal"
  )
})

test_that("load_question_analysis_sheet filters out empty rows", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Question_Analysis")
  qa_df <- data.frame(
    Question_ID = c("Q1", "", "Q2"),
    Statistic_Type = c("Proportion", "", "Mean"),
    Run_MOE = c("Y", "", "Y"),
    Run_Bootstrap = c("N", "", "N"),
    Run_Credible = c("N", "", "N"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Question_Analysis", qa_df)
  tmp_path <- file.path(tempdir(), paste0("test_qa_empty_", sample(1000:9999, 1), ".xlsx"))
  openxlsx::saveWorkbook(wb, tmp_path, overwrite = TRUE)
  on.exit(unlink(tmp_path))

  result <- load_question_analysis_sheet(tmp_path)

  expect_equal(nrow(result), 2)
  expect_equal(result$Question_ID, c("Q1", "Q2"))
})


# ==============================================================================
# load_file_paths_sheet() — OPTIONAL SHEET
# ==============================================================================

test_that("load_file_paths_sheet returns NULL when sheet missing", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Study_Settings")
  openxlsx::writeData(wb, "Study_Settings", data.frame(Setting = "X", Value = "Y"))
  tmp_path <- file.path(tempdir(), paste0("test_fp_", sample(1000:9999, 1), ".xlsx"))
  openxlsx::saveWorkbook(wb, tmp_path, overwrite = TRUE)
  on.exit(unlink(tmp_path))

  result <- load_file_paths_sheet(tmp_path)

  expect_null(result)
})

test_that("load_file_paths_sheet refuses when required params missing", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "File_Paths")
  # Only Data_File, missing Output_File
  openxlsx::writeData(wb, "File_Paths", data.frame(
    Setting = "Data_File",
    Value = "data.csv",
    stringsAsFactors = FALSE
  ))
  tmp_path <- file.path(tempdir(), paste0("test_fp_miss_", sample(1000:9999, 1), ".xlsx"))
  openxlsx::saveWorkbook(wb, tmp_path, overwrite = TRUE)
  on.exit(unlink(tmp_path))

  expect_error(
    load_file_paths_sheet(tmp_path),
    class = "turas_refusal"
  )
})


# ==============================================================================
# validate_config()
# ==============================================================================

test_that("validate_config returns valid=TRUE for well-formed config", {
  # Build a config object as load_confidence_config would return
  # validate_config expects study_settings as a data frame with Setting/Value columns
  config <- list(
    file_paths = list(),
    study_settings = data.frame(
      Setting = c("Calculate_Effective_N", "Multiple_Comparison_Adjustment",
                  "Multiple_Comparison_Method", "Confidence_Level",
                  "Bootstrap_Iterations", "Decimal_Separator"),
      Value = c("Y", "N", "Bonferroni", "0.95", "1000", "."),
      stringsAsFactors = FALSE
    ),
    question_analysis = data.frame(
      Question_ID = "Q1",
      Statistic_Type = "Proportion",
      Run_MOE = "Y",
      Run_Bootstrap = "N",
      Run_Credible = "N",
      stringsAsFactors = FALSE
    )
  )

  result <- validate_config(config)

  expect_type(result, "list")
  expect_true("valid" %in% names(result))
  expect_true("errors" %in% names(result))
  expect_true("warnings" %in% names(result))
})
