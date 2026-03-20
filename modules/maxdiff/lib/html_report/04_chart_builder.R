# ==============================================================================
# MAXDIFF HTML REPORT - CHART BUILDER - TURAS V11.0
# ==============================================================================
# Builds pure SVG charts for the MaxDiff report
# Layer 3 of the 4-layer HTML report pipeline
#
# All charts are inline SVG strings -- no external dependencies.
# ==============================================================================

# ==============================================================================
# UTILITY HELPERS
# ==============================================================================

svg_font <- "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"

svg_wrap <- function(inner, width, height, aria_label) {
  sprintf(
    '<svg viewBox="0 0 %d %d" style="font-family:%s;width:100%%;max-width:%dpx;height:auto;display:block;margin:0 auto;" role="img" aria-label="%s">%s</svg>',
    width, height, svg_font, width, aria_label, inner
  )
}


# ==============================================================================
# PREFERENCE SHARE BAR CHART (Horizontal)
# ==============================================================================

#' Build horizontal bar chart of preference shares or rescaled utilities
#'
#' @param scores Data frame with Item_Label, Rescaled (or Pref_Share)
#' @param brand_colour Hex colour for bars
#' @param use_shares Logical. If TRUE, use Pref_Share column
#'
#' @return SVG string
#' @keywords internal
build_preference_chart <- function(scores, brand_colour = "#1e3a5f", use_shares = FALSE) {

  if (is.null(scores) || nrow(scores) == 0) return("")

  # Sort by value descending
  val_col <- if (use_shares && "Pref_Share" %in% names(scores)) "Pref_Share" else "Rescaled"
  scores <- scores[order(-scores[[val_col]]), ]

  n <- nrow(scores)
  bar_height <- 28
  gap <- 6
  ml <- 180  # left margin for labels
  mr <- 60   # right margin for values
  mt <- 30
  mb <- 20
  chart_width <- 720
  cw <- chart_width - ml - mr
  ch <- n * (bar_height + gap)
  total_height <- mt + ch + mb

  max_val <- max(scores[[val_col]], na.rm = TRUE)
  if (max_val <= 0) max_val <- 1
  scale_x <- function(v) ml + (v / max_val) * cw

  # Grid lines
  n_grid <- 5
  grid_vals <- pretty(c(0, max_val), n_grid)
  grid_vals <- grid_vals[grid_vals >= 0 & grid_vals <= max_val * 1.1]

  grid_lines <- paste(vapply(grid_vals, function(gv) {
    x <- scale_x(gv)
    label_text <- if (use_shares) sprintf("%.0f%%", gv) else sprintf("%.0f", gv)
    paste0(
      sprintf('<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#e2e8f0" stroke-width="1"/>', x, mt, x, mt + ch),
      sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="10">%s</text>', x, mt + ch + 14, label_text)
    )
  }, character(1)), collapse = "\n")

  # Bars
  bars <- paste(vapply(seq_len(n), function(i) {
    y <- mt + (i - 1) * (bar_height + gap)
    val <- scores[[val_col]][i]
    w <- max(2, (val / max_val) * cw)
    label <- scores$Item_Label[i]
    if (nchar(label) > 25) label <- paste0(substr(label, 1, 22), "...")

    val_label <- if (use_shares) sprintf("%.1f%%", val) else sprintf("%.0f", val)

    paste0(
      sprintf('<text x="%d" y="%g" text-anchor="end" fill="#1e293b" font-size="12" font-weight="500" dominant-baseline="middle">%s</text>',
              ml - 8, y + bar_height / 2, label),
      sprintf('<rect x="%d" y="%g" width="%g" height="%d" rx="4" fill="%s" opacity="0.8"/>',
              ml, y, w, bar_height, brand_colour),
      sprintf('<text x="%g" y="%g" fill="#1e293b" font-size="11" font-weight="500" dominant-baseline="middle">%s</text>',
              ml + w + 6, y + bar_height / 2, val_label)
    )
  }, character(1)), collapse = "\n")

  svg_wrap(paste(grid_lines, bars, sep = "\n"), chart_width, total_height, "Preference scores chart")
}


# ==============================================================================
# ANCHORED MAXDIFF THRESHOLD CHART
# ==============================================================================

