# ==============================================================================
# BRAND MODULE - MA PANEL METRICS + RANKING SECTION
# ==============================================================================
# Renders the Headline Metrics sub-tab:
#   - Hero strip: focal brand MPen, NS, MMS (with cat avg comparison)
#   - Brand table: per-brand MPen / NS / MMS + heatmap variation
#   - CEP penetration ranking: horizontal bar chart of category-level CEP %
# ==============================================================================


#' Build the MA metrics section HTML.
#' @param pd Panel data from build_ma_panel_data().
#' @param focal_colour Character. Hex colour for focal highlighting.
#' @return Character string (section element).
#' @export
build_ma_metrics_section <- function(pd, focal_colour = "#1A5276") {
  metrics <- pd$metrics
  if (is.null(metrics)) return("")

  brand_codes <- pd$config$brand_codes %||% character(0)
  brand_names <- pd$config$brand_names %||% brand_codes
  focal       <- pd$meta$focal_brand_code %||% brand_codes[1]

  # Sort: focal first, then alphabetical by brand name
  sorted_order <- order(brand_codes != focal, tolower(brand_names))
  brand_codes  <- brand_codes[sorted_order]
  brand_names  <- brand_names[sorted_order]

  chips_html <- paste(vapply(seq_along(brand_codes), function(i) {
    sprintf(
      '<button type="button" class="col-chip" data-ma-scope="metrics" data-ma-brand="%s">%s</button>',
      .ma_esc(brand_codes[i]), .ma_esc(brand_names[i]))
  }, character(1)), collapse = "")

  chart_toggles <- paste0(
    '<label class="toggle-label"><input type="checkbox" checked data-ma-action="togglechart" data-ma-chart-target="scatter"> Mental Space</label>',
    '<label class="toggle-label"><input type="checkbox" checked data-ma-action="togglechart" data-ma-chart-target="bars"> MMS vs SOM</label>',
    '<label class="toggle-label"><input type="checkbox" checked data-ma-action="togglechart" data-ma-chart-target="ranking"> CEP Ranking</label>'
  )

  controls_bar <- paste0(
    '<div class="ma-controls controls-bar">',
    '<div class="ma-ctl-group"><span class="ma-ctl-label">Show brands</span>',
    '<div class="ma-chip-row col-chip-bar" data-ma-scope="metrics">', chips_html, '</div>',
    '</div>',
    chart_toggles,
    '<label class="toggle-label"><input type="checkbox" data-ma-action="showcounts-metrics"> Show count</label>',
    '<button type="button" class="export-btn ma-pin-dropdown-btn" data-ma-action="pindropdown" title="Pin a section" aria-haspopup="true">&#128204; Pin &#9662;</button>',
    '<button type="button" class="export-btn ma-png-btn" onclick="brExportPngFromEl(this)" title="Export view to PNG">&#x1F5BC; PNG</button>',
    '<button type="button" class="export-btn ma-export-btn" data-ma-action="exporttable" data-ma-stim="metrics" title="Export table to Excel">\u2B73 Excel \u25BE</button>',
    '</div>'
  )

  paste0(
    '<section class="ma-section ma-metrics-section" data-ma-stim="metrics">',
    .ma_metrics_hero(pd, focal_colour),
    controls_bar,
    .ma_metrics_table(pd, focal_colour),
    .ma_metrics_charts(pd),
    .ma_cep_ranking(pd, focal_colour),
    '</section>'
  )
}


# ==============================================================================
# HERO CARDS: focal brand MPen / NS / MMS
# ==============================================================================

