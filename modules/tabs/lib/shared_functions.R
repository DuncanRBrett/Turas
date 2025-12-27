# ==============================================================================
# SHARED FUNCTIONS - TURAS V10.0
# ==============================================================================
# Common utilities used across all analysis types
# Part of R Survey Analytics Toolkit
#
# VERSION HISTORY:
# Turas v10.0 - Modularization refactor (2025)
#          - REFACTORED: Split 1,910-line file into focused modules for maintainability
#          - CREATED: 8 new focused module files (validation, config, paths, etc.)
#          - MAINTAINED: All function signatures unchanged for backward compatibility
#          - IMPROVED: Code organization and discoverability
# Turas v10.0 - Numeric question support (2025)
#          - FIXED: format_output_value() now supports numeric question type
#          - ADDED: decimal_places_numeric parameter to format_output_value()
#          - ADDED: SHARED_FUNCTIONS_VERSION constant for version checking
# V9.9.1 - External review fixes (2024)
#          - FIXED: Extension validation now works for output files (must_exist=FALSE)
#          - FIXED: Duplicate config settings now detected and blocked
#          - ADDED: Typed config getters (get_numeric_config, get_logical_config, get_char_config)
#          - ADDED: .sav label normalization option (convert_labelled parameter)
#          - FIXED: safe_equal() NA handling (real NA vs "NA" string)
#          - ADDED: source_if_exists() environment control
#          - ADDED: CSV fast-path via data.table when available
#          - IMPROVED: log_issue() documentation for batch accumulation pattern
# V9.9   - Production release (aligned with run_crosstabs.r V9.9)
#          - FIXED: Excel letter generation (proper base-26 algorithm)
#          - ADDED: Comprehensive input validation functions
#          - ADDED: .sav (SPSS) file support via haven package
# V8.0   - Previous version (deprecated)
#
# MAINTENANCE NOTES:
# - This is a FOUNDATIONAL script - changes affect all toolkit components
# - Always run full integration tests after modifications
# - Performance-critical functions marked with [PERFORMANCE]
# - See MODULE STRUCTURE section below for file organization
# ==============================================================================

SCRIPT_VERSION <- "10.0"
SHARED_FUNCTIONS_VERSION <- "10.0"  # For version checking by other modules

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
# DEPENDENCY MANAGEMENT
# ==============================================================================

#' Check if package is available
#'
#' @param package_name Character, package name
#' @return Logical, TRUE if available
is_package_available <- function(package_name) {
  requireNamespace(package_name, quietly = TRUE)
}

#' Safely source file if it exists (V9.9.1: Environment control added)
#'
#' SECURITY: Sources into specified environment to prevent namespace pollution
#' DEFAULT: Sources into caller's environment (parent.frame())
#'
#' @param file_path Character, path to R script
#' @param envir Environment, where to source (default: parent.frame())
#' @return Invisible NULL
source_if_exists <- function(file_path, envir = parent.frame()) {
  if (file.exists(file_path)) {
    tryCatch({
      source(file_path, local = envir)
      invisible(NULL)
    }, error = function(e) {
      warning(sprintf("Failed to source %s: %s", file_path, conditionMessage(e)))
      invisible(NULL)
    })
  }
}

# ==============================================================================
# MODULE LOADING
# ==============================================================================
# The large shared_functions.R has been refactored into focused modules for
# better maintainability. Each module is loaded below.
#
# MODULE STRUCTURE:
# - shared_validation.R    : Input validation functions
# - shared_config.R        : Configuration loading and access
# - shared_paths.R         : Path resolution utilities
# - shared_safe_ops.R      : Safe type conversions and operations
# - shared_data_loading.R  : Survey data and structure loading
# - shared_filters.R       : Filter expression handling
# - shared_logging.R       : Logging and progress tracking
# - shared_formatting.R    : Output formatting utilities
#
# BACKWARD COMPATIBILITY:
# All functions maintain their original signatures and behavior. Existing
# code that sources shared_functions.R will continue to work without changes.
# ==============================================================================

