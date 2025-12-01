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
