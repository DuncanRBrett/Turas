# ==============================================================================
# RUN_CROSSTABS HELPERS - TURAS V10.0
# ==============================================================================
# Helper functions for run_crosstabs.R
# Extracted from run_crosstabs.R for better modularity and maintainability
#
# VERSION HISTORY:
# V10.0 - Extracted from run_crosstabs.R (2025)
#        - Refactored procedural code into reusable functions
#        - Improved testability and maintainability
# ==============================================================================

# ==============================================================================
# CONFIGURATION SUMMARY
# ==============================================================================

#' Print Analysis Configuration Summary
#'
#' Prints a formatted summary of analysis configuration before processing
#'
#' @param n_questions Integer, number of questions to process
#' @param n_respondents Integer, number of respondents
#' @param n_banner_cols Integer, number of banner columns
#' @param use_weights Logical, whether weighting is enabled
#' @param enable_sig_testing Logical, whether significance testing is enabled
#' @param estimated_seconds Numeric, estimated processing time in seconds
#' @return Invisible NULL
#' @export
print_analysis_summary <- function(n_questions, n_respondents, n_banner_cols,
                                   use_weights, enable_sig_testing,
                                   estimated_seconds) {
  cat("\n")
  cat(strrep("=", 60), "\n")
  cat("ANALYSIS CONFIGURATION\n")
  cat(strrep("=", 60), "\n")
  cat(sprintf("  Questions to process:    %d\n", n_questions))
  cat(sprintf("  Respondents:             %d\n", n_respondents))
  cat(sprintf("  Banner columns:          %d\n", n_banner_cols))
  cat(sprintf("  Weighting:               %s\n",
              if (use_weights) "Enabled" else "Disabled"))
  cat(sprintf("  Significance testing:    %s\n",
              if (enable_sig_testing) "Enabled" else "Disabled"))
  cat(sprintf("  Estimated time:          %s\n",
              format_seconds(estimated_seconds)))
  cat(strrep("=", 60), "\n\n")

  invisible(NULL)
}


#' Estimate Analysis Runtime
#'
#' Estimates how long analysis will take based on question count and banner size
#'
#' @param n_questions Integer, number of questions to process
#' @param n_banner_cols Integer, number of banner columns
#' @param enable_sig_testing Logical, whether significance testing is enabled
#' @return Numeric, estimated seconds
#' @export
estimate_runtime <- function(n_questions, n_banner_cols, enable_sig_testing = TRUE) {
  # Base time per question (seconds)
  base_time_per_question <- 0.5

  # Time per banner column per question
  time_per_banner_col <- 0.1

  # Additional time if significance testing enabled
  sig_test_multiplier <- if (enable_sig_testing) 1.5 else 1.0

  # Calculate total
  total_seconds <- n_questions * (
    base_time_per_question +
    (n_banner_cols * time_per_banner_col)
  ) * sig_test_multiplier

  return(total_seconds)
}


# ==============================================================================
# PARTIAL RESULTS HANDLING
# ==============================================================================

#' Print Partial Results Warning
#'
#' Prints a formatted warning when analysis completes with partial results
#'
#' @param n_successful Integer, number of successful questions
#' @param n_failed Integer, number of failed questions
#' @param n_total Integer, total questions attempted
#' @return Invisible NULL
#' @export
print_partial_results_warning <- function(n_successful, n_failed, n_total) {
  cat("\n")
  cat(paste(rep("!", 80), collapse=""), "\n")
  cat("[TRS PARTIAL] ANALYSIS COMPLETED WITH PARTIAL RESULTS\n")
  cat(paste(rep("!", 80), collapse=""), "\n")
  cat("\n")
  cat(sprintf("  SUCCESS: %d/%d questions processed successfully\n",
              n_successful, n_total))
  cat(sprintf("  FAILED:  %d/%d questions could not be processed\n",
              n_failed, n_total))
  cat("\n")
  cat("  WHAT HAPPENED:\n")
  cat("  Some questions encountered data quality or configuration issues\n")
  cat("  that prevented processing. These issues are logged below.\n")
  cat("\n")
  cat("  PARTIAL OUTPUT:\n")
  cat("  - Successfully processed questions are included in the workbook\n")
  cat("  - Failed questions are marked in the Run_Status sheet\n")
  cat("  - An error log is included with details on each failure\n")
  cat("\n")
  cat("  ACTION REQUIRED: Review and fix the issues above, then re-run.\n")
  cat("  A 'Run_Status' sheet will be included in your workbook.\n")
  cat(paste(rep("!", 80), collapse=""), "\n\n")

  invisible(NULL)
}


