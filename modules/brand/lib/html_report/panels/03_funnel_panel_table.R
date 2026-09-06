# ==============================================================================
# BRAND MODULE - FUNNEL PANEL TABLE (tabs-parity polish)
# ==============================================================================
# Uses the tabs module's ct-* CSS classes verbatim so the funnel table
# looks identical to a tabs crosstab card (dark navy header, red-bold
# small-base warning, column letters, sort indicators in header).
#
# Row order (locked: sort only shuffles competitor rows):
#   1. Base (n=) per stage, with ct-low-base red/bold when < 30
#   2. Focal brand                  (left-border accent)
#   3. Category average             (italic, muted band)
#   4+ Competitors                  (sortable A-Z / Z-A / by any stage)
#
# Per-column heatmap shading scales 0.08..0.65 (wider than the earlier
# 0.06..0.40 range so the gradient is clearly visible). Controlled by
# the panel-level .fn-heatmap-off class which blanks cell backgrounds.
# Sig ▲/▼ vs category average renders inline where present.
# ==============================================================================


#' Build the funnel table section (table + popover templates).
#' The Heatmap toggle lives on the controls bar above, not here.
#'
#' @param pd Panel data from build_funnel_panel_data().
#' @param focal_colour Character. Hex colour for focal highlighting.
#' @return Character string (section element).
#' @export
build_funnel_table_section <- function(pd, focal_colour = "#1A5276") {
  table <- pd$table
  if (is.null(table) || length(table$stage_keys) == 0 ||
      length(table$brand_codes) == 0) return("")

  stage_keys <- table$stage_keys
  stage_labels <- table$stage_labels
  brand_codes <- table$brand_codes
  brand_names <- table$brand_names
  focal <- pd$meta$focal_brand_code
  stage_defs <- pd$meta$stage_definitions %||% character(0)
  cells_by_stage <- .fn_cells_by_stage(table$cells, stage_keys)
  col_max <- .fn_per_column_max(cells_by_stage, stage_keys)
  # Nested chain percentage, the default view. Derived here rather than in
  # the engine: the cumulative-chain count is already in the payload and
  # n_weighted is the same denominator pct_absolute uses, so the view needs
  # no new engine number. See .fn_chain_pct().
  n_weighted <- as.numeric(pd$meta$n_weighted %||% NA_real_)
  chain_avg  <- .fn_chain_stats_by_stage(table$cells, stage_keys, brand_codes,
                                         n_weighted)

  paste0(
    '<section class="fn-section fn-table-section">',
    '<div class="fn-table-wrap">',
    '<table class="ct-table fn-ct-table fn-table" data-fn-table="1">',
    .fn_table_header(stage_labels, stage_keys),
    '<tbody>',
    .fn_row_base(stage_keys, table$cells, brand_codes,
                 n_total = pd$meta$n_unweighted),
    .fn_row_focal(stage_keys, focal, brand_names[match(focal, brand_codes)],
                  table$cells, focal_colour, col_max, n_weighted),
    .fn_row_avg_all(stage_keys, table$avg_all_brands, col_max, chain_avg),
    .fn_rows_competitors(stage_keys, brand_codes, brand_names, focal,
                         table$cells, col_max, n_weighted),
    '</tbody></table></div>',
    '</section>'
  )
}


#' Nested chain percentage for one cell: cumulative-chain count over the
#' weighted respondent total.
#'
#' \code{base_chain_filtered} counts the respondents who passed this stage
#' and every earlier one; \code{n_weighted} is \code{sum(weights)}, which is
#' the denominator \code{pct_weighted} already uses. So at the first stage
#' this returns the same figure as \code{pct_absolute}, and every later
#' stage sits at or below the one before it.
#' @keywords internal
.fn_chain_pct <- function(cell, n_weighted) {
  if (is.null(cell)) return(NA_real_)
  chain <- suppressWarnings(as.numeric(cell$base_chain_filtered %||% NA_real_))
  if (!is.finite(chain) || !is.finite(n_weighted) || n_weighted <= 0) {
    return(NA_real_)
  }
  chain / n_weighted
}


