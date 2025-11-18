# ==============================================================================
# TURAS PRICING MODULE - VAN WESTENDORP PRICE SENSITIVITY METER
# ==============================================================================
#
# Purpose: Implement Van Westendorp PSM analysis methodology
# Version: 1.0.0
# Date: 2025-11-18
#
# References:
# - Van Westendorp, P. (1976). NSS Price Sensitivity Meter (PSM) -
#   A new approach to study consumer perception of price
#
# ==============================================================================

#' Run Van Westendorp PSM Analysis
#'
#' Calculates price sensitivity metrics using the Van Westendorp methodology.
#' Finds four key price points through cumulative distribution intersections:
#' - PMC (Point of Marginal Cheapness)
#' - OPP (Optimal Price Point)
#' - IDP (Indifference Price Point)
#' - PME (Point of Marginal Expensiveness)
#'
#' @param data Data frame containing price perception responses
#' @param config Configuration list with Van Westendorp settings
#'
#' @return List containing price points, curves, confidence intervals, and diagnostics
#'
#' @keywords internal
run_van_westendorp <- function(data, config) {

  vw <- config$van_westendorp

  # Extract price columns
  too_cheap <- data[[vw$col_too_cheap]]
  cheap <- data[[vw$col_cheap]]
  expensive <- data[[vw$col_expensive]]
  too_expensive <- data[[vw$col_too_expensive]]

  # Remove cases with any missing values
  complete_cases <- !is.na(too_cheap) & !is.na(cheap) &
    !is.na(expensive) & !is.na(too_expensive)

  too_cheap <- too_cheap[complete_cases]
  cheap <- cheap[complete_cases]
  expensive <- expensive[complete_cases]
  too_expensive <- too_expensive[complete_cases]

  n_valid <- length(too_cheap)

  if (n_valid < 30) {
    warning(sprintf("Low sample size for Van Westendorp analysis: n=%d (recommended minimum: 30)",
                    n_valid), call. = FALSE)
  }

  # Calculate cumulative distribution curves
  curves <- calculate_vw_curves(too_cheap, cheap, expensive, too_expensive,
                                interpolation = vw$interpolation_method %||% "linear")

  # Find intersection points
  price_points <- find_vw_intersections(curves)

  # Calculate acceptable and optimal ranges
  acceptable_range <- list(
    lower = price_points$PMC,
    upper = price_points$PME
  )

  optimal_range <- list(
    lower = price_points$OPP,
    upper = price_points$IDP
  )

  # Calculate confidence intervals if requested
  confidence_intervals <- NULL
  if (isTRUE(vw$calculate_confidence)) {
    confidence_intervals <- bootstrap_vw_confidence(
      too_cheap, cheap, expensive, too_expensive,
      iterations = vw$bootstrap_iterations %||% 1000,
      level = vw$confidence_level %||% 0.95
    )
  }

  # Calculate descriptive statistics
  descriptives <- calculate_vw_descriptives(too_cheap, cheap, expensive, too_expensive)

  # Return results
  list(
    price_points = price_points,
    acceptable_range = acceptable_range,
    optimal_range = optimal_range,
    curves = curves,
    confidence_intervals = confidence_intervals,
    descriptives = descriptives,
    diagnostics = list(
      n_total = sum(complete_cases) + sum(!complete_cases),
      n_valid = n_valid,
      price_range = range(c(too_cheap, cheap, expensive, too_expensive)),
      method = "van_westendorp"
    )
  )
}


