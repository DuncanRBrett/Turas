# ==============================================================================
# CATEGORICAL KEY DRIVER - CORE ANALYSIS
# ==============================================================================
#
# Binary, ordinal, and multinomial logistic regression implementations
# with robust estimation and automatic fallback.
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
      # No fallback available - continue with original model if it exists
      if (is.list(model) && isTRUE(model$error)) {
        guard_model_fit_success(model, fallback_available = FALSE)
      }
      # Otherwise use original model with warnings
      warning("Separation detected but brglm2 package not available for Firth fallback. ",
              "Consider installing brglm2.")
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


# ==============================================================================
# ORDINAL LOGISTIC REGRESSION (with fallback)
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


# ==============================================================================
# MULTINOMIAL LOGISTIC REGRESSION
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
    stop("Package 'nnet' required for multinomial logistic regression", call. = FALSE)
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
    stop("Invalid multinomial_mode: '", multinomial_mode, "'\n",
         "Must be one of: ", paste(valid_modes, collapse = ", "),
         call. = FALSE)
  }

  # For one_vs_all mode, require target_outcome_level
  target_outcome_level <- config$target_outcome_level
  if (multinomial_mode == "one_vs_all") {
    if (is.null(target_outcome_level) || is.na(target_outcome_level)) {
      stop("HARD ERROR: multinomial_mode='one_vs_all' requires target_outcome_level.\n",
           "Specify which outcome level to treat as 'success' in the config.",
           call. = FALSE)
    }

    # Validate target level exists in data
    outcome_levels <- levels(data[[config$outcome_var]])
    if (!target_outcome_level %in% outcome_levels) {
      stop("HARD ERROR: target_outcome_level='", target_outcome_level,
           "' not found in outcome.\n",
           "Available levels: ", paste(outcome_levels, collapse = ", "),
           call. = FALSE)
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
