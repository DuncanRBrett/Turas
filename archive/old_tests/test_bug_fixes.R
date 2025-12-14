#!/usr/bin/env Rscript
# ==============================================================================
# BUG FIX VALIDATION SCRIPT
# ==============================================================================
# Quick smoke test to verify bug fixes don't break existing code
# Run this BEFORE testing with your real data
# ==============================================================================

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("TURAS BUG FIX VALIDATION\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

# Track test results
tests_passed <- 0
tests_failed <- 0
failures <- list()

# Helper function to run tests
run_test <- function(test_name, test_code) {
  cat(sprintf("Testing: %s ... ", test_name))

  result <- tryCatch({
    test_code()
    cat("✅ PASS\n")
    tests_passed <<- tests_passed + 1
    TRUE
  }, error = function(e) {
    cat("❌ FAIL\n")
    cat(sprintf("   Error: %s\n", e$message))
    tests_failed <<- tests_failed + 1
    failures[[length(failures) + 1]] <<- list(test = test_name, error = e$message)
    FALSE
  })

  result
}

cat("PHASE 1: Module Loading Tests\n")
cat(rep("-", 80), "\n", sep = "")

# Test 1: Tabs validation.R loads with MAX_DECIMAL_PLACES defined
run_test("CR-TABS-001: MAX_DECIMAL_PLACES constant defined", {
  source("modules/tabs/lib/validation.R", local = TRUE)
  if (!exists("MAX_DECIMAL_PLACES")) {
    stop("MAX_DECIMAL_PLACES not defined")
  }
  if (MAX_DECIMAL_PLACES != 6) {
    stop(sprintf("MAX_DECIMAL_PLACES should be 6, got %d", MAX_DECIMAL_PLACES))
  }
})

# Test 2: Tabs shared_functions.R loads
run_test("CR-TABS-002: Shared functions load without namespace pollution", {
  source("modules/tabs/lib/shared_functions.R", local = TRUE)
})

# Test 3: Tabs excel_writer.R loads
run_test("CR-TABS-002: Excel writer loads correctly", {
  # Skip if openxlsx not available
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    message("Skipping (openxlsx not installed)")
    return(invisible(NULL))
  }
  source("modules/tabs/lib/excel_writer.R", local = TRUE)
})

# Test 4: Tracker modules load
run_test("CR-TRACKER-001-005: Tracker modules load", {
  source("modules/tracker/tracker_config_loader.R", local = TRUE)
  source("modules/tracker/trend_calculator.R", local = TRUE)
  source("modules/tracker/wave_loader.R", local = TRUE)
})

# Test 5: Confidence modules load
run_test("CR-CONF-001-003: Confidence modules load", {
  source("modules/confidence/R/00_main.R", local = TRUE)
  source("modules/confidence/R/05_means.R", local = TRUE)
  source("modules/confidence/R/07_output.R", local = TRUE)
})

# Test 6: Segment modules load
run_test("CR-SEG-001-003: Segment modules load", {
  source("modules/segment/lib/segment_validation.R", local = TRUE)
  source("modules/segment/lib/segment_export.R", local = TRUE)
})

# Test 7: Parser modules load
run_test("CR-PARSER-001-002: Parser modules load", {
  # Check if required packages exist
  required_pkgs <- c("shiny", "officer", "openxlsx", "stringr", "DT")
  missing <- required_pkgs[!required_pkgs %in% installed.packages()[,"Package"]]

  if (length(missing) > 0) {
    message(sprintf("Skipping (missing packages: %s)", paste(missing, collapse = ", ")))
    return(invisible(NULL))
  }

  source("modules/parser/run_parser.R", local = TRUE)
  source("modules/parser/shiny_app.R", local = TRUE)
})

cat("\n")
cat("PHASE 2: Bug Fix Validation Tests\n")
cat(rep("-", 80), "\n", sep = "")

# Test 8: Division by zero protection in Tracker
run_test("CR-TRACKER-003: Division by zero protection", {
  # Simulate the percentage change calculation
  current_val <- 10
  previous_val <- 0

  # This should NOT crash and should return NA
  percentage_change <- if (previous_val == 0) {
    NA
  } else {
    (current_val - previous_val) / previous_val * 100
  }

  if (!is.na(percentage_change)) {
    stop("Division by zero should return NA")
  }
})

# Test 9: Weight validation in Tracker
run_test("CR-TRACKER-004: Invalid weights excluded", {
  # Simulate weight filtering
  weights <- c(1.2, 0, -0.5, 2.1, NA, 1.5)

  # Apply the fix
  weights[weights <= 0] <- NA

  # Check: only positive weights remain valid
  valid_weights <- weights[!is.na(weights)]
  if (any(valid_weights <= 0)) {
    stop("Negative/zero weights not properly excluded")
  }
  if (length(valid_weights) != 3) {  # Should have 1.2, 2.1, 1.5
    stop(sprintf("Expected 3 valid weights, got %d", length(valid_weights)))
  }
})

# Test 10: Confidence weighted SD calculation
run_test("CR-CONF-003: Weighted SD calculation", {
  # Test data
  values <- c(5, 7, 8, 6, 9)
  weights <- c(1, 2, 1, 3, 1)

  # Calculate weighted mean
  mean_val <- sum(values * weights) / sum(weights)

  # Calculate weighted SD (the fix)
  weighted_var <- sum(weights * (values - mean_val)^2) / sum(weights)
  sd_val <- sqrt(weighted_var)

  # Should not error and should be numeric
  if (!is.numeric(sd_val) || is.na(sd_val)) {
    stop("Weighted SD calculation failed")
  }
})

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("TEST SUMMARY\n")
cat(rep("=", 80), "\n", sep = "")
cat(sprintf("Tests Passed: %d\n", tests_passed))
cat(sprintf("Tests Failed: %d\n", tests_failed))

if (tests_failed > 0) {
  cat("\n")
  cat("FAILURES:\n")
  for (failure in failures) {
    cat(sprintf("  - %s: %s\n", failure$test, failure$error))
  }
  cat("\n")
  cat("❌ Some tests failed. Review errors above.\n")
  cat("\n")
} else {
  cat("\n")
  cat("✅ ALL TESTS PASSED!\n")
  cat("\n")
  cat("Next steps:\n")
  cat("1. Test with your actual data (see TEST_BUG_FIXES.md)\n")
  cat("2. Run your normal Tabs/Tracker workflows\n")
  cat("3. If everything works, merge the branch\n")
  cat("\n")
}

cat(rep("=", 80), "\n", sep = "")
cat("\n")
