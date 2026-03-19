# ==============================================================================
# TURAS SEGMENTATION DEMO - RUN ALL ANALYSES
# ==============================================================================
# Runs the complete segmentation demo pipeline:
#
#   Step 1: Generate synthetic customer data (800 respondents)
#   Step 2: Create configuration files (4 configs)
#   Step 3: Run all 4 segmentation analyses sequentially
#
# This script demonstrates:
#   - K-means exploration mode (how many segments?)
#   - K-means final solution (4-segment solution)
#   - Hierarchical clustering (alternative algorithm)
#   - Gaussian Mixture Model (probabilistic clustering)
#   - HTML report generation for each run
#   - Outlier detection, profiling, classification rules, action cards
#
# Prerequisites:
#   - R 4.0+ with required packages (renv::restore() from project root)
#   - TURAS_ROOT environment variable set to project root
#
# Usage:
#   # From the Turas project root:
#   Sys.setenv(TURAS_ROOT = getwd())
#   source("examples/segment/demo_showcase/run_demo.R")
#
#   # Or set working directory to the demo folder:
#   setwd("examples/segment/demo_showcase")
#   Sys.setenv(TURAS_ROOT = normalizePath("../../.."))
#   source("run_demo.R")
#
# Version: 1.0
# ==============================================================================


# ==========================================================================
# SETUP
# ==========================================================================

cat("\n")
cat("##############################################################\n")
cat("#                                                            #\n")
cat("#   TURAS SEGMENTATION MODULE - SALES DEMO                  #\n")
cat("#                                                            #\n")
cat("#   Demonstrating multi-algorithm customer segmentation      #\n")
cat("#   with automated reporting and actionable insights         #\n")
cat("#                                                            #\n")
cat("##############################################################\n")
cat("\n")

# Determine Turas root
turas_root <- Sys.getenv("TURAS_ROOT", "")

if (turas_root == "") {
  # Try to auto-detect from common locations
  candidates <- c(
    normalizePath(file.path(getwd(), "..", "..", ".."), mustWork = FALSE),
    normalizePath(file.path(getwd()), mustWork = FALSE)
  )
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "modules", "segment", "run_segment.R"))) {
      turas_root <- candidate
      break
    }
  }
  if (turas_root == "") {
    stop(paste(
      "Cannot determine TURAS_ROOT.",
      "Set it before running: Sys.setenv(TURAS_ROOT = '/path/to/turas')"
    ))
  }
  Sys.setenv(TURAS_ROOT = turas_root)
}

cat(sprintf("TURAS_ROOT: %s\n", turas_root))

# Determine demo directory
demo_dir <- tryCatch({
  # Works when called via source()
  dirname(sys.frame(1)$ofile)
}, error = function(e) {
  # Fallback: try commandArgs for Rscript execution
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    dirname(normalizePath(sub("^--file=", "", file_arg[1])))
  } else {
    getwd()
  }
})

cat(sprintf("Demo directory: %s\n\n", demo_dir))

# Save and restore working directory
original_wd <- getwd()
on.exit(setwd(original_wd), add = TRUE)
setwd(demo_dir)


# ==========================================================================
# STEP 1: GENERATE DEMO DATA
# ==========================================================================

cat("=== STEP 1: Generating demo data ===\n\n")

data_file <- file.path(demo_dir, "demo_customer_data.csv")

if (file.exists(data_file)) {
  cat("Demo data already exists, skipping generation.\n")
  cat(sprintf("  File: %s\n", data_file))
  cat(sprintf("  Size: %.1f KB\n\n", file.info(data_file)$size / 1024))
} else {
  source(file.path(demo_dir, "generate_demo_data.R"))
  cat("\n")
}


# ==========================================================================
# STEP 2: CREATE CONFIG FILES
# ==========================================================================

cat("=== STEP 2: Creating configuration files ===\n\n")

config_files <- c(
  "demo_kmeans_explore.xlsx",
  "demo_kmeans_final.xlsx",
  "demo_hclust_final.xlsx",
  "demo_gmm_final.xlsx",
  "demo_combined_config.xlsx"
)

