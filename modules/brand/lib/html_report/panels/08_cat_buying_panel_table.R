# ==============================================================================
# BRAND MODULE - CATEGORY BUYING PANEL TABLE BUILDER
# ==============================================================================
# Builds the Dirichlet norms HTML table (§8 item 3) and the DoP deviation
# summary for the Category Buying panel.
#
# VERSION: 1.0
# ==============================================================================

BRAND_CB_TABLE_VERSION <- "1.0"

if (!exists(".cb_esc", mode = "function")) {
  .cb_esc <- function(x) {
    if (is.null(x) || is.na(x)) return("")
    x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x
  }
}

if (!exists(".cb_brand_lbl", mode = "function")) {
  .cb_brand_lbl <- function(code, brand_labels = NULL) {
    if (!is.null(brand_labels) && !is.na(brand_labels[code]) &&
        nzchar(brand_labels[code])) {
      return(as.character(brand_labels[code]))
    }
    tools::toTitleCase(tolower(as.character(code)))
  }
}


#' Build the Dirichlet norms HTML table (§8 item 3)
#'
#' Renders a grouped-header table: Penetration | Buy rate | SCR | 100% Loyals,
#' each group showing Obs / Exp / Δ%.  Focal row bolded, large deviations
#' shaded green/red.
#'
#' @param norms_table Data frame. From \code{run_dirichlet_norms()$norms_table}.
#' @param focal_brand Character or NULL.
#' @param target_months Integer. Used in footer text.
#' @param category_metrics List. From \code{run_dirichlet_norms()$category_metrics}.
#'   Used for footer note reconciliation.
#' @param cat_buying_freq List or NULL. From \code{cat_result$cat_buying_frequency}.
#'   Used for M_stated reconciliation note (§5.5).
#' @param brand_labels Named character vector or NULL. Names = BrandCode, values = display labels.
#'
#' @return Character. HTML string.
#' @keywords internal
cb_norms_table_html <- function(norms_table,
                                 focal_brand      = NULL,
                                 target_months    = 3L,
                                 category_metrics = NULL,
                                 cat_buying_freq  = NULL,
                                 brand_labels     = NULL) {
  if (is.null(norms_table) || nrow(norms_table) == 0)
    return('<p class="cb-refused">Norms table not available.</p>')

  fmt_pct <- function(x, d = 1) {
    if (is.na(x)) return("\u2014") else sprintf("%.*f%%", d, x)
  }
  fmt_n <- function(x, d = 2) {
    if (is.na(x)) return("\u2014") else sprintf("%.*f", d, x)
  }
  dev_cls <- function(v) {
    if (is.na(v)) return("")
    if (abs(v) >= 20) {
      if (v > 0) "cb-dev-large-pos" else "cb-dev-large-neg"
    } else {
      if (v > 0) "cb-dev-pos" else "cb-dev-neg"
    }
  }

  lines <- character(0)
  lines <- c(lines, '<div class="cb-norms-wrap">')
  lines <- c(lines, '<table class="cb-norms-table">')
  lines <- c(lines, '<colgroup><col style="width:80px"/></colgroup>')

  # Grouped header row 1
  lines <- c(lines, '<thead>')
  lines <- c(lines, '<tr>')
  lines <- c(lines, '<th rowspan="2">Brand</th>')
  for (grp in c("Penetration", "Buy rate", "SCR", "100% Loyals")) {
    lines <- c(lines, sprintf('<th colspan="3">%s</th>', grp))
  }
  lines <- c(lines, '</tr>')

  # Grouped header row 2
  lines <- c(lines, '<tr>')
  for (i in 1:4) {
    lines <- c(lines, '<th>Obs</th><th>Exp</th><th>\u0394%</th>')
  }
  lines <- c(lines, '</tr></thead><tbody>')

  for (i in seq_len(nrow(norms_table))) {
    row      <- norms_table[i, ]
    is_focal <- !is.null(focal_brand) && row$BrandCode == focal_brand
    r_cls    <- if (is_focal) ' class="focal-row"' else ""
    lbl      <- .cb_brand_lbl(row$BrandCode, brand_labels)

    lines <- c(lines, sprintf('<tr data-brand="%s"%s>', .cb_esc(row$BrandCode), r_cls))
    lines <- c(lines, sprintf('<td class="brand-col">%s</td>',
                               .cb_esc(lbl)))

    # Penetration
    lines <- c(lines, sprintf('<td>%s</td>', fmt_pct(row$Penetration_Obs_Pct)))
    lines <- c(lines, sprintf('<td>%s</td>', fmt_pct(row$Penetration_Exp_Pct)))
    lines <- c(lines, sprintf('<td class="%s">%s</td>',
                               dev_cls(row$Penetration_Dev_Pct),
                               fmt_n(row$Penetration_Dev_Pct, 0)))

    # Buy rate
    lines <- c(lines, sprintf('<td>%s</td>', fmt_n(row$BuyRate_Obs)))
    lines <- c(lines, sprintf('<td>%s</td>', fmt_n(row$BuyRate_Exp)))
    lines <- c(lines, sprintf('<td class="%s">%s</td>',
                               dev_cls(row$BuyRate_Dev_Pct),
                               fmt_n(row$BuyRate_Dev_Pct, 0)))

    # SCR
    lines <- c(lines, sprintf('<td>%s</td>', fmt_pct(row$SCR_Obs_Pct)))
    lines <- c(lines, sprintf('<td>%s</td>', fmt_pct(row$SCR_Exp_Pct)))
    lines <- c(lines, sprintf('<td class="%s">%s</td>',
                               dev_cls(row$SCR_Dev_Pct),
                               fmt_n(row$SCR_Dev_Pct, 0)))

    # 100% Loyal
    lines <- c(lines, sprintf('<td>%s</td>', fmt_pct(row$Pct100Loyal_Obs)))
    lines <- c(lines, sprintf('<td>%s</td>', fmt_pct(row$Pct100Loyal_Exp)))
    lines <- c(lines, sprintf('<td class="%s">%s</td>',
                               dev_cls(row$Pct100Loyal_Dev_Pct),
                               fmt_n(row$Pct100Loyal_Dev_Pct, 0)))

    lines <- c(lines, '</tr>')
  }

  lines <- c(lines, '</tbody>')

  # Footer: §5.5 reconciliation note + limitations
  m_brand  <- if (!is.null(category_metrics))
    sprintf("%.1f", category_metrics$mean_purchases) else "?"
  m_stated <- if (!is.null(cat_buying_freq) &&
                   !is.null(cat_buying_freq$mean_freq) &&
                   !is.na(cat_buying_freq$mean_freq)) {
    sprintf("%.1f", cat_buying_freq$mean_freq * target_months)
  } else "?"

  footer_txt <- sprintf(
    paste0("Category mean purchases per buyer over the last %d months \u2014 ",
           "BRANDPEN3: %s; CATBUY stated scale: %s. ",
           "Dirichlet uses BRANDPEN3 (direct measurement). ",
           "\u0394%% flags: \u2265\u00b120%% shaded. ",
           "Source: Goodhardt, Ehrenberg &amp; Chatfield (1984)."),
    target_months, m_brand, m_stated)

  lines <- c(lines, sprintf(
    '<tfoot><tr><td colspan="13" style="font-size:10px;color:#94a3b8;padding:6px 4px;text-align:left;font-style:italic;">%s</td></tr></tfoot>',
    footer_txt))

  lines <- c(lines, '</table></div>')
  paste(lines, collapse = "\n")
}


