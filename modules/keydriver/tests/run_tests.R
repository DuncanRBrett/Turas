# ==============================================================================
# KEYDRIVER MODULE - TEST RUNNER
# ==============================================================================
#
# Run all keydriver module tests using testthat.
#
# Usage:
#   source("modules/keydriver/tests/run_tests.R")
#
# Or from project root:
#   testthat::test_dir("modules/keydriver/tests")
#
# ==============================================================================

# Determine paths
test_dir <- if (exists("script_dir_override", envir = globalenv())) {
  file.path(get("script_dir_override", envir = globalenv()), "tests")
} else {
  dirname(sys.frame(1)$ofile %||% ".")
}

module_dir <- dirname(test_dir)
project_root <- file.path(module_dir, "..", "..")

# Source test data generators
source(file.path(test_dir, "fixtures", "generate_test_data.R"))

# Source module files
source(file.path(module_dir, "R", "00_guard.R"))

# Run tests
if (requireNamespace("testthat", quietly = TRUE)) {
  cat("\n")
  cat(paste(rep("=", 60), collapse = ""), "\n")
  cat("  KEYDRIVER MODULE - TEST SUITE\n")
  cat(paste(rep("=", 60), collapse = ""), "\n\n")

  results <- testthat::test_dir(
    file.path(test_dir, "testthat"),
    reporter = testthat::SummaryReporter$new()
  )

  cat("\n")
  cat(paste(rep("=", 60), collapse = ""), "\n\n")
} else {
  cat("[ERROR] testthat package is required to run tests.\n")
  cat("Install with: install.packages('testthat')\n")
}
