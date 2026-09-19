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
  fit_data <- data  # Local copy to avoid polluting caller's data with .wt column

  if (requireNamespace("ordinal", quietly = TRUE)) {
    model <- tryCatch({
      if (!is.null(weights) && length(weights) == nrow(data)) {
        if (!all(abs(weights - 1) < 1e-10)) {
          fit_data$.wt <- weights
          ordinal::clm(formula, data = fit_data, weights = .wt, link = "logit")
        } else {
          ordinal::clm(formula, data = fit_data, link = "logit")
        }
      } else {
        ordinal::clm(formula, data = fit_data, link = "logit")
      }
    }, error = function(e) {
      list(error = TRUE, message = e$message)
    })

    if (!is.list(model) || !isTRUE(model$error)) {
      # Check convergence
      if (!is.null(model$convergence) && isTRUE(model$convergence$code == 0)) {
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
      catdriver_refuse(
        reason = "PKG_MASS_MISSING",
        title = "REQUIRED PACKAGE MISSING",
        problem = "Package 'MASS' is required for ordinal logistic regression but is not installed.",
        why_it_matters = "The primary engine (ordinal::clm) is unavailable and the fallback (MASS::polr) requires the MASS package.",
        fix = "Install the package with: install.packages('MASS')"
      )
    }

    model <- tryCatch({
      if (!is.null(weights) && length(weights) == nrow(data)) {
        if (!all(abs(weights - 1) < 1e-10)) {
          fit_data$.wt <- weights
          # polr fits a binomial glm for starting values, so weighted runs raise
          # the same "non-integer #successes" warning as the binary engine.
          cd_muffle_noninteger_successes(
            MASS::polr(formula, data = fit_data, weights = .wt, Hess = TRUE, method = "logistic"))
        } else {
          MASS::polr(formula, data = fit_data, Hess = TRUE, method = "logistic")
        }
      } else {
        MASS::polr(formula, data = fit_data, Hess = TRUE, method = "logistic")
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

  # Predictor coefficients — use named indexing to ensure length alignment
  # (if a coefficient is aliased/dropped from vcov, %in% filtering can cause
  # a length mismatch between pred_coef and pred_se)
  pred_coef <- model$beta
  pred_se <- se_vals[names(pred_coef)]

  # Remove any coefficients without valid SEs (aliased due to collinearity)
  valid_mask <- !is.na(pred_se) & !is.na(pred_coef)
  if (sum(!valid_mask) > 0) {
    dropped <- names(pred_coef)[!valid_mask]
    cat("   [WARN] Dropped", length(dropped), "aliased coefficient(s):",
        paste(dropped, collapse = ", "), "\n")
    pred_coef <- pred_coef[valid_mask]
    pred_se <- pred_se[valid_mask]
  }

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

  # ===========================================================================
  # ODDS RATIO COMPUTATION - Proportional Odds Model Interpretation
  # ===========================================================================
  #
  # VERIFIED BEHAVIOR (via empirical testing):
  #   Both ordinal::clm and MASS::polr use the parameterization:
  #     logit(P(Y ≤ j)) = θ_j - X'β
  #
  #   Despite the minus sign in the formula, both implementations return β with:
  #     β > 0 when predictor → HIGHER outcome categories
  #     β < 0 when predictor → LOWER outcome categories
  #
  #   This is the STANDARD interpretation (same as for linear/logistic regression).
  #
  #   Therefore, for intuitive OR (OR > 1 = higher categories more likely):
  #     OR = exp(β)   [NO NEGATION NEEDED]
  #
  #   Verified: Treatment group with mean satisfaction 3.87 vs Control 2.22
  #   gives β = +2.44 (POSITIVE), and exp(β) = 11.5 correctly indicates
  #   Treatment → higher satisfaction.
  # ===========================================================================
  conf_level <- config$confidence_level
  z_crit <- qnorm(1 - (1 - conf_level) / 2)

  # OR for higher categories = exp(β) [standard interpretation]
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
  # The null model must be fitted on the SAME rows and with the SAME weights as
  # the full model. model$model holds the rows clm actually used and carries the
  # weights under the non-syntactic name "(weights)"; refitting without them
  # compared a weighted full model to an unweighted null and produced negative
  # McFadden R-squared values under PASS.
  null_model <- tryCatch({
    null_data <- model$model
    if ("(weights)" %in% names(null_data)) {
      null_data[["..catdriver_wt.."]] <- as.numeric(null_data[["(weights)"]])
      ordinal::clm(null_formula, data = null_data, weights = ..catdriver_wt.., link = "logit")
    } else {
      ordinal::clm(null_formula, data = null_data, link = "logit")
    }
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

  # Predicted probabilities, one column per outcome category.
  #
  # predict() on a clm WITHOUT newdata returns each respondent's probability of
  # the category they were actually observed in, which is a fit diagnostic and
  # not a probability of anything in particular. The probability lift then
  # averaged that by driver level and called the difference a lift. Passing the
  # estimation frame with the outcome column removed returns the full matrix,
  # named by category, which is what a lift needs. Verified by running both,
  # 2026-09-19.
  pred_probs <- tryCatch({
    newdata <- model$model
    newdata[[config$outcome_var]] <- NULL
    newdata[["(weights)"]] <- NULL
    fit <- predict(model, newdata = newdata, type = "prob")$fit
    if (is.null(dim(fit))) stop("clm returned no probability matrix")
    fit
  }, error = function(e) {
    cat(sprintf("   [INFO] Per-category probabilities unavailable (%s); probability lift will be skipped\n",
                conditionMessage(e)))
    NULL
  })

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
    # The comment here used to read "clm has built-in tests", and no test was
    # ever run: guard_check_proportional_odds() skips on NULL, so the default
    # engine's central assumption went unchecked while the docs implied it had
    # been checked. ordinal::nominal_test() is the built-in test; it is run now,
    # and when it cannot run the run says so rather than saying nothing.
    proportional_odds = test_proportional_odds_clm(model),
    predicted_probs = pred_probs,
    convergence = convergence_ok
  )
}


#' Test the Proportional Odds Assumption on a clm Fit
#'
#' Runs \code{ordinal::nominal_test()}, the likelihood-ratio test of whether
#' each predictor's effect is constant across the outcome thresholds. A small
#' p-value says the proportional-odds assumption does not hold for that
#' predictor, so its single odds ratio is describing thresholds that behave
#' differently.
#'
#' The test refits the model per predictor and can fail on sparse level
#' combinations. That is disclosed, never fatal: the result says the assumption
#' was not tested, which is what a reader needs to know.
#'
#' @param model A fitted \code{ordinal::clm} object.
#' @return List in the shape \code{guard_check_proportional_odds()} expects:
#'   checked, status, interpretation, plus the per-predictor p-values.
#' @keywords internal
test_proportional_odds_clm <- function(model) {

  if (!requireNamespace("ordinal", quietly = TRUE) ||
      !exists("nominal_test", where = asNamespace("ordinal"), mode = "function")) {
    return(list(
      checked = FALSE,
      status = "NOT_TESTED",
      method = "ordinal::nominal_test",
      interpretation = "Proportional odds assumption NOT tested: ordinal::nominal_test is unavailable."
    ))
  }

  # nominal_test() refits the model per predictor, and a refit re-evaluates the
  # original call in the FORMULA's environment. CatDriver builds its formulas in
  # the caller, so the engine's local fit frame is not visible there and the
  # refits come back empty: the test then reported "assumption holds" having
  # tested nothing. Refit here, from the model's own frame, with a formula whose
  # environment is this one, and test that.
  res <- tryCatch({
    mf <- model$model
    if (is.null(mf)) stop("the fitted model kept no model frame")
    link <- model$link %||% "logit"
    model_formula <- formula(model)
    w <- if ("(weights)" %in% names(mf)) as.numeric(mf[["(weights)"]]) else NULL

    # The data and the weights go into the call BY VALUE. nominal_test refits
    # per predictor with update(), which re-evaluates the call, and a call that
    # only names its data frame is re-evaluated wherever the formula came from:
    # the caller, where the engine's fit frame does not exist. The refits then
    # come back blank and the test would report that the assumption holds having
    # tested nothing. Verified both ways by running it, 2026-09-18.
    refit_call <- if (is.null(w)) {
      bquote(ordinal::clm(.(model_formula), data = .(mf), link = .(link)))
    } else {
      bquote(ordinal::clm(.(model_formula), data = .(mf), weights = .(w), link = .(link)))
    }
    ordinal::nominal_test(eval(refit_call))
  }, error = function(e) e)

  if (inherits(res, "error")) {
    return(list(
      checked = FALSE,
      status = "NOT_TESTED",
      method = "ordinal::nominal_test",
      interpretation = paste0(
        "Proportional odds assumption NOT tested: ordinal::nominal_test could not run (",
        conditionMessage(res), "). Read the odds ratios as an average across thresholds."
      )
    ))
  }

  res_df <- as.data.frame(res)
  p_col <- grep("^Pr", names(res_df), value = TRUE)
  if (length(p_col) == 0) {
    return(list(
      checked = FALSE,
      status = "NOT_TESTED",
      method = "ordinal::nominal_test",
      interpretation = "Proportional odds assumption NOT tested: nominal_test returned no p-values."
    ))
  }

  p_values <- res_df[[p_col[1]]]
  names(p_values) <- rownames(res_df)
  p_values <- p_values[!is.na(p_values)]

  if (length(p_values) == 0) {
    # Every per-predictor refit failed. Saying "the assumption holds" here would
    # be reporting a test that never ran.
    return(list(
      checked = FALSE,
      status = "NOT_TESTED",
      method = "ordinal::nominal_test",
      interpretation = paste0(
        "Proportional odds assumption NOT tested: ordinal::nominal_test returned no usable ",
        "p-values (the per-predictor refits did not converge). Read the odds ratios as an ",
        "average across thresholds."
      )
    ))
  }

  violations <- names(p_values)[p_values < 0.05]

  if (length(violations) > 0) {
    status <- "WARNING"
    interpretation <- paste0(
      "Proportional odds assumption is rejected for: ", paste(violations, collapse = ", "),
      " (ordinal::nominal_test, p < 0.05). Those drivers act differently at different points ",
      "of the scale, so a single odds ratio averages effects that are not the same. ",
      "Consider a multinomial model, or report those drivers threshold by threshold."
    )
  } else {
    status <- "PASS"
    interpretation <- paste0(
      "Proportional odds assumption holds (ordinal::nominal_test, smallest p = ",
      if (length(p_values) > 0) sprintf("%.3f", min(p_values)) else "n/a", ")."
    )
  }

  list(
    checked = TRUE,
    status = status,
    method = "ordinal::nominal_test",
    p_values = p_values,
    violations = violations,
    interpretation = interpretation
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
  # Use named indexing for robustness (positional indexing can break if
  # polr reorders parameters or drops aliased coefficients)
  pred_se <- se_vals[names(pred_coef)]

  # Remove any coefficients without valid SEs (aliased due to collinearity)
  valid_mask <- !is.na(pred_se) & !is.na(pred_coef)
  if (sum(!valid_mask) > 0) {
    dropped <- names(pred_coef)[!valid_mask]
    cat("   [WARN] Dropped", length(dropped), "aliased coefficient(s):",
        paste(dropped, collapse = ", "), "\n")
    pred_coef <- pred_coef[valid_mask]
    pred_se <- pred_se[valid_mask]
  }

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

  # Odds ratios - same STANDARD interpretation as clm (see detailed note above)
  # MASS::polr uses parameterization: logit(P(Y ≤ j)) = ζ_j - X'β
  # Despite the minus sign, polr returns β > 0 for predictors → higher outcomes
  # Therefore: OR = exp(β) [NO NEGATION]
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
  # Same rows, same weights as the full fit (see the clm path above).
  null_model <- tryCatch({
    null_data <- model$model
    if ("(weights)" %in% names(null_data)) {
      null_data[["..catdriver_wt.."]] <- as.numeric(null_data[["(weights)"]])
      MASS::polr(null_formula, data = null_data, weights = ..catdriver_wt..,
                 Hess = TRUE, method = "logistic")
    } else {
      MASS::polr(null_formula, data = null_data, Hess = TRUE, method = "logistic")
    }
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

  # NOTE: this is the polr fallback path's ad-hoc check (an odds-ratio ratio
  # across thresholds, not a test). Its per-threshold refits below do not carry
  # the study weights, so on a weighted study it describes the unweighted
  # sample; the interpretation string says so. The clm path, which is the
  # default engine, uses ordinal::nominal_test via test_proportional_odds_clm().
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

  unweighted_note <- " This heuristic compares odds ratios across thresholds on the UNWEIGHTED sample; it is not a statistical test."

  if (max_or_ratio < 1.25) {
    status <- "PASS"
    interpretation <- paste0("Proportional odds assumption appears reasonable (OR variation < 25% across thresholds).",
                             unweighted_note)
  } else if (max_or_ratio < 1.5) {
    status <- "MARGINAL"
    interpretation <- paste0("Proportional odds assumption is marginally met. Results are likely still valid.",
                             unweighted_note)
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


# verify_or_direction() was deleted 2026-09-18: deprecated, no callers.

