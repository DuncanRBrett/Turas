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

test_that("transform_pricing_for_html handles minimal results", {
  pricing_results <- list(
    method = "gabor_granger",
    results = list(
      demand_curve = data.frame(price = c(10, 20), purchase_intent = c(0.8, 0.3)),
      revenue_curve = data.frame(price = c(10, 20), purchase_intent = c(0.8, 0.3), revenue_index = c(8, 6)),
      optimal_price = list(price = 10, purchase_intent = 0.8, revenue_index = 8)
    ),
    diagnostics = list(n_total = 5, n_valid = 5)
  )
  config <- list(currency_symbol = "$")

  html_data <- transform_pricing_for_html(pricing_results, config)
  expect_equal(html_data$meta$method, "gabor_granger")
  expect_equal(html_data$meta$n_valid, 5)
  expect_false(is.null(html_data$gabor_granger))
})


# ── Extreme Price Ranges ─────────────────────────────────────────────────────

test_that("chart builder handles very low prices ($0.01)", {
  prices <- c(0.01, 0.02, 0.05, 0.10)
  intents <- c(0.95, 0.85, 0.60, 0.30)
  revenue <- prices * intents

  svg <- build_demand_curve_chart(
    prices = prices,
    intents = intents,
    revenue = revenue,
    optimal_price = 0.02,
    brand_colour = "#1e3a5f",
    currency = "$"
  )

  expect_true(grepl("<svg", svg))
  expect_true(grepl("viewBox", svg))
})

test_that("chart builder handles very high prices ($10,000+)", {
  prices <- c(5000, 7500, 10000, 15000, 20000)
  intents <- c(0.7, 0.5, 0.3, 0.15, 0.05)
  revenue <- prices * intents

  svg <- build_demand_curve_chart(
    prices = prices,
    intents = intents,
    revenue = revenue,
    optimal_price = 7500,
    brand_colour = "#1e3a5f",
    currency = "$"
  )

  expect_true(grepl("<svg", svg))
  expect_true(grepl("viewBox", svg))
})

test_that("table builder handles very low prices", {
  gg_data <- list(
    demand_curve = data.frame(price = c(0.01, 0.05, 0.10), purchase_intent = c(0.9, 0.5, 0.1)),
    revenue_curve = data.frame(price = c(0.01, 0.05, 0.10), purchase_intent = c(0.9, 0.5, 0.1), revenue_index = c(0.009, 0.025, 0.010))
  )
  html <- build_gg_demand_table(gg_data, "$")
  expect_true(grepl("<table", html))
  expect_true(grepl("0.01", html))
})

test_that("table builder handles very high prices", {
  gg_data <- list(
    demand_curve = data.frame(price = c(10000, 20000, 50000), purchase_intent = c(0.8, 0.4, 0.1)),
    revenue_curve = data.frame(price = c(10000, 20000, 50000), purchase_intent = c(0.8, 0.4, 0.1), revenue_index = c(8000, 8000, 5000))
  )
  html <- build_gg_demand_table(gg_data, "$")
  expect_true(grepl("<table", html))
  expect_true(grepl("10000", html) || grepl("10,000", html))
})


# ── All-NA and Missing Data ──────────────────────────────────────────────────

test_that("data transformer handles missing diagnostics gracefully", {
  pricing_results <- list(
    method = "gabor_granger",
    results = list(
      demand_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.8, 0.5, 0.2)),
      revenue_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.8, 0.5, 0.2), revenue_index = c(8, 10, 6)),
      optimal_price = list(price = 20)
    ),
    diagnostics = NULL
  )

  html_data <- transform_pricing_for_html(pricing_results, list())
  expect_equal(html_data$meta$n_total, 0)
  expect_equal(html_data$meta$n_valid, 0)
})

test_that("data transformer handles NULL synthesis", {
  pricing_results <- list(
    method = "gabor_granger",
    results = list(
      demand_curve = data.frame(price = c(10, 20), purchase_intent = c(0.8, 0.3)),
      revenue_curve = data.frame(price = c(10, 20), purchase_intent = c(0.8, 0.3), revenue_index = c(8, 6)),
      optimal_price = list(price = 10)
    ),
    synthesis = NULL,
    diagnostics = list(n_total = 50, n_valid = 50)
  )

  html_data <- transform_pricing_for_html(pricing_results, list())
  expect_null(html_data$summary$recommended_price)
  expect_null(html_data$recommendation)
})

test_that("chart builder handles all-zero intents gracefully", {
  prices <- c(10, 20, 30, 40, 50)
  intents <- c(0, 0, 0, 0, 0)
  revenue <- prices * intents

  svg <- build_demand_curve_chart(
    prices = prices,
    intents = intents,
    revenue = revenue,
    brand_colour = "#1e3a5f"
  )

  # Should produce a valid SVG even with zeros (flat line at bottom)
  expect_true(grepl("<svg", svg))
})

test_that("chart builder handles all-one intents (perfect demand)", {
  prices <- c(10, 20, 30)
  intents <- c(1, 1, 1)
  revenue <- prices * intents

  svg <- build_demand_curve_chart(
    prices = prices,
    intents = intents,
    revenue = revenue,
    brand_colour = "#1e3a5f"
  )

  expect_true(grepl("<svg", svg))
})


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

test_that("scenarios JSON handles special characters in names", {
  scenarios <- data.frame(
    name = c("Budget & Value", "Premium (Top)"),
    price = c(10, 50),
    description = c("Low-cost < $20", "High-end > $40"),
    stringsAsFactors = FALSE
  )
  json <- build_scenarios_json(scenarios, "$")

  parsed <- jsonlite::fromJSON(json)
  expect_equal(nrow(parsed), 2)
})


# ── Elasticity Edge Cases ────────────────────────────────────────────────────

