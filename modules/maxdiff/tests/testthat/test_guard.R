# ==============================================================================
# MAXDIFF TESTS - TRS GUARD LAYER
# ==============================================================================

test_that("validate_option accepts valid values", {
  result <- validate_option("YES", c("YES", "NO"), "test_param")
  expect_equal(result, "YES")
})

test_that("validate_option is case-insensitive by default", {
  result <- validate_option("yes", c("YES", "NO"), "test_param")
  expect_equal(toupper(result), "YES")
})

test_that("validate_option refuses invalid values", {
  result <- tryCatch(
    validate_option("MAYBE", c("YES", "NO"), "test_param"),
    error = function(e) list(status = "REFUSED")
  )
  # Should either throw or return a refusal
  expect_true(is.list(result) || inherits(result, "error"))
})

test_that("validate_positive_integer accepts valid integers", {
  expect_equal(validate_positive_integer(5, "test"), 5L)
  expect_equal(validate_positive_integer("10", "test"), 10L)
})

test_that("validate_positive_integer refuses zero", {
  result <- tryCatch(
    validate_positive_integer(0, "test"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("parse_yes_no handles various inputs", {
  expect_true(parse_yes_no("YES"))
  expect_true(parse_yes_no("Y"))
  expect_true(parse_yes_no("TRUE"))
  expect_true(parse_yes_no("1"))
  expect_true(parse_yes_no(TRUE))

  expect_false(parse_yes_no("NO"))
  expect_false(parse_yes_no("N"))
  expect_false(parse_yes_no("FALSE"))
  expect_false(parse_yes_no("0"))
  expect_false(parse_yes_no(FALSE))

  # Default for unknown
  expect_false(parse_yes_no("maybe"))
  expect_true(parse_yes_no("maybe", default = TRUE))
})

test_that("parse_yes_no handles NULL and NA", {
  expect_false(parse_yes_no(NULL))
  expect_false(parse_yes_no(NA))
  expect_true(parse_yes_no(NULL, default = TRUE))
})

test_that("safe_numeric converts correctly", {
  expect_equal(safe_numeric("3.14"), 3.14)
  expect_equal(safe_numeric(42), 42)
  expect_equal(safe_numeric("not_a_number", default = 0), 0)
  expect_equal(safe_numeric(NULL, default = -1), -1)
  expect_equal(safe_numeric(NA, default = 99), 99)
})

test_that("is_missing_value detects missing values", {
  expect_true(is_missing_value(NULL))
  expect_true(is_missing_value(NA))
  expect_true(is_missing_value(character(0)))
  expect_false(is_missing_value("hello"))
  expect_false(is_missing_value(0))
  expect_false(is_missing_value(FALSE))
})
