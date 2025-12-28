# ==============================================================================
# TurasTracker - Dashboard and Enhanced Reports Module
# ==============================================================================
#
# Implements enhanced reporting capabilities:
#   1. Trend Dashboard - Executive summary showing all metrics with status
#   2. Significance Matrix - Wave-pair comparison matrices per question
#
# VERSION: 1.0.0 (2025-12-11)
#
# SPECIFICATION: Turas Tracker report enhancement Detailed Specification.txt
#
# DEPENDENCIES:
#   - openxlsx (Excel output)
#   - shared/formatting.R (decimal separator handling)
#   - tracker_output.R (shared styles and utilities)
#
# ==============================================================================


# ==============================================================================
# HELPER FUNCTIONS - Formatting and Display
# ==============================================================================

#' Convert Significance Code to Arrow Character
#'
#' Converts numeric significance code to visual arrow indicator.
#'
#' @param sig_code Numeric. -1 = sig down, 0 = not sig, 1 = sig up, NA = unknown
#' @return Character. Arrow symbol or dash for unknown
#'
#' @keywords internal
sig_to_arrow <- function(sig_code) {
  if (is.na(sig_code) || is.null(sig_code)) return("\u2014")  # em-dash
  if (sig_code > 0) return("\u2191")   # up arrow
  if (sig_code < 0) return("\u2193")   # down arrow
  return("\u2192")                      # right arrow (no change)
}


#' Get Style Based on Significance
#'
#' Returns appropriate cell style based on significance direction.
#'
#' @param sig_code Numeric. Significance code (-1, 0, 1)
#' @param styles List. Style definitions from create_dashboard_styles()
#' @return openxlsx style object
#'
#' @keywords internal
get_sig_style <- function(sig_code, styles) {
  if (is.na(sig_code) || is.null(sig_code)) return(styles$sig_none)
  if (sig_code > 0) return(styles$sig_up)
  if (sig_code < 0) return(styles$sig_down)
  return(styles$sig_none)
}


#' Determine Overall Trend Status
#'
#' Determines status label and style based on significance patterns.
#' Logic:
#'   - Alert: baseline significantly down
#'   - Watch: recent (prev wave) significantly down
#'   - Good: baseline significantly up
#'   - Stable: all other cases
#'
#' @param prev_sig Numeric. Previous wave significance code
#' @param base_sig Numeric. Baseline wave significance code
#' @param styles List. Style definitions from create_dashboard_styles()
#' @return List with $label and $style
#'
#' @keywords internal
determine_trend_status <- function(prev_sig, base_sig, styles) {
  # Alert: declining from baseline
  if (!is.na(base_sig) && base_sig < 0) {
    return(list(label = "Alert", style = styles$status_alert))
  }
  # Watch: recent decline
  if (!is.na(prev_sig) && prev_sig < 0) {
    return(list(label = "Watch", style = styles$status_watch))
  }
  # Good: improving from baseline
  if (!is.na(base_sig) && base_sig > 0) {
    return(list(label = "Good", style = styles$status_good))
  }
  # Stable: everything else
  return(list(label = "Stable", style = styles$status_stable))
}


#' Format Metric Type for Display
#'
#' Converts internal metric type to display label.
#'
#' @param metric_type Character. Internal metric type
#' @return Character. Display label
#'
#' @keywords internal
format_metric_type_display <- function(metric_type) {
  # Guard against NULL/NA/empty metric_type
  if (is.null(metric_type) || length(metric_type) == 0 || is.na(metric_type) || !nzchar(trimws(metric_type))) {
    tracker_refuse(
      code = "DATA_MISSING_METRIC_TYPE",
      title = "Missing metric type in dashboard",
      problem = "A question result is missing its metric_type field",
      why_it_matters = "The dashboard cannot display metric information without knowing the metric type",
      how_to_fix = c(
        "Check that all trend calculator functions set metric_type in their results",
        "Verify question_mapper.R maps question types to valid calculators",
        "Look for questions where the trend calculation may have failed silently"
      ),
      details = list(
        metric_type_value = metric_type,
        metric_type_class = class(metric_type),
        metric_type_length = length(metric_type)
      )
    )
  }

  type_lower <- tolower(metric_type)
  switch(type_lower,
         "proportion" = "%",
         "proportions" = "%",
         "mean" = "Mean",
         "rating" = "Mean",
         "rating_enhanced" = "Mean",
         "nps" = "NPS",
         "top2_box" = "T2B%",
         "top_box" = "TB%",
         "composite_enhanced" = "Index",
         "composite" = "Index",
         "multi_mention" = "%",
         "category_mentions" = "%",
         metric_type)
}


#' Format Metric Value for Display
#'
#' Formats a metric value for display with appropriate formatting.
#'
#' @param value Numeric. The value to format
#' @param metric_type Character. Type of metric
#' @param decimal_places Integer. Number of decimal places (default 1)
#' @return Character. Formatted value string
#'
#' @keywords internal
format_metric_value_display <- function(value, metric_type, decimal_places = 1) {
  if (is.na(value) || is.null(value)) return("\u2014")  # em-dash

  type_lower <- tolower(metric_type)

  if (type_lower %in% c("proportion", "proportions", "top2_box", "top_box", "multi_mention")) {
    # Percentage types - value is already in percentage form (0-100)
    return(paste0(round(value, decimal_places), "%"))
  } else if (type_lower == "nps") {
    # NPS is typically shown as integer
    return(as.character(round(value, 0)))
  }

  # Default: show with decimal places
  return(as.character(round(value, decimal_places)))
}


