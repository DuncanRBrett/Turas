# Enhanced Conjoint Module - Implementation Status

**Date:** 2025-11-26
**Version:** 2.0.0 (In Progress)
**Branch:** claude/enhance-conjoint-module-01TSUfoueFUWVGUM1XBiZhbx

## Overview

This document tracks the implementation of the enhanced Turas Conjoint Analysis module based on the comprehensive 5-part specification located in this directory.

## Completed Components ✅

### 1. Core Infrastructure (99_helpers.R)
**Status:** ✅ Complete
**Location:** `modules/conjoint/R/99_helpers.R`

Comprehensive utility functions including:
- Error and warning message formatting
- Data type conversions (safe_logical, safe_numeric)
- Attribute level parsing and handling
- Statistical functions (CIs, p-values, significance stars)
- Utility interpretation helpers
- Model quality assessment functions
- Excel formatting helpers
- Logging and progress tracking
- Package checking utilities
- Zero-centering functions

### 2. Enhanced Configuration Loading (01_config.R)
**Status:** ✅ Complete
**Location:** `modules/conjoint/R/01_config.R`

Features:
- Loads Settings and Attributes sheets from Excel config
- Comprehensive validation of configuration structure
- Support for all Phase 1 settings:
  - analysis_type (choice/rating)
  - estimation_method (auto/mlogit/clogit/hb)
  - baseline_handling (first_level_zero/all_levels_explicit)
  - choice_type (single/single_with_none/best_worst/continuous_sum)
  - None option settings (none_as_baseline, none_label)
  - Column name customization
  - Feature flags (generate_market_simulator, include_diagnostics)
- Flexible path resolution (relative and absolute paths)
- Clear, actionable error messages
- Attribute-level validation (min/max levels, duplicates, etc.)

### 3. None Option Handling (09_none_handling.R)
**Status:** ✅ Complete
**Location:** `modules/conjoint/R/09_none_handling.R`

Features:
- Auto-detection of none options using multiple methods:
  - Pattern matching in attribute values
  - Detection of all-unchosen choice sets
  - Checking alternative_id column
- Handles both explicit and implicit none options
- Creates none rows when needed
- Validates none option data integrity
- Calculates none-specific diagnostics

### 4. Comprehensive Data Validation (02_data.R)
**Status:** ✅ Complete
**Location:** `modules/conjoint/R/02_data.R`

Features:
- Supports multiple file formats (CSV, XLSX, SAV, DTA)
- Three-tier validation (Critical/Warning/Info)
- Critical checks:
  - Required columns exist
  - Exactly one chosen per choice set
  - Attribute levels match configuration
  - No missing values in critical columns
  - Chosen column is binary (0/1)
- Warning checks:
  - Low response counts per level
  - Some cards never chosen
  - Unbalanced choice set sizes
  - Sample size adequacy
  - Perfect separation detection
- Integrates with none option handling
- Calculates comprehensive data statistics
- Clear error messages with specific row/column references

## Pending Components 🚧

### 5. Multi-Method Estimation (03_estimation.R)
**Status:** Not Started
**Priority:** High
**Specification:** Part 1, Sections 2.2-2.3

**Requirements:**
- Primary method: `mlogit::mlogit()` with proper data preparation
- Fallback method: `survival::clogit()` when mlogit fails
- Auto mode: try methods in order until success
- Support for baseline handling options
- Proper formula construction
- Convergence checking
- Standardized output structure

**Key Functions Needed:**
```r
estimate_choice_model()
try_mlogit()
try_clogit()
prepare_mlogit_data()
build_mlogit_formula()
extract_mlogit_results()
```

### 6. Utility Calculation with CIs (04_utilities.R)
**Status:** Not Started
**Priority:** High
**Specification:** Part 1, Section 2.4

**Requirements:**
- Extract coefficients from model
- Apply baseline handling
- Zero-center utilities within attributes
- Calculate standard errors
- Compute confidence intervals (Delta method or bootstrap)
- Calculate p-values
- Flag significant/non-significant levels
- Add interpretation text

**Key Functions Needed:**
```r
calculate_utilities()
extract_coefficients()
apply_baseline_handling()
calculate_standard_errors()
bootstrap_confidence_intervals()
```

### 7. Model Diagnostics (05_diagnostics.R)
**Status:** Not Started
**Priority:** Medium
**Specification:** Part 1, Section 2.6

**Requirements:**
- McFadden R² and adjusted R²
- Hit rate calculation
- AIC/BIC
- Likelihood ratio test
- Attribute-level significance tests
- Prediction accuracy by choice set size
- Auto-generated interpretation

**Key Functions Needed:**
```r
calculate_diagnostics()
calculate_hit_rate()
test_attribute_significance()
assess_model_quality()
generate_interpretation_text()
```

### 8. Enhanced Excel Output (07_output.R)
**Status:** Needs Major Enhancement
**Priority:** High
**Specification:** Part 3, All Sections

**Current:** Basic 4-sheet output
**Needed:** 8-sheet comprehensive output

**Required Sheets:**
1. Executive Summary (NEW)
2. Attribute Importance (Enhanced with CIs)
3. Part-Worth Utilities (Enhanced with significance)
4. Model Diagnostics (Enhanced with interpretation)
5. Market Simulator (NEW - Interactive)
6. Simulator Data (NEW - Hidden lookups)
7. Detailed Results
8. Configuration Summary

### 9. Market Simulator (08_market_simulator.R)
**Status:** Not Started
**Priority:** Medium (High for client deliverables)
**Specification:** Part 3, Section 3

