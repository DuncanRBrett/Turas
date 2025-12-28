# ==============================================================================
# VALIDATION V10.1 - PHASE 2 REFACTORING
# ==============================================================================
# Input validation and data quality checks
# Part of R Survey Analytics Toolkit
#
# VERSION HISTORY:
# V10.1  - Phase 2 refactoring (2025-12-28)
#          - EXTRACTED: Structure validators to validation/structure_validators.R
#          - ADDED: tabs_source() for subdirectory loading
#          - Reduced file size by 162 lines
# V9.9.5 - External review fixes (2025-10-16)
#          - FIXED: Added integer64 and labelled type support
#          - FIXED: Made weight validation thresholds configurable
#          - weight_na_threshold (default: 10)
#          - weight_zero_threshold (default: 5)
#          - weight_deff_warning (default: 3)
# V9.9.4 - Likert character data fix
#          - FIXED: Accept character/factor data for Likert questions
# V9.9.3 - Final polish (optional enhancements from review)
#          - ADDED: output_format normalization (excel → xlsx in config object)
#          - ADDED: Configurable NA-weight threshold (weight_na_threshold, default: 10)
# V9.9.2 - External review fixes (production hardening)
# V9.9.1 - Production release (aligned with ecosystem V9.9)
# V8.0   - Previous version (incompatible with V9.9 ecosystem)
#
# DESIGN PHILOSOPHY:
# - Fail fast: Stop immediately on critical errors
# - Collect warnings: Log non-critical issues for review
# - Clear messages: Every error/warning is actionable
# - Defensive: Validate all inputs before processing
# - Consistent: All validations follow same patterns
#
# ERROR SEVERITY LEVELS:
# - Error: Blocks execution (data corruption, missing requirements)
# - Warning: Suspicious but not blocking (data quality, best practices)
# - Info: Informational only (successful validations)
# ==============================================================================

SCRIPT_VERSION <- "10.1"

# Maximum decimal places allowed for rounding settings
MAX_DECIMAL_PLACES <- 6

# ==============================================================================
# DEPENDENCIES (V9.9.2)
# ==============================================================================

