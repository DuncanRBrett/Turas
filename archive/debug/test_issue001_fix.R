# ==============================================================================
# Test Script - Issue-001 Fix Validation
# ==============================================================================
#
# Tests the Multi_Mention selective TrackingSpecs bug fix
# Validates both the fix AND backward compatibility
#
# ==============================================================================

setwd("/home/user/Turas/modules/tracker")
source("run_tracker.R")

cat("\n")
cat("================================================================================\n")
cat("ISSUE-001 FIX VALIDATION TEST\n")
cat("================================================================================\n")

# ==============================================================================
# Setup Test Data
# ==============================================================================

cat("\n=== Creating Test Data ===\n")

# Create Wave 1 data
wave1 <- data.frame(
  ResponseID = 1:100,
  Q30_1 = sample(0:1, 100, replace = TRUE),
  Q30_2 = sample(0:1, 100, replace = TRUE),
  Q30_3 = sample(0:1, 100, replace = TRUE),
  Q30_4 = sample(0:1, 100, replace = TRUE),
  Q30_5 = sample(0:1, 100, replace = TRUE),
  weight_var = rep(1, 100),
  stringsAsFactors = FALSE
)

# Create Wave 2 data (slightly different proportions to test significance)
wave2 <- data.frame(
  ResponseID = 101:200,
  Q30_1 = sample(0:1, 100, replace = TRUE, prob = c(0.4, 0.6)),
  Q30_2 = sample(0:1, 100, replace = TRUE, prob = c(0.5, 0.5)),
  Q30_3 = sample(0:1, 100, replace = TRUE, prob = c(0.6, 0.4)),
  Q30_4 = sample(0:1, 100, replace = TRUE, prob = c(0.3, 0.7)),
  Q30_5 = sample(0:1, 100, replace = TRUE, prob = c(0.7, 0.3)),
  weight_var = rep(1, 100),
  stringsAsFactors = FALSE
)

# Create Wave 3 data
wave3 <- data.frame(
  ResponseID = 201:300,
  Q30_1 = sample(0:1, 100, replace = TRUE, prob = c(0.5, 0.5)),
  Q30_2 = sample(0:1, 100, replace = TRUE, prob = c(0.4, 0.6)),
  Q30_3 = sample(0:1, 100, replace = TRUE, prob = c(0.6, 0.4)),
  Q30_4 = sample(0:1, 100, replace = TRUE, prob = c(0.2, 0.8)),
  Q30_5 = sample(0:1, 100, replace = TRUE, prob = c(0.8, 0.2)),
  weight_var = rep(1, 100),
  stringsAsFactors = FALSE
)

wave_data <- list(
  Wave1 = wave1,
  Wave2 = wave2,
  Wave3 = wave3
)

cat("✓ Test data created (3 waves, 100 respondents each)\n")
cat("✓ Question Q30 with 5 options (Q30_1 through Q30_5)\n")

# ==============================================================================
# Create Mock Config
# ==============================================================================

config <- list(
  project_name = "Issue-001 Test",
  waves = data.frame(
    WaveID = c("Wave1", "Wave2", "Wave3"),
    stringsAsFactors = FALSE
  ),
  settings = data.frame(
    SettingName = c("alpha", "minimum_base", "show_significance", "weight_variable"),
    SettingValue = c("0.05", "30", "TRUE", "weight_var"),
    stringsAsFactors = FALSE
  )
)

cat("✓ Mock config created\n")

# ==============================================================================
# Test 1: Selective TrackingSpecs (THE BUG FIX)
# ==============================================================================

cat("\n=== TEST 1: Selective TrackingSpecs (option:Q30_4) ===\n")
cat("This was the BROKEN functionality that should now work.\n\n")

# Create question map with selective TrackingSpecs
question_map_selective <- data.frame(
  QuestionCode = "Q30",
  QuestionText = "Which options apply?",
  QuestionType = "Multi_Mention",
  Wave1 = "Q30",
  Wave2 = "Q30",
  Wave3 = "Q30",
  TrackingSpecs = "option:Q30_4",  # THE BUG: This used to fail
  stringsAsFactors = FALSE
)

