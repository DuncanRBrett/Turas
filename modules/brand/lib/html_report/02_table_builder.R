# ==============================================================================
# BRAND HTML REPORT - TABLE BUILDER
# ==============================================================================
# Builds styled HTML tables for each element type.
# Layer 2 of the 4-layer pipeline.
# ==============================================================================

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

.bt_esc <- function(x) {
  if (is.null(x) || is.na(x)) return("")
  x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}

.bt_fmt <- function(x, d = 1, pct = FALSE) {
  if (is.na(x)) return("\u2014")
  if (pct) sprintf("%.*f%%", d, x) else sprintf("%.*f", d, x)
}


#' Build a generic styled table
#'
#' @param df Data frame.
#' @param focal_col Character. Column name used to identify the focal brand row.
#' @param focal_value Character. Value to highlight.
#' @param pct_cols Character vector. Columns to format as percentages.
#' @param caption Character. Caption below table.
#' @param title Character. Title above table.
#'
#' @return HTML string.
#' @keywords internal
build_br_table <- function(df, focal_col = NULL, focal_value = NULL,
                           pct_cols = NULL, caption = NULL, title = NULL) {
  if (is.null(df) || nrow(df) == 0) return("")

  lines <- character(0)
  if (!is.null(title)) {
    lines <- c(lines, sprintf('<div style="font-size:14px;font-weight:600;color:#334155;margin:16px 0 6px;">%s</div>',
                               .bt_esc(title)))
  }

  lines <- c(lines, '<div style="overflow-x:auto;margin:8px 0 16px;">')
  lines <- c(lines, '<table class="br-table">')

  if (!is.null(caption)) {
    lines <- c(lines, sprintf('<caption style="font-size:11px;color:#94a3b8;text-align:left;padding:4px 0;">%s</caption>',
                               .bt_esc(caption)))
  }

  # Header
  lines <- c(lines, '<thead><tr>')
  for (col in names(df)) {
    display_col <- gsub("_", " ", col)
    lines <- c(lines, sprintf('<th>%s</th>', .bt_esc(display_col)))
  }
  lines <- c(lines, '</tr></thead><tbody>')

  # Rows
  for (i in seq_len(nrow(df))) {
    is_focal <- FALSE
    if (!is.null(focal_col) && !is.null(focal_value) && focal_col %in% names(df)) {
      is_focal <- !is.na(df[[focal_col]][i]) && df[[focal_col]][i] == focal_value
    }
    rc <- if (is_focal) ' class="focal-row"' else ""
    lines <- c(lines, sprintf('<tr%s>', rc))

    for (col in names(df)) {
      val <- df[[col]][i]
      if (!is.null(pct_cols) && col %in% pct_cols && is.numeric(val)) {
        cell <- .bt_fmt(val, 1, TRUE)
      } else if (is.numeric(val)) {
        cell <- .bt_fmt(val, 2)
      } else {
        cell <- .bt_esc(as.character(val))
      }
      lines <- c(lines, sprintf('<td>%s</td>', cell))
    }
    lines <- c(lines, '</tr>')
  }

  lines <- c(lines, '</tbody></table></div>')
  paste(lines, collapse = "\n")
}


#' Build all tables for Mental Availability
#' @keywords internal
build_ma_tables <- function(ma, focal_brand) {
  if (is.null(ma) || identical(ma$status, "REFUSED")) return("")

  parts <- character(0)

  parts <- c(parts, build_br_table(
    ma$mms, "BrandCode", focal_brand, pct_cols = "MMS",
    title = "Mental Market Share",
    caption = sprintf("n = %d category buyers", ma$n_respondents %||% 0)))

  parts <- c(parts, build_br_table(
    ma$mpen, "BrandCode", focal_brand, pct_cols = "MPen",
    title = "Mental Penetration"))

  parts <- c(parts, build_br_table(
    ma$ns, "BrandCode", focal_brand,
    title = "Network Size (avg CEPs per linker)"))

  if (!is.null(ma$cep_turf) && !is.null(ma$cep_turf$incremental_table)) {
    parts <- c(parts, build_br_table(
      ma$cep_turf$incremental_table, NULL, NULL,
      pct_cols = c("Reach_Pct", "Incremental_Pct"),
      title = "CEP TURF \u2014 Optimal Reach Sequence"))
  }

  paste(parts, collapse = "\n")
}


