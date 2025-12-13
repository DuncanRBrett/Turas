# ==============================================================================
# Tests for modules/shared/lib/config_utils.R
# ==============================================================================
# Tests for the shared configuration utilities module.
# This module provides consistent config handling across all TURAS modules.
#
# Created as part of Phase 3: Shared Config Utilities
# Updated: Now uses consolidated /modules/shared/lib/ location
# ==============================================================================

# Source required dependencies first
source("modules/shared/lib/validation_utils.R", local = TRUE)

# Source the module under test (new consolidated location)
source("modules/shared/lib/config_utils.R", local = TRUE)

# ==============================================================================
# Test: parse_settings_to_list
# ==============================================================================

test_that("parse_settings_to_list converts basic settings", {
  settings_df <- data.frame(
    Setting = c("project_name", "decimal_separator", "output_format"),
    Value = c("Test Project", ",", "xlsx"),
    stringsAsFactors = FALSE
  )

  result <- parse_settings_to_list(settings_df)

  expect_type(result, "list")
  expect_equal(result$project_name, "Test Project")
  expect_equal(result$decimal_separator, ",")
  expect_equal(result$output_format, "xlsx")
})

test_that("parse_settings_to_list converts Y/N to logical", {
  settings_df <- data.frame(
    Setting = c("show_base", "show_significance", "verbose"),
    Value = c("Y", "N", "yes"),
    stringsAsFactors = FALSE
  )

  result <- parse_settings_to_list(settings_df)

  expect_equal(result$show_base, TRUE)
  expect_equal(result$show_significance, FALSE)
  expect_equal(result$verbose, TRUE)
})

test_that("parse_settings_to_list converts numeric strings", {
  settings_df <- data.frame(
    Setting = c("decimal_places", "min_base", "max_base"),
    Value = c("2", "30", "1000"),
    stringsAsFactors = FALSE
  )

  result <- parse_settings_to_list(settings_df)

  expect_equal(result$decimal_places, 2)
  expect_equal(result$min_base, 30)
  expect_equal(result$max_base, 1000)
  expect_type(result$decimal_places, "double")
})

test_that("parse_settings_to_list accepts SettingName column", {
  # For backward compatibility
  settings_df <- data.frame(
    SettingName = c("project_name", "decimal_separator"),
    Value = c("Test", ","),
    stringsAsFactors = FALSE
  )

  result <- parse_settings_to_list(settings_df)

  expect_type(result, "list")
  expect_equal(result$project_name, "Test")
})

test_that("parse_settings_to_list detects duplicate settings", {
  settings_df <- data.frame(
    Setting = c("project_name", "decimal_separator", "project_name"),
    Value = c("Test1", ",", "Test2"),
    stringsAsFactors = FALSE
  )

  expect_error(
    parse_settings_to_list(settings_df),
    regexp = "Duplicate settings"
  )
})

test_that("parse_settings_to_list requires Setting and Value columns", {
  # Missing Value column
  settings_df <- data.frame(
    Setting = c("project_name"),
    SomethingElse = c("value"),
    stringsAsFactors = FALSE
  )

  expect_error(
    parse_settings_to_list(settings_df),
    regexp = "Value"
  )

  # Missing Setting column
  settings_df2 <- data.frame(
    SomethingElse = c("project_name"),
    Value = c("value"),
    stringsAsFactors = FALSE
  )

  expect_error(
    parse_settings_to_list(settings_df2),
    regexp = "Setting"
  )
})

# ==============================================================================
# Test: get_setting
# ==============================================================================

test_that("get_setting retrieves from Tracker-style config", {
  config <- list(
    settings = list(
      decimal_separator = ",",
      decimal_places = 2,
      show_base = TRUE
    )
  )

  expect_equal(get_setting(config, "decimal_separator"), ",")
  expect_equal(get_setting(config, "decimal_places"), 2)
  expect_equal(get_setting(config, "show_base"), TRUE)
})

test_that("get_setting retrieves from Tabs-style config", {
  config <- list(
    decimal_separator = ".",
    decimal_places = 1,
    show_base = FALSE
  )

  expect_equal(get_setting(config, "decimal_separator"), ".")
  expect_equal(get_setting(config, "decimal_places"), 1)
  expect_equal(get_setting(config, "show_base"), FALSE)
})

test_that("get_setting returns default for missing settings", {
  config <- list(settings = list(existing = "value"))

  result <- get_setting(config, "nonexistent", default = "default_value")
  expect_equal(result, "default_value")

  result_null <- get_setting(config, "nonexistent")
  expect_null(result_null)
})

# ==============================================================================
# Test: get_typed_setting
# ==============================================================================

test_that("get_typed_setting converts to logical", {
  config <- list(settings = list(show_base = "Y"))

  result <- get_typed_setting(config, "show_base", default = FALSE, type = "logical")
  expect_type(result, "logical")
})

test_that("get_typed_setting converts to numeric", {
  config <- list(settings = list(decimal_places = "2"))

  result <- get_typed_setting(config, "decimal_places", default = 1, type = "numeric")
  expect_type(result, "double")
  expect_equal(result, 2)
})

