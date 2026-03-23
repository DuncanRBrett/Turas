# ==============================================================================
# TURAS PRICING MODULE - HTML REPORT CHART BUILDER (Layer 3)
# ==============================================================================
#
# Purpose: Generate pure SVG charts for pricing HTML reports
# Pattern: Follows tabs module visual conventions
# Version: 2.0.0
# ==============================================================================

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

# htmlEscape is defined in 99_html_report_main.R (sourced before this file)

# ==============================================================================
# VAN WESTENDORP CHART
# ==============================================================================

#' Build VW Cumulative Distribution SVG
#'
#' Draws the four VW cumulative curves with intersection points marked.
#' Uses point pruning to reduce SVG bloat while preserving visual fidelity.
#'
#' @param vw_data Transformed VW section
#' @param brand_colour Brand colour hex
#' @return SVG string
#' @keywords internal
build_vw_curves_chart <- function(vw_data, brand_colour = "#323367") {
  curves <- vw_data$curves
  if (is.null(curves) || !is.data.frame(curves) || nrow(curves) == 0) return("")

  # Chart dimensions (wider viewBox for better proportions)
  width <- 800
  height <- 400
  ml <- 60   # margin left
  mr <- 30   # margin right
  mt <- 40   # margin top
  mb <- 50   # margin bottom
  cw <- width - ml - mr
  ch <- height - mt - mb

  prices <- as.numeric(curves$price)
  valid_idx <- !is.na(prices)
  if (sum(valid_idx) < 2) return("")
  curves <- curves[valid_idx, , drop = FALSE]
  prices <- prices[valid_idx]
  x_min <- min(prices)
  x_max <- max(prices)
  if (x_min == x_max) x_max <- x_min + 1

  scale_x <- function(p) ml + (p - x_min) / (x_max - x_min) * cw
  scale_y <- function(v) mt + (1 - v) * ch

  # Curve colours
  colours <- list(
    too_cheap  = "#e74c3c",
    cheap      = "#f39c12",
    expensive  = "#3498db",
    too_expensive = "#2ecc71"
  )

  # Determine which columns exist
  col_map <- list()
  possible_names <- list(
    too_cheap = c("too_cheap", "Too Cheap", "too.cheap"),
    cheap = c("cheap", "Cheap", "bargain", "Bargain"),
    expensive = c("expensive", "Expensive", "getting_expensive"),
    too_expensive = c("too_expensive", "Too Expensive", "too.expensive")
  )

  for (curve_name in names(possible_names)) {
    for (cn in possible_names[[curve_name]]) {
      if (cn %in% names(curves)) {
        col_map[[curve_name]] <- cn
        break
      }
    }
  }

  if (length(col_map) < 4) return("")

  # Build SVG polylines with point pruning
  lines_svg <- character(0)
  curve_labels <- c(too_cheap = "Too Cheap", cheap = "Cheap/Bargain",
                    expensive = "Expensive", too_expensive = "Too Expensive")

  for (curve_name in names(col_map)) {
    vals <- as.numeric(curves[[col_map[[curve_name]]]])
    if (is.null(vals) || all(is.na(vals))) next

    # Point pruning: skip consecutive points where Y change < 0.002
    keep <- rep(FALSE, length(vals))
    keep[1] <- TRUE
    keep[length(vals)] <- TRUE
    last_kept_y <- vals[1]
    for (i in 2:(length(vals) - 1)) {
      if (is.na(vals[i])) next
      if (abs(vals[i] - last_kept_y) >= 0.002) {
        keep[i] <- TRUE
        last_kept_y <- vals[i]
      }
    }

    pruned_p <- prices[keep]
    pruned_v <- vals[keep]
    points <- paste(sprintf("%.1f,%.1f", scale_x(pruned_p), scale_y(pruned_v)), collapse = " ")
    lines_svg <- c(lines_svg, sprintf(
      '<polyline points="%s" fill="none" stroke="%s" stroke-width="2.5" stroke-linecap="round"/>',
      points, colours[[curve_name]]
    ))
  }

  # Grid lines (5 horizontal, faint)
  grid_svg <- character(0)
  for (v in seq(0, 1, by = 0.25)) {
    y <- scale_y(v)
    grid_svg <- c(grid_svg, sprintf(
      '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e2e8f0" stroke-width="1"/>',
      ml, y, width - mr, y
    ))
    grid_svg <- c(grid_svg, sprintf(
      '<text x="%d" y="%.1f" text-anchor="end" fill="#64748b" font-size="11" font-weight="400">%.0f%%</text>',
      ml - 8, y + 4, v * 100
    ))
  }

  # X-axis labels
  n_ticks <- min(7, length(unique(prices)))
  tick_prices <- pretty(c(x_min, x_max), n = n_ticks)
  tick_prices <- tick_prices[tick_prices >= x_min & tick_prices <= x_max]
  axis_svg <- character(0)
  for (tp in tick_prices) {
    x <- scale_x(tp)
    axis_svg <- c(axis_svg, sprintf(
      '<text x="%.1f" y="%d" text-anchor="middle" fill="#64748b" font-size="11" font-weight="400">%.0f</text>',
      x, height - mb + 20, tp
    ))
  }

  # Intersection markers (OPP, IDP, PMC, PME) with tooltips
  pp <- vw_data$price_points
  markers_svg <- character(0)

  safe_pp <- function(x) {
    v <- x$value
    if (is.null(v)) return(NA_real_)
    if (is.list(v)) v <- unlist(v)
    as.numeric(v[1])
  }

  marker_defs <- list(
    list(price = safe_pp(pp$pmc), label = "PMC", desc = pp$pmc$desc %||% "Point of Marginal Cheapness", colour = "#64748b"),
    list(price = safe_pp(pp$opp), label = "OPP", desc = pp$opp$desc %||% "Optimal Price Point", colour = brand_colour),
    list(price = safe_pp(pp$idp), label = "IDP", desc = pp$idp$desc %||% "Indifference Price Point", colour = brand_colour),
    list(price = safe_pp(pp$pme), label = "PME", desc = pp$pme$desc %||% "Point of Marginal Expensiveness", colour = "#64748b")
  )

  # Collect valid markers with their x positions
  valid_markers <- list()
  for (m in marker_defs) {
    if (is.na(m$price) || !is.numeric(m$price)) next
    m$mx <- scale_x(m$price)
    valid_markers <- c(valid_markers, list(m))
  }

  # Assign label y-offsets to avoid collisions (stagger when close)
  min_gap <- 35  # minimum pixels between labels before staggering
  label_offsets <- rep(mt - 8, length(valid_markers))
  if (length(valid_markers) >= 2) {
    for (i in 2:length(valid_markers)) {
      for (j in 1:(i - 1)) {
        if (abs(valid_markers[[i]]$mx - valid_markers[[j]]$mx) < min_gap &&
            abs(label_offsets[i] - label_offsets[j]) < 10) {
          label_offsets[i] <- label_offsets[j] + 14
        }
      }
    }
  }

  for (i in seq_along(valid_markers)) {
    m <- valid_markers[[i]]
    markers_svg <- c(markers_svg, sprintf(
      '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="%s" stroke-width="1.5" stroke-dasharray="4,3" data-tooltip="%s: $%.2f"/>',
      m$mx, mt, m$mx, height - mb, m$colour, m$desc, m$price
    ))
    markers_svg <- c(markers_svg, sprintf(
      '<text x="%.1f" y="%.0f" text-anchor="middle" fill="%s" font-size="10" font-weight="600">%s</text>',
      m$mx, label_offsets[i], m$colour, m$label
    ))
  }

  # Legend
  legend_y <- height - 12
  legend_items <- character(0)
  lx <- ml
  for (curve_name in names(col_map)) {
    legend_items <- c(legend_items, sprintf(
      '<rect x="%.0f" y="%.0f" width="12" height="3" rx="1" fill="%s"/>
       <text x="%.0f" y="%.0f" fill="#64748b" font-size="10">%s</text>',
      lx, legend_y - 2, colours[[curve_name]],
      lx + 16, legend_y + 2, curve_labels[[curve_name]]
    ))
    lx <- lx + nchar(curve_labels[[curve_name]]) * 6.5 + 30
  }

  svg <- sprintf(
    '<svg viewBox="0 0 %d %d" style="font-family:\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif;width:100%%;height:auto;display:block;margin:0 auto;" role="img" aria-label="Van Westendorp Price Sensitivity Curves">
      %s
      %s
      %s
      %s
      %s
     </svg>',
    width, height,
    paste(grid_svg, collapse = "\n"),
    paste(lines_svg, collapse = "\n"),
    paste(markers_svg, collapse = "\n"),
    paste(axis_svg, collapse = "\n"),
    paste(legend_items, collapse = "\n")
  )

  svg
}


