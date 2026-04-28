# ==============================================================================
# BRAND MODULE - DEMOGRAPHICS PANEL: PER-QUESTION MATRIX TABLE
# ==============================================================================
# Pure HTML builder for the per-question matrix table consumed by the
# demographics panel renderer.
#
# Layout:
#   Col 1: option label
#   Col 2: focal brand (data-demo-col="focal")  — toggleable column
#   Col 3: cat avg (data-demo-col="catavg")
#   Col 4..N: per-brand columns (data-demo-col="brand" data-demo-brand="<bc>")
#
# Each cell renders a primary % plus an optional count (data-cell-n) and CI
# range (data-cell-ci-lo/hi). The JS controller toggles the visibility of
# those secondary spans based on the global "n counts" / "95% CI" checkbox
# state, so we render them once and let CSS / JS hide them.
#
# Heatmap colouring is applied per-cell via inline background-color when the
# global Heatmap checkbox is on. Diff is computed against the cat-avg row %
# and clipped to ±MAX_HEAT_DIFF percentage points.
#
# VERSION: 1.0
# ==============================================================================

BRAND_DEMOGRAPHICS_PANEL_TABLE_VERSION <- "1.0"

# Magnitude clip for the heatmap colour ramp. Diffs above this saturate the
# colour. 30pp is the largest single-option diff we typically see between a
# brand's buyers and the category average across demographic cuts.
.DEMO_TABLE_MAX_HEAT_DIFF_PP <- 30


# ==============================================================================
# PUBLIC API
# ==============================================================================

#' Build the per-question matrix table
#'
#' @param question_payload List. One entry from \code{panel_data$questions}
#'   produced by \code{build_demographics_panel_data()}.
#' @param focal_brand Character. Brand code shown in column 2.
#' @param brand_colours Named list. brand_code -> hex colour for chip swatches.
#' @param panel_data List. Full panel data; used for the brand list ordering.
#' @param decimal_places Integer. Display precision for percentages.
#' @return Character. HTML fragment for the matrix table.
#' @export
build_demographics_matrix_table <- function(question_payload, focal_brand,
                                             brand_colours, panel_data,
                                             decimal_places = 0L) {
  q     <- question_payload
  rows  <- q$total$rows %||% list()
  if (length(rows) == 0L) {
    return('<div class="demo-empty">No responses for this question.</div>')
  }

  brand_codes  <- panel_data$brands$codes  %||% character(0)
  brand_labels <- panel_data$brands$labels %||% brand_codes
  ord          <- .demo_table_brand_order(brand_codes, focal_brand)

  thead <- .demo_table_header(brand_codes[ord], brand_labels[ord],
                               focal_brand, brand_colours)
  tbody <- .demo_table_body(rows, q, brand_codes[ord], focal_brand,
                             brand_colours, decimal_places)

  sprintf(
    '<div class="demo-matrix-wrap"><table class="demo-matrix">%s%s</table></div>',
    thead, tbody)
}


# ==============================================================================
# INTERNAL: BRAND ORDERING (focal first, others in declared order)
# ==============================================================================

.demo_table_brand_order <- function(brand_codes, focal_brand) {
  if (length(brand_codes) == 0L) return(integer(0))
  fi <- if (focal_brand %in% brand_codes) which(brand_codes == focal_brand)[1L]
        else integer(0)
  rest <- setdiff(seq_along(brand_codes), fi)
  c(fi, rest)
}


# ==============================================================================
# INTERNAL: HEADER ROW
# ==============================================================================

.demo_table_header <- function(brand_codes, brand_labels, focal_brand,
                                brand_colours) {
  brand_th <- vapply(seq_along(brand_codes), function(i) {
    bc  <- brand_codes[i]
    bl  <- brand_labels[i]
    col <- brand_colours[[bc]] %||% "#94a3b8"
    cls <- if (identical(bc, focal_brand)) "demo-col-focal" else ""
    sprintf(
      '<th class="%s" data-demo-col="brand" data-demo-brand="%s">
         <span class="demo-brand-chip-swatch" style="background:%s"></span> %s
       </th>',
      cls, .demo_table_esc(bc), .demo_table_esc(col), .demo_table_esc(bl))
  }, character(1L))
  paste0(
    '<thead><tr>',
    '<th>Option</th>',
    '<th class="demo-col-focal" data-demo-col="focal">Focal</th>',
    '<th class="demo-col-catavg" data-demo-col="catavg">Cat avg</th>',
    paste(brand_th, collapse = ""),
    '</tr></thead>'
  )
}


# ==============================================================================
# INTERNAL: BODY (one row per option)
# ==============================================================================

