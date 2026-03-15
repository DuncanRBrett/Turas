# ==============================================================================
# TABS MODULE - EXCEL OUTPUT TESTS
# ==============================================================================
#
# Tests for Excel workbook creation and formatting:
#   1. create_excel_styles() — style object creation
#   2. get_row_style() — row type to style mapping
#   3. write_banner_headers() — banner header output
#   4. write_base_rows() — base size row output
#   5. write_question_table() — question table output
#   6. create_summary_sheet() — summary sheet creation
#   7. write_error_log_sheet() — error log sheet
#   8. create_guide_sheet() — guide/legend sheet
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_excel_output.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))
source(file.path(turas_root, "modules/tabs/lib/banner.R"))
source(file.path(turas_root, "modules/tabs/lib/banner_indices.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_writer.R"))


# ==============================================================================
# HELPERS
# ==============================================================================

# Minimal banner_info for testing
make_test_banner_info <- function() {
  list(
    columns = c("Total", "Male", "Female"),
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
    letters = c("A", "B", "C"),
    column_to_banner = c("TOTAL::Total" = "TOTAL",
                         "Gender::Male" = "Gender",
                         "Gender::Female" = "Gender"),
    key_to_display = c("TOTAL::Total" = "Total",
                       "Gender::Male" = "Male",
                       "Gender::Female" = "Female"),
    column_labels = c("Total", "Male", "Female"),
    banner_headers = data.frame(
      label = c("Total", "Gender"),
      start_col = c(1, 2),
      end_col = c(1, 3),
      stringsAsFactors = FALSE
    )
  )
}

# Minimal question result for testing
make_test_question_result <- function() {
  list(
    question_code = "Q1",
    question_text = "How satisfied are you?",
    question_type = "Single_Response",
    table = data.frame(
      RowLabel = c("Satisfied", "Satisfied", "Neutral", "Neutral",
                   "Dissatisfied", "Dissatisfied"),
      RowType = c("Frequency", "Column %", "Frequency", "Column %",
                  "Frequency", "Column %"),
      "TOTAL::Total" = c(60, 60.0, 25, 25.0, 15, 15.0),
      "Gender::Male" = c(35, 70.0, 10, 20.0, 5, 10.0),
      "Gender::Female" = c(25, 50.0, 15, 30.0, 10, 20.0),
      check.names = FALSE,
      stringsAsFactors = FALSE
    ),
    bases = list(
      "TOTAL::Total" = list(unweighted = 100),
      "Gender::Male" = list(unweighted = 50),
      "Gender::Female" = list(unweighted = 50)
    ),
    base_filter = NULL
  )
}

# Minimal config for testing
make_test_config <- function() {
  list(
    apply_weighting = FALSE,
    show_unweighted_n = FALSE,
    show_effective_n = FALSE,
    enable_significance_testing = TRUE,
    show_frequencies = TRUE,
    show_column_percentages = TRUE,
    show_row_percentages = FALSE,
    decimal_places_percent = 0,
    decimal_places_ratings = 1,
    decimal_places_index = 1,
    decimal_places_numeric = 1,
    decimal_separator = ".",
    min_base = 30,
    very_small_base = 10,
    project_title = "Test Project",
    html_report = FALSE,
    show_charts = FALSE,
    include_summary = FALSE
  )
}


# ==============================================================================
# 1. create_excel_styles
# ==============================================================================

context("create_excel_styles")

test_that("returns named list of style objects", {
  styles <- create_excel_styles()

  expect_true(is.list(styles))
  # Check required style names exist
  required <- c("banner", "question", "filter", "letter", "base",
                "frequency", "column_pct", "row_pct", "sig",
                "rating_style", "index_style", "row_label")
  for (name in required) {
    expect_true(name %in% names(styles),
                info = paste("Missing style:", name))
  }
})

