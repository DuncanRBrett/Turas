# ==============================================================================
# TURAS PRICING MODULE - HTML REPORT TESTS
# ==============================================================================
#
# Tests for the 4-layer HTML report generation pipeline:
#   Layer 1: Data transformer
#   Layer 2: Table builder
#   Layer 3: Chart builder
#   Layer 4: Page builder
#   Orchestrator: 99_html_report_main.R
# ==============================================================================

# ── Layer 1: Data Transformer ────────────────────────────────────────────────

test_that("transform_pricing_for_html handles VW+GG (both) method", {
  # Build minimal pricing_results for "both" method
  pricing_results <- list(
    method = "both",
    results = list(
      van_westendorp = list(
        price_points = list(PMC = 10, OPP = 15, IDP = 18, PME = 25),
        acceptable_range = list(lower = 10, upper = 25),
        optimal_range = list(lower = 15, upper = 18),
        curves = data.frame(
          price = seq(5, 30, by = 1),
          too_cheap = seq(1, 0, length.out = 26),
          cheap = seq(0.8, 0.1, length.out = 26),
          expensive = seq(0.1, 0.9, length.out = 26),
          too_expensive = seq(0, 1, length.out = 26)
        ),
        nms_results = list(trial_optimal = 14, revenue_optimal = 17)
      ),
      gabor_granger = list(
        demand_curve = data.frame(price = c(10, 15, 20, 25, 30), purchase_intent = c(0.9, 0.7, 0.5, 0.3, 0.1)),
        revenue_curve = data.frame(price = c(10, 15, 20, 25, 30), purchase_intent = c(0.9, 0.7, 0.5, 0.3, 0.1), revenue_index = c(9, 10.5, 10, 7.5, 3)),
        optimal_price = list(price = 15, purchase_intent = 0.7, revenue_index = 10.5),
        elasticity = data.frame(price_from = c(10, 15, 20, 25), price_to = c(15, 20, 25, 30), arc_elasticity = c(-0.5, -0.8, -1.2, -2.0), elasticity_type = c("Inelastic", "Inelastic", "Elastic", "Elastic"))
      )
    ),
    synthesis = list(
      recommendation = list(price = 16.99, confidence = "HIGH", confidence_score = 0.85, source = "GG revenue optimal"),
      acceptable_range = list(lower = 10, upper = 25, lower_desc = "Risk of margin erosion", upper_desc = "Risk of demand loss"),
      evidence_table = data.frame(method = "GG", metric = "Optimal", value = "$15.00", interpretation = "Revenue max", stringsAsFactors = FALSE),
      risks = list(downside = c("Price too low for premium positioning"))
    ),
    segment_results = list(
      comparison_table = data.frame(Segment = c("A", "B"), OPP = c(15, 20)),
      insights = c("Segment B supports higher pricing", "Both segments show inelastic demand")
    ),
    diagnostics = list(n_total = 200, n_valid = 195)
  )
  config <- list(currency_symbol = "$", brand_colour = "#1e3a5f", project_name = "Test Project")

  html_data <- transform_pricing_for_html(pricing_results, config)

  expect_type(html_data, "list")
  expect_equal(html_data$meta$method, "both")
  expect_equal(html_data$meta$n_valid, 195)
  expect_false(is.null(html_data$van_westendorp))
  expect_false(is.null(html_data$gabor_granger))
  expect_false(is.null(html_data$recommendation))
  expect_false(is.null(html_data$segments))
  expect_null(html_data$monadic)  # monadic not in "both"
  expect_false(is.null(html_data$summary$callout))
})

test_that("transform_pricing_for_html handles monadic method", {
  pricing_results <- list(
    method = "monadic",
    results = list(
      demand_curve = data.frame(price = seq(10, 40, length.out = 50), predicted_intent = seq(0.9, 0.1, length.out = 50), revenue_index = seq(10, 40, length.out = 50) * seq(0.9, 0.1, length.out = 50)),
      observed_data = data.frame(price = c(15, 20, 25, 30), n = c(50, 50, 50, 50), observed_intent = c(0.8, 0.6, 0.4, 0.2)),
      optimal_price = list(price = 22, predicted_intent = 0.5, revenue_index = 11),
      model_summary = list(model_type = "logistic", n_observations = 200, pseudo_r2 = 0.15, aic = 250, null_deviance = 300, residual_deviance = 255, price_coefficient_p = 0.001),
      confidence_intervals = list(optimal_price_ci = c(19, 25), n_attempted = 1000)
    ),
    diagnostics = list(n_total = 200, n_valid = 200)
  )
  config <- list(currency_symbol = "$")

  html_data <- transform_pricing_for_html(pricing_results, config)
  expect_false(is.null(html_data$monadic))
  expect_null(html_data$van_westendorp)
  expect_null(html_data$gabor_granger)
})