#' Format Change Value for Display
#'
#' Formats a change value with sign indicator.
#'
#' @param change Numeric. The change value
#' @param metric_type Character. Type of metric
#' @param decimal_places Integer. Number of decimal places (default 1)
#' @return Character. Formatted change string with sign
#'
#' @keywords internal
format_change_value_display <- function(change, metric_type, decimal_places = 1) {
  if (is.na(change) || is.null(change)) return("\u2014")  # em-dash

  sign_char <- if (change >= 0) "+" else ""
  type_lower <- tolower(metric_type)

  if (type_lower %in% c("proportion", "proportions", "top2_box", "top_box", "multi_mention")) {
    return(paste0(sign_char, round(change, decimal_places)))
  }

  return(paste0(sign_char, round(change, decimal_places)))
}


#' Extract Primary Metric Value from Wave Result
#'
#' Extracts the main metric value from a wave result based on metric type.
#'
#' @param wave_result List. Wave result object with metric data
#' @param metric_type Character. Type of metric to extract
#' @return Numeric. Primary metric value or NA
#'
#' @keywords internal
extract_primary_metric <- function(wave_result, metric_type) {
  if (is.null(wave_result) || !wave_result$available) return(NA)

  # Guard against NULL/NA/empty metric_type
  if (is.null(metric_type) || length(metric_type) == 0 || is.na(metric_type) || !nzchar(trimws(metric_type))) {
    tracker_refuse(
      code = "DATA_MISSING_METRIC_TYPE",
      title = "Missing metric type when extracting metric value",
      problem = "Cannot extract primary metric because metric_type is NULL/NA/empty",
      why_it_matters = "The system cannot determine which metric value to extract without a metric type",
      how_to_fix = c(
        "Check that all trend calculator functions set metric_type in their results",
        "Verify question_mapper.R maps question types to valid calculators",
        "Look for questions where the trend calculation may have failed silently"
      ),
      details = list(
        metric_type_value = metric_type,
        metric_type_class = class(metric_type),
        metric_type_length = length(metric_type),
        wave_result_names = names(wave_result)
      )
    )
  }

  type_lower <- tolower(metric_type)

  result <- switch(type_lower,
         "proportion" = {
           if (!is.null(wave_result$proportion)) wave_result$proportion * 100 else NA
         },
         "proportions" = {
           # For proportions, we need to handle differently - get first proportion
           if (!is.null(wave_result$proportions) && length(wave_result$proportions) > 0) {
             wave_result$proportions[1] * 100
           } else NA
         },
         "mean" = wave_result$mean,
         "rating" = wave_result$mean,
         "rating_enhanced" = wave_result$mean,
         "nps" = wave_result$nps,
         "top2_box" = {
           if (!is.null(wave_result$top2_box_pct)) wave_result$top2_box_pct else NA
         },
         "top_box" = {
           if (!is.null(wave_result$top_box_pct)) wave_result$top_box_pct else NA
         },
         "composite_enhanced" = wave_result$mean,
         "composite" = wave_result$mean,
         "multi_mention" = {
           # For multi-mention, extract first item proportion
           if (!is.null(wave_result$item_proportions) && length(wave_result$item_proportions) > 0) {
             wave_result$item_proportions[1] * 100
           } else NA
         },
         "category_mentions" = {
           # For category mentions, extract first category proportion
           if (!is.null(wave_result$category_proportions) && length(wave_result$category_proportions) > 0) {
             wave_result$category_proportions[1] * 100
           } else NA
         },
         wave_result$mean)  # default to mean

  return(result)
}


# ==============================================================================
# HELPER FUNCTIONS - Statistical Calculations
# ==============================================================================

