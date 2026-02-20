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
#' ready for table and chart rendering.
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

  # Build wave lookup
  wave_lookup <- setNames(wave_labels, waves)

  # Transform each metric into HTML-ready rows
  metric_rows <- lapply(seq_along(crosstab_data$metrics), function(i) {
    m <- crosstab_data$metrics[[i]]
    transform_metric_for_html(m, waves, wave_lookup, segments, baseline_wave, i)
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
    metadata = crosstab_data$metadata
  )
}


#' Transform a Single Metric for HTML
#'
#' @keywords internal
transform_metric_for_html <- function(metric, waves, wave_lookup, segments,
                                       baseline_wave, idx) {

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

      # Format the display value
      display_val <- format_html_value(val, metric$metric_name)

      # Change vs previous
      prev_change <- NULL
      prev_sig <- NULL
      prev_display <- ""
      if (w_idx > 1) {
        prev_change <- seg_data$change_vs_previous[[wid]]
        prev_sig <- seg_data$sig_vs_previous[[wid]]
        if (!is.null(prev_change) && !is.na(prev_change)) {
          prev_display <- format_change_display(prev_change, prev_sig, metric$metric_name)
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
          base_display <- format_change_display(base_change, base_sig, metric$metric_name)
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
    question_text = metric$question_text %||% "",
    segment_cells = segment_cells
  )
}


#' Format a Value for HTML Display
#'
#' @keywords internal
format_html_value <- function(val, metric_name) {
  if (is.na(val)) return("&mdash;")

  if (grepl("(pct|box|range|proportion|category|any)", metric_name)) {
    paste0(round(val * 100, 0), "%")
  } else if (metric_name %in% c("nps_score", "nps")) {
    sprintf("%+d", round(val))
  } else {
    format(round(val, 1), nsmall = 1)
  }
}


#' Format Change Value with Significance Arrow for HTML
#'
#' @keywords internal
format_change_display <- function(change_val, sig_val, metric_name) {
  if (is.na(change_val)) return("")

  # Format the numeric change
  if (grepl("(pct|box|range|proportion|category|any)", metric_name)) {
    change_str <- paste0(ifelse(change_val > 0, "+", ""), round(change_val * 100, 0), "pp")
  } else if (metric_name %in% c("nps_score", "nps")) {
    change_str <- paste0(ifelse(change_val > 0, "+", ""), round(change_val, 0))
  } else {
    change_str <- paste0(ifelse(change_val > 0, "+", ""), round(change_val, 1))
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

  sprintf('<span class="change-val %s">%s%s</span>',
          css_class, change_str, if (nzchar(arrow)) paste0(" ", arrow) else "")
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