#' Category-average chain statistics per stage.
#'
#' The mean follows \code{.avg_all_brands_row()} in 03c_funnel_panel_data.R:
#' apply the view's formula per brand, then average across brands. Not the
#' ratio of the summed counts.
#'
#' The CI bounds and the column maximum come with it, because the cat-avg
#' cell draws a range bar and its labels underneath the figure. Rendering
#' the figure at the chain base and the bar at the absolute base would put
#' a mean of six percent inside a band of eight to seventeen, which is what
#' the first cut of this stage did. Mirrors updateAvgRowRangeBars() in
#' brand_funnel_panel.js, which redraws the same bar on every toggle.
#' @keywords internal
.fn_chain_stats_by_stage <- function(cells, stage_keys, brand_codes,
                                     n_weighted) {
  out <- list()
  for (k in stage_keys) {
    vals <- vapply(cells, function(c) {
      if (!identical(c$stage_key, k) || !(c$brand_code %in% brand_codes)) {
        return(NA_real_)
      }
      .fn_chain_pct(c, n_weighted)
    }, numeric(1))
    vals <- vals[is.finite(vals)]
    if (length(vals) == 0) {
      out[[k]] <- list(mean = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_,
                       col_max = NA_real_)
      next
    }
    m <- mean(vals)
    lo <- NA_real_; hi <- NA_real_
    if (length(vals) >= 2) {
      se <- stats::sd(vals) / sqrt(length(vals))
      lo <- m - 1.96 * se
      hi <- m + 1.96 * se
    }
    out[[k]] <- list(mean = m, ci_lo = lo, ci_hi = hi, col_max = max(vals))
  }
  out
}


# ==============================================================================
# INTERNAL: HEADER (matches tabs' ct-th pattern)
# ==============================================================================

.fn_table_header <- function(stage_labels, stage_keys) {
  # Brand column header (sortable A-Z / Z-A)
  brand_th <- paste0(
    '<th class="ct-th ct-label-col" data-sort-col="brand">',
      '<div class="ct-header-text">Brand</div>',
      '<button type="button" class="ct-sort-indicator fn-sort-btn"
              aria-label="Sort brands alphabetically"
              data-fn-action="sort-brand"
              data-fn-sort-dir="asc">\u21C5</button>',
    '</th>')

  # Stage column headers: sort button only (? definitions moved to About section)
  stage_ths <- paste(vapply(seq_along(stage_keys), function(i) {
    key <- .fn_esc(stage_keys[i])
    label <- .fn_esc(stage_labels[i])
    sprintf(
      '<th class="ct-th ct-data-col fn-ct-th-stage" data-fn-stage="%s" data-sort-col="%s">
         <div class="ct-header-text">%s</div>
         <button type="button" class="ct-sort-indicator fn-sort-btn"
                 aria-label="Sort by %s"
                 data-fn-action="sort-stage" data-fn-stage="%s"
                 data-fn-sort-dir="none">\u21C5</button>
       </th>',
      key, key, label, label, key)
  }, character(1)), collapse = "")

  paste0('<thead><tr>', brand_th, stage_ths, '</tr></thead>')
}


# ==============================================================================
# INTERNAL: ROWS
# ==============================================================================

.fn_row_base <- function(stage_keys, cells, brand_codes, n_total = NULL) {
  # Show the total respondent base for all stages (n_total = all focal
  # respondents). This is the correct denominator for "% of total" display.
  # Fall back to max per-brand base only when n_total is not available.
  base_by_stage <- if (!is.null(n_total) && is.finite(n_total) && n_total > 0) {
    stats::setNames(rep(as.numeric(n_total), length(stage_keys)), stage_keys)
  } else {
    vapply(stage_keys, function(k) {
      bs <- vapply(cells, function(c) {
        if (!identical(c$stage_key, k) || !(c$brand_code %in% brand_codes)) {
          return(NA_real_)
        }
        as.numeric(c$base_unweighted %||% NA_real_)
      }, numeric(1))
      bs <- bs[!is.na(bs)]
      if (length(bs) == 0) NA_real_ else max(bs, na.rm = TRUE)
    }, numeric(1))
  }

  cells_html <- vapply(seq_along(stage_keys), function(i) {
    v <- base_by_stage[i]
    if (!is.finite(v)) {
      return('<td class="ct-td ct-data-col ct-na">&ndash;</td>')
    }
    warn <- v < .FN_SMALL_BASE
    sprintf('<td class="ct-td ct-data-col"><span class="%s">n=%d%s</span></td>',
            if (warn) "ct-low-base" else "ct-base-n",
            as.integer(round(v)),
            if (warn) " \u26A0" else "")
  }, character(1))

  paste0(
    '<tr class="ct-row ct-row-base fn-row-base" data-locked="1">',
    '<td class="ct-td ct-label-col">Base (n=)</td>',
    paste(cells_html, collapse = ""),
    '</tr>'
  )
}