**Requirements:**
- Product configuration with dropdowns
- Market share calculation formulas
- Utilities breakdown display
- Sensitivity analysis section
- What-if scenarios
- Auto-updating charts
- Hidden lookup tables
- None option toggle (if applicable)

### 10. Enhanced Main Workflow (00_main.R)
**Status:** Needs Update
**Priority:** High
**Current:** Basic workflow
**Needed:** Integrate all new components

**Required Updates:**
- Call new validation functions
- Use multi-method estimation
- Calculate utilities with CIs
- Generate diagnostics
- Create enhanced output
- Better progress reporting
- Error recovery logic

## File Structure

```
modules/conjoint/
├── R/
│   ├── 00_main.R              [NEEDS UPDATE]
│   ├── 01_config.R            [✅ COMPLETE]
│   ├── 02_data.R              [✅ COMPLETE]  (was 02_validation.R)
│   ├── 03_estimation.R        [🚧 TO DO]    (was 03_analysis.R)
│   ├── 04_utilities.R         [🚧 TO DO]    (NEW)
│   ├── 05_diagnostics.R       [🚧 TO DO]    (NEW)
│   ├── 06_simulation.R        [🚧 TO DO]    (NEW - market sim logic)
│   ├── 07_output.R            [NEEDS UPDATE]
│   ├── 08_market_simulator.R  [🚧 TO DO]    (NEW - Excel market sim)
│   ├── 09_none_handling.R     [✅ COMPLETE] (NEW)
│   └── 99_helpers.R           [✅ COMPLETE] (NEW)
├── examples/                  [TO CREATE]
├── tests/                     [TO CREATE]
└── inst/templates/            [TO CREATE]
```

## Specification Files (Reference)

Located in `modules/conjoint/`:
- Part1_Core_Technical_Specification.md
- Part2_Configuration_Testing_Validation.md
- Part3_Excel_Output_Market_Simulator.md
- Part4_Alchemer_Choice_Types_Format_Support.md
- Part5_Excel_Data_Configuration_File_Structures.md

## Installation Notes

### Required R Packages

**Core (must have):**
```r
install.packages(c(
  "mlogit",      # Primary estimation engine
  "survival",    # Fallback clogit
  "openxlsx",    # Excel I/O
  "dplyr",       # Data manipulation
  "tidyr"        # Data reshaping
))
```

**Optional (for advanced features):**
```r
install.packages(c(
  "ChoiceModelR",  # Hierarchical Bayes (Phase 2)
  "haven",         # SPSS/Stata files
  "boot"           # Bootstrap CIs
))
```

## Next Steps (Priority Order)

### Immediate (Session 2)
1. **Implement 03_estimation.R**
   - mlogit integration
   - clogit fallback
   - Auto method selection

2. **Implement 04_utilities.R**
   - Utility extraction
   - Zero-centering
   - Confidence intervals
   - Significance testing

3. **Update 00_main.R**
   - Integrate new components
   - Enhanced workflow
   - Progress reporting

### Short-term (Session 3)
4. **Implement 05_diagnostics.R**
   - Model fit statistics
   - Hit rate calculation
   - Interpretation generation

5. **Enhance 07_output.R**
   - 8-sheet structure
   - Rich formatting
   - Charts and conditional formatting

### Medium-term (Session 4)
6. **Implement 08_market_simulator.R**
   - Interactive simulator sheet
   - Dropdown configuration
   - Formula-based calculations

7. **Create examples and tests**
   - Example config files
   - Test data
   - Integration tests

## Testing Plan

### Unit Tests
- Config loading and validation
- Data validation logic
- None option detection
- Utility calculations
- Zero-centering verification

### Integration Tests
- End-to-end with DE_noodle dataset
- Validation against spec Part1_Core examples
- Comparison with existing clogit results

### Test Data Needed
1. Standard CBC (no none option)
2. CBC with explicit none rows
3. CBC with implicit none (all unchosen sets)
4. Various attribute/level combinations
5. Edge cases (minimal data, max complexity)

## Known Issues / Decisions Needed

1. **mlogit data format:** Need to determine exact format required by mlogit package (wide vs long, indexing requirements)

2. **Bootstrap vs Delta method:** For confidence intervals on utilities
   - Delta method: Faster, assumes normality
   - Bootstrap: More robust, slower
   - **Recommendation:** Start with Delta, add bootstrap as option

3. **Market simulator:** JavaScript vs pure Excel formulas
   - Pure Excel: More compatible, works offline
   - JavaScript: More interactive, requires macro-enabled
   - **Recommendation:** Pure Excel with VBA-free formulas

4. **Phase 2 features:** When to implement?
   - Best vs Worst: Moderate complexity
   - Continuous Sum: Lower complexity
   - Hierarchical Bayes: High complexity
   - **Recommendation:** Complete Phase 1 fully first

## Success Criteria

The implementation will be considered complete when:

- ✅ All critical Phase 1 components implemented
- ✅ Produces results matching statsmodels within 5% tolerance
- ✅ Handles all Alchemer CBC data formats correctly
- ✅ Generates 8-sheet Excel output
- ✅ Market simulator works with formulas
- ✅ Passes all unit and integration tests
- ✅ Clear error messages for common mistakes
- ✅ Works for non-statistician users
- ✅ Performance within targets (see spec Part 1, Section 8)

## References

- Green & Srinivasan (1978): Conjoint analysis in consumer research
- Orme (2010): Getting Started with Conjoint Analysis
- Sawtooth Software technical papers
- R mlogit package documentation
- Turas coding standards (see modules/shared/lib/)

---

**Last Updated:** 2025-11-26
**Next Session Focus:** Multi-method estimation + utilities calculation
