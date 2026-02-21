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
            # Values already on 0-100 scale (matching real engine output)
            values = list(W1 = 52, W2 = 55, W3 = 58),
            n = list(W1 = 500L, W2 = 480L, W3 = 510L),
            # Changes already in percentage-point units
            change_vs_previous = list(W2 = 3, W3 = 3),
            change_vs_baseline = list(W2 = 3, W3 = 6),
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
      accent_colour = "#CC9900",
      decimal_places_ratings = 2,
      decimal_places_percentages = 0,
      decimal_places_nps = 2
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
  # Check decimal_config is included
  expect_true("decimal_config" %in% names(result))
  expect_equal(result$decimal_config$dp_ratings, 2L)
  expect_equal(result$decimal_config$dp_pct, 0L)
  expect_equal(result$decimal_config$dp_nps, 2L)
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
  expect_equal(w1_cell$display_value, "8.20")  # 2dp for ratings
  expect_true(w1_cell$is_first_wave)

  # W2 should have change vs prev
  expect_equal(w2_cell$value, 8.5)
  expect_equal(w2_cell$change_vs_prev, 0.3)
  expect_true(w2_cell$sig_vs_prev)
  expect_true(nzchar(w2_cell$display_vs_prev))
})

test_that("format_html_value handles different metric types with default decimals", {
  # Mean/rating: 2 dp default
  expect_equal(format_html_value(8.5, "mean"), "8.50")
  expect_equal(format_html_value(8.123, "mean"), "8.12")

  # Percentage: 0 dp default, values already on 0-100 scale (no * 100)
  expect_equal(format_html_value(52, "top2_box"), "52%")
  expect_equal(format_html_value(55.6, "top2_box"), "56%")

  # NPS: signed format with 2 dp default
  expect_equal(format_html_value(32, "nps_score"), "+32.00")
  expect_equal(format_html_value(-15.5, "nps_score"), "-15.50")

  # NA
  expect_equal(format_html_value(NA, "mean"), "&mdash;")
})

test_that("format_html_value respects custom decimal places", {
  # Percentage with 1 dp
  expect_equal(format_html_value(52.34, "top2_box", dp_pct = 1), "52.3%")
  expect_equal(format_html_value(52.36, "top2_box", dp_pct = 1), "52.4%")

  # Ratings with 0 dp
  expect_equal(format_html_value(8.523, "mean", dp_ratings = 0), "9")

  # NPS with 0 dp
  expect_equal(format_html_value(32.7, "nps_score", dp_nps = 0), "+33")
  expect_equal(format_html_value(-15, "nps_score", dp_nps = 0), "-15")

  # Ratings with 3 dp
  expect_equal(format_html_value(8.5236, "mean", dp_ratings = 3), "8.524")
})

test_that("format_html_value matches pct/box/range/proportion/category/any patterns", {
  # All percentage-like metric names
  expect_true(grepl("%", format_html_value(50, "top2_box")))
  expect_true(grepl("%", format_html_value(50, "pct_promoters")))
  expect_true(grepl("%", format_html_value(50, "range_1_3")))
  expect_true(grepl("%", format_html_value(50, "proportion")))
  expect_true(grepl("%", format_html_value(50, "category_agree")))
  expect_true(grepl("%", format_html_value(50, "any_mention")))
})

test_that("format_change_display formats percentage changes correctly", {
  # Positive significant change (values in pp)
  result <- format_change_display(3, TRUE, "top2_box")
  expect_true(grepl("\\+3pp", result))
  expect_true(grepl("sig-up", result))
  expect_true(grepl("sig-arrow", result))

  # Negative significant change
  result <- format_change_display(-5, TRUE, "top2_box")
  expect_true(grepl("-5pp", result))
  expect_true(grepl("sig-down", result))

  # Non-significant change
  result <- format_change_display(3, FALSE, "top2_box")
  expect_true(grepl("not-sig", result))
})

