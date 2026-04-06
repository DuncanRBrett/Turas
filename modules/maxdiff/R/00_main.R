# ==============================================================================
# MAXDIFF MODULE - MAIN ORCHESTRATION - TURAS V10.0
# ==============================================================================
# Main entry point for MaxDiff design generation and analysis
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# WORKFLOW:
# DESIGN MODE:
#   1. Load configuration
#   2. Generate experimental design
#   3. Validate design quality
#   4. Output design file
#
# ANALYSIS MODE:
#   1. Load configuration
#   2. Load design file
#   3. Load and validate survey data
#   4. Reshape to long format
#   5. Compute count-based scores
#   6. Fit aggregate logit model
#   7. Fit HB model (if enabled)
#   8. Compute segment scores
#   9. Generate charts
#   10. Generate Excel output
#
# USAGE:
# source("R/00_main.R")
# run_maxdiff("path/to/config.xlsx")
#
# DEPENDENCIES:
# - All other module R scripts
# - openxlsx, survival, ggplot2
# - cmdstanr (optional, for HB)
# ==============================================================================

MAXDIFF_VERSION <- "11.1"

# ==============================================================================
# TRS GUARD LAYER (Must be first)
# ==============================================================================

# Source TRS guard layer for refusal handling
.get_script_dir_for_guard <- function() {
  if (exists("script_dir_override", envir = globalenv())) {
    return(get("script_dir_override", envir = globalenv()))
  }
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) return(dirname(sub("^--file=", "", file_arg)))
  return(getwd())
}

.guard_path <- file.path(.get_script_dir_for_guard(), "00_guard.R")
if (!file.exists(.guard_path)) {
  .guard_path <- file.path(.get_script_dir_for_guard(), "R", "00_guard.R")
}
if (file.exists(.guard_path)) {
  source(.guard_path)
}

# ==============================================================================
# TRS INFRASTRUCTURE (TRS v1.0)
# ==============================================================================

# Source TRS run state management
.source_trs_infrastructure <- function() {
  base_dir <- .get_script_dir_for_guard()

  # Try multiple paths to find shared/lib
  possible_paths <- c(
    file.path(base_dir, "..", "..", "shared", "lib"),
    file.path(base_dir, "..", "shared", "lib"),
    file.path(getwd(), "modules", "shared", "lib"),
    file.path(getwd(), "..", "shared", "lib")
  )

  trs_files <- c("trs_run_state.R", "trs_banner.R", "trs_run_status_writer.R",
                 "stats_pack_writer.R")

  for (shared_lib in possible_paths) {
    if (dir.exists(shared_lib)) {
      for (f in trs_files) {
        fpath <- file.path(shared_lib, f)
        if (file.exists(fpath)) {
          source(fpath)
        }
      }
      break
    }
  }
}

tryCatch({
  .source_trs_infrastructure()
}, error = function(e) {
  message(sprintf("[TRS INFO] MAXD_TRS_LOAD: Could not load TRS infrastructure: %s", e$message))
})

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

# Get script directory for sourcing
get_script_dir <- function() {
  # Check for manual override
  if (exists("script_dir_override", envir = globalenv())) {
    return(get("script_dir_override", envir = globalenv()))
  }

  # Method 1: Try to find from source() call stack using srcfile
  # This is the most reliable method when file is being sourced
  for (i in seq_len(sys.nframe())) {
    srcfile <- tryCatch({
      sys.frame(i)$srcfile
    }, error = function(e) NULL)

    # Safely check srcfile - must be a list/environment with $filename
    if (!is.null(srcfile) && is.list(srcfile) && !is.null(srcfile$filename)) {
      script_path <- srcfile$filename
      if (grepl("00_main\\.R$", script_path)) {
        return(dirname(normalizePath(script_path, mustWork = FALSE)))
      }
    }

    # Also try ofile attribute - must be character
    ofile <- tryCatch({
      sys.frame(i)$ofile
    }, error = function(e) NULL)

    if (!is.null(ofile) && is.character(ofile) && length(ofile) == 1 && grepl("00_main\\.R$", ofile)) {
      return(dirname(normalizePath(ofile, mustWork = FALSE)))
    }
  }

  # Method 2: Try to get from command line args (Rscript)
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)

  if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg)
    return(dirname(normalizePath(script_path, mustWork = FALSE)))
  }

  # Method 3: Try rstudioapi
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    if (rstudioapi::isAvailable()) {
      script_path <- tryCatch({
        rstudioapi::getSourceEditorContext()$path
      }, error = function(e) NULL)

      if (!is.null(script_path) && nzchar(script_path)) {
        return(dirname(script_path))
      }
    }
  }

  # Method 4: Look for module in common locations relative to working directory
  possible_paths <- c(
    file.path(getwd(), "modules", "maxdiff", "R"),
    file.path(getwd(), "R"),
    file.path(dirname(getwd()), "modules", "maxdiff", "R"),
    getwd()
  )

  for (path in possible_paths) {
    if (file.exists(file.path(path, "utils.R"))) {
      return(path)
    }
  }

  # Default to current directory
  return(getwd())
}


