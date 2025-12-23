# ==============================================================================
# TURAS REGRESSION TEST: TRACKER DASHBOARD MODULE
# ==============================================================================
# Tests for the new dashboard and significance matrix reports
# Added: 2025-12-11 (Tracker v2.2)
# ==============================================================================

library(testthat)

# Set working directory to project root if needed
if (basename(getwd()) == "regression") {
  setwd("../..")
} else if (basename(getwd()) == "tests") {
  setwd("..")
}

test_that("Tracker Dashboard: Helper functions work correctly", {
  # Load dashboard module (paths relative to project root)
  suppressMessages({
    source("modules/tracker/lib/formatting_utils.R")
    source("modules/tracker/lib/tracker_output.R")
    source("modules/tracker/lib/tracker_dashboard_reports.R")
  })

  # Test sig_to_arrow function
  expect_equal(sig_to_arrow(1), "\u2191")    # up arrow
  expect_equal(sig_to_arrow(-1), "\u2193")   # down arrow
  expect_equal(sig_to_arrow(0), "\u2192")    # right arrow
  expect_equal(sig_to_arrow(NA), "\u2014")   # em-dash

  # Test determine_trend_status function
  styles <- list(
    status_alert = "alert",
    status_watch = "watch",
    status_good = "good",
    status_stable = "stable"
  )

  # Alert: baseline significantly down
  status <- determine_trend_status(NA, -1, styles)
  expect_equal(status$label, "Alert")
  expect_equal(status$style, "alert")

  # Watch: recent decline
  status <- determine_trend_status(-1, 0, styles)
  expect_equal(status$label, "Watch")
  expect_equal(status$style, "watch")

  # Good: baseline significantly up
  status <- determine_trend_status(NA, 1, styles)
  expect_equal(status$label, "Good")
  expect_equal(status$style, "good")

  # Stable: no significant change
  status <- determine_trend_status(0, 0, styles)
  expect_equal(status$label, "Stable")
  expect_equal(status$style, "stable")
})

test_that("Tracker Dashboard: Main export functions exist", {
  # Load dashboard module (paths relative to project root)
  suppressMessages({
    source("modules/tracker/lib/formatting_utils.R")
    source("modules/tracker/lib/tracker_output.R")
    source("modules/tracker/lib/tracker_dashboard_reports.R")
  })

  # Check that new export functions exist
  expect_true(exists("write_dashboard_output"))
  expect_true(exists("write_sig_matrix_output"))

  # Check that they are functions
  expect_true(is.function(write_dashboard_output))
  expect_true(is.function(write_sig_matrix_output))
})

test_that("Tracker Dashboard: Format metric type display works", {
  # Load dashboard module (paths relative to project root)
  suppressMessages({
    source("modules/tracker/lib/formatting_utils.R")
    source("modules/tracker/lib/tracker_output.R")
    source("modules/tracker/lib/tracker_dashboard_reports.R")
  })

  # Test format_metric_type_display if it exists
  if (exists("format_metric_type_display")) {
    expect_type(format_metric_type_display("Mean"), "character")
    expect_type(format_metric_type_display("Percent"), "character")
    expect_type(format_metric_type_display("Top2Box"), "character")
  }
})

test_that("Tracker Dashboard: Significance style selection works", {
  # Load dashboard module (paths relative to project root)
  suppressMessages({
    source("modules/tracker/lib/formatting_utils.R")
    source("modules/tracker/lib/tracker_output.R")
    source("modules/tracker/lib/tracker_dashboard_reports.R")
  })

  # Create mock styles
  styles <- list(
    sig_up = "green",
    sig_down = "red",
    sig_none = "gray"
  )

  # Test get_sig_style function
  expect_equal(get_sig_style(1, styles), "green")
  expect_equal(get_sig_style(-1, styles), "red")
  expect_equal(get_sig_style(0, styles), "gray")
  expect_equal(get_sig_style(NA, styles), "gray")
})

# Note: Full end-to-end testing of dashboard output generation would require:
# 1. Mock trend_results data structure
# 2. Mock config object
# 3. Mock wave_data
# 4. Temporary output file creation
# These are better suited for integration tests rather than regression tests.

cat("\n✓ Tracker Dashboard regression tests completed\n")
cat("  All dashboard helper functions validated\n")
cat("  Export functions exist and are callable\n")
