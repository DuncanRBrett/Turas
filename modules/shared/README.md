# Turas Shared Utilities

Common utility functions used across all Turas modules.

## Purpose

This shared module eliminates code duplication across Turas modules (tabs, tracker, segment, etc.) by providing a single source of truth for common operations.

## Organization

```
modules/shared/lib/
├── import_all.R          # Single-file import (recommended)
├── config_utils.R        # Excel config loading, path handling, find_turas_root()
├── data_utils.R          # Data loading and type conversion
├── validation_utils.R    # Input validation functions
├── logging_utils.R       # Logging, progress tracking, error tracking
├── formatting_utils.R    # Number formatting for Excel and text output
├── weights_utils.R       # Weight efficiency and validation
├── stats_pack_writer.R   # Diagnostic stats pack Excel workbook generator
├── trs_run_state.R       # TRS execution state management
├── trs_run_status_writer.R # TRS Run_Status sheet writer
└── trs_banner.R          # TRS start/finish console banners
```

## Usage

**Recommended: Use import_all.R**
```r
# From any module - loads all utilities in correct dependency order
turas_root <- find_turas_root()
source(file.path(turas_root, "modules/shared/lib/import_all.R"))
```

**Alternative: Source individual files**
```r
# Source only what you need (respect dependency order)
shared_path <- file.path(find_turas_root(), "modules/shared/lib")
source(file.path(shared_path, "validation_utils.R"))  # First (no deps)
source(file.path(shared_path, "config_utils.R"))      # Second
```

## Key Functions

### Configuration (config_utils.R)

- `load_config_sheet(file_path, sheet_name)` - Load Excel config with validation
- `get_config_value(config, name, default, required)` - Safely retrieve config value
- `get_numeric_config()`, `get_logical_config()`, `get_char_config()` - Typed getters
- `resolve_path(base, relative)` - Platform-independent path resolution
- `find_turas_root()` - Locate Turas installation root (cached)

### Data Loading (data_utils.R)

- `load_survey_data(file_path)` - Load .xlsx, .xls, .csv, .sav files
- `safe_equal(a, b)` - Case-sensitive comparison with whitespace trimming
- `safe_numeric(x)`, `safe_logical(x)` - Safe type conversion
- `calc_percentage(num, denom, decimals)` - Percentage calculation with 0/0 handling

### Validation (validation_utils.R)

- `validate_data_frame(df, required_cols, min_rows)` - Data frame validation
- `validate_numeric_param(value, name, min, max)` - Numeric parameter validation
- `validate_logical_param(value, name)` - Logical parameter validation
- `validate_char_param(value, name, allowed)` - Character parameter validation
- `validate_file_path(path, must_exist, extensions)` - File path validation
- `validate_column_exists(data, column)` - Column existence check
- `has_data(df)` - Quick check if data frame has rows

### Logging (logging_utils.R)

- `log_message(msg, level, verbose)` - Timestamped logging
- `log_progress(current, total, item, start_time)` - Progress tracking with ETA
- `create_error_log()`, `log_issue()` - Structured error tracking
- `print_toolkit_header(analysis_type, version)` - Branding header

### Formatting (formatting_utils.R)

- `format_number(x, decimal_places, separator)` - Format numbers with locale separator
- `format_percentage(x, decimals, separator, sign)` - Format percentages
- `create_excel_number_format(decimals)` - Excel numFmt codes
- `create_excel_number_styles()` - openxlsx style objects
- `validate_decimal_separator()`, `validate_decimal_places()` - Input validators

### Weights (weights_utils.R)

- `calculate_weight_efficiency(weights)` - Effective sample size
- `calculate_design_effect(weights)` - Design effect (deff)
- `validate_weights_comprehensive(weights)` - Full weight validation
- `get_weight_summary(weights)` - Summary statistics
- `standardize_weight_variable(df, var)` - Standardize weight column

### Stats Pack (stats_pack_writer.R)

Generates a standalone diagnostic Excel workbook for advanced partners and
research statisticians. Provides a full, transparent audit trail of:
- What data was received vs what was analysed
- All analytical assumptions, methods, and implementation references
- Per-question response counts and data quality flags
- TRS warnings and execution events
- Reproducibility information (R version, package versions, seeds)
- Full config echo (verbatim settings used)

**Main function:**
```r
turas_write_stats_pack(payload, output_path, protect_sheets = TRUE)
```

**Payload structure:**
```r
payload <- list(
  module           = "CONFIDENCE",         # required
  project_name     = "Brand Tracker Q1",   # optional — from config Study_Settings
  analyst_name     = "Jane Smith",         # optional
  research_house   = "Acme Research",      # optional
  run_timestamp    = Sys.time(),
  turas_version    = MAIN_VERSION,
  status           = "PASS",
  duration_seconds = elapsed,
  data_receipt = list(
    file_name           = "survey_data.csv",
    n_rows              = nrow(survey_data),
    n_cols              = ncol(survey_data),
    questions_in_config = length(question_ids)
  ),
  data_used = list(
    n_respondents      = 498,
    n_excluded         = 14,
    questions_analysed = 40,
    questions_skipped  = 3,
    per_item_stats     = data.frame(Question_ID, Missing_N, Missing_Pct, ...)
  ),
  assumptions  = list("Confidence Level" = "95%", ...),  # named list → key-value table
  seeds        = list("k-means" = "42"),                 # optional, for stochastic modules
  run_result   = run_result,    # TRS run result object (for Warnings sheet)
  packages     = c("openxlsx", "readxl", "survey"),      # packages to report
  config_echo  = list(file_paths = ..., study_settings = ...)
)
```

**Output:** `{output_base}_stats_pack.xlsx` — six sheets (Declaration, Data_Used,
Assumptions, Warnings, Reproducibility, Config_Echo), all sheets write-protected.

**Enabling per module:**

Via config (Study_Settings sheet):
```
Setting              | Value
Generate_Stats_Pack  | Y
```

Via GUI: each module's GUI has a "Generate stats pack" checkbox.

Via R option (programmatic):
```r
options(turas.generate_stats_pack = TRUE)
```

**Optional identity fields** (`Project_Name`, `Analyst_Name`, `Research_House`)
populate the Declaration sheet when present in Study_Settings.

**Tests:** `modules/shared/tests/testthat/test_stats_pack_writer.R`

## Design Principles

1. **Single Responsibility**: Each function does one thing well
2. **Defensive Programming**: Validate all inputs, provide clear error messages
3. **Fail Fast**: Stop immediately with actionable errors rather than propagating bad data
4. **Consistent Interface**: Similar functions have similar signatures
5. **Performance Conscious**: Note performance characteristics in documentation

## Maintenance

**This code is used by ALL Turas modules.** Changes here affect:
- confidence, tabs, tracker, segment modules
- keydriver, catdriver, conjoint, maxdiff modules
- pricing, weighting modules
- All future modules

**Before making changes:**
1. Consider impact on all dependent modules
2. Maintain backward compatibility when possible
3. Test with all modules that use the changed functions
4. Update version comments if making breaking changes

## Version History

- **V1.1** (2026-03) - Stats pack writer added
  - `stats_pack_writer.R` — universal diagnostic workbook generator
  - Deployed across all 9 analytical modules (confidence, keydriver, catdriver,
    conjoint, maxdiff, pricing, segment, weighting, tracker)
  - Tests in `modules/shared/tests/testthat/test_stats_pack_writer.R`

- **V1.0** (2025-11-13) - Initial extraction from shared_functions.R V9.9.1
  - Organized into logical modules (config, data, validation, logging)
  - Maintained full backward compatibility
  - Extracted from tabs module's shared_functions.R
