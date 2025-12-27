# ==============================================================================
# VALIDATION_DATA.R
# ==============================================================================
# Survey data structure validation functions
# Extracted from validation.R for better maintainability
#
# Part of R Survey Analytics Toolkit - Tabs Module
# Version: 10.1
#
# FUNCTIONS:
# - validate_data_structure(): Main validation function
# - check_multi_mention_columns(): Check Multi_Mention question columns
# - check_single_column(): Check single column question
# ==============================================================================

# ------------------------------------------------------------------------------
# DATA VALIDATION HELPER FUNCTIONS (Internal)
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

# ------------------------------------------------------------------------------
# MAIN VALIDATION FUNCTION
# ------------------------------------------------------------------------------

#' Validate survey data matches structure expectations
#'
#' CHECKS PERFORMED:
#' - Required question columns exist in data
#' - Multi_Mention columns exist (Q_1, Q_2, etc.)
#' - Column data types match Variable_Type expectations (V9.9.2)
#' - No completely empty questions (type-safe check, V9.9.2)
#'
#' V9.9.5 ENHANCEMENTS:
#' - Added integer64 type support (common via data.table, DB extracts)
#' - Added labelled type support (from haven package)
#'
#' V9.9.4 ENHANCEMENTS:
#' - Accept character/factor data for Likert questions (common and valid)
#' - Text responses get mapped to numeric via Options sheet during analysis
#'
#' V9.9.2 ENHANCEMENTS:
#' - Type validation per Variable_Type
#' - Type-safe empty column checks (character vs numeric)
#'
#' @param survey_data Survey data frame
#' @param survey_structure Survey structure list
#' @param error_log Error log data frame
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Updated error log data frame
#' @export
validate_data_structure <- function(survey_data, survey_structure, error_log, verbose = TRUE) {
  # Input validation
  if (!is.data.frame(survey_data)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid survey_data Type",
      problem = "survey_data must be a data frame but received a non-data-frame object.",
      why_it_matters = "The validation function requires survey_data to be a data frame containing survey responses.",
      how_to_fix = "Ensure survey_data is a valid data frame before calling this function."
    )
  }

  if (nrow(survey_data) == 0) {
    tabs_refuse(
      code = "DATA_EMPTY",
      title = "Empty Survey Data",
      problem = "survey_data has zero rows - no data to validate.",
      why_it_matters = "Cannot perform data validation on an empty dataset.",
      how_to_fix = "Ensure survey_data contains at least one row of data."
    )
  }

  if (!is.list(survey_structure) || !"questions" %in% names(survey_structure)) {
    tabs_refuse(
      code = "ARG_MISSING_ELEMENT",
      title = "Missing Questions Element",
      problem = "survey_structure must be a list containing a $questions element.",
      why_it_matters = "The questions table is required to validate the survey data structure.",
      how_to_fix = "Ensure survey_structure is a list with a $questions data frame."
    )
  }

  if (!is.data.frame(error_log)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid error_log Type",
      problem = "error_log must be a data frame but received a non-data-frame object.",
      why_it_matters = "The validation function requires error_log to track issues during validation.",
      how_to_fix = "Create error_log using create_error_log() before calling this function."
    )
  }

  if (verbose) cat("Validating data structure...\n")

  questions_df <- survey_structure$questions

  if (!is.data.frame(questions_df) || nrow(questions_df) == 0) {
    tabs_refuse(
      code = "DATA_INVALID_STRUCTURE",
      title = "Invalid Questions Structure",
      problem = "survey_structure$questions must be a non-empty data frame.",
      why_it_matters = "The questions table is required to validate survey data columns and types.",
      how_to_fix = "Ensure survey_structure$questions is a valid data frame with at least one row."
    )
  }

  # V9.9.5: Extended numeric types to include integer64
  numeric_types <- c("numeric", "integer", "double", "integer64")

  # Check for missing question columns and validate types
  for (i in seq_len(nrow(questions_df))) {
    question <- questions_df[i, ]
    var_type <- question$Variable_Type

    # Skip Open_End (optional in data)
    if (var_type == "Open_End") {
      next
    }

    # Dispatch to appropriate check function
    if (var_type == "Multi_Mention") {
      error_log <- check_multi_mention_columns(question, survey_data, numeric_types, error_log)
    } else {
      error_log <- check_single_column(question, survey_data, numeric_types, error_log)
    }
  }

  # ===========================================================================
  # V10.0.0: NUMERIC QUESTION VALIDATION (NEW)
  # ===========================================================================
  # Validate Numeric questions for Min/Max values and bin definitions
  numeric_questions <- questions_df[questions_df$Variable_Type == "Numeric", ]

  if (nrow(numeric_questions) > 0) {
    for (i in seq_len(nrow(numeric_questions))) {
      numeric_q_info <- numeric_questions[i, ]
      q_code <- trimws(numeric_q_info$QuestionCode)

      # Get options for this question (bins, if defined)
      q_options <- survey_structure$options[
        trimws(survey_structure$options$QuestionCode) == q_code,
      ]

      # Validate this numeric question
      error_log <- validate_numeric_question(
        numeric_q_info,
        q_options,
        survey_data,
        error_log
      )
    }
  }
  # ===========================================================================
  # END OF V10.0.0 ADDITION
  # ===========================================================================

  if (verbose) cat("✓ Data structure validation complete\n")

  return(error_log)
}

# ==============================================================================
# END OF VALIDATION_DATA.R
# ==============================================================================
