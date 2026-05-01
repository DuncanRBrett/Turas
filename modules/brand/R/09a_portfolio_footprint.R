# ==============================================================================
# BRAND MODULE - PORTFOLIO FOOTPRINT MATRIX (§4.1)
# ==============================================================================
# Computes A(b, c) = weighted awareness % among category buyers for every
# brand × category pair.
#
# Denominator: build_portfolio_base() per §3.1 — never inline SQ1_/SQ2_.
# ==============================================================================


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
#'   \code{build_portfolio_base()}.
#' @param weights Numeric vector or NULL.
#' @return Named numeric vector, length \code{ncol(aware_mat)}.
#' @keywords internal
.compute_brand_awareness_pct <- function(aware_mat, base_idx, weights) {
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
compute_footprint_matrix <- function(data, role_map, categories, structure,
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

    base <- build_portfolio_base(data, cat_code, timeframe, weights)
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

      aware_mat <- .portfolio_aware_matrix(data, role_map, cat_code,
                                              brand_codes)
      awareness <- .compute_brand_awareness_pct(aware_mat, base$idx,
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
