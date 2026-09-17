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

  # Limit to 15 drivers (2^p subsets becomes prohibitive). The drivers left out
  # are disclosed in the result, not only on the console, because a reader of
  # the sheet would otherwise see a dominance table that silently omits drivers
  # the study measured (review H5).
  truncation_note <- NULL
  dropped_drivers <- character(0)
  if (length(numeric_drivers) > 15) {
    cat(sprintf("   [WARN] Too many drivers (%d) for exact dominance analysis. Using top 15.\n",
                length(numeric_drivers)))
    # Use correlation magnitude to select top 15
    cors <- vapply(numeric_drivers, function(v) {
      abs(stats::cor(d[[v]], d[[outcome_var]], use = "complete.obs"))
    }, numeric(1))
    kept <- names(sort(cors, decreasing = TRUE))[1:15]
    dropped_drivers <- setdiff(numeric_drivers, kept)
    truncation_note <- sprintf(paste0(
      "Exact dominance analysis evaluates 2^p submodels, so it was limited to the ",
      "15 drivers most correlated with the outcome. %d driver(s) are NOT in this ",
      "table and their dominance is not zero, it is unmeasured: %s."),
      length(dropped_drivers), paste(dropped_drivers, collapse = ", "))
    numeric_drivers <- kept
  }

  cat(sprintf("   - Analysing %d drivers (2^%d = %d submodels)\n",
              length(numeric_drivers), length(numeric_drivers),
              2^length(numeric_drivers)))

  # --- Build formula ---
  formula_str <- paste(outcome_var, "~", paste(numeric_drivers, collapse = " + "))

  # --- Run domir ---
  # domir v1.2.0+ requires separate reg and fitstat arguments.
  #
  # A weighted run used to multiply the outcome and every driver by sqrt(w) and
  # fit unweighted, with a comment claiming that is "algebraically equivalent to
  # weighted least squares". It is not, for R-squared, which is the whole of
  # what dominance decomposes: the transformation changes the total sum of
  # squares and the intercept's meaning, so summary()$r.squared on the
  # transformed data is not the weighted R-squared. Measured on a 500-row
  # weighted fixture, the trick summed to 0.825110 where the weighted
  # full-model R-squared is 0.825140 (review H5).
  #
  # domir does not pass its data through to reg, which is why the old code
  # resorted to the transform. A closure that captures the frame and the weight
  # vector does pass them: domir reduces the formula and reg fits the reduced
  # model on the captured data, weighted. Verified to reconstruct the weighted
  # full-model R-squared exactly.
  dom_data <- d
  dom_weights <- if (!is.null(weight_var) && weight_var %in% names(d)) {
    as.numeric(d[[weight_var]])
  } else {
    NULL
  }
  # lm() resolves `weights` by non-standard evaluation: it looks in `data`
  # first and then in the FORMULA's environment, not in the caller's. domir
  # builds each submodel's formula itself with reformulate(), so that
  # environment is domir's internal frame and a weight vector captured by this
  # closure is invisible there. Rebinding the formula to an environment that
  # holds the weights is what makes the lookup succeed.
  dom_reg <- if (is.null(dom_weights)) {
    function(formula, ...) stats::lm(formula, data = dom_data)
  } else {
    reg_env <- new.env(parent = environment())
    assign(".dom_w", dom_weights, envir = reg_env)
    function(formula, ...) {
      environment(formula) <- reg_env
      stats::lm(formula, data = dom_data, weights = .dom_w)
    }
  }

  dom_result <- tryCatch(
    domir::domin(
      as.formula(formula_str),
      reg = dom_reg,
      fitstat = list(summary, "r.squared")
    ),
    error = function(e) {
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

  # A truncated run is a degraded one: the table cannot be read as the whole
  # driver set (review H5).
  if (!is.null(truncation_note)) cat(sprintf("   [PARTIAL] %s\n", truncation_note))

  list(
    status = if (is.null(truncation_note)) "PASS" else "PARTIAL",
    message = if (is.null(truncation_note)) {
      sprintf("Dominance analysis complete for %d drivers.", length(numeric_drivers))
    } else {
      truncation_note
    },
    result = list(
      summary = results_df,
      general_dominance = general_dom,
      conditional_dominance = conditional_dom,
      complete_dominance = complete_dom,
      n_drivers = length(numeric_drivers),
      n_obs = nrow(d),
      total_r_squared = sum(general_dom),
      weighted = !is.null(dom_weights),
      weight_variable = if (is.null(dom_weights)) NA_character_ else weight_var,
      drivers_omitted = dropped_drivers,
      truncation_note = truncation_note
    )
  )
}
