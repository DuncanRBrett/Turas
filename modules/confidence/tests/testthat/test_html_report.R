# ==============================================================================
# TEST SUITE: HTML Report Generation
# ==============================================================================
# Tests for confidence HTML report system
# Part of Turas Confidence Module Test Suite
# ==============================================================================

library(testthat)

context("HTML Report Generation")

# ==============================================================================
# TEST DATA HELPERS
# ==============================================================================

#' Create synthetic confidence results for testing
#' @keywords internal
create_test_confidence_results <- function(
    n_proportions = 2,
    n_means = 1,
    n_nps = 1,
    include_study_stats = TRUE,
    include_warnings = FALSE
) {
  # Config
  config <- list(
    study_settings = list(
      Confidence_Level = "0.95",
      Bootstrap_Iterations = "1000",
      Calculate_Effective_N = "Y",
      Decimal_Separator = "."
    ),
    file_paths = list(
      Data_File = "test_data.csv",
      Output_File = "test_output.xlsx"
    )
  )

  # Study stats
  study_stats <- NULL
  if (include_study_stats) {
    study_stats <- data.frame(
      Group = "Overall",
      Actual_n = 500,
      Effective_n = 450,
      DEFF = 1.11,
      Weight_CV = 0.15,
      Warning = "",
      stringsAsFactors = FALSE
    )
  }

  # Proportion results
  proportion_results <- list()
  if (n_proportions >= 1) {
    proportion_results$Q1 <- list(
      category = "1",
      proportion = 0.65,
      n = 500,
      n_eff = 450,
      moe_normal = list(lower = 0.607, upper = 0.693, moe = 0.043),
      wilson = list(lower = 0.608, upper = 0.690),
      bootstrap = list(lower = 0.605, upper = 0.695)
    )
  }
  if (n_proportions >= 2) {
    proportion_results$Q2 <- list(
      category = "1",
      proportion = 0.32,
      n = 500,
      n_eff = 450,
      moe_normal = list(lower = 0.277, upper = 0.363, moe = 0.043),
      wilson = list(lower = 0.280, upper = 0.362)
    )
  }
  if (n_proportions >= 3) {
    proportion_results$Q5 <- list(
      category = "1",
      proportion = 0.88,
      n = 500,
      n_eff = 450,
      moe_normal = list(lower = 0.850, upper = 0.910, moe = 0.030),
      wilson = list(lower = 0.851, upper = 0.905)
    )
  }

  # Mean results
  mean_results <- list()
  if (n_means >= 1) {
    mean_results$Q3 <- list(
      mean = 7.2,
      sd = 1.8,
      n = 500,
      n_eff = 450,
      t_dist = list(lower = 7.03, upper = 7.37, se = 0.085, df = 449),
      bootstrap = list(lower = 7.01, upper = 7.39)
    )
  }

  # NPS results
  nps_results <- list()
  if (n_nps >= 1) {
    nps_results$Q4 <- list(
      nps_score = 25,
      pct_promoters = 40,
      pct_detractors = 15,
      pct_passives = 45,
      n = 500,
      n_eff = 450,
      moe_normal = list(lower = 17.2, upper = 32.8, se = 3.95)
    )
  }

  # Warnings
  warnings_list <- character()
  if (include_warnings) {
    warnings_list <- c(
      "Q5: Effective n (25) is very small for reliable CI estimation",
      "Study-level: DEFF > 2.0 indicates substantial precision loss from weighting"
    )
  }

  list(
    study_stats = study_stats,
    proportion_results = proportion_results,
    mean_results = mean_results,
    nps_results = nps_results,
    warnings = warnings_list,
    config = config
  )
}

# ==============================================================================
# INPUT VALIDATION TESTS
# ==============================================================================

test_that("validate_confidence_html_inputs: valid input passes", {
  results <- create_test_confidence_results()
  result <- validate_confidence_html_inputs(results, list())

  expect_true(result$valid)
  expect_equal(length(result$errors), 0)
})

test_that("validate_confidence_html_inputs: rejects non-list input", {
  result <- validate_confidence_html_inputs("not a list", list())

  expect_false(result$valid)
  expect_true(any(grepl("must be a list", result$errors)))
})

test_that("validate_confidence_html_inputs: rejects empty results", {
  results <- list(config = list())
  result <- validate_confidence_html_inputs(results, list())

  expect_false(result$valid)
  expect_true(any(grepl("No results to render", result$errors)))
})

test_that("validate_confidence_html_inputs: rejects missing config", {
  results <- list(
    proportion_results = list(Q1 = list(proportion = 0.5))
  )
  result <- validate_confidence_html_inputs(results, list())

  expect_false(result$valid)
  expect_true(any(grepl("config", result$errors)))
})

test_that("validate_confidence_html_inputs: rejects invalid brand_colour", {
  results <- create_test_confidence_results()
  result <- validate_confidence_html_inputs(results, list(brand_colour = "red"))

  expect_false(result$valid)
  expect_true(any(grepl("brand_colour", result$errors)))
})

