library(testthat)
context("Tracker Annotations")

# ==============================================================================
# Setup: source required files
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

assign(".tracker_lib_dir", file.path(tracker_root, "lib"), envir = globalenv())

palette_path <- file.path(turas_root, "modules", "shared", "lib", "colour_palettes.R")
if (file.exists(palette_path)) source(palette_path)

source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "html_report", "05_chart_builder.R"))
source(file.path(tracker_root, "lib", "html_report", "03b_page_components.R"))
source(file.path(tracker_root, "lib", "html_report", "03c_summary_builder.R"))
# 03d_metrics_builder.R and 03e_overview_builder.R REMOVED
# Functions classify_metric_type/derive_segment_groups relocated to 01_data_transformer.R
source(file.path(tracker_root, "lib", "html_report", "03_page_builder.R"))


# ==============================================================================
# Test: No annotations in config
# ==============================================================================

test_that("build_annotations_json returns '[]' when settings has no annotations", {
  config <- list(settings = list())
  result <- build_annotations_json(config)
  expect_equal(result, "[]")
})


# ==============================================================================
# Test: NULL annotations
# ==============================================================================

test_that("build_annotations_json returns '[]' when annotations is NULL", {
  config <- list(settings = list(annotations = NULL))
  result <- build_annotations_json(config)
  expect_equal(result, "[]")
})


# ==============================================================================
# Test: Data frame annotations
# ==============================================================================

test_that("build_annotations_json handles data frame annotations", {
  ann_df <- data.frame(
    metric_id = c("Q1_mean", "Q2_pct"),
    wave_id   = c("W3", "W2"),
    segment   = c("Total", "Male"),
    text      = c("Campaign launched", "Price change"),
    colour    = c("#ff0000", "#00ff00"),
    stringsAsFactors = FALSE
  )
  config <- list(settings = list(annotations = ann_df))
  result <- build_annotations_json(config)

  parsed <- jsonlite::fromJSON(result)
  expect_equal(nrow(parsed), 2)
  expect_true(all(c("metricId", "waveId", "segment", "text", "colour") %in% names(parsed)))
})


# ==============================================================================
# Test: List of lists annotations
# ==============================================================================

test_that("build_annotations_json handles list of lists", {
  ann_list <- list(
    list(metric_id = "Q1_mean", wave_id = "W3", text = "Event A"),
    list(metricId = "Q2_pct", waveId = "W2", text = "Event B", colour = "#123456")
  )
  config <- list(settings = list(annotations = ann_list))
  result <- build_annotations_json(config)

  parsed <- jsonlite::fromJSON(result)
  expect_equal(nrow(parsed), 2)
  expect_true(all(c("metricId", "waveId", "segment", "text", "colour") %in% names(parsed)))
})


# ==============================================================================
# Test: Empty text filtered out
# ==============================================================================

test_that("annotations with empty text are excluded", {
  ann_df <- data.frame(
    metric_id = c("Q1_mean", "Q2_pct"),
    wave_id   = c("W3", "W2"),
    text      = c("Campaign launched", ""),
    stringsAsFactors = FALSE
  )
  config <- list(settings = list(annotations = ann_df))
  result <- build_annotations_json(config)

  parsed <- jsonlite::fromJSON(result)
  expect_equal(nrow(parsed), 1)
  expect_equal(parsed$text, "Campaign launched")
})


# ==============================================================================
# Test: Empty metricId filtered out
# ==============================================================================

test_that("annotations without metric_id are excluded", {
  ann_list <- list(
    list(metric_id = "Q1_mean", wave_id = "W3", text = "Valid"),
    list(wave_id = "W2", text = "No metric")
  )
  config <- list(settings = list(annotations = ann_list))
  result <- build_annotations_json(config)

  parsed <- jsonlite::fromJSON(result)
  expect_equal(nrow(parsed), 1)
  expect_equal(parsed$metricId, "Q1_mean")
})


# ==============================================================================
# Test: Default segment is "Total"
# ==============================================================================

test_that("default segment is 'Total' when not specified", {
  ann_list <- list(
    list(metric_id = "Q1_mean", wave_id = "W3", text = "No segment")
  )
  config <- list(settings = list(annotations = ann_list))
  result <- build_annotations_json(config)

  parsed <- jsonlite::fromJSON(result)
  expect_equal(parsed$segment, "Total")
})


# ==============================================================================
# Test: Default colour is "#64748b"
# ==============================================================================

test_that("default colour is '#64748b' when not specified", {
  ann_list <- list(
    list(metric_id = "Q1_mean", wave_id = "W3", text = "No colour")
  )
  config <- list(settings = list(annotations = ann_list))
  result <- build_annotations_json(config)

  parsed <- jsonlite::fromJSON(result)
  expect_equal(parsed$colour, "#64748b")
})


