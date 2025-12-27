# ==============================================================================
# VALIDATION V10.1 - PRODUCTION RELEASE (MAIN ORCHESTRATION)
# ==============================================================================
# Input validation and data quality checks
# Part of R Survey Analytics Toolkit
#
# VERSION HISTORY:
# V10.1 - Refactored for maintainability (2025-12-27)
#         - Split into focused modules for better organization
#         - Main file now handles orchestration and sourcing
#         - All validation logic extracted to specialized modules
# V9.9.5 - External review fixes (2025-10-16)
#          - FIXED: Added integer64 and labelled type support
#          - FIXED: Made weight validation thresholds configurable
# V9.9.4 - Likert character data fix
# V9.9.3 - Final polish (optional enhancements from review)
# V9.9.2 - External review fixes (production hardening)
# V9.9.1 - Production release (aligned with ecosystem V9.9)
# V8.0   - Previous version (incompatible with V9.9 ecosystem)
#
# DESIGN PHILOSOPHY:
# - Fail fast: Stop immediately on critical errors
# - Collect warnings: Log non-critical issues for review
# - Clear messages: Every error/warning is actionable
# - Defensive: Validate all inputs before processing
# - Consistent: All validations follow same patterns
#
# ERROR SEVERITY LEVELS:
# - Error: Blocks execution (data corruption, missing requirements)
# - Warning: Suspicious but not blocking (data quality, best practices)
# - Info: Informational only (successful validations)
# ==============================================================================

SCRIPT_VERSION <- "10.1"

# ==============================================================================
# DEPENDENCIES (V9.9.2)
# ==============================================================================

source_if_exists <- function(file_path) {
  if (file.exists(file_path)) {
    tryCatch({
      # Source into global environment so functions remain accessible
      source(file_path, local = FALSE)
      invisible(NULL)
    }, error = function(e) {
      warning(sprintf(
        "Failed to source %s: %s\nSome functions may not be available.",
        file_path,
        conditionMessage(e)
      ), call. = FALSE)
      invisible(NULL)
    })
  }
}

# Determine validation module directory (script_dir should be set by run_crosstabs.R)
.validation_dir <- if (exists("script_dir") && !is.null(script_dir) && length(script_dir) > 0 && nzchar(script_dir[1])) {
  script_dir[1]
} else {
  # Fallback: try to determine from this file's location
  tryCatch({
    dirname(sys.frame(1)$ofile)
  }, error = function(e) {
    getwd()
  })
}

# Source validation modules from the same directory as this file
source_if_exists(file.path(.validation_dir, "validation_structure.R"))
source_if_exists(file.path(.validation_dir, "validation_data.R"))
source_if_exists(file.path(.validation_dir, "validation_weighting.R"))
source_if_exists(file.path(.validation_dir, "validation_config.R"))
source_if_exists(file.path(.validation_dir, "validation_statistical.R"))
source_if_exists(file.path(.validation_dir, "validation_numeric.R"))

# ==============================================================================
# HELPER FUNCTIONS (V9.9.2)
# ==============================================================================

#' Check if column is empty (type-safe)
#'
#' V9.9.2: Handles character vs numeric columns correctly
#' Character: empty if NA or whitespace-only strings
#' Numeric: empty if NA
#'
#' @param x Vector to check
#' @return Logical, TRUE if all values are "empty"
#' @keywords internal
is_blank <- function(x) {
  if (is.character(x) || is.factor(x)) {
    # Character/factor: check for NA or empty strings
    x_char <- as.character(x)
    all(is.na(x_char) | trimws(x_char) == "")
  } else {
    # Numeric/other: check for NA only
    all(is.na(x))
  }
}

# ==============================================================================
# MASTER VALIDATION (V9.9.2)
# ==============================================================================

