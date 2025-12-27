# ==============================================================================
# CONFIDENCE ANALYSIS - INITIALIZATION MODULE
# ==============================================================================
# Handles module initialization including:
# - TRS guard layer loading
# - TRS infrastructure sourcing
# - Script directory detection
# - Module file sourcing and dependency loading
#
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.1 - Extracted from 00_main.R for maintainability (2025-12-27)
#
# USAGE:
# This file is sourced automatically by 00_main.R at load time.
# Do not source directly unless you know what you're doing.
#
# DEPENDENCIES:
# - 00_guard.R (for TRS refusal handling)
# - shared/lib/trs_*.R (for TRS run state management)
# ==============================================================================

INITIALIZATION_VERSION <- "10.1"

# ==============================================================================
# TRS GUARD LAYER (Must be first)
# ==============================================================================

#' Get script directory for guard layer sourcing
#'
#' @return Character path to script directory
#' @keywords internal
get_script_dir_for_guard <- function() {
  if (exists("script_dir_override")) return(script_dir_override)
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) return(dirname(sub("^--file=", "", file_arg)))
  return(getwd())
}

#' Load TRS guard layer for refusal handling
#'
#' Sources the 00_guard.R file which provides confidence_refuse() function
#' and refusal handler wrapper. Tries multiple possible paths.
#'
#' @return NULL (side effect: sources guard file)
#' @keywords internal
load_trs_guard <- function() {
  guard_path <- file.path(get_script_dir_for_guard(), "00_guard.R")
  if (!file.exists(guard_path)) {
    guard_path <- file.path(get_script_dir_for_guard(), "R", "00_guard.R")
  }
  if (file.exists(guard_path)) {
    source(guard_path)
  }
}

# Load guard immediately
load_trs_guard()

# ==============================================================================
# TRS INFRASTRUCTURE (TRS v1.0)
# ==============================================================================

#' Source TRS run state management infrastructure
#'
#' Loads TRS infrastructure files for run state tracking, banner printing,
#' and status writing. Tries multiple possible paths to find shared/lib.
#'
#' @return NULL (side effect: sources TRS files)
#' @keywords internal
source_trs_infrastructure <- function() {
  base_dir <- get_script_dir_for_guard()

  # Try multiple paths to find shared/lib
  possible_paths <- c(
    file.path(base_dir, "..", "..", "shared", "lib"),
    file.path(base_dir, "..", "shared", "lib"),
    file.path(getwd(), "modules", "shared", "lib"),
    file.path(getwd(), "..", "shared", "lib")
  )

  trs_files <- c("trs_run_state.R", "trs_banner.R", "trs_run_status_writer.R")

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

# Load TRS infrastructure
tryCatch({
  source_trs_infrastructure()
}, error = function(e) {
  message(sprintf("[TRS INFO] CONF_TRS_LOAD: Could not load TRS infrastructure: %s", e$message))
})

# ==============================================================================
# SCRIPT DIRECTORY DETECTION
# ==============================================================================

#' Get script directory for sourcing module files
#'
#' Detects the directory containing the currently executing script.
#' Checks for script_dir_override variable first, then command line args,
#' then falls back to current working directory.
#'
#' @return Character path to script directory
#' @export
get_script_dir <- function() {
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

# ==============================================================================
# MODULE FILE SOURCING
# ==============================================================================

#' Source all module dependency files
#'
#' Loads all required R files for the confidence module in the correct order.
#' Uses TRS refusal pattern if files are missing or cannot be loaded.
#'
#' @param base_dir Character. Base directory for sourcing (default: auto-detect)
#'
#' @return NULL (side effect: sources module files)
#' @export
source_module_files <- function(base_dir = NULL) {

  if (is.null(base_dir)) {
    base_dir <- get_script_dir()
  }

  # List of files to source in order
  module_files <- c(
    "utils.R",
    "01_load_config.R",
    "02_load_data.R",
    "03_study_level.R",
    "04_proportions.R",
    "05_means.R",
    "07_output.R",
    # New sub-modules from refactoring
    "main_processing.R",
    "main_workflow.R"
  )

  for (file in module_files) {
    file_path <- file.path(base_dir, file)

    if (!file.exists(file_path)) {
      # Try R subdirectory
      file_path <- file.path(base_dir, "R", file)
    }

    if (!file.exists(file_path)) {
      # Only fail if it's not one of the new sub-modules
      # (which might not exist yet during initial sourcing)
      if (!file %in% c("main_processing.R", "main_workflow.R")) {
        confidence_refuse(
          code = "IO_MODULE_FILE_MISSING",
          title = "Required Module File Not Found",
          problem = sprintf("Required module file not found: %s", file),
          why_it_matters = "The confidence module requires all component files to function properly.",
          how_to_fix = c(
            sprintf("Verify that %s exists in the module directory", file),
            "Ensure the module installation is complete"
          )
        )
      }
      # Skip silently if it's a sub-module that doesn't exist yet
      next
    }

    source(file_path)
  }
}

# Source all modules
tryCatch({
  source_module_files()
}, error = function(e) {
  confidence_refuse(
    code = "IO_MODULE_LOAD_FAILED",
    title = "Failed to Load Module Files",
    problem = sprintf("Failed to load module files: %s", conditionMessage(e)),
    why_it_matters = "All module component files must be loaded before analysis can proceed.",
    how_to_fix = c(
      "Ensure all R files are in the correct location",
      "Check that files are not corrupted",
      "Verify file permissions allow reading"
    )
  )
})

# ==============================================================================
# MODULE METADATA
# ==============================================================================

if (exists("VERBOSE_LOAD") && VERBOSE_LOAD) {
  message(sprintf("  ✓ Initialization module loaded (v%s)", INITIALIZATION_VERSION))
}
