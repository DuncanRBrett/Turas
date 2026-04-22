# ==============================================================================
# BRAND MODULE - MA PANEL MATRIX TABLE (brands-as-columns)
# ==============================================================================
# Renders the attribute x brand and CEP x brand matrix tables.
#
# Layout: statements (attributes or CEPs) as ROWS, brands as COLUMNS.
# Column order: [Label] [Base n=] [Focal brand] [Category avg] [Other brands...]
#
# Heatmap modes (controlled via JS toggles in the controls bar):
#   - CI band (default): green if above 95% CI vs cat-avg row, amber if
#                        within, red if below. Mirrors funnel relationship
#                        screenshot.
#   - Heatmap proportional: diverging red/blue vs row mean (old default).
#
# Sig markers ↑/↓ render next to each percentage when the two-proportion
# z-test against cat-avg is significant at 0.05.
#
# Row interactions: click the row label to grey-out the row. Greyed rows
# are dimmed in the table and excluded from the bar chart.
# ==============================================================================


#' Build the MA matrix section HTML.
#'
#' @param pd Panel data from build_ma_panel_data().
#' @param stim Character. "attributes" or "ceps".
#' @param focal_colour Character. Hex colour for focal highlighting.
#' @return Character string (section element).
#' @export
build_ma_matrix_section <- function(pd, stim = c("attributes", "ceps"),
                                    focal_colour = "#1A5276") {
  stim <- match.arg(stim)
  block <- if (stim == "attributes") pd$attributes else pd$ceps
  if (is.null(block) || length(block$codes) == 0) return("")

  # Column order: focal brand FIRST, then the rest in brand-list order.
  brand_codes_all <- pd$config$brand_codes %||% block$brand_codes
  brand_names_all <- pd$config$brand_names %||% brand_codes_all
  focal <- pd$meta$focal_brand_code
  if (!is.null(focal) && focal %in% brand_codes_all) {
    order_idx <- c(which(brand_codes_all == focal),
                   which(brand_codes_all != focal))
    brand_codes <- brand_codes_all[order_idx]
    brand_names <- brand_names_all[order_idx]
  } else {
    brand_codes <- brand_codes_all
    brand_names <- brand_names_all
  }

  paste0(
    sprintf('<section class="ma-section ma-matrix-section" data-ma-stim="%s">',
            stim),
    '<div class="ma-table-wrap">',
    sprintf('<table class="ct-table ma-ct-table ma-table" data-ma-table="%s">',
            stim),
    .ma_table_header(brand_codes, brand_names, focal, stim, pd),
    '<tbody>',
    .ma_table_rows(block, brand_codes, focal, stim, pd),
    .ma_table_footer(block, brand_codes, focal),
    '</tbody></table></div>',
    '</section>'
  )
}


# ==============================================================================
# INTERNAL: HEADER
#   [Label] [Base] [Focal] [Cat avg] [Other brands...]
# ==============================================================================