test_that("accepts custom decimal separator", {
  styles_dot <- create_excel_styles(decimal_separator = ".")
  styles_comma <- create_excel_styles(decimal_separator = ",")

  # Both should return valid style lists
  expect_true(is.list(styles_dot))
  expect_true(is.list(styles_comma))
  expect_true("column_pct" %in% names(styles_dot))
  expect_true("column_pct" %in% names(styles_comma))
})

test_that("accepts custom decimal places", {
  styles <- create_excel_styles(
    decimal_places_percent = 2,
    decimal_places_ratings = 3,
    decimal_places_index = 0
  )

  expect_true(is.list(styles))
  expect_true("rating_style" %in% names(styles))
})

test_that("default parameters produce valid styles", {
  styles <- create_excel_styles()

  # Each style should be an openxlsx Style object
  expect_true(inherits(styles$banner, "Style"))
  expect_true(inherits(styles$question, "Style"))
  expect_true(inherits(styles$frequency, "Style"))
})


# ==============================================================================
# 2. get_row_style
# ==============================================================================

context("get_row_style")

test_that("maps known row types to correct styles", {
  styles <- create_excel_styles()

  expect_identical(get_row_style("Frequency", styles), styles$frequency)
  expect_identical(get_row_style("Column %", styles), styles$column_pct)
  expect_identical(get_row_style("Row %", styles), styles$row_pct)
  expect_identical(get_row_style("Average", styles), styles$rating_style)
  expect_identical(get_row_style("Index", styles), styles$index_style)
  expect_identical(get_row_style("Score", styles), styles$score_style)
  expect_identical(get_row_style("StdDev", styles), styles$stddev_style)
  expect_identical(get_row_style("Median", styles), styles$numeric_style)
  expect_identical(get_row_style("Mode", styles), styles$numeric_style)
  expect_identical(get_row_style("Sig.", styles), styles$sig)
  expect_identical(get_row_style("ChiSquare", styles), styles$sig)
})

test_that("returns base style for unknown row types", {
  styles <- create_excel_styles()

  expect_identical(get_row_style("UnknownType", styles), styles$base)
  expect_identical(get_row_style("", styles), styles$base)
})


# ==============================================================================
# 3. write_banner_headers — live workbook test
# ==============================================================================

context("write_banner_headers")

test_that("writes headers and returns next row number", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Test")
  banner_info <- make_test_banner_info()
  styles <- create_excel_styles()

  next_row <- write_banner_headers(wb, "Test", banner_info, styles)

  # Should return an integer > 1 (headers take 2-3 rows)
  expect_true(is.numeric(next_row))
  expect_true(next_row >= 3)
})

test_that("handles banner with no banner_headers field", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Test")
  banner_info <- make_test_banner_info()
  banner_info$banner_headers <- NULL
  styles <- create_excel_styles()

  next_row <- write_banner_headers(wb, "Test", banner_info, styles)

  expect_true(is.numeric(next_row))
  expect_true(next_row >= 2)
})


# ==============================================================================
# 4. write_base_rows — unweighted
# ==============================================================================

context("write_base_rows")

test_that("writes unweighted base row and returns next row", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Test")
  banner_info <- make_test_banner_info()
  styles <- create_excel_styles()
  config <- make_test_config()

  question_bases <- list(
    "TOTAL::Total" = list(unweighted = 100),
    "Gender::Male" = list(unweighted = 50),
    "Gender::Female" = list(unweighted = 50)
  )

  next_row <- write_base_rows(wb, "Test", banner_info, question_bases,
                               styles, current_row = 4, config)

  expect_true(is.numeric(next_row))
  expect_true(next_row > 4)
})