# Source all module files
source_module_files <- function(base_dir = NULL) {

  if (is.null(base_dir)) {
    base_dir <- get_script_dir()
  }

  # List of files to source in order
  module_files <- c(
    "utils.R",
    "01_config.R",
    "02_validation.R",
    "03_data.R",
    "04_design.R",
    "05_counts.R",
    "06_logit.R",
    "07_hb.R",
    "08_segments.R",
    "09_output.R",
    "10_charts.R",
    "11_turf.R"
  )

  for (file in module_files) {
    file_path <- file.path(base_dir, file)

    if (!file.exists(file_path)) {
      # Try R subdirectory
      file_path <- file.path(base_dir, "R", file)
    }

    if (!file.exists(file_path)) {
      maxdiff_refuse(
        code = "IO_MODULE_FILE_NOT_FOUND",
        title = "Module File Not Found",
        problem = sprintf("Required module file not found: %s", file),
        why_it_matters = "All module files must be present for MaxDiff to function",
        how_to_fix = c(
          "Ensure all R files are in the modules/maxdiff/R directory",
          "Verify complete module installation",
          "Re-download or reinstall module if files are missing"
        ),
        details = sprintf("Looking for: %s", file)
      )
    }

    source(file_path)
  }
}

# Source all modules
tryCatch({
  source_module_files()
}, error = function(e) {
  maxdiff_refuse(
    code = "IO_MODULE_LOAD_FAILED",
    title = "Failed to Load Module Files",
    problem = sprintf("Error loading module files: %s", conditionMessage(e)),
    why_it_matters = "All module files must load successfully for MaxDiff to function",
    how_to_fix = c(
      "Check all R files are in modules/maxdiff/R directory",
      "Verify no syntax errors in module files",
      "Ensure file permissions allow reading",
      "Check R version compatibility"
    ),
    details = conditionMessage(e)
  )
})


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Run MaxDiff Module
#'
#' Main entry point for MaxDiff design generation or analysis.
#' Automatically determines mode from configuration file.
#'
#' @param config_path Character. Path to configuration Excel file
#' @param project_root Character. Project root directory (optional)
#' @param verbose Logical. Print progress messages (default: TRUE)
#'
#' @return List with results (design or analysis outputs)
#'
#' @examples
#' # Design mode
#' run_maxdiff("config/maxdiff_config.xlsx")  # Mode = DESIGN in config
#'
#' # Analysis mode
#' run_maxdiff("config/maxdiff_config.xlsx")  # Mode = ANALYSIS in config
#'
#' @export
run_maxdiff <- function(config_path, project_root = NULL, verbose = TRUE) {

  # ==========================================================================
  # TRS REFUSAL HANDLER WRAPPER (TRS v1.0)
  # ==========================================================================

  if (exists("maxdiff_with_refusal_handler", mode = "function")) {
    maxdiff_with_refusal_handler(
      run_maxdiff_impl(config_path, project_root, verbose)
    )
  } else {
    run_maxdiff_impl(config_path, project_root, verbose)
  }
}


