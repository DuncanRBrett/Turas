#!/usr/bin/env Rscript
# ==============================================================================
# TURAS MASTER REGRESSION TEST RUNNER
# ==============================================================================
# Runs regression tests for all TURAS modules and shared utilities
# Usage: Rscript tests/regression/run_all_regression_tests.R
# ==============================================================================

# Check required packages
if (!requireNamespace("testthat", quietly = TRUE)) {
  stop("Package 'testthat' required. Install: install.packages('testthat')")
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' required. Install: install.packages('jsonlite')")
}

library(testthat)

cat("\n")
cat("================================================================================\n")
cat("TURAS COMPLETE REGRESSION TEST SUITE\n")
cat("================================================================================\n\n")

# Check working directory
if (!all(dir.exists(c("tests", "examples", "modules")))) {
  stop("Please run from TURAS root directory")
}

# ==============================================================================
# SECTION 1: MODULE REGRESSION TESTS
# ==============================================================================

cat("--- MODULE REGRESSION TESTS ---\n\n")

# Define available test modules
test_modules <- list(
  list(name = "Tabs", file = "test_regression_tabs_mock.R", status = "implemented"),
  list(name = "Confidence", file = "test_regression_confidence_mock.R", status = "implemented"),
  list(name = "KeyDriver", file = "test_regression_keydriver_mock.R", status = "implemented"),
  list(name = "AlchemerParser", file = "test_regression_alchemerparser_mock.R", status = "implemented"),
  list(name = "Segment", file = "test_regression_segment_mock.R", status = "implemented"),
  list(name = "Conjoint", file = "test_regression_conjoint_mock.R", status = "implemented"),
  list(name = "Pricing", file = "test_regression_pricing_mock.R", status = "implemented"),
  list(name = "Tracker", file = "test_regression_tracker_mock.R", status = "implemented"),
  list(name = "MaxDiff", file = "test_regression_maxdiff_mock.R", status = "implemented"),
  list(name = "Weighting", file = "test_regression_weighting_mock.R", status = "implemented")
)

# Define shared utility tests (from tests/testthat/)
shared_tests <- list(
  list(name = "Shared Config", file = "test_shared_config.R"),
  list(name = "Shared Formatting", file = "test_shared_formatting.R"),
  list(name = "Shared Weights", file = "test_shared_weights.R"),
  list(name = "Shared Validation", file = "test_shared_validation.R"),
  list(name = "Module Smoke Tests", file = "test_module_smoke.R")
)

# Helper function to run a test file and count results
run_test_file <- function(test_file, source_helpers = TRUE) {
  result <- tryCatch({
    # Source helpers before running test (make available globally)
    if (source_helpers) {
      if (file.exists("tests/regression/helpers/assertion_helpers.R")) {
        source("tests/regression/helpers/assertion_helpers.R")
      }
      if (file.exists("tests/regression/helpers/path_helpers.R")) {
        source("tests/regression/helpers/path_helpers.R")
      }
    }

    # Capture test output
    test_results <- test_file(test_file, reporter = "silent")

    # Count expectations from nested structure
    n_failed <- 0
    n_passed <- 0

    # testthat results: result[[1]]$results contains the expectations
    if (is.list(test_results) && length(test_results) > 0) {
      for (test in test_results) {
        if (is.list(test$results)) {
          for (expectation in test$results) {
            if (inherits(expectation, "expectation_success")) {
              n_passed <- n_passed + 1
            } else if (inherits(expectation, "expectation_failure")) {
              n_failed <- n_failed + 1
            } else if (inherits(expectation, "expectation_error")) {
              n_failed <- n_failed + 1
            }
          }
        }
      }
    }

    list(passed = n_passed, failed = n_failed)
  }, error = function(e) {
    list(error = e$message)
  })

  return(result)
}

# Track results
results <- list()
module_passed <- 0
module_failed <- 0
module_skipped <- 0

