PORTFOLIO_VERSION <- "1.0"

PORTFOLIO_TIMEFRAME_3M  <- "3m"
PORTFOLIO_TIMEFRAME_13M <- "13m"

PORTFOLIO_MIN_BASE_DEFAULT          <- 30L
PORTFOLIO_COOCCUR_MIN_PAIRS_DEFAULT <- 20L
PORTFOLIO_EDGE_TOP_N_DEFAULT        <- 40L


# ==============================================================================
# DENOMINATOR HELPER
# ==============================================================================

# ==============================================================================
# V2: SLOT-INDEXED SCREENER QUALIFIER
# ==============================================================================

#' Build portfolio base from slot-indexed SQ1 / SQ2 columns
#'
#' v2 alternative to \code{build_portfolio_base()}. The IPK Alchemer
#' parser-shape data uses Multi_Mention slot columns (\code{SQ1_1..N},
#' \code{SQ2_1..N}) holding category codes as cell values, instead of
#' the legacy column-per-category \code{SQ1_DSS=1} pattern. This helper
#' resolves the qualifier index via \code{respondent_picked()}.
#'
#' Same denominator rule (§3.1 of PORTFOLIO_SPEC_v1): \code{timeframe}
#' \code{"3m"} reads SQ2 (target window), with SQ1 fallback when SQ2
#' columns are absent. \code{"13m"} reads SQ1 only.
#'
#' Returns the same list shape as \code{build_portfolio_base()} so
#' downstream sub-analyses can consume either output identically.
#'
#' @param data Data frame.
#' @param cat_code Character scalar.
#' @param timeframe \code{"3m"} or \code{"13m"}.
#' @param weights Numeric vector or NULL.
#' @return List with \code{idx} / \code{n_uw} / \code{n_w} /
#'   \code{col_used} (root, e.g. \code{"SQ2"}).
#' @export
build_portfolio_base <- function(data, cat_code,
                                    timeframe = PORTFOLIO_TIMEFRAME_3M,
                                    weights = NULL) {
  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0L) {
    return(list(status = "REFUSED",
                code = "DATA_PORTFOLIO_NOT_DATA_FRAME",
                message = "data must be a non-empty data frame",
                how_to_fix = "Provide a non-empty data frame to build_portfolio_base()"))
  }
  if (is.null(cat_code) || length(cat_code) != 1L ||
      !nzchar(trimws(as.character(cat_code)))) {
    return(list(status = "REFUSED",
                code = "DATA_PORTFOLIO_MISSING_CAT_CODE",
                message = "cat_code must be a non-empty character scalar",
                how_to_fix = "Provide a valid category code such as 'DSS'"))
  }
  cat_code <- trimws(as.character(cat_code))

  has_sq2_slots <- length(grep("^SQ2_[0-9]+$", names(data))) > 0L
  has_sq1_slots <- length(grep("^SQ1_[0-9]+$", names(data))) > 0L

  if (identical(timeframe, PORTFOLIO_TIMEFRAME_3M)) {
    if (has_sq2_slots) {
      idx <- respondent_picked(data, "SQ2", cat_code); col_used <- "SQ2"
    } else if (has_sq1_slots) {
      idx <- respondent_picked(data, "SQ1", cat_code); col_used <- "SQ1"
    } else {
      idx <- NULL; col_used <- NULL
    }
  } else {
    if (has_sq1_slots) {
      idx <- respondent_picked(data, "SQ1", cat_code); col_used <- "SQ1"
    } else {
      idx <- NULL; col_used <- NULL
    }
  }

  if (is.null(idx)) {
    expected <- if (identical(timeframe, PORTFOLIO_TIMEFRAME_3M)) "SQ2" else "SQ1"
    return(list(status = "REFUSED",
                code = "DATA_PORTFOLIO_TIMEFRAME_MISSING",
                message = sprintf(
                  "No screener slot columns found for timeframe '%s'. Expected '%s_1..N'.",
                  timeframe, expected),
                how_to_fix = sprintf(
                  paste0("Ensure the parsed data file contains the slot-indexed ",
                         "Multi_Mention question '%s_1..N' with category codes ",
                         "as cell values."),
                  expected)))
  }

  n_uw <- sum(idx)
  w    <- if (!is.null(weights)) weights else rep(1.0, nrow(data))
  n_w  <- sum(w[idx], na.rm = TRUE)
  list(idx = idx, n_uw = n_uw, n_w = n_w, col_used = col_used)
}


# ==============================================================================
# V2: SHARED AWARENESS-MATRIX HELPER
# ==============================================================================

