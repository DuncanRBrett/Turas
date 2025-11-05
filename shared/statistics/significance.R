# ==============================================================================
# TURAS: SIGNIFICANCE TESTING
# ==============================================================================
# Statistical significance testing for survey analytics
# Migrated from weighting.r V9.9.4 as part of Phase 5
#
# CONTENTS:
# 1. weighted_z_test_proportions() - Z-test for comparing proportions
# 2. weighted_t_test_means() - T-test for comparing means
# 3. chi_square_test() - Chi-square test for independence
# 4. run_net_difference_tests() - Net difference testing for rankings
#
# DEPENDENCIES:
# - Requires weighting.R for: calculate_effective_n(), weighted_variance(), calculate_weighted_mean()
#
# STATISTICAL METHODOLOGY:
# - Z-test: Uses pooled proportion, effective-n for weighted data
# - T-test: Uses Welch-Satterthwaite approximation, weighted variance
# - Chi-square: Standard Pearson chi-square with minimum expected frequency checks
# - Net differences: Specialized for ranking/rating questions
# ==============================================================================

# ==============================================================================
# 1. Z-TEST FOR PROPORTIONS
# ==============================================================================

#' Z-test for difference in proportions (weighted or unweighted)
#'
#' Tests whether two proportions are significantly different using a
#' two-tailed z-test.
#'
#' METHODOLOGY:
#' - Uses pooled proportion: p_pooled = (count1 + count2) / (base1 + base2)
#' - Standard error: SE = sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))
#' - For weighted data: Uses effective-n instead of actual base
#' - Two-tailed test: p-value = 2 * P(Z > |z|)
#'
#' WEIGHTED DATA:
#' - Set is_weighted = TRUE
#' - Provide eff_n1 and eff_n2 (from calculate_effective_n())
#' - Counts should be weighted counts
#' - Bases should be weighted bases
#'
#' EDGE CASES:
#' - Returns non-significant if base < min_base
#' - Returns non-significant if pooled proportion is 0 or 1
#' - Validates that count <= base
#'
#' @param count1 Numeric, count for group 1 (weighted if is_weighted=TRUE)
#' @param base1 Numeric, base for group 1 (weighted if is_weighted=TRUE)
#' @param count2 Numeric, count for group 2 (weighted if is_weighted=TRUE)
#' @param base2 Numeric, base for group 2 (weighted if is_weighted=TRUE)
#' @param eff_n1 Numeric, effective sample size for group 1 (required if is_weighted=TRUE)
#' @param eff_n2 Numeric, effective sample size for group 2 (required if is_weighted=TRUE)
#' @param is_weighted Logical, whether data is weighted (default: FALSE)
#' @param min_base Numeric, minimum base size for testing (default: 30)
#' @param alpha Numeric, significance level (default: 0.05)
#' @return List with $significant (logical), $p_value (numeric), $higher (logical indicating if group 1 > group 2)
#' @export
#' @examples
#' # Unweighted test
#' result <- weighted_z_test_proportions(
#'   count1 = 50, base1 = 100,
#'   count2 = 30, base2 = 100,
#'   is_weighted = FALSE
#' )
#' 
#' # Weighted test
#' result <- weighted_z_test_proportions(
#'   count1 = 52.3, base1 = 104.7,
#'   count2 = 31.8, base2 = 98.2,
#'   eff_n1 = 95, eff_n2 = 92,
#'   is_weighted = TRUE
#' )
weighted_z_test_proportions <- function(count1, base1, count2, base2, 
                                       eff_n1 = NULL, eff_n2 = NULL,
                                       is_weighted = FALSE,
                                       min_base = 30,
                                       alpha = 0.05) {
  # Parameter validation
  if (!is.numeric(alpha) || length(alpha) != 1 || alpha <= 0 || alpha >= 1) {
    stop("alpha must be a single numeric value between 0 and 1", call. = FALSE)
  }
  
  if (!is.numeric(min_base) || length(min_base) != 1 || min_base < 1) {
    stop("min_base must be a single numeric value >= 1", call. = FALSE)
  }
  
  # Validate inputs
  if (any(is.na(c(count1, base1, count2, base2)))) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }
  
  # Sanity check count/base relationship
  if (count1 < 0 || count2 < 0 || base1 < 0 || base2 < 0) {
    warning("Negative count or base values detected; skipping z-test.", call. = FALSE)
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }
  
  if (count1 > base1 || count2 > base2) {
    warning(sprintf(
      "Count exceeds base (count1=%.1f, base1=%.1f, count2=%.1f, base2=%.1f); skipping z-test.\nThis may indicate duplicated rows or upstream data errors.",
      count1, base1, count2, base2
    ), call. = FALSE)
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }
  
  # Explicit is_weighted flag
  if (is_weighted && (is.null(eff_n1) || is.null(eff_n2))) {
    warning(
      "Weighted data requires effective-n for valid significance testing. Test skipped.",
      call. = FALSE
    )
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }
  
  # Determine sample sizes to use
  n1 <- if (is_weighted && !is.null(eff_n1)) eff_n1 else base1
  n2 <- if (is_weighted && !is.null(eff_n2)) eff_n2 else base2
  
  # Check minimum base size
  if (n1 < min_base || n2 < min_base) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }
  
  # Check for zero bases
  if (base1 == 0 || base2 == 0) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }
  
  # Calculate proportions
  p1 <- count1 / base1
  p2 <- count2 / base2
  
  # Pooled proportion (uses design-weighted counts)
  p_pooled <- (count1 + count2) / (base1 + base2)
  
  # Edge cases: degenerate proportions
  if (p_pooled == 0 || p_pooled == 1) {
    # Both groups have 0% or 100% - no difference to test
    return(list(significant = FALSE, p_value = 1, higher = (p1 > p2)))
  }
  
  # Standard error (uses effective sample sizes)
  se <- sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))
  
  if (se == 0 || is.na(se)) {
    return(list(significant = FALSE, p_value = 1, higher = (p1 > p2)))
  }
  
  # Z-statistic and p-value
  z_stat <- (p1 - p2) / se
  p_value <- 2 * pnorm(-abs(z_stat))
  
  # Uses alpha comparison
  return(list(
    significant = (!is.na(p_value) && p_value < alpha),
    p_value = p_value,
    higher = (p1 > p2)
  ))
}

