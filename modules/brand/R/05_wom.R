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
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand WOM element loaded (v%s)", WOM_VERSION))
}
