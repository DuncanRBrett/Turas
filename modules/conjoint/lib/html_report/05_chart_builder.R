# ==============================================================================
# CONJOINT HTML REPORT - CHART BUILDER
# ==============================================================================
# Builds SVG visualizations following Turas visual standards
# ==============================================================================

#' Build Attribute Importance Bar Chart (SVG)
#'
#' Horizontal bars sorted by importance, rounded corners, muted palette.
#'
#' @param importance Data frame with Attribute, Importance
#' @param brand_colour Hex colour for bars
#' @return SVG string
#' @keywords internal
build_importance_chart <- function(importance, brand_colour = "#323367") {

  imp_sorted <- importance[order(importance$Importance), ]
  n <- nrow(imp_sorted)

  chart_width <- 600
  chart_height <- max(200, n * 40 + 60)
  margin_left <- 160
  margin_right <- 60
  margin_top <- 30
  margin_bottom <- 30
  plot_w <- chart_width - margin_left - margin_right
  bar_height <- 24
  bar_gap <- 16

  elements <- character()

  # Gridlines
  max_imp <- max(imp_sorted$Importance, 50)
  grid_ticks <- seq(0, ceiling(max_imp / 10) * 10, by = 10)
  for (tick in grid_ticks) {
    x <- margin_left + (tick / max_imp) * plot_w
    elements <- c(elements, sprintf(
      '<line x1="%.1f" y1="%d" x2="%.1f" y2="%.1f" stroke="#e2e8f0" stroke-width="1"/>',
      x, margin_top, x, chart_height - margin_bottom
    ))
    elements <- c(elements, sprintf(
      '<text x="%.1f" y="%d" text-anchor="middle" fill="#64748b" font-size="11" font-weight="400">%d%%</text>',
      x, chart_height - margin_bottom + 16, tick
    ))
  }

  # Bars
  for (i in seq_len(n)) {
    y <- margin_top + (i - 1) * (bar_height + bar_gap)
    w <- (imp_sorted$Importance[i] / max_imp) * plot_w

    # Label
    elements <- c(elements, sprintf(
      '<text x="%d" y="%.1f" text-anchor="end" fill="#334155" font-size="12" font-weight="400" dominant-baseline="central">%s</text>',
      margin_left - 8, y + bar_height / 2, imp_sorted$Attribute[i]
    ))

    # Bar with rounded corners
    elements <- c(elements, sprintf(
      '<rect x="%d" y="%.1f" width="%.1f" height="%d" rx="4" fill="%s" opacity="0.85"/>',
      margin_left, y, max(w, 2), bar_height, brand_colour
    ))

    # Value label
    elements <- c(elements, sprintf(
      '<text x="%.1f" y="%.1f" fill="#334155" font-size="11" font-weight="500" dominant-baseline="central">%.1f%%</text>',
      margin_left + w + 6, y + bar_height / 2, imp_sorted$Importance[i]
    ))
  }

  sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="100%%" style="max-width:%dpx;font-family:system-ui,-apple-system,sans-serif;">%s</svg>',
    chart_width, chart_height, chart_width, paste(elements, collapse = "\n")
  )
}


#' Build Utility Grouped Bar Chart for an Attribute (SVG)
#'
#' Vertical bars showing utility value per level.
#'
#' @param attr_utilities Utilities data frame filtered to one attribute
#' @param attr_name Attribute name for title
#' @param brand_colour Hex colour
#' @return SVG string
#' @keywords internal
build_utility_chart <- function(attr_utilities, attr_name, brand_colour = "#323367") {

  n <- nrow(attr_utilities)
  chart_width <- max(300, n * 80 + 120)
  chart_height <- 280
  margin_left <- 50
  margin_right <- 20
  margin_top <- 40
  margin_bottom <- 80
  plot_w <- chart_width - margin_left - margin_right
  plot_h <- chart_height - margin_top - margin_bottom
  bar_width <- min(50, (plot_w / n) * 0.6)

  u_values <- attr_utilities$Utility
  u_max <- max(abs(u_values), 0.5) * 1.2
  u_min <- -u_max

  scale_y <- function(v) margin_top + (u_max - v) / (u_max - u_min) * plot_h
  zero_y <- scale_y(0)

  elements <- character()

  # Title
  elements <- c(elements, sprintf(
    '<text x="%.1f" y="16" text-anchor="middle" fill="#334155" font-size="13" font-weight="500">%s</text>',
    chart_width / 2, attr_name
  ))

  # Zero line
  elements <- c(elements, sprintf(
    '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#94a3b8" stroke-width="1" stroke-dasharray="4,4"/>',
    margin_left, zero_y, chart_width - margin_right, zero_y
  ))

  # Gridlines
  grid_step <- if (u_max > 1) round(u_max / 3, 1) else round(u_max / 3, 2)
  if (grid_step > 0) {
    grid_vals <- seq(-floor(u_max / grid_step) * grid_step, ceiling(u_max / grid_step) * grid_step, by = grid_step)
    for (gv in grid_vals) {
      if (abs(gv) < 1e-10) next
      gy <- scale_y(gv)
      if (gy >= margin_top && gy <= chart_height - margin_bottom) {
        elements <- c(elements, sprintf(
          '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e2e8f0" stroke-width="1"/>',
          margin_left, gy, chart_width - margin_right, gy
        ))
        elements <- c(elements, sprintf(
          '<text x="%d" y="%.1f" text-anchor="end" fill="#64748b" font-size="10" dominant-baseline="central">%.2f</text>',
          margin_left - 6, gy, gv
        ))
      }
    }
  }

  # Bars
  for (i in seq_len(n)) {
    x_center <- margin_left + (i - 0.5) * (plot_w / n)
    x <- x_center - bar_width / 2
    u <- u_values[i]
    bar_colour <- if (u >= 0) brand_colour else "#e74c3c"

    if (u >= 0) {
      bar_y <- scale_y(u)
      bar_h <- zero_y - bar_y
    } else {
      bar_y <- zero_y
      bar_h <- scale_y(u) - zero_y
    }

    elements <- c(elements, sprintf(
      '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="4" fill="%s" opacity="0.8"/>',
      x, bar_y, bar_width, max(bar_h, 1), bar_colour
    ))

    # Value label
    label_y <- if (u >= 0) bar_y - 6 else bar_y + bar_h + 14
    elements <- c(elements, sprintf(
      '<text x="%.1f" y="%.1f" text-anchor="middle" fill="#334155" font-size="10" font-weight="500">%.3f</text>',
      x_center, label_y, u
    ))

    # Level label (rotated)
    label <- attr_utilities$Level[i]
    if (nchar(label) > 15) label <- paste0(substr(label, 1, 14), "\u2026")
    elements <- c(elements, sprintf(
      '<text x="%.1f" y="%.1f" text-anchor="end" fill="#64748b" font-size="10" transform="rotate(-45,%.1f,%.1f)">%s</text>',
      x_center, chart_height - margin_bottom + 12, x_center, chart_height - margin_bottom + 12, label
    ))
  }

  sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="100%%" style="max-width:%dpx;font-family:system-ui,-apple-system,sans-serif;">%s</svg>',
    chart_width, chart_height, chart_width, paste(elements, collapse = "\n")
  )
}


