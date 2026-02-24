# ==============================================================================
# TurasTracker HTML Report - Table Builder
# ==============================================================================
# Builds HTML <table> elements for the tracking crosstab.
# Uses string concatenation (sprintf/paste0) + htmltools::HTML for output.
# VERSION: 1.0.0
# ==============================================================================


# ------------------------------------------------------------------------------
# TRACKING TABLE HELPERS
# ------------------------------------------------------------------------------

#' Build HTML for Base (n=) Row
#'
#' Generates the base sample size row with low-base warnings.
#' Uses max n across all metrics per segment/wave.
#'
#' @param metric_rows List. All metric row data
#' @param segments Character vector. Banner segments
#' @param waves Character vector. Wave IDs
#' @param min_base Integer. Minimum base threshold
#' @return Character vector of HTML parts
#' @keywords internal
build_table_base_row_html <- function(metric_rows, segments, waves, min_base) {
  parts <- c()

  # Pre-compute max n per segment per wave across all metrics
  base_n <- list()
  for (seg_name in segments) {
    base_n[[seg_name]] <- list()
    for (wid in waves) {
      max_n <- NA_integer_
      for (mr in metric_rows) {
        cell <- mr$segment_cells[[seg_name]][[wid]]
        if (!is.null(cell) && !is.na(cell$n)) {
          if (is.na(max_n) || cell$n > max_n) max_n <- cell$n
        }
      }
      base_n[[seg_name]][[wid]] <- max_n
    }
  }

  parts <- c(parts, '<tr class="tk-base-row">')
  parts <- c(parts, '<td class="tk-td tk-label-col tk-sticky-col tk-base-label">Base (n=)</td>')
  for (seg_idx in seq_along(segments)) {
    seg_name <- segments[seg_idx]
    for (wid in waves) {
      n_val <- base_n[[seg_name]][[wid]]
      if (!is.na(n_val) && n_val < min_base) {
        n_display <- sprintf('<span class="tk-low-base">%s &#x26A0;</span>', n_val)
      } else {
        n_display <- if (!is.na(n_val)) as.character(n_val) else ""
      }
      parts <- c(parts, sprintf(
        '<td class="tk-td tk-base-cell" data-segment="%s" data-n="%s">%s</td>',
        htmltools::htmlEscape(seg_name),
        if (!is.na(n_val)) n_val else "",
        n_display
      ))
    }
  }
  parts <- c(parts, '</tr>')

  return(parts)
}


