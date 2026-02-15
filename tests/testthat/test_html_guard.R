# ==============================================================================
# TESTS: HTML REPORT GUARD LAYER
# ==============================================================================
# Tests for validate_html_report_inputs() - input validation for HTML reports
# ==============================================================================

library(testthat)

# Source the guard module
# When run via test_file(), working dir may be tests/testthat/
turas_root <- Sys.getenv("TURAS_ROOT", "")
if (!nzchar(turas_root)) {
  # Walk up from current directory to find Turas root
  candidate <- getwd()
  for (i in 1:5) {
    if (file.exists(file.path(candidate, "modules", "tabs", "lib", "html_report", "00_html_guard.R"))) {
      turas_root <- candidate
      break
    }
    candidate <- dirname(candidate)
  }
  if (!nzchar(turas_root)) turas_root <- getwd()
}
source(file.path(turas_root, "modules/tabs/lib/html_report/00_html_guard.R"))

# ==============================================================================
# HELPER: Minimal valid inputs
# ==============================================================================

make_valid_all_results <- function() {
  list(
    Q001 = list(
      question_code = "Q001",
      question_text = "Test question",
      question_type = "Single_Choice",
      base_filter = NA,
      table = data.frame(
        RowLabel = c("Option A", "Option A", "Option B", "Option B"),
        RowType = c("Frequency", "Column %", "Frequency", "Column %"),
        `TOTAL::Total` = c(100, 50, 100, 50),
        `Q01::Male` = c(60, 60, 40, 40),
        check.names = FALSE
      ),
      bases = list(
        `TOTAL::Total` = list(unweighted = 200, weighted = 200),
        `Q01::Male` = list(unweighted = 100, weighted = 100)
      )
    )
  )
}

make_valid_banner_info <- function() {
  list(
    banner_info = list(
      Q01 = list(
        internal_keys = c("Q01::Male", "Q01::Female"),
        letters = c("A", "B"),
        columns = c("Male", "Female")
      )
    ),
    internal_keys = c("TOTAL::Total", "Q01::Male", "Q01::Female"),
    columns = c("Total", "Male", "Female"),
    letters = c("-", "A", "B")
  )
}

make_valid_config <- function() {
  list(
    html_report = TRUE,
    brand_colour = "#0d8a8a",
    project_title = "Test Project",
    embed_frequencies = TRUE,
    significance_min_base = 30,
    enable_significance_testing = TRUE,
    show_frequency = TRUE,
    show_percent_column = TRUE,
    show_percent_row = FALSE
  )
}


# ==============================================================================
# TEST: Valid inputs pass
# ==============================================================================

test_that("valid inputs pass validation", {
  result <- validate_html_report_inputs(
    all_results = make_valid_all_results(),
    banner_info = make_valid_banner_info(),
    config_obj = make_valid_config()
  )
  expect_equal(result$status, "PASS")
})


# ==============================================================================
# TEST: Missing all_results
# ==============================================================================

test_that("NULL all_results returns TRS refusal", {
  result <- validate_html_report_inputs(
    all_results = NULL,
    banner_info = make_valid_banner_info(),
    config_obj = make_valid_config()
  )
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_MISSING")
})

test_that("empty all_results returns TRS refusal", {
  result <- validate_html_report_inputs(
    all_results = list(),
    banner_info = make_valid_banner_info(),
    config_obj = make_valid_config()
  )
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_INVALID")
})

test_that("unnamed all_results returns TRS refusal", {
  result <- validate_html_report_inputs(
    all_results = list(list(table = data.frame(RowLabel = "a", RowType = "b"))),
    banner_info = make_valid_banner_info(),
    config_obj = make_valid_config()
  )
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_INVALID")
})


# ==============================================================================
# TEST: Invalid question structure
# ==============================================================================

test_that("question without table returns TRS refusal", {
  bad_results <- list(Q001 = list(question_code = "Q001"))
  result <- validate_html_report_inputs(
    all_results = bad_results,
    banner_info = make_valid_banner_info(),
    config_obj = make_valid_config()
  )
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_INVALID")
})

test_that("question table missing RowType column returns TRS refusal", {
  bad_results <- list(
    Q001 = list(
      table = data.frame(RowLabel = "a", SomeOtherCol = 1),
      bases = list()
    )
  )
  result <- validate_html_report_inputs(
    all_results = bad_results,
    banner_info = make_valid_banner_info(),
    config_obj = make_valid_config()
  )
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_INVALID")
  expect_true(grepl("RowType", result$message))
})


# ==============================================================================
# TEST: Missing banner_info
# ==============================================================================

test_that("NULL banner_info returns TRS refusal", {
  result <- validate_html_report_inputs(
    all_results = make_valid_all_results(),
    banner_info = NULL,
    config_obj = make_valid_config()
  )
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_MISSING")
})

test_that("banner_info missing required fields returns TRS refusal", {
  bad_banner <- list(banner_info = list(), columns = c("Total"))
  result <- validate_html_report_inputs(
    all_results = make_valid_all_results(),
    banner_info = bad_banner,
    config_obj = make_valid_config()
  )
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_INVALID")
  expect_true(grepl("internal_keys|letters", result$message))
})


# ==============================================================================
# TEST: Missing config_obj
# ==============================================================================

test_that("NULL config_obj returns TRS refusal", {
  result <- validate_html_report_inputs(
    all_results = make_valid_all_results(),
    banner_info = make_valid_banner_info(),
    config_obj = NULL
  )
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_INVALID")
})

test_that("non-list config_obj returns TRS refusal", {
  result <- validate_html_report_inputs(
    all_results = make_valid_all_results(),
    banner_info = make_valid_banner_info(),
    config_obj = "not a list"
  )
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_INVALID")
})


# ==============================================================================
# TEST: TRS refusal structure
# ==============================================================================

test_that("all refusals include required TRS fields", {
  # Test one refusal to ensure structure is complete
  result <- validate_html_report_inputs(
    all_results = NULL,
    banner_info = make_valid_banner_info(),
    config_obj = make_valid_config()
  )
  expect_equal(result$status, "REFUSED")
  expect_true(!is.null(result$code))
  expect_true(!is.null(result$message))
  expect_true(!is.null(result$how_to_fix))
  expect_true(nchar(result$message) > 0)
  expect_true(nchar(result$how_to_fix) > 0)
})