#' Build anchor threshold chart showing must-have rates per item
#'
#' Horizontal bar chart of anchor rates with a vertical dashed threshold line.
#' Items above the threshold are highlighted as "must-haves".
#'
#' @param anchor_data Data frame with Item_Label, Anchor_Rate, Is_Must_Have
#' @param brand_colour Hex colour for bars
#' @param threshold Numeric. The must-have threshold (0-1 scale)
#'
#' @return SVG string, or "" if no anchor data
#' @keywords internal
build_anchor_threshold_chart <- function(anchor_data, brand_colour = "#1e3a5f", threshold = 0.50) {

  if (is.null(anchor_data) || !is.data.frame(anchor_data) || nrow(anchor_data) == 0) return("")
  if (!"Anchor_Rate" %in% names(anchor_data)) return("")

  # Sort by anchor rate descending
  anchor_data <- anchor_data[order(-anchor_data$Anchor_Rate), ]

  n <- nrow(anchor_data)
  bar_height <- 28
  gap <- 6
  ml <- 180
  mr <- 60
  mt <- 30
  mb <- 20
  chart_width <- 720
  cw <- chart_width - ml - mr
  ch <- n * (bar_height + gap)
  total_height <- mt + ch + mb

  max_val <- max(anchor_data$Anchor_Rate * 100, threshold * 100, na.rm = TRUE) * 1.1
  if (max_val <= 0) max_val <- 100
  scale_x <- function(v) ml + (v / max_val) * cw

  # Grid lines
  grid_vals <- pretty(c(0, max_val), 5)
  grid_vals <- grid_vals[grid_vals >= 0 & grid_vals <= max_val]
  grid_lines <- paste(vapply(grid_vals, function(gv) {
    x <- scale_x(gv)
    paste0(
      sprintf('<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#e2e8f0" stroke-width="1"/>', x, mt, x, mt + ch),
      sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="10">%.0f%%</text>', x, mt + ch + 14, gv)
    )
  }, character(1)), collapse = "\n")

  # Threshold line
  threshold_x <- scale_x(threshold * 100)
  threshold_line <- paste0(
    sprintf('<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#e74c3c" stroke-width="2" stroke-dasharray="6,4"/>', threshold_x, mt - 5, threshold_x, mt + ch),
    sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#e74c3c" font-size="10" font-weight="600">Must-Have Threshold (%.0f%%)</text>', threshold_x, mt - 8, threshold * 100)
  )

  # Bars
  bars <- paste(vapply(seq_len(n), function(i) {
    y <- mt + (i - 1) * (bar_height + gap)
    rate <- anchor_data$Anchor_Rate[i] * 100
    is_must_have <- if ("Is_Must_Have" %in% names(anchor_data)) anchor_data$Is_Must_Have[i] else (rate >= threshold * 100)
    w <- max(2, (rate / max_val) * cw)
    label <- anchor_data$Item_Label[i] %||% anchor_data$Item_ID[i]
    if (nchar(label) > 25) label <- paste0(substr(label, 1, 22), "...")

    bar_colour <- if (is_must_have) "#27ae60" else brand_colour
    label_weight <- if (is_must_have) "600" else "500"

    paste0(
      sprintf('<text x="%d" y="%g" text-anchor="end" fill="#1e293b" font-size="12" font-weight="%s" dominant-baseline="middle">%s</text>',
              ml - 8, y + bar_height / 2, label_weight, htmlEscape(label)),
      sprintf('<rect x="%d" y="%g" width="%g" height="%d" rx="4" fill="%s" opacity="0.8"/>',
              ml, y, w, bar_height, bar_colour),
      sprintf('<text x="%g" y="%g" fill="#1e293b" font-size="11" font-weight="500" dominant-baseline="middle">%.0f%%</text>',
              ml + w + 6, y + bar_height / 2, rate)
    )
  }, character(1)), collapse = "\n")

  svg_wrap(paste(grid_lines, threshold_line, bars, sep = "\n"), chart_width, total_height, "Anchored MaxDiff threshold chart")
}


# ==============================================================================
# BEST/WORST DIVERGING BAR CHART
# ==============================================================================