#' Internal Implementation of MaxDiff Analysis
#'
#' @keywords internal
run_maxdiff_impl <- function(config_path, project_root = NULL, verbose = TRUE) {

  # ==========================================================================
  # TRS RUN STATE INITIALIZATION (TRS v1.0)
  # ==========================================================================

  # Create TRS run state for tracking events
  trs_state <- if (exists("turas_run_state_new", mode = "function")) {
    turas_run_state_new("MAXDIFF")
  } else {
    NULL
  }

  # Print TRS start banner
  if (exists("turas_print_start_banner", mode = "function")) {
    turas_print_start_banner("MAXDIFF", MAXDIFF_VERSION)
  } else if (verbose) {
    cat("\n")
    cat("================================================================================\n")
    cat("TURAS MAXDIFF MODULE\n")
    cat(sprintf("Version: %s\n", MAXDIFF_VERSION))
    cat(sprintf("Started: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
    cat("================================================================================\n\n")
  }

  # Start timer
  start_time <- Sys.time()

  # ==========================================================================
  # STEP 1: LOAD CONFIGURATION
  # ==========================================================================

  if (verbose) cat("STEP 1: Loading configuration...\n")

  config <- tryCatch({
    load_maxdiff_config(config_path, project_root)
  }, error = function(e) {
    maxdiff_refuse(
      code = "CFG_LOAD_FAILED",
      title = "Failed to Load Configuration",
      problem = sprintf("Error loading configuration file: %s", conditionMessage(e)),
      why_it_matters = "Valid configuration is required to run MaxDiff analysis",
      how_to_fix = c(
        "Check configuration Excel file is valid",
        "Verify all required sheets exist",
        "Ensure configuration values are correct types",
        "Review error message for specific issue"
      ),
      details = conditionMessage(e)
    )
  })

  if (verbose) {
    cat(sprintf("  Project: %s\n", config$project_settings$Project_Name))
    cat(sprintf("  Mode: %s\n", config$mode))
    cat(sprintf("  Items: %d\n", sum(config$items$Include == 1)))
  }

  # ==========================================================================
  # DISPATCH TO APPROPRIATE MODE
  # ==========================================================================

  results <- if (config$mode == "DESIGN") {
    run_maxdiff_design_mode(config, verbose, trs_state)
  } else if (config$mode == "ANALYSIS") {
    run_maxdiff_analysis_mode(config, verbose, trs_state)
  } else {
    maxdiff_refuse(
      code = "CFG_INVALID_MODE",
      title = "Invalid Mode",
      problem = sprintf("Unrecognised mode: '%s'", config$mode),
      why_it_matters = "Mode must be DESIGN or ANALYSIS",
      how_to_fix = "Set Mode to DESIGN or ANALYSIS in the PROJECT_SETTINGS sheet"
    )
  }

  # ==========================================================================
  # SUMMARY
  # ==========================================================================

  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))
  all_warnings <- results$warnings %||% character()

  # ==========================================================================
  # TRS: Get run result (use from results if already created in mode function)
  # ==========================================================================
  run_result <- if (!is.null(results$run_result)) {
    results$run_result
  } else if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else {
    NULL
  }

  if (verbose) {
    cat("\n")
    cat(sprintf("Finished: %s\n", format(end_time, "%Y-%m-%d %H:%M:%S")))
    cat(sprintf("Elapsed time: %.1f seconds\n", elapsed))
    if (!is.null(results$output_path)) {
      cat(sprintf("Output file: %s\n", results$output_path))
    }
  }

  # ==========================================================================
  # TRS FINAL BANNER (TRS v1.0)
  # ==========================================================================
  if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
    turas_print_final_banner(run_result)
  } else if (verbose) {
    cat("================================================================================\n")
    if (length(all_warnings) == 0) {
      cat("[TRS PASS] MAXDIFF - MODULE COMPLETED SUCCESSFULLY\n")
    } else {
      cat(sprintf("[TRS PARTIAL] MAXDIFF - MODULE COMPLETED WITH %d WARNING(S)\n", length(all_warnings)))
    }
    cat("================================================================================\n\n")
  }

  # ==========================================================================
  # STATS PACK (Optional — analysis mode only)
  # ==========================================================================

  if (config$mode == "ANALYSIS") {
    generate_stats_pack_flag <- isTRUE(
      toupper(config$project_settings$Generate_Stats_Pack %||% "Y") == "Y"
    ) || isTRUE(getOption("turas.generate_stats_pack", FALSE))

    if (generate_stats_pack_flag) {
      if (verbose) cat("\nGenerating stats pack...\n")
      results$stats_pack <- generate_maxdiff_stats_pack(
        config       = config,
        results      = results,
        run_result   = run_result,
        start_time   = start_time,
        verbose      = verbose
      )
    } else {
      if (verbose) cat("\nStats pack skipped (set Generate_Stats_Pack = Y in config to enable)\n")
    }
  }

  results$elapsed_seconds <- elapsed
  results$config <- config
  results$run_result <- run_result

  invisible(results)
}


# ==============================================================================
# DESIGN MODE
# ==============================================================================

#' Run MaxDiff Design Mode
#'
#' Generates experimental design for MaxDiff study.
#'
#' @param config Configuration object
#' @param verbose Print progress
#' @param trs_state TRS run state object (optional)
#'
#' @return List with design results
#' @keywords internal
run_maxdiff_design_mode <- function(config, verbose = TRUE, trs_state = NULL) {

  if (verbose) {
    cat("\n")
    cat("--------------------------------------------------------------------------------\n")
    cat("DESIGN MODE\n")
    cat("--------------------------------------------------------------------------------\n")
  }

  # ==========================================================================
  # STEP 2: GENERATE DESIGN
  # ==========================================================================

  if (verbose) cat("\nSTEP 2: Generating experimental design...\n")

  design_result <- tryCatch({
    generate_maxdiff_design(
      items = config$items,
      design_settings = config$design_settings,
      seed = config$project_settings$Seed,
      verbose = verbose
    )
  }, error = function(e) {
    maxdiff_refuse(
      code = "MODEL_DESIGN_FAILED",
      title = "Design Generation Failed",
      problem = sprintf("Error generating experimental design: %s", conditionMessage(e)),
      why_it_matters = "Valid experimental design is required for MaxDiff study",
      how_to_fix = c(
        "Check design settings are valid",
        "Verify Items_Per_Task is not too large",
        "Try different Design_Type (BALANCED, OPTIMAL, or RANDOM)",
        "Ensure sufficient items are included"
      ),
      details = conditionMessage(e)
    )
  })

  # ==========================================================================
  # STEP 3: VALIDATE DESIGN
  # ==========================================================================

  if (verbose) cat("\nSTEP 3: Validating design...\n")

  validation <- validate_design(
    design = design_result$design,
    items = config$items,
    verbose = verbose
  )

  if (!validation$valid) {
    message(sprintf(
      "[TRS INFO] MAXD_DESIGN_VALIDATION: Design validation found %d issues: %s",
      length(validation$issues),
      paste(validation$issues, collapse = "; ")
    ))
  }

  # ==========================================================================
  # STEP 4: GENERATE OUTPUT
  # ==========================================================================

  if (verbose) cat("\nSTEP 4: Generating output...\n")

  output_path <- NULL

  if (config$output_settings$Generate_Design_File) {
    output_path <- generate_design_output(design_result, config, verbose)
  }

  list(
    mode = "DESIGN",
    design_result = design_result,
    validation = validation,
    output_path = output_path
  )
}