#' Resolve the awareness column root for a category from a v2 role map
#'
#' Looks up \code{portfolio.awareness.{cat_code}} (preferred) or
#' \code{funnel.awareness.{cat_code}} in \code{role_map} and returns the
#' \code{column_root} field. When \code{role_map} is NULL or neither entry
#' resolves a non-empty root, falls back to the convention
#' \code{BRANDAWARE_{cat_code}}. Returns a single character string.
#'
#' @param role_map Named list from \code{build_brand_role_map()} or NULL.
#' @param cat_code Character scalar. Category code.
#' @return Character scalar — the awareness root.
#' @keywords internal
.portfolio_aware_root <- function(role_map, cat_code) {
  if (!is.null(role_map)) {
    for (key in c(paste0("portfolio.awareness.", cat_code),
                  paste0("funnel.awareness.",    cat_code))) {
      entry <- role_map[[key]]
      root  <- entry$column_root %||% NULL
      if (!is.null(root) && nzchar(root)) return(as.character(root))
    }
  }
  paste0("BRANDAWARE_", cat_code)
}


#' Build the per-respondent x per-brand awareness matrix for one category (v2)
#'
#' Single seam between portfolio sub-analyses and the slot-indexed data-access
#' layer. Every v2 sub-analysis (footprint, constellation, clutter, strength,
#' extension, overview) calls this helper to obtain the awareness matrix for a
#' category, replacing the legacy \code{data[[paste0("BRANDAWARE_", cat, "_",
#' brand)]] == 1L} reads.
#'
#' Returns an integer 0/1 matrix \code{[nrow(data) x length(brand_codes)]} with
#' \code{brand_codes} as colnames. Brands whose code never appears in any slot
#' contribute an all-zero column — caller decides whether that means "not
#' aware" or "not asked". (For the legacy column-per-brand fixture, slot
#' columns are absent and the helper returns an all-zero matrix; that fixture
#' is scheduled for retirement at cutover.)
#'
#' @param data Data frame.
#' @param role_map Named list from \code{build_brand_role_map()} or NULL.
#'   When NULL, the helper falls back to the \code{BRANDAWARE_{cat}}
#'   convention root.
#' @param cat_code Character scalar. Category code.
#' @param brand_codes Character vector. Brand codes in this category.
#' @return Integer matrix \code{[nrow(data) x length(brand_codes)]}, colnames
#'   = \code{brand_codes}, values 0 / 1.
#' @keywords internal
.portfolio_aware_matrix <- function(data, role_map, cat_code,
                                       brand_codes) {
  root <- .portfolio_aware_root(role_map, cat_code)
  multi_mention_indicator_matrix(data, root, brand_codes)
}


# ==============================================================================
# MAIN ORCHESTRATOR (stub — filled in phases 2-5)
# ==============================================================================

# ==============================================================================
# SUPPORTING METRICS HELPER (§5)
# ==============================================================================

# ==============================================================================
# V2 ORCHESTRATOR — slot-indexed parser-shape data
# ==============================================================================

