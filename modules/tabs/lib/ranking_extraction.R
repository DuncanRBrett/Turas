# ==============================================================================
# RANKING EXTRACTION V10.0
# ==============================================================================
# Extracted from ranking.R for improved maintainability
# Contains all ranking data extraction functions
#
# Part of R Survey Analytics Toolkit
# Module: Ranking - Extraction
#
# CONTENTS:
# - Rank direction normalization (Best-to-Worst, Worst-to-Best)
# - Position format extraction (each item has rank column)
# - Item format extraction (each rank has item column)
# - Metadata extraction and validation
# - Configuration helpers
#
# DEPENDENCIES:
# - shared_functions.R (for tabs_refuse error handling)
# - ranking_validation.R (for validate_ranking_matrix)
# ==============================================================================

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
# END OF RANKING_EXTRACTION.R V10.0
# ==============================================================================
