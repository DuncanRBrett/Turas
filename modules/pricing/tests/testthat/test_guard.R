# ==============================================================================
# TURAS PRICING MODULE - GUARD LAYER TESTS
# ==============================================================================

test_that("pricing_guard_init returns correct structure", {
  skip_if(!exists("pricing_guard_init", mode = "function"),
          "pricing_guard_init not available")

  gs <- pricing_guard_init()

  expect_true(is.list(gs))
  expect_true(!is.null(gs$module))
  expect_true(!is.null(gs$warnings))  # character(0) or list()
  expect_true(is.character(gs$skipped_methods))
  expect_true(is.character(gs$data_quality_issues))
})

test_that("validate_pricing_config refuses non-list config", {
  skip_if(!exists("validate_pricing_config", mode = "function"),
          "validate_pricing_config not available")

  expect_error(validate_pricing_config("not a list"), "CFG_INVALID_TYPE|Invalid Configuration")
})

test_that("validate_pricing_config accepts valid list config", {
  skip_if(!exists("validate_pricing_config", mode = "function"),
          "validate_pricing_config not available")

  config <- list(analysis_method = "van_westendorp")
  result <- validate_pricing_config(config)
  expect_true(result)  # Returns invisible(TRUE)
})

test_that("validate_price_points refuses fewer than 3 points", {
  skip_if(!exists("validate_price_points", mode = "function"),
          "validate_price_points not available")

  expect_error(validate_price_points(c(10, 20)), "CFG_INSUFFICIENT|Insufficient")
})

test_that("validate_price_points accepts valid price points", {
  skip_if(!exists("validate_price_points", mode = "function"),
          "validate_price_points not available")

  result <- validate_price_points(c(10, 20, 30, 40, 50))
  expect_true(result)
})

test_that("validate_price_points refuses non-positive prices", {
  skip_if(!exists("validate_price_points", mode = "function"),
          "validate_price_points not available")

  expect_error(validate_price_points(c(-5, 10, 20, 30)), "CFG_NEGATIVE|Non-Positive")
})

test_that("validate_price_points refuses NA prices", {
  skip_if(!exists("validate_price_points", mode = "function"),
          "validate_price_points not available")

  expect_error(validate_price_points(c(10, NA, 30)), "CFG_INVALID|Invalid")
})

test_that("validate_van_westendorp_data catches missing column names", {
  skip_if(!exists("validate_van_westendorp_data", mode = "function"),
          "validate_van_westendorp_data not available")

  data <- data.frame(x = 1:10, y = 1:10)
  # The function takes (data, vw_columns) where vw_columns is a named list
  vw_columns <- list(too_cheap = "tc", cheap = "ch")  # Missing expensive, too_expensive

  expect_error(
    validate_van_westendorp_data(data, vw_columns),
    "CFG_MISSING_VW|Missing Van Westendorp"
  )
})

test_that("validate_van_westendorp_data catches columns not in data", {
  skip_if(!exists("validate_van_westendorp_data", mode = "function"),
          "validate_van_westendorp_data not available")

  data <- data.frame(a = 1:10, b = 1:10)
  vw_columns <- list(
    too_cheap = "too_cheap",
    cheap = "cheap",
    expensive = "expensive",
    too_expensive = "too_expensive"
  )

  expect_error(
    validate_van_westendorp_data(data, vw_columns),
    "DATA_VW_COLUMNS|Not Found"
  )
})

test_that("validate_van_westendorp_data accepts valid data", {
  skip_if(!exists("validate_van_westendorp_data", mode = "function"),
          "validate_van_westendorp_data not available")

  data <- generate_vw_data(n = 50)
  vw_columns <- list(
    too_cheap = "too_cheap",
    cheap = "cheap",
    expensive = "expensive",
    too_expensive = "too_expensive"
  )

  result <- validate_van_westendorp_data(data, vw_columns)
  expect_true(result)
})

test_that("validate_monadic_data catches missing price column", {
  skip_if(!exists("validate_monadic_data", mode = "function"),
          "validate_monadic_data not available")
  skip_if(!exists("pricing_guard_init", mode = "function"),
          "pricing_guard_init not available")

  data <- data.frame(x = 1:10)
  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "purchase_intent"
    )
  )
  guard <- pricing_guard_init()

  expect_error(
    validate_monadic_data(data, config, guard),
    "DATA_MONADIC|Not Found"
  )
})