.fn_row_focal <- function(stage_keys, focal, focal_name, cells, focal_colour,
                          col_max, n_weighted = NA_real_) {
  if (is.null(focal) || !nzchar(focal)) return("")
  display <- focal_name %||% focal
  cells_for <- .fn_cells_for_brand(cells, focal)
  row_attrs <- sprintf('data-fn-brand="%s" data-locked="1" style="--fn-row-accent:%s;"',
                       .fn_esc(focal), focal_colour)
  paste0(
    sprintf('<tr class="ct-row fn-row-focal" %s>', row_attrs),
    sprintf('<td class="ct-td ct-label-col fn-row-focal-label">%s <span class="fn-focal-badge">FOCAL</span></td>',
            .fn_esc(display)),
    .fn_cells_html(stage_keys, cells_for, col_max, n_weighted),
    '</tr>'
  )
}


.fn_row_avg_all <- function(stage_keys, avg_rows, col_max, chain_avg = NULL) {
  if (is.null(avg_rows) || length(avg_rows) == 0) return("")
  by_key <- stats::setNames(avg_rows,
    vapply(avg_rows, function(r) r$stage_key, character(1)))
  cells <- vapply(stage_keys, function(k) {
    r <- by_key[[k]]
    if (is.null(r)) return('<td class="ct-td ct-data-col ct-na">&ndash;</td>')
    pct_abs <- r$pct_absolute %||% NA_real_
    if (is.null(pct_abs) || is.na(pct_abs))
      return('<td class="ct-td ct-data-col ct-na fn-td-avg">&ndash;</td>')
    # All four base values are surfaced as data attributes so applyPctMode()
    # in brand_funnel_panel.js can reflow this cell when the user toggles
    # between the nested funnel / each stage on its own / % previous /
    # % aware. Sentinel brand code "__avg__" so the cat-avg row is included
    # by the .ct-td[data-fn-brand][data-fn-stage] selector without colliding
    # with any real brand code.
    pct_nes <- r$pct_nested %||% pct_abs
    pct_aw  <- r$pct_aware  %||% pct_abs
    # The whole cell is drawn at the DEFAULT view (the nested chain): the
    # figure, the range bar behind it and the lo/hi labels under it. Drawing
    # the figure at one base and the bar at another put a mean of 6% inside
    # a band of 8% to 17% on the fixture. updateAvgRowRangeBars() in
    # brand_funnel_panel.js redraws all three on every toggle, including once
    # at init, so this only has to be right for the file as written.
    cs      <- if (is.null(chain_avg)) NULL else chain_avg[[k]]
    pct_chn <- if (is.null(cs)) NA_real_ else cs$mean %||% NA_real_
    use_chain <- is.finite(pct_chn %||% NA_real_)
    if (!use_chain) pct_chn <- pct_abs
    ci_lo   <- if (use_chain) cs$ci_lo %||% NA_real_ else r$ci_lo %||% NA_real_
    ci_hi   <- if (use_chain) cs$ci_hi %||% NA_real_ else r$ci_hi %||% NA_real_
    safe_max <- if (use_chain && is.finite(cs$col_max %||% NA_real_))
      max(0.01, as.numeric(cs$col_max))
    else max(0.01, as.numeric(col_max[[k]] %||% 1), na.rm = TRUE)
    disp    <- sprintf("%.0f%%", 100 * pct_chn)
    lo_disp <- if (is.finite(ci_lo)) sprintf("%.0f%%", 100 * ci_lo) else ""
    hi_disp <- if (is.finite(ci_hi)) sprintf("%.0f%%", 100 * ci_hi) else ""
    fill_left <- if (nzchar(lo_disp)) max(0, min(94, 100 * ci_lo / safe_max)) else 0
    fill_w    <- if (nzchar(lo_disp) && nzchar(hi_disp))
                  max(4, min(100 - fill_left, 100 * (ci_hi - ci_lo) / safe_max)) else 0
    mean_pct  <- max(1, min(99, 100 * pct_chn / safe_max))
    ci_bar <- if (nzchar(lo_disp) && nzchar(hi_disp)) paste0(
      sprintf('<div class="ma-ci-bar-wrap" title="95%% CI: %s \u2013 %s">', lo_disp, hi_disp),
      sprintf('<div class="ma-ci-bar-range" style="left:%.1f%%;width:%.1f%%;"></div>', fill_left, fill_w),
      sprintf('<div class="ma-ci-bar-tick" style="left:%.1f%%"></div>', mean_pct),
      '</div>',
      sprintf('<div class="ma-ci-limits"><span>%s</span><span>%s</span></div>', lo_disp, hi_disp)
    ) else ""
    sprintf(
      '<td class="ct-td ct-data-col fn-td-avg fn-td-avg-ci"
           data-fn-stage="%s" data-fn-brand="__avg__"
           data-fn-pct-abs="%.6f" data-fn-pct-nes="%.6f" data-fn-pct-aw="%.6f"
           data-fn-pct-chn="%.6f"
           data-sort-val="%.6f"><span class="ct-val fn-pct-primary">%s</span>%s</td>',
      .fn_esc(k), pct_abs, pct_nes, pct_aw, pct_chn, pct_abs, disp, ci_bar)
  }, character(1))
  paste0(
    '<tr class="ct-row fn-row-avg-all" data-locked="1">',
    '<td class="ct-td ct-label-col"><em>Category average</em></td>',
    paste(cells, collapse = ""),
    '</tr>'
  )
}


