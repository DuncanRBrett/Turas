# ==============================================================================
# WEIGHTING HTML REPORT - CHART BUILDER
# ==============================================================================
# Builds inline SVG histogram charts for weight distribution visualisation.
# Follows Turas visual conventions: rounded bar corners, muted palette,
# soft charcoal labels, no gradients or shadows.
# ==============================================================================

#' Build Weight Distribution Histogram SVG
#'
#' Creates an inline SVG histogram showing the distribution of weights.
#' Uses the same visual language as tabs/tracker charts.
#'
#' @param histogram_data Data frame from build_histogram_data()
#' @param weight_name Character, name for chart title
#' @param brand_colour Character, hex colour for bars
#' @param chart_width Numeric, SVG viewBox width (default: 680)
#' @param chart_height Numeric, SVG viewBox height (default: 280)
#' @return Character, SVG string
#' @keywords internal
build_histogram_svg <- function(histogram_data, weight_name = "",
                                 brand_colour = "#1e3a5f",
                                 chart_width = 680, chart_height = 280) {
  if (is.null(histogram_data) || nrow(histogram_data) == 0) {
    return("")
  }

  # Layout constants
  margin_left <- 50
  margin_right <- 20
  margin_top <- 40
  margin_bottom <- 50
  plot_w <- chart_width - margin_left - margin_right
  plot_h <- chart_height - margin_top - margin_bottom

  n_bins <- nrow(histogram_data)
  max_count <- max(histogram_data$count)
  if (max_count == 0) return("")

  # Bar dimensions
  bar_gap <- 2
  bar_w <- (plot_w - (n_bins - 1) * bar_gap) / n_bins

  # Build bars
  bars <- ""
  for (i in seq_len(n_bins)) {
    h <- histogram_data$count[i]
    bar_h <- (h / max_count) * plot_h
    x <- margin_left + (i - 1) * (bar_w + bar_gap)
    y <- margin_top + plot_h - bar_h

    bars <- paste0(bars, sprintf(
      '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="3" fill="%s" opacity="0.80"/>\n',
      x, y, bar_w, bar_h, brand_colour
    ))
  }

  # Y-axis: 5 gridlines
  y_axis <- ""
  n_grid <- 5
  for (j in 0:n_grid) {
    val <- round(max_count * j / n_grid)
    y_pos <- margin_top + plot_h - (j / n_grid) * plot_h

    # Gridline
    y_axis <- paste0(y_axis, sprintf(
      '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e2e8f0" stroke-width="1"/>\n',
      margin_left, y_pos, chart_width - margin_right, y_pos
    ))

    # Label
    y_axis <- paste0(y_axis, sprintf(
      '<text x="%d" y="%.1f" text-anchor="end" fill="#64748b" font-size="11" font-weight="500">%d</text>\n',
      margin_left - 8, y_pos + 4, val
    ))
  }

  # X-axis labels: show ~5 evenly spaced tick labels
  x_axis <- ""
  n_ticks <- min(n_bins, 7)
  tick_indices <- unique(round(seq(1, n_bins, length.out = n_ticks)))
  for (idx in tick_indices) {
    x_center <- margin_left + (idx - 1) * (bar_w + bar_gap) + bar_w / 2
    label <- sprintf("%.2f", histogram_data$bin_mid[idx])

    x_axis <- paste0(x_axis, sprintf(
      '<text x="%.1f" y="%d" text-anchor="middle" fill="#64748b" font-size="10" font-weight="400">%s</text>\n',
      x_center, chart_height - 10, label
    ))
  }

  # Title
  title_svg <- sprintf(
    '<text x="%d" y="20" fill="#1e293b" font-size="13" font-weight="600">Weight Distribution%s</text>\n',
    margin_left,
    if (nzchar(weight_name)) paste0(": ", htmlEscape(weight_name)) else ""
  )

  # Axis labels
  x_label <- sprintf(
    '<text x="%.1f" y="%d" text-anchor="middle" fill="#64748b" font-size="11" font-weight="500">Weight Value</text>\n',
    margin_left + plot_w / 2, chart_height - 2
  )
  y_label <- sprintf(
    '<text transform="rotate(-90)" x="%.1f" y="14" text-anchor="middle" fill="#64748b" font-size="11" font-weight="500">Count</text>\n',
    -(margin_top + plot_h / 2)
  )

  # Assemble SVG
  sprintf(
    '<svg viewBox="0 0 %d %d" style="font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Roboto,sans-serif; width:100%%; max-width:700px; height:auto; display:block; margin:0 auto;">\n%s%s%s%s%s%s</svg>',
    chart_width, chart_height,
    title_svg, y_axis, bars, x_axis, x_label, y_label
  )
}

#' Build Quality Gauge SVG
#'
#' Creates a small semicircular gauge showing weight quality.
#'
#' @param quality_status Character, "GOOD", "ACCEPTABLE", or "POOR"
#' @param efficiency Numeric, weight efficiency percentage
#' @return Character, SVG string
#' @keywords internal
build_quality_gauge_svg <- function(quality_status, efficiency = NULL) {
  colour <- switch(quality_status,
    "GOOD" = "#27ae60",
    "ACCEPTABLE" = "#f39c12",
    "#e74c3c"
  )

  # Simple bar gauge (120px wide)
  fill_pct <- if (!is.null(efficiency)) min(100, max(0, efficiency)) else
    switch(quality_status, "GOOD" = 90, "ACCEPTABLE" = 60, 30)
  fill_w <- round(100 * fill_pct / 100)

  sprintf(
    '<svg viewBox="0 0 120 36" style="width:120px; height:36px;">
      <rect x="0" y="8" width="100" height="10" rx="5" fill="#e2e8f0"/>
      <rect x="0" y="8" width="%d" height="10" rx="5" fill="%s"/>
      <text x="108" y="18" text-anchor="middle" fill="%s" font-size="12" font-weight="700">%s</text>
    </svg>',
    fill_w, colour, colour, quality_status
  )
}
