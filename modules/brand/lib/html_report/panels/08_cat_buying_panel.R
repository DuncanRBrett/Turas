# ==============================================================================
# BRAND MODULE - CATEGORY BUYING PANEL ASSEMBLER
# ==============================================================================
# Consumes dirichlet_norms, buyer_heaviness, repertoire (DoP), and
# cat_buying_frequency outputs and emits a self-contained HTML fragment
# for the Category Buying tab per §8 of CAT_BUYING_SPEC_v3.
#
# Panel layout (top → bottom):
#   Brand picker + KPI strip
#   Sub-tab nav (5 tabs — mirrors MA panel visual contract exactly)
#     1. Category Context   — freq + rep tables + avg purchase KPI
#     2. Brand Summary      — brands-as-rows performance table
#     3. Loyalty            — col-chip chips + brands-as-columns matrix + dot chart
#     4. Purchase Dist      — col-chip chips + brands-as-columns matrix + dot chart
#     5. Duplication of Purchase — observed heatmap table only
#
# Sub-renderers:
#   08_cat_buying_panel_styling.R  — CSS
#   08_cat_buying_panel_chart.R    — heatmap + freq/rep helpers
#   08_cat_buying_panel_table.R    — brand performance summary table
#
# Interaction JS: js/brand_cat_buying_panel.js (initCbPanel per panel).
#
# SIZE-EXCEPTION: sequential HTML assembly pipeline. Decomposing further
# would require threading many small strings between helper functions,
# reducing readability of the layout specification.
#
# VERSION: 2.0
# ==============================================================================

BRAND_CB_PANEL_VERSION <- "2.0"

local({
  base <- tryCatch(
    dirname(sys.frame(1)$ofile),
    error = function(e) "modules/brand/lib/html_report/panels"
  )
  for (f in c("08_cat_buying_panel_styling.R",
              "08_cat_buying_panel_chart.R",
              "08_cat_buying_panel_table.R")) {
    fp <- file.path(base, f)
    if (file.exists(fp)) source(fp, local = FALSE)
  }
})

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a)) b else a
if (!exists(".cb_esc", mode = "function")) {
  .cb_esc <- function(x) {
    if (is.null(x) || is.na(x)) return("")
    x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x
  }
}


# ==============================================================================
# PUBLIC ENTRY POINT
# ==============================================================================

#' Render the Category Buying HTML panel
#'
#' Assembles all sub-tab sections into a single HTML fragment. Any upstream
#' \code{REFUSED} element is shown as a refusal block; remaining sections
#' still render.
#'
#' @param panel_data List produced by \code{transform_cat_buying_panel_data()}.
#' @return Character. A single HTML fragment (string).
#' @export
render_cat_buying_panel <- function(panel_data) {
  if (is.null(panel_data)) {
    return('<div class="cb-refused">Category Buying panel data not available.</div>')
  }

  cat_code     <- panel_data$category_code %||% "cat"
  focal        <- panel_data$focal_brand   %||% NULL
  fcol         <- panel_data$focal_colour  %||% "#1A5276"
  t_months     <- panel_data$target_months %||% 3L
  l_months     <- panel_data$longer_months %||% 12L
  dn           <- panel_data$dirichlet_norms
  bh           <- panel_data$buyer_heaviness
  cbf          <- panel_data$cat_buying_frequency
  rep          <- panel_data$repertoire
  brand_labels <- panel_data$brand_labels %||% NULL
  brand_colours <- panel_data$brand_colours %||% list()
  dist_labels  <- panel_data$cat_buying_dist_labels %||% NULL

  has_dn <- !is.null(dn) && !identical(dn$status, "REFUSED")
  has_bh <- !is.null(bh) && !identical(bh$status, "REFUSED")

  panel_id <- paste0("cb-panel-", cat_code)
  parts    <- character(0)

  if (exists("cb_panel_css", mode = "function")) parts <- c(parts, cb_panel_css())

  parts <- c(parts, sprintf(
    '<div class="cb-panel cb-on-context" id="%s" data-focal-colour="%s" style="--cb-focal-colour:%s;">',
    panel_id, .cb_esc(fcol), .cb_esc(fcol)))

  # JSON: per-brand KPI data for focal switcher
  parts <- c(parts, .cb_kpi_json_script(dn, bh, cat_code))

  # JSON: chart data for JS stacked bar renderer
  parts <- c(parts, .cb_chart_data_json(
    dn, bh, focal, fcol, brand_labels, brand_colours, dist_labels, cat_code))

  # Sub-tab navigation
  parts <- c(parts, .cb_sub_tab_nav(cat_code))

  # Brand picker (focal <select> + show/hide chips) — BELOW the sub-tab nav
  parts <- c(parts, .cb_brand_picker(dn, bh, focal, fcol, cat_code,
                                      brand_labels, brand_colours))

  # ----- Tab 1: Category Context (default) -----------------------------------
  parts <- c(parts, '<div class="cb-subtab" data-cb-tab="context">')
  parts <- c(parts, .cb_context_tab(cbf, rep, dn, bh, dist_labels))
  parts <- c(parts, '</div>')

  # ----- Tab 2: Brand Performance Summary ------------------------------------
  parts <- c(parts, '<div class="cb-subtab" data-cb-tab="brands" hidden>')
  parts <- c(parts, .cb_brands_tab(dn, bh, focal, brand_labels, t_months))
  parts <- c(parts, '</div>')

  # Base counts + "% buyers (of cat buyers)" derived from loyalty segments.
  # Used as the Base and "% Buyers" columns on the Loyalty & Distribution tabs.
  total_cat_buyers_n <- if (has_bh && !is.null(bh$category_buyer_mix$n))
    sum(as.integer(bh$category_buyer_mix$n), na.rm = TRUE) else NA_integer_
  loy_df0 <- if (has_bh) bh$brand_loyalty_segments else NULL
  buyers_pct_map <- if (!is.null(loy_df0) && "NoBuy_Pct" %in% names(loy_df0)) {
    setNames(100 - as.numeric(loy_df0$NoBuy_Pct), as.character(loy_df0$BrandCode))
  } else setNames(numeric(0), character(0))
  brand_buyers_n_map <- if (has_bh && !is.null(bh$brand_heaviness) &&
                            "Brand_Buyers_n" %in% names(bh$brand_heaviness)) {
    setNames(as.integer(bh$brand_heaviness$Brand_Buyers_n),
             as.character(bh$brand_heaviness$BrandCode))
  } else setNames(integer(0), character(0))

  # ----- Tab 3: Loyalty Segmentation -----------------------------------------
  loy_seg_codes  <- c("sole", "primary", "secondary", "nobuy")
  loy_seg_labels <- c("Sole buyer", "Primary (>50% SCR)", "Secondary (\u226450%)", "Not bought")
  loy_data       <- if (has_bh) bh$brand_loyalty_segments else NULL
  loy_col_names  <- c("Sole_Pct", "Primary_Pct", "Secondary_Pct", "NoBuy_Pct")

  parts <- c(parts, '<div class="cb-subtab" data-cb-tab="loyalty" hidden>')
  parts <- c(parts, .cb_ma_style_tab(
    scope        = "loyalty",
    data_df      = loy_data,
    col_names    = loy_col_names,
    seg_codes    = loy_seg_codes,
    seg_labels   = loy_seg_labels,
    focal        = focal,
    brand_labels = brand_labels,
    description  = paste0(
      "How category buyers relate to each brand: sole buyer | primary (>50% of their ",
      "purchases) | secondary (\u226450%) | not bought. As % of all category buyers."),
    buyers_pct_map = buyers_pct_map,
    base_n         = total_cat_buyers_n,
    base_label     = "Cat buyers (n=)",
    refused_source = bh))
  parts <- c(parts, '</div>')

  # ----- Tab 4: Purchase Distribution ----------------------------------------
  default_dist <- c("Light (1\u00d7)", "Moderate (2\u00d7)",
                    "Regular (3\u20135\u00d7)", "Frequent (6+\u00d7)")
  dist_seg_labels <- if (!is.null(dist_labels) && length(dist_labels) == 4L)
    as.character(dist_labels) else default_dist
  dist_seg_codes <- c("freq1", "freq2", "freq3to5", "freq6plus")
  dist_col_names <- c("Freq1_Pct", "Freq2_Pct", "Freq3to5_Pct", "Freq6plus_Pct")
  dist_data      <- if (has_bh) bh$brand_freq_dist else NULL

  parts <- c(parts, '<div class="cb-subtab" data-cb-tab="dist" hidden>')
  parts <- c(parts, .cb_ma_style_tab(
    scope        = "dist",
    data_df      = dist_data,
    col_names    = dist_col_names,
    seg_codes    = dist_seg_codes,
    seg_labels   = dist_seg_labels,
    focal        = focal,
    brand_labels = brand_labels,
    description  = "% of brand buyers by purchase frequency in the target window. Category average shown.",
    buyers_pct_map = buyers_pct_map,
    base_n_map     = brand_buyers_n_map,
    base_label     = "Brand buyers (n=)",
    refused_source = bh))
  parts <- c(parts, '</div>')

  # ----- Tab 5: Duplication of Purchase --------------------------------------
  parts <- c(parts, '<div class="cb-subtab" data-cb-tab="dop" hidden>')
  parts <- c(parts, .cb_dop_tab(rep, focal, brand_labels))
  parts <- c(parts, '</div>')

  parts <- c(parts, '</div>') # close .cb-panel
  paste(parts, collapse = "\n")
}


