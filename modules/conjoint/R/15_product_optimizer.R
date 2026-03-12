# ==============================================================================
# PRODUCT OPTIMIZER - CONJOINT
# ==============================================================================
#
# Module: Conjoint Analysis - Product Optimization
# Purpose: Find optimal product configurations to maximize share or profit
# Version: 3.0.0
# Date: 2026-03-10
#
# WHAT THIS PROVIDES:
#   - Exhaustive search for small design spaces (<10K combos)
#   - Greedy hill-climbing for large spaces
#   - Revenue/profit optimization with cost data
#   - Multi-product portfolio optimization
#   - Top-N product ranking
#
# ==============================================================================

CONJOINT_OPTIMIZER_VERSION <- "3.0.0"

# Null coalesce
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}


# ==============================================================================
# EXHAUSTIVE SEARCH
# ==============================================================================

#' Optimize Product via Exhaustive Enumeration
#'
#' Tests all possible product configurations to find the one that maximizes
#' market share (or another objective). Only feasible for small design spaces.
#'
#' @param utilities Utilities data frame (Attribute, Level, Utility)
#' @param config Configuration with attribute definitions
#' @param other_products List of competing products (optional)
#' @param objective "share" (default), "utility", or "revenue"
#' @param price_attribute Name of price attribute (for revenue optimization)
#' @param cost_data Optional named list of costs per attribute level
#' @param model_result Optional HB/LC model for individual-level simulation
#' @param method Simulation method ("logit", "first_choice", "rfc")
#' @param top_n Number of top products to return (default: 10)
#' @param verbose Logical
#' @return List with top_products, best_product, n_combinations_tested
#' @export
optimize_product_exhaustive <- function(utilities,
                                         config,
                                         other_products = list(),
                                         objective = "share",
                                         price_attribute = NULL,
                                         cost_data = NULL,
                                         model_result = NULL,
                                         method = "logit",
                                         top_n = 10,
                                         verbose = TRUE) {

  attr_names <- config$attributes$AttributeName

  # Build level lists per attribute
  level_lists <- lapply(attr_names, function(attr) {
    get_attribute_levels(config, attr)
  })
  names(level_lists) <- attr_names

  # Calculate total combinations
  n_combos <- prod(sapply(level_lists, length))

  if (n_combos > 100000) {
    conjoint_refuse(
      code = "OPT_TOO_MANY_COMBINATIONS",
      title = "Design Space Too Large for Exhaustive Search",
      problem = sprintf("Exhaustive search requires %s combinations (max: 100,000).", format(n_combos, big.mark = ",")),
      why_it_matters = "Exhaustive enumeration becomes impractically slow with large design spaces.",
      how_to_fix = c(
        "Use optimizer_method = 'greedy' for large design spaces",
        "Reduce the number of attributes or levels"
      )
    )
  }

  log_verbose(sprintf("  → Exhaustive search: %s combinations", format(n_combos, big.mark = ",")), verbose)

  # Generate all combinations
  grid <- expand.grid(level_lists, stringsAsFactors = FALSE)

  # Evaluate each combination
  scores <- numeric(nrow(grid))

  for (i in seq_len(nrow(grid))) {
    product <- as.list(grid[i, ])
    names(product) <- attr_names

    score <- evaluate_product(
      product, utilities, other_products, objective,
      price_attribute, cost_data, model_result, config, method
    )
    scores[i] <- score

    if (verbose && i %% 1000 == 0) {
      log_verbose(sprintf("  → Evaluated %d / %d", i, nrow(grid)), verbose)
    }
  }

  # Rank and return top N
  top_idx <- order(scores, decreasing = TRUE)[1:min(top_n, length(scores))]

  top_products <- lapply(top_idx, function(idx) {
    product <- as.list(grid[idx, ])
    names(product) <- attr_names
    list(
      configuration = product,
      score = scores[idx],
      rank = which(top_idx == idx)
    )
  })

  best <- top_products[[1]]

  log_verbose(sprintf("  ✓ Best product: %s (score: %.2f)",
                       paste(sapply(names(best$configuration), function(a)
                         paste0(a, "=", best$configuration[[a]])), collapse = ", "),
                       best$score), verbose)

  list(
    top_products = top_products,
    best_product = best$configuration,
    best_score = best$score,
    objective = objective,
    n_combinations_tested = nrow(grid),
    method = "exhaustive"
  )
}


# ==============================================================================
# GREEDY HILL-CLIMBING
# ==============================================================================

