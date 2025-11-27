# ==============================================================================
# CONJOINT ANALYSIS - MULTI-METHOD ESTIMATION
# ==============================================================================
#
# Module: Conjoint Analysis - Model Estimation
# Purpose: Estimate choice models using mlogit (primary) and clogit (fallback)
# Version: 2.0.0 (Enhanced Implementation)
# Date: 2025-11-26
#
# ==============================================================================

#' Estimate Choice Model
#'
#' Main estimation function with multi-method support
#' Primary: mlogit, Fallback: clogit, Optional: HB
#'
#' @param data_list Data list from load_conjoint_data()
#' @param config Configuration list
#' @param verbose Logical, print progress
#' @return List with model results
#' @export
estimate_choice_model <- function(data_list, config, verbose = TRUE) {

  data <- data_list$data
  method <- config$estimation_method

  log_verbose("Estimating choice model...", verbose)

  # Check analysis type
  if (config$analysis_type == "rating") {
    return(estimate_rating_based_conjoint(data_list, config, verbose))
  }

  # Choice-based conjoint
  if (method == "auto") {
    result <- estimate_auto_method(data, config, verbose)
  } else if (method == "mlogit") {
    result <- estimate_with_mlogit(data, config, verbose)
  } else if (method == "clogit") {
    result <- estimate_with_clogit(data, config, verbose)
  } else if (method == "hb") {
    stop(create_error(
      "ESTIMATION",
      "Hierarchical Bayes (HB) not yet implemented",
      "This is a Phase 2 feature. Use 'auto', 'mlogit', or 'clogit' for now."
    ), call. = FALSE)
  } else {
    stop(create_error(
      "ESTIMATION",
      sprintf("Unknown estimation method: %s", method),
      "Valid methods: auto, mlogit, clogit, hb"
    ), call. = FALSE)
  }

  result
}


#' Estimate with Auto Method Selection
#'
#' Tries mlogit first, falls back to clogit if needed
#'
#' @keywords internal
estimate_auto_method <- function(data, config, verbose = TRUE) {

  log_verbose("  → Method: auto (trying mlogit first)", verbose)

  # Try mlogit
  mlogit_result <- tryCatch({
    estimate_with_mlogit(data, config, verbose = FALSE)
  }, error = function(e) {
    list(success = FALSE, error = conditionMessage(e))
  })

  if (!inherits(mlogit_result, "list") || mlogit_result$success != FALSE) {
    log_verbose("  ✓ mlogit estimation successful", verbose)
    return(mlogit_result)
  }

  # mlogit failed, try clogit
  log_verbose("  ⚠ mlogit failed, trying clogit fallback...", verbose)
  log_verbose(sprintf("    mlogit error: %s", mlogit_result$error), verbose)

  clogit_result <- tryCatch({
    estimate_with_clogit(data, config, verbose = FALSE)
  }, error = function(e) {
    list(success = FALSE, error = conditionMessage(e))
  })

  if (!inherits(clogit_result, "list") || clogit_result$success != FALSE) {
    log_verbose("  ✓ clogit estimation successful", verbose)
    return(clogit_result)
  }

  # Both failed
  stop(create_error(
    "ESTIMATION",
    "All estimation methods failed",
    sprintf("mlogit error: %s\nclogit error: %s",
            mlogit_result$error, clogit_result$error),
    "Check your data quality. Run validate_conjoint_data() for diagnostics."
  ), call. = FALSE)
}


#' Estimate with mlogit
#'
#' Primary estimation method using mlogit package
#'
#' @keywords internal
estimate_with_mlogit <- function(data, config, verbose = TRUE) {

  # Check if mlogit is available
  if (!requireNamespace("mlogit", quietly = TRUE)) {
    stop(create_error(
      "ESTIMATION",
      "Package 'mlogit' not installed",
      "Install with: install.packages('mlogit')"
    ), call. = FALSE)
  }

  log_verbose("  → Preparing data for mlogit...", verbose)

  # Prepare data in mlogit format
  mlogit_data <- prepare_mlogit_data(data, config)

  # Build formula
  formula_obj <- build_mlogit_formula(config)

  log_verbose(sprintf("  → Formula: %s", deparse(formula_obj)), verbose)
  log_verbose("  → Fitting mlogit model...", verbose)

  # Fit model
  model <- tryCatch({
    mlogit::mlogit(
      formula = formula_obj,
      data = mlogit_data,
      method = "nr",  # Newton-Raphson
      print.level = 0
    )
  }, error = function(e) {
    stop(create_error(
      "ESTIMATION",
      sprintf("mlogit estimation failed: %s", conditionMessage(e)),
      "This may indicate perfect separation or other data quality issues.",
      "Try running with estimation_method = 'clogit' or check your data."
    ), call. = FALSE)
  })

  # Check convergence
  if (!is.null(model$convergence) && model$convergence != 0) {
    warning(create_warning(
      "ESTIMATION",
      sprintf("Model may not have converged properly (code: %d)", model$convergence),
      "Results should be interpreted with caution."
    ), call. = FALSE)
  }

  log_verbose("  ✓ Model estimation complete", verbose)

  # Extract results
  extract_mlogit_results(model, data, config)
}