test_that("format_change_display formats rating changes correctly", {
  result <- format_change_display(0.3, TRUE, "mean")
  expect_true(grepl("\\+0\\.30", result))
  expect_true(grepl("sig-up", result))

  result <- format_change_display(-0.5, TRUE, "mean", dp_ratings = 1)
  expect_true(grepl("-0\\.5", result))
})

test_that("format_change_display wraps arrows in sig-arrow span", {
  result <- format_change_display(3, TRUE, "top2_box")
  expect_true(grepl('<span class="sig-arrow">', result))

  # NA significance — no arrow
  result <- format_change_display(3, NA, "top2_box")
  expect_true(grepl("sig-na", result))
  expect_false(grepl("sig-arrow", result))
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

test_that("chart data correctly identifies percentage metric", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  result <- transform_tracker_for_html(crosstab_data, config)

  cd <- result$chart_data[[2]]  # top2_box
  expect_true(cd$is_percentage)
  expect_false(cd$is_nps)
  expect_equal(cd$series$Total$values, c(52, 55, 58))
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

test_that("build_line_chart produces SVG with smooth path", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  chart <- build_line_chart(html_data$chart_data[[1]], config,
                             decimal_config = html_data$decimal_config)
  expect_true(!is.null(chart))
  chart_str <- as.character(chart)
  expect_true(grepl("<svg", chart_str))
  # Should use smooth <path> not <polyline>
  expect_true(grepl("<path", chart_str))
  expect_true(grepl("circle", chart_str))
  # Should NOT have polyline for the main line (sparklines still use polyline)
  expect_false(grepl("polyline", chart_str))
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

test_that("build_line_chart has proper Y-axis range for percentages", {
  chart_data <- list(
    series = list(Total = list(name = "Total", values = c(52, 55, 58), n = c(500L, 480L, 510L))),
    wave_ids = c("W1", "W2", "W3"),
    wave_labels = c("Jan 2024", "Apr 2024", "Jul 2024"),
    metric_label = "Top 2 Box", metric_name = "top2_box",
    question_code = "Q_SAT",
    is_percentage = TRUE, is_nps = FALSE
  )
  chart <- build_line_chart(chart_data, create_test_config())
  chart_str <- as.character(chart)

  # Y-axis should show 0% and 100% (full percentage range)
  expect_true(grepl("0%", chart_str))
  expect_true(grepl("100%", chart_str))
  # Should NOT show 5200% (the old bug)
  expect_false(grepl("5200", chart_str))
})

test_that("build_line_chart has proper Y-axis range for ratings (0-5 scale)", {
  chart_data <- list(
    series = list(Total = list(name = "Total", values = c(3.2, 3.5, 3.8), n = c(500L, 480L, 510L))),
    wave_ids = c("W1", "W2", "W3"),
    wave_labels = c("Jan 2024", "Apr 2024", "Jul 2024"),
    metric_label = "Satisfaction", metric_name = "mean",
    question_code = "Q_SAT",
    is_percentage = FALSE, is_nps = FALSE
  )
  chart <- build_line_chart(chart_data, create_test_config())
  chart_str <- as.character(chart)

  # Y-axis should range from 0 to 5 (auto-detected for values <= 5.5)
  expect_true(grepl("0\\.00", chart_str))  # Y-axis label: 0.00
  expect_true(grepl("5\\.00", chart_str))  # Y-axis label: 5.00
})

test_that("build_line_chart has proper Y-axis range for ratings (0-10 scale)", {
  chart_data <- list(
    series = list(Total = list(name = "Total", values = c(7.2, 7.5, 8.0), n = c(500L, 480L, 510L))),
    wave_ids = c("W1", "W2", "W3"),
    wave_labels = c("Jan 2024", "Apr 2024", "Jul 2024"),
    metric_label = "Satisfaction", metric_name = "mean",
    question_code = "Q_SAT",
    is_percentage = FALSE, is_nps = FALSE
  )
  chart <- build_line_chart(chart_data, create_test_config())
  chart_str <- as.character(chart)

  # Y-axis should range from 0 to 10 (auto-detected for values > 5.5 and <= 10.5)
  expect_true(grepl(">0\\.00<", chart_str))   # Y-axis label: 0.00
  expect_true(grepl(">10\\.00<", chart_str))  # Y-axis label: 10.00
})

test_that("build_line_chart has proper Y-axis range for NPS", {
  chart_data <- list(
    series = list(Total = list(name = "Total", values = c(32, 38, 41), n = c(500L, 480L, 510L))),
    wave_ids = c("W1", "W2", "W3"),
    wave_labels = c("Jan 2024", "Apr 2024", "Jul 2024"),
    metric_label = "NPS Score", metric_name = "nps_score",
    question_code = "Q_NPS",
    is_percentage = FALSE, is_nps = TRUE
  )
  chart <- build_line_chart(chart_data, create_test_config())
  chart_str <- as.character(chart)

  # Y-axis should range from -100 to +100
  expect_true(grepl("-100", chart_str))
  expect_true(grepl("\\+100", chart_str))
})

test_that("build_smooth_path produces SVG path with cubic bezier for 3+ points", {
  points <- list(c(0, 100), c(100, 50), c(200, 80))
  path <- build_smooth_path(points)

  expect_true(grepl("^M", path))  # Starts with M
  expect_true(grepl("C", path))   # Contains cubic bezier curves
  expect_false(grepl("L", path))  # No straight lines
})

test_that("build_smooth_path produces straight line for 2 points", {
  points <- list(c(0, 100), c(200, 50))
  path <- build_smooth_path(points)

  expect_true(grepl("^M", path))  # Starts with M
  expect_true(grepl("L", path))   # Contains line-to
  expect_false(grepl("C", path))  # No curves
})

test_that("build_smooth_path returns empty for single point", {
  points <- list(c(0, 100))
  path <- build_smooth_path(points)
  expect_equal(path, "")
})

test_that("get_segment_colours returns correct number of colours", {
  cols <- get_segment_colours(c("Total", "Cape Town", "Joburg"), "#323367")
  expect_equal(length(cols), 3)
  expect_equal(cols[1], "#323367")
})

test_that("build_line_chart displays percentage values correctly (no double multiply)", {
  # Test with percentage data that was previously being doubled
  chart_data <- list(
    series = list(Total = list(name = "Total", values = c(52, 55, 58), n = c(500L, 480L, 510L))),
    wave_ids = c("W1", "W2", "W3"),
    wave_labels = c("Jan 2024", "Apr 2024", "Jul 2024"),
    metric_label = "Top 2 Box", metric_name = "top2_box",
    question_code = "Q_SAT",
    is_percentage = TRUE, is_nps = FALSE
  )
  chart <- build_line_chart(chart_data, create_test_config())
  chart_str <- as.character(chart)

  # Should show 52%, 55%, 58% — NOT 5200%, 5500%, 5800%
  expect_true(grepl("52%", chart_str))
  expect_true(grepl("55%", chart_str))
  expect_true(grepl("58%", chart_str))
  expect_false(grepl("5200", chart_str))
  expect_false(grepl("5500", chart_str))
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

test_that("table displays percentage values correctly (no double multiply)", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  table <- build_tracking_table(html_data, config)
  table_str <- as.character(table)

  # Percentage values should be 52%, 55%, 58% — NOT 5200%, 5500%
  expect_true(grepl("52%", table_str))
  expect_true(grepl("55%", table_str))
  expect_true(grepl("58%", table_str))
  expect_false(grepl("5200", table_str))
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

  # Check SVG charts present with smooth paths
  expect_true(grepl("<svg", content))
  expect_true(grepl("<path", content))

  # Percentage values displayed correctly (52%, not 5200%)
  expect_true(grepl("52%", content))

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

  # Should now have 7 JS files: core_navigation, chart_controls, table_export,
  # slide_export, tab_navigation, metrics_view, pinned_views
  expect_true(length(js_files) >= 7)

  for (js_file in js_files) {
    result <- system2("node", args = c("--check", js_file),
                       stdout = TRUE, stderr = TRUE)
    status <- attr(result, "status")
    expect_true(is.null(status) || status == 0,
                info = paste("JS syntax error in", basename(js_file), ":",
                             paste(result, collapse = "\n")))
  }
})


# ==============================================================================
# TESTS: 4-Tab Layout (Phase 2)
# ==============================================================================

test_that("HTML report has 4 report tabs", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Check tab navigation exists
  expect_true(grepl("report-tabs", content))
  expect_true(grepl("Summary", content))
  expect_true(grepl("Metrics by Segment", content))
  expect_true(grepl("Segment Overview", content))
  expect_true(grepl("Pinned Views", content))

  # Check tab panels exist
  expect_true(grepl('id="tab-summary"', content))
  expect_true(grepl('id="tab-metrics"', content))
  expect_true(grepl('id="tab-overview"', content))
  expect_true(grepl('id="tab-pinned"', content))

  # Check tab-panel class
  expect_true(grepl("tab-panel", content))

  unlink(output_path)
})

test_that("Summary tab has stat cards and insight boxes", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Stat cards
  expect_true(grepl("summary-stat-card", content))
  expect_true(grepl("3.*Metrics", content))  # 3 metrics
  expect_true(grepl("3.*Waves", content))    # 3 waves

  # Insight boxes
  expect_true(grepl("Background &amp; Method", content))
  expect_true(grepl("summary-editor", content))
  expect_true(grepl("contenteditable", content))

  unlink(output_path)
})

test_that("Tab switching JS is embedded", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Tab navigation JS
  expect_true(grepl("switchReportTab", content))
  expect_true(grepl("tab_navigation.js", content))

  unlink(output_path)
})


# ==============================================================================
# TESTS: Metrics by Segment Tab (Phase 3)
# ==============================================================================

test_that("Metrics by Segment tab has metric navigation sidebar", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Navigation sidebar
  expect_true(grepl("mv-sidebar", content))
  expect_true(grepl("tk-metric-nav-item", content))
  expect_true(grepl("selectTrackerMetric", content))

  # Should list all metrics in nav
  expect_true(grepl("Satisfaction \\(Mean\\)", content))
  expect_true(grepl("Satisfaction \\(Top 2 Box\\)", content))
  expect_true(grepl("NPS Score", content))

  unlink(output_path)
})

test_that("Metrics by Segment tab has per-metric panels", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Per-metric panels
  expect_true(grepl("tk-metric-panel", content))
  expect_true(grepl('id="mv-metric_1"', content))
  expect_true(grepl('id="mv-metric_2"', content))
  expect_true(grepl('id="mv-metric_3"', content))

  # Metric title
  expect_true(grepl("mv-metric-title", content))

  unlink(output_path)
})

