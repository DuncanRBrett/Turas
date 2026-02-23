# ==============================================================================
# TurasTracker - Statistical Core Functions (SINGLE SOURCE OF TRUTH)
# ==============================================================================
#
# Canonical definitions for all core statistical calculations used by the
# tracker module. All calculation functions are defined here and nowhere else.
#
# Functions:
#   - is_significant()          Safe significance check
#   - normalize_question_type() Type mapping (TurasTabs/legacy -> internal)
#   - t_test_for_means()        Pooled two-sample t-test from summary stats
#   - z_test_for_proportions()  Two-sample z-test for proportions
#   - calculate_weighted_mean() Weighted mean with SD, CI, and eff_n
#   - calculate_nps_score()     Net Promoter Score with eff_n
#   - calculate_proportions()   Weighted proportions (named vector + eff_n)
#   - calculate_distribution()  Full distribution (named list of percentages)
#   - calculate_top_box()       Top-N box percentage
#   - calculate_bottom_box()    Bottom-N box percentage
#   - calculate_custom_range()  Custom value range percentage
#
# SOURCED BY: run_tracker.R (line 76, before trend_calculator.R)
# VERSION: 2.0.0
# ==============================================================================

# Default significance level - defined in constants.R (single source of truth)
# Do NOT redefine DEFAULT_ALPHA here; use the value from constants.R
if (!exists("DEFAULT_ALPHA")) DEFAULT_ALPHA <- 0.05

#' Check if Significance Test Result is Significant
#'
#' Safe helper function to check if a significance test result indicates significance.
#' Handles NULL, NA, and missing values gracefully.
#'
#' @param sig_test Significance test result object (may be NULL or have $significant field)
#' @return Logical. TRUE if test is significant, FALSE otherwise
#' @keywords internal
is_significant <- function(sig_test) {
  return(isTRUE(!is.null(sig_test) &&
                !is.na(sig_test$significant) &&
                sig_test$significant))
}

#' Normalize Question Type
#'
#' Maps question types to standardized internal types.
#' Supports both TurasTabs and legacy TurasTracker naming conventions.
#'
#' @param q_type Character, raw question type
#' @return Character, normalized type
#' @keywords internal
normalize_question_type <- function(q_type) {
  # Guard against NULL/NA/empty input
  if (is.null(q_type) || is.na(q_type) || trimws(as.character(q_type)) == "") {
    return(NA_character_)
  }

  type_map <- c(
    "Single_Response" = "single_choice",
    "SingleChoice" = "single_choice",
    "Multi_Mention" = "multi_choice",
    "MultiChoice" = "multi_choice",
    "Rating" = "rating",
    "Likert" = "rating",
    "NPS" = "nps",
    "Index" = "rating",
    "Numeric" = "rating",
    "Open_End" = "open_end",
    "OpenEnd" = "open_end",
    "Ranking" = "ranking",
    "Composite" = "composite"
  )

  normalized <- type_map[q_type]
  if (is.na(normalized)) {
    return(tolower(q_type))
  }
  return(as.character(normalized))
}

#' T-Test for Means
#'
#' Two-sample t-test for comparing means using summary statistics.
#'
#' @param mean1 Numeric, mean of first sample
#' @param sd1 Numeric, standard deviation of first sample
#' @param n1 Integer, sample size of first sample
#' @param mean2 Numeric, mean of second sample
#' @param sd2 Numeric, standard deviation of second sample
#' @param n2 Integer, sample size of second sample
#' @param alpha Numeric, significance level (default: 0.05)
#' @return List with t_stat, df, p_value, significant, alpha
#' @keywords internal
t_test_for_means <- function(mean1, sd1, n1, mean2, sd2, n2, alpha = DEFAULT_ALPHA) {
  # Guard against insufficient sample sizes for pooled t-test
  # Need at least 2 observations in each group (df = n1 + n2 - 2 > 0)
  df <- n1 + n2 - 2
  if (df <= 0) {
    return(list(
      t_stat = NA_real_,
      df = df,
      p_value = NA_real_,
      significant = FALSE,
      alpha = alpha,
      error = "Insufficient sample size: need at least 2 observations per group for pooled t-test"
    ))
  }

  # Guard against zero sample sizes which would cause division by zero

  if (n1 <= 0 || n2 <= 0) {
    return(list(
      t_stat = NA_real_,
      df = df,
      p_value = NA_real_,
      significant = FALSE,
      alpha = alpha,
      error = "Sample sizes must be positive"
    ))
  }

  pooled_var <- ((n1 - 1) * sd1^2 + (n2 - 1) * sd2^2) / df
  pooled_sd <- sqrt(pooled_var)
  se <- pooled_sd * sqrt(1/n1 + 1/n2)

  # Guard against zero standard error
  if (is.na(se) || se == 0) {
    return(list(
      t_stat = NA_real_,
      df = df,
      p_value = NA_real_,
      significant = FALSE,
      alpha = alpha,
      error = "Cannot calculate t-statistic: standard error is zero"
    ))
  }

  t_stat <- (mean2 - mean1) / se
  p_value <- 2 * pt(-abs(t_stat), df)
  significant <- p_value < alpha

  list(
    t_stat = t_stat,
    df = df,
    p_value = p_value,
    significant = significant,
    alpha = alpha
  )
}

