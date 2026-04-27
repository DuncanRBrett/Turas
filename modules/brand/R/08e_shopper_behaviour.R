# ==============================================================================
# BRAND MODULE - SHOPPER BEHAVIOUR ELEMENT
# ==============================================================================
# Computes purchase channel and pack size distributions per category from
# multi-mention questions:
#   * channel.purchase.{CAT}      -> CHANNEL_{CAT}_{CHANNELCODE}  (Q020)
#   * cat_buying.packsize.{CAT}   -> PACKSIZE_{CAT}_{PACKSIZECODE}
#
# Both questions are multi-mention (a respondent can pick multiple channels
# or pack sizes), so percentages do not sum to 100%. Shares are computed
# over category buyers (for the category-level distribution) and over each
# brand's buyers (for the brand x option matrix).
#
# Brand buyer identity is derived from BRANDPEN3 (target-window purchase
# counts): brand_j is bought by respondent i iff pen_mat[i, j] > 0.
#
# Element is OPTIONAL per category. Absent QuestionMap rows -> the element
# is skipped silently; the panel hides the corresponding sub-section.
#
# VERSION: 1.0
# ==============================================================================

SHOPPER_BEHAVIOUR_VERSION <- "1.0"


# ==============================================================================
# PUBLIC API
# ==============================================================================

#' Compute purchase-channel distribution for one category
#'
#' Treats the channel question as multi-mention binary columns (one per
#' channel option). Computes (a) the category-level share of buyers using
#' each channel, and (b) a brand x channel matrix showing the share of each
#' brand's buyers using each channel.
#'
#' @param channel_data Data frame with one column per channel option. Column
#'   names must match \code{channel_cols}. Cells are 0/1 (multi-mention).
#'   NA is treated as 0.
#' @param channel_cols Character. Vector of column names in \code{channel_data}.
#' @param channel_codes Character. Short codes parallel to \code{channel_cols}
#'   (e.g. "SUPMKT"). Used as Code in the output.
#' @param channel_labels Character. Display labels parallel to
#'   \code{channel_cols} (e.g. "Supermarket"). Used as Label in the output.
#' @param pen_mat Numeric matrix or NULL. Respondents x brands BRANDPEN3
#'   target-window counts (or any matrix where >0 means "this respondent
#'   bought this brand"). Required for the brand-level matrix; if NULL only
#'   the category-level distribution is returned.
#' @param brand_codes Character. Brand codes in column order of \code{pen_mat}.
#' @param weights Numeric or NULL. Respondent weights (length = n respondents).
#'
#' @return List:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{category_distribution}{Data frame Code | Label | Order | n | Pct.
#'     Pct = % of category buyers selecting the channel.}
#'   \item{brand_matrix}{Data frame keyed by BrandCode with Base_n + one
#'     numeric column per channel (Pct_<CODE>). One row per brand plus a
#'     leading row \code{__cat__} for the category average across brands.}
#'   \item{top}{List with code, label, pct of the most-used channel.}
#'   \item{hhi}{Numeric. Sum of squared category shares (0-1). 1 = single
#'     channel, lower = more dispersed. Useful as a concentration KPI.}
#'   \item{n_cat_buyers}{Unweighted count of category buyers used as base.}
#'   \item{n_respondents}{Total rows.}
#'
#' @export
run_shopper_location <- function(channel_data,
                                  channel_cols,
                                  channel_codes,
                                  channel_labels,
                                  pen_mat     = NULL,
                                  brand_codes = NULL,
                                  weights     = NULL) {
  .run_shopper_multimention(
    data_df     = channel_data,
    cols        = channel_cols,
    codes       = channel_codes,
    labels      = channel_labels,
    pen_mat     = pen_mat,
    brand_codes = brand_codes,
    weights     = weights,
    kind        = "location"
  )
}


#' Compute pack-size distribution for one category
#'
#' Same shape as \code{run_shopper_location()}: multi-mention binary input
#' columns, one per pack-size band, producing a category-level distribution
#' and a brand x pack-size matrix.
#'
#' @inheritParams run_shopper_location
#' @param pack_data Data frame with one column per pack-size band.
#' @param pack_cols Character. Column names in \code{pack_data}.
#' @param pack_codes Character. Short codes (e.g. "SMALL", "MEDIUM").
#' @param pack_labels Character. Display labels (e.g. "Small (<200g)").
#'
#' @return List with the same fields as \code{run_shopper_location()}, plus
#'   \code{top} reporting the most-bought pack size.
#'
#' @export
run_shopper_packsize <- function(pack_data,
                                  pack_cols,
                                  pack_codes,
                                  pack_labels,
                                  pen_mat     = NULL,
                                  brand_codes = NULL,
                                  weights     = NULL) {
  .run_shopper_multimention(
    data_df     = pack_data,
    cols        = pack_cols,
    codes       = pack_codes,
    labels      = pack_labels,
    pen_mat     = pen_mat,
    brand_codes = brand_codes,
    weights     = weights,
    kind        = "packsize"
  )
}