#' Calculate Van Westendorp Cumulative Curves
#'
#' Computes cumulative distribution functions for each price perception question.
#'
#' @param too_cheap Vector of "too cheap" prices
#' @param cheap Vector of "bargain" prices
#' @param expensive Vector of "expensive" prices
#' @param too_expensive Vector of "too expensive" prices
#' @param interpolation Interpolation method ("linear" or "spline")
#'
#' @return Data frame with price points and cumulative percentages
#'
#' @keywords internal
calculate_vw_curves <- function(too_cheap, cheap, expensive, too_expensive,
                                interpolation = "linear") {

  # Get all unique price points
  all_prices <- sort(unique(c(too_cheap, cheap, expensive, too_expensive)))

  # Create finer price grid for smoother curves
  price_range <- range(all_prices)
  price_grid <- seq(price_range[1], price_range[2], length.out = 200)

  # Calculate cumulative percentages at each price point
  # Using ECDF (empirical cumulative distribution function)

  # "Too Cheap" curve: % who say price is too cheap (cumulative from high to low)
  # At price P: % of respondents whose "too cheap" price >= P
  curve_too_cheap <- sapply(price_grid, function(p) mean(too_cheap >= p))

  # "Not Cheap" curve (inverse of cheap): % who say price is NOT cheap
  # At price P: % of respondents whose "cheap" price <= P
  curve_not_cheap <- sapply(price_grid, function(p) mean(cheap <= p))

  # "Not Expensive" curve (inverse of expensive): % who say price is NOT expensive
  # At price P: % of respondents whose "expensive" price >= P
  curve_not_expensive <- sapply(price_grid, function(p) mean(expensive >= p))

  # "Too Expensive" curve: % who say price is too expensive
  # At price P: % of respondents whose "too expensive" price <= P
  curve_too_expensive <- sapply(price_grid, function(p) mean(too_expensive <= p))

  # Also calculate the "Cheap" and "Expensive" curves for IDP
  curve_cheap <- 1 - curve_not_cheap
  curve_expensive <- 1 - curve_not_expensive

  # Return curves data frame
  data.frame(
    price = price_grid,
    too_cheap = curve_too_cheap,
    not_cheap = curve_not_cheap,
    cheap = curve_cheap,
    not_expensive = curve_not_expensive,
    expensive = curve_expensive,
    too_expensive = curve_too_expensive,
    stringsAsFactors = FALSE
  )
}


#' Find Van Westendorp Intersection Points
#'
#' Calculates the four key price points from curve intersections.
#'
#' @param curves Data frame of cumulative curves from calculate_vw_curves()
#'
#' @return Named list with PMC, OPP, IDP, and PME price points
#'
#' @keywords internal
find_vw_intersections <- function(curves) {

  price <- curves$price

  # PMC (Point of Marginal Cheapness): Too Cheap x Not Cheap
  # Where "too cheap" percentage equals "not cheap" percentage
  pmc <- find_curve_intersection(price, curves$too_cheap, curves$not_cheap)

  # OPP (Optimal Price Point): Too Cheap x Too Expensive
  # Where "too cheap" percentage equals "too expensive" percentage
  opp <- find_curve_intersection(price, curves$too_cheap, curves$too_expensive)

  # IDP (Indifference Price Point): Cheap x Expensive
  # Where "cheap" percentage equals "expensive" percentage
  idp <- find_curve_intersection(price, curves$cheap, curves$expensive)

  # PME (Point of Marginal Expensiveness): Not Expensive x Too Expensive
  # Where "not expensive" percentage equals "too expensive" percentage
  pme <- find_curve_intersection(price, curves$not_expensive, curves$too_expensive)

  list(
    PMC = pmc,
    OPP = opp,
    IDP = idp,
    PME = pme
  )
}


#' Find Intersection of Two Curves
#'
#' Uses linear interpolation to find where two curves intersect.
#'
#' @param x X-axis values (prices)
#' @param y1 First curve y-values
#' @param y2 Second curve y-values
#'
#' @return X-value at intersection point
#'
#' @keywords internal
find_curve_intersection <- function(x, y1, y2) {

  # Calculate difference
  diff <- y1 - y2

  # Find where sign changes (crossing point)
  sign_changes <- which(diff[-1] * diff[-length(diff)] < 0)

  if (length(sign_changes) == 0) {
    # No intersection found
    # Return the point where curves are closest
    min_diff_idx <- which.min(abs(diff))
    return(x[min_diff_idx])
  }

  # Use first intersection
  idx <- sign_changes[1]

  # Linear interpolation to find exact crossing point
  x1 <- x[idx]
  x2 <- x[idx + 1]
  y1_1 <- y1[idx]
  y1_2 <- y1[idx + 1]
  y2_1 <- y2[idx]
  y2_2 <- y2[idx + 1]

  # Solve for intersection
  # y1 = y1_1 + (y1_2 - y1_1) * t
  # y2 = y2_1 + (y2_2 - y2_1) * t
  # Set equal and solve for t
  denom <- (y1_2 - y1_1) - (y2_2 - y2_1)

  if (abs(denom) < 1e-10) {
    # Parallel lines - return midpoint
    return((x1 + x2) / 2)
  }

  t <- (y2_1 - y1_1) / denom
  intersection_x <- x1 + (x2 - x1) * t

  return(intersection_x)
}


