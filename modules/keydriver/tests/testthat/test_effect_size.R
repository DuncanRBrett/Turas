# ==============================================================================
# TEST SUITE: Effect Size Interpretation
# ==============================================================================
# Tests for effect size benchmarks, classification, Cohen's f2, and
# interpretation generation in the keydriver module.
# Part of Turas Key Driver Module Test Suite
# ==============================================================================

library(testthat)

context("Effect Size Interpretation")

# ==============================================================================
# SETUP: Source dependencies and test data generators
# ==============================================================================

# Define %||% operator if not already available
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Locate module root
test_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."))
module_dir <- dirname(test_dir)
project_root <- normalizePath(file.path(module_dir, "..", ".."))

# Source shared TRS infrastructure
tryCatch({
  source(file.path(project_root, "modules", "shared", "lib", "trs_refusal.R"))
}, error = function(e) {
  skip(paste("Cannot load TRS infrastructure:", conditionMessage(e)))
})

# Source keydriver guard layer (provides keydriver_refuse)
tryCatch({
  source(file.path(module_dir, "R", "00_guard.R"))
}, error = function(e) {
  skip(paste("Cannot load keydriver guard:", conditionMessage(e)))
})

# Source the effect size module under test
tryCatch({
  source(file.path(module_dir, "R", "06_effect_size.R"))
}, error = function(e) {
  skip(paste("Cannot load effect size module:", conditionMessage(e)))
})

# Source test data generators
tryCatch({
  source(file.path(test_dir, "fixtures", "generate_test_data.R"))
}, error = function(e) {
  skip(paste("Cannot load test data generators:", conditionMessage(e)))
})


# ==============================================================================
# BENCHMARK THRESHOLD TESTS
# ==============================================================================

test_that("get_effect_size_benchmarks returns correct thresholds for cohen_f2", {
  benchmarks <- get_effect_size_benchmarks("cohen_f2")

  expect_true(is.list(benchmarks))
  expect_equal(benchmarks$negligible, 0.02)
  expect_equal(benchmarks$small, 0.15)
  expect_equal(benchmarks$medium, 0.35)
})


test_that("get_effect_size_benchmarks returns correct thresholds for standardized_beta", {
  benchmarks <- get_effect_size_benchmarks("standardized_beta")

  expect_true(is.list(benchmarks))
  expect_equal(benchmarks$negligible, 0.05)
  expect_equal(benchmarks$small, 0.10)
  expect_equal(benchmarks$medium, 0.30)
})


test_that("get_effect_size_benchmarks returns correct thresholds for correlation", {
  benchmarks <- get_effect_size_benchmarks("correlation")

  expect_true(is.list(benchmarks))
  expect_equal(benchmarks$negligible, 0.10)
  expect_equal(benchmarks$small, 0.30)
  expect_equal(benchmarks$medium, 0.50)
})


# ==============================================================================
# CLASSIFICATION TESTS
# ==============================================================================

test_that("classify_effect_size correctly classifies all categories for cohen_f2", {
  # Negligible: < 0.02
  expect_equal(classify_effect_size(0.01, method = "cohen_f2"), "Negligible")

  # Small: 0.02 <= value < 0.15
  expect_equal(classify_effect_size(0.08, method = "cohen_f2"), "Small")

  # Medium: 0.15 <= value < 0.35
  expect_equal(classify_effect_size(0.25, method = "cohen_f2"), "Medium")

  # Large: >= 0.35
  expect_equal(classify_effect_size(0.50, method = "cohen_f2"), "Large")
})


test_that("classify_effect_size correctly classifies all categories for standardized_beta", {
  # Negligible: < 0.05
  expect_equal(classify_effect_size(0.03, method = "standardized_beta"), "Negligible")

  # Small: 0.05 <= value < 0.10
  expect_equal(classify_effect_size(0.07, method = "standardized_beta"), "Small")

  # Medium: 0.10 <= value < 0.30
  expect_equal(classify_effect_size(0.20, method = "standardized_beta"), "Medium")

  # Large: >= 0.30
  expect_equal(classify_effect_size(0.45, method = "standardized_beta"), "Large")
})


test_that("classify_effect_size correctly classifies all categories for correlation", {
  # Negligible: < 0.10
  expect_equal(classify_effect_size(0.05, method = "correlation"), "Negligible")

  # Small: 0.10 <= value < 0.30
  expect_equal(classify_effect_size(0.20, method = "correlation"), "Small")

  # Medium: 0.30 <= value < 0.50
  expect_equal(classify_effect_size(0.40, method = "correlation"), "Medium")

  # Large: >= 0.50
  expect_equal(classify_effect_size(0.70, method = "correlation"), "Large")
})


test_that("classify_effect_size handles boundary values at exact thresholds", {
  # At the exact negligible threshold: value == 0.02 should be Small (not Negligible)
  # because classify uses < (strictly less than) for boundaries
  expect_equal(classify_effect_size(0.02, method = "cohen_f2"), "Small")

  # At the exact small threshold: value == 0.15 should be Medium
  expect_equal(classify_effect_size(0.15, method = "cohen_f2"), "Medium")

  # At the exact medium threshold: value == 0.35 should be Large
  expect_equal(classify_effect_size(0.35, method = "cohen_f2"), "Large")

  # Zero should be Negligible
  expect_equal(classify_effect_size(0, method = "cohen_f2"), "Negligible")
})


test_that("classify_effect_size uses absolute value for negative inputs", {
  # Negative beta of -0.42 should classify using |0.42| = 0.42 -> Large
  expect_equal(classify_effect_size(-0.42, method = "standardized_beta"), "Large")

  # Negative correlation of -0.15 should use |0.15| = 0.15 -> Small
  expect_equal(classify_effect_size(-0.15, method = "correlation"), "Small")
})


