# ==============================================================================
# Unit Tests for Shared Formatting Utilities
# ==============================================================================
# Tests for /modules/shared/lib/formatting_utils.R
# ==============================================================================

# Setup: Source the shared utilities
test_that("formatting_utils.R can be sourced", {
  # Find Turas root
  current_dir <- getwd()
  while (current_dir != dirname(current_dir)) {
    if (file.exists(file.path(current_dir, "launch_turas.R")) ||
        dir.exists(file.path(current_dir, "modules", "shared"))) {
      break
    }
    current_dir <- dirname(current_dir)
  }

  formatting_path <- file.path(current_dir, "modules", "shared", "lib", "formatting_utils.R")
  expect_true(file.exists(formatting_path))
  source(formatting_path)
  expect_true(exists("format_number", mode = "function"))
})

# Source for remaining tests
current_dir <- getwd()
while (current_dir != dirname(current_dir)) {
  if (file.exists(file.path(current_dir, "launch_turas.R")) ||
      dir.exists(file.path(current_dir, "modules", "shared"))) {
    break
  }
  current_dir <- dirname(current_dir)
}
source(file.path(current_dir, "modules", "shared", "lib", "formatting_utils.R"))

# ==============================================================================
# Tests for create_excel_number_format()
# ==============================================================================

test_that("create_excel_number_format handles 0 decimal places", {
  result <- create_excel_number_format(0)
  expect_equal(result, "0")
})

test_that("create_excel_number_format handles 1 decimal place", {
  result <- create_excel_number_format(1)
  expect_equal(result, "0.0")
})

test_that("create_excel_number_format handles 2 decimal places", {
  result <- create_excel_number_format(2)
  expect_equal(result, "0.00")
})

test_that("create_excel_number_format handles 3 decimal places", {
  result <- create_excel_number_format(3)
  expect_equal(result, "0.000")
})

test_that("create_excel_number_format rejects invalid decimal places", {
  expect_error(create_excel_number_format(-1))
  expect_error(create_excel_number_format(7))
  expect_error(create_excel_number_format("abc"))
})

# ==============================================================================
# Tests for format_number()
# ==============================================================================

test_that("format_number formats single values correctly", {
  expect_equal(format_number(8.567, 1), "8.6")
  expect_equal(format_number(8.567, 2), "8.57")
  expect_equal(format_number(8.567, 0), "9")
})

test_that("format_number handles vectors", {
  result <- format_number(c(1.5, 2.5, 3.5), 1)
  expect_equal(result, c("1.5", "2.5", "3.5"))
})

test_that("format_number handles comma separator", {
  expect_equal(format_number(8.5, 1, ","), "8,5")
  expect_equal(format_number(123.456, 2, ","), "123,46")
})

test_that("format_number handles NA values", {
  result <- format_number(c(1.5, NA, 3.5), 1)
  expect_equal(result[1], "1.5")
  expect_true(is.na(result[2]))
  expect_equal(result[3], "3.5")
})

test_that("format_number handles NULL", {
  expect_null(format_number(NULL))
})

test_that("format_number handles all NA", {
  result <- format_number(c(NA, NA), 1)
  expect_true(all(is.na(result)))
})

test_that("format_number rejects invalid separator", {
  expect_error(format_number(8.5, 1, ";"))
})

test_that("format_number rejects invalid decimal places", {
  expect_error(format_number(8.5, -1))
  expect_error(format_number(8.5, 10))
})

# ==============================================================================
# Tests for format_percentage()
# ==============================================================================

test_that("format_percentage formats without sign", {
  expect_equal(format_percentage(95.5, 0), "96")
  expect_equal(format_percentage(95.5, 1), "95.5")
})

test_that("format_percentage adds percent sign", {
  expect_equal(format_percentage(95.5, 0, ".", TRUE), "96%")
  expect_equal(format_percentage(75.25, 1, ".", TRUE), "75.2%")
})

test_that("format_percentage handles comma separator", {
  expect_equal(format_percentage(95.5, 1, ","), "95,5")
  expect_equal(format_percentage(95.5, 1, ",", TRUE), "95,5%")
})

# ==============================================================================
# Tests for format_index()
# ==============================================================================

test_that("format_index formats ratings", {
  expect_equal(format_index(7.8, 1), "7.8")
  expect_equal(format_index(7.85, 2), "7.85")
})

# ==============================================================================
# Tests for validate_decimal_separator()
# ==============================================================================

test_that("validate_decimal_separator accepts valid separators", {
  expect_equal(validate_decimal_separator("."), ".")
  expect_equal(validate_decimal_separator(","), ",")
})

test_that("validate_decimal_separator returns default for NULL", {
  expect_equal(validate_decimal_separator(NULL), ".")
  expect_equal(validate_decimal_separator(NULL, ","), ",")
})

test_that("validate_decimal_separator warns on invalid", {
  expect_warning(result <- validate_decimal_separator(";"))
  expect_equal(result, ".")
})

# ==============================================================================
# Tests for validate_decimal_places()
# ==============================================================================

test_that("validate_decimal_places accepts valid values", {
  expect_equal(validate_decimal_places(0), 0L)
  expect_equal(validate_decimal_places(1), 1L)
  expect_equal(validate_decimal_places(6), 6L)
})

test_that("validate_decimal_places handles string input", {
  expect_equal(validate_decimal_places("2"), 2L)
})

test_that("validate_decimal_places returns default for NULL", {
  expect_equal(validate_decimal_places(NULL), 1L)
  expect_equal(validate_decimal_places(NULL, 2), 2L)
})

test_that("validate_decimal_places warns on invalid", {
  expect_warning(result <- validate_decimal_places(-1))
  expect_equal(result, 1L)

  expect_warning(result <- validate_decimal_places(10))
  expect_equal(result, 1L)
})

# ==============================================================================
# Summary
# ==============================================================================

cat("\n=== Formatting Utilities Tests Complete ===\n")
