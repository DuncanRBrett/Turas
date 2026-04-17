# ==============================================================================
# BRAND MODULE - FUNNEL PANEL TABLE (tabs-parity polish)
# ==============================================================================
# Uses the tabs module's ct-* CSS classes verbatim so the funnel table
# looks identical to a tabs crosstab card (dark navy header, red-bold
# small-base warning, column letters, sort indicators in header).
#
# Row order (locked — sort only shuffles competitor rows):
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

  paste0(
    '<section class="fn-section fn-table-section">',
    '<div class="fn-table-wrap">',
    '<table class="ct-table fn-ct-table fn-table" data-fn-table="1">',
    .fn_table_header(stage_labels, stage_keys),
    '<tbody>',
    .fn_row_base(stage_keys, table$cells, brand_codes),
    .fn_row_focal(stage_keys, focal, brand_names[match(focal, brand_codes)],
                  table$cells, focal_colour, col_max),
    .fn_row_avg_all(stage_keys, table$avg_all_brands, col_max),
    .fn_rows_competitors(stage_keys, brand_codes, brand_names, focal,
                         table$cells, col_max),
    '</tbody></table></div>',
    .fn_add_insight_strip(),
    '</section>'
  )
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

  # Stage column headers — sort button only (? definitions moved to About section)
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

