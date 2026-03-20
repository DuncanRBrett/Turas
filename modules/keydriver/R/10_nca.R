# ==============================================================================
# TURAS KEY DRIVER - NECESSARY CONDITION ANALYSIS (NCA)
# ==============================================================================
#
# Purpose: Identify drivers that are necessary conditions for the outcome.
#          A driver is "necessary" if there is no high outcome without at
#          least a moderate level of that driver (ceiling effect).
# Version: Turas v10.4
# Date: 2026-03
#
# Value: Separates "hygiene factors" (necessary but not differentiating)
#        from "motivators" (differentiating but not necessary). Creates a
#        powerful framework when combined with derived importance.
#
# References:
#   - Dul, J. (2016). Necessary Condition Analysis (NCA): Logic and
#     methodology of "Necessary but Not Sufficient" causality.
#     Organizational Research Methods, 19(1), 10-52.
# ==============================================================================


#' Run Necessary Condition Analysis
#'
#' Uses the NCA package to test each driver for necessity. A driver is
#' necessary if there is a ceiling effect: high outcome values require
#' at least moderate driver values. Computes ceiling envelopment (CE-FDH)
#' and effect size.
#'
#' @param data Data frame with outcome and driver columns
#' @param config Configuration list (outcome_var, driver_vars)
#' @return List with status, result (necessity classification, bottleneck table)
#' @keywords internal
run_nca_analysis <- function(data, config) {

  # --- Check NCA availability ---
  if (!requireNamespace("NCA", quietly = TRUE)) {
    return(list(
      status = "PARTIAL",
      message = "NCA package not installed. Necessary Condition Analysis skipped.",
      result = NULL
    ))
  }

  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars

  cat("   Running Necessary Condition Analysis...\n")

  # --- Prepare data (complete cases only) ---
  use_vars <- c(outcome_var, driver_vars)
  cc <- stats::complete.cases(data[, use_vars, drop = FALSE])
  d <- data[cc, use_vars, drop = FALSE]

  if (nrow(d) < 20) {
    return(list(
      status = "PARTIAL",
      message = sprintf("Too few complete cases (%d) for NCA. Minimum 20 required.", nrow(d)),
      result = NULL
    ))
  }

  # Only analyse numeric drivers
  numeric_drivers <- driver_vars[vapply(driver_vars, function(v) {
    is.numeric(d[[v]])
  }, logical(1))]

  if (length(numeric_drivers) < 1) {
    return(list(
      status = "PARTIAL",
      message = "No numeric drivers available for NCA.",
      result = NULL
    ))
  }

  cat(sprintf("   - Analysing %d numeric drivers\n", length(numeric_drivers)))

  # --- Run NCA for each driver ---
  nca_results <- lapply(numeric_drivers, function(drv) {
    tryCatch({
      nca_out <- NCA::nca_analysis(d[[drv]], d[[outcome_var]], ceilings = "ce_fdh")

      # Extract effect size and p-value
      effect_size <- nca_out$summaries$ce_fdh$effect
      p_value <- nca_out$summaries$ce_fdh$p_value

      # Classification: necessary if effect size >= 0.1 and p < 0.05
      is_necessary <- !is.null(effect_size) && !is.na(effect_size) &&
                      effect_size >= 0.1 &&
                      !is.null(p_value) && !is.na(p_value) && p_value < 0.05

      list(
        driver = drv,
        effect_size = if (is.null(effect_size) || is.na(effect_size)) 0 else effect_size,
        p_value = if (is.null(p_value) || is.na(p_value)) 1 else p_value,
        is_necessary = is_necessary,
        accuracy = nca_out$summaries$ce_fdh$accuracy %||% NA_real_,
        ceiling_zone = nca_out$summaries$ce_fdh$ceiling.zone %||% NA_real_,
        scope = nca_out$summaries$ce_fdh$scope %||% NA_real_
      )
    }, error = function(e) {
      cat(sprintf("   [WARN] NCA for '%s' failed: %s\n", drv, e$message))
      list(
        driver = drv,
        effect_size = NA_real_,
        p_value = NA_real_,
        is_necessary = FALSE,
        accuracy = NA_real_,
        ceiling_zone = NA_real_,
        scope = NA_real_
      )
    })
  })

  # --- Build results data frame ---
  results_df <- data.frame(
    Driver = vapply(nca_results, `[[`, character(1), "driver"),
    NCA_Effect_Size = vapply(nca_results, `[[`, numeric(1), "effect_size"),
    NCA_p_value = vapply(nca_results, `[[`, numeric(1), "p_value"),
    Is_Necessary = vapply(nca_results, `[[`, logical(1), "is_necessary"),
    stringsAsFactors = FALSE
  )

  # Classify
  results_df$Classification <- ifelse(
    results_df$Is_Necessary,
    "Necessary Condition",
    "Not Necessary"
  )

  # Sort by effect size descending
  results_df <- results_df[order(-results_df$NCA_Effect_Size), ]
  rownames(results_df) <- NULL

  n_necessary <- sum(results_df$Is_Necessary)

  # --- Build bottleneck table ---
  # Shows: for outcome at 50%, 75%, 90%, what minimum driver level is needed?
  bottleneck_levels <- c(50, 75, 90)
  bottleneck_rows <- lapply(numeric_drivers[numeric_drivers %in%
    results_df$Driver[results_df$Is_Necessary]], function(drv) {
    tryCatch({
      nca_out <- NCA::nca_analysis(d[[drv]], d[[outcome_var]], ceilings = "ce_fdh")
      bn <- NCA::nca_output(nca_out, bottleneck.y = bottleneck_levels,
                            plots = FALSE, summaries = FALSE)
      bn_vals <- if (!is.null(bn$bottleneck)) {
        as.numeric(bn$bottleneck$ce_fdh)
      } else {
        rep(NA_real_, length(bottleneck_levels))
      }
      c(Driver = drv, setNames(bn_vals, paste0("Y_", bottleneck_levels, "pct")))
    }, error = function(e) {
      c(Driver = drv, setNames(rep(NA, length(bottleneck_levels)),
                               paste0("Y_", bottleneck_levels, "pct")))
    })
  })

  bottleneck_df <- if (length(bottleneck_rows) > 0) {
    do.call(rbind, lapply(bottleneck_rows, function(r) as.data.frame(t(r), stringsAsFactors = FALSE)))
  } else {
    NULL
  }

  cat(sprintf("   - Necessary conditions found: %d of %d\n",
              n_necessary, length(numeric_drivers)))

  list(
    status = "PASS",
    message = sprintf("NCA complete. %d necessary condition(s) identified.", n_necessary),
    result = list(
      nca_summary = results_df,
      bottleneck = bottleneck_df,
      n_necessary = n_necessary,
      n_analysed = length(numeric_drivers),
      n_obs = nrow(d)
    )
  )
}
