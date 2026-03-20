# ==============================================================================
# TURAS PRICING MODULE - MAIN PIPELINE TESTS
# ==============================================================================
# Tests for: 00_main.R
# Covers: run_pricing_analysis, run_pricing_analysis_from_config
# ==============================================================================


# Helper: create a complete config + data setup for VW pipeline test
setup_vw_pipeline <- function() {
  data <- generate_vw_data(n = 100)

  tmp_data <- tempfile(fileext = ".csv")
  write.csv(data, tmp_data, row.names = FALSE)

  tmp_output <- tempfile(fileext = ".xlsx")

  config <- list(
    analysis_method = "van_westendorp",
    project_name = "Test Pipeline",
    project_root = tempdir(),
    data_file = tmp_data,
    output_file = tmp_output,
    weight_var = NA,
    dk_codes = numeric(0),
    currency_symbol = "$",
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive",
      validate_monotonicity = FALSE,
      pi_cheap = NULL,
      pi_expensive = NULL
    ),
    gabor_granger = NULL,
    segmentation = list(
      segment_column = NA
    ),
    validation = NULL,
    price_ladder = list(
      n_tiers = 3,
      tier_names = c("Value", "Standard", "Premium"),
      min_gap_pct = 15,
      max_gap_pct = 50,
      round_to = 0.99,
      anchor = "Standard"
    ),
    output = list(
      directory = tempdir(),
      filename_prefix = "test_pipeline"
    ),
    generate_html_report = FALSE,
    generate_simulator = FALSE
  )

  list(config = config, tmp_data = tmp_data, tmp_output = tmp_output)
}


# Helper: create a complete config + data setup for GG pipeline test
setup_gg_pipeline <- function() {
  data <- generate_gg_data_wide(n = 100)

  tmp_data <- tempfile(fileext = ".csv")
  write.csv(data, tmp_data, row.names = FALSE)

  tmp_output <- tempfile(fileext = ".xlsx")

  price_cols <- grep("^price_", names(data), value = TRUE)
  prices <- as.numeric(sub("price_", "", price_cols))

  config <- list(
    analysis_method = "gabor_granger",
    project_name = "Test GG Pipeline",
    project_root = tempdir(),
    data_file = tmp_data,
    output_file = tmp_output,
    weight_var = NA,
    dk_codes = numeric(0),
    currency_symbol = "$",
    unit_cost = NA,
    van_westendorp = NULL,
    gg_monotonicity_behavior = "smooth",
    gabor_granger = list(
      data_format = "wide",
      response_columns = price_cols,
      price_sequence = prices,
      response_coding = "binary",
      revenue_optimization = TRUE,
      calculate_elasticity = TRUE,
      confidence_intervals = FALSE,
      check_monotonicity = FALSE,
      unit_cost = NA,
      market_size = NA,
      price_column = NULL,
      response_column = NULL
    ),
    segmentation = list(
      segment_column = NA
    ),
    validation = NULL,
    output = list(
      directory = tempdir(),
      filename_prefix = "test_gg_pipeline"
    ),
    generate_html_report = FALSE,
    generate_simulator = FALSE
  )

  list(config = config, tmp_data = tmp_data, tmp_output = tmp_output)
}


# ------------------------------------------------------------------------------
# run_pricing_analysis_from_config — VW pipeline
# ------------------------------------------------------------------------------

test_that("run_pricing_analysis_from_config runs VW pipeline end-to-end", {
  setup <- setup_vw_pipeline()
  on.exit({
    unlink(setup$tmp_data)
    unlink(setup$tmp_output)
  }, add = TRUE)

  result <- run_pricing_analysis_from_config(setup$config)

  expect_true(is.list(result))
  expect_equal(result$method, "van_westendorp")
  expect_true(!is.null(result$results))
  expect_true(!is.null(result$results$price_points))
  expect_true(!is.null(result$plots))
  expect_true(file.exists(setup$tmp_output))
})


# ------------------------------------------------------------------------------
# run_pricing_analysis_from_config — GG pipeline
# ------------------------------------------------------------------------------

test_that("run_pricing_analysis_from_config runs GG pipeline end-to-end", {
  setup <- setup_gg_pipeline()
  on.exit({
    unlink(setup$tmp_data)
    unlink(setup$tmp_output)
  }, add = TRUE)

  result <- run_pricing_analysis_from_config(setup$config)

  expect_true(is.list(result))
  expect_equal(result$method, "gabor_granger")
  expect_true(!is.null(result$results$demand_curve))
  expect_true(!is.null(result$results$optimal_price))
  expect_true(file.exists(setup$tmp_output))
})


# ------------------------------------------------------------------------------
# Error handling in pipeline
# ------------------------------------------------------------------------------

test_that("run_pricing_analysis_from_config refuses missing data file", {
  setup <- setup_vw_pipeline()
  on.exit(unlink(setup$tmp_data), add = TRUE)

  setup$config$data_file <- "/nonexistent/data.csv"

  expect_error(run_pricing_analysis_from_config(setup$config),
               "IO_DATA_NOT_FOUND")
})

test_that("run_pricing_analysis_from_config refuses invalid method", {
  setup <- setup_vw_pipeline()
  on.exit(unlink(setup$tmp_data), add = TRUE)

  setup$config$analysis_method <- "bogus_method"

  expect_error(run_pricing_analysis_from_config(setup$config),
               "CFG_INVALID_METHOD")
})

test_that("run_pricing_analysis_from_config refuses missing config data_file", {
  setup <- setup_vw_pipeline()
  on.exit(unlink(setup$tmp_data), add = TRUE)

  setup$config$data_file <- NA

  expect_error(run_pricing_analysis_from_config(setup$config),
               "CFG_MISSING_DATA_FILE")
})


# ------------------------------------------------------------------------------
# Pipeline outputs
# ------------------------------------------------------------------------------

test_that("run_pricing_analysis_from_config returns synthesis when available", {
  setup <- setup_vw_pipeline()
  on.exit({
    unlink(setup$tmp_data)
    unlink(setup$tmp_output)
  }, add = TRUE)

  result <- run_pricing_analysis_from_config(setup$config)

  # Synthesis should be attempted (may or may not succeed depending on data)
  # But the pipeline should complete regardless
  expect_true("synthesis" %in% names(result))
})

test_that("run_pricing_analysis_from_config returns diagnostics", {
  setup <- setup_vw_pipeline()
  on.exit({
    unlink(setup$tmp_data)
    unlink(setup$tmp_output)
  }, add = TRUE)

  result <- run_pricing_analysis_from_config(setup$config)

  expect_true(!is.null(result$diagnostics))
  expect_true(result$diagnostics$n_total > 0)
})
