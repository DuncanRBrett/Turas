# ==============================================================================
# TURAS PRICING MODULE - INTEGRATION TESTS
# ==============================================================================
# End-to-end workflow tests combining multiple analysis steps

# Shared config helpers
make_vw_config_int <- function() {
  list(
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive"
    ),
    currency_symbol = "$"
  )
}

make_gg_config_int <- function(prices = c(20, 30, 40, 50, 60, 70, 80)) {
  list(
    gabor_granger = list(
      data_format = "wide",
      price_sequence = prices,
      response_columns = paste0("price_", prices),
      response_coding = "binary",
      revenue_optimization = TRUE,
      calculate_elasticity = TRUE,
      check_monotonicity = TRUE
    ),
    gg_monotonicity_behavior = "none",
    unit_cost = NA,
    weight_var = NA,
    currency_symbol = "$"
  )
}

test_that("VW end-to-end: data -> analysis -> output structure", {
  skip_if(!exists("run_van_westendorp", mode = "function"),
          "run_van_westendorp not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  data <- generate_vw_data(n = 250)
  config <- make_vw_config_int()

  result <- run_van_westendorp(data, config)

  expect_true(!is.null(result$price_points))
  expect_true(!is.null(result$acceptable_range))
  expect_true(!is.null(result$curves))
  expect_true(!is.null(result$diagnostics))

  expect_true(result$price_points$OPP >= result$price_points$PMC)
  expect_true(result$price_points$PME >= result$price_points$IDP)
})

test_that("GG end-to-end: data -> analysis -> optimal price", {
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")

  prices <- c(20, 30, 40, 50, 60, 70, 80)
  data <- generate_gg_data_wide(n = 250, prices = prices)
  config <- make_gg_config_int(prices)

  result <- run_gabor_granger(data, config)

  expect_true(!is.null(result$demand_curve))
  expect_true(!is.null(result$revenue_curve))
  expect_true(!is.null(result$optimal_price))
  expect_true(!is.null(result$elasticity))
  expect_true(!is.null(result$diagnostics))

  rc <- result$revenue_curve
  expect_true(max(rc$revenue_index) > min(rc$revenue_index))
})

test_that("Monadic end-to-end: data -> model -> demand curve -> optimal", {
  skip_if(!exists("run_monadic_analysis", mode = "function"),
          "run_monadic_analysis not available")

  data <- generate_monadic_data(n = 300, prices = c(15, 25, 35, 45, 55, 65))
  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "purchase_intent",
      intent_type = "binary",
      model_type = "logistic",
      prediction_points = 40
    ),
    currency_symbol = "$"
  )

  result <- run_monadic_analysis(data, config)

  expect_true(!is.null(result$demand_curve))
  expect_true(!is.null(result$optimal_price))
  expect_true(!is.null(result$model_summary))
  expect_true(!is.null(result$observed_data))

  dc <- result$demand_curve
  expect_true(all(dc$predicted_intent >= 0 & dc$predicted_intent <= 1))
  expect_true(result$optimal_price$price >= 15 && result$optimal_price$price <= 65)
})

test_that("VW -> Price Ladder pipeline works", {
  skip_if(!exists("run_van_westendorp", mode = "function"),
          "run_van_westendorp not available")
  skip_if(!exists("build_price_ladder", mode = "function"),
          "build_price_ladder not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  data <- generate_vw_data(n = 250)
  config <- make_vw_config_int()
  config$price_ladder <- list(
    n_tiers = 3,
    tier_names = "Good;Better;Best",
    round_to = "0.99"
  )

  vw_result <- run_van_westendorp(data, config)
  ladder_result <- build_price_ladder(vw_result, gg_results = NULL, config = config)

  expect_true(!is.null(ladder_result$tier_table))
  tt <- ladder_result$tier_table
  expect_equal(nrow(tt), 3)
  expect_true(min(tt$price) >= vw_result$price_points$PMC * 0.5)
  expect_true(max(tt$price) <= vw_result$price_points$PME * 1.5)
})

test_that("VW + GG -> Synthesis pipeline works", {
  skip_if(!exists("run_van_westendorp", mode = "function"),
          "run_van_westendorp not available")
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")
  skip_if(!exists("synthesize_recommendation", mode = "function"),
          "synthesize_recommendation not available")
  skip_if(!requireNamespace("pricesensitivitymeter", quietly = TRUE),
          "pricesensitivitymeter package not available")

  vw_data <- generate_vw_data(n = 250)
  vw_config <- make_vw_config_int()
  vw_result <- run_van_westendorp(vw_data, vw_config)

  prices <- c(20, 30, 40, 50, 60, 70, 80)
  gg_data <- generate_gg_data_wide(n = 250, prices = prices)
  gg_config <- make_gg_config_int(prices)
  gg_result <- run_gabor_granger(gg_data, gg_config)

  synth <- synthesize_recommendation(
    vw_results = vw_result,
    gg_results = gg_result,
    config = list(currency_symbol = "$")
  )

  expect_true(!is.null(synth$recommendation))
  expect_true(!is.null(synth$evidence_table))
  expect_true(synth$recommendation$price > 0)
})

test_that("Monadic -> Synthesis pipeline works", {
  skip_if(!exists("run_monadic_analysis", mode = "function"),
          "run_monadic_analysis not available")
  skip_if(!exists("synthesize_recommendation", mode = "function"),
          "synthesize_recommendation not available")

  data <- generate_monadic_data(n = 300)
  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "purchase_intent",
      intent_type = "binary",
      model_type = "logistic"
    ),
    currency_symbol = "$"
  )

  monadic_result <- run_monadic_analysis(data, config)

  synth <- synthesize_recommendation(
    vw_results = NULL,
    gg_results = NULL,
    monadic_results = monadic_result,
    config = list(currency_symbol = "$")
  )

  expect_true(!is.null(synth$recommendation))
  expect_true(synth$recommendation$price > 0)
})

test_that("HTML data transformer handles monadic results", {
  skip_if(!exists("transform_pricing_for_html", mode = "function"),
          "transform_pricing_for_html not available")
  skip_if(!exists("run_monadic_analysis", mode = "function"),
          "run_monadic_analysis not available")

  data <- generate_monadic_data(n = 200)
  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "purchase_intent",
      intent_type = "binary",
      model_type = "logistic"
    ),
    currency_symbol = "$",
    brand_colour = "#1e3a5f"
  )

  monadic_result <- run_monadic_analysis(data, config)

  pricing_results <- list(
    method = "monadic",
    results = monadic_result,
    config = config
  )

  html_data <- transform_pricing_for_html(pricing_results, config)

  expect_true(!is.null(html_data$meta))
  expect_true(!is.null(html_data$monadic))
  expect_equal(html_data$meta$method, "monadic")
})

test_that("Simulator data extraction works for monadic", {
  skip_if(!exists("extract_demand_data", mode = "function"),
          "extract_demand_data not available")
  skip_if(!exists("run_monadic_analysis", mode = "function"),
          "run_monadic_analysis not available")

  data <- generate_monadic_data(n = 200)
  config <- list(
    monadic = list(
      price_column = "price_shown",
      intent_column = "purchase_intent",
      intent_type = "binary",
      model_type = "logistic"
    ),
    currency_symbol = "$"
  )

  monadic_result <- run_monadic_analysis(data, config)
  demand <- extract_demand_data(monadic_result, "monadic")

  expect_true(!is.null(demand))
  expect_true(!is.null(demand$price_range))
  expect_true(!is.null(demand$demand_curve))
  expect_true(length(demand$price_range) == length(demand$demand_curve))
})