#' Build compact Category Context tables: purchase frequency + repertoire size
#'
#' Returns two side-by-side tables in a CSS grid wrapper, followed by the mean
#' repertoire stat. Both tables are always rendered; if data is unavailable an
#' informative note is shown instead.
#'
#' @param cbf List or NULL. \code{cat_buying_frequency} result from run_brand().
#'   Must contain \code{cbf$distribution} with columns \code{Label} and \code{Pct}.
#' @param rep List or NULL. \code{repertoire} result from run_brand().
#'   Must contain \code{rep$repertoire_size} with columns
#'   \code{Brands_Bought} and \code{Percentage}.
#'   \code{rep$mean_repertoire} displayed as a summary stat when present.
#'
#' @return Character. HTML string (two-column grid with compact tables + mean stat).
#' @keywords internal
cb_freq_repertoire_tables_html <- function(cbf = NULL, rep = NULL) {
  lines <- character(0)
  lines <- c(lines, '<div class="cb-context-tables">')

  # --- Purchase Frequency Distribution ---
  lines <- c(lines, '<div>')
  lines <- c(lines, '<div class="cb-ctx-subtitle">Category Purchase Frequency</div>')

  freq_ok <- !is.null(cbf) && !identical(cbf$status, "REFUSED") &&
             !is.null(cbf$distribution) && nrow(cbf$distribution) > 0

  if (freq_ok) {
    dist <- cbf$distribution
    if ("Order" %in% names(dist)) dist <- dist[order(dist$Order), , drop = FALSE]
    lines <- c(lines, '<table class="cb-ctx-table">')
    lines <- c(lines, '<thead><tr><th>Frequency</th><th style="text-align:right;">%</th></tr></thead>')
    lines <- c(lines, '<tbody>')
    for (i in seq_len(nrow(dist))) {
      lbl_i <- if ("Label" %in% names(dist)) .cb_esc(dist$Label[i]) else as.character(i)
      pct_i <- if ("Pct" %in% names(dist) && !is.na(dist$Pct[i]))
        sprintf("%.1f%%", dist$Pct[i]) else "\u2014"
      lines <- c(lines, sprintf('<tr><td>%s</td><td style="text-align:right;">%s</td></tr>',
                                 lbl_i, pct_i))
    }
    lines <- c(lines, '</tbody></table>')
  } else {
    lines <- c(lines, '<p style="font-size:12px;color:#94a3b8;">Purchase frequency data not available.</p>')
  }
  lines <- c(lines, '</div>')

  # --- Repertoire Size Distribution + mean stat ---
  lines <- c(lines, '<div>')
  lines <- c(lines, '<div class="cb-ctx-subtitle">Repertoire Size</div>')

  rep_ok <- !is.null(rep) && !identical(rep$status, "REFUSED") &&
            !is.null(rep$repertoire_size) && nrow(rep$repertoire_size) > 0

  mean_rep <- if (!is.null(rep) && !identical(rep$status, "REFUSED") &&
                  !is.null(rep$mean_repertoire) && !is.na(rep$mean_repertoire))
    rep$mean_repertoire else NULL

  if (!is.null(mean_rep)) {
    lines <- c(lines, sprintf(
      '<div class="cb-ctx-stat">Mean: <strong>%.1f brands</strong> per buyer</div>',
      mean_rep))
  }

  if (rep_ok) {
    rs <- rep$repertoire_size
    lines <- c(lines, '<table class="cb-ctx-table">')
    lines <- c(lines, '<thead><tr><th>Brands bought</th><th style="text-align:right;">%</th></tr></thead>')
    lines <- c(lines, '<tbody>')
    for (i in seq_len(nrow(rs))) {
      bb_i  <- if ("Brands_Bought" %in% names(rs))
        .cb_esc(as.character(rs$Brands_Bought[i])) else as.character(i)
      pct_i <- if ("Percentage" %in% names(rs) && !is.na(rs$Percentage[i]))
        sprintf("%.1f%%", rs$Percentage[i]) else "\u2014"
      lines <- c(lines, sprintf('<tr><td>%s</td><td style="text-align:right;">%s</td></tr>',
                                 bb_i, pct_i))
    }
    lines <- c(lines, '</tbody></table>')
  } else {
    lines <- c(lines, '<p style="font-size:12px;color:#94a3b8;">Repertoire size data not available.</p>')
  }
  lines <- c(lines, '</div>')

  lines <- c(lines, '</div>') # close cb-context-tables
  paste(lines, collapse = "\n")
}


