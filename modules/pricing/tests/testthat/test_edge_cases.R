# ==============================================================================
# TURAS PRICING MODULE - EDGE CASE TESTS
# ==============================================================================
#
# Tests for boundary conditions, degenerate inputs, and unusual data patterns
# ==============================================================================

# ── Small Datasets (n < 10) ──────────────────────────────────────────────────

test_that("VW data generator works with very small n", {
  df <- generate_vw_data(n = 5, base_price = 20)
  expect_equal(nrow(df), 5)
  expect_true(all(c("too_cheap", "cheap", "expensive", "too_expensive") %in% names(df)))
})

test_that("GG data generator works with very small n", {
  df <- generate_gg_data_wide(n = 3, prices = c(10, 20, 30))
  expect_equal(nrow(df), 3)
  expect_equal(ncol(df), 4)  # respondent_id + 3 price columns
})

test_that("monadic data generator works with very small n", {
  df <- generate_monadic_data(n = 6, prices = c(10, 20))
  expect_equal(nrow(df), 6)
  expect_true(all(df$price_shown %in% c(10, 20)))
})


# ── All-NA and Missing Data ──────────────────────────────────────────────────


# ── Non-ASCII Currency Symbols ───────────────────────────────────────────────

test_that("JSON builder handles non-ASCII currency", {
  demand_data <- list(
    price_range = c(100, 200, 300),
    demand_curve = c(0.8, 0.5, 0.2),
    revenue_curve = c(80, 100, 60)
  )
  json <- build_pricing_json(demand_data, 200, list())

  # Should be parseable regardless of currency symbol
  parsed <- jsonlite::fromJSON(json)
  expect_equal(length(parsed$price_range), 3)
})

test_that("extract_segment_demand handles empty segment_results", {
  empty_results <- list(segment_results = list())
  seg_data <- extract_segment_demand(empty_results, "gabor_granger")
  expect_equal(length(seg_data), 0)
})


# ── VW Edge Cases ────────────────────────────────────────────────────────────


# ── Page Builder Edge Cases ──────────────────────────────────────────────────