#' Prepare Data for mlogit
#'
#' Converts data to mlogit format with proper indexing
#'
#' @keywords internal
prepare_mlogit_data <- function(data, config) {

  # mlogit needs data in "long" format with specific structure
  # Need to create index columns: chid (choice situation), alt (alternative)

  # Create alternative index if not present
  if (!config$alternative_id_column %in% names(data)) {
    data$alt <- ave(
      rep(1, nrow(data)),
      data[[config$choice_set_column]],
      FUN = seq_along
    )
  } else {
    data$alt <- data[[config$alternative_id_column]]
  }

  # Ensure choice set is numeric
  if (!is.numeric(data[[config$choice_set_column]])) {
    data$chid <- as.numeric(as.factor(data[[config$choice_set_column]]))
  } else {
    data$chid <- data[[config$choice_set_column]]
  }

  # Convert attributes to factors with correct reference level
  for (attr in config$attributes$AttributeName) {
    levels_vec <- get_attribute_levels(config, attr)

    # Set reference level based on baseline handling
    if (config$baseline_handling == "first_level_zero") {
      # First level is baseline
      data[[attr]] <- factor(data[[attr]], levels = levels_vec)
    } else {
      # All levels explicit
      data[[attr]] <- factor(data[[attr]], levels = levels_vec)
    }
  }

  # Create mlogit.data object
  mlogit_data <- mlogit::dfidx(
    data,
    choice = config$chosen_column,
    idx = list(c("chid", "alt")),
    drop.index = FALSE,
    ranked = FALSE
  )

  mlogit_data
}


#' Build mlogit Formula
#'
#' @keywords internal
build_mlogit_formula <- function(config) {

  # Build formula: choice ~ attribute1 + attribute2 + ... | 0
  # The | 0 means no individual-specific variables
  # The attributes are alternative-specific

  attr_terms <- paste(config$attributes$AttributeName, collapse = " + ")
  formula_str <- paste(config$chosen_column, "~", attr_terms, "| 0")

  as.formula(formula_str)
}


#' Extract mlogit Results
#'
#' @keywords internal
extract_mlogit_results <- function(model, data, config) {

  # Get coefficients
  coefs <- coef(model)
  vcov_matrix <- vcov(model)

  # Log-likelihoods
  ll_fitted <- logLik(model)
  ll_null <- model$logLik[1]  # Null log-likelihood

  # Sample info
  n_obs <- nrow(data)
  n_respondents <- length(unique(data[[config$respondent_id_column]]))
  n_choice_sets <- length(unique(data[[config$choice_set_column]]))

  # Convergence info
  convergence <- list(
    converged = is.null(model$convergence) || model$convergence == 0,
    code = model$convergence %||% 0,
    message = if (is.null(model$convergence) || model$convergence == 0) {
      "Successful convergence"
    } else {
      "Convergence issue detected"
    }
  )

  # Create standardized result
  structure(list(
    method = "mlogit",
    model = model,
    coefficients = coefs,
    vcov = vcov_matrix,
    std_errors = sqrt(diag(vcov_matrix)),
    loglik = c(null = as.numeric(ll_null), fitted = as.numeric(ll_fitted)),
    n_obs = n_obs,
    n_respondents = n_respondents,
    n_choice_sets = n_choice_sets,
    n_parameters = length(coefs),
    convergence = convergence,
    aic = AIC(model),
    bic = BIC(model)
  ), class = "turas_conjoint_model")
}


