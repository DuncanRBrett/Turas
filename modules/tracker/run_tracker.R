# ==============================================================================
# TurasTracker - Main Entry Point
# ==============================================================================
#
# MVT (Minimum Viable Tracker) - Phase 2: Trend Calculation & Output
#
# Main orchestration script for running tracking analysis across survey waves.
#
# USAGE:
#   source("run_tracker.R")
#   run_tracker(
#     tracking_config_path = "path/to/tracking_config.xlsx",
#     question_mapping_path = "path/to/question_mapping.xlsx",
#     data_dir = "path/to/data/files",
#     output_path = "optional/output/path.xlsx"
#   )
#
# ==============================================================================

# Load required libraries
library(openxlsx)

# Source module files
# When run from GUI, sys.frame(1)$ofile is NULL, so use getwd() as fallback
script_dir <- tryCatch({
  dirname(sys.frame(1)$ofile)
}, error = function(e) {
  getwd()
})

source(file.path(script_dir, "tracker_config_loader.R"))
source(file.path(script_dir, "wave_loader.R"))
source(file.path(script_dir, "question_mapper.R"))
source(file.path(script_dir, "validation_tracker.R"))
source(file.path(script_dir, "trend_calculator.R"))
source(file.path(script_dir, "banner_trends.R"))
source(file.path(script_dir, "formatting_utils.R"))
source(file.path(script_dir, "tracker_output.R"))


#' Run Tracking Analysis
#'
#' Main entry point for TurasTracker.
#' Supports Phase 2 (simple trends) and Phase 3 (banner breakouts & composites).
#'
#' @param tracking_config_path Character. Path to tracking_config.xlsx
#' @param question_mapping_path Character. Path to question_mapping.xlsx
#' @param data_dir Character. Directory containing wave data files (for relative paths)
#' @param output_path Character. Path for output file (default: auto-generated)
#' @param use_banners Logical. If TRUE, calculate trends with banner breakouts (Phase 3). Default FALSE (Phase 2).
#'
#' @return Character. Path to generated Excel file
#'
#' @export
run_tracker <- function(tracking_config_path,
                        question_mapping_path,
                        data_dir = NULL,
                        output_path = NULL,
                        use_banners = FALSE) {

  start_time <- Sys.time()

  phase_label <- if (use_banners) "PHASE 3: BANNER BREAKOUTS & COMPOSITES" else "PHASE 2: TREND CALCULATION & OUTPUT"

  message("================================================================================")
  message(paste0("TURASTACKER - MVT ", phase_label))
  message("================================================================================")
  message(paste0("Started: ", format(start_time, "%Y-%m-%d %H:%M:%S")))
  message("")

  # ============================================================================
  # STEP 1: Load Configuration
  # ============================================================================
  message("\n[1/6] LOADING CONFIGURATION")
  message("================================================================================")

  config <- load_tracking_config(tracking_config_path)

  # Display project info
  project_name <- get_setting(config, "project_name", default = "Tracking Analysis")
  message(paste0("\nProject: ", project_name))
  message(paste0("Waves: ", paste(config$waves$WaveName, collapse = ", ")))


  # ============================================================================
  # STEP 2: Load Question Mapping
  # ============================================================================
  message("\n[2/6] LOADING QUESTION MAPPING")
  message("================================================================================")

  question_mapping <- load_question_mapping(question_mapping_path)

  # Build question map index
  question_map <- build_question_map_index(question_mapping, config)


  # ============================================================================
  # STEP 3: Validate Configuration
  # ============================================================================
  message("\n[3/6] VALIDATING CONFIGURATION")
  message("================================================================================")

  validate_tracking_config(config, question_mapping)


  # ============================================================================
  # STEP 4: Load Wave Data
  # ============================================================================
  message("\n[4/6] LOADING WAVE DATA")
  message("================================================================================")

  wave_data <- load_all_waves(config, data_dir)

  # Display wave summary
  wave_summary <- get_wave_summary(wave_data)
  print(wave_summary)


  # ============================================================================
  # STEP 5: Validate Wave Data
  # ============================================================================
  message("\n[5/6] VALIDATING WAVE DATA")
  message("================================================================================")

  validate_wave_data(wave_data, config, question_mapping)


  # ============================================================================
  # STEP 6: Comprehensive Validation
  # ============================================================================
  message("\n[6/6] RUNNING COMPREHENSIVE VALIDATION")
  message("================================================================================")

  validation_results <- validate_tracker_setup(
    config = config,
    question_mapping = question_mapping,
    question_map = question_map,
    wave_data = wave_data
  )

  # Display question availability
  availability <- validate_question_mapping(config, question_map, wave_data)


  # ============================================================================
  # STEP 7: Calculate Trends
  # ============================================================================
  message("\n[7/8] CALCULATING TRENDS")
  message("================================================================================")

  if (use_banners) {
    # Phase 3: Calculate trends with banner breakouts
    banner_segments <- get_banner_segments(config, wave_data)
    trend_results <- calculate_trends_with_banners(
      config = config,
      question_map = question_map,
      wave_data = wave_data
    )
  } else {
    # Phase 2: Calculate simple trends (Total only)
    trend_results <- calculate_all_trends(
      config = config,
      question_map = question_map,
      wave_data = wave_data
    )
    banner_segments <- NULL
  }


  # ============================================================================
  # STEP 8: Write Excel Output
  # ============================================================================
  message("\n[8/8] GENERATING OUTPUT")
  message("================================================================================")

  output_file <- write_tracker_output(
    trend_results = trend_results,
    config = config,
    wave_data = wave_data,
    output_path = output_path,
    banner_segments = banner_segments
  )


  # ============================================================================
  # PHASE 2 COMPLETE - Analysis Complete
  # ============================================================================
  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  message("\n================================================================================")
  message("TRACKING ANALYSIS COMPLETE")
  message("================================================================================")
  message(paste0("Completed: ", format(end_time, "%Y-%m-%d %H:%M:%S")))
  message(paste0("Elapsed time: ", round(elapsed, 1), " seconds"))
  message("")
  message("✓ Configuration loaded and validated")
  message("✓ Question mapping indexed")
  message("✓ Wave data loaded")
  message(paste0("✓ Trends calculated for ", length(trend_results), " questions"))
  message(paste0("✓ Output written to: ", output_file))
  message("")
  message("================================================================================\n")

  # Return output file path
  return(output_file)
}