# ==============================================================================
# Test: Supports both metric_id and metricId (and wave_id/waveId)
# ==============================================================================

test_that("supports both metric_id/metricId and wave_id/waveId field names", {
  ann_list <- list(
    list(metric_id = "Q1_mean", wave_id = "W3", text = "snake_case"),
    list(metricId = "Q2_pct", waveId = "W2", text = "camelCase")
  )
  config <- list(settings = list(annotations = ann_list))
  result <- build_annotations_json(config)

  parsed <- jsonlite::fromJSON(result)
  expect_equal(nrow(parsed), 2)
  expect_equal(parsed$metricId[1], "Q1_mean")
  expect_equal(parsed$metricId[2], "Q2_pct")
  expect_equal(parsed$waveId[1], "W3")
  expect_equal(parsed$waveId[2], "W2")
})


# ==============================================================================
# Test: Supports both colour and color field names
# ==============================================================================

test_that("supports both 'colour' and 'color' field names", {
  ann_list <- list(
    list(metric_id = "Q1_mean", wave_id = "W3", text = "British", colour = "#ff0000"),
    list(metric_id = "Q2_pct", wave_id = "W2", text = "American", color = "#00ff00")
  )
  config <- list(settings = list(annotations = ann_list))
  result <- build_annotations_json(config)

  parsed <- jsonlite::fromJSON(result)
  expect_equal(parsed$colour[1], "#ff0000")
  expect_equal(parsed$colour[2], "#00ff00")
})


# ==============================================================================
# Test: Non-list/non-df input returns "[]"
# ==============================================================================

test_that("non-list/non-df annotations input returns '[]'", {
  # Numeric input
  config_num <- list(settings = list(annotations = 42))
  expect_equal(build_annotations_json(config_num), "[]")

  # Character input
  config_chr <- list(settings = list(annotations = "not valid"))
  expect_equal(build_annotations_json(config_chr), "[]")
})


# ==============================================================================
# Test: JSON parses correctly (round-trip)
# ==============================================================================

test_that("output is valid JSON that round-trips correctly", {
  ann_df <- data.frame(
    metric_id = c("Q1_mean", "Q2_pct"),
    wave_id   = c("W3", "W2"),
    segment   = c("Total", "Male"),
    text      = c("Campaign launched", "Price change"),
    colour    = c("#ff0000", "#00ff00"),
    stringsAsFactors = FALSE
  )
  config <- list(settings = list(annotations = ann_df))
  result <- build_annotations_json(config)

  # Should not error on parse
  parsed <- jsonlite::fromJSON(result)
  expect_is(parsed, "data.frame")

  # Re-serialise and re-parse should match
  re_json <- jsonlite::toJSON(parsed, auto_unbox = TRUE)
  re_parsed <- jsonlite::fromJSON(re_json)
  expect_equal(parsed, re_parsed)
})


# ==============================================================================
# Test: Single annotation data frame (1-row edge case)
# ==============================================================================

test_that("single-row data frame annotation works", {
  ann_df <- data.frame(
    metric_id = "Q1_mean",
    wave_id   = "W3",
    text      = "Solo annotation",
    stringsAsFactors = FALSE
  )
  config <- list(settings = list(annotations = ann_df))
  result <- build_annotations_json(config)

  parsed <- jsonlite::fromJSON(result)
  # fromJSON with a single-element array may return a 1-row df or named list
  if (is.data.frame(parsed)) {
    expect_equal(nrow(parsed), 1)
    expect_equal(parsed$metricId, "Q1_mean")
    expect_equal(parsed$text, "Solo annotation")
  } else {
    expect_equal(parsed$metricId, "Q1_mean")
    expect_equal(parsed$text, "Solo annotation")
  }
})


# ==============================================================================
# Test: All fields preserved correctly
# ==============================================================================

test_that("all field values are preserved correctly in JSON output", {
  ann_df <- data.frame(
    metric_id = "awareness_pct",
    wave_id   = "wave_2024Q1",
    segment   = "18-24",
    text      = "New campaign launched in Q1",
    colour    = "#e74c3c",
    stringsAsFactors = FALSE
  )
  config <- list(settings = list(annotations = ann_df))
  result <- build_annotations_json(config)

  parsed <- jsonlite::fromJSON(result)
  expect_equal(parsed$metricId, "awareness_pct")
  expect_equal(parsed$waveId, "wave_2024Q1")
  expect_equal(parsed$segment, "18-24")
  expect_equal(parsed$text, "New campaign launched in Q1")
  expect_equal(parsed$colour, "#e74c3c")
})
