# ==============================================================================
# TURAS PRICING MODULE - GABOR-GRANGER ANALYSIS
# ==============================================================================
#
# Purpose: Implement Gabor-Granger pricing methodology
# Version: 1.0.0
# Date: 2025-11-18
#
# References:
# - Gabor, A., & Granger, C. W. J. (1966). Price as an indicator of quality
#
# ==============================================================================

#' Run Gabor-Granger Analysis
#'
#' Analyzes sequential purchase intent at various price points to construct
#' demand curve and find revenue-maximizing price.
#'
#' @param data Data frame containing purchase intent responses
#' @param config Configuration list with Gabor-Granger settings
#'
#' @return List containing demand curve, revenue curve, optimal price, and diagnostics
#'
#' @keywords internal
run_gabor_granger <- function(data, config) {

  gg <- config$gabor_granger

  # Prepare data based on format
  if (gg$data_format == "wide") {
    gg_data <- prepare_gg_wide_data(data, gg, config)
  } else {
    gg_data <- prepare_gg_long_data(data, gg, config)
  }

  n_respondents <- length(unique(gg_data$respondent_id))
  n_prices <- length(unique(gg_data$price))

  if (n_respondents < 30) {
    warning(sprintf("Low sample size for Gabor-Granger analysis: n=%d (recommended minimum: 30)",
                    n_respondents), call. = FALSE)
  }

  # Check monotonicity if requested
  monotonicity_check <- NULL
  if (isTRUE(gg$check_monotonicity)) {
    monotonicity_check <- check_gg_monotonicity(gg_data)
    if (monotonicity_check$violations > 0) {
      warning(sprintf("%d respondents (%.1f%%) showed non-monotonic purchase intent",
                      monotonicity_check$violations,
                      monotonicity_check$violation_rate * 100),
              call. = FALSE)
    }
  }

  # Calculate demand curve
  demand_curve <- calculate_demand_curve(gg_data)

  # Apply monotone smoothing if configured
  if (config$gg_monotonicity_behavior == "smooth") {
    # Enforce monotone decreasing demand: as price increases, demand should not increase
    # Simple approach: cummax from high price to low price
    demand_curve <- demand_curve[order(demand_curve$price, decreasing = TRUE), ]
    demand_curve$purchase_intent <- cummax(demand_curve$purchase_intent)
    demand_curve <- demand_curve[order(demand_curve$price), ]  # Back to ascending order
  }

  # Calculate revenue curve (and profit if unit_cost specified)
  revenue_curve <- calculate_revenue_curve(demand_curve, unit_cost = config$unit_cost)

  # Find optimal price (revenue or profit)
  optimal_price <- NULL
  optimal_price_profit <- NULL
  if (isTRUE(gg$revenue_optimization)) {
    optimal_price <- find_optimal_price(revenue_curve, metric = "revenue")
    # Also find profit-maximizing price if profit was calculated
    if ("profit_index" %in% names(revenue_curve)) {
      optimal_price_profit <- find_optimal_price(revenue_curve, metric = "profit")
    }
  }

  # Calculate elasticity
  elasticity <- NULL
  if (isTRUE(gg$calculate_elasticity)) {
    elasticity <- calculate_price_elasticity(demand_curve)
  }

  # Calculate confidence intervals
  confidence_intervals <- NULL
  if (isTRUE(gg$confidence_intervals)) {
    confidence_intervals <- bootstrap_gg_confidence(
      gg_data,
      iterations = gg$bootstrap_iterations %||% 1000,
      level = gg$confidence_level %||% 0.95
    )
  }

  # Return results
  list(
    demand_curve = demand_curve,
    revenue_curve = revenue_curve,
    optimal_price = optimal_price,
    optimal_price_profit = optimal_price_profit,
    elasticity = elasticity,
    confidence_intervals = confidence_intervals,
    diagnostics = list(
      n_respondents = n_respondents,
      n_price_points = n_prices,
      monotonicity_check = monotonicity_check,
      price_range = range(gg_data$price),
      method = "gabor_granger",
      has_profit = "profit_index" %in% names(revenue_curve)
    )
  )
}