#' Estimate with clogit
#'
#' Fallback method using survival::clogit
#'
#' @keywords internal
estimate_with_clogit <- function(data, config, verbose = TRUE) {

  # Check if survival is available
  require_package("survival", "Package 'survival' required for clogit.\nInstall with: install.packages('survival')")

  log_verbose("  → Preparing data for clogit...", verbose)

  # Convert attributes to factors
  for (attr in config$attributes$AttributeName) {
    levels_vec <- get_attribute_levels(config, attr)
    data[[attr]] <- factor(data[[attr]], levels = levels_vec)
  }

  # Build formula
  attr_terms <- paste(config$attributes$AttributeName, collapse = " + ")
  formula_str <- paste(
    config$chosen_column, "~",
    attr_terms,
    "+ strata(", config$choice_set_column, ")"
  )
  formula_obj <- as.formula(formula_str)

  log_verbose(sprintf("  → Formula: %s", deparse(formula_obj)), verbose)
  log_verbose("  → Fitting clogit model...", verbose)

  # Fit model
  model <- tryCatch({
    survival::clogit(formula_obj, data = data)
  }, error = function(e) {
    stop(create_error(
      "ESTIMATION",
      sprintf("clogit estimation failed: %s", conditionMessage(e)),
      "Check your data for perfect separation or other quality issues."
    ), call. = FALSE)
  })

  log_verbose("  ✓ Model estimation complete", verbose)

  # Extract results
  extract_clogit_results(model, data, config)
}


#' Extract clogit Results
#'
#' @keywords internal
extract_clogit_results <- function(model, data, config) {

  # Get coefficients
  coefs <- coef(model)
  vcov_matrix <- vcov(model)

  # Check for NA coefficients
  if (any(is.na(coefs))) {
    warning(create_warning(
      "ESTIMATION",
      "Some coefficients could not be estimated (NA values)",
      "This may indicate perfect separation or multicollinearity."
    ), call. = FALSE)
  }

  # Log-likelihoods
  ll_fitted <- model$loglik[2]
  ll_null <- model$loglik[1]

  # Sample info
  n_obs <- nrow(data)
  n_respondents <- length(unique(data[[config$respondent_id_column]]))
  n_choice_sets <- length(unique(data[[config$choice_set_column]]))

  # Create standardized result
  structure(list(
    method = "clogit",
    model = model,
    coefficients = coefs,
    vcov = vcov_matrix,
    std_errors = sqrt(diag(vcov_matrix)),
    loglik = c(null = ll_null, fitted = ll_fitted),
    n_obs = n_obs,
    n_respondents = n_respondents,
    n_choice_sets = n_choice_sets,
    n_parameters = length(coefs),
    convergence = list(
      converged = TRUE,
      code = 0,
      message = "clogit convergence (check summary for warnings)"
    ),
    aic = AIC(model),
    bic = BIC(model)
  ), class = "turas_conjoint_model")
}


#' Estimate Rating-Based Conjoint
#'
#' OLS regression for rating-based designs
#'
#' @keywords internal
estimate_rating_based_conjoint <- function(data_list, config, verbose = TRUE) {

  data <- data_list$data

  log_verbose("  → Rating-based conjoint (OLS regression)", verbose)

  # Get rating variable
  rating_var <- config$rating_variable

  if (!rating_var %in% names(data)) {
    stop(create_error(
      "ESTIMATION",
      sprintf("Rating variable '%s' not found in data", rating_var),
      "Check the 'rating_variable' setting in your config file."
    ), call. = FALSE)
  }

  # Convert attributes to factors
  for (attr in config$attributes$AttributeName) {
    levels_vec <- get_attribute_levels(config, attr)
    data[[attr]] <- factor(data[[attr]], levels = levels_vec)
  }

  # Build formula
  attr_terms <- paste(config$attributes$AttributeName, collapse = " + ")
  formula_str <- paste(rating_var, "~", attr_terms)
  formula_obj <- as.formula(formula_str)

  log_verbose(sprintf("  → Formula: %s", deparse(formula_obj)), verbose)

  # Fit OLS model
  model <- lm(formula_obj, data = data)

  log_verbose("  ✓ Model estimation complete", verbose)

  # Extract results
  coefs <- coef(model)
  vcov_matrix <- vcov(model)

  structure(list(
    method = "ols_rating",
    model = model,
    coefficients = coefs,
    vcov = vcov_matrix,
    std_errors = sqrt(diag(vcov_matrix)),
    r_squared = summary(model)$r.squared,
    adj_r_squared = summary(model)$adj.r.squared,
    rmse = sqrt(mean(residuals(model)^2)),
    n_obs = nrow(data),
    n_parameters = length(coefs),
    convergence = list(
      converged = TRUE,
      code = 0,
      message = "OLS always converges"
    )
  ), class = "turas_conjoint_model")
}
