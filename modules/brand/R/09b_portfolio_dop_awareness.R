# ==============================================================================
# BRAND MODULE - PORTFOLIO DUPLICATION OF AWARENESS (DoA)
# ==============================================================================
# Awareness analogue of the Duplication of Purchase table in 04_repertoire.R.
#
# For each category C with >= 2 brands and an adequate base, this module
# computes, on the category-buyer base:
#
#   observed[i,j] = weighted P(aware of brand j | aware of brand i) * 100
#   D             = Sigma(obs * a_j) / Sigma(a_j^2)        over i != j cells
#   expected[i,j] = D * a_j                                       (Sharp's law)
#   deviation[i,j] = observed[i,j] - expected[i,j]                       (pp)
#
# where a_j is the % of category buyers aware of brand j.
#
# The methodology mirrors compute_repertoire_metrics() lines 162-298 exactly,
# with awareness penetration a_j substituted for brand penetration b_j. This
# keeps the engine consistent with the published Ehrenberg / Sharp framework
# and tracker-friendly (a single D per category per wave).
#
# Reuses .portfolio_aware_matrix() from 09b_portfolio_constellation.R so the
# awareness universe is identical to the one driving the Competitive Set
# constellation chart.
# ==============================================================================

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a


# ==============================================================================
# CONSTANTS
# ==============================================================================

# Minimum number of brands a category must have (with >0 awareness) for a
# Duplication of Awareness matrix to make sense.
DOA_MIN_BRANDS <- 2L

# Minimum weighted "n aware" required for a row to be reported without a
# low-base flag. Rows below this still appear in the matrix but are flagged
# in the payload (low_base_brands).
DOA_ROW_LOW_BASE <- 30L


# ==============================================================================
# PUBLIC ENTRY
# ==============================================================================

#' Compute Duplication of Awareness for every category
#'
#' Walks the categories sheet and, for each measured category, computes the
#' Duplication of Awareness matrices on the category-buyer base. Mirrors the
#' shape of \code{compute_constellations_per_cat()} so the Portfolio panel
#' can drive both views from the same category-chip event.
#'
#' @param data Data frame of survey responses.
#' @param role_map Named list from \code{build_brand_role_map()} or NULL.
#' @param categories Data frame with \code{Category} + \code{CategoryCode}.
#' @param structure List from a Survey_Structure loader (must contain
#'   \code{brands}).
#' @param config List with portfolio settings (\code{focal_brand},
#'   \code{portfolio_timeframe}, \code{portfolio_min_base}).
#' @param weights Numeric vector or NULL.
#'
#' @return List with structure:
#'   \item{status}{"PASS" if at least one category produced a matrix; "REFUSED"
#'     if no category qualifies.}
#'   \item{by_cat}{Named list of per-category payloads (see
#'     \code{.compute_dop_aware_for_cat}). Keyed by CategoryCode.}
#'   \item{cat_order}{Character vector of category codes ordered by base size
#'     descending.}
#'   \item{cat_names}{Named list mapping CategoryCode to display Category.}
#'   \item{suppressed_cats}{Data frame: \code{cat}, \code{reason}.}
#'   \item{meta}{List with \code{method} description.}
#'
#' @export
compute_dop_awareness_per_cat <- function(data, role_map, categories,
                                          structure, config, weights = NULL) {
  guard <- .dop_aware_guard_inputs(categories, structure)
  if (identical(guard$status, "REFUSED")) return(guard)

  timeframe <- config$portfolio_timeframe %||% "3m"
  min_base  <- config$portfolio_min_base  %||% 30L
  n_total   <- nrow(data)
  w         <- if (!is.null(weights)) weights else rep(1.0, n_total)

  by_cat       <- list()
  cat_codes_ok <- character(0)
  cat_n        <- integer(0)
  cat_name_map <- list()
  suppressed   <- list()

  for (i in seq_len(nrow(categories))) {
    cat_name <- as.character(categories$Category[i])
    cat_code <- as.character(categories$CategoryCode[i])
    if (is.na(cat_code) || !nzchar(cat_code)) next

    res <- .dop_aware_process_one_cat(
      data = data, role_map = role_map, structure = structure,
      cat_name = cat_name, cat_code = cat_code,
      timeframe = timeframe, weights = w, min_base = min_base
    )

    if (!is.null(res$suppressed)) {
      suppressed[[length(suppressed) + 1L]] <- res$suppressed
      next
    }
    by_cat[[cat_code]]       <- res$payload
    cat_codes_ok             <- c(cat_codes_ok, cat_code)
    cat_n                    <- c(cat_n, res$n_uw)
    cat_name_map[[cat_code]] <- cat_name
  }

  suppressed_df <- if (length(suppressed) > 0L) {
    do.call(rbind, lapply(suppressed, as.data.frame, stringsAsFactors = FALSE))
  } else {
    data.frame(cat = character(0), reason = character(0),
               stringsAsFactors = FALSE)
  }

  if (length(cat_codes_ok) == 0L) {
    cat("\n=== TURAS BRAND WARNING ===\n")
    cat("Context: compute_dop_awareness_per_cat()\n")
    cat("Code: CALC_DOA_NO_CATS\n")
    cat("Message: No category produced a Duplication of Awareness matrix\n")
    cat("How to fix: lower portfolio_min_base or verify awareness columns load\n")
    cat("===========================\n")
    return(list(
      status          = "REFUSED",
      code            = "CALC_DOA_NO_CATS",
      message         = "No category qualified for a Duplication of Awareness matrix",
      how_to_fix      = "Lower portfolio_min_base or verify awareness columns load correctly",
      suppressed_cats = suppressed_df
    ))
  }

  ord <- order(cat_n, decreasing = TRUE)
  list(
    status          = "PASS",
    by_cat          = by_cat[cat_codes_ok[ord]],
    cat_order       = cat_codes_ok[ord],
    cat_names       = cat_name_map[cat_codes_ok[ord]],
    suppressed_cats = suppressed_df,
    meta            = list(
      method = "Sharp / Ehrenberg D-law applied to awareness penetration"
    )
  )
}


