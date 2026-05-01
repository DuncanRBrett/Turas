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
# SIZE-EXCEPTION: overview record builder + brand-list assembler + deep-dive
# enrichment + cat-code detector form a coherent payload-building flow. During
# the IPK rebuild the file holds both v1 (column-per-brand) and v2
# (slot-indexed) variants of compute_portfolio_overview_data + the per-cat
# record helper. The legacy v1 entries are scheduled for deletion at rebuild
# cutover (planning doc §9 step 5), bringing the file back inside the
# 300-active-line default.
#
# VERSION: 2.0 (raw-data driven)
# ==============================================================================

PORTFOLIO_OVERVIEW_VERSION <- "2.0"

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a


# ==============================================================================
# LAYER A — RAW-DATA COMPUTATION (called by run_brand)
# ==============================================================================

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
  # The Survey_Structure template ships with `BrandLabel` (e.g. "Ina
  # Paarman's Kitchen") — the older / external schema variant uses
  # `BrandName`. Honour whichever is present so the focal dropdown,
  # deep-dive cards, and any other downstream consumer get human
  # display names instead of brand codes.
  name_col <- if ("BrandLabel" %in% names(cat_brands)) "BrandLabel"
              else if ("BrandName" %in% names(cat_brands)) "BrandName"
              else NULL
  if (is.null(name_col)) return(default)
  lookup <- stats::setNames(as.character(cat_brands[[name_col]]),
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


# ==============================================================================
# V2: SLOT-INDEXED OVERVIEW DATA
# ==============================================================================

#' Build a per-category overview record using the slot-indexed helper (v2)
#'
#' Replaces \code{.po_build_category_record()} for the v2 entry: cat_code
#' comes directly from \code{categories$CategoryCode}, awareness from
#' \code{.portfolio_aware_matrix()}, base from
#' \code{build_portfolio_base()}.
#'
#' @keywords internal
.po_build_category_record <- function(cat_name, cat_code, analysis_depth,
                                          data, role_map, structure,
                                          timeframe, weights, n_total,
                                          category_results) {
  if (is.null(cat_code) || !nzchar(cat_code)) return(NULL)

  cat_brands <- tryCatch(
    get_brands_for_category(structure, cat_name),
    error = function(e) data.frame(BrandCode = character(0))
  )
  if (nrow(cat_brands) == 0L) return(NULL)

  base <- build_portfolio_base(data, cat_code, timeframe, weights)
  if (!is.null(base$status)) return(NULL)
  # Skip categories with zero qualifiers — denominator would be 0 and
  # the panel renderer shows a "no respondents in this category yet"
  # placeholder downstream rather than an all-NA awareness card.
  if (base$n_uw == 0L) return(NULL)

  brand_codes  <- as.character(cat_brands$BrandCode)
  brand_names  <- .po_brand_names(cat_brands, brand_codes)

  aware_mat    <- .portfolio_aware_matrix(data, role_map, cat_code,
                                              brand_codes)
  awareness    <- .compute_brand_awareness_pct(aware_mat, base$idx,
                                                  weights)
  awareness_list <- stats::setNames(
    as.list(ifelse(is.finite(awareness), as.numeric(awareness), NA_real_)),
    brand_codes
  )

  cat_usage_pct <- if (n_total > 0L) base$n_uw / n_total * 100 else NA_real_

  deep_dive <- NULL
  if (identical(analysis_depth, "full") && !is.null(category_results)) {
    cat_rec <- category_results[[cat_name]]
    deep_dive <- .po_deep_dive_block(cat_rec, brand_codes)
  }

  list(
    cat_code        = cat_code,
    cat_name        = cat_name,
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


#' Compute the Portfolio Overview payload (v2 — slot-indexed)
#'
#' v2 alternative to \code{compute_portfolio_overview_data()}.  Uses
#' \code{categories$CategoryCode} for direct cat_code lookup (no detection)
#' and the slot-indexed data-access helpers for awareness reads.  Returns
#' the same shape as the legacy entry.
#'
#' @param data Data frame.
#' @param role_map Named list from \code{build_brand_role_map()} or NULL.
#' @param categories Data frame with \code{Category} + \code{CategoryCode}
#'   (and optional \code{Analysis_Depth}).
#' @param structure List from a Survey_Structure loader.
#' @param config List with \code{focal_brand} +
#'   \code{portfolio_timeframe}.
#' @param weights Numeric vector or NULL.
#' @param category_results List or NULL — passes through to deep-dive
#'   enrichment.
#' @return Same list shape as \code{compute_portfolio_overview_data()}.
#' @export
compute_portfolio_overview_data <- function(data, role_map, categories,
                                                structure, config,
                                                weights = NULL,
                                                category_results = NULL) {
  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0L) {
    return(.po_refuse("DATA_OVERVIEW_NO_DATA",
                      "data must be a non-empty data frame",
                      "Pass the full survey data to compute_portfolio_overview_data()."))
  }
  if (is.null(categories) || !is.data.frame(categories) ||
      nrow(categories) == 0L) {
    return(.po_refuse("DATA_OVERVIEW_NO_CATEGORIES",
                      "categories must be a non-empty data frame",
                      "Confirm config$categories is populated."))
  }
  if (!"CategoryCode" %in% names(categories)) {
    return(.po_refuse("CFG_PORTFOLIO_NO_CATEGORY_CODE",
                      "categories sheet must include a CategoryCode column for v2 portfolio analyses",
                      "Add CategoryCode column to Brand_Config Categories sheet"))
  }

  focal     <- config$focal_brand         %||% ""
  timeframe <- config$portfolio_timeframe %||% "3m"
  n_total   <- nrow(data)

  cats_list <- list()
  for (i in seq_len(nrow(categories))) {
    rec <- .po_build_category_record(
      cat_name        = as.character(categories$Category[i]),
      cat_code        = as.character(categories$CategoryCode[i]),
      analysis_depth  = .po_depth_from_cfg(categories, i),
      data            = data,
      role_map        = role_map,
      structure       = structure,
      timeframe       = timeframe,
      weights         = weights,
      n_total         = n_total,
      category_results = category_results
    )
    if (!is.null(rec)) cats_list[[rec$cat_code]] <- rec
  }

  if (length(cats_list) == 0L) {
    return(.po_refuse("DATA_OVERVIEW_NO_COVERAGE",
                      "No category awareness could be computed.",
                      "Confirm BRANDAWARE_*_1..N slot columns exist and CategoryCode values match the data."))
  }

  brands_df <- .po_build_brand_list(cats_list, focal)

  list(
    status      = "PASS",
    focal_brand = focal,
    brands      = brands_df,
    categories  = cats_list
  )
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Portfolio Overview data builder loaded (v%s)",
                  PORTFOLIO_OVERVIEW_VERSION))
}