# ── Layer 2: Table Builder ────────────────────────────────────────────────────

test_that("build_vw_price_points_table produces valid HTML", {
  vw_data <- list(
    price_points = list(
      pmc = list(value = 10.89, label = "PMC", desc = "Point of Marginal Cheapness"),
      opp = list(value = 17.50, label = "OPP", desc = "Optimal Price Point"),
      idp = list(value = 17.82, label = "IDP", desc = "Indifference Price Point"),
      pme = list(value = 27.35, label = "PME", desc = "Point of Marginal Expensiveness")
    ),
    acceptable_range = list(lower = 10.89, upper = 27.35),
    optimal_range = list(lower = 17.50, upper = 17.82),
    nms_results = list(trial_optimal = 15, revenue_optimal = 20)
  )

  html <- build_vw_price_points_table(vw_data, "$")
  expect_true(grepl("<table", html))
  expect_true(grepl("PMC", html))
  expect_true(grepl("OPP", html))
  expect_true(grepl("10.89", html))
  expect_true(grepl("Revenue Optimal", html))
})

test_that("build_gg_demand_table applies heatmap classes", {
  gg_data <- list(
    demand_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.9, 0.5, 0.2)),
    revenue_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.9, 0.5, 0.2), revenue_index = c(9, 10, 6))
  )

  html <- build_gg_demand_table(gg_data, "$")
  expect_true(grepl("<table", html))
  expect_true(grepl("pr-heat-high", html))  # 90% intent
  expect_true(grepl("pr-heat-med", html))   # 50% intent
  expect_true(grepl("pr-heat-low", html))   # 20% intent
  expect_true(grepl("pr-row-optimal", html))  # row with max revenue
})

test_that("build_gg_elasticity_table handles both column name conventions", {
  # Convention 1: price_from/price_to/elasticity_type
  el1 <- list(elasticity = data.frame(
    price_from = c(10, 20), price_to = c(20, 30),
    arc_elasticity = c(-0.5, -1.5), elasticity_type = c("Inelastic", "Elastic")
  ))
  html1 <- build_gg_elasticity_table(el1, "$")
  expect_true(grepl("Inelastic", html1))
  expect_true(grepl("Elastic", html1))

  # Convention 2: price_low/price_high/classification
  el2 <- list(elasticity = data.frame(
    price_low = c(10, 20), price_high = c(20, 30),
    arc_elasticity = c(-0.5, -1.5), classification = c("Inelastic", "Elastic")
  ))
  html2 <- build_gg_elasticity_table(el2, "$")
  expect_true(grepl("Inelastic", html2))
})

test_that("build_monadic_observed_table applies heatmap", {
  mon_data <- list(
    observed_data = data.frame(price = c(10, 20, 30), n = c(50, 50, 50), observed_intent = c(0.8, 0.5, 0.2))
  )
  html <- build_monadic_observed_table(mon_data, "$")
  expect_true(grepl("pr-heat-high", html))
  expect_true(grepl("pr-heat-low", html))
})


# ── Layer 3: Chart Builder ────────────────────────────────────────────────────

test_that("build_vw_curves_chart produces valid SVG", {
  vw_data <- list(
    curves = data.frame(
      price = seq(5, 30, by = 0.5),
      too_cheap = seq(1, 0, length.out = 51),
      cheap = seq(0.8, 0.1, length.out = 51),
      expensive = seq(0.1, 0.9, length.out = 51),
      too_expensive = seq(0, 1, length.out = 51)
    ),
    price_points = list(
      pmc = list(value = 10, label = "PMC", desc = "Point of Marginal Cheapness"),
      opp = list(value = 15, label = "OPP", desc = "Optimal Price Point"),
      idp = list(value = 18, label = "IDP", desc = "Indifference Price Point"),
      pme = list(value = 25, label = "PME", desc = "Point of Marginal Expensiveness")
    )
  )

  svg <- build_vw_curves_chart(vw_data, "#1e3a5f")
  expect_true(grepl("<svg", svg))
  expect_true(grepl("viewBox", svg))
  expect_true(grepl("polyline", svg))
  expect_true(grepl("PMC", svg))
  expect_true(grepl("OPP", svg))
  # SVG should contain all 4 curves as polylines
  n_polylines <- length(gregexpr("polyline", svg)[[1]])
  expect_true(n_polylines >= 4)  # 4 VW curves
})