source_if_exists <- function(file_path) {
  if (file.exists(file_path)) {
    tryCatch({
      # V9.9.2: Use sys.source with local environment to avoid global pollution
      # while still making functions available in caller's environment
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

# Try to source shared_functions.R from expected locations
source_if_exists("shared_functions.R")
source_if_exists("Scripts/shared_functions.R")

# ==============================================================================
# SOURCE PHASE 2 SUBMODULES (V10.1)
# ==============================================================================
# V10.1: Structure validation functions extracted to validation/structure_validators.R
# Use tabs_source() for reliable subdirectory loading

if (exists("tabs_source", mode = "function")) {
  # Use the Phase 2 sourcing mechanism
  tabs_source("validation", "structure_validators.R")
  tabs_source("validation", "weight_validators.R")
  tabs_source("validation", "config_validators.R")
} else {
  # Fallback: try to source directly (less reliable but maintains backward compat)
  .validation_dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) getwd())
  .structure_validators_path <- file.path(.validation_dir, "validation", "structure_validators.R")
  if (file.exists(.structure_validators_path)) {
    source(.structure_validators_path)
  }
  .weight_validators_path <- file.path(.validation_dir, "validation", "weight_validators.R")
  if (file.exists(.weight_validators_path)) {
    source(.weight_validators_path)
  }
  .config_validators_path <- file.path(.validation_dir, "validation", "config_validators.R")
  if (file.exists(.config_validators_path)) {
    source(.config_validators_path)
  }
}

# ==============================================================================
# HELPER FUNCTIONS (V9.9.2)
# ==============================================================================

#' Check if column is empty (type-safe)
#'
#' V9.9.2: Handles character vs numeric columns correctly
#' Character: empty if NA or whitespace-only strings
#' Numeric: empty if NA
#'
#' @param x Vector to check
#' @return Logical, TRUE if all values are "empty"
#' @keywords internal
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
# SURVEY STRUCTURE VALIDATION (V10.1 - Phase 2 Refactoring)
# ==============================================================================
# V10.1: Structure helper functions extracted to validation/structure_validators.R
# Functions available after sourcing:
#   - check_duplicate_questions()
#   - check_missing_options()
#   - check_orphan_options()
#   - check_variable_types()
#   - check_ranking_questions()
#   - check_multi_mention_questions()
# ==============================================================================

# ------------------------------------------------------------------------------
# MAIN VALIDATION FUNCTION
# ------------------------------------------------------------------------------

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

# ==============================================================================
# DATA VALIDATION (V9.9.5)
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
# WEIGHTING VALIDATION (V10.1 - Phase 2 Refactoring)
# ==============================================================================
# V10.1: Weight validation functions extracted to validation/weight_validators.R
# Functions available after sourcing:
#   - check_weighting_enabled()
#   - check_weight_variable()
#   - check_weight_column_exists()
#   - check_weight_values_valid()
#   - check_weight_distribution()
#   - validate_weighting_config()
# ==============================================================================

# ==============================================================================
# BASE FILTER VALIDATION (V9.9.2)
# ==============================================================================

#' Validate base filter expression for safety and correctness
#'
#' CHECKS PERFORMED:
#' - Expression is valid R code
#' - Expression returns logical vector
#' - Vector length matches data
#' - Filter retains at least some rows
#' - No unsafe characters or operations
#'
#' V9.9.2 ENHANCEMENTS:
#' - Allows %in% and : operators (common in filters)
#' - Hardened dangerous patterns (::, :::, get, assign, mget, do.call)
#' - Uses enclos = parent.frame() for safer evaluation
#'
#' DESIGN: Comprehensive security checks before evaluating user-provided code
#'
#' @param filter_expression R expression as string
#' @param survey_data Survey data frame
#' @param question_code Question code for logging (optional)
#' @return List with $valid (logical) and $message (character)
#' @export
#' @examples
#' result <- validate_base_filter("AGE %in% 18:24", survey_data)
#' if (!result$valid) stop(result$message)
validate_base_filter <- function(filter_expression, survey_data, question_code = "") {
  # Input validation
  if (!is.data.frame(survey_data)) {
    return(list(
      valid = FALSE,
      message = "survey_data must be a data frame"
    ))
  }
  
  if (nrow(survey_data) == 0) {
    return(list(
      valid = FALSE,
      message = "survey_data is empty (0 rows)"
    ))
  }
  
  # Empty/null filter is valid (no filtering)
  if (is.na(filter_expression) || is.null(filter_expression) || filter_expression == "") {
    return(list(valid = TRUE, message = "No filter"))
  }
  
  # Must be character
  if (!is.character(filter_expression)) {
    return(list(
      valid = FALSE,
      message = sprintf("Filter must be character string, got: %s", class(filter_expression)[1])
    ))
  }
  
  # Clean Unicode characters and special quotes
  filter_expression <- tryCatch({
    # Convert to ASCII, replacing non-ASCII with closest match
    cleaned <- iconv(filter_expression, to = "ASCII//TRANSLIT", sub = "")
    if (is.na(cleaned)) filter_expression else cleaned
  }, error = function(e) filter_expression)
  
  # Replace various Unicode spaces with regular space
  filter_expression <- gsub("[\u00A0\u2000-\u200B\u202F\u205F\u3000]", " ", filter_expression)
  
  # Replace smart quotes with regular quotes
  filter_expression <- gsub("[\u2018\u2019\u201A\u201B]", "'", filter_expression)
  filter_expression <- gsub("[\u201C\u201D\u201E\u201F]", '"', filter_expression)
  
  # Trim whitespace
  filter_expression <- trimws(filter_expression)
  
  # V9.9.2: Check for potentially unsafe characters (NOW INCLUDES % and :)
  # Allow: letters, numbers, underscore, $, ., (), &, |, !, <, >, =, +, -, *, /, ,, quotes, [], space, %, :
  if (grepl("[^A-Za-z0-9_$.()&|!<>= +*/,'\"\\[\\]%:-]", filter_expression)) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Filter contains potentially unsafe characters: '%s'. Use only standard operators and column names.",
        filter_expression
      )
    ))
  }
  
  # V9.9.2: Enhanced dangerous patterns list
  dangerous_patterns <- c(
    "system\\s*\\(",    # system calls
    "eval\\s*\\(",      # eval (nested)
    "source\\s*\\(",    # sourcing code
    "library\\s*\\(",   # loading packages
    "require\\s*\\(",   # loading packages
    "<-",               # assignment
    "<<-",              # global assignment
    "->",               # right assignment
    "->>",              # right global assignment
    "rm\\s*\\(",        # removing objects
    "file\\.",          # file operations
    "sink\\s*\\(",      # sink
    "options\\s*\\(",   # changing options
    "\\.GlobalEnv",     # accessing global env
    "::",               # namespace access (V9.9.2)
    ":::",              # internal namespace access (V9.9.2)
    "get\\s*\\(",       # get function (V9.9.2)
    "assign\\s*\\(",    # assign function (V9.9.2)
    "mget\\s*\\(",      # mget function (V9.9.2)
    "do\\.call\\s*\\(" # do.call function (V9.9.2)
  )
  
  for (pattern in dangerous_patterns) {
    if (grepl(pattern, filter_expression, ignore.case = TRUE)) {
      return(list(
        valid = FALSE,
        message = sprintf(
          "Filter contains unsafe pattern: '%s' not allowed",
          gsub("\\\\s\\*\\\\\\(", "(", pattern)
        )
      ))
    }
  }
  
  # Try to evaluate filter
  tryCatch({
    # V9.9.2: Use enclos = parent.frame() for safer name resolution
    filter_result <- eval(
      parse(text = filter_expression), 
      envir = survey_data,
      enclos = parent.frame()
    )
    
    # Check return type
    if (!is.logical(filter_result)) {
      return(list(
        valid = FALSE,
        message = sprintf(
          "Filter must return logical vector, got: %s. Use logical operators (==, !=, <, >, &, |, %%in%%).",
          class(filter_result)[1]
        )
      ))
    }
    
    # Check length
    if (length(filter_result) != nrow(survey_data)) {
      return(list(
        valid = FALSE,
        message = sprintf(
          "Filter returned %d values but data has %d rows. Check column names and operations.",
          length(filter_result), 
          nrow(survey_data)
        )
      ))
    }
    
    # Check how many rows retained (excluding NAs)
    n_retained <- sum(filter_result, na.rm = TRUE)
    n_total <- nrow(survey_data)
    pct_retained <- round(100 * n_retained / n_total, 1)
    
    if (n_retained == 0) {
      return(list(
        valid = FALSE,
        message = sprintf(
          "Filter retains 0 rows (filters out all data). Expression: '%s'",
          filter_expression
        )
      ))
    }
    
    # Check for too many NAs in filter result
    n_na <- sum(is.na(filter_result))
    pct_na <- round(100 * n_na / n_total, 1)
    
    message_parts <- c(
      sprintf("Filter OK: %d of %d rows (%.1f%%)", n_retained, n_total, pct_retained)
    )
    
    if (n_na > 0) {
      message_parts <- c(
        message_parts,
        sprintf("%d NA values (%.1f%%) treated as FALSE", n_na, pct_na)
      )
    }
    
    return(list(
      valid = TRUE,
      message = paste(message_parts, collapse = "; ")
    ))
    
  }, error = function(e) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Filter evaluation failed: %s. Check column names and syntax. Expression: '%s'",
        conditionMessage(e),
        filter_expression
      )
    ))
  })
}

