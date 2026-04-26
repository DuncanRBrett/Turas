# ==============================================================================
# BRAND MODULE - PORTFOLIO CLUTTER QUADRANT (§4.3)
# ==============================================================================
# For each category, computes:
#   x_c = mean brands a buyer knows in the category (awareness set size)
#   y_c = focal brand's share of category awareness
# and classifies each category into one of four strategic quadrants.
#
# Denominator: build_portfolio_base() per §3.1 — never inline SQ1_/SQ2_.
# ==============================================================================


#' Compute clutter metrics for one category (pure, no side-effects)
#'
#' Returns the awareness set size mean (x) and focal share of awareness (y)
#' for a single category. Both are used to position the category dot on the
#' clutter quadrant scatter.
#'
#' @param data Data frame. Full survey data.
#' @param cat_code Character. Category code.
#' @param brand_codes Character vector. All brand codes in this category.
#' @param focal_brand Character. Focal brand code.
#' @param base_idx Logical vector. Qualifier flags from build_portfolio_base().
#' @param weights Numeric vector or NULL. Survey weights.
#'
#' @return List: awareness_set_size_mean, focal_pct, sum_brand_pcts.
#' @keywords internal
.compute_category_clutter_metrics <- function(data, cat_code, brand_codes,
                                               focal_brand, base_idx, weights) {
  w     <- if (!is.null(weights)) weights else rep(1.0, nrow(data))
  denom <- sum(w[base_idx], na.rm = TRUE)
  n_row <- nrow(data)

  # Awareness matrix: one column per brand, rows = all respondents
  aware_mat <- vapply(brand_codes, function(bc) {
    col <- paste0("BRANDAWARE_", cat_code, "_", bc)
    if (!col %in% names(data)) return(rep(0L, n_row))
    as.integer(!is.na(data[[col]]) & data[[col]] == 1L)
  }, integer(n_row))
  if (!is.matrix(aware_mat)) aware_mat <- matrix(aware_mat, ncol = length(brand_codes))

  set_size_per_resp <- rowSums(aware_mat)
  awareness_set_size_mean <- if (denom > 0) {
    sum(w[base_idx] * set_size_per_resp[base_idx], na.rm = TRUE) / denom
  } else NA_real_

  # Per-brand weighted awareness %
  brand_pcts <- vapply(seq_along(brand_codes), function(bi) {
    if (denom <= 0) return(0)
    sum(w[base_idx] * aware_mat[base_idx, bi], na.rm = TRUE) / denom * 100
  }, numeric(1))
  names(brand_pcts) <- brand_codes

  focal_pct    <- if (focal_brand %in% brand_codes) brand_pcts[[focal_brand]] else 0
  sum_brand    <- sum(brand_pcts, na.rm = TRUE)

  list(
    awareness_set_size_mean = awareness_set_size_mean,
    focal_pct               = focal_pct,
    sum_brand_pcts          = sum_brand,
    n_brands                = length(brand_codes)
  )
}