# ==============================================================================
# INPUT GUARD
# ==============================================================================

#' Validate inputs shared across all per-category DoA computes.
#'
#' Returns a TRS refusal if the categories sheet has no CategoryCode column,
#' or the structure has no brand list. Returns \code{list(status="OK")}
#' otherwise.
#'
#' @keywords internal
.dop_aware_guard_inputs <- function(categories, structure) {
  if (!"CategoryCode" %in% names(categories)) {
    return(list(
      status     = "REFUSED",
      code       = "CFG_PORTFOLIO_NO_CATEGORY_CODE",
      message    = "categories sheet must include a CategoryCode column for DoA",
      how_to_fix = "Add CategoryCode column to Brand_Config Categories sheet"
    ))
  }
  brands_df <- structure$brands
  if (is.null(brands_df) || nrow(brands_df) == 0L) {
    return(list(
      status     = "REFUSED",
      code       = "CFG_NO_BRAND_LIST",
      message    = "structure$brands is empty - cannot build DoA matrices",
      how_to_fix = "Populate the Brands sheet in Survey_Structure"
    ))
  }
  list(status = "OK")
}


# ==============================================================================
# PER-CATEGORY DISPATCH HELPER
# ==============================================================================

#' Process one category for Duplication of Awareness
#'
#' Resolves the brand list and category buyer base, builds the awareness
#' matrix and calls the single-cat engine. On any failure returns
#' \code{list(suppressed = list(cat=..., reason=...))} so the orchestrator
#' can accumulate suppression reasons consistently.
#'
#' @keywords internal
.dop_aware_process_one_cat <- function(data, role_map, structure,
                                       cat_name, cat_code, timeframe,
                                       weights, min_base) {
  cat_brands <- tryCatch(
    get_brands_for_category(structure, cat_name, cat_code = cat_code),
    error = function(e) data.frame(BrandCode = character(0))
  )
  if (nrow(cat_brands) == 0L) {
    return(list(suppressed = list(cat = cat_name,
                                  reason = "no brand list defined")))
  }

  base <- build_portfolio_base(data, cat_code, timeframe, weights)
  if (!is.null(base$status)) {
    return(list(suppressed = list(
      cat = cat_code, reason = base$message %||% "screener missing")))
  }
  if (base$n_uw == 0L) {
    return(list(suppressed = list(cat = cat_code, reason = "no qualifiers")))
  }
  if (base$n_uw < min_base) {
    return(list(suppressed = list(
      cat = cat_code,
      reason = sprintf("low base (n=%d < %d)", base$n_uw, min_base))))
  }

  brand_codes <- as.character(cat_brands$BrandCode)
  brand_lbls  <- if ("BrandLabel" %in% names(cat_brands))
                   as.character(cat_brands$BrandLabel)
                 else if ("BrandName" %in% names(cat_brands))
                   as.character(cat_brands$BrandName)
                 else brand_codes
  names(brand_lbls) <- brand_codes

  am <- .portfolio_aware_matrix(data, role_map, cat_code, brand_codes)
  payload <- .compute_dop_aware_for_cat(
    am = am, brand_codes = brand_codes, brand_lbls = brand_lbls,
    base_idx = base$idx, weights = weights,
    cat_code = cat_code, cat_label = cat_name
  )

  if (identical(payload$status, "REFUSED")) {
    return(list(suppressed = list(
      cat = cat_code, reason = payload$message %||% "too sparse")))
  }

  list(payload = payload, n_uw = base$n_uw)
}


