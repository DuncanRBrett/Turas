# ==============================================================================
# TURAS PRICING MODULE - WILLINGNESS-TO-PAY DISTRIBUTION
# ==============================================================================
#
# Purpose: Per-respondent willingness to pay, for the tabs export's WTP column
# Version: 12.0
# Date: 2025-12-01
#
# ==============================================================================

#' Extract WTP Distribution from Van Westendorp
#'
#' Derives individual-level WTP from Van Westendorp price thresholds.
#' Uses the midpoint between "cheap" and "expensive" thresholds as WTP proxy.
#'
#' @param data Data frame with Van Westendorp responses
#' @param config Configuration list
#' @param method "median" (default) or "mean" for combining cheap/expensive
#'
#' @return Data frame with columns: id, wtp, weight, plus any segment variables
#'
#' @export
extract_wtp_vw <- function(data, config, method = "median") {

  method <- match.arg(method, c("median", "mean"))
  vw <- config$van_westendorp

  # Get respondent ID
  if (!is.na(config$id_var) && config$id_var %in% names(data)) {
    id <- data[[config$id_var]]
  } else {
    id <- seq_len(nrow(data))
  }

  # Extract price thresholds
  cheap <- data[[vw$col_cheap]]
  expensive <- data[[vw$col_expensive]]

  # Calculate WTP as midpoint between cheap and expensive
  comb_fun <- if (method == "median") median else mean
  wtp <- mapply(
    function(ch, ex) {
      vals <- c(ch, ex)
      if (all(is.na(vals))) return(NA_real_)
      comb_fun(vals, na.rm = TRUE)
    },
    cheap, expensive
  )

  # Extract weights
  if (!is.na(config$weight_var) && config$weight_var %in% names(data)) {
    weight <- data[[config$weight_var]]
  } else {
    weight <- rep(1, length(wtp))
  }

  # Build result data frame
  wtp_df <- data.frame(
    id = id,
    wtp = as.numeric(wtp),
    weight = as.numeric(weight),
    stringsAsFactors = FALSE
  )

  # Add segment variables if specified
  if (length(config$segment_vars) > 0) {
    for (seg_var in config$segment_vars) {
      if (seg_var %in% names(data)) {
        wtp_df[[seg_var]] <- data[[seg_var]]
      }
    }
  }

  # Remove missing WTP
  # which(): a blank weight compares NA, and an NA in a logical index adds a
  # junk all-NA row, which then broke the tabs export's id match ("NAs are
  # not allowed in subscripted assignments") and lost the whole file
  # (robustness gate, 25 Sep 2026).
  wtp_df <- wtp_df[which(!is.na(wtp_df$wtp) & is.finite(wtp_df$wtp) & wtp_df$weight > 0), ]

  return(wtp_df)
}


#' Extract WTP Distribution from Gabor-Granger
#'
#' Derives WTP as the highest price at which respondent indicates purchase intent.
#'
#' @param gg_data Long-format Gabor-Granger data (from prepare_gg_* functions)
#' @param config Configuration list
#'
#' @return Data frame with columns: id, wtp, weight, plus any segment variables
#'
#' @export
extract_wtp_gg <- function(gg_data, config) {

  # Group by respondent and find max price with purchase intent > 0
  respondents <- unique(gg_data$respondent_id)

  wtp_list <- lapply(respondents, function(rid) {
    resp_data <- gg_data[gg_data$respondent_id == rid, ]
    resp_data <- resp_data[!is.na(resp_data$response), ]

    # Find highest price with positive purchase intent
    positive <- resp_data[resp_data$response > 0, ]
    if (nrow(positive) > 0) {
      wtp_val <- max(positive$price)
    } else {
      wtp_val <- NA_real_
    }

    # Get weight (should be same for all rows of this respondent)
    weight_val <- if ("weight" %in% names(resp_data)) {
      resp_data$weight[1]
    } else {
      1
    }

    data.frame(
      id = rid,
      wtp = wtp_val,
      weight = weight_val,
      stringsAsFactors = FALSE
    )
  })

  wtp_df <- do.call(rbind, wtp_list)

  # Remove missing WTP
  # which(): a blank weight compares NA, and an NA in a logical index adds a
  # junk all-NA row, which then broke the tabs export's id match ("NAs are
  # not allowed in subscripted assignments") and lost the whole file
  # (robustness gate, 25 Sep 2026).
  wtp_df <- wtp_df[which(!is.na(wtp_df$wtp) & is.finite(wtp_df$wtp) & wtp_df$weight > 0), ]

  return(wtp_df)
}


