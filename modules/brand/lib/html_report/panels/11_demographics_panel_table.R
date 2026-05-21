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
  # Look up the focal-brand display label from the FULL brand list before
  # we drop focal from the per-brand block. Otherwise the header function
  # can't resolve "BR_A" → "Brand A".
  focal_label  <- .demo_table_focal_label(brand_codes, brand_labels,
                                           focal_brand)
  ord          <- .demo_table_brand_order(brand_codes, focal_brand)

  thead <- .demo_table_header(brand_codes[ord], brand_labels[ord],
                               focal_brand, focal_label, brand_colours)
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
  # Focal lives in its own pinned column 2 (rendered separately). The
  # per-brand block excludes the focal so we don't show the same brand
  # twice — fixed 2026-05-22 after a UX review flagged the duplication.
  if (length(brand_codes) == 0L) return(integer(0))
  fi <- which(brand_codes == focal_brand)
  setdiff(seq_along(brand_codes), fi)
}


# Resolve the display label for the focal brand from the original (full)
# brand list. Called BEFORE per-brand ordering subset because excluding
# focal from the per-brand block would otherwise lose its label.
.demo_table_focal_label <- function(brand_codes, brand_labels, focal_brand) {
  fi <- match(focal_brand, brand_codes)
  if (is.na(fi)) return(focal_brand)
  brand_labels[fi]
}


# ==============================================================================
# INTERNAL: HEADER ROW
# ==============================================================================

.demo_table_header <- function(brand_codes, brand_labels, focal_brand,
                                focal_label, brand_colours) {
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
    sprintf('<th class="demo-col-focal" data-demo-col="focal">%s<span class="demo-th-sub">focal</span></th>',
            .demo_table_esc(focal_label)),
    '<th class="demo-col-catavg" data-demo-col="catavg">Cat avg</th>',
    paste(brand_th, collapse = ""),
    '</tr></thead>'
  )
}


# ==============================================================================
# INTERNAL: BODY (two rows per option — Buyer + Non-buyer)
# ==============================================================================

# Cell semantics: penetration WITHIN the demographic option.
#   Buyer-row cell    = % of respondents in this option who BUY this brand
#   Non-buyer-row cell = 100% − Buyer-row cell (its complement)
# Buyer + Non-buyer per cell sum to 100%, so the read is: "of the 30-35s, 29%
# buy IPK and 71% don't".
#
# Cat-avg column in penetration mode shows the per-option MEAN pen across all
# brands — the typical brand's pen rate in this demographic. Heatmap shading
# per brand cell is driven by (cell pct − this per-option avg pen), clipped
# to ±MAX_HEAT_DIFF. Blue = brand over-performs vs the typical brand here;
# red = under-performs. Non-buyer rows mirror the SAME colour as the matching
# buyer row (same competitive direction, not the mathematical inverse) so
# reading either row gives a consistent signal.

.demo_table_body <- function(rows, q, brand_codes, focal_brand, brand_colours,
                              dp) {
  pen_by      <- .demo_table_index_by_brand(q$brand_penetration_long)
  option_avg  <- q$option_avg_penetration %||% list()

  trs <- vapply(seq_along(rows), function(i) {
    r <- rows[[i]]
    cat_pct <- .demo_table_option_avg_pct(option_avg, r$code)

    buyer_row <- .demo_table_pen_row(
      role         = "buyer",
      label_cell   = sprintf('<td class="demo-opt-label">%s</td>',
                             .demo_table_esc(r$label %||% r$code)),
      brand_index  = pen_by,
      cat_pct      = cat_pct,
      code         = r$code,
      catavg_cell  = .demo_table_catavg_pen_cell(r, cat_pct, dp),
      brand_codes  = brand_codes,
      focal_brand  = focal_brand,
      complement   = FALSE,
      dp           = dp)

    nonbuyer_row <- .demo_table_pen_row(
      role         = "nonbuyer",
      label_cell   = '<td class="demo-opt-label demo-row-nonbuyer-label">&#8627; non-buyer</td>',
      brand_index  = pen_by,
      cat_pct      = cat_pct,
      code         = r$code,
      catavg_cell  = '<td class="demo-col-catavg demo-cell-blank" data-demo-col="catavg"></td>',
      brand_codes  = brand_codes,
      focal_brand  = focal_brand,
      complement   = TRUE,
      dp           = dp)

    paste0(buyer_row, nonbuyer_row)
  }, character(1L))

  paste0('<tbody>', paste(trs, collapse = ""), '</tbody>')
}


# Render one tr (buyer or non-buyer). complement=TRUE flips the cell value to
# 100 − pct (non-buyer is the complement of buyer within the known base).
# cat_pct is the per-option avg-brand-pen baseline used for cell shading.
.demo_table_pen_row <- function(role, label_cell, brand_index, cat_pct,
                                 code, catavg_cell, brand_codes, focal_brand,
                                 complement, dp) {
  focal_cell <- .demo_table_pen_cell(
    brand_index[[focal_brand]], cat_pct,
    code, dp, complement = complement,
    extra_class = "demo-col-focal", colcode = "focal",
    brand_code  = focal_brand)
  per_brand_cells <- vapply(brand_codes, function(bc) {
    .demo_table_pen_cell(
      brand_index[[bc]], cat_pct,
      code, dp, complement = complement,
      extra_class = "", colcode = "brand", brand_code = bc)
  }, character(1L))
  sprintf(
    '<tr class="demo-row-%s">%s%s%s%s</tr>',
    role, label_cell, focal_cell, catavg_cell,
    paste(per_brand_cells, collapse = ""))
}


