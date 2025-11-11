# ==============================================================================
# Test Script - Phase 2: Trend Calculation & Output
# ==============================================================================

# Set working directory
setwd("/Users/duncan/Documents/Turas/modules/tracker")

cat("\n================================================================================\n")
cat("TESTING TURASTACKER - PHASE 2: TREND CALCULATION & OUTPUT\n")
cat("================================================================================\n\n")

# Source the main entry point
source("run_tracker.R")

# Run complete tracker workflow
tryCatch({

  output_file <- run_tracker(
    tracking_config_path = "tracking_config_mvt.xlsx",
    question_mapping_path = "question_mapping_mvt.xlsx",
    data_dir = ".",
    output_path = "MVT_Test_Output.xlsx"
  )

  cat("\n✓✓✓ PHASE 2 TEST PASSED ✓✓✓\n")
  cat("\nOutput file created:", output_file, "\n")
  cat("\nYou can now open the Excel file to inspect the results.\n\n")

}, error = function(e) {
  cat("\n✗✗✗ TEST FAILED ✗✗✗\n")
  cat("Error:", e$message, "\n\n")
  traceback()
})
