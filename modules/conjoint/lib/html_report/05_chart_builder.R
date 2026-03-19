# ==============================================================================
# CONJOINT HTML REPORT - CHART BUILDER
# ==============================================================================
# Builds SVG visualizations following Turas visual standards:
#   - Rounded corners on bars (rx="4")
#   - Muted colour palette
#   - Decluttered grids (#e2e8f0), soft charcoal axis labels (#64748b)
#   - No gradients, no shadows
#   - All charts wrapped in data-chart-id divs for PNG export
# ==============================================================================

# --- Shared SVG helpers ---

.svg_wrap <- function(chart_id, svg_content, chart_width, chart_height) {
  sprintf(
    '<div class="cj-chart-wrap" data-chart-id="%s"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="100%%" style="max-width:%dpx;font-family:system-ui,-apple-system,sans-serif;">%s</svg></div>',
    chart_id, chart_width, chart_height, chart_width, paste(svg_content, collapse = "\n")
  )
}

.svg_gridline <- function(x1, y1, x2, y2, colour = "#f1f5f9") {
  sprintf(
    '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="1"/>',
    x1, y1, x2, y2, colour
  )
}

.svg_axis_label <- function(x, y, label, anchor = "middle", size = 11, weight = 400) {
  sprintf(
    '<text x="%.1f" y="%.1f" text-anchor="%s" fill="#64748b" font-size="%d" font-weight="%d">%s</text>',
    x, y, anchor, size, weight, label
  )
}

.svg_value_label <- function(x, y, label, anchor = "middle", size = 12) {
  sprintf(
    '<text x="%.1f" y="%.1f" text-anchor="%s" fill="#334155" font-size="%d" font-weight="600">%s</text>',
    x, y, anchor, size, label
  )
}


# ==============================================================================
# IMPORTANCE CHART
# ==============================================================================

#' Build Attribute Importance Bar Chart (SVG)
#'
#' Horizontal bars sorted by importance, rounded corners, muted palette.
#'
#' @param importance Data frame with Attribute, Importance
#' @param brand_colour Hex colour for bars
#' @return HTML string with SVG wrapped in data-chart-id div
#' @keywords internal
build_importance_chart <- function(importance, brand_colour = "#323367") {

  imp_sorted <- importance[order(importance$Importance), ]
  n <- nrow(imp_sorted)

  chart_width <- 800
  chart_height <- max(200, n * 48 + 60)
  margin_left <- 180
  margin_right <- 80
  margin_top <- 30
  margin_bottom <- 30
  plot_w <- chart_width - margin_left - margin_right
  bar_height <- 32
  bar_gap <- 16

  elements <- character()

  # Horizontal gridlines at each tick mark
  max_imp <- max(imp_sorted$Importance, 50)
  grid_ticks <- seq(0, ceiling(max_imp / 10) * 10, by = 10)
  for (tick in grid_ticks) {
    if (tick == 0) next
    x <- margin_left + (tick / max_imp) * plot_w
    elements <- c(elements, .svg_gridline(x, margin_top, x, chart_height - margin_bottom))
    elements <- c(elements, .svg_axis_label(x, chart_height - margin_bottom + 16, sprintf("%d%%", tick)))
  }

  # Bottom axis line and left axis line only (no outer box)
  elements <- c(elements, sprintf(
    '<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#cbd5e1" stroke-width="1"/>',
    margin_left, chart_height - margin_bottom, chart_width - margin_right, chart_height - margin_bottom
  ))
  elements <- c(elements, sprintf(
    '<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#cbd5e1" stroke-width="1"/>',
    margin_left, margin_top, margin_left, chart_height - margin_bottom
  ))

  # Mean importance reference line
  mean_imp <- mean(imp_sorted$Importance)
  mean_x <- margin_left + (mean_imp / max_imp) * plot_w
  elements <- c(elements, sprintf(
    '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#94a3b8" stroke-width="1" stroke-dasharray="4,4"/>',
    mean_x, margin_top, mean_x, chart_height - margin_bottom
  ))
  elements <- c(elements, sprintf(
    '<text x="%.1f" y="%d" text-anchor="middle" fill="#94a3b8" font-size="10" font-weight="400">mean</text>',
    mean_x, margin_top - 4
  ))

  # Bars with opacity gradient: least important (0.70) -> most important (0.95)
  for (i in seq_len(n)) {
    y <- margin_top + (i - 1) * (bar_height + bar_gap)
    w <- (imp_sorted$Importance[i] / max_imp) * plot_w
    bar_opacity <- 0.70 + (i - 1) / max(n - 1, 1) * 0.25
    val_label <- sprintf("%.1f%%", imp_sorted$Importance[i])

    # Attribute label (font-weight 400 for softer axis labels)
    elements <- c(elements, sprintf(
      '<text x="%d" y="%.1f" text-anchor="end" fill="#334155" font-size="13" font-weight="400" dominant-baseline="central">%s</text>',
      margin_left - 8, y + bar_height / 2, imp_sorted$Attribute[i]
    ))

    # Bar with rounded corners and white stroke for separation
    elements <- c(elements, sprintf(
      '<rect x="%d" y="%.1f" width="%.1f" height="%d" rx="4" ry="4" fill="%s" opacity="%.2f" stroke="#fff" stroke-width="1"/>',
      margin_left, y, max(w, 2), bar_height, brand_colour, bar_opacity
    ))

    # Value label: inside bar (white, right-aligned) if wide enough, else outside
    if (w > 80) {
      elements <- c(elements, sprintf(
        '<text x="%.1f" y="%.1f" text-anchor="end" fill="#ffffff" font-size="12" font-weight="600" dominant-baseline="central">%s</text>',
        margin_left + w - 8, y + bar_height / 2, val_label
      ))
    } else {
      elements <- c(elements, sprintf(
        '<text x="%.1f" y="%.1f" text-anchor="start" fill="#334155" font-size="12" font-weight="600" dominant-baseline="central">%s</text>',
        margin_left + w + 6, y + bar_height / 2, val_label
      ))
    }
  }

  .svg_wrap("importance", elements, chart_width, chart_height)
}