#' Build diverging bar chart for Best% and Worst%
#'
#' @param count_data Data frame with Item_Label, Best_Pct, Worst_Pct
#' @param brand_colour Hex colour for Best bars
#'
#' @return SVG string
#' @keywords internal
build_diverging_chart <- function(count_data, brand_colour = "#1e3a5f") {

  if (is.null(count_data) || nrow(count_data) == 0) return("")

  n <- nrow(count_data)
  bar_height <- 24
  gap <- 5
  ml <- 160   # left margin for labels
  mr <- 30
  mt <- 40
  mb <- 30
  chart_width <- 720
  center_x <- ml + (chart_width - ml - mr) / 2
  half_width <- (chart_width - ml - mr) / 2

  max_pct <- max(c(count_data$Best_Pct, count_data$Worst_Pct), na.rm = TRUE)
  if (max_pct <= 0) max_pct <- 1

  ch <- n * (bar_height + gap)
  total_height <- mt + ch + mb

  scale <- function(pct) (pct / max_pct) * half_width * 0.9

  # Center line
  center_line <- sprintf(
    '<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#cbd5e1" stroke-width="1.5"/>',
    center_x, mt - 5, center_x, mt + ch + 5
  )

  # Headers
  headers <- paste0(
    sprintf('<text x="%g" y="%d" text-anchor="end" fill="#e74c3c" font-size="11" font-weight="600">WORST %%</text>', center_x - 10, mt - 12),
    sprintf('<text x="%g" y="%d" fill="%s" font-size="11" font-weight="600">BEST %%</text>', center_x + 10, mt - 12, brand_colour)
  )

  # Bars
  bars <- paste(vapply(seq_len(n), function(i) {
    y <- mt + (i - 1) * (bar_height + gap)
    label <- count_data$Item_Label[i]
    if (nchar(label) > 22) label <- paste0(substr(label, 1, 19), "...")
    best <- count_data$Best_Pct[i]
    worst <- count_data$Worst_Pct[i]

    best_w <- scale(best)
    worst_w <- scale(worst)

    paste0(
      # Label
      sprintf('<text x="%d" y="%g" text-anchor="end" fill="#1e293b" font-size="11" font-weight="400" dominant-baseline="middle">%s</text>',
              ml - 8, y + bar_height / 2, label),
      # Worst bar (left of center, red)
      sprintf('<rect x="%g" y="%g" width="%g" height="%d" rx="4" fill="#e74c3c" opacity="0.7"/>',
              center_x - worst_w, y, worst_w, bar_height),
      # Worst label
      if (worst >= 3) sprintf('<text x="%g" y="%g" text-anchor="end" fill="#64748b" font-size="10" dominant-baseline="middle">%.0f%%</text>',
              center_x - worst_w - 4, y + bar_height / 2, worst) else "",
      # Best bar (right of center, brand)
      sprintf('<rect x="%g" y="%g" width="%g" height="%d" rx="4" fill="%s" opacity="0.8"/>',
              center_x, y, best_w, bar_height, brand_colour),
      # Best label
      if (best >= 3) sprintf('<text x="%g" y="%g" fill="#64748b" font-size="10" dominant-baseline="middle">%.0f%%</text>',
              center_x + best_w + 4, y + bar_height / 2, best) else ""
    )
  }, character(1)), collapse = "\n")

  svg_wrap(paste(center_line, headers, bars, sep = "\n"), chart_width, total_height,
           "Best vs Worst diverging chart")
}


# ==============================================================================
# TURF REACH CURVE
# ==============================================================================