# ==============================================================================
# INTERNAL: SHARED MULTI-MENTION ENGINE
# ==============================================================================

.run_shopper_multimention <- function(data_df, cols, codes, labels,
                                       pen_mat, brand_codes, weights, kind) {

  guard <- .shopper_guard_inputs(data_df, cols, codes, labels, weights, kind)
  if (identical(guard$status, "REFUSED")) return(guard)

  M <- .shopper_to_binary_matrix(data_df, cols, codes)
  cat_buyer <- rowSums(M) > 0
  n_cat_buyers <- sum(cat_buyer)
  if (n_cat_buyers == 0) {
    return(.shopper_refuse(
      "DATA_NO_CAT_BUYERS",
      sprintf("No respondents selected any %s option (all rows blank).",
              .shopper_label(kind))
    ))
  }

  w <- .shopper_normalise_weights(weights, nrow(data_df))
  cat_pct_raw <- .shopper_raw_category_pct(M, w, cat_buyer)
  cat_dist <- .shopper_category_distribution(M, codes, labels,
                                              cat_pct_raw, cat_buyer)
  kpis     <- .shopper_kpis(cat_pct_raw, codes, labels)
  brand_mx <- .shopper_brand_matrix(M, codes, w, pen_mat, brand_codes)

  list(
    status                = "PASS",
    kind                  = kind,
    category_distribution = cat_dist,
    brand_matrix          = brand_mx,
    top                   = kpis$top,
    hhi                   = kpis$hhi,
    n_cat_buyers          = as.integer(n_cat_buyers),
    n_respondents         = as.integer(nrow(data_df))
  )
}


# Coerce multi-mention columns to a respondents x options 0/1 matrix.
# Tolerates logical or "1"/"0" character inputs; NA collapses to 0.
.shopper_to_binary_matrix <- function(data_df, cols, codes) {
  M <- vapply(cols, function(cn) {
    v <- suppressWarnings(as.numeric(data_df[[cn]]))
    v[is.na(v)] <- 0
    v
  }, numeric(nrow(data_df)))
  if (is.vector(M)) M <- matrix(M, ncol = length(cols))
  colnames(M) <- codes
  M
}


# Replace NULL / negative / NA weights with safe defaults so weighted-mean
# calls below never see them.
.shopper_normalise_weights <- function(weights, n_rows) {
  w <- if (is.null(weights)) rep(1, n_rows) else as.numeric(weights)
  w[is.na(w) | w < 0] <- 0
  w
}


# Unrounded category-level % per option (weighted share over cat buyers).
# Kept as raw doubles so KPIs compute with full precision; the display
# distribution rounds to 1 dp downstream.
.shopper_raw_category_pct <- function(M, w, cat_buyer) {
  cb_w_total <- sum(w[cat_buyer])
  vapply(seq_along(colnames(M)), function(j) {
    if (cb_w_total <= 0) return(NA_real_)
    100 * sum(w[cat_buyer] * M[cat_buyer, j]) / cb_w_total
  }, numeric(1))
}


# Display-ready category distribution: Code/Label/Order/n/Pct (1 dp).
.shopper_category_distribution <- function(M, codes, labels,
                                            cat_pct_raw, cat_buyer) {
  cat_n <- vapply(seq_along(codes), function(j) {
    sum(cat_buyer & M[, j] > 0)
  }, integer(1))
  data.frame(
    Code  = codes,
    Label = labels,
    Order = seq_along(codes),
    n     = cat_n,
    Pct   = round(cat_pct_raw, 1),
    stringsAsFactors = FALSE
  )
}


# Top-option KPI + HHI concentration index (sum of squared shares, 0-1).
# All-NA input returns NA stubs rather than NaN. HHI is computed from the
# raw (unrounded) percentages to keep three-dp precision.
.shopper_kpis <- function(cat_pct_raw, codes, labels) {
  if (all(is.na(cat_pct_raw))) {
    return(list(
      top = list(code = NA_character_, label = NA_character_, pct = NA_real_),
      hhi = NA_real_
    ))
  }
  top_i <- which.max(cat_pct_raw)
  shares <- cat_pct_raw / 100
  list(
    top = list(
      code  = codes[top_i],
      label = labels[top_i],
      pct   = round(cat_pct_raw[top_i], 1)
    ),
    hhi = round(sum(shares ^ 2, na.rm = TRUE), 3)
  )
}


