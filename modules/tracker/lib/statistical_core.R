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
#' The CI uses the same alpha as the significance tests so a tracker
#' configured at p<0.10 produces 90% CIs (not 95%). Previously the
#' critical value was hardcoded to 1.96, which silently disagreed with
#' the configured alpha whenever the latter was anything other than 0.05.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @param alpha Numeric. Significance level for the CI critical value.
#'   Default `DEFAULT_ALPHA` (0.05 → 95% CI). Pass the tracker's
#'   `alpha` setting to keep CIs consistent with the sig tests.
#' @return List with mean, sd, n_unweighted, n_weighted, ci_lower, ci_upper
#' @keywords internal
calculate_weighted_mean <- function(values, weights, alpha = DEFAULT_ALPHA) {
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

  # Effective N (design-effect adjusted sample size)
  sum_weights_squared <- sum(weights_valid^2)
  eff_n <- if (sum_weights_squared > 0) {
    (n_weighted^2) / sum_weights_squared
  } else {
    0
  }

  # Unbiased SD for reliability (survey) weights: the weighted variance times
  # n_eff / (n_eff - 1). Equals sd() when every weight is 1, is unchanged by
  # grossing, matches stats::cov.wt(method = "unbiased") and the tabs v2
  # renderer's sdOfScores(). Undefined when one respondent carries all the
  # weight (n_eff = 1).
  w_var <- sum(weights_valid * (values_valid - w_mean)^2) / n_weighted
  w_sd <- if (eff_n > 1) sqrt(w_var * eff_n / (eff_n - 1)) else NA_real_

  # Use effective sample size for SE to correctly account for weighting design effect
  se <- if (eff_n > 0) w_sd / sqrt(eff_n) else NA
  # Critical value derived from alpha so the CI agrees with the sig-test threshold.
  # alpha = 0.05 reproduces the historical 1.96 multiplier exactly.
  z_crit <- qnorm(1 - alpha / 2)
  ci_lower <- w_mean - z_crit * se
  ci_upper <- w_mean + z_crit * se

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

#' Refuse a Top / Bottom Box With No Defined Scale
#'
#' @keywords internal
refuse_box_without_scale <- function(which_box) {
  tracker_refuse(
    code = "CFG_BOX_SCALE_UNKNOWN",
    title = "Top / Bottom Box Has No Scale",
    problem = paste0(which_box, " needs the question's scale, and none is defined."),
    why_it_matters = paste0(
      "Reading the scale from the answers makes 'top box' mean the highest ",
      "point anyone chose in that wave, so two waves can compare different points."),
    how_to_fix = c(
      "Add a StructureFile to the Waves sheet whose Options give each scale point an Index_Weight",
      "Or name the box directly, for example range:4-5 for top 2 of a 1-5 scale"
    )
  )
}


#' Calculate Top Box
#'
#' Calculates percentage of responses in the top N points of the question's
#' scale. The scale comes from the Survey_Structure (Index_Weight), never from
#' the answers: a wave where nobody chose the top point reports 0%.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @param n_boxes Integer, number of top scale points (1, 2, or 3)
#' @param scale_values Numeric vector. Every point on the question's scale.
#'   Refused (CFG_BOX_SCALE_UNKNOWN) when missing.
#' @return List with proportion, scale_detected, top_values, n_*
#' @keywords internal
calculate_top_box <- function(values, weights, n_boxes = 1, scale_values = NULL) {
  calculate_scale_box(values, weights, n_boxes, scale_values, top = TRUE)
}


#' Calculate Bottom Box
#'
#' Bottom N points of the question's scale; see calculate_top_box().
#'
#' @inheritParams calculate_top_box
#' @return List with proportion, scale_detected, bottom_values, n_*
#' @keywords internal
calculate_bottom_box <- function(values, weights, n_boxes = 1, scale_values = NULL) {
  calculate_scale_box(values, weights, n_boxes, scale_values, top = FALSE)
}


#' Shared Top / Bottom Box Calculation
#'
#' The base is every non-missing answer. Options the structure flags
#' ExcludeFromIndex = Y (don't know) were set to NA upstream by
#' resolve_question_values(), so they are in neither the box nor the base.
#'
#' @keywords internal
calculate_scale_box <- function(values, weights, n_boxes, scale_values, top) {
  box_label <- paste0(if (top) "top" else "bottom", if (n_boxes > 1) n_boxes else "", "_box")
  scale_points <- sort(unique(suppressWarnings(as.numeric(scale_values))))
  scale_points <- scale_points[!is.na(scale_points)]
  if (length(scale_points) == 0) refuse_box_without_scale(box_label)

  n_boxes <- min(n_boxes, length(scale_points))
  box_values <- if (top) tail(scale_points, n_boxes) else head(scale_points, n_boxes)
  scale_text <- paste0(min(scale_points), "-", max(scale_points))
  values_name <- if (top) "top_values" else "bottom_values"

  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  total_weight <- sum(weights_valid)
  proportion <- if (length(values_valid) == 0) NA else
    sum(weights_valid[which(values_valid %in% box_values)]) / total_weight * 100

  result <- list(
    proportion = proportion,
    scale_detected = scale_text,
    n_unweighted = length(values_valid),
    n_weighted = total_weight
  )
  result[[values_name]] <- box_values
  result
}


#' Calculate Custom Range
#'
#' Calculates percentage of responses within a custom value range.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights
#' @param range_spec Character, range specification (e.g., "1-3", "4-5")
#' @return List with proportion, range_values (the inclusive bounds), n_*
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

  # Inclusive interval, not a list of integers: a composite score of 4.5 and
  # a half-point bound such as 3.5-5 both count correctly.
  range_values <- c(range_min, range_max)

  valid_idx <- which(!is.na(values) & !is.na(weights) & weights > 0)
  values_valid <- values[valid_idx]
  weights_valid <- weights[valid_idx]

  if (length(values_valid) == 0) {
    return(list(proportion = NA, range_spec = range_spec, range_values = range_values,
                n_unweighted = 0, n_weighted = 0))
  }

  in_range <- values_valid >= range_min & values_valid <= range_max
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