# Look up the per-option avg brand pen from the panel payload. Returns NA
# when the option isn't represented (defensive — shouldn't happen with a
# well-formed engine result).
.demo_table_option_avg_pct <- function(option_avg, code) {
  if (is.null(option_avg) || length(option_avg) == 0L) return(NA_real_)
  entry <- option_avg[[as.character(code)]]
  if (is.null(entry)) return(NA_real_)
  as.numeric(entry$pct %||% NA_real_)
}


# Penetration-mode Cat-avg cell. Shows the per-option mean brand pen — i.e.
# the typical brand's pen rate in this demographic. Italic / muted styling
# from the .demo-col-catavg class.
.demo_table_catavg_pen_cell <- function(r, cat_pct, dp) {
  sprintf(
    '<td class="demo-col-catavg" data-demo-col="catavg">%s</td>',
    .demo_table_pct(cat_pct, dp))
}


.demo_table_index_by_brand <- function(brand_long) {
  out <- list()
  for (b in (brand_long %||% list())) {
    out[[b$brand_code]] <- b
  }
  out
}


# Render one cell in the penetration table.
#
# value = buyer pct in option (from brand_index); when complement=TRUE the
# cell shows 100 − value (the non-buyer share). Heat colour is always based
# on the BUYER gap (cell - cat_pct, where cat_pct is the per-option mean
# brand pen) so buyer + non-buyer rows share the same colour and signal
# direction — and the colour directly indicates "this brand over/under-
# performs the typical brand in this demographic".
#
# Returns an NA cell when no data for this option/brand combination exists.
.demo_table_pen_cell <- function(entry, cat_pct, code, dp,
                                  complement = FALSE,
                                  extra_class = "", colcode = "brand",
                                  brand_code = NA_character_) {
  if (is.null(entry)) {
    return(.demo_table_na_cell(extra_class, colcode, brand_code))
  }
  cell <- .demo_table_find_cell(entry$cells %||% list(), code)
  if (is.null(cell)) {
    return(.demo_table_na_cell(extra_class, colcode, brand_code))
  }
  buyer_pct <- cell$pct
  shown_pct <- if (isTRUE(complement)) {
    if (is.finite(buyer_pct)) 100 - buyer_pct else NA_real_
  } else {
    buyer_pct
  }
  buyer_diff <- if (is.finite(buyer_pct) && is.finite(cat_pct))
                  buyer_pct - cat_pct else NA_real_
  bg <- .demo_table_heat_colour(buyer_diff)

  cell_n <- .demo_table_pen_cell_n(entry, code, buyer_pct, complement)

  sprintf(
    '<td class="%s" data-demo-col="%s" data-demo-brand="%s" data-demo-heat="%s">%s%s</td>',
    extra_class, colcode, .demo_table_esc(brand_code %||% ""),
    .demo_table_esc(bg),
    .demo_table_pct(shown_pct, dp),
    .demo_table_count_span(cell_n))
}


# Unweighted cell count behind the displayed pct. For the BUYER row this is
# round(base_n * buyer_pct / 100); for NON-BUYER it's base_n − buyer_n. The
# per-option Base_n is exposed as Base_n_<code> on the engine output and the
# panel-data builder forwards it on each cells[] entry as base_n_in_option.
.demo_table_pen_cell_n <- function(entry, code, buyer_pct, complement) {
  if (is.null(entry)) return(NA_integer_)
  cell <- .demo_table_find_cell(entry$cells %||% list(), code)
  if (is.null(cell)) return(NA_integer_)
  base_in_opt <- cell$base_n_in_option %||% NA_integer_
  if (!is.finite(base_in_opt) || !is.finite(buyer_pct)) return(NA_integer_)
  buyer_n <- as.integer(round(base_in_opt * buyer_pct / 100))
  if (isTRUE(complement)) base_in_opt - buyer_n else buyer_n
}


# Compute the unweighted respondent count behind a percentage cell, given the
# brand's base size and the weighted pct. Returns NA when either is unknown.
.demo_table_cell_n <- function(brand_entry, pct) {
  base_n <- (brand_entry %||% list())$base_n %||% NA_integer_
  if (!is.finite(base_n) || !is.finite(pct)) return(NA_integer_)
  as.integer(round(base_n * pct / 100))
}


.demo_table_na_cell <- function(extra_class, colcode, brand_code) {
  sprintf(
    '<td class="%s" data-demo-col="%s" data-demo-brand="%s">
       <span class="demo-na">&mdash;</span>
     </td>',
    extra_class, colcode, .demo_table_esc(brand_code %||% ""))
}


.demo_table_catavg_cell <- function(r, dp) {
  pct <- r$pct
  base_n <- r$n
  sprintf(
    '<td class="demo-col-catavg" data-demo-col="catavg">
       %s%s
     </td>',
    .demo_table_pct(pct, dp),
    .demo_table_count_span(base_n))
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
