# ==============================================================================
# TEST SUITE: Tracker HTML Report (Phase 4)
# ==============================================================================

library(testthat)

context("Tracker HTML Report")

# ==============================================================================
# SETUP
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

# Set tracker lib dir for JS path resolution in page_builder
assign(".tracker_lib_dir", file.path(tracker_root, "lib"), envir = globalenv())

source(file.path(tracker_root, "lib", "00_guard.R"))
source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "metric_types.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "question_mapper.R"))
source(file.path(tracker_root, "lib", "statistical_core.R"))
source(file.path(tracker_root, "lib", "tracking_crosstab_engine.R"))

# Source all HTML report files
source(file.path(tracker_root, "lib", "html_report", "00_html_guard.R"))
source(file.path(tracker_root, "lib", "html_report", "01_data_transformer.R"))
source(file.path(tracker_root, "lib", "html_report", "02_table_builder.R"))
source(file.path(tracker_root, "lib", "html_report", "03_page_builder.R"))
source(file.path(tracker_root, "lib", "html_report", "04_html_writer.R"))
source(file.path(tracker_root, "lib", "html_report", "05_chart_builder.R"))
source(file.path(tracker_root, "lib", "html_report", "99_html_report_main.R"))


# ==============================================================================
# HELPERS
# ==============================================================================

create_test_crosstab_data <- function() {
  list(
    metrics = list(
      list(
        question_code = "Q_SAT",
        metric_label = "Satisfaction (Mean)",
        metric_name = "mean",
        section = "Brand Health",
        sort_order = 1,
        question_type = "rating_enhanced",
        question_text = "How satisfied?",
        segments = list(
          Total = list(
            values = list(W1 = 8.2, W2 = 8.5, W3 = 8.7),
            n = list(W1 = 500L, W2 = 480L, W3 = 510L),
            change_vs_previous = list(W2 = 0.3, W3 = 0.2),
            change_vs_baseline = list(W2 = 0.3, W3 = 0.5),
            sig_vs_previous = list(W2 = TRUE, W3 = FALSE),
            sig_vs_baseline = list(W2 = TRUE, W3 = TRUE)
          )
        )
      ),
      list(
        question_code = "Q_SAT",
        metric_label = "Satisfaction (Top 2 Box)",
        metric_name = "top2_box",
        section = "Brand Health",
        sort_order = 1.01,
        question_type = "rating_enhanced",
        question_text = "How satisfied?",
        segments = list(
          Total = list(
            values = list(W1 = 0.52, W2 = 0.55, W3 = 0.58),
            n = list(W1 = 500L, W2 = 480L, W3 = 510L),
            change_vs_previous = list(W2 = 0.03, W3 = 0.03),
            change_vs_baseline = list(W2 = 0.03, W3 = 0.06),
            sig_vs_previous = list(W2 = TRUE, W3 = FALSE),
            sig_vs_baseline = list(W2 = TRUE, W3 = TRUE)
          )
        )
      ),
      list(
        question_code = "Q_NPS",
        metric_label = "NPS Score",
        metric_name = "nps_score",
        section = "Brand Health",
        sort_order = 2,
        question_type = "nps",
        question_text = "Recommend?",
        segments = list(
          Total = list(
            values = list(W1 = 32, W2 = 38, W3 = 41),
            n = list(W1 = 500L, W2 = 480L, W3 = 510L),
            change_vs_previous = list(W2 = 6, W3 = 3),
            change_vs_baseline = list(W2 = 6, W3 = 9),
            sig_vs_previous = list(W2 = TRUE, W3 = FALSE),
            sig_vs_baseline = list(W2 = TRUE, W3 = TRUE)
          )
        )
      )
    ),
    waves = c("W1", "W2", "W3"),
    wave_labels = c("Jan 2024", "Apr 2024", "Jul 2024"),
    banner_segments = "Total",
    baseline_wave = "W1",
    sections = c("Brand Health"),
    metadata = list(
      project_name = "Test Project",
      generated_at = Sys.time(),
      confidence_level = 0.95,
      n_metrics = 3,
      n_waves = 3,
      n_segments = 1
    )
  )
}