#' Prepare Gabor-Granger Data (Wide Format)
#'
#' Converts wide format survey data to long format for analysis.
#'
#' @param data Data frame in wide format
#' @param gg_config Gabor-Granger configuration
#' @param main_config Main configuration (for weight_var)
#'
#' @return Data frame in long format with respondent_id, price, response, weight columns
#'
#' @keywords internal
prepare_gg_wide_data <- function(data, gg_config, main_config) {

  prices <- gg_config$price_sequence
  response_cols <- gg_config$response_columns

  if (length(prices) != length(response_cols)) {
    stop(sprintf("Number of prices (%d) must match number of response columns (%d)",
                 length(prices), length(response_cols)),
         call. = FALSE)
  }

  # Create respondent IDs if not present
  if (is.null(gg_config$respondent_column) || is.na(gg_config$respondent_column)) {
    data$respondent_id <- seq_len(nrow(data))
  } else {
    data$respondent_id <- data[[gg_config$respondent_column]]
  }

  # Extract weights (if specified)
  if (!is.na(main_config$weight_var) && main_config$weight_var %in% names(data)) {
    data$weight <- data[[main_config$weight_var]]
  } else {
    data$weight <- 1
  }

  # Reshape to long format
  long_data <- data.frame()

  for (i in seq_along(prices)) {
    temp <- data.frame(
      respondent_id = data$respondent_id,
      price = prices[i],
      response = data[[response_cols[i]]],
      weight = data$weight,
      stringsAsFactors = FALSE
    )
    long_data <- rbind(long_data, temp)
  }

  # Code responses as binary if needed
  long_data$response <- code_gg_response(long_data$response, gg_config)

  return(long_data)
}


#' Prepare Gabor-Granger Data (Long Format)
#'
#' Validates and standardizes long format data for analysis.
#'
#' @param data Data frame in long format
#' @param gg_config Gabor-Granger configuration
#' @param main_config Main configuration (for weight_var)
#'
#' @return Standardized data frame
#'
#' @keywords internal
prepare_gg_long_data <- function(data, gg_config, main_config) {

  # Extract weights (if specified)
  if (!is.na(main_config$weight_var) && main_config$weight_var %in% names(data)) {
    weight <- data[[main_config$weight_var]]
  } else {
    weight <- 1
  }

  long_data <- data.frame(
    respondent_id = data[[gg_config$respondent_column]],
    price = as.numeric(data[[gg_config$price_column]]),
    response = data[[gg_config$response_column]],
    weight = weight,
    stringsAsFactors = FALSE
  )

  # Code responses as binary
  long_data$response <- code_gg_response(long_data$response, gg_config)

  return(long_data)
}


#' Code Gabor-Granger Responses as Binary
#'
#' Converts various response formats to binary (0/1) purchase intent.
#'
#' @param response Vector of responses
#' @param config Configuration with response coding settings
#'
#' @return Numeric vector of 0/1 values
#'
#' @keywords internal
code_gg_response <- function(response, config) {

  response_type <- config$response_type %||% "binary"

  if (response_type == "binary") {
    # Already binary or convert common values
    if (is.logical(response)) {
      return(as.numeric(response))
    }

    if (is.numeric(response)) {
      return(as.numeric(response > 0))
    }

    # Handle text responses
    positive_values <- c("1", "yes", "y", "true", "Yes", "YES", "Y", "TRUE")
    return(as.numeric(tolower(as.character(response)) %in% tolower(positive_values)))

  } else if (response_type == "scale") {
    # Top-box coding for scale responses
    threshold <- config$scale_threshold %||% 3
    return(as.numeric(as.numeric(response) >= threshold))

  } else {
    # Auto-detect
    if (is.numeric(response)) {
      max_val <- max(response, na.rm = TRUE)
      if (max_val <= 1) {
        return(as.numeric(response))
      } else {
        # Assume scale - use top 2 boxes on 5-point scale
        threshold <- ceiling(max_val * 0.6)
        return(as.numeric(response >= threshold))
      }
    } else {
      return(as.numeric(tolower(as.character(response)) %in%
                          c("1", "yes", "y", "true")))
    }
  }
}


