# ==============================================================================
# CATEGORICAL KEY DRIVER - CORE ANALYSIS
# ==============================================================================
#
# Main analysis dispatcher and binary logistic regression implementation.
#
# Related modules:
#   - 04a_ordinal.R: Ordinal logistic regression
#   - 04b_multinomial.R: Multinomial logistic regression
#
# Version: 2.0
# Date: December 2024
#
# ==============================================================================

#' Run Categorical Key Driver Analysis
#'
#' Main analysis function that selects and runs the appropriate regression method.
#' Includes automatic fallback for separation/convergence issues.
#'
#' @param prep_data Preprocessed data from preprocess_catdriver_data()
#' @param config Configuration list
#' @param weights Optional weight vector
#' @param guard Guard state object for tracking warnings
#' @return List with model results and diagnostics
#' @export
run_catdriver_model <- function(prep_data, config, weights = NULL, guard = NULL) {

  if (is.null(guard)) {
    guard <- guard_init()
  }

  outcome_type <- prep_data$outcome_info$type
  model_formula <- prep_data$model_formula
  data <- prep_data$data

  # Run appropriate model with fallback
  model_result <- switch(outcome_type,
    binary = run_binary_logistic_robust(model_formula, data, weights, config, guard),
    ordinal = run_ordinal_logistic_robust(model_formula, data, weights, config, guard),
    nominal = run_multinomial_logistic_robust(model_formula, data, weights, config, guard),
    multinomial = run_multinomial_logistic_robust(model_formula, data, weights, config, guard),
    catdriver_refuse(
      reason = "CFG_OUTCOME_TYPE_UNKNOWN",
      title = "UNKNOWN OUTCOME TYPE",
      problem = paste0("Outcome type '", outcome_type, "' is not recognized."),
      why_it_matters = "CatDriver needs to know the outcome type to select the correct model.",
      fix = "Set outcome_type to one of: binary, ordinal, multinomial"
    )
  )

  # Add common model info
  model_result$outcome_type <- outcome_type
  model_result$outcome_var <- config$outcome_var
  model_result$outcome_label <- config$outcome_label
  model_result$n_observations <- nrow(data)
  model_result$formula <- model_formula

  model_result
}


# ==============================================================================
# BINARY LOGISTIC REGRESSION (with fallback)
# ==============================================================================

