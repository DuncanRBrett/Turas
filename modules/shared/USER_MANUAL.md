# Turas Shared Utilities - User Manual

**Version:** 10.0
**For:** Module Developers
**Purpose:** Guide to using shared utilities in your Turas modules

---

## Overview

The Turas Shared utilities module provides common functions used across all Turas modules. Instead of duplicating code, all modules source these utilities for configuration loading, data validation, logging, formatting, and weight calculations.

**Who should read this manual:**
- Developers creating new Turas modules
- Developers maintaining existing modules
- Developers modifying shared utility code

---

## Getting Started

### Quick Start

To use shared utilities in your module:

```r
# Source the utilities you need
source("../shared/lib/config_utils.R")
source("../shared/lib/data_utils.R")
source("../shared/lib/validation_utils.R")
source("../shared/lib/logging_utils.R")

# Or for legacy modules, source from root
source("../shared/formatting.R")
source("../shared/weights.R")
source("../shared/config_utils.R")
```

### Module Structure

```
modules/shared/
├── lib/                           # Modular utilities (recommended)
│   ├── config_utils.R            # Excel config loading
│   ├── data_utils.R              # Data loading and type conversion
│   ├── validation_utils.R        # Input validation
│   └── logging_utils.R           # Logging and progress tracking
│
└── (legacy root files - backward compatibility)
    ├── config_utils.R            # Legacy config parsing
    ├── formatting.R              # Number formatting for Excel
    └── weights.R                 # Weight calculation
```

**Recommendation**: Use `/lib/` utilities for new code.

---

## Common Tasks

### 1. Loading Configuration Files

**Task**: Load settings from an Excel configuration file.

```r
# Source utility
source("../shared/lib/config_utils.R")

# Load config sheet
config <- load_config_sheet("Config.xlsx", "Settings")

# Get values with defaults
sig_level <- get_numeric_config(config, "significance_level",
                                default = 0.95, min = 0, max = 1)

show_sig <- get_logical_config(config, "show_significance", default = TRUE)

decimal_sep <- get_char_config(config, "decimal_separator",
                               default = ".",
                               allowed_values = c(".", ","))
```

**Benefits**:
- Automatic type conversion (Y/N → TRUE/FALSE)
- Built-in validation (range checks, whitelists)
- Clear error messages if config is invalid
- Handles missing values with defaults

---

### 2. Loading Survey Data

**Task**: Load survey data from multiple file formats.

```r
# Source utility
source("../shared/lib/data_utils.R")

# Load data (auto-detects format)
survey_data <- load_survey_data("data.csv")  # or .xlsx, .xls, .sav

# Load with SPSS label conversion
survey_data <- load_survey_data("data.sav", convert_labelled = TRUE)
```

**Supported Formats**:
- `.xlsx`, `.xls` (Excel)
- `.csv` (CSV - uses data.table for 10x speedup if available)
- `.sav` (SPSS)

**Performance**: Automatically uses `data.table::fread()` for CSV files if the package is installed (500 MB/sec vs 50 MB/sec).

---

### 3. Validating Inputs

**Task**: Validate function inputs to fail fast with clear error messages.

```r
# Source utility
source("../shared/lib/validation_utils.R")

# Validate at function entry
my_analysis <- function(survey_data, n_clusters, max_iterations) {

  # Validate data frame
  validate_data_frame(survey_data,
                     required_cols = c("ResponseID", "Q1", "Q2"),
                     min_rows = 10)

  # Validate numeric parameter with range
  validate_numeric_param(n_clusters, "n_clusters",
                        min = 2, max = 20)

  validate_numeric_param(max_iterations, "max_iterations",
                        min = 1, max = 10000)

  # Now safe to proceed with analysis...
}
```

**Available Validators**:
- `validate_data_frame()` - Check structure, columns, row count
- `validate_numeric_param()` - Numeric with range checking
- `validate_logical_param()` - TRUE/FALSE validation
- `validate_char_param()` - Character with whitelist
- `validate_file_path()` - File existence and extension
- `validate_column_exists()` - Column presence in data
- `validate_weights()` - Weight vector validation

