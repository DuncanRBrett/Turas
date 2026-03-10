# ==============================================================================
# WILLINGNESS TO PAY (WTP) - CONJOINT
# ==============================================================================
#
# Module: Conjoint Analysis - Willingness to Pay
# Purpose: Estimate monetary value of attribute level changes
# Version: 3.0.0
# Date: 2026-03-10
#
# WHAT WTP PROVIDES:
#   - Dollar value of switching from one level to another
#   - Marginal rate of substitution (utility/price coefficient)
#   - Individual-level WTP distributions (with HB)
#   - Confidence intervals via delta method or bootstrap
#   - Demand/price sensitivity curves
#
# METHODOLOGY:
#   WTP = -(Beta_attribute / Beta_price)
#   where Beta_price is the marginal utility of a one-unit price change.
#
#   For categorical price levels, the price coefficient is estimated
#   by regressing price utilities on numeric price values.
#
# ==============================================================================

CONJOINT_WTP_VERSION <- "3.0.0"

# Null coalesce
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}


# ==============================================================================
# MAIN WTP CALCULATION
# ==============================================================================

#' Calculate Willingness to Pay
#'
#' Estimates the monetary value of each attribute level relative to its
#' baseline. Requires a designated price attribute with numeric levels.
#'
#' @param utilities Utilities data frame (Attribute, Level, Utility)
#' @param config Configuration (must have wtp_price_attribute)
#' @param model_result Optional HB/LC model for individual-level WTP
#' @param verbose Logical
#' @return List with wtp_table, price_coefficient, method, individual_wtp (if HB)
#' @export
calculate_wtp <- function(utilities, config, model_result = NULL, verbose = TRUE) {

  price_attr <- config$wtp_price_attribute
  wtp_method <- config$wtp_method %||% "marginal"

  if (is.na(price_attr) || is.null(price_attr) || nchar(price_attr) == 0) {
    conjoint_refuse(
      code = "WTP_NO_PRICE_ATTRIBUTE",
      title = "Price Attribute Not Specified",
      problem = "WTP calculation requires a price attribute to be specified.",
      why_it_matters = "Cannot convert utilities to dollar values without a price benchmark.",
      how_to_fix = "Set 'wtp_price_attribute' in your configuration to the name of the price attribute"
    )
  }

  log_verbose("Calculating Willingness to Pay...", verbose)

  # Extract price utilities and estimate price coefficient
  price_coef <- estimate_price_coefficient(utilities, price_attr, verbose)

  if (is.null(price_coef) || abs(price_coef) < 1e-10) {
    conjoint_refuse(
      code = "WTP_ZERO_PRICE_COEFFICIENT",
      title = "Price Coefficient is Zero",
      problem = "The price coefficient is zero or near-zero, making WTP undefined.",
      why_it_matters = "WTP = utility / price_coefficient; division by zero is undefined.",
      how_to_fix = c(
        "Check that the price attribute has meaningful variation in utilities",
        "Verify price levels are ordered correctly",
        "The price attribute may not be driving choices in your data"
      )
    )
  }

  # Calculate aggregate WTP
  wtp_table <- calculate_aggregate_wtp(utilities, price_attr, price_coef, config, verbose)

  result <- list(
    wtp_table = wtp_table,
    price_coefficient = price_coef,
    price_attribute = price_attr,
    method = wtp_method
  )

  # Individual-level WTP if HB/LC results available
  if (!is.null(model_result) && !is.null(model_result$individual_betas)) {
    log_verbose("  → Calculating individual-level WTP...", verbose)
    result$individual_wtp <- calculate_individual_wtp(
      model_result, config, price_attr, verbose
    )
    result$wtp_distribution <- summarize_wtp_distribution(result$individual_wtp)
  }

  log_verbose("  ✓ WTP calculation complete", verbose)

  result
}


# ==============================================================================
# PRICE COEFFICIENT ESTIMATION
# ==============================================================================

