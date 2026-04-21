# ==============================================================================
# BRAND MODULE - CATEGORY BUYING PANEL CHARTS
# ==============================================================================
# SVG chart builders for the Category Buying (Dirichlet) panel:
#   1. Double Jeopardy scatter + Dirichlet-expected curve
#   2. Buyer heaviness stacked bars
#   3. Buy-rate profile horizontal bars
#   4. DoP deviation heatmap
#
# SIZE-EXCEPTION: SVG rendering pipeline — each builder is a sequential series
# of coordinate computations and string concatenations; decomposing further
# would require passing many intermediate coordinate lists, harming readability.
#
# VERSION: 1.0
# ==============================================================================

BRAND_CB_CHART_VERSION <- "1.0"

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a)) b else a


#' HTML-escape helper
#' @keywords internal
.cb_esc <- function(x) {
  if (is.null(x) || is.na(x)) return("")
  x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}


#' Resolve display label for a brand code
#'
#' Returns the BrandLabel from the lookup (if present), otherwise converts
#' the code to title case as a readable fallback.
#'
#' @param code Character. Brand code (e.g. "IPK").
#' @param brand_labels Named character vector or NULL.
#'   Names are BrandCode; values are display labels.
#'
#' @return Character. Display label.
#' @keywords internal
.cb_brand_lbl <- function(code, brand_labels = NULL) {
  if (!is.null(brand_labels) && !is.na(brand_labels[code]) &&
      nzchar(brand_labels[code])) {
    return(as.character(brand_labels[code]))
  }
  tools::toTitleCase(tolower(as.character(code)))
}


# ==============================================================================
# 1. DOUBLE JEOPARDY SCATTER
# ==============================================================================

#' Render the Double Jeopardy scatter as an SVG string
#'
#' @param norms_table Data frame. From \code{run_dirichlet_norms()$norms_table}.
#' @param dj_curve List. From \code{run_dirichlet_norms()$dj_curve}.
#' @param focal_brand Character or NULL.
#' @param focal_colour Character. Hex colour.
#' @param y_axis Character. \code{"scr"} or \code{"w"} (buy rate).
#' @param brand_labels Named character vector or NULL. Names = BrandCode, values = display labels.
#'
#' @return Character. SVG string.
#' @keywords internal
cb_dj_scatter_svg <- function(norms_table, dj_curve,
                               focal_brand  = NULL,
                               focal_colour = "#1A5276",
                               y_axis       = "scr",
                               brand_labels = NULL) {
  if (is.null(norms_table) || nrow(norms_table) == 0) return("")

  W <- 480; H <- 320
  pad <- list(l = 56, r = 20, t = 20, b = 50)
  cw <- W - pad$l - pad$r
  ch <- H - pad$t - pad$b

  # Data
  x_obs <- norms_table$Penetration_Obs_Pct
  y_obs <- if (y_axis == "scr") norms_table$SCR_Obs_Pct else norms_table$BuyRate_Obs
  y_lab <- if (y_axis == "scr") "SCR (%)" else "Buy rate"
  brands <- norms_table$BrandCode

  x_range <- range(c(x_obs, dj_curve$x_grid * 100), na.rm = TRUE)
  y_curve <- if (y_axis == "scr") dj_curve$y_fit_scr else dj_curve$y_fit_w
  y_range <- range(c(y_obs, y_curve), na.rm = TRUE)
  expand  <- 0.1
  x_range <- x_range + c(-1, 1) * diff(x_range) * expand
  y_range <- y_range + c(-1, 1) * diff(y_range) * expand

  to_px_x <- function(v) pad$l + (v - x_range[1]) / diff(x_range) * cw
  to_px_y <- function(v) pad$t + ch - (v - y_range[1]) / diff(y_range) * ch

  lines <- character(0)
  lines <- c(lines, sprintf(
    '<svg class="cb-dj-svg" viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">',
    W, H))

  # Grid lines (x)
  for (gx in pretty(x_range, n = 5)) {
    px <- to_px_x(gx)
    if (px < pad$l || px > W - pad$r) next
    lines <- c(lines, sprintf(
      '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#f1f5f9" stroke-width="1"/>',
      px, pad$t, px, pad$t + ch))
    lines <- c(lines, sprintf(
      '<text x="%.1f" y="%d" font-size="9" fill="#94a3b8" text-anchor="middle">%.0f%%</text>',
      px, pad$t + ch + 14, gx))
  }
  for (gy in pretty(y_range, n = 5)) {
    py <- to_px_y(gy)
    if (py < pad$t || py > pad$t + ch) next
    lines <- c(lines, sprintf(
      '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#f1f5f9" stroke-width="1"/>',
      pad$l, py, pad$l + cw, py))
    lines <- c(lines, sprintf(
      '<text x="%d" y="%.1f" font-size="9" fill="#94a3b8" text-anchor="end" dominant-baseline="middle">%.1f</text>',
      pad$l - 4, py, gy))
  }

  # Dirichlet curve
  curve_pts <- if (!all(is.na(y_curve)) && length(dj_curve$x_grid) > 1) {
    valid <- !is.na(y_curve)
    xs <- to_px_x(dj_curve$x_grid[valid] * 100)
    ys <- to_px_y(y_curve[valid])
    paste(sprintf("%.1f,%.1f", xs, ys), collapse = " ")
  } else NULL

  if (!is.null(curve_pts)) {
    lines <- c(lines, sprintf(
      '<polyline points="%s" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="4,3"/>',
      curve_pts))
  }

  # Points
  for (bi in seq_along(brands)) {
    xp <- to_px_x(x_obs[bi])
    yp <- to_px_y(y_obs[bi])
    is_focal <- !is.null(focal_brand) && brands[bi] == focal_brand
    col  <- if (is_focal) focal_colour else "#94a3b8"
    r    <- if (is_focal) 6 else 4
    flag <- norms_table$DJ_Flag[bi]
    show_label <- is_focal || (!is.na(flag) && flag != "on_line")
    lbl  <- .cb_brand_lbl(brands[bi], brand_labels)

    lines <- c(lines, sprintf(
      '<g data-brand="%s">', .cb_esc(brands[bi])))
    lines <- c(lines, sprintf(
      '<circle class="cb-brand-dot" cx="%.1f" cy="%.1f" r="%d" fill="%s" stroke="#fff" stroke-width="1.5">',
      xp, yp, r, col))
    lines <- c(lines, sprintf(
      '<title>%s\nPen: %.1f%%\n%s: %.1f</title>',
      .cb_esc(lbl), x_obs[bi], y_lab, y_obs[bi]))
    lines <- c(lines, "</circle>")

    if (show_label) {
      lines <- c(lines, sprintf(
        '<text class="cb-brand-label" x="%.1f" y="%.1f" font-size="9" fill="%s" font-weight="%s">%s</text>',
        xp + r + 2, yp + 3, col,
        if (is_focal) "700" else "400",
        .cb_esc(lbl)))
    }
    lines <- c(lines, '</g>')
  }

  # Axis labels
  lines <- c(lines, sprintf(
    '<text x="%.1f" y="%d" font-size="10" fill="#475569" text-anchor="middle">Penetration (%%)</text>',
    pad$l + cw / 2, H - 4))
  lines <- c(lines, sprintf(
    '<text x="%d" y="%.1f" font-size="10" fill="#475569" text-anchor="middle" transform="rotate(-90 %d %.1f)">%s</text>',
    14, pad$t + ch / 2, 14, pad$t + ch / 2, y_lab))

  lines <- c(lines, "</svg>")
  paste(lines, collapse = "\n")
}