#' Run all validation checks and report results
#'
#' DESIGN:
#' - Runs all validation functions in sequence
#' - Collects all errors and warnings
#' - Stops execution only if critical errors found
#' - Provides clear summary of issues
#'
#' V9.9.2: Added verbose parameter for quiet mode (unit tests, batch, Shiny)
#'
#' ERROR HANDLING:
#' - Errors: Stop execution (data corruption, missing requirements)
#' - Warnings: Continue but log (data quality, best practices)
#' - Info: Successful validations logged to console (if verbose)
#'
#' @param survey_structure Survey structure list
#' @param survey_data Survey data frame
#' @param config Configuration list
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Error log data frame (stops if critical errors found)
#' @export
#' @examples
#' # Standard mode (prints progress)
#' error_log <- run_all_validations(survey_structure, survey_data, config)
#'
#' # Quiet mode (for unit tests or batch processing)
#' error_log <- run_all_validations(survey_structure, survey_data, config, verbose = FALSE)
run_all_validations <- function(survey_structure, survey_data, config, verbose = TRUE) {
  # Input validation (fail fast)
  if (!is.list(survey_structure)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid survey_structure Type",
      problem = "survey_structure must be a list but received a non-list object.",
      why_it_matters = "The validation orchestrator requires survey_structure to be a list for comprehensive validation.",
      how_to_fix = "Ensure survey_structure is a valid list with questions, options, and project elements."
    )
  }

  if (!is.data.frame(survey_data)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid survey_data Type",
      problem = "survey_data must be a data frame but received a non-data-frame object.",
      why_it_matters = "The validation orchestrator requires survey_data to be a data frame for comprehensive validation.",
      how_to_fix = "Ensure survey_data is a valid data frame."
    )
  }

  if (!is.list(config)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid config Type",
      problem = "config must be a list but received a non-list object.",
      why_it_matters = "The validation orchestrator requires config to be a list for comprehensive validation.",
      how_to_fix = "Ensure config is a valid list with all required configuration settings."
    )
  }

  # Header (if verbose)
  if (verbose) {
    cat("\n")
    cat(strrep("=", 80), "\n", sep = "")
    cat("VALIDATION CHECKS (V", SCRIPT_VERSION, ")\n", sep = "")
    cat(strrep("=", 80), "\n", sep = "")
    cat("\n")
  }

  # Create error log
  error_log <- create_error_log()

  # Run validations (each returns updated error_log)
  tryCatch({
    error_log <- validate_survey_structure(survey_structure, error_log, verbose)
    error_log <- validate_data_structure(survey_data, survey_structure, error_log, verbose)
    error_log <- validate_weighting_config(survey_structure, survey_data, config, error_log, verbose)
    error_log <- validate_crosstab_config(config, survey_structure, survey_data, error_log, verbose)
  }, error = function(e) {
    # Validation function itself failed (shouldn't happen with proper inputs)
    if (verbose) {
      cat("\n")
      cat("✗ VALIDATION FAILED WITH CRITICAL ERROR:\n")
      cat("  ", conditionMessage(e), "\n")
      cat("\n")
    }
    tabs_refuse(
      code = "ENV_INTERNAL_ERROR",
      title = "Validation Process Failed",
      problem = sprintf("Validation could not complete due to an internal error: %s", conditionMessage(e)),
      why_it_matters = "The validation process encountered an unexpected error and cannot proceed.",
      how_to_fix = c(
        "Fix critical errors in the input data or configuration",
        "Review the error message for details",
        "Ensure all required data structures are properly formatted"
      )
    )
  })

  # Report results (if verbose)
  if (verbose) {
    cat("\n")
    cat(strrep("-", 80), "\n", sep = "")
    cat("VALIDATION SUMMARY\n")
    cat(strrep("-", 80), "\n", sep = "")
  }

  if (nrow(error_log) == 0) {
    if (verbose) {
      cat("\n✓ All validation checks passed!\n")
      cat("  No errors or warnings found.\n\n")
    }
  } else {
    n_errors <- sum(error_log$Severity == "Error")
    n_warnings <- sum(error_log$Severity == "Warning")

    if (verbose) {
      cat("\n")
      if (n_errors > 0) {
        cat("✗ ", n_errors, " ERROR(S) found - execution will be blocked\n", sep = "")
      }
      if (n_warnings > 0) {
        cat("⚠ ", n_warnings, " WARNING(S) found - review recommended\n", sep = "")
      }
      cat("\n")

      # Print errors (detailed)
      if (n_errors > 0) {
        cat("ERRORS (must fix):\n")
        errors <- error_log[error_log$Severity == "Error", ]
        for (i in seq_len(nrow(errors))) {
          cat(sprintf(
            "  %d. %s: %s\n",
            i,
            errors$Issue_Type[i],
            errors$Description[i]
          ))
          if (errors$QuestionCode[i] != "") {
            cat(sprintf("     Question: %s\n", errors$QuestionCode[i]))
          }
        }
        cat("\n")
      }

      # Print warnings (summary)
      if (n_warnings > 0) {
        cat("WARNINGS (review recommended):\n")
        warnings <- error_log[error_log$Severity == "Warning", ]
        for (i in seq_len(nrow(warnings))) {
          cat(sprintf(
            "  • %s: %s\n",
            warnings$Issue_Type[i],
            warnings$Description[i]
          ))
        }
        cat("\n")
      }
    }

    # Stop if errors found (regardless of verbose)
    if (n_errors > 0) {
      if (verbose) {
        cat(strrep("=", 80), "\n", sep = "")
      }
      tabs_refuse(
        code = "ENV_VALIDATION_FAILED",
        title = "Validation Failed",
        problem = sprintf("Validation failed with %d error(s). Cannot proceed with analysis.", n_errors),
        why_it_matters = "Critical validation errors must be resolved before processing can continue.",
        how_to_fix = c(
          if (verbose) "See error details above" else "Run validation with verbose=TRUE to see detailed errors",
          "Fix all reported errors in the survey structure, data, or configuration",
          "Re-run validation after corrections"
        )
      )
    }
  }

  if (verbose) {
    cat(strrep("=", 80), "\n", sep = "")
    cat("\n")
  }

  return(error_log)
}

