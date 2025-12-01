# ==============================================================================
# KEY DRIVER ANALYSIS - CORE ALGORITHMS
# ==============================================================================

# ------------------------------------------------------------------------------
# Weighted correlation helpers
# ------------------------------------------------------------------------------

#' Weighted Covariance
#' @keywords internal
weighted_cov <- function(x, y, w) {
  w <- w / sum(w)
  mx <- sum(w * x)
  my <- sum(w * y)
  sum(w * (x - mx) * (y - my))
}

#' Weighted Correlation
#' @keywords internal
weighted_cor <- function(x, y, w) {
  w <- w / sum(w)
  mx <- sum(w * x)
  my <- sum(w * y)
  sx <- sqrt(sum(w * (x - mx)^2))
  sy <- sqrt(sum(w * (y - my)^2))
  if (sx == 0 || sy == 0) return(NA_real_)
  weighted_cov(x, y, w) / (sx * sy)
}

#' Calculate Correlations (weighted or unweighted)
#'
#' @keywords internal
calculate_correlations <- function(data, config) {
  vars <- c(config$outcome_var, config$driver_vars)
  weight_var <- config$weight_var

  if (is.null(weight_var)) {
    # Simple Pearson correlation
    cors <- stats::cor(data[, vars, drop = FALSE], use = "pairwise.complete.obs")
    return(cors)
  }

  # Weighted correlation matrix
  w <- data[[weight_var]]
  w <- as.numeric(w)
  m <- length(vars)
  mat <- matrix(NA_real_, nrow = m, ncol = m,
                dimnames = list(vars, vars))

  for (i in seq_len(m)) {
    for (j in i:m) {
      r <- weighted_cor(data[[vars[i]]], data[[vars[j]]], w)
      mat[i, j] <- r
      mat[j, i] <- r
    }
  }

  mat
}


# ------------------------------------------------------------------------------
# Regression Model
# ------------------------------------------------------------------------------

#' Fit Key Driver Regression Model (weighted or unweighted)
#'
#' @keywords internal
fit_keydriver_model <- function(data, config) {
  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars
  weight_var <- config$weight_var

  # Build formula
  formula_str <- paste(outcome_var, "~", paste(driver_vars, collapse = " + "))
  model_formula <- stats::as.formula(formula_str)

  # Fit OLS model (weighted if weight_var specified)
  if (!is.null(weight_var)) {
    w <- data[[weight_var]]
    model <- stats::lm(model_formula, data = data, weights = w)
  } else {
    model <- stats::lm(model_formula, data = data)
  }

  model
}


# ------------------------------------------------------------------------------
# Importance Score Calculation
# ------------------------------------------------------------------------------

#' Calculate Multiple Importance Scores
#'
#' Implements multiple methods for relative importance.
#'
#' @keywords internal
calculate_importance_scores <- function(model, data, correlations, config) {

  driver_vars <- config$driver_vars

  # Initialize results data frame
  importance <- data.frame(
    Driver = driver_vars,
    Label = vapply(
      driver_vars,
      function(v) {
        label <- config$variables$Label[config$variables$VariableName == v][1]
        if (is.na(label) || is.null(label)) v else label
      },
      character(1)
    ),
    stringsAsFactors = FALSE
  )

  # METHOD 1: Standardized Coefficients (Beta Weights)
  beta_res <- calculate_beta_weights(model, data, config)
  importance$Beta_Weight <- as.numeric(beta_res)
  importance$Beta_Coefficient <- as.numeric(attr(beta_res, "beta_coefficients"))

  # METHOD 2: Relative Weights (Johnson's method)
  importance$Relative_Weight <- calculate_relative_weights(model, correlations, config)

  # METHOD 3: Shapley Value Decomposition
  importance$Shapley_Value <- calculate_shapley_values(model, data, config)

  # METHOD 4: Zero-order correlations (signed r)
  outcome_cors <- correlations[config$outcome_var, driver_vars]
  importance$Correlation <- as.numeric(outcome_cors)

  # Calculate ranks for each method (lower rank = more important)
  importance$Beta_Rank <- rank(-abs(importance$Beta_Weight), ties.method = "average")
  importance$RelWeight_Rank <- rank(-importance$Relative_Weight, ties.method = "average")
  importance$Shapley_Rank <- rank(-importance$Shapley_Value, ties.method = "average")
  importance$Corr_Rank <- rank(-abs(importance$Correlation), ties.method = "average")

  # Average rank
  importance$Average_Rank <- rowMeans(importance[, c(
    "Beta_Rank", "RelWeight_Rank", "Shapley_Rank", "Corr_Rank"
  )])

  # Sort by Shapley value (generally most robust)
  importance <- importance[order(-importance$Shapley_Value), ]
  rownames(importance) <- NULL

  importance
}