# ==============================================================================
# SUB-TAB NAV
# ==============================================================================

.cb_sub_tab_nav <- function(cat_code) {
  tabs <- list(
    list(key = "context",  label = "Category Context"),
    list(key = "brands",   label = "Brand Summary"),
    list(key = "loyalty",  label = "Loyalty Segmentation"),
    list(key = "dist",     label = "Purchase Distribution"),
    list(key = "dop",      label = "Duplication of Purchase")
  )
  btns <- paste(vapply(tabs, function(t) {
    active <- if (identical(t$key, "context")) " active" else ""
    sprintf(
      '<button type="button" class="cb-subtab-btn%s" data-cb-tab="%s">%s</button>',
      active, t$key, .cb_esc(t$label))
  }, character(1)), collapse = "")
  sprintf('<nav class="cb-subnav">%s</nav>', btns)
}


# ==============================================================================
# TAB CONTENT BUILDERS
# ==============================================================================

.cb_context_tab <- function(cbf, rep, dn = NULL, bh = NULL, dist_labels = NULL) {
  parts <- character(0)
  parts <- c(parts, '<div class="cb-section-title">Category Context</div>')
  parts <- c(parts, '<p style="font-size:12px;color:#64748b;margin:-4px 0 12px;">Category-level purchase frequency and brand repertoire distributions among category buyers.</p>')

  # KPI strip: Avg purchases + Avg brands bought, side-by-side
  kpi_chips <- character(0)
  if (!is.null(dn) && !identical(dn$status, "REFUSED") &&
      !is.null(dn$category_metrics$mean_purchases)) {
    mp <- sprintf("%.1f", dn$category_metrics$mean_purchases)
    kpi_chips <- c(kpi_chips, sprintf(
      '<div class="cb-kpi-chip"><div class="cb-kpi-val">%s</div><div class="cb-kpi-label">Avg purchases / category buyer</div></div>',
      mp))
  }
  if (!is.null(rep) && !identical(rep$status, "REFUSED") &&
      !is.null(rep$mean_repertoire) && !is.na(rep$mean_repertoire)) {
    mr <- sprintf("%.1f", rep$mean_repertoire)
    kpi_chips <- c(kpi_chips, sprintf(
      '<div class="cb-kpi-chip"><div class="cb-kpi-val">%s</div><div class="cb-kpi-label">Avg brands bought / category buyer</div></div>',
      mr))
  }
  if (length(kpi_chips) > 0) {
    parts <- c(parts, sprintf(
      '<div class="cb-kpi-strip" style="margin-bottom:16px;">%s</div>',
      paste(kpi_chips, collapse = "")))
  }

  # Category freq distribution from BRANDPEN3-derived m_vec (same buckets as
  # the Purchase Distribution tab) — replaces the stated-scale cbf distribution.
  cat_fd <- if (!is.null(bh) && !identical(bh$status, "REFUSED"))
    bh$category_freq_dist else NULL

  if (exists("cb_freq_repertoire_tables_html", mode = "function")) {
    parts <- c(parts, cb_freq_repertoire_tables_html(cat_fd, rep, dist_labels))
  }
  paste(parts, collapse = "\n")
}


