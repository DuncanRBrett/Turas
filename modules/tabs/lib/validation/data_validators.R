# ==============================================================================
# DATA VALIDATORS - V10.1 (Phase 2 Refactoring)
# ==============================================================================
# Data structure and type validation helper functions
# Extracted from validation.R for better modularity
#
# VERSION HISTORY:
# V10.1 - Extracted from validation.R (2025-12-28)
#        - Uses tabs_source() for reliable subdirectory loading
#        - All data validation helper functions
#        - Numeric question validation functions
#
# DEPENDENCIES (must be loaded before this file):
# - log_issue() from logging_utils.R
# - is_blank() from validation.R
# - tabs_refuse() from 00_guard.R
#
# USAGE:
# These functions are sourced by validation.R using:
#   tabs_source("validation", "data_validators.R")
#
# FUNCTIONS EXPORTED:
# - check_multi_mention_columns() - Validate multi-mention question columns
# - check_single_column() - Validate single column questions
# - check_numeric_min_max() - Check numeric values against Min/Max
# - check_bin_structure() - Validate bin definitions
# - check_bin_overlaps() - Check for overlapping bins
# - check_bin_coverage() - Check bin coverage of data
# - validate_numeric_question() - Main numeric question validator
# ==============================================================================

# ==============================================================================
# DATA VALIDATION HELPER FUNCTIONS (V9.9.5)
# ==============================================================================

# ------------------------------------------------------------------------------
# MULTI-MENTION AND SINGLE COLUMN VALIDATION
# ------------------------------------------------------------------------------

#' Check Multi_Mention question columns
#' @keywords internal
check_multi_mention_columns <- function(question, survey_data, numeric_types, error_log) {
  question_code <- trimws(question$QuestionCode)
  num_cols <- suppressWarnings(as.numeric(question$Columns))

  if (is.na(num_cols)) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Invalid Columns Value",
      sprintf("Multi_Mention question %s has non-numeric Columns value", question_code),
      question_code,
      "Error"
    )
    return(error_log)
  }

  if (num_cols > 0) {
    expected_cols <- paste0(question_code, "_", seq_len(num_cols))
    missing_cols <- expected_cols[!expected_cols %in% names(survey_data)]

    if (length(missing_cols) > 0) {
      error_log <- log_issue(
        error_log,
        "Validation",
        "Missing Multi-Mention Columns",
        sprintf(
          "Expected columns not found in data: %s. Add these columns or update Columns value.",
          paste(missing_cols, collapse = ", ")
        ),
        question_code,
        "Warning"
      )
    } else {
      # Check if all columns are completely empty
      all_empty <- all(sapply(expected_cols, function(col) {
        is_blank(survey_data[[col]])
      }))

      if (all_empty) {
        error_log <- log_issue(
          error_log,
          "Validation",
          "Empty Question Data",
          sprintf("All response columns for %s are empty", question_code),
          question_code,
          "Warning"
        )
      }

      # Type validation
      col_types <- sapply(expected_cols, function(col) class(survey_data[[col]])[1])

      # Multi_Mention typically numeric (0/1) or character codes
      valid_mm_types <- c(numeric_types, "character", "factor", "logical")

      invalid_type_cols <- expected_cols[!col_types %in% valid_mm_types]
      if (length(invalid_type_cols) > 0) {
        error_log <- log_issue(
          error_log,
          "Validation",
          "Unexpected Data Type",
          sprintf(
            "Multi_Mention columns have unexpected types: %s. Expected numeric or character.",
            paste(sprintf("%s (%s)", invalid_type_cols, col_types[invalid_type_cols]), collapse = ", ")
          ),
          question_code,
          "Warning"
        )
      }
    }
  }

  return(error_log)
}

