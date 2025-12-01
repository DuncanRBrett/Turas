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
