# ==============================================================================
# BRAND MODULE - BRANDED REACH (ROMANIUK)
# ==============================================================================
# Phase 1 skeleton. Computes the three Romaniuk metrics per ad —
#   reach %             (saw the ad)
#   branded reach %     (saw + correctly attributed brand)
#   branding %          (of those who saw, % correctly attributed)
# — plus a misattribution table and a media-channel mix per ad.
#
# Required survey-structure inputs (already present in modules/brand/examples/9cat):
#   - MarketingReach sheet: AssetCode, AssetLabel, ImagePath, Brand, Category,
#       SeenQuestionCode, BrandQuestionCode, MediaQuestionCode
#   - ReachMedia sheet:     MediaCode, MediaLabel, DisplayOrder
#   - reach_seen_scale OptionMap: 1 = recognised, 2 = not recognised
#   - reach.seen.{ad}, reach.brand.{ad}, reach.media.{ad} QuestionMap rows
#     (Variable_Type for reach.brand is Single_Response — the cell value is
#     a brand code from the category Brands list, "DK", or "OTHER".)
#
# Helpers live in 10a/10b/10c; 10d shapes the result for the HTML panel.
#
# VERSION: 1.0
# ==============================================================================

BRAND_BRANDED_REACH_VERSION <- "1.0"


#' Run branded-reach analysis for one category
#'
#' @param data Data frame. Already filtered to focal-category respondents
#'   (the per-category orchestrator in 00_main.R does this filter upstream).
#' @param asset_list Data frame from the MarketingReach sheet. Required
#'   columns: AssetCode, Brand, Category, SeenQuestionCode, BrandQuestionCode,
#'   MediaQuestionCode. Optional: ImagePath, AssetLabel.
#' @param brand_list Data frame of category brands (BrandCode, BrandLabel).
#' @param media_list Data frame of media channels (MediaCode, MediaLabel,
#'   optional DisplayOrder).
#' @param weights Numeric vector or NULL. Length must equal nrow(data).
#' @param cat_code Character or NULL. Category code; ALL-scoped ads run for
#'   every category, category-coded ads only run for their matching category.
#' @param focal_brand Character. Focal brand code (passed through to result
#'   meta, useful for HTML render).
#' @param seen_recognised_value Integer. Cell value indicating "Yes, seen".
#'   Default 1L (matches the reach_seen_scale OptionMap shipped with 9cat).
#'
#' @return List with status, ads (per-ad metrics), misattribution (named
#'   list of data frames keyed by AssetCode), media_mix (same keying), and
#'   meta. Returns a TRS refusal when essential inputs are missing.
#'
#' @examples
#' \dontrun{
#'   res <- run_branded_reach(
#'     data        = cat_data,
#'     asset_list  = structure$marketing_reach,
#'     brand_list  = cat_brands,
#'     media_list  = structure$reach_media,
#'     focal_brand = config$focal_brand,
#'     cat_code    = "DSS"
#'   )
#'   if (res$status == "PASS") str(res$ads, max.level = 2)
#' }
#'
#' @export
run_branded_reach <- function(data, asset_list, brand_list, media_list,
                               weights = NULL, cat_code = NULL,
                               focal_brand = NULL,
                               seen_recognised_value = 1L) {

  # Guard: data
  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) {
    return(.br_refuse("DATA_MISSING",
                       "Branded reach: data is empty or not a data frame",
                       "Pass the category-filtered survey data frame"))
  }

  # Guard: asset list — if missing/empty, skip silently with PASS empty
  if (is.null(asset_list) || !is.data.frame(asset_list) ||
      nrow(asset_list) == 0) {
    return(list(
      status = "PASS",
      ads = list(), misattribution = list(), media_mix = list(),
      meta = list(n_respondents = nrow(data), n_assets = 0L,
                   cat_code = cat_code, focal_brand = focal_brand,
                   weighted = !is.null(weights),
                   note = "No MarketingReach assets defined")
    ))
  }

  # Step 1: per-ad reach metrics
  metrics <- compute_br_reach_metrics(
    data = data, asset_list = asset_list,
    weights = weights, cat_code = cat_code,
    seen_recognised_value = seen_recognised_value
  )
  if (identical(metrics$status, "REFUSED")) return(metrics)

  # Step 2: per-ad misattribution
  misattr <- compute_br_misattribution(
    data = data, asset_list = asset_list, brand_list = brand_list,
    weights = weights, cat_code = cat_code,
    seen_recognised_value = seen_recognised_value
  )
  if (identical(misattr$status, "REFUSED")) {
    # Misattribution refusal is non-fatal — keep metrics + media mix
    misattr <- list(status = "PARTIAL", tables = list(),
                    message = misattr$message)
  }

  # Step 3: per-ad media mix
  mediamx <- compute_br_media_mix(
    data = data, asset_list = asset_list, media_list = media_list,
    weights = weights, cat_code = cat_code,
    seen_recognised_value = seen_recognised_value
  )
  if (identical(mediamx$status, "REFUSED")) {
    mediamx <- list(status = "PARTIAL", tables = list(),
                    message = mediamx$message)
  }

  list(
    status = "PASS",
    ads = metrics$ads,
    misattribution = misattr$tables %||% list(),
    media_mix      = mediamx$tables %||% list(),
    meta = list(
      n_respondents = nrow(data),
      n_assets      = length(metrics$ads),
      cat_code      = cat_code,
      focal_brand   = focal_brand,
      weighted      = !is.null(weights)
    )
  )
}


# ==============================================================================
# Internal: TRS refusal helper (mirrors brand_refuse but local to this engine
# so it can be sourced in any order)
# ==============================================================================

.br_refuse <- function(code, problem, how_to_fix) {
  res <- list(
    status = "REFUSED",
    code = code,
    message = problem,
    how_to_fix = how_to_fix
  )
  cat(sprintf("\n[BRANDED REACH] %s: %s\n  Fix: %s\n", code, problem, how_to_fix))
  res
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Branded reach engine loaded (v%s)",
                  BRAND_BRANDED_REACH_VERSION))
}