# ==============================================================================
# UTILITY CHART
# ==============================================================================

#' Build Utility Grouped Bar Chart for an Attribute (SVG)
#'
#' Vertical bars showing utility value per level.
#'
#' @param attr_utilities Utilities data frame filtered to one attribute
#' @param attr_name Attribute name for title
#' @param brand_colour Hex colour
#' @return HTML string with SVG wrapped in data-chart-id div
#' @keywords internal
build_utility_chart <- function(attr_utilities, attr_name, brand_colour = "#323367") {

  n <- nrow(attr_utilities)
  chart_width <- max(400, n * 100 + 120)
  chart_height <- 250
  margin_left <- 50
  margin_right <- 20
  margin_top <- 20
  margin_bottom <- 50
  plot_w <- chart_width - margin_left - margin_right
  plot_h <- chart_height - margin_top - margin_bottom
  bar_width <- min(55, (plot_w / n) * 0.6)

  u_values <- attr_utilities$Utility
  u_max <- max(abs(u_values), 0.5) * 1.2
  u_min <- -u_max

  scale_y <- function(v) margin_top + (u_max - v) / (u_max - u_min) * plot_h
  zero_y <- scale_y(0)

  elements <- character()

  # No SVG title — card h2 already shows attribute name

  # Zero line (solid thin line, not dashed)
  elements <- c(elements, sprintf(
    '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#94a3b8" stroke-width="1"/>',
    margin_left, zero_y, chart_width - margin_right, zero_y
  ))

  # Horizontal gridlines using nice tick step
  grid_step <- .nice_tick_step(u_max)
  if (grid_step > 0) {
    grid_vals <- seq(-floor(u_max / grid_step) * grid_step,
                     ceiling(u_max / grid_step) * grid_step, by = grid_step)
    for (gv in grid_vals) {
      if (abs(gv) < 1e-10) next
      gy <- scale_y(gv)
      if (gy >= margin_top && gy <= chart_height - margin_bottom) {
        elements <- c(elements, .svg_gridline(margin_left, gy, chart_width - margin_right, gy))
        elements <- c(elements, .svg_axis_label(
          margin_left - 6, gy, sprintf("%.2f", gv), anchor = "end", size = 11
        ))
      }
    }
  }

  # Bars
  for (i in seq_len(n)) {
    x_center <- margin_left + (i - 0.5) * (plot_w / n)
    x <- x_center - bar_width / 2
    u <- u_values[i]
    bar_colour <- if (u >= 0) brand_colour else "#c0695c"

    if (u >= 0) {
      bar_y <- scale_y(u)
      bar_h <- zero_y - bar_y
    } else {
      bar_y <- zero_y
      bar_h <- scale_y(u) - zero_y
    }

    elements <- c(elements, sprintf(
      '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="4" ry="4" fill="%s" opacity="0.85" stroke="#fff" stroke-width="1"/>',
      x, bar_y, bar_width, max(bar_h, 1), bar_colour
    ))

    # Value label (font-weight 600 for bolder contrast)
    label_y <- if (u >= 0) bar_y - 6 else bar_y + bar_h + 14
    elements <- c(elements, sprintf(
      '<text x="%.1f" y="%.1f" text-anchor="middle" fill="#334155" font-size="12" font-weight="600">%s</text>',
      x_center, label_y, sprintf("%.3f", u)
    ))

    # Level label (font-weight 400, colour #475569)
    label <- attr_utilities$Level[i]
    if (nchar(label) > 20) label <- paste0(substr(label, 1, 19), "\u2026")
    elements <- c(elements, sprintf(
      '<text x="%.1f" y="%.1f" text-anchor="middle" fill="#475569" font-size="11" font-weight="400">%s</text>',
      x_center, chart_height - margin_bottom + 16, label
    ))
  }

  chart_id <- paste0("utility-", gsub("[^a-zA-Z0-9]", "-", tolower(attr_name)))
  .svg_wrap(chart_id, elements, chart_width, chart_height)
}


