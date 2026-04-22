# ==============================================================================
# BRAND MODULE - WORD OF MOUTH PANEL HTML RENDERER
# ==============================================================================
# Emits the WOM tab's HTML fragment. Mirrors the funnel Relationship
# ("Brand Attitude") table visual contract:
#   - Brands as rows, questions as columns
#   - Row 1 = focal brand (accent colour, FOCAL badge, left-border rail)
#   - Row 2 = category average with 95% CI mini-bars per column
#   - Row 3+ = competitor brands, alphabetical
#   - ct-* CSS classes for parity with tabs / funnel / MA
#
# Sub-renderer contract: consumes build_wom_panel_data() output.
#
# Interaction JS: js/brand_wom_panel.js (loaded once per report).
# Initial release (v1.0) renders a static table; the focal-brand dropdown
# and heatmap toggle are scaffolded for the forthcoming JS controller.
#
# VERSION: 1.0
# ==============================================================================

BRAND_WOM_PANEL_VERSION <- "1.0"


#' Build the WOM panel HTML fragment.
#'
#' @param panel_data List from \code{build_wom_panel_data()}.
#' @param category_code Character. Used to scope element ids on the page.
#' @param focal_colour Character. Hex colour for the focal brand.
#'
#' @return Character. A single HTML fragment (string).
#' @export
build_wom_panel_html <- function(panel_data,
                                 category_code = "cat",
                                 focal_colour = "#1A5276") {
  if (is.null(panel_data) || is.null(panel_data$columns) ||
      length(panel_data$brands) == 0) {
    return('<div class="wom-panel-empty">Word of Mouth not available for this category.</div>')
  }

  panel_id <- paste0("wom-", category_code)
  json_payload <- .wom_panel_json(panel_data, focal_colour)

  paste0(
    sprintf('<div class="wom-panel" id="%s" data-focal-colour="%s" data-cat-code="%s">',
            panel_id, .wom_esc(focal_colour), .wom_esc(category_code)),
    sprintf('<script type="application/json" class="wom-panel-data">%s</script>',
            json_payload),
    .wom_controls_bar(panel_data, category_code, focal_colour),
    .wom_table_section(panel_data, focal_colour),
    .wom_chart_placeholder(category_code),
    .wom_insight_box(),
    '</div>'
  )
}


# ==============================================================================
# INTERNAL: CONTROLS BAR (focal dropdown + coloured chips + show chart)
# ==============================================================================

.wom_controls_bar <- function(pd, category_code, focal_colour) {
  brand_codes   <- pd$config$brand_codes %||% character(0)
  brand_names   <- pd$config$brand_names %||% brand_codes
  brand_colours <- pd$config$brand_colours %||% list()
  focal         <- pd$meta$focal_brand_code %||% brand_codes[1]

  # Fallback palette — mirrors cat_buying panel
  palette <- c('#4e79a7', '#f28e2b', '#e15759', '#76b7b2', '#59a14f',
               '#edc948', '#b07aa1', '#ff9da7', '#9c755f', '#bab0ac')
  .resolve_col <- function(bc, idx) {
    if (!is.null(brand_colours[[bc]]) && nzchar(brand_colours[[bc]]))
      return(as.character(brand_colours[[bc]]))
    if (!is.null(focal) && bc == focal && !is.null(focal_colour) &&
        nzchar(focal_colour)) return(as.character(focal_colour))
    palette[((idx - 1) %% length(palette)) + 1]
  }

  # Focal-brand dropdown
  focus_options <- paste(vapply(seq_along(brand_codes), function(i) {
    sel <- if (identical(brand_codes[i], focal)) " selected" else ""
    sprintf('<option value="%s"%s>%s</option>',
            .wom_esc(brand_codes[i]), sel, .wom_esc(brand_names[i]))
  }, character(1)), collapse = "")

  # Coloured chips — toggle row visibility
  chips_html <- paste(vapply(seq_along(brand_codes), function(i) {
    bc  <- brand_codes[i]
    nm  <- brand_names[i]
    col <- .resolve_col(bc, i)
    is_foc <- !is.null(focal) && bc == focal
    badge  <- if (is_foc) ' <span class="fn-focal-badge">FOCAL</span>' else ""
    sprintf(
      '<button type="button" class="col-chip fn-rel-brand-chip active wom-brand-chip" data-wom-action="toggle-row" data-wom-brand="%s" style="--brand-chip-color:%s;background-color:%s;border-color:%s;color:#fff;">%s%s</button>',
      .wom_esc(bc), .wom_esc(col), .wom_esc(col), .wom_esc(col),
      .wom_esc(nm), badge)
  }, character(1)), collapse = "")

  sprintf(
    '<div class="wom-focus-bar">
       <label class="wom-ctl-label">Focal brand</label>
       <select class="wom-focus-select" data-wom-action="focus">%s</select>
       <label class="wom-toggle-label">
         <input type="checkbox" data-wom-action="showchart" data-wom-scope="%s">
         Show chart
       </label>
     </div>
     <div class="wom-brand-picker">
       <span class="wom-ctl-label wom-ctl-label-title">Show brands</span>
       <div class="col-chip-bar" data-wom-scope="%s">%s</div>
     </div>',
    focus_options, .wom_esc(category_code), .wom_esc(category_code), chips_html)
}


