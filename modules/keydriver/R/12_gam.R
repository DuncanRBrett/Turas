# ==============================================================================
# TURAS KEY DRIVER - GAM NONLINEAR EFFECTS
# ==============================================================================
#
# Purpose: Fit Generalized Additive Models to detect nonlinear driver-outcome
#          relationships. Identifies diminishing returns, thresholds, and
#          S-curves in driver effects.
# Version: Turas v10.4
# Date: 2026-03
#
# Value: Shows WHERE investment will pay off — a linear model tells you a
#        driver matters, but a GAM reveals the shape. If satisfaction plateaus
#        above 7/10, that changes the strategy.
#
# References:
#   - Wood, S. N. (2017). Generalized Additive Models: An Introduction
#     with R. 2nd Edition. Chapman & Hall/CRC.
# ==============================================================================


#' Run GAM Nonlinear Effects Analysis
#'
#' Fits a GAM with smooth terms for each numeric driver. Tests whether each
#' driver's relationship with the outcome is significantly nonlinear by
#' comparing effective degrees of freedom (edf) and the approximate p-value
#' of the smooth term.
#'
#' @param data Data frame with outcome and driver columns
#' @param config Configuration list (outcome_var, driver_vars, weight_var)
#' @return List with status, result (nonlinearity tests, deviance explained)
#' @keywords internal
run_gam_analysis <- function(data, config) {

  # mgcv is a recommended R package (ships with base R), so it should be available
  if (!requireNamespace("mgcv", quietly = TRUE)) {
    return(list(
      status = "PARTIAL",
      message = "mgcv package not available. GAM analysis skipped.",
      result = NULL
    ))
  }

  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars
  weight_var  <- config$weight_var
  settings    <- config$settings %||% list()

  k_basis <- as.integer(settings$gam_k %||% 5)  # basis dimension (default 5 for survey data)

  cat("   Running GAM nonlinear effects analysis...\n")
  cat(sprintf("   - Basis dimension k = %d\n", k_basis))

  # --- Prepare data ---
  use_vars <- c(outcome_var, driver_vars)
  if (!is.null(weight_var) && weight_var %in% names(data)) {
    use_vars <- c(use_vars, weight_var)
  }

  cc <- stats::complete.cases(data[, use_vars, drop = FALSE])
  d <- data[cc, , drop = FALSE]

  if (nrow(d) < 30) {
    return(list(
      status = "PARTIAL",
      message = sprintf("Too few complete cases (%d) for GAM analysis. Minimum 30 required.", nrow(d)),
      result = NULL
    ))
  }

  # Only numeric drivers with enough unique values (need ≥ k for smooth)
  # Also require sufficient sample size relative to basis dimension
  min_n_per_smooth <- 3 * k_basis
  numeric_drivers <- driver_vars[vapply(driver_vars, function(v) {
    is.numeric(d[[v]]) && length(unique(d[[v]])) >= k_basis
  }, logical(1))]

  if (nrow(d) < min_n_per_smooth) {
    cat(sprintf("   [WARN] Sample size (%d) is small relative to k=%d. Reducing k to %d.\n",
                nrow(d), k_basis, max(3, nrow(d) %/% 5)))
    k_basis <- max(3L, as.integer(nrow(d) %/% 5))
  }

  if (length(numeric_drivers) < 1) {
    return(list(
      status = "PARTIAL",
      message = "No numeric drivers with sufficient unique values for GAM smooths.",
      result = NULL
    ))
  }

  cat(sprintf("   - Fitting GAM for %d numeric drivers\n", length(numeric_drivers)))

  # --- Build GAM formula ---
  smooth_terms <- paste(
    vapply(numeric_drivers, function(v) {
      sprintf("s(%s, k=%d)", v, k_basis)
    }, character(1)),
    collapse = " + "
  )
  gam_formula <- as.formula(paste(outcome_var, "~", smooth_terms))

  # --- Fit GAM ---
  gam_fit <- tryCatch({
    if (!is.null(weight_var) && weight_var %in% names(d)) {
      mgcv::gam(gam_formula, data = d, weights = d[[weight_var]], method = "REML")
    } else {
      mgcv::gam(gam_formula, data = d, method = "REML")
    }
  }, error = function(e) {
    cat(sprintf("   [WARN] GAM fitting failed: %s\n", e$message))
    NULL
  })

  if (is.null(gam_fit)) {
    return(list(
      status = "PARTIAL",
      message = "GAM fitting failed.",
      result = NULL
    ))
  }

  # --- Extract smooth term summaries ---
  gam_summary <- summary(gam_fit)
  s_table <- gam_summary$s.table

  if (is.null(s_table) || nrow(s_table) == 0) {
    return(list(
      status = "PARTIAL",
      message = "GAM produced no smooth term summaries.",
      result = NULL
    ))
  }

  # Parse driver names from smooth term labels
  smooth_names <- rownames(s_table)
  driver_names <- gsub("^s\\((.+)\\)$", "\\1", smooth_names)

  results_df <- data.frame(
    Driver = driver_names,
    EDF = round(s_table[, "edf"], 2),
    F_statistic = round(s_table[, "F"], 2),
    p_value = s_table[, "p-value"],
    stringsAsFactors = FALSE
  )

  # Classify nonlinearity: edf > 1.5 and p < 0.05 suggests meaningful nonlinearity
  results_df$Is_Nonlinear <- results_df$EDF > 1.5 & results_df$p_value < 0.05
  results_df$Shape <- ifelse(
    results_df$Is_Nonlinear,
    ifelse(results_df$EDF > 3, "Complex", "Moderate curvature"),
    "Approximately linear"
  )

  results_df <- results_df[order(-results_df$EDF), ]
  rownames(results_df) <- NULL

  n_nonlinear <- sum(results_df$Is_Nonlinear)
  dev_explained <- gam_summary$dev.expl

  # --- Also fit linear model for comparison ---
  lm_formula <- as.formula(paste(outcome_var, "~",
                                  paste(numeric_drivers, collapse = " + ")))
  lm_fit <- tryCatch({
    if (!is.null(weight_var) && weight_var %in% names(d)) {
      stats::lm(lm_formula, data = d, weights = d[[weight_var]])
    } else {
      stats::lm(lm_formula, data = d)
    }
  }, error = function(e) NULL)

  lm_r2 <- if (!is.null(lm_fit)) summary(lm_fit)$r.squared else NA_real_
  gam_r2 <- dev_explained  # GAM deviance explained ≈ R²

  cat(sprintf("   - Linear R²: %.3f | GAM deviance explained: %.3f\n",
              ifelse(is.na(lm_r2), 0, lm_r2), gam_r2))
  cat(sprintf("   - Drivers with significant nonlinearity: %d of %d\n",
              n_nonlinear, length(numeric_drivers)))

  list(
    status = "PASS",
    message = sprintf("GAM analysis complete. %d driver(s) show significant nonlinear effects.",
                      n_nonlinear),
    result = list(
      nonlinearity_summary = results_df,
      deviance_explained = round(dev_explained, 4),
      linear_r_squared = round(lm_r2, 4),
      improvement = round(gam_r2 - ifelse(is.na(lm_r2), 0, lm_r2), 4),
      n_nonlinear = n_nonlinear,
      n_analysed = length(numeric_drivers),
      n_obs = nrow(d),
      k_basis = k_basis
    )
  )
}
