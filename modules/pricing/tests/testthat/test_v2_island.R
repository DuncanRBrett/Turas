# ==============================================================================
# TURAS PRICING MODULE - V2 REPORT ISLAND (Session B, B1)
# ==============================================================================
# The pricing run contributes {output}_pr_island.json; a tabs run for the same
# project embeds it and the report gains a Pricing tab. The load-bearing
# properties are that a block the run did not produce is ABSENT (jsonlite
# writes NULL as {}, which is truthy in JavaScript), that a one-row block
# still arrives as an array, and that every provenance sentence comes from
# what the engines recorded rather than from anything recomputed here.
#
# Every test in this file fails on main at 34078b33: 14_v2_island.R does not
# exist there.
# ==============================================================================

skip_if(!exists("serialize_pricing_layer", mode = "function"), "island writer not available")

# ---------------------------------------------------------------------------
# Small hand-built result objects, so the shape tests do not depend on a run
# ---------------------------------------------------------------------------

fake_vw <- function(with_ci = TRUE, n_curve = 40) {
  ci <- data.frame(
    metric = c("PMC", "OPP", "IDP", "PME"),
    estimate = c(20, 30, 32, 45),
    boot_mean = c(20.1, 30.2, 32.1, 45.3),
    se = c(0.5, 0.6, 0.6, 0.9),
    ci_lower = c(19, 29, 31, 43),
    ci_upper = c(21, 31, 33, 47),
    n_successful = 200L,
    stringsAsFactors = FALSE
  )
  attr(ci, "policy") <- "test policy"
  list(
    price_points = list(PMC = 20, OPP = 30, IDP = 32, PME = 45),
    acceptable_range = list(lower = 20, upper = 45, width = 25),
    optimal_range = list(lower = 30, upper = 32, width = 2),
    curves = data.frame(
      price = seq(10, 60, length.out = n_curve),
      too_cheap = seq(0.9, 0.05, length.out = n_curve),
      cheap = seq(0.95, 0.1, length.out = n_curve),
      expensive = seq(0.05, 0.9, length.out = n_curve),
      too_expensive = seq(0.02, 0.8, length.out = n_curve),
      stringsAsFactors = FALSE
    ),
    confidence_intervals = if (with_ci) ci else NULL,
    diagnostics = list(
      n_valid = 180L, n_analysed = 172L, n_violations = 8L,
      monotonicity_behavior = "drop", validate_flag = TRUE, weighted = TRUE,
      estimator = "psm_analysis_weighted (survey design)"
    )
  )
}

fake_gg <- function(n_rungs = 4, smoothed = TRUE) {
  price <- seq(20, 50, length.out = n_rungs)
  raw <- seq(0.8, 0.2, length.out = n_rungs)
  dc <- data.frame(
    price = price, n_respondents = rep(200L, n_rungs),
    weighted_n = rep(200, n_rungs), n_purchase = raw * 200,
    purchase_intent = raw, stringsAsFactors = FALSE
  )
  if (smoothed) dc$purchase_intent_raw <- pmin(raw + 0.02, 1)
  rc <- dc
  rc$revenue_index <- rc$price * rc$purchase_intent
  el <- data.frame(price_from = price[-n_rungs], price_to = price[-1],
                   arc_elasticity = rep(-1.2, n_rungs - 1), stringsAsFactors = FALSE)
  list(
    demand_curve = dc, revenue_curve = rc, elasticity = el,
    rung_bases = data.frame(price = price, n_answered = rep(200L, n_rungs),
                            n_missing = rep(0L, n_rungs), stringsAsFactors = FALSE),
    optimal_price = list(price = price[2], purchase_intent = raw[2],
                         revenue_index = price[2] * raw[2]),
    diagnostics = list(n_respondents = 200L, n_price_points = n_rungs,
                       weighted = TRUE, response_coding = "binary, 1 = would buy, 0 = would not",
                       imputation = "none",
                       smoothing = if (smoothed) "isotonic" else "none")
  )
}

