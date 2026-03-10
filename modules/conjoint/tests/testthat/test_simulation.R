# ==============================================================================
# TESTS: CONJOINT SIMULATION (05_simulator.R)
# ==============================================================================

fixture_path <- file.path(
  dirname(dirname(testthat::test_path())),
  "fixtures", "synthetic_data", "generate_conjoint_test_data.R"
)
if (file.exists(fixture_path)) source(fixture_path, local = TRUE)


test_that("generate_utilities_df produces valid structure", {
  utils <- generate_utilities_df(with_price = TRUE)

  expect_is(utils, "data.frame")
  expect_true(all(c("Attribute", "Level", "Utility", "SE", "is_baseline") %in% names(utils)))
  expect_true(any(utils$is_baseline))
  expect_true(any(utils$Attribute == "Price"))
})


test_that("market share logit simulation sums to 1", {
  if (!exists("predict_market_shares", mode = "function")) skip("predict_market_shares not loaded")

  utils <- generate_utilities_df(with_price = FALSE)
  config <- list(
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size  = c("Small", "Medium", "Large")
    ),
    simulation_method = "logit"
  )

  products <- list(
    list(Brand = "Alpha", Size = "Small"),
    list(Brand = "Beta",  Size = "Medium"),
    list(Brand = "Gamma", Size = "Large")
  )

  shares <- predict_market_shares(products, utils, config)

  expect_is(shares, "numeric")
  expect_equal(length(shares), 3)
  expect_equal(sum(shares), 1.0, tolerance = 1e-6)
  expect_true(all(shares >= 0 & shares <= 1))
})


test_that("source of volume conserves total share", {
  if (!exists("source_of_volume", mode = "function")) skip("source_of_volume not loaded")

  utils <- generate_utilities_df(with_price = FALSE)
  config <- list(
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size  = c("Small", "Medium", "Large")
    ),
    simulation_method = "logit"
  )

  baseline_products <- list(
    list(Brand = "Alpha", Size = "Small"),
    list(Brand = "Beta",  Size = "Medium")
  )

  test_products <- list(
    list(Brand = "Alpha", Size = "Small"),
    list(Brand = "Beta",  Size = "Medium"),
    list(Brand = "Gamma", Size = "Large")
  )

  sov <- source_of_volume(baseline_products, test_products, utils, config)

  expect_is(sov, "data.frame")
  # Shares from removed from existing products should equal share gained by new product
  expect_equal(sum(sov$share_shift), 0, tolerance = 1e-6)
})


test_that("demand curve returns valid price-share pairs", {
  if (!exists("generate_demand_curve", mode = "function")) skip("generate_demand_curve not loaded")

  utils <- generate_utilities_df(with_price = TRUE)
  config <- list(
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size  = c("Small", "Medium", "Large"),
      Price = c("$10", "$20", "$30")
    ),
    simulation_method = "logit"
  )

  products <- list(
    list(Brand = "Alpha", Size = "Small", Price = "$10"),
    list(Brand = "Beta",  Size = "Medium", Price = "$20")
  )

  curve <- generate_demand_curve(products, 1, "Price", utils, config)

  expect_is(curve, "data.frame")
  expect_true(all(c("level", "share") %in% names(curve)))
  expect_equal(nrow(curve), 3)  # 3 price levels
  expect_true(all(curve$share >= 0 & curve$share <= 1))
})
