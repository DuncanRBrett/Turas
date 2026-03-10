# =============================================================================
# Turas Pricing Module — Full Capability Demo Runner
# Product: CloudSync Pro (cloud storage SaaS)
# =============================================================================
#
# Runs ALL pricing module capabilities:
#   - Van Westendorp PSM (with NMS extension)
#   - Gabor-Granger demand curve analysis
#   - Segment analysis across 3 customer groups
#   - Price ladder (Value / Standard / Premium)
#   - Recommendation synthesis with confidence scoring
#   - Interactive HTML report
#   - Interactive simulator dashboard
#   - Monadic price testing (logistic regression)
#
# Run from Turas project root:
#   source("examples/pricing/demo_showcase/run_demo.R")
#
# Prerequisites:
#   - Required: openxlsx, readxl, ggplot2
#   - Optional: pricesensitivitymeter (for VW analysis)
#   - Run generate_demo_data.R first to create data & config files
# =============================================================================

cat("\n")
cat("###########################################################\n")
cat("#                                                         #\n")
cat("#   TURAS PRICING MODULE v12.0 — FULL CAPABILITY DEMO     #\n")
cat("#   Product: CloudSync Pro (Cloud Storage SaaS)           #\n")
cat("#                                                         #\n")
cat("###########################################################\n\n")

# ---------------------------------------------------------------------------
# 0. Verify prerequisites
# ---------------------------------------------------------------------------

demo_dir <- "examples/pricing/demo_showcase"

# Check we're in the Turas root
if (!file.exists("launch_turas.R") && !file.exists("CLAUDE.md")) {
  stop("Please run this script from the Turas project root directory.\n",
       "  setwd('/path/to/Turas')\n",
       "  source('examples/pricing/demo_showcase/run_demo.R')", call. = FALSE)
}

# Check data file exists
data_file <- file.path(demo_dir, "demo_data.csv")
if (!file.exists(data_file)) {
  stop("Demo data not found. Generate it first:\n",
       "  source('examples/pricing/demo_showcase/generate_demo_data.R')", call. = FALSE)
}

# Check config files exist
config_vwgg <- file.path(demo_dir, "Demo_Pricing_Config.xlsx")
config_monadic <- file.path(demo_dir, "Demo_Monadic_Config.xlsx")
if (!file.exists(config_vwgg) || !file.exists(config_monadic)) {
  stop("Config files not found. Generate them first:\n",
       "  source('examples/pricing/demo_showcase/generate_demo_data.R')", call. = FALSE)
}

# Check required packages
required_pkgs <- c("openxlsx", "readxl", "ggplot2")
missing_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop(sprintf("Missing required packages: %s\nInstall with: install.packages(c('%s'))",
               paste(missing_pkgs, collapse = ", "),
               paste(missing_pkgs, collapse = "', '")), call. = FALSE)
}

has_psm <- requireNamespace("pricesensitivitymeter", quietly = TRUE)
if (!has_psm) {
  cat("NOTE: pricesensitivitymeter package not installed.\n")
  cat("  Van Westendorp analysis will use fallback implementation.\n")
  cat("  For NMS extension: install.packages('pricesensitivitymeter')\n\n")
}

# ---------------------------------------------------------------------------
# 1. Source module files
# ---------------------------------------------------------------------------

cat("1. Sourcing pricing module...\n")

# Source shared utilities
shared_lib <- file.path("modules", "shared", "lib")
if (dir.exists(shared_lib)) {
  for (f in sort(list.files(shared_lib, pattern = "[.]R$", full.names = TRUE))) {
    tryCatch(source(f), error = function(e) NULL)
  }
}

# Source all pricing R files (sorted order)
pricing_r_dir <- file.path("modules", "pricing", "R")
pricing_files <- sort(list.files(pricing_r_dir, pattern = "[.]R$", full.names = TRUE))
for (fpath in pricing_files) {
  tryCatch(source(fpath), error = function(e) {
    message(sprintf("   Warning: Could not source %s: %s", basename(fpath), e$message))
  })
}

