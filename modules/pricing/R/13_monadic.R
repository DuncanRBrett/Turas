# ==============================================================================
# TURAS PRICING MODULE - MONADIC PRICE TESTING
# ==============================================================================
#
# Purpose: Implement monadic (randomized cell) price testing using logistic
#          regression. Each respondent sees ONE randomly assigned price and
#          reports purchase intent. This is the gold standard for unbiased
#          price sensitivity measurement.
#
# Statistical Method:
#   - Logistic regression: glm(intent ~ price, family = binomial)
#   - Optional log-logistic: glm(intent ~ log(price), family = binomial)
#   - Demand curve: predicted purchase probability across price range
#   - Revenue curve: price * predicted_probability
#   - Profit curve: (price - cost) * predicted_probability
#   - Bootstrap CIs for optimal price and demand curve
#
# References:
#   - Gabor & Granger (1966) — foundational price-intent methodology
#   - Lipovetsky (2006) — logistic regression for WTP estimation
#   - Standard econometric demand estimation via GLM
#
# Version: 1.0.0
# Date: 2026-03-09
#
# ==============================================================================

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Run Monadic Price Testing Analysis
#'
#' Fits a logistic regression model to randomized cell monadic pricing data
#' where each respondent was shown a single price and asked purchase intent.
#' Produces a demand curve, revenue/profit optimization, and confidence intervals.
#'
#' @param data Data frame containing respondent-level data
#' @param config Configuration list with monadic settings in config$monadic
#'
#' @return List with:
#'   \item{demand_curve}{Data frame with price, predicted_intent, revenue_index, profit_index}
#'   \item{observed_data}{Data frame with price, n, observed_intent}
#'   \item{optimal_price}{List with price, predicted_intent, revenue_index}
#'   \item{optimal_price_profit}{List with price, predicted_intent, profit_index (if unit_cost set)}
#'   \item{elasticity}{Data frame with price, arc_elasticity, classification}
#'   \item{model_summary}{List with coefficients, AIC, deviance, pseudo_r2}
#'   \item{confidence_intervals}{List with optimal_price_ci, demand_curve_ci}
#'   \item{diagnostics}{List with n_total, n_valid, n_cells, cell_sizes, model_fit}
#'
#' @export
run_monadic_analysis <- function(data, config) {

  mon <- config$monadic

  # --------------------------------------------------------------------------
  # Step 1: Extract and prepare data
  # --------------------------------------------------------------------------
  price_col <- mon$price_column
  intent_col <- mon$intent_column
  intent_type <- mon$intent_type %||% "binary"
  scale_threshold <- mon$scale_threshold %||% 4

  # Extract columns
  prices <- data[[price_col]]
  intents_raw <- data[[intent_col]]

  # Convert intent to binary (0/1)
  if (intent_type == "scale") {
    # Top-box coding: >= threshold counts as "would buy"
    intents <- as.numeric(as.numeric(intents_raw) >= scale_threshold)
  } else {
    # Binary: coerce to 0/1
    intents <- as.numeric(as.numeric(intents_raw) > 0)
  }

  # Remove NAs
  valid <- !is.na(prices) & !is.na(intents) & prices > 0
  prices <- prices[valid]
  intents <- intents[valid]

  n_total <- nrow(data)
  n_valid <- length(prices)

  cat(sprintf("   Valid observations: %d / %d\n", n_valid, n_total))

  # --------------------------------------------------------------------------
  # Step 2: Compute observed intent by price cell
  # --------------------------------------------------------------------------
  price_factor <- factor(prices)
  cell_sizes <- table(price_factor)
  cell_intents <- tapply(intents, price_factor, mean)
  observed_prices <- as.numeric(names(cell_sizes))

  observed_data <- data.frame(
    price = observed_prices,
    n = as.numeric(cell_sizes),
    observed_intent = as.numeric(cell_intents),
    stringsAsFactors = FALSE
  )
  observed_data <- observed_data[order(observed_data$price), ]
  rownames(observed_data) <- NULL

  cat(sprintf("   Price cells: %d (range: %.2f to %.2f)\n",
              length(observed_prices), min(observed_prices), max(observed_prices)))

  # --------------------------------------------------------------------------
  # Step 3: Fit logistic regression model
  # --------------------------------------------------------------------------
  model_type <- mon$model_type %||% "logistic"

  if (model_type == "log_logistic") {
    model <- glm(intents ~ log(prices), family = binomial(link = "logit"))
  } else {
    model <- glm(intents ~ prices, family = binomial(link = "logit"))
  }

  # Model diagnostics
  coefs <- summary(model)$coefficients
  null_dev <- model$null.deviance
  resid_dev <- model$deviance
  pseudo_r2 <- 1 - (resid_dev / null_dev)  # McFadden's pseudo R-squared

  model_summary <- list(
    coefficients = coefs,
    aic = AIC(model),
    null_deviance = null_dev,
    residual_deviance = resid_dev,
    pseudo_r2 = pseudo_r2,
    model_type = model_type,
    n_observations = n_valid,
    price_coefficient_p = coefs[2, 4]  # p-value for price effect
  )

  # Check significance
  if (model_summary$price_coefficient_p > 0.05) {
    cat("   ! WARNING: Price effect not statistically significant (p > 0.05)\n")
    cat(sprintf("     Price coefficient p-value: %.4f\n", model_summary$price_coefficient_p))
  }

  cat(sprintf("   Model: %s, pseudo-R2: %.3f, AIC: %.1f\n",
              model_type, pseudo_r2, AIC(model)))

  # --------------------------------------------------------------------------
  # Step 4: Generate predicted demand curve
  # --------------------------------------------------------------------------
  n_points <- mon$prediction_points %||% 100
  price_range <- seq(min(observed_prices), max(observed_prices), length.out = n_points)

  if (model_type == "log_logistic") {
    predicted <- predict(model, newdata = data.frame(prices = price_range), type = "response")
  } else {
    predicted <- predict(model, newdata = data.frame(prices = price_range), type = "response")
  }

  # Revenue and profit indices
  revenue_index <- price_range * predicted
  unit_cost <- as.numeric(config$unit_cost %||% NA)
  profit_index <- if (!is.na(unit_cost)) (price_range - unit_cost) * predicted else rep(NA, length(price_range))

  demand_curve <- data.frame(
    price = price_range,
    predicted_intent = predicted,
    revenue_index = revenue_index,
    profit_index = profit_index,
    stringsAsFactors = FALSE
  )

  # --------------------------------------------------------------------------
  # Step 5: Find optimal prices
  # --------------------------------------------------------------------------
  # Revenue-maximizing price
  rev_max_idx <- which.max(demand_curve$revenue_index)
  optimal_price <- list(
    price = demand_curve$price[rev_max_idx],
    predicted_intent = demand_curve$predicted_intent[rev_max_idx],
    revenue_index = demand_curve$revenue_index[rev_max_idx]
  )

  # Profit-maximizing price (if unit_cost available)
  optimal_price_profit <- NULL
  if (!is.na(unit_cost)) {
    profit_max_idx <- which.max(demand_curve$profit_index)
    optimal_price_profit <- list(
      price = demand_curve$price[profit_max_idx],
      predicted_intent = demand_curve$predicted_intent[profit_max_idx],
      profit_index = demand_curve$profit_index[profit_max_idx]
    )
    cat(sprintf("   Profit-maximizing price: %s%.2f\n",
                config$currency_symbol %||% "$", optimal_price_profit$price))
  }

  # --------------------------------------------------------------------------
  # Step 6: Calculate price elasticity
  # --------------------------------------------------------------------------
  elasticity <- compute_monadic_elasticity(demand_curve)

  # --------------------------------------------------------------------------
  # Step 7: Bootstrap confidence intervals
  # --------------------------------------------------------------------------
  confidence_intervals <- NULL
  if (isTRUE(mon$confidence_intervals)) {
    cat("   Calculating bootstrap confidence intervals...\n")
    n_boot <- mon$bootstrap_iterations %||% 1000
    conf_level <- mon$confidence_level %||% 0.95

    confidence_intervals <- monadic_bootstrap_ci(
      prices = prices,
      intents = intents,
      model_type = model_type,
      price_range = price_range,
      n_boot = n_boot,
      conf_level = conf_level,
      unit_cost = unit_cost
    )

    if (!is.null(confidence_intervals$optimal_price_ci)) {
      cat(sprintf("   Revenue-optimal price: %s%.2f [%.2f, %.2f] (%d%% CI)\n",
                  config$currency_symbol %||% "$",
                  optimal_price$price,
                  confidence_intervals$optimal_price_ci[1],
                  confidence_intervals$optimal_price_ci[2],
                  round(conf_level * 100)))
    }
  }

  # --------------------------------------------------------------------------
  # Step 8: Compile diagnostics
  # --------------------------------------------------------------------------
  diagnostics <- list(
    n_total = n_total,
    n_valid = n_valid,
    n_excluded = n_total - n_valid,
    n_cells = length(observed_prices),
    cell_sizes = observed_data,
    min_cell_n = min(observed_data$n),
    max_cell_n = max(observed_data$n),
    price_range = c(min(observed_prices), max(observed_prices)),
    model_fit = model_summary
  )

  # --------------------------------------------------------------------------
  # Return results
  # --------------------------------------------------------------------------
  list(
    demand_curve = demand_curve,
    observed_data = observed_data,
    optimal_price = optimal_price,
    optimal_price_profit = optimal_price_profit,
    elasticity = elasticity,
    model_summary = model_summary,
    confidence_intervals = confidence_intervals,
    diagnostics = diagnostics,
    method = "monadic"
  )
}


