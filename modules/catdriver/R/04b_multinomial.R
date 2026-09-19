# ==============================================================================
# CATEGORICAL KEY DRIVER - MULTINOMIAL LOGISTIC REGRESSION
# ==============================================================================
#
# Multinomial logistic regression implementation.
# Extracted from 04_analysis.R for maintainability.
#
# Version: 2.0
# ==============================================================================

#' Run Multinomial Logistic Regression with Robust Handling
#'
#' One mode exists: "baseline_category", every outcome level compared with one
#' reference level. config$multinomial_mode must say so. The module used to
#' accept all_pairwise, one_vs_all and per_outcome and then fit this same model
#' regardless, which meant the odds ratios did not answer the question the
#' setting asked; those values are refused now (see guard_require_multinomial_mode).
#'
#' @param formula Model formula
#' @param data Analysis data
#' @param weights Optional weight vector
#' @param config Configuration list
#' @param guard Guard state object
#' @return List with model results
#' @keywords internal
run_multinomial_logistic_robust <- function(formula, data, weights = NULL, config, guard) {

  engine_used <- "nnet::multinom"
  fallback_used <- FALSE
  fallback_reason <- NULL

  if (!requireNamespace("nnet", quietly = TRUE)) {
    catdriver_refuse(
      reason = "PKG_NNET_MISSING",
      title = "REQUIRED PACKAGE MISSING",
      problem = "Package 'nnet' is required for multinomial logistic regression but is not installed.",
      why_it_matters = "Multinomial outcomes (3+ categories) require the nnet package to fit the model.",
      fix = "Install the package with: install.packages('nnet')"
    )
  }

  # ===========================================================================
  # VALIDATE MULTINOMIAL MODE
  # ===========================================================================

  multinomial_mode <- config$multinomial_mode
  if (is.null(multinomial_mode)) {
    multinomial_mode <- "baseline_category"  # Default
  }

  # One implemented mode. The guard refuses the others before the run reaches
  # here; this is the engine's own backstop for a direct call.
  if (!identical(multinomial_mode, "baseline_category")) {
    catdriver_refuse(
      reason = "CFG_MULTINOMIAL_MODE_NOT_IMPLEMENTED",
      title = "MULTINOMIAL MODE NOT IMPLEMENTED",
      problem = paste0("multinomial_mode='", multinomial_mode, "' is not implemented."),
      why_it_matters = paste0(
        "Only 'baseline_category' exists. The engine fits that model whatever this setting says, ",
        "so accepting another value would report odds ratios that do not answer the question asked."
      ),
      fix = paste0(
        "Set multinomial_mode to 'baseline_category'.\n",
        "To compare one level against all others, recode the outcome as binary ",
        "and run it with outcome_type = 'binary'."
      )
    )
  }

  # ===========================================================================
  # FIT MODEL
  # ===========================================================================

  fit_data <- data  # Local copy to avoid polluting caller's data with weight column
  # Hess = TRUE stores the Hessian so vcov()/confint() work outside fit scope
  # Use unique column name to avoid collision with user data columns
  model <- tryCatch({
    if (!is.null(weights) && length(weights) == nrow(data)) {
      if (!all(abs(weights - 1) < 1e-10)) {
        fit_data$..catdriver_wt.. <- weights
        nnet::multinom(formula, data = fit_data, weights = ..catdriver_wt..,
                       trace = FALSE, maxit = 500, Hess = TRUE)
      } else {
        nnet::multinom(formula, data = fit_data,
                       trace = FALSE, maxit = 500, Hess = TRUE)
      }
    } else {
      nnet::multinom(formula, data = fit_data,
                     trace = FALSE, maxit = 500, Hess = TRUE)
    }
  }, error = function(e) {
    list(error = TRUE, message = e$message)
  })

  if (is.list(model) && isTRUE(model$error)) {
    guard_model_fit_success(model, fallback_available = FALSE)
  }

  convergence_ok <- model$convergence == 0
  if (!convergence_ok) {
    guard <- guard_warn(guard,
      "Multinomial model may not have fully converged",
      "model_convergence"
    )
  }

  # Extract coefficients
  coef_matrix <- coef(model)

  if (is.null(dim(coef_matrix))) {
    coef_matrix <- matrix(coef_matrix, nrow = 1,
                         dimnames = list(names(model$lev)[-1], names(coef_matrix)))
  }

  # vcov() for nnet::multinom internally calls model.frame() which tries to

  # evaluate the `data` argument from model$call. If model$call stores the
  # symbol `fit_data`, it fails when `fit_data` is not in the calling scope.
  # Fix: temporarily ensure fit_data is visible, or use the Hessian directly.
  se_matrix <- tryCatch({
    # nnet stores the Hessian — use it directly for robust SE extraction
    if (!is.null(model$Hessian)) {
      vcov_mat <- solve(model$Hessian)
      se_vec <- sqrt(pmax(diag(vcov_mat), 0))  # pmax guards against tiny negatives
    } else {
      vcov_mat <- vcov(model)
      se_vec <- sqrt(diag(vcov_mat))
    }
    matrix(se_vec, nrow = nrow(coef_matrix), byrow = TRUE,
           dimnames = dimnames(coef_matrix))
  }, error = function(e) {
    matrix(NA, nrow = nrow(coef_matrix), ncol = ncol(coef_matrix),
           dimnames = dimnames(coef_matrix))
  })

  outcome_levels <- rownames(coef_matrix)
  ref_level <- levels(data[[config$outcome_var]])[1]

  coef_list <- list()

  for (i in 1:nrow(coef_matrix)) {
    for (j in 1:ncol(coef_matrix)) {
      est <- coef_matrix[i, j]
      se <- se_matrix[i, j]

      z_val <- if (!is.na(se) && se > 0) est / se else NA
      p_val <- if (!is.na(z_val)) 2 * pnorm(-abs(z_val)) else NA

      conf_level <- config$confidence_level %||% CATDRIVER_DEFAULTS$confidence_level %||% 0.95
      z_crit <- qnorm(1 - (1 - conf_level) / 2)

      coef_list[[length(coef_list) + 1]] <- data.frame(
        outcome_level = outcome_levels[i],
        term = colnames(coef_matrix)[j],
        estimate = est,
        std_error = se,
        z_value = z_val,
        p_value = p_val,
        odds_ratio = exp(est),
        or_lower = if (!is.na(se)) exp(est - z_crit * se) else NA,
        or_upper = if (!is.na(se)) exp(est + z_crit * se) else NA,
        reference_outcome = ref_level,
        stringsAsFactors = FALSE
      )
    }
  }

  coef_df <- do.call(rbind, coef_list)
  rownames(coef_df) <- NULL

  # Fit statistics
  ll_full <- logLik(model)

  null_formula <- as.formula(paste(config$outcome_var, "~ 1"))
  # The null model must see the same rows and the same weights as the full fit.
  # It used to be refitted on the caller's raw frame with no weights, which
  # compared a weighted full model to an unweighted null (negative McFadden
  # R-squared and an invalid LR test, under PASS) and, where a predictor had
  # missing values, on more rows than the full model ever used.
  estimation_rows <- cd_estimation_rows(model, nrow(fit_data))
  estimation_data <- if (!is.null(estimation_rows)) {
    fit_data[estimation_rows, , drop = FALSE]
  } else {
    fit_data
  }
  weights_used <- if ("..catdriver_wt.." %in% names(estimation_data)) {
    estimation_data[["..catdriver_wt.."]]
  } else {
    NULL
  }

  null_model <- tryCatch({
    if (!is.null(weights_used)) {
      nnet::multinom(null_formula, data = estimation_data, weights = ..catdriver_wt..,
                     trace = FALSE)
    } else {
      nnet::multinom(null_formula, data = estimation_data, trace = FALSE)
    }
  }, error = function(e) NULL)

  if (!is.null(null_model)) {
    ll_null <- logLik(null_model)
    mcfadden_r2 <- 1 - (as.numeric(ll_full) / as.numeric(ll_null))
    lr_stat <- -2 * (as.numeric(ll_null) - as.numeric(ll_full))
    lr_df <- attr(ll_full, "df") - attr(ll_null, "df")
    lr_pvalue <- pchisq(lr_stat, abs(lr_df), lower.tail = FALSE)
  } else {
    cat("   [WARNING] Null model failed to fit - R\u00B2 and LR test unavailable\n")
    mcfadden_r2 <- NA
    lr_stat <- NA
    lr_df <- NA
    lr_pvalue <- NA
  }

  aic <- AIC(model)

  pred_probs <- predict(model, type = "probs")
  pred_class <- predict(model, type = "class")

  # Predictions cover only the rows the model fitted; the caller's frame may
  # hold more (a predictor with missing values). Cross like with like.
  confusion <- table(Actual = cd_fitted_outcome(model, data, config$outcome_var),
                     Predicted = pred_class)
  total_obs <- sum(confusion)
  accuracy <- if (total_obs > 0) sum(diag(confusion)) / total_obs else NA_real_

  list(
    model = model,
    analysis_data = data,
    # The rows and weights the full model actually used. Importance refits
    # every reduced model and must use exactly these, or the likelihood-ratio
    # statistics are not comparable.
    estimation_data = estimation_data,
    estimation_weights = weights_used,
    weight_column = if (!is.null(weights_used)) "..catdriver_wt.." else NULL,
    model_type = "multinomial_logistic",
    engine_used = engine_used,
    fallback_used = fallback_used,
    fallback_reason = fallback_reason,
    coefficients = coef_df,
    reference_outcome = ref_level,
    multinomial_mode = multinomial_mode,
    target_outcome_level = NULL,  # one_vs_all is not implemented; see the guard
    fit_statistics = list(
      log_likelihood = as.numeric(ll_full),
      mcfadden_r2 = mcfadden_r2,
      aic = aic,
      lr_statistic = lr_stat,
      lr_df = lr_df,
      lr_pvalue = lr_pvalue
    ),
    classification = list(
      confusion_matrix = confusion,
      accuracy = accuracy
    ),
    predicted_probs = pred_probs,
    predicted_class = pred_class,
    convergence = convergence_ok,
    guard = guard
  )
}
