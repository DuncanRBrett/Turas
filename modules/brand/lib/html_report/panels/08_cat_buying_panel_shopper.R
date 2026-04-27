# ==============================================================================
# BRAND MODULE - CATEGORY BUYING / SHOPPER BEHAVIOUR SUB-TAB
# ==============================================================================
# Renders the 6th sub-tab of the Category Buying panel. Two stacked
# sections: Purchase Location (channels) and Pack Sizes. Each section
# reuses the brands-as-rows / options-as-columns table layout from the
# Loyalty and Distribution tabs (.cb_rel_table_html) so the visual
# contract — sortable headers, CI-band heatmap, "show counts" toggle —
# stays consistent across the panel.
#
# The tab silently hides any section whose engine returned NULL or
# REFUSED. If both are absent the tab itself is suppressed by the parent
# renderer.
#
# Multi-mention semantics: a respondent can select multiple channels or
# multiple pack sizes, so per-brand rows may sum to >100%. The info
# callouts explain this so the values are not misread as single-choice.
#
# VERSION: 1.0
# ==============================================================================

BRAND_CB_SHOPPER_VERSION <- "1.0"


# ==============================================================================
# PUBLIC ENTRY
# ==============================================================================

#' Build the Shopper Behaviour sub-tab for the Category Buying panel
#'
#' @param panel_data List. The same panel_data the parent render uses;
#'   reads \code{shopper_location}, \code{shopper_packsize},
#'   \code{focal_brand}, and \code{brand_labels}.
#' @return Character. HTML fragment for the sub-tab body, or empty string
#'   when both sections are absent.
#' @export
cb_shopper_tab_html <- function(panel_data) {

  loc <- panel_data$shopper_location
  pak <- panel_data$shopper_packsize
  has_loc <- .cb_shop_section_ok(loc)
  has_pak <- .cb_shop_section_ok(pak)
  if (!has_loc && !has_pak) return("")

  buyers_pct_map <- .cb_shop_buyers_pct_map(panel_data$buyer_heaviness)

  parts <- character(0)
  parts <- c(parts, '<div class="cb-section-title">Shopper Behaviour</div>')
  parts <- c(parts,
    '<p style="font-size:12px;color:#64748b;margin:-4px 0 12px;">',
    'Where category buyers shop and what pack sizes they choose. ',
    'Multi-mention questions: a respondent can select more than one ',
    'option, so brand rows may sum to more than 100%.</p>')

  parts <- c(parts, .cb_shop_kpi_chips(loc, pak))

  if (has_loc) {
    parts <- c(parts, .cb_shop_section(
      result         = loc,
      scope          = "shop_loc",
      heading        = "Purchase Location",
      base_label     = "Brand buyers (n=)",
      cat_avg_label  = "Category avg",
      focal          = panel_data$focal_brand,
      brand_labels   = panel_data$brand_labels,
      buyers_pct_map = buyers_pct_map,
      kind_label     = "channel"
    ))
  }
  if (has_pak) {
    parts <- c(parts, .cb_shop_section(
      result         = pak,
      scope          = "shop_pak",
      heading        = "Pack Sizes",
      base_label     = "Brand buyers (n=)",
      cat_avg_label  = "Category avg",
      focal          = panel_data$focal_brand,
      brand_labels   = panel_data$brand_labels,
      buyers_pct_map = buyers_pct_map,
      kind_label     = "pack size"
    ))
  }
  paste(parts, collapse = "\n")
}


# % of category buyers who bought each brand, derived from buyer_heaviness
# loyalty segments (100 - NoBuy_Pct). Mirrors the parent panel's logic so
# the % Buyers column reads identically to the Loyalty / Distribution tabs.
.cb_shop_buyers_pct_map <- function(bh) {
  if (is.null(bh) || identical(bh$status, "REFUSED")) return(NULL)
  loy <- bh$brand_loyalty_segments
  if (is.null(loy) || !"NoBuy_Pct" %in% names(loy) ||
      !"BrandCode" %in% names(loy)) return(NULL)
  stats::setNames(100 - as.numeric(loy$NoBuy_Pct), as.character(loy$BrandCode))
}