#' Print Complete Success Message
#'
#' Prints a formatted success message when analysis completes without errors
#'
#' @param n_questions Integer, number of questions processed
#' @param output_file Character, path to output file
#' @return Invisible NULL
#' @export
print_success_message <- function(n_questions, output_file) {
  cat("\n")
  cat(strrep("=", 60), "\n")
  cat("✓ ANALYSIS COMPLETE\n")
  cat(strrep("=", 60), "\n")
  cat(sprintf("  Questions processed:     %d\n", n_questions))
  cat(sprintf("  Output file:             %s\n", basename(output_file)))
  cat(strrep("=", 60), "\n\n")

  invisible(NULL)
}


# ==============================================================================
# VALIDATION HELPERS
# ==============================================================================

#' Check for Validation Issues
#'
#' Checks if there are any validation issues in the error log
#'
#' @param error_log Data frame, error log
#' @return Logical, TRUE if there are validation issues
#' @export
has_validation_issues <- function(error_log) {
  if (is.null(error_log) || !is.data.frame(error_log)) {
    return(FALSE)
  }

  nrow(error_log) > 0
}


#' Print Validation Summary
#'
#' Prints summary of validation issues
#'
#' @param error_log Data frame, error log with validation issues
#' @return Invisible NULL
#' @export
print_validation_summary <- function(error_log) {
  if (is.null(error_log) || nrow(error_log) == 0) {
    return(invisible(NULL))
  }

  n_errors <- sum(error_log$Severity == "Error", na.rm = TRUE)
  n_warnings <- sum(error_log$Severity == "Warning", na.rm = TRUE)

  cat("\n")
  cat("VALIDATION SUMMARY:\n")
  if (n_errors > 0) {
    cat(sprintf("  Errors:   %d\n", n_errors))
  }
  if (n_warnings > 0) {
    cat(sprintf("  Warnings: %d\n", n_warnings))
  }
  cat("\n")

  invisible(NULL)
}


# ==============================================================================
# QUESTION SELECTION
# ==============================================================================

#' Filter Selected Questions
#'
#' Filters selection data frame to get only selected questions
#'
#' @param selection_df Data frame, selection with Include column
#' @return Data frame, only selected questions
#' @export
get_selected_questions <- function(selection_df) {
  if (is.null(selection_df) || !is.data.frame(selection_df)) {
    return(data.frame())
  }

  if (!"Include" %in% names(selection_df)) {
    return(selection_df)
  }

  # Filter to Include='Y'
  selected <- selection_df[
    !is.na(selection_df$Include) & selection_df$Include == "Y",
  ]

  return(selected)
}


#' Get Question Codes from Selection
#'
#' Extracts question codes from selection data frame
#'
#' @param selection_df Data frame, selection data
#' @return Character vector, question codes
#' @export
get_question_codes <- function(selection_df) {
  if (is.null(selection_df) || !is.data.frame(selection_df)) {
    return(character(0))
  }

  if (!"QuestionCode" %in% names(selection_df)) {
    return(character(0))
  }

  # Get non-empty question codes
  codes <- selection_df$QuestionCode
  codes <- codes[!is.na(codes) & trimws(codes) != ""]

  return(as.character(codes))
}


# ==============================================================================
# PROCESSING HELPERS
# ==============================================================================

#' Initialize Results List
#'
#' Creates an empty results list for collecting question results
#'
#' @return List, empty results list
#' @export
initialize_results_list <- function() {
  list()
}


#' Add Result to List
#'
#' Adds a question result to the results list
#'
#' @param results_list List, existing results
#' @param result List, new result to add
#' @return List, updated results
#' @export
add_result <- function(results_list, result) {
  results_list[[length(results_list) + 1]] <- result
  return(results_list)
}


#' Count Successful Results
#'
#' Counts how many results were successfully processed
#'
#' @param results_list List, all results
#' @return Integer, number of successful results
#' @export
count_successful_results <- function(results_list) {
  if (is.null(results_list) || length(results_list) == 0) {
    return(0)
  }

  # Count non-NULL results with data
  n_success <- sum(sapply(results_list, function(r) {
    !is.null(r) && !is.null(r$table) && nrow(r$table) > 0
  }))

  return(n_success)
}
