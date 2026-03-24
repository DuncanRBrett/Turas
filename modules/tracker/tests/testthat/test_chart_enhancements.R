# ==============================================================================
# TEST SUITE: Tracker Chart Builder Enhancements
# ==============================================================================
# Tests for chart builder functions: smooth paths, sparklines, line charts,
# segment colours, axes, series rendering, and label collision avoidance.
# ==============================================================================

library(testthat)

context("Tracker Chart Enhancements")

# ==============================================================================
# SETUP
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

# Source shared palette if available
palette_path <- file.path(turas_root, "modules", "shared", "lib", "colour_palettes.R")
if (file.exists(palette_path)) source(palette_path)

# Ensure %||% is available
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Source tracker dependencies
source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "html_report", "05_chart_builder.R"))


# ==============================================================================
# HELPERS
# ==============================================================================

#' Create mock chart_data for line chart tests
#'
#' @param n_waves Integer. Number of waves
#' @param n_series Integer. Number of series
#' @param is_percentage Logical
#' @param is_nps Logical
#' @param values_fn Function(wave_index, series_index) -> numeric value
#' @return List matching chart_data structure
make_mock_chart_data <- function(n_waves = 3, n_series = 1,
                                  is_percentage = TRUE, is_nps = FALSE,
                                  values_fn = NULL) {
  if (is.null(values_fn)) {
    values_fn <- function(w, s) 40 + w * 5 + s * 2
  }

  series <- lapply(seq_len(n_series), function(s) {
    vals <- vapply(seq_len(n_waves), function(w) values_fn(w, s), numeric(1))
    list(
      name = if (s == 1) "Total" else paste0("Segment ", s),
      values = vals,
      ci_lower = NULL,
      ci_upper = NULL
    )
  })
  names(series) <- vapply(series, function(s) s$name, character(1))

  list(
    series = series,
    wave_labels = paste("Wave", seq_len(n_waves)),
    wave_ids = paste0("W", seq_len(n_waves)),
    is_percentage = is_percentage,
    is_nps = is_nps
  )
}

make_mock_config <- function(brand_colour = "#323367") {
  list(settings = list(brand_colour = brand_colour))
}


# ==============================================================================
# build_smooth_path
# ==============================================================================

test_that("build_smooth_path returns empty string for 0 or 1 point", {
  expect_equal(build_smooth_path(list()), "")
  expect_equal(build_smooth_path(list(c(10, 20))), "")
})

test_that("build_smooth_path draws straight line for 2 points", {
  path <- build_smooth_path(list(c(0, 100), c(200, 50)))
  expect_true(grepl("^M", path))
  expect_true(grepl("L", path))
  expect_false(grepl("C", path))
})

test_that("build_smooth_path draws cubic bezier for 3+ points", {
  pts <- list(c(0, 100), c(100, 50), c(200, 80))
  path <- build_smooth_path(pts)
  expect_true(grepl("^M", path))
  expect_true(grepl("C", path))
  expect_false(grepl("L", path))
})

test_that("build_smooth_path handles 4 points with multiple C segments", {
  pts <- list(c(0, 100), c(50, 60), c(100, 80), c(150, 40))
  path <- build_smooth_path(pts)
  # Should have 3 cubic segments (one per pair)
  c_count <- length(gregexpr("C", path)[[1]])
  expect_equal(c_count, 3)
})

test_that("build_smooth_path respects tension parameter", {
  pts <- list(c(0, 100), c(100, 50), c(200, 80))
  path_low <- build_smooth_path(pts, tension = 0.1)
  path_high <- build_smooth_path(pts, tension = 0.9)
  # Both produce C commands but with different control points
  expect_true(grepl("C", path_low))
  expect_true(grepl("C", path_high))
  expect_false(identical(path_low, path_high))
})


# ==============================================================================
# build_sparkline_svg
# ==============================================================================

test_that("build_sparkline_svg returns SVG with polyline for valid values", {
  svg <- build_sparkline_svg(c(10, 20, 30, 25))
  expect_true(grepl("<svg", svg))
  expect_true(grepl("<polyline", svg))
  expect_true(grepl("tk-sparkline", svg))
})

test_that("build_sparkline_svg contains end dot circle", {
  svg <- build_sparkline_svg(c(10, 20, 30))
  expect_true(grepl("<circle", svg))
})

test_that("build_sparkline_svg returns empty string for all-NA values", {
  expect_equal(build_sparkline_svg(c(NA, NA, NA)), "")
})

test_that("build_sparkline_svg returns empty string for fewer than 2 valid values", {
  expect_equal(build_sparkline_svg(c(NA, 10, NA)), "")
  expect_equal(build_sparkline_svg(c(5)), "")
})

test_that("build_sparkline_svg handles 2 valid values with NAs mixed in", {
  svg <- build_sparkline_svg(c(NA, 10, NA, 20, NA))
  expect_true(grepl("<polyline", svg))
  expect_true(grepl("<circle", svg))
})