test_that("Metrics by Segment tab has segment chips", {
  crosstab_data <- create_test_crosstab_data()

  # Add a second segment for chip testing
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
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Segment chips
  expect_true(grepl("tk-segment-chip", content))
  expect_true(grepl("toggleSegmentChip", content))

  unlink(output_path)
})

test_that("Metrics by Segment tab has show-chart checkbox and significance toggle", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Show chart checkbox (replaces table/chart toggle)
  expect_true(grepl("toggleShowChart", content))
  expect_true(grepl("mv-show-chart-cb", content))
  expect_true(grepl("Show chart", content))

  # Significance toggle
  expect_true(grepl("toggleSignificance", content))
  expect_true(grepl("hide-significance", content))

  # vs Prev / vs Base toggles
  expect_true(grepl("toggleMetricChangeRows", content))

  unlink(output_path)
})

test_that("Metrics by Segment tab has insight area", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Insight area
  expect_true(grepl("insight-area", content))
  expect_true(grepl("insight-toggle", content))
  expect_true(grepl("insight-editor", content))
  expect_true(grepl("toggleMetricInsight", content))
  expect_true(grepl("syncMetricInsight", content))

  unlink(output_path)
})

test_that("Metrics by Segment tab has pin button", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Pin button
  expect_true(grepl("mv-pin-btn", content))
  expect_true(grepl("pinMetricView", content))

  unlink(output_path)
})