# ==============================================================================
# ANALYSIS MODE
# ==============================================================================

#' Run MaxDiff Analysis Mode
#'
#' Performs complete MaxDiff analysis workflow.
#'
#' @param config Configuration object
#' @param verbose Print progress
#' @param trs_state TRS run state object (optional)
#'
#' @return List with analysis results
#' @keywords internal
run_maxdiff_analysis_mode <- function(config, verbose = TRUE, trs_state = NULL) {

  if (verbose) {
    cat("\n")
    cat("--------------------------------------------------------------------------------\n")
    cat("ANALYSIS MODE\n")
    cat("--------------------------------------------------------------------------------\n")
  }

  # Use an environment for warnings_list so tryCatch error handlers can append
  # (plain <- inside error handler creates a local copy that is discarded)
  .warn_env <- new.env(parent = emptyenv())
  .warn_env$warnings_list <- character()
  add_warning <- function(msg) .warn_env$warnings_list <- c(.warn_env$warnings_list, msg)

  # ==========================================================================
  # STEP 2: LOAD DESIGN FILE
  # ==========================================================================

  if (verbose) cat("\nSTEP 2: Loading design file...\n")

  design <- tryCatch({
    load_design_file(config$project_settings$Design_File, verbose)
  }, error = function(e) {
    maxdiff_refuse(
      code = "IO_DESIGN_LOAD_FAILED",
      title = "Failed to Load Design File",
      problem = sprintf("Error loading design file: %s", conditionMessage(e)),
      why_it_matters = "Design file is required to map survey responses to items",
      how_to_fix = c(
        "Check design file path is correct",
        "Verify file is valid Excel format",
        "Ensure DESIGN sheet exists in workbook",
        "Re-generate design file if corrupted"
      ),
      details = conditionMessage(e)
    )
  })

  # ==========================================================================
  # STEP 3: LOAD SURVEY DATA
  # ==========================================================================

  if (verbose) cat("\nSTEP 3: Loading survey data...\n")

  raw_data <- tryCatch({
    load_survey_data(
      file_path = config$project_settings$Raw_Data_File,
      sheet = config$project_settings$Data_File_Sheet,
      verbose = verbose
    )
  }, error = function(e) {
    maxdiff_refuse(
      code = "IO_DATA_LOAD_FAILED",
      title = "Failed to Load Survey Data",
      problem = sprintf("Error loading survey data file: %s", conditionMessage(e)),
      why_it_matters = "Survey data is required for MaxDiff analysis",
      how_to_fix = c(
        "Check data file path is correct",
        "Verify file format is CSV or Excel",
        "Ensure file is not corrupted or locked",
        "Check file has correct sheet name (if Excel)"
      ),
      details = conditionMessage(e)
    )
  })

  # Apply filter if specified
  if (!is.null(config$project_settings$Filter_Expression)) {
    raw_data <- apply_filter_expression(
      raw_data,
      config$project_settings$Filter_Expression,
      verbose
    )
  }

  # ==========================================================================
  # STEP 4: VALIDATE DATA
  # ==========================================================================

  if (verbose) cat("\nSTEP 4: Validating data...\n")

  data_validation <- validate_survey_data(
    data = raw_data,
    survey_mapping = config$survey_mapping,
    design = design,
    items = config$items,
    verbose = verbose
  )

  if (!data_validation$valid) {
    maxdiff_refuse(
      code = "DATA_VALIDATION_FAILED",
      title = "Data Validation Failed",
      problem = "Survey data failed validation checks",
      why_it_matters = "Data must pass validation before analysis can proceed",
      how_to_fix = c(
        "Review validation issues listed below",
        "Check survey mapping matches data columns",
        "Verify design matches survey structure",
        "Ensure data has required fields and valid values"
      ),
      details = paste(data_validation$issues, collapse = "\n  ")
    )
  }

  add_warning( data_validation$warnings)

  # ==========================================================================
  # STEP 5: RESHAPE TO LONG FORMAT
  # ==========================================================================

  if (verbose) cat("\nSTEP 5: Reshaping data to long format...\n")

  long_data <- tryCatch({
    build_maxdiff_long(
      data = raw_data,
      survey_mapping = config$survey_mapping,
      design = design,
      config = config,
      verbose = verbose
    )
  }, error = function(e) {
    maxdiff_refuse(
      code = "DATA_RESHAPE_FAILED",
      title = "Data Reshaping Failed",
      problem = sprintf("Error converting data to long format: %s", conditionMessage(e)),
      why_it_matters = "Long format data is required for all MaxDiff analyses",
      how_to_fix = c(
        "Check survey mapping is correct",
        "Verify column names match mapping",
        "Ensure design and data are compatible",
        "Check for missing or invalid response values"
      ),
      details = conditionMessage(e)
    )
  })

  # Compute study summary
  study_summary <- compute_study_summary(long_data, config, verbose)

  # ==========================================================================
  # STEPS 6-10D: OPTIONAL ANALYSES (PARTIAL on failure)
  # ==========================================================================

  optional <- run_maxdiff_optional_analyses(
    long_data = long_data,
    raw_data = raw_data,
    config = config,
    study_summary = study_summary,
    add_warning = add_warning,
    verbose = verbose
  )

  # ==========================================================================
  # STEPS 11-13: OUTPUT GENERATION
  # ==========================================================================

  results <- run_maxdiff_generate_outputs(
    design = design,
    long_data = long_data,
    raw_data = raw_data,
    study_summary = study_summary,
    optional = optional,
    config = config,
    trs_state = trs_state,
    add_warning = add_warning,
    warnings_list = .warn_env$warnings_list,
    verbose = verbose
  )

  # Warnings summary
  if (length(.warn_env$warnings_list) > 0 && verbose) {
    cat("\n")
    cat("WARNINGS:\n")
    for (i in seq_along(.warn_env$warnings_list)) {
      cat(sprintf("  %d. %s\n", i, .warn_env$warnings_list[i]))
    }
  }

  return(results)
}