#' Build all tables for Funnel (role-registry architecture)
#'
#' Consumes the new long-format \code{funnel$stages} directly. Falls back
#' to the legacy wide adapter to keep the table's column schema stable
#' while the HTML renderers are being migrated to the new data contract.
#'
#' @keywords internal
build_funnel_tables <- function(funnel, focal_brand) {
  if (is.null(funnel) || identical(funnel$status, "REFUSED")) return("")
  if (is.null(funnel$stages) || nrow(funnel$stages) == 0) return("")

  brand_codes <- unique(as.character(funnel$stages$brand_code))
  brand_list <- data.frame(BrandCode = brand_codes, stringsAsFactors = FALSE)

  legacy_wide <- build_funnel_legacy_wide(funnel, brand_list)
  legacy_conv <- build_funnel_legacy_conversions(funnel, brand_list)

  parts <- character(0)
  parts <- c(parts, build_br_table(
    legacy_wide, "BrandCode", focal_brand,
    pct_cols = c("Aware_Pct", "Positive_Pct", "Love_Pct", "Prefer_Pct",
                 "Ambivalent_Pct", "Reject_Pct", "NoOpinion_Pct",
                 "Bought_Pct", "Primary_Pct"),
    title = "Funnel Stage Metrics",
    caption = sprintf("Base: n = %d unweighted",
                      funnel$meta$n_unweighted %||% 0)))

  if (nrow(legacy_conv) > 0) {
    parts <- c(parts, build_br_table(
      legacy_conv, "BrandCode", focal_brand,
      pct_cols = c("Aware_to_Positive", "Positive_to_Bought",
                   "Bought_to_Primary"),
      title = "Stage-to-Stage Conversion (%)"))
  }

  paste(parts, collapse = "\n")
}


#' Build all tables for Repertoire
#' @keywords internal
build_repertoire_tables <- function(rep, focal_brand) {
  if (is.null(rep) || identical(rep$status, "REFUSED")) return("")

  parts <- character(0)
  parts <- c(parts, build_br_table(
    rep$repertoire_size, NULL, NULL, pct_cols = "Percentage",
    title = sprintf("Repertoire Size Distribution (mean: %.1f brands)",
                    rep$mean_repertoire)))
  parts <- c(parts, build_br_table(
    rep$sole_loyalty, "BrandCode", focal_brand, pct_cols = "SoleLoyalty_Pct",
    title = "Sole Loyalty — % of brand buyers who only buy this brand",
    caption = sprintf("Base: category buyers (n = %d)", rep$n_buyers %||% 0)))
  paste(parts, collapse = "\n")
}


