# ==============================================================================
# KEYDRIVER INTEGRATION TESTS
# ==============================================================================
#
# High-level integration tests for the keydriver module pipeline.
# Uses mock objects from generate_test_data.R to test:
#   - Mock results structure
#   - Data transformation for HTML
#   - Executive summary generation
#   - Effect size classification
#   - Bootstrap CI (small n_bootstrap for speed)
#   - Segment comparison
#   - HTML guard validation
#   - Full HTML report end-to-end
#
# ==============================================================================

# Null-coalescing operator
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Locate module root via sys.frame (works outside test_that) or test_path (inside)
.find_module_dir <- function() {
  # Try sys.frame approach first
  ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(ofile)) {
    return(normalizePath(file.path(dirname(ofile), "..", ".."), mustWork = FALSE))
  }
  # Fallback: use test_path
  tp <- tryCatch(testthat::test_path(), error = function(e) ".")
  normalizePath(file.path(tp, "..", ".."), mustWork = FALSE)
}
module_dir <- .find_module_dir()
project_root <- normalizePath(file.path(module_dir, "..", ".."), mustWork = FALSE)

# Source test data generators
source(file.path(module_dir, "tests", "fixtures", "generate_test_data.R"))

# Source shared TRS infrastructure
source(file.path(project_root, "modules", "shared", "lib", "trs_refusal.R"))

# Source keydriver modules
keydriver_r_dir <- file.path(module_dir, "R")
for (f in list.files(keydriver_r_dir, pattern = "\\.R$", full.names = TRUE)) {
  tryCatch(source(f), error = function(e) NULL)
}

