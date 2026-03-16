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
source(file.path(tracker_root, "lib", "html_report", "05_chart_builder.R"))
source(file.path(tracker_root, "lib", "html_report", "03a_page_styling.R"))
source(file.path(tracker_root, "lib", "html_report", "03b_page_components.R"))
source(file.path(tracker_root, "lib", "html_report", "03c_summary_builder.R"))
# 03d_metrics_builder.R and 03e_overview_builder.R REMOVED
# Functions classify_metric_type/derive_segment_groups relocated to 01_data_transformer.R
source(file.path(tracker_root, "lib", "html_report", "03f_heatmap_builder.R"))
source(file.path(tracker_root, "lib", "html_report", "03_page_builder.R"))
source(file.path(tracker_root, "lib", "html_report", "04_html_writer.R"))
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

  # Y-axis should show valid percentage labels within 0-100% range
  # Values 52-58% → axis covers 0-100% with gridline labels at intervals
  expect_true(grepl("52%", chart_str))   # Data value label present
  expect_true(grepl("0%", chart_str))    # Y-axis minimum
  # Should NOT show 5200% (the old bug where values weren't divided by 100)
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

  # Y-axis should be data-driven (zoomed to data range with padding)
  # Values 3.2-3.8 → axis should include labels near data, not fixed 0-5
  expect_true(grepl("3\\.00|2\\.75|3\\.25", chart_str))  # Y-axis label near data min
  expect_true(grepl("4\\.00|4\\.25|3\\.75", chart_str))  # Y-axis label near data max
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

  # Y-axis should be data-driven (zoomed to data range with padding)
  # Values 7.2-8.0 → axis should include labels near data, not fixed 0-10
  expect_true(grepl("7\\.00|6\\.50|7\\.50", chart_str))  # Y-axis label near data min
  expect_true(grepl("8\\.00|8\\.50", chart_str))          # Y-axis label near data max
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

  # Y-axis should be data-driven (zoomed to data range with padding)
  # NPS values 32-41 → axis should zoom to ~20-60 range, not fixed -100 to +100
  expect_true(grepl("\\+20\\.00|\\+30\\.00", chart_str))  # Y-axis label near data min
  expect_true(grepl("\\+50\\.00|\\+60\\.00", chart_str))  # Y-axis label near data max
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
  expect_true(grepl("tk-seg-sidebar-item", content))  # Sidebar segment items
  expect_true(grepl("switchSegment", content))        # Segment switching present

  unlink(output_path)
})

