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

source(file.path(script_dir, "constants.R"))
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

  # Enable detailed error tracking with logging to file
  log_file <- file.path(dirname(tracking_config_path), "tracker_error.log")
  old_options <- options(warn = 1, error = quote({
    error_msg <- geterrmessage()

    # Write to console
    cat("\n!!! ERROR OCCURRED !!!\n")
    cat("Error message:", error_msg, "\n")
    cat("\nCall stack:\n")
    traceback()

    # Write to log file
    tryCatch({
      log_conn <- file(log_file, "w")
      cat("TRACKER ERROR LOG\n", file = log_conn)
      cat("================================================================================\n", file = log_conn)
      cat("Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n", file = log_conn)
      cat("Error message:", error_msg, "\n\n", file = log_conn)
      cat("Call stack:\n", file = log_conn)
      cat(paste(capture.output(traceback()), collapse = "\n"), file = log_conn)
      cat("\n================================================================================\n", file = log_conn)
      close(log_conn)
      cat("\nError details written to:", log_file, "\n")
    }, error = function(e) {
      # Ignore if logging fails
    })
  }))
  on.exit(options(old_options), add = TRUE)

  phase_label <- if (use_banners) "PHASE 3: BANNER BREAKOUTS & COMPOSITES" else "PHASE 2: TREND CALCULATION & OUTPUT"

  cat("================================================================================\n")
  cat(paste0("TURASTACKER - MVT ", phase_label, "\n"))
  cat("================================================================================\n")
  cat(paste0("Version: 2024-11-27 (Fixed Wave Detection + Diagnostics)\n"))
  cat(paste0("Started: ", format(start_time, "%Y-%m-%d %H:%M:%S"), "\n"))
  cat("\n")

  # ============================================================================
  # STEP 1: Load Configuration
  # ============================================================================
  cat("\n[1/6] LOADING CONFIGURATION\n")
  cat("================================================================================\n")

  config <- load_tracking_config(tracking_config_path)

  # Display project info
  project_name <- get_setting(config, "project_name", default = "Tracking Analysis")
  cat(paste0("\nProject: ", project_name, "\n"))
  cat(paste0("Waves: ", paste(config$waves$WaveName, collapse = ", "), "\n"))


  # ============================================================================
  # STEP 2: Load Question Mapping
  # ============================================================================
  cat("\n[2/6] LOADING QUESTION MAPPING\n")
  cat("================================================================================\n")

  question_mapping <- load_question_mapping(question_mapping_path)

  # Build question map index
  question_map <- build_question_map_index(question_mapping, config)


  # ============================================================================
  # STEP 3: Validate Configuration
  # ============================================================================
  cat("\n[3/6] VALIDATING CONFIGURATION\n")
  cat("================================================================================\n")

  validate_tracking_config(config, question_mapping)


  # ============================================================================
  # STEP 4: Load Wave Data
  # ============================================================================
  cat("\n[4/6] LOADING WAVE DATA\n")
  cat("================================================================================\n")

  wave_data <- load_all_waves(config, data_dir, question_mapping)

  # Display wave summary
  wave_summary <- get_wave_summary(wave_data)
  print(wave_summary)


  # ============================================================================
  # STEP 5: Validate Wave Data
  # ============================================================================
  cat("\n[5/6] VALIDATING WAVE DATA\n")
  cat("================================================================================\n")

  validate_wave_data(wave_data, config, question_mapping)


  # ============================================================================
  # STEP 6: Comprehensive Validation
  # ============================================================================
  cat("\n[6/6] RUNNING COMPREHENSIVE VALIDATION\n")
  cat("================================================================================\n")

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
  cat("\n[7/8] CALCULATING TRENDS\n")
  cat("================================================================================\n")

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
  cat("\n[8/8] GENERATING OUTPUT\n")
  cat("================================================================================\n")

  # Check report_types setting to determine which outputs to generate
  report_types_setting <- get_setting(config, "report_types", default = "detailed")

  # Parse comma-separated list and trim whitespace
  report_types <- trimws(strsplit(report_types_setting, ",")[[1]])

  # Validate report types
  valid_types <- c("detailed", "wave_history")
  invalid_types <- setdiff(report_types, valid_types)
  if (length(invalid_types) > 0) {
    warning(paste0("Invalid report types ignored: ", paste(invalid_types, collapse = ", ")))
    report_types <- intersect(report_types, valid_types)
  }

  # If no valid types, default to detailed
  if (length(report_types) == 0) {
    report_types <- "detailed"
    cat("  No valid report types specified, defaulting to 'detailed'\n")
  }

  cat(paste0("  Report types to generate: ", paste(report_types, collapse = ", "), "\n"))

  # Generate outputs based on report types
  output_files <- list()

  if ("detailed" %in% report_types) {
    # Generate detailed trend report
    detailed_path <- if (length(report_types) > 1) {
      # Multiple report types - use specific filename
      output_dir <- if (!is.null(output_path)) {
        dirname(output_path)
      } else {
        get_setting(config, "output_dir", default = dirname(config$config_path))
      }
      project_name <- get_setting(config, "project_name", default = "Tracking")
      project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)
      file.path(output_dir, paste0(project_name, "_Tracker_", format(Sys.Date(), "%Y%m%d"), ".xlsx"))
    } else {
      # Single report type - use default output_path
      output_path
    }

    output_files$detailed <- write_tracker_output(
      trend_results = trend_results,
      config = config,
      wave_data = wave_data,
      output_path = detailed_path,
      banner_segments = banner_segments
    )
  }

  if ("wave_history" %in% report_types) {
    # Generate wave history report
    wave_history_path <- if (length(report_types) > 1) {
      # Multiple report types - use specific filename
      output_dir <- if (!is.null(output_path)) {
        dirname(output_path)
      } else {
        get_setting(config, "output_dir", default = dirname(config$config_path))
      }
      project_name <- get_setting(config, "project_name", default = "Tracking")
      project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)
      file.path(output_dir, paste0(project_name, "_WaveHistory_", format(Sys.Date(), "%Y%m%d"), ".xlsx"))
    } else {
      # Single report type - use default output_path or auto-generate
      NULL  # Let write_wave_history_output handle it
    }

    output_files$wave_history <- write_wave_history_output(
      trend_results = trend_results,
      config = config,
      wave_data = wave_data,
      output_path = wave_history_path,
      banner_segments = banner_segments
    )
  }


  # ============================================================================
  # PHASE 2 COMPLETE - Analysis Complete
  # ============================================================================
  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  cat("\n================================================================================\n")
  cat("TRACKING ANALYSIS COMPLETE\n")
  cat("================================================================================\n")
  cat(paste0("Completed: ", format(end_time, "%Y-%m-%d %H:%M:%S"), "\n"))
  cat(paste0("Elapsed time: ", round(elapsed, 1), " seconds\n"))
  cat("\n")
  cat("✓ Configuration loaded and validated\n")
  cat("✓ Question mapping indexed\n")
  cat("✓ Wave data loaded\n")
  cat(paste0("✓ Trends calculated for ", length(trend_results), " questions\n"))

  # Display output files
  if (length(output_files) > 0) {
    cat("✓ Output files generated:\n")
    for (report_type in names(output_files)) {
      cat(paste0("  - ", report_type, ": ", output_files[[report_type]], "\n"))
    }
  }

  cat("\n")
  cat("================================================================================\n\n")

  # Return output file path(s)
  # If single output, return as character; if multiple, return as named list
  if (length(output_files) == 1) {
    return(output_files[[1]])
  } else {
    return(output_files)
  }
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

  cat("Running tracker foundation test...\n\n")

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
  cat("NOTE: This test will load templates but may fail on data loading\n")
  cat("      if synthetic test data is not available.\n\n")

  tryCatch({
    results <- run_tracker(
      tracking_config_path = tracking_config_path,
      question_mapping_path = question_mapping_path,
      data_dir = script_dir
    )

    cat("\n✓ Foundation test completed successfully!\n")
    return(results)

  }, error = function(e) {
    cat("\n✗ Test failed: ", e$message, "\n")
    cat("\nThis is expected if test data files are not yet available.\n")
    cat("Templates loaded successfully up to the point of data file loading.\n")
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