run_portfolio <- function(data, role_map, categories, structure, config,
                              weights = NULL) {

  focal     <- config$focal_brand %||% ""
  timeframe <- config$portfolio_timeframe %||% PORTFOLIO_TIMEFRAME_3M

  guard_result <- tryCatch(
    guard_validate_portfolio(data, categories, structure, config),
    turas_refusal = function(e) {
      list(
        status     = "REFUSED",
        code       = e$code,
        message    = e$problem %||% conditionMessage(e),
        how_to_fix = e$how_to_fix
      )
    }
  )
  if (!is.null(guard_result$status) && identical(guard_result$status, "REFUSED")) {
    cat("\n┌─── TURAS BRAND ERROR ──────────────────────────────────────────┐\n")
    cat("│ Context: run_portfolio()\n")
    cat(sprintf("│ Code: %s\n", guard_result$code))
    cat(sprintf("│ Message: %s\n", guard_result$message))
    cat(sprintf("│ How to fix: %s\n",
                paste(guard_result$how_to_fix, collapse = "; ")))
    cat("└────────────────────────────────────────────────────────────────┘\n\n")
    return(guard_result)
  }

  n_total <- nrow(data)
  total_w <- if (!is.null(weights)) sum(weights, na.rm = TRUE) else as.numeric(n_total)

  # Phase 2 — footprint + clutter
  footprint_result <- tryCatch(
    compute_footprint_matrix(data, role_map, categories, structure, config, weights),
    error = function(e) {
      message(sprintf("[PORTFOLIO_V2] Footprint failed: %s", e$message))
      NULL
    }
  )

  clutter_result <- tryCatch(
    compute_clutter_data(data, role_map, categories, structure, config, weights),
    error = function(e) {
      message(sprintf("[PORTFOLIO_V2] Clutter failed: %s", e$message))
      NULL
    }
  )

  # Phase 3 — strength map + extension + per-brand extension
  strength_result <- tryCatch(
    compute_strength_map(data, role_map, categories, structure, config, weights),
    error = function(e) {
      message(sprintf("[PORTFOLIO_V2] Strength failed: %s", e$message))
      NULL
    }
  )

  extension_result <- tryCatch(
    compute_extension_table(data, role_map, categories, structure, config, weights,
                                footprint_result = footprint_result),
    error = function(e) {
      message(sprintf("[PORTFOLIO_V2] Extension failed: %s", e$message))
      NULL
    }
  )

  extension_per_brand <- tryCatch(
    compute_extension_per_brand(data, role_map, categories, structure, config, weights,
                                    footprint_result = footprint_result),
    error = function(e) {
      message(sprintf("[PORTFOLIO_V2] Per-brand extension failed: %s", e$message))
      NULL
    }
  )

  # Phase 4 — cross-cat + per-cat constellations
  constellation_result <- tryCatch(
    compute_constellation(data, role_map, categories, structure, config, weights),
    error = function(e) {
      message(sprintf("[PORTFOLIO_V2] Constellation failed: %s", e$message))
      NULL
    }
  )
  constellation_per_cat <- tryCatch(
    compute_constellations_per_cat(data, role_map, categories, structure, config, weights),
    error = function(e) {
      message(sprintf("[PORTFOLIO_V2] Per-category constellations failed: %s", e$message))
      NULL
    }
  )

  all_suppressed <- unique(c(
    if (!is.null(footprint_result)) footprint_result$suppressed_cats   else character(0),
    if (!is.null(clutter_result))   clutter_result$suppressed_cats     else character(0),
    if (!is.null(strength_result))  strength_result$suppressed_cats    else character(0),
    if (!is.null(extension_result) &&
        identical(extension_result$status, "PASS"))
      extension_result$suppressed_cats else character(0)
  ))

  bases_per_cat <- if (!is.null(footprint_result) &&
                        !is.null(footprint_result$bases_df) &&
                        nrow(footprint_result$bases_df) > 0) {
    footprint_result$bases_df
  } else {
    data.frame(cat = character(0), n_buyers_uw = integer(0),
               n_buyers_w = numeric(0), stringsAsFactors = FALSE)
  }

  supporting_result <- .compute_supporting_metrics(
    data             = data,
    weights          = if (!is.null(weights)) weights else rep(1.0, n_total),
    timeframe        = timeframe,
    focal            = focal,
    categories       = categories,
    footprint_result = footprint_result,
    clutter_result   = clutter_result,
    extension_result = if (!is.null(extension_result) &&
                           identical(extension_result$status, "PASS"))
                         extension_result else NULL,
    n_cats_total     = nrow(categories)
  )

  list(
    status       = "PASS",
    focal_brand  = focal,
    timeframe    = timeframe,
    n_total      = n_total,
    n_weighted   = total_w,
    bases        = list(
      per_category = bases_per_cat,
      per_brand    = data.frame(
        brand                = character(0),
        n_aware_uw           = integer(0),
        n_aware_w            = numeric(0),
        n_categories_present = integer(0),
        stringsAsFactors     = FALSE
      )
    ),
    footprint_matrix = if (!is.null(footprint_result)) footprint_result$matrix_df else NULL,
    footprint_meta   = if (!is.null(footprint_result)) list(
                          cat_names   = footprint_result$cat_names   %||% character(0),
                          brand_names = footprint_result$brand_names %||% character(0)
                        ) else NULL,
    constellation    = if (!is.null(constellation_result) &&
                           identical(constellation_result$status, "PASS"))
                         constellation_result else NULL,
    constellation_per_cat = if (!is.null(constellation_per_cat) &&
                                 identical(constellation_per_cat$status, "PASS"))
                              constellation_per_cat else NULL,
    clutter          = clutter_result,
    strength         = if (!is.null(strength_result) &&
                           identical(strength_result$status, "PASS"))
                         strength_result else NULL,
    extension        = if (!is.null(extension_result) &&
                           identical(extension_result$status, "PASS"))
                         extension_result else NULL,
    extension_per_brand = if (!is.null(extension_per_brand) &&
                               length(extension_per_brand$per_brand %||% list()) > 0)
                            extension_per_brand else NULL,
    supporting       = supporting_result,
    suppressions     = list(
      low_base_cats  = all_suppressed,
      dropped_brands = character(0),
      dropped_edges  = 0L
    )
  )
}


