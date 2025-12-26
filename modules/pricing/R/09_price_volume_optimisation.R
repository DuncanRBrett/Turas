# ==============================================================================
# TURAS PRICING MODULE - CONSTRAINED PRICE-VOLUME OPTIMISATION
# ==============================================================================
#
# Purpose: Find optimal prices subject to business constraints
# Version: 1.0.0
# Date: 2025-12-01
#
# ==============================================================================

#' Find Constrained Optimal Price
#'
#' Identifies the best price subject to business constraints (min volume, min profit, etc.)
#'
#' @param demand_curve Demand curve from Gabor-Granger (with revenue_index and optionally profit_index)
#' @param objective Either "revenue" or "profit" to maximize
#' @param constraints Named list of constraints, e.g.:
#'   list(min_volume = 400000, min_profit = 10000000, min_margin_pct = 25)
#' @param market_size Total market size (required if using volume constraints)
#'
#' @return Single-row data frame with optimal price and metrics, or NA if no feasible solution
#'
#' @export
find_constrained_optimal <- function(demand_curve, objective = c("revenue", "profit"),
                                    constraints = list(), market_size = NULL) {

  objective <- match.arg(objective)

  # Add volume column if market_size provided
  if (!is.null(market_size) && is.finite(market_size)) {
    demand_curve$volume <- demand_curve$purchase_intent * market_size
  }

  # Initialize feasibility mask
  feasible <- rep(TRUE, nrow(demand_curve))

  # Apply constraints
  if (!is.null(constraints$min_volume)) {
    if (!"volume" %in% names(demand_curve)) {
      stop("min_volume constraint requires market_size parameter", call. = FALSE)
    }
    feasible <- feasible & (demand_curve$volume >= constraints$min_volume)
  }

  if (!is.null(constraints$min_revenue)) {
    if (!"revenue_index" %in% names(demand_curve)) {
      stop("revenue_index not found in demand_curve", call. = FALSE)
    }
    # Scale to total market if market_size provided
    rev_total <- if (!is.null(market_size)) {
      demand_curve$revenue_index * market_size
    } else {
      demand_curve$revenue_index
    }
    feasible <- feasible & (rev_total >= constraints$min_revenue)
  }

  if (!is.null(constraints$min_profit)) {
    if (!"profit_index" %in% names(demand_curve)) {
      stop("profit_index not found in demand_curve. Specify unit_cost in config.", call. = FALSE)
    }
    # Scale to total market
    prof_total <- if (!is.null(market_size)) {
      demand_curve$profit_index * market_size
    } else {
      demand_curve$profit_index
    }
    feasible <- feasible & (prof_total >= constraints$min_profit)
  }

  if (!is.null(constraints$min_margin_pct)) {
    if (!"margin" %in% names(demand_curve)) {
      stop("margin not found in demand_curve. Specify unit_cost in config.", call. = FALSE)
    }
    margin_pct <- (demand_curve$margin / demand_curve$price) * 100
    feasible <- feasible & (margin_pct >= constraints$min_margin_pct)
  }

  if (!is.null(constraints$max_price)) {
    feasible <- feasible & (demand_curve$price <= constraints$max_price)
  }

  if (!is.null(constraints$min_price)) {
    feasible <- feasible & (demand_curve$price >= constraints$min_price)
  }

  # Filter to feasible prices
  feasible_prices <- demand_curve[feasible, ]

  if (nrow(feasible_prices) == 0) {
    warning("No price satisfies all constraints. Returning NA.", call. = FALSE)
    return(data.frame(
      price = NA_real_,
      purchase_intent = NA_real_,
      revenue_index = NA_real_,
      profit_index = NA_real_,
      volume = NA_real_,
      feasible = FALSE,
      stringsAsFactors = FALSE
    ))
  }

  # Find optimal within feasible set
  if (objective == "revenue") {
    idx <- which.max(feasible_prices$revenue_index)
  } else {
    if (!"profit_index" %in% names(feasible_prices)) {
      stop("profit_index required for profit objective. Specify unit_cost.", call. = FALSE)
    }
    idx <- which.max(feasible_prices$profit_index)
  }

  result <- feasible_prices[idx, , drop = FALSE]
  result$feasible <- TRUE
  result$objective <- objective

  return(result)
}


