# ==============================================================================
# CATDRIVER - THE V2 REPORT ISLAND (TR.CD)
# ==============================================================================
# Session C. The island is the module's contribution to the tabs v2 report: a
# frozen block a later tabs run embeds. These tests hold the island to what the
# view expects and to what the module actually computed, because a field that
# quietly changes name here becomes an empty panel over there.
# ==============================================================================

.cd_isl_fixture <- function(n = 400, seed = 606) {
  set.seed(seed)
  d <- data.frame(
    service = factor(sample(c("Poor", "Fair", "Good"), n, TRUE)),
    price   = factor(sample(c("Cheap", "Dear"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  eta <- ifelse(d$service == "Good", 1.4, 0) - ifelse(d$price == "Dear", 0.8, 0)
  d$churn <- factor(ifelse(plogis(eta + rlogis(n)) > 0.5, "Retained", "Churned"),
                    levels = c("Churned", "Retained"))
  d$wt <- runif(n, 0.5, 1.8)
  d$wt <- d$wt / mean(d$wt)
  d
}

.cd_isl_config <- function() {
  list(outcome_var = "churn", outcome_type = "binary", outcome_label = "Customer churn",
       confidence_level = 0.9, analysis_name = "Island test",
       driver_vars = c("service", "price"), weight_var = "wt",
       output_file = file.path(tempdir(), "island_test.xlsx"),
       variables = data.frame(VariableName = c("service", "price"),
                              Label = c("Service", "Price"), stringsAsFactors = FALSE))
}

.cd_isl_results <- function() {
  d <- .cd_isl_fixture()
  config <- .cd_isl_config()
  w <- normalise_catdriver_weights(d$wt, "wt")
  f <- churn ~ service + price
  fit <- run_binary_logistic_robust(f, d, w$weights, config, guard_init())
  mapping <- map_terms_to_levels(fit$model, d, f)
  or_df <- extract_odds_ratios_mapped(fit, mapping, config, 0.9)
  diagnostics <- calculate_weight_diagnostics(w$weights)
  diagnostics$inference_stamp <- catdriver_weighting_stamp("wt", diagnostics, w)

  list(
    importance = calculate_importance(fit, config),
    odds_ratios = or_df,
    probability_lift = calculate_probability_lift(
      fit, list(data = d, outcome_info = list(type = "binary",
                                              categories = levels(d$churn))), config),
    factor_patterns = calculate_factor_patterns(
      list(data = d, outcome_info = list(type = "binary",
                                         categories = levels(d$churn))),
      config, or_df),
    model_result = fit,
    prep_data = list(data = d, outcome_info = list(type = "binary",
                                                   categories = levels(d$churn))),
    diagnostics = list(original_n = nrow(d), analysis_n = nrow(d)),
    weight_diagnostics = diagnostics,
    run_status = "PASS",
    degraded_reasons = character(0),
    config = config
  )
}

test_that("the island carries every block the view reads", {
  res <- .cd_isl_results()
  island <- serialize_catdriver_layer(res, res$config, verbose = FALSE)

  expect_false(is.null(island))
  expect_equal(island$meta$kind, "catdriver")          # the tabs reader checks this
  expect_true(island$meta$frozen)
  expect_true(nzchar(island$meta$filter_note))
  expect_equal(island$meta$schema_version, CD_ISLAND_SCHEMA_VERSION)

  expect_true(length(island$importance$rows) > 0)
  expect_true(nzchar(island$importance$method))        # D5: the method travels
  expect_true(length(island$odds_ratios$rows) > 0)
  expect_false(is.null(island$fit$n))
  expect_false(is.null(island$fit$n_eff))              # the shared Kish figure
  expect_true(grepl("frequency weights", island$fit$weighting))
})

test_that("the island's numbers are the run's numbers", {
  res <- .cd_isl_results()
  island <- serialize_catdriver_layer(res, res$config, verbose = FALSE)

  # importance, row for row
  for (r in island$importance$rows) {
    src <- res$importance[res$importance$variable == r$driver, ]
    expect_equal(r$pct, src$importance_pct[1], tolerance = 1e-8, info = r$driver)
    expect_equal(r$statistic, src$chi_square[1], tolerance = 1e-8, info = r$driver)
  }
  # odds ratios, row for row
  for (r in island$odds_ratios$rows) {
    src <- res$odds_ratios[res$odds_ratios$factor == r$driver &
                             res$odds_ratios$comparison == r$level, ]
    expect_equal(r$or, src$odds_ratio[1], tolerance = 1e-8, info = r$level)
    expect_equal(r$lo, src$or_lower[1], tolerance = 1e-8, info = r$level)
  }
  expect_equal(island$fit$n_eff, res$weight_diagnostics$effective_n, tolerance = 1e-8)
  expect_equal(island$meta$confidence_level, 0.9)
})

test_that("a bootstrap that did not run is said, not implied", {
  res <- .cd_isl_results()
  island <- serialize_catdriver_layer(res, res$config, verbose = FALSE)

  expect_false(island$odds_ratios$bootstrap)
  expect_equal(island$odds_ratios$interval_kind, "wald")
  for (r in island$odds_ratios$rows) {
    expect_null(r$boot_lo)
    expect_null(r$boot_hi)
  }

  # and where one did run, the interval travels
  res2 <- res
  res2$odds_ratios$boot_ci_lower <- res2$odds_ratios$or_lower * 0.95
  res2$odds_ratios$boot_ci_upper <- res2$odds_ratios$or_upper * 1.05
  res2$odds_ratios$sign_stability <- 1
  island2 <- serialize_catdriver_layer(res2, res$config, verbose = FALSE)
  expect_true(island2$odds_ratios$bootstrap)
  expect_equal(island2$odds_ratios$interval_kind, "wald_and_bootstrap")
  expect_false(is.null(island2$odds_ratios$rows[[1]]$boot_lo))
})

test_that("the probability lift carries the level it describes and its basis", {
  res <- .cd_isl_results()
  island <- serialize_catdriver_layer(res, res$config, verbose = FALSE)
  skip_if(is.null(island$lifts), "this fixture produced no lift table")

  expect_true(nzchar(island$lifts$basis))
  expect_true(grepl("Not an average marginal effect", island$lifts$basis))
  expect_true(island$lifts$outcome_level %in% levels(res$prep_data$data$churn))
})

test_that("a run with no importance table writes nothing, and says so", {
  res <- .cd_isl_results()
  res$importance <- NULL
  expect_null(serialize_catdriver_layer(res, res$config, verbose = FALSE))

  out <- utils::capture.output(
    r <- write_catdriver_island(res, res$config, verbose = TRUE)
  )
  expect_equal(r$status, "SKIPPED")
  expect_null(r$output_file)
  expect_true(any(grepl("No importance table", out)))
})

test_that("the written file is the JSON the tabs reader accepts", {
  skip_if_not_installed("jsonlite")
  res <- .cd_isl_results()
  path <- file.path(tempdir(), "cd_island_probe.json")
  on.exit(unlink(path), add = TRUE)

  r <- write_catdriver_island(res, res$config, output_file = path, verbose = FALSE)
  expect_equal(r$status, "OK")
  expect_true(file.exists(path))

  back <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  # This is the exact check .read_catdriver_contribution() makes before it
  # hands the file to the report builder.
  expect_equal(back$meta$kind, "catdriver")
  # Arrays must stay arrays through the round trip, or the view's Array.isArray
  # guards drop the panel.
  expect_true(is.list(back$importance$rows))
  expect_null(names(back$importance$rows))
  expect_true(is.list(back$odds_ratios$rows))
})

test_that("the island holds no per-respondent data", {
  res <- .cd_isl_results()
  island <- serialize_catdriver_layer(res, res$config, verbose = FALSE)

  # D5 and the locked decision: fitted probabilities are model estimates of a
  # tabs-native outcome column, so they never leave the module as respondent
  # data. The island carries group means, never a vector the length of the
  # sample.
  flat <- unlist(island, use.names = TRUE)
  expect_lt(length(flat), 5000)
  expect_false(any(vapply(island, function(b) {
    is.numeric(b) && length(b) >= nrow(res$prep_data$data)
  }, logical(1))))
})