#' Bootstrap Confidence Intervals for Van Westendorp
#'
#' Calculates confidence intervals for price points using bootstrap resampling.
#'
#' @param too_cheap Vector of "too cheap" prices
#' @param cheap Vector of "bargain" prices
#' @param expensive Vector of "expensive" prices
#' @param too_expensive Vector of "too expensive" prices
#' @param iterations Number of bootstrap iterations
#' @param level Confidence level (e.g., 0.95 for 95% CI)
#'
#' @return Data frame with price point estimates and confidence intervals
#'
#' @keywords internal
bootstrap_vw_confidence <- function(too_cheap, cheap, expensive, too_expensive,
                                    iterations = 1000, level = 0.95) {

  n <- length(too_cheap)
  alpha <- 1 - level

  # Storage for bootstrap results
  boot_results <- matrix(NA, nrow = iterations, ncol = 4)
  colnames(boot_results) <- c("PMC", "OPP", "IDP", "PME")

  # Run bootstrap
  for (i in seq_len(iterations)) {
    # Resample with replacement
    idx <- sample(n, n, replace = TRUE)

    boot_too_cheap <- too_cheap[idx]
    boot_cheap <- cheap[idx]
    boot_expensive <- expensive[idx]
    boot_too_expensive <- too_expensive[idx]

    # Calculate curves and intersections
    curves <- calculate_vw_curves(boot_too_cheap, boot_cheap,
                                  boot_expensive, boot_too_expensive)
    points <- find_vw_intersections(curves)

    boot_results[i, ] <- c(points$PMC, points$OPP, points$IDP, points$PME)
  }

  # Calculate percentile confidence intervals
  ci_lower <- apply(boot_results, 2, quantile, probs = alpha/2, na.rm = TRUE)
  ci_upper <- apply(boot_results, 2, quantile, probs = 1 - alpha/2, na.rm = TRUE)
  ci_mean <- colMeans(boot_results, na.rm = TRUE)
  ci_se <- apply(boot_results, 2, sd, na.rm = TRUE)

  data.frame(
    metric = c("PMC", "OPP", "IDP", "PME"),
    estimate = ci_mean,
    se = ci_se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    stringsAsFactors = FALSE
  )
}


#' Calculate Descriptive Statistics for Van Westendorp
#'
#' @param too_cheap Vector of "too cheap" prices
#' @param cheap Vector of "bargain" prices
#' @param expensive Vector of "expensive" prices
#' @param too_expensive Vector of "too expensive" prices
#'
#' @return Data frame with descriptive statistics
#'
#' @keywords internal
calculate_vw_descriptives <- function(too_cheap, cheap, expensive, too_expensive) {

  calc_stats <- function(x, name) {
    data.frame(
      variable = name,
      n = sum(!is.na(x)),
      mean = mean(x, na.rm = TRUE),
      median = median(x, na.rm = TRUE),
      sd = sd(x, na.rm = TRUE),
      min = min(x, na.rm = TRUE),
      max = max(x, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }

  rbind(
    calc_stats(too_cheap, "Too Cheap"),
    calc_stats(cheap, "Cheap/Bargain"),
    calc_stats(expensive, "Expensive"),
    calc_stats(too_expensive, "Too Expensive")
  )
}
