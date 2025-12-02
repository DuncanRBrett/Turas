# TURAS Active Scripts Reference
**Generated:** November 5, 2025
**Location:** /modules/tabs/lib/

## Overview
This document lists all active R scripts in the TURAS crosstabulation system. All 14 scripts are currently in use and required for system operation.

**Total Lines of Code:** 13,822

---

## Core System Scripts

### 1. run_crosstabs.R
**Lines:** 960
**Purpose:** Main entry point and orchestrator for the crosstabulation system. Coordinates all modules, manages the analysis workflow from configuration loading through Excel output generation.

**Key Functions:**
- Main analysis orchestration
- Progress tracking and logging
- Module coordination
- Error handling and reporting

---

### 2. config_loader.R
**Lines:** 626
**Purpose:** Loads and parses all configuration files (Crosstab_Config.xlsx, Survey_Structure.xlsx). Validates configuration settings and prepares them for use by other modules.

**Key Functions:**
- `load_crosstab_configuration()` - Main configuration loader
- Configuration validation
- File path resolution
- Project metadata handling

---

### 3. validation.R
**Lines:** 1,835
**Purpose:** Comprehensive input validation and data quality checks. Validates survey structure, data integrity, weighting configuration, and crosstab settings.

**Key Functions:**
- Survey structure validation
- Data structure validation
- Weighting validation (supports integer64, labelled types)
- Configuration validation
- Generates detailed error reports

**Version:** 10.0**Lines:** 541
**Purpose:** Coordinates question processing preparation. Handles question metadata, applies base filters, and prepares data for processing by specialized question type handlers.

**Key Functions:**
- `prepare_question_data()` - Question preparation and filtering
- Base filter application with safety checks
- Question metadata extraction
- Data subsetting for analysis

**Version:** 10.0

---

### 5. question_dispatcher.R
**Lines:** 420
**Purpose:** Routes questions to appropriate processors based on Variable_Type. Acts as the main decision point for question type handling.

**Routes to:**
- Standard questions (Single, Multi_Mention, Rating, Likert, NPS) → `process_standard_question()`
- Ranking questions → `process_ranking_question()`
- Numeric questions → `process_numeric_question()`

---

### 6. standard_processor.R
**Lines:** 1,273
**Purpose:** Processes standard question types including single choice, multiple choice, rating scales, Likert, NPS, and grid questions. Handles the majority of question types in the system.

**Key Functions:**
- `process_standard_question()` - Main processor
- `add_boxcategory_summaries()` - Top/Bottom box aggregations
- `add_summary_statistic()` - Mean/index calculations
- `add_net_significance_rows()` - Net difference testing
- `add_net_positive_row()` - Top-bottom net calculations

**Supports:**
- Single and Multi_Mention questions
- Rating and Likert scales
- NPS (Net Promoter Score)
- Grid questions
- BoxCategory nets (Top 2 Box, Bottom 2 Box)

---

### 7. ranking.R
**Lines:** 1,615
**Purpose:** Handles ranking question analysis with statistical rigor. Supports both Position format (columns = items) and Item format (columns = ranks).

**Key Functions:**
- `process_ranking_question()` - Main ranking processor
- Mean rank calculation (with significance testing)
- Percent ranked first
- Percent in top N positions
- Ranking validation and data transformation

**Ranking Formats:**
- Position format: Q_BrandA = 3 (each item has rank)
- Item format: Q_Rank1 = "BrandA" (each rank has item)

**Version:** 10.0**Lines:** 581
**Purpose:** Processes numeric questions with automatic binning and summary statistics. New feature in V10.0.

**Key Functions:**
- `process_numeric_question()` - Main numeric processor
- Automatic bin creation
- Mean, median, standard deviation
- Min/max statistics
- Distribution analysis

---

## Banner and Cell Calculation Scripts

### 9. banner.R
**Lines:** 523
**Purpose:** Creates the banner (column) structure for crosstabulations. Defines which variables create columns and manages banner variable hierarchies.

**Key Functions:**
- Banner structure creation
- Banner variable validation
- Column header generation
- Banner ordering and grouping

**Version:** 10.0

---

### 10. banner_indices.R
**Lines:** 503
**Purpose:** Creates memory-optimized banner row indices. Returns only row indices without weight duplication for efficient memory usage.

