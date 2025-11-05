# ==============================================================================
# TURAS VALIDATION: DATA STRUCTURE MODULE
# ==============================================================================
# Data structure and quality validation functions
# Part of Turas Analytics Toolkit - Phase 4 Migration
#
# MIGRATED FROM: validation.r (lines 351-618, 1325-1535)
# DATE: October 24, 2025
# STATUS: Phase 4 - Module 2
#
# DESCRIPTION:
#   Validates survey data matches structure expectations including:
#   - Required columns exist in data
#   - Multi_Mention column codes exist
#   - Data types match Variable_Type expectations
#   - No completely empty questions (type-safe)
#   - Numeric question validation (Min/Max, bins)
#
# DEPENDENCIES:
#   - core/validation.R (validate_data_frame, validate_column_exists)
#   - core/logging.R (log_issue)
#   - core/utilities.R (has_data)
#   - shared/validation/survey.R (is_blank helper)
#
# EXPORTED FUNCTIONS:
#   - validate_data_structure() - Main data validator
#   - validate_numeric_question() - Numeric question validator
# ==============================================================================

# ==============================================================================
# MAIN DATA VALIDATION FUNCTION
# ==============================================================================

#' Validate survey data matches structure expectations
#'
#' Comprehensive validation of survey data including:
#' - Required question columns exist in data
#' - Multi_Mention columns exist (Q_1, Q_2, etc.)
#' - Column data types match Variable_Type expectations
#' - No completely empty questions (type-safe check)
#' - Numeric questions validated for Min/Max and bins
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
#' @param survey_structure Survey structure list containing $questions and $options
#' @param error_log Error log data frame (from create_error_log())
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Updated error log data frame with any validation issues
#' @export
#' @examples
#' error_log <- create_error_log()
#' error_log <- validate_data_structure(survey_data, survey_structure, error_log)
validate_data_structure <- function(survey_data, survey_structure, error_log, verbose = TRUE) {
  
  # ============================================================================
  # INPUT VALIDATION
  # ============================================================================
  
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
  
  # ============================================================================
  # TYPE DEFINITIONS
  # ============================================================================
  
  # V9.9.5: Extended numeric types to include integer64
  numeric_types <- c("numeric", "integer", "double", "integer64")
  
  # ============================================================================
  # CHECK EACH QUESTION
  # ============================================================================
  
  for (i in seq_len(nrow(questions_df))) {
    question <- questions_df[i, ]
    question_code <- trimws(question$QuestionCode)
    var_type <- question$Variable_Type
    
    # Skip Open_End (optional in data)
    if (var_type == "Open_End") {
      next
    }
    
    # ------------------------------------------------------------------------
    # MULTI_MENTION QUESTIONS
    # ------------------------------------------------------------------------
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
      
    # ------------------------------------------------------------------------
    # SINGLE COLUMN QUESTIONS
    # ------------------------------------------------------------------------
    } else {
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
  
  # ============================================================================
  # NUMERIC QUESTION VALIDATION (V10.0.0)
  # ============================================================================
  
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
  
  # ============================================================================
  # COMPLETE
  # ============================================================================
  
  if (verbose) cat("✓ Data structure validation complete\n")
  
  return(error_log)
}

# ==============================================================================
# NUMERIC QUESTION VALIDATION
# ==============================================================================

#' Validate numeric question data quality and bin definitions
#'
#' Validates numeric questions for:
#' - Min_Value and Max_Value constraints
#' - Non-numeric values that will become NA
#' - Bin definitions (if provided in options)
#' - Bin coverage of data range
#' - Overlapping bins
#'
#' @param question_info Single row from questions data frame
#' @param option_info Rows from options data frame for this question
#' @param survey_data Survey data frame
#' @param error_log Error log data frame
#' @return Updated error log data frame
#' @keywords internal
validate_numeric_question <- function(question_info, option_info, survey_data, error_log) {
  question_code <- trimws(question_info$QuestionCode)
  
  # Check if column exists in data
  if (!question_code %in% names(survey_data)) {
    # This is handled in main validation, skip here
    return(error_log)
  }
  
  col_data <- survey_data[[question_code]]
  
  # ============================================================================
  # CHECK 1: MIN_VALUE CONSTRAINT
  # ============================================================================
  
  if ("Min_Value" %in% names(question_info)) {
    min_val <- suppressWarnings(as.numeric(question_info$Min_Value))
    if (!is.na(min_val)) {
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
  
  # ============================================================================
  # CHECK 2: MAX_VALUE CONSTRAINT
  # ============================================================================
  
  if ("Max_Value" %in% names(question_info)) {
    max_val <- suppressWarnings(as.numeric(question_info$Max_Value))
    if (!is.na(max_val)) {
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
  
  # ============================================================================
  # CHECK 3: NON-NUMERIC VALUES
  # ============================================================================
  
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
  
  # ============================================================================
  # CHECK 4: BIN DEFINITIONS (if provided)
  # ============================================================================
  
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
