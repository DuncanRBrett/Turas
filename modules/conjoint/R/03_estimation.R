# ==============================================================================
# CONJOINT ANALYSIS - MULTI-METHOD ESTIMATION
# ==============================================================================
#
# Module: Conjoint Analysis - Model Estimation
# Purpose: Estimate choice models using mlogit (primary) and clogit (fallback)
# Version: 2.1.0 (Phase 1 - Alchemer Integration)
# Date: 2025-12-12
#
# ESTIMATION METHODS:
#   - mlogit: Primary engine, purpose-built for discrete choice analysis
#   - clogit: Fallback using survival::clogit (Cox regression workaround)
#   - auto: Try mlogit first, fall back to clogit if needed
#
# WHY MLOGIT OVER CLOGIT:
#   - Purpose-built for discrete choice analysis
#   - Native support for panel data structure
#   - Better diagnostics and hypothesis testing
#   - Industry standard in academic/commercial conjoint software
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
    conjoint_refuse(
      code = "EST_HB_NOT_IMPLEMENTED",
      title = "Hierarchical Bayes Not Implemented",
      problem = "Hierarchical Bayes (HB) estimation is not yet implemented.",
      why_it_matters = "HB provides individual-level utilities but requires complex MCMC estimation.",
      how_to_fix = c(
        "This is a Phase 2 feature",
        "Use 'auto', 'mlogit', or 'clogit' for now",
        "OR see modules/conjoint/R/11_hierarchical_bayes.R for framework"
      )
    )
  } else {
    conjoint_refuse(
      code = "EST_INVALID_METHOD",
      title = "Unknown Estimation Method",
      problem = sprintf("Unknown estimation method: %s", method),
      why_it_matters = "Only specific estimation methods are supported for conjoint analysis.",
      how_to_fix = c(
        "Valid methods: auto, mlogit, clogit, hb",
        "Set 'estimation_method' in your configuration",
        sprintf("You specified: %s", method)
      )
    )
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
  # Always print the mlogit error so user can diagnose
  message(sprintf("    mlogit error: %s", mlogit_result$error))

  clogit_result <- tryCatch({
    estimate_with_clogit(data, config, verbose = FALSE)
  }, error = function(e) {
    list(success = FALSE, error = conditionMessage(e))
  })

  if (!inherits(clogit_result, "list") || clogit_result$success != FALSE) {
    # TRS PARTIAL: Fallback estimator used
    message(sprintf("[TRS PARTIAL] CONJ_MLOGIT_FALLBACK: mlogit failed, using clogit fallback (original error: %s)",
                    mlogit_result$error))
    log_verbose("  ✓ clogit estimation successful", verbose)
    return(clogit_result)
  }

  # Both failed
  conjoint_refuse(
    code = "EST_ALL_METHODS_FAILED",
    title = "All Estimation Methods Failed",
    problem = "Both mlogit and clogit estimation failed.",
    why_it_matters = "Cannot complete analysis without a successful model estimation.",
    how_to_fix = c(
      "Check your data quality - run validate_conjoint_data() for diagnostics",
      sprintf("mlogit error: %s", mlogit_result$error),
      sprintf("clogit error: %s", clogit_result$error),
      "Common causes: perfect separation, missing data, or insufficient variation"
    )
  )
}


