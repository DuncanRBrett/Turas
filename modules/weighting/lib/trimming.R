# ==============================================================================
# WEIGHTING MODULE - WEIGHT TRIMMING
# ==============================================================================
# Functions for capping and trimming extreme weights
# Part of TURAS Weighting Module v3.0
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
    weighting_refuse(
      code = "DATA_INVALID_TYPE",
      title = "Invalid Weight Type",
      problem = "The weights parameter is not a numeric vector",
      why_it_matters = "Weight trimming requires numeric values to calculate thresholds and apply caps",
      how_to_fix = "Ensure weights is a numeric vector before calling trim_weights()"
    )
  }

  if (!is.numeric(value) || length(value) != 1 || is.na(value)) {
    weighting_refuse(
      code = "DATA_INVALID_PARAMETER",
      title = "Invalid Trim Value",
      problem = "The value parameter must be a single non-NA numeric value",
      why_it_matters = "The trimming threshold must be a well-defined numeric value to cap weights",
      how_to_fix = "Provide a single numeric value for the value parameter (e.g., value = 5 or value = 0.95)"
    )
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
      weighting_refuse(
        code = "CFG_INVALID_CAP",
        title = "Invalid Cap Value",
        problem = sprintf("Cap value must be positive, but got %s", value),
        why_it_matters = "A negative or zero cap would set all weights to zero or negative, making the data unusable",
        how_to_fix = "Set value to a positive number (e.g., value = 5 for a maximum weight of 5)"
      )
    }
    threshold <- value

    if (verbose) {
      message("Trimming method: Hard cap at ", value)
    }

  } else if (method == "percentile") {
    if (value <= 0 || value >= 1) {
      weighting_refuse(
        code = "CFG_INVALID_PERCENTILE",
        title = "Invalid Percentile Value",
        problem = sprintf("Percentile value must be between 0 and 1, but got %s", value),
        why_it_matters = "Percentiles represent proportions of the distribution and must be in the range (0, 1)",
        how_to_fix = "Use a value between 0 and 1, such as 0.95 for the 95th percentile or 0.99 for the 99th percentile"
      )
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
#' Post-hoc trimming caps weights AFTER they were calculated, which breaks
#' whatever the calculation had just established. Two different things follow
#' from that, depending on the method:
#'
#' \itemize{
#'   \item \strong{rim/rake} — refused. Raking calibrates the weights so the
#'     weighted margins hit the targets and the weights sum to n. Capping
#'     afterwards destroys both, and nothing re-rakes. The correct mechanism
#'     already exists: \code{cap_weights} is passed to \code{survey::calibrate}
#'     as \code{bounds}, so the cap holds \emph{during} calibration and the
#'     margins still come out right.
#'   \item \strong{design/cell} — applied, then rescaled to restore the original
#'     sum, and disclosed. These methods have no calibrated margins to break,
#'     but an uncorrected trim still shrinks the weighted base.
#' }
#'
#' @param weights Numeric vector of weights
#' @param spec Named list, weight specification from config. \code{spec$method}
#'   decides which of the two paths above applies.
#' @param verbose Logical, print progress messages
#' @param warn_threshold Numeric, percentage threshold for warning (default: 5)
#' @return List with trimming results (or original weights if no trimming)
#' @export
apply_trimming_from_config <- function(weights, spec, verbose = FALSE, warn_threshold = 5) {

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

  # Rim weights are calibrated. Post-hoc capping breaks the calibration and
  # nothing puts it back, so the run would ship weights whose margins no longer
  # match the targets the config asked for while still reporting them as
  # achieved. Refuse, and name the setting that does this correctly.
  weight_method <- if (is.null(spec$method) || all(is.na(spec$method))) {
    ""
  } else {
    tolower(as.character(spec$method)[1])
  }

  if (weight_method %in% c("rim", "rake")) {
    weighting_refuse(
      code = "CFG_TRIM_USE_CAP",
      title = "Post-hoc trimming cannot be used with rim weights",
      problem = sprintf(
        "Weight '%s' is a %s weight with apply_trimming = Y. Rim weighting calibrates the weights so the weighted margins match the targets and the weights sum to n. Capping them afterwards breaks both, and nothing re-rakes them.",
        if (is.null(spec$weight_name)) "(unnamed)" else as.character(spec$weight_name)[1],
        weight_method
      ),
      why_it_matters = "The run would report the raked margins as achieved while shipping weights that no longer meet them. Every weighted base and percentage in the tabs report built on those weights would be wrong, with nothing on the face of the report to show it.",
      how_to_fix = "Set apply_trimming = N and use cap_weights instead. cap_weights is passed to survey::calibrate() as the upper weight bound, so the cap applies DURING calibration and the margins still come out right. If you also need a floor, set weight_bounds."
    )
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

  # Capping removes weight from the sample and puts none back, so the weights no
  # longer sum to what they summed to before. For design weights that shrinks the
  # grossed-up population; for cell weights it drops the weighted base below n.
  # Restore the original sum, and record both sums so the disclosure below and
  # the diagnostics can say what moved.
  valid_before <- !is.na(weights) & is.finite(weights) & weights > 0
  sum_before <- sum(weights[valid_before])

  trimmed_weights <- result$weights
  valid_trimmed <- !is.na(trimmed_weights) & is.finite(trimmed_weights) & trimmed_weights > 0
  sum_trimmed <- sum(trimmed_weights[valid_trimmed])

  result$weights <- rescale_after_trimming(weights, trimmed_weights)

  valid_after <- !is.na(result$weights) & is.finite(result$weights) & result$weights > 0
  sum_after <- sum(result$weights[valid_after])
  scale_factor <- if (sum_trimmed > 0) sum_before / sum_trimmed else NA_real_

  result$rescaled <- TRUE
  result$sum_before <- sum_before
  result$sum_trimmed <- sum_trimmed
  result$sum_after <- sum_after
  result$rescale_factor <- scale_factor
  result$max_after_rescale <- if (any(valid_after)) max(result$weights[valid_after]) else NA_real_

  # Rescaling restores the total but pushes the capped weights back above the
  # cap. Say so rather than letting a "capped at 5" run ship a weight of 5.2.
  if (!is.na(result$max_after_rescale) && !is.na(result$threshold) &&
      result$max_after_rescale > result$threshold * (1 + 1e-8)) {
    cat("\n┌─── TURAS WARNING ─────────────────────────────────────┐\n")
    cat("│ Context: Weighting - post-hoc trimming\n")
    cat("│ Code: CALC_TRIM_RESCALED_ABOVE_CAP\n")
    cat(sprintf("│ %d weight(s) were capped at %.4f, then every weight was\n",
                result$n_trimmed, result$threshold))
    cat(sprintf("│ rescaled by %.6f to restore the sum (%.2f -> %.2f -> %.2f).\n",
                scale_factor, sum_before, sum_trimmed, sum_after))
    cat(sprintf("│ The largest weight is now %.4f, above the cap.\n",
                result$max_after_rescale))
    cat("│ How to fix: this is the cost of capping after the fact. The\n")
    cat("│ total is right and the cap is nominal. Soften the target if\n")
    cat("│ the largest weight matters more than the total.\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
  }

  if (verbose) {
    message(sprintf("  Rescaled after trimming: sum %.4f -> %.4f -> %.4f (factor %.6f)",
                    sum_before, sum_trimmed, sum_after, scale_factor))
  }

  # Warn if many weights trimmed (configurable threshold)
  if (result$pct_trimmed > warn_threshold) {
    warning(sprintf(
      "%.1f%% of weights were trimmed (threshold: %.1f%%). This may introduce bias.\nConsider reviewing targets or adjusting trim threshold.",
      result$pct_trimmed, warn_threshold
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
    weighting_refuse(
      code = "CFG_INVALID_PERCENTILE_RANGE",
      title = "Invalid Percentile Range",
      problem = sprintf("lower_pct (%s) must be less than upper_pct (%s)", lower_pct, upper_pct),
      why_it_matters = "Two-sided trimming requires a valid range with the lower bound below the upper bound",
      how_to_fix = "Ensure lower_pct < upper_pct (e.g., lower_pct = 0.01, upper_pct = 0.99)"
    )
  }

  if (lower_pct <= 0 || upper_pct >= 1) {
    weighting_refuse(
      code = "CFG_PERCENTILE_OUT_OF_BOUNDS",
      title = "Percentiles Out of Bounds",
      problem = sprintf("Percentiles must be in range (0, 1), but got lower_pct = %s, upper_pct = %s", lower_pct, upper_pct),
      why_it_matters = "Percentiles at exactly 0 or 1 would trim all or no weights, defeating the purpose of two-sided trimming",
      how_to_fix = "Use percentiles strictly between 0 and 1 (e.g., lower_pct = 0.01, upper_pct = 0.99)"
    )
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
#' Uses survey::calibrate() with built-in weight bounds.
#'
#' @param data Data frame, survey data
#' @param target_list Named list of rim targets
#' @param cap Numeric, maximum weight (upper bound)
#' @param max_outer_iterations Integer, max trimming iterations (unused, kept for API compatibility)
#' @param verbose Logical, print progress
#' @return List with final weights and iteration details
#' @export
iterative_rim_trim <- function(data,
                               target_list,
                               cap,
                               max_outer_iterations = 5,
                               verbose = FALSE) {

  if (verbose) {
    message("\nIterative rim weighting with trimming...")
    message("  Cap: ", cap)
  }

  # survey::calibrate() handles weight bounds during calibration
  # No need for iterative trim-and-rerake with this approach
  result <- calculate_rim_weights(
    data = data,
    target_list = target_list,
    cap_weights = cap,  # Fixed: was 'cap', now 'cap_weights'
    verbose = verbose
  )

  return(result)
}
