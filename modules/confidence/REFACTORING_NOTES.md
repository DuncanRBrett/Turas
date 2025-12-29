# Confidence Module Refactoring - V10.1

## Overview

This document describes the refactoring work completed on the Confidence module to improve code maintainability, modularity, and readability.

## Refactoring Goals

1. **Modularity**: Break large monolithic scripts into focused, single-responsibility modules
2. **Reduce Duplication**: Extract shared logic from similar functions
3. **Maintainability**: Reduce file sizes and improve code organization
4. **Testability**: Make code easier to test by separating concerns
5. **Clarity**: Make dependencies explicit and reduce coupling

## Problem Statement

Two large scripts were identified for refactoring:

| File | Before | Issues |
|------|--------|--------|
| `00_main.R` | 1,396 lines | High duplication in `process_*_question()` functions |
| `07_output.R` | 1,308 lines | Repetitive dataframe building patterns |

### Key Issues in 00_main.R

The three question processing functions shared ~70% common code:

| Common Pattern | Lines (each) | Total Duplicated |
|----------------|--------------|------------------|
| Check question exists | 5 | 15 |
| Get/validate weights | 10 | 30 |
| Clean/align values & weights | 25 | 75 |
| Calculate basic stats | 20 | 60 |
| CI flag dispatch pattern | 50 | 150 |
| **Total** | **~110** | **~330 lines** |

## Solution Implemented

Following the orchestrator pattern established in the Tabs module refactoring.

### New Modules Created

#### 1. `question_processor.R` (466 lines)
**Purpose**: Common question processing logic

**Functions**:
- `validate_question_in_data()` - Check question exists in data
- `get_question_weights()` - Get and validate weights
- `prepare_question_data()` - Clean and align values with weights
- `calculate_proportion_stats()` - Calculate proportion base statistics
- `calculate_mean_stats()` - Calculate mean base statistics
- `calculate_nps_stats()` - Calculate NPS base statistics
- `process_question_data()` - Unified high-level processing

**Rationale**: Consolidates repeated validation, weight handling, and data preparation logic from the three `process_*_question()` functions.

#### 2. `ci_dispatcher.R` (367 lines)
**Purpose**: Unified CI calculation dispatch

**Functions**:
- `dispatch_proportion_ci()` - Dispatch proportion CI calculations based on flags
- `dispatch_mean_ci()` - Dispatch mean CI calculations based on flags
- `dispatch_nps_ci()` - Dispatch NPS CI calculations based on flags

**Rationale**: Centralizes the logic for checking Run_MOE, Use_Wilson, Run_Bootstrap, Run_Credible flags and calling appropriate CI functions.

#### 3. `output_helpers.R` (399 lines)
**Purpose**: Common output building patterns

**Functions**:
- `build_base_result_row()` - Create base row with common fields
- `add_ci_fields_to_row()` - Add CI-specific fields to result row
- `combine_result_rows()` - Combine rows handling mismatched columns
- `build_results_dataframe()` - Generic results dataframe builder
- `build_proportion_result_row()` - Build proportion result row
- `build_mean_result_row()` - Build mean result row
- `build_nps_result_row()` - Build NPS result row
- `create_header_style()` - Standard header style
- `create_title_style()` - Standard title style
- `write_formatted_data()` - Write data with standard formatting

**Rationale**: Extracts common patterns from the three `build_*_dataframe()` functions in 07_output.R.

### Modified Files

#### `00_main.R`
**Changes**:
- Converted to orchestrator pattern
- Sources new modules (`question_processor.R`, `ci_dispatcher.R`)
- Refactored `process_proportion_question()` to use shared modules
- Refactored `process_mean_question()` to use shared modules
- Refactored `process_nps_question()` to use shared modules
- Extracted orchestration steps into named functions

**Reduction**: 1,396 → 955 lines (32% reduction)

#### `07_output.R`
**Changes**:
- Sources `output_helpers.R`
- Updated version header
- Existing functions maintained (already well-structured)

**Note**: 07_output.R was already reasonably well-organized. The main improvement is the addition of `output_helpers.R` which provides reusable patterns.

## File Size Comparison

### Before Refactoring
| File | Lines | Status |
|------|-------|--------|
| 00_main.R | 1,396 | Too large - high duplication |
| 07_output.R | 1,308 | Large - moderate duplication |
| **Total** | **2,704** | |