#' Calculate Pairwise Significance Between Two Waves
#'
#' Calculates statistical significance between two wave results.
#' Uses appropriate test based on metric type:
#'   - Proportions: Two-proportion z-test
#'   - Means: Two-sample t-test (Welch's)
#'   - NPS: Simplified z-test approximation
#'
#' @param from_result List. Wave result for "from" wave
#' @param to_result List. Wave result for "to" wave
#' @param metric_type Character. Type of metric
#' @param alpha Numeric. Significance level (default 0.05)
#' @return List with $sig_code (-1, 0, 1) and $p_value
#'
#' @keywords internal
calculate_pairwise_significance <- function(from_result, to_result, metric_type, alpha = 0.05) {

  # Default return for errors or insufficient data
  default_return <- list(sig_code = 0, p_value = NA)

  # Check for valid inputs
  if (is.null(from_result) || is.null(to_result)) return(default_return)
  if (!isTRUE(from_result$available) || !isTRUE(to_result$available)) return(default_return)

  tryCatch({
    type_lower <- tolower(metric_type)

    if (type_lower %in% c("proportion", "proportions", "top2_box", "top_box", "multi_mention")) {
      # Two-proportion z-test
      p1 <- if (!is.null(from_result$proportion)) {
        from_result$proportion
      } else if (!is.null(from_result$proportions) && length(from_result$proportions) > 0) {
        from_result$proportions[1]
      } else if (!is.null(from_result$item_proportions) && length(from_result$item_proportions) > 0) {
        from_result$item_proportions[1]
      } else {
        return(default_return)
      }

      p2 <- if (!is.null(to_result$proportion)) {
        to_result$proportion
      } else if (!is.null(to_result$proportions) && length(to_result$proportions) > 0) {
        to_result$proportions[1]
      } else if (!is.null(to_result$item_proportions) && length(to_result$item_proportions) > 0) {
        to_result$item_proportions[1]
      } else {
        return(default_return)
      }

      n1 <- from_result$n_weighted
      n2 <- to_result$n_weighted

      if (is.na(n1) || is.na(n2) || n1 <= 0 || n2 <= 0) return(default_return)

      # Pooled proportion
      p_pooled <- (p1 * n1 + p2 * n2) / (n1 + n2)

      # Standard error
      se <- sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))

      if (se == 0 || is.na(se)) return(default_return)

      # Z-score
      z <- (p2 - p1) / se
      p_value <- 2 * pnorm(-abs(z))

    } else if (type_lower %in% c("mean", "rating", "rating_enhanced", "composite_enhanced")) {
      # Two-sample t-test (Welch's approximation)
      m1 <- from_result$mean
      m2 <- to_result$mean
      sd1 <- from_result$sd
      sd2 <- to_result$sd
      n1 <- from_result$n_weighted
      n2 <- to_result$n_weighted

      if (any(is.na(c(m1, m2, sd1, sd2, n1, n2)))) return(default_return)
      if (n1 <= 1 || n2 <= 1) return(default_return)

      se <- sqrt(sd1^2/n1 + sd2^2/n2)

      if (se == 0 || is.na(se)) return(default_return)

      t_stat <- (m2 - m1) / se

      # Welch-Satterthwaite degrees of freedom
      df <- (sd1^2/n1 + sd2^2/n2)^2 /
            ((sd1^2/n1)^2/(n1-1) + (sd2^2/n2)^2/(n2-1))

      if (is.na(df) || df <= 0) return(default_return)

      p_value <- 2 * pt(-abs(t_stat), df)
      z <- t_stat  # Use t_stat for direction

    } else if (type_lower == "nps") {
      # NPS significance test (simplified approach)
      nps1 <- from_result$nps
      nps2 <- to_result$nps
      n1 <- from_result$n_weighted
      n2 <- to_result$n_weighted

      if (any(is.na(c(nps1, nps2, n1, n2)))) return(default_return)
      if (n1 <= 0 || n2 <= 0) return(default_return)

      # Rough approximation using standard error
      se <- sqrt(100^2 * (1/n1 + 1/n2))
      z <- (nps2 - nps1) / se
      p_value <- 2 * pnorm(-abs(z))

    } else {
      return(default_return)
    }

    # Determine significance code
    if (is.na(p_value)) {
      sig_code <- 0
    } else if (p_value < alpha) {
      sig_code <- if (z > 0) 1 else -1
    } else {
      sig_code <- 0
    }

    return(list(sig_code = sig_code, p_value = p_value))

  }, error = function(e) {
    return(default_return)
  })
}


#' Calculate Change Significance Between Two Waves
#'
#' Wrapper function to calculate significance between two specific waves.
#' Used for dashboard trend comparisons.
#'
#' @param from_wave_result List. Wave result for starting wave
#' @param to_wave_result List. Wave result for ending wave
#' @param metric_type Character. Type of metric
#' @param config Configuration object (for alpha level)
#' @return Integer. Significance code: -1, 0, or 1
#'
#' @keywords internal
calculate_change_significance <- function(from_wave_result, to_wave_result, metric_type, config) {
  alpha <- get_setting(config, "alpha", default = 0.05)
  sig_result <- calculate_pairwise_significance(from_wave_result, to_wave_result, metric_type, alpha)
  return(sig_result$sig_code)
}


# ==============================================================================
# STYLE DEFINITIONS
# ==============================================================================

#' Create Dashboard Styles
#'
#' Creates style definitions for dashboard and significance matrix reports.
#'
#' @return List of openxlsx style objects
#'
#' @keywords internal
create_dashboard_styles <- function() {
  list(
    # Title styles
    title = openxlsx::createStyle(
      fontSize = 14, fontColour = "#1F4E79", textDecoration = "bold"
    ),
    subtitle = openxlsx::createStyle(
      fontSize = 10, fontColour = "#666666"
    ),

    # Header styles
    header = openxlsx::createStyle(
      fontSize = 10, fontColour = "#FFFFFF", fgFill = "#1F4E79",
      textDecoration = "bold", halign = "center",
      border = "TopBottomLeftRight", borderColour = "#FFFFFF"
    ),
    row_header = openxlsx::createStyle(
      fontSize = 10, fgFill = "#D6DCE4", textDecoration = "bold",
      halign = "left", border = "TopBottomLeftRight"
    ),

    # Data styles
    data_text = openxlsx::createStyle(
      fontSize = 10, halign = "left", border = "TopBottomLeftRight"
    ),
    data_num = openxlsx::createStyle(
      fontSize = 10, halign = "center", border = "TopBottomLeftRight"
    ),

    # Significance indicator styles
    sig_up = openxlsx::createStyle(
      fontSize = 10, fontColour = "#006400", halign = "center",
      textDecoration = "bold", border = "TopBottomLeftRight"
    ),
    sig_down = openxlsx::createStyle(
      fontSize = 10, fontColour = "#8B0000", halign = "center",
      textDecoration = "bold", border = "TopBottomLeftRight"
    ),
    sig_none = openxlsx::createStyle(
      fontSize = 10, fontColour = "#666666", halign = "center",
      border = "TopBottomLeftRight"
    ),

    # Status indicator styles (with background colors)
    status_good = openxlsx::createStyle(
      fontSize = 10, fgFill = "#C6EFCE", fontColour = "#006400",
      halign = "center", border = "TopBottomLeftRight"
    ),
    status_watch = openxlsx::createStyle(
      fontSize = 10, fgFill = "#FFEB9C", fontColour = "#9C5700",
      halign = "center", border = "TopBottomLeftRight"
    ),
    status_alert = openxlsx::createStyle(
      fontSize = 10, fgFill = "#FFC7CE", fontColour = "#9C0006",
      halign = "center", border = "TopBottomLeftRight"
    ),
    status_stable = openxlsx::createStyle(
      fontSize = 10, fgFill = "#DDDDDD", fontColour = "#333333",
      halign = "center", border = "TopBottomLeftRight"
    ),

    # Wave column style
    wave_col = openxlsx::createStyle(
      fontSize = 9, halign = "center", border = "TopBottomLeftRight",
      fgFill = "#F2F2F2"
    ),

    # Matrix-specific styles
    diagonal = openxlsx::createStyle(
      fontSize = 10, fgFill = "#808080", fontColour = "#FFFFFF",
      halign = "center", border = "TopBottomLeftRight"
    ),
    matrix_sig_up = openxlsx::createStyle(
      fontSize = 10, fgFill = "#C6EFCE", fontColour = "#006400",
      halign = "center", border = "TopBottomLeftRight"
    ),
    matrix_sig_down = openxlsx::createStyle(
      fontSize = 10, fgFill = "#FFC7CE", fontColour = "#9C0006",
      halign = "center", border = "TopBottomLeftRight"
    ),
    matrix_not_sig = openxlsx::createStyle(
      fontSize = 10, fgFill = "#FFFFFF", fontColour = "#666666",
      halign = "center", border = "TopBottomLeftRight"
    ),
    na_cell = openxlsx::createStyle(
      fontSize = 10, fgFill = "#F2F2F2", fontColour = "#999999",
      halign = "center", border = "TopBottomLeftRight"
    ),

    # Legend style
    legend = openxlsx::createStyle(
      fontSize = 9, fontColour = "#666666"
    )
  )
}