# ==============================================================================
# BIC CHART (LATENT CLASS)
# ==============================================================================

#' Build BIC Line Chart for LC Comparison (SVG)
#'
#' @param comparison LC comparison data frame
#' @param optimal_k Optimal number of classes
#' @param brand_colour Hex colour
#' @return HTML string with SVG wrapped in data-chart-id div
#' @keywords internal
build_bic_chart <- function(comparison, optimal_k, brand_colour = "#323367") {

  if (is.null(comparison) || nrow(comparison) < 2) return("")

  chart_width <- 500
  chart_height <- 250
  margin_left <- 70
  margin_right <- 30
  margin_top <- 20
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
    elements <- c(elements, .svg_gridline(margin_left, gy, chart_width - margin_right, gy))
    elements <- c(elements, .svg_axis_label(
      margin_left - 6, gy, sprintf("%.0f", bic_val), anchor = "end", size = 11
    ))
  }

  # Line path (rounded joins/caps)
  points <- vapply(seq_along(ks), function(i) {
    sprintf("%.1f,%.1f", x_scale(ks[i]), y_scale(bics[i]))
  }, character(1))
  elements <- c(elements, sprintf(
    '<polyline points="%s" fill="none" stroke="%s" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"/>',
    paste(points, collapse = " "), brand_colour
  ))

  # Data points (white fill, brand stroke for connected-dot look)
  for (i in seq_along(ks)) {
    cx <- x_scale(ks[i])
    cy <- y_scale(bics[i])
    is_optimal <- (ks[i] == optimal_k)
    fill <- if (is_optimal) "#fff" else "#fff"
    stroke_col <- if (is_optimal) "#c0695c" else brand_colour
    r <- if (is_optimal) 7 else 5
    sw <- if (is_optimal) 3 else 2.5
    elements <- c(elements, sprintf(
      '<circle cx="%.1f" cy="%.1f" r="%d" fill="%s" stroke="%s" stroke-width="%.1f"/>', cx, cy, r, fill, stroke_col, sw
    ))
    elements <- c(elements, .svg_axis_label(cx, chart_height - margin_bottom + 20, sprintf("K=%d", ks[i]), size = 11))

    # Label the optimal (minimum BIC) point
    if (is_optimal) {
      elements <- c(elements, sprintf(
        '<text x="%.1f" y="%.1f" text-anchor="middle" fill="#c0695c" font-size="10" font-weight="600">Optimal</text>',
        cx, cy - 14
      ))
    }
  }

  .svg_wrap("bic-comparison", elements, chart_width, chart_height)
}


# ==============================================================================
# WTP CHART
# ==============================================================================

