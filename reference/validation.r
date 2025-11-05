# ==============================================================================
# VALIDATION V9.9.5 - PRODUCTION RELEASE
# ==============================================================================
# Input validation and data quality checks
# Part of R Survey Analytics Toolkit
#
# VERSION HISTORY:
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

SCRIPT_VERSION <- "9.9.5"

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
# SURVEY STRUCTURE VALIDATION (V9.9.2)
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
  
  # V9.9.2: Trim whitespace on codes before duplicate checks
  questions_df$QuestionCode <- trimws(questions_df$QuestionCode)
  if (nrow(options_df) > 0) {
    options_df$QuestionCode <- trimws(options_df$QuestionCode)
  }
  
  # Check for duplicate question codes
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
  
# Check for questions without options (excluding Open_End and Numeric)
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
  
# Check for options without matching questions
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
  # Validate Variable_Type values
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
  
  # Validate Ranking questions have Ranking_Format
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
  
  # Validate Multi_Mention questions have Columns specified
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
  
  if (verbose) cat("✓ Survey structure validation complete\n")
  
  return(error_log)
}

# ==============================================================================
# DATA VALIDATION (V9.9.5)
# ==============================================================================

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
    stop("survey_data must be a data frame", call. = FALSE)
  }
  
  if (nrow(survey_data) == 0) {
    stop("survey_data is empty (0 rows)", call. = FALSE)
  }
  
  if (!is.list(survey_structure) || !"questions" %in% names(survey_structure)) {
    stop("survey_structure must contain $questions", call. = FALSE)
  }
  
  if (!is.data.frame(error_log)) {
    stop("error_log must be a data frame", call. = FALSE)
  }
  
  if (verbose) cat("Validating data structure...\n")
  
  questions_df <- survey_structure$questions
  
  if (!is.data.frame(questions_df) || nrow(questions_df) == 0) {
    stop("survey_structure$questions must be a non-empty data frame", call. = FALSE)
  }
  
  # V9.9.5: Extended numeric types to include integer64
  numeric_types <- c("numeric", "integer", "double", "integer64")
  
  # Check for missing question columns and validate types
  for (i in seq_len(nrow(questions_df))) {
    question <- questions_df[i, ]
    question_code <- trimws(question$QuestionCode)
    var_type <- question$Variable_Type
    
    # Skip Open_End (optional in data)
    if (var_type == "Open_End") {
      next
    }
    
    if (var_type == "Multi_Mention") {
      # Check multi-mention columns
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
        next
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
          # V9.9.2: Type-safe check if all columns are completely empty
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
          
          # V9.9.5: Updated Multi_Mention type validation with integer64
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

} else {
      # Check single column
      # Skip Ranking questions - they use multiple columns (Q76_Rank1, Q76_Rank2, etc.)
      if (var_type == "Ranking") {
        next
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
      } else {
                              
        col_values <- survey_data[[question_code]]
        col_type <- class(col_values)[1]
        
        # V9.9.2: Type-safe check if column is completely empty
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
        
        # V9.9.5: Updated type validation with integer64 and labelled support
        expected_types <- list(
          Rating = c(numeric_types, "character", "factor", "labelled"),  # V9.9.4: added character/factor
          Likert = c(numeric_types, "character", "factor", "labelled"),  # V9.9.4: added character/factor
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
      }
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
# WEIGHTING VALIDATION (V9.9.5: FULLY CONFIGURABLE THRESHOLDS)
# ==============================================================================

#' Validate weighting configuration and weight column
#'
#' CHECKS PERFORMED:
#' - Weighting config consistency
#' - Weight variable is specified when weighting enabled
#' - Weight column exists in data
#' - Weight values are valid (not all NA, not negative, not infinite)
#' - Weight distribution is reasonable (CV, design effect)
#' - Weights are not all equal (V9.9.2)
#'
#' V9.9.5 ENHANCEMENTS:
#' - All thresholds now configurable:
#'   * weight_na_threshold (default: 10)
#'   * weight_zero_threshold (default: 5)
#'   * weight_deff_warning (default: 3)
#'
#' V9.9.2 ENHANCEMENTS:
#' - Reports Kish design effect (deff ≈ 1 + CV²)
#' - Checks for all-equal weights (SD ≈ 0)
#'
#' V9.9.3 ENHANCEMENTS:
#' - Configurable NA threshold (weight_na_threshold, default: 10)
#'
#' @param survey_structure Survey structure list
#' @param survey_data Survey data frame
#' @param config Configuration list
#' @param error_log Error log data frame
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Updated error log data frame
#' @export
validate_weighting_config <- function(survey_structure, survey_data, config, error_log, verbose = TRUE) {
  # Input validation
  if (!is.list(survey_structure) || !"project" %in% names(survey_structure)) {
    stop("survey_structure must contain $project", call. = FALSE)
  }
  
  if (!is.data.frame(survey_data)) {
    stop("survey_data must be a data frame", call. = FALSE)
  }
  
  if (!is.list(config)) {
    stop("config must be a list", call. = FALSE)
  }
  
  if (!is.data.frame(error_log)) {
    stop("error_log must be a data frame", call. = FALSE)
  }
  
  # Check if weighting is enabled
  apply_weighting <- safe_logical(get_config_value(config, "apply_weighting", FALSE))
  
  if (!apply_weighting) {
    return(error_log)  # No weighting, nothing to validate
  }
  
  if (verbose) cat("Validating weighting configuration...\n")
  
  # Check if weight column exists flag is set in Survey_Structure
  weight_exists <- safe_logical(
    get_config_value(survey_structure$project, "weight_column_exists", "N")
  )
  
  if (!weight_exists) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Weighting Configuration Mismatch",
      "apply_weighting=TRUE but weight_column_exists=N in Survey_Structure. Update Survey_Structure or disable weighting.",
      "", 
      "Error"
    )
    return(error_log)
  }
  
  # Get weight column name
  weight_variable <- get_config_value(config, "weight_variable", NULL)
  
  if (is.null(weight_variable) || is.na(weight_variable) || weight_variable == "") {
    # Try to get default weight from Survey_Structure
    weight_variable <- get_config_value(survey_structure$project, "default_weight", NULL)
    
    if (is.null(weight_variable) || is.na(weight_variable) || weight_variable == "") {
      error_log <- log_issue(
        error_log, 
        "Validation", 
        "Missing Weight Variable",
        "Weighting enabled but no weight_variable specified in config. Set weight_variable or disable weighting.",
        "", 
        "Error"
      )
      return(error_log)
    }
  }
  
  # Check if weight column exists in data
  if (!weight_variable %in% names(survey_data)) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Missing Weight Column",
      sprintf(
        "Weight column '%s' not found in data. Add column or update weight_variable.",
        weight_variable
      ),
      "", 
      "Error"
    )
    return(error_log)
  }
  
  # Check weight column values
  weight_values <- survey_data[[weight_variable]]
  
  # Check for non-numeric weights
  if (!is.numeric(weight_values)) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Non-Numeric Weights",
      sprintf("Weight column '%s' is not numeric (type: %s)", weight_variable, class(weight_values)[1]),
      "", 
      "Error"
    )
    return(error_log)
  }
  
  # Check for all NA
  valid_weights <- weight_values[!is.na(weight_values) & is.finite(weight_values)]
  
  if (length(valid_weights) == 0) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Empty Weight Column",
      sprintf("Weight column '%s' has no valid (non-NA, finite) values", weight_variable),
      "", 
      "Error"
    )
    return(error_log)
  }
  
  # V9.9.5: Fully configurable thresholds
  na_threshold <- safe_numeric(get_config_value(config, "weight_na_threshold", 10))
  zero_threshold <- safe_numeric(get_config_value(config, "weight_zero_threshold", 5))
  deff_threshold <- safe_numeric(get_config_value(config, "weight_deff_warning", 3))
  
  pct_na <- 100 * sum(is.na(weight_values)) / length(weight_values)
  
  if (pct_na > na_threshold) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "High NA Rate in Weights",
      sprintf(
        "Weight column '%s' has %.1f%% NA values (threshold: %.0f%%). Review data quality.",
        weight_variable, pct_na, na_threshold
      ),
      "", 
      "Warning"
    )
  }
  
  # Check for negative weights
  if (any(valid_weights < 0)) {
    n_negative <- sum(valid_weights < 0)
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Negative Weights",
      sprintf(
        "Weight column '%s' contains %d negative values (%.1f%%). Weights must be non-negative.",
        weight_variable, n_negative, 100 * n_negative / length(valid_weights)
      ),
      "", 
      "Error"
    )
  }
  
  # V9.9.5: Configurable zero threshold
  n_zero <- sum(valid_weights == 0)
  if (n_zero > 0) {
    pct_zero <- 100 * n_zero / length(valid_weights)
    if (pct_zero > zero_threshold) {
      error_log <- log_issue(
        error_log, 
        "Validation", 
        "Many Zero Weights",
        sprintf(
          "Weight column '%s' has %d zero values (%.1f%%, threshold: %.0f%%). High proportion may indicate data issues.",
          weight_variable, n_zero, pct_zero, zero_threshold
        ),
        "", 
        "Warning"
      )
    }
  }
  
  # Check for infinite weights
  if (any(is.infinite(weight_values))) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Infinite Weights",
      sprintf("Weight column '%s' contains infinite values. Fix data before analysis.", weight_variable),
      "", 
      "Error"
    )
  }
  
  # V9.9.2: Check for all-equal weights (SD ≈ 0)
  nonzero_weights <- valid_weights[valid_weights > 0]
  
  if (length(nonzero_weights) > 0) {
    weight_sd <- sd(nonzero_weights)
    weight_mean <- mean(nonzero_weights)
    
    if (weight_sd < 1e-10 || (weight_mean > 0 && weight_sd / weight_mean < 1e-6)) {
      error_log <- log_issue(
        error_log, 
        "Validation", 
        "All-Equal Weights",
        sprintf(
          "Weight column '%s' has near-zero variance (SD = %.10f). All weights appear equal - weighting may not be applied.",
          weight_variable, weight_sd
        ),
        "", 
        "Warning"
      )
    }
    
    # V9.9.5: Configurable design effect threshold
    weight_cv <- weight_sd / weight_mean
    
    if (weight_cv > 1.5) {
      # V9.9.2: Calculate and report Kish design effect (deff ≈ 1 + CV²)
      design_effect <- 1 + weight_cv^2
      
      severity <- if (design_effect > deff_threshold) "Warning" else "Info"
      
      error_log <- log_issue(
        error_log, 
        "Validation", 
        "High Weight Variability",
        sprintf(
          "Weight column '%s' has high variability (CV = %.2f, Design Effect ≈ %.2f, threshold: %.1f). %s",
          weight_variable, 
          weight_cv,
          design_effect,
          deff_threshold,
          if (design_effect > deff_threshold) "This substantially reduces effective sample size. Verify weights are correct." else "Verify weights are correct."
        ),
        "", 
        severity
      )
    }
  }
  
  if (verbose) cat("✓ Weighting validation complete\n")
  
  return(error_log)
}

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
# CONFIG VALIDATION (V9.9.3: OUTPUT FORMAT NORMALIZATION)
# ==============================================================================

