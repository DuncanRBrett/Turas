# ==============================================================================
# RANKING V10.1 - PHASE 2 REFACTORING
# ==============================================================================
# Functions for ranking question analysis with statistical rigor
# Part of R Survey Analytics Toolkit
#
# VERSION HISTORY:
# V10.1  - Phase 2 refactoring (2025-12-29)
#          - EXTRACTED: Question validation to ranking/ranking_validation.R
#          - EXTRACTED: Metric calculations to ranking/ranking_metrics.R
#          - ADDED: tabs_source() for subdirectory loading
#          - Reduced file size: 1,929 -> 1,280 lines (649 lines extracted)
# V9.9.3 - External review fix (2025-10-16)
#          - FIXED: Fail-fast numeric coercion guard in validate_ranking_matrix()
#          - Prevents silent character matrix conversion
#          - Checks all columns are numeric/integer64 before as.matrix()
#          - Enforces storage.mode = "double" for numeric matrix
# V9.9.2 - External review fixes (production hardening)
#          - FIXED: Item format rank misnumbering (derive from column name)
#          - FIXED: Vectorized Item→Position (O(R×I) not O(R×I×P), 3-5x faster)
#          - ADDED: Configurable validation thresholds (tie, gap, completeness)
#          - ADDED: Guard top_n vs num_positions (auto-clamp + warn)
#          - ADDED: Rank direction normalization (Worst-to-Best support)
#          - FIXED: Return shape parity (removed weights from first/top-n)
#          - IMPROVED: Named args in format_output_value calls
#          - ADDED: Item matching hygiene (trim whitespace in extraction)
#          - IMPROVED: Vectorized validation loops (apply-based, faster)
#          - ADDED: Configurable ranking_min_base from config
#          - ADDED: Legend note for mean rank interpretation
#          - MODULE COMPLETE & LOCKED FOR PRODUCTION
# V9.9.1 - World-class production release
# V8.0   - Previous version (DEPRECATED)
#
# RANKING METHODOLOGY:
# This script handles two ranking formats:
# 1. Position format: Each item has a column with rank (Q_BrandA = 3)
# 2. Item format: Each rank position has item name (Q_Rank1 = "BrandA")
#
# Statistical approach:
# - Mean rank: Lower is better (1st place = 1, 2nd = 2, etc.)
# - Weighted mean: Uses design weights with effective-n
# - Variance: Population variance for weighted data
# - Significance: t-tests on mean ranks using effective-n
# - Top-N: Percentage in top N positions (e.g., top 3 box)
#
# RANK DIRECTION:
# - Best-to-Worst (default): 1 = best, higher = worse
# - Worst-to-Best: 1 = worst, higher = better (auto-normalized to Best-to-Worst)
# ==============================================================================

SCRIPT_VERSION <- "10.1"

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

# Use shared_functions.R version if available, otherwise define minimal fallback
if (!exists("source_if_exists")) {
  source_if_exists <- function(file_path, envir = parent.frame()) {
    if (file.exists(file_path)) {
      tryCatch({
        sys.source(file_path, envir = envir)
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
}

source_if_exists("shared_functions.R")
source_if_exists("Scripts/shared_functions.R")
source_if_exists("weighting.R")
source_if_exists("Scripts/weighting.R")

# ==============================================================================
# SOURCE PHASE 2 SUBMODULES (V10.1)
# ==============================================================================
# V10.1: Ranking validation functions extracted to ranking/ranking_validation.R
# Use tabs_source() for reliable subdirectory loading

if (exists("tabs_source", mode = "function")) {
  # Use the Phase 2 sourcing mechanism
  tabs_source("ranking", "ranking_validation.R")
  tabs_source("ranking", "ranking_metrics.R")
} else {
  # Fallback: try to source directly (less reliable but maintains backward compat)
  .ranking_dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) getwd())
  .ranking_validation_path <- file.path(.ranking_dir, "ranking", "ranking_validation.R")
  if (file.exists(.ranking_validation_path)) {
    source(.ranking_validation_path)
  }
  .ranking_metrics_path <- file.path(.ranking_dir, "ranking", "ranking_metrics.R")
  if (file.exists(.ranking_metrics_path)) {
    source(.ranking_metrics_path)
  }
}

# ==============================================================================
# TRS v1.0: RANKING PARTIAL FAILURE TRACKING
# ==============================================================================
# Environment-based tracking of partial failures during ranking processing.
# The orchestrator can call ranking_get_partial_failures() after processing
# to collect any section-level failures that occurred.

# Private environment to track partial failures
.ranking_state <- new.env(parent = emptyenv())
.ranking_state$partial_failures <- list()

#' Reset ranking partial failures
#' Call before processing each question
#' @export
ranking_reset_partial_failures <- function() {
  .ranking_state$partial_failures <- list()
  invisible(NULL)
}

#' Record a ranking partial failure
#' @param section Character, the section that failed
#' @param stage Character, the processing stage
#' @param error Character, the error message
#' @keywords internal
ranking_record_partial_failure <- function(section, stage, error) {
  .ranking_state$partial_failures[[length(.ranking_state$partial_failures) + 1]] <- list(
    section = section,
    stage = stage,
    error = error
  )
  invisible(NULL)
}

#' Get ranking partial failures
#' Call after processing to collect any failures
#' @return List of partial failure records
#' @export
ranking_get_partial_failures <- function() {
  return(.ranking_state$partial_failures)
}

# ==============================================================================
# RANK DIRECTION NORMALIZATION (V9.9.2: NEW)
# ==============================================================================

#' Normalize ranks to consistent Best-to-Worst direction
#'
#' DESIGN: All internal calculations use Best-to-Worst (1 = best)
#' If data is Worst-to-Best (1 = worst), flip ranks: new_rank = (max + 1) - old_rank
#'
#' V9.9.2: NEW function for rank direction consistency
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#' @param num_positions Integer, maximum rank position
#' @param direction Character, "BestToWorst" or "WorstToBest"
#' @return Normalized matrix (always Best-to-Worst direction)
#' @export
#' @examples
#' # Data has 1=worst, 5=best → flip to 1=best, 5=worst
#' normalized <- normalize_rank_direction(matrix, 5, "WorstToBest")
normalize_rank_direction <- function(ranking_matrix, num_positions,
                                    direction = c("BestToWorst", "WorstToBest")) {
  # Input validation
  if (!is.matrix(ranking_matrix) && !is.data.frame(ranking_matrix)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: ranking_matrix",
      problem = "The ranking_matrix argument must be a matrix or data.frame.",
      why_it_matters = "Rank direction normalization requires a matrix structure to flip rank values.",
      how_to_fix = "Provide a matrix or data.frame object for ranking_matrix"
    )
  }

  if (!is.numeric(num_positions) || length(num_positions) != 1 || num_positions < 1) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid Argument Value: num_positions",
      problem = sprintf("The num_positions argument must be a single positive integer, got: %s",
                       paste(num_positions, collapse = ", ")),
      why_it_matters = "The number of ranking positions is needed to flip ranks (e.g., 1 becomes 5 in a 5-position ranking).",
      how_to_fix = "Provide a single positive integer for num_positions (e.g., 5 for ranking 1-5)"
    )
  }

  direction <- match.arg(direction)
  
  # If already Best-to-Worst, return as-is
  if (direction == "BestToWorst") {
    return(ranking_matrix)
  }
  
  # Flip ranks: 1 becomes num_positions, num_positions becomes 1
  out <- ranking_matrix
  valid <- !is.na(ranking_matrix)
  out[valid] <- (num_positions + 1) - ranking_matrix[valid]
  
  return(out)
}

