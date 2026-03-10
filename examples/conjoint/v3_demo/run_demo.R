# ==============================================================================
# CONJOINT v3.0 DEMO - FULL PIPELINE TEST
# ==============================================================================
#
# This script runs the complete conjoint analysis pipeline on synthetic data
# to demonstrate all v3.0 capabilities:
#
#   1. Aggregate MNL estimation (mlogit/clogit)
#   2. Utilities and importance calculation
#   3. Market simulation (logit shares)
#   4. Willingness to Pay (WTP)
#   5. Product optimization
#   6. HTML analysis report
#   7. HTML standalone simulator
#   8. Excel output with all sheets
#
# USAGE:
#   source("examples/conjoint/v3_demo/run_demo.R")
#   (from the Turas root directory)
#
# OUTPUT:
#   examples/conjoint/v3_demo/output/demo_results.xlsx
#   examples/conjoint/v3_demo/output/demo_results_report.html
#   examples/conjoint/v3_demo/output/demo_results_simulator.html
#
# ==============================================================================

cat("\n")
cat("================================================================\n")
cat("  TURAS CONJOINT v3.0 DEMO\n")
cat("  Testing full pipeline on synthetic smartphone data\n")
cat("================================================================\n\n")

# --- Setup paths ---
turas_root <- getwd()
demo_dir   <- file.path(turas_root, "examples", "conjoint", "v3_demo")
output_dir <- file.path(demo_dir, "output")

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# Verify we're in the right place
if (!file.exists(file.path(turas_root, "launch_turas.R"))) {
  stop("Please run this script from the Turas root directory:\n  setwd('/path/to/Turas')\n  source('examples/conjoint/v3_demo/run_demo.R')")
}

# Verify data exists
data_file <- file.path(demo_dir, "demo_data.csv")
if (!file.exists(data_file)) {
  stop("Demo data not found. Run generate_demo_data.R first.")
}

# --- Step 1: Source the conjoint module ---
cat("[1/8] Loading conjoint module...\n")
source(file.path(turas_root, "modules", "conjoint", "R", "00_main.R"))
cat("  Done.\n\n")

# --- Step 2: Run analysis via main entry point ---
cat("[2/8] Running aggregate analysis (mlogit)...\n")
config_file <- file.path(demo_dir, "demo_config.xlsx")

# Override output to go to output directory
results <- tryCatch({
  run_conjoint_analysis(
    config_file = config_file,
    data_file   = data_file,
    output_file = file.path(output_dir, "demo_results.xlsx"),
    verbose     = TRUE
  )
}, error = function(e) {
  cat(sprintf("\n  ERROR: %s\n", conditionMessage(e)))
  NULL
})

if (is.null(results)) {
  cat("\n  Analysis failed. See error above.\n")
} else {
  cat(sprintf("\n  Status: %s\n", results$run_result$status %||% "COMPLETE"))
}

# --- Step 3: WTP calculation ---
cat("\n[3/8] Calculating Willingness to Pay...\n")
if (exists("calculate_wtp", mode = "function") && !is.null(results$utilities)) {

  wtp_config <- results$config
  wtp_config$wtp_price_attribute <- "Price"

  wtp_result <- tryCatch({
    calculate_wtp(results$utilities, wtp_config, model_result = results$model_result, verbose = TRUE)
  }, error = function(e) {
    cat(sprintf("  WTP error: %s\n", conditionMessage(e)))
    NULL
  })

  if (!is.null(wtp_result) && !is.null(wtp_result$wtp_table)) {
    cat("\n  WTP Results:\n")
    wtp <- wtp_result$wtp_table
    for (i in seq_len(nrow(wtp))) {
      if (!wtp$is_baseline[i]) {
        cat(sprintf("    %s / %s: $%.2f\n", wtp$Attribute[i], wtp$Level[i], wtp$WTP[i]))
      }
    }
    cat(sprintf("  Price coefficient: %.4f\n", wtp_result$price_coefficient))
  }
} else {
  cat("  Skipped (calculate_wtp not available or no utilities)\n")
}

# --- Step 4: Product optimization ---
cat("\n[4/8] Running product optimizer...\n")
if (exists("optimize_product_exhaustive", mode = "function") && !is.null(results$utilities)) {

  opt_config <- results$config
  competitors <- list(
    list(Brand = "TechPro", Price = "$199", Screen = "5.5 inch", Battery = "3000mAh", Storage = "64GB"),
    list(Brand = "ValueMax", Price = "$299", Screen = "6.1 inch", Battery = "4500mAh", Storage = "128GB")
  )

  opt_result <- tryCatch({
    optimize_product_exhaustive(results$utilities, opt_config, competitors, top_n = 5, verbose = TRUE)
  }, error = function(e) {
    cat(sprintf("  Optimizer error: %s\n", conditionMessage(e)))
    NULL
  })

  if (!is.null(opt_result) && !is.null(opt_result$top_products)) {
    cat("\n  Top 5 product configurations:\n")
    for (i in seq_len(min(5, length(opt_result$top_products)))) {
      prod <- opt_result$top_products[[i]]
      config_str <- paste(sapply(names(prod$configuration), function(a)
        paste0(a, "=", prod$configuration[[a]])), collapse = ", ")
      cat(sprintf("    #%d: Score=%.4f (%s)\n", i, prod$score, config_str))
    }
  }
} else {
  cat("  Skipped (optimizer not available or no utilities)\n")
}