test1_result <- tryCatch({
  result <- calculate_multi_mention_trend("Q30", question_map_selective, wave_data, config)

  if (is.null(result)) {
    cat("✗ FAILED: calculate_multi_mention_trend returned NULL\n")
    list(success = FALSE, error = "Function returned NULL")
  } else {
    # Validate structure
    if (!is.list(result)) {
      cat("✗ FAILED: Result is not a list\n")
      list(success = FALSE, error = "Invalid result structure")
    } else if (is.null(result$wave_results)) {
      cat("✗ FAILED: wave_results missing\n")
      list(success = FALSE, error = "wave_results missing")
    } else if (is.null(result$changes)) {
      cat("✗ FAILED: changes missing\n")
      list(success = FALSE, error = "changes missing")
    } else {
      # Check that only Q30_4 is tracked
      wave1_result <- result$wave_results$Wave1
      tracked_cols <- wave1_result$tracked_columns

      if (length(tracked_cols) != 1 || tracked_cols[1] != "Q30_4") {
        cat("✗ FAILED: Expected only Q30_4 to be tracked, got:", paste(tracked_cols, collapse = ", "), "\n")
        list(success = FALSE, error = "Wrong columns tracked")
      } else {
        # Check that mention proportion exists for Q30_4
        if (is.null(wave1_result$mention_proportions$Q30_4)) {
          cat("✗ FAILED: Q30_4 mention proportion missing\n")
          list(success = FALSE, error = "Q30_4 data missing")
        } else if (is.na(wave1_result$mention_proportions$Q30_4)) {
          cat("✗ FAILED: Q30_4 mention proportion is NA\n")
          list(success = FALSE, error = "Q30_4 is NA")
        } else {
          cat("✓ SUCCESS: Selective TrackingSpecs works!\n")
          cat(sprintf("  - Only Q30_4 tracked (not Q30_1, Q30_2, Q30_3, Q30_5)\n"))
          cat(sprintf("  - Wave1 Q30_4: %.1f%%\n", wave1_result$mention_proportions$Q30_4))
          cat(sprintf("  - Wave2 Q30_4: %.1f%%\n", result$wave_results$Wave2$mention_proportions$Q30_4))
          cat(sprintf("  - Wave3 Q30_4: %.1f%%\n", result$wave_results$Wave3$mention_proportions$Q30_4))
          list(success = TRUE, result = result)
        }
      }
    }
  }
}, error = function(e) {
  cat("✗ FAILED with ERROR:", e$message, "\n")
  list(success = FALSE, error = e$message)
})

# ==============================================================================
# Test 2: Auto-Detection (Backward Compatibility)
# ==============================================================================

cat("\n=== TEST 2: Auto-Detection (Backward Compatibility) ===\n")
cat("This should still work as before (no regression).\n\n")

question_map_auto <- data.frame(
  QuestionCode = "Q30",
  QuestionText = "Which options apply?",
  QuestionType = "Multi_Mention",
  Wave1 = "Q30",
  Wave2 = "Q30",
  Wave3 = "Q30",
  TrackingSpecs = "auto",  # Auto-detect all options
  stringsAsFactors = FALSE
)

test2_result <- tryCatch({
  result <- calculate_multi_mention_trend("Q30", question_map_auto, wave_data, config)

  if (is.null(result)) {
    cat("✗ FAILED: calculate_multi_mention_trend returned NULL\n")
    list(success = FALSE, error = "Function returned NULL")
  } else {
    wave1_result <- result$wave_results$Wave1
    tracked_cols <- wave1_result$tracked_columns

    # Should track ALL 5 columns
    if (length(tracked_cols) != 5) {
      cat("✗ FAILED: Expected 5 columns, got", length(tracked_cols), "\n")
      list(success = FALSE, error = "Wrong column count")
    } else if (!all(c("Q30_1", "Q30_2", "Q30_3", "Q30_4", "Q30_5") %in% tracked_cols)) {
      cat("✗ FAILED: Not all columns tracked\n")
      list(success = FALSE, error = "Missing columns")
    } else {
      cat("✓ SUCCESS: Auto-detection works!\n")
      cat(sprintf("  - All 5 columns tracked: %s\n", paste(tracked_cols, collapse = ", ")))
      cat(sprintf("  - Wave1 Q30_1: %.1f%%\n", wave1_result$mention_proportions$Q30_1))
      cat(sprintf("  - Wave1 Q30_2: %.1f%%\n", wave1_result$mention_proportions$Q30_2))
      cat(sprintf("  - Wave1 Q30_3: %.1f%%\n", wave1_result$mention_proportions$Q30_3))
      cat(sprintf("  - Wave1 Q30_4: %.1f%%\n", wave1_result$mention_proportions$Q30_4))
      cat(sprintf("  - Wave1 Q30_5: %.1f%%\n", wave1_result$mention_proportions$Q30_5))
      list(success = TRUE, result = result)
    }
  }
}, error = function(e) {
  cat("✗ FAILED with ERROR:", e$message, "\n")
  list(success = FALSE, error = e$message)
})

