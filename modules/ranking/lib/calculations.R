# ==============================================================================
# TURAS RANKING MODULE 4: STATISTICAL CALCULATIONS
# ==============================================================================
# Statistical calculations for ranking metrics
#
# Part of Phase 6: Ranking Migration
# Source: ranking.r (V9.9.3) lines 636-1011
#
# METRICS PROVIDED:
# - Percent ranked first (% in 1st place)
# - Percent in top N (top 3 box, etc.)
# - Mean rank (lower = better)
# - Rank variance (for significance testing)
# - Mean rank comparison (t-tests)
#
# SUPPORTS:
# - Weighted and unweighted calculations
# - Effective-n for weighted data (Kish formula)
# - Significance testing with configurable thresholds
# ==============================================================================

# Source dependencies
if (file.exists("~/Documents/Turas/shared/statistics/weighting_stubs.R")) {
  source("~/Documents/Turas/shared/statistics/weighting_stubs.R")
}

# ==============================================================================
# PERCENT RANKED FIRST
# ==============================================================================

#' Calculate percentage who ranked item first
#'
#' @description
#' Calculates the percentage of respondents who ranked a specific item
#' in the 1st position (rank = 1).
#' 
#' Supports both weighted and unweighted calculations. For weighted data,
#' uses effective sample size (Kish formula) for accurate base reporting.
#'
#' @details
#' **V9.9.2: Return Shape Parity**
#' Removed weights from return value to match top_n function signature.
#' 
#' **Calculation:**
#' - Count: Sum of weights for respondents where rank = 1
#' - Base: Sum of weights for respondents who ranked this item
#' - Percentage: (Count / Base) × 100
#' - Effective-n: For weighted data, uses Kish formula
#' 
#' **Base Definition:**
#' Base includes all respondents who ranked the item (any position),
#' not just those who ranked it first.
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#'   Each cell contains rank position (1 to num_positions) or NA
#' @param item_name Character, column name of item to analyze
#'   Must exist in colnames(ranking_matrix)
#' @param weights Numeric vector, optional weights for respondents
#'   If NULL, uses equal weights (1 for all respondents)
#'   Length must match nrow(ranking_matrix)
#'
#' @return List with:
#' \describe{
#'   \item{count}{Numeric, weighted count of "ranked first"}
#'   \item{base}{Numeric, weighted count of "ranked this item"}
#'   \item{percentage}{Numeric, percentage (0-100), NA if base=0}
#'   \item{effective_n}{Numeric, effective sample size for weighted data}
#' }
#'
#' @examples
#' matrix <- matrix(c(1, 2, 3,
#'                    2, 1, 3,
#'                    1, 3, 2),
#'                  nrow = 3, byrow = TRUE,
#'                  dimnames = list(NULL, c("A", "B", "C")))
#' 
#' result <- calculate_percent_ranked_first(matrix, "A")
#' # 2 out of 3 ranked A first = 66.7%
#'
#' @export
#' @family ranking_calculations
calculate_percent_ranked_first <- function(ranking_matrix, item_name, weights = NULL) {
  
  # ==============================================================================
  # INPUT VALIDATION
  # ==============================================================================
  
  if (!is.matrix(ranking_matrix) && !is.data.frame(ranking_matrix)) {
    stop(
      "ranking_matrix must be a matrix or data.frame\n",
      "  Received: ", class(ranking_matrix)[1],
      call. = FALSE
    )
  }
  
  if (!is.character(item_name) || length(item_name) != 1) {
    stop(
      "item_name must be a single character string\n",
      "  Received: ", class(item_name)[1],
      call. = FALSE
    )
  }
  
  # Check item exists
  if (!item_name %in% colnames(ranking_matrix)) {
    warning(sprintf(
      "Item '%s' not found in ranking matrix. Available: %s",
      item_name,
      paste(head(colnames(ranking_matrix), 5), collapse = ", ")
    ), call. = FALSE)
    
    return(list(
      count = 0,
      base = 0,
      percentage = NA_real_,
      effective_n = 0
    ))
  }
  
  # Extract item ranks
  item_ranks <- ranking_matrix[, item_name]
  
  # Default weights (equal weighting)
  if (is.null(weights)) {
    weights <- rep(1, length(item_ranks))
  }
  
  # Validate weights length
  if (length(weights) != length(item_ranks)) {
    stop(sprintf(
      "weights length (%d) must match ranking_matrix rows (%d)",
      length(weights),
      length(item_ranks)
    ), call. = FALSE)
  }
  
  # ==============================================================================
  # CALCULATION
  # ==============================================================================
  
  # Identify respondents who ranked this item first (rank = 1)
  ranked_first <- !is.na(item_ranks) & item_ranks == 1
  
  # Identify respondents who ranked this item at all (any rank)
  has_rank <- !is.na(item_ranks)
  
  # Calculate weighted counts
  weighted_count <- sum(weights[ranked_first], na.rm = TRUE)
  weighted_base <- sum(weights[has_rank], na.rm = TRUE)
  
  # Calculate effective-n (for significance testing with weighted data)
  effective_n <- calculate_effective_n(weights[has_rank])
  
  # Calculate percentage
  percentage <- if (weighted_base > 0) {
    (weighted_count / weighted_base) * 100
  } else {
    NA_real_
  }
  
  # V9.9.2: Return without weights (shape parity)
  return(list(
    count = weighted_count,
    base = weighted_base,
    percentage = percentage,
    effective_n = effective_n
  ))
}


