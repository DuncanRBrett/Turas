# ==============================================================================
# TURAS SHARED - HIERARCHICAL BAYES MCMC DIAGNOSTICS
# ==============================================================================
#
# Module: Shared Library - HB/MCMC Convergence Diagnostics
# Purpose: Reusable MCMC convergence checking for any HB estimation
# Version: 1.0.0
# Date: 2025-12
#
# USAGE:
#   This module provides convergence diagnostics for Hierarchical Bayes
#   estimation across Turas modules (conjoint, maxdiff, etc.).
#
# DIAGNOSTICS PROVIDED:
#   1. Gelman-Rubin (R-hat) - chain mixing assessment
#   2. Effective Sample Size (ESS) - autocorrelation-adjusted sample size
#   3. Geweke diagnostic - stationarity test
#   4. Autocorrelation - chain mixing speed
#
# DEPENDENCIES:
#   - Optional: coda package (for enhanced diagnostics)
#
# ==============================================================================

HB_DIAGNOSTICS_VERSION <- "1.0.0"


# ==============================================================================
# MAIN CONVERGENCE CHECK
# ==============================================================================

#' Check MCMC Convergence for HB Model
#'
#' Performs comprehensive MCMC convergence diagnostics for Hierarchical Bayes
#' estimation. Uses standard diagnostic criteria from the literature.
#'
#' @description
#' Convergence is assessed using multiple criteria:
#'
#' 1. **Gelman-Rubin statistic (R-hat)**: Compares within-chain and between-chain
#'    variance. Values < 1.1 indicate convergence.
#'
#' 2. **Effective Sample Size (ESS)**: Accounts for autocorrelation in MCMC chains.
#'    Should be > 100 for reliable inference, ideally > 400.
#'
#' 3. **Geweke diagnostic**: Compares means from first 10% and last 50% of chain.
#'    Z-scores should be within (-1.96, 1.96) at 95% level.
#'
#' 4. **Autocorrelation**: High autocorrelation indicates slow mixing.
#'    Lag-1 autocorrelation > 0.9 suggests poor mixing.
#'
#' @param mcmc_draws Matrix or mcmc object with MCMC samples (rows = iterations, cols = parameters)
#' @param parameters Character vector of parameter names to check (NULL = all)
#' @param verbose Logical. Print detailed diagnostics.
#'
#' @return List with convergence diagnostics:
#' \describe{
#'   \item{converged}{Logical. Overall convergence assessment}
#'   \item{gelman_rubin}{Data frame with R-hat values per parameter}
#'   \item{effective_n}{Data frame with effective sample sizes}
#'   \item{geweke}{Data frame with Geweke z-scores}
#'   \item{autocorrelation}{Data frame with lag-1 autocorrelations}
#'   \item{summary}{Character summary of convergence status}
#'   \item{recommendations}{Character vector of improvement suggestions}
#' }
#'
#' @export
check_hb_convergence <- function(mcmc_draws, parameters = NULL, verbose = TRUE) {

  # Initialize diagnostics list
  diagnostics <- list(
    converged = FALSE,
    gelman_rubin = NULL,
    effective_n = NULL,
    geweke = NULL,
    autocorrelation = NULL,
    summary = "",
    recommendations = character(0)
  )

  # Check if we have MCMC draws
  if (is.null(mcmc_draws)) {
    diagnostics$summary <- "No MCMC draws available for diagnostics"
    diagnostics$recommendations <- "Run HB estimation with save_draws=TRUE"
    return(diagnostics)
  }

  if (verbose) {
    cat("\n")
    cat(rep("=", 70), "\n", sep = "")
    cat("HIERARCHICAL BAYES CONVERGENCE DIAGNOSTICS\n")
    cat(rep("=", 70), "\n", sep = "")
    cat("\n")
  }

  # Try to use coda package for comprehensive diagnostics
  has_coda <- requireNamespace("coda", quietly = TRUE)

  if (has_coda) {
    diagnostics <- check_convergence_with_coda(mcmc_draws, parameters, verbose)
  } else {
    diagnostics <- check_convergence_basic(mcmc_draws, parameters, verbose)
  }

  # Overall assessment
  all_converged <- TRUE
  recommendations <- character(0)

  # Check Gelman-Rubin
  if (!is.null(diagnostics$gelman_rubin)) {
    bad_rhat <- diagnostics$gelman_rubin$rhat > 1.1
    if (any(bad_rhat, na.rm = TRUE)) {
      all_converged <- FALSE
      n_bad <- sum(bad_rhat, na.rm = TRUE)
      recommendations <- c(recommendations,
        sprintf("Increase MCMC iterations: %d parameters have R-hat > 1.1", n_bad))
    }
  }

  # Check effective sample size
  if (!is.null(diagnostics$effective_n)) {
    low_ess <- diagnostics$effective_n$ess < 100
    if (any(low_ess, na.rm = TRUE)) {
      n_low <- sum(low_ess, na.rm = TRUE)
      if (n_low > length(low_ess) * 0.5) {
        all_converged <- FALSE
      }
      recommendations <- c(recommendations,
        sprintf("Increase iterations or reduce thinning: %d parameters have ESS < 100", n_low))
    }
  }

  # Check autocorrelation
  if (!is.null(diagnostics$autocorrelation)) {
    high_ac <- diagnostics$autocorrelation$lag1_ac > 0.9
    if (any(high_ac, na.rm = TRUE)) {
      n_high <- sum(high_ac, na.rm = TRUE)
      recommendations <- c(recommendations,
        sprintf("High autocorrelation detected: %d parameters have lag-1 AC > 0.9", n_high))
    }
  }

  diagnostics$converged <- all_converged
  diagnostics$recommendations <- recommendations

  # Generate summary
  if (all_converged) {
    diagnostics$summary <- "MCMC chains appear to have converged"
  } else {
    diagnostics$summary <- "MCMC chains may not have converged - see recommendations"
  }

  if (verbose) {
    cat("\n")
    cat(rep("-", 70), "\n", sep = "")
    cat("CONVERGENCE SUMMARY\n")
    cat(rep("-", 70), "\n", sep = "")
    cat(sprintf("Status: %s\n", if (all_converged) "CONVERGED" else "NOT CONVERGED"))
    cat(sprintf("Summary: %s\n", diagnostics$summary))

    if (length(recommendations) > 0) {
      cat("\nRecommendations:\n")
      for (rec in recommendations) {
        cat(sprintf("  - %s\n", rec))
      }
    }
    cat("\n")
  }

  diagnostics
}