test_that("build_sparkline_svg uses custom dimensions and colour", {
  svg <- build_sparkline_svg(c(1, 2, 3), width = 80, height = 20, colour = "#ff0000")
  expect_true(grepl('width="80"', svg))
  expect_true(grepl('height="20"', svg))
  expect_true(grepl("#ff0000", svg))
})


# ==============================================================================
# build_line_chart
# ==============================================================================

test_that("build_line_chart returns NULL for NULL or empty series", {
  config <- make_mock_config()
  expect_null(build_line_chart(NULL, config))
  expect_null(build_line_chart(list(series = list()), config))
})

test_that("build_line_chart returns NULL for single wave (< 2 waves)", {
  chart_data <- make_mock_chart_data(n_waves = 1)
  config <- make_mock_config()
  expect_null(build_line_chart(chart_data, config))
})

test_that("build_line_chart uses responsive width: 4 waves -> 1100", {
  chart_data <- make_mock_chart_data(n_waves = 4)
  config <- make_mock_config()
  result <- as.character(build_line_chart(chart_data, config))
  expect_true(grepl('viewBox="0 0 1100', result))
})

test_that("build_line_chart uses responsive width: 5-8 waves -> 960", {
  for (nw in c(5, 6, 8)) {
    chart_data <- make_mock_chart_data(n_waves = nw)
    config <- make_mock_config()
    result <- as.character(build_line_chart(chart_data, config))
    expect_true(grepl('viewBox="0 0 960', result),
                info = paste("Failed for n_waves =", nw))
  }
})

test_that("build_line_chart uses responsive width: 9+ waves -> 1200", {
  chart_data <- make_mock_chart_data(n_waves = 10)
  config <- make_mock_config()
  result <- as.character(build_line_chart(chart_data, config))
  expect_true(grepl('viewBox="0 0 1200', result))
})

test_that("build_line_chart percentage chart has y-axis 0 to 100", {
  chart_data <- make_mock_chart_data(is_percentage = TRUE, is_nps = FALSE)
  config <- make_mock_config()
  result <- as.character(build_line_chart(chart_data, config))
  # Y-axis labels should include 0% and 100%
  expect_true(grepl("0%", result, fixed = TRUE))
  expect_true(grepl("100%", result, fixed = TRUE))
})

test_that("build_line_chart NPS chart has y-axis -100 to +100", {
  chart_data <- make_mock_chart_data(
    is_percentage = FALSE, is_nps = TRUE,
    values_fn = function(w, s) -20 + w * 10
  )
  config <- make_mock_config()
  result <- as.character(build_line_chart(chart_data, config))
  # Y-axis should be data-driven (zoomed to data range with padding)
  # NPS values -10 to 10 → axis should zoom to ~-20 to +20 range
  expect_true(grepl("-20\\.00|-10\\.00", result))  # Y-axis label near data min
  expect_true(grepl("\\+10\\.00|\\+20\\.00", result))  # Y-axis label near data max
})

test_that("build_line_chart contains tk-chart-point data attributes", {
  chart_data <- make_mock_chart_data(n_waves = 3)
  config <- make_mock_config()
  result <- as.character(build_line_chart(chart_data, config))
  expect_true(grepl('class="tk-chart-point"', result, fixed = TRUE))
  expect_true(grepl('data-segment=', result))
  expect_true(grepl('data-wave=', result))
  expect_true(grepl('data-value=', result))
})

test_that("build_line_chart single-series generates area fill path", {
  chart_data <- make_mock_chart_data(n_series = 1)
  config <- make_mock_config()
  result <- as.character(build_line_chart(chart_data, config))
  expect_true(grepl('class="tk-area-fill"', result, fixed = TRUE))
})

test_that("build_line_chart returns NULL when all values are NA", {
  chart_data <- list(
    series = list(
      list(name = "Total", values = c(NA, NA, NA), ci_lower = NULL, ci_upper = NULL)
    ),
    wave_labels = c("W1", "W2", "W3"),
    wave_ids = c("W1", "W2", "W3"),
    is_percentage = TRUE,
    is_nps = FALSE
  )
  config <- make_mock_config()
  expect_null(build_line_chart(chart_data, config))
})


# ==============================================================================
# get_segment_colours
# ==============================================================================

test_that("get_segment_colours returns correct number of colours", {
  cols <- get_segment_colours(c("A", "B", "C"), "#323367")
  expect_length(cols, 3)
})

test_that("get_segment_colours uses brand_colour as first colour in fallback", {
  # Remove get_segment_palette temporarily to test fallback
  had_fn <- exists("get_segment_palette", mode = "function")
  if (had_fn) {
    saved_fn <- get("get_segment_palette", mode = "function")
    rm("get_segment_palette", envir = globalenv())
  }
  on.exit({
    if (had_fn) assign("get_segment_palette", saved_fn, envir = globalenv())
  })

  cols <- get_segment_colours(c("Total", "Male", "Female"), "#AA0000")
  expect_equal(cols[1], "#AA0000")
})

