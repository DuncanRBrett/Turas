# ==============================================================================
# BRAND MODULE - BRANDED REACH: MEDIA MIX
# ==============================================================================
# For each ad, computes the share of respondents-who-saw-it that selected
# each media channel for "Where did you see this advertising?" (Q015).
#
# The Q015 column is multi-mention: cell values are comma-separated media
# codes (e.g. "TV,SOCIAL"), matching the ReachMedia sheet's MediaCode list.
#
# VERSION: 1.0
# ==============================================================================

BRAND_BRANDED_REACH_MEDIA_VERSION <- "1.0"


#' Build per-ad media mix table
#'
#' @param data Data frame for the category respondents.
#' @param asset_list Data frame from MarketingReach sheet (must include
#'   MediaQuestionCode column).
#' @param media_list Data frame from ReachMedia sheet (MediaCode, MediaLabel,
#'   optional DisplayOrder).
#' @param weights Numeric vector or NULL.
#' @param cat_code Character or NULL.
#' @param seen_recognised_value Integer. Default 1L.
#'
#' @return List with status and (when PASS) \code{tables} — named list keyed
#'   by AssetCode. Each entry is a data frame with columns: MediaCode,
#'   MediaLabel, n, pct_of_seen.
#'
#' @export
compute_br_media_mix <- function(data, asset_list, media_list,
                                  weights = NULL, cat_code = NULL,
                                  seen_recognised_value = 1L) {

  if (is.null(asset_list) || nrow(asset_list) == 0) {
    return(list(status = "PASS", tables = list()))
  }
  if (is.null(media_list) || !is.data.frame(media_list) ||
      nrow(media_list) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_MISSING",
      message = "Branded reach media mix: media_list is empty",
      how_to_fix = "Populate the ReachMedia sheet in Survey_Structure.xlsx"
    ))
  }
  if (!"MediaQuestionCode" %in% names(asset_list)) {
    return(list(
      status = "REFUSED",
      code = "DATA_MISSING",
      message = "MarketingReach sheet missing MediaQuestionCode column",
      how_to_fix = "Re-generate Survey_Structure.xlsx from the 9cat template"
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

  if ("DisplayOrder" %in% names(media_list)) {
    media_list <- media_list[order(media_list$DisplayOrder), , drop = FALSE]
  }
  media_codes  <- as.character(media_list$MediaCode)
  media_labels <- if ("MediaLabel" %in% names(media_list))
    as.character(media_list$MediaLabel) else media_codes

  tables <- list()
  for (i in seq_len(nrow(ads_in_scope))) {
    row       <- ads_in_scope[i, , drop = FALSE]
    asset_id  <- as.character(row$AssetCode)
    seen_col  <- as.character(row$SeenQuestionCode)
    media_col <- as.character(row$MediaQuestionCode)

    if (!seen_col %in% names(data) || !media_col %in% names(data)) next

    seen_mask <- !is.na(data[[seen_col]]) &
                  data[[seen_col]] == seen_recognised_value
    n_seen    <- sum(w[seen_mask])

    media_strings <- as.character(data[[media_col]])
    media_strings[!seen_mask] <- NA_character_

    counts <- vapply(media_codes, function(mc) {
      hit <- vapply(media_strings, function(s) {
        if (is.na(s) || !nzchar(s)) return(FALSE)
        mc %in% trimws(strsplit(s, ",", fixed = TRUE)[[1]])
      }, logical(1))
      sum(w[hit])
    }, numeric(1))

    df <- data.frame(
      MediaCode   = media_codes,
      MediaLabel  = media_labels,
      n           = counts,
      pct_of_seen = if (n_seen > 0) counts / n_seen else rep(NA_real_, length(media_codes)),
      stringsAsFactors = FALSE
    )
    rownames(df) <- NULL
    tables[[asset_id]] <- df
  }

  list(status = "PASS", tables = tables)
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Branded reach media mix loaded (v%s)",
                  BRAND_BRANDED_REACH_MEDIA_VERSION))
}
