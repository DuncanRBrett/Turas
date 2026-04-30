# ==============================================================================
# BRAND MODULE - BRAND VOLUME MATRIX
# ==============================================================================
# Builds per-respondent purchase count matrices from BRANDPEN2 (bought flag)
# and BRANDPEN3 (count in target window). Handles reconciliation between the
# two columns per §5.3 of CAT_BUYING_SPEC_v3, winsorisation per §5.4, and
# type coercion per §5.2.
#
# VERSION: 1.0
#
# REFERENCES:
#   Goodhardt, G.J., Ehrenberg, A.S.C. & Chatfield, C. (1984). The Dirichlet:
#     A comprehensive model of buying behaviour. JRSS-A 147(5), 621-655.
# ==============================================================================

BRAND_VOLUME_VERSION <- "2.0"

# Threshold multiplier for 99th-percentile winsorisation
.BV_WINSOR_MULT_DEFAULT <- 3


#' Build per-respondent brand purchase count matrices
#'
#' Reads BRANDPEN2 (bought in target window, 0/1) and BRANDPEN3 (purchase
#' count in target window, numeric) for each brand in a category.  Reconciles
#' logical inconsistencies between the two columns (§5.3), winsorises extreme
#' counts (§5.4), and returns clean matrices ready for Dirichlet analysis.
#'
#' @param cat_data Data frame. Rows = respondents for the focal category.
#' @param cat_brands Data frame. Must have a \code{BrandCode} column whose
#'   order defines the matrix columns.
#' @param pen_target_prefix Character. Question root for BRANDPEN2 columns,
#'   e.g. \code{"BRANDPEN2_DSS"}. The function expects slot-indexed columns
#'   matching \code{<root>_[0-9]+} (AlchemerParser shape). For backward
#'   compatibility with legacy column-per-brand fixtures, the function
#'   falls back to per-brand column matching when no slot columns exist.
#' @param freq_prefix Character. Question root for BRANDPEN3 columns,
#'   e.g. \code{"BRANDPEN3_DSS"}. Same shape as pen_target_prefix.
#' @param winsor_mult Numeric. Multiplier applied to the 99th percentile of
#'   per-respondent category volume to set the winsorisation cap.  Default 3.
#' @param verbose Logical. Print reconciliation stats to console.
#'
#' @return List with:
#'   \item{status}{"PASS", "PARTIAL", or "REFUSED"}
#'   \item{pen_mat}{n_resp × n_brands integer matrix (0/1) of reconciled buyer flags}
#'   \item{x_mat}{n_resp × n_brands numeric matrix of winsorised purchase counts}
#'   \item{m_vec}{Numeric vector length n_resp of per-respondent category volume}
#'   \item{reconciliation}{Named list of diagnostic counts}
#'   \item{warnings}{Character vector — populated for PARTIAL}
#'
#' @references Goodhardt, Ehrenberg & Chatfield (1984).
#'
#' @export
build_brand_volume_matrix <- function(cat_data,
                                      cat_brands,
                                      pen_target_prefix,
                                      freq_prefix,
                                      winsor_mult = .BV_WINSOR_MULT_DEFAULT,
                                      verbose     = FALSE) {

  warnings_out <- character(0)

  # --- Input guards ---
  if (is.null(cat_data) || nrow(cat_data) == 0) {
    return(.bv_refuse("DATA_NO_CAT_DATA",
                      "No category data provided to build_brand_volume_matrix()"))
  }
  if (is.null(cat_brands) || nrow(cat_brands) == 0 ||
      !"BrandCode" %in% names(cat_brands)) {
    return(.bv_refuse("DATA_BRANDPEN2_MISSING",
                      "cat_brands must be a data frame with a BrandCode column"))
  }

  n_resp   <- nrow(cat_data)
  brands   <- as.character(cat_brands$BrandCode)
  n_brands <- length(brands)

  pen_mat <- matrix(0L, nrow = n_resp, ncol = n_brands,
                    dimnames = list(NULL, brands))
  x_mat   <- matrix(0.0,  nrow = n_resp, ncol = n_brands,
                    dimnames = list(NULL, brands))

  coerce_fails <- 0L

  # Detect column shape: slot-indexed (parser-shape) or per-brand (legacy).
  has_slots_pen  <- length(.bv_slot_cols(cat_data, pen_target_prefix)) > 0
  has_slots_freq <- length(.bv_slot_cols(cat_data, freq_prefix)) > 0

  if (has_slots_pen && has_slots_freq) {
    # Slot-indexed path — use data-access helpers
    pen_logical <- multi_mention_brand_matrix(cat_data, pen_target_prefix,
                                              brands)
    pen_mat <- matrix(as.integer(pen_logical), nrow = n_resp,
                      ncol = n_brands, dimnames = list(NULL, brands))
    x_mat <- slot_paired_numeric_matrix(cat_data, pen_target_prefix,
                                        freq_prefix, brands)
    x_mat[is.na(x_mat) | x_mat < 0] <- 0
  } else {
    # Legacy per-brand-column path — preserved for backward compatibility
    missing_pen  <- character(0)
    missing_freq <- character(0)
    for (bi in seq_along(brands)) {
      br <- brands[bi]
      pen_col  <- .bv_find_col(cat_data, pen_target_prefix, br)
      freq_col <- .bv_find_col(cat_data, freq_prefix, br)
      if (is.null(pen_col))  { missing_pen  <- c(missing_pen,  br); next }
      if (is.null(freq_col)) { missing_freq <- c(missing_freq, br); next }

      pen_raw <- as.integer(!is.na(cat_data[[pen_col]]) &
                              cat_data[[pen_col]] > 0)
      freq_chr <- trimws(as.character(cat_data[[freq_col]]))
      freq_num <- suppressWarnings(as.numeric(freq_chr))
      n_fail   <- sum(is.na(freq_num) & !is.na(freq_chr) &
                        freq_chr != "NA")
      coerce_fails <- coerce_fails + n_fail
      freq_num <- ifelse(is.na(freq_num) | freq_num < 0, 0.0, freq_num)
      pen_mat[, bi] <- pen_raw
      x_mat[, bi]   <- freq_num
    }
    if (length(missing_pen) > 0) {
      return(.bv_refuse("DATA_BRANDPEN2_MISSING",
                        sprintf("BRANDPEN2 columns missing for brands: %s",
                                paste(missing_pen, collapse = ", "))))
    }
    if (length(missing_freq) > 0) {
      return(.bv_refuse("DATA_BRANDPEN3_MISSING",
                        sprintf("BRANDPEN3 columns missing for brands: %s",
                                paste(missing_freq, collapse = ", "))))
    }
  }

  # --- Reconciliation (§5.3) ---
  rec <- .bv_reconcile(pen_mat, x_mat, n_resp, n_brands, brands)
  pen_mat           <- rec$pen_mat
  x_mat             <- rec$x_mat
  pen_yes_count_no  <- rec$pen_yes_count_no
  pen_no_count_yes  <- rec$pen_no_count_yes

  # PARTIAL thresholds
  n_buyers_pre <- sum(rowSums(pen_mat) > 0)
  if (n_buyers_pre > 0) {
    rate_pycn <- pen_yes_count_no / (n_buyers_pre * n_brands)
    rate_pncy <- pen_no_count_yes / (n_resp * n_brands)
    if (rate_pycn > 0.10)
      warnings_out <- c(warnings_out, sprintf(
        "%.0f%% of buyer × brand cells have pen=1 but count=0; treated as count=1",
        rate_pycn * 100))
    if (rate_pncy > 0.05)
      warnings_out <- c(warnings_out, sprintf(
        "%.0f%% of non-buyer × brand cells have count>0; treated as buyers",
        rate_pncy * 100))
  }

  # --- Category volume ---
  m_vec <- rowSums(x_mat)

  if (all(m_vec == 0)) {
    return(.bv_refuse("DATA_ALL_NA",
                      "All purchase counts are zero after reconciliation"))
  }

  # --- Winsorisation (§5.4) ---
  buyers_mask <- m_vec > 0
  n_buyers    <- sum(buyers_mask)
  winsor_n    <- 0L

  if (n_buyers > 1) {
    cap <- as.numeric(stats::quantile(m_vec[buyers_mask], 0.99)) * winsor_mult
    too_high <- buyers_mask & m_vec > cap
    winsor_n <- sum(too_high)
    if (winsor_n > 0) {
      for (i in which(too_high)) {
        scale_f   <- cap / m_vec[i]
        x_mat[i, ] <- x_mat[i, ] * scale_f
      }
      m_vec <- rowSums(x_mat)
    }
  }

  if (verbose) {
    cat(sprintf(
      "[08b] Brands: %d | Respondents: %d | Buyers: %d | ",
      n_brands, n_resp, sum(m_vec > 0)))
    cat(sprintf(
      "Coerce fails: %d | pen=1/count=0: %d | pen=0/count>0: %d | Winsorised: %d\n",
      coerce_fails, pen_yes_count_no, pen_no_count_yes, winsor_n))
  }

  recon_list <- list(
    pen_yes_count_no  = pen_yes_count_no,
    pen_no_count_yes  = pen_no_count_yes,
    winsorised_n      = winsor_n,
    coercion_failures = coerce_fails
  )

  result <- list(
    status         = if (length(warnings_out) > 0) "PARTIAL" else "PASS",
    pen_mat        = pen_mat,
    x_mat          = x_mat,
    m_vec          = m_vec,
    reconciliation = recon_list,
    warnings       = warnings_out
  )
  result
}


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

