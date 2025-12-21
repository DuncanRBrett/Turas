# ==============================================================================
# MARKET SIMULATOR - SHARE PREDICTION FUNCTIONS
# ==============================================================================
#
# This file contains functions for predicting market shares from part-worth
# utilities using choice models (multinomial logit, first-choice rule).
#
# Part of: Turas Enhanced Conjoint Analysis Module
# Version: 2.0.0
# ==============================================================================

# ==============================================================================
# 1. SHARE PREDICTION - MULTINOMIAL LOGIT
# ==============================================================================

#' Predict market shares using multinomial logit model
#'
#' @param products List of product configurations (each product is a named list of levels)
#' @param utilities Data frame with columns: Attribute, Level, Utility
#' @param method Character: "logit" (default), "first_choice", or "randomized_first_choice"
#' @param availability Numeric vector of availability weights (0-1) for each product
#' @param verbose Logical: print progress messages?
#'
#' @return Data frame with columns: Product, Total_Utility, Probability, Share_Percent
#'
#' @examples
#' products <- list(
#'   list(Brand = "Apple", Price = "$299", Screen_Size = "6.1 inches"),
#'   list(Brand = "Samsung", Price = "$399", Screen_Size = "5.5 inches")
#' )
#' shares <- predict_market_shares(products, utilities)
predict_market_shares <- function(products,
                                   utilities,
                                   method = "logit",
                                   availability = NULL,
                                   verbose = FALSE) {

  # Input validation
  if (!is.list(products) || length(products) == 0) {
    stop("'products' must be a non-empty list of product configurations")
  }

  if (!all(c("Attribute", "Level", "Utility") %in% names(utilities))) {
    stop("'utilities' must have columns: Attribute, Level, Utility")
  }

  # Default availability (all products equally available)
  if (is.null(availability)) {
    availability <- rep(1, length(products))
  }

  if (length(availability) != length(products)) {
    stop("'availability' must have same length as number of products")
  }

  # Calculate total utility for each product
  product_utilities <- vapply(seq_along(products), function(i) {
    calculate_product_utility(products[[i]], utilities, verbose = verbose)
  }, numeric(1))

  # Predict shares based on method
  shares <- switch(method,
    logit = predict_shares_logit(product_utilities, availability),
    first_choice = predict_shares_first_choice(product_utilities, availability),
    randomized_first_choice = predict_shares_randomized_first_choice(product_utilities, availability),
    stop(sprintf("Unknown method: %s. Use 'logit', 'first_choice', or 'randomized_first_choice'", method))
  )

  # Create result data frame
  result <- data.frame(
    Product = paste0("Product_", seq_along(products)),
    Total_Utility = product_utilities,
    Probability = shares,
    Share_Percent = shares * 100,
    stringsAsFactors = FALSE
  )

  if (verbose) {
    cat("\nMarket Share Predictions (", method, " model):\n", sep = "")
    for (i in seq_len(nrow(result))) {
      cat(sprintf("  %s: %.1f%%\n", result$Product[i], result$Share_Percent[i]))
    }
  }

  result
}


#' Calculate total utility for a single product
#'
#' @param product Named list of attribute levels (e.g., list(Brand="Apple", Price="$299"))
#' @param utilities Data frame with Attribute, Level, Utility columns
#' @param verbose Logical
#'
#' @return Numeric: total utility for the product
calculate_product_utility <- function(product, utilities, verbose = FALSE) {

  total_utility <- 0

  for (attr in names(product)) {
    level <- product[[attr]]

    # Find utility for this attribute-level combination
    util_row <- utilities[utilities$Attribute == attr & utilities$Level == level, ]

    if (nrow(util_row) == 0) {
      message(sprintf("[TRS INFO] CONJ_UTIL_NOT_FOUND: No utility found for %s = %s - using 0", attr, level))
      attr_utility <- 0
    } else if (nrow(util_row) > 1) {
      message(sprintf("[TRS INFO] CONJ_UTIL_DUPLICATE: Multiple utilities found for %s = %s - using first", attr, level))
      attr_utility <- util_row$Utility[1]
    } else {
      attr_utility <- util_row$Utility[1]
    }

    total_utility <- total_utility + attr_utility

    if (verbose) {
      cat(sprintf("  %s = %s: utility = %.3f\n", attr, level, attr_utility))
    }
  }

  total_utility
}


