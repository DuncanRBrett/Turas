# ==============================================================================
# Test Script - MVT Phase 1 Foundation
# ==============================================================================

# Set working directory
setwd("/Users/duncan/Documents/Turas/modules/tracker")

cat("\n================================================================================\n")
cat("TESTING TURASTACKER MVT - PHASE 1 FOUNDATION\n")
cat("================================================================================\n\n")

# Source the main entry point
source("run_tracker.R")

# Run tracker with MVT test files
tryCatch({

  results <- run_tracker(
    tracking_config_path = "tracking_config_mvt.xlsx",
    question_mapping_path = "question_mapping_mvt.xlsx",
    data_dir = "."
  )

  cat("\n✓✓✓ PHASE 1 FOUNDATION TEST PASSED ✓✓✓\n")
  cat("\nResults available for inspection:\n")
  cat("  - results$config\n")
  cat("  - results$question_mapping\n")
  cat("  - results$question_map\n")
  cat("  - results$wave_data\n")
  cat("  - results$availability\n\n")

}, error = function(e) {
  cat("\n✗✗✗ TEST FAILED ✗✗✗\n")
  cat("Error:", e$message, "\n\n")
  traceback()
})
