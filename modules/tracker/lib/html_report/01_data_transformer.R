# ==============================================================================
# TurasTracker HTML Report - Data Transformer
# ==============================================================================
# Transforms tracking crosstab data into HTML-ready structures.
# Flattens metrics into table rows, generates chart JSON, builds sparklines.
# VERSION: 1.0.0
# ==============================================================================


#' Classify Metric Name into Data Type
#'
#' Maps metric_name to one of five data type categories for type separation
#' and heatmap grouping. Shared classification used by data transformer,
#' heatmap builder, and chart type guards.
#'
#' @param metric_name Character. The metric name (e.g., "mean", "top2_box", "nps_score")
#' @return Character. Data type key: "mean", "pct", "pct_response", "nps", or "other"
#' @keywords internal
classify_data_type <- function(metric_name) {
  if (metric_name == "mean" || grepl("(mean|index|composite)", metric_name)) return("mean")
  if (metric_name %in% c("nps_score", "nps", "promoters_pct", "passives_pct", "detractors_pct")) return("nps")
  # Top-box / bottom-box / range — derived from a scale question

  if (grepl("(box|range)", metric_name)) return("pct")
  # Standalone proportions — brand awareness, category %, multi-mention %
  if (grepl("(category|proportion|any)", metric_name)) return("pct_response")
  # Other percentage specs (fallback)
  if (grepl("pct", metric_name)) return("pct")
  "other"
}


#' Classify Metric Name into Display Type
#'
#' Maps internal metric_name values to human-readable filter categories.
#' Similar to classify_data_type() but used for UI display grouping.
#' Relocated from removed 03d_metrics_builder.R.
#'
#' @param metric_name Character. The metric name (e.g., "mean", "top2_box", "nps_score")
#' @return Character. Display type key: "mean", "pct", "pct_response", "nps", or "other"
#' @keywords internal
classify_metric_type <- function(metric_name) {
  if (metric_name == "mean") return("mean")
  if (metric_name %in% c("nps_score", "nps", "promoters_pct", "passives_pct", "detractors_pct")) return("nps")
  if (grepl("(box|range)", metric_name)) return("pct")
  if (grepl("(category|proportion|any)", metric_name)) return("pct_response")
  if (grepl("pct", metric_name)) return("pct")
  "other"
}


#' Derive Segment Groups from Segment Names
#'
#' Splits segments into hierarchical groups based on the prefix before
#' the first underscore. "Total" is placed in its own standalone group.
#' Relocated from removed 03d_metrics_builder.R.
#'
#' @param segments Character vector of segment names
#' @return List with: standalone (character vector), groups (named list of character vectors)
#' @keywords internal
derive_segment_groups <- function(segments) {
  standalone <- character(0)
  groups <- list()

  for (seg in segments) {
    if (seg == "Total") {
      standalone <- c(standalone, seg)
      next
    }
    underscore_pos <- regexpr("_", seg, fixed = TRUE)
    if (underscore_pos > 0) {
      group_name <- substr(seg, 1, underscore_pos - 1)
    } else {
      group_name <- seg
    }
    if (is.null(groups[[group_name]])) groups[[group_name]] <- character(0)
    groups[[group_name]] <- c(groups[[group_name]], seg)
  }

  list(standalone = standalone, groups = groups)
}