#' Validate crosstab configuration parameters
#'
#' CHECKS PERFORMED:
#' - alpha (significance level) is in (0, 1)
#' - significance_min_base is positive
#' - decimal_places are reasonable (0-5, documented standard)
#' - All required config values are present
#' - Output format is valid (normalizes excel → xlsx)
#'
#' V9.9.2 ENHANCEMENTS:
#' - Documents decimal precision policy (0-5 is standard)
#'
#' V9.9.3 ENHANCEMENTS:
#' - Normalizes output_format in config object: "excel" → "xlsx"
#'
#' @param config Configuration list
#' @param survey_structure Survey structure list
#' @param survey_data Survey data frame
#' @param error_log Error log data frame
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Updated error log data frame
#' @export
validate_crosstab_config <- function(config, survey_structure, survey_data, error_log, verbose = TRUE) {
  # Input validation
  if (!is.list(config)) {
    stop("config must be a list", call. = FALSE)
  }
  
  if (!is.data.frame(error_log)) {
    stop("error_log must be a data frame", call. = FALSE)
  }
  
  if (verbose) cat("Validating crosstab configuration...\n")
  
  # Validate alpha (not significance_level)
  alpha <- get_config_value(config, "alpha", NULL)
  sig_level <- get_config_value(config, "significance_level", NULL)
  
  if (!is.null(sig_level) && is.null(alpha)) {
    # Old config using significance_level (0.95) - warn about deprecation
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Deprecated Config Parameter",
      "Using 'significance_level' is deprecated. Use 'alpha' instead (e.g., alpha = 0.05 for 95% CI).",
      "", 
      "Warning"
    )
    
    # Convert significance_level to alpha
    sig_level <- safe_numeric(sig_level)
    if (sig_level > 0.5) {
      # Looks like confidence level (0.95), convert to alpha
      alpha <- 1 - sig_level
    } else {
      # Already looks like alpha
      alpha <- sig_level
    }
  } else if (!is.null(alpha)) {
    alpha <- safe_numeric(alpha)
  } else {
    # Default
    alpha <- 0.05
  }
  
  # Validate alpha range
  if (alpha <= 0 || alpha >= 1) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Invalid Alpha",
      sprintf(
        "alpha must be between 0 and 1 (typical: 0.05 for 95%% CI, 0.01 for 99%% CI), got: %.4f",
        alpha
      ),
      "", 
      "Error"
    )
  }
  
  # Warn if alpha is unusual
  if (alpha > 0.2) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Unusual Alpha Value",
      sprintf(
        "alpha = %.4f is unusually high (>80%% CI). Typical values: 0.05 (95%% CI) or 0.01 (99%% CI).",
        alpha
      ),
      "", 
      "Warning"
    )
  }
  
  # Validate minimum base
  min_base <- safe_numeric(get_config_value(config, "significance_min_base", 30))
  
  if (min_base < 1) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Invalid Minimum Base",
      sprintf("significance_min_base must be positive, got: %d", min_base),
      "", 
      "Error"
    )
  }
  
  if (min_base < 10) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Low Minimum Base",
      sprintf(
        "significance_min_base = %d is very low. Values < 30 may give unreliable significance tests.",
        min_base
      ),
      "", 
      "Warning"
    )
  }
  