#' Build WTP Horizontal Bar Chart (SVG)
#'
#' Shows willingness-to-pay per level, grouped by attribute.
#' Positive WTP = green-ish brand, negative = red.
#'
#' @param wtp_data WTP data list with wtp_table
#' @param brand_colour Hex colour for positive bars
#' @return HTML string with SVG wrapped in data-chart-id div
#' @keywords internal
build_wtp_chart <- function(wtp_data, brand_colour = "#323367") {

  if (is.null(wtp_data) || is.null(wtp_data$wtp_table)) return("")

  cs <- wtp_data$currency_symbol %||% "$"
  wtp <- wtp_data$wtp_table
  # Filter out baselines
  if ("is_baseline" %in% names(wtp)) wtp <- wtp[!wtp$is_baseline, , drop = FALSE]
  if (nrow(wtp) == 0) return("")

  n <- nrow(wtp)
  has_ci <- all(c("WTP_Lower", "WTP_Upper") %in% names(wtp)) &&
    any(!is.na(wtp$WTP_Lower) & !is.na(wtp$WTP_Upper))
  chart_width <- 800
  bar_height <- 30
  bar_gap <- 6
  group_gap <- 14
  margin_left <- 220
  margin_right <- 80
  margin_top <- 30
  margin_bottom <- 30
  plot_w <- chart_width - margin_left - margin_right

  # Calculate height with group gaps
  attrs <- unique(wtp$Attribute)
  total_items <- n + (length(attrs) - 1)  # extra gaps between groups
  chart_height <- margin_top + total_items * (bar_height + bar_gap) + margin_bottom

  wtp_abs_max <- max(abs(wtp$WTP), 1)
  scale_x <- function(v) margin_left + (v + wtp_abs_max) / (2 * wtp_abs_max) * plot_w
  zero_x <- scale_x(0)

  elements <- character()

  # Zero line (solid thin line, not dashed)
  elements <- c(elements, sprintf(
    '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#94a3b8" stroke-width="1"/>',
    zero_x, margin_top, zero_x, chart_height - margin_bottom
  ))

  # Horizontal gridlines
  tick_step <- .nice_tick_step(wtp_abs_max)
  ticks <- seq(-floor(wtp_abs_max / tick_step) * tick_step,
               ceiling(wtp_abs_max / tick_step) * tick_step, by = tick_step)
  for (tick in ticks) {
    if (abs(tick) < 1e-10) next
    tx <- scale_x(tick)
    if (tx >= margin_left && tx <= chart_width - margin_right) {
      elements <- c(elements, .svg_gridline(tx, margin_top, tx, chart_height - margin_bottom))
      elements <- c(elements, .svg_axis_label(tx, chart_height - margin_bottom + 16, sprintf("%s%.0f", cs, tick)))
    }
  }
  elements <- c(elements, .svg_axis_label(zero_x, chart_height - margin_bottom + 16, paste0(cs, "0")))

  # Bars grouped by attribute
  y_pos <- margin_top
  prev_attr <- ""
  for (i in seq_len(n)) {
    curr_attr <- wtp$Attribute[i]
    if (curr_attr != prev_attr && prev_attr != "") {
      y_pos <- y_pos + group_gap
    }
    prev_attr <- curr_attr

    val <- wtp$WTP[i]
    bar_colour <- if (val >= 0) brand_colour else "#c0695c"
    label <- sprintf("%s: %s", curr_attr, wtp$Level[i])
    if (nchar(label) > 34) label <- paste0(substr(label, 1, 33), "\u2026")

    # Label (font-weight 400, colour #475569)
    elements <- c(elements, sprintf(
      '<text x="%d" y="%.1f" text-anchor="end" fill="#475569" font-size="11" font-weight="400" dominant-baseline="central">%s</text>',
      margin_left - 8, y_pos + bar_height / 2, label
    ))

    # Bar with white stroke for separation
    if (val >= 0) {
      bx <- zero_x
      bw <- scale_x(val) - zero_x
    } else {
      bx <- scale_x(val)
      bw <- zero_x - scale_x(val)
    }
    elements <- c(elements, sprintf(
      '<rect x="%.1f" y="%.1f" width="%.1f" height="%d" rx="4" ry="4" fill="%s" opacity="0.85" stroke="#fff" stroke-width="1"/>',
      bx, y_pos, max(bw, 2), bar_height, bar_colour
    ))

    # CI whiskers (if available)
    if (has_ci) {
      ci_lo <- wtp$WTP_Lower[i]
      ci_hi <- wtp$WTP_Upper[i]
      if (!is.na(ci_lo) && !is.na(ci_hi)) {
        ci_lo_x <- scale_x(ci_lo)
        ci_hi_x <- scale_x(ci_hi)
        ci_y <- y_pos + bar_height / 2
        whisker_h <- 8
        # Horizontal line
        elements <- c(elements, sprintf(
          '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#475569" stroke-width="1.5"/>',
          ci_lo_x, ci_y, ci_hi_x, ci_y
        ))
        # Left whisker T-cap
        elements <- c(elements, sprintf(
          '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#475569" stroke-width="1.5"/>',
          ci_lo_x, ci_y - whisker_h / 2, ci_lo_x, ci_y + whisker_h / 2
        ))
        # Right whisker T-cap
        elements <- c(elements, sprintf(
          '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#475569" stroke-width="1.5"/>',
          ci_hi_x, ci_y - whisker_h / 2, ci_hi_x, ci_y + whisker_h / 2
        ))
      }
    }

    # Value label (font-weight 600 for bolder contrast)
    vx <- if (val >= 0) scale_x(val) + 4 else scale_x(val) - 4
    vanch <- if (val >= 0) "start" else "end"
    elements <- c(elements, sprintf(
      '<text x="%.1f" y="%.1f" text-anchor="%s" fill="#334155" font-size="12" font-weight="600" dominant-baseline="central">%s</text>',
      vx, y_pos + bar_height / 2, vanch, sprintf("%s%.2f", cs, val)
    ))

    y_pos <- y_pos + bar_height + bar_gap
  }

  chart_height <- y_pos + margin_bottom
  .svg_wrap("wtp", elements, chart_width, chart_height)
}