**Benefits**:
- Errors caught immediately at function entry
- Clear, actionable error messages
- Consistent error format across all modules

---

### 4. Progress Tracking and Logging

**Task**: Show progress and log messages during long-running operations.

```r
# Source utility
source("../shared/lib/logging_utils.R")

# Print header
print_toolkit_header("Segment Analysis", "10.0")

# Log messages
log_message("Starting analysis", "INFO")
log_message("Missing data detected in Q5", "WARNING")

# Progress bar with ETA
questions <- c("Q1", "Q2", "Q3", ..., "Q50")
n_questions <- length(questions)
start_time <- Sys.time()

for (i in 1:n_questions) {
  log_progress(i, n_questions, questions[i], start_time)

  # Process question...
  process_question(questions[i])
}

# Output:
# [  2%] 1/50 | ETA: 5.2s Q1
# [  4%] 2/50 | ETA: 4.9s Q2
# ...
# [100%] 50/50 | ETA: 0.0s Q50
```

**Error Logging**:

```r
# Initialize error log
error_log <- create_error_log()

# Log issues during processing
if (missing_data_detected) {
  error_log <- log_issue(
    error_log,
    component = "Data Validation",
    issue_type = "Missing Data",
    description = "Question Q5 has no responses",
    question_code = "Q5",
    severity = "Warning"
  )
}

# Review at end
if (nrow(error_log) > 0) {
  cat("\n=== ISSUES DETECTED ===\n")
  print(error_log)
}
```

---

### 5. Formatting Numbers for Excel

**Task**: Format numbers in Excel output with proper decimal separators.

```r
# Source utility
source("../shared/formatting.R")

# Create Excel styles from config
styles <- create_excel_number_styles(
  decimal_separator = config$decimal_separator,
  decimal_places_percent = 0,
  decimal_places_ratings = 1,
  decimal_places_index = 1
)

# Apply to worksheet
openxlsx::addStyle(wb, "Results",
                  style = styles$percentage,
                  rows = 2:100, cols = 3,
                  gridExpand = TRUE)

openxlsx::addStyle(wb, "Results",
                  style = styles$rating,
                  rows = 2:100, cols = 5,
                  gridExpand = TRUE)
```

**For Text Formatting**:

```r
# Format as string (for labels, not Excel cells)
formatted <- format_number(95.5, decimal_places = 1, decimal_separator = ",")
# Returns: "95,5"

formatted_pct <- format_percentage(95.5, 1, ",", include_percent_sign = TRUE)
# Returns: "95,5%"
```

**Important**: Excel format codes always use `.` internally. Excel handles locale conversion. The `decimal_separator` parameter only affects text formatting.

---

### 6. Working with Survey Weights

**Task**: Calculate effective sample size and design effect for weighted data.

```r
# Source utility
source("../shared/weights.R")

# Validate weights
weights <- survey_data$weight
validation <- validate_weights(weights, allow_na = FALSE)

if (!validation$valid) {
  stop(paste("Weight validation failed:", paste(validation$issues, collapse = "\n")))
}

# Calculate efficiency
eff_n <- calculate_weight_efficiency(weights)
deff <- calculate_design_effect(weights)

cat(sprintf("Sample size: %d\n", length(weights)))
cat(sprintf("Effective n: %.1f (%.1f%% efficiency)\n",
            eff_n, 100 * eff_n / length(weights)))
cat(sprintf("Design effect: %.2f\n", deff))

# Output:
# Sample size: 1000
# Effective n: 857.3 (85.7% efficiency)
# Design effect: 1.17

# Get full summary
summary <- get_weight_summary(weights)
print(summary)
```

**Interpretation**:
- **Weight Efficiency**: Effective sample size after accounting for variance inflation
- **Design Effect (deff)**:
  - deff = 1: No inflation (equal weights)
  - deff > 1: Standard errors are √deff times larger
  - deff = 2: Standard errors are 1.41x larger

