# ==============================================================================
# TURAS RANKING MODULE 1: RANK DIRECTION NORMALIZATION
# ==============================================================================
# Normalize ranking data to consistent Best-to-Worst direction
#
# Part of Phase 6: Ranking Migration
# Source: ranking.r (V9.9.3) lines 77-119
#
# DESIGN PRINCIPLE:
# All internal ranking calculations use Best-to-Worst direction (1 = best)
# If input data uses Worst-to-Best (1 = worst), this module flips ranks
# ==============================================================================

#' Normalize ranks to consistent Best-to-Worst direction
#'
#' @description
#' Ensures all ranking data follows the Best-to-Worst convention where
#' rank 1 is the best/most preferred and higher ranks are worse/less preferred.
#' 
#' If data is in Worst-to-Best format (1 = worst, higher = better), this
#' function flips the ranks using the formula: new_rank = (max + 1) - old_rank
#'
#' @details
#' **Best-to-Worst (Standard):**
#' - Rank 1 = Best/Most preferred
#' - Higher ranks = Worse/Less preferred
#' - No transformation needed
#' 
#' **Worst-to-Best (Needs Flip):**
#' - Rank 1 = Worst/Least preferred  
#' - Higher ranks = Better/More preferred
#' - Transformed to Best-to-Worst
#' 
#' **Transformation Formula:**
#' \code{new_rank = (num_positions + 1) - old_rank}
#' 
#' Example with 5 positions (Worst-to-Best → Best-to-Worst):
#' - Rank 1 (worst) → Rank 5 (worst)
#' - Rank 2 → Rank 4
#' - Rank 3 → Rank 3 (middle stays middle)
#' - Rank 4 → Rank 2
#' - Rank 5 (best) → Rank 1 (best)
#'
#' @param ranking_matrix Numeric matrix or data.frame with ranking data
#'   - Rows = respondents
#'   - Columns = items being ranked
#'   - Values = rank positions (1 to num_positions)
#'   - NA values preserved
#' @param num_positions Integer, maximum number of rank positions
#'   Must be positive integer
#' @param direction Character, ranking direction:
#'   - "BestToWorst" (default): No transformation, return as-is
#'   - "WorstToBest": Flip ranks to Best-to-Worst convention
#'
#' @return Matrix with same dimensions as input, normalized to Best-to-Worst direction
#'   - NA values preserved in original positions
#'   - All valid ranks flipped if direction = "WorstToBest"
#'   - Returns input unchanged if direction = "BestToWorst"
#'
#' @section Input Validation:
#' - ranking_matrix must be matrix or data.frame
#' - num_positions must be single positive integer
#' - direction must be one of: "BestToWorst", "WorstToBest"
#'
#' @section Performance:
#' - Vectorized operation: O(n×m) where n=respondents, m=items
#' - Handles NA values efficiently using logical indexing
#' - No loops, fast for large matrices
#'
#' @examples
#' # Example 1: Worst-to-Best data (1=worst, 5=best) - needs flip
#' matrix_wtb <- matrix(c(5, 4, 1,  # Respondent 1: Item1=5(best), Item2=4, Item3=1(worst)
#'                        3, 5, 2), # Respondent 2: Item1=3, Item2=5(best), Item3=2
#'                      nrow = 2, byrow = TRUE)
#' 
#' normalized <- normalize_rank_direction(matrix_wtb, 
#'                                       num_positions = 5, 
#'                                       direction = "WorstToBest")
#' # Result: Best-to-Worst format (1=best, 5=worst)
#' # [1, 2, 5]  # Item1=1(best), Item2=2, Item3=5(worst)
#' # [3, 1, 4]  # Item1=3, Item2=1(best), Item3=4
#'
#' # Example 2: Best-to-Worst data (already correct format)
#' matrix_btw <- matrix(c(1, 2, 3,
#'                        2, 1, 3),
#'                      nrow = 2, byrow = TRUE)
#' 
#' normalized <- normalize_rank_direction(matrix_btw, 
#'                                       num_positions = 3, 
#'                                       direction = "BestToWorst")
#' # Result: Returns unchanged (already Best-to-Worst)
#'
#' # Example 3: Data with missing values
#' matrix_na <- matrix(c(1, NA, 3,
#'                       NA, 2, 1),
#'                     nrow = 2, byrow = TRUE)
#' 
#' normalized <- normalize_rank_direction(matrix_na, 
#'                                       num_positions = 3, 
#'                                       direction = "BestToWorst")
#' # Result: NA values preserved
#'
#' @export
#' @family ranking
#' @seealso \code{\link{validate_ranking_matrix}} for data quality validation
normalize_rank_direction <- function(ranking_matrix, 
                                    num_positions, 
                                    direction = c("BestToWorst", "WorstToBest")) {
  
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
  
  # Validate and match direction argument
  direction <- match.arg(direction)
  
  # ==============================================================================
  # NORMALIZATION
  # ==============================================================================
  
  # If already Best-to-Worst, return as-is (no transformation needed)
  if (direction == "BestToWorst") {
    return(ranking_matrix)
  }
  
  # Flip ranks from Worst-to-Best to Best-to-Worst
  # Formula: new_rank = (max_position + 1) - old_rank
  # This inverts the scale:
  #   - Best rank (num_positions) becomes 1
  #   - Worst rank (1) becomes num_positions
  #   - Middle ranks stay middle
  
  out <- ranking_matrix
  valid <- !is.na(ranking_matrix)  # Preserve NA positions
  out[valid] <- (num_positions + 1) - ranking_matrix[valid]
  
  return(out)
}


