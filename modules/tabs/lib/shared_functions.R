# ==============================================================================
# SHARED FUNCTIONS - TURAS V10.1 (Phase 3 Refactoring)
# ==============================================================================
# Module orchestrator that sources all utility modules in correct dependency order
# This is the main entry point for common utilities used across all analysis types
#
# VERSION HISTORY:
# V10.1 - Phase 3 Refactoring (December 2025)
#        - Extracted to focused utility modules:
#          * validation_utils.R - Input validation functions
#          * path_utils.R - Path handling and sourcing
#          * data_loader.R - Survey structure and data loading
#          * filter_utils.R - Base filter application
#        - Removed duplicated functions (now in utility modules)
#        - Reduced from 2,001 lines to ~350 lines (83% reduction)
#
# V10.0 - Numeric question support, modular utilities sourcing
# V9.9.1 - External review fixes (duplicate detection, typed getters)
# V9.9 - Production release (proper Excel letters, SPSS support)
#
# MAINTENANCE NOTES:
# - This file now acts as an ORCHESTRATOR - sources modules in correct order
# - All utility functions live in dedicated modules for better maintainability
# - Changes to individual utilities should be made in their respective modules
# - This file maintains backward compatibility - all functions still available
#
# ==============================================================================

SCRIPT_VERSION <- "10.1"
SHARED_FUNCTIONS_VERSION <- "10.1"  # For version checking by other modules

# ==============================================================================
# CONSTANTS
# ==============================================================================

# File Size Limits (bytes)
MAX_FILE_SIZE_MB <- 500
MAX_FILE_SIZE_BYTES <- MAX_FILE_SIZE_MB * 1024 * 1024

# Excel Limits
MAX_EXCEL_COLUMNS <- 16384
MAX_EXCEL_ROWS <- 1048576

# Validation Limits
MAX_DECIMAL_PLACES <- 6
MIN_SAMPLE_SIZE <- 1

# Supported File Types
SUPPORTED_DATA_FORMATS <- c("xlsx", "xls", "csv", "sav")
SUPPORTED_CONFIG_FORMATS <- c("xlsx", "xls")


# ==============================================================================
# SCRIPT DIRECTORY RESOLUTION
# ==============================================================================

# Determine script directory
if (!exists("script_dir")) {
  script_dir <- tryCatch({
    dirname(sys.frame(1)$ofile)
  }, error = function(e) getwd())
}

# Cache the lib directory for reliable subdirectory sourcing (V10.1 Phase 2 Support)
if (!exists(".tabs_lib_dir", envir = globalenv())) {
  assign(".tabs_lib_dir", script_dir, envir = globalenv())
}


# ==============================================================================
# SOURCE UTILITY MODULES (V10.1 - Phase 3 Refactoring)
# ==============================================================================
# IMPORTANT: Order matters! Dependencies must be sourced first.
#
# Dependency order:
# 1. 00_guard.R - provides tabs_refuse() error handling
# 2. validation_utils.R - input validation (needs tabs_refuse)
# 3. path_utils.R - path handling (needs tabs_refuse)
# 4. type_utils.R - type conversions (no dependencies)
# 5. logging_utils.R - logging (no dependencies)
# 6. config_utils.R - config loading (needs validation_utils, tabs_refuse)
# 7. excel_utils.R - Excel utilities (needs validation_utils)
# 8. data_loader.R - data loading (needs validation_utils, path_utils, config_utils)
# 9. filter_utils.R - filter application (needs tabs_refuse)
# ==============================================================================

# Source 00_guard.R first (provides tabs_refuse)
source(file.path(script_dir, "00_guard.R"))

# Source validation utilities (Phase 3)
source(file.path(script_dir, "validation_utils.R"))

# Source path utilities (Phase 3)
source(file.path(script_dir, "path_utils.R"))

# Source type utilities (Phase 1)
source(file.path(script_dir, "type_utils.R"))

# Source logging utilities (Phase 1)
source(file.path(script_dir, "logging_utils.R"))

# Source config utilities (Phase 1)
source(file.path(script_dir, "config_utils.R"))

# Source Excel utilities (Phase 1)
source(file.path(script_dir, "excel_utils.R"))

# Source data loader (Phase 3)
source(file.path(script_dir, "data_loader.R"))

# Source filter utilities (Phase 3)
source(file.path(script_dir, "filter_utils.R"))


# ==============================================================================
# HELPER FUNCTIONS (Not extracted - simple utilities)
# ==============================================================================

#' Calculate percentage
#'
#' USAGE: Calculate percentages with automatic 0/0 handling
#' DESIGN: Returns NA_real_ for division by zero (not 0 or error)
#'
#' @param numerator Numeric, numerator
#' @param denominator Numeric, denominator
#' @param decimal_places Integer, decimal places for rounding (default: 0)
#' @return Numeric, percentage (0-100 scale) or NA_real_
#' @export
#' @examples
#' calc_percentage(50, 100)     # 50
#' calc_percentage(1, 3, 1)     # 33.3
#' calc_percentage(10, 0)       # NA
calc_percentage <- function(numerator, denominator, decimal_places = 0) {
  if (is.na(denominator) || denominator == 0) {
    return(NA_real_)
  }

  return(round((numerator / denominator) * 100, decimal_places))
}


#' Create empty error log data frame
#'
#' STRUCTURE: Timestamp, Component, Issue_Type, Description, QuestionCode, Severity
#' USAGE: Initialize at start of analysis, populate during validation
#'
#' @return Empty error log data frame
#' @export
create_error_log <- function() {
  data.frame(
    Timestamp = character(),
    Component = character(),
    Issue_Type = character(),
    Description = character(),
    QuestionCode = character(),
    Severity = character(),
    stringsAsFactors = FALSE
  )
}


