# ==============================================================================
# CONFIDENCE ANALYSIS MAIN ORCHESTRATION - TURAS V10.1
# ==============================================================================
# Main entry point for running complete confidence analysis
# Part of Turas Confidence Analysis Module
#
# This file has been refactored into focused sub-modules for maintainability:
# - main_initialization.R: TRS guard, infrastructure, and dependencies
# - main_processing.R: Question processing functions (proportion, mean, NPS)
# - main_workflow.R: Main workflow orchestration
#
# VERSION HISTORY:
# Turas v10.1 - Refactored into sub-modules (2025-12-27)
# Turas v10.0 - Initial release (2025-11-13)
#          - Complete workflow orchestration
#          - Progress reporting
#          - Error handling and validation
#          - Support for 200 question limit
#
# WORKFLOW:
# 1. Load configuration (with 200 question limit check)
# 2. Load survey data
# 3. Calculate study-level statistics (DEFF, effective n)
# 4. Process each question (proportions or means)
# 5. Collect warnings
# 6. Generate Excel output
#
# USAGE:
# source("R/00_main.R")
# run_confidence_analysis("path/to/confidence_config.xlsx")
#
# DEPENDENCIES:
# - All module R scripts (automatically sourced)
# - readxl, openxlsx
# ==============================================================================

MAIN_VERSION <- "10.1"

# ==============================================================================
# MODULE SOURCING
# ==============================================================================

#' Get directory for sourcing sub-modules
#'
#' @keywords internal
get_main_script_dir <- function() {
  if (exists("script_dir_override")) {
    return(script_dir_override)
  }

  # Try to get from command line args
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)

  if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg)
    return(dirname(script_path))
  }

  # Default to current directory
  return(getwd())
}

#' Source all sub-modules for the confidence module
#'
#' Sources sub-modules in the correct order. Uses TRS refusal pattern
#' if critical files are missing.
#'
#' @keywords internal
source_confidence_submodules <- function() {
  base_dir <- get_main_script_dir()

  # Sub-modules to source in order
  # main_initialization.R will handle sourcing all other dependencies
  submodules <- c(
    "main_initialization.R",
    "main_processing.R",
    "main_workflow.R"
  )

  for (module in submodules) {
    module_path <- file.path(base_dir, module)

    # Try R subdirectory if not found
    if (!file.exists(module_path)) {
      module_path <- file.path(base_dir, "R", module)
    }

    if (!file.exists(module_path)) {
      # Critical error - module missing
      stop(sprintf(
        "[CONFIDENCE ERROR] Required sub-module not found: %s\n  Expected at: %s\n  Ensure all module files are present.",
        module, module_path
      ))
    }

    # Source the module
    source(module_path)
  }
}

# Source all sub-modules
# Note: main_initialization.R sources all other dependencies (utils, config, data, etc.)
tryCatch({
  source_confidence_submodules()
}, error = function(e) {
  cat("\n")
  cat("================================================================================\n")
  cat("[CONFIDENCE ERROR] FAILED TO LOAD MODULE\n")
  cat("================================================================================\n\n")
  cat(sprintf("Problem: %s\n\n", conditionMessage(e)))
  cat("This is a configuration error, not a data error.\n")
  cat("The confidence module requires all component files to be present.\n\n")
  cat("How to fix:\n")
  cat("  1. Ensure all R files are in the correct location\n")
  cat("  2. Verify the module installation is complete\n")
  cat("  3. Check that files are not corrupted\n")
  cat("  4. Verify file permissions allow reading\n\n")
  cat("================================================================================\n\n")
  stop(conditionMessage(e), call. = FALSE)
})

# ==============================================================================
# MAIN EXPORTS
# ==============================================================================

# The main function run_confidence_analysis() is defined in main_workflow.R
# and is automatically available after sourcing.

# Re-export key functions for clarity (they're already in the namespace,
# but this documents what's public API)

#' @export run_confidence_analysis
#' @export quick_analysis
#' @export print_analysis_summary

# ==============================================================================
# CONVENIENCE FUNCTIONS
# ==============================================================================

#' Quick analysis with default settings
#'
#' Convenience wrapper for run_confidence_analysis with common defaults
#'
#' @param config_path Character. Path to confidence_config.xlsx
#'
#' @return List with analysis results (invisible)
#'
#' @examples
#' quick_analysis("config/confidence_config.xlsx")
#'
#' @export
quick_analysis <- function(config_path) {
  run_confidence_analysis(config_path, verbose = TRUE, stop_on_warnings = FALSE)
}