.fn_rows_competitors <- function(stage_keys, brand_codes, brand_names,
                                 focal, cells, col_max, n_weighted = NA_real_) {
  non_focal_idx <- which(brand_codes != focal)
  if (length(non_focal_idx) == 0) return("")
  order_idx <- non_focal_idx[order(tolower(brand_names[non_focal_idx]))]
  rows <- vapply(order_idx, function(i) {
    b <- brand_codes[i]; nm <- brand_names[i]
    cells_for <- .fn_cells_for_brand(cells, b)
    sort_attrs <- .fn_brand_sort_attrs(cells_for, stage_keys, nm, n_weighted)
    paste0(
      sprintf('<tr class="ct-row fn-row-competitor" data-fn-brand="%s"%s>',
              .fn_esc(b), sort_attrs),
      sprintf('<td class="ct-td ct-label-col">%s</td>', .fn_esc(nm)),
      .fn_cells_html(stage_keys, cells_for, col_max, n_weighted),
      '</tr>'
    )
  }, character(1))
  paste(rows, collapse = "")
}


.fn_brand_sort_attrs <- function(cells_for, stage_keys, brand_name,
                                 n_weighted = NA_real_) {
  # Emit one sort attribute per stage per base mode so setSort() in
  # brand_funnel_panel.js can pick the right value when the user sorts
  # while a non-default base is active. Without the per-mode attributes
  # the sort silently kept ordering by % total regardless of the active
  # toggle, so switching to % aware and re-sorting by stage produced the
  # same brand order as % total.
  #   data-fn-sort-<k>      -> pct_absolute (legacy / default fallback)
  #   data-fn-sort-<k>-abs  -> pct_absolute
  #   data-fn-sort-<k>-nes  -> pct_nested
  #   data-fn-sort-<k>-aw   -> pct_aware
  #   data-fn-sort-<k>-chn  -> nested chain over the weighted total
  fmt <- function(v) if (is.na(v)) "" else sprintf("%.6f", v)
  parts <- vapply(stage_keys, function(k) {
    cell <- cells_for[[k]] %||% list()
    abs_v <- cell$pct_absolute %||% NA_real_
    nes_v <- cell$pct_nested   %||% abs_v
    aw_v  <- cell$pct_aware    %||% abs_v
    chn_v <- .fn_chain_pct(cells_for[[k]], n_weighted)
    if (!is.finite(chn_v)) chn_v <- abs_v
    sprintf(paste0(
        ' data-fn-sort-%s="%s"',
        ' data-fn-sort-%s-abs="%s"',
        ' data-fn-sort-%s-nes="%s"',
        ' data-fn-sort-%s-aw="%s"',
        ' data-fn-sort-%s-chn="%s"'),
      .fn_esc(k), fmt(abs_v),
      .fn_esc(k), fmt(abs_v),
      .fn_esc(k), fmt(nes_v),
      .fn_esc(k), fmt(aw_v),
      .fn_esc(k), fmt(chn_v))
  }, character(1))
  paste0(
    sprintf(' data-fn-sort-brand="%s"', .fn_esc(tolower(brand_name))),
    paste(parts, collapse = ""))
}