test_that("Metrics by Segment tab has per-metric table with sparkline", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Metric table within panel
  expect_true(grepl("mv-metric-table", content))
  expect_true(grepl("mv-table-area", content))
  expect_true(grepl("mv-chart-area", content))

  # Sparkline
  expect_true(grepl("tk-sparkline", content))

  # Base (n) row
  expect_true(grepl("Base \\(n\\)", content))

  unlink(output_path)
})

test_that("metrics_view.js is embedded", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("metrics_view.js", content))

  unlink(output_path)
})


# ==============================================================================
# TESTS: Pinned Views Tab (Phase 4)
# ==============================================================================

test_that("Pinned Views tab has empty state and container", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Pinned tab content
  expect_true(grepl("pinned-tab-content", content))
  expect_true(grepl("pinned-cards-container", content))
  expect_true(grepl("pinned-empty-state", content))
  expect_true(grepl("No pinned views yet", content))

  # JSON data store
  expect_true(grepl("pinned-views-data", content))

  unlink(output_path)
})

test_that("Pinned views JS is embedded", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("pinned_views.js", content))
  expect_true(grepl("pinnedViews", content))
  expect_true(grepl("togglePin", content))
  expect_true(grepl("renderPinnedCards", content))
  expect_true(grepl("hydratePinnedViews", content))

  unlink(output_path)
})