test_that("build_demand_curve_chart produces valid SVG with tooltips", {
  prices <- seq(10, 30, by = 1)
  intents <- 1 / (1 + exp(0.2 * (prices - 20)))
  revenue <- prices * intents

  svg <- build_demand_curve_chart(
    prices = prices,
    intents = intents,
    revenue = revenue,
    optimal_price = 18,
    brand_colour = "#1e3a5f",
    currency = "$"
  )

  expect_true(grepl("<svg", svg))
  expect_true(grepl("viewBox", svg))
  expect_true(grepl("Optimal", svg))
  expect_true(grepl("data-tooltip", svg))  # tooltips present
  expect_true(grepl("Purchase Intent", svg))  # legend
  expect_true(grepl("Revenue Index", svg))  # legend
})

test_that("build_demand_curve_chart handles CI bands", {
  prices <- seq(10, 30, by = 2)
  intents <- seq(0.9, 0.1, length.out = length(prices))

  svg <- build_demand_curve_chart(
    prices = prices,
    intents = intents,
    ci_lower = intents - 0.05,
    ci_upper = intents + 0.05,
    observed_prices = c(10, 20, 30),
    observed_intents = c(0.85, 0.45, 0.12)
  )

  expect_true(grepl("polygon", svg))  # CI band
  expect_true(grepl("Observed", svg))  # observed tooltips
})

test_that("build_elasticity_chart handles non-finite values", {
  el_data <- data.frame(
    price_from = c(10, 20, 30),
    price_to = c(20, 30, 40),
    arc_elasticity = c(-0.5, Inf, -1.5)
  )

  svg <- build_elasticity_chart(el_data, "#1e3a5f", "$")
  expect_true(grepl("<svg", svg))
  # Inf value should be filtered out, leaving 2 points
  n_circles <- length(gregexpr("circle", svg)[[1]])
  expect_equal(n_circles, 2)
})

test_that("build_segment_comparison_chart produces bars", {
  seg_data <- list(
    comparison_table = data.frame(Segment = c("A", "B", "C"), OPP = c(15, 20, 25))
  )

  svg <- build_segment_comparison_chart(seg_data, "#1e3a5f", "$")
  expect_true(grepl("<svg", svg))
  expect_true(grepl("rect", svg))  # bars
  expect_true(grepl("rx=\"4\"", svg))  # rounded corners
  expect_true(grepl("data-tooltip", svg))
})

test_that("chart builder returns empty string for insufficient data", {
  expect_equal(build_vw_curves_chart(list(curves = NULL)), "")
  expect_equal(build_demand_curve_chart(c(1), c(0.5)), "")
  expect_equal(build_elasticity_chart(NULL), "")
  expect_equal(build_segment_comparison_chart(list(comparison_table = NULL)), "")
})


# ── Layer 4: Page Builder ────────────────────────────────────────────────────

test_that("build_pricing_page produces complete HTML document", {
  html_data <- list(
    meta = list(method = "gabor_granger", currency = "$", brand_colour = "#1e3a5f", project_name = "Test", generated = "2026-01-01", n_total = 200, n_valid = 195),
    summary = list(recommended_price = "$15.00", confidence_level = "HIGH", confidence_score = 0.85, n_valid = 195, callout = "<div>Test callout</div>"),
    van_westendorp = NULL,
    gabor_granger = list(callout = "<div>GG results</div>"),
    monadic = NULL,
    segments = NULL,
    recommendation = list(
      recommendation = list(price = 15, confidence = "HIGH", confidence_score = 0.85, source = "GG"),
      acceptable_range = list(lower = 10, upper = 25),
      callout = "<div>Recommendation</div>"
    )
  )
  tables <- list(gg_optimal = "<table><tr><td>$15.00</td></tr></table>")
  charts <- list(gg_demand = "<svg viewBox='0 0 800 400'></svg>")
  config <- list(brand_colour = "#1e3a5f", currency_symbol = "$", project_name = "Test Report")

  page <- build_pricing_page(html_data, tables, charts, config)

  # Complete HTML document
  expect_true(grepl("<!DOCTYPE html>", page))
  expect_true(grepl("<html", page))
  expect_true(grepl("</html>", page))
  expect_true(grepl("<meta charset", page))
  expect_true(grepl("<title>", page))

  # Gradient header
  expect_true(grepl("linear-gradient", page))
  expect_true(grepl("pr-header", page))

  # Dashboard summary
  expect_true(grepl("pr-dashboard", page))
  expect_true(grepl("pr-gauge-card", page))
  expect_true(grepl("\\$15.00", page))

  # Tab navigation
  expect_true(grepl("pr-tab-nav", page))
  expect_true(grepl("pr-tab-btn", page))

  # Content
  expect_true(grepl("panel-summary", page))
  expect_true(grepl("panel-gg", page))
  expect_true(grepl("panel-recommendation", page))

  # Print CSS
  expect_true(grepl("@page", page))
  expect_true(grepl("print-color-adjust", page))

  # Keyboard navigation JS
  expect_true(grepl("ArrowLeft", page))
  expect_true(grepl("ArrowRight", page))

  # Chart export JS
  expect_true(grepl("TurasCharts", page))
  expect_true(grepl("exportSVG", page))

  # Tooltip system
  expect_true(grepl("pr-tooltip", page))

  # Closing section
  expect_true(grepl("TURAS Analytics Platform", page))
  expect_true(grepl("Confidential", page))

  # Meta tags for Report Hub
  expect_true(grepl("turas-report-type", page))
  expect_true(grepl("turas-analysis-method", page))
})