.ma_metrics_hero <- function(pd, focal_colour) {
  m      <- pd$metrics
  hero   <- m$focal_hero
  avg    <- m$cat_avg
  leader <- m$leader
  focal  <- pd$meta$focal_brand_code
  focal_name <- pd$meta$focal_brand_name %||% focal

  brand_names <- pd$config$brand_names %||% pd$config$brand_codes

  leader_name <- function(code) {
    idx <- match(code, pd$config$brand_codes)
    if (is.na(idx)) code else brand_names[idx]
  }

  dp <- as.integer(pd$config$decimal_places %||% 0L)

  card <- function(label, focal_val, avg_val, leader_code, unit, metric_key) {
    focal_disp <- if (is.null(focal_val) || is.na(focal_val)) "\u2014"
                  else if (unit == "pct") sprintf(paste0("%.", dp, "f%%"), focal_val)
                  else sprintf("%.2f", focal_val)
    avg_disp <- if (is.null(avg_val) || is.na(avg_val)) "\u2014"
                else if (unit == "pct") sprintf(paste0("%.", dp, "f%%"), avg_val)
                else sprintf("%.2f", avg_val)
    lead_name <- leader_name(leader_code)
    is_leader <- identical(focal, leader_code)
    leader_line <- if (is_leader)
      '<div class="ma-hero-leader ma-hero-leader-focal">Category leader</div>'
      else sprintf('<div class="ma-hero-leader">Leader: <strong>%s</strong></div>',
                   .ma_esc(lead_name))
    sprintf(
      '<div class="tk-hero-card ma-hero-card" data-ma-metric="%s" style="border-left-color:%s;">
         <div class="tk-hero-label">%s</div>
         <div class="tk-hero-value" style="color:%s;">%s</div>
         <div class="ma-hero-compare">Category avg: <strong>%s</strong></div>
         %s
       </div>',
      metric_key, focal_colour, .ma_esc(label),
      focal_colour, focal_disp,
      avg_disp, leader_line)
  }

  paste0(
    sprintf('<h3 class="ma-section-title ma-metrics-hero-title">%s \u2014 Headline Metrics</h3>',
            .ma_esc(focal_name)),
    '<div class="ma-hero-strip tk-hero-strip">',
    card("Mental Penetration (MPen)", hero$mpen, avg$mpen, leader$mpen, "pct", "mpen"),
    card("Network Size (NS)",         hero$ns,   avg$ns,   leader$ns,   "num", "ns"),
    card("Mental Market Share (MMS)", hero$mms,  avg$mms,  leader$mms,  "pct", "mms"),
    card("Share of Mind (SOM)",       hero$som,  avg$som,  leader$som,  "pct", "som"),
    '</div>'
  )
}


# ==============================================================================
# BRAND METRICS TABLE
# ==============================================================================