#' Check Gabor-Granger Monotonicity
#'
#' Checks if purchase intent decreases monotonically with price for each respondent.
#'
#' @param gg_data Long format Gabor-Granger data
#'
#' @return List with violation counts and rates
#'
#' @keywords internal
check_gg_monotonicity <- function(gg_data) {

  # Check for each respondent
  respondents <- unique(gg_data$respondent_id)
  violations <- 0

  for (resp in respondents) {
    resp_data <- gg_data[gg_data$respondent_id == resp, ]
    resp_data <- resp_data[order(resp_data$price), ]

    # Check if any response increases with price
    # (purchase intent should decrease or stay same as price increases)
    diffs <- diff(resp_data$response)
    if (any(diffs > 0, na.rm = TRUE)) {
      violations <- violations + 1
    }
  }

  list(
    violations = violations,
    n_respondents = length(respondents),
    violation_rate = violations / length(respondents)
  )
}


#' Calculate Demand Curve
#'
#' Aggregates purchase intent at each price point to create demand curve.
#'
#' @param gg_data Long format Gabor-Granger data (must include weight column)
#'
#' @return Data frame with price and weighted purchase intent percentage
#'
#' @keywords internal
calculate_demand_curve <- function(gg_data) {

  # Aggregate by price
  prices <- sort(unique(gg_data$price))

  demand <- data.frame(
    price = prices,
    n_respondents = integer(length(prices)),
    effective_n = numeric(length(prices)),
    n_purchase = numeric(length(prices)),
    purchase_intent = numeric(length(prices)),
    stringsAsFactors = FALSE
  )

  for (i in seq_along(prices)) {
    p <- prices[i]
    subset_data <- gg_data[gg_data$price == p & !is.na(gg_data$response), ]

    if (nrow(subset_data) > 0) {
      weights <- subset_data$weight
      responses <- subset_data$response

      demand$n_respondents[i] <- nrow(subset_data)
      demand$effective_n[i] <- sum(weights)
      demand$n_purchase[i] <- sum(weights * responses)
      # Weighted purchase intent
      demand$purchase_intent[i] <- sum(weights * responses) / sum(weights)
    } else {
      demand$n_respondents[i] <- 0
      demand$effective_n[i] <- 0
      demand$n_purchase[i] <- 0
      demand$purchase_intent[i] <- NA_real_
    }
  }

  return(demand)
}


# ==============================================================================
# DEMAND CURVE SMOOTHING OPTIONS
# ==============================================================================

#' Smooth Demand Curve
#'
#' Applies smoothing to demand curve to reduce noise while enforcing monotonicity.
#' Multiple algorithms available for different use cases.
#'
#' @param demand_curve Data frame from calculate_demand_curve()
#' @param method Smoothing method: "none", "cummax", "isotonic", "loess", "pava"
#' @param span LOESS span parameter (0-1, default 0.75). Lower = less smoothing.
#' @param preserve_endpoints Logical, if TRUE keeps first/last points unchanged
#' @param verbose Logical, print smoothing diagnostics
#'
#' @return Data frame with smoothed purchase_intent column and original values
#'   preserved in purchase_intent_raw
#'
#' @details
#' Smoothing methods:
#' - "none": No smoothing, raw data returned
#' - "cummax": Simple cumulative maximum (fast, but can create steps)
#' - "isotonic": Pool Adjacent Violators Algorithm (PAVA) - best for monotonicity
#' - "loess": Local polynomial regression with post-hoc monotonicity enforcement
#' - "pava": Alias for "isotonic"
#'
#' The isotonic/PAVA method is recommended for most cases as it:
#' 1. Guarantees monotonically decreasing output
#' 2. Minimizes squared deviations from original data
#' 3. Is statistically optimal for monotone regression
#'
#' @export
#' @examples
#' # Apply isotonic smoothing to noisy demand curve
#' smoothed <- smooth_demand_curve(demand_curve, method = "isotonic")
#'
#' # Apply LOESS for more aggressive smoothing
#' smoothed <- smooth_demand_curve(demand_curve, method = "loess", span = 0.5)
smooth_demand_curve <- function(demand_curve,
                                 method = c("isotonic", "cummax", "loess", "pava", "none"),
                                 span = 0.75,
                                 preserve_endpoints = FALSE,
                                 verbose = FALSE) {

  method <- match.arg(method)

  # Handle pava as alias for isotonic

  if (method == "pava") method <- "isotonic"

  # Store original values
  demand_curve$purchase_intent_raw <- demand_curve$purchase_intent

  if (method == "none") {
    if (verbose) message("Smoothing: none (raw data)")
    return(demand_curve)
  }

  # Remove NA values for smoothing
  valid_idx <- !is.na(demand_curve$purchase_intent)
  if (sum(valid_idx) < 3) {
    warning("Insufficient valid data points for smoothing", call. = FALSE)
    return(demand_curve)
  }

  prices <- demand_curve$price[valid_idx]
  intent <- demand_curve$purchase_intent[valid_idx]

  # Apply smoothing method
  smoothed <- switch(method,
    "cummax" = smooth_cummax(prices, intent, verbose),
    "isotonic" = smooth_isotonic(prices, intent, verbose),
    "loess" = smooth_loess_monotone(prices, intent, span, verbose)
  )

  # Preserve endpoints if requested
  if (preserve_endpoints && length(smoothed) > 2) {
    smoothed[1] <- intent[1]
    smoothed[length(smoothed)] <- intent[length(smoothed)]
  }

  # Update demand curve with smoothed values
  demand_curve$purchase_intent[valid_idx] <- smoothed

  # Add smoothing metadata
  attr(demand_curve, "smoothing_method") <- method
  attr(demand_curve, "smoothing_span") <- if (method == "loess") span else NA

  if (verbose) {
    rmse <- sqrt(mean((intent - smoothed)^2))
    message(sprintf("Smoothing RMSE: %.4f", rmse))
  }

  return(demand_curve)
}