test_that("Pin count badge exists in tab nav", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("pin-count-badge", content))

  unlink(output_path)
})


# ==============================================================================
# TESTS: Header Style (Turas Tabs match)
# ==============================================================================

test_that("Header uses dark gradient style", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Dark gradient header CSS
  expect_true(grepl("linear-gradient.*#1a2744.*#2a3f5f", content))
  # Turas Tracker branding
  expect_true(grepl("Turas Tracker", content))
  expect_true(grepl("Interactive Tracking Report", content))
  # Badge bar
  expect_true(grepl("tk-badge-bar", content))
  expect_true(grepl("Metrics", content))
  expect_true(grepl("Waves", content))

  unlink(output_path)
})


# ==============================================================================
# TESTS: Per-Metric Table (waves-only columns, n= toggle, hide row/col)
# ==============================================================================

test_that("Per-metric table has wave-only columns (no segment x wave duplication)", {
  crosstab_data <- create_test_crosstab_data()
  # Add second segment
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
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # The mv-metric-table should NOT have segment header rows (segment x wave)
  # It should have a single wave header row
  expect_true(grepl("mv-metric-table", content))
  # Should NOT have tk-segment-header-row in metric tables
  # (it should still exist in the overview tab's table)
  # The metric table has segments as rows, not columns

  unlink(output_path)
})

test_that("Per-metric table has n= frequency display", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # n= frequency elements
  expect_true(grepl("tk-freq", content))
  expect_true(grepl("n=500", content))
  expect_true(grepl("n=480", content))

  # Show count toggle
  expect_true(grepl("Show count", content))
  expect_true(grepl("toggleMetricCounts", content))

  # CSS for freq toggle
  expect_true(grepl("show-freq", content))

  unlink(output_path)
})

test_that("Per-metric table has segment colour dots", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("tk-seg-dot", content))

  unlink(output_path)
})

test_that("Per-metric table uses chip-only segment control (no row exclude buttons)", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Row exclude buttons were removed — segment hiding is chip-only

  expect_false(grepl("row-exclude-btn", content))
  expect_false(grepl("toggleRowExclusion", content))

  # Segment chips should be present for toggling
  expect_true(grepl("tk-segment-chip", content))
  expect_true(grepl("toggleSegmentChip", content))

  unlink(output_path)
})

