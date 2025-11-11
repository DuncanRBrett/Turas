# ==============================================================================
# Test Script - Phase 3: Banner Breakouts & Composites
# ==============================================================================

# Set working directory
setwd("/Users/duncan/Documents/Turas/modules/tracker")

cat("\n================================================================================\n")
cat("TESTING TURASTACKER - PHASE 3: BANNER BREAKOUTS & COMPOSITES\n")
cat("================================================================================\n\n")

# Create Phase 3 test config with composite
cat("Creating Phase 3 test configuration...\n")

library(openxlsx)

# Create tracking_config_phase3.xlsx with composite question
wb_config <- createWorkbook()

# Waves sheet (same as MVT)
addWorksheet(wb_config, 'Waves')
waves_data <- data.frame(
  WaveID = c('W1', 'W2'),
  WaveName = c('Wave 1 - Jan 2024', 'Wave 2 - Apr 2024'),
  DataFile = c('test_wave1.csv', 'test_wave2.csv'),
  FieldworkStart = as.Date(c('2024-01-15', '2024-04-15')),
  FieldworkEnd = as.Date(c('2024-01-30', '2024-04-30')),
  WeightVar = c('weight', 'weight'),
  stringsAsFactors = FALSE
)
writeData(wb_config, 'Waves', waves_data)

# Settings sheet
addWorksheet(wb_config, 'Settings')
settings_data <- data.frame(
  Setting = c('project_name', 'decimal_places_ratings', 'show_significance', 'alpha', 'minimum_base'),
  Value = c('Phase 3 Test - Banners & Composites', '1', 'Y', '0.05', '30'),
  stringsAsFactors = FALSE
)
writeData(wb_config, 'Settings', settings_data)

# Banner sheet - add Gender
addWorksheet(wb_config, 'Banner')
banner_data <- data.frame(
  BreakVariable = c('Total', 'Gender'),
  BreakLabel = c('Total Sample', 'Gender'),
  stringsAsFactors = FALSE
)
writeData(wb_config, 'Banner', banner_data)

# TrackedQuestions sheet - add composite
addWorksheet(wb_config, 'TrackedQuestions')
tracked_data <- data.frame(
  QuestionCode = c('Q_SAT', 'Q_NPS', 'COMP_OVERALL'),
  stringsAsFactors = FALSE
)
writeData(wb_config, 'TrackedQuestions', tracked_data)

saveWorkbook(wb_config, 'tracking_config_phase3.xlsx', overwrite = TRUE)

# Create question_mapping_phase3.xlsx with composite definition
wb_mapping <- createWorkbook()

addWorksheet(wb_mapping, 'QuestionMap')
mapping_data <- data.frame(
  QuestionCode = c('Q_SAT', 'Q_NPS', 'COMP_OVERALL'),
  QuestionText = c('Overall satisfaction', 'Likelihood to recommend', 'Overall Score (Composite)'),
  QuestionType = c('Rating', 'NPS', 'Composite'),
  Wave1 = c('Q10', 'Q25', 'COMP_OVERALL'),
  Wave2 = c('Q11', 'Q26', 'COMP_OVERALL'),
  SourceQuestions = c(NA, NA, 'Q_SAT,Q_NPS'),  # Composite uses Q_SAT and Q_NPS
  stringsAsFactors = FALSE
)
writeData(wb_mapping, 'QuestionMap', mapping_data)

saveWorkbook(wb_mapping, 'question_mapping_phase3.xlsx', overwrite = TRUE)

cat("✓ Phase 3 configuration created\n\n")

# Source the main entry point
source("run_tracker.R")

# Run complete Phase 3 workflow
tryCatch({

  cat("Running Phase 3 tracker with banners and composites...\n\n")

  output_file <- run_tracker(
    tracking_config_path = "tracking_config_phase3.xlsx",
    question_mapping_path = "question_mapping_phase3.xlsx",
    data_dir = ".",
    output_path = "Phase3_Test_Output.xlsx",
    use_banners = TRUE  # Enable Phase 3 banner breakouts
  )

  cat("\n✓✓✓ PHASE 3 TEST PASSED ✓✓✓\n")
  cat("\nOutput file created:", output_file, "\n")
  cat("\nExpected sheets:\n")
  cat("  - Summary (with banner segments)\n")
  cat("  - Q_SAT (with Gender breakouts)\n")
  cat("  - Q_NPS (with Gender breakouts)\n")
  cat("  - COMP_OVERALL (composite of Q_SAT and Q_NPS)\n")
  cat("  - Change_Summary (baseline comparison)\n")
  cat("  - Metadata\n\n")

}, error = function(e) {
  cat("\n✗✗✗ TEST FAILED ✗✗✗\n")
  cat("Error:", e$message, "\n\n")
  traceback()
})
