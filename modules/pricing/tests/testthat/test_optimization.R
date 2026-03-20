# ==============================================================================
# TURAS PRICING MODULE - PRICE-VOLUME OPTIMISATION TESTS
# ==============================================================================
# Tests for: 09_price_volume_optimisation.R
# Covers: find_constrained_optimal, find_price_for_volume,
#         find_price_for_revenue, find_price_for_profit,
#         explore_price_tradeoffs, create_demand_interpolator,
#         golden_section_search, find_continuous_optimal,
#         analyze_price_sensitivity, find_pareto_frontier,
#         optimize_with_scenarios
# ==============================================================================

# Helper: create a standard demand curve for testing
make_demand_curve <- function(unit_cost = 15) {
  prices <- seq(20, 80, by = 5)
  # Linearly declining intent
  intent <- 0.9 - (prices - 20) * (0.8 / 60)
  intent <- pmax(0.05, intent)  # floor at 5%

  dc <- data.frame(
    price = prices,
    purchase_intent = intent,
    revenue_index = prices * intent,
    stringsAsFactors = FALSE
  )
  dc$margin <- dc$price - unit_cost
  dc$profit_index <- dc$margin * dc$purchase_intent
  dc
}


# ------------------------------------------------------------------------------
# golden_section_search
# ------------------------------------------------------------------------------

test_that("golden_section_search finds minimum of simple function", {
  # Minimum of (x-3)^2 is at x=3
  f <- function(x) (x - 3)^2

  result <- golden_section_search(f, a = 0, b = 10, tol = 0.001)

  expect_true(abs(result$x - 3) < 0.01)
  expect_true(result$fx < 0.001)
  expect_true(result$iterations > 0)
})

test_that("golden_section_search finds minimum of concave revenue function", {
  # Revenue = p * (1 - p/100), max at p=50
  f <- function(p) -(p * (1 - p / 100))

  result <- golden_section_search(f, a = 0, b = 100, tol = 0.01)

  expect_true(abs(result$x - 50) < 0.5)
})


# ------------------------------------------------------------------------------
# create_demand_interpolator
# ------------------------------------------------------------------------------

test_that("create_demand_interpolator returns valid function", {
  prices <- c(20, 30, 40, 50, 60)
  intent <- c(0.9, 0.7, 0.5, 0.3, 0.1)

  func <- create_demand_interpolator(prices, intent)

  expect_true(is.function(func))

  # Test at known points
  expect_true(abs(func(20) - 0.9) < 0.1)
  expect_true(abs(func(60) - 0.1) < 0.1)

  # Test interpolation
  mid_val <- func(40)
  expect_true(mid_val > 0 && mid_val < 1)
})

test_that("create_demand_interpolator bounds output to [0, 1]", {
  prices <- c(20, 40, 60)
  intent <- c(0.95, 0.5, 0.05)

  func <- create_demand_interpolator(prices, intent)

  # Test extrapolation bounds
  expect_true(func(10) >= 0 && func(10) <= 1)
  expect_true(func(80) >= 0 && func(80) <= 1)
})

test_that("create_demand_interpolator enforces monotonicity", {
  prices <- c(20, 30, 40, 50, 60)
  intent <- c(0.8, 0.85, 0.5, 0.3, 0.1)  # Non-monotone at 30

  func <- create_demand_interpolator(prices, intent)

  # Should be monotone decreasing after isotonic correction
  vals <- sapply(seq(20, 60, by = 5), func)
  expect_true(all(diff(vals) <= 0.01))  # Small tolerance for spline
})


# ------------------------------------------------------------------------------
# find_constrained_optimal
# ------------------------------------------------------------------------------

test_that("find_constrained_optimal finds revenue-maximizing price", {
  dc <- make_demand_curve()

  result <- find_constrained_optimal(dc, objective = "revenue")

  expect_s3_class(result, "data.frame")
  expect_true(!is.na(result$price))
  expect_true(result$feasible)
  # Revenue-max should be in the middle range
  expect_true(result$price >= 25 && result$price <= 70)
})

test_that("find_constrained_optimal finds profit-maximizing price", {
  dc <- make_demand_curve(unit_cost = 15)

  result <- find_constrained_optimal(dc, objective = "profit")

  expect_true(!is.na(result$price))
  # Profit-max typically higher than revenue-max
  rev_result <- find_constrained_optimal(dc, objective = "revenue")
  expect_true(result$price >= rev_result$price - 5)
})

test_that("find_constrained_optimal applies price range constraint", {
  dc <- make_demand_curve()

  result <- find_constrained_optimal(
    dc,
    objective = "revenue",
    constraints = list(min_price = 40, max_price = 60)
  )

  expect_true(result$price >= 40)
  expect_true(result$price <= 60)
})

test_that("find_constrained_optimal applies volume constraint", {
  dc <- make_demand_curve()
  market_size <- 10000

  result <- find_constrained_optimal(
    dc,
    objective = "revenue",
    constraints = list(min_volume = 5000),
    market_size = market_size
  )

  if (!is.na(result$price)) {
    # Volume should meet constraint
    actual_volume <- result$purchase_intent * market_size
    expect_true(actual_volume >= 5000)
  }
})