# Source HTML report modules
html_report_dir <- file.path("modules", "pricing", "lib", "html_report")
if (dir.exists(html_report_dir)) {
  for (f in sort(list.files(html_report_dir, pattern = "[.]R$", full.names = TRUE))) {
    tryCatch(source(f), error = function(e) NULL)
  }
}

# Source simulator builder
sim_builder <- file.path("modules", "pricing", "lib", "simulator", "simulator_builder.R")
if (file.exists(sim_builder)) {
  tryCatch(source(sim_builder), error = function(e) NULL)
}

# Source config template generator
template_gen <- file.path("modules", "pricing", "lib", "generate_config_templates.R")
if (file.exists(template_gen)) {
  tryCatch(source(template_gen), error = function(e) NULL)
}

cat("   Module loaded successfully.\n\n")

# Create output directory
output_dir <- file.path(demo_dir, "output")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# ===========================================================================
# ANALYSIS 1: Van Westendorp + Gabor-Granger (Combined)
# ===========================================================================

cat("###########################################################\n")
cat("#  ANALYSIS 1: Van Westendorp + Gabor-Granger Combined    #\n")
cat("###########################################################\n\n")

results_vwgg <- tryCatch({
  run_pricing_analysis(
    config_file = config_vwgg
  )
}, error = function(e) {
  cat("\n!!! Analysis 1 encountered an error:\n")
  cat("   ", e$message, "\n\n")
  NULL
})

if (!is.null(results_vwgg)) {
  cat("\n-----------------------------------------------------------\n")
  cat("  ANALYSIS 1 RESULTS SUMMARY\n")
  cat("-----------------------------------------------------------\n\n")

  # Van Westendorp results
  if (!is.null(results_vwgg$results$price_points)) {
    pp <- results_vwgg$results$price_points
    cat("  VAN WESTENDORP PRICE POINTS:\n")
    cat(sprintf("    PMC (Marginal Cheapness):     $%.2f\n", pp$PMC))
    cat(sprintf("    OPP (Optimal Price):          $%.2f\n", pp$OPP))
    cat(sprintf("    IDP (Indifference Point):     $%.2f\n", pp$IDP))
    cat(sprintf("    PME (Marginal Expensiveness): $%.2f\n", pp$PME))
    cat(sprintf("    Acceptable Range: $%.2f - $%.2f\n", pp$PMC, pp$PME))
    cat(sprintf("    Optimal Zone:     $%.2f - $%.2f\n", pp$OPP, pp$IDP))
    cat("\n")
  }

  # Gabor-Granger results
  if (!is.null(results_vwgg$results$optimal_price)) {
    opt <- results_vwgg$results$optimal_price
    cat("  GABOR-GRANGER OPTIMAL PRICE:\n")
    cat(sprintf("    Revenue-maximising: $%.2f (%.1f%% intent)\n",
                opt$price, opt$purchase_intent * 100))
    if (!is.null(results_vwgg$results$optimal_price_profit)) {
      profit_opt <- results_vwgg$results$optimal_price_profit
      cat(sprintf("    Profit-maximising:  $%.2f (%.1f%% intent)\n",
                  profit_opt$price, profit_opt$purchase_intent * 100))
    }
    cat("\n")
  }

  # Synthesis
  if (!is.null(results_vwgg$synthesis)) {
    syn <- results_vwgg$synthesis
    if (!is.null(syn$recommendation)) {
      cat("  SYNTHESISED RECOMMENDATION:\n")
      cat(sprintf("    Recommended price: $%.2f\n", syn$recommendation$price))
      if (!is.null(syn$recommendation$confidence_score)) {
        cat(sprintf("    Confidence:        %.0f%% (%s)\n",
                    syn$recommendation$confidence_score * 100,
                    syn$recommendation$confidence %||% "N/A"))
      }
      cat("\n")
    }
  }

  # Segment results
  if (!is.null(results_vwgg$segment_results)) {
    cat("  SEGMENT ANALYSIS:\n")
    if (!is.null(results_vwgg$segment_results$comparison_table)) {
      comp <- results_vwgg$segment_results$comparison_table
      for (j in seq_len(nrow(comp))) {
        cat(sprintf("    %s: n=%s\n",
                    comp$segment[j],
                    comp$n[j]))
      }
    }
    cat("\n")
  }

  # Output files
  cat("  OUTPUT FILES:\n")
  if (!is.null(results_vwgg$html_report_path) && file.exists(results_vwgg$html_report_path)) {
    cat(sprintf("    HTML Report:  %s\n", results_vwgg$html_report_path))
  }
  if (!is.null(results_vwgg$simulator_path) && file.exists(results_vwgg$simulator_path)) {
    cat(sprintf("    Simulator:    %s\n", results_vwgg$simulator_path))
  }
  cat("\n")
}