# ==============================================================================
# CODA-BASED DIAGNOSTICS
# ==============================================================================

#' Check Convergence Using coda Package
#'
#' @param draws MCMC draws matrix or mcmc object
#' @param parameters Parameter names to check
#' @param verbose Print progress
#' @return List with diagnostics
#' @keywords internal
check_convergence_with_coda <- function(draws, parameters, verbose) {

  diagnostics <- list()

  # Convert to coda mcmc object if needed
  if (!inherits(draws, "mcmc")) {
    draws <- coda::as.mcmc(draws)
  }

  # Get parameter names
  if (is.null(parameters)) {
    parameters <- colnames(draws)
  }

  n_params <- length(parameters)

  if (verbose) {
    cat(sprintf("Checking convergence for %d parameters using coda package...\n\n", n_params))
  }

  # 1. Effective Sample Size
  if (verbose) cat("1. Effective Sample Size (ESS):\n")

  ess_values <- coda::effectiveSize(draws)
  diagnostics$effective_n <- data.frame(
    parameter = names(ess_values),
    ess = as.numeric(ess_values),
    stringsAsFactors = FALSE
  )

  if (verbose) {
    min_ess <- min(ess_values)
    max_ess <- max(ess_values)
    median_ess <- median(ess_values)
    cat(sprintf("   Min ESS: %.0f | Median: %.0f | Max: %.0f\n", min_ess, median_ess, max_ess))
    cat(sprintf("   Parameters with ESS < 100: %d\n", sum(ess_values < 100)))
    cat(sprintf("   Parameters with ESS < 400: %d\n\n", sum(ess_values < 400)))
  }

  # 2. Geweke Diagnostic
  if (verbose) cat("2. Geweke Diagnostic (first 10% vs last 50%):\n")

  geweke_z <- coda::geweke.diag(draws)$z
  diagnostics$geweke <- data.frame(
    parameter = names(geweke_z),
    z_score = as.numeric(geweke_z),
    significant = abs(geweke_z) > 1.96,
    stringsAsFactors = FALSE
  )

  if (verbose) {
    n_sig <- sum(abs(geweke_z) > 1.96, na.rm = TRUE)
    cat(sprintf("   Parameters with |z| > 1.96: %d (%.1f%%)\n", n_sig, 100 * n_sig / n_params))
    if (n_sig > 0 && n_sig <= 5) {
      bad_params <- names(geweke_z)[abs(geweke_z) > 1.96]
      cat(sprintf("   Flagged: %s\n", paste(head(bad_params, 5), collapse = ", ")))
    }
    cat("\n")
  }

  # 3. Autocorrelation at lag 1
  if (verbose) cat("3. Autocorrelation (lag-1):\n")

  ac_values <- apply(as.matrix(draws), 2, function(x) {
    if (length(x) > 1) acf(x, lag.max = 1, plot = FALSE)$acf[2] else NA
  })

  diagnostics$autocorrelation <- data.frame(
    parameter = names(ac_values),
    lag1_ac = as.numeric(ac_values),
    stringsAsFactors = FALSE
  )

  if (verbose) {
    mean_ac <- mean(ac_values, na.rm = TRUE)
    max_ac <- max(ac_values, na.rm = TRUE)
    cat(sprintf("   Mean lag-1 autocorrelation: %.3f\n", mean_ac))
    cat(sprintf("   Max lag-1 autocorrelation: %.3f\n", max_ac))
    cat(sprintf("   Parameters with AC > 0.9: %d\n\n", sum(ac_values > 0.9, na.rm = TRUE)))
  }

  # 4. Approximate Gelman-Rubin (single chain version)
  if (verbose) cat("4. Split-chain R-hat (approximate Gelman-Rubin):\n")

  rhat_values <- calculate_split_rhat(as.matrix(draws))
  diagnostics$gelman_rubin <- data.frame(
    parameter = names(rhat_values),
    rhat = as.numeric(rhat_values),
    stringsAsFactors = FALSE
  )

  if (verbose) {
    max_rhat <- max(rhat_values, na.rm = TRUE)
    n_bad <- sum(rhat_values > 1.1, na.rm = TRUE)
    cat(sprintf("   Max R-hat: %.3f\n", max_rhat))
    cat(sprintf("   Parameters with R-hat > 1.1: %d\n", n_bad))
    cat(sprintf("   Parameters with R-hat > 1.05: %d\n\n", sum(rhat_values > 1.05, na.rm = TRUE)))
  }

  diagnostics
}


