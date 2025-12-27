# ==============================================================================
# WEIGHTING V10.0 - MODULAR ARCHITECTURE
# ==============================================================================
# Functions for weighted analysis and significance testing
# Part of R Survey Analytics Toolkit
#
# VERSION HISTORY:
# V10.0 - Modular refactoring (2025-12-27)
#         - REFACTORED: Split 1,590-line monolith into focused modules
#         - CREATED: weighting_validation.R (~290 lines)
#         - CREATED: weighting_calculations.R (~320 lines)
#         - CREATED: weighting_bases.R (~230 lines)
#         - CREATED: weighting_tests.R (~380 lines)
#         - CREATED: weighting_advanced.R (~270 lines)
#         - CREATED: weighting_summary.R (~80 lines)
#         - MAINTAINED: All V9.9.4 functionality and TRS v1.0 compliance
#         - IMPROVED: Maintainability, testability, and code organization
# V9.9.4 - Final polish (optional hardening from review)
#          - ADDED: Parameter validation for alpha and min_base in sig tests
#          - DOCUMENTED: n_eff rounding behavior (used in downstream SE/df)
#          - DOCUMENTED: Zero weight exclusion in calculate_effective_n
#          - All review feedback complete - PRODUCTION LOCKED
# V9.9.3 - Final production polish (all required fixes)
# V9.9.2 - External review fixes (correctness improvements)
# V9.9.1 - Production release (aligned with run_crosstabs.r V9.9)
# V8.0   - Previous version (DEPRECATED)
#
# STATISTICAL METHODOLOGY:
# This script implements weighted survey analysis following standard practices:
# - Effective sample size: n_eff = (Σw)² / Σw²  (Kish 1965)
# - Weighted variance: Population estimator Var = Σw(x - x̄)² / Σw
# - Significance testing: p_pooled from weighted counts, SE from effective-n
# - See individual modules for detailed methodology notes
#
# WEIGHT HANDLING POLICY (V9.9.2):
# - NA weights: Treated as 0 (excluded from analysis)
# - Zero weights: Kept as 0 (excluded from sums)
# - Negative weights: Error (design weights cannot be negative)
# - Infinite weights: Warning and excluded (set to 0)
# - This ensures correct base sizes and prevents bias from improper inclusion
#
# MODULAR ARCHITECTURE (V10.0):
# - weighting.R (this file): Orchestration, dependencies, version history
# - weighting_validation.R: Weight extraction, repair policies, validation
# - weighting_calculations.R: Effective-n, variance, counts, percentages, means
# - weighting_bases.R: Base calculations for different question types
# - weighting_tests.R: Significance tests (z-test, t-test)
# - weighting_advanced.R: Advanced tests (chi-square, net difference)
# - weighting_summary.R: Summary statistics and diagnostics
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
        source(file_path, local = envir)
        invisible(NULL)
      }, error = function(e) {
        warning(sprintf("Failed to source %s: %s", file_path, conditionMessage(e)))
        invisible(NULL)
      })
    }
  }
}

# Determine module directory (script_dir should be set by run_crosstabs.R)
.weighting_dir <- if (exists("script_dir") && !is.null(script_dir) && length(script_dir) > 0 && nzchar(script_dir[1])) {
  script_dir[1]
} else {
  getwd()
}

# ==============================================================================
# SOURCE WEIGHTING MODULES (V10.0: MODULAR ARCHITECTURE)
# ==============================================================================

# Weight extraction and validation
source_if_exists(file.path(.weighting_dir, "weighting_validation.R"))

# Core weighted calculations
source_if_exists(file.path(.weighting_dir, "weighting_calculations.R"))

# Base calculations for different question types
source_if_exists(file.path(.weighting_dir, "weighting_bases.R"))

# Significance testing (z-test, t-test)
source_if_exists(file.path(.weighting_dir, "weighting_tests.R"))

# Advanced tests (chi-square, net difference)
source_if_exists(file.path(.weighting_dir, "weighting_advanced.R"))

# Summary and diagnostics
source_if_exists(file.path(.weighting_dir, "weighting_summary.R"))

