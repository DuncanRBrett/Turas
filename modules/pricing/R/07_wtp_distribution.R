# ==============================================================================
# TURAS PRICING MODULE - WILLINGNESS-TO-PAY DISTRIBUTION
# ==============================================================================
#
# Purpose: Extract and analyze WTP distributions from pricing data
# Version: 1.0.0
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
  wtp_df <- wtp_df[!is.na(wtp_df$wtp) & is.finite(wtp_df$wtp) & wtp_df$weight > 0, ]

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
  wtp_df <- wtp_df[!is.na(wtp_df$wtp) & is.finite(wtp_df$wtp) & wtp_df$weight > 0, ]

  return(wtp_df)
}


#' Compute WTP Density Estimate
#'
#' Calculates weighted kernel density estimate of WTP distribution.
#'
#' @param wtp_df Data frame from extract_wtp_vw() or extract_wtp_gg()
#' @param from,to Optional numeric range for density
#' @param n Number of grid points (default: 512)
#' @param bw Bandwidth (optional, auto-selected if NULL)
#'
#' @return Data frame with columns x (price grid) and density
#'
#' @export
compute_wtp_density <- function(wtp_df, from = NULL, to = NULL, n = 512, bw = NULL) {

  w <- wtp_df$weight
  x <- wtp_df$wtp

  # Normalize weights
  w <- w / sum(w, na.rm = TRUE)

  # Auto-select range if not provided
  if (is.null(from)) from <- min(x, na.rm = TRUE)
  if (is.null(to))   to   <- max(x, na.rm = TRUE)

  # Auto-select bandwidth if not provided
  if (is.null(bw)) bw <- stats::bw.nrd0(x)

  # Create price grid
  grid <- seq(from, to, length.out = n)

  # Weighted Gaussian kernel density
  dens <- sapply(grid, function(g) {
    z <- (g - x) / bw
    sum(w * stats::dnorm(z)) / bw
  })

  data.frame(
    x = grid,
    density = dens,
    stringsAsFactors = FALSE
  )
}


#' Compute WTP Percentiles
#'
#' Calculates weighted percentiles of WTP distribution.
#'
#' @param wtp_df Data frame from extract_wtp_vw() or extract_wtp_gg()
#' @param probs Numeric vector of probabilities (default: quartiles and key percentiles)
#'
#' @return Named numeric vector of percentiles
#'
#' @export
compute_wtp_percentiles <- function(wtp_df, probs = c(.05, .10, .25, .50, .75, .90, .95)) {

  x <- wtp_df$wtp
  w <- wtp_df$weight

  # Sort by WTP
  o <- order(x)
  x <- x[o]
  w <- w[o] / sum(w[o], na.rm = TRUE)

  # Cumulative weights
  cw <- cumsum(w)

  # Find percentiles
  q <- sapply(probs, function(p) {
    idx <- which(cw >= p)[1]
    if (is.na(idx)) return(NA_real_)
    x[idx]
  })

  names(q) <- paste0("p", sprintf("%02d", round(probs * 100)))
  return(q)
}


#' Compute WTP Summary Statistics
#'
#' Calculates descriptive statistics for WTP distribution.
#'
#' @param wtp_df Data frame from extract_wtp_vw() or extract_wtp_gg()
#'
#' @return Data frame with summary statistics
#'
#' @export
compute_wtp_summary <- function(wtp_df) {

  x <- wtp_df$wtp
  w <- wtp_df$weight
  w_norm <- w / sum(w)

  # Weighted statistics
  mean_wtp <- sum(x * w_norm)
  var_wtp <- sum(w_norm * (x - mean_wtp)^2)
  sd_wtp <- sqrt(var_wtp)

  # Guard against empty vector before calculating summary statistics
  n_obs <- length(x)
  if (n_obs == 0) {
    return(data.frame(
      n = 0L,
      effective_n = 0,
      mean = NA_real_,
      median = NA_real_,
      sd = NA_real_,
      min = NA_real_,
      max = NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  # Unweighted median (weighted median is complex)
  median_wtp <- median(x)

  data.frame(
    n = n_obs,
    effective_n = sum(w),
    mean = mean_wtp,
    median = median_wtp,
    sd = sd_wtp,
    min = min(x),
    max = max(x),
    stringsAsFactors = FALSE
  )
}


#' Plot WTP Distribution
#'
#' Creates density plot with percentile markers.
#'
#' @param wtp_df Data frame from extract_wtp_vw() or extract_wtp_gg()
#' @param show_percentiles Logical; show key percentile lines?
#' @param title Plot title
#'
#' @return ggplot object (if ggplot2 available), otherwise NULL with message
#'
#' @export
plot_wtp_distribution <- function(wtp_df, show_percentiles = TRUE, title = "Willingness-to-Pay Distribution") {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    message("ggplot2 package required for plotting. Install with: install.packages('ggplot2')")
    return(invisible(NULL))
  }

  # Compute density
  dens <- compute_wtp_density(wtp_df)

  # Create base plot
  p <- ggplot2::ggplot(dens, ggplot2::aes(x = x, y = density)) +
    ggplot2::geom_line(color = "steelblue", size = 1) +
    ggplot2::geom_area(fill = "steelblue", alpha = 0.3) +
    ggplot2::labs(
      title = title,
      x = "Price",
      y = "Density"
    ) +
    ggplot2::theme_minimal()

  # Add percentile lines if requested
  if (show_percentiles) {
    pct <- compute_wtp_percentiles(wtp_df, probs = c(.25, .50, .75))
    p <- p +
      ggplot2::geom_vline(xintercept = pct["p50"], linetype = "dashed", color = "darkred", size = 0.8) +
      ggplot2::geom_vline(xintercept = pct[c("p25", "p75")], linetype = "dotted", color = "gray40") +
      ggplot2::annotate("text", x = pct["p50"], y = max(dens$density) * 0.95,
                        label = sprintf("Median: $%.2f", pct["p50"]),
                        hjust = -0.1, color = "darkred", size = 3.5)
  }

  return(p)
}
