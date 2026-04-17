# ==============================================================================
# BRAND MODULE - FUNNEL PANEL TABLE (HEATMAP)
# ==============================================================================
# Renders the stage-by-brand table with:
#   - Row 1: Focal brand (highlighted)
#   - Row 2: Average of all brands
#   - Rows 3..N: Competitor brands
# Cells carry both pct_nested and pct_absolute; which is displayed is
# chosen by the panel JS based on the "% of %" / "% of absolute" toggle.
# Cell background uses the tracker blue sequential scale.
# ==============================================================================


#' Build the funnel table HTML
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

  paste0(
    '<section class="fn-section fn-table-section">',
    '<h3 class="fn-section-title">Table view <span class="fn-insight-marker" title="AI insight available">&#9679;</span></h3>',
    '<div class="fn-table-wrap">',
    '<table class="fn-table ct-table" data-fn-table="1">',
    .fn_table_header(stage_labels, stage_keys),
    '<tbody>',
    .fn_row_focal(stage_keys, focal, table$cells, focal_colour),
    .fn_row_avg_all(stage_keys, table$avg_all_brands),
    .fn_rows_competitors(stage_keys, brand_codes, brand_names, focal,
                         table$cells),
    '</tbody></table></div>',
    '</section>'
  )
}


# ==============================================================================
# INTERNAL: HEADER + ROWS
# ==============================================================================

.fn_table_header <- function(stage_labels, stage_keys) {
  cols <- vapply(seq_along(stage_keys), function(i) {
    sprintf('<th class="fn-th-stage" data-fn-stage="%s">%s</th>',
            .fn_esc(stage_keys[i]), .fn_esc(stage_labels[i]))
  }, character(1))
  paste0(
    '<thead><tr>',
    '<th class="fn-th-brand">Brand</th>',
    paste(cols, collapse = ""),
    '</tr></thead>'
  )
}


.fn_row_focal <- function(stage_keys, focal, cells, focal_colour) {
  focal_name <- focal  # brand_list label not carried in cells; use code
  cells_for <- .fn_cells_for_brand(cells, focal)
  paste0(
    sprintf('<tr class="fn-row fn-row-focal" data-fn-brand="%s" style="--fn-row-accent:%s;">',
            .fn_esc(focal), focal_colour),
    sprintf('<th class="fn-th-rowlabel fn-row-focal-label">%s <span class="fn-focal-badge">focal</span></th>',
            .fn_esc(focal_name)),
    .fn_cells_html(stage_keys, cells_for),
    '</tr>'
  )
}


.fn_row_avg_all <- function(stage_keys, avg_rows) {
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
                  row_class = "fn-td-avg")
  }, character(1))
  paste0(
    '<tr class="fn-row fn-row-avg-all">',
    '<th class="fn-th-rowlabel">Average of all brands</th>',
    paste(cells, collapse = ""),
    '</tr>'
  )
}


.fn_rows_competitors <- function(stage_keys, brand_codes, brand_names,
                                 focal, cells) {
  non_focal_idx <- which(brand_codes != focal)
  if (length(non_focal_idx) == 0) return("")
  rows <- vapply(non_focal_idx, function(i) {
    b <- brand_codes[i]
    nm <- brand_names[i]
    cells_for <- .fn_cells_for_brand(cells, b)
    paste0(
      sprintf('<tr class="fn-row fn-row-competitor" data-fn-brand="%s">',
              .fn_esc(b)),
      sprintf('<th class="fn-th-rowlabel">%s</th>', .fn_esc(nm)),
      .fn_cells_html(stage_keys, cells_for),
      '</tr>'
    )
  }, character(1))
  paste(rows, collapse = "")
}


# ==============================================================================
# INTERNAL: CELL RENDERING
# ==============================================================================

.fn_cells_for_brand <- function(cells, brand_code) {
  out <- list()
  for (c in cells) {
    if (identical(c$brand_code, brand_code)) {
      out[[c$stage_key]] <- c
    }
  }
  out
}


.fn_cells_html <- function(stage_keys, cells_by_stage) {
  vals <- vapply(stage_keys, function(k) {
    c <- cells_by_stage[[k]]
    if (is.null(c)) return('<td class="fn-td fn-td-empty">&mdash;</td>')
    .fn_cell_html(c$pct_absolute, c$pct_nested,
                  c$base_weighted, c$base_unweighted,
                  k, c$brand_code, "")
  }, character(1))
  paste(vals, collapse = "")
}


.fn_cell_html <- function(pct_absolute, pct_nested, base_w, base_u,
                          stage_key, brand_code, row_class = "") {
  if (is.null(pct_absolute) || is.na(pct_absolute)) {
    return(sprintf('<td class="fn-td fn-td-empty %s">&mdash;</td>', row_class))
  }
  bg_style <- .fn_heatmap_bg(100 * pct_absolute)
  abs_display <- sprintf("%.0f%%", 100 * pct_absolute)
  nested_display <- if (is.na(pct_nested)) abs_display
                    else sprintf("%.0f%%", 100 * pct_nested)
  base_display <- if (is.finite(base_u)) sprintf("n = %d", as.integer(base_u))
                  else if (is.finite(base_w)) sprintf("n = %.0f", base_w)
                  else ""

  sprintf(
    '<td class="fn-td %s" style="%s" data-fn-stage="%s" data-fn-brand="%s" data-fn-pct-abs="%.6f" data-fn-pct-nes="%.6f"><span class="fn-pct fn-pct-primary">%s</span><span class="fn-pct-count">%s</span></td>',
    row_class, bg_style, .fn_esc(stage_key), .fn_esc(brand_code),
    pct_absolute, if (is.na(pct_nested)) pct_absolute else pct_nested,
    nested_display, base_display
  )
}


#' Heatmap background — blue sequential rgba(37,99,171, 0.06..0.40) by val
#' (mirrors tracker's pct_response scale).
#' @keywords internal
.fn_heatmap_bg <- function(pct_0to100) {
  if (is.na(pct_0to100)) return("")
  frac <- max(0, min(1, pct_0to100 / 100))
  opacity <- 0.06 + frac * 0.34
  sprintf("background:rgba(37,99,171,%.2f);", opacity)
}


# ==============================================================================
# SHARED HELPERS
# ==============================================================================

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
