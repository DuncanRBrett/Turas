# ==============================================================================
# WEIGHTING BASES V10.0 - BASE CALCULATION MODULE
# ==============================================================================
# Functions for calculating weighted bases for different question types
# Part of R Survey Analytics Toolkit
#
# MODULE PURPOSE:
# This module handles the calculation of weighted bases (sample sizes) for
# different question types including multi-mention, ranking, and single response.
# It provides type-robust logic to determine who has valid responses.
#
# VERSION HISTORY:
# V10.0 - Modular refactoring (2025-12-27)
#         - EXTRACTED: From weighting.R V9.9.4 (~230 lines)
#         - MAINTAINED: All V9.9.4 base calculation logic
#         - NO CHANGES: Function signatures and behavior identical
# V9.9.2 - Type-robust "has response" detection (numeric vs character)
# V9.9.1 - Return structure with unweighted, weighted, effective keys
#
# RETURN STRUCTURE (V9.9.1):
# All base calculation functions return a list with:
#   - $unweighted: Integer count of valid responses
#   - $weighted: Numeric sum of weights for valid responses
#   - $effective: Integer effective sample size for valid responses
#
# EXPORTED FUNCTIONS:
# - calculate_weighted_base(): Main function, dispatches to question-type helpers
#
# INTERNAL FUNCTIONS:
# - calculate_multimention_base(): Base for multi-mention questions
# - calculate_ranking_base(): Base for ranking questions
# - calculate_single_response_base(): Base for single response questions
# ==============================================================================

WEIGHTING_BASES_VERSION <- "10.0"

# ==============================================================================
# WEIGHTED BASE HELPERS (INTERNAL)
# ==============================================================================

#' Calculate base for multi-mention questions
#' @keywords internal
calculate_multimention_base <- function(data_subset, question_code, num_columns, weights) {
  if (is.na(num_columns) || num_columns < 1) {
    return(list(unweighted = 0, weighted = 0, effective = 0))
  }

  question_cols <- paste0(question_code, "_", seq_len(num_columns))
  existing_cols <- question_cols[question_cols %in% names(data_subset)]

  if (length(existing_cols) == 0) {
    return(list(unweighted = 0, weighted = 0, effective = 0))
  }

  # V9.9.2: Type-robust "has response" detection
  has_any_response <- Reduce(`|`, lapply(existing_cols, function(col) {
    v <- data_subset[[col]]

    if (is.numeric(v)) {
      # Numeric: valid if not NA and not zero
      !is.na(v) & v != 0
    } else {
      # Character/factor: valid if not NA and not empty string
      s <- trimws(as.character(v))
      !is.na(s) & nzchar(s)
    }
  }))

  unweighted_n <- sum(has_any_response, na.rm = TRUE)
  weighted_n <- sum(weights[has_any_response], na.rm = TRUE)
  effective_n <- calculate_effective_n(weights[has_any_response])

  return(list(
    unweighted = unweighted_n,
    weighted = weighted_n,
    effective = effective_n
  ))
}

#' Calculate base for ranking questions
#' @keywords internal
calculate_ranking_base <- function(data_subset, question_code, weights) {
  # Find all columns that start with the question code
  pattern <- paste0("^", question_code, "_")
  ranking_cols <- names(data_subset)[grepl(pattern, names(data_subset))]

  if (length(ranking_cols) == 0) {
    return(list(unweighted = 0, weighted = 0, effective = 0))
  }

  # Count respondents who have at least one non-NA ranking value
  has_any_ranking <- Reduce(`|`, lapply(ranking_cols, function(col) {
    !is.na(data_subset[[col]])
  }))

  unweighted_n <- sum(has_any_ranking, na.rm = TRUE)
  weighted_n <- sum(weights[has_any_ranking], na.rm = TRUE)
  effective_n <- calculate_effective_n(weights[has_any_ranking])

  return(list(
    unweighted = unweighted_n,
    weighted = weighted_n,
    effective = effective_n
  ))
}

