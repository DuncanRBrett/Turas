# ==============================================================================
# STRUCTURE VALIDATORS - TURAS V10.1
# ==============================================================================
# Survey structure validation functions
# Extracted from validation.R for better modularity
#
# Validates:
#  - Unique question codes (no duplicates)
#  - Questions have associated options (where required)
#  - No orphan options (options for non-existent questions)
#  - Valid Variable_Type values
#  - Ranking questions have format specification
#  - Multi_Mention questions have column count
#
# VERSION HISTORY:
# V10.1 - Extracted from validation.R (2025)
#        - Part of Phase 2 refactoring
#        - Zero functional changes - pure extraction
# ==============================================================================

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

# Source shared functions for log_issue() and tabs_refuse()
if (!exists("log_issue")) {
  # Use local variable to avoid overwriting global script_dir
  this_script_dir <- tryCatch({
    dirname(sys.frame(1)$ofile)
  }, error = function(e) getwd())
  if (is.null(this_script_dir) || is.na(this_script_dir) || length(this_script_dir) == 0) {
    this_script_dir <- getwd()
  }
  source(file.path(dirname(this_script_dir), "shared_functions.R"), local = FALSE)
}

# ==============================================================================
# VALIDATION FUNCTIONS
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

# ==============================================================================
# ORCHESTRATOR
# ==============================================================================

#' Validate survey structure completeness and integrity
#'
#' CHECKS PERFORMED:
#' - No duplicate question codes (after whitespace trimming)
#' - All questions (except Open_End/Numeric) have options
#' - No orphan options (options without questions)
#' - Variable_Type values are valid
#' - Ranking questions have Ranking_Format
#' - Multi_Mention questions have Columns specified
#'
#' V9.9.2: Trims whitespace on codes before duplicate checks
#'
#' DESIGN: Collects all issues before returning (doesn't stop mid-validation)
#'
#' @param survey_structure Survey structure list with $questions and $options
#' @param error_log Error log data frame (created by create_error_log())
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Updated error log data frame
#' @export
validate_survey_structure <- function(survey_structure, error_log, verbose = TRUE) {
  # Input validation
  if (!is.list(survey_structure)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid survey_structure Type",
      problem = "survey_structure must be a list but received a non-list object.",
      why_it_matters = "The validation function requires survey_structure to be a list containing questions and options.",
      how_to_fix = "Ensure survey_structure is a list with $questions and $options elements."
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

  if (!"questions" %in% names(survey_structure) || !"options" %in% names(survey_structure)) {
    tabs_refuse(
      code = "ARG_MISSING_ELEMENT",
      title = "Missing Required Elements",
      problem = "survey_structure must contain both $questions and $options elements.",
      why_it_matters = "Both questions and options tables are required for survey structure validation.",
      how_to_fix = "Ensure survey_structure list has both $questions and $options data frames."
    )
  }

  if (verbose) cat("Validating survey structure...\n")

  questions_df <- survey_structure$questions
  options_df <- survey_structure$options

  # Validate questions_df structure
  if (!is.data.frame(questions_df) || nrow(questions_df) == 0) {
    tabs_refuse(
      code = "DATA_INVALID_STRUCTURE",
      title = "Invalid Questions Structure",
      problem = "survey_structure$questions must be a non-empty data frame but is either not a data frame or has zero rows.",
      why_it_matters = "The questions table is essential for defining survey structure and must contain question definitions.",
      how_to_fix = "Ensure survey_structure$questions is a valid data frame with at least one row."
    )
  }

  required_q_cols <- c("QuestionCode", "Variable_Type")
  missing_q_cols <- setdiff(required_q_cols, names(questions_df))
  if (length(missing_q_cols) > 0) {
    tabs_refuse(
      code = "DATA_MISSING_COLUMNS",
      title = "Missing Required Columns",
      problem = sprintf("survey_structure$questions is missing required columns: %s",
                       paste(missing_q_cols, collapse = ", ")),
      why_it_matters = "QuestionCode and Variable_Type columns are mandatory for processing survey questions.",
      how_to_fix = c(
        sprintf("Add the following columns to questions table: %s", paste(missing_q_cols, collapse = ", ")),
        "Verify the questions table structure matches the expected format"
      )
    )
  }

  # Validate options_df structure
  if (!is.data.frame(options_df)) {
    tabs_refuse(
      code = "DATA_INVALID_STRUCTURE",
      title = "Invalid Options Structure",
      problem = "survey_structure$options must be a data frame but received a non-data-frame object.",
      why_it_matters = "The options table is required for defining response options for survey questions.",
      how_to_fix = "Ensure survey_structure$options is a valid data frame."
    )
  }

  if (nrow(options_df) > 0 && !"QuestionCode" %in% names(options_df)) {
    tabs_refuse(
      code = "DATA_MISSING_COLUMNS",
      title = "Missing QuestionCode Column",
      problem = "survey_structure$options must contain a QuestionCode column.",
      why_it_matters = "QuestionCode column is required to link options to their respective questions.",
      how_to_fix = "Add a QuestionCode column to the options table."
    )
  }

  # V9.9.2: Trim whitespace on codes before duplicate checks
  questions_df$QuestionCode <- trimws(questions_df$QuestionCode)
  if (nrow(options_df) > 0) {
    options_df$QuestionCode <- trimws(options_df$QuestionCode)
  }

  # Run all validation checks
  error_log <- check_duplicate_questions(questions_df, error_log)
  error_log <- check_missing_options(questions_df, options_df, error_log)
  error_log <- check_orphan_options(questions_df, options_df, error_log)
  error_log <- check_variable_types(questions_df, error_log)
  error_log <- check_ranking_questions(questions_df, error_log)
  error_log <- check_multi_mention_questions(questions_df, error_log)

  if (verbose) cat("✓ Survey structure validation complete\n")

  return(error_log)
}