# ==============================================================================
# TREND DASHBOARD
# ==============================================================================

#' Write Trend Dashboard to Excel
#'
#' Creates executive summary dashboard showing all metrics with trend status.
#' Shows: Code, Question, Type, Latest Value, vs Prev Wave, vs Baseline,
#' Wave values, and overall Status indicator.
#'
#' @param wb openxlsx workbook object
#' @param trend_results List of trend results from calculate_all_trends()
#' @param config Configuration object
#' @param sheet_name Character. Name for dashboard sheet (default "Trend_Dashboard")
#' @return Modified workbook object (invisibly)
#'
#' @export
write_trend_dashboard <- function(wb, trend_results, config, sheet_name = "Trend_Dashboard") {

  message("  Writing Trend Dashboard sheet...")

  # Add sheet
  openxlsx::addWorksheet(wb, sheet_name)

  # Get wave IDs
  wave_ids <- config$waves$WaveID
  n_waves <- length(wave_ids)

  # Get styles
  styles <- create_dashboard_styles()

  # Get decimal separator and places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  # ===========================================================================
  # TITLE ROW
  # ===========================================================================

  project_name <- get_setting(config, "project_name", default = "Tracking Analysis")
  title_text <- paste0("TREND DASHBOARD - ", project_name)

  openxlsx::writeData(wb, sheet_name, title_text, startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, sheet_name, styles$title, rows = 1, cols = 1)
  openxlsx::mergeCells(wb, sheet_name, cols = 1:(8 + n_waves), rows = 1)

  # Generation timestamp
  openxlsx::writeData(wb, sheet_name,
                      paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
                      startRow = 2, startCol = 1)
  openxlsx::addStyle(wb, sheet_name, styles$subtitle, rows = 2, cols = 1)

  # ===========================================================================
  # HEADER ROW
  # ===========================================================================

  header_row <- 4
  headers <- c("Code", "Question", "Type", "Latest", "vs Prev", "Sig",
               "vs Base", "Sig", wave_ids, "Status")

  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = header_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                     rows = header_row, cols = 1:length(headers), gridExpand = TRUE)

  # ===========================================================================
  # DATA ROWS
  # ===========================================================================

  current_row <- header_row + 1
  rows_written <- 0

  # Debug: show what we're iterating over
  if (length(trend_results) == 0) {
    message("  WARNING: No trend results to display in dashboard")
  } else {
    message(paste0("  Processing ", length(trend_results), " questions for dashboard..."))
  }

  for (q_code in names(trend_results)) {
    q_result <- trend_results[[q_code]]

    # Skip if no wave_results
    if (is.null(q_result$wave_results)) {
      message(paste0("    Skipping ", q_code, ": no wave_results"))
      next
    }

    # Extract wave values
    wave_values <- sapply(wave_ids, function(wid) {
      wr <- q_result$wave_results[[wid]]
      extract_primary_metric(wr, q_result$metric_type)
    })

    # Calculate indices for comparisons
    latest_idx <- n_waves
    prev_idx <- n_waves - 1
    base_idx <- 1

    latest_val <- wave_values[latest_idx]
    prev_val <- if (prev_idx >= 1) wave_values[prev_idx] else NA
    base_val <- wave_values[base_idx]

    prev_change <- if (!is.na(latest_val) && !is.na(prev_val)) latest_val - prev_val else NA
    base_change <- if (!is.na(latest_val) && !is.na(base_val)) latest_val - base_val else NA

    # Calculate significance
    prev_sig <- if (prev_idx >= 1) {
      calculate_change_significance(
        q_result$wave_results[[wave_ids[prev_idx]]],
        q_result$wave_results[[wave_ids[latest_idx]]],
        q_result$metric_type,
        config
      )
    } else NA

    base_sig <- calculate_change_significance(
      q_result$wave_results[[wave_ids[base_idx]]],
      q_result$wave_results[[wave_ids[latest_idx]]],
      q_result$metric_type,
      config
    )

    # Determine status
    status <- determine_trend_status(prev_sig, base_sig, styles)

    # Format values for display
    metric_type_display <- format_metric_type_display(q_result$metric_type)
    latest_display <- format_metric_value_display(latest_val, q_result$metric_type, decimal_places)
    prev_display <- format_change_value_display(prev_change, q_result$metric_type, decimal_places)
    base_display <- format_change_value_display(base_change, q_result$metric_type, decimal_places)
    prev_sig_char <- sig_to_arrow(prev_sig)
    base_sig_char <- sig_to_arrow(base_sig)

    # Truncate question text if too long
    question_text <- q_result$question_text
    if (nchar(question_text) > 60) {
      question_text <- paste0(substr(question_text, 1, 57), "...")
    }

    # Write row data
    col <- 1

    # Code
    openxlsx::writeData(wb, sheet_name, q_result$question_code,
                        startRow = current_row, startCol = col)
    openxlsx::addStyle(wb, sheet_name, styles$data_text,
                       rows = current_row, cols = col)
    col <- col + 1

    # Question
    openxlsx::writeData(wb, sheet_name, question_text,
                        startRow = current_row, startCol = col)
    openxlsx::addStyle(wb, sheet_name, styles$data_text,
                       rows = current_row, cols = col)
    col <- col + 1

    # Type
    openxlsx::writeData(wb, sheet_name, metric_type_display,
                        startRow = current_row, startCol = col)
    openxlsx::addStyle(wb, sheet_name, styles$data_num,
                       rows = current_row, cols = col)
    col <- col + 1

    # Latest value
    openxlsx::writeData(wb, sheet_name, latest_display,
                        startRow = current_row, startCol = col)
    openxlsx::addStyle(wb, sheet_name, styles$data_num,
                       rows = current_row, cols = col)
    col <- col + 1

    # vs Prev change
    openxlsx::writeData(wb, sheet_name, prev_display,
                        startRow = current_row, startCol = col)
    openxlsx::addStyle(wb, sheet_name, get_sig_style(prev_sig, styles),
                       rows = current_row, cols = col)
    col <- col + 1

    # Prev sig indicator
    openxlsx::writeData(wb, sheet_name, prev_sig_char,
                        startRow = current_row, startCol = col)
    openxlsx::addStyle(wb, sheet_name, get_sig_style(prev_sig, styles),
                       rows = current_row, cols = col)
    col <- col + 1

    # vs Base change
    openxlsx::writeData(wb, sheet_name, base_display,
                        startRow = current_row, startCol = col)
    openxlsx::addStyle(wb, sheet_name, get_sig_style(base_sig, styles),
                       rows = current_row, cols = col)
    col <- col + 1

    # Base sig indicator
    openxlsx::writeData(wb, sheet_name, base_sig_char,
                        startRow = current_row, startCol = col)
    openxlsx::addStyle(wb, sheet_name, get_sig_style(base_sig, styles),
                       rows = current_row, cols = col)
    col <- col + 1

    # Wave values
    for (i in seq_along(wave_ids)) {
      wave_val <- wave_values[i]
      wave_display <- if (!is.na(wave_val)) round(wave_val, decimal_places) else "\u2014"
      openxlsx::writeData(wb, sheet_name, wave_display,
                          startRow = current_row, startCol = col)
      openxlsx::addStyle(wb, sheet_name, styles$wave_col,
                         rows = current_row, cols = col)
      col <- col + 1
    }

    # Status
    openxlsx::writeData(wb, sheet_name, status$label,
                        startRow = current_row, startCol = col)
    openxlsx::addStyle(wb, sheet_name, status$style,
                       rows = current_row, cols = col)

    current_row <- current_row + 1
    rows_written <- rows_written + 1
  }

  # Report how many rows were written
  if (rows_written == 0) {
    message("  WARNING: No data rows written to dashboard. Check that trend_results contains valid wave_results.")
  } else {
    message(paste0("  Dashboard: ", rows_written, " question rows written"))
  }

  # ===========================================================================
  # LEGEND
  # ===========================================================================

  legend_row <- current_row + 2

  legend_lines <- c(
    paste0("Legend: \u2191 Significant increase | \u2193 Significant decrease | \u2192 No significant change"),
    "Status: Good (improving from baseline) | Stable | Watch (recent decline) | Alert (declining from baseline)"
  )

  for (i in seq_along(legend_lines)) {
    openxlsx::writeData(wb, sheet_name, legend_lines[i],
                        startRow = legend_row + i - 1, startCol = 1)
    openxlsx::addStyle(wb, sheet_name, styles$legend,
                       rows = legend_row + i - 1, cols = 1)
  }

  # ===========================================================================
  # COLUMN WIDTHS
  # ===========================================================================

  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 18)   # Code
  openxlsx::setColWidths(wb, sheet_name, cols = 2, widths = 40)   # Question
  openxlsx::setColWidths(wb, sheet_name, cols = 3, widths = 8)    # Type
  openxlsx::setColWidths(wb, sheet_name, cols = 4, widths = 10)   # Latest
  openxlsx::setColWidths(wb, sheet_name, cols = 5, widths = 10)   # vs Prev
  openxlsx::setColWidths(wb, sheet_name, cols = 6, widths = 5)    # Sig
  openxlsx::setColWidths(wb, sheet_name, cols = 7, widths = 10)   # vs Base
  openxlsx::setColWidths(wb, sheet_name, cols = 8, widths = 5)    # Sig
  openxlsx::setColWidths(wb, sheet_name, cols = 9:(8 + n_waves), widths = 8)  # Waves
  openxlsx::setColWidths(wb, sheet_name, cols = 9 + n_waves, widths = 10)     # Status

  # Freeze panes (freeze header row and first 2 columns)
  openxlsx::freezePane(wb, sheet_name, firstRow = TRUE, firstCol = FALSE,
                       firstActiveRow = header_row + 1, firstActiveCol = 3)

  invisible(wb)
}


