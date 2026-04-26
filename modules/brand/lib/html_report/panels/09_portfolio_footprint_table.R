# ==============================================================================
# BRAND MODULE - PORTFOLIO FOOTPRINT TABLE (HTML)
# ==============================================================================
# Replaces the legacy SVG heat-strip with an interactive HTML table that
# matches the visual contract of the other brand tabs:
#   - Focal-brand <select> dropdown (always pins the focal row to row 1)
#   - Coloured chip row (show/hide individual brands)
#   - Sortable column headers (click to sort by any category)
#   - Heat-coloured cells (awareness % drives background intensity)
#   - All categories shown — low-base columns are flagged but not dropped
#   - Lowercase row + column header labels per Duncan's spec
#
# Rendered by .pf_footprint_subtab() in 09_portfolio_panel.R.
# Interactions live in js/brand_portfolio_panel.js (pf-fp-* hooks).
# ==============================================================================

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a


#' Stable colour palette + per-brand colour resolver.
#'
#' Falls back to a DJB2 hash over the brand code so colours are stable
#' across reports for brands not in `brand_colours`.
#' @keywords internal
.pf_brand_palette <- c(
  "#4e79a7", "#f28e2b", "#e15759", "#76b7b2", "#59a14f",
  "#edc948", "#b07aa1", "#ff9da7", "#9c755f", "#bab0ac"
)

.pf_brand_colour <- function(bc, focal_code, focal_colour, brand_colours = list()) {
  if (!is.null(brand_colours[[bc]]) && nzchar(brand_colours[[bc]]))
    return(as.character(brand_colours[[bc]]))
  if (!is.null(focal_code) && bc == focal_code && nzchar(focal_colour %||% ""))
    return(as.character(focal_colour))
  # DJB2-on-doubles, mod 2^31 — matches the JS-side implementation in
  # WoM/Funnel so chip colours line up across tabs without coordination.
  h <- 5381.0
  for (b in utf8ToInt(bc)) h <- (h * 33.0 + b) %% 2147483648.0
  .pf_brand_palette[(as.integer(h) %% length(.pf_brand_palette)) + 1L]
}


#' Heat-cell background colour ramp (awareness % → rgba).
#' @keywords internal
.pf_heat_bg <- function(pct, focal_colour = "#1A5276") {
  if (is.na(pct) || !is.finite(pct)) return("transparent")
  intensity <- max(0, min(1, pct / 100))
  hex <- gsub("^#", "", focal_colour)
  if (nchar(hex) != 6) hex <- "1A5276"
  r <- strtoi(substr(hex, 1, 2), 16L)
  g <- strtoi(substr(hex, 3, 4), 16L)
  b <- strtoi(substr(hex, 5, 6), 16L)
  alpha <- 0.05 + intensity * 0.55
  sprintf("rgba(%d,%d,%d,%.2f)", r, g, b, alpha)
}

.pf_heat_fg <- function(pct) {
  if (is.na(pct) || !is.finite(pct)) return("#94a3b8")
  if (pct / 100 > 0.55) "#ffffff" else "#1e293b"
}


