# ==============================================================================
# BRAND HTML REPORT - CHART BUILDER
# ==============================================================================
# Pure inline SVG charts for the brand report.
# Layer 3 of the 4-layer pipeline. No external dependencies.
#
# Chart types:
#   1. Cleveland dot plot (MMS league, conversion leak)
#   2. Scatter with reference lines (MPen x NS, I×P quadrant, DBA grid)
#   3. Heat strip (CEP × brand matrix)
#   4. Line chart with dots (TURF reach curves)
#   5. Horizontal stacked bar (funnel + attitude decomposition)
#   6. Horizontal bar (repertoire, overlap)
#   7. Diverging bar (WOM net balance)
#   8. Dumbbell chart (competitive advantage)
#   9. Bubble scatter (portfolio map)
# ==============================================================================

br_svg_font <- "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"

br_svg_wrap <- function(inner, width, height, aria_label) {
  sprintf(
    '<svg viewBox="0 0 %d %d" style="font-family:%s;width:100%%;max-width:%dpx;height:auto;display:block;margin:0 auto;" role="img" aria-label="%s">%s</svg>',
    width, height, br_svg_font, width, .br_escape(aria_label), inner
  )
}

.br_escape <- function(x) {
  if (is.null(x) || is.na(x)) return("")
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

.br_trunc <- function(x, max_len = 28) {
  if (is.null(x) || is.na(x)) return("")
  x <- as.character(x)
  if (nchar(x) > max_len) paste0(substr(x, 1, max_len - 3), "...") else x
}

.br_fmt <- function(x, digits = 1, pct = FALSE) {
  if (is.na(x)) return("\u2014")
  if (pct) sprintf("%.*f%%", digits, x) else sprintf("%.*f", digits, x)
}


# ==============================================================================
# 1. CLEVELAND DOT PLOT (horizontal)
# ==============================================================================

#' Build a Cleveland dot plot
#'
#' One horizontal axis, one dot per item. Focal item saturated,
#' others desaturated grey. Direct-labelled.
#'
#' @param df Data frame with Label, Value columns.
#' @param focal_label Character. Label to highlight.
#' @param brand_colour Hex colour for focal dot.
#' @param comp_colour Hex colour for competitors.
#' @param title Character. Chart title.
#' @param value_suffix Character. Suffix for values (e.g., "%").
#' @param ref_line Numeric. Reference line value (optional).
#' @param ref_label Character. Reference line label.
#'
#' @return SVG string.
#' @keywords internal
build_dot_plot <- function(df, focal_label = NULL,
                           brand_colour = "#1A5276",
                           comp_colour = "#B0B0B0",
                           title = "",
                           value_suffix = "%",
                           ref_line = NULL, ref_label = NULL) {
  if (is.null(df) || nrow(df) == 0) return("")

  df <- df[order(-df$Value), ]
  n <- nrow(df)
  row_h <- 32
  ml <- 180; mr <- 80; mt <- 40; mb <- 30
  cw <- 720 - ml - mr
  total_h <- mt + n * row_h + mb

  min_v <- 0
  max_v <- max(df$Value, na.rm = TRUE) * 1.15
  if (!is.null(ref_line)) max_v <- max(max_v, ref_line * 1.15)
  if (max_v <= 0) max_v <- 1
  scale_x <- function(v) ml + ((v - min_v) / (max_v - min_v)) * cw

  # Title
  title_svg <- sprintf(
    '<text x="%d" y="22" fill="#1e293b" font-size="14" font-weight="700">%s</text>',
    ml, .br_escape(title)
  )

  # Grid
  grid_vals <- pretty(c(min_v, max_v), 5)
  grid_vals <- grid_vals[grid_vals >= min_v & grid_vals <= max_v]
  grid_svg <- paste(vapply(grid_vals, function(gv) {
    x <- scale_x(gv)
    paste0(
      sprintf('<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#f0f0f0" stroke-width="1"/>',
              x, mt, x, mt + n * row_h),
      sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="10">%s%s</text>',
              x, mt + n * row_h + 16, .br_fmt(gv, 0), value_suffix)
    )
  }, character(1)), collapse = "\n")

  # Reference line
  ref_svg <- ""
  if (!is.null(ref_line)) {
    rx <- scale_x(ref_line)
    ref_svg <- paste0(
      sprintf('<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#94a3b8" stroke-width="1" stroke-dasharray="4,3"/>',
              rx, mt, rx, mt + n * row_h),
      sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="9" font-style="italic">%s</text>',
              rx, mt - 6, .br_escape(ref_label %||% ""))
    )
  }

  # Dots
  dots_svg <- paste(vapply(seq_len(n), function(i) {
    y <- mt + (i - 0.5) * row_h
    val <- df$Value[i]
    label <- .br_trunc(df$Label[i])
    is_focal <- !is.null(focal_label) && df$Label[i] == focal_label
    col <- if (is_focal) brand_colour else comp_colour
    r <- if (is_focal) 7 else 5
    fw <- if (is_focal) "700" else "400"
    fc <- if (is_focal) "#1e293b" else "#64748b"

    paste0(
      sprintf('<text x="%d" y="%g" text-anchor="end" fill="%s" font-size="12" font-weight="%s" dominant-baseline="middle">%s</text>',
              ml - 12, y, fc, fw, .br_escape(label)),
      sprintf('<circle cx="%g" cy="%g" r="%d" fill="%s"/>', scale_x(val), y, r, col),
      sprintf('<text x="%g" y="%g" fill="%s" font-size="11" font-weight="%s" dominant-baseline="middle">%s%s</text>',
              scale_x(val) + r + 6, y, fc, fw, .br_fmt(val, 1), value_suffix)
    )
  }, character(1)), collapse = "\n")

  br_svg_wrap(paste(title_svg, grid_svg, ref_svg, dots_svg, sep = "\n"),
              720, total_h, title)
}


