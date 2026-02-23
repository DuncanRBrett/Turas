# ==============================================================================
# TurasTracker HTML Report - Chart Builder
# ==============================================================================
# Generates inline SVG line charts and sparklines for tracking metrics.
# All charts are self-contained SVG — no external dependencies.
# VERSION: 2.0.0
# ==============================================================================
# CHANGES in v3.0.0:
#   - Professional chart redesign: wider (960px), taller (380px)
#   - Legend moved to horizontal row below chart (no truncation)
#   - Dashed gridlines for cleaner look
#   - Value label collision avoidance (vertical offset when overlapping)
#   - Full plot width utilisation (right margin reduced from 140 to 20px)
# CHANGES in v2.0.0:
#   - Fixed percentage scale bug: values are already 0-100, no multiplication
#   - Config-driven decimal places via decimal_config parameter
#   - Proper metric-appropriate Y-axis ranges
#   - Smooth lines: Catmull-Rom → cubic Bézier path conversion
# ==============================================================================


# ------------------------------------------------------------------------------
# LINE CHART HELPERS
# ------------------------------------------------------------------------------

#' Build SVG Axes Elements (Gridlines + Y Labels + X Labels + Ticks)
#'
#' @param n_waves Integer. Number of waves
#' @param wave_labels Character vector. Labels for x-axis
#' @param wave_ids Character vector. IDs for data attributes
#' @param y_axis_min Numeric. Y-axis minimum
#' @param y_axis_max Numeric. Y-axis maximum
#' @param plot_w Numeric. Plot width in pixels
#' @param plot_h Numeric. Plot height in pixels
#' @param scale_fn Function. Maps value to pixel offset from bottom
#' @param format_fn Function. Formats value for display
#' @return Character vector of SVG elements
#' @keywords internal
build_chart_axes_svg <- function(n_waves, wave_labels, wave_ids,
                                  y_axis_min, y_axis_max,
                                  plot_w, plot_h, scale_fn, format_fn) {
  parts <- c()

  # Dashed gridlines and Y-axis labels
  n_gridlines <- 5
  grid_vals <- seq(y_axis_min, y_axis_max, length.out = n_gridlines)
  for (gv in grid_vals) {
    gy <- plot_h - scale_fn(gv)
    parts <- c(parts, sprintf(
      '<line x1="0" y1="%.1f" x2="%d" y2="%.1f" stroke="#e0e0e0" stroke-width="1" stroke-dasharray="4,4"/>',
      gy, plot_w, gy
    ))
    parts <- c(parts, sprintf(
      '<text x="-10" y="%.1f" text-anchor="end" fill="#666" font-size="12" font-weight="500" dy="0.35em">%s</text>',
      gy, htmltools::htmlEscape(format_fn(gv))
    ))
  }

  # X-axis labels — data-wave for JS filtering
  for (i in seq_len(n_waves)) {
    x_pos <- (i - 1) / (n_waves - 1) * plot_w
    parts <- c(parts, sprintf(
      '<text x="%.1f" y="%d" text-anchor="middle" fill="#666" font-size="13" font-weight="600" class="tk-chart-xaxis" data-wave="%s">%s</text>',
      x_pos, plot_h + 24, htmltools::htmlEscape(wave_ids[i]),
      htmltools::htmlEscape(wave_labels[i])
    ))
    # Tick mark
    parts <- c(parts, sprintf(
      '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#ccc" stroke-width="1" class="tk-chart-tick" data-wave="%s"/>',
      x_pos, plot_h, x_pos, plot_h + 5,
      htmltools::htmlEscape(wave_ids[i])
    ))
  }

  return(parts)
}