#' Find Price to Achieve Target Volume
#'
#' Identifies the lowest price that achieves a target sales volume.
#'
#' @param demand_curve Demand curve from Gabor-Granger
#' @param target_volume Target volume to achieve
#' @param market_size Total market size
#'
#' @return Single-row data frame with price and metrics
#'
#' @export
find_price_for_volume <- function(demand_curve, target_volume, market_size) {

  demand_curve$volume <- demand_curve$purchase_intent * market_size

  # Find prices that meet or exceed target
  achieves_target <- demand_curve$volume >= target_volume

  if (!any(achieves_target)) {
    warning(sprintf("Target volume %.0f not achievable. Max volume: %.0f at price %.2f",
                    target_volume, max(demand_curve$volume), demand_curve$price[which.max(demand_curve$volume)]),
            call. = FALSE)
    # Return closest
    idx <- which.min(abs(demand_curve$volume - target_volume))
    result <- demand_curve[idx, , drop = FALSE]
    result$target_met <- FALSE
    return(result)
  }

  # Among feasible, choose lowest price (usually highest share)
  feasible <- demand_curve[achieves_target, ]
  idx <- which.min(feasible$price)
  result <- feasible[idx, , drop = FALSE]
  result$target_met <- TRUE

  return(result)
}


#' Find Price to Achieve Target Revenue
#'
#' Identifies price that achieves target revenue.
#'
#' @param demand_curve Demand curve with revenue_index
#' @param target_revenue Target revenue
#' @param market_size Optional market size for scaling
#'
#' @return Single-row data frame
#'
#' @export
find_price_for_revenue <- function(demand_curve, target_revenue, market_size = NULL) {

  revenue <- if (!is.null(market_size)) {
    demand_curve$revenue_index * market_size
  } else {
    demand_curve$revenue_index
  }

  # Find closest
  idx <- which.min(abs(revenue - target_revenue))
  result <- demand_curve[idx, , drop = FALSE]
  result$target_revenue <- target_revenue
  result$actual_revenue <- revenue[idx]
  result$revenue_gap <- revenue[idx] - target_revenue

  return(result)
}


#' Find Price to Achieve Target Profit
#'
#' Identifies price that achieves target profit.
#'
#' @param demand_curve Demand curve with profit_index
#' @param target_profit Target profit
#' @param market_size Optional market size
#'
#' @return Single-row data frame
#'
#' @export
find_price_for_profit <- function(demand_curve, target_profit, market_size = NULL) {

  if (!"profit_index" %in% names(demand_curve)) {
    stop("profit_index not found. Specify unit_cost in config.", call. = FALSE)
  }

  profit <- if (!is.null(market_size)) {
    demand_curve$profit_index * market_size
  } else {
    demand_curve$profit_index
  }

  # Find closest
  idx <- which.min(abs(profit - target_profit))
  result <- demand_curve[idx, , drop = FALSE]
  result$target_profit <- target_profit
  result$actual_profit <- profit[idx]
  result$profit_gap <- profit[idx] - target_profit

  return(result)
}


#' Explore Price-Volume Tradeoff
#'
#' Creates a grid showing tradeoffs between price, volume, revenue, and profit.
#'
#' @param demand_curve Demand curve
#' @param market_size Market size
#' @param price_range Optional c(min, max) to subset price range
#'
#' @return Data frame with price, volume, revenue, profit, margin% for all prices
#'
#' @export
explore_price_tradeoffs <- function(demand_curve, market_size = NULL, price_range = NULL) {

  # Subset to price range if specified
  if (!is.null(price_range)) {
    demand_curve <- demand_curve[demand_curve$price >= price_range[1] &
                                  demand_curve$price <= price_range[2], ]
  }

  # Add volume
  if (!is.null(market_size)) {
    demand_curve$volume <- demand_curve$purchase_intent * market_size
    demand_curve$revenue_total <- demand_curve$revenue_index * market_size
    if ("profit_index" %in% names(demand_curve)) {
      demand_curve$profit_total <- demand_curve$profit_index * market_size
    }
  }

  # Add margin %
  if ("margin" %in% names(demand_curve)) {
    demand_curve$margin_pct <- (demand_curve$margin / demand_curve$price) * 100
  }

  # Select key columns
  key_cols <- c("price", "purchase_intent")
  if ("volume" %in% names(demand_curve)) key_cols <- c(key_cols, "volume")
  if ("revenue_index" %in% names(demand_curve)) key_cols <- c(key_cols, "revenue_index")
  if ("revenue_total" %in% names(demand_curve)) key_cols <- c(key_cols, "revenue_total")
  if ("profit_index" %in% names(demand_curve)) key_cols <- c(key_cols, "profit_index")
  if ("profit_total" %in% names(demand_curve)) key_cols <- c(key_cols, "profit_total")
  if ("margin_pct" %in% names(demand_curve)) key_cols <- c(key_cols, "margin_pct")

  result <- demand_curve[, key_cols, drop = FALSE]

  return(result)
}


