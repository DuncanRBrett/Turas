# ==============================================================================
# TURAS PRICING MODULE - THE FILES A RUN WRITES
# ==============================================================================
# The module's own tabbed HTML report is retired (Session B, B4): pricing
# results appear in the client's interactive report as the Pricing tab, and
# the simulator is a standalone file again. What used to be four HTML-report
# tests here is now one test of the deliverable that survived, plus a check
# that the retired one is gone rather than half-present.
#
# The simulator's own behaviour is covered in test_simulator.R; this file
# checks the document a client receives.
# ==============================================================================

skip_if(!exists("generate_pricing_simulator", mode = "function"), "simulator not available")

test_that("the simulator is a valid self-contained document", {
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
  invisible(capture.output(
    result <- generate_pricing_simulator(pricing_results, tmp, config, verbose = FALSE)))

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp))
  content <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

  # 1. DOCTYPE and structure
  expect_true(grepl("<!DOCTYPE html>", content, fixed = TRUE))
  expect_true(grepl("<html", content, fixed = TRUE))
  expect_true(grepl("</html>", content, fixed = TRUE))
  expect_true(grepl("charset", content, fixed = TRUE))

  # 2. Self-contained: nothing is fetched when the client opens it
  expect_false(grepl('<link[^>]*href="http', content))
  expect_false(grepl('<script[^>]*src="http', content))

  # 3. CSS inline
  expect_true(grepl("<style>", content, fixed = TRUE))
  expect_true(grepl("sim-header", content, fixed = TRUE))

  # 4. JS inline
  expect_true(grepl("PricingSimulator", content, fixed = TRUE))

  # 5. Data inline, as parseable islands
  expect_true(grepl('id="pricing-simulator-data"', content, fixed = TRUE))
  expect_true(grepl('id="pricing-simulator-config"', content, fixed = TRUE))

  # 6. The controls the engine binds
  expect_true(grepl("sim-price-slider", content, fixed = TRUE))
  expect_true(grepl("sim-chart-area", content, fixed = TRUE))

  # 7. Big enough to actually carry the CSS and JS
  expect_gt(file.info(tmp)$size, 5000)
})

test_that("the retired HTML report is gone, not half-present", {
  # A half-retirement is the failure mode: the builder deleted but a caller
  # still reaching for it, or the reverse.
  root <- file.path(TURAS_ROOT, "modules", "pricing")
  expect_false(dir.exists(file.path(root, "lib", "html_report")))
  expect_false(dir.exists(file.path(root, "lib", "simulator")))
  expect_false(exists("generate_pricing_html_report", mode = "function"))
  expect_false(exists("build_pricing_simulator", mode = "function"))

  main <- paste(readLines(file.path(root, "R", "00_main.R"), warn = FALSE), collapse = "\n")
  expect_false(grepl("html_report", main, fixed = TRUE))
  expect_true(grepl("generate_pricing_simulator", main, fixed = TRUE))
})

test_that("a config still carrying Generate_HTML_Report is answered by name and runs on", {
  skip_if(!exists("apply_pricing_defaults", mode = "function"), "config loader not available")
  out <- capture.output(
    cfg <- .pricing_check_setting_names(c("Project_Name", "Generate_HTML_Report"), "Settings"))
  joined <- paste(out, collapse = " ")
  expect_true(grepl("SETTING WITHDRAWN", joined, fixed = TRUE))
  expect_true(grepl("Pricing tab", joined, fixed = TRUE))
  expect_true(grepl("Generate_Simulator", joined, fixed = TRUE))
  expect_true(grepl("The run continues", joined, fixed = TRUE))
  # ...and it is not also reported as a name the module does not know.
  expect_false(grepl("does not read", joined, fixed = TRUE))
})

test_that("the flag is neutralised, so nothing downstream believes a report exists", {
  skip_if(!exists("apply_pricing_defaults", mode = "function"), "config loader not available")
  cfg <- apply_pricing_defaults(list(analysis_method = "gabor_granger",
                                     generate_html_report = "TRUE"))
  expect_false(isTRUE(cfg$generate_html_report))
})
