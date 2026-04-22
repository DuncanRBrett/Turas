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
#'     descending. Columns sorted by category buyer size descending.}
#'   \item{bases_df}{Data frame: cat, n_buyers_uw, n_buyers_w.}
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
  suppressed     <- character(0)

  for (i in seq_len(nrow(categories))) {
    cat_name   <- categories$Category[i]
    cat_brands <- tryCatch(
      get_brands_for_category(structure, cat_name),
      error = function(e) data.frame(BrandCode = character(0))
    )
    if (nrow(cat_brands) == 0) next

    cat_code <- if (!is.null(structure$questionmap) &&
                    nrow(structure$questionmap) > 0)
      .detect_category_code(structure$questionmap, cat_brands, data)
    else NULL
    if (is.null(cat_code)) next

    base <- build_portfolio_base(data, cat_code, timeframe, weights)
    if (!is.null(base$status)) next

    if (base$n_uw < min_base) {
      suppressed <- c(suppressed, cat_code)
      next
    }

    cat_codes    <- c(cat_codes, cat_code)
    cat_n_buyers <- c(cat_n_buyers, base$n_uw)
    bases_list[[cat_code]] <- list(n_buyers_uw = base$n_uw, n_buyers_w = base$n_w)

    brand_codes <- as.character(cat_brands$BrandCode)
    awareness   <- .compute_category_awareness(data, cat_code, brand_codes,
                                               base$idx, weights)
    for (bi in seq_along(brand_codes)) {
      bc <- brand_codes[bi]
      if (!bc %in% names(brand_rows)) brand_rows[[bc]] <- list()
      brand_rows[[bc]][[cat_code]] <- awareness[bi]
    }
  }

  if (length(cat_codes) == 0 || length(brand_rows) == 0) {
    return(list(
      status          = "PASS",
      matrix_df       = data.frame(),
      bases_df        = data.frame(),
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

  list(
    status          = "PASS",
    matrix_df       = matrix_df,
    bases_df        = bases_df,
    suppressed_cats = suppressed
  )
}