# ==============================================================================
# STATS PACK HELPER
# ==============================================================================

#' Generate MaxDiff Stats Pack
#'
#' Builds the diagnostic payload from MaxDiff analysis results and writes the
#' stats pack Excel workbook alongside the main output.
#'
#' @keywords internal
generate_maxdiff_stats_pack <- function(config, results, run_result,
                                         start_time, verbose) {

  if (!exists("turas_write_stats_pack", mode = "function")) {
    if (verbose) cat("  ! Stats pack writer not loaded - skipping\n")
    return(NULL)
  }

  # Output path: same base as main output with _stats_pack suffix
  main_out    <- results$output_path %||% config$project_settings$Output_File %||% "maxdiff_output.xlsx"
  output_path <- sub("(\\.xlsx)$", "_stats_pack.xlsx", main_out, ignore.case = TRUE)
  if (identical(output_path, main_out)) {
    output_path <- paste0(tools::file_path_sans_ext(main_out), "_stats_pack.xlsx")
  }

  # Data sizes
  raw_data       <- results$raw_data
  n_respondents  <- if (!is.null(raw_data)) nrow(raw_data) else 0L
  n_cols         <- if (!is.null(raw_data)) ncol(raw_data) else 0L
  items_df       <- config$items %||% data.frame()
  n_items        <- sum(items_df$Include == 1, na.rm = TRUE)

  # Design info
  design_df      <- results$design %||% data.frame()
  tasks_per_resp <- if (nrow(design_df) > 0 && "Task" %in% names(design_df)) {
    max(design_df$Task, na.rm = TRUE)
  } else NA

  # Model settings
  has_hb      <- !is.null(results$hb_results)
  has_logit   <- !is.null(results$logit_results)
  method_str  <- if (has_hb) {
    "HB (ChoiceModelR package)"
  } else if (has_logit) {
    "Aggregate logit"
  } else {
    "Count scores only"
  }
  hb_iters    <- if (has_hb) {
    as.character(config$output_settings$HB_Iterations %||% config$project_settings$HB_Iterations %||% "—")
  } else "N/A"
  seed_val    <- as.character(config$project_settings$Seed %||% "Not set")
  turf_flag   <- !is.null(results$turf_results)

  # TRS summary
  n_events   <- length(run_result$events %||% list())
  n_refusals <- sum(vapply(run_result$events %||% list(),
                           function(e) identical(e$level, "REFUSE"), logical(1)))
  n_partials <- sum(vapply(run_result$events %||% list(),
                           function(e) identical(e$level, "PARTIAL"), logical(1)))
  trs_summary <- if (n_events == 0) {
    "No events — ran cleanly"
  } else {
    parts <- character(0)
    if (n_refusals > 0) parts <- c(parts, sprintf("%d refusal(s)", n_refusals))
    if (n_partials > 0) parts <- c(parts, sprintf("%d partial(s)", n_partials))
    remainder <- n_events - n_refusals - n_partials
    if (remainder  > 0) parts <- c(parts, sprintf("%d info event(s)", remainder))
    paste(parts, collapse = ", ")
  }

  assumptions <- list(
    "Items"                = as.character(n_items),
    "Tasks per respondent" = if (!is.na(tasks_per_resp)) as.character(tasks_per_resp) else "—",
    "Method"               = method_str,
    "HB Iterations"        = hb_iters,
    "Seed"                 = seed_val,
    "TURF Analysis"        = if (turf_flag) "Enabled" else "Disabled",
    "TRS Status"           = run_result$status %||% "PASS",
    "TRS Events"           = trs_summary
  )

  data_receipt <- list(
    file_name           = basename(config$project_settings$Raw_Data_File %||% "unknown"),
    n_rows              = n_respondents,
    n_cols              = n_cols,
    questions_in_config = n_items
  )

  data_used <- list(
    n_respondents      = n_respondents,
    n_excluded         = 0L,
    weighted           = !is.null(config$project_settings$Weight_Variable),
    questions_analysed = n_items,
    questions_skipped  = 0L
  )

  duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  payload <- list(
    module           = "MAXDIFF",
    project_name     = config$project_settings$Project_Name %||% NULL,
    analyst_name     = config$project_settings$Analyst_Name %||% NULL,
    research_house   = config$project_settings$Research_House %||% NULL,
    run_timestamp    = start_time,
    turas_version    = MAXDIFF_VERSION,
    r_version        = R.version$version.string,
    status           = run_result$status %||% "PASS",
    duration_seconds = duration_secs,
    data_receipt     = data_receipt,
    data_used        = data_used,
    assumptions      = assumptions,
    run_result       = run_result,
    packages         = c("openxlsx", "survival", "ChoiceModelR"),
    config_echo      = list(
      project_settings = config$project_settings,
      output_settings  = config$output_settings
    )
  )

  result <- turas_write_stats_pack(payload, output_path)

  if (!is.null(result) && verbose) {
    cat(sprintf("  Stats pack written: %s\n", basename(output_path)))
  }

  result
}