# ==============================================================================
# CONFIG VALIDATION (V10.1 - Phase 2 Refactoring)
# ==============================================================================
# V10.1: Config validation functions extracted to validation/config_validators.R
# Functions available after sourcing:
#   - check_alpha_config()
#   - check_min_base()
#   - check_decimal_places()
#   - check_numeric_settings()
#   - check_output_format()
#   - validate_crosstab_config()
# ==============================================================================

# ==============================================================================
# NUMERIC QUESTION VALIDATION (V10.0.0 - NEW)
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
# STATISTICAL TEST VALIDATION (V10.1 - NEW)
# ==============================================================================
# Validation utilities for statistical significance tests used in crosstabs
# Ensures test preconditions are met before running statistical tests
# ==============================================================================

# ------------------------------------------------------------------------------
# CHI-SQUARE TEST VALIDATION
# ------------------------------------------------------------------------------

#' Validate Chi-Square Test Preconditions
#'
#' Checks if chi-square test assumptions are met:
#' - Minimum expected cell frequency (typically >= 5)
#' - No more than 20% of cells with expected count < 5
#' - Minimum sample size for meaningful inference
#'
#' @param observed Matrix or data frame of observed frequencies
#' @param min_expected Numeric. Minimum expected frequency per cell (default: 5)
#' @param max_low_expected_pct Numeric. Max percentage of cells with low expected (default: 0.20)
#' @param min_total Numeric. Minimum total sample size (default: 30)
#' @param verbose Logical. Print diagnostic messages (default: FALSE)
#' @return List with $valid (logical), $message (character), $diagnostics (list)
#' @export
#'
#' @examples
#' observed <- matrix(c(10, 20, 30, 40), nrow = 2)
#' result <- validate_chi_square_preconditions(observed)
#' if (!result$valid) warning(result$message)
validate_chi_square_preconditions <- function(observed,
                                               min_expected = 5,
                                               max_low_expected_pct = 0.20,
                                               min_total = 30,
                                               verbose = FALSE) {
  # Input validation
  if (!is.matrix(observed) && !is.data.frame(observed)) {
    return(list(
      valid = FALSE,
      message = "observed must be a matrix or data frame",
      diagnostics = NULL
    ))
  }

  observed <- as.matrix(observed)

  # Check for negative values
  if (any(observed < 0, na.rm = TRUE)) {
    return(list(
      valid = FALSE,
      message = "observed frequencies cannot be negative",
      diagnostics = NULL
    ))
  }

  # Calculate expected frequencies under independence
  row_totals <- rowSums(observed, na.rm = TRUE)
  col_totals <- colSums(observed, na.rm = TRUE)
  grand_total <- sum(observed, na.rm = TRUE)

  # Check minimum sample size
  if (grand_total < min_total) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Total sample size (%d) below minimum (%d) for chi-square test",
        grand_total, min_total
      ),
      diagnostics = list(
        grand_total = grand_total,
        min_required = min_total
      )
    ))
  }

  # Check for zero marginals (would cause division by zero)
  if (any(row_totals == 0) || any(col_totals == 0)) {
    return(list(
      valid = FALSE,
      message = "Chi-square test invalid: one or more rows/columns have zero total",
      diagnostics = list(
        zero_rows = sum(row_totals == 0),
        zero_cols = sum(col_totals == 0)
      )
    ))
  }

  # Calculate expected frequencies
  expected <- outer(row_totals, col_totals) / grand_total

  # Count cells with low expected frequency
  n_cells <- length(expected)
  n_low_expected <- sum(expected < min_expected)
  pct_low_expected <- n_low_expected / n_cells

  # Check if any expected frequency is zero
  if (any(expected == 0)) {
    return(list(
      valid = FALSE,
      message = "Chi-square test invalid: expected frequency is zero for some cells",
      diagnostics = list(
        n_zero_expected = sum(expected == 0)
      )
    ))
  }

  # Check minimum expected frequency rule
  min_exp_value <- min(expected)

  diagnostics <- list(
    grand_total = grand_total,
    n_cells = n_cells,
    n_low_expected = n_low_expected,
    pct_low_expected = pct_low_expected,
    min_expected_value = min_exp_value,
    expected_matrix = expected
  )

  # Cochran's rule: no more than 20% of cells should have expected < 5
  if (pct_low_expected > max_low_expected_pct) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Chi-square test may be unreliable: %.1f%% of cells have expected frequency < %d (max allowed: %.0f%%)",
        pct_low_expected * 100, min_expected, max_low_expected_pct * 100
      ),
      diagnostics = diagnostics
    ))
  }

  # Additional warning for very small expected values
  if (min_exp_value < 1) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Chi-square test unreliable: minimum expected frequency (%.2f) is less than 1",
        min_exp_value
      ),
      diagnostics = diagnostics
    ))
  }

  if (verbose) {
    cat(sprintf("Chi-square preconditions met: n=%d, min_expected=%.2f, low_expected_pct=%.1f%%\n",
                grand_total, min_exp_value, pct_low_expected * 100))
  }

  return(list(
    valid = TRUE,
    message = "Chi-square test preconditions met",
    diagnostics = diagnostics
  ))
}