# ------------------------------------------------------------------------------
# METHOD 1: Beta Weights (FIXED - handles aliased predictors)
# ------------------------------------------------------------------------------

#' Calculate Standardized Beta Weights
#'
#' Returns importance percentages based on |standardized beta|,
#' and attaches signed standardized betas as an attribute.
#'
#' @keywords internal
calculate_beta_weights <- function(model, data, config) {
  driver_vars <- config$driver_vars
  outcome_var <- config$outcome_var

  # Extract coefficients by name (skip intercept)
  coefs <- stats::coef(model)[driver_vars]

  # Check for aliased/missing coefficients (multicollinearity)
  missing_coefs <- names(coefs)[is.na(coefs)]
  if (length(missing_coefs) > 0) {
    stop(
      "The following drivers have aliased/NA coefficients (likely due to multicollinearity): ",
      paste(missing_coefs, collapse = ", "),
      ". Please remove or combine these variables and rerun the analysis.",
      call. = FALSE
    )
  }

  # Standard deviations
  sd_x <- vapply(driver_vars, function(v) stats::sd(data[[v]], na.rm = TRUE), numeric(1))
  sd_y <- stats::sd(data[[outcome_var]], na.rm = TRUE)

  # Additional safety checks (should have been caught in validation, but double-check)
  if (any(sd_x == 0)) {
    stop(
      "One or more drivers have zero variance; cannot compute standardized betas. Offending drivers: ",
      paste(driver_vars[sd_x == 0], collapse = ", "),
      call. = FALSE
    )
  }

  if (sd_y == 0) {
    stop("Outcome variable has zero variance; key driver analysis is not defined.", call. = FALSE)
  }

  # Standardized betas
  beta_std <- coefs * (sd_x / sd_y)

  # Importance based on |beta|
  sum_abs <- sum(abs(beta_std))
  if (sum_abs == 0) {
    pct <- rep(0, length(beta_std))
  } else {
    pct <- (abs(beta_std) / sum_abs) * 100
  }

  names(pct) <- driver_vars
  attr(pct, "beta_coefficients") <- beta_std
  pct
}


# ------------------------------------------------------------------------------
# METHOD 2: Relative Weights (FIXED - correct Johnson 2000 implementation)
# ------------------------------------------------------------------------------

