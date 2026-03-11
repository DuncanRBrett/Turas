# ==============================================================================
# CUSTOMER SEGMENTATION DEMO - Runner Script
# ==============================================================================
# Demonstrates all modes of the Turas Segment module using synthetic
# customer data with 4 embedded segments.
#
# Usage:
#   1. Set working directory to the demo folder
#   2. Source this script: source("run_customer_demo.R")
#   3. Call one of the run functions below
#
# Prerequisites:
#   - Turas segment module properly installed
#   - customer_data.csv generated (run generate_customer_data.R if missing)
#   - Config Excel files present
# ==============================================================================

# Setup paths
demo_dir <- dirname(sys.frame(1)$ofile %||% getwd())
turas_root <- normalizePath(file.path(demo_dir, "../../.."))

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("TURAS SEGMENT MODULE - CUSTOMER SEGMENTATION DEMO\n")
cat(rep("=", 80), "\n", sep = "")
cat(sprintf("\nDemo directory: %s\n", demo_dir))
cat(sprintf("Turas root: %s\n\n", turas_root))

# Set environment for module loading
Sys.setenv(TURAS_ROOT = turas_root)

# Source the segment module
segment_main <- file.path(turas_root, "modules/segment/R/00_main.R")
if (!file.exists(segment_main)) {
  stop("Segment module not found at: ", segment_main)
}


#' Run Exploration Mode
#'
#' Tests k = 2 to 7 with K-means to find optimal number of segments.
run_exploration <- function() {
  cat("\n--- MODE: EXPLORATION (k = 2 to 7) ---\n\n")
  config_file <- file.path(demo_dir, "customer_explore_config.xlsx")
  source(segment_main)
  result <- run_segmentation(config_file)
  cat("\nExploration mode complete. Check output_explore/ for results.\n")
  invisible(result)
}


#' Run Final Mode (K-means, k=4)
#'
#' Full segmentation with profiling, validation, scoring, cards, and reports.
run_final <- function() {
  cat("\n--- MODE: FINAL (k = 4, K-means, all features) ---\n\n")
  config_file <- file.path(demo_dir, "customer_final_config.xlsx")
  source(segment_main)
  result <- run_segmentation(config_file)
  cat("\nFinal mode complete. Check output_final/ for results.\n")
  invisible(result)
}


#' Run Multi-Method Comparison
#'
#' Compares K-means, Hierarchical, and GMM at k=4.
run_combined <- function() {
  cat("\n--- MODE: MULTI-METHOD COMPARISON (kmeans, hclust, gmm) ---\n\n")
  config_file <- file.path(demo_dir, "customer_combined_config.xlsx")
  source(segment_main)
  result <- run_segmentation(config_file)
  cat("\nMulti-method comparison complete. Check output_combined/ for results.\n")
  invisible(result)
}


#' Run Ensemble Clustering
#'
#' Consensus clustering combining K-means and hierarchical methods.
run_ensemble <- function() {
  cat("\n--- MODE: ENSEMBLE CLUSTERING ---\n\n")
  config_file <- file.path(demo_dir, "customer_ensemble_config.xlsx")
  source(segment_main)
  result <- run_segmentation(config_file)
  cat("\nEnsemble clustering complete. Check output_ensemble/ for results.\n")
  invisible(result)
}


#' Run All Modes
#'
#' Sequentially runs all 4 demo configurations.
run_all <- function() {
  cat("\n")
  cat(rep("*", 80), "\n", sep = "")
  cat("RUNNING ALL DEMO MODES\n")
  cat(rep("*", 80), "\n", sep = "")

  results <- list()

  cat("\n[1/4] Exploration mode...\n")
  results$explore <- tryCatch(run_exploration(), error = function(e) {
    cat(sprintf("  ERROR: %s\n", e$message))
    NULL
  })

  cat("\n[2/4] Final mode...\n")
  results$final <- tryCatch(run_final(), error = function(e) {
    cat(sprintf("  ERROR: %s\n", e$message))
    NULL
  })

  cat("\n[3/4] Multi-method comparison...\n")
  results$combined <- tryCatch(run_combined(), error = function(e) {
    cat(sprintf("  ERROR: %s\n", e$message))
    NULL
  })

  cat("\n[4/4] Ensemble clustering...\n")
  results$ensemble <- tryCatch(run_ensemble(), error = function(e) {
    cat(sprintf("  ERROR: %s\n", e$message))
    NULL
  })

  cat("\n")
  cat(rep("*", 80), "\n", sep = "")
  cat("ALL DEMO MODES COMPLETE\n")
  cat(rep("*", 80), "\n\n")

  # Summary
  for (mode in names(results)) {
    status <- if (is.null(results[[mode]])) "FAILED" else "SUCCESS"
    cat(sprintf("  %-20s %s\n", mode, status))
  }
  cat("\n")

  invisible(results)
}


# Print available commands
cat("Available demo functions:\n")
cat("  run_exploration()  - Test k=2 to 7 (exploration mode)\n")
cat("  run_final()        - Full k=4 segmentation with all features\n")
cat("  run_combined()     - Compare kmeans, hclust, gmm methods\n")
cat("  run_ensemble()     - Consensus/ensemble clustering\n")
cat("  run_all()          - Run all modes sequentially\n")
cat("\n")
