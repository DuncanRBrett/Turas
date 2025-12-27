# ==============================================================================
# MODULE: crosstabs_initialization.R
# ==============================================================================
# Purpose: Initialize TRS infrastructure, check dependencies, define constants
#
# This module handles the foundational setup for crosstab analysis:
# - TRS guard layer and infrastructure
# - Package dependency checks
# - Constant definitions (thresholds, labels, limits)
# - Utility functions for formatting
#
# Version: 10.0
# TRS Compliance: v1.0
# ==============================================================================

# ==============================================================================
# MODULE OUTPUT CONTRACT
# ==============================================================================
#
# All analysis modules should return a list with these keys:
#
# all_results (list of lists):
#   question_code (character): Question identifier
#   question_text (character): Display text
#   question_type (character): Variable_Type
#   base_filter (character): Any applied filter
#   bases (list): Base sizes by banner column
#     - $unweighted (numeric)
#     - $weighted (numeric)
#     - $effective (numeric)
#   table (data.frame): Results table with:
#     - RowLabel (character)
#     - RowType (character): "Frequency", "Column %", "Row %", "Average", etc.
#     - [banner_columns] (numeric): One column per banner
#
# This contract allows:
# - Consistent Excel writing across modules
# - Shared validation of outputs
# - Common charting/reporting layer (future)
#
# ==============================================================================

# ==============================================================================
# TRS GUARD LAYER - Must be loaded FIRST
# ==============================================================================

# Determine script directory for sourcing (only if not already set by parent)
if (!exists("script_dir")) {
  script_dir <- if (exists("toolkit_path")) dirname(toolkit_path) else getwd()
}

# TRS Guard Layer (v1.0) - MUST be loaded before any TRS refusal calls
source(file.path(script_dir, "00_guard.R"))

# ==============================================================================
# TRS INFRASTRUCTURE (TRS v1.0)
# ==============================================================================

# Source TRS run state management
.source_trs_infrastructure_tabs <- function() {
  # Try multiple paths to find shared/lib
  possible_paths <- c(
    file.path(script_dir, "..", "..", "shared", "lib"),
    file.path(script_dir, "..", "shared", "lib"),
    file.path(getwd(), "modules", "shared", "lib"),
    file.path(getwd(), "..", "shared", "lib")
  )

  trs_files <- c("trs_run_state.R", "trs_banner.R", "trs_run_status_writer.R")

  for (shared_lib in possible_paths) {
    if (dir.exists(shared_lib)) {
      for (f in trs_files) {
        fpath <- file.path(shared_lib, f)
        if (file.exists(fpath)) {
          source(fpath)
        }
      }
      break
    }
  }
}

tryCatch({
  .source_trs_infrastructure_tabs()
}, error = function(e) {
  message(sprintf("[TRS INFO] TABS_TRS_LOAD: Could not load TRS infrastructure: %s", e$message))
})

# Create TRS run state for tracking events
trs_state <- if (exists("turas_run_state_new", mode = "function")) {
  turas_run_state_new("TABS")
} else {
  NULL
}

# ==============================================================================
# DEPENDENCY CHECKS (Friendly error messages)
# ==============================================================================

#' Check required packages with friendly errors
#'
#' @return Invisible NULL or stops with helpful message
check_dependencies <- function() {
  required_packages <- c("openxlsx", "readxl")
  missing <- character(0)

  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      missing <- c(missing, pkg)
    }
  }

  if (length(missing) > 0) {
    # TRS Refusal: PKG_MISSING_PACKAGES
    tabs_refuse(
      code = "PKG_MISSING_PACKAGES",
      title = "Missing Required Packages",
      problem = paste0("Required packages not installed: ", paste(missing, collapse = ", ")),
      why_it_matters = "Crosstab analysis requires these packages to function properly.",
      how_to_fix = c(
        "Install the missing packages with:",
        paste0("  install.packages(c(", paste(sprintf('"%s"', missing), collapse = ", "), "))")
      ),
      missing = missing
    )
  }

  # Optional but recommended (V10.0: lobstr replaces deprecated pryr)
  if (!requireNamespace("lobstr", quietly = TRUE)) {
    message("Note: 'lobstr' package not found. Memory monitoring will be disabled.")
  }

  invisible(NULL)
}

# ==============================================================================
# CONSTANTS
# ==============================================================================

# Column and Row Labels
TOTAL_COLUMN <- "Total"
SIG_ROW_TYPE <- "Sig."
BASE_ROW_LABEL <- "Base (n=)"
UNWEIGHTED_BASE_LABEL <- "Base (unweighted)"
WEIGHTED_BASE_LABEL <- "Base (weighted)"
EFFECTIVE_BASE_LABEL <- "Effective base"
FREQUENCY_ROW_TYPE <- "Frequency"
COLUMN_PCT_ROW_TYPE <- "Column %"
ROW_PCT_ROW_TYPE <- "Row %"
AVERAGE_ROW_TYPE <- "Average"
INDEX_ROW_TYPE <- "Index"
SCORE_ROW_TYPE <- "Score"

# Statistical Thresholds
MINIMUM_BASE_SIZE <- 30
VERY_SMALL_BASE_SIZE <- 10
DEFAULT_ALPHA <- 0.05  # P-value threshold (not confidence level)
DEFAULT_MIN_BASE <- 30

# Excel Limits
MAX_EXCEL_COLUMNS <- 16384
MAX_EXCEL_ROWS <- 1048576

# Performance Settings
BATCH_WRITE_THRESHOLD <- 100
VECTORIZE_THRESHOLD <- 50
CHECKPOINT_FREQUENCY <- 10

# Memory Thresholds (GiB = 1024^3 bytes)
MEMORY_WARNING_GIB <- 6
MEMORY_CRITICAL_GIB <- 8

# Decimal validation limits
MAX_DECIMAL_PLACES <- 6

# ==============================================================================
# FORMATTING UTILITIES
# ==============================================================================

#' Format value for output (NA handling for Excel)
#'
#' Returns NA_real_ which Excel writer displays as blank cell
#'
#' @param value Numeric value
#' @param type Value type
#' @param decimal_places_percent Integer
#' @param decimal_places_ratings Integer
#' @param decimal_places_index Integer
#' @param decimal_places_numeric Integer
#' @return Formatted numeric or NA_real_
#' @export
format_output_value <- function(value, type = "frequency",
                               decimal_places_percent = 0,
                               decimal_places_ratings = 1,
                               decimal_places_index = 1,
                               decimal_places_numeric = 1) {
  if (is.null(value) || is.na(value)) return(NA_real_)

  formatted_value <- switch(type,
    "percent" = round(as.numeric(value), decimal_places_percent),
    "rating" = round(as.numeric(value), decimal_places_ratings),
    "index" = round(as.numeric(value), decimal_places_index),
    "numeric" = round(as.numeric(value), decimal_places_numeric),
    "frequency" = round(as.numeric(value), 0),
    round(as.numeric(value), 2)
  )

  return(formatted_value)
}

# ==============================================================================
# END OF MODULE: crosstabs_initialization.R
# ==============================================================================
