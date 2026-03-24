# ==============================================================================
# TEST SUITE: Data Loading (02_load_data.R)
# ==============================================================================
# Tests for survey data loading and validation functions:
#   - load_survey_data()
#   - load_data_file()
#   - validate_survey_data()
#
# Run with:
#   testthat::test_file("modules/confidence/tests/testthat/test_load_data.R")
# ==============================================================================

library(testthat)

context("Data Loading")

# ==============================================================================
# HELPERS
# ==============================================================================

#' Create a mock CSV survey data file in tempdir
create_mock_csv <- function(n = 50, questions = c("Q1", "Q2", "Q3"),
                            weight_col = NULL) {
  df <- data.frame(ResponseID = seq_len(n))
  for (q in questions) {
    df[[q]] <- sample(1:5, n, replace = TRUE)
  }
  if (!is.null(weight_col)) {
    df[[weight_col]] <- runif(n, 0.5, 2.0)
  }
  tmp_path <- file.path(tempdir(), paste0("test_data_", sample(10000:99999, 1), ".csv"))
  write.csv(df, tmp_path, row.names = FALSE)
  return(tmp_path)
}

#' Create a mock XLSX survey data file in tempdir
create_mock_xlsx <- function(n = 50, questions = c("Q1", "Q2"),
                             weight_col = NULL) {
  df <- data.frame(ResponseID = seq_len(n))
  for (q in questions) {
    df[[q]] <- sample(1:10, n, replace = TRUE)
  }
  if (!is.null(weight_col)) {
    df[[weight_col]] <- runif(n, 0.5, 2.0)
  }
  tmp_path <- file.path(tempdir(), paste0("test_data_", sample(10000:99999, 1), ".xlsx"))
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, "Data", df)
  openxlsx::saveWorkbook(wb, tmp_path, overwrite = TRUE)
  return(tmp_path)
}


# ==============================================================================
# load_survey_data() — HAPPY PATH
# ==============================================================================

test_that("load_survey_data loads CSV file successfully", {
  csv_path <- create_mock_csv(n = 30, questions = c("Q1", "Q2"))
  on.exit(unlink(csv_path))

  result <- load_survey_data(csv_path, verbose = FALSE)

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 30)
  expect_true("Q1" %in% names(result))
  expect_true("Q2" %in% names(result))
})

test_that("load_survey_data loads XLSX file successfully", {
  xlsx_path <- create_mock_xlsx(n = 25, questions = c("Q1", "Q2"))
  on.exit(unlink(xlsx_path))

  result <- load_survey_data(xlsx_path, verbose = FALSE)

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 25)
  expect_true("Q1" %in% names(result))
})

test_that("load_survey_data validates required questions when provided", {
  csv_path <- create_mock_csv(questions = c("Q1", "Q2", "Q3"))
  on.exit(unlink(csv_path))

  result <- load_survey_data(csv_path, required_questions = c("Q1", "Q2"),
                              verbose = FALSE)

  expect_true(is.data.frame(result))
  expect_true(all(c("Q1", "Q2") %in% names(result)))
})

test_that("load_survey_data validates weight variable when provided", {
  csv_path <- create_mock_csv(questions = c("Q1"), weight_col = "wt")
  on.exit(unlink(csv_path))

  result <- load_survey_data(csv_path, weight_variable = "wt", verbose = FALSE)

  expect_true(is.data.frame(result))
  expect_true("wt" %in% names(result))
  expect_true(is.numeric(result$wt))
})


# ==============================================================================
# load_survey_data() — TRS REFUSALS
# ==============================================================================

test_that("load_survey_data refuses on missing file", {
  expect_error(
    load_survey_data("/nonexistent/path/data.csv", verbose = FALSE),
    class = "turas_refusal"
  )
})

test_that("load_survey_data refuses on unsupported format", {
  tmp_json <- file.path(tempdir(), "bad_data.json")
  writeLines("{}", tmp_json)
  on.exit(unlink(tmp_json))

  expect_error(
    load_survey_data(tmp_json, verbose = FALSE),
    class = "turas_refusal"
  )
})

test_that("load_survey_data refuses when required questions missing from data", {
  csv_path <- create_mock_csv(questions = c("Q1", "Q2"))
  on.exit(unlink(csv_path))

  expect_error(
    load_survey_data(csv_path, required_questions = c("Q1", "Q99_MISSING"),
                      verbose = FALSE),
    class = "turas_refusal"
  )
})


# ==============================================================================
# validate_survey_data() — WEIGHT VALIDATION
# ==============================================================================

test_that("validate_survey_data refuses when weight variable not found", {
  df <- data.frame(Q1 = 1:10)

  expect_error(
    validate_survey_data(df, required_questions = NULL,
                          weight_variable = "nonexistent_weight"),
    class = "turas_refusal"
  )
})

test_that("validate_survey_data refuses when weight variable is non-numeric", {
  df <- data.frame(Q1 = 1:10, wt = letters[1:10], stringsAsFactors = FALSE)

  expect_error(
    validate_survey_data(df, required_questions = NULL, weight_variable = "wt"),
    class = "turas_refusal"
  )
})

test_that("validate_survey_data refuses on negative weights", {
  df <- data.frame(Q1 = 1:10, wt = c(-1, rep(1, 9)))

  expect_error(
    validate_survey_data(df, required_questions = NULL, weight_variable = "wt"),
    class = "turas_refusal"
  )
})


# ==============================================================================
# validate_survey_data() — DATA STRUCTURE
# ==============================================================================

test_that("validate_survey_data refuses on empty data frame", {
  df <- data.frame(Q1 = numeric(0))

  expect_error(
    validate_survey_data(df, required_questions = NULL, weight_variable = NULL),
    class = "turas_refusal"
  )
})

test_that("validate_survey_data passes with valid data and no requirements", {
  df <- data.frame(Q1 = 1:10, Q2 = 11:20)

  # Should not throw
  result <- validate_survey_data(df, required_questions = NULL,
                                  weight_variable = NULL)

  expect_true(result)
})

test_that("validate_survey_data passes with valid weight variable", {
  df <- data.frame(Q1 = 1:10, wt = runif(10, 0.5, 2))

  result <- validate_survey_data(df, required_questions = NULL,
                                  weight_variable = "wt")

  expect_true(result)
})
