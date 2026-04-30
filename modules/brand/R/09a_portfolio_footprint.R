# ==============================================================================
# BRAND MODULE - PORTFOLIO FOOTPRINT MATRIX (§4.1)
# ==============================================================================
# Computes A(b, c) = weighted awareness % among category buyers for every
# brand × category pair.
#
# Denominator: build_portfolio_base() per §3.1 — never inline SQ1_/SQ2_.
# ==============================================================================


#' Compute weighted awareness for one category (pure, no side-effects)
#'
#' For a single category identified by \code{cat_code}, returns the weighted
#' awareness percentage for each brand code supplied. Brands whose awareness
#' column is absent in the data return \code{NA} — not zero — because
#' \emph{not asked ≠ not aware}.
#'
#' @param data Data frame. Full survey data.
#' @param cat_code Character. Category code, e.g. "DSS".
#' @param brand_codes Character vector. Brand codes to compute awareness for.
#' @param base_idx Logical vector. Qualifier flags from build_portfolio_base().
#' @param weights Numeric vector or NULL. Survey weights.
#'
#' @return Named numeric vector, one value per brand (0–100 scale or NA).
#' @keywords internal
.compute_category_awareness <- function(data, cat_code, brand_codes,
                                        base_idx, weights) {
  w <- if (!is.null(weights)) weights else rep(1.0, nrow(data))
  denom <- sum(w[base_idx], na.rm = TRUE)

  vapply(brand_codes, function(bc) {
    aw_col <- paste0("BRANDAWARE_", cat_code, "_", bc)
    if (!aw_col %in% names(data)) return(NA_real_)
    vals <- as.integer(!is.na(data[[aw_col]]) & data[[aw_col]] == 1L)
    if (denom <= 0) return(NA_real_)
    sum(w[base_idx] * vals[base_idx], na.rm = TRUE) / denom * 100
  }, numeric(1))
}


