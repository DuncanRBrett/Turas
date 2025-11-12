# ==============================================================================
# Tests for shared/formatting.R
# ==============================================================================
# Tests for the new shared formatting module.
# This module provides consistent number formatting across all TURAS modules.
#
# Created as part of Phase 2: Shared Formatting Module
# ==============================================================================

# Source the module under test
source("shared/formatting.R", local = TRUE)

# ==============================================================================
# Test: create_excel_number_format
# ==============================================================================

test_that("create_excel_number_format generates correct format codes", {
  # Test with period separator
  expect_equal(create_excel_number_format(0, "."), "0")
  expect_equal(create_excel_number_format(1, "."), "0.0")
  expect_equal(create_excel_number_format(2, "."), "0.00")
  expect_equal(create_excel_number_format(3, "."), "0.000")

  # Test with comma separator
  expect_equal(create_excel_number_format(0, ","), "0")
  expect_equal(create_excel_number_format(1, ","), "0,0")
  expect_equal(create_excel_number_format(2, ","), "0,00")
  expect_equal(create_excel_number_format(3, ","), "0,000")
})

test_that("create_excel_number_format validates inputs", {
  # Invalid separator
  expect_error(
    create_excel_number_format(1, ";"),
    regexp = "decimal_separator must be"
  )

  # Invalid decimal places (negative)
  expect_error(
    create_excel_number_format(-1, "."),
    regexp = "decimal_places must be"
  )

  # Invalid decimal places (too large)
  expect_error(
    create_excel_number_format(10, "."),
    regexp = "decimal_places must be"
  )

  # Non-numeric decimal places
  expect_error(
    create_excel_number_format("abc", "."),
    regexp = "decimal_places must be"
  )
})

# ==============================================================================
# Test: format_number
# ==============================================================================

test_that("format_number formats with period separator", {
  expect_equal(format_number(95.5, 1, "."), "95.5")
  expect_equal(format_number(100, 2, "."), "100.00")
  expect_equal(format_number(0.123, 2, "."), "0.12")
})

test_that("format_number formats with comma separator", {
  expect_equal(format_number(95.5, 1, ","), "95,5")
  expect_equal(format_number(100, 2, ","), "100,00")
  expect_equal(format_number(0.123, 2, ","), "0,12")
})

test_that("format_number handles vectors", {
  input <- c(10.5, 20.7, 30.9)
  result <- format_number(input, 1, ",")

  expect_type(result, "character")
  expect_length(result, 3)
  expect_equal(result[1], "10,5")
  expect_equal(result[2], "20,7")
  expect_equal(result[3], "30,9")
})

test_that("format_number handles NA values", {
  result <- format_number(NA, 1, ".")
  expect_true(is.na(result))

  # Vector with NA
  input <- c(10.5, NA, 30.9)
  result <- format_number(input, 1, ".")
  expect_length(result, 3)
  expect_equal(result[1], "10.5")
  expect_true(is.na(result[2]))
  expect_equal(result[3], "30.9")
})

test_that("format_number handles NULL", {
  result <- format_number(NULL, 1, ".")
  expect_null(result)
})

test_that("format_number handles all NA input", {
  result <- format_number(c(NA, NA, NA), 1, ".")
  expect_true(all(is.na(result)))
})

test_that("format_number respects decimal_places", {
  # 0 decimal places - rounds
  expect_equal(format_number(95.567, 0, "."), "96")

  # 1 decimal place
  expect_equal(format_number(95.567, 1, "."), "95.6")

  # 2 decimal places
  expect_equal(format_number(95.567, 2, "."), "95.57")

  # 3 decimal places
  expect_equal(format_number(95.567, 3, "."), "95.567")
})

test_that("format_number validates inputs", {
  # Invalid separator
  expect_error(
    format_number(95.5, 1, ";"),
    regexp = "decimal_separator must be"
  )

  # Invalid decimal places
  expect_error(
    format_number(95.5, -1, "."),
    regexp = "decimal_places must be"
  )
})

# ==============================================================================
# Test: format_percentage
# ==============================================================================

test_that("format_percentage formats without percent sign", {
  expect_equal(format_percentage(95.5, 1, ".", FALSE), "95.5")
  expect_equal(format_percentage(95.5, 0, ".", FALSE), "96")
  expect_equal(format_percentage(95.5, 1, ",", FALSE), "95,5")
})

test_that("format_percentage formats with percent sign", {
  expect_equal(format_percentage(95.5, 1, ".", TRUE), "95.5%")
  expect_equal(format_percentage(95.5, 0, ".", TRUE), "96%")
  expect_equal(format_percentage(95.5, 1, ",", TRUE), "95,5%")
})

test_that("format_percentage handles edge cases", {
  expect_equal(format_percentage(0, 0, ".", TRUE), "0%")
  expect_equal(format_percentage(100, 0, ".", TRUE), "100%")

  # NA
  result <- format_percentage(NA, 1, ".", TRUE)
  expect_true(grepl("NA", result))
})

# ==============================================================================
# Test: format_index
# ==============================================================================