#' Run Binary Logistic Regression with Robust Fallback
#'
#' Attempts standard glm, falls back to Firth correction if separation detected.
#'
#' @param formula Model formula
#' @param data Analysis data
#' @param weights Optional weight vector
#' @param config Configuration list
#' @param guard Guard state object
#' @return List with model results
#' @keywords internal
run_binary_logistic_robust <- function(formula, data, weights = NULL, config, guard) {

  fallback_used <- FALSE
  fallback_reason <- NULL
  engine_used <- "glm"

  # ==========================================================================
  # ATTEMPT PRIMARY FIT (standard glm)
  # ==========================================================================

  model <- tryCatch({
    if (!is.null(weights) && length(weights) == nrow(data)) {
      if (length(unique(weights)) == 1 && unique(weights)[1] == 1) {
        glm(formula, data = data, family = binomial(link = "logit"))
      } else {
        data$.wt <- weights
        glm(formula, data = data, family = binomial(link = "logit"), weights = .wt)
      }
    } else {
      glm(formula, data = data, family = binomial(link = "logit"))
    }
  }, error = function(e) {
    list(error = TRUE, message = e$message)
  })

  # ==========================================================================
  # CHECK FOR SEPARATION / CONVERGENCE ISSUES
  # ==========================================================================

  needs_fallback <- FALSE

  if (is.list(model) && isTRUE(model$error)) {
    needs_fallback <- TRUE
    fallback_reason <- model$message
  } else if (!model$converged) {
    needs_fallback <- TRUE
    fallback_reason <- "Model did not converge"
  } else {
    # Check for separation
    separation_check <- check_separation(model)
    if (separation_check$has_separation) {
      needs_fallback <- TRUE
      fallback_reason <- separation_check$message
    }
  }

  # ==========================================================================
  # ATTEMPT FALLBACK (Firth correction via brglm2)
  # ==========================================================================

  if (needs_fallback) {
    # Try brglm2 for Firth correction
    if (requireNamespace("brglm2", quietly = TRUE)) {
      model <- tryCatch({
        engine_used <- "brglm2 (Firth)"
        fallback_used <- TRUE

        if (!is.null(weights) && length(weights) == nrow(data) &&
            !(length(unique(weights)) == 1 && unique(weights)[1] == 1)) {
          data$.wt <- weights
          brglm2::brglm(formula, data = data, family = binomial(link = "logit"),
                        weights = .wt, method = "brglmFit")
        } else {
          brglm2::brglm(formula, data = data, family = binomial(link = "logit"),
                        method = "brglmFit")
        }
      }, error = function(e) {
        list(error = TRUE, message = e$message)
      })
    } else {
      # ========================================================================
      # HARD STOP: Separation detected but no fallback available
      # ========================================================================
      #
      # Default behavior: REFUSE to proceed with unreliable estimates.
      # User can override with: allow_separation_without_fallback = TRUE
      #
      allow_separation <- isTRUE(config$allow_separation_without_fallback)

      if (!allow_separation) {
        catdriver_refuse(
          reason = "MODEL_SEPARATION_NO_FALLBACK",
          title = "SEPARATION DETECTED - NO FALLBACK AVAILABLE",
          problem = paste0("The binary logistic model detected separation (or quasi-separation). ",
                          "This produces unreliable odds ratios (often infinite or near-zero)."),
          why_it_matters = paste0("Reason: ", fallback_reason, "\n",
                                  "  The 'brglm2' package (Firth bias-reduced logistic regression) is not installed. ",
                                  "This package provides stable estimates when separation occurs."),
          fix = paste0("Solutions (in order of preference):\n",
                      "  1. Install brglm2: install.packages('brglm2')\n",
                      "  2. Collapse rare categories in predictors\n",
                      "  3. Remove the problematic predictor\n",
                      "  4. Set 'allow_separation_without_fallback = TRUE' in config (NOT RECOMMENDED)")
        )
      } else {
        # User explicitly allowed proceeding - warn loudly
        guard <- guard_warn(guard,
          "SEPARATION DETECTED: Proceeding WITHOUT Firth fallback (user override). Results may be unreliable.",
          "separation_override"
        )
        guard <- guard_flag_stability(guard, "Separation without fallback (user override)")
      }

      # If we get here with allow_separation=TRUE but model errored, still fail
      if (is.list(model) && isTRUE(model$error)) {
        catdriver_refuse(
          reason = "MODEL_FIT_FAILED",
          title = "MODEL FITTING FAILED",
          problem = "Model fitting failed and no fallback is available.",
          why_it_matters = "The logistic regression could not be estimated with the current data.",
          fix = "Check your data for issues (too few observations, perfect collinearity, etc.).",
          details = model$message
        )
      }
    }
  }

  # Final check
  if (is.list(model) && isTRUE(model$error)) {
    guard_model_fit_success(model, fallback_available = TRUE)
  }

  # Update guard
  guard <- guard_check_fallback(guard, fallback_used, fallback_reason)

  # ==========================================================================
  # EXTRACT RESULTS
  # ==========================================================================

  # Check convergence
  convergence_ok <- if (engine_used == "glm") model$converged else TRUE

  # Extract coefficients and odds ratios
  coef_summary <- summary(model)$coefficients
  coef_df <- data.frame(
    term = rownames(coef_summary),
    estimate = coef_summary[, "Estimate"],
    std_error = coef_summary[, "Std. Error"],
    z_value = coef_summary[, "z value"],
    p_value = coef_summary[, "Pr(>|z|)"],
    stringsAsFactors = FALSE
  )
  rownames(coef_df) <- NULL

  # Calculate odds ratios and CIs
  conf_level <- config$confidence_level
  z_crit <- qnorm(1 - (1 - conf_level) / 2)

  coef_df$odds_ratio <- exp(coef_df$estimate)
  coef_df$or_lower <- exp(coef_df$estimate - z_crit * coef_df$std_error)
  coef_df$or_upper <- exp(coef_df$estimate + z_crit * coef_df$std_error)

  # Calculate fit statistics
  null_deviance <- model$null.deviance
  residual_deviance <- model$deviance
  mcfadden_r2 <- 1 - (residual_deviance / null_deviance)
  aic <- model$aic

  # Likelihood ratio test
  lr_stat <- null_deviance - residual_deviance
  lr_df <- model$df.null - model$df.residual
  lr_pvalue <- pchisq(lr_stat, lr_df, lower.tail = FALSE)

  # Get predicted probabilities
  pred_probs <- predict(model, type = "response")

  # Classification metrics
  outcome_actual <- data[[config$outcome_var]]
  pred_class <- factor(ifelse(pred_probs >= 0.5,
                              levels(outcome_actual)[2],
                              levels(outcome_actual)[1]),
                       levels = levels(outcome_actual))

  confusion <- table(Actual = outcome_actual, Predicted = pred_class)

  accuracy <- sum(diag(confusion)) / sum(confusion)

  if (nrow(confusion) >= 2 && ncol(confusion) >= 2) {
    sensitivity <- confusion[2, 2] / sum(confusion[2, ])
    specificity <- confusion[1, 1] / sum(confusion[1, ])
  } else {
    sensitivity <- NA
    specificity <- NA
  }

  list(
    model = model,
    model_type = "binary_logistic",
    engine_used = engine_used,
    fallback_used = fallback_used,
    fallback_reason = fallback_reason,
    coefficients = coef_df,
    fit_statistics = list(
      null_deviance = null_deviance,
      residual_deviance = residual_deviance,
      mcfadden_r2 = mcfadden_r2,
      aic = aic,
      lr_statistic = lr_stat,
      lr_df = lr_df,
      lr_pvalue = lr_pvalue
    ),
    classification = list(
      confusion_matrix = confusion,
      accuracy = accuracy,
      sensitivity = sensitivity,
      specificity = specificity
    ),
    predicted_probs = pred_probs,
    convergence = convergence_ok,
    separation = check_separation(model),
    guard = guard
  )
}


