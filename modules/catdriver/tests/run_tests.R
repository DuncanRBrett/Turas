#!/usr/bin/env Rscript
# ==============================================================================
# CATDRIVER TEST RUNNER
# ==============================================================================
#
# Runs the complete test suite for the categorical key driver module.
#
# Usage: Rscript run_tests.R [--verbose]
#
# ==============================================================================

# Parse arguments
args <- commandArgs(trailingOnly = TRUE)
verbose <- "--verbose" %in% args || "-v" %in% args

# Get script directory
script_dir <- tryCatch({
  dirname(sys.frame(1)$ofile)
}, error = function(e) {
  getwd()
})

if (is.null(script_dir) || script_dir == "") {
  script_dir <- getwd()
}

# Set module root
module_root <- dirname(script_dir)
if (basename(module_root) != "catdriver") {
  # Maybe we're already in module root
  if (basename(getwd()) == "catdriver") {
    module_root <- getwd()
  } else if (file.exists("R/00_main.R")) {
    module_root <- getwd()
  } else {
    stop("Cannot determine module root. Run from catdriver directory.")
  }
}

cat("==============================================================================\n")
cat("  CATDRIVER TEST SUITE\n")
cat("==============================================================================\n\n")
cat("Module root:", module_root, "\n\n")

# Check required packages
required_packages <- c("testthat", "openxlsx")
optional_packages <- c("ordinal", "MASS", "brglm2", "nnet")

cat("Checking required packages...\n")
missing_required <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
if (length(missing_required) > 0) {
  stop("Missing required packages: ", paste(missing_required, collapse = ", "),
       "\n\nInstall with: install.packages(c('", paste(missing_required, collapse = "', '"), "'))")
}
cat("  Required packages: OK\n")

cat("Checking optional packages...\n")
missing_optional <- optional_packages[!sapply(optional_packages, requireNamespace, quietly = TRUE)]
if (length(missing_optional) > 0) {
  cat("  Missing optional packages:", paste(missing_optional, collapse = ", "), "\n")
  cat("  Some tests may be skipped\n")
} else {
  cat("  Optional packages: OK\n")
}
cat("\n")

# Source shared utilities first (required for TRS refusal functions)
cat("Loading shared utilities...\n")
# modules/catdriver -> modules -> Turas -> modules/shared/lib
turas_root <- dirname(dirname(module_root))
shared_lib_path <- file.path(turas_root, "modules", "shared", "lib")
if (dir.exists(shared_lib_path)) {
  shared_files <- list.files(shared_lib_path, pattern = "\\.R$", full.names = TRUE)
  for (f in shared_files) {
    tryCatch({
      source(f)
      if (verbose) cat("  Loaded:", basename(f), "\n")
    }, error = function(e) {
      cat("  WARNING loading", basename(f), ":", e$message, "\n")
    })
  }
  cat("  Shared utilities loaded\n")
} else {
  cat("  WARNING: Shared utilities not found at", shared_lib_path, "\n")
}
cat("\n")

# Source module files
cat("Loading module...\n")
setwd(module_root)

r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
r_files <- r_files[order(r_files)]  # Ensure loading order

for (f in r_files) {
  tryCatch({
    source(f)
    if (verbose) cat("  Loaded:", basename(f), "\n")
  }, error = function(e) {
    cat("  ERROR loading", basename(f), ":", e$message, "\n")
  })
}
cat("  Module loaded\n\n")

# Run tests
cat("Running tests...\n\n")

library(testthat)

# Set reporter based on verbosity
reporter <- if (verbose) "progress" else "summary"

test_results <- tryCatch({
  test_file(file.path(module_root, "tests", "test_catdriver.R"),
            reporter = reporter)
}, error = function(e) {
  cat("\nERROR running tests:", e$message, "\n")
  NULL
})

# Summary
cat("\n")
cat("==============================================================================\n")

if (is.null(test_results)) {
  cat("  TEST RUN FAILED\n")
  cat("==============================================================================\n")
  quit(status = 1)
}

# Extract summary
test_df <- as.data.frame(test_results)
total_tests <- sum(test_df$nb)
passed_tests <- sum(test_df$nb) - sum(test_df$failed) - sum(test_df$skipped)
failed_tests <- sum(test_df$failed)
skipped_tests <- sum(test_df$skipped)

if (failed_tests > 0) {
  cat("  TESTS FAILED\n")
  cat("==============================================================================\n")
  cat(sprintf("\n  Total: %d | Passed: %d | Failed: %d | Skipped: %d\n\n",
              total_tests, passed_tests, failed_tests, skipped_tests))
  quit(status = 1)
} else {
  cat("  ALL TESTS PASSED\n")
  cat("==============================================================================\n")
  cat(sprintf("\n  Total: %d | Passed: %d | Failed: %d | Skipped: %d\n\n",
              total_tests, passed_tests, failed_tests, skipped_tests))
  quit(status = 0)
}