# ------------------------------------------------------------------------------
# Z-TEST / PROPORTION TEST VALIDATION
# ------------------------------------------------------------------------------

#' Validate Z-Test for Proportions Preconditions
#'
#' Checks if z-test for proportions assumptions are met:
#' - Normal approximation valid (np >= 10 and n(1-p) >= 10)
#' - Minimum sample size
#' - Valid proportion range (0-1)
#'
#' @param n Integer. Sample size
#' @param p Numeric. Observed proportion (0-1)
#' @param min_np Numeric. Minimum for n*p and n*(1-p) (default: 10)
#' @param min_n Numeric. Minimum sample size (default: 30)
#' @param verbose Logical. Print diagnostic messages (default: FALSE)
#' @return List with $valid (logical), $message (character), $diagnostics (list)
#' @export
#'
#' @examples
#' result <- validate_z_test_preconditions(n = 100, p = 0.25)
#' if (!result$valid) warning(result$message)
validate_z_test_preconditions <- function(n,
                                           p,
                                           min_np = 10,
                                           min_n = 30,
                                           verbose = FALSE) {
  # Input validation
  if (!is.numeric(n) || length(n) != 1 || is.na(n)) {
    return(list(
      valid = FALSE,
      message = "n must be a single numeric value",
      diagnostics = NULL
    ))
  }

  if (!is.numeric(p) || length(p) != 1 || is.na(p)) {
    return(list(
      valid = FALSE,
      message = "p must be a single numeric value",
      diagnostics = NULL
    ))
  }

  # Check proportion range
  if (p < 0 || p > 1) {
    return(list(
      valid = FALSE,
      message = sprintf("Proportion p (%.4f) must be between 0 and 1", p),
      diagnostics = list(n = n, p = p)
    ))
  }

  # Check sample size
  if (n < min_n) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Sample size (%d) below minimum (%d) for z-test",
        n, min_n
      ),
      diagnostics = list(n = n, p = p, min_n = min_n)
    ))
  }

  # Calculate np and n(1-p)
  np <- n * p
  nq <- n * (1 - p)

  diagnostics <- list(
    n = n,
    p = p,
    np = np,
    nq = nq,
    min_np = min_np
  )

  # Check normal approximation conditions
  if (np < min_np) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Normal approximation invalid: n*p = %.1f < %d. Consider exact binomial test.",
        np, min_np
      ),
      diagnostics = diagnostics,
      recommendation = "Use exact binomial test instead"
    ))
  }

  if (nq < min_np) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Normal approximation invalid: n*(1-p) = %.1f < %d. Consider exact binomial test.",
        nq, min_np
      ),
      diagnostics = diagnostics,
      recommendation = "Use exact binomial test instead"
    ))
  }

  if (verbose) {
    cat(sprintf("Z-test preconditions met: n=%d, p=%.3f, np=%.1f, nq=%.1f\n",
                n, p, np, nq))
  }

  return(list(
    valid = TRUE,
    message = "Z-test preconditions met",
    diagnostics = diagnostics
  ))
}


# ------------------------------------------------------------------------------
# COLUMN PROPORTION COMPARISON VALIDATION
# ------------------------------------------------------------------------------

