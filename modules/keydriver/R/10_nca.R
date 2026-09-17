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
  #
  # The call used to be NCA::nca_analysis(d[[drv]], d[[outcome_var]], ...).
  # The package's signature is nca_analysis(data, x, y, ...), so those two
  # vectors bound to `data` and `x` with no `y` at all and the call failed for
  # every driver, on every run. The tryCatch below then turned each failure
  # into NA, the classifier read NA as not-significant, and every driver in
  # every study was reported "Not Necessary". Verified by execution against the
  # installed package (review H7).
  #
  # The return shape was wrong too: summaries is keyed by the x variable's
  # name, not by the ceiling, and each entry holds a 25-row params matrix read
  # by row name. Nothing the old extraction named existed.
  test_reps <- suppressWarnings(as.numeric(
    config$settings$nca_test_reps %||% config$nca_test_reps %||% 100))
  if (!is.finite(test_reps) || test_reps < 0) test_reps <- 100
  cat(sprintf("   - Permutation test: %d replications%s\n", as.integer(test_reps),
              if (test_reps == 0) " (no p-values)" else ""))

  nca_param <- function(summary_entry, row_name) {
    prm <- summary_entry$params
    if (is.null(prm) || !row_name %in% rownames(prm)) return(NA_real_)
    suppressWarnings(as.numeric(prm[rownames(prm) == row_name, 1][1]))
  }

  nca_failures <- character(0)
  nca_results <- lapply(numeric_drivers, function(drv) {
    tryCatch({
      nca_out <- NCA::nca_analysis(data = d, x = drv, y = outcome_var,
                                   ceilings = "ce_fdh", test.rep = test_reps)
      entry <- nca_out$summaries[[drv]]
      if (is.null(entry)) stop(sprintf("no summary returned for '%s'", drv))

      effect_size <- nca_param(entry, "Effect size")
      p_value <- nca_param(entry, "p-value")
      scope <- if (!is.null(entry$global) && "Scope" %in% rownames(entry$global)) {
        suppressWarnings(as.numeric(entry$global[rownames(entry$global) == "Scope", 1][1]))
      } else NA_real_

      # Necessary if the effect is large enough AND the permutation test says
      # it is not chance. With test.rep = 0 there is no p-value, so nothing can
      # be called necessary and the column says so rather than assuming.
      is_necessary <- !is.na(effect_size) && effect_size >= 0.1 &&
                      !is.na(p_value) && p_value < 0.05

      list(
        driver = drv,
        effect_size = if (is.na(effect_size)) NA_real_ else effect_size,
        p_value = p_value,
        is_necessary = is_necessary,
        accuracy = nca_param(entry, "Ceiling accuracy"),
        ceiling_zone = nca_param(entry, "Ceiling zone"),
        scope = scope
      )
    }, error = function(e) {
      cat(sprintf("   [WARN] NCA for '%s' failed: %s\n", drv, e$message))
      nca_failures <<- c(nca_failures, drv)
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
    results_df$Is_Necessary, "Necessary Condition",
    ifelse(is.na(results_df$NCA_Effect_Size), "Not analysed",
           ifelse(is.na(results_df$NCA_p_value), "No significance test", "Not Necessary")))

  # Sort by effect size descending
  results_df <- results_df[order(-results_df$NCA_Effect_Size), ]
  rownames(results_df) <- NULL

  n_necessary <- sum(results_df$Is_Necessary)

  # --- Build bottleneck table ---
  # Shows: for outcome at 50%, 75%, 90%, what minimum driver level is needed?
  bottleneck_levels <- c(50, 75, 90)
  # Intervals for NCA's 0 to 100 outcome grid. Twenty gives 5 point steps,
  # which contain every level above exactly (review F12).
  KD_NCA_BOTTLENECK_STEPS <- 20L
  bottleneck_rows <- lapply(numeric_drivers[numeric_drivers %in%
    results_df$Driver[results_df$Is_Necessary]], function(drv) {
    tryCatch({
      # Bottleneck levels are an argument to nca_analysis(), not to
      # nca_output(): the old code passed bottleneck.y to nca_output, which has
      # no such parameter, so the call errored and every bottleneck was NA
      # (review H7). The table comes back on $bottlenecks$ce_fdh with the
      # outcome in the first column and the driver in the second.
      # steps is the number of intervals the 0 to 100 outcome grid is cut
      # into, not the number of levels wanted. steps = 3 gave a grid of
      # 0, 33.3, 66.7, 100, and the nearest-level lookup below then filled
      # the column headed Y_50pct with the value at 33.3 or 66.7 (review
      # F12). Twenty intervals is a 5 point grid, which contains 50, 75 and
      # 90 exactly, so each column holds the number its header names.
      nca_out <- NCA::nca_analysis(data = d, x = drv, y = outcome_var,
                                   ceilings = "ce_fdh", test.rep = 0,
                                   bottleneck.y = "percentage.range",
                                   steps = KD_NCA_BOTTLENECK_STEPS)
      bn_vals <- tryCatch({
        tbl <- nca_out$bottlenecks$ce_fdh
        if (is.data.frame(tbl) && ncol(tbl) >= 2) {
          y_levels <- suppressWarnings(as.numeric(tbl[[1]]))
          x_needed <- suppressWarnings(as.numeric(tbl[[2]]))
          vapply(bottleneck_levels, function(lv) {
            # Exact, not nearest. A nearest match is how a number computed at
            # one outcome level ended up under another level's heading. If the
            # grid does not contain the level, the cell is empty rather than
            # wrong. A cell is also empty when NCA reports "NN", meaning the
            # driver places no constraint at that outcome level.
            hit <- which(abs(y_levels - lv) < 1e-6)
            if (length(hit) == 1) x_needed[hit] else NA_real_
          }, numeric(1))
        } else {
          rep(NA_real_, length(bottleneck_levels))
        }
      }, error = function(e2) {
        rep(NA_real_, length(bottleneck_levels))
      })
      c(Driver = drv, setNames(bn_vals, paste0("Y_", bottleneck_levels, "pct")))
    }, error = function(e) {
      cat(sprintf("   [WARN] Bottleneck for '%s' failed: %s\n", drv, e$message))
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

  # Every driver erroring is not a finding of "no necessary conditions", it is
  # a feature that did not run. That is exactly how the broken call read as a
  # clean PASS with every driver marked Not Necessary (review H7).
  all_failed <- length(nca_failures) == length(numeric_drivers) && length(numeric_drivers) > 0
  some_failed <- length(nca_failures) > 0

  if (all_failed) {
    cat(sprintf("   [PARTIAL] NCA failed for every driver (%d of %d).\n",
                length(nca_failures), length(numeric_drivers)))
  } else if (some_failed) {
    cat(sprintf("   [PARTIAL] NCA failed for %d of %d drivers: %s\n",
                length(nca_failures), length(numeric_drivers),
                paste(nca_failures, collapse = ", ")))
  }

  list(
    status = if (some_failed) "PARTIAL" else "PASS",
    message = if (all_failed) {
      sprintf("NCA produced no result: the analysis errored for all %d driver(s).",
              length(numeric_drivers))
    } else if (some_failed) {
      sprintf(paste0("NCA complete for %d of %d drivers. %d necessary condition(s) ",
                     "identified; %s could not be analysed."),
              length(numeric_drivers) - length(nca_failures), length(numeric_drivers),
              n_necessary, paste(nca_failures, collapse = ", "))
    } else {
      sprintf("NCA complete. %d necessary condition(s) identified.", n_necessary)
    },
    result = list(
      nca_summary = results_df,
      bottleneck = bottleneck_df,
      n_necessary = n_necessary,
      n_analysed = length(numeric_drivers) - length(nca_failures),
      n_failed = length(nca_failures),
      drivers_failed = nca_failures,
      test_replications = as.integer(test_reps),
      n_obs = nrow(d)
    )
  )
}
