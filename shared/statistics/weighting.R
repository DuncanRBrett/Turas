# ==============================================================================
# TURAS: WEIGHTING & WEIGHTED CALCULATIONS
# ==============================================================================
# Complete weighting system for survey analytics
# Migrated from weighting.r V9.9.4 as part of Phase 5
# 
# CONTENTS:
# 1. validate_weights() - From Phase 3 (existing)
# 2. get_weight_vector() - Extract and validate weights from data
# 3. calculate_effective_n() - Kish effective sample size  
# 4. weighted_variance() - Population variance estimator
# 5. calculate_weighted_count() - Count with weights
# 6. calculate_weighted_base() - Calculate base sizes
# 7. calculate_weighted_percentage() - Percentage calculation
# 8. calculate_weighted_mean() - Weighted average
# 9. summarize_weights() - Weight diagnostics
#
# STATISTICAL METHODOLOGY:
# - Effective sample size: n_eff = (Σw)² / Σw² (Kish 1965)
# - Weighted variance: Var = Σw(x - x̄)² / Σw (population estimator)
# - Significance testing: Uses effective-n for SE calculations
#
# WEIGHT HANDLING POLICY:
# - NA weights: Treated as 0 (excluded from analysis)
# - Zero weights: Kept as 0 (excluded from sums)
# - Negative weights: Error (design weights cannot be negative)
# - Infinite weights: Warning and excluded (set to 0)
# ==============================================================================

# ==============================================================================
# EXISTING FUNCTION FROM PHASE 3 - validate_weights()
# ==============================================================================
# This function was created in Phase 3. It remains unchanged.
# Location in original system: shared/statistics/weighting.R
#
# NOTE: If you already have this function in your local weighting.R,
# you can skip this section when integrating.
# ==============================================================================

#' Validate weights in weighting configuration
#' 
#' Checks that weighting configuration is consistent and weight column
#' exists in the data when weighting is enabled.
#' 
#' @param survey_structure Survey structure list
#' @param survey_data Survey data frame
#' @param config Configuration list with $apply_weighting and $weight_variable
#' @param error_log Error log data frame
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Updated error log data frame
#' @export
validate_weights <- function(survey_structure, survey_data, config, error_log, verbose = TRUE) {
  if (verbose) cat("Validating weighting configuration...\n")
  
  # Check if weighting is enabled
  apply_weighting <- isTRUE(config$apply_weighting)
  
  if (apply_weighting) {
    # Check weight variable is specified
    if (is.null(config$weight_variable) || is.na(config$weight_variable) || 
        config$weight_variable == "") {
      error_log <- log_issue(
        error_log,
        "Weighting is enabled but no weight_variable specified in config",
        "Config",
        "Error"
      )
      return(error_log)
    }
    
    # Check weight column exists in data
    if (!config$weight_variable %in% names(survey_data)) {
      error_log <- log_issue(
        error_log,
        sprintf(
          "Weight variable '%s' not found in data. Available columns: %s",
          config$weight_variable,
          paste(head(names(survey_data), 10), collapse = ", ")
        ),
        "Data",
        "Error"
      )
      return(error_log)
    }
    
    # Check weight column is numeric
    weight_col <- survey_data[[config$weight_variable]]
    if (!is.numeric(weight_col)) {
      error_log <- log_issue(
        error_log,
        sprintf(
          "Weight variable '%s' must be numeric, got: %s",
          config$weight_variable,
          class(weight_col)[1]
        ),
        "Data",
        "Error"
      )
      return(error_log)
    }
    
    # Check for all NA weights
    if (all(is.na(weight_col))) {
      error_log <- log_issue(
        error_log,
        sprintf("Weight variable '%s' contains only NA values", config$weight_variable),
        "Data",
        "Error"
      )
      return(error_log)
    }
    
    # Check for negative weights
    if (any(weight_col < 0, na.rm = TRUE)) {
      error_log <- log_issue(
        error_log,
        sprintf(
          "Weight variable '%s' contains negative values. Design weights must be non-negative.",
          config$weight_variable
        ),
        "Data",
        "Warning"
      )
    }
    
    # Check for excessive NAs
    na_pct <- 100 * sum(is.na(weight_col)) / length(weight_col)
    if (na_pct > 10) {
      error_log <- log_issue(
        error_log,
        sprintf(
          "Weight variable '%s' contains %.1f%% NA values",
          config$weight_variable,
          na_pct
        ),
        "Data",
        "Warning"
      )
    }
    
    if (verbose) cat("✓ Weighting configuration validated\n")
  } else {
    if (verbose) cat("✓ Weighting disabled (skipped validation)\n")
  }
  
  return(error_log)
}

