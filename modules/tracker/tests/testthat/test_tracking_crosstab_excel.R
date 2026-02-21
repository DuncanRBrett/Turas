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

# Source shared formatting utils (for create_excel_number_format)
shared_formatting <- file.path(turas_root, "modules", "shared", "lib", "formatting_utils.R")
if (file.exists(shared_formatting)) source(shared_formatting)

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
            values = list(W1 = 52, W2 = 55, W3 = 58),
            n = list(W1 = 500L, W2 = 480L, W3 = 510L),
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

  sheet_names <- openxlsx::getSheetNames(output_path)

  expect_true("Summary" %in% sheet_names)
  expect_true("Summary Data" %in% sheet_names)
  expect_true("Tracking Crosstab" %in% sheet_names)

  unlink(output_path)
})

test_that("Tracking Crosstab sheet has traditional crosstab structure", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".xlsx")

  write_tracking_crosstab_output(crosstab_data, config, output_path)

  data <- openxlsx::read.xlsx(output_path, sheet = "Tracking Crosstab",
                               colNames = FALSE, skipEmptyRows = FALSE)

  # Traditional layout with 3-row header:
  # Row 1: Banner group (Total)
  # Row 2: Segment option (Question, blank, Total)
  # Row 3: Wave labels (blank, blank, Jan 2024, Apr 2024, Jul 2024)
  # Row 4: Section header "Brand Health"
  # Row 5: Question header "How satisfied?" (merged)
  # Row 6: Base (n=) row
  # Row 7: Top 2 Box % (percentage first in traditional order)
  # Row 8: vs Prev
  # Row 9: vs Base
  # Row 10: Mean
  # Row 11: vs Prev
  # Row 12: vs Base
  # Row 13: (blank separator)
  # Row 14: Question header "Recommend?" (merged)
  # Row 15: Base (n=)
  # Row 16: NPS
  # Row 17: vs Prev
  # Row 18: vs Base

  expect_true(nrow(data) >= 18)

  # Check question header is in row 5 col 1
  expect_equal(data[5, 1], "How satisfied?")

  # Check base row label in col 2
  expect_equal(data[6, 2], "Base (n=)")

  unlink(output_path)
})


# ==============================================================================
# TESTS: Formatting helpers
# ==============================================================================

test_that("format_change_value formats correctly", {
  # Means: display with 2 decimals
  expect_equal(format_change_value(0.3, "mean"), "+0.3")
  expect_equal(format_change_value(-0.5, "mean"), "-0.5")
  # Proportions: values on 0-100 scale, change is percentage points
  expect_equal(format_change_value(3, "top2_box"), "+3pp")
  expect_equal(format_change_value(-5, "promoters_pct"), "-5pp")
  # NPS: integer display
  expect_equal(format_change_value(6, "nps_score"), "+6")
  expect_equal(format_change_value(-3, "nps"), "-3")
})

test_that("format_sig_arrow returns correct arrows", {
  expect_equal(format_sig_arrow(0.3, TRUE), " \u2191")   # up
  expect_equal(format_sig_arrow(-0.3, TRUE), " \u2193")  # down
  expect_equal(format_sig_arrow(0.3, FALSE), " \u2192")  # right
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

test_that("get_metric_suffix returns correct labels", {
  expect_equal(get_metric_suffix("mean"), "Mean")
  expect_equal(get_metric_suffix("top2_box"), "Top 2 Box %")
  expect_equal(get_metric_suffix("nps_score"), "NPS")
  expect_equal(get_metric_suffix("box_agree"), "% Agree")
  expect_equal(get_metric_suffix("category_yes"), "% Yes")
})

test_that("format_change_with_sig adds * for significant", {
  expect_equal(format_change_with_sig(3, TRUE, "top2_box"), "+3pp *")
  expect_equal(format_change_with_sig(3, FALSE, "top2_box"), "+3pp")
  expect_equal(format_change_with_sig(0.3, TRUE, "mean"), "+0.3 *")
  expect_equal(format_change_with_sig(NA, TRUE, "mean"), "")
  expect_equal(format_change_with_sig(NULL, TRUE, "mean"), "")
})


# ==============================================================================
# TESTS: Question grouping and metric ordering
# ==============================================================================

test_that("group_metrics_by_question groups correctly", {
  crosstab_data <- create_test_crosstab_data()

  groups <- group_metrics_by_question(crosstab_data$metrics)

  # Q_SAT has 2 metrics (mean + top2_box), Q_NPS has 1
  expect_equal(length(groups), 2)
  expect_equal(length(groups[[1]]), 2)  # Q_SAT: mean + top2_box
  expect_equal(length(groups[[2]]), 1)  # Q_NPS: nps_score
  expect_equal(groups[[1]][[1]]$question_code, "Q_SAT")
  expect_equal(groups[[2]][[1]]$question_code, "Q_NPS")
})

test_that("sort_metrics_traditional puts percentages before means", {
  crosstab_data <- create_test_crosstab_data()
  groups <- group_metrics_by_question(crosstab_data$metrics)

  # Q_SAT group: mean (sort_order=1) and top2_box (sort_order=1.01)
  sorted <- sort_metrics_traditional(groups[[1]])

  # top2_box (percentage) should come before mean (rating)
  expect_equal(sorted[[1]]$metric_name, "top2_box")
  expect_equal(sorted[[2]]$metric_name, "mean")
})


# ==============================================================================
# TESTS: Decimal places from config
# ==============================================================================

test_that("create_crosstab_styles uses config decimal settings", {
  config <- list(settings = list(
    decimal_places_ratings = 2,
    decimal_places_percentages = 0,
    decimal_places_nps = 1
  ))

  styles <- create_crosstab_styles(config)

  # Styles should exist and be style objects
  expect_true(!is.null(styles$value_rating))
  expect_true(!is.null(styles$value_percent))
  expect_true(!is.null(styles$value_nps))
})

test_that("create_crosstab_styles works without config", {
  styles <- create_crosstab_styles()

  expect_true(!is.null(styles$value_rating))
  expect_true(!is.null(styles$value_percent))
  expect_true(!is.null(styles$value_nps))
})


# ==============================================================================
# TESTS: Summary Data sheet (flat filterable table)
# ==============================================================================

test_that("Summary Data sheet has correct structure", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".xlsx")

  write_tracking_crosstab_output(crosstab_data, config, output_path)

  data <- openxlsx::read.xlsx(output_path, sheet = "Summary Data",
                               colNames = TRUE, skipEmptyRows = FALSE)

  # Headers: Section, Question, Metric, Jan 2024, Apr 2024, Jul 2024
  expect_equal(names(data)[1], "Section")
  expect_equal(names(data)[2], "Question")
  expect_equal(names(data)[3], "Metric")

  # First data row is Base (n=)
  expect_equal(data[1, "Metric"], "Base (n=)")

  # Then metrics: top2_box first (percentage), then mean (traditional order), then NPS
  # Q_SAT group: top2_box, mean; Q_NPS group: nps_score
  expect_equal(data[2, "Metric"], "Top 2 Box %")
  expect_equal(data[3, "Metric"], "Mean")
  expect_equal(data[4, "Metric"], "NPS")

  # Section repeated on every data row for filtering
  expect_equal(data[2, "Section"], "Brand Health")
  expect_equal(data[3, "Section"], "Brand Health")
  expect_equal(data[4, "Section"], "Brand Health")

  # Question repeated on every data row for filtering
  expect_equal(data[2, "Question"], "How satisfied?")
  expect_equal(data[3, "Question"], "How satisfied?")
  expect_equal(data[4, "Question"], "Recommend?")

  # Total rows: 1 base + 3 metrics = 4
  expect_equal(nrow(data), 4)

  unlink(output_path)
})