# ==============================================================================
# INTERNAL: CELL RENDERING
# ==============================================================================

.fn_cells_for_brand <- function(cells, brand_code) {
  out <- list()
  for (c in cells) {
    if (identical(c$brand_code, brand_code)) out[[c$stage_key]] <- c
  }
  out
}


.fn_cells_by_stage <- function(cells, stage_keys) {
  out <- stats::setNames(vector("list", length(stage_keys)), stage_keys)
  for (c in cells) {
    k <- c$stage_key
    out[[k]] <- c(out[[k]], list(c))
  }
  out
}


.fn_per_column_max <- function(cells_by_stage, stage_keys) {
  out <- stats::setNames(vector("list", length(stage_keys)), stage_keys)
  for (k in stage_keys) {
    vals <- vapply(cells_by_stage[[k]] %||% list(), function(c) {
      v <- c$pct_absolute %||% NA_real_
      if (is.na(v) || !is.finite(v)) NA_real_ else v
    }, numeric(1))
    vals <- vals[!is.na(vals) & vals > 0]
    out[[k]] <- if (length(vals) == 0) 1 else max(vals)
  }
  out
}


.fn_cells_html <- function(stage_keys, cells_by_stage_for_brand, col_max,
                           n_weighted = NA_real_) {
  vals <- vapply(stage_keys, function(k) {
    c <- cells_by_stage_for_brand[[k]]
    if (is.null(c)) return('<td class="ct-td ct-data-col ct-na">&ndash;</td>')
    .fn_cell_html(c$pct_absolute, c$pct_nested, c$pct_aware,
                  c$base_weighted, c$base_unweighted,
                  k, c$brand_code,
                  col_max = col_max[[k]],
                  sig_vs_avg = c$sig_vs_avg %||% "na",
                  row_class = "",
                  pct_chain = .fn_chain_pct(c, n_weighted),
                  base_chain_u = c$base_chain_unweighted %||% NA_real_)
  }, character(1))
  paste(vals, collapse = "")
}


.fn_cell_html <- function(pct_absolute, pct_nested, pct_aware, base_w, base_u,
                          stage_key, brand_code, col_max, sig_vs_avg,
                          row_class = "", pct_chain = NA_real_,
                          base_chain_u = NA_real_) {
  if (is.null(pct_absolute) || is.na(pct_absolute)) {
    return(sprintf('<td class="ct-td ct-data-col ct-na %s">&ndash;</td>', row_class))
  }
  heatmap_data <- .fn_per_column_heatmap_data(pct_absolute, col_max)
  abs_display    <- sprintf("%.0f%%", 100 * pct_absolute)
  nested_display <- if (is.null(pct_nested) || is.na(pct_nested)) abs_display
                    else sprintf("%.0f%%", 100 * pct_nested)
  # The nested chain is the default view, so it is what the file says
  # before any script runs. Falls back to the absolute figure when the
  # chain count is missing, which is what every other view does too.
  pct_chain_val <- if (is.null(pct_chain) || !is.finite(pct_chain))
                     pct_absolute else pct_chain
  default_display <- sprintf("%.0f%%", 100 * pct_chain_val)
  # Count under the cell follows the view: the nested view counts the
  # respondents still in the chain, not the stage's own raw count.
  base_display <- if (is.finite(base_chain_u %||% NA_real_))
                    sprintf("n=%d", as.integer(base_chain_u))
                  else if (is.finite(base_u %||% NA_real_))
                    sprintf("n=%d", as.integer(base_u))
                  else ""

  is_warn <- is.finite(base_u %||% NA_real_) &&
             !is.na(base_u) && as.numeric(base_u) < .FN_SMALL_BASE
  dim_cls <- if (is_warn) " ct-low-base-dim" else ""
  # No significance mark in the default (nested) view. The engine's test is
  # run on each stage's own base, so its verdict is about the figure the
  # "Each stage on its own" view shows, not about the chain. The direction
  # rides on the cell as an attribute and brand_funnel_panel.js writes the
  # badge back when the reader switches to a view the test belongs to.
  # It is left out of the markup rather than hidden with CSS: the pin and
  # PNG capture drops a display:none it reads as a default value, so a
  # hidden badge would reappear on the exported card.
  sig_attr <- sprintf(' data-fn-sig-avg="%s"', .fn_esc(sig_vs_avg %||% "na"))
  sig_badge <- ""
  pct_aw_val <- if (is.null(pct_aware) || is.na(pct_aware)) pct_absolute else pct_aware

  sprintf(
    '<td class="ct-td ct-data-col ct-heatmap-cell%s %s" data-heatmap="%s"
         data-fn-stage="%s" data-fn-brand="%s"
         data-fn-pct-abs="%.6f" data-fn-pct-nes="%.6f" data-fn-pct-aw="%.6f"
         data-fn-pct-chn="%.6f"
         data-fn-base="%s"%s
         data-sort-val="%.6f">
       <span class="ct-val fn-pct-primary">%s</span>%s
       <span class="ct-freq fn-pct-count">%s</span>
     </td>',
    dim_cls, row_class, heatmap_data,
    .fn_esc(stage_key), .fn_esc(brand_code),
    pct_absolute, if (is.null(pct_nested) || is.na(pct_nested))
                    pct_absolute else pct_nested,
    pct_aw_val,
    pct_chain_val,
    if (is.finite(base_u %||% NA_real_)) as.integer(base_u) else "",
    sig_attr,
    pct_absolute,
    default_display, sig_badge, base_display
  )
}