#' Plot Constrained Optimization
#'
#' Visualizes feasible region and optimal point.
#'
#' @param demand_curve Demand curve
#' @param constraints List of constraints
#' @param optimal_result Result from find_constrained_optimal()
#' @param market_size Market size (if applicable)
#'
#' @return ggplot object
#'
#' @export
plot_constrained_optimization <- function(demand_curve, constraints, optimal_result, market_size = NULL) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    message("ggplot2 required")
    return(invisible(NULL))
  }

  # Add volume if needed
  if (!is.null(market_size)) {
    demand_curve$volume <- demand_curve$purchase_intent * market_size
  }

  # Create feasibility indicator
  feasible <- rep(TRUE, nrow(demand_curve))
  if (!is.null(constraints$min_volume) && "volume" %in% names(demand_curve)) {
    feasible <- feasible & (demand_curve$volume >= constraints$min_volume)
  }
  demand_curve$feasible <- feasible

  # Plot price vs volume, colored by feasibility
  p <- ggplot2::ggplot(demand_curve, ggplot2::aes(x = price, y = volume, color = feasible)) +
    ggplot2::geom_line(size = 1.2) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_color_manual(values = c("TRUE" = "steelblue", "FALSE" = "gray70"),
                                labels = c("Infeasible", "Feasible")) +
    ggplot2::labs(
      title = "Price-Volume Tradeoff with Constraints",
      x = "Price",
      y = "Volume",
      color = "Region"
    ) +
    ggplot2::theme_minimal()

  # Mark optimal point
  if (!is.na(optimal_result$price)) {
    p <- p +
      ggplot2::geom_point(data = optimal_result, ggplot2::aes(x = price, y = volume),
                          color = "darkred", size = 4, shape = 18) +
      ggplot2::annotate("text", x = optimal_result$price, y = optimal_result$volume,
                        label = sprintf("Optimal: $%.2f", optimal_result$price),
                        hjust = -0.2, color = "darkred", size = 4)
  }

  # Add constraint lines
  if (!is.null(constraints$min_volume)) {
    p <- p + ggplot2::geom_hline(yintercept = constraints$min_volume,
                                  linetype = "dashed", color = "red", alpha = 0.6)
  }

  return(p)
}


# ==============================================================================
# ADVANCED OPTIMIZATION ALGORITHMS
# ==============================================================================