test_that("validate_confidence_html_inputs: accepts valid hex colour", {
  results <- create_test_confidence_results()
  result <- validate_confidence_html_inputs(results, list(brand_colour = "#2a3f5f"))

  expect_true(result$valid)
})

# ==============================================================================
# DATA TRANSFORMER TESTS
# ==============================================================================

test_that("transform_confidence_for_html: returns expected structure", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  expect_true(is.list(html_data))
  expect_true("summary" %in% names(html_data))
  expect_true("questions" %in% names(html_data))
  expect_true("methodology" %in% names(html_data))

  # Summary fields
  expect_true("n_total" %in% names(html_data$summary))
  expect_true("confidence_level" %in% names(html_data$summary))
  expect_true("n_proportions" %in% names(html_data$summary))
  expect_true("n_means" %in% names(html_data$summary))
})

test_that("transform_confidence_for_html: generates correct question count", {
  results <- create_test_confidence_results(n_proportions = 2, n_means = 1, n_nps = 1)
  html_data <- transform_confidence_for_html(results)

  expect_equal(length(html_data$questions), 4)
  expect_equal(html_data$summary$n_proportions, 2)
  expect_equal(html_data$summary$n_means, 1)
  expect_equal(html_data$summary$n_nps, 1)
})

test_that("transform_confidence_for_html: assigns quality badges", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  for (q in html_data$questions) {
    expect_true("quality" %in% names(q))
    expect_true(is.list(q$quality))
    expect_true("badge" %in% names(q$quality))
    expect_true(q$quality$badge %in% c("good", "warn", "poor"))
  }
})

test_that("transform_confidence_for_html: generates callout text", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  for (q in html_data$questions) {
    expect_true("callout" %in% names(q))
    expect_true(nzchar(q$callout))
  }
})

test_that("transform_confidence_for_html: proportion-only results work", {
  results <- create_test_confidence_results(n_proportions = 3, n_means = 0, n_nps = 0)
  html_data <- transform_confidence_for_html(results)

  expect_equal(length(html_data$questions), 3)
  for (q in html_data$questions) {
    expect_equal(q$type, "proportion")
  }
})

test_that("transform_confidence_for_html: mean-only results work", {
  results <- create_test_confidence_results(n_proportions = 0, n_means = 1, n_nps = 0)
  html_data <- transform_confidence_for_html(results)

  expect_equal(length(html_data$questions), 1)
  expect_equal(html_data$questions[[1]]$type, "mean")
})

# ==============================================================================
# TABLE BUILDER TESTS
# ==============================================================================

test_that("build_ci_summary_table: renders valid HTML", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  table_html <- build_ci_summary_table(html_data$questions)

  expect_true(is.character(table_html))
  expect_true(nzchar(table_html))
  expect_true(grepl("<table", table_html))
  expect_true(grepl("</table>", table_html))
})

test_that("build_study_level_table: renders valid HTML", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  table_html <- build_study_level_table(html_data$study_level)

  expect_true(is.character(table_html))
  expect_true(grepl("<table", table_html))
  expect_true(grepl("DEFF", table_html, ignore.case = TRUE))
})

test_that("build_proportion_detail_table: renders valid HTML", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  q <- html_data$questions[[1]]  # First proportion question
  table_html <- build_proportion_detail_table(q$results, 0.95)

  expect_true(is.character(table_html))
  expect_true(grepl("<table", table_html))
})

test_that("build_mean_detail_table: renders valid HTML", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  # Find the mean question
  mean_q <- NULL
  for (q in html_data$questions) {
    if (q$type == "mean") {
      mean_q <- q
      break
    }
  }
  skip_if(is.null(mean_q), "No mean questions in test data")

  table_html <- build_mean_detail_table(mean_q$results, 0.95)

  expect_true(is.character(table_html))
  expect_true(grepl("<table", table_html))
})

# ==============================================================================
# CHART BUILDER TESTS
# ==============================================================================

test_that("build_ci_forest_plot: renders valid SVG", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  chart_html <- build_ci_forest_plot(html_data$questions, "#1e3a5f")

  expect_true(is.character(chart_html))
  expect_true(nzchar(chart_html))
  expect_true(grepl("<svg", chart_html))
})

test_that("build_method_comparison_chart: renders valid SVG", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  chart_html <- build_method_comparison_chart(html_data$questions[[1]], "#1e3a5f")

  expect_true(is.character(chart_html))
  expect_true(grepl("<svg", chart_html))
})

# ==============================================================================
# PAGE BUILDER TESTS
# ==============================================================================

test_that("build_confidence_page: generates complete HTML page", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  tables <- list(
    summary = build_ci_summary_table(html_data$questions)
  )
  charts <- list(
    forest_plot = build_ci_forest_plot(html_data$questions, "#1e3a5f")
  )

  page <- build_confidence_page(html_data, tables, charts,
                                 config = list(), source_filename = "test")

  expect_true(is.character(page))
  expect_true(grepl("<!DOCTYPE html>", page))
  expect_true(grepl("</html>", page))
  expect_true(grepl("turas-report-type", page))
  expect_true(grepl("confidence", page))
})

