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

# TRS Guard Layer (v1.0) - MUST be loaded first before any module files
source(file.path(script_dir, "lib", "00_guard.R"))

# ==============================================================================
# TRS RUN STATE INFRASTRUCTURE (v1.0)
# ==============================================================================
# Source TRS run state and banner helpers from shared/lib
.source_trs_infrastructure_tracker <- function() {
  possible_paths <- c(
    file.path(script_dir, "..", "shared", "lib"),
    file.path(getwd(), "modules", "shared", "lib"),
    file.path(Sys.getenv("TURAS_HOME"), "modules", "shared", "lib")
  )

  trs_files <- c("trs_run_state.R", "trs_banner.R", "trs_run_status_writer.R", "turas_log.R")

  for (trs_file in trs_files) {
    loaded <- FALSE
    for (p in possible_paths) {
      fpath <- file.path(p, trs_file)
      if (file.exists(fpath)) {
        tryCatch({
          source(fpath, local = FALSE)
          loaded <- TRUE
          break
        }, error = function(e) NULL)
      }
    }
  }
}

# Attempt to load TRS infrastructure
tryCatch({
  .source_trs_infrastructure_tracker()
}, error = function(e) {
  message("[TRS INFO] TRS infrastructure not fully loaded: ", e$message)
})

source(file.path(script_dir, "lib", "constants.R"))
# Load metric types module (required by most other modules)
source(file.path(script_dir, "lib", "metric_types.R"))
source(file.path(script_dir, "lib", "tracker_config_loader.R"))
source(file.path(script_dir, "lib", "wave_loader.R"))
source(file.path(script_dir, "lib", "question_mapper.R"))
source(file.path(script_dir, "lib", "validation_tracker.R"))
source(file.path(script_dir, "lib", "statistical_core.R"))
# Load trend calculation modules
source(file.path(script_dir, "lib", "trend_changes.R"))
source(file.path(script_dir, "lib", "trend_significance.R"))
source(file.path(script_dir, "lib", "trend_calculator.R"))
source(file.path(script_dir, "lib", "banner_trends.R"))
source(file.path(script_dir, "lib", "formatting_utils.R"))
# Load output modules
source(file.path(script_dir, "lib", "output_formatting.R"))
source(file.path(script_dir, "lib", "tracker_output.R"))
source(file.path(script_dir, "lib", "tracker_dashboard_reports.R"))
# Load tracking crosstab modules
source(file.path(script_dir, "lib", "tracking_crosstab_engine.R"))
source(file.path(script_dir, "lib", "tracking_crosstab_excel.R"))
# Load HTML report modules
assign(".tracker_lib_dir", file.path(script_dir, "lib"), envir = globalenv())
source(file.path(script_dir, "lib", "html_report", "00_html_guard.R"))
source(file.path(script_dir, "lib", "html_report", "01_data_transformer.R"))
source(file.path(script_dir, "lib", "html_report", "02_table_builder.R"))
source(file.path(script_dir, "lib", "html_report", "05_chart_builder.R"))
source(file.path(script_dir, "lib", "html_report", "03_page_builder.R"))
source(file.path(script_dir, "lib", "html_report", "04_html_writer.R"))
source(file.path(script_dir, "lib", "html_report", "99_html_report_main.R"))

# Verify all required functions loaded successfully
verify_tracker_environment <- function() {
  required_functions <- c(
    "load_tracking_config",
    "load_question_mapping",
    "build_question_map_index",
    "validate_tracking_config",
    "load_all_waves",
    "validate_wave_data",
    "calculate_all_trends",
    "calculate_trends_with_banners",
    "write_tracker_output",
    "write_dashboard_output",
    "write_sig_matrix_output",
    "build_tracking_crosstab",
    "write_tracking_crosstab_output",
    "generate_tracker_html_report",
    "find_turas_root"
  )

  missing_functions <- character(0)
  for (func_name in required_functions) {
    if (!exists(func_name, mode = "function")) {
      missing_functions <- c(missing_functions, func_name)
    }
  }

  if (length(missing_functions) > 0) {
    # TRS Refusal: PKG_MISSING_FUNCTIONS
    tracker_refuse(
      code = "PKG_MISSING_FUNCTIONS",
      title = "Tracker Module Initialization Failed",
      problem = "Required functions are not loaded.",
      why_it_matters = "Tracker analysis cannot run without core functions.",
      how_to_fix = c(
        "Run from modules/tracker/ directory",
        "Or set TURAS_ROOT environment variable"
      ),
      missing = missing_functions
    )
  }

  # Verify shared formatting is accessible
  tryCatch({
    find_turas_root()
  }, error = function(e) {
    # TRS Refusal: CFG_TURAS_ROOT_NOT_FOUND
    tracker_refuse(
      code = "CFG_TURAS_ROOT_NOT_FOUND",
      title = "Turas Root Directory Not Found",
      problem = "Cannot locate Turas root directory and shared/formatting.R.",
      why_it_matters = "Tracker requires shared formatting functions to produce output.",
      how_to_fix = c(
        "Run from modules/tracker/ directory",
        "Or set TURAS_ROOT environment variable"
      ),
      details = e$message
    )
  })

  return(TRUE)
}