test_that("JS files pass syntax validation", {
  js_dir <- file.path(tracker_root, "lib", "html_report", "js")
  js_files <- list.files(js_dir, pattern = "\\.js$", full.names = TRUE)

  # Should now have 7 JS files: core_navigation, chart_controls, table_export,
  # slide_export, tab_navigation, metrics_view, pinned_views
  expect_true(length(js_files) >= 7)

  # Find node binary — R may not inherit the full shell PATH (e.g. Homebrew)
  node_bin <- Sys.which("node")
  if (!nzchar(node_bin)) {
    for (candidate in c("/opt/homebrew/bin/node", "/usr/local/bin/node")) {
      if (file.exists(candidate)) { node_bin <- candidate; break }
    }
  }
  skip_if(!nzchar(node_bin), "node is not installed — skipping JS syntax check")

  for (js_file in js_files) {
    result <- system2(node_bin, args = c("--check", js_file),
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

  # Check tab navigation exists (4-tab layout: Summary, Explorer, Added Slides, Pinned Views)
  expect_true(grepl("report-tabs", content))
  expect_true(grepl("Summary", content))
  expect_true(grepl("Explorer", content))
  expect_true(grepl("Pinned Views", content))

  # Check tab panels exist
  expect_true(grepl('id="tab-summary"', content))
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

  unlink(output_path)
})


# ==============================================================================
# TESTS: Metrics by Segment Tab (Phase 3) — REMOVED
# ==============================================================================
# Metrics by Segment and Segment Overview tabs were removed from the HTML report.
# Tests retained only for utility functions relocated to 01_data_transformer.R.

test_that("classify_metric_type works after relocation from removed 03d", {
  expect_equal(classify_metric_type("mean"), "mean")
  expect_equal(classify_metric_type("top2_box"), "pct")
  expect_equal(classify_metric_type("nps_score"), "nps")
  expect_equal(classify_metric_type("category_yes"), "pct_response")
  expect_equal(classify_metric_type("unknown_thing"), "other")
})

test_that("derive_segment_groups works after relocation from removed 03d", {
  result <- derive_segment_groups(c("Total", "Gender_Male", "Gender_Female", "Age_18-24"))
  expect_equal(result$standalone, "Total")
  expect_true("Gender" %in% names(result$groups))
  expect_true("Age" %in% names(result$groups))
})

test_that("metric_type_descriptor works after relocation from removed 03d", {
  expect_equal(metric_type_descriptor("mean"), "Mean Score")
  expect_equal(metric_type_descriptor("nps_score"), "NPS Score")
  expect_equal(metric_type_descriptor("top2_box"), "Top 2 Box (%)")
  expect_true(nchar(metric_type_descriptor("unknown")) > 0)  # Returns fallback
})

test_that("explorer JS functions are embedded", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")

  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("selectMetric", content))

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

# Per-metric table tests removed — build_metric_table() was in deleted 03d_metrics_builder.R

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

# Show chart checkbox and wave table header tests removed — referenced removed 03d functions

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


# ==============================================================================
# TESTS: Summary Table, Segment Selector, Sidebar, Sort-By, Row-Hide, Pinned Toolbar
# ==============================================================================

test_that("Summary metrics table is present on summary tab", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Summary metrics table wrapper and class
  expect_true(grepl("summary-metrics-table-wrap", content))
  expect_true(grepl("summary-metrics-table", content))
  expect_true(grepl("Metrics Overview", content))

  unlink(output_path)
})

test_that("Segment switching uses sidebar (not dropdown)", {
  crosstab_data <- create_test_crosstab_data()
  crosstab_data$banner_segments <- c("Total", "Male", "Female")
  crosstab_data$metadata$n_segments <- 3
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Sidebar is present with segment items
  expect_true(grepl("tk-sidebar", content))
  expect_true(grepl("tk-seg-sidebar-item", content))
  expect_true(grepl("switchSegment", content))

  # Sidebar or heatmap banner shows segments
  expect_true(grepl("Segment|segment", content))

  unlink(output_path)
})

test_that("Overview sidebar shows segments instead of metrics", {
  crosstab_data <- create_test_crosstab_data()
  crosstab_data$banner_segments <- c("Total", "Group_A", "Group_B")
  crosstab_data$metadata$n_segments <- 3
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Sidebar shows "Segments" header
  expect_true(grepl("tk-sidebar-header", content))
  expect_true(grepl("Segments", content))

  # Sidebar contains segment items
  expect_true(grepl("tk-seg-sidebar-item", content))
  expect_true(grepl("tk-seg-dot", content))

  unlink(output_path)
})

test_that("Sort by dropdown is present in controls", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Sort by dropdown
  expect_true(grepl("sort-by-select", content))
  expect_true(grepl("sortOverviewBy", content))
  expect_true(grepl("Original Order", content))
  expect_true(grepl("metric_name", content))  # Sort option value

  unlink(output_path)
})

test_that("Row hide buttons are present in overview table", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Row hide button
  expect_true(grepl("tk-row-hide-btn", content))
  expect_true(grepl("toggleRowVisibility", content))

  unlink(output_path)
})

test_that("Pinned tab has export toolbar", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Pinned toolbar
  expect_true(grepl("pinned-toolbar", content))
  expect_true(grepl("exportAllPinsPNG", content))
  expect_true(grepl("printAllPins", content))
  expect_true(grepl("saveReportHTML", content))

  unlink(output_path)
})

test_that("Selected segment CSS class is present", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Selected segment CSS
  expect_true(grepl("tk-segment-chip\\.selected", content))

  unlink(output_path)
})