# ==============================================================================
# BASIC DIAGNOSTICS (NO CODA)
# ==============================================================================

#' Check Convergence Using Basic Methods (no coda)
#'
#' @param draws MCMC draws matrix
#' @param parameters Parameter names to check
#' @param verbose Print progress
#' @return List with diagnostics
#' @keywords internal
check_convergence_basic <- function(draws, parameters, verbose) {

  diagnostics <- list()

  if (verbose) {
    cat("Note: Install 'coda' package for more comprehensive diagnostics\n\n")
  }

  draws_matrix <- as.matrix(draws)

  if (is.null(parameters)) {
    parameters <- colnames(draws_matrix)
  }

  n_samples <- nrow(draws_matrix)
  n_params <- ncol(draws_matrix)

  if (verbose) {
    cat(sprintf("Checking convergence for %d parameters (%d samples)...\n\n", n_params, n_samples))
  }

  # 1. Effective Sample Size (basic calculation)
  if (verbose) cat("1. Effective Sample Size (basic):\n")

  ess_values <- apply(draws_matrix, 2, function(x) {
    calculate_basic_ess(x)
  })
  names(ess_values) <- parameters

  diagnostics$effective_n <- data.frame(
    parameter = parameters,
    ess = ess_values,
    stringsAsFactors = FALSE
  )

  if (verbose) {
    cat(sprintf("   Min ESS: %.0f | Median: %.0f | Max: %.0f\n",
                min(ess_values), median(ess_values), max(ess_values)))
    cat("\n")
  }

  # 2. Geweke-like diagnostic (compare first 10% to last 50%)
  if (verbose) cat("2. Mean comparison (first 10% vs last 50%):\n")

  n_first <- ceiling(n_samples * 0.1)
  n_last <- ceiling(n_samples * 0.5)

  geweke_z <- apply(draws_matrix, 2, function(x) {
    first <- x[1:n_first]
    last <- x[(n_samples - n_last + 1):n_samples]
    se <- sqrt(var(first)/n_first + var(last)/n_last)
    if (se > 0) (mean(first) - mean(last)) / se else NA
  })
  names(geweke_z) <- parameters

  diagnostics$geweke <- data.frame(
    parameter = parameters,
    z_score = geweke_z,
    significant = abs(geweke_z) > 1.96,
    stringsAsFactors = FALSE
  )

  if (verbose) {
    n_sig <- sum(abs(geweke_z) > 1.96, na.rm = TRUE)
    cat(sprintf("   Parameters with |z| > 1.96: %d\n\n", n_sig))
  }

  # 3. Autocorrelation at lag 1
  if (verbose) cat("3. Autocorrelation (lag-1):\n")

  ac_values <- apply(draws_matrix, 2, function(x) {
    if (length(x) > 1) {
      cor(x[-length(x)], x[-1])
    } else {
      NA
    }
  })
  names(ac_values) <- parameters

  diagnostics$autocorrelation <- data.frame(
    parameter = parameters,
    lag1_ac = ac_values,
    stringsAsFactors = FALSE
  )

  if (verbose) {
    cat(sprintf("   Mean lag-1 autocorrelation: %.3f\n", mean(ac_values, na.rm = TRUE)))
    cat(sprintf("   Max lag-1 autocorrelation: %.3f\n\n", max(ac_values, na.rm = TRUE)))
  }

  # 4. Split-chain R-hat
  if (verbose) cat("4. Split-chain R-hat:\n")

  rhat_values <- calculate_split_rhat(draws_matrix)
  names(rhat_values) <- parameters

  diagnostics$gelman_rubin <- data.frame(
    parameter = parameters,
    rhat = rhat_values,
    stringsAsFactors = FALSE
  )

  if (verbose) {
    cat(sprintf("   Max R-hat: %.3f\n", max(rhat_values, na.rm = TRUE)))
    cat(sprintf("   Parameters with R-hat > 1.1: %d\n\n", sum(rhat_values > 1.1, na.rm = TRUE)))
  }

  diagnostics
}


