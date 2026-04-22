# ==============================================================================
# BRAND MODULE - PORTFOLIO OVERVIEW DATA BUILDER
# ==============================================================================
# Computes the focal-brand-centred overview payload used by the Portfolio
# Overview subtab.  Unlike the footprint matrix (§4.1, which is scoped to
# categories with deep-dive bases), the overview spans EVERY category in the
# study — deep-dive AND awareness-only — so the focal brand's strength and
# weakness can be read across the full portfolio.
#
# Two entry points:
#   compute_portfolio_overview_data()
#     Raw-data-powered. Called once by run_brand() and stashed into
#     results$portfolio_overview. Computes per-category usage, per-brand
#     awareness, and (for deep-dive categories) penetration / SCR / vol /
#     frequency enrichment.
#
#   build_portfolio_overview()
#     Presentation wrapper. Reads the pre-computed payload from results
#     and returns it (with refusal shape on failure). Used by the HTML panel.
#
# VERSION: 2.0 (raw-data driven)
# ==============================================================================

PORTFOLIO_OVERVIEW_VERSION <- "2.0"

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a


# ==============================================================================
# LAYER A — RAW-DATA COMPUTATION (called by run_brand)
# ==============================================================================

#' Compute the Portfolio Overview payload from raw data
#'
#' Spans every category in \code{categories} (deep-dive and awareness-only)
#' for every brand mapped to the category. For deep-dive categories, looks
#' up per-brand penetration / SCR / vol share / freq from the corresponding
#' category result (\code{category_results[[Category]]}).
#'
#' Pure w.r.t. the data frame (no I/O, no global writes). Depends on helpers
#' from 09_portfolio.R (\code{build_portfolio_base}) and 09a_portfolio_footprint.R
#' (\code{.compute_category_awareness}).
#'
#' @param data Data frame. Full survey data.
#' @param categories Data frame. Categories sheet from loaded brand config.
#' @param structure List. Loaded survey structure.
#' @param config List. Loaded brand config.
#' @param weights Numeric or NULL. Survey weights.
#' @param category_results List or NULL. run_brand()'s
#'   \code{results$categories}; supplies brand_volume / repertoire for
#'   deep-dive enrichment. If NULL, deep-dive blocks are omitted.
#'
#' @return List: \code{status}, \code{focal_brand}, \code{brands} (data.frame),
#'   \code{categories} (named list of per-category records). See file header.
#' @export
compute_portfolio_overview_data <- function(data, categories, structure, config,
                                             weights = NULL,
                                             category_results = NULL) {
  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) {
    return(.po_refuse("DATA_OVERVIEW_NO_DATA",
                      "data must be a non-empty data frame",
                      "Pass the full survey data to compute_portfolio_overview_data()."))
  }
  if (is.null(categories) || !is.data.frame(categories) ||
      nrow(categories) == 0) {
    return(.po_refuse("DATA_OVERVIEW_NO_CATEGORIES",
                      "categories must be a non-empty data frame",
                      "Confirm config$categories is populated."))
  }

  focal     <- config$focal_brand         %||% ""
  timeframe <- config$portfolio_timeframe %||% "3m"
  n_total   <- nrow(data)

  cats_list <- list()
  for (i in seq_len(nrow(categories))) {
    rec <- .po_build_category_record(
      cat_name_in_cfg = as.character(categories$Category[i]),
      analysis_depth  = .po_depth_from_cfg(categories, i),
      data            = data,
      structure       = structure,
      timeframe       = timeframe,
      weights         = weights,
      n_total         = n_total,
      category_results = category_results
    )
    if (!is.null(rec)) cats_list[[rec$cat_code]] <- rec
  }

  if (length(cats_list) == 0) {
    return(.po_refuse("DATA_OVERVIEW_NO_COVERAGE",
                      "No category awareness could be computed.",
                      "Confirm BRANDAWARE_*_* columns exist and that category codes map to structure$questionmap."))
  }

  brands_df <- .po_build_brand_list(cats_list, focal)

  list(
    status      = "PASS",
    focal_brand = focal,
    brands      = brands_df,
    categories  = cats_list
  )
}


# ==============================================================================
# LAYER B — PRESENTATION WRAPPER (called by HTML panel)
# ==============================================================================

#' Return the pre-computed Portfolio Overview payload for the HTML panel
#'
#' Reads from \code{results$portfolio_overview} or \code{results$results$portfolio_overview}.
#' Fails loudly via TRS refusal if the payload is missing.
#'
#' @param results List. run_brand() output.
#' @param config List. Loaded brand config.
#' @return List with shape described in \code{compute_portfolio_overview_data()}.
#' @export
build_portfolio_overview <- function(results, config) {
  if (is.null(results) || !is.list(results)) {
    return(.po_refuse("DATA_OVERVIEW_NO_RESULTS",
                      "results must be a non-null list",
                      "Pass the full run_brand() result object."))
  }
  payload <- results$results$portfolio_overview %||% results$portfolio_overview
  if (is.null(payload) || length(payload$categories) == 0) {
    return(.po_refuse("DATA_OVERVIEW_NOT_COMPUTED",
                      "results$portfolio_overview is missing or empty.",
                      "Ensure run_brand() called compute_portfolio_overview_data() at step 5b."))
  }
  payload
}