#' Cumulative Maximum Smoothing (Simple)
#'
#' Enforces monotonicity using cumulative maximum from high to low price.
#' Fast but can create step-like patterns.
#'
#' @param prices Numeric vector of prices (ascending order)
#' @param intent Numeric vector of purchase intent values
#' @param verbose Logical, print diagnostics
#' @return Smoothed purchase intent vector
#' @keywords internal
smooth_cummax <- function(prices, intent, verbose = FALSE) {
  # Reverse to go from high price to low price
  n <- length(intent)
  rev_intent <- intent[n:1]

  # Cumulative maximum ensures monotonically increasing (from high to low price)
  # which means monotonically decreasing from low to high price
  smoothed_rev <- cummax(rev_intent)

  # Reverse back
  smoothed <- smoothed_rev[n:1]

  if (verbose) {
    n_adjusted <- sum(smoothed != intent)
    message(sprintf("Cummax smoothing: %d of %d points adjusted", n_adjusted, n))
  }

  return(smoothed)
}


#' Isotonic Regression Smoothing (PAVA)
#'
#' Pool Adjacent Violators Algorithm for monotone regression.
#' Optimal in the sense of minimizing squared error subject to monotonicity.
#'
#' @param prices Numeric vector of prices (ascending order)
#' @param intent Numeric vector of purchase intent values
#' @param verbose Logical, print diagnostics
#' @return Smoothed purchase intent vector (monotonically decreasing with price)
#' @keywords internal
smooth_isotonic <- function(prices, intent, verbose = FALSE) {
  n <- length(intent)

  if (n <= 1) return(intent)

  # PAVA for monotonically DECREASING function
  # We want: intent[1] >= intent[2] >= ... >= intent[n] as price increases

  # Initialize with original values
  y <- intent
  w <- rep(1, n)  # weights (could be sample sizes if weighted)

  # Pool adjacent violators
  # Work from left to right, pooling when violation found
  i <- 1
  while (i < n) {
    if (y[i] < y[i + 1]) {
      # Violation: demand increased with price
      # Pool blocks
      j <- i + 1

      # Find extent of violation
      while (j <= n && y[i] < y[j]) {
        j <- j + 1
      }
      j <- j - 1

      # Pool all points from i to j
      # Weighted mean of pooled block
      pooled_sum <- sum(y[i:j] * w[i:j])
      pooled_weight <- sum(w[i:j])
      pooled_mean <- pooled_sum / pooled_weight

      # Assign pooled value
      y[i:j] <- pooled_mean
      w[i:j] <- pooled_weight / (j - i + 1)

      # Step back to check for new violations
      if (i > 1) i <- i - 1
    } else {
      i <- i + 1
    }
  }

  if (verbose) {
    n_adjusted <- sum(abs(y - intent) > 1e-10)
    message(sprintf("Isotonic smoothing (PAVA): %d of %d points adjusted", n_adjusted, n))
  }

  return(y)
}