fake_monadic <- function(n_cells = 3) {
  price <- seq(20, 40, length.out = n_cells)
  list(
    observed_data = data.frame(price = price, n = rep(60, n_cells),
                               weighted_n = rep(60, n_cells),
                               observed_intent = seq(0.7, 0.3, length.out = n_cells),
                               stringsAsFactors = FALSE),
    demand_curve = data.frame(price = seq(20, 40, length.out = 30),
                              predicted_intent = seq(0.72, 0.28, length.out = 30),
                              revenue_index = seq(14, 11, length.out = 30),
                              profit_index = rep(NA_real_, 30),
                              stringsAsFactors = FALSE),
    optimal_price = list(price = 31, predicted_intent = 0.5, revenue_index = 15.5),
    model_summary = list(model_type = "logistic", pseudo_r2 = 0.11,
                         price_coefficient_p = 1e-9, weighted = TRUE,
                         p_value_caveat = "Weighted fit: the p-value overstates significance."),
    diagnostics = list(n_valid = 180L, n_cells = n_cells)
  )
}

fake_validation <- function() list(n_total = 200L, n_valid = 190L,
                                   clean_data = data.frame(Weight = rep(1, 190)))

fake_config <- function(weighted = TRUE, simulator = FALSE) {
  list(
    project_name = "Test Study", currency_symbol = "R",
    weight_var = if (weighted) "Weight" else NA_character_,
    generate_simulator = simulator,
    van_westendorp = list(confidence_level = 0.95),
    gabor_granger = list(confidence_level = 0.95)
  )
}

quiet_island <- function(results, config) {
  invisible(capture.output(out <- serialize_pricing_layer(results, config, verbose = FALSE)))
  out
}

# ---------------------------------------------------------------------------
# Shape
# ---------------------------------------------------------------------------

test_that("a run with no method output serialises to NULL, not to an empty island", {
  isl <- quiet_island(list(van_westendorp = NULL, gabor_granger = NULL, monadic = NULL,
                           validation = fake_validation()), fake_config())
  expect_null(isl)
})

test_that("the island names itself and carries schema 1", {
  isl <- quiet_island(list(van_westendorp = fake_vw(), validation = fake_validation(),
                           output_path = "x.xlsx"), fake_config())
  expect_equal(isl$meta$kind, "pricing")
  expect_equal(isl$meta$schema, 1L)
  expect_equal(isl$meta$currency, "R")
  expect_equal(isl$meta$projectName, "Test Study")
  expect_true(isTRUE(isl$meta$frozen))
})

test_that("a block the run did not produce is absent, not empty", {
  isl <- quiet_island(list(gabor_granger = fake_gg(), validation = fake_validation()),
                      fake_config())
  expect_true("gg" %in% names(isl))
  expect_false("vw" %in% names(isl))
  expect_false("monadic" %in% names(isl))
  expect_equal(as.character(isl$meta$methods), "gabor_granger")
})

test_that("all three methods travel when all three ran", {
  isl <- quiet_island(list(van_westendorp = fake_vw(), gabor_granger = fake_gg(),
                           monadic = fake_monadic(), validation = fake_validation()),
                      fake_config())
  expect_setequal(as.character(isl$meta$methods), c("van_westendorp", "gabor_granger", "monadic"))
  expect_true(all(c("vw", "gg", "monadic") %in% names(isl)))
  expect_equal(length(isl$meta$methodLabels), 3)
})

# ---------------------------------------------------------------------------
# Van Westendorp
# ---------------------------------------------------------------------------

test_that("the four price points carry their own interval, in a fixed order", {
  isl <- quiet_island(list(van_westendorp = fake_vw(), validation = fake_validation()),
                      fake_config())
  expect_equal(isl$vw$point, c("PMC", "OPP", "IDP", "PME"))
  expect_equal(isl$vw$value, c(20, 30, 32, 45))
  expect_equal(isl$vw$ciLower, c(19, 29, 31, 43))
  expect_equal(isl$vw$ciUpper, c(21, 31, 33, 47))
  expect_true(all(isl$vw$ciLower <= isl$vw$value & isl$vw$value <= isl$vw$ciUpper))
  expect_equal(isl$vw$ciLevel, 0.95)
  expect_equal(isl$vw$ciPolicy, "test policy")
})