# ==============================================================================
# SIGNIFICANCE MATRIX
# ==============================================================================

#' Write Significance Matrix for a Question
#'
#' Creates matrix showing significance of all wave-pair comparisons.
#' Matrix shows change from ROW wave to COLUMN wave.
#'
#' @param wb openxlsx workbook object
#' @param q_result Question result object from trend_results
#' @param config Configuration object
#' @param wave_ids Character vector of wave IDs
#' @return Modified workbook (invisibly)
#'
#' @export
write_significance_matrix <- function(wb, q_result, config, wave_ids) {

  # Create sheet name (max 31 chars for Excel)
  sheet_name <- paste0(q_result$question_code, "_SigMatrix")
  if (nchar(sheet_name) > 31) {
    sheet_name <- substr(sheet_name, 1, 31)
  }

  # Ensure unique sheet name
  existing_sheets <- openxlsx::sheets(wb)
  if (sheet_name %in% existing_sheets) {
    # Add numeric suffix if name exists
    base_name <- substr(sheet_name, 1, 28)
    suffix <- 1
    while (paste0(base_name, "_", suffix) %in% existing_sheets) {
      suffix <- suffix + 1
    }
    sheet_name <- paste0(base_name, "_", suffix)
  }

  message(paste0("  Writing Significance Matrix: ", sheet_name))

  openxlsx::addWorksheet(wb, sheet_name)

  n_waves <- length(wave_ids)
  alpha <- get_setting(config, "alpha", default = 0.05)
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  # Get styles
  styles <- create_dashboard_styles()

  # ===========================================================================
  # EXTRACT WAVE VALUES
  # ===========================================================================

  wave_values <- sapply(wave_ids, function(wid) {
    wr <- q_result$wave_results[[wid]]
    extract_primary_metric(wr, q_result$metric_type)
  })

  wave_n <- sapply(wave_ids, function(wid) {
    wr <- q_result$wave_results[[wid]]
    if (!is.null(wr) && wr$available) {
      wr$n_unweighted
    } else {
      NA
    }
  })

  # ===========================================================================
  # TITLE AND SUBTITLE
  # ===========================================================================

  current_row <- 1

  # Title
  title_text <- paste0(q_result$question_code, " - ", q_result$question_text)
  if (nchar(title_text) > 80) {
    title_text <- paste0(substr(title_text, 1, 77), "...")
  }
  openxlsx::writeData(wb, sheet_name, title_text, startRow = current_row, startCol = 1)
  openxlsx::addStyle(wb, sheet_name, styles$title, rows = current_row, cols = 1)
  current_row <- current_row + 1

  # Subtitle with wave values
  wave_summary_parts <- sapply(seq_along(wave_ids), function(i) {
    val_display <- format_metric_value_display(wave_values[i], q_result$metric_type, decimal_places)
    n_display <- if (!is.na(wave_n[i])) paste0("n=", wave_n[i]) else "n=N/A"
    paste0(wave_ids[i], " = ", val_display, " (", n_display, ")")
  })
  wave_summary <- paste(wave_summary_parts, collapse = ", ")
  openxlsx::writeData(wb, sheet_name, wave_summary, startRow = current_row, startCol = 1)
  openxlsx::addStyle(wb, sheet_name, styles$subtitle, rows = current_row, cols = 1)
  current_row <- current_row + 2

  # ===========================================================================
  # MATRIX HEADER ROW
  # ===========================================================================

  matrix_start_row <- current_row

  # Write "From \\ To" label
  openxlsx::writeData(wb, sheet_name, "From \\ To",
                      startRow = matrix_start_row, startCol = 1)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                     rows = matrix_start_row, cols = 1)

  # Write column headers (wave IDs with values)
  for (j in seq_along(wave_ids)) {
    header_text <- paste0(wave_ids[j], "\n",
                          format_metric_value_display(wave_values[j], q_result$metric_type, decimal_places))
    openxlsx::writeData(wb, sheet_name, header_text,
                        startRow = matrix_start_row, startCol = j + 1)
    openxlsx::addStyle(wb, sheet_name, styles$header,
                       rows = matrix_start_row, cols = j + 1)
  }

  current_row <- matrix_start_row + 1

  # ===========================================================================
  # MATRIX DATA ROWS
  # ===========================================================================

  for (i in seq_along(wave_ids)) {
    # Row header
    row_label <- paste0(wave_ids[i], " (",
                        format_metric_value_display(wave_values[i], q_result$metric_type, decimal_places), ")")
    openxlsx::writeData(wb, sheet_name, row_label,
                        startRow = current_row, startCol = 1)
    openxlsx::addStyle(wb, sheet_name, styles$row_header,
                       rows = current_row, cols = 1)

    # Matrix cells
    for (j in seq_along(wave_ids)) {
      col_idx <- j + 1

      if (i == j) {
        # Diagonal - same wave
        openxlsx::writeData(wb, sheet_name, "\u2014",
                            startRow = current_row, startCol = col_idx)
        openxlsx::addStyle(wb, sheet_name, styles$diagonal,
                           rows = current_row, cols = col_idx)

      } else if (j > i) {
        # Upper triangle - show comparison (from row wave TO column wave)
        from_wave <- wave_ids[i]
        to_wave <- wave_ids[j]

        from_result <- q_result$wave_results[[from_wave]]
        to_result <- q_result$wave_results[[to_wave]]

        if (is.null(from_result) || !isTRUE(from_result$available) ||
            is.null(to_result) || !isTRUE(to_result$available)) {
          openxlsx::writeData(wb, sheet_name, "N/A",
                              startRow = current_row, startCol = col_idx)
          openxlsx::addStyle(wb, sheet_name, styles$na_cell,
                             rows = current_row, cols = col_idx)
        } else {
          # Calculate change and significance
          change <- wave_values[j] - wave_values[i]
          sig_result <- calculate_pairwise_significance(
            from_result, to_result, q_result$metric_type, alpha
          )

          # Format cell content
          change_text <- format_change_value_display(change, q_result$metric_type, decimal_places)
          sig_arrow <- sig_to_arrow(sig_result$sig_code)
          cell_text <- paste0(change_text, sig_arrow)

          openxlsx::writeData(wb, sheet_name, cell_text,
                              startRow = current_row, startCol = col_idx)

          # Apply significance-based styling
          cell_style <- switch(
            as.character(sig_result$sig_code),
            "1" = styles$matrix_sig_up,
            "-1" = styles$matrix_sig_down,
            styles$matrix_not_sig
          )
          openxlsx::addStyle(wb, sheet_name, cell_style,
                             rows = current_row, cols = col_idx)
        }

      } else {
        # Lower triangle - leave empty/grey
        openxlsx::writeData(wb, sheet_name, "",
                            startRow = current_row, startCol = col_idx)
        openxlsx::addStyle(wb, sheet_name, styles$na_cell,
                           rows = current_row, cols = col_idx)
      }
    }

    current_row <- current_row + 1
  }

  # ===========================================================================
  # LEGEND
  # ===========================================================================

  current_row <- current_row + 2

  openxlsx::writeData(wb, sheet_name, "Legend:",
                      startRow = current_row, startCol = 1)
  openxlsx::addStyle(wb, sheet_name, styles$title, rows = current_row, cols = 1)
  current_row <- current_row + 1

  legend_items <- c(
    "Cell shows: Change from ROW wave to COLUMN wave",
    paste0("\u2191 = Significant increase (p < ", alpha, ")"),
    paste0("\u2193 = Significant decrease (p < ", alpha, ")"),
    "\u2192 = Not statistically significant",
    "\u2014 = Same wave (diagonal)",
    "N/A = Data not available"
  )

  for (item in legend_items) {
    openxlsx::writeData(wb, sheet_name, item, startRow = current_row, startCol = 1)
    openxlsx::addStyle(wb, sheet_name, styles$legend, rows = current_row, cols = 1)
    current_row <- current_row + 1
  }

  # ===========================================================================
  # COLUMN WIDTHS
  # ===========================================================================

  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 18)
  openxlsx::setColWidths(wb, sheet_name, cols = 2:(n_waves + 1), widths = 12)

  # Set row height for header to accommodate two lines
  openxlsx::setRowHeights(wb, sheet_name, rows = matrix_start_row, heights = 30)

  invisible(wb)
}