# ==============================================================================
# CONVENIENCE FUNCTIONS
# ==============================================================================

#' Quick MaxDiff Analysis
#'
#' Convenience wrapper for run_maxdiff with default settings.
#'
#' @param config_path Path to configuration file
#'
#' @export
quick_maxdiff <- function(config_path) {
  run_maxdiff(config_path, verbose = TRUE)
}


#' Run MaxDiff Design Only
#'
#' @param config_path Path to configuration file
#'
#' @export
run_maxdiff_design <- function(config_path) {
  config <- load_maxdiff_config(config_path)
  config$mode <- "DESIGN"  # Force design mode
  run_maxdiff_design_mode(config, verbose = TRUE)
}


#' Run MaxDiff Analysis Only
#'
#' @param config_path Path to configuration file
#'
#' @export
run_maxdiff_analysis <- function(config_path) {
  config <- load_maxdiff_config(config_path)
  config$mode <- "ANALYSIS"  # Force analysis mode
  run_maxdiff_analysis_mode(config, verbose = TRUE)
}


# ==============================================================================
# HELPER: Run Optional Analyses (Steps 6-10D)
# ==============================================================================

#' Run MaxDiff Optional Analyses
#'
#' Executes all optional/additive analysis steps: count scores, logit,
#' HB, segments, charts, TURF, anchored MaxDiff, and discrimination.
#' Each step uses tryCatch for PARTIAL status on failure.
#'
#' @param long_data Long-format survey data
#' @param raw_data Original wide-format data
#' @param config Configuration list
#' @param study_summary Study summary from Step 5
#' @param add_warning Function to accumulate warnings
#' @param verbose Logical; whether to print progress
#' @return List with all optional analysis results
#' @keywords internal
run_maxdiff_optional_analyses <- function(long_data, raw_data, config,
                                          study_summary, add_warning,
                                          verbose = TRUE) {

  # Step 6: Count scores
  count_scores <- NULL
  if (config$output_settings$Generate_Count_Scores) {
    if (verbose) cat("\nSTEP 6: Computing count-based scores...\n")
    count_scores <- tryCatch({
      compute_maxdiff_counts(
        long_data = long_data,
        items = config$items,
        weighted = !is.null(config$project_settings$Weight_Variable),
        verbose = verbose
      )
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] MAXD_COUNT_SCORE_FAILED: Count score computation failed: %s", conditionMessage(e)))
      add_warning(sprintf("Count scores: %s", conditionMessage(e)))
      NULL
    })
  }

  # Step 7: Aggregate logit
  logit_results <- NULL
  if (config$output_settings$Generate_Aggregate_Logit) {
    if (verbose) cat("\nSTEP 7: Fitting aggregate logit model...\n")
    logit_results <- tryCatch({
      if (requireNamespace("survival", quietly = TRUE)) {
        fit_aggregate_logit(long_data = long_data, items = config$items,
                            weighted = !is.null(config$project_settings$Weight_Variable),
                            verbose = verbose)
      } else {
        fit_simple_logit(long_data, config$items, verbose)
      }
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] MAXD_LOGIT_FAILED: Logit model failed: %s", conditionMessage(e)))
      add_warning(sprintf("Logit model: %s", conditionMessage(e)))
      NULL
    })
    if (!is.null(logit_results) && !is.null(count_scores)) {
      count_scores <- merge(count_scores,
        logit_results$utilities[, c("Item_ID", "Logit_Utility", "Logit_SE")],
        by = "Item_ID", all.x = TRUE)
    }
  }

  # Step 8: Hierarchical Bayes
  hb_results <- NULL
  if (config$output_settings$Generate_HB_Model) {
    if (verbose) cat("\nSTEP 8: Fitting Hierarchical Bayes model...\n")
    hb_results <- tryCatch({
      fit_hb_model(long_data = long_data, items = config$items,
                   config = config, verbose = verbose)
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] MAXD_HB_FAILED: HB model failed: %s", conditionMessage(e)))
      add_warning(sprintf("HB model: %s", conditionMessage(e)))
      NULL
    })
    if (!is.null(hb_results) && !is.null(count_scores)) {
      count_scores <- merge(count_scores,
        hb_results$population_utilities[, c("Item_ID", "HB_Utility_Mean", "HB_Utility_SD")],
        by = "Item_ID", all.x = TRUE)
    }
  }

  # Step 9: Segment scores
  segment_results <- NULL
  if (config$output_settings$Generate_Segment_Tables &&
      !is.null(config$segment_settings) &&
      nrow(config$segment_settings) > 0) {
    if (verbose) cat("\nSTEP 9: Computing segment-level scores...\n")
    segment_results <- tryCatch({
      compute_segment_scores(long_data = long_data, raw_data = raw_data,
                             segment_settings = config$segment_settings,
                             items = config$items,
                             output_settings = config$output_settings,
                             verbose = verbose)
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] MAXD_SEGMENT_FAILED: Segment analysis failed: %s", conditionMessage(e)))
      add_warning(sprintf("Segments: %s", conditionMessage(e)))
      NULL
    })
  }

  # Step 10: Charts
  chart_paths <- NULL
  if (config$output_settings$Generate_Charts) {
    if (verbose) cat("\nSTEP 10: Generating charts...\n")
    results_for_charts <- list(
      count_scores = count_scores, logit_results = logit_results,
      hb_results = hb_results, segment_results = segment_results,
      study_summary = study_summary
    )
    chart_paths <- tryCatch({
      generate_maxdiff_charts(results_for_charts, config, verbose)
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] MAXD_CHART_FAILED: Chart generation failed: %s", conditionMessage(e)))
      add_warning(sprintf("Charts: %s", conditionMessage(e)))
      NULL
    })
  }

  # Step 10B: TURF
  turf_results <- NULL
  generate_turf <- parse_yes_no(config$output_settings$Generate_TURF %||% FALSE)
  if (generate_turf && !is.null(hb_results$individual_utilities)) {
    if (verbose) cat("\nSTEP 10B: Running TURF analysis...\n")
    turf_results <- tryCatch({
      turf_max <- safe_integer(config$output_settings$TURF_Max_Items %||% 10, default = 10L)
      turf_method <- config$output_settings$TURF_Threshold %||% "ABOVE_MEAN"
      run_turf_analysis(individual_utils = hb_results$individual_utilities,
                        items = config$items, max_items = turf_max,
                        threshold_method = turf_method, verbose = verbose)
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] MAXD_TURF_FAILED: TURF analysis failed: %s", conditionMessage(e)))
      add_warning(sprintf("TURF: %s", conditionMessage(e)))
      NULL
    })
  }

  # Step 10C: Anchored MaxDiff
  anchor_data <- NULL
  has_anchor <- parse_yes_no(config$output_settings$Has_Anchor_Question %||% FALSE)
  if (has_anchor) {
    if (verbose) cat("\nSTEP 10C: Processing anchor data...\n")
    anchor_var <- config$output_settings$Anchor_Variable %||% NULL
    anchor_threshold <- safe_numeric(config$output_settings$Anchor_Threshold %||% 0.50, default = 0.50)
    anchor_format <- config$output_settings$Anchor_Format %||% "COMMA_SEPARATED"
    anchor_data <- tryCatch({
      process_anchor_data(raw_data = raw_data, anchor_variable = anchor_var,
                          items = config$items,
                          id_variable = config$project_settings$Respondent_ID_Variable,
                          anchor_format = anchor_format,
                          anchor_threshold = anchor_threshold)
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] MAXD_ANCHOR_FAILED: Anchor processing failed: %s", conditionMessage(e)))
      add_warning(sprintf("Anchor: %s", conditionMessage(e)))
      NULL
    })
  }

  # Step 10D: Item discrimination
  discrimination_data <- NULL
  if (!is.null(hb_results$individual_utilities)) {
    if (verbose) cat("\nSTEP 10D: Computing item discrimination...\n")
    discrimination_data <- tryCatch({
      classify_item_discrimination(hb_results$individual_utilities, config$items)
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] MAXD_DISC_FAILED: Item discrimination failed: %s", conditionMessage(e)))
      NULL
    })
  }

  list(
    count_scores = count_scores,
    logit_results = logit_results,
    hb_results = hb_results,
    segment_results = segment_results,
    chart_paths = chart_paths,
    turf_results = turf_results,
    anchor_data = anchor_data,
    discrimination_data = discrimination_data
  )
}