# ==============================================================================
# 2. T-TEST FOR MEANS
# ==============================================================================

#' T-test for weighted means
#'
#' Tests whether two means are significantly different using Welch's t-test
#' (unequal variances assumed). Works with both weighted and unweighted data.
#'
#' METHODOLOGY:
#' - Uses weighted_variance() for population variance
#' - Uses effective-n for degrees of freedom and SE
#' - Welch-Satterthwaite approximation for unequal variances:
#'   df = (s1²/n1 + s2²/n2)² / [(s1²/n1)²/(n1-1) + (s2²/n2)²/(n2-1)]
#'
#' IMPLEMENTATION:
#' - Computes effective-n internally on ANALYTIC SAMPLE (after filtering NAs)
#' - If weights are NULL, defaults to unit weights (unweighted test)
#' - Length mismatches cause immediate error (fail fast)
#'
#' EDGE CASES:
#' - Returns non-significant if effective-n < min_base in either group
#' - Returns non-significant if SE = 0 (no variance)
#' - Returns non-significant if df <= 0 (degenerate case)
#'
#' @param values1 Numeric vector, values for group 1
#' @param values2 Numeric vector, values for group 2
#' @param weights1 Numeric vector, weights for group 1 (NULL = unweighted)
#' @param weights2 Numeric vector, weights for group 2 (NULL = unweighted)
#' @param min_base Integer, minimum base size for testing (default: 30)
#' @param alpha Numeric, significance level (default: 0.05)
#' @return List with $significant (logical), $p_value (numeric), $higher (logical indicating if mean1 > mean2)
#' @export
#' @examples
#' # Unweighted test
#' values1 <- c(5, 6, 7, 5, 6)
#' values2 <- c(3, 4, 3, 5, 4)
#' result <- weighted_t_test_means(values1, values2)
#' 
#' # Weighted test
#' weights1 <- c(1.2, 0.8, 1.5, 1.0, 0.9)
#' weights2 <- c(1.1, 1.3, 0.9, 1.2, 1.0)
#' result <- weighted_t_test_means(values1, values2, weights1, weights2)
weighted_t_test_means <- function(values1, values2, 
                                 weights1 = NULL, weights2 = NULL,
                                 min_base = 30,
                                 alpha = 0.05) {
  # Parameter validation
  if (!is.numeric(alpha) || length(alpha) != 1 || alpha <= 0 || alpha >= 1) {
    stop("alpha must be a single numeric value between 0 and 1", call. = FALSE)
  }
  
  if (!is.numeric(min_base) || length(min_base) != 1 || min_base < 1) {
    stop("min_base must be a single numeric value >= 1", call. = FALSE)
  }
  
  # Default to unit weights if not provided
  if (is.null(weights1)) weights1 <- rep(1, length(values1))
  if (is.null(weights2)) weights2 <- rep(1, length(values2))
  
  # Validate lengths (fail fast)
  if (length(values1) != length(weights1)) {
    stop(sprintf(
      "values1 (%d) and weights1 (%d) have different lengths",
      length(values1),
      length(weights1)
    ), call. = FALSE)
  }
  
  if (length(values2) != length(weights2)) {
    stop(sprintf(
      "values2 (%d) and weights2 (%d) have different lengths",
      length(values2),
      length(weights2)
    ), call. = FALSE)
  }
  
  # Filter to analytic sample FIRST, then compute eff-n
  valid1 <- !is.na(values1) & !is.na(weights1) & is.finite(weights1) & weights1 > 0
  valid2 <- !is.na(values2) & !is.na(weights2) & is.finite(weights2) & weights2 > 0
  
  values1 <- values1[valid1]
  weights1 <- weights1[valid1]
  values2 <- values2[valid2]
  weights2 <- weights2[valid2]
  
  # Calculate effective sample sizes on ANALYTIC sample
  eff_n1 <- calculate_effective_n(weights1)
  eff_n2 <- calculate_effective_n(weights2)
  
  # Check minimum base size
  if (eff_n1 < min_base || eff_n2 < min_base) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }
  
  tryCatch({
    # Calculate weighted means
    mean1 <- calculate_weighted_mean(values1, weights1)
    mean2 <- calculate_weighted_mean(values2, weights2)
    
    if (is.na(mean1) || is.na(mean2)) {
      return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
    }
    
    # Calculate weighted variances
    var1 <- weighted_variance(values1, weights1)
    var2 <- weighted_variance(values2, weights2)
    
    # Standard error (uses effective sample sizes)
    se <- sqrt(var1/eff_n1 + var2/eff_n2)
    
    if (se == 0 || is.na(se)) {
      return(list(significant = FALSE, p_value = 1, higher = (mean1 > mean2)))
    }
    
    # T-statistic
    t_stat <- (mean1 - mean2) / se
    
    # Degrees of freedom (Welch-Satterthwaite approximation)
    df <- (var1/eff_n1 + var2/eff_n2)^2 / 
          ((var1/eff_n1)^2/(eff_n1-1) + (var2/eff_n2)^2/(eff_n2-1))
    
    if (is.na(df) || df <= 0) {
      return(list(significant = FALSE, p_value = NA_real_, higher = (mean1 > mean2)))
    }
    
    # P-value (two-tailed)
    p_value <- 2 * pt(-abs(t_stat), df = df)
    
    return(list(
      significant = (!is.na(p_value) && p_value < alpha),
      p_value = p_value,
      higher = (mean1 > mean2)
    ))
    
  }, error = function(e) {
    warning(sprintf("T-test failed: %s", e$message), call. = FALSE)
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  })
}