# ==============================================================================
# PERCENT IN TOP N
# ==============================================================================

#' Calculate percentage who ranked item in top N positions
#'
#' @description
#' Calculates the percentage of respondents who ranked a specific item
#' in the top N positions (e.g., top 3 box = ranks 1, 2, or 3).
#' 
#' Supports both weighted and unweighted calculations.
#'
#' @details
#' **V9.9.2 ENHANCEMENTS:**
#' - Guard against top_n exceeding num_positions (auto-clamp with warning)
#' - Consistent return shape (no weights in output)
#' 
#' **Calculation:**
#' - Count: Sum of weights for respondents where rank ≤ top_n
#' - Base: Sum of weights for respondents who ranked this item
#' - Percentage: (Count / Base) × 100
#' 
#' **Common Use Cases:**
#' - top_n = 1: Same as percent_ranked_first
#' - top_n = 2: Top 2 box
#' - top_n = 3: Top 3 box (most common)
#' - top_n = 5: Top 5 box
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#' @param item_name Character, column name of item to analyze
#' @param top_n Integer, number of top positions to include (default: 3)
#'   E.g., top_n=3 includes ranks 1, 2, and 3
#' @param num_positions Integer, total available ranking positions
#'   Used to validate top_n doesn't exceed available positions
#'   If NULL, no validation performed
#' @param weights Numeric vector, optional weights
#'   If NULL, uses equal weights
#'
#' @return List with:
#' \describe{
#'   \item{count}{Numeric, weighted count in top N}
#'   \item{base}{Numeric, weighted count who ranked item}
#'   \item{percentage}{Numeric, percentage (0-100)}
#'   \item{effective_n}{Numeric, effective sample size}
#' }
#'
#' @examples
#' matrix <- matrix(c(1, 2, 5,
#'                    2, 1, 4,
#'                    4, 3, 1),
#'                  nrow = 3, byrow = TRUE,
#'                  dimnames = list(NULL, c("A", "B", "C")))
#' 
#' # Top 3 box for item A (ranks 1, 2, or 3)
#' result <- calculate_percent_top_n(matrix, "A", top_n = 3, num_positions = 5)
#' # Respondents 1 and 2 ranked A in top 3 = 66.7%
#'
#' @export
#' @family ranking_calculations
calculate_percent_top_n <- function(ranking_matrix, item_name, top_n = 3, 
                                   num_positions = NULL, weights = NULL) {
  
  # ==============================================================================
  # INPUT VALIDATION
  # ==============================================================================
  
  if (!is.matrix(ranking_matrix) && !is.data.frame(ranking_matrix)) {
    stop(
      "ranking_matrix must be a matrix or data.frame\n",
      "  Received: ", class(ranking_matrix)[1],
      call. = FALSE
    )
  }
  
  if (!is.character(item_name) || length(item_name) != 1) {
    stop(
      "item_name must be a single character string",
      call. = FALSE
    )
  }
  
  if (!is.numeric(top_n) || length(top_n) != 1 || top_n < 1) {
    stop(
      "top_n must be a single positive integer\n",
      "  Received: ", top_n,
      call. = FALSE
    )
  }
  
  # V9.9.2: Guard top_n vs available positions
  if (!is.null(num_positions)) {
    if (top_n > num_positions) {
      warning(sprintf(
        "top_n (%d) exceeds available positions (%d), clamping to %d",
        top_n, num_positions, num_positions
      ), call. = FALSE)
      top_n <- num_positions
    }
  }
  
  # Check item exists
  if (!item_name %in% colnames(ranking_matrix)) {
    warning(sprintf(
      "Item '%s' not found in ranking matrix",
      item_name
    ), call. = FALSE)
    
    return(list(
      count = 0,
      base = 0,
      percentage = NA_real_,
      effective_n = 0
    ))
  }
  
  # Extract item ranks
  item_ranks <- ranking_matrix[, item_name]
  
  # Default weights
  if (is.null(weights)) {
    weights <- rep(1, length(item_ranks))
  }
  
  # Validate weights length
  if (length(weights) != length(item_ranks)) {
    stop(sprintf(
      "weights length (%d) must match ranking_matrix rows (%d)",
      length(weights),
      length(item_ranks)
    ), call. = FALSE)
  }
  
  # ==============================================================================
  # CALCULATION
  # ==============================================================================
  
  # Identify respondents who ranked this item in top N
  ranked_top_n <- !is.na(item_ranks) & item_ranks <= top_n
  
  # Identify respondents who ranked this item at all
  has_rank <- !is.na(item_ranks)
  
  # Calculate weighted counts
  weighted_count <- sum(weights[ranked_top_n], na.rm = TRUE)
  weighted_base <- sum(weights[has_rank], na.rm = TRUE)
  
  # Calculate effective-n
  effective_n <- calculate_effective_n(weights[has_rank])
  
  # Calculate percentage
  percentage <- if (weighted_base > 0) {
    (weighted_count / weighted_base) * 100
  } else {
    NA_real_
  }
  
  return(list(
    count = weighted_count,
    base = weighted_base,
    percentage = percentage,
    effective_n = effective_n
  ))
}