#' Build the Duplication of Purchase crossover grid
#'
#' Renders a heatmap-style HTML table where each cell [i, j] shows the
#' percentage of brand_i buyers who also buy brand_j. The diagonal is 100.
#' Focal brand row and column are highlighted.
#'
#' @param crossover_matrix Data frame. BrandCode column + one column per brand.
#' @param focal_brand Character. Focal brand code to highlight.
#'
#' @return HTML string.
#' @keywords internal
build_crossover_grid_table <- function(crossover_matrix, focal_brand = NULL) {
  if (is.null(crossover_matrix) || nrow(crossover_matrix) == 0) return("")

  brand_codes <- crossover_matrix$BrandCode
  col_brands  <- setdiff(names(crossover_matrix), "BrandCode")
  if (length(col_brands) == 0) return("")

  .heat_bg <- function(v) {
    if (is.na(v) || v >= 100) return("background:#e2e8f0;")
    if (v >= 60) return("background:#bfdbfe;")
    if (v >= 40) return("background:#dbeafe;")
    if (v >= 20) return("background:#eff6ff;")
    "background:#f8fafc;"
  }

  lines <- character(0)
  lines <- c(lines,
    '<div style="font-size:14px;font-weight:600;color:#334155;margin:16px 0 6px;">',
    'Duplication of Purchase \u2014 % of row-brand buyers who also buy column brand',
    '</div>',
    '<p style="font-size:11px;color:#94a3b8;margin:0 0 8px;">',
    'Read across each row: of buyers who bought [row brand], what share also bought each other brand?',
    '</p>',
    '<div style="overflow-x:auto;margin:0 0 16px;">',
    '<table class="br-table" style="font-size:12px;">')

  # Header row
  lines <- c(lines, '<thead><tr>')
  lines <- c(lines, '<th style="text-align:left;">Bought \u2193 / Also bought \u2192</th>')
  for (cb in col_brands) {
    is_focal_col <- !is.null(focal_brand) && cb == focal_brand
    fw <- if (is_focal_col) "700" else "400"
    col_style <- if (is_focal_col)
      sprintf('style="font-weight:%s;background:#eff6ff;"', fw)
    else
      sprintf('style="font-weight:%s;"', fw)
    lines <- c(lines, sprintf('<th %s>%s</th>', col_style, .bt_esc(cb)))
  }
  lines <- c(lines, '</tr></thead><tbody>')

  # Data rows
  for (i in seq_along(brand_codes)) {
    bc        <- brand_codes[i]
    is_focal  <- !is.null(focal_brand) && bc == focal_brand
    row_style <- if (is_focal) ' class="focal-row"' else ""
    lines <- c(lines, sprintf('<tr%s>', row_style))

    fw_label <- if (is_focal) "700" else "400"
    lines <- c(lines, sprintf(
      '<td style="font-weight:%s;">%s</td>', fw_label, .bt_esc(bc)))

    for (cb in col_brands) {
      val <- crossover_matrix[[cb]][i]
      cell_text <- if (is.na(val)) "\u2014"
                   else if (val >= 100) "\u2014"
                   else sprintf("%.0f%%", val)
      cell_style <- .heat_bg(val)
      if (!is.null(focal_brand) && cb == focal_brand) {
        cell_style <- paste0(cell_style, "font-weight:600;")
      }
      lines <- c(lines, sprintf('<td style="%s text-align:center;">%s</td>',
                                 cell_style, cell_text))
    }
    lines <- c(lines, '</tr>')
  }

  lines <- c(lines, '</tbody></table></div>')
  paste(lines, collapse = "\n")
}


#' Build per-brand loyalty profile table
#'
#' Shows for each brand the % of its buyers who are sole-loyal, dual-brand,
#' or multi-brand shoppers, plus mean repertoire size among that brand's buyers.
#'
#' @param brand_repertoire_profile Data frame from run_repertoire()
#'   with columns BrandCode, Brand_Buyers_n, Sole_Pct, Dual_Pct, Multi_Pct,
#'   Mean_Repertoire.
#' @param focal_brand Character.
#'
#' @return HTML string.
#' @keywords internal
build_brand_repertoire_profile_table <- function(brand_repertoire_profile,
                                                  focal_brand = NULL) {
  if (is.null(brand_repertoire_profile) ||
      nrow(brand_repertoire_profile) == 0) return("")

  display <- brand_repertoire_profile
  names(display)[names(display) == "BrandCode"]       <- "Brand"
  names(display)[names(display) == "Brand_Buyers_n"]  <- "n buyers"
  names(display)[names(display) == "Sole_Pct"]        <- "Sole loyal %"
  names(display)[names(display) == "Dual_Pct"]        <- "Dual-brand %"
  names(display)[names(display) == "Multi_Pct"]       <- "Multi-brand %"
  names(display)[names(display) == "Mean_Repertoire"] <- "Mean repertoire"

  build_br_table(
    display, "Brand", focal_brand,
    pct_cols = c("Sole loyal %", "Dual-brand %", "Multi-brand %"),
    title    = "Buyer Loyalty Profile — repertoire depth among each brand\u2019s buyers",
    caption  = "Sole = bought only this brand; Dual = this brand + 1 other; Multi = this brand + 2 or more others")
}