# ==============================================================================
# PHASE 5 NEW FUNCTIONS
# ==============================================================================

# ==============================================================================
# 1. WEIGHT EXTRACTION & VALIDATION
# ==============================================================================

#' Extract weight vector from data with proper repair policy
#'
#' Extracts the weight column from survey data and handles problematic
#' weight values according to the specified repair policy.
#'
#' WEIGHT REPAIR POLICIES:
#' - repair="exclude" (default): NA→0, zero→0, negative→error, infinite→0
#'   This is CORRECT for survey weights - excludes problematic cases
#' - repair="coerce_to_one": Legacy behavior (not recommended)
#'   Forces NA/zero/negative to 1, which biases estimates
#' - repair="error": Stops on any problematic weights
#'
#' DESIGN: Returns unit weights (all 1s) if weighting disabled or column missing
#'
#' @param data Data frame, survey data
#' @param weight_variable Character, name of weight column (NULL = no weighting)
#' @param repair Character, weight repair policy (default: "exclude")
#' @return Numeric vector of weights (length = nrow(data))
#' @export
#' @examples
#' # Recommended (excludes problematic weights)
#' weights <- get_weight_vector(survey_data, "weight", repair = "exclude")
#' 
#' # Legacy behavior (not recommended)
#' weights <- get_weight_vector(survey_data, "weight", repair = "coerce_to_one")
#' 
#' # Strict (errors on any issues)
#' weights <- get_weight_vector(survey_data, "weight", repair = "error")
get_weight_vector <- function(data, weight_variable, repair = c("exclude", "coerce_to_one", "error")) {
  repair <- match.arg(repair)
  
  # Validate data
  if (!is.data.frame(data) || nrow(data) == 0) {
    stop("data must be a non-empty data frame", call. = FALSE)
  }
  
  # No weighting requested
  if (is.null(weight_variable) || is.na(weight_variable) || weight_variable == "") {
    return(rep(1, nrow(data)))
  }
  
  # Check column exists
  if (!weight_variable %in% names(data)) {
    warning(sprintf(
      "Weight column '%s' not found in data. Using unweighted analysis.\nAvailable columns: %s",
      weight_variable,
      paste(head(names(data), 10), collapse = ", ")
    ), call. = FALSE)
    return(rep(1, nrow(data)))
  }
  
  weights <- data[[weight_variable]]
  
  # Type check
  if (!is.numeric(weights)) {
    stop(sprintf(
      "Weight column '%s' must be numeric, got: %s",
      weight_variable,
      class(weights)[1]
    ), call. = FALSE)
  }
  
  # Length check (should always match, but safety check)
  if (length(weights) != nrow(data)) {
    stop(sprintf(
      "Weight vector length (%d) does not match data rows (%d)",
      length(weights),
      nrow(data)
    ), call. = FALSE)
  }
  
  # Comprehensive diagnostics
  n_total <- length(weights)
  n_na <- sum(is.na(weights))
  n_negative <- sum(weights < 0, na.rm = TRUE)
  n_zero <- sum(weights == 0, na.rm = TRUE)
  n_infinite <- sum(is.infinite(weights))
  n_positive_finite <- sum(weights > 0 & is.finite(weights), na.rm = TRUE)
  
  # Check for fatal issue
  if (n_positive_finite == 0) {
    stop(sprintf(
      "Weight column '%s' has no positive finite values. Cannot perform weighted analysis.",
      weight_variable
    ), call. = FALSE)
  }
  
  # Apply repair policy
  if (repair == "error") {
    # Strict mode - error on any issues
    if (n_na > 0) {
      stop(sprintf(
        "Weight column '%s' contains %d NA values. Fix data before analysis.",
        weight_variable, n_na
      ), call. = FALSE)
    }
    if (n_negative > 0) {
      stop(sprintf(
        "Weight column '%s' contains %d negative values. Design weights cannot be negative.",
        weight_variable, n_negative
      ), call. = FALSE)
    }
    if (n_zero > 0) {
      stop(sprintf(
        "Weight column '%s' contains %d zero values. Fix data before analysis.",
        weight_variable, n_zero
      ), call. = FALSE)
    }
    if (n_infinite > 0) {
      stop(sprintf(
        "Weight column '%s' contains %d infinite values. Fix data before analysis.",
        weight_variable, n_infinite
      ), call. = FALSE)
    }
    
  } else if (repair == "exclude") {
    # Recommended mode - exclude problematic weights (set to 0)
    
    # Negative weights are a design error - always stop
    if (n_negative > 0) {
      stop(sprintf(
        "Weight column '%s' contains %d negative values (%.1f%%).\nDesign weights cannot be negative. Fix data before analysis.",
        weight_variable,
        n_negative,
        100 * n_negative / n_total
      ), call. = FALSE)
    }
    
    # NA weights - exclude (set to 0)
    if (n_na > 0) {
      warning(sprintf(
        "Weight column '%s' contains %d NA values (%.1f%%). These will be EXCLUDED (weight=0) from analysis.",
        weight_variable,
        n_na,
        100 * n_na / n_total
      ), call. = FALSE)
      weights[is.na(weights)] <- 0
    }
    
    # Infinite weights - exclude (set to 0)
    if (n_infinite > 0) {
      warning(sprintf(
        "Weight column '%s' contains %d infinite values (%.1f%%). These will be EXCLUDED (weight=0) from analysis.",
        weight_variable,
        n_infinite,
        100 * n_infinite / n_total
      ), call. = FALSE)
      weights[is.infinite(weights)] <- 0
    }
    
    # Zero weights - keep as 0, but warn if many
    if (n_zero > 0) {
      pct_zero <- 100 * n_zero / n_total
      if (pct_zero > 5) {
        warning(sprintf(
          "Weight column '%s' contains %d zero values (%.1f%%). These cases are EXCLUDED from weighted analysis.\nHigh proportion may indicate data quality issues.",
          weight_variable,
          n_zero,
          pct_zero
        ), call. = FALSE)
      }
    }
    
  } else {
    # coerce_to_one mode - legacy behavior (NOT RECOMMENDED)
    warning(sprintf(
      "Using legacy repair='coerce_to_one' mode. This is NOT RECOMMENDED as it biases estimates.\nConsider using repair='exclude' (default) instead."
    ), call. = FALSE)
    
    if (n_na > 0) {
      warning(sprintf(
        "Weight column '%s': Replacing %d NA values with 1 (unweighted). This may bias results.",
        weight_variable, n_na
      ), call. = FALSE)
      weights[is.na(weights)] <- 1
    }
    
    if (n_negative > 0) {
      warning(sprintf(
        "Weight column '%s': Replacing %d negative values with 1. This may bias results.",
        weight_variable, n_negative
      ), call. = FALSE)
      weights[weights < 0] <- 1
    }
    
    if (n_zero > 0) {
      warning(sprintf(
        "Weight column '%s': Replacing %d zero values with 1. This may bias results.",
        weight_variable, n_zero
      ), call. = FALSE)
      weights[weights == 0] <- 1
    }
    
    if (n_infinite > 0) {
      warning(sprintf(
        "Weight column '%s': Replacing %d infinite values with 1. This may bias results.",
        weight_variable, n_infinite
      ), call. = FALSE)
      weights[is.infinite(weights)] <- 1
    }
  }
  
  # Check weight variability (after repairs)
  valid_weights <- weights[weights > 0 & is.finite(weights)]
  if (length(valid_weights) > 0) {
    weight_cv <- sd(valid_weights) / mean(valid_weights)  # Coefficient of variation
    
    if (weight_cv > 1.0) {
      warning(sprintf(
        "Weight column '%s' has high variability (CV = %.2f). This may indicate:\n  1. Intentional design (e.g., raking weights)\n  2. Data quality issues\n  3. Very unequal sampling probabilities\nEffective sample size will be substantially reduced.",
        weight_variable,
        weight_cv
      ), call. = FALSE)
    }
  }
  
  return(as.numeric(weights))
}

