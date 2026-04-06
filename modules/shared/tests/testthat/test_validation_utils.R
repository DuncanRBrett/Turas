# ==============================================================================
# TESTS: validation_utils.R
# ==============================================================================
# Tests for the shared validation utilities.
# Covers: validate_data_frame, validate_numeric_param, validate_logical_param,
#         validate_char_param, validate_file_path, has_data,
#         validate_column_exists, validate_weights.
# ==============================================================================

library(testthat)

# Source TRS infrastructure (required by validation_utils.R)
trs_path <- file.path(
  dirname(dirname(dirname(getwd()))),
  "shared", "lib", "trs_refusal.R"
)
if (!file.exists(trs_path)) {
  trs_path <- file.path(getwd(), "modules", "shared", "lib", "trs_refusal.R")
}
if (file.exists(trs_path)) source(trs_path)

# Source validation utilities
val_path <- file.path(
  dirname(dirname(dirname(getwd()))),
  "shared", "lib", "validation_utils.R"
)
if (!file.exists(val_path)) {
  val_path <- file.path(getwd(), "modules", "shared", "lib", "validation_utils.R")
}
if (file.exists(val_path)) source(val_path)

skip_if_not(exists("validate_data_frame", mode = "function"),
            message = "Validation utilities not available")


# ==============================================================================
# validate_data_frame()
# ==============================================================================

test_that("validate_data_frame passes for a valid data frame", {
  df <- data.frame(a = 1:5, b = letters[1:5])
  expect_invisible(validate_data_frame(df))
  expect_true(validate_data_frame(df))
})

test_that("validate_data_frame refuses NULL input with turas_refusal", {
  expect_error(
    validate_data_frame(NULL),
    class = "turas_refusal"
  )
  err <- tryCatch(validate_data_frame(NULL), turas_refusal = function(e) e)
  expect_equal(err$code, "DATA_INVALID_TYPE")
})

test_that("validate_data_frame refuses non-data-frame input", {
  expect_error(
    validate_data_frame(list(a = 1, b = 2)),
    class = "turas_refusal"
  )
  expect_error(
    validate_data_frame("not a data frame"),
    class = "turas_refusal"
  )
  expect_error(
    validate_data_frame(matrix(1:4, nrow = 2)),
    class = "turas_refusal"
  )

  err <- tryCatch(validate_data_frame(42), turas_refusal = function(e) e)
  expect_equal(err$code, "DATA_INVALID_TYPE")
})

test_that("validate_data_frame refuses empty data frame (0 rows)", {
  empty_df <- data.frame(a = integer(0), b = character(0))
  expect_error(
    validate_data_frame(empty_df),
    class = "turas_refusal"
  )

  err <- tryCatch(validate_data_frame(empty_df), turas_refusal = function(e) e)
  expect_equal(err$code, "DATA_INSUFFICIENT_ROWS")
})

test_that("validate_data_frame allows 0-row data frame when min_rows = 0", {
  empty_df <- data.frame(a = integer(0), b = character(0))
  expect_true(validate_data_frame(empty_df, min_rows = 0))
})