#' LOESS Smoothing with Monotonicity Enforcement
#'
#' Local polynomial regression followed by isotonic projection.
#' Good for noisy data where underlying curve is smooth.
#'
#' @param prices Numeric vector of prices
#' @param intent Numeric vector of purchase intent values
#' @param span LOESS span parameter (0-1)
#' @param verbose Logical, print diagnostics
#' @return Smoothed purchase intent vector
#' @keywords internal
smooth_loess_monotone <- function(prices, intent, span = 0.75, verbose = FALSE) {
  n <- length(intent)

  if (n < 4) {
    # Not enough points for LOESS, fall back to isotonic
    if (verbose) message("Too few points for LOESS, using isotonic")
    return(smooth_isotonic(prices, intent, verbose))
  }

  # Fit LOESS
  tryCatch({
    loess_fit <- loess(intent ~ prices, span = span, degree = 1)
    loess_pred <- predict(loess_fit, newdata = data.frame(prices = prices))

    # Bound predictions to [0, 1]
    loess_pred <- pmax(0, pmin(1, loess_pred))

    # Apply isotonic regression to enforce monotonicity
    smoothed <- smooth_isotonic(prices, loess_pred, verbose = FALSE)

    if (verbose) {
      message(sprintf("LOESS smoothing (span=%.2f) with isotonic projection", span))
    }

    return(smoothed)

  }, error = function(e) {
    warning("LOESS smoothing failed, falling back to isotonic: ", e$message,
            call. = FALSE)
    return(smooth_isotonic(prices, intent, verbose))
  })
}


#' Interpolate Demand Curve to Finer Price Grid
#'
#' Creates a smooth demand curve at arbitrary price points using
#' monotone interpolation (monotone cubic spline).
#'
#' @param demand_curve Data frame with price and purchase_intent columns
#' @param new_prices Numeric vector of prices to interpolate at
#' @param method Interpolation method: "linear", "spline", "pchip"
#'
#' @return Data frame with interpolated demand at new_prices
#'
#' @details
#' Methods:
#' - "linear": Linear interpolation between points (preserves monotonicity)
#' - "spline": Cubic spline with post-hoc monotonicity enforcement
#' - "pchip": Piecewise Cubic Hermite Interpolating Polynomial (monotone)
#'
#' @export
interpolate_demand_curve <- function(demand_curve,
                                      new_prices,
                                      method = c("linear", "spline", "pchip")) {

  method <- match.arg(method)

  prices <- demand_curve$price
  intent <- demand_curve$purchase_intent

  # Remove NA values
  valid <- !is.na(intent)
  prices <- prices[valid]
  intent <- intent[valid]

  if (length(prices) < 2) {
    stop("Need at least 2 valid data points for interpolation", call. = FALSE)
  }

  # Interpolate based on method
  if (method == "linear") {
    interp <- approx(prices, intent, xout = new_prices, rule = 2)$y

  } else if (method == "spline") {
    # Cubic spline interpolation
    spline_fit <- splinefun(prices, intent, method = "natural")
    interp <- spline_fit(new_prices)
    # Enforce monotonicity
    interp <- smooth_isotonic(new_prices, interp, verbose = FALSE)
    # Bound to [0, 1]
    interp <- pmax(0, pmin(1, interp))

  } else if (method == "pchip") {
    # Piecewise cubic Hermite - naturally monotone preserving
    # Implementation using linear + cubic blending
    interp <- pchip_interpolate(prices, intent, new_prices)
  }

  # Bound to valid range
  interp <- pmax(0, pmin(1, interp))

  data.frame(
    price = new_prices,
    purchase_intent = interp,
    interpolated = TRUE,
    stringsAsFactors = FALSE
  )
}