#' Build TURF incremental reach curve (line chart)
#'
#' @param reach_curve Data frame with Portfolio_Size and Reach_Pct
#' @param brand_colour Hex colour
#'
#' @return SVG string
#' @keywords internal
build_turf_chart <- function(reach_curve, brand_colour = "#1e3a5f") {

  if (is.null(reach_curve) || nrow(reach_curve) < 2) return("")

  chart_width <- 720
  chart_height <- 380
  ml <- 60
  mr <- 30
  mt <- 30
  mb <- 50
  cw <- chart_width - ml - mr
  ch <- chart_height - mt - mb

  max_x <- max(reach_curve$Portfolio_Size)
  max_y <- min(100, max(reach_curve$Reach_Pct) * 1.1)

  scale_x <- function(v) ml + (v / max_x) * cw
  scale_y <- function(v) mt + (1 - v / max_y) * ch

  # Grid lines
  y_ticks <- seq(0, max_y, by = 20)
  grid <- paste(vapply(y_ticks, function(yt) {
    y <- scale_y(yt)
    paste0(
      sprintf('<line x1="%d" y1="%g" x2="%d" y2="%g" stroke="#e2e8f0" stroke-width="1"/>', ml, y, ml + cw, y),
      sprintf('<text x="%d" y="%g" text-anchor="end" fill="#64748b" font-size="11">%d%%</text>', ml - 8, y + 4, yt)
    )
  }, character(1)), collapse = "\n")

  # X axis labels
  x_labels <- paste(vapply(seq(0, max_x), function(xt) {
    sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#64748b" font-size="11">%d</text>',
            scale_x(xt), mt + ch + 20, xt)
  }, character(1)), collapse = "\n")

  x_axis_label <- sprintf(
    '<text x="%g" y="%d" text-anchor="middle" fill="#64748b" font-size="12" font-weight="500">Portfolio Size</text>',
    ml + cw / 2, mt + ch + 40
  )

  # Line + dots
  points <- paste(vapply(seq_len(nrow(reach_curve)), function(i) {
    sprintf("%g,%g", scale_x(reach_curve$Portfolio_Size[i]), scale_y(reach_curve$Reach_Pct[i]))
  }, character(1)), collapse = " ")

  line <- sprintf(
    '<polyline points="%s" fill="none" stroke="%s" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>',
    points, brand_colour
  )

  dots <- paste(vapply(seq_len(nrow(reach_curve)), function(i) {
    x <- scale_x(reach_curve$Portfolio_Size[i])
    y <- scale_y(reach_curve$Reach_Pct[i])
    val <- reach_curve$Reach_Pct[i]
    paste0(
      sprintf('<circle cx="%g" cy="%g" r="4" fill="%s" stroke="white" stroke-width="1.5"/>', x, y, brand_colour),
      if (i > 1) sprintf('<text x="%g" y="%g" text-anchor="middle" fill="#1e293b" font-size="10" font-weight="500">%.0f%%</text>',
              x, y - 10, val) else ""
    )
  }, character(1)), collapse = "\n")

  svg_wrap(paste(grid, x_labels, x_axis_label, line, dots, sep = "\n"),
           chart_width, chart_height, "TURF reach curve")
}


# ==============================================================================
# SEGMENT COMPARISON CHART
# ==============================================================================