# ==============================================================================
# 2. SCATTER PLOT (MPen×NS, I×P, DBA, Portfolio)
# ==============================================================================

build_scatter <- function(df, x_col, y_col, label_col,
                          focal_label = NULL,
                          brand_colour = "#1A5276",
                          comp_colour = "#B0B0B0",
                          title = "",
                          x_label = "", y_label = "",
                          x_suffix = "", y_suffix = "",
                          quadrant_labels = NULL,
                          ref_x = NULL, ref_y = NULL,
                          size_col = NULL) {

  if (is.null(df) || nrow(df) == 0) return("")

  w <- 720; h <- 520
  ml <- 70; mr <- 30; mt <- 45; mb <- 55
  pw <- w - ml - mr; ph <- h - mt - mb

  x_vals <- df[[x_col]]
  y_vals <- df[[y_col]]
  x_range <- range(x_vals, na.rm = TRUE)
  y_range <- range(y_vals, na.rm = TRUE)
  x_pad <- max(1, diff(x_range) * 0.12)
  y_pad <- max(0.1, diff(y_range) * 0.12)
  x_min <- x_range[1] - x_pad; x_max <- x_range[2] + x_pad
  y_min <- y_range[1] - y_pad; y_max <- y_range[2] + y_pad

  sx <- function(v) ml + ((v - x_min) / (x_max - x_min)) * pw
  sy <- function(v) mt + ph - ((v - y_min) / (y_max - y_min)) * ph

  parts <- character(0)

  # Title
  parts <- c(parts, sprintf(
    '<text x="%d" y="22" fill="#1e293b" font-size="14" font-weight="700">%s</text>',
    ml, .br_escape(title)))

  # Quadrant backgrounds
  if (!is.null(quadrant_labels) && !is.null(ref_x) && !is.null(ref_y)) {
    rx <- sx(ref_x); ry <- sy(ref_y)
    fills <- c("#f0fdf4", "#eff6ff", "#fefce8", "#fdf2f8")
    parts <- c(parts,
      sprintf('<rect x="%d" y="%d" width="%g" height="%g" fill="%s" opacity="0.5"/>', ml, mt, rx - ml, ry - mt, fills[1]),
      sprintf('<rect x="%g" y="%d" width="%g" height="%g" fill="%s" opacity="0.5"/>', rx, mt, ml + pw - rx, ry - mt, fills[2]),
      sprintf('<rect x="%d" y="%g" width="%g" height="%g" fill="%s" opacity="0.5"/>', ml, ry, rx - ml, mt + ph - ry, fills[3]),
      sprintf('<rect x="%g" y="%g" width="%g" height="%g" fill="%s" opacity="0.5"/>', rx, ry, ml + pw - rx, mt + ph - ry, fills[4])
    )
    ql <- quadrant_labels
    parts <- c(parts,
      sprintf('<text x="%g" y="%d" fill="#64748b" font-size="10" font-weight="600" text-anchor="start">%s</text>', ml + 6, mt + 14, .br_escape(ql[1])),
      sprintf('<text x="%g" y="%d" fill="#64748b" font-size="10" font-weight="600" text-anchor="end">%s</text>', ml + pw - 6, mt + 14, .br_escape(ql[2])),
      sprintf('<text x="%g" y="%g" fill="#64748b" font-size="10" font-weight="600" text-anchor="start">%s</text>', ml + 6, mt + ph - 6, .br_escape(ql[3])),
      sprintf('<text x="%g" y="%g" fill="#64748b" font-size="10" font-weight="600" text-anchor="end">%s</text>', ml + pw - 6, mt + ph - 6, .br_escape(ql[4]))
    )
  }

  # Reference lines
  if (!is.null(ref_x)) {
    rx <- sx(ref_x)
    parts <- c(parts, sprintf(
      '<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#94a3b8" stroke-width="1" stroke-dasharray="5,3"/>', rx, mt, rx, mt + ph))
  }
  if (!is.null(ref_y)) {
    ry <- sy(ref_y)
    parts <- c(parts, sprintf(
      '<line x1="%d" y1="%g" x2="%d" y2="%g" stroke="#94a3b8" stroke-width="1" stroke-dasharray="5,3"/>', ml, ry, ml + pw, ry))
  }

  # Axes
  x_ticks <- pretty(c(x_min, x_max), 5)
  y_ticks <- pretty(c(y_min, y_max), 5)
  for (tv in x_ticks[x_ticks >= x_min & x_ticks <= x_max]) {
    parts <- c(parts, sprintf(
      '<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="10">%s%s</text>',
      sx(tv), mt + ph + 16, .br_fmt(tv, 0), x_suffix))
  }
  for (tv in y_ticks[y_ticks >= y_min & y_ticks <= y_max]) {
    parts <- c(parts, sprintf(
      '<text x="%d" y="%g" text-anchor="end" fill="#94a3b8" font-size="10" dominant-baseline="middle">%s%s</text>',
      ml - 8, sy(tv), .br_fmt(tv, 1), y_suffix))
  }

  # Axis labels
  parts <- c(parts, sprintf(
    '<text x="%g" y="%d" text-anchor="middle" fill="#64748b" font-size="11" font-weight="500">%s</text>',
    ml + pw / 2, h - 6, .br_escape(x_label)))
  parts <- c(parts, sprintf(
    '<text x="14" y="%g" text-anchor="middle" fill="#64748b" font-size="11" font-weight="500" transform="rotate(-90,14,%g)">%s</text>',
    mt + ph / 2, mt + ph / 2, .br_escape(y_label)))

  # Plot border
  parts <- c(parts, sprintf(
    '<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="#e2e8f0" stroke-width="1"/>', ml, mt, pw, ph))

  # Dots
  for (i in seq_len(nrow(df))) {
    xv <- x_vals[i]; yv <- y_vals[i]
    if (is.na(xv) || is.na(yv)) next
    lbl <- .br_trunc(df[[label_col]][i], 20)
    is_focal <- !is.null(focal_label) && df[[label_col]][i] == focal_label
    col <- if (is_focal) brand_colour else comp_colour
    r <- if (!is.null(size_col) && size_col %in% names(df)) {
      sv <- df[[size_col]][i]
      max(5, min(18, 5 + (sv / max(df[[size_col]], na.rm = TRUE)) * 13))
    } else if (is_focal) 8 else 6
    fw <- if (is_focal) "700" else "400"
    fc <- if (is_focal) "#1e293b" else "#64748b"

    parts <- c(parts,
      sprintf('<circle cx="%g" cy="%g" r="%g" fill="%s" opacity="0.8" stroke="#fff" stroke-width="1.5"/>', sx(xv), sy(yv), r, col),
      sprintf('<text x="%g" y="%g" fill="%s" font-size="10" font-weight="%s">%s</text>',
              sx(xv) + r + 4, sy(yv) - r - 2, fc, fw, .br_escape(lbl))
    )
  }

  br_svg_wrap(paste(parts, collapse = "\n"), w, h, title)
}