#' Build BIC Line Chart for LC Comparison (SVG)
#'
#' @param comparison LC comparison data frame
#' @param optimal_k Optimal number of classes
#' @param brand_colour Hex colour
#' @return SVG string
#' @keywords internal
build_bic_chart <- function(comparison, optimal_k, brand_colour = "#323367") {

  if (is.null(comparison) || nrow(comparison) < 2) return("")

  chart_width <- 400
  chart_height <- 250
  margin_left <- 70
  margin_right <- 30
  margin_top <- 30
  margin_bottom <- 50
  plot_w <- chart_width - margin_left - margin_right
  plot_h <- chart_height - margin_top - margin_bottom

  ks <- comparison$K
  bics <- comparison$BIC

  x_scale <- function(k) margin_left + (k - min(ks)) / max(1, max(ks) - min(ks)) * plot_w
  y_range <- max(bics) - min(bics)
  if (y_range == 0) y_range <- 1
  y_scale <- function(b) margin_top + (max(bics) - b) / y_range * plot_h

  elements <- character()

  # Y-axis gridlines
  n_grids <- 4
  for (g in 0:n_grids) {
    bic_val <- min(bics) + g * y_range / n_grids
    gy <- y_scale(bic_val)
    elements <- c(elements, sprintf(
      '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e2e8f0" stroke-width="1"/>',
      margin_left, gy, chart_width - margin_right, gy
    ))
    elements <- c(elements, sprintf(
      '<text x="%d" y="%.1f" text-anchor="end" fill="#64748b" font-size="10" dominant-baseline="central">%.0f</text>',
      margin_left - 6, gy, bic_val
    ))
  }

  # Line path
  points <- vapply(seq_along(ks), function(i) {
    sprintf("%.1f,%.1f", x_scale(ks[i]), y_scale(bics[i]))
  }, character(1))
  elements <- c(elements, sprintf(
    '<polyline points="%s" fill="none" stroke="%s" stroke-width="2.5"/>',
    paste(points, collapse = " "), brand_colour
  ))

  # Data points
  for (i in seq_along(ks)) {
    cx <- x_scale(ks[i])
    cy <- y_scale(bics[i])
    fill <- if (ks[i] == optimal_k) "#e74c3c" else brand_colour
    r <- if (ks[i] == optimal_k) 6 else 4
    elements <- c(elements, sprintf(
      '<circle cx="%.1f" cy="%.1f" r="%d" fill="%s"/>',
      cx, cy, r, fill
    ))
    # X-axis label
    elements <- c(elements, sprintf(
      '<text x="%.1f" y="%d" text-anchor="middle" fill="#64748b" font-size="11">K=%d</text>',
      cx, chart_height - margin_bottom + 20, ks[i]
    ))
  }

  # Axis labels
  elements <- c(elements, sprintf(
    '<text x="%.1f" y="%d" text-anchor="middle" fill="#334155" font-size="12" font-weight="500">BIC by Number of Classes</text>',
    chart_width / 2, 16
  ))

  sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="100%%" style="max-width:%dpx;font-family:system-ui,-apple-system,sans-serif;">%s</svg>',
    chart_width, chart_height, chart_width, paste(elements, collapse = "\n")
  )
}
