# ==============================================================================
# TURAS KEY DRIVER - ELASTIC NET IMPORTANCE
# ==============================================================================
#
# Purpose: Penalized regression (Elastic Net via glmnet) for driver selection
#          and regularized importance estimation.
# Version: Turas v10.4
# Date: 2026-03
#
# Value: Handles multicollinearity gracefully, performs automatic variable
#        selection, answers "which drivers can we ignore?"
#
# References:
#   - Tibshirani, R. (1996). Regression Shrinkage and Selection via the Lasso.
#   - Zou, H. & Hastie, T. (2005). Regularization and Variable Selection via
#     the Elastic Net. JRSS-B.
# ==============================================================================


#' Run Elastic Net Driver Importance Analysis
#'
#' Uses cross-validated elastic net regression (glmnet) to identify which
#' drivers are retained under regularization and their coefficient magnitudes.
#' This provides a complementary view to Shapley/relative weights: drivers
#' with zero coefficients under elastic net can be safely deprioritised.
#'
#' @param data Data frame with outcome and driver columns
#' @param config Configuration list (outcome_var, driver_vars, weight_var,
#'   settings for alpha, nfolds)
#' @return List with status, result (coefficients, selected/zeroed drivers,
#'   lambda, alpha, cv_error)
#' @keywords internal
run_elastic_net_analysis <- function(data, config) {

  # --- Check glmnet availability ---
  if (!requireNamespace("glmnet", quietly = TRUE)) {
    return(list(
      status = "PARTIAL",
      message = "glmnet package not installed. Elastic net analysis skipped.",
      result = NULL
    ))
  }

  # --- Extract configuration ---
  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars
  weight_var  <- config$weight_var
  settings    <- config$settings %||% list()

  alpha <- as.numeric(settings$elastic_net_alpha %||% 0.5)  # 0=ridge, 1=lasso, 0.5=elastic net
  nfolds <- as.integer(settings$elastic_net_nfolds %||% 10)

  cat("   Running Elastic Net analysis...\n")
  cat(sprintf("   - Alpha: %.2f (0=ridge, 0.5=elastic net, 1=lasso)\n", alpha))
  cat(sprintf("   - Cross-validation folds: %d\n", nfolds))

  # --- Prepare model matrix ---
  # Use only complete cases for the specified variables
  use_vars <- c(outcome_var, driver_vars)
  if (!is.null(weight_var) && weight_var %in% names(data)) {
    use_vars <- c(use_vars, weight_var)
  }

  cc <- stats::complete.cases(data[, use_vars, drop = FALSE])
  d <- data[cc, , drop = FALSE]

  if (nrow(d) < 20) {
    return(list(
      status = "PARTIAL",
      message = sprintf("Too few complete cases (%d) for elastic net. Minimum 20 required.", nrow(d)),
      result = NULL
    ))
  }

  y <- d[[outcome_var]]
  X <- as.matrix(d[, driver_vars, drop = FALSE])

  # Scale predictors for comparable coefficients
  X_scaled <- scale(X)
  # Replace NaN from zero-variance columns with 0
  X_scaled[is.nan(X_scaled)] <- 0

  # Weights
  w <- if (!is.null(weight_var) && weight_var %in% names(d)) {
    d[[weight_var]]
  } else {
    rep(1, nrow(d))
  }

  # --- Cross-validated glmnet ---
  cv_fit <- tryCatch({
    glmnet::cv.glmnet(
      x = X_scaled,
      y = y,
      weights = w,
      alpha = alpha,
      nfolds = nfolds,
      type.measure = "mse",
      standardize = FALSE  # already scaled
    )
  }, error = function(e) {
    cat(sprintf("   [WARN] cv.glmnet failed: %s\n", e$message))
    return(NULL)
  })

  if (is.null(cv_fit)) {
    return(list(
      status = "PARTIAL",
      message = "Elastic net cross-validation failed.",
      result = NULL
    ))
  }

  # --- Extract coefficients at lambda.1se (parsimonious model) ---
  coefs_1se <- as.matrix(stats::coef(cv_fit, s = "lambda.1se"))
  coef_vals <- coefs_1se[-1, 1]  # drop intercept
  names(coef_vals) <- driver_vars

  # Also get lambda.min coefficients for comparison
  coefs_min <- as.matrix(stats::coef(cv_fit, s = "lambda.min"))
  coef_vals_min <- coefs_min[-1, 1]
  names(coef_vals_min) <- driver_vars

  # --- Classify drivers ---
  selected_1se <- names(coef_vals[coef_vals != 0])
  zeroed_1se   <- names(coef_vals[coef_vals == 0])
  selected_min <- names(coef_vals_min[coef_vals_min != 0])
  zeroed_min   <- names(coef_vals_min[coef_vals_min == 0])

  # --- Importance as |coefficient| share ---
  abs_coefs <- abs(coef_vals)
  total_abs <- sum(abs_coefs)
  importance_pct <- if (total_abs > 0) {
    (abs_coefs / total_abs) * 100
  } else {
    rep(0, length(abs_coefs))
  }

  # --- Build results table ---
  results_df <- data.frame(
    Driver = driver_vars,
    Coefficient_1se = coef_vals,
    Abs_Coefficient_1se = abs_coefs,
    Importance_Pct = round(importance_pct, 1),
    Selected_1se = driver_vars %in% selected_1se,
    Coefficient_min = coef_vals_min,
    Selected_min = driver_vars %in% selected_min,
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  results_df <- results_df[order(-results_df$Abs_Coefficient_1se), ]

  cat(sprintf("   - Selected drivers (lambda.1se): %d / %d\n",
              length(selected_1se), length(driver_vars)))
  cat(sprintf("   - Selected drivers (lambda.min): %d / %d\n",
              length(selected_min), length(driver_vars)))
  cat(sprintf("   - CV MSE at lambda.1se: %.4f\n", cv_fit$cvm[cv_fit$lambda == cv_fit$lambda.1se]))

  list(
    status = "PASS",
    message = sprintf("Elastic net complete. %d of %d drivers retained (lambda.1se).",
                      length(selected_1se), length(driver_vars)),
    result = list(
      coefficients = results_df,
      selected_drivers = selected_1se,
      zeroed_drivers = zeroed_1se,
      alpha = alpha,
      lambda_1se = cv_fit$lambda.1se,
      lambda_min = cv_fit$lambda.min,
      cv_mse_1se = cv_fit$cvm[cv_fit$lambda == cv_fit$lambda.1se],
      cv_mse_min = min(cv_fit$cvm),
      n_obs = nrow(d)
    )
  )
}
