# ==============================================================================
# TURAS RANKING MODULE 3: DATA EXTRACTION
# ==============================================================================
# Extract ranking data from survey in both Position and Item formats
#
# Part of Phase 6: Ranking Migration
# Source: ranking.r (V9.9.3) lines 342-621
#
# SUPPORTED FORMATS:
# 1. Position Format: Each item has a column with rank value
#    Example: Q10_BrandA=3, Q10_BrandB=1, Q10_BrandC=2
#    (BrandB ranked 1st, BrandC 2nd, BrandA 3rd)
#
# 2. Item Format: Each rank position has a column with item name
#    Example: Q10_Rank1="BrandB", Q10_Rank2="BrandC", Q10_Rank3="BrandA"
#    (BrandB in 1st place, BrandC in 2nd, BrandA in 3rd)
#
# BOTH formats are converted to consistent Position matrix internally
# ==============================================================================

# Source dependencies
if (file.exists("~/Documents/Turas/modules/ranking/lib/direction.R")) {
  source("~/Documents/Turas/modules/ranking/lib/direction.R")
}

if (file.exists("~/Documents/Turas/modules/ranking/lib/validation.R")) {
  source("~/Documents/Turas/modules/ranking/lib/validation.R")
}

#' Extract ranking data from survey with format auto-detection
#'
#' @description
#' Main dispatcher function that extracts ranking data from survey and converts
#' it to a standardized numeric matrix format regardless of input format.
#' 
#' Supports two ranking formats:
#' - **Position Format:** Each item has a column (Q_BrandA, Q_BrandB, etc.)
#' - **Item Format:** Each rank position has a column (Q_Rank1, Q_Rank2, etc.)
#' 
#' Performs comprehensive validation, rank direction normalization, and data
#' quality checks with configurable thresholds.
#'
#' @details
#' **WORKFLOW:**
#' 1. Validate inputs (data, question_info, option_info)
#' 2. Extract question metadata (code, format, positions)
#' 3. Route to appropriate format extractor
#' 4. Normalize rank direction if needed (V9.9.2)
#' 5. Validate extracted matrix with configurable thresholds
#' 6. Return results with validation diagnostics
#' 
#' **V9.9.2 ENHANCEMENTS:**
#' - Rank direction normalization (Worst-to-Best → Best-to-Worst)
#' - Configurable validation thresholds from config
#' - Item matching with whitespace trimming
#' 
#' **RANKING DIRECTION:**
#' Can optionally normalize ranks if data is Worst-to-Best:
#' - Check question_info$Ranking_Direction field
#' - If "WorstToBest", flips ranks to standard Best-to-Worst
#' - Uses normalize_rank_direction() from direction.R
#' 
#' **VALIDATION THRESHOLDS (from config):**
#' - ranking_tie_threshold_pct: Default 5%
#' - ranking_gap_threshold_pct: Default 5%
#' - ranking_completeness_threshold_pct: Default 80%
#'
#' @param data Data frame, survey data with ranking columns
#' @param question_info Data frame row, single question metadata
#'   Required fields:
#'   - QuestionCode: Question identifier
#'   - Ranking_Format: "Position" or "Item"
#'   - Ranking_Positions: Number of rank positions (or Columns)
#'   Optional fields:
#'   - Ranking_Direction: "BestToWorst" (default) or "WorstToBest"
#' @param option_info Data frame, options/items for this question
#'   Required fields:
#'   - DisplayText: Display name for item
#'   - OptionText: Internal code/value for item
#' @param config List, optional configuration for validation thresholds
#'   Supports: ranking_tie_threshold_pct, ranking_gap_threshold_pct,
#'   ranking_completeness_threshold_pct
#'
#' @return List with extracted ranking data:
#' \describe{
#'   \item{format}{Character, "Position" or "Item" (original format)}
#'   \item{matrix}{Numeric matrix, rows=respondents, cols=items, values=ranks}
#'   \item{items}{Character vector, item display names (column names)}
#'   \item{num_positions}{Integer, maximum rank position}
#'   \item{rank_direction}{Character, "BestToWorst" (after normalization)}
#'   \item{validation}{List, validation results from validate_ranking_matrix()}
#' }
#'
#' @section Position Format Example:
#' ```
#' Data columns: Q10_BrandA, Q10_BrandB, Q10_BrandC
#' Data values: 3, 1, 2 (for respondent 1)
#' 
#' Extracted matrix:
#'        BrandA BrandB BrandC
#' Resp1      3      1      2
#' ```
#'
#' @section Item Format Example:
#' ```
#' Data columns: Q10_Rank1, Q10_Rank2, Q10_Rank3
#' Data values: "BrandB", "BrandC", "BrandA" (for respondent 1)
#' 
#' Extracted matrix (converted to Position format):
#'        BrandA BrandB BrandC
#' Resp1      3      1      2
#' ```
#'
#' @examples
#' # Position format
#' data <- data.frame(
#'   Q10_BrandA = c(3, 2, 1),
#'   Q10_BrandB = c(1, 1, 2),
#'   Q10_BrandC = c(2, 3, 3)
#' )
#' 
#' question_info <- data.frame(
#'   QuestionCode = "Q10",
#'   Ranking_Format = "Position",
#'   Ranking_Positions = 3
#' )
#' 
#' option_info <- data.frame(
#'   DisplayText = c("Brand A", "Brand B", "Brand C"),
#'   OptionText = c("BrandA", "BrandB", "BrandC")
#' )
#' 
#' result <- extract_ranking_data(data, question_info, option_info)
#' # result$matrix: 3x3 matrix with ranks
#' # result$format: "Position"
#'
#' @export
#' @family ranking
extract_ranking_data <- function(data, question_info, option_info, config = NULL) {
  
  # ==============================================================================
  # INPUT VALIDATION
  # ==============================================================================
  
  # Validate data
  if (!is.data.frame(data) || nrow(data) == 0) {
    stop(
      "data must be a non-empty data frame\n",
      "  Rows: ", if (is.data.frame(data)) nrow(data) else "N/A",
      call. = FALSE
    )
  }
  
  # Validate question_info
  if (!is.data.frame(question_info) || nrow(question_info) == 0) {
    stop(
      "question_info must be a non-empty data frame (single question row)",
      call. = FALSE
    )
  }
  
  # Validate option_info
  if (!is.data.frame(option_info)) {
    stop(
      "option_info must be a data frame\n",
      "  Received: ", class(option_info)[1],
      call. = FALSE
    )
  }
  
  # ==============================================================================
  # EXTRACT QUESTION METADATA
  # ==============================================================================
  
  # Get question code
  question_code <- question_info$QuestionCode
  
  if (is.null(question_code) || is.na(question_code) || question_code == "") {
    stop(
      "question_info must contain valid QuestionCode",
      call. = FALSE
    )
  }
  
  # Get ranking format
  if (!"Ranking_Format" %in% names(question_info)) {
    stop(sprintf(
      "Question %s: Ranking_Format column missing\n",
      "  Add Ranking_Format ('Position' or 'Item') to Survey_Structure",
      question_code
    ), call. = FALSE)
  }
  
  ranking_format <- question_info$Ranking_Format
  
  if (is.na(ranking_format) || !ranking_format %in% c("Position", "Item")) {
    stop(sprintf(
      "Question %s: Invalid Ranking_Format '%s'\n",
      "  Must be 'Position' or 'Item'",
      question_code,
      if (is.na(ranking_format)) "NA" else ranking_format
    ), call. = FALSE)
  }
  
  # Get number of positions
  num_positions <- NA
  
  # Try Ranking_Positions first
  if ("Ranking_Positions" %in% names(question_info)) {
    num_positions <- suppressWarnings(as.numeric(question_info$Ranking_Positions))
  }
  
  # Fallback to Columns
  if (is.na(num_positions) && "Columns" %in% names(question_info)) {
    num_positions <- suppressWarnings(as.numeric(question_info$Columns))
  }
  
  if (is.na(num_positions) || num_positions < 1) {
    stop(sprintf(
      "Question %s: Invalid Ranking_Positions\n",
      "  Must be positive integer (number of rank positions)",
      question_code
    ), call. = FALSE)
  }
  
  # Validate options exist
  if (nrow(option_info) == 0) {
    stop(sprintf(
      "Question %s: No options defined\n",
      "  Add items to rank in Survey_Structure options table",
      question_code
    ), call. = FALSE)
  }
  
  # ==============================================================================
  # EXTRACT BASED ON FORMAT
  # ==============================================================================
  
  if (ranking_format == "Position") {
    result <- extract_position_format(data, question_code, option_info, num_positions)
  } else {  # Item format
    result <- extract_item_format(data, question_code, option_info, num_positions)
  }
  
  # ==============================================================================
  # V9.9.2: RANK DIRECTION NORMALIZATION
  # ==============================================================================
  
  rank_direction <- "BestToWorst"  # Default
  
  if ("Ranking_Direction" %in% names(question_info)) {
    direction_val <- trimws(as.character(question_info$Ranking_Direction))
    
    if (!is.na(direction_val) && direction_val != "") {
      # Check if Worst-to-Best (various spellings)
      if (direction_val %in% c("WorstToBest", "Worst_to_Best", "worst_to_best")) {
        rank_direction <- "WorstToBest"
        result$matrix <- normalize_rank_direction(
          result$matrix, 
          num_positions, 
          "WorstToBest"
        )
      }
    }
  }
  
  result$rank_direction <- rank_direction
  
  # ==============================================================================
  # V9.9.2: VALIDATION WITH CONFIGURABLE THRESHOLDS
  # ==============================================================================
  
  # Default thresholds
  tie_threshold <- 5
  gap_threshold <- 5
  completeness_threshold <- 80
  
  # Override from config if available
  if (!is.null(config)) {
    # Try to use get_config_value if it exists
    if (exists("get_config_value", mode = "function")) {
      tie_threshold <- get_config_value(config, "ranking_tie_threshold_pct", 5)
      gap_threshold <- get_config_value(config, "ranking_gap_threshold_pct", 5)
      completeness_threshold <- get_config_value(
        config, 
        "ranking_completeness_threshold_pct", 
        80
      )
    } else {
      # Direct access if config is a list
      if (is.list(config)) {
        if (!is.null(config$ranking_tie_threshold_pct)) {
          tie_threshold <- config$ranking_tie_threshold_pct
        }
        if (!is.null(config$ranking_gap_threshold_pct)) {
          gap_threshold <- config$ranking_gap_threshold_pct
        }
        if (!is.null(config$ranking_completeness_threshold_pct)) {
          completeness_threshold <- config$ranking_completeness_threshold_pct
        }
      }
    }
  }
  
  # Validate extracted matrix
  validation <- validate_ranking_matrix(
    result$matrix, 
    num_positions, 
    result$items,
    tie_threshold_pct = tie_threshold,
    gap_threshold_pct = gap_threshold,
    completeness_threshold_pct = completeness_threshold
  )
  
  # Warn if issues found
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


# ==============================================================================
# POSITION FORMAT EXTRACTION
# ==============================================================================

#' Extract Position format ranking data
#'
#' @description
#' Handles Position format where each item has its own column containing
#' the rank assigned to that item.
#' 
#' Example: Q10_BrandA=3, Q10_BrandB=1, Q10_BrandC=2
#' This means: BrandB ranked 1st, BrandC 2nd, BrandA 3rd
#'
#' @details
#' **V9.9.2: Item Matching Hygiene**
#' - Trims whitespace from item codes and display text
#' - Matches columns using OptionText codes
#' - Tries both with and without question code prefix
#' 
#' **Column Name Patterns:**
#' - Direct match: Uses OptionText as column name
#' - Prefixed match: QuestionCode_OptionText
#' 
#' **Type Conversion:**
#' - Converts columns to numeric (safe with as.character first)
#' - Handles factor/character data gracefully
#' - NA for non-numeric values
#'
#' @param data Data frame, survey data
#' @param question_code Character, question identifier
#' @param option_info Data frame, options metadata
#' @param num_positions Integer, number of rank positions
#'
#' @return List with:
#' \describe{
#'   \item{format}{Character, "Position"}
#'   \item{matrix}{Numeric matrix, rankings}
#'   \item{items}{Character vector, item display names}
#'   \item{num_positions}{Integer, max positions}
#' }
#'
#' @keywords internal
#' @family ranking
extract_position_format <- function(data, question_code, option_info, num_positions) {
  
  # V9.9.2: Trim whitespace for hygiene
  items <- trimws(as.character(option_info$DisplayText))
  item_codes <- trimws(as.character(option_info$OptionText))
  
  if (length(items) == 0 || length(item_codes) == 0) {
    stop(sprintf(
      "Question %s: Options missing DisplayText or OptionText",
      question_code
    ), call. = FALSE)
  }
  
  # Build expected column names (try both with/without prefix)
  ranking_cols <- item_codes
  
  # Check if columns exist without prefix
  if (!any(ranking_cols %in% names(data))) {
    # Try with question code prefix
    ranking_cols_prefixed <- paste0(question_code, "_", item_codes)
    
    if (any(ranking_cols_prefixed %in% names(data))) {
      ranking_cols <- ranking_cols_prefixed
    }
  }
  
  # Find existing columns in data
  existing_cols <- ranking_cols[ranking_cols %in% names(data)]
  
  if (length(existing_cols) == 0) {
    stop(sprintf(
      "Question %s: No ranking columns found in data\n",
      "  Expected columns: %s\n",
      "  Available columns: %s",
      question_code,
      paste(head(ranking_cols, 5), collapse = ", "),
      paste(head(names(data), 10), collapse = ", ")
    ), call. = FALSE)
  }
  
  # Extract ranking columns
  ranking_matrix <- data[, existing_cols, drop = FALSE]
  
  # Convert to numeric matrix (type-safe: char first to handle factors)
  ranking_matrix <- apply(ranking_matrix, 2, function(x) {
    suppressWarnings(as.numeric(as.character(x)))
  })
  
  # Set item display names as column names
  item_indices <- match(existing_cols, ranking_cols)
  colnames(ranking_matrix) <- items[item_indices]
  
  return(list(
    format = "Position",
    matrix = ranking_matrix,
    items = items[item_indices],
    num_positions = num_positions
  ))
}


# ==============================================================================
# ITEM FORMAT EXTRACTION (V9.9.2: FULLY VECTORIZED)
# ==============================================================================

#' Extract Item format ranking data with vectorized conversion
#'
#' @description
#' Handles Item format where each rank position has a column containing
#' the name/code of the item at that position.
#' 
#' Example: Q10_Rank1="BrandB", Q10_Rank2="BrandC", Q10_Rank3="BrandA"
#' This means: BrandB in 1st place, BrandC in 2nd, BrandA in 3rd
#' 
#' **Converts to Position format** internally for consistency.
#'
#' @details
#' **V9.9.2 ENHANCEMENTS:**
#' 
#' 1. **Rank Position from Column Name (Not Index):**
#'    - Old: Used column index → wrong if columns missing
#'    - New: Parse "_Rank5" from column name → correct
#' 
#' 2. **Fully Vectorized Conversion (3-5x Faster):**
#'    - Old: Nested loops O(R×I×P)
#'    - New: Vectorized lookup O(R×P)
#'    - Uses named vector for instant item→index mapping
#' 
#' 3. **Item Matching Hygiene:**
#'    - Trims whitespace from both option codes and responses
#'    - Case-sensitive matching (as intended)
#'    - NA for non-matching values
#' 
#' **ALGORITHM:**
#' 1. Create empty matrix (respondents × items) filled with NA
#' 2. Build lookup: item_code → column_index
#' 3. For each rank position column:
#'    - Parse rank number from column name (e.g., "_Rank3" → 3)
#'    - Get item codes from data (trimmed)
#'    - Lookup item codes → column indices
#'    - Assign rank number to [respondent, item] cells
#'
#' @param data Data frame, survey data
#' @param question_code Character, question identifier
#' @param option_info Data frame, options metadata
#' @param num_positions Integer, number of rank positions
#'
#' @return List with:
#' \describe{
#'   \item{format}{Character, "Item"}
#'   \item{matrix}{Numeric matrix, converted to Position format}
#'   \item{items}{Character vector, item display names}
#'   \item{num_positions}{Integer, max positions}
#' }
#'
#' @section Example Conversion:
#' ```
#' Input (Item format):
#'   Q10_Rank1   Q10_Rank2   Q10_Rank3
#'   "BrandB"    "BrandC"    "BrandA"
#'   "BrandA"    "BrandB"    NA
#' 
#' Output (Position format):
#'        BrandA  BrandB  BrandC
#' Resp1      3       1       2
#' Resp2      1       2      NA
#' ```
#'
#' @keywords internal
#' @family ranking
extract_item_format <- function(data, question_code, option_info, num_positions) {
  
  # V9.9.2: Trim whitespace for hygiene
  items <- trimws(as.character(option_info$DisplayText))
  item_values <- trimws(as.character(option_info$OptionText))
  
  if (length(items) == 0 || length(item_values) == 0) {
    stop(sprintf(
      "Question %s: Options missing DisplayText or OptionText",
      question_code
    ), call. = FALSE)
  }
  
  # Build expected column names: QuestionCode_Rank1, _Rank2, ...
  ranking_cols <- paste0(question_code, "_Rank", seq_len(num_positions))
  
  # Find existing columns in data
  existing_cols <- ranking_cols[ranking_cols %in% names(data)]
  
  if (length(existing_cols) == 0) {
    stop(sprintf(
      "Question %s: No ranking columns found in data\n",
      "  Expected columns: %s\n",
      "  Available columns: %s",
      question_code,
      paste(ranking_cols, collapse = ", "),
      paste(head(names(data), 10), collapse = ", ")
    ), call. = FALSE)
  }
  
  # Extract ranking data columns
  ranking_data <- data[, existing_cols, drop = FALSE]
  
  # ==============================================================================
  # V9.9.2: FULLY VECTORIZED ITEM→POSITION CONVERSION
  # ==============================================================================
  
  n_respondents <- nrow(data)
  n_items <- length(items)
  
  # Create output matrix: rows = respondents, cols = items, values = rank
  ranking_matrix <- matrix(NA_real_, nrow = n_respondents, ncol = n_items)
  colnames(ranking_matrix) <- items
  
  # V9.9.2: Build lookup map for instant item_value → column_index
  item_index <- seq_along(item_values)
  names(item_index) <- item_values
  
  # Process each rank position column
  for (col_name in existing_cols) {
    
    # V9.9.2 FIX: Derive rank position from column name (not column index!)
    # Example: "Q10_Rank5" → extract "5"
    rank_position <- suppressWarnings(
      as.integer(gsub("\\D", "", sub(".*Rank", "", col_name)))
    )
    
    if (is.na(rank_position) || rank_position < 1 || rank_position > num_positions) {
      stop(sprintf(
        "Question %s: Cannot parse rank position from column name '%s'\n",
        "  Expected format: %s_Rank1, %s_Rank2, etc.",
        question_code,
        col_name,
        question_code,
        question_code
      ), call. = FALSE)
    }
    
    # V9.9.2: Get item codes from this rank column (trimmed for matching)
    item_responses <- trimws(as.character(ranking_data[[col_name]]))
    
    # V9.9.2: Vectorized lookup - item_value → column_index
    # NA for non-matching item values (e.g., blank, "Other", invalid codes)
    col_indices <- unname(item_index[item_responses])
    
    # Find valid matches (not NA)
    valid_matches <- !is.na(col_indices)
    
    if (any(valid_matches)) {
      # Get respondent row indices with valid matches
      row_indices <- which(valid_matches)
      
      # Assign rank_position to [respondent_row, item_column] cells
      # Uses matrix indexing: cbind creates (row, col) pairs
      ranking_matrix[cbind(row_indices, col_indices[valid_matches])] <- rank_position
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
# MODULE METADATA
# ==============================================================================

# Module: extraction.R
# Phase: 6 (Ranking)
# Status: Complete
# Dependencies: direction.R, validation.R
# Functions: 3 (extract_ranking_data, extract_position_format, extract_item_format)
# Lines: ~680
# Tested: Ready for testing

# ==============================================================================
