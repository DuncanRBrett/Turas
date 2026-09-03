# ==============================================================================
# TURAS PRICING MODULE - THE STANDALONE SIMULATOR (Session B, B4)
# ==============================================================================
# The simulator is a standalone HTML file again, linked from the v2 Pricing
# tab rather than embedded in a report (programme decision D2). This file
# covers the demand extraction it is built from, the islands it embeds, and
# the two defects fixed as the engine moved: P1c (a segment drawn against the
# total sample's price axis) and P3a (one name, "Revenue Index", carrying
# three different scales).
#
# The extraction tests are the ones the retired builder had; the page tests
# and the two regressions are new.
# ==============================================================================

skip_if(!exists("extract_demand_data", mode = "function"), "simulator parts not available")

# ── Demand data extraction ────────────────────────────────────────────────────

test_that("extract_demand_data works for gabor_granger method", {
  results <- list(
    demand_curve = data.frame(price = c(10, 20, 30), purchase_intent = c(0.8, 0.5, 0.2)),
    revenue_curve = data.frame(revenue_index = c(8, 10, 6))
  )
  dd <- extract_demand_data(results, "gabor_granger")
  expect_false(is.null(dd))
  expect_equal(length(dd$price_range), 3)
  expect_equal(dd$demand_curve, c(0.8, 0.5, 0.2))
  expect_equal(dd$revenue_curve, c(8, 10, 6))
})

test_that("extract_demand_data falls back to price times intent without a revenue curve", {
  results <- list(demand_curve = data.frame(price = c(10, 20), purchase_intent = c(0.8, 0.4)))
  dd <- extract_demand_data(results, "gabor_granger")
  expect_equal(dd$revenue_curve, c(8, 8))
})

test_that("extract_demand_data works for monadic method", {
  results <- list(demand_curve = data.frame(price = c(5, 10), predicted_intent = c(0.9, 0.4),
                                            revenue_index = c(4.5, 4)))
  dd <- extract_demand_data(results, "monadic")
  expect_equal(dd$demand_curve, c(0.9, 0.4))
  expect_equal(dd$revenue_curve, c(4.5, 4))
})

test_that("extract_demand_data works for the both method, taking the GG curve", {
  results <- list(gabor_granger = list(
    demand_curve = data.frame(price = c(10, 20), purchase_intent = c(0.7, 0.3)),
    revenue_curve = data.frame(revenue_index = c(7, 6))))
  dd <- extract_demand_data(results, "both")
  expect_equal(dd$demand_curve, c(0.7, 0.3))
})

test_that("a Van Westendorp run on its own has no demand curve to simulate", {
  # VW measures price perceptions, not demand at a price. The NMS extension
  # would give one and is refused until it has a golden (Session A review F3),
  # so nothing here should invent a curve.
  expect_null(extract_demand_data(list(price_points = list(OPP = 30)), "van_westendorp"))
  expect_null(extract_demand_data(list(), "gabor_granger"))
  expect_null(extract_demand_data(list(), "unknown"))
})

test_that("extract_optimal_price works for each method", {
  expect_equal(extract_optimal_price(list(optimal_price = list(price = 25)), "monadic"), 25)
  expect_equal(extract_optimal_price(list(optimal_price = list(price = 30)), "gabor_granger"), 30)
  expect_equal(extract_optimal_price(
    list(gabor_granger = list(optimal_price = list(price = 40))), "both"), 40)
  expect_null(extract_optimal_price(list(), "van_westendorp"))
})

test_that("extract_segment_demand extracts one curve per segment", {
  seg <- list(segment_results = list(
    Premium = list(demand_curve = data.frame(price = c(10, 20), purchase_intent = c(0.9, 0.6)),
                   revenue_curve = data.frame(revenue_index = c(9, 12))),
    Budget = list(demand_curve = data.frame(price = c(10, 20), purchase_intent = c(0.5, 0.1)),
                  revenue_curve = data.frame(revenue_index = c(5, 2)))))
  out <- extract_segment_demand(seg, "gabor_granger")
  expect_setequal(names(out), c("Premium", "Budget"))
  expect_equal(out$Premium$demand_curve, c(0.9, 0.6))
})