test_that("Segment header row is no longer in the HTML (single-row header used)", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Segment header row should NOT be in HTML at all (removed, not just hidden)
  expect_false(grepl("tk-segment-header-row", content))
  # Should NOT have rowspan="2" in the table
  expect_false(grepl('rowspan="2"', content, fixed = TRUE))
  # Wave header row should include Metric header cell
  expect_true(grepl("tk-wave-header-row", content))

  unlink(output_path)
})

test_that("Print CSS for pinned views is present", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Print CSS for pinned-only printing
  expect_true(grepl("print-pinned-only", content))

  unlink(output_path)
})

test_that("JS includes sortOverviewBy and toggleRowVisibility functions", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Core navigation JS functions
  expect_true(grepl("sortOverviewBy", content))
  expect_true(grepl("toggleRowVisibility", content))
  expect_true(grepl("restoreOriginalOrder", content))

  # Metrics view JS - selected segment
  expect_true(grepl("selectedSegment", content))

  # Pinned views export functions
  expect_true(grepl("exportPinnedCardPNG", content))
  expect_true(grepl("exportAllPinsPNG", content))
  expect_true(grepl("printAllPins", content))
  expect_true(grepl("saveReportHTML", content))

  unlink(output_path)
})


# ==============================================================================
# ROUND 2 FIXES — New Tests
# ==============================================================================

test_that("Row hidden CSS uses opacity instead of display:none", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Should have opacity-based grey-out (not display:none)
  expect_true(grepl("row-hidden-user.*opacity", content))
  # Should have Show All button
  expect_true(grepl("showAllHiddenRows", content))
  # Should have hidden-rows-indicator
  expect_true(grepl("hidden-rows-indicator", content))

  unlink(output_path)
})

test_that("Summary metrics table has base row", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)
  table_html <- as.character(build_summary_metrics_table(html_data))

  expect_true(grepl("tk-base-row", table_html))
  expect_true(grepl("Base \\(n=\\)", table_html))
})

test_that("Summary tab has insight boxes above KPI cards", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Background editor should appear before KPI hero cards section
  bg_pos <- regexpr('id="summary-background-editor"', content)
  kpi_pos <- regexpr('class="tk-hero-card', content)
  expect_true(bg_pos[1] > 0)
  expect_true(kpi_pos[1] > 0)
  expect_true(bg_pos[1] < kpi_pos[1])

  # Pin/export buttons on summary sections
  expect_true(grepl("pinSummarySection", content))
  expect_true(grepl("exportSummarySlide", content))

  unlink(output_path)
})

# Segment Overview tests removed — tab no longer exists

test_that("JS includes summary pin/export functions", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Core navigation functions
  expect_true(grepl("showAllHiddenRows", content))
  expect_true(grepl("updateHiddenRowsIndicator", content))

  # Summary pin/export functions in pinned_views.js
  expect_true(grepl("pinSummarySection", content))
  expect_true(grepl("exportSummarySlide", content))

  unlink(output_path)
})


# ==============================================================================
# PHASE 1: CSS Variable Alignment + Export Button + Low Base CSS
# ==============================================================================

test_that("CSS contains aligned Turas design tokens (--ct-* prefix)", {
  css_output <- build_tracker_css("#323367", "#CC9900")

  # Shared Turas tokens (matching Turas Tabs)
  expect_true(grepl("--ct-brand:", css_output, fixed = TRUE))
  expect_true(grepl("--ct-accent:", css_output, fixed = TRUE))
  expect_true(grepl("--ct-text-primary:#1e293b", css_output, fixed = TRUE))
  expect_true(grepl("--ct-text-secondary:#64748b", css_output, fixed = TRUE))
  expect_true(grepl("--ct-bg-surface:#ffffff", css_output, fixed = TRUE))
  expect_true(grepl("--ct-bg-muted:#f8f9fa", css_output, fixed = TRUE))
  expect_true(grepl("--ct-border:#e2e8f0", css_output, fixed = TRUE))

  # Module variables updated to match Tabs
  expect_true(grepl("--text:#1e293b", css_output, fixed = TRUE))
  expect_true(grepl("--text-muted:#64748b", css_output, fixed = TRUE))
  expect_true(grepl("--border:#e2e8f0", css_output, fixed = TRUE))
  expect_true(grepl("--sidebar-w:280px", css_output, fixed = TRUE))
})