#' Z-Test for Proportions
#'
#' Two-sample z-test for comparing proportions.
#'
#' @param p1 Numeric, proportion in first sample (0-1 scale)
#' @param n1 Integer, sample size of first sample
#' @param p2 Numeric, proportion in second sample (0-1 scale)
#' @param n2 Integer, sample size of second sample
#' @param alpha Numeric, significance level (default: 0.05)
#' @return List with z_stat, p_value, significant, alpha
#' @keywords internal
z_test_for_proportions <- function(p1, n1, p2, n2, alpha = DEFAULT_ALPHA) {
  # Guard against zero or negative sample sizes (prevents division by zero)
  if (n1 <= 0 || n2 <= 0) {
    return(list(
      z_stat = NA_real_,
      p_value = NA_real_,
      significant = FALSE,
      alpha = alpha,
      error = "Sample sizes must be positive"
    ))
  }

  p_pooled <- (p1 * n1 + p2 * n2) / (n1 + n2)
  se <- sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))

  # Guard against NaN (e.g. p_pooled outside 0-1) or zero standard error
  if (is.na(se) || is.nan(se) || se == 0) {
    return(list(z_stat = 0, p_value = 1, significant = FALSE, alpha = alpha))
  }

  z_stat <- (p2 - p1) / se
  p_value <- 2 * pnorm(-abs(z_stat))
  significant <- p_value < alpha

  list(
    z_stat = z_stat,
    p_value = p_value,
    significant = significant,
    alpha = alpha
  )
}

#' Calculate Weighted Mean
#'
#' Calculates weighted mean with standard deviation and confidence interval.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @return List with mean, sd, n_unweighted, n_weighted, ci_lower, ci_upper
#' @keywords internal
calculate_weighted_mean <- function(values, weights) {
  # Guard: non-numeric values cannot be averaged
  # Note: c(NA, NA) is logical in R, so only refuse if non-NA values exist and aren't numeric
  non_na_values <- values[!is.na(values)]
  if (length(non_na_values) > 0 && !is.numeric(non_na_values)) {
    sample_values <- head(unique(non_na_values), 5)
    return(tracker_refuse(
      code = "DATA_NON_NUMERIC_VALUES",
      title = "Non-Numeric Data Detected",
      problem = "Expected numeric responses but found text values.",
      why_it_matters = "Weighted mean calculation requires numeric data.",
      how_to_fix = c(
        "Check that the data file has numeric values for this question",
        "Verify question type is configured correctly"
      ),
      details = paste0("Sample values found: ", paste(sample_values, collapse = ", "))
    ))
  }

  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  n_unweighted <- length(values_valid)
  n_weighted <- sum(weights_valid)

  if (n_unweighted < 2) {
    return(list(
      mean = if (n_unweighted == 1) values_valid[1] else NA,
      sd = NA,
      n_unweighted = n_unweighted,
      n_weighted = n_weighted,
      ci_lower = NA,
      ci_upper = NA,
      eff_n = if (n_unweighted == 1) 1 else 0
    ))
  }

  w_mean <- sum(values_valid * weights_valid) / n_weighted
  w_var <- sum(weights_valid * (values_valid - w_mean)^2) / n_weighted
  w_sd <- sqrt(w_var)
  se <- w_sd / sqrt(n_unweighted)
  ci_lower <- w_mean - 1.96 * se
  ci_upper <- w_mean + 1.96 * se

  # Effective N (design-effect adjusted sample size)
  sum_weights_squared <- sum(weights_valid^2)
  eff_n <- if (sum_weights_squared > 0) {
    (n_weighted^2) / sum_weights_squared
  } else {
    0
  }

  list(
    mean = w_mean,
    sd = w_sd,
    n_unweighted = n_unweighted,
    n_weighted = n_weighted,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    eff_n = eff_n
  )
}

