# ==============================================================================
# TURAS PRICING MODULE - SIMULATOR TESTS
# ==============================================================================
#
# Tests for the interactive pricing simulator builder
# ==============================================================================

# ── Demand Data Extraction ────────────────────────────────────────────────────

test_that("extract_demand_data works for gabor_granger method", {
  results <- list(
    demand_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.8, 0.5, 0.2)),
    revenue_curve = data.frame(revenue_index = c(8, 10, 6))
  )
  dd <- extract_demand_data(results, "gabor_granger")
  expect_false(is.null(dd))
  expect_equal(length(dd$price_range), 3)
  expect_equal(length(dd$demand_curve), 3)
  expect_equal(dd$demand_curve, c(0.8, 0.5, 0.2))
})

test_that("extract_demand_data works for monadic method", {
  results <- list(
    demand_curve = data.frame(price = seq(10, 30, by = 1), predicted_intent = seq(0.9, 0.1, length.out = 21), revenue_index = seq(10, 30, by = 1) * seq(0.9, 0.1, length.out = 21))
  )
  dd <- extract_demand_data(results, "monadic")
  expect_false(is.null(dd))
  expect_equal(length(dd$price_range), 21)
})

test_that("extract_demand_data works for both method", {
  results <- list(
    gabor_granger = list(
      demand_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.8, 0.5, 0.2)),
      revenue_curve = data.frame(revenue_index = c(8, 10, 6))
    )
  )
  dd <- extract_demand_data(results, "both")
  expect_false(is.null(dd))
})

test_that("extract_demand_data works for van_westendorp method with NMS", {
  results <- list(
    nms_results = list(
      data = data.frame(price = c(10, 20, 30), trial = c(0.7, 0.5, 0.3), revenue = c(7, 10, 9))
    )
  )
  dd <- extract_demand_data(results, "van_westendorp")
  expect_false(is.null(dd))
})

test_that("extract_demand_data returns NULL for missing data", {
  expect_null(extract_demand_data(list(), "gabor_granger"))
  expect_null(extract_demand_data(list(), "monadic"))
  expect_null(extract_demand_data(list(), "unknown_method"))
})


# ── Optimal Price Extraction ────────────────────────────────────────────────

test_that("extract_optimal_price works for each method", {
  expect_equal(
    extract_optimal_price(list(optimal_price = list(price = 20)), "gabor_granger"),
    20
  )
  expect_equal(
    extract_optimal_price(list(optimal_price = list(price = 18)), "monadic"),
    18
  )
})


# ── Segment Demand Extraction ────────────────────────────────────────────────

test_that("extract_segment_demand extracts per-segment data", {
  seg_results <- list(
    segment_results = list(
      "Seg A" = list(
        demand_curve = data.frame(price = c(10, 20), purchase_intent = c(0.8, 0.4)),
        revenue_curve = data.frame(revenue_index = c(8, 8))
      ),
      "Seg B" = list(
        demand_curve = data.frame(price = c(10, 20), purchase_intent = c(0.6, 0.3)),
        revenue_curve = data.frame(revenue_index = c(6, 6))
      )
    )
  )
  seg_data <- extract_segment_demand(seg_results, "gabor_granger")
  expect_equal(length(seg_data), 2)
  expect_true("Seg A" %in% names(seg_data))
})

test_that("extract_segment_demand returns empty list for NULL input", {
  expect_equal(extract_segment_demand(NULL, "gabor_granger"), list())
})


# ── JSON Builders ────────────────────────────────────────────────────────────

test_that("build_pricing_json produces valid JSON structure", {
  demand_data <- list(
    price_range = c(10, 20, 30),
    demand_curve = c(0.8, 0.5, 0.2),
    revenue_curve = c(8, 10, 6)
  )
  json <- build_pricing_json(demand_data, 20, list())
  expect_true(grepl("price_range", json))
  expect_true(grepl("demand_curve", json))
  expect_true(grepl("optimal_price", json))
  expect_true(grepl("20.00", json))

  # Verify JSON is parseable
  parsed <- jsonlite::fromJSON(json)
  expect_equal(length(parsed$price_range), 3)
})

test_that("build_pricing_json includes segment data", {
  demand_data <- list(price_range = c(10, 20), demand_curve = c(0.8, 0.4), revenue_curve = c(8, 8))
  seg_data <- list("Seg A" = list(price_range = c(10, 20), demand_curve = c(0.9, 0.5)))
  json <- build_pricing_json(demand_data, 15, seg_data)
  expect_true(grepl("Seg A", json))
})

