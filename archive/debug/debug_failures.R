#!/usr/bin/env Rscript
# Show detailed failures for KeyDriver and Segment

library(testthat)

# Source helpers
source("tests/regression/helpers/assertion_helpers.R")
source("tests/regression/helpers/path_helpers.R")

cat("================================================================================\n")
cat("KEYDRIVER FAILURES\n")
cat("================================================================================\n")
test_file("tests/regression/test_regression_keydriver_mock.R", reporter = "check")

cat("\n\n")
cat("================================================================================\n")
cat("SEGMENT FAILURES\n")
cat("================================================================================\n")
test_file("tests/regression/test_regression_segment_mock.R", reporter = "check")