#' Calculate Relative Weights (Johnson's Method)
#'
#' Decomposes model R² into non-negative contributions from each predictor.
#' CORRECTED implementation that matches Johnson (2000) and Tonidandel & LeBreton.
#'
#' @keywords internal
calculate_relative_weights <- function(model, correlations, config) {
  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars

  # Predictor correlation matrix and predictor–outcome correlations
  R_xx <- as.matrix(correlations[driver_vars, driver_vars])
  r_xy <- as.numeric(correlations[driver_vars, outcome_var])

  p <- length(driver_vars)

  # Eigen decomposition of R_xx
  eig <- eigen(R_xx, symmetric = TRUE)
  vals <- eig$values
  vecs <- eig$vectors

  # Guard against numerical negatives
  vals[vals < 0] <- 0

  # Check for severe multicollinearity (non-positive definite R_xx)
  if (any(vals < 1e-6)) {
    stop(
      "Predictor correlation matrix is singular or nearly singular (severe multicollinearity). ",
      "Relative weights cannot be computed reliably. Consider removing or combining highly ",
      "correlated drivers.",
      call. = FALSE
    )
  }

  # sqrt(Λ) and Λ^{-1/2}
  Lambda_sqrt <- diag(sqrt(vals), nrow = p, ncol = p)
  Lambda_inv_sqrt <- diag(1 / sqrt(vals), nrow = p, ncol = p)

  # Correlations between original predictors X and orthogonal components Z
  # Z = X * V * Λ^{-1/2}, so corr(X, Z) = V * Λ^{1/2}
  Phi <- vecs %*% Lambda_sqrt  # p x p

  # Correlations between Z and Y (with standardized Y)
  # corr(Z, Y) = Λ^{-1/2} * V' * r_xy
  r_z_y <- Lambda_inv_sqrt %*% t(vecs) %*% r_xy  # p x 1
  r2_z_y <- as.numeric(r_z_y)^2  # component-level R² contributions

  # Total R² in orthogonal space
  total_R2 <- sum(r2_z_y)
  if (total_R2 <= 0) {
    return(rep(0, p))
  }

  # Predictor-level relative weights in R² units:
  # RW_i = Σ_j (phi_ij^2 * r_zj,y^2)
  Phi_sq <- Phi^2  # element-wise square (p x p)
  rw_raw <- Phi_sq %*% r2_z_y  # p x 1
  rw_raw <- as.numeric(rw_raw)

  # Optional rescale so that sum of raw RWs matches model R² exactly
  model_R2 <- summary(model)$r.squared
  if (!is.na(model_R2) && model_R2 > 0 && sum(rw_raw) > 0) {
    rw_raw <- rw_raw * (model_R2 / sum(rw_raw))
  }

  # Convert to percentages
  sum_rw <- sum(rw_raw)
  if (sum_rw <= 0) {
    rw_pct <- rep(0, p)
  } else {
    rw_pct <- (rw_raw / sum_rw) * 100
  }

  names(rw_pct) <- driver_vars
  rw_pct
}


# ------------------------------------------------------------------------------
# METHOD 3: Shapley Values (IMPROVED - added driver limit)
# ------------------------------------------------------------------------------

#' Calculate Shapley Value Decomposition
#'
#' Allocates R² contribution fairly using game theory approach.
#' IMPROVED: Added guardrail against too many drivers.
#'
#' @keywords internal
calculate_shapley_values <- function(model, data, config) {

  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars
  n <- length(driver_vars)

  # NEW: Guard against too many drivers for exact Shapley
  if (n > 15) {
    stop(
      "Too many drivers (", n, ") for exact Shapley decomposition. ",
      "Please reduce the number of drivers (e.g., to <= 15) or implement ",
      "an approximate Shapley method.",
      call. = FALSE
    )
  }

  # Store all subset R²
  r2_values <- list()

  # Calculate R² for all possible subsets
  for (subset_size in 0:n) {
    if (subset_size == 0) {
      r2_values[["empty"]] <- 0
      next
    }

    # Get all combinations of this size
    combos <- utils::combn(driver_vars, subset_size, simplify = FALSE)

    for (combo in combos) {
      combo_key <- paste(sort(combo), collapse = "|")

      # Fit model with this subset
      formula_str <- paste(outcome_var, "~", paste(combo, collapse = " + "))
      subset_model <- stats::lm(as.formula(formula_str), data = data)

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

    for (subset_size in 0:(n - 1)) {
      if (subset_size == 0) {
        subsets <- list(character(0))
      } else {
        subsets <- utils::combn(other_vars, subset_size, simplify = FALSE)
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

  names(shapley_pct) <- driver_vars
  unname(shapley_pct)
}
