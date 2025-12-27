# ==============================================================================
# TurasTracker - Trend Changes Calculator
# ==============================================================================
#
# Wave-over-wave change calculations for tracked questions.
#
# EXTRACTED FROM: modules/tracker/lib/trend_calculator.R
# PURPOSE: Modular maintainability - separates change calculation logic from
#          main trend calculator orchestration
#
# This file contains functions that calculate absolute and percentage changes
# between consecutive waves for different question types:
#   - Rating questions (means, proportions, enhanced metrics)
#   - Multi-mention questions (mention proportions, additional metrics)
#
# ARCHITECTURE:
# These functions were extracted from trend_calculator.R as part of the
# planned decomposition outlined in that file's architecture notes (lines 19-38).
#
# The change calculation pattern is consistent across all functions:
#   1. Iterate through consecutive wave pairs
#   2. Extract current and previous wave values
#   3. Calculate absolute change (current - previous)
#   4. Calculate percentage change ((absolute / previous) * 100)
#   5. Determine direction (up/down/stable/unavailable)
#
# These functions are called by the main trend calculation functions in
# trend_calculator.R after wave-level metrics have been computed.
#
# ==============================================================================


#' Calculate Wave-over-Wave Changes
#'
#' Calculates changes for basic metrics (means, individual proportions).
#' Supports both simple metrics (e.g., mean) and sub-metrics (e.g., proportion
#' for a specific response code).
#'
#' @param wave_results List of wave-level results
#' @param wave_ids Vector of wave IDs in chronological order
#' @param metric_name Name of the metric to calculate changes for
#' @param sub_metric Optional sub-metric identifier (e.g., response code for proportions)
#'
#' @return List of change objects, one for each consecutive wave pair
#'
#' @keywords internal
calculate_changes <- function(wave_results, wave_ids, metric_name, sub_metric = NULL) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

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


#' Calculate Changes for Enhanced Metric
#'
#' Calculates changes for enhanced metrics (top_box, bottom_box, range, etc.)
#' that are nested under a $metrics list structure.
#'
#' @param wave_results List of wave-level results with $metrics structure
#' @param wave_ids Vector of wave IDs in chronological order
#' @param metric_name Name of the metric (e.g., "top_box", "bottom_box")
#'
#' @return List of change objects, one for each consecutive wave pair
#'
#' @keywords internal
calculate_changes_for_metric <- function(wave_results, wave_ids, metric_name) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get metric values
    current_val <- if (current$available && !is.null(current$metrics[[metric_name]])) {
      current$metrics[[metric_name]]
    } else {
      NA
    }

    previous_val <- if (previous$available && !is.null(previous$metrics[[metric_name]])) {
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
#' Calculates changes for multi-mention question options (mention proportions).
#'
#' @param wave_results List of wave-level results with $mention_proportions
#' @param wave_ids Vector of wave IDs in chronological order
#' @param column_name Name of the option column to calculate changes for
#'
#' @return List of change objects, one for each consecutive wave pair
#'
#' @keywords internal
calculate_changes_for_multi_mention_option <- function(wave_results, wave_ids, column_name) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    # Get mention proportions
    current_val <- if (current$available && !is.null(current$mention_proportions[[column_name]])) {
      current$mention_proportions[[column_name]]
    } else {
      NA
    }

    previous_val <- if (previous$available && !is.null(previous$mention_proportions[[column_name]])) {
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
#' Calculates changes for multi-mention additional metrics (e.g., sum_of_mentions).
#'
#' @param wave_results List of wave-level results with $additional_metrics
#' @param wave_ids Vector of wave IDs in chronological order
#' @param metric_name Name of the additional metric to calculate changes for
#'
#' @return List of change objects, one for each consecutive wave pair
#'
#' @keywords internal
calculate_changes_for_multi_mention_metric <- function(wave_results, wave_ids, metric_name) {

  changes <- list()

  for (i in 2:length(wave_ids)) {
    wave_id <- wave_ids[i]
    prev_wave_id <- wave_ids[i - 1]

    current <- wave_results[[wave_id]]
    previous <- wave_results[[prev_wave_id]]

    current_val <- if (current$available && !is.null(current$additional_metrics[[metric_name]])) {
      current$additional_metrics[[metric_name]]
    } else {
      NA
    }

    previous_val <- if (previous$available && !is.null(previous$additional_metrics[[metric_name]])) {
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