# ==============================================================================
# INTERNAL: CHART PLACEHOLDER (hidden until Show chart toggled on)
# ==============================================================================

.wom_chart_placeholder <- function(category_code) {
  sprintf(
    '<section class="wom-chart-section" data-wom-scope="%s" hidden>
       <div class="wom-chart-placeholder">
         <span>Chart coming soon.</span>
       </div>
     </section>',
    .wom_esc(category_code))
}


# ==============================================================================
# INTERNAL: TABLE SECTION
# ==============================================================================

.wom_table_section <- function(pd, focal_colour) {
  paste0(
    '<section class="wom-section wom-table-section">',
    '<div class="wom-table-wrap fn-table-wrap">',
    '<table class="ct-table fn-ct-table wom-table" data-wom-table="1">',
    .wom_table_header(pd$columns),
    '<tbody>',
    .wom_table_rows(pd, focal_colour),
    '</tbody></table></div>',
    '</section>'
  )
}


.wom_table_header <- function(columns) {
  brand_th <- paste0(
    '<th class="ct-th ct-label-col wom-sortable" ',
    'data-wom-action="sort" data-wom-sort-col="brand" ',
    'data-wom-sort-dir="none" ',
    'title="Click to sort A\u2013Z / Z\u2013A" ',
    'style="text-align:left;min-width:160px;cursor:pointer;">',
    '<span>Brand</span><span class="wom-sort-ind"></span></th>')
  base_th <- '<th class="ct-th ct-data-col" style="min-width:70px;">Base</th>'

  col_ths <- paste(vapply(columns, function(col) {
    group_cls <- switch(col$value_type,
      pct  = " wom-th-pct",
      net  = " wom-th-net",
      freq = " wom-th-freq",
      "")
    sprintf(
      '<th class="ct-th ct-data-col wom-th%s" data-wom-col="%s" data-wom-col-type="%s" title="%s">%s</th>',
      group_cls,
      .wom_esc(col$key),
      .wom_esc(col$value_type),
      .wom_esc(col$long_label %||% col$label),
      .wom_esc(col$label))
  }, character(1)), collapse = "")

  paste0('<thead><tr>', brand_th, base_th, col_ths, '</tr></thead>')
}


.wom_table_rows <- function(pd, focal_colour) {
  columns <- pd$columns
  brands  <- pd$brands
  cat_avg <- pd$cat_avg
  focal   <- pd$meta$focal_brand_code

  focal_idx <- which(vapply(brands, function(b) isTRUE(b$is_focal), logical(1)))
  comp_idx  <- setdiff(seq_along(brands), focal_idx)
  if (length(comp_idx) > 0) {
    nm <- tolower(vapply(brands[comp_idx], function(b)
      as.character(b$brand_name %||% b$brand_code), character(1)))
    comp_idx <- comp_idx[order(nm)]
  }

  focal_row <- if (length(focal_idx) > 0)
    .wom_brand_row(brands[[focal_idx[1]]], columns, is_focal = TRUE,
                   focal_colour = focal_colour, pd = pd)
  else ""

  avg_row <- .wom_cat_avg_row(cat_avg, columns, pd = pd)

  comp_rows <- paste(vapply(comp_idx, function(i)
    .wom_brand_row(brands[[i]], columns, is_focal = FALSE,
                   focal_colour = focal_colour, pd = pd),
    character(1)), collapse = "")

  paste0(focal_row, avg_row, comp_rows)
}


# ---- Focal + competitor rows ----

