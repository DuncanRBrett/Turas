# ==============================================================================
# TurasTracker HTML Report - Table Builder
# ==============================================================================
# Builds HTML <table> elements for the tracking crosstab.
# Uses string concatenation (sprintf/paste0) + htmltools::HTML for output.
# VERSION: 1.0.0
# ==============================================================================


#' Build Tracking Crosstab Table
#'
#' Creates the complete HTML table for the tracking crosstab.
#' Rows = metrics with change sub-rows.
#' Columns = waves, shown per active banner segment.
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

  brand_colour <- get_setting(config, "brand_colour", default = "#323367") %||% "#323367"
  segment_colours <- get_segment_colours(segments, brand_colour)

  parts <- c()

  # Table wrapper
  parts <- c(parts, '<div class="tk-table-wrapper">')
  parts <- c(parts, '<table class="tk-table" id="tk-crosstab-table">')

  # ---- THEAD: Segment header + Wave header ----
  parts <- c(parts, '<thead>')

  # Row 1: Segment headers (merged across wave columns)
  parts <- c(parts, '<tr class="tk-segment-header-row">')
  parts <- c(parts, '<th class="tk-th tk-label-col tk-sticky-col" rowspan="2">Metric</th>')

  for (seg_idx in seq_along(segments)) {
    seg_name <- segments[seg_idx]
    seg_colour <- segment_colours[seg_idx]
    parts <- c(parts, sprintf(
      '<th class="tk-th tk-segment-header bg-%s" colspan="%d" data-segment="%s" style="background-color:%s;color:#fff">%s</th>',
      make_css_safe(seg_name), n_waves,
      htmltools::htmlEscape(seg_name),
      seg_colour,
      htmltools::htmlEscape(seg_name)
    ))
  }
  parts <- c(parts, '</tr>')

  # Row 2: Wave headers (repeated per segment)
  parts <- c(parts, '<tr class="tk-wave-header-row">')
  for (seg_idx in seq_along(segments)) {
    seg_name <- segments[seg_idx]
    for (w_idx in seq_along(waves)) {
      parts <- c(parts, sprintf(
        '<th class="tk-th tk-wave-header bg-%s" data-segment="%s" data-wave="%s">%s</th>',
        make_css_safe(seg_name),
        htmltools::htmlEscape(seg_name),
        htmltools::htmlEscape(waves[w_idx]),
        htmltools::htmlEscape(wave_labels[w_idx])
      ))
    }
  }
  parts <- c(parts, '</tr>')
  parts <- c(parts, '</thead>')

  # ---- TBODY: Section headers + Metric rows ----
  parts <- c(parts, '<tbody>')
  current_section <- ""
  total_cols <- 1 + length(segments) * n_waves

  for (m_idx in seq_along(html_data$metric_rows)) {
    mr <- html_data$metric_rows[[m_idx]]
    chart_json <- jsonlite::toJSON(html_data$chart_data[[m_idx]], auto_unbox = TRUE)
    sparkline_data <- html_data$sparkline_data[[m_idx]]

    section <- if (is.na(mr$section) || mr$section == "") "(Ungrouped)" else mr$section

    # Section divider
    if (section != current_section) {
      current_section <- section
      parts <- c(parts, sprintf(
        '<tr class="tk-section-row"><td colspan="%d" class="tk-section-cell">%s</td></tr>',
        total_cols, htmltools::htmlEscape(section)
      ))
    }

    # ---- Metric value row ----
    parts <- c(parts, sprintf(
      '<tr class="tk-metric-row" data-metric-id="%s" data-q-code="%s" data-chart=\'%s\'>',
      mr$metric_id,
      htmltools::htmlEscape(mr$question_code),
      chart_json
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
      '<td class="tk-td tk-label-col tk-sticky-col"><span class="tk-metric-label">%s</span><span class="tk-sparkline-wrap">%s</span></td>',
      htmltools::htmlEscape(mr$metric_label),
      sparkline_svg
    ))

    # Data cells per segment per wave
    for (seg_idx in seq_along(segments)) {
      seg_name <- segments[seg_idx]
      cells <- mr$segment_cells[[seg_name]]

      for (wid in waves) {
        cell <- cells[[wid]]
        if (is.null(cell)) {
          parts <- c(parts, sprintf(
            '<td class="tk-td tk-value-cell bg-%s" data-segment="%s">&mdash;</td>',
            make_css_safe(seg_name), htmltools::htmlEscape(seg_name)
          ))
          next
        }

        # Sort value for column sorting
        sort_val <- if (!is.na(cell$value)) cell$value else ""

        parts <- c(parts, sprintf(
          '<td class="tk-td tk-value-cell bg-%s" data-segment="%s" data-wave="%s" data-sort-val="%s" data-n="%s">%s</td>',
          make_css_safe(seg_name),
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
        parts <- c(parts, sprintf(
          '<td class="tk-td tk-change-cell bg-%s" data-segment="%s">%s</td>',
          make_css_safe(seg_name),
          htmltools::htmlEscape(seg_name),
          content
        ))
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
        parts <- c(parts, sprintf(
          '<td class="tk-td tk-change-cell bg-%s" data-segment="%s">%s</td>',
          make_css_safe(seg_name),
          htmltools::htmlEscape(seg_name),
          content
        ))
      }
    }
    parts <- c(parts, '</tr>')
  }

  # Base row at bottom
  parts <- c(parts, sprintf(
    '<tr class="tk-base-row"><td class="tk-td tk-label-col tk-sticky-col tk-base-label">Base (n)</td>'
  ))
  for (seg_idx in seq_along(segments)) {
    seg_name <- segments[seg_idx]
    # Use first metric's n values as representative
    first_metric <- html_data$metric_rows[[1]]
    cells <- first_metric$segment_cells[[seg_name]]

    for (wid in waves) {
      cell <- cells[[wid]]
      n_display <- if (!is.null(cell) && !is.na(cell$n)) cell$n else ""
      parts <- c(parts, sprintf(
        '<td class="tk-td tk-base-cell bg-%s" data-segment="%s">%s</td>',
        make_css_safe(seg_name),
        htmltools::htmlEscape(seg_name),
        n_display
      ))
    }
  }
  parts <- c(parts, '</tr>')

  parts <- c(parts, '</tbody>')
  parts <- c(parts, '</table>')
  parts <- c(parts, '</div>')

  htmltools::HTML(paste(parts, collapse = "\n"))
}


#' Make a CSS-safe Class Name
#'
#' Converts a segment name to a CSS-safe class string.
#'
#' @keywords internal
make_css_safe <- function(name) {
  gsub("[^a-zA-Z0-9_-]", "-", name)
}
