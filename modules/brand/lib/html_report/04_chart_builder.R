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

#' Lighten a hex colour toward white
#'
#' Used to derive a rival-tier colour from the focal brand colour: the rival
#' tier (top-N closest competitors in the constellation) sits midway between
#' the saturated focal colour and the recessive comparator grey, so all three
#' tiers are visually distinct without introducing a competing accent hue.
#'
#' @param hex Character. Hex colour, e.g. \code{"#1A5276"}. \code{NA} or empty
#'   returns \code{"#94a3b8"} as a safe fallback.
#' @param amount Numeric in \eqn{[0, 1]}. Mix weight toward white.
#' @return Character. Lightened hex colour.
#' @keywords internal
.lighten_hex <- function(hex, amount = 0.45) {
  if (is.null(hex) || is.na(hex) || !nzchar(hex)) return("#94a3b8")
  hex <- gsub("^#", "", hex)
  if (nchar(hex) == 3L) hex <- paste0(strsplit(hex, "")[[1]],
                                        strsplit(hex, "")[[1]],
                                        collapse = "")
  if (nchar(hex) != 6L) return("#94a3b8")
  r <- strtoi(substr(hex, 1, 2), 16L)
  g <- strtoi(substr(hex, 3, 4), 16L)
  b <- strtoi(substr(hex, 5, 6), 16L)
  if (anyNA(c(r, g, b))) return("#94a3b8")
  amount <- max(0, min(1, amount))
  r <- as.integer(round(r + (255 - r) * amount))
  g <- as.integer(round(g + (255 - g) * amount))
  b <- as.integer(round(b + (255 - b) * amount))
  sprintf("#%02X%02X%02X", r, g, b)
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
# Label placement (collision-aware)
# ==============================================================================

#' Place scatter-plot labels around their bubbles, avoiding collisions
#'
#' Mirrors the ggrepel approach for pure-SVG charts: for each point, picks the
#' best of eight candidate positions (E / NE / N / NW / W / SW / S / SE) at a
#' radial offset from the bubble, scoring each by overlap with other bubbles,
#' already-placed labels, and the chart edges. Falls back to wider offsets
#' (1.5x, 2x) if every direction is taken at the default distance.
#'
#' Categories with similar metrics genuinely sit at the same coordinates
#' (e.g. on the IPK Wave 1 clutter chart, Salad Dressings, Stock Powder and
#' Cook-in Sauces all sit around 7.4 brands known / 13% focal share). The
#' bubbles are deliberately precise — only the labels move, never the points.
#'
#' @param points List of named lists, each with: \code{svgx}, \code{svgy},
#'   \code{r} (bubble radius), \code{label} (display text), \code{is_focal}
#'   (logical). Order does not matter — placement order is determined by
#'   focal-first then label length.
#' @param plot_left,plot_right,plot_top,plot_bot Numeric. Plot-area edges
#'   in SVG pixels.
#' @param font_size Numeric. Label font size in px. Default 10.
#' @param pad Numeric. Gap between bubble edge and label box. Default 4.
#' @return List the same length as \code{points}, each element a list with
#'   \code{cx} / \code{cy} (label anchor coords), \code{anchor}
#'   (\code{"start"} / \code{"middle"} / \code{"end"}), and \code{leader}
#'   (logical — TRUE when the label is far enough from the bubble that a
#'   thin leader line should be drawn).
#' @keywords internal
.place_scatter_labels <- function(points, plot_left, plot_right,
                                   plot_top, plot_bot,
                                   font_size = 10, pad = 4) {
  n <- length(points)
  if (n == 0L) return(list())

  # Approximate label box dimensions for an Inter-stack font at this size.
  char_w <- font_size * 0.55
  text_h <- font_size * 1.15

  candidates <- list(
    list(name = "E",  dx =  1.0, dy =  0.0, anchor = "start"),
    list(name = "NE", dx =  0.7, dy = -0.7, anchor = "start"),
    list(name = "SE", dx =  0.7, dy =  0.7, anchor = "start"),
    list(name = "W",  dx = -1.0, dy =  0.0, anchor = "end"),
    list(name = "NW", dx = -0.7, dy = -0.7, anchor = "end"),
    list(name = "SW", dx = -0.7, dy =  0.7, anchor = "end"),
    list(name = "N",  dx =  0.0, dy = -1.0, anchor = "middle"),
    list(name = "S",  dx =  0.0, dy =  1.0, anchor = "middle")
  )

  bbox_for <- function(pt, cand, mult) {
    label_w <- char_w * nchar(pt$label)
    cx <- pt$svgx + cand$dx * (pt$r + pad) * mult
    cy <- pt$svgy + cand$dy * (pt$r + pad) * mult
    x0 <- if (cand$anchor == "start") cx
          else if (cand$anchor == "end") cx - label_w
          else cx - label_w / 2
    y0 <- cy - text_h * 0.7
    list(x0 = x0, y0 = y0, x1 = x0 + label_w, y1 = y0 + text_h,
         cx = cx, cy = cy, anchor = cand$anchor, mult = mult)
  }

  score_box <- function(bb, self_idx, placed) {
    s <- 0
    if (bb$x0 < plot_left)  s <- s + (plot_left - bb$x0) * 3
    if (bb$x1 > plot_right) s <- s + (bb$x1 - plot_right) * 3
    if (bb$y0 < plot_top)   s <- s + (plot_top - bb$y0) * 3
    if (bb$y1 > plot_bot)   s <- s + (bb$y1 - plot_bot) * 3
    for (i in seq_len(n)) {
      if (i == self_idx) next
      p <- points[[i]]
      cx_clamp <- max(bb$x0, min(p$svgx, bb$x1))
      cy_clamp <- max(bb$y0, min(p$svgy, bb$y1))
      d <- sqrt((cx_clamp - p$svgx)^2 + (cy_clamp - p$svgy)^2)
      if (d < p$r + pad) s <- s + (p$r + pad - d) * 8
    }
    for (lb in placed) {
      if (is.null(lb)) next
      ow <- max(0, min(bb$x1, lb$x1) - max(bb$x0, lb$x0))
      oh <- max(0, min(bb$y1, lb$y1) - max(bb$y0, lb$y0))
      s <- s + ow * oh * 0.15
    }
    s
  }

  # Process focal first, then longest labels first (hardest to fit).
  focal_first <- which(vapply(points, function(p) isTRUE(p$is_focal), logical(1)))
  rest <- setdiff(seq_len(n), focal_first)
  rest <- rest[order(vapply(points[rest], function(p) nchar(p$label), integer(1)),
                      decreasing = TRUE)]
  proc_order <- c(focal_first, rest)

  placed <- vector("list", n)
  for (idx in proc_order) {
    pt <- points[[idx]]
    best <- NULL
    best_score <- Inf
    for (mult in c(1.0, 1.5, 2.0)) {
      for (cand in candidates) {
        bb <- bbox_for(pt, cand, mult)
        sc <- score_box(bb, idx, placed)
        if (sc < best_score) {
          best_score <- sc
          best <- bb
        }
      }
      if (best_score < 1) break
    }
    placed[[idx]] <- best
  }

  # Convert internal bbox to public list shape; flag leader lines for
  # any label drawn beyond the bubble's natural east neighbourhood.
  lapply(seq_len(n), function(i) {
    bb <- placed[[i]]
    pt <- points[[i]]
    natural <- bb$mult <= 1.0 && abs(bb$cx - pt$svgx) <= pt$r * 1.6 &&
               abs(bb$cy - pt$svgy) <= pt$r * 1.6
    list(cx = bb$cx, cy = bb$cy, anchor = bb$anchor, leader = !natural)
  })
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
                          size_col = NULL,
                          diag_ref_line = FALSE) {

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

  # Diagonal reference line y = x (strength map only)
  if (isTRUE(diag_ref_line)) {
    d_lo <- max(x_min, y_min)
    d_hi <- min(x_max, y_max)
    if (d_hi > d_lo) {
      parts <- c(parts, sprintf(
        '<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="#cbd5e1" stroke-width="1.5" stroke-dasharray="6,4"/>',
        sx(d_lo), sy(d_lo), sx(d_hi), sy(d_hi)
      ))
    }
  }

  # Two-pass label placement: first compute every bubble, then run
  # collision-aware label placement so categories that share coordinates
  # (e.g. on the IPK clutter chart) don't end up with stacked labels.
  bubble_specs <- list()
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
    bubble_specs[[length(bubble_specs) + 1L]] <- list(
      svgx = sx(xv), svgy = sy(yv), r = r, label = lbl,
      is_focal = is_focal, col = col
    )
  }

  placements <- .place_scatter_labels(
    points     = bubble_specs,
    plot_left  = ml,    plot_right = ml + pw,
    plot_top   = mt,    plot_bot   = mt + ph,
    font_size  = 10,    pad        = 4
  )

  for (i in seq_along(bubble_specs)) {
    pt <- bubble_specs[[i]]
    pl <- placements[[i]]
    fw <- if (pt$is_focal) "700" else "400"
    fc <- if (pt$is_focal) "#1e293b" else "#64748b"
    if (isTRUE(pl$leader)) {
      parts <- c(parts, sprintf(
        '<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="#cbd5e1" stroke-width="0.8" opacity="0.7"/>',
        pt$svgx, pt$svgy, pl$cx, pl$cy
      ))
    }
    parts <- c(parts,
      sprintf('<circle cx="%g" cy="%g" r="%g" fill="%s" opacity="0.8" stroke="#fff" stroke-width="1.5"/>',
              pt$svgx, pt$svgy, pt$r, pt$col),
      sprintf('<text x="%g" y="%g" text-anchor="%s" fill="%s" font-size="10" font-weight="%s">%s</text>',
              pl$cx, pl$cy, pl$anchor, fc, fw, .br_escape(pt$label))
    )
  }

  br_svg_wrap(paste(parts, collapse = "\n"), w, h, title)
}