# ===========================================================================
# ANALYSIS 2: Monadic Price Testing
# ===========================================================================

cat("\n")
cat("###########################################################\n")
cat("#  ANALYSIS 2: Monadic Price Testing                      #\n")
cat("###########################################################\n\n")

results_monadic <- tryCatch({
  run_pricing_analysis(
    config_file = config_monadic
  )
}, error = function(e) {
  cat("\n!!! Analysis 2 encountered an error:\n")
  cat("   ", e$message, "\n\n")
  NULL
})

if (!is.null(results_monadic)) {
  cat("\n-----------------------------------------------------------\n")
  cat("  ANALYSIS 2 RESULTS SUMMARY\n")
  cat("-----------------------------------------------------------\n\n")

  # Monadic model summary
  if (!is.null(results_monadic$results$model_summary)) {
    ms <- results_monadic$results$model_summary
    cat("  MONADIC MODEL:\n")
    cat(sprintf("    Model type:     %s\n", ms$model_type %||% "logistic"))
    cat(sprintf("    Pseudo-R2:      %.4f\n", ms$pseudo_r2 %||% NA))
    cat(sprintf("    AIC:            %.1f\n", ms$aic %||% NA))
    cat(sprintf("    Price coeff p:  %.4f\n", ms$price_coefficient_p %||% NA))
    cat(sprintf("    N observations: %d\n", ms$n_observations %||% 0))
    cat("\n")
  }

  # Optimal price
  if (!is.null(results_monadic$results$optimal_price)) {
    opt <- results_monadic$results$optimal_price
    cat("  MONADIC OPTIMAL PRICE:\n")
    cat(sprintf("    Revenue-maximising: $%.2f (%.1f%% predicted intent)\n",
                opt$price, opt$predicted_intent * 100))
    if (!is.null(results_monadic$results$optimal_price_profit)) {
      profit_opt <- results_monadic$results$optimal_price_profit
      cat(sprintf("    Profit-maximising:  $%.2f\n", profit_opt$price))
    }
    cat("\n")
  }

  # Bootstrap CIs
  if (!is.null(results_monadic$results$confidence_intervals)) {
    ci <- results_monadic$results$confidence_intervals
    if (!is.null(ci$optimal_price_ci)) {
      cat("  BOOTSTRAP CONFIDENCE INTERVALS:\n")
      cat(sprintf("    Revenue-optimal 95%% CI: [$%.2f, $%.2f]\n",
                  ci$optimal_price_ci[1], ci$optimal_price_ci[2]))
    }
    if (!is.null(ci$n_successful)) {
      cat(sprintf("    Successful iterations: %d/%d\n",
                  ci$n_successful, ci$n_attempted %||% ci$n_successful))
    }
    cat("\n")
  }
}

# ===========================================================================
# FINAL SUMMARY
# ===========================================================================

cat("\n")
cat("###########################################################\n")
cat("#  DEMO COMPLETE — OUTPUT FILES                           #\n")
cat("###########################################################\n\n")

output_files <- list.files(output_dir, full.names = TRUE)
if (length(output_files) > 0) {
  for (f in output_files) {
    size_kb <- round(file.info(f)$size / 1024, 1)
    cat(sprintf("  %s (%s KB)\n", f, size_kb))
  }
} else {
  cat("  No output files found. Check for errors above.\n")
}

cat("\n")
cat("  To view the HTML report, open:\n")
cat(sprintf("    %s\n", file.path(output_dir, "demo_report.html")))
cat("\n")
cat("  To view the interactive simulator, open:\n")
cat(sprintf("    %s\n", file.path(output_dir, "demo_simulator.html")))
cat("\n")
cat("###########################################################\n\n")