#' Build segment comparison grouped bar chart
#'
#' @param segment_data Segment results
#' @param brand_colour Hex colour
#'
#' @return SVG string (or empty string if no data)
#' @keywords internal
build_segment_chart <- function(segment_data, brand_colour = "#1e3a5f") {

  if (is.null(segment_data) || length(segment_data) == 0) return("")

  # Build one grouped bar chart per segment variable
  charts <- vapply(names(segment_data), function(seg_var) {

    df <- segment_data[[seg_var]]
    if (is.null(df) || nrow(df) == 0) return("")

    # Identify BW_Score columns (one per segment level)
    bw_cols <- grep("^BW_Score_", names(df), value = TRUE)
    if (length(bw_cols) == 0) return("")

    # Derive clean segment level names from column names
    seg_levels <- sub("^BW_Score_", "", bw_cols)
    seg_levels <- gsub("_", " ", seg_levels)
    n_seg <- min(length(seg_levels), 6)  # cap at 6 segments
    bw_cols  <- bw_cols[seq_len(n_seg)]
    seg_levels <- seg_levels[seq_len(n_seg)]

    # Sort items by overall mean score descending
    row_means <- rowMeans(df[, bw_cols, drop = FALSE], na.rm = TRUE)
    df <- df[order(-row_means), ]

    n_items <- nrow(df)
    colours <- generate_md_palette(n_seg, brand_colour)

    # --- Layout dimensions ---
    bar_height   <- 14
    bar_gap      <- 3       # gap between bars within a group
    group_gap    <- 12      # gap between item groups
    ml           <- 180     # left margin for item labels
    mr           <- 60      # right margin for value labels
    mt           <- 30      # top margin
    legend_h     <- 30      # space for legend
    mb           <- 20      # bottom margin
    chart_width  <- 720
    cw           <- chart_width - ml - mr
    group_height <- n_seg * (bar_height + bar_gap) - bar_gap
    ch           <- n_items * (group_height + group_gap) - group_gap
    total_height <- mt + legend_h + ch + mb

    # Max value for scaling
    all_vals <- unlist(df[, bw_cols, drop = FALSE])
    max_val  <- max(all_vals, na.rm = TRUE)
    if (is.na(max_val) || max_val <= 0) max_val <- 1
    scale_x  <- function(v) ml + (v / max_val) * cw

    # --- Legend ---
    legend_items <- paste(vapply(seq_len(n_seg), function(s) {
      lx <- ml + (s - 1) * 120
      ly <- mt + 4
      paste0(
        sprintf('<rect x="%g" y="%g" width="14" height="14" rx="3" fill="%s" opacity="0.8"/>',
                lx, ly, colours[s]),
        sprintf('<text x="%g" y="%g" fill="#64748b" font-size="11" font-weight="400" dominant-baseline="middle">%s</text>',
                lx + 20, ly + 7, seg_levels[s])
      )
    }, character(1)), collapse = "\n")

    content_top <- mt + legend_h

    # --- Grid lines ---
    grid_vals <- pretty(c(0, max_val), 5)
    grid_vals <- grid_vals[grid_vals >= 0 & grid_vals <= max_val * 1.1]
    grid_lines <- paste(vapply(grid_vals, function(gv) {
      x <- scale_x(gv)
      paste0(
        sprintf('<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#e2e8f0" stroke-width="1"/>',
                x, content_top, x, content_top + ch),
        sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="10">%.0f</text>',
                x, content_top + ch + 14, gv)
      )
    }, character(1)), collapse = "\n")

    # --- Grouped bars ---
    bars <- paste(vapply(seq_len(n_items), function(i) {
      group_y <- content_top + (i - 1) * (group_height + group_gap)
      label <- df$Item_Label[i]
      if (nchar(label) > 25) label <- paste0(substr(label, 1, 22), "...")

      # Item label centred vertically on the group
      label_svg <- sprintf(
        '<text x="%d" y="%g" text-anchor="end" fill="#1e293b" font-size="11" font-weight="500" dominant-baseline="middle">%s</text>',
        ml - 8, group_y + group_height / 2, label
      )

      # One bar per segment level
      seg_bars <- paste(vapply(seq_len(n_seg), function(s) {
        by <- group_y + (s - 1) * (bar_height + bar_gap)
        val <- df[[bw_cols[s]]][i]
        if (is.na(val)) val <- 0
        w <- max(2, (val / max_val) * cw)
        paste0(
          sprintf('<rect x="%d" y="%g" width="%g" height="%d" rx="4" fill="%s" opacity="0.8"/>',
                  ml, by, w, bar_height, colours[s]),
          sprintf('<text x="%g" y="%g" fill="#64748b" font-size="10" font-weight="500" dominant-baseline="middle">%.0f</text>',
                  ml + w + 5, by + bar_height / 2, val)
        )
      }, character(1)), collapse = "\n")

      paste0(label_svg, "\n", seg_bars)
    }, character(1)), collapse = "\n")

    aria <- sprintf("Segment comparison chart for %s showing %d items across %d segments",
                    seg_var, n_items, n_seg)

    svg_wrap(paste(legend_items, grid_lines, bars, sep = "\n"),
             chart_width, total_height, aria)

  }, character(1))

  # Concatenate all segment variable charts separated by spacing div
  paste(charts[charts != ""], collapse = '\n<div style="height:24px;"></div>\n')
}


# ==============================================================================
# ITEM STRATEGY QUADRANT (Scatter: Mean Utility vs SD)
# ==============================================================================

