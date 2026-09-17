# ==============================================================================
# KEY DRIVER ANALYSIS - CORE ALGORITHMS
# ==============================================================================
#
# Version: Turas v10.3 (Continuous Key Driver Upgrade)
# Date: 2025-12
#
# NEW IN v10.3:
#   - partial_r2 aggregation for categorical drivers (per spec)
#   - grouped_permutation method support
#   - Driver-type aware importance calculation
#
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
  if (sx < 1e-10 || sy < 1e-10) return(NA_real_)
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

  # Johnson's symmetric square root of R_xx: Lam = V sqrt(L) V'.
  #
  # This used to be V sqrt(L), which is the PCA rotation, not Johnson's
  # orthogonal counterpart set (review C1). The two differ by the V' on the
  # right and the consequence is not subtle: with two drivers the PCA form
  # returns 50/50 whatever the data says, so every two-driver study's headline
  # importance split was a constant. Johnson (2000) requires the symmetric
  # root, which is the orthogonal basis closest to the original predictors in
  # a least-squares sense.
  Lam <- vecs %*% diag(sqrt(vals), nrow = p, ncol = p) %*% t(vecs)

  # Betas of the outcome on the orthogonals, then the weights in R-squared
  # units: RW_i = sum_j Lam_ij^2 * beta*_j^2.
  beta_star <- solve(Lam) %*% r_xy
  rw_raw <- as.numeric((Lam^2) %*% (beta_star^2))

  if (sum(rw_raw) <= 0) {
    return(rep(0, p))
  }

  # No rescale to R-squared. Correct raw weights already sum to it, which is
  # the identity the old rescale was quietly papering over: a wrong
  # decomposition was being stretched to the right total. Assert it instead,
  # with room for the difference between the model's own R-squared and the one
  # implied by the correlation matrix it was handed.
  model_R2 <- summary(model)$r.squared
  if (!is.na(model_R2) && model_R2 > 0) {
    drift <- abs(sum(rw_raw) - model_R2)
    if (drift > 0.01 + 0.02 * model_R2) {
      keydriver_refuse(
        code = "CALC_RW_DOES_NOT_SUM_TO_R2",
        title = "Relative Weights Do Not Reconstruct The Model",
        problem = sprintf(
          "The relative weights sum to %.4f and the model's R-squared is %.4f.",
          sum(rw_raw), model_R2),
        why_it_matters = paste0(
          "Johnson's weights are a decomposition of R-squared, so they must add ",
          "back up to it. A gap this size means the correlation matrix and the ",
          "fitted model were not built from the same respondents."),
        how_to_fix = paste0(
          "Check that the correlation matrix and the regression used the same ",
          "rows: a driver with missing values dropped from one and not the other ",
          "will do this.")
      )
    }
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

  # Resolve weights for consistent subset model fitting
  weight_var <- config$weight_var
  w <- if (!is.null(weight_var) && weight_var %in% names(data)) data[[weight_var]] else NULL

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

      # Fit model with this subset (weighted if applicable, matching main model)
      formula_str <- paste(outcome_var, "~", paste(combo, collapse = " + "))
      if (!is.null(w)) {
        subset_model <- stats::lm(as.formula(formula_str), data = data, weights = w)
      } else {
        subset_model <- stats::lm(as.formula(formula_str), data = data)
      }

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
#' @param correlations Pre-computed correlation matrix (optional). If NULL,
#'   correlations are calculated internally.
#' @return Data frame with driver-level importance
#' @export
calculate_importance_mixed <- function(model, data, config, term_mapping,
                                      correlations = NULL) {

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
  if (is.null(correlations)) {
    correlations <- calculate_correlations(data, config)
  }

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

  # Correlation matrix of model matrix columns (terms). Weighted when the study
  # is weighted: these were plain cor() while the non-mixed path used the
  # weighted machinery, so a weighted mixed run's relative weights were
  # computed on the wrong correlations (review A1).
  w <- NULL
  if (!is.null(config$weight_var) && nzchar(config$weight_var) &&
      config$weight_var %in% names(data)) {
    w <- as.numeric(data[[config$weight_var]])[complete]
  }
  p <- ncol(mm)
  term_names <- colnames(mm)

  if (is.null(w)) {
    R_xx <- cor(mm)
    r_xy <- cor(mm, y)[, 1]
  } else {
    R_xx <- matrix(1, p, p, dimnames = list(term_names, term_names))
    for (i in seq_len(p)) {
      for (j in seq_len(p)) {
        if (i < j) {
          r <- weighted_cor(mm[, i], mm[, j], w)
          R_xx[i, j] <- r
          R_xx[j, i] <- r
        }
      }
    }
    r_xy <- vapply(seq_len(p), function(i) weighted_cor(mm[, i], y, w), numeric(1))
    names(r_xy) <- term_names
  }

  # Eigen decomposition
  eig <- eigen(R_xx, symmetric = TRUE)
  vals <- eig$values
  vecs <- eig$vectors

  # Guard against numerical negatives
  vals[vals < 0] <- 0

  # Near-singularity refuses, the same as the non-mixed path (review H4).
  #
  # It used to substitute squared correlations for Johnson's weights, print one
  # console line, and carry on. Squared correlations are not relative weights:
  # they ignore the predictors' correlations with each other, which is the
  # entire problem the method exists to solve, and they do not sum to R-squared.
  # The report labelled them "Relative_Weight" and nothing downstream knew the
  # difference. The identical condition in the non-mixed path refuses, so the
  # same data got a refusal or a silently different number depending on whether
  # a categorical driver happened to be in the model.
  if (any(vals < 1e-10)) {
    keydriver_refuse(
      code = "MODEL_SINGULAR_MATRIX",
      title = "Singular Correlation Matrix",
      problem = paste0(
        "The model-term correlation matrix is singular or nearly singular ",
        "(severe multicollinearity among the drivers' model terms)."),
      why_it_matters = paste0(
        "Relative weights cannot be computed reliably when terms are this ",
        "closely related. The previous behaviour substituted squared ",
        "correlations, which ignore how the drivers relate to each other and do ",
        "not decompose R-squared, and reported them under the same column name."),
      how_to_fix = c(
        "Identify highly correlated driver pairs using a correlation matrix",
        "Remove or combine drivers that are too similar",
        "A categorical driver with a level almost nobody chose will do this: check the level counts",
        "Aim for correlations below 0.9 between predictors"
      )
    )
  } else {
    # Johnson relative weights at term level, on the symmetric square root
    # (review C1). The same PCA-rotation error lived here.
    Lam <- vecs %*% diag(sqrt(vals), nrow = p, ncol = p) %*% t(vecs)
    beta_star <- solve(Lam) %*% r_xy
    rw_term <- as.numeric((Lam^2) %*% (beta_star^2))
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


# ==============================================================================
# v10.3: PARTIAL R² AGGREGATION FOR CATEGORICAL DRIVERS
# ==============================================================================
# Per TURAS-KD-CONTINUOUS-UPGRADE-v1.0:
# - partial_r2 is the default aggregation method
# - Computes R² contribution of the driver as a whole

#' Calculate Partial R² for a Driver
#'
#' Computes the partial R² contribution of a driver by comparing
#' the full model R² to a reduced model without the driver.
#'
#' partial_r2 = (R²_full - R²_reduced) / (1 - R²_reduced)
#'
#' This gives the proportion of unexplained variance that is explained
#' by adding this driver to the model.
#'
#' @param data Data frame
#' @param outcome_var Outcome variable name
#' @param all_drivers All driver variable names
#' @param target_driver The driver to calculate partial R² for
#' @param weight_var Optional weight variable
#' @return Partial R² value (0 to 1)
#' @keywords internal
calculate_partial_r2 <- function(data, outcome_var, all_drivers, target_driver, weight_var = NULL) {

  # Build formula for full model
  full_formula_str <- paste(outcome_var, "~", paste(all_drivers, collapse = " + "))
  full_formula <- stats::as.formula(full_formula_str)

  # Build formula for reduced model (without target driver)
  other_drivers <- setdiff(all_drivers, target_driver)

  if (length(other_drivers) == 0) {
    # Only one driver - partial R² equals model R²
    if (!is.null(weight_var)) {
      full_model <- stats::lm(full_formula, data = data, weights = data[[weight_var]])
    } else {
      full_model <- stats::lm(full_formula, data = data)
    }
    return(summary(full_model)$r.squared)
  }

  reduced_formula_str <- paste(outcome_var, "~", paste(other_drivers, collapse = " + "))
  reduced_formula <- stats::as.formula(reduced_formula_str)

  # Fit both models
  if (!is.null(weight_var)) {
    full_model <- stats::lm(full_formula, data = data, weights = data[[weight_var]])
    reduced_model <- stats::lm(reduced_formula, data = data, weights = data[[weight_var]])
  } else {
    full_model <- stats::lm(full_formula, data = data)
    reduced_model <- stats::lm(reduced_formula, data = data)
  }

  r2_full <- summary(full_model)$r.squared
  r2_reduced <- summary(reduced_model)$r.squared

  # Partial R²
  if (r2_reduced >= 1) {
    # Edge case: reduced model explains everything
    return(0)
  }

  partial_r2 <- (r2_full - r2_reduced) / (1 - r2_reduced)

  # Clamp to [0, 1]
  max(0, min(1, partial_r2))
}


# The v10.3 importance engine was deleted here (review H3). Three functions,
# calculate_importance_partial_r2(), calculate_importance_permutation() and
# calculate_importance_by_config(), implemented a partial-R-squared and
# permutation scheme that nothing in the pipeline ever called: importance is
# computed and ranked by Shapley value in calculate_driver_importance() above.
# The Run_Status sheet nevertheless stamped "partial_r2" as the primary method,
# so the provenance named an engine that had not run.

