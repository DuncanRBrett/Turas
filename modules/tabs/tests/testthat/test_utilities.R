# ==============================================================================
# TABS MODULE - UTILITY FUNCTION TESTS
# ==============================================================================
#
# Tests for utility functions across the tabs module:
#   1. type_utils.R — safe_logical, safe_numeric, safe_equal
#   2. config_utils.R — get_config_value, load_config_sheet
#   3. path_utils.R — resolve_path, tabs_lib_path
#   4. filter_utils.R — apply_base_filter, check_filter_security
#   5. validation_utils.R — validate_numeric_param, validate_data_frame
#   6. logging_utils.R — format_seconds
#   7. excel_utils.R — excel_column_letter
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_utilities.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

# Source TRS infrastructure
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))

# Source the guard layer (provides tabs_refuse)
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))

# Source utility modules in dependency order
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))


# ==============================================================================
# 1. type_utils.R — safe_logical
# ==============================================================================

context("safe_logical")

test_that("converts TRUE string variants", {
  expect_true(safe_logical("TRUE"))
  expect_true(safe_logical("true"))
  expect_true(safe_logical("T"))
  expect_true(safe_logical("Y"))
  expect_true(safe_logical("YES"))
  expect_true(safe_logical("yes"))
  expect_true(safe_logical("1"))
  expect_true(safe_logical(1))
  expect_true(safe_logical(TRUE))
})

test_that("converts FALSE string variants", {
  expect_false(safe_logical("FALSE"))
  expect_false(safe_logical("false"))
  expect_false(safe_logical("F"))
  expect_false(safe_logical("N"))
  expect_false(safe_logical("NO"))
  expect_false(safe_logical("no"))
  expect_false(safe_logical("0"))
  expect_false(safe_logical(0))
  expect_false(safe_logical(FALSE))
})

test_that("returns default for NULL, NA, and unrecognised input", {
  expect_false(safe_logical(NULL))
  expect_false(safe_logical(NA))
  expect_false(safe_logical("maybe"))
  expect_false(safe_logical(""))
  expect_true(safe_logical(NULL, default = TRUE))
  expect_true(safe_logical(NA, default = TRUE))
  expect_true(safe_logical("garbage", default = TRUE))
})

test_that("handles whitespace in input", {
  expect_true(safe_logical("  Y  "))
  expect_true(safe_logical("\tTRUE\n"))
  expect_false(safe_logical("  N  "))
})


# ==============================================================================
# 2. type_utils.R — safe_numeric
# ==============================================================================

context("safe_numeric")

test_that("converts valid numeric strings", {
  expect_equal(safe_numeric("42"), 42)
  expect_equal(safe_numeric("3.14"), 3.14)
  expect_equal(safe_numeric("-1.5"), -1.5)
  expect_equal(safe_numeric("0"), 0)
  expect_equal(safe_numeric(42), 42)
})

test_that("returns default for non-numeric input", {
  expect_true(is.na(safe_numeric("abc")))
  expect_true(is.na(safe_numeric("")))
  # NULL input returns zero-length numeric (not NA)
  expect_length(safe_numeric(NULL), 0)
  expect_true(is.na(safe_numeric(NA)))
  expect_equal(safe_numeric("abc", na_value = 0), 0)
  expect_length(safe_numeric(NULL, na_value = -1), 0)  # NULL → zero-length, na_value not applied
})


# ==============================================================================
# 3. type_utils.R — safe_equal
# ==============================================================================

context("safe_equal")

test_that("compares equal values correctly", {
  expect_true(safe_equal("hello", "hello"))
  expect_true(safe_equal(1, 1))
  expect_true(safe_equal(TRUE, TRUE))
})

test_that("compares unequal values correctly", {
  expect_false(safe_equal("hello", "world"))
  expect_false(safe_equal(1, 2))
})

test_that("handles NA values — both NA means both missing, so TRUE", {
  # Design decision: both-NA = TRUE (both values are missing = match)
  expect_true(safe_equal(NA, NA))
  expect_false(safe_equal(NA, "hello"))
  expect_false(safe_equal("hello", NA))
})

test_that("handles NULL values — zero-length input yields zero-length output", {
  # NULL has length 0, so safe_equal returns logical(0)
  expect_length(safe_equal(NULL, NULL), 0)
  expect_length(safe_equal(NULL, "hello"), 0)
  expect_length(safe_equal("hello", NULL), 0)
})

test_that("trims whitespace when comparing strings", {
  expect_true(safe_equal("  hello  ", "hello"))
  expect_true(safe_equal("hello", "  hello  "))
})


# ==============================================================================
# 4. config_utils.R — get_config_value
# ==============================================================================

context("get_config_value")

test_that("retrieves existing values", {
  config <- list(alpha = 0.05, name = "test", flag = TRUE)
  expect_equal(get_config_value(config, "alpha"), 0.05)
  expect_equal(get_config_value(config, "name"), "test")
  expect_true(get_config_value(config, "flag"))
})

test_that("returns default for missing values", {
  config <- list(alpha = 0.05)
  expect_equal(get_config_value(config, "missing", default_value = 99), 99)
  expect_null(get_config_value(config, "missing"))
})

test_that("returns default for NA values", {
  config <- list(alpha = NA)
  expect_equal(get_config_value(config, "alpha", default_value = 0.05), 0.05)
})

test_that("required missing value produces TRS refusal", {
  config <- list(alpha = 0.05)
  expect_error(
    get_config_value(config, "missing_required", required = TRUE),
    class = "turas_refusal"
  )
})


# ==============================================================================
# 5. path_utils.R — resolve_path
# ==============================================================================

context("resolve_path")

test_that("resolves relative paths", {
  result <- resolve_path("/base/dir", "sub/file.txt")
  expect_true(grepl("base/dir/sub/file.txt", result, fixed = TRUE))
})