test_that("find_constrained_optimal returns NA when no feasible solution", {
  dc <- make_demand_curve()

  # Impossible constraint: min volume of 100% of huge market
  result <- find_constrained_optimal(
    dc,
    objective = "revenue",
    constraints = list(min_volume = 1000000),
    market_size = 1000000
  )

  expect_true(is.na(result$price))
  expect_false(result$feasible)
})


# ------------------------------------------------------------------------------
# find_price_for_volume
# ------------------------------------------------------------------------------

test_that("find_price_for_volume finds price achieving target", {
  dc <- make_demand_curve()
  market_size <- 10000

  result <- find_price_for_volume(dc, target_volume = 5000, market_size = market_size)

  expect_s3_class(result, "data.frame")
  expect_true("target_met" %in% names(result))
})

test_that("find_price_for_volume returns closest when target unachievable", {
  dc <- make_demand_curve()

  result <- find_price_for_volume(dc, target_volume = 100000, market_size = 10000)

  expect_false(result$target_met)
})


# ------------------------------------------------------------------------------
# find_price_for_revenue
# ------------------------------------------------------------------------------

test_that("find_price_for_revenue finds closest price to target revenue", {
  dc <- make_demand_curve()

  # Find a reasonable target (roughly middle of revenue curve)
  mid_rev <- median(dc$revenue_index)
  result <- find_price_for_revenue(dc, target_revenue = mid_rev)

  expect_s3_class(result, "data.frame")
  expect_true("target_revenue" %in% names(result))
  expect_true("actual_revenue" %in% names(result))
  expect_true("revenue_gap" %in% names(result))
})

test_that("find_price_for_revenue handles market_size scaling", {
  dc <- make_demand_curve()
  market_size <- 10000

  target <- median(dc$revenue_index) * market_size
  result <- find_price_for_revenue(dc, target_revenue = target, market_size = market_size)

  expect_true(abs(result$actual_revenue - target) < target * 0.5)
})


# ------------------------------------------------------------------------------
# find_price_for_profit
# ------------------------------------------------------------------------------

test_that("find_price_for_profit finds price for target profit", {
  dc <- make_demand_curve(unit_cost = 15)

  mid_profit <- median(dc$profit_index)
  result <- find_price_for_profit(dc, target_profit = mid_profit)

  expect_s3_class(result, "data.frame")
  expect_true("target_profit" %in% names(result))
  expect_true("profit_gap" %in% names(result))
})

test_that("find_price_for_profit refuses without profit_index", {
  dc <- data.frame(
    price = c(20, 30, 40, 50),
    purchase_intent = c(0.8, 0.6, 0.4, 0.2),
    revenue_index = c(16, 18, 16, 10)
  )

  expect_error(find_price_for_profit(dc, target_profit = 5),
               "CFG_MISSING_UNIT_COST")
})


# ------------------------------------------------------------------------------
# explore_price_tradeoffs
# ------------------------------------------------------------------------------

test_that("explore_price_tradeoffs returns grid with key columns", {
  dc <- make_demand_curve(unit_cost = 15)

  result <- explore_price_tradeoffs(dc, market_size = 10000)

  expect_s3_class(result, "data.frame")
  expect_true("price" %in% names(result))
  expect_true("purchase_intent" %in% names(result))
  expect_true("volume" %in% names(result))
  expect_true("revenue_total" %in% names(result))
  expect_true("profit_total" %in% names(result))
})

test_that("explore_price_tradeoffs subsets by price_range", {
  dc <- make_demand_curve()

  result <- explore_price_tradeoffs(dc, price_range = c(30, 50))

  expect_true(min(result$price) >= 30)
  expect_true(max(result$price) <= 50)
})

test_that("explore_price_tradeoffs works without market_size", {
  dc <- make_demand_curve()

  result <- explore_price_tradeoffs(dc)

  expect_s3_class(result, "data.frame")
  expect_false("volume" %in% names(result))
})


# ------------------------------------------------------------------------------
# find_continuous_optimal
# ------------------------------------------------------------------------------

test_that("find_continuous_optimal finds revenue optimum", {
  dc <- make_demand_curve()

  result <- find_continuous_optimal(dc, objective = "revenue")

  expect_true(is.list(result))
  expect_true(!is.null(result$price))
  expect_true(result$purchase_intent > 0 && result$purchase_intent <= 1)
  expect_equal(result$objective, "revenue")
  expect_true(result$iterations > 0)
  expect_equal(result$method, "golden_section_continuous")
})

test_that("find_continuous_optimal finds profit optimum with unit_cost", {
  dc <- make_demand_curve(unit_cost = 15)

  result <- find_continuous_optimal(dc, objective = "profit", unit_cost = 15)

  expect_true(!is.null(result$price))
  expect_equal(result$objective, "profit")
  expect_true(result$profit_index > 0)
})

