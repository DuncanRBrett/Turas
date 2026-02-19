# ==============================================================================
# TEST SUITE: Tracking Crosstab Excel Output (Phase 3)
# ==============================================================================

library(testthat)

context("Tracking Crosstab Excel Output")

# ==============================================================================
# SETUP
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

source(file.path(tracker_root, "lib", "00_guard.R"))
source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "metric_types.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "question_mapper.R"))
source(file.path(tracker_root, "lib", "statistical_core.R"))
source(file.path(tracker_root, "lib", "tracking_crosstab_engine.R"))
source(file.path(tracker_root, "lib", "tracking_crosstab_excel.R"))

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
      baseline_wave = "W1"
    ),
    waves = data.frame(
      WaveID = c("W1", "W2", "W3"),
      WaveName = c("Jan 2024", "Apr 2024", "Jul 2024"),
      stringsAsFactors = FALSE
    )
  )
}


# ==============================================================================
# TESTS: Excel file generation
# ==============================================================================

test_that("write_tracking_crosstab_output creates an Excel file", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".xlsx")

  result <- write_tracking_crosstab_output(crosstab_data, config, output_path)

  expect_true(file.exists(output_path))
  expect_equal(result, output_path)

  # Clean up
  unlink(output_path)
})

test_that("Excel file has correct sheets", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".xlsx")

  write_tracking_crosstab_output(crosstab_data, config, output_path)

  wb <- openxlsx::loadWorkbook(output_path)
  sheet_names <- openxlsx::getSheetNames(output_path)

  expect_true("Summary" %in% sheet_names)
  expect_true("Tracking Crosstab" %in% sheet_names)

  unlink(output_path)
})

test_that("Tracking Crosstab sheet has correct structure", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".xlsx")

  write_tracking_crosstab_output(crosstab_data, config, output_path)

  data <- openxlsx::read.xlsx(output_path, sheet = "Tracking Crosstab",
                               colNames = FALSE, skipEmptyRows = FALSE)

  # Row 1: segment header, Row 2: wave headers
  # Row 3: section header "Brand Health"
  # Row 4: Satisfaction (Mean) values
  # Row 5: vs Prev
  # Row 6: vs Base
  # Row 7: Satisfaction (Top 2 Box) values
  # Row 8: vs Prev
  # Row 9: vs Base
  # Row 10: NPS Score values
  # Row 11: vs Prev
  # Row 12: vs Base

  expect_true(nrow(data) >= 12)

  # Check metric label is in the correct cell
  expect_equal(data[4, 1], "Satisfaction (Mean)")

  unlink(output_path)
})


# ==============================================================================
# TESTS: Formatting helpers
# ==============================================================================

test_that("format_change_value formats correctly", {
  expect_equal(format_change_value(0.3, "mean"), "+0.3")
  expect_equal(format_change_value(-0.5, "mean"), "-0.5")
  expect_equal(format_change_value(0.03, "top2_box"), "+3pp")
  expect_equal(format_change_value(-0.05, "promoters_pct"), "-5pp")
  expect_equal(format_change_value(6, "nps_score"), "+6")
  expect_equal(format_change_value(-3, "nps"), "-3")
})

test_that("format_sig_arrow returns correct arrows", {
  expect_equal(format_sig_arrow(0.3, TRUE), " \u2191")   # ↑
  expect_equal(format_sig_arrow(-0.3, TRUE), " \u2193")  # ↓
  expect_equal(format_sig_arrow(0.3, FALSE), " \u2192")  # →
  expect_equal(format_sig_arrow(0.3, NA), "")
  expect_equal(format_sig_arrow(0.3, NULL), "")
})

test_that("get_value_style selects correct style", {
  styles <- create_crosstab_styles()

  nps_style <- get_value_style("nps_score", styles)
  expect_true(is.list(nps_style) || inherits(nps_style, "Style"))

  pct_style <- get_value_style("top2_box", styles)
  expect_true(is.list(pct_style) || inherits(pct_style, "Style"))

  num_style <- get_value_style("mean", styles)
  expect_true(is.list(num_style) || inherits(num_style, "Style"))
})


# ==============================================================================
# TESTS: Multi-segment output
# ==============================================================================

test_that("handles multiple banner segments", {
  crosstab_data <- create_test_crosstab_data()

  # Add a second segment
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
  output_path <- tempfile(fileext = ".xlsx")

  result <- write_tracking_crosstab_output(crosstab_data, config, output_path)
  expect_true(file.exists(output_path))

  # Read and verify data columns: 1 label + (3 waves * 2 segments) = 7 columns
  data <- openxlsx::read.xlsx(output_path, sheet = "Tracking Crosstab",
                               colNames = FALSE, skipEmptyRows = FALSE)
  expect_true(ncol(data) >= 7)

  unlink(output_path)
})