# ==============================================================================
# RANKING MATRIX VALIDATION HELPERS (INTERNAL)
# ==============================================================================

#' Check if ranking matrix is empty
#' @keywords internal
check_matrix_dimensions <- function(ranking_matrix) {
  n_respondents <- nrow(ranking_matrix)
  n_items <- ncol(ranking_matrix)

  if (n_respondents == 0 || n_items == 0) {
    return(list(
      valid = FALSE,
      has_issues = TRUE,
      summary = "Ranking matrix is empty",
      n_respondents = 0,
      n_items = 0
    ))
  }

  return(list(valid = TRUE, n_respondents = n_respondents, n_items = n_items))
}

#' Check for out-of-range and non-integer values
#' @keywords internal
check_numeric_quality <- function(ranking_matrix, num_positions) {
  valid_values <- ranking_matrix[!is.na(ranking_matrix)]

  # Check range
  out_of_range <- sum(valid_values < 1 | valid_values > num_positions)
  pct_out_of_range <- if (length(valid_values) > 0) {
    100 * out_of_range / length(valid_values)
  } else {
    0
  }

  # Check for non-integer ranks
  non_integer <- sum(valid_values != floor(valid_values))

  return(list(
    out_of_range = out_of_range,
    pct_out_of_range = pct_out_of_range,
    non_integer = non_integer
  ))
}

#' Check ranking completeness
#' @keywords internal
check_ranking_completeness <- function(ranking_matrix) {
  n_na <- sum(is.na(ranking_matrix))
  pct_complete <- 100 * (1 - n_na / length(ranking_matrix))

  return(list(n_na = n_na, pct_complete = pct_complete))
}

#' Detect tied ranks (vectorized)
#' @keywords internal
detect_ranking_ties <- function(ranking_matrix) {
  has_tie <- apply(ranking_matrix, 1, function(x) {
    y <- x[!is.na(x)]
    length(y) > 0 && any(duplicated(y))
  })

  n_ties <- sum(has_tie)
  n_respondents <- nrow(ranking_matrix)
  pct_ties <- 100 * n_ties / n_respondents
  respondents_with_ties <- if (n_ties > 0 && n_ties <= 10) which(has_tie) else NULL

  return(list(
    n_ties = n_ties,
    pct_ties = pct_ties,
    respondents_with_ties = respondents_with_ties
  ))
}

#' Detect gaps in rankings (vectorized)
#' @keywords internal
detect_ranking_gaps <- function(ranking_matrix) {
  has_gap <- apply(ranking_matrix, 1, function(x) {
    y <- sort(x[!is.na(x)])
    length(y) > 1 && !all(y == seq_len(length(y)))
  })

  n_gaps <- sum(has_gap)
  n_respondents <- nrow(ranking_matrix)
  pct_gaps <- 100 * n_gaps / n_respondents

  return(list(n_gaps = n_gaps, pct_gaps = pct_gaps))
}

#' Compile validation issues based on thresholds
#' @keywords internal
compile_ranking_issues <- function(numeric_quality, completeness, ties, gaps,
                                   num_positions, tie_threshold_pct,
                                   gap_threshold_pct, completeness_threshold_pct) {
  has_issues <- (numeric_quality$out_of_range > 0) ||
                (numeric_quality$non_integer > 0) ||
                (ties$pct_ties > tie_threshold_pct) ||
                (gaps$pct_gaps > gap_threshold_pct) ||
                (completeness$pct_complete < completeness_threshold_pct)

  issues <- c()
  if (numeric_quality$out_of_range > 0) {
    issues <- c(issues, sprintf("%d values (%.1f%%) out of valid range [1, %d]",
                                numeric_quality$out_of_range,
                                numeric_quality$pct_out_of_range,
                                num_positions))
  }
  if (numeric_quality$non_integer > 0) {
    issues <- c(issues, sprintf("%d non-integer rank values", numeric_quality$non_integer))
  }
  if (ties$pct_ties > tie_threshold_pct) {
    issues <- c(issues, sprintf("%.1f%% of respondents have tied ranks (threshold: %.0f%%)",
                                ties$pct_ties, tie_threshold_pct))
  }
  if (gaps$pct_gaps > gap_threshold_pct) {
    issues <- c(issues, sprintf("%.1f%% of respondents have gaps in rankings (threshold: %.0f%%)",
                                gaps$pct_gaps, gap_threshold_pct))
  }
  if (completeness$pct_complete < completeness_threshold_pct) {
    issues <- c(issues, sprintf("Only %.1f%% complete (threshold: %.0f%%)",
                                completeness$pct_complete, completeness_threshold_pct))
  }

  summary_text <- if (has_issues) {
    paste("Data quality issues detected:\n  ", paste(issues, collapse = "\n  "))
  } else {
    sprintf("Data quality: %.1f%% complete, %.1f%% ties, %.1f%% gaps",
            completeness$pct_complete, ties$pct_ties, gaps$pct_gaps)
  }

  return(list(has_issues = has_issues, summary = summary_text))
}