test_that("find_continuous_optimal respects price_bounds", {
  dc <- make_demand_curve()

  result <- find_continuous_optimal(dc, objective = "revenue",
                                     price_bounds = c(30, 50))

  expect_true(result$price >= 29.5 && result$price <= 50.5)
})

test_that("find_continuous_optimal returns NULL with insufficient data", {
  dc <- data.frame(
    price = c(30, 40),
    purchase_intent = c(0.8, 0.6)
  )

  result <- find_continuous_optimal(dc, objective = "revenue")

  expect_null(result)
})

test_that("find_continuous_optimal adds volume with market_size", {
  dc <- make_demand_curve()

  result <- find_continuous_optimal(dc, objective = "revenue", market_size = 10000)

  expect_true(!is.na(result$volume))
  expect_true(result$volume > 0 && result$volume <= 10000)
})


# ------------------------------------------------------------------------------
# analyze_price_sensitivity
# ------------------------------------------------------------------------------

test_that("analyze_price_sensitivity shows revenue loss from deviations", {
  dc <- make_demand_curve()
  optimal_price <- dc$price[which.max(dc$revenue_index)]

  result <- analyze_price_sensitivity(dc, optimal_price)

  expect_s3_class(result, "data.frame")
  expect_true("deviation_pct" %in% names(result))
  expect_true("revenue_pct_of_optimal" %in% names(result))

  # At 0% deviation, should be ~100% of optimal
  zero_dev <- result[result$deviation_pct == 0, ]
  expect_true(abs(zero_dev$revenue_pct_of_optimal - 100) < 5)
})

test_that("analyze_price_sensitivity includes profit when unit_cost provided", {
  dc <- make_demand_curve(unit_cost = 15)
  optimal_price <- dc$price[which.max(dc$profit_index)]

  result <- analyze_price_sensitivity(dc, optimal_price, unit_cost = 15)

  expect_true("profit_index" %in% names(result))
  expect_true("profit_pct_of_optimal" %in% names(result))
})

test_that("analyze_price_sensitivity uses custom deviations", {
  dc <- make_demand_curve()
  optimal_price <- dc$price[which.max(dc$revenue_index)]

  result <- analyze_price_sensitivity(dc, optimal_price,
                                       deviation_pct = c(-10, 0, 10))

  expect_equal(nrow(result), 3)
})


# ------------------------------------------------------------------------------
# find_pareto_frontier
# ------------------------------------------------------------------------------

test_that("find_pareto_frontier identifies non-dominated solutions", {
  dc <- make_demand_curve(unit_cost = 15)

  result <- find_pareto_frontier(
    dc,
    objectives = list(revenue = TRUE, volume = TRUE),
    market_size = 10000
  )

  expect_s3_class(result, "data.frame")
  expect_true("pareto_optimal" %in% names(result))
  expect_true(any(result$pareto_optimal))

  n_pareto <- attr(result, "n_pareto_points")
  expect_true(n_pareto > 0)
})

test_that("find_pareto_frontier includes profit objective", {
  dc <- make_demand_curve(unit_cost = 15)

  result <- find_pareto_frontier(
    dc,
    objectives = list(revenue = TRUE, profit = TRUE),
    unit_cost = 15
  )

  expect_true("profit" %in% names(result))
  expect_true("revenue" %in% names(result))
})


# ------------------------------------------------------------------------------
# optimize_with_scenarios
# ------------------------------------------------------------------------------

test_that("optimize_with_scenarios runs across cost/market scenarios", {
  dc <- make_demand_curve()

  scenarios <- list(
    optimistic = list(unit_cost = 10, market_size = 20000),
    base = list(unit_cost = 15, market_size = 10000),
    pessimistic = list(unit_cost = 20, market_size = 5000)
  )

  result <- optimize_with_scenarios(dc, scenarios, objective = "revenue")

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
  expect_true(all(c("scenario", "optimal_price", "revenue_index") %in% names(result)))
  expect_true("optimistic" %in% result$scenario)
  expect_true("pessimistic" %in% result$scenario)
})

test_that("optimize_with_scenarios applies constraints", {
  dc <- make_demand_curve(unit_cost = 15)

  scenarios <- list(
    base = list(unit_cost = 15, market_size = 10000)
  )

  result <- optimize_with_scenarios(
    dc,
    scenarios,
    objective = "revenue",
    constraints = list(min_price = 30, max_price = 60)
  )

  expect_true(result$optimal_price >= 30)
  expect_true(result$optimal_price <= 60)
})

test_that("optimize_with_scenarios handles profit objective", {
  dc <- make_demand_curve()

  scenarios <- list(
    low_cost = list(unit_cost = 10, market_size = 10000),
    high_cost = list(unit_cost = 25, market_size = 10000)
  )

  result <- optimize_with_scenarios(dc, scenarios, objective = "profit")

  expect_equal(nrow(result), 2)
  # Higher cost should yield higher optimal price
  low_price <- result$optimal_price[result$scenario == "low_cost"]
  high_price <- result$optimal_price[result$scenario == "high_cost"]
  expect_true(high_price >= low_price - 5)  # Allow small tolerance
})