# ==============================================================================
# 2b. BUBBLE SCATTER (portfolio strength map — §4.4)
# ==============================================================================

#' Build portfolio strength bubble scatter
#'
#' Thin wrapper over \code{build_scatter()} that enables variable-radius dots
#' and adds a diagonal y = x reference line. Used for the §4.4 strength map
#' where x = category penetration and y = brand awareness among buyers.
#'
#' @param df Data frame. Must contain x_col, y_col, label_col, size_col.
#' @param x_col Character. Column name for x-axis values.
#' @param y_col Character. Column name for y-axis values.
#' @param label_col Character. Column name for dot labels.
#' @param size_col Character or NULL. Column for variable radius.
#' @param brand_colour Character. Hex colour for dots.
#' @param title Character. Chart title.
#' @param x_label Character. X-axis label.
#' @param y_label Character. Y-axis label.
#'
#' @return Character. Inline SVG string.
#' @keywords internal
build_bubble_scatter <- function(df, x_col, y_col, label_col,
                                 size_col = NULL,
                                 brand_colour = "#1A5276",
                                 title = "",
                                 x_label = "Category Penetration (%)",
                                 y_label = "Brand Awareness among Buyers (%)") {
  build_scatter(
    df           = df,
    x_col        = x_col,
    y_col        = y_col,
    label_col    = label_col,
    focal_label  = NULL,
    brand_colour = brand_colour,
    comp_colour  = brand_colour,
    title        = title,
    x_label      = x_label,
    y_label      = y_label,
    x_suffix     = "%",
    y_suffix     = "%",
    size_col     = size_col,
    diag_ref_line = TRUE
  )
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
      is_absent <- is.na(val)
      if (is_absent) {
        bg      <- "#f1f5f9"
        txt_col <- "#94a3b8"
        cell_label <- "\u2014"
      } else {
        intensity  <- min(1, val / max_val)
        bg         <- sprintf("rgba(26,82,118,%.2f)", 0.08 + intensity * 0.45)
        txt_col    <- if (intensity > 0.6) "#fff" else "#334155"
        cell_label <- .br_fmt(val, 1)
      }

      parts <- c(parts,
        sprintf('<rect x="%g" y="%g" width="%d" height="%d" fill="%s" stroke="#fff" stroke-width="1"/>', x, y, cell_w, cell_h, bg),
        sprintf('<text x="%g" y="%g" text-anchor="middle" fill="%s" font-size="10" dominant-baseline="middle">%s</text>',
                x + cell_w / 2, y + cell_h / 2, txt_col, cell_label))
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
# 9. STACKED LOYALTY PROFILE (per-brand sole / dual / multi)
# ==============================================================================

#' Build a stacked horizontal bar showing buyer loyalty profile per brand
#'
#' Each bar represents one brand. Segments show the % of that brand's buyers
#' who are sole-loyal (Sole), dual-brand shoppers (Dual), or multi-brand
#' shoppers (Multi). A dot at the right shows mean repertoire size.
#'
#' @param brand_repertoire_profile Data frame with BrandCode, Sole_Pct,
#'   Dual_Pct, Multi_Pct, Mean_Repertoire, Brand_Buyers_n.
#' @param focal_brand Character. Focal brand code (row highlighted).
#' @param focal_colour Hex colour for sole-loyal segment.
#' @param title Character.
#'
#' @return SVG string.
#' @keywords internal
build_loyalty_profile_chart <- function(brand_repertoire_profile,
                                         focal_brand    = NULL,
                                         focal_colour   = "#1A5276",
                                         title          = "Buyer Loyalty Profile") {

  df <- brand_repertoire_profile
  if (is.null(df) || nrow(df) == 0) return("")

  # Colours: Sole = focal (most committed), Dual = medium, Multi = muted
  col_sole  <- focal_colour
  col_dual  <- "#60a5fa"   # sky-blue
  col_multi <- "#cbd5e1"   # slate-200

  n     <- nrow(df)
  row_h <- 28; gap <- 6
  ml    <- 80; mr <- 90; mt <- 50; mb <- 30
  cw    <- 720 - ml - mr
  total_h <- mt + n * (row_h + gap) + mb

  parts <- character(0)

  # Title
  parts <- c(parts, sprintf(
    '<text x="%d" y="22" fill="#1e293b" font-size="14" font-weight="700">%s</text>',
    ml, .br_escape(title)))

  # Legend (top-right)
  leg_x <- ml + cw - 10
  parts <- c(parts,
    sprintf('<rect x="%g" y="32" width="10" height="10" rx="2" fill="%s"/>',
            leg_x - 200, col_sole),
    sprintf('<text x="%g" y="41" fill="#64748b" font-size="10">Sole</text>',
            leg_x - 187),
    sprintf('<rect x="%g" y="32" width="10" height="10" rx="2" fill="%s"/>',
            leg_x - 150, col_dual),
    sprintf('<text x="%g" y="41" fill="#64748b" font-size="10">Dual</text>',
            leg_x - 137),
    sprintf('<rect x="%g" y="32" width="10" height="10" rx="2" fill="%s"/>',
            leg_x - 100, col_multi),
    sprintf('<text x="%g" y="41" fill="#64748b" font-size="10">Multi (3+)</text>',
            leg_x - 87),
    sprintf('<text x="%g" y="41" fill="#94a3b8" font-size="10">\u2022 Mean brands</text>',
            leg_x - 28))

  for (i in seq_len(n)) {
    bc        <- df$BrandCode[i]
    sole_pct  <- df$Sole_Pct[i]  %||% 0
    dual_pct  <- df$Dual_Pct[i]  %||% 0
    multi_pct <- df$Multi_Pct[i] %||% 0
    mean_rep  <- df$Mean_Repertoire[i] %||% NA_real_
    n_bb      <- df$Brand_Buyers_n[i]  %||% 0

    y         <- mt + (i - 1) * (row_h + gap)
    is_focal  <- !is.null(focal_brand) && bc == focal_brand
    lbl_fw    <- if (is_focal) "700" else "400"
    lbl_col   <- if (is_focal) "#1e293b" else "#64748b"

    # Label
    parts <- c(parts, sprintf(
      '<text x="%g" y="%g" text-anchor="end" fill="%s" font-size="12" font-weight="%s" dominant-baseline="middle">%s</text>',
      ml - 6, y + row_h / 2, lbl_col, lbl_fw, .br_escape(bc)))

    # Stacked bar segments
    x_cursor <- ml
    segs <- list(
      list(pct = sole_pct,  col = col_sole),
      list(pct = dual_pct,  col = col_dual),
      list(pct = multi_pct, col = col_multi)
    )
    for (seg in segs) {
      w <- max(0, (seg$pct / 100) * cw)
      if (w > 0) {
        parts <- c(parts, sprintf(
          '<rect x="%g" y="%g" width="%g" height="%d" fill="%s" opacity="0.85"/>',
          x_cursor, y, w, row_h, seg$col))
      }
      x_cursor <- x_cursor + w
    }

    # Background track (unaccounted % due to rounding)
    if (x_cursor < ml + cw) {
      parts <- c(parts, sprintf(
        '<rect x="%g" y="%g" width="%g" height="%d" fill="#f1f5f9"/>',
        x_cursor, y, (ml + cw) - x_cursor, row_h))
    }

    # Mean repertoire dot + label
    if (!is.na(mean_rep) && mean_rep > 0) {
      max_rep <- max(df$Mean_Repertoire, na.rm = TRUE)
      max_rep <- max(max_rep, 1)
      dot_x   <- ml + cw + 8 + ((mean_rep - 1) / max(max_rep - 1, 0.1)) * 50
      parts <- c(parts,
        sprintf('<circle cx="%g" cy="%g" r="5" fill="%s" opacity="0.8"/>',
                dot_x, y + row_h / 2, lbl_col),
        sprintf('<text x="%g" y="%g" fill="%s" font-size="10" dominant-baseline="middle">%.1f</text>',
                dot_x + 8, y + row_h / 2, lbl_col, mean_rep))
    }
  }

  # Axis: 0 / 50% / 100% marks
  for (tick in c(0, 50, 100)) {
    tx <- ml + (tick / 100) * cw
    parts <- c(parts,
      sprintf('<line x1="%g" y1="%d" x2="%g" y2="%g" stroke="#e2e8f0" stroke-width="1"/>',
              tx, mt, tx, mt + n * (row_h + gap)),
      sprintf('<text x="%g" y="%d" text-anchor="middle" fill="#94a3b8" font-size="10">%d%%</text>',
              tx, mt - 5, tick))
  }

  br_svg_wrap(paste(parts, collapse = "\n"), 720, total_h, title)
}


# ==============================================================================
# 10. NETWORK / CONSTELLATION CHART (§4.2)
# ==============================================================================

#' Build competitive constellation network SVG
#'
#' Renders pre-computed node positions and edges as an inline SVG. Nodes are
#' coloured in three visual tiers so the focal-vs-rivals-vs-rest read is
#' immediately legible:
#'   * Focal brand: \code{focal_colour}, dashed halo, larger radius.
#'   * Top-N closest competitors (by Jaccard with focal): \code{rival_colour}
#'     — a lightened shade of \code{focal_colour} by default, derived via
#'     \code{.lighten_hex()} so it stays brand-consistent.
#'   * All other brands: \code{comp_colour} — recessive grey.
#' Node sizes scale with total aware respondents. Edges incident on the
#' focal are highlighted in \code{focal_colour}; the rest stay grey.
#'
#' @param nodes Data frame: brand, n_aware_w, is_focal (and optional
#'   \code{brand_lbl} for display).
#' @param edges Data frame: b1, b2, jaccard, cooccur_n.
#' @param layout Data frame: brand, x, y (pre-computed positions).
#' @param focal_colour Character. Hex colour for focal brand node. Default
#'   \code{"#1A5276"}.
#' @param rival_colour Character or NULL. Hex colour for the top-N rival
#'   tier. \code{NULL} (default) derives a lightened shade of
#'   \code{focal_colour} via \code{.lighten_hex(focal_colour, 0.45)}.
#' @param comp_colour Character. Hex colour for non-rival competitor nodes.
#'   Default \code{"#94a3b8"}.
#' @param top_n_rivals Integer. Number of closest-by-Jaccard competitors
#'   to highlight as the rival tier. Default 5 (matches the side-panel
#'   "Closest Competitors" list count). Set to 0 to disable the tier.
#' @param title Character. Chart title.
#'
#' @return Character. Inline SVG string.
#' @keywords internal
build_network <- function(nodes, edges, layout,
                          focal_colour = "#1A5276",
                          rival_colour = NULL,
                          comp_colour  = "#94a3b8",
                          top_n_rivals = 5L,
                          title        = "Competitive Constellation",
                          brand_colours = NULL) {
  if (is.null(rival_colour) || !nzchar(rival_colour)) {
    rival_colour <- .lighten_hex(focal_colour, 0.45)
  }
  if (is.null(nodes) || nrow(nodes) == 0 || is.null(layout)) return("")

  # Bigger canvas + larger top/side margins so brand labels at the
  # edges don't collide with the title or get truncated. Right-edge
  # labels are flipped to the left of their node further down so wide
  # labels like "Checkers House Brand" or "PnP No Name" fit.
  w <- 820L; h <- 580L
  pad_x   <- 90L
  pad_top <- 80L      # leaves room for title (y=22) + first label
  pad_bot <- 60L
  pw  <- w - 2L * pad_x
  ph  <- h - pad_top - pad_bot

  # Merge layout into nodes
  nodes <- merge(nodes, layout, by = "brand", all.x = TRUE)
  nodes <- nodes[!is.na(nodes$x), , drop = FALSE]
  if (nrow(nodes) == 0) return("")

  # Map layout coordinates to SVG
  x_range <- range(nodes$x, na.rm = TRUE)
  y_range <- range(nodes$y, na.rm = TRUE)
  sx <- function(v) pad_x + (v - x_range[1]) / max(diff(x_range), 1e-6) * pw
  sy <- function(v) pad_top + ph - (v - y_range[1]) / max(diff(y_range), 1e-6) * ph

  nodes$svgx <- sx(nodes$x)
  nodes$svgy <- sy(nodes$y)

  # Node radius: 8–22 px, scaled by n_aware_w
  max_aw <- max(nodes$n_aware_w, 1)
  nodes$r <- 8 + (nodes$n_aware_w / max_aw) * 14

  # Top-N closest competitors to the focal, by Jaccard. Used for the
  # rival visual tier (between focal and the recessive comparator grey)
  # so the user can see the focal's mental-space rivals at a glance,
  # not just from the side-panel ranking.
  focal_idx <- which(isTRUE(any(nodes$is_focal)) & nodes$is_focal == TRUE)
  focal_brand <- if (length(focal_idx) > 0L) {
    as.character(nodes$brand[focal_idx[1L]])
  } else ""
  rival_brands <- character(0)
  if (top_n_rivals > 0L && nzchar(focal_brand) &&
      !is.null(edges) && nrow(edges) > 0L) {
    inc <- edges[edges$b1 == focal_brand | edges$b2 == focal_brand, ,
                 drop = FALSE]
    if (nrow(inc) > 0L) {
      inc <- inc[order(inc$jaccard, decreasing = TRUE), , drop = FALSE]
      rivals <- ifelse(inc$b1 == focal_brand, inc$b2, inc$b1)
      rivals <- rivals[!duplicated(rivals)]
      rival_brands <- head(rivals, top_n_rivals)
    }
  }

  parts <- character(0)

  # Title
  parts <- c(parts, sprintf(
    '<text x="%d" y="28" fill="#1e293b" font-size="14" font-weight="700">%s</text>',
    pad_x, .br_escape(title)))

  # Edges (draw before nodes so nodes sit on top). Each line carries
  # data-pf-cn-b1 / data-pf-cn-b2 / data-pf-cn-jac so the JS-side focal
  # switcher can find and re-style the lines that touch the active focal
  # (paint them in the brand colour, scale thickness by Jaccard).
  if (!is.null(edges) && nrow(edges) > 0) {
    max_jac <- max(edges$jaccard, 1e-6)
    for (k in seq_len(nrow(edges))) {
      b1 <- edges$b1[k]; b2 <- edges$b2[k]
      n1 <- nodes[nodes$brand == b1, , drop = FALSE]
      n2 <- nodes[nodes$brand == b2, , drop = FALSE]
      if (nrow(n1) == 0 || nrow(n2) == 0) next
      jac     <- edges$jaccard[k]
      opacity <- 0.15 + (jac / max_jac) * 0.55
      lw      <- 1 + (jac / max_jac) * 3
      parts <- c(parts, sprintf(
        '<line class="pf-cn-edge" data-pf-cn-b1="%s" data-pf-cn-b2="%s" data-pf-cn-jac="%.4f" data-pf-cn-base-w="%.1f" x1="%g" y1="%g" x2="%g" y2="%g" stroke="#94a3b8" stroke-width="%.1f" opacity="%.2f"/>',
        .br_escape(b1), .br_escape(b2), jac, lw,
        n1$svgx, n1$svgy, n2$svgx, n2$svgy, lw, opacity
      ))
    }
  }

  # Nodes + labels. Prefer the display label (brand_lbl) when supplied
  # by the data layer; fall back to the brand code so the legacy pooled
  # constellation still renders.
  #
  # Each node, label and (when focal) halo carries a `data-pf-cn-*`
  # attribute keyed by brand code so the JS-side focal switcher can
  # re-style the chart in place when the user picks a different focal
  # from the dropdown — no full re-render required.
  has_lbl <- "brand_lbl" %in% names(nodes)
  for (i in seq_len(nrow(nodes))) {
    nd <- nodes[i, ]
    is_focal <- isTRUE(nd$is_focal)
    is_rival <- !is_focal && (nd$brand %in% rival_brands)
    # Per-brand colour from the portfolio-wide map when supplied — keeps
    # constellation node colours consistent with the rest of the brand
    # module (Cat Buying / DSS chips). Falls back to the legacy
    # focal/rival/comp single-colour scheme when no map is passed.
    brand_specific <- if (!is.null(brand_colours))
      brand_colours[[as.character(nd$brand)]] else NULL
    col      <- if (is_focal) focal_colour
                else if (is_rival && (is.null(brand_specific) || !nzchar(brand_specific))) rival_colour
                else if (!is.null(brand_specific) && nzchar(brand_specific)) brand_specific
                else comp_colour
    radius   <- if (is_focal) nd$r * 1.25 else nd$r
    label    <- if (has_lbl && nzchar(as.character(nd$brand_lbl)))
                  as.character(nd$brand_lbl) else as.character(nd$brand)
    bcode    <- .br_escape(nd$brand)
    if (is_focal) {
      parts <- c(parts, sprintf(
        '<circle class="pf-cn-halo" data-pf-cn-halo="%s" cx="%g" cy="%g" r="%g" fill="none" stroke="%s" stroke-width="2" stroke-dasharray="3 3" opacity="0.55"/>',
        bcode, nd$svgx, nd$svgy, radius + 6, focal_colour))
    }
    # Smart label placement: nodes in the right third of the chart get
    # their label drawn LEFT of the node (right-anchored) so wide labels
    # like "Checkers House Brand" don't run off the SVG edge. Top-edge
    # nodes get the label drawn BELOW so they don't collide with the title.
    on_right <- nd$svgx > (pad_x + pw * 0.65)
    on_top   <- nd$svgy < (pad_top + 20)
    if (on_right) {
      label_x <- nd$svgx - radius - 4
      anchor  <- "end"
    } else {
      label_x <- nd$svgx + radius + 4
      anchor  <- "start"
    }
    label_y <- if (on_top) nd$svgy + radius + 14 else nd$svgy - radius - 2

    # Hover tooltip is delivered by JS (instant, reliable) — the brand
    # display label rides on the circle as a data attribute so the
    # tooltip handler can read it without a DOM walk.
    node_cls <- if (is_focal) " pf-cn-node-focal"
                else if (is_rival) " pf-cn-node-rival"
                else ""
    label_cls <- if (is_focal) " pf-cn-label-focal"
                 else if (is_rival) " pf-cn-label-rival"
                 else ""
    label_fill <- if (is_focal) "#1e293b"
                  else if (is_rival) "#334155"
                  else "#64748b"
    label_size <- if (is_focal) "12"
                  else if (is_rival) "11"
                  else "10"
    label_wt   <- if (is_focal) "700"
                  else if (is_rival) "600"
                  else "400"

    parts <- c(parts,
      sprintf('<circle class="pf-cn-node%s" data-pf-cn-node="%s" data-pf-cn-base-r="%g" data-pf-cn-name="%s" cx="%g" cy="%g" r="%g" fill="%s" opacity="0.9" stroke="#fff" stroke-width="2" data-brand="%s" style="cursor:pointer;" onclick="pfConstellationNodeClick(event,\'%s\')"></circle>',
              node_cls,
              bcode, nd$r, .br_escape(label),
              nd$svgx, nd$svgy, radius, col,
              bcode, bcode),
      sprintf('<text class="pf-cn-label%s" data-pf-cn-label="%s" x="%g" y="%g" text-anchor="%s" fill="%s" font-size="%s" font-weight="%s">%s</text>',
              label_cls,
              bcode,
              label_x, label_y, anchor,
              label_fill, label_size, label_wt,
              .br_escape(.br_trunc(label, 24)))
    )
  }

  # Wrap the SVG and decorate with rival metadata so the JS-side focal
  # switcher uses the same lightened shade we computed here, and can
  # recompute the tier on focal change without re-running the layout.
  svg <- br_svg_wrap(paste(parts, collapse = "\n"), w, h, title)
  rivals_attr <- paste(rival_brands, collapse = ",")
  sub("^<svg ", sprintf(
    '<svg data-pf-cn-rival-colour="%s" data-pf-cn-rivals="%s" data-pf-cn-top-n="%d" ',
    .br_escape(rival_colour), .br_escape(rivals_attr),
    as.integer(top_n_rivals)
  ), svg)
}


# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