#' PCHIP Interpolation (Monotone Preserving)
#'
#' Piecewise Cubic Hermite Interpolating Polynomial.
#' Preserves monotonicity of the original data.
#'
#' @param x Known x values (must be strictly increasing)
#' @param y Known y values
#' @param xi Interpolation points
#' @return Interpolated y values at xi
#' @keywords internal
pchip_interpolate <- function(x, y, xi) {
  n <- length(x)

  if (n < 2) {
    return(rep(y[1], length(xi)))
  }

  # Calculate slopes
  h <- diff(x)
  delta <- diff(y) / h

  # Calculate derivative estimates at each point
  # Use harmonic mean to preserve monotonicity
  d <- numeric(n)

  # Interior points
  for (i in 2:(n-1)) {
    if (delta[i-1] * delta[i] > 0) {
      # Same sign - use weighted harmonic mean
      w1 <- 2 * h[i] + h[i-1]
      w2 <- h[i] + 2 * h[i-1]
      d[i] <- (w1 + w2) / (w1 / delta[i-1] + w2 / delta[i])
    } else {
      # Different signs or zero - set to zero for monotonicity
      d[i] <- 0
    }
  }

  # Endpoints
  d[1] <- pchip_endpoint_deriv(h[1], h[2], delta[1], delta[2])
  d[n] <- pchip_endpoint_deriv(h[n-1], h[n-2], delta[n-1], delta[n-2])

  # Interpolate at each xi
  yi <- numeric(length(xi))

  for (k in seq_along(xi)) {
    xk <- xi[k]

    # Handle extrapolation
    if (xk <= x[1]) {
      yi[k] <- y[1]
    } else if (xk >= x[n]) {
      yi[k] <- y[n]
    } else {
      # Find interval
      i <- findInterval(xk, x)
      i <- min(i, n - 1)

      # Hermite basis interpolation
      t <- (xk - x[i]) / h[i]
      t2 <- t * t
      t3 <- t2 * t

      h00 <- 2*t3 - 3*t2 + 1
      h10 <- t3 - 2*t2 + t
      h01 <- -2*t3 + 3*t2
      h11 <- t3 - t2

      yi[k] <- h00 * y[i] + h10 * h[i] * d[i] +
               h01 * y[i+1] + h11 * h[i] * d[i+1]
    }
  }

  return(yi)
}


#' PCHIP Endpoint Derivative
#' @keywords internal
pchip_endpoint_deriv <- function(h1, h2, del1, del2) {
  # One-sided three-point estimate
  d <- ((2 * h1 + h2) * del1 - h1 * del2) / (h1 + h2)

  # Ensure monotonicity
  if (sign(d) != sign(del1)) {
    d <- 0
  } else if ((sign(del1) != sign(del2)) && (abs(d) > abs(3 * del1))) {
    d <- 3 * del1
  }

  return(d)
}


#' Calculate Revenue Curve
#'
#' Computes expected revenue and profit indices at each price point.
#'
#' @param demand_curve Demand curve from calculate_demand_curve()
#' @param unit_cost Optional unit cost for profit calculations
#'
#' @return Data frame with price, purchase intent, revenue index, and optionally profit
#'
#' @keywords internal
calculate_revenue_curve <- function(demand_curve, unit_cost = NA) {

  revenue <- demand_curve
  revenue$revenue_index <- revenue$price * revenue$purchase_intent
  revenue$revenue_per_100 <- revenue$price * revenue$purchase_intent * 100

  # Calculate profit if unit cost is provided
  if (!is.na(unit_cost) && is.finite(unit_cost)) {
    revenue$margin <- revenue$price - unit_cost
    revenue$profit_index <- revenue$margin * revenue$purchase_intent
    revenue$profit_per_100 <- revenue$margin * revenue$purchase_intent * 100
  }

  return(revenue)
}


#' Find Optimal Price
#'
#' Identifies the price point that maximizes expected revenue or profit.
#'
#' @param revenue_curve Revenue curve from calculate_revenue_curve()
#' @param metric Either "revenue" (default) or "profit"
#'
#' @return List with optimal price, purchase intent, and metric value
#'
#' @keywords internal
find_optimal_price <- function(revenue_curve, metric = "revenue") {

  if (metric == "profit") {
    if (!"profit_index" %in% names(revenue_curve)) {
      stop("Profit index not found in revenue_curve. Specify unit_cost in config.", call. = FALSE)
    }
    optimal_idx <- which.max(revenue_curve$profit_index)
    result <- list(
      price = revenue_curve$price[optimal_idx],
      purchase_intent = revenue_curve$purchase_intent[optimal_idx],
      revenue_index = revenue_curve$revenue_index[optimal_idx],
      profit_index = revenue_curve$profit_index[optimal_idx],
      margin = revenue_curve$margin[optimal_idx],
      position = optimal_idx,
      n_price_points = nrow(revenue_curve),
      metric = "profit"
    )
  } else {
    optimal_idx <- which.max(revenue_curve$revenue_index)
    result <- list(
      price = revenue_curve$price[optimal_idx],
      purchase_intent = revenue_curve$purchase_intent[optimal_idx],
      revenue_index = revenue_curve$revenue_index[optimal_idx],
      position = optimal_idx,
      n_price_points = nrow(revenue_curve),
      metric = "revenue"
    )
    # Include profit info if available
    if ("profit_index" %in% names(revenue_curve)) {
      result$profit_index <- revenue_curve$profit_index[optimal_idx]
      result$margin <- revenue_curve$margin[optimal_idx]
    }
  }

  return(result)
}


