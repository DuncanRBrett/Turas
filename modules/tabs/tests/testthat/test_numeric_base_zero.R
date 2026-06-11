# ==============================================================================
# TABS MODULE - NUMERIC BASE ZERO-POLICY TESTS (V10.8.2)
# ==============================================================================
#
# Regression tests for calculate_single_response_base / calculate_weighted_base:
# a numeric value of 0 is a real answer and must be counted in the base;
# only NA (numeric) or blank/whitespace (character) means "no response".
#
# Discovered on the Electrum VAS 2024 project: respondents with a genuine
# R0 monthly wallet were dropped from the Base (n=) row while the mean and
# bin frequencies still included them, producing an inconsistent table.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_numeric_base_zero.R")
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
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))

make_question_info <- function(code, type) {
  data.frame(QuestionCode = code, Variable_Type = type, Columns = 1,
             stringsAsFactors = FALSE)
}

# ==============================================================================
# NUMERIC COLUMNS: 0 COUNTS, NA DOES NOT
# ==============================================================================

test_that("numeric base counts zero values as responses", {
  data <- data.frame(SPEND = c(0, 150, 0, 2300, NA))
  weights <- rep(1, 5)

  result <- calculate_single_response_base(
    data, "SPEND", make_question_info("SPEND", "Numeric"), weights
  )

  # 4 respondents answered (two of them with a true zero); only NA excluded.
  expect_equal(result$unweighted, 4)
  expect_equal(result$weighted, 4)
})

test_that("numeric base excludes only NA when all values are zero", {
  data <- data.frame(SPEND = c(0, 0, 0))
  weights <- rep(1, 3)

  result <- calculate_single_response_base(
    data, "SPEND", make_question_info("SPEND", "Numeric"), weights
  )

  expect_equal(result$unweighted, 3)
})

test_that("numeric base is weighted over zero-valued respondents too", {
  data <- data.frame(SPEND = c(0, 100, NA))
  weights <- c(2.5, 1.5, 9.9)

  result <- calculate_single_response_base(
    data, "SPEND", make_question_info("SPEND", "Numeric"), weights
  )

  expect_equal(result$unweighted, 2)
  expect_equal(result$weighted, 4.0)  # 2.5 + 1.5; the NA respondent excluded
})

test_that("NPS scale zero (a valid detractor score) stays in the base", {
  data <- data.frame(NPS_Q = c(0, 5, 10, NA))
  weights <- rep(1, 4)

  result <- calculate_single_response_base(
    data, "NPS_Q", make_question_info("NPS_Q", "NPS"), weights
  )

  expect_equal(result$unweighted, 3)
})

# ==============================================================================
# CHARACTER COLUMNS: BLANK MEANS NO RESPONSE
# ==============================================================================

test_that("character base excludes blank and whitespace-only values", {
  data <- data.frame(Q1 = c("Yes", "", "  ", "No", NA),
                     stringsAsFactors = FALSE)
  weights <- rep(1, 5)

  result <- calculate_single_response_base(
    data, "Q1", make_question_info("Q1", "Single_Response"), weights
  )

  expect_equal(result$unweighted, 2)
})

test_that("character '0' is a response, blank is not", {
  data <- data.frame(Q1 = c("0", "1", "", NA), stringsAsFactors = FALSE)
  weights <- rep(1, 4)

  result <- calculate_single_response_base(
    data, "Q1", make_question_info("Q1", "Single_Response"), weights
  )

  expect_equal(result$unweighted, 2)
})

# ==============================================================================
# DISPATCH VIA calculate_weighted_base
# ==============================================================================

test_that("calculate_weighted_base applies the zero policy for Numeric", {
  data <- data.frame(WALLET = c(0, 0, 0, 1200))
  weights <- rep(1, 4)

  result <- calculate_weighted_base(
    data, make_question_info("WALLET", "Numeric"), weights
  )

  expect_equal(result$unweighted, 4)
})

test_that("multi-mention base semantics are unchanged (0 = not selected)", {
  # 0/1-coded check-all-that-apply: base remains 'selected at least one'.
  data <- data.frame(Q5_1 = c(1, 0, 0), Q5_2 = c(0, 1, 0))
  weights <- rep(1, 3)
  question_info <- data.frame(QuestionCode = "Q5",
                              Variable_Type = "Multi_Mention", Columns = 2,
                              stringsAsFactors = FALSE)

  result <- calculate_weighted_base(data, question_info, weights)

  expect_equal(result$unweighted, 2)
})
