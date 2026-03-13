# ==============================================================================
# TURAS PRICING MODULE - OUTPUT FILE VALIDATION TESTS
# ==============================================================================
#
# Tests that generated output files meet structural requirements:
#   - HTML contains DOCTYPE, charset, title
#   - Self-contained (no external resource references)
#   - SVG charts present when expected
#   - Meta tags for Report Hub integration
# ==============================================================================


# ── HTML Report File Validation ──────────────────────────────────────────────

test_that("HTML report is a valid self-contained document", {
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
      recommendation = list(price = 16.99, confidence = "HIGH", confidence_score = 0.85, source = "GG"),
      acceptable_range = list(lower = 10, upper = 25, lower_desc = "Low", upper_desc = "High"),
      evidence_table = data.frame(method = "GG", metric = "Optimal", value = "$15.00", interpretation = "Rev max", stringsAsFactors = FALSE),
      risks = list(downside = c("Price may be too low"))
    ),
    segment_results = list(
      comparison_table = data.frame(Segment = c("A", "B"), OPP = c(15, 20)),
      insights = c("Segment B higher")
    ),
    diagnostics = list(n_total = 200, n_valid = 195)
  )
  config <- list(currency_symbol = "$", brand_colour = "#1e3a5f", project_name = "Output Test")

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp))

  report_dir <- file.path(TURAS_ROOT, "modules", "pricing", "lib", "html_report")
  result <- generate_pricing_html_report(pricing_results, tmp, config, report_dir = report_dir)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp))

  content <- paste(readLines(tmp), collapse = "\n")

  # 1. DOCTYPE and HTML structure
  expect_true(grepl("<!DOCTYPE html>", content))
  expect_true(grepl("<html", content))
  expect_true(grepl("</html>", content))
  expect_true(grepl("<head>", content))
  expect_true(grepl("</head>", content))
  expect_true(grepl("<body", content))
  expect_true(grepl("</body>", content))

  # 2. Character encoding
  expect_true(grepl('charset="UTF-8"', content) || grepl("charset=UTF-8", content))

  # 3. Title present
  expect_true(grepl("<title>", content))
  expect_true(grepl("Output Test", content))

  # 4. Self-contained: no external stylesheets or scripts
  expect_false(grepl('<link[^>]*rel="stylesheet"[^>]*href="http', content))
  expect_false(grepl('<script[^>]*src="http', content))

  # 5. All CSS is inline (in <style> tags)
  expect_true(grepl("<style>", content) || grepl("<style ", content))

  # 6. All JS is inline (in <script> tags without src)
  # The script tags should exist but not reference external URLs
  expect_true(grepl("<script>", content))

  # 7. SVG charts present (both VW and GG)
  expect_true(grepl("<svg", content))
  expect_true(grepl("viewBox", content))

  # 8. Report Hub meta tags
  expect_true(grepl('name="turas-report-type"', content))
  expect_true(grepl('name="turas-analysis-method"', content))
  expect_true(grepl("pricing", content))

  # 9. File size reasonable (10KB - 5MB)
  expect_true(result$file_size_bytes > 10000)
  expect_true(result$file_size_bytes < 5000000)

  # 10. Insight areas present (one per section)
  expect_true(grepl("pr-insight-area", content))
  expect_true(grepl("pr-insight-toggle", content))

  # 11. Pin system present
  expect_true(grepl("pr-pin-btn", content))
  expect_true(grepl("panel-pinned", content))
  expect_true(grepl("pinned-views-data", content))

  # 12. Export toolbar present
  expect_true(grepl("pr-export-toolbar", content))
  expect_true(grepl("exportChartPNG", content))
  expect_true(grepl("exportTableExcel", content))

  # 13. About tab present
  expect_true(grepl("panel-about", content))
  expect_true(grepl("About This Report", content))

  # 14. Save Report button present
  expect_true(grepl("saveReportHTML", content))

  # 15. Simulator tab present (both VW and GG data available)
  expect_true(grepl("panel-simulator", content))
  expect_true(grepl("PRICING_DATA", content))
})


# ── Simulator File Validation ────────────────────────────────────────────────