---

## Type Conversion Helpers

### Safe Numeric Conversion

**Problem**: `as.numeric("abc")` generates warnings.

**Solution**:
```r
source("../shared/lib/data_utils.R")

# No warnings, returns NA for failures
value <- safe_numeric("123")       # 123
value <- safe_numeric("abc")       # NA_real_
value <- safe_numeric("abc", 0)    # 0 (custom NA value)
```

### Safe Logical Conversion

**Problem**: Need to handle Y/N, YES/NO, T/F, 1/0, TRUE/FALSE.

**Solution**:
```r
source("../shared/lib/data_utils.R")

# Case-insensitive conversion
safe_logical("Y")        # TRUE
safe_logical("yes")      # TRUE
safe_logical("1")        # TRUE
safe_logical("N")        # FALSE
safe_logical("abc")      # FALSE (with warning, uses default)
```

### Safe Equality Comparison

**Problem**: Need case-sensitive comparison with whitespace handling.

**Solution**:
```r
source("../shared/lib/data_utils.R")

# Trims whitespace, case-sensitive
safe_equal(" Apple ", "Apple")    # TRUE
safe_equal("Apple", "apple")      # FALSE (case-sensitive)
safe_equal(NA, NA)                # TRUE (both missing)
safe_equal(NA, "NA")              # FALSE (missing vs string)
```

---

## Path Resolution

**Problem**: Config files contain relative paths that need to be resolved.

**Solution**:
```r
source("../shared/lib/config_utils.R")

# Config file at: /project/config.xlsx
# Contains: data_file = "data/survey.csv"

project_root <- get_project_root("/project/config.xlsx")
# Returns: "/project"

data_path <- resolve_path(project_root, "data/survey.csv")
# Returns: "/project/data/survey.csv"

# Handles:
# - Platform independence (/ and \)
# - Parent directories (..)
# - Current directory (.)
# - Security (prevents directory traversal)
```

---

## Error Message Best Practices

All validation functions provide **actionable error messages**:

```r
# BAD: Generic error
stop("File not found")

# GOOD: Actionable error
validate_file_path("data.csv", must_exist = TRUE)
# Error message includes:
#   - What file was expected
#   - Whether directory exists
#   - Troubleshooting steps
```

**Example Error**:
```
file_path: File not found
  Path: /project/data.csv
  Directory exists: YES
  Looking for: data.csv

Troubleshooting:
  1. Check spelling and case sensitivity
  2. Verify file is in correct location
  3. Check file permissions
```

---

## Design Patterns

### 1. Fail Fast Pattern

Validate all inputs at function entry, not deep in processing logic.

```r
my_function <- function(data, n_clusters) {
  # Validate FIRST
  validate_data_frame(data, required_cols = c("ID", "Response"), min_rows = 10)
  validate_numeric_param(n_clusters, "n_clusters", min = 2, max = 20)

  # Now safe to process...
}
```

### 2. Safe Defaults Pattern

Always provide sensible defaults for optional config values.

```r
# GOOD: Provides default
sig_level <- get_numeric_config(config, "significance_level",
                                default = 0.95, min = 0, max = 1)

# BETTER: Type-safe with validation
decimal_places <- get_numeric_config(config, "decimal_places",
                                    default = 1, min = 0, max = 6)
```

### 3. Progressive Enhancement Pattern

Use optional packages for performance boost without hard dependency.

```r
# CSV loading uses data.table if available, falls back to base R
survey_data <- load_survey_data("data.csv")

# Internally:
# - If data.table installed: 500 MB/sec
# - Otherwise: 50 MB/sec (base R)
```

---

## Performance Tips

### 1. Install data.table for Faster CSV Loading

```r
install.packages("data.table")
```

**Benefit**: 10x faster CSV loading (500 MB/sec vs 50 MB/sec)

### 2. Convert Large Excel Files to CSV