.fn_row_base <- function(stage_keys, cells, brand_codes) {
  # Show the largest base across the visible brands (all brands are shown
  # by default; per-brand small-base warnings appear on the cells below).
  base_by_stage <- vapply(stage_keys, function(k) {
    bs <- vapply(cells, function(c) {
      if (!identical(c$stage_key, k) || !(c$brand_code %in% brand_codes)) {
        return(NA_real_)
      }
      as.numeric(c$base_unweighted %||% NA_real_)
    }, numeric(1))
    bs <- bs[!is.na(bs)]
    if (length(bs) == 0) NA_real_ else max(bs, na.rm = TRUE)
  }, numeric(1))

  cells_html <- vapply(seq_along(stage_keys), function(i) {
    v <- base_by_stage[i]
    if (!is.finite(v)) {
      return('<td class="ct-td ct-data-col ct-na">&mdash;</td>')
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
                          col_max) {
  if (is.null(focal) || !nzchar(focal)) return("")
  display <- focal_name %||% focal
  cells_for <- .fn_cells_for_brand(cells, focal)
  row_attrs <- sprintf('data-fn-brand="%s" data-locked="1" style="--fn-row-accent:%s;"',
                       .fn_esc(focal), focal_colour)
  paste0(
    sprintf('<tr class="ct-row fn-row-focal" %s>', row_attrs),
    sprintf('<td class="ct-td ct-label-col fn-row-focal-label">%s <span class="fn-focal-badge">FOCAL</span></td>',
            .fn_esc(display)),
    .fn_cells_html(stage_keys, cells_for, col_max),
    '</tr>'
  )
}


.fn_row_avg_all <- function(stage_keys, avg_rows, col_max) {
  if (is.null(avg_rows) || length(avg_rows) == 0) return("")
  by_key <- stats::setNames(avg_rows,
    vapply(avg_rows, function(r) r$stage_key, character(1)))
  cells <- vapply(stage_keys, function(k) {
    r <- by_key[[k]]
    if (is.null(r)) return('<td class="ct-td ct-data-col ct-na">&mdash;</td>')
    pct_abs <- r$pct_absolute %||% NA_real_
    pct_nes <- r$pct_nested %||% NA_real_
    .fn_cell_html(pct_abs, pct_nes, base_w = NA_real_, base_u = NA_real_,
                  stage_key = k, brand_code = "__avg_all__",
                  col_max = col_max[[k]], sig_vs_avg = "na",
                  row_class = "fn-td-avg")
  }, character(1))
  paste0(
    '<tr class="ct-row fn-row-avg-all" data-locked="1">',
    '<td class="ct-td ct-label-col"><em>Category average</em></td>',
    paste(cells, collapse = ""),
    '</tr>'
  )
}


.fn_rows_competitors <- function(stage_keys, brand_codes, brand_names,
                                 focal, cells, col_max) {
  non_focal_idx <- which(brand_codes != focal)
  if (length(non_focal_idx) == 0) return("")
  order_idx <- non_focal_idx[order(tolower(brand_names[non_focal_idx]))]
  rows <- vapply(order_idx, function(i) {
    b <- brand_codes[i]; nm <- brand_names[i]
    cells_for <- .fn_cells_for_brand(cells, b)
    sort_attrs <- .fn_brand_sort_attrs(cells_for, stage_keys, nm)
    paste0(
      sprintf('<tr class="ct-row fn-row-competitor" data-fn-brand="%s"%s>',
              .fn_esc(b), sort_attrs),
      sprintf('<td class="ct-td ct-label-col">%s</td>', .fn_esc(nm)),
      .fn_cells_html(stage_keys, cells_for, col_max),
      '</tr>'
    )
  }, character(1))
  paste(rows, collapse = "")
}


.fn_brand_sort_attrs <- function(cells_for, stage_keys, brand_name) {
  parts <- vapply(stage_keys, function(k) {
    v <- cells_for[[k]]$pct_absolute %||% NA_real_
    sprintf(' data-fn-sort-%s="%s"', .fn_esc(k),
            if (is.na(v)) "" else sprintf("%.6f", v))
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


.fn_cells_html <- function(stage_keys, cells_by_stage_for_brand, col_max) {
  vals <- vapply(stage_keys, function(k) {
    c <- cells_by_stage_for_brand[[k]]
    if (is.null(c)) return('<td class="ct-td ct-data-col ct-na">&mdash;</td>')
    .fn_cell_html(c$pct_absolute, c$pct_nested,
                  c$base_weighted, c$base_unweighted,
                  k, c$brand_code,
                  col_max = col_max[[k]],
                  sig_vs_avg = c$sig_vs_avg %||% "na",
                  row_class = "")
  }, character(1))
  paste(vals, collapse = "")
}


.fn_cell_html <- function(pct_absolute, pct_nested, base_w, base_u,
                          stage_key, brand_code, col_max, sig_vs_avg,
                          row_class = "") {
  if (is.null(pct_absolute) || is.na(pct_absolute)) {
    return(sprintf('<td class="ct-td ct-data-col ct-na %s">&mdash;</td>', row_class))
  }
  heatmap_data <- .fn_per_column_heatmap_data(pct_absolute, col_max)
  abs_display    <- sprintf("%.0f%%", 100 * pct_absolute)
  nested_display <- if (is.null(pct_nested) || is.na(pct_nested)) abs_display
                    else sprintf("%.0f%%", 100 * pct_nested)
  base_display <- if (is.finite(base_u %||% NA_real_))
                    sprintf("n=%d", as.integer(base_u))
                  else ""

  is_warn <- is.finite(base_u %||% NA_real_) &&
             !is.na(base_u) && as.numeric(base_u) < .FN_SMALL_BASE
  dim_cls <- if (is_warn) " ct-low-base-dim" else ""
  sig_badge <- .fn_sig_badge(sig_vs_avg)

  sprintf(
    '<td class="ct-td ct-data-col ct-heatmap-cell%s %s" data-heatmap="%s"
         data-fn-stage="%s" data-fn-brand="%s"
         data-fn-pct-abs="%.6f" data-fn-pct-nes="%.6f"
         data-fn-base="%s"
         data-sort-val="%.6f">
       <span class="ct-val fn-pct-primary">%s</span>%s
       <span class="ct-freq fn-pct-count">%s</span>
     </td>',
    dim_cls, row_class, heatmap_data,
    .fn_esc(stage_key), .fn_esc(brand_code),
    pct_absolute, if (is.null(pct_nested) || is.na(pct_nested))
                    pct_absolute else pct_nested,
    if (is.finite(base_u %||% NA_real_)) as.integer(base_u) else "",
    pct_absolute,
    abs_display, sig_badge, base_display
  )
}


#' In-cell ▲/▼ badge — brand sig higher / lower than category average.
#' @keywords internal
.fn_sig_badge <- function(direction) {
  switch(direction,
    higher = '<span class="ct-sig fn-sig-up" title="Higher than category average (p<0.05)">\u25B2</span>',
    lower  = '<span class="ct-sig fn-sig-down" title="Lower than category average (p<0.05)">\u25BC</span>',
    "")
}


#' Per-column heatmap rgba — wider alpha range (0.08 .. 0.65) so the
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
  '<div class="fn-add-insight-strip">
     <button type="button" class="fn-add-insight-btn" data-fn-action="add-insight">
       + Add Insight
     </button>
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
