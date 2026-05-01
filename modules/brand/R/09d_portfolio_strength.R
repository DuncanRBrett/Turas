# ==============================================================================
# BRAND MODULE - PORTFOLIO STRENGTH MAP (§4.4)
# ==============================================================================
# For each brand present in ≥1 category, produces a per-category data frame:
#   cat_pen     = category penetration in total sample
#   brand_aware = A(brand, cat) — awareness among category buyers (0-100)
#   aware_n_w   = weighted count of aware buyers
#
# Denominator: build_portfolio_base() per §3.1 — never inline SQ1_/SQ2_.
# Relies on .compute_category_awareness() from 09a_portfolio_footprint.R.
# ==============================================================================


# ==============================================================================
# V2: SLOT-INDEXED STRENGTH MAP
# ==============================================================================

#' Compute portfolio strength map data (v2 — slot-indexed)
#'
#' v2 alternative to \code{compute_strength_map()} that uses the slot-indexed
#' data-access layer. Iterates \code{categories$CategoryCode} directly;
#' awareness from \code{.portfolio_aware_matrix_v2()}.
#'
#' @param data Data frame.
#' @param role_map Named list from \code{build_brand_role_map()} or NULL.
#' @param categories Data frame with \code{Category} + \code{CategoryCode}.
#' @param structure List from a Survey_Structure loader.
#' @param config List with \code{portfolio_timeframe}, \code{portfolio_min_base}.
#' @param weights Numeric vector or NULL.
#' @return Same list shape as \code{compute_strength_map()}.
#' @export
compute_strength_map_v2 <- function(data, role_map, categories, structure,
                                     config, weights = NULL) {
  timeframe <- config$portfolio_timeframe %||% "3m"
  min_base  <- config$portfolio_min_base  %||% 30L
  n_total   <- nrow(data)
  w         <- if (!is.null(weights)) weights else rep(1.0, n_total)

  if (!"CategoryCode" %in% names(categories)) {
    return(list(status = "REFUSED",
                code = "CFG_PORTFOLIO_NO_CATEGORY_CODE",
                message = "categories sheet must include a CategoryCode column for v2 portfolio analyses",
                how_to_fix = "Add CategoryCode column to Brand_Config Categories sheet"))
  }

  brand_cat_rows <- list()
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
    if (nrow(cat_brands) == 0L) next

    base <- build_portfolio_base_v2(data, cat_code, timeframe, weights)
    if (!is.null(base$status)) next
    if (base$n_uw == 0L) { suppressed <- c(suppressed, cat_code); next }
    if (base$n_uw < min_base) { suppressed <- c(suppressed, cat_code); next }

    cat_name_map[[cat_code]] <- cat_name

    brand_codes <- as.character(cat_brands$BrandCode)
    brand_lbls  <- if ("BrandLabel" %in% names(cat_brands))
                     as.character(cat_brands$BrandLabel)
                   else if ("BrandName" %in% names(cat_brands))
                     as.character(cat_brands$BrandName)
                   else brand_codes
    names(brand_lbls) <- brand_codes

    aware_mat <- .portfolio_aware_matrix_v2(data, role_map, cat_code,
                                            brand_codes)
    awareness <- .compute_brand_awareness_pct_v2(aware_mat, base$idx,
                                                 weights)
    cat_pen   <- base$n_uw / n_total

    for (bc in brand_codes) {
      aw_val <- awareness[[bc]]
      if (is.na(aw_val)) next

      # Weighted aware-buyer count from the matrix (no column lookup needed)
      aware_n_w <- sum(w[base$idx] * aware_mat[base$idx, bc], na.rm = TRUE)

      if (!bc %in% names(brand_cat_rows)) brand_cat_rows[[bc]] <- list()
      brand_cat_rows[[bc]][[cat_code]] <- list(
        cat         = cat_code,
        cat_label   = cat_name,
        cat_pen     = cat_pen,
        brand_aware = aw_val,
        aware_n_w   = aware_n_w
      )
      if (!nzchar(brand_name_map[[bc]] %||% "") && nzchar(brand_lbls[[bc]] %||% "")) {
        brand_name_map[[bc]] <- as.character(brand_lbls[[bc]])
      }
    }
  }

  if (length(brand_cat_rows) == 0L) {
    return(list(status = "PASS", per_brand = list(),
                cat_names = list(), brand_names = list(),
                suppressed_cats = suppressed))
  }

  per_brand <- lapply(names(brand_cat_rows), function(bc) {
    rows <- brand_cat_rows[[bc]]
    if (length(rows) == 0L) return(NULL)
    do.call(rbind, lapply(rows, function(r) {
      data.frame(cat = r$cat, cat_label = r$cat_label,
                 cat_pen = r$cat_pen,
                 brand_aware = r$brand_aware, aware_n_w = r$aware_n_w,
                 stringsAsFactors = FALSE)
    }))
  })
  names(per_brand) <- names(brand_cat_rows)
  per_brand <- Filter(function(df) !is.null(df) && nrow(df) >= 1L, per_brand)

  for (bc in names(per_brand)) {
    if (!nzchar(brand_name_map[[bc]] %||% "")) brand_name_map[[bc]] <- bc
  }

  list(status = "PASS",
       per_brand = per_brand,
       cat_names = cat_name_map,
       brand_names = brand_name_map,
       suppressed_cats = suppressed)
}