test_that("extract_segment_demand returns an empty list for nothing", {
  expect_equal(length(extract_segment_demand(NULL, "gabor_granger")), 0)
  expect_equal(length(extract_segment_demand(list(), "gabor_granger")), 0)
})

# ── The islands ───────────────────────────────────────────────────────────────

test_that("the data island is real JSON with the curves and the optimum", {
  dd <- list(price_range = c(10, 20, 30), demand_curve = c(0.8, 0.5, 0.2),
             revenue_curve = c(8, 10, 6))
  js <- build_pricing_json(dd, 20, list())
  parsed <- jsonlite::fromJSON(js)
  expect_equal(parsed$price_range, c(10, 20, 30))
  expect_equal(parsed$demand_curve, c(0.8, 0.5, 0.2))
  expect_equal(parsed$optimal_price, 20)
  expect_false("segments" %in% names(parsed))
})

test_that("segments travel with their own price grid", {
  # P1c: the engine reads prices and intents from the same object, so each
  # segment must carry its own grid rather than borrowing the total's.
  dd <- list(price_range = c(10, 20, 30), demand_curve = c(0.8, 0.5, 0.2),
             revenue_curve = c(8, 10, 6))
  segs <- list(Premium = list(price_range = c(15, 25), demand_curve = c(0.9, 0.6),
                              revenue_curve = c(13.5, 15)))
  parsed <- jsonlite::fromJSON(build_pricing_json(dd, 20, segs))
  expect_equal(parsed$segments$Premium$price_range, c(15, 25))
  expect_equal(parsed$segments$Premium$demand_curve, c(0.9, 0.6))
})

test_that("a one-point curve still arrives as an array", {
  parsed <- jsonlite::fromJSON(build_pricing_json(
    list(price_range = 10, demand_curve = 0.5, revenue_curve = 5), NULL, list()),
    simplifyVector = FALSE)
  expect_true(is.list(parsed$price_range))
  expect_equal(length(parsed$price_range), 1)
})

test_that("the config island carries the study's own currency and cost", {
  parsed <- jsonlite::fromJSON(build_simulator_config_json(
    list(currency_symbol = "R", brand_colour = "#0d8a8a", unit_cost = 42.5,
         project_name = "Karoo")))
  expect_equal(parsed$currency, "R")
  expect_equal(parsed$unit_cost, 42.5)
  expect_equal(parsed$project_name, "Karoo")
  expect_equal(length(parsed$scenarios), 0)
})

test_that("a nonsense unit cost becomes zero rather than reaching the page", {
  expect_equal(jsonlite::fromJSON(build_simulator_config_json(list(unit_cost = -5)))$unit_cost, 0)
  expect_equal(jsonlite::fromJSON(build_simulator_config_json(list(unit_cost = "abc")))$unit_cost, 0)
})

test_that("preset scenarios come from a data frame or a list, and bad rows are dropped", {
  df <- data.frame(name = c("Value", "Premium"), price = c(60, 120),
                   description = c("Entry", "Top"), stringsAsFactors = FALSE)
  out <- build_scenarios_list(df)
  expect_equal(length(out), 2)
  expect_equal(out[[1]]$name, "Value")
  expect_equal(out[[2]]$price, 120)

  lst <- list(list(name = "A", price = 10), list(name = "B", price = "not a price"))
  out2 <- build_scenarios_list(lst)
  expect_equal(length(out2), 1)
  expect_equal(out2[[1]]$name, "A")

  expect_equal(length(build_scenarios_list(NULL)), 0)
  expect_equal(length(build_scenarios_list(list())), 0)
})