# ==============================================================================
# 3. HEAT STRIP (CEP × brand matrix)
# ==============================================================================

build_heat_strip <- function(matrix_df, focal_brand = NULL,
                              brand_colour = "#1A5276",
                              title = "CEP × Brand Linkage (%)") {

  if (is.null(matrix_df) || nrow(matrix_df) == 0) return("")

  cep_col <- names(matrix_df)[1]
  brand_cols <- setdiff(names(matrix_df), cep_col)
  n_ceps <- nrow(matrix_df)
  n_brands <- length(brand_cols)

  cell_w <- 65; cell_h <- 30
  label_w <- 200; header_h <- 80
  ml <- label_w + 10; mt <- 45 + header_h
  w <- ml + n_brands * cell_w + 20
  h <- mt + n_ceps * cell_h + 20

  parts <- character(0)
  parts <- c(parts, sprintf(
    '<text x="10" y="22" fill="#1e293b" font-size="14" font-weight="700">%s</text>', .br_escape(title)))

  # Brand headers (rotated)
  for (j in seq_along(brand_cols)) {
    bx <- ml + (j - 0.5) * cell_w
    is_focal <- !is.null(focal_brand) && brand_cols[j] == focal_brand
    fc <- if (is_focal) brand_colour else "#64748b"
    fw <- if (is_focal) "700" else "500"
    parts <- c(parts, sprintf(
      '<text x="%g" y="%d" fill="%s" font-size="10" font-weight="%s" text-anchor="start" transform="rotate(-45,%g,%d)">%s</text>',
      bx, mt - 8, fc, fw, bx, mt - 8, .br_escape(.br_trunc(brand_cols[j], 12))))
  }

  # Cells
  all_vals <- unlist(matrix_df[, brand_cols])
  max_val <- max(all_vals, na.rm = TRUE)
  if (max_val <= 0) max_val <- 1

  for (i in seq_len(n_ceps)) {
    y <- mt + (i - 1) * cell_h
    cep_label <- .br_trunc(matrix_df[[cep_col]][i], 30)
    parts <- c(parts, sprintf(
      '<text x="%d" y="%g" text-anchor="end" fill="#334155" font-size="11" dominant-baseline="middle">%s</text>',
      ml - 12, y + cell_h / 2, .br_escape(cep_label)))

    for (j in seq_along(brand_cols)) {
      x <- ml + (j - 1) * cell_w
      val <- matrix_df[[brand_cols[j]]][i]
      if (is.na(val)) val <- 0
      intensity <- min(1, val / max_val)
      bg <- sprintf("rgba(26,82,118,%.2f)", 0.08 + intensity * 0.45)
      txt_col <- if (intensity > 0.6) "#fff" else "#334155"

      parts <- c(parts,
        sprintf('<rect x="%g" y="%g" width="%d" height="%d" fill="%s" stroke="#fff" stroke-width="1"/>', x, y, cell_w, cell_h, bg),
        sprintf('<text x="%g" y="%g" text-anchor="middle" fill="%s" font-size="10" dominant-baseline="middle">%s</text>',
                x + cell_w / 2, y + cell_h / 2, txt_col, .br_fmt(val, 1)))
    }
  }

  br_svg_wrap(paste(parts, collapse = "\n"), w, h, title)
}