test_that("Per-metric panel has wave chips for toggling waves", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Wave chips
  expect_true(grepl("tk-wave-chip", content))
  expect_true(grepl("toggleWaveChip", content))
  expect_true(grepl("mv-wave-chips", content))
  # Should have chip for each wave label
  expect_true(grepl("Jan 2024", content))
  expect_true(grepl("Apr 2024", content))
  expect_true(grepl("Jul 2024", content))

  # Wave hidden CSS still present (for table column hiding)
  expect_true(grepl("wave-hidden", content))

  unlink(output_path)
})

test_that("Chart SVG has data-wave attributes on points and labels", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  chart <- build_line_chart(html_data$chart_data[[1]], config,
                             decimal_config = html_data$decimal_config)
  chart_str <- as.character(chart)

  # Data points should have data-wave
  expect_true(grepl('data-wave="W1"', chart_str))
  expect_true(grepl('data-wave="W2"', chart_str))
  expect_true(grepl('data-wave="W3"', chart_str))

  # Value labels should have data-segment and data-wave
  expect_true(grepl('class="tk-chart-label"', chart_str))
  expect_true(grepl('data-segment="Total"', chart_str))

  # X-axis labels should have data-wave
  expect_true(grepl('class="tk-chart-xaxis"', chart_str))
})

test_that("Show chart checkbox replaces table/chart toggle buttons", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Should have "Show chart" checkbox
  expect_true(grepl("Show chart", content))
  expect_true(grepl("toggleShowChart", content))
  expect_true(grepl("mv-show-chart-cb", content))

  # Should NOT have the old table/chart toggle buttons
  expect_false(grepl("toggleMetricView", content))
  expect_false(grepl("mv-view-btn", content))

  unlink(output_path)
})

test_that("Wave table headers no longer have onclick for column hide", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  # Build a metric table directly
  brand_colour <- "#323367"
  segments <- html_data$segments
  segment_colours <- get_segment_colours(segments, brand_colour)
  mr <- html_data$metric_rows[[1]]
  sparkline_data <- html_data$sparkline_data[[1]]

  table_html <- build_metric_table(mr, html_data, sparkline_data, segments, segment_colours, brand_colour)

  # Wave headers should NOT have onclick for toggleWaveColumn
  expect_false(grepl("toggleWaveColumn", table_html))
  # But should still have data-wave attribute
  expect_true(grepl('data-wave="W1"', table_html))
  expect_true(grepl('data-wave="W2"', table_html))
  expect_true(grepl('data-wave="W3"', table_html))
})

test_that("JS has rebuildChartLines and smoothPathFromPoints functions", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Should have the chart rebuild functions for wave chip interactivity
  expect_true(grepl("rebuildChartLines", content))
  expect_true(grepl("smoothPathFromPoints", content))

  unlink(output_path)
})

test_that("JS has global chip state persistence for segment/wave selections", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Global state variables
  expect_true(grepl("var activeSegments", content))
  expect_true(grepl("var activeWaves", content))

  # State persistence functions
  expect_true(grepl("initChipState", content))
  expect_true(grepl("applyChipState", content))

  # selectTrackerMetric should call applyChipState
  expect_true(grepl("applyChipState\\(target\\)", content))

  # toggleSegmentChip should update global activeSegments
  expect_true(grepl("activeSegments\\[segmentName\\]", content))

  # toggleWaveChip should update global activeWaves
  expect_true(grepl("activeWaves\\[waveId\\]", content))

  unlink(output_path)
})

test_that("Wave chip CSS styles are present", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Wave chip CSS
  expect_true(grepl("tk-wave-chip\\.active", content))
  expect_true(grepl("tk-wave-chip:not", content))
  expect_true(grepl("mv-wave-chips-label", content))

  unlink(output_path)
})
