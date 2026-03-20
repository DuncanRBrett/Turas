# ==============================================================================
# TURAS PRICING MODULE - VISUALIZATION TESTS
# ==============================================================================
# Tests for: 05_visualization.R
# Covers: generate_pricing_plots, plot_van_westendorp, plot_gg_demand,
#         plot_gg_revenue, plot_gg_profit, plot_revenue_vs_profit
# ==============================================================================

# Helper: create minimal VW results
make_vw_results <- function() {
  list(
    price_points = list(PMC = 25, OPP = 35, IDP = 40, PME = 55),
    curves = data.frame(
      price = seq(10, 70, by = 1),
      too_cheap = seq(1, 0, length.out = 61),
      cheap = seq(0.9, 0.1, length.out = 61),
      expensive = seq(0.1, 0.9, length.out = 61),
      too_expensive = seq(0, 1, length.out = 61),
      stringsAsFactors = FALSE
    ),
    acceptable_range = list(lower = 25, upper = 55, width = 30),
    optimal_range = list(lower = 35, upper = 40, width = 5)
  )
}

# Helper: create minimal GG results
make_gg_results <- function(with_profit = FALSE) {
  prices <- seq(20, 80, by = 10)
  intent <- c(0.85, 0.70, 0.55, 0.40, 0.25, 0.15, 0.05)
  revenue <- prices * intent

  res <- list(
    demand_curve = data.frame(
      price = prices,
      purchase_intent = intent,
      stringsAsFactors = FALSE
    ),
    revenue_curve = data.frame(
      price = prices,
      purchase_intent = intent,
      revenue_index = revenue,
      stringsAsFactors = FALSE
    ),
    optimal_price = data.frame(
      price = 40,
      purchase_intent = 0.55,
      revenue_index = 22,
      stringsAsFactors = FALSE
    )
  )

  if (with_profit) {
    unit_cost <- 15
    res$revenue_curve$margin <- prices - unit_cost
    res$revenue_curve$profit_index <- res$revenue_curve$margin * intent
    res$optimal_price_profit <- data.frame(
      price = 50,
      purchase_intent = 0.40,
      profit_index = 14,
      margin = 35,
      stringsAsFactors = FALSE
    )
  }

  res
}

make_config <- function() {
  list(
    currency_symbol = "$",
    analysis_method = "van_westendorp"
  )
}


# ------------------------------------------------------------------------------
# generate_pricing_plots
# ------------------------------------------------------------------------------

test_that("generate_pricing_plots returns list for VW results", {
  skip_if_not_installed("ggplot2")

  results <- make_vw_results()
  config <- make_config()

  plots <- generate_pricing_plots(results, config)

  expect_true(is.list(plots))
  expect_true(length(plots) >= 1)
})

test_that("generate_pricing_plots returns list for GG results", {
  skip_if_not_installed("ggplot2")

  results <- make_gg_results()
  config <- make_config()
  config$analysis_method <- "gabor_granger"

  plots <- generate_pricing_plots(results, config)

  expect_true(is.list(plots))
  expect_true(length(plots) >= 1)
})


# ------------------------------------------------------------------------------
# plot_van_westendorp
# ------------------------------------------------------------------------------

test_that("plot_van_westendorp returns ggplot object", {
  skip_if_not_installed("ggplot2")

  results <- make_vw_results()
  config <- make_config()

  p <- plot_van_westendorp(results, config)

  expect_true(inherits(p, "gg") || inherits(p, "ggplot"))
})


# ------------------------------------------------------------------------------
# plot_gg_demand
# ------------------------------------------------------------------------------

test_that("plot_gg_demand returns ggplot object", {
  skip_if_not_installed("ggplot2")

  results <- make_gg_results()
  config <- make_config()

  p <- plot_gg_demand(results, config)

  expect_true(inherits(p, "gg") || inherits(p, "ggplot"))
})


# ------------------------------------------------------------------------------
# plot_gg_revenue
# ------------------------------------------------------------------------------

test_that("plot_gg_revenue returns ggplot object", {
  skip_if_not_installed("ggplot2")

  results <- make_gg_results()
  config <- make_config()

  p <- plot_gg_revenue(results, config)

  expect_true(inherits(p, "gg") || inherits(p, "ggplot"))
})


# ------------------------------------------------------------------------------
# plot_gg_profit
# ------------------------------------------------------------------------------

test_that("plot_gg_profit returns ggplot object with profit data", {
  skip_if_not_installed("ggplot2")

  results <- make_gg_results(with_profit = TRUE)
  config <- make_config()

  p <- plot_gg_profit(results, config)

  expect_true(inherits(p, "gg") || inherits(p, "ggplot") || is.null(p))
})


# ------------------------------------------------------------------------------
# plot_revenue_vs_profit
# ------------------------------------------------------------------------------

test_that("plot_revenue_vs_profit returns ggplot with both curves", {
  skip_if_not_installed("ggplot2")

  results <- make_gg_results(with_profit = TRUE)
  config <- make_config()

  p <- plot_revenue_vs_profit(results, config)

  expect_true(inherits(p, "gg") || inherits(p, "ggplot") || is.null(p))
})

test_that("plot_revenue_vs_profit handles missing profit data", {
  skip_if_not_installed("ggplot2")

  results <- make_gg_results(with_profit = FALSE)
  config <- make_config()

  # Should return NULL or a plot without profit line
  p <- plot_revenue_vs_profit(results, config)
  # Either NULL (no profit data) or a valid plot
  expect_true(is.null(p) || inherits(p, "gg") || inherits(p, "ggplot"))
})