# ==============================================================================
# STATISTICAL CALCULATIONS
# ==============================================================================

#' Calculate Basic Effective Sample Size
#'
#' Estimates ESS using autocorrelation summation method.
#'
#' @param x Numeric vector of MCMC samples
#' @return Effective sample size estimate
#' @keywords internal
calculate_basic_ess <- function(x) {
  n <- length(x)
  if (n < 2) return(n)

  # Calculate autocorrelations up to lag n/2
  max_lag <- min(n - 1, floor(n / 2))
  rho <- numeric(max_lag)

  var_x <- var(x)
  if (var_x == 0) return(n)

  mean_x <- mean(x)
  for (k in 1:max_lag) {
    rho[k] <- sum((x[1:(n-k)] - mean_x) * (x[(k+1):n] - mean_x)) / ((n - k) * var_x)
  }

  # Sum positive autocorrelations (Geyer's initial monotone sequence)
  sum_rho <- 0
  for (k in seq(1, max_lag - 1, by = 2)) {
    pair_sum <- rho[k] + rho[k + 1]
    if (pair_sum < 0) break
    sum_rho <- sum_rho + pair_sum
  }

  # ESS = n / (1 + 2 * sum_rho)
  ess <- n / (1 + 2 * sum_rho)
  max(1, min(n, ess))  # Bound between 1 and n
}


#' Calculate Split-Chain R-hat
#'
#' Computes approximate Gelman-Rubin statistic by splitting single chain.
#'
#' @param draws_matrix Matrix of MCMC draws (samples x parameters)
#' @return Named vector of R-hat values
#' @keywords internal
calculate_split_rhat <- function(draws_matrix) {
  n_samples <- nrow(draws_matrix)
  n_params <- ncol(draws_matrix)

  # Split chain in half
  mid <- floor(n_samples / 2)
  chain1 <- draws_matrix[1:mid, , drop = FALSE]
  chain2 <- draws_matrix[(mid + 1):n_samples, , drop = FALSE]

  rhat <- numeric(n_params)

  for (j in 1:n_params) {
    x1 <- chain1[, j]
    x2 <- chain2[, j]

    n <- length(x1)
    m <- 2  # number of chains

    # Within-chain variance
    W <- (var(x1) + var(x2)) / 2

    # Between-chain variance
    grand_mean <- mean(c(x1, x2))
    B <- n * ((mean(x1) - grand_mean)^2 + (mean(x2) - grand_mean)^2) / (m - 1)

    # Marginal posterior variance estimate
    var_plus <- ((n - 1) * W + B) / n

    # R-hat
    if (W > 0) {
      rhat[j] <- sqrt(var_plus / W)
    } else {
      rhat[j] <- 1.0
    }
  }

  names(rhat) <- colnames(draws_matrix)
  rhat
}


# ==============================================================================
# VISUALIZATION HELPERS
# ==============================================================================

#' Generate Trace Plot Data
#'
#' Prepares data for trace plot visualization of MCMC chains.
#'
#' @param mcmc_draws Matrix or mcmc object with MCMC draws
#' @param parameters Character vector of parameters to plot (NULL = first 6)
#' @param thin_factor Integer. Thinning factor for large chains (default: auto)
#' @return Data frame suitable for ggplot2 trace plots
#' @export
prepare_trace_plot_data <- function(mcmc_draws, parameters = NULL, thin_factor = NULL) {

  if (is.null(mcmc_draws)) {
    stop("No MCMC draws available for trace plots")
  }

  draws <- as.matrix(mcmc_draws)
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


#' Summarize HB Convergence for Output
#'
#' Creates a summary table suitable for Excel output.
#'
#' @param diagnostics Diagnostics list from check_hb_convergence()
#' @return Data frame with convergence summary
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


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>Shared HB diagnostics module loaded (v%s)", HB_DIAGNOSTICS_VERSION))
