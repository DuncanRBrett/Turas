# ==============================================================================
# TESTS: trs_refusal.R
# ==============================================================================
# Tests for the shared TRS refusal infrastructure.
# Covers: code validation, refusal signalling, condition class, run status.
# ==============================================================================

library(testthat)

# Source TRS infrastructure
turas_root <- Sys.getenv("TURAS_ROOT", getwd())
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (!file.exists(trs_path)) {
  trs_path <- file.path("modules", "shared", "lib", "trs_refusal.R")
}
if (file.exists(trs_path)) source(trs_path)

skip_if_not(exists("turas_refuse", mode = "function"),
            message = "TRS infrastructure not available")


# ==============================================================================
# CODE VALIDATION
# ==============================================================================

test_that("trs_validate_code accepts valid codes", {
  expect_true(trs_validate_code("CFG_MISSING_SHEET"))
  expect_true(trs_validate_code("DATA_INVALID"))
  expect_true(trs_validate_code("IO_FILE_NOT_FOUND"))
  expect_true(trs_validate_code("MODEL_CONVERGENCE"))
  expect_true(trs_validate_code("MAPPER_UNMAPPED"))
  expect_true(trs_validate_code("PKG_MISSING"))
  expect_true(trs_validate_code("FEATURE_DISABLED"))
  expect_true(trs_validate_code("BUG_INTERNAL"))
})

test_that("trs_validate_code rejects invalid prefixes", {
  expect_error(trs_validate_code("INVALID_CODE"), "Invalid refusal code prefix")
  expect_error(trs_validate_code("FOO_BAR"), "Invalid refusal code prefix")
  expect_error(trs_validate_code("data_lower"), "Invalid refusal code prefix")
})

test_that("trs_validate_code rejects non-string inputs", {
  expect_error(trs_validate_code(NULL), "single character string")
  expect_error(trs_validate_code(123), "single character string")
  expect_error(trs_validate_code(c("CFG_A", "CFG_B")), "single character string")
})

test_that("trs_validate_code rejects lowercase and special chars", {
  expect_error(trs_validate_code("CFG_lower_case"), "uppercase letters")
  expect_error(trs_validate_code("CFG_HAS-DASH"), "uppercase letters")
})


# ==============================================================================
# REFUSAL SIGNALLING
# ==============================================================================

test_that("turas_refuse signals a turas_refusal condition", {
  expect_error(
    turas_refuse(
      code = "CFG_MISSING_SHEET",
      title = "Missing Config Sheet",
      problem = "The Settings sheet is missing",
      why_it_matters = "Cannot load configuration",
      how_to_fix = "Add a Settings sheet"
    ),
    class = "turas_refusal"
  )
})

test_that("turas_refuse requires why_it_matters", {
  expect_error(
    turas_refuse(
      code = "CFG_TEST",
      title = "Test",
      problem = "Test problem",
      why_it_matters = "",
      how_to_fix = "Fix it"
    ),
    "why_it_matters is MANDATORY"
  )

  expect_error(
    turas_refuse(
      code = "CFG_TEST",
      title = "Test",
      problem = "Test problem",
      why_it_matters = NULL,
      how_to_fix = "Fix it"
    ),
    "why_it_matters is MANDATORY"
  )
})

test_that("turas_refuse condition carries structured data", {
  cond <- tryCatch(
    turas_refuse(
      code = "DATA_INVALID",
      title = "Invalid Data",
      problem = "Column X has NAs",
      why_it_matters = "Cannot compute stats",
      how_to_fix = c("Remove NAs", "Impute values"),
      expected = c("A", "B", "C"),
      missing = c("C"),
      module = "test_module"
    ),
    turas_refusal = function(e) e
  )

  expect_s3_class(cond, "turas_refusal")
  expect_equal(cond$code, "DATA_INVALID")
  expect_equal(cond$title, "Invalid Data")
  expect_equal(cond$problem, "Column X has NAs")
  expect_equal(cond$module, "test_module")
  expect_equal(cond$expected, c("A", "B", "C"))
  expect_equal(cond$missing, "C")
  expect_equal(length(cond$how_to_fix), 2)
})

test_that("turas_refuse message includes all sections", {
  cond <- tryCatch(
    turas_refuse(
      code = "IO_FILE_NOT_FOUND",
      title = "File Not Found",
      problem = "Cannot find data.csv",
      why_it_matters = "No data to analyse",
      how_to_fix = "Check the file path",
      details = "Searched in /tmp/"
    ),
    turas_refusal = function(e) e
  )

  msg <- cond$message
  expect_true(grepl("REFUSE", msg))
  expect_true(grepl("IO_FILE_NOT_FOUND", msg))
  expect_true(grepl("Problem:", msg))
  expect_true(grepl("Why it matters:", msg))
  expect_true(grepl("How to fix:", msg))
  expect_true(grepl("Details:", msg))
})

test_that("turas_refuse handles multi-step how_to_fix", {
  cond <- tryCatch(
    turas_refuse(
      code = "CFG_MISSING_SHEET",
      title = "Missing Sheet",
      problem = "Settings sheet missing",
      why_it_matters = "Cannot configure module",
      how_to_fix = c("Open the config file", "Add a Settings sheet", "Save and retry")
    ),
    turas_refusal = function(e) e
  )

  expect_true(grepl("1\\.", cond$message))
  expect_true(grepl("2\\.", cond$message))
  expect_true(grepl("3\\.", cond$message))
})

test_that("turas_refuse truncates long diagnostics lists", {
  cond <- tryCatch(
    turas_refuse(
      code = "DATA_INVALID",
      title = "Too Many Issues",
      problem = "Many columns have problems",
      why_it_matters = "Data quality is poor",
      how_to_fix = "Clean the data",
      expected = paste0("col_", 1:25)
    ),
    turas_refusal = function(e) e
  )

  expect_true(grepl("25 total", cond$message))
})


# ==============================================================================
# RUN STATUS (trs_run_status)
# ==============================================================================

test_that("trs_run_status validates status values", {
  skip_if_not(exists("trs_run_status", mode = "function"),
              message = "trs_run_status not available")

  expect_error(
    trs_run_status(status = "INVALID"),
    "Invalid status"
  )
})

test_that("trs_run_status creates PASS status", {
  skip_if_not(exists("trs_run_status", mode = "function"),
              message = "trs_run_status not available")

  result <- trs_run_status(
    status = "PASS",
    module = "test",
    message = "All good"
  )

  expect_equal(result$status, "PASS")
  expect_equal(result$module, "test")
})

test_that("trs_run_status PARTIAL requires reasons", {
  skip_if_not(exists("trs_run_status", mode = "function"),
              message = "trs_run_status not available")

  expect_error(
    trs_run_status(status = "PARTIAL", module = "test"),
    "degraded_reason"
  )
})