.wom_brand_row <- function(brand, columns, is_focal, focal_colour, pd) {
  row_cls <- paste("ct-row wom-row",
                    if (is_focal) "fn-row-focal wom-row-focal"
                    else         "fn-row-competitor wom-row-competitor")
  row_attrs <- if (is_focal)
    sprintf(' style="--fn-row-accent:%s;" data-locked="1"',
            .wom_esc(focal_colour))
  else ""

  label_txt <- .wom_esc(brand$brand_name %||% brand$brand_code)
  if (is_focal) label_txt <- paste0(label_txt,
    ' <span class="fn-focal-badge">FOCAL</span>')

  focal_cls <- if (is_focal) " fn-rel-td-focal" else ""
  base_cell <- .wom_base_cell(pd$meta$n_unweighted, focal_cls)

  data_cells <- paste(vapply(columns, function(col) {
    v <- brand$values[[col$key]]
    .wom_data_cell(v, col, focal_cls, pd$cat_avg[[col$key]])
  }, character(1)), collapse = "")

  sort_key <- tolower(as.character(brand$brand_name %||% brand$brand_code))
  sprintf('<tr class="%s" data-wom-brand="%s" data-wom-sort-key="%s"%s>%s%s%s</tr>',
    row_cls, .wom_esc(brand$brand_code), .wom_esc(sort_key), row_attrs,
    sprintf('<td class="ct-td ct-label-col%s">%s</td>', focal_cls, label_txt),
    base_cell,
    data_cells)
}


# ---- Category-average row with CI mini-bars ----

.wom_cat_avg_row <- function(cat_avg, columns, pd) {
  cells <- paste(vapply(columns, function(col) {
    stats_block <- cat_avg[[col$key]]
    .wom_cat_avg_cell(stats_block, col)
  }, character(1)), collapse = "")

  paste0(
    '<tr class="ct-row fn-row-avg-all wom-row-avg" data-locked="1">',
    '<td class="ct-td ct-label-col"><em>Category average</em></td>',
    '<td class="ct-td ct-data-col"><span style="color:#94a3b8;font-size:11px;">\u2014</span></td>',
    cells,
    '</tr>'
  )
}


# ---- Individual cells ----

.wom_base_cell <- function(n, focal_cls) {
  if (is.null(n) || is.na(n) || !is.finite(n)) {
    return(sprintf('<td class="ct-td ct-data-col%s ct-na">&mdash;</td>', focal_cls))
  }
  ni <- as.integer(n)
  warn <- ni < 30L
  sprintf('<td class="ct-td ct-data-col%s"><span class="%s">n=%d%s</span></td>',
          focal_cls,
          if (warn) "ct-low-base" else "ct-base-n",
          ni,
          if (warn) " \u26A0" else "")
}


.wom_data_cell <- function(value, col, focal_cls, stats_block) {
  if (is.null(value) || is.na(value) || !is.finite(value)) {
    return(sprintf('<td class="ct-td ct-data-col%s ct-na">&mdash;</td>', focal_cls))
  }
  val_type <- col$value_type
  display  <- .wom_format_value(value, val_type)
  type_cls <- switch(val_type,
    pct  = " wom-td-pct",
    net  = " wom-td-net",
    freq = " wom-td-freq",
    "")
  # Green/amber/red vs category avg \u00b11 SD (matches cat_buying panel):
  #   above avg + SD -> wom-hm-above (green)
  #   below avg - SD -> wom-hm-below (red)
  #   within the band -> wom-hm-near  (amber)
  hm_cls <- .wom_hm_cls(value, stats_block)

  sprintf(
    '<td class="ct-td ct-data-col%s%s%s" data-wom-col="%s" data-wom-val="%.3f"><span class="ct-val">%s</span></td>',
    focal_cls, type_cls, hm_cls,
    .wom_esc(col$key),
    value,
    display)
}


.wom_hm_cls <- function(value, stats_block) {
  if (is.null(stats_block)) return("")
  avg  <- stats_block$mean
  sd_v <- stats_block$sd
  if (!is.finite(value) || !is.finite(avg) ||
      !is.finite(sd_v) || sd_v <= 0) return("")
  if (value > avg + sd_v)      " wom-hm-above"
  else if (value < avg - sd_v) " wom-hm-below"
  else                         " wom-hm-near"
}