#' Build all Category Buying tables
#'
#' Combines purchase frequency distribution, repertoire depth, brand loyalty
#' profile, and duplication of purchase grid.
#'
#' @param rep List. Output from run_repertoire().
#' @param cat_buying_freq List or NULL. Output from run_cat_buying_frequency().
#' @param focal_brand Character.
#'
#' @return HTML string.
#' @keywords internal
build_cat_buying_tables <- function(rep, cat_buying_freq = NULL,
                                    focal_brand) {
  parts <- character(0)

  # --- 1. Frequency distribution table ---
  if (!is.null(cat_buying_freq) &&
      !identical(cat_buying_freq$status, "REFUSED") &&
      !is.null(cat_buying_freq$distribution)) {

    dist_display <- cat_buying_freq$distribution[
      , intersect(c("Label", "Pct", "n"), names(cat_buying_freq$distribution)),
      drop = FALSE]
    names(dist_display)[names(dist_display) == "Label"] <- "Frequency"
    names(dist_display)[names(dist_display) == "Pct"]   <- "Pct (%)"
    names(dist_display)[names(dist_display) == "n"]     <- "n"

    n_all <- cat_buying_freq$n_respondents %||% 0
    cap_n <- if (!is.na(n_all) && n_all > 0)
      sprintf("Base: all respondents (n = %d)", n_all) else ""

    parts <- c(parts, build_br_table(
      dist_display, NULL, NULL,
      pct_cols = "Pct (%)",
      title    = "Category Purchase Frequency",
      caption  = cap_n))
  }

  # --- 2. Repertoire depth (category-level) ---
  if (!is.null(rep) && !identical(rep$status, "REFUSED")) {
    parts <- c(parts, build_repertoire_tables(rep, focal_brand))
  }

  # --- 3. Per-brand loyalty profile ---
  if (!is.null(rep) && !identical(rep$status, "REFUSED") &&
      !is.null(rep$brand_repertoire_profile)) {
    parts <- c(parts, build_brand_repertoire_profile_table(
      rep$brand_repertoire_profile, focal_brand))
  }

  # --- 4. Duplication of purchase crossover grid ---
  if (!is.null(rep) && !identical(rep$status, "REFUSED") &&
      !is.null(rep$crossover_matrix)) {
    parts <- c(parts, build_crossover_grid_table(rep$crossover_matrix,
                                                  focal_brand))
  }

  paste(parts, collapse = "\n")
}


#' Build WOM tables
#' @keywords internal
build_wom_tables <- function(wom, focal_brand) {
  if (is.null(wom) || identical(wom$status, "REFUSED")) return("")
  parts <- character(0)
  parts <- c(parts, build_br_table(
    wom$wom_metrics, "BrandCode", focal_brand,
    pct_cols = c("ReceivedPos_Pct", "ReceivedNeg_Pct", "SharedPos_Pct", "SharedNeg_Pct"),
    title = "Word-of-Mouth Metrics"))
  parts <- c(parts, build_br_table(
    wom$net_balance, "BrandCode", focal_brand,
    title = "Net WOM Balance (positive \u2212 negative)"))
  paste(parts, collapse = "\n")
}


#' Build DBA tables
#' @keywords internal
build_dba_tables <- function(dba) {
  if (is.null(dba) || identical(dba$status, "REFUSED")) return("")
  build_br_table(
    dba$dba_metrics, NULL, NULL,
    pct_cols = c("Fame_Pct", "Uniqueness_Pct"),
    title = "Distinctive Brand Assets \u2014 Fame \u00d7 Uniqueness")
}