test_that("get_typed_setting returns default on conversion error", {
  config <- list(settings = list(invalid = "not_a_number"))

  expect_warning(
    result <- get_typed_setting(config, "invalid", default = 99, type = "numeric"),
    regexp = "Could not convert"
  )
  expect_equal(result, 99)
})

# ==============================================================================
# Test: validate_required_columns
# ==============================================================================

test_that("validate_required_columns passes with all columns present", {
  df <- data.frame(
    ID = 1:3,
    Name = c("A", "B", "C"),
    Value = c(10, 20, 30)
  )

  expect_silent(
    validate_required_columns(df, c("ID", "Name"), "Test data")
  )

  expect_true(
    validate_required_columns(df, c("ID", "Name", "Value"), "Test data")
  )
})

test_that("validate_required_columns fails with missing columns", {
  df <- data.frame(
    ID = 1:3,
    Name = c("A", "B", "C")
  )

  expect_error(
    validate_required_columns(df, c("ID", "Name", "Missing"), "Test data"),
    regexp = "missing required columns"
  )

  expect_error(
    validate_required_columns(df, c("ID", "Name", "Missing"), "Test data"),
    regexp = "Missing"
  )
})

test_that("validate_required_columns fails on non-dataframe", {
  not_df <- list(ID = 1:3, Name = c("A", "B", "C"))

  expect_error(
    validate_required_columns(not_df, c("ID"), "Test data"),
    regexp = "not a data frame"
  )
})

# ==============================================================================
# Test: check_duplicates
# ==============================================================================

test_that("check_duplicates passes with unique values", {
  values <- c("A", "B", "C", "D")

  expect_silent(
    check_duplicates(values, "ID", "Test data")
  )

  expect_true(
    check_duplicates(values, "ID", "Test data")
  )
})

test_that("check_duplicates fails with duplicate values", {
  values <- c("A", "B", "C", "B", "D", "A")

  expect_error(
    check_duplicates(values, "ID", "Test data"),
    regexp = "Duplicate"
  )

  expect_error(
    check_duplicates(values, "ID", "Test data"),
    regexp = "A"  # Should mention the duplicate value
  )
})

test_that("check_duplicates handles numeric values", {
  values <- c(1, 2, 3, 2, 4)

  expect_error(
    check_duplicates(values, "WaveID", "Waves"),
    regexp = "Duplicate"
  )
})

# ==============================================================================
# Test: validate_date_range
# ==============================================================================

test_that("validate_date_range passes with valid range", {
  start_date <- as.Date("2024-01-01")
  end_date <- as.Date("2024-12-31")

  expect_silent(
    validate_date_range(start_date, end_date, "Test range")
  )

  expect_true(
    validate_date_range(start_date, end_date, "Test range")
  )
})

test_that("validate_date_range passes with same start and end", {
  date <- as.Date("2024-01-01")

  expect_silent(
    validate_date_range(date, date, "Test range")
  )
})

test_that("validate_date_range fails with end before start", {
  start_date <- as.Date("2024-12-31")
  end_date <- as.Date("2024-01-01")

  expect_error(
    validate_date_range(start_date, end_date, "Test range"),
    regexp = "before start date"
  )
})

test_that("validate_date_range handles character dates", {
  expect_silent(
    validate_date_range("2024-01-01", "2024-12-31", "Test range")
  )

  expect_error(
    validate_date_range("2024-12-31", "2024-01-01", "Test range"),
    regexp = "before start date"
  )
})

test_that("validate_date_range fails with invalid dates", {
  expect_error(
    validate_date_range(NA, as.Date("2024-12-31"), "Test range"),
    regexp = "invalid or missing"
  )

  expect_error(
    validate_date_range(as.Date("2024-01-01"), NA, "Test range"),
    regexp = "invalid or missing"
  )
})

# ==============================================================================
# Test: find_turas_root
# ==============================================================================

test_that("find_turas_root returns a valid path", {
  # This test verifies that find_turas_root can locate Turas
  result <- find_turas_root()

  expect_type(result, "character")
  expect_true(nzchar(result))
  # The path should exist
  expect_true(dir.exists(result))
})

test_that("find_turas_root finds correct markers", {
  result <- find_turas_root()

  # Should contain launch_turas.R, turas.R, or modules/shared/
  has_launch <- file.exists(file.path(result, "launch_turas.R"))
  has_turas_r <- file.exists(file.path(result, "turas.R"))
  has_modules_shared <- dir.exists(file.path(result, "modules", "shared"))

  expect_true(has_launch || has_turas_r || has_modules_shared)
})

test_that("find_turas_root caches result", {
  # Clear cache first
  if (exists("TURAS_ROOT", envir = .GlobalEnv)) {
    rm("TURAS_ROOT", envir = .GlobalEnv)
  }

  # First call should set cache
  result1 <- find_turas_root()
  expect_true(exists("TURAS_ROOT", envir = .GlobalEnv))

  # Second call should return cached value
  result2 <- find_turas_root()
  expect_equal(result1, result2)
})

cat("\n✓ Shared config utilities tests completed\n")
cat("  All config functions validated\n")