#' Validate Column Proportion Comparison Preconditions
#'
#' Checks if two-sample proportion test assumptions are met:
#' - Both samples have adequate size
#' - Normal approximation valid for both proportions
#' - Proportions are meaningfully different from 0 or 1
#'
#' @param n1 Integer. Sample size for group 1
#' @param p1 Numeric. Proportion for group 1
#' @param n2 Integer. Sample size for group 2
#' @param p2 Numeric. Proportion for group 2
#' @param min_n Numeric. Minimum sample size per group (default: 30)
#' @param min_np Numeric. Minimum for n*p and n*(1-p) per group (default: 5)
#' @param verbose Logical. Print diagnostic messages (default: FALSE)
#' @return List with $valid (logical), $message (character), $diagnostics (list)
#' @export
#'
#' @examples
#' result <- validate_column_comparison_preconditions(
#'   n1 = 100, p1 = 0.45,
#'   n2 = 120, p2 = 0.35
#' )
validate_column_comparison_preconditions <- function(n1, p1, n2, p2,
                                                      min_n = 30,
                                                      min_np = 5,
                                                      verbose = FALSE) {
  # Input validation
  if (!is.numeric(n1) || !is.numeric(n2) || !is.numeric(p1) || !is.numeric(p2)) {
    return(list(
      valid = FALSE,
      message = "All inputs must be numeric",
      diagnostics = NULL
    ))
  }

  # Check proportion ranges
  if (p1 < 0 || p1 > 1 || p2 < 0 || p2 > 1) {
    return(list(
      valid = FALSE,
      message = "Proportions must be between 0 and 1",
      diagnostics = list(p1 = p1, p2 = p2)
    ))
  }

  # Check sample sizes
  if (n1 < min_n || n2 < min_n) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Sample sizes (n1=%d, n2=%d) below minimum (%d) for reliable comparison",
        n1, n2, min_n
      ),
      diagnostics = list(n1 = n1, n2 = n2, min_n = min_n)
    ))
  }

  # Calculate np and nq for both groups
  np1 <- n1 * p1
  nq1 <- n1 * (1 - p1)
  np2 <- n2 * p2
  nq2 <- n2 * (1 - p2)

  diagnostics <- list(
    n1 = n1, p1 = p1, np1 = np1, nq1 = nq1,
    n2 = n2, p2 = p2, np2 = np2, nq2 = nq2,
    min_np = min_np
  )

  # Check normal approximation for group 1
  if (np1 < min_np || nq1 < min_np) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Normal approximation invalid for group 1: np1=%.1f, nq1=%.1f (min: %d)",
        np1, nq1, min_np
      ),
      diagnostics = diagnostics,
      recommendation = "Consider Fisher's exact test or increase sample size"
    ))
  }

  # Check normal approximation for group 2
  if (np2 < min_np || nq2 < min_np) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Normal approximation invalid for group 2: np2=%.1f, nq2=%.1f (min: %d)",
        np2, nq2, min_np
      ),
      diagnostics = diagnostics,
      recommendation = "Consider Fisher's exact test or increase sample size"
    ))
  }

  # Check for extreme proportions (may cause instability)
  extreme_threshold <- 0.01
  if (p1 < extreme_threshold || p1 > (1 - extreme_threshold) ||
      p2 < extreme_threshold || p2 > (1 - extreme_threshold)) {
    diagnostics$warning <- "One or more proportions are extreme (<1% or >99%)"
  }

  if (verbose) {
    cat(sprintf("Column comparison preconditions met: n1=%d, n2=%d, p1=%.3f, p2=%.3f\n",
                n1, n2, p1, p2))
  }

  return(list(
    valid = TRUE,
    message = "Column comparison preconditions met",
    diagnostics = diagnostics
  ))
}


# ------------------------------------------------------------------------------
# SIGNIFICANCE TEST RESULT VALIDATION
# ------------------------------------------------------------------------------

