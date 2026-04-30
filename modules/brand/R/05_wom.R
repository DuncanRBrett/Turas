# ==============================================================================
# BRAND MODULE - WOM (WORD-OF-MOUTH) ELEMENT
# ==============================================================================
# Word-of-mouth analysis: received/shared x positive/negative.
# Standalone element with own battery (6 questions, ~2 min).
# Brand-level (not category-specific).
#
# VERSION: 1.0
#
# REFERENCES:
#   Romaniuk, J. (2022). Better Brand Health. (CBM template, WOM battery)
# ==============================================================================

WOM_VERSION <- "1.0"


#' Calculate WOM metrics for all brands
#'
#' @param data Data frame. Survey data.
#' @param brand_codes Character vector. Brand codes.
#' @param received_pos_prefix Character. Column prefix for received positive.
#' @param received_neg_prefix Character. Column prefix for received negative.
#' @param shared_pos_prefix Character. Column prefix for shared positive.
#' @param shared_neg_prefix Character. Column prefix for shared negative.
#' @param shared_pos_freq_prefix Character. Column prefix for shared positive
#'   frequency (optional).
#' @param shared_neg_freq_prefix Character. Column prefix for shared negative
#'   frequency (optional).
#' @param focal_brand Character. Focal brand code.
#' @param weights Numeric vector. Respondent weights (optional).
#'
#' @return List with status, wom_metrics, net_balance, amplification,
#'   and metrics_summary.
#'
#' @export
run_wom <- function(data, brand_codes,
                    received_pos_prefix, received_neg_prefix,
                    shared_pos_prefix, shared_neg_prefix,
                    shared_pos_freq_prefix = NULL,
                    shared_neg_freq_prefix = NULL,
                    focal_brand = NULL,
                    weights = NULL) {

  if (is.null(data) || nrow(data) == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_EMPTY",
      message = "No data for WOM analysis"
    ))
  }

  n_resp <- nrow(data)
  n_brands <- length(brand_codes)

  # Helper to find brand column
  .find_col <- function(prefix, brand) {
    candidates <- c(paste0(prefix, "_", brand), paste0(prefix, ".", brand))
    match <- intersect(candidates, names(data))
    if (length(match) > 0) match[1] else NULL
  }

  # Helper for weighted percentage
  .wpct <- function(vals, wts = weights) {
    binary <- !is.na(vals) & vals > 0
    if (is.null(wts)) {
      mean(binary) * 100
    } else {
      sum(wts * binary) / sum(wts) * 100
    }
  }

  # Helper for weighted mean among non-zero
  .wmean_nz <- function(vals, wts = weights) {
    valid <- !is.na(vals) & vals > 0
    if (sum(valid) == 0) return(0)
    if (is.null(wts)) {
      mean(vals[valid])
    } else {
      sum(wts[valid] * vals[valid]) / sum(wts[valid])
    }
  }

  # Calculate per-brand metrics
  wom_metrics <- data.frame(
    BrandCode = brand_codes,
    ReceivedPos_Pct = numeric(n_brands),
    ReceivedNeg_Pct = numeric(n_brands),
    SharedPos_Pct = numeric(n_brands),
    SharedNeg_Pct = numeric(n_brands),
    SharedPosFreq_Mean = numeric(n_brands),
    SharedNegFreq_Mean = numeric(n_brands),
    stringsAsFactors = FALSE
  )

  for (b in seq_along(brand_codes)) {
    brand <- brand_codes[b]

    # Received positive
    col <- .find_col(received_pos_prefix, brand)
    if (!is.null(col)) {
      wom_metrics$ReceivedPos_Pct[b] <- round(.wpct(data[[col]]), 1)
    }

    # Received negative
    col <- .find_col(received_neg_prefix, brand)
    if (!is.null(col)) {
      wom_metrics$ReceivedNeg_Pct[b] <- round(.wpct(data[[col]]), 1)
    }

    # Shared positive
    col <- .find_col(shared_pos_prefix, brand)
    if (!is.null(col)) {
      wom_metrics$SharedPos_Pct[b] <- round(.wpct(data[[col]]), 1)
    }

    # Shared negative
    col <- .find_col(shared_neg_prefix, brand)
    if (!is.null(col)) {
      wom_metrics$SharedNeg_Pct[b] <- round(.wpct(data[[col]]), 1)
    }

    # Shared positive frequency
    if (!is.null(shared_pos_freq_prefix)) {
      col <- .find_col(shared_pos_freq_prefix, brand)
      if (!is.null(col)) {
        wom_metrics$SharedPosFreq_Mean[b] <- round(
          .wmean_nz(data[[col]]), 1
        )
      }
    }

    # Shared negative frequency
    if (!is.null(shared_neg_freq_prefix)) {
      col <- .find_col(shared_neg_freq_prefix, brand)
      if (!is.null(col)) {
        wom_metrics$SharedNegFreq_Mean[b] <- round(
          .wmean_nz(data[[col]]), 1
        )
      }
    }
  }

  # Net balance: received positive - received negative
  net_balance <- data.frame(
    BrandCode = brand_codes,
    Net_Received = round(wom_metrics$ReceivedPos_Pct -
                          wom_metrics$ReceivedNeg_Pct, 1),
    Net_Shared = round(wom_metrics$SharedPos_Pct -
                        wom_metrics$SharedNeg_Pct, 1),
    stringsAsFactors = FALSE
  )

  # Amplification ratio: shared positive / received positive
  amplification <- data.frame(
    BrandCode = brand_codes,
    Amplification_Ratio = round(
      ifelse(wom_metrics$ReceivedPos_Pct > 0,
             wom_metrics$SharedPos_Pct / wom_metrics$ReceivedPos_Pct,
             0), 2),
    stringsAsFactors = FALSE
  )

  # Metrics summary
  focal_net <- NA_real_
  if (!is.null(focal_brand) && focal_brand %in% net_balance$BrandCode) {
    focal_net <- net_balance$Net_Received[
      net_balance$BrandCode == focal_brand
    ]
  }

  most_negative_brand <- net_balance$BrandCode[
    which.min(net_balance$Net_Received)
  ]
  most_positive_brand <- net_balance$BrandCode[
    which.max(net_balance$Net_Received)
  ]

  metrics_summary <- list(
    focal_brand = focal_brand,
    focal_net_received = focal_net,
    most_positive_brand = most_positive_brand,
    most_positive_net = max(net_balance$Net_Received),
    most_negative_brand = most_negative_brand,
    most_negative_net = min(net_balance$Net_Received),
    any_net_negative = any(net_balance$Net_Received < 0),
    n_brands = n_brands,
    n_respondents = n_resp
  )

  list(
    status = "PASS",
    wom_metrics = wom_metrics,
    net_balance = net_balance,
    amplification = amplification,
    metrics_summary = metrics_summary,
    n_respondents = n_resp,
    n_brands = n_brands
  )
}


