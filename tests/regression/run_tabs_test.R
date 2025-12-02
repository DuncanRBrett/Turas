#!/usr/bin/env Rscript
# ==============================================================================
# RUN TABS REGRESSION TEST
# ==============================================================================
# Quick runner for Tabs regression test
# Usage: Rscript tests/regression/run_tabs_test.R
# ==============================================================================

# Check if testthat is installed
if (!requireNamespace("testthat", quietly = TRUE)) {
  stop("Package 'testthat' required. Install with: install.packages('testthat')")
}

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' required. Install with: install.packages('jsonlite')")
}

library(testthat)

cat("\n")
cat("================================================================================\n")
cat("TURAS REGRESSION TEST: TABS MODULE\n")
cat("================================================================================\n\n")

# Check working directory
if (!all(dir.exists(c("tests", "examples", "modules")))) {
  stop("Please run from TURAS root directory")
}

# Run test
cat("Running test...\n\n")

result <- test_file(
  "tests/regression/test_regression_tabs_mock.R",
  reporter = "summary"
)

cat("\n")
cat("================================================================================\n")

if (all(result$passed)) {
  cat("✅ TABS REGRESSION TEST PASSED\n")
  cat("================================================================================\n")
  quit(status = 0)
} else {
  cat("❌ TABS REGRESSION TEST FAILED\n")
  cat("================================================================================\n")
  cat("\nReview failures above.\n\n")
  quit(status = 1)
}
