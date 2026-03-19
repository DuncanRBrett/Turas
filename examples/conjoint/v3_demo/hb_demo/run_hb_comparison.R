# ==============================================================================
# CONJOINT v3.1 DEMO - MNL vs HB COMPARISON
# ==============================================================================
#
# This script runs BOTH aggregate MNL and Hierarchical Bayes estimation
# on the same dataset, then compares results side by side.
#
# PURPOSE:
#   Demonstrates the difference between:
#   - MNL (aggregate): One set of utilities for the whole sample
#   - HB (individual): Unique utilities per respondent + convergence diagnostics
#
# USAGE:
#   source("examples/conjoint/v3_demo/hb_demo/run_hb_comparison.R")
#   (from the Turas root directory)
#
# NOTE:
#   HB requires the bayesm package and takes longer to run (~60-120 seconds).
#   For a quick test, hb_iterations is set to 5000 (production: 10000-50000).
#
# ==============================================================================

cat("\n")
cat("================================================================\n")
cat("  TURAS CONJOINT v3.1 — MNL vs HB COMPARISON\n")
cat("================================================================\n\n")

# --- Setup ---
turas_root <- getwd()
demo_dir <- file.path(turas_root, "examples", "conjoint", "v3_demo")
hb_demo_dir <- file.path(demo_dir, "hb_demo")
output_dir <- file.path(hb_demo_dir, "output")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

if (!file.exists(file.path(turas_root, "launch_turas.R"))) {
  stop("Run from the Turas root: setwd('/path/to/Turas')")
}

data_file <- file.path(demo_dir, "demo_data.csv")
config_file <- file.path(demo_dir, "demo_config.xlsx")

# --- Load module ---
cat("[1/5] Loading conjoint module...\n")
source(file.path(turas_root, "modules", "conjoint", "R", "00_main.R"))

# Check bayesm is available
if (!requireNamespace("bayesm", quietly = TRUE)) {
  stop("bayesm package is required for HB. Install with: install.packages('bayesm')")
}
cat("  bayesm package: available\n\n")

# =====================================================================
# PART 1: MNL (AGGREGATE) ESTIMATION
# =====================================================================

cat("[2/5] Running MNL (aggregate) estimation...\n")
t1 <- Sys.time()
mnl_results <- tryCatch({
  run_conjoint_analysis(
    config_file = config_file,
    data_file = data_file,
    output_file = file.path(output_dir, "demo_mnl_results.xlsx"),
    verbose = FALSE
  )
}, error = function(e) {
  cat(sprintf("  MNL ERROR: %s\n", conditionMessage(e)))
  NULL
})
t1_elapsed <- as.numeric(Sys.time() - t1, units = "secs")

if (!is.null(mnl_results)) {
  cat(sprintf("  MNL completed in %.1f seconds\n", t1_elapsed))
  cat(sprintf("  Status: %s\n\n", mnl_results$run_result$status))
}

# =====================================================================
# PART 2: HB (INDIVIDUAL-LEVEL) ESTIMATION
# =====================================================================

cat("[3/5] Running HB (individual-level) estimation...\n")
cat("  This will take longer (MCMC iterations)...\n")
t2 <- Sys.time()

# For HB, we need to load the config, override estimation settings, then run
# the internal pipeline manually since run_conjoint_analysis reads method from config
hb_results <- tryCatch({
  # Load config
  config <- load_conjoint_config(config_file)
  config$estimation_method <- "hb"
  config$hb_iterations <- 5000    # Quick demo (production: 10000-50000)
  config$hb_burnin <- 2500
  config$hb_thin <- 1
  config$hb_ncomp <- 1

  # Load data
  data_list <- load_conjoint_data(data_file, config, verbose = TRUE)

  # Estimate HB model
  model_result <- estimate_choice_model(data_list, config, verbose = TRUE)

  # Calculate utilities and importance
  utilities <- calculate_utilities(model_result, config, verbose = TRUE)
  importance <- calculate_attribute_importance(utilities, config, verbose = TRUE)
  diagnostics <- calculate_model_diagnostics(model_result, data_list, utilities, importance, config)

  # Write Excel output
  write_conjoint_output(
    utilities, importance, diagnostics, model_result,
    config, data_list,
    file.path(output_dir, "demo_hb_results.xlsx")
  )

  list(
    model_result = model_result,
    utilities = utilities,
    importance = importance,
    diagnostics = diagnostics,
    config = config,
    run_result = list(status = "PASS")
  )
}, error = function(e) {
  cat(sprintf("  HB ERROR: %s\n", conditionMessage(e)))
  NULL
})
t2_elapsed <- as.numeric(Sys.time() - t2, units = "secs")

