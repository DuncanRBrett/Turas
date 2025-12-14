# ==============================================================================
# Unit Tests for Shared Validation Utilities
# ==============================================================================
# Tests for /modules/shared/lib/validation_utils.R
# ==============================================================================

# Setup: Source the shared utilities
test_that("validation_utils.R can be sourced", {
  # Find Turas root
  current_dir <- getwd()
  while (current_dir != dirname(current_dir)) {
    if (file.exists(file.path(current_dir, "launch_turas.R")) ||
        dir.exists(file.path(current_dir, "modules", "shared"))) {
      break
    }
    current_dir <- dirname(current_dir)
  }

  validation_path <- file.path(current_dir, "modules", "shared", "lib", "validation_utils.R")
  expect_true(file.exists(validation_path))
  source(validation_path)
  expect_true(exists("validate_data_frame", mode = "function"))
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
source(file.path(current_dir, "modules", "shared", "lib", "validation_utils.R"))

# ==============================================================================
# Tests for validate_data_frame()
# ==============================================================================

test_that("validate_data_frame passes for valid data frame", {
  df <- data.frame(a = 1:3, b = c("x", "y", "z"))
  expect_true(validate_data_frame(df))
})

test_that("validate_data_frame checks type", {
  expect_error(validate_data_frame(list(a = 1)), "must be a data frame")
  expect_error(validate_data_frame("not a df"), "must be a data frame")
  expect_error(validate_data_frame(1:10), "must be a data frame")
})

test_that("validate_data_frame checks min_rows", {
  df <- data.frame(a = 1:3)
  expect_true(validate_data_frame(df, min_rows = 1))
  expect_true(validate_data_frame(df, min_rows = 3))
  expect_error(validate_data_frame(df, min_rows = 5), "at least 5 rows")
})

test_that("validate_data_frame checks max_rows", {
  df <- data.frame(a = 1:100)
  expect_true(validate_data_frame(df, max_rows = 100))
  expect_error(validate_data_frame(df, max_rows = 50), "exceeds maximum")
})

test_that("validate_data_frame checks required columns", {
  df <- data.frame(a = 1, b = 2, c = 3)

  expect_true(validate_data_frame(df, required_cols = c("a", "b")))
  expect_true(validate_data_frame(df, required_cols = c("a", "b", "c")))
  expect_error(validate_data_frame(df, required_cols = c("a", "d")), "missing required columns")
})

test_that("validate_data_frame shows available columns on error", {
  df <- data.frame(col1 = 1, col2 = 2)
  expect_error(
    validate_data_frame(df, required_cols = "missing"),
    "Available columns"
  )
})

test_that("validate_data_frame uses param_name in errors", {
  df <- list(a = 1)
  expect_error(validate_data_frame(df, param_name = "survey_data"), "survey_data")
})

# ==============================================================================
# Tests for validate_numeric_param()
# ==============================================================================

test_that("validate_numeric_param passes for valid numeric", {
  expect_true(validate_numeric_param(5, "test_param"))
  expect_true(validate_numeric_param(0, "test_param"))
  expect_true(validate_numeric_param(-10, "test_param"))
  expect_true(validate_numeric_param(3.14, "test_param"))
})

test_that("validate_numeric_param checks type", {
  expect_error(validate_numeric_param("5", "test_param"), "must be a single numeric")
  expect_error(validate_numeric_param(c(1, 2), "test_param"), "must be a single numeric")
})

test_that("validate_numeric_param checks NA", {
  expect_error(validate_numeric_param(NA, "test_param"), "cannot be NA")
  expect_true(validate_numeric_param(NA, "test_param", allow_na = TRUE))
})

test_that("validate_numeric_param checks min", {
  expect_true(validate_numeric_param(5, "test_param", min = 0))
  expect_error(validate_numeric_param(-1, "test_param", min = 0), "minimum")
})

test_that("validate_numeric_param checks max", {
  expect_true(validate_numeric_param(5, "test_param", max = 10))
  expect_error(validate_numeric_param(15, "test_param", max = 10), "maximum")
})

test_that("validate_numeric_param uses param_name in errors", {
  expect_error(validate_numeric_param("bad", "alpha_value"), "alpha_value")
})

# ==============================================================================
# Tests for Constants
# ==============================================================================

test_that("Constants are defined", {
  expect_true(exists("MAX_FILE_SIZE_MB"))
  expect_true(exists("SUPPORTED_DATA_FORMATS"))
  expect_true(exists("SUPPORTED_CONFIG_FORMATS"))
})

test_that("Supported formats include common types", {
  expect_true("xlsx" %in% SUPPORTED_DATA_FORMATS)
  expect_true("csv" %in% SUPPORTED_DATA_FORMATS)
  expect_true("sav" %in% SUPPORTED_DATA_FORMATS)
})

# ==============================================================================
# Summary
# ==============================================================================

cat("\n=== Validation Utilities Tests Complete ===\n")
