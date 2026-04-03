# ==============================================================================
# TABS MODULE - AI EXTRACTION TESTS
# ==============================================================================
#
# Tests for data extraction from all_results for AI insights:
#   - extract_question_data()         — per-question structured extraction
#   - extract_question_data_compact() — reduced payload
#   - extract_study_context()         — study-level context
#   - extract_sig_flags()             — significance letter → boolean translation
#
# Uses synthetic fixtures matching real all_results structure.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_ai_extraction.R")
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

source(file.path(turas_root, "modules/tabs/lib/ai/ai_extraction.R"))

# ==============================================================================
# FIXTURES — Synthetic all_results matching real Turas output
# ==============================================================================

make_test_banner_info <- function() {
  list(
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
    columns       = c("Total", "Male", "Female"),
    letters       = c("A", "B", "C"),
    key_to_display = c(
      "TOTAL::Total"    = "Total",
      "Gender::Male"    = "Male",
      "Gender::Female"  = "Female"
    ),
    banner_info = list(
      Gender = list(
        internal_keys = c("Gender::Male", "Gender::Female"),
        columns       = c("Male", "Female"),
        letters       = c("B", "C"),
        question      = data.frame(
          QuestionCode = "Gender",
          QuestionText = "What is your gender?",
          stringsAsFactors = FALSE
        )
      )
    ),
    banner_headers = data.frame(
      label     = c("Total", "Gender"),
      start_col = c(1, 2),
      end_col   = c(1, 3),
      stringsAsFactors = FALSE
    )
  )
}

make_test_q_result <- function() {
  list(
    question_code = "Q1",
    question_text = "How satisfied are you with our service?",
    question_type = "Single_Response",
    base_filter   = NA,
    filter_label  = NA,
    table = data.frame(
      RowLabel = c(
        "Very satisfied", "Very satisfied", "Very satisfied",
        "Satisfied", "Satisfied", "Satisfied",
        "Neutral", "Neutral", "Neutral",
        "Dissatisfied", "Dissatisfied", "Dissatisfied"
      ),
      RowType = c(
        "Frequency", "Column %", "Sig.",
        "Frequency", "Column %", "Sig.",
        "Frequency", "Column %", "Sig.",
        "Frequency", "Column %", "Sig."
      ),
      `TOTAL::Total` = c(
        120, 40.0, "",
         90, 30.0, "",
         60, 20.0, "",
         30, 10.0, ""
      ),
      `Gender::Male` = c(
        70, 46.7, "C",
        50, 33.3, "",
        20, 13.3, "",
        10,  6.7, ""
      ),
      `Gender::Female` = c(
        50, 33.3, "",
        40, 26.7, "",
        40, 26.7, "B",
        20, 13.3, ""
      ),
      check.names = FALSE,
      stringsAsFactors = FALSE
    ),
    bases = list(
      `TOTAL::Total`   = list(unweighted = 300, weighted = 300, effective = 295),
      `Gender::Male`   = list(unweighted = 150, weighted = 150, effective = 148),
      `Gender::Female` = list(unweighted = 150, weighted = 150, effective = 147)
    )
  )
}

