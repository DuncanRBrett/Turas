# ==============================================================================
# TURAS KEY DRIVER - BOOTSTRAP CONFIDENCE INTERVALS
# ==============================================================================
#
# Purpose: Calculate bootstrap CIs for driver importance scores
# Version: Turas v10.1
# Date: 2025-12
#
# Provides percentile-based bootstrap confidence intervals on driver
# importance scores (correlation, beta weight, relative weight).
# Supports weighted resampling when case weights are available.
#
# ==============================================================================


# ------------------------------------------------------------------------------
# Main Bootstrap Entry Point
# ------------------------------------------------------------------------------

#' Bootstrap Confidence Intervals for Driver Importance
#'
#' Resamples respondent data with replacement and recalculates driver
#' importance scores on each resample. Returns percentile-based
#' confidence intervals, standard errors, and point estimates for
#' each driver-method combination.
#'
#' Three importance methods are bootstrapped:
#' \itemize{
#'   \item \strong{Correlation}: Pearson correlation between driver and outcome
#'   \item \strong{Beta_Weight}: Standardized regression coefficient (|beta| share)
#'   \item \strong{Relative_Weight}: Johnson's relative weight decomposition of R-squared
#' }
#'
#' Config fields (all optional, with defaults):
#' \itemize{
#'   \item \code{enable_bootstrap} - logical, default FALSE
#'   \item \code{bootstrap_iterations} - integer, default 1000
#'   \item \code{bootstrap_ci_level} - numeric 0-1, default 0.95
#' }
#'
#' @param data A data.frame containing the outcome and driver columns.
#'   Must have at least 30 complete cases across outcome + drivers.
#' @param outcome Character string naming the outcome (dependent) variable.
#' @param drivers Character vector of driver (independent) variable names.
#' @param weights Optional character string naming a case-weight column,
#'   or NULL for unweighted analysis. When provided, bootstrap resampling
#'   draws rows proportional to their weights.
#' @param config Optional list of configuration overrides. Recognised fields:
#'   \code{enable_bootstrap}, \code{bootstrap_iterations}, \code{bootstrap_ci_level}.
#' @param n_bootstrap Number of bootstrap iterations (default 1000).
#'   Overridden by \code{config$bootstrap_iterations} when present.
#' @param ci_level Confidence level for the interval, e.g. 0.95 for a 95
#'   percent CI. Overridden by \code{config$bootstrap_ci_level} when present.
#'
#' @return A data.frame with one row per driver-method combination and columns:
#'   \describe{
#'     \item{Driver}{Driver variable name}
#'     \item{Method}{Importance method (Correlation, Beta_Weight, Relative_Weight)}
#'     \item{Point_Estimate}{Mean of bootstrap distribution}
#'     \item{CI_Lower}{Lower percentile bound}
#'     \item{CI_Upper}{Upper percentile bound}
#'     \item{SE}{Standard error (SD of bootstrap distribution)}
#'   }
#'   Returns a TRS refusal list if inputs are invalid.
#'
#' @examples
#' \dontrun{
#'   ci_results <- bootstrap_importance_ci(
#'     data = survey_data,
#'     outcome = "overall_satisfaction",
#'     drivers = c("price", "quality", "service"),
#'     n_bootstrap = 500,
#'     ci_level = 0.95
#'   )
#'   print(ci_results)
#' }
#'
#' @export
bootstrap_importance_ci <- function(data,
                                    outcome,
                                    drivers,
                                    weights = NULL,
                                    config = list(),
                                    n_bootstrap = 1000,
                                    ci_level = 0.95) {


  # ------------------------------------------------------------------
  # Resolve config overrides
  # ------------------------------------------------------------------
  n_bootstrap <- config$bootstrap_iterations %||% n_bootstrap
  ci_level    <- config$bootstrap_ci_level    %||% ci_level
  n_bootstrap <- as.integer(n_bootstrap)

  # ------------------------------------------------------------------
  # Input validation (TRS refusals, never stop())
  # ------------------------------------------------------------------
  if (!is.data.frame(data)) {
    return(keydriver_refuse(
      code   = "DATA_INVALID",
      title  = "Invalid Data Argument",
      problem = "'data' must be a data.frame.",
      why_it_matters = "Bootstrap resampling requires a rectangular data frame.",
      how_to_fix = "Pass a valid data.frame to the 'data' parameter."
    ))
  }

  if (!is.character(outcome) || length(outcome) != 1 || !nzchar(outcome)) {
    return(keydriver_refuse(
      code   = "CFG_OUTCOME_MISSING",
      title  = "Invalid Outcome Variable",
      problem = "'outcome' must be a single non-empty character string.",
      why_it_matters = "The bootstrap needs to know which column is the dependent variable.",
      how_to_fix = "Pass the outcome column name as a length-1 character string."
    ))
  }

  if (!is.character(drivers) || length(drivers) < 2) {
    return(keydriver_refuse(
      code   = "CFG_INSUFFICIENT_DRIVERS",
      title  = "Insufficient Driver Variables",
      problem = paste0("'drivers' must be a character vector with at least 2 elements (got ",
                       length(drivers), ")."),
      why_it_matters = "Key driver analysis compares relative importance across multiple drivers.",
      how_to_fix = "Supply at least 2 driver variable names."
    ))
  }

  # Check columns exist in data
  all_vars <- c(outcome, drivers)
  missing_vars <- setdiff(all_vars, names(data))
  if (length(missing_vars) > 0) {
    return(keydriver_refuse(
      code   = "DATA_DRIVERS_NOT_FOUND",
      title  = "Variables Not Found in Data",
      problem = paste0(length(missing_vars), " variable(s) not found: ",
                       paste(missing_vars, collapse = ", ")),
      why_it_matters = "Cannot compute importance for variables that are not in the data.",
      how_to_fix = "Check that outcome and driver names match column names exactly (case-sensitive).",
      expected = all_vars,
      observed = names(data),
      missing  = missing_vars
    ))
  }

  # Check weight column if supplied
  if (!is.null(weights)) {
    if (!is.character(weights) || length(weights) != 1) {
      return(keydriver_refuse(
        code   = "CFG_WEIGHT_INVALID",
        title  = "Invalid Weight Parameter",
        problem = "'weights' must be a single character string naming the weight column, or NULL.",
        why_it_matters = "Weighted resampling requires a valid column reference.",
        how_to_fix = "Pass the weight column name as a length-1 character, or NULL for unweighted."
      ))
    }
    if (!weights %in% names(data)) {
      return(keydriver_refuse(
        code   = "DATA_WEIGHT_NOT_FOUND",
        title  = "Weight Variable Not Found",
        problem = paste0("Weight variable '", weights, "' not found in data."),
        why_it_matters = "Cannot apply weighted resampling without the weight column.",
        how_to_fix = "Check that the weight column name matches exactly, or set weights = NULL.",
        expected = weights,
        observed = names(data)
      ))
    }
  }

  # Validate numeric types for all analysis variables
  cols_to_check <- if (!is.null(weights)) c(all_vars, weights) else all_vars
  for (col in cols_to_check) {
    if (!is.numeric(data[[col]])) {
      return(keydriver_refuse(
        code   = "DATA_INVALID",
        title  = "Non-Numeric Variable",
        problem = paste0("Column '", col, "' is not numeric (class: ",
                         paste(class(data[[col]]), collapse = "/"), ")."),
        why_it_matters = "Bootstrap importance requires numeric outcome, drivers, and weights.",
        how_to_fix = paste0("Convert '", col, "' to numeric before calling bootstrap_importance_ci().")
      ))
    }
  }

  # Subset to complete cases
  subset_cols <- if (!is.null(weights)) c(all_vars, weights) else all_vars
  complete_mask <- complete.cases(data[, subset_cols, drop = FALSE])
  n_complete <- sum(complete_mask)
  min_n <- max(30L, 10L * length(drivers))

  if (n_complete < min_n) {
    return(keydriver_refuse(
      code   = "DATA_INSUFFICIENT_SAMPLE",
      title  = "Insufficient Sample Size for Bootstrap",
      problem = sprintf("Only %d complete cases available. Need at least %d for %d drivers.",
                        n_complete, min_n, length(drivers)),
      why_it_matters = "Bootstrap CIs are unreliable with very small samples.",
      how_to_fix = c(
        "Increase sample size or reduce number of drivers",
        sprintf("Rule: need at least 10 cases per driver, minimum 30 (have %d)", n_complete)
      )
    ))
  }

  data <- data[complete_mask, , drop = FALSE]

  # Validate bootstrap parameters
  if (!is.numeric(n_bootstrap) || n_bootstrap < 100) {
    return(keydriver_refuse(
      code   = "CFG_BOOTSTRAP_ITERATIONS",
      title  = "Invalid Bootstrap Iterations",
      problem = sprintf("n_bootstrap must be an integer >= 100 (got %s).", as.character(n_bootstrap)),
      why_it_matters = "Too few iterations produce unstable confidence intervals.",
      how_to_fix = "Set n_bootstrap to at least 100. Recommended: 1000."
    ))
  }

  if (!is.numeric(ci_level) || ci_level <= 0 || ci_level >= 1) {
    return(keydriver_refuse(
      code   = "CFG_BOOTSTRAP_CI_LEVEL",
      title  = "Invalid Confidence Level",
      problem = sprintf("ci_level must be between 0 and 1 exclusive (got %s).", as.character(ci_level)),
      why_it_matters = "Confidence level defines the width of the interval.",
      how_to_fix = "Set ci_level to a value like 0.90, 0.95, or 0.99."
    ))
  }

  # ------------------------------------------------------------------
  # Console output
  # ------------------------------------------------------------------
  cat("\n  Bootstrap CI Analysis\n")
  cat(sprintf("  - Running %d bootstrap iterations...\n", n_bootstrap))

  # ------------------------------------------------------------------
  # Build weight probability vector (or NULL for uniform)
  # ------------------------------------------------------------------
  w_prob <- NULL
  if (!is.null(weights)) {
    w_vec <- data[[weights]]
    w_vec[w_vec < 0] <- 0
    w_sum <- sum(w_vec)
    if (w_sum <= 0) {
      return(keydriver_refuse(
        code   = "DATA_WEIGHTS_ZERO",
        title  = "All Weights Are Zero or Negative",
        problem = "Sum of weights is zero or negative after clamping negatives.",
        why_it_matters = "Cannot perform weighted resampling when no observation has positive weight.",
        how_to_fix = "Check your weight variable for valid positive values."
      ))
    }
    w_prob <- w_vec / w_sum
  }

  # ------------------------------------------------------------------
  # Run bootstrap iterations
  # ------------------------------------------------------------------
  n_drivers <- length(drivers)
  n_obs     <- nrow(data)

  # Pre-allocate matrices: rows = iterations, cols = drivers
  # Three methods: correlation, beta_weight, relative_weight
  boot_correlation    <- matrix(NA_real_, nrow = n_bootstrap, ncol = n_drivers,
                                dimnames = list(NULL, drivers))
  boot_beta_weight    <- matrix(NA_real_, nrow = n_bootstrap, ncol = n_drivers,
                                dimnames = list(NULL, drivers))
  boot_relative_weight <- matrix(NA_real_, nrow = n_bootstrap, ncol = n_drivers,
                                 dimnames = list(NULL, drivers))

  n_failed <- 0L


  for (b in seq_len(n_bootstrap)) {
    # Draw resample indices
    idx <- sample.int(n_obs, size = n_obs, replace = TRUE, prob = w_prob)
    boot_data <- data[idx, , drop = FALSE]

    # Calculate importance on this resample
    result <- calculate_single_bootstrap(boot_data, outcome, drivers, weights)

    if (is.null(result)) {
      n_failed <- n_failed + 1L
      next
    }

    boot_correlation[b, ]     <- result$correlation
    boot_beta_weight[b, ]     <- result$beta_weight
    boot_relative_weight[b, ] <- result$relative_weight
  }

  # Warn if many failures
  if (n_failed > 0) {
    pct_failed <- round(100 * n_failed / n_bootstrap, 1)
    cat(sprintf("  - [WARN] %d of %d iterations failed (%.1f%%)\n",
                n_failed, n_bootstrap, pct_failed))
  }

  if (n_failed >= n_bootstrap) {
    return(keydriver_refuse(
      code   = "CALC_BOOTSTRAP_ALL_FAILED",
      title  = "All Bootstrap Iterations Failed",
      problem = "Every bootstrap resample failed to produce valid importance scores.",
      why_it_matters = "Cannot compute confidence intervals without any successful resamples.",
      how_to_fix = c(
        "Check that your data supports linear regression (sufficient variance, no perfect collinearity)",
        "Try reducing the number of drivers"
      )
    ))
  }

  # ------------------------------------------------------------------
  # Summarize bootstrap distributions
  # ------------------------------------------------------------------
  cat(sprintf("  - Calculating confidence intervals (%s%%)...\n",
              format(100 * ci_level, nsmall = 0)))

  ci_correlation     <- summarize_bootstrap_results(boot_correlation,     ci_level)
  ci_beta_weight     <- summarize_bootstrap_results(boot_beta_weight,     ci_level)
  ci_relative_weight <- summarize_bootstrap_results(boot_relative_weight, ci_level)

  # Tag with method names
  ci_correlation$Method     <- "Correlation"
  ci_beta_weight$Method     <- "Beta_Weight"
  ci_relative_weight$Method <- "Relative_Weight"

  # Combine into single tidy result
  result_df <- rbind(ci_correlation, ci_beta_weight, ci_relative_weight)
  result_df <- result_df[, c("Driver", "Method", "Point_Estimate",
                             "CI_Lower", "CI_Upper", "SE")]
  rownames(result_df) <- NULL

  cat(sprintf("  - Bootstrap complete: %d drivers analyzed\n", n_drivers))

  result_df
}


