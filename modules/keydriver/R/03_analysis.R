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
    keydriver_refuse(
      code = "MODEL_ALIASED_COEFFICIENTS",
      title = "Aliased Coefficients (Multicollinearity)",
      problem = paste0("The following drivers have aliased/NA coefficients: ", paste(missing_coefs, collapse = ", ")),
      why_it_matters = "This is typically caused by multicollinearity (highly correlated predictors). The model cannot estimate unique effects for these variables.",
      how_to_fix = c(
        "Remove one of the correlated drivers",
        "Or combine correlated drivers into a single composite variable",
        "Then rerun the analysis"
      )
    )
  }

  # Standard deviations
  sd_x <- vapply(driver_vars, function(v) stats::sd(data[[v]], na.rm = TRUE), numeric(1))
  sd_y <- stats::sd(data[[outcome_var]], na.rm = TRUE)

  # Additional safety checks (should have been caught in validation, but double-check)
  if (any(sd_x == 0)) {
    keydriver_refuse(
      code = "DATA_DRIVERS_ZERO_VARIANCE",
      title = "Zero Variance Drivers",
      problem = paste0("One or more drivers have zero variance: ", paste(driver_vars[sd_x == 0], collapse = ", ")),
      why_it_matters = "Cannot compute standardized betas for variables with no variation.",
      how_to_fix = c(
        "Remove these zero-variance drivers from your analysis",
        "Or check your data for issues (all identical values)"
      )
    )
  }

  if (sd_y == 0) {
    keydriver_refuse(
      code = "DATA_OUTCOME_ZERO_VARIANCE",
      title = "Zero Variance Outcome",
      problem = "The outcome variable has zero variance (all values are identical).",
      why_it_matters = "Key driver analysis is not defined when there is nothing to explain.",
      how_to_fix = "Check your outcome variable - it should have variation in values."
    )
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
    keydriver_refuse(
      code = "MODEL_SINGULAR_MATRIX",
      title = "Singular Correlation Matrix",
      problem = "Predictor correlation matrix is singular or nearly singular (severe multicollinearity).",
      why_it_matters = "Relative weights cannot be computed reliably when drivers are too highly correlated.",
      how_to_fix = c(
        "Identify highly correlated driver pairs using a correlation matrix",
        "Remove or combine drivers that are too similar",
        "Aim for correlations below 0.9 between predictors"
      )
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
    keydriver_refuse(
      code = "FEATURE_SHAPLEY_TOO_MANY_DRIVERS",
      title = "Too Many Drivers for Exact Shapley",
      problem = paste0("You have ", n, " drivers, but exact Shapley decomposition is computationally infeasible with more than 15."),
      why_it_matters = "Exact Shapley requires evaluating 2^n subsets. With 15+ drivers this becomes prohibitively slow.",
      how_to_fix = c(
        "Reduce the number of drivers to 15 or fewer",
        "Or use an alternative importance method (beta weights or relative weights)",
        "In future versions, approximate Shapley methods may be available"
      )
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


# ==============================================================================
# MIXED PREDICTOR SUPPORT - DRIVER-LEVEL AGGREGATION
# ==============================================================================

#' Calculate Importance Scores for Mixed Predictors
#'
#' Main entry point for importance calculation with mixed predictors.
#' Uses term-level calculation then aggregates to driver level.
#'
#' @param model Fitted model
#' @param data Data frame
#' @param config Configuration list
#' @param term_mapping Result from build_term_mapping()
#' @return Data frame with driver-level importance
#' @export
calculate_importance_mixed <- function(model, data, config, term_mapping) {

  driver_vars <- config$driver_vars

  # Initialize results
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
    Type = term_mapping$predictor_info$type,
    N_Terms = term_mapping$predictor_info$n_terms,
    stringsAsFactors = FALSE
  )

  # METHOD 1: Aggregated Beta Weights
  beta_res <- calculate_beta_weights_mixed(model, data, config, term_mapping)
  importance$Beta_Weight <- beta_res$driver_importance
  importance$Beta_Direction <- beta_res$driver_direction

  # METHOD 2: Aggregated Relative Weights
  importance$Relative_Weight <- calculate_relative_weights_mixed(model, data, config, term_mapping)

  # METHOD 3: Shapley Values (still at driver level - uses driver in formula)
  # Skip if any categorical predictors (Shapley handles whole driver naturally)
  importance$Shapley_Value <- calculate_shapley_values(model, data, config)

  # METHOD 4: Correlations - only for numeric drivers
  numeric_drivers <- get_numeric_drivers(data, driver_vars)
  correlations <- calculate_correlations(data, config)

  importance$Correlation <- vapply(driver_vars, function(drv) {
    if (drv %in% numeric_drivers) {
      as.numeric(correlations[config$outcome_var, drv])
    } else {
      NA_real_  # Correlation not meaningful for categorical
    }
  }, numeric(1))

  # Calculate ranks
  importance$Beta_Rank <- rank(-abs(importance$Beta_Weight), ties.method = "average")
  importance$RelWeight_Rank <- rank(-importance$Relative_Weight, ties.method = "average")
  importance$Shapley_Rank <- rank(-importance$Shapley_Value, ties.method = "average")

  # For correlation rank, only rank numeric drivers
  corr_vals <- importance$Correlation
  corr_vals[is.na(corr_vals)] <- 0  # NAs get lowest rank
  importance$Corr_Rank <- rank(-abs(corr_vals), ties.method = "average")

  # Average rank (exclude correlation for categorical drivers)
  importance$Average_Rank <- rowMeans(importance[, c(
    "Beta_Rank", "RelWeight_Rank", "Shapley_Rank"
  )])

  # Sort by Shapley
  importance <- importance[order(-importance$Shapley_Value), ]
  rownames(importance) <- NULL

  importance
}


#' Calculate Beta Weights with Driver-Level Aggregation
#'
#' Computes standardized betas at term level, then aggregates to driver level.
#'
#' Aggregation method (per Mixed Predictor Spec):
#'   driver_importance = sum(|beta_term|) over all terms belonging to driver
#'
#' @param model Fitted model
#' @param data Data frame
#' @param config Configuration
#' @param term_mapping Term mapping result
#' @return List with driver_importance and driver_direction
#' @keywords internal
calculate_beta_weights_mixed <- function(model, data, config, term_mapping) {

  driver_vars <- config$driver_vars
  outcome_var <- config$outcome_var
  driver_terms <- term_mapping$driver_terms

  # Get all coefficients (excluding intercept)
  all_coefs <- stats::coef(model)
  all_coefs <- all_coefs[names(all_coefs) != "(Intercept)"]

  # Check for NA coefficients (aliased)
  na_terms <- names(all_coefs)[is.na(all_coefs)]
  if (length(na_terms) > 0) {
    # Find which drivers these belong to
    affected_drivers <- unique(term_mapping$term_map[na_terms])
    affected_drivers <- affected_drivers[!is.na(affected_drivers) & nzchar(affected_drivers)]

    if (length(affected_drivers) > 0) {
      keydriver_refuse(
        code = "MODEL_ALIASED_COEFFICIENTS",
        title = "Aliased Coefficients (Multicollinearity)",
        problem = paste0("Coefficients for some terms are NA due to perfect collinearity."),
        why_it_matters = "Cannot compute importance for aliased terms. This typically means predictors are linearly dependent.",
        how_to_fix = c(
          "Check for redundant factor levels across drivers",
          "Remove one of the collinear predictors",
          "Check if any categorical driver has a level that is a subset of another"
        ),
        details = paste0("Affected terms: ", paste(na_terms, collapse = ", "))
      )
    }
  }

  # Build model.matrix for standardization
  mm <- stats::model.matrix(model)
  mm <- mm[, colnames(mm) != "(Intercept)", drop = FALSE]

  # Calculate term-level standardized betas
  sd_y <- sd(data[[outcome_var]], na.rm = TRUE)
  term_betas <- numeric(length(all_coefs))
  names(term_betas) <- names(all_coefs)

  for (term in names(all_coefs)) {
    if (!is.na(all_coefs[term]) && term %in% colnames(mm)) {
      sd_x <- sd(mm[, term], na.rm = TRUE)
      if (sd_x > 0 && sd_y > 0) {
        term_betas[term] <- all_coefs[term] * (sd_x / sd_y)
      }
    }
  }

  # Aggregate to driver level
  driver_importance <- numeric(length(driver_vars))
  names(driver_importance) <- driver_vars
  driver_direction <- character(length(driver_vars))
  names(driver_direction) <- driver_vars

  for (drv in driver_vars) {
    terms <- driver_terms[[drv]]
    if (length(terms) == 0) {
      driver_importance[drv] <- 0
      driver_direction[drv] <- "N/A"
      next
    }

    # Get betas for this driver's terms
    drv_betas <- term_betas[terms]
    drv_betas <- drv_betas[!is.na(drv_betas)]

    if (length(drv_betas) == 0) {
      driver_importance[drv] <- 0
      driver_direction[drv] <- "N/A"
      next
    }

    # Aggregation: sum of absolute values
    driver_importance[drv] <- sum(abs(drv_betas))

    # Direction: sign of largest |beta|, or "mixed" if signs differ
    max_idx <- which.max(abs(drv_betas))
    if (all(drv_betas >= 0) || all(drv_betas <= 0)) {
      driver_direction[drv] <- if (drv_betas[max_idx] >= 0) "positive" else "negative"
    } else {
      driver_direction[drv] <- "mixed"
    }
  }

  # Normalize to percentages
  sum_importance <- sum(driver_importance)
  if (sum_importance > 0) {
    driver_importance <- (driver_importance / sum_importance) * 100
  }

  list(
    driver_importance = as.numeric(driver_importance),
    driver_direction = as.character(driver_direction)
  )
}


#' Calculate Relative Weights for Mixed Predictors
#'
#' Computes relative weights at term level (using model.matrix),
#' then aggregates to driver level.
#'
#' @param model Fitted model
#' @param data Data frame
#' @param config Configuration
#' @param term_mapping Term mapping result
#' @return Numeric vector of driver-level relative weights (percentages)
#' @keywords internal
calculate_relative_weights_mixed <- function(model, data, config, term_mapping) {

  driver_vars <- config$driver_vars
  outcome_var <- config$outcome_var
  driver_terms <- term_mapping$driver_terms

  # Build model matrix (excluding intercept)
  mm <- stats::model.matrix(model)
  mm <- mm[, colnames(mm) != "(Intercept)", drop = FALSE]

  # Get outcome
  y <- data[[outcome_var]]

  # Remove rows with NA
  complete <- complete.cases(mm, y)
  mm <- mm[complete, , drop = FALSE]
  y <- y[complete]

  # Correlation matrix of model matrix columns (terms)
  R_xx <- cor(mm)
  r_xy <- cor(mm, y)[, 1]

  p <- ncol(mm)
  term_names <- colnames(mm)

  # Eigen decomposition
  eig <- eigen(R_xx, symmetric = TRUE)
  vals <- eig$values
  vecs <- eig$vectors

  # Guard against numerical negatives
  vals[vals < 0] <- 0

  # Check for near-singularity
  if (any(vals < 1e-10)) {
    # Matrix is near-singular - use fallback to beta weights
    cat("   [WARN] Near-singular correlation matrix - using simplified relative weights\n")
    # Fallback: use squared correlations as proxy
    rw_term <- r_xy^2
    rw_term[is.na(rw_term)] <- 0
  } else {
    # Standard Johnson relative weights at term level
    Lambda_sqrt <- diag(sqrt(vals), nrow = p, ncol = p)
    Lambda_inv_sqrt <- diag(1 / sqrt(vals), nrow = p, ncol = p)

    Phi <- vecs %*% Lambda_sqrt
    r_z_y <- Lambda_inv_sqrt %*% t(vecs) %*% r_xy
    r2_z_y <- as.numeric(r_z_y)^2

    Phi_sq <- Phi^2
    rw_term <- as.numeric(Phi_sq %*% r2_z_y)
  }

  names(rw_term) <- term_names

  # Aggregate to driver level
  driver_rw <- numeric(length(driver_vars))
  names(driver_rw) <- driver_vars

  for (drv in driver_vars) {
    terms <- driver_terms[[drv]]
    if (length(terms) == 0) {
      driver_rw[drv] <- 0
      next
    }

    # Sum term-level relative weights for this driver
    matching_terms <- intersect(terms, term_names)
    if (length(matching_terms) > 0) {
      driver_rw[drv] <- sum(rw_term[matching_terms], na.rm = TRUE)
    } else {
      driver_rw[drv] <- 0
    }
  }

  # Normalize to percentages
  sum_rw <- sum(driver_rw)
  if (sum_rw > 0) {
    driver_rw <- (driver_rw / sum_rw) * 100
  }

  as.numeric(driver_rw)
}
