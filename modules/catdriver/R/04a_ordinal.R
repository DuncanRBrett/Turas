# ==============================================================================
# CATEGORICAL KEY DRIVER - ORDINAL LOGISTIC REGRESSION
# ==============================================================================
#
# Ordinal logistic regression implementation with robust fallback.
# Extracted from 04_analysis.R for maintainability.
#
# Version: 2.0
# ==============================================================================

#' Run Ordinal Logistic Regression with Robust Fallback
#'
#' Attempts ordinal::clm first (more robust), falls back to MASS::polr.
#'
#' @param formula Model formula
#' @param data Analysis data
#' @param weights Optional weight vector
#' @param config Configuration list
#' @param guard Guard state object
#' @return List with model results
#' @keywords internal
run_ordinal_logistic_robust <- function(formula, data, weights = NULL, config, guard) {

  fallback_used <- FALSE
  fallback_reason <- NULL
  engine_used <- "ordinal::clm"

  # ==========================================================================
  # ATTEMPT PRIMARY FIT (ordinal::clm)
  # ==========================================================================

  model <- NULL
  primary_success <- FALSE

  if (requireNamespace("ordinal", quietly = TRUE)) {
    model <- tryCatch({
      if (!is.null(weights) && length(weights) == nrow(data)) {
        if (!(length(unique(weights)) == 1 && unique(weights)[1] == 1)) {
          data$.wt <- weights
          ordinal::clm(formula, data = data, weights = .wt, link = "logit")
        } else {
          ordinal::clm(formula, data = data, link = "logit")
        }
      } else {
        ordinal::clm(formula, data = data, link = "logit")
      }
    }, error = function(e) {
      list(error = TRUE, message = e$message)
    })

    if (!is.list(model) || !isTRUE(model$error)) {
      # Check convergence
      if (!is.null(model$convergence) && model$convergence$code == 0) {
        primary_success <- TRUE
      } else if (is.null(model$convergence)) {
        primary_success <- TRUE  # Assume success if no convergence info
      }
    }
  }

  # ==========================================================================
  # FALLBACK TO MASS::polr IF NEEDED
  # ==========================================================================

  if (!primary_success) {
    fallback_used <- TRUE
    fallback_reason <- if (is.list(model) && isTRUE(model$error)) {
      model$message
    } else if (!requireNamespace("ordinal", quietly = TRUE)) {
      "ordinal package not available"
    } else {
      "ordinal::clm did not converge"
    }

    engine_used <- "MASS::polr"

    if (!requireNamespace("MASS", quietly = TRUE)) {
      stop("Package 'MASS' required for ordinal logistic regression", call. = FALSE)
    }

    model <- tryCatch({
      if (!is.null(weights) && length(weights) == nrow(data)) {
        if (!(length(unique(weights)) == 1 && unique(weights)[1] == 1)) {
          data$.wt <- weights
          MASS::polr(formula, data = data, weights = .wt, Hess = TRUE, method = "logistic")
        } else {
          MASS::polr(formula, data = data, Hess = TRUE, method = "logistic")
        }
      } else {
        MASS::polr(formula, data = data, Hess = TRUE, method = "logistic")
      }
    }, error = function(e) {
      list(error = TRUE, message = e$message)
    })

    if (is.list(model) && isTRUE(model$error)) {
      guard_model_fit_success(model, fallback_available = TRUE)
    }
  }

  # Update guard
  guard <- guard_check_fallback(guard, fallback_used, fallback_reason)

  # ==========================================================================
  # EXTRACT RESULTS
  # ==========================================================================

  # Handle different model structures (clm vs polr)
  if (inherits(model, "clm")) {
    result <- extract_clm_results(model, config, guard)
  } else {
    result <- extract_polr_results(model, config, guard)
  }

  result$engine_used <- engine_used
  result$fallback_used <- fallback_used
  result$fallback_reason <- fallback_reason
  result$guard <- guard

  result
}