#' Build per-brand performance summary table
#'
#' Visual style matches the Brand Attitude table: dark header with sort buttons,
#' focal brand at top with FOCAL badge and red left border, category average row
#' with min-max range context, other brands sortable by column.
#'
#' Columns: Brand | Base (n=) | Penetration | Avg purchases | Vol share |
#' SCR obs | SCR exp | Δ SCR.
#' Vol share = (Pen/100 × BuyRate) / cat_mean_purchases × 100.
#'
#' @param norms_table Data frame. From \code{run_dirichlet_norms()$norms_table}.
#' @param focal_brand Character or NULL.
#' @param brand_labels Named character vector or NULL.
#' @param brand_heaviness Data frame or NULL.
#'   From \code{run_buyer_heaviness()$brand_heaviness}.
#'   Provides \code{Brand_Buyers_n} for the Base column.
#' @param category_metrics List or NULL. From \code{run_dirichlet_norms()$category_metrics}.
#'   Provides \code{mean_purchases} for Vol share computation.
#' @param target_months Integer. Used in tooltip copy.
#'
#' @return Character. HTML string (includes inline sort script).
#' @keywords internal
cb_brand_freq_scr_table_html <- function(norms_table,
                                          focal_brand      = NULL,
                                          brand_labels     = NULL,
                                          brand_heaviness  = NULL,
                                          category_metrics = NULL,
                                          target_months    = 3L) {
  if (is.null(norms_table) || nrow(norms_table) == 0)
    return('<p class="cb-refused">Per-brand data not available.</p>')

  cat_mean_purch <- if (!is.null(category_metrics) &&
                         !is.null(category_metrics$mean_purchases) &&
                         !is.na(category_metrics$mean_purchases))
    as.numeric(category_metrics$mean_purchases) else NA_real_

  fmt_pct  <- function(x) if (is.na(x)) "\u2014" else sprintf("%.0f%%", x)
  fmt_n    <- function(x) if (is.na(x)) "\u2014" else sprintf("%.1f", x)
  fmt_int  <- function(x) if (is.na(x) || x == 0L) "\u2014" else
    formatC(as.integer(x), format = "d", big.mark = ",")

  dev_cls <- function(v) {
    if (is.na(v)) return("")
    if (abs(v) >= 20) {
      if (v > 0) " class=\"cb-dev-large-pos\"" else " class=\"cb-dev-large-neg\""
    } else ""
  }

  vol_share_fn <- function(pen, buy_rate) {
    if (is.na(pen) || is.na(buy_rate) || is.na(cat_mean_purch) ||
        cat_mean_purch == 0) return(NA_real_)
    buy_rate * (pen / 100) / cat_mean_purch * 100
  }

  .get <- function(row, col) {
    if (col %in% names(row)) as.numeric(row[[col]]) else NA_real_
  }

  .bh_n <- function(bc) {
    if (is.null(brand_heaviness) || nrow(brand_heaviness) == 0) return(NA_integer_)
    ri <- which(brand_heaviness$BrandCode == bc)
    if (length(ri) == 1 && "Brand_Buyers_n" %in% names(brand_heaviness))
      as.integer(brand_heaviness$Brand_Buyers_n[ri])
    else NA_integer_
  }

  # Column-wise stats across all brands (for category avg row + range display)
  all_pen  <- as.numeric(norms_table$Penetration_Obs_Pct)
  all_br   <- as.numeric(norms_table$BuyRate_Obs)
  all_scro <- as.numeric(norms_table$SCR_Obs_Pct)
  all_scre <- as.numeric(norms_table$SCR_Exp_Pct)
  all_scrd <- as.numeric(norms_table$SCR_Dev_Pct)
  all_vs   <- vapply(seq_len(nrow(norms_table)),
    function(i) vol_share_fn(all_pen[i], all_br[i]), numeric(1))

  avg_pen  <- mean(all_pen,  na.rm = TRUE)
  avg_br   <- mean(all_br,   na.rm = TRUE)
  avg_scro <- mean(all_scro, na.rm = TRUE)
  avg_scre <- mean(all_scre, na.rm = TRUE)
  avg_scrd <- mean(all_scrd, na.rm = TRUE)
  avg_vs   <- mean(all_vs,   na.rm = TRUE)

  # Min–max range text for category avg row (mirrors the CI bars in brand attitude)
  .rng <- function(vals) {
    mn <- min(vals, na.rm = TRUE); mx <- max(vals, na.rm = TRUE)
    if (!is.finite(mn) || !is.finite(mx)) return("")
    sprintf('<div class="cb-perf-range">%.0f\u2013%.0f%%</div>', mn, mx)
  }
  .rng_n <- function(vals) {
    mn <- min(vals, na.rm = TRUE); mx <- max(vals, na.rm = TRUE)
    if (!is.finite(mn) || !is.finite(mx)) return("")
    sprintf('<div class="cb-perf-range">%.1f\u2013%.1f</div>', mn, mx)
  }

  # Sort order: focal first, then other brands by penetration descending
  focal_idx  <- if (!is.null(focal_brand))
    which(norms_table$BrandCode == focal_brand) else integer(0)
  other_idx  <- setdiff(seq_len(nrow(norms_table)), focal_idx)
  if (length(other_idx) > 0 && "Penetration_Obs_Pct" %in% names(norms_table))
    other_idx <- other_idx[order(-norms_table$Penetration_Obs_Pct[other_idx])]
  nt <- norms_table[c(focal_idx, other_idx), , drop = FALSE]

  # Unique table ID (for JS sort)
  tbl_id <- paste0("cbpt-", gsub("[^a-z0-9]", "",
                    tolower(focal_brand %||% paste0("x", nrow(norms_table)))))

  # --- Tooltips ---
  pen_tip <- sprintf(
    paste0("%% of respondents who bought this brand in the last %d months ",
           "(BRANDPEN3 purchase counts, reconciled). May differ from the Brand Funnel ",
           "by 1\u20133pp: BRANDPEN3 reconciliation promotes respondents who reported ",
           "purchases but did not tick the buyer flag on BRANDPEN2."),
    as.integer(target_months))
  br_tip <- paste0(
    "Mean number of times this brand was bought by brand buyers in the target window. ",
    "Only counts respondents who bought this brand (i.e. brand buyers, not all respondents).")
  vs_tip <- paste0(
    "Brand\u2019s estimated share of total category purchase volume. ",
    "Computed as (Pen \u00d7 Avg purchases) \u00f7 category mean purchases. ",
    "Brands not in this list account for any shortfall from 100%%.")
  scr_tip <- paste0(
    "Share of Category Requirement (observed): among this brand\u2019s buyers, ",
    "the % of their total category purchases that go to this brand. ",
    "This is a loyalty metric \u2014 it does NOT sum to 100%% across brands ",
    "because each brand\u2019s SCR is measured within its own buyer group.")

  # --- Inline sort JS (emitted once per table) ---
  sort_js <- sprintf(
    '<script>(function(){window._cbpSort=window._cbpSort||function(th,id,ci){var asc=th.dataset.asc!=="1";th.dataset.asc=asc?"1":"0";var body=document.querySelector("#"+id+" tbody");var rows=Array.from(body.querySelectorAll("tr.cbp-brand-row"));rows.sort(function(a,b){var av=parseFloat(a.cells[ci].dataset.v)||0,bv=parseFloat(b.cells[ci].dataset.v)||0;return(asc?1:-1)*(av-bv);});rows.forEach(function(r){body.appendChild(r);});document.querySelectorAll("#"+id+" .cb-sort-arr").forEach(function(s){s.textContent="\u21c5";});th.querySelector(".cb-sort-arr").textContent=asc?"\u2191":"\u2193";};})();</script>',
    character(0))

  # --- Build HTML ---
  lines <- character(0)
  lines <- c(lines, sort_js)
  lines <- c(lines, '<div class="cb-brand-freq-wrap">')
  lines <- c(lines, sprintf('<table class="cb-brand-freq-table" id="%s">', tbl_id))

  # Header row with sort buttons on numeric columns
  .sort_th <- function(label, ci, tip = "") {
    tip_attr <- if (nzchar(tip)) sprintf(' title="%s"', .cb_esc(tip)) else ""
    sprintf(
      '<th class="cb-sort-th"%s onclick="_cbpSort(this,\'%s\',%d)">%s<span class="cb-sort-arr">\u21c5</span></th>',
      tip_attr, tbl_id, ci, label)
  }

  lines <- c(lines, '<thead><tr>',
    '<th style="text-align:left;cursor:default;" onclick="_cbpSort(this,\'',
    tbl_id, '\',0)">Brand <span class="cb-sort-arr">\u21c5</span></th>',
    '<th title="Weighted respondent count who bought this brand (BRANDPEN3 reconciled)">Base<br/>(n=)</th>',
    .sort_th("Pen", 2L, pen_tip),
    .sort_th("Avg purch.", 3L, br_tip),
    .sort_th("Vol share", 4L, vs_tip),
    .sort_th("SCR obs", 5L, scr_tip),
    .sort_th("SCR exp", 6L, "Dirichlet model-expected SCR for this brand."),
    .sort_th("\u0394 SCR", 7L,
             "SCR deviation from expected (percentage points). \u2265\u00b120pp shaded."),
    '</tr></thead><tbody>')

  # --- Focal brand row (first) ---
  if (length(focal_idx) == 1) {
    frow   <- norms_table[focal_idx, ]
    bc     <- as.character(frow$BrandCode)
    lbl    <- .cb_brand_lbl(bc, brand_labels)
    pen_v  <- .get(frow, "Penetration_Obs_Pct")
    br_v   <- .get(frow, "BuyRate_Obs")
    scro_v <- .get(frow, "SCR_Obs_Pct")
    scre_v <- .get(frow, "SCR_Exp_Pct")
    scrd_v <- .get(frow, "SCR_Dev_Pct")
    vs_v   <- vol_share_fn(pen_v, br_v)
    n_v    <- .bh_n(bc)
    dev_str <- if (!is.na(scrd_v)) sprintf("%+.0f", scrd_v) else "\u2014"
    # focal-row class is consistent with _cbSetFocal in brand_cat_buying_panel.js
    lines <- c(lines,
      sprintf('<tr class="focal-row" data-brand="%s">', .cb_esc(bc)),
      sprintf('<td class="brand-col">%s<span class="cb-focal-badge">FOCAL</span></td>',
              .cb_esc(lbl)),
      sprintf('<td data-v="%s">%s</td>',
              if (!is.na(n_v)) as.character(n_v) else "0", fmt_int(n_v)),
      sprintf('<td data-v="%.2f">%s</td>', pen_v %||% 0, fmt_pct(pen_v)),
      sprintf('<td data-v="%.3f">%s</td>', br_v  %||% 0, fmt_n(br_v)),
      sprintf('<td data-v="%.2f">%s</td>', vs_v  %||% 0, fmt_pct(vs_v)),
      sprintf('<td data-v="%.2f">%s</td>', scro_v %||% 0, fmt_pct(scro_v)),
      sprintf('<td data-v="%.2f" style="color:#64748b;">%s</td>',
              scre_v %||% 0, fmt_pct(scre_v)),
      sprintf('<td data-v="%.2f"%s>%s</td>', scrd_v %||% 0, dev_cls(scrd_v), dev_str),
      '</tr>')
  }

  # --- Category average row (second) with min-max range context ---
  avg_dev_str <- if (!is.na(avg_scrd)) sprintf("%+.0f", avg_scrd) else "\u2014"
  lines <- c(lines,
    '<tr class="cbp-avg-row">',
    '<td class="brand-col" style="font-style:italic;">Category avg</td>',
    '<td>\u2014</td>',
    sprintf('<td data-v="%.2f">%s%s</td>',
            avg_pen, fmt_pct(avg_pen), .rng(all_pen)),
    sprintf('<td data-v="%.3f">%s%s</td>',
            avg_br, fmt_n(avg_br), .rng_n(all_br)),
    sprintf('<td data-v="%.2f">%s%s</td>',
            avg_vs, fmt_pct(avg_vs), .rng(all_vs)),
    sprintf('<td data-v="%.2f">%s%s</td>',
            avg_scro, fmt_pct(avg_scro), .rng(all_scro)),
    sprintf('<td data-v="%.2f" style="color:#94a3b8;">%s</td>',
            avg_scre, fmt_pct(avg_scre)),
    sprintf('<td data-v="%.2f">%s</td>', avg_scrd, avg_dev_str),
    '</tr>')

  # --- Other brand rows (sortable; class cbp-brand-row for JS targeting) ---
  for (i in seq_len(nrow(nt))) {
    row <- nt[i, ]
    bc  <- as.character(row$BrandCode)
    if (!is.null(focal_brand) && bc == focal_brand) next  # rendered above
    lbl    <- .cb_brand_lbl(bc, brand_labels)
    pen_v  <- .get(row, "Penetration_Obs_Pct")
    br_v   <- .get(row, "BuyRate_Obs")
    scro_v <- .get(row, "SCR_Obs_Pct")
    scre_v <- .get(row, "SCR_Exp_Pct")
    scrd_v <- .get(row, "SCR_Dev_Pct")
    vs_v   <- vol_share_fn(pen_v, br_v)
    n_v    <- .bh_n(bc)
    dev_str <- if (!is.na(scrd_v)) sprintf("%+.0f", scrd_v) else "\u2014"

    lines <- c(lines,
      sprintf('<tr class="cbp-brand-row" data-brand="%s">', .cb_esc(bc)),
      sprintf('<td class="brand-col" data-v="%s">%s</td>',
              .cb_esc(lbl), .cb_esc(lbl)),
      sprintf('<td data-v="%s">%s</td>',
              if (!is.na(n_v)) as.character(n_v) else "0", fmt_int(n_v)),
      sprintf('<td data-v="%.2f">%s</td>', pen_v  %||% 0, fmt_pct(pen_v)),
      sprintf('<td data-v="%.3f">%s</td>', br_v   %||% 0, fmt_n(br_v)),
      sprintf('<td data-v="%.2f">%s</td>', vs_v   %||% 0, fmt_pct(vs_v)),
      sprintf('<td data-v="%.2f">%s</td>', scro_v %||% 0, fmt_pct(scro_v)),
      sprintf('<td data-v="%.2f" style="color:#64748b;">%s</td>',
              scre_v %||% 0, fmt_pct(scre_v)),
      sprintf('<td data-v="%.2f"%s>%s</td>', scrd_v %||% 0, dev_cls(scrd_v), dev_str),
      '</tr>')
  }

  lines <- c(lines, '</tbody>')

  vol_note <- if (!is.na(cat_mean_purch))
    sprintf("Vol share = (Pen \u00d7 Avg purch.) \u00f7 %.1f (category mean). ", cat_mean_purch)
  else "Vol share requires category mean purchases. "
  lines <- c(lines, sprintf(
    '<tfoot><tr><td colspan="8" style="font-size:10px;color:#94a3b8;padding:5px 4px;font-style:italic;">%s</td></tr></tfoot>',
    paste0(
      "Pen = % of respondents who bought the brand (BRANDPEN3, reconciled; ",
      "may differ from Brand Funnel by 1\u20133pp \u2014 see column tooltip). ",
      "Avg purch. = mean times bought per brand buyer. ",
      "SCR obs = share of category requirement (loyalty \u2014 does not sum to 100%% across brands). ",
      vol_note,
      "\u0394\u2265\u00b120pp shaded. Click column headers to sort brands.")))
  lines <- c(lines, '</table></div>')
  paste(lines, collapse = "\n")
}