#' Predict shares using multinomial logit (MNL) model
#'
#' @param utilities Numeric vector of total utilities for each product
#' @param availability Numeric vector of availability weights (0-1)
#'
#' @return Numeric vector of predicted shares (probabilities)
predict_shares_logit <- function(utilities, availability) {

  # MNL formula: P(i) = exp(U_i) / sum(exp(U_j))
  # With availability: P(i) = A_i * exp(U_i) / sum(A_j * exp(U_j))

  # Use log-sum-exp trick for numerical stability
  max_utility <- max(utilities)
  exp_utilities <- exp(utilities - max_utility) * availability
  sum_exp_utilities <- sum(exp_utilities)

  shares <- exp_utilities / sum_exp_utilities

  shares
}


#' Predict shares using deterministic first-choice rule
#'
#' @param utilities Numeric vector of total utilities
#' @param availability Numeric vector of availability weights
#'
#' @return Numeric vector: 1 for highest utility product, 0 for others
predict_shares_first_choice <- function(utilities, availability) {

  # Adjust utilities by availability (unavailable products get -Inf)
  adjusted_utilities <- ifelse(availability > 0, utilities, -Inf)

  # Highest utility product gets 100% share
  shares <- rep(0, length(utilities))
  max_idx <- which.max(adjusted_utilities)
  shares[max_idx] <- 1

  shares
}


#' Predict shares using randomized first-choice rule with ties
#'
#' @param utilities Numeric vector of total utilities
#' @param availability Numeric vector of availability weights
#' @param tie_tolerance Numeric: utilities within this range are considered tied
#'
#' @return Numeric vector of shares (equal splits for ties)
predict_shares_randomized_first_choice <- function(utilities,
                                                    availability,
                                                    tie_tolerance = 0.01) {

  # Adjust utilities by availability
  adjusted_utilities <- ifelse(availability > 0, utilities, -Inf)

  # Find products within tie_tolerance of maximum
  max_utility <- max(adjusted_utilities)
  tied_products <- abs(adjusted_utilities - max_utility) < tie_tolerance

  # Split share equally among tied products
  n_tied <- sum(tied_products)
  shares <- ifelse(tied_products, 1 / n_tied, 0)

  shares
}


# ==============================================================================
# 2. SENSITIVITY ANALYSIS
# ==============================================================================

