# ==============================================================================
# WEIGHTING SUMMARY V10.0 - SUMMARY AND DIAGNOSTICS MODULE
# ==============================================================================
# Functions for weight summary statistics and diagnostics
# Part of R Survey Analytics Toolkit
#
# MODULE PURPOSE:
# This module provides diagnostic and reporting functions for weight vectors.
# Used to validate weights, check design effects, and diagnose quality issues.
#
# VERSION HISTORY:
# V10.0 - Modular refactoring (2025-12-27)
#         - EXTRACTED: From weighting.R V9.9.4 (~80 lines)
#         - MAINTAINED: All V9.9.4 summary logic
#         - NO CHANGES: Function signatures and behavior identical
# V9.9.2 - Design effect computed using n_nonzero (clearer semantics)
#
# EXPORTED FUNCTIONS:
# - summarize_weights(): Display weight summary statistics
# ==============================================================================

WEIGHTING_SUMMARY_VERSION <- "10.0"

# ==============================================================================
# WEIGHTING SUMMARY (V9.9.2)
# ==============================================================================

#' Print weight summary statistics (V9.9.2: Clearer design effect)
#'
#' USAGE: Display weight diagnostics for validation
#' DESIGN: Shows distribution, effective-n, design effect
#' V9.9.2: Design effect computed using n_nonzero (clearer with zero weights)
#'
#' @param weights Numeric vector, weight vector
#' @param label Character, label for summary (default: "Weight Summary")
#' @export
#' @examples
#' summarize_weights(weights, "Main Weight")
summarize_weights <- function(weights, label = "Weight Summary") {
  weights <- weights[!is.na(weights) & is.finite(weights)]

  if (length(weights) == 0) {
    cat(label, ": No valid weights\n", sep = "")
    return(invisible(NULL))
  }

  # V9.9.2: Separate counts for total vs nonzero
  n_total <- length(weights)
  n_nonzero <- sum(weights > 0)
  n_zero <- n_total - n_nonzero

  eff_n <- calculate_effective_n(weights)

  # V9.9.2: Design effect computed using n_nonzero (clearer semantics)
  design_effect <- if (eff_n > 0) n_nonzero / eff_n else NA_real_

  cat("\n", label, ":\n", sep = "")
  cat("  N (total):        ", format(n_total, big.mark = ","), "\n")
  cat("  N (nonzero):      ", format(n_nonzero, big.mark = ","), "\n")

  if (n_zero > 0) {
    cat("  N (zero):         ", format(n_zero, big.mark = ","),
        sprintf(" (%.1f%%)", 100 * n_zero / n_total), "\n")
  }

  if (n_nonzero > 0) {
    nonzero_weights <- weights[weights > 0]

    cat("  Min:              ", round(min(nonzero_weights), 3), "\n")
    cat("  Q1:               ", round(quantile(nonzero_weights, 0.25), 3), "\n")
    cat("  Median:           ", round(median(nonzero_weights), 3), "\n")
    cat("  Q3:               ", round(quantile(nonzero_weights, 0.75), 3), "\n")
    cat("  Max:              ", round(max(nonzero_weights), 3), "\n")
    cat("  Mean:             ", round(mean(nonzero_weights), 3), "\n")
    cat("  SD:               ", round(sd(nonzero_weights), 3), "\n")
    cat("  CV:               ", round(sd(nonzero_weights)/mean(nonzero_weights), 3), "\n")
    cat("  Sum:              ", format(round(sum(nonzero_weights), 1), big.mark = ","), "\n")
  }

  cat("  Effective n:      ", format(eff_n, big.mark = ","), "\n")

  if (!is.na(design_effect)) {
    cat("  Design effect:    ", round(design_effect, 2), "\n")

    if (design_effect > 2) {
      cat("  WARNING: High design effect (>2) indicates substantial precision loss\n")
    }
  }

  cat("\n")
  invisible(NULL)
}

# ==============================================================================
# END OF WEIGHTING_SUMMARY.R V10.0
# ==============================================================================
