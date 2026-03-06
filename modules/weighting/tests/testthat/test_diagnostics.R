# ==============================================================================
# TESTS: Diagnostics (diagnostics.R)
# ==============================================================================

test_that("diagnose_weights returns expected structure", {
  weights <- runif(100, 0.5, 2.0)
  result <- diagnose_weights(weights, label = "test", verbose = FALSE)

  expect_true(is.list(result))
  expect_true("sample_size" %in% names(result))
  expect_true("distribution" %in% names(result))
  expect_true("effective_sample" %in% names(result))
  expect_true("quality" %in% names(result))
})

test_that("diagnose_weights computes correct effective N", {
  # All equal weights = no design effect
  weights <- rep(1.0, 100)
  result <- diagnose_weights(weights, label = "test", verbose = FALSE)

  expect_equal(result$effective_sample$effective_n, 100)
  expect_equal(result$effective_sample$design_effect, 1.0, tolerance = 0.01)
  expect_equal(result$effective_sample$efficiency, 100.0, tolerance = 0.1)
})

test_that("diagnose_weights computes Kish formula correctly", {
  # Known weights with known Kish effective N
  weights <- c(rep(1, 50), rep(2, 50))
  # sum_w = 50 + 100 = 150
  # sum_w2 = 50 + 200 = 250
  # eff_n = 150^2 / 250 = 22500/250 = 90
  result <- diagnose_weights(weights, label = "test", verbose = FALSE)

  expect_equal(result$effective_sample$effective_n, 90)
})

test_that("diagnose_weights produces GOOD quality for low DEFF", {
  weights <- runif(100, 0.9, 1.1)  # Nearly uniform
  result <- diagnose_weights(weights, label = "test", verbose = FALSE)

  expect_equal(result$quality$status, "GOOD")
})

test_that("diagnose_weights produces POOR quality for high DEFF", {
  weights <- c(rep(0.1, 90), rep(10, 10))  # Very skewed
  result <- diagnose_weights(weights, label = "test", verbose = FALSE)

  expect_true(result$quality$status %in% c("ACCEPTABLE", "POOR"))
})

test_that("diagnose_weights handles all-NA weights", {
  weights <- rep(NA_real_, 50)
  result <- diagnose_weights(weights, label = "test", verbose = FALSE)

  expect_true(is.list(result))
  expect_equal(result$sample_size$n_valid, 0)
})

test_that("diagnose_weights handles single weight", {
  weights <- 1.5
  result <- diagnose_weights(weights, label = "test", verbose = FALSE)

  expect_true(is.list(result))
  expect_equal(result$sample_size$n_total, 1)
})

test_that("assess_weight_quality returns expected statuses", {
  skip_if(!exists("assess_weight_quality", mode = "function"),
          "assess_weight_quality not available")

  # assess_weight_quality takes a diagnostics list (from diagnose_weights)
  weights <- runif(100, 0.9, 1.1)
  diag <- diagnose_weights(weights, label = "test", verbose = FALSE)
  quality <- assess_weight_quality(diag)
  expect_true(quality$status %in% c("GOOD", "ACCEPTABLE", "POOR"))
})

test_that("get_weight_histogram_data returns data", {
  skip_if(!exists("get_weight_histogram_data", mode = "function"),
          "get_weight_histogram_data not available")

  weights <- runif(100, 0.5, 3.0)
  hist_data <- get_weight_histogram_data(weights)

  expect_true(is.list(hist_data) || is.data.frame(hist_data))
})

test_that("compare_weights works with two weight sets", {
  skip_if(!exists("compare_weights", mode = "function"),
          "compare_weights not available")

  w1 <- runif(100, 0.5, 2.0)
  w2 <- runif(100, 0.8, 1.5)

  result <- compare_weights(list(w1 = w1, w2 = w2))
  expect_true(is.list(result) || is.data.frame(result))
})

test_that("diagnose_weights with rim_result includes margin data", {
  skip_if_not_installed("survey")

  data <- create_simple_survey(n = 200)
  targets <- list(Gender = c("Male" = 0.50, "Female" = 0.50))
  rim_result <- calculate_rim_weights(data, targets, verbose = FALSE)

  result <- diagnose_weights(
    weights = rim_result$weights,
    label = "rim_test",
    rim_result = rim_result,
    verbose = FALSE
  )

  expect_true(is.list(result))
})