#' Write All Significance Matrices
#'
#' Creates significance matrix sheets for all questions in trend_results.
#'
#' @param wb openxlsx workbook object
#' @param trend_results List of trend results
#' @param config Configuration object
#' @return Modified workbook (invisibly)
#'
#' @export
write_all_significance_matrices <- function(wb, trend_results, config) {

  wave_ids <- config$waves$WaveID
  matrices_written <- 0

  # Debug: show what we're iterating over
  if (length(trend_results) == 0) {
    message("  WARNING: No trend results to display in significance matrices")
  } else {
    message(paste0("  Processing ", length(trend_results), " questions for significance matrices..."))
  }

  for (q_code in names(trend_results)) {
    q_result <- trend_results[[q_code]]

    # Skip if no wave_results
    if (is.null(q_result$wave_results)) {
      message(paste0("    Skipping ", q_code, ": no wave_results"))
      next
    }

    write_significance_matrix(wb, q_result, config, wave_ids)
    matrices_written <- matrices_written + 1
  }

  # Report how many matrices were written
  if (matrices_written == 0) {
    message("  WARNING: No significance matrices written. Check that trend_results contains valid wave_results.")
  } else {
    message(paste0("  Sig Matrix: ", matrices_written, " matrices written"))
  }

  invisible(wb)
}


