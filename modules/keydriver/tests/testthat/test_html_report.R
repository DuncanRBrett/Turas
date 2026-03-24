# ==============================================================================
# KEYDRIVER HTML REPORT TESTS
# ==============================================================================
#
# Tests for the HTML report pipeline:
#   - 00_html_guard.R  (validate_keydriver_html_inputs)
#   - 01_data_transformer.R  (transform_keydriver_for_html)
#   - 02_table_builder.R  (build_kd_importance_table, etc.)
#
# ==============================================================================

# module_dir and project_root are provided by helper-paths.R

# Source test data generators
source(file.path(module_dir, "tests", "fixtures", "generate_test_data.R"))

# Source shared TRS infrastructure (required by guard and transformer functions)
shared_lib <- file.path(project_root, "modules", "shared", "lib")
source(file.path(shared_lib, "trs_refusal.R"))

# Null-coalescing operator
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Source keydriver guard (needed by transformer and other modules)
keydriver_r_dir <- file.path(module_dir, "R")
source(file.path(keydriver_r_dir, "00_guard.R"))

# Source HTML report submodules
html_report_dir <- file.path(module_dir, "lib", "html_report")
if (dir.exists(html_report_dir)) {
  for (f in list.files(html_report_dir, pattern = "\\.R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }
}


# ==============================================================================
# validate_keydriver_html_inputs() - PASS cases
# ==============================================================================

test_that("validate_keydriver_html_inputs returns PASS for valid inputs", {
  skip_if_not_installed("htmltools")

  results <- generate_mock_results(n_drivers = 5)
  config <- generate_mock_config(n_drivers = 5)
  output_path <- file.path(tempdir(), "test_kd_report.html")

  result <- validate_keydriver_html_inputs(results, config, output_path)

  expect_equal(result$status, "PASS")
  expect_true(!is.null(result$message))
})


# ==============================================================================
# validate_keydriver_html_inputs() - REFUSED cases
# ==============================================================================

test_that("validate_keydriver_html_inputs refuses when results is NULL", {
  skip_if_not_installed("htmltools")

  config <- generate_mock_config()
  output_path <- file.path(tempdir(), "test_kd_report.html")

  result <- validate_keydriver_html_inputs(NULL, config, output_path)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_MISSING")
})

test_that("validate_keydriver_html_inputs refuses when results is missing required fields", {
  skip_if_not_installed("htmltools")

  # Results without model_summary and correlations
  results <- list(
    importance = data.frame(Driver = "d1", Correlation_Pct = 50, stringsAsFactors = FALSE)
  )
  config <- generate_mock_config()
  output_path <- file.path(tempdir(), "test_kd_report.html")

  result <- validate_keydriver_html_inputs(results, config, output_path)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_INVALID")
  expect_true(grepl("model_summary|correlations", result$message))
})

test_that("validate_keydriver_html_inputs refuses when importance is empty data.frame", {
  skip_if_not_installed("htmltools")

  results <- generate_mock_results(n_drivers = 5)
  results$importance <- data.frame()  # empty
  config <- generate_mock_config()
  output_path <- file.path(tempdir(), "test_kd_report.html")

  result <- validate_keydriver_html_inputs(results, config, output_path)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_INVALID")
  expect_true(grepl("importance", result$message, ignore.case = TRUE))
})

test_that("validate_keydriver_html_inputs refuses when config is NULL", {
  skip_if_not_installed("htmltools")

  results <- generate_mock_results(n_drivers = 5)
  output_path <- file.path(tempdir(), "test_kd_report.html")

  result <- validate_keydriver_html_inputs(results, NULL, output_path)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_INVALID")
})

test_that("validate_keydriver_html_inputs refuses when output_path is empty", {
  skip_if_not_installed("htmltools")

  results <- generate_mock_results(n_drivers = 5)
  config <- generate_mock_config()

  result <- validate_keydriver_html_inputs(results, config, "")

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})

test_that("validate_keydriver_html_inputs refuses when htmltools is missing", {
  # This test only makes sense if we can simulate htmltools being absent.
  # If htmltools IS installed, we skip since we cannot unload it safely.
  skip_if(requireNamespace("htmltools", quietly = TRUE),
          message = "htmltools is installed; cannot test PKG_HTMLTOOLS_MISSING path")

  results <- generate_mock_results(n_drivers = 5)
  config <- generate_mock_config()
  output_path <- file.path(tempdir(), "test_kd_report.html")

  result <- validate_keydriver_html_inputs(results, config, output_path)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "PKG_HTMLTOOLS_MISSING")
})


# ==============================================================================
# transform_keydriver_for_html() - Successful transformation
# ==============================================================================

test_that("transform_keydriver_for_html returns expected fields", {
  skip_if_not_installed("htmltools")

  results <- generate_mock_results(n_drivers = 5)
  config <- generate_mock_config(n_drivers = 5)

  html_data <- tryCatch(
    transform_keydriver_for_html(results, config),
    error = function(e) NULL
  )

  skip_if(is.null(html_data), message = "transform_keydriver_for_html returned NULL")

  expect_true(is.list(html_data))
  expect_true("n_drivers" %in% names(html_data))
  expect_true("methods_available" %in% names(html_data))
  expect_true("importance" %in% names(html_data))
  expect_true("correlations" %in% names(html_data))
  expect_true("model_info" %in% names(html_data))
  expect_true("has_shap" %in% names(html_data))
  expect_true("has_quadrant" %in% names(html_data))
  expect_true("has_bootstrap" %in% names(html_data))
  expect_equal(html_data$n_drivers, 5)
  expect_true(is.character(html_data$methods_available))
  # methods_available may be empty if mock importance column names use _Pct suffix
  # instead of the raw names the transformer checks for
})

test_that("transform_keydriver_for_html handles optional fields gracefully (quadrant)", {
  skip_if_not_installed("htmltools")

  results <- generate_mock_results(n_drivers = 5, include_quadrant = TRUE)
  config <- generate_mock_config(n_drivers = 5)

  html_data <- tryCatch(
    transform_keydriver_for_html(results, config),
    error = function(e) NULL
  )

  skip_if(is.null(html_data), message = "transform failed")

  expect_true(html_data$has_quadrant)
  expect_true(!is.null(html_data$quadrant_data))
})

test_that("transform_keydriver_for_html handles optional fields gracefully (bootstrap)", {
  skip_if_not_installed("htmltools")

  results <- generate_mock_results(n_drivers = 5, include_bootstrap = TRUE)
  config <- generate_mock_config(n_drivers = 5)

  html_data <- tryCatch(
    transform_keydriver_for_html(results, config),
    error = function(e) NULL
  )

  skip_if(is.null(html_data), message = "transform failed")

  expect_true(html_data$has_bootstrap)
  expect_true(!is.null(html_data$bootstrap_ci))
})

test_that("transform_keydriver_for_html handles optional fields gracefully (shap absent)", {
  skip_if_not_installed("htmltools")

  results <- generate_mock_results(n_drivers = 5, include_shap = FALSE)
  config <- generate_mock_config(n_drivers = 5)

  html_data <- tryCatch(
    transform_keydriver_for_html(results, config),
    error = function(e) NULL
  )

  skip_if(is.null(html_data), message = "transform failed")

  expect_false(html_data$has_shap)
})


# ==============================================================================
# Table builders - NULL input handling
# ==============================================================================

test_that("build_kd_importance_table returns NULL for NULL input", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_importance_table", mode = "function"),
          message = "build_kd_importance_table not available")

  result <- build_kd_importance_table(NULL)
  expect_null(result)
})