#' Compute portfolio footprint matrix
#'
#' Produces the brand × category awareness matrix for §4.1 of the portfolio
#' spec. Every cell is \code{A(b, c)} = weighted % of category buyers aware
#' of brand \code{b} in category \code{c}. Cells are \code{NA} when the brand
#' is absent from a category's QuestionMap (not asked ≠ not aware).
#'
#' Categories below \code{config$portfolio_min_base} unweighted buyers are
#' suppressed (excluded from matrix, recorded in \code{suppressed_cats}).
#'
#' @param data Data frame. Full survey data.
#' @param categories Data frame. Categories sheet.
#' @param structure List. Loaded survey structure.
#' @param config List. Loaded brand config.
#' @param weights Numeric vector or NULL. Survey weights.
#'
#' @return List:
#'   \item{status}{"PASS"}
#'   \item{matrix_df}{Data frame: Brand column + one column per category.
#'     Values are awareness % (0–100). Rows sorted by total footprint
#'     descending. Columns sorted by category buyer size descending.
#'     All categories from the config are included — categories whose
#'     unweighted base falls below \code{config$portfolio_min_base} are
#'     also recorded in \code{suppressed_cats} so the renderer can flag
#'     them, but their column is still emitted (with the awareness
#'     values that were observed, even if at low base).}
#'   \item{bases_df}{Data frame: cat, n_buyers_uw, n_buyers_w.}
#'   \item{cat_names}{Named character vector: cat_code -> human display name.}
#'   \item{brand_names}{Named character vector: brand_code -> display name,
#'     unioned across all categories.}
#'   \item{suppressed_cats}{Character. Category codes below min_base.}
#'
#' @export
compute_footprint_matrix <- function(data, categories, structure,
                                     config, weights = NULL) {
  timeframe <- config$portfolio_timeframe %||% "3m"
  min_base  <- config$portfolio_min_base  %||% 30L

  brand_rows     <- list()
  cat_codes      <- character(0)
  cat_n_buyers   <- integer(0)
  bases_list     <- list()
  # name maps are lists so `[[code]]` returns NULL (not error) for missing keys
  cat_name_map   <- list()
  brand_name_map <- list()
  suppressed     <- character(0)

  for (i in seq_len(nrow(categories))) {
    cat_name   <- categories$Category[i]
    cat_brands <- tryCatch(
      get_brands_for_category(structure, cat_name),
      error = function(e) data.frame(BrandCode = character(0))
    )

    # Use the broader detector (also matches cross_cat.awareness.<CC>) so
    # awareness-only / non-key categories resolve a code instead of being
    # silently dropped. Falls back to the funnel-only detector when the
    # overview helper isn't in scope.
    cat_code <- if (!is.null(structure$questionmap) &&
                    nrow(structure$questionmap) > 0) {
      detector <- if (exists(".po_detect_cat_code", mode = "function"))
                    .po_detect_cat_code else .detect_category_code
      detector(structure$questionmap, cat_brands, data)
    } else NULL
    if (is.null(cat_code)) next

    base <- build_portfolio_base(data, cat_code, timeframe, weights)
    if (!is.null(base$status)) next

    is_low_base <- base$n_uw < min_base
    if (is_low_base) suppressed <- c(suppressed, cat_code)

    # Include every category whose screener column resolved, regardless of
    # min_base or whether brands are declared in the structure. Low-base
    # cats are still flagged in `suppressed_cats` so the renderer can mark
    # them; non-key cats with no brand list contribute an all-NA column,
    # which is the right semantic ("not measured" — see panel about-text).
    cat_codes    <- c(cat_codes, cat_code)
    cat_n_buyers <- c(cat_n_buyers, base$n_uw)
    bases_list[[cat_code]] <- list(n_buyers_uw = base$n_uw, n_buyers_w = base$n_w)
    cat_name_map[[cat_code]] <- as.character(cat_name)

    if (nrow(cat_brands) > 0) {
      brand_codes <- as.character(cat_brands$BrandCode)
      brand_lbls  <- if ("BrandLabel" %in% names(cat_brands))
                       as.character(cat_brands$BrandLabel)
                     else if ("BrandName" %in% names(cat_brands))
                       as.character(cat_brands$BrandName)
                     else brand_codes
      awareness   <- .compute_category_awareness(data, cat_code, brand_codes,
                                                 base$idx, weights)
      for (bi in seq_along(brand_codes)) {
        bc <- brand_codes[bi]
        if (!bc %in% names(brand_rows)) brand_rows[[bc]] <- list()
        brand_rows[[bc]][[cat_code]] <- awareness[bi]
        # First-seen wins for the global brand name lookup; subsequent
        # categories with a different label do not override an earlier
        # populated value.
        if (!nzchar(brand_name_map[[bc]] %||% "") && nzchar(brand_lbls[bi]))
          brand_name_map[[bc]] <- brand_lbls[bi]
      }
    }
  }

  if (length(cat_codes) == 0 || length(brand_rows) == 0) {
    return(list(
      status          = "PASS",
      matrix_df       = data.frame(),
      bases_df        = data.frame(),
      cat_names       = list(),
      brand_names     = list(),
      suppressed_cats = suppressed
    ))
  }

  all_brands <- names(brand_rows)
  mat <- matrix(NA_real_, nrow = length(all_brands), ncol = length(cat_codes),
                dimnames = list(all_brands, cat_codes))
  for (bc in all_brands) {
    for (cc in cat_codes) {
      v <- brand_rows[[bc]][[cc]]
      if (!is.null(v)) mat[bc, cc] <- v
    }
  }

  col_order <- order(cat_n_buyers, decreasing = TRUE)
  mat       <- mat[, col_order, drop = FALSE]

  row_sums  <- rowSums(mat, na.rm = TRUE)
  mat       <- mat[order(row_sums, decreasing = TRUE), , drop = FALSE]

  matrix_df <- data.frame(Brand = rownames(mat), as.data.frame(mat),
                           stringsAsFactors = FALSE, check.names = FALSE)
  rownames(matrix_df) <- NULL

  ord_cats  <- cat_codes[col_order]
  bases_df  <- data.frame(
    cat         = ord_cats,
    n_buyers_uw = vapply(ord_cats, function(cc) bases_list[[cc]]$n_buyers_uw, integer(1)),
    n_buyers_w  = vapply(ord_cats, function(cc) bases_list[[cc]]$n_buyers_w,  numeric(1)),
    stringsAsFactors = FALSE
  )

  # Fill any missing brand label with the brand code.
  for (bc in all_brands) {
    if (!nzchar(brand_name_map[[bc]] %||% "")) brand_name_map[[bc]] <- bc
  }

  list(
    status          = "PASS",
    matrix_df       = matrix_df,
    bases_df        = bases_df,
    cat_names       = cat_name_map[ord_cats],
    brand_names     = brand_name_map[rownames(mat)],
    suppressed_cats = suppressed
  )
}


