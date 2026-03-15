# ==============================================================================
# TABS MODULE - WORKBOOK BUILDER ORCHESTRATION TESTS
# ==============================================================================
#
# Tests for workbook builder orchestration functions (workbook_builder.R):
#   1. get_style_config() — style parameter extraction with defaults
#   2. build_project_info() — project info list construction
#   3. save_workbook_safe() — directory creation and file save
#   4. create_crosstabs_workbook() — full workbook orchestration
#
# These tests focus on orchestration gaps NOT covered by test_excel_output.R,
# which already tests the low-level write_* and create_*_sheet functions.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_workbook_builder.R")
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

# Source shared infrastructure
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
source(file.path(turas_root, "modules/tabs/lib/cell_calculator.R"))
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))

# Define shared utility functions (same pattern as test_standard_processor.R)
safe_execute <- function(expr, default = NA, error_msg = "Operation failed", silent = FALSE) {
  tryCatch(expr, error = function(e) {
    if (!silent) cat(sprintf("  [WARNING] %s: %s\n", error_msg, conditionMessage(e)))
    return(default)
  })
}
assign("safe_execute", safe_execute, envir = globalenv())

batch_rbind <- function(row_list) {
  if (length(row_list) == 0) return(data.frame())
  all_cols <- unique(unlist(lapply(row_list, names)))
  row_list <- lapply(row_list, function(df) {
    missing_cols <- setdiff(all_cols, names(df))
    for (col in missing_cols) df[[col]] <- NA
    df[, all_cols, drop = FALSE]
  })
  do.call(rbind, row_list)
}
assign("batch_rbind", batch_rbind, envir = globalenv())

create_error_log <- function() {
  data.frame(
    QuestionCode = character(0),
    Issue = character(0),
    Severity = character(0),
    stringsAsFactors = FALSE
  )
}
assign("create_error_log", create_error_log, envir = globalenv())

# Constants needed by write_question_table_fast
if (!exists("TOTAL_COLUMN", envir = globalenv()))
  assign("TOTAL_COLUMN", "Total", envir = globalenv())
if (!exists("SIG_ROW_TYPE", envir = globalenv()))
  assign("SIG_ROW_TYPE", "Sig.", envir = globalenv())

# Extract write_question_table_fast from run_crosstabs.R
# (it lives there, not in excel_writer.R)
.rc_lines <- readLines(file.path(turas_root, "modules/tabs/lib/run_crosstabs.R"))
.rc_start <- grep("^write_question_table_fast <- function", .rc_lines)
# Find closing brace: next function definition or section header after start
.rc_candidates <- grep("^(#'|[a-z_]+ <- function)", .rc_lines)
.rc_candidates <- .rc_candidates[.rc_candidates > .rc_start[1]]
# The function ends at the line before the next roxygen/function block
.rc_end <- .rc_candidates[1] - 1
# Walk back over blank lines
while (.rc_end > .rc_start[1] && trimws(.rc_lines[.rc_end]) == "") {
  .rc_end <- .rc_end - 1
}
eval(parse(text = .rc_lines[.rc_start[1]:.rc_end]), envir = globalenv())
rm(.rc_lines, .rc_start, .rc_end, .rc_candidates)

# Source the module under test
source(file.path(turas_root, "modules/tabs/lib/crosstabs/workbook_builder.R"))


# ==============================================================================
# HELPERS
# ==============================================================================

# Minimal banner_info matching the structure expected by workbook_builder
make_wb_test_banner_info <- function() {
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
    ),
    banner_info = list(
      TOTAL = list(
        label = "Total",
        internal_keys = "TOTAL::Total",
        display_labels = "Total"
      ),
      Gender = list(
        label = "Gender",
        internal_keys = c("Gender::Male", "Gender::Female"),
        display_labels = c("Male", "Female")
      )
    ),
    banner_questions = data.frame(
      Variable_Name = c("Gender"),
      Variable_Label = c("Gender"),
      stringsAsFactors = FALSE
    )
  )
}

# Minimal question result for workbook builder tests
make_wb_test_results <- function() {
  list(
    Q1 = list(
      question_code = "Q1",
      question_text = "How satisfied?",
      question_type = "Single_Response",
      table = data.frame(
        RowLabel = c("Satisfied", "Satisfied", "Neutral", "Neutral"),
        RowType = c("Frequency", "Column %", "Frequency", "Column %"),
        "TOTAL::Total" = c(60, 60.0, 40, 40.0),
        "Gender::Male" = c(35, 70.0, 15, 30.0),
        "Gender::Female" = c(25, 50.0, 25, 50.0),
        check.names = FALSE, stringsAsFactors = FALSE
      ),
      bases = list(
        "TOTAL::Total" = list(unweighted = 100, weighted = 100, effective = 100),
        "Gender::Male" = list(unweighted = 50, weighted = 50, effective = 50),
        "Gender::Female" = list(unweighted = 50, weighted = 50, effective = 50)
      ),
      base_filter = NULL
    )
  )
}