# ==============================================================================
# MAINTENANCE DOCUMENTATION
# ==============================================================================
#
# OVERVIEW:
# This script handles all weighted calculations and significance testing.
# Critical compatibility with run_crosstabs.r V9.9 - function signatures
# and return values MUST match exactly.
#
# V10.0 MODULAR REFACTORING (2025-12-27):
# - Split 1,590-line monolith into 7 focused modules for maintainability
# - Each module has clear responsibility and ~80-380 lines
# - All V9.9.4 functionality preserved (100% backward compatible)
# - Improved testability: each module can be tested independently
# - Better code navigation: find functions by logical grouping
# - Simplified debugging: smaller surface area per file
#
# MODULE RESPONSIBILITIES:
# 1. weighting_validation.R: Weight extraction, repair policies, validation
#    - get_weight_vector() and repair policy helpers
#    - Handles NA, zero, negative, infinite weights
#
# 2. weighting_calculations.R: Core weighted calculations
#    - calculate_effective_n() - Kish's formula
#    - weighted_variance() - Population variance
#    - calculate_weighted_count() - Weighted counts
#    - calculate_weighted_percentage() - Percentages
#    - calculate_weighted_mean() - Weighted means
#
# 3. weighting_bases.R: Base calculations for question types
#    - calculate_weighted_base() - Main dispatcher
#    - Helpers for multi-mention, ranking, single response
#
# 4. weighting_tests.R: Statistical significance tests
#    - weighted_z_test_proportions() - Z-test for proportions
#    - weighted_t_test_means() - T-test for means
#    - Statistical test helpers
#
# 5. weighting_advanced.R: Advanced statistical tests
#    - chi_square_test() - Chi-square independence test
#    - run_net_difference_tests() - Net difference testing
#
# 6. weighting_summary.R: Summary and diagnostics
#    - summarize_weights() - Weight distribution summary
#
# 7. weighting.R (main): Orchestration, dependencies, documentation
#
# V9.9.4 FINAL HARDENING (COMPLETE):
# All external review feedback addressed across 4 iterations:
# 1. V9.9.2: Proper weight repair, analytic eff-n, no rounding, type-robust
# 2. V9.9.3: Fail-fast errors, z-test sanity checks, numeric stability
# 3. V9.9.4: Parameter validation (alpha, min_base), documentation polish
#
# STATUS: PRODUCTION LOCKED - "hard to misuse" module
#
# TESTING PROTOCOL:
# 1. Unit tests for all statistical functions (see test_weighting.R)
# 2. Integration tests with run_crosstabs.r
# 3. Validate against known weighted survey results
# 4. Test edge cases (zero weights, extreme weights, small samples)
# 5. Verify significance testing matches manual calculations
# 6. V9.9.4: Test parameter validation (invalid alpha, min_base)
# 7. V10.0: Module integration (all functions accessible, no regressions)
#
# REGRESSION TESTS (V9.9.4):
# - Degenerate bases: count=5, base=0 → p=NA (no error)
# - count > base: Explicit warning + test skipped
# - Analytic-sample eff-n: Many NAs → correct eff-n + respects min_base
# - Extreme weights: No overflow in calculate_effective_n
# - Invalid parameters: alpha=1.5 → error, min_base=0 → error
#
# DEPENDENCY MAP:
#
# weighting.R (THIS FILE)
#   ├─→ Used by: run_crosstabs.r (PRIMARY)
#   ├─→ Used by: ranking.R
#   ├─→ Depends on: shared_functions.R
#   ├─→ Sources: weighting_validation.R
#   ├─→ Sources: weighting_calculations.R
#   ├─→ Sources: weighting_bases.R
#   ├─→ Sources: weighting_tests.R
#   ├─→ Sources: weighting_advanced.R
#   ├─→ Sources: weighting_summary.R
#   └─→ External packages: (base R only)
#
# CRITICAL FUNCTIONS (Extra care when modifying):
# - weighted_z_test_proportions(): Used extensively in significance testing
# - calculate_weighted_base(): Return structure MUST match V9.9
# - calculate_effective_n(): Used throughout for sample size adjustments
# - weighted_variance(): Core calculation for t-tests
# - get_weight_vector(): Weight repair policy critical for correctness
#
# STATISTICAL ASSUMPTIONS:
# 1. Weights represent sampling probabilities (design weights)
# 2. Effective-n formula assumes simple random sampling within strata
# 3. Population variance estimator appropriate given effective-n usage
# 4. Pooled proportion uses design-weighted counts (standard practice)
# 5. Welch approximation for unequal variances (conservative)
# 6. Zero weights mean exclusion (not re-inclusion)
#
# PERFORMANCE NOTES:
# - All functions are O(n) or O(1) - efficient for large datasets
# - No iterative algorithms - deterministic performance
# - Memory usage scales linearly with data size
# - V9.9.3: Scale-safe eff-n prevents numeric overflow
#
# BACKWARD COMPATIBILITY:
# - V8.0 → V10.0: BREAKING CHANGES
#   * Function signatures changed
#   * Return value keys changed
#   * Weight repair policy changed
# - V9.9.1/V9.9.2/V9.9.3/V9.9.4 → V10.0: NON-BREAKING
#   * Refactoring only - all APIs identical
#   * All functions remain in same namespace
#   * Module files must be present for functionality
#
# COMMON ISSUES:
# 1. "effective-n required" warning: Pass eff_n when is_weighted=TRUE
# 2. High design effects: Check weight variability, consider trimming
# 3. "Count exceeds base" warning: Check for duplicated rows upstream
# 4. Length mismatch errors: Verify data subsetting logic
# 5. Parameter validation errors: Check alpha ∈ (0,1), min_base ≥ 1
# 6. "Module not found": Ensure all weighting_*.R files are in lib/ directory
#
# MIGRATION GUIDE (V9.9.4 → V10.0):
# - No code changes required for users of weighting functions
# - All public API functions remain in same namespace
# - Module files must be present in modules/tabs/lib/ directory
# - If deploying, include all 7 weighting*.R files (not just weighting.R)
# - All functions automatically exported through module sourcing
# - Test thoroughly after upgrade to verify all modules load correctly
#
# VERSION HISTORY DETAIL:
# V10.0 (Current - Modular Refactoring):
# - Refactored 1,590-line file into 7 focused modules
# - Improved maintainability and code organization
# - Enhanced testability (each module can be tested independently)
# - Better navigation (logical grouping of functions)
# - All V9.9.4 functionality preserved (100% backward compatible)
#
# V9.9.4 (Final Production Release):
# - Added parameter validation (alpha, min_base) in sig tests
# - Documented n_eff rounding behavior
# - Documented zero weight exclusion
# - All external review feedback COMPLETE
# - MODULE PRODUCTION LOCKED
#
# V9.9.3 (Final Production Polish):
# - calculate_weighted_mean: Length mismatch → error
# - Z-test: Added count ≤ base sanity checks
# - calculate_effective_n: Numeric stability
# - calculate_weighted_percentage: Documented rounding
#
# V9.9.2 (External Review Fixes):
# - Fixed weight repair policy (exclude, not coerce)
# - Fixed t-test eff-n calculation (analytic sample)
# - Removed rounding from calculate_weighted_base
# - Added type-robust "has response" logic
#
# V9.9.1 (Production Release):
# - Fixed function signatures to match V9.9
# - Fixed return value structures
# - Added weighted_variance() function
# - Added explicit is_weighted flag
#
# V8.0 (Deprecated):
# - Incompatible signatures and return values
#
# REFACTORING BENEFITS:
# - Reduced cognitive load: ~80-380 lines per file vs 1,590 lines
# - Faster navigation: find validation code in validation module
# - Easier testing: test calculations independently from tests
# - Better collaboration: multiple developers can work on different modules
# - Clearer dependencies: see exactly what each module needs
# - Simplified debugging: smaller surface area per file
# - Focused maintenance: update specific functionality in its module
#
# ==============================================================================
# END OF WEIGHTING.R V10.0 - MODULAR ARCHITECTURE
# ==============================================================================
