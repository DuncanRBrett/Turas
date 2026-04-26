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


#' Compute portfolio strength map data
#'
#' For each brand present in at least one qualifying category, produces a
#' per-category data frame suitable for the bubble-scatter strength chart
#' (§4.4 of spec). The focal brand is always included if it is present.
#'
#' Strength map axes:
#' \itemize{
#'   \item x = category penetration (n_buyers_uw / n_total)
#'   \item y = brand awareness among category buyers (\code{A(brand, cat)}, 0–100)
#'   \item bubble size = weighted aware-buyer count
#' }
#'
#' @param data Data frame. Full survey data.
#' @param categories Data frame. Categories sheet.
#' @param structure List. Loaded survey structure.
#' @param config List. Loaded brand config.
#' @param weights Numeric vector or NULL. Survey weights.
#'
#' @return List:
#'   \item{status}{"PASS"}
#'   \item{per_brand}{Named list. Each element is a data frame with columns:
#'     cat, cat_pen, brand_aware, aware_n_w.}
#'   \item{suppressed_cats}{Character. Category codes below min_base.}
#'
#' @export
compute_strength_map <- function(data, categories, structure,
                                 config, weights = NULL) {
  focal_brand <- config$focal_brand %||% ""
  timeframe   <- config$portfolio_timeframe %||% "3m"
  min_base    <- config$portfolio_min_base  %||% 30L
  n_total     <- nrow(data)
  w           <- if (!is.null(weights)) weights else rep(1.0, n_total)

  brand_cat_rows <- list()
  cat_name_map   <- list()  # cat_code → display label
  brand_name_map <- list()  # brand_code → display label
  suppressed     <- character(0)

  detector <- if (exists(".po_detect_cat_code", mode = "function"))
                .po_detect_cat_code else .detect_category_code

  for (i in seq_len(nrow(categories))) {
    cat_name   <- categories$Category[i]
    cat_brands <- tryCatch(
      get_brands_for_category(structure, cat_name),
      error = function(e) data.frame(BrandCode = character(0))
    )
    if (nrow(cat_brands) == 0) next

    cat_code <- if (!is.null(structure$questionmap) &&
                    nrow(structure$questionmap) > 0)
      detector(structure$questionmap, cat_brands, data) else NULL
    if (is.null(cat_code)) next

    base <- build_portfolio_base(data, cat_code, timeframe, weights)
    if (!is.null(base$status)) next

    if (base$n_uw < min_base) {
      suppressed <- c(suppressed, cat_code)
      next
    }

    cat_name_map[[cat_code]] <- as.character(cat_name)

    brand_codes <- as.character(cat_brands$BrandCode)
    brand_lbls  <- if ("BrandLabel" %in% names(cat_brands))
                     as.character(cat_brands$BrandLabel)
                   else if ("BrandName" %in% names(cat_brands))
                     as.character(cat_brands$BrandName)
                   else brand_codes
    names(brand_lbls) <- brand_codes
    cat_pen     <- base$n_uw / n_total
    awareness   <- .compute_category_awareness(data, cat_code, brand_codes,
                                               base$idx, weights)

    for (bc in brand_codes) {
      aw_val <- awareness[[bc]]
      if (is.na(aw_val)) next

      aw_col    <- paste0("BRANDAWARE_", cat_code, "_", bc)
      aware_n_w <- if (aw_col %in% names(data)) {
        vals <- as.integer(!is.na(data[[aw_col]]) & data[[aw_col]] == 1L)
        sum(w[base$idx] * vals[base$idx], na.rm = TRUE)
      } else 0

      if (!bc %in% names(brand_cat_rows)) brand_cat_rows[[bc]] <- list()
      brand_cat_rows[[bc]][[cat_code]] <- list(
        cat         = cat_code,
        cat_label   = as.character(cat_name),
        cat_pen     = cat_pen,
        brand_aware = aw_val,
        aware_n_w   = aware_n_w
      )
      if (!nzchar(brand_name_map[[bc]] %||% "") && nzchar(brand_lbls[[bc]] %||% ""))
        brand_name_map[[bc]] <- as.character(brand_lbls[[bc]])
    }
  }

  if (length(brand_cat_rows) == 0) {
    return(list(status = "PASS", per_brand = list(),
                cat_names = list(), brand_names = list(),
                suppressed_cats = suppressed))
  }

  per_brand <- lapply(names(brand_cat_rows), function(bc) {
    rows <- brand_cat_rows[[bc]]
    if (length(rows) == 0) return(NULL)
    do.call(rbind, lapply(rows, function(r) {
      data.frame(cat = r$cat, cat_label = r$cat_label,
                 cat_pen = r$cat_pen,
                 brand_aware = r$brand_aware, aware_n_w = r$aware_n_w,
                 stringsAsFactors = FALSE)
    }))
  })
  names(per_brand) <- names(brand_cat_rows)
  per_brand <- Filter(function(df) !is.null(df) && nrow(df) >= 1, per_brand)

  # Fill any missing brand label with the brand code so downstream code
  # always has a label to display.
  for (bc in names(per_brand)) {
    if (!nzchar(brand_name_map[[bc]] %||% "")) brand_name_map[[bc]] <- bc
  }

  list(status = "PASS",
       per_brand = per_brand,
       cat_names = cat_name_map,
       brand_names = brand_name_map,
       suppressed_cats = suppressed)
}
