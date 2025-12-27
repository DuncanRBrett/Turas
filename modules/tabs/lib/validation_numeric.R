# ==============================================================================
# VALIDATION_NUMERIC.R
# ==============================================================================
# Numeric question validation functions
# Extracted from validation.R for better maintainability
#
# Part of R Survey Analytics Toolkit - Tabs Module
# Version: 10.1
#
# FUNCTIONS:
# - validate_numeric_question(): Main validation function
# - check_numeric_min_max(): Check Min/Max values against data
# - check_bin_structure(): Check bin structure validity
# - check_bin_overlaps(): Check for overlapping bins
# - check_bin_coverage(): Check bin coverage of data
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

  if (!all(c("Bin_Min", "Bin_Max") %in% names(option_info))) {
    error_log <- log_issue(error_log, "Validation", "Missing Bin Columns",
      sprintf("Question %s: Bins defined but missing Bin_Min or Bin_Max columns.", question_code),
      question_code, "Error")
    return(error_log)
  }

  for (i in seq_len(nrow(option_info))) {
    bin_min <- suppressWarnings(as.numeric(option_info$Bin_Min[i]))
    bin_max <- suppressWarnings(as.numeric(option_info$Bin_Max[i]))

    if (is.na(bin_min) || is.na(bin_max)) {
      error_log <- log_issue(error_log, "Validation", "Invalid Bin Values",
        sprintf("Question %s bin %d: Bin_Min or Bin_Max is not numeric.", question_code, i),
        question_code, "Error")
    } else if (bin_min > bin_max) {
      error_log <- log_issue(error_log, "Validation", "Invalid Bin Range",
        sprintf("Question %s bin %d: Bin_Min (%.2f) > Bin_Max (%.2f).", question_code, i, bin_min, bin_max),
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
    bin1_min <- suppressWarnings(as.numeric(option_info$Bin_Min[i]))
    bin1_max <- suppressWarnings(as.numeric(option_info$Bin_Max[i]))

    if (is.na(bin1_min) || is.na(bin1_max)) next

    for (j in (i + 1):nrow(option_info)) {
      bin2_min <- suppressWarnings(as.numeric(option_info$Bin_Min[j]))
      bin2_max <- suppressWarnings(as.numeric(option_info$Bin_Max[j]))

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

  bins_min <- suppressWarnings(as.numeric(option_info$Bin_Min))
  bins_max <- suppressWarnings(as.numeric(option_info$Bin_Max))

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
# MAIN VALIDATION FUNCTION
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

# ==============================================================================
# END OF VALIDATION_NUMERIC.R
# ==============================================================================
