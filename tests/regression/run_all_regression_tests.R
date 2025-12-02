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
  list(name = "Tracker", file = "test_regression_tracker_mock.R", status = "planned"),
  list(name = "Segment", file = "test_regression_segment_mock.R", status = "planned"),
  list(name = "Conjoint", file = "test_regression_conjoint_mock.R", status = "planned"),
  list(name = "Pricing", file = "test_regression_pricing_mock.R", status = "planned"),
  list(name = "AlchemerParser", file = "test_regression_alchemerparser_mock.R", status = "planned")
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
    test_file(test_file, reporter = "silent")
  }, error = function(e) {
    list(passed = FALSE, failed = 1, error = e$message)
  })

  # Check results
  if (!is.null(result$error)) {
    cat(" ❌ ERROR:", result$error, "\n")
    total_failed <- total_failed + 1
  } else if (length(result$results) > 0 && all(sapply(result$results, function(r) r$passed))) {
    n_checks <- length(result$results)
    cat(sprintf(" ✅ PASS (%d/%d checks)\n", n_checks, n_checks))
    total_passed <- total_passed + 1
  } else {
    n_failed <- sum(!sapply(result$results, function(r) r$passed))
    n_total <- length(result$results)
    cat(sprintf(" ❌ FAIL (%d/%d checks failed)\n", n_failed, n_total))
    total_failed <- total_failed + 1
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