### After Refactoring
| File | Lines | Status |
|------|-------|--------|
| 00_main.R | 954 | ✓ Orchestrator pattern |
| 07_output.R | 1,315 | ✓ Minor update |
| **New: question_processor.R** | 466 | ✓ Focused module |
| **New: ci_dispatcher.R** | 367 | ✓ Focused module |
| **New: output_helpers.R** | 399 | ✓ Focused module |
| **Total** | **3,501** | Well-organized code |

**Net effect**:
- 00_main.R reduced by 442 lines (32%)
- 1,232 lines of new well-organized utility code
- Total duplication reduced significantly
- Each module has single responsibility

## Benefits Achieved

### 1. Reduced Duplication
- **Before**: ~330 lines of duplicated code in question processing
- **After**: Single implementation of common patterns

### 2. Improved Maintainability
- Changes to question validation logic only needed in one place
- CI dispatch logic centralized

### 3. Enhanced Testability
- `question_processor.R` functions can be unit tested independently
- `ci_dispatcher.R` functions can be tested in isolation

### 4. Clearer Flow
- Main file shows clear 6-step workflow
- Each step is a named function

### 5. Easier Debugging
- Smaller, focused functions are easier to trace
- Clear separation of concerns

## Backward Compatibility

All refactoring maintains backward compatibility:
- ✓ All existing public function signatures unchanged
- ✓ All existing functions still available
- ✓ Module sourcing is automatic via 00_main.R
- ✓ No breaking changes to calling code

## Architecture After Refactoring

```
R/
├── 00_guard.R              (error handling - unchanged)
├── 00_main.R               (954 lines - orchestrator)
├── 01_load_config.R        (unchanged)
├── 02_load_data.R          (unchanged)
├── 03_study_level.R        (unchanged)
├── 04_proportions.R        (unchanged)
├── 05_means.R              (unchanged)
├── question_processor.R    (466 lines - NEW)
├── ci_dispatcher.R         (367 lines - NEW)
├── output_helpers.R        (399 lines - NEW)
├── 07_output.R             (1,315 lines - updated)
└── utils.R                 (unchanged)
```

## Main Execution Flow

```r
# 00_main.R orchestration

# STEP 1: LOAD CONFIGURATION
config <- load_config_step(config_path)

# STEP 2: LOAD SURVEY DATA
data_result <- load_data_step(config, verbose)

# STEP 3: STUDY-LEVEL STATISTICS
study_result <- calculate_study_stats_step(...)

# STEP 4: PROCESS QUESTIONS
question_result <- process_all_questions(config, survey_data, weight_var, verbose)

# STEP 5: QUALITY CHECKS
handle_warnings_step(warnings_list, verbose, stop_on_warnings)

# STEP 6: GENERATE OUTPUT
generate_output_step(...)
```

## Question Processing Flow

Each `process_*_question()` function now follows this pattern:

```r
process_proportion_question <- function(q_row, survey_data, weight_var, config) {
  # Step 1: Prepare question data (using question_processor.R)
  prep <- process_question_data(q_id, survey_data, weight_var)

  # Step 2: Parse categories
  categories <- parse_codes(q_row$Categories)

  # Step 3: Calculate base statistics (using question_processor.R)
  stats <- calculate_proportion_stats(prep$values, categories, prep$weights)

  # Step 4: Build result with base stats
  result <- list(...)

  # Step 5: Dispatch CI calculations (using ci_dispatcher.R)
  ci_results <- dispatch_proportion_ci(...)

  # Merge CI results
  return(list(result = result, warnings = warnings_list))
}
```

## Future Considerations

### Potential Further Improvements

1. **Unit Tests**: Add comprehensive test suites for new modules
2. **Performance**: Profile bootstrap calculations for large datasets
3. **Documentation**: Add roxygen2 documentation to all functions
4. **Error Handling**: Standardize error patterns using confidence_refuse()

### Lessons Learned

1. The orchestrator pattern significantly improves readability
2. Extracting shared logic reduces maintenance burden
3. Small, focused modules are easier to test and debug
4. Backward compatibility is achievable with careful design

---

**Date**: December 29, 2025
**Version**: 10.1
**Author**: Claude Code Refactoring