#' Find Continuous Optimal Price
#'
#' Uses interpolation and optimization to find the optimal price
#' at any point on the demand curve, not just tested price points.
#'
#' @param demand_curve Demand curve from Gabor-Granger
#' @param objective Either "revenue" or "profit"
#' @param unit_cost Unit cost (required for profit objective)
#' @param market_size Market size for scaling (optional)
#' @param price_bounds Optional c(min, max) bounds for search
#' @param tolerance Optimization tolerance (default 0.01)
#'
#' @return List with optimal price, objective value, and confidence interval
#'
#' @details
#' Uses golden section search combined with monotone spline interpolation
#' to find the optimal price without being restricted to tested price points.
#' This is particularly useful when:
#' - Price points tested were coarse-grained
#' - You want to find precise optimal pricing
#' - You need to optimize within a specific price range
#'
#' @export
find_continuous_optimal <- function(demand_curve,
                                     objective = c("revenue", "profit"),
                                     unit_cost = NULL,
                                     market_size = NULL,
                                     price_bounds = NULL,
                                     tolerance = 0.01) {

  objective <- match.arg(objective)

  prices <- demand_curve$price
  intent <- demand_curve$purchase_intent

  # Remove NA values
  valid <- !is.na(intent)
  prices <- prices[valid]
  intent <- intent[valid]

  if (length(prices) < 3) {
    warning("Insufficient data points for continuous optimization", call. = FALSE)
    return(NULL)
  }

  # Set price bounds
  if (is.null(price_bounds)) {
    price_bounds <- range(prices)
  }

  # Create interpolation function (monotone spline)
  intent_func <- create_demand_interpolator(prices, intent)

  # Define objective function
  if (objective == "revenue") {
    obj_func <- function(p) {
      d <- intent_func(p)
      -p * d  # Negative because we minimize
    }
  } else {
    if (is.null(unit_cost)) {
      stop("unit_cost required for profit optimization", call. = FALSE)
    }
    obj_func <- function(p) {
      d <- intent_func(p)
      -(p - unit_cost) * d  # Negative profit
    }
  }

  # Golden section search
  result <- golden_section_search(
    f = obj_func,
    a = price_bounds[1],
    b = price_bounds[2],
    tol = tolerance
  )

  optimal_price <- result$x
  optimal_intent <- intent_func(optimal_price)

  # Calculate objective values
  if (objective == "revenue") {
    objective_value <- optimal_price * optimal_intent
    profit_value <- if (!is.null(unit_cost)) (optimal_price - unit_cost) * optimal_intent else NA
  } else {
    objective_value <- (optimal_price - unit_cost) * optimal_intent
    profit_value <- objective_value
  }

  # Scale if market size provided
  if (!is.null(market_size)) {
    objective_value_scaled <- objective_value * market_size
    volume <- optimal_intent * market_size
  } else {
    objective_value_scaled <- NA
    volume <- NA
  }

  list(
    price = optimal_price,
    purchase_intent = optimal_intent,
    objective = objective,
    objective_value = objective_value,
    objective_value_scaled = objective_value_scaled,
    volume = volume,
    profit_index = profit_value,
    iterations = result$iterations,
    method = "golden_section_continuous"
  )
}


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


#' Golden Section Search
#'
#' Finds minimum of unimodal function using golden section method.
#'
#' @param f Function to minimize
#' @param a Lower bound
#' @param b Upper bound
#' @param tol Tolerance for convergence
#' @param max_iter Maximum iterations
#' @return List with x (optimal point), fx (function value), iterations
#' @keywords internal
golden_section_search <- function(f, a, b, tol = 0.01, max_iter = 100) {
  phi <- (1 + sqrt(5)) / 2  # Golden ratio
  resphi <- 2 - phi

  x1 <- a + resphi * (b - a)
  x2 <- b - resphi * (b - a)
  f1 <- f(x1)
  f2 <- f(x2)

  iter <- 0

  while ((b - a) > tol && iter < max_iter) {
    iter <- iter + 1

    if (f1 < f2) {
      b <- x2
      x2 <- x1
      f2 <- f1
      x1 <- a + resphi * (b - a)
      f1 <- f(x1)
    } else {
      a <- x1
      x1 <- x2
      f1 <- f2
      x2 <- b - resphi * (b - a)
      f2 <- f(x2)
    }
  }

  x_opt <- (a + b) / 2

  list(
    x = x_opt,
    fx = f(x_opt),
    iterations = iter
  )
}