test_that("an island cannot close the script element it lives in", {
  # P2a: real JSON plus island escaping, in place of the hand-rolled escaper.
  segs <- list("</script><script>alert(1)" = list(price_range = c(1, 2),
                                                  demand_curve = c(0.5, 0.4),
                                                  revenue_curve = c(0.5, 0.8)))
  js <- build_pricing_json(list(price_range = c(1, 2), demand_curve = c(0.5, 0.4),
                                revenue_curve = c(0.5, 0.8)), 1, segs)
  expect_false(grepl("</script", js, fixed = TRUE))
  # jsonlite also escapes the slash, so the escaped form is \u003c\/script.
  expect_true(grepl("\\u003c", js, fixed = TRUE))
  restored <- jsonlite::fromJSON(js)
  expect_true("</script><script>alert(1)" %in% names(restored$segments))

  cfg <- build_simulator_config_json(list(project_name = "</script>Karoo"))
  expect_false(grepl("</script", cfg, fixed = TRUE))
})

# ── The page ──────────────────────────────────────────────────────────────────

sim_results <- function(with_segments = FALSE) {
  gg <- list(demand_curve = data.frame(price = c(60, 80, 100, 120),
                                       purchase_intent = c(0.9, 0.75, 0.5, 0.25)),
             revenue_curve = data.frame(revenue_index = c(54, 60, 50, 30)),
             optimal_price = list(price = 80))
  out <- list(method = "gabor_granger", results = gg)
  if (with_segments) {
    out$segment_results <- list(segment_results = list(
      Premium = list(demand_curve = data.frame(price = c(70, 90, 110),
                                               purchase_intent = c(0.95, 0.8, 0.6)),
                     revenue_curve = data.frame(revenue_index = c(66.5, 72, 66)))))
  }
  out
}

sim_file <- function() file.path(tempdir(), paste0("sim_", sample.int(1e6, 1), ".html"))

test_that("the simulator writes a self-contained page with its data inlined", {
  skip_if(!exists("generate_pricing_simulator", mode = "function"), "simulator not available")
  f <- sim_file()
  invisible(capture.output(
    res <- generate_pricing_simulator(sim_results(), f,
                                      list(currency_symbol = "R", project_name = "Karoo",
                                           unit_cost = 45), verbose = FALSE)))
  expect_equal(res$status, "PASS")
  expect_true(file.exists(f))
  html <- paste(readLines(f, warn = FALSE), collapse = "\n")

  expect_true(grepl('id="panel-simulator"', html, fixed = TRUE))
  expect_true(grepl('id="sim-price-slider"', html, fixed = TRUE))
  expect_true(grepl('id="pricing-simulator-data"', html, fixed = TRUE))
  expect_true(grepl('id="pricing-simulator-config"', html, fixed = TRUE))
  expect_true(grepl("PricingSimulator", html, fixed = TRUE))
  # Self-contained: no external stylesheet, script or font.
  expect_false(grepl('src="http', html, fixed = TRUE))
  expect_false(grepl('href="http', html, fixed = TRUE))
  # And the report layer it came out of is not dragged along.
  expect_false(grepl("pinSection", html, fixed = TRUE))
  expect_false(grepl("toggleInsight", html, fixed = TRUE))
})

test_that("the page carries the study's own currency and no em dash", {
  skip_if(!exists("generate_pricing_simulator", mode = "function"), "simulator not available")
  f <- sim_file()
  invisible(capture.output(
    generate_pricing_simulator(sim_results(), f,
                               list(currency_symbol = "R", project_name = "Karoo Coffee"),
                               verbose = FALSE)))
  html <- paste(readLines(f, warn = FALSE), collapse = "\n")
  expect_true(grepl('"currency":"R"', html, fixed = TRUE))
  expect_false(grepl("\u2014", html))
})