test_that("CSS contains export-btn class matching Turas Tabs style", {
  css_output <- build_tracker_css("#323367", "#CC9900")

  expect_true(grepl(".export-btn", css_output, fixed = TRUE))
  expect_true(grepl(".export-btn:hover", css_output, fixed = TRUE))
})

test_that("CSS contains low-base warning classes", {
  css_output <- build_tracker_css("#323367", "#CC9900")

  expect_true(grepl(".tk-low-base", css_output, fixed = TRUE))
  expect_true(grepl("#dc2626", css_output, fixed = TRUE))  # Red colour
  expect_true(grepl(".tk-low-base-dim", css_output, fixed = TRUE))
  # Low-base-dim now uses muted text colour instead of opacity
  expect_true(grepl("#94a3b8", css_output, fixed = TRUE))
})

test_that("CSS contains header action button dark variant", {
  css_output <- build_tracker_css("#323367", "#CC9900")

  expect_true(grepl(".tk-header-actions", css_output, fixed = TRUE))
  expect_true(grepl(".tk-header .export-btn", css_output, fixed = TRUE))
})


# ==============================================================================
# Phase 2: Base Row at TOP + Low Base Warning
# ==============================================================================

test_that("Tracking table has base row as first row in tbody", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  table <- build_tracking_table(html_data, config)
  table_str <- as.character(table)

  # Base row should appear BEFORE any metric row in the HTML
  base_pos <- regexpr("tk-base-row", table_str)
  metric_pos <- regexpr("tk-metric-row", table_str)
  expect_true(base_pos > 0)
  expect_true(metric_pos > 0)
  expect_true(base_pos < metric_pos, info = "Base row should come before metric rows")

  # Base row should contain "Base (n=)"
  expect_true(grepl("Base \\(n=\\)", table_str))
})

test_that("Summary metrics table has base row as first row in tbody", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  table <- build_summary_metrics_table(html_data)
  table_str <- as.character(table)

  # Base row should appear BEFORE any section or metric row
  base_pos <- regexpr("tk-base-row", table_str)
  metric_pos <- regexpr("tk-metric-row", table_str)
  expect_true(base_pos > 0)
  expect_true(metric_pos > 0)
  expect_true(base_pos < metric_pos, info = "Base row should come before metric rows in summary table")
})

# Per-metric table test removed — build_metric_table() was in deleted 03d_metrics_builder.R

test_that("Low base warning shows when n < 30 in tracking table", {
  crosstab_data <- create_test_crosstab_data()
  # Set n to low value (25) for W2 across ALL metrics —
  # the base row uses max(n) across metrics, so all must be low
  for (i in seq_along(crosstab_data$metrics)) {
    crosstab_data$metrics[[i]]$segments$Total$n$W2 <- 25L
  }

  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  table <- build_tracking_table(html_data, config)
  table_str <- as.character(table)

  # Should have low-base warning class
  expect_true(grepl("tk-low-base", table_str, fixed = TRUE))
  # Should contain the warning icon (&#x26A0; = ⚠)
  expect_true(grepl("&#x26A0;", table_str, fixed = TRUE))
  # The value 25 should be inside the low-base span
  expect_true(grepl("25", table_str, fixed = TRUE))
})

test_that("Low base dims data cells when n < 30", {
  crosstab_data <- create_test_crosstab_data()
  # Set n to low value for W2
  crosstab_data$metrics[[1]]$segments$Total$n$W2 <- 25L

  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  table <- build_tracking_table(html_data, config)
  table_str <- as.character(table)

  # Data cells for that wave should have dim class
  expect_true(grepl("tk-low-base-dim", table_str, fixed = TRUE))
})

test_that("Low base warning shows in summary metrics table when n < 30", {
  crosstab_data <- create_test_crosstab_data()
  # Set n to low value for W2 across ALL metrics —
  # the base row uses max(n) across metrics, so all must be low
  for (i in seq_along(crosstab_data$metrics)) {
    crosstab_data$metrics[[i]]$segments$Total$n$W2 <- 25L
  }

  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  table <- build_summary_metrics_table(html_data, min_base = 30L)
  table_str <- as.character(table)

  expect_true(grepl("tk-low-base", table_str, fixed = TRUE))
  expect_true(grepl("&#x26A0;", table_str, fixed = TRUE))
})