# ==============================================================================
# Test 3: Blank TrackingSpecs (Backward Compatibility)
# ==============================================================================

cat("\n=== TEST 3: Blank TrackingSpecs (Backward Compatibility) ===\n")
cat("Blank TrackingSpecs should default to auto-detection.\n\n")

question_map_blank <- data.frame(
  QuestionCode = "Q30",
  QuestionText = "Which options apply?",
  QuestionType = "Multi_Mention",
  Wave1 = "Q30",
  Wave2 = "Q30",
  Wave3 = "Q30",
  TrackingSpecs = "",  # Blank - should auto-detect
  stringsAsFactors = FALSE
)

test3_result <- tryCatch({
  result <- calculate_multi_mention_trend("Q30", question_map_blank, wave_data, config)

  if (is.null(result)) {
    cat("✗ FAILED: calculate_multi_mention_trend returned NULL\n")
    list(success = FALSE, error = "Function returned NULL")
  } else {
    wave1_result <- result$wave_results$Wave1
    tracked_cols <- wave1_result$tracked_columns

    if (length(tracked_cols) != 5) {
      cat("✗ FAILED: Expected 5 columns, got", length(tracked_cols), "\n")
      list(success = FALSE, error = "Wrong column count")
    } else {
      cat("✓ SUCCESS: Blank TrackingSpecs works (auto-detection)!\n")
      cat(sprintf("  - All 5 columns tracked: %s\n", paste(tracked_cols, collapse = ", ")))
      list(success = TRUE, result = result)
    }
  }
}, error = function(e) {
  cat("✗ FAILED with ERROR:", e$message, "\n")
  list(success = FALSE, error = e$message)
})

# ==============================================================================
# Test 4: Multiple Selective Options
# ==============================================================================

cat("\n=== TEST 4: Multiple Selective Options ===\n")
cat("Testing option:Q30_2,option:Q30_4 (select 2 out of 5).\n\n")

question_map_multi_selective <- data.frame(
  QuestionCode = "Q30",
  QuestionText = "Which options apply?",
  QuestionType = "Multi_Mention",
  Wave1 = "Q30",
  Wave2 = "Q30",
  Wave3 = "Q30",
  TrackingSpecs = "option:Q30_2,option:Q30_4",
  stringsAsFactors = FALSE
)

test4_result <- tryCatch({
  result <- calculate_multi_mention_trend("Q30", question_map_multi_selective, wave_data, config)

  if (is.null(result)) {
    cat("✗ FAILED: calculate_multi_mention_trend returned NULL\n")
    list(success = FALSE, error = "Function returned NULL")
  } else {
    wave1_result <- result$wave_results$Wave1
    tracked_cols <- wave1_result$tracked_columns

    if (length(tracked_cols) != 2) {
      cat("✗ FAILED: Expected 2 columns, got", length(tracked_cols), "\n")
      list(success = FALSE, error = "Wrong column count")
    } else if (!all(c("Q30_2", "Q30_4") %in% tracked_cols)) {
      cat("✗ FAILED: Q30_2 and Q30_4 not both tracked\n")
      list(success = FALSE, error = "Wrong columns")
    } else {
      cat("✓ SUCCESS: Multiple selective options work!\n")
      cat(sprintf("  - Only Q30_2 and Q30_4 tracked: %s\n", paste(tracked_cols, collapse = ", ")))
      cat(sprintf("  - Wave1 Q30_2: %.1f%%\n", wave1_result$mention_proportions$Q30_2))
      cat(sprintf("  - Wave1 Q30_4: %.1f%%\n", wave1_result$mention_proportions$Q30_4))
      list(success = TRUE, result = result)
    }
  }
}, error = function(e) {
  cat("✗ FAILED with ERROR:", e$message, "\n")
  list(success = FALSE, error = e$message)
})

# ==============================================================================
# Test 5: Selective with Additional Metrics
# ==============================================================================