# ==============================================================================
# V2: SLOT-INDEXED FOOTPRINT MATRIX
# ==============================================================================

#' Compute weighted awareness % from a 0/1 awareness matrix (v2)
#'
#' Pure helper. Computes weighted awareness % for each brand column in
#' \code{aware_mat} restricted to qualifier respondents. Returns named numeric
#' vector (0-100). Empty matrix or zero base => all NA.
#'
#' @param aware_mat Integer matrix \code{[nrow(data) x n_brands]} with brand
#'   codes as colnames. 1 = aware.
#' @param base_idx Logical vector. Qualifier flags from
#'   \code{build_portfolio_base_v2()}.
#' @param weights Numeric vector or NULL.
#' @return Named numeric vector, length \code{ncol(aware_mat)}.
#' @keywords internal
.compute_brand_awareness_pct_v2 <- function(aware_mat, base_idx, weights) {
  brand_codes <- colnames(aware_mat) %||% character(0)
  if (length(brand_codes) == 0L) return(setNames(numeric(0), character(0)))

  w     <- if (!is.null(weights)) weights else rep(1.0, nrow(aware_mat))
  denom <- sum(w[base_idx], na.rm = TRUE)
  if (denom <= 0) {
    return(setNames(rep(NA_real_, length(brand_codes)), brand_codes))
  }
  vapply(brand_codes, function(bc) {
    sum(w[base_idx] * aware_mat[base_idx, bc], na.rm = TRUE) / denom * 100
  }, numeric(1))
}