#' In-cell ▲/▼ badge: brand sig higher / lower than category average.
#' @keywords internal
.fn_sig_badge <- function(direction) {
  switch(direction,
    higher = '<span class="ct-sig fn-sig-up" title="Higher than category average (p<0.05)">\u25B2</span>',
    lower  = '<span class="ct-sig fn-sig-down" title="Lower than category average (p<0.05)">\u25BC</span>',
    "")
}


#' Per-column heatmap rgba: wider alpha range (0.08 .. 0.65) so the
#' gradient reads clearly at desktop size. The JS applies this
#' data-heatmap value as inline background-color on report load; the
#' Heatmap toggle blanks it via a parent .fn-heatmap-off class.
#' @keywords internal
.fn_per_column_heatmap_data <- function(val, col_max) {
  if (is.na(val) || val <= 0) return("")
  denom <- if (is.null(col_max) || !is.finite(col_max) || col_max <= 0) 1
           else col_max
  frac <- min(1, max(0, val / denom))
  opacity <- 0.08 + frac * 0.57
  sprintf("rgba(37,99,171,%.3f)", opacity)
}


# ==============================================================================
# INTERNAL: POPOVER TEMPLATES + ADD INSIGHT STRIP
# ==============================================================================

.fn_popover_templates <- function(stage_keys, stage_labels, stage_defs) {
  parts <- vapply(seq_along(stage_keys), function(i) {
    k <- stage_keys[i]
    label <- stage_labels[i]
    body <- as.character(stage_defs[[k]] %||% "")
    if (!nzchar(trimws(body))) return("")
    sprintf(
      '<template class="fn-help-template" data-fn-stage="%s"
                data-fn-stage-label="%s">
         <div class="fn-help-popover-body">%s</div>
       </template>',
      .fn_esc(k), .fn_esc(label), .fn_esc(body))
  }, character(1))
  paste(parts[nzchar(parts)], collapse = "")
}


.fn_add_insight_strip <- function() {
  '<div class="fn-insight-strip fn-add-insight-strip">
     <button type="button" class="fn-add-insight-btn" data-fn-action="add-insight">
       + Add Insight
     </button>
     <div class="fn-insight-box" style="display:none;margin-top:8px;">
       <textarea class="fn-insight-textarea" rows="3"
         placeholder="Enter your insight here\u2026"
         style="width:100%;box-sizing:border-box;padding:8px;border:1px solid #cbd5e1;border-radius:6px;font-family:inherit;font-size:13px;color:#1e293b;resize:vertical;"></textarea>
     </div>
   </div>'
}


# ==============================================================================
# CONSTANTS + SHARED HELPERS
# ==============================================================================

.FN_SMALL_BASE <- 30


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!exists(".fn_esc", mode = "function")) {
  .fn_esc <- function(x) {
    if (is.null(x)) return("")
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub("\"", "&quot;", x, fixed = TRUE)
    x
  }
}
