# ==============================================================================
# BRAND MODULE - WOM PANEL CHARTS (SVG)
# ==============================================================================
# Two diverging-bar charts for the WOM panel:
#   1. build_wom_heard_chart() — Heard positive vs Heard negative per brand
#   2. build_wom_said_chart()  — Said positive vs Said negative, annotated
#      with mean number of occasions per sharer
#
# Design notes
# ------------
# Both charts use the same geometry. Brands are ordered with the focal row
# at the top, then all other brands sorted by net score (pos - neg) DESC.
# A dashed category-average reference marker sits beneath the last brand row
# on each side (neg and pos) to let readers gauge over/under-indexers at a
# glance. Colours mirror the heatmap palette used in the table:
#   positive = green (#059669 family)
#   negative = red   (#dc2626 family)
#
# VERSION: 1.0
# ==============================================================================


BRAND_WOM_CHART_VERSION <- "1.0"


#' Build the WOM Heard chart (diverging bar: received_pos vs received_neg).
#'
#' @param panel_data List from \code{build_wom_panel_data()}.
#' @param focal_colour Character. Hex colour for the focal bar accent.
#' @return Character HTML string (SVG wrapper).
#' @export
build_wom_heard_chart <- function(panel_data, focal_colour = "#1A5276") {
  .wom_chart(panel_data,
             pos_key = "received_pos", neg_key = "received_neg",
             net_key = "net_heard",
             pos_label = "Heard positive",
             neg_label = "Heard negative",
             title = "WOM: Heard (last period)",
             focal_colour = focal_colour,
             show_occasions = FALSE)
}


#' Build the WOM Said chart (diverging bar + occasions annotation).
#'
#' @param panel_data List from \code{build_wom_panel_data()}.
#' @param focal_colour Character. Hex colour for the focal bar accent.
#' @return Character HTML string (SVG wrapper).
#' @export
build_wom_said_chart <- function(panel_data, focal_colour = "#1A5276") {
  .wom_chart(panel_data,
             pos_key = "shared_pos", neg_key = "shared_neg",
             net_key = "net_said",
             pos_label = "Said positive",
             neg_label = "Said negative",
             title = "WOM: Said + occasions mentioned (per sharer)",
             focal_colour = focal_colour,
             show_occasions = TRUE,
             pos_occ_key = "pos_freq",
             neg_occ_key = "neg_freq")
}


# ==============================================================================
# INTERNAL: shared diverging-bar renderer
# ==============================================================================

