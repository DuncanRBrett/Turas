# ==============================================================================
# RANKING V10.0 - MODULAR ARCHITECTURE
# ==============================================================================
# Functions for ranking question analysis with statistical rigor
# Part of R Survey Analytics Toolkit
#
# VERSION HISTORY:
# V10.0 - Modular refactoring (2025-12-27)
#         - REFACTORED: Split 1,929-line monolith into focused modules
#         - CREATED: ranking_validation.R (~400 lines)
#         - CREATED: ranking_extraction.R (~400 lines)
#         - CREATED: ranking_calculations.R (~500 lines)
#         - CREATED: ranking_statistics.R (~200 lines)
#         - CREATED: ranking_banners.R (~300 lines)
#         - MAINTAINED: All V9.9.3 functionality and TRS v1.0 compliance
#         - IMPROVED: Maintainability, testability, and code organization
# V9.9.3 - External review fix (2025-10-16)
#          - FIXED: Fail-fast numeric coercion guard in validate_ranking_matrix()
#          - Prevents silent character matrix conversion
#          - Checks all columns are numeric/integer64 before as.matrix()
#          - Enforces storage.mode = "double" for numeric matrix
# V9.9.2 - External review fixes (production hardening)
#          - FIXED: Item format rank misnumbering (derive from column name)
#          - FIXED: Vectorized Item→Position (O(R×I) not O(R×I×P), 3-5x faster)
#          - ADDED: Configurable validation thresholds (tie, gap, completeness)
#          - ADDED: Guard top_n vs num_positions (auto-clamp + warn)
#          - ADDED: Rank direction normalization (Worst-to-Best support)
#          - FIXED: Return shape parity (removed weights from first/top-n)
#          - IMPROVED: Named args in format_output_value calls
#          - ADDED: Item matching hygiene (trim whitespace in extraction)
#          - IMPROVED: Vectorized validation loops (apply-based, faster)
#          - ADDED: Configurable ranking_min_base from config
#          - ADDED: Legend note for mean rank interpretation
#          - MODULE COMPLETE & LOCKED FOR PRODUCTION
# V9.9.1 - World-class production release
# V8.0   - Previous version (DEPRECATED)
#
# RANKING METHODOLOGY:
# This script handles two ranking formats:
# 1. Position format: Each item has a column with rank (Q_BrandA = 3)
# 2. Item format: Each rank position has item name (Q_Rank1 = "BrandA")
#
# Statistical approach:
# - Mean rank: Lower is better (1st place = 1, 2nd = 2, etc.)
# - Weighted mean: Uses design weights with effective-n
# - Variance: Population variance for weighted data
# - Significance: t-tests on mean ranks using effective-n
# - Top-N: Percentage in top N positions (e.g., top 3 box)
#
# RANK DIRECTION:
# - Best-to-Worst (default): 1 = best, higher = worse
# - Worst-to-Best: 1 = worst, higher = better (auto-normalized to Best-to-Worst)
#
# MODULAR ARCHITECTURE:
# - ranking.R (this file): Orchestration, dependencies, partial failure tracking
# - ranking_validation.R: Data quality validation and checking
# - ranking_extraction.R: Data extraction from Position/Item formats
# - ranking_calculations.R: Metric calculations (% first, mean, top-N, variance)
# - ranking_statistics.R: Statistical comparisons and significance testing
# - ranking_banners.R: Crosstab row generation for banner analysis
# ==============================================================================

SCRIPT_VERSION <- "10.0"

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

# Use shared_functions.R version if available, otherwise define minimal fallback
if (!exists("source_if_exists")) {
  source_if_exists <- function(file_path, envir = parent.frame()) {
    if (file.exists(file_path)) {
      tryCatch({
        sys.source(file_path, envir = envir)
        invisible(NULL)
      }, error = function(e) {
        warning(sprintf(
          "Failed to source %s: %s\nSome functions may not be available.",
          file_path,
          conditionMessage(e)
        ), call. = FALSE)
        invisible(NULL)
      })
    }
  }
}

# Source shared utilities
source_if_exists("shared_functions.R")
source_if_exists("Scripts/shared_functions.R")
source_if_exists("weighting.R")
source_if_exists("Scripts/weighting.R")

# Source ranking modules (V10.0: Modular architecture)
source_if_exists("ranking_validation.R")
source_if_exists("modules/tabs/lib/ranking_validation.R")
source_if_exists("ranking_extraction.R")
source_if_exists("modules/tabs/lib/ranking_extraction.R")
source_if_exists("ranking_calculations.R")
source_if_exists("modules/tabs/lib/ranking_calculations.R")
source_if_exists("ranking_statistics.R")
source_if_exists("modules/tabs/lib/ranking_statistics.R")
source_if_exists("ranking_banners.R")
source_if_exists("modules/tabs/lib/ranking_banners.R")

# ==============================================================================
# TRS v1.0: RANKING PARTIAL FAILURE TRACKING
# ==============================================================================
# Environment-based tracking of partial failures during ranking processing.
# The orchestrator can call ranking_get_partial_failures() after processing
# to collect any section-level failures that occurred.

# Private environment to track partial failures
.ranking_state <- new.env(parent = emptyenv())
.ranking_state$partial_failures <- list()

#' Reset ranking partial failures
#' Call before processing each question
#' @export
ranking_reset_partial_failures <- function() {
  .ranking_state$partial_failures <- list()
  invisible(NULL)
}

#' Record a ranking partial failure
#' @param section Character, the section that failed
#' @param stage Character, the processing stage
#' @param error Character, the error message
#' @keywords internal
ranking_record_partial_failure <- function(section, stage, error) {
  .ranking_state$partial_failures[[length(.ranking_state$partial_failures) + 1]] <- list(
    section = section,
    stage = stage,
    error = error
  )
  invisible(NULL)
}