#' Price Sensitivity Analysis
#'
#' Analyzes how revenue/profit changes as price deviates from optimal.
#'
#' @param demand_curve Demand curve from Gabor-Granger
#' @param optimal_price Optimal price from find_constrained_optimal() or similar
#' @param unit_cost Unit cost (optional, for profit analysis)
#' @param market_size Market size (optional)
#' @param deviation_pct Vector of percentage deviations to test (default: -20 to +20)
#'
#' @return Data frame with sensitivity analysis results
#'
#' @details
#' Shows how much revenue/profit is lost at prices above or below optimal.
#' Useful for:
#' - Understanding pricing flexibility
#' - Comparing revenue vs profit tradeoffs
#' - Setting price bands for negotiation
#'
#' @export
analyze_price_sensitivity <- function(demand_curve,
                                       optimal_price,
                                       unit_cost = NULL,
                                       market_size = NULL,
                                       deviation_pct = seq(-20, 20, by = 5)) {

  prices <- demand_curve$price
  intent <- demand_curve$purchase_intent

  # Remove NA
  valid <- !is.na(intent)
  prices <- prices[valid]
  intent <- intent[valid]

  # Create interpolator
  intent_func <- create_demand_interpolator(prices, intent)

  # Calculate optimal values
  opt_intent <- intent_func(optimal_price)
  opt_revenue <- optimal_price * opt_intent
  opt_profit <- if (!is.null(unit_cost)) (optimal_price - unit_cost) * opt_intent else NA

  # Test deviations
  test_prices <- optimal_price * (1 + deviation_pct / 100)
  # Bound to data range
  test_prices <- pmax(min(prices), pmin(max(prices), test_prices))

  results <- data.frame(
    deviation_pct = deviation_pct,
    price = test_prices,
    purchase_intent = numeric(length(test_prices)),
    revenue_index = numeric(length(test_prices)),
    revenue_pct_of_optimal = numeric(length(test_prices)),
    stringsAsFactors = FALSE
  )

  for (i in seq_along(test_prices)) {
    p <- test_prices[i]
    d <- intent_func(p)
    rev <- p * d

    results$purchase_intent[i] <- d
    results$revenue_index[i] <- rev
    results$revenue_pct_of_optimal[i] <- (rev / opt_revenue) * 100
  }

  # Add profit columns if unit_cost provided
  if (!is.null(unit_cost)) {
    results$profit_index <- (results$price - unit_cost) * results$purchase_intent
    results$profit_pct_of_optimal <- (results$profit_index / opt_profit) * 100
  }

  # Add volume if market size provided
  if (!is.null(market_size)) {
    results$volume <- results$purchase_intent * market_size
    results$revenue_total <- results$revenue_index * market_size
    if (!is.null(unit_cost)) {
      results$profit_total <- results$profit_index * market_size
    }
  }

  # Add metadata
  attr(results, "optimal_price") <- optimal_price
  attr(results, "optimal_revenue") <- opt_revenue
  attr(results, "optimal_profit") <- opt_profit

  return(results)
}


#' Pareto Frontier for Multi-Objective Optimization
#'
#' Finds non-dominated solutions when optimizing multiple objectives
#' (e.g., revenue vs volume, or profit vs market share).
#'
#' @param demand_curve Demand curve from Gabor-Granger
#' @param objectives Named list of objectives to maximize:
#'   list(revenue = TRUE, volume = TRUE, profit = TRUE)
#' @param unit_cost Unit cost (required if profit objective)
#' @param market_size Market size (required if volume objective)
#' @param n_points Number of points to evaluate on Pareto frontier
#'
#' @return Data frame with Pareto-optimal solutions
#'
#' @details
#' Multi-objective optimization finds the set of prices where no other price
#' can improve one objective without worsening another. This is useful when:
#' - Balancing short-term revenue vs long-term market share
#' - Considering both revenue and profit maximization
#' - Exploring strategic pricing tradeoffs
#'
#' @export
find_pareto_frontier <- function(demand_curve,
                                  objectives = list(revenue = TRUE, volume = TRUE),
                                  unit_cost = NULL,
                                  market_size = NULL,
                                  n_points = 100) {

  prices <- demand_curve$price
  intent <- demand_curve$purchase_intent

  valid <- !is.na(intent)
  prices <- prices[valid]
  intent <- intent[valid]

  # Create fine grid of prices
  price_grid <- seq(min(prices), max(prices), length.out = n_points)
  intent_func <- create_demand_interpolator(prices, intent)

  # Calculate objectives at each price
  results <- data.frame(price = price_grid)
  results$purchase_intent <- sapply(price_grid, intent_func)

  if (isTRUE(objectives$revenue)) {
    results$revenue <- results$price * results$purchase_intent
  }

  if (isTRUE(objectives$volume) && !is.null(market_size)) {
    results$volume <- results$purchase_intent * market_size
  }

  if (isTRUE(objectives$profit)) {
    if (is.null(unit_cost)) {
      stop("unit_cost required for profit objective", call. = FALSE)
    }
    results$profit <- (results$price - unit_cost) * results$purchase_intent
  }

  # Find Pareto-optimal points
  # A point is Pareto-optimal if no other point dominates it
  obj_cols <- names(objectives)[unlist(objectives)]
  obj_cols <- obj_cols[obj_cols %in% names(results)]

  if (length(obj_cols) < 2) {
    warning("Need at least 2 objectives for Pareto analysis", call. = FALSE)
    return(results)
  }

  is_pareto <- rep(TRUE, nrow(results))

  for (i in 1:nrow(results)) {
    for (j in 1:nrow(results)) {
      if (i != j && is_pareto[i]) {
        # Check if j dominates i (j is better in all objectives)
        j_better_all <- all(results[j, obj_cols] >= results[i, obj_cols])
        j_strictly_better_some <- any(results[j, obj_cols] > results[i, obj_cols])

        if (j_better_all && j_strictly_better_some) {
          is_pareto[i] <- FALSE
        }
      }
    }
  }

  results$pareto_optimal <- is_pareto

  # Return full grid with Pareto flag, sorted by first objective
  results <- results[order(-results[[obj_cols[1]]]), ]

  attr(results, "objectives") <- obj_cols
  attr(results, "n_pareto_points") <- sum(is_pareto)

  return(results)
}


