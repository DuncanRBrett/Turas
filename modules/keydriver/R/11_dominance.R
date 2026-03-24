# ==============================================================================
# TURAS KEY DRIVER - DOMINANCE ANALYSIS
# ==============================================================================
#
# Purpose: Complete and conditional dominance analysis extending the
#          existing Shapley (general dominance) decomposition. Reveals
#          suppressor effects and provides pairwise dominance rankings.
# Version: Turas v10.4
# Date: 2026-03
#
# Value: General dominance = Shapley values (already computed). This module
#        adds conditional dominance (by model size) and complete dominance
#        (pairwise, every subset context).
#
# References:
#   - Budescu, D. V. (1993). Dominance analysis: A new approach to the
#     problem of relative importance of predictors in multiple regression.
#     Psychological Bulletin, 114(3), 542-551.
#   - Azen, R. & Budescu, D. V. (2003). The dominance analysis approach
#     for comparing predictors in multiple regression.
#     Psychological Methods, 8(2), 129-148.
# ==============================================================================


#' Run Dominance Analysis
#'
#' Uses the domir package to compute general, conditional, and complete
#' dominance statistics for all drivers.
#'
#' @param data Data frame with outcome and driver columns
#' @param config Configuration list (outcome_var, driver_vars, weight_var)
#' @return List with status, result (general, conditional, complete dominance)
#' @keywords internal
run_dominance_analysis <- function(data, config) {

  # --- Check domir availability ---
  if (!requireNamespace("domir", quietly = TRUE)) {
    return(list(
      status = "PARTIAL",
      message = "domir package not installed. Dominance analysis skipped.",
      result = NULL
    ))
  }

  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars
  weight_var  <- config$weight_var

  cat("   Running Dominance Analysis...\n")

  # --- Prepare data ---
  use_vars <- c(outcome_var, driver_vars)
  if (!is.null(weight_var) && weight_var %in% names(data)) {
    use_vars <- c(use_vars, weight_var)
  }

  cc <- stats::complete.cases(data[, use_vars, drop = FALSE])
  d <- data[cc, , drop = FALSE]

  if (nrow(d) < 20) {
    return(list(
      status = "PARTIAL",
      message = sprintf("Too few complete cases (%d) for dominance analysis.", nrow(d)),
      result = NULL
    ))
  }

  # Only numeric drivers
  numeric_drivers <- driver_vars[vapply(driver_vars, function(v) is.numeric(d[[v]]), logical(1))]
  if (length(numeric_drivers) < 2) {
    return(list(
      status = "PARTIAL",
      message = "Dominance analysis requires at least 2 numeric drivers.",
      result = NULL
    ))
  }

  # Limit to 15 drivers (2^p subsets becomes prohibitive)
  if (length(numeric_drivers) > 15) {
    cat(sprintf("   [WARN] Too many drivers (%d) for exact dominance analysis. Using top 15.\n",
                length(numeric_drivers)))
    # Use correlation magnitude to select top 15
    cors <- vapply(numeric_drivers, function(v) {
      abs(stats::cor(d[[v]], d[[outcome_var]], use = "complete.obs"))
    }, numeric(1))
    numeric_drivers <- names(sort(cors, decreasing = TRUE))[1:15]
  }

  cat(sprintf("   - Analysing %d drivers (2^%d = %d submodels)\n",
              length(numeric_drivers), length(numeric_drivers),
              2^length(numeric_drivers)))

  # --- Build formula ---
  formula_str <- paste(outcome_var, "~", paste(numeric_drivers, collapse = " + "))

  # --- Run domir ---
  # domir v1.2.0+ requires separate reg and fitstat arguments.
  # For weighted analysis, we pre-weight the data since lm(weights=)
  # cannot resolve the weight column inside domir's internal evaluation.
  dom_result <- tryCatch({
    if (!is.null(weight_var) && weight_var %in% names(d)) {
      # Pre-weight data: multiply all analysis columns by sqrt(weight)
      # This is algebraically equivalent to weighted least squares
      w_sqrt <- sqrt(d[[weight_var]])
      d_wt <- d
      for (v in c(outcome_var, numeric_drivers)) {
        d_wt[[v]] <- d[[v]] * w_sqrt
      }
      domir::domin(
        as.formula(formula_str),
        reg = stats::lm,
        fitstat = list(summary, "r.squared"),
        data = d_wt
      )
    } else {
      domir::domin(
        as.formula(formula_str),
        reg = stats::lm,
        fitstat = list(summary, "r.squared"),
        data = d
      )
    }
  }, error = function(e) {
    cat(sprintf("   [WARN] domir::domin failed: %s\n", e$message))
    NULL
  })

  if (is.null(dom_result)) {
    return(list(
      status = "PARTIAL",
      message = "Dominance analysis computation failed.",
      result = NULL
    ))
  }

  # --- Extract results ---
  # General dominance (= Shapley values)
  general_dom <- dom_result$General_Dominance
  if (is.null(names(general_dom))) names(general_dom) <- numeric_drivers

  # Conditional dominance (by model size)
  conditional_dom <- dom_result$Conditional_Dominance
  if (is.null(conditional_dom)) conditional_dom <- matrix(nrow = 0, ncol = 0)

  # Complete dominance (pairwise)
  complete_dom <- dom_result$Complete_Dominance
  if (is.null(complete_dom)) complete_dom <- matrix(nrow = 0, ncol = 0)

  # --- Build summary data frame ---
  total_dom <- sum(general_dom)
  gen_pct <- if (total_dom > 1e-10) {
    (general_dom / total_dom) * 100
  } else {
    rep(0, length(general_dom))
  }
  results_df <- data.frame(
    Driver = names(general_dom),
    General_Dominance = round(general_dom, 4),
    General_Pct = round(gen_pct, 1),
    Rank = rank(-general_dom, ties.method = "min"),
    stringsAsFactors = FALSE
  )
  results_df <- results_df[order(results_df$Rank), ]
  rownames(results_df) <- NULL

  cat(sprintf("   - Top driver (general dominance): %s (%.1f%%)\n",
              results_df$Driver[1], results_df$General_Pct[1]))

  list(
    status = "PASS",
    message = sprintf("Dominance analysis complete for %d drivers.", length(numeric_drivers)),
    result = list(
      summary = results_df,
      general_dominance = general_dom,
      conditional_dominance = conditional_dom,
      complete_dominance = complete_dom,
      n_drivers = length(numeric_drivers),
      n_obs = nrow(d),
      total_r_squared = sum(general_dom)
    )
  )
}
