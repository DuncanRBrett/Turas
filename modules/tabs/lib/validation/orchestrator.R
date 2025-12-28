# ==============================================================================
# VALIDATION ORCHESTRATOR - TURAS V10.1
# ==============================================================================
# Main validation orchestrator and shared utilities
# Runs complete validation suite before analysis
#
# VERSION HISTORY:
# V10.1 - Created from validation.R refactoring (2025)
#        - Orchestrates all focused validation modules
#        - Part of Phase 2 refactoring
# ==============================================================================

SCRIPT_VERSION <- "10.1"

# Maximum decimal places allowed for rounding settings
MAX_DECIMAL_PLACES <- 6

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

source_if_exists <- function(file_path) {
  if (file.exists(file_path)) {
    tryCatch({
      sys.source(file_path, envir = environment())
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

# Source shared functions
if (!exists("log_issue")) {
  script_dir <- dirname(sys.frame(1)$ofile)
  if (is.null(script_dir) || is.na(script_dir)) script_dir <- getwd()
  source(file.path(dirname(script_dir), "shared_functions.R"), local = FALSE)
}

# Source all validation modules
validation_dir <- tryCatch({
  dirname(sys.frame(1)$ofile)
}, error = function(e) getwd())
if (is.null(validation_dir) || is.na(validation_dir) || length(validation_dir) == 0) {
  validation_dir <- getwd()
}

source(file.path(validation_dir, "structure_validators.R"), local = FALSE)
source(file.path(validation_dir, "data_validators.R"), local = FALSE)
source(file.path(validation_dir, "weight_validators.R"), local = FALSE)
source(file.path(validation_dir, "config_validators.R"), local = FALSE)
source(file.path(validation_dir, "statistical_validators.R"), local = FALSE)
source(file.path(validation_dir, "filter_validator.R"), local = FALSE)

# ==============================================================================
# SHARED UTILITIES (Re-exported from data_validators.R)
# ==============================================================================

# is_blank() is already defined in data_validators.R
# Re-export it here for convenience if needed
if (!exists("is_blank")) {
  #' Type-safe empty value check
  #' @keywords internal
  is_blank <- function(x) {
    if (is.character(x) || is.factor(x)) {
      x_char <- as.character(x)
      all(is.na(x_char) | trimws(x_char) == "")
    } else {
      all(is.na(x))
    }
  }
}

# ==============================================================================
# MASTER ORCHESTRATOR
# ==============================================================================

#' Run All Validation Checks
#'
#' Master orchestrator that runs complete validation suite
#'
#' VALIDATION SEQUENCE:
#' 1. Survey structure validation (duplicates, orphans, types)
#' 2. Data structure validation (columns, types, empties)
#' 3. Weighting configuration validation (if applicable)
#' 4. Crosstab configuration validation
#'
#' DESIGN PHILOSOPHY:
#' - Fail fast: Stop immediately on critical errors
#' - Collect warnings: Log non-critical issues for review
#' - Clear messages: Every error/warning is actionable
#' - Defensive: Validate all inputs before processing
#'
#' @param survey_structure Survey structure list with $questions and $options
#' @param survey_data Survey data frame
#' @param config Configuration list
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Error log data frame
#' @export
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
