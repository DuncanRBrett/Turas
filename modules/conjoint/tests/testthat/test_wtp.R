# ==============================================================================
# TESTS: WILLINGNESS TO PAY (14_willingness_to_pay.R)
# ==============================================================================

fixture_path <- file.path(
  dirname(dirname(testthat::test_path())),
  "fixtures", "synthetic_data", "generate_conjoint_test_data.R"
)
if (file.exists(fixture_path)) source(fixture_path, local = TRUE)


test_that("extract_numeric_prices handles common formats", {
  if (!exists("extract_numeric_prices", mode = "function")) skip("extract_numeric_prices not loaded")

  expect_equal(extract_numeric_prices(c("$10", "$20", "$30")), c(10, 20, 30))
  expect_equal(extract_numeric_prices(c("R150", "R250")), c(150, 250))
  expect_equal(extract_numeric_prices(c("100", "200", "300")), c(100, 200, 300))
  expect_equal(extract_numeric_prices(c("9.99", "19.99")), c(9.99, 19.99))
})


test_that("estimate_price_coefficient returns negative coefficient for higher prices", {
  if (!exists("estimate_price_coefficient", mode = "function")) skip("estimate_price_coefficient not loaded")

  utils <- generate_utilities_df(with_price = TRUE)
  # Price utilities: $10=0, $20=-0.5, $30=-1.2 → negative slope
  coef <- estimate_price_coefficient(utils, "Price", verbose = FALSE)

  expect_is(coef, "numeric")
  expect_true(coef < 0)  # Higher price → lower utility
})


test_that("WTP values have correct sign and magnitude", {
  if (!exists("calculate_wtp", mode = "function")) skip("calculate_wtp not loaded")

  utils <- generate_utilities_df(with_price = TRUE)
  config <- list(
    wtp_price_attribute = "Price",
    wtp_method = "marginal",
    confidence_level = 0.95,
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size  = c("Small", "Medium", "Large"),
      Price = c("$10", "$20", "$30")
    )
  )

  result <- calculate_wtp(utils, config, model_result = NULL, verbose = FALSE)

  expect_is(result$wtp_table, "data.frame")
  expect_true("WTP" %in% names(result$wtp_table))
  expect_true(result$price_coefficient < 0)

  # Brand Beta has positive utility → positive WTP (willing to pay MORE)
  beta_wtp <- result$wtp_table$WTP[result$wtp_table$Level == "Beta" & result$wtp_table$Attribute == "Brand"]
  expect_true(beta_wtp > 0)

  # Brand Gamma has negative utility → negative WTP
  gamma_wtp <- result$wtp_table$WTP[result$wtp_table$Level == "Gamma" & result$wtp_table$Attribute == "Brand"]
  expect_true(gamma_wtp < 0)
})


test_that("WTP refuses when price attribute is missing", {
  if (!exists("calculate_wtp", mode = "function")) skip("calculate_wtp not loaded")

  utils <- generate_utilities_df(with_price = TRUE)
  config <- list(
    wtp_price_attribute = "",
    confidence_level = 0.95
  )

  # Should refuse with empty price attribute
  expect_error(calculate_wtp(utils, config, verbose = FALSE))
})


test_that("WTP CIs bracket the point estimate", {
  if (!exists("calculate_wtp", mode = "function")) skip("calculate_wtp not loaded")

  utils <- generate_utilities_df(with_price = TRUE)
  config <- list(
    wtp_price_attribute = "Price",
    confidence_level = 0.95,
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size  = c("Small", "Medium", "Large"),
      Price = c("$10", "$20", "$30")
    )
  )

  result <- calculate_wtp(utils, config, verbose = FALSE)
  wtp <- result$wtp_table

  # For rows with SE, CI should bracket the estimate
  has_ci <- !is.na(wtp$WTP_SE) & wtp$WTP_SE > 0
  if (any(has_ci)) {
    expect_true(all(wtp$WTP_Lower[has_ci] <= wtp$WTP[has_ci]))
    expect_true(all(wtp$WTP_Upper[has_ci] >= wtp$WTP[has_ci]))
  }
})
