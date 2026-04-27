# ==============================================================================
# BRAND MODULE - BRANDED REACH: MISATTRIBUTION MATRIX
# ==============================================================================
# For each ad, builds a credit-stealing table: of respondents who said they
# saw the ad, what proportion attributed it to each brand in the category
# (plus DK and OTHER buckets).
#
# This is the diagnostic that tells you whether competitors are getting
# credit for your ads — Romaniuk's "branding %" decomposed by who got
# the credit when not the focal.
#
# VERSION: 1.0
# ==============================================================================

BRAND_BRANDED_REACH_MISATTRIBUTION_VERSION <- "1.0"


#' Build per-ad misattribution table
#'
#' For each ad, returns a data frame of brand attribution shares among the
#' subset of respondents who said they saw the ad.
#'
#' @param data Data frame already filtered to the category respondents.
#' @param asset_list Data frame from the MarketingReach sheet (see
#'   compute_br_reach_metrics for required columns).
#' @param brand_list Data frame of brands for the category (BrandCode,
#'   BrandLabel). The misattribution table contains one row per brand in this
#'   list, plus a DK row and an OTHER row, so every category brand is named
#'   even when zero respondents picked it.
#' @param weights Numeric vector or NULL.
#' @param cat_code Character or NULL. Same scope filter as
#'   compute_br_reach_metrics.
#' @param seen_recognised_value Integer. Default 1L (matches reach_seen_scale).
#'
#' @return List with status and (when PASS) \code{tables} — a named list
#'   keyed by AssetCode. Each entry is a data frame with columns:
#'   BrandCode, BrandLabel, n, pct_of_seen, is_correct.
#'
#' @export
compute_br_misattribution <- function(data, asset_list, brand_list,
                                       weights = NULL, cat_code = NULL,
                                       seen_recognised_value = 1L) {

  if (is.null(asset_list) || nrow(asset_list) == 0) {
    return(list(status = "PASS", tables = list()))
  }
  if (is.null(brand_list) || !is.data.frame(brand_list) ||
      nrow(brand_list) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_MISSING",
      message = "Branded reach misattribution: brand_list is empty",
      how_to_fix = "Pass the category brand list (BrandCode, BrandLabel)"
    ))
  }

  w <- .br_normalise_weights(weights, nrow(data))

  cat_filter <- if (is.null(cat_code) || !nzchar(cat_code)) {
    rep(TRUE, nrow(asset_list))
  } else {
    asset_list$Category == "ALL" | asset_list$Category == cat_code
  }
  ads_in_scope <- asset_list[cat_filter, , drop = FALSE]

  if (nrow(ads_in_scope) == 0) {
    return(list(status = "PASS", tables = list()))
  }

  brand_codes  <- as.character(brand_list$BrandCode)
  brand_labels <- if ("BrandLabel" %in% names(brand_list))
    as.character(brand_list$BrandLabel) else brand_codes
  # Append two non-brand buckets for unrecognised + other answers
  all_codes  <- c(brand_codes, "DK", "OTHER")
  all_labels <- c(brand_labels, "Don't know", "Other / wrong brand")

  tables <- list()
  for (i in seq_len(nrow(ads_in_scope))) {
    row       <- ads_in_scope[i, , drop = FALSE]
    asset_id  <- as.character(row$AssetCode)
    seen_col  <- as.character(row$SeenQuestionCode)
    brand_col <- as.character(row$BrandQuestionCode)
    correct   <- as.character(row$Brand)

    if (!seen_col %in% names(data) || !brand_col %in% names(data)) next

    seen_mask <- !is.na(data[[seen_col]]) &
                  data[[seen_col]] == seen_recognised_value
    n_seen    <- sum(w[seen_mask])

    pick_codes <- as.character(data[[brand_col]])
    pick_codes[!seen_mask] <- NA_character_

    counts <- vapply(all_codes, function(bc) {
      sum(w[seen_mask & !is.na(pick_codes) & pick_codes == bc])
    }, numeric(1))

    df <- data.frame(
      BrandCode   = all_codes,
      BrandLabel  = all_labels,
      n           = counts,
      pct_of_seen = if (n_seen > 0) counts / n_seen else rep(NA_real_, length(all_codes)),
      is_correct  = all_codes == correct,
      stringsAsFactors = FALSE
    )
    # Sort: focal first, then descending share, with DK/OTHER pinned to bottom
    df$.sort <- ifelse(df$is_correct, 0,
                ifelse(df$BrandCode %in% c("DK", "OTHER"), 2, 1))
    df <- df[order(df$.sort, -df$pct_of_seen), , drop = FALSE]
    df$.sort <- NULL
    rownames(df) <- NULL

    tables[[asset_id]] <- df
  }

  list(status = "PASS", tables = tables)
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Branded reach misattribution loaded (v%s)",
                  BRAND_BRANDED_REACH_MISATTRIBUTION_VERSION))
}
