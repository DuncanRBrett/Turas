# ==============================================================================
# TurasTracker HTML Report - Data Transformer
# ==============================================================================
# Transforms tracking crosstab data into HTML-ready structures.
# Flattens metrics into table rows, generates chart JSON, builds sparklines.
# VERSION: 1.0.0
# ==============================================================================


#' Transform Tracking Crosstab Data for HTML
#'
#' Converts the crosstab_data structure into flat, HTML-friendly structures
#' ready for table and chart rendering. Reads decimal place settings from
#' config for consistent formatting with the Excel output.
#'
#' @param crosstab_data List. Output from build_tracking_crosstab()
#' @param config List. Tracker configuration object
#' @return List with transformed data for HTML rendering
#' @export
transform_tracker_for_html <- function(crosstab_data, config) {

  waves <- crosstab_data$waves
  wave_labels <- crosstab_data$wave_labels
  segments <- crosstab_data$banner_segments
  baseline_wave <- crosstab_data$baseline_wave
  sections <- crosstab_data$sections

  # Read decimal settings from config (same pattern as tracking_crosstab_excel.R)
  dp_ratings <- if (!is.null(config)) get_setting(config, "decimal_places_ratings", default = 2) else 2
  dp_pct <- if (!is.null(config)) get_setting(config, "decimal_places_percentages", default = 0) else 0
  dp_nps <- if (!is.null(config)) get_setting(config, "decimal_places_nps", default = 2) else 2
  dp_ratings <- as.integer(dp_ratings)
  dp_pct <- as.integer(dp_pct)
  dp_nps <- as.integer(dp_nps)

  decimal_config <- list(dp_ratings = dp_ratings, dp_pct = dp_pct, dp_nps = dp_nps)

  # Build wave lookup
  wave_lookup <- setNames(wave_labels, waves)

  # Transform each metric into HTML-ready rows
  metric_rows <- lapply(seq_along(crosstab_data$metrics), function(i) {
    m <- crosstab_data$metrics[[i]]
    transform_metric_for_html(m, waves, wave_lookup, segments, baseline_wave, i,
                               decimal_config = decimal_config)
  })

  # Build chart data for each metric (JSON-ready)
  chart_data <- lapply(seq_along(crosstab_data$metrics), function(i) {
    m <- crosstab_data$metrics[[i]]
    build_chart_data(m, waves, wave_labels, segments)
  })

  # Build sparkline data for each metric per segment
  sparkline_data <- lapply(seq_along(crosstab_data$metrics), function(i) {
    m <- crosstab_data$metrics[[i]]
    build_sparkline_data(m, waves, segments)
  })

  list(
    metric_rows = metric_rows,
    chart_data = chart_data,
    sparkline_data = sparkline_data,
    waves = waves,
    wave_labels = wave_labels,
    wave_lookup = wave_lookup,
    segments = segments,
    baseline_wave = baseline_wave,
    sections = sections,
    n_metrics = length(crosstab_data$metrics),
    metadata = crosstab_data$metadata,
    decimal_config = decimal_config
  )
}