#' Build the slim Shopper KPI chips for the Category Context tab
#'
#' Two compact chips ("Most-used channel" + "Most-bought pack") shown on
#' tab 1 of the Category Buying panel. Returns empty string when neither
#' element produced data.
#' @export
cb_shopper_context_chips <- function(panel_data) {
  parts <- character(0)
  loc <- panel_data$shopper_location
  pak <- panel_data$shopper_packsize
  if (.cb_shop_section_ok(loc) && !is.null(loc$top$label)) {
    parts <- c(parts, .cb_shop_chip(
      val = sprintf("%s (%.0f%%)", loc$top$label, loc$top$pct),
      label = "Most-used purchase channel",
      compact = TRUE
    ))
  }
  if (.cb_shop_section_ok(pak) && !is.null(pak$top$label)) {
    parts <- c(parts, .cb_shop_chip(
      val = sprintf("%s (%.0f%%)", pak$top$label, pak$top$pct),
      label = "Most-bought pack size",
      compact = TRUE
    ))
  }
  paste(parts, collapse = "")
}


# ==============================================================================
# INTERNAL: SECTION BUILDER
# ==============================================================================

# A "section" = heading + info callout + controls bar + brands x options
# matrix. Reuses .cb_rel_table_html from the parent panel so the table
# styling and heatmap/sort behaviour match the Loyalty / Distribution tabs.
.cb_shop_section <- function(result, scope, heading, base_label,
                              cat_avg_label, focal, brand_labels,
                              kind_label, buyers_pct_map = NULL) {
  bm <- result$brand_matrix
  if (is.null(bm) || nrow(bm) == 0) {
    return(.cb_shop_refused_block(heading, "no brand-level data available"))
  }
  # Strip the leading category-average row; .cb_rel_table_html computes
  # its own cat-avg row (cross-brand mean + CI band) from the brand rows.
  brand_only <- bm[bm$BrandCode != "__cat__", , drop = FALSE]
  if (nrow(brand_only) == 0) {
    return(.cb_shop_refused_block(heading, "all brands had zero buyers"))
  }

  codes  <- result$category_distribution$Code
  labels <- result$category_distribution$Label
  pct_cols_in <- paste0("Pct_", codes)
  data_df <- brand_only[, c("BrandCode", "Base_n", pct_cols_in), drop = FALSE]
  col_names <- paste0(codes, "_Pct")
  names(data_df)[match(pct_cols_in, names(data_df))] <- col_names

  brands <- as.character(data_df$BrandCode)
  brand_names <- vapply(brands, function(bc) {
    if (!is.null(brand_labels) && bc %in% names(brand_labels)) {
      as.character(brand_labels[[bc]])
    } else tools::toTitleCase(tolower(bc))
  }, character(1))
  base_n_map <- stats::setNames(as.numeric(data_df$Base_n), brands)

  parts <- character(0)
  parts <- c(parts, sprintf('<div class="cb-section-title" style="margin-top:18px;">%s</div>',
                             .cb_esc(heading)))
  parts <- c(parts, .cb_shop_info_callout(scope, kind_label))
  parts <- c(parts, .cb_shop_controls_bar(scope))

  parts <- c(parts, .cb_rel_table_html(
    scope        = scope,
    data_df      = data_df,
    col_names    = col_names,
    seg_codes    = codes,
    seg_labels   = labels,
    brands       = brands,
    brand_names  = brand_names,
    focal        = focal,
    buyers_pct_map = buyers_pct_map,
    base_n_map     = base_n_map,
    base_n         = NULL,
    base_label     = base_label
  ))
  paste(parts, collapse = "\n")
}


