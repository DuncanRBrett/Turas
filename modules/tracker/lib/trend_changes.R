# ==============================================================================
# TREND CHANGES MODULE
# ==============================================================================
# Purpose: Calculate wave-over-wave changes for all metric types in the tracker.
#
# This module extracts change calculation logic from trend_calculator.R to
# reduce complexity and improve maintainability.
#
# Author: Claude (Refactoring)
# Date: 2025-12-28
# Extracted from: trend_calculator.R
# ==============================================================================

#' Calculate Wave-over-Wave Changes
#'
#' Calculates absolute and percentage changes between consecutive waves for
#' basic metrics (mean, NPS, proportions).
#'
#' @param wave_results List of wave results indexed by wave ID
#' @param wave_ids Vector of wave IDs in chronological order
#' @param metric_name Character, name of the metric to track
#' @param sub_metric Optional, for proportions - the response code to track
#' @return List of change objects indexed by "prev_wave_to_current_wave"
#' @export
calculate_changes <- function(wave_results, wave_ids, metric_name, sub_metric = NULL) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- safe_wave_result(wave_results, wave_id)
    previous <- safe_wave_result(wave_results, prev_wave_id)

    # Get metric values
    if (!is.null(sub_metric)) {
      # For proportions, access by sub_metric (response code)
      sub_metric_str <- as.character(sub_metric)
      current_val <- if (!is.null(current[[metric_name]]) && sub_metric_str %in% names(current[[metric_name]])) {
        current[[metric_name]][[sub_metric_str]]
      } else {
        NA
      }
      previous_val <- if (!is.null(previous[[metric_name]]) && sub_metric_str %in% names(previous[[metric_name]])) {
        previous[[metric_name]][[sub_metric_str]]
      } else {
        NA
      }
    } else {
      current_val <- current[[metric_name]]
      previous_val <- previous[[metric_name]]
    }

    # Calculate changes
    if (!is.na(current_val) && !is.na(previous_val)) {
      absolute_change <- current_val - previous_val
      # Avoid division by zero
      percentage_change <- if (previous_val == 0) {
        NA  # Cannot calculate percentage change from zero baseline
      } else {
        (absolute_change / previous_val) * 100
      }

      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = absolute_change,
        percentage_change = percentage_change,
        direction = if (absolute_change > 0) "up" else if (absolute_change < 0) "down" else "stable"
      )
    } else {
      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = NA,
        percentage_change = NA,
        direction = "unavailable"
      )
    }
  }

  return(changes)
}


#' Calculate Changes for Enhanced Metrics
#'
#' Calculates wave-over-wave changes for enhanced metric types (top_box,
#' bottom_box, custom_range, etc.).
#'
#' @param wave_results List of wave results indexed by wave ID
#' @param wave_ids Vector of wave IDs in chronological order
#' @param metric_name Character, name of the metric to track
#' @return List of change objects indexed by "prev_wave_to_current_wave"
#' @keywords internal
calculate_changes_for_metric <- function(wave_results, wave_ids, metric_name) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- safe_wave_result(wave_results, wave_id)
    previous <- safe_wave_result(wave_results, prev_wave_id)

    # Get metric values
    current_val <- if (isTRUE(current$available) && !is.null(current$metrics[[metric_name]])) {
      current$metrics[[metric_name]]
    } else {
      NA
    }

    previous_val <- if (isTRUE(previous$available) && !is.null(previous$metrics[[metric_name]])) {
      previous$metrics[[metric_name]]
    } else {
      NA
    }

    # Calculate changes
    if (!is.na(current_val) && !is.na(previous_val)) {
      absolute_change <- current_val - previous_val
      percentage_change <- if (previous_val == 0) {
        NA
      } else {
        (absolute_change / previous_val) * 100
      }

      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = absolute_change,
        percentage_change = percentage_change,
        direction = if (absolute_change > 0) "up" else if (absolute_change < 0) "down" else "stable"
      )
    } else {
      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = NA,
        percentage_change = NA,
        direction = NA
      )
    }
  }

  return(changes)
}


#' Calculate Changes for Multi-Mention Option
#'
#' Calculates wave-over-wave changes for a specific multi-mention option's
#' mention proportion.
#'
#' @param wave_results List of wave results indexed by wave ID
#' @param wave_ids Vector of wave IDs in chronological order
#' @param column_name Character, column name for the multi-mention option
#' @return List of change objects indexed by "prev_wave_to_current_wave"
#' @keywords internal
calculate_changes_for_multi_mention_option <- function(wave_results, wave_ids, column_name) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- safe_wave_result(wave_results, wave_id)
    previous <- safe_wave_result(wave_results, prev_wave_id)

    # Get mention proportions
    current_val <- if (isTRUE(current$available) && !is.null(current$mention_proportions[[column_name]])) {
      current$mention_proportions[[column_name]]
    } else {
      NA
    }

    previous_val <- if (isTRUE(previous$available) && !is.null(previous$mention_proportions[[column_name]])) {
      previous$mention_proportions[[column_name]]
    } else {
      NA
    }

    # Calculate changes
    if (!is.na(current_val) && !is.na(previous_val)) {
      absolute_change <- current_val - previous_val
      percentage_change <- if (previous_val == 0) {
        NA
      } else {
        (absolute_change / previous_val) * 100
      }

      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = absolute_change,
        percentage_change = percentage_change,
        direction = if (absolute_change > 0) "up" else if (absolute_change < 0) "down" else "stable"
      )
    } else {
      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = NA,
        percentage_change = NA,
        direction = NA
      )
    }
  }

  return(changes)
}


#' Calculate Changes for Multi-Mention Additional Metric
#'
#' Calculates wave-over-wave changes for additional metrics tracked alongside
#' multi-mention questions (e.g., average number of mentions per respondent).
#'
#' @param wave_results List of wave results indexed by wave ID
#' @param wave_ids Vector of wave IDs in chronological order
#' @param metric_name Character, name of the additional metric to track
#' @return List of change objects indexed by "prev_wave_to_current_wave"
#' @keywords internal
calculate_changes_for_multi_mention_metric <- function(wave_results, wave_ids, metric_name) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- safe_wave_result(wave_results, wave_id)
    previous <- safe_wave_result(wave_results, prev_wave_id)

    current_val <- if (isTRUE(current$available) && !is.null(current$additional_metrics[[metric_name]])) {
      current$additional_metrics[[metric_name]]
    } else {
      NA
    }

    previous_val <- if (isTRUE(previous$available) && !is.null(previous$additional_metrics[[metric_name]])) {
      previous$additional_metrics[[metric_name]]
    } else {
      NA
    }

    if (!is.na(current_val) && !is.na(previous_val)) {
      absolute_change <- current_val - previous_val
      percentage_change <- if (previous_val == 0) {
        NA
      } else {
        (absolute_change / previous_val) * 100
      }

      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = absolute_change,
        percentage_change = percentage_change,
        direction = if (absolute_change > 0) "up" else if (absolute_change < 0) "down" else "stable"
      )
    } else {
      changes[[paste0(prev_wave_id, "_to_", wave_id)]] <- list(
        from_wave = prev_wave_id,
        to_wave = wave_id,
        from_value = previous_val,
        to_value = current_val,
        absolute_change = NA,
        percentage_change = NA,
        direction = NA
      )
    }
  }

  return(changes)
}


# ==============================================================================
# END OF TREND CHANGES MODULE
# ==============================================================================
