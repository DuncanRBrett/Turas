# ==============================================================================
# TESTS: EDGE CASES
# ==============================================================================

fixture_path <- file.path(
  dirname(dirname(testthat::test_path())),
  "fixtures", "synthetic_data", "generate_conjoint_test_data.R"
)
if (file.exists(fixture_path)) source(fixture_path, local = TRUE)


test_that("utilities with all-zero baseline levels are handled", {
  utils <- generate_utilities_df(with_price = TRUE)
  baselines <- utils[utils$is_baseline, ]
  expect_true(all(baselines$Utility == 0))
})


test_that("single-attribute utilities work for simulation", {
  if (!exists("predict_market_shares", mode = "function")) skip("predict_market_shares not loaded")

  utils <- data.frame(
    Attribute = c("Brand", "Brand", "Brand"),
    Level = c("A", "B", "C"),
    Utility = c(0, 0.5, -0.3),
    is_baseline = c(TRUE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )

  config <- list(
    attribute_levels = list(Brand = c("A", "B", "C")),
    simulation_method = "logit"
  )

  products <- list(
    list(Brand = "A"),
    list(Brand = "B"),
    list(Brand = "C")
  )

  shares <- predict_market_shares(products, utils, config)
  expect_equal(sum(shares), 1.0, tolerance = 1e-6)
  # B has highest utility → highest share
  expect_true(shares[2] > shares[1])
  expect_true(shares[2] > shares[3])
})


test_that("importance sums to 100", {
  imp <- generate_importance_df(with_price = TRUE)
  expect_equal(sum(imp$Importance), 100)
})


test_that("extract_numeric_prices handles edge cases", {
  if (!exists("extract_numeric_prices", mode = "function")) skip("extract_numeric_prices not loaded")

  # Empty strings
  result <- extract_numeric_prices(c("", "  "))
  expect_true(all(is.na(result)))

  # Mixed valid/invalid
  result2 <- extract_numeric_prices(c("$10", "free", "$30"))
  expect_equal(result2[1], 10)
  expect_true(is.na(result2[2]))
  expect_equal(result2[3], 30)
})


test_that("two-segment data has expected structure", {
  seg_data <- generate_two_segment_data(n_respondents = 20, seed = 1)

  expect_is(seg_data$data, "data.frame")
  expect_equal(length(seg_data$segment_assignments), 20)
  expect_true(all(seg_data$segment_assignments %in% c(1, 2)))

  # Both segments should be represented
  expect_true(1 %in% seg_data$segment_assignments)
  expect_true(2 %in% seg_data$segment_assignments)

  # Correct number of rows
  expect_equal(nrow(seg_data$data), 20 * 8 * 3)  # respondents * tasks * alts
})


test_that("WTP handles non-numeric price levels gracefully", {
  if (!exists("extract_numeric_prices", mode = "function")) skip("extract_numeric_prices not loaded")

  # Currency formats
  expect_equal(extract_numeric_prices(c("EUR 50.00", "EUR 100.00")), c(50, 100))
  expect_equal(extract_numeric_prices(c("$1,299", "$2,499")), c(1299, 2499))
})


test_that("null coalesce handles various falsy values correctly", {
  `%||%` <- function(x, y) if (is.null(x)) y else x

  # Only NULL should trigger fallback

  expect_equal(NULL %||% "default", "default")
  expect_equal(FALSE %||% "default", FALSE)
  expect_equal(0 %||% "default", 0)
  expect_equal("" %||% "default", "")
  expect_equal(NA %||% "default", NA)
})