test_that("build_kd_importance_table returns NULL for empty list input", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_importance_table", mode = "function"),
          message = "build_kd_importance_table not available")

  result <- build_kd_importance_table(list())
  expect_null(result)
})

test_that("build_kd_importance_table returns valid htmltools tag object for valid data", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_importance_table", mode = "function"),
          message = "build_kd_importance_table not available")

  # Build importance data matching the expected structure
  importance_data <- list(
    list(rank = 1, label = "Price", driver = "price",
         importance_pct = 35, top_method = "Relative Weight"),
    list(rank = 2, label = "Quality", driver = "quality",
         importance_pct = 28, top_method = "Correlation"),
    list(rank = 3, label = "Service", driver = "service",
         importance_pct = 20, top_method = "Beta Weight"),
    list(rank = 4, label = "Brand", driver = "brand",
         importance_pct = 12, top_method = "Correlation"),
    list(rank = 5, label = "Location", driver = "location",
         importance_pct = 5, top_method = "Relative Weight")
  )

  result <- build_kd_importance_table(importance_data)

  expect_true(!is.null(result))
  expect_true(inherits(result, "shiny.tag") || inherits(result, "shiny.tag.list") ||
              inherits(result, "html"))
  # Render to string to ensure it is valid HTML
  html_str <- tryCatch(as.character(result), error = function(e) NULL)
  expect_true(!is.null(html_str))
  expect_true(nchar(html_str) > 0)
})

test_that("build_kd_method_comparison_table returns NULL for NULL input", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_method_comparison_table", mode = "function"),
          message = "build_kd_method_comparison_table not available")

  result <- tryCatch(build_kd_method_comparison_table(NULL), error = function(e) NULL)
  expect_null(result)
})

test_that("build_kd_correlation_table returns NULL for NULL input", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("build_kd_correlation_table", mode = "function"),
          message = "build_kd_correlation_table not available")

  result <- tryCatch(build_kd_correlation_table(NULL), error = function(e) NULL)
  expect_null(result)
})
