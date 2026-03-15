# ==============================================================================
# TABS MODULE - HTML REPORT TESTS
# ==============================================================================
#
# Tests for HTML report generation pipeline:
#   1. validate_html_report_inputs() — guard layer
#   2. build_banner_groups() — banner group transformation
#   3. transform_single_question() — question data transformation
#   4. transform_for_html() — full data transformation
#   5. generate_html_report() — end-to-end report generation
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_html_report.R")
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

# Source shared + tabs dependencies
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

# Source HTML report submodules
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/html_report/99_html_report_main.R"))


# ==============================================================================
# HELPERS
# ==============================================================================

# Minimal banner_info matching what create_banner_structure() returns
make_html_test_banner_info <- function() {
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
    banner_headers = data.frame(
      label = c("Total", "Gender"),
      start_col = c(1, 2),
      end_col = c(1, 3),
      stringsAsFactors = FALSE
    ),
    banner_info = list(
      Gender = list(
        internal_keys = c("Gender::Male", "Gender::Female"),
        columns = c("Male", "Female"),
        letters = c("B", "C"),
        question = data.frame(
          QuestionCode = "Gender",
          QuestionText = "What is your gender?",
          stringsAsFactors = FALSE
        )
      )
    )
  )
}

# Minimal all_results with one question
make_html_test_results <- function() {
  list(
    Q1 = list(
      question_code = "Q1",
      question_text = "How satisfied are you?",
      question_type = "Single_Response",
      table = data.frame(
        RowLabel = c("Satisfied", "Satisfied", "Satisfied",
                     "Neutral", "Neutral", "Neutral",
                     "Dissatisfied", "Dissatisfied", "Dissatisfied"),
        RowType = c("Frequency", "Column %", "Sig.",
                    "Frequency", "Column %", "Sig.",
                    "Frequency", "Column %", "Sig."),
        RowSource = c("Satisfied", "Satisfied", "Satisfied",
                      "Neutral", "Neutral", "Neutral",
                      "Dissatisfied", "Dissatisfied", "Dissatisfied"),
        "TOTAL::Total" = c(60, 60.0, "",
                           25, 25.0, "",
                           15, 15.0, ""),
        "Gender::Male" = c(35, 70.0, "A",
                           10, 20.0, "",
                           5, 10.0, ""),
        "Gender::Female" = c(25, 50.0, "",
                             15, 30.0, "",
                             10, 20.0, "B"),
        check.names = FALSE,
        stringsAsFactors = FALSE
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

# Minimal config
make_html_test_config <- function() {
  list(
    project_title = "Test HTML Report",
    brand_colour = "#323367",
    accent_colour = "#CC9900",
    company_name = "Test Company",
    client_name = NULL,
    researcher_logo_path = NULL,
    client_logo_path = NULL,
    include_summary = FALSE,
    show_charts = FALSE,
    enable_significance_testing = TRUE,
    embed_frequencies = TRUE,
    apply_weighting = FALSE,
    significance_min_base = 30,
    decimal_places_ratings = 1,
    decimal_places_percent = 0,
    chart_palette_preset = "warm",
    html_report = TRUE,
    min_base = 30,
    show_row_percentages = FALSE,
    analyst_name = NULL,
    analyst_email = NULL,
    analyst_phone = NULL,
    fieldwork_dates = NULL,
    closing_notes = NULL,
    verbatim_filename = NULL,
    qualitative_slides = NULL,
    index_descriptor = NULL,
    mean_descriptor = NULL,
    nps_descriptor = NULL,
    show_numeric_median = FALSE,
    show_numeric_mode = FALSE,
    show_index_scores = FALSE,
    show_nps_score = FALSE,
    show_net_positive = FALSE,
    show_chi_square = FALSE,
    show_frequencies = TRUE,
    show_column_percentages = TRUE,
    show_unweighted_n = FALSE,
    show_effective_n = FALSE,
    dashboard_green_net = 30,
    dashboard_amber_net = 0,
    dashboard_green_mean = 7,
    dashboard_amber_mean = 5,
    dashboard_scale_mean = 10,
    dashboard_green_index = 7,
    dashboard_amber_index = 5,
    dashboard_scale_index = 10,
    dashboard_green_custom = 60,
    dashboard_amber_custom = 40,
    dashboard_metrics = "NET POSITIVE"
  )
}


# ==============================================================================
# 1. validate_html_report_inputs — guard layer
# ==============================================================================

context("validate_html_report_inputs")

test_that("passes with valid inputs", {
  result <- validate_html_report_inputs(
    make_html_test_results(),
    make_html_test_banner_info(),
    make_html_test_config()
  )
  expect_equal(result$status, "PASS")
})

test_that("refuses NULL all_results", {
  result <- validate_html_report_inputs(
    NULL,
    make_html_test_banner_info(),
    make_html_test_config()
  )
  expect_equal(result$status, "REFUSED")
  expect_true(grepl("MISSING|INVALID", result$code))
})

test_that("refuses empty all_results", {
  result <- validate_html_report_inputs(
    list(),
    make_html_test_banner_info(),
    make_html_test_config()
  )
  expect_equal(result$status, "REFUSED")
})

test_that("refuses NULL banner_info", {
  result <- validate_html_report_inputs(
    make_html_test_results(),
    NULL,
    make_html_test_config()
  )
  expect_equal(result$status, "REFUSED")
})

test_that("refuses NULL config_obj", {
  result <- validate_html_report_inputs(
    make_html_test_results(),
    make_html_test_banner_info(),
    NULL
  )
  expect_equal(result$status, "REFUSED")
})


# ==============================================================================
# 2. build_banner_groups — banner group transformation
# ==============================================================================

context("build_banner_groups")

test_that("extracts banner groups from banner_info", {
  banner_info <- make_html_test_banner_info()
  groups <- build_banner_groups(banner_info)

  expect_true(is.list(groups))
  expect_true(length(groups) >= 1)

  # Should have at least Gender group
  group_names <- names(groups)
  expect_true(any(grepl("Gender|gender", group_names, ignore.case = TRUE)))
})

test_that("each group has required fields", {
  banner_info <- make_html_test_banner_info()
  groups <- build_banner_groups(banner_info)

  for (g_name in names(groups)) {
    g <- groups[[g_name]]
    expect_true("internal_keys" %in% names(g),
                info = paste("Missing internal_keys in group:", g_name))
    expect_true("display_labels" %in% names(g),
                info = paste("Missing display_labels in group:", g_name))
    expect_true(length(g$internal_keys) > 0)
  }
})


# ==============================================================================
# 3. transform_single_question
# ==============================================================================

context("transform_single_question")

test_that("transforms question with table and bases", {
  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  result <- transform_single_question(
    all_results$Q1,
    banner_info,
    config
  )

  expect_true(is.list(result))
  expect_equal(result$q_code, "Q1")
  expect_equal(result$question_text, "How satisfied are you?")
  expect_true("table_data" %in% names(result))
  expect_true(is.data.frame(result$table_data))
  expect_true(nrow(result$table_data) > 0)
})

test_that("detects available statistics", {
  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  result <- transform_single_question(
    all_results$Q1,
    banner_info,
    config
  )

  expect_true("stats" %in% names(result))
  expect_true(result$stats$has_freq)
  expect_true(result$stats$has_col_pct)
  expect_true(result$stats$has_sig)
})


# ==============================================================================
# 4. transform_for_html — full transformation
# ==============================================================================

context("transform_for_html")

test_that("transforms all results successfully", {
  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  html_data <- transform_for_html(all_results, banner_info, config)

  expect_true(is.list(html_data))
  expect_true("questions" %in% names(html_data))
  expect_true("banner_groups" %in% names(html_data))
  expect_true("n_questions" %in% names(html_data))
  expect_equal(html_data$n_questions, 1)
})

test_that("returns total_n", {
  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  html_data <- transform_for_html(all_results, banner_info, config)

  expect_true("total_n" %in% names(html_data))
  expect_equal(html_data$total_n, 100)
})

test_that("handles multiple questions", {
  all_results <- make_html_test_results()
  # Add a second question
  all_results$Q2 <- all_results$Q1
  all_results$Q2$question_code <- "Q2"
  all_results$Q2$question_text <- "Would you recommend?"

  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  html_data <- transform_for_html(all_results, banner_info, config)

  expect_equal(html_data$n_questions, 2)
  expect_true("Q1" %in% names(html_data$questions))
  expect_true("Q2" %in% names(html_data$questions))
})


# ==============================================================================
# 5. generate_html_report — end-to-end
# ==============================================================================

context("generate_html_report — end-to-end")

test_that("generates valid HTML file", {
  tmp_html <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_html))

  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  result <- generate_html_report(all_results, banner_info, config, tmp_html)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp_html))
  expect_true(file.size(tmp_html) > 0)
  expect_true(!is.null(result$file_size_mb))
  expect_equal(result$n_questions, 1)
})

