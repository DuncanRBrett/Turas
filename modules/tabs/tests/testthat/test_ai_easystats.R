# ==============================================================================
# TABS MODULE - AI EASYSTATS TESTS
# ==============================================================================
#
# Tests for APA-style statistical narration using easystats:
#   - generate_apa_narration()      — per-question narration
#   - generate_all_apa_narrations() — batch narration
#   - build_apa_narration_panel()   — HTML rendering
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_ai_easystats.R")
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

source(file.path(turas_root, "modules/tabs/lib/ai/ai_easystats.R"))

# ==============================================================================
# FIXTURES
# ==============================================================================

make_apa_banner_info <- function() {
  list(
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
    columns       = c("Total", "Male", "Female"),
    letters       = c("A", "B", "C"),
    key_to_display = c(
      "TOTAL::Total"   = "Total",
      "Gender::Male"   = "Male",
      "Gender::Female" = "Female"
    ),
    banner_info = list(
      Gender = list(
        internal_keys = c("Gender::Male", "Gender::Female"),
        columns       = c("Male", "Female"),
        letters       = c("B", "C")
      )
    )
  )
}

make_apa_q_result <- function() {
  list(
    question_code = "Q1",
    question_text = "How satisfied are you?",
    question_type = "Single_Response",
    table = data.frame(
      RowLabel = c("Satisfied", "Satisfied", "Neutral", "Neutral",
                   "Dissatisfied", "Dissatisfied"),
      RowType = c("Frequency", "Column %", "Frequency", "Column %",
                  "Frequency", "Column %"),
      `TOTAL::Total` = c(60, 60.0, 25, 25.0, 15, 15.0),
      `Gender::Male` = c(40, 80.0, 5, 10.0, 5, 10.0),
      `Gender::Female` = c(20, 40.0, 20, 40.0, 10, 20.0),
      check.names = FALSE,
      stringsAsFactors = FALSE
    ),
    bases = list(
      `TOTAL::Total`   = list(unweighted = 100, weighted = 100),
      `Gender::Male`   = list(unweighted = 50, weighted = 50),
      `Gender::Female` = list(unweighted = 50, weighted = 50)
    )
  )
}

make_apa_q_result_small_base <- function() {
  q <- make_apa_q_result()
  q$bases$`Gender::Male` <- list(unweighted = 15, weighted = 15)
  q
}

# ==============================================================================
# TESTS: generate_apa_narration
# ==============================================================================

context("generate_apa_narration")

test_that("generates narration for valid categorical question", {
  skip_if_not_installed("report")

  result <- generate_apa_narration(make_apa_q_result(), make_apa_banner_info())

  expect_false(is.null(result))
  expect_true(nzchar(result$narration))
  expect_equal(result$test_type, "chi-squared")
  expect_true(is.logical(result$significant))
  expect_true(is.numeric(result$p_value))
})

test_that("returns NULL for NULL q_result", {
  expect_null(generate_apa_narration(NULL, make_apa_banner_info()))
})

test_that("returns NULL for empty table", {
  q <- make_apa_q_result()
  q$table <- q$table[0, , drop = FALSE]
  expect_null(generate_apa_narration(q, make_apa_banner_info()))
})

test_that("returns NULL when base sizes are too small", {
  result <- generate_apa_narration(make_apa_q_result_small_base(), make_apa_banner_info())
  expect_null(result)
})

test_that("returns NULL for Numeric question type", {
  q <- make_apa_q_result()
  q$question_type <- "Numeric"
  expect_null(generate_apa_narration(q, make_apa_banner_info()))
})

test_that("narration includes chi-squared test statistics", {
  skip_if_not_installed("report")

  result <- generate_apa_narration(make_apa_q_result(), make_apa_banner_info())

  expect_false(is.null(result))
  # Should contain chi-squared related terms
  expect_true(grepl("chi", tolower(result$narration)) ||
              grepl("X2", result$narration) ||
              grepl("\\u03C7", result$narration))
})