#' Check single column question
#' @keywords internal
check_single_column <- function(question, survey_data, numeric_types, error_log) {
  question_code <- trimws(question$QuestionCode)
  var_type <- question$Variable_Type

  # Skip Ranking questions - they use multiple columns (Q76_Rank1, Q76_Rank2, etc.)
  if (var_type == "Ranking") {
    return(error_log)
  }

  if (!question_code %in% names(survey_data)) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Missing Column",
      sprintf(
        "Question column '%s' not found in data. Add column or remove from Survey_Structure.",
        question_code
      ),
      question_code,
      "Warning"
    )
    return(error_log)
  }

  col_values <- survey_data[[question_code]]
  col_type <- class(col_values)[1]

  # Check if column is completely empty
  if (is_blank(col_values)) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Empty Question Data",
      sprintf("Column %s exists but contains no valid responses", question_code),
      question_code,
      "Warning"
    )
  }

  # Type validation with integer64 and labelled support
  expected_types <- list(
    Rating = c(numeric_types, "character", "factor", "labelled"),
    Likert = c(numeric_types, "character", "factor", "labelled"),
    NPS = c(numeric_types, "labelled"),
    Numeric = c(numeric_types, "labelled"),
    Single_Response = c("character", "factor", numeric_types, "labelled"),
    Ranking = c(numeric_types),
    Grid_Single = c("character", "factor", numeric_types, "labelled"),
    Grid_Multi = c(numeric_types, "character", "factor", "labelled")
  )

  if (var_type %in% names(expected_types)) {
    valid_types <- expected_types[[var_type]]

    if (!col_type %in% valid_types) {
      error_log <- log_issue(
        error_log,
        "Validation",
        "Unexpected Data Type",
        sprintf(
          "Question %s (type: %s) has unexpected data type '%s'. Expected: %s",
          question_code,
          var_type,
          col_type,
          paste(valid_types, collapse = " or ")
        ),
        question_code,
        "Warning"
      )
    }
  }

  # Additional check: Single_Response shouldn't be list or data.frame
  if (var_type == "Single_Response" && (is.list(col_values) || is.data.frame(col_values))) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Invalid Data Structure",
      sprintf(
        "Single_Response question %s has complex structure (%s). Should be atomic vector.",
        question_code,
        col_type
      ),
      question_code,
      "Error"
    )
  }

  return(error_log)
}

# ==============================================================================
# NUMERIC QUESTION VALIDATION (V10.0.0)
# ==============================================================================

# ------------------------------------------------------------------------------
# NUMERIC VALIDATION HELPER FUNCTIONS (Internal)
# ------------------------------------------------------------------------------

#' Check Min/Max values against data
#' @keywords internal
check_numeric_min_max <- function(question_code, question_info, survey_data, error_log) {
  col_data <- survey_data[[question_code]]
  numeric_data <- suppressWarnings(as.numeric(col_data))
  valid_numeric <- numeric_data[!is.na(numeric_data)]

  if (length(valid_numeric) == 0) return(error_log)

  if ("Min_Value" %in% names(question_info)) {
    min_val <- suppressWarnings(as.numeric(question_info$Min_Value))
    if (!is.na(min_val)) {
      below_min <- sum(valid_numeric < min_val)
      if (below_min > 0) {
        error_log <- log_issue(error_log, "Validation", "Values Below Minimum",
          sprintf("Question %s: %d values below Min_Value (%.2f). These will be excluded from analysis.",
                  question_code, below_min, min_val), question_code, "Warning")
      }
    }
  }

  if ("Max_Value" %in% names(question_info)) {
    max_val <- suppressWarnings(as.numeric(question_info$Max_Value))
    if (!is.na(max_val)) {
      above_max <- sum(valid_numeric > max_val)
      if (above_max > 0) {
        error_log <- log_issue(error_log, "Validation", "Values Above Maximum",
          sprintf("Question %s: %d values above Max_Value (%.2f). These will be excluded from analysis.",
                  question_code, above_max, max_val), question_code, "Warning")
      }
    }
  }

  return(error_log)
}

#' Check bin structure validity
#' @keywords internal
check_bin_structure <- function(question_code, option_info, error_log) {
  if (nrow(option_info) == 0) return(error_log)

  if (!all(c("Min", "Max") %in% names(option_info))) {
    error_log <- log_issue(error_log, "Validation", "Missing Bin Columns",
      sprintf("Question %s: Bins defined but missing Min or Max columns.", question_code),
      question_code, "Error")
    return(error_log)
  }

  for (i in seq_len(nrow(option_info))) {
    bin_min <- suppressWarnings(as.numeric(option_info$Min[i]))
    bin_max <- suppressWarnings(as.numeric(option_info$Max[i]))

    if (is.na(bin_min) || is.na(bin_max)) {
      error_log <- log_issue(error_log, "Validation", "Invalid Bin Values",
        sprintf("Question %s bin %d: Min or Max is not numeric.", question_code, i),
        question_code, "Error")
    } else if (bin_min > bin_max) {
      error_log <- log_issue(error_log, "Validation", "Invalid Bin Range",
        sprintf("Question %s bin %d: Min (%.2f) > Max (%.2f).", question_code, i, bin_min, bin_max),
        question_code, "Error")
    }
  }

  return(error_log)
}