# ==============================================================================
# 2. EFFECTIVE SAMPLE SIZE (Kish 1965)
# ==============================================================================

#' Calculate effective sample size for weighted data (Kish 1965)
#'
#' Computes the effective sample size which accounts for the loss of
#' precision due to differential weighting.
#'
#' METHODOLOGY:
#' Uses Kish's design effect formula: n_eff = (Σw)² / Σw²
#' 
#' NUMERIC STABILITY:
#' For extreme weights, scales by w/mean(w) internally (scale-invariant)
#' This prevents numeric overflow with very large weights
#' 
#' IMPLEMENTATION NOTES:
#' - Zero weights are excluded (only weights > 0 are used)
#' - Result is rounded to integer (downstream SE/df calculations use rounded value)
#' 
#' INTERPRETATION:
#' - n_eff = n when all weights equal (unweighted)
#' - n_eff < n when weights vary (reduced precision)
#' - Lower n_eff means higher design effect (less efficient sampling)
#' - Used in significance testing to account for weighting impact
#'
#' REFERENCE: Kish, L. (1965). Survey Sampling. New York: John Wiley & Sons.
#'
#' @param weights Numeric vector, weights (zero and negative weights excluded)
#' @return Integer, effective sample size (rounded)
#' @export
#' @examples
#' # Calculate effective n
#' weights <- c(1.2, 0.8, 1.5, 1.0, 0.9)
#' eff_n <- calculate_effective_n(weights)
#' 
#' # Check design effect
#' design_effect <- length(weights) / calculate_effective_n(weights)
#' cat("Design effect:", design_effect, "\n")
calculate_effective_n <- function(weights) {
  # Remove NA/infinite weights and keep only positive (zeros excluded)
  weights <- weights[!is.na(weights) & is.finite(weights) & weights > 0]
  
  if (length(weights) == 0) {
    return(0L)
  }
  
  # If all weights are 1, effective n = actual n (no design effect)
  if (all(weights == 1)) {
    return(as.integer(length(weights)))
  }
  
  # Scale-safe calculation for extreme weights
  # Effective-n is scale-invariant, so we can normalize by mean
  # This prevents numeric overflow with very large weights
  mean_weight <- mean(weights)
  
  if (is.finite(mean_weight) && mean_weight > 0) {
    # Scale by mean for numeric stability
    w <- weights / mean_weight
    n_effective <- (sum(w)^2) / sum(w^2)
  } else {
    # Fallback to direct calculation (shouldn't happen if weights validated)
    sum_weights <- sum(weights)
    sum_weights_squared <- sum(weights^2)
    
    if (sum_weights_squared == 0) {
      return(0L)
    }
    
    n_effective <- (sum_weights^2) / sum_weights_squared
  }
  
  # Return as integer (downstream SE/df use this rounded value)
  return(as.integer(round(n_effective)))
}