#' Build the Footprint sub-tab HTML (table view).
#'
#' @param footprint List with fields: matrix_df (Brand + cat columns),
#'   bases_df, cat_names (named vector), brand_names (named vector),
#'   suppressed_cats.
#' @param focal_brand Character. Focal brand code.
#' @param focal_colour Character. Hex colour for focal accents and the
#'   awareness heat ramp.
#' @param brand_colours Named list. Optional cat-overridden brand colours.
#'
#' @return Character. HTML fragment.
#' @keywords internal
build_pf_footprint_html <- function(footprint, focal_brand, focal_colour,
                                     brand_colours = list()) {
  if (is.null(footprint) || is.null(footprint$matrix_df) ||
      nrow(footprint$matrix_df) == 0) {
    return('<p style="color:#94a3b8;padding:24px 0;">Footprint data not available.</p>')
  }

  fp           <- footprint$matrix_df
  bases_df     <- footprint$bases_df    %||% data.frame()
  cat_names    <- footprint$cat_names   %||% character(0)
  brand_names  <- footprint$brand_names %||% character(0)
  n_total      <- footprint$n_total     %||% NA_integer_
  suppressed   <- footprint$suppressed_cats %||% character(0)

  brand_codes  <- as.character(fp$Brand)
  cat_codes    <- setdiff(names(fp), "Brand")
  if (length(cat_codes) == 0 || length(brand_codes) == 0) {
    return('<p style="color:#94a3b8;padding:24px 0;">Footprint data not available.</p>')
  }

  # Resolve display labels — fall back to the code when the lookup is
  # absent or doesn't contain the key. Robust to: NULL map, length-0 map,
  # named character vector, named list — any of which can show up
  # depending on whether `compute_footprint_matrix` had any brands to
  # populate.
  .nm <- function(map, code) {
    if (is.null(map) || length(map) == 0) return(code)
    nm <- names(map)
    if (is.null(nm) || !(code %in% nm)) return(code)
    v <- map[[code]]
    if (is.null(v) || (length(v) == 1 && (is.na(v) || !nzchar(as.character(v)))))
      return(code)
    as.character(v)
  }
  cat_label   <- vapply(cat_codes,   function(cc) .nm(cat_names,   cc), character(1))
  brand_label <- vapply(brand_codes, function(bc) .nm(brand_names, bc), character(1))

  # Order brands: focal first, then alphabetical by display name.
  is_focal     <- brand_codes == focal_brand
  others_order <- order(tolower(brand_label[!is_focal]))
  brand_order  <- c(which(is_focal), which(!is_focal)[others_order])
  brand_codes  <- brand_codes[brand_order]
  brand_label  <- brand_label[brand_order]

  # Bases lookup for the column subtitle (n=…).
  base_n <- if (is.data.frame(bases_df) && "cat" %in% names(bases_df) &&
                "n_buyers_uw" %in% names(bases_df)) {
    setNames(as.integer(bases_df$n_buyers_uw), as.character(bases_df$cat))
  } else setNames(integer(0), character(0))

  paste0(
    .pf_fp_controls_bar(brand_codes, brand_label, focal_brand,
                         focal_colour, brand_colours),
    .pf_fp_table(fp, brand_codes, brand_label, cat_codes, cat_label,
                  base_n, n_total, suppressed, focal_brand, focal_colour)
  )
}


# ==============================================================================
# CONTROLS BAR — focal <select> + colour-coded chips
# ==============================================================================

.pf_fp_controls_bar <- function(brand_codes, brand_label, focal_brand,
                                 focal_colour, brand_colours) {
  # Focal-brand <select>
  options <- vapply(seq_along(brand_codes), function(i) {
    bc  <- brand_codes[i]
    nm  <- brand_label[i]
    sel <- if (identical(bc, focal_brand)) " selected" else ""
    sprintf('<option value="%s"%s>%s</option>',
            .pf_esc(bc), sel, .pf_esc(nm))
  }, character(1))

  # Coloured chips — same DJB2 palette as other tabs, focal gets the brand colour.
  chips <- vapply(seq_along(brand_codes), function(i) {
    bc  <- brand_codes[i]
    nm  <- brand_label[i]
    col <- .pf_brand_colour(bc, focal_brand, focal_colour, brand_colours)
    is_foc <- identical(bc, focal_brand)
    badge  <- if (is_foc) ' <span class="fn-focal-badge">FOCAL</span>' else ""
    sprintf(
      '<button type="button" class="col-chip pf-fp-chip" data-pf-fp-brand="%s" style="--pf-chip-col:%s;"><span class="pf-fp-chip-dot" style="background:%s;"></span>%s%s</button>',
      .pf_esc(bc), col, col, .pf_esc(nm), badge
    )
  }, character(1))

  paste0(
    '<div class="pf-fp-controls">',
    '<div class="pf-fp-ctl-group">',
    '<label class="pf-fp-ctl-label" for="pf-fp-focal-select">Focal brand</label>',
    sprintf('<select id="pf-fp-focal-select" class="pf-fp-focal-select" data-pf-fp-action="focal">%s</select>',
            paste(options, collapse = "")),
    '</div>',
    '<div class="pf-fp-ctl-group pf-fp-chips-group">',
    '<span class="pf-fp-ctl-label">Show brands</span>',
    sprintf('<div class="pf-fp-chips col-chip-bar">%s</div>',
            paste(chips, collapse = "")),
    '</div>',
    '<div class="pf-fp-ctl-group pf-fp-toggles-group">',
    '<span class="pf-fp-ctl-label">Display</span>',
    '<div class="pf-fp-toggles">',
    '<label class="toggle-label"><input type="checkbox" checked data-pf-fp-action="heatmap"> Show heatmap</label>',
    '<label class="toggle-label"><input type="checkbox" data-pf-fp-action="showcounts"> Show count</label>',
    '</div>',
    '</div>',
    '</div>'
  )
}


