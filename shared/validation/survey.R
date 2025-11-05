# ==============================================================================
# TURAS VALIDATION: SURVEY STRUCTURE MODULE
# ==============================================================================
# Survey structure validation functions
# Part of Turas Analytics Toolkit - Phase 4 Migration
#
# MIGRATED FROM: validation.r (lines 111-319)
# DATE: October 24, 2025
# STATUS: Phase 4 - Module 1
#
# DESCRIPTION:
#   Validates survey structure completeness and integrity including:
#   - Question code uniqueness
#   - Required options for questions
#   - Orphan option detection
#   - Variable type validation
#   - Question-specific requirements (ranking format, multi-mention columns)
#
# DEPENDENCIES:
#   - core/validation.R (validate_data_frame, validate_column_exists)
#   - core/logging.R (log_issue)
#   - core/utilities.R (safe_equal)
#
# EXPORTED FUNCTIONS:
#   - validate_survey_structure() - Main survey structure validator
#   - is_blank() - Helper to check if column is empty (type-safe)
# ==============================================================================

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Check if column is empty (type-safe)
#'
#' Handles character vs numeric columns correctly:
#' - Character/factor: empty if NA or whitespace-only strings
#' - Numeric: empty if NA
#'
#' @param x Vector to check
#' @return Logical, TRUE if all values are "empty"
#' @keywords internal
#' @examples
#' is_blank(c(NA, "", "  "))  # TRUE
#' is_blank(c(1, 2, 3))       # FALSE
#' is_blank(c(NA, NA, NA))    # TRUE
is_blank <- function(x) {
  if (is.character(x) || is.factor(x)) {
    # Character/factor: check for NA or empty strings
    x_char <- as.character(x)
    all(is.na(x_char) | trimws(x_char) == "")
  } else {
    # Numeric/other: check for NA only
    all(is.na(x))
  }
}

# ==============================================================================
# MAIN VALIDATION FUNCTION
# ==============================================================================

#' Validate survey structure completeness and integrity
#'
#' Comprehensive validation of survey structure including:
#' - No duplicate question codes (after whitespace trimming)
#' - All questions (except Open_End/Numeric) have options
#' - No orphan options (options without questions)
#' - Variable_Type values are valid
#' - Ranking questions have Ranking_Format specified
#' - Multi_Mention questions have Columns specified
#'
#' @param survey_structure List containing $questions and $options data frames
#' @param error_log Error log data frame (from create_error_log())
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Updated error log data frame with any validation issues
#' @export
#' @examples
#' error_log <- create_error_log()
#' error_log <- validate_survey_structure(survey_structure, error_log)
validate_survey_structure <- function(survey_structure, error_log, verbose = TRUE) {
  
  # ============================================================================
  # INPUT VALIDATION
  # ============================================================================
  
  if (!is.list(survey_structure)) {
    stop("survey_structure must be a list", call. = FALSE)
  }
  
  if (!is.data.frame(error_log)) {
    stop("error_log must be a data frame (use create_error_log())", call. = FALSE)
  }
  
  if (!"questions" %in% names(survey_structure) || !"options" %in% names(survey_structure)) {
    stop("survey_structure must contain $questions and $options data frames", call. = FALSE)
  }
  
  if (verbose) cat("Validating survey structure...\n")
  
  questions_df <- survey_structure$questions
  options_df <- survey_structure$options
  
  # ============================================================================
  # VALIDATE DATA FRAME STRUCTURES
  # ============================================================================
  
  # Validate questions_df structure
  if (!is.data.frame(questions_df) || nrow(questions_df) == 0) {
    stop("survey_structure$questions must be a non-empty data frame", call. = FALSE)
  }
  
  required_q_cols <- c("QuestionCode", "Variable_Type")
  missing_q_cols <- setdiff(required_q_cols, names(questions_df))
  if (length(missing_q_cols) > 0) {
    stop(sprintf(
      "survey_structure$questions missing required columns: %s",
      paste(missing_q_cols, collapse = ", ")
    ), call. = FALSE)
  }
  
  # Validate options_df structure
  if (!is.data.frame(options_df)) {
    stop("survey_structure$options must be a data frame", call. = FALSE)
  }
  
  if (nrow(options_df) > 0 && !"QuestionCode" %in% names(options_df)) {
    stop("survey_structure$options must contain QuestionCode column", call. = FALSE)
  }
  
  # ============================================================================
  # TRIM WHITESPACE ON CODES (V9.9.2 enhancement)
  # ============================================================================
  
  questions_df$QuestionCode <- trimws(questions_df$QuestionCode)
  if (nrow(options_df) > 0) {
    options_df$QuestionCode <- trimws(options_df$QuestionCode)
  }
  
  # ============================================================================
  # CHECK 1: DUPLICATE QUESTION CODES
  # ============================================================================
  
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
  
  # ============================================================================
  # CHECK 2: QUESTIONS WITHOUT OPTIONS
  # ============================================================================
  
  question_codes <- unique(questions_df$QuestionCode)
  option_questions <- unique(options_df$QuestionCode)
  
  questions_no_options <- setdiff(question_codes, option_questions)
  
  # Exclude question types that don't need options in the Options sheet
  open_end_questions <- questions_df$QuestionCode[questions_df$Variable_Type == "Open_End"]
  numeric_questions <- questions_df$QuestionCode[questions_df$Variable_Type == "Numeric"]
  multi_mention_questions <- questions_df$QuestionCode[questions_df$Variable_Type == "Multi_Mention"]
  
  # Multi_Mention options use column names (Q01_1, Q01_2) not base code (Q01)
  questions_no_options <- setdiff(
    questions_no_options, 
    c(open_end_questions, numeric_questions, multi_mention_questions)
  )
  
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
  
  # ============================================================================
  # CHECK 3: ORPHAN OPTIONS (Options without matching questions)
  # ============================================================================
  
  # Build list of valid option codes including Multi_Mention column codes
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
  
  # ============================================================================
  # CHECK 4: VARIABLE_TYPE VALUES
  # ============================================================================
  
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
  
  # ============================================================================
  # CHECK 5: RANKING QUESTIONS HAVE RANKING_FORMAT
  # ============================================================================
  
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
  
  # ============================================================================
  # CHECK 6: MULTI_MENTION QUESTIONS HAVE COLUMNS SPECIFIED
  # ============================================================================
  
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
  
  # ============================================================================
  # COMPLETE
  # ============================================================================
  
  if (verbose) cat("✓ Survey structure validation complete\n")
  
  return(error_log)
}