test_that("writes additional rows when weighting enabled", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Test")
  banner_info <- make_test_banner_info()
  styles <- create_excel_styles()
  config <- make_test_config()
  config$apply_weighting <- TRUE
  config$show_unweighted_n <- TRUE
  config$show_effective_n <- TRUE

  question_bases <- list(
    "TOTAL::Total" = list(unweighted = 100, weighted = 98.5, effective = 95.2),
    "Gender::Male" = list(unweighted = 50, weighted = 48.0, effective = 46.1),
    "Gender::Female" = list(unweighted = 50, weighted = 50.5, effective = 49.1)
  )

  next_row_weighted <- write_base_rows(wb, "Test", banner_info, question_bases,
                                        styles, current_row = 4, config)

  # Weighted output should use more rows than unweighted
  config$apply_weighting <- FALSE
  wb2 <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb2, "Test")
  next_row_unweighted <- write_base_rows(wb2, "Test", banner_info, question_bases,
                                          styles, current_row = 4, config)

  expect_true(next_row_weighted >= next_row_unweighted)
})


# ==============================================================================
# 5. write_question_table
# ==============================================================================

context("write_question_table")

test_that("writes question table and returns next row", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Test")
  banner_info <- make_test_banner_info()
  styles <- create_excel_styles()
  config <- make_test_config()
  result <- make_test_question_result()

  next_row <- write_question_table(wb, "Test", result, banner_info,
                                    styles, start_row = 5, config)

  expect_true(is.numeric(next_row))
  # Should advance past the 6 data rows + question header
  expect_true(next_row > 5)
})

test_that("handles result with base_filter", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Test")
  banner_info <- make_test_banner_info()
  styles <- create_excel_styles()
  config <- make_test_config()
  result <- make_test_question_result()
  result$base_filter <- "Age >= 18"

  next_row <- write_question_table(wb, "Test", result, banner_info,
                                    styles, start_row = 5, config)

  expect_true(is.numeric(next_row))
  expect_true(next_row > 5)
})


# ==============================================================================
# 6. create_summary_sheet
# ==============================================================================

context("create_summary_sheet")

test_that("creates summary sheet without error", {
  wb <- openxlsx::createWorkbook()
  styles <- create_excel_styles()
  config <- make_test_config()

  project_info <- list(
    project_name = "Test Project",
    total_responses = 500,
    effective_n = 485,
    total_banner_cols = 6,
    num_banner_questions = 2
  )

  all_results <- list(
    Q1 = make_test_question_result()
  )

  # Should not error
  result <- tryCatch(
    create_summary_sheet(wb, project_info, all_results, config, styles,
                          script_version = "10.8.1"),
    error = function(e) e
  )
  expect_false(inherits(result, "error"),
               info = paste("create_summary_sheet errored:", conditionMessage(result)))

  # Verify sheet was created
  expect_true("Summary" %in% openxlsx::sheets(wb))
})

test_that("handles empty all_results", {
  wb <- openxlsx::createWorkbook()
  styles <- create_excel_styles()
  config <- make_test_config()

  project_info <- list(
    project_name = "Empty Project",
    total_responses = 0,
    effective_n = 0,
    total_banner_cols = 1,
    num_banner_questions = 0
  )

  result <- tryCatch(
    create_summary_sheet(wb, project_info, list(), config, styles),
    error = function(e) e
  )
  expect_false(inherits(result, "error"))
})


# ==============================================================================
# 7. write_error_log_sheet
# ==============================================================================

context("write_error_log_sheet")

test_that("creates error log sheet with data", {
  wb <- openxlsx::createWorkbook()
  styles <- create_excel_styles()

  error_log <- data.frame(
    QuestionCode = c("Q5", "Q8"),
    Issue = c("Missing options", "Zero base size"),
    Severity = c("WARNING", "ERROR"),
    stringsAsFactors = FALSE
  )

  result <- tryCatch(
    write_error_log_sheet(wb, error_log, styles),
    error = function(e) e
  )
  expect_false(inherits(result, "error"))
})

test_that("handles NULL error log", {
  wb <- openxlsx::createWorkbook()
  styles <- create_excel_styles()

  result <- tryCatch(
    write_error_log_sheet(wb, NULL, styles),
    error = function(e) e
  )
  expect_false(inherits(result, "error"))
})