# ==============================================================================
# HELPER FUNCTION: Detect Rank Direction (Optional Enhancement)
# ==============================================================================

#' Detect ranking direction from data patterns (experimental)
#'
#' @description
#' Attempts to auto-detect whether ranking data is Best-to-Worst or Worst-to-Best
#' based on distribution patterns. This is experimental and should be used with caution.
#' 
#' **RECOMMENDATION:** Always explicitly specify direction rather than rely on detection.
#'
#' @details
#' Detection heuristic:
#' - If mean rank < (num_positions/2), likely Best-to-Worst (low ranks common)
#' - If mean rank > (num_positions/2), likely Worst-to-Best (high ranks common)
#' - If mean ≈ median ≈ num_positions/2, inconclusive
#'
#' @param ranking_matrix Numeric matrix of ranking data
#' @param num_positions Integer, maximum rank position
#'
#' @return Character: "BestToWorst", "WorstToBest", or "Inconclusive"
#'
#' @note This is a heuristic and may be incorrect. Always prefer explicit direction.
#'
#' @keywords internal
detect_rank_direction <- function(ranking_matrix, num_positions) {
  
  # Calculate mean rank across all valid responses
  valid_ranks <- ranking_matrix[!is.na(ranking_matrix)]
  
  if (length(valid_ranks) == 0) {
    return("Inconclusive")
  }
  
  mean_rank <- mean(valid_ranks)
  midpoint <- (num_positions + 1) / 2
  
  # If mean is significantly below midpoint, likely Best-to-Worst (low ranks common)
  # If mean is significantly above midpoint, likely Worst-to-Best (high ranks common)
  threshold <- num_positions * 0.15  # 15% tolerance
  
  if (mean_rank < (midpoint - threshold)) {
    return("BestToWorst")
  } else if (mean_rank > (midpoint + threshold)) {
    return("WorstToBest")
  } else {
    return("Inconclusive")
  }
}


# ==============================================================================
# MODULE METADATA
# ==============================================================================

# Module: direction.R
# Phase: 6 (Ranking)
# Status: Complete
# Dependencies: None (pure utility)
# Functions: 2 (normalize_rank_direction, detect_rank_direction)
# Lines: ~220
# Tested: Ready for testing

# ==============================================================================