#' Validate Significance Test Result
#'
#' Validates the output of a significance test for data quality issues:
#' - P-value in valid range [0, 1]
#' - Test statistic is finite
#' - Degrees of freedom are positive (if applicable)
#' - Effect size is within expected bounds
#'
#' @param p_value Numeric. P-value from the test
#' @param test_statistic Numeric. Test statistic (chi-square, z, t, etc.)
#' @param df Numeric. Degrees of freedom (optional, for chi-square/t tests)
#' @param effect_size Numeric. Effect size (optional, e.g., Cramér's V, Cohen's d)
#' @param test_type Character. Type of test for validation rules
#' @return List with $valid (logical), $message (character), $warnings (character vector)
#' @export
#'
#' @examples
#' result <- validate_significance_result(
#'   p_value = 0.023,
#'   test_statistic = 12.45,
#'   df = 4,
#'   test_type = "chi_square"
#' )
validate_significance_result <- function(p_value,
                                          test_statistic = NULL,
                                          df = NULL,
                                          effect_size = NULL,
                                          test_type = c("chi_square", "z_test", "t_test", "proportion")) {

  test_type <- match.arg(test_type)
  warnings <- character(0)

  # Validate p-value
  if (is.null(p_value) || is.na(p_value)) {
    return(list(
      valid = FALSE,
      message = "P-value is missing (NULL or NA)",
      warnings = warnings
    ))
  }

  if (!is.numeric(p_value)) {
    return(list(
      valid = FALSE,
      message = sprintf("P-value must be numeric, got: %s", class(p_value)[1]),
      warnings = warnings
    ))
  }

  if (p_value < 0 || p_value > 1) {
    return(list(
      valid = FALSE,
      message = sprintf("P-value (%.6f) outside valid range [0, 1]", p_value),
      warnings = warnings
    ))
  }

  # Validate test statistic
  if (!is.null(test_statistic)) {
    if (!is.finite(test_statistic)) {
      return(list(
        valid = FALSE,
        message = sprintf("Test statistic is not finite: %s", test_statistic),
        warnings = warnings
      ))
    }

    # Chi-square and F statistics must be non-negative
    if (test_type %in% c("chi_square") && test_statistic < 0) {
      return(list(
        valid = FALSE,
        message = sprintf("Chi-square statistic (%.4f) cannot be negative", test_statistic),
        warnings = warnings
      ))
    }
  }

  # Validate degrees of freedom
  if (!is.null(df)) {
    if (!is.finite(df) || df <= 0) {
      return(list(
        valid = FALSE,
        message = sprintf("Degrees of freedom (%.2f) must be positive and finite", df),
        warnings = warnings
      ))
    }

    # Check for suspiciously small df
    if (df < 1 && test_type %in% c("chi_square", "t_test")) {
      warnings <- c(warnings, sprintf(
        "Very small degrees of freedom (%.2f) may indicate insufficient data",
        df
      ))
    }
  }

  # Validate effect size
  if (!is.null(effect_size)) {
    if (!is.finite(effect_size)) {
      warnings <- c(warnings, "Effect size is not finite - interpret with caution")
    } else {
      # Cramér's V should be in [0, 1]
      if (test_type == "chi_square" && (effect_size < 0 || effect_size > 1)) {
        warnings <- c(warnings, sprintf(
          "Cramér's V (%.4f) outside expected range [0, 1]",
          effect_size
        ))
      }

      # Cohen's d typically |d| < 5 for realistic effects
      if (test_type == "t_test" && abs(effect_size) > 5) {
        warnings <- c(warnings, sprintf(
          "Unusually large effect size (d = %.2f) - verify data quality",
          effect_size
        ))
      }
    }
  }

  # Check for suspiciously small p-values (potential numerical issues)
  if (p_value < 1e-15) {
    warnings <- c(warnings, sprintf(
      "Extremely small p-value (%.2e) may indicate numerical precision issues",
      p_value
    ))
  }

  # Check for p-value exactly 0 or 1 (usually indicates edge case)
  if (p_value == 0) {
    warnings <- c(warnings, "P-value is exactly 0 - may indicate extreme test statistic or calculation issue")
  }

  if (p_value == 1) {
    warnings <- c(warnings, "P-value is exactly 1 - may indicate no variation or calculation issue")
  }

  return(list(
    valid = TRUE,
    message = "Significance test result is valid",
    warnings = warnings
  ))
}


# ------------------------------------------------------------------------------
# BASE SIZE VALIDATION FOR SIGNIFICANCE TESTING
# ------------------------------------------------------------------------------

