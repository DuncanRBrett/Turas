# ==============================================================================
# RANKING VALIDATION V10.0
# ==============================================================================
# Extracted from ranking.R for improved maintainability
# Contains all ranking data validation functions
#
# Part of R Survey Analytics Toolkit
# Module: Ranking - Validation
#
# CONTENTS:
# - Matrix validation helpers (dimensions, numeric quality, completeness)
# - Ranking quality checks (ties, gaps, out-of-range values)
# - Question configuration validation
# - Data quality reporting
#
# DEPENDENCIES:
# - shared_functions.R (for tabs_refuse error handling)
# - weighting.R (optional, for validation context)
# ==============================================================================

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
# RANKING QUESTION VALIDATION HELPERS (INTERNAL)
# ==============================================================================

#' Check Ranking_Format field
#' @keywords internal
check_ranking_format <- function(question_code, question_info, error_log) {
  if (!"Ranking_Format" %in% names(question_info) ||
      is.na(question_info$Ranking_Format) ||
      trimws(question_info$Ranking_Format) == "") {
    error_log <- log_issue(
      error_log,
      "Ranking",
      "Missing Ranking_Format",
      sprintf(
        "Ranking question %s missing Ranking_Format. Add 'Position' or 'Item' to Survey_Structure.",
        question_code
      ),
      question_code,
      "Error"
    )
  } else if (!question_info$Ranking_Format %in% c("Position", "Item")) {
    error_log <- log_issue(
      error_log,
      "Ranking",
      "Invalid Ranking_Format",
      sprintf(
        "Question %s: Ranking_Format must be 'Position' or 'Item', got: '%s'",
        question_code,
        question_info$Ranking_Format
      ),
      question_code,
      "Error"
    )
  }

  return(error_log)
}

#' Check Ranking_Positions field
#' @keywords internal
check_ranking_positions <- function(question_code, question_info, error_log) {
  has_positions <- FALSE

  if ("Ranking_Positions" %in% names(question_info)) {
    positions <- suppressWarnings(as.numeric(question_info$Ranking_Positions))

    if (!is.na(positions) && positions > 0) {
      has_positions <- TRUE
    }
  }

  if (!has_positions && "Columns" %in% names(question_info)) {
    columns <- suppressWarnings(as.numeric(question_info$Columns))

    if (!is.na(columns) && columns > 0) {
      has_positions <- TRUE
    }
  }

  if (!has_positions) {
    error_log <- log_issue(
      error_log,
      "Ranking",
      "Missing Ranking_Positions",
      sprintf(
        "Ranking question %s missing Ranking_Positions or Columns. Specify number of rank positions.",
        question_code
      ),
      question_code,
      "Error"
    )
  }

  return(error_log)
}

#' Check ranking options exist and are complete
#' @keywords internal
check_ranking_options <- function(question_code, options_info, error_log) {
  if (nrow(options_info) == 0) {
    error_log <- log_issue(
      error_log,
      "Ranking",
      "No Options",
      sprintf(
        "Ranking question %s has no options. Add items to rank in Survey_Structure options table.",
        question_code
      ),
      question_code,
      "Error"
    )
  } else {
    # Check options have required fields
    if (!"DisplayText" %in% names(options_info) || !"OptionText" %in% names(options_info)) {
      error_log <- log_issue(
        error_log,
        "Ranking",
        "Incomplete Options",
        sprintf(
          "Ranking question %s options missing DisplayText or OptionText columns.",
          question_code
        ),
        question_code,
        "Error"
      )
    }
  }

  return(error_log)
}

# ==============================================================================
# RANKING VALIDATION (V9.9.1)
# ==============================================================================

#' Validate ranking question setup in Survey_Structure
#'
#' @param question_info Question metadata row
#' @param options_info Options metadata for this question
#' @param error_log Error log data frame
#' @return Updated error log data frame
#' @export
validate_ranking_question <- function(question_info, options_info, error_log) {
  # Input validation
  if (!is.data.frame(question_info) || nrow(question_info) == 0) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: question_info",
      problem = "The question_info argument must be a non-empty data frame row.",
      why_it_matters = "Question metadata is required to validate ranking question configuration.",
      how_to_fix = "Provide a data frame row with question metadata from Survey_Structure"
    )
  }

  if (!is.data.frame(options_info)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: options_info",
      problem = sprintf("The options_info argument must be a data frame, got: %s", class(options_info)),
      why_it_matters = "Options metadata is required to validate that ranking items are properly configured.",
      how_to_fix = "Provide a data frame with option metadata from Survey_Structure"
    )
  }

  if (!is.data.frame(error_log)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: error_log",
      problem = sprintf("The error_log argument must be a data frame, got: %s", class(error_log)),
      why_it_matters = "Error log is used to record validation issues found during ranking question validation.",
      how_to_fix = "Provide a data frame for error_log with standard error logging columns"
    )
  }

  question_code <- question_info$QuestionCode

  if (is.null(question_code) || is.na(question_code)) {
    tabs_refuse(
      code = "ARG_MISSING_REQUIRED",
      title = "Missing Required Field: QuestionCode",
      problem = "The question_info must contain a QuestionCode.",
      why_it_matters = "QuestionCode is required to identify which question is being validated.",
      how_to_fix = "Ensure question_info data frame has a non-null QuestionCode field"
    )
  }

  # Run all ranking question validation checks (delegated to helpers)
  error_log <- check_ranking_format(question_code, question_info, error_log)
  error_log <- check_ranking_positions(question_code, question_info, error_log)
  error_log <- check_ranking_options(question_code, options_info, error_log)

  return(error_log)
}

# ==============================================================================
# END OF RANKING_VALIDATION.R V10.0
# ==============================================================================