.ma_table_header <- function(brand_codes, brand_names, focal, stim, pd) {
  stmt_label <- if (stim == "attributes") "Attribute" else "Entry Point"
  stmt_th <- sprintf(
    '<th class="ct-th ct-label-col ma-ct-th-stim" data-sort-col="stim">
       <div class="ct-header-text">%s</div>
       <button type="button" class="ct-sort-indicator ma-sort-btn"
               aria-label="Sort statements"
               data-ma-action="sort-stim" data-ma-stim="%s"
               data-ma-sort-dir="none">\u21C5</button>
     </th>', stmt_label, stim)

  brand_ths <- character(0)

  for (i in seq_along(brand_codes)) {
    bc <- brand_codes[i]; bn <- brand_names[i]
    if (!is.null(focal) && bc == focal) {
      # Focal column — leftmost data column, accent colour; FOCAL badge sits above brand name
      brand_ths <- c(brand_ths, sprintf(
        '<th class="ct-th ct-data-col ma-ct-th-brand ma-ct-th-focal" data-ma-brand="%s" data-sort-col="%s">
           <div class="ct-header-text"><span class="ma-focal-badge">FOCAL</span><span class="ma-brand-name">%s</span></div>
           <button type="button" class="ct-sort-indicator ma-sort-btn"
                   aria-label="Sort by %s"
                   data-ma-action="sort-brand" data-ma-brand="%s" data-ma-stim="%s"
                   data-ma-sort-dir="none">\u21C5</button>
         </th>',
        .ma_esc(bc), .ma_esc(bc), .ma_esc(bn),
        .ma_esc(bn), .ma_esc(bc), stim))

      # Immediately after focal: cat-avg column
      brand_ths <- c(brand_ths, sprintf(
        '<th class="ct-th ct-data-col ma-ct-th-catavg" data-ma-brand="__avg__" data-sort-col="avg">
           <div class="ct-header-text">Cat avg</div>
           <button type="button" class="ct-sort-indicator ma-sort-btn"
                   aria-label="Sort by category average"
                   data-ma-action="sort-avg" data-ma-stim="%s"
                   data-ma-sort-dir="none">\u21C5</button>
         </th>', stim))
    } else {
      brand_ths <- c(brand_ths, sprintf(
        '<th class="ct-th ct-data-col ma-ct-th-brand" data-ma-brand="%s" data-sort-col="%s">
           <div class="ct-header-text">%s</div>
           <button type="button" class="ct-sort-indicator ma-sort-btn"
                   aria-label="Sort by %s"
                   data-ma-action="sort-brand" data-ma-brand="%s" data-ma-stim="%s"
                   data-ma-sort-dir="none">\u21C5</button>
         </th>',
        .ma_esc(bc), .ma_esc(bc), .ma_esc(bn),
        .ma_esc(bn), .ma_esc(bc), stim))
    }
  }

  paste0('<thead><tr>', stmt_th,
         paste(brand_ths, collapse = ""),
         '</tr></thead>')
}


# ==============================================================================
# INTERNAL: ROWS — one per stimulus
# ==============================================================================

.ma_table_rows <- function(block, brand_codes, focal, stim, pd) {
  cells_by_stim <- split(block$cells,
                         vapply(block$cells, function(c) c$stim_code,
                                character(1)))

  codes   <- block$codes
  labels  <- block$labels
  stim_avg <- block$stim_avg
  ci_lower <- block$stim_ci_lower
  ci_upper <- block$stim_ci_upper

  rows <- vapply(seq_along(codes), function(i) {
    code <- codes[i]
    lbl  <- labels[i]
    cells <- cells_by_stim[[code]] %||% list()
    .ma_row_html(code, lbl,
                 avg_pct   = stim_avg[i],
                 ci_lower  = ci_lower[i],
                 ci_upper  = ci_upper[i],
                 cells     = cells,
                 brand_codes = brand_codes,
                 focal       = focal,
                 stim        = stim)
  }, character(1))

  paste0(.ma_base_row(block, brand_codes, focal),
         paste(rows, collapse = ""))
}


.ma_row_html <- function(code, label, avg_pct, ci_lower, ci_upper,
                         cells, brand_codes, focal, stim, base_n = NULL) {
  cells_by_brand <- stats::setNames(
    vector("list", length(brand_codes)), brand_codes)
  for (c in cells) {
    cells_by_brand[[c$brand_code]] <- c
  }

  # Build data cells in column order
  cells_html <- character(0)
  for (b in brand_codes) {
    c <- cells_by_brand[[b]]
    is_focal <- !is.null(focal) && b == focal
    focal_cls <- if (is_focal) " ma-td-focal" else ""
    if (is.null(c)) {
      cells_html <- c(cells_html,
        sprintf('<td class="ct-td ct-data-col ct-na%s">&mdash;</td>',
                focal_cls))
    } else {
      cells_html <- c(cells_html, .ma_cell_html(c, focal_cls, stim))
    }
    # After focal column → inject cat-avg cell
    if (is_focal) {
      cells_html <- c(cells_html, .ma_catavg_cell_html(avg_pct, ci_lower,
                                                        ci_upper, base_n))
    }
  }

  # Sort attrs on row
  sort_attrs <- paste(vapply(brand_codes, function(b) {
    c <- cells_by_brand[[b]]
    v <- if (is.null(c)) NA_real_ else as.numeric(c$pct_total)
    sprintf(' data-ma-sort-%s="%s"', .ma_esc(b),
            if (is.na(v)) "" else sprintf("%.6f", v))
  }, character(1)), collapse = "")
  sort_attrs <- paste0(sort_attrs,
    sprintf(' data-ma-sort-avg="%s"',
            if (is.na(avg_pct)) "" else sprintf("%.6f", avg_pct)))

  sprintf(
    '<tr class="ct-row ma-row" data-ma-stim="%s" data-ma-sort-stim="%s"%s>
       <td class="ct-td ct-label-col ma-row-label" title="%s">
         <label class="ma-row-toggle"><input type="checkbox" class="ma-row-active-cb" data-ma-stim="%s" data-ma-stim-code="%s" checked>
           <span class="ma-row-label-text">%s</span>
         </label>
       </td>
       %s
     </tr>',
    .ma_esc(code), .ma_esc(tolower(label)),
    sort_attrs,
    .ma_esc(label),
    stim, .ma_esc(code),
    .ma_esc(label),
    paste(cells_html, collapse = ""))
}


# ------------------------------------------------------------------
# Per-cell — primary pct + optional count + CI band + sig arrow
# ------------------------------------------------------------------

.ma_cell_html <- function(cell, focal_cls = "", stim) {
  pct_total <- cell$pct_total
  pct_aware <- cell$pct_aware
  diff      <- cell$diff_vs_avg
  n_total   <- cell$n_total
  n_aware   <- cell$n_aware
  ci_band   <- cell$ci_band %||% "na"
  sig       <- cell$sig_vs_avg %||% "na"

  if (is.null(pct_total) || is.na(pct_total)) {
    return(sprintf('<td class="ct-td ct-data-col ct-na%s">&mdash;</td>',
                   focal_cls))
  }

  ci_cls <- switch(ci_band, above = " ma-ci-above",
                           within = " ma-ci-within",
                           below  = " ma-ci-below",
                           "")
  heatmap_colour <- .ma_diff_heatmap(diff, 40)  # row-level normalised
  pct_display <- sprintf("%.0f%%", pct_total)
  sig_badge   <- .ma_sig_badge(sig)
  count_display <- if (!is.null(n_total) && !is.na(n_total))
    sprintf("n=%d", as.integer(n_total)) else ""

  sprintf(
    '<td class="ct-td ct-data-col ma-heatmap-cell%s%s" data-ma-brand="%s" data-ma-heatmap="%s" data-ma-pct="%.1f" data-ma-pct-aware="%s" data-ma-diff="%.1f" data-ma-n-total="%s" data-ma-n-aware="%s" data-ma-ci-band="%s" data-sort-val="%.6f">
       <span class="ct-val ma-pct-primary">%s</span>%s
       <span class="ct-freq ma-n-primary">%s</span>
     </td>',
    focal_cls, ci_cls,
    .ma_esc(cell$brand_code),
    heatmap_colour,
    pct_total,
    if (is.na(pct_aware)) "" else sprintf("%.1f", pct_aware),
    diff,
    if (is.na(n_total)) "" else as.integer(n_total),
    if (is.na(n_aware)) "" else as.integer(n_aware),
    ci_band,
    pct_total,
    pct_display, sig_badge, count_display)
}


.ma_catavg_cell_html <- function(avg_pct, ci_lower, ci_upper, base_n) {
  if (is.null(avg_pct) || is.na(avg_pct)) {
    return('<td class="ct-td ct-data-col ma-td-catavg ct-na" data-ma-brand="__avg__">&mdash;</td>')
  }
  # Funnel-style CI mini-bar (matches .ma-ci-bar-wrap used on Metrics tab and
  # the Category Buying DoP category-average row). Values are % on a 0-100 scale.
  has_ci <- !is.na(ci_lower) && !is.na(ci_upper)
  ci_text <- if (has_ci) sprintf("%.0f\u2013%.0f", ci_lower, ci_upper) else ""
  ci_bar <- ""
  if (has_ci) {
    safe_max  <- 100
    lo        <- max(0, min(safe_max, ci_lower))
    hi        <- max(lo, min(safe_max, ci_upper))
    fill_left <- max(0, min(94, 100 * lo / safe_max))
    fill_w    <- max(4, min(100 - fill_left, 100 * (hi - lo) / safe_max))
    mean_pct  <- max(1, min(99, 100 * avg_pct / safe_max))
    lo_disp   <- sprintf("%.0f%%", lo)
    hi_disp   <- sprintf("%.0f%%", hi)
    ci_bar <- paste0(
      sprintf('<div class="ma-ci-bar-wrap" title="95%% CI: %s \u2013 %s">', lo_disp, hi_disp),
      sprintf('<div class="ma-ci-bar-range" style="left:%.1f%%;width:%.1f%%;"></div>', fill_left, fill_w),
      sprintf('<div class="ma-ci-bar-tick" style="left:%.1f%%"></div>', mean_pct),
      '</div>',
      sprintf('<div class="ma-ci-limits"><span>%s</span><span>%s</span></div>', lo_disp, hi_disp))
  }
  sprintf(
    '<td class="ct-td ct-data-col ma-td-catavg ma-td-catavg-ci" data-ma-brand="__avg__" data-ma-ci-lower="%s" data-ma-ci-upper="%s" data-sort-val="%.6f" title="95%% CI: %s">
       <span class="ct-val">%.0f%%</span>%s
     </td>',
    if (is.na(ci_lower)) "" else sprintf("%.3f", ci_lower),
    if (is.na(ci_upper)) "" else sprintf("%.3f", ci_upper),
    avg_pct, ci_text,
    avg_pct, ci_bar)
}


# ==============================================================================
# INTERNAL: FOOTER (brand column averages)
# ==============================================================================

.ma_table_footer <- function(block, brand_codes, focal) {
  brand_avg <- stats::setNames(block$brand_avg, block$brand_codes)
  row_cells <- character(0)

  for (b in brand_codes) {
    is_focal <- !is.null(focal) && b == focal
    focal_cls <- if (is_focal) " ma-td-focal" else ""
    v <- brand_avg[[b]]
    if (is.na(v)) {
      row_cells <- c(row_cells,
        sprintf('<td class="ct-td ct-data-col ct-na%s" data-ma-brand="%s">&mdash;</td>',
                focal_cls, .ma_esc(b)))
    } else {
      row_cells <- c(row_cells, sprintf(
        '<td class="ct-td ct-data-col ma-td-brand-avg%s" data-ma-brand="%s"><span class="ct-val">%.0f%%</span></td>',
        focal_cls, .ma_esc(b), v))
    }
    if (is_focal) {
      row_cells <- c(row_cells, sprintf(
        '<td class="ct-td ct-data-col ma-td-catavg" data-ma-brand="__avg__"><span class="ct-val">%.0f%%</span></td>',
        mean(brand_avg, na.rm = TRUE)))
    }
  }

  paste0(
    '<tr class="ct-row ma-row-summary" data-locked="1">',
    '<td class="ct-td ct-label-col"><em>Brand average</em></td>',
    paste(row_cells, collapse = ""),
    '</tr>'
  )
}


# ==============================================================================
# INTERNAL: BASE ROW — shows base n per brand at top of tbody
# ==============================================================================

.ma_base_row <- function(block, brand_codes, focal) {
  n_total <- block$n_total %||% NA
  awareness_pcts  <- block$awareness_by_brand
  block_codes     <- block$brand_codes %||% character(0)
  n_aware_by_code <- if (!is.null(awareness_pcts) && length(block_codes) > 0) {
    base <- if (is.null(n_total) || is.na(n_total)) 0 else n_total
    ap_num <- unlist(awareness_pcts)  # convert named list → named numeric vector
    round(ap_num * base / 100)
  } else NULL

  n_total_display <- if (is.null(n_total) || is.na(n_total)) "&mdash;"
                     else sprintf("n=%d", as.integer(n_total))

  cells <- character(0)
  for (b in brand_codes) {
    is_focal  <- !is.null(focal) && b == focal
    focal_cls <- if (is_focal) " ma-td-focal" else ""
    n_total_attr  <- if (is.null(n_total) || is.na(n_total)) "" else as.integer(n_total)
    n_aware       <- if (!is.null(n_aware_by_code)) unname(n_aware_by_code[b]) else NA_real_
    n_aware_attr  <- if (is.na(n_aware)) "" else as.integer(n_aware)

    cells <- c(cells, sprintf(
      '<td class="ct-td ct-data-col ma-base-n%s" data-ma-brand="%s" data-ma-n-total="%s" data-ma-n-aware="%s"><span class="ma-base-val">%s</span></td>',
      focal_cls, .ma_esc(b), n_total_attr, n_aware_attr, n_total_display))

    if (is_focal) {
      cells <- c(cells,
        '<td class="ct-td ct-data-col ma-td-catavg ma-base-n" data-ma-brand="__avg__">&mdash;</td>')
    }
  }

  paste0(
    '<tr class="ma-row-base" data-locked="1">',
    '<td class="ct-td ct-label-col"><em>Base</em></td>',
    paste(cells, collapse = ""),
    '</tr>'
  )
}


# ==============================================================================
# INTERNAL: HEATMAP (diverging — red/white/blue vs cat avg)
# ==============================================================================

.ma_diff_heatmap <- function(diff, max_abs_diff) {
  if (is.na(diff) || max_abs_diff <= 0) return("")
  frac <- min(1, max(0, abs(diff) / max_abs_diff))
  alpha <- 0.08 + frac * 0.55
  colour <- if (diff >= 0) sprintf("rgba(37,99,171,%.3f)", alpha)
            else           sprintf("rgba(192,57,43,%.3f)", alpha)
  colour
}


.ma_sig_badge <- function(direction) {
  if (identical(direction, "higher"))
    return('<span class="ma-sig ma-sig-up" title="Sig higher than category average (p&lt;0.05)">\u2191</span>')
  if (identical(direction, "lower"))
    return('<span class="ma-sig ma-sig-down" title="Sig lower than category average (p&lt;0.05)">\u2193</span>')
  return("")
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!exists(".ma_esc", mode = "function")) {
  .ma_esc <- function(x) {
    if (is.null(x)) return("")
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub("\"", "&quot;", x, fixed = TRUE)
    x
  }
}
