# ==============================================================================
# TURAS PRICING MODULE - VAN WESTENDORP TESTS
# ==============================================================================

# Helper: build VW config with proper column name mappings
make_vw_config <- function(include_nms = FALSE) {
  config <- list(
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive"
    ),
    currency_symbol = "$"
  )
  if (include_nms) {
    config$van_westendorp$nms_trial <- "purchase_intent"
  }
  config
}

test_that("validate_vw_data returns quality assessment", {
  skip_if(!exists("validate_vw_data", mode = "function"),
          "validate_vw_data not available")

  data <- generate_vw_data(n = 100)
  config <- make_vw_config()

  result <- validate_vw_data(data, config, verbose = FALSE)

  expect_true(is.list(result))
  expect_true(!is.null(result$quality_score))
  expect_true(result$quality_score >= 0 && result$quality_score <= 100)
  expect_true(!is.null(result$n_valid))
  expect_true(result$is_valid)
})

test_that("validate_vw_data catches non-numeric columns", {
  skip_if(!exists("validate_vw_data", mode = "function"),
          "validate_vw_data not available")

  data <- data.frame(
    too_cheap = letters[1:20],
    cheap = letters[1:20],
    expensive = letters[1:20],
    too_expensive = letters[1:20],
    stringsAsFactors = FALSE
  )
  config <- make_vw_config()

  result <- validate_vw_data(data, config, verbose = FALSE)
  expect_false(result$is_valid)
})

test_that("validate_vw_data detects missing config mappings", {
  skip_if(!exists("validate_vw_data", mode = "function"),
          "validate_vw_data not available")

  data <- generate_vw_data(n = 50)
  # Config with missing column mappings
  config <- list(
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap"
      # Missing col_expensive and col_too_expensive
    )
  )

  result <- validate_vw_data(data, config, verbose = FALSE)
  expect_false(result$is_valid)
  expect_false(result$checks$config_complete)
})

test_that("run_van_westendorp produces valid price points", {
  skip_if(!exists("run_van_westendorp", mode = "function"),
          "run_van_westendorp not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  data <- generate_vw_data(n = 200)
  config <- make_vw_config()

  result <- run_van_westendorp(data, config)

  expect_true(is.list(result))
  expect_true(!is.null(result$price_points))

  pp <- result$price_points
  expect_true(!is.null(pp$PMC))
  expect_true(!is.null(pp$OPP))
  expect_true(!is.null(pp$IDP))
  expect_true(!is.null(pp$PME))

  # PMC < PME is the general expectation
  expect_true(pp$PMC < pp$PME)
})

test_that("run_van_westendorp returns acceptable range", {
  skip_if(!exists("run_van_westendorp", mode = "function"),
          "run_van_westendorp not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  data <- generate_vw_data(n = 200)
  config <- make_vw_config()

  result <- run_van_westendorp(data, config)

  expect_true(!is.null(result$acceptable_range))
  ar <- result$acceptable_range
  expect_true(ar$lower < ar$upper)
  expect_true(ar$width > 0)
})

test_that("run_van_westendorp returns curves data", {
  skip_if(!exists("run_van_westendorp", mode = "function"),
          "run_van_westendorp not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  data <- generate_vw_data(n = 200)
  config <- make_vw_config()

  result <- run_van_westendorp(data, config)

  expect_true(!is.null(result$curves))
  expect_true(is.data.frame(result$curves))
  expect_true("price" %in% names(result$curves))
  expect_true(nrow(result$curves) > 0)
})

test_that("run_van_westendorp returns diagnostics", {
  skip_if(!exists("run_van_westendorp", mode = "function"),
          "run_van_westendorp not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  data <- generate_vw_data(n = 200)
  config <- make_vw_config()

  result <- run_van_westendorp(data, config)

  diag <- result$diagnostics
  expect_true(!is.null(diag))
  expect_true(diag$n_total > 0)
  expect_true(diag$n_valid > 0)
})

test_that("run_van_westendorp handles NMS columns when present", {
  skip_if(!exists("run_van_westendorp", mode = "function"),
          "run_van_westendorp not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  data <- generate_vw_data(n = 200, include_nms = TRUE)
  config <- make_vw_config(include_nms = TRUE)

  result <- run_van_westendorp(data, config)
  expect_true(is.list(result))
})

test_that("bootstrap_vw_confidence returns CIs", {
  skip_if(!exists("bootstrap_vw_confidence", mode = "function"),
          "bootstrap_vw_confidence not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  data <- generate_vw_data(n = 200)

  result <- bootstrap_vw_confidence(
    too_cheap = data$too_cheap,
    cheap = data$cheap,
    expensive = data$expensive,
    too_expensive = data$too_expensive,
    iterations = 50,
    level = 0.95
  )

  expect_true(is.data.frame(result) || is.list(result))
})


# ------------------------------------------------------------------------------
# Edge cases
# ------------------------------------------------------------------------------

test_that("run_van_westendorp handles small sample (n=30)", {
  skip_if(!exists("run_van_westendorp", mode = "function"),
          "run_van_westendorp not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  data <- generate_vw_data(n = 30)
  config <- make_vw_config()

  result <- run_van_westendorp(data, config)
  expect_true(!is.null(result$price_points))
})

test_that("run_van_westendorp handles data with many NAs", {
  skip_if(!exists("run_van_westendorp", mode = "function"),
          "run_van_westendorp not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  data <- generate_vw_data(n = 200)
  # Set 30% of cheap values to NA
  data$cheap[sample(200, 60)] <- NA

  config <- make_vw_config()

  result <- run_van_westendorp(data, config)
  expect_true(result$diagnostics$n_valid < 200)
  expect_true(!is.null(result$price_points))
})

test_that("run_van_westendorp price points are ordered correctly", {
  skip_if(!exists("run_van_westendorp", mode = "function"),
          "run_van_westendorp not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  data <- generate_vw_data(n = 300)
  config <- make_vw_config()

  result <- run_van_westendorp(data, config)
  pp <- result$price_points

  # Expected ordering: PMC <= OPP <= IDP <= PME
  expect_true(pp$PMC <= pp$OPP + 0.01)
  expect_true(pp$OPP <= pp$IDP + 0.01)
  expect_true(pp$IDP <= pp$PME + 0.01)
})

test_that("validate_vw_data handles all-identical price responses", {
  skip_if(!exists("validate_vw_data", mode = "function"),
          "validate_vw_data not available")

  data <- data.frame(
    too_cheap = rep(50, 50),
    cheap = rep(50, 50),
    expensive = rep(50, 50),
    too_expensive = rep(50, 50),
    stringsAsFactors = FALSE
  )
  config <- make_vw_config()

  result <- validate_vw_data(data, config, verbose = FALSE)
  # Should detect the problem (zero variance)
  expect_true(is.list(result))
})

test_that("validate_vw_data handles extreme price ranges", {
  skip_if(!exists("validate_vw_data", mode = "function"),
          "validate_vw_data not available")

  set.seed(123)
  data <- data.frame(
    too_cheap = runif(50, 0.01, 0.10),
    cheap = runif(50, 0.10, 1.00),
    expensive = runif(50, 100, 1000),
    too_expensive = runif(50, 1000, 10000),
    stringsAsFactors = FALSE
  )
  config <- make_vw_config()

  result <- validate_vw_data(data, config, verbose = FALSE)
  expect_true(is.list(result))
})
