# ==============================================================================
# BRAND MODULE - MA FOCAL-BRAND VIEW (DRIVERS & BARRIERS LENS)
# ==============================================================================
# Pairs a focal brand's market-relative Mental Advantage score with the
# buyer-gap (% of focal-brand buyers minus % of non-buyers) for each
# stimulus, and assigns a four-way Read label that collapses both numbers
# into a single strategic call.
#
# This is the analytical core that replaces a standalone Drivers & Barriers
# HTML page. The existing D&B engine (06_drivers_barriers.R) is retained
# for its Excel/CSV outputs; this file produces the data shape the MA
# Mental Advantage sub-tab consumes for its focal-brand drill-down.
#
# Read labels (locked at four — see sketches/MA_BUYER_GAP_BUILD_PLAN.md §2):
#   STRENGTH   high MA + high buyer gap   buyer-validated competitive edge
#   FAME_GAP   high MA + flat/neg gap     market thinks of you, buyers don't
#                                          reinforce — delivery / experience gap
#   BUYER_EDGE flat MA + high buyer gap   buyers know it, market doesn't —
#                                          awareness opportunity
#   WEAK       low MA (any gap)           drop from comms or rebuild
#   (none)     flat MA + flat gap         no signal — chip left empty
#   suppressed base < min_base            gap NA, row marked Below_Min_Base
#
# Two-proportion z is the significance test for the buyer gap:
#   z = (p_buy - p_nonbuy) /
#       sqrt( p_pool * (1 - p_pool) * (1/n_buy + 1/n_nonbuy) )
# with |z| > 1.96 = significant at 95%.
#
# DEPENDENCIES: 02_mental_availability.R, 06_drivers_barriers.R
# VERSION: 1.0
# ==============================================================================

MA_FOCAL_VIEW_VERSION   <- "1.0"
MA_FOCAL_VIEW_MIN_BASE  <- 30L
MA_FOCAL_VIEW_GAP_THR   <- 5    # pp
MA_FOCAL_VIEW_MA_THR    <- 5    # pp — match MA_DEFAULT_THRESHOLD_PP
MA_FOCAL_VIEW_Z_THR     <- 1.96


# ==============================================================================
# SECTION 1: READ LABEL CLASSIFIER
# ==============================================================================

#' Classify a (MA score, buyer gap) pair into a four-way Read label.
#'
#' Pure function; vectorised. Returns one of \code{"STRENGTH"},
#' \code{"FAME_GAP"}, \code{"BUYER_EDGE"}, \code{"WEAK"}, \code{""} (no
#' chip — flat on both axes), or \code{"INSUFFICIENT"} (base too small).
#'
#' Decision rules (locked):
#'   below_min_base          -> "INSUFFICIENT"
#'   ma >= +ma_thr & gap >=  gap_thr            -> "STRENGTH"
#'   ma >= +ma_thr & gap <   gap_thr            -> "FAME_GAP"
#'   ma <= -ma_thr (any gap)                    -> "WEAK"
#'   |ma| <  ma_thr & gap >=  gap_thr           -> "BUYER_EDGE"
#'   else (flat on both axes)                   -> "" (empty)
#'
#' @param ma_score Numeric. Mental Advantage score in pp.
#' @param buyer_gap Numeric. Buyer minus non-buyer linkage in pp.
#' @param below_min_base Logical. TRUE when buyer or non-buyer base is
#'   below the minimum threshold; forces "INSUFFICIENT".
#' @param ma_thr Numeric. MA threshold (default 5pp).
#' @param gap_thr Numeric. Buyer-gap threshold (default 5pp).
#' @return Character vector of labels.
#' @export
classify_focal_read <- function(ma_score, buyer_gap, below_min_base = FALSE,
                                ma_thr  = MA_FOCAL_VIEW_MA_THR,
                                gap_thr = MA_FOCAL_VIEW_GAP_THR) {
  n <- max(length(ma_score), length(buyer_gap), length(below_min_base))
  if (n == 0L) return(character(0))

  ma_score        <- rep_len(as.numeric(ma_score),        n)
  buyer_gap       <- rep_len(as.numeric(buyer_gap),       n)
  below_min_base  <- rep_len(as.logical(below_min_base),  n)

  out <- character(n)

  for (i in seq_len(n)) {
    if (isTRUE(below_min_base[i])) { out[i] <- "INSUFFICIENT"; next }
    if (is.na(ma_score[i]) || is.na(buyer_gap[i])) { out[i] <- ""; next }

    ma_pos  <- ma_score[i]  >=  ma_thr
    ma_neg  <- ma_score[i]  <= -ma_thr
    gap_pos <- buyer_gap[i] >=  gap_thr

    out[i] <- if (ma_neg)            "WEAK"
              else if (ma_pos &&  gap_pos)  "STRENGTH"
              else if (ma_pos && !gap_pos)  "FAME_GAP"
              else if (!ma_pos && !ma_neg && gap_pos) "BUYER_EDGE"
              else                                    ""
  }
  out
}