.wom_chart <- function(panel_data,
                       pos_key, neg_key, net_key,
                       pos_label, neg_label,
                       title,
                       focal_colour = "#1A5276",
                       show_occasions = FALSE,
                       pos_occ_key = NULL, neg_occ_key = NULL) {
  if (is.null(panel_data) || length(panel_data$brands) == 0)
    return('<div class="wom-chart-placeholder">Chart unavailable.</div>')

  brands  <- panel_data$brands
  cat_avg <- panel_data$cat_avg

  # Sort: focal first, then by net score DESC
  is_foc <- vapply(brands, function(b) isTRUE(b$is_focal), logical(1))
  focal_idx <- which(is_foc)
  comp_idx  <- which(!is_foc)
  nets <- vapply(comp_idx,
    function(i) suppressWarnings(as.numeric(brands[[i]]$values[[net_key]])),
    numeric(1))
  nets[!is.finite(nets)] <- -Inf
  comp_idx <- comp_idx[order(-nets)]
  order_idx <- c(focal_idx, comp_idx)

  n <- length(order_idx)

  # Geometry
  W <- 760
  ml <- 170; mr <- if (show_occasions) 190 else 140
  mt <- 58;  mb <- 26
  bar_h <- 22; gap <- 8
  inner_w <- W - ml - mr
  half_w  <- inner_w / 2
  mid_x   <- ml + half_w
  total_h <- mt + n * (bar_h + gap) + mb

  # Axis scale = max of abs(value) across pos + neg columns
  all_pos <- vapply(brands, function(b) as.numeric(b$values[[pos_key]]) %||% NA_real_,
                    numeric(1))
  all_neg <- vapply(brands, function(b) as.numeric(b$values[[neg_key]]) %||% NA_real_,
                    numeric(1))
  max_v <- suppressWarnings(max(c(all_pos, all_neg), na.rm = TRUE))
  if (!is.finite(max_v) || max_v <= 0) max_v <- 1
  max_axis <- .wom_nice_ceiling(max_v)

  pos_colour  <- "#059669"
  neg_colour  <- "#dc2626"
  pos_colour_focal <- .wom_shade(pos_colour, -0.1)
  neg_colour_focal <- .wom_shade(neg_colour, -0.1)

  parts <- character(0)

  # Title
  parts <- c(parts, sprintf(
    '<text x="%d" y="22" fill="#0f172a" font-size="14" font-weight="700">%s</text>',
    ml, .wom_chart_esc(title)))

  # Axis legend above chart area
  parts <- c(parts,
    sprintf('<text x="%g" y="%d" text-anchor="end" fill="%s" font-size="11" font-weight="600">%s \u25C0</text>',
            mid_x - 8, mt - 10, neg_colour, .wom_chart_esc(neg_label)),
    sprintf('<text x="%g" y="%d" text-anchor="start" fill="%s" font-size="11" font-weight="600">\u25B6 %s</text>',
            mid_x + 8, mt - 10, pos_colour, .wom_chart_esc(pos_label)))

  # Grid: ticks at 0 / 25% / 50% / 75% / 100% of half-axis
  grid_top <- mt
  grid_bot <- mt + n * (bar_h + gap)
  tick_fracs <- c(0.25, 0.5, 0.75, 1)
  for (f in tick_fracs) {
    xl <- mid_x - half_w * f
    xr <- mid_x + half_w * f
    v_lbl <- sprintf("%.0f%%", max_axis * f)
    parts <- c(parts,
      sprintf('<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#e2e8f0" stroke-width="1" stroke-dasharray="2,3"/>',
              xl, grid_top, xl, grid_bot),
      sprintf('<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#e2e8f0" stroke-width="1" stroke-dasharray="2,3"/>',
              xr, grid_top, xr, grid_bot),
      sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="9">%s</text>',
              xl, grid_bot + 12, v_lbl),
      sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="9">%s</text>',
              xr, grid_bot + 12, v_lbl))
  }
  # Centre line (0%)
  parts <- c(parts, sprintf(
    '<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#475569" stroke-width="1"/>',
    mid_x, grid_top, mid_x, grid_bot))

  # Category-average reference markers (dashed notches)
  avg_pos <- cat_avg[[pos_key]]$mean %||% NA_real_
  avg_neg <- cat_avg[[neg_key]]$mean %||% NA_real_
  if (is.finite(avg_pos)) {
    xr <- mid_x + half_w * (avg_pos / max_axis)
    parts <- c(parts, sprintf(
      '<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="%s" stroke-width="1.5" stroke-dasharray="4,3" opacity="0.8"/>',
      xr, grid_top + 2, xr, grid_bot - 2, pos_colour),
      sprintf('<text x="%g" y="%d" text-anchor="middle" fill="%s" font-size="9" font-weight="600">cat avg %.0f%%</text>',
              xr, grid_top - 26, pos_colour, avg_pos))
  }
  if (is.finite(avg_neg)) {
    xl <- mid_x - half_w * (avg_neg / max_axis)
    parts <- c(parts, sprintf(
      '<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="%s" stroke-width="1.5" stroke-dasharray="4,3" opacity="0.8"/>',
      xl, grid_top + 2, xl, grid_bot - 2, neg_colour),
      sprintf('<text x="%g" y="%d" text-anchor="middle" fill="%s" font-size="9" font-weight="600">cat avg %.0f%%</text>',
              xl, grid_top - 26, neg_colour, avg_neg))
  }

  # Bars
  for (i in seq_along(order_idx)) {
    b <- brands[[order_idx[i]]]
    is_f <- isTRUE(b$is_focal)
    y <- mt + (i - 1) * (bar_h + gap)

    pos_v <- suppressWarnings(as.numeric(b$values[[pos_key]]))
    neg_v <- suppressWarnings(as.numeric(b$values[[neg_key]]))
    net_v <- suppressWarnings(as.numeric(b$values[[net_key]]))
    if (!is.finite(pos_v)) pos_v <- 0
    if (!is.finite(neg_v)) neg_v <- 0
    if (!is.finite(net_v)) net_v <- pos_v - neg_v

    pos_w <- (pos_v / max_axis) * half_w
    neg_w <- (neg_v / max_axis) * half_w

    label <- b$brand_name %||% b$brand_code
    lbl_weight <- if (is_f) "700" else "500"
    lbl_col    <- if (is_f) focal_colour else "#1e293b"
    pos_fill <- if (is_f) pos_colour_focal else pos_colour
    neg_fill <- if (is_f) neg_colour_focal else neg_colour
    pos_opacity <- if (is_f) "1" else "0.85"
    neg_opacity <- if (is_f) "1" else "0.85"

    # Focal-row band
    if (is_f) {
      parts <- c(parts, sprintf(
        '<rect x="%d" y="%g" width="%d" height="%d" fill="%s" opacity="0.07"/>',
        ml - 16, y - 3, inner_w + 24, bar_h + 6, focal_colour))
    }

    # Label (left gutter)
    parts <- c(parts, sprintf(
      '<text x="%d" y="%g" text-anchor="end" fill="%s" font-size="11" font-weight="%s" dominant-baseline="middle">%s%s</text>',
      ml - 10, y + bar_h / 2, lbl_col, lbl_weight,
      .wom_chart_esc(.wom_chart_trunc(label, 20)),
      if (is_f) " \u25C6" else ""))

    # Negative bar (grows leftwards from mid_x)
    if (neg_w > 0.4) {
      parts <- c(parts, sprintf(
        '<rect x="%g" y="%g" width="%g" height="%d" rx="2" fill="%s" opacity="%s"/>',
        mid_x - neg_w, y, neg_w, bar_h, neg_fill, neg_opacity))
      if (neg_w >= 22) {
        parts <- c(parts, sprintf(
          '<text x="%g" y="%g" text-anchor="middle" fill="#fff" font-size="10" font-weight="600" dominant-baseline="middle">%.0f%%</text>',
          mid_x - neg_w / 2, y + bar_h / 2, neg_v))
      } else {
        parts <- c(parts, sprintf(
          '<text x="%g" y="%g" text-anchor="end" fill="%s" font-size="10" font-weight="600" dominant-baseline="middle">%.0f%%</text>',
          mid_x - neg_w - 3, y + bar_h / 2, neg_colour, neg_v))
      }
    } else {
      parts <- c(parts, sprintf(
        '<text x="%g" y="%g" text-anchor="end" fill="#94a3b8" font-size="10" dominant-baseline="middle">%.0f%%</text>',
        mid_x - 3, y + bar_h / 2, neg_v))
    }

    # Positive bar (grows rightwards from mid_x)
    if (pos_w > 0.4) {
      parts <- c(parts, sprintf(
        '<rect x="%g" y="%g" width="%g" height="%d" rx="2" fill="%s" opacity="%s"/>',
        mid_x, y, pos_w, bar_h, pos_fill, pos_opacity))
      if (pos_w >= 22) {
        parts <- c(parts, sprintf(
          '<text x="%g" y="%g" text-anchor="middle" fill="#fff" font-size="10" font-weight="600" dominant-baseline="middle">%.0f%%</text>',
          mid_x + pos_w / 2, y + bar_h / 2, pos_v))
      } else {
        parts <- c(parts, sprintf(
          '<text x="%g" y="%g" text-anchor="start" fill="%s" font-size="10" font-weight="600" dominant-baseline="middle">%.0f%%</text>',
          mid_x + pos_w + 3, y + bar_h / 2, pos_colour, pos_v))
      }
    } else {
      parts <- c(parts, sprintf(
        '<text x="%g" y="%g" text-anchor="start" fill="#94a3b8" font-size="10" dominant-baseline="middle">%.0f%%</text>',
        mid_x + 3, y + bar_h / 2, pos_v))
    }

    # Right-gutter annotations
    net_col <- if (net_v >= 0) pos_colour else neg_colour
    right_x <- ml + inner_w + 8
    parts <- c(parts, sprintf(
      '<text x="%g" y="%g" fill="%s" font-size="11" font-weight="700" dominant-baseline="middle">Net %+.0fpp</text>',
      right_x, y + bar_h / 2, net_col, net_v))

    if (show_occasions) {
      pos_occ <- suppressWarnings(as.numeric(b$values[[pos_occ_key]]))
      neg_occ <- suppressWarnings(as.numeric(b$values[[neg_occ_key]]))
      occ_txt <- sprintf("\u00D7%.1f pos | \u00D7%.1f neg",
                         if (is.finite(pos_occ)) pos_occ else 0,
                         if (is.finite(neg_occ)) neg_occ else 0)
      parts <- c(parts, sprintf(
        '<text x="%g" y="%g" fill="#64748b" font-size="10" dominant-baseline="middle">%s</text>',
        right_x + 70, y + bar_h / 2, .wom_chart_esc(occ_txt)))
    }
  }

  svg_body <- paste(parts, collapse = "\n")
  sprintf(
    '<svg class="wom-chart-svg" viewBox="0 0 %d %g" width="100%%" preserveAspectRatio="xMinYMin meet" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="%s">%s</svg>',
    W, total_h, .wom_chart_esc(title), svg_body)
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

.wom_nice_ceiling <- function(x) {
  if (!is.finite(x) || x <= 0) return(10)
  step <- 10 ^ floor(log10(x))
  ceiling(x / step) * step
}


.wom_shade <- function(hex, frac) {
  if (!grepl("^#[0-9A-Fa-f]{6}$", hex)) return(hex)
  rgb_v <- strtoi(substring(hex, c(2, 4, 6), c(3, 5, 7)), 16L)
  rgb_v <- pmin(255, pmax(0, round(rgb_v + frac * 255)))
  sprintf("#%02X%02X%02X", rgb_v[1], rgb_v[2], rgb_v[3])
}


.wom_chart_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;",  x, fixed = TRUE)
  x <- gsub(">", "&gt;",  x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


.wom_chart_trunc <- function(s, n) {
  if (is.null(s)) return("")
  s <- as.character(s)
  if (nchar(s) <= n) s else paste0(substring(s, 1, n - 1), "\u2026")
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