#' Estimate with mlogit
#'
#' Primary estimation method using mlogit package
#'
#' @keywords internal
estimate_with_mlogit <- function(data, config, verbose = TRUE) {

  # Check if mlogit and dfidx are available
  if (!requireNamespace("mlogit", quietly = TRUE)) {
    conjoint_refuse(
      code = "PKG_MLOGIT_MISSING",
      title = "Required Package Not Installed",
      problem = "Package 'mlogit' is not installed.",
      why_it_matters = "mlogit is the primary estimation engine for discrete choice models in conjoint analysis.",
      how_to_fix = "Install with: install.packages('mlogit')"
    )
  }

  if (!requireNamespace("dfidx", quietly = TRUE)) {
    conjoint_refuse(
      code = "PKG_DFIDX_MISSING",
      title = "Required Package Not Installed",
      problem = "Package 'dfidx' is not installed (required by mlogit).",
      why_it_matters = "dfidx provides the data structure required for mlogit estimation.",
      how_to_fix = "Install with: install.packages('dfidx')"
    )
  }

  log_verbose("  → Preparing data for mlogit...", verbose)

  # Prepare data in mlogit format
  mlogit_data <- prepare_mlogit_data(data, config)

  # Debug: show data structure
  n_choice_sets <- length(unique(paste(data[[config$respondent_id_column]],
                                       data[[config$choice_set_column]], sep = "_")))
  log_verbose(sprintf("  → Data has %d rows, %d choice sets", nrow(data), n_choice_sets), verbose)

  # Build formula
  formula_obj <- build_mlogit_formula(config)

  log_verbose(sprintf("  → Formula: %s", deparse(formula_obj)), verbose)

  # Verify all formula variables exist in data
  attr_names <- config$attributes$AttributeName
  missing_cols <- attr_names[!attr_names %in% names(data)]
  if (length(missing_cols) > 0) {
    conjoint_refuse(
      code = "EST_MISSING_ATTRIBUTES",
      title = "Attributes Missing From Data",
      problem = sprintf("Attributes missing from data: %s", paste(missing_cols, collapse = ", ")),
      why_it_matters = "All attributes defined in configuration must exist as columns in the data for estimation.",
      how_to_fix = c(
        "Check that attribute names in config match column names in data exactly (case-sensitive)",
        sprintf("Missing: %s", paste(missing_cols, collapse = ", ")),
        sprintf("Available in data: %s", paste(names(data), collapse = ", "))
      )
    )
  }

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
    conjoint_refuse(
      code = "EST_MLOGIT_FAILED",
      title = "mlogit Estimation Failed",
      problem = sprintf("mlogit estimation failed: %s", conditionMessage(e)),
      why_it_matters = "Model estimation failed, preventing calculation of part-worth utilities.",
      how_to_fix = c(
        "This may indicate perfect separation or other data quality issues",
        "Try running with estimation_method = 'clogit' in your config",
        "OR check your data for: perfect separation, insufficient variation, or missing values",
        "Run validate_conjoint_data() for detailed diagnostics"
      )
    )
  })

  # Check convergence
  if (!is.null(model$convergence) && model$convergence != 0) {
    message(sprintf(
      "[TRS INFO] CONJ_CONVERGENCE_WARNING: Model may not have converged properly (code: %d) - results should be interpreted with caution",
      model$convergence
    ))
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

  # Create alternative index if not present - MUST be numeric for dfidx
  if (!config$alternative_id_column %in% names(data)) {
    data$alt <- ave(
      rep(1, nrow(data)),
      data[[config$choice_set_column]],
      FUN = seq_along
    )
  } else {
    # Convert to numeric if character (e.g., "1", "2", "3" or "Card1", "Card2")
    alt_vals <- data[[config$alternative_id_column]]
    if (is.character(alt_vals) || is.factor(alt_vals)) {
      # Try numeric conversion first, fall back to factor->numeric
      numeric_vals <- suppressWarnings(as.numeric(as.character(alt_vals)))
      if (any(is.na(numeric_vals) & !is.na(alt_vals))) {
        # Has non-numeric values, use factor encoding
        data$alt <- as.numeric(as.factor(alt_vals))
      } else {
        data$alt <- numeric_vals
      }
    } else {
      data$alt <- as.numeric(alt_vals)
    }
  }

  # Ensure alt has no NAs
  if (any(is.na(data$alt))) {
    conjoint_refuse(
      code = "EST_MISSING_ALT_IDS",
      title = "Alternative IDs Contain Missing Values",
      problem = "Alternative IDs (alt column) contain NA values.",
      why_it_matters = "mlogit requires valid alternative identifiers for each choice option.",
      how_to_fix = c(
        "Check your data for NA values in the alternative_id column",
        "Ensure every row has a valid alternative identifier",
        "OR set alternative_id_column in config if using a different column"
      )
    )
  }

  # Create unique choice set ID combining respondent and choice_set
  # This ensures (chid, alt) is unique across all observations
  # Required for mlogit's dfidx when multiple respondents have same choice_set_id
  data$chid <- as.numeric(as.factor(
    paste(data[[config$respondent_id_column]],
          data[[config$choice_set_column]],
          sep = "_")
  ))

  # Convert attributes to factors with correct reference level
  for (attr in config$attributes$AttributeName) {
    levels_vec <- get_attribute_levels(config, attr)

    # Convert to factor with specified level order
    # First level becomes baseline (reference) for effect coding
    data[[attr]] <- factor(data[[attr]], levels = levels_vec)
  }

  # Create mlogit.data object using dfidx package
  # Note: dfidx was moved to separate package in mlogit >= 1.1-0
  # idx: first column is choice set (chid), second is alternative (alt)
  mlogit_data <- tryCatch({
    dfidx::dfidx(
      data,
      choice = config$chosen_column,
      idx = c("chid", "alt"),
      drop.index = FALSE,
      ranked = FALSE
    )
  }, error = function(e) {
    conjoint_refuse(
      code = "EST_MLOGIT_DATA_STRUCTURE_FAILED",
      title = "Failed to Create mlogit Data Structure",
      problem = sprintf("Failed to create mlogit data structure: %s", conditionMessage(e)),
      why_it_matters = "mlogit requires a specific data format with unique (choice_id, alternative_id) combinations.",
      how_to_fix = c(
        "This usually means (chid, alt) combinations are not unique",
        "Check that each choice set has unique alternative IDs",
        "Verify your data has proper choice_set_id and alternative_id columns",
        "Ensure no duplicate rows within the same choice set"
      )
    )
  })

  mlogit_data
}


