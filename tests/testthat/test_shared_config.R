# ==============================================================================
# Tests for modules/shared/lib/config_utils.R
# ==============================================================================
# Tests for the shared configuration utilities module.
# This module provides consistent config handling across all TURAS modules.
# ==============================================================================

# Find Turas root for sourcing
find_test_turas_root <- function() {
  current_dir <- getwd()
  while (current_dir != dirname(current_dir)) {
    if (file.exists(file.path(current_dir, "launch_turas.R")) ||
        dir.exists(file.path(current_dir, "modules", "shared"))) {
      return(current_dir)
    }
    current_dir <- dirname(current_dir)
  }
  stop("Cannot locate Turas root directory")
}

turas_root <- find_test_turas_root()

# Source required dependencies first
source(file.path(turas_root, "modules/shared/lib/validation_utils.R"), local = TRUE)
source(file.path(turas_root, "modules/shared/lib/data_utils.R"), local = TRUE)

# Source the module under test
source(file.path(turas_root, "modules/shared/lib/config_utils.R"), local = TRUE)

# ==============================================================================
# Test: find_turas_root
# ==============================================================================

test_that("find_turas_root returns a valid path", {
  result <- find_turas_root()

  expect_type(result, "character")
  expect_true(nzchar(result))
  expect_true(dir.exists(result))
})

test_that("find_turas_root finds correct markers", {
  result <- find_turas_root()

  # Should contain launch_turas.R, turas.R, or modules/shared/
  has_launch <- file.exists(file.path(result, "launch_turas.R"))
  has_turas_r <- file.exists(file.path(result, "turas.R"))
  has_modules_shared <- dir.exists(file.path(result, "modules", "shared"))

  expect_true(has_launch || has_turas_r || has_modules_shared)
})

test_that("find_turas_root caches result", {
  # Clear cache first
  if (exists("TURAS_ROOT", envir = .GlobalEnv)) {
    rm("TURAS_ROOT", envir = .GlobalEnv)
  }

  # First call should set cache
  result1 <- find_turas_root()
  expect_true(exists("TURAS_ROOT", envir = .GlobalEnv))

  # Second call should return cached value
  result2 <- find_turas_root()
  expect_equal(result1, result2)
})

# ==============================================================================
# Test: resolve_path
# ==============================================================================

test_that("resolve_path handles relative paths", {
  base <- turas_root
  result <- resolve_path(base, "modules")
  expect_true(grepl("modules", result))
})

test_that("resolve_path handles ./ prefix", {
  base <- turas_root
  result <- resolve_path(base, "./modules")
  expect_true(grepl("modules", result))
})

test_that("resolve_path handles empty relative path", {
  base <- turas_root
  result <- resolve_path(base, "")
  expect_equal(normalizePath(result, mustWork = FALSE),
               normalizePath(base, mustWork = FALSE))
})

test_that("resolve_path rejects empty base path", {
  expect_error(resolve_path("", "modules"), "cannot be empty")
})

# ==============================================================================
# Test: get_project_root
# ==============================================================================

test_that("get_project_root returns parent directory", {
  config_path <- file.path(turas_root, "modules", "tabs", "config.xlsx")
  result <- get_project_root(config_path)
  expect_true(grepl("tabs", result))
})

test_that("get_project_root rejects empty path", {
  expect_error(get_project_root(""), "cannot be empty")
})

# ==============================================================================
# Test: get_config_value
# ==============================================================================

test_that("get_config_value retrieves existing values", {
  config <- list(
    setting1 = "value1",
    setting2 = 42,
    setting3 = TRUE
  )

  expect_equal(get_config_value(config, "setting1"), "value1")
  expect_equal(get_config_value(config, "setting2"), 42)
  expect_equal(get_config_value(config, "setting3"), TRUE)
})

test_that("get_config_value returns default for missing settings", {
  config <- list(existing = "value")

  result <- get_config_value(config, "nonexistent", default_value = "default")
  expect_equal(result, "default")

  result_null <- get_config_value(config, "nonexistent")
  expect_null(result_null)
})

test_that("get_config_value handles required settings", {
  config <- list(existing = "value")

  expect_error(
    get_config_value(config, "missing", required = TRUE),
    regexp = "Required setting"
  )
})

test_that("get_config_value handles NA values", {
  config <- list(na_setting = NA)

  result <- get_config_value(config, "na_setting", default_value = "fallback")
  expect_equal(result, "fallback")
})

# ==============================================================================
# Test: get_numeric_config
# ==============================================================================

test_that("get_numeric_config converts string to numeric", {
  config <- list(decimal_places = "2")

  result <- get_numeric_config(config, "decimal_places")
  expect_type(result, "double")
  expect_equal(result, 2)
})

test_that("get_numeric_config validates range", {
  config <- list(value = "100")

  expect_error(
    get_numeric_config(config, "value", max = 50),
    regexp = "must be between"
  )
})

test_that("get_numeric_config returns default for missing", {
  config <- list()

  result <- get_numeric_config(config, "missing", default_value = 10)
  expect_equal(result, 10)
})

# ==============================================================================
# Test: get_logical_config
# ==============================================================================

test_that("get_logical_config handles Y/N strings", {
  config <- list(
    show_base = "Y",
    verbose = "N"
  )

  expect_true(get_logical_config(config, "show_base"))
  expect_false(get_logical_config(config, "verbose"))
})

test_that("get_logical_config returns default for missing", {
  config <- list()

  expect_true(get_logical_config(config, "missing", default_value = TRUE))
  expect_false(get_logical_config(config, "missing", default_value = FALSE))
})

# ==============================================================================
# Test: get_char_config
# ==============================================================================

test_that("get_char_config retrieves string values", {
  config <- list(output_format = "xlsx")

  result <- get_char_config(config, "output_format")
  expect_equal(result, "xlsx")
})

test_that("get_char_config validates allowed values", {
  config <- list(format = "invalid")

  expect_error(
    get_char_config(config, "format", allowed_values = c("xlsx", "csv")),
    regexp = "must be one of"
  )
})

cat("\n=== Config Utilities Tests Complete ===\n")