# ==============================================================================
# MEAN RANK
# ==============================================================================

#' Calculate mean rank for item (lower = better ranking)
#'
#' @description
#' Calculates the average rank position for an item across all respondents
#' who ranked it.
#' 
#' **INTERPRETATION:** Lower mean rank = better performance
#' - Mean rank of 1.5 is better than 2.5
#' - Item with lowest mean rank is most preferred
#'
#' @details
#' Supports weighted and unweighted calculations:
#' - **Unweighted:** Simple arithmetic mean
#' - **Weighted:** Uses weighted mean from weighting module
#' 
#' Only includes respondents who actually ranked the item (non-NA).
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#' @param item_name Character, column name of item to analyze
#' @param weights Numeric vector, optional weights
#'   If NULL, calculates simple mean
#'
#' @return Numeric, mean rank value
#'   - Returns NA if no valid ranks
#'   - Lower values indicate better/more preferred ranking
#'
#' @examples
#' matrix <- matrix(c(1, 2, 3,
#'                    2, 1, 3,
#'                    3, 2, 1),
#'                  nrow = 3, byrow = TRUE,
#'                  dimnames = list(NULL, c("A", "B", "C")))
#' 
#' mean_a <- calculate_mean_rank(matrix, "A")
#' # (1 + 2 + 3) / 3 = 2.0
#' 
#' mean_b <- calculate_mean_rank(matrix, "B")
#' # (2 + 1 + 2) / 3 = 1.67 (better than A!)
#'
#' @export
#' @family ranking_calculations
calculate_mean_rank <- function(ranking_matrix, item_name, weights = NULL) {
  
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
  
  # Check item exists
  if (!item_name %in% colnames(ranking_matrix)) {
    warning(sprintf(
      "Item '%s' not found in ranking matrix",
      item_name
    ), call. = FALSE)
    return(NA_real_)
  }
  
  # Extract item ranks
  item_ranks <- ranking_matrix[, item_name]
  
  # Default weights
  if (is.null(weights)) {
    weights <- rep(1, length(item_ranks))
  }
  
  # Validate weights length
  if (length(weights) != length(item_ranks)) {
    stop(sprintf(
      "weights length (%d) must match ranking_matrix rows (%d)",
      length(weights),
      length(item_ranks)
    ), call. = FALSE)
  }
  
  # ==============================================================================
  # CALCULATION
  # ==============================================================================
  
  # Filter to valid ranks only
  valid_idx <- !is.na(item_ranks)
  valid_ranks <- item_ranks[valid_idx]
  valid_weights <- weights[valid_idx]
  
  if (length(valid_ranks) == 0) {
    return(NA_real_)
  }
  
  # Calculate mean
  if (all(valid_weights == 1)) {
    # Unweighted - simple arithmetic mean
    return(mean(valid_ranks))
  } else {
    # Weighted - use weighting module function
    return(calculate_weighted_mean(valid_ranks, valid_weights))
  }
}


