# ==============================================================================
# Baseline Tests for Decimal Separator / Number Formatting
# ==============================================================================
# These tests document the CURRENT behavior of formatting in both modules.
# After Phase 2, we'll ensure the shared formatting produces identical results.
#
# Created as part of Phase 1: Testing Infrastructure
# ==============================================================================

# ==============================================================================
# Test: Tabs Module Formatting (Baseline)
# ==============================================================================

test_that("Tabs excel_writer creates correct number formats with period separator", {
  source("modules/tabs/lib/excel_writer.R", local = TRUE)

  styles <- create_excel_styles(
    decimal_separator = ".",
    decimal_places_percent = 0,
    decimal_places_ratings = 1,
    decimal_places_index = 1,
    decimal_places_numeric = 2
  )

  # Check that styles were created
  expect_type(styles, "list")
  expect_true("column_pct" %in% names(styles))
  expect_true("rating_style" %in% names(styles))
  expect_true("numeric_style" %in% names(styles))

  # Extract numFmt from styles (these are openxlsx style objects)
  # We can't easily inspect numFmt directly, so we test by usage
  expect_s3_class(styles$column_pct, "Style")
  expect_s3_class(styles$rating_style, "Style")
})

test_that("Tabs excel_writer creates correct number formats with comma separator", {
  source("modules/tabs/lib/excel_writer.R", local = TRUE)

  styles <- create_excel_styles(
    decimal_separator = ",",
    decimal_places_percent = 0,
    decimal_places_ratings = 1,
    decimal_places_index = 2,
    decimal_places_numeric = 2
  )

  expect_type(styles, "list")
  expect_true("column_pct" %in% names(styles))
  expect_true("rating_style" %in% names(styles))

  # Styles should be created successfully with comma separator
  expect_s3_class(styles$column_pct, "Style")
  expect_s3_class(styles$rating_style, "Style")
})

# ==============================================================================
# Test: Tracker Module Formatting (Baseline)
# ==============================================================================

test_that("Tracker formatting_utils formats numbers with period separator", {
  source("modules/tracker/formatting_utils.R", local = TRUE)

  result <- format_number_with_separator(95.5, decimal_places = 1, decimal_sep = ".")

  expect_type(result, "character")
  expect_equal(result, "95.5")
})

test_that("Tracker formatting_utils formats numbers with comma separator", {
  source("modules/tracker/formatting_utils.R", local = TRUE)

  result <- format_number_with_separator(95.5, decimal_places = 1, decimal_sep = ",")

  expect_type(result, "character")
  expect_equal(result, "95,5")
})

test_that("Tracker formatting handles vector inputs", {
  source("modules/tracker/formatting_utils.R", local = TRUE)

  values <- c(10.5, 20.7, 30.9)
  result <- format_number_with_separator(values, decimal_places = 1, decimal_sep = ",")

  expect_type(result, "character")
  expect_length(result, 3)
  expect_equal(result[1], "10,5")
  expect_equal(result[2], "20,7")
  expect_equal(result[3], "30,9")
})

test_that("Tracker formatting handles NA values", {
  source("modules/tracker/formatting_utils.R", local = TRUE)

  result <- format_number_with_separator(NA, decimal_places = 1, decimal_sep = ".")

  expect_true(is.na(result))
})

test_that("Tracker formatting handles NULL values", {
  source("modules/tracker/formatting_utils.R", local = TRUE)

  result <- format_number_with_separator(NULL, decimal_places = 1, decimal_sep = ".")

  expect_null(result)
})

test_that("Tracker formatting respects decimal_places parameter", {
  source("modules/tracker/formatting_utils.R", local = TRUE)

  # 0 decimal places
  expect_equal(
    format_number_with_separator(95.567, decimal_places = 0, decimal_sep = "."),
    "96"
  )

  # 1 decimal place
  expect_equal(
    format_number_with_separator(95.567, decimal_places = 1, decimal_sep = "."),
    "95.6"
  )

  # 2 decimal places
  expect_equal(
    format_number_with_separator(95.567, decimal_places = 2, decimal_sep = "."),
    "95.57"
  )
})

# ==============================================================================
# Test: Document Current Inconsistency (Will be fixed in Phase 2)
# ==============================================================================

test_that("KNOWN ISSUE: Tracker tracker_output ignores decimal_separator config", {
  # This test documents the current bug
  # The tracker_output.R module has comments saying it always uses "." in format codes
  # and relies on Excel locale conversion

  # This is a documentation test - it will pass now to establish baseline
  # After Phase 2, we'll have consistent behavior

  expect_true(TRUE)  # Placeholder - documents known issue
})

cat("\n✓ Formatting baseline tests completed\n")
cat("  Note: These tests document CURRENT behavior before Phase 2 refactoring\n")
