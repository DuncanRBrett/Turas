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


# ==============================================================================
# V2: SLOT-INDEXED CLUTTER QUADRANT
# ==============================================================================

#' Compute per-category clutter metrics from a 0/1 awareness matrix (v2)
#'
#' Pure helper. Given the brand x respondent awareness matrix, returns:
#' \code{awareness_set_size_mean} (weighted mean of brands known per
#' qualifier), \code{focal_pct} (weighted % of qualifiers aware of focal),
#' \code{sum_brand_pcts} (sum of per-brand awareness %), \code{n_brands},
#' and the per-brand pct vector (for the JS-side focal switcher).
#'
#' @param aware_mat Integer matrix \code{[nrow(data) x n_brands]}.
#' @param focal_brand Character. Focal brand code.
#' @param base_idx Logical vector. Qualifier mask.
#' @param weights Numeric vector or NULL.
#' @return List: \code{awareness_set_size_mean}, \code{focal_pct},
#'   \code{sum_brand_pcts}, \code{n_brands}, \code{brand_pcts}.
#' @keywords internal
.compute_clutter_metrics <- function(aware_mat, focal_brand, base_idx,
                                        weights) {
  brand_codes <- colnames(aware_mat) %||% character(0)
  w     <- if (!is.null(weights)) weights else rep(1.0, nrow(aware_mat))
  denom <- sum(w[base_idx], na.rm = TRUE)

  set_size_per_resp <- rowSums(aware_mat)
  set_size_mean <- if (denom > 0) {
    sum(w[base_idx] * set_size_per_resp[base_idx], na.rm = TRUE) / denom
  } else NA_real_

  brand_pcts <- if (length(brand_codes) > 0L) {
    vapply(brand_codes, function(bc) {
      if (denom <= 0) return(0)
      sum(w[base_idx] * aware_mat[base_idx, bc], na.rm = TRUE) / denom * 100
    }, numeric(1))
  } else {
    setNames(numeric(0), character(0))
  }

  focal_pct <- if (focal_brand %in% brand_codes) brand_pcts[[focal_brand]] else 0
  sum_brand <- sum(brand_pcts, na.rm = TRUE)

  list(
    awareness_set_size_mean = set_size_mean,
    focal_pct               = focal_pct,
    sum_brand_pcts          = sum_brand,
    n_brands                = length(brand_codes),
    brand_pcts              = brand_pcts
  )
}


#' Compute portfolio clutter quadrant data (v2 — slot-indexed)
#'
#' v2 alternative to \code{compute_clutter_data()} that uses the slot-indexed
#' data-access layer. Iterates \code{categories$CategoryCode} directly (no
#' detection); awareness comes from \code{.portfolio_aware_matrix()}.
#'
#' @param data Data frame.
#' @param role_map Named list from \code{build_brand_role_map()} or NULL.
#' @param categories Data frame. Must have \code{Category} + \code{CategoryCode}.
#' @param structure List from a Survey_Structure loader.
#' @param config List. Must carry \code{focal_brand},
#'   \code{portfolio_timeframe}, \code{portfolio_min_base}.
#' @param weights Numeric vector or NULL.
#' @return Same list shape as \code{compute_clutter_data()}.
#' @export
compute_clutter_data <- function(data, role_map, categories, structure,
                                     config, weights = NULL) {
  focal_brand <- config$focal_brand %||% ""
  timeframe   <- config$portfolio_timeframe %||% "3m"
  min_base    <- config$portfolio_min_base  %||% 30L
  n_total     <- nrow(data)

  if (!"CategoryCode" %in% names(categories)) {
    return(list(status = "REFUSED",
                code = "CFG_PORTFOLIO_NO_CATEGORY_CODE",
                message = "categories sheet must include a CategoryCode column for v2 portfolio analyses",
                how_to_fix = "Add CategoryCode column to Brand_Config Categories sheet"))
  }

  rows         <- list()
  per_cat_full <- list()
  cat_label_map<- list()
  suppressed   <- character(0)

  for (i in seq_len(nrow(categories))) {
    cat_name <- as.character(categories$Category[i])
    cat_code <- as.character(categories$CategoryCode[i])
    if (is.na(cat_code) || !nzchar(cat_code)) next

    cat_brands <- tryCatch(
      get_brands_for_category(structure, cat_name, cat_code = cat_code),
      error = function(e) data.frame(BrandCode = character(0))
    )
    if (nrow(cat_brands) == 0L) next

    base <- build_portfolio_base(data, cat_code, timeframe, weights)
    if (!is.null(base$status)) next
    if (base$n_uw == 0L) {
      suppressed <- c(suppressed, cat_code); next
    }
    if (base$n_uw < min_base) {
      suppressed <- c(suppressed, cat_code); next
    }

    brand_codes <- as.character(cat_brands$BrandCode)
    brand_lbls  <- if ("BrandLabel" %in% names(cat_brands))
                     as.character(cat_brands$BrandLabel)
                   else if ("BrandName" %in% names(cat_brands))
                     as.character(cat_brands$BrandName)
                   else brand_codes
    names(brand_lbls) <- brand_codes

    aware_mat <- .portfolio_aware_matrix(data, role_map, cat_code,
                                            brand_codes)
    metrics   <- .compute_clutter_metrics(aware_mat, focal_brand,
                                             base$idx, weights)

    cat_pen     <- base$n_uw / n_total
    fair_share  <- if (metrics$n_brands > 0L) 1 / metrics$n_brands else NA_real_
    focal_share <- if (metrics$sum_brand_pcts > 0) {
      metrics$focal_pct / metrics$sum_brand_pcts
    } else 0

    rows[[cat_code]] <- list(
      cat                     = cat_code,
      awareness_set_size_mean = metrics$awareness_set_size_mean,
      focal_share_of_aware    = focal_share,
      cat_penetration         = cat_pen,
      fair_share              = fair_share
    )
    per_cat_full[[cat_code]] <- list(
      cat_code        = cat_code,
      cat_label       = cat_name,
      set_size_mean   = metrics$awareness_set_size_mean,
      cat_penetration = cat_pen,
      n_brands        = metrics$n_brands,
      brand_pcts      = as.list(metrics$brand_pcts),
      brand_lbls      = as.list(brand_lbls)
    )
    cat_label_map[[cat_code]] <- cat_name
  }

  if (length(rows) == 0L) {
    return(list(
      status          = "PASS",
      clutter_df      = data.frame(),
      per_cat_full    = list(),
      ref_x           = NA_real_,
      ref_y           = NA_real_,
      suppressed_cats = suppressed
    ))
  }

  clutter_df <- do.call(rbind, lapply(rows, as.data.frame,
                                       stringsAsFactors = FALSE))
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