For files >100 MB, convert to CSV for faster loading:
- Excel: ~10 MB/sec
- CSV (with data.table): ~500 MB/sec

### 3. Large File Warnings

Files >500 MB trigger warnings. Strategies:
- Convert to CSV
- Split into chunks
- Consider database backend for >5 GB

---

## Common Pitfalls

### ❌ Don't: Use comma in Excel format codes

```r
# WRONG: This divides by 1000!
format_code <- "0,00"  # 8.2 becomes "08"

# CORRECT: Always use period
format_code <- "0.00"  # Excel handles locale conversion
```

**Use**: `create_excel_number_format()` which handles this correctly.

### ❌ Don't: Skip input validation

```r
# RISKY: No validation
my_function <- function(data, n_clusters) {
  # Errors happen deep in processing
  result <- kmeans(data, centers = n_clusters)
}

# SAFE: Validate first
my_function <- function(data, n_clusters) {
  validate_data_frame(data, min_rows = 10)
  validate_numeric_param(n_clusters, "n_clusters", min = 2, max = 20)
  result <- kmeans(data, centers = n_clusters)
}
```

### ❌ Don't: Assume config values exist

```r
# RISKY: Will error if missing
decimal_places <- config$decimal_places

# SAFE: Provides default
decimal_places <- get_numeric_config(config, "decimal_places", default = 1)
```

---

## Maintenance Notes

### Impact on Other Modules

**CRITICAL**: Shared utilities are used by ALL Turas modules:
- AlchemerParser
- tabs
- tracker
- confidence
- segment
- conjoint
- keydriver
- pricing

**Before making changes:**
1. Consider impact on all dependent modules
2. Maintain backward compatibility when possible
3. Test with all modules that use the changed functions
4. Update version comments if making breaking changes

### Adding New Utilities

**Template** for adding new validation function:

```r
#' Validate [What You're Validating]
#'
#' [Brief description]
#'
#' @param value [Type], value to validate
#' @param param_name Character, parameter name for errors
#' @return Invisible TRUE if valid, stops with error if invalid
#' @export
validate_[thing] <- function(value, param_name, ...) {
  # 1. Type check
  if (!is.[type](value)) {
    stop(sprintf("%s must be [type], got: %s",
                 param_name, class(value)[1]))
  }

  # 2. Range/content checks
  if ([violation]) {
    stop(sprintf("%s [violation description]", param_name))
  }

  invisible(TRUE)
}
```

---

## Documentation

For complete technical details, see:
- **TECHNICAL_DOCS.md** - Complete API reference, algorithms, design patterns
- **README.md** - Quick overview and organization

---

## Support

### Questions or Issues?

1. Check **TECHNICAL_DOCS.md** for detailed API reference
2. Review examples in other modules (tabs, tracker, etc.)
3. Contact Turas development team

### Contributing

When adding new utilities:
1. Follow existing naming conventions
2. Include comprehensive error messages
3. Add examples in this user manual
4. Update TECHNICAL_DOCS.md with API details
5. Test with multiple modules

---

## Quick Reference

### Most-Used Functions

**Configuration**:
```r
config <- load_config_sheet("Config.xlsx", "Settings")
value <- get_numeric_config(config, "setting_name", default = 1, min = 0, max = 10)
```

**Data Loading**:
```r
data <- load_survey_data("data.csv")  # Auto-detects format
```

**Validation**:
```r
validate_data_frame(data, required_cols = c("ID", "Q1"), min_rows = 10)
validate_numeric_param(value, "parameter_name", min = 0, max = 100)
```

**Logging**:
```r
log_message("Processing data", "INFO")
log_progress(i, total, item_name, start_time)
```

**Formatting**:
```r
styles <- create_excel_number_styles(decimal_separator = ".")
formatted <- format_number(95.5, 1, ",")  # "95,5"
```

**Weights**:
```r
eff_n <- calculate_weight_efficiency(weights)
deff <- calculate_design_effect(weights)
```

---

**Version:** 10.0
**Last Updated:** December 6, 2025