#' Quick Test Run
#'
#' Convenience function for testing with template files.
#' Assumes templates are in the tracker module directory.
#'
#' @param use_synthetic_data Logical. If TRUE, will look for synthetic test data
#'
#' @export
test_tracker_foundation <- function(use_synthetic_data = FALSE) {

  message("Running tracker foundation test...\n")

  script_dir <- dirname(sys.frame(1)$ofile)

  # Use template config files
  tracking_config_path <- file.path(script_dir, "tracking_config_template.xlsx")
  question_mapping_path <- file.path(script_dir, "question_mapping_template.xlsx")

  # Check if templates exist
  if (!file.exists(tracking_config_path)) {
    stop(paste0("Template not found: ", tracking_config_path))
  }

  if (!file.exists(question_mapping_path)) {
    stop(paste0("Template not found: ", question_mapping_path))
  }

  # For Phase 1, just test loading and validation
  message("NOTE: This test will load templates but may fail on data loading")
  message("      if synthetic test data is not available.\n")

  tryCatch({
    results <- run_tracker(
      tracking_config_path = tracking_config_path,
      question_mapping_path = question_mapping_path,
      data_dir = script_dir
    )

    message("\n✓ Foundation test completed successfully!")
    return(results)

  }, error = function(e) {
    message("\n✗ Test failed: ", e$message)
    message("\nThis is expected if test data files are not yet available.")
    message("Templates loaded successfully up to the point of data file loading.")
  })
}


# ==============================================================================
# SHARED CODE REFACTORING NOTES - SUMMARY
# ==============================================================================
#
# The following code should be extracted to /shared/ for use by both
# TurasTabs and TurasTracker:
#
# 1. /shared/config_utils.R
#    - read_config_sheet() - Generic Excel config sheet reader
#    - parse_settings() - Settings dataframe to named list conversion
#    - get_setting() - Safe setting retrieval with defaults
#    - validate_required_columns() - Column validation
#
# 2. /shared/weights.R
#    - apply_weights() - Weight variable application
#    - calculate_weight_efficiency() - Effective sample size calculation
#    - validate_weights() - Weight value validation
#    - weight_summary_stats() - Weight distribution statistics
#
# 3. /shared/data_utils.R
#    - load_data_file() - Generic CSV/Excel file loader
#    - resolve_file_path() - Path resolution (absolute/relative)
#    - validate_data_structure() - Basic data validation
#
# 4. /shared/validation_utils.R
#    - validate_date_range() - Date validation
#    - check_duplicates() - Duplicate checking
#    - merge_validation_results() - Validation result aggregation
#
# 5. /shared/excel_styles.R (already exists in TurasTabs)
#    - Style definitions for Excel output
#    - Header formatting
#    - Data cell formatting
#    - Number formatting with decimal separator
#
# 6. /shared/significance_tests.R (for Phase 2)
#    - z_test_proportions() - Z-test for proportions
#    - t_test_means() - T-test for means
#    - apply_significance_letters() - Letter marking (A/B/C)
#
# 7. /shared/composite_calculator.R (for Phase 3)
#    - calculate_composite_mean() - Mean composite calculation
#    - calculate_composite_sum() - Sum composite calculation
#    - calculate_composite_weighted_mean() - Weighted mean composite
#
# When extracting to /shared/:
#   - Preserve Roxygen documentation
#   - Add unit tests for each shared function
#   - Update both TurasTabs and TurasTracker to source from /shared/
#   - Ensure backward compatibility with existing TurasTabs code
#
# ==============================================================================