#' Build mlogit Formula
#'
#' @keywords internal
build_mlogit_formula <- function(config) {

  # Validate inputs

  if (is.null(config$attributes$AttributeName) || length(config$attributes$AttributeName) == 0) {
    conjoint_refuse(
      code = "EST_NO_ATTRIBUTES",
      title = "No Attributes Found",
      problem = "No attributes found in configuration.",
      why_it_matters = "Conjoint analysis requires attributes to estimate utilities.",
      how_to_fix = c(
        "Check that your configuration has attributes defined in the Attributes sheet",
        "Ensure the Attributes sheet has at least one row with AttributeName, NumLevels, and LevelNames"
      )
    )
  }

  if (is.null(config$chosen_column) || nchar(config$chosen_column) == 0) {
    conjoint_refuse(
      code = "EST_CHOSEN_COLUMN_MISSING",
      title = "Chosen Column Not Specified",
      problem = "chosen_column not specified in configuration.",
      why_it_matters = "The chosen column indicates which alternative was selected in each choice set.",
      how_to_fix = c(
        "Check your configuration settings",
        "Set 'chosen_column' in the Settings sheet (typically 'chosen' or 'selected')"
      )
    )
  }

  # Build formula: choice ~ attribute1 + attribute2 + ... | 0
  # The | 0 means no individual-specific variables
  # The attributes are alternative-specific

  # Escape attribute names with special characters using backticks
  # e.g., "I+G" becomes "`I+G`" to prevent formula parsing issues
  escaped_attrs <- sapply(config$attributes$AttributeName, function(attr) {
    if (grepl("[^a-zA-Z0-9_.]", attr)) {
      paste0("`", attr, "`")
    } else {
      attr
    }
  })

  attr_terms <- paste(escaped_attrs, collapse = " + ")
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
  ll_fitted <- as.numeric(logLik(model))

  # Extract null log-likelihood from mlogit model
  # In mlogit, this is stored in model$logLik with name "null"
  if (!is.null(attr(logLik(model), "null"))) {
    ll_null <- attr(logLik(model), "null")
  } else if (!is.null(model$logLik.null)) {
    ll_null <- model$logLik.null
  } else {
    # Fallback: try to get it from the model summary
    ll_null <- tryCatch({
      summary(model)$logLik["null"]
    }, error = function(e) {
      # Last resort: estimate null model
      message("[TRS INFO] CONJ_NULL_LL_ESTIMATED: Could not extract null log-likelihood - estimating from null model")
      null_formula <- as.formula(paste(config$chosen_column, "~ 1"))
      null_model <- mlogit::mlogit(null_formula, data = data)
      as.numeric(logLik(null_model))
    })
  }

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

  # Build formula with escaped attribute names
  # Escape attribute names with special characters using backticks
  escaped_attrs <- sapply(config$attributes$AttributeName, function(attr) {
    if (grepl("[^a-zA-Z0-9_.]", attr)) {
      paste0("`", attr, "`")
    } else {
      attr
    }
  })

  attr_terms <- paste(escaped_attrs, collapse = " + ")
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
    conjoint_refuse(
      code = "EST_CLOGIT_FAILED",
      title = "clogit Estimation Failed",
      problem = sprintf("clogit estimation failed: %s", conditionMessage(e)),
      why_it_matters = "Fallback estimation method failed, preventing calculation of part-worth utilities.",
      how_to_fix = c(
        "Check your data for perfect separation or other quality issues",
        "Verify data has sufficient variation in choices",
        "Run validate_conjoint_data() for detailed diagnostics",
        "Common causes: all respondents choosing the same levels, or insufficient sample size"
      )
    )
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
    message("[TRS INFO] CONJ_NA_COEFFICIENTS: Some coefficients could not be estimated (NA values) - this may indicate perfect separation or multicollinearity")
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
    conjoint_refuse(
      code = "EST_RATING_VAR_MISSING",
      title = "Rating Variable Not Found",
      problem = sprintf("Rating variable '%s' not found in data", rating_var),
      why_it_matters = "Rating-based conjoint requires a rating column with numeric preference scores.",
      how_to_fix = c(
        "Check the 'rating_variable' setting in your config file",
        sprintf("Expected column: %s", rating_var),
        sprintf("Available columns: %s", paste(names(data), collapse = ", "))
      )
    )
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