cat("\n=== TEST 5: Selective TrackingSpecs with Additional Metrics ===\n")
cat("Testing option:Q30_4,any,count_mean.\n\n")

question_map_selective_metrics <- data.frame(
  QuestionCode = "Q30",
  QuestionText = "Which options apply?",
  QuestionType = "Multi_Mention",
  Wave1 = "Q30",
  Wave2 = "Q30",
  Wave3 = "Q30",
  TrackingSpecs = "option:Q30_4,any,count_mean",
  stringsAsFactors = FALSE
)

test5_result <- tryCatch({
  result <- calculate_multi_mention_trend("Q30", question_map_selective_metrics, wave_data, config)

  if (is.null(result)) {
    cat("✗ FAILED: calculate_multi_mention_trend returned NULL\n")
    list(success = FALSE, error = "Function returned NULL")
  } else {
    wave1_result <- result$wave_results$Wave1
    tracked_cols <- wave1_result$tracked_columns

    if (length(tracked_cols) != 1 || tracked_cols[1] != "Q30_4") {
      cat("✗ FAILED: Expected only Q30_4\n")
      list(success = FALSE, error = "Wrong columns")
    } else if (is.null(wave1_result$additional_metrics$any_mention_pct)) {
      cat("✗ FAILED: 'any' metric missing\n")
      list(success = FALSE, error = "'any' metric missing")
    } else if (is.null(wave1_result$additional_metrics$count_mean)) {
      cat("✗ FAILED: 'count_mean' metric missing\n")
      list(success = FALSE, error = "'count_mean' metric missing")
    } else {
      cat("✓ SUCCESS: Selective with additional metrics works!\n")
      cat(sprintf("  - Tracked column: Q30_4 (%.1f%%)\n", wave1_result$mention_proportions$Q30_4))
      cat(sprintf("  - Any mention: %.1f%%\n", wave1_result$additional_metrics$any_mention_pct))
      cat(sprintf("  - Count mean: %.2f\n", wave1_result$additional_metrics$count_mean))
      list(success = TRUE, result = result)
    }
  }
}, error = function(e) {
  cat("✗ FAILED with ERROR:", e$message, "\n")
  list(success = FALSE, error = e$message)
})

# ==============================================================================
# Test Summary
# ==============================================================================

cat("\n")
cat("================================================================================\n")
cat("TEST SUMMARY\n")
cat("================================================================================\n\n")

all_tests <- list(
  list(name = "Test 1: Selective TrackingSpecs (THE BUG FIX)", result = test1_result),
  list(name = "Test 2: Auto-Detection", result = test2_result),
  list(name = "Test 3: Blank TrackingSpecs", result = test3_result),
  list(name = "Test 4: Multiple Selective Options", result = test4_result),
  list(name = "Test 5: Selective with Additional Metrics", result = test5_result)
)

passed <- 0
failed <- 0

for (test in all_tests) {
  if (test$result$success) {
    cat(sprintf("✓ PASSED: %s\n", test$name))
    passed <- passed + 1
  } else {
    cat(sprintf("✗ FAILED: %s\n", test$name))
    cat(sprintf("  Error: %s\n", test$result$error))
    failed <- failed + 1
  }
}

cat("\n")
cat(sprintf("Total Tests: %d\n", length(all_tests)))
cat(sprintf("Passed: %d\n", passed))
cat(sprintf("Failed: %d\n", failed))
cat("\n")

if (failed == 0) {
  cat("================================================================================\n")
  cat("✓✓✓ ALL TESTS PASSED - BUG FIX VALIDATED ✓✓✓\n")
  cat("================================================================================\n")
  cat("\nThe fix is working correctly:\n")
  cat("1. Selective TrackingSpecs (option:Q30_4) now works - BUG FIXED!\n")
  cat("2. Auto-detection still works - No regression\n")
  cat("3. Blank TrackingSpecs still works - No regression\n")
  cat("4. Multiple selective options work - Extended functionality confirmed\n")
  cat("5. Additional metrics work with selective - Combined functionality confirmed\n")
  cat("\n✓ Safe to deploy to production\n")
} else {
  cat("================================================================================\n")
  cat("✗✗✗ SOME TESTS FAILED - REVIEW REQUIRED ✗✗✗\n")
  cat("================================================================================\n")
  cat("\nDO NOT DEPLOY until all tests pass.\n")
}

cat("\n")
