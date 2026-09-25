# ==============================================================================
# TURAS PRICING MODULE - POINT ELASTICITY (DIRECT API)
# ==============================================================================
#
# Purpose: compute_point_elasticity(), the console function USER_MANUAL.md
#          documents, and the interpolator it uses. Not called by the pipeline.
#          The constrained-optimisation, trade-off, Pareto and scenario
#          functions that shared this file had no caller anywhere and were
#          removed on 25 Sep 2026 (robustness follow-up).
# Version: 12.0
#
# ==============================================================================

#' Create Demand Interpolator Function
#'
#' Creates a function that interpolates demand at any price point
#' using monotone cubic spline.
#'
#' @param prices Vector of known prices
#' @param intent Vector of purchase intent values
#' @return Function that takes price(s) and returns interpolated demand
#' @keywords internal
create_demand_interpolator <- function(prices, intent) {
  # Use monotone spline interpolation
  # splinefun with method "monoH.FC" ensures monotonicity

  # First ensure monotonicity in the input data
  n <- length(intent)
  y <- intent

  # Simple isotonic regression to ensure decreasing
  for (i in 2:n) {
    if (y[i] > y[i-1]) {
      y[i] <- y[i-1]
    }
  }

  # Create spline function
  tryCatch({
    spline_func <- splinefun(prices, y, method = "monoH.FC")

    # Wrapper to bound output
    function(p) {
      result <- spline_func(p)
      pmax(0, pmin(1, result))
    }
  }, error = function(e) {
    # Fallback to linear interpolation
    function(p) {
      approx(prices, y, xout = p, rule = 2)$y
    }
  })
}


#' Compute Point Price Elasticity of Demand
#'
#' Calculates point elasticity at specific prices using the derivative
#' of the interpolated demand function. Unlike arc elasticity (which
#' averages between two price points), point elasticity gives the
#' instantaneous responsiveness of demand to a price change.
#'
#' @param demand_curve Demand curve from Gabor-Granger (price + purchase_intent)
#' @param prices_to_evaluate Numeric vector of prices at which to compute elasticity.
#'   If NULL, evaluates at all prices in the demand curve plus midpoints.
#' @param delta Small price increment for numerical derivative (default 0.01)
#'
#' @return Data frame with columns: price, purchase_intent, elasticity,
#'   elasticity_type, revenue_index, marginal_revenue
#'
#' @details
#' Point elasticity is computed as:
#'   E(p) = (dQ/dP) * (P/Q)
#'
#' where dQ/dP is approximated via central difference on the monotone
#' spline interpolator. This is more precise than arc elasticity when
#' price points are coarsely spaced.
#'
#' The function also computes marginal revenue at each price:
#'   MR(p) = Q(p) + p * dQ/dP
#'
#' Revenue is maximized where MR = 0, i.e., where elasticity = -1.
#'
#' @export
compute_point_elasticity <- function(demand_curve,
                                     prices_to_evaluate = NULL,
                                     delta = 0.01) {

  prices <- demand_curve$price
  intent <- demand_curve$purchase_intent

  # Remove NAs
  valid <- !is.na(prices) & !is.na(intent)
  prices <- prices[valid]
  intent <- intent[valid]

  if (length(prices) < 3) {
    pricing_refuse(
      code = "DATA_INSUFFICIENT_POINTS",
      title = "Insufficient Data for Point Elasticity",
      problem = sprintf("Need at least 3 price points, got %d", length(prices)),
      why_it_matters = "Point elasticity requires a smooth demand curve interpolation",
      how_to_fix = "Ensure demand_curve has at least 3 non-NA price/intent rows",
      expected = "3+ price points"
    )
  }

  # Build interpolator
  intent_func <- create_demand_interpolator(prices, intent)

  # Default evaluation grid: original prices plus midpoints
  if (is.null(prices_to_evaluate)) {
    midpoints <- (prices[-length(prices)] + prices[-1]) / 2
    prices_to_evaluate <- sort(unique(c(prices, midpoints)))
  }

  # Clamp to data range
  p_min <- min(prices)
  p_max <- max(prices)
  prices_to_evaluate <- prices_to_evaluate[prices_to_evaluate >= p_min &
                                             prices_to_evaluate <= p_max]

  # Compute elasticity at each price
  n_eval <- length(prices_to_evaluate)
  result <- data.frame(
    price = prices_to_evaluate,
    purchase_intent = numeric(n_eval),
    elasticity = numeric(n_eval),
    elasticity_type = character(n_eval),
    revenue_index = numeric(n_eval),
    marginal_revenue = numeric(n_eval),
    stringsAsFactors = FALSE
  )

  for (i in seq_len(n_eval)) {
    p <- prices_to_evaluate[i]
    q <- intent_func(p)

    # Central difference for dQ/dP
    p_lo <- max(p_min, p - delta)
    p_hi <- min(p_max, p + delta)
    dq_dp <- (intent_func(p_hi) - intent_func(p_lo)) / (p_hi - p_lo)

    # Point elasticity: E = (dQ/dP) * (P/Q)
    if (q > 1e-10) {
      elast <- dq_dp * (p / q)
    } else {
      elast <- NA_real_
    }

    # Marginal revenue: MR = Q + P * dQ/dP
    mr <- q + p * dq_dp

    result$purchase_intent[i] <- q
    result$elasticity[i] <- round(elast, 4)
    result$revenue_index[i] <- round(p * q, 4)
    result$marginal_revenue[i] <- round(mr, 6)
  }

  # Classify
  result$elasticity_type <- ifelse(
    is.na(result$elasticity), "Undefined",
    ifelse(abs(result$elasticity) > 1, "Elastic",
           ifelse(abs(result$elasticity) < 1, "Inelastic", "Unit Elastic"))
  )

  # Find revenue-maximizing price (where MR crosses zero)
  mr_vals <- result$marginal_revenue[!is.na(result$marginal_revenue)]
  if (length(mr_vals) >= 2) {
    sign_changes <- which(diff(sign(mr_vals)) != 0)
    if (length(sign_changes) > 0) {
      # Linear interpolation to find zero crossing
      idx <- sign_changes[1]
      valid_mr <- result[!is.na(result$marginal_revenue), ]
      p1 <- valid_mr$price[idx]
      p2 <- valid_mr$price[idx + 1]
      mr1 <- valid_mr$marginal_revenue[idx]
      mr2 <- valid_mr$marginal_revenue[idx + 1]
      rev_max_price <- p1 + (0 - mr1) * (p2 - p1) / (mr2 - mr1)
      attr(result, "revenue_maximizing_price") <- round(rev_max_price, 2)
    }
  }

  attr(result, "method") <- "point_elasticity_central_difference"
  attr(result, "delta") <- delta

  return(result)
}
