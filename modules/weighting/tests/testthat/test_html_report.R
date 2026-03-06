# ==============================================================================
# TESTS: HTML Report Generation
# ==============================================================================

# --- Guard Validation Tests ---

test_that("validate_html_report_inputs rejects NULL results", {
  skip_if(!exists("validate_html_report_inputs", mode = "function"),
          "validate_html_report_inputs not available")

  result <- validate_html_report_inputs(NULL)

  expect_false(result$valid)
  expect_true(length(result$errors) > 0)
  expect_true(any(grepl("NULL", result$errors)))
})

test_that("validate_html_report_inputs rejects results without data", {
  skip_if(!exists("validate_html_report_inputs", mode = "function"),
          "validate_html_report_inputs not available")

  result <- validate_html_report_inputs(list(
    data = NULL,
    weight_names = "w1",
    weight_results = list(w1 = list())
  ))

  expect_false(result$valid)
  expect_true(any(grepl("data frame", result$errors)))
})

test_that("validate_html_report_inputs rejects results without weight_names", {
  skip_if(!exists("validate_html_report_inputs", mode = "function"),
          "validate_html_report_inputs not available")

  result <- validate_html_report_inputs(list(
    data = data.frame(x = 1:5),
    weight_names = character(0),
    weight_results = list()
  ))

  expect_false(result$valid)
  expect_true(any(grepl("[Nn]o weight", result$errors)))
})

test_that("validate_html_report_inputs accepts valid results", {
  skip_if(!exists("validate_html_report_inputs", mode = "function"),
          "validate_html_report_inputs not available")
  skip_if_not_installed("htmltools")

  result <- validate_html_report_inputs(list(
    data = data.frame(id = 1:10, w = runif(10)),
    weight_names = "w",
    weight_results = list(w = list(diagnostics = list()))
  ))

  expect_true(result$valid)
  expect_equal(length(result$errors), 0)
})

# --- Data Transformer Tests ---

test_that("transform_for_html creates proper structure", {
  skip_if(!exists("transform_for_html", mode = "function"),
          "transform_for_html not available")

  mock_results <- list(
    data = data.frame(id = 1:100, w1 = runif(100, 0.5, 2)),
    weight_names = "w1",
    weight_results = list(
      w1 = list(
        weights = runif(100, 0.5, 2),
        diagnostics = list(
          design_effect = 1.2,
          efficiency = 83.3,
          cv = 0.35,
          min = 0.5,
          max = 2.0,
          mean = 1.0,
          n_valid = 100,
          effective_n = 83
        )
      )
    ),
    config = list(
      general = list(project_name = "Test Project"),
      weight_specifications = data.frame(
        weight_name = "w1",
        method = "design",
        stringsAsFactors = FALSE
      )
    )
  )

  html_data <- transform_for_html(mock_results, list())

  expect_true(is.list(html_data))
  expect_true(!is.null(html_data$summary))
  expect_true(!is.null(html_data$weight_details))
  expect_equal(html_data$summary$project_name, "Test Project")
  expect_equal(html_data$summary$n_weights, 1)
  expect_equal(length(html_data$weight_details), 1)
})

# --- Table Builder Tests ---

test_that("build_summary_table produces non-empty HTML", {
  skip_if(!exists("build_summary_table", mode = "function"),
          "build_summary_table not available")

  weight_details <- list(
    list(
      weight_name = "w1",
      method = "design",
      diagnostics = list(
        sample_size = list(n_total = 100, n_valid = 100),
        effective_sample = list(design_effect = 1.2, efficiency = 83.3, effective_n = 83),
        distribution = list(min = 0.5, max = 2.0, mean = 1.0, cv = 0.35),
        quality = list(status = "GOOD", message = "Weight quality is good")
      )
    )
  )

  table <- build_summary_table(weight_details)

  expect_true(is.character(table))
  expect_true(nzchar(table))
  expect_true(grepl("<table", table))
  expect_true(grepl("w1", table))
})

# --- Chart Builder Tests ---

test_that("build_histogram_svg produces valid SVG", {
  skip_if(!exists("build_histogram_svg", mode = "function"),
          "build_histogram_svg not available")
  skip_if(!exists("build_histogram_data", mode = "function"),
          "build_histogram_data not available")

  weights <- rnorm(200, mean = 1, sd = 0.3)
  weights[weights < 0.1] <- 0.1  # ensure positive

  hist_data <- build_histogram_data(weights)
  svg <- build_histogram_svg(hist_data, "test_weight", "#1e3a5f")

  expect_true(is.character(svg))
  expect_true(nzchar(svg))
  expect_true(grepl("<svg", svg))
  expect_true(grepl("test_weight", svg))
})