create_test_config <- function() {
  list(
    settings = list(
      project_name = "Test Project",
      baseline_wave = "W1",
      brand_colour = "#323367",
      accent_colour = "#CC9900"
    ),
    waves = data.frame(
      WaveID = c("W1", "W2", "W3"),
      WaveName = c("Jan 2024", "Apr 2024", "Jul 2024"),
      stringsAsFactors = FALSE
    )
  )
}


# ==============================================================================
# TESTS: Guard Layer
# ==============================================================================

test_that("validate_tracker_html_inputs passes with valid data", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()

  result <- validate_tracker_html_inputs(crosstab_data, config)
  expect_equal(result$status, "PASS")
})

test_that("validate_tracker_html_inputs refuses non-list crosstab_data", {
  result <- validate_tracker_html_inputs("not a list", create_test_config())
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_INVALID")
})

test_that("validate_tracker_html_inputs refuses missing fields", {
  crosstab_data <- list(metrics = list(), waves = c("W1"))
  result <- validate_tracker_html_inputs(crosstab_data, create_test_config())
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_MISSING_FIELDS")
})

test_that("validate_tracker_html_inputs refuses empty metrics", {
  crosstab_data <- create_test_crosstab_data()
  crosstab_data$metrics <- list()
  result <- validate_tracker_html_inputs(crosstab_data, create_test_config())
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_EMPTY_METRICS")
})

test_that("validate_tracker_html_inputs refuses wave/label mismatch", {
  crosstab_data <- create_test_crosstab_data()
  crosstab_data$wave_labels <- c("Jan", "Apr")  # 2 labels for 3 waves
  result <- validate_tracker_html_inputs(crosstab_data, create_test_config())
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_WAVE_MISMATCH")
})


# ==============================================================================
# TESTS: Data Transformer
# ==============================================================================

test_that("transform_tracker_for_html returns correct structure", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()

  result <- transform_tracker_for_html(crosstab_data, config)

  expect_true(is.list(result))
  expect_equal(length(result$metric_rows), 3)
  expect_equal(length(result$chart_data), 3)
  expect_equal(length(result$sparkline_data), 3)
  expect_equal(result$n_metrics, 3)
  expect_equal(result$waves, c("W1", "W2", "W3"))
  expect_equal(result$segments, "Total")
})

test_that("metric rows have correct fields", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  result <- transform_tracker_for_html(crosstab_data, config)

  mr <- result$metric_rows[[1]]
  expect_equal(mr$metric_id, "metric_1")
  expect_equal(mr$metric_label, "Satisfaction (Mean)")
  expect_equal(mr$metric_name, "mean")
  expect_equal(mr$section, "Brand Health")
  expect_true("segment_cells" %in% names(mr))
  expect_true("Total" %in% names(mr$segment_cells))
})

test_that("cell data includes display values and changes", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  result <- transform_tracker_for_html(crosstab_data, config)

  cells <- result$metric_rows[[1]]$segment_cells$Total
  w1_cell <- cells$W1
  w2_cell <- cells$W2

  # W1 should have value but no vs-prev
  expect_equal(w1_cell$value, 8.2)
  expect_equal(w1_cell$display_value, "8.2")
  expect_true(w1_cell$is_first_wave)

  # W2 should have change vs prev
  expect_equal(w2_cell$value, 8.5)
  expect_equal(w2_cell$change_vs_prev, 0.3)
  expect_true(w2_cell$sig_vs_prev)
  expect_true(nzchar(w2_cell$display_vs_prev))
})

test_that("format_html_value handles different metric types", {
  expect_equal(format_html_value(8.5, "mean"), "8.5")
  expect_equal(format_html_value(0.52, "top2_box"), "52%")
  expect_equal(format_html_value(32, "nps_score"), "+32")
  expect_equal(format_html_value(NA, "mean"), "&mdash;")
})