#' Build the partition callout for the DoP heatmap (§8 item 5)
#'
#' Checks whether 3+ brands share mutual positive deviations > 10pp and
#' emits a callout paragraph.
#'
#' @param dev_matrix Data frame. \code{dop_deviation_matrix}.
#' @return Character. HTML paragraph or empty string.
#' @keywords internal
cb_partition_callout_html <- function(dev_matrix) {
  if (is.null(dev_matrix) || nrow(dev_matrix) < 3) return("")

  brands <- dev_matrix$BrandCode
  n      <- length(brands)
  THRESHOLD <- 10

  # Find brands that are mutually positive > threshold with at least 2 others
  cluster_brands <- character(0)
  for (i in seq_along(brands)) {
    strong_partners <- character(0)
    for (j in seq_along(brands)) {
      if (i == j) next
      v_ij <- tryCatch(as.numeric(dev_matrix[i, brands[j]]), error = function(e) NA)
      v_ji <- tryCatch(as.numeric(dev_matrix[j, brands[i]]), error = function(e) NA)
      if (!is.na(v_ij) && !is.na(v_ji) && v_ij > THRESHOLD && v_ji > THRESHOLD) {
        strong_partners <- c(strong_partners, brands[j])
      }
    }
    if (length(strong_partners) >= 2) {
      cluster_brands <- c(cluster_brands, brands[i])
    }
  }
  cluster_brands <- unique(cluster_brands)

  if (length(cluster_brands) >= 3) {
    return(sprintf(
      '<div style="background:#fef9c3;border:1px solid #fde68a;border-radius:6px;padding:10px 14px;margin:8px 0;font-size:12px;color:#92400e;">\u26a0 <strong>Partition candidate:</strong> %s show strong mutual positive duplication (&gt;10pp above the DoP law). These brands may serve a distinct sub-segment or usage occasion.</div>',
      paste(cluster_brands, collapse = ", ")))
  }
  ""
}
