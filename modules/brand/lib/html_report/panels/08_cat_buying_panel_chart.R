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

#' Render DoP heatmap as an HTML table (colour-coded cells)
#'
#' @param dev_matrix Data frame. Primary matrix to render — deviation values or
#'   observed crossover percentages when \code{observed = TRUE}.
#' @param obs_matrix Data frame or NULL. Optional overlay shown in tooltip.
#' @param focal_brand Character or NULL.
#' @param brand_labels Named character vector or NULL. Names = BrandCode, values = display labels.
#' @param observed Logical. When \code{TRUE}, renders observed percentages with a
#'   sequential blue scale instead of the diverging green/red deviation scale.
#'
#' @return Character. HTML string.
#' @keywords internal
cb_dop_heatmap_html <- function(dev_matrix, obs_matrix = NULL,
                                 focal_brand    = NULL,
                                 brand_labels   = NULL,
                                 observed       = FALSE,
                                 brand_buyers_n = NULL) {
  if (is.null(dev_matrix)) return("")

  brands <- dev_matrix$BrandCode
  n      <- length(brands)

  # Column averages & SDs across the non-diagonal cells in each column.
  col_vals <- lapply(brands, function(col_b) {
    v <- tryCatch(as.numeric(dev_matrix[, col_b]), error = function(e) rep(NA_real_, n))
    # exclude diagonal (i == j) — brand vs. itself
    diag_idx <- which(brands == col_b)
    if (length(diag_idx) == 1) v[diag_idx] <- NA_real_
    v
  })
  col_avgs <- vapply(col_vals, function(v) mean(v, na.rm = TRUE), numeric(1))
  col_sds  <- vapply(col_vals, function(v) sd(v,   na.rm = TRUE), numeric(1))
  # Per-column display max for CI mini-bar scaling — make sure it covers both
  # the largest observed value and the upper CI bound, with a small margin.
  col_max  <- vapply(seq_along(brands), function(j) {
    cv <- col_vals[[j]]
    raw_max <- suppressWarnings(max(cv, na.rm = TRUE))
    if (!is.finite(raw_max)) raw_max <- 0
    hi <- if (is.finite(col_avgs[j]) && is.finite(col_sds[j]))
      col_avgs[j] + col_sds[j] else raw_max
    m <- max(raw_max, hi, na.rm = TRUE) * 1.1
    if (!is.finite(m) || m <= 0) 1 else m
  }, numeric(1))

  # Traffic-light CI-band classifier for observed mode (green above upper band,
  # red below lower band, amber inside). For deviation mode keep legacy scale.
  hm_cls <- function(val, avg, sd_v) {
    if (is.na(val) || is.na(avg) || is.na(sd_v) || sd_v == 0) return("cb-dop-near")
    if (val > avg + sd_v) "cb-dop-above"
    else if (val < avg - sd_v) "cb-dop-below"
    else "cb-dop-near"
  }

  # Lookup for row buyer base (used by Show counts toggle → renders n=X below %).
  # `brand_buyers_n` may be a named int/num vector or a list; use single-bracket
  # to get NA safely for unknown names.
  buyers_lookup <- function(code) {
    if (is.null(brand_buyers_n)) return(NA_real_)
    nm <- as.character(code)
    if (!nm %in% names(brand_buyers_n)) return(NA_real_)
    v <- suppressWarnings(as.numeric(brand_buyers_n[nm]))
    if (length(v) != 1 || !is.finite(v)) return(NA_real_)
    v
  }
  fmt_n <- function(n) {
    if (!is.finite(n)) return("\u2014")
    if (n >= 1000) format(round(n), big.mark = ",", scientific = FALSE)
    else sprintf("%d", as.integer(round(n)))
  }

  # Cell styling. `observed` → use CI-band traffic-light class; else legacy
  # green/red deviation alpha shading.
  cell_attrs <- function(val, col_idx, obs) {
    if (is.na(val)) return(list(cls = "", style = 'background:#f8fafc;color:#94a3b8;', title = ""))
    if (observed) {
      cls <- hm_cls(val, col_avgs[col_idx], col_sds[col_idx])
      title <- sprintf("%.0f%% \u2014 col avg %.0f%%, \u00b11 SD %.1f",
                       val, col_avgs[col_idx], col_sds[col_idx])
      return(list(cls = cls, style = "text-align:center;", title = title))
    }
    abs_val <- abs(val)
    alpha   <- min(1, abs_val / 20)
    if (val > 0) {
      bg <- sprintf("rgba(22,101,52,%.2f)", alpha * 0.4)
      co <- if (abs_val >= 10) "#166534" else "#475569"
    } else {
      bg <- sprintf("rgba(153,27,27,%.2f)", alpha * 0.4)
      co <- if (abs_val >= 10) "#991b1b" else "#475569"
    }
    obs_txt <- if (!is.null(obs) && !is.na(obs)) sprintf(" (obs %.0f%%)", obs) else ""
    list(cls = "",
         style = sprintf("background:%s;color:%s;text-align:center;", bg, co),
         title = sprintf("Dev: %+.1fpp%s", val, obs_txt))
  }

  lines <- character(0)
  lines <- c(lines, '<div class="cb-heatmap-wrap">')
  lines <- c(lines, '<table class="cb-heatmap-table cb-dop-table" data-cb-heatmap="on">')

  # Column-group header label above — "% of buyers who also bought brand"
  lines <- c(lines, '<thead>')
  lines <- c(lines, sprintf(paste0(
    '<tr class="cb-dop-grouphdr"><th class="cb-dop-row-hdr"></th>',
    '<th class="cb-dop-group-lbl" colspan="%d">%% of buyers who also bought brand</th></tr>'),
    n))

  # Header row — Brand column sortable A-Z/Z-A (col 0); columns sort numerically.
  lines <- c(lines, paste0(
    '<tr><th class="cb-dop-row-hdr cb-sortable" ',
    'data-cb-sort-col="0" data-cb-sort-dir="none" title="Click to sort A-Z">',
    '<span class="cb-th-label">Brand</span>',
    '<span class="cb-sort-ind"></span></th>'))
  for (bi in seq_along(brands)) {
    lines <- c(lines, sprintf(paste0(
      '<th class="cb-dop-col-hdr cb-sortable" ',
      'data-cb-sort-col="%d" data-cb-sort-dir="none" ',
      'title="Click to sort">',
      '<span class="cb-th-label">%s</span>',
      '<span class="cb-sort-ind"></span></th>'),
      bi, .cb_esc(.cb_brand_lbl(brands[bi], brand_labels))))
  }
  lines <- c(lines, '</tr></thead><tbody>')

  # Build a single brand row (used for focal-first + non-focal rows).
  build_brand_row <- function(i) {
    is_focal <- !is.null(focal_brand) && brands[i] == focal_brand
    row_cls  <- if (is_focal) "focal-row" else ""
    row_buyers <- buyers_lookup(brands[i])
    nm <- .cb_brand_lbl(brands[i], brand_labels)
    # Brand column text-sort key lives on the row as data-name (lowercased).
    out <- sprintf(
      '<tr data-brand="%s" class="%s" data-name="%s"><td class="cb-dop-row-lbl"><b>%s</b></td>',
      .cb_esc(brands[i]), row_cls, .cb_esc(tolower(nm)), .cb_esc(nm))
    cells <- character(0)
    for (j in seq_along(brands)) {
      if (i == j) {
        cells <- c(cells, '<td class="cb-dop-diag" style="text-align:center;">\u2014</td>')
        next
      }
      val <- tryCatch(as.numeric(dev_matrix[i, brands[j]]), error = function(e) NA)
      obs <- if (!is.null(obs_matrix))
        tryCatch(as.numeric(obs_matrix[i, brands[j]]), error = function(e) NULL) else NULL
      val_txt <- if (is.na(val)) "\u2014" else if (observed) sprintf("%.0f%%", val) else sprintf("%+.1f", val)
      attrs <- cell_attrs(val, j, obs)
      data_v_attr <- if (!is.na(val)) sprintf(' data-v="%.4f"', val) else ' data-v=""'
      # Show-counts companion: n = pct * row_buyers / 100 (hidden by default).
      n_val <- if (!is.na(val) && is.finite(row_buyers)) val * row_buyers / 100 else NA_real_
      n_span <- if (!is.na(val))
        sprintf('<span class="cb-val-n" hidden>n=%s</span>', fmt_n(n_val))
      else ""
      pct_span <- sprintf('<span class="cb-val-pct">%s</span>', val_txt)
      cells <- c(cells, sprintf(
        '<td class="cb-dop-cell %s"%s style="%s" title="%s">%s%s</td>',
        attrs$cls, data_v_attr, attrs$style, .cb_esc(attrs$title),
        pct_span, n_span))
    }
    paste0(out, paste(cells, collapse = ""), '</tr>')
  }

  # Category average row — value + CI mini-bar (avg \u00b1 1 SD), funnel format
  avg_cells <- vapply(seq_along(brands), function(j) {
    v    <- col_avgs[j]
    sdv  <- col_sds[j]
    if (!is.finite(v)) {
      return('<td class="cb-dop-avg-cell" data-v="" style="text-align:center;">\u2014</td>')
    }
    txt  <- sprintf("%.0f%%", v)
    data_v_attr <- sprintf(' data-v="%.4f"', v)
    safe_max <- col_max[j]
    ci_bar <- ""
    if (is.finite(sdv) && sdv > 0) {
      lo <- max(0, v - sdv); hi <- min(safe_max, v + sdv)
      lo_disp <- sprintf("%.0f%%", lo)
      hi_disp <- sprintf("%.0f%%", hi)
      fill_left <- max(0, min(94, 100 * lo / safe_max))
      fill_w    <- max(4, min(100 - fill_left, 100 * (hi - lo) / safe_max))
      mean_pct  <- max(1, min(99, 100 * v / safe_max))
      ci_bar <- paste0(
        sprintf('<div class="ma-ci-bar-wrap" title="CI (\u00b11 SD): %s \u2013 %s">', lo_disp, hi_disp),
        sprintf('<div class="ma-ci-bar-range" style="left:%.1f%%;width:%.1f%%;"></div>', fill_left, fill_w),
        sprintf('<div class="ma-ci-bar-tick" style="left:%.1f%%"></div>', mean_pct),
        '</div>',
        sprintf('<div class="ma-ci-limits"><span>%s</span><span>%s</span></div>', lo_disp, hi_disp))
    }
    sprintf(
      '<td class="cb-dop-avg-cell cb-dop-avg-ci"%s style="text-align:center;"><span class="cb-val-pct">%s</span>%s</td>',
      data_v_attr, txt, ci_bar)
  }, character(1))
  avg_row_html <- sprintf(
    '<tr class="cb-dop-avg-row"><td class="cb-dop-row-lbl"><em>Category average</em></td>%s</tr>',
    paste(avg_cells, collapse = ""))

  # Row order: focal FIRST (above Category avg), then avg, then remaining brands.
  focal_idx  <- if (!is.null(focal_brand)) which(brands == focal_brand) else integer(0)
  other_idx  <- setdiff(seq_along(brands), focal_idx)

  if (length(focal_idx) == 1) {
    lines <- c(lines, build_brand_row(focal_idx))
  }
  lines <- c(lines, avg_row_html)
  for (i in other_idx) lines <- c(lines, build_brand_row(i))

  lines <- c(lines, '</tbody></table></div>')
  paste(lines, collapse = "\n")
}


