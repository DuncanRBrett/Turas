# ==============================================================================
# TurasTracker HTML Report - Chart Builder
# ==============================================================================
# Generates inline SVG line charts and sparklines for tracking metrics.
# All charts are self-contained SVG — no external dependencies.
# VERSION: 1.0.0
# ==============================================================================


#' Build Line Chart SVG for a Metric
#'
#' Creates an SVG line chart showing metric values across waves.
#' Supports multiple series (one per banner segment).
#'
#' @param chart_data List. Chart data from build_chart_data()
#' @param config List. Tracker configuration
#' @param active_segment Character. Currently active segment (highlighted)
#' @return htmltools::HTML SVG string
#' @export
build_line_chart <- function(chart_data, config, active_segment = NULL) {

  if (is.null(chart_data) || length(chart_data$series) == 0) return(NULL)

  # Chart dimensions
  width <- 700
  height <- 320
  margin <- list(top = 30, right = 140, bottom = 50, left = 60)
  plot_w <- width - margin$left - margin$right
  plot_h <- height - margin$top - margin$bottom

  wave_labels <- chart_data$wave_labels
  n_waves <- length(wave_labels)

  if (n_waves < 2) return(NULL)

  # Collect all values across series for Y-axis scaling
  all_vals <- c()
  for (s in chart_data$series) {
    all_vals <- c(all_vals, s$values[!is.na(s$values)])
  }

  if (length(all_vals) == 0) return(NULL)

  # Y-axis range with padding
  y_min <- min(all_vals, na.rm = TRUE)
  y_max <- max(all_vals, na.rm = TRUE)
  y_range <- y_max - y_min
  if (y_range == 0) y_range <- 1

  y_pad <- y_range * 0.15
  y_axis_min <- y_min - y_pad
  y_axis_max <- y_max + y_pad

  # Special handling for percentage (0-100 scale)
  if (chart_data$is_percentage) {
    y_axis_min <- max(0, y_axis_min)
    y_axis_max <- min(1, y_axis_max)
    # Scale display to 0-100
    scale_fn <- function(v) (v - y_axis_min) / (y_axis_max - y_axis_min) * plot_h
    format_fn <- function(v) paste0(round(v * 100), "%")
  } else if (chart_data$is_nps) {
    y_axis_min <- max(-100, y_axis_min)
    y_axis_max <- min(100, y_axis_max)
    scale_fn <- function(v) (v - y_axis_min) / (y_axis_max - y_axis_min) * plot_h
    format_fn <- function(v) sprintf("%+d", round(v))
  } else {
    scale_fn <- function(v) (v - y_axis_min) / (y_axis_max - y_axis_min) * plot_h
    format_fn <- function(v) format(round(v, 1), nsmall = 1)
  }

  # Colour palette for segments
  brand_colour <- get_setting(config, "brand_colour", default = "#323367") %||% "#323367"
  segment_colours <- get_segment_colours(names(chart_data$series), brand_colour)

  # Build SVG
  svg_parts <- c()
  svg_parts <- c(svg_parts, sprintf(
    '<svg class="tk-line-chart" width="%d" height="%d" viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">',
    width, height, width, height
  ))

  # Background
  svg_parts <- c(svg_parts, sprintf(
    '<rect width="%d" height="%d" fill="#ffffff" rx="4"/>',
    width, height
  ))

  # Plot area group with transform
  svg_parts <- c(svg_parts, sprintf(
    '<g transform="translate(%d,%d)">',
    margin$left, margin$top
  ))

  # Gridlines and Y-axis labels
  n_gridlines <- 5
  grid_vals <- seq(y_axis_min, y_axis_max, length.out = n_gridlines)
  for (gv in grid_vals) {
    gy <- plot_h - scale_fn(gv)
    svg_parts <- c(svg_parts, sprintf(
      '<line x1="0" y1="%.1f" x2="%d" y2="%.1f" stroke="#e8e8e8" stroke-width="1"/>',
      gy, plot_w, gy
    ))
    svg_parts <- c(svg_parts, sprintf(
      '<text x="-8" y="%.1f" text-anchor="end" fill="#888" font-size="11" dy="0.35em">%s</text>',
      gy, htmltools::htmlEscape(format_fn(gv))
    ))
  }

  # X-axis labels
  for (i in seq_len(n_waves)) {
    x_pos <- (i - 1) / (n_waves - 1) * plot_w
    svg_parts <- c(svg_parts, sprintf(
      '<text x="%.1f" y="%d" text-anchor="middle" fill="#888" font-size="11">%s</text>',
      x_pos, plot_h + 20, htmltools::htmlEscape(wave_labels[i])
    ))
    # Tick mark
    svg_parts <- c(svg_parts, sprintf(
      '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#ccc" stroke-width="1"/>',
      x_pos, plot_h, x_pos, plot_h + 4
    ))
  }

  # Plot lines and points for each series
  for (s_idx in seq_along(chart_data$series)) {
    series <- chart_data$series[[s_idx]]
    colour <- segment_colours[s_idx]
    seg_name <- series$name

    # Build path
    path_points <- c()
    point_circles <- c()
    value_labels <- c()

    for (i in seq_len(n_waves)) {
      val <- series$values[i]
      if (is.na(val)) next

      x_pos <- (i - 1) / (n_waves - 1) * plot_w
      y_pos <- plot_h - scale_fn(val)

      path_points <- c(path_points, sprintf("%.1f,%.1f", x_pos, y_pos))

      # Data point circle
      point_circles <- c(point_circles, sprintf(
        '<circle cx="%.1f" cy="%.1f" r="4" fill="%s" stroke="#fff" stroke-width="2" class="tk-chart-point" data-segment="%s" data-wave="%s" data-value="%s"/>',
        x_pos, y_pos, colour,
        htmltools::htmlEscape(seg_name),
        htmltools::htmlEscape(chart_data$wave_ids[i]),
        htmltools::htmlEscape(format_fn(val))
      ))

      # Value label above point
      value_labels <- c(value_labels, sprintf(
        '<text x="%.1f" y="%.1f" text-anchor="middle" fill="%s" font-size="10" font-weight="600">%s</text>',
        x_pos, y_pos - 10, colour, htmltools::htmlEscape(format_fn(val))
      ))
    }

    # Draw line
    if (length(path_points) >= 2) {
      line_opacity <- if (!is.null(active_segment) && seg_name != active_segment) "0.3" else "1"
      svg_parts <- c(svg_parts, sprintf(
        '<polyline points="%s" fill="none" stroke="%s" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" opacity="%s" class="tk-chart-line" data-segment="%s"/>',
        paste(path_points, collapse = " "), colour, line_opacity,
        htmltools::htmlEscape(seg_name)
      ))
    }

    # Draw points and labels
    svg_parts <- c(svg_parts, paste(point_circles, collapse = "\n"))
    svg_parts <- c(svg_parts, paste(value_labels, collapse = "\n"))
  }

  svg_parts <- c(svg_parts, '</g>')  # Close plot area group

  # Legend (right side)
  legend_x <- width - margin$right + 15
  legend_y <- margin$top + 10

  for (s_idx in seq_along(chart_data$series)) {
    series <- chart_data$series[[s_idx]]
    colour <- segment_colours[s_idx]
    ly <- legend_y + (s_idx - 1) * 22

    svg_parts <- c(svg_parts, sprintf(
      '<rect x="%d" y="%.1f" width="14" height="3" rx="1.5" fill="%s"/>',
      legend_x, ly + 5, colour
    ))
    svg_parts <- c(svg_parts, sprintf(
      '<text x="%d" y="%.1f" fill="#444" font-size="11" dy="0.35em">%s</text>',
      legend_x + 20, ly + 6, htmltools::htmlEscape(series$name)
    ))
  }

  svg_parts <- c(svg_parts, '</svg>')

  htmltools::HTML(paste(svg_parts, collapse = "\n"))
}


