# ==============================================================================
# CATEGORICAL KEY DRIVER - CORE ANALYSIS
# ==============================================================================
#
# Binary, ordinal, and multinomial logistic regression implementations.
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================

#' Run Categorical Key Driver Analysis
#'
#' Main analysis function that selects and runs the appropriate regression method.
#'
#' @param prep_data Preprocessed data from preprocess_catdriver_data()
#' @param config Configuration list
#' @param weights Optional weight vector
#' @return List with model results and diagnostics
#' @export
run_catdriver_model <- function(prep_data, config, weights = NULL) {

  outcome_type <- prep_data$outcome_info$type
  model_formula <- prep_data$model_formula
  data <- prep_data$data

  # Run appropriate model
  model_result <- switch(outcome_type,
    binary = run_binary_logistic(model_formula, data, weights, config),
    ordinal = run_ordinal_logistic(model_formula, data, weights, config),
    nominal = run_multinomial_logistic(model_formula, data, weights, config),
    stop("Unknown outcome type: ", outcome_type)
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
# BINARY LOGISTIC REGRESSION
# ==============================================================================

#' Run Binary Logistic Regression
#'
#' @param formula Model formula
#' @param data Analysis data
#' @param weights Optional weight vector
#' @param config Configuration list
#' @return List with model results
#' @keywords internal
run_binary_logistic <- function(formula, data, weights = NULL, config) {

  # Fit model
  # Note: Avoid using 'weights' directly in glm() call due to conflict with stats::weights function
  model <- tryCatch({
    if (!is.null(weights) && length(weights) == nrow(data)) {
      # Check if weights are all equal (no actual weighting needed)
      if (length(unique(weights)) == 1 && unique(weights)[1] == 1) {
        glm(formula, data = data, family = binomial(link = "logit"))
      } else {
        # Add weights to data frame to avoid scoping issues
        data$.wt <- weights
        glm(formula, data = data, family = binomial(link = "logit"),
            weights = .wt)
      }
    } else {
      glm(formula, data = data, family = binomial(link = "logit"))
    }
  }, error = function(e) {
    stop("Binary logistic model failed: ", e$message,
         "\n\nThis may be due to perfect separation or collinearity.",
         call. = FALSE)
  })

  # Check convergence
  if (!model$converged) {
    warning("Model did not converge. Results may be unreliable.")
  }

  # Check for separation
  separation_check <- check_separation(model)
  if (separation_check$has_separation) {
    warning(separation_check$message)
  }

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

  # Calculate metrics safely
  accuracy <- sum(diag(confusion)) / sum(confusion)

  # Sensitivity and specificity
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
    convergence = model$converged,
    separation = separation_check
  )
}


# ==============================================================================
# ORDINAL LOGISTIC REGRESSION
# ==============================================================================

#' Run Ordinal Logistic Regression
#'
#' Uses proportional odds model via MASS::polr.
#'
#' @param formula Model formula
#' @param data Analysis data
#' @param weights Optional weight vector
#' @param config Configuration list
#' @return List with model results
#' @keywords internal
run_ordinal_logistic <- function(formula, data, weights = NULL, config) {

  # Ensure MASS is available
  if (!requireNamespace("MASS", quietly = TRUE)) {
    stop("Package 'MASS' required for ordinal logistic regression",
         call. = FALSE)
  }

  # Fit model
  # Note: Avoid using 'weights' directly due to conflict with stats::weights function
  model <- tryCatch({
    if (!is.null(weights) && length(weights) == nrow(data)) {
      # Check if weights are all equal (no actual weighting needed)
      if (length(unique(weights)) == 1 && unique(weights)[1] == 1) {
        MASS::polr(formula, data = data, Hess = TRUE, method = "logistic")
      } else {
        # Add weights to data frame to avoid scoping issues
        data$.wt <- weights
        MASS::polr(formula, data = data, weights = .wt,
                   Hess = TRUE, method = "logistic")
      }
    } else {
      MASS::polr(formula, data = data, Hess = TRUE, method = "logistic")
    }
  }, error = function(e) {
    stop("Ordinal logistic model failed: ", e$message,
         "\n\nConsider using nominal (multinomial) model instead.",
         call. = FALSE)
  })

  # Check convergence
  convergence_ok <- model$convergence == 0
  if (!convergence_ok) {
    warning("Model may not have fully converged. Results should be interpreted with caution.")
  }

  # Extract coefficients
  coef_vals <- coef(model)
  se_vals <- sqrt(diag(vcov(model)))

  # Separate predictor coefficients from thresholds
  n_coef <- length(coef_vals)
  n_thresh <- length(model$zeta)

  # Predictor coefficients
  pred_coef <- coef_vals
  pred_se <- se_vals[1:n_coef]

  # Calculate z-values and p-values
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

  # Calculate cumulative odds ratios and CIs
  conf_level <- config$confidence_level
  z_crit <- qnorm(1 - (1 - conf_level) / 2)

  coef_df$odds_ratio <- exp(coef_df$estimate)
  coef_df$or_lower <- exp(coef_df$estimate - z_crit * coef_df$std_error)
  coef_df$or_upper <- exp(coef_df$estimate + z_crit * coef_df$std_error)

  # Threshold coefficients
  thresh_df <- data.frame(
    threshold = names(model$zeta),
    estimate = as.numeric(model$zeta),
    std_error = se_vals[(n_coef + 1):(n_coef + n_thresh)],
    stringsAsFactors = FALSE
  )

  # Calculate fit statistics
  ll_full <- logLik(model)

  # Fit null model for comparison
  null_formula <- as.formula(paste(config$outcome_var, "~ 1"))
  null_model <- tryCatch({
    MASS::polr(null_formula, data = data, Hess = TRUE, method = "logistic")
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

  # Proportional odds check (practical approach)
  po_check <- check_proportional_odds(model, data, config)

  # Get predicted probabilities
  pred_probs <- predict(model, type = "probs")

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


#' Check Proportional Odds Assumption (Practical Approach)
#'
#' @param model Fitted polr model
#' @param data Analysis data
#' @param config Configuration list
#' @return List with check results
#' @keywords internal
check_proportional_odds <- function(model, data, config) {

  # Try to run binary models at each threshold for comparison
  # This is a practical approach rather than formal Brant test

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

  # Get model coefficients (excluding thresholds)
  main_coefs <- coef(model)
  coef_names <- names(main_coefs)

  # Try to fit separate binary models at each cutpoint
  binary_coefs <- list()
  cutpoint_names <- character(0)

  for (i in 1:(n_levels - 1)) {
    # Create binary outcome: 1 if above cutpoint
    binary_outcome <- as.numeric(as.numeric(outcome) > i)

    # Fit binary model
    binary_formula <- as.formula(paste("binary_outcome ~",
                                       paste(config$driver_vars, collapse = " + ")))

    binary_model <- tryCatch({
      temp_data <- data
      temp_data$binary_outcome <- binary_outcome
      glm(binary_formula, data = temp_data, family = binomial)
    }, error = function(e) NULL)

    if (!is.null(binary_model)) {
      bc <- coef(binary_model)
      # Match coefficient names
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

  # Compare coefficients across cutpoints
  # Calculate max ratio of ORs for same predictor
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

  # Practical interpretation
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


# ==============================================================================
# MULTINOMIAL LOGISTIC REGRESSION
# ==============================================================================

#' Run Multinomial Logistic Regression
#'
#' Uses nnet::multinom for unordered multi-category outcomes.
#'
#' @param formula Model formula
#' @param data Analysis data
#' @param weights Optional weight vector
#' @param config Configuration list
#' @return List with model results
#' @keywords internal
run_multinomial_logistic <- function(formula, data, weights = NULL, config) {

  # Ensure nnet is available
  if (!requireNamespace("nnet", quietly = TRUE)) {
    stop("Package 'nnet' required for multinomial logistic regression",
         call. = FALSE)
  }

  # Fit model
  # Note: Avoid using 'weights' directly due to conflict with stats::weights function
  model <- tryCatch({
    if (!is.null(weights) && length(weights) == nrow(data)) {
      # Check if weights are all equal (no actual weighting needed)
      if (length(unique(weights)) == 1 && unique(weights)[1] == 1) {
        nnet::multinom(formula, data = data, trace = FALSE, maxit = 500)
      } else {
        # Add weights to data frame to avoid scoping issues
        data$.wt <- weights
        nnet::multinom(formula, data = data, weights = .wt,
                       trace = FALSE, maxit = 500)
      }
    } else {
      nnet::multinom(formula, data = data, trace = FALSE, maxit = 500)
    }
  }, error = function(e) {
    stop("Multinomial logistic model failed: ", e$message,
         "\n\nConsider reducing number of predictors or collapsing outcome categories.",
         call. = FALSE)
  })

  # Check convergence
  convergence_ok <- model$convergence == 0
  if (!convergence_ok) {
    warning("Model may not have fully converged. Consider increasing maxit or simplifying model.")
  }

  # Extract coefficients
  coef_matrix <- coef(model)

  # Handle single vs multiple equations
  if (is.null(dim(coef_matrix))) {
    # Single equation (3 outcome categories)
    coef_matrix <- matrix(coef_matrix, nrow = 1,
                         dimnames = list(names(model$lev)[-1], names(coef_matrix)))
  }

  # Get standard errors
  se_matrix <- tryCatch({
    vcov_mat <- vcov(model)
    se_vec <- sqrt(diag(vcov_mat))
    matrix(se_vec, nrow = nrow(coef_matrix), byrow = TRUE,
           dimnames = dimnames(coef_matrix))
  }, error = function(e) {
    matrix(NA, nrow = nrow(coef_matrix), ncol = ncol(coef_matrix),
           dimnames = dimnames(coef_matrix))
  })

  # Build coefficient data frame
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

  # Calculate fit statistics
  ll_full <- logLik(model)

  # Fit null model
  null_formula <- as.formula(paste(config$outcome_var, "~ 1"))
  null_model <- tryCatch({
    nnet::multinom(null_formula, data = data, trace = FALSE)
  }, error = function(e) NULL)

  if (!is.null(null_model)) {
    ll_null <- logLik(null_model)
    mcfadden_r2 <- 1 - (as.numeric(ll_full) / as.numeric(ll_null))
    lr_stat <- -2 * (as.numeric(ll_null) - as.numeric(ll_full))
    lr_df <- length(coef_matrix) - length(coef(null_model))
    lr_pvalue <- pchisq(lr_stat, lr_df, lower.tail = FALSE)
  } else {
    mcfadden_r2 <- NA
    lr_stat <- NA
    lr_df <- NA
    lr_pvalue <- NA
  }

  aic <- AIC(model)

  # Get predicted probabilities and classes
  pred_probs <- predict(model, type = "probs")
  pred_class <- predict(model, type = "class")

  # Confusion matrix
  confusion <- table(Actual = data[[config$outcome_var]], Predicted = pred_class)
  accuracy <- sum(diag(confusion)) / sum(confusion)

  list(
    model = model,
    model_type = "multinomial_logistic",
    coefficients = coef_df,
    reference_outcome = ref_level,
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
    convergence = convergence_ok
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

  # Requires car package
  if (!requireNamespace("car", quietly = TRUE)) {
    return(list(
      checked = FALSE,
      message = "Package 'car' required for multicollinearity check"
    ))
  }

  vif_result <- tryCatch({
    vif_vals <- car::vif(model)

    # Handle factor variables (GVIF)
    if (is.matrix(vif_vals)) {
      # GVIF output
      df <- data.frame(
        variable = rownames(vif_vals),
        gvif = vif_vals[, "GVIF"],
        df = vif_vals[, "Df"],
        gvif_adj = vif_vals[, "GVIF^(1/(2*Df))"],
        stringsAsFactors = FALSE
      )
    } else {
      # Simple VIF
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

  # Assess multicollinearity
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