# ==============================================================================
# 3. CHI-SQUARE TEST FOR INDEPENDENCE
# ==============================================================================

#' Chi-square test for independence in contingency tables
#'
#' Tests whether rows and columns in a contingency table are independent
#' using Pearson's chi-square test.
#'
#' METHODOLOGY:
#' - Standard Pearson chi-square: χ² = Σ((O - E)² / E)
#' - Degrees of freedom: df = (rows - 1) * (cols - 1)
#' - Checks minimum expected frequency requirement
#'
#' EXPECTED FREQUENCY CHECK:
#' - Warns if >20% of cells have expected < min_expected (default: 5)
#' - Chi-square may be unreliable if expected frequencies are too low
#' - Consider Fisher's exact test for small samples (not implemented here)
#'
#' EDGE CASES:
#' - Returns non-significant if any row/column sum is 0
#' - Returns non-significant if table is too small (< 2x2)
#' - Returns non-significant if chi-square or df calculation fails
#'
#' @param observed_matrix Matrix or data frame, observed frequencies (rows x columns)
#' @param min_expected Numeric, minimum expected frequency per cell (default: 5)
#' @param alpha Numeric, significance level (default: 0.05)
#' @return List with $significant (logical), $p_value (numeric), $chi_sq (numeric), $df (integer)
#' @export
#' @examples
#' # Create contingency table
#' observed <- matrix(c(50, 30, 20, 40), nrow = 2, ncol = 2)
#' result <- chi_square_test(observed)
#' 
#' # With custom parameters
#' result <- chi_square_test(observed, min_expected = 3, alpha = 0.01)
chi_square_test <- function(observed_matrix, min_expected = 5, alpha = 0.05) {
  # Parameter validation
  if (!is.numeric(alpha) || length(alpha) != 1 || alpha <= 0 || alpha >= 1) {
    stop("alpha must be a single numeric value between 0 and 1", call. = FALSE)
  }
  
  if (!is.numeric(min_expected) || length(min_expected) != 1 || min_expected < 0) {
    stop("min_expected must be a single non-negative numeric value", call. = FALSE)
  }
  
  # Convert to matrix if data frame
  if (is.data.frame(observed_matrix)) {
    observed_matrix <- as.matrix(observed_matrix)
  }
  
  # Validate input
  if (!is.numeric(observed_matrix)) {
    stop("observed_matrix must be numeric", call. = FALSE)
  }
  
  if (any(is.na(observed_matrix))) {
    warning("observed_matrix contains NA values; test skipped", call. = FALSE)
    return(list(significant = FALSE, p_value = NA_real_, chi_sq = NA_real_, df = NA_integer_))
  }
  
  if (any(observed_matrix < 0)) {
    warning("observed_matrix contains negative values; test skipped", call. = FALSE)
    return(list(significant = FALSE, p_value = NA_real_, chi_sq = NA_real_, df = NA_integer_))
  }
  
  # Check dimensions
  dims <- dim(observed_matrix)
  if (length(dims) != 2 || dims[1] < 2 || dims[2] < 2) {
    warning("observed_matrix must be at least 2x2; test skipped", call. = FALSE)
    return(list(significant = FALSE, p_value = NA_real_, chi_sq = NA_real_, df = NA_integer_))
  }
  
  # Check for zero row/column sums
  row_sums <- rowSums(observed_matrix)
  col_sums <- colSums(observed_matrix)
  
  if (any(row_sums == 0) || any(col_sums == 0)) {
    warning("observed_matrix has zero row or column sums; test skipped", call. = FALSE)
    return(list(significant = FALSE, p_value = NA_real_, chi_sq = NA_real_, df = NA_integer_))
  }
  
  tryCatch({
    # Calculate expected frequencies
    grand_total <- sum(observed_matrix)
    expected_matrix <- outer(row_sums, col_sums) / grand_total
    
    # Check minimum expected frequency
    low_expected <- expected_matrix < min_expected
    pct_low_expected <- 100 * sum(low_expected) / length(expected_matrix)
    
    if (pct_low_expected > 20) {
      warning(sprintf(
        "%.1f%% of cells have expected frequency < %.1f.\nChi-square test may be unreliable. Consider Fisher's exact test for small samples.",
        pct_low_expected,
        min_expected
      ), call. = FALSE)
    }
    
    # Calculate chi-square statistic
    chi_sq <- sum((observed_matrix - expected_matrix)^2 / expected_matrix)
    
    # Degrees of freedom
    df <- (dims[1] - 1) * (dims[2] - 1)
    
    if (df <= 0) {
      return(list(significant = FALSE, p_value = NA_real_, chi_sq = chi_sq, df = df))
    }
    
    # P-value
    p_value <- pchisq(chi_sq, df = df, lower.tail = FALSE)
    
    return(list(
      significant = (!is.na(p_value) && p_value < alpha),
      p_value = p_value,
      chi_sq = chi_sq,
      df = as.integer(df)
    ))
    
  }, error = function(e) {
    warning(sprintf("Chi-square test failed: %s", e$message), call. = FALSE)
    return(list(significant = FALSE, p_value = NA_real_, chi_sq = NA_real_, df = NA_integer_))
  })
}