#' Print analysis summary
#'
#' Pretty-print summary of confidence analysis results
#'
#' @param results List. Output from run_confidence_analysis()
#'
#' @return NULL (side effect: prints to console)
#'
#' @examples
#' results <- run_confidence_analysis("config/confidence_config.xlsx")
#' print_analysis_summary(results)
#'
#' @export
print_analysis_summary <- function(results) {
  cat("\n=== CONFIDENCE ANALYSIS SUMMARY ===\n\n")

  if (!is.null(results$study_stats)) {
    cat("Study-Level Statistics:\n")
    print(results$study_stats, row.names = FALSE)
    cat("\n")
  }

  cat(sprintf("Proportions analyzed: %d\n", length(results$proportion_results)))
  cat(sprintf("Means analyzed: %d\n", length(results$mean_results)))
  cat(sprintf("NPS analyzed: %d\n", length(results$nps_results)))
  cat(sprintf("Warnings: %d\n", length(results$warnings)))
  cat(sprintf("Elapsed time: %.1f seconds\n", results$elapsed_seconds))

  if (length(results$warnings) > 0) {
    cat("\nWarnings:\n")
    for (i in seq_along(results$warnings)) {
      cat(sprintf("  %d. %s\n", i, results$warnings[i]))
    }
  }

  cat("\n")
}


#' Get module version information
#'
#' Returns version information for the confidence module and its sub-modules
#'
#' @return List with version information
#'
#' @examples
#' get_confidence_version()
#'
#' @export
get_confidence_version <- function() {
  versions <- list(
    main = MAIN_VERSION
  )

  # Add sub-module versions if available
  if (exists("INITIALIZATION_VERSION")) {
    versions$initialization <- INITIALIZATION_VERSION
  }
  if (exists("PROCESSING_VERSION")) {
    versions$processing <- PROCESSING_VERSION
  }
  if (exists("WORKFLOW_VERSION")) {
    versions$workflow <- WORKFLOW_VERSION
  }

  return(versions)
}


#' Print module version information
#'
#' Pretty-print version information for the confidence module
#'
#' @return NULL (side effect: prints to console)
#'
#' @examples
#' print_confidence_version()
#'
#' @export
print_confidence_version <- function() {
  versions <- get_confidence_version()

  cat("\n=== TURAS CONFIDENCE ANALYSIS MODULE ===\n\n")
  cat(sprintf("Main version: %s\n", versions$main))

  if (!is.null(versions$initialization)) {
    cat(sprintf("  - Initialization: %s\n", versions$initialization))
  }
  if (!is.null(versions$processing)) {
    cat(sprintf("  - Processing: %s\n", versions$processing))
  }
  if (!is.null(versions$workflow)) {
    cat(sprintf("  - Workflow: %s\n", versions$workflow))
  }

  cat("\n")
}


#' Validate configuration file
#'
#' Checks if a configuration file is valid without running the analysis
#'
#' @param config_path Character. Path to confidence_config.xlsx
#'
#' @return Logical. TRUE if config is valid, FALSE otherwise (with warnings)
#'
#' @examples
#' if (validate_confidence_config("config/confidence_config.xlsx")) {
#'   run_confidence_analysis("config/confidence_config.xlsx")
#' }
#'
#' @export
validate_confidence_config <- function(config_path) {
  tryCatch({
    config <- load_confidence_config(config_path)
    cat(sprintf("✓ Configuration is valid\n"))
    cat(sprintf("  - Questions: %d\n", nrow(config$question_analysis)))
    cat(sprintf("  - Data file: %s\n", config$file_paths$Data_File))
    cat(sprintf("  - Output file: %s\n", config$file_paths$Output_File))
    return(TRUE)
  }, error = function(e) {
    cat(sprintf("✗ Configuration is invalid: %s\n", conditionMessage(e)))
    return(FALSE)
  })
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

# Print startup message
cat("\n")
cat("================================================================================\n")
cat(sprintf("✓ Turas Confidence Analysis Module loaded (v%s)\n", MAIN_VERSION))
cat("================================================================================\n")
cat("\n")
cat("USAGE:\n")
cat("  Basic:  run_confidence_analysis('path/to/config.xlsx')\n")
cat("  Quick:  quick_analysis('path/to/config.xlsx')\n")
cat("  Help:   ?run_confidence_analysis\n")
cat("\n")
cat("TIPS:\n")
cat("  - Validate config:  validate_confidence_config('path/to/config.xlsx')\n")
cat("  - Check version:    print_confidence_version()\n")
cat("  - View results:     print_analysis_summary(results)\n")
cat("\n")
cat("SUB-MODULES LOADED:\n")
cat(sprintf("  ✓ Initialization (v%s)\n",
            if (exists("INITIALIZATION_VERSION")) INITIALIZATION_VERSION else "unknown"))
cat(sprintf("  ✓ Processing (v%s)\n",
            if (exists("PROCESSING_VERSION")) PROCESSING_VERSION else "unknown"))
cat(sprintf("  ✓ Workflow (v%s)\n",
            if (exists("WORKFLOW_VERSION")) WORKFLOW_VERSION else "unknown"))
cat("\n")
cat("Ready to analyze confidence intervals.\n")
cat("================================================================================\n\n")
