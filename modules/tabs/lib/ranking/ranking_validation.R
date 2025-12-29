# ==============================================================================
# RANKING VALIDATION - V10.1 (Phase 2 Refactoring)
# ==============================================================================
# Question validation helper functions for ranking questions
# Extracted from ranking.R for better modularity
#
# VERSION HISTORY:
# V10.1 - Extracted from ranking.R (2025-12-29)
#        - Uses tabs_source() for reliable subdirectory loading
#        - All ranking question validation helper functions
#
# DEPENDENCIES (must be loaded before this file):
# - log_issue() from logging_utils.R
# - tabs_refuse() from 00_guard.R
#
# USAGE:
# These functions are sourced by ranking.R using:
#   tabs_source("ranking", "ranking_validation.R")
#
# FUNCTIONS EXPORTED:
# - check_ranking_format() - Validate Ranking_Format field
# - check_ranking_positions() - Validate Ranking_Positions field
# - check_ranking_options() - Validate ranking options exist and are complete
# - validate_ranking_question() - Main ranking question validator
# ==============================================================================

# ==============================================================================
# RANKING QUESTION VALIDATION HELPERS (INTERNAL)
# ==============================================================================

#' Check Ranking_Format field
#' @keywords internal
check_ranking_format <- function(question_code, question_info, error_log) {
  if (!"Ranking_Format" %in% names(question_info) ||
      is.na(question_info$Ranking_Format) ||
      trimws(question_info$Ranking_Format) == "") {
    error_log <- log_issue(
      error_log,
      "Ranking",
      "Missing Ranking_Format",
      sprintf(
        "Ranking question %s missing Ranking_Format. Add 'Position' or 'Item' to Survey_Structure.",
        question_code
      ),
      question_code,
      "Error"
    )
  } else if (!question_info$Ranking_Format %in% c("Position", "Item")) {
    error_log <- log_issue(
      error_log,
      "Ranking",
      "Invalid Ranking_Format",
      sprintf(
        "Question %s: Ranking_Format must be 'Position' or 'Item', got: '%s'",
        question_code,
        question_info$Ranking_Format
      ),
      question_code,
      "Error"
    )
  }

  return(error_log)
}

#' Check Ranking_Positions field
#' @keywords internal
check_ranking_positions <- function(question_code, question_info, error_log) {
  has_positions <- FALSE

  if ("Ranking_Positions" %in% names(question_info)) {
    positions <- suppressWarnings(as.numeric(question_info$Ranking_Positions))

    if (!is.na(positions) && positions > 0) {
      has_positions <- TRUE
    }
  }

  if (!has_positions && "Columns" %in% names(question_info)) {
    columns <- suppressWarnings(as.numeric(question_info$Columns))

    if (!is.na(columns) && columns > 0) {
      has_positions <- TRUE
    }
  }

  if (!has_positions) {
    error_log <- log_issue(
      error_log,
      "Ranking",
      "Missing Ranking_Positions",
      sprintf(
        "Ranking question %s missing Ranking_Positions or Columns. Specify number of rank positions.",
        question_code
      ),
      question_code,
      "Error"
    )
  }

  return(error_log)
}

#' Check ranking options exist and are complete
#' @keywords internal
check_ranking_options <- function(question_code, options_info, error_log) {
  if (nrow(options_info) == 0) {
    error_log <- log_issue(
      error_log,
      "Ranking",
      "No Options",
      sprintf(
        "Ranking question %s has no options. Add items to rank in Survey_Structure options table.",
        question_code
      ),
      question_code,
      "Error"
    )
  } else {
    # Check options have required fields
    if (!"DisplayText" %in% names(options_info) || !"OptionText" %in% names(options_info)) {
      error_log <- log_issue(
        error_log,
        "Ranking",
        "Incomplete Options",
        sprintf(
          "Ranking question %s options missing DisplayText or OptionText columns.",
          question_code
        ),
        question_code,
        "Error"
      )
    }
  }

  return(error_log)
}

# ==============================================================================
# MAIN RANKING QUESTION VALIDATION FUNCTION
# ==============================================================================

#' Validate ranking question setup in Survey_Structure
#'
#' @param question_info Question metadata row
#' @param options_info Options metadata for this question
#' @param error_log Error log data frame
#' @return Updated error log data frame
#' @export
validate_ranking_question <- function(question_info, options_info, error_log) {
  # Input validation
  if (!is.data.frame(question_info) || nrow(question_info) == 0) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: question_info",
      problem = "The question_info argument must be a non-empty data frame row.",
      why_it_matters = "Question metadata is required to validate ranking question configuration.",
      how_to_fix = "Provide a data frame row with question metadata from Survey_Structure"
    )
  }

  if (!is.data.frame(options_info)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: options_info",
      problem = sprintf("The options_info argument must be a data frame, got: %s", class(options_info)),
      why_it_matters = "Options metadata is required to validate that ranking items are properly configured.",
      how_to_fix = "Provide a data frame with option metadata from Survey_Structure"
    )
  }

  if (!is.data.frame(error_log)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: error_log",
      problem = sprintf("The error_log argument must be a data frame, got: %s", class(error_log)),
      why_it_matters = "Error log is used to record validation issues found during ranking question validation.",
      how_to_fix = "Provide a data frame for error_log with standard error logging columns"
    )
  }

  question_code <- question_info$QuestionCode

  if (is.null(question_code) || is.na(question_code)) {
    tabs_refuse(
      code = "ARG_MISSING_REQUIRED",
      title = "Missing Required Field: QuestionCode",
      problem = "The question_info must contain a QuestionCode.",
      why_it_matters = "QuestionCode is required to identify which question is being validated.",
      how_to_fix = "Ensure question_info data frame has a non-null QuestionCode field"
    )
  }

  # Run all ranking question validation checks (delegated to helpers)
  error_log <- check_ranking_format(question_code, question_info, error_log)
  error_log <- check_ranking_positions(question_code, question_info, error_log)
  error_log <- check_ranking_options(question_code, options_info, error_log)

  return(error_log)
}