# ==============================================================================
# 2. BUYER HEAVINESS STACKED BARS
# ==============================================================================

#' Render buyer heaviness stacked bar chart as SVG
#'
#' @param brand_heaviness Data frame. From \code{run_buyer_heaviness()$brand_heaviness}.
#' @param category_buyer_mix Data frame. From \code{run_buyer_heaviness()$category_buyer_mix}.
#' @param focal_brand Character or NULL.
#' @param focal_colour Character. Hex.
#' @param brand_labels Named character vector or NULL. Names = BrandCode, values = display labels.
#'
#' @return Character. SVG string.
#' @keywords internal
cb_heaviness_bars_svg <- function(brand_heaviness, category_buyer_mix,
                                   focal_brand  = NULL,
                                   focal_colour = "#1A5276",
                                   brand_labels = NULL) {
  if (is.null(brand_heaviness) || nrow(brand_heaviness) == 0) return("")

  brands <- brand_heaviness$BrandCode
  n      <- nrow(brand_heaviness)
  bar_h  <- 22
  gap    <- 6
  W      <- 300
  pad_l  <- 60; pad_r <- 10; pad_t <- 20; pad_b <- 30
  total_h <- pad_t + n * (bar_h + gap) + pad_b
  bw     <- W - pad_l - pad_r

  # Category reference lines
  cat_light  <- if (!is.null(category_buyer_mix))
    category_buyer_mix$Pct[category_buyer_mix$Tier == "Light"] / 100 else 1/3
  cat_medium <- if (!is.null(category_buyer_mix))
    category_buyer_mix$Pct[category_buyer_mix$Tier == "Medium"] / 100 else 1/3

  cols <- c(Light = "#bfdbfe", Medium = "#60a5fa", Heavy = "#1A5276")

  lines <- character(0)
  lines <- c(lines, sprintf(
    '<svg viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">',
    W, total_h))

  for (bi in seq_along(brands)) {
    y0 <- pad_t + (bi - 1) * (bar_h + gap)
    is_focal <- !is.null(focal_brand) && brands[bi] == focal_brand
    lbl <- .cb_brand_lbl(brands[bi], brand_labels)

    light_p  <- brand_heaviness$Light_Pct[bi] / 100
    medium_p <- brand_heaviness$Medium_Pct[bi] / 100
    heavy_p  <- brand_heaviness$Heavy_Pct[bi] / 100

    lines <- c(lines, sprintf('<g data-brand="%s">', .cb_esc(brands[bi])))

    # Brand label
    lines <- c(lines, sprintf(
      '<text class="cb-brand-label" x="%d" y="%.1f" font-size="10" fill="%s" font-weight="%s" text-anchor="end">%s</text>',
      pad_l - 4, y0 + bar_h / 2 + 4,
      if (is_focal) focal_colour else "#475569",
      if (is_focal) "700" else "400",
      .cb_esc(lbl)))

    # Stacked segments
    segs <- list(
      list(pct = light_p,  col = cols[["Light"]],  lbl = "L"),
      list(pct = medium_p, col = cols[["Medium"]], lbl = "M"),
      list(pct = heavy_p,  col = cols[["Heavy"]],  lbl = "H")
    )
    x_cur <- pad_l
    for (seg in segs) {
      seg_w <- seg$pct * bw
      if (seg_w < 1) { x_cur <- x_cur + seg_w; next }
      lines <- c(lines, sprintf(
        '<rect class="cb-brand-bar" x="%.1f" y="%d" width="%.1f" height="%d" fill="%s"/>',
        x_cur, y0, seg_w, bar_h, seg$col))
      if (seg_w > 22) {
        lines <- c(lines, sprintf(
          '<text x="%.1f" y="%.1f" font-size="9" fill="#1e293b" text-anchor="middle">%s</text>',
          x_cur + seg_w / 2, y0 + bar_h / 2 + 4, seg$lbl))
      }
      x_cur <- x_cur + seg_w
    }

    lines <- c(lines, '</g>')
  }

  # Reference dotted lines at category Light and Light+Medium boundaries
  ref_x1 <- pad_l + cat_light * bw
  ref_x2 <- pad_l + (cat_light + cat_medium) * bw
  for (rx in c(ref_x1, ref_x2)) {
    lines <- c(lines, sprintf(
      '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#94a3b8" stroke-width="1" stroke-dasharray="3,2"/>',
      rx, pad_t, rx, pad_t + n * (bar_h + gap)))
  }

  lines <- c(lines, "</svg>")
  paste(lines, collapse = "\n")
}