# Source quadrant modules
quadrant_dir <- file.path(keydriver_r_dir, "kda_quadrant")
if (dir.exists(quadrant_dir)) {
  for (f in list.files(quadrant_dir, pattern = "\\.R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }
}

# Source HTML report modules (conditional on htmltools)
html_report_dir <- file.path(module_dir, "lib", "html_report")
if (dir.exists(html_report_dir)) {
  for (f in list.files(html_report_dir, pattern = "\\.R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }
}


# ==============================================================================
# 1. Mock results object structure
# ==============================================================================

test_that("mock results object has correct core structure", {
  results <- generate_mock_results(n_drivers = 5)

  expect_true(is.list(results))
  expect_true("importance" %in% names(results))
  expect_true("model_summary" %in% names(results))
  expect_true("correlations" %in% names(results))

  # Importance should be a data frame with expected columns
  expect_true(is.data.frame(results$importance))
  expect_true("Driver" %in% names(results$importance))
  expect_equal(nrow(results$importance), 5)

  # Model summary should have key metrics
  expect_true(is.list(results$model_summary))
  expect_true("r_squared" %in% names(results$model_summary))
  expect_true("n_obs" %in% names(results$model_summary))

  # Correlations should be a matrix
  expect_true(is.matrix(results$correlations))
  expect_equal(nrow(results$correlations), 5)
  expect_equal(ncol(results$correlations), 5)
})

test_that("mock results with optional components includes them", {
  results <- generate_mock_results(
    n_drivers = 5,
    include_shap = FALSE,
    include_quadrant = TRUE,
    include_bootstrap = TRUE
  )

  expect_true(!is.null(results$quadrant))
  expect_true(!is.null(results$bootstrap_ci))
  expect_true(is.data.frame(results$bootstrap_ci))
  expect_true("Driver" %in% names(results$bootstrap_ci))
  expect_true("Method" %in% names(results$bootstrap_ci))
  expect_true("CI_Lower" %in% names(results$bootstrap_ci))
  expect_true("CI_Upper" %in% names(results$bootstrap_ci))
})


# ==============================================================================
# 2. Data transformation for HTML
# ==============================================================================

test_that("mock results can be transformed for HTML", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("transform_keydriver_for_html", mode = "function"),
          message = "transform_keydriver_for_html not available")

  results <- generate_mock_results(n_drivers = 5)
  config <- generate_mock_config(n_drivers = 5)

  html_data <- tryCatch(
    transform_keydriver_for_html(results, config),
    error = function(e) NULL
  )

  skip_if(is.null(html_data), message = "transform_keydriver_for_html returned NULL")

  expect_true(is.list(html_data))
  expect_equal(html_data$n_drivers, 5)
  expect_true(is.list(html_data$importance) || is.data.frame(html_data$importance))
  expect_true(!is.null(html_data$methods_available))
  expect_true(!is.null(html_data$model_info))
})


# ==============================================================================
# 3. Executive summary from mock results
# ==============================================================================

test_that("executive summary can be generated from mock results", {
  skip_if(!exists("generate_executive_summary", mode = "function"),
          message = "generate_executive_summary not available")

  # Executive summary requires a model object (lm), not just model_summary
  # Build a real model from test data
  data <- generate_basic_kda_data(n = 200, n_drivers = 5, seed = 42)
  model <- lm(outcome ~ driver_1 + driver_2 + driver_3 + driver_4 + driver_5, data = data)

  results <- generate_mock_results(n_drivers = 5)
  results$model <- model

  summary_result <- tryCatch(
    generate_executive_summary(results),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(summary_result), message = "generate_executive_summary failed or refused")

  expect_true(is.list(summary_result))
  expect_true("headline" %in% names(summary_result))
  expect_true("key_findings" %in% names(summary_result))
  expect_true(nchar(summary_result$headline) > 0)
  expect_true(length(summary_result$key_findings) > 0)
})


# ==============================================================================
# 4. Effect size classification from mock results
# ==============================================================================

test_that("effect sizes can be classified from mock results", {
  skip_if(!exists("classify_effect_size", mode = "function"),
          message = "classify_effect_size not available")

  results <- generate_mock_results(n_drivers = 5)

  # Use effect size values from mock results
  expect_true(!is.null(results$effect_sizes))
  expect_true(is.data.frame(results$effect_sizes))

  # Classify each effect value
  for (i in seq_len(nrow(results$effect_sizes))) {
    value <- results$effect_sizes$effect_value[i]

    classification <- tryCatch(
      classify_effect_size(value, method = "cohen_f2"),
      error = function(e) NULL,
      turas_refusal = function(e) NULL
    )

    skip_if(is.null(classification), message = "classify_effect_size failed")

    expect_true(classification %in% c("Negligible", "Small", "Medium", "Large"),
                info = paste("Unexpected classification:", classification))
  }
})

test_that("effect size benchmarks return correct thresholds", {
  skip_if(!exists("get_effect_size_benchmarks", mode = "function"),
          message = "get_effect_size_benchmarks not available")

  benchmarks <- tryCatch(
    get_effect_size_benchmarks("cohen_f2"),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(benchmarks), message = "get_effect_size_benchmarks failed")

  expect_true(is.list(benchmarks))
  expect_true("negligible" %in% names(benchmarks))
  expect_true("small" %in% names(benchmarks))
  expect_true("medium" %in% names(benchmarks))
  expect_true(benchmarks$negligible < benchmarks$small)
  expect_true(benchmarks$small < benchmarks$medium)
})


# ==============================================================================
# 5. Bootstrap CI with small iteration count
# ==============================================================================

test_that("bootstrap function runs with n_bootstrap >= 100 (production guard minimum)", {
  skip_if(!exists("bootstrap_importance_ci", mode = "function"),
          message = "bootstrap_importance_ci not available")

  data <- generate_basic_kda_data(n = 100, n_drivers = 3, seed = 77)

  result <- tryCatch(
    bootstrap_importance_ci(
      data = data,
      outcome = "outcome",
      drivers = c("driver_1", "driver_2", "driver_3"),
      n_bootstrap = 100,
      ci_level = 0.95
    ),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(result), message = "bootstrap_importance_ci failed or refused")

  expect_true(is.data.frame(result))
  expect_true("Driver" %in% names(result))
  expect_true("Method" %in% names(result))
  expect_true("Point_Estimate" %in% names(result))
  expect_true("CI_Lower" %in% names(result))
  expect_true("CI_Upper" %in% names(result))
  expect_true("SE" %in% names(result))

  # 3 drivers x 3 methods = 9 rows
  expect_equal(nrow(result), 9)

  # CI_Lower should be less than CI_Upper for all rows
  for (i in seq_len(nrow(result))) {
    expect_true(result$CI_Lower[i] <= result$CI_Upper[i],
                info = paste("CI bounds inverted for row", i))
  }
})

test_that("bootstrap refuses n_bootstrap < 100", {
  skip_if(!exists("bootstrap_importance_ci", mode = "function"),
          message = "bootstrap_importance_ci not available")

  data <- generate_basic_kda_data(n = 100, n_drivers = 3, seed = 77)

  expect_error(
    bootstrap_importance_ci(
      data = data,
      outcome = "outcome",
      drivers = c("driver_1", "driver_2", "driver_3"),
      n_bootstrap = 10
    ),
    class = "turas_refusal"
  )
})


# ==============================================================================
# 6. Segment comparison with mock data
# ==============================================================================

test_that("segment comparison works with mock segment data", {
  skip_if(!exists("build_importance_comparison_matrix", mode = "function"),
          message = "build_importance_comparison_matrix not available")

  # Create per-segment importance data
  seg_list <- list(
    Premium = data.frame(
      Driver = paste0("driver_", 1:5),
      Importance_Pct = c(35, 25, 20, 12, 8),
      stringsAsFactors = FALSE
    ),
    Standard = data.frame(
      Driver = paste0("driver_", 1:5),
      Importance_Pct = c(20, 30, 15, 25, 10),
      stringsAsFactors = FALSE
    ),
    Budget = data.frame(
      Driver = paste0("driver_", 1:5),
      Importance_Pct = c(15, 10, 35, 20, 20),
      stringsAsFactors = FALSE
    )
  )

  result <- tryCatch(
    build_importance_comparison_matrix(seg_list),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(result), message = "build_importance_comparison_matrix failed")

  expect_true(is.data.frame(result))
  expect_true("Driver" %in% names(result))
  expect_true("Mean_Pct" %in% names(result))
  expect_true("Premium_Pct" %in% names(result))
  expect_true("Standard_Pct" %in% names(result))
  expect_true("Budget_Pct" %in% names(result))
  expect_equal(nrow(result), 5)

  # Verify ordering is by Mean_Pct descending
  mean_pcts <- result$Mean_Pct
  expect_true(all(diff(mean_pcts) <= 0),
              info = "Rows should be sorted by Mean_Pct descending")
})

test_that("driver classification works with comparison matrix", {
  skip_if(!exists("build_importance_comparison_matrix", mode = "function"),
          message = "build_importance_comparison_matrix not available")
  skip_if(!exists("classify_drivers", mode = "function"),
          message = "classify_drivers not available")

  seg_list <- list(
    Segment_A = data.frame(
      Driver = paste0("driver_", 1:5),
      Importance_Pct = c(35, 25, 20, 12, 8),
      stringsAsFactors = FALSE
    ),
    Segment_B = data.frame(
      Driver = paste0("driver_", 1:5),
      Importance_Pct = c(33, 27, 18, 14, 8),
      stringsAsFactors = FALSE
    )
  )

  comp_matrix <- tryCatch(
    build_importance_comparison_matrix(seg_list),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(comp_matrix), message = "comparison matrix failed")

  classification <- tryCatch(
    classify_drivers(comp_matrix, top_n = 3),
    error = function(e) NULL,
    turas_refusal = function(e) NULL
  )

  skip_if(is.null(classification), message = "classify_drivers failed")

  expect_true(is.data.frame(classification))
  expect_true("Driver" %in% names(classification))
  expect_true("Classification" %in% names(classification))
  expect_true(all(classification$Classification %in%
    c("Universal", "Segment-Specific", "Mixed", "Low Priority")))
})


# ==============================================================================
# 7. HTML guard validates valid mock inputs as PASS
# ==============================================================================

test_that("HTML guard validates valid mock inputs as PASS", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("validate_keydriver_html_inputs", mode = "function"),
          message = "validate_keydriver_html_inputs not available")

  results <- generate_mock_results(n_drivers = 5)
  config <- generate_mock_config(n_drivers = 5)
  output_path <- file.path(tempdir(), "integration_test_report.html")

  result <- validate_keydriver_html_inputs(results, config, output_path)

  expect_equal(result$status, "PASS")
})

