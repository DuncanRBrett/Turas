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
# Export Constants
# ==============================================================================

message("TurasTracker constants loaded (v1.0)")