#' Calculate NPS Score
#'
#' Calculates Net Promoter Score from 0-10 scale responses.
#'
#' @param values Numeric vector of response values (0-10)
#' @param weights Numeric vector of weights
#' @return List with nps, promoters_pct, passives_pct, detractors_pct, n_*
#' @keywords internal
calculate_nps_score <- function(values, weights) {
  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  n_unweighted <- length(values_valid)
  n_weighted <- sum(weights_valid)

  if (n_unweighted == 0) {
    return(list(
      nps = NA, promoters_pct = NA, passives_pct = NA, detractors_pct = NA,
      n_unweighted = 0, n_weighted = 0,
      n_promoters = 0, n_passives = 0, n_detractors = 0,
      eff_n = 0
    ))
  }

  # NPS categories: Detractors (0-6), Passives (7-8), Promoters (9-10)
  promoters <- weights_valid[values_valid >= 9]
  passives <- weights_valid[values_valid >= 7 & values_valid <= 8]
  detractors <- weights_valid[values_valid <= 6]

  promoters_pct <- sum(promoters) / n_weighted * 100
  passives_pct <- sum(passives) / n_weighted * 100
  detractors_pct <- sum(detractors) / n_weighted * 100
  nps <- promoters_pct - detractors_pct

  # Effective N (design-effect adjusted sample size)
  sum_weights_squared <- sum(weights_valid^2)
  eff_n <- if (sum_weights_squared > 0) {
    (n_weighted^2) / sum_weights_squared
  } else {
    0
  }

  list(
    nps = nps,
    promoters_pct = promoters_pct,
    passives_pct = passives_pct,
    detractors_pct = detractors_pct,
    n_unweighted = n_unweighted,
    n_weighted = n_weighted,
    n_promoters = length(promoters),
    n_passives = length(passives),
    n_detractors = length(detractors),
    eff_n = eff_n
  )
}

#' Calculate Proportions
#'
#' Calculates weighted proportions for categorical responses.
#'
#' @param values Vector of categorical values
#' @param weights Numeric vector of weights
#' @param codes Vector of codes to calculate proportions for (NULL = all)
#' @return Data frame with code, proportion, n_unweighted, n_weighted
#' @keywords internal
calculate_proportions <- function(values, weights, codes = NULL) {
  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (is.null(codes)) {
    codes <- unique(values_valid)
  }

  n_unweighted <- length(values_valid)
  n_weighted <- sum(weights_valid)

  if (n_unweighted == 0) {
    return(list(
      proportions = setNames(rep(NA_real_, length(codes)), as.character(codes)),
      n_unweighted = 0,
      n_weighted = 0,
      eff_n = 0
    ))
  }

  total_weight <- sum(weights_valid)

  # Calculate proportion for each code (as named numeric vector, 0-100 scale)
  proportions <- sapply(codes, function(code) {
    matched_idx <- which(values_valid == code)
    code_weight <- sum(weights_valid[matched_idx], na.rm = TRUE)
    (code_weight / total_weight) * 100
  })
  names(proportions) <- as.character(codes)

  # Effective N (design-effect adjusted sample size)
  sum_weights_squared <- sum(weights_valid^2)
  eff_n <- if (sum_weights_squared > 0) {
    (n_weighted^2) / sum_weights_squared
  } else {
    0
  }

  list(
    proportions = proportions,
    n_unweighted = n_unweighted,
    n_weighted = n_weighted,
    eff_n = eff_n
  )
}

#' Calculate Distribution
#'
#' Calculates full distribution of weighted values.
#'
#' @param values Numeric or character vector
#' @param weights Numeric vector of weights
#' @return Data frame with value, count, proportion
#' @keywords internal
calculate_distribution <- function(values, weights) {
  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  n_unweighted <- length(values_valid)
  n_weighted <- sum(weights_valid)

  if (n_unweighted == 0) {
    return(list(
      distribution = list(),
      n_unweighted = 0,
      n_weighted = 0
    ))
  }

  # Build named list: value -> percentage (0-100 scale)
  unique_vals <- sort(unique(values_valid))
  total_weight <- sum(weights_valid)

  distribution <- list()
  for (val in unique_vals) {
    matched_idx <- which(values_valid == val)
    val_weight <- sum(weights_valid[matched_idx])
    distribution[[as.character(val)]] <- (val_weight / total_weight) * 100
  }

  list(
    distribution = distribution,
    n_unweighted = n_unweighted,
    n_weighted = n_weighted
  )
}