# Config with all fields the workbook builder checks
make_wb_test_config <- function() {
  list(
    project_name = "Test Project",
    project_title = "Test Project",
    apply_weighting = FALSE,
    show_unweighted_n = FALSE,
    show_effective_n = FALSE,
    enable_significance_testing = TRUE,
    show_frequencies = TRUE,
    show_column_percentages = TRUE,
    show_row_percentages = FALSE,
    decimal_places = 1,
    decimal_places_percent = 0,
    decimal_places_ratings = 1,
    decimal_places_index = 1,
    decimal_places_numeric = 1,
    decimal_separator = ".",
    min_base = 30,
    very_small_base = 10,
    html_report = FALSE,
    show_charts = FALSE,
    include_summary = FALSE,
    create_sample_composition = FALSE,
    create_index_summary = FALSE
  )
}

# Minimal survey_structure for build_project_info
make_wb_test_survey_structure <- function() {
  list(
    project = list(project_name = "Test Crosstabs")
  )
}

# Minimal survey_data for build_project_info
make_wb_test_survey_data <- function(n = 100) {
  data.frame(
    ID = seq_len(n),
    Gender = sample(c("Male", "Female"), n, replace = TRUE),
    Q1 = sample(c("Satisfied", "Neutral"), n, replace = TRUE),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# 1. get_style_config
# ==============================================================================

context("get_style_config")

test_that("returns correct defaults with minimal config", {
  config <- list()
  result <- get_style_config(config)

  expect_true(is.list(result))
  expect_equal(result$decimal_separator, ".")
  expect_equal(result$decimal_places_percent, 1)
  expect_equal(result$decimal_places_ratings, 1)
  expect_equal(result$decimal_places_index, 1)
  expect_equal(result$decimal_places_numeric, 1)
})

test_that("respects custom decimal_places values", {
  config <- list(
    decimal_separator = ",",
    decimal_places = 2,
    decimal_places_percent = 0,
    decimal_places_ratings = 3,
    decimal_places_index = 2,
    decimal_places_numeric = 1
  )
  result <- get_style_config(config)

  expect_equal(result$decimal_separator, ",")
  expect_equal(result$decimal_places_percent, 0)
  expect_equal(result$decimal_places_ratings, 3)
  expect_equal(result$decimal_places_index, 2)
  expect_equal(result$decimal_places_numeric, 1)
})


# ==============================================================================
# 2. build_project_info
# ==============================================================================

context("build_project_info")

test_that("returns list with required fields", {
  survey_structure <- make_wb_test_survey_structure()
  survey_data <- make_wb_test_survey_data(n = 200)
  banner_info <- make_wb_test_banner_info()

  result <- build_project_info(survey_structure, survey_data, banner_info, effective_n = 195)

  expect_true(is.list(result))
  expect_equal(result$project_name, "Test Crosstabs")
  expect_equal(result$total_responses, 200)
  expect_equal(result$effective_n, 195)
  expect_equal(result$total_banner_cols, 3)
  expect_equal(result$num_banner_questions, 1)
})

test_that("handles NULL banner_questions gracefully", {
  survey_structure <- make_wb_test_survey_structure()
  survey_data <- make_wb_test_survey_data(n = 50)
  banner_info <- make_wb_test_banner_info()
  banner_info$banner_questions <- NULL

  result <- build_project_info(survey_structure, survey_data, banner_info, effective_n = 48)

  expect_true(is.list(result))
  expect_equal(result$num_banner_questions, 0)
  expect_equal(result$total_responses, 50)
})


# ==============================================================================
# 3. save_workbook_safe
# ==============================================================================

context("save_workbook_safe")

test_that("creates output directory if missing", {
  tmp_dir <- file.path(tempdir(), paste0("wb_test_", format(Sys.time(), "%H%M%S")))
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  # Ensure directory does not exist
  if (dir.exists(tmp_dir)) unlink(tmp_dir, recursive = TRUE)
  expect_false(dir.exists(tmp_dir))

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Sheet1")
  openxlsx::writeData(wb, "Sheet1", data.frame(x = 1:3))

  output_path <- file.path(tmp_dir, "output.xlsx")
  save_workbook_safe(wb, output_path)

  expect_true(dir.exists(tmp_dir))
  expect_true(file.exists(output_path))
})

test_that("saves valid Excel file to disk", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, "Data", data.frame(a = 1:5, b = letters[1:5]))

  save_workbook_safe(wb, tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)

  # Verify it is a valid xlsx by reading it back
  read_back <- openxlsx::read.xlsx(tmp, sheet = "Data")
  expect_equal(nrow(read_back), 5)
  expect_true("a" %in% names(read_back))
})