#' Check Multicollinearity
#'
#' Calculates GVIF for model predictors.
#'
#' @param model Fitted model
#' @return Data frame with GVIF values
#' @export
check_multicollinearity <- function(model) {

  if (!requireNamespace("car", quietly = TRUE)) {
    return(list(
      checked = FALSE,
      message = "Package 'car' required for multicollinearity check"
    ))
  }

  vif_result <- tryCatch({
    vif_vals <- car::vif(model)

    if (is.matrix(vif_vals)) {
      df <- data.frame(
        variable = rownames(vif_vals),
        gvif = vif_vals[, "GVIF"],
        df = vif_vals[, "Df"],
        gvif_adj = vif_vals[, "GVIF^(1/(2*Df))"],
        stringsAsFactors = FALSE
      )
    } else {
      df <- data.frame(
        variable = names(vif_vals),
        gvif = vif_vals,
        df = 1,
        gvif_adj = sqrt(vif_vals),
        stringsAsFactors = FALSE
      )
    }

    rownames(df) <- NULL
    df
  }, error = function(e) {
    NULL
  })

  if (is.null(vif_result)) {
    return(list(
      checked = FALSE,
      message = "Could not calculate VIF (model may have issues)"
    ))
  }

  max_gvif_adj <- max(vif_result$gvif_adj, na.rm = TRUE)

  if (max_gvif_adj > 5) {
    status <- "WARNING"
    high_vars <- vif_result$variable[vif_result$gvif_adj > 5]
    interpretation <- paste0("High multicollinearity detected in: ",
                            paste(high_vars, collapse = ", "))
  } else if (max_gvif_adj > 2.5) {
    status <- "MARGINAL"
    interpretation <- "Moderate multicollinearity present but likely acceptable"
  } else {
    status <- "PASS"
    interpretation <- "No concerning multicollinearity detected"
  }

  list(
    checked = TRUE,
    status = status,
    max_gvif_adj = max_gvif_adj,
    vif_table = vif_result,
    interpretation = interpretation
  )
}