# ==============================================================================
# 3. WEIGHTED VARIANCE (Population Estimator)
# ==============================================================================

#' Calculate weighted variance (POPULATION VARIANCE)
#'
#' Computes the population variance estimator for weighted data.
#'
#' METHODOLOGY:
#' Uses population variance estimator: Var = Σw(x - x̄)² / Σw
#' NOT Bessel-corrected (unbiased) estimator
#' 
#' RATIONALE:
#' - This is appropriate because effective-n is used in SE calculations
#' - Combining population variance with effective-n gives correct SE
#' - If you need unbiased variance, divide by (Σw - 1) instead
#'
#' USAGE: Called by weighted t-tests for means
#'
#' @param values Numeric vector, values to calculate variance for
#' @param weights Numeric vector, weights (same length as values)
#' @return Numeric, weighted population variance
#' @export
#' @examples
#' values <- c(5, 3, 8, 6, 4)
#' weights <- c(1.2, 0.8, 1.5, 1.0, 0.9)
#' var_weighted <- weighted_variance(values, weights)
weighted_variance <- function(values, weights) {
  # Validate inputs
  if (length(values) != length(weights)) {
    stop(sprintf(
      "values and weights must have same length (got %d and %d)",
      length(values),
      length(weights)
    ), call. = FALSE)
  }
  
  # Keep only valid observations
  valid_idx <- !is.na(values) & !is.na(weights) & is.finite(weights) & weights > 0
  values <- values[valid_idx]
  weights <- weights[valid_idx]
  
  if (length(values) < 2) {
    return(0)
  }
  
  sum_weights <- sum(weights)
  if (sum_weights == 0) {
    return(0)
  }
  
  # Calculate weighted mean
  weighted_mean <- sum(values * weights) / sum_weights
  
  # Calculate weighted population variance
  weighted_var <- sum(weights * (values - weighted_mean)^2) / sum_weights
  
  return(weighted_var)
}

