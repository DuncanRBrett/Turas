# ==============================================================================
# Test Wave History Report Feature
# ==============================================================================
#
# Tests the Wave History report format implementation with real CCPB-CCS data.
#
# USAGE:
#   Run from anywhere within Turas directory structure
#   source("modules/tracker/test_wave_history.R")
#
# ==============================================================================

# Load required libraries
library(openxlsx)

# Source run_tracker
source("run_tracker.R")

message("\n================================================================================")
message("WAVE HISTORY REPORT - TEST SUITE")
message("================================================================================\n")

# Test configuration path (use user's real data)
config_path <- "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/CCPB/CCPB-CCS/04_CrossWave/CCS_question_mapping.xlsx"

# Verify file exists
if (!file.exists(config_path)) {
  stop(paste0("Configuration file not found: ", config_path))
}

message("Using configuration: ", config_path)
message("")


# ==============================================================================
# TEST 1: Wave History Report Only (No Banners)
# ==============================================================================
message("\n[TEST 1] Wave History Report Only (No Banners)")
message("================================================================================\n")

tryCatch({
  # Temporarily modify settings to use wave_history only
  # Note: This requires the user to have added report_types setting to their config
  # Or we test with the default (which will be detailed)

  result <- run_tracker(
    tracking_config_path = config_path,
    question_mapping_path = config_path,
    use_banners = FALSE
  )

  message("\n✓ Test 1 completed successfully!")
  message(paste0("  Output: ", result))

}, error = function(e) {
  message("\n✗ Test 1 failed with error:")
  message(paste0("  ", e$message))
})


# ==============================================================================
# TEST 2: Wave History Report with Banners
# ==============================================================================
message("\n[TEST 2] Wave History Report with Banners")
message("================================================================================\n")

tryCatch({
  result <- run_tracker(
    tracking_config_path = config_path,
    question_mapping_path = config_path,
    use_banners = TRUE
  )

  message("\n✓ Test 2 completed successfully!")
  if (is.list(result)) {
    message("  Outputs:")
    for (type in names(result)) {
      message(paste0("    - ", type, ": ", result[[type]]))
    }
  } else {
    message(paste0("  Output: ", result))
  }

}, error = function(e) {
  message("\n✗ Test 2 failed with error:")
  message(paste0("  ", e$message))
})


# ==============================================================================
# MANUAL TEST INSTRUCTIONS
# ==============================================================================
message("\n================================================================================")
message("MANUAL TESTING INSTRUCTIONS")
message("================================================================================\n")

message("To test Wave History report specifically, add to your Settings sheet:")
message("")
message("SettingName   | SettingValue")
message("report_types  | wave_history")
message("")
message("Or to generate both reports:")
message("")
message("SettingName   | SettingValue")
message("report_types  | detailed,wave_history")
message("")
message("Then run:")
message("")
message('  source("run_tracker.R")')
message('  run_tracker(')
message('    tracking_config_path = "', config_path, '",')
message('    question_mapping_path = "', config_path, '",')
message('    use_banners = TRUE')
message('  )')
message("")

message("================================================================================")
message("EXPECTED OUTPUT FILES")
message("================================================================================\n")

message("If report_types = wave_history:")
message("  - CCPB_CCS_WaveHistory_YYYYMMDD.xlsx")
message("")
message("If report_types = detailed,wave_history:")
message("  - CCPB_CCS_Tracker_YYYYMMDD.xlsx (detailed)")
message("  - CCPB_CCS_WaveHistory_YYYYMMDD.xlsx (wave history)")
message("")

message("================================================================================")
message("WAVE HISTORY FORMAT")
message("================================================================================\n")

message("Each sheet shows:")
message("  - One row per question/metric")
message("  - Columns: QuestionCode | Question | Type | Wave 1 | Wave 2 | ...")
message("  - Clean, scannable format for executives")
message("")
message("For questions with TrackingSpecs='mean,top2_box':")
message("  - Two rows: one for mean, one for top2_box")
message("")
message("For banner breakouts:")
message("  - One sheet per segment (Total, Male, Female, etc.)")
message("")

message("================================================================================\n")