# ==============================================================================
# PRIVATE — per-category record assembly
# ==============================================================================

.po_depth_from_cfg <- function(categories, i) {
  if ("Analysis_Depth" %in% names(categories)) {
    tolower(as.character(categories$Analysis_Depth[i]))
  } else "awareness_only"
}

.po_build_category_record <- function(cat_name_in_cfg, analysis_depth,
                                       data, structure, timeframe, weights,
                                       n_total, category_results) {

  cat_brands <- tryCatch(get_brands_for_category(structure, cat_name_in_cfg),
                         error = function(e) data.frame(BrandCode = character(0)))
  if (nrow(cat_brands) == 0) return(NULL)

  cat_code <- tryCatch(
    .po_detect_cat_code(structure$questionmap, cat_brands, data),
    error = function(e) NULL
  )
  if (is.null(cat_code) || !nzchar(cat_code)) return(NULL)

  base <- build_portfolio_base(data, cat_code, timeframe, weights)
  if (!is.null(base$status) && identical(base$status, "REFUSED")) return(NULL)

  brand_codes <- as.character(cat_brands$BrandCode)
  brand_names <- .po_brand_names(cat_brands, brand_codes)

  awareness <- .compute_category_awareness(data, cat_code, brand_codes,
                                            base$idx, weights)
  awareness_list <- stats::setNames(
    as.list(ifelse(is.finite(awareness), as.numeric(awareness), NA_real_)),
    brand_codes
  )

  cat_usage_pct <- if (n_total > 0) base$n_uw / n_total * 100 else NA_real_

  deep_dive <- NULL
  if (identical(analysis_depth, "full") && !is.null(category_results)) {
    cat_rec <- category_results[[cat_name_in_cfg]]
    deep_dive <- .po_deep_dive_block(cat_rec, brand_codes)
  }

  list(
    cat_code        = cat_code,
    cat_name        = cat_name_in_cfg,
    analysis_depth  = analysis_depth %||% "awareness_only",
    total_n_uw      = as.integer(n_total),
    n_buyers_uw     = as.integer(base$n_uw),
    n_buyers_w      = as.numeric(base$n_w),
    cat_usage_pct   = cat_usage_pct,
    brand_codes     = brand_codes,
    brand_names     = brand_names,
    awareness_pct   = awareness_list,
    deep_dive       = deep_dive
  )
}


# ==============================================================================
# PRIVATE — deep-dive enrichment
# ==============================================================================

.po_deep_dive_block <- function(cat_rec, brand_codes) {
  if (is.null(cat_rec)) return(NULL)
  brand_vol <- cat_rec$brand_volume
  rep_res   <- cat_rec$repertoire
  pen_mat   <- if (!is.null(brand_vol)) brand_vol$pen_mat else NULL
  x_mat     <- if (!is.null(brand_vol)) brand_vol$x_mat   else NULL
  if (is.null(pen_mat) || is.null(x_mat)) return(NULL)

  n_resp <- nrow(pen_mat)
  cat_total_volume <- sum(x_mat, na.rm = TRUE)
  sor_df <- if (!is.null(rep_res) && !is.null(rep_res$share_of_requirements))
    rep_res$share_of_requirements else NULL

  per_brand <- lapply(brand_codes, function(bc) {
    .po_brand_deep_dive(bc, pen_mat, x_mat, n_resp, cat_total_volume, sor_df)
  })
  names(per_brand) <- brand_codes
  per_brand
}

.po_brand_deep_dive <- function(brand_code, pen_mat, x_mat, n_resp,
                                 cat_total_volume, sor_df) {
  empty <- list(penetration_pct = NA_real_, scr_pct = NA_real_,
                freq_mean = NA_real_, vol_share_pct = NA_real_,
                buyers_n = 0L)
  if (!brand_code %in% colnames(pen_mat)) return(empty)

  pen_col <- pen_mat[, brand_code]
  vol_col <- x_mat[,  brand_code]
  buyers  <- sum(pen_col == 1L, na.rm = TRUE)
  pen_pct <- if (n_resp > 0) buyers / n_resp * 100 else NA_real_
  freq    <- if (buyers > 0) mean(vol_col[pen_col == 1L], na.rm = TRUE) else NA_real_
  vol     <- if (cat_total_volume > 0)
    sum(vol_col, na.rm = TRUE) / cat_total_volume * 100 else NA_real_

  scr_pct <- NA_real_
  if (!is.null(sor_df) && "BrandCode" %in% names(sor_df) &&
      "SoR_Pct" %in% names(sor_df)) {
    hit <- sor_df$SoR_Pct[sor_df$BrandCode == brand_code]
    if (length(hit) == 1L && is.finite(hit)) scr_pct <- as.numeric(hit)
  }

  list(
    penetration_pct = pen_pct,
    scr_pct         = scr_pct,
    freq_mean       = if (is.finite(freq)) freq else NA_real_,
    vol_share_pct   = vol,
    buyers_n        = as.integer(buyers)
  )
}