#' Calculate Top Box
#'
#' Calculates percentage of responses in top N values of scale.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @param n_boxes Integer, number of top values (1, 2, or 3)
#' @return List with proportion, scale_detected, top_values, n_*
#' @keywords internal
calculate_top_box <- function(values, weights, n_boxes = 1) {
  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(proportion = NA, scale_detected = NA, top_values = NA,
                n_unweighted = 0, n_weighted = 0))
  }

  unique_values <- sort(unique(values_valid))
  scale_min <- min(unique_values)
  scale_max <- max(unique_values)
  n_boxes <- min(n_boxes, length(unique_values))
  top_values <- tail(unique_values, n_boxes)

  in_top_box <- values_valid %in% top_values
  top_weight <- sum(weights_valid[which(in_top_box)])
  total_weight <- sum(weights_valid)
  proportion <- (top_weight / total_weight) * 100

  list(
    proportion = proportion,
    scale_detected = paste0(scale_min, "-", scale_max),
    top_values = top_values,
    n_unweighted = length(values_valid),
    n_weighted = total_weight
  )
}

#' Calculate Bottom Box
#'
#' Calculates percentage of responses in bottom N values of scale.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @param n_boxes Integer, number of bottom values (1, 2, or 3)
#' @return List with proportion, scale_detected, bottom_values, n_*
#' @keywords internal
calculate_bottom_box <- function(values, weights, n_boxes = 1) {
  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(proportion = NA, scale_detected = NA, bottom_values = NA,
                n_unweighted = 0, n_weighted = 0))
  }

  unique_values <- sort(unique(values_valid))
  scale_min <- min(unique_values)
  scale_max <- max(unique_values)
  n_boxes <- min(n_boxes, length(unique_values))
  bottom_values <- head(unique_values, n_boxes)

  in_bottom_box <- values_valid %in% bottom_values
  bottom_weight <- sum(weights_valid[which(in_bottom_box)])
  total_weight <- sum(weights_valid)
  proportion <- (bottom_weight / total_weight) * 100

  list(
    proportion = proportion,
    scale_detected = paste0(scale_min, "-", scale_max),
    bottom_values = bottom_values,
    n_unweighted = length(values_valid),
    n_weighted = total_weight
  )
}

#' Calculate Custom Range
#'
#' Calculates percentage of responses within a custom value range.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @param range_spec Character, range specification (e.g., "1-3", "4-5")
#' @return List with proportion, range_values, n_*
#' @keywords internal
calculate_custom_range <- function(values, weights, range_spec) {
  # Strip optional "range:" prefix (supports both "4-5" and "range:4-5")
  range_str <- sub("^range:", "", tolower(range_spec))

  # Parse range specification
  range_parts <- strsplit(range_str, "-")[[1]]
  if (length(range_parts) != 2) {
    cat("[WARNING]", paste("Invalid range specification:", range_spec), "\n")
    return(list(proportion = NA, range_spec = range_spec, range_values = NA,
                n_unweighted = 0, n_weighted = 0))
  }

  range_min <- as.numeric(range_parts[1])
  range_max <- as.numeric(range_parts[2])

  if (is.na(range_min) || is.na(range_max) || range_min > range_max) {
    cat("[WARNING]", paste("Invalid range specification:", range_spec), "\n")
    return(list(proportion = NA, range_spec = range_spec, range_values = NA,
                n_unweighted = 0, n_weighted = 0))
  }

  range_values <- seq(range_min, range_max)

  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(proportion = NA, range_spec = range_spec, range_values = range_values,
                n_unweighted = 0, n_weighted = 0))
  }

  in_range <- values_valid %in% range_values
  range_weight <- sum(weights_valid[which(in_range)])
  total_weight <- sum(weights_valid)
  proportion <- (range_weight / total_weight) * 100

  list(
    proportion = proportion,
    range_spec = range_spec,
    range_values = range_values,
    n_unweighted = length(values_valid),
    n_weighted = total_weight
  )
}
