# ==============================================================================
# MARKET SIMULATOR - SHARE PREDICTION FUNCTIONS
# ==============================================================================
#
# This file contains functions for predicting market shares from part-worth
# utilities using choice models (multinomial logit, first-choice rule).
#
# Part of: Turas Conjoint Analysis Module
# Version: 3.0.0
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
    conjoint_refuse(
      code = "CFG_SIMULATOR_INVALID_PRODUCTS",
      title = "Invalid Products Configuration",
      problem = "'products' must be a non-empty list of product configurations",
      why_it_matters = "The market simulator requires at least one product configuration to predict market shares.",
      how_to_fix = "Provide a list of product configurations, each as a named list of attribute levels"
    )
  }

  if (!all(c("Attribute", "Level", "Utility") %in% names(utilities))) {
    conjoint_refuse(
      code = "DATA_SIMULATOR_INVALID_UTILITIES",
      title = "Invalid Utilities Data Frame",
      problem = "'utilities' must have columns: Attribute, Level, Utility",
      why_it_matters = "The market simulator needs part-worth utilities to calculate product preferences.",
      how_to_fix = "Ensure utilities data frame has 'Attribute', 'Level', and 'Utility' columns"
    )
  }

  # Default availability (all products equally available)
  if (is.null(availability)) {
    availability <- rep(1, length(products))
  }

  if (length(availability) != length(products)) {
    conjoint_refuse(
      code = "CFG_SIMULATOR_AVAILABILITY_MISMATCH",
      title = "Availability Vector Length Mismatch",
      problem = "'availability' must have same length as number of products",
      why_it_matters = "Each product needs an availability weight to calculate accurate market shares.",
      how_to_fix = sprintf("Provide %d availability values (one per product), or leave NULL for equal availability", length(products))
    )
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
    # NOTE: conjoint_refuse halts execution via stop(), so this never returns a value

    # to `shares`. Kept as defense-in-depth — if conjoint_refuse were ever changed to
    # return instead of halt, this would assign the refusal list to `shares`.
    conjoint_refuse(
      code = "CFG_SIMULATOR_UNKNOWN_METHOD",
      title = "Unknown Simulation Method",
      problem = sprintf("Unknown method: %s", method),
      why_it_matters = "The simulator requires a valid prediction method to calculate market shares.",
      how_to_fix = "Use one of: 'logit', 'first_choice', or 'randomized_first_choice'"
    )
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

  # Guard against division by zero (e.g., all availability weights are 0)
  if (sum_exp_utilities < 1e-10) {
    message("[TRS INFO] CONJ_SIMULATOR_ZERO_SHARES: All products unavailable — returning equal shares")
    return(rep(1 / length(utilities), length(utilities)))
  }

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
    conjoint_refuse(
      code = "CFG_SIMULATOR_INVALID_SCENARIOS",
      title = "Invalid Scenarios Configuration",
      problem = "'scenarios' must be a named list of product configurations",
      why_it_matters = "Scenario comparison requires named scenarios to distinguish between different market conditions.",
      how_to_fix = "Provide a named list where each element is a scenario name with corresponding product configurations"
    )
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


# ==============================================================================
# 5. INDIVIDUAL-LEVEL SIMULATION (HB / LC)
# ==============================================================================

#' Predict Market Shares Using Individual-Level Utilities
#'
#' Uses HB or LC individual-level betas for more accurate simulation.
#' Supports Randomized First Choice (RFC) via Gumbel error draws.
#'
#' @param products List of product configurations
#' @param model_result HB or LC model result with individual_betas
#' @param config Configuration object
#' @param method "logit", "first_choice", or "rfc"
#' @param n_draws Number of RFC error draws per respondent (default: 1000)
#' @param segment_filter Optional vector of respondent IDs to include
#' @return Data frame with Product, Share_Percent, and per-respondent details
#' @export
predict_market_shares_individual <- function(products,
                                              model_result,
                                              config,
                                              method = "logit",
                                              n_draws = 1000,
                                              segment_filter = NULL) {

  if (is.null(model_result$individual_betas)) {
    conjoint_refuse(
      code = "SIM_NO_INDIVIDUAL_BETAS",
      title = "Individual-Level Utilities Required",
      problem = "Individual-level simulation requires HB or LC estimation results.",
      why_it_matters = "Aggregate utilities cannot capture preference heterogeneity.",
      how_to_fix = "Run with estimation_method = 'hb' or 'latent_class'"
    )
  }

  individual_betas <- model_result$individual_betas
  col_names <- model_result$col_names
  attribute_map <- model_result$attribute_map
  respondent_ids <- model_result$respondent_ids

  # Apply segment filter if provided
  if (!is.null(segment_filter)) {
    mask <- respondent_ids %in% segment_filter
    individual_betas <- individual_betas[mask, , drop = FALSE]
    respondent_ids <- respondent_ids[mask]
  }

  n_respondents <- nrow(individual_betas)
  n_products <- length(products)

  # Build design vectors for each product
  product_designs <- lapply(products, function(prod) {
    build_product_design_vector(prod, config, col_names, attribute_map)
  })

  if (method == "rfc") {
    # Randomized First Choice with Gumbel error
    shares <- simulate_rfc(product_designs, individual_betas, n_draws)
  } else if (method == "first_choice") {
    # Deterministic first choice per respondent
    shares <- simulate_first_choice_individual(product_designs, individual_betas)
  } else {
    # Logit per respondent, then average
    shares <- simulate_logit_individual(product_designs, individual_betas)
  }

  data.frame(
    Product = paste0("Product_", seq_len(n_products)),
    Share_Percent = shares * 100,
    n_respondents = n_respondents,
    method = method,
    stringsAsFactors = FALSE
  )
}


#' Build Design Vector for a Product Configuration
#'
#' @param product Named list of attribute levels
#' @param config Configuration
#' @param col_names Column names from HB design matrix
#' @param attribute_map Attribute/level mapping
#' @return Numeric design vector
#' @keywords internal
build_product_design_vector <- function(product, config, col_names, attribute_map) {

  design <- numeric(length(col_names))
  names(design) <- col_names

  for (cn in col_names) {
    if (!is.null(attribute_map[[cn]])) {
      attr_name <- attribute_map[[cn]]$attribute
      level_name <- attribute_map[[cn]]$level
      if (!is.null(product[[attr_name]]) && product[[attr_name]] == level_name) {
        design[cn] <- 1
      }
    }
  }

  design
}


#' Simulate RFC (Randomized First Choice)
#'
#' Adds Gumbel-distributed error to each respondent's utilities, then
#' selects the highest-utility product. Repeats n_draws times.
#'
#' @param product_designs List of design vectors
#' @param individual_betas Matrix [respondents x parameters]
#' @param n_draws Number of error draws
#' @return Numeric vector of share proportions
#' @keywords internal
simulate_rfc <- function(product_designs, individual_betas, n_draws) {

  n_respondents <- nrow(individual_betas)
  n_products <- length(product_designs)

  # Calculate deterministic utilities per product per respondent
  V <- matrix(NA, nrow = n_respondents, ncol = n_products)
  for (j in seq_len(n_products)) {
    V[, j] <- individual_betas %*% product_designs[[j]]
  }

  # RFC: add Gumbel error and count first choices
  choice_counts <- numeric(n_products)

  for (d in seq_len(n_draws)) {
    # Generate Gumbel errors for all respondents x products
    gumbel_errors <- matrix(
      -log(-log(runif(n_respondents * n_products))),
      nrow = n_respondents, ncol = n_products
    )
    U <- V + gumbel_errors
    choices <- apply(U, 1, which.max)
    tab <- tabulate(choices, nbins = n_products)
    choice_counts <- choice_counts + tab
  }

  # Average across draws and respondents
  choice_counts / (n_draws * n_respondents)
}


#' Simulate First Choice per Respondent (Deterministic)
#' @keywords internal
simulate_first_choice_individual <- function(product_designs, individual_betas) {

  n_respondents <- nrow(individual_betas)
  n_products <- length(product_designs)

  V <- matrix(NA, nrow = n_respondents, ncol = n_products)
  for (j in seq_len(n_products)) {
    V[, j] <- individual_betas %*% product_designs[[j]]
  }

  choices <- apply(V, 1, which.max)
  tab <- tabulate(choices, nbins = n_products)
  tab / n_respondents
}


#' Simulate Logit per Respondent
#' @keywords internal
simulate_logit_individual <- function(product_designs, individual_betas) {

  n_respondents <- nrow(individual_betas)
  n_products <- length(product_designs)

  V <- matrix(NA, nrow = n_respondents, ncol = n_products)
  for (j in seq_len(n_products)) {
    V[, j] <- individual_betas %*% product_designs[[j]]
  }

  # Softmax per respondent
  shares_per_resp <- matrix(NA, nrow = n_respondents, ncol = n_products)
  for (i in seq_len(n_respondents)) {
    v_i <- V[i, ]
    exp_v <- exp(v_i - max(v_i))
    shares_per_resp[i, ] <- exp_v / sum(exp_v)
  }

  # Average across respondents
  colMeans(shares_per_resp)
}


# ==============================================================================
# 6. SOURCE OF VOLUME ANALYSIS
# ==============================================================================

#' Calculate Source of Volume
#'
#' Determines where a new product's share comes from (share shift analysis).
#' Compares a baseline scenario (without new product) against a test scenario
#' (with new product).
#'
#' @param baseline_products List of existing product configurations
#' @param new_product New product configuration to add
#' @param utilities Utilities data frame (or model_result for individual-level)
#' @param model_result Optional HB/LC model for individual-level simulation
#' @param config Optional configuration (needed for individual-level)
#' @param method Simulation method
#' @return Data frame with share shifts
#' @export
source_of_volume <- function(baseline_products,
                              new_product,
                              utilities = NULL,
                              model_result = NULL,
                              config = NULL,
                              method = "logit") {

  # Calculate baseline shares (without new product)
  if (!is.null(model_result) && !is.null(model_result$individual_betas) && !is.null(config)) {
    baseline_shares <- predict_market_shares_individual(
      baseline_products, model_result, config, method = method
    )
    # Add new product and recalculate
    all_products <- c(baseline_products, list(new_product))
    test_shares <- predict_market_shares_individual(
      all_products, model_result, config, method = method
    )
  } else if (!is.null(utilities)) {
    baseline_shares <- predict_market_shares(baseline_products, utilities, method = method)
    all_products <- c(baseline_products, list(new_product))
    test_shares <- predict_market_shares(all_products, utilities, method = method)
  } else {
    conjoint_refuse(
      code = "SIM_NO_UTILITIES",
      title = "No Utilities Provided",
      problem = "Either utilities data frame or model_result must be provided.",
      why_it_matters = "Cannot calculate source of volume without utilities.",
      how_to_fix = "Provide either 'utilities' or 'model_result' parameter"
    )
  }

  n_baseline <- length(baseline_products)
  new_product_share <- test_shares$Share_Percent[n_baseline + 1]

  # Calculate share shifts for baseline products
  result <- data.frame(
    Product = c(baseline_shares$Product, "New_Product"),
    Baseline_Share = c(baseline_shares$Share_Percent, 0),
    Test_Share = test_shares$Share_Percent,
    Share_Change = test_shares$Share_Percent - c(baseline_shares$Share_Percent, 0),
    stringsAsFactors = FALSE
  )

  # Proportion of new product's volume from each existing product
  existing_shifts <- result$Share_Change[1:n_baseline]
  total_lost <- sum(abs(existing_shifts))
  result$Volume_Contribution_Pct <- c(
    if (total_lost > 0) abs(existing_shifts) / total_lost * 100 else rep(0, n_baseline),
    NA_real_
  )

  result
}


# ==============================================================================
# 7. DEMAND CURVE GENERATION
# ==============================================================================

#' Generate Demand Curve for Price Attribute
#'
#' Sweeps through all price levels, computing market share at each.
#'
#' @param base_product Named list product configuration
#' @param price_attribute Name of the price attribute
#' @param price_levels Vector of price levels to test
#' @param utilities Utilities data frame
#' @param other_products List of competing products
#' @param model_result Optional HB/LC model
#' @param config Optional configuration
#' @param method Simulation method
#' @return Data frame with Price, Share_Percent columns
#' @export
generate_demand_curve <- function(base_product,
                                   price_attribute,
                                   price_levels,
                                   utilities = NULL,
                                   other_products = list(),
                                   model_result = NULL,
                                   config = NULL,
                                   method = "logit") {

  results <- lapply(price_levels, function(price) {
    test_product <- base_product
    test_product[[price_attribute]] <- price

    all_products <- c(list(test_product), other_products)

    if (!is.null(model_result) && !is.null(model_result$individual_betas) && !is.null(config)) {
      shares <- predict_market_shares_individual(
        all_products, model_result, config, method = method
      )
    } else {
      shares <- predict_market_shares(all_products, utilities, method = method)
    }

    data.frame(
      Price = price,
      Share_Percent = shares$Share_Percent[1],
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, results)
}


# ==============================================================================
# CONFIDENCE INTERVALS ON SIMULATED SHARES
# ==============================================================================

#' Predict Market Shares with Confidence Intervals
#'
#' Computes share predictions with bootstrap CIs by resampling individual-level
#' utilities (from HB estimation). Each bootstrap draw samples respondents with
#' replacement, computes individual-level shares, and aggregates.
#'
#' For HB models, this uses true individual-level RFC (each respondent has their
#' own beta vector). For aggregate models, CIs cannot be computed and NA is returned.
#'
#' @param products List of product configurations
#' @param utilities Data frame with Attribute, Level, Utility columns (aggregate)
#' @param individual_betas Matrix (n_respondents x n_params) of individual betas
#' @param attribute_map List mapping column names to attribute/level pairs
#' @param method Character: "logit" or "rfc" (default "rfc")
#' @param n_boot Integer: number of bootstrap draws (default 1000)
#' @param conf_level Numeric: confidence level (default 0.95)
#' @param verbose Logical
#'
#' @return Data frame with: Product, Share_Percent, Lower, Upper, SE
#'
#' @export
predict_shares_with_ci <- function(products,
                                   utilities,
                                   individual_betas = NULL,
                                   attribute_map = NULL,
                                   method = "rfc",
                                   n_boot = 1000,
                                   conf_level = 0.95,
                                   verbose = FALSE) {

  n_products <- length(products)

  # If no individual betas, fall back to aggregate (no CIs possible)
  if (is.null(individual_betas) || is.null(attribute_map)) {
    base_shares <- predict_market_shares(products, utilities, method = method)
    base_shares$Lower <- NA_real_
    base_shares$Upper <- NA_real_
    base_shares$SE <- NA_real_
    if (verbose) message("[TRS INFO] No individual betas available - CIs not computed")
    return(base_shares)
  }

  n_respondents <- nrow(individual_betas)
  param_names <- colnames(individual_betas)

  # Build design vectors for each product
  # Each product config maps to a utility = sum of relevant betas
  product_design <- matrix(0, nrow = n_products, ncol = ncol(individual_betas))
  colnames(product_design) <- param_names

  for (p_idx in seq_len(n_products)) {
    prod <- products[[p_idx]]
    for (attr_name in names(prod)) {
      level_val <- prod[[attr_name]]
      # Find which column corresponds to this attribute-level
      for (col_idx in seq_along(attribute_map)) {
        am <- attribute_map[[col_idx]]
        if (am$attribute == attr_name && am$level == level_val) {
          product_design[p_idx, col_idx] <- 1
          break
        }
      }
    }
  }

  # Compute individual-level shares for a given set of betas
  compute_individual_shares <- function(betas_matrix) {
    n <- nrow(betas_matrix)
    # Compute utility for each product for each respondent
    U <- betas_matrix %*% t(product_design)  # n_resp x n_products

    if (method == "rfc") {
      # RFC: add Gumbel noise per respondent, count first choices
      wins <- rep(0, n_products)
      for (i in seq_len(n)) {
        gumbel <- -log(-log(runif(n_products)))
        noisy_u <- U[i, ] + gumbel
        wins[which.max(noisy_u)] <- wins[which.max(noisy_u)] + 1
      }
      wins / n * 100
    } else {
      # Logit: average of individual-level logit shares
      share_mat <- matrix(0, nrow = n, ncol = n_products)
      for (i in seq_len(n)) {
        u <- U[i, ]
        eu <- exp(u - max(u))
        share_mat[i, ] <- eu / sum(eu) * 100
      }
      colMeans(share_mat)
    }
  }

  # Point estimate
  point_shares <- compute_individual_shares(individual_betas)

  # Bootstrap
  if (verbose) cat(sprintf("  Computing %d bootstrap CIs...\n", n_boot))
  boot_shares <- matrix(0, nrow = n_boot, ncol = n_products)
  for (b in seq_len(n_boot)) {
    boot_idx <- sample.int(n_respondents, replace = TRUE)
    boot_shares[b, ] <- compute_individual_shares(individual_betas[boot_idx, , drop = FALSE])
  }

  # CI bounds (percentile method)
  alpha <- (1 - conf_level) / 2
  lower <- apply(boot_shares, 2, quantile, probs = alpha)
  upper <- apply(boot_shares, 2, quantile, probs = 1 - alpha)
  se <- apply(boot_shares, 2, sd)

  data.frame(
    Product = paste0("Product_", seq_len(n_products)),
    Share_Percent = point_shares,
    Lower = lower,
    Upper = upper,
    SE = se,
    stringsAsFactors = FALSE
  )
}
