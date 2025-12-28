# ==============================================================================
# STRUCTURE VALIDATORS - V10.1 (Phase 2 Refactoring)
# ==============================================================================
# Survey structure validation helper functions
# Extracted from validation.R for better modularity
#
# VERSION HISTORY:
# V10.1 - Extracted from validation.R (2025)
#        - Uses tabs_source() for reliable subdirectory loading
#        - All structure validation helper functions
#
# DEPENDENCIES:
# - log_issue() from shared_functions.R (logging_utils.R)
# - tabs_refuse() from 00_guard.R
#
# USAGE:
# These functions are sourced by validation.R using:
#   tabs_source("validation", "structure_validators.R")
# ==============================================================================

# ==============================================================================
# SURVEY STRUCTURE HELPER FUNCTIONS (Internal)
# ==============================================================================

#' Check for duplicate question codes
#' @keywords internal
check_duplicate_questions <- function(questions_df, error_log) {
  dup_questions <- questions_df$QuestionCode[duplicated(questions_df$QuestionCode)]
  if (length(dup_questions) > 0) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Duplicate Questions",
      sprintf("Duplicate QuestionCodes found: %s. Each question must have unique code.",
              paste(unique(dup_questions), collapse = ", ")),
      "",
      "Error"
    )
  }
  return(error_log)
}

#' Check for questions without options
#' @keywords internal
check_missing_options <- function(questions_df, options_df, error_log) {
  question_codes <- unique(questions_df$QuestionCode)
  option_questions <- unique(options_df$QuestionCode)

  questions_no_options <- setdiff(question_codes, option_questions)
  open_end_questions <- questions_df$QuestionCode[questions_df$Variable_Type == "Open_End"]
  numeric_questions <- questions_df$QuestionCode[questions_df$Variable_Type == "Numeric"]
  multi_mention_questions <- questions_df$QuestionCode[questions_df$Variable_Type == "Multi_Mention"]

  # Exclude Open_End, Numeric, and Multi_Mention from this check
  # Multi_Mention options use column names (Q01_1, Q01_2) not base code (Q01)
  questions_no_options <- setdiff(questions_no_options, c(open_end_questions, numeric_questions, multi_mention_questions))

  if (length(questions_no_options) > 0) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Missing Options",
      sprintf("Questions without options (may cause errors): %s",
              paste(questions_no_options, collapse = ", ")),
      "",
      "Warning"
    )
  }
  return(error_log)
}

#' Check for options without matching questions
#' @keywords internal
check_orphan_options <- function(questions_df, options_df, error_log) {
  question_codes <- unique(questions_df$QuestionCode)
  option_questions <- unique(options_df$QuestionCode)

  # For Multi_Mention, generate expected column codes
  valid_option_codes <- question_codes

  for (i in seq_len(nrow(questions_df))) {
    if (questions_df$Variable_Type[i] == "Multi_Mention") {
      q_code <- questions_df$QuestionCode[i]
      num_cols <- suppressWarnings(as.numeric(questions_df$Columns[i]))

      if (!is.na(num_cols) && num_cols > 0) {
        # Add Q01_1, Q01_2, ..., Q01_N to valid codes
        multi_cols <- paste0(q_code, "_", seq_len(num_cols))
        valid_option_codes <- c(valid_option_codes, multi_cols)
      }
    }
  }

  orphan_options <- setdiff(option_questions, valid_option_codes)
  if (length(orphan_options) > 0) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Orphan Options",
      sprintf("Options exist for non-existent questions: %s. Remove these from options table.",
              paste(orphan_options, collapse = ", ")),
      "",
      "Warning"
    )
  }
  return(error_log)
}

#' Validate Variable_Type values
#' @keywords internal
check_variable_types <- function(questions_df, error_log) {
  valid_types <- c(
    "Single_Response", "Multi_Mention", "Rating", "Likert", "NPS",
    "Ranking", "Numeric", "Open_End", "Grid_Single", "Grid_Multi"
  )

  invalid_types <- questions_df$Variable_Type[!questions_df$Variable_Type %in% valid_types]
  if (length(invalid_types) > 0) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Invalid Variable_Type",
      sprintf(
        "Invalid Variable_Type values found: %s. Valid types: %s",
        paste(unique(invalid_types), collapse = ", "),
        paste(valid_types, collapse = ", ")
      ),
      "",
      "Error"
    )
  }
  return(error_log)
}

#' Validate Ranking questions have Ranking_Format
#' @keywords internal
check_ranking_questions <- function(questions_df, error_log) {
  ranking_questions <- questions_df[questions_df$Variable_Type == "Ranking", ]
  if (nrow(ranking_questions) > 0) {
    if (!"Ranking_Format" %in% names(questions_df)) {
      error_log <- log_issue(
        error_log,
        "Validation",
        "Missing Ranking_Format Column",
        "Ranking questions exist but Ranking_Format column missing in questions table. Add this column.",
        "",
        "Error"
      )
    } else {
      missing_format <- ranking_questions$QuestionCode[
        is.na(ranking_questions$Ranking_Format) |
        trimws(ranking_questions$Ranking_Format) == ""
      ]
      if (length(missing_format) > 0) {
        error_log <- log_issue(
          error_log,
          "Validation",
          "Missing Ranking_Format Values",
          sprintf(
            "Ranking questions missing format specification: %s. Specify 'Best_to_Worst' or 'Worst_to_Best'.",
            paste(missing_format, collapse = ", ")
          ),
          "",
          "Error"
        )
      }
    }
  }
  return(error_log)
}

#' Validate Multi_Mention questions have Columns specified
#' @keywords internal
check_multi_mention_questions <- function(questions_df, error_log) {
  multi_questions <- questions_df[questions_df$Variable_Type == "Multi_Mention", ]
  if (nrow(multi_questions) > 0) {
    if (!"Columns" %in% names(questions_df)) {
      error_log <- log_issue(
        error_log,
        "Validation",
        "Missing Columns Specification",
        "Multi_Mention questions exist but Columns column missing. Add this column.",
        "",
        "Error"
      )
    } else {
      missing_cols <- multi_questions$QuestionCode[
        is.na(multi_questions$Columns) |
        trimws(as.character(multi_questions$Columns)) == "" |
        suppressWarnings(is.na(as.numeric(multi_questions$Columns)))
      ]
      if (length(missing_cols) > 0) {
        error_log <- log_issue(
          error_log,
          "Validation",
          "Missing Columns Values",
          sprintf(
            "Multi_Mention questions missing Columns specification: %s. Specify number of response columns.",
            paste(missing_cols, collapse = ", ")
          ),
          "",
          "Error"
        )
      }
    }
  }
  return(error_log)
}