#' Transform a Single Metric for HTML
#'
#' @keywords internal
transform_metric_for_html <- function(metric, waves, wave_lookup, segments,
                                       baseline_wave, idx,
                                       decimal_config = list(dp_ratings = 2, dp_pct = 0, dp_nps = 2)) {

  metric_id <- paste0("metric_", idx)

  # Build per-segment, per-wave cell data
  segment_cells <- list()

  for (seg_name in segments) {
    seg_data <- metric$segments[[seg_name]]
    if (is.null(seg_data)) next

    cells <- list()
    for (w_idx in seq_along(waves)) {
      wid <- waves[w_idx]
      val <- seg_data$values[[wid]]
      n_val <- seg_data$n[[wid]]

      # Format the display value (with config-driven decimal places)
      display_val <- format_html_value(val, metric$metric_name,
                                        dp_pct = decimal_config$dp_pct,
                                        dp_ratings = decimal_config$dp_ratings,
                                        dp_nps = decimal_config$dp_nps)

      # Change vs previous
      prev_change <- NULL
      prev_sig <- NULL
      prev_display <- ""
      if (w_idx > 1) {
        prev_change <- seg_data$change_vs_previous[[wid]]
        prev_sig <- seg_data$sig_vs_previous[[wid]]
        if (!is.null(prev_change) && !is.na(prev_change)) {
          prev_display <- format_change_display(prev_change, prev_sig, metric$metric_name,
                                                 dp_pct = decimal_config$dp_pct,
                                                 dp_ratings = decimal_config$dp_ratings,
                                                 dp_nps = decimal_config$dp_nps)
        }
      }

      # Change vs baseline
      base_change <- NULL
      base_sig <- NULL
      base_display <- ""
      if (wid != baseline_wave) {
        base_change <- seg_data$change_vs_baseline[[wid]]
        base_sig <- seg_data$sig_vs_baseline[[wid]]
        if (!is.null(base_change) && !is.na(base_change)) {
          base_display <- format_change_display(base_change, base_sig, metric$metric_name,
                                                 dp_pct = decimal_config$dp_pct,
                                                 dp_ratings = decimal_config$dp_ratings,
                                                 dp_nps = decimal_config$dp_nps)
        }
      }

      cells[[wid]] <- list(
        wave_id = wid,
        value = val,
        display_value = display_val,
        n = n_val,
        change_vs_prev = prev_change,
        sig_vs_prev = prev_sig,
        display_vs_prev = prev_display,
        change_vs_base = base_change,
        sig_vs_base = base_sig,
        display_vs_base = base_display,
        is_baseline = (wid == baseline_wave),
        is_first_wave = (w_idx == 1)
      )
    }
    segment_cells[[seg_name]] <- cells
  }

  list(
    metric_id = metric_id,
    question_code = metric$question_code,
    metric_label = metric$metric_label,
    metric_name = metric$metric_name,
    section = metric$section,
    sort_order = metric$sort_order,
    question_type = metric$question_type,
    question_text = if (is.null(metric$question_text) || is.na(metric$question_text)) "" else metric$question_text,
    segment_cells = segment_cells
  )
}


#' Format a Value for HTML Display
#'
#' Values are already on their natural scale (percentages on 0-100, means as-is,
#' NPS on -100 to +100). No scaling is applied here — only formatting and
#' rounding per config decimal place settings.
#'
#' @param val Numeric. The value to format.
#' @param metric_name Character. The metric name (e.g., "mean", "top2_box", "nps_score").
#' @param dp_pct Integer. Decimal places for percentage metrics (default 0).
#' @param dp_ratings Integer. Decimal places for rating/mean metrics (default 2).
#' @param dp_nps Integer. Decimal places for NPS metrics (default 2).
#' @return Character. Formatted HTML string.
#' @keywords internal
format_html_value <- function(val, metric_name, dp_pct = 0, dp_ratings = 2, dp_nps = 2) {
  if (is.na(val)) return("&mdash;")

  if (grepl("(pct|box|range|proportion|category|any)", metric_name)) {
    # Values already on 0-100 scale — just round and append %
    paste0(format(round(val, dp_pct), nsmall = dp_pct), "%")
  } else if (metric_name %in% c("nps_score", "nps")) {
    sprintf("%+.*f", dp_nps, val)
  } else {
    format(round(val, dp_ratings), nsmall = dp_ratings)
  }
}