# SIZE-EXCEPTION: per-row builder weaves five cell types (focal, cat-avg,
# per-brand × N, n counts, CI bounds, heatmap shading) and is clearer as a
# single sequential function than as four extract-this / extract-that helpers
# that would each take the same six args.
.demo_table_body <- function(rows, q, brand_codes, focal_brand, brand_colours,
                              dp) {
  # Brand_cut indexed by code -> cells list (parallel to q$codes order)
  brand_by <- list()
  for (b in (q$brand_cut %||% list())) {
    brand_by[[b$brand_code]] <- b
  }

  trs <- vapply(seq_along(rows), function(i) {
    r <- rows[[i]]
    cat_pct <- r$pct %||% NA_real_

    focal_cell <- .demo_table_brand_cell(brand_by[[focal_brand]], r$code,
                                          cat_pct, dp,
                                          extra_class = "demo-col-focal",
                                          colcode = "focal",
                                          brand_code = focal_brand)
    catavg_cell <- .demo_table_catavg_cell(r, dp)
    # Per-brand block always lists every brand in declared order, including
    # the focal brand. The "Focal" column 2 is a pinned reference of whichever
    # brand the user currently picks; the per-brand block is the full
    # comparison set. Showing focal twice is intentional (matches Excel pivot
    # with a "Selected" row pinned at top).
    per_brand_cells <- vapply(brand_codes, function(bc) {
      .demo_table_brand_cell(brand_by[[bc]], r$code, cat_pct, dp,
                              extra_class = if (identical(bc, focal_brand))
                                "demo-col-focal" else "",
                              colcode = "brand", brand_code = bc)
    }, character(1L))

    paste0(
      '<tr>',
      sprintf('<td>%s</td>', .demo_table_esc(r$label %||% r$code)),
      focal_cell, catavg_cell, paste(per_brand_cells, collapse = ""),
      '</tr>'
    )
  }, character(1L))

  paste0('<tbody>', paste(trs, collapse = ""), '</tbody>')
}


# Per-brand cell — primary % + optional n + optional CI + heatmap diff.
# colcode controls data-demo-col (used by JS visibility toggles).
.demo_table_brand_cell <- function(brand_entry, code, cat_pct, dp,
                                    extra_class = "", colcode = "brand",
                                    brand_code = NA_character_) {
  if (is.null(brand_entry)) {
    return(sprintf(
      '<td class="%s" data-demo-col="%s" data-demo-brand="%s">
         <span class="demo-na">&mdash;</span>
       </td>',
      extra_class, colcode, .demo_table_esc(brand_code %||% "")))
  }
  cell <- .demo_table_find_cell(brand_entry$cells, code)
  if (is.null(cell)) {
    return(sprintf(
      '<td class="%s" data-demo-col="%s" data-demo-brand="%s">
         <span class="demo-na">&mdash;</span>
       </td>',
      extra_class, colcode, .demo_table_esc(brand_code %||% "")))
  }
  pct <- cell$pct
  diff <- if (!is.null(cat_pct) && is.finite(cat_pct) && is.finite(pct))
    pct - cat_pct else NA_real_
  bg <- .demo_table_heat_colour(diff)
  base_n <- brand_entry$base_n %||% NA_integer_
  cell_n <- if (is.finite(base_n) && is.finite(pct))
    as.integer(round(base_n * pct / 100)) else NA_integer_
  sprintf(
    '<td class="%s" data-demo-col="%s" data-demo-brand="%s" data-demo-heat="%s">
       %s%s%s
     </td>',
    extra_class, colcode, .demo_table_esc(brand_code %||% ""),
    .demo_table_esc(bg),
    .demo_table_pct(pct, dp),
    .demo_table_count_span(cell_n),
    .demo_table_ci_span(cell$ci_lower, cell$ci_upper, dp))
}


.demo_table_catavg_cell <- function(r, dp) {
  pct <- r$pct
  base_n <- r$n
  sprintf(
    '<td class="demo-col-catavg" data-demo-col="catavg">
       %s%s%s
     </td>',
    .demo_table_pct(pct, dp),
    .demo_table_count_span(base_n),
    .demo_table_ci_span(r$ci_lower, r$ci_upper, dp))
}


# Find a cell in a brand_entry$cells list by option code.
.demo_table_find_cell <- function(cells, code) {
  for (c in cells) if (identical(c$code, code)) return(c)
  NULL
}


# ==============================================================================
# INTERNAL: FORMAT HELPERS
# ==============================================================================

.demo_table_pct <- function(v, dp) {
  if (is.null(v) || is.na(v) || !is.finite(v))
    return('<span class="demo-na">&mdash;</span>')
  sprintf("%.*f%%", as.integer(dp), v)
}


.demo_table_count_span <- function(n) {
  if (is.null(n) || is.na(n) || !is.finite(n)) return("")
  sprintf('<span class="demo-cell-n" hidden>n=%d</span>', as.integer(n))
}


.demo_table_ci_span <- function(lo, hi, dp) {
  if (is.null(lo) || is.null(hi) || is.na(lo) || is.na(hi) ||
      !is.finite(lo) || !is.finite(hi)) return("")
  sprintf('<span class="demo-cell-ci" hidden>[%.*f%% &ndash; %.*f%%]</span>',
          as.integer(dp), lo, as.integer(dp), hi)
}


# Heat colour for one cell. Diverging blue (above cat-avg) / red (below).
# Empty string when diff is unknown; the JS toggle controls whether the
# resulting background actually paints.
.demo_table_heat_colour <- function(diff) {
  if (is.null(diff) || is.na(diff) || !is.finite(diff)) return("")
  frac  <- min(1, abs(diff) / .DEMO_TABLE_MAX_HEAT_DIFF_PP)
  alpha <- sprintf("%.3f", 0.06 + frac * 0.50)
  if (diff >= 0) sprintf("rgba(37,99,171,%s)",  alpha)
  else           sprintf("rgba(192,57,43,%s)",  alpha)
}


.demo_table_esc <- function(x) {
  if (is.null(x)) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}