# ==============================================================================
# 5. SCR PER BRAND BAR CHART
# ==============================================================================

#' Render Share of Category Requirement (SCR) per brand as an SVG bar chart
#'
#' Horizontal bars show observed SCR per brand. A tick marker shows the
#' Dirichlet-expected SCR. A dotted reference line marks the category mean.
#' Brands sorted: focal first, then by penetration descending.
#'
#' @param norms_table Data frame. From \code{run_dirichlet_norms()$norms_table}.
#'   Must contain \code{SCR_Obs_Pct}, \code{SCR_Exp_Pct}, \code{Penetration_Obs_Pct},
#'   \code{DJ_Flag}.
#' @param focal_brand Character or NULL.
#' @param focal_colour Character. Hex colour.
#' @param brand_labels Named character vector or NULL.
#'
#' @return Character. SVG string.
#' @keywords internal
cb_scr_bars_svg <- function(norms_table,
                             focal_brand  = NULL,
                             focal_colour = "#1A5276",
                             brand_labels = NULL) {
  if (is.null(norms_table) || nrow(norms_table) == 0) return("")

  # Sort: focal first, then by penetration descending
  focal_row <- if (!is.null(focal_brand))
    which(norms_table$BrandCode == focal_brand) else integer(0)
  other_rows <- setdiff(seq_len(nrow(norms_table)), focal_row)
  if (length(other_rows) > 0 && "Penetration_Obs_Pct" %in% names(norms_table)) {
    other_rows <- other_rows[order(-norms_table$Penetration_Obs_Pct[other_rows])]
  }
  ord <- c(focal_row, other_rows)
  nt  <- norms_table[ord, , drop = FALSE]

  brands   <- nt$BrandCode
  scr_obs  <- nt$SCR_Obs_Pct
  scr_exp  <- if ("SCR_Exp_Pct"          %in% names(nt)) nt$SCR_Exp_Pct          else rep(NA_real_, nrow(nt))
  dj_flag  <- if ("DJ_Flag"              %in% names(nt)) nt$DJ_Flag               else rep("on_line", nrow(nt))
  n        <- nrow(nt)

  bar_h   <- 20L
  gap     <- 7L
  W       <- 280L
  pad_l   <- 62L; pad_r <- 28L; pad_t <- 14L; pad_b <- 28L
  total_h <- pad_t + n * (bar_h + gap) + pad_b

  max_scr <- max(c(scr_obs, scr_exp), na.rm = TRUE)
  max_scr <- if (is.finite(max_scr)) max_scr * 1.12 else 100
  to_px   <- function(v) pad_l + (v / max_scr) * (W - pad_l - pad_r)

  # Bar colour: focal uses focal colour; over/under get semantic tints
  bar_col <- function(bi) {
    if (!is.null(focal_brand) && brands[bi] == focal_brand) return(focal_colour)
    flag <- dj_flag[bi]
    if (identical(flag, "over"))  return("#16a34a")
    if (identical(flag, "under")) return("#dc2626")
    "#94a3b8"
  }

  lines <- character(0)
  lines <- c(lines, sprintf(
    '<svg class="cb-scr-svg" viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">',
    W, total_h))

  # Light vertical grid lines + x-axis labels
  for (gx in pretty(c(0, max_scr), n = 4)) {
    if (gx < 0) next
    px <- to_px(gx)
    if (px > W - pad_r + 2) next
    lines <- c(lines, sprintf(
      '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#f1f5f9" stroke-width="1"/>',
      px, pad_t, px, pad_t + n * (bar_h + gap)))
    lines <- c(lines, sprintf(
      '<text x="%.1f" y="%d" font-size="8" fill="#94a3b8" text-anchor="middle">%.0f%%</text>',
      px, pad_t + n * (bar_h + gap) + 11L, gx))
  }

  # One row per brand
  for (bi in seq_along(brands)) {
    y0       <- pad_t + (bi - 1L) * (bar_h + gap)
    is_focal <- !is.null(focal_brand) && brands[bi] == focal_brand
    obs_val  <- scr_obs[bi]
    exp_val  <- scr_exp[bi]
    col      <- bar_col(bi)
    lbl      <- .cb_brand_lbl(brands[bi], brand_labels)

    lines <- c(lines, sprintf('<g data-brand="%s">', .cb_esc(brands[bi])))

    lines <- c(lines, sprintf(
      '<text x="%d" y="%.1f" font-size="10" fill="%s" font-weight="%s" text-anchor="end">%s</text>',
      pad_l - 3L, y0 + bar_h / 2 + 3.5,
      if (is_focal) focal_colour else "#475569",
      if (is_focal) "700" else "400",
      .cb_esc(lbl)))

    if (!is.na(obs_val)) {
      bar_px <- to_px(obs_val) - pad_l
      lines <- c(lines, sprintf(
        '<rect x="%d" y="%d" width="%.1f" height="%d" fill="%s" rx="2"/>',
        pad_l, y0, max(0.5, bar_px), bar_h, col))
      lines <- c(lines, sprintf(
        '<text x="%.1f" y="%.1f" font-size="9" fill="%s">%.0f%%</text>',
        to_px(obs_val) + 2L, y0 + bar_h / 2 + 3.5,
        if (is_focal) focal_colour else "#475569", obs_val))
    }

    # Expected SCR tick marker
    if (!is.na(exp_val)) {
      ex_px <- to_px(exp_val)
      lines <- c(lines, sprintf(
        '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#334155" stroke-width="2"/>',
        ex_px, y0 - 1L, ex_px, y0 + bar_h + 1L))
    }

    lines <- c(lines, '</g>')
  }

  # Category mean SCR reference line
  cat_mean_scr <- mean(scr_obs, na.rm = TRUE)
  if (is.finite(cat_mean_scr)) {
    ref_px <- to_px(cat_mean_scr)
    lines <- c(lines, sprintf(
      '<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#475569" stroke-width="1" stroke-dasharray="4,3"/>',
      ref_px, pad_t, ref_px, pad_t + n * (bar_h + gap)))
    lines <- c(lines, sprintf(
      '<text x="%.1f" y="%d" font-size="8" fill="#475569" text-anchor="middle">Cat mean</text>',
      ref_px, pad_t + n * (bar_h + gap) + 22L))
  }

  # Compact inline legend
  lx <- pad_l; ly <- total_h - 7L
  lines <- c(lines, sprintf(
    '<rect x="%d" y="%d" width="12" height="8" fill="#94a3b8" rx="1"/>', lx, ly - 7L))
  lines <- c(lines, sprintf(
    '<text x="%d" y="%d" font-size="8" fill="#64748b"> Obs</text>', lx + 14L, ly))
  lines <- c(lines, sprintf(
    '<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#334155" stroke-width="2"/>',
    lx + 46L, ly - 3L, lx + 46L, ly + 1L))
  lines <- c(lines, sprintf(
    '<text x="%d" y="%d" font-size="8" fill="#64748b"> Exp</text>', lx + 48L, ly))

  lines <- c(lines, '</svg>')
  paste(lines, collapse = "\n")
}


