# ==============================================================================
# TURAS RANKING MODULE 2: DATA QUALITY VALIDATION
# ==============================================================================
# Comprehensive validation for ranking question data quality
#
# Part of Phase 6: Ranking Migration
# Source: ranking.r (V9.9.3) lines 122-341, 1237-1354
#
# KEY FEATURES:
# - V9.9.3 fail-fast numeric guard (prevents silent character conversion)
# - Vectorized tie/gap detection (V9.9.2 performance improvement)
# - Configurable validation thresholds
# - Comprehensive data quality diagnostics
# ==============================================================================

#' Validate ranking matrix for data quality
#'
#' @description
#' Performs comprehensive validation of ranking data matrix, checking for:
#' - Numeric type validity
#' - Value range compliance (1 to num_positions)
#' - Tied ranks (same rank assigned to multiple items)
#' - Gaps in rankings (skipped positions)
#' - Data completeness (missing values)
#' 
#' Returns detailed diagnostics for quality assessment and troubleshooting.
#'
#' @details
#' **V9.9.3 CRITICAL FIX:**
#' Implements fail-fast numeric validation BEFORE matrix conversion.
#' When converting a data.frame to matrix with `as.matrix()`, if ANY column
#' is character, R silently converts the ENTIRE matrix to character mode.
#' This breaks all numeric calculations downstream.
#' 
#' Solution: Check all columns are numeric/integer64 before conversion,
#' then explicitly enforce storage.mode = "double".
#' 
#' **V9.9.2 PERFORMANCE:**
#' Uses vectorized apply-based detection for ties and gaps (3-5x faster
#' than nested loops on large datasets).
#' 
#' **VALIDATION CHECKS:**
#' 
#' 1. **Type Check:** Ensures matrix is numeric after conversion
#' 2. **Range Check:** All values between 1 and num_positions
#' 3. **Integer Check:** Ranks should be whole numbers
#' 4. **Tie Detection:** Same rank for multiple items (per respondent)
#' 5. **Gap Detection:** Missing rank positions (e.g., 1, 3, 5 missing 2, 4)
#' 6. **Completeness:** Percentage of non-NA values
#' 
#' **CONFIGURABLE THRESHOLDS:**
#' Each check has a configurable threshold for warnings:
#' - Ties: Default 5% (warn if >5% of respondents have ties)
#' - Gaps: Default 5% (warn if >5% of respondents have gaps)
#' - Completeness: Default 80% (warn if <80% complete)
#'
#' @param ranking_matrix Numeric matrix or data.frame with ranking data
#'   - Rows = respondents
#'   - Columns = items being ranked
#'   - Values = rank positions (1 to num_positions)
#'   - NA = not ranked
#' @param num_positions Integer, maximum number of rank positions
#'   E.g., if ranking top 5 items, num_positions = 5
#' @param item_names Character vector, item names for reporting
#'   If NULL, uses column names or generates Item_1, Item_2, etc.
#' @param tie_threshold_pct Numeric (0-100), threshold for tie warning
#'   Default: 5%. Warn if >5% of respondents have tied ranks
#' @param gap_threshold_pct Numeric (0-100), threshold for gap warning
#'   Default: 5%. Warn if >5% of respondents have gaps
#' @param completeness_threshold_pct Numeric (0-100), completeness threshold
#'   Default: 80%. Warn if <80% of matrix is non-NA
#'
#' @return List with validation results:
#' \describe{
#'   \item{valid}{Logical, TRUE if no issues detected}
#'   \item{has_issues}{Logical, TRUE if any issues found}
#'   \item{summary}{Character, human-readable summary}
#'   \item{n_respondents}{Integer, number of respondents}
#'   \item{n_items}{Integer, number of items}
#'   \item{pct_complete}{Numeric, percentage complete}
#'   \item{n_ties}{Integer, number of respondents with ties}
#'   \item{pct_ties}{Numeric, percentage with ties}
#'   \item{respondents_with_ties}{Integer vector, indices (max 10) or NULL}
#'   \item{n_gaps}{Integer, number of respondents with gaps}
#'   \item{pct_gaps}{Numeric, percentage with gaps}
#'   \item{out_of_range}{Integer, count of out-of-range values}
#'   \item{non_integer}{Integer, count of non-integer ranks}
#' }
#'
#' @section Examples of Data Quality Issues:
#' 
#' **Tied Ranks (Same rank for multiple items):**
#' ```
#' Respondent ranks 3 brands:
#'   Brand A: Rank 1
#'   Brand B: Rank 1  <- TIE (both ranked 1st)
#'   Brand C: Rank 2
#' ```
#' 
#' **Gaps (Missing rank positions):**
#' ```
#' Respondent ranks 5 items but skips positions:
#'   Item A: Rank 1
#'   Item B: Rank 3  <- GAP (missing rank 2)
#'   Item C: Rank 5  <- GAP (missing rank 4)
#' ```
#' 
#' **Out of Range:**
#' ```
#' If num_positions = 5:
#'   Item A: Rank 6  <- INVALID (too high)
#'   Item B: Rank 0  <- INVALID (too low)
#' ```
#'
#' @examples
#' # Example 1: Valid ranking data
#' valid_matrix <- matrix(c(1, 2, 3, 4, 5,
#'                          2, 1, 3, 5, 4),
#'                        nrow = 2, byrow = TRUE)
#' result <- validate_ranking_matrix(valid_matrix, 5)
#' # result$valid = TRUE, result$has_issues = FALSE
#'
#' # Example 2: Data with ties
#' tied_matrix <- matrix(c(1, 1, 3, 4, 5,  # Both Item1 and Item2 ranked 1
#'                         2, 1, 3, 5, 4),
#'                       nrow = 2, byrow = TRUE)
#' result <- validate_ranking_matrix(tied_matrix, 5)
#' # result$n_ties = 1, result$pct_ties = 50%
#'
#' # Example 3: Data with gaps
#' gap_matrix <- matrix(c(1, 3, 5, NA, NA,  # Skipped ranks 2 and 4
#'                        2, 1, 3, 5, 4),
#'                      nrow = 2, byrow = TRUE)
#' result <- validate_ranking_matrix(gap_matrix, 5)
#' # result$n_gaps = 1
#'
#' # Example 4: Custom thresholds
#' result <- validate_ranking_matrix(tied_matrix, 5,
#'                                  tie_threshold_pct = 10)  # More lenient
#' # Won't warn about ties unless >10% have them
#'
#' @export
#' @family ranking
#' @seealso \code{\link{normalize_rank_direction}} for direction normalization
validate_ranking_matrix <- function(ranking_matrix, 
                                   num_positions, 
                                   item_names = NULL,
                                   tie_threshold_pct = 5,
                                   gap_threshold_pct = 5,
                                   completeness_threshold_pct = 80) {
  
  # ==============================================================================
  # INPUT VALIDATION
  # ==============================================================================
  
  # Check ranking_matrix type
  if (!is.matrix(ranking_matrix) && !is.data.frame(ranking_matrix)) {
    stop(
      "ranking_matrix must be a matrix or data.frame\n",
      "  Received: ", class(ranking_matrix)[1],
      call. = FALSE
    )
  }
  
  # Check num_positions
  if (!is.numeric(num_positions) || length(num_positions) != 1 || num_positions < 1) {
    stop(
      "num_positions must be a single positive integer\n",
      "  Received: ", 
      if (length(num_positions) == 1) num_positions else paste(num_positions, collapse = ", "),
      call. = FALSE
    )
  }
  
  # Validate threshold parameters
  if (!is.numeric(tie_threshold_pct) || tie_threshold_pct < 0 || tie_threshold_pct > 100) {
    stop(
      "tie_threshold_pct must be between 0 and 100\n",
      "  Received: ", tie_threshold_pct,
      call. = FALSE
    )
  }
  
  if (!is.numeric(gap_threshold_pct) || gap_threshold_pct < 0 || gap_threshold_pct > 100) {
    stop(
      "gap_threshold_pct must be between 0 and 100\n",
      "  Received: ", gap_threshold_pct,
      call. = FALSE
    )
  }
  
  if (!is.numeric(completeness_threshold_pct) || 
      completeness_threshold_pct < 0 || 
      completeness_threshold_pct > 100) {
    stop(
      "completeness_threshold_pct must be between 0 and 100\n",
      "  Received: ", completeness_threshold_pct,
      call. = FALSE
    )
  }
  
  # ==============================================================================
  # V9.9.3: FAIL-FAST NUMERIC GUARD
  # ==============================================================================
  # CRITICAL: Check all columns are numeric BEFORE as.matrix() conversion
  # If ANY column is character, as.matrix() silently converts ENTIRE matrix to character!
  
  if (is.data.frame(ranking_matrix)) {
    # Check each column is numeric or integer64
    bad_cols <- names(ranking_matrix)[!sapply(ranking_matrix, function(x) {
      is.numeric(x) || inherits(x, "integer64")
    })]
    
    if (length(bad_cols) > 0) {
      stop(
        "Ranking columns must be numeric, found character/other types:\n",
        "  Columns: ", paste(bad_cols, collapse = ", "), "\n",
        "  Check data types in source data",
        call. = FALSE
      )
    }
    
    # Safe to convert now
    ranking_matrix <- as.matrix(ranking_matrix)
  }
  
  # V9.9.3: Explicitly enforce numeric storage
  storage.mode(ranking_matrix) <- "double"
  
  # ==============================================================================
  # DIMENSION CHECKS
  # ==============================================================================
  
  n_respondents <- nrow(ranking_matrix)
  n_items <- ncol(ranking_matrix)
  
  # Empty matrix check
  if (n_respondents == 0 || n_items == 0) {
    return(list(
      valid = FALSE,
      has_issues = TRUE,
      summary = "Ranking matrix is empty (0 rows or 0 columns)",
      n_respondents = n_respondents,
      n_items = n_items,
      pct_complete = 0,
      n_ties = 0,
      pct_ties = 0,
      respondents_with_ties = NULL,
      n_gaps = 0,
      pct_gaps = 0,
      out_of_range = 0,
      non_integer = 0
    ))
  }
  
  # Get or generate item names
  if (is.null(item_names)) {
    item_names <- colnames(ranking_matrix)
    if (is.null(item_names)) {
      item_names <- paste0("Item_", seq_len(n_items))
    }
  }
  
  # ==============================================================================
  # NUMERIC TYPE CHECK
  # ==============================================================================
  # Should always pass after V9.9.3 guard, but keep as safety net
  
  if (!is.numeric(ranking_matrix)) {
    return(list(
      valid = FALSE,
      has_issues = TRUE,
      summary = paste(
        "Ranking matrix must contain numeric values\n",
        "  Current type:", typeof(ranking_matrix)
      ),
      n_respondents = n_respondents,
      n_items = n_items,
      pct_complete = 0,
      n_ties = 0,
      pct_ties = 0,
      respondents_with_ties = NULL,
      n_gaps = 0,
      pct_gaps = 0,
      out_of_range = 0,
      non_integer = 0
    ))
  }
  
  # ==============================================================================
  # DATA QUALITY DIAGNOSTICS
  # ==============================================================================
  
  valid_values <- ranking_matrix[!is.na(ranking_matrix)]
  
  # 1. RANGE CHECK: Values between 1 and num_positions
  out_of_range <- sum(valid_values < 1 | valid_values > num_positions)
  pct_out_of_range <- if (length(valid_values) > 0) {
    100 * out_of_range / length(valid_values)
  } else {
    0
  }
  
  # 2. INTEGER CHECK: Ranks should be whole numbers
  non_integer <- sum(valid_values != floor(valid_values))
  
  # 3. COMPLETENESS CHECK: Percentage of non-NA values
  n_na <- sum(is.na(ranking_matrix))
  pct_complete <- 100 * (1 - n_na / length(ranking_matrix))
  
  # 4. TIE DETECTION (V9.9.2: Vectorized with apply)
  # Check each respondent for duplicate ranks
  has_tie <- apply(ranking_matrix, 1, function(x) {
    y <- x[!is.na(x)]
    length(y) > 0 && any(duplicated(y))
  })
  
  n_ties <- sum(has_tie)
  pct_ties <- 100 * n_ties / n_respondents
  # Show first 10 respondents with ties (for debugging)
  respondents_with_ties <- if (n_ties > 0 && n_ties <= 10) {
    which(has_tie)
  } else {
    NULL
  }
  
  # 5. GAP DETECTION (V9.9.2: Vectorized with apply)
  # Check if ranks form sequence 1, 2, 3, ... (no skipped positions)
  has_gap <- apply(ranking_matrix, 1, function(x) {
    y <- sort(x[!is.na(x)])
    # If ranks are 1, 2, 3, ..., they equal seq_len(length)
    length(y) > 1 && !all(y == seq_len(length(y)))
  })
  
  n_gaps <- sum(has_gap)
  pct_gaps <- 100 * n_gaps / n_respondents
  
  # ==============================================================================
  # COMPILE ISSUES (V9.9.2: Configurable thresholds)
  # ==============================================================================
  
  has_issues <- (out_of_range > 0) || 
                (non_integer > 0) || 
                (pct_ties > tie_threshold_pct) || 
                (pct_gaps > gap_threshold_pct) || 
                (pct_complete < completeness_threshold_pct)
  
  issues <- c()
  
  if (out_of_range > 0) {
    issues <- c(issues, sprintf(
      "%d values (%.1f%%) out of valid range [1, %d]", 
      out_of_range, pct_out_of_range, num_positions
    ))
  }
  
  if (non_integer > 0) {
    issues <- c(issues, sprintf(
      "%d non-integer rank values (ranks should be whole numbers)", 
      non_integer
    ))
  }
  
  if (pct_ties > tie_threshold_pct) {
    issues <- c(issues, sprintf(
      "%.1f%% of respondents have tied ranks (threshold: %.0f%%)", 
      pct_ties, tie_threshold_pct
    ))
  }
  
  if (pct_gaps > gap_threshold_pct) {
    issues <- c(issues, sprintf(
      "%.1f%% of respondents have gaps in rankings (threshold: %.0f%%)", 
      pct_gaps, gap_threshold_pct
    ))
  }
  
  if (pct_complete < completeness_threshold_pct) {
    issues <- c(issues, sprintf(
      "Only %.1f%% complete (threshold: %.0f%%)", 
      pct_complete, completeness_threshold_pct
    ))
  }
  
  # Create summary message
  summary_text <- if (has_issues) {
    paste("Data quality issues detected:\n  ", paste(issues, collapse = "\n  "))
  } else {
    sprintf(
      "Data quality: %.1f%% complete, %.1f%% ties, %.1f%% gaps", 
      pct_complete, pct_ties, pct_gaps
    )
  }
  
  # ==============================================================================
  # RETURN DIAGNOSTICS
  # ==============================================================================
  
  return(list(
    valid = !has_issues,
    has_issues = has_issues,
    summary = summary_text,
    n_respondents = n_respondents,
    n_items = n_items,
    pct_complete = pct_complete,
    n_ties = n_ties,
    pct_ties = pct_ties,
    respondents_with_ties = respondents_with_ties,
    n_gaps = n_gaps,
    pct_gaps = pct_gaps,
    out_of_range = out_of_range,
    non_integer = non_integer
  ))
}