# ==============================================================================
# 4. LINE CHART WITH DOTS (TURF reach curve)
# ==============================================================================

build_reach_curve <- function(reach_df, brand_colour = "#1A5276",
                               title = "TURF Reach Curve") {

  if (is.null(reach_df) || nrow(reach_df) == 0) return("")

  w <- 720; h <- 380
  ml <- 60; mr <- 40; mt <- 45; mb <- 50
  pw <- w - ml - mr; ph <- h - mt - mb

  x_vals <- reach_df$Portfolio_Size
  y_vals <- reach_df$Reach_Pct

  x_max <- max(x_vals)
  y_max <- min(100, max(y_vals) * 1.1)
  sx <- function(v) ml + (v / x_max) * pw
  sy <- function(v) mt + ph - (v / y_max) * ph

  parts <- character(0)
  parts <- c(parts, sprintf(
    '<text x="%d" y="22" fill="#1e293b" font-size="14" font-weight="700">%s</text>', ml, .br_escape(title)))

  # Grid
  y_ticks <- seq(0, 100, by = 20)
  y_ticks <- y_ticks[y_ticks <= y_max]
  for (tv in y_ticks) {
    parts <- c(parts,
      sprintf('<line x1="%d" y1="%g" x2="%d" y2="%g" stroke="#f0f0f0" stroke-width="1"/>', ml, sy(tv), ml + pw, sy(tv)),
      sprintf('<text x="%d" y="%g" text-anchor="end" fill="#94a3b8" font-size="10" dominant-baseline="middle">%s%%</text>', ml - 8, sy(tv), .br_fmt(tv, 0)))
  }
  for (tv in seq_len(x_max)) {
    parts <- c(parts, sprintf(
      '<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="10">%d</text>', sx(tv), mt + ph + 20, tv))
  }
  parts <- c(parts, sprintf(
    '<text x="%g" y="%d" text-anchor="middle" fill="#64748b" font-size="11">Items in portfolio</text>',
    ml + pw / 2, h - 8))

  # Line
  points <- paste(vapply(seq_len(nrow(reach_df)), function(i) {
    sprintf("%g,%g", sx(x_vals[i]), sy(y_vals[i]))
  }, character(1)), collapse = " ")
  parts <- c(parts, sprintf(
    '<polyline points="%s" fill="none" stroke="%s" stroke-width="2.5"/>', points, brand_colour))

  # Dots + labels
  for (i in seq_len(nrow(reach_df))) {
    if (x_vals[i] == 0) next
    parts <- c(parts,
      sprintf('<circle cx="%g" cy="%g" r="5" fill="%s" stroke="#fff" stroke-width="2"/>', sx(x_vals[i]), sy(y_vals[i]), brand_colour),
      sprintf('<text x="%g" y="%g" text-anchor="middle" fill="#334155" font-size="10" font-weight="500">%s%%</text>',
              sx(x_vals[i]), sy(y_vals[i]) - 10, .br_fmt(y_vals[i], 1)))
  }

  # Plot border
  parts <- c(parts, sprintf(
    '<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="#e2e8f0"/>', ml, mt, pw, ph))

  br_svg_wrap(paste(parts, collapse = "\n"), w, h, title)
}


