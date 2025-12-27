# ==============================================================================
# HIERARCHICAL BAYES - VISUALIZATION AND SUMMARIES
# ==============================================================================
#
# Module: Conjoint Analysis - HB Visualization
# Purpose: Visualization and summary functions for Hierarchical Bayes results
# Version: 2.1.0
# Date: 2025-12-27
#
# CONTENTS:
#   - Trace plot data preparation
#   - Convergence diagnostics summary tables
#   - Output formatting for Excel
#
# Part of: Turas Enhanced Conjoint Analysis Module - Hierarchical Bayes
# Parent: 11_hierarchical_bayes.R
# ==============================================================================


# ==============================================================================
# TRACE PLOT DATA PREPARATION
# ==============================================================================

#' Generate Trace Plot Data
#'
#' Prepares MCMC chain data for trace plot visualization. Trace plots show
#' the sampled parameter values over iterations and are essential for
#' visual convergence assessment.
#'
#' @param hb_result HB model result from estimate_hierarchical_bayes()
#' @param parameters Character vector of parameters to plot (NULL = first 6)
#' @param thin_factor Integer. Thinning factor for large chains (default: auto)
#'
#' @return Data frame suitable for ggplot2 trace plots with columns:
#'   - iteration: MCMC iteration number
#'   - parameter: Parameter name
#'   - value: Parameter value at that iteration
#'
#' @details
#' For large MCMC chains (> 2000 samples), automatic thinning is applied
#' to reduce data size while preserving visual patterns. Manual thinning
#' can be controlled via thin_factor parameter.
#'
#' The output data frame is in long format suitable for faceted plotting:
#' \code{
#' ggplot(trace_data, aes(x = iteration, y = value)) +
#'   geom_line() +
#'   facet_wrap(~parameter, scales = "free_y")
#' }
#'
#' @examples
#' \dontrun{
#' # Prepare trace plot data for first 6 parameters
#' trace_data <- prepare_trace_plot_data(hb_result)
#'
#' # Plot with ggplot2
#' library(ggplot2)
#' ggplot(trace_data, aes(x = iteration, y = value)) +
#'   geom_line(alpha = 0.7) +
#'   facet_wrap(~parameter, scales = "free_y") +
#'   labs(title = "MCMC Trace Plots",
#'        x = "Iteration",
#'        y = "Parameter Value")
#' }
#'
#' @export
prepare_trace_plot_data <- function(hb_result, parameters = NULL, thin_factor = NULL) {

  if (is.null(hb_result$mcmc_draws)) {
    conjoint_refuse(
      code = "DATA_HB_NO_MCMC_DRAWS",
      title = "No MCMC Draws Available",
      problem = "No MCMC draws available for trace plots",
      why_it_matters = "Trace plots require MCMC samples to visualize chain convergence.",
      how_to_fix = "Ensure HB estimation was run with save_draws=TRUE"
    )
  }

  draws <- as.matrix(hb_result$mcmc_draws)
  n_samples <- nrow(draws)

  # Select parameters
  if (is.null(parameters)) {
    parameters <- head(colnames(draws), 6)
  }

  draws <- draws[, parameters, drop = FALSE]

  # Auto-thin for large chains
  if (is.null(thin_factor)) {
    thin_factor <- max(1, floor(n_samples / 2000))
  }

  if (thin_factor > 1) {
    idx <- seq(1, n_samples, by = thin_factor)
    draws <- draws[idx, , drop = FALSE]
  }

  # Convert to long format
  n_samples_final <- nrow(draws)
  trace_data <- data.frame(
    iteration = rep(seq_len(n_samples_final) * thin_factor, ncol(draws)),
    parameter = rep(colnames(draws), each = n_samples_final),
    value = as.vector(draws),
    stringsAsFactors = FALSE
  )

  trace_data
}


# ==============================================================================
# CONVERGENCE DIAGNOSTICS SUMMARY
# ==============================================================================

#' Summarize HB Convergence for Output
#'
#' Creates a comprehensive summary table of convergence diagnostics suitable
#' for Excel output and reporting. Combines all diagnostic measures into a
#' single data frame with interpretation flags.
#'
#' @param diagnostics Diagnostics list from check_hb_convergence()
#'
#' @return Data frame with convergence summary containing:
#'   - parameter: Parameter name
#'   - rhat: Gelman-Rubin R-hat statistic
#'   - rhat_ok: Flag indicating if R-hat is acceptable ("OK" or "CHECK")
#'   - ess: Effective sample size
#'   - ess_ok: Flag for ESS ("OK", "LOW", or "VERY LOW")
#'   - lag1_ac: Lag-1 autocorrelation
#'   - z_score: Geweke diagnostic z-score
#'
#' @details
#' Interpretation flags:
#' - **rhat_ok**: "OK" if R-hat <= 1.1, "CHECK" otherwise
#' - **ess_ok**: "OK" if ESS >= 100, "LOW" if 50-99, "VERY LOW" if < 50
#'
#' Parameters flagged as "CHECK" or "VERY LOW" indicate potential convergence
#' issues and may require longer MCMC runs.
#'
#' @examples
#' \dontrun{
#' # Check convergence and create summary
#' diagnostics <- check_hb_convergence(hb_result)
#' summary_df <- summarize_hb_diagnostics(diagnostics)
#'
#' # Identify problematic parameters
#' problems <- summary_df[summary_df$rhat_ok == "CHECK" |
#'                        summary_df$ess_ok == "VERY LOW", ]
#' print(problems)
#' }
#'
#' @export
summarize_hb_diagnostics <- function(diagnostics) {

  # Merge all diagnostic data frames
  summary_df <- diagnostics$gelman_rubin

  if (!is.null(diagnostics$effective_n)) {
    summary_df <- merge(summary_df, diagnostics$effective_n, by = "parameter", all = TRUE)
  }

  if (!is.null(diagnostics$autocorrelation)) {
    summary_df <- merge(summary_df, diagnostics$autocorrelation, by = "parameter", all = TRUE)
  }

  if (!is.null(diagnostics$geweke)) {
    summary_df <- merge(summary_df,
                        diagnostics$geweke[, c("parameter", "z_score")],
                        by = "parameter", all = TRUE)
  }

  # Add interpretation columns
  summary_df$rhat_ok <- ifelse(is.na(summary_df$rhat), NA,
                                ifelse(summary_df$rhat <= 1.1, "OK", "CHECK"))
  summary_df$ess_ok <- ifelse(is.na(summary_df$ess), NA,
                               ifelse(summary_df$ess >= 100, "OK",
                                      ifelse(summary_df$ess >= 50, "LOW", "VERY LOW")))

  # Reorder columns
  col_order <- c("parameter", "rhat", "rhat_ok", "ess", "ess_ok", "lag1_ac", "z_score")
  col_order <- col_order[col_order %in% names(summary_df)]
  summary_df <- summary_df[, col_order]

  summary_df
}