test_that("build_quality_gauge_svg produces valid SVG", {
  skip_if(!exists("build_quality_gauge_svg", mode = "function"),
          "build_quality_gauge_svg not available")

  svg <- build_quality_gauge_svg("Good", 83.3)

  expect_true(is.character(svg))
  expect_true(nzchar(svg))
  expect_true(grepl("<svg", svg))
})

# --- Writer Tests ---

test_that("write_weighting_html_report rejects empty path", {
  skip_if(!exists("write_weighting_html_report", mode = "function"),
          "write_weighting_html_report not available")

  result <- write_weighting_html_report(htmltools::tags$div("test"), "")

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})

test_that("write_weighting_html_report writes file successfully", {
  skip_if(!exists("write_weighting_html_report", mode = "function"),
          "write_weighting_html_report not available")
  skip_if_not_installed("htmltools")

  output_path <- file.path(tempdir(), "test_html_report.html")
  on.exit(unlink(output_path))

  page <- htmltools::tagList(
    htmltools::tags$div(class = "test", "Test content")
  )

  result <- write_weighting_html_report(page, output_path)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(output_path))
  expect_true(result$file_size_bytes > 0)
})

# --- Integration: Full Report Generation ---

test_that("generate_weighting_html_report produces valid report from design weights", {
  skip_if(!exists("generate_weighting_html_report", mode = "function"),
          "generate_weighting_html_report not available")
  skip_if_not_installed("htmltools")
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 100)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_design_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  # Run weighting to get results
  result <- run_weighting(config_path, verbose = FALSE)
  expect_equal(result$status, "PASS")

  # Generate HTML report
  output_path <- file.path(tempdir(), "test_weighting_report.html")
  on.exit(unlink(output_path), add = TRUE)

  html_result <- generate_weighting_html_report(
    result,
    output_path,
    config = list(brand_colour = "#1e3a5f", accent_colour = "#2aa198")
  )

  expect_equal(html_result$status, "PASS")
  expect_true(file.exists(output_path))
  expect_true(html_result$file_size_bytes > 100)

  # Check HTML content
  html_content <- paste(readLines(output_path), collapse = "\n")
  expect_true(grepl("turas-report-type", html_content))
  expect_true(grepl("weighting", html_content))
  expect_true(grepl("design_weight", html_content))
})

test_that("generate_weighting_html_report handles rim weights", {
  skip_if(!exists("generate_weighting_html_report", mode = "function"),
          "generate_weighting_html_report not available")
  skip_if_not_installed("htmltools")
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 150)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_rim_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  result <- run_weighting(config_path, verbose = FALSE)
  expect_equal(result$status, "PASS")

  output_path <- file.path(tempdir(), "test_rim_report.html")
  on.exit(unlink(output_path), add = TRUE)

  html_result <- generate_weighting_html_report(result, output_path, config = list())

  expect_equal(html_result$status, "PASS")
  expect_true(file.exists(output_path))
})

test_that("generate_weighting_html_report refuses NULL results", {
  skip_if(!exists("generate_weighting_html_report", mode = "function"),
          "generate_weighting_html_report not available")

  output_path <- file.path(tempdir(), "test_null_report.html")
  on.exit(unlink(output_path))

  html_result <- generate_weighting_html_report(NULL, output_path)

  expect_equal(html_result$status, "REFUSED")
  expect_false(file.exists(output_path))
})

test_that("generate_weighting_html_report includes notes when provided", {
  skip_if(!exists("generate_weighting_html_report", mode = "function"),
          "generate_weighting_html_report not available")
  skip_if_not_installed("htmltools")
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 100)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_config_with_notes(data_path)
  on.exit(unlink(config_path), add = TRUE)

  result <- run_weighting(config_path, verbose = FALSE)
  expect_equal(result$status, "PASS")

  output_path <- file.path(tempdir(), "test_notes_report.html")
  on.exit(unlink(output_path), add = TRUE)

  html_result <- generate_weighting_html_report(result, output_path, config = list())

  expect_equal(html_result$status, "PASS")
  expect_true(file.exists(output_path))

  html_content <- paste(readLines(output_path), collapse = "\n")
  expect_true(grepl("Method Notes", html_content))
})