# ------------------------------------------------------------------------------
# Single Bootstrap Iteration Helper
# ------------------------------------------------------------------------------

#' Calculate Importance Scores for a Single Bootstrap Resample
#'
#' Fits a linear model to one resampled data set and extracts three
#' types of importance: correlation, beta weight share, and relative
#' weight.
#'
#' This is an internal helper called once per bootstrap iteration.
#' It is deliberately minimal (no console output, no TRS refusals)
#' to keep per-iteration overhead low.
#'
#' @param data A data.frame (one bootstrap resample).
#' @param outcome Character string naming the outcome variable.
#' @param drivers Character vector of driver variable names.
#' @param weights Character string naming the weight column, or NULL.
#'
#' @return A list with named numeric vectors \code{$correlation},
#'   \code{$beta_weight}, and \code{$relative_weight}, each of
#'   length equal to \code{length(drivers)}. Returns NULL if the
#'   model cannot be fit (e.g. singular design).
#'
#' @keywords internal
calculate_single_bootstrap <- function(data, outcome, drivers, weights) {

  n_drivers <- length(drivers)
  y <- data[[outcome]]

  # ----- Correlation -----
  cor_vals <- vapply(drivers, function(d) {
    x <- data[[d]]
    if (sd(x, na.rm = TRUE) == 0 || sd(y, na.rm = TRUE) == 0) return(NA_real_)
    stats::cor(x, y, use = "complete.obs")
  }, numeric(1))

  # ----- Fit linear model -----
  formula_str <- paste(outcome, "~", paste(drivers, collapse = " + "))
  model_formula <- stats::as.formula(formula_str)

  model <- tryCatch({
    if (!is.null(weights)) {
      stats::lm(model_formula, data = data, weights = data[[weights]])
    } else {
      stats::lm(model_formula, data = data)
    }
  }, error = function(e) NULL)

  if (is.null(model)) return(NULL)

  # Check for aliased coefficients
  coefs <- stats::coef(model)[drivers]
  if (any(is.na(coefs))) return(NULL)

  # ----- Beta Weights (|standardized beta| shares) -----
  sd_y <- sd(y, na.rm = TRUE)
  if (sd_y == 0) return(NULL)

  sd_x <- vapply(drivers, function(d) sd(data[[d]], na.rm = TRUE), numeric(1))
  if (any(sd_x == 0)) return(NULL)

  beta_std   <- coefs * (sd_x / sd_y)
  sum_abs    <- sum(abs(beta_std))
  beta_pct   <- if (sum_abs > 0) (abs(beta_std) / sum_abs) * 100 else rep(0, n_drivers)
  names(beta_pct) <- drivers

  # ----- Relative Weights (Johnson's method) -----
  R_xx <- stats::cor(data[, drivers, drop = FALSE], use = "pairwise.complete.obs")
  r_xy <- vapply(drivers, function(d) {
    stats::cor(data[[d]], y, use = "complete.obs")
  }, numeric(1))

  eig  <- eigen(R_xx, symmetric = TRUE)
  vals <- eig$values
  vecs <- eig$vectors
  vals[vals < 0] <- 0

  # If near-singular, return NULL for this iteration

  if (any(vals < 1e-10)) return(NULL)

  p <- n_drivers
  Lambda_sqrt     <- diag(sqrt(vals),     nrow = p, ncol = p)
  Lambda_inv_sqrt <- diag(1 / sqrt(vals), nrow = p, ncol = p)

  Phi     <- vecs %*% Lambda_sqrt
  r_z_y   <- Lambda_inv_sqrt %*% t(vecs) %*% r_xy
  r2_z_y  <- as.numeric(r_z_y)^2

  rw_raw <- as.numeric(Phi^2 %*% r2_z_y)

  # Rescale to model R-squared
  model_R2 <- summary(model)$r.squared
  if (!is.na(model_R2) && model_R2 > 0 && sum(rw_raw) > 0) {
    rw_raw <- rw_raw * (model_R2 / sum(rw_raw))
  }

  # Convert to percentages
  sum_rw <- sum(rw_raw)
  rw_pct <- if (sum_rw > 0) (rw_raw / sum_rw) * 100 else rep(0, p)
  names(rw_pct) <- drivers

  list(
    correlation    = cor_vals,
    beta_weight    = beta_pct,
    relative_weight = rw_pct
  )
}