# ==============================================================================
# PRICE ELASTICITY
# ==============================================================================

#' Compute Arc Price Elasticity from Monadic Demand Curve
#'
#' @param demand_curve Data frame with price and predicted_intent columns
#' @return Data frame with midpoint price, arc elasticity, and classification
#' @keywords internal
compute_monadic_elasticity <- function(demand_curve) {
  n <- nrow(demand_curve)
  if (n < 2) return(data.frame(price = numeric(0), elasticity = numeric(0), classification = character(0)))

  # Sample at regular intervals for cleaner output (every ~5% of range)
  step <- max(1, floor(n / 20))
  indices <- seq(1, n, by = step)
  if (indices[length(indices)] != n) indices <- c(indices, n)

  results <- list()
  for (i in 2:length(indices)) {
    idx1 <- indices[i - 1]
    idx2 <- indices[i]

    p1 <- demand_curve$price[idx1]
    p2 <- demand_curve$price[idx2]
    q1 <- demand_curve$predicted_intent[idx1]
    q2 <- demand_curve$predicted_intent[idx2]

    if (p1 == p2 || q1 + q2 == 0) next

    # Arc elasticity
    pct_change_q <- (q2 - q1) / ((q1 + q2) / 2)
    pct_change_p <- (p2 - p1) / ((p1 + p2) / 2)
    arc_e <- pct_change_q / pct_change_p

    classification <- if (abs(arc_e) > 1) "elastic"
                      else if (abs(arc_e) == 1) "unitary"
                      else "inelastic"

    results[[length(results) + 1]] <- data.frame(
      price_midpoint = (p1 + p2) / 2,
      price_low = p1,
      price_high = p2,
      elasticity = arc_e,
      classification = classification,
      stringsAsFactors = FALSE
    )
  }

  if (length(results) == 0) {
    return(data.frame(price_midpoint = numeric(0), elasticity = numeric(0),
                      classification = character(0)))
  }

  do.call(rbind, results)
}


