# ==============================================================================
# BRAND MODULE - PERMISSION-TO-EXTEND TABLE (§4.5)
# ==============================================================================
# For each category not the focal brand's home, computes:
#   lift(c) = P(aware focal | bought c) / P(aware focal | baseline)
#
# Significance: two-proportion z-test by default; auto-fallback to Fisher's
# exact when any expected 2×2 cell count < 5. BH correction applied across
# all categories regardless of which test was used per row.
#
# Denominator: build_portfolio_base() per §3.1 — never inline SQ1_/SQ2_.
# ==============================================================================

EXTENSION_BASELINE_ALL        <- "all"
EXTENSION_BASELINE_NON_BUYERS <- "non_buyers"


#' Compute permission-to-extend tables for every brand in the universe.
#'
#' Runs \code{compute_extension_table()} once per brand so the panel's
#' focal-brand picker can swap focals client-side without a server
#' round-trip. Builds the brand universe from the footprint matrix
#' (the canonical "every brand we measured" list) and excludes brands
#' for which no cross-category awareness column exists.
#'
#' @inheritParams compute_extension_table
#' @return List with:
#'   \item{per_brand}{Named list keyed by brand code; each entry is the
#'     full `compute_extension_table` result (extension_df, home_cat,
#'     home_cat_source, suppressed_cats).}
#'   \item{cat_names}{Named list cat_code → display name (taken from the
#'     categories sheet).}
#'   \item{brand_names}{Named list brand_code → display name.}
#'   \item{suppressed_cats}{Character. Union of suppressed cats across runs.}
#' @export
compute_extension_per_brand <- function(data, categories, structure,
                                        config, weights = NULL,
                                        footprint_result = NULL) {
  per_brand     <- list()
  cat_names     <- list()
  brand_names   <- list()
  all_suppressed <- character(0)

  # Cat-name map — straight from the categories sheet, since detection
  # of the cat code is already handled by compute_extension_table.
  for (i in seq_len(nrow(categories))) {
    nm <- as.character(categories$Category[i])
    if (!nzchar(nm)) next
    detector <- if (exists(".po_detect_cat_code", mode = "function"))
                  .po_detect_cat_code else .detect_category_code
    cat_brands <- tryCatch(
      get_brands_for_category(structure, nm),
      error = function(e) data.frame(BrandCode = character(0))
    )
    if (nrow(cat_brands) == 0) next
    cc <- if (!is.null(structure$questionmap) &&
              nrow(structure$questionmap) > 0)
            detector(structure$questionmap, cat_brands, data) else NULL
    if (!is.null(cc)) cat_names[[cc]] <- nm

    # While we're here, harvest brand display labels from the BrandList.
    if ("BrandLabel" %in% names(cat_brands) ||
        "BrandName"  %in% names(cat_brands)) {
      lbl_col <- if ("BrandLabel" %in% names(cat_brands)) "BrandLabel" else "BrandName"
      for (k in seq_len(nrow(cat_brands))) {
        bc  <- as.character(cat_brands$BrandCode[k])
        lbl <- as.character(cat_brands[[lbl_col]][k])
        if (!nzchar(brand_names[[bc]] %||% "") && nzchar(lbl))
          brand_names[[bc]] <- lbl
      }
    }
  }

  # Universe of brands — anything with at least one BRANDAWARE column.
  aw_cols <- grep("^BRANDAWARE_[^_]+_[^_]+$", names(data), value = TRUE)
  if (length(aw_cols) == 0) {
    return(list(per_brand = list(), cat_names = cat_names,
                brand_names = brand_names, suppressed_cats = character(0)))
  }
  universe <- unique(sub("^BRANDAWARE_[^_]+_", "", aw_cols))

  # Compute extension for each brand. Pass a config clone whose
  # focal_brand is overridden so compute_extension_table picks it up
  # without us touching its internals.
  for (bc in universe) {
    cfg_for_brand <- config
    cfg_for_brand$focal_brand <- bc
    res <- tryCatch(
      compute_extension_table(data, categories, structure,
                              cfg_for_brand, weights, footprint_result),
      error = function(e) NULL
    )
    if (is.null(res) || identical(res$status, "REFUSED")) next
    per_brand[[bc]]  <- res
    all_suppressed   <- unique(c(all_suppressed, res$suppressed_cats %||% character(0)))
    if (!nzchar(brand_names[[bc]] %||% "")) brand_names[[bc]] <- bc
  }

  list(
    per_brand       = per_brand,
    cat_names       = cat_names,
    brand_names     = brand_names,
    suppressed_cats = all_suppressed
  )
}


