# ==============================================================================
# TEST SUITE: Utility Functions (utils.R)
# ==============================================================================
# Tests for validation helpers, formatting, and utility functions
# ==============================================================================

library(testthat)

# ==============================================================================
# validate_proportion()
# ==============================================================================

test_that("validate_proportion accepts valid proportions", {
  expect_invisible(validate_proportion(0, "p"))
  expect_invisible(validate_proportion(0.5, "p"))
  expect_invisible(validate_proportion(1, "p"))
  expect_invisible(validate_proportion(0.001, "p"))
  expect_invisible(validate_proportion(0.999, "p"))
})

test_that("validate_proportion refuses out of range", {
  expect_error(validate_proportion(-0.1, "p"), class = "turas_refusal")
  expect_error(validate_proportion(1.1, "p"), class = "turas_refusal")
  expect_error(validate_proportion(-1, "p"), class = "turas_refusal")
  expect_error(validate_proportion(5, "p"), class = "turas_refusal")
})

test_that("validate_proportion refuses non-numeric", {
  expect_error(validate_proportion("abc", "p"), class = "turas_refusal")
  expect_error(validate_proportion(NULL, "p"), class = "turas_refusal")
  expect_error(validate_proportion(NA, "p"), class = "turas_refusal")
})

# ==============================================================================
# validate_sample_size()
# ==============================================================================

test_that("validate_sample_size accepts valid sizes", {
  expect_invisible(validate_sample_size(10, "n"))
  expect_invisible(validate_sample_size(100, "n"))
  expect_invisible(validate_sample_size(10000, "n"))
})

test_that("validate_sample_size refuses zero and negative", {
  expect_error(validate_sample_size(0, "n"), class = "turas_refusal")
  expect_error(validate_sample_size(-5, "n"), class = "turas_refusal")
})

test_that("validate_sample_size refuses non-integer", {
  expect_error(validate_sample_size(10.5, "n"), class = "turas_refusal")
})

test_that("validate_sample_size refuses non-numeric", {
  expect_error(validate_sample_size("abc", "n"), class = "turas_refusal")
  expect_error(validate_sample_size(NULL, "n"), class = "turas_refusal")
  expect_error(validate_sample_size(NA, "n"), class = "turas_refusal")
})

test_that("validate_sample_size respects min_n parameter", {
  expect_error(validate_sample_size(5, "n", min_n = 10), class = "turas_refusal")
  expect_invisible(validate_sample_size(10, "n", min_n = 10))
})

# ==============================================================================
# validate_conf_level()
# ==============================================================================

test_that("validate_conf_level accepts standard levels", {
  expect_invisible(validate_conf_level(0.90))
  expect_invisible(validate_conf_level(0.95))
  expect_invisible(validate_conf_level(0.99))
})

test_that("validate_conf_level refuses out of range", {
  expect_error(validate_conf_level(0), class = "turas_refusal")
  expect_error(validate_conf_level(1), class = "turas_refusal")
  expect_error(validate_conf_level(-0.5), class = "turas_refusal")
  expect_error(validate_conf_level(1.5), class = "turas_refusal")
})

test_that("validate_conf_level refuses non-numeric", {
  expect_error(validate_conf_level("0.95"), class = "turas_refusal")
  expect_error(validate_conf_level(NULL), class = "turas_refusal")
  expect_error(validate_conf_level(NA), class = "turas_refusal")
})

# ==============================================================================
# validate_decimal_separator()
# ==============================================================================

test_that("validate_decimal_separator accepts valid separators", {
  expect_invisible(validate_decimal_separator("."))
  expect_invisible(validate_decimal_separator(","))
})

test_that("validate_decimal_separator refuses invalid separators", {
  expect_error(validate_decimal_separator(";"), class = "turas_refusal")
  expect_error(validate_decimal_separator(""), class = "turas_refusal")
  expect_error(validate_decimal_separator(NULL), class = "turas_refusal")
})

# ==============================================================================
# format_decimal()
# ==============================================================================

test_that("format_decimal formats with period", {
  result <- format_decimal(3.14159, ".", 2)
  expect_equal(result, "3.14")
})

test_that("format_decimal formats with comma", {
  result <- format_decimal(3.14159, ",", 2)
  expect_equal(result, "3,14")
})

test_that("format_decimal handles different decimal places", {
  expect_equal(format_decimal(3.14159, ".", 0), "3")
  expect_equal(format_decimal(3.14159, ".", 1), "3.1")
  expect_equal(format_decimal(3.14159, ".", 4), "3.1416")
})

test_that("format_decimal handles NA_real_", {
  result <- format_decimal(NA_real_, ".", 2)
  expect_equal(trimws(result), "NA")
})

test_that("format_decimal refuses non-numeric NA", {
  expect_error(format_decimal(NA, ".", 2), class = "turas_refusal")
})

# ==============================================================================
# check_small_sample()
# ==============================================================================

test_that("check_small_sample warns for very small samples", {
  result <- check_small_sample(5)
  expect_true(nzchar(result))
  expect_true(grepl("unstable|caution|small", result, ignore.case = TRUE))
})

test_that("check_small_sample warns for moderately small samples", {
  result <- check_small_sample(20)
  expect_true(nzchar(result))
})

test_that("check_small_sample returns empty for adequate samples", {
  result <- check_small_sample(100)
  expect_equal(result, "")
})

# ==============================================================================
# check_extreme_proportion()
# ==============================================================================

test_that("check_extreme_proportion warns for low p", {
  result <- check_extreme_proportion(0.05)
  expect_true(nzchar(result))
  expect_true(grepl("extreme|Wilson", result, ignore.case = TRUE))
})

test_that("check_extreme_proportion warns for high p", {
  result <- check_extreme_proportion(0.95)
  expect_true(nzchar(result))
})

test_that("check_extreme_proportion returns empty for moderate p", {
  result <- check_extreme_proportion(0.5)
  expect_equal(result, "")
})

# ==============================================================================
# parse_codes()
# ==============================================================================

test_that("parse_codes handles numeric codes", {
  result <- parse_codes("1,2,3")
  expect_equal(result, c(1, 2, 3))
})

test_that("parse_codes handles character codes", {
  result <- parse_codes("A,B,C")
  expect_equal(result, c("A", "B", "C"))
})

test_that("parse_codes handles whitespace", {
  result <- parse_codes("1 , 2 , 3")
  expect_equal(result, c(1, 2, 3))
})

test_that("parse_codes handles NULL/NA/empty", {
  expect_null(parse_codes(NULL))
  expect_null(parse_codes(NA))
  expect_null(parse_codes(""))
})

# ==============================================================================
# safe_divide()
# ==============================================================================

test_that("safe_divide handles normal division", {
  expect_equal(safe_divide(10, 2), 5)
  expect_equal(safe_divide(1, 3), 1/3)
})

test_that("safe_divide returns NA for zero denominator by default", {
  expect_true(is.na(safe_divide(10, 0)))
})

test_that("safe_divide returns Inf when na_on_zero is FALSE", {
  expect_equal(safe_divide(10, 0, na_on_zero = FALSE), Inf)
})

test_that("safe_divide handles vectors", {
  result <- safe_divide(c(10, 20, 30), c(2, 0, 5))
  expect_equal(result[1], 5)
  expect_true(is.na(result[2]))
  expect_equal(result[3], 6)
})

# ==============================================================================
# create_timestamp()
# ==============================================================================

test_that("create_timestamp returns formatted string", {
  ts <- create_timestamp()
  expect_type(ts, "character")
  expect_true(grepl("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$", ts))
})

# ==============================================================================
# END OF TEST SUITE
# ==============================================================================