all_configs_exist <- all(file.exists(file.path(demo_dir, config_files)))

if (all_configs_exist) {
  cat("All config files already exist, skipping generation.\n")
  for (f in config_files) {
    cat(sprintf("  %s\n", f))
  }
  cat("\n")
} else {
  source(file.path(demo_dir, "create_demo_configs.R"))
  cat("\n")
}


# ==========================================================================
# STEP 3: SOURCE THE SEGMENT MODULE
# ==========================================================================

cat("=== STEP 3: Loading Turas segment module ===\n\n")

source(file.path(turas_root, "modules", "segment", "run_segment.R"))

cat("Segment module loaded successfully.\n\n")


# ==========================================================================
# STEP 4: RUN ANALYSES
# ==========================================================================

# Track results for final summary
run_results <- list()
run_times <- list()

# --------------------------------------------------------------------------
# RUN 1: K-means Exploration
# --------------------------------------------------------------------------
# This run tests k = 3, 4, 5, and 6 and recommends the best k based on
# silhouette scores, the elbow method, and cluster size balance.
# It produces a k-selection report comparing all solutions.

cat("##############################################################\n")
cat("#  RUN 1: K-means Exploration (k = 3 to 6)                  #\n")
cat("##############################################################\n\n")

t1 <- Sys.time()
run_results$kmeans_explore <- tryCatch({
  turas_segment_from_config(file.path(demo_dir, "demo_kmeans_explore.xlsx"))
}, error = function(e) {
  cat(sprintf("\n[ERROR] K-means exploration failed: %s\n\n", e$message))
  list(status = "FAILED", error = e$message)
})
run_times$kmeans_explore <- as.numeric(difftime(Sys.time(), t1, units = "secs"))

cat("\n\n")


# --------------------------------------------------------------------------
# RUN 2: K-means Final (k = 4)
# --------------------------------------------------------------------------
# Based on the exploration results, we proceed with k = 4.
# This produces the full segment solution with profiles, rules,
# action cards, and an HTML report.

cat("##############################################################\n")
cat("#  RUN 2: K-means Final Solution (k = 4)                    #\n")
cat("##############################################################\n\n")

t2 <- Sys.time()
run_results$kmeans_final <- tryCatch({
  turas_segment_from_config(file.path(demo_dir, "demo_kmeans_final.xlsx"))
}, error = function(e) {
  cat(sprintf("\n[ERROR] K-means final failed: %s\n\n", e$message))
  list(status = "FAILED", error = e$message)
})
run_times$kmeans_final <- as.numeric(difftime(Sys.time(), t2, units = "secs"))

cat("\n\n")


# --------------------------------------------------------------------------
# RUN 3: Hierarchical Clustering Final (k = 4)
# --------------------------------------------------------------------------
# Demonstrates the same data analyzed with hierarchical clustering
# (Ward's method). Useful for comparing solutions across algorithms.

cat("##############################################################\n")
cat("#  RUN 3: Hierarchical Clustering (k = 4, Ward's D2)        #\n")
cat("##############################################################\n\n")

t3 <- Sys.time()
run_results$hclust_final <- tryCatch({
  turas_segment_from_config(file.path(demo_dir, "demo_hclust_final.xlsx"))
}, error = function(e) {
  cat(sprintf("\n[ERROR] Hierarchical clustering failed: %s\n\n", e$message))
  list(status = "FAILED", error = e$message)
})
run_times$hclust_final <- as.numeric(difftime(Sys.time(), t3, units = "secs"))

cat("\n\n")


# --------------------------------------------------------------------------
# RUN 4: GMM Final (k = 4)
# --------------------------------------------------------------------------
# Gaussian Mixture Models provide probabilistic segment membership,
# showing how confident we are about each respondent's assignment.
# The VVV model type allows each cluster to have its own covariance.

cat("##############################################################\n")
cat("#  RUN 4: Gaussian Mixture Model (k = 4, VVV)               #\n")
cat("##############################################################\n\n")