.cb_brands_tab <- function(dn, bh, focal, brand_labels, t_months) {
  parts <- character(0)
  parts <- c(parts, '<div class="cb-section-title">Brand Performance Summary</div>')
  parts <- c(parts,
    '<p style="font-size:12px;color:#64748b;margin:-4px 0 8px;">Penetration and volume share are based on BRANDPEN3 purchase counts after reconciliation. SCR = share of category requirement (loyalty metric).</p>')
  has_dn <- !is.null(dn) && !identical(dn$status, "REFUSED")
  has_bh <- !is.null(bh) && !identical(bh$status, "REFUSED")

  # Info callout — column definitions & how to read the table
  cat_mean_purch <- if (has_dn && !is.null(dn$category_metrics$mean_purchases))
    dn$category_metrics$mean_purchases else NA_real_
  vol_note <- if (!is.na(cat_mean_purch))
    sprintf("<strong>Vol share</strong> = (Pen \u00d7 Avg purch.) \u00f7 %.1f (category mean).",
            cat_mean_purch)
  else "<strong>Vol share</strong> requires category mean purchases."
  parts <- c(parts, paste0(
    '<details class="cb-info-callout" data-cb-scope="brands">',
    '<summary>&#9432; How to read this table</summary>',
    '<div class="cb-info-body">',
    '<ul>',
    '<li><strong>Pen</strong> = % of respondents who bought the brand (BRANDPEN3, reconciled).</li>',
    '<li><strong>Avg purch.</strong> = mean times bought per brand buyer.</li>',
    '<li><strong>SCR obs</strong> = share of category requirement (loyalty).</li>',
    '<li>', vol_note, '</li>',
    '<li><strong>CI band</strong> on Category avg = \u00b11 SD across brands.</li>',
    '<li><strong>Heatmap</strong>: green = above upper CI band, red = below lower CI band, amber = inside the band.</li>',
    '<li>Click a column header to sort brands.</li>',
    '</ul>',
    '</div>',
    '</details>'))

  # Controls bar: show chart + show heatmap (both off by default)
  parts <- c(parts,
    '<div class="cb-controls-bar" data-cb-scope="brands">',
    '  <label class="toggle-label">',
    '    <input type="checkbox" data-cb-action="showchart" data-cb-scope="brands"> Show chart',
    '  </label>',
    '  <label class="toggle-label">',
    '    <input type="checkbox" data-cb-action="heatmapmode" data-cb-scope="brands"> Show heatmap',
    '  </label>',
    '</div>')

  if (has_dn && exists("cb_brand_freq_scr_table_html", mode = "function")) {
    parts <- c(parts, cb_brand_freq_scr_table_html(
      dn$norms_table,
      focal_brand      = focal,
      brand_labels     = brand_labels,
      brand_heaviness  = if (has_bh) bh$brand_heaviness else NULL,
      category_metrics = dn$category_metrics,
      target_months    = t_months))
  } else if (!has_dn) {
    parts <- c(parts, .cb_refused_block(dn, "Brand performance summary"))
  }

  # Chart placeholder (hidden until Show chart is checked) — BELOW the table.
  # Column selector + single bar chart.
  parts <- c(parts,
    '<div class="cb-brands-chart-area" data-cb-scope="brands" hidden>',
    '  <div class="cb-brands-chart-ctl">',
    '    <label class="cb-brands-chart-ctl-label">Column</label>',
    '    <select class="cb-brands-chart-col" data-cb-action="brandschart-col">',
    '      <option value="pen" selected>Penetration</option>',
    '      <option value="avg">Avg purchases</option>',
    '      <option value="vol">Vol share</option>',
    '      <option value="scr">SCR obs</option>',
    '    </select>',
    '  </div>',
    '  <div class="cb-brands-chart" data-cb-brands-chart="brands"></div>',
    '</div>')

  paste(parts, collapse = "\n")
}


