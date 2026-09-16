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

# ------------------------------------------------------------------------------
# F4 + F6: the completeness exclusion reaches the workbook a client receives
# ------------------------------------------------------------------------------

test_that("the Validation sheet reports the Gabor-Granger completeness exclusion (F4)", {
  skip_if(!requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")
  skip_if(!exists("write_pricing_output", mode = "function"), "writer not available")

  prices <- c(20, 40, 60, 80, 100)
  cols <- paste0("p", prices)
  config <- list(
    analysis_method = "gabor_granger", weight_var = NA_character_, dk_codes = numeric(0),
    id_var = "respondent_id", unit_cost = NA_real_, currency_symbol = "R",
    gg_monotonicity_behavior = "diagnostic_only", gg_stop_early_imputation = "NONE",
    gabor_granger = list(data_format = "wide", price_sequence = prices, response_columns = cols,
                         response_type = "binary", binary_coding = "ZERO_ONE",
                         smoothing_method = "isotonic", check_monotonicity = FALSE,
                         calculate_elasticity = FALSE, revenue_optimization = TRUE,
                         confidence_intervals = FALSE, bootstrap_iterations = 10,
                         confidence_level = 0.95),
    validation = list(min_completeness = 0.8, min_sample = 1, price_min = 0, price_max = 10000),
    output = list(), project_name = "F4 completeness")

  set.seed(21)
  n <- 300
  ceiling <- runif(n, 15, 105)
  m <- sapply(prices, function(p) as.integer(p <= ceiling))
  m[matrix(runif(n * length(prices)) < 0.03, nrow = n)] <- NA_integer_
  d <- as.data.frame(m)
  names(d) <- cols
  d$respondent_id <- seq_len(n)

  invisible(capture.output(v <- validate_pricing_data(d, config)))
  invisible(capture.output(r <- run_gabor_granger(v$clean_data, config)))
  cmp <- r$diagnostics$completeness
  expect_gt(cmp$n_excluded, 0)

  out <- file.path(tempdir(), "pricing_f4_completeness.xlsx")
  unlink(out)
  on.exit(unlink(out), add = TRUE)
  invisible(capture.output(write_pricing_output(r, list(), v, config, out)))
  expect_true(file.exists(out))
  expect_true("Validation" %in% openxlsx::getSheetNames(out))

  val <- openxlsx::read.xlsx(out, sheet = "Validation", skipEmptyRows = FALSE, colNames = FALSE)
  text <- apply(val, 1, function(x) paste(x[!is.na(x)], collapse = " | "))
  expect_true(any(grepl("GABOR-GRANGER COMPLETENESS", text, fixed = TRUE)))
  expect_true(any(grepl(paste("Respondents Excluded", cmp$n_excluded, sep = " | "), text, fixed = TRUE)))
  expect_true(any(grepl("Rule Applied | incomplete ladder", text, fixed = TRUE)))
})