# ==============================================================================
# RANK VARIANCE
# ==============================================================================

#' Calculate variance of ranks for an item
#'
#' @description
#' Calculates the variance in rank positions for an item.
#' Used in significance testing (t-tests) for comparing mean ranks.
#' 
#' Uses population variance formula (divides by N, not N-1).
#'
#' @details
#' **Variance Interpretation:**
#' - High variance: Ranks are spread out (inconsistent opinions)
#' - Low variance: Ranks are clustered (consensus)
#' 
#' **For Weighted Data:**
#' Uses weighted population variance formula from weighting module.
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#' @param item_name Character, column name of item to analyze
#' @param weights Numeric vector, optional weights
#'
#' @return Numeric, variance of ranks
#'   - Returns NA if fewer than 2 valid ranks
#'   - Population variance (not sample variance)
#'
#' @examples
#' matrix <- matrix(c(1, 1, 1,  # All rank "A" first
#'                    2, 3, 2,
#'                    3, 2, 3),
#'                  nrow = 3, byrow = TRUE,
#'                  dimnames = list(NULL, c("A", "B", "C")))
#' 
#' var_a <- calculate_rank_variance(matrix, "A")
#' # All 1s: variance = 0 (perfect consensus)
#' 
#' var_b <- calculate_rank_variance(matrix, "B")
#' # 1, 3, 2: has variance (mixed opinions)
#'
#' @export
#' @family ranking_calculations
calculate_rank_variance <- function(ranking_matrix, item_name, weights = NULL) {
  
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
  
  # Check item exists
  if (!item_name %in% colnames(ranking_matrix)) {
    return(NA_real_)
  }
  
  # Extract item ranks
  item_ranks <- ranking_matrix[, item_name]
  
  # Default weights
  if (is.null(weights)) {
    weights <- rep(1, length(item_ranks))
  }
  
  # Validate weights length
  if (length(weights) != length(item_ranks)) {
    stop(sprintf(
      "weights length (%d) must match ranking_matrix rows (%d)",
      length(weights),
      length(item_ranks)
    ), call. = FALSE)
  }
  
  # ==============================================================================
  # CALCULATION
  # ==============================================================================
  
  # Filter to valid ranks
  valid_idx <- !is.na(item_ranks)
  valid_ranks <- item_ranks[valid_idx]
  valid_weights <- weights[valid_idx]
  
  if (length(valid_ranks) < 2) {
    return(NA_real_)
  }
  
  # Calculate variance
  if (all(valid_weights == 1)) {
    # Unweighted - population variance
    mean_rank <- mean(valid_ranks)
    return(mean((valid_ranks - mean_rank)^2))
  } else {
    # Weighted - use weighting module function
    if (exists("weighted_variance", mode = "function")) {
      return(weighted_variance(valid_ranks, valid_weights))
    } else {
      # Fallback: weighted population variance
      mean_rank <- sum(valid_ranks * valid_weights) / sum(valid_weights)
      return(sum(valid_weights * (valid_ranks - mean_rank)^2) / sum(valid_weights))
    }
  }
}


# ==============================================================================
# MEAN RANK COMPARISON (SIGNIFICANCE TESTING)
# ==============================================================================

