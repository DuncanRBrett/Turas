#!/usr/bin/env Rscript
# ==============================================================================
# COMPREHENSIVE KEY DRIVER MODULE REGRESSION TEST SUITE
# ==============================================================================
#
# Tests all key driver modules systematically
# Ensures no silent failures
#
# ==============================================================================

library(testthat)

cat("\n")
cat("================================================================================\n")
cat("  COMPREHENSIVE KEY DRIVER MODULE TEST SUITE\n")
cat("================================================================================\n")
cat("\n")

# Track all results
all_results <- list()
total_tests <- 0
total_passed <- 0
total_failed <- 0
total_skipped <- 0

# Helper to run and track tests
run_test_file <- function(test_name, test_file) {
  cat(sprintf("\n--- Testing: %s ---\n", test_name))
  cat(sprintf("File: %s\n\n", basename(test_file)))

  if (!file.exists(test_file)) {
    cat(sprintf("⚠️  SKIP: Test file not found: %s\n", test_file))
    return(list(status = "SKIP", reason = "File not found"))
  }

  result <- tryCatch({
    test_results <- test_file(test_file, reporter = "minimal")
    test_df <- as.data.frame(test_results)

    n_tests <- sum(test_df$nb)
    n_failed <- sum(test_df$failed)
    n_skipped <- sum(test_df$skipped)
    n_passed <- n_tests - n_failed - n_skipped

    if (n_failed > 0) {
      cat(sprintf("❌ FAILED: %d/%d tests failed\n", n_failed, n_tests))
      return(list(
        status = "FAIL",
        total = n_tests,
        passed = n_passed,
        failed = n_failed,
        skipped = n_skipped,
        results = test_results
      ))
    } else if (n_tests == 0) {
      cat(sprintf("⚠️  WARNING: No tests found\n"))
      return(list(status = "WARN", reason = "No tests found"))
    } else {
      cat(sprintf("✅ PASSED: %d/%d tests passed\n", n_passed, n_tests))
      return(list(
        status = "PASS",
        total = n_tests,
        passed = n_passed,
        failed = n_failed,
        skipped = n_skipped
      ))
    }
  }, error = function(e) {
    cat(sprintf("❌ ERROR: %s\n", e$message))
    return(list(status = "ERROR", message = e$message))
  })

  result
}

# ==============================================================================
# TEST 1: CATDRIVER MODULE
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("  1. CATEGORICAL KEY DRIVER MODULE\n")
cat("================================================================================\n")

# Module tests
result <- run_test_file(
  "CatDriver Module Tests",
  "modules/catdriver/tests/test_catdriver.R"
)
all_results$catdriver_module <- result

# Regression tests
result <- run_test_file(
  "CatDriver Regression Tests",
  "tests/regression/test_regression_catdriver_mock.R"
)
all_results$catdriver_regression <- result

# ==============================================================================
# TEST 2: KEYDRIVER MODULE
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("  2. CONTINUOUS KEY DRIVER MODULE\n")
cat("================================================================================\n")

# Check if module tests exist
if (dir.exists("modules/keydriver/tests")) {
  keydriver_tests <- list.files("modules/keydriver/tests",
                                pattern = "^test_.*\\.R$",
                                full.names = TRUE)
  if (length(keydriver_tests) > 0) {
    for (test_file in keydriver_tests) {
      result <- run_test_file(
        paste("KeyDriver", basename(test_file)),
        test_file
      )
      all_results[[paste0("keydriver_", basename(test_file))]] <- result
    }
  } else {
    cat("⚠️  No module-level tests found\n")
  }
} else {
  cat("⚠️  No tests directory found\n")
}

# Regression tests
result <- run_test_file(
  "KeyDriver Mock Tests",
  "tests/regression/test_regression_keydriver_mock.R"
)
all_results$keydriver_mock <- result

result <- run_test_file(
  "KeyDriver Enhancement Tests",
  "tests/regression/test_regression_keydriver_enhancements.R"
)
all_results$keydriver_enhancements <- result

# ==============================================================================
# TEST 3: TRACKER MODULE
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("  3. TRACKER MODULE\n")
cat("================================================================================\n")

# Check for tracker tests
tracker_test_files <- c(
  "tests/regression/test_regression_tracker_mock.R",
  "tests/regression/test_regression_tracker_dashboard.R"
)

for (test_file in tracker_test_files) {
  if (file.exists(test_file)) {
    result <- run_test_file(
      paste("Tracker", basename(test_file)),
      test_file
    )
    all_results[[paste0("tracker_", basename(test_file))]] <- result
  }
}

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("  TEST SUMMARY\n")
cat("================================================================================\n")
cat("\n")

# Calculate totals
for (name in names(all_results)) {
  result <- all_results[[name]]
  if (result$status == "PASS") {
    total_tests <- total_tests + result$total
    total_passed <- total_passed + result$passed
    total_failed <- total_failed + result$failed
    total_skipped <- total_skipped + result$skipped
  } else if (result$status == "FAIL") {
    total_tests <- total_tests + result$total
    total_passed <- total_passed + result$passed
    total_failed <- total_failed + result$failed
    total_skipped <- total_skipped + result$skipped
  }
}

# Print summary
cat(sprintf("Total Tests:   %d\n", total_tests))
cat(sprintf("Passed:        %d (%.1f%%)\n", total_passed,
            if(total_tests > 0) 100*total_passed/total_tests else 0))
cat(sprintf("Failed:        %d\n", total_failed))
cat(sprintf("Skipped:       %d\n", total_skipped))
cat("\n")

# List failed tests
failed_tests <- names(all_results)[sapply(all_results, function(x) x$status == "FAIL")]
error_tests <- names(all_results)[sapply(all_results, function(x) x$status == "ERROR")]

if (length(failed_tests) > 0) {
  cat("FAILED TEST SUITES:\n")
  for (name in failed_tests) {
    cat(sprintf("  ❌ %s\n", name))
  }
  cat("\n")
}

if (length(error_tests) > 0) {
  cat("ERROR TEST SUITES:\n")
  for (name in error_tests) {
    cat(sprintf("  ❌ %s: %s\n", name, all_results[[name]]$message))
  }
  cat("\n")
}

# Final result
cat("================================================================================\n")
if (total_failed > 0 || length(error_tests) > 0) {
  cat("  ❌ TESTS FAILED\n")
  cat("================================================================================\n")
  quit(status = 1)
} else {
  cat("  ✅ ALL TESTS PASSED\n")
  cat("================================================================================\n")
  quit(status = 0)
}