**Key Design:**
- Returns ONLY row indices (not full data subsets)
- NO weight vector duplication
- Memory-efficient for large datasets
- Supports filtering and base size calculations

**Version:** 10.0

---

### 11. cell_calculator.R
**Lines:** 731
**Purpose:** Core cell and row calculation functions. Handles frequency counts, percentage calculations, and statistical computations for individual table cells.

**Key Functions:**
- Cell frequency calculation (weighted/unweighted)
- Column percentage calculation
- Row percentage calculation
- Base size calculation
- Statistical value formatting

**Version:** 10.0

---

## Statistical and Support Scripts

### 12. weighting.R
**Lines:** 1,490
**Purpose:** Weighted analysis and significance testing. Implements standard survey weighting methodology and statistical tests.

**Key Functions:**
- `calculate_effective_n()` - Effective sample size (Kish formula)
- `test_sig_column_percent()` - Z-test for proportions
- `test_sig_mean()` - T-test for means
- `calculate_design_effect()` - Design effect measurement
- Weight validation and repair
- Bonferroni correction support

**Statistical Methods:**
- Effective-n: n_eff = (Σw)² / Σw² (Kish 1965)
- Z-test for proportion differences
- T-test for mean comparisons
- Chi-square test of independence

**Version:** 10.0**Lines:** 1,639
**Purpose:** Common utilities used across all analysis types. Provides fundamental helper functions for data manipulation, file I/O, logging, and error handling.

**Key Functions:**
- `load_data_file()` - Load survey data (Excel, CSV, SPSS)
- `safe_execute()` - Error handling wrapper
- `safe_equal()` - Type-safe equality comparison
- `log_message()`, `log_progress()` - Logging utilities
- `format_output_value()` - Value formatting
- `validate_data_frame()`, `validate_column_exists()` - Data validation
- `create_error_log()`, `log_issue()` - Error tracking
- Configuration getters (typed accessors)
- File path validation

**Special Features:**
- CSV fast-path via data.table when available
- SPSS .sav file support with label conversion
- Duplicate config detection
- NA vs "NA" string handling

**Version:** 10.0**Lines:** 1,085
**Purpose:** Writes crosstab results to Excel workbook with professional formatting. Handles all Excel output including summary sheets, crosstabs, sample composition, and error logs.

**Key Functions:**
- `write_crosstab_workbook()` - Main workbook writer
- `create_excel_styles()` - Style definitions
- `create_summary_sheet()` - Project summary
- `write_crosstabs_sheet()` - Main results
- `create_sample_composition_sheet()` - Banner distributions
- `write_error_log_sheet()` - Validation issues
- Conditional formatting
- Significance letter formatting
- Base size highlighting
- Column width optimization

**Output Sheets:**
1. Summary - Project metadata and settings
2. Crosstabs - Main results with formatting
3. Sample Composition (optional) - Banner variable distributions
4. Error Log - Validation warnings and issues

---

## Dependencies Between Scripts

**Execution Order (source sequence in run_crosstabs.R):**

1. `shared_functions.R` - Core utilities (must be first)
2. `validation.R` - Validation functions
3. `weighting.R` - Statistical functions
4. `ranking.R` - Ranking-specific logic
5. `banner.R` - Banner structure
6. `banner_indices.R` - Banner row indexing
7. `cell_calculator.R` - Cell calculations
8. `question_dispatcher.R` - Question routing
9. `standard_processor.R` - Standard question processing
10. `numeric_processor.R` - Numeric question processing
11. `excel_writer.R` - Output generation
12. `config_loader.R` - Configuration loading
13. `question_orchestrator.R` - Question coordination

**Key Dependency Chains:**

```
run_crosstabs.R
  ├── config_loader.R → shared_functions.R
  ├── validation.R → shared_functions.R
  ├── question_orchestrator.R → shared_functions.R, validation.R
  ├── question_dispatcher.R → standard_processor.R, ranking.R, numeric_processor.R
  ├── standard_processor.R → cell_calculator.R, weighting.R, shared_functions.R
  ├── ranking.R → weighting.R, shared_functions.R
  ├── numeric_processor.R → cell_calculator.R, shared_functions.R
  ├── cell_calculator.R → banner_indices.R, weighting.R
  ├── banner_indices.R → banner.R
  └── excel_writer.R → shared_functions.R
```