if (!is.null(hb_results)) {
  cat(sprintf("\n  HB completed in %.1f seconds\n", t2_elapsed))
  cat(sprintf("  Status: %s\n\n", hb_results$run_result$status))
}

# =====================================================================
# PART 3: COMPARE RESULTS
# =====================================================================

cat("[4/5] Comparing MNL vs HB results...\n\n")

if (!is.null(mnl_results) && !is.null(hb_results)) {

  # --- Importance comparison ---
  cat("  ATTRIBUTE IMPORTANCE COMPARISON\n")
  cat("  ================================\n")
  mnl_imp <- mnl_results$importance
  hb_imp <- hb_results$importance

  cat(sprintf("  %-15s %8s %8s %8s\n", "Attribute", "MNL", "HB", "Diff"))
  cat("  ", strrep("-", 45), "\n", sep = "")
  for (attr in mnl_imp$Attribute) {
    mnl_val <- mnl_imp$Importance[mnl_imp$Attribute == attr]
    hb_idx <- which(hb_imp$Attribute == attr)
    hb_val <- if (length(hb_idx) > 0) hb_imp$Importance[hb_idx] else NA
    diff <- if (!is.na(hb_val)) hb_val - mnl_val else NA
    cat(sprintf("  %-15s %7.1f%% %7.1f%% %+6.1f pp\n",
                attr, mnl_val, hb_val, diff))
  }

  # --- Top utility comparison ---
  cat("\n  TOP UTILITY COMPARISON (selected levels)\n")
  cat("  ==========================================\n")
  mnl_utils <- mnl_results$utilities
  hb_utils <- hb_results$utilities

  cat(sprintf("  %-25s %8s %8s\n", "Level", "MNL", "HB"))
  cat("  ", strrep("-", 45), "\n", sep = "")
  for (i in seq_len(min(10, nrow(mnl_utils)))) {
    row <- mnl_utils[i, ]
    hb_row <- hb_utils[hb_utils$Attribute == row$Attribute & hb_utils$Level == row$Level, ]
    hb_val <- if (nrow(hb_row) > 0) hb_row$Utility[1] else NA
    cat(sprintf("  %-25s %+7.3f %+7.3f\n",
                paste0(row$Attribute, ": ", row$Level),
                row$Utility, hb_val))
  }

  # --- HB-specific diagnostics ---
  if (!is.null(hb_results$model_result$convergence)) {
    cat("\n  HB CONVERGENCE DIAGNOSTICS\n")
    cat("  ===========================\n")
    conv <- hb_results$model_result$convergence
    cat(sprintf("  Converged: %s\n", if (conv$converged) "YES" else "NO"))
    cat(sprintf("  Draws retained: %d\n", conv$n_draws))
    cat(sprintf("  Geweke pass: %s\n", if (conv$geweke_pass) "YES" else "NO"))
    cat(sprintf("  ESS pass: %s\n", if (conv$ess_pass) "YES" else "NO"))
    cat(sprintf("  ESS range: %.0f - %.0f\n",
                min(conv$effective_sample_size), max(conv$effective_sample_size)))
  }

  # --- HB respondent quality ---
  if (!is.null(hb_results$model_result$respondent_quality)) {
    quality <- hb_results$model_result$respondent_quality
    cat("\n  HB RESPONDENT QUALITY (RLH)\n")
    cat("  ============================\n")
    cat(sprintf("  Mean RLH: %.3f (chance = %.3f)\n", quality$mean_rlh, quality$chance_rlh))
    cat(sprintf("  Median RLH: %.3f\n", quality$median_rlh))
    cat(sprintf("  Flagged respondents: %d of %d (%.1f%%)\n",
                quality$n_flagged, length(quality$rlh_scores),
                100 * quality$n_flagged / length(quality$rlh_scores)))
  }

  cat("\n  TIMING COMPARISON\n")
  cat("  ==================\n")
  cat(sprintf("  MNL: %.1f seconds\n", t1_elapsed))
  cat(sprintf("  HB:  %.1f seconds (%.0fx slower)\n", t2_elapsed, t2_elapsed / max(t1_elapsed, 0.1)))

} else {
  cat("  Cannot compare — one or both analyses failed.\n")
}