#' Compute a "nice" tick step for axis labels
#' @keywords internal
.nice_tick_step <- function(range_val) {
  rough <- range_val / 4
  mag <- 10^floor(log10(rough))
  candidates <- c(1, 2, 5, 10) * mag
  candidates[which.min(abs(candidates - rough))]
}


# ==============================================================================
# DEMAND CURVE CHART
# ==============================================================================

#' Build Demand Curve Line Chart (SVG)
#'
#' @param demand_curve Data frame with Price and Share/Demand columns
#' @param brand_colour Hex colour
#' @return HTML string with SVG wrapped in data-chart-id div
#' @keywords internal
build_demand_curve_chart <- function(demand_curve, brand_colour = "#323367", currency_symbol = "$") {

  cs <- currency_symbol %||% "$"
  if (is.null(demand_curve) || nrow(demand_curve) < 2) return("")

  share_col <- if ("Share" %in% names(demand_curve)) "Share" else if ("Demand" %in% names(demand_curve)) "Demand" else NULL
  if (is.null(share_col)) return("")

  chart_width <- 700
  chart_height <- 300
  margin_left <- 60
  margin_right <- 30
  margin_top <- 30
  margin_bottom <- 50
  plot_w <- chart_width - margin_left - margin_right
  plot_h <- chart_height - margin_top - margin_bottom

  prices <- demand_curve$Price
  shares <- demand_curve[[share_col]]

  x_min <- min(prices)
  x_max <- max(prices)
  x_range <- max(x_max - x_min, 1)
  y_min <- 0
  y_max <- max(shares) * 1.1

  scale_x <- function(p) margin_left + (p - x_min) / x_range * plot_w
  scale_y <- function(s) margin_top + (y_max - s) / y_max * plot_h

  elements <- character()

  # Y-axis gridlines
  y_step <- .nice_tick_step(y_max)
  y_ticks <- seq(0, ceiling(y_max / y_step) * y_step, by = y_step)
  for (yt in y_ticks) {
    yy <- scale_y(yt)
    if (yy >= margin_top && yy <= chart_height - margin_bottom) {
      elements <- c(elements, .svg_gridline(margin_left, yy, chart_width - margin_right, yy))
      elements <- c(elements, .svg_axis_label(margin_left - 6, yy, sprintf("%.0f%%", yt), anchor = "end", size = 11))
    }
  }

  # X-axis labels
  x_step <- .nice_tick_step(x_range)
  x_ticks <- seq(ceiling(x_min / x_step) * x_step, floor(x_max / x_step) * x_step, by = x_step)
  for (xt in x_ticks) {
    xx <- scale_x(xt)
    elements <- c(elements, .svg_axis_label(xx, chart_height - margin_bottom + 16, sprintf("%s%.0f", cs, xt), size = 11))
  }

  # Line (rounded joins/caps)
  line_points <- vapply(seq_len(nrow(demand_curve)), function(i) {
    sprintf("%.1f,%.1f", scale_x(prices[i]), scale_y(shares[i]))
  }, character(1))
  elements <- c(elements, sprintf(
    '<polyline points="%s" fill="none" stroke="%s" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"/>',
    paste(line_points, collapse = " "), brand_colour
  ))

  # Data points (white fill, brand stroke for filled-circle look)
  for (i in seq_len(nrow(demand_curve))) {
    cx <- scale_x(prices[i])
    cy <- scale_y(shares[i])
    elements <- c(elements, sprintf(
      '<circle cx="%.1f" cy="%.1f" r="5" fill="#fff" stroke="%s" stroke-width="2.5"/>', cx, cy, brand_colour
    ))
    elements <- c(elements, .svg_value_label(cx, cy - 12, sprintf("%.1f%%", shares[i]), size = 11))
  }

  # Axis title labels
  elements <- c(elements, sprintf(
    '<text x="%.1f" y="%d" text-anchor="middle" fill="#475569" font-size="12" font-weight="400">Price</text>',
    chart_width / 2, chart_height - 5
  ))
  elements <- c(elements, sprintf(
    '<text x="15" y="%.1f" text-anchor="middle" fill="#475569" font-size="12" font-weight="400" transform="rotate(-90,15,%.1f)">Market Share</text>',
    margin_top + plot_h / 2, margin_top + plot_h / 2
  ))

  .svg_wrap("demand-curve", elements, chart_width, chart_height)
}