test_that("a run without a bootstrap carries the points and no interval fields", {
  isl <- quiet_island(list(van_westendorp = fake_vw(with_ci = FALSE),
                           validation = fake_validation()), fake_config())
  expect_equal(isl$vw$value, c(20, 30, 32, 45))
  expect_false("ciLower" %in% names(isl$vw))
  expect_false("ciUpper" %in% names(isl$vw))
})

test_that("a long interpolated curve is downsampled and keeps both ends", {
  vw <- fake_vw(n_curve = 3000)
  isl <- quiet_island(list(van_westendorp = vw, validation = fake_validation()),
                      fake_config())
  cv <- isl$vw$curves
  expect_lte(length(cv$price), 120)
  expect_equal(cv$price[1], vw$curves$price[1])
  expect_equal(cv$price[length(cv$price)], vw$curves$price[3000])
  expect_equal(cv$downsampledFrom, 3000)
  expect_equal(length(cv$tooCheap), length(cv$price))
})

test_that("a short curve is not downsampled and says nothing about it", {
  isl <- quiet_island(list(van_westendorp = fake_vw(n_curve = 40),
                           validation = fake_validation()), fake_config())
  expect_equal(length(isl$vw$curves$price), 40)
  expect_false("downsampledFrom" %in% names(isl$vw$curves))
})

test_that("the violation count stays out until the F5 fix lands", {
  # The engine recomputes violations on data `drop` has already cleaned, so
  # the number reads 0 on a run that excluded respondents for violating.
  isl <- quiet_island(list(van_westendorp = fake_vw(), validation = fake_validation()),
                      fake_config())
  expect_false("violations" %in% names(isl$vw))
})

# ---------------------------------------------------------------------------
# Gabor-Granger
# ---------------------------------------------------------------------------

test_that("each rung carries its base, both curves and the interval", {
  isl <- quiet_island(list(gabor_granger = fake_gg(), validation = fake_validation()),
                      fake_config())
  gg <- isl$gg
  expect_equal(length(gg$price), 4)
  expect_equal(gg$baseN, rep(200, 4))
  # acceptancePct is what was observed; smoothedPct is what is published.
  expect_equal(round(gg$acceptancePct, 4), round(c(82, 62, 42, 22), 4))
  expect_equal(round(gg$smoothedPct, 4), round(c(80, 60, 40, 20), 4))
  expect_equal(gg$smoothing, "isotonic")
  expect_equal(gg$optimalRevenuePrice, 30)
})

test_that("an unsmoothed run publishes one curve, not two identical ones", {
  isl <- quiet_island(list(gabor_granger = fake_gg(smoothed = FALSE),
                           validation = fake_validation()), fake_config())
  expect_true("acceptancePct" %in% names(isl$gg))
  expect_false("smoothedPct" %in% names(isl$gg))
  expect_equal(isl$gg$smoothing, "none")
})

test_that("arc elasticity is carried on the rung its step ends at", {
  isl <- quiet_island(list(gabor_granger = fake_gg(), validation = fake_validation()),
                      fake_config())
  expect_equal(length(isl$gg$arcElasticity), length(isl$gg$price))
  expect_true(is.na(isl$gg$arcElasticity[1]))
  expect_equal(isl$gg$arcElasticity[2], -1.2)
})

# ---------------------------------------------------------------------------
# Monadic
# ---------------------------------------------------------------------------

test_that("the monadic block keeps the measured cells apart from the fitted curve", {
  isl <- quiet_island(list(monadic = fake_monadic(), validation = fake_validation()),
                      fake_config())
  m <- isl$monadic
  expect_equal(length(m$cellPrice), 3)
  expect_equal(round(m$cellIntentPct, 4), round(c(70, 50, 30), 4))
  expect_equal(length(m$fitted$price), 30)
  expect_equal(m$modelType, "logistic")
  expect_equal(m$optimalPrice, 31)
  expect_match(m$pValueCaveat, "overstates significance")
})

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