#' Estimate Price Coefficient from Part-Worth Utilities
#'
#' For categorical price levels, fits a linear regression of utilities
#' on numeric price values to get the marginal utility per dollar.
#'
#' @param utilities Utilities data frame
#' @param price_attr Name of the price attribute
#' @param verbose Logical
#' @return Numeric price coefficient (utility per dollar/unit)
#' @keywords internal
estimate_price_coefficient <- function(utilities, price_attr, verbose = TRUE) {

  price_utils <- utilities[utilities$Attribute == price_attr, ]

  if (nrow(price_utils) == 0) {
    conjoint_refuse(
      code = "WTP_PRICE_ATTR_NOT_FOUND",
      title = "Price Attribute Not Found in Utilities",
      problem = sprintf("Price attribute '%s' not found in utilities.", price_attr),
      why_it_matters = "Cannot estimate price coefficient without price utilities.",
      how_to_fix = "Check that wtp_price_attribute matches an attribute name in your config"
    )
  }

  # Extract numeric values from price levels
  price_values <- extract_numeric_prices(price_utils$Level)

  if (all(is.na(price_values))) {
    conjoint_refuse(
      code = "WTP_NON_NUMERIC_PRICES",
      title = "Price Levels Are Not Numeric",
      problem = "Could not extract numeric values from price levels.",
      why_it_matters = "WTP requires numeric price values to calculate dollar equivalents.",
      how_to_fix = c(
        "Price levels should contain numeric values (e.g., '$9.99', '99', 'R150')",
        sprintf("Current levels: %s", paste(price_utils$Level, collapse = ", "))
      )
    )
  }

  # Fit linear regression: Utility = a + b * Price
  fit <- lm(price_utils$Utility ~ price_values)
  price_coef <- coef(fit)[2]  # slope = utility per price unit

  if (verbose) {
    log_verbose(sprintf("  → Price coefficient: %.4f (utility per unit price)", price_coef), verbose)
    log_verbose(sprintf("  → Price range: %s to %s",
                         min(price_values, na.rm = TRUE),
                         max(price_values, na.rm = TRUE)), verbose)
  }

  as.numeric(price_coef)
}


#' Extract Numeric Price Values from Level Labels
#'
#' Handles common price formats: "$9.99", "R150", "150", "EUR 50.00"
#'
#' @param levels Character vector of price level labels
#' @return Numeric vector of price values
#' @keywords internal
extract_numeric_prices <- function(levels) {

  # Strip currency symbols, spaces, commas
  cleaned <- gsub("[^0-9.]", "", levels)

  # Handle cases where stripping leaves empty string
  cleaned[cleaned == ""] <- NA

  as.numeric(cleaned)
}


# ==============================================================================
# AGGREGATE WTP
# ==============================================================================

#' Calculate Aggregate WTP Table
#'
#' @param utilities Utilities data frame
#' @param price_attr Price attribute name
#' @param price_coef Price coefficient
#' @param config Configuration
#' @param verbose Logical
#' @return Data frame with WTP per attribute level
#' @keywords internal
calculate_aggregate_wtp <- function(utilities, price_attr, price_coef, config, verbose) {

  # WTP for each non-price attribute level relative to baseline
  non_price <- utilities[utilities$Attribute != price_attr, ]

  wtp_rows <- list()
  for (i in seq_len(nrow(non_price))) {
    row <- non_price[i, ]
    wtp_value <- -(row$Utility / price_coef)

    # CI propagation (delta method approximation)
    se_wtp <- if (!is.null(row$SE) && row$SE > 0) {
      abs(row$SE / price_coef)
    } else {
      NA_real_
    }

    z <- qnorm(1 - (1 - (config$confidence_level %||% 0.95)) / 2)

    wtp_rows[[i]] <- data.frame(
      Attribute = row$Attribute,
      Level = row$Level,
      Utility = row$Utility,
      WTP = wtp_value,
      WTP_SE = se_wtp,
      WTP_Lower = if (!is.na(se_wtp)) wtp_value - z * se_wtp else NA_real_,
      WTP_Upper = if (!is.na(se_wtp)) wtp_value + z * se_wtp else NA_real_,
      is_baseline = row$is_baseline %||% FALSE,
      stringsAsFactors = FALSE
    )
  }

  wtp_table <- do.call(rbind, wtp_rows)
  rownames(wtp_table) <- NULL

  wtp_table
}


# ==============================================================================
# INDIVIDUAL-LEVEL WTP (HB)
# ==============================================================================

