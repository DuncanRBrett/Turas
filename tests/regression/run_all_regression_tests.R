#!/usr/bin/env Rscript
# ==============================================================================
# TURAS MASTER REGRESSION TEST RUNNER
# ==============================================================================
# Runs regression tests for all TURAS modules
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

# Define available test modules
test_modules <- list(
  list(name = "Tabs", file = "test_regression_tabs_mock.R", status = "implemented"),
  list(name = "Confidence", file = "test_regression_confidence_mock.R", status = "implemented"),
  list(name = "KeyDriver", file = "test_regression_keydriver_mock.R", status = "implemented"),
  list(name = "AlchemerParser", file = "test_regression_alchemerparser_mock.R", status = "implemented"),
  list(name = "Segment", file = "test_regression_segment_mock.R", status = "implemented"),
  list(name = "Conjoint", file = "test_regression_conjoint_mock.R", status = "implemented"),
  list(name = "Pricing", file = "test_regression_pricing_mock.R", status = "implemented"),
  list(name = "Tracker", file = "test_regression_tracker_mock.R", status = "implemented")
)

# Track results
results <- list()
total_passed <- 0
total_failed <- 0
total_skipped <- 0

# Run each test
for (i in seq_along(test_modules)) {
  module <- test_modules[[i]]

  cat(sprintf("[%d/%d] %-20s", i, length(test_modules), paste0(module$name, "...")))

  test_file <- file.path("tests/regression", module$file)

  if (module$status == "planned") {
    cat(" ⏭️  PLANNED (not implemented yet)\n")
    total_skipped <- total_skipped + 1
    next
  }

  if (!file.exists(test_file)) {
    cat(" ❌ TEST FILE NOT FOUND\n")
    total_failed <- total_failed + 1
    next
  }

  # Run test
  result <- tryCatch({
    # Capture test output
    test_results <- test_file(test_file, reporter = "silent")

    # Count expectations manually from the result object
    n_failed <- 0
    n_passed <- 0

    # testthat results are stored in a list structure
    if (is.list(test_results) && length(test_results) > 0) {
      for (test_result in test_results) {
        if (inherits(test_result, "expectation")) {
          if (inherits(test_result, "expectation_success")) {
            n_passed <- n_passed + 1
          } else if (inherits(test_result, "expectation_failure")) {
            n_failed <- n_failed + 1
          }
        }
      }
    }

    list(passed = n_passed, failed = n_failed)
  }, error = function(e) {
    list(error = e$message)
  })

  # Check results
  if (!is.null(result$error)) {
    cat(" ❌ ERROR:", result$error, "\n")
    total_failed <- total_failed + 1
  } else {
    n_failed <- result$failed
    n_passed <- result$passed
    n_total <- n_failed + n_passed

    if (n_failed == 0 && n_total > 0) {
      cat(sprintf(" ✅ PASS (%d/%d checks)\n", n_passed, n_total))
      total_passed <- total_passed + 1
    } else if (n_total == 0) {
      cat(" ❌ NO TESTS RUN\n")
      total_failed <- total_failed + 1
    } else {
      cat(sprintf(" ❌ FAIL (%d/%d checks failed)\n", n_failed, n_total))
      total_failed <- total_failed + 1
    }
  }

  results[[module$name]] <- result
}

# Summary
cat("\n")
cat("================================================================================\n")

implemented <- sum(sapply(test_modules, function(m) m$status == "implemented"))
planned <- sum(sapply(test_modules, function(m) m$status == "planned"))

if (total_failed == 0 && total_passed == implemented) {
  cat("✅ ALL IMPLEMENTED MODULES PASSED - TURAS IS STABLE\n")
} else if (total_failed > 0) {
  cat("❌ SOME TESTS FAILED - REVIEW REQUIRED\n")
} else {
  cat("⚠️  PARTIAL COVERAGE\n")
}

cat("================================================================================\n\n")

cat(sprintf("Modules tested:  %d/%d\n", implemented, length(test_modules)))
cat(sprintf("  ✅ Passed:     %d\n", total_passed))
cat(sprintf("  ❌ Failed:     %d\n", total_failed))
cat(sprintf("  ⏭️  Planned:    %d\n", total_skipped))

cat("\n")
cat("Next steps:\n")
if (planned > 0) {
  cat(sprintf("  • Implement %d remaining module tests\n", planned))
}
if (total_failed > 0) {
  cat("  • Fix failing tests\n")
}
if (total_passed == implemented && planned == 0) {
  cat("  • All done! Complete regression test coverage achieved.\n")
}

cat("\n")

# Exit code
if (total_failed > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