# ==============================================================================
# 4. NET DIFFERENCE TESTS (Ranking Questions)
# ==============================================================================

#' Run net difference tests for ranking questions
#'
#' Tests whether "net positive" (e.g., Top 2 Box) differs from 
#' "net negative" (e.g., Bottom 2 Box) using z-tests.
#'
#' USAGE:
#' Typically used for rating scales where you want to compare:
#' - Top Box (e.g., "Strongly Agree" + "Agree")
#' - vs Bottom Box (e.g., "Disagree" + "Strongly Disagree")
#'
#' METHODOLOGY:
#' - Runs weighted_z_test_proportions() for each banner column
#' - Compares top box % vs bottom box %
#' - Uses provided effective-n for weighted data
#'
#' INPUT STRUCTURE:
#' test_data should be a data frame with columns:
#' - banner_col: Banner column identifier
#' - top_count: Count in top box (weighted if applicable)
#' - bottom_count: Count in bottom box (weighted if applicable)
#' - base: Total base (weighted if applicable)
#' - eff_n: Effective sample size (if weighted)
#'
#' @param test_data Data frame with columns: banner_col, top_count, bottom_count, base, eff_n
#' @param banner_info Data frame with banner column metadata
#' @param internal_keys Character vector, banner column keys to test
#' @param is_weighted Logical, whether data is weighted
#' @param min_base Numeric, minimum base size for testing (default: 30)
#' @param alpha Numeric, significance level (default: 0.05)
#' @return Data frame with test results for each banner column
#' @export
#' @examples
#' # Create test data
#' test_data <- data.frame(
#'   banner_col = c("Total", "Male", "Female"),
#'   top_count = c(60, 35, 25),
#'   bottom_count = c(20, 10, 10),
#'   base = c(100, 50, 50),
#'   eff_n = c(95, 48, 47)
#' )
#' 
#' # Run tests
#' results <- run_net_difference_tests(
#'   test_data = test_data,
#'   banner_info = banner_structure,
#'   internal_keys = c("Total", "Male", "Female"),
#'   is_weighted = TRUE
#' )
run_net_difference_tests <- function(test_data, banner_info, internal_keys,
                                    is_weighted = FALSE,
                                    min_base = 30,
                                    alpha = 0.05) {
  # Validate inputs
  if (!is.data.frame(test_data)) {
    stop("test_data must be a data frame", call. = FALSE)
  }
  
  required_cols <- c("banner_col", "top_count", "bottom_count", "base")
  if (is_weighted) {
    required_cols <- c(required_cols, "eff_n")
  }
  
  missing_cols <- setdiff(required_cols, names(test_data))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "test_data missing required columns: %s",
      paste(missing_cols, collapse = ", ")
    ), call. = FALSE)
  }
  
  # Initialize results
  results <- data.frame(
    banner_col = character(),
    top_pct = numeric(),
    bottom_pct = numeric(),
    net_diff = numeric(),
    significant = logical(),
    p_value = numeric(),
    stringsAsFactors = FALSE
  )
  
  # Run test for each banner column
  for (key in internal_keys) {
    # Get data for this column
    col_data <- test_data[test_data$banner_col == key, ]
    
    if (nrow(col_data) == 0) {
      next
    }
    
    # Extract values
    top_count <- col_data$top_count[1]
    bottom_count <- col_data$bottom_count[1]
    base <- col_data$base[1]
    eff_n <- if (is_weighted) col_data$eff_n[1] else base
    
    # Calculate percentages
    top_pct <- if (base > 0) (top_count / base) * 100 else NA
    bottom_pct <- if (base > 0) (bottom_count / base) * 100 else NA
    net_diff <- top_pct - bottom_pct
    
    # Run z-test comparing top vs bottom
    test_result <- weighted_z_test_proportions(
      count1 = top_count,
      base1 = base,
      count2 = bottom_count,
      base2 = base,
      eff_n1 = eff_n,
      eff_n2 = eff_n,
      is_weighted = is_weighted,
      min_base = min_base,
      alpha = alpha
    )
    
    # Add to results
    results <- rbind(results, data.frame(
      banner_col = key,
      top_pct = top_pct,
      bottom_pct = bottom_pct,
      net_diff = net_diff,
      significant = test_result$significant,
      p_value = test_result$p_value,
      stringsAsFactors = FALSE
    ))
  }
  
  return(results)
}

# ==============================================================================
# END OF SIGNIFICANCE MODULE
# ==============================================================================