# ==============================================================================
# 5. FUNNEL STACKED BAR (horizontal, attitude decomposition)
# ==============================================================================

build_funnel_chart <- function(funnel_df, focal_brand = NULL,
                                brand_colour = "#1A5276",
                                comp_colour = "#B0B0B0",
                                title = "Brand Funnel") {

  if (is.null(funnel_df) || nrow(funnel_df) == 0) return("")

  n <- nrow(funnel_df)
  bar_h <- 24; gap <- 14
  ml <- 120; mr <- 30; mt <- 50; mb <- 40
  cw <- 720 - ml - mr
  total_h <- mt + n * (bar_h * 2 + gap) + mb + 40

  # Attitude colours: Love(dark blue) Prefer(mid blue) Ambivalent(light blue) Reject(muted red) NoOpinion(light grey)
  att_cols <- c("#1A5276", "#2E86C1", "#85C1E9", "#C0392B", "#D5D8DC")
  att_labels <- c("Love", "Prefer", "Ambivalent", "Reject", "No Opinion")

  parts <- character(0)
  parts <- c(parts, sprintf(
    '<text x="%d" y="22" fill="#1e293b" font-size="14" font-weight="700">%s</text>', ml, .br_escape(title)))

  # Legend
  lx <- ml
  for (k in seq_along(att_labels)) {
    parts <- c(parts,
      sprintf('<rect x="%g" y="32" width="10" height="10" rx="2" fill="%s"/>', lx, att_cols[k]),
      sprintf('<text x="%g" y="41" fill="#64748b" font-size="9">%s</text>', lx + 14, att_labels[k]))
    lx <- lx + nchar(att_labels[k]) * 6 + 28
  }

  for (i in seq_len(n)) {
    brand <- funnel_df$BrandCode[i]
    is_focal <- !is.null(focal_brand) && brand == focal_brand
    y_base <- mt + (i - 1) * (bar_h * 2 + gap)
    fw <- if (is_focal) "700" else "400"
    fc <- if (is_focal) "#1e293b" else "#64748b"

    parts <- c(parts, sprintf(
      '<text x="%d" y="%g" text-anchor="end" fill="%s" font-size="12" font-weight="%s" dominant-baseline="middle">%s</text>',
      ml - 10, y_base + bar_h / 2, fc, fw, .br_escape(.br_trunc(brand, 14))))

    # Aware bar (full width = aware %)
    aware <- funnel_df$Aware_Pct[i]
    aware_w <- max(1, aware / 100 * cw)
    parts <- c(parts, sprintf(
      '<rect x="%d" y="%g" width="%g" height="%d" rx="3" fill="#e2e8f0"/>', ml, y_base, aware_w, bar_h))

    # Attitude decomposition within aware bar
    att_pcts <- c(funnel_df$Love_Pct[i], funnel_df$Prefer_Pct[i],
                  funnel_df$Ambivalent_Pct[i], funnel_df$Reject_Pct[i],
                  funnel_df$NoOpinion_Pct[i])
    att_total <- sum(att_pcts, na.rm = TRUE)
    if (att_total > 0) {
      ax <- ml
      for (k in seq_along(att_pcts)) {
        seg_w <- (att_pcts[k] / 100) * cw
        if (seg_w > 1) {
          parts <- c(parts, sprintf(
            '<rect x="%g" y="%g" width="%g" height="%d" fill="%s"/>', ax, y_base, seg_w, bar_h, att_cols[k]))
          if (seg_w > 25) {
            parts <- c(parts, sprintf(
              '<text x="%g" y="%g" text-anchor="middle" fill="#fff" font-size="9" dominant-baseline="middle">%s%%</text>',
              ax + seg_w / 2, y_base + bar_h / 2, .br_fmt(att_pcts[k], 0)))
          }
        }
        ax <- ax + seg_w
      }
    }

    # Aware label
    parts <- c(parts, sprintf(
      '<text x="%g" y="%g" fill="#334155" font-size="10" dominant-baseline="middle">%s%%</text>',
      ml + aware_w + 6, y_base + bar_h / 2, .br_fmt(aware, 0)))

    # Bought bar (second row)
    y2 <- y_base + bar_h + 2
    bought <- funnel_df$Bought_Pct[i]
    bought_w <- max(1, bought / 100 * cw)
    bar_col <- if (is_focal) brand_colour else comp_colour
    parts <- c(parts,
      sprintf('<rect x="%d" y="%g" width="%g" height="%d" rx="3" fill="%s" opacity="0.7"/>', ml, y2, bought_w, bar_h - 4, bar_col),
      sprintf('<text x="%g" y="%g" fill="#334155" font-size="10" dominant-baseline="middle">Bought: %s%%</text>',
              ml + bought_w + 6, y2 + (bar_h - 4) / 2, .br_fmt(bought, 0)))
  }

  br_svg_wrap(paste(parts, collapse = "\n"), 720, total_h, title)
}