#' Find slot-indexed columns matching ^prefix_[0-9]+$ (parser shape)
#' @keywords internal
.bv_slot_cols <- function(data, prefix) {
  if (is.null(prefix) || !nzchar(prefix)) return(character(0))
  pat <- paste0("^",
                gsub("([\\.\\+\\*\\?\\(\\)\\[\\]\\{\\}\\|\\^\\$])",
                     "\\\\\\1", prefix, perl = TRUE),
                "_[0-9]+$")
  grep(pat, names(data), value = TRUE)
}


#' Find a brand column by prefix + brand code (legacy column-per-brand path)
#' @keywords internal
.bv_find_col <- function(data, prefix, brand) {
  candidates <- c(
    paste0(prefix, "_", brand),
    paste0(prefix, ".", brand),
    paste0(prefix, brand)
  )
  # Also accept prefix_cat_brand pattern (detect cat from existing columns)
  extras <- grep(
    paste0("^", prefix, "_[A-Z]{2,4}_", brand, "$"),
    names(data), value = TRUE)
  candidates <- c(candidates, extras)
  match <- intersect(candidates, names(data))
  if (length(match) > 0) match[1] else NULL
}


#' Perform §5.3 reconciliation in-place
#' @keywords internal
.bv_reconcile <- function(pen_mat, x_mat, n_resp, n_brands, brands) {
  pen_yes_count_no <- 0L
  pen_no_count_yes <- 0L

  for (bi in seq_len(n_brands)) {
    pen  <- pen_mat[, bi]
    freq <- x_mat[, bi]

    # Case: pen=1, count=0 or NA → minimum count = 1
    case_a <- pen == 1L & freq <= 0
    if (any(case_a)) {
      pen_yes_count_no <- pen_yes_count_no + sum(case_a)
      x_mat[case_a, bi] <- 1.0
    }

    # Case: pen=0, count>0 → trust count, promote to buyer
    case_b <- pen == 0L & freq > 0
    if (any(case_b)) {
      pen_no_count_yes <- pen_no_count_yes + sum(case_b)
      pen_mat[case_b, bi] <- 1L
    }
  }

  list(pen_mat          = pen_mat,
       x_mat            = x_mat,
       pen_yes_count_no = pen_yes_count_no,
       pen_no_count_yes = pen_no_count_yes)
}


#' Build a simple TRS-style refusal for this module
#' @keywords internal
.bv_refuse <- function(code, message) {
  cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
  cat("│ Module: 08b_brand_volume\n")
  cat(sprintf("│ Code:    %s\n", code))
  cat(sprintf("│ Message: %s\n", message))
  cat("└───────────────────────────────────────────────────────┘\n\n")
  list(status = "REFUSED", code = code, message = message)
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand Volume Matrix element loaded (v%s)",
                  BRAND_VOLUME_VERSION))
}