test_that("build_scenarios_json handles data frame format", {
  scenarios <- data.frame(
    name = c("Economy", "Premium"),
    price = c(10, 25),
    description = c("Low price", "High price"),
    stringsAsFactors = FALSE
  )
  json <- build_scenarios_json(scenarios, "$")
  expect_true(grepl("Economy", json))
  expect_true(grepl("Premium", json))

  parsed <- jsonlite::fromJSON(json)
  expect_equal(nrow(parsed), 2)
})

test_that("build_scenarios_json handles list format", {
  scenarios <- list(
    list(name = "Budget", price = 10, description = "Entry level"),
    list(name = "Pro", price = 30, description = "Professional")
  )
  json <- build_scenarios_json(scenarios, "$")
  expect_true(grepl("Budget", json))
  expect_true(grepl("Pro", json))
})

test_that("build_scenarios_json returns [] for empty input", {
  expect_equal(build_scenarios_json(NULL, "$"), "[]")
  expect_equal(build_scenarios_json(list(), "$"), "[]")
})

test_that("jsonEscape handles special characters", {
  expect_true(grepl("\\\\n", jsonEscape("line\nbreak")))
  expect_true(grepl("\\\\t", jsonEscape("tab\there")))
  expect_equal(jsonEscape(NULL), "")
  expect_equal(jsonEscape(NA), "")
})


# ── CSS/JS Embedding (Critical Bug Test) ────────────────────────────────────

test_that("build_pricing_simulator embeds non-empty CSS and JS", {
  pricing_results <- list(
    method = "gabor_granger",
    results = list(
      demand_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.8, 0.5, 0.2)),
      revenue_curve = data.frame(revenue_index = c(8, 10, 6)),
      optimal_price = list(price = 20)
    ),
    segment_results = NULL
  )
  config <- list(currency_symbol = "$", brand_colour = "#1e3a5f", project_name = "Test Sim")

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp))

  sim_dir <- file.path(TURAS_ROOT, "modules", "pricing", "lib", "simulator")
  result <- build_pricing_simulator(pricing_results, tmp, config, sim_dir = sim_dir)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp))
  expect_true(result$file_size_bytes > 5000)  # must be > 5KB (CSS+JS alone are ~25KB)

  content <- paste(readLines(tmp), collapse = "\n")

  # CSS must be embedded (not empty)
  expect_true(grepl("sim-header", content))
  expect_true(grepl("sim-metric", content))
  expect_true(grepl("sim-chart-area", content))

  # JS must be embedded (not empty)
  expect_true(grepl("TurasSimulator", content))
  expect_true(grepl("interpolateIntent", content))
  expect_true(grepl("updateChart", content))

  # Data must be embedded
  expect_true(grepl("PRICING_DATA", content))
  expect_true(grepl("PRICING_CONFIG", content))

  # Gradient header
  expect_true(grepl("linear-gradient", content))
})


# ── HTML Structure ────────────────────────────────────────────────────────────

test_that("simulator HTML has correct structure", {
  pricing_results <- list(
    method = "gabor_granger",
    results = list(
      demand_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.8, 0.5, 0.2)),
      revenue_curve = data.frame(revenue_index = c(8, 10, 6)),
      optimal_price = list(price = 20)
    ),
    segment_results = NULL
  )
  config <- list(currency_symbol = "$")

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp))

  sim_dir <- file.path(TURAS_ROOT, "modules", "pricing", "lib", "simulator")
  result <- build_pricing_simulator(pricing_results, tmp, config, sim_dir = sim_dir)

  content <- paste(readLines(tmp), collapse = "\n")

  expect_true(grepl("<!DOCTYPE html>", content))
  expect_true(grepl("charset", content))
  expect_true(grepl("turas-report-type", content))
  expect_true(grepl("pricing-simulator", content))
  expect_true(grepl("sim-price-slider", content))
  expect_true(grepl("sim-compare-section", content))
  expect_true(grepl("DOMContentLoaded", content))
})

test_that("simulator refuses when no demand data available", {
  pricing_results <- list(
    method = "unknown",
    results = list(),
    segment_results = NULL
  )
  config <- list()

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp))

  sim_dir <- file.path(TURAS_ROOT, "modules", "pricing", "lib", "simulator")
  result <- build_pricing_simulator(pricing_results, tmp, config, sim_dir = sim_dir)

  expect_equal(result$status, "REFUSED")
  expect_false(file.exists(tmp))
})