# ==============================================================================
# DEMAND CURVE CHART (GG & MONADIC)
# ==============================================================================

#' Build Demand Curve SVG
#'
#' Line chart showing purchase intent vs price, with optional revenue overlay,
#' CI band, and interactive tooltips. Used for both GG and Monadic results.
#'
#' @param prices Numeric vector of prices
#' @param intents Numeric vector of purchase intents (0-1)
#' @param revenue Optional revenue index vector
#' @param ci_lower Optional lower CI band
#' @param ci_upper Optional upper CI band
#' @param observed_prices Optional observed price points (dots)
#' @param observed_intents Optional observed intents at those prices
#' @param optimal_price Optional optimal price to mark
#' @param brand_colour Brand colour hex
#' @param title Chart title
#' @param currency Currency symbol for axis
#' @return SVG string
#' @keywords internal
build_demand_curve_chart <- function(prices, intents,
                                     revenue = NULL,
                                     ci_lower = NULL, ci_upper = NULL,
                                     observed_prices = NULL,
                                     observed_intents = NULL,
                                     optimal_price = NULL,
                                     brand_colour = "#323367",
                                     title = "Demand Curve",
                                     currency = "$") {

  prices <- as.numeric(prices)
  intents <- as.numeric(intents)
  if (!is.null(revenue)) revenue <- as.numeric(revenue)
  if (!is.null(ci_lower)) ci_lower <- as.numeric(ci_lower)
  if (!is.null(ci_upper)) ci_upper <- as.numeric(ci_upper)
  if (!is.null(observed_prices)) observed_prices <- as.numeric(observed_prices)
  if (!is.null(observed_intents)) observed_intents <- as.numeric(observed_intents)
  if (!is.null(optimal_price)) {
    optimal_price <- as.numeric(optimal_price)
    if (length(optimal_price) > 1) optimal_price <- optimal_price[1]
    if (length(optimal_price) == 0 || is.na(optimal_price)) optimal_price <- NULL
  }

  if (length(prices) < 2 || length(intents) < 2) return("")

  # Chart dimensions (wider viewBox)
  width <- 800
  height <- 400
  ml <- 60
  mr <- 80
  mt <- 35
  mb <- 50
  cw <- width - ml - mr
  ch <- height - mt - mb

  x_min <- min(prices, na.rm = TRUE)
  x_max <- max(prices, na.rm = TRUE)
  if (x_min == x_max) x_max <- x_min + 1

  scale_x <- function(p) ml + (p - x_min) / (x_max - x_min) * cw
  scale_y <- function(v) mt + (1 - v) * ch

  # Revenue scaling
  has_revenue <- !is.null(revenue) && length(revenue) == length(prices) &&
                  any(is.finite(revenue))
  if (has_revenue) {
    rev_max <- max(revenue, na.rm = TRUE) * 1.1
    if (!is.finite(rev_max) || rev_max == 0) rev_max <- 1
    scale_y_rev <- function(r) mt + (1 - r / rev_max) * ch
  }

  parts <- character(0)

  # Grid lines (faint horizontal)
  for (v in seq(0, 1, by = 0.2)) {
    y <- scale_y(v)
    parts <- c(parts, sprintf(
      '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e2e8f0" stroke-width="1"/>',
      ml, y, width - mr, y
    ))
    parts <- c(parts, sprintf(
      '<text x="%d" y="%.1f" text-anchor="end" fill="#64748b" font-size="11" font-weight="400">%.0f%%</text>',
      ml - 8, y + 4, v * 100
    ))
  }

  # X-axis
  n_ticks <- min(7, length(unique(prices)))
  tick_prices <- pretty(c(x_min, x_max), n = n_ticks)
  tick_prices <- tick_prices[tick_prices >= x_min & tick_prices <= x_max]
  for (tp in tick_prices) {
    x <- scale_x(tp)
    parts <- c(parts, sprintf(
      '<text x="%.1f" y="%d" text-anchor="middle" fill="#64748b" font-size="11" font-weight="400">%s%.0f</text>',
      x, height - mb + 20, currency, tp
    ))
  }

  # CI band
  if (!is.null(ci_lower) && !is.null(ci_upper) &&
      length(ci_lower) == length(prices)) {
    upper_points <- paste(sprintf("%.1f,%.1f", scale_x(prices), scale_y(ci_upper)), collapse = " ")
    lower_points <- paste(sprintf("%.1f,%.1f", scale_x(rev(prices)), scale_y(rev(ci_lower))), collapse = " ")
    parts <- c(parts, sprintf(
      '<polygon points="%s %s" fill="%s" opacity="0.12"/>',
      upper_points, lower_points, brand_colour
    ))
  }

  # Revenue curve
  if (has_revenue) {
    rev_points <- paste(sprintf("%.1f,%.1f", scale_x(prices), scale_y_rev(revenue)), collapse = " ")
    parts <- c(parts, sprintf(
      '<polyline points="%s" fill="none" stroke="#f39c12" stroke-width="2" stroke-dasharray="6,3" opacity="0.7"/>',
      rev_points
    ))
    for (rv in pretty(c(0, rev_max), n = 5)) {
      if (rv > rev_max || rv < 0) next
      ry <- scale_y_rev(rv)
      parts <- c(parts, sprintf(
        '<text x="%d" y="%.1f" text-anchor="start" fill="#f39c12" font-size="10" opacity="0.7">%.0f</text>',
        width - mr + 8, ry + 4, rv
      ))
    }
  }

  # Main demand line
  demand_points <- paste(sprintf("%.1f,%.1f", scale_x(prices), scale_y(intents)), collapse = " ")
  parts <- c(parts, sprintf(
    '<polyline points="%s" fill="none" stroke="%s" stroke-width="2.5" stroke-linecap="round"/>',
    demand_points, brand_colour
  ))

  # Data point dots with tooltips (sample every few points to avoid clutter)
  step <- max(1, floor(length(prices) / 20))
  for (i in seq(1, length(prices), by = step)) {
    if (is.na(intents[i])) next
    tooltip_text <- sprintf("Price: %s%.2f, Intent: %.1f%%", currency, prices[i], intents[i] * 100)
    if (has_revenue && !is.na(revenue[i])) {
      tooltip_text <- sprintf("%s, Revenue: %.1f", tooltip_text, revenue[i])
    }
    parts <- c(parts, sprintf(
      '<circle cx="%.1f" cy="%.1f" r="3" fill="%s" opacity="0.5" data-tooltip="%s"/>',
      scale_x(prices[i]), scale_y(intents[i]), brand_colour, tooltip_text
    ))
  }

  # Observed data points (larger, prominent)
  if (!is.null(observed_prices) && !is.null(observed_intents)) {
    for (i in seq_along(observed_prices)) {
      if (is.na(observed_prices[i]) || is.na(observed_intents[i])) next
      ox <- scale_x(observed_prices[i])
      oy <- scale_y(observed_intents[i])
      tooltip_text <- sprintf("Observed: %s%.2f, Intent: %.1f%%",
                              currency, observed_prices[i], observed_intents[i] * 100)
      parts <- c(parts, sprintf(
        '<circle cx="%.1f" cy="%.1f" r="4.5" fill="white" stroke="%s" stroke-width="2" data-tooltip="%s"/>',
        ox, oy, brand_colour, tooltip_text
      ))
    }
  }

  # Optimal price marker
  if (!is.null(optimal_price)) {
    opt_x <- scale_x(optimal_price)
    opt_idx <- which.min(abs(prices - optimal_price))
    opt_y <- scale_y(intents[opt_idx])

    parts <- c(parts, sprintf(
      '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e74c3c" stroke-width="1.5" stroke-dasharray="4,3"/>',
      opt_x, mt, opt_x, height - mb
    ))
    parts <- c(parts, sprintf(
      '<circle cx="%.1f" cy="%.1f" r="5" fill="#e74c3c" stroke="white" stroke-width="2" data-tooltip="Optimal: %s%.2f (%.1f%% intent)"/>',
      opt_x, opt_y, currency, optimal_price, intents[opt_idx] * 100
    ))
    parts <- c(parts, sprintf(
      '<text x="%.1f" y="%d" text-anchor="middle" fill="#e74c3c" font-size="10" font-weight="600">Optimal: %s%.2f</text>',
      opt_x, mt - 8, currency, optimal_price
    ))
  }

  # Legend
  legend_y <- height - 10
  legend_items <- sprintf(
    '<rect x="%d" y="%.0f" width="14" height="3" rx="1" fill="%s"/>
     <text x="%d" y="%.0f" fill="#64748b" font-size="10">Purchase Intent</text>',
    ml, legend_y - 2, brand_colour, ml + 18, legend_y + 2
  )
  if (has_revenue) {
    legend_items <- c(legend_items, sprintf(
      '<rect x="%d" y="%.0f" width="14" height="3" rx="1" fill="#f39c12" opacity="0.7"/>
       <text x="%d" y="%.0f" fill="#64748b" font-size="10">Revenue Index</text>',
      ml + 140, legend_y - 2, ml + 158, legend_y + 2
    ))
  }

  sprintf(
    '<svg viewBox="0 0 %d %d" style="font-family:\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif;width:100%%;height:auto;display:block;margin:0 auto;" role="img" aria-label="%s">
      %s
      %s
     </svg>',
    width, height,
    htmlEscape(title),
    paste(parts, collapse = "\n"),
    paste(legend_items, collapse = "\n")
  )
}


