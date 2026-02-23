# ==============================================================================
# TurasTracker - Constants
# ==============================================================================
#
# Centralized constants for the TurasTracker module.
# Extracts magic numbers to improve maintainability and consistency.
#
# VERSION: 1.0.0
# ==============================================================================

# ==============================================================================
# Statistical Testing Constants
# ==============================================================================

#' Default alpha level (significance threshold) for hypothesis tests
#'
#' Standard: 0.05 = 5% significance level (95% confidence)
DEFAULT_ALPHA <- 0.05

#' Minimum base size for reliable statistical testing
#'
#' Standard: 30 respondents (minimum for central limit theorem applicability)
DEFAULT_MINIMUM_BASE <- 30


# ==============================================================================
# Formatting Constants
# ==============================================================================

#' Default number of decimal places for rating/mean values
DEFAULT_DECIMAL_PLACES_RATINGS <- 1

#' Default decimal separator (period for international format)
#'
#' Common values: "." (international) or "," (European)
DEFAULT_DECIMAL_SEPARATOR <- "."


# ==============================================================================
# Validation Constants
# ==============================================================================

#' Maximum sheet name length in Excel
#'
#' Excel limit: 31 characters
MAX_EXCEL_SHEET_NAME_LENGTH <- 31

#' Pattern for wave column naming in question mapping
#'
#' Expected format: Wave1, Wave2, Wave3, etc.
WAVE_COLUMN_PATTERN <- "^Wave\\d+$"


# ==============================================================================
# Weight Validation Constants
# ==============================================================================

#' Minimum valid weight value
#'
#' Weights must be positive (> 0)
MIN_VALID_WEIGHT <- 0


# ==============================================================================
# Report Types
# ==============================================================================

#' Valid report types for run_tracker()
VALID_REPORT_TYPES <- c("detailed", "wave_history", "dashboard", "sig_matrix", "tracking_crosstab")


# ==============================================================================
# Safe Accessor Helpers
# ==============================================================================

#' Safe Wave Result Access
#'
#' Safely access a wave result from a wave_results list. Returns a
#' default unavailable structure if the wave_id is NULL, missing, or
#' the result itself is NULL.
#'
#' @param wave_results List of wave results indexed by wave ID
#' @param wave_id Character. The wave ID to look up
#' @return The wave result list, or a default list with available = FALSE
#' @keywords internal
safe_wave_result <- function(wave_results, wave_id) {
  if (is.null(wave_results) || is.null(wave_id) || !wave_id %in% names(wave_results)) {
    return(list(available = FALSE, n_unweighted = 0, n_weighted = 0, eff_n = 0))
  }
  result <- wave_results[[wave_id]]
  if (is.null(result)) {
    return(list(available = FALSE, n_unweighted = 0, n_weighted = 0, eff_n = 0))
  }
  result
}


# ==============================================================================
# Export Constants
# ==============================================================================

message("TurasTracker constants loaded (v1.0)")