#' Extract Results from ordinal::clm Model
#'
#' @param model clm model object
#' @param config Configuration list
#' @param guard Guard state object
#' @return List with extracted results
#' @keywords internal
extract_clm_results <- function(model, config, guard) {

  coef_vals <- coef(model)
  vcov_mat <- vcov(model)
  se_vals <- sqrt(diag(vcov_mat))

  # Separate thresholds from predictor coefficients
  threshold_names <- names(model$alpha)
  coef_names <- names(model$beta)

  # Predictor coefficients
  pred_coef <- model$beta
  pred_se <- se_vals[names(se_vals) %in% coef_names]

  z_vals <- pred_coef / pred_se
  p_vals <- 2 * pnorm(-abs(z_vals))

  coef_df <- data.frame(
    term = names(pred_coef),
    estimate = as.numeric(pred_coef),
    std_error = as.numeric(pred_se),
    z_value = as.numeric(z_vals),
    p_value = as.numeric(p_vals),
    stringsAsFactors = FALSE
  )
  rownames(coef_df) <- NULL

  # Odds ratios
  conf_level <- config$confidence_level
  z_crit <- qnorm(1 - (1 - conf_level) / 2)

  coef_df$odds_ratio <- exp(coef_df$estimate)
  coef_df$or_lower <- exp(coef_df$estimate - z_crit * coef_df$std_error)
  coef_df$or_upper <- exp(coef_df$estimate + z_crit * coef_df$std_error)

  # Thresholds
  thresh_se <- se_vals[names(se_vals) %in% threshold_names]
  thresh_df <- data.frame(
    threshold = threshold_names,
    estimate = as.numeric(model$alpha),
    std_error = as.numeric(thresh_se),
    stringsAsFactors = FALSE
  )

  # Fit statistics
  ll_full <- logLik(model)
  aic <- AIC(model)

  # Null model for comparison
  null_formula <- as.formula(paste(config$outcome_var, "~ 1"))
  null_model <- tryCatch({
    ordinal::clm(null_formula, data = model$model, link = "logit")
  }, error = function(e) NULL)

  if (!is.null(null_model)) {
    ll_null <- logLik(null_model)
    mcfadden_r2 <- 1 - (as.numeric(ll_full) / as.numeric(ll_null))
    lr_stat <- -2 * (as.numeric(ll_null) - as.numeric(ll_full))
    lr_df <- length(pred_coef)
    lr_pvalue <- pchisq(lr_stat, lr_df, lower.tail = FALSE)
  } else {
    mcfadden_r2 <- NA
    lr_stat <- NA
    lr_df <- NA
    lr_pvalue <- NA
  }

  # Predicted probabilities
  pred_probs <- tryCatch(
    predict(model, type = "prob")$fit,
    error = function(e) predict(model, type = "prob")
  )

  # Convergence
  convergence_ok <- is.null(model$convergence) || model$convergence$code == 0

  list(
    model = model,
    model_type = "ordinal_logistic",
    coefficients = coef_df,
    thresholds = thresh_df,
    fit_statistics = list(
      log_likelihood = as.numeric(ll_full),
      mcfadden_r2 = mcfadden_r2,
      aic = aic,
      lr_statistic = lr_stat,
      lr_df = lr_df,
      lr_pvalue = lr_pvalue
    ),
    proportional_odds = NULL,  # clm has built-in tests
    predicted_probs = pred_probs,
    convergence = convergence_ok
  )
}


#' Extract Results from MASS::polr Model
#'
#' @param model polr model object
#' @param config Configuration list
#' @param guard Guard state object
#' @return List with extracted results
#' @keywords internal
extract_polr_results <- function(model, config, guard) {

  coef_vals <- coef(model)
  se_vals <- sqrt(diag(vcov(model)))

  n_coef <- length(coef_vals)
  n_thresh <- length(model$zeta)

  pred_coef <- coef_vals
  pred_se <- se_vals[1:n_coef]

  z_vals <- pred_coef / pred_se
  p_vals <- 2 * pnorm(-abs(z_vals))

  coef_df <- data.frame(
    term = names(pred_coef),
    estimate = as.numeric(pred_coef),
    std_error = pred_se,
    z_value = z_vals,
    p_value = p_vals,
    stringsAsFactors = FALSE
  )
  rownames(coef_df) <- NULL

  conf_level <- config$confidence_level
  z_crit <- qnorm(1 - (1 - conf_level) / 2)

  coef_df$odds_ratio <- exp(coef_df$estimate)
  coef_df$or_lower <- exp(coef_df$estimate - z_crit * coef_df$std_error)
  coef_df$or_upper <- exp(coef_df$estimate + z_crit * coef_df$std_error)

  thresh_df <- data.frame(
    threshold = names(model$zeta),
    estimate = as.numeric(model$zeta),
    std_error = se_vals[(n_coef + 1):(n_coef + n_thresh)],
    stringsAsFactors = FALSE
  )

  ll_full <- logLik(model)

  null_formula <- as.formula(paste(config$outcome_var, "~ 1"))
  null_model <- tryCatch({
    MASS::polr(null_formula, data = model$model, Hess = TRUE, method = "logistic")
  }, error = function(e) NULL)

  if (!is.null(null_model)) {
    ll_null <- logLik(null_model)
    mcfadden_r2 <- 1 - (as.numeric(ll_full) / as.numeric(ll_null))
    lr_stat <- -2 * (as.numeric(ll_null) - as.numeric(ll_full))
    lr_df <- length(coef_vals)
    lr_pvalue <- pchisq(lr_stat, lr_df, lower.tail = FALSE)
  } else {
    mcfadden_r2 <- NA
    lr_stat <- NA
    lr_df <- NA
    lr_pvalue <- NA
  }

  aic <- AIC(model)
  convergence_ok <- model$convergence == 0

  pred_probs <- predict(model, type = "probs")

  # Proportional odds check
  po_check <- check_proportional_odds(model, model$model, config)

  list(
    model = model,
    model_type = "ordinal_logistic",
    coefficients = coef_df,
    thresholds = thresh_df,
    fit_statistics = list(
      log_likelihood = as.numeric(ll_full),
      mcfadden_r2 = mcfadden_r2,
      aic = aic,
      lr_statistic = lr_stat,
      lr_df = lr_df,
      lr_pvalue = lr_pvalue
    ),
    proportional_odds = po_check,
    predicted_probs = pred_probs,
    convergence = convergence_ok
  )
}


