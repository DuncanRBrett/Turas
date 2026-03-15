# ==============================================================================
# TABS MODULE - DATA LOADING TESTS
# ==============================================================================
#
# Tests for data loading, path resolution, and config parsing:
#   1. path_utils.R — resolve_path (absolute detection, trimws, relative)
#   2. config_utils.R — load_config_sheet (header auto-detect)
#   3. data_loader.R — load_survey_structure, load_survey_data
#   4. data_setup.R — load_and_validate_data, load_question_selection
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_data_loading.R")
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
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))


# ==============================================================================
# 1. resolve_path — absolute path detection
# ==============================================================================

context("resolve_path — absolute paths")

test_that("detects Unix absolute paths and returns them directly", {
  result <- resolve_path("/base/dir", "/absolute/path/file.txt")
  expect_true(grepl("absolute/path/file.txt", result, fixed = TRUE))
  expect_false(grepl("base/dir", result, fixed = TRUE))
})

test_that("detects Windows absolute paths", {
  result <- resolve_path("/base/dir", "C:/Users/test/file.txt")
  expect_true(grepl("Users/test/file.txt", result, fixed = TRUE))
  expect_false(grepl("base/dir", result, fixed = TRUE))
})

test_that("joins relative paths with base", {
  result <- resolve_path("/base/dir", "sub/file.txt")
  expect_true(grepl("base/dir/sub/file.txt", result, fixed = TRUE))
})


# ==============================================================================
# 2. resolve_path — whitespace handling
# ==============================================================================

context("resolve_path — whitespace trimming")

test_that("trims leading whitespace from relative path", {
  result <- resolve_path("/base/dir", "  sub/file.txt")
  expect_true(grepl("base/dir/sub/file.txt", result, fixed = TRUE))
  expect_false(grepl("  sub", result, fixed = TRUE))
})

test_that("trims whitespace from absolute path", {
  result <- resolve_path("/base/dir", "  /absolute/path.txt  ")
  expect_true(grepl("absolute/path.txt", result, fixed = TRUE))
  expect_false(grepl("base/dir", result, fixed = TRUE))
})

test_that("handles empty relative_path", {
  result <- resolve_path("/base/dir", "")
  expect_true(grepl("base/dir", result, fixed = TRUE))
})

test_that("handles NULL relative_path", {
  result <- resolve_path("/base/dir", NULL)
  expect_true(grepl("base/dir", result, fixed = TRUE))
})

test_that("handles NA relative_path", {
  result <- resolve_path("/base/dir", NA)
  expect_true(grepl("base/dir", result, fixed = TRUE))
})


# ==============================================================================
# 3. resolve_path — ./ prefix stripping
# ==============================================================================

context("resolve_path — ./ prefix")

test_that("strips ./ prefix from relative paths", {
  result <- resolve_path("/base/dir", "./sub/file.txt")
  expect_true(grepl("base/dir/sub/file.txt", result, fixed = TRUE))
  expect_false(grepl("/./", result, fixed = TRUE))
})


# ==============================================================================
# 4. resolve_path — empty base_path
# ==============================================================================

context("resolve_path — invalid inputs")

test_that("refuses empty base_path", {
  result <- tryCatch(
    resolve_path("", "file.txt"),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})

test_that("refuses NULL base_path", {
  result <- tryCatch(
    resolve_path(NULL, "file.txt"),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})


# ==============================================================================
# 5. get_project_root
# ==============================================================================

context("get_project_root")

test_that("returns parent directory of config file", {
  result <- get_project_root("/Users/test/project/Config.xlsx")
  expect_true(grepl("Users/test/project", result, fixed = TRUE))
  expect_false(grepl("Config.xlsx", result, fixed = TRUE))
})

test_that("refuses empty path", {
  result <- tryCatch(
    get_project_root(""),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})


# ==============================================================================
# 6. load_config_sheet — auto-detect header row
# ==============================================================================

context("load_config_sheet — header auto-detect")

test_that("loads standard config with Setting/Value in row 1", {
  # Create temp config file
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  config_df <- data.frame(
    Setting = c("alpha", "min_base", "apply_weighting"),
    Value = c("0.05", "30", "TRUE"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Settings", config_df)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- load_config_sheet(tmp, "Settings")

  expect_equal(result[["alpha"]], "0.05")
  expect_equal(result[["min_base"]], "30")
  expect_equal(result[["apply_weighting"]], "TRUE")
})

test_that("loads template config with Setting/Value in row 5", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  # Write title rows above the header
  openxlsx::writeData(wb, "Settings", data.frame(A = "TURAS Config", B = NA), startRow = 1,
                      colNames = FALSE)
  openxlsx::writeData(wb, "Settings", data.frame(A = "Description here", B = NA), startRow = 2,
                      colNames = FALSE)
  openxlsx::writeData(wb, "Settings", data.frame(A = NA, B = NA), startRow = 3,
                      colNames = FALSE)
  # Row 4: header
  openxlsx::writeData(wb, "Settings", data.frame(Setting = "Setting", Value = "Value"),
                      startRow = 4, colNames = FALSE)
  # Row 5+: data
  config_data <- data.frame(
    Setting = c("alpha", "min_base"),
    Value = c("0.05", "30"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Settings", config_data, startRow = 5, colNames = FALSE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- load_config_sheet(tmp, "Settings")

  expect_equal(result[["alpha"]], "0.05")
  expect_equal(result[["min_base"]], "30")
})

test_that("rejects duplicate settings", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  config_df <- data.frame(
    Setting = c("alpha", "alpha"),
    Value = c("0.05", "0.10"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Settings", config_df)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- tryCatch(
    load_config_sheet(tmp, "Settings"),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})


# ==============================================================================
# 7. load_survey_structure — with demo data
# ==============================================================================

context("load_survey_structure")

test_that("loads demo survey structure successfully", {
  demo_structure <- file.path(turas_root,
    "examples/tabs/demo_survey/Demo_Survey_Structure.xlsx")
  if (!file.exists(demo_structure)) skip("Demo structure file not found")

  result <- load_survey_structure(demo_structure)

  expect_true(is.list(result))
  expect_true("questions" %in% names(result))
  expect_true("options" %in% names(result))
  expect_true("project" %in% names(result))
  expect_true(nrow(result$questions) > 0)
  expect_true(nrow(result$options) > 0)
  expect_true("QuestionCode" %in% names(result$questions))
})


# ==============================================================================
# 8. .read_table_sheet — header auto-detect for table sheets
# ==============================================================================

context(".read_table_sheet")

test_that("reads table sheet with standard headers", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Questions")
  df <- data.frame(
    QuestionCode = c("Q1", "Q2"),
    QuestionText = c("First question", "Second question"),
    Variable_Type = c("Single_Response", "Rating"),
    Columns = c("Q1", "Q2"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Questions", df)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  result <- .read_table_sheet(tmp, "Questions",
                              required_cols = c("QuestionCode", "QuestionText"))

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 2)
  expect_true("QuestionCode" %in% names(result))
})
