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

MAXDIFF_VERSION <- "10.0"

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
    "10_charts.R"
  )

  for (file in module_files) {
    file_path <- file.path(base_dir, file)

    if (!file.exists(file_path)) {
      # Try R subdirectory
      file_path <- file.path(base_dir, "R", file)
    }

    if (!file.exists(file_path)) {
      stop(sprintf("Required module file not found: %s", file), call. = FALSE)
    }

    source(file_path)
  }
}

# Source all modules
tryCatch({
  source_module_files()
}, error = function(e) {
  stop(sprintf(
    "Failed to load module files\nError: %s\n\nPlease ensure all R files are in the correct location.",
    conditionMessage(e)
  ), call. = FALSE)
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

  # Start timer

start_time <- Sys.time()

  if (verbose) {
    cat("\n")
    cat("================================================================================\n")
    cat("TURAS MAXDIFF MODULE\n")
    cat(sprintf("Version: %s\n", MAXDIFF_VERSION))
    cat(sprintf("Started: %s\n", format(start_time, "%Y-%m-%d %H:%M:%S")))
    cat("================================================================================\n\n")
  }

  # ==========================================================================
  # STEP 1: LOAD CONFIGURATION
  # ==========================================================================

  if (verbose) cat("STEP 1: Loading configuration...\n")

  config <- tryCatch({
    load_maxdiff_config(config_path, project_root)
  }, error = function(e) {
    stop(sprintf("Failed to load configuration\nError: %s", conditionMessage(e)),
         call. = FALSE)
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
    run_maxdiff_design_mode(config, verbose)
  } else {
    run_maxdiff_analysis_mode(config, verbose)
  }

  # ==========================================================================
  # SUMMARY
  # ==========================================================================

  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  if (verbose) {
    cat("\n")
    cat("================================================================================\n")
    cat("MAXDIFF MODULE COMPLETE\n")
    cat("================================================================================\n")
    cat(sprintf("Finished: %s\n", format(end_time, "%Y-%m-%d %H:%M:%S")))
    cat(sprintf("Elapsed time: %.1f seconds\n", elapsed))
    if (!is.null(results$output_path)) {
      cat(sprintf("Output file: %s\n", results$output_path))
    }
    cat("================================================================================\n\n")
  }

  results$elapsed_seconds <- elapsed
  results$config <- config

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
#'
#' @return List with design results
#' @keywords internal
run_maxdiff_design_mode <- function(config, verbose = TRUE) {

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
    stop(sprintf("Design generation failed\nError: %s", conditionMessage(e)),
         call. = FALSE)
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
    warning(
      sprintf("Design validation found %d issues:\n  %s",
              length(validation$issues),
              paste(validation$issues, collapse = "\n  ")),
      call. = FALSE
    )
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
#'
#' @return List with analysis results
#' @keywords internal
run_maxdiff_analysis_mode <- function(config, verbose = TRUE) {

  if (verbose) {
    cat("\n")
    cat("--------------------------------------------------------------------------------\n")
    cat("ANALYSIS MODE\n")
    cat("--------------------------------------------------------------------------------\n")
  }

  warnings_list <- character()

  # ==========================================================================
  # STEP 2: LOAD DESIGN FILE
  # ==========================================================================

  if (verbose) cat("\nSTEP 2: Loading design file...\n")

  design <- tryCatch({
    load_design_file(config$project_settings$Design_File, verbose)
  }, error = function(e) {
    stop(sprintf("Failed to load design file\nError: %s", conditionMessage(e)),
         call. = FALSE)
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
    stop(sprintf("Failed to load survey data\nError: %s", conditionMessage(e)),
         call. = FALSE)
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
    stop(sprintf(
      "Data validation failed:\n  %s",
      paste(data_validation$issues, collapse = "\n  ")
    ), call. = FALSE)
  }

  warnings_list <- c(warnings_list, data_validation$warnings)

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
    stop(sprintf("Data reshaping failed\nError: %s", conditionMessage(e)),
         call. = FALSE)
  })

  # Compute study summary
  study_summary <- compute_study_summary(long_data, config, verbose)

  # ==========================================================================
  # STEP 6: COMPUTE COUNT SCORES
  # ==========================================================================

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
      warning(sprintf("Count score computation failed: %s", conditionMessage(e)),
              call. = FALSE)
      warnings_list <- c(warnings_list, sprintf("Count scores: %s", conditionMessage(e)))
      NULL
    })
  }

  # ==========================================================================
  # STEP 7: FIT AGGREGATE LOGIT MODEL
  # ==========================================================================

  logit_results <- NULL

  if (config$output_settings$Generate_Aggregate_Logit) {
    if (verbose) cat("\nSTEP 7: Fitting aggregate logit model...\n")

    logit_results <- tryCatch({
      # Try full logit first, fall back to simple
      if (requireNamespace("survival", quietly = TRUE)) {
        fit_aggregate_logit(
          long_data = long_data,
          items = config$items,
          weighted = !is.null(config$project_settings$Weight_Variable),
          verbose = verbose
        )
      } else {
        fit_simple_logit(long_data, config$items, verbose)
      }
    }, error = function(e) {
      warning(sprintf("Logit model failed: %s", conditionMessage(e)), call. = FALSE)
      warnings_list <- c(warnings_list, sprintf("Logit model: %s", conditionMessage(e)))
      NULL
    })

    # Add logit utilities to count_scores if available
    if (!is.null(logit_results) && !is.null(count_scores)) {
      count_scores <- merge(
        count_scores,
        logit_results$utilities[, c("Item_ID", "Logit_Utility", "Logit_SE")],
        by = "Item_ID",
        all.x = TRUE
      )
    }
  }

  # ==========================================================================
  # STEP 8: FIT HIERARCHICAL BAYES MODEL
  # ==========================================================================

  hb_results <- NULL

  if (config$output_settings$Generate_HB_Model) {
    if (verbose) cat("\nSTEP 8: Fitting Hierarchical Bayes model...\n")

    hb_results <- tryCatch({
      fit_hb_model(
        long_data = long_data,
        items = config$items,
        config = config,
        verbose = verbose
      )
    }, error = function(e) {
      warning(sprintf("HB model failed: %s", conditionMessage(e)), call. = FALSE)
      warnings_list <- c(warnings_list, sprintf("HB model: %s", conditionMessage(e)))
      NULL
    })

    # Add HB utilities to count_scores if available
    if (!is.null(hb_results) && !is.null(count_scores)) {
      count_scores <- merge(
        count_scores,
        hb_results$population_utilities[, c("Item_ID", "HB_Utility_Mean", "HB_Utility_SD")],
        by = "Item_ID",
        all.x = TRUE
      )
    }
  }

  # ==========================================================================
  # STEP 9: COMPUTE SEGMENT SCORES
  # ==========================================================================

  segment_results <- NULL

  if (config$output_settings$Generate_Segment_Tables &&
      !is.null(config$segment_settings) &&
      nrow(config$segment_settings) > 0) {

    if (verbose) cat("\nSTEP 9: Computing segment-level scores...\n")

    segment_results <- tryCatch({
      compute_segment_scores(
        long_data = long_data,
        raw_data = raw_data,
        segment_settings = config$segment_settings,
        items = config$items,
        output_settings = config$output_settings,
        verbose = verbose
      )
    }, error = function(e) {
      warning(sprintf("Segment analysis failed: %s", conditionMessage(e)),
              call. = FALSE)
      warnings_list <- c(warnings_list, sprintf("Segments: %s", conditionMessage(e)))
      NULL
    })
  }

  # ==========================================================================
  # STEP 10: GENERATE CHARTS
  # ==========================================================================

  chart_paths <- NULL

  if (config$output_settings$Generate_Charts) {
    if (verbose) cat("\nSTEP 10: Generating charts...\n")

    results_for_charts <- list(
      count_scores = count_scores,
      logit_results = logit_results,
      hb_results = hb_results,
      segment_results = segment_results,
      study_summary = study_summary
    )

    chart_paths <- tryCatch({
      generate_maxdiff_charts(results_for_charts, config, verbose)
    }, error = function(e) {
      warning(sprintf("Chart generation failed: %s", conditionMessage(e)),
              call. = FALSE)
      warnings_list <- c(warnings_list, sprintf("Charts: %s", conditionMessage(e)))
      NULL
    })
  }

  # ==========================================================================
  # STEP 11: GENERATE EXCEL OUTPUT
  # ==========================================================================

  if (verbose) cat("\nSTEP 11: Generating Excel output...\n")

  results <- list(
    mode = "ANALYSIS",
    design = design,
    long_data = long_data,
    study_summary = study_summary,
    count_scores = count_scores,
    logit_results = logit_results,
    hb_results = hb_results,
    segment_results = segment_results,
    chart_paths = chart_paths,
    warnings = warnings_list
  )

  output_path <- tryCatch({
    generate_maxdiff_output(results, config, verbose)
  }, error = function(e) {
    warning(sprintf("Output generation failed: %s", conditionMessage(e)),
            call. = FALSE)
    NULL
  })

  results$output_path <- output_path

  # ==========================================================================
  # WARNINGS SUMMARY
  # ==========================================================================

  if (length(warnings_list) > 0 && verbose) {
    cat("\n")
    cat("WARNINGS:\n")
    for (i in seq_along(warnings_list)) {
      cat(sprintf("  %d. %s\n", i, warnings_list[i]))
    }
  }

  return(results)
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
# MODULE INITIALIZATION
# ==============================================================================

cat(sprintf("\nTuras MaxDiff Module loaded (v%s)\n", MAXDIFF_VERSION))
cat("  Usage: run_maxdiff('path/to/config.xlsx')\n")
cat("  Quick: quick_maxdiff('path/to/config.xlsx')\n\n")
