# ==============================================================================
# KEY DRIVER ANALYSIS - CORE ALGORITHMS
# ==============================================================================

#' Calculate Correlations
#'
#' @keywords internal
calculate_correlations <- function(data, config) {
  all_vars <- c(config$outcome_var, config$driver_vars)
  cor(data[, all_vars], use = "complete.obs")
}


#' Fit Key Driver Regression Model
#'
#' @keywords internal
fit_keydriver_model <- function(data, config) {

  # Build formula
  formula_str <- paste(config$outcome_var, "~",
                       paste(config$driver_vars, collapse = " + "))
  model_formula <- as.formula(formula_str)

  # Fit OLS model
  model <- lm(model_formula, data = data)

  model
}


#' Calculate Multiple Importance Scores
#'
#' Implements multiple methods for relative importance.
#'
#' @keywords internal
calculate_importance_scores <- function(model, data, correlations, config) {

  driver_vars <- config$driver_vars
  n_drivers <- length(driver_vars)

  # Initialize results data frame
  importance <- data.frame(
    Driver = driver_vars,
    Label = sapply(driver_vars, function(v) {
      config$variables$Label[config$variables$VariableName == v][1]
    }),
    stringsAsFactors = FALSE
  )

  # METHOD 1: Standardized Coefficients (Beta Weights)
  importance$Beta_Weight <- calculate_beta_weights(model, data, config)

  # METHOD 2: Relative Weights (Johnson's method)
  importance$Relative_Weight <- calculate_relative_weights(model, correlations, config)

  # METHOD 3: Shapley Value Decomposition
  importance$Shapley_Value <- calculate_shapley_values(model, data, config)

  # METHOD 4: Zero-order correlations
  outcome_cors <- correlations[config$outcome_var, driver_vars]
  importance$Correlation <- abs(outcome_cors)

  # Calculate ranks for each method
  importance$Beta_Rank <- rank(-abs(importance$Beta_Weight))
  importance$RelWeight_Rank <- rank(-importance$Relative_Weight)
  importance$Shapley_Rank <- rank(-importance$Shapley_Value)
  importance$Corr_Rank <- rank(-importance$Correlation)

  # Average rank
  importance$Average_Rank <- rowMeans(importance[, c("Beta_Rank", "RelWeight_Rank",
                                                      "Shapley_Rank", "Corr_Rank")])

  # Sort by Shapley value (generally most robust)
  importance <- importance[order(-importance$Shapley_Value), ]

  importance
}


#' Calculate Standardized Coefficients
#'
#' @keywords internal
calculate_beta_weights <- function(model, data, config) {

  # Get standardized coefficients
  coefs <- coef(model)[-1]  # Remove intercept

  # Standardize
  sd_x <- sapply(config$driver_vars, function(v) sd(data[[v]], na.rm = TRUE))
  sd_y <- sd(data[[config$outcome_var]], na.rm = TRUE)

  beta_weights <- coefs * (sd_x / sd_y)

  # Return as percentage of sum of absolute betas
  sum_abs <- sum(abs(beta_weights))
  if (sum_abs == 0) {
    pct <- rep(0, length(beta_weights))
  } else {
    pct <- (abs(beta_weights) / sum_abs) * 100
  }

  unname(pct)
}


#' Calculate Relative Weights (Johnson's Method)
#'
#' Decomposes R² into non-negative contributions from each predictor.
#'
#' @keywords internal
calculate_relative_weights <- function(model, correlations, config) {

  # Extract correlation matrices
  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars

  R_xx <- correlations[driver_vars, driver_vars]
  R_xy <- correlations[driver_vars, outcome_var]

  # Eigen decomposition of predictor correlation matrix
  eigen_decomp <- eigen(R_xx)
  Lambda <- diag(sqrt(pmax(eigen_decomp$values, 0)))
  P <- eigen_decomp$vectors

  # Transform to orthogonal space
  Delta <- P %*% Lambda %*% t(P)

  # Relative weights
  rw <- rowSums((Delta %*% R_xy)^2)

  # Normalize to percentages
  sum_rw <- sum(rw)
  if (sum_rw == 0) {
    rw_pct <- rep(0, length(rw))
  } else {
    rw_pct <- (rw / sum_rw) * 100
  }

  unname(rw_pct)
}


#' Calculate Shapley Value Decomposition
#'
#' Allocates R² contribution fairly using game theory approach.
#'
#' @keywords internal
calculate_shapley_values <- function(model, data, config) {

  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars
  n <- length(driver_vars)

  # Store all subset R²
  r2_values <- list()

  # Calculate R² for all possible subsets
  for (subset_size in 0:n) {
    if (subset_size == 0) {
      r2_values[["empty"]] <- 0
      next
    }

    # Get all combinations of this size
    combos <- combn(driver_vars, subset_size, simplify = FALSE)

    for (combo in combos) {
      combo_key <- paste(sort(combo), collapse = "|")

      # Fit model with this subset
      formula_str <- paste(outcome_var, "~", paste(combo, collapse = " + "))
      subset_model <- lm(as.formula(formula_str), data = data)

      r2_values[[combo_key]] <- summary(subset_model)$r.squared
    }
  }

  # Calculate Shapley values
  shapley <- numeric(n)
  names(shapley) <- driver_vars

  for (i in seq_along(driver_vars)) {
    var <- driver_vars[i]
    marginal_sum <- 0

    # Iterate over all subsets NOT containing var
    other_vars <- setdiff(driver_vars, var)

    for (subset_size in 0:(n-1)) {
      if (subset_size == 0) {
        subsets <- list(character(0))
      } else {
        subsets <- combn(other_vars, subset_size, simplify = FALSE)
      }

      for (subset in subsets) {
        # Weight for this subset size
        weight <- factorial(subset_size) * factorial(n - subset_size - 1) / factorial(n)

        # R² with var
        with_var_key <- if (length(subset) == 0) {
          var
        } else {
          paste(sort(c(subset, var)), collapse = "|")
        }

        # R² without var
        without_var_key <- if (length(subset) == 0) {
          "empty"
        } else {
          paste(sort(subset), collapse = "|")
        }

        marginal_contribution <- r2_values[[with_var_key]] - r2_values[[without_var_key]]
        marginal_sum <- marginal_sum + weight * marginal_contribution
      }
    }

    shapley[i] <- marginal_sum
  }

  # Convert to percentages
  sum_shapley <- sum(shapley)
  if (sum_shapley == 0) {
    shapley_pct <- rep(0, length(shapley))
  } else {
    shapley_pct <- (shapley / sum_shapley) * 100
  }

  unname(shapley_pct)
}