# ==============================================================================
# COMBINED DASHBOARD OUTPUT FUNCTION
# ==============================================================================

#' Write Dashboard Report to Excel
#'
#' Creates complete dashboard report with Trend Dashboard and optional
#' Significance Matrices.
#'
#' @param trend_results List of trend results from calculate_all_trends()
#' @param config Configuration object
#' @param wave_data List of wave data frames
#' @param output_path Character. Path for output file (auto-generated if NULL)
#' @param include_sig_matrices Logical. Include significance matrices (default TRUE)
#' @return Character. Path to created file
#'
#' @export
write_dashboard_output <- function(trend_results, config, wave_data,
                                   output_path = NULL, include_sig_matrices = TRUE, run_result = NULL) {

  cat("\n================================================================================\n")
  cat("WRITING DASHBOARD EXCEL OUTPUT\n")
  cat("================================================================================\n\n")

  # Determine output path
  if (is.null(output_path)) {
    output_dir <- get_setting(config, "output_dir", default = NULL)

    if (is.null(output_dir) || !nzchar(trimws(output_dir))) {
      output_dir <- dirname(config$config_path)
    }

    # Ensure output directory exists
    if (!dir.exists(output_dir)) {
      tryCatch({
        dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      }, error = function(e) {
        warning(paste0("Could not create output directory: ", output_dir, ". Using config directory."))
        output_dir <<- dirname(config$config_path)
      })
    }

    # Check for output_file setting first, otherwise auto-generate
    output_file <- get_setting(config, "output_file", default = NULL)
    if (!is.null(output_file) && nzchar(trimws(output_file))) {
      filename <- trimws(output_file)
    } else {
      project_name <- get_setting(config, "project_name", default = "Tracking")
      project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)
      filename <- paste0(project_name, "_Dashboard_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
    }

    output_path <- file.path(output_dir, filename)
  }

  cat(paste0("Output file: ", output_path, "\n"))

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Write Trend Dashboard
  write_trend_dashboard(wb, trend_results, config)

  # Write Significance Matrices (if requested)
  if (include_sig_matrices) {
    write_all_significance_matrices(wb, trend_results, config)
  }

  # ===========================================================================
  # TRS v1.0: Add Run_Status Sheet
  # ===========================================================================
  if (!is.null(run_result) && exists("turas_write_run_status_sheet", mode = "function")) {
    turas_write_run_status_sheet(wb, run_result)
  }

  # Save workbook (TRS v1.0: Use atomic save if available)
  cat(paste0("\nSaving workbook...\n"))
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_path, run_result = run_result, module = "TRACKER")
    if (!save_result$success) {
      tracker_refuse(
        code = "IO_SAVE_FAILED",
        title = "Excel Save Failed",
        problem = sprintf("Failed to save Excel file: %s", save_result$error),
        why_it_matters = "The tracker output could not be written to disk",
        how_to_fix = c("Check that the output directory exists and is writable",
                       "Ensure the file is not open in another program",
                       "Verify sufficient disk space is available"),
        details = list(output_path = output_path, error = save_result$error)
      )
    }
  } else {
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  }

  cat(paste0("\u2713 Dashboard output written to: ", output_path, "\n"))
  cat("================================================================================\n\n")

  return(output_path)
}