# --- Step 5: Market simulation ---
cat("\n[5/8] Running market simulation...\n")
if (exists("predict_market_shares", mode = "function") && !is.null(results$utilities)) {

  products <- list(
    list(Brand = "TechPro",  Price = "$199", Screen = "6.1 inch", Battery = "4500mAh", Storage = "128GB"),
    list(Brand = "ValueMax", Price = "$299", Screen = "6.1 inch", Battery = "4500mAh", Storage = "128GB"),
    list(Brand = "PremiumX", Price = "$399", Screen = "6.7 inch", Battery = "5000mAh", Storage = "256GB")
  )

  shares <- tryCatch({
    predict_market_shares(products, results$utilities, method = "logit")
  }, error = function(e) {
    cat(sprintf("  Simulation error: %s\n", conditionMessage(e)))
    NULL
  })

  if (!is.null(shares)) {
    cat("  Market shares:\n")
    labels <- c("TechPro ($199)", "ValueMax ($299)", "PremiumX ($399)")
    for (i in seq_len(nrow(shares))) {
      cat(sprintf("    %s: %.1f%%\n", labels[i], shares$Share_Percent[i]))
    }
  }
} else {
  cat("  Skipped (simulator not available)\n")
}

# --- Step 6: Source of volume ---
cat("\n[6/8] Source of volume analysis...\n")
if (exists("source_of_volume", mode = "function") && !is.null(results$utilities)) {

  baseline <- list(
    list(Brand = "TechPro",  Price = "$199", Screen = "6.1 inch", Battery = "4500mAh", Storage = "128GB"),
    list(Brand = "ValueMax", Price = "$299", Screen = "6.1 inch", Battery = "4500mAh", Storage = "128GB")
  )
  new_product <- list(Brand = "PremiumX", Price = "$399", Screen = "6.7 inch", Battery = "5000mAh", Storage = "256GB")

  sov <- tryCatch({
    source_of_volume(baseline, new_product, utilities = results$utilities, method = "logit")
  }, error = function(e) {
    cat(sprintf("  SoV error: %s\n", conditionMessage(e)))
    NULL
  })

  if (!is.null(sov)) {
    cat("  Share shifts when PremiumX enters market:\n")
    for (i in seq_len(nrow(sov))) {
      cat(sprintf("    %s: %+.1f pp share shift\n", sov$Product[i], sov$Share_Change[i]))
    }
  }
} else {
  cat("  Skipped\n")
}

# --- Step 7: HTML report ---
cat("\n[7/8] Generating HTML analysis report...\n")
if (exists("generate_conjoint_html_report", mode = "function") && !is.null(results)) {

  conjoint_results <- list(
    utilities    = results$utilities,
    importance   = results$importance,
    model_result = results$model_result,
    diagnostics  = results$diagnostics,
    config       = results$config
  )

  report_config <- list(
    project_name = "Smartphone Conjoint v3.0 Demo",
    brand_colour = "#1e40af",
    accent_colour = "#f59e0b"
  )

  html_path <- file.path(output_dir, "demo_results_report.html")
  report_result <- tryCatch({
    generate_conjoint_html_report(conjoint_results, html_path, report_config)
  }, error = function(e) {
    cat(sprintf("  HTML report error: %s\n", conditionMessage(e)))
    NULL
  })

  if (!is.null(report_result) && report_result$status == "PASS") {
    cat(sprintf("  Written to: %s\n", html_path))
  }
} else {
  cat("  Skipped (generate_conjoint_html_report not available)\n")
}

# --- Step 8: HTML simulator ---
cat("\n[8/8] Generating HTML standalone simulator...\n")
if (exists("generate_conjoint_html_simulator", mode = "function") && !is.null(results)) {

  sim_config <- results$config
  sim_config$project_name <- "Smartphone Conjoint Simulator"
  sim_config$brand_colour <- "#1e40af"

  sim_path <- file.path(output_dir, "demo_results_simulator.html")
  sim_result <- tryCatch({
    generate_conjoint_html_simulator(
      results$utilities,
      results$importance,
      results$model_result,
      sim_config,
      sim_path
    )
  }, error = function(e) {
    cat(sprintf("  HTML simulator error: %s\n", conditionMessage(e)))
    NULL
  })

  if (!is.null(sim_result) && sim_result$status == "PASS") {
    cat(sprintf("  Written to: %s\n", sim_path))
  }
} else {
  cat("  Skipped (generate_conjoint_html_simulator not available)\n")
}

# --- Summary ---
cat("\n")
cat("================================================================\n")
cat("  DEMO COMPLETE\n")
cat("================================================================\n")
cat("\n  Output files:\n")
output_files <- list.files(output_dir, full.names = TRUE)
for (f in output_files) {
  size_kb <- round(file.size(f) / 1024, 1)
  cat(sprintf("    %s (%s KB)\n", basename(f), size_kb))
}
cat(sprintf("\n  Output directory: %s\n", output_dir))
cat("\n  To view HTML report:  Open demo_results_report.html in browser\n")
cat("  To use simulator:     Open demo_results_simulator.html in browser\n")
cat("\n")