# ==============================================================================
# 6. HORIZONTAL BAR (repertoire, overlap)
# ==============================================================================

build_h_bar <- function(df, label_col, value_col,
                        brand_colour = "#1A5276",
                        title = "", value_suffix = "%") {

  if (is.null(df) || nrow(df) == 0) return("")

  df <- df[order(-df[[value_col]]), ]
  n <- nrow(df)
  bar_h <- 28; gap <- 6
  ml <- 180; mr <- 70; mt <- 40; mb <- 20
  cw <- 720 - ml - mr
  total_h <- mt + n * (bar_h + gap) + mb

  max_v <- max(df[[value_col]], na.rm = TRUE)
  if (max_v <= 0) max_v <- 1

  parts <- character(0)
  parts <- c(parts, sprintf(
    '<text x="%d" y="22" fill="#1e293b" font-size="14" font-weight="700">%s</text>', ml, .br_escape(title)))

  for (i in seq_len(n)) {
    y <- mt + (i - 1) * (bar_h + gap)
    val <- df[[value_col]][i]
    label <- .br_trunc(df[[label_col]][i])
    w <- max(2, (val / max_v) * cw)

    parts <- c(parts,
      sprintf('<text x="%d" y="%g" text-anchor="end" fill="#64748b" font-size="12" dominant-baseline="middle">%s</text>',
              ml - 10, y + bar_h / 2, .br_escape(label)),
      sprintf('<rect x="%d" y="%g" width="%g" height="%d" rx="4" fill="%s" opacity="0.8"/>', ml, y, w, bar_h, brand_colour),
      sprintf('<text x="%g" y="%g" fill="#334155" font-size="11" font-weight="500" dominant-baseline="middle">%s%s</text>',
              ml + w + 6, y + bar_h / 2, .br_fmt(val, 1), value_suffix))
  }

  br_svg_wrap(paste(parts, collapse = "\n"), 720, total_h, title)
}