# ==============================================================================
# RANKING DATA VALIDATION (V9.9.3: FAIL-FAST NUMERIC GUARD)
# ==============================================================================

#' Validate ranking matrix for data quality
#'
#' V9.9.3 ENHANCEMENTS:
#' - FIXED: Fail-fast numeric check before as.matrix() conversion
#' - If any column is character, as.matrix() silently converts entire matrix
#' - Now explicitly checks all columns are numeric/integer64 first
#' - Enforces storage.mode = "double" for numeric matrix
#'
#' V9.9.2 ENHANCEMENTS:
#' - Configurable thresholds (tie_threshold_pct, gap_threshold_pct, completeness_threshold_pct)
#' - Vectorized tie/gap detection (apply-based, faster)
#'
#' CHECKS PERFORMED:
#' - Matrix is numeric
#' - Values are in valid range (1 to num_positions)
#' - Detect tied ranks (same rank for multiple items by respondent)
#' - Detect gaps (missing rank positions)
#' - Calculate completeness
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#' @param num_positions Integer, maximum rank position
#' @param item_names Character vector, item names (for reporting)
#' @param tie_threshold_pct Numeric, threshold for tie warning (default: 5%)
#' @param gap_threshold_pct Numeric, threshold for gap warning (default: 5%)
#' @param completeness_threshold_pct Numeric, threshold for completeness warning (default: 80%)
#' @return List with validation results and diagnostics
#' @export
validate_ranking_matrix <- function(ranking_matrix, num_positions, item_names = NULL,
                                   tie_threshold_pct = 5,
                                   gap_threshold_pct = 5,
                                   completeness_threshold_pct = 80) {
  # Input validation
  if (!is.matrix(ranking_matrix) && !is.data.frame(ranking_matrix)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: ranking_matrix",
      problem = "The ranking_matrix argument must be a matrix or data.frame.",
      why_it_matters = "Ranking validation requires a matrix structure to check data quality across items and respondents.",
      how_to_fix = "Provide a matrix or data.frame object for ranking_matrix"
    )
  }

  if (!is.numeric(num_positions) || length(num_positions) != 1 || num_positions < 1) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid Argument Value: num_positions",
      problem = sprintf("The num_positions argument must be a single positive integer, got: %s",
                       paste(num_positions, collapse = ", ")),
      why_it_matters = "The number of ranking positions determines the valid range for rank values during validation.",
      how_to_fix = "Provide a single positive integer for num_positions (e.g., 5 for ranking 1-5)"
    )
  }

  # Validate thresholds
  if (!is.numeric(tie_threshold_pct) || tie_threshold_pct < 0 || tie_threshold_pct > 100) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid Argument Value: tie_threshold_pct",
      problem = sprintf("The tie_threshold_pct must be between 0 and 100, got: %s", tie_threshold_pct),
      why_it_matters = "Threshold percentages must be valid percentages to determine when to flag tied ranks as a data quality issue.",
      how_to_fix = "Provide a value between 0 and 100 for tie_threshold_pct"
    )
  }

  if (!is.numeric(gap_threshold_pct) || gap_threshold_pct < 0 || gap_threshold_pct > 100) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid Argument Value: gap_threshold_pct",
      problem = sprintf("The gap_threshold_pct must be between 0 and 100, got: %s", gap_threshold_pct),
      why_it_matters = "Threshold percentages must be valid percentages to determine when to flag gaps in ranks as a data quality issue.",
      how_to_fix = "Provide a value between 0 and 100 for gap_threshold_pct"
    )
  }

  if (!is.numeric(completeness_threshold_pct) || completeness_threshold_pct < 0 || completeness_threshold_pct > 100) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid Argument Value: completeness_threshold_pct",
      problem = sprintf("The completeness_threshold_pct must be between 0 and 100, got: %s", completeness_threshold_pct),
      why_it_matters = "Threshold percentages must be valid percentages to determine minimum acceptable data completeness.",
      how_to_fix = "Provide a value between 0 and 100 for completeness_threshold_pct"
    )
  }
  
  # V9.9.3: Fail-fast numeric check before conversion
  if (is.data.frame(ranking_matrix)) {
    # Ensure every column is numeric BEFORE as.matrix()
    # If any column is character, as.matrix() silently converts entire matrix to character!
    bad_cols <- names(ranking_matrix)[!sapply(ranking_matrix, function(x) {
      is.numeric(x) || inherits(x, "integer64")
    })]
    
    if (length(bad_cols) > 0) {
      tabs_refuse(
        code = "DATA_INVALID_TYPE",
        title = "Non-Numeric Ranking Columns",
        problem = sprintf("Ranking columns must be numeric, but these are not: %s",
                         paste(bad_cols, collapse = ", ")),
        why_it_matters = "Character columns in ranking data will cause as.matrix() to silently convert the entire matrix to character, breaking all numeric calculations.",
        how_to_fix = c(
          "Ensure all ranking columns contain numeric values only",
          "Check for text values that should be coded as numbers",
          "Verify data import preserved numeric types"
        )
      )
    }
    
    ranking_matrix <- as.matrix(ranking_matrix)
  }
  
  # V9.9.3: Enforce numeric matrix storage
  storage.mode(ranking_matrix) <- "double"

  # Check matrix dimensions (delegated to helper)
  dim_check <- check_matrix_dimensions(ranking_matrix)
  if (!dim_check$valid) {
    return(dim_check)
  }

  n_respondents <- dim_check$n_respondents
  n_items <- dim_check$n_items

  # Get item names
  if (is.null(item_names)) {
    item_names <- colnames(ranking_matrix)
    if (is.null(item_names)) {
      item_names <- paste0("Item_", seq_len(n_items))
    }
  }

  # Check if numeric (should always pass after V9.9.3 guard)
  if (!is.numeric(ranking_matrix)) {
    return(list(
      valid = FALSE,
      has_issues = TRUE,
      summary = "Ranking matrix must contain numeric values",
      n_respondents = n_respondents,
      n_items = n_items
    ))
  }

  # Run all validation checks (delegated to helpers)
  numeric_quality <- check_numeric_quality(ranking_matrix, num_positions)
  completeness <- check_ranking_completeness(ranking_matrix)
  ties <- detect_ranking_ties(ranking_matrix)
  gaps <- detect_ranking_gaps(ranking_matrix)

  # Compile issues (delegated to helper)
  issue_summary <- compile_ranking_issues(
    numeric_quality, completeness, ties, gaps,
    num_positions, tie_threshold_pct, gap_threshold_pct, completeness_threshold_pct
  )

  return(list(
    valid = !issue_summary$has_issues,
    has_issues = issue_summary$has_issues,
    summary = issue_summary$summary,
    n_respondents = n_respondents,
    n_items = n_items,
    pct_complete = completeness$pct_complete,
    n_ties = ties$n_ties,
    pct_ties = ties$pct_ties,
    respondents_with_ties = ties$respondents_with_ties,
    n_gaps = gaps$n_gaps,
    pct_gaps = gaps$pct_gaps,
    out_of_range = numeric_quality$out_of_range,
    non_integer = numeric_quality$non_integer
  ))
}