# ==============================================================================
# HELPER: Generate Outputs (Steps 11-13)
# ==============================================================================

#' Generate MaxDiff Outputs
#'
#' Handles TRS logging, Excel output, optional simulator, and optional
#' HTML report generation.
#'
#' @param design Design object
#' @param long_data Long-format data
#' @param raw_data Original wide-format data
#' @param study_summary Study summary
#' @param optional List of optional analysis results from run_maxdiff_optional_analyses
#' @param config Configuration list
#' @param trs_state TRS run state (or NULL)
#' @param add_warning Function to accumulate warnings
#' @param warnings_list Current warnings list
#' @param verbose Logical
#' @return Results list with output paths
#' @keywords internal
run_maxdiff_generate_outputs <- function(design, long_data, raw_data,
                                          study_summary, optional, config,
                                          trs_state, add_warning,
                                          warnings_list, verbose = TRUE) {

  # TRS: Log PARTIAL events
  if (!is.null(trs_state) && length(warnings_list) > 0) {
    for (warn in warnings_list) {
      if (exists("turas_run_state_partial", mode = "function")) {
        turas_run_state_partial(trs_state, "MAXD_WARNING", "Analysis warning", problem = warn)
      }
    }
  }

  run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else {
    NULL
  }

  # Step 11: Excel output
  if (verbose) cat("\nSTEP 11: Generating Excel output...\n")

  results <- list(
    mode = "ANALYSIS",
    design = design,
    long_data = long_data,
    raw_data = raw_data,
    study_summary = study_summary,
    count_scores = optional$count_scores,
    logit_results = optional$logit_results,
    hb_results = optional$hb_results,
    segment_results = optional$segment_results,
    turf_results = optional$turf_results,
    anchor_data = optional$anchor_data,
    discrimination_data = optional$discrimination_data,
    chart_paths = optional$chart_paths,
    warnings = warnings_list,
    run_result = run_result
  )

  output_path <- tryCatch({
    generate_maxdiff_output(results, config, verbose, run_result)
  }, error = function(e) {
    message(sprintf("[TRS PARTIAL] MAXD_OUTPUT_FAILED: Output generation failed: %s", conditionMessage(e)))
    NULL
  })
  results$output_path <- output_path

  # Step 12: Simulator
  generate_sim <- parse_yes_no(config$output_settings$Generate_Simulator %||% FALSE)
  generate_html <- parse_yes_no(config$output_settings$Generate_HTML_Report %||% FALSE)
  simulator_html <- NULL

  if (generate_sim && !is.null(output_path)) {
    if (verbose) cat("\nSTEP 12: Generating interactive simulator...\n")
    tryCatch({
      sim_main <- find_module_file("lib/html_simulator/99_simulator_main.R", "maxdiff")
      if (!is.null(sim_main)) {
        source(sim_main, local = FALSE)
        if (generate_html) {
          simulator_html <- build_simulator_html_string(results, config)
        } else {
          sim_path <- sub("\\.xlsx$", "_simulator.html", output_path)
          sim_result <- generate_maxdiff_html_simulator(results, config, sim_path)
          results$simulator_path <- sim_result$output_file
        }
      } else {
        message("[TRS PARTIAL] MAXD_SIM_NOT_FOUND: Simulator module not found")
      }
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] MAXD_SIM_FAILED: Simulator failed: %s", conditionMessage(e)))
      add_warning(sprintf("Simulator: %s", conditionMessage(e)))
    })
  }

  # Step 13: HTML report
  if (generate_html && !is.null(output_path)) {
    if (verbose) cat("\nSTEP 13: Generating HTML report...\n")
    html_report_path <- sub("\\.xlsx$", ".html", output_path)
    tryCatch({
      html_main <- find_module_file("lib/html_report/99_html_report_main.R", "maxdiff")
      if (!is.null(html_main)) {
        cat("  Sourcing HTML report module...\n")
        source(html_main, local = FALSE)
        cat(sprintf("  Generating HTML report to: %s\n", html_report_path))
        html_result <- generate_maxdiff_html_report(
          results, html_report_path, config,
          simulator_html = simulator_html
        )
        cat(sprintf("  HTML report result status: %s\n", html_result$status))
        if (html_result$status == "PASS") {
          results$html_report_path <- html_result$output_file
          cat(sprintf("  HTML report saved: %s\n", html_result$output_file))

          # Minify for client delivery (if requested via Shiny checkbox)
          if (exists("turas_prepare_deliverable", mode = "function")) {
            turas_prepare_deliverable(html_report_path)
          }
        } else {
          cat(sprintf("  HTML report failed: %s\n", html_result$message %||% "unknown"))
        }
      } else {
        cat("\n[TRS PARTIAL] MAXD_HTML_NOT_FOUND: HTML report module not found at any path\n")
        message("[TRS PARTIAL] MAXD_HTML_NOT_FOUND: HTML report module not found")
      }
    }, error = function(e) {
      cat(sprintf("\n[TRS PARTIAL] MAXD_HTML_FAILED: HTML report failed: %s\n", conditionMessage(e)))
      cat(sprintf("  Traceback: %s\n", paste(capture.output(traceback()), collapse = "\n  ")))
      message(sprintf("[TRS PARTIAL] MAXD_HTML_FAILED: HTML report failed: %s", conditionMessage(e)))
      add_warning(sprintf("HTML report: %s", conditionMessage(e)))
    })
  }

  results
}


#' Find a Module File Using Multi-Fallback Path Resolution
#'
#' Searches for a file relative to the module's script directory, cwd,
#' and project root. Returns the first existing path, or NULL.
#'
#' @param relative_path Relative path from module root (e.g. "lib/html_report/99_html_report_main.R")
#' @param module_name Module name (e.g. "maxdiff")
#' @return Absolute path if found, NULL otherwise
#' @keywords internal
find_module_file <- function(relative_path, module_name) {
  base_dir <- get_script_dir()
  candidates <- c(
    file.path(base_dir, "..", relative_path),
    file.path(getwd(), relative_path),
    file.path(getwd(), "modules", module_name, relative_path)
  )
  for (cand in candidates) {
    if (file.exists(cand)) return(cand)
  }
  NULL
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

cat(sprintf("\nTuras MaxDiff Module loaded (v%s)\n", MAXDIFF_VERSION))
cat("  Usage: run_maxdiff('path/to/config.xlsx')\n")
cat("  Quick: quick_maxdiff('path/to/config.xlsx')\n\n")