# ==============================================================================
# SEGMENT COMPARISON CHART
# ==============================================================================

#' Build Segment Comparison Bar Chart
#'
#' Horizontal bar chart comparing a key metric across segments.
#'
#' @param segment_data Transformed segments section
#' @param brand_colour Brand colour hex
#' @param currency Currency symbol
#' @return SVG string
#' @keywords internal
build_segment_comparison_chart <- function(segment_data, brand_colour = "#323367",
                                           currency = "$") {
  ct <- segment_data$comparison_table
  if (is.null(ct) || !is.data.frame(ct) || nrow(ct) == 0) return("")

  price_col <- NULL
  for (cn in c("OPP", "Optimal_Price", "optimal_price", "Revenue_Optimal", "price")) {
    if (cn %in% names(ct)) { price_col <- cn; break }
  }
  if (is.null(price_col)) return("")

  seg_col <- names(ct)[1]

  segments <- as.character(ct[[seg_col]])
  prices <- as.numeric(ct[[price_col]])
  valid <- !is.na(prices)
  segments <- segments[valid]
  prices <- prices[valid]
  if (length(prices) == 0) return("")

  n <- length(segments)
  row_height <- 36
  width <- 700
  ml <- 150
  mr <- 80
  mt <- 30
  mb <- 30
  cw <- width - ml - mr
  height <- mt + n * row_height + mb

  p_min <- min(prices) * 0.85
  p_max <- max(prices) * 1.05
  if (p_min == p_max) p_max <- p_min + 1
  scale_x <- function(p) ml + (p - p_min) / (p_max - p_min) * cw

  palette <- generate_palette(n, brand_colour)

  parts <- character(0)

  # Gridlines
  ticks <- pretty(c(p_min, p_max), n = 5)
  ticks <- ticks[ticks >= p_min & ticks <= p_max]
  for (tp in ticks) {
    x <- scale_x(tp)
    parts <- c(parts, sprintf(
      '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e2e8f0" stroke-width="1"/>',
      x, mt, x, height - mb
    ))
    parts <- c(parts, sprintf(
      '<text x="%.1f" y="%d" text-anchor="middle" fill="#64748b" font-size="10">%s%.0f</text>',
      x, height - mb + 16, currency, tp
    ))
  }

  # Bars with tooltips
  for (i in seq_along(segments)) {
    y_center <- mt + (i - 0.5) * row_height
    bar_h <- row_height * 0.55

    # Label
    parts <- c(parts, sprintf(
      '<text x="%d" y="%.1f" text-anchor="end" fill="#64748b" font-size="11" font-weight="400" dominant-baseline="middle">%s</text>',
      ml - 10, y_center, htmlEscape(segments[i])
    ))

    # Bar (rounded corners)
    bar_x <- scale_x(p_min)
    bar_w <- scale_x(prices[i]) - bar_x
    tooltip_text <- sprintf("%s: %s%.2f", segments[i], currency, prices[i])
    parts <- c(parts, sprintf(
      '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="4" fill="%s" opacity="0.75" data-tooltip="%s"/>',
      bar_x, y_center - bar_h / 2, bar_w, bar_h, palette[i], tooltip_text
    ))

    # Value label
    parts <- c(parts, sprintf(
      '<text x="%.1f" y="%.1f" fill="#334155" font-size="12" font-weight="500" dominant-baseline="middle">%s%.2f</text>',
      scale_x(prices[i]) + 6, y_center, currency, prices[i]
    ))
  }

  sprintf(
    '<svg viewBox="0 0 %d %d" style="font-family:\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif;width:100%%;height:auto;display:block;margin:0 auto;" role="img" aria-label="Segment Price Comparison">
      %s
     </svg>',
    width, height,
    paste(parts, collapse = "\n")
  )
}