# ==============================================================================
# 4. WEIGHTED COUNTS
# ==============================================================================

#' Calculate weighted count
#'
#' Counts respondents matching a condition with weights applied.
#'
#' DESIGN: Treats NA in condition as FALSE (explicit, safe)
#' 
#' @param condition_vector Logical vector, which rows to count
#' @param weights Numeric vector, weight vector (same length as condition)
#' @return Numeric, weighted count
#' @export
#' @examples
#' condition <- c(TRUE, FALSE, TRUE, TRUE, FALSE)
#' weights <- c(1.2, 0.8, 1.5, 1.0, 0.9)
#' weighted_count <- calculate_weighted_count(condition, weights)
calculate_weighted_count <- function(condition_vector, weights) {
  # Stop on length mismatch
  if (length(condition_vector) != length(weights)) {
    stop(sprintf(
      "Condition vector (%d) and weights (%d) have different lengths",
      length(condition_vector),
      length(weights)
    ), call. = FALSE)
  }
  
  # Explicit NA handling - treat NA as FALSE
  cond <- as.logical(condition_vector)
  idx <- !is.na(cond) & cond
  
  # Sum weights where condition is TRUE (na.rm for safety with weights)
  weighted_count <- sum(weights[idx], na.rm = TRUE)
  
  return(weighted_count)
}

# ==============================================================================
# 5. WEIGHTED BASE CALCULATION
# ==============================================================================

#' Calculate weighted base for a question
#'
#' Calculates unweighted base, weighted base, and effective sample size
#' for a survey question.
#'
#' RETURN STRUCTURE:
#' Returns list with keys: unweighted, weighted, effective
#'
#' DESIGN: 
#' - Counts respondents with at least one valid response
#' - Handles multi-mention questions correctly
#' - Type-robust "has response" detection (numeric vs character)
#'
#' @param data_subset Data frame, filtered data subset
#' @param question_info Data frame row, question metadata with $QuestionCode and $Variable_Type
#' @param weights Numeric vector, weight vector for subset
#' @return List with $unweighted (integer), $weighted (numeric), $effective (integer)
#' @export
#' @examples
#' # Single mention question
#' base_info <- calculate_weighted_base(filtered_data, q_info, weights)
#' cat("Unweighted:", base_info$unweighted, "\n")
#' cat("Weighted:", base_info$weighted, "\n")
#' cat("Effective:", base_info$effective, "\n")
calculate_weighted_base <- function(data_subset, question_info, weights) {
  # Validate inputs
  if (!is.data.frame(data_subset)) {
    stop("data_subset must be a data frame", call. = FALSE)
  }
  
  if (!is.data.frame(question_info) || nrow(question_info) == 0) {
    stop("question_info must be a non-empty data frame", call. = FALSE)
  }
  
  if (!is.numeric(weights)) {
    stop("weights must be numeric", call. = FALSE)
  }
  
  if (length(weights) != nrow(data_subset)) {
    stop(sprintf(
      "Weight vector length (%d) must match data rows (%d)",
      length(weights),
      nrow(data_subset)
    ), call. = FALSE)
  }
  
  # Empty data
  if (nrow(data_subset) == 0) {
    return(list(unweighted = 0, weighted = 0, effective = 0))
  }
  
  question_code <- question_info$QuestionCode
  
  # Multi-mention questions: count respondents with at least one answer
  if (question_info$Variable_Type == "Multi_Mention") {
    num_columns <- suppressWarnings(as.numeric(question_info$Columns))
    
    if (is.na(num_columns) || num_columns < 1) {
      return(list(unweighted = 0, weighted = 0, effective = 0))
    }
    
    question_cols <- paste0(question_code, "_", seq_len(num_columns))
    existing_cols <- question_cols[question_cols %in% names(data_subset)]
    
    if (length(existing_cols) == 0) {
      return(list(unweighted = 0, weighted = 0, effective = 0))
    }
    
    # Check if any column has a response (type-robust)
    has_response <- rep(FALSE, nrow(data_subset))
    for (col in existing_cols) {
      col_data <- data_subset[[col]]
      if (is.numeric(col_data)) {
        # Numeric: non-NA and non-zero means response
        has_response <- has_response | (!is.na(col_data) & col_data != 0)
      } else {
        # Character/factor: non-NA and non-empty means response
        has_response <- has_response | (!is.na(col_data) & col_data != "")
      }
    }
    
    unweighted_base <- sum(has_response)
    weighted_base <- sum(weights[has_response], na.rm = TRUE)
    effective_base <- calculate_effective_n(weights[has_response])
    
  } else {
    # Single mention: check if main column has response
    if (!question_code %in% names(data_subset)) {
      return(list(unweighted = 0, weighted = 0, effective = 0))
    }
    
    col_data <- data_subset[[question_code]]
    
    # Type-robust response detection
    if (is.numeric(col_data)) {
      has_response <- !is.na(col_data) & col_data != 0
    } else {
      has_response <- !is.na(col_data) & col_data != ""
    }
    
    unweighted_base <- sum(has_response)
    weighted_base <- sum(weights[has_response], na.rm = TRUE)
    effective_base <- calculate_effective_n(weights[has_response])
  }
  
  return(list(
    unweighted = as.integer(unweighted_base),
    weighted = weighted_base,
    effective = as.integer(effective_base)
  ))
}

