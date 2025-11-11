# ==============================================================================
# Test Script - Phase 1 Foundation
# ==============================================================================
#
# Tests the Phase 1 foundation components with template files.
# This script helps validate that all modules load and work correctly.
#
# ==============================================================================

# Set working directory to tracker module
setwd("/Users/duncan/Documents/Turas/modules/tracker")

# Source the main entry point (which sources all other modules)
source("run_tracker.R")

# ==============================================================================
# Test 1: Examine Template Files
# ==============================================================================

cat("\n=== TEST 1: Examining Template Files ===\n")

# Load and inspect tracking_config.xlsx
cat("\nLoading tracking_config_template.xlsx...\n")
config_sheets <- openxlsx::getSheetNames("tracking_config_template.xlsx")
cat("Sheets found:", paste(config_sheets, collapse = ", "), "\n")

# Check Waves sheet
cat("\nWaves sheet:\n")
waves <- openxlsx::read.xlsx("tracking_config_template.xlsx", sheet = "Waves", detectDates = TRUE)
print(waves)

# Check Settings sheet
cat("\nSettings sheet:\n")
settings <- openxlsx::read.xlsx("tracking_config_template.xlsx", sheet = "Settings")
print(settings)

# Check Banner sheet
cat("\nBanner sheet:\n")
banner <- openxlsx::read.xlsx("tracking_config_template.xlsx", sheet = "Banner")
print(banner)

# Check TrackedQuestions sheet
cat("\nTrackedQuestions sheet:\n")
tracked <- openxlsx::read.xlsx("tracking_config_template.xlsx", sheet = "TrackedQuestions")
print(tracked)

# Load and inspect question_mapping.xlsx
cat("\n\nLoading question_mapping_template.xlsx...\n")
mapping_sheets <- openxlsx::getSheetNames("question_mapping_template.xlsx")
cat("Sheets found:", paste(mapping_sheets, collapse = ", "), "\n")

# Check QuestionMap sheet
cat("\nQuestionMap sheet:\n")
mapping <- openxlsx::read.xlsx("question_mapping_template.xlsx", sheet = "QuestionMap")
print(mapping)

# ==============================================================================
# Test 2: Test Configuration Loading
# ==============================================================================

cat("\n\n=== TEST 2: Testing Configuration Loading ===\n")

tryCatch({
  # Load config
  config <- load_tracking_config("tracking_config_template.xlsx")
  cat("✓ Configuration loaded successfully\n")
  cat("  Waves:", nrow(config$waves), "\n")
  cat("  Settings:", length(config$settings), "\n")
  cat("  Banner breakouts:", nrow(config$banner), "\n")
  cat("  Tracked questions:", nrow(config$tracked_questions), "\n")

  # Load mapping
  question_mapping <- load_question_mapping("question_mapping_template.xlsx")
  cat("✓ Question mapping loaded successfully\n")
  cat("  Questions mapped:", nrow(question_mapping), "\n")

  # Validate config
  validate_tracking_config(config, question_mapping)
  cat("✓ Configuration validation passed\n")

  # Build question map
  question_map <- build_question_map_index(question_mapping, config)
  cat("✓ Question map index built successfully\n")

  # Test some question map lookups
  cat("\nQuestion map lookup tests:\n")
  first_q <- question_mapping$QuestionCode[1]
  cat("  Standard code:", first_q, "\n")

  for (i in 1:nrow(config$waves)) {
    wave_id <- config$waves$WaveID[i]
    wave_code <- get_wave_question_code(question_map, first_q, wave_id)
    cat("    ", wave_id, "->", wave_code, "\n")
  }

}, error = function(e) {
  cat("✗ Error:", e$message, "\n")
})

# ==============================================================================
# Test 3: Check for Test Data Files
# ==============================================================================

cat("\n\n=== TEST 3: Checking for Test Data Files ===\n")

# Check if data files specified in template exist
if (exists("config")) {
  for (i in 1:nrow(config$waves)) {
    data_file <- config$waves$DataFile[i]
    exists <- file.exists(data_file)
    cat("  ", config$waves$WaveID[i], ": ", data_file, " - ",
        if (exists) "✓ Found" else "✗ Not found", "\n", sep = "")
  }

  cat("\nNote: If data files not found, we cannot complete full validation.\n")
  cat("      You can create synthetic test data or point to real data files.\n")
}

cat("\n=== Phase 1 Foundation Test Complete ===\n")