# ==============================================================================
# 7. DIVERGING BAR (WOM net balance)
# ==============================================================================

build_diverging_bar <- function(df, label_col = "BrandCode",
                                 pos_col = "ReceivedPos_Pct",
                                 neg_col = "ReceivedNeg_Pct",
                                 focal_label = NULL,
                                 brand_colour = "#1A5276",
                                 title = "WOM Net Balance") {

  if (is.null(df) || nrow(df) == 0) return("")

  n <- nrow(df)
  bar_h <- 26; gap <- 10
  ml <- 120; mr <- 120; mt <- 50; mb <- 30
  mid_x <- 720 / 2
  half_w <- (720 - ml - mr) / 2

  max_v <- max(c(df[[pos_col]], df[[neg_col]]), na.rm = TRUE)
  if (max_v <= 0) max_v <- 1
  total_h <- mt + n * (bar_h + gap) + mb

  parts <- character(0)
  parts <- c(parts, sprintf(
    '<text x="%g" y="22" fill="#1e293b" font-size="14" font-weight="700">%s</text>', mid_x, .br_escape(title)))

  # Center line
  parts <- c(parts, sprintf(
    '<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#94a3b8" stroke-width="1"/>', mid_x, mt, mid_x, mt + n * (bar_h + gap)))
  parts <- c(parts,
    sprintf('<text x="%g" y="%d" text-anchor="end" fill="#C0392B" font-size="10" font-weight="600">Negative</text>', mid_x - 10, mt - 8),
    sprintf('<text x="%g" y="%d" text-anchor="start" fill="#27AE60" font-size="10" font-weight="600">Positive</text>', mid_x + 10, mt - 8))

  for (i in seq_len(n)) {
    y <- mt + (i - 1) * (bar_h + gap)
    label <- .br_trunc(df[[label_col]][i], 14)
    pos_v <- df[[pos_col]][i]
    neg_v <- df[[neg_col]][i]
    is_focal <- !is.null(focal_label) && df[[label_col]][i] == focal_label
    fw <- if (is_focal) "700" else "400"
    fc <- if (is_focal) "#1e293b" else "#64748b"

    neg_w <- max(0, (neg_v / max_v) * half_w)
    pos_w <- max(0, (pos_v / max_v) * half_w)
    net <- pos_v - neg_v

    parts <- c(parts,
      sprintf('<text x="%d" y="%g" text-anchor="end" fill="%s" font-size="11" font-weight="%s" dominant-baseline="middle">%s</text>',
              ml - 8, y + bar_h / 2, fc, fw, .br_escape(label)),
      sprintf('<rect x="%g" y="%g" width="%g" height="%d" rx="3" fill="#E74C3C" opacity="0.6"/>', mid_x - neg_w, y, neg_w, bar_h),
      sprintf('<rect x="%g" y="%g" width="%g" height="%d" rx="3" fill="#27AE60" opacity="0.7"/>', mid_x, y, pos_w, bar_h))

    # Net label
    net_col <- if (net >= 0) "#27AE60" else "#E74C3C"
    parts <- c(parts, sprintf(
      '<text x="%g" y="%g" fill="%s" font-size="10" font-weight="600" dominant-baseline="middle">Net: %+.0fpp</text>',
      720 - mr + 8, y + bar_h / 2, net_col, net))
  }

  br_svg_wrap(paste(parts, collapse = "\n"), 720, total_h, title)
}