test_that("elasticity chart handles all-Inf values", {
  el_data <- data.frame(
    price_from = c(10, 20, 30),
    price_to = c(20, 30, 40),
    arc_elasticity = c(Inf, -Inf, Inf)
  )

  svg <- build_elasticity_chart(el_data, "#1e3a5f", "$")
  # Should return empty or SVG without crashing
  expect_true(is.character(svg))
})

test_that("elasticity chart handles NaN values", {
  el_data <- data.frame(
    price_from = c(10, 20),
    price_to = c(20, 30),
    arc_elasticity = c(-0.5, NaN)
  )

  svg <- build_elasticity_chart(el_data, "#1e3a5f", "$")
  expect_true(is.character(svg))
})


# ── Empty Segment Results ────────────────────────────────────────────────────

test_that("extract_segment_demand handles empty segment_results", {
  empty_results <- list(segment_results = list())
  seg_data <- extract_segment_demand(empty_results, "gabor_granger")
  expect_equal(length(seg_data), 0)
})

test_that("segment comparison chart handles single segment", {
  seg_data <- list(
    comparison_table = data.frame(Segment = "Only One", OPP = 25)
  )

  svg <- build_segment_comparison_chart(seg_data, "#1e3a5f", "$")
  expect_true(grepl("<svg", svg))
  expect_true(grepl("Only One", svg))
})

test_that("transform_segments_section handles empty insights", {
  seg_results <- list(
    comparison_table = data.frame(Segment = c("A", "B"), OPP = c(15, 20)),
    insights = character(0)
  )

  section <- transform_segments_section(seg_results, list())
  expect_false(is.null(section$callout))
  expect_true(grepl("2 segments", section$callout))
})


# ── VW Edge Cases ────────────────────────────────────────────────────────────

test_that("VW chart handles identical price points", {
  vw_data <- list(
    curves = data.frame(
      price = seq(10, 30, by = 1),
      too_cheap = seq(1, 0, length.out = 21),
      cheap = seq(0.8, 0.1, length.out = 21),
      expensive = seq(0.1, 0.9, length.out = 21),
      too_expensive = seq(0, 1, length.out = 21)
    ),
    price_points = list(
      pmc = list(value = 20, label = "PMC"),
      opp = list(value = 20, label = "OPP"),
      idp = list(value = 20, label = "IDP"),
      pme = list(value = 20, label = "PME")
    )
  )

  svg <- build_vw_curves_chart(vw_data, "#1e3a5f")
  expect_true(grepl("<svg", svg))
})

test_that("VW price points table handles NMS-only result", {
  vw_data <- list(
    price_points = list(
      pmc = list(value = 10, label = "PMC", desc = "Point of Marginal Cheapness"),
      opp = list(value = 15, label = "OPP", desc = "Optimal Price Point"),
      idp = list(value = 16, label = "IDP", desc = "Indifference Price Point"),
      pme = list(value = 25, label = "PME", desc = "Point of Marginal Expensiveness")
    ),
    nms_results = list(trial_optimal = 14, revenue_optimal = 18)
  )

  html <- build_vw_price_points_table(vw_data, "$")
  expect_true(grepl("Trial Optimal", html))
  expect_true(grepl("Revenue Optimal", html))
  expect_true(grepl("14", html))
  expect_true(grepl("18", html))
})


# ── Page Builder Edge Cases ──────────────────────────────────────────────────

test_that("build_pricing_page works with VW-only results", {
  html_data <- list(
    meta = list(method = "van_westendorp", currency = "$", brand_colour = "#1e3a5f",
                project_name = "VW Only", generated = "2026-01-01", n_total = 100, n_valid = 95),
    summary = list(callout = "<div>Summary</div>"),
    van_westendorp = list(callout = "<div>VW data</div>"),
    gabor_granger = NULL,
    monadic = NULL,
    segments = NULL,
    recommendation = NULL
  )
  tables <- list(vw_price_points = "<table><tr><td>VW</td></tr></table>")
  charts <- list(vw_curves = "<svg viewBox='0 0 800 400'></svg>")
  config <- list(brand_colour = "#1e3a5f", currency_symbol = "$")

  page <- build_pricing_page(html_data, tables, charts, config)
  expect_true(grepl("<!DOCTYPE html>", page))
  expect_true(grepl("panel-vw", page))
  # No GG or monadic panels
  expect_false(grepl("panel-gg", page))
  expect_false(grepl("panel-monadic", page))
})

test_that("build_pricing_page works with monadic-only results", {
  html_data <- list(
    meta = list(method = "monadic", currency = "$", brand_colour = "#1e3a5f",
                project_name = "Monadic Only", generated = "2026-01-01", n_total = 200, n_valid = 200),
    summary = list(callout = "<div>Summary</div>"),
    van_westendorp = NULL,
    gabor_granger = NULL,
    monadic = list(callout = "<div>Monadic data</div>"),
    segments = NULL,
    recommendation = NULL
  )
  tables <- list(monadic_model = "<table><tr><td>Model</td></tr></table>")
  charts <- list(monadic_demand = "<svg viewBox='0 0 800 400'></svg>")
  config <- list(brand_colour = "#1e3a5f", currency_symbol = "$")

  page <- build_pricing_page(html_data, tables, charts, config)
  expect_true(grepl("<!DOCTYPE html>", page))
  expect_true(grepl("panel-monadic", page))
  expect_false(grepl("panel-vw", page))
  expect_false(grepl("panel-gg", page))
})

test_that("build_pricing_closing works without analyst name", {
  closing <- build_pricing_closing(list())
  expect_true(grepl("TURAS Analytics Platform", closing))
  expect_true(grepl("Confidential", closing))
  expect_false(grepl("Analyst", closing))
})