test_that("HTML output contains expected content", {
  tmp_html <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_html))

  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  result <- generate_html_report(all_results, banner_info, config, tmp_html)

  html_content <- readLines(tmp_html, warn = FALSE)
  html_text <- paste(html_content, collapse = "\n")

  # Should contain DOCTYPE
  expect_true(grepl("<!DOCTYPE html>", html_text, fixed = TRUE))
  # Should contain question text
  expect_true(grepl("How satisfied are you?", html_text, fixed = TRUE))
  # Should contain project title
  expect_true(grepl("Test HTML Report", html_text, fixed = TRUE))
})

test_that("refuses invalid inputs gracefully", {
  tmp_html <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_html))

  result <- generate_html_report(
    list(),  # empty results
    make_html_test_banner_info(),
    make_html_test_config(),
    tmp_html
  )

  expect_equal(result$status, "REFUSED")
  expect_false(file.exists(tmp_html))
})

test_that("handles multiple questions end-to-end", {
  tmp_html <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_html))

  all_results <- make_html_test_results()
  all_results$Q2 <- all_results$Q1
  all_results$Q2$question_code <- "Q2"
  all_results$Q2$question_text <- "Would you recommend?"

  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  result <- generate_html_report(all_results, banner_info, config, tmp_html)

  expect_equal(result$status, "PASS")
  expect_equal(result$n_questions, 2)

  html_text <- paste(readLines(tmp_html, warn = FALSE), collapse = "\n")
  expect_true(grepl("Would you recommend?", html_text, fixed = TRUE))
})
