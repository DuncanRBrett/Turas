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


# ------------------------------------------------------------------------------
# Edge cases
# ------------------------------------------------------------------------------

test_that("run_gabor_granger handles small sample (n=30)", {
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")

  data <- generate_gg_data_wide(n = 30)
  config <- make_gg_config()
  config$gabor_granger$calculate_elasticity <- FALSE

  result <- run_gabor_granger(data, config)
  expect_true(!is.null(result$demand_curve))
  expect_true(!is.null(result$optimal_price))
})

test_that("run_gabor_granger handles 100% purchase intent at all prices", {
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")

  # Everyone says yes at every price
  prices <- c(20, 30, 40, 50, 60)
  data <- data.frame(
    price_20 = rep(1, 50),
    price_30 = rep(1, 50),
    price_40 = rep(1, 50),
    price_50 = rep(1, 50),
    price_60 = rep(1, 50)
  )
  config <- make_gg_config(prices)
  config$gabor_granger$calculate_elasticity <- FALSE

  result <- run_gabor_granger(data, config)

  # All intent should be 1.0
  expect_true(all(result$demand_curve$purchase_intent >= 0.99))
  # Optimal price should be highest (since all have 100% intent)
  expect_equal(result$optimal_price$price, max(prices))
})

test_that("run_gabor_granger handles 0% purchase intent at all prices", {
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")

  prices <- c(20, 30, 40, 50, 60)
  data <- data.frame(
    price_20 = rep(0, 50),
    price_30 = rep(0, 50),
    price_40 = rep(0, 50),
    price_50 = rep(0, 50),
    price_60 = rep(0, 50)
  )
  config <- make_gg_config(prices)
  config$gabor_granger$calculate_elasticity <- FALSE

  result <- run_gabor_granger(data, config)

  # All intent should be 0
  expect_true(all(result$demand_curve$purchase_intent <= 0.01))
})

test_that("run_gabor_granger smooth monotonicity enforces decreasing demand", {
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")

  prices <- c(20, 30, 40, 50, 60)
  set.seed(42)
  # Create data where price_40 has HIGHER intent than price_30 (violation)
  data <- data.frame(
    price_20 = rbinom(100, 1, 0.8),
    price_30 = rbinom(100, 1, 0.3),  # lower than expected
    price_40 = rbinom(100, 1, 0.6),  # higher than price_30 (violation)
    price_50 = rbinom(100, 1, 0.2),
    price_60 = rbinom(100, 1, 0.1)
  )
  config <- make_gg_config(prices)
  config$gg_monotonicity_behavior <- "smooth"
  config$gabor_granger$calculate_elasticity <- FALSE

  result <- run_gabor_granger(data, config)
  dc <- result$demand_curve

  # After smoothing, demand should be non-increasing
  diffs <- diff(dc$purchase_intent)
  expect_true(all(diffs <= 0.001))  # Small tolerance for floating point
})

test_that("calculate_price_elasticity returns NULL for single price point", {
  skip_if(!exists("calculate_price_elasticity", mode = "function"),
          "calculate_price_elasticity not available")

  dc <- data.frame(price = 40, purchase_intent = 0.5)
  result <- calculate_price_elasticity(dc)
  expect_null(result)
})

test_that("run_gabor_granger with many price points", {
  skip_if(!exists("run_gabor_granger", mode = "function"),
          "run_gabor_granger not available")

  prices <- seq(10, 100, by = 5)
  data <- generate_gg_data_wide(n = 100, prices = prices)
  config <- make_gg_config(prices)
  config$gabor_granger$calculate_elasticity <- TRUE

  result <- run_gabor_granger(data, config)

  expect_equal(nrow(result$demand_curve), length(prices))
  expect_true(!is.null(result$elasticity))
})
