# ==============================================================================
# MAXDIFF TESTS - CONFIGURATION UTILITIES
# ==============================================================================

# ==============================================================================
# parse_yes_no() extended tests
# ==============================================================================

test_that("parse_yes_no handles YES/yes/Yes case variations", {
  expect_true(parse_yes_no("YES"))
  expect_true(parse_yes_no("yes"))
  expect_true(parse_yes_no("Yes"))
  expect_true(parse_yes_no("yEs"))
})

test_that("parse_yes_no handles TRUE/true/1 as truthy", {
  expect_true(parse_yes_no("TRUE"))
  expect_true(parse_yes_no("true"))
  expect_true(parse_yes_no("True"))
  expect_true(parse_yes_no("1"))
  expect_true(parse_yes_no(1))
  expect_true(parse_yes_no(TRUE))
})

test_that("parse_yes_no handles Y/T shorthand as truthy", {
  expect_true(parse_yes_no("Y"))
  expect_true(parse_yes_no("y"))
  expect_true(parse_yes_no("T"))
  expect_true(parse_yes_no("t"))
})

test_that("parse_yes_no handles NO/FALSE/0/N/F as falsy", {
  expect_false(parse_yes_no("NO"))
  expect_false(parse_yes_no("no"))
  expect_false(parse_yes_no("FALSE"))
  expect_false(parse_yes_no("false"))
  expect_false(parse_yes_no("0"))
  expect_false(parse_yes_no(0))
  expect_false(parse_yes_no(FALSE))
  expect_false(parse_yes_no("N"))
  expect_false(parse_yes_no("n"))
  expect_false(parse_yes_no("F"))
  expect_false(parse_yes_no("f"))
})

test_that("parse_yes_no returns default for unrecognized strings", {
  expect_false(parse_yes_no("maybe"))
  expect_false(parse_yes_no("unknown"))
  expect_false(parse_yes_no(""))
  expect_true(parse_yes_no("maybe", default = TRUE))
  expect_true(parse_yes_no("xyz", default = TRUE))
})

test_that("parse_yes_no handles NULL, NA, and empty inputs", {
  expect_false(parse_yes_no(NULL))
  expect_false(parse_yes_no(NA))
  expect_false(parse_yes_no(character(0)))
  expect_true(parse_yes_no(NULL, default = TRUE))
  expect_true(parse_yes_no(NA, default = TRUE))
})

test_that("parse_yes_no handles vector input (takes first element)", {
  expect_true(parse_yes_no(c("YES", "NO")))
  expect_false(parse_yes_no(c("NO", "YES")))
})

# ==============================================================================
# safe_numeric() extended tests
# ==============================================================================

test_that("safe_numeric converts valid numeric strings", {
  expect_equal(safe_numeric("3.14"), 3.14)
  expect_equal(safe_numeric("42"), 42)
  expect_equal(safe_numeric("-7.5"), -7.5)
  expect_equal(safe_numeric("0"), 0)
  expect_equal(safe_numeric("1e3"), 1000)
})

test_that("safe_numeric passes through numeric values", {
  expect_equal(safe_numeric(42), 42)
  expect_equal(safe_numeric(3.14), 3.14)
  expect_equal(safe_numeric(-1L), -1)
})

test_that("safe_numeric returns default for invalid input", {
  expect_equal(safe_numeric("not_a_number", default = 0), 0)
  expect_equal(safe_numeric("abc", default = -1), -1)
  expect_equal(safe_numeric("", default = 99), 99)
})

test_that("safe_numeric returns default for NULL, NA, empty", {
  expect_equal(safe_numeric(NULL, default = -1), -1)
  expect_equal(safe_numeric(NA, default = 99), 99)
  expect_equal(safe_numeric(numeric(0), default = 5), 5)
  expect_equal(safe_numeric(character(0), default = 10), 10)
})

test_that("safe_numeric default is NA_real_ when not specified", {
  result <- safe_numeric("invalid")
  expect_true(is.na(result))
})

# ==============================================================================
# safe_integer() extended tests
# ==============================================================================

test_that("safe_integer converts valid inputs", {
  expect_equal(safe_integer("5"), 5L)
  expect_equal(safe_integer(10), 10L)
  expect_equal(safe_integer(3.7), 3L)  # truncates
  expect_equal(safe_integer("100"), 100L)
})

test_that("safe_integer returns default for invalid input", {
  expect_equal(safe_integer("abc", default = 0), 0L)
  expect_equal(safe_integer("3.14.15", default = -1), -1L)
})

test_that("safe_integer returns default for NULL, NA, empty", {
  expect_equal(safe_integer(NULL, default = 0), 0L)
  expect_equal(safe_integer(NA, default = 5), 5L)
  expect_equal(safe_integer(numeric(0), default = 7), 7L)
  expect_equal(safe_integer(character(0), default = 3), 3L)
})

test_that("safe_integer result is integer type", {
  result <- safe_integer("42")
  expect_true(is.integer(result))
})

# ==============================================================================
# Config validation: missing required fields
# ==============================================================================

test_that("validate_option refuses NULL value", {
  skip_if(!exists("validate_option", mode = "function"))

  result <- tryCatch(
    validate_option(NULL, c("YES", "NO"), "test_param"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_option refuses NA value", {
  skip_if(!exists("validate_option", mode = "function"))

  result <- tryCatch(
    validate_option(NA, c("YES", "NO"), "test_param"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_positive_integer refuses negative values", {
  skip_if(!exists("validate_positive_integer", mode = "function"))

  result <- tryCatch(
    validate_positive_integer(-5, "test_param"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_positive_integer refuses non-numeric strings", {
  skip_if(!exists("validate_positive_integer", mode = "function"))

  result <- tryCatch(
    validate_positive_integer("abc", "test_param"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_positive_integer refuses NULL", {
  skip_if(!exists("validate_positive_integer", mode = "function"))

  result <- tryCatch(
    validate_positive_integer(NULL, "test_param"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_numeric_range refuses out-of-range values", {
  skip_if(!exists("validate_numeric_range", mode = "function"))

  result <- tryCatch(
    validate_numeric_range(150, "test_param", min_val = 0, max_val = 100),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_numeric_range accepts in-range values", {
  skip_if(!exists("validate_numeric_range", mode = "function"))

  result <- validate_numeric_range(50, "test_param", min_val = 0, max_val = 100)
  expect_equal(result, 50)
})

test_that("validate_file_path refuses NULL path", {
  skip_if(!exists("validate_file_path", mode = "function"))

  result <- tryCatch(
    validate_file_path(NULL, "test_path"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_file_path refuses empty string", {
  skip_if(!exists("validate_file_path", mode = "function"))

  result <- tryCatch(
    validate_file_path("", "test_path"),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_file_path refuses non-existent file", {
  skip_if(!exists("validate_file_path", mode = "function"))

  result <- tryCatch(
    validate_file_path("/nonexistent/path/file.xlsx", "test_path", must_exist = TRUE),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))
})

test_that("validate_file_path refuses wrong extension", {
  skip_if(!exists("validate_file_path", mode = "function"))

  tmp <- tempfile(fileext = ".csv")
  writeLines("test", tmp)

  result <- tryCatch(
    validate_file_path(tmp, "test_path", must_exist = TRUE, extensions = c("xlsx")),
    error = function(e) list(status = "REFUSED")
  )
  expect_true(is.list(result))

  unlink(tmp)
})