.ma_metrics_table <- function(pd, focal_colour) {
  rows    <- pd$metrics$table
  if (is.null(rows) || length(rows) == 0) return("")

  focal   <- pd$meta$focal_brand_code
  cat_avg <- pd$metrics$cat_avg
  n_resp  <- pd$meta$n_respondents
  dp      <- as.integer(pd$config$decimal_places %||% 0L)

  # Max values per metric (for CI bar scaling in cat avg row)
  mms_max  <- max(c(cat_avg$mms  %||% 0, vapply(rows, function(r) r$mms  %||% 0, numeric(1))), na.rm = TRUE)
  mpen_max <- max(c(cat_avg$mpen %||% 0, vapply(rows, function(r) r$mpen %||% 0, numeric(1))), na.rm = TRUE)
  ns_max   <- max(c(cat_avg$ns   %||% 0, vapply(rows, function(r) r$ns   %||% 0, numeric(1))), na.rm = TRUE)
  som_max  <- max(c(cat_avg$som  %||% 0, vapply(rows, function(r) r$som  %||% 0, numeric(1))), na.rm = TRUE)

  # Separate focal row from others; default-sort others by MMS desc
  is_focal_row <- vapply(rows, function(r) !is.null(focal) && identical(r$brand_code, focal), logical(1))
  focal_rows   <- rows[is_focal_row]
  other_rows   <- rows[!is_focal_row]
  if (length(other_rows) > 0) {
    ord        <- order(-vapply(other_rows, function(r) r$mms %||% NA_real_, numeric(1)))
    other_rows <- other_rows[ord]
  }

  # CI band cell (green/amber/red)
  ci_bg <- function(band) {
    switch(as.character(band %||% "within"),
      "above"  = "rgba(5,150,105,0.18)",
      "below"  = "rgba(220,38,38,0.18)",
      "within" = "rgba(245,158,11,0.15)",
      "transparent")
  }

  fmt_cell <- function(val, band, fmt, n = NULL) {
    if (is.null(val) || is.na(val))
      return('<td class="ct-td ct-data-col ct-na">&mdash;</td>')
    disp   <- if (fmt == "pct") sprintf(paste0("%.", dp, "f%%"), val) else sprintf("%.2f", val)
    band_s <- as.character(band %||% "within")
    bg     <- ci_bg(band_s)
    n_html <- if (!is.null(n) && !is.na(n))
      sprintf('<span class="ma-n-metrics">%s</span>',
              format(as.integer(n), big.mark = ","))
      else ""
    sprintf(
      '<td class="ct-td ct-data-col ma-heatmap-cell ma-ci-%s" style="background-color:%s;" data-sort-val="%.4f"><span class="ct-val">%s</span>%s</td>',
      band_s, bg, val, disp, n_html)
  }

  # Category-average cell with visual 95% CI range bar
  fmt_avg_ci_cell <- function(avg_val, ci_lo, ci_hi, max_val, fmt) {
    if (is.null(avg_val) || is.na(avg_val))
      return('<td class="ct-td ct-data-col ma-metrics-cat-avg">&mdash;</td>')
    disp    <- if (fmt == "pct") sprintf(paste0("%.", dp, "f%%"), avg_val) else sprintf("%.2f", avg_val)
    lo_disp <- if (!is.null(ci_lo) && !is.na(ci_lo))
      (if (fmt == "pct") sprintf(paste0("%.", dp, "f%%"), ci_lo) else sprintf("%.2f", ci_lo)) else ""
    hi_disp <- if (!is.null(ci_hi) && !is.na(ci_hi))
      (if (fmt == "pct") sprintf(paste0("%.", dp, "f%%"), ci_hi) else sprintf("%.2f", ci_hi)) else ""
    safe_max   <- max(1, as.numeric(max_val %||% 1), na.rm = TRUE)
    fill_left  <- if (nzchar(lo_disp)) max(0, min(94, 100 * as.numeric(ci_lo) / safe_max)) else 0
    fill_w     <- if (nzchar(lo_disp) && nzchar(hi_disp))
      max(4, min(100 - fill_left, 100 * (as.numeric(ci_hi) - as.numeric(ci_lo)) / safe_max)) else 0
    mean_pct   <- max(1, min(99, 100 * avg_val / safe_max))
    ci_bar <- if (nzchar(lo_disp) && nzchar(hi_disp)) paste0(
      sprintf('<div class="ma-ci-bar-wrap" title="95%% CI: %s \u2013 %s">', lo_disp, hi_disp),
      sprintf('<div class="ma-ci-bar-range" style="left:%.1f%%;width:%.1f%%;"></div>', fill_left, fill_w),
      sprintf('<div class="ma-ci-bar-tick" style="left:%.1f%%"></div>', mean_pct),
      '</div>',
      sprintf('<div class="ma-ci-limits"><span>%s</span><span>%s</span></div>', lo_disp, hi_disp)
    ) else ""
    paste0('<td class="ct-td ct-data-col ma-metrics-cat-avg">',
           sprintf('<span class="ct-val">%s</span>', disp),
           ci_bar, '</td>')
  }

  fmt_base_cell <- function(n) {
    if (is.null(n) || is.na(n))
      return('<td class="ct-td ct-data-col ct-na">&mdash;</td>')
    sprintf('<td class="ct-td ct-data-col"><span class="ct-val">%s</span></td>',
            format(as.integer(n), big.mark = ","))
  }

  make_brand_row <- function(r, is_focal = FALSE) {
    cls         <- if (is_focal) "ct-row ma-row ma-metrics-focal-row" else "ct-row ma-row"
    focal_badge <- if (is_focal) ' <span class="ma-focal-badge">FOCAL</span>' else ""
    sort_attrs  <- sprintf(
      ' data-sort-mms="%.4f" data-sort-mpen="%.4f" data-sort-ns="%.4f" data-sort-som="%.4f" data-sort-brand="%s"',
      r$mms %||% -999, r$mpen %||% -999, r$ns %||% -999, r$som %||% -999,
      .ma_esc(r$brand_name))
    n_linkers <- if (!is.null(n_resp) && !is.na(n_resp) && !is.null(r$mpen) && !is.na(r$mpen))
      as.integer(round(r$mpen / 100 * n_resp)) else NA_integer_
    paste0(
      sprintf('<tr class="%s" data-ma-brand="%s"%s>', cls, .ma_esc(r$brand_code), sort_attrs),
      sprintf('<td class="ct-td ct-label-col">%s%s</td>', .ma_esc(r$brand_name), focal_badge),
      fmt_cell(r$mms,  r$mms_band,  "pct", n = r$total_links),
      fmt_cell(r$mpen, r$mpen_band, "pct", n = n_resp),
      fmt_cell(r$ns,   r$ns_band,   "num", n = n_linkers),
      fmt_cell(r$som,  r$som_band,  "pct", n = n_resp),
      '</tr>'
    )
  }

  # Row 1: Base
  base_html  <- paste0(
    '<tr class="ct-row ma-metrics-base">',
    '<td class="ct-td ct-label-col"><strong>Base</strong></td>',
    fmt_base_cell(n_resp), fmt_base_cell(n_resp),
    fmt_base_cell(n_resp), fmt_base_cell(n_resp),
    '</tr>'
  )

  # Row 2: Focal brand (always above cat avg, clearly marked)
  focal_html <- if (length(focal_rows) > 0)
    make_brand_row(focal_rows[[1]], is_focal = TRUE) else ""

  # Row 3: Category average with 95% CI band display
  avg_html <- paste0(
    '<tr class="ct-row ma-metrics-cat-avg">',
    '<td class="ct-td ct-label-col"><em>Category avg</em></td>',
    fmt_avg_ci_cell(cat_avg$mms,  cat_avg$mms_ci_lo,  cat_avg$mms_ci_hi,  mms_max,  "pct"),
    fmt_avg_ci_cell(cat_avg$mpen, cat_avg$mpen_ci_lo, cat_avg$mpen_ci_hi, mpen_max, "pct"),
    fmt_avg_ci_cell(cat_avg$ns,   cat_avg$ns_ci_lo,   cat_avg$ns_ci_hi,   ns_max,   "num"),
    fmt_avg_ci_cell(cat_avg$som,  cat_avg$som_ci_lo,  cat_avg$som_ci_hi,  som_max,  "pct"),
    '</tr>'
  )

  # Rows 4+: Other brands sorted MMS desc
  other_html <- paste(vapply(other_rows, function(r) make_brand_row(r), character(1)),
                      collapse = "")

  # Sortable header helper — full metric names
  th_sort <- function(col_id, label, title_text, default_active = FALSE) {
    dir_init <- if (default_active) "desc" else "none"
    glyph    <- if (default_active) "\u2193" else "\u21C5"
    sprintf(
      '<th class="ct-th ct-data-col ma-metrics-th" title="%s">
         <div class="ct-header-text">%s</div>
         <button type="button" class="ma-metric-sort-btn"
                 aria-label="Sort by %s" data-sort-col="%s" data-sort-dir="%s">%s</button>
       </th>',
      .ma_esc(title_text), label, label, col_id, dir_init, glyph)
  }

  # Brand column header (with A-Z / Z-A sort)
  brand_th <- sprintf(
    '<th class="ct-th ct-label-col ma-metrics-th">
       <div class="ct-header-text" style="text-align:left;">Brand</div>
       <button type="button" class="ma-metric-sort-btn"
               aria-label="Sort brands A\u2013Z or Z\u2013A"
               data-sort-col="brand" data-sort-dir="none">\u21C5</button>
     </th>')

  paste0(
    '<div class="ma-table-wrap">',
    '<table class="ct-table ma-ct-table ma-metrics-table">',
    '<thead><tr>',
    brand_th,
    th_sort("mms",  "Mental Market Share",
            "Brand\u2019s share of all brand-CEP links in the category"),
    th_sort("mpen", "Mental Penetration",
            "% of category buyers linking the brand to at least one CEP"),
    th_sort("ns",   "Network Size",
            "Average CEPs linked per buyer who links at least one"),
    th_sort("som",  "Share of Mind",
            "MMS \u00f7 MPen \u00d7 100 \u2014 CEP links as % of all links by buyers with MPen for that brand"),
    '</tr></thead>',
    '<tbody>',
    base_html,
    focal_html,
    avg_html,
    other_html,
    '</tbody></table></div>'
  )
}


# ==============================================================================
# CEP PENETRATION RANKING (horizontal bar chart)
# ==============================================================================

.ma_cep_ranking <- function(pd, focal_colour) {
  rank_df <- pd$metrics$cep_penetration
  if (is.null(rank_df) || nrow(rank_df) == 0) return("")

  # Align with CEP labels if available
  cep_labels <- pd$ceps$labels %||% character(0)
  cep_codes  <- pd$ceps$codes  %||% character(0)
  label_map <- stats::setNames(cep_labels, cep_codes)

  rank_df <- rank_df[order(-rank_df$Penetration_Pct), , drop = FALSE]

  bars_html <- vapply(seq_len(nrow(rank_df)), function(i) {
    code <- as.character(rank_df$CEPCode[i])
    pct  <- as.numeric(rank_df$Penetration_Pct[i])
    label <- label_map[[code]]
    if (is.null(label) || is.na(label)) label <- code
    width <- max(2, min(100, pct))
    sprintf(
      '<div class="ma-rank-row">
         <div class="ma-rank-rank">#%d</div>
         <div class="ma-rank-label" title="%s">%s</div>
         <div class="ma-rank-bar-track">
           <div class="ma-rank-bar-fill" style="width:%.1f%%;background:%s;"></div>
           <div class="ma-rank-bar-value">%.0f%%</div>
         </div>
       </div>',
      i, .ma_esc(label), .ma_esc(label),
      width, focal_colour, pct)
  }, character(1))

  paste0(
    '<div class="ma-rank-section" data-ma-chart-id="ranking">',
    '<h4 class="ma-subsection-title">Category Entry Point penetration (any brand)</h4>',
    '<div class="ma-rank-list">',
    paste(bars_html, collapse = ""),
    '</div></div>'
  )
}


# ==============================================================================
# METRICS CHARTS: MPen×NS scatter + MMS vs SOM bar chart
# ==============================================================================

.ma_metrics_charts <- function(pd) {
  paste0(
    '<div class="ma-metrics-charts">',

    # --- Scatter: MPen × NS (Double Jeopardy) --------------------------------
    '<div class="ma-scatter-wrap" data-ma-chart-id="scatter">',
    '<h4 class="ma-subsection-title">Mental Space: Penetration \u00d7 Depth</h4>',
    '<details class="ma-chart-callout">',
    '<summary>About this chart</summary>',
    '<p class="ma-subsection-note">',
    'Each bubble is a brand. Position shows mental penetration (reach) vs network size ',
    '(depth); bubble size reflects mental market share. The trend line reveals the ',
    'double-jeopardy pattern \u2014 brands with broader reach also tend to have deeper ',
    'associations. Dashed lines mark category averages.',
    '</p></details>',
    '<svg class="ma-scatter-svg" data-ma-stim="metrics"',
    ' xmlns="http://www.w3.org/2000/svg"></svg>',
    '</div>',

    # --- Bar chart: MMS vs SOM -----------------------------------------------
    '<div class="ma-bars-wrap" data-ma-chart-id="bars">',
    '<h4 class="ma-subsection-title">MMS vs Share of Mind</h4>',
    '<details class="ma-chart-callout">',
    '<summary>About this chart</summary>',
    '<p class="ma-subsection-note">',
    'Mental Market Share (share of all brand-CEP links in the category) vs Share of Mind ',
    '(MMS \u00f7 MPen \u00d7 100 \u2014 CEP links as % of all links by buyers with MPen for that brand). ',
    'Dashed lines mark category averages for each metric.',
    '</p></details>',
    '<svg class="ma-bars-svg" data-ma-stim="metrics"',
    ' xmlns="http://www.w3.org/2000/svg"></svg>',
    '</div>',

    '</div>'
  )
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!exists(".ma_esc", mode = "function")) {
  .ma_esc <- function(x) {
    if (is.null(x)) return("")
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub("\"", "&quot;", x, fixed = TRUE)
    x
  }
}