# ==============================================================================
# CLASS IMPORTANCE CHART (LATENT CLASS)
# ==============================================================================

#' Build Class Importance Grouped Bar Chart (SVG)
#'
#' Side-by-side bars per attribute, one colour per class.
#'
#' @param class_importance Data frame with Attribute and Class_1, Class_2, etc.
#' @param brand_colour Hex base colour (auto-generates palette)
#' @return HTML string with SVG wrapped in data-chart-id div
#' @keywords internal
build_class_importance_chart <- function(class_importance, brand_colour = "#323367") {

  if (is.null(class_importance) || nrow(class_importance) == 0) return("")

  class_cols <- grep("^Class", names(class_importance), value = TRUE)
  if (length(class_cols) == 0) return("")

  n_attrs <- nrow(class_importance)
  n_classes <- length(class_cols)

  chart_width <- max(400, n_attrs * (n_classes * 30 + 40) + 200)
  chart_height <- 280
  margin_left <- 50
  margin_right <- 100  # legend space
  margin_top <- 30
  margin_bottom <- 50
  plot_w <- chart_width - margin_left - margin_right
  plot_h <- chart_height - margin_top - margin_bottom

  group_w <- plot_w / n_attrs
  bar_w <- min(28, (group_w * 0.7) / n_classes)
  max_val <- max(unlist(class_importance[class_cols]), 50) * 1.1

  scale_y <- function(v) margin_top + (max_val - v) / max_val * plot_h

  # Generate class colours from HSL rotation
  palette <- .generate_class_palette(n_classes, brand_colour)

  elements <- character()

  # Y-axis gridlines
  y_step <- .nice_tick_step(max_val)
  y_ticks <- seq(0, ceiling(max_val / y_step) * y_step, by = y_step)
  for (yt in y_ticks) {
    yy <- scale_y(yt)
    if (yy >= margin_top && yy <= chart_height - margin_bottom) {
      elements <- c(elements, .svg_gridline(margin_left, yy, chart_width - margin_right, yy))
      elements <- c(elements, .svg_axis_label(margin_left - 6, yy, sprintf("%.0f%%", yt), anchor = "end", size = 11))
    }
  }

  # Bars
  for (i in seq_len(n_attrs)) {
    group_x <- margin_left + (i - 1) * group_w
    group_center <- group_x + group_w / 2

    for (j in seq_len(n_classes)) {
      val <- class_importance[[class_cols[j]]][i]
      bx <- group_center - (n_classes * bar_w) / 2 + (j - 1) * bar_w
      by <- scale_y(val)
      bh <- scale_y(0) - by

      elements <- c(elements, sprintf(
        '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="4" fill="%s" opacity="0.8"/>',
        bx, by, bar_w - 2, max(bh, 1), palette[j]
      ))

      # Value on top
      elements <- c(elements, .svg_value_label(bx + (bar_w - 2) / 2, by - 5, sprintf("%.0f", val), size = 11))
    }

    # Attribute label (horizontal, no rotation)
    label <- class_importance$Attribute[i]
    if (nchar(label) > 18) label <- paste0(substr(label, 1, 17), "\u2026")
    elements <- c(elements, sprintf(
      '<text x="%.1f" y="%.1f" text-anchor="middle" fill="#64748b" font-size="11">%s</text>',
      group_center, chart_height - margin_bottom + 16, label
    ))
  }

  # Legend
  legend_x <- chart_width - margin_right + 10
  for (j in seq_len(n_classes)) {
    ly <- margin_top + (j - 1) * 22
    elements <- c(elements, sprintf(
      '<rect x="%.1f" y="%.1f" width="14" height="14" rx="3" fill="%s"/>',
      legend_x, ly, palette[j]
    ))
    elements <- c(elements, .svg_axis_label(
      legend_x + 20, ly + 10, gsub("_", " ", class_cols[j]), anchor = "start", size = 11
    ))
  }

  .svg_wrap("class-importance", elements, chart_width, chart_height)
}