# ==============================================================================
# BOOTSTRAP CONFIDENCE INTERVALS
# ==============================================================================

#' Bootstrap Confidence Intervals for Monadic Analysis
#'
#' @param prices Numeric vector of prices
#' @param intents Numeric vector of binary intents (0/1)
#' @param model_type "logistic" or "log_logistic"
#' @param price_range Numeric vector of prices for demand curve prediction
#' @param n_boot Number of bootstrap iterations
#' @param conf_level Confidence level (0-1)
#' @param unit_cost Unit cost for profit optimization (NA to skip)
#'
#' @return List with optimal_price_ci, optimal_profit_price_ci, demand_curve_ci
#' @keywords internal
monadic_bootstrap_ci <- function(prices, intents, model_type, price_range,
                                  n_boot = 1000, conf_level = 0.95,
                                  unit_cost = NA) {

  n <- length(prices)
  alpha <- 1 - conf_level

  boot_optimal_rev <- numeric(n_boot)
  boot_optimal_profit <- numeric(n_boot)
  boot_demand <- matrix(NA, nrow = n_boot, ncol = length(price_range))

  successful <- 0
  for (b in seq_len(n_boot)) {
    idx <- sample(n, n, replace = TRUE)
    b_prices <- prices[idx]
    b_intents <- intents[idx]

    # Skip degenerate samples (all same intent)
    if (length(unique(b_intents)) < 2) next

    tryCatch({
      if (model_type == "log_logistic") {
        b_model <- glm(b_intents ~ log(b_prices), family = binomial(link = "logit"))
      } else {
        b_model <- glm(b_intents ~ b_prices, family = binomial(link = "logit"))
      }

      b_pred <- predict(b_model, newdata = data.frame(prices = price_range), type = "response")

      # Revenue optimal
      b_revenue <- price_range * b_pred
      boot_optimal_rev[b] <- price_range[which.max(b_revenue)]

      # Profit optimal
      if (!is.na(unit_cost)) {
        b_profit <- (price_range - unit_cost) * b_pred
        boot_optimal_profit[b] <- price_range[which.max(b_profit)]
      }

      boot_demand[b, ] <- b_pred
      successful <- successful + 1

    }, error = function(e) {
      # Bootstrap iteration failed — skip silently
    })
  }

  if (successful < n_boot * 0.5) {
    cat(sprintf("   ! Bootstrap warning: only %d/%d iterations succeeded\n", successful, n_boot))
  }

  # Compute CIs from successful iterations
  valid_rev <- boot_optimal_rev[!is.na(boot_optimal_rev) & boot_optimal_rev > 0]
  optimal_price_ci <- if (length(valid_rev) >= 10) {
    quantile(valid_rev, probs = c(alpha / 2, 1 - alpha / 2), na.rm = TRUE)
  } else NULL

  optimal_profit_price_ci <- NULL
  if (!is.na(unit_cost)) {
    valid_profit <- boot_optimal_profit[!is.na(boot_optimal_profit) & boot_optimal_profit > 0]
    if (length(valid_profit) >= 10) {
      optimal_profit_price_ci <- quantile(valid_profit, probs = c(alpha / 2, 1 - alpha / 2), na.rm = TRUE)
    }
  }

  # Demand curve CI (lower/upper at each price point)
  demand_curve_ci <- NULL
  valid_rows <- apply(boot_demand, 1, function(r) !any(is.na(r)))
  if (sum(valid_rows) >= 10) {
    valid_demand <- boot_demand[valid_rows, , drop = FALSE]
    demand_lower <- apply(valid_demand, 2, quantile, probs = alpha / 2)
    demand_upper <- apply(valid_demand, 2, quantile, probs = 1 - alpha / 2)
    demand_curve_ci <- data.frame(
      price = price_range,
      ci_lower = demand_lower,
      ci_upper = demand_upper,
      stringsAsFactors = FALSE
    )
  }

  list(
    optimal_price_ci = optimal_price_ci,
    optimal_profit_price_ci = optimal_profit_price_ci,
    demand_curve_ci = demand_curve_ci,
    n_successful = successful,
    n_attempted = n_boot
  )
}