# ==============================================================================
# SECTION 2: TWO-PROPORTION Z FOR THE BUYER GAP
# ==============================================================================

#' Two-proportion z-test for the buyer / non-buyer linkage gap.
#'
#' Pooled-variance form, two-sided. Returns NA when either base is zero.
#'
#' @param x_buy Integer/numeric. Buyer "yes" count (unweighted).
#' @param n_buy Integer/numeric. Buyer base (unweighted).
#' @param x_nonbuy Integer/numeric. Non-buyer "yes" count.
#' @param n_nonbuy Integer/numeric. Non-buyer base.
#' @return List with \code{z}, \code{abs_z}, \code{significant} (logical,
#'   |z| > 1.96).
#' @keywords internal
.fv_two_prop_z <- function(x_buy, n_buy, x_nonbuy, n_nonbuy,
                            z_thr = MA_FOCAL_VIEW_Z_THR) {
  if (is.na(n_buy) || is.na(n_nonbuy) || n_buy <= 0 || n_nonbuy <= 0) {
    return(list(z = NA_real_, abs_z = NA_real_, significant = NA))
  }
  p_buy    <- x_buy    / n_buy
  p_nonbuy <- x_nonbuy / n_nonbuy
  p_pool   <- (x_buy + x_nonbuy) / (n_buy + n_nonbuy)
  denom    <- sqrt(p_pool * (1 - p_pool) * (1 / n_buy + 1 / n_nonbuy))
  z <- if (is.finite(denom) && denom > 0) (p_buy - p_nonbuy) / denom else NA_real_
  list(z = z, abs_z = abs(z),
       significant = !is.na(z) && abs(z) > z_thr)
}


# ==============================================================================
# SECTION 3: MAIN ENTRY POINT
# ==============================================================================