# Verify environment immediately after sourcing
verify_tracker_environment()


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
#' @param enable_html Logical or NULL. If TRUE, generate HTML report alongside Excel.
#'   If FALSE, skip HTML. If NULL (default), reads from config Settings sheet (html_report setting).
#'
#' @return Character. Path to generated Excel file
#'
#' @export
run_tracker <- function(tracking_config_path,
                        question_mapping_path,
                        data_dir = NULL,
                        output_path = NULL,
                        use_banners = FALSE,
                        enable_html = NULL) {

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

  # ===========================================================================
  # TRS v1.0: Initialize Run State
  # ===========================================================================
  trs_state <- if (exists("turas_run_state_new", mode = "function")) {
    turas_run_state_new("TRACKER")
  } else {
    NULL
  }

  # TRS v1.0: Start Banner
  if (exists("turas_banner_start", mode = "function")) {
    turas_banner_start("TRACKER", "2.2")
  } else {
    cat("================================================================================\n")
    cat(paste0("TURASTACKER - MVT ", phase_label, "\n"))
    cat("================================================================================\n")
    cat(paste0("Version: 2.2 (2025-12-11) - Enhanced Reports: Dashboard & Significance Matrix\n"))
    cat(paste0("Started: ", format(start_time, "%Y-%m-%d %H:%M:%S"), "\n"))
    cat("\n")
  }

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

  wave_load_result <- load_all_waves(config, data_dir, question_mapping)
  wave_data <- wave_load_result$wave_data
  wave_structures <- wave_load_result$wave_structures

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
    trend_calc_result <- calculate_trends_with_banners(
      config = config,
      question_map = question_map,
      wave_data = wave_data,
      wave_structures = wave_structures
    )
  } else {
    # Phase 2: Calculate simple trends (Total only)
    trend_calc_result <- calculate_all_trends(
      config = config,
      question_map = question_map,
      wave_data = wave_data,
      wave_structures = wave_structures
    )
    banner_segments <- NULL
  }

  # Extract the actual trends from the wrapper structure
  # calculate_all_trends returns: list(trends=..., skipped_questions=..., run_status=...)
  if (is.list(trend_calc_result) && "trends" %in% names(trend_calc_result)) {
    trend_results <- trend_calc_result$trends
    skipped_questions <- trend_calc_result$skipped_questions
    trend_run_status <- trend_calc_result$run_status
    cat(paste0("\n  Trends calculated for ", length(trend_results), " questions\n"))
    if (length(skipped_questions) > 0) {
      cat(paste0("  Skipped: ", length(skipped_questions), " questions\n"))
    }
  } else {
    # Backward compatibility: if already a simple list of trends
    trend_results <- trend_calc_result
    skipped_questions <- list()
    trend_run_status <- "PASS"
  }


  # ============================================================================
  # STEP 8: Write Excel Output
  # ============================================================================
  cat("\n[8/8] GENERATING OUTPUT\n")
  cat("================================================================================\n")

  # TRS v1.0: Extract run_result BEFORE output generation so Run_Status sheets have complete data
  run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else {
    NULL
  }

  # ===========================================================================
  # Resolve output directory and validate it exists
  # ===========================================================================
  # Priority: 1) output_path parameter, 2) output_dir setting, 3) config file directory
  base_output_dir <- if (!is.null(output_path)) {
    dirname(output_path)
  } else {
    output_dir_setting <- get_setting(config, "output_dir", default = NULL)
    if (!is.null(output_dir_setting) && nzchar(trimws(output_dir_setting))) {
      trimws(output_dir_setting)
    } else {
      dirname(config$config_path)
    }
  }

  # Ensure output directory exists (create if needed)
  if (!dir.exists(base_output_dir)) {
    cat(paste0("  Creating output directory: ", base_output_dir, "\n"))
    tryCatch({
      dir.create(base_output_dir, recursive = TRUE, showWarnings = FALSE)
    }, error = function(e) {
      warning(paste0("Could not create output directory: ", base_output_dir, ". Using config directory."))
      base_output_dir <<- dirname(config$config_path)
    })
  }

  # Check for output_file setting (used when single report type)
  output_file_setting <- get_setting(config, "output_file", default = NULL)

  cat(paste0("  Output directory: ", base_output_dir, "\n"))
  if (!is.null(output_file_setting) && nzchar(trimws(output_file_setting))) {
    cat(paste0("  Output file setting: ", output_file_setting, "\n"))
  }

  # Check report_types setting to determine which outputs to generate
  report_types_setting <- get_setting(config, "report_types", default = "detailed")

  # Parse comma-separated list and trim whitespace
  report_types <- trimws(strsplit(report_types_setting, ",")[[1]])

  # Validate report types
  valid_types <- c("detailed", "wave_history", "dashboard", "sig_matrix", "tracking_crosstab")
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
    detailed_path <- if (!is.null(output_path)) {
      # Explicit output_path parameter takes priority
      output_path
    } else if (length(report_types) == 1 && !is.null(output_file_setting) && nzchar(trimws(output_file_setting))) {
      # Single report type with output_file setting - use it directly
      file.path(base_output_dir, trimws(output_file_setting))
    } else {
      # Auto-generate filename
      project_name <- get_setting(config, "project_name", default = "Tracking")
      project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)
      file.path(base_output_dir, paste0(project_name, "_Tracker_", format(Sys.Date(), "%Y%m%d"), ".xlsx"))
    }

    output_files$detailed <- write_tracker_output(
      trend_results = trend_results,
      config = config,
      wave_data = wave_data,
      output_path = detailed_path,
      banner_segments = banner_segments,
      run_result = run_result
    )
  }

  if ("wave_history" %in% report_types) {
    # Generate wave history report
    wave_history_path <- if (length(report_types) == 1 && !is.null(output_file_setting) && nzchar(trimws(output_file_setting))) {
      # Single report type with output_file setting - use it directly
      file.path(base_output_dir, trimws(output_file_setting))
    } else {
      # Auto-generate filename
      project_name <- get_setting(config, "project_name", default = "Tracking")
      project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)
      file.path(base_output_dir, paste0(project_name, "_WaveHistory_", format(Sys.Date(), "%Y%m%d"), ".xlsx"))
    }

    output_files$wave_history <- write_wave_history_output(
      trend_results = trend_results,
      config = config,
      wave_data = wave_data,
      output_path = wave_history_path,
      banner_segments = banner_segments,
      run_result = run_result
    )
  }

  if ("dashboard" %in% report_types) {
    # Generate executive dashboard report
    dashboard_path <- if (length(report_types) == 1 && !is.null(output_file_setting) && nzchar(trimws(output_file_setting))) {
      # Single report type with output_file setting - use it directly
      file.path(base_output_dir, trimws(output_file_setting))
    } else {
      # Auto-generate filename
      project_name <- get_setting(config, "project_name", default = "Tracking")
      project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)
      file.path(base_output_dir, paste0(project_name, "_Dashboard_", format(Sys.Date(), "%Y%m%d"), ".xlsx"))
    }

    output_files$dashboard <- write_dashboard_output(
      trend_results = trend_results,
      config = config,
      wave_data = wave_data,
      output_path = dashboard_path,
      include_sig_matrices = TRUE,  # Dashboard includes sig matrices by default
      run_result = run_result
    )
  }

  if ("sig_matrix" %in% report_types) {
    # Generate significance matrix report (standalone, without dashboard)
    sig_matrix_path <- if (length(report_types) == 1 && !is.null(output_file_setting) && nzchar(trimws(output_file_setting))) {
      # Single report type with output_file setting - use it directly
      file.path(base_output_dir, trimws(output_file_setting))
    } else {
      # Auto-generate filename
      project_name <- get_setting(config, "project_name", default = "Tracking")
      project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)
      file.path(base_output_dir, paste0(project_name, "_SigMatrix_", format(Sys.Date(), "%Y%m%d"), ".xlsx"))
    }

    output_files$sig_matrix <- write_sig_matrix_output(
      trend_results = trend_results,
      config = config,
      wave_data = wave_data,
      output_path = sig_matrix_path,
      run_result = run_result
    )
  }

  # Determine if HTML report should be generated (check early — may need crosstab_data)
  if (!is.null(enable_html)) {
    generate_html <- isTRUE(enable_html)
  } else {
    html_report_setting <- get_setting(config, "html_report", default = "N")
    generate_html <- toupper(trimws(as.character(html_report_setting))) %in% c("Y", "YES", "TRUE", "1")
  }

  # Build crosstab data if needed for tracking_crosstab report OR HTML report
  needs_crosstab_data <- ("tracking_crosstab" %in% report_types) || generate_html
  crosstab_data <- NULL

  if (needs_crosstab_data) {
    cat("\n  Building tracking crosstab...\n")

    crosstab_data <- build_tracking_crosstab(
      trend_results = trend_results,
      config = config,
      question_map = question_map,
      banner_segments = banner_segments
    )
  }

  if ("tracking_crosstab" %in% report_types && !is.null(crosstab_data)) {
    # Excel output
    crosstab_path <- if (length(report_types) == 1 && !is.null(output_file_setting) && nzchar(trimws(output_file_setting))) {
      file.path(base_output_dir, trimws(output_file_setting))
    } else {
      project_name <- get_setting(config, "project_name", default = "Tracking")
      project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)
      file.path(base_output_dir, paste0(project_name, "_TrackingCrosstab_", format(Sys.Date(), "%Y%m%d"), ".xlsx"))
    }

    output_files$tracking_crosstab <- write_tracking_crosstab_output(
      crosstab_data = crosstab_data,
      config = config,
      output_path = crosstab_path,
      run_result = run_result
    )
  }

  # HTML report — generated independently of report_types when enable_html is TRUE
  if (generate_html && !is.null(crosstab_data)) {
    # Derive HTML path from crosstab Excel path (if it exists) or generate standalone
    if (!is.null(output_files$tracking_crosstab)) {
      html_path <- sub("\\.xlsx$", ".html", output_files$tracking_crosstab)
    } else {
      # No crosstab Excel — generate HTML path from project name
      project_name <- get_setting(config, "project_name", default = "Tracking")
      project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)
      html_path <- file.path(base_output_dir, paste0(project_name, "_TrackingReport_", format(Sys.Date(), "%Y%m%d"), ".html"))
    }

    html_result <- generate_tracker_html_report(
      crosstab_data = crosstab_data,
      config = config,
      output_path = html_path
    )
    if (html_result$status == "PASS") {
      output_files$tracking_html <- html_result$output_file
    } else {
      cat("\n  WARNING: HTML report generation failed\n")
      cat("  Code: ", html_result$code, "\n")
      cat("  Message: ", html_result$message, "\n")
    }
  }


  # ============================================================================
  # PHASE 2 COMPLETE - Analysis Complete
  # ============================================================================
  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  # ===========================================================================
  # TRS v1.0: Display Final Banner (run_result already extracted before output)
  # ===========================================================================

  # TRS v1.0: Final Banner
  if (exists("turas_banner_final", mode = "function") && !is.null(run_result)) {
    turas_banner_final("TRACKER", run_result)
  } else {
    cat("\n================================================================================\n")
    cat("TRACKING ANALYSIS COMPLETE\n")
    cat("================================================================================\n")
    cat(paste0("Completed: ", format(end_time, "%Y-%m-%d %H:%M:%S"), "\n"))
    cat(paste0("Elapsed time: ", round(elapsed, 1), " seconds\n"))
    cat("\n")
    cat("   Configuration loaded and validated\n")
    cat("   Question mapping indexed\n")
    cat("   Wave data loaded\n")
    cat(paste0("   Trends calculated for ", length(trend_results), " questions\n"))

    # Display output files
    if (length(output_files) > 0) {
      cat("   Output files generated:\n")
      for (report_type in names(output_files)) {
        cat(paste0("     - ", report_type, ": ", output_files[[report_type]], "\n"))
      }
    }

    cat("\n")
    cat("================================================================================\n\n")
  }

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
    # TRS Refusal: IO_TEMPLATE_NOT_FOUND
    tracker_refuse(
      code = "IO_TEMPLATE_NOT_FOUND",
      title = "Tracking Config Template Not Found",
      problem = paste0("Cannot find template file: ", basename(tracking_config_path)),
      why_it_matters = "Template files are required for testing.",
      how_to_fix = "Verify tracking_config_template.xlsx exists in the tracker module directory.",
      details = paste0("Expected path: ", tracking_config_path)
    )
  }

  if (!file.exists(question_mapping_path)) {
    # TRS Refusal: IO_TEMPLATE_NOT_FOUND
    tracker_refuse(
      code = "IO_TEMPLATE_NOT_FOUND",
      title = "Question Mapping Template Not Found",
      problem = paste0("Cannot find template file: ", basename(question_mapping_path)),
      why_it_matters = "Template files are required for testing.",
      how_to_fix = "Verify question_mapping_template.xlsx exists in the tracker module directory.",
      details = paste0("Expected path: ", question_mapping_path)
    )
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