# ==============================================================================
# 6. LOYALTY SEGMENTATION CHART
# ==============================================================================

#' Render per-brand loyalty segmentation as HTML stacked bar chart
#'
#' Shows 4 segments per brand as % of all category buyers:
#' Sole buyer | Primary (SCR > 50%) | Secondary (SCR ≤ 50%) | Not bought.
#' Sorted: focal first, then by (Sole + Primary + Secondary) descending.
#' Category average row always shown at top.
#'
#' @param loyalty_segs Data frame. From \code{run_buyer_heaviness()$brand_loyalty_segments}.
#'   Columns: BrandCode, Sole_Pct, Primary_Pct, Secondary_Pct, NoBuy_Pct.
#' @param focal_brand Character or NULL.
#' @param focal_colour Character. Hex colour (used to highlight focal label).
#' @param brand_labels Named character vector or NULL.
#' @param brand_heaviness Data frame or NULL. From \code{run_buyer_heaviness()$brand_heaviness}.
#'   Used to display buyer base (n=) per brand.
#'
#' @return Character. HTML string.
#' @keywords internal
cb_loyalty_segs_html <- function(loyalty_segs,
                                  focal_brand    = NULL,
                                  focal_colour   = "#1A5276",
                                  brand_labels   = NULL,
                                  brand_heaviness = NULL,
                                  chart_id        = NULL) {
  if (is.null(loyalty_segs) || nrow(loyalty_segs) == 0) return("")

  cols     <- c(Sole = "#166534", Primary = "#4ade80",
                Secondary = "#fbbf24", NoBuy = "#e2e8f0")
  txt_cols <- c(Sole = "#ffffff",  Primary = "#1e293b",
                Secondary = "#1e293b", NoBuy = "#94a3b8")

  # Category average row (unweighted mean across all brands)
  avg_sole  <- mean(loyalty_segs$Sole_Pct,      na.rm = TRUE)
  avg_prim  <- mean(loyalty_segs$Primary_Pct,   na.rm = TRUE)
  avg_sec   <- mean(loyalty_segs$Secondary_Pct, na.rm = TRUE)
  avg_nobuy <- mean(loyalty_segs$NoBuy_Pct,     na.rm = TRUE)

  # Sort: focal first, then by bought (Sole + Primary + Secondary) descending
  focal_idx  <- if (!is.null(focal_brand))
    which(loyalty_segs$BrandCode == focal_brand) else integer(0)
  other_idx  <- setdiff(seq_len(nrow(loyalty_segs)), focal_idx)
  bought_pct <- loyalty_segs$Sole_Pct + loyalty_segs$Primary_Pct +
                loyalty_segs$Secondary_Pct
  if (length(other_idx) > 0)
    other_idx <- other_idx[order(-bought_pct[other_idx])]
  ord <- c(focal_idx, other_idx)
  ls  <- loyalty_segs[ord, , drop = FALSE]

  seg_classes <- c("cb-loy-seg-0", "cb-loy-seg-1", "cb-loy-seg-2", "cb-loy-seg-3")
  .seg_html <- function(pcts_named) {
    seg_keys <- c("Sole", "Primary", "Secondary", "NoBuy")
    paste(vapply(seq_along(seg_keys), function(ki) {
      k <- seg_keys[ki]
      p <- if (is.na(pcts_named[[k]])) 0 else pcts_named[[k]]
      lbl_txt <- if (p >= 10) sprintf("%.0f%%", p) else ""
      if (p < 0.5)
        return(sprintf('<div class="%s cb-loyalty-seg" style="width:0;display:none;"></div>', seg_classes[ki]))
      sprintf('<div class="%s cb-loyalty-seg" style="width:%.2f%%;background:%s;color:%s;">%s</div>',
              seg_classes[ki], p, cols[[k]], txt_cols[[k]], lbl_txt)
    }, character(1)), collapse = "")
  }

  .make_row <- function(label, label_cls, n_lbl, pcts, data_brand = "") {
    db_attr <- if (nzchar(data_brand)) sprintf(' data-brand="%s"', .cb_esc(data_brand)) else ""
    sprintf(
      '<div class="cb-loyalty-row"%s><div class="cb-loyalty-label %s">%s</div><div class="cb-loyalty-n">%s</div><div class="cb-loyalty-bars">%s</div></div>',
      db_attr, label_cls, .cb_esc(label), n_lbl, .seg_html(pcts))
  }

  id_attr <- if (!is.null(chart_id)) sprintf(' id="%s"', .cb_esc(chart_id)) else ""
  lines <- character(0)
  lines <- c(lines, sprintf('<div class="cb-loyalty-chart"%s>', id_attr))

  # Legend
  leg_items <- list(
    list(col = cols[["Sole"]],      lbl = "Sole buyer"),
    list(col = cols[["Primary"]],   lbl = "Primary (&gt;50% SCR)"),
    list(col = cols[["Secondary"]], lbl = "Secondary"),
    list(col = cols[["NoBuy"]],     lbl = "Not bought")
  )
  leg_html <- paste(vapply(leg_items, function(li) {
    sprintf('<span class="cb-loyalty-legend-item"><span class="cb-loyalty-legend-swatch" style="background:%s;"></span>%s</span>',
            li$col, li$lbl)
  }, character(1)), collapse = "")
  lines <- c(lines, sprintf('<div class="cb-loyalty-legend">%s</div>', leg_html))

  # Category average row
  lines <- c(lines, .make_row(
    "Category avg", "avg", "",
    list(Sole = avg_sole, Primary = avg_prim,
         Secondary = avg_sec, NoBuy = avg_nobuy)))
  lines <- c(lines,
    '<div style="border-top:1px solid #e2e8f0;margin:4px 0 4px 118px;"></div>')

  # Per-brand rows
  for (i in seq_len(nrow(ls))) {
    bc      <- ls$BrandCode[i]
    lbl     <- .cb_brand_lbl(bc, brand_labels)
    cls     <- if (!is.null(focal_brand) && bc == focal_brand) "focal" else ""
    n_txt   <- ""
    if (!is.null(brand_heaviness) && nrow(brand_heaviness) > 0) {
      ri <- which(brand_heaviness$BrandCode == bc)
      if (length(ri) == 1 && "Brand_Buyers_n" %in% names(brand_heaviness) &&
          !is.na(brand_heaviness$Brand_Buyers_n[ri]))
        n_txt <- sprintf("n=%s", formatC(as.integer(brand_heaviness$Brand_Buyers_n[ri]),
                                         format = "d", big.mark = ","))
    }
    lines <- c(lines, .make_row(
      lbl, cls, n_txt,
      list(Sole      = ls$Sole_Pct[i],
           Primary   = ls$Primary_Pct[i],
           Secondary = ls$Secondary_Pct[i],
           NoBuy     = ls$NoBuy_Pct[i]),
      bc))
  }

  lines <- c(lines, '</div>')
  paste(lines, collapse = "\n")
}