test_that("chart data has correct structure", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  result <- transform_tracker_for_html(crosstab_data, config)

  cd <- result$chart_data[[1]]
  expect_equal(cd$metric_label, "Satisfaction (Mean)")
  expect_equal(cd$wave_labels, c("Jan 2024", "Apr 2024", "Jul 2024"))
  expect_true("Total" %in% names(cd$series))
  expect_equal(cd$series$Total$values, c(8.2, 8.5, 8.7))
  expect_false(cd$is_percentage)
  expect_false(cd$is_nps)
})

test_that("chart data correctly identifies NPS metric", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  result <- transform_tracker_for_html(crosstab_data, config)

  cd <- result$chart_data[[3]]  # NPS
  expect_true(cd$is_nps)
})

test_that("sparkline data extracts values correctly", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  result <- transform_tracker_for_html(crosstab_data, config)

  sp <- result$sparkline_data[[1]]
  expect_equal(sp$Total, c(8.2, 8.5, 8.7))
})


# ==============================================================================
# TESTS: Chart Builder
# ==============================================================================

test_that("build_sparkline_svg produces valid SVG", {
  svg <- build_sparkline_svg(c(8.2, 8.5, 8.7), width = 60, height = 16)
  expect_true(nzchar(svg))
  expect_true(grepl("<svg", svg))
  expect_true(grepl("</svg>", svg))
  expect_true(grepl("polyline", svg))
  expect_true(grepl("circle", svg))
})

test_that("build_sparkline_svg handles insufficient data", {
  svg <- build_sparkline_svg(c(8.2), width = 60, height = 16)
  expect_equal(svg, "")

  svg <- build_sparkline_svg(c(NA, NA), width = 60, height = 16)
  expect_equal(svg, "")
})

test_that("build_sparkline_svg handles NAs in middle", {
  svg <- build_sparkline_svg(c(8.2, NA, 8.7, 9.0), width = 60, height = 16)
  expect_true(nzchar(svg))
  expect_true(grepl("polyline", svg))
})

test_that("build_sparkline_svg handles all-same values", {
  svg <- build_sparkline_svg(c(5, 5, 5), width = 60, height = 16)
  expect_true(nzchar(svg))
})

test_that("build_line_chart produces SVG for valid data", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  chart <- build_line_chart(html_data$chart_data[[1]], config)
  expect_true(!is.null(chart))
  chart_str <- as.character(chart)
  expect_true(grepl("<svg", chart_str))
  expect_true(grepl("polyline", chart_str))
  expect_true(grepl("circle", chart_str))
})

test_that("build_line_chart returns NULL for single wave", {
  chart_data <- list(
    series = list(Total = list(name = "Total", values = c(8.2), n = c(500L))),
    wave_ids = "W1", wave_labels = "Jan 2024",
    metric_label = "Test", metric_name = "mean",
    is_percentage = FALSE, is_nps = FALSE
  )
  chart <- build_line_chart(chart_data, create_test_config())
  expect_null(chart)
})

test_that("get_segment_colours returns correct number of colours", {
  cols <- get_segment_colours(c("Total", "Cape Town", "Joburg"), "#323367")
  expect_equal(length(cols), 3)
  expect_equal(cols[1], "#323367")
})


# ==============================================================================
# TESTS: Table Builder
# ==============================================================================

test_that("build_tracking_table produces HTML with correct structure", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  table <- build_tracking_table(html_data, config)
  table_str <- as.character(table)

  expect_true(grepl("<table", table_str))
  expect_true(grepl("tk-crosstab-table", table_str))
  expect_true(grepl("Satisfaction \\(Mean\\)", table_str))
  expect_true(grepl("NPS Score", table_str))
  expect_true(grepl("Brand Health", table_str))
  expect_true(grepl("vs Prev", table_str))
  expect_true(grepl("vs Base", table_str))
})