# ==============================================================================
# 3. BUY-RATE PROFILE (§4 output 6)
# ==============================================================================

#' Render horizontal buy-rate bar chart as SVG
#'
#' @param brand_heaviness Data frame. Contains \code{WBar_Brand} and
#'   \code{WBar_Category}.
#' @param focal_brand Character or NULL.
#' @param focal_colour Character.
#' @param brand_labels Named character vector or NULL. Names = BrandCode, values = display labels.
#'
#' @return Character. SVG string.
#' @keywords internal
cb_buyrate_bars_svg <- function(brand_heaviness,
                                 focal_brand  = NULL,
                                 focal_colour = "#1A5276",
                                 brand_labels = NULL) {
  if (is.null(brand_heaviness) || nrow(brand_heaviness) == 0) return("")

  brands    <- brand_heaviness$BrandCode
  w_vals    <- brand_heaviness$WBar_Brand
  cat_w     <- brand_heaviness$WBar_Category[1]
  n         <- nrow(brand_heaviness)
  bar_h     <- 20
  gap       <- 6
  W         <- 280; pad_l <- 60; pad_r <- 20; pad_t <- 20; pad_b <- 30
  total_h   <- pad_t + n * (bar_h + gap) + pad_b
  max_w     <- max(c(w_vals, cat_w), na.rm = TRUE) * 1.1

  to_px <- function(v) pad_l + (v / max_w) * (W - pad_l - pad_r)

  lines <- character(0)
  lines <- c(lines, sprintf(
    '<svg viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">', W, total_h))

  for (bi in seq_along(brands)) {
    y0       <- pad_t + (bi - 1) * (bar_h + gap)
    is_focal <- !is.null(focal_brand) && brands[bi] == focal_brand
    val      <- w_vals[bi]
    bar_px   <- if (!is.na(val)) to_px(val) - pad_l else 0
    col      <- if (is_focal) focal_colour else "#94a3b8"
    lbl      <- .cb_brand_lbl(brands[bi], brand_labels)

    lines <- c(lines, sprintf('<g data-brand="%s">', .cb_esc(brands[bi])))

    lines <- c(lines, sprintf(
      '<text class="cb-brand-label" x="%d" y="%.1f" font-size="10" fill="%s" font-weight="%s" text-anchor="end">%s</text>',
      pad_l - 4, y0 + bar_h / 2 + 4,
      if (is_focal) focal_colour else "#475569",
      if (is_focal) "700" else "400",
      .cb_esc(lbl)))

    lines <- c(lines, sprintf(
      '<rect class="cb-brand-bar" x="%d" y="%d" width="%.1f" height="%d" fill="%s"/>',
      pad_l, y0, bar_px, bar_h, col))

    if (!is.na(val)) {
      lines <- c(lines, sprintf(
        '<text x="%.1f" y="%.1f" font-size="9" fill="#475569">%.1f</text>',
        to_px(val) + 3, y0 + bar_h / 2 + 4, val))
    }

    lines <- c(lines, '</g>')
  }

  # Category mean reference line
  ref_px <- to_px(cat_w)
  lines <- c(lines, sprintf(
    '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#475569" stroke-width="1" stroke-dasharray="4,3"/>',
    ref_px, pad_t, ref_px, pad_t + n * (bar_h + gap)))
  lines <- c(lines, sprintf(
    '<text x="%.1f" y="%d" font-size="8" fill="#475569" text-anchor="middle">Category mean</text>',
    ref_px, pad_t + n * (bar_h + gap) + 12))

  lines <- c(lines, "</svg>")
  paste(lines, collapse = "\n")
}