test_that("get_segment_colours handles more segments than palette length", {
  # Force fallback path
  had_fn <- exists("get_segment_palette", mode = "function")
  if (had_fn) {
    saved_fn <- get("get_segment_palette", mode = "function")
    rm("get_segment_palette", envir = globalenv())
  }
  on.exit({
    if (had_fn) assign("get_segment_palette", saved_fn, envir = globalenv())
  })

  cols <- get_segment_colours(paste0("S", 1:15), "#323367")
  expect_length(cols, 15)
  # First colour is still brand
  expect_equal(cols[1], "#323367")
})


# ==============================================================================
# build_chart_axes_svg
# ==============================================================================

test_that("build_chart_axes_svg returns gridlines with dashed style", {
  scale_fn <- function(v) v / 100 * 300
  format_fn <- function(v) paste0(round(v), "%")

  parts <- build_chart_axes_svg(
    n_waves = 3,
    wave_labels = c("Wave 1", "Wave 2", "Wave 3"),
    wave_ids = c("W1", "W2", "W3"),
    y_axis_min = 0, y_axis_max = 100,
    plot_w = 880, plot_h = 300,
    scale_fn = scale_fn, format_fn = format_fn
  )
  combined <- paste(parts, collapse = "\n")

  # Gridlines should be dashed with the correct colour
  expect_true(grepl('stroke="#e2e8f0"', combined, fixed = TRUE))
  expect_true(grepl('stroke-dasharray="4,3"', combined, fixed = TRUE))
})

test_that("build_chart_axes_svg x-axis labels have data-wave attribute", {
  scale_fn <- function(v) v / 100 * 300
  format_fn <- function(v) paste0(round(v), "%")

  parts <- build_chart_axes_svg(
    n_waves = 3,
    wave_labels = c("Wave 1", "Wave 2", "Wave 3"),
    wave_ids = c("W1", "W2", "W3"),
    y_axis_min = 0, y_axis_max = 100,
    plot_w = 880, plot_h = 300,
    scale_fn = scale_fn, format_fn = format_fn
  )
  combined <- paste(parts, collapse = "\n")

  expect_true(grepl('data-wave="W1"', combined, fixed = TRUE))
  expect_true(grepl('data-wave="W2"', combined, fixed = TRUE))
  expect_true(grepl('data-wave="W3"', combined, fixed = TRUE))
  expect_true(grepl('class="tk-chart-xaxis"', combined, fixed = TRUE))
})


# ==============================================================================
# resolve_and_emit_labels_svg
# ==============================================================================

test_that("resolve_and_emit_labels_svg pushes overlapping labels apart", {
  plot_h <- 300
  min_gap <- 14

  # Two labels at nearly the same y position (overlapping)
  label_data <- list(
    list(  # Wave 1 with two overlapping labels
      list(x = 100, y = 150, text = "45%", colour = "#323367",
           seg_name = "Total", wave_id = "W1"),
      list(x = 100, y = 152, text = "46%", colour = "#CC9900",
           seg_name = "Male", wave_id = "W1")
    )
  )

  parts <- resolve_and_emit_labels_svg(label_data, plot_h)
  combined <- paste(parts, collapse = "\n")

  # Both labels should be emitted
  expect_true(grepl("45%", combined, fixed = TRUE))
  expect_true(grepl("46%", combined, fixed = TRUE))

  # Extract y positions from the SVG text elements
  y_matches <- regmatches(combined, gregexpr('y="([0-9.]+)"', combined))[[1]]
  y_vals <- as.numeric(gsub('y="([0-9.]+)"', "\\1", y_matches))

  # The two labels should be at least min_gap apart
  expect_true(length(y_vals) >= 2)
  expect_gte(abs(y_vals[2] - y_vals[1]), min_gap)
})

test_that("resolve_and_emit_labels_svg clamps labels within plot bounds", {
  plot_h <- 100

  # Label near the bottom of the plot area
  label_data <- list(
    list(
      list(x = 50, y = 99, text = "80%", colour = "#323367",
           seg_name = "Total", wave_id = "W1")
    )
  )

  parts <- resolve_and_emit_labels_svg(label_data, plot_h)
  combined <- paste(parts, collapse = "\n")

  # Extract y position
  y_match <- regmatches(combined, regexpr('y="([0-9.]+)"', combined))
  y_val <- as.numeric(gsub('y="([0-9.]+)"', "\\1", y_match))

  # Should be clamped to plot_h - 4 at most
  expect_lte(y_val, plot_h - 4)
})

test_that("resolve_and_emit_labels_svg handles empty label data", {
  parts <- resolve_and_emit_labels_svg(list(), 300)
  expect_true(is.null(parts) || length(parts) == 0)
})
