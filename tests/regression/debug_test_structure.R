#!/usr/bin/env Rscript
# Debug script to understand test_file() return structure

library(testthat)

# Run one test file and examine structure
test_file <- "tests/regression/test_regression_tabs_mock.R"

cat("Running test file:", test_file, "\n\n")

result <- test_file(test_file, reporter = "silent")

cat("Class of result:", class(result), "\n")
cat("Length of result:", length(result), "\n")
cat("Names of result:", names(result), "\n")
cat("Structure:\n")
str(result, max.level = 2)

cat("\n\nFirst element class:", class(result[[1]]), "\n")
cat("First element structure:\n")
str(result[[1]], max.level = 3)