# ==============================================================================
# RANKING DATA EXTRACTION HELPERS (INTERNAL)
# ==============================================================================

#' Validate and extract question code
#' @keywords internal
extract_question_metadata <- function(question_info) {
  question_code <- question_info$QuestionCode

  if (is.null(question_code) || is.na(question_code) || question_code == "") {
    tabs_refuse(
      code = "ARG_MISSING_REQUIRED",
      title = "Missing Required Field: QuestionCode",
      problem = "The question_info must contain a valid QuestionCode.",
      why_it_matters = "QuestionCode is required to identify which question is being processed and to locate its data columns.",
      how_to_fix = "Ensure question_info data frame has a non-empty QuestionCode field"
    )
  }

  return(question_code)
}

#' Validate Ranking_Format field
#' @keywords internal
validate_ranking_format_field <- function(question_code, question_info) {
  if (!"Ranking_Format" %in% names(question_info)) {
    tabs_refuse(
      code = "CFG_MISSING_SETTING",
      title = "Missing Configuration: Ranking_Format",
      problem = sprintf("Question %s is missing the Ranking_Format column.", question_code),
      why_it_matters = "Ranking_Format determines how to extract ranking data (Position format vs Item format).",
      how_to_fix = "Add Ranking_Format column to Survey_Structure with value 'Position' or 'Item'"
    )
  }

  ranking_format <- question_info$Ranking_Format

  if (is.na(ranking_format) || !ranking_format %in% c("Position", "Item")) {
    tabs_refuse(
      code = "CFG_INVALID_VALUE",
      title = "Invalid Configuration: Ranking_Format",
      problem = sprintf("Question %s has invalid Ranking_Format '%s'. Must be 'Position' or 'Item'.",
                       question_code, ranking_format),
      why_it_matters = "Only 'Position' and 'Item' ranking formats are supported for data extraction.",
      how_to_fix = "Set Ranking_Format to either 'Position' or 'Item' in Survey_Structure"
    )
  }

  return(ranking_format)
}

#' Get number of ranking positions
#' @keywords internal
get_num_positions <- function(question_code, question_info) {
  num_positions <- NA

  if ("Ranking_Positions" %in% names(question_info)) {
    num_positions <- suppressWarnings(as.numeric(question_info$Ranking_Positions))
  }

  if (is.na(num_positions) && "Columns" %in% names(question_info)) {
    num_positions <- suppressWarnings(as.numeric(question_info$Columns))
  }

  if (is.na(num_positions) || num_positions < 1) {
    tabs_refuse(
      code = "CFG_INVALID_VALUE",
      title = "Invalid Configuration: Ranking_Positions",
      problem = sprintf("Question %s has invalid Ranking_Positions. Must be a positive integer.", question_code),
      why_it_matters = "Ranking_Positions defines how many rank positions are available (e.g., 5 for ranks 1-5).",
      how_to_fix = "Set Ranking_Positions or Columns to a positive integer in Survey_Structure"
    )
  }

  return(num_positions)
}

#' Get validation thresholds from config
#' @keywords internal
get_validation_thresholds <- function(config) {
  tie_threshold <- 5
  gap_threshold <- 5
  completeness_threshold <- 80

  if (!is.null(config) && exists("get_config_value", mode = "function")) {
    tie_threshold <- get_config_value(config, "ranking_tie_threshold_pct", 5)
    gap_threshold <- get_config_value(config, "ranking_gap_threshold_pct", 5)
    completeness_threshold <- get_config_value(config, "ranking_completeness_threshold_pct", 80)
  }

  return(list(
    tie = tie_threshold,
    gap = gap_threshold,
    completeness = completeness_threshold
  ))
}

#' Normalize rank direction if needed
#' @keywords internal
normalize_direction_if_needed <- function(question_info, result, num_positions) {
  rank_direction <- "BestToWorst"  # Default

  if ("Ranking_Direction" %in% names(question_info)) {
    direction_val <- trimws(as.character(question_info$Ranking_Direction))

    if (!is.na(direction_val) && direction_val != "") {
      if (direction_val %in% c("WorstToBest", "Worst_to_Best", "worst_to_best")) {
        rank_direction <- "WorstToBest"
        result$matrix <- normalize_rank_direction(result$matrix, num_positions, "WorstToBest")
      }
    }
  }

  result$rank_direction <- rank_direction
  return(result)
}

