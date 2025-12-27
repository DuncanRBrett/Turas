# ==============================================================================
# SEGMENTATION UTILITIES - MAIN MODULE
# ==============================================================================
# Purpose: Main orchestration file for segmentation utility functions
# Part of: Turas Segmentation Module
# Version: 1.1.0 (Refactored for maintainability)
# ==============================================================================
#
# REFACTORING SUMMARY:
# This file has been refactored from a monolithic 1,152-line file into
# focused, maintainable sub-modules. All existing functionality is preserved
# with full backward compatibility.
#
# SUB-MODULES:
#   - utils_dependencies.R     : Package dependency checking
#   - utils_config.R           : Configuration template generation
#   - utils_validation.R       : Input data validation
#   - utils_project.R          : Project initialization
#   - utils_reproducibility.R  : Seed and RNG management
#   - utils_quick_run.R        : Programmatic segmentation execution
#
# BACKWARD COMPATIBILITY:
# All existing functions remain available with identical APIs. Code using
# segment_utils.R will continue to work without modification.
#
# ==============================================================================

# ==============================================================================
# LOAD SUB-MODULES
# ==============================================================================
# Load all utility sub-modules at source time. This ensures all functions
# are available when segment_utils.R is loaded.
# ==============================================================================

# Determine the directory containing this file
.segment_utils_dir <- if (exists("module_config") &&
                          !is.null(module_config$module_lib_path)) {
  module_config$module_lib_path
} else {
  # Fallback: use the directory of the current script
  getSrcDirectory(function() {})
}

# If we still don't have a directory, try one more approach
if (.segment_utils_dir == "") {
  .segment_utils_dir <- dirname(sys.frame(1)$ofile)
}

# Final fallback: current working directory
if (is.null(.segment_utils_dir) || .segment_utils_dir == "") {
  .segment_utils_dir <- getwd()
}

# Source all sub-modules
.utils_modules <- c(
  "utils_dependencies.R",
  "utils_config.R",
  "utils_validation.R",
  "utils_project.R",
  "utils_reproducibility.R",
  "utils_quick_run.R"
)

for (.module in .utils_modules) {
  .module_path <- file.path(.segment_utils_dir, .module)

  if (file.exists(.module_path)) {
    source(.module_path, local = FALSE)
  } else {
    warning(sprintf("Sub-module not found: %s", .module_path), call. = FALSE)
  }
}

# Clean up temporary variables
rm(.segment_utils_dir, .utils_modules, .module, .module_path)

# ==============================================================================
# MODULE METADATA
# ==============================================================================

#' Get Segment Utils Module Information
#'
#' Returns information about the segment_utils module including version,
#' loaded sub-modules, and available functions.
#'
#' @param verbose Logical, print detailed information (default: TRUE)
#' @return List with module metadata
#' @export
get_segment_utils_info <- function(verbose = TRUE) {

  info <- list(
    module = "segment_utils",
    version = "1.1.0",
    refactored = TRUE,
    refactoring_date = "2025-12-27",

    sub_modules = c(
      "utils_dependencies.R",
      "utils_config.R",
      "utils_validation.R",
      "utils_project.R",
      "utils_reproducibility.R",
      "utils_quick_run.R"
    ),

    functions = list(
      dependencies = c(
        "check_segment_dependencies",
        "get_minimum_install_cmd",
        "get_full_install_cmd"
      ),
      config = c(
        "generate_config_template"
      ),
      validation = c(
        "validate_input_data"
      ),
      project = c(
        "initialize_segmentation_project"
      ),
      reproducibility = c(
        "set_segmentation_seed",
        "get_rng_state",
        "restore_rng_state",
        "validate_seed_reproducibility"
      ),
      quick_run = c(
        "run_segment_quick"
      )
    )
  )

  if (verbose) {
    cat("\n")
    cat(rep("=", 70), "\n", sep = "")
    cat("SEGMENTATION UTILS MODULE INFORMATION\n")
    cat(rep("=", 70), "\n", sep = "")
    cat("\n")
    cat(sprintf("Module:   %s\n", info$module))
    cat(sprintf("Version:  %s\n", info$version))
    cat(sprintf("Status:   Refactored for maintainability\n"))
    cat(sprintf("Date:     %s\n", info$refactoring_date))
    cat("\n")

    cat("SUB-MODULES:\n")
    for (mod in info$sub_modules) {
      cat(sprintf("  - %s\n", mod))
    }
    cat("\n")

    cat("AVAILABLE FUNCTIONS:\n")
    for (category in names(info$functions)) {
      cat(sprintf("\n  %s:\n", toupper(category)))
      for (fn in info$functions[[category]]) {
        cat(sprintf("    - %s()\n", fn))
      }
    }
    cat("\n")

    cat(rep("-", 70), "\n", sep = "")
    cat("Total functions: ")
    cat(sum(sapply(info$functions, length)), "\n")
    cat(rep("=", 70), "\n", sep = "")
    cat("\n")
  }

  return(invisible(info))
}


# ==============================================================================
# BACKWARD COMPATIBILITY VERIFICATION
# ==============================================================================
# All functions from the original segment_utils.R are now available through
# the sourced sub-modules. This section documents the function mapping for
# reference and maintenance purposes.
# ==============================================================================

# ORIGINAL FUNCTIONS (all preserved):
#
# From utils_dependencies.R:
#   - check_segment_dependencies()
#   - get_minimum_install_cmd()
#   - get_full_install_cmd()
#
# From utils_config.R:
#   - generate_config_template()
#
# From utils_validation.R:
#   - validate_input_data()
#
# From utils_project.R:
#   - initialize_segmentation_project()
#
# From utils_reproducibility.R:
#   - set_segmentation_seed()
#   - get_rng_state()
#   - restore_rng_state()
#   - validate_seed_reproducibility()
#
# From utils_quick_run.R:
#   - run_segment_quick()
#
# ==============================================================================

# ==============================================================================
# MODULE INITIALIZATION COMPLETE
# ==============================================================================
# All utility functions are now loaded and ready for use.
# ==============================================================================