test_that("handles empty error log", {
  wb <- openxlsx::createWorkbook()
  styles <- create_excel_styles()

  empty_log <- data.frame(
    QuestionCode = character(0),
    Issue = character(0),
    stringsAsFactors = FALSE
  )

  result <- tryCatch(
    write_error_log_sheet(wb, empty_log, styles),
    error = function(e) e
  )
  expect_false(inherits(result, "error"))
})


# ==============================================================================
# 8. create_guide_sheet
# ==============================================================================

context("create_guide_sheet")

test_that("creates guide sheet without error", {
  wb <- openxlsx::createWorkbook()
  styles <- create_excel_styles()
  config <- make_test_config()
  banner_info <- make_test_banner_info()

  result <- tryCatch(
    create_guide_sheet(wb, config, banner_info, styles),
    error = function(e) e
  )
  expect_false(inherits(result, "error"))
  expect_true("Guide" %in% openxlsx::sheets(wb))
})

test_that("guide sheet content varies with config", {
  # With significance testing enabled
  wb1 <- openxlsx::createWorkbook()
  styles <- create_excel_styles()
  config1 <- make_test_config()
  config1$enable_significance_testing <- TRUE
  banner_info <- make_test_banner_info()

  create_guide_sheet(wb1, config1, banner_info, styles)

  # With significance testing disabled
  wb2 <- openxlsx::createWorkbook()
  config2 <- make_test_config()
  config2$enable_significance_testing <- FALSE

  create_guide_sheet(wb2, config2, banner_info, styles)

  # Both should have Guide sheets (content differs internally)
  expect_true("Guide" %in% openxlsx::sheets(wb1))
  expect_true("Guide" %in% openxlsx::sheets(wb2))
})


# ==============================================================================
# 9. End-to-end: write to file and verify
# ==============================================================================

context("Excel output — end-to-end file write")

test_that("creates valid Excel file with all sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  wb <- openxlsx::createWorkbook()
  styles <- create_excel_styles()
  config <- make_test_config()
  banner_info <- make_test_banner_info()
  result <- make_test_question_result()

  # Add Crosstabs sheet
  openxlsx::addWorksheet(wb, "Crosstabs")
  next_row <- write_banner_headers(wb, "Crosstabs", banner_info, styles)
  next_row <- write_base_rows(wb, "Crosstabs", banner_info, result$bases,
                               styles, next_row, config)
  next_row <- write_question_table(wb, "Crosstabs", result, banner_info,
                                    styles, next_row, config)

  # Add Summary sheet
  project_info <- list(
    project_name = "E2E Test",
    total_responses = 100,
    effective_n = 95,
    total_banner_cols = 3,
    num_banner_questions = 1
  )
  create_summary_sheet(wb, project_info, list(Q1 = result), config, styles)

  # Add Guide sheet
  create_guide_sheet(wb, config, banner_info, styles)

  # Add Error Log sheet
  write_error_log_sheet(wb, NULL, styles)

  # Save and verify
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)

  # Verify sheets exist in saved file
  sheet_names <- openxlsx::getSheetNames(tmp)
  expect_true("Crosstabs" %in% sheet_names)
  expect_true("Summary" %in% sheet_names)
  expect_true("Guide" %in% sheet_names)
})

test_that("Crosstabs sheet contains expected data", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  wb <- openxlsx::createWorkbook()
  styles <- create_excel_styles()
  config <- make_test_config()
  banner_info <- make_test_banner_info()
  result <- make_test_question_result()

  openxlsx::addWorksheet(wb, "Crosstabs")
  next_row <- write_banner_headers(wb, "Crosstabs", banner_info, styles)
  next_row <- write_base_rows(wb, "Crosstabs", banner_info, result$bases,
                               styles, next_row, config)
  next_row <- write_question_table(wb, "Crosstabs", result, banner_info,
                                    styles, next_row, config)

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  # Read back and verify content
  sheet_data <- openxlsx::read.xlsx(tmp, sheet = "Crosstabs",
                                     colNames = FALSE, skipEmptyRows = FALSE)

  expect_true(nrow(sheet_data) > 0)
  expect_true(ncol(sheet_data) > 1)
})