#' Check for overlapping bins
#' @keywords internal
check_bin_overlaps <- function(question_code, option_info, error_log) {
  if (nrow(option_info) < 2) return(error_log)

  for (i in seq_len(nrow(option_info) - 1)) {
    bin1_min <- suppressWarnings(as.numeric(option_info$Min[i]))
    bin1_max <- suppressWarnings(as.numeric(option_info$Max[i]))

    if (is.na(bin1_min) || is.na(bin1_max)) next

    for (j in (i + 1):nrow(option_info)) {
      bin2_min <- suppressWarnings(as.numeric(option_info$Min[j]))
      bin2_max <- suppressWarnings(as.numeric(option_info$Max[j]))

      if (is.na(bin2_min) || is.na(bin2_max)) next

      if (bin1_min < bin2_max && bin2_min < bin1_max) {
        error_log <- log_issue(error_log, "Validation", "Overlapping Bins",
          sprintf("Question %s: Bins %d and %d overlap ([%.2f-%.2f] and [%.2f-%.2f]).",
                  question_code, i, j, bin1_min, bin1_max, bin2_min, bin2_max),
          question_code, "Error")
      }
    }
  }

  return(error_log)
}

#' Check bin coverage of data
#' @keywords internal
check_bin_coverage <- function(question_code, option_info, survey_data, error_log) {
  col_data <- survey_data[[question_code]]
  numeric_data <- suppressWarnings(as.numeric(col_data))
  valid_numeric <- numeric_data[!is.na(numeric_data)]

  if (length(valid_numeric) == 0) return(error_log)

  data_min <- min(valid_numeric)
  data_max <- max(valid_numeric)

  bins_min <- suppressWarnings(as.numeric(option_info$Min))
  bins_max <- suppressWarnings(as.numeric(option_info$Max))

  valid_bins <- !is.na(bins_min) & !is.na(bins_max)
  if (!any(valid_bins)) return(error_log)

  bins_min <- bins_min[valid_bins]
  bins_max <- bins_max[valid_bins]

  bin_coverage_min <- min(bins_min)
  bin_coverage_max <- max(bins_max)

  if (data_min < bin_coverage_min || data_max > bin_coverage_max) {
    error_log <- log_issue(error_log, "Validation", "Insufficient Bin Coverage",
      sprintf("Question %s: Data range [%.2f-%.2f] not fully covered by bins [%.2f-%.2f].",
              question_code, data_min, data_max, bin_coverage_min, bin_coverage_max),
      question_code, "Warning")
  }

  return(error_log)
}

# ------------------------------------------------------------------------------
# MAIN NUMERIC VALIDATION FUNCTION
# ------------------------------------------------------------------------------

#' Validate Numeric Question Configuration
#'
#' Validates Min_Value, Max_Value, and bin definitions for Numeric questions
#'
#' CHECKS PERFORMED:
#' - Min/Max values are valid numbers
#' - Data values fall within Min/Max range (if specified)
#' - Bin definitions are valid (if bins defined in Options sheet)
#' - Bins don't overlap
#' - Bins cover the data range
#'
#' @param question_info Data frame row, question metadata
#' @param option_info Data frame, options for this question
#' @param survey_data Data frame, survey data
#' @param error_log Data frame, error log to append to
#' @return Updated error_log
#' @export
validate_numeric_question <- function(question_info, option_info, survey_data, error_log) {
  question_code <- trimws(question_info$QuestionCode)

  # Check if column exists in data
  if (!question_code %in% names(survey_data)) {
    return(error_log)
  }

  # Check Min/Max values
  error_log <- check_numeric_min_max(question_code, question_info, survey_data, error_log)

  # Check for non-numeric values
  col_data <- survey_data[[question_code]]
  numeric_data <- suppressWarnings(as.numeric(col_data))
  non_numeric_count <- sum(is.na(numeric_data) & !is.na(col_data))

  if (non_numeric_count > 0) {
    error_log <- log_issue(error_log, "Validation", "Non-Numeric Values",
      sprintf("Question %s: %d non-numeric values found. These will be treated as missing data.",
              question_code, non_numeric_count), question_code, "Warning")
  }

  # Validate bins if defined
  if (nrow(option_info) > 0) {
    error_log <- check_bin_structure(question_code, option_info, error_log)
    error_log <- check_bin_overlaps(question_code, option_info, error_log)
    error_log <- check_bin_coverage(question_code, option_info, survey_data, error_log)
  }

  return(error_log)
}