#' Generate a palette for latent classes
#' @keywords internal
.generate_class_palette <- function(n, base_colour = "#323367") {
  # Use a set of pre-defined muted colours for up to 6 classes
  muted_palette <- c("#323367", "#2d8a6e", "#c46a3a", "#8b5e9b", "#3a7bc8", "#c45d5d")
  if (n <= length(muted_palette)) {
    return(muted_palette[seq_len(n)])
  }
  # Fallback: repeat palette
  rep_len(muted_palette, n)
}


# ==============================================================================
# CLASS SIZE CHART (LATENT CLASS)
# ==============================================================================

#' Build Class Size Donut/Bar Chart (SVG)
#'
#' Simple horizontal bars showing class proportions.
#'
#' @param class_sizes Numeric vector of class proportions (0-1 or percentages)
#' @param brand_colour Hex base colour
#' @return HTML string with SVG wrapped in data-chart-id div
#' @keywords internal
build_class_size_chart <- function(class_sizes, brand_colour = "#323367") {

  if (is.null(class_sizes) || length(class_sizes) == 0) return("")

  # Normalise to percentages
  sizes <- as.numeric(class_sizes)
  if (all(sizes <= 1)) sizes <- sizes * 100
  n <- length(sizes)

  palette <- .generate_class_palette(n, brand_colour)

  chart_width <- 500
  bar_height <- 28
  bar_gap <- 12
  margin_left <- 80
  margin_right <- 60
  margin_top <- 20
  margin_bottom <- 20
  chart_height <- margin_top + n * (bar_height + bar_gap) + margin_bottom
  plot_w <- chart_width - margin_left - margin_right

  elements <- character()

  for (i in seq_len(n)) {
    y <- margin_top + (i - 1) * (bar_height + bar_gap)
    w <- (sizes[i] / 100) * plot_w

    # Label
    elements <- c(elements, sprintf(
      '<text x="%d" y="%.1f" text-anchor="end" fill="#334155" font-size="13" font-weight="500" dominant-baseline="central">Class %d</text>',
      margin_left - 8, y + bar_height / 2, i
    ))

    # Bar
    elements <- c(elements, sprintf(
      '<rect x="%d" y="%.1f" width="%.1f" height="%d" rx="4" fill="%s" opacity="0.85"/>',
      margin_left, y, max(w, 2), bar_height, palette[i]
    ))

    # Value
    elements <- c(elements, .svg_value_label(
      margin_left + w + 6, y + bar_height / 2,
      sprintf("%.1f%%", sizes[i]), anchor = "start"
    ))
  }

  .svg_wrap("class-sizes", elements, chart_width, chart_height)
}