test_that("simulator HTML is a valid self-contained document", {
  pricing_results <- list(
    method = "gabor_granger",
    results = list(
      demand_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.8, 0.5, 0.2)),
      revenue_curve = data.frame(revenue_index = c(8, 10, 6)),
      optimal_price = list(price = 20)
    ),
    segment_results = NULL
  )
  config <- list(currency_symbol = "$", brand_colour = "#1e3a5f", project_name = "Sim Test")

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp))

  sim_dir <- file.path(TURAS_ROOT, "modules", "pricing", "lib", "simulator")
  result <- build_pricing_simulator(pricing_results, tmp, config, sim_dir = sim_dir)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp))

  content <- paste(readLines(tmp), collapse = "\n")

  # 1. DOCTYPE and structure
  expect_true(grepl("<!DOCTYPE html>", content))
  expect_true(grepl("<html", content))
  expect_true(grepl("</html>", content))
  expect_true(grepl('charset', content))

  # 2. Self-contained — no external resources
  expect_false(grepl('<link[^>]*href="http', content))
  expect_false(grepl('<script[^>]*src="http', content))

  # 3. CSS embedded inline
  expect_true(grepl("<style>", content) || grepl("<style ", content))
  expect_true(grepl("sim-header", content))

  # 4. JS embedded inline
  expect_true(grepl("<script>", content))
  expect_true(grepl("TurasSimulator", content))

  # 5. Data embedded
  expect_true(grepl("PRICING_DATA", content))
  expect_true(grepl("PRICING_CONFIG", content))

  # 6. Interactive elements present
  expect_true(grepl("sim-price-slider", content))
  expect_true(grepl("sim-chart-area", content))

  # 7. File size > 5KB (CSS+JS alone are ~25KB)
  expect_true(result$file_size_bytes > 5000)
})


# ── HTML Report Without Synthesis ────────────────────────────────────────────

test_that("HTML report works without synthesis/recommendation", {
  pricing_results <- list(
    method = "gabor_granger",
    results = list(
      demand_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.8, 0.5, 0.2)),
      revenue_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.8, 0.5, 0.2), revenue_index = c(8, 10, 6)),
      optimal_price = list(price = 20, purchase_intent = 0.5, revenue_index = 10)
    ),
    synthesis = NULL,
    segment_results = NULL,
    diagnostics = list(n_total = 50, n_valid = 50)
  )
  config <- list(currency_symbol = "$")

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp))

  report_dir <- file.path(TURAS_ROOT, "modules", "pricing", "lib", "html_report")
  result <- generate_pricing_html_report(pricing_results, tmp, config, report_dir = report_dir)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp))

  content <- paste(readLines(tmp), collapse = "\n")
  expect_true(grepl("<!DOCTYPE html>", content))
  # No recommendation panel expected
  expect_false(grepl("panel-recommendation", content))
})


# ── Report with Monadic Method ───────────────────────────────────────────────

test_that("HTML report includes monadic-specific elements", {
  pricing_results <- list(
    method = "monadic",
    results = list(
      demand_curve = data.frame(price = seq(10, 40, length.out = 50), predicted_intent = seq(0.9, 0.1, length.out = 50), revenue_index = seq(10, 40, length.out = 50) * seq(0.9, 0.1, length.out = 50)),
      observed_data = data.frame(price = c(15, 20, 25, 30), n = c(50, 50, 50, 50), observed_intent = c(0.8, 0.6, 0.4, 0.2)),
      optimal_price = list(price = 22, predicted_intent = 0.5, revenue_index = 11),
      model_summary = list(model_type = "logistic", n_observations = 200, pseudo_r2 = 0.15, aic = 250, null_deviance = 300, residual_deviance = 255, price_coefficient_p = 0.001)
    ),
    diagnostics = list(n_total = 200, n_valid = 200)
  )
  config <- list(currency_symbol = "$", project_name = "Monadic Output")

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp))

  report_dir <- file.path(TURAS_ROOT, "modules", "pricing", "lib", "html_report")
  result <- generate_pricing_html_report(pricing_results, tmp, config, report_dir = report_dir)

  expect_equal(result$status, "PASS")

  content <- paste(readLines(tmp), collapse = "\n")
  expect_true(grepl("panel-monadic", content))
  expect_true(grepl("<svg", content))  # monadic demand chart
  expect_true(grepl("logistic", content, ignore.case = TRUE))

  # New features present in monadic reports
  expect_true(grepl("panel-about", content))
  expect_true(grepl("pr-insight-area", content))
  expect_true(grepl("pr-pin-btn", content))
  expect_true(grepl("panel-simulator", content))  # monadic has demand curve for simulator
})