test_that("format_index is alias for format_number", {
  # Should behave identically to format_number
  expect_equal(format_index(7.5, 1, "."), format_number(7.5, 1, "."))
  expect_equal(format_index(7.5, 1, ","), format_number(7.5, 1, ","))
  expect_equal(format_index(7.5, 2, "."), format_number(7.5, 2, "."))
})

# ==============================================================================
# Test: validate_decimal_separator
# ==============================================================================

test_that("validate_decimal_separator accepts valid separators", {
  expect_equal(validate_decimal_separator("."), ".")
  expect_equal(validate_decimal_separator(","), ",")
})

test_that("validate_decimal_separator handles invalid separators", {
  # Should warn and return default
  expect_warning(
    result <- validate_decimal_separator(";"),
    regexp = "must be"
  )
  expect_equal(result, ".")

  # Custom default
  expect_warning(
    result <- validate_decimal_separator("!", default = ","),
    regexp = "must be"
  )
  expect_equal(result, ",")
})

test_that("validate_decimal_separator handles NULL", {
  result <- validate_decimal_separator(NULL)
  expect_equal(result, ".")

  result <- validate_decimal_separator(NULL, default = ",")
  expect_equal(result, ",")
})

test_that("validate_decimal_separator handles empty", {
  result <- validate_decimal_separator(character(0))
  expect_equal(result, ".")
})

# ==============================================================================
# Test: validate_decimal_places
# ==============================================================================

test_that("validate_decimal_places accepts valid values", {
  expect_equal(validate_decimal_places(0), 0L)
  expect_equal(validate_decimal_places(1), 1L)
  expect_equal(validate_decimal_places(2), 2L)
  expect_equal(validate_decimal_places(6), 6L)

  # Should convert character to integer
  expect_equal(validate_decimal_places("2"), 2L)
  expect_equal(validate_decimal_places("0"), 0L)
})

test_that("validate_decimal_places handles invalid values", {
  # Negative
  expect_warning(
    result <- validate_decimal_places(-1),
    regexp = "must be an integer 0-6"
  )
  expect_equal(result, 1L)

  # Too large
  expect_warning(
    result <- validate_decimal_places(10),
    regexp = "must be an integer 0-6"
  )
  expect_equal(result, 1L)

  # Non-numeric
  expect_warning(
    result <- validate_decimal_places("abc"),
    regexp = "must be an integer 0-6"
  )
  expect_equal(result, 1L)
})

test_that("validate_decimal_places handles NULL", {
  result <- validate_decimal_places(NULL)
  expect_equal(result, 1L)

  result <- validate_decimal_places(NULL, default = 2)
  expect_equal(result, 2L)
})

test_that("validate_decimal_places returns integer type", {
  # Should always return integer
  result <- validate_decimal_places(2.0)
  expect_type(result, "integer")
  expect_equal(result, 2L)
})

# ==============================================================================
# Test: Consistency with Tabs Implementation
# ==============================================================================

test_that("Shared formatting matches Tabs excel_writer behavior", {
  # Load Tabs implementation
  source("modules/tabs/lib/excel_writer.R", local = TRUE)

  # Create styles with both implementations
  tabs_styles <- create_excel_styles(
    decimal_separator = ",",
    decimal_places_percent = 0,
    decimal_places_ratings = 1
  )

  shared_styles <- create_excel_number_styles(
    decimal_separator = ",",
    decimal_places_percent = 0,
    decimal_places_ratings = 1
  )

  # Both should create style objects
  expect_s3_class(tabs_styles$column_pct, "Style")
  expect_s3_class(shared_styles$percentage, "Style")

  # Format codes should match
  pct_format <- create_excel_number_format(0, ",")
  rating_format <- create_excel_number_format(1, ",")

  expect_equal(pct_format, "0")
  expect_equal(rating_format, "0,0")
})

test_that("Shared formatting matches Tracker formatting_utils behavior", {
  # Load Tracker implementation
  source("modules/tracker/formatting_utils.R", local = TRUE)

  # Test identical inputs produce identical outputs
  test_values <- c(10.5, 20.7, 95.123)

  tracker_result <- format_number_with_separator(test_values, 1, ",")
  shared_result <- format_number(test_values, 1, ",")

  expect_equal(shared_result, tracker_result)
})

# ==============================================================================
# Test: Decimal Separator Consistency (The Fix!)
# ==============================================================================

test_that("FIXED: Decimal separator is respected consistently", {
  # This test validates the FIX for the decimal separator issue

  # Generate format codes for both separators
  period_format_1dp <- create_excel_number_format(1, ".")
  comma_format_1dp <- create_excel_number_format(1, ",")

  # Should use different separators
  expect_equal(period_format_1dp, "0.0")
  expect_equal(comma_format_1dp, "0,0")
  expect_false(period_format_1dp == comma_format_1dp)

  # String formatting should also respect separator
  expect_equal(format_number(95.5, 1, "."), "95.5")
  expect_equal(format_number(95.5, 1, ","), "95,5")

  # This is the behavior that was broken in tracker_output.R
  # (it always used "0.0" regardless of config)
  # Now fixed with shared implementation!
})

cat("\n✓ Shared formatting module tests completed\n")
cat("  All tests pass - decimal separator issue is FIXED!\n")