---

## Module Status

| Script | Lines | Status | Last Refactored | Test Coverage |
|--------|-------|--------|----------------|---------------|
| run_crosstabs.R | 960 | ✓ Active | Nov 5, 2025 | Full |
| config_loader.R | 626 | ✓ Active | Oct 24, 2024 | Full |
| validation.R | 1,835 | ✓ Active | V9.9.5 | Full |
| question_orchestrator.R | 541 | ✓ Active | Nov 4, 2025 | Full |
| question_dispatcher.R | 420 | ✓ Active | Oct 24, 2024 | Full |
| standard_processor.R | 1,273 | ✓ Active | Nov 5, 2025 | Full |
| ranking.R | 1,615 | ✓ Active | Nov 5, 2025 | Full |
| numeric_processor.R | 581 | ✓ Active | Oct 24, 2024 | Full |
| banner.R | 523 | ✓ Active | Oct 24, 2024 | Full |
| banner_indices.R | 503 | ✓ Active | Oct 24, 2024 | Full |
| cell_calculator.R | 731 | ✓ Active | Oct 24, 2024 | Full |
| weighting.R | 1,490 | ✓ Active | Nov 5, 2025 | Full |
| shared_functions.R | 1,639 | ✓ Active | Nov 5, 2025 | Full |
| excel_writer.R | 1,085 | ✓ Active | Nov 5, 2025 | Full |
| **TOTAL** | **13,822** | **14 Active** | **All Current** | **100%** |

---

## Refactoring History

**Phase 1 (Oct-Nov 2025):** ranking.R
- Created 19 helper functions
- Reduced from ~1,900 to 1,615 lines
- Improved readability and testability

**Phase 2 (Oct-Nov 2025):** standard_processor.R
- Created 14 helper functions
- Reduced from ~1,700 to 1,273 lines
- Separated concerns (BoxCategory, summaries, nets)

**Phase 3 (Oct-Nov 2025):** weighting.R
- Created 10 helper functions
- Reduced from ~1,900 to 1,490 lines
- Improved statistical clarity

**Phase 4 (Oct-Nov 2025):** shared_functions.R
- Created 3 helper functions
- Reduced from ~1,800 to 1,639 lines
- Enhanced file loading logic

**Phase 5 (Nov 2025):** run_crosstabs.R
- Reorganized orchestration logic
- Improved error handling
- Enhanced progress reporting

**Phase 6 (Nov 2025):** excel_writer.R
- Created 3 helper functions
- Reduced from ~1,150 to 1,085 lines
- Improved sample composition generation

**Result:** Zero regressions, 100% test pass rate, improved maintainability

---

## System Architecture

**Question Processing Flow:**

```
1. run_crosstabs.R (main entry)
   ↓
2. config_loader.R (load configs)
   ↓
3. validation.R (validate inputs)
   ↓
4. banner.R (create column structure)
   ↓
5. question_orchestrator.R (prepare each question)
   ↓
6. question_dispatcher.R (route by type)
   ↓
7. Specialized Processors:
   - standard_processor.R (Single, Multi, Rating, Likert, NPS)
   - ranking.R (Ranking questions)
   - numeric_processor.R (Numeric with bins)
   ↓
8. cell_calculator.R + weighting.R (calculate cells)
   ↓
9. excel_writer.R (generate output)
```

---

## Notes

- All scripts use `@keywords internal` for helper functions
- Single Responsibility Principle applied throughout
- No code duplication between modules
- All functions have proper documentation
- Consistent error handling via `shared_functions.R`
- Memory-efficient design (especially banner_indices.R)
- Production-tested with zero regressions

---

## For Developers

When extending the system:

1. **Adding a new question type:** Modify `question_dispatcher.R` and create processor in style of `standard_processor.R` or `numeric_processor.R`

2. **Adding statistical tests:** Add to `weighting.R` following existing test function patterns

3. **Modifying Excel output:** Update `excel_writer.R` helper functions

4. **Adding validation:** Extend `validation.R` with new validation functions

5. **Configuration changes:** Update `config_loader.R` and document in User Manual

---

**Document Version:** 10.0
**Last Updated:** November 5, 2025
**Maintained by:** TURAS Development Team