#' Build the per-stimulus Focal Brand View data frame.
#'
#' For each stimulus (CEP or attribute) returns the focal brand's MA score
#' (passed in from the existing MA result) alongside the buyer-gap, the
#' two-proportion z significance, and the Read label.
#'
#' Reuses the existing differential importance math from
#' \code{calculate_differential_importance()} and adds significance,
#' base-size suppression and the Read classifier.
#'
#' @param linkage_tensor Named list of brand matrices (respondents x stimuli)
#'   from \code{build_cep_linkage()}.
#' @param codes Character vector of stimulus codes in display order.
#' @param focal_brand Character. Focal brand code (must be a name of
#'   \code{linkage_tensor}).
#' @param pen Numeric / logical vector (length n_resp). 1 = focal-brand
#'   buyer in the target window, 0 = non-buyer. NA = treated as non-buyer.
#' @param weights Numeric vector or NULL. Used for the displayed
#'   percentages and gap, but not for the z test (z uses unweighted Ns).
#' @param ma_advantage Numeric vector. MA score in pp for the focal brand,
#'   one entry per stimulus in \code{codes}. Optional (NA when missing).
#' @param ma_significant Logical vector or NULL. MA |z| > 1.96 per stimulus.
#' @param min_base Integer. Minimum unweighted base per side; below this,
#'   gap fields are NA and \code{Below_Min_Base} is TRUE.
#' @param ma_thr Numeric. MA threshold for the Read classifier.
#' @param gap_thr Numeric. Buyer-gap threshold for the Read classifier.
#'
#' @return Data frame with columns:
#'   \itemize{
#'     \item \code{Code}             stimulus code (matches \code{codes})
#'     \item \code{MA_Score}         pp (NA when not supplied)
#'     \item \code{MA_Significant}   logical (NA when not supplied)
#'     \item \code{Buyer_Pct}        % of buyers linking the stimulus
#'     \item \code{NonBuyer_Pct}     % of non-buyers linking the stimulus
#'     \item \code{Buyer_Gap}        Buyer_Pct − NonBuyer_Pct (pp)
#'     \item \code{Gap_Z}            two-proportion z (unweighted Ns)
#'     \item \code{Gap_Significant}  logical, |z| > 1.96
#'     \item \code{N_Buyer}          unweighted buyer base
#'     \item \code{N_NonBuyer}       unweighted non-buyer base
#'     \item \code{Below_Min_Base}   logical, suppress gap fields if TRUE
#'     \item \code{Read_Label}       one of STRENGTH/FAME_GAP/BUYER_EDGE/WEAK/""/INSUFFICIENT
#'   }
#'
#' @export
calculate_ma_focal_view <- function(linkage_tensor, codes, focal_brand, pen,
                                     weights        = NULL,
                                     ma_advantage   = NULL,
                                     ma_significant = NULL,
                                     min_base       = MA_FOCAL_VIEW_MIN_BASE,
                                     ma_thr         = MA_FOCAL_VIEW_MA_THR,
                                     gap_thr        = MA_FOCAL_VIEW_GAP_THR) {

  # --- Guards (TRS-style refusal expressed as empty data frame on bad input;
  #             the caller decides whether to escalate to a refusal) ---------
  if (!is.list(linkage_tensor) || length(linkage_tensor) == 0L)
    return(.fv_empty_df())
  if (length(codes) == 0L) return(.fv_empty_df())
  if (is.null(focal_brand) || !nzchar(focal_brand) ||
      !focal_brand %in% names(linkage_tensor)) return(.fv_empty_df())

  brand_mat <- linkage_tensor[[focal_brand]]
  if (is.null(brand_mat) || nrow(brand_mat) == 0L) return(.fv_empty_df())
  n_resp <- nrow(brand_mat)

  # Coerce pen to 0/1
  pen <- if (is.null(pen)) rep(0L, n_resp) else as.integer(!is.na(pen) & pen > 0)
  if (length(pen) != n_resp) {
    # length mismatch is a programming error — surface as empty rather than crash
    return(.fv_empty_df())
  }

  buyers     <- pen == 1L
  non_buyers <- !buyers

  n_buy_unw    <- sum(buyers)
  n_nonbuy_unw <- sum(non_buyers)

  # Weighted bases for percentage display (fall through to unweighted)
  if (is.null(weights)) {
    n_buy_disp    <- n_buy_unw
    n_nonbuy_disp <- n_nonbuy_unw
  } else {
    if (length(weights) != n_resp)
      return(.fv_empty_df())
    n_buy_disp    <- sum(weights[buyers],     na.rm = TRUE)
    n_nonbuy_disp <- sum(weights[non_buyers], na.rm = TRUE)
  }

  # Pre-extend MA inputs to match codes length
  ma_score <- if (is.null(ma_advantage))
    rep(NA_real_, length(codes)) else as.numeric(ma_advantage)
  if (length(ma_score) != length(codes))
    ma_score <- rep_len(ma_score, length(codes))

  ma_sig <- if (is.null(ma_significant))
    rep(NA, length(codes)) else as.logical(ma_significant)
  if (length(ma_sig) != length(codes))
    ma_sig <- rep_len(ma_sig, length(codes))

  rows <- vector("list", length(codes))
  for (i in seq_along(codes)) {
    code <- codes[i]
    if (!code %in% colnames(brand_mat)) {
      rows[[i]] <- .fv_row_na(code, ma_score[i], ma_sig[i],
                               n_buy_unw, n_nonbuy_unw,
                               below_min_base = TRUE,
                               min_base = min_base)
      next
    }
    col_vals <- brand_mat[, code]
    col_vals[is.na(col_vals)] <- 0

    # Unweighted "yes" counts (used for the z test)
    x_buy_unw    <- sum(col_vals[buyers])
    x_nonbuy_unw <- sum(col_vals[non_buyers])

    # Displayed percentages (weighted if supplied)
    if (is.null(weights)) {
      buyer_pct    <- if (n_buy_unw    > 0) 100 * x_buy_unw    / n_buy_unw    else NA_real_
      nonbuyer_pct <- if (n_nonbuy_unw > 0) 100 * x_nonbuy_unw / n_nonbuy_unw else NA_real_
    } else {
      buyer_pct    <- if (n_buy_disp    > 0)
        100 * sum(weights[buyers]     * col_vals[buyers])     / n_buy_disp    else NA_real_
      nonbuyer_pct <- if (n_nonbuy_disp > 0)
        100 * sum(weights[non_buyers] * col_vals[non_buyers]) / n_nonbuy_disp else NA_real_
    }

    below_min <- (n_buy_unw < min_base) || (n_nonbuy_unw < min_base)

    z_res <- .fv_two_prop_z(x_buy_unw, n_buy_unw,
                             x_nonbuy_unw, n_nonbuy_unw)

    if (below_min) {
      buyer_gap <- NA_real_
      gap_z     <- NA_real_
      gap_sig   <- NA
    } else {
      buyer_gap <- buyer_pct - nonbuyer_pct
      gap_z     <- z_res$z
      gap_sig   <- z_res$significant
    }

    read_label <- classify_focal_read(
      ma_score = ma_score[i],
      buyer_gap = buyer_gap,
      below_min_base = below_min,
      ma_thr = ma_thr, gap_thr = gap_thr)

    rows[[i]] <- data.frame(
      Code            = code,
      MA_Score        = round(ma_score[i], 2),
      MA_Significant  = ma_sig[i],
      Buyer_Pct       = round(buyer_pct, 2),
      NonBuyer_Pct    = round(nonbuyer_pct, 2),
      Buyer_Gap       = round(buyer_gap, 2),
      Gap_Z           = round(gap_z, 3),
      Gap_Significant = gap_sig,
      N_Buyer         = as.integer(n_buy_unw),
      N_NonBuyer      = as.integer(n_nonbuy_unw),
      Below_Min_Base  = below_min,
      Read_Label      = read_label,
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, rows)
}


# ==============================================================================
# SECTION 4: HELPERS
# ==============================================================================

.fv_empty_df <- function() {
  data.frame(
    Code            = character(0),
    MA_Score        = numeric(0),
    MA_Significant  = logical(0),
    Buyer_Pct       = numeric(0),
    NonBuyer_Pct    = numeric(0),
    Buyer_Gap       = numeric(0),
    Gap_Z           = numeric(0),
    Gap_Significant = logical(0),
    N_Buyer         = integer(0),
    N_NonBuyer      = integer(0),
    Below_Min_Base  = logical(0),
    Read_Label      = character(0),
    stringsAsFactors = FALSE
  )
}

.fv_row_na <- function(code, ma_score, ma_sig, n_buy, n_nonbuy,
                        below_min_base, min_base) {
  data.frame(
    Code            = code,
    MA_Score        = round(as.numeric(ma_score), 2),
    MA_Significant  = ma_sig,
    Buyer_Pct       = NA_real_,
    NonBuyer_Pct    = NA_real_,
    Buyer_Gap       = NA_real_,
    Gap_Z           = NA_real_,
    Gap_Significant = NA,
    N_Buyer         = as.integer(n_buy),
    N_NonBuyer      = as.integer(n_nonbuy),
    Below_Min_Base  = isTRUE(below_min_base) ||
                       (n_buy < min_base) || (n_nonbuy < min_base),
    Read_Label      = "INSUFFICIENT",
    stringsAsFactors = FALSE
  )
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand MA Focal-Brand View element loaded (v%s)",
                  MA_FOCAL_VIEW_VERSION))
}
