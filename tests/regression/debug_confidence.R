#!/usr/bin/env Rscript
# Debug confidence test

library(testthat)

# Source helpers globally
source("tests/regression/helpers/assertion_helpers.R")
source("tests/regression/helpers/path_helpers.R")

# Run confidence test
test_file <- "tests/regression/test_regression_confidence_mock.R"
cat("Running:", test_file, "\n\n")

result <- test_file(test_file, reporter = "silent")

# Show error
cat("Number of results:", length(result[[1]]$results), "\n")
if (length(result[[1]]$results) > 0) {
  exp <- result[[1]]$results[[1]]
  cat("Error class:", class(exp), "\n")
  cat("Error message:", exp$message, "\n")
}