# ==============================================================================
# PRIVATE — brand list + names
# ==============================================================================

.po_brand_names <- function(cat_brands, brand_codes) {
  default <- stats::setNames(as.list(brand_codes), brand_codes)
  if (!"BrandName" %in% names(cat_brands)) return(default)
  lookup <- stats::setNames(as.character(cat_brands$BrandName),
                             as.character(cat_brands$BrandCode))
  stats::setNames(lapply(brand_codes, function(bc) {
    v <- lookup[[bc]]
    if (is.null(v) || !nzchar(v) || is.na(v)) bc else v
  }), brand_codes)
}

.po_build_brand_list <- function(cats_list, focal) {
  all_codes <- unique(unlist(lapply(cats_list, function(c) c$brand_codes),
                              use.names = FALSE))
  if (length(all_codes) == 0) {
    return(data.frame(brand_code = character(0), brand_name = character(0),
                       n_categories_present = integer(0),
                       stringsAsFactors = FALSE))
  }

  presence <- vapply(all_codes, function(bc) {
    sum(vapply(cats_list, function(c) {
      v <- c$awareness_pct[[bc]]
      isTRUE(is.finite(v) && v > 0)
    }, logical(1)))
  }, integer(1))

  name_map <- stats::setNames(as.list(all_codes), all_codes)
  for (c in cats_list) {
    for (bc in c$brand_codes) {
      nm <- c$brand_names[[bc]]
      if (!is.null(nm) && identical(name_map[[bc]], bc) && nzchar(nm))
        name_map[[bc]] <- nm
    }
  }

  df <- data.frame(
    brand_code           = all_codes,
    brand_name           = vapply(all_codes, function(bc) name_map[[bc]], character(1)),
    n_categories_present = as.integer(presence),
    stringsAsFactors     = FALSE
  )

  is_focal   <- df$brand_code == focal
  focal_row  <- df[is_focal, , drop = FALSE]
  others     <- df[!is_focal, , drop = FALSE]
  others     <- others[order(-others$n_categories_present,
                              others$brand_name), , drop = FALSE]
  rbind(focal_row, others)
}


# ==============================================================================
# PRIVATE — category-code detection (funnel + cross_cat awareness roles)
# ==============================================================================

# Like .detect_category_code() in 00_main.R but (a) recognises
# `cross_cat.awareness.{CC}` rows so awareness-only categories resolve, and
# (b) picks the BEST match rather than the first match above threshold. The
# best-match rule matters when focal/crossover brands appear in multiple
# categories' BRANDAWARE_* columns — a first-match rule would bind the wrong
# category code and cause collisions in cats_list.
.po_detect_cat_code <- function(qmap, cat_brands, data) {
  if (is.null(qmap) || nrow(qmap) == 0) return(NULL)
  if (is.null(cat_brands) || nrow(cat_brands) == 0) return(NULL)

  roles  <- trimws(as.character(qmap$Role))
  pat    <- "^(funnel|cross_cat)\\.awareness\\.[^.]+$"
  aw_idx <- which(grepl(pat, roles))
  if (length(aw_idx) == 0) return(NULL)

  threshold <- max(1L, floor(nrow(cat_brands) * 0.5))
  best_n    <- 0L
  best_code <- NULL
  for (i in aw_idx) {
    cc <- trimws(as.character(qmap$ClientCode[i]))
    if (is.na(cc) || cc == "") next
    expected <- paste0(cc, "_", cat_brands$BrandCode)
    n_found  <- sum(expected %in% names(data))
    if (n_found >= threshold && n_found > best_n) {
      best_n <- n_found
      parts  <- strsplit(roles[i], "\\.")[[1]]
      best_code <- parts[length(parts)]
    }
  }
  best_code
}


# ==============================================================================
# PRIVATE — refusal helper
# ==============================================================================

.po_refuse <- function(code, message, how_to_fix) {
  list(
    status      = "REFUSED",
    code        = code,
    message     = message,
    how_to_fix  = how_to_fix,
    focal_brand = "",
    brands      = data.frame(brand_code = character(0), brand_name = character(0),
                              n_categories_present = integer(0),
                              stringsAsFactors = FALSE),
    categories  = list()
  )
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Portfolio Overview data builder loaded (v%s)",
                  PORTFOLIO_OVERVIEW_VERSION))
}