#' Format Change Value with Significance Arrow for HTML
#'
#' Change values are already in their natural units: percentage changes in
#' percentage points (pp), rating changes as differences, NPS as integer change.
#' No scaling is applied — only formatting.
#'
#' Arrows are wrapped in a separate span so they can be hidden independently
#' by the significance toggle (body.hide-significance .sig-arrow { display: none; }).
#'
#' @param dp_pct Integer. Decimal places for percentage change (default 0).
#' @param dp_ratings Integer. Decimal places for rating change (default 2).
#' @param dp_nps Integer. Decimal places for NPS change (default 2).
#' @keywords internal
format_change_display <- function(change_val, sig_val, metric_name,
                                   dp_pct = 0, dp_ratings = 2, dp_nps = 2) {
  if (is.na(change_val)) return("")

  # Format the numeric change — values are already on natural scale
  prefix <- ifelse(change_val > 0, "+", "")
  if (grepl("(pct|box|range|proportion|category|any)", metric_name)) {
    change_str <- paste0(prefix, round(change_val, dp_pct), "pp")
  } else if (metric_name %in% c("nps_score", "nps")) {
    change_str <- paste0(prefix, round(change_val, dp_nps))
  } else {
    change_str <- paste0(prefix, format(round(change_val, dp_ratings), nsmall = dp_ratings))
  }

  # Determine CSS class and arrow
  if (isTRUE(sig_val)) {
    if (change_val > 0) {
      css_class <- "sig-up"
      arrow <- "&#x2191;"  # up arrow
    } else if (change_val < 0) {
      css_class <- "sig-down"
      arrow <- "&#x2193;"  # down arrow
    } else {
      css_class <- "sig-flat"
      arrow <- "&#x2192;"  # right arrow
    }
  } else if (isFALSE(sig_val)) {
    css_class <- "not-sig"
    arrow <- "&#x2192;"
  } else {
    # NA significance — no arrow
    css_class <- "sig-na"
    arrow <- ""
  }

  # Wrap arrow in .sig-arrow span for toggle control
  arrow_html <- if (nzchar(arrow)) {
    sprintf(' <span class="sig-arrow">%s</span>', arrow)
  } else {
    ""
  }

  sprintf('<span class="change-val %s">%s%s</span>',
          css_class, change_str, arrow_html)
}


#' Build Chart Data for a Metric (JSON-ready)
#'
#' Creates the data structure that will be embedded as JSON in data attributes
#' for JavaScript chart rendering.
#'
#' @keywords internal
build_chart_data <- function(metric, waves, wave_labels, segments) {

  series <- list()
  for (seg_name in segments) {
    seg_data <- metric$segments[[seg_name]]
    if (is.null(seg_data)) next

    values <- vapply(waves, function(wid) {
      v <- seg_data$values[[wid]]
      if (is.null(v) || is.na(v)) NA_real_ else v
    }, numeric(1))

    n_values <- vapply(waves, function(wid) {
      n <- seg_data$n[[wid]]
      if (is.null(n) || is.na(n)) NA_integer_ else n
    }, integer(1))

    series[[seg_name]] <- list(
      name = seg_name,
      values = unname(values),
      n = unname(n_values)
    )
  }

  list(
    metric_id = paste0("metric_", which(sapply(segments, function(s) TRUE))[1]),
    metric_label = metric$metric_label,
    metric_name = metric$metric_name,
    question_code = metric$question_code,
    wave_ids = unname(waves),
    wave_labels = unname(wave_labels),
    series = series,
    is_percentage = grepl("(pct|box|range|proportion|category|any)", metric$metric_name),
    is_nps = metric$metric_name %in% c("nps_score", "nps")
  )
}


#' Build Sparkline Data for a Metric
#'
#' Creates coordinate arrays for inline SVG sparklines.
#'
#' @keywords internal
build_sparkline_data <- function(metric, waves, segments) {

  sparklines <- list()

  for (seg_name in segments) {
    seg_data <- metric$segments[[seg_name]]
    if (is.null(seg_data)) next

    values <- vapply(waves, function(wid) {
      v <- seg_data$values[[wid]]
      if (is.null(v) || is.na(v)) NA_real_ else v
    }, numeric(1))

    sparklines[[seg_name]] <- unname(values)
  }

  sparklines
}