# Run each module test
for (i in seq_along(test_modules)) {
  module <- test_modules[[i]]

  cat(sprintf("[%d/%d] %-20s", i, length(test_modules), paste0(module$name, "...")))

  test_file_path <- file.path("tests/regression", module$file)

  if (module$status == "planned") {
    cat(" [SKIP] PLANNED (not implemented yet)\n")
    module_skipped <- module_skipped + 1
    next
  }

  if (!file.exists(test_file_path)) {
    cat(" [FAIL] TEST FILE NOT FOUND\n")
    module_failed <- module_failed + 1
    next
  }

  result <- run_test_file(test_file_path, source_helpers = TRUE)

  # Check results
  if (!is.null(result$error)) {
    cat(" [FAIL] ERROR:", result$error, "\n")
    module_failed <- module_failed + 1
  } else {
    n_failed <- result$failed
    n_passed <- result$passed
    n_total <- n_failed + n_passed

    if (n_failed == 0 && n_total > 0) {
      cat(sprintf(" [PASS] (%d/%d checks)\n", n_passed, n_total))
      module_passed <- module_passed + 1
    } else if (n_total == 0) {
      cat(" [FAIL] NO TESTS RUN\n")
      module_failed <- module_failed + 1
    } else {
      cat(sprintf(" [FAIL] (%d/%d checks failed)\n", n_failed, n_total))
      module_failed <- module_failed + 1
    }
  }

  results[[module$name]] <- result
}

# ==============================================================================
# SECTION 2: SHARED UTILITY TESTS
# ==============================================================================

cat("\n--- SHARED UTILITY TESTS ---\n\n")

shared_passed <- 0
shared_failed <- 0

for (i in seq_along(shared_tests)) {
  test <- shared_tests[[i]]

  cat(sprintf("[%d/%d] %-20s", i, length(shared_tests), paste0(test$name, "...")))

  test_file_path <- file.path("tests/testthat", test$file)

  if (!file.exists(test_file_path)) {
    cat(" [FAIL] TEST FILE NOT FOUND\n")
    shared_failed <- shared_failed + 1
    next
  }

  result <- run_test_file(test_file_path, source_helpers = FALSE)

  # Check results
  if (!is.null(result$error)) {
    cat(" [FAIL] ERROR:", result$error, "\n")
    shared_failed <- shared_failed + 1
  } else {
    n_failed <- result$failed
    n_passed <- result$passed
    n_total <- n_failed + n_passed

    if (n_failed == 0 && n_total > 0) {
      cat(sprintf(" [PASS] (%d/%d checks)\n", n_passed, n_total))
      shared_passed <- shared_passed + 1
    } else if (n_total == 0) {
      cat(" [FAIL] NO TESTS RUN\n")
      shared_failed <- shared_failed + 1
    } else {
      cat(sprintf(" [FAIL] (%d/%d checks failed)\n", n_failed, n_total))
      shared_failed <- shared_failed + 1
    }
  }

  results[[test$name]] <- result
}

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n")
cat("================================================================================\n")

total_passed <- module_passed + shared_passed
total_failed <- module_failed + shared_failed
total_tests <- length(test_modules) + length(shared_tests)

implemented <- sum(sapply(test_modules, function(m) m$status == "implemented"))
planned <- sum(sapply(test_modules, function(m) m$status == "planned"))

if (total_failed == 0) {
  cat("ALL TESTS PASSED - TURAS IS STABLE\n")
} else {
  cat("SOME TESTS FAILED - REVIEW REQUIRED\n")
}

cat("================================================================================\n\n")

cat("MODULE TESTS:\n")
cat(sprintf("  Modules tested:  %d/%d\n", implemented, length(test_modules)))
cat(sprintf("    Passed:        %d\n", module_passed))
cat(sprintf("    Failed:        %d\n", module_failed))
if (module_skipped > 0) {
  cat(sprintf("    Planned:       %d\n", module_skipped))
}

cat("\nSHARED UTILITY TESTS:\n")
cat(sprintf("  Test suites:     %d\n", length(shared_tests)))
cat(sprintf("    Passed:        %d\n", shared_passed))
cat(sprintf("    Failed:        %d\n", shared_failed))

cat("\nOVERALL:\n")
cat(sprintf("  Total tests:     %d\n", total_tests))
cat(sprintf("  Total passed:    %d\n", total_passed))
cat(sprintf("  Total failed:    %d\n", total_failed))

cat("\n")

# Exit code (only quit if running non-interactively, e.g., via Rscript)
if (!interactive()) {
  if (total_failed > 0) {
    quit(save = "no", status = 1)
  } else {
    quit(save = "no", status = 0)
  }
}