#' Build SVG Series (Lines + Points) and Collect Label Data
#'
#' @param chart_data List. Chart data with series
#' @param segment_colours Character vector. Colours per series
#' @param n_waves Integer
#' @param plot_w Numeric. Plot width
#' @param plot_h Numeric. Plot height
#' @param scale_fn Function. Y-value to pixel converter
#' @param format_fn Function. Value formatter
#' @param active_segment Character or NULL
#' @return List with $svg_parts and $all_label_data
#' @keywords internal
build_chart_series_svg <- function(chart_data, segment_colours, n_waves,
                                    plot_w, plot_h, scale_fn, format_fn,
                                    active_segment) {
  svg_parts <- c()
  all_label_data <- vector("list", n_waves)
  for (i in seq_len(n_waves)) all_label_data[[i]] <- list()

  for (s_idx in seq_along(chart_data$series)) {
    series <- chart_data$series[[s_idx]]
    colour <- segment_colours[s_idx]
    seg_name <- series$name

    xy_points <- list()
    point_circles <- c()

    for (i in seq_len(n_waves)) {
      val <- series$values[i]
      if (is.na(val)) next

      x_pos <- (i - 1) / (n_waves - 1) * plot_w
      y_pos <- plot_h - scale_fn(val)

      xy_points[[length(xy_points) + 1]] <- c(x_pos, y_pos)

      # Data point circle
      point_circles <- c(point_circles, sprintf(
        '<circle cx="%.1f" cy="%.1f" r="5" fill="%s" stroke="#fff" stroke-width="2.5" class="tk-chart-point" data-segment="%s" data-wave="%s" data-value="%s"/>',
        x_pos, y_pos, colour,
        htmltools::htmlEscape(seg_name),
        htmltools::htmlEscape(chart_data$wave_ids[i]),
        htmltools::htmlEscape(format_fn(val))
      ))

      # Store label data for collision avoidance
      all_label_data[[i]][[length(all_label_data[[i]]) + 1]] <- list(
        x = x_pos, y = y_pos - 14, text = format_fn(val),
        colour = colour, seg_name = seg_name,
        wave_id = chart_data$wave_ids[i]
      )
    }

    # Draw smooth path
    if (length(xy_points) >= 2) {
      line_opacity <- if (!is.null(active_segment) && seg_name != active_segment) "0.3" else "1"
      path_d <- build_smooth_path(xy_points)

      svg_parts <- c(svg_parts, sprintf(
        '<path d="%s" fill="none" stroke="%s" stroke-width="3" stroke-linejoin="round" stroke-linecap="round" opacity="%s" class="tk-chart-line" data-segment="%s"/>',
        path_d, colour, line_opacity,
        htmltools::htmlEscape(seg_name)
      ))
    }

    # Draw points on top of lines
    svg_parts <- c(svg_parts, paste(point_circles, collapse = "\n"))
  }

  return(list(svg_parts = svg_parts, all_label_data = all_label_data))
}


#' Resolve Label Collisions and Emit SVG Text Elements
#'
#' Takes label data collected per wave, resolves vertical overlaps,
#' and emits positioned SVG text elements.
#'
#' @param all_label_data List. Per-wave label data lists
#' @param plot_h Numeric. Plot area height
#' @return Character vector of SVG text elements
#' @keywords internal
resolve_and_emit_labels_svg <- function(all_label_data, plot_h) {
  svg_parts <- c()
  min_label_gap <- 14  # minimum vertical gap between labels in pixels

  for (wave_labels_at_x in all_label_data) {
    if (length(wave_labels_at_x) == 0) next

    # Sort by y position (ascending = top of SVG first)
    y_vals <- vapply(wave_labels_at_x, function(lb) lb$y, numeric(1))
    sorted_idx <- order(y_vals)
    sorted_labels <- wave_labels_at_x[sorted_idx]

    # Push overlapping labels apart
    for (j in seq_along(sorted_labels)) {
      if (j > 1) {
        prev_y <- sorted_labels[[j - 1]]$y
        if (sorted_labels[[j]]$y - prev_y < min_label_gap) {
          sorted_labels[[j]]$y <- prev_y + min_label_gap
        }
      }
    }

    # Clamp labels within plot area bounds
    n_labels <- length(sorted_labels)
    if (n_labels > 0) {
      last_y <- sorted_labels[[n_labels]]$y
      if (last_y > plot_h - 4) {
        # Labels exceed bottom — redistribute evenly within available range
        total_needed <- (n_labels - 1) * min_label_gap
        first_y <- sorted_labels[[1]]$y
        start_y <- max(4, min(first_y, plot_h - 4 - total_needed))
        for (j in seq_along(sorted_labels)) {
          sorted_labels[[j]]$y <- start_y + (j - 1) * min_label_gap
        }
      }
      # Final clamp for each label
      for (j in seq_along(sorted_labels)) {
        sorted_labels[[j]]$y <- max(4, min(sorted_labels[[j]]$y, plot_h - 4))
      }
    }

    # Emit labels
    for (lb in sorted_labels) {
      svg_parts <- c(svg_parts, sprintf(
        '<text x="%.1f" y="%.1f" text-anchor="middle" fill="%s" font-size="12" font-weight="700" class="tk-chart-label" data-segment="%s" data-wave="%s">%s</text>',
        lb$x, lb$y, lb$colour,
        htmltools::htmlEscape(lb$seg_name),
        htmltools::htmlEscape(lb$wave_id),
        htmltools::htmlEscape(lb$text)
      ))
    }
  }

  return(svg_parts)
}


