# ==============================================================================
# TurasTracker - Trend Significance Testing Functions
# ==============================================================================
#
# Significance testing functions for trend calculations across survey waves.
# Extracted from trend_calculator.R for better maintainability and modularity.
#
# VERSION: 1.0.0
# EXTRACTED FROM: trend_calculator.R (lines 1180-2936)
# DATE: 2025-12-27
#
# DEPENDENCIES:
#   This file requires the following to be sourced BEFORE loading:
#   - lib/statistical_core.R (for t_test_for_means, z_test_for_proportions, DEFAULT_ALPHA)
#   - lib/constants.R (for DEFAULT_MINIMUM_BASE)
#   - lib/tracker_config_loader.R (for get_setting)
#
# FUNCTIONS:
#   - perform_significance_tests_means()
#   - perform_significance_tests_proportions()
#   - perform_significance_tests_nps()
#   - perform_significance_tests_for_metric()
#   - perform_significance_tests_multi_mention()
#   - perform_significance_tests_multi_mention_metric()
#
# NOTES:
#   - All functions use effective N (eff_n) instead of unweighted N to properly
#     account for design effects from weighting
#   - Does NOT duplicate t_test_for_means or z_test_for_proportions - these
#     should come from statistical_core.R
# ==============================================================================


#' Perform Significance Tests for Means
#'
#' SHARED CODE NOTE: T-test logic should be in /shared/significance_tests.R
#' This is identical to TurasTabs t-test implementation
#'
#' NOTE: Uses effective N (eff_n) instead of unweighted N to properly account
#' for design effects from weighting. This provides more accurate p-values when
#' weights vary substantially across respondents.
#'
#' @keywords internal
perform_significance_tests_means <- function(wave_results, wave_ids, config) {

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  min_base <- get_setting(config, "minimum_base", default = DEFAULT_MINIMUM_BASE)

  sig_tests <- list()

  # Test consecutive waves
  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    # Check if both available and have sufficient base (using effective N)
    if (current$available && previous$available &&
        current_eff_n >= min_base && previous_eff_n >= min_base) {

      # Two-sample t-test for means (using effective N)
      # SHARED CODE NOTE: Extract to shared/significance_tests.R::t_test_means()
      t_result <- t_test_for_means(
        mean1 = previous$mean,
        sd1 = previous$sd,
        n1 = previous_eff_n,
        mean2 = current$mean,
        sd2 = current$sd,
        n2 = current_eff_n,
        alpha = alpha
      )

      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- t_result
    } else {
      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
        significant = FALSE,
        reason = "insufficient_base_or_unavailable"
      )
    }
  }

  return(sig_tests)
}


#' Perform Significance Tests for Proportions
#'
#' SHARED CODE NOTE: Z-test logic should be in /shared/significance_tests.R
#'
#' NOTE: Uses effective N (eff_n) instead of unweighted N to properly account
#' for design effects from weighting. This provides more accurate p-values when
#' weights vary substantially across respondents.
#'
#' @keywords internal
perform_significance_tests_proportions <- function(wave_results, wave_ids, config, response_code) {

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  min_base <- get_setting(config, "minimum_base", default = DEFAULT_MINIMUM_BASE)

  sig_tests <- list()

  # Test consecutive waves
  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    if (current$available && previous$available &&
        current_eff_n >= min_base && previous_eff_n >= min_base) {

      # Get proportions for this response code
      response_code_str <- as.character(response_code)

      # Check if response code exists in both waves
      if (!is.null(previous$proportions) && response_code_str %in% names(previous$proportions) &&
          !is.null(current$proportions) && response_code_str %in% names(current$proportions)) {

        p1 <- previous$proportions[[response_code_str]] / 100  # Convert to proportion
        p2 <- current$proportions[[response_code_str]] / 100

        # Z-test for proportions (using effective N)
        # SHARED CODE NOTE: Extract to shared/significance_tests.R::z_test_proportions()
        z_result <- z_test_for_proportions(
          p1 = p1,
          n1 = previous_eff_n,
          p2 = p2,
          n2 = current_eff_n,
          alpha = alpha
        )

        sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- z_result
      } else {
        sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
          significant = FALSE,
          reason = "response_code_not_found"
        )
      }
    } else {
      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
        significant = FALSE,
        reason = "insufficient_base_or_unavailable"
      )
    }
  }

  return(sig_tests)
}