#' Run one-way sensitivity analysis for an attribute
#'
#' @param base_product Named list of attribute levels
#' @param attribute Character: which attribute to vary
#' @param all_levels Character vector: all possible levels for this attribute
#' @param utilities Data frame with Attribute, Level, Utility
#' @param other_products List of competing product configurations
#' @param method Character: share prediction method
#'
#' @return Data frame with Level, Share_Percent, Share_Change columns
sensitivity_one_way <- function(base_product,
                                 attribute,
                                 all_levels,
                                 utilities,
                                 other_products = list(),
                                 method = "logit") {

  # Get current level and share
  current_level <- base_product[[attribute]]
  all_products <- c(list(base_product), other_products)
  current_shares <- predict_market_shares(all_products, utilities, method = method)
  current_share <- current_shares$Share_Percent[1]

  # Test each level
  results <- lapply(all_levels, function(level) {
    # Create modified product
    modified_product <- base_product
    modified_product[[attribute]] <- level

    # Predict shares with modified product
    all_products_modified <- c(list(modified_product), other_products)
    new_shares <- predict_market_shares(all_products_modified, utilities, method = method)
    new_share <- new_shares$Share_Percent[1]

    data.frame(
      Level = level,
      Share_Percent = new_share,
      Share_Change = new_share - current_share,
      Is_Current = level == current_level,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, results)
}


#' Run two-way sensitivity analysis for two attributes
#'
#' @param base_product Named list of attribute levels
#' @param attribute1 Character: first attribute to vary
#' @param levels1 Character vector: levels for attribute1
#' @param attribute2 Character: second attribute to vary
#' @param levels2 Character vector: levels for attribute2
#' @param utilities Data frame with utilities
#' @param other_products List of competing products
#' @param method Character: share prediction method
#'
#' @return Data frame with grid of share predictions
sensitivity_two_way <- function(base_product,
                                 attribute1,
                                 levels1,
                                 attribute2,
                                 levels2,
                                 utilities,
                                 other_products = list(),
                                 method = "logit") {

  # Create grid of level combinations
  grid <- expand.grid(
    Level1 = levels1,
    Level2 = levels2,
    stringsAsFactors = FALSE
  )

  # Calculate share for each combination
  grid$Share_Percent <- vapply(seq_len(nrow(grid)), function(i) {
    modified_product <- base_product
    modified_product[[attribute1]] <- grid$Level1[i]
    modified_product[[attribute2]] <- grid$Level2[i]

    all_products <- c(list(modified_product), other_products)
    shares <- predict_market_shares(all_products, utilities, method = method)
    shares$Share_Percent[1]
  }, numeric(1))

  # Add column names
  names(grid)[1:2] <- c(attribute1, attribute2)

  grid
}


# ==============================================================================
# 3. WHAT-IF SCENARIO ANALYSIS
# ==============================================================================

#' Compare multiple product scenarios
#'
#' @param scenarios Named list of product configurations
#' @param utilities Data frame with utilities
#' @param method Character: share prediction method
#'
#' @return Data frame comparing scenarios
compare_scenarios <- function(scenarios, utilities, method = "logit") {

  if (!is.list(scenarios) || is.null(names(scenarios))) {
    stop("'scenarios' must be a named list of product configurations")
  }

  results <- lapply(names(scenarios), function(scenario_name) {
    products <- scenarios[[scenario_name]]

    # Ensure products is a list
    if (!is.list(products[[1]])) {
      products <- list(products)
    }

    shares <- predict_market_shares(products, utilities, method = method)

    data.frame(
      Scenario = scenario_name,
      Product = shares$Product,
      Total_Utility = shares$Total_Utility,
      Share_Percent = shares$Share_Percent,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, results)
}


#' Optimize a product to maximize market share
#'
#' @param base_product Named list of starting configuration
#' @param utilities Data frame with utilities
#' @param config Configuration object with attribute definitions
#' @param other_products List of competing products
#' @param max_iterations Integer: maximum optimization iterations
#' @param method Character: share prediction method
#'
#' @return List with optimized product and improvement details
optimize_product <- function(base_product,
                              utilities,
                              config,
                              other_products = list(),
                              max_iterations = 100,
                              method = "logit") {

  current_product <- base_product
  iteration <- 0
  improved <- TRUE

  history <- list()

  while (improved && iteration < max_iterations) {
    iteration <- iteration + 1
    improved <- FALSE

    # Calculate current share
    all_products <- c(list(current_product), other_products)
    current_shares <- predict_market_shares(all_products, utilities, method = method)
    current_share <- current_shares$Share_Percent[1]

    # Try improving each attribute
    for (attr in names(current_product)) {
      # Get all possible levels for this attribute
      attr_levels <- utilities$Level[utilities$Attribute == attr]
      attr_levels <- unique(attr_levels)

      # Test each level
      best_level <- current_product[[attr]]
      best_share <- current_share

      for (level in attr_levels) {
        if (level == current_product[[attr]]) next

        # Test this level
        test_product <- current_product
        test_product[[attr]] <- level

        all_products_test <- c(list(test_product), other_products)
        test_shares <- predict_market_shares(all_products_test, utilities, method = method)
        test_share <- test_shares$Share_Percent[1]

        if (test_share > best_share) {
          best_share <- test_share
          best_level <- level
        }
      }

      # If improvement found, update product
      if (best_level != current_product[[attr]]) {
        current_product[[attr]] <- best_level
        current_share <- best_share
        improved <- TRUE

        history[[length(history) + 1]] <- list(
          iteration = iteration,
          attribute = attr,
          new_level = best_level,
          share = best_share
        )
      }
    }
  }

  # Final share calculation
  all_products_final <- c(list(current_product), other_products)
  final_shares <- predict_market_shares(all_products_final, utilities, method = method)

  list(
    optimized_product = current_product,
    final_share = final_shares$Share_Percent[1],
    initial_share = predict_market_shares(c(list(base_product), other_products),
                                           utilities, method = method)$Share_Percent[1],
    improvement = final_shares$Share_Percent[1] -
                   predict_market_shares(c(list(base_product), other_products),
                                        utilities, method = method)$Share_Percent[1],
    iterations = iteration,
    history = history,
    converged = !improved
  )
}


# ==============================================================================
# 4. UTILITY FUNCTIONS
# ==============================================================================

#' Extract product configuration from dropdown selections in Excel
#'
#' @param selections Named vector of level selections
#'
#' @return Named list (product configuration)
excel_to_product <- function(selections) {
  as.list(selections)
}


#' Format product for display
#'
#' @param product Named list of attribute levels
#'
#' @return Character string describing the product
format_product <- function(product) {
  parts <- vapply(names(product), function(attr) {
    sprintf("%s: %s", attr, product[[attr]])
  }, character(1))

  paste(parts, collapse = ", ")
}