# ==============================================================================
# 4. DoP DEVIATION HEATMAP
# ==============================================================================

#' Render DoP deviation heatmap as an HTML table (colour-coded cells)
#'
#' @param dev_matrix Data frame. \code{dop_deviation_matrix} from repertoire.
#' @param obs_matrix Data frame. \code{crossover_matrix} from repertoire.
#' @param focal_brand Character or NULL.
#' @param brand_labels Named character vector or NULL. Names = BrandCode, values = display labels.
#'
#' @return Character. HTML string.
#' @keywords internal
cb_dop_heatmap_html <- function(dev_matrix, obs_matrix = NULL,
                                 focal_brand  = NULL,
                                 brand_labels = NULL) {
  if (is.null(dev_matrix)) return("")

  brands <- dev_matrix$BrandCode
  n      <- length(brands)

  # Colour scale: diverging around 0
  cell_style <- function(val, obs) {
    if (is.na(val)) return('style="background:#f8fafc;color:#94a3b8;"')
    abs_val <- abs(val)
    alpha   <- min(1, abs_val / 20)
    if (val > 0) {
      bg <- sprintf("rgba(22,101,52,%.2f)", alpha * 0.4)
      col <- if (abs_val >= 10) "#166534" else "#475569"
    } else {
      bg  <- sprintf("rgba(153,27,27,%.2f)", alpha * 0.4)
      col <- if (abs_val >= 10) "#991b1b" else "#475569"
    }
    obs_txt <- if (!is.null(obs) && !is.na(obs)) sprintf(" <small>(%.0f%%)</small>", obs) else ""
    sprintf('style="background:%s;color:%s;text-align:center;" title="Dev: %+.1fpp%s"',
            bg, col, val, obs_txt)
  }

  lines <- character(0)
  lines <- c(lines, '<div class="cb-heatmap-wrap">')
  lines <- c(lines, '<table class="cb-heatmap-table">')
  lines <- c(lines, '<thead><tr><th></th>')
  for (b in brands) {
    lines <- c(lines, sprintf('<th>%s</th>', .cb_esc(.cb_brand_lbl(b, brand_labels))))
  }
  lines <- c(lines, '</tr></thead><tbody>')

  for (i in seq_along(brands)) {
    is_focal <- !is.null(focal_brand) && brands[i] == focal_brand
    row_cls  <- if (is_focal) ' class="focal-row"' else ""
    lines <- c(lines, sprintf('<tr data-brand="%s"%s><td><b>%s</b></td>',
                               .cb_esc(brands[i]), row_cls,
                               .cb_esc(.cb_brand_lbl(brands[i], brand_labels))))
    for (j in seq_along(brands)) {
      if (i == j) {
        lines <- c(lines, '<td style="background:#e2e8f0;color:#94a3b8;text-align:center;">—</td>')
        next
      }
      val <- tryCatch(as.numeric(dev_matrix[i, brands[j]]), error = function(e) NA)
      obs <- if (!is.null(obs_matrix))
        tryCatch(as.numeric(obs_matrix[i, brands[j]]), error = function(e) NULL) else NULL
      lines <- c(lines, sprintf('<td %s>%s</td>', cell_style(val, obs),
                                 if (!is.na(val)) sprintf("%+.1f", val) else "—"))
    }
    lines <- c(lines, '</tr>')
  }
  lines <- c(lines, '</tbody></table></div>')
  paste(lines, collapse = "\n")
}