#' Build a Brand Attitude-style sub-tab (loyalty or dist):
#' brand chips + brands-as-rows table + emphasis chips + stacked bar chart.
#' @keywords internal
.cb_ma_style_tab <- function(scope, data_df, col_names, seg_codes, seg_labels,
                              focal, brand_labels, description,
                              buyers_pct_map = NULL,
                              base_n_map     = NULL,
                              base_n         = NULL,
                              base_label     = "Base (n=)",
                              refused_source = NULL) {
  parts <- character(0)
  parts <- c(parts, sprintf(
    '<p style="font-size:12px;color:#64748b;margin:4px 0 10px;">%s</p>',
    .cb_esc(description)))

  if (is.null(data_df) || nrow(data_df) == 0) {
    parts <- c(parts, .cb_refused_block(refused_source,
      if (scope == "loyalty") "Loyalty segmentation" else "Purchase distribution"))
    return(paste(parts, collapse = "\n"))
  }

  brands <- as.character(data_df$BrandCode)
  brand_names <- vapply(brands, function(bc) {
    lbl_fn <- if (exists(".cb_brand_lbl", mode = "function")) .cb_brand_lbl else
      function(code, bl) tools::toTitleCase(tolower(as.character(code)))
    lbl_fn(bc, brand_labels)
  }, character(1))

  # Info callout
  parts <- c(parts, .cb_ma_info_callout(scope))

  # Controls bar: show chart + show counts + show heatmap (pin/export relocated
  # here by JS, right-aligned via .cb-toolbar-relocated).
  parts <- c(parts, sprintf(paste0(
    '<div class="cb-controls-bar" data-cb-scope="%s">',
    '<label class="toggle-label">',
    '<input type="checkbox" checked data-cb-action="showchart" data-cb-scope="%s"> Show chart',
    '</label>',
    '<label class="toggle-label">',
    '<input type="checkbox" data-cb-action="showcounts" data-cb-scope="%s"> Show counts',
    '</label>',
    '<label class="toggle-label">',
    '<input type="checkbox" data-cb-action="heatmapmode" data-cb-scope="%s"> Show heatmap',
    '</label>',
    '</div>'),
    scope, scope, scope, scope))

  # Table: brands-as-rows, segments-as-columns (matches Brand Attitude orientation)
  parts <- c(parts, .cb_rel_table_html(
    scope, data_df, col_names, seg_codes, seg_labels,
    brands, brand_names, focal,
    buyers_pct_map = buyers_pct_map,
    base_n_map     = base_n_map,
    base_n         = base_n,
    base_label     = base_label))

  # Emphasis chips + stacked bar chart area (JS renders into fn-rel-chart div)
  parts <- c(parts, .cb_rel_emphasis_chips(scope, seg_codes, seg_labels))
  parts <- c(parts, sprintf(
    '<div class="fn-rel-chart-area" data-cb-scope="%s">
  <div class="fn-rel-chart" data-cb-stacked-chart="%s"></div>
</div>', scope, scope))

  paste(parts, collapse = "\n")
}


# Scope-specific info callout (loyalty vs dist)
.cb_ma_info_callout <- function(scope) {
  body <- if (identical(scope, "loyalty")) {
    paste0(
      '<ul>',
      '<li><strong>Sole buyer</strong> = bought this brand and no other brand in the category.</li>',
      '<li><strong>Primary (&gt;50% SCR)</strong> = this brand is &gt;50% of the buyer\u2019s category purchases (but they also buy other brands).</li>',
      '<li><strong>Secondary (\u226450%)</strong> = bought this brand, but another brand takes the majority of their category spend.</li>',
      '<li><strong>Not bought</strong> = category buyer who did not buy this brand in the target window.</li>',
      '<li><strong>% Buyers</strong> = % of category buyers who bought the brand (Sole + Primary + Secondary).</li>',
      '<li><strong>CI band</strong> on Category avg = \u00b11 SD across brands. Heatmap: green = above upper band, red = below lower band, amber = inside band.</li>',
      '<li><strong>Show counts</strong> toggles segment % \u2194 raw weighted N (of category buyers). <strong>Show heatmap</strong> colours segment cells by CI band.</li>',
      '</ul>')
  } else {
    paste0(
      '<ul>',
      '<li>Segments are buckets of purchase <em>frequency</em> among this brand\u2019s buyers over the target window.</li>',
      '<li><strong>% Buyers</strong> = % of category buyers who bought the brand (for context).</li>',
      '<li><strong>Base (n=)</strong> = weighted count of this brand\u2019s buyers.</li>',
      '<li><strong>CI band</strong> on Category avg = \u00b11 SD across brands. Heatmap: green = above upper band, red = below lower band, amber = inside band.</li>',
      '<li><strong>Show counts</strong> toggles segment % \u2194 raw weighted N (of brand buyers). <strong>Show heatmap</strong> colours segment cells by CI band.</li>',
      '</ul>')
  }
  paste0(
    '<details class="cb-info-callout" data-cb-scope="', scope, '">',
    '<summary>&#9432; How to read this tab</summary>',
    '<div class="cb-info-body">', body, '</div>',
    '</details>')
}


.cb_dop_tab <- function(rep, focal, brand_labels) {
  parts <- character(0)
  parts <- c(parts, '<div class="cb-section-title">Duplication of Purchase</div>')
  parts <- c(parts, paste0(
    '<p style="font-size:12px;color:#64748b;margin:-4px 0 8px;">',
    'Read across a row: of this brand\'s buyers, what % also bought each column brand ',
    'in the target window. Category avg is shown first; cells shaded by column CI band ',
    '(green above +1 SD, amber inside \u00b11 SD, red below \u22121 SD).</p>'))
  obs_mat <- rep$crossover_matrix %||% NULL
  if (!is.null(obs_mat) && exists("cb_dop_heatmap_html", mode = "function")) {
    parts <- c(parts, cb_dop_heatmap_html(obs_mat, NULL, focal,
                                           brand_labels = brand_labels,
                                           observed     = TRUE))
  } else {
    parts <- c(parts, '<p style="font-size:12px;color:#94a3b8;">Duplication of purchase requires BRANDPEN3 data.</p>')
  }
  paste(parts, collapse = "\n")
}


# ==============================================================================
# CONTROLS BAR (MA-style: col-chip brand chips + show chart toggle)
# ==============================================================================

.cb_controls_bar <- function(scope, brands, brand_names, focal) {
  chips_html <- paste(vapply(seq_along(brands), function(i) {
    bc  <- brands[i]
    nm  <- brand_names[i]
    sprintf(
      '<button type="button" class="col-chip" data-cb-scope="%s" data-cb-brand="%s">%s</button>',
      .cb_esc(scope), .cb_esc(bc), .cb_esc(nm))
  }, character(1)), collapse = "")

  sprintf(
    '<div class="cb-controls-bar">
  <div class="cb-ctl-group">
    <span class="cb-ctl-label">Show brands</span>
    <div class="ma-chip-row col-chip-bar" data-cb-scope="%s">%s</div>
  </div>
  <label class="toggle-label">
    <input type="checkbox" checked data-cb-action="showchart" data-cb-scope="%s">
    Show chart
  </label>
</div>',
    scope, chips_html, scope)
}


# ==============================================================================
# BRAND ATTITUDE-STYLE TABLE & CHART HELPERS
# ==============================================================================

# Per-tab brand visibility chips ("Brands: A [FOCAL]  B  C")
.cb_rel_brand_chips <- function(scope, brands, brand_names, focal) {
  chips <- paste(vapply(seq_along(brands), function(i) {
    bc    <- brands[i]
    nm    <- brand_names[i]
    is_foc <- !is.null(focal) && bc == focal
    badge  <- if (is_foc) ' <span class="fn-focal-badge">FOCAL</span>' else ""
    sprintf(
      '<button type="button" class="col-chip fn-rel-brand-chip active" data-cb-scope="%s" data-cb-brand="%s">%s%s</button>',
      .cb_esc(scope), .cb_esc(bc), .cb_esc(nm), badge)
  }, character(1)), collapse = "")
  sprintf(
    '<div class="cb-ctl-row"><span class="cb-ctl-label">Brands:</span><div class="col-chip-bar">%s</div></div>',
    chips)
}


# Brands-as-rows, segments-as-columns table (Brand Attitude orientation)
.cb_rel_table_html <- function(scope, data_df, col_names, seg_codes, seg_labels,
                                brands, brand_names, focal,
                                buyers_pct_map = NULL,
                                base_n_map     = NULL,
                                base_n         = NULL,
                                base_label     = "Base (n=)") {
  # Heatmap CI-band classifier — same logic as Brand Summary.
  .hm_cls <- function(v, avg, sd_v) {
    if (is.na(v) || is.na(avg) || is.na(sd_v) || sd_v == 0) return("cb-hm-near")
    if (v > avg + sd_v) "cb-hm-above"
    else if (v < avg - sd_v) "cb-hm-below"
    else "cb-hm-near"
  }
  fmt_pct <- function(v) if (!is.na(v)) sprintf("%.0f%%", v) else "\u2014"
  fmt_n   <- function(v) {
    if (is.null(v) || is.na(v)) return("\u2014")
    if (v >= 1000) format(round(v), big.mark = ",", scientific = FALSE) else sprintf("%d", as.integer(round(v)))
  }

  # Header: Brand | % Buyers | Base (n=) | seg1 | seg2 | ...
  # Columns 1..(2+nSeg) are sortable (click header → sort by data-v).
  seg_ths <- paste(vapply(seq_along(seg_codes), function(si) {
    sprintf(paste0(
      '<th class="ct-th ct-data-col cb-sortable" ',
      'data-cb-seg="%s" data-cb-sort-col="%d" data-cb-sort-dir="none">',
      '<span class="cb-th-label">%s</span>',
      '<span class="cb-sort-ind"></span></th>'),
      .cb_esc(seg_codes[si]), 2L + si, .cb_esc(seg_labels[si]))
  }, character(1)), collapse = "")

  header_html <- sprintf(paste0(
    '<tr><th class="ct-th ct-label-col">Brand</th>',
    '<th class="ct-th ct-data-col cb-col-buyers cb-sortable" ',
    'data-cb-sort-col="1" data-cb-sort-dir="none">',
    '<span class="cb-th-label">%% Buyers</span>',
    '<span class="cb-sort-ind"></span></th>',
    '<th class="ct-th ct-data-col cb-col-base cb-sortable" ',
    'data-cb-sort-col="2" data-cb-sort-dir="none">',
    '<span class="cb-th-label">%s</span>',
    '<span class="cb-sort-ind"></span></th>',
    '%s</tr>'),
    .cb_esc(base_label), seg_ths)

  # Per-column category avg & SD across brands (for CI band & heatmap)
  cat_avgs <- vapply(col_names, function(cn) {
    if (!cn %in% names(data_df)) return(NA_real_)
    mean(as.numeric(data_df[[cn]]), na.rm = TRUE)
  }, numeric(1))
  cat_sds <- vapply(col_names, function(cn) {
    if (!cn %in% names(data_df)) return(NA_real_)
    sd(as.numeric(data_df[[cn]]), na.rm = TRUE)
  }, numeric(1))

  # Category avg row — CI band shown on seg cells (avg ± sd)
  avg_seg_cells <- paste(vapply(seq_along(col_names), function(si) {
    v  <- cat_avgs[si]
    sd <- cat_sds[si]
    ci <- if (!is.na(v) && !is.na(sd)) sprintf(" <span class=\"cb-ci-band\">\u00b1%.0f</span>", sd) else ""
    sprintf('<td class="ct-td ct-data-col"><span class="cb-val-pct">%s</span>%s</td>',
            fmt_pct(v), ci)
  }, character(1)), collapse = "")
  avg_row <- sprintf(
    '<tr class="ct-row fn-row-avg-all cb-rel-row cb-avg-row"><td class="ct-td ct-label-col">Category avg</td><td class="ct-td ct-data-col cb-col-buyers">\u2014</td><td class="ct-td ct-data-col cb-col-base">\u2014</td>%s</tr>',
    avg_seg_cells)

  order_idx <- if (!is.null(focal) && focal %in% brands) {
    c(which(brands == focal), which(brands != focal))
  } else seq_along(brands)
  ord_brands <- brands[order_idx]
  ord_names  <- brand_names[order_idx]

  rows_html <- paste(vapply(seq_along(ord_brands), function(i) {
    bc      <- ord_brands[i]
    nm      <- ord_names[i]
    is_foc  <- !is.null(focal) && bc == focal
    row_cls <- if (is_foc)
      "ct-row fn-rel-row fn-row-focal cb-rel-row"
    else
      "ct-row fn-rel-row cb-rel-row"
    badge <- if (is_foc) '<span class="fn-focal-badge">FOCAL</span>' else ""

    # % Buyers (of cat buyers) and Base N
    buyers_pct <- if (!is.null(buyers_pct_map) && bc %in% names(buyers_pct_map))
      as.numeric(buyers_pct_map[[bc]]) else NA_real_
    base_val <- if (!is.null(base_n_map) && bc %in% names(base_n_map))
      as.numeric(base_n_map[[bc]])
    else if (!is.null(base_n)) as.numeric(base_n)
    else NA_real_

    buyers_cell <- sprintf(
      '<td class="ct-td ct-data-col cb-col-buyers" data-v="%s">%s</td>',
      if (!is.na(buyers_pct)) sprintf("%.4f", buyers_pct) else "",
      fmt_pct(buyers_pct))
    base_cell <- sprintf(
      '<td class="ct-td ct-data-col cb-col-base" data-v="%s">%s</td>',
      if (!is.null(base_val) && !is.na(base_val)) sprintf("%.4f", base_val) else "",
      fmt_n(base_val))

    data_cells <- paste(vapply(seq_along(col_names), function(si) {
      cn  <- col_names[si]
      ri  <- which(data_df$BrandCode == bc)
      v <- if (length(ri) == 1 && cn %in% names(data_df))
        as.numeric(data_df[[cn]][ri]) else NA_real_
      # Seg N = segment % × base N / 100 (approx weighted count)
      n_cell <- if (!is.na(v) && !is.na(base_val)) v * base_val / 100 else NA_real_
      hm <- .hm_cls(v, cat_avgs[si], cat_sds[si])
      data_attrs <- sprintf(' data-v="%s" data-pct="%s" data-n="%s"',
                            if (!is.na(v)) sprintf("%.4f", v) else "",
                            fmt_pct(v),
                            fmt_n(n_cell))
      n_label <- if (!is.na(n_cell)) paste0("n=", fmt_n(n_cell)) else "n=\u2014"
      sprintf(
        paste0('<td class="ct-td ct-data-col cb-seg-cell %s"%s>',
               '<span class="cb-val-pct">%s</span>',
               '<span class="cb-val-n" hidden>%s</span></td>'),
        hm, data_attrs, fmt_pct(v), n_label)
    }, character(1)), collapse = "")
    sprintf(
      '<tr class="%s" data-cb-brand="%s"><td class="ct-td ct-label-col">%s %s</td>%s%s%s</tr>',
      row_cls, .cb_esc(bc), .cb_esc(nm), badge,
      buyers_cell, base_cell, data_cells)
  }, character(1)), collapse = "\n")

  sprintf(
    '<section class="cb-rel-section" data-cb-scope="%s">
  <div class="ma-table-wrap" style="overflow-x:auto;">
    <table class="ct-table cb-rel-table">
      <thead>%s</thead>
      <tbody>%s%s</tbody>
    </table>
  </div>
</section>',
    scope, header_html, avg_row, rows_html)
}


# "Emphasise: All | Seg1 | Seg2 …" chips
.cb_rel_emphasis_chips <- function(scope, seg_codes, seg_labels) {
  all_chip <- sprintf(
    '<button type="button" class="col-chip cb-rel-seg-chip active" data-cb-scope="%s" data-cb-emphasis="all">All</button>',
    .cb_esc(scope))
  seg_chips <- paste(vapply(seq_along(seg_codes), function(i) {
    sprintf(
      '<button type="button" class="col-chip cb-rel-seg-chip" data-cb-scope="%s" data-cb-emphasis="%s">%s</button>',
      .cb_esc(scope), .cb_esc(seg_codes[i]), .cb_esc(seg_labels[i]))
  }, character(1)), collapse = "")
  sprintf(
    '<div class="cb-emphasis-row">Emphasise: %s%s</div>',
    all_chip, seg_chips)
}


# ==============================================================================
# MATRIX TABLE (legacy — brands-as-columns format kept for backwards compat)
# ==============================================================================

.cb_matrix_table_html <- function(scope, data_df, col_names, seg_codes,
                                   seg_labels, brands, brand_names, focal) {
  # Column order: focal first
  order_idx <- if (!is.null(focal) && focal %in% brands) {
    c(which(brands == focal), which(brands != focal))
  } else {
    seq_along(brands)
  }
  ord_brands <- brands[order_idx]
  ord_names  <- brand_names[order_idx]

  # Header
  brand_ths <- paste(vapply(seq_along(ord_brands), function(i) {
    bc  <- ord_brands[i]
    nm  <- ord_names[i]
    foc_cls <- if (!is.null(focal) && bc == focal) " cb-focal-th" else ""
    badge   <- if (!is.null(focal) && bc == focal)
      '<span class="ma-focal-badge">FOCAL</span>' else ""
    after_focal <- if (!is.null(focal) && bc == focal) {
      '<th class="ct-th ct-data-col cb-th-catavg" data-cb-brand="__avg__"><div class="ct-header-text">Cat avg</div></th>'
    } else ""
    paste0(sprintf(
      '<th class="ct-th ct-data-col cb-th-brand%s" data-cb-brand="%s"><div class="ct-header-text">%s<span class="ma-brand-name">%s</span></div></th>',
      foc_cls, .cb_esc(bc), badge, .cb_esc(nm)),
      after_focal)
  }, character(1)), collapse = "")

  # Compute category averages per segment
  cat_avgs <- vapply(col_names, function(cn) {
    if (!cn %in% names(data_df)) return(NA_real_)
    mean(as.numeric(data_df[[cn]]), na.rm = TRUE)
  }, numeric(1))

  # Rows (one per segment)
  rows_html <- paste(vapply(seq_along(seg_codes), function(si) {
    seg_code  <- seg_codes[si]
    seg_label <- seg_labels[si]
    col_nm    <- col_names[si]
    cat_avg   <- cat_avgs[si]

    data_cells <- paste(vapply(seq_along(ord_brands), function(i) {
      bc      <- ord_brands[i]
      is_foc  <- !is.null(focal) && bc == focal
      foc_cls <- if (is_foc) " cb-focal-td" else ""
      bi_orig <- which(data_df$BrandCode == bc)
      val_txt <- if (length(bi_orig) == 1 && col_nm %in% names(data_df) &&
                     !is.na(data_df[[col_nm]][bi_orig])) {
        sprintf("%.0f%%", data_df[[col_nm]][bi_orig])
      } else "\u2014"
      after_focal <- if (is_foc) {
        avg_txt <- if (!is.na(cat_avg)) sprintf("%.0f%%", cat_avg) else "\u2014"
        sprintf('<td class="ct-td ct-data-col cb-td-catavg" data-cb-brand="__avg__"><span class="ct-val">%s</span></td>',
                avg_txt)
      } else ""
      paste0(sprintf(
        '<td class="ct-td ct-data-col%s" data-cb-brand="%s"><span class="ct-val">%s</span></td>',
        foc_cls, .cb_esc(bc), val_txt),
        after_focal)
    }, character(1)), collapse = "")

    sprintf(
      '<tr class="ct-row cb-matrix-row" data-cb-row-code="%s">
    <td class="ct-td ct-label-col">
      <label class="cb-row-toggle"><input type="checkbox" class="cb-row-active-cb" data-cb-scope="%s" data-cb-row-code="%s" checked><span class="cb-row-label-text">%s</span></label>
    </td>
    %s
  </tr>',
      .cb_esc(seg_code), .cb_esc(scope), .cb_esc(seg_code),
      .cb_esc(seg_label), data_cells)
  }, character(1)), collapse = "\n")

  sprintf(
    '<section class="ma-section cb-matrix-section" data-cb-scope="%s">
  <div class="ma-table-wrap">
    <table class="ct-table cb-matrix-table">
      <thead><tr>
        <th class="ct-th ct-label-col">Segment</th>
        %s
      </tr></thead>
      <tbody>%s</tbody>
    </table>
  </div>
</section>',
    scope, brand_ths, rows_html)
}


# ==============================================================================
# CHART DATA JSON (for JS dot chart renderer)
# ==============================================================================

.cb_chart_data_json <- function(dn, bh, focal, fcol, brand_labels,
                                 brand_colours = list(),
                                 dist_labels, cat_code) {
  has_bh <- !is.null(bh) && !identical(bh$status, "REFUSED")
  lbl_fn <- if (exists(".cb_brand_lbl", mode = "function")) .cb_brand_lbl else
    function(code, bl) tools::toTitleCase(tolower(as.character(code)))

  # All brand codes in play
  codes <- character(0)
  if (!is.null(dn) && !identical(dn$status, "REFUSED") && !is.null(dn$norms_table))
    codes <- c(codes, as.character(dn$norms_table$BrandCode))
  if (has_bh && !is.null(bh$brand_heaviness))
    codes <- c(codes, as.character(bh$brand_heaviness$BrandCode))
  codes <- unique(codes)
  if (length(codes) == 0) return("")

  names_vec <- vapply(codes, function(bc) lbl_fn(bc, brand_labels), character(1))

  # Loyalty block
  loy_codes  <- c("sole", "primary", "secondary", "nobuy")
  loy_labels <- c("Sole buyer", "Primary (>50% SCR)", "Secondary (\u226450%)", "Not bought")
  loy_cols   <- c("Sole_Pct", "Primary_Pct", "Secondary_Pct", "NoBuy_Pct")
  loy_block  <- .cb_chart_block(
    bh, "brand_loyalty_segments", codes, loy_codes, loy_labels, loy_cols, has_bh)

  # Dist block
  default_dl <- c("Light (1\u00d7)", "Moderate (2\u00d7)",
                   "Regular (3\u20135\u00d7)", "Frequent (6+\u00d7)")
  dist_seg_labels <- if (!is.null(dist_labels) && length(dist_labels) == 4L)
    as.character(dist_labels) else default_dl
  dist_codes <- c("freq1", "freq2", "freq3to5", "freq6plus")
  dist_cols  <- c("Freq1_Pct", "Freq2_Pct", "Freq3to5_Pct", "Freq6plus_Pct")
  dist_block <- .cb_chart_block(
    bh, "brand_freq_dist", codes, dist_codes, dist_seg_labels, dist_cols, has_bh)

  # Brand colours map (only for brands with an explicit hex)
  colours_map <- list()
  if (!is.null(brand_colours) && length(brand_colours) > 0) {
    for (bc in codes) {
      if (!is.null(brand_colours[[bc]]) && nzchar(brand_colours[[bc]])) {
        colours_map[[bc]] <- as.character(brand_colours[[bc]])
      }
    }
  }

  payload <- list(
    brandCodes   = as.list(codes),
    brandNames   = as.list(unname(names_vec)),
    brandColours = colours_map,
    focalBrand   = focal %||% "",
    focalColour  = fcol %||% "#1A5276",
    loyalty      = loy_block,
    dist         = dist_block
  )

  json_str <- tryCatch(
    jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null",
                     pretty = FALSE, digits = 4),
    error = function(e) "{}"
  )
  sprintf(
    '<script type="application/json" class="cb-panel-chart-data">%s</script>',
    json_str)
}


.cb_chart_block <- function(bh, df_name, codes, seg_codes, seg_labels,
                              col_names, has_bh) {
  df <- if (has_bh) bh[[df_name]] else NULL
  values <- lapply(codes, function(bc) {
    if (is.null(df)) return(as.list(rep(NA_real_, length(seg_codes))))
    ri <- which(df$BrandCode == bc)
    if (length(ri) != 1) return(as.list(rep(NA_real_, length(seg_codes))))
    as.list(unname(vapply(col_names, function(cn) {
      v <- df[[cn]][ri]
      if (is.null(v) || is.na(v)) NA_real_ else as.numeric(v)
    }, numeric(1))))
  })
  names(values) <- codes

  cat_avgs <- unname(vapply(col_names, function(cn) {
    if (is.null(df) || !cn %in% names(df)) return(NA_real_)
    mean(as.numeric(df[[cn]]), na.rm = TRUE)
  }, numeric(1)))

  list(
    codes  = as.list(seg_codes),
    labels = as.list(seg_labels),
    values = values,
    catAvg = as.list(cat_avgs)
  )
}


# ==============================================================================
# SHARED SECTION BUILDERS (brand picker, KPI strip, KPI JSON, refused block)
# ==============================================================================

.cb_kpi_strip <- function(dn, bh, cbf, rep = NULL, fcol, focal, t_months) {
  chips <- character(0)

  pct_b <- if (!is.null(cbf) && !identical(cbf$status, "REFUSED") &&
                !is.null(cbf$pct_buyers) && !is.na(cbf$pct_buyers))
    sprintf("%.0f%%", cbf$pct_buyers) else "\u2014"
  chips <- c(chips, sprintf(
    '<div class="cb-kpi-chip"><div class="cb-kpi-val">%s</div><div class="cb-kpi-label">%% Category buyers</div></div>',
    pct_b))

  if (!is.null(dn) && !identical(dn$status, "REFUSED") &&
      !is.null(dn$category_metrics$mean_purchases)) {
    mp_val <- sprintf("%.1f", dn$category_metrics$mean_purchases)
    chips <- c(chips, sprintf(
      '<div class="cb-kpi-chip"><div class="cb-kpi-val">%s</div><div class="cb-kpi-label">Mean purchases / buyer (%dm)</div></div>',
      mp_val, t_months))
  }

  if (!is.null(rep) && !identical(rep$status, "REFUSED") &&
      !is.null(rep$mean_repertoire) && !is.na(rep$mean_repertoire)) {
    mr_txt <- sprintf("%.1f", rep$mean_repertoire)
    chips <- c(chips, sprintf(
      '<div class="cb-kpi-chip muted"><div class="cb-kpi-val muted">%s</div><div class="cb-kpi-label">Avg brands bought / buyer</div></div>',
      mr_txt))
  }

  if (!is.null(dn) && !identical(dn$status, "REFUSED")) {
    ms      <- dn$metrics_summary
    scr_val <- if (!is.null(ms$focal_scr_obs) && !is.na(ms$focal_scr_obs))
      sprintf("%.0f%%", ms$focal_scr_obs) else "\u2014"
    scr_exp <- if (!is.null(ms$focal_scr_exp) && !is.na(ms$focal_scr_exp))
      sprintf("exp %.0f%%", ms$focal_scr_exp) else ""
    chips <- c(chips, sprintf(
      '<div class="cb-kpi-chip green" data-kpi="scr"><div class="cb-kpi-val green" data-kpi-val>%s</div><div class="cb-kpi-label">Focal SCR <span data-kpi-sub>%s</span></div></div>',
      scr_val, if (nzchar(scr_exp)) sprintf("(%s)", scr_exp) else ""))

    loy_val <- if (!is.null(ms$focal_loyal_obs) && !is.na(ms$focal_loyal_obs))
      sprintf("%.0f%%", ms$focal_loyal_obs) else "\u2014"
    loy_exp <- if (!is.null(ms$focal_loyal_exp) && !is.na(ms$focal_loyal_exp))
      sprintf("exp %.0f%%", ms$focal_loyal_exp) else ""
    chips <- c(chips, sprintf(
      '<div class="cb-kpi-chip" data-kpi="loyal"><div class="cb-kpi-val" data-kpi-val>%s</div><div class="cb-kpi-label">Focal 100%%-loyal <span data-kpi-sub>%s</span></div></div>',
      loy_val, if (nzchar(loy_exp)) sprintf("(%s)", loy_exp) else ""))
  }

  if (!is.null(bh) && !identical(bh$status, "REFUSED")) {
    nmi_val   <- bh$metrics_summary$focal_nmi %||% NA
    nmi_txt   <- if (!is.na(nmi_val)) sprintf("%.0f", nmi_val) else "\u2014"
    nmi_arrow <- if (!is.na(nmi_val)) {
      if (nmi_val < 85) " \u2193" else if (nmi_val > 115) " \u2191" else " \u2192"
    } else ""
    chips <- c(chips, sprintf(
      '<div class="cb-kpi-chip amber" data-kpi="nmi"><div class="cb-kpi-val amber" data-kpi-val>%s%s</div><div class="cb-kpi-label">Focal NMI (100 = avg)</div></div>',
      nmi_txt, nmi_arrow))
  }

  sprintf('<div class="cb-kpi-strip">%s</div>', paste(chips, collapse = "\n"))
}


.cb_brand_picker <- function(dn, bh, focal, fcol, cat_code,
                              brand_labels = NULL, brand_colours = list()) {
  codes <- character(0)
  if (!is.null(dn) && !identical(dn$status, "REFUSED") && !is.null(dn$norms_table))
    codes <- c(codes, as.character(dn$norms_table$BrandCode))
  if (!is.null(bh) && !identical(bh$status, "REFUSED") && !is.null(bh$brand_heaviness))
    codes <- c(codes, as.character(bh$brand_heaviness$BrandCode))
  codes <- unique(codes)
  if (length(codes) == 0) return("")

  lbl_fn <- if (exists(".cb_brand_lbl", mode = "function")) .cb_brand_lbl else
    function(code, bl) tools::toTitleCase(tolower(as.character(code)))

  # Fallback palette — same as JS PALETTE for brands without Colour
  palette <- c('#4e79a7', '#f28e2b', '#e15759', '#76b7b2', '#59a14f',
               '#edc948', '#b07aa1', '#ff9da7', '#9c755f', '#bab0ac')
  resolve_colour <- function(bc, idx) {
    if (!is.null(brand_colours) && !is.null(brand_colours[[bc]]) &&
        nzchar(brand_colours[[bc]])) {
      return(as.character(brand_colours[[bc]]))
    }
    if (!is.null(focal) && bc == focal && !is.null(fcol) && nzchar(fcol)) {
      return(as.character(fcol))
    }
    palette[((idx - 1) %% length(palette)) + 1]
  }

  # Focal-brand <select> dropdown (MA-style)
  select_options <- paste(vapply(seq_along(codes), function(i) {
    bc <- codes[i]
    lbl <- lbl_fn(bc, brand_labels)
    sel <- if (!is.null(focal) && bc == focal) " selected" else ""
    sprintf('<option value="%s"%s>%s</option>',
            .cb_esc(bc), sel, .cb_esc(lbl))
  }, character(1)), collapse = "")

  focus_bar <- sprintf(
    '<div class="cb-focus-bar">
       <label class="cb-focus-label">Focal brand</label>
       <select class="cb-focus-select" data-cb-action="focus" onchange="_cbSetFocal(this,\'%s\')">%s</select>
     </div>',
    .cb_esc(cat_code), select_options)

  # Coloured brand chips — show/hide toggles (NOT focal selectors).
  # Clicking a chip hides its row in the brand summary table via JS.
  chips <- paste(vapply(seq_along(codes), function(i) {
    bc <- codes[i]
    lbl <- lbl_fn(bc, brand_labels)
    col <- resolve_colour(bc, i)
    is_foc <- !is.null(focal) && bc == focal
    badge <- if (is_foc) ' <span class="fn-focal-badge">FOCAL</span>' else ""
    sprintf(
      '<button type="button" class="col-chip fn-rel-brand-chip active" data-cb-action="toggle-row" data-brand="%s" style="--brand-chip-color:%s;background-color:%s;border-color:%s;color:#fff;">%s%s</button>',
      .cb_esc(bc), .cb_esc(col), .cb_esc(col), .cb_esc(col),
      .cb_esc(lbl), badge)
  }, character(1)), collapse = "")

  sprintf(
    '%s<div class="cb-brand-picker"><span class="cb-ctl-label cb-ctl-label-title">Show brands</span><div class="col-chip-bar">%s</div></div>',
    focus_bar, chips)
}


.cb_kpi_json_script <- function(dn, bh, cat_code) {
  entries <- list()
  has_dn <- !is.null(dn) && !identical(dn$status, "REFUSED") && !is.null(dn$norms_table)
  has_bh <- !is.null(bh) && !identical(bh$status, "REFUSED") && !is.null(bh$brand_heaviness)

  codes <- character(0)
  if (has_dn) codes <- c(codes, as.character(dn$norms_table$BrandCode))
  if (has_bh) codes <- c(codes, as.character(bh$brand_heaviness$BrandCode))
  codes <- unique(codes)
  if (length(codes) == 0) return("")

  for (bc in codes) {
    scr_obs <- "\u2014"; scr_exp <- ""
    loy_obs <- "\u2014"; loy_exp <- ""
    nmi_txt <- "\u2014"; nmi_arrow <- ""

    if (has_dn) {
      nt <- dn$norms_table; ri <- which(nt$BrandCode == bc)
      if (length(ri) == 1) {
        if (!is.na(nt$SCR_Obs_Pct[ri]))     scr_obs <- sprintf("%.0f%%", nt$SCR_Obs_Pct[ri])
        if (!is.na(nt$SCR_Exp_Pct[ri]))     scr_exp <- sprintf("exp %.0f%%", nt$SCR_Exp_Pct[ri])
        if (!is.na(nt$Pct100Loyal_Obs[ri])) loy_obs <- sprintf("%.0f%%", nt$Pct100Loyal_Obs[ri])
        if (!is.na(nt$Pct100Loyal_Exp[ri])) loy_exp <- sprintf("exp %.0f%%", nt$Pct100Loyal_Exp[ri])
      }
    }
    if (has_bh) {
      bh_df <- bh$brand_heaviness; ri <- which(bh_df$BrandCode == bc)
      if (length(ri) == 1 && "NaturalMonopolyIndex" %in% names(bh_df)) {
        nmi_v <- bh_df$NaturalMonopolyIndex[ri]
        if (!is.na(nmi_v)) {
          nmi_txt   <- sprintf("%.0f", nmi_v)
          nmi_arrow <- if (nmi_v < 85) "\u2193" else if (nmi_v > 115) "\u2191" else "\u2192"
        }
      }
    }
    entries[[bc]] <- list(scr_obs = scr_obs, scr_exp = scr_exp,
                          loyal_obs = loy_obs, loyal_exp = loy_exp,
                          nmi = nmi_txt, nmi_arrow = nmi_arrow)
  }

  json_str <- tryCatch(
    jsonlite::toJSON(entries, auto_unbox = TRUE, pretty = FALSE),
    error = function(e) "{}"
  )
  sprintf(
    '<script type="application/json" class="cb-panel-data" id="cb-data-%s">%s</script>',
    .cb_esc(cat_code), json_str)
}


.cb_refused_block <- function(elem, label) {
  if (is.null(elem)) {
    return(sprintf(
      '<div class="cb-refused">%s not available (no data).</div>', .cb_esc(label)))
  }
  sprintf('<div class="cb-refused">%s not available: %s (%s).</div>',
          .cb_esc(label),
          .cb_esc(elem$message %||% ""),
          .cb_esc(elem$code    %||% ""))
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Cat Buying Panel loaded (v%s)",
                  BRAND_CB_PANEL_VERSION))
}
