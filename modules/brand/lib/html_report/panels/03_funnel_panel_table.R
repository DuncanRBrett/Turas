# ==============================================================================
# BRAND MODULE - FUNNEL PANEL TABLE (POLISHED, FUNNEL_SPEC_v2 §6)
# ==============================================================================
# Renders the stage-by-brand table inside a tabs/tracker-style card.
#
# Row order (locked — sort only shuffles competitor rows):
#   1. Base (n= per stage, with small-base warning triangle when n < 30)
#   2. Focal brand                  (left-border accent, FOCAL badge)
#   3. Category average             (italic, muted band)
#   4+ Competitors                  (sortable A-Z / Z-A / by any stage column)
#
# Cells carry both pct_of_total and pct_of_previous as data attributes; the
# panel JS toggles which one renders primary based on the Percentage Base
# control. Heatmap shading is PER COLUMN (relative within each stage), which
# reads honestly for a funnel where rightmost stages always decline.
# Sig ▲/▼ vs category average is rendered inline where present.
# Stage definitions are emitted as a hidden template consumed by the JS
# popover handler on the header ? buttons.
# ==============================================================================


#' Build the funnel table section (header + controls + table + popover templates)
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
    '<h3 class="fn-section-title">Funnel table <span class="fn-insight-marker" title="AI insight available">&#9679;</span></h3>',
    '<div class="fn-table-wrap">',
    '<table class="fn-table ct-table" data-fn-table="1">',
    .fn_table_header(stage_labels, stage_keys),
    '<tbody>',
    .fn_row_base(stage_keys, table$cells, brand_codes),
    .fn_row_focal(stage_keys, focal, brand_names[match(focal, brand_codes)],
                  table$cells, focal_colour, col_max),
    .fn_row_avg_all(stage_keys, table$avg_all_brands, col_max),
    .fn_rows_competitors(stage_keys, brand_codes, brand_names, focal,
                         table$cells, col_max),
    '</tbody></table></div>',
    .fn_popover_templates(stage_keys, stage_labels, stage_defs),
    '</section>'
  )
}


# ==============================================================================
# INTERNAL: HEADER
# ==============================================================================

.fn_table_header <- function(stage_labels, stage_keys) {
  cols <- vapply(seq_along(stage_keys), function(i) {
    key <- .fn_esc(stage_keys[i])
    label <- .fn_esc(stage_labels[i])
    sprintf(
      '<th class="fn-th-stage" data-fn-stage="%s" data-sort-col="%s">
         <span class="fn-th-label">%s</span>
         <button type="button" class="fn-help-btn"
                 aria-label="What is %s?"
                 data-fn-action="help" data-fn-stage="%s">?</button>
         <button type="button" class="fn-sort-btn"
                 aria-label="Sort by %s"
                 data-fn-action="sort-stage" data-fn-stage="%s"
                 data-fn-sort-dir="none">&#x25B4;&#x25BE;</button>
       </th>',
      key, key, label, label, key, label, key)
  }, character(1))
  paste0(
    '<thead><tr>',
    '<th class="fn-th-brand" data-sort-col="brand">
       <span class="fn-th-label">Brand</span>
       <button type="button" class="fn-sort-btn"
               aria-label="Sort brands alphabetically"
               data-fn-action="sort-brand"
               data-fn-sort-dir="asc">&#x25B4;&#x25BE;</button>
     </th>',
    paste(cols, collapse = ""),
    '</tr></thead>'
  )
}


# ==============================================================================
# INTERNAL: ROWS
# ==============================================================================

.fn_row_base <- function(stage_keys, cells, brand_codes) {
  # Base row aggregates the category base at each stage (sum of brand bases
  # / respondents per stage). We use category-average base as a proxy — the
  # brand-specific base is shown in the Show Counts mode.
  base_by_stage <- vapply(stage_keys, function(k) {
    ks <- vapply(cells, function(c) identical(c$stage_key, k), logical(1))
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
      return('<td class="fn-td fn-td-base fn-td-empty">&mdash;</td>')
    }
    warn <- v < .FN_SMALL_BASE
    sprintf('<td class="fn-td fn-td-base%s"><span class="fn-base-n">n=%d%s</span></td>',
            if (warn) " fn-td-base-warn" else "",
            as.integer(round(v)),
            if (warn) ' <span class="fn-warn" aria-label="small base">\u26A0</span>' else "")
  }, character(1))

  paste0(
    '<tr class="fn-row fn-row-base" data-locked="1">',
    '<th class="fn-th-rowlabel fn-th-rowlabel-base">Base (n=)</th>',
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
    sprintf('<tr class="fn-row fn-row-focal" %s>', row_attrs),
    sprintf('<th class="fn-th-rowlabel fn-row-focal-label">%s <span class="fn-focal-badge">focal</span></th>',
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
    if (is.null(r)) return('<td class="fn-td fn-td-empty">&mdash;</td>')
    pct_abs <- r$pct_absolute %||% NA_real_
    pct_nes <- r$pct_nested %||% NA_real_
    .fn_cell_html(pct_abs, pct_nes, base_w = NA_real_, base_u = NA_real_,
                  stage_key = k, brand_code = "__avg_all__",
                  col_max = col_max[[k]], sig_vs_avg = "na",
                  row_class = "fn-td-avg")
  }, character(1))
  paste0(
    '<tr class="fn-row fn-row-avg-all" data-locked="1">',
    '<th class="fn-th-rowlabel">Category average</th>',
    paste(cells, collapse = ""),
    '</tr>'
  )
}