#' Build HTML for a Single Metric Row (Value + Change Rows)
#'
#' Generates the value row, vs-previous change row, and vs-baseline change row
#' for a single metric.
#'
#' @param mr List. Metric row data
#' @param m_idx Integer. Metric index
#' @param chart_json Character. JSON chart data
#' @param sparkline_data List. Sparkline data for this metric
#' @param segments Character vector. Banner segments
#' @param waves Character vector. Wave IDs
#' @param n_waves Integer
#' @param min_base Integer. Low base threshold
#' @param total_cols Integer. Total column count
#' @param brand_colour Character. Brand colour for sparklines
#' @param current_section Character. Current section name
#' @return List with $parts (character vector) and $section (updated section)
#' @keywords internal
build_table_metric_row_html <- function(mr, m_idx, chart_json, sparkline_data,
                                         segments, waves, n_waves, min_base,
                                         total_cols, brand_colour, current_section) {
  parts <- c()

  section <- if (is.na(mr$section) || mr$section == "") "(Ungrouped)" else mr$section

  # Section divider (clickable to collapse/expand)
  if (section != current_section) {
    current_section <- section
    parts <- c(parts, sprintf(
      '<tr class="tk-section-row"><td colspan="%d" class="tk-section-cell" onclick="toggleOverviewSection(this)"><span class="section-chevron">&#x25BC;</span> %s</td></tr>',
      total_cols, htmltools::htmlEscape(section)
    ))
  }

  # ---- Metric value row ----
  m_type <- classify_metric_type(mr$metric_name)
  parts <- c(parts, sprintf(
    '<tr class="tk-metric-row" data-metric-id="%s" data-q-code="%s" data-metric-type="%s" data-section="%s" data-chart=\'%s\'>',
    mr$metric_id,
    htmltools::htmlEscape(mr$question_code),
    m_type,
    htmltools::htmlEscape(section),
    htmltools::htmlEscape(as.character(chart_json))
  ))

  # Label cell with sparkline
  sparkline_svg <- ""
  first_seg <- segments[1]
  if (!is.null(sparkline_data[[first_seg]])) {
    sparkline_svg <- build_sparkline_svg(
      sparkline_data[[first_seg]],
      colour = brand_colour
    )
  }

  parts <- c(parts, sprintf(
    '<td class="tk-td tk-label-col tk-sticky-col"><button class="tk-row-hide-btn" onclick="toggleRowVisibility(\'%s\')" title="Hide this metric">&#x1F441;</button><span class="tk-metric-label">%s</span><span class="tk-sparkline-wrap">%s</span><button class="tk-add-chart-btn" data-metric-id="%s" onclick="addToChart(\'%s\')" title="Add to chart">&#x1F4C8;</button></td>',
    mr$metric_id,
    htmltools::htmlEscape(mr$metric_label),
    sparkline_svg,
    mr$metric_id, mr$metric_id
  ))

  # Data cells per segment per wave
  for (seg_idx in seq_along(segments)) {
    seg_name <- segments[seg_idx]
    cells <- mr$segment_cells[[seg_name]]

    for (wid in waves) {
      cell <- cells[[wid]]
      if (is.null(cell)) {
        parts <- c(parts, sprintf(
          '<td class="tk-td tk-value-cell" data-segment="%s">&mdash;</td>',
          htmltools::htmlEscape(seg_name)
        ))
        next
      }

      # Sort value for column sorting
      sort_val <- if (!is.na(cell$value)) cell$value else ""
      is_latest <- (wid == waves[n_waves])
      latest_class <- if (is_latest) " tk-latest-wave" else ""
      # Dim cells with low base
      low_base_class <- if (!is.na(cell$n) && cell$n < min_base) " tk-low-base-dim" else ""

      parts <- c(parts, sprintf(
        '<td class="tk-td tk-value-cell%s%s" data-segment="%s" data-wave="%s" data-sort-val="%s" data-n="%s">%s</td>',
        latest_class,
        low_base_class,
        htmltools::htmlEscape(seg_name),
        htmltools::htmlEscape(wid),
        sort_val,
        if (!is.na(cell$n)) cell$n else "",
        cell$display_value
      ))
    }
  }
  parts <- c(parts, '</tr>')

  # ---- vs Previous change row ----
  parts <- c(parts, sprintf(
    '<tr class="tk-change-row tk-vs-prev" data-metric-id="%s">',
    mr$metric_id
  ))
  parts <- c(parts, '<td class="tk-td tk-label-col tk-sticky-col tk-change-label">vs Prev</td>')

  for (seg_idx in seq_along(segments)) {
    seg_name <- segments[seg_idx]
    cells <- mr$segment_cells[[seg_name]]

    for (wid in waves) {
      cell <- cells[[wid]]
      content <- ""
      if (!is.null(cell) && !cell$is_first_wave && nzchar(cell$display_vs_prev)) {
        content <- cell$display_vs_prev
      }
      if (nzchar(content)) {
        parts <- c(parts, sprintf(
          '<td class="tk-td tk-change-cell" data-segment="%s">%s</td>',
          htmltools::htmlEscape(seg_name),
          content
        ))
      } else {
        parts <- c(parts, sprintf(
          '<td data-segment="%s"></td>',
          htmltools::htmlEscape(seg_name)
        ))
      }
    }
  }
  parts <- c(parts, '</tr>')

  # ---- vs Baseline change row ----
  parts <- c(parts, sprintf(
    '<tr class="tk-change-row tk-vs-base" data-metric-id="%s">',
    mr$metric_id
  ))
  parts <- c(parts, '<td class="tk-td tk-label-col tk-sticky-col tk-change-label">vs Base</td>')

  for (seg_idx in seq_along(segments)) {
    seg_name <- segments[seg_idx]
    cells <- mr$segment_cells[[seg_name]]

    for (wid in waves) {
      cell <- cells[[wid]]
      content <- ""
      if (!is.null(cell) && !cell$is_baseline && nzchar(cell$display_vs_base)) {
        content <- cell$display_vs_base
      }
      if (nzchar(content)) {
        parts <- c(parts, sprintf(
          '<td class="tk-td tk-change-cell" data-segment="%s">%s</td>',
          htmltools::htmlEscape(seg_name),
          content
        ))
      } else {
        parts <- c(parts, sprintf(
          '<td data-segment="%s"></td>',
          htmltools::htmlEscape(seg_name)
        ))
      }
    }
  }
  parts <- c(parts, '</tr>')

  return(list(parts = parts, section = current_section))
}