# ==============================================================================
# RANKING DATA EXTRACTION (V9.9.2: FIXED RANK NUMBERING)
# ==============================================================================

#' Extract ranking data from survey with comprehensive validation
#'
#' V9.9.2 ENHANCEMENTS:
#' - Rank direction normalization (Worst-to-Best auto-converted)
#' - Configurable validation thresholds
#' - Item matching hygiene (whitespace trimming)
#'
#' FORMATS SUPPORTED:
#' - Position: Each item has column with rank (Q_BrandA = 3, Q_BrandB = 1)
#' - Item: Each rank has column with item name (Q_Rank1 = "BrandA")
#'
#' @param data Survey data frame
#' @param question_info Question metadata
#' @param option_info Options metadata
#' @param config Configuration list (for validation thresholds)
#' @return List with format, matrix, items, num_positions, validation
#' @export
extract_ranking_data <- function(data, question_info, option_info, config = NULL) {
  # Input validation
  if (!is.data.frame(data) || nrow(data) == 0) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: data",
      problem = "The data argument must be a non-empty data frame.",
      why_it_matters = "Survey data is required to extract ranking information for analysis.",
      how_to_fix = "Provide a data frame with at least one row of survey data"
    )
  }

  if (!is.data.frame(question_info) || nrow(question_info) == 0) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: question_info",
      problem = "The question_info argument must be a non-empty data frame row.",
      why_it_matters = "Question metadata is required to understand ranking format and configuration.",
      how_to_fix = "Provide a data frame row with question metadata from Survey_Structure"
    )
  }

  if (!is.data.frame(option_info)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: option_info",
      problem = "The option_info argument must be a data frame.",
      why_it_matters = "Option metadata defines which items are being ranked.",
      how_to_fix = "Provide a data frame with option metadata from Survey_Structure"
    )
  }
  
  # Extract and validate question metadata (delegated to helpers)
  question_code <- extract_question_metadata(question_info)
  ranking_format <- validate_ranking_format_field(question_code, question_info)
  num_positions <- get_num_positions(question_code, question_info)

  # Validate options exist
  if (nrow(option_info) == 0) {
    tabs_refuse(
      code = "CFG_MISSING_SETTING",
      title = "Missing Configuration: Ranking Options",
      problem = sprintf("Question %s has no options defined.", question_code),
      why_it_matters = "Ranking questions require options to define which items are being ranked.",
      how_to_fix = "Add ranking items to the options table in Survey_Structure for this question"
    )
  }

  # Extract based on format
  if (ranking_format == "Position") {
    result <- extract_position_format(data, question_code, option_info, num_positions)
  } else {
    result <- extract_item_format(data, question_code, option_info, num_positions)
  }

  # Normalize rank direction if needed (delegated to helper)
  result <- normalize_direction_if_needed(question_info, result, num_positions)

  # Get validation thresholds (delegated to helper)
  thresholds <- get_validation_thresholds(config)

  # Validate extracted matrix
  validation <- validate_ranking_matrix(
    result$matrix,
    num_positions,
    result$items,
    tie_threshold_pct = thresholds$tie,
    gap_threshold_pct = thresholds$gap,
    completeness_threshold_pct = thresholds$completeness
  )
  
  if (validation$has_issues) {
    warning(sprintf(
      "Question %s: %s",
      question_code,
      validation$summary
    ), call. = FALSE)
  }
  
  result$validation <- validation
  
  return(result)
}

#' Extract Position format ranking data (internal)
#'
#' V9.9.2: Item matching hygiene (whitespace trimming)
#'
#' @param data Survey data frame
#' @param question_code Question code
#' @param option_info Options metadata
#' @param num_positions Number of ranking positions
#' @return List with format, matrix, items, num_positions
#' @keywords internal
extract_position_format <- function(data, question_code, option_info, num_positions) {
  # V9.9.2: Trim whitespace on item codes
  items <- trimws(as.character(option_info$DisplayText))
  item_codes <- trimws(as.character(option_info$OptionText))
  
  if (length(items) == 0 || length(item_codes) == 0) {
    tabs_refuse(
      code = "CFG_MISSING_SETTING",
      title = "Missing Configuration: Option Fields",
      problem = sprintf("Question %s options are missing DisplayText or OptionText.", question_code),
      why_it_matters = "DisplayText and OptionText are required to identify ranking items and their column names.",
      how_to_fix = "Ensure all options have both DisplayText and OptionText in Survey_Structure"
    )
  }
  
  # Build expected column names
  ranking_cols <- item_codes
  
  # Check if columns exist with question prefix
  if (!any(ranking_cols %in% names(data))) {
    # Try with question code prefix
    ranking_cols_prefixed <- paste0(question_code, "_", item_codes)
    
    if (any(ranking_cols_prefixed %in% names(data))) {
      ranking_cols <- ranking_cols_prefixed
    }
  }
  
  # Find existing columns
  existing_cols <- ranking_cols[ranking_cols %in% names(data)]
  
  if (length(existing_cols) == 0) {
    tabs_refuse(
      code = "DATA_COLUMN_NOT_FOUND",
      title = "Ranking Columns Not Found",
      problem = sprintf("Question %s: No ranking columns found in data.", question_code),
      why_it_matters = "Without ranking columns, no ranking data can be extracted for analysis.",
      how_to_fix = c(
        sprintf("Expected columns: %s", paste(head(ranking_cols, 5), collapse = ", ")),
        "Check that data column names match Survey_Structure option codes",
        "Verify data import preserved ranking columns"
      )
    )
  }
  
  # Extract ranking matrix
  ranking_matrix <- data[, existing_cols, drop = FALSE]
  
  # Convert to numeric matrix (type-safe)
  ranking_matrix <- apply(ranking_matrix, 2, function(x) {
    suppressWarnings(as.numeric(as.character(x)))
  })
  
  # Set item names as column names
  item_indices <- match(existing_cols, ranking_cols)
  colnames(ranking_matrix) <- items[item_indices]
  
  return(list(
    format = "Position",
    matrix = ranking_matrix,
    items = items[item_indices],
    num_positions = num_positions
  ))
}