# ==============================================================================
# 7. PURCHASE FREQUENCY DISTRIBUTION CHART
# ==============================================================================

#' Render per-brand purchase frequency distribution as a stacked SVG bar chart
#'
#' Shows what % of brand buyers purchased 1×, 2×, 3–5×, or 6+ times.
#' Sorted: focal first, then by penetration descending (or Freq6plus desc).
#'
#' @param freq_dist Data frame. From \code{run_buyer_heaviness()$brand_freq_dist}.
#'   Columns: BrandCode, Freq1_Pct, Freq2_Pct, Freq3to5_Pct, Freq6plus_Pct.
#' @param focal_brand Character or NULL.
#' @param focal_colour Character. Hex colour (used to highlight focal label).
#' @param brand_labels Named character vector or NULL.
#'
#' @return Character. SVG string.
#' @keywords internal
cb_freq_dist_svg <- function(freq_dist,
                              focal_brand  = NULL,
                              focal_colour = "#1A5276",
                              brand_labels = NULL) {
  if (is.null(freq_dist) || nrow(freq_dist) == 0) return("")

  # Sort: focal first, then by Freq1 descending (most light-usage first)
  focal_row  <- if (!is.null(focal_brand))
    which(freq_dist$BrandCode == focal_brand) else integer(0)
  other_rows <- setdiff(seq_len(nrow(freq_dist)), focal_row)
  if (length(other_rows) > 0 && "Freq1_Pct" %in% names(freq_dist))
    other_rows <- other_rows[order(-freq_dist$Freq1_Pct[other_rows])]
  ord <- c(focal_row, other_rows)
  fd  <- freq_dist[ord, , drop = FALSE]

  brands  <- fd$BrandCode
  n       <- nrow(fd)
  bar_h   <- 20L
  gap     <- 6L
  W       <- 280L
  pad_l   <- 62L; pad_r <- 10L; pad_t <- 14L; pad_b <- 44L
  total_h <- pad_t + n * (bar_h + gap) + pad_b
  bw      <- W - pad_l - pad_r

  # Blue shades — lightest = 1×, darkest = 6+×
  cols <- c("#bfdbfe", "#60a5fa", "#2563eb", "#1e3a8a")

  lines <- character(0)
  lines <- c(lines, sprintf(
    '<svg viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">', W, total_h))

  for (bi in seq_along(brands)) {
    y0       <- pad_t + (bi - 1L) * (bar_h + gap)
    is_focal <- !is.null(focal_brand) && brands[bi] == focal_brand
    lbl      <- .cb_brand_lbl(brands[bi], brand_labels)

    f1  <- (fd$Freq1_Pct[bi] %||% 0)     / 100
    f2  <- (fd$Freq2_Pct[bi] %||% 0)     / 100
    f35 <- (fd$Freq3to5_Pct[bi] %||% 0)  / 100
    f6  <- (fd$Freq6plus_Pct[bi] %||% 0) / 100

    lines <- c(lines, sprintf('<g data-brand="%s">', .cb_esc(brands[bi])))
    lines <- c(lines, sprintf(
      '<text x="%d" y="%.1f" font-size="10" fill="%s" font-weight="%s" text-anchor="end">%s</text>',
      pad_l - 3L, y0 + bar_h / 2 + 3.5,
      if (is_focal) focal_colour else "#475569",
      if (is_focal) "700" else "400",
      .cb_esc(lbl)))

    segs <- list(
      list(pct = f1,  col = cols[1]),
      list(pct = f2,  col = cols[2]),
      list(pct = f35, col = cols[3]),
      list(pct = f6,  col = cols[4])
    )
    x_cur <- as.numeric(pad_l)
    for (seg in segs) {
      if (is.na(seg$pct)) { next }
      seg_w <- seg$pct * bw
      if (seg_w < 0.5) { x_cur <- x_cur + seg_w; next }
      lines <- c(lines, sprintf(
        '<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="%s" rx="1"/>',
        x_cur, y0, seg_w, bar_h, seg$col))
      x_cur <- x_cur + seg_w
    }
    lines <- c(lines, '</g>')
  }

  # Legend
  ly <- total_h - pad_b + 10L
  leg_items <- list(
    list(col = cols[1], lbl = "1\u00d7"),
    list(col = cols[2], lbl = "2\u00d7"),
    list(col = cols[3], lbl = "3\u20135\u00d7"),
    list(col = cols[4], lbl = "6+\u00d7")
  )
  lx <- as.numeric(pad_l)
  for (item in leg_items) {
    lines <- c(lines, sprintf(
      '<rect x="%.1f" y="%d" width="10" height="8" fill="%s" rx="1"/>',
      lx, ly - 7L, item$col))
    lines <- c(lines, sprintf(
      '<text x="%.1f" y="%d" font-size="8" fill="#64748b">%s</text>',
      lx + 12L, ly, item$lbl))
    lx <- lx + 34
  }
  lines <- c(lines, sprintf(
    '<text x="%.1f" y="%d" font-size="8" fill="#94a3b8">%% of brand buyers</text>',
    as.numeric(pad_l), total_h - 2L))

  lines <- c(lines, '</svg>')
  paste(lines, collapse = "\n")
}