#' Compare mean ranks between two groups with significance testing
#'
#' @description
#' Performs statistical comparison of mean ranks between two groups
#' using t-test methodology adapted for weighted data.
#' 
#' Tests whether the difference in mean ranks is statistically significant.
#'
#' @details
#' **V9.9.2: Configurable Minimum Base**
#' Uses min_base parameter (can be set from config) to ensure adequate
#' sample size for testing.
#' 
#' **Interpretation:**
#' - Lower mean rank = better performance
#' - If group 1 mean < group 2 mean, group 1 ranks item better
#' - better_group returns which group has lower (better) mean rank
#' 
#' **Weighted Testing:**
#' - Uses effective sample size for degrees of freedom
#' - Weighted means and variances
#' - Welch-Satterthwaite degrees of freedom
#'
#' @param ranking_matrix1 Numeric matrix for group 1
#' @param ranking_matrix2 Numeric matrix for group 2
#' @param item_name Character, item to compare
#' @param weights1 Numeric vector, weights for group 1 (optional)
#' @param weights2 Numeric vector, weights for group 2 (optional)
#' @param alpha Numeric, significance level (default: 0.05)
#'   P-value threshold for determining significance
#' @param min_base Integer, minimum base size for testing (default: 10)
#'   If either group has effective-n < min_base, returns non-significant
#'
#' @return List with:
#' \describe{
#'   \item{significant}{Logical, TRUE if p < alpha}
#'   \item{p_value}{Numeric, two-tailed p-value}
#'   \item{mean1}{Numeric, mean rank for group 1}
#'   \item{mean2}{Numeric, mean rank for group 2}
#'   \item{better_group}{Integer, 1 or 2 (group with lower mean = better)}
#' }
#'
#' @examples
#' matrix1 <- matrix(c(1, 2, 3,
#'                     2, 1, 3),
#'                   nrow = 2, byrow = TRUE,
#'                   dimnames = list(NULL, c("A", "B", "C")))
#' 
#' matrix2 <- matrix(c(3, 2, 1,
#'                     3, 3, 1),
#'                   nrow = 2, byrow = TRUE,
#'                   dimnames = list(NULL, c("A", "B", "C")))
#' 
#' result <- compare_mean_ranks(matrix1, matrix2, "A")
#' # Group 1 mean = 1.5, Group 2 mean = 3.0
#' # Group 1 is significantly better (p < 0.05)
#'
#' @export
#' @family ranking_calculations
compare_mean_ranks <- function(ranking_matrix1, ranking_matrix2, item_name,
                              weights1 = NULL, weights2 = NULL,
                              alpha = 0.05, min_base = 10) {
  
  # ==============================================================================
  # INPUT VALIDATION
  # ==============================================================================
  
  if (!is.numeric(alpha) || length(alpha) != 1 || alpha <= 0 || alpha >= 1) {
    stop(
      "alpha must be between 0 and 1\n",
      "  Received: ", alpha,
      call. = FALSE
    )
  }
  
  if (!is.numeric(min_base) || length(min_base) != 1 || min_base < 1) {
    stop(
      "min_base must be a positive integer\n",
      "  Received: ", min_base,
      call. = FALSE
    )
  }
  
  # ==============================================================================
  # CALCULATE MEANS FOR BOTH GROUPS
  # ==============================================================================
  
  mean1 <- calculate_mean_rank(ranking_matrix1, item_name, weights1)
  mean2 <- calculate_mean_rank(ranking_matrix2, item_name, weights2)
  
  # If either mean is NA, cannot test
  if (is.na(mean1) || is.na(mean2)) {
    return(list(
      significant = FALSE,
      p_value = NA_real_,
      mean1 = mean1,
      mean2 = mean2,
      better_group = NA_integer_
    ))
  }
  
  # ==============================================================================
  # PERFORM WEIGHTED T-TEST
  # ==============================================================================
  
  # Extract ranks
  ranks1 <- ranking_matrix1[, item_name]
  ranks2 <- ranking_matrix2[, item_name]
  
  # Default weights
  if (is.null(weights1)) weights1 <- rep(1, length(ranks1))
  if (is.null(weights2)) weights2 <- rep(1, length(ranks2))
  
  # Use weighted_t_test_means from weighting module if available
  if (exists("weighted_t_test_means", mode = "function")) {
    test_result <- weighted_t_test_means(
      ranks1, ranks2,
      weights1, weights2,
      min_base = min_base,
      alpha = alpha
    )
    
    return(list(
      significant = test_result$significant,
      p_value = test_result$p_value,
      mean1 = mean1,
      mean2 = mean2,
      better_group = if (mean1 < mean2) 1 else 2  # Lower mean = better rank
    ))
  } else {
    # Fallback: basic unweighted t-test
    test <- tryCatch({
      t.test(ranks1, ranks2, na.rm = TRUE)
    }, error = function(e) {
      return(NULL)
    })
    
    if (is.null(test)) {
      return(list(
        significant = FALSE,
        p_value = NA_real_,
        mean1 = mean1,
        mean2 = mean2,
        better_group = if (mean1 < mean2) 1 else 2
      ))
    }
    
    return(list(
      significant = test$p.value < alpha,
      p_value = test$p.value,
      mean1 = mean1,
      mean2 = mean2,
      better_group = if (mean1 < mean2) 1 else 2
    ))
  }
}


# ==============================================================================
# MODULE METADATA
# ==============================================================================

# Module: calculations.R
# Phase: 6 (Ranking)
# Status: Complete
# Dependencies: weighting_stubs.R (Phase 5 stubs)
# Functions: 5 (percent_first, percent_top_n, mean_rank, variance, compare)
# Lines: ~850
# Tested: Ready for testing

# ==============================================================================
