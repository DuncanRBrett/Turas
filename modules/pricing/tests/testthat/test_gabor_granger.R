# ==============================================================================
# TURAS PRICING MODULE - GABOR-GRANGER TESTS
# ==============================================================================

# Helper: build a correct GG config for wide format data
make_gg_config <- function(prices = c(20, 30, 40, 50, 60, 70, 80)) {
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

test_that("run_gabor_granger produces valid demand curve from wide data", {
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")

  data <- generate_gg_data_wide(n = 200)
  config <- make_gg_config()

  result <- run_gabor_granger(data, config)

  expect_true(is.list(result))
  expect_true(!is.null(result$demand_curve))
  expect_true(is.data.frame(result$demand_curve))
  expect_true("price" %in% names(result$demand_curve))
  expect_true("purchase_intent" %in% names(result$demand_curve))

  # Intent should generally decrease with price
  dc <- result$demand_curve
  expect_true(dc$purchase_intent[1] >= dc$purchase_intent[nrow(dc)])
})

test_that("run_gabor_granger finds valid optimal price", {
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")

  prices <- c(20, 30, 40, 50, 60, 70, 80)
  data <- generate_gg_data_wide(n = 200, prices = prices)
  config <- make_gg_config(prices)

  result <- run_gabor_granger(data, config)

  expect_true(!is.null(result$optimal_price))
  op <- result$optimal_price
  expect_true(op$price >= min(prices) && op$price <= max(prices))
  expect_true(op$purchase_intent > 0 && op$purchase_intent <= 1)
  expect_true(op$revenue_index > 0)
})

test_that("run_gabor_granger returns revenue curve", {
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")

  data <- generate_gg_data_wide(n = 200)
  config <- make_gg_config()

  result <- run_gabor_granger(data, config)

  expect_true(!is.null(result$revenue_curve))
  rc <- result$revenue_curve
  expect_true(is.data.frame(rc))
  expect_true("revenue_index" %in% names(rc))
  expect_true(all(rc$revenue_index >= 0))
})

test_that("run_gabor_granger computes elasticity", {
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")

  data <- generate_gg_data_wide(n = 200)
  config <- make_gg_config()

  result <- run_gabor_granger(data, config)

  expect_true(!is.null(result$elasticity))
  el <- result$elasticity
  expect_true(is.data.frame(el))
  expect_true("arc_elasticity" %in% names(el))
  expect_true("elasticity_type" %in% names(el))
  expect_true(all(el$elasticity_type %in% c("elastic", "inelastic", "unitary", "Elastic", "Inelastic", "Unitary")))
})

test_that("run_gabor_granger handles profit optimization with unit_cost", {
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")

  data <- generate_gg_data_wide(n = 200)
  config <- make_gg_config()
  config$unit_cost <- 15

  result <- run_gabor_granger(data, config)

  expect_true(!is.null(result$optimal_price_profit) ||
              !is.null(result$revenue_curve$profit_index))
})

test_that("run_gabor_granger returns diagnostics", {
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")

  data <- generate_gg_data_wide(n = 200)
  config <- make_gg_config()

  result <- run_gabor_granger(data, config)

  diag <- result$diagnostics
  expect_true(!is.null(diag))
  expect_true(diag$n_respondents > 0)
  expect_true(diag$n_price_points > 0)
})

test_that("calculate_demand_curve produces valid output", {
  skip_if(!exists("calculate_demand_curve", mode = "function"),
          "calculate_demand_curve not available")

  set.seed(42)
  long_data <- data.frame(
    respondent_id = rep(1:50, each = 5),
    price = rep(c(10, 20, 30, 40, 50), 50),
    response = c(
      rbinom(50, 1, 0.9),
      rbinom(50, 1, 0.7),
      rbinom(50, 1, 0.5),
      rbinom(50, 1, 0.3),
      rbinom(50, 1, 0.1)
    ),
    weight = 1
  )

  result <- calculate_demand_curve(long_data)

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 5)
  expect_true(all(result$purchase_intent >= 0 & result$purchase_intent <= 1))
})

test_that("calculate_price_elasticity returns valid classifications", {
  skip_if(!exists("calculate_price_elasticity", mode = "function"),
          "calculate_price_elasticity not available")

  demand_curve <- data.frame(
    price = c(10, 20, 30, 40, 50),
    purchase_intent = c(0.9, 0.7, 0.5, 0.3, 0.1)
  )

  result <- calculate_price_elasticity(demand_curve)

  expect_true(is.data.frame(result))
  expect_true(nrow(result) > 0)
  expect_true(all(result$elasticity_type %in% c("elastic", "inelastic", "unitary", "Elastic", "Inelastic", "Unitary")))
})

test_that("check_gg_monotonicity detects violations", {
  skip_if(!exists("check_gg_monotonicity", mode = "function"),
          "check_gg_monotonicity not available")

  # Data with clear monotonicity violations
  set.seed(42)
  long_data <- data.frame(
    respondent_id = rep(1:20, each = 3),
    price = rep(c(10, 20, 30), 20),
    response = c(
      # Some respondents say yes at high price but no at low price
      rep(c(0, 1, 0), 10),
      rep(c(1, 1, 0), 10)
    ),
    weight = 1
  )

  result <- check_gg_monotonicity(long_data)

  expect_true(is.list(result))
  expect_true(!is.null(result$violations) || !is.null(result$violation_rate))
})