make_test_q_result_with_mean <- function() {
  q <- make_test_q_result()
  # Add Mean row
  mean_rows <- data.frame(
    RowLabel = c("Mean", "Mean"),
    RowType  = c("Average", "Average"),
    `TOTAL::Total`   = c(7.2, 7.2),
    `Gender::Male`   = c(7.8, 7.8),
    `Gender::Female`  = c(6.6, 6.6),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  q$table <- rbind(q$table, mean_rows[1, ])
  q
}

make_test_all_results <- function() {
  list(
    Q1 = make_test_q_result(),
    Q2 = make_test_q_result()
  )
}

make_test_config_obj <- function() {
  list(
    project_title   = "Customer Satisfaction Q1 2026",
    apply_weighting = TRUE,
    fieldwork_dates = "1-15 March 2026"
  )
}

# ==============================================================================
# TESTS: extract_question_data
# ==============================================================================

context("extract_question_data")

test_that("extracts correct structure from valid question result", {
  q_result <- make_test_q_result()
  banner_info <- make_test_banner_info()

  result <- extract_question_data(q_result, banner_info)

  expect_false(is.null(result))
  expect_equal(result$q_code, "Q1")
  expect_equal(result$q_title, "How satisfied are you with our service?")
  expect_equal(result$q_type, "Single_Response")
})

test_that("extracts response labels from Column % rows", {
  result <- extract_question_data(make_test_q_result(), make_test_banner_info())

  expect_equal(result$response_labels,
               c("Very satisfied", "Satisfied", "Neutral", "Dissatisfied"))
})

test_that("extracts results as named list keyed by display label", {
  result <- extract_question_data(make_test_q_result(), make_test_banner_info())

  expect_true("Total" %in% names(result$results))
  expect_true("Male" %in% names(result$results))
  expect_true("Female" %in% names(result$results))

  # Verify values match Column % rows
  expect_equal(result$results$Total[["Very satisfied"]], 40.0)
  expect_equal(result$results$Male[["Very satisfied"]], 46.7)
  expect_equal(result$results$Female[["Very satisfied"]], 33.3)
})

test_that("extracts base sizes correctly", {
  result <- extract_question_data(make_test_q_result(), make_test_banner_info())

  expect_equal(result$base_sizes$Total, 300)
  expect_equal(result$base_sizes$Male, 150)
  expect_equal(result$base_sizes$Female, 150)
})

test_that("detects priority metric (Mean)", {
  q_result <- make_test_q_result_with_mean()
  result <- extract_question_data(q_result, make_test_banner_info())

  expect_false(is.null(result$priority_metric))
  expect_equal(result$priority_metric$label, "Mean")
  expect_equal(result$priority_metric$values$Total, 7.2)
  expect_equal(result$priority_metric$values$Male, 7.8)
  expect_equal(result$priority_metric$values$Female, 6.6)
})

test_that("returns NULL for priority metric when none present", {
  result <- extract_question_data(make_test_q_result(), make_test_banner_info())
  expect_null(result$priority_metric)
})

test_that("returns NULL for NULL q_result", {
  expect_null(extract_question_data(NULL, make_test_banner_info()))
})

test_that("returns NULL for q_result with NULL table", {
  q <- make_test_q_result()
  q$table <- NULL
  expect_null(extract_question_data(q, make_test_banner_info()))
})

test_that("returns NULL for empty table", {
  q <- make_test_q_result()
  q$table <- q$table[0, , drop = FALSE]
  expect_null(extract_question_data(q, make_test_banner_info()))
})

# ==============================================================================
# TESTS: extract_sig_flags
# ==============================================================================

context("extract_sig_flags")

test_that("extracts significance flags from Sig. rows", {
  q_result <- make_test_q_result()
  banner_info <- make_test_banner_info()

  flags <- extract_sig_flags(q_result, banner_info)

  expect_true(is.list(flags))
  expect_true(length(flags) > 0)
})

test_that("translates letter C to Female in sig flags", {
  q_result <- make_test_q_result()
  banner_info <- make_test_banner_info()

  flags <- extract_sig_flags(q_result, banner_info)

  # Male row for "Very satisfied" has sig "C" (higher than Female)
  male_sat_flag <- Filter(function(f) {
    f$measure == "Very satisfied" && f$column == "Male"
  }, flags)

  expect_true(length(male_sat_flag) > 0)
  expect_equal(male_sat_flag[[1]]$vs_columns, "Female")
  expect_true(male_sat_flag[[1]]$significant)
})

test_that("translates letter B to Male in sig flags", {
  q_result <- make_test_q_result()
  banner_info <- make_test_banner_info()

  flags <- extract_sig_flags(q_result, banner_info)

  # Female row for "Neutral" has sig "B" (higher than Male)
  female_neutral_flag <- Filter(function(f) {
    f$measure == "Neutral" && f$column == "Female"
  }, flags)

  expect_true(length(female_neutral_flag) > 0)
  expect_equal(female_neutral_flag[[1]]$vs_columns, "Male")
})

test_that("returns empty list when no Sig. rows exist", {
  q_result <- make_test_q_result()
  # Remove Sig. rows
  q_result$table <- q_result$table[q_result$table$RowType != "Sig.", , drop = FALSE]
  banner_info <- make_test_banner_info()

  flags <- extract_sig_flags(q_result, banner_info)
  expect_equal(length(flags), 0L)
})

test_that("returns empty list for NULL table", {
  q_result <- list(table = NULL)
  expect_equal(length(extract_sig_flags(q_result, make_test_banner_info())), 0L)
})

test_that("ignores empty and dash sig values", {
  q_result <- make_test_q_result()
  banner_info <- make_test_banner_info()

  flags <- extract_sig_flags(q_result, banner_info)

  # Total column has all empty sig values — should not appear
  total_flags <- Filter(function(f) f$column == "Total", flags)
  expect_equal(length(total_flags), 0L)
})

# ==============================================================================
# TESTS: extract_study_context
# ==============================================================================

context("extract_study_context")

test_that("extracts study context from config and results", {
  all_results <- make_test_all_results()
  banner_info <- make_test_banner_info()
  config_obj <- make_test_config_obj()

  ctx <- extract_study_context(all_results, banner_info, config_obj)

  expect_equal(ctx$report_title, "Customer Satisfaction Q1 2026")
  expect_true(ctx$weighted)
  expect_equal(ctx$fieldwork, "1-15 March 2026")
  expect_equal(ctx$n_questions, 2L)
  expect_equal(ctx$total_n, 300)
})

test_that("extracts banner group structure", {
  all_results <- make_test_all_results()
  banner_info <- make_test_banner_info()
  config_obj <- make_test_config_obj()

  ctx <- extract_study_context(all_results, banner_info, config_obj)

  expect_true("Gender" %in% names(ctx$banner_groups))
  expect_true("Male" %in% names(ctx$banner_groups$Gender$base_sizes) ||
              length(ctx$banner_groups$Gender$labels) > 0)
})

test_that("handles missing config fields gracefully", {
  all_results <- make_test_all_results()
  banner_info <- make_test_banner_info()
  config_obj <- list()

  ctx <- extract_study_context(all_results, banner_info, config_obj)

  expect_equal(ctx$report_title, "Untitled Study")
  expect_false(ctx$weighted)
  expect_equal(ctx$fieldwork, "")
})

# ==============================================================================
# TESTS: extract_question_data_compact
# ==============================================================================

context("extract_question_data_compact")

test_that("compact extraction has fewer fields than full", {
  q_result <- make_test_q_result()
  banner_info <- make_test_banner_info()

  full <- extract_question_data(q_result, banner_info)
  compact <- extract_question_data_compact(q_result, banner_info)

  expect_false(is.null(compact))
  expect_equal(compact$q_code, full$q_code)
  expect_equal(compact$q_title, full$q_title)

  # Compact has only Total results
  expect_true(length(compact$results) <= 1)

  # Full has all columns
  expect_true(length(full$results) >= 3)
})

test_that("compact extraction filters to significant-only flags", {
  q_result <- make_test_q_result()
  banner_info <- make_test_banner_info()

  compact <- extract_question_data_compact(q_result, banner_info)

  # All remaining sig flags should be significant=TRUE
  for (f in compact$significance) {
    expect_true(f$significant)
  }
})

test_that("returns NULL for NULL q_result", {
  expect_null(extract_question_data_compact(NULL, make_test_banner_info()))
})

# ==============================================================================
# TESTS: Internal helpers
# ==============================================================================

context("AI extraction internal helpers")

test_that("detect_primary_stat_type prefers Column %", {
  table <- data.frame(RowType = c("Frequency", "Column %", "Sig."))
  expect_equal(detect_primary_stat_type(table), "Column %")
})

test_that("detect_primary_stat_type falls back to Frequency", {
  table <- data.frame(RowType = c("Frequency", "Sig."))
  expect_equal(detect_primary_stat_type(table), "Frequency")
})

test_that("extract_total_n returns weighted n from first question", {
  all_results <- make_test_all_results()
  expect_equal(extract_total_n(all_results), 300)
})

test_that("extract_total_n returns NA for empty results", {
  expect_true(is.na(extract_total_n(list())))
})
