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
#' Returns two side-by-side tables in a CSS grid wrapper. Both tables are
#' always rendered; if data is unavailable an informative note is shown.
#'
#' Purchase Frequency uses the category-level 1x / 2x / 3-5x / 6+x buckets
#' derived from BRANDPEN3 purchase counts (\code{bh$category_freq_dist}),
#' matching the column headers used on the Purchase Distribution sub-tab.
#' Custom bucket labels may be supplied via \code{dist_labels}.
#'
#' @param cat_fd Data frame or NULL. From
#'   \code{run_buyer_heaviness()$category_freq_dist}. Columns: Bucket, Label,
#'   Pct, n. Pct is % of category buyers in each bucket.
#' @param rep List or NULL. \code{repertoire} result from run_brand().
#'   Must contain \code{rep$repertoire_size} with columns
#'   \code{Brands_Bought} and \code{Percentage}.
#' @param dist_labels Character vector of length 4 or NULL. Overrides the
#'   default bucket labels (1x / 2x / 3-5x / 6+x).
#'
#' @return Character. HTML string (two-column grid with compact tables).
#' @keywords internal
cb_freq_repertoire_tables_html <- function(cat_fd = NULL, rep = NULL,
                                            dist_labels = NULL) {
  lines <- character(0)
  lines <- c(lines, '<div class="cb-context-tables">')

  # --- Category Purchase Frequency (BRANDPEN3 buckets) ---
  lines <- c(lines, '<div>')
  lines <- c(lines, '<div class="cb-ctx-subtitle">Category Purchase Frequency</div>')

  freq_ok <- !is.null(cat_fd) && is.data.frame(cat_fd) && nrow(cat_fd) > 0 &&
             "Pct" %in% names(cat_fd)

  if (freq_ok) {
    default_lbl <- c("1\u00d7", "2\u00d7", "3\u20135\u00d7", "6+\u00d7")
    labels <- if (!is.null(dist_labels) && length(dist_labels) == 4L)
      as.character(dist_labels)
    else if ("Label" %in% names(cat_fd))
      as.character(cat_fd$Label)
    else default_lbl

    lines <- c(lines, '<table class="cb-ctx-table">')
    lines <- c(lines, '<thead><tr><th>Purchases in window</th><th style="text-align:right;">%</th></tr></thead>')
    lines <- c(lines, '<tbody>')
    for (i in seq_len(nrow(cat_fd))) {
      lbl_i <- .cb_esc(labels[i])
      pct_i <- if (!is.na(cat_fd$Pct[i])) sprintf("%.1f%%", cat_fd$Pct[i])
               else "\u2014"
      lines <- c(lines, sprintf('<tr><td>%s</td><td style="text-align:right;">%s</td></tr>',
                                 lbl_i, pct_i))
    }
    lines <- c(lines, '</tbody></table>')
    lines <- c(lines, '<p style="font-size:10px;color:#94a3b8;margin:4px 0 0;font-style:italic;">% of category buyers by total category purchases in target window (BRANDPEN3).</p>')
  } else {
    lines <- c(lines, '<p style="font-size:12px;color:#94a3b8;">Category frequency data not available.</p>')
  }
  lines <- c(lines, '</div>')

  # --- Repertoire Size Distribution ---
  lines <- c(lines, '<div>')
  lines <- c(lines, '<div class="cb-ctx-subtitle">Repertoire Size</div>')

  rep_ok <- !is.null(rep) && !identical(rep$status, "REFUSED") &&
            !is.null(rep$repertoire_size) && nrow(rep$repertoire_size) > 0

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

  # Column-wise stats across all brands (for category avg row + heatmap/CI bands)
  all_pen  <- as.numeric(norms_table$Penetration_Obs_Pct)
  all_br   <- as.numeric(norms_table$BuyRate_Obs)
  all_scro <- as.numeric(norms_table$SCR_Obs_Pct)
  all_vs   <- vapply(seq_len(nrow(norms_table)),
    function(i) vol_share_fn(all_pen[i], all_br[i]), numeric(1))

  avg_pen  <- mean(all_pen,  na.rm = TRUE)
  avg_br   <- mean(all_br,   na.rm = TRUE)
  avg_scro <- mean(all_scro, na.rm = TRUE)
  avg_vs   <- mean(all_vs,   na.rm = TRUE)

  sd_pen  <- stats::sd(all_pen,  na.rm = TRUE)
  sd_br   <- stats::sd(all_br,   na.rm = TRUE)
  sd_scro <- stats::sd(all_scro, na.rm = TRUE)
  sd_vs   <- stats::sd(all_vs,   na.rm = TRUE)

  # CI band = cross-brand 1-SD spread around the mean (a visual band, not a
  # sampling-CI). Mirrors the "range" hint MA shows under cat-avg cells.
  .ci_band <- function(mn, sd_v, digits = 0, pct = TRUE) {
    if (!is.finite(mn) || !is.finite(sd_v) || sd_v == 0) return("")
    lo <- mn - sd_v; hi <- mn + sd_v
    fmt <- if (pct) sprintf("%%.%df%%%%\u2013%%.%df%%%%", digits, digits) else
      sprintf("%%.%df\u2013%%.%df", digits, digits)
    sprintf('<div class="cb-ci-band" title="\u00b11 SD across brands">%s</div>',
            sprintf(fmt, lo, hi))
  }

  # Heatmap cell class (relative to cat avg \u00b11 SD "CI band"):
  # green  = above upper band (v > avg + sd)
  # red    = below lower band (v < avg - sd)
  # amber  = within the band
  .hm_cls <- function(v, avg, sd_v) {
    if (is.na(v) || is.na(avg) || !is.finite(sd_v) || sd_v <= 0) return("")
    if (v > avg + sd_v)       " cb-hm-above"
    else if (v < avg - sd_v)  " cb-hm-below"
    else                      " cb-hm-near"
  }
  .hm_cell <- function(v, avg, sd_v, text, d = 2) {
    cls <- .hm_cls(v, avg, sd_v)
    sprintf('<td class="cb-hm-cell%s" data-v="%s">%s</td>',
            cls,
            if (is.na(v)) "" else formatC(v, format = "f", digits = d),
            text)
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

  # --- Header: sort buttons on numeric columns (MA-style indicator) ---
  .sort_th <- function(label, ci, tip = "") {
    tip_attr <- if (nzchar(tip)) sprintf(' title="%s"', .cb_esc(tip)) else ""
    sprintf(
      paste0('<th class="cb-sort-th" data-sort-col="%d"%s>',
             '<div class="ct-header-text">%s</div>',
             '<button type="button" class="ct-sort-indicator" aria-label="Sort by %s" ',
             'data-cb-action="sort" data-cb-sort-col="%d" data-cb-sort-table="%s" ',
             'data-cb-sort-dir="none">\u21C5</button>',
             '</th>'),
      ci, tip_attr, label, .cb_esc(label), ci, tbl_id)
  }

  header_html <- paste0(
    '<thead><tr>',
    '<th class="ct-label-col" style="text-align:left;">Brand</th>',
    sprintf('<th title="%s" class="cb-base-th">Base<br/>(n=)</th>',
            .cb_esc("Weighted respondent count who bought this brand (BRANDPEN3 reconciled).")),
    .sort_th("Pen",        2L, pen_tip),
    .sort_th("Avg purch.", 3L, br_tip),
    .sort_th("Vol share",  4L, vs_tip),
    .sort_th("SCR obs",    5L, scr_tip),
    '</tr></thead>'
  )

  # --- Build body rows ---
  .row_html <- function(row, row_cls, lbl_html) {
    bc     <- as.character(row$BrandCode)
    pen_v  <- .get(row, "Penetration_Obs_Pct")
    br_v   <- .get(row, "BuyRate_Obs")
    scro_v <- .get(row, "SCR_Obs_Pct")
    vs_v   <- vol_share_fn(pen_v, br_v)
    n_v    <- .bh_n(bc)
    paste0(
      sprintf('<tr class="%s" data-brand="%s">', row_cls, .cb_esc(bc)),
      sprintf('<td class="ct-label-col">%s</td>', lbl_html),
      sprintf('<td class="cb-base-td" data-v="%s">%s</td>',
              if (is.na(n_v)) "0" else as.character(n_v), fmt_int(n_v)),
      .hm_cell(pen_v,  avg_pen,  sd_pen,  fmt_pct(pen_v)),
      .hm_cell(br_v,   avg_br,   sd_br,   fmt_n(br_v), d = 3),
      .hm_cell(vs_v,   avg_vs,   sd_vs,   fmt_pct(vs_v)),
      .hm_cell(scro_v, avg_scro, sd_scro, fmt_pct(scro_v)),
      '</tr>')
  }

  body_rows <- character(0)

  # Row 1: focal
  if (length(focal_idx) == 1) {
    frow <- norms_table[focal_idx, ]
    lbl  <- .cb_brand_lbl(frow$BrandCode, brand_labels)
    lbl_html <- sprintf('%s<span class="cb-focal-badge">FOCAL</span>', .cb_esc(lbl))
    body_rows <- c(body_rows, .row_html(frow, "focal-row", lbl_html))
  }

  # Row 2: category avg (with CI bands)
  body_rows <- c(body_rows, paste0(
    '<tr class="cbp-avg-row">',
    '<td class="ct-label-col" style="font-style:italic;">Category avg</td>',
    '<td class="cb-base-td">\u2014</td>',
    sprintf('<td class="cb-avg-td" data-v="%s">%s%s</td>',
            formatC(avg_pen, format = "f", digits = 2),
            fmt_pct(avg_pen), .ci_band(avg_pen, sd_pen, 0, TRUE)),
    sprintf('<td class="cb-avg-td" data-v="%s">%s%s</td>',
            formatC(avg_br, format = "f", digits = 3),
            fmt_n(avg_br), .ci_band(avg_br, sd_br, 1, FALSE)),
    sprintf('<td class="cb-avg-td" data-v="%s">%s%s</td>',
            formatC(avg_vs, format = "f", digits = 2),
            fmt_pct(avg_vs), .ci_band(avg_vs, sd_vs, 0, TRUE)),
    sprintf('<td class="cb-avg-td" data-v="%s">%s%s</td>',
            formatC(avg_scro, format = "f", digits = 2),
            fmt_pct(avg_scro), .ci_band(avg_scro, sd_scro, 0, TRUE)),
    '</tr>'))

  # Rows 3+: other brands (sortable)
  for (i in seq_len(nrow(nt))) {
    row <- nt[i, ]
    bc  <- as.character(row$BrandCode)
    if (!is.null(focal_brand) && bc == focal_brand) next
    lbl <- .cb_brand_lbl(bc, brand_labels)
    body_rows <- c(body_rows, .row_html(row, "cbp-brand-row", .cb_esc(lbl)))
  }

  paste(c(
    '<div class="cb-brand-freq-wrap">',
    sprintf('<table class="cb-brand-freq-table" id="%s" data-cb-heatmap="off">', tbl_id),
    header_html,
    '<tbody>',
    body_rows,
    '</tbody>',
    '</table></div>'
  ), collapse = "\n")
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