#' Extract Item format ranking data with fully vectorized conversion
#'
#' V9.9.2 FIXES:
#' - Derive rank_position from column name (not col_idx)
#' - Fully vectorized (no inner item loop, 3-5x faster)
#' - Item matching hygiene (whitespace trimming)
#'
#' @param data Survey data frame
#' @param question_code Question code
#' @param option_info Options metadata
#' @param num_positions Number of ranking positions
#' @return List with format, matrix, items, num_positions
#' @keywords internal
extract_item_format <- function(data, question_code, option_info, num_positions) {
  # V9.9.2: Trim whitespace on item values
  items <- trimws(as.character(option_info$DisplayText))
  item_values <- trimws(as.character(option_info$OptionText))
  
  if (length(items) == 0 || length(item_values) == 0) {
    tabs_refuse(
      code = "CFG_MISSING_SETTING",
      title = "Missing Configuration: Option Fields",
      problem = sprintf("Question %s options are missing DisplayText or OptionText.", question_code),
      why_it_matters = "DisplayText and OptionText are required to identify ranking items and match them to responses.",
      how_to_fix = "Ensure all options have both DisplayText and OptionText in Survey_Structure"
    )
  }
  
  # Build expected column names
  ranking_cols <- paste0(question_code, "_Rank", seq_len(num_positions))
  
  # Find existing columns
  existing_cols <- ranking_cols[ranking_cols %in% names(data)]
  
  if (length(existing_cols) == 0) {
    tabs_refuse(
      code = "DATA_COLUMN_NOT_FOUND",
      title = "Ranking Columns Not Found",
      problem = sprintf("Question %s: No ranking columns found in data.", question_code),
      why_it_matters = "Without ranking columns, no ranking data can be extracted for Item format analysis.",
      how_to_fix = c(
        sprintf("Expected columns: %s", paste(ranking_cols, collapse = ", ")),
        "Check that data has columns matching pattern: QuestionCode_Rank1, QuestionCode_Rank2, etc.",
        "Verify data import preserved ranking columns"
      )
    )
  }
  
  # Extract ranking data
  ranking_data <- data[, existing_cols, drop = FALSE]
  
  # V9.9.2: Fully vectorized Item→Position conversion
  # Create output matrix: rows = respondents, cols = items, values = rank
  n_respondents <- nrow(data)
  n_items <- length(items)
  
  ranking_matrix <- matrix(NA_real_, nrow = n_respondents, ncol = n_items)
  colnames(ranking_matrix) <- items
  
  # V9.9.2: Build lookup map (item_value → column index)
  item_index <- seq_along(item_values)
  names(item_index) <- item_values
  
  # Process each rank column
  for (col_name in existing_cols) {
    # V9.9.2 FIX: Derive rank position from column name (not col_idx)
    rank_position <- suppressWarnings(
      as.integer(gsub("\\D", "", sub(".*Rank", "", col_name)))
    )
    
    if (is.na(rank_position) || rank_position < 1 || rank_position > num_positions) {
      tabs_refuse(
        code = "DATA_INVALID_FORMAT",
        title = "Invalid Rank Column Name",
        problem = sprintf("Question %s: Cannot parse rank position from column name '%s'.",
                         question_code, col_name),
        why_it_matters = "Item format ranking requires column names matching the pattern QuestionCode_Rank# to determine rank positions.",
        how_to_fix = c(
          "Ensure ranking columns follow the pattern: QuestionCode_Rank1, QuestionCode_Rank2, etc.",
          sprintf("Expected rank position between 1 and %d", num_positions),
          "Check data column naming conventions"
        )
      )
    }
    
    # V9.9.2: Get item responses (trimmed for matching hygiene)
    resp <- trimws(as.character(ranking_data[[col_name]]))
    
    # V9.9.2: Vectorized lookup (item_value → column index)
    idx <- unname(item_index[resp])  # NA for non-matches
    good <- !is.na(idx)
    
    if (any(good)) {
      rows <- which(good)
      # Assign rank_position to these respondents for the matched items
      ranking_matrix[cbind(rows, idx[good])] <- rank_position
    }
  }
  
  return(list(
    format = "Item",
    matrix = ranking_matrix,
    items = items,
    num_positions = num_positions
  ))
}

# ==============================================================================
# RANKING METRICS (V10.1 - Phase 2 Refactoring)
# ==============================================================================
# V10.1: Ranking metric functions extracted to ranking/ranking_metrics.R
# Functions available after sourcing:
#   - calculate_percent_ranked_first()
#   - calculate_percent_top_n()
#   - calculate_mean_rank()
#   - calculate_rank_variance()
#   - prepare_rank_comparison_data()
#   - run_mean_rank_test()
#   - compare_mean_ranks()
# ==============================================================================

# ==============================================================================
# RANKING CROSSTAB ROWS (V9.9.2: NAMED ARGS & TOP_N GUARD)
# ==============================================================================

# ==============================================================================
# RANKING ROW CREATION HELPERS (INTERNAL)
# ==============================================================================

#' Get banner subset matrix and weights
#' @keywords internal
get_banner_subset_and_weights <- function(key, banner_data_list, ranking_matrix, weights_list) {
  subset_data <- banner_data_list[[key]]

  # Check if subset has data
  if (is.null(subset_data) || !is.data.frame(subset_data) || nrow(subset_data) == 0) {
    return(list(valid = FALSE, reason = "no_data"))
  }

  # Get subset indices
  if (".original_row" %in% names(subset_data)) {
    subset_idx <- subset_data$.original_row
  } else {
    subset_idx <- seq_len(nrow(subset_data))
  }

  # Validate indices
  if (any(subset_idx < 1 | subset_idx > nrow(ranking_matrix))) {
    return(list(valid = FALSE, reason = "invalid_indices"))
  }

  subset_matrix <- ranking_matrix[subset_idx, , drop = FALSE]

  # Get weights
  subset_weights <- if (!is.null(weights_list) && key %in% names(weights_list)) {
    weights_list[[key]]
  } else {
    rep(1, length(subset_idx))
  }

  # Validate weights length
  if (length(subset_weights) != length(subset_idx)) {
    subset_weights <- rep(1, length(subset_idx))
  }

  return(list(
    valid = TRUE,
    subset_matrix = subset_matrix,
    subset_weights = subset_weights
  ))
}

