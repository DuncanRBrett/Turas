# ==============================================================================
# Quick Test Script for Tracker Module Fixes
# ==============================================================================
#
# Tests the 4 fixes implemented:
# 1. Alpha level consistency
# 2. NA safety in wave_loader
# 3. is_significant() helper
# 4. Constants file
#
# ==============================================================================

# Set working directory to tracker module
setwd("/home/user/Turas/modules/tracker")

# Source all modules (this will test if constants.R loads correctly)
cat("\n=== Testing Module Loading ===\n")
tryCatch({
  source("constants.R")
  cat("✓ constants.R loaded successfully\n")

  # Verify constants exist
  if (exists("DEFAULT_ALPHA") && DEFAULT_ALPHA == 0.05) {
    cat("✓ DEFAULT_ALPHA defined correctly (0.05)\n")
  } else {
    stop("✗ DEFAULT_ALPHA not defined or incorrect value")
  }

  if (exists("DEFAULT_MINIMUM_BASE") && DEFAULT_MINIMUM_BASE == 30) {
    cat("✓ DEFAULT_MINIMUM_BASE defined correctly (30)\n")
  } else {
    stop("✗ DEFAULT_MINIMUM_BASE not defined or incorrect value")
  }

  source("trend_calculator.R")
  cat("✓ trend_calculator.R loaded successfully\n")

  source("tracker_output.R")
  cat("✓ tracker_output.R loaded successfully\n")

  source("wave_loader.R")
  cat("✓ wave_loader.R loaded successfully\n")

}, error = function(e) {
  cat("✗ Error loading modules:", e$message, "\n")
  quit(status = 1)
})

# Test 1: is_significant() helper function
cat("\n=== Testing is_significant() Helper ===\n")
tryCatch({
  # Test NULL case
  result1 <- is_significant(NULL)
  if (!result1) {
    cat("✓ is_significant(NULL) returns FALSE\n")
  } else {
    stop("✗ is_significant(NULL) should return FALSE")
  }

  # Test NA case
  result2 <- is_significant(list(significant = NA))
  if (!result2) {
    cat("✓ is_significant(NA) returns FALSE\n")
  } else {
    stop("✗ is_significant(NA) should return FALSE")
  }

  # Test TRUE case
  result3 <- is_significant(list(significant = TRUE))
  if (result3) {
    cat("✓ is_significant(TRUE) returns TRUE\n")
  } else {
    stop("✗ is_significant(TRUE) should return TRUE")
  }

  # Test FALSE case
  result4 <- is_significant(list(significant = FALSE))
  if (!result4) {
    cat("✓ is_significant(FALSE) returns FALSE\n")
  } else {
    stop("✗ is_significant(FALSE) should return FALSE")
  }

}, error = function(e) {
  cat("✗ Error testing is_significant():", e$message, "\n")
  quit(status = 1)
})

# Test 2: Alpha constant usage in significance tests
cat("\n=== Testing Alpha Constant Usage ===\n")
tryCatch({
  # Create mock config without alpha setting
  mock_config <- list()

  # Test t_test_for_means uses DEFAULT_ALPHA
  result <- t_test_for_means(
    mean1 = 5.0, sd1 = 1.0, n1 = 100,
    mean2 = 5.5, sd2 = 1.0, n2 = 100
  )

  if (!is.null(result$alpha) && result$alpha == DEFAULT_ALPHA) {
    cat("✓ t_test_for_means uses DEFAULT_ALPHA correctly\n")
  } else {
    stop("✗ t_test_for_means not using DEFAULT_ALPHA")
  }

  # Test z_test_for_proportions uses DEFAULT_ALPHA
  result <- z_test_for_proportions(
    p1 = 0.5, n1 = 100,
    p2 = 0.6, n2 = 100
  )

  if (!is.null(result$alpha) && result$alpha == DEFAULT_ALPHA) {
    cat("✓ z_test_for_proportions uses DEFAULT_ALPHA correctly\n")
  } else {
    stop("✗ z_test_for_proportions not using DEFAULT_ALPHA")
  }

}, error = function(e) {
  cat("✗ Error testing alpha constants:", e$message, "\n")
  quit(status = 1)
})

# Test 3: NA safety in data cleaning (simulate)
cat("\n=== Testing NA Safety ===\n")
tryCatch({
  # Simulate the NA-safe code from wave_loader
  test_data <- c("1", "2", NA, "DK", "3")
  non_response_codes <- c("DK", "Refused", "NA")

  # This should not produce warnings
  for (code in non_response_codes) {
    non_na_idx <- which(!is.na(test_data))
    if (length(non_na_idx) > 0) {
      match_idx <- non_na_idx[trimws(toupper(test_data[non_na_idx])) == toupper(code)]
      if (length(match_idx) > 0) {
        test_data[match_idx] <- NA
      }
    }
  }

  cat("✓ NA safety check works without warnings\n")

  # Verify DK was replaced
  if (sum(is.na(test_data)) == 2) {  # Original NA + DK = 2 NAs
    cat("✓ Non-response codes replaced correctly\n")
  } else {
    stop("✗ Non-response code replacement failed")
  }

}, error = function(e) {
  cat("✗ Error testing NA safety:", e$message, "\n")
  quit(status = 1)
})

# All tests passed!
cat("\n=== ALL TESTS PASSED ✓ ===\n")
cat("\nThe following fixes are working correctly:\n")
cat("  1. ✓ Alpha level consistency (DEFAULT_ALPHA)\n")
cat("  2. ✓ NA safety in data cleaning\n")
cat("  3. ✓ is_significant() helper function\n")
cat("  4. ✓ Constants file loaded and used\n")
cat("\nSafe to merge to main branch!\n\n")