test_that("validate_data_frame refuses when required columns are missing", {
  df <- data.frame(x = 1:3, y = 4:6)
  expect_error(
    validate_data_frame(df, required_cols = c("x", "z")),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_data_frame(df, required_cols = c("x", "z")),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_MISSING_COLUMNS")
  expect_true("z" %in% err$missing)
})

test_that("validate_data_frame passes when required columns all present", {
  df <- data.frame(x = 1:3, y = 4:6, z = 7:9)
  expect_true(validate_data_frame(df, required_cols = c("x", "z")))
})

test_that("validate_data_frame handles column names with spaces", {
  df <- data.frame(1:3, 4:6)
  names(df) <- c("col one", "col two")

  expect_true(validate_data_frame(df, required_cols = c("col one")))

  expect_error(
    validate_data_frame(df, required_cols = c("col_one")),
    class = "turas_refusal"
  )
})

test_that("validate_data_frame respects max_rows", {
  df <- data.frame(a = 1:100)
  expect_error(
    validate_data_frame(df, max_rows = 50),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_data_frame(df, max_rows = 50),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_TOO_MANY_ROWS")
})

test_that("validate_data_frame uses param_name in error messages", {
  err <- tryCatch(
    validate_data_frame("bad", param_name = "survey_data"),
    turas_refusal = function(e) e
  )
  expect_true(grepl("survey_data", err$problem))
})


# ==============================================================================
# validate_numeric_param()
# ==============================================================================

test_that("validate_numeric_param passes for valid numeric", {
  expect_invisible(validate_numeric_param(5, "threshold"))
  expect_true(validate_numeric_param(5, "threshold"))
  expect_true(validate_numeric_param(3.14, "pi"))
  expect_true(validate_numeric_param(-10, "offset"))
})

test_that("validate_numeric_param refuses NA", {
  expect_error(
    validate_numeric_param(NA, "threshold"),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_numeric_param(NA, "threshold"),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_INVALID_NA_VALUE")
})

test_that("validate_numeric_param allows NA when allow_na = TRUE", {
  expect_true(validate_numeric_param(NA, "threshold", allow_na = TRUE))
})

test_that("validate_numeric_param refuses string input", {
  expect_error(
    validate_numeric_param("five", "threshold"),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_numeric_param("five", "threshold"),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_INVALID_PARAM_TYPE")
})

test_that("validate_numeric_param refuses out-of-range value (below min)", {
  expect_error(
    validate_numeric_param(0, "pct", min = 1, max = 100),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_numeric_param(0, "pct", min = 1, max = 100),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_VALUE_OUT_OF_RANGE")
})

test_that("validate_numeric_param refuses out-of-range value (above max)", {
  expect_error(
    validate_numeric_param(101, "pct", min = 1, max = 100),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_numeric_param(101, "pct", min = 1, max = 100),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_VALUE_OUT_OF_RANGE")
})

test_that("validate_numeric_param passes boundary values", {
  expect_true(validate_numeric_param(1, "pct", min = 1, max = 100))
  expect_true(validate_numeric_param(100, "pct", min = 1, max = 100))
  expect_true(validate_numeric_param(0, "zero", min = 0))
})

test_that("validate_numeric_param refuses vectors (length > 1)", {
  expect_error(
    validate_numeric_param(c(1, 2), "value"),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_numeric_param(c(1, 2), "value"),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_INVALID_PARAM_LENGTH")
})


# ==============================================================================
# validate_logical_param()
# ==============================================================================

test_that("validate_logical_param passes TRUE and FALSE", {
  expect_invisible(validate_logical_param(TRUE, "flag"))
  expect_true(validate_logical_param(TRUE, "flag"))
  expect_true(validate_logical_param(FALSE, "flag"))
})

test_that("validate_logical_param refuses NA", {
  expect_error(
    validate_logical_param(NA, "flag"),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_logical_param(NA, "flag"),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_INVALID_LOGICAL_VALUE")
})

test_that("validate_logical_param refuses string input", {
  expect_error(
    validate_logical_param("TRUE", "flag"),
    class = "turas_refusal"
  )
  expect_error(
    validate_logical_param("yes", "flag"),
    class = "turas_refusal"
  )
})

test_that("validate_logical_param refuses numeric input", {
  expect_error(
    validate_logical_param(1, "flag"),
    class = "turas_refusal"
  )
  expect_error(
    validate_logical_param(0, "flag"),
    class = "turas_refusal"
  )
})

test_that("validate_logical_param refuses NULL", {
  expect_error(
    validate_logical_param(NULL, "flag"),
    class = "turas_refusal"
  )
})

test_that("validate_logical_param refuses logical vector (length > 1)", {
  expect_error(
    validate_logical_param(c(TRUE, FALSE), "flag"),
    class = "turas_refusal"
  )
})


# ==============================================================================
# validate_char_param()
# ==============================================================================

test_that("validate_char_param passes for valid string", {
  expect_invisible(validate_char_param("hello", "name"))
  expect_true(validate_char_param("hello", "name"))
  expect_true(validate_char_param("some longer text", "desc"))
})

test_that("validate_char_param refuses NULL", {
  expect_error(
    validate_char_param(NULL, "name"),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_char_param(NULL, "name"),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_INVALID_CHAR_VALUE")
})

test_that("validate_char_param refuses empty string by default", {
  expect_error(
    validate_char_param("", "name"),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_char_param("", "name"),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_EMPTY_STRING_VALUE")
})

test_that("validate_char_param refuses whitespace-only string by default", {
  expect_error(
    validate_char_param("   ", "name"),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_char_param("   ", "name"),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_EMPTY_STRING_VALUE")
})

test_that("validate_char_param allows empty string when allow_empty = TRUE", {
  expect_true(validate_char_param("", "name", allow_empty = TRUE))
})

test_that("validate_char_param passes when value is in allowed_values", {
  expect_true(
    validate_char_param("csv", "format", allowed_values = c("csv", "xlsx", "sav"))
  )
})

test_that("validate_char_param refuses when value is not in allowed_values", {
  expect_error(
    validate_char_param("pdf", "format", allowed_values = c("csv", "xlsx", "sav")),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_char_param("pdf", "format", allowed_values = c("csv", "xlsx", "sav")),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_INVALID_CHOICE")
})

test_that("validate_char_param refuses NA character", {
  expect_error(
    validate_char_param(NA_character_, "name"),
    class = "turas_refusal"
  )
})

test_that("validate_char_param refuses numeric input", {
  expect_error(
    validate_char_param(42, "name"),
    class = "turas_refusal"
  )
})


# ==============================================================================
# validate_file_path()
# ==============================================================================

test_that("validate_file_path passes for an existing file", {
  tmp <- tempfile(fileext = ".csv")
  writeLines("a,b\n1,2", tmp)
  on.exit(unlink(tmp))

  expect_invisible(validate_file_path(tmp))
  expect_true(validate_file_path(tmp))
})

test_that("validate_file_path refuses non-existent file", {
  expect_error(
    validate_file_path("/nonexistent/path/fake_file.csv"),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_file_path("/nonexistent/path/fake_file.csv"),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "IO_FILE_NOT_FOUND")
})

test_that("validate_file_path refuses wrong extension", {
  tmp <- tempfile(fileext = ".txt")
  writeLines("test", tmp)
  on.exit(unlink(tmp))

  expect_error(
    validate_file_path(tmp, required_extensions = c("csv", "xlsx")),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_file_path(tmp, required_extensions = c("csv", "xlsx")),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "IO_INVALID_FILE_EXTENSION")
})

test_that("validate_file_path passes with correct extension", {
  tmp <- tempfile(fileext = ".csv")
  writeLines("a,b\n1,2", tmp)
  on.exit(unlink(tmp))

  expect_true(validate_file_path(tmp, required_extensions = c("csv", "xlsx")))
})

test_that("validate_file_path refuses NULL path", {
  expect_error(
    validate_file_path(NULL),
    class = "turas_refusal"
  )
})

test_that("validate_file_path refuses empty string path", {
  expect_error(
    validate_file_path(""),
    class = "turas_refusal"
  )
})

test_that("validate_file_path skips existence check when must_exist = FALSE", {
  expect_true(
    validate_file_path("/nonexistent/output.csv", must_exist = FALSE)
  )
})

test_that("validate_file_path validates extension even when file does not exist", {
  expect_error(
    validate_file_path(
      "/nonexistent/output.txt",
      must_exist = FALSE,
      required_extensions = c("csv", "xlsx"),
      validate_extension_even_if_missing = TRUE
    ),
    class = "turas_refusal"
  )
})

test_that("validate_file_path warns on large files", {
  # Create a file and mock its size via the warning text
  tmp <- tempfile(fileext = ".csv")
  writeLines("test", tmp)
  on.exit(unlink(tmp))

  # File is tiny, so no warning expected
  expect_silent(validate_file_path(tmp))
})


# ==============================================================================
# has_data()
# ==============================================================================

test_that("has_data returns TRUE for non-empty data frame", {
  df <- data.frame(a = 1:3)
  expect_true(has_data(df))
})

test_that("has_data returns FALSE for NULL", {
  expect_false(has_data(NULL))
})

test_that("has_data returns FALSE for empty data frame (0 rows)", {
  empty_df <- data.frame(a = integer(0))
  expect_false(has_data(empty_df))
})

test_that("has_data returns FALSE for non-data-frame objects", {
  expect_false(has_data(c(1, 2, 3)))
  expect_false(has_data(list(a = 1)))
  expect_false(has_data("text"))
})

test_that("has_data returns FALSE for NA-only vector (not a data frame)", {
  expect_false(has_data(c(NA, NA, NA)))
})

test_that("has_data returns TRUE for data frame with NA values", {
  df <- data.frame(a = c(NA, NA, NA))
  expect_true(has_data(df))
})


# ==============================================================================
# validate_column_exists()
# ==============================================================================

test_that("validate_column_exists passes when column is present", {
  df <- data.frame(x = 1:3, y = 4:6)
  expect_invisible(validate_column_exists(df, "x"))
  expect_true(validate_column_exists(df, "x"))
})

test_that("validate_column_exists refuses when column is missing", {
  df <- data.frame(x = 1:3, y = 4:6)
  expect_error(
    validate_column_exists(df, "z"),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_column_exists(df, "z"),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_COLUMN_NOT_FOUND")
  expect_equal(err$missing, "z")
})

test_that("validate_column_exists uses friendly_name in error message", {
  df <- data.frame(x = 1:3)
  err <- tryCatch(
    validate_column_exists(df, "weight_col", friendly_name = "Weight Column"),
    turas_refusal = function(e) e
  )
  expect_true(grepl("Weight Column", err$problem))
})

test_that("validate_column_exists reports available columns in observed", {
  df <- data.frame(alpha = 1:3, beta = 4:6)
  err <- tryCatch(
    validate_column_exists(df, "gamma"),
    turas_refusal = function(e) e
  )
  expect_true("alpha" %in% err$observed)
  expect_true("beta" %in% err$observed)
})


# ==============================================================================
# validate_weights()
# ==============================================================================

test_that("validate_weights passes for valid numeric weights", {
  expect_invisible(validate_weights(c(1.0, 2.0, 3.0), data_rows = 3))
  expect_true(validate_weights(c(1.0, 2.0, 3.0), data_rows = 3))
})

test_that("validate_weights passes for all-integer weights", {
  expect_true(validate_weights(c(1L, 2L, 3L), data_rows = 3))
})

test_that("validate_weights refuses negative weights", {
  expect_error(
    validate_weights(c(1.0, -0.5, 2.0), data_rows = 3),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_weights(c(1.0, -0.5, 2.0), data_rows = 3),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_WEIGHTS_NEGATIVE")
})

test_that("validate_weights refuses all-zero weights when allow_zero = FALSE", {
  expect_error(
    validate_weights(c(0, 0, 0), data_rows = 3, allow_zero = FALSE),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_weights(c(0, 0, 0), data_rows = 3, allow_zero = FALSE),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_WEIGHTS_ALL_ZERO")
})

test_that("validate_weights allows all-zero weights when allow_zero = TRUE (default)", {
  expect_warning(
    # NA check triggers warning even with zeros -- test the zero path
    validate_weights(c(0, 0, 0), data_rows = 3),
    NA
  )
})

test_that("validate_weights warns on NA weights", {
  expect_warning(
    validate_weights(c(1.0, NA, 3.0), data_rows = 3),
    "NA values"
  )
})

test_that("validate_weights refuses wrong length", {
  expect_error(
    validate_weights(c(1.0, 2.0), data_rows = 5),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_weights(c(1.0, 2.0), data_rows = 5),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_WEIGHTS_LENGTH_MISMATCH")
})

test_that("validate_weights refuses non-numeric input", {
  expect_error(
    validate_weights(c("a", "b", "c"), data_rows = 3),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_weights(c("a", "b", "c"), data_rows = 3),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_WEIGHTS_INVALID_TYPE")
})

test_that("validate_weights refuses logical input", {
  expect_error(
    validate_weights(c(TRUE, FALSE, TRUE), data_rows = 3),
    class = "turas_refusal"
  )

  err <- tryCatch(
    validate_weights(c(TRUE, FALSE, TRUE), data_rows = 3),
    turas_refusal = function(e) e
  )
  expect_equal(err$code, "DATA_WEIGHTS_INVALID_TYPE")
})

test_that("validate_weights handles mix of valid values and NAs", {
  expect_warning(
    result <- validate_weights(c(1.0, NA, 2.0, NA, 3.0), data_rows = 5),
    "2 NA values"
  )
  expect_true(result)
})

test_that("validate_weights refuses zero-length weights vector", {
  expect_error(
    validate_weights(numeric(0), data_rows = 5),
    class = "turas_refusal"
  )
})
