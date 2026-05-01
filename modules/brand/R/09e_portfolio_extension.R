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
#
# SIZE-EXCEPTION: extension lift + per-brand walker + significance test +
# home-cat detector form one coherent extension-table pipeline. During the
# IPK rebuild the file holds both v1 (column-per-brand) and v2 (slot-indexed)
# variants of compute_extension_table and compute_extension_per_brand. The
# legacy v1 entries are scheduled for deletion at rebuild cutover (planning
# doc §9 step 5), bringing the file back inside the 300-active-line default.
# ==============================================================================

EXTENSION_BASELINE_ALL        <- "all"
EXTENSION_BASELINE_NON_BUYERS <- "non_buyers"


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


# ==============================================================================
# V2: SLOT-INDEXED EXTENSION TABLE
# ==============================================================================

#' Compute permission-to-extend table (v2 — slot-indexed)
#'
#' v2 alternative to \code{compute_extension_table()}.  The focal-awareness
#' vector in each category comes from \code{respondent_picked()} on the
#' awareness root resolved by \code{.portfolio_aware_root()}.  The
#' non-buyers baseline (when \code{config$portfolio_extension_baseline ==
#' "non_buyers"}) reads SQ1 slots for the home category instead of the
#' legacy \code{SQ1_{home_cat}} column-per-cat.
#'
#' @param data Data frame.
#' @param role_map Named list from \code{build_brand_role_map()} or NULL.
#' @param categories Data frame with \code{Category} + \code{CategoryCode}.
#' @param structure List from a Survey_Structure loader.
#' @param config List with portfolio settings + \code{focal_brand}.
#' @param weights Numeric vector or NULL.
#' @param footprint_result List or NULL. From
#'   \code{compute_footprint_matrix()} — used to auto-detect home cat.
#' @return Same list shape as \code{compute_extension_table()}.
#' @export
compute_extension_table <- function(data, role_map, categories, structure,
                                        config, weights = NULL,
                                        footprint_result = NULL) {
  focal_brand <- config$focal_brand %||% ""
  timeframe   <- config$portfolio_timeframe %||% "3m"
  min_base    <- config$portfolio_min_base  %||% 30L
  baseline_mode <- trimws(config$portfolio_extension_baseline %||%
                            EXTENSION_BASELINE_ALL)
  n_total <- nrow(data)
  w       <- if (!is.null(weights)) weights else rep(1.0, n_total)

  if (!"CategoryCode" %in% names(categories)) {
    return(list(status = "REFUSED",
                code = "CFG_PORTFOLIO_NO_CATEGORY_CODE",
                message = "categories sheet must include a CategoryCode column for v2 portfolio analyses",
                how_to_fix = "Add CategoryCode column to Brand_Config Categories sheet"))
  }

  if (!nzchar(focal_brand)) {
    return(list(
      status     = "REFUSED",
      code       = "CALC_EXTENSION_NO_FOCAL_AWARENESS",
      message    = "focal_brand is empty — cannot compute extension lift",
      how_to_fix = "Set focal_brand in the brand config"
    ))
  }

  # --- Brand universe + presence check (focal must be aware in >= 1 cat) ---
  brands_df    <- structure$brands
  if (is.null(brands_df) || nrow(brands_df) == 0L) {
    return(list(status = "REFUSED",
                code = "CFG_NO_BRAND_LIST",
                message = "structure$brands is empty — cannot compute extension",
                how_to_fix = "Populate the Brands sheet"))
  }
  focal_in_cats <- unique(as.character(
    brands_df$CategoryCode[brands_df$BrandCode == focal_brand]))
  if (length(focal_in_cats) == 0L) {
    return(list(
      status     = "REFUSED",
      code       = "CALC_EXTENSION_NO_FOCAL_AWARENESS",
      message    = sprintf(
        "Focal brand '%s' is not declared in any category in structure$brands",
        focal_brand),
      how_to_fix = "Add the focal brand to the Brands sheet for at least one category"
    ))
  }

  # --- Auto-detect or use configured home category ---
  cfg_home <- trimws(config$focal_home_category %||% "")
  home_cat_source <- if (nzchar(cfg_home)) "config" else "auto"
  home_cat <- if (nzchar(cfg_home)) {
    cfg_home
  } else if (!is.null(footprint_result) &&
             !is.null(footprint_result$matrix_df) &&
             nrow(footprint_result$matrix_df) > 0L) {
    .detect_home_category(footprint_result$matrix_df,
                          footprint_result$bases_df,
                          focal_brand, n_total)
  } else ""

  # --- Non-buyers baseline mask ---
  home_buyer_idx <- if (baseline_mode == EXTENSION_BASELINE_NON_BUYERS &&
                         nzchar(home_cat)) {
    as.integer(respondent_picked(data, "SQ1", home_cat))
  } else NULL

  rows_list  <- list()
  suppressed <- character(0)

  for (i in seq_len(nrow(categories))) {
    cat_name <- as.character(categories$Category[i])
    cat_code <- as.character(categories$CategoryCode[i])
    if (is.na(cat_code) || !nzchar(cat_code)) next

    is_home <- identical(cat_code, home_cat)

    base <- build_portfolio_base(data, cat_code, timeframe, weights)
    if (!is.null(base$status)) next
    if (base$n_uw == 0L) { suppressed <- c(suppressed, cat_code); next }

    low_base_flag <- base$n_uw < min_base
    if (low_base_flag) suppressed <- c(suppressed, cat_code)

    aw_root <- .portfolio_aware_root(role_map, cat_code)
    aw_vals <- as.integer(respondent_picked(data, aw_root, focal_brand))

    n1_w <- sum(w[base$idx], na.rm = TRUE)
    x1_w <- sum(w[base$idx] * aw_vals[base$idx], na.rm = TRUE)
    p_c  <- if (n1_w > 0) x1_w / n1_w else NA_real_

    if (baseline_mode == EXTENSION_BASELINE_NON_BUYERS &&
        !is.null(home_buyer_idx)) {
      non_buyer_idx <- home_buyer_idx == 0L
      n2_w <- sum(w[non_buyer_idx], na.rm = TRUE)
      x2_w <- sum(w[non_buyer_idx] * aw_vals[non_buyer_idx], na.rm = TRUE)
    } else {
      n2_w <- sum(w, na.rm = TRUE)
      x2_w <- sum(w * aw_vals, na.rm = TRUE)
    }
    p_base <- if (n2_w > 0) x2_w / n2_w else NA_real_

    lift <- if (!is.na(p_c) && !is.na(p_base) && p_base > 0) {
      p_c / p_base
    } else NA_real_

    x1_int <- as.integer(round(x1_w))
    n1_int <- as.integer(round(n1_w))
    x2_int <- as.integer(round(x2_w))
    n2_int <- as.integer(round(n2_w))
    sig    <- .ext_sig_test(x1_int, n1_int, x2_int, n2_int)

    rows_list[[cat_code]] <- list(
      cat             = cat_code,
      is_home         = is_home,
      n_buyers_uw     = base$n_uw,
      focal_aware_pct = if (!is.na(p_c)) p_c * 100 else NA_real_,
      lift            = lift,
      p_value         = sig$p_value,
      test_used       = sig$test_used,
      low_base_flag   = low_base_flag
    )
  }

  if (length(rows_list) == 0L) {
    return(list(
      status          = "PASS",
      extension_df    = data.frame(),
      home_cat        = home_cat,
      home_cat_source = home_cat_source,
      suppressed_cats = suppressed
    ))
  }

  ext_df <- do.call(rbind, lapply(rows_list, as.data.frame,
                                   stringsAsFactors = FALSE))
  rownames(ext_df) <- NULL

  p_vals <- ext_df$p_value
  p_adj  <- rep(NA_real_, nrow(ext_df))
  valid  <- !is.na(p_vals)
  if (any(valid)) p_adj[valid] <- p.adjust(p_vals[valid], method = "BH")
  ext_df$p_adj <- p_adj

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


#' Compute the per-brand extension table for the JS focal switcher (v2)
#'
#' v2 alternative to \code{compute_extension_per_brand()}.  Walks the brand
#' universe from \code{structure$brands$BrandCode} (instead of a regex scan
#' over data column names) and runs \code{compute_extension_table()} for
#' each brand.  Brands whose extension run fails (REFUSED) are skipped.
#'
#' @inheritParams compute_extension_table
#' @return Same list shape as \code{compute_extension_per_brand()}.
#' @export
compute_extension_per_brand <- function(data, role_map, categories,
                                            structure, config, weights = NULL,
                                            footprint_result = NULL) {
  per_brand      <- list()
  cat_names      <- list()
  brand_names    <- list()
  all_suppressed <- character(0)

  if (!"CategoryCode" %in% names(categories)) {
    return(list(per_brand = list(), cat_names = list(), brand_names = list(),
                suppressed_cats = character(0)))
  }
  for (i in seq_len(nrow(categories))) {
    nm <- as.character(categories$Category[i])
    cc <- as.character(categories$CategoryCode[i])
    if (is.na(cc) || !nzchar(cc)) next
    cat_names[[cc]] <- nm
  }

  brands_df <- structure$brands
  if (is.null(brands_df) || nrow(brands_df) == 0L) {
    return(list(per_brand = list(), cat_names = cat_names,
                brand_names = list(), suppressed_cats = character(0)))
  }

  if ("BrandLabel" %in% names(brands_df) ||
      "BrandName"  %in% names(brands_df)) {
    lbl_col <- if ("BrandLabel" %in% names(brands_df)) "BrandLabel"
               else "BrandName"
    for (k in seq_len(nrow(brands_df))) {
      bc  <- as.character(brands_df$BrandCode[k])
      lbl <- as.character(brands_df[[lbl_col]][k])
      if (!nzchar(brand_names[[bc]] %||% "") && nzchar(lbl)) {
        brand_names[[bc]] <- lbl
      }
    }
  }

  universe <- unique(as.character(brands_df$BrandCode))
  if (length(universe) == 0L) {
    return(list(per_brand = list(), cat_names = cat_names,
                brand_names = brand_names, suppressed_cats = character(0)))
  }

  for (bc in universe) {
    cfg_for_brand <- config
    cfg_for_brand$focal_brand <- bc
    res <- tryCatch(
      compute_extension_table(data, role_map, categories, structure,
                                  cfg_for_brand, weights, footprint_result),
      error = function(e) NULL
    )
    if (is.null(res) || identical(res$status, "REFUSED")) next
    per_brand[[bc]]  <- res
    all_suppressed   <- unique(c(all_suppressed,
                                  res$suppressed_cats %||% character(0)))
    if (!nzchar(brand_names[[bc]] %||% "")) brand_names[[bc]] <- bc
  }

  list(
    per_brand       = per_brand,
    cat_names       = cat_names,
    brand_names     = brand_names,
    suppressed_cats = all_suppressed
  )
}