#' Validate Base Sizes for Significance Testing
#'
#' Checks if base sizes are adequate for reliable significance testing:
#' - Minimum base size per column
#' - Effective base size for weighted data
#' - Warning for highly variable base sizes
#'
#' @param base_sizes Numeric vector. Base sizes for each column
#' @param effective_bases Numeric vector. Effective base sizes (optional, for weighted data)
#' @param min_base Numeric. Minimum base size for testing (default: 30)
#' @param warn_ratio Numeric. Warn if max/min base ratio exceeds this (default: 10)
#' @param column_names Character vector. Column names for reporting (optional)
#' @return List with $valid (logical), $message (character), $details (list)
#' @export
validate_base_sizes_for_testing <- function(base_sizes,
                                             effective_bases = NULL,
                                             min_base = 30,
                                             warn_ratio = 10,
                                             column_names = NULL) {
  # Input validation
  if (!is.numeric(base_sizes) || length(base_sizes) == 0) {
    return(list(
      valid = FALSE,
      message = "base_sizes must be a non-empty numeric vector",
      details = NULL
    ))
  }

  # Check for non-positive base sizes
  if (any(base_sizes <= 0, na.rm = TRUE)) {
    zero_cols <- which(base_sizes <= 0)
    col_labels <- if (!is.null(column_names) && length(column_names) >= max(zero_cols)) {
      column_names[zero_cols]
    } else {
      paste("Column", zero_cols)
    }

    return(list(
      valid = FALSE,
      message = sprintf(
        "Zero or negative base sizes found in: %s",
        paste(col_labels, collapse = ", ")
      ),
      details = list(
        zero_base_columns = zero_cols,
        zero_base_labels = col_labels
      )
    ))
  }

  details <- list(
    base_sizes = base_sizes,
    n_columns = length(base_sizes),
    min_base_size = min(base_sizes, na.rm = TRUE),
    max_base_size = max(base_sizes, na.rm = TRUE)
  )

  # Check minimum base size
  below_min <- base_sizes < min_base
  if (any(below_min, na.rm = TRUE)) {
    low_cols <- which(below_min)
    col_labels <- if (!is.null(column_names) && length(column_names) >= max(low_cols)) {
      column_names[low_cols]
    } else {
      paste("Column", low_cols)
    }

    details$low_base_columns <- low_cols
    details$low_base_labels <- col_labels

    return(list(
      valid = FALSE,
      message = sprintf(
        "%d column(s) below minimum base size (%d): %s. Significance tests suppressed for these columns.",
        sum(below_min),
        min_base,
        paste(col_labels, collapse = ", ")
      ),
      details = details
    ))
  }

  # Check base size ratio
  base_ratio <- details$max_base_size / details$min_base_size
  details$base_ratio <- base_ratio

  warnings <- character(0)

  if (base_ratio > warn_ratio) {
    warnings <- c(warnings, sprintf(
      "Large base size variation (ratio %.1f:1). Comparison power may vary significantly.",
      base_ratio
    ))
  }

  # Check effective bases if provided
  if (!is.null(effective_bases)) {
    if (length(effective_bases) != length(base_sizes)) {
      warnings <- c(warnings, "effective_bases length doesn't match base_sizes - ignoring")
    } else {
      details$effective_bases <- effective_bases
      details$min_effective <- min(effective_bases, na.rm = TRUE)

      # Design effect warning
      deff <- base_sizes / effective_bases
      deff <- deff[is.finite(deff)]
      if (length(deff) > 0 && max(deff) > 2) {
        warnings <- c(warnings, sprintf(
          "High design effect detected (max deff = %.2f). Significance tests may be anti-conservative.",
          max(deff)
        ))
      }

      # Check effective base below minimum
      if (details$min_effective < min_base) {
        warnings <- c(warnings, sprintf(
          "Minimum effective base (%.1f) below threshold (%d) due to weighting.",
          details$min_effective, min_base
        ))
      }
    }
  }

  details$warnings <- warnings

  return(list(
    valid = TRUE,
    message = if (length(warnings) > 0) {
      paste("Base sizes adequate with warnings:", paste(warnings, collapse = "; "))
    } else {
      "Base sizes adequate for significance testing"
    },
    details = details
  ))
}


# ==============================================================================
# MASTER VALIDATION (V9.9.2)
# ==============================================================================

#' Run all validation checks and report results
#'
#' DESIGN:
#' - Runs all validation functions in sequence
#' - Collects all errors and warnings
#' - Stops execution only if critical errors found
#' - Provides clear summary of issues
#'
#' V9.9.2: Added verbose parameter for quiet mode (unit tests, batch, Shiny)
#'
#' ERROR HANDLING:
#' - Errors: Stop execution (data corruption, missing requirements)
#' - Warnings: Continue but log (data quality, best practices)
#' - Info: Successful validations logged to console (if verbose)
#'
#' @param survey_structure Survey structure list
#' @param survey_data Survey data frame
#' @param config Configuration list
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Error log data frame (stops if critical errors found)
#' @export
#' @examples
#' # Standard mode (prints progress)
#' error_log <- run_all_validations(survey_structure, survey_data, config)
#' 
#' # Quiet mode (for unit tests or batch processing)
#' error_log <- run_all_validations(survey_structure, survey_data, config, verbose = FALSE)
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

