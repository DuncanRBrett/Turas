# ==============================================================================
# TURAS RANKING MODULE 5: OUTPUT GENERATION (COMPLETE & CORRECTED)
# ==============================================================================
# Generate formatted output rows for ranking questions in crosstabs
#
# Part of Phase 6: Ranking Migration
# Source: ranking.r (V9.9.3) lines 1038-1224
#
# OUTPUT ROWS GENERATED:
# 1. % Ranked 1st - Percentage who ranked item in 1st place
# 2. Mean Rank - Average rank position (Lower = Better)
# 3. % Top N (optional) - Percentage in top N positions (e.g., Top 3 Box)
#
# INTEGRATES:
# - All calculation functions from Module 4
# - Weighted calculations with effective-n
# - Format output values for Excel/display
# - Banner column processing
#
# FIX: Simplified format_output_value fallback (no Phase 1 dependency)
# ==============================================================================

# Source dependencies
if (file.exists("~/Documents/Turas/modules/ranking/lib/calculations.R")) {
  source("~/Documents/Turas/modules/ranking/lib/calculations.R")
}

#' Create crosstab output rows for one ranking item
#'
#' @description
#' Generates formatted output rows for a single ranking item across all
#' banner columns in a crosstab.
#' 
#' Creates up to 3 rows per item:
#' - **% Ranked 1st:** Percentage who ranked this item first
#' - **Mean Rank:** Average rank position (with "Lower = Better" legend)
#' - **% Top N:** Percentage in top N positions (optional, e.g., Top 3 Box)
#'
#' @details
#' **V9.9.2 ENHANCEMENTS:**
#' - Named arguments in format_output_value calls (safer)
#' - Guard top_n vs num_positions (auto-clamp with warning)
#' - Legend note for mean rank interpretation
#' - Dynamic top_n in label (e.g., "% Top 3", "% Top 5")
#' 
#' **CORRECTED:** Simplified output formatting (no format_output_value dependency)
#' 
#' **WORKFLOW:**
#' 1. Create row templates (RowLabel, RowType)
#' 2. For each banner column:
#'    - Get data subset
#'    - Extract ranking matrix subset
#'    - Get weights for subset
#'    - Calculate metrics (% first, mean, % top N)
#'    - Format values
#'    - Add to row
#' 3. Return list of row data frames
#' 
#' **BANNER INTEGRATION:**
#' Processes each banner column independently, calculating statistics
#' for the respondent subset in that column.
#' 
#' **WEIGHTING:**
#' - Uses weights_list to apply design weights
#' - Calculates effective-n for weighted data
#' - Falls back to unweighted if weights missing
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#'   Full ranking matrix for all respondents
#' @param item_name Character, name of item to create rows for
#'   Must be in colnames(ranking_matrix)
#' @param banner_data_list List of data frame subsets by banner column
#'   Names are internal_keys, values are data subsets
#'   Each subset should have .original_row column for indexing
#' @param banner_info Banner structure metadata (not used directly here)
#'   Provided for future extensibility
#' @param internal_keys Character vector, banner column keys
#'   Order determines output column order
#' @param weights_list List of weight vectors by banner column
#'   Names match internal_keys
#'   If NULL or missing for a column, uses unweighted (all 1s)
#' @param show_top_n Logical, whether to show "% Top N" row (default: TRUE)
#' @param top_n Integer, number of top positions (default: 3)
#'   E.g., 3 = Top 3 Box (ranks 1, 2, 3)
#' @param num_positions Integer, total ranking positions (optional)
#'   Used to validate top_n doesn't exceed available positions
#' @param decimal_places_percent Integer, decimals for percentages (default: 0)
#'   Controls formatting of % Ranked 1st and % Top N
#' @param decimal_places_index Integer, decimals for mean rank (default: 1)
#'   Controls formatting of Mean Rank
#' @param add_legend Logical, add "(Lower = Better)" to Mean Rank label (default: TRUE)
#'
#' @return List of data frames (one per row):
#' \describe{
#'   \item{[[1]]}{Data frame: % Ranked 1st row}
#'   \item{[[2]]}{Data frame: Mean Rank row}
#'   \item{[[3]]}{Data frame: % Top N row (if show_top_n = TRUE)}
#' }
#' 
#' Each data frame has:
#' - RowLabel: Character, row description
#' - RowType: Character, "Column %" or "Average"
#' - One column per banner column (internal_keys) with calculated values
#'
#' @section Row Structure Example:
#' ```
#' # For item "Brand A" across 3 banner columns (Total, Male, Female):
#' 
#' Row 1:
#'   RowLabel = "Brand A - % Ranked 1st"
#'   RowType = "Column %"
#'   Total = 35.0
#'   Male = 40.0
#'   Female = 30.0
#' 
#' Row 2:
#'   RowLabel = "Brand A - Mean Rank (Lower = Better)"
#'   RowType = "Average"
#'   Total = 2.3
#'   Male = 2.1
#'   Female = 2.5
#' 
#' Row 3:
#'   RowLabel = "Brand A - % Top 3"
#'   RowType = "Column %"
#'   Total = 65.0
#'   Male = 70.0
#'   Female = 60.0
#' ```
#'
#' @section Error Handling:
#' If calculation fails for a banner column:
#' - Logs warning with details
#' - Sets value to NA for that column
#' - Continues processing other columns
#'
#' @section Format Output Integration:
#' Uses simple rounding for output formatting.
#' When Phase 1 is integrated, can optionally use format_output_value()
#' for enhanced formatting.
#'
#' @examples
#' # Simplified example
#' matrix <- matrix(c(1, 2, 3,
#'                    2, 1, 3,
#'                    1, 3, 2),
#'                  nrow = 3, byrow = TRUE,
#'                  dimnames = list(NULL, c("A", "B", "C")))
#' 
#' # Banner data: Total, Group1, Group2
#' banner_data <- list(
#'   Total = data.frame(.original_row = 1:3),
#'   Group1 = data.frame(.original_row = 1:2),
#'   Group2 = data.frame(.original_row = 3)
#' )
#' 
#' result <- create_ranking_rows_for_item(
#'   ranking_matrix = matrix,
#'   item_name = "A",
#'   banner_data_list = banner_data,
#'   banner_info = NULL,
#'   internal_keys = c("Total", "Group1", "Group2"),
#'   weights_list = NULL,
#'   show_top_n = TRUE,
#'   top_n = 3,
#'   num_positions = 3
#' )
#' # Returns 3 data frames (% first, mean rank, % top 3)
#'
#' @export
#' @family ranking
create_ranking_rows_for_item <- function(ranking_matrix, item_name, 
                                        banner_data_list, banner_info, 
                                        internal_keys, weights_list,
                                        show_top_n = TRUE, top_n = 3,
                                        num_positions = NULL,
                                        decimal_places_percent = 0,
                                        decimal_places_index = 1,
                                        add_legend = TRUE) {
  
  # ==============================================================================
  # INPUT VALIDATION
  # ==============================================================================
  
  if (!is.matrix(ranking_matrix) && !is.data.frame(ranking_matrix)) {
    stop(
      "ranking_matrix must be a matrix or data.frame",
      call. = FALSE
    )
  }
  
  if (!is.character(item_name) || length(item_name) != 1) {
    stop(
      "item_name must be a single character string",
      call. = FALSE
    )
  }
  
  if (!is.list(banner_data_list)) {
    stop(
      "banner_data_list must be a list of data frame subsets",
      call. = FALSE
    )
  }
  
  if (!is.character(internal_keys)) {
    stop(
      "internal_keys must be a character vector",
      call. = FALSE
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
  
  # ==============================================================================
  # CREATE ROW TEMPLATES
  # ==============================================================================
  
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
  
  # ==============================================================================
  # CALCULATE FOR EACH BANNER COLUMN
  # ==============================================================================
  
  for (key in internal_keys) {
    subset_data <- banner_data_list[[key]]
    
    # Check if subset has data
    if (is.null(subset_data) || !is.data.frame(subset_data) || nrow(subset_data) == 0) {
      pct_first_row[[key]] <- NA
      mean_rank_row[[key]] <- NA
      if (show_top_n) top_n_row[[key]] <- NA
      next
    }
    
    # Get subset row indices
    if (".original_row" %in% names(subset_data)) {
      subset_idx <- subset_data$.original_row
    } else {
      # Fallback: assume sequential rows
      subset_idx <- seq_len(nrow(subset_data))
    }
    
    # Validate indices are within ranking_matrix bounds
    if (any(subset_idx < 1 | subset_idx > nrow(ranking_matrix))) {
      warning(sprintf(
        "Invalid row indices for banner column '%s', skipping",
        key
      ), call. = FALSE)
      pct_first_row[[key]] <- NA
      mean_rank_row[[key]] <- NA
      if (show_top_n) top_n_row[[key]] <- NA
      next
    }
    
    # Extract subset of ranking matrix
    subset_matrix <- ranking_matrix[subset_idx, , drop = FALSE]
    
    # Get weights for this subset
    subset_weights <- if (!is.null(weights_list) && key %in% names(weights_list)) {
      weights_list[[key]]
    } else {
      rep(1, length(subset_idx))
    }
    
    # Validate weights length matches subset
    if (length(subset_weights) != length(subset_idx)) {
      warning(sprintf(
        "Weight length mismatch for banner column '%s', using unweighted",
        key
      ), call. = FALSE)
      subset_weights <- rep(1, length(subset_idx))
    }
    
    # ==============================================================================
    # CALCULATE METRICS
    # ==============================================================================
    
    tryCatch({
      
      # METRIC 1: % Ranked 1st
      first_result <- calculate_percent_ranked_first(
        subset_matrix, 
        item_name, 
        subset_weights
      )
      
      # CORRECTED: Simple rounding (no format_output_value dependency)
      pct_first_row[[key]] <- if (is.na(first_result$percentage)) {
        NA
      } else {
        round(first_result$percentage, decimal_places_percent)
      }
      
      # METRIC 2: Mean Rank
      mean_rank <- calculate_mean_rank(
        subset_matrix, 
        item_name, 
        subset_weights
      )
      
      # CORRECTED: Simple rounding (no format_output_value dependency)
      mean_rank_row[[key]] <- if (is.na(mean_rank)) {
        NA
      } else {
        round(mean_rank, decimal_places_index)
      }
      
      # METRIC 3: % Top N (optional)
      if (show_top_n) {
        top_n_result <- calculate_percent_top_n(
          subset_matrix, 
          item_name, 
          top_n, 
          num_positions = num_positions,  # V9.9.2: Pass for validation
          weights = subset_weights
        )
        
        # CORRECTED: Simple rounding (no format_output_value dependency)
        top_n_row[[key]] <- if (is.na(top_n_result$percentage)) {
          NA
        } else {
          round(top_n_result$percentage, decimal_places_percent)
        }
      }
      
    }, error = function(e) {
      # Log error but continue processing other columns
      warning(sprintf(
        "Error calculating ranking metrics for banner column '%s': %s",
        key,
        conditionMessage(e)
      ), call. = FALSE)
      pct_first_row[[key]] <- NA
      mean_rank_row[[key]] <- NA
      if (show_top_n) top_n_row[[key]] <- NA
    })
  }
  
  # ==============================================================================
  # RETURN RESULTS
  # ==============================================================================
  
  results[[1]] <- pct_first_row
  results[[2]] <- mean_rank_row
  
  if (show_top_n) {
    results[[3]] <- top_n_row
  }
  
  return(results)
}


# ==============================================================================
# MODULE METADATA
# ==============================================================================

# Module: output.R
# Phase: 6 (Ranking)
# Status: Complete (CORRECTED)
# Dependencies: calculations.R (Module 4)
# Functions: 1 (create_ranking_rows_for_item)
# Lines: ~480 (full documentation + fix)
# Fix: Simplified format_output_value fallback (no Phase 1 dependency)
#
# CORRECTED SECTIONS:
# - Line ~238: % Ranked 1st formatting (simple round)
# - Line ~251: Mean Rank formatting (simple round)
# - Line ~267: % Top N formatting (simple round)
#
# All functionality preserved, dependency removed

# ==============================================================================