# ==============================================================================
# TABLE
# ==============================================================================

.pf_fp_table <- function(fp, brand_codes, brand_label, cat_codes, cat_label,
                          base_n, n_total, suppressed, focal_brand, focal_colour) {
  # Pre-compute categories-per-brand counts (non-NA cells per row). This
  # is the right-most column added per Duncan's spec.
  presence_count <- vapply(brand_codes, function(bc) {
    row_idx <- match(bc, fp$Brand)
    if (is.na(row_idx)) return(0L)
    sum(vapply(cat_codes, function(cc) {
      v <- fp[[cc]][row_idx]
      !is.null(v) && !is.na(v) && is.finite(v)
    }, logical(1)))
  }, integer(1))
  total_cats <- length(cat_codes)

  # Header cells — lowercase + sortable + base subtitle (n + cat
  # penetration as % of all respondents). The <th> itself is the click
  # target (no inner <button>) so the header strip renders as a
  # continuous solid bar without per-cell native-button artefacts.
  has_total <- !is.null(n_total) && is.finite(n_total) && n_total > 0
  ths <- vapply(seq_along(cat_codes), function(j) {
    cc  <- cat_codes[j]
    lbl <- tolower(cat_label[j])
    n <- if (length(base_n) > 0 && cc %in% names(base_n)) base_n[[cc]] else NA_integer_
    base_str <- if (!is.null(n) && !is.na(n)) sprintf("n=%d", n) else ""
    pen_str <- if (has_total && !is.null(n) && !is.na(n))
                 sprintf("%.0f%% pen", 100 * n / n_total) else ""
    flagged  <- cc %in% suppressed
    flag_cls <- if (flagged) " pf-fp-th-lowbase" else ""
    sprintf(
      '<th class="pf-fp-th pf-fp-th-sort%s" data-pf-fp-sort="%s" scope="col" tabindex="0" role="button"><span class="pf-fp-th-inner"><span class="pf-fp-th-label">%s</span><span class="pf-fp-th-base">%s</span><span class="pf-fp-th-pen">%s</span><span class="pf-fp-sort-ind" aria-hidden="true">&#x2195;</span></span></th>',
      flag_cls, .pf_esc(cc), .pf_esc(lbl), .pf_esc(base_str), .pf_esc(pen_str)
    )
  }, character(1))

  # Trailing "categories" column header (sort by presence count).
  cats_th <- '<th class="pf-fp-th pf-fp-th-sort pf-fp-th-cats" data-pf-fp-sort="__cats__" scope="col" tabindex="0" role="button"><span class="pf-fp-th-inner"><span class="pf-fp-th-label">categories</span><span class="pf-fp-th-base">in portfolio</span><span class="pf-fp-sort-ind" aria-hidden="true">&#x2195;</span></span></th>'

  # Body rows — brand name first column + awareness cells.
  rows <- vapply(seq_along(brand_codes), function(i) {
    bc  <- brand_codes[i]
    nm  <- brand_label[i]
    is_focal <- identical(bc, focal_brand)
    row_cls  <- paste("pf-fp-row",
                      if (is_focal) "pf-fp-row-focal" else "pf-fp-row-other")
    label_lc <- tolower(nm)
    badge    <- if (is_focal) ' <span class="fn-focal-badge">FOCAL</span>' else ""
    cells <- vapply(cat_codes, function(cc) {
      v <- fp[[cc]][match(bc, fp$Brand)]
      n_cat <- if (length(base_n) > 0 && cc %in% names(base_n)) base_n[[cc]] else NA_integer_
      n_cell <- if (!is.null(v) && !is.na(v) && is.finite(v) &&
                    !is.null(n_cat) && !is.na(n_cat))
                  as.integer(round(v / 100 * n_cat)) else NA_integer_
      n_str <- if (!is.na(n_cell)) sprintf("n=%d", n_cell) else ""

      if (is.null(v) || is.na(v) || !is.finite(v)) {
        sprintf('<td class="pf-fp-td pf-fp-td-na" data-pf-fp-val="" data-pf-fp-col="%s">&mdash;</td>',
                .pf_esc(cc))
      } else {
        # Heat colours are inlined as CSS custom properties so the JS-driven
        # "Show heatmap" toggle can flip them on/off by adding/removing a
        # parent class (see .pf-fp-heatmap-off rule in styling). The cell
        # text colour also lives on the property so contrast tracks the
        # background.
        bg  <- .pf_heat_bg(v, focal_colour)
        fg  <- .pf_heat_fg(v)
        sprintf(
          '<td class="pf-fp-td pf-fp-heat-cell" data-pf-fp-val="%.2f" data-pf-fp-col="%s" style="--pf-fp-bg:%s;--pf-fp-fg:%s;"><span class="pf-fp-pct">%.0f%%</span><span class="pf-fp-n">%s</span></td>',
          v, .pf_esc(cc), bg, fg, v, n_str
        )
      }
    }, character(1))
    cats_n <- presence_count[i]
    cats_cell <- sprintf(
      '<td class="pf-fp-td pf-fp-td-cats" data-pf-fp-val="%d" data-pf-fp-col="__cats__"><span class="pf-fp-cats-num">%d</span><span class="pf-fp-cats-of">/%d</span></td>',
      as.integer(cats_n), as.integer(cats_n), as.integer(total_cats)
    )
    sprintf(
      '<tr class="%s" data-pf-fp-brand="%s" data-pf-fp-focal="%s"><th class="pf-fp-row-label" scope="row"><span class="pf-fp-row-label-text">%s</span>%s</th>%s%s</tr>',
      row_cls, .pf_esc(bc), if (is_focal) "1" else "0",
      .pf_esc(label_lc), badge, paste(cells, collapse = ""), cats_cell
    )
  }, character(1))

  # Brand-column sort header (sort by brand name).
  brand_th <- '<th class="pf-fp-th pf-fp-th-brand pf-fp-th-sort" data-pf-fp-sort="__brand__" scope="col" tabindex="0" role="button"><span class="pf-fp-th-inner"><span class="pf-fp-th-label">brand</span><span class="pf-fp-sort-ind" aria-hidden="true">&#x2195;</span></span></th>'

  # Default state: heatmap on, counts off — matches MA matrix.
  paste0(
    '<div class="pf-fp-table-wrap pf-fp-heatmap-on">',
    '<table class="pf-fp-table" data-pf-focal="', .pf_esc(focal_brand), '">',
    '<thead><tr>', brand_th, paste(ths, collapse = ""), cats_th, '</tr></thead>',
    '<tbody>', paste(rows, collapse = ""), '</tbody>',
    '</table>',
    if (length(suppressed) > 0) sprintf(
      '<p class="pf-fp-suppressed-note">Categories with low base (n &lt; threshold): %s. Values still shown but interpret with caution.</p>',
      .pf_esc(paste(suppressed, collapse = ", "))) else "",
    '</div>'
  )
}