#' Optimize Product via Greedy Hill-Climbing
#'
#' Iteratively improves each attribute one at a time. Fast for large
#' design spaces but may find local optima. Runs multiple random starts
#' to mitigate this.
#'
#' @param utilities Utilities data frame
#' @param config Configuration
#' @param other_products Competing products
#' @param objective Optimization objective
#' @param price_attribute Price attribute name
#' @param cost_data Cost data
#' @param model_result Optional HB/LC model
#' @param method Simulation method
#' @param n_starts Number of random starting points (default: 20)
#' @param max_iterations Max iterations per start (default: 50)
#' @param verbose Logical
#' @return List with best product and search details
#' @export
optimize_product_greedy <- function(utilities,
                                     config,
                                     other_products = list(),
                                     objective = "share",
                                     price_attribute = NULL,
                                     cost_data = NULL,
                                     model_result = NULL,
                                     method = "logit",
                                     n_starts = 20,
                                     max_iterations = 50,
                                     verbose = TRUE) {

  attr_names <- config$attributes$AttributeName
  level_lists <- lapply(attr_names, function(attr) {
    get_attribute_levels(config, attr)
  })
  names(level_lists) <- attr_names

  log_verbose(sprintf("  → Greedy optimization: %d random starts, max %d iterations each",
                       n_starts, max_iterations), verbose)

  best_overall <- NULL
  best_overall_score <- -Inf

  for (s in seq_len(n_starts)) {
    # Random starting product
    current <- lapply(level_lists, function(levels) sample(levels, 1))
    names(current) <- attr_names

    current_score <- evaluate_product(
      current, utilities, other_products, objective,
      price_attribute, cost_data, model_result, config, method
    )

    for (iter in seq_len(max_iterations)) {
      improved <- FALSE

      for (attr in attr_names) {
        best_level <- current[[attr]]
        best_attr_score <- current_score

        for (level in level_lists[[attr]]) {
          if (level == current[[attr]]) next

          test <- current
          test[[attr]] <- level
          test_score <- evaluate_product(
            test, utilities, other_products, objective,
            price_attribute, cost_data, model_result, config, method
          )

          if (test_score > best_attr_score) {
            best_attr_score <- test_score
            best_level <- level
          }
        }

        if (best_level != current[[attr]]) {
          current[[attr]] <- best_level
          current_score <- best_attr_score
          improved <- TRUE
        }
      }

      if (!improved) break
    }

    if (current_score > best_overall_score) {
      best_overall_score <- current_score
      best_overall <- current
    }
  }

  log_verbose(sprintf("  ✓ Best product (greedy): score=%.2f", best_overall_score), verbose)

  list(
    best_product = best_overall,
    best_score = best_overall_score,
    objective = objective,
    n_starts = n_starts,
    method = "greedy"
  )
}


# ==============================================================================
# PRODUCT EVALUATION
# ==============================================================================

#' Evaluate a Product Configuration Against an Objective
#'
#' @param product Named list of attribute levels
#' @param utilities Utilities data frame
#' @param other_products Competing products
#' @param objective "share", "utility", or "revenue"
#' @param price_attribute Price attribute name (for revenue)
#' @param cost_data Cost data (for profit)
#' @param model_result Optional HB/LC model
#' @param config Configuration
#' @param method Simulation method
#' @return Numeric score
#' @keywords internal
evaluate_product <- function(product, utilities, other_products, objective,
                              price_attribute, cost_data, model_result, config, method) {

  if (objective == "utility") {
    # Simple: total utility of the product
    return(calculate_product_utility(product, utilities))
  }

  # Calculate market share
  all_products <- c(list(product), other_products)

  if (!is.null(model_result) && !is.null(model_result$individual_betas) && !is.null(config)) {
    shares <- predict_market_shares_individual(
      all_products, model_result, config, method = method
    )
  } else {
    shares <- predict_market_shares(all_products, utilities, method = method)
  }

  share <- shares$Share_Percent[1] / 100  # proportion

  if (objective == "share") {
    return(share * 100)  # percentage
  }

  if (objective == "revenue") {
    # Revenue = share * price
    price <- get_product_price(product, price_attribute)
    return(share * price)
  }

  if (objective == "profit") {
    # Profit = share * (price - cost)
    price <- get_product_price(product, price_attribute)
    cost <- get_product_cost(product, cost_data)
    return(share * (price - cost))
  }

  share * 100  # default to share
}


#' Get Numeric Price from Product Configuration
#' @keywords internal
get_product_price <- function(product, price_attribute) {

  if (is.null(price_attribute) || is.null(product[[price_attribute]])) {
    return(1)  # Default unit price
  }

  price_str <- product[[price_attribute]]
  price <- as.numeric(gsub("[^0-9.]", "", price_str))
  if (is.na(price)) 1 else price
}


#' Get Cost from Cost Data
#' @keywords internal
get_product_cost <- function(product, cost_data) {

  if (is.null(cost_data)) return(0)

  total_cost <- 0
  for (attr in names(product)) {
    level <- product[[attr]]
    key <- paste0(attr, "_", level)
    if (!is.null(cost_data[[key]])) {
      total_cost <- total_cost + cost_data[[key]]
    } else if (!is.null(cost_data[[attr]])) {
      total_cost <- total_cost + cost_data[[attr]]
    }
  }

  total_cost
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>Conjoint Optimizer module loaded (v%s)", CONJOINT_OPTIMIZER_VERSION))
