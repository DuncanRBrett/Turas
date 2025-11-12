# ==============================================================================
# Tests for modules/tabs/lib/shared_functions.R
# ==============================================================================
# These tests validate the current behavior of shared functions.
# Created as part of Phase 1: Testing Infrastructure
# ==============================================================================

# Source the module under test
source("modules/tabs/lib/shared_functions.R", local = TRUE)

# ==============================================================================
# Test: is_package_available
# ==============================================================================

test_that("is_package_available detects installed packages", {
  # Test with a package that should be installed
  expect_true(is_package_available("base"))
  expect_true(is_package_available("utils"))

  # Test with a package that shouldn't exist
  expect_false(is_package_available("this_package_does_not_exist_xyz123"))
})

# ==============================================================================
# Test: Safe Type Conversion Functions
# ==============================================================================

test_that("safe_numeric converts values correctly", {
  skip_if_not(exists("safe_numeric"), message = "safe_numeric function not found")

  expect_equal(safe_numeric("123"), 123)
  expect_equal(safe_numeric("123.45"), 123.45)
  expect_equal(safe_numeric(""), NA_real_)
  expect_equal(safe_numeric(NA), NA_real_)
  expect_equal(safe_numeric("not_a_number"), NA_real_)
})

test_that("safe_logical converts values correctly", {
  skip_if_not(exists("safe_logical"), message = "safe_logical function not found")

  expect_equal(safe_logical("Y"), TRUE)
  expect_equal(safe_logical("N"), FALSE)
  expect_equal(safe_logical("TRUE"), TRUE)
  expect_equal(safe_logical("FALSE"), FALSE)
  expect_equal(safe_logical("yes"), TRUE)
  expect_equal(safe_logical("no"), FALSE)
  expect_equal(safe_logical(""), NA)
  expect_equal(safe_logical(NA), NA)
})

# ==============================================================================
# Test: Excel Column Letter Generation
# ==============================================================================

test_that("excel column letters generated correctly", {
  skip_if_not(exists("number_to_excel_column"), message = "number_to_excel_column function not found")

  # Test basic columns
  expect_equal(number_to_excel_column(1), "A")
  expect_equal(number_to_excel_column(26), "Z")

  # Test double-letter columns
  expect_equal(number_to_excel_column(27), "AA")
  expect_equal(number_to_excel_column(52), "AZ")

  # Test triple-letter columns
  expect_equal(number_to_excel_column(702), "ZZ")
  expect_equal(number_to_excel_column(703), "AAA")
})

# ==============================================================================
# Test: Path Resolution
# ==============================================================================

test_that("resolve_path handles absolute paths", {
  skip_if_not(exists("resolve_path"), message = "resolve_path function not found")

  # Absolute paths should be returned as-is (normalized)
  abs_path <- "/home/user/data.csv"
  result <- resolve_path(abs_path)
  expect_true(grepl("^/", result))  # Should start with /
})

test_that("resolve_path handles relative paths with base_dir", {
  skip_if_not(exists("resolve_path"), message = "resolve_path function not found")

  # Relative path with base directory
  result <- resolve_path("data.csv", base_dir = "/home/user/project")
  expect_true(grepl("^/", result))  # Should be absolute
  expect_true(grepl("data.csv$", result))  # Should end with filename
})

# ==============================================================================
# Test: Configuration Value Retrieval
# ==============================================================================

test_that("get_config_value retrieves values correctly", {
  skip_if_not(exists("get_config_value"), message = "get_config_value function not found")

  # Create test config
  test_config <- list(
    setting1 = "value1",
    setting2 = 42,
    setting3 = TRUE
  )

  # Test retrieval
  expect_equal(get_config_value(test_config, "setting1"), "value1")
  expect_equal(get_config_value(test_config, "setting2"), 42)
  expect_equal(get_config_value(test_config, "setting3"), TRUE)

  # Test default values
  expect_equal(get_config_value(test_config, "nonexistent", default = "default"), "default")
  expect_null(get_config_value(test_config, "nonexistent"))
})

# ==============================================================================
# Test: Data Frame Validation
# ==============================================================================

test_that("validate_data_frame catches invalid inputs", {
  skip_if_not(exists("validate_data_frame"), message = "validate_data_frame function not found")

  # Valid data frame should pass
  valid_df <- data.frame(ID = 1:5, Value = letters[1:5])
  expect_silent(validate_data_frame(valid_df, param_name = "test_df"))

  # NULL should fail
  expect_error(
    validate_data_frame(NULL, param_name = "test_df"),
    regexp = "test_df.*NULL"
  )

  # Non-data.frame should fail
  expect_error(
    validate_data_frame(list(a = 1), param_name = "test_df"),
    regexp = "test_df.*data.frame"
  )

  # Empty data frame should fail with min_rows
  empty_df <- data.frame()
  expect_error(
    validate_data_frame(empty_df, min_rows = 1, param_name = "test_df"),
    regexp = "test_df.*0 rows"
  )
})

test_that("validate_data_frame checks required columns", {
  skip_if_not(exists("validate_data_frame"), message = "validate_data_frame function not found")

  test_df <- data.frame(ID = 1:5, Name = letters[1:5])

  # Should pass with required columns present
  expect_silent(
    validate_data_frame(test_df, required_cols = c("ID", "Name"), param_name = "test_df")
  )

  # Should fail with missing required columns
  expect_error(
    validate_data_frame(test_df, required_cols = c("ID", "Age"), param_name = "test_df"),
    regexp = "Age"
  )
})

# ==============================================================================
# Test: Safe Comparison
# ==============================================================================

test_that("safe_equal handles NA correctly", {
  skip_if_not(exists("safe_equal"), message = "safe_equal function not found")

  # Normal equality
  expect_true(safe_equal("A", "A"))
  expect_false(safe_equal("A", "B"))

  # NA handling
  expect_false(safe_equal(NA, "A"))
  expect_false(safe_equal("A", NA))
  expect_false(safe_equal(NA, NA))  # NA != NA in safe comparison

  # String "NA" vs actual NA
  expect_false(safe_equal("NA", NA))
})

# ==============================================================================
# Test: Memory Checking
# ==============================================================================

test_that("check_memory returns reasonable values", {
  skip_if_not(exists("check_memory"), message = "check_memory function not found")

  mem_info <- check_memory()

  expect_type(mem_info, "list")
  expect_true("used_mb" %in% names(mem_info) || "used" %in% names(mem_info))
})

cat("\n✓ shared_functions.R tests completed\n")