# ==============================================================================
# INTERNAL: KPI CHIPS, INFO CALLOUTS, CONTROLS, REFUSALS
# ==============================================================================

.cb_shop_kpi_chips <- function(loc, pak) {
  chips <- character(0)
  if (.cb_shop_section_ok(loc)) {
    chips <- c(chips, .cb_shop_chip(
      val   = sprintf("%s (%.0f%%)", loc$top$label, loc$top$pct),
      label = "Top channel"
    ))
    chips <- c(chips, .cb_shop_chip(
      val   = sprintf("%.2f", loc$hhi),
      label = "Channel HHI (0-1)"
    ))
  }
  if (.cb_shop_section_ok(pak)) {
    chips <- c(chips, .cb_shop_chip(
      val   = sprintf("%s (%.0f%%)", pak$top$label, pak$top$pct),
      label = "Top pack size"
    ))
    chips <- c(chips, .cb_shop_chip(
      val   = sprintf("%.2f", pak$hhi),
      label = "Pack HHI (0-1)"
    ))
  }
  if (length(chips) == 0) return("")
  sprintf('<div class="cb-kpi-strip" style="margin-bottom:14px;">%s</div>',
          paste(chips, collapse = ""))
}


.cb_shop_chip <- function(val, label, compact = FALSE) {
  cls <- if (isTRUE(compact)) "cb-kpi-chip cb-kpi-chip-text" else "cb-kpi-chip"
  sprintf(paste0(
    '<div class="%s">',
    '<div class="cb-kpi-val">%s</div>',
    '<div class="cb-kpi-label">%s</div>',
    '</div>'),
    cls, .cb_esc(val), .cb_esc(label))
}


.cb_shop_info_callout <- function(scope, kind_label) {
  paste0(
    '<details class="cb-info-callout" data-cb-scope="', scope, '">',
    '<summary>&#9432; How to read this section</summary>',
    '<div class="cb-info-body"><ul>',
    '<li>Cells show the <strong>% of each brand\'s buyers</strong> who selected that ',
    .cb_esc(kind_label), ' option.</li>',
    '<li><strong>Multi-mention</strong>: a respondent can pick more than one option, ',
    'so a brand row can sum to more than 100%.</li>',
    '<li><strong>Category avg</strong> row = unweighted mean across the brand rows.</li>',
    '<li><strong>CI band on Category avg</strong> = mean &plusmn;1 SD across brands. ',
    'Roughly 68% of brands fall inside the band when their values are normally distributed.</li>',
    '<li><strong>Heatmap</strong>: green = above upper band (+1 SD), red = below lower band (&minus;1 SD), ',
    'amber = inside the band.</li>',
    '<li><strong>Show counts</strong> toggles segment % &harr; raw weighted N (of brand buyers). ',
    '<strong>Show heatmap</strong> colours cells by CI band. ',
    'Click a column header to sort.</li>',
    '</ul></div></details>')
}


.cb_shop_controls_bar <- function(scope) {
  sprintf(paste0(
    '<div class="cb-controls-bar" data-cb-scope="%s">',
    '<label class="toggle-label">',
    '<input type="checkbox" data-cb-action="showcounts" data-cb-scope="%s"> Show counts',
    '</label>',
    '<label class="toggle-label">',
    '<input type="checkbox" data-cb-action="heatmapmode" data-cb-scope="%s"> Show heatmap',
    '</label>',
    '</div>'),
    scope, scope, scope)
}


.cb_shop_refused_block <- function(heading, reason) {
  sprintf(paste0(
    '<div class="cb-refused" style="margin-top:18px;">',
    '<strong>%s:</strong> %s.</div>'),
    .cb_esc(heading), .cb_esc(reason))
}


.cb_shop_section_ok <- function(x) {
  !is.null(x) && !identical(x$status, "REFUSED")
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Cat Buying Shopper sub-tab loaded (v%s)",
                  BRAND_CB_SHOPPER_VERSION))
}