.wom_cat_avg_cell <- function(stats_block, col) {
  if (is.null(stats_block) || is.null(stats_block$mean) ||
      is.na(stats_block$mean)) {
    return('<td class="ct-td ct-data-col fn-rel-td-avg wom-td-avg ct-na">&mdash;</td>')
  }
  m      <- stats_block$mean
  lo     <- stats_block$ci_lower
  hi     <- stats_block$ci_upper
  has_ci <- is.finite(lo) && is.finite(hi)
  val_type <- col$value_type
  display  <- .wom_format_value(m, val_type)
  # CI mini-bar: calibrated 0..100 for pct, else to local range.
  ci_bar <- .wom_ci_bar(m, lo, hi, val_type)
  sprintf(
    '<td class="ct-td ct-data-col fn-rel-td-avg wom-td-avg" data-wom-col="%s" data-wom-ci-lo="%s" data-wom-ci-hi="%s"><span class="ct-val">%s</span>%s</td>',
    .wom_esc(col$key),
    if (is.finite(lo)) sprintf("%.3f", lo) else "",
    if (is.finite(hi)) sprintf("%.3f", hi) else "",
    display,
    ci_bar)
}


# ==============================================================================
# INTERNAL: FORMATTING HELPERS
# ==============================================================================

.wom_format_value <- function(value, val_type) {
  switch(val_type,
    pct  = sprintf("%.0f%%", value),
    net  = sprintf("%+.0f", value),  # signed integer percentage points
    freq = sprintf("%.1f", value),
    sprintf("%.1f", value))
}


.wom_ci_bar <- function(mean_val, ci_lo, ci_hi, val_type) {
  if (!is.finite(ci_lo) || !is.finite(ci_hi) || ci_hi <= ci_lo) return("")

  # Scale axis per column type
  axis <- switch(val_type,
    pct  = list(lo = 0,   hi = 100),
    net  = {
      # Net columns: symmetrical band around zero, scaled to the largest
      # |value| present so the zero-point is always at the visual centre.
      span <- max(10, abs(ci_lo), abs(ci_hi), abs(mean_val))
      list(lo = -span, hi = span)
    },
    freq = {
      span <- max(1, ceiling(max(ci_hi, mean_val)))
      list(lo = 0, hi = span)
    },
    list(lo = 0, hi = 100)
  )
  axis_span <- axis$hi - axis$lo
  if (axis_span <= 0) return("")

  pct_fill_left <- 100 * (ci_lo - axis$lo) / axis_span
  pct_fill_w    <- 100 * (ci_hi - ci_lo) / axis_span
  pct_fill_left <- max(0, min(94, pct_fill_left))
  pct_fill_w    <- max(4, min(100 - pct_fill_left, pct_fill_w))
  pct_mean_x    <- max(1, min(99, 100 * (mean_val - axis$lo) / axis_span))

  lo_disp <- .wom_format_value(ci_lo, val_type)
  hi_disp <- .wom_format_value(ci_hi, val_type)

  paste0(
    sprintf('<div class="ma-ci-bar-wrap" title="95%% CI: %s \u2013 %s">',
            lo_disp, hi_disp),
    sprintf('<div class="ma-ci-bar-range" style="left:%.1f%%;width:%.1f%%;"></div>',
            pct_fill_left, pct_fill_w),
    sprintf('<div class="ma-ci-bar-tick" style="left:%.1f%%"></div>',
            pct_mean_x),
    '</div>',
    sprintf('<div class="ma-ci-limits"><span>%s</span><span>%s</span></div>',
            lo_disp, hi_disp))
}




# ==============================================================================
# INTERNAL: INSIGHT BOX (styled like MA)
# ==============================================================================

.wom_insight_box <- function() {
  '<section class="wom-insight-box ma-insight-box" data-wom-stim="wom">
     <div class="ma-insight-box-header">
       <span class="ma-insight-box-title">Insight</span>
       <button type="button" class="ma-insight-box-clear" data-wom-action="clear-insight" title="Clear">&#215;</button>
     </div>
     <textarea class="ma-insight-box-text" placeholder="Write the headline for this table (one or two sentences)\u2026"></textarea>
   </section>'
}


# ==============================================================================
# INTERNAL: HELPERS
# ==============================================================================

.wom_panel_json <- function(pd, focal_colour) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return("{}")
  payload <- list(
    meta    = pd$meta,
    columns = pd$columns,
    brands  = pd$brands,
    cat_avg = pd$cat_avg,
    config  = pd$config,
    focal_colour = focal_colour
  )
  jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null",
                   pretty = FALSE, digits = 6)
}


.wom_esc <- function(x) {
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
