# ==============================================================================
# TurasTracker - Trend Table Writing Functions
# ==============================================================================
#
# This file contains table writing functions extracted from tracker_output.R
# for improved maintainability and code organization.
#
# PURPOSE:
# Contains specialized functions for writing different types of trend tables
# to Excel worksheets. Each function handles a specific question type or
# metric format.
#
# EXTRACTED FROM: tracker_output.R
# EXTRACTION DATE: 2025-12-27
#
# DEPENDENCIES:
# - openxlsx: Excel workbook creation and formatting
# - Tracker styles: Style objects created by create_tracker_styles()
# - Shared utilities: formatting_utils.R, config_utils.R
#
# FUNCTIONS:
# - write_mean_trend_table()              : Rating questions with mean metric
# - write_nps_trend_table()               : NPS questions (promoters/passives/detractors)
# - write_proportions_trend_table()       : Single-choice categorical questions
# - write_distribution_table()            : Response distribution for ratings
# - write_enhanced_rating_trend_table()   : Rating questions with multiple metrics
# - write_enhanced_composite_trend_table(): Composite scores with multiple metrics
# - write_multi_mention_trend_table()     : Multi-mention questions
#
# NOTES:
# - All functions expect tracker-specific style objects
# - All functions respect decimal_separator config setting
# - All functions use shared formatting utilities
# ==============================================================================