# ==============================================================================
# 4. create_crosstabs_workbook
# ==============================================================================

context("create_crosstabs_workbook")

test_that("creates workbook with expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  all_results <- make_wb_test_results()
  config <- make_wb_test_config()
  banner_info <- make_wb_test_banner_info()
  survey_structure <- make_wb_test_survey_structure()
  survey_data <- make_wb_test_survey_data(n = 100)
  error_log <- create_error_log()
  crosstab_questions <- data.frame(
    Variable_Name = "Q1",
    Variable_Label = "How satisfied?",
    Variable_Type = "Single_Response",
    stringsAsFactors = FALSE
  )

  result <- create_crosstabs_workbook(
    all_results = all_results,
    composite_results = list(),
    composite_defs = NULL,
    survey_structure = survey_structure,
    survey_data = survey_data,
    banner_info = banner_info,
    config_obj = config,
    error_log = error_log,
    trs_state = NULL,
    run_status = "PASS",
    skipped_questions = list(),
    partial_questions = list(),
    processed_questions = c("Q1"),
    crosstab_questions = crosstab_questions,
    effective_n = 100,
    master_weights = rep(1, 100),
    output_path = tmp,
    script_version = "10.2.0"
  )

  # Verify file was created
  expect_true(file.exists(tmp))

  # Verify expected sheets exist
  sheet_names <- openxlsx::getSheetNames(tmp)
  expect_true("Summary" %in% sheet_names)
  expect_true("Guide" %in% sheet_names)
  expect_true("Crosstabs" %in% sheet_names)
  # Error Log sheet should exist (even if empty)
  expect_true("Error Log" %in% sheet_names)
})

test_that("returns list with output_path and project_name", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  all_results <- make_wb_test_results()
  config <- make_wb_test_config()
  banner_info <- make_wb_test_banner_info()
  survey_structure <- make_wb_test_survey_structure()
  survey_data <- make_wb_test_survey_data(n = 100)
  error_log <- create_error_log()
  crosstab_questions <- data.frame(
    Variable_Name = "Q1",
    Variable_Label = "How satisfied?",
    Variable_Type = "Single_Response",
    stringsAsFactors = FALSE
  )

  result <- create_crosstabs_workbook(
    all_results = all_results,
    composite_results = list(),
    composite_defs = NULL,
    survey_structure = survey_structure,
    survey_data = survey_data,
    banner_info = banner_info,
    config_obj = config,
    error_log = error_log,
    trs_state = NULL,
    run_status = "PASS",
    skipped_questions = list(),
    partial_questions = list(),
    processed_questions = c("Q1"),
    crosstab_questions = crosstab_questions,
    effective_n = 100,
    master_weights = rep(1, 100),
    output_path = tmp,
    script_version = "10.2.0"
  )

  expect_true(is.list(result))
  expect_equal(result$output_path, tmp)
  expect_equal(result$project_name, "Test Crosstabs")
})

test_that("handles empty all_results gracefully", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  config <- make_wb_test_config()
  banner_info <- make_wb_test_banner_info()
  survey_structure <- make_wb_test_survey_structure()
  survey_data <- make_wb_test_survey_data(n = 50)
  error_log <- create_error_log()
  crosstab_questions <- data.frame(
    Variable_Name = character(0),
    Variable_Label = character(0),
    Variable_Type = character(0),
    stringsAsFactors = FALSE
  )

  result <- create_crosstabs_workbook(
    all_results = list(),
    composite_results = list(),
    composite_defs = NULL,
    survey_structure = survey_structure,
    survey_data = survey_data,
    banner_info = banner_info,
    config_obj = config,
    error_log = error_log,
    trs_state = NULL,
    run_status = "PASS",
    skipped_questions = list(),
    partial_questions = list(),
    processed_questions = character(0),
    crosstab_questions = crosstab_questions,
    effective_n = 50,
    master_weights = rep(1, 50),
    output_path = tmp,
    script_version = "10.2.0"
  )

  expect_true(file.exists(tmp))
  expect_true(is.list(result))
  expect_equal(result$output_path, tmp)

  # Crosstabs sheet should still exist even with no questions
  sheet_names <- openxlsx::getSheetNames(tmp)
  expect_true("Crosstabs" %in% sheet_names)
})