# =====================================================================
# PART 4: GENERATE HB HTML REPORT
# =====================================================================

cat("\n[5/5] Generating HB HTML report...\n")

if (!is.null(hb_results) && exists("generate_conjoint_html_report", mode = "function")) {

  conjoint_results <- list(
    utilities = hb_results$utilities,
    importance = hb_results$importance,
    model_result = hb_results$model_result,
    diagnostics = hb_results$diagnostics,
    config = hb_results$config
  )

  # WTP
  wtp_config <- hb_results$config
  wtp_config$wtp_price_attribute <- "Price"
  wtp_result <- tryCatch(
    calculate_wtp(hb_results$utilities, wtp_config,
                  model_result = hb_results$model_result, verbose = FALSE),
    error = function(e) { cat(sprintf("  WTP error: %s\n", conditionMessage(e))); NULL }
  )
  conjoint_results$wtp <- wtp_result

  report_config <- list(
    project_name = "Smartphone Conjoint — HB Analysis",
    brand_colour = "#323367",
    accent_colour = "#CC9900",
    analyst_name = "Demo Analyst",
    company_name = "The Research LampPost",
    client_name = "Demo Client",
    closing_notes = "HB analysis on synthetic data. Compare with MNL report for methodology differences.",
    insight_overview = "HB estimation provides individual-level utilities, revealing preference heterogeneity across respondents.",
    insight_utilities = "These utilities represent the average across individual respondent estimates. Check the respondent quality tab for individual-level RLH scores.",
    insight_diagnostics = "HB convergence diagnostics show whether the MCMC chains have stabilised. Check Geweke scores and effective sample sizes.",
    insight_simulator = "The simulator uses aggregate HB utilities. For individual-level simulation, use the R-side predict functions.",
    insight_wtp = "Individual-level WTP distributions are available — showing not just the average WTP but the full spread across respondents."
  )

  html_path <- file.path(output_dir, "demo_hb_report.html")
  html_result <- tryCatch(
    generate_conjoint_html_report(conjoint_results, html_path, report_config),
    error = function(e) { cat(sprintf("  HTML error: %s\n", conditionMessage(e))); NULL }
  )

  if (!is.null(html_result) && html_result$status == "PASS") {
    cat(sprintf("  HB report: %s\n", html_path))
  }
} else {
  cat("  Skipped (HB results not available)\n")
}

# --- Summary ---
cat("\n")
cat("================================================================\n")
cat("  COMPARISON COMPLETE\n")
cat("================================================================\n")
cat("\n  Output files:\n")
for (f in list.files(output_dir, full.names = TRUE)) {
  size_kb <- round(file.size(f) / 1024, 1)
  cat(sprintf("    %s (%s KB)\n", basename(f), size_kb))
}
cat("\n  Open demo_results_report.html for the MNL report\n")
cat("  Open demo_hb_report.html for the HB report\n")
cat("  Compare side by side to see the difference!\n\n")