#' Build Tracking Crosstab Table
#'
#' Creates the complete HTML table for the tracking crosstab.
#' Rows = metrics with change sub-rows.
#' Columns = waves, shown per active banner segment.
#' Base row appears at the top with low-base warnings when n < min_base.
#'
#' @param html_data List. Output from transform_tracker_for_html()
#' @param config List. Tracker configuration
#' @return htmltools::HTML object containing the table
#' @export
build_tracking_table <- function(html_data, config) {

  waves <- html_data$waves
  wave_labels <- html_data$wave_labels
  segments <- html_data$segments
  n_waves <- length(waves)
  min_base <- as.integer(get_setting(config, "significance_min_base", default = 30) %||% 30)

  brand_colour <- get_setting(config, "brand_colour", default = "#323367") %||% "#323367"
  segment_colours <- get_segment_colours(segments, brand_colour)

  parts <- c()

  # "Showing" label above table
  first_seg <- segments[1]
  parts <- c(parts, sprintf(
    '<div class="tk-segment-showing" id="tk-segment-showing">Showing: <strong>%s</strong></div>',
    htmltools::htmlEscape(first_seg)
  ))

  # Table wrapper
  parts <- c(parts, '<div class="tk-table-wrapper">')
  parts <- c(parts, '<table class="tk-table" id="tk-crosstab-table">')

  # ---- THEAD: Segment indicator row + wave header row ----
  parts <- c(parts, '<thead>')

  # Segment colour indicator row (with segment name labels)
  parts <- c(parts, '<tr class="tk-segment-indicator-row">')
  parts <- c(parts, '<th class="tk-segment-indicator tk-sticky-col"></th>')  # Empty label cell
  for (seg_idx in seq_along(segments)) {
    seg_name <- segments[seg_idx]
    seg_colour <- segment_colours[seg_idx]
    # Use text colour that contrasts with the background (luminance via weighted RGB sum)
    seg_rgb <- as.numeric(grDevices::col2rgb(seg_colour))
    seg_lum <- seg_rgb[1] * 0.299 + seg_rgb[2] * 0.587 + seg_rgb[3] * 0.114
    text_colour <- if (seg_lum > 150) "#1e293b" else "#ffffff"
    parts <- c(parts, sprintf(
      '<th class="tk-segment-indicator" data-segment="%s" colspan="%d" style="background-color:%s;color:%s;font-size:11px;font-weight:600;text-align:center;letter-spacing:0.02em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">%s</th>',
      htmltools::htmlEscape(seg_name),
      n_waves,
      seg_colour, text_colour,
      htmltools::htmlEscape(seg_name)
    ))
  }
  parts <- c(parts, '</tr>')

  parts <- c(parts, '<tr class="tk-wave-header-row">')
  parts <- c(parts, '<th class="tk-th tk-label-col tk-sticky-col">Metric</th>')

  col_idx <- 1  # 0 is the label column
  for (seg_idx in seq_along(segments)) {
    seg_name <- segments[seg_idx]
    for (w_idx in seq_along(waves)) {
      parts <- c(parts, sprintf(
        '<th class="tk-th tk-wave-header tk-sortable" data-segment="%s" data-wave="%s" data-col-index="%d" onclick="sortOverviewColumn(this)" title="Click to sort">%s</th>',
        htmltools::htmlEscape(seg_name),
        htmltools::htmlEscape(waves[w_idx]),
        col_idx,
        htmltools::htmlEscape(wave_labels[w_idx])
      ))
      col_idx <- col_idx + 1
    }
  }
  parts <- c(parts, '</tr>')
  parts <- c(parts, '</thead>')

  # ---- TBODY: Base row at top, then section headers + metric rows ----
  parts <- c(parts, '<tbody>')
  total_cols <- 1 + length(segments) * n_waves

  # Base (n) row at the TOP of the table
  if (length(html_data$metric_rows) > 0) {
    parts <- c(parts, build_table_base_row_html(html_data$metric_rows, segments, waves, min_base))
  }

  # Metric rows with value + change sub-rows
  current_section <- ""
  for (m_idx in seq_along(html_data$metric_rows)) {
    mr <- html_data$metric_rows[[m_idx]]
    chart_json <- jsonlite::toJSON(html_data$chart_data[[m_idx]], auto_unbox = TRUE)
    sparkline_data <- html_data$sparkline_data[[m_idx]]

    row_result <- build_table_metric_row_html(
      mr, m_idx, chart_json, sparkline_data,
      segments, waves, n_waves, min_base,
      total_cols, brand_colour, current_section
    )
    parts <- c(parts, row_result$parts)
    current_section <- row_result$section
  }

  parts <- c(parts, '</tbody>')
  parts <- c(parts, '</table>')
  parts <- c(parts, '</div>')

  htmltools::HTML(paste(parts, collapse = "\n"))
}

