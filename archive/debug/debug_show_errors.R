#!/usr/bin/env Rscript
# Debug script to show actual test errors

library(testthat)

# Source helpers globally
source("tests/regression/helpers/assertion_helpers.R")
source("tests/regression/helpers/path_helpers.R")

# Run one test file
test_file <- "tests/regression/test_regression_tabs_mock.R"
cat("Running:", test_file, "\n\n")

result <- test_file(test_file, reporter = "silent")

# Show detailed error information
cat("Number of test contexts:", length(result), "\n\n")

for (i in seq_along(result)) {
  test_context <- result[[i]]
  cat("Context", i, ":", test_context$context, "\n")
  cat("Number of results:", length(test_context$results), "\n")

  for (j in seq_along(test_context$results)) {
    expectation <- test_context$results[[j]]
    cat("\n  Expectation", j, ":\n")
    cat("    Class:", class(expectation), "\n")

    if (inherits(expectation, "expectation_error") || inherits(expectation, "expectation_failure")) {
      cat("    Message:", expectation$message, "\n")
      if (!is.null(expectation$trace)) {
        cat("    Trace available: Yes\n")
      }
    } else if (inherits(expectation, "expectation_success")) {
      cat("    Status: SUCCESS\n")
    }
  }
}
