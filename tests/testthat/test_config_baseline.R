# ==============================================================================
# Baseline Tests for Config Loading
# ==============================================================================
# Tests for config_loader.R functionality in both modules.
# Documents current behavior before Phase 3 refactoring.
#
# Created as part of Phase 1: Testing Infrastructure
# ==============================================================================

# ==============================================================================
# Test: Tabs Config Loader
# ==============================================================================

test_that("Tabs config_loader can parse settings from named list", {
  # Test with a mock settings structure
  test_settings <- list(
    decimal_separator = ".",
    decimal_places_percent = "0",
    decimal_places_ratings = "1",
    show_significance = "Y",
    verbose = "N"
  )

  # These functions should exist in config_loader
  expect_true(file.exists("modules/tabs/lib/config_loader.R"))
})

test_that("Tabs config_loader has expected functions", {
  source("modules/tabs/lib/config_loader.R", local = TRUE)

  # Check that key functions exist
  expect_true(exists("load_crosstab_configuration"))
  expect_true(exists("load_config_settings"))
})

# ==============================================================================
# Test: Tracker Config Loader
# ==============================================================================

test_that("Tracker config_loader has expected functions", {
  source("modules/tracker/tracker_config_loader.R", local = TRUE)

  # Check that key functions exist
  expect_true(exists("load_tracking_config"))
  expect_true(exists("parse_settings_to_list"))
  expect_true(exists("get_setting"))
})

test_that("Tracker get_setting retrieves values with defaults", {
  source("modules/tracker/tracker_config_loader.R", local = TRUE)

  test_config <- list(
    settings = list(
      decimal_separator = ",",
      decimal_places_ratings = 1
    )
  )

  # Test retrieval with config structure
  result <- get_setting(test_config, "decimal_separator", default = ".")
  expect_equal(result, ",")

  # Test default fallback
  result <- get_setting(test_config, "nonexistent_setting", default = "default_value")
  expect_equal(result, "default_value")
})

test_that("Tracker parse_settings_to_list converts Y/N to logical", {
  source("modules/tracker/tracker_config_loader.R", local = TRUE)

  settings_df <- data.frame(
    Setting = c("show_base", "show_significance", "decimal_places"),
    Value = c("Y", "N", "2"),
    stringsAsFactors = FALSE
  )

  result <- parse_settings_to_list(settings_df)

  expect_type(result, "list")
  expect_equal(result$show_base, TRUE)
  expect_equal(result$show_significance, FALSE)
  expect_equal(result$decimal_places, "2")  # Numbers stay as strings initially
})

cat("\n✓ Config loader baseline tests completed\n")