test_that("build_pricing_css applies brand and accent tokens", {
  css <- build_pricing_css("#ff0000", "#00ff00")
  expect_true(grepl("#ff0000", css))
  expect_true(grepl("#00ff00", css))
  expect_false(grepl("BRAND_TOKEN", css))
  expect_false(grepl("ACCENT_TOKEN", css))
})

test_that("build_pricing_header includes gradient and print button", {
  meta <- list(method = "gabor_granger", n_valid = 200, generated = "2026-01-01")
  header <- build_pricing_header("My Project", meta, "#1e3a5f")
  expect_true(grepl("My Project", header))
  expect_true(grepl("pr-btn-print", header))
  expect_true(grepl("window.print", header))
})

test_that("build_dashboard_summary shows gauge cards", {
  html_data <- list(
    meta = list(method = "both", generated = "2026-01-01"),
    summary = list(recommended_price = "$20.00", confidence_level = "HIGH", confidence_score = 0.9, n_valid = 500),
    recommendation = list(acceptable_range = list(lower = 10, upper = 30))
  )
  config <- list(currency_symbol = "$")

  dashboard <- build_dashboard_summary(html_data, config)
  expect_true(grepl("pr-gauge-card", dashboard))
  expect_true(grepl("\\$20.00", dashboard))
  expect_true(grepl("HIGH", dashboard))
  expect_true(grepl("500", dashboard))
  expect_true(grepl("pr-meta-strip", dashboard))
})

test_that("build_pricing_js includes keyboard navigation", {
  js <- build_pricing_js()
  expect_true(grepl("keydown", js))
  expect_true(grepl("ArrowLeft", js))
  expect_true(grepl("ArrowRight", js))
  expect_true(grepl("switchTab", js))
  # Number key access
  expect_true(grepl('"1"', js))
})

test_that("build_pricing_closing includes branding", {
  closing <- build_pricing_closing(list(analyst_name = "John Smith"))
  expect_true(grepl("TURAS Analytics Platform", closing))
  expect_true(grepl("Confidential", closing))
  expect_true(grepl("John Smith", closing))
})


# ── Orchestrator: End-to-end ────────────────────────────────────────────────

test_that("generate_pricing_html_report writes valid file", {
  pricing_results <- list(
    method = "gabor_granger",
    results = list(
      demand_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.8, 0.5, 0.2)),
      revenue_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.8, 0.5, 0.2), revenue_index = c(8, 10, 6)),
      optimal_price = list(price = 20, purchase_intent = 0.5, revenue_index = 10),
      elasticity = data.frame(price_from = c(10, 20), price_to = c(20, 30), arc_elasticity = c(-0.6, -1.5), elasticity_type = c("Inelastic", "Elastic"))
    ),
    diagnostics = list(n_total = 100, n_valid = 100)
  )
  config <- list(currency_symbol = "$", project_name = "Test")

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp))

  report_dir <- file.path(TURAS_ROOT, "modules", "pricing", "lib", "html_report")
  result <- generate_pricing_html_report(pricing_results, tmp, config, report_dir = report_dir)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp))
  expect_true(result$file_size_bytes > 10000)  # at least 10KB
  expect_true(result$file_size_bytes < 5000000)  # under 5MB

  content <- paste(readLines(tmp), collapse = "\n")
  expect_true(grepl("<!DOCTYPE html>", content))
  expect_true(grepl("turas-report-type", content))
  expect_true(grepl("linear-gradient", content))
})