#' Get ranking partial failures
#' Call after processing to collect any failures
#' @return List of partial failure records
#' @export
ranking_get_partial_failures <- function() {
  return(.ranking_state$partial_failures)
}

# ==============================================================================
# MAINTENANCE DOCUMENTATION
# ==============================================================================
#
# OVERVIEW:
# This script handles ranking question analysis with statistical rigor.
# Supports both Position and Item ranking formats with comprehensive
# validation, weighted analysis, and significance testing.
#
# V10.0 MODULAR REFACTORING (2025-12-27):
# - Split 1,929-line monolith into 6 focused modules for maintainability
# - Each module has clear responsibility and ~200-500 lines
# - All V9.9.3 functionality preserved (100% backward compatible)
# - Improved testability: each module can be tested independently
# - Better code navigation: find functions by logical grouping
# - Maintained TRS v1.0 partial failure tracking in main file
# - Orchestration functions remain in main ranking.R
#
# MODULE RESPONSIBILITIES:
# 1. ranking_validation.R: Data quality checks, validation helpers
# 2. ranking_extraction.R: Format detection, data extraction, normalization
# 3. ranking_calculations.R: Metric calculations (%, mean, variance)
# 4. ranking_statistics.R: Statistical comparisons, significance tests
# 5. ranking_banners.R: Crosstab row generation, banner analysis
# 6. ranking.R (main): Orchestration, dependencies, partial failure tracking
#
# V9.9.3 ENHANCEMENTS (EXTERNAL REVIEW FIX):
# 1. FIXED: Fail-fast numeric coercion guard in validate_ranking_matrix()
#    - If data.frame has ANY character column, as.matrix() silently converts
#      entire matrix to character, breaking all numeric calculations
#    - Now checks all columns are numeric/integer64 before conversion
#    - Enforces storage.mode = "double" for numeric matrix
#    - Provides clear error message if non-numeric columns found
#
# V9.9.2 IMPROVEMENTS (EXTERNAL REVIEW):
# 1. FIXED: Item format rank misnumbering (derive from column name)
# 2. FIXED: Fully vectorized Item→Position (3-5x faster, cleaner code)
# 3. ADDED: Configurable validation thresholds (tie, gap, completeness)
# 4. ADDED: Guard top_n vs num_positions (auto-clamp + warn)
# 5. ADDED: Rank direction normalization (Worst-to-Best support)
# 6. FIXED: Return shape parity (removed weights from returns)
# 7. IMPROVED: Named args in format_output_value calls (safer)
# 8. ADDED: Item matching hygiene (whitespace trimming)
# 9. IMPROVED: Vectorized validation loops (apply-based, faster)
# 10. ADDED: Configurable ranking_min_base from config
# 11. ADDED: Legend note for mean rank interpretation ("Lower = Better")
#
# MODULE COMPLETE & PRODUCTION-READY
#
# TESTING PROTOCOL:
# 1. Unit tests for all metrics
# 2. Format conversion (Position ↔ Item, both directions)
# 3. Edge cases (ties, gaps, incomplete, out-of-range, top_n>positions)
# 4. Weighted vs unweighted (match expectations)
# 5. Significance testing (known rankings)
# 6. Performance (vectorized, no O(n²))
# 7. V9.9.2: Rank numbering with missing columns
# 8. V9.9.2: Direction normalization (Worst-to-Best → Best-to-Worst)
# 9. V9.9.3: Character column detection (fail-fast test)
# 10. V10.0: Module integration (all functions accessible, no regressions)
#
# CONFIGURATION OPTIONS (V9.9.2+):
# - ranking_tie_threshold_pct: Tie warning threshold (default: 5%)
# - ranking_gap_threshold_pct: Gap warning threshold (default: 5%)
# - ranking_completeness_threshold_pct: Completeness threshold (default: 80%)
# - ranking_min_base: Minimum base for significance testing (default: 10)
#
# BACKWARD COMPATIBILITY:
# - V8.0 → V10.0: MOSTLY COMPATIBLE (new params have defaults)
# - V9.9.1 → V10.0: FULLY COMPATIBLE (refactoring only, no API changes)
# - V9.9.2 → V10.0: FULLY COMPATIBLE (refactoring only, no API changes)
# - V9.9.3 → V10.0: FULLY COMPATIBLE (refactoring only, no API changes)
#
# COMMON ISSUES:
# 1. "Ranking columns not numeric": Character column in data - check data types
# 2. "Cannot parse rank position": Column name doesn't match _Rank# pattern
# 3. "Invalid Ranking_Format": Check Survey_Structure Ranking_Format column
# 4. "No ranking columns found": Verify column names match expected pattern
# 5. "top_n exceeds positions": Auto-clamped with warning
# 6. "Module not found": Ensure all ranking_*.R files are in lib/ directory
#
# MIGRATION GUIDE (V9.9.3 → V10.0):
# - No code changes required for users of ranking functions
# - All public API functions remain in same namespace
# - Module files must be present in modules/tabs/lib/ directory
# - If deploying, include all 6 ranking_*.R files (not just ranking.R)
# - All functions automatically exported through module sourcing
#
# REFACTORING BENEFITS:
# - Reduced cognitive load: ~200-400 lines per file vs 1,929 lines
# - Faster navigation: find validation code in validation module
# - Easier testing: test extraction independently from calculation
# - Better collaboration: multiple developers can work on different modules
# - Clearer dependencies: see exactly what each module needs
# - Simplified debugging: smaller surface area per file
#
# ==============================================================================
# END OF RANKING.R V10.0 - MODULAR ARCHITECTURE
# ==============================================================================