#' Calculate Price Elasticity
#'
#' Computes price elasticity of demand (arc elasticity between price points).
#'
#' @param demand_curve Demand curve from calculate_demand_curve()
#'
#' @return Data frame with elasticity values between consecutive prices
#'
#' @keywords internal
calculate_price_elasticity <- function(demand_curve) {

  n <- nrow(demand_curve)

  if (n < 2) {
    return(NULL)
  }

  elasticity <- data.frame(
    price_from = demand_curve$price[-n],
    price_to = demand_curve$price[-1],
    demand_from = demand_curve$purchase_intent[-n],
    demand_to = demand_curve$purchase_intent[-1],
    stringsAsFactors = FALSE
  )

  # Arc elasticity formula
  # E = ((Q2-Q1)/((Q2+Q1)/2)) / ((P2-P1)/((P2+P1)/2))
  elasticity$pct_change_demand <- (elasticity$demand_to - elasticity$demand_from) /
    ((elasticity$demand_to + elasticity$demand_from) / 2)

  elasticity$pct_change_price <- (elasticity$price_to - elasticity$price_from) /
    ((elasticity$price_to + elasticity$price_from) / 2)

  elasticity$arc_elasticity <- elasticity$pct_change_demand / elasticity$pct_change_price

  # Classify elasticity
  elasticity$elasticity_type <- ifelse(
    abs(elasticity$arc_elasticity) > 1, "Elastic",
    ifelse(abs(elasticity$arc_elasticity) < 1, "Inelastic", "Unit Elastic")
  )

  return(elasticity)
}


#' Bootstrap Confidence Intervals for Gabor-Granger
#'
#' Calculates confidence intervals for demand curve using bootstrap resampling.
#'
#' @param gg_data Long format Gabor-Granger data
#' @param iterations Number of bootstrap iterations
#' @param level Confidence level
#'
#' @return Data frame with price and confidence intervals for purchase intent
#'
#' @keywords internal
bootstrap_gg_confidence <- function(gg_data, iterations = 1000, level = 0.95) {

  alpha <- 1 - level
  prices <- sort(unique(gg_data$price))
  respondents <- unique(gg_data$respondent_id)
  n_resp <- length(respondents)

  # Storage for bootstrap results
  boot_results <- matrix(NA, nrow = iterations, ncol = length(prices))

  for (i in seq_len(iterations)) {
    # Resample respondents
    boot_respondents <- sample(respondents, n_resp, replace = TRUE)

    # Get data for resampled respondents (includes weights)
    boot_data <- do.call(rbind, lapply(boot_respondents, function(r) {
      gg_data[gg_data$respondent_id == r, ]
    }))

    # Calculate weighted demand at each price
    for (j in seq_along(prices)) {
      p <- prices[j]
      subset_data <- boot_data[boot_data$price == p & !is.na(boot_data$response), ]
      if (nrow(subset_data) > 0 && "weight" %in% names(subset_data)) {
        # Weighted mean
        boot_results[i, j] <- sum(subset_data$weight * subset_data$response) / sum(subset_data$weight)
      } else {
        # Fallback to unweighted if no weights
        boot_results[i, j] <- mean(subset_data$response)
      }
    }
  }

  # Calculate confidence intervals
  ci <- data.frame(
    price = prices,
    mean = colMeans(boot_results, na.rm = TRUE),
    se = apply(boot_results, 2, sd, na.rm = TRUE),
    ci_lower = apply(boot_results, 2, quantile, probs = alpha/2, na.rm = TRUE),
    ci_upper = apply(boot_results, 2, quantile, probs = 1 - alpha/2, na.rm = TRUE),
    stringsAsFactors = FALSE
  )

  return(ci)
}
