# ==============================================================================
# TURAS Test Runner
# ==============================================================================
# This file runs all tests in tests/testthat/
#
# USAGE:
#   From R console in Turas root:
#   testthat::test_dir("tests/testthat")
#
# Or source this file:
#   source("tests/testthat.R")
# ==============================================================================

library(testthat)

# Set working directory to Turas root (if not already there)
if (basename(getwd()) != "Turas") {
  if (file.exists("tests/testthat.R")) {
    # Already in Turas root
  } else if (file.exists("../tests/testthat.R")) {
    setwd("..")
  } else {
    stop("Please run from Turas root directory")
  }
}

cat("\n")
cat("================================================================================\n")
cat("TURAS ANALYTICS PLATFORM - TEST SUITE\n")
cat("================================================================================\n")
cat("Working Directory:", getwd(), "\n")
cat("Test Directory: tests/testthat/\n")
cat("================================================================================\n\n")

# Run all tests
test_results <- test_dir(
  "tests/testthat",
  reporter = "progress",
  stop_on_failure = FALSE
)

cat("\n")
cat("================================================================================\n")
cat("TEST SUMMARY\n")
cat("================================================================================\n")
print(test_results)
cat("================================================================================\n")