#' Build Item Strategy Quadrant scatter chart
#'
#' Plots mean utility (x) vs standard deviation (y) for each item,
#' creating four strategic quadrants:
#' - High Mean, Low SD = Universal Favourites (top-left when rotated, or bottom-right standard)
#' - High Mean, High SD = Polarising Leaders
#' - Low Mean, Low SD = Low Priority
#' - Low Mean, High SD = Divisive Rejects
#'
#' @param hb_pop Data frame with Item_Label, HB_Utility_Mean, HB_Utility_SD
#' @param brand_colour Hex colour
#'
#' @return SVG string
#' @keywords internal
build_strategy_quadrant <- function(hb_pop, brand_colour = "#1e3a5f") {

  if (is.null(hb_pop) || nrow(hb_pop) < 3) return("")
  if (!all(c("HB_Utility_Mean", "HB_Utility_SD") %in% names(hb_pop))) return("")

  n <- nrow(hb_pop)
  means <- hb_pop$HB_Utility_Mean
  sds <- hb_pop$HB_Utility_SD
  labels <- hb_pop$Item_Label %||% hb_pop$Item_ID

  chart_width <- 720
  chart_height <- 520
  ml <- 70    # left margin
  mr <- 30
  mt <- 40
  mb <- 60
  cw <- chart_width - ml - mr
  ch <- chart_height - mt - mb

  # Scales
  x_min <- min(means) - diff(range(means)) * 0.1
  x_max <- max(means) + diff(range(means)) * 0.1
  y_min <- 0
  y_max <- max(sds) * 1.2

  if (x_max - x_min < 0.01) { x_min <- x_min - 1; x_max <- x_max + 1 }
  if (y_max < 0.01) y_max <- 1

  scale_x <- function(v) ml + (v - x_min) / (x_max - x_min) * cw
  scale_y <- function(v) mt + (1 - (v - y_min) / (y_max - y_min)) * ch

  # Quadrant dividers at median
  med_x <- median(means)
  med_y <- median(sds)
  qx <- scale_x(med_x)
  qy <- scale_y(med_y)

  # Quadrant background fills (very subtle)
  quadrants <- paste0(
    sprintf('<rect x="%g" y="%g" width="%g" height="%g" fill="#dcfce7" opacity="0.25"/>', ml, qy, qx - ml, mt + ch - qy),       # Bottom-left: Low priority (green-ish)
    sprintf('<rect x="%g" y="%g" width="%g" height="%g" fill="#dbeafe" opacity="0.25"/>', qx, qy, ml + cw - qx, mt + ch - qy),   # Bottom-right: Universal Favourite
    sprintf('<rect x="%g" y="%g" width="%g" height="%g" fill="#fef3c7" opacity="0.25"/>', ml, mt, qx - ml, qy - mt),              # Top-left: Divisive
    sprintf('<rect x="%g" y="%g" width="%g" height="%g" fill="#fce7f3" opacity="0.25"/>', qx, mt, ml + cw - qx, qy - mt)          # Top-right: Polarising Leaders
  )

  # Quadrant labels (corners)
  q_labels <- paste0(
    sprintf('<text x="%d" y="%d" fill="#94a3b8" font-size="10" font-weight="500" font-style="italic">Low Priority</text>', ml + 8, mt + ch - 8),
    sprintf('<text x="%d" y="%d" fill="#94a3b8" font-size="10" font-weight="500" font-style="italic" text-anchor="end">Universal Favourites</text>', ml + cw - 8, mt + ch - 8),
    sprintf('<text x="%d" y="%d" fill="#94a3b8" font-size="10" font-weight="500" font-style="italic">Divisive</text>', ml + 8, mt + 16),
    sprintf('<text x="%d" y="%d" fill="#94a3b8" font-size="10" font-weight="500" font-style="italic" text-anchor="end">Polarising Leaders</text>', ml + cw - 8, mt + 16)
  )

  # Median lines (dashed)
  med_lines <- paste0(
    sprintf('<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#cbd5e1" stroke-width="1" stroke-dasharray="4,3"/>', qx, mt, qx, mt + ch),
    sprintf('<line x1="%d" y1="%g" x2="%d" y2="%g" stroke="#cbd5e1" stroke-width="1" stroke-dasharray="4,3"/>', ml, qy, ml + cw, qy)
  )

  # Axis grid
  x_ticks <- pretty(c(x_min, x_max), 5)
  x_ticks <- x_ticks[x_ticks >= x_min & x_ticks <= x_max]
  y_ticks <- pretty(c(y_min, y_max), 5)
  y_ticks <- y_ticks[y_ticks >= y_min & y_ticks <= y_max]

  grid_svg <- paste(c(
    vapply(x_ticks, function(xt) {
      x <- scale_x(xt)
      paste0(
        sprintf('<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#f1f5f9" stroke-width="1"/>', x, mt, x, mt + ch),
        sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="10">%.2f</text>', x, mt + ch + 16, xt)
      )
    }, character(1)),
    vapply(y_ticks, function(yt) {
      y <- scale_y(yt)
      paste0(
        sprintf('<line x1="%d" y1="%g" x2="%d" y2="%g" stroke="#f1f5f9" stroke-width="1"/>', ml, y, ml + cw, y),
        sprintf('<text x="%d" y="%g" text-anchor="end" fill="#94a3b8" font-size="10">%.2f</text>', ml - 8, y + 4, yt)
      )
    }, character(1))
  ), collapse = "\n")

  # Axis labels
  axis_labels <- paste0(
    sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#64748b" font-size="12" font-weight="500">Mean Utility</text>', ml + cw / 2, mt + ch + 40),
    sprintf('<text x="%d" y="%g" text-anchor="middle" fill="#64748b" font-size="12" font-weight="500" transform="rotate(-90, %d, %g)">Standard Deviation</text>', ml - 50, mt + ch / 2, ml - 50, mt + ch / 2)
  )

  # Dots + labels
  dots <- paste(vapply(seq_len(n), function(i) {
    x <- scale_x(means[i])
    y <- scale_y(sds[i])
    label <- labels[i]
    if (nchar(label) > 18) label <- paste0(substr(label, 1, 15), "...")
    paste0(
      sprintf('<circle cx="%g" cy="%g" r="6" fill="%s" opacity="0.7" stroke="white" stroke-width="1.5"/>', x, y, brand_colour),
      sprintf('<text x="%g" y="%g" fill="#1e293b" font-size="10" font-weight="400">%s</text>', x + 10, y + 4, label)
    )
  }, character(1)), collapse = "\n")

  # Border
  border <- sprintf('<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="#e2e8f0" stroke-width="1"/>',
                    ml, mt, cw, ch)

  svg_wrap(paste(quadrants, grid_svg, med_lines, q_labels, border, axis_labels, dots, sep = "\n"),
           chart_width, chart_height, "Item Strategy Quadrant: Mean Utility vs Standard Deviation")
}