# ==============================================================================
# SINGLE-CATEGORY ENGINE
# ==============================================================================

#' Compute Duplication of Awareness for one category
#'
#' Pure engine. Given the brand x respondent awareness matrix and a
#' category-buyer base index, returns observed / expected / deviation matrices
#' plus Sharp's D coefficient.
#'
#' @param am Integer matrix \code{[nrow(data) x n_brands]} from
#'   \code{.portfolio_aware_matrix()}.
#' @param brand_codes Character vector of brand codes (matrix column order).
#' @param brand_lbls Named character vector of brand display labels.
#' @param base_idx Integer vector — row indices of category buyers.
#' @param weights Numeric vector — full-length weights.
#' @param cat_code Character — category code (for the payload).
#' @param cat_label Character — category display label.
#'
#' @return List: per-category DoA payload. See top-of-file documentation.
#' @keywords internal
.compute_dop_aware_for_cat <- function(am, brand_codes, brand_lbls, base_idx,
                                       weights, cat_code, cat_label) {
  if (is.null(am) || nrow(am) == 0L || length(brand_codes) == 0L) {
    return(list(status = "REFUSED",
                message = "no awareness matrix",
                code = "CALC_DOA_NO_MATRIX"))
  }

  am_buyers <- am[base_idx, , drop = FALSE]
  w_buyers  <- weights[base_idx]
  sum_w     <- sum(w_buyers, na.rm = TRUE)
  if (!is.finite(sum_w) || sum_w <= 0) {
    return(list(status = "REFUSED",
                message = "zero weighted base",
                code = "CALC_DOA_ZERO_BASE"))
  }

  awareness <- .doa_brand_awareness(am_buyers, w_buyers, sum_w, brand_codes)
  aware_pcts <- awareness$pcts
  n_aware_w  <- awareness$n_w
  n_aware_uw <- awareness$n_uw

  present <- brand_codes[aware_pcts > 0]
  if (length(present) < DOA_MIN_BRANDS) {
    return(list(status = "REFUSED",
                code = "CALC_DOA_TOO_SPARSE",
                message = sprintf(
                  "only %d brand(s) with non-zero awareness in %s",
                  length(present), cat_code)))
  }

  obs_mat <- .doa_observed_matrix(am_buyers, brand_codes, w_buyers)
  D       <- .doa_sharp_coefficient(obs_mat, aware_pcts, brand_codes)
  exp_mat <- .doa_expected_matrix(D, aware_pcts, brand_codes)
  dev_mat <- .doa_deviation_matrix(obs_mat, exp_mat, brand_codes)

  low_base_brands <- brand_codes[n_aware_w < DOA_ROW_LOW_BASE]

  list(
    status         = "PASS",
    cat_code       = cat_code,
    cat_label      = cat_label,
    brand_codes    = brand_codes,
    brand_lbls     = brand_lbls,
    aware_pcts     = aware_pcts,
    n_aware_w      = n_aware_w,
    n_aware_uw     = n_aware_uw,
    D              = D,
    observed_matrix  = obs_mat,
    expected_matrix  = exp_mat,
    deviation_matrix = dev_mat,
    low_base_brands  = low_base_brands,
    n_buyers_uw      = length(base_idx),
    n_buyers_w       = sum_w
  )
}