t4 <- Sys.time()
run_results$gmm_final <- tryCatch({
  turas_segment_from_config(file.path(demo_dir, "demo_gmm_final.xlsx"))
}, error = function(e) {
  cat(sprintf("\n[ERROR] GMM failed: %s\n\n", e$message))
  list(status = "FAILED", error = e$message)
})
run_times$gmm_final <- as.numeric(difftime(Sys.time(), t4, units = "secs"))

cat("\n\n")


# --------------------------------------------------------------------------
# RUN 5: Combined Multi-Method Comparison
# --------------------------------------------------------------------------
# Runs K-means, Hierarchical, and GMM simultaneously on the same data
# and produces a side-by-side comparison report with all methods.

cat("##############################################################\n")
cat("#  RUN 5: Multi-Method Comparison (kmeans + hclust + gmm)    #\n")
cat("##############################################################\n\n")

t5 <- Sys.time()
run_results$combined <- tryCatch({
  turas_segment_from_config(file.path(demo_dir, "demo_combined_config.xlsx"))
}, error = function(e) {
  cat(sprintf("\n[ERROR] Combined analysis failed: %s\n\n", e$message))
  list(status = "FAILED", error = e$message)
})
run_times$combined <- as.numeric(difftime(Sys.time(), t5, units = "secs"))

cat("\n\n")


# ==========================================================================
# SUMMARY
# ==========================================================================

cat("##############################################################\n")
cat("#  DEMO COMPLETE - SUMMARY                                   #\n")
cat("##############################################################\n\n")

# Helper to extract status from varied return types
extract_status <- function(result) {
  if (is.null(result)) return("UNKNOWN")
  # Final mode returns $status

  if (!is.null(result$status)) return(result$status)
  # TRS refusal returns $run_status (e.g., "REFUSE")
  if (!is.null(result$run_status)) return(result$run_status)
  # Exploration mode returns $mode == "exploration" without $status
  if (identical(result$mode, "exploration")) return("PASS")
  "UNKNOWN"
}

cat("Run Results:\n")
cat(sprintf("  %-35s  Status: %-10s  Time: %.1fs\n",
            "1. K-means Exploration (k=3-6)",
            extract_status(run_results$kmeans_explore),
            run_times$kmeans_explore))
cat(sprintf("  %-35s  Status: %-10s  Time: %.1fs\n",
            "2. K-means Final (k=4)",
            extract_status(run_results$kmeans_final),
            run_times$kmeans_final))
cat(sprintf("  %-35s  Status: %-10s  Time: %.1fs\n",
            "3. Hierarchical Clustering (k=4)",
            extract_status(run_results$hclust_final),
            run_times$hclust_final))
cat(sprintf("  %-35s  Status: %-10s  Time: %.1fs\n",
            "4. GMM (k=4)",
            extract_status(run_results$gmm_final),
            run_times$gmm_final))
cat(sprintf("  %-35s  Status: %-10s  Time: %.1fs\n",
            "5. Multi-Method Comparison",
            extract_status(run_results$combined),
            run_times$combined))

total_time <- sum(unlist(run_times))
cat(sprintf("\nTotal demo time: %.1f seconds\n", total_time))

# List output files
cat("\nOutput files generated:\n")
output_dir <- file.path(demo_dir, "output")
if (dir.exists(output_dir)) {
  output_files <- list.files(output_dir, recursive = TRUE, full.names = FALSE)
  if (length(output_files) > 0) {
    for (f in sort(output_files)) {
      fpath <- file.path(output_dir, f)
      fsize <- file.info(fpath)$size
      size_str <- if (fsize > 1048576) {
        sprintf("%.1f MB", fsize / 1048576)
      } else {
        sprintf("%.1f KB", fsize / 1024)
      }
      cat(sprintf("  %-55s  %s\n", f, size_str))
    }
  } else {
    cat("  (no files found)\n")
  }
} else {
  cat("  (output directory not found)\n")
}

cat("\n##############################################################\n")
cat("#  Open the HTML reports in a browser for the full           #\n")
cat("#  interactive experience.                                    #\n")
cat("##############################################################\n\n")
