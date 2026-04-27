# ==============================================================================
# BRAND MODULE - BRANDED REACH: PER-AD REACH METRICS
# ==============================================================================
# Computes per-ad recognition and branded-reach metrics from respondent-level
# Q013 (seen) + Q014 (single-select brand attribution) data.
#
# Romaniuk metrics:
#   reach_pct          = n_seen / n_eligible
#   branded_reach_pct  = n_correct_attribution / n_eligible
#   branding_pct       = n_correct_attribution / n_seen   (efficiency)
#
# All computations are weighted-aware: when `weights` is supplied the counts
# become weighted sums; the percentages divide weighted-by-weighted.
#
# This file is intentionally narrow: it owns the per-ad metric calc only.
# Misattribution details live in 10b; media mix lives in 10c.
#
# VERSION: 1.0
# ==============================================================================

BRAND_BRANDED_REACH_METRICS_VERSION <- "1.0"


#' Compute per-ad reach + branded-reach metrics
#'
#' For each ad in \code{asset_list}, determines the eligible respondent set
#' (filtered to the ad's category when not "ALL"), counts who said they saw
#' the ad, and counts correct vs incorrect brand attribution.
#'
#' @param data Data frame. Survey data already filtered to the focal-category
#'   respondents (the per-category orchestration loop does this filter
#'   upstream, see 00_main.R).
#' @param asset_list Data frame from the MarketingReach sheet. Required cols:
#'   AssetCode, AssetLabel, Brand, Category, SeenQuestionCode,
#'   BrandQuestionCode, MediaQuestionCode. Optional: ImagePath.
#' @param weights Numeric vector or NULL. Must equal nrow(data) when supplied.
#' @param cat_code Character or NULL. Category code (e.g. "DSS") for the
#'   current per-category run. Ads with Category = "ALL" are always included;
#'   ads with a category-specific code are included only when it matches
#'   \code{cat_code}.
#' @param seen_recognised_value Integer. The OptionMap-coded value for
#'   "Yes, I have seen this advertising" (default 1L; matches reach_seen_scale
#'   row 1 in modules/brand/examples/9cat).
#'
#' @return List with status and (when PASS) an \code{ads} field — one row per
#'   ad shown to this category. Each row carries: asset_code, asset_label,
#'   image_path, correct_brand, n_eligible, n_seen, n_correct, reach_pct,
#'   branded_reach_pct, branding_pct.
#'
#'   Returns a TRS refusal when the asset list is empty or required columns
#'   are missing.
#'
#' @export
compute_br_reach_metrics <- function(data, asset_list, weights = NULL,
                                      cat_code = NULL,
                                      seen_recognised_value = 1L) {

  if (is.null(asset_list) || !is.data.frame(asset_list) ||
      nrow(asset_list) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_MISSING",
      message = "Branded reach: asset_list is empty",
      how_to_fix = "Populate the MarketingReach sheet in Survey_Structure.xlsx"
    ))
  }

  required_cols <- c("AssetCode", "Brand", "Category",
                     "SeenQuestionCode", "BrandQuestionCode")
  missing_cols  <- setdiff(required_cols, names(asset_list))
  if (length(missing_cols) > 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_MISSING",
      message = sprintf("MarketingReach sheet missing required columns: %s",
                        paste(missing_cols, collapse = ", ")),
      how_to_fix = "Re-generate Survey_Structure.xlsx from the 9cat template"
    ))
  }

  w <- .br_normalise_weights(weights, nrow(data))

  # Filter the asset list to ads shown in this category (ALL or matching code)
  cat_filter <- if (is.null(cat_code) || !nzchar(cat_code)) {
    rep(TRUE, nrow(asset_list))
  } else {
    asset_list$Category == "ALL" | asset_list$Category == cat_code
  }
  ads_in_scope <- asset_list[cat_filter, , drop = FALSE]

  if (nrow(ads_in_scope) == 0) {
    return(list(
      status = "PASS",
      ads = list(),
      meta = list(n_respondents = nrow(data), n_assets = 0L,
                  cat_code = cat_code)
    ))
  }

  ads <- lapply(seq_len(nrow(ads_in_scope)), function(i) {
    row       <- ads_in_scope[i, , drop = FALSE]
    seen_col  <- as.character(row$SeenQuestionCode)
    brand_col <- as.character(row$BrandQuestionCode)
    correct   <- as.character(row$Brand)
    image     <- if ("ImagePath" %in% names(row))
      as.character(row$ImagePath) else NA_character_

    if (!seen_col %in% names(data) || !brand_col %in% names(data)) {
      return(list(
        asset_code = as.character(row$AssetCode),
        asset_label = as.character(row$AssetLabel %||% row$AssetCode),
        image_path = image,
        correct_brand = correct,
        category = as.character(row$Category),
        n_eligible = NA_integer_, n_seen = NA_integer_, n_correct = NA_integer_,
        reach_pct = NA_real_, branded_reach_pct = NA_real_,
        branding_pct = NA_real_,
        status = "REFUSED",
        message = sprintf("Data missing column %s or %s", seen_col, brand_col)
      ))
    }

    seen_vals  <- data[[seen_col]]
    brand_vals <- data[[brand_col]]

    # Eligibility: anyone with a non-NA seen response (the questionnaire
    # routes only the right respondents to each ad, so NA = "not shown").
    eligible <- !is.na(seen_vals)
    seen     <- eligible & seen_vals == seen_recognised_value
    correct_attr <- seen & !is.na(brand_vals) & trimws(as.character(brand_vals)) == correct

    n_eligible <- sum(w[eligible])
    n_seen     <- sum(w[seen])
    n_correct  <- sum(w[correct_attr])

    list(
      asset_code        = as.character(row$AssetCode),
      asset_label       = as.character(row$AssetLabel %||% row$AssetCode),
      image_path        = image,
      correct_brand     = correct,
      category          = as.character(row$Category),
      n_eligible        = n_eligible,
      n_seen            = n_seen,
      n_correct         = n_correct,
      reach_pct         = if (n_eligible > 0) n_seen / n_eligible else NA_real_,
      branded_reach_pct = if (n_eligible > 0) n_correct / n_eligible else NA_real_,
      branding_pct      = if (n_seen > 0)     n_correct / n_seen     else NA_real_,
      status            = "PASS"
    )
  })

  list(
    status = "PASS",
    ads = ads,
    meta = list(
      n_respondents = nrow(data),
      n_assets      = length(ads),
      cat_code      = cat_code,
      weighted      = !is.null(weights)
    )
  )
}


# ==============================================================================
# Internal: normalise weights to a numeric vector of length n
# ==============================================================================

.br_normalise_weights <- function(weights, n) {
  if (is.null(weights)) return(rep(1, n))
  if (length(weights) != n) {
    stop(sprintf("Branded reach: weights length (%d) != data rows (%d)",
                 length(weights), n))
  }
  w <- as.numeric(weights)
  w[is.na(w)] <- 0
  w
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Branded reach metrics loaded (v%s)",
                  BRAND_BRANDED_REACH_METRICS_VERSION))
}