# ==============================================================================
# 6. WEIGHTED PERCENTAGE
# ==============================================================================

#' Calculate weighted percentage
#'
#' Simple percentage calculation from weighted count and base.
#'
#' @param weighted_count Numeric, weighted count
#' @param weighted_base Numeric, weighted base
#' @param decimal_places Integer, number of decimal places (default: 1)
#' @return Numeric, percentage (0-100 scale)
#' @export
#' @examples
#' pct <- calculate_weighted_percentage(45.2, 100.0, decimal_places = 1)
calculate_weighted_percentage <- function(weighted_count, weighted_base, 
                                         decimal_places = 1) {
  if (is.na(weighted_base) || weighted_base == 0) {
    return(NA_real_)
  }
  
  pct <- (weighted_count / weighted_base) * 100
  return(round(pct, decimal_places))
}

# ==============================================================================
# 7. WEIGHTED MEAN
# ==============================================================================

#' Calculate weighted mean
#'
#' Computes the weighted average of numeric values.
#'
#' DESIGN:
#' - Filters to valid observations (non-NA values with positive weights)
#' - Returns NA if no valid observations
#' - Standard weighted mean: Σ(w * x) / Σw
#'
#' @param values Numeric vector, values to average
#' @param weights Numeric vector, weights (same length as values)
#' @return Numeric, weighted mean (or NA if no valid observations)
#' @export
#' @examples
#' values <- c(5, 3, 8, 6, 4)
#' weights <- c(1.2, 0.8, 1.5, 1.0, 0.9)
#' mean_weighted <- calculate_weighted_mean(values, weights)
calculate_weighted_mean <- function(values, weights) {
  # Validate inputs
  if (length(values) != length(weights)) {
    stop(sprintf(
      "values and weights must have same length (got %d and %d)",
      length(values),
      length(weights)
    ), call. = FALSE)
  }
  
  # Keep only valid observations
  valid_idx <- !is.na(values) & !is.na(weights) & is.finite(weights) & weights > 0
  values <- values[valid_idx]
  weights <- weights[valid_idx]
  
  if (length(values) == 0) {
    return(NA_real_)
  }
  
  sum_weights <- sum(weights)
  if (sum_weights == 0) {
    return(NA_real_)
  }
  
  # Calculate weighted mean
  weighted_mean <- sum(values * weights) / sum_weights
  
  return(weighted_mean)
}

# ==============================================================================
# 8. WEIGHT DIAGNOSTICS
# ==============================================================================

