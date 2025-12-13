# ==============================================================================
# Tests for modules/shared/lib/formatting_utils.R
# ==============================================================================
# Tests for the shared formatting module.
# This module provides consistent number formatting across all TURAS modules.
#
# Created as part of Phase 2: Shared Formatting Module
# Updated: Now uses consolidated /modules/shared/lib/ location
# ==============================================================================

# Source the module under test (new consolidated location)
source("modules/shared/lib/formatting_utils.R", local = TRUE)

# ==============================================================================
# Test: create_excel_number_format
# ==============================================================================

test_that("create_excel_number_format generates correct format codes", {
  # Excel format codes always use period (this is Excel's internal format)
  expect_equal(create_excel_number_format(0), "0")
  expect_equal(create_excel_number_format(1), "0.0")
  expect_equal(create_excel_number_format(2), "0.00")
  expect_equal(create_excel_number_format(3), "0.000")
})

test_that("create_excel_number_format validates inputs", {
  # Invalid decimal places (negative)
  expect_error(
    create_excel_number_format(-1),
    regexp = "decimal_places must be"
  )

  # Invalid decimal places (too large)
  expect_error(
    create_excel_number_format(10),
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
# Test: Decimal Separator Consistency
# ==============================================================================

test_that("Decimal separator is respected in format_number", {
  # String formatting should respect separator
  expect_equal(format_number(95.5, 1, "."), "95.5")
  expect_equal(format_number(95.5, 1, ","), "95,5")

  # Different separators produce different output
  period_result <- format_number(123.456, 2, ".")
  comma_result <- format_number(123.456, 2, ",")

  expect_equal(period_result, "123.46")
  expect_equal(comma_result, "123,46")
  expect_false(period_result == comma_result)
})

test_that("Excel format codes always use period (Excel standard)", {
  # Excel internally always uses period for decimal
  expect_equal(create_excel_number_format(1), "0.0")
  expect_equal(create_excel_number_format(2), "0.00")
})

cat("\n✓ Shared formatting module tests completed\n")
cat("  All formatting functions validated\n")
