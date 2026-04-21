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
#' always rendered; if data is unavailable an informative note is shown instead.
#'
#' @param cbf List or NULL. \code{cat_buying_frequency} result from run_brand().
#'   Must contain \code{cbf$distribution} with columns \code{Label} and \code{Pct}.
#' @param rep List or NULL. \code{repertoire} result from run_brand().
#'   Must contain \code{rep$repertoire_size} with columns
#'   \code{Brands_Bought} and \code{Percentage}.
#'
#' @return Character. HTML string (two-column grid with compact tables).
#' @keywords internal
cb_freq_repertoire_tables_html <- function(cbf = NULL, rep = NULL) {
  lines <- character(0)
  lines <- c(lines, '<div class="cb-context-tables">')

  # --- Purchase Frequency Distribution ---
  lines <- c(lines, '<div>')
  lines <- c(lines, '<div class="cb-section-title" style="margin-top:0;">Category Purchase Frequency</div>')

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

  # --- Repertoire Size Distribution ---
  lines <- c(lines, '<div>')
  lines <- c(lines, '<div class="cb-section-title" style="margin-top:0;">Repertoire Size</div>')

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