# ==============================================================================
# V2: SLOT-INDEXED + PER-BRAND DATA-ACCESS PATH
# ==============================================================================

#' Run WOM analysis from a v2 role map and slot-indexed data
#'
#' v2 alternative to \code{run_wom()}. Reads the four mention sets via
#' \code{multi_mention_brand_matrix()} and the two count families via
#' \code{single_response_brand_matrix()}, then computes the same metrics in
#' the same shape so downstream consumers (\code{build_wom_panel_data()})
#' need no changes.
#'
#' Required role-map entries (per category):
#' \itemize{
#'   \item \code{wom.pos_rec.\{cat\}}   — Multi_Mention root, brand codes as values
#'   \item \code{wom.neg_rec.\{cat\}}   — Multi_Mention root
#'   \item \code{wom.pos_share.\{cat\}} — Multi_Mention root
#'   \item \code{wom.neg_share.\{cat\}} — Multi_Mention root
#'   \item \code{wom.pos_count.\{cat\}} — per-brand Single_Response, numeric
#'   \item \code{wom.neg_count.\{cat\}} — per-brand Single_Response, numeric
#' }
#' Missing roles produce zero columns (graceful partial output) rather than a
#' refusal, matching legacy behaviour where missing prefixes left the
#' corresponding metric at zero.
#'
#' @param data Data frame. Survey data (one row per respondent).
#' @param role_map Named list from \code{build_brand_role_map()}.
#' @param cat_code Character. Category code (e.g. \code{"DSS"}).
#' @param brand_list Data frame with \code{BrandCode} column. Order defines
#'   output row order.
#' @param focal_brand Character. Focal brand code or NULL.
#' @param weights Numeric vector of length \code{nrow(data)} or NULL.
#' @return Same shape as \code{run_wom()}: list with \code{status},
#'   \code{wom_metrics}, \code{net_balance}, \code{amplification},
#'   \code{metrics_summary}, \code{n_respondents}, \code{n_brands}.
#' @export
run_wom_v2 <- function(data, role_map, cat_code, brand_list,
                       focal_brand = NULL, weights = NULL) {
  if (is.null(data) || nrow(data) == 0L) {
    return(list(status = "REFUSED", code = "DATA_EMPTY",
                message = "No data for WOM analysis"))
  }
  brand_codes <- as.character(brand_list$BrandCode)
  n_brands <- length(brand_codes)
  n_resp <- nrow(data)

  pct_from_logical_matrix <- function(role) {
    entry <- role_map[[role]]
    if (is.null(entry) || is.null(entry$column_root))
      return(rep(0, n_brands))
    mat <- multi_mention_brand_matrix(data, entry$column_root, brand_codes)
    if (is.null(weights)) {
      colMeans(mat) * 100
    } else {
      w <- as.numeric(weights)
      colSums(mat * w) / sum(w) * 100
    }
  }

  freq_from_per_brand <- function(role) {
    entry <- role_map[[role]]
    if (is.null(entry) || is.null(entry$client_code))
      return(rep(0, n_brands))
    char_mat <- single_response_brand_matrix(data, entry$client_code,
                                             cat_code, brand_codes)
    out <- numeric(n_brands)
    for (i in seq_along(brand_codes)) {
      vals <- suppressWarnings(as.numeric(char_mat[, i]))
      sharers <- !is.na(vals) & vals > 0
      if (!any(sharers)) { out[i] <- 0; next }
      if (is.null(weights)) {
        out[i] <- mean(vals[sharers])
      } else {
        w <- as.numeric(weights)
        out[i] <- sum(w[sharers] * vals[sharers]) / sum(w[sharers])
      }
    }
    out
  }

  rp <- pct_from_logical_matrix(paste0("wom.pos_rec.",   cat_code))
  rn <- pct_from_logical_matrix(paste0("wom.neg_rec.",   cat_code))
  sp <- pct_from_logical_matrix(paste0("wom.pos_share.", cat_code))
  sn <- pct_from_logical_matrix(paste0("wom.neg_share.", cat_code))
  pf <- freq_from_per_brand(    paste0("wom.pos_count.", cat_code))
  nf <- freq_from_per_brand(    paste0("wom.neg_count.", cat_code))

  wom_metrics <- data.frame(
    BrandCode          = brand_codes,
    ReceivedPos_Pct    = round(rp, 1),
    ReceivedNeg_Pct    = round(rn, 1),
    SharedPos_Pct      = round(sp, 1),
    SharedNeg_Pct      = round(sn, 1),
    SharedPosFreq_Mean = round(pf, 1),
    SharedNegFreq_Mean = round(nf, 1),
    stringsAsFactors = FALSE
  )

  net_balance <- data.frame(
    BrandCode    = brand_codes,
    Net_Received = round(wom_metrics$ReceivedPos_Pct -
                          wom_metrics$ReceivedNeg_Pct, 1),
    Net_Shared   = round(wom_metrics$SharedPos_Pct -
                          wom_metrics$SharedNeg_Pct, 1),
    stringsAsFactors = FALSE
  )

  amplification <- data.frame(
    BrandCode = brand_codes,
    Amplification_Ratio = round(
      ifelse(wom_metrics$ReceivedPos_Pct > 0,
             wom_metrics$SharedPos_Pct / wom_metrics$ReceivedPos_Pct,
             0), 2),
    stringsAsFactors = FALSE
  )

  focal_net <- NA_real_
  if (!is.null(focal_brand) && focal_brand %in% net_balance$BrandCode) {
    focal_net <- net_balance$Net_Received[
      net_balance$BrandCode == focal_brand]
  }

  metrics_summary <- list(
    focal_brand         = focal_brand,
    focal_net_received  = focal_net,
    most_positive_brand = net_balance$BrandCode[
      which.max(net_balance$Net_Received)],
    most_positive_net   = max(net_balance$Net_Received),
    most_negative_brand = net_balance$BrandCode[
      which.min(net_balance$Net_Received)],
    most_negative_net   = min(net_balance$Net_Received),
    any_net_negative    = any(net_balance$Net_Received < 0),
    n_brands            = n_brands,
    n_respondents       = n_resp
  )

  list(
    status          = "PASS",
    wom_metrics     = wom_metrics,
    net_balance     = net_balance,
    amplification   = amplification,
    metrics_summary = metrics_summary,
    n_respondents   = n_resp,
    n_brands        = n_brands
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand WOM element loaded (v%s)", WOM_VERSION))
}