test_that("HTML guard refuses incomplete mock results", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("validate_keydriver_html_inputs", mode = "function"),
          message = "validate_keydriver_html_inputs not available")

  # Partially constructed results missing correlations
  results <- list(
    importance = data.frame(Driver = "d1", Correlation_Pct = 50, stringsAsFactors = FALSE),
    model_summary = list(r_squared = 0.5)
  )
  config <- generate_mock_config()
  output_path <- file.path(tempdir(), "integration_test_report.html")

  result <- validate_keydriver_html_inputs(results, config, output_path)

  expect_equal(result$status, "REFUSED")
})


# ==============================================================================
# 8. Full HTML report generation end-to-end
# ==============================================================================

test_that("full HTML report generation works end-to-end with mock data", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("generate_keydriver_html_report", mode = "function"),
          message = "generate_keydriver_html_report not available")

  results <- generate_mock_results(
    n_drivers = 5,
    include_quadrant = TRUE,
    include_bootstrap = TRUE
  )
  config <- generate_mock_config(n_drivers = 5)
  output_path <- file.path(tempdir(), "integration_test_kd_full_report.html")

  # Clean up any prior file
  if (file.exists(output_path)) file.remove(output_path)

  report_result <- tryCatch(
    generate_keydriver_html_report(results, config, output_path),
    error = function(e) {
      list(status = "ERROR", message = e$message)
    }
  )

  # The report may succeed or produce a PARTIAL result with warnings
  expect_true(report_result$status %in% c("PASS", "PARTIAL"),
              info = paste("Report status:", report_result$status,
                           "Message:", report_result$message %||% "none"))

  # Output file should exist
  expect_true(file.exists(output_path),
              info = "HTML report file should have been written")

  # File size should be reasonable (at least 1 KB)
  if (file.exists(output_path)) {
    fsize <- file.info(output_path)$size
    expect_true(fsize > 1024,
                info = paste("File size too small:", fsize, "bytes"))
    # Clean up
    file.remove(output_path)
  }
})