#' Auto-detect focal brand's home category
#'
#' Home = category with highest A(focal, c). Ties broken by highest category
#' penetration. Returns the category code or \code{""} if not detectable.
#'
#' @param footprint_matrix Data frame. Output from compute_footprint_matrix().
#' @param bases_df Data frame. bases_df from compute_footprint_matrix().
#' @param focal_brand Character. Focal brand code.
#' @param n_total Integer. Total respondents (for cat_pen fallback).
#' @keywords internal
.detect_home_category <- function(footprint_matrix, bases_df,
                                   focal_brand, n_total) {
  if (is.null(footprint_matrix) || nrow(footprint_matrix) == 0) return("")
  focal_row <- footprint_matrix[footprint_matrix$Brand == focal_brand, ,
                                drop = FALSE]
  if (nrow(focal_row) == 0) return("")

  cat_cols <- setdiff(names(focal_row), "Brand")
  if (length(cat_cols) == 0) return("")

  vals <- unlist(focal_row[, cat_cols, drop = FALSE])
  vals <- vals[!is.na(vals)]
  if (length(vals) == 0) return("")

  max_aw <- max(vals)
  candidates <- names(vals)[vals == max_aw]

  if (length(candidates) == 1) return(candidates)

  if (!is.null(bases_df) && nrow(bases_df) > 0 && n_total > 0) {
    pens <- vapply(candidates, function(cc) {
      idx <- which(bases_df$cat == cc)
      if (length(idx) == 0) return(0)
      bases_df$n_buyers_uw[idx[1]] / n_total
    }, numeric(1))
    return(candidates[which.max(pens)])
  }

  candidates[1]
}


#' Compute significance for one row of the extension table
#'
#' Two-proportion z-test by default; falls back to Fisher's exact when any
#' expected 2×2 cell count < 5. Returns list(p_value, test_used).
#'
#' @param x1 Integer. Aware-of-focal count in category c buyers.
#' @param n1 Integer. Total category c buyers.
#' @param x2 Integer. Aware-of-focal count at baseline.
#' @param n2 Integer. Total baseline respondents.
#' @keywords internal
.ext_sig_test <- function(x1, n1, x2, n2) {
  if (n1 <= 0 || n2 <= 0) return(list(p_value = NA_real_, test_used = "none"))

  p1 <- x1 / n1
  p2 <- x2 / n2

  # Expected counts in 2x2 contingency
  p_pool <- (x1 + x2) / (n1 + n2)
  e11 <- n1 * p_pool; e12 <- n1 * (1 - p_pool)
  e21 <- n2 * p_pool; e22 <- n2 * (1 - p_pool)

  if (min(e11, e12, e21, e22) < 5) {
    m <- matrix(c(x1, n1 - x1, x2, n2 - x2), nrow = 2)
    pv <- tryCatch(fisher.test(m)$p.value, error = function(e) NA_real_)
    return(list(p_value = pv, test_used = "fisher"))
  }

  denom <- sqrt(p_pool * (1 - p_pool) * (1 / n1 + 1 / n2))
  if (denom <= 0) return(list(p_value = NA_real_, test_used = "none"))
  z  <- (p1 - p2) / denom
  pv <- 2 * pnorm(-abs(z))
  list(p_value = pv, test_used = "z_test")
}