#' Build Line Chart SVG for a Metric
#'
#' Creates an SVG line chart showing metric values across waves.
#' Supports multiple series (one per banner segment). Uses smooth
#' Catmull-Rom spline interpolation for line paths.
#'
#' @param chart_data List. Chart data from build_chart_data()
#' @param config List. Tracker configuration
#' @param active_segment Character. Currently active segment (highlighted)
#' @param decimal_config List. Decimal places: dp_ratings, dp_pct, dp_nps
#' @return htmltools::HTML SVG string
#' @export
build_line_chart <- function(chart_data, config, active_segment = NULL,
                              decimal_config = list(dp_ratings = 2, dp_pct = 0, dp_nps = 2)) {

  if (is.null(chart_data) || length(chart_data$series) == 0) return(NULL)

  n_series <- length(chart_data$series)
  wave_labels <- chart_data$wave_labels
  n_waves <- length(wave_labels)
  if (n_waves < 2) return(NULL)

  # Collect all values across series for Y-axis scaling
  all_vals <- c()
  for (s in chart_data$series) {
    all_vals <- c(all_vals, s$values[!is.na(s$values)])
  }
  if (length(all_vals) == 0) return(NULL)

  # ---- Chart dimensions: wide, with bottom legend ----
  width <- 960
  # Legend row height depends on number of series (one horizontal row, wrapped if many)
  legend_row_h <- 30
  height <- 380 + legend_row_h
  margin <- list(top = 30, right = 20, bottom = 80, left = 60)
  plot_w <- width - margin$left - margin$right  # 880px
  plot_h <- height - margin$top - margin$bottom - legend_row_h  # 240px

  # ---- Y-axis range: metric-appropriate fixed ranges ----
  y_min_data <- min(all_vals, na.rm = TRUE)
  y_max_data <- max(all_vals, na.rm = TRUE)

  dp_pct <- decimal_config$dp_pct %||% 0
  dp_ratings <- decimal_config$dp_ratings %||% 2
  dp_nps <- decimal_config$dp_nps %||% 2

  if (chart_data$is_percentage) {
    y_axis_min <- 0
    y_axis_max <- 100
    format_fn <- function(v) paste0(format(round(v, dp_pct), nsmall = dp_pct), "%")
  } else if (chart_data$is_nps) {
    y_axis_min <- -100
    y_axis_max <- 100
    format_fn <- function(v) sprintf("%+.*f", dp_nps, v)
  } else {
    if (y_max_data <= 5.5) {
      y_axis_min <- 0
      y_axis_max <- 5
    } else if (y_max_data <= 10.5) {
      y_axis_min <- 0
      y_axis_max <- 10
    } else {
      y_range <- y_max_data - y_min_data
      if (y_range == 0) y_range <- 1
      y_pad <- y_range * 0.15
      y_axis_min <- max(0, y_min_data - y_pad)
      y_axis_max <- y_max_data + y_pad
    }
    format_fn <- function(v) format(round(v, dp_ratings), nsmall = dp_ratings)
  }

  y_axis_range <- y_axis_max - y_axis_min
  if (y_axis_range == 0) y_axis_range <- 1
  scale_fn <- function(v) (v - y_axis_min) / y_axis_range * plot_h

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
    '<rect width="%d" height="%d" fill="#ffffff" rx="6"/>',
    width, height
  ))

  # Plot area group with transform
  svg_parts <- c(svg_parts, sprintf(
    '<g transform="translate(%d,%d)">',
    margin$left, margin$top
  ))

  # Axes: gridlines, Y labels, X labels, ticks
  svg_parts <- c(svg_parts, build_chart_axes_svg(
    n_waves, wave_labels, chart_data$wave_ids,
    y_axis_min, y_axis_max, plot_w, plot_h, scale_fn, format_fn
  ))

  # Data series: lines, points, and label data collection
  series_result <- build_chart_series_svg(
    chart_data, segment_colours, n_waves,
    plot_w, plot_h, scale_fn, format_fn, active_segment
  )
  svg_parts <- c(svg_parts, series_result$svg_parts)

  # Resolve label collisions and emit value labels
  svg_parts <- c(svg_parts, resolve_and_emit_labels_svg(series_result$all_label_data, plot_h))

  svg_parts <- c(svg_parts, '</g>')  # Close plot area group

  # ---- Legend: horizontal row below chart ----
  legend_y <- height - legend_row_h + 8
  # Calculate legend item widths: swatch(16) + gap(6) + text + spacing(24)
  # Estimate text width: ~7px per character at font-size 12
  legend_items <- list()
  total_legend_w <- 0
  for (s_idx in seq_along(chart_data$series)) {
    seg_label <- chart_data$series[[s_idx]]$name
    item_w <- 16 + 6 + nchar(seg_label) * 7 + 24
    legend_items[[s_idx]] <- list(
      name = seg_label,
      colour = segment_colours[s_idx],
      w = item_w
    )
    total_legend_w <- total_legend_w + item_w
  }

  # Center the legend row
  legend_start_x <- max(margin$left, (width - total_legend_w) / 2)
  lx <- legend_start_x

  for (item in legend_items) {
    svg_parts <- c(svg_parts, sprintf(
      '<g class="tk-chart-legend-item" data-segment="%s">',
      htmltools::htmlEscape(item$name)
    ))
    svg_parts <- c(svg_parts, sprintf(
      '<rect x="%.1f" y="%.1f" width="16" height="4" rx="2" fill="%s"/>',
      lx, legend_y + 4, item$colour
    ))
    svg_parts <- c(svg_parts, sprintf(
      '<text x="%.1f" y="%.1f" fill="#555" font-size="12" font-weight="600" dy="0.35em">%s</text>',
      lx + 22, legend_y + 5, htmltools::htmlEscape(item$name)
    ))
    svg_parts <- c(svg_parts, '</g>')
    lx <- lx + item$w
  }

  svg_parts <- c(svg_parts, '</svg>')

  htmltools::HTML(paste(svg_parts, collapse = "\n"))
}