test_that("joins absolute second path onto base (no special absolute handling)", {
  # resolve_path always combines base + relative via file.path then normalizes
  result <- resolve_path("/base/dir", "/absolute/path.txt")
  expect_true(grepl("absolute/path.txt", result, fixed = TRUE))
  expect_true(grepl("base/dir", result, fixed = TRUE))
})

test_that("strips ./ prefix from relative paths", {
  result <- resolve_path("/base/dir", "./sub/file.txt")
  expect_true(grepl("base/dir/sub/file.txt", result, fixed = TRUE))
  expect_false(grepl("/./", result, fixed = TRUE))
})


# ==============================================================================
# 6. filter_utils.R — check_filter_security
# ==============================================================================

context("check_filter_security")

test_that("allows safe filter expressions", {
  # Safe expressions should not produce TRS refusals
  result <- tryCatch(
    check_filter_security("Q1 == 'Male'"),
    turas_refusal = function(e) e
  )
  # If it returns without error, it's safe
  expect_false(inherits(result, "turas_refusal"))
})

test_that("blocks system() calls", {
  result <- tryCatch(
    check_filter_security("system('rm -rf /')"),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})

test_that("blocks file manipulation", {
  result <- tryCatch(
    check_filter_security("file.remove('data.csv')"),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})

test_that("blocks eval/parse", {
  result <- tryCatch(
    check_filter_security("eval(parse(text='1+1'))"),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})


# ==============================================================================
# 7. filter_utils.R — apply_base_filter
# ==============================================================================

context("apply_base_filter")

test_that("filters data correctly with simple expression", {
  data <- data.frame(
    Gender = c("Male", "Female", "Male", "Female"),
    Age = c(25, 30, 35, 40)
  )
  result <- apply_base_filter(data, "Gender == 'Male'")
  expect_equal(nrow(result), 2)
  expect_true(all(result$Gender == "Male"))
})

test_that("returns all rows for empty or NA filter", {
  data <- data.frame(X = 1:5)
  expect_equal(nrow(apply_base_filter(data, "")), 5)
  expect_equal(nrow(apply_base_filter(data, NA)), 5)
  expect_equal(nrow(apply_base_filter(data, NULL)), 5)
})

test_that("handles numeric comparisons", {
  data <- data.frame(Age = c(18, 25, 35, 45, 65))
  result <- apply_base_filter(data, "Age >= 30")
  expect_equal(nrow(result), 3)
  expect_true(all(result$Age >= 30))
})


# ==============================================================================
# 8. validation_utils.R — validate_data_frame
# ==============================================================================

context("validate_data_frame")

test_that("accepts valid data frame", {
  df <- data.frame(A = 1:3, B = c("x", "y", "z"))
  # Should not error
  result <- tryCatch(
    validate_data_frame(df, c("A", "B"), min_rows = 1),
    turas_refusal = function(e) e
  )
  expect_false(inherits(result, "turas_refusal"))
})

test_that("rejects missing required columns", {
  df <- data.frame(A = 1:3)
  result <- tryCatch(
    validate_data_frame(df, c("A", "B"), min_rows = 1),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})

test_that("rejects too few rows", {
  df <- data.frame(A = 1:2)
  result <- tryCatch(
    validate_data_frame(df, c("A"), min_rows = 5),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})


# ==============================================================================
# 9. logging_utils.R — format_seconds
# ==============================================================================

context("format_seconds")

test_that("formats seconds correctly", {
  expect_equal(format_seconds(30), "30s")
  expect_equal(format_seconds(0), "0s")
})

test_that("formats minutes as decimal", {
  # format_seconds uses decimal format: "1.5m" not "1m 30s"
  expect_equal(format_seconds(90), "1.5m")
  expect_equal(format_seconds(120), "2.0m")
})

test_that("formats hours as decimal", {
  # format_seconds uses decimal format: "1.0h" not "1h 1m 1s"
  expect_equal(format_seconds(3661), "1.0h")
  expect_equal(format_seconds(7200), "2.0h")
})


# ==============================================================================
# 10. excel_utils.R — excel_column_letter
# ==============================================================================

context("excel_column_letter")

test_that("converts single-letter columns correctly", {
  expect_equal(excel_column_letter(1), "A")
  expect_equal(excel_column_letter(26), "Z")
})

test_that("converts double-letter columns correctly", {
  expect_equal(excel_column_letter(27), "AA")
  expect_equal(excel_column_letter(28), "AB")
  expect_equal(excel_column_letter(52), "AZ")
  expect_equal(excel_column_letter(53), "BA")
})

test_that("converts triple-letter columns correctly", {
  expect_equal(excel_column_letter(703), "AAA")
})


# ==============================================================================
# 11. validate_numeric_param — NULL guard
# ==============================================================================

context("validate_numeric_param")

test_that("rejects NULL input", {
  result <- tryCatch(
    validate_numeric_param(NULL, "test_param"),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})

test_that("rejects NA when not allowed", {
  result <- tryCatch(
    validate_numeric_param(NA, "test_param", allow_na = FALSE),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})

test_that("accepts NA when allowed", {
  result <- tryCatch(
    validate_numeric_param(NA, "test_param", allow_na = TRUE),
    turas_refusal = function(e) e
  )
  expect_false(inherits(result, "turas_refusal"))
})

test_that("accepts valid numeric within range", {
  result <- tryCatch(
    validate_numeric_param(0.5, "alpha", min = 0, max = 1),
    turas_refusal = function(e) e
  )
  expect_false(inherits(result, "turas_refusal"))
})

test_that("rejects out-of-range values", {
  result <- tryCatch(
    validate_numeric_param(2.0, "alpha", min = 0, max = 1),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})
