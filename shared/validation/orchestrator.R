# ==============================================================================
# TURAS VALIDATION: ORCHESTRATOR MODULE
# ==============================================================================
# Master validation orchestrator
# Part of Turas Analytics Toolkit - Phase 4 Migration
#
# MIGRATED FROM: validation.r (lines 1568-1690)
# DATE: October 24, 2025
# STATUS: Phase 4 - Module 5 (FINAL MODULE)
#
# DESCRIPTION:
#   Orchestrates all validation checks and provides comprehensive reporting:
#   - Runs all validation functions in sequence
#   - Collects all errors and warnings
#   - Provides clear summary of issues
#   - Stops execution only if critical errors found
#
# DEPENDENCIES:
#   - core/logging.R (create_error_log, log_issue)
#   - shared/validation/survey.R (validate_survey_structure)
#   - shared/validation/data.R (validate_data_structure)
#   - shared/validation/config.R (validate_weighting_config, validate_crosstab_config)
#
# EXPORTED FUNCTIONS:
#   - run_all_validations() - Main orchestrator (user-facing entry point)
#
# DESIGN PHILOSOPHY:
#   - Fail fast: Stop immediately on critical errors
#   - Collect warnings: Log non-critical issues for review
#   - Clear messages: Every error/warning is actionable
#   - Defensive: Validate all inputs before processing
#
# ERROR SEVERITY LEVELS:
#   - Error: Blocks execution (data corruption, missing requirements, security issues)
#   - Warning: Suspicious but not blocking (data quality, best practices, deprecations)
#   - Info: Informational only (successful validations)
# ==============================================================================

# Version constant
VALIDATION_VERSION <- "9.9.5"

# ==============================================================================
# MASTER VALIDATION ORCHESTRATOR
# ==============================================================================

#' Run all validation checks and report results
#'
#' This is the main entry point for validation. It runs all validation
#' functions in sequence and provides a comprehensive summary of issues.
#'
#' VALIDATION SEQUENCE:
#' 1. Survey structure validation (questions, options, relationships)
#' 2. Data structure validation (columns, types, quality)
#' 3. Weighting configuration validation (if weighting enabled)
#' 4. Crosstab configuration validation (parameters, formats)
#'
#' ERROR HANDLING:
#' - Errors: Stop execution (data corruption, missing requirements)
#' - Warnings: Continue but log (data quality, best practices)
#' - Info: Successful validations logged to console (if verbose)
#'
#' @param survey_structure Survey structure list containing $questions, $options, $project
#' @param survey_data Survey data frame
#' @param config Configuration list
#' @param verbose Logical, print progress messages and summary (default: TRUE)
#' @return Error log data frame (stops if critical errors found)
#' @export
#' @examples
#' # Standard mode (prints progress)
#' error_log <- run_all_validations(survey_structure, survey_data, config)
#' 
#' # Quiet mode (for unit tests or batch processing)
#' error_log <- run_all_validations(survey_structure, survey_data, config, verbose = FALSE)
run_all_validations <- function(survey_structure, survey_data, config, verbose = TRUE) {
  
  # ============================================================================
  # INPUT VALIDATION (fail fast)
  # ============================================================================
  
  if (!is.list(survey_structure)) {
    stop("survey_structure must be a list", call. = FALSE)
  }
  
  if (!is.data.frame(survey_data)) {
    stop("survey_data must be a data frame", call. = FALSE)
  }
  
  if (!is.list(config)) {
    stop("config must be a list", call. = FALSE)
  }
  
  # ============================================================================
  # HEADER
  # ============================================================================
  
  if (verbose) {
    cat("\n")
    cat(strrep("=", 80), "\n", sep = "")
    cat("VALIDATION CHECKS (V", VALIDATION_VERSION, ")\n", sep = "")
    cat(strrep("=", 80), "\n", sep = "")
    cat("\n")
  }
  
  # ============================================================================
  # CREATE ERROR LOG
  # ============================================================================
  
  error_log <- create_error_log()
  
  # ============================================================================
  # RUN VALIDATIONS
  # ============================================================================
  
  # Each validation function returns updated error_log
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
    stop("Validation could not complete. Fix critical errors before proceeding.", call. = FALSE)
  })
  
  # ============================================================================
  # REPORT RESULTS
  # ============================================================================
  
  if (verbose) {
    cat("\n")
    cat(strrep("-", 80), "\n", sep = "")
    cat("VALIDATION SUMMARY\n")
    cat(strrep("-", 80), "\n", sep = "")
  }
  
  if (nrow(error_log) == 0) {
    # ========================================================================
    # NO ISSUES FOUND
    # ========================================================================
    if (verbose) {
      cat("\n✓ All validation checks passed!\n")
      cat("  No errors or warnings found.\n\n")
    }
  } else {
    # ========================================================================
    # ISSUES FOUND - CATEGORIZE AND REPORT
    # ========================================================================
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
      
      # ----------------------------------------------------------------------
      # PRINT ERRORS (DETAILED)
      # ----------------------------------------------------------------------
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
      
      # ----------------------------------------------------------------------
      # PRINT WARNINGS (SUMMARY)
      # ----------------------------------------------------------------------
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
    
    # ========================================================================
    # STOP IF ERRORS FOUND (regardless of verbose)
    # ========================================================================
    if (n_errors > 0) {
      if (verbose) {
        cat(strrep("=", 80), "\n", sep = "")
      }
      stop(sprintf(
        "\nValidation failed with %d error(s). Fix errors before proceeding.%s",
        n_errors,
        if (verbose) "\nSee error details above." else ""
      ), call. = FALSE)
    }
  }
  
  # ============================================================================
  # FOOTER
  # ============================================================================
  
  if (verbose) {
    cat(strrep("=", 80), "\n", sep = "")
    cat("\n")
  }
  
  return(error_log)
}

# ==============================================================================
# USAGE NOTES
# ==============================================================================
#
# BASIC USAGE:
#   # Load your data
#   survey_structure <- load_survey_structure("Survey_Structure.xlsx")
#   survey_data <- load_survey_data("data.csv", survey_structure)
#   config <- load_crosstab_config("config.xlsx")
#   
#   # Run all validations
#   error_log <- run_all_validations(survey_structure, survey_data, config)
#   
#   # If no errors, continue with analysis
#   results <- run_crosstabs(survey_structure, survey_data, config)
#
# QUIET MODE:
#   # For batch processing or unit tests
#   error_log <- run_all_validations(
#     survey_structure, 
#     survey_data, 
#     config, 
#     verbose = FALSE
#   )
#
# ERROR HANDLING:
#   tryCatch({
#     error_log <- run_all_validations(survey_structure, survey_data, config)
#     # Continue with analysis if no errors
#     results <- run_crosstabs(survey_structure, survey_data, config)
#   }, error = function(e) {
#     cat("Validation failed:", conditionMessage(e), "\n")
#     # Handle error (log, notify, etc.)
#   })
#
# ==============================================================================