# ==============================================================================
# RANKING QUESTION STRUCTURE VALIDATION
# ==============================================================================

#' Validate ranking question structure from survey metadata
#'
#' @description
#' Validates that a ranking question has the required metadata fields in the
#' survey structure (Survey_Structure.xlsx). Logs any issues to error_log.
#' 
#' Checks for:
#' - Ranking_Format field (Position or Item)
#' - Ranking_Positions field (number of rank positions)
#' - Options table with items to rank
#' - Required option fields (DisplayText, OptionText)
#'
#' @details
#' **Required Fields in question_info:**
#' - QuestionCode: Unique question identifier
#' - Ranking_Format: Either "Position" or "Item"
#' - Ranking_Positions: Number of rank positions (e.g., 5 for top 5)
#'   OR Columns field with same info
#' 
#' **Required in options_info:**
#' - At least one option (item to rank)
#' - DisplayText: Display name for item
#' - OptionText: Internal name/code for item
#'
#' @param question_info Data frame row, single question metadata
#'   Must contain: QuestionCode, Ranking_Format, Ranking_Positions (or Columns)
#' @param options_info Data frame, options for this question
#'   Must contain: DisplayText, OptionText
#' @param error_log Data frame, existing error log to append to
#'   Must have structure compatible with log_issue() function
#'
#' @return Updated error_log data frame with any new issues appended
#'
#' @section Error Logging:
#' Uses log_issue() function to record validation errors:
#' - Module: "Ranking"
#' - Severity: "Error" for all ranking validation issues
#' - QuestionCode: Identifies which question has the issue
#'
#' @note This function requires log_issue() from core/logging.R
#'
#' @examples
#' # Valid ranking question
#' question <- data.frame(
#'   QuestionCode = "Q10",
#'   Ranking_Format = "Position",
#'   Ranking_Positions = 5
#' )
#' 
#' options <- data.frame(
#'   DisplayText = c("Brand A", "Brand B", "Brand C"),
#'   OptionText = c("BrandA", "BrandB", "BrandC")
#' )
#' 
#' error_log <- data.frame()  # Empty error log
#' error_log <- validate_ranking_question(question, options, error_log)
#' # error_log still empty (no issues)
#'
#' # Invalid ranking question (missing format)
#' invalid_question <- data.frame(
#'   QuestionCode = "Q11",
#'   Ranking_Positions = 5
#'   # Missing Ranking_Format!
#' )
#' 
#' error_log <- validate_ranking_question(invalid_question, options, error_log)
#' # error_log now contains error about missing Ranking_Format
#'
#' @export
#' @family ranking
validate_ranking_question <- function(question_info, options_info, error_log) {
  
  # ==============================================================================
  # INPUT VALIDATION
  # ==============================================================================
  
  if (!is.data.frame(question_info) || nrow(question_info) == 0) {
    stop(
      "question_info must be a non-empty data frame (single question row)",
      call. = FALSE
    )
  }
  
  if (!is.data.frame(options_info)) {
    stop(
      "options_info must be a data frame",
      call. = FALSE
    )
  }
  
  if (!is.data.frame(error_log)) {
    stop(
      "error_log must be a data frame",
      call. = FALSE
    )
  }
  
  # Extract question code
  question_code <- question_info$QuestionCode
  
  if (is.null(question_code) || is.na(question_code)) {
    stop(
      "question_info must contain QuestionCode column",
      call. = FALSE
    )
  }
  
  # ==============================================================================
  # CHECK: RANKING_FORMAT FIELD
  # ==============================================================================
  
  if (!"Ranking_Format" %in% names(question_info) || 
      is.na(question_info$Ranking_Format) ||
      trimws(question_info$Ranking_Format) == "") {
    
    error_log <- log_issue(
      error_log, 
      module = "Ranking", 
      issue_type = "Missing Ranking_Format",
      details = sprintf(
        "Ranking question %s missing Ranking_Format field. Add 'Position' or 'Item' to Survey_Structure.",
        question_code
      ),
      question_code = question_code, 
      severity = "Error"
    )
  } else {
    # Check format is valid (Position or Item)
    if (!question_info$Ranking_Format %in% c("Position", "Item")) {
      error_log <- log_issue(
        error_log, 
        module = "Ranking", 
        issue_type = "Invalid Ranking_Format",
        details = sprintf(
          "Question %s: Ranking_Format must be 'Position' or 'Item', got: '%s'",
          question_code,
          question_info$Ranking_Format
        ),
        question_code = question_code, 
        severity = "Error"
      )
    }
  }
  
  # ==============================================================================
  # CHECK: RANKING_POSITIONS FIELD
  # ==============================================================================
  
  has_positions <- FALSE
  
  # Try Ranking_Positions field first
  if ("Ranking_Positions" %in% names(question_info)) {
    positions <- suppressWarnings(as.numeric(question_info$Ranking_Positions))
    
    if (!is.na(positions) && positions > 0) {
      has_positions <- TRUE
    }
  }
  
  # Fallback to Columns field
  if (!has_positions && "Columns" %in% names(question_info)) {
    columns <- suppressWarnings(as.numeric(question_info$Columns))
    
    if (!is.na(columns) && columns > 0) {
      has_positions <- TRUE
    }
  }
  
  if (!has_positions) {
    error_log <- log_issue(
      error_log, 
      module = "Ranking", 
      issue_type = "Missing Ranking_Positions",
      details = sprintf(
        "Ranking question %s missing Ranking_Positions or Columns. Specify number of rank positions.",
        question_code
      ),
      question_code = question_code, 
      severity = "Error"
    )
  }
  
  # ==============================================================================
  # CHECK: OPTIONS EXIST
  # ==============================================================================
  
  if (nrow(options_info) == 0) {
    error_log <- log_issue(
      error_log, 
      module = "Ranking", 
      issue_type = "No Options",
      details = sprintf(
        "Ranking question %s has no options. Add items to rank in Survey_Structure options table.",
        question_code
      ),
      question_code = question_code, 
      severity = "Error"
    )
  } else {
    # Check options have required fields
    if (!"DisplayText" %in% names(options_info) || !"OptionText" %in% names(options_info)) {
      error_log <- log_issue(
        error_log, 
        module = "Ranking", 
        issue_type = "Incomplete Options",
        details = sprintf(
          "Ranking question %s options missing DisplayText or OptionText columns.",
          question_code
        ),
        question_code = question_code, 
        severity = "Error"
      )
    }
  }
  
  return(error_log)
}


# ==============================================================================
# MODULE METADATA
# ==============================================================================

# Module: validation.R
# Phase: 6 (Ranking)
# Status: Complete
# Dependencies: log_issue() from core/logging.R
# Functions: 2 (validate_ranking_matrix, validate_ranking_question)
# Lines: ~650
# Tested: Ready for testing

# ==============================================================================