#' Calculate Individual-Level WTP from HB Betas
#'
#' Computes WTP for each respondent using their individual betas.
#'
#' @param model_result HB/LC model result
#' @param config Configuration
#' @param price_attr Price attribute name
#' @param verbose Logical
#' @return List with wtp_matrix and respondent_price_coefs
#' @keywords internal
calculate_individual_wtp <- function(model_result, config, price_attr, verbose = TRUE) {

  individual_betas <- model_result$individual_betas
  col_names <- model_result$col_names
  attribute_map <- model_result$attribute_map
  respondent_ids <- model_result$respondent_ids
  n_respondents <- nrow(individual_betas)

  # Identify price columns
  price_cols <- which(sapply(col_names, function(cn) {
    !is.null(attribute_map[[cn]]) && attribute_map[[cn]]$attribute == price_attr
  }))

  if (length(price_cols) == 0) {
    log_verbose("  ⚠ No price columns found in HB betas; individual WTP unavailable", verbose)
    return(NULL)
  }

  # Get numeric price values for the non-baseline levels
  price_levels <- sapply(col_names[price_cols], function(cn) {
    attribute_map[[cn]]$level
  })
  price_values <- extract_numeric_prices(price_levels)

  # Estimate individual price coefficients via regression
  resp_price_coefs <- numeric(n_respondents)
  for (i in seq_len(n_respondents)) {
    price_betas <- individual_betas[i, price_cols]
    # Add baseline (0 utility, lowest price)
    all_betas <- c(0, price_betas)

    # Need at least the baseline price value too
    levels_vec <- get_attribute_levels(config, price_attr)
    baseline_price <- extract_numeric_prices(levels_vec[1])
    all_prices <- c(baseline_price, price_values)

    valid <- !is.na(all_prices)
    if (sum(valid) >= 2) {
      fit <- lm(all_betas[valid] ~ all_prices[valid])
      resp_price_coefs[i] <- coef(fit)[2]
    } else {
      resp_price_coefs[i] <- NA
    }
  }

  # Calculate WTP per respondent per non-price attribute level
  non_price_cols <- which(sapply(col_names, function(cn) {
    !is.null(attribute_map[[cn]]) && attribute_map[[cn]]$attribute != price_attr
  }))

  wtp_matrix <- matrix(NA, nrow = n_respondents, ncol = length(non_price_cols))
  colnames(wtp_matrix) <- col_names[non_price_cols]
  rownames(wtp_matrix) <- respondent_ids

  for (i in seq_len(n_respondents)) {
    if (!is.na(resp_price_coefs[i]) && abs(resp_price_coefs[i]) > 1e-10) {
      wtp_matrix[i, ] <- -(individual_betas[i, non_price_cols] / resp_price_coefs[i])
    }
  }

  list(
    wtp_matrix = wtp_matrix,
    respondent_price_coefs = resp_price_coefs,
    respondent_ids = respondent_ids,
    col_names = col_names[non_price_cols]
  )
}


#' Summarize WTP Distribution Across Respondents
#'
#' @param individual_wtp Output from calculate_individual_wtp
#' @return Data frame with mean, median, SD, percentiles per attribute level
#' @keywords internal
summarize_wtp_distribution <- function(individual_wtp) {

  if (is.null(individual_wtp)) return(NULL)

  wtp_matrix <- individual_wtp$wtp_matrix
  col_names <- individual_wtp$col_names

  summary_rows <- list()
  for (j in seq_along(col_names)) {
    vals <- wtp_matrix[, j]
    valid <- vals[!is.na(vals)]

    if (length(valid) > 0) {
      summary_rows[[j]] <- data.frame(
        Level = col_names[j],
        Mean_WTP = mean(valid),
        Median_WTP = median(valid),
        SD_WTP = sd(valid),
        P05 = quantile(valid, 0.05),
        P25 = quantile(valid, 0.25),
        P75 = quantile(valid, 0.75),
        P95 = quantile(valid, 0.95),
        n_valid = length(valid),
        stringsAsFactors = FALSE,
        row.names = NULL
      )
    }
  }

  if (length(summary_rows) > 0) {
    result <- do.call(rbind, summary_rows)
    rownames(result) <- NULL
    result
  } else {
    NULL
  }
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>Conjoint WTP module loaded (v%s)", CONJOINT_WTP_VERSION))