.shopper_brand_matrix <- function(M, codes, w, pen_mat, brand_codes) {

  if (is.null(pen_mat) || is.null(brand_codes) || length(brand_codes) == 0) {
    return(NULL)
  }

  pen_mat <- as.matrix(pen_mat)
  if (ncol(pen_mat) != length(brand_codes)) return(NULL)
  if (nrow(pen_mat) != nrow(M)) return(NULL)

  # One row per brand, leading "__cat__" row for the cross-brand mean.
  per_brand <- lapply(seq_along(brand_codes), function(b) {
    is_buyer <- pen_mat[, b] > 0 & !is.na(pen_mat[, b])
    base_w   <- sum(w[is_buyer])
    base_n   <- as.integer(sum(is_buyer))
    pcts <- if (base_w <= 0) {
      stats::setNames(rep(NA_real_, length(codes)), codes)
    } else {
      vapply(seq_along(codes), function(j) {
        round(100 * sum(w[is_buyer] * M[is_buyer, j]) / base_w, 1)
      }, numeric(1))
    }
    out <- as.data.frame(
      c(list(BrandCode = brand_codes[b], Base_n = base_n),
        stats::setNames(as.list(pcts), paste0("Pct_", codes))),
      stringsAsFactors = FALSE
    )
    out
  })
  brand_df <- do.call(rbind, per_brand)

  # Cat avg row: unweighted mean across brand rows, per option column.
  pct_cols <- paste0("Pct_", codes)
  cat_avg <- vapply(pct_cols, function(cn) {
    v <- suppressWarnings(as.numeric(brand_df[[cn]]))
    if (all(is.na(v))) NA_real_ else round(mean(v, na.rm = TRUE), 1)
  }, numeric(1))
  cat_row <- as.data.frame(
    c(list(BrandCode = "__cat__", Base_n = NA_integer_),
      stats::setNames(as.list(cat_avg), pct_cols)),
    stringsAsFactors = FALSE
  )

  rbind(cat_row, brand_df)
}


# ==============================================================================
# INTERNAL: GUARDS + REFUSAL HELPERS
# ==============================================================================

.shopper_label <- function(kind) {
  switch(kind, location = "purchase channel", packsize = "pack size", kind)
}


.shopper_refuse <- function(code, message, how_to_fix = NULL) {
  out <- list(status = "REFUSED", code = code, message = message)
  if (!is.null(how_to_fix)) out$how_to_fix <- how_to_fix
  cat(sprintf("\n[TURAS Brand/Shopper] REFUSED %s: %s\n", code, message))
  out
}


.shopper_guard_inputs <- function(data_df, cols, codes, labels, weights, kind) {

  if (is.null(data_df) || !is.data.frame(data_df) || nrow(data_df) == 0) {
    return(.shopper_refuse(
      "DATA_NO_INPUT",
      sprintf("No %s data provided.", .shopper_label(kind)),
      "Pass a data frame with one row per respondent and one column per option."
    ))
  }

  if (length(cols) == 0) {
    return(.shopper_refuse(
      "CFG_NO_OPTION_COLS",
      sprintf("No %s option columns supplied.", .shopper_label(kind)),
      sprintf("Resolve role columns via the %s sheet then pass the column names.",
              if (kind == "location") "Channels" else "PackSizes")
    ))
  }

  missing_cols <- setdiff(cols, names(data_df))
  if (length(missing_cols) > 0) {
    return(.shopper_refuse(
      "DATA_COLS_MISSING",
      sprintf("Expected %s columns not in data: %s.",
              .shopper_label(kind),
              paste(missing_cols, collapse = ", ")),
      "Check ColumnPattern and the option-list sheet match the data file."
    ))
  }

  if (!is.null(codes) && length(codes) != length(cols)) {
    return(.shopper_refuse(
      "CFG_CODES_LENGTH_MISMATCH",
      sprintf("codes length (%d) != cols length (%d).",
              length(codes), length(cols))
    ))
  }
  if (!is.null(labels) && length(labels) != length(cols)) {
    return(.shopper_refuse(
      "CFG_LABELS_LENGTH_MISMATCH",
      sprintf("labels length (%d) != cols length (%d).",
              length(labels), length(cols))
    ))
  }

  if (!is.null(weights) && length(weights) != nrow(data_df)) {
    return(.shopper_refuse(
      "DATA_WEIGHTS_MISMATCH",
      sprintf("weights length (%d) does not match data rows (%d).",
              length(weights), nrow(data_df))
    ))
  }

  list(status = "PASS")
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Shopper Behaviour element loaded (v%s)",
                  SHOPPER_BEHAVIOUR_VERSION))
}