test_that("validate_monadic_data returns guard with valid data", {
  skip_if(!exists("validate_monadic_data", mode = "function"),
          "validate_monadic_data not available")
  skip_if(!exists("pricing_guard_init", mode = "function"),
          "pricing_guard_init not available")

  data <- generate_monadic_data(n = 100)
  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "purchase_intent",
      intent_type = "binary"
    )
  )
  guard <- pricing_guard_init()

  result <- validate_monadic_data(data, config, guard)
  expect_true(is.list(result))  # Returns updated guard state
})

test_that("pricing_console_error prints boxed output", {
  skip_if(!exists("pricing_console_error", mode = "function"),
          "pricing_console_error not available")

  output <- capture.output(
    pricing_console_error("TEST_CODE", "Test message", "Fix it")
  )

  expect_true(any(grepl("TURAS", output)))
  expect_true(any(grepl("TEST_CODE", output)))
})

test_that("pricing_determine_status returns PASS for clean state", {
  skip_if(!exists("pricing_determine_status", mode = "function"),
          "pricing_determine_status not available")
  skip_if(!exists("pricing_guard_init", mode = "function"),
          "pricing_guard_init not available")

  gs <- pricing_guard_init()
  result <- pricing_determine_status(
    gs,
    analysis_type = "VW",
    n_respondents = 200,
    optimal_price = 42,
    price_points_valid = 5,
    violation_rate = 0.03
  )

  # TRS uses run_status field
  actual_status <- result$run_status %||% result$status
  expect_equal(actual_status, "PASS")
})

test_that("pricing_determine_status returns PARTIAL for warnings", {
  skip_if(!exists("pricing_determine_status", mode = "function"),
          "pricing_determine_status not available")
  skip_if(!exists("pricing_guard_init", mode = "function"),
          "pricing_guard_init not available")

  gs <- pricing_guard_init()

  # Low sample size triggers PARTIAL
  result <- pricing_determine_status(
    gs,
    analysis_type = "VW",
    n_respondents = 20,
    optimal_price = 42,
    violation_rate = 0.03
  )

  actual_status <- result$run_status %||% result$status
  expect_equal(actual_status, "PARTIAL")
})

test_that("pricing_determine_status returns PARTIAL for high violation rate", {
  skip_if(!exists("pricing_determine_status", mode = "function"),
          "pricing_determine_status not available")
  skip_if(!exists("pricing_guard_init", mode = "function"),
          "pricing_guard_init not available")

  gs <- pricing_guard_init()

  result <- pricing_determine_status(
    gs,
    analysis_type = "VW",
    n_respondents = 200,
    optimal_price = 42,
    violation_rate = 0.25  # 25% violations
  )

  actual_status <- result$run_status %||% result$status
  expect_equal(actual_status, "PARTIAL")
})

test_that("pricing_determine_status returns PARTIAL when no optimal price", {
  skip_if(!exists("pricing_determine_status", mode = "function"),
          "pricing_determine_status not available")
  skip_if(!exists("pricing_guard_init", mode = "function"),
          "pricing_guard_init not available")

  gs <- pricing_guard_init()

  result <- pricing_determine_status(
    gs,
    analysis_type = "VW",
    n_respondents = 200,
    optimal_price = NULL,
    violation_rate = 0.03
  )

  actual_status <- result$run_status %||% result$status
  expect_equal(actual_status, "PARTIAL")
})

test_that("guard_record_price_issue tracks issues", {
  skip_if(!exists("guard_record_price_issue", mode = "function"),
          "guard_record_price_issue not available")
  skip_if(!exists("pricing_guard_init", mode = "function"),
          "pricing_guard_init not available")

  gs <- pricing_guard_init()
  gs <- guard_record_price_issue(gs, price = 30, issue = "Small sample", sample_size = 15)

  expect_true(length(gs$price_point_issues) == 1)
  expect_true(length(gs$warnings) > 0)
})