# ==============================================================================
# 8. PURCHASE DISTRIBUTION HTML CHART (configurable labels)
# ==============================================================================

#' Render per-brand purchase frequency distribution as HTML stacked bar chart
#'
#' Shows % of brand buyers in each frequency bucket (1×, 2×, 3–5×, 6+×).
#' Category average row always shown at top. Bucket labels are configurable
#' via \code{dist_labels} to allow custom terminology (e.g. "Very light",
#' "Light", "Regular", "Frequent").
#'
#' @param freq_dist Data frame. From \code{run_buyer_heaviness()$brand_freq_dist}.
#'   Columns: BrandCode, Freq1_Pct, Freq2_Pct, Freq3to5_Pct, Freq6plus_Pct.
#' @param focal_brand Character or NULL.
#' @param focal_colour Character. Hex colour.
#' @param brand_labels Named character vector or NULL.
#' @param brand_heaviness Data frame or NULL. Used to display buyer base (n=).
#' @param dist_labels Character vector of length 4 or NULL. Custom bucket labels.
#'   Default: \code{c("Light (1\u00d7)", "Moderate (2\u00d7)", "Regular (3\u20135\u00d7)", "Frequent (6+\u00d7)")}.
#'
#' @return Character. HTML string.
#' @keywords internal
cb_purchase_dist_html <- function(freq_dist,
                                   focal_brand    = NULL,
                                   focal_colour   = "#1A5276",
                                   brand_labels   = NULL,
                                   brand_heaviness = NULL,
                                   dist_labels    = NULL,
                                   chart_id        = NULL) {
  if (is.null(freq_dist) || nrow(freq_dist) == 0) return("")

  default_labels <- c("Light (1\u00d7)", "Moderate (2\u00d7)",
                       "Regular (3\u20135\u00d7)", "Frequent (6+\u00d7)")
  seg_labels <- if (!is.null(dist_labels) && length(dist_labels) == 4L)
    as.character(dist_labels) else default_labels

  cols     <- c("#bfdbfe", "#60a5fa", "#2563eb", "#1e3a8a")
  txt_cols <- c("#1e293b", "#1e293b", "#ffffff",  "#ffffff")

  # Category average (unweighted mean across all brands)
  avg_f1  <- mean(freq_dist$Freq1_Pct,     na.rm = TRUE)
  avg_f2  <- mean(freq_dist$Freq2_Pct,     na.rm = TRUE)
  avg_f35 <- mean(freq_dist$Freq3to5_Pct,  na.rm = TRUE)
  avg_f6  <- mean(freq_dist$Freq6plus_Pct, na.rm = TRUE)

  # Sort: focal first, then by Freq1 descending (most light-usage first)
  focal_idx <- if (!is.null(focal_brand))
    which(freq_dist$BrandCode == focal_brand) else integer(0)
  other_idx <- setdiff(seq_len(nrow(freq_dist)), focal_idx)
  if (length(other_idx) > 0 && "Freq1_Pct" %in% names(freq_dist))
    other_idx <- other_idx[order(-freq_dist$Freq1_Pct[other_idx])]
  ord <- c(focal_idx, other_idx)
  fd  <- freq_dist[ord, , drop = FALSE]

  dist_seg_classes <- paste0("cb-dist-seg-", 0:3)
  .seg_html <- function(pcts) {
    paste(vapply(seq_along(pcts), function(si) {
      p <- if (is.na(pcts[si])) 0 else pcts[si]
      lbl_txt <- if (p >= 10) sprintf("%.0f%%", p) else ""
      if (p < 0.5)
        return(sprintf('<div class="%s cb-dist-seg" style="width:0;display:none;"></div>', dist_seg_classes[si]))
      sprintf('<div class="%s cb-dist-seg" style="width:%.2f%%;background:%s;color:%s;">%s</div>',
              dist_seg_classes[si], p, cols[si], txt_cols[si], lbl_txt)
    }, character(1)), collapse = "")
  }

  .make_row <- function(label, label_cls, n_lbl, pcts, data_brand = "") {
    db_attr <- if (nzchar(data_brand)) sprintf(' data-brand="%s"', .cb_esc(data_brand)) else ""
    sprintf(
      '<div class="cb-dist-row"%s><div class="cb-dist-label %s">%s</div><div class="cb-dist-n">%s</div><div class="cb-dist-bars">%s</div></div>',
      db_attr, label_cls, .cb_esc(label), n_lbl, .seg_html(pcts))
  }

  dist_id_attr <- if (!is.null(chart_id)) sprintf(' id="%s"', .cb_esc(chart_id)) else ""
  lines <- character(0)
  lines <- c(lines, sprintf('<div class="cb-dist-chart"%s>', dist_id_attr))

  # Legend
  leg_html <- paste(vapply(seq_along(seg_labels), function(si) {
    sprintf('<span class="cb-dist-legend-item"><span class="cb-dist-legend-swatch" style="background:%s;"></span>%s</span>',
            cols[si], .cb_esc(seg_labels[si]))
  }, character(1)), collapse = "")
  lines <- c(lines, sprintf('<div class="cb-dist-legend">%s</div>', leg_html))

  # Category average row
  lines <- c(lines, .make_row(
    "Category avg", "avg", "", c(avg_f1, avg_f2, avg_f35, avg_f6)))
  lines <- c(lines,
    '<div style="border-top:1px solid #e2e8f0;margin:4px 0 4px 118px;"></div>')

  # Per-brand rows
  for (i in seq_len(nrow(fd))) {
    bc    <- fd$BrandCode[i]
    lbl   <- .cb_brand_lbl(bc, brand_labels)
    cls   <- if (!is.null(focal_brand) && bc == focal_brand) "focal" else ""
    n_txt <- ""
    if (!is.null(brand_heaviness) && nrow(brand_heaviness) > 0) {
      ri <- which(brand_heaviness$BrandCode == bc)
      if (length(ri) == 1 && "Brand_Buyers_n" %in% names(brand_heaviness) &&
          !is.na(brand_heaviness$Brand_Buyers_n[ri]))
        n_txt <- sprintf("n=%s", formatC(as.integer(brand_heaviness$Brand_Buyers_n[ri]),
                                         format = "d", big.mark = ","))
    }
    lines <- c(lines, .make_row(
      lbl, cls, n_txt,
      c(fd$Freq1_Pct[i], fd$Freq2_Pct[i], fd$Freq3to5_Pct[i], fd$Freq6plus_Pct[i]),
      bc))
  }

  lines <- c(lines, '</div>')
  paste(lines, collapse = "\n")
}