# Validate decimal places (0-5 recommended, 6 allowed for edge cases)
  decimal_settings <- c(
    "decimal_places_percent",
    "decimal_places_ratings",
    "decimal_places_index",
    "decimal_places_mean",
    "decimal_places_numeric"  # V10.0.0: Added for Numeric questions
  )
  
  for (setting in decimal_settings) {
    value <- safe_numeric(get_config_value(config, setting, 0))
    
    if (value < 0 || value > MAX_DECIMAL_PLACES) {
      error_log <- log_issue(
        error_log, 
        "Validation", 
        "Invalid Decimal Places",
        sprintf(
          "%s out of range: %d (must be 0-%d).",
          setting, value, MAX_DECIMAL_PLACES
        ),
        "", 
        "Error"
      )
    } else if (value > 5) {
      error_log <- log_issue(
        error_log, 
        "Validation", 
        "High Decimal Places",
        sprintf(
          "%s = %d exceeds recommended range (0-5 is standard). Values 0-2 are typical for survey reporting.",
          setting, value
        ),
        "", 
        "Warning"
      )
    }
  }

# ===========================================================================
  # V10.0.0: NUMERIC QUESTION SETTINGS VALIDATION (NEW)
  # ===========================================================================
  
  # Validate median/mode with weighting
  show_median <- safe_logical(get_config_value(config, "show_numeric_median", FALSE))
  show_mode <- safe_logical(get_config_value(config, "show_numeric_mode", FALSE))
  apply_weighting <- safe_logical(get_config_value(config, "apply_weighting", FALSE))
  
  if (show_median && apply_weighting) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Unsupported Configuration",
      "show_numeric_median=TRUE with apply_weighting=TRUE: Median is only available for unweighted data. Median will display as 'N/A (weighted)'.",
      "",
      "Warning"
    )
  }
  
  if (show_mode && apply_weighting) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Unsupported Configuration",
      "show_numeric_mode=TRUE with apply_weighting=TRUE: Mode is only available for unweighted data. Mode will display as 'N/A (weighted)'.",
      "",
      "Warning"
    )
  }
  
  # Validate outlier method
  outlier_method <- get_config_value(config, "outlier_method", "IQR")
  valid_outlier_methods <- c("IQR")
  
  if (!outlier_method %in% valid_outlier_methods) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Invalid Outlier Method",
      sprintf(
        "outlier_method '%s' not supported. Valid methods: %s. Using 'IQR' as default.",
        outlier_method,
        paste(valid_outlier_methods, collapse = ", ")
      ),
      "",
      "Warning"
    )
    config$outlier_method <- "IQR"  # Normalize to default
  }
  
  # ===========================================================================
  # END OF V10.0.0 ADDITION
  # ===========================================================================
    
    
  # V9.9.3: Validate and NORMALIZE output format
  output_format <- get_config_value(config, "output_format", "excel")
  valid_formats <- c("excel", "xlsx", "csv")
  
  if (!output_format %in% valid_formats) {
    error_log <- log_issue(
      error_log, 
      "Validation", 
      "Invalid Output Format",
      sprintf(
        "output_format '%s' not recognized. Valid formats: %s. Using 'xlsx' as default.",
        output_format,
        paste(valid_formats, collapse = ", ")
      ),
      "", 
      "Warning"
    )
    config$output_format <- "xlsx"  # V9.9.3: Normalize
  } else if (output_format == "excel") {
    # V9.9.3: Normalize "excel" to "xlsx" IN the config object
    config$output_format <- "xlsx"
    if (verbose) {
      cat("  Note: output_format 'excel' normalized to 'xlsx'\n")
    }
  }
  
  if (verbose) cat("✓ Configuration validation complete\n")
  
  return(error_log)
}
# ==============================================================================
# NUMERIC QUESTION VALIDATION (V10.0.0 - NEW)
# ==============================================================================

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
    # This is handled in main validation, skip here
    return(error_log)
  }
  
  # Validate Min_Value and Max_Value if specified
  if ("Min_Value" %in% names(question_info)) {
    min_val <- suppressWarnings(as.numeric(question_info$Min_Value))
    if (!is.na(min_val)) {
      # Check data against min
      col_data <- survey_data[[question_code]]
      numeric_data <- suppressWarnings(as.numeric(col_data))
      valid_numeric <- numeric_data[!is.na(numeric_data)]
      
      if (length(valid_numeric) > 0) {
        below_min <- sum(valid_numeric < min_val)
        if (below_min > 0) {
          error_log <- log_issue(
            error_log,
            "Validation",
            "Values Below Minimum",
            sprintf(
              "Question %s: %d values below Min_Value (%.2f). These will be excluded from analysis.",
              question_code, below_min, min_val
            ),
            question_code,
            "Warning"
          )
        }
      }
    }
  }
  
  if ("Max_Value" %in% names(question_info)) {
    max_val <- suppressWarnings(as.numeric(question_info$Max_Value))
    if (!is.na(max_val)) {
      # Check data against max
      col_data <- survey_data[[question_code]]
      numeric_data <- suppressWarnings(as.numeric(col_data))
      valid_numeric <- numeric_data[!is.na(numeric_data)]
      
      if (length(valid_numeric) > 0) {
        above_max <- sum(valid_numeric > max_val)
        if (above_max > 0) {
          error_log <- log_issue(
            error_log,
            "Validation",
            "Values Above Maximum",
            sprintf(
              "Question %s: %d values above Max_Value (%.2f). These will be excluded from analysis.",
              question_code, above_max, max_val
            ),
            question_code,
            "Warning"
          )
        }
      }
    }
  }
  
  # Check for non-numeric values that will be converted to NA
  col_data <- survey_data[[question_code]]
  numeric_data <- suppressWarnings(as.numeric(col_data))
  non_numeric_count <- sum(is.na(numeric_data) & !is.na(col_data))
  
  if (non_numeric_count > 0) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Non-Numeric Values",
      sprintf(
        "Question %s: %d non-numeric values found. These will be treated as missing data.",
        question_code, non_numeric_count
      ),
      question_code,
      "Warning"
    )
  }
  
  # Validate bins if defined in options
  if (nrow(option_info) > 0) {
    # Check for required bin columns
    if (!all(c("Min", "Max") %in% names(option_info))) {
      error_log <- log_issue(
        error_log,
        "Validation",
        "Missing Bin Columns",
        sprintf(
          "Question %s: Numeric bins require 'Min' and 'Max' columns in Options sheet.",
          question_code
        ),
        question_code,
        "Error"
      )
      return(error_log)
    }
    
    # Validate bin numeric values
    bin_mins <- suppressWarnings(as.numeric(option_info$Min))
    bin_maxs <- suppressWarnings(as.numeric(option_info$Max))
    
    invalid_bins <- is.na(bin_mins) | is.na(bin_maxs)
    if (any(invalid_bins)) {
      error_log <- log_issue(
        error_log,
        "Validation",
        "Invalid Bin Values",
        sprintf(
          "Question %s: Bins have non-numeric Min or Max values (rows: %s).",
          question_code,
          paste(which(invalid_bins), collapse = ", ")
        ),
        question_code,
        "Error"
      )
      return(error_log)
    }
    
    # Check bin logic: Min <= Max
    invalid_range <- bin_mins > bin_maxs
    if (any(invalid_range)) {
      error_log <- log_issue(
        error_log,
        "Validation",
        "Invalid Bin Range",
        sprintf(
          "Question %s: Bins have Min > Max (rows: %s).",
          question_code,
          paste(which(invalid_range), collapse = ", ")
        ),
        question_code,
        "Error"
      )
    }
    
    # Check for overlapping bins (sorted by Min)
    if (nrow(option_info) > 1) {
      sorted_idx <- order(bin_mins)
      for (i in 1:(length(sorted_idx) - 1)) {
        curr_idx <- sorted_idx[i]
        next_idx <- sorted_idx[i + 1]
        
        # Bins overlap if current Max >= next Min
        if (bin_maxs[curr_idx] >= bin_mins[next_idx]) {
          error_log <- log_issue(
            error_log,
            "Validation",
            "Overlapping Bins",
            sprintf(
              "Question %s: Bins overlap between rows %d and %d. Bin[%d] Max (%.2f) >= Bin[%d] Min (%.2f).",
              question_code,
              curr_idx, next_idx,
              curr_idx, bin_maxs[curr_idx],
              next_idx, bin_mins[next_idx]
            ),
            question_code,
            "Warning"
          )
        }
      }
    }
    
    # Check if bins cover the data range
    numeric_data <- suppressWarnings(as.numeric(col_data))
    valid_numeric <- numeric_data[!is.na(numeric_data)]
    
    if (length(valid_numeric) > 0) {
      data_min <- min(valid_numeric)
      data_max <- max(valid_numeric)
      
      bin_coverage_min <- min(bin_mins)
      bin_coverage_max <- max(bin_maxs)
      
      if (data_min < bin_coverage_min) {
        uncovered_count <- sum(valid_numeric < bin_coverage_min)
        error_log <- log_issue(
          error_log,
          "Validation",
          "Incomplete Bin Coverage",
          sprintf(
            "Question %s: %d values below lowest bin Min (%.2f < %.2f). These values will not be categorized.",
            question_code, uncovered_count, data_min, bin_coverage_min
          ),
          question_code,
          "Warning"
        )
      }
      
      if (data_max > bin_coverage_max) {
        uncovered_count <- sum(valid_numeric > bin_coverage_max)
        error_log <- log_issue(
          error_log,
          "Validation",
          "Incomplete Bin Coverage",
          sprintf(
            "Question %s: %d values above highest bin Max (%.2f > %.2f). These values will not be categorized.",
            question_code, uncovered_count, data_max, bin_coverage_max
          ),
          question_code,
          "Warning"
        )
      }
    }
  }
  
  return(error_log)
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
    stop("survey_structure must be a list", call. = FALSE)
  }
  
  if (!is.data.frame(survey_data)) {
    stop("survey_data must be a data frame", call. = FALSE)
  }
  
  if (!is.list(config)) {
    stop("config must be a list", call. = FALSE)
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
    stop("Validation could not complete. Fix critical errors before proceeding.", call. = FALSE)
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
      stop(sprintf(
        "\nValidation failed with %d error(s). Fix errors before proceeding.%s",
        n_errors,
        if (verbose) "\nSee error details above." else ""
      ), call. = FALSE)
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
# END OF VALIDATION.R V9.9.5 - PRODUCTION RELEASE
# ==============================================================================
