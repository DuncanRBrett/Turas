# Turas Shared Utilities

Common utility functions used across all Turas modules.

## Purpose

This shared module eliminates code duplication across Turas modules (tabs, tracker, segment, etc.) by providing a single source of truth for common operations.

## Organization

```
modules/shared/lib/
├── config_utils.R      # Excel config loading and validation
├── data_utils.R        # Data loading and type conversion
├── logging_utils.R     # Logging, progress tracking, error tracking
└── validation_utils.R  # Input validation functions
```

## Usage

In your module scripts, source the utilities you need:

```r
# Source shared utilities
source("../shared/lib/validation_utils.R")
source("../shared/lib/config_utils.R")
source("../shared/lib/data_utils.R")
source("../shared/lib/logging_utils.R")
```

## Key Functions

### Configuration (config_utils.R)

- `load_config_sheet(file_path, sheet_name)` - Load Excel config with validation
- `get_config_value(config, name, default, required)` - Safely retrieve config value
- `get_numeric_config()`, `get_logical_config()`, `get_char_config()` - Typed getters
- `resolve_path(base, relative)` - Platform-independent path resolution

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

## Design Principles

1. **Single Responsibility**: Each function does one thing well
2. **Defensive Programming**: Validate all inputs, provide clear error messages
3. **Fail Fast**: Stop immediately with actionable errors rather than propagating bad data
4. **Consistent Interface**: Similar functions have similar signatures
5. **Performance Conscious**: Note performance characteristics in documentation

## Maintenance

**This code is used by ALL Turas modules.** Changes here affect:
- tabs module
- tracker module
- segment module
- confidence module
- Future modules

**Before making changes:**
1. Consider impact on all dependent modules
2. Maintain backward compatibility when possible
3. Test with all modules that use the changed functions
4. Update version comments if making breaking changes

## Version History

- **V1.0** (2025-11-13) - Initial extraction from shared_functions.R V9.9.1
  - Organized into logical modules (config, data, validation, logging)
  - Maintained full backward compatibility
  - Extracted from tabs module's shared_functions.R
