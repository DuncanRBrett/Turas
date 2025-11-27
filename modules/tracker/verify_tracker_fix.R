# ==============================================================================
# Tracker Fix Verification Script
# ==============================================================================
#
# This script verifies that the tracker fixes have been applied correctly.
# Run this script to confirm:
# 1. The updated code is being loaded
# 2. Wave detection is working with your WaveIDs
# 3. Question mapping is loading correctly
#
# ==============================================================================

cat("================================================================================\n")
cat("TRACKER FIX VERIFICATION\n")
cat("================================================================================\n\n")

# Source the tracker modules
script_dir <- dirname(sys.frame(1)$ofile)
if (is.null(script_dir) || script_dir == "") {
  script_dir <- getwd()
}

cat("Loading tracker modules from:", script_dir, "\n\n")

library(openxlsx)

source(file.path(script_dir, "constants.R"))
source(file.path(script_dir, "tracker_config_loader.R"))
source(file.path(script_dir, "question_mapper.R"))

# Test configuration loading
cat("Step 1: Testing configuration loading...\n")

config_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/SACS/04_CrossWave/01_Analysis/SACS_tracking_config.xlsx"

if (!file.exists(config_path)) {
  stop("Config file not found. Please update the path in this script.")
}

config <- load_tracking_config(config_path)

cat("✓ Configuration loaded successfully\n")
cat("  WaveIDs:", paste(config$waves$WaveID, collapse = ", "), "\n")
cat("  Wave names:", paste(config$waves$WaveName, collapse = ", "), "\n\n")

# Test question mapping loading
cat("Step 2: Testing question mapping loading...\n")

mapping_path <- gsub("SACS_tracking_config.xlsx", "SACS_question_mapping.xlsx", config_path)

if (!file.exists(mapping_path)) {
  stop("Mapping file not found at:", mapping_path)
}

question_mapping <- load_question_mapping(mapping_path)

cat("✓ Question mapping loaded\n")
cat("  Total questions:", nrow(question_mapping), "\n")
cat("  Columns:", paste(names(question_mapping), collapse = ", "), "\n\n")

# Test question map index building (this is where the wave detection happens)
cat("Step 3: Testing question map index building (wave detection)...\n")

question_map <- build_question_map_index(question_mapping, config)

cat("✓ Question map index built successfully\n")
cat("  Standard codes indexed:", length(question_map$standard_to_wave), "\n\n")

# Test specific question mapping
cat("Step 4: Testing specific question mappings...\n")

# Test Q13 (the problematic one)
test_questions <- c("Q13", "Q09", "COMP_engage")

for (q_code in test_questions) {
  cat("\nQuestion:", q_code, "\n")

  # Get metadata
  metadata <- get_question_metadata(question_map, q_code)

  if (is.null(metadata)) {
    cat("  ✗ Not found in mapping\n")
    next
  }

  cat("  Type:", metadata$QuestionType, "\n")

  # Get wave-specific codes
  for (wave_id in config$waves$WaveID) {
    wave_code <- get_wave_question_code(question_map, q_code, wave_id)
    if (!is.na(wave_code)) {
      cat("  ", wave_id, "→", wave_code, "\n")
    } else {
      cat("  ", wave_id, "→ <not mapped>\n")
    }
  }

  # If composite, show source questions
  if (!is.null(metadata) && metadata$QuestionType == "Composite") {
    sources <- get_composite_sources(question_map, q_code)
    if (!is.null(sources)) {
      cat("  Source questions:", paste(sources, collapse = ", "), "\n")
    }
  }
}

cat("\n================================================================================\n")
cat("VERIFICATION COMPLETE\n")
cat("================================================================================\n")
cat("\nIf you see this message without errors, the tracker fixes are working!\n")
cat("\nNext step: Run the full tracker with your data and share:\n")
cat("1. The version number shown at startup\n")
cat("2. Any error messages with the call stack\n")
cat("3. Messages about which waves are being processed\n\n")