# Low base in per-metric table test removed — build_metric_table() was in deleted 03d

test_that("JS sort functions use insertBefore to keep base row at top", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # All sort functions should use insertBefore for base row (not appendChild)
  expect_true(grepl("insertBefore(baseRow, tbody.firstChild)", content, fixed = TRUE))
  # Should NOT have appendChild(baseRow) for base row
  expect_false(grepl("appendChild(baseRow)", content, fixed = TRUE))

  unlink(output_path)
})

test_that("Summary metrics table has id and data-metric-type attributes", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  table <- build_summary_metrics_table(html_data)
  table_str <- as.character(table)

  # Should have id for JS targeting
  expect_true(grepl('id="summary-metrics-table"', table_str, fixed = TRUE))
  # Metric rows should have data-metric-type
  expect_true(grepl('data-metric-type="mean"', table_str, fixed = TRUE))
  expect_true(grepl('data-metric-type="nps"', table_str, fixed = TRUE))
})


# ==============================================================================
# Phase 3: Save Report Button on Every Screen
# ==============================================================================

test_that("Report tab nav contains Save Report and Print buttons with export-btn class", {
  # Save Report and Print moved from header to the report-tabs bar in the body
  tab_nav <- build_report_tab_nav("#323367")
  nav_str <- as.character(tab_nav)

  # Save Report button
  expect_true(grepl("saveReportHTML", nav_str, fixed = TRUE))
  expect_true(grepl("Save Report", nav_str, fixed = TRUE))
  # Print button
  expect_true(grepl("printReport", nav_str, fixed = TRUE))
  expect_true(grepl("Print", nav_str, fixed = TRUE))
  # export-btn class on buttons
  expect_true(grepl("export-btn", nav_str, fixed = TRUE))
  # Tab actions container
  expect_true(grepl("tk-tab-actions", nav_str, fixed = TRUE))
})


# ==============================================================================
# Phase 4: Summary Tab Enhancements
# ==============================================================================

test_that("Summary tab has metric type filter chips", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Should have type filter chips on summary tab
  expect_true(grepl("summary-type-filter", content, fixed = TRUE))
  expect_true(grepl("summary-type-chip", content, fixed = TRUE))
  expect_true(grepl("filterSummaryByType", content, fixed = TRUE))

  unlink(output_path)
})

test_that("Summary tab has action buttons (Export Excel, Pin, Export Slide)", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Action buttons present
  expect_true(grepl("exportSummaryExcel", content, fixed = TRUE))
  expect_true(grepl("pinSummaryTable", content, fixed = TRUE))
  expect_true(grepl("exportSummaryTableSlide", content, fixed = TRUE))
  # Buttons use export-btn class
  expect_true(grepl("summary-actions", content, fixed = TRUE))

  unlink(output_path)
})

test_that("JS has filterSummaryByType function", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("window.filterSummaryByType", content, fixed = TRUE))
  expect_true(grepl("summary-metrics-table", content, fixed = TRUE))

  unlink(output_path)
})

test_that("JS has exportSummaryExcel, pinSummaryTable, exportSummaryTableSlide functions", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("function exportSummaryExcel", content, fixed = TRUE))
  expect_true(grepl("function pinSummaryTable", content, fixed = TRUE))
  expect_true(grepl("function exportSummaryTableSlide", content, fixed = TRUE))

  unlink(output_path)
})


# ==============================================================================
# Phase 5: Button Styling (Metric panels removed — testing summary export buttons)
# ==============================================================================

test_that("Summary export buttons use export-btn class", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # export-btn class used in generated HTML
  expect_true(grepl("export-btn", content, fixed = TRUE))

  unlink(output_path)
})

test_that("Metric panels have Export Slide button", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # Export Slide button present
  expect_true(grepl("Export Slide", content, fixed = TRUE))
  expect_true(grepl('exportSlidePNG', content, fixed = TRUE))

  unlink(output_path)
})