test_that("the weighting note names the variable and what the weights reached", {
  isl <- quiet_island(list(van_westendorp = fake_vw(), gabor_granger = fake_gg(),
                           monadic = fake_monadic(), validation = fake_validation()),
                      fake_config(weighted = TRUE))
  expect_match(isl$meta$weightingNote, "Weighted by Weight")
  expect_match(isl$meta$weightingNote, "survey design")
  expect_match(isl$meta$weightingNote, "normalised to mean 1")
  expect_true(isTRUE(isl$meta$weighted))
  expect_true(is.numeric(isl$meta$effectiveN))
})

test_that("an unweighted run says so and carries no effective N", {
  isl <- quiet_island(list(van_westendorp = fake_vw(), validation = fake_validation()),
                      fake_config(weighted = FALSE))
  expect_false(isTRUE(isl$meta$weighted))
  expect_match(isl$meta$weightingNote, "^Unweighted")
  expect_false("effectiveN" %in% names(isl$meta))
  expect_false("weightVariable" %in% names(isl$meta))
})

test_that("the estimation notes repeat what the engines recorded", {
  isl <- quiet_island(list(van_westendorp = fake_vw(), gabor_granger = fake_gg(),
                           monadic = fake_monadic(), validation = fake_validation()),
                      fake_config())
  expect_match(isl$meta$estimationNote$vw, "psm_analysis_weighted")
  expect_match(isl$meta$estimationNote$vw, "172")            # the analysed base
  expect_match(isl$meta$estimationNote$vw, "excluded")       # what drop did
  expect_match(isl$meta$estimationNote$gg, "1 = would buy")
  expect_match(isl$meta$estimationNote$gg, "smoothed")
  expect_match(isl$meta$estimationNote$monadic, "logistic regression")
  expect_match(isl$meta$estimationNote$monadic, "overstates significance")
})

test_that("the frozen note tells the reader where a filtered cut lives", {
  isl <- quiet_island(list(gabor_granger = fake_gg(), validation = fake_validation()),
                      fake_config())
  expect_match(isl$meta$filterNote, "do not respond to the audience filter")
  expect_match(isl$meta$filterNote, "Generate_Tabs_Export")
})

test_that("the simulator is named only when a standalone file was written", {
  base <- list(van_westendorp = fake_vw(), validation = fake_validation(),
               output_path = "/tmp/Study_Results.xlsx")
  off <- quiet_island(base, fake_config(simulator = FALSE))
  expect_false("simulatorFile" %in% names(off$meta))
  standalone <- quiet_island(base, fake_config(simulator = TRUE))
  expect_equal(standalone$meta$simulatorFile, "Study_Results_simulator.html")
  # No output path, so no file was written and none is named.
  nameless <- quiet_island(list(van_westendorp = fake_vw(), validation = fake_validation()),
                           fake_config(simulator = TRUE))
  expect_false("simulatorFile" %in% names(nameless$meta))
})

test_that("no em dash reaches the reader from the island writer", {
  src <- paste(readLines(file.path(TURAS_ROOT, "modules", "pricing", "R", "14_v2_island.R"),
                         warn = FALSE), collapse = "\n")
  expect_false(grepl("—", src))
})

# ---------------------------------------------------------------------------
# The JSON on disk
# ---------------------------------------------------------------------------

test_that("write_pricing_island writes {output}_pr_island.json and it parses", {
  out <- file.path(tempdir(), "island_test", "Study_Results.xlsx")
  dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
  invisible(capture.output(
    res <- write_pricing_island(
      results = list(van_westendorp = fake_vw(), gabor_granger = fake_gg(),
                     validation = fake_validation(), output_path = out),
      config = fake_config(), verbose = FALSE)))
  expect_equal(res$status, "PASS")
  expect_equal(basename(res$output_file), "Study_Results_pr_island.json")
  expect_true(file.exists(res$output_file))
  parsed <- jsonlite::fromJSON(res$output_file, simplifyVector = FALSE)
  expect_equal(parsed$meta$kind, "pricing")
  expect_true(is.list(parsed$vw$value))
  expect_equal(length(parsed$vw$value), 4)
})