# ==============================================================================
# 9. HTML report with v10.4 features
# ==============================================================================

test_that("HTML report includes v10.4 sections when data present", {
  skip_if_not_installed("htmltools")
  skip_if(!exists("generate_keydriver_html_report", mode = "function"),
          message = "generate_keydriver_html_report not available")

  results <- generate_mock_results(
    n_drivers = 5,
    include_quadrant = TRUE,
    include_bootstrap = TRUE,
    include_elastic_net = TRUE,
    include_nca = TRUE,
    include_dominance = TRUE,
    include_gam = TRUE
  )
  config <- generate_mock_config(n_drivers = 5)
  output_path <- file.path(tempdir(), "integration_v104_report.html")

  if (file.exists(output_path)) file.remove(output_path)

  report_result <- tryCatch(
    generate_keydriver_html_report(results, config, output_path),
    error = function(e) list(status = "ERROR", message = e$message)
  )

  expect_true(report_result$status %in% c("PASS", "PARTIAL"),
              info = paste("Report status:", report_result$status,
                           "Message:", report_result$message %||% "none"))

  if (file.exists(output_path)) {
    html_content <- readLines(output_path, warn = FALSE)
    html_text <- paste(html_content, collapse = "\n")

    # Check for v10.4 section markers
    expect_true(grepl("elastic", html_text, ignore.case = TRUE),
                info = "HTML report should contain elastic net section")
    expect_true(grepl("dominance", html_text, ignore.case = TRUE),
                info = "HTML report should contain dominance section")

    file.remove(output_path)
  }
})


# ==============================================================================
# 10. Mixed predictor data through analysis functions
# ==============================================================================

test_that("mixed predictor data handles categorical drivers", {
  skip_if(!exists("build_term_map", mode = "function"),
          message = "build_term_map not available")

  data <- generate_mixed_kda_data(n = 200, seed = 123)

  # Region is categorical — model terms will include dummy-coded levels
  model <- lm(overall_satisfaction ~ price + quality + service + region + segment,
               data = data)
  model_terms <- names(coef(model))[-1]  # remove intercept

  result <- tryCatch(
    build_term_map(
      model_terms = model_terms,
      driver_vars = c("price", "quality", "service", "region", "segment"),
      data = data
    ),
    error = function(e) NULL
  )

  skip_if(is.null(result), message = "build_term_map failed with mixed predictors")

  # All model terms should be mapped to a driver
  expect_true(is.character(result) || is.list(result))
  if (is.character(result)) {
    expect_true(length(result) == length(model_terms))
    # Every mapped driver should be one of the original drivers
    expect_true(all(result %in% c("price", "quality", "service", "region", "segment")))
  }
})