#' Compute permission-to-extend table
#'
#' Produces the lift table for §4.5 of the portfolio spec. Identifies the
#' focal brand's home category, then for every other qualifying category
#' computes:
#' \code{lift = P(aware focal | bought c) / P(aware focal | baseline)}.
#'
#' Baseline is controlled by \code{config$portfolio_extension_baseline}:
#' \code{"all"} (default) = all sample; \code{"non_buyers"} = respondents
#' who did not buy focal's home category.
#'
#' @param data Data frame. Full survey data.
#' @param categories Data frame. Categories sheet.
#' @param structure List. Loaded survey structure.
#' @param config List. Loaded brand config.
#' @param weights Numeric vector or NULL. Survey weights.
#' @param footprint_result List or NULL. Output from compute_footprint_matrix().
#'   If supplied, used to auto-detect home category.
#'
#' @return List:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{extension_df}{Data frame: cat, n_buyers_uw, focal_aware_pct, lift,
#'     p_value, p_adj, test_used, low_base_flag, home_cat_flag.}
#'   \item{home_cat}{Character. Detected or configured home category code.}
#'   \item{home_cat_source}{Character. "auto" or "config".}
#'   \item{suppressed_cats}{Character. Categories below min_base.}
#'
#' @export
compute_extension_table <- function(data, categories, structure,
                                    config, weights = NULL,
                                    footprint_result = NULL) {
  focal_brand <- config$focal_brand %||% ""
  timeframe   <- config$portfolio_timeframe %||% "3m"
  min_base    <- config$portfolio_min_base  %||% 30L
  baseline_mode <- trimws(config$portfolio_extension_baseline %||%
                            EXTENSION_BASELINE_ALL)
  n_total <- nrow(data)
  w       <- if (!is.null(weights)) weights else rep(1.0, n_total)

  if (!nzchar(focal_brand)) {
    return(list(
      status     = "REFUSED",
      code       = "CALC_EXTENSION_NO_FOCAL_AWARENESS",
      message    = "focal_brand is empty — cannot compute extension lift",
      how_to_fix = "Set focal_brand in the brand config"
    ))
  }

  # --- Auto-detect or use configured home category ---
  cfg_home <- trimws(config$focal_home_category %||% "")
  home_cat_source <- if (nzchar(cfg_home)) "config" else "auto"

  home_cat <- if (nzchar(cfg_home)) {
    cfg_home
  } else if (!is.null(footprint_result) &&
             !is.null(footprint_result$matrix_df) &&
             nrow(footprint_result$matrix_df) > 0) {
    .detect_home_category(footprint_result$matrix_df, footprint_result$bases_df,
                          focal_brand, n_total)
  } else ""

  # --- Compute baseline aware rate ---
  # Find any awareness column for focal brand across categories
  focal_aw_cols <- grep(paste0("BRANDAWARE_[^_]+_", focal_brand, "$"),
                        names(data), value = TRUE)

  if (length(focal_aw_cols) == 0) {
    return(list(
      status     = "REFUSED",
      code       = "CALC_EXTENSION_NO_FOCAL_AWARENESS",
      message    = sprintf("No BRANDAWARE_*_%s columns found in data", focal_brand),
      how_to_fix = "Ensure cross-category awareness columns exist for the focal brand"
    ))
  }

  # Build home-category SQ1 index for non_buyers baseline
  home_sq1_idx <- if (baseline_mode == EXTENSION_BASELINE_NON_BUYERS &&
                       nzchar(home_cat)) {
    home_sq1_col <- paste0("SQ1_", home_cat)
    if (home_sq1_col %in% names(data)) {
      as.integer(!is.na(data[[home_sq1_col]]) & data[[home_sq1_col]] == 1L)
    } else rep(0L, n_total)
  } else NULL

  # --- Loop categories ---
  rows_list  <- list()
  suppressed <- character(0)

  for (i in seq_len(nrow(categories))) {
    cat_name   <- categories$Category[i]
    cat_brands <- tryCatch(
      get_brands_for_category(structure, cat_name),
      error = function(e) data.frame(BrandCode = character(0))
    )
    if (nrow(cat_brands) == 0) next

    detector <- if (exists(".po_detect_cat_code", mode = "function"))
                  .po_detect_cat_code else .detect_category_code
    cat_code <- if (!is.null(structure$questionmap) &&
                    nrow(structure$questionmap) > 0)
      detector(structure$questionmap, cat_brands, data) else NULL
    if (is.null(cat_code)) next

    # Extension table: skip home category (it's the reference, not an extension)
    is_home <- identical(cat_code, home_cat)

    base <- build_portfolio_base(data, cat_code, timeframe, weights)
    if (!is.null(base$status)) next

    low_base_flag <- base$n_uw < min_base
    if (low_base_flag) suppressed <- c(suppressed, cat_code)

    aw_col <- paste0("BRANDAWARE_", cat_code, "_", focal_brand)
    if (!aw_col %in% names(data)) next

    aw_vals <- as.integer(!is.na(data[[aw_col]]) & data[[aw_col]] == 1L)

    # p_c: focal aware % among c-buyers (weighted)
    n1_w   <- sum(w[base$idx], na.rm = TRUE)
    x1_w   <- sum(w[base$idx] * aw_vals[base$idx], na.rm = TRUE)
    p_c    <- if (n1_w > 0) x1_w / n1_w else NA_real_

    # baseline
    if (baseline_mode == EXTENSION_BASELINE_NON_BUYERS && !is.null(home_sq1_idx)) {
      non_buyer_idx <- home_sq1_idx == 0L
      n2_w  <- sum(w[non_buyer_idx], na.rm = TRUE)
      x2_w  <- sum(w[non_buyer_idx] * aw_vals[non_buyer_idx], na.rm = TRUE)
    } else {
      n2_w <- sum(w, na.rm = TRUE)
      x2_w <- sum(w * aw_vals, na.rm = TRUE)
    }
    p_base <- if (n2_w > 0) x2_w / n2_w else NA_real_

    lift <- if (!is.na(p_c) && !is.na(p_base) && p_base > 0) p_c / p_base else NA_real_

    # Significance (integer counts for test)
    x1_int <- as.integer(round(x1_w))
    n1_int <- as.integer(round(n1_w))
    x2_int <- as.integer(round(x2_w))
    n2_int <- as.integer(round(n2_w))
    sig    <- .ext_sig_test(x1_int, n1_int, x2_int, n2_int)

    rows_list[[cat_code]] <- list(
      cat            = cat_code,
      is_home        = is_home,
      n_buyers_uw    = base$n_uw,
      focal_aware_pct = if (!is.na(p_c)) p_c * 100 else NA_real_,
      lift           = lift,
      p_value        = sig$p_value,
      test_used      = sig$test_used,
      low_base_flag  = low_base_flag
    )
  }

  if (length(rows_list) == 0) {
    return(list(
      status          = "PASS",
      extension_df    = data.frame(),
      home_cat        = home_cat,
      home_cat_source = home_cat_source,
      suppressed_cats = suppressed
    ))
  }

  ext_df <- do.call(rbind, lapply(rows_list, as.data.frame, stringsAsFactors = FALSE))
  rownames(ext_df) <- NULL

  # BH correction across all rows (including home cat row)
  p_vals <- ext_df$p_value
  p_adj  <- rep(NA_real_, nrow(ext_df))
  valid  <- !is.na(p_vals)
  if (any(valid)) {
    p_adj[valid] <- p.adjust(p_vals[valid], method = "BH")
  }
  ext_df$p_adj <- p_adj

  # Sort: home cat first for reference, then by lift desc (non-home cats)
  non_home <- ext_df[!ext_df$is_home, , drop = FALSE]
  home_row <- ext_df[ext_df$is_home,  , drop = FALSE]
  lift_order <- order(non_home$lift, decreasing = TRUE, na.last = TRUE)
  ext_df <- rbind(home_row, non_home[lift_order, , drop = FALSE])

  list(
    status          = "PASS",
    extension_df    = ext_df,
    home_cat        = home_cat,
    home_cat_source = home_cat_source,
    suppressed_cats = suppressed
  )
}