test_that("Summary Data sheet has correct values", {
  crosstab_data <- create_test_crosstab_data()
  config <- create_test_config()
  output_path <- tempfile(fileext = ".xlsx")

  write_tracking_crosstab_output(crosstab_data, config, output_path)

  data <- openxlsx::read.xlsx(output_path, sheet = "Summary Data",
                               colNames = TRUE, skipEmptyRows = FALSE)

  # Base row: n values
  expect_equal(data[1, 4], 500)  # W1 base
  expect_equal(data[1, 5], 480)  # W2 base
  expect_equal(data[1, 6], 510)  # W3 base

  # Top 2 Box row (Q_SAT): values on 0-100 scale
  expect_equal(data[2, 4], 52)   # W1
  expect_equal(data[2, 5], 55)   # W2
  expect_equal(data[2, 6], 58)   # W3

  # Mean row (Q_SAT)
  expect_equal(data[3, 4], 8.2)  # W1
  expect_equal(data[3, 5], 8.5)  # W2
  expect_equal(data[3, 6], 8.7)  # W3

  # NPS row (Q_NPS)
  expect_equal(data[4, 4], 32)   # W1
  expect_equal(data[4, 5], 38)   # W2
  expect_equal(data[4, 6], 41)   # W3

  unlink(output_path)
})

test_that("Summary Data handles multiple sections", {
  crosstab_data <- create_test_crosstab_data()
  # Change NPS to a different section
  crosstab_data$metrics[[3]]$section <- "Customer Experience"
  crosstab_data$sections <- c("Brand Health", "Customer Experience")

  config <- create_test_config()
  output_path <- tempfile(fileext = ".xlsx")

  write_tracking_crosstab_output(crosstab_data, config, output_path)

  data <- openxlsx::read.xlsx(output_path, sheet = "Summary Data",
                               colNames = TRUE, skipEmptyRows = FALSE)

  # Brand Health metrics first, then Customer Experience
  sections <- data[2:nrow(data), "Section"]
  expect_true(all(sections[1:2] == "Brand Health"))
  expect_equal(sections[3], "Customer Experience")

  unlink(output_path)
})

test_that("Summary Data handles multiple segments with correct column headers", {
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

  write_tracking_crosstab_output(crosstab_data, config, output_path)

  data <- openxlsx::read.xlsx(output_path, sheet = "Summary Data",
                               colNames = TRUE, skipEmptyRows = FALSE)

  # 3 fixed cols + (3 waves × 2 segments) = 9 columns
  expect_equal(ncol(data), 9)

  # Column headers for multi-segment: "Segment - Wave"
  expect_true(grepl("Total", names(data)[4]))
  expect_true(grepl("Cape.Town", names(data)[7]))

  unlink(output_path)
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

  # Read and verify data columns: 2 label cols + (3 waves * 2 segments) = 8 columns
  data <- openxlsx::read.xlsx(output_path, sheet = "Tracking Crosstab",
                               colNames = FALSE, skipEmptyRows = FALSE)
  expect_true(ncol(data) >= 8)

  unlink(output_path)
})