test_that("table has correct number of header columns", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  table <- build_tracking_table(html_data, config)
  table_str <- as.character(table)

  # Should have wave headers: Jan 2024, Apr 2024, Jul 2024
  expect_true(grepl("Jan 2024", table_str))
  expect_true(grepl("Apr 2024", table_str))
  expect_true(grepl("Jul 2024", table_str))
})

test_that("make_css_safe converts names correctly", {
  expect_equal(make_css_safe("Total"), "Total")
  expect_equal(make_css_safe("Cape Town"), "Cape-Town")
  expect_equal(make_css_safe("Group (A)"), "Group--A-")
})


# ==============================================================================
# TESTS: HTML Writer
# ==============================================================================

test_that("write_tracker_html_report refuses missing path", {
  result <- write_tracker_html_report(htmltools::tags$div("test"), "")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})

test_that("write_tracker_html_report writes valid HTML file", {
  output_path <- tempfile(fileext = ".html")

  page <- htmltools::browsable(htmltools::tagList(
    htmltools::tags$head(htmltools::tags$title("Test")),
    htmltools::tags$div("Hello World")
  ))

  result <- write_tracker_html_report(page, output_path)
  expect_equal(result$status, "PASS")
  expect_true(file.exists(output_path))
  expect_true(result$file_size_bytes > 0)

  # Check content is valid HTML
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("<!DOCTYPE html>", content))
  expect_true(grepl("Hello World", content))

  unlink(output_path)
})


# ==============================================================================
# TESTS: End-to-End
# ==============================================================================

test_that("generate_tracker_html_report produces valid HTML file", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(output_path))
  expect_true(result$file_size_bytes > 0)

  # Read and check content
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("<!DOCTYPE html>", content))
  expect_true(grepl("Tracking Report", content))
  expect_true(grepl("Satisfaction", content))
  expect_true(grepl("NPS Score", content))
  expect_true(grepl("Brand Health", content))

  # Check CSS is embedded
  expect_true(grepl("tk-table", content))
  expect_true(grepl("--brand:", content))

  # Check JS is embedded
  expect_true(grepl("switchSegment", content))
  expect_true(grepl("toggleChangeRows", content))
  expect_true(grepl("exportCSV", content))

  # Check SVG charts present
  expect_true(grepl("<svg", content))

  unlink(output_path)
})

test_that("HTML report with multiple segments", {
  crosstab_data <- create_test_crosstab_data()

  # Add Cape Town segment
  for (i in seq_along(crosstab_data$metrics)) {
    crosstab_data$metrics[[i]]$segments[["Cape Town"]] <- list(
      values = list(W1 = 7.0, W2 = 7.5, W3 = 7.8),
      n = list(W1 = 200L, W2 = 190L, W3 = 210L),
      change_vs_previous = list(W2 = 0.5, W3 = 0.3),
      change_vs_baseline = list(W2 = 0.5, W3 = 0.8),
      sig_vs_previous = list(W2 = TRUE, W3 = FALSE),
      sig_vs_baseline = list(W2 = TRUE, W3 = TRUE)
    )
  }
  crosstab_data$banner_segments <- c("Total", "Cape Town")
  crosstab_data$metadata$n_segments <- 2

  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  expect_equal(result$status, "PASS")

  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("Cape Town", content))
  expect_true(grepl("tk-segment-tab", content))
  expect_true(grepl("All Segments", content))

  unlink(output_path)
})

test_that("JS files pass syntax validation", {
  js_dir <- file.path(tracker_root, "lib", "html_report", "js")
  js_files <- list.files(js_dir, pattern = "\\.js$", full.names = TRUE)

  expect_true(length(js_files) == 4)

  for (js_file in js_files) {
    result <- system2("node", args = c("--check", js_file),
                       stdout = TRUE, stderr = TRUE)
    status <- attr(result, "status")
    expect_true(is.null(status) || status == 0,
                info = paste("JS syntax error in", basename(js_file), ":",
                             paste(result, collapse = "\n")))
  }
})