#' Write Mean Trend Table
#'
#' @keywords internal
write_mean_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {

  current_row <- start_row

  # Headers
  headers <- c("Metric", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Get decimal separator and decimal places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  # Phase 2 Update: Use shared formatting module
  # This FIXES the issue where decimal_separator was ignored!
  # Now properly respects config setting instead of always using "."
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Mean row - write label and numbers separately to preserve numeric type
  # First, write the label
  openxlsx::writeData(wb, sheet_name, "Mean",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

  # Then write numeric values (rounded to specified decimal places)
  mean_values <- numeric(length(wave_ids))
  for (i in seq_along(wave_ids)) {
    wave_result <- result$wave_results[[wave_ids[i]]]
    if (wave_result$available) {
      mean_values[i] <- round(wave_result$mean, decimal_places)
    } else {
      mean_values[i] <- NA
    }
  }

  openxlsx::writeData(wb, sheet_name, t(mean_values),
                      startRow = current_row, startCol = 2, colNames = FALSE)

  # Apply number format to numeric columns
  number_style <- openxlsx::createStyle(numFmt = number_format)
  openxlsx::addStyle(wb, sheet_name, number_style,
                    rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)
  current_row <- current_row + 1

  # Sample size row - write label and numbers separately
  openxlsx::writeData(wb, sheet_name, "Sample Size (n)",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

  # Write numeric values
  n_values <- numeric(length(wave_ids))
  for (i in seq_along(wave_ids)) {
    wave_result <- result$wave_results[[wave_ids[i]]]
    if (wave_result$available) {
      n_values[i] <- wave_result$n_unweighted
    } else {
      n_values[i] <- NA
    }
  }

  openxlsx::writeData(wb, sheet_name, t(n_values),
                      startRow = current_row, startCol = 2, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$data_integer,
                    rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE)
  current_row <- current_row + 2

  # Distribution section (show % for each rating value)
  current_row <- write_distribution_table(wb, sheet_name, result, wave_ids, config, styles, current_row)
  current_row <- current_row + 1

  # Changes section
  if (length(result$changes) > 0) {
    openxlsx::writeData(wb, sheet_name, "Wave-over-Wave Changes:",
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$header, rows = current_row, cols = 1)
    current_row <- current_row + 1

    change_headers <- c("Comparison", "Absolute Change", "% Change", "Significant")
    openxlsx::writeData(wb, sheet_name, t(change_headers),
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$wave_header,
                      rows = current_row, cols = 1:length(change_headers), gridExpand = TRUE)
    current_row <- current_row + 1

    for (change_name in names(result$changes)) {
      change <- result$changes[[change_name]]

      comparison_label <- paste0(change$from_wave, " → ", change$to_wave)

      # Get significance
      sig_key <- paste0(change$from_wave, "_vs_", change$to_wave)
      sig_test <- result$significance[[sig_key]]
      is_sig <- is_significant(sig_test)

      # Write label
      openxlsx::writeData(wb, sheet_name, comparison_label,
                          startRow = current_row, startCol = 1, colNames = FALSE)

      # Write numeric values separately to preserve type (rounded)
      openxlsx::writeData(wb, sheet_name, round(change$absolute_change, decimal_places),
                          startRow = current_row, startCol = 2, colNames = FALSE)
      openxlsx::writeData(wb, sheet_name, round(change$percentage_change, decimal_places),
                          startRow = current_row, startCol = 3, colNames = FALSE)
      openxlsx::writeData(wb, sheet_name, if (is_sig) "Yes" else "No",
                          startRow = current_row, startCol = 4, colNames = FALSE)

      # Style based on direction
      change_style <- if (!is.na(change$absolute_change) && change$absolute_change > 0) {
        styles$change_positive
      } else if (!is.na(change$absolute_change) && change$absolute_change < 0) {
        styles$change_negative
      } else {
        styles$data_number
      }

      # Apply number format with decimal separator to numeric columns
      number_style <- openxlsx::createStyle(numFmt = number_format)
      openxlsx::addStyle(wb, sheet_name, change_style, rows = current_row, cols = 2:3, gridExpand = TRUE)
      openxlsx::addStyle(wb, sheet_name, number_style, rows = current_row, cols = 2:3, gridExpand = TRUE, stack = TRUE)

      if (is_sig) {
        openxlsx::addStyle(wb, sheet_name, styles$significant, rows = current_row, cols = 4)
      }

      current_row <- current_row + 1
    }
  }

  # Set column widths
  openxlsx::setColWidths(wb, sheet_name, cols = 1:10, widths = "auto")

  return(current_row + 1)
}


#' Write NPS Trend Table
#'
#' @keywords internal
write_nps_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {

  current_row <- start_row

  # Get decimal separator and decimal places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  # Phase 2 Update: Use shared formatting module
  # This FIXES the issue where decimal_separator was ignored!
  # Now properly respects config setting instead of always using "."
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Headers
  headers <- c("Metric", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # NPS row
  metrics <- c("NPS Score", "% Promoters (9-10)", "% Passives (7-8)", "% Detractors (0-6)", "Sample Size (n)")

  for (metric in metrics) {
    # Write label
    openxlsx::writeData(wb, sheet_name, metric,
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

    # Collect numeric values
    metric_values <- numeric(length(wave_ids))
    for (i in seq_along(wave_ids)) {
      wave_result <- result$wave_results[[wave_ids[i]]]

      if (wave_result$available) {
        val <- if (metric == "NPS Score") {
          wave_result$nps
        } else if (metric == "% Promoters (9-10)") {
          wave_result$promoters_pct
        } else if (metric == "% Passives (7-8)") {
          wave_result$passives_pct
        } else if (metric == "% Detractors (0-6)") {
          wave_result$detractors_pct
        } else {
          wave_result$n_unweighted  # Sample size - don't round
        }
        # Round all values except sample size
        metric_values[i] <- if (metric == "Sample Size (n)") val else round(val, decimal_places)
      } else {
        metric_values[i] <- NA
      }
    }

    # Write numeric values
    openxlsx::writeData(wb, sheet_name, t(metric_values),
                        startRow = current_row, startCol = 2, colNames = FALSE)

    # Apply appropriate number format
    if (metric == "Sample Size (n)") {
      openxlsx::addStyle(wb, sheet_name, styles$data_integer,
                        rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE)
    } else {
      number_style <- openxlsx::createStyle(numFmt = number_format)
      openxlsx::addStyle(wb, sheet_name, number_style,
                        rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)
    }
    current_row <- current_row + 1
  }

  # Set column widths
  openxlsx::setColWidths(wb, sheet_name, cols = 1:10, widths = "auto")

  return(current_row + 1)
}


#' Write Proportions Trend Table
#'
#' @keywords internal
write_proportions_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {

  current_row <- start_row

  # Get decimal separator and decimal places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  # Phase 2 Update: Use shared formatting module
  # This FIXES the issue where decimal_separator was ignored!
  # Now properly respects config setting instead of always using "."
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Headers
  headers <- c("Response Option", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Row for each response code
  for (code in result$response_codes) {
    # Write label
    openxlsx::writeData(wb, sheet_name, as.character(code),
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

    # Collect numeric values (rounded)
    code_values <- numeric(length(wave_ids))
    for (i in seq_along(wave_ids)) {
      wave_result <- result$wave_results[[wave_ids[i]]]

      if (wave_result$available) {
        pct <- wave_result$proportions[[as.character(code)]]
        code_values[i] <- round(pct, decimal_places)
      } else {
        code_values[i] <- NA
      }
    }

    # Write numeric values
    openxlsx::writeData(wb, sheet_name, t(code_values),
                        startRow = current_row, startCol = 2, colNames = FALSE)

    # Apply number format
    number_style <- openxlsx::createStyle(numFmt = number_format)
    openxlsx::addStyle(wb, sheet_name, number_style,
                      rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)
    current_row <- current_row + 1
  }

  current_row <- current_row + 1

  # Sample size row - write label and numbers separately
  openxlsx::writeData(wb, sheet_name, "Sample Size (n)",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

  # Write numeric values
  n_values <- numeric(length(wave_ids))
  for (i in seq_along(wave_ids)) {
    wave_result <- result$wave_results[[wave_ids[i]]]
    if (wave_result$available) {
      n_values[i] <- wave_result$n_unweighted
    } else {
      n_values[i] <- NA
    }
  }

  openxlsx::writeData(wb, sheet_name, t(n_values),
                      startRow = current_row, startCol = 2, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$data_integer,
                    rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE)

  # Set column widths
  openxlsx::setColWidths(wb, sheet_name, cols = 1:10, widths = "auto")

  return(current_row + 1)
}


#' Write Distribution Table
#'
#' Writes distribution of responses (% for each rating value) for rating questions.
#'
#' @keywords internal
write_distribution_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {

  # Only show distribution for rating/mean questions
  if (is.null(result$metric_type) || result$metric_type != "mean") {
    return(start_row)
  }

  current_row <- start_row

  # Header
  openxlsx::writeData(wb, sheet_name, "Response Distribution:",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header, rows = current_row, cols = 1)
  current_row <- current_row + 1

  # Calculate distribution for each wave
  # First, find all unique values across all waves
  all_values <- c()
  for (wave_id in wave_ids) {
    wave_result <- result$wave_results[[wave_id]]
    if (wave_result$available && !is.null(wave_result$values)) {
      all_values <- c(all_values, wave_result$values)
    }
  }

  if (length(all_values) == 0) {
    # No distribution data available
    return(current_row)
  }

  # Get unique values and sort
  unique_values <- sort(unique(all_values[!is.na(all_values)]))

  # Get decimal separator and decimal places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  # Phase 2 Update: Use shared formatting module
  # This FIXES the issue where decimal_separator was ignored!
  # Now properly respects config setting instead of always using "."
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Write distribution table
  headers <- c("Rating Value", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$wave_header,
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Write row for each rating value
  for (val in unique_values) {
    # Write label
    openxlsx::writeData(wb, sheet_name, as.character(val),
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

    # Collect numeric values
    dist_values <- numeric(length(wave_ids))
    for (i in seq_along(wave_ids)) {
      wave_result <- result$wave_results[[wave_ids[i]]]

      if (wave_result$available && !is.null(wave_result$values)) {
        # Calculate percentage for this value
        values <- wave_result$values
        weights <- if (!is.null(wave_result$weights)) wave_result$weights else rep(1, length(values))

        # Count weighted responses for this value
        matching <- !is.na(values) & values == val
        weighted_count <- sum(weights[matching])
        total_weighted <- sum(weights[!is.na(values)])

        if (total_weighted > 0) {
          pct <- (weighted_count / total_weighted) * 100
          dist_values[i] <- round(pct, decimal_places)
        } else {
          dist_values[i] <- NA
        }
      } else {
        dist_values[i] <- NA
      }
    }

    # Write numeric values
    openxlsx::writeData(wb, sheet_name, t(dist_values),
                        startRow = current_row, startCol = 2, colNames = FALSE)

    # Apply number format
    number_style <- openxlsx::createStyle(numFmt = number_format)
    openxlsx::addStyle(wb, sheet_name, number_style,
                      rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)
    current_row <- current_row + 1
  }

  return(current_row)
}


#' Write Enhanced Rating Trend Table
#'
#' Writes table for rating questions with multiple metrics (mean, top_box, etc.)
#'
#' @keywords internal
write_enhanced_rating_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {

  current_row <- start_row

  # Get decimal separator and decimal places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Headers
  headers <- c("Metric", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Write row for each metric in tracking_specs
  for (metric_name in result$tracking_specs) {
    metric_lower <- tolower(trimws(metric_name))

    # Skip distribution (handled separately below)
    if (metric_lower == "distribution") {
      next
    }

    # Clean metric name for display
    display_name <- if (startsWith(metric_lower, "range:")) {
      paste0("% ", sub("range:", "", metric_name))
    } else if (metric_lower == "mean") {
      "Mean"
    } else if (metric_lower == "top_box") {
      "Top Box %"
    } else if (metric_lower == "top2_box") {
      "Top 2 Box %"
    } else if (metric_lower == "top3_box") {
      "Top 3 Box %"
    } else if (metric_lower == "bottom_box") {
      "Bottom Box %"
    } else if (metric_lower == "bottom2_box") {
      "Bottom 2 Box %"
    } else {
      metric_name
    }

    # Write label
    openxlsx::writeData(wb, sheet_name, display_name,
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

    # Collect numeric values
    metric_values <- numeric(length(wave_ids))
    for (i in seq_along(wave_ids)) {
      wave_result <- result$wave_results[[wave_ids[i]]]
      if (wave_result$available && !is.null(wave_result$metrics)) {
        metric_val <- wave_result$metrics[[metric_lower]]
        if (!is.null(metric_val)) {
          metric_values[i] <- round(metric_val, decimal_places)
        } else {
          metric_values[i] <- NA
        }
      } else {
        metric_values[i] <- NA
      }
    }

    # Write numeric values
    openxlsx::writeData(wb, sheet_name, t(metric_values),
                        startRow = current_row, startCol = 2, colNames = FALSE)

    # Apply number format
    number_style <- openxlsx::createStyle(numFmt = number_format)
    openxlsx::addStyle(wb, sheet_name, number_style,
                      rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)

    current_row <- current_row + 1
  }

  # Sample size row
  openxlsx::writeData(wb, sheet_name, "Sample Size (n)",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

  n_values <- numeric(length(wave_ids))
  for (i in seq_along(wave_ids)) {
    wave_result <- result$wave_results[[wave_ids[i]]]
    if (wave_result$available) {
      n_values[i] <- wave_result$n_unweighted
    } else {
      n_values[i] <- NA
    }
  }

  openxlsx::writeData(wb, sheet_name, t(n_values),
                      startRow = current_row, startCol = 2, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$data_integer,
                    rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE)
  current_row <- current_row + 2

  return(current_row)
}


#' Write Enhanced Composite Trend Table
#'
#' Same as enhanced rating (composites support same metrics)
#'
#' @keywords internal
write_enhanced_composite_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {
  return(write_enhanced_rating_trend_table(wb, sheet_name, result, wave_ids, config, styles, start_row))
}


#' Write Multi-Mention Trend Table
#'
#' Writes table for multi-mention questions showing % mentioning each option
#'
#' @keywords internal
write_multi_mention_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {

  current_row <- start_row

  # Get decimal separator and decimal places
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Headers
  headers <- c("Option", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Write row for each tracked column
  for (col_name in result$tracked_columns) {
    # Write label
    openxlsx::writeData(wb, sheet_name, col_name,
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

    # Collect numeric values (% mentioning)
    mention_values <- numeric(length(wave_ids))
    for (i in seq_along(wave_ids)) {
      wave_result <- result$wave_results[[wave_ids[i]]]
      if (wave_result$available && !is.null(wave_result$mention_proportions)) {
        mention_pct <- wave_result$mention_proportions[[col_name]]
        if (!is.null(mention_pct) && !is.na(mention_pct)) {
          mention_values[i] <- round(mention_pct, decimal_places)
        } else {
          mention_values[i] <- NA
        }
      } else {
        mention_values[i] <- NA
      }
    }

    # Write numeric values
    openxlsx::writeData(wb, sheet_name, t(mention_values),
                        startRow = current_row, startCol = 2, colNames = FALSE)

    # Apply number format
    number_style <- openxlsx::createStyle(numFmt = number_format)
    openxlsx::addStyle(wb, sheet_name, number_style,
                      rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)

    current_row <- current_row + 1
  }

  # Add additional metrics if present
  # Check first wave for additional metrics
  first_wave_result <- result$wave_results[[wave_ids[1]]]
  if (first_wave_result$available && !is.null(first_wave_result$additional_metrics)) {
    additional_metrics <- first_wave_result$additional_metrics

    if (!is.null(additional_metrics$any_mention_pct)) {
      current_row <- current_row + 1  # Blank row

      # "Any mention" row
      openxlsx::writeData(wb, sheet_name, "% Mentioning Any",
                          startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

      any_values <- numeric(length(wave_ids))
      for (i in seq_along(wave_ids)) {
        wave_result <- result$wave_results[[wave_ids[i]]]
        if (wave_result$available && !is.null(wave_result$additional_metrics$any_mention_pct)) {
          any_values[i] <- round(wave_result$additional_metrics$any_mention_pct, decimal_places)
        } else {
          any_values[i] <- NA
        }
      }

      openxlsx::writeData(wb, sheet_name, t(any_values),
                          startRow = current_row, startCol = 2, colNames = FALSE)

      number_style <- openxlsx::createStyle(numFmt = number_format)
      openxlsx::addStyle(wb, sheet_name, number_style,
                        rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)

      current_row <- current_row + 1
    }

    if (!is.null(additional_metrics$count_mean)) {
      # "Mean count" row
      openxlsx::writeData(wb, sheet_name, "Mean # of Mentions",
                          startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

      count_values <- numeric(length(wave_ids))
      for (i in seq_along(wave_ids)) {
        wave_result <- result$wave_results[[wave_ids[i]]]
        if (wave_result$available && !is.null(wave_result$additional_metrics$count_mean)) {
          count_values[i] <- round(wave_result$additional_metrics$count_mean, decimal_places)
        } else {
          count_values[i] <- NA
        }
      }

      openxlsx::writeData(wb, sheet_name, t(count_values),
                          startRow = current_row, startCol = 2, colNames = FALSE)

      number_style <- openxlsx::createStyle(numFmt = number_format)
      openxlsx::addStyle(wb, sheet_name, number_style,
                        rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)

      current_row <- current_row + 1
    }
  }

  # Sample size row
  current_row <- current_row + 1
  openxlsx::writeData(wb, sheet_name, "Sample Size (n)",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

  n_values <- numeric(length(wave_ids))
  for (i in seq_along(wave_ids)) {
    wave_result <- result$wave_results[[wave_ids[i]]]
    if (wave_result$available) {
      n_values[i] <- wave_result$n_unweighted
    } else {
      n_values[i] <- NA
    }
  }

  openxlsx::writeData(wb, sheet_name, t(n_values),
                      startRow = current_row, startCol = 2, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$data_integer,
                    rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE)

  current_row <- current_row + 2

  return(current_row)
}