# ==============================================================================
# COLOUR PALETTE
# ==============================================================================

# ==============================================================================
# UTILITY DISTRIBUTION VIOLIN / RAINCLOUD CHART
# ==============================================================================

#' Build violin/raincloud chart showing HB utility distributions per item
#'
#' Shows the distribution of individual-level utilities for each item,
#' revealing polarization patterns. Items with wide distributions or
#' multiple peaks are polarizing; tight distributions indicate consensus.
#'
#' @param dist_data List with $summary (data.frame) and $densities (list of density estimates)
#' @param brand_colour Hex colour
#'
#' @return SVG string
#' @keywords internal
build_utility_distribution_chart <- function(dist_data, brand_colour = "#1e3a5f") {

  if (is.null(dist_data) || is.null(dist_data$summary) || nrow(dist_data$summary) < 2) return("")

  df <- dist_data$summary
  densities <- dist_data$densities

  n <- nrow(df)
  row_height <- 44
  gap <- 4
  ml <- 180   # left margin for labels
  mr <- 40
  mt <- 30
  mb <- 40
  chart_width <- 720
  cw <- chart_width - ml - mr
  ch <- n * (row_height + gap) - gap
  total_height <- mt + ch + mb

  # X scale: covers all utility values
  x_min <- min(df$Min, na.rm = TRUE) - abs(diff(range(c(df$Min, df$Max)))) * 0.05
  x_max <- max(df$Max, na.rm = TRUE) + abs(diff(range(c(df$Min, df$Max)))) * 0.05
  if (x_max - x_min < 0.01) { x_min <- x_min - 1; x_max <- x_max + 1 }

  scale_x <- function(v) ml + (v - x_min) / (x_max - x_min) * cw

  # Grid lines
  x_ticks <- pretty(c(x_min, x_max), 6)
  x_ticks <- x_ticks[x_ticks >= x_min & x_ticks <= x_max]

  grid_lines <- paste(vapply(x_ticks, function(xt) {
    x <- scale_x(xt)
    paste0(
      sprintf('<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#e2e8f0" stroke-width="1"/>', x, mt, x, mt + ch),
      sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="10">%.2f</text>', x, mt + ch + 16, xt)
    )
  }, character(1)), collapse = "\n")

  axis_label <- sprintf(
    '<text x="%g" y="%d" text-anchor="middle" fill="#64748b" font-size="12" font-weight="500">Utility Score</text>',
    ml + cw / 2, mt + ch + 34
  )

  # Zero line if range spans zero
  zero_line <- ""
  if (x_min < 0 && x_max > 0) {
    zx <- scale_x(0)
    zero_line <- sprintf(
      '<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#cbd5e1" stroke-width="1.5" stroke-dasharray="4,3"/>',
      zx, mt, zx, mt + ch
    )
  }

  # Rows: for each item, draw density violin + box plot
  rows_svg <- paste(vapply(seq_len(n), function(i) {
    y_center <- mt + (i - 1) * (row_height + gap) + row_height / 2
    item_id <- df$Item_ID[i]
    label <- df$Item_Label[i]
    if (nchar(label) > 25) label <- paste0(substr(label, 1, 22), "...")

    # Label
    label_svg <- sprintf(
      '<text x="%d" y="%g" text-anchor="end" fill="#1e293b" font-size="11" font-weight="500" dominant-baseline="middle">%s</text>',
      ml - 8, y_center, htmlEscape(label)
    )

    # Density violin (half — raincloud style: density on top only)
    violin_svg <- ""
    d <- densities[[item_id]]
    if (!is.null(d) && length(d$x) > 2) {
      max_density <- max(d$y)
      if (max_density > 0) {
        half_h <- row_height * 0.38  # max height of the density curve
        # Build path: bottom line then density curve on top
        pts_top <- paste(vapply(seq_along(d$x), function(k) {
          px <- scale_x(d$x[k])
          py <- y_center - (d$y[k] / max_density) * half_h
          sprintf("%g,%g", px, py)
        }, character(1)), collapse = " ")
        # Close path along the center line
        x_start <- scale_x(d$x[1])
        x_end <- scale_x(d$x[length(d$x)])
        violin_svg <- sprintf(
          '<polygon points="%g,%g %s %g,%g" fill="%s" opacity="0.25" stroke="%s" stroke-width="0.8" stroke-opacity="0.5"/>',
          x_start, y_center, pts_top, x_end, y_center, brand_colour, brand_colour
        )
      }
    }

    # Box plot (below center line)
    q25_x <- scale_x(df$Q25[i])
    q75_x <- scale_x(df$Q75[i])
    median_x <- scale_x(df$Median[i])
    mean_x <- scale_x(df$Mean[i])
    min_x <- scale_x(df$Min[i])
    max_x <- scale_x(df$Max[i])
    box_h <- 6
    box_y <- y_center + 2

    box_svg <- paste0(
      # Whiskers
      sprintf('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="#94a3b8" stroke-width="1"/>', min_x, box_y + box_h/2, q25_x, box_y + box_h/2),
      sprintf('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="#94a3b8" stroke-width="1"/>', q75_x, box_y + box_h/2, max_x, box_y + box_h/2),
      # Whisker caps
      sprintf('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="#94a3b8" stroke-width="1"/>', min_x, box_y + 1, min_x, box_y + box_h - 1),
      sprintf('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="#94a3b8" stroke-width="1"/>', max_x, box_y + 1, max_x, box_y + box_h - 1),
      # Box (Q25 to Q75)
      sprintf('<rect x="%g" y="%g" width="%g" height="%d" rx="2" fill="%s" opacity="0.5" stroke="%s" stroke-width="1"/>',
              q25_x, box_y, q75_x - q25_x, box_h, brand_colour, brand_colour),
      # Median line
      sprintf('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="white" stroke-width="1.5"/>', median_x, box_y, median_x, box_y + box_h),
      # Mean dot
      sprintf('<circle cx="%g" cy="%g" r="3" fill="white" stroke="%s" stroke-width="1.5"/>', mean_x, box_y + box_h/2, brand_colour)
    )

    paste0(label_svg, "\n", violin_svg, "\n", box_svg)
  }, character(1)), collapse = "\n")

  svg_wrap(paste(grid_lines, zero_line, axis_label, rows_svg, sep = "\n"),
           chart_width, total_height,
           "Utility distribution chart showing individual-level preference spread per item")
}


# ==============================================================================
# COLOUR PALETTE
# ==============================================================================

generate_md_palette <- function(n, brand_colour = "#1e3a5f") {
  base <- c(brand_colour, "#2aa198", "#f39c12", "#e74c3c", "#9b59b6",
            "#3498db", "#1abc9c", "#e67e22")
  if (n <= length(base)) return(base[seq_len(n)])
  rep_len(base, n)
}
