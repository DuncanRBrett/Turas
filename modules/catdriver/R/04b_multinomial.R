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
#' Supports three multinomial modes (set in config$multinomial_mode):
#' - "baseline_category": Compare all levels to reference (default)
#' - "all_pairwise": Compare every pair of levels
#' - "one_vs_all": Compare each level vs. all others combined
#'
#' When multinomial_mode="one_vs_all", config$target_outcome_level specifies
#' which outcome level to treat as "success".
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

  valid_modes <- c("baseline_category", "all_pairwise", "one_vs_all")
  if (!multinomial_mode %in% valid_modes) {
    catdriver_refuse(
      reason = "CFG_INVALID_MULTINOMIAL_MODE",
      title = "INVALID MULTINOMIAL MODE",
      problem = paste0("multinomial_mode='", multinomial_mode, "' is not a valid option."),
      why_it_matters = "The multinomial mode determines how outcome categories are compared.",
      fix = paste0("Set multinomial_mode to one of: ", paste(valid_modes, collapse = ", "))
    )
  }

  # For one_vs_all mode, require target_outcome_level
  target_outcome_level <- config$target_outcome_level
  if (multinomial_mode == "one_vs_all") {
    if (is.null(target_outcome_level) || is.na(target_outcome_level)) {
      catdriver_refuse(
        reason = "CFG_TARGET_LEVEL_MISSING",
        title = "TARGET OUTCOME LEVEL REQUIRED",
        problem = "multinomial_mode='one_vs_all' requires target_outcome_level to be specified.",
        why_it_matters = "One-vs-all mode compares a specific level against all others combined.",
        fix = "Add target_outcome_level to your config specifying which outcome level to treat as 'success'."
      )
    }

    # Validate target level exists in data
    outcome_levels <- levels(data[[config$outcome_var]])
    if (!target_outcome_level %in% outcome_levels) {
      catdriver_refuse(
        reason = "CFG_TARGET_LEVEL_NOT_FOUND",
        title = "TARGET OUTCOME LEVEL NOT IN DATA",
        problem = paste0("target_outcome_level='", target_outcome_level, "' not found in outcome variable."),
        why_it_matters = "The specified target level must exist in your data to use one-vs-all mode.",
        fix = paste0("Set target_outcome_level to one of: ", paste(outcome_levels, collapse = ", "))
      )
    }
  }

  # ===========================================================================
  # FIT MODEL
  # ===========================================================================

  model <- tryCatch({
    if (!is.null(weights) && length(weights) == nrow(data)) {
      if (!(length(unique(weights)) == 1 && unique(weights)[1] == 1)) {
        data$.wt <- weights
        nnet::multinom(formula, data = data, weights = .wt, trace = FALSE, maxit = 500)
      } else {
        nnet::multinom(formula, data = data, trace = FALSE, maxit = 500)
      }
    } else {
      nnet::multinom(formula, data = data, trace = FALSE, maxit = 500)
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

  se_matrix <- tryCatch({
    vcov_mat <- vcov(model)
    se_vec <- sqrt(diag(vcov_mat))
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

      conf_level <- config$confidence_level
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
  null_model <- tryCatch({
    nnet::multinom(null_formula, data = data, trace = FALSE)
  }, error = function(e) NULL)

  if (!is.null(null_model)) {
    ll_null <- logLik(null_model)
    mcfadden_r2 <- 1 - (as.numeric(ll_full) / as.numeric(ll_null))
    lr_stat <- -2 * (as.numeric(ll_null) - as.numeric(ll_full))
    lr_df <- attr(ll_full, "df") - attr(ll_null, "df")
    lr_pvalue <- pchisq(lr_stat, abs(lr_df), lower.tail = FALSE)
  } else {
    mcfadden_r2 <- NA
    lr_stat <- NA
    lr_df <- NA
    lr_pvalue <- NA
  }

  aic <- AIC(model)

  pred_probs <- predict(model, type = "probs")
  pred_class <- predict(model, type = "class")

  confusion <- table(Actual = data[[config$outcome_var]], Predicted = pred_class)
  accuracy <- sum(diag(confusion)) / sum(confusion)

  list(
    model = model,
    model_type = "multinomial_logistic",
    engine_used = engine_used,
    fallback_used = fallback_used,
    fallback_reason = fallback_reason,
    coefficients = coef_df,
    reference_outcome = ref_level,
    multinomial_mode = multinomial_mode,
    target_outcome_level = target_outcome_level,
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