#' Compute portfolio clutter quadrant data
#'
#' Produces the per-category data for the clutter scatter plot (§4.3 of spec).
#' Each category is characterised by its awareness set size (how many brands
#' buyers know) and the focal brand's share of that awareness.
#'
#' Quadrant classification uses:
#' \itemize{
#'   \item High clutter: \code{awareness_set_size_mean > ref_x} (median across cats)
#'   \item Focal strong: \code{focal_share_of_aware > 1 / k_c} (fair share for cat)
#' }
#'
#' @param data Data frame. Full survey data.
#' @param categories Data frame. Categories sheet.
#' @param structure List. Loaded survey structure.
#' @param config List. Loaded brand config.
#' @param weights Numeric vector or NULL. Survey weights.
#'
#' @return List:
#'   \item{status}{"PASS"}
#'   \item{clutter_df}{Data frame: cat, awareness_set_size_mean,
#'     focal_share_of_aware, cat_penetration, fair_share, quadrant.}
#'   \item{ref_x}{Numeric. Median awareness set size (vertical reference line).}
#'   \item{ref_y}{Numeric. Median fair share (horizontal reference line).}
#'   \item{suppressed_cats}{Character. Category codes below min_base.}
#'
#' @export
compute_clutter_data <- function(data, categories, structure,
                                 config, weights = NULL) {
  focal_brand <- config$focal_brand %||% ""
  timeframe   <- config$portfolio_timeframe %||% "3m"
  min_base    <- config$portfolio_min_base  %||% 30L
  n_total     <- nrow(data)

  rows         <- list()
  per_cat_full <- list()  # focal-agnostic payload (set size, all brand pcts)
  cat_label_map<- list()
  suppressed   <- character(0)

  for (i in seq_len(nrow(categories))) {
    cat_name   <- categories$Category[i]
    cat_brands <- tryCatch(
      get_brands_for_category(structure, cat_name),
      error = function(e) data.frame(BrandCode = character(0))
    )
    if (nrow(cat_brands) == 0) next

    # Use the broader detector (cross_cat.awareness.<CC> too) so
    # awareness-only categories resolve a code instead of being
    # silently dropped — same fix as the footprint pipeline.
    detector <- if (exists(".po_detect_cat_code", mode = "function"))
                  .po_detect_cat_code else .detect_category_code
    cat_code <- if (!is.null(structure$questionmap) &&
                    nrow(structure$questionmap) > 0)
      detector(structure$questionmap, cat_brands, data) else NULL
    if (is.null(cat_code)) next

    base <- build_portfolio_base(data, cat_code, timeframe, weights)
    if (!is.null(base$status)) next

    if (base$n_uw < min_base) {
      suppressed <- c(suppressed, cat_code)
      next
    }

    brand_codes   <- as.character(cat_brands$BrandCode)
    brand_lbls    <- if ("BrandLabel" %in% names(cat_brands))
                       as.character(cat_brands$BrandLabel)
                     else if ("BrandName" %in% names(cat_brands))
                       as.character(cat_brands$BrandName)
                     else brand_codes
    names(brand_lbls) <- brand_codes

    metrics       <- .compute_category_clutter_metrics(
      data, cat_code, brand_codes, focal_brand, base$idx, weights)

    cat_pen       <- base$n_uw / n_total
    fair_share    <- if (metrics$n_brands > 0) 1 / metrics$n_brands else NA_real_
    focal_share   <- if (metrics$sum_brand_pcts > 0) {
      metrics$focal_pct / metrics$sum_brand_pcts
    } else 0

    # Per-brand awareness % across this category's buyers — needed for
    # the JS-side focal switcher (recompute focal_share without R).
    w     <- if (!is.null(weights)) weights else rep(1.0, n_total)
    denom <- sum(w[base$idx], na.rm = TRUE)
    brand_pcts <- vapply(brand_codes, function(bc) {
      col <- paste0("BRANDAWARE_", cat_code, "_", bc)
      if (!col %in% names(data) || denom <= 0) return(0)
      vals <- as.integer(!is.na(data[[col]]) & data[[col]] == 1L)
      sum(w[base$idx] * vals[base$idx], na.rm = TRUE) / denom * 100
    }, numeric(1))
    names(brand_pcts) <- brand_codes

    rows[[cat_code]] <- list(
      cat                    = cat_code,
      awareness_set_size_mean = metrics$awareness_set_size_mean,
      focal_share_of_aware   = focal_share,
      cat_penetration        = cat_pen,
      fair_share             = fair_share
    )
    per_cat_full[[cat_code]] <- list(
      cat_code        = cat_code,
      cat_label       = as.character(cat_name),
      set_size_mean   = metrics$awareness_set_size_mean,
      cat_penetration = cat_pen,
      n_brands        = metrics$n_brands,
      brand_pcts      = as.list(brand_pcts),
      brand_lbls      = as.list(brand_lbls)
    )
    cat_label_map[[cat_code]] <- as.character(cat_name)
  }

  if (length(rows) == 0) {
    return(list(
      status          = "PASS",
      clutter_df      = data.frame(),
      per_cat_full    = list(),
      ref_x           = NA_real_,
      ref_y           = NA_real_,
      suppressed_cats = suppressed
    ))
  }

  clutter_df <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))
  rownames(clutter_df) <- NULL

  ref_x <- median(clutter_df$awareness_set_size_mean, na.rm = TRUE)
  ref_y <- median(clutter_df$fair_share, na.rm = TRUE)

  clutter_df$quadrant <- vapply(seq_len(nrow(clutter_df)), function(i) {
    is_strong <- !is.na(clutter_df$focal_share_of_aware[i]) &&
                 !is.na(clutter_df$fair_share[i]) &&
                 clutter_df$focal_share_of_aware[i] > clutter_df$fair_share[i]
    is_high_clutter <- !is.na(clutter_df$awareness_set_size_mean[i]) &&
                       !is.na(ref_x) &&
                       clutter_df$awareness_set_size_mean[i] > ref_x
    if (is_strong && !is_high_clutter) return("Dominant")
    if (is_strong && is_high_clutter)  return("Contested")
    if (!is_strong && !is_high_clutter) return("Niche Opportunity")
    "Forgotten / Wrong Battle"
  }, character(1))

  list(
    status          = "PASS",
    clutter_df      = clutter_df,
    per_cat_full    = per_cat_full,
    ref_x           = ref_x,
    ref_y           = ref_y,
    suppressed_cats = suppressed
  )
}