# ==============================================================================
# MAINTENANCE DOCUMENTATION
# ==============================================================================
#
# OVERVIEW:
# This script orchestrates comprehensive validation of survey data, structure,
# and configuration before analysis. It sources specialized validation modules
# and coordinates their execution.
#
# V10.1 REFACTORING:
# The validation logic has been split into focused modules:
#
# 1. validation_structure.R - Survey structure validation
#    - validate_survey_structure()
#    - check_duplicate_questions()
#    - check_missing_options()
#    - check_orphan_options()
#    - check_variable_types()
#    - check_ranking_questions()
#    - check_multi_mention_questions()
#
# 2. validation_data.R - Data structure validation
#    - validate_data_structure()
#    - check_multi_mention_columns()
#    - check_single_column()
#
# 3. validation_weighting.R - Weighting configuration validation
#    - validate_weighting_config()
#    - check_weighting_enabled()
#    - check_weight_variable()
#    - check_weight_column_exists()
#    - check_weight_values_valid()
#    - check_weight_distribution()
#
# 4. validation_config.R - Configuration validation
#    - validate_crosstab_config()
#    - check_alpha_config()
#    - check_min_base()
#    - check_decimal_places()
#    - check_numeric_settings()
#    - check_output_format()
#
# 5. validation_statistical.R - Statistical test validation
#    - validate_chi_square_preconditions()
#    - validate_z_test_preconditions()
#    - validate_column_comparison_preconditions()
#    - validate_significance_result()
#    - validate_base_sizes_for_testing()
#    - validate_base_filter()
#
# 6. validation_numeric.R - Numeric question validation
#    - validate_numeric_question()
#    - check_numeric_min_max()
#    - check_bin_structure()
#    - check_bin_overlaps()
#    - check_bin_coverage()
#
# CRITICAL FUNCTIONS (in this file):
# - run_all_validations(): Main entry point, orchestrates all validations
# - source_if_exists(): Safe module loading
# - is_blank(): Type-safe empty check (shared utility)
#
# TESTING PROTOCOL:
# 1. Module loading: Verify all modules source correctly
# 2. Orchestration: Verify run_all_validations() calls all modules
# 3. Error handling: Verify failure modes handled correctly
# 4. Backward compatibility: All existing validation tests pass
#
# DEPENDENCY MAP:
#
# validation.R (THIS FILE - ORCHESTRATION)
#   ├─→ validation_structure.R (survey structure checks)
#   ├─→ validation_data.R (data structure checks)
#   ├─→ validation_weighting.R (weighting configuration)
#   ├─→ validation_config.R (crosstab configuration)
#   ├─→ validation_statistical.R (statistical test validation)
#   ├─→ validation_numeric.R (numeric question validation)
#   ├─→ shared_functions.R (log_issue, create_error_log, tabs_refuse)
#   └─→ Used by: run_crosstabs.r (pre-execution checks)
#
# ==============================================================================
# END OF VALIDATION.R V10.1 - PRODUCTION RELEASE
# ==============================================================================