#' Perform Significance Tests for NPS
#'
#' NOTE: Uses effective N (eff_n) instead of unweighted N to properly account
#' for design effects from weighting.
#'
#' @keywords internal
perform_significance_tests_nps <- function(wave_results, wave_ids, config) {

  # NPS is a difference of proportions, so we test the NPS score directly
  # This is a simplified approach for MVT
  # Could be enhanced with proper proportion difference testing

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  min_base <- get_setting(config, "minimum_base", default = DEFAULT_MINIMUM_BASE)

  sig_tests <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    if (current$available && previous$available &&
        current_eff_n >= min_base && previous_eff_n >= min_base) {

      # Calculate z-test for NPS difference
      # NPS is on -100 to +100 scale, convert to proportion scale (0-1)
      nps_diff <- current$nps - previous$nps

      # Approximate standard error for NPS difference (using effective N)
      # Using conservative estimate: SE = sqrt((100^2 / n1) + (100^2 / n2))
      # This assumes worst-case variance for NPS scale
      se_nps <- sqrt((10000 / current_eff_n) + (10000 / previous_eff_n))

      # Calculate z-statistic
      z_stat <- abs(nps_diff) / se_nps

      # Critical value for two-tailed test (e.g., 1.96 for 95% confidence)
      z_critical <- qnorm(1 - alpha/2)

      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
        significant = z_stat > z_critical,
        nps_difference = nps_diff,
        z_statistic = z_stat,
        p_value = 2 * (1 - pnorm(abs(z_stat))),
        note = "Z-test for NPS difference (conservative SE estimate, uses effective N)"
      )
    } else {
      sig_tests[[paste0(prev_wave_id, "_vs_", wave_id)]] <- list(
        significant = FALSE,
        reason = "insufficient_base_or_unavailable"
      )
    }
  }

  return(sig_tests)
}


#' Perform Significance Tests for Enhanced Metric
#'
#' Performs significance testing for proportion-based metrics (top_box, range, etc.).
#'
#' NOTE: Uses effective N (eff_n) instead of unweighted N to properly account
#' for design effects from weighting.
#'
#' @keywords internal
perform_significance_tests_for_metric <- function(wave_results, wave_ids, metric_name,
                                                   config, test_type = "proportion") {

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  sig_tests <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Check availability
    if (!current$available || !previous$available) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    # Get metric values
    current_val <- current$metrics[[metric_name]]
    previous_val <- previous$metrics[[metric_name]]

    if (is.na(current_val) || is.na(previous_val)) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    # Perform test based on type
    if (test_type == "proportion") {
      # Convert percentages to proportions
      p1 <- previous_val / 100
      p2 <- current_val / 100

      test_result <- z_test_for_proportions(p1, previous_eff_n, p2, current_eff_n, alpha)
    } else {
      # Would use t-test for means, but this function is for proportions
      test_result <- NA
    }

    sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- test_result
  }

  return(sig_tests)
}


#' Perform Significance Tests for Multi-Mention Option
#'
#' Uses z-test for proportions (same as single-choice questions).
#'
#' NOTE: Uses effective N (eff_n) instead of unweighted N to properly account
#' for design effects from weighting.
#'
#' @keywords internal
perform_significance_tests_multi_mention <- function(wave_results, wave_ids, column_name, config) {

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  sig_tests <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    if (!current$available || !previous$available) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    current_val <- current$mention_proportions[[column_name]]
    previous_val <- previous$mention_proportions[[column_name]]

    if (is.na(current_val) || is.na(previous_val)) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    # Convert percentages to proportions
    p1 <- previous_val / 100
    p2 <- current_val / 100

    test_result <- z_test_for_proportions(p1, previous_eff_n, p2, current_eff_n, alpha)
    sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- test_result
  }

  return(sig_tests)
}


#' Perform Significance Tests for Multi-Mention Additional Metric
#'
#' @keywords internal
perform_significance_tests_multi_mention_metric <- function(wave_results, wave_ids, metric_name, config) {

  alpha <- get_setting(config, "alpha", default = DEFAULT_ALPHA)
  sig_tests <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    if (!current$available || !previous$available) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    current_val <- current$additional_metrics[[metric_name]]
    previous_val <- previous$additional_metrics[[metric_name]]

    if (is.na(current_val) || is.na(previous_val)) {
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
      next
    }

    # Get effective N (or fall back to n_unweighted if eff_n not available)
    current_eff_n <- if (!is.null(current$eff_n)) current$eff_n else current$n_unweighted
    previous_eff_n <- if (!is.null(previous$eff_n)) previous$eff_n else previous$n_unweighted

    # For "any" metric, use z-test for proportions (using effective N)
    # For "count_mean", use t-test (but need raw values - skip for now)
    if (metric_name == "any_mention_pct") {
      p1 <- previous_val / 100
      p2 <- current_val / 100

      test_result <- z_test_for_proportions(p1, previous_eff_n, p2, current_eff_n, alpha)
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- test_result
    } else {
      # For count_mean, we'd need the raw count values for t-test
      # Skip significance testing for now
      sig_tests[[paste0(prev_wave_id, "_to_", wave_id)]] <- NA
    }
  }

  return(sig_tests)
}