#' Build Smooth SVG Path from Points (Catmull-Rom → Cubic Bézier)
#'
#' Converts a sequence of (x, y) points into a smooth SVG path string
#' using Catmull-Rom spline interpolation converted to cubic Bézier curves.
#' For 2 points, draws a straight line. For 3+ points, applies smoothing.
#'
#' @param points List of numeric vectors c(x, y)
#' @param tension Numeric. Catmull-Rom tension (0 = sharp, 1 = very smooth). Default 0.5
#' @return Character. SVG path d-attribute string
#' @keywords internal
build_smooth_path <- function(points, tension = 0.5) {

  n <- length(points)
  if (n < 2) return("")

  # Start path at first point
  d <- sprintf("M%.1f,%.1f", points[[1]][1], points[[1]][2])

  # For exactly 2 points, straight line

  if (n == 2) {
    d <- paste0(d, sprintf(" L%.1f,%.1f", points[[2]][1], points[[2]][2]))
    return(d)
  }

  # Catmull-Rom to cubic Bézier conversion
  # For each segment between points[i] and points[i+1], we need:
  #   p0 = points[i-1] (or reflected for first segment)
  #   p1 = points[i]
  #   p2 = points[i+1]
  #   p3 = points[i+2] (or reflected for last segment)
  alpha <- tension / 3

  for (i in seq_len(n - 1)) {
    p1 <- points[[i]]
    p2 <- points[[i + 1]]

    # Get surrounding points (with reflection for edges)
    if (i == 1) {
      p0 <- c(2 * p1[1] - p2[1], 2 * p1[2] - p2[2])  # reflect p2 through p1
    } else {
      p0 <- points[[i - 1]]
    }

    if (i == n - 1) {
      p3 <- c(2 * p2[1] - p1[1], 2 * p2[2] - p1[2])  # reflect p1 through p2
    } else {
      p3 <- points[[i + 2]]
    }

    # Control points for cubic Bézier
    cp1x <- p1[1] + alpha * (p2[1] - p0[1])
    cp1y <- p1[2] + alpha * (p2[2] - p0[2])
    cp2x <- p2[1] - alpha * (p3[1] - p1[1])
    cp2y <- p2[2] - alpha * (p3[2] - p1[2])

    d <- paste0(d, sprintf(" C%.1f,%.1f %.1f,%.1f %.1f,%.1f",
                            cp1x, cp1y, cp2x, cp2y, p2[1], p2[2]))
  }

  d
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