#' Check Proportional Odds Assumption
#'
#' @param model Fitted polr model
#' @param data Analysis data
#' @param config Configuration list
#' @return List with check results
#' @keywords internal
check_proportional_odds <- function(model, data, config) {

  outcome_var <- config$outcome_var
  outcome <- data[[outcome_var]]
  levels_vec <- levels(outcome)
  n_levels <- length(levels_vec)

  if (n_levels < 3) {
    return(list(
      checked = FALSE,
      message = "Proportional odds only applicable to 3+ categories"
    ))
  }

  main_coefs <- coef(model)
  coef_names <- names(main_coefs)

  binary_coefs <- list()
  cutpoint_names <- character(0)

  for (i in 1:(n_levels - 1)) {
    binary_outcome <- as.numeric(as.numeric(outcome) > i)

    binary_formula <- as.formula(paste("binary_outcome ~",
                                       paste(config$driver_vars, collapse = " + ")))

    binary_model <- tryCatch({
      temp_data <- data
      temp_data$binary_outcome <- binary_outcome
      glm(binary_formula, data = temp_data, family = binomial)
    }, error = function(e) NULL)

    if (!is.null(binary_model)) {
      bc <- coef(binary_model)
      matched_coefs <- bc[names(bc) %in% coef_names]
      if (length(matched_coefs) > 0) {
        binary_coefs[[paste0("cut_", i)]] <- matched_coefs
        cutpoint_names <- c(cutpoint_names, paste(levels_vec[i], "|", levels_vec[i + 1]))
      }
    }
  }

  if (length(binary_coefs) < 2) {
    return(list(
      checked = FALSE,
      message = "Could not compare coefficients across thresholds"
    ))
  }

  max_or_ratio <- 1
  problematic_vars <- character(0)

  for (coef_name in coef_names) {
    or_values <- sapply(binary_coefs, function(x) {
      if (coef_name %in% names(x)) exp(x[[coef_name]]) else NA
    })
    or_values <- na.omit(or_values)

    if (length(or_values) >= 2) {
      ratio <- max(or_values) / min(or_values)
      if (ratio > max_or_ratio) {
        max_or_ratio <- ratio
      }
      if (ratio > 1.5) {
        problematic_vars <- c(problematic_vars, coef_name)
      }
    }
  }

  if (max_or_ratio < 1.25) {
    status <- "PASS"
    interpretation <- "Proportional odds assumption appears reasonable (OR variation < 25% across thresholds)"
  } else if (max_or_ratio < 1.5) {
    status <- "MARGINAL"
    interpretation <- "Proportional odds assumption is marginally met. Results are likely still valid."
  } else {
    status <- "WARNING"
    interpretation <- paste0("Proportional odds assumption may be violated for: ",
                            paste(unique(problematic_vars), collapse = ", "),
                            ". Consider multinomial model as alternative.")
  }

  list(
    checked = TRUE,
    status = status,
    max_or_ratio = max_or_ratio,
    problematic_vars = unique(problematic_vars),
    interpretation = interpretation
  )
}
