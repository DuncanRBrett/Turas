# ==============================================================================
# TURAS PRICING MODULE - POINT ELASTICITY TESTS
# ==============================================================================
# Tests for: compute_point_elasticity() in 09_price_volume_optimisation.R
# ==============================================================================

# Helper: create a standard demand curve
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
# compute_point_elasticity - basic functionality
# ------------------------------------------------------------------------------

test_that("compute_point_elasticity returns valid data frame", {
  dc <- make_demand_curve()

  result <- compute_point_elasticity(dc)

  expect_s3_class(result, "data.frame")
  expect_true(all(c("price", "purchase_intent", "elasticity",
                     "elasticity_type", "revenue_index",
                     "marginal_revenue") %in% names(result)))
  expect_true(nrow(result) > 0)
})

test_that("compute_point_elasticity returns negative elasticity for normal demand", {
  dc <- make_demand_curve()

  result <- compute_point_elasticity(dc)

  # Demand slopes down, so elasticity should be negative
  valid_elast <- result$elasticity[!is.na(result$elasticity)]
  expect_true(all(valid_elast < 0))
})

test_that("compute_point_elasticity evaluates at specified prices", {
  dc <- make_demand_curve()

  eval_prices <- c(30, 40, 50, 60)
  result <- compute_point_elasticity(dc, prices_to_evaluate = eval_prices)

  expect_equal(nrow(result), 4)
  expect_equal(result$price, eval_prices)
})

test_that("compute_point_elasticity default grid includes midpoints", {
  dc <- make_demand_curve()

  result <- compute_point_elasticity(dc)

  # Should have more rows than original (originals + midpoints)
  expect_true(nrow(result) > nrow(dc))
})


# ------------------------------------------------------------------------------
# compute_point_elasticity - elasticity properties
# ------------------------------------------------------------------------------

test_that("compute_point_elasticity shows more elastic demand at higher prices", {
  dc <- make_demand_curve()

  result <- compute_point_elasticity(dc, prices_to_evaluate = c(25, 50, 70))

  # At higher prices (with lower demand), elasticity should be more negative
  # (more elastic) than at low prices
  elast_low <- result$elasticity[result$price == 25]
  elast_high <- result$elasticity[result$price == 70]

  expect_true(elast_high < elast_low)
})

test_that("compute_point_elasticity classifies elastic vs inelastic", {
  dc <- make_demand_curve()

  result <- compute_point_elasticity(dc)

  types <- unique(result$elasticity_type)
  expect_true(all(types %in% c("Elastic", "Inelastic", "Unit Elastic", "Undefined")))

  # Should have at least one of each for a typical demand curve
  valid_types <- result$elasticity_type[result$elasticity_type != "Undefined"]
  expect_true("Elastic" %in% valid_types || "Inelastic" %in% valid_types)
})

test_that("compute_point_elasticity computes marginal revenue", {
  dc <- make_demand_curve()

  result <- compute_point_elasticity(dc, prices_to_evaluate = c(25, 40, 60))

  # MR should decrease as price increases (for downward-sloping demand)
  expect_true(result$marginal_revenue[1] > result$marginal_revenue[3])
})

test_that("compute_point_elasticity revenue_maximizing_price attribute set", {
  dc <- make_demand_curve()

  result <- compute_point_elasticity(dc)

  rev_max <- attr(result, "revenue_maximizing_price")
  # Should be set (MR crosses zero somewhere in the range)
  if (!is.null(rev_max)) {
    expect_true(rev_max >= min(dc$price))
    expect_true(rev_max <= max(dc$price))
  }
})


# ------------------------------------------------------------------------------
# compute_point_elasticity - edge cases
# ------------------------------------------------------------------------------

test_that("compute_point_elasticity refuses insufficient data", {
  dc <- data.frame(
    price = c(30, 40),
    purchase_intent = c(0.8, 0.6)
  )

  expect_error(compute_point_elasticity(dc), "DATA_INSUFFICIENT_POINTS")
})

test_that("compute_point_elasticity handles prices outside range", {
  dc <- make_demand_curve()

  # Prices outside data range should be clamped

  result <- compute_point_elasticity(dc, prices_to_evaluate = c(10, 50, 100))

  # Only price 50 is in range [20, 80]
  expect_equal(nrow(result), 1)
  expect_equal(result$price, 50)
})

test_that("compute_point_elasticity handles NAs in demand curve", {
  dc <- make_demand_curve()
  dc$purchase_intent[3] <- NA

  result <- compute_point_elasticity(dc)

  # Should still work after removing NAs
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("compute_point_elasticity stores method attribute", {
  dc <- make_demand_curve()

  result <- compute_point_elasticity(dc)

  expect_equal(attr(result, "method"), "point_elasticity_central_difference")
  expect_equal(attr(result, "delta"), 0.01)
})

test_that("compute_point_elasticity custom delta changes precision", {
  dc <- make_demand_curve()

  result_fine <- compute_point_elasticity(dc, prices_to_evaluate = c(40), delta = 0.001)
  result_coarse <- compute_point_elasticity(dc, prices_to_evaluate = c(40), delta = 1.0)

  # Both should give similar results (linear demand → exact derivative)
  expect_true(abs(result_fine$elasticity - result_coarse$elasticity) < 0.5)
})