#' Price Optimization with Scenario Analysis
#'
#' Runs optimization under multiple scenarios (e.g., different cost assumptions,
#' market sizes, or demand elasticity scenarios).
#'
#' @param demand_curve Demand curve from Gabor-Granger
#' @param scenarios Named list of scenarios, each with unit_cost and/or market_size
#' @param objective Either "revenue" or "profit"
#' @param constraints Optional constraints (applied to all scenarios)
#'
#' @return Data frame with optimal price for each scenario
#'
#' @export
optimize_with_scenarios <- function(demand_curve,
                                     scenarios,
                                     objective = c("revenue", "profit"),
                                     constraints = list()) {

  objective <- match.arg(objective)

  results <- data.frame(
    scenario = character(0),
    optimal_price = numeric(0),
    purchase_intent = numeric(0),
    revenue_index = numeric(0),
    profit_index = numeric(0),
    volume = numeric(0),
    stringsAsFactors = FALSE
  )

  for (scenario_name in names(scenarios)) {
    scenario <- scenarios[[scenario_name]]

    # Add cost/market info to demand curve for this scenario
    dc <- demand_curve

    if (!is.null(scenario$unit_cost) && "price" %in% names(dc)) {
      dc$margin <- dc$price - scenario$unit_cost
      dc$profit_index <- dc$margin * dc$purchase_intent
    }

    # Find optimal
    if (length(constraints) > 0) {
      optimal <- find_constrained_optimal(
        dc,
        objective = objective,
        constraints = constraints,
        market_size = scenario$market_size
      )
    } else {
      # Simple optimization
      if (objective == "profit" && "profit_index" %in% names(dc)) {
        idx <- which.max(dc$profit_index)
      } else {
        dc$revenue_index <- dc$price * dc$purchase_intent
        idx <- which.max(dc$revenue_index)
      }
      optimal <- dc[idx, , drop = FALSE]
    }

    # Store result
    row <- data.frame(
      scenario = scenario_name,
      optimal_price = optimal$price,
      purchase_intent = optimal$purchase_intent,
      revenue_index = if ("revenue_index" %in% names(optimal)) optimal$revenue_index else optimal$price * optimal$purchase_intent,
      profit_index = if ("profit_index" %in% names(optimal)) optimal$profit_index else NA,
      volume = if (!is.null(scenario$market_size)) optimal$purchase_intent * scenario$market_size else NA,
      unit_cost = scenario$unit_cost %||% NA,
      market_size = scenario$market_size %||% NA,
      stringsAsFactors = FALSE
    )

    results <- rbind(results, row)
  }

  return(results)
}