# ==============================================================================
# MAINTENANCE DOCUMENTATION
# ==============================================================================
#
# OVERVIEW:
# This script performs comprehensive validation of survey data, structure,
# and configuration before analysis. It follows fail-fast principles for
# critical errors while collecting warnings for review.
#
# V10.1 ENHANCEMENTS (STATISTICAL TEST VALIDATION):
# 1. Chi-square test validation: validate_chi_square_preconditions()
#    - Checks expected cell frequencies (Cochran's rule)
#    - Validates minimum sample size
#    - Reports detailed diagnostics
# 2. Z-test/proportion validation: validate_z_test_preconditions()
#    - Checks normal approximation validity (np >= 10, nq >= 10)
#    - Recommends exact binomial test when appropriate
# 3. Column comparison validation: validate_column_comparison_preconditions()
#    - Two-sample proportion test assumptions
#    - Validates both groups have adequate sizes
# 4. Result validation: validate_significance_result()
#    - P-value range validation
#    - Test statistic validity checks
#    - Effect size bounds checking
# 5. Base size validation: validate_base_sizes_for_testing()
#    - Minimum base size per column
#    - Design effect warnings for weighted data
#    - Base size ratio warnings
#
# V9.9.5 ENHANCEMENTS (EXTERNAL REVIEW FIXES):
# 1. Type coverage: Added integer64 (data.table, DB extracts) and labelled (haven)
# 2. Configurable thresholds: All weight validation thresholds now configurable
#    - weight_na_threshold (default: 10)
#    - weight_zero_threshold (default: 5)
#    - weight_deff_warning (default: 3)
#
# V9.9.4 ENHANCEMENTS:
# 1. Likert character data: Accept character/factor for Likert questions
#    - Text responses ("Not at all", "Somewhat") are valid and common
#    - These get mapped to numeric via Options sheet during analysis
#
# V9.9.3 ENHANCEMENTS:
# 1. Output format normalization: "excel" → "xlsx" in config object
# 2. Configurable NA threshold: weight_na_threshold parameter
#
# V9.9.2 IMPROVEMENTS (EXTERNAL REVIEW):
# 1. Filter whitelist: Now allows %in% and : operators
# 2. Enhanced security: Added ::, :::, get, assign, mget, do.call blocks
# 3. Type-safe checks: is_blank() function handles character vs numeric
# 4. Type validation: Validates data types per Variable_Type
# 5. Design effect: Reports Kish deff in weight validation
# 6. All-equal weights: Detects SD ≈ 0 (weights not applied)
# 7. Whitespace trimming: Codes trimmed before duplicate checks
# 8. Verbose parameter: Allows quiet mode for tests/batch
# 9. Enclos parameter: Safer filter evaluation
# 10. sys.source: Better environment handling
#
# TESTING PROTOCOL:
# 1. Valid inputs: All validations pass
# 2. Invalid inputs: Appropriate errors/warnings
# 3. Edge cases: Empty data, missing columns, null values
# 4. Filter validation: %in%, :, and dangerous patterns
# 5. Weight validation: All-equal, design effect thresholds
# 6. Config validation: alpha conversion, output format normalization
# 7. Verbose modes: Output suppression works correctly
# 8. Type validation: Correct types per Variable_Type
# 9. V9.9.3: NA threshold configurability, format normalization
# 10. V9.9.4: Character/factor accepted for Likert questions
# 11. V9.9.5: integer64 and labelled support, configurable thresholds
# 12. V10.1: Chi-square precondition validation (Cochran's rule)
# 13. V10.1: Z-test normal approximation validation
# 14. V10.1: Column comparison precondition validation
# 15. V10.1: Significance result validation (p-value, test statistic, df)
# 16. V10.1: Base size validation for significance testing
#
# DEPENDENCY MAP:
#
# validation.R (THIS FILE)
#   ├─→ Used by: run_crosstabs.r (pre-execution checks)
#   ├─→ Depends on: shared_functions.R (log_issue, create_error_log)
#   └─→ External packages: (base R only)
#
# CRITICAL FUNCTIONS:
# - run_all_validations(): Main entry point, stops on errors
# - validate_base_filter(): Security-critical (evaluates user code)
# - validate_weighting_config(): Data quality critical
# - is_blank(): Type-safe empty check (internal helper)
# - validate_chi_square_preconditions(): Chi-square test assumption check
# - validate_z_test_preconditions(): Z-test normal approximation check
# - validate_column_comparison_preconditions(): Two-sample proportion test check
# - validate_significance_result(): Test result validation
# - validate_base_sizes_for_testing(): Base size adequacy check
#
# ERROR SEVERITY GUIDELINES:
# - Error: Stops execution (missing data, invalid config, security issues)
# - Warning: Continues but flags (data quality, best practices, deprecations)
# - Info: Successful validations (console only, not logged)
#
# SECURITY NOTES:
# - validate_base_filter() performs comprehensive security checks
# - Blocks dangerous patterns (system, eval, file ops, namespace access, etc.)
# - Sanitizes Unicode and special characters
# - Uses enclos = parent.frame() for controlled evaluation
# - NEVER eval() user code without these checks
#
# BACKWARD COMPATIBILITY:
# - V8.0 → V9.9.5: significance_level → alpha (warning, auto-converts)
# - V9.9.1 → V9.9.5: NON-BREAKING (additions only)
# - V9.9.2 → V9.9.5: NON-BREAKING (enhancements only)
# - V9.9.3 → V9.9.5: NON-BREAKING (Likert accepts more types)
# - V9.9.4 → V9.9.5: NON-BREAKING (more type support, configurable thresholds)
# - All V8.0 functionality preserved
#
# COMMON ISSUES:
# 1. "Missing column": Check Survey_Structure vs actual data columns
# 2. "Filter evaluation failed": Check column names, use %in% for sets
# 3. "Weight column not found": Verify weight_variable config
# 4. "Invalid alpha": Use 0.05 (not 0.95) for 95% CI
# 5. "Unsafe pattern": Check for ::, get(), assign() in filters
# 6. "All-equal weights": Verify weights were actually applied to data
# 7. "Unexpected data type": V9.9.5 now supports integer64 and labelled
#
# CONFIGURATION OPTIONS (V9.9.5):
# - weight_na_threshold: Threshold for NA weight warning (default: 10%)
# - weight_zero_threshold: Threshold for zero weight warning (default: 5%)
# - weight_deff_warning: Design effect warning threshold (default: 3)
# - output_format: "excel", "xlsx", or "csv" (normalized to "xlsx"/"csv")
# - alpha: Significance level, 0.05 for 95% CI (replaces significance_level)
# - significance_min_base: Minimum base for sig tests (default: 30)
# - decimal_places_*: 0-5 (toolkit standard)
#
# ==============================================================================
# END OF VALIDATION.R V10.1 - PRODUCTION RELEASE
# ==============================================================================