# ==============================================================================
# AWARENESS VECTORS HELPER
# ==============================================================================

#' Per-brand awareness penetration plus base counts
#'
#' @return Named list with three named numeric/integer vectors over
#'   \code{brand_codes}: \code{pcts} (\%), \code{n_w} (weighted aware count),
#'   \code{n_uw} (unweighted aware count).
#' @keywords internal
.doa_brand_awareness <- function(am_buyers, w_buyers, sum_w, brand_codes) {
  n_w <- vapply(brand_codes, function(bc) {
    sum(w_buyers * am_buyers[, bc], na.rm = TRUE)
  }, numeric(1))
  n_uw <- vapply(brand_codes, function(bc) {
    sum(am_buyers[, bc] == 1, na.rm = TRUE)
  }, integer(1))
  pcts <- n_w / sum_w * 100
  names(n_w) <- names(n_uw) <- names(pcts) <- brand_codes
  list(pcts = pcts, n_w = n_w, n_uw = n_uw)
}


# ==============================================================================
# MATRIX BUILDERS
# ==============================================================================

#' Build observed Duplication of Awareness matrix
#'
#' @keywords internal
.doa_observed_matrix <- function(am_buyers, brand_codes, w_buyers) {
  n <- length(brand_codes)
  obs <- matrix(NA_real_, n, n, dimnames = list(brand_codes, brand_codes))
  for (i in seq_len(n)) {
    awi      <- am_buyers[, i] == 1
    wi_total <- sum(w_buyers[awi], na.rm = TRUE)
    if (!is.finite(wi_total) || wi_total <= 0) next
    for (j in seq_len(n)) {
      if (i == j) { obs[i, j] <- 100; next }
      both <- awi & (am_buyers[, j] == 1)
      obs[i, j] <- round(
        sum(w_buyers[both], na.rm = TRUE) / wi_total * 100, 1)
    }
  }
  obs
}


#' Compute Sharp's D coefficient over off-diagonal cells
#'
#' No-intercept OLS: D = Sigma(obs * a) / Sigma(a^2).
#'
#' @keywords internal
.doa_sharp_coefficient <- function(obs_mat, aware_pcts, brand_codes) {
  n <- length(brand_codes)
  obs_off <- numeric(0)
  aw_off  <- numeric(0)
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (i == j) next
      v <- obs_mat[i, j]
      if (is.na(v)) next
      obs_off <- c(obs_off, v)
      aw_off  <- c(aw_off,  aware_pcts[j])
    }
  }
  if (length(obs_off) < 2L || sum(aw_off^2) <= 0) return(NA_real_)
  sum(obs_off * aw_off) / sum(aw_off^2)
}


#' Build expected matrix (D * a_j) on off-diagonal cells.
#'
#' @keywords internal
.doa_expected_matrix <- function(D, aware_pcts, brand_codes) {
  n <- length(brand_codes)
  exp_mat <- matrix(NA_real_, n, n, dimnames = list(brand_codes, brand_codes))
  if (is.na(D)) return(exp_mat)
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (i == j) next
      exp_mat[i, j] <- round(D * aware_pcts[j], 1)
    }
  }
  exp_mat
}


#' Build deviation matrix (observed - expected) on off-diagonal cells.
#'
#' Values are percentage points. NA when either observed or expected is NA.
#'
#' @keywords internal
.doa_deviation_matrix <- function(obs_mat, exp_mat, brand_codes) {
  n <- length(brand_codes)
  dev_mat <- matrix(NA_real_, n, n, dimnames = list(brand_codes, brand_codes))
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (i == j) next
      o <- obs_mat[i, j]
      e <- exp_mat[i, j]
      if (!is.na(o) && !is.na(e)) dev_mat[i, j] <- round(o - e, 1)
    }
  }
  dev_mat
}