test_that("build_confidence_page: contains meta tags for Report Hub", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  tables <- list(summary = build_ci_summary_table(html_data$questions))
  charts <- list(forest_plot = "")

  page <- build_confidence_page(html_data, tables, charts,
                                 config = list(), source_filename = "test")

  expect_true(grepl('turas-report-type.*content.*confidence', page))
})

test_that("build_confidence_page: contains callout text", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  tables <- list(summary = build_ci_summary_table(html_data$questions))
  charts <- list(forest_plot = "")

  page <- build_confidence_page(html_data, tables, charts,
                                 config = list(), source_filename = "test")

  # Should contain callout text
  expect_true(grepl("ci-callout", page))
})

test_that("build_confidence_page: contains comments textarea", {
  results <- create_test_confidence_results()
  html_data <- transform_confidence_for_html(results)

  tables <- list(summary = "")
  charts <- list(forest_plot = "")

  page <- build_confidence_page(html_data, tables, charts,
                                 config = list(), source_filename = "test")

  expect_true(grepl("textarea", page))
  expect_true(grepl("ci-comments-box", page))
})

# ==============================================================================
# HTML WRITER TESTS
# ==============================================================================

test_that("write_confidence_html_report: writes valid file", {
  tmp_dir <- tempdir()
  output_path <- file.path(tmp_dir, "test_confidence_report.html")

  # Clean up if exists
  if (file.exists(output_path)) file.remove(output_path)

  page <- "<!DOCTYPE html><html><head><title>Test</title></head><body>Test</body></html>"
  result <- write_confidence_html_report(page, output_path)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(output_path))
  expect_true(result$file_size_bytes > 0)

  # Clean up
  file.remove(output_path)
})

test_that("write_confidence_html_report: creates output directory", {
  tmp_dir <- file.path(tempdir(), "test_subdir_ci")
  output_path <- file.path(tmp_dir, "test_report.html")

  # Ensure dir doesn't exist
  if (dir.exists(tmp_dir)) unlink(tmp_dir, recursive = TRUE)

  page <- "<!DOCTYPE html><html><body>Test</body></html>"
  result <- write_confidence_html_report(page, output_path)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(output_path))

  # Clean up
  unlink(tmp_dir, recursive = TRUE)
})

# ==============================================================================
# FULL PIPELINE TEST
# ==============================================================================

test_that("Full HTML report pipeline generates valid output", {
  results <- create_test_confidence_results(
    n_proportions = 2, n_means = 1, n_nps = 1,
    include_study_stats = TRUE, include_warnings = TRUE
  )

  tmp_path <- file.path(tempdir(), "full_pipeline_test.html")
  if (file.exists(tmp_path)) file.remove(tmp_path)

  report_result <- generate_confidence_html_report(
    results, tmp_path, config = list(brand_colour = "#1e3a5f")
  )

  expect_equal(report_result$status, "PASS")
  expect_true(file.exists(tmp_path))
  expect_true(report_result$file_size_bytes > 0)
  expect_equal(report_result$n_questions, 4)

  # Read and check content
  html_content <- readLines(tmp_path, warn = FALSE)
  html_text <- paste(html_content, collapse = "\n")

  # Meta tags
  expect_true(grepl("turas-report-type", html_text))

  # Key sections present
  expect_true(grepl("tab-summary", html_text))
  expect_true(grepl("tab-details", html_text))
  expect_true(grepl("tab-notes", html_text))

  # Callouts present
  expect_true(grepl("ci-callout", html_text))

  # Comments box present
  expect_true(grepl("textarea", html_text))

  # Clean up
  file.remove(tmp_path)
})

test_that("HTML report handles proportion-only scenario", {
  results <- create_test_confidence_results(
    n_proportions = 3, n_means = 0, n_nps = 0
  )

  tmp_path <- file.path(tempdir(), "prop_only_test.html")
  if (file.exists(tmp_path)) file.remove(tmp_path)

  report_result <- generate_confidence_html_report(results, tmp_path, list())

  expect_equal(report_result$status, "PASS")
  expect_equal(report_result$n_questions, 3)

  file.remove(tmp_path)
})

test_that("HTML report handles mean-only scenario", {
  results <- create_test_confidence_results(
    n_proportions = 0, n_means = 1, n_nps = 0
  )

  tmp_path <- file.path(tempdir(), "mean_only_test.html")
  if (file.exists(tmp_path)) file.remove(tmp_path)

  report_result <- generate_confidence_html_report(results, tmp_path, list())

  expect_equal(report_result$status, "PASS")
  expect_equal(report_result$n_questions, 1)

  file.remove(tmp_path)
})

test_that("HTML report handles NPS-only scenario", {
  results <- create_test_confidence_results(
    n_proportions = 0, n_means = 0, n_nps = 1
  )

  tmp_path <- file.path(tempdir(), "nps_only_test.html")
  if (file.exists(tmp_path)) file.remove(tmp_path)

  report_result <- generate_confidence_html_report(results, tmp_path, list())

  expect_equal(report_result$status, "PASS")
  expect_equal(report_result$n_questions, 1)

  file.remove(tmp_path)
})

# ==============================================================================
# END OF TEST SUITE
# ==============================================================================