# ------------------------------------------------------------------------------
# Bootstrap Summary
# ------------------------------------------------------------------------------

#' Summarize Bootstrap Results into Confidence Intervals
#'
#' Takes a matrix of bootstrap replications (one row per iteration,
#' one column per driver) and computes point estimates, standard
#' errors, and percentile-based confidence intervals.
#'
#' Rows that are entirely NA (from failed iterations) are dropped
#' before summarization.
#'
#' @param boot_matrix Numeric matrix with dimensions
#'   \code{n_bootstrap x n_drivers}. Column names should be driver names.
#' @param ci_level Confidence level in (0, 1), e.g. 0.95.
#'
#' @return A data.frame with columns:
#'   \describe{
#'     \item{Driver}{Driver variable name (from column names)}
#'     \item{Point_Estimate}{Mean of non-NA bootstrap values}
#'     \item{CI_Lower}{Lower percentile bound}
#'     \item{CI_Upper}{Upper percentile bound}
#'     \item{SE}{Standard deviation of bootstrap distribution}
#'   }
#'
#' @keywords internal
summarize_bootstrap_results <- function(boot_matrix, ci_level) {

  drivers <- colnames(boot_matrix)
  n_drivers <- ncol(boot_matrix)

  # Percentile bounds
  alpha <- 1 - ci_level
  probs <- c(alpha / 2, 1 - alpha / 2)

  point_estimate <- numeric(n_drivers)
  ci_lower       <- numeric(n_drivers)
  ci_upper       <- numeric(n_drivers)
  se             <- numeric(n_drivers)

  for (j in seq_len(n_drivers)) {
    col_vals <- boot_matrix[, j]
    col_vals <- col_vals[!is.na(col_vals)]

    if (length(col_vals) == 0) {
      point_estimate[j] <- NA_real_
      ci_lower[j]       <- NA_real_
      ci_upper[j]       <- NA_real_
      se[j]             <- NA_real_
    } else {
      point_estimate[j] <- mean(col_vals)
      quantiles          <- stats::quantile(col_vals, probs = probs, na.rm = TRUE)
      ci_lower[j]       <- quantiles[1]
      ci_upper[j]       <- quantiles[2]
      se[j]             <- sd(col_vals)
    }
  }

  data.frame(
    Driver         = drivers,
    Point_Estimate = round(point_estimate, 4),
    CI_Lower       = round(ci_lower, 4),
    CI_Upper       = round(ci_upper, 4),
    SE             = round(se, 4),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# NULL-COALESCING OPERATOR (guarded)
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