#' Safely execute with error handling
#'
#' @param expr Expression to evaluate
#' @param default Default value on error
#' @param error_msg Error message prefix
#' @param silent Suppress warnings
#' @return Result or default
#' @export
safe_execute <- function(expr, default = NA, error_msg = "Operation failed",
                        silent = FALSE) {
  tryCatch(
    expr,
    error = function(e) {
      if (!silent) {
        warning(sprintf("%s: %s", error_msg, conditionMessage(e)), call. = FALSE)
      }
      return(default)
    }
  )
}


#' Batch rbind (column-safe)
#'
#' Combines a list of data frames by rows.
#' Handles column mismatches by adding missing columns with NA values
#' before binding, preventing "numbers of columns do not match" errors.
#'
#' @param row_list List of data frames
#' @return Single data frame
#' @export
batch_rbind <- function(row_list) {
  if (length(row_list) == 0) return(data.frame())
  # Normalize columns across all data frames to prevent mismatch errors
  all_cols <- unique(unlist(lapply(row_list, names)))
  row_list <- lapply(row_list, function(df) {
    missing_cols <- setdiff(all_cols, names(df))
    for (col in missing_cols) {
      df[[col]] <- NA
    }
    df[, all_cols, drop = FALSE]
  })
  do.call(rbind, row_list)
}


# ==============================================================================
# VERSION & BRANDING
# ==============================================================================

#' Get toolkit version
#'
#' @return Character, version string
#' @export
get_toolkit_version <- function() {
  return(SCRIPT_VERSION)
}


#' Print toolkit header
#'
#' USAGE: Display at start of analysis scripts for branding
#'
#' @param analysis_type Character, type of analysis being run
#' @export
print_toolkit_header <- function(analysis_type = "Analysis") {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
  cat("  R SURVEY ANALYTICS TOOLKIT V", get_toolkit_version(), "\n", sep = "")
  cat("  ", analysis_type, "\n", sep = "")
  cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
  cat("\n")
}


# ==============================================================================
# BACKWARD COMPATIBILITY EXPORTS
# ==============================================================================
# All functions are now available through the sourced modules.
# This section documents what's available for users of shared_functions.R
#
# FROM validation_utils.R:
#   - validate_data_frame()
#   - validate_numeric_param()
#   - validate_logical_param()
#   - validate_char_param()
#   - validate_file_path()
#   - validate_column_exists()
#   - validate_weights()
#   - has_data()
#
# FROM path_utils.R:
#   - tabs_lib_path()
#   - tabs_source()
#   - resolve_path()
#   - get_project_root()
#   - is_package_available()
#   - source_if_exists()
#
# FROM type_utils.R:
#   - safe_equal()
#   - safe_numeric()
#   - safe_logical()
#   - safe_char()
#
# FROM logging_utils.R:
#   - log_message()
#   - log_progress()
#   - format_seconds()
#   - add_log_entry() / log_issue()
#   - check_memory()
#
# FROM config_utils.R:
#   - load_config_sheet()
#   - get_config_value()
#   - get_numeric_config()
#   - get_logical_config()
#   - get_char_config()
#
# FROM excel_utils.R:
#   - generate_excel_letters()
#   - excel_column_letter()
#   - format_output_value()
#
# FROM data_loader.R:
#   - load_survey_structure()
#   - load_survey_data()
#   - load_survey_data_smart()
#
# FROM filter_utils.R:
#   - apply_base_filter()
#   - clean_filter_expression()
#   - check_filter_security()
#   - validate_filter_result()
#
# ==============================================================================


# ==============================================================================
# MAINTENANCE DOCUMENTATION
# ==============================================================================
#
# OVERVIEW:
# This script is now an ORCHESTRATOR that sources utility modules.
# All utility functions have been extracted to focused modules.
#
# MODULE STRUCTURE (V10.1):
# shared_functions.R (THIS FILE - orchestrator)
#   ├─→ Sources: 00_guard.R (TRS error handling)
#   ├─→ Sources: validation_utils.R (input validation)
#   ├─→ Sources: path_utils.R (path handling)
#   ├─→ Sources: type_utils.R (type conversions)
#   ├─→ Sources: logging_utils.R (logging utilities)
#   ├─→ Sources: config_utils.R (config loading)
#   ├─→ Sources: excel_utils.R (Excel utilities)
#   ├─→ Sources: data_loader.R (data loading)
#   └─→ Sources: filter_utils.R (filter application)
#
# TESTING PROTOCOL:
# Before deploying changes to production:
# 1. Source shared_functions.R - verify all modules load correctly
# 2. Run test suite for each module
# 3. Run integration tests with run_crosstabs.R
# 4. Test with small dataset (fast feedback)
# 5. Test with large dataset (performance validation)
#
# BACKWARD COMPATIBILITY:
# - V10.0 → V10.1: All functions remain available
# - Function signatures unchanged
# - All existing code will work without modification
#
# PERFORMANCE:
# - Module sourcing adds ~10ms at startup
# - Function execution performance unchanged
# - Better maintainability outweighs minimal startup cost
#
# REFACTORING HISTORY:
# Phase 1 (V10.0): Extracted type_utils, config_utils, logging_utils, excel_utils
# Phase 2 (V10.1): Extracted validation/ and ranking/ subdirectory modules
# Phase 3 (V10.1): Extracted validation_utils, path_utils, data_loader, filter_utils
#                  Removed all duplicated functions from shared_functions.R
#                  Reduced from 2,001 lines to ~350 lines (83% reduction)
#
# ==============================================================================
# END OF SHARED_FUNCTIONS.R V10.1
# ==============================================================================