#' Format ranking output value
#' @keywords internal
format_ranking_value <- function(value, value_type, decimal_places_percent, decimal_places_index) {
  if (exists("format_output_value", mode = "function")) {
    if (value_type == "percent") {
      format_output_value(
        value,
        "percent",
        decimal_places_percent = decimal_places_percent,
        decimal_places_ratings = NULL,
        decimal_places_index = NULL
      )
    } else {  # "index"
      format_output_value(
        value,
        "index",
        decimal_places_percent = NULL,
        decimal_places_ratings = NULL,
        decimal_places_index = decimal_places_index
      )
    }
  } else {
    # Fallback if format_output_value not available
    if (is.na(value)) {
      NA
    } else if (value_type == "percent") {
      round(value, decimal_places_percent)
    } else {
      round(value, decimal_places_index)
    }
  }
}

#' Calculate all ranking metrics for one banner column
#' @keywords internal
calculate_banner_ranking_metrics <- function(subset_matrix, item_name, subset_weights,
                                             show_top_n, top_n, num_positions,
                                             decimal_places_percent, decimal_places_index) {
  result <- list()

  # % Ranked 1st
  first_result <- calculate_percent_ranked_first(subset_matrix, item_name, subset_weights)
  result$pct_first <- format_ranking_value(
    first_result$percentage, "percent",
    decimal_places_percent, decimal_places_index
  )

  # Mean Rank
  mean_rank <- calculate_mean_rank(subset_matrix, item_name, subset_weights)
  result$mean_rank <- format_ranking_value(
    mean_rank, "index",
    decimal_places_percent, decimal_places_index
  )

  # % Top N
  if (show_top_n) {
    top_n_result <- calculate_percent_top_n(
      subset_matrix, item_name, top_n,
      num_positions = num_positions,
      weights = subset_weights
    )
    result$pct_top_n <- format_ranking_value(
      top_n_result$percentage, "percent",
      decimal_places_percent, decimal_places_index
    )
  }

  return(result)
}

#' Create crosstab rows for one ranking item
#'
#' V9.9.2 ENHANCEMENTS:
#' - Named args in format_output_value calls
#' - top_n guard vs num_positions
#' - Legend note for mean rank interpretation
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#' @param item_name Character, item to create rows for
#' @param banner_data_list List of data subsets by banner column
#' @param banner_info Banner structure metadata
#' @param internal_keys Character vector, internal column keys
#' @param weights_list List of weight vectors by banner column
#' @param show_top_n Logical, whether to show top N percentage (default: TRUE)
#' @param top_n Integer, top N positions (default: 3)
#' @param num_positions Integer, total ranking positions (for validation)
#' @param decimal_places_percent Integer, decimals for percentages (default: 0)
#' @param decimal_places_index Integer, decimals for mean rank (default: 1)
#' @param add_legend Logical, add legend note to mean rank row (default: TRUE)
#' @return List of data frames (one per row)
#' @export
create_ranking_rows_for_item <- function(ranking_matrix, item_name, banner_data_list,
                                        banner_info, internal_keys, weights_list,
                                        show_top_n = TRUE, top_n = 3,
                                        num_positions = NULL,
                                        decimal_places_percent = 0,
                                        decimal_places_index = 1,
                                        add_legend = TRUE) {
  # Input validation
  if (!is.matrix(ranking_matrix) && !is.data.frame(ranking_matrix)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: ranking_matrix",
      problem = "The ranking_matrix argument must be a matrix or data.frame.",
      why_it_matters = "Crosstab row creation requires a matrix structure to calculate metrics across banner columns.",
      how_to_fix = "Provide a matrix or data.frame object for ranking_matrix"
    )
  }

  if (!is.character(item_name) || length(item_name) != 1) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: item_name",
      problem = sprintf("The item_name argument must be a single character string, got: %s",
                       class(item_name)),
      why_it_matters = "Item name identifies which ranking item to create crosstab rows for.",
      how_to_fix = "Provide a single character string for item_name matching a column in ranking_matrix"
    )
  }

  if (!is.list(banner_data_list)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: banner_data_list",
      problem = sprintf("The banner_data_list argument must be a list, got: %s", class(banner_data_list)),
      why_it_matters = "Banner data list contains data subsets for each banner column needed for crosstab.",
      how_to_fix = "Provide a list of data frames, one for each banner column"
    )
  }

  if (!is.character(internal_keys)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: internal_keys",
      problem = sprintf("The internal_keys argument must be a character vector, got: %s",
                       class(internal_keys)),
      why_it_matters = "Internal keys identify which banner columns to include in the crosstab.",
      how_to_fix = "Provide a character vector of banner column keys"
    )
  }
  
  # V9.9.2: Guard top_n vs num_positions
  if (!is.null(num_positions) && top_n > num_positions) {
    warning(sprintf(
      "top_n (%d) exceeds available positions (%d), clamping to %d",
      top_n, num_positions, num_positions
    ), call. = FALSE, immediate. = TRUE)
    top_n <- num_positions
  }
  
  results <- list()
  
  # Row 1: % Ranked 1st
  pct_first_row <- data.frame(
    RowLabel = paste0(item_name, " - % Ranked 1st"),
    RowType = "Column %",
    stringsAsFactors = FALSE
  )
  
  # Row 2: Mean Rank (V9.9.2: Add legend note)
  mean_rank_label <- paste0(item_name, " - Mean Rank")
  if (add_legend) {
    mean_rank_label <- paste0(mean_rank_label, " (Lower = Better)")
  }
  
  mean_rank_row <- data.frame(
    RowLabel = mean_rank_label,
    RowType = "Average",
    stringsAsFactors = FALSE
  )
  
  # Row 3: % Top N (optional, V9.9.2: Dynamic top_n in label)
  if (show_top_n) {
    top_n_row <- data.frame(
      RowLabel = paste0(item_name, " - % Top ", top_n),
      RowType = "Column %",
      stringsAsFactors = FALSE
    )
  }
  
  # Calculate for each banner column (delegated to helpers)
  for (key in internal_keys) {
    # Get banner subset and weights (delegated to helper)
    subset_result <- get_banner_subset_and_weights(key, banner_data_list, ranking_matrix, weights_list)

    if (!subset_result$valid) {
      # Handle invalid subset
      if (subset_result$reason == "invalid_indices") {
        warning(sprintf("Invalid row indices for banner %s, skipping", key), call. = FALSE)
      }
      pct_first_row[[key]] <- NA
      mean_rank_row[[key]] <- NA
      if (show_top_n) top_n_row[[key]] <- NA
      next
    }

    # Calculate metrics with error handling (delegated to helper)
    tryCatch({
      metrics <- calculate_banner_ranking_metrics(
        subset_result$subset_matrix, item_name, subset_result$subset_weights,
        show_top_n, top_n, num_positions,
        decimal_places_percent, decimal_places_index
      )

      pct_first_row[[key]] <- metrics$pct_first
      mean_rank_row[[key]] <- metrics$mean_rank
      if (show_top_n) top_n_row[[key]] <- metrics$pct_top_n
    }, error = function(e) {
      warning(sprintf(
        "Error calculating ranking metrics for banner %s: %s",
        key,
        conditionMessage(e)
      ), call. = FALSE)
      pct_first_row[[key]] <- NA
      mean_rank_row[[key]] <- NA
      if (show_top_n) top_n_row[[key]] <- NA
    })
  }
  
  results[[1]] <- pct_first_row
  results[[2]] <- mean_rank_row
  if (show_top_n) {
    results[[3]] <- top_n_row
  }
  
  return(results)
}

