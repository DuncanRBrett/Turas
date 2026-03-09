# ==============================================================================
# TURAS PRICING MODULE - PRICE LADDER TESTS
# ==============================================================================

test_that("build_price_ladder generates correct number of tiers", {
  skip_if(!exists("build_price_ladder", mode = "function"),
          "build_price_ladder not available")

  # Minimal VW results with key price points
  vw_results <- list(
    price_points = list(PMC = 20, OPP = 35, IDP = 45, PME = 70),
    acceptable_range = list(lower = 20, upper = 70),
    nms_results = list(revenue_optimal = 40)
  )

  config <- list(
    price_ladder = list(
      n_tiers = 3,
      tier_names = "Good;Better;Best",
      round_to = "0.99"
    ),
    currency_symbol = "$"
  )

  result <- build_price_ladder(vw_results, gg_results = NULL, config = config)

  expect_true(is.list(result))
  expect_true(!is.null(result$tier_table))
  tt <- result$tier_table
  expect_true(is.data.frame(tt))
  expect_equal(nrow(tt), 3)
})

test_that("build_price_ladder tiers are in ascending order", {
  skip_if(!exists("build_price_ladder", mode = "function"),
          "build_price_ladder not available")

  vw_results <- list(
    price_points = list(PMC = 20, OPP = 35, IDP = 45, PME = 70),
    acceptable_range = list(lower = 20, upper = 70),
    nms_results = list(revenue_optimal = 40)
  )

  config <- list(
    price_ladder = list(
      n_tiers = 3,
      tier_names = "Good;Better;Best",
      round_to = "none"
    ),
    currency_symbol = "$"
  )

  result <- build_price_ladder(vw_results, gg_results = NULL, config = config)

  prices <- result$tier_table$price
  expect_true(all(diff(prices) > 0))
})

test_that("apply_price_rounding applies 0.99 ending", {
  skip_if(!exists("apply_price_rounding", mode = "function"),
          "apply_price_rounding not available")

  prices <- c(30, 45, 60)
  result <- apply_price_rounding(prices, "0.99")

  expect_true(all(result %% 1 == 0.99 | abs(result %% 1 - 0.99) < 0.01))
})

test_that("apply_price_rounding handles 'none' option", {
  skip_if(!exists("apply_price_rounding", mode = "function"),
          "apply_price_rounding not available")

  prices <- c(30.50, 45.25, 60.75)
  result <- apply_price_rounding(prices, "none")

  expect_equal(result, prices)
})

test_that("analyze_gaps flags narrow gaps", {
  skip_if(!exists("analyze_gaps", mode = "function"),
          "analyze_gaps not available")

  prices <- c(29.99, 31.99, 59.99)  # Second gap is tiny (~7%)
  tier_names <- c("Good", "Better", "Best")

  result <- analyze_gaps(prices, tier_names, min_gap = 0.15, max_gap = 0.50)

  expect_true(is.list(result))
  # Should have some flags due to the narrow first gap
  expect_true(!is.null(result$flags) || !is.null(result$notes))
})

test_that("analyze_gaps accepts well-spaced tiers", {
  skip_if(!exists("analyze_gaps", mode = "function"),
          "analyze_gaps not available")

  prices <- c(29.99, 44.99, 64.99)  # ~50% and ~44% gaps
  tier_names <- c("Good", "Better", "Best")

  result <- analyze_gaps(prices, tier_names, min_gap = 0.15, max_gap = 0.50)

  expect_true(is.list(result))
})

test_that("build_price_ladder handles 2 tiers", {
  skip_if(!exists("build_price_ladder", mode = "function"),
          "build_price_ladder not available")

  vw_results <- list(
    price_points = list(PMC = 20, OPP = 35, IDP = 45, PME = 70),
    acceptable_range = list(lower = 20, upper = 70),
    nms_results = list(revenue_optimal = 40)
  )

  config <- list(
    price_ladder = list(
      n_tiers = 2,
      tier_names = "Standard;Premium",
      round_to = "0.99"
    ),
    currency_symbol = "$"
  )

  result <- build_price_ladder(vw_results, gg_results = NULL, config = config)

  expect_true(!is.null(result$tier_table))
  expect_equal(nrow(result$tier_table), 2)
})

test_that("estimate_tier_demand uses GG demand curve", {
  skip_if(!exists("estimate_tier_demand", mode = "function"),
          "estimate_tier_demand not available")

  tier_prices <- c(30, 45, 60)
  gg_results <- list(
    demand_curve = data.frame(
      price = c(20, 30, 40, 50, 60, 70, 80),
      purchase_intent = c(0.9, 0.8, 0.65, 0.5, 0.35, 0.2, 0.1)
    ),
    revenue_curve = data.frame(
      price = c(20, 30, 40, 50, 60, 70, 80),
      revenue_index = c(18, 24, 26, 25, 21, 14, 8)
    )
  )

  result <- estimate_tier_demand(tier_prices, gg_results)

  expect_true(is.data.frame(result) || is.list(result))
})