# Determine the directory containing this script
SHARED_FUNCTIONS_DIR <- getSrcDirectory(function() {})
if (SHARED_FUNCTIONS_DIR == "") {
  # Fallback for interactive use or when getSrcDirectory doesn't work
  SHARED_FUNCTIONS_DIR <- dirname(sys.frame(1)$ofile)
  if (is.null(SHARED_FUNCTIONS_DIR) || SHARED_FUNCTIONS_DIR == "") {
    SHARED_FUNCTIONS_DIR <- getwd()
  }
}

# Load all module files
cat("Loading shared functions modules...\n")

source_if_exists(file.path(SHARED_FUNCTIONS_DIR, "shared_validation.R"))
source_if_exists(file.path(SHARED_FUNCTIONS_DIR, "shared_config.R"))
source_if_exists(file.path(SHARED_FUNCTIONS_DIR, "shared_paths.R"))
source_if_exists(file.path(SHARED_FUNCTIONS_DIR, "shared_safe_ops.R"))
source_if_exists(file.path(SHARED_FUNCTIONS_DIR, "shared_data_loading.R"))
source_if_exists(file.path(SHARED_FUNCTIONS_DIR, "shared_filters.R"))
source_if_exists(file.path(SHARED_FUNCTIONS_DIR, "shared_logging.R"))
source_if_exists(file.path(SHARED_FUNCTIONS_DIR, "shared_formatting.R"))

cat("✓ Shared functions loaded (V", SHARED_FUNCTIONS_VERSION, ")\n", sep = "")