test_that("a hostile project name cannot break out of the page", {
  skip_if(!exists("generate_pricing_simulator", mode = "function"), "simulator not available")
  f <- sim_file()
  invisible(capture.output(
    generate_pricing_simulator(sim_results(), f,
                               list(project_name = '</title><script>alert(1)</script>'),
                               verbose = FALSE)))
  html <- paste(readLines(f, warn = FALSE), collapse = "\n")
  expect_false(grepl("<script>alert(1)</script>", html, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;", html, fixed = TRUE))
})

test_that("the segment toggle appears only when there are segments", {
  skip_if(!exists("generate_pricing_simulator", mode = "function"), "simulator not available")
  f1 <- sim_file(); f2 <- sim_file()
  invisible(capture.output({
    generate_pricing_simulator(sim_results(FALSE), f1, list(currency_symbol = "R"), verbose = FALSE)
    generate_pricing_simulator(sim_results(TRUE), f2, list(currency_symbol = "R"), verbose = FALSE)
  }))
  a <- paste(readLines(f1, warn = FALSE), collapse = "\n")
  b <- paste(readLines(f2, warn = FALSE), collapse = "\n")
  expect_true(grepl('id="sim-segment-section" style="display:none;"', a, fixed = TRUE))
  expect_true(grepl('id="sim-segment-buttons"', b, fixed = TRUE))
  expect_true(grepl('"Premium"', b, fixed = TRUE))
})

test_that("the simulator refuses when there is no demand curve to move along", {
  skip_if(!exists("generate_pricing_simulator", mode = "function"), "simulator not available")
  f <- sim_file()
  res <- generate_pricing_simulator(
    list(method = "van_westendorp", results = list(price_points = list(OPP = 30))),
    f, list(), verbose = FALSE)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "DATA_SIMULATOR_NO_CURVE")
  expect_false(file.exists(f))
})

# ── The two defects fixed as the engine moved ─────────────────────────────────

test_that("P1c: the chart reads prices and intents from the same object", {
  js <- paste(readLines(file.path(TURAS_ROOT, "modules", "pricing", "lib",
                                  "html_simulator", "js", "pricing_simulator.js"),
                        warn = FALSE), collapse = "\n")
  # The defect was: prices from data.price_range, intents from the segment.
  expect_false(grepl("var prices = data.price_range;\n    var intents = (segment",
                     js, fixed = TRUE))
  expect_true(grepl("var series = (segment !== \"total\" && data.segments && data.segments[segment])",
                    js, fixed = TRUE))
  expect_true(grepl("var prices = series.price_range;", js, fixed = TRUE))
  expect_true(grepl("var intents = series.demand_curve;", js, fixed = TRUE))
  # And a mismatched pair is refused rather than drawn.
  expect_true(grepl("prices.length !== intents.length", js, fixed = TRUE))
})

test_that("P3a: Revenue Index names one scale, and % of optimum is its own row", {
  js <- paste(readLines(file.path(TURAS_ROOT, "modules", "pricing", "lib",
                                  "html_simulator", "js", "pricing_simulator.js"),
                        warn = FALSE), collapse = "\n")
  # The comparison table used to print revenue as an index to the optimum
  # under the same name the metric card gave the raw figure.
  expect_false(grepl("revenueIndex", js, fixed = TRUE))
  expect_false(grepl("profitIndex", js, fixed = TRUE))
  expect_true(grepl("Revenue, % of optimum", js, fixed = TRUE))
  expect_true(grepl("Profit, % of optimum", js, fixed = TRUE))
  # The chart's fitted line no longer borrows the name.
  expect_true(grepl("Revenue (scaled to fit)", js, fixed = TRUE))
  expect_false(grepl(">Revenue Index</text>", js, fixed = TRUE))
})

test_that("the engine is syntactically valid and safe to inline", {
  js_path <- file.path(TURAS_ROOT, "modules", "pricing", "lib", "html_simulator",
                       "js", "pricing_simulator.js")
  src <- paste(readLines(js_path, warn = FALSE), collapse = "\n")
  expect_false(grepl("</script", src, fixed = TRUE))
  expect_false(grepl("\u2014", src))
  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node not on PATH")
  expect_equal(system2(node, c("--check", shQuote(js_path)),
                       stdout = FALSE, stderr = FALSE), 0L)
})