# ==============================================================================
# V2 SUPPORTING METRICS HELPER
# ==============================================================================

#' Compute hero-strip supporting metrics for the portfolio tab (v2)
#'
#' v2 alternative to \code{.compute_supporting_metrics()}. Differs only in the
#' repertoire-depth calculation: walks slot-indexed SQ columns via
#' \code{respondent_picked()} for every CategoryCode in \code{categories},
#' instead of the legacy \code{grep("^SQ[12]_")} over column-per-category data.
#' On legacy column-per-cat data the helper returns 0 depth (slot columns
#' are absent); the legacy v1 helper handles that fixture.
#'
#' @param data Data frame.
#' @param weights Numeric vector. Survey weights.
#' @param timeframe Character. \code{"3m"} or \code{"13m"}.
#' @param focal Character. Focal brand code.
#' @param categories Data frame with \code{CategoryCode} column.
#' @param footprint_result List or NULL. From
#'   \code{compute_footprint_matrix()}.
#' @param clutter_result List or NULL. From \code{compute_clutter_data()}.
#' @param extension_result List or NULL. From
#'   \code{compute_extension_table()} when status PASS.
#' @param n_cats_total Integer. Total number of categories in config.
#' @return Named list, same shape as \code{.compute_supporting_metrics()}.
#' @keywords internal
.compute_supporting_metrics <- function(data, weights, timeframe, focal,
                                            categories,
                                            footprint_result, clutter_result,
                                            extension_result, n_cats_total) {
  w <- weights

  breadth <- 0L
  if (!is.null(footprint_result) && !is.null(footprint_result$matrix_df)) {
    fp <- footprint_result$matrix_df
    if (nrow(fp) > 0 && "Brand" %in% names(fp)) {
      focal_row <- fp[fp$Brand == focal, setdiff(names(fp), "Brand"), drop = FALSE]
      if (nrow(focal_row) > 0) {
        vals    <- unlist(focal_row[1L, ], use.names = FALSE)
        breadth <- sum(!is.na(vals) & vals > 0)
      }
    }
  }

  home_cat <- if (!is.null(extension_result)) extension_result$home_cat else NULL

  avg_set_size     <- NA_real_
  focal_efficiency <- NA_real_
  if (!is.null(clutter_result) && !is.null(clutter_result$clutter_df)) {
    cl <- clutter_result$clutter_df
    if (nrow(cl) > 0) {
      home_row <- if (!is.null(home_cat) && home_cat %in% cl$cat) {
        cl[cl$cat == home_cat, , drop = FALSE]
      } else {
        max_idx <- which.max(cl$focal_share_of_aware)
        cl[max_idx, , drop = FALSE]
      }
      if (nrow(home_row) > 0) {
        avg_set_size <- home_row$awareness_set_size_mean[1L]
        sh  <- home_row$focal_share_of_aware[1L]
        pen <- home_row$cat_penetration[1L]
        if (!is.na(sh) && !is.na(pen) && pen > 0) {
          focal_efficiency <- sh / pen
        }
      }
    }
  }

  # Slot-aware repertoire depth: count picks across CategoryCodes via the
  # parser-shape SQ slot root (SQ1 for 13m, SQ2 for 3m).
  sq_root <- if (identical(timeframe, "13m")) "SQ1" else "SQ2"
  cat_codes <- if (!is.null(categories) && "CategoryCode" %in% names(categories)) {
    cc <- as.character(categories$CategoryCode)
    cc[!is.na(cc) & nzchar(cc)]
  } else {
    character(0)
  }

  mean_repertoire_depth <- NA_real_
  if (length(cat_codes) > 0L && nrow(data) > 0L) {
    indicator_mat <- vapply(cat_codes, function(cc) {
      as.integer(respondent_picked(data, sq_root, cc))
    }, integer(nrow(data)))
    depths <- if (is.matrix(indicator_mat)) rowSums(indicator_mat) else
              as.integer(indicator_mat)
    w_sum <- sum(w, na.rm = TRUE)
    if (w_sum > 0) {
      mean_repertoire_depth <- sum(w * depths, na.rm = TRUE) / w_sum
    }
  }

  list(
    avg_awareness_set_size_focal_cat = avg_set_size,
    focal_footprint_breadth          = as.integer(breadth),
    n_cats_total                     = as.integer(n_cats_total),
    focal_awareness_efficiency       = focal_efficiency,
    mean_repertoire_depth            = mean_repertoire_depth,
    home_cat                         = home_cat %||% ""
  )
}