#' Summarize weights for diagnostic purposes
#'
#' Provides comprehensive summary statistics for weight distribution,
#' including design effect and efficiency metrics.
#'
#' OUTPUT:
#' Prints formatted summary to console and returns list of statistics
#'
#' METRICS:
#' - Basic stats: min, max, mean, median, SD
#' - Sample sizes: n, effective n, design effect
#' - Distribution: CV, skewness
#' - Problematic values: NA, zero, negative, infinite
#'
#' @param weights Numeric vector, weights to summarize
#' @param label Character, label for output (default: "Weight Summary")
#' @return List of weight statistics (invisibly)
#' @export
#' @examples
#' weights <- c(1.2, 0.8, 1.5, 1.0, 0.9, NA, 0)
#' weight_stats <- summarize_weights(weights, label = "Survey Weights")
summarize_weights <- function(weights, label = "Weight Summary") {
  cat("\n")
  cat("=====================================\n")
  cat(label, "\n")
  cat("=====================================\n")
  
  # Basic counts
  n_total <- length(weights)
  n_na <- sum(is.na(weights))
  n_zero <- sum(weights == 0, na.rm = TRUE)
  n_negative <- sum(weights < 0, na.rm = TRUE)
  n_infinite <- sum(is.infinite(weights))
  n_valid <- sum(!is.na(weights) & is.finite(weights) & weights > 0)
  
  cat("\nSample Size:\n")
  cat(sprintf("  Total cases:        %d\n", n_total))
  cat(sprintf("  Valid weights:      %d\n", n_valid))
  if (n_na > 0) {
    cat(sprintf("  NA weights:         %d (%.1f%%)\n", n_na, 100 * n_na / n_total))
  }
  if (n_zero > 0) {
    cat(sprintf("  Zero weights:       %d (%.1f%%)\n", n_zero, 100 * n_zero / n_total))
  }
  if (n_negative > 0) {
    cat(sprintf("  Negative weights:   %d (%.1f%%) [ERROR]\n", n_negative, 100 * n_negative / n_total))
  }
  if (n_infinite > 0) {
    cat(sprintf("  Infinite weights:   %d (%.1f%%) [ERROR]\n", n_infinite, 100 * n_infinite / n_total))
  }
  
  # Statistics on valid weights
  valid_weights <- weights[!is.na(weights) & is.finite(weights) & weights > 0]
  
  if (length(valid_weights) > 0) {
    cat("\nWeight Distribution:\n")
    cat(sprintf("  Min:                %.4f\n", min(valid_weights)))
    cat(sprintf("  Max:                %.4f\n", max(valid_weights)))
    cat(sprintf("  Mean:               %.4f\n", mean(valid_weights)))
    cat(sprintf("  Median:             %.4f\n", median(valid_weights)))
    cat(sprintf("  SD:                 %.4f\n", sd(valid_weights)))
    
    # Coefficient of variation
    cv <- sd(valid_weights) / mean(valid_weights)
    cat(sprintf("  CV:                 %.4f\n", cv))
    
    # Design effect
    eff_n <- calculate_effective_n(valid_weights)
    deff <- length(valid_weights) / eff_n
    efficiency <- (1 / deff) * 100
    
    cat("\nDesign Effect:\n")
    cat(sprintf("  Effective n:        %d\n", eff_n))
    cat(sprintf("  Design effect:      %.4f\n", deff))
    cat(sprintf("  Efficiency:         %.1f%%\n", efficiency))
    
    # Interpretation
    if (deff > 2) {
      cat("\n⚠️  High design effect - substantial loss of precision\n")
    } else if (deff > 1.5) {
      cat("\n⚠️  Moderate design effect - some loss of precision\n")
    } else {
      cat("\n✓ Low design effect - minimal loss of precision\n")
    }
  } else {
    cat("\n⚠️  No valid weights available\n")
  }
  
  cat("\n")
  
  # Return statistics invisibly
  invisible(list(
    n_total = n_total,
    n_valid = n_valid,
    n_na = n_na,
    n_zero = n_zero,
    n_negative = n_negative,
    n_infinite = n_infinite,
    min = if (length(valid_weights) > 0) min(valid_weights) else NA,
    max = if (length(valid_weights) > 0) max(valid_weights) else NA,
    mean = if (length(valid_weights) > 0) mean(valid_weights) else NA,
    median = if (length(valid_weights) > 0) median(valid_weights) else NA,
    sd = if (length(valid_weights) > 0) sd(valid_weights) else NA,
    cv = if (length(valid_weights) > 0) sd(valid_weights) / mean(valid_weights) else NA,
    effective_n = if (length(valid_weights) > 0) calculate_effective_n(valid_weights) else 0,
    design_effect = if (length(valid_weights) > 0) length(valid_weights) / calculate_effective_n(valid_weights) else NA
  ))
}

# ==============================================================================
# END OF WEIGHTING MODULE
# ==============================================================================
