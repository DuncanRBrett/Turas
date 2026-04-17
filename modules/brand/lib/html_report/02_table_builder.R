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
    title = sprintf("Repertoire Size Distribution (mean: %.1f brands)", rep$mean_repertoire)))
  parts <- c(parts, build_br_table(
    rep$sole_loyalty, "BrandCode", focal_brand, pct_cols = "SoleLoyalty_Pct",
    title = "Sole Loyalty"))
  if (!is.null(rep$brand_overlap) && nrow(rep$brand_overlap) > 0) {
    parts <- c(parts, build_br_table(
      rep$brand_overlap, NULL, NULL, pct_cols = "Overlap_Pct",
      title = sprintf("Brand Overlap with %s Buyers", focal_brand %||% "Focal")))
  }
  paste(parts, collapse = "\n")
}


#' Build all tables for Drivers & Barriers
#' @keywords internal
build_db_tables <- function(db, focal_brand) {
  if (is.null(db) || identical(db$status, "REFUSED")) return("")

  parts <- character(0)
  if (!is.null(db$importance)) {
    cols <- intersect(c("Code", "Label", "Buyer_Pct", "NonBuyer_Pct",
                        "Differential", "Importance_Rank"), names(db$importance))
    parts <- c(parts, build_br_table(
      db$importance[, cols, drop = FALSE], NULL, NULL,
      pct_cols = c("Buyer_Pct", "NonBuyer_Pct", "Differential"),
      title = "Derived Importance (buyer vs non-buyer differential)"))
  }
  if (!is.null(db$ixp_quadrants)) {
    cols <- intersect(c("Code", "Label", "Differential", "Focal_Linkage_Pct", "Quadrant"),
                      names(db$ixp_quadrants))
    parts <- c(parts, build_br_table(
      db$ixp_quadrants[, cols, drop = FALSE], NULL, NULL,
      pct_cols = c("Differential", "Focal_Linkage_Pct"),
      title = "Importance \u00d7 Performance Quadrants"))
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