test_that("a one-rung ladder and a one-cell monadic still arrive as arrays", {
  # auto_unbox turns a length-1 vector into a scalar, and the view's array
  # check would then treat the whole block as absent (the maxdiff F2 defect).
  out <- file.path(tempdir(), "island_test1", "One_Results.xlsx")
  dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
  invisible(capture.output(
    res <- write_pricing_island(
      results = list(gabor_granger = fake_gg(n_rungs = 1),
                     monadic = fake_monadic(n_cells = 1),
                     validation = fake_validation(), output_path = out),
      config = fake_config(), verbose = FALSE)))
  parsed <- jsonlite::fromJSON(res$output_file, simplifyVector = FALSE)
  expect_true(is.list(parsed$gg$price))
  expect_equal(length(parsed$gg$price), 1)
  expect_true(is.list(parsed$monadic$cellPrice))
  expect_equal(length(parsed$monadic$cellPrice), 1)
  expect_true(is.list(parsed$meta$methods))
})

test_that("write_pricing_island refuses rather than writing an empty island", {
  out <- file.path(tempdir(), "island_test2", "Empty_Results.xlsx")
  dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
  expect_error(
    write_pricing_island(results = list(validation = fake_validation(), output_path = out),
                         config = fake_config(), verbose = FALSE),
    class = "turas_refusal")
  expect_false(file.exists(file.path(dirname(out), "Empty_Results_pr_island.json")))
})

# ---------------------------------------------------------------------------
# End to end, on the shipped example
# ---------------------------------------------------------------------------

test_that("the Karoo run writes an island whose numbers are the headline numbers", {
  skip_if(!exists("run_pricing_analysis", mode = "function"), "pipeline not available")
  example_script <- file.path(TURAS_ROOT, "examples", "pricing", "create_pricing_example.R")
  skip_if(!file.exists(example_script), "example generator not present")

  old <- getOption("turas.example.no_run")
  options(turas.example.no_run = TRUE)
  source(example_script, local = FALSE)
  options(turas.example.no_run = old)

  out_dir <- file.path(tempdir(), "karoo_island_test")
  unlink(out_dir, recursive = TRUE)
  invisible(capture.output(ex <- build_pricing_example(TURAS_ROOT, out_dir, verbose = FALSE,
                                                       bootstrap_iterations = 40)))
  invisible(capture.output(r <- run_pricing_analysis(ex$config)))

  island_file <- file.path(out_dir, "Output", "Karoo_Pricing_Results_pr_island.json")
  expect_true(file.exists(island_file))
  expect_equal(normalizePath(r$island_path), normalizePath(island_file))

  isl <- jsonlite::fromJSON(island_file, simplifyVector = TRUE)
  expect_equal(isl$meta$kind, "pricing")
  expect_setequal(isl$meta$methods, c("van_westendorp", "gabor_granger"))

  # The island repeats the run, it does not re-estimate it.
  vw <- r$results$van_westendorp
  expect_equal(isl$vw$value,
               unname(unlist(vw$price_points[c("PMC", "OPP", "IDP", "PME")])),
               tolerance = 1e-6)
  gg <- r$results$gabor_granger
  expect_equal(isl$gg$price, gg$demand_curve$price, tolerance = 1e-6)
  expect_equal(isl$gg$acceptancePct,
               (gg$demand_curve$purchase_intent_raw %||% gg$demand_curve$purchase_intent) * 100,
               tolerance = 1e-6)
  expect_equal(isl$meta$effectiveN,
               calculate_effective_n(r$diagnostics$clean_data$Weight), tolerance = 1e-6)

  # No em dash reaches the client through the island.
  raw <- paste(readLines(island_file, warn = FALSE), collapse = "")
  expect_false(grepl("—", raw))
  expect_false(grepl("NaN|Infinity", raw))
})