#' Compute portfolio footprint matrix (v2 — slot-indexed)
#'
#' v2 alternative to \code{compute_footprint_matrix()} that uses the
#' slot-indexed data-access layer. The \code{categories} data frame must
#' carry a \code{CategoryCode} column (per the new Brand_Config schema) so
#' the helper does not need to detect category codes from question patterns.
#'
#' Returns the same shape as the legacy entry. Categories whose unweighted
#' base falls below \code{config$portfolio_min_base} are still emitted in
#' the matrix (for transparency) and recorded in \code{suppressed_cats}.
#'
#' @param data Data frame.
#' @param role_map Named list from \code{build_brand_role_map()} or NULL.
#' @param categories Data frame. Must have \code{Category} (label) +
#'   \code{CategoryCode} (data code).
#' @param structure List from a Survey_Structure loader.
#' @param config List. Must carry \code{portfolio_timeframe},
#'   \code{portfolio_min_base}.
#' @param weights Numeric vector or NULL.
#' @return Same list shape as \code{compute_footprint_matrix()}.
#' @export
compute_footprint_matrix_v2 <- function(data, role_map, categories, structure,
                                         config, weights = NULL) {
  timeframe <- config$portfolio_timeframe %||% "3m"
  min_base  <- config$portfolio_min_base  %||% 30L

  if (!"CategoryCode" %in% names(categories)) {
    return(list(status = "REFUSED",
                code = "CFG_PORTFOLIO_NO_CATEGORY_CODE",
                message = "categories sheet must include a CategoryCode column for v2 portfolio analyses",
                how_to_fix = "Add CategoryCode column to Brand_Config Categories sheet"))
  }

  brand_rows     <- list()
  cat_codes      <- character(0)
  cat_n_buyers   <- integer(0)
  bases_list     <- list()
  cat_name_map   <- list()
  brand_name_map <- list()
  suppressed     <- character(0)

  for (i in seq_len(nrow(categories))) {
    cat_name <- as.character(categories$Category[i])
    cat_code <- as.character(categories$CategoryCode[i])
    if (is.na(cat_code) || !nzchar(cat_code)) next

    cat_brands <- tryCatch(
      get_brands_for_category(structure, cat_name),
      error = function(e) data.frame(BrandCode = character(0))
    )

    base <- build_portfolio_base_v2(data, cat_code, timeframe, weights)
    if (!is.null(base$status)) next

    # Categories with zero qualifiers carry no information for the matrix
    # (denominator would be 0). Record them in suppressed_cats so the
    # renderer can show a "no qualifiers" placeholder and skip the column.
    if (base$n_uw == 0L) {
      suppressed <- c(suppressed, cat_code)
      next
    }

    if (base$n_uw < min_base) suppressed <- c(suppressed, cat_code)

    cat_codes    <- c(cat_codes, cat_code)
    cat_n_buyers <- c(cat_n_buyers, base$n_uw)
    bases_list[[cat_code]]   <- list(n_buyers_uw = base$n_uw,
                                     n_buyers_w  = base$n_w)
    cat_name_map[[cat_code]] <- cat_name

    if (nrow(cat_brands) > 0L) {
      brand_codes <- as.character(cat_brands$BrandCode)
      brand_lbls  <- if ("BrandLabel" %in% names(cat_brands))
                       as.character(cat_brands$BrandLabel)
                     else if ("BrandName" %in% names(cat_brands))
                       as.character(cat_brands$BrandName)
                     else brand_codes

      aware_mat <- .portfolio_aware_matrix_v2(data, role_map, cat_code,
                                              brand_codes)
      awareness <- .compute_brand_awareness_pct_v2(aware_mat, base$idx,
                                                   weights)

      for (bi in seq_along(brand_codes)) {
        bc <- brand_codes[bi]
        if (!bc %in% names(brand_rows)) brand_rows[[bc]] <- list()
        brand_rows[[bc]][[cat_code]] <- awareness[[bc]]
        if (!nzchar(brand_name_map[[bc]] %||% "") && nzchar(brand_lbls[bi])) {
          brand_name_map[[bc]] <- brand_lbls[bi]
        }
      }
    }
  }

  if (length(cat_codes) == 0L || length(brand_rows) == 0L) {
    return(list(
      status          = "PASS",
      matrix_df       = data.frame(),
      bases_df        = data.frame(),
      cat_names       = list(),
      brand_names     = list(),
      suppressed_cats = suppressed
    ))
  }

  all_brands <- names(brand_rows)
  mat <- matrix(NA_real_, nrow = length(all_brands), ncol = length(cat_codes),
                dimnames = list(all_brands, cat_codes))
  for (bc in all_brands) {
    for (cc in cat_codes) {
      v <- brand_rows[[bc]][[cc]]
      if (!is.null(v)) mat[bc, cc] <- v
    }
  }

  col_order <- order(cat_n_buyers, decreasing = TRUE)
  mat       <- mat[, col_order, drop = FALSE]
  row_sums  <- rowSums(mat, na.rm = TRUE)
  mat       <- mat[order(row_sums, decreasing = TRUE), , drop = FALSE]

  matrix_df <- data.frame(Brand = rownames(mat), as.data.frame(mat),
                           stringsAsFactors = FALSE, check.names = FALSE)
  rownames(matrix_df) <- NULL

  ord_cats <- cat_codes[col_order]
  bases_df <- data.frame(
    cat         = ord_cats,
    n_buyers_uw = vapply(ord_cats, function(cc) bases_list[[cc]]$n_buyers_uw,
                         integer(1)),
    n_buyers_w  = vapply(ord_cats, function(cc) bases_list[[cc]]$n_buyers_w,
                         numeric(1)),
    stringsAsFactors = FALSE
  )

  for (bc in all_brands) {
    if (!nzchar(brand_name_map[[bc]] %||% "")) brand_name_map[[bc]] <- bc
  }

  list(
    status          = "PASS",
    matrix_df       = matrix_df,
    bases_df        = bases_df,
    cat_names       = cat_name_map[ord_cats],
    brand_names     = brand_name_map[rownames(mat)],
    suppressed_cats = suppressed
  )
}