#' Build Sparkline SVG
#'
#' Creates a tiny inline SVG sparkline for trend visualisation.
#'
#' @param values Numeric vector. Values to plot
#' @param width Numeric. SVG width in pixels
#' @param height Numeric. SVG height in pixels
#' @param colour Character. Line colour
#' @return Character. SVG markup string
#' @export
build_sparkline_svg <- function(values, width = 60, height = 16, colour = "#323367") {

  # Filter out NAs
  valid <- !is.na(values)
  if (sum(valid) < 2) return("")

  valid_vals <- values[valid]
  valid_idx <- which(valid)
  n <- length(valid_vals)

  y_min <- min(valid_vals)
  y_max <- max(valid_vals)
  y_range <- y_max - y_min
  if (y_range == 0) y_range <- 1

  # Padding
  pad <- 2
  plot_w <- width - 2 * pad
  plot_h <- height - 2 * pad

  total_points <- length(values)
  points <- c()
  for (i in seq_along(valid_vals)) {
    x <- pad + (valid_idx[i] - 1) / max(1, total_points - 1) * plot_w
    y <- pad + plot_h - (valid_vals[i] - y_min) / y_range * plot_h
    points <- c(points, sprintf("%.1f,%.1f", x, y))
  }

  # End dot
  last_x <- pad + (valid_idx[n] - 1) / max(1, total_points - 1) * plot_w
  last_y <- pad + plot_h - (valid_vals[n] - y_min) / y_range * plot_h

  sprintf(
    '<svg class="tk-sparkline" width="%d" height="%d" viewBox="0 0 %d %d"><polyline points="%s" fill="none" stroke="%s" stroke-width="1.5" stroke-linejoin="round"/><circle cx="%.1f" cy="%.1f" r="2" fill="%s"/></svg>',
    width, height, width, height,
    paste(points, collapse = " "),
    colour,
    last_x, last_y, colour
  )
}


#' Get Segment Colours
#'
#' Returns a colour palette for banner segments.
#' First segment uses brand colour, others use a distinct palette.
#'
#' @keywords internal
get_segment_colours <- function(segment_names, brand_colour) {
  palette <- c(
    brand_colour,
    "#CC9900",  # Gold
    "#2E8B57",  # Sea green
    "#CD5C5C",  # Indian red
    "#4682B4",  # Steel blue
    "#9370DB",  # Medium purple
    "#D2691E",  # Chocolate
    "#20B2AA"   # Light sea green
  )

  n <- length(segment_names)
  if (n <= length(palette)) {
    return(palette[seq_len(n)])
  }

  # Extend palette by cycling
  rep_len(palette, n)
}