# ==============================================================================
# MAINTENANCE DOCUMENTATION
# ==============================================================================
#
# OVERVIEW:
# This script provides foundational utilities used across ALL toolkit components.
# Changes here affect: run_crosstabs.r, validation.R, weighting.R, ranking.R
#
# MODULAR STRUCTURE (V10.0):
# The monolithic 1,910-line shared_functions.R has been refactored into focused
# modules for better maintainability, discoverability, and testing:
#
# 1. shared_validation.R (~350 lines)
#    - validate_data_frame(), validate_numeric_param(), validate_logical_param()
#    - validate_char_param(), validate_file_path(), validate_column_exists()
#    - validate_weights()
#
# 2. shared_config.R (~350 lines)
#    - load_config_sheet(), get_config_value()
#    - get_numeric_config(), get_logical_config(), get_char_config()
#
# 3. shared_paths.R (~150 lines)
#    - resolve_path(), get_project_root()
#
# 4. shared_safe_ops.R (~200 lines)
#    - safe_equal(), safe_numeric(), safe_logical()
#    - has_data(), safe_execute(), batch_rbind()
#
# 5. shared_data_loading.R (~450 lines)
#    - load_survey_structure(), load_survey_data(), load_survey_data_smart()
#
# 6. shared_filters.R (~250 lines)
#    - clean_filter_expression(), check_filter_security()
#    - validate_filter_result(), apply_base_filter()
#
# 7. shared_logging.R (~200 lines)
#    - log_message(), log_progress(), format_seconds()
#    - check_memory(), create_error_log(), add_log_entry()
#    - get_toolkit_version(), print_toolkit_header()
#
# 8. shared_formatting.R (~150 lines)
#    - generate_excel_letters(), format_output_value(), calc_percentage()
#
# TESTING PROTOCOL:
# Before deploying changes to production:
# 1. Run unit tests on changed functions (see test_shared_functions.R)
# 2. Run integration tests with all dependent scripts
# 3. Test with small dataset (fast feedback)
# 4. Test with large dataset (performance validation)
# 5. Test error cases (missing files, corrupted data, etc.)
#
# DEPENDENCY MAP:
#
# shared_functions.R (THIS FILE)
#   ├─→ Used by: run_crosstabs.r
#   ├─→ Used by: validation.R
#   ├─→ Used by: weighting.R
#   ├─→ Used by: ranking.R
#   └─→ External packages: readxl, tools, haven (optional), data.table (optional)
#
# CRITICAL FUNCTIONS (Extra care when modifying):
# - generate_excel_letters(): Used for significance testing column mapping
# - safe_equal(): Used for matching survey responses to options
# - load_survey_structure(): Core data loading function
# - validate_data_frame(): Used extensively for input validation
#
# PERFORMANCE NOTES:
# - Excel loading: Use load_survey_data_smart() for auto CSV caching (V10.0)
# - CSV with data.table: 10x faster than base read.csv (auto-enabled if available)
# - Path resolution: Results can be cached if calling repeatedly
# - Config loading: Cache config objects, don't reload on every function call
# - add_log_entry(): For 100+ entries, use list accumulation pattern (see function docs)
# - Memory monitoring: Uses lobstr::obj_size() (V10.0 - replaces deprecated pryr)
#
# BACKWARD COMPATIBILITY:
# - V8.0 → V9.9: Breaking changes in excel letter generation only
# - V9.9 → V9.9.1: All changes are additions (no breaking changes)
# - V9.9.1 → V10.0.0: New optional parameter (backward compatible)
#   - format_output_value() gains decimal_places_numeric parameter (optional, has default)
#   - All existing calls continue to work without modification
# - V10.0.0 → V10.0: All changes are backward compatible
#   - log_issue() kept as alias for new add_log_entry()
#   - load_survey_data() unchanged, new load_survey_data_smart() added as drop-in replacement
#   - pryr → lobstr only affects internal memory monitoring (no API change)
#   - Modularization: All functions maintain original signatures
# - Function signatures unchanged except new optional parameters
# - All V8.0 code calling these functions will work (with warnings)
#
# COMMON ISSUES:
# 1. "File not found" errors: Check working directory and relative paths
# 2. Excel file corruption: Try opening and re-saving in Excel
# 3. Memory issues with large files: Consider chunking or sampling
# 4. Case sensitivity: safe_equal() is case-sensitive by design
# 5. SPSS labelled columns: Use convert_labelled=TRUE if downstream code expects plain types
#
# VERSION HISTORY DETAIL:
# V10.0 (Current - Modularization):
# - Refactored 1,910-line file into 8 focused modules
# - Improved code organization and maintainability
# - All functions maintain backward compatibility
# - Added module loading infrastructure
# - Enhanced documentation for each module
#
# V10.0.0 (Numeric Question Support):
# - CRITICAL FIX: format_output_value() now supports "numeric" type (prevents crashes in numeric_processor.R)
# - Added decimal_places_numeric parameter to format_output_value()
# - Added SHARED_FUNCTIONS_VERSION constant for version checking
# - Improved NULL/NA handling in format_output_value()
# - Better error handling for edge cases
#
# V9.9.1 (External Review Fixes):
# - Fixed extension validation for output files (validate_extension_even_if_missing)
# - Fixed duplicate config settings detection (blocks silently overwriting values)
# - Added typed config getters (get_numeric_config, get_logical_config, get_char_config)
# - Fixed safe_equal() NA handling (real NA vs string "NA")
# - Added source_if_exists() environment control
# - Added CSV fast-path via data.table (10x speedup when available)
# - Added .sav label normalization option (convert_labelled parameter)
# - Added performance note for log_issue() batch pattern
#
# V9.9 (Production Release):
# - Fixed Excel letter bug (proper base-26 algorithm)
# - Added comprehensive validation functions
# - Added .sav (SPSS) support
# - Enhanced all error messages
# - Added performance documentation
# - Added maintenance documentation
#
# V8.0 (Deprecated):
# - Excel letter generation had bug after column Z
# - Missing modern validation functions
# - Limited file format support
# - Basic error messages
#
# ==============================================================================
# END OF SHARED_FUNCTIONS.R V10.0
# ==============================================================================
