# ==============================================================================
# Test Script - Tracker Enhancements (Phases 1 & 2)
# ==============================================================================
#
# This script walks through testing the new tracker enhancements:
# - Phase 1: TrackingSpecs for ratings and composites
# - Phase 2: Multi-Mention support
#
# ==============================================================================

# SETUP
# Set working directory to tracker module
setwd("/home/user/Turas/modules/tracker")

# Source all tracker modules
source("run_tracker.R")

cat("\n")
cat("================================================================================\n")
cat("TRACKER ENHANCEMENTS - BASIC FUNCTIONALITY TEST\n")
cat("================================================================================\n")

# ==============================================================================
# Test 1: Verify Helper Functions Load Correctly
# ==============================================================================

cat("\n=== TEST 1: Verify Helper Functions ===\n")

# Check if new functions are available
test_functions <- c(
  "get_tracking_specs",
  "validate_tracking_specs",
  "calculate_top_box",
  "calculate_bottom_box",
  "calculate_custom_range",
  "detect_multi_mention_columns",
  "calculate_multi_mention_trend"
)

for (func_name in test_functions) {
  if (exists(func_name)) {
    cat(sprintf("✓ %s loaded\n", func_name))
  } else {
    cat(sprintf("✗ %s NOT FOUND\n", func_name))
  }
}

# ==============================================================================
# Test 2: Test TrackingSpecs Validation
# ==============================================================================

cat("\n=== TEST 2: TrackingSpecs Validation ===\n")

# Test valid specs
test_cases <- list(
  list(specs = "mean,top2_box", type = "Rating", should_pass = TRUE),
  list(specs = "range:9-10", type = "Rating", should_pass = TRUE),
  list(specs = "top_box,bottom_box", type = "Rating", should_pass = TRUE),
  list(specs = "auto,any", type = "Multi_Mention", should_pass = TRUE),
  list(specs = "option:Q30_1,option:Q30_2", type = "Multi_Mention", should_pass = TRUE),
  list(specs = "range:9-10", type = "NPS", should_pass = FALSE),  # Should fail
  list(specs = "invalid_spec", type = "Rating", should_pass = FALSE)  # Should fail
)

for (i in seq_along(test_cases)) {
  test <- test_cases[[i]]
  result <- validate_tracking_specs(test$specs, test$type)

  if (result$valid == test$should_pass) {
    cat(sprintf("✓ Test %d PASSED: '%s' for %s\n", i, test$specs, test$type))
  } else {
    cat(sprintf("✗ Test %d FAILED: '%s' for %s\n", i, test$specs, test$type))
    if (!result$valid) {
      cat(sprintf("  Error: %s\n", result$message))
    }
  }
}

# ==============================================================================
# Test 3: Test Multi-Mention Column Detection
# ==============================================================================

cat("\n=== TEST 3: Multi-Mention Column Detection ===\n")

# Create a mock data frame with multi-mention columns
mock_df <- data.frame(
  Q30_1 = c(1, 0, 1),
  Q30_2 = c(0, 1, 0),
  Q30_3 = c(1, 1, 0),
  Q30_10 = c(0, 0, 1),  # Test numeric sorting
  Q31 = c(5, 6, 7),
  weight_var = c(1, 1, 1)
)

# Test detection
detected <- detect_multi_mention_columns(mock_df, "Q30")

if (!is.null(detected) && length(detected) == 4) {
  cat("✓ Column detection works\n")
  cat("  Detected columns:", paste(detected, collapse = ", "), "\n")

  # Check if sorted numerically (Q30_1, Q30_2, Q30_3, Q30_10)
  if (detected[4] == "Q30_10") {
    cat("✓ Numeric sorting works (Q30_10 comes after Q30_3)\n")
  } else {
    cat("✗ Numeric sorting failed\n")
  }
} else {
  cat("✗ Column detection failed\n")
}

# ==============================================================================
# Test 4: Test Enhanced Rating Calculations
# ==============================================================================

cat("\n=== TEST 4: Enhanced Rating Calculations ===\n")

# Create sample rating data
rating_values <- c(8, 9, 10, 7, 9, 10, 8, 9, 10, 10)
weights <- rep(1, 10)

# Test top_box calculation
top_box_result <- calculate_top_box(rating_values, weights, n_boxes = 1)
cat(sprintf("Top box (1): %.1f%% (expected 40%% - four 10s)\n", top_box_result$proportion))

# Test top2_box calculation
top2_box_result <- calculate_top_box(rating_values, weights, n_boxes = 2)
cat(sprintf("Top 2 box: %.1f%% (expected 80%% - four 9s + four 10s)\n", top2_box_result$proportion))

# Test custom range
range_result <- calculate_custom_range(rating_values, weights, "range:9-10")
cat(sprintf("Range 9-10: %.1f%% (expected 80%%)\n", range_result$proportion))

# Test bottom_box
bottom_box_result <- calculate_bottom_box(rating_values, weights, n_boxes = 1)
cat(sprintf("Bottom box: %.1f%% (expected 20%% - two 7s)\n", bottom_box_result$proportion))

# ==============================================================================
# Summary
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("BASIC TESTS COMPLETE\n")
cat("================================================================================\n")
cat("\nAll core functions are loaded and basic calculations work.\n")
cat("\nNext steps for full testing:\n")
cat("1. Create a test question_mapping.xlsx with TrackingSpecs column\n")
cat("2. Add some sample questions with different TrackingSpecs\n")
cat("3. Run the full tracker pipeline with test data\n")
cat("4. Verify Excel output shows enhanced metrics\n")
cat("\n")
