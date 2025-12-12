# ==============================================================================
# TURAS KEY DRIVER - SHAP MODEL FITTING
# ==============================================================================
#
# Purpose: Fit XGBoost/LightGBM models optimized for SHAP analysis
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================

#' Fit XGBoost Model for SHAP Analysis
#'
#' Fits a gradient boosting model optimized for interpretability.
#' Uses cross-validation with early stopping to prevent overfitting.
#'
#' @param prep Prepared data from prepare_shap_data()
#' @param config Configuration parameters
#'
#' @return Fitted xgb.Booster object with metadata attributes
#' @keywords internal
fit_shap_model <- function(prep, config) {

  if (!requireNamespace("xgboost", quietly = TRUE)) {
    stop("Package 'xgboost' required for SHAP analysis. Install with: install.packages('xgboost')",
         call. = FALSE)
  }

  # Set default parameters
  params <- list(
    objective = detect_objective(prep$y),
    eval_metric = detect_metric(prep$y),
    eta = config$learning_rate %||% 0.1,
    max_depth = config$max_depth %||% 6,
    subsample = config$subsample %||% 0.8,
    colsample_bytree = config$colsample_bytree %||% 0.8,
    min_child_weight = 1,
    nthread = max(1, parallel::detectCores() - 1)
  )

  # Create DMatrix with weights
  dtrain <- xgboost::xgb.DMatrix(
    data = prep$X,
    label = prep$y
  )

  # Add weights if available
  if (!is.null(prep$w)) {
    xgboost::setinfo(dtrain, "weight", prep$w)
  }

  # Get max rounds
  max_rounds <- config$n_trees %||% 500
  if (is.character(max_rounds) && tolower(max_rounds) == "auto") {
    max_rounds <- 500
  }

  # Cross-validation to find optimal nrounds
  cv_result <- xgboost::xgb.cv(
    params = params,
    data = dtrain,
    nrounds = max_rounds,
    nfold = 5,
    early_stopping_rounds = 20,
    verbose = FALSE,
    print_every_n = 50
  )

  best_nrounds <- cv_result$best_iteration
  if (is.null(best_nrounds) || is.na(best_nrounds)) {
    best_nrounds <- max_rounds
  }

  # Fit final model
  model <- xgboost::xgb.train(
    params = params,
    data = dtrain,
    nrounds = best_nrounds,
    verbose = FALSE
  )

  # Store metadata for later use
  attr(model, "prep") <- prep
  attr(model, "cv_result") <- cv_result
  attr(model, "best_iteration") <- best_nrounds

  model
}


#' Detect Objective Function
#'
#' Automatically selects appropriate XGBoost objective based on outcome type.
#'
#' @param y Outcome vector
#' @return Character string of objective function
#' @keywords internal
detect_objective <- function(y) {
  if (is.factor(y)) {
    n_levels <- nlevels(y)
    if (n_levels == 2) {
      return("binary:logistic")
    } else {
      return("multi:softprob")
    }
  }

  # Check if it looks like binary 0/1
  unique_vals <- unique(y[!is.na(y)])
  if (length(unique_vals) == 2 && all(unique_vals %in% c(0, 1))) {
    return("binary:logistic")
  }

  # Continuous outcome
  "reg:squarederror"
}


#' Detect Evaluation Metric
#'
#' Automatically selects appropriate evaluation metric based on outcome type.
#'
#' @param y Outcome vector
#' @return Character string of evaluation metric
#' @keywords internal
detect_metric <- function(y) {
  if (is.factor(y)) {
    n_levels <- nlevels(y)
    if (n_levels == 2) {
      return("logloss")
    } else {
      return("mlogloss")
    }
  }

  # Check if it looks like binary 0/1
  unique_vals <- unique(y[!is.na(y)])
  if (length(unique_vals) == 2 && all(unique_vals %in% c(0, 1))) {
    return("logloss")
  }

  # Continuous outcome
  "rmse"
}


#' Calculate Model Diagnostics
#'
#' Computes model fit statistics and diagnostics.
#'
#' @param model Fitted XGBoost model
#' @param prep Prepared data
#' @return List of diagnostic statistics
#' @keywords internal
model_diagnostics <- function(model, prep) {

  # Get predictions
  preds <- predict(model, prep$X)

  # Calculate R-squared for regression
  y <- prep$y
  ss_tot <- sum((y - mean(y))^2)
  ss_res <- sum((y - preds)^2)
  r_squared <- 1 - ss_res / ss_tot

  # RMSE
  rmse <- sqrt(mean((y - preds)^2))

  # MAE
  mae <- mean(abs(y - preds))

  # CV metrics if available
  cv_result <- attr(model, "cv_result")
  cv_best_score <- NULL
  if (!is.null(cv_result)) {
    # Get the best iteration score
    best_iter <- attr(model, "best_iteration")
    if (!is.null(best_iter) && best_iter <= nrow(cv_result$evaluation_log)) {
      cv_best_score <- cv_result$evaluation_log[[2]][best_iter]  # test metric
    }
  }

  list(
    model_type = "XGBoost",
    n_trees = attr(model, "best_iteration"),
    r_squared = r_squared,
    rmse = rmse,
    mae = mae,
    cv_best_score = cv_best_score,
    sample_size = nrow(prep$X)
  )
}


#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a