# ==============================================================================
# 8. DUMBBELL CHART (competitive advantage)
# ==============================================================================

build_dumbbell <- function(df, focal_brand = NULL,
                           brand_colour = "#1A5276",
                           comp_colour = "#B0B0B0",
                           title = "Competitive Advantage") {

  if (is.null(df) || nrow(df) == 0) return("")

  df <- df[order(-abs(df$Gap_pp)), ]
  n <- min(nrow(df), 12)
  df <- df[seq_len(n), ]

  row_h <- 34
  ml <- 200; mr <- 80; mt <- 45; mb <- 30
  cw <- 720 - ml - mr
  total_h <- mt + n * row_h + mb

  all_v <- c(df$Focal_Pct, df$Leader_Pct)
  min_v <- max(0, min(all_v, na.rm = TRUE) - 5)
  max_v <- min(100, max(all_v, na.rm = TRUE) + 5)
  sx <- function(v) ml + ((v - min_v) / (max_v - min_v)) * cw

  parts <- character(0)
  parts <- c(parts, sprintf(
    '<text x="%d" y="22" fill="#1e293b" font-size="14" font-weight="700">%s</text>', ml, .br_escape(title)))

  # Grid
  for (tv in pretty(c(min_v, max_v), 5)) {
    if (tv < min_v || tv > max_v) next
    parts <- c(parts,
      sprintf('<line x1="%g" y1="%d" x2="%g" y2="%d" stroke="#f0f0f0" stroke-width="1"/>', sx(tv), mt, sx(tv), mt + n * row_h),
      sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="10">%s%%</text>', sx(tv), mt + n * row_h + 16, .br_fmt(tv, 0)))
  }

  for (i in seq_len(n)) {
    y <- mt + (i - 0.5) * row_h
    label <- .br_trunc(df$Label[i] %||% df$Code[i], 28)
    fv <- df$Focal_Pct[i]
    lv <- df$Leader_Pct[i]
    gap_v <- df$Gap_pp[i]

    # Connector line
    parts <- c(parts, sprintf(
      '<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="#e2e8f0" stroke-width="2"/>', sx(min(fv, lv)), y, sx(max(fv, lv)), y))

    # Dots
    parts <- c(parts,
      sprintf('<circle cx="%g" cy="%g" r="6" fill="%s"/>', sx(fv), y, brand_colour),
      sprintf('<circle cx="%g" cy="%g" r="5" fill="%s"/>', sx(lv), y, comp_colour))

    # Label
    parts <- c(parts, sprintf(
      '<text x="%d" y="%g" text-anchor="end" fill="#64748b" font-size="11" dominant-baseline="middle">%s</text>',
      ml - 10, y, .br_escape(label)))

    # Gap label
    gap_col <- if (gap_v >= 0) "#27AE60" else "#E74C3C"
    parts <- c(parts, sprintf(
      '<text x="%g" y="%g" fill="%s" font-size="10" font-weight="600" dominant-baseline="middle">%+.0fpp</text>',
      720 - mr + 10, y, gap_col, gap_v))
  }

  # Legend
  ly <- mt - 10
  parts <- c(parts,
    sprintf('<circle cx="%g" cy="%g" r="5" fill="%s"/>', 720 - mr - 100, ly, brand_colour),
    sprintf('<text x="%g" y="%g" fill="#64748b" font-size="9" dominant-baseline="middle">%s</text>', 720 - mr - 90, ly, .br_escape(focal_brand %||% "Focal")),
    sprintf('<circle cx="%g" cy="%g" r="4" fill="%s"/>', 720 - mr - 40, ly, comp_colour),
    sprintf('<text x="%g" y="%g" fill="#64748b" font-size="9" dominant-baseline="middle">Leader</text>', 720 - mr - 30, ly))

  br_svg_wrap(paste(parts, collapse = "\n"), 720, total_h, title)
}


# ==============================================================================
# CONVENIENCE: null coalescing
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