test_that("detects significant difference in skewed data", {
  skip_if_not_installed("report")

  result <- generate_apa_narration(make_apa_q_result(), make_apa_banner_info())

  # The test data has a strong gender difference (80% vs 40% satisfied)
  expect_false(is.null(result))
  expect_true(result$significant)
  expect_true(result$p_value < 0.05)
})

# ==============================================================================
# TESTS: generate_all_apa_narrations
# ==============================================================================

context("generate_all_apa_narrations")

test_that("batch processes multiple questions", {
  skip_if_not_installed("report")

  all_results <- list(
    Q1 = make_apa_q_result(),
    Q2 = make_apa_q_result()
  )
  banner_info <- make_apa_banner_info()

  narrations <- generate_all_apa_narrations(all_results, banner_info)

  expect_true(is.list(narrations))
  expect_true(length(narrations) >= 1)
})

test_that("skips questions that fail silently", {
  all_results <- list(
    Q1 = make_apa_q_result(),
    Q2 = list(table = NULL)  # Invalid
  )
  banner_info <- make_apa_banner_info()

  narrations <- generate_all_apa_narrations(all_results, banner_info)

  # Q2 should be skipped, not error
  expect_false("Q2" %in% names(narrations))
})

# ==============================================================================
# TESTS: build_apa_narration_panel
# ==============================================================================

context("build_apa_narration_panel")

test_that("renders narration panel with correct structure", {
  narr <- list(
    narration = "A chi-squared test was significant, X2(2) = 15.3, p < .001.",
    test_type = "chi-squared",
    significant = TRUE
  )

  html <- build_apa_narration_panel(narr, "Q001")

  expect_true(nzchar(html))
  expect_true(grepl('class="turas-apa-narration"', html, fixed = TRUE))
  expect_true(grepl('data-q-code="Q001"', html, fixed = TRUE))
  expect_true(grepl("Statistical test", html, fixed = TRUE))
  expect_true(grepl("chi-squared", html, fixed = TRUE))
})

test_that("returns empty string for NULL narration", {
  expect_equal(build_apa_narration_panel(NULL, "Q001"), "")
})

test_that("returns empty string for empty narration text", {
  narr <- list(narration = "", test_type = "chi-squared")
  expect_equal(build_apa_narration_panel(narr, "Q001"), "")
})

test_that("escapes HTML in narration text", {
  narr <- list(
    narration = "X2 < 5 & p > 0.05",
    test_type = "chi-squared",
    significant = FALSE
  )
  html <- build_apa_narration_panel(narr, "Q001")

  expect_true(grepl("&lt;", html, fixed = TRUE))
  expect_true(grepl("&amp;", html, fixed = TRUE))
})

test_that("does not contain AI labelling", {
  narr <- list(
    narration = "The test was not significant.",
    test_type = "chi-squared",
    significant = FALSE
  )
  html <- build_apa_narration_panel(narr, "Q001")

  expect_false(grepl("AI-assisted", html, fixed = TRUE))
  expect_false(grepl("ai-callout", html, fixed = TRUE))
})

# ==============================================================================
# TESTS: build_apa_narration_css
# ==============================================================================

context("build_apa_narration_css")

test_that("CSS contains required selectors", {
  css <- build_apa_narration_css()

  expect_true(grepl(".turas-apa-narration", css, fixed = TRUE))
  expect_true(grepl(".apa-narration-label", css, fixed = TRUE))
  expect_true(grepl("@media print", css, fixed = TRUE))
})

# ==============================================================================
# TESTS: Constants
# ==============================================================================

context("easystats constants")

test_that("minimum base size is 30", {
  expect_equal(APA_MIN_BASE_SIZE, 30L)
})

test_that("default alpha is 0.05", {
  expect_equal(APA_ALPHA_DEFAULT, 0.05)
})