#' Calculate base for single response questions
#' @keywords internal
calculate_single_response_base <- function(data_subset, question_code, question_info, weights) {
  if (!question_code %in% names(data_subset)) {
    return(list(unweighted = 0, weighted = 0, effective = 0))
  }

  col_values <- data_subset[[question_code]]

  # V9.9.2: Type-robust "has response" detection
  if (is.numeric(col_values)) {
    # For NPS and Rating questions, 0 may be a valid response
    # Include 0 if it's a valid score on the scale
    if (question_info$Variable_Type %in% c("NPS", "Rating", "Likert")) {
      has_response <- !is.na(col_values)
    } else {
      has_response <- !is.na(col_values) & col_values != 0
    }
  } else {
    col_str <- trimws(as.character(col_values))
    has_response <- !is.na(col_str) & nzchar(col_str)
  }

  unweighted_n <- sum(has_response, na.rm = TRUE)
  weighted_n <- sum(weights[has_response], na.rm = TRUE)
  effective_n <- calculate_effective_n(weights[has_response])

  return(list(
    unweighted = unweighted_n,
    weighted = weighted_n,
    effective = effective_n
  ))
}

# ==============================================================================
# WEIGHTED BASE CALCULATION (V9.9.2)
# ==============================================================================

#' Calculate weighted base for a question (V9.9.2: No rounding, type-robust)
#'
#' RETURN STRUCTURE (V9.9.1):
#' Returns list with keys: unweighted, weighted, effective
#'
#' V9.9.2 CHANGES:
#' - No rounding of weighted base (full precision for upstream calculations)
#' - Type-robust "has response" detection (numeric vs character)
#'
#' USAGE: Calculate base counts for question (handles multi-mention logic)
#' DESIGN: Counts respondents with at least one valid response
#'
#' @param data_subset Data frame, filtered data subset
#' @param question_info Data frame row, question metadata
#' @param weights Numeric vector, weight vector for subset
#' @return List with $unweighted, $weighted, $effective
#' @export
#' @examples
#' base_info <- calculate_weighted_base(filtered_data, q_info, weights)
#' cat("Unweighted:", base_info$unweighted)
#' cat("Weighted:", base_info$weighted)
#' cat("Effective:", base_info$effective)
calculate_weighted_base <- function(data_subset, question_info, weights) {
  # Validate inputs
  if (!is.data.frame(data_subset)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid data_subset Type",
      problem = "data_subset must be a data frame.",
      why_it_matters = "Cannot calculate weighted base from invalid data structure.",
      how_to_fix = "This is an internal error - check function call"
    )
  }

  if (!is.data.frame(question_info) || nrow(question_info) == 0) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid question_info Type",
      problem = "question_info must be a non-empty data frame.",
      why_it_matters = "Question metadata is required to determine base calculation method.",
      how_to_fix = "This is an internal error - check function call"
    )
  }

  if (!is.numeric(weights)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid weights Type",
      problem = "weights must be numeric.",
      why_it_matters = "Weights must be numeric for base calculations.",
      how_to_fix = "This is an internal error - check function call"
    )
  }

  if (length(weights) != nrow(data_subset)) {
    tabs_refuse(
      code = "ARG_LENGTH_MISMATCH",
      title = "Weights Length Mismatch",
      problem = sprintf("Weight vector length (%d) must match data rows (%d).", length(weights), nrow(data_subset)),
      why_it_matters = "Each row must have a corresponding weight value.",
      how_to_fix = "This is an internal error - check function call"
    )
  }

  # Empty data
  if (nrow(data_subset) == 0) {
    return(list(unweighted = 0, weighted = 0, effective = 0))
  }

  question_code <- question_info$QuestionCode

  # Delegate to appropriate helper based on question type
  if (question_info$Variable_Type == "Multi_Mention") {
    num_columns <- suppressWarnings(as.numeric(question_info$Columns))
    return(calculate_multimention_base(data_subset, question_code, num_columns, weights))
  } else if (question_info$Variable_Type == "Ranking") {
    return(calculate_ranking_base(data_subset, question_code, weights))
  } else {
    return(calculate_single_response_base(data_subset, question_code, question_info, weights))
  }
}

# ==============================================================================
# END OF WEIGHTING_BASES.R V10.0
# ==============================================================================