# ==============================================================================
# RANKING QUESTION VALIDATION (V10.1 - Phase 2 Refactoring)
# ==============================================================================
# V10.1: Ranking question validation functions extracted to ranking/ranking_validation.R
# Functions available after sourcing:
#   - check_ranking_format()
#   - check_ranking_positions()
#   - check_ranking_options()
#   - validate_ranking_question()
# ==============================================================================

# ==============================================================================
# MAINTENANCE DOCUMENTATION
# ==============================================================================
#
# OVERVIEW:
# This script handles ranking question analysis with statistical rigor.
# Supports both Position and Item ranking formats with comprehensive
# validation, weighted analysis, and significance testing.
#
# V9.9.3 ENHANCEMENTS (EXTERNAL REVIEW FIX):
# 1. FIXED: Fail-fast numeric coercion guard in validate_ranking_matrix()
#    - If data.frame has ANY character column, as.matrix() silently converts
#      entire matrix to character, breaking all numeric calculations
#    - Now checks all columns are numeric/integer64 before conversion
#    - Enforces storage.mode = "double" for numeric matrix
#    - Provides clear error message if non-numeric columns found
#
# V9.9.2 IMPROVEMENTS (EXTERNAL REVIEW):
# 1. FIXED: Item format rank misnumbering (derive from column name)
# 2. FIXED: Fully vectorized Item→Position (3-5x faster, cleaner code)
# 3. ADDED: Configurable validation thresholds (tie, gap, completeness)
# 4. ADDED: Guard top_n vs num_positions (auto-clamp + warn)
# 5. ADDED: Rank direction normalization (Worst-to-Best support)
# 6. FIXED: Return shape parity (removed weights from returns)
# 7. IMPROVED: Named args in format_output_value calls (safer)
# 8. ADDED: Item matching hygiene (whitespace trimming)
# 9. IMPROVED: Vectorized validation loops (apply-based, faster)
# 10. ADDED: Configurable ranking_min_base from config
# 11. ADDED: Legend note for mean rank interpretation ("Lower = Better")
#
# MODULE COMPLETE & PRODUCTION-READY
#
# TESTING PROTOCOL:
# 1. Unit tests for all metrics
# 2. Format conversion (Position ↔ Item, both directions)
# 3. Edge cases (ties, gaps, incomplete, out-of-range, top_n>positions)
# 4. Weighted vs unweighted (match expectations)
# 5. Significance testing (known rankings)
# 6. Performance (vectorized, no O(n²))
# 7. V9.9.2: Rank numbering with missing columns
# 8. V9.9.2: Direction normalization (Worst-to-Best → Best-to-Worst)
# 9. V9.9.3: Character column detection (fail-fast test)
#
# CONFIGURATION OPTIONS (V9.9.2+):
# - ranking_tie_threshold_pct: Tie warning threshold (default: 5%)
# - ranking_gap_threshold_pct: Gap warning threshold (default: 5%)
# - ranking_completeness_threshold_pct: Completeness threshold (default: 80%)
# - ranking_min_base: Minimum base for significance testing (default: 10)
#
# BACKWARD COMPATIBILITY:
# - V8.0 → V9.9.3: MOSTLY COMPATIBLE (new params have defaults)
# - V9.9.1 → V9.9.3: FULLY COMPATIBLE (internal improvements only)
# - V9.9.2 → V9.9.3: FULLY COMPATIBLE (validation improvement only)
#
# COMMON ISSUES:
# 1. "Ranking columns not numeric": Character column in data - check data types
# 2. "Cannot parse rank position": Column name doesn't match _Rank# pattern
# 3. "Invalid Ranking_Format": Check Survey_Structure Ranking_Format column
# 4. "No ranking columns found": Verify column names match expected pattern
# 5. "top_n exceeds positions": Auto-clamped with warning
#
# ==============================================================================
# END OF RANKING.R V10.1 - PHASE 2 REFACTORING
# ==============================================================================