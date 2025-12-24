# ==============================================================================
# WEIGHTING MODULE - WEIGHT TRIMMING
# ==============================================================================
# Functions for capping and trimming extreme weights
# Part of TURAS Weighting Module v1.0
#
# PURPOSE:
# Extreme weights can destabilize estimates by giving too much influence
# to individual respondents. Weight trimming caps extreme values to
# improve estimate stability at the cost of some bias.
#
# METHODS:
# - Cap: Hard maximum value (e.g., no weight > 5)
# - Percentile: Cap at a percentile (e.g., 95th percentile)
# ==============================================================================

#' Trim Weights
#'
#' Applies weight trimming to reduce extreme values.
#'
#' @param weights Numeric vector of weights
#' @param method Character, trimming method: "cap" or "percentile"
#' @param value Numeric, max weight (for cap) or percentile threshold (for percentile)
#' @param verbose Logical, print trimming details (default: FALSE)
#' @return List with $weights (trimmed), $n_trimmed, $original_max, $new_max
#' @export
#'
#' @examples
#' # Cap at maximum weight of 5
#' trimmed <- trim_weights(weights, method = "cap", value = 5)
#'
#' # Trim to 95th percentile
#' trimmed <- trim_weights(weights, method = "percentile", value = 0.95)
trim_weights <- function(weights,
                         method = c("cap", "percentile"),
                         value,
                         verbose = FALSE) {

  method <- match.arg(method)

  # Validate inputs
  if (!is.numeric(weights)) {
    stop("weights must be a numeric vector", call. = FALSE)
  }

  if (!is.numeric(value) || length(value) != 1 || is.na(value)) {
    stop("value must be a single numeric value", call. = FALSE)
  }

  # Get valid weights for calculation
  valid_idx <- !is.na(weights) & is.finite(weights) & weights > 0
  n_valid <- sum(valid_idx)

  if (n_valid == 0) {
    return(list(
      weights = weights,
      n_trimmed = 0,
      original_max = NA_real_,
      new_max = NA_real_,
      threshold = NA_real_
    ))
  }

  original_max <- max(weights[valid_idx])
  original_min <- min(weights[valid_idx])

  # Determine threshold based on method
  if (method == "cap") {
    if (value <= 0) {
      stop("For 'cap' method, value must be positive", call. = FALSE)
    }
    threshold <- value

    if (verbose) {
      message("Trimming method: Hard cap at ", value)
    }

  } else if (method == "percentile") {
    if (value <= 0 || value >= 1) {
      stop("For 'percentile' method, value must be between 0 and 1 (e.g., 0.95)", call. = FALSE)
    }
    threshold <- quantile(weights[valid_idx], probs = value, na.rm = TRUE)

    if (verbose) {
      message(sprintf(
        "Trimming method: Percentile cap at %.1f%% (threshold = %.4f)",
        value * 100, threshold
      ))
    }
  }

  # Apply trimming
  trimmed_weights <- weights
  n_trimmed <- sum(weights[valid_idx] > threshold)

  if (n_trimmed > 0) {
    trimmed_weights[valid_idx & weights > threshold] <- threshold
  }

  new_max <- max(trimmed_weights[valid_idx])

  # Report results
  if (verbose) {
    message(sprintf("  Original range: %.4f - %.4f", original_min, original_max))
    message(sprintf("  Weights trimmed: %d (%.1f%%)", n_trimmed, 100 * n_trimmed / n_valid))
    message(sprintf("  New range: %.4f - %.4f", original_min, new_max))
  }

  return(list(
    weights = trimmed_weights,
    n_trimmed = n_trimmed,
    original_max = original_max,
    new_max = new_max,
    threshold = threshold,
    method = method,
    pct_trimmed = 100 * n_trimmed / n_valid
  ))
}

#' Apply Trimming from Configuration
#'
#' Applies trimming based on weight specification from config.
#'
#' @param weights Numeric vector of weights
#' @param spec Named list, weight specification from config
#' @param verbose Logical, print progress messages
#' @return List with trimming results (or original weights if no trimming)
#' @export
apply_trimming_from_config <- function(weights, spec, verbose = FALSE) {

  # Check if trimming is configured
  apply_trim <- !is.null(spec$apply_trimming) &&
                !is.na(spec$apply_trimming) &&
                toupper(spec$apply_trimming) == "Y"

  if (!apply_trim) {
    if (verbose) {
      message("  No trimming applied (apply_trimming = N)")
    }
    return(list(
      weights = weights,
      n_trimmed = 0,
      original_max = max(weights[!is.na(weights) & weights > 0], na.rm = TRUE),
      new_max = max(weights[!is.na(weights) & weights > 0], na.rm = TRUE),
      threshold = NA_real_,
      trimming_applied = FALSE
    ))
  }

  # Get trimming parameters
  method <- tolower(spec$trim_method)
  value <- as.numeric(spec$trim_value)

  if (is.na(value)) {
    warning("trim_value is NA, skipping trimming", call. = FALSE)
    return(list(
      weights = weights,
      n_trimmed = 0,
      original_max = max(weights[!is.na(weights) & weights > 0], na.rm = TRUE),
      new_max = max(weights[!is.na(weights) & weights > 0], na.rm = TRUE),
      threshold = NA_real_,
      trimming_applied = FALSE
    ))
  }

  if (verbose) {
    message("\nApplying weight trimming...")
  }

  result <- trim_weights(
    weights = weights,
    method = method,
    value = value,
    verbose = verbose
  )

  result$trimming_applied <- TRUE

  # Warn if many weights trimmed
  if (result$pct_trimmed > 5) {
    warning(sprintf(
      "%.1f%% of weights were trimmed. This may introduce bias.\nConsider reviewing targets or adjusting trim threshold.",
      result$pct_trimmed
    ), call. = FALSE)
  }

  return(result)
}

#' Two-Sided Trimming
#'
#' Trims both very low and very high weights.
#'
#' @param weights Numeric vector of weights
#' @param lower_pct Numeric, lower percentile (e.g., 0.01 for 1st percentile)
#' @param upper_pct Numeric, upper percentile (e.g., 0.99 for 99th percentile)
#' @param verbose Logical, print details
#' @return List with trimmed weights and details
#' @export
trim_weights_two_sided <- function(weights,
                                   lower_pct = 0.01,
                                   upper_pct = 0.99,
                                   verbose = FALSE) {

  if (lower_pct >= upper_pct) {
    stop("lower_pct must be less than upper_pct", call. = FALSE)
  }

  if (lower_pct <= 0 || upper_pct >= 1) {
    stop("Percentiles must be between 0 and 1 (exclusive)", call. = FALSE)
  }

  valid_idx <- !is.na(weights) & is.finite(weights) & weights > 0
  n_valid <- sum(valid_idx)

  if (n_valid == 0) {
    return(list(
      weights = weights,
      n_trimmed_low = 0,
      n_trimmed_high = 0,
      lower_threshold = NA_real_,
      upper_threshold = NA_real_
    ))
  }

  # Calculate thresholds
  lower_threshold <- quantile(weights[valid_idx], probs = lower_pct, na.rm = TRUE)
  upper_threshold <- quantile(weights[valid_idx], probs = upper_pct, na.rm = TRUE)

  original_max <- max(weights[valid_idx])
  original_min <- min(weights[valid_idx])

  if (verbose) {
    message(sprintf(
      "Two-sided trimming: [%.1f%%, %.1f%%] -> [%.4f, %.4f]",
      lower_pct * 100, upper_pct * 100,
      lower_threshold, upper_threshold
    ))
    message(sprintf("  Original range: %.4f - %.4f", original_min, original_max))
  }

  # Apply trimming
  trimmed_weights <- weights

  n_trimmed_low <- sum(weights[valid_idx] < lower_threshold)
  n_trimmed_high <- sum(weights[valid_idx] > upper_threshold)

  trimmed_weights[valid_idx & weights < lower_threshold] <- lower_threshold
  trimmed_weights[valid_idx & weights > upper_threshold] <- upper_threshold

  if (verbose) {
    message(sprintf("  Trimmed low: %d, Trimmed high: %d", n_trimmed_low, n_trimmed_high))
    new_range <- range(trimmed_weights[valid_idx])
    message(sprintf("  New range: %.4f - %.4f", new_range[1], new_range[2]))
  }

  return(list(
    weights = trimmed_weights,
    n_trimmed_low = n_trimmed_low,
    n_trimmed_high = n_trimmed_high,
    lower_threshold = lower_threshold,
    upper_threshold = upper_threshold,
    n_total_trimmed = n_trimmed_low + n_trimmed_high,
    pct_trimmed = 100 * (n_trimmed_low + n_trimmed_high) / n_valid
  ))
}