test_that("classify_effect_size refuses NA input with TRS refusal", {
  expect_error(
    classify_effect_size(NA, method = "cohen_f2"),
    class = "turas_refusal"
  )
})


# ==============================================================================
# COHEN'S F-SQUARED CALCULATION TESTS
# ==============================================================================

test_that("calculate_cohens_f2 returns correct values for known inputs", {
  # f2 = (R2_full - R2_reduced) / (1 - R2_full)
  # With R2_full = 0.45, R2_reduced = 0.30:
  # f2 = (0.45 - 0.30) / (1 - 0.45) = 0.15 / 0.55 = 0.2727...
  result <- calculate_cohens_f2(0.45, 0.30)
  expect_equal(result, 0.15 / 0.55, tolerance = 1e-10)

  # No incremental contribution: R2_full == R2_reduced
  result_zero <- calculate_cohens_f2(0.30, 0.30)
  expect_equal(result_zero, 0)

  # Small effect: R2_full = 0.10, R2_reduced = 0.05
  # f2 = 0.05 / 0.90 = 0.0556
  result_small <- calculate_cohens_f2(0.10, 0.05)
  expect_equal(result_small, 0.05 / 0.90, tolerance = 1e-10)
})


test_that("calculate_cohens_f2 handles perfect fit edge case", {
  # R2_full = 1 with positive difference -> Inf
  result <- calculate_cohens_f2(1.0, 0.5)
  expect_equal(result, Inf)

  # R2_full = 1 with no difference -> 0
  result_equal <- calculate_cohens_f2(1.0, 1.0)
  expect_equal(result_equal, 0)
})


test_that("calculate_cohens_f2 refuses NA inputs with TRS refusal", {
  expect_error(
    calculate_cohens_f2(NA, 0.30),
    class = "turas_refusal"
  )
  expect_error(
    calculate_cohens_f2(0.45, NA),
    class = "turas_refusal"
  )
})


test_that("calculate_cohens_f2 returns 0 when reduced model is better", {
  # R2_full < R2_reduced (unusual but handled gracefully)
  result <- calculate_cohens_f2(0.30, 0.35)
  expect_equal(result, 0)
})


# ==============================================================================
# EFFECT INTERPRETATION GENERATION TESTS
# ==============================================================================

test_that("generate_effect_interpretation returns data.frame with expected columns", {
  imp_df <- data.frame(
    Driver = c("Price", "Quality", "Service"),
    Beta_Coefficient = c(0.45, 0.22, 0.08),
    stringsAsFactors = FALSE
  )

  result <- generate_effect_interpretation(imp_df)

  expect_true(is.data.frame(result))
  expected_cols <- c("Driver", "Effect_Value", "Effect_Size", "Interpretation", "Benchmark_Method")
  expect_equal(names(result), expected_cols)
  expect_equal(nrow(result), 3)

  # All drivers should be present
  expect_equal(result$Driver, c("Price", "Quality", "Service"))

  # Benchmark method should be standardized_beta (no model_summary provided)
  expect_true(all(result$Benchmark_Method == "standardized_beta"))
})


test_that("generate_effect_interpretation works with model_summary (Cohen's f2)", {
  imp_df <- data.frame(
    Driver = c("Price", "Quality", "Service"),
    Beta_Coefficient = c(0.45, 0.22, 0.08),
    stringsAsFactors = FALSE
  )

  model_info <- list(
    r_squared_full = 0.55,
    r_squared_reduced = c(Price = 0.35, Quality = 0.48, Service = 0.53)
  )

  result <- generate_effect_interpretation(imp_df, model_summary = model_info)

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 3)
  expect_true(all(result$Benchmark_Method == "cohen_f2"))

  # Effect values should be non-negative (Cohen's f2 >= 0)
  expect_true(all(result$Effect_Value >= 0))
})


test_that("generate_effect_interpretation handles empty data frame", {
  empty_df <- data.frame(
    Driver = character(0),
    Beta_Coefficient = numeric(0),
    stringsAsFactors = FALSE
  )

  result <- generate_effect_interpretation(empty_df)

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 0)
  expected_cols <- c("Driver", "Effect_Value", "Effect_Size", "Interpretation", "Benchmark_Method")
  expect_equal(names(result), expected_cols)
})


# ==============================================================================
# TRS REFUSAL TESTS
# ==============================================================================

test_that("invalid method name triggers TRS refusal in get_effect_size_benchmarks", {
  expect_error(
    get_effect_size_benchmarks("invalid_method"),
    class = "turas_refusal"
  )

  expect_error(
    get_effect_size_benchmarks("COHEN_F2"),  # wrong case handled by tolower
    NA  # should NOT error because tolower normalizes it
  )
})


test_that("NULL method triggers TRS refusal in get_effect_size_benchmarks", {
  expect_error(
    get_effect_size_benchmarks(NULL),
    class = "turas_refusal"
  )
})


test_that("calculate_cohens_f2 refuses out-of-range R-squared", {
  expect_error(
    calculate_cohens_f2(1.5, 0.30),
    class = "turas_refusal"
  )

  expect_error(
    calculate_cohens_f2(0.45, -0.1),
    class = "turas_refusal"
  )
})


test_that("generate_effect_interpretation refuses non-data.frame input", {
  expect_error(
    generate_effect_interpretation("not a data.frame"),
    class = "turas_refusal"
  )

  expect_error(
    generate_effect_interpretation(NULL),
    class = "turas_refusal"
  )
})
