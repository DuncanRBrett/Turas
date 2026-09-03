# ==============================================================================
# TURAS PRICING MODULE - THE KAROO EXAMPLE RUNS END TO END
# ==============================================================================
# The shipped example is the harness: a synthetic study with known truths,
# run through run_pricing_analysis() exactly as the GUI runs a config. A
# refusal anywhere in the pipeline fails this test (the old main-pipeline
# test passed while the ladder refused, review section 5).
# ==============================================================================

skip_if(!exists("run_pricing_analysis", mode = "function"), "pipeline not available")

example_script <- file.path(TURAS_ROOT, "examples", "pricing", "create_pricing_example.R")
skip_if(!file.exists(example_script), "example generator not present")

withr_local <- function() {
  old <- getOption("turas.example.no_run")
  options(turas.example.no_run = TRUE)
  source(example_script, local = FALSE)
  options(turas.example.no_run = old)
}
withr_local()

out_dir <- file.path(tempdir(), "karoo_pricing_test")
unlink(out_dir, recursive = TRUE)
capture.output(ex <- build_pricing_example(TURAS_ROOT, out_dir, verbose = FALSE,
                                           bootstrap_iterations = 60))
truth <- ex$truth

run_quietly <- function(cfg) {
  out <- capture.output(res <- run_pricing_analysis(cfg))
  attr(res, "console") <- out
  res
}

test_that("the both-methods config runs to PASS with no refusal or partial event", {
  r <- run_quietly(ex$config)
  expect_equal(r$run_result$status, "PASS")
  levels <- vapply(r$run_result$events %||% list(), function(e) e$level %||% "", character(1))
  expect_false(any(levels %in% c("REFUSE")))
  expect_false(any(grepl("\\[TRS PARTIAL\\]|failed:", attr(r, "console"))))
  expect_true(file.exists(file.path(out_dir, "Output", "Karoo_Pricing_Results.xlsx")))
  expect_true(file.exists(file.path(out_dir, "Output", "Karoo_Pricing_Results_stats_pack.xlsx")))

  vw <- r$results$van_westendorp
  b <- truth$bands
  for (p in c("OPP", "IDP", "PMC", "PME")) {
    expect_true(vw$price_points[[p]] >= b[[p]][1] && vw$price_points[[p]] <= b[[p]][2],
                info = sprintf("%s = %.2f outside %s", p, vw$price_points[[p]], paste(b[[p]], collapse = " to ")))
  }
  expect_match(vw$diagnostics$estimator, "weighted")
  expect_equal(vw$diagnostics$n_analysed, vw$diagnostics$n_valid)
  ci <- vw$confidence_intervals
  expect_equal(ci$estimate, unname(unlist(vw$price_points[ci$metric])))
  expect_true(all(ci$ci_lower <= ci$estimate & ci$estimate <= ci$ci_upper))

  gg <- r$results$gabor_granger
  expect_true(all(gg$demand_curve$n_respondents == gg$demand_curve$n_respondents[1]))
  expect_gte(gg$demand_curve$purchase_intent[1], b$gg_demand_first_rung_min)
  expect_lte(gg$demand_curve$purchase_intent[nrow(gg$demand_curve)], b$gg_demand_last_rung_max)
  expect_true(all(diff(gg$demand_curve$purchase_intent) <= 1e-12))
  expect_equal(gg$diagnostics$smoothing, "isotonic")
  expect_match(gg$diagnostics$response_coding, "1 = would buy, 0")

  # The stats pack carries the Kish effective N from the shared helper (H7)
  # and the pricing-authored sheets carry no em dash. (The shared writer's
  # own Declaration and Warnings wording is outside this module.)
  sp <- file.path(out_dir, "Output", "Karoo_Pricing_Results_stats_pack.xlsx")
  txt <- unlist(lapply(c("Assumptions", "Config_Echo", "Data_Used"), function(s)
    unlist(openxlsx::read.xlsx(sp, sheet = s, skipEmptyRows = FALSE, colNames = FALSE))))
  txt <- txt[!is.na(txt)]
  expect_true(any(grepl("Effective N (Kish)", txt, fixed = TRUE)))
  expect_true(any(grepl("Valid N", txt, fixed = TRUE)))
  expect_true(any(grepl("psm_analysis_weighted", txt, fixed = TRUE)))
  expect_false(any(grepl("—", txt)))
})

test_that("the weighted and unweighted runs give different Van Westendorp points (C1)", {
  cfg_un <- file.path(out_dir, "Karoo_Unweighted.xlsx")
  write_pricing_config(cfg_un, method = "van_westendorp", data_file = "Karoo_Pricing_Data.xlsx",
                       output_file = "Output/Karoo_Unweighted_Results.xlsx",
                       weighted = FALSE, segment_column = NULL, stats_pack = FALSE,
                       bootstrap_iterations = 60)
  un <- run_quietly(cfg_un)
  we <- run_quietly(ex$config)
  expect_false(isTRUE(all.equal(un$results$price_points$OPP,
                                we$results$van_westendorp$price_points$OPP)))
  expect_match(un$results$diagnostics$estimator, "unweighted")
  # Generate_Stats_Pack = N is honoured (H8).
  expect_false(file.exists(file.path(out_dir, "Output", "Karoo_Unweighted_Results_stats_pack.xlsx")))
})

test_that("the stop-early ladder refuses by default and passes with the opt-in (C2)", {
  expect_error(capture.output(run_pricing_analysis(ex$config_stop_early)), "DATA_GG_UNEQUAL_BASES")
  r <- run_quietly(ex$config_stop_early_imputed)
  expect_equal(r$run_result$status, "PASS")
  gg <- r$results
  expect_true(all(gg$demand_curve$n_respondents == nrow(ex$data)))
  expect_match(gg$diagnostics$imputation, "NO_AFTER_STOP")
  # Survivors-only demand at the top rung would have been higher.
  naive <- mean(ex$data$GGS_R140, na.rm = TRUE)
  expect_gt(naive, gg$demand_curve$purchase_intent_raw[nrow(gg$demand_curve)])
})

test_that("the monadic config runs weighted with a negative price slope", {
  r <- run_quietly(ex$config_monadic)
  expect_equal(r$run_result$status, "PASS")
  expect_lt(r$results$model_summary$coefficients[2, 1], 0)
  expect_true(r$results$model_summary$weighted)
  expect_match(r$results$model_summary$p_value_caveat, "frequency weights")
  expect_true("weighted_n" %in% names(r$results$observed_data))
})