# ==============================================================================
# ELASTICITY CHART
# ==============================================================================

#' Build Elasticity Classification Bar Chart
#'
#' @param elasticity_data Data frame with price_midpoint, elasticity, classification
#' @param brand_colour Brand colour hex
#' @param currency Currency symbol
#' @return SVG string
#' @keywords internal
build_elasticity_chart <- function(elasticity_data, brand_colour = "#323367",
                                    currency = "$") {
  if (is.null(elasticity_data) || !is.data.frame(elasticity_data) || nrow(elasticity_data) == 0) return("")

  width <- 800
  height <- 300
  ml <- 60
  mr <- 30
  mt <- 30
  mb <- 50
  cw <- width - ml - mr
  ch <- height - mt - mb

  # Resolve column names
  prices <- elasticity_data$price_midpoint %||% elasticity_data$price_low
  if (is.null(prices) && !is.null(elasticity_data$price_from)) {
    if (!is.null(elasticity_data$price_to)) {
      prices <- (as.numeric(elasticity_data$price_from) + as.numeric(elasticity_data$price_to)) / 2
    } else {
      prices <- elasticity_data$price_from
    }
  }
  elast <- elasticity_data$elasticity %||% elasticity_data$arc_elasticity

  prices <- as.numeric(prices)
  elast <- as.numeric(elast)

  valid <- is.finite(prices) & is.finite(elast)
  prices <- prices[valid]
  elast <- elast[valid]

  if (is.null(prices) || is.null(elast) || length(prices) == 0) return("")

  x_min <- min(prices)
  x_max <- max(prices)
  if (x_min == x_max) x_max <- x_min + 1
  y_min <- min(elast, -2)
  y_max <- max(elast, 0.5)
  if (y_min == y_max) y_max <- y_min + 1

  scale_x <- function(p) ml + (p - x_min) / (x_max - x_min) * cw
  scale_y <- function(e) mt + (y_max - e) / (y_max - y_min) * ch

  parts <- character(0)

  # Horizontal grid
  for (ev in pretty(c(y_min, y_max), n = 5)) {
    if (ev < y_min || ev > y_max) next
    y <- scale_y(ev)
    parts <- c(parts, sprintf(
      '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e2e8f0" stroke-width="1"/>',
      ml, y, width - mr, y
    ))
    parts <- c(parts, sprintf(
      '<text x="%d" y="%.1f" text-anchor="end" fill="#64748b" font-size="10">%.1f</text>',
      ml - 8, y + 4, ev
    ))
  }

  # Unitary elasticity line (e = -1)
  if (y_min <= -1 && y_max >= -1) {
    y_unity <- scale_y(-1)
    parts <- c(parts, sprintf(
      '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e74c3c" stroke-width="1" stroke-dasharray="4,3" opacity="0.6"/>',
      ml, y_unity, width - mr, y_unity
    ))
    parts <- c(parts, sprintf(
      '<text x="%d" y="%.1f" fill="#e74c3c" font-size="9" opacity="0.7">e = -1 (unitary)</text>',
      width - mr - 80, y_unity - 6
    ))
  }

  # Elasticity line
  points <- paste(sprintf("%.1f,%.1f", scale_x(prices), scale_y(elast)), collapse = " ")
  parts <- c(parts, sprintf(
    '<polyline points="%s" fill="none" stroke="%s" stroke-width="2.5" stroke-linecap="round"/>',
    points, brand_colour
  ))

  # Points with colour coding and tooltips
  for (i in seq_along(prices)) {
    cx <- scale_x(prices[i])
    cy <- scale_y(elast[i])
    colour <- if (!is.na(elast[i]) && abs(elast[i]) > 1) "#e74c3c" else "#2ecc71"
    class_text <- if (!is.na(elast[i]) && abs(elast[i]) > 1) "Elastic" else "Inelastic"
    tooltip_text <- sprintf("Price: %s%.0f, Elasticity: %.2f (%s)", currency, prices[i], elast[i], class_text)
    parts <- c(parts, sprintf(
      '<circle cx="%.1f" cy="%.1f" r="4" fill="%s" stroke="white" stroke-width="1.5" data-tooltip="%s"/>',
      cx, cy, colour, tooltip_text
    ))
  }

  # X-axis
  for (tp in pretty(c(x_min, x_max), n = 6)) {
    if (tp < x_min || tp > x_max) next
    parts <- c(parts, sprintf(
      '<text x="%.1f" y="%d" text-anchor="middle" fill="#64748b" font-size="10">%s%.0f</text>',
      scale_x(tp), height - mb + 18, currency, tp
    ))
  }

  sprintf(
    '<svg viewBox="0 0 %d %d" style="font-family:\'Inter\', system-ui, -apple-system, \'Segoe UI\', sans-serif;width:100%%;height:auto;display:block;margin:0 auto;" role="img" aria-label="Price Elasticity">
      %s
     </svg>',
    width, height,
    paste(parts, collapse = "\n")
  )
}


# ==============================================================================
# UTILITY: PALETTE GENERATOR
# ==============================================================================

#' Generate Colour Palette from Brand Colour
#' @param n Number of colours needed
#' @param brand_colour Base brand colour hex
#' @return Character vector of hex colours
#' @keywords internal
generate_palette <- function(n, brand_colour = "#323367") {
  if (n <= 0) return(character(0))

  base_palette <- c(
    brand_colour,
    "#2aa198",
    "#f39c12",
    "#e74c3c",
    "#9b59b6",
    "#3498db",
    "#1abc9c",
    "#e67e22"
  )

  rep_len(base_palette, n)
}