#' Get Human-Readable Metric Type Descriptor
#'
#' Returns a clean subtitle string describing the metric type,
#' e.g. "Mean Score", "Top 2 Box (%)", "NPS Score".
#' Relocated from removed 03d_metrics_builder.R.
#'
#' @param metric_name Character. Internal metric name (e.g., "mean", "top2_box")
#' @return Character. Human-readable metric type descriptor
#' @keywords internal
metric_type_descriptor <- function(metric_name) {
  if (metric_name == "mean") return("Mean Score")
  if (metric_name == "nps_score" || metric_name == "nps") return("NPS Score")
  if (metric_name == "promoters_pct") return("NPS \u2014 Promoters (%)")
  if (metric_name == "passives_pct") return("NPS \u2014 Passives (%)")
  if (metric_name == "detractors_pct") return("NPS \u2014 Detractors (%)")
  if (grepl("^top[_]?2[_]?box", metric_name)) return("Top 2 Box (%)")
  if (grepl("^top[_]?3[_]?box", metric_name)) return("Top 3 Box (%)")
  if (grepl("^bottom[_]?2[_]?box", metric_name)) return("Bottom 2 Box (%)")
  if (grepl("^bottom[_]?3[_]?box", metric_name)) return("Bottom 3 Box (%)")
  if (grepl("^box_", metric_name)) return("Box Score (%)")
  if (grepl("^category_", metric_name)) return("% Response")
  if (grepl("^range_", metric_name)) return("Range (%)")
  if (grepl("(proportion|any)", metric_name)) return("% Response")
  m_type <- classify_metric_type(metric_name)
  if (m_type == "mean") return("Mean Score")
  if (m_type == "nps") return("NPS (%)")
  if (m_type == "pct_response") return("% Response")
  if (m_type == "pct") return("Percentage (%)")
  "Metric"
}


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

      # Significance badge for value cell (vs previous wave)
      sig_badge <- ""
      if (!is.null(prev_sig) && !is.na(prev_sig) && isTRUE(prev_sig) &&
          !is.null(prev_change) && !is.na(prev_change)) {
        if (prev_change > 0) {
          sig_badge <- '<span class="tk-sig tk-sig-up">&#x25B2;</span>'
        } else if (prev_change < 0) {
          sig_badge <- '<span class="tk-sig tk-sig-down">&#x25BC;</span>'
        }
      }

      cells[[wid]] <- list(
        wave_id = wid,
        value = val,
        display_value = display_val,
        sig_badge = sig_badge,
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

  # Classify data type for type separation and heatmap grouping
  data_type <- classify_data_type(metric$metric_name)

  # Determine if this is the "headline" metric for its question
  # Headline: mean for ratings, nps_score for NPS, first pct metric otherwise
  is_headline <- (metric$metric_name == "mean" && data_type == "mean") ||
                 (metric$metric_name == "nps_score" && data_type == "nps") ||
                 (data_type == "pct" && grepl("^(top2_box|top_box|proportion)", metric$metric_name))

  list(
    metric_id = metric_id,
    question_code = metric$question_code,
    metric_label = metric$metric_label,
    metric_name = metric$metric_name,
    section = metric$section,
    sort_order = metric$sort_order,
    question_type = metric$question_type,
    question_text = if (is.null(metric$question_text) || is.na(metric$question_text)) "" else metric$question_text,
    data_type = data_type,
    is_headline = is_headline,
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
      if (is.null(n) || is.na(n)) NA_real_ else as.numeric(n)
    }, numeric(1))

    series[[seg_name]] <- list(
      name = seg_name,
      values = unname(values),
      n = unname(n_values)
    )
  }

  # Determine scale_max for rating questions (used by chart axis scaling)
  is_pct <- grepl("(pct|box|range|proportion|category|any)", metric$metric_name)
  is_nps <- metric$metric_name %in% c("nps_score", "nps")
  scale_max <- NULL
  if (!is_pct && !is_nps) {
    # Infer scale from data: collect all non-NA values
    all_vals <- unlist(lapply(series, function(s) s$values), use.names = FALSE)
    all_vals <- all_vals[!is.na(all_vals)]
    if (length(all_vals) > 0) {
      mx <- max(all_vals, na.rm = TRUE)
      scale_max <- if (mx <= 5.5) 5L else if (mx <= 10.5) 10L else ceiling(mx)
    }
  }

  list(
    metric_id = paste0("metric_", which(sapply(segments, function(s) TRUE))[1]),
    metric_label = metric$metric_label,
    metric_name = metric$metric_name,
    question_code = metric$question_code,
    wave_ids = unname(waves),
    wave_labels = unname(wave_labels),
    series = series,
    is_percentage = is_pct,
    is_nps = is_nps,
    scale_max = scale_max
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
