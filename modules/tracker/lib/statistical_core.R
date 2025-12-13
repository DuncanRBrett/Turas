# ==============================================================================
# TurasTracker - Statistical Core Functions
# ==============================================================================
#
# Core statistical calculations used by trend calculator.
# Extracted for clarity and potential reuse.
#
# VERSION: 1.0.0
# EXTRACTED FROM: trend_calculator.R
# ==============================================================================

# Default significance level
DEFAULT_ALPHA <- 0.05

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
  pooled_var <- ((n1 - 1) * sd1^2 + (n2 - 1) * sd2^2) / (n1 + n2 - 2)
  pooled_sd <- sqrt(pooled_var)
  se <- pooled_sd * sqrt(1/n1 + 1/n2)
  t_stat <- (mean2 - mean1) / se
  df <- n1 + n2 - 2
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
  p_pooled <- (p1 * n1 + p2 * n2) / (n1 + n2)
  se <- sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))

  if (se == 0) {
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
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
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
      ci_upper = NA
    ))
  }

  w_mean <- sum(values_valid * weights_valid) / n_weighted
  w_var <- sum(weights_valid * (values_valid - w_mean)^2) / n_weighted
  w_sd <- sqrt(w_var)
  se <- w_sd / sqrt(n_unweighted)
  ci_lower <- w_mean - 1.96 * se
  ci_upper <- w_mean + 1.96 * se

  list(
    mean = w_mean,
    sd = w_sd,
    n_unweighted = n_unweighted,
    n_weighted = n_weighted,
    ci_lower = ci_lower,
    ci_upper = ci_upper
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
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  n_unweighted <- length(values_valid)
  n_weighted <- sum(weights_valid)

  if (n_unweighted == 0) {
    return(list(
      nps = NA, promoters_pct = NA, passives_pct = NA, detractors_pct = NA,
      n_unweighted = 0, n_weighted = 0,
      n_promoters = 0, n_passives = 0, n_detractors = 0
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

  list(
    nps = nps,
    promoters_pct = promoters_pct,
    passives_pct = passives_pct,
    detractors_pct = detractors_pct,
    n_unweighted = n_unweighted,
    n_weighted = n_weighted,
    n_promoters = length(promoters),
    n_passives = length(passives),
    n_detractors = length(detractors)
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
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  total_weight <- sum(weights_valid)

  if (is.null(codes)) {
    codes <- unique(values_valid)
  }

  results <- data.frame(
    code = character(),
    proportion = numeric(),
    n_unweighted = integer(),
    n_weighted = numeric(),
    stringsAsFactors = FALSE
  )

  for (code in codes) {
    mask <- values_valid == code
    code_weights <- weights_valid[mask]
    n_unwt <- sum(mask)
    n_wt <- sum(code_weights)
    prop <- if (total_weight > 0) (n_wt / total_weight) * 100 else 0

    results <- rbind(results, data.frame(
      code = as.character(code),
      proportion = prop,
      n_unweighted = n_unwt,
      n_weighted = n_wt,
      stringsAsFactors = FALSE
    ))
  }

  results
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
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  total_weight <- sum(weights_valid)
  unique_vals <- sort(unique(values_valid))

  results <- data.frame(
    value = unique_vals,
    count = sapply(unique_vals, function(v) sum(weights_valid[values_valid == v])),
    stringsAsFactors = FALSE
  )

  results$proportion <- if (total_weight > 0) results$count / total_weight * 100 else 0
  results
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
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(proportion = NA, scale_detected = NA, top_values = NA,
                n_unweighted = 0, n_weighted = 0))
  }

  unique_values <- sort(unique(values_valid))
  scale_max <- max(unique_values)
  top_values <- tail(unique_values, n_boxes)

  top_mask <- values_valid %in% top_values
  top_weights <- weights_valid[top_mask]
  total_weight <- sum(weights_valid)
  proportion <- sum(top_weights) / total_weight * 100

  list(
    proportion = proportion,
    scale_detected = paste0("1-", scale_max),
    top_values = top_values,
    n_unweighted = sum(top_mask),
    n_weighted = sum(top_weights)
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
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(proportion = NA, scale_detected = NA, bottom_values = NA,
                n_unweighted = 0, n_weighted = 0))
  }

  unique_values <- sort(unique(values_valid))
  scale_max <- max(unique_values)
  bottom_values <- head(unique_values, n_boxes)

  bottom_mask <- values_valid %in% bottom_values
  bottom_weights <- weights_valid[bottom_mask]
  total_weight <- sum(weights_valid)
  proportion <- sum(bottom_weights) / total_weight * 100

  list(
    proportion = proportion,
    scale_detected = paste0("1-", scale_max),
    bottom_values = bottom_values,
    n_unweighted = sum(bottom_mask),
    n_weighted = sum(bottom_weights)
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
  valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(proportion = NA, range_spec = range_spec, range_values = NA,
                n_unweighted = 0, n_weighted = 0))
  }

  # Parse range specification
  range_parts <- strsplit(range_spec, "-")[[1]]
  if (length(range_parts) != 2) {
    warning(paste("Invalid range specification:", range_spec))
    return(list(proportion = NA, range_spec = range_spec, range_values = NA,
                n_unweighted = 0, n_weighted = 0))
  }

  range_min <- as.numeric(range_parts[1])
  range_max <- as.numeric(range_parts[2])

  if (is.na(range_min) || is.na(range_max)) {
    warning(paste("Invalid range specification:", range_spec))
    return(list(proportion = NA, range_spec = range_spec, range_values = NA,
                n_unweighted = 0, n_weighted = 0))
  }

  range_values <- seq(range_min, range_max)
  range_mask <- values_valid >= range_min & values_valid <= range_max
  range_weights <- weights_valid[range_mask]
  total_weight <- sum(weights_valid)
  proportion <- sum(range_weights) / total_weight * 100

  list(
    proportion = proportion,
    range_spec = range_spec,
    range_values = range_values,
    n_unweighted = sum(range_mask),
    n_weighted = sum(range_weights)
  )
}
