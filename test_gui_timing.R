#!/usr/bin/env Rscript
# ==============================================================================
# GUI Launch Timing Diagnostic
# ==============================================================================
# This script measures where time is spent when launching a GUI module
# Run this to diagnose slow GUI loading issues
# ==============================================================================

cat("\n=== GUI Launch Timing Diagnostic ===\n\n")

# Simulate the launch environment
Sys.setenv(TURAS_ROOT = getwd())
Sys.setenv(TURAS_SKIP_RENV = "1")

# Test 1: Check if renv gets loaded
cat("Test 1: Checking renv activation...\n")
start_time <- Sys.time()

# Check if .Rprofile would activate renv
test_renv <- function() {
  if (Sys.getenv("TURAS_SKIP_RENV") != "1") {
    return("RENV WOULD BE ACTIVATED (SLOW)")
  } else {
    return("RENV SKIPPED (FAST)")
  }
}

result <- test_renv()
elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
cat(sprintf("  Result: %s (%.3f seconds)\n\n", result, elapsed))

# Test 2: requireNamespace vs installed.packages
cat("Test 2: Package checking methods...\n")

# Old method (slow)
cat("  Testing installed.packages()...\n")
start_time <- Sys.time()
pkgs1 <- "shiny" %in% installed.packages()[,"Package"]
elapsed1 <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
cat(sprintf("    installed.packages(): %.3f seconds\n", elapsed1))

# New method (fast)
cat("  Testing requireNamespace()...\n")
start_time <- Sys.time()
pkgs2 <- requireNamespace("shiny", quietly = TRUE)
elapsed2 <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
cat(sprintf("    requireNamespace():   %.3f seconds\n", elapsed2))
cat(sprintf("    Speedup: %.1fx faster\n\n", elapsed1/elapsed2))

# Test 3: Full module launch simulation
cat("Test 3: Simulating full module launch...\n")
total_start <- Sys.time()

# Step 1: Package check (new fast method)
step_start <- Sys.time()
for (pkg in c("shiny", "shinyFiles")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("    Would install: %s\n", pkg))
  }
}
pkg_time <- as.numeric(difftime(Sys.time(), step_start, units = "secs"))
cat(sprintf("  Package checking: %.3f seconds\n", pkg_time))

# Step 2: Load libraries
step_start <- Sys.time()
suppressPackageStartupMessages({
  library(shiny)
  library(shinyFiles)
})
lib_time <- as.numeric(difftime(Sys.time(), step_start, units = "secs"))
cat(sprintf("  Loading libraries: %.3f seconds\n", lib_time))

# Total
total_time <- as.numeric(difftime(Sys.time(), total_start, units = "secs"))
cat(sprintf("  TOTAL LAUNCH TIME: %.3f seconds\n\n", total_time))

# Test 4: Check what's actually in the environment
cat("Test 4: Environment check...\n")
cat(sprintf("  TURAS_SKIP_RENV = %s\n", Sys.getenv("TURAS_SKIP_RENV")))
cat(sprintf("  TURAS_ROOT = %s\n", Sys.getenv("TURAS_ROOT")))
cat(sprintf("  Working directory = %s\n", getwd()))

# Check if renv is active in current session
if ("renv" %in% loadedNamespaces()) {
  cat("  WARNING: renv is loaded in this session\n")
} else {
  cat("  OK: renv is NOT loaded\n")
}

cat("\n=== Diagnostic Complete ===\n\n")