.fn_rows_competitors <- function(stage_keys, brand_codes, brand_names,
                                 focal, cells, col_max) {
  non_focal_idx <- which(brand_codes != focal)
  if (length(non_focal_idx) == 0) return("")
  # Default order: alphabetical by brand name (matches the default sort)
  order_idx <- non_focal_idx[order(tolower(brand_names[non_focal_idx]))]
  rows <- vapply(order_idx, function(i) {
    b <- brand_codes[i]; nm <- brand_names[i]
    cells_for <- .fn_cells_for_brand(cells, b)
    sort_attrs <- .fn_brand_sort_attrs(cells_for, stage_keys, nm)
    paste0(
      sprintf('<tr class="fn-row fn-row-competitor" data-fn-brand="%s"%s>',
              .fn_esc(b), sort_attrs),
      sprintf('<th class="fn-th-rowlabel">%s</th>', .fn_esc(nm)),
      .fn_cells_html(stage_keys, cells_for, col_max),
      '</tr>'
    )
  }, character(1))
  paste(rows, collapse = "")
}


#' Emit a data-fn-sort-<stage>="0.NNN" attribute for every stage + a
#' data-fn-sort-brand for the alphabetical sort.
#' @keywords internal
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


#' Column max of pct_absolute — used to normalise heatmap shade per stage.
#' @keywords internal
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
    if (is.null(c)) return('<td class="fn-td fn-td-empty">&mdash;</td>')
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
    return(sprintf('<td class="fn-td fn-td-empty %s">&mdash;</td>', row_class))
  }
  bg_style <- .fn_per_column_heatmap_bg(pct_absolute, col_max)
  abs_display    <- sprintf("%.0f%%", 100 * pct_absolute)
  nested_display <- if (is.null(pct_nested) || is.na(pct_nested)) abs_display
                    else sprintf("%.0f%%", 100 * pct_nested)
  base_display <- if (is.finite(base_u %||% NA_real_))
                    sprintf("n=%d", as.integer(base_u))
                  else if (is.finite(base_w %||% NA_real_))
                    sprintf("n=%.0f", base_w)
                  else ""

  # Small-base warning on unweighted base < threshold
  is_warn <- is.finite(base_u %||% NA_real_) &&
             !is.na(base_u) && as.numeric(base_u) < .FN_SMALL_BASE
  warn_cls <- if (is_warn) " fn-td-warn" else ""
  sig_badge <- .fn_sig_badge(sig_vs_avg)

  sprintf(
    '<td class="fn-td%s %s" style="%s"
         data-fn-stage="%s" data-fn-brand="%s"
         data-fn-pct-abs="%.6f" data-fn-pct-nes="%.6f"
         data-fn-base="%s"
         data-sort-val="%.6f">
       <span class="fn-pct fn-pct-primary">%s</span>%s
       <span class="fn-pct-count">%s</span>
     </td>',
    warn_cls, row_class, bg_style,
    .fn_esc(stage_key), .fn_esc(brand_code),
    pct_absolute, if (is.null(pct_nested) || is.na(pct_nested))
                    pct_absolute else pct_nested,
    if (is.finite(base_u %||% NA_real_)) as.integer(base_u) else "",
    pct_absolute,
    abs_display, sig_badge, base_display
  )
}


#' In-cell ▲/▼ badge rendered whenever the brand is sig higher / lower than
#' the category average at that stage. Rendered hidden by default; JS
#' enables via a panel class so the user can opt in/out (future work) —
#' for now always visible.
#' @keywords internal
.fn_sig_badge <- function(direction) {
  switch(direction,
    higher = '<span class="fn-sig fn-sig-up" title="Higher than category average (p<0.05)">\u25B2</span>',
    lower  = '<span class="fn-sig fn-sig-down" title="Lower than category average (p<0.05)">\u25BC</span>',
    "")
}


#' Per-column heatmap shading (honest for funnels because stage 5 never
#' looks 'pale' relative to stage 1 — shade is relative within the column).
#' @keywords internal
.fn_per_column_heatmap_bg <- function(val, col_max) {
  if (is.na(val) || val <= 0) return("")
  denom <- if (is.null(col_max) || !is.finite(col_max) || col_max <= 0) 1
           else col_max
  frac <- min(1, max(0, val / denom))
  opacity <- 0.06 + frac * 0.34
  sprintf("background:rgba(37,99,171,%.2f);", opacity)
}


# ==============================================================================
# INTERNAL: POPOVER TEMPLATES
# ==============================================================================

#' Hidden <template> blocks per stage. JS reads these when the header ?
#' button is clicked and floats the content next to the trigger.
#' @keywords internal
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


# ==============================================================================
# CONSTANTS + SHARED HELPERS
# ==============================================================================

.FN_SMALL_BASE <- 30  # n< this triggers the ⚠ flag (per Duncan, matches tabs)


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