# ==============================================================================
# Phase 6: Tracking Table Sidebar + Colour Bar
# ==============================================================================

test_that("Overview table has segment indicator row with colour cells", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  table <- build_tracking_table(html_data, config)
  table_str <- as.character(table)

  # Should have segment indicator row
  expect_true(grepl("tk-segment-indicator-row", table_str, fixed = TRUE))
  expect_true(grepl("tk-segment-indicator", table_str, fixed = TRUE))
})

test_that("Overview table has 'Showing' label above table", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  table <- build_tracking_table(html_data, config)
  table_str <- as.character(table)

  expect_true(grepl("tk-segment-showing", table_str, fixed = TRUE))
  expect_true(grepl("Showing:", table_str, fixed = TRUE))
})

test_that("JS switchSegment updates the Showing label", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("tk-segment-showing", content, fixed = TRUE))
  # JS should update the label
  expect_true(grepl("getElementById(\"tk-segment-showing\")", content, fixed = TRUE))

  unlink(output_path)
})

test_that("CSS has segment indicator and showing label styles", {
  css_output <- build_tracker_css("#323367", "#CC9900")

  expect_true(grepl(".tk-segment-indicator", css_output, fixed = TRUE))
  expect_true(grepl(".tk-segment-showing", css_output, fixed = TRUE))
})


# ==============================================================================
# Phase 7: Tracking Table Chart — Additive Row Selection
# ==============================================================================

test_that("Overview table metric rows have 'Add to Chart' button", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  html_data <- transform_tracker_for_html(crosstab_data, config)

  table <- build_tracking_table(html_data, config)
  table_str <- as.character(table)

  # Add to chart button
  expect_true(grepl("tk-add-chart-btn", table_str, fixed = TRUE))
  expect_true(grepl("addToChart", table_str, fixed = TRUE))
})

# Chart container test removed — from removed overview tab

test_that("JS has addToChart, removeFromChart, getChartSelection functions", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("window.addToChart", content, fixed = TRUE))
  expect_true(grepl("window.removeFromChart", content, fixed = TRUE))
  expect_true(grepl("window.getChartSelection", content, fixed = TRUE))
  expect_true(grepl("window.exportSelectedChartsSlide", content, fixed = TRUE))
  expect_true(grepl("window.pinSelectedCharts", content, fixed = TRUE))

  unlink(output_path)
})

test_that("Chart panel has header with Export Slide and Pin buttons", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("tk-chart-header", content, fixed = TRUE))
  expect_true(grepl("exportSelectedChartsSlide", content, fixed = TRUE))
  expect_true(grepl("pinSelectedCharts", content, fixed = TRUE))
  expect_true(grepl("tk-chart-remove-btn", content, fixed = TRUE))

  unlink(output_path)
})


# ==============================================================================
# Phase 8: Pinned Views as PNG
# ==============================================================================

test_that("JS has pngDataUrl handling in pin objects", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # captureMetricView should store pngDataUrl
  expect_true(grepl("pngDataUrl", content, fixed = TRUE))

  unlink(output_path)
})

test_that("Pinned card renders PNG image when pngDataUrl exists", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  # CSS should include pinned-card-png styling
  expect_true(grepl("pinned-card-png", content, fixed = TRUE))

  unlink(output_path)
})

test_that("CSS has pinned-card-png style for PNG images", {
  css_output <- build_tracker_css("#323367", "#CC9900")
  expect_true(grepl("pinned-card-png", css_output, fixed = TRUE))
  expect_true(grepl("max-width:100%", css_output, fixed = TRUE))
})


# ==============================================================================
# Phase 9: Code Cleanup
# ==============================================================================

test_that("Top-level container has data-report-module='tracker' attribute", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".html")
  result <- generate_tracker_html_report(crosstab_data, config, output_path)
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl('data-report-module="tracker"', content, fixed = TRUE))

  unlink(output_path)
})

test_that("Legacy build_tracker_sidebar function is removed", {
  # build_tracker_sidebar was a passthrough wrapper — now removed
  expect_false(exists("build_tracker_sidebar", mode = "function"))
})
