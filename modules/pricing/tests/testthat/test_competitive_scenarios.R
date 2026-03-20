# ==============================================================================
# TURAS PRICING MODULE - COMPETITIVE SCENARIOS TESTS
# ==============================================================================
# Tests for: 08_competitive_scenarios.R
# Covers: simulate_choice, simulate_scenarios, price_response_curve
# ==============================================================================

# Helper: create WTP data for competitive testing
make_wtp_data <- function(n = 100) {
  set.seed(42)
  data.frame(
    id = seq_len(n),
    wtp = rnorm(n, mean = 50, sd = 15),
    weight = rep(1, n),
    stringsAsFactors = FALSE
  )
}


# ------------------------------------------------------------------------------
# simulate_choice
# ------------------------------------------------------------------------------

test_that("simulate_choice returns market shares summing to 1", {
  wtp <- make_wtp_data(200)
  prices <- c(brand_a = 40, brand_b = 45, brand_c = 50)

  result <- simulate_choice(wtp, prices, allow_no_purchase = TRUE)

  expect_s3_class(result, "data.frame")
  expect_true("brand" %in% names(result))
  expect_true("share" %in% names(result))
  expect_equal(sum(result$share), 1, tolerance = 1e-10)
})

test_that("simulate_choice assigns highest share to cheapest brand", {
  # Use WTP data where everyone can afford the cheap brand
  set.seed(99)
  wtp <- data.frame(
    id = 1:500,
    wtp = rnorm(500, mean = 60, sd = 10),
    weight = rep(1, 500),
    stringsAsFactors = FALSE
  )
  prices <- c(cheap_brand = 30, mid_brand = 50, expensive_brand = 70)

  result <- simulate_choice(wtp, prices, allow_no_purchase = TRUE)

  # Cheapest brand should dominate (surplus = WTP - 30 is highest for all)
  cheap_share <- result$share[result$brand == "cheap_brand"]
  expect_true(length(cheap_share) > 0)
  expect_true(cheap_share > 0.9)
})

test_that("simulate_choice includes no_purchase when allowed", {
  # Set WTP very low so most can't afford any brand
  wtp <- data.frame(
    id = 1:50,
    wtp = rep(10, 50),
    weight = rep(1, 50),
    stringsAsFactors = FALSE
  )
  prices <- c(brand_a = 40, brand_b = 50)

  result <- simulate_choice(wtp, prices, allow_no_purchase = TRUE)

  expect_true(".no_purchase" %in% result$brand)
  no_purchase_share <- result$share[result$brand == ".no_purchase"]
  expect_true(no_purchase_share > 0.5)  # Most should not purchase
})

test_that("simulate_choice forces purchase when allow_no_purchase = FALSE", {
  wtp <- data.frame(
    id = 1:20,
    wtp = rep(10, 20),
    weight = rep(1, 20),
    stringsAsFactors = FALSE
  )
  prices <- c(brand_a = 40, brand_b = 50)

  result <- simulate_choice(wtp, prices, allow_no_purchase = FALSE)

  expect_false(".no_purchase" %in% result$brand)
})

test_that("simulate_choice adds volume when market_size provided", {
  wtp <- make_wtp_data(100)
  prices <- c(brand_a = 40, brand_b = 50)

  result <- simulate_choice(wtp, prices, market_size = 10000)

  expect_true("volume" %in% names(result))
  expect_equal(sum(result$volume), 10000, tolerance = 0.1)
})

test_that("simulate_choice refuses unnamed prices", {
  wtp <- make_wtp_data(50)
  prices <- c(40, 50, 60)  # No names

  expect_error(simulate_choice(wtp, prices), "DATA_PRICES_NOT_NAMED")
})

test_that("simulate_choice handles weighted respondents", {
  wtp <- data.frame(
    id = 1:4,
    wtp = c(60, 60, 60, 60),
    weight = c(10, 1, 1, 1),
    stringsAsFactors = FALSE
  )
  prices <- c(brand_a = 40, brand_b = 50)

  result <- simulate_choice(wtp, prices)

  # All respondents choose brand_a (cheapest), shares by weight
  brand_a_row <- result[result$brand == "brand_a", ]
  expect_true(brand_a_row$share > 0.9)
})


# ------------------------------------------------------------------------------
# simulate_scenarios
# ------------------------------------------------------------------------------

test_that("simulate_scenarios runs multiple scenarios", {
  wtp <- make_wtp_data(200)

  scenarios <- data.frame(
    brand_a = c(35, 40, 45),
    brand_b = c(50, 50, 50),
    stringsAsFactors = FALSE
  )

  result <- simulate_scenarios(wtp, scenarios,
                               scenario_names = c("Low", "Mid", "High"))

  expect_s3_class(result, "data.frame")
  expect_true("scenario" %in% names(result))
  expect_true("brand" %in% names(result))
  expect_true("price" %in% names(result))
  expect_true("share" %in% names(result))
  expect_equal(length(unique(result$scenario)), 3)
})

test_that("simulate_scenarios uses default names when not provided", {
  wtp <- make_wtp_data(100)

  scenarios <- data.frame(
    brand_a = c(30, 50),
    brand_b = c(40, 40)
  )

  result <- simulate_scenarios(wtp, scenarios)

  expect_true("S1" %in% result$scenario)
  expect_true("S2" %in% result$scenario)
})

test_that("simulate_scenarios refuses non-data-frame", {
  wtp <- make_wtp_data(50)

  expect_error(simulate_scenarios(wtp, scenarios = list(a = 30, b = 40)),
               "DATA_SCENARIOS_INVALID")
})

test_that("simulate_scenarios refuses mismatched scenario names", {
  wtp <- make_wtp_data(50)
  scenarios <- data.frame(brand_a = c(30, 40), brand_b = c(50, 50))

  expect_error(simulate_scenarios(wtp, scenarios,
                                   scenario_names = c("A", "B", "C")),
               "DATA_SCENARIO_NAMES_MISMATCH")
})

test_that("simulate_scenarios includes volume with market_size", {
  wtp <- make_wtp_data(100)
  scenarios <- data.frame(brand_a = c(30, 50), brand_b = c(40, 40))

  result <- simulate_scenarios(wtp, scenarios, market_size = 5000)

  expect_true("volume" %in% names(result))
})


# ------------------------------------------------------------------------------
# price_response_curve
# ------------------------------------------------------------------------------

test_that("price_response_curve shows declining share with rising price", {
  wtp <- make_wtp_data(500)

  response <- price_response_curve(
    wtp,
    your_prices = seq(20, 80, by = 10),
    competitor_prices = c(comp_a = 45, comp_b = 55),
    your_brand_name = "Our Brand"
  )

  expect_s3_class(response, "data.frame")
  expect_true("your_price" %in% names(response))
  expect_true("your_share" %in% names(response))
  expect_equal(nrow(response), 7)

  # Share should generally decrease as our price increases
  # (Not strictly monotone due to discrete WTP, but overall trend)
  low_price_share <- response$your_share[response$your_price == 20]
  high_price_share <- response$your_share[response$your_price == 80]
  expect_true(low_price_share > high_price_share)
})

test_that("price_response_curve returns 0 share when price exceeds all WTP", {
  wtp <- data.frame(
    id = 1:50,
    wtp = rep(30, 50),
    weight = rep(1, 50),
    stringsAsFactors = FALSE
  )

  response <- price_response_curve(
    wtp,
    your_prices = c(100),
    competitor_prices = c(comp = 90),
    allow_no_purchase = TRUE
  )

  # At price 100, WTP is 30, everyone picks no_purchase
  expect_equal(response$your_share, 0)
})