#' Write Significance Matrix Report to Excel
#'
#' Creates report with only significance matrices (no dashboard).
#'
#' @param trend_results List of trend results from calculate_all_trends()
#' @param config Configuration object
#' @param wave_data List of wave data frames
#' @param output_path Character. Path for output file (auto-generated if NULL)
#' @return Character. Path to created file
#'
#' @export
write_sig_matrix_output <- function(trend_results, config, wave_data, output_path = NULL, run_result = NULL) {

  cat("\n================================================================================\n")
  cat("WRITING SIGNIFICANCE MATRIX EXCEL OUTPUT\n")
  cat("================================================================================\n\n")

  # Determine output path
  if (is.null(output_path)) {
    output_dir <- get_setting(config, "output_dir", default = NULL)

    if (is.null(output_dir) || !nzchar(trimws(output_dir))) {
      output_dir <- dirname(config$config_path)
    }

    # Ensure output directory exists
    if (!dir.exists(output_dir)) {
      tryCatch({
        dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      }, error = function(e) {
        warning(paste0("Could not create output directory: ", output_dir, ". Using config directory."))
        output_dir <<- dirname(config$config_path)
      })
    }

    # Check for output_file setting first, otherwise auto-generate
    output_file <- get_setting(config, "output_file", default = NULL)
    if (!is.null(output_file) && nzchar(trimws(output_file))) {
      filename <- trimws(output_file)
    } else {
      project_name <- get_setting(config, "project_name", default = "Tracking")
      project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)
      filename <- paste0(project_name, "_SigMatrix_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
    }

    output_path <- file.path(output_dir, filename)
  }

  cat(paste0("Output file: ", output_path, "\n"))

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Write all significance matrices
  write_all_significance_matrices(wb, trend_results, config)

  # ===========================================================================
  # TRS v1.0: Add Run_Status Sheet
  # ===========================================================================
  if (!is.null(run_result) && exists("turas_write_run_status_sheet", mode = "function")) {
    turas_write_run_status_sheet(wb, run_result)
  }

  # Save workbook (TRS v1.0: Use atomic save if available)
  cat(paste0("\nSaving workbook...\n"))
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_path, run_result = run_result, module = "TRACKER")
    if (!save_result$success) {
      tracker_refuse(
        code = "IO_SAVE_FAILED",
        title = "Excel Save Failed",
        problem = sprintf("Failed to save Excel file: %s", save_result$error),
        why_it_matters = "The tracker output could not be written to disk",
        how_to_fix = c("Check that the output directory exists and is writable",
                       "Ensure the file is not open in another program",
                       "Verify sufficient disk space is available"),
        details = list(output_path = output_path, error = save_result$error)
      )
    }
  } else {
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  }

  cat(paste0("\u2713 Significance Matrix output written to: ", output_path, "\n"))
  cat("================================================================================\n\n")

  return(output_path)
}