#' Winsorize Weights
#'
#' Alternative name for two-sided percentile trimming.
#' Winsorization replaces extreme values with less extreme values.
#'
#' @param weights Numeric vector of weights
#' @param trim_pct Numeric, percentage to trim from each tail (e.g., 0.05 = 5%)
#' @param verbose Logical, print details
#' @return List with winsorized weights and details
#' @export
winsorize_weights <- function(weights, trim_pct = 0.05, verbose = FALSE) {
  trim_weights_two_sided(
    weights = weights,
    lower_pct = trim_pct,
    upper_pct = 1 - trim_pct,
    verbose = verbose
  )
}

#' Rescale Weights After Trimming
#'
#' After trimming, weights may no longer sum to the original total.
#' This function rescales to restore the original sum.
#'
#' @param original_weights Numeric vector, weights before trimming
#' @param trimmed_weights Numeric vector, weights after trimming
#' @return Numeric vector, rescaled weights
#' @export
rescale_after_trimming <- function(original_weights, trimmed_weights) {
  valid_orig <- !is.na(original_weights) & is.finite(original_weights) & original_weights > 0
  valid_trim <- !is.na(trimmed_weights) & is.finite(trimmed_weights) & trimmed_weights > 0

  original_sum <- sum(original_weights[valid_orig])
  trimmed_sum <- sum(trimmed_weights[valid_trim])

  if (trimmed_sum == 0) {
    warning("Cannot rescale: trimmed weights sum to zero", call. = FALSE)
    return(trimmed_weights)
  }

  scale_factor <- original_sum / trimmed_sum

  rescaled <- trimmed_weights
  rescaled[valid_trim] <- trimmed_weights[valid_trim] * scale_factor

  return(rescaled)
}

#' Iterative Trimming with Convergence
#'
#' For rim weights, applies trimming then re-rakes to maintain margins.
#' This is an advanced technique for complex weighting scenarios.
#'
#' @param data Data frame, survey data
#' @param target_list Named list of rim targets
#' @param cap Numeric, maximum weight
#' @param max_outer_iterations Integer, max trimming iterations
#' @param verbose Logical, print progress
#' @return List with final weights and iteration details
#' @export
iterative_rim_trim <- function(data,
                               target_list,
                               cap,
                               max_outer_iterations = 5,
                               verbose = FALSE) {

  check_anesrake_available()

  if (verbose) {
    message("\nIterative rim weighting with trimming...")
    message("  Cap: ", cap)
    message("  Max outer iterations: ", max_outer_iterations)
  }

  # Initial rim weighting with cap built in
  result <- calculate_rim_weights(
    data = data,
    target_list = target_list,
    cap = cap,
    verbose = verbose
  )

  # The anesrake package handles iterative capping internally when cap is specified
  # So this wrapper primarily exists for custom trim-and-rerake strategies

  return(result)
}
