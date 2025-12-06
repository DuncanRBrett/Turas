# Shared Utilities Module - Technical Documentation

**Version:** Turas v10.0
**Module Type:** Cross-Module Infrastructure
**Lines of Code:** ~1,600 LOC (utilities)
**Purpose:** Common utilities shared across all Turas modules to eliminate code duplication

---

## Table of Contents

1. [Overview](#overview)
2. [Module Architecture](#module-architecture)
3. [File Organization](#file-organization)
4. [Configuration Utilities](#configuration-utilities)
5. [Data Utilities](#data-utilities)
6. [Validation Utilities](#validation-utilities)
7. [Logging Utilities](#logging-utilities)
8. [Formatting Utilities](#formatting-utilities)
9. [Weight Utilities](#weight-utilities)
10. [API Reference](#api-reference)
11. [Design Patterns](#design-patterns)
12. [Extension Points](#extension-points)

---

## 1. Overview

### Purpose

The Shared utilities module provides a single source of truth for common operations used across all Turas modules. This eliminates code duplication and ensures consistent behavior for:

- **Configuration Loading**: Excel config file reading and parsing
- **Data Loading**: Multi-format survey data loading (.xlsx, .xls, .csv, .sav)
- **Validation**: Input validation with detailed error messages
- **Logging**: Progress tracking and error logging
- **Formatting**: Number formatting for Excel output
- **Weights**: Weight calculation and validation

### Design Philosophy

1. **Single Responsibility**: Each function does one thing well
2. **Defensive Programming**: Validate all inputs, provide clear error messages
3. **Fail Fast**: Stop immediately with actionable errors rather than propagating bad data
4. **Consistent Interface**: Similar functions have similar signatures
5. **Performance Conscious**: Optimize for common use cases

### Dependent Modules

**CRITICAL**: This code is used by ALL Turas modules:
- AlchemerParser
- Tabs
- Tracker
- Segment
- Confidence
- Conjoint
- KeyDriver
- Pricing

**Before making changes:**
1. Consider impact on all dependent modules
2. Maintain backward compatibility when possible
3. Test with all modules that use the changed functions
4. Update version comments if making breaking changes

---

## 2. Module Architecture

### Directory Structure

```
modules/shared/
├── lib/                           # Modular utilities (v10.0+)
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

### Version History

- **V10.0** (2025-11-13): Modular extraction
  - Created `/lib/` subdirectory with logical organization
  - Extracted from tabs module's `shared_functions.R` V9.9.1
  - Maintained full backward compatibility
  - Added comprehensive documentation

- **V9.x**: Monolithic `shared_functions.R` (deprecated)

### Two-Tier Architecture

The Shared utilities module uses a **two-tier architecture**:

1. **`/lib/` utilities** (NEW): Modular, well-documented, granular functions
2. **Root utilities** (LEGACY): Backward compatibility for existing modules

**Recommendation for new code**: Source from `/lib/` directory for better organization and documentation.

---

## 3. File Organization

### Modular Utilities (`/lib/`)

#### `config_utils.R` (257 LOC)

**Purpose**: Configuration file loading and validation

**Key Functions**:
- `load_config_sheet()` - Load Excel config with structure validation
- `get_config_value()` - Safe config retrieval with defaults
- `get_numeric_config()`, `get_logical_config()`, `get_char_config()` - Typed getters
- `resolve_path()` - Platform-independent path resolution
- `get_project_root()` - Determine project root from config location

**Usage Pattern**:
```r
source("../shared/lib/config_utils.R")
config <- load_config_sheet("Config.xlsx", "Settings")
sig_level <- get_numeric_config(config, "significance_level", default = 0.95, min = 0, max = 1)
```

#### `data_utils.R` (241 LOC)

**Purpose**: Data loading and type conversion

**Key Functions**:
- `load_survey_data()` - Load .xlsx, .xls, .csv, .sav files with format detection
- `safe_equal()` - Case-sensitive comparison with whitespace trimming
- `safe_numeric()`, `safe_logical()` - Safe type conversion
- `calc_percentage()` - Percentage calculation with 0/0 handling

**Performance Characteristics**:
- Excel: ~10MB/sec
- CSV (base R): ~50MB/sec
- CSV (data.table): ~500MB/sec (auto-enabled if available)
- SPSS: ~20MB/sec

**Usage Pattern**:
```r
source("../shared/lib/data_utils.R")
survey_data <- load_survey_data("data.csv")
# Automatically uses data.table::fread() if available for 10x speedup
```

#### `validation_utils.R` (312 LOC)

**Purpose**: Input validation functions

**Key Functions**:
- `validate_data_frame()` - Data frame structure validation
- `validate_numeric_param()` - Numeric parameter with range checking
- `validate_logical_param()` - TRUE/FALSE validation
- `validate_char_param()` - Character parameter with whitelist
- `validate_file_path()` - File existence and extension validation
- `validate_column_exists()` - Column presence check
- `validate_weights()` - Weight vector validation
- `has_data()` - Quick data frame emptiness check

**Error Message Design**:
All validation functions provide **actionable error messages** with:
- What was expected
- What was actually received
- Troubleshooting suggestions

**Usage Pattern**:
```r
source("../shared/lib/validation_utils.R")

# Validate at function entry
my_function <- function(data, n_clusters) {
  validate_data_frame(data, required_cols = c("ID", "Response"), min_rows = 10)
  validate_numeric_param(n_clusters, "n_clusters", min = 2, max = 20)

  # Function logic here...
}
```

#### `logging_utils.R` (133 LOC)

**Purpose**: Logging, progress tracking, error tracking

**Key Functions**:
- `log_message()` - Timestamped logging with levels (INFO/WARNING/ERROR/DEBUG)
- `log_progress()` - Progress bar with percentage and ETA
- `create_error_log()` - Initialize structured error log
- `log_issue()` - Add issue to error log
- `print_toolkit_header()` - Branding header

**Usage Pattern**:
```r
source("../shared/lib/logging_utils.R")

print_toolkit_header("Segment Analysis", "10.0")

# Progress tracking
start_time <- Sys.time()
for (i in 1:n_questions) {
  log_progress(i, n_questions, question_codes[i], start_time)
  # Process question...
}

# Error logging
error_log <- create_error_log()
error_log <- log_issue(error_log, "Validation", "Missing Data",
                       "Question Q1 has no responses", "Q1", "Warning")
```

### Legacy Utilities (Root)

#### `formatting.R` (318 LOC)

**Purpose**: Number and text formatting for Excel output

**Key Functions**:
- `create_excel_number_format()` - Generate Excel numFmt codes
- `create_excel_number_styles()` - Create openxlsx style objects
- `format_number()`, `format_percentage()`, `format_index()` - String formatting
- `validate_decimal_separator()`, `validate_decimal_places()` - Config validation

**Critical Design Decision**: Excel format codes always use `.` for decimal separator (Excel handles locale conversion internally). The `decimal_separator` parameter only affects text formatting.

**Usage Pattern**:
```r
source("../shared/formatting.R")

# Create Excel styles
styles <- create_excel_number_styles(
  decimal_separator = ",",
  decimal_places_percent = 0,
  decimal_places_ratings = 1
)

# Apply to worksheet
openxlsx::addStyle(wb, sheet, style = styles$percentage, rows = 2:100, cols = 3)
```

#### `weights.R` (327 LOC)

**Purpose**: Weight calculation and validation

**Key Functions**:
- `calculate_weight_efficiency()` - Effective sample size (Kish formula)
- `calculate_design_effect()` - Design effect (deff)
- `validate_weights()` - Comprehensive weight validation
- `get_weight_summary()` - Descriptive statistics
- `standardize_weight_variable()` - Create standardized weight column

**Statistical Background**:
```r
# Weight Efficiency (Effective Sample Size)
efficiency = (sum of weights)^2 / sum of squared weights

# Design Effect
deff = n / effective_n

# Interpretation:
# - deff = 1: No design effect (equal weights)
# - deff > 1: Variance inflation due to weighting
# - deff = 2: Standard errors are ~1.41x larger
```

**Usage Pattern**:
```r
source("../shared/weights.R")

# Validate weights
validation <- validate_weights(weights, allow_na = FALSE)
if (!validation$valid) {
  stop(paste(validation$issues, collapse = "\n"))
}

# Calculate efficiency
eff_n <- calculate_weight_efficiency(weights)
cat(sprintf("Effective sample size: %.0f (%.1f%% of actual n)\n",
            eff_n, 100 * eff_n / length(weights)))
```

#### `config_utils.R` (356 LOC)

**Purpose**: Configuration file handling (legacy interface)

**Key Functions**:
- `read_config_sheet()` - Generic Excel sheet reader
- `parse_settings_to_list()` - Convert Setting/Value dataframe to list
- `get_setting()` - Retrieve setting with default
- `get_typed_setting()` - Type-safe setting retrieval
- `validate_required_columns()` - Column existence check
- `check_duplicates()` - Uniqueness validation
- `validate_date_range()` - Date validation

**Usage Pattern**:
```r
source("../shared/config_utils.R")

# Load and parse settings
settings_df <- read_config_sheet("config.xlsx", "Settings")
settings <- parse_settings_to_list(settings_df)

# Access with type safety
decimal_sep <- get_setting(settings, "decimal_separator", default = ".")
show_sig <- get_typed_setting(settings, "show_significance", default = TRUE, type = "logical")
```

---

## 4. Configuration Utilities

### Configuration Loading Pipeline

```
Excel Config File (.xlsx)
         ↓
load_config_sheet() / read_config_sheet()
         ↓
Validate structure (Setting/Value columns)
         ↓
Check for duplicates
         ↓
Convert to named list
         ↓
Type conversion (Y/N → logical, numbers → numeric)
         ↓
Return config object
```

### Configuration Sheet Structure

**Expected Format**:
```
| Setting              | Value    |
|---------------------|----------|
| decimal_separator   | .        |
| significance_level  | 0.95     |
| show_significance   | Y        |
| decimal_places      | 1        |
| data_file           | data.csv |
```

### Type Conversion Rules

**Automatic Type Conversion** (in `parse_settings_to_list()`):

1. **Y/N → Logical**:
   - `"Y"`, `"YES"`, `"TRUE"` → `TRUE`
   - `"N"`, `"NO"`, `"FALSE"` → `FALSE`
   - Case-insensitive

2. **Numeric Strings → Numeric**:
   - Pattern: `^-?[0-9.]+$`
   - Examples: `"0.95"` → `0.95`, `"123"` → `123`

3. **Everything Else → Character**:
   - Preserved as-is

### Path Resolution

**Problem**: Config files contain relative paths that need to be resolved to absolute paths.

**Solution**: `resolve_path()` function

```r
# Config file at: /project/config.xlsx
# Contains: data_file = "data/survey.csv"

project_root <- get_project_root("/project/config.xlsx")
# Returns: "/project"

data_path <- resolve_path(project_root, "data/survey.csv")
# Returns: "/project/data/survey.csv"
```

**Features**:
- Platform-independent (handles both `/` and `\`)
- Resolves `..` (parent directory)
- Removes leading `./`
- Normalizes to OS-specific separators
- Security: Prevents directory traversal attacks via normalization

### Error Handling

**Duplicate Settings**:
```r
# If config contains:
# decimal_separator, .
# decimal_separator, ,

# Error:
# Duplicate settings found in configuration:
#   decimal_separator
#
# Each setting must appear only once.
```

**Missing Required Settings**:
```r
data_file <- get_config_value(config, "data_file", required = TRUE)

# If missing:
# Required setting 'data_file' not found in configuration
#
# Available settings:
#   decimal_separator
#   significance_level
#   show_significance
#   ...
```

---

## 5. Data Utilities

### Data Loading

#### Multi-Format Support

**Supported Formats**:
- `.xlsx` - Excel 2007+ (via readxl)
- `.xls` - Excel 97-2003 (via readxl)
- `.csv` - Comma-separated values (via data.table or base R)
- `.sav` - SPSS data files (via haven)

**Format Detection**: Automatic based on file extension (case-insensitive)

#### Loading Algorithm

```r
load_survey_data <- function(data_file_path, project_root = NULL,
                             convert_labelled = FALSE) {

  # 1. Resolve path if relative
  if (!is.null(project_root) && !file.exists(data_file_path)) {
    data_file_path <- resolve_path(project_root, data_file_path)
  }

  # 2. Validate file exists
  validate_file_path(data_file_path, must_exist = TRUE)

  # 3. Detect file type
  file_ext <- tolower(tools::file_ext(data_file_path))

  # 4. Load with format-specific handler
  survey_data <- switch(file_ext,
    "xlsx" = readxl::read_excel(data_file_path),
    "xls"  = readxl::read_excel(data_file_path),
    "csv"  = {
      # Fast-path: data.table if available (10x faster)
      if (requireNamespace("data.table", quietly = TRUE)) {
        data.table::fread(data_file_path, data.table = FALSE)
      } else {
        read.csv(data_file_path, stringsAsFactors = FALSE)
      }
    },
    "sav"  = {
      dat <- haven::read_sav(data_file_path)
      if (convert_labelled) dat <- haven::zap_labels(dat)
      dat
    }
  )

  # 5. Validate loaded data
  # - Check is data frame
  # - Check has rows
  # - Check has columns

  # 6. Return
  return(survey_data)
}
```

#### Performance Characteristics

| Format | Package      | Speed        | Notes                           |
|--------|-------------|--------------|----------------------------------|
| .xlsx  | readxl      | ~10 MB/sec   | Reliable, no Java dependency    |
| .xls   | readxl      | ~10 MB/sec   | Legacy format                   |
| .csv   | base R      | ~50 MB/sec   | Default fallback                |
| .csv   | data.table  | ~500 MB/sec  | 10x faster, auto-enabled        |
| .sav   | haven       | ~20 MB/sec   | SPSS labelled data support      |

**Memory**: Loads entire file into RAM. Files >500MB will show warning.

#### SPSS Labelled Data

SPSS `.sav` files often contain **labelled data**:
```r
# Example: Gender variable
# Value 1 has label "Male"
# Value 2 has label "Female"

# Option 1: Keep labels (default)
data <- load_survey_data("survey.sav", convert_labelled = FALSE)
# Gender column is class "haven_labelled"

# Option 2: Convert to plain R types
data <- load_survey_data("survey.sav", convert_labelled = TRUE)
# Gender column is numeric (1, 2)
```

### Type Conversion

#### `safe_numeric()`

**Problem**: `as.numeric("abc")` generates warning and returns `NA`

**Solution**:
```r
safe_numeric <- function(x, na_value = NA_real_) {
  result <- suppressWarnings(as.numeric(x))
  result[is.na(result)] <- na_value
  return(result)
}

# Usage
safe_numeric("123")      # → 123
safe_numeric("abc")      # → NA_real_ (no warning)
safe_numeric("abc", 0)   # → 0 (custom NA value)
```

#### `safe_logical()`

**Problem**: Need to handle multiple text representations of TRUE/FALSE

**Solution**: Case-insensitive mapping
```r
safe_logical <- function(x, default = FALSE) {
  x_upper <- toupper(trimws(as.character(x)))

  if (x_upper %in% c("TRUE", "T", "Y", "YES", "1")) return(TRUE)
  if (x_upper %in% c("FALSE", "F", "N", "NO", "0")) return(FALSE)

  warning(sprintf("Could not convert '%s' to logical, using default: %s", x, default))
  return(default)
}

# Usage
safe_logical("Y")        # → TRUE
safe_logical("yes")      # → TRUE
safe_logical("1")        # → TRUE
safe_logical("abc")      # → FALSE (with warning)
```

#### `safe_equal()`

**Purpose**: Type-safe equality comparison with whitespace trimming

**Features**:
- Case-sensitive: `"Apple" != "apple"`
- Trims whitespace: `" Apple " == "Apple"`
- NA handling: `NA == NA` → `TRUE`, `NA != "NA"` → `FALSE`
- Vectorized

```r
safe_equal <- function(a, b) {
  # Handle empty inputs
  if (length(a) == 0 || length(b) == 0) return(logical(0))

  # Vectorize to longer length
  max_len <- max(length(a), length(b))
  if (length(a) < max_len) a <- rep_len(a, max_len)
  if (length(b) < max_len) b <- rep_len(b, max_len)

  result <- rep(FALSE, max_len)

  # Both NA = TRUE
  both_na <- is.na(a) & is.na(b)
  result[both_na] <- TRUE

  # Compare non-NA (trim whitespace)
  neither_na <- !is.na(a) & !is.na(b)
  if (any(neither_na)) {
    result[neither_na] <- trimws(as.character(a[neither_na])) ==
                          trimws(as.character(b[neither_na]))
  }

  return(result)
}
```

### Percentage Calculation

**Problem**: Division by zero in percentage calculations

**Solution**: `calc_percentage()` returns `NA_real_` for 0/0
```r
calc_percentage <- function(numerator, denominator, decimal_places = 0) {
  if (is.na(denominator) || denominator == 0) return(NA_real_)
  return(round((numerator / denominator) * 100, decimal_places))
}

# Usage
calc_percentage(95, 100)     # → 95
calc_percentage(95, 100, 1)  # → 95.0
calc_percentage(10, 0)       # → NA_real_ (not error)
```

---

## 6. Validation Utilities

### Validation Philosophy

**Fail Fast Principle**: Detect errors at input validation rather than deep in processing logic.

**Benefits**:
1. **Clear Error Messages**: User sees exactly what's wrong
2. **Easier Debugging**: Error occurs at entry point, not 100 lines later
3. **Data Integrity**: Prevents bad data from propagating through pipeline
4. **Security**: Input validation prevents injection attacks

### Data Frame Validation

```r
validate_data_frame <- function(data, required_cols = NULL, min_rows = 1,
                               max_rows = Inf, param_name = "data") {
  # 1. Type check
  if (!is.data.frame(data)) {
    stop(sprintf("%s must be a data frame, got: %s",
                 param_name, paste(class(data), collapse = ", ")))
  }

  # 2. Row count check
  n_rows <- nrow(data)
  if (n_rows < min_rows) {
    stop(sprintf("%s must have at least %d rows, has %d",
                 param_name, min_rows, n_rows))
  }
  if (n_rows > max_rows) {
    stop(sprintf("%s exceeds maximum %d rows, has %d",
                 param_name, max_rows, n_rows))
  }

  # 3. Column check
  if (!is.null(required_cols) && length(required_cols) > 0) {
    missing <- setdiff(required_cols, names(data))
    if (length(missing) > 0) {
      available_preview <- head(names(data), 10)
      stop(sprintf(
        "%s missing required columns: %s\n\nAvailable columns: %s%s",
        param_name,
        paste(missing, collapse = ", "),
        paste(available_preview, collapse = ", "),
        if (ncol(data) > 10) sprintf(" ... (%d more)", ncol(data) - 10) else ""
      ))
    }
  }

  invisible(TRUE)
}
```

**Usage**:
```r
analyze_survey <- function(survey_data) {
  # Validate at entry
  validate_data_frame(survey_data,
                     required_cols = c("ResponseID", "Q1", "Q2"),
                     min_rows = 10)

  # Now safe to use survey_data...
}
```

### Numeric Parameter Validation

```r
validate_numeric_param <- function(value, param_name, min = -Inf, max = Inf,
                                  allow_na = FALSE) {
  # NA check
  if (is.na(value)) {
    if (!allow_na) stop(sprintf("%s cannot be NA", param_name))
    return(invisible(TRUE))
  }

  # Type and length check
  if (!is.numeric(value) || length(value) != 1) {
    stop(sprintf("%s must be a single numeric value, got: %s (length %d)",
                 param_name, class(value)[1], length(value)))
  }

  # Range check
  if (value < min || value > max) {
    stop(sprintf("%s must be between %g and %g, got: %g",
                 param_name, min, max, value))
  }

  invisible(TRUE)
}
```

**Usage**:
```r
run_clustering <- function(n_clusters, max_iterations = 100) {
  validate_numeric_param(n_clusters, "n_clusters", min = 2, max = 20)
  validate_numeric_param(max_iterations, "max_iterations", min = 1, max = 10000)

  # Now safe to use...
}
```

### Character Parameter Validation

**With Whitelist**:
```r
validate_char_param <- function(value, param_name, allowed_values = NULL,
                               allow_empty = FALSE) {
  # Type check
  if (!is.character(value) || length(value) != 1 || is.na(value)) {
    stop(sprintf("%s must be a single character value, got: %s",
                 param_name, if (is.null(value)) "NULL" else class(value)[1]))
  }

  # Empty check
  if (!allow_empty && nchar(trimws(value)) == 0) {
    stop(sprintf("%s cannot be empty", param_name))
  }

  # Whitelist check
  if (!is.null(allowed_values) && !value %in% allowed_values) {
    stop(sprintf("%s must be one of: %s\nGot: '%s'",
                 param_name, paste(allowed_values, collapse = ", "), value))
  }

  invisible(TRUE)
}
```

**Usage**:
```r
calculate_ci <- function(method = "bootstrap") {
  validate_char_param(method, "method",
                     allowed_values = c("bootstrap", "normal", "wilson", "bayesian"))

  # Now safe - method is guaranteed to be one of the four options
}
```

### File Path Validation

```r
validate_file_path <- function(file_path, param_name = "file_path",
                               must_exist = TRUE,
                               required_extensions = NULL,
                               validate_extension_even_if_missing = FALSE) {
  # Basic validation
  validate_char_param(file_path, param_name, allow_empty = FALSE)

  # Existence check
  if (must_exist && !file.exists(file_path)) {
    dir_part <- dirname(file_path)
    file_part <- basename(file_path)

    stop(sprintf(
      "%s: File not found\n  Path: %s\n  Directory exists: %s\n  Looking for: %s\n\nTroubleshooting:\n  1. Check spelling and case sensitivity\n  2. Verify file is in correct location\n  3. Check file permissions",
      param_name, file_path,
      if (dir.exists(dir_part)) "YES" else "NO",
      file_part
    ))
  }

  # Extension check
  if (!is.null(required_extensions) &&
      (must_exist || validate_extension_even_if_missing)) {
    file_ext <- tolower(tools::file_ext(file_path))

    if (!nzchar(file_ext) || !file_ext %in% required_extensions) {
      stop(sprintf(
        "%s: Invalid file type\n  Expected: %s\n  Got: .%s",
        param_name,
        paste0(".", required_extensions, collapse = " or "),
        if (nzchar(file_ext)) file_ext else "(no extension)"
      ))
    }
  }

  # Size check (if exists)
  if (must_exist) {
    file_size <- file.info(file_path)$size
    if (file_size > MAX_FILE_SIZE_BYTES) {  # 500 MB
      warning(sprintf(
        "%s: Large file detected (%.1f MB). Loading may be slow.",
        param_name, file_size / (1024 * 1024)
      ))
    }
  }

  invisible(TRUE)
}
```

**Usage**:
```r
# Validate input file exists
validate_file_path("data.csv", must_exist = TRUE,
                  required_extensions = c("csv", "xlsx"))

# Validate output file path (doesn't exist yet, but check extension)
validate_file_path("output.xlsx", must_exist = FALSE,
                  required_extensions = c("xlsx"),
                  validate_extension_even_if_missing = TRUE)
```

### Weight Validation

```r
validate_weights <- function(weights, min_weight = 0, max_weight = Inf,
                             allow_na = FALSE) {
  result <- list(
    valid = TRUE,
    n_total = length(weights),
    n_na = sum(is.na(weights)),
    n_zero = sum(weights == 0, na.rm = TRUE),
    n_negative = sum(weights < 0, na.rm = TRUE),
    n_too_small = sum(weights <= min_weight & weights > 0, na.rm = TRUE),
    n_too_large = sum(weights > max_weight, na.rm = TRUE),
    issues = character(0)
  )

  # Check for NA
  if (result$n_na > 0 && !allow_na) {
    result$valid <- FALSE
    result$issues <- c(result$issues, sprintf("%d NA weights found", result$n_na))
  }

  # Check for zero weights
  if (result$n_zero > 0) {
    result$valid <- FALSE
    result$issues <- c(result$issues, sprintf("%d zero weights found", result$n_zero))
  }

  # Check for negative weights
  if (result$n_negative > 0) {
    result$valid <- FALSE
    result$issues <- c(result$issues, sprintf("%d negative weights found", result$n_negative))
  }

  return(result)
}
```

**Usage**:
```r
weights <- survey_data$weight
validation <- validate_weights(weights, allow_na = FALSE)

if (!validation$valid) {
  cat("Weight validation failed:\n")
  cat(paste(" -", validation$issues, collapse = "\n"))
  stop("Fix weight issues before proceeding")
}
```

---

## 7. Logging Utilities

### Log Levels

**Supported Levels**:
- `INFO`: General information (default)
- `WARNING`: Non-critical issues
- `ERROR`: Critical failures
- `DEBUG`: Detailed diagnostic information

### Basic Logging

```r
log_message <- function(msg, level = "INFO", verbose = TRUE) {
  if (!verbose) return(invisible(NULL))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] %s: %s\n", timestamp, level, msg))
  invisible(NULL)
}
```

**Usage**:
```r
log_message("Starting analysis", "INFO")
# [2025-12-06 10:30:15] INFO: Starting analysis

log_message("Missing data detected in Q5", "WARNING")
# [2025-12-06 10:30:16] WARNING: Missing data detected in Q5

log_message("Analysis failed", "ERROR")
# [2025-12-06 10:30:17] ERROR: Analysis failed
```

### Progress Tracking

```r
log_progress <- function(current, total, item = "", start_time = NULL) {
  pct <- round(100 * current / total, 1)

  eta_str <- ""
  if (!is.null(start_time) && current > 0) {
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    rate <- elapsed / current
    remaining <- (total - current) * rate
    eta_str <- sprintf(" | ETA: %s", format_seconds(remaining))
  }

  cat(sprintf("\r[%3d%%] %d/%d%s %s",
             round(pct), current, total, eta_str, item))

  if (current == total) cat("\n")
  invisible(NULL)
}
```

**Usage**:
```r
questions <- c("Q1", "Q2", "Q3", ..., "Q50")
n_questions <- length(questions)
start_time <- Sys.time()

for (i in 1:n_questions) {
  log_progress(i, n_questions, questions[i], start_time)
  # Process question...
  Sys.sleep(0.1)  # Simulate work
}

# Output:
# [  2%] 1/50 | ETA: 5.2s Q1
# [  4%] 2/50 | ETA: 4.9s Q2
# ...
# [100%] 50/50 | ETA: 0.0s Q50
```

### Structured Error Logging

**Purpose**: Track issues during analysis for later reporting

```r
# Initialize
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

# At end of analysis, review error log
if (nrow(error_log) > 0) {
  cat("\n=== ISSUES DETECTED ===\n")
  print(error_log)
}
```

**Error Log Structure**:
```
| Timestamp           | Component        | Issue_Type    | Description              | QuestionCode | Severity |
|---------------------|------------------|---------------|--------------------------|--------------|----------|
| 2025-12-06 10:30:15 | Data Validation  | Missing Data  | Q5 has no responses      | Q5           | Warning  |
| 2025-12-06 10:30:16 | Banner Creation  | Empty Group   | Age 65+ has 0 respondents| AGE_65P      | Error    |
```

**Severity Guidelines**:
- **Error**: Prevents analysis from running (missing data, invalid config)
- **Warning**: Analysis can proceed but results may be affected
- **Info**: Informational messages (not actual problems)

### Toolkit Header

```r
print_toolkit_header <- function(analysis_type = "Analysis", version = "1.0") {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
  cat("  TURAS ANALYTICS TOOLKIT V", version, "\n", sep = "")
  cat("  ", analysis_type, "\n", sep = "")
  cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
  cat("\n")
}
```

**Output**:
```
================================================================================
  TURAS ANALYTICS TOOLKIT V10.0
  Segment Analysis
================================================================================
```

---

## 8. Formatting Utilities

### Excel Number Formatting

#### Critical Design Decision

**Problem**: Excel format codes use `.` for decimal and `,` for thousands separator. Using `,` in format code means "divide by 1000", causing `8.2` → `0.0082` → `"08"`.

**Solution**: Always use `.` in Excel format codes. Excel automatically displays with `,` if system locale uses comma.

```r
create_excel_number_format <- function(decimal_places = 1, decimal_separator = ".") {
  if (decimal_places == 0) return("0")

  # ALWAYS use . in format code regardless of user preference
  zeros <- paste(rep("0", decimal_places), collapse = "")
  format_code <- paste0("0", ".", zeros)

  return(format_code)
}

# Examples:
create_excel_number_format(0)  # "0"
create_excel_number_format(1)  # "0.0"
create_excel_number_format(2)  # "0.00"
```

**Note**: The `decimal_separator` parameter only affects TEXT formatting (`format_number()` function), not Excel's internal number format codes.

#### Excel Style Creation

```r
create_excel_number_styles <- function(decimal_separator = ".",
                                       decimal_places_percent = 0,
                                       decimal_places_ratings = 1,
                                       decimal_places_index = 1,
                                       decimal_places_numeric = 1,
                                       font_name = "Aptos",
                                       font_size = 12) {

  # Generate format codes
  fmt_pct <- create_excel_number_format(decimal_places_percent)
  fmt_rating <- create_excel_number_format(decimal_places_ratings)
  fmt_index <- create_excel_number_format(decimal_places_index)
  fmt_numeric <- create_excel_number_format(decimal_places_numeric)

  # Create style objects
  styles <- list(
    percentage = openxlsx::createStyle(
      fontSize = font_size, fontName = font_name,
      halign = "center", valign = "center",
      numFmt = fmt_pct
    ),
    rating = openxlsx::createStyle(
      fontSize = font_size, fontName = font_name,
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = fmt_rating
    ),
    index = openxlsx::createStyle(
      fontSize = font_size, fontName = font_name,
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = fmt_index
    ),
    numeric = openxlsx::createStyle(
      fontSize = font_size, fontName = font_name,
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = fmt_numeric
    )
  )

  return(styles)
}
```

**Usage**:
```r
# Create styles from config
styles <- create_excel_number_styles(
  decimal_separator = config$decimal_separator,
  decimal_places_percent = config$decimal_places_percent,
  decimal_places_ratings = config$decimal_places_ratings
)

# Apply to worksheet
openxlsx::addStyle(wb, "Results", style = styles$percentage,
                  rows = 2:100, cols = 3, gridExpand = TRUE)
```

### String Number Formatting

**When to Use**:
- Excel cells with numeric values: Use `create_excel_number_format()` + style
- Text labels or pre-formatted strings: Use `format_number()`

```r
format_number <- function(x, decimal_places = 1, decimal_separator = ".") {
  # Handle NULL and all NA
  if (is.null(x)) return(NULL)
  if (all(is.na(x))) return(as.character(x))

  # Validate inputs
  validate_decimal_separator(decimal_separator)
  validate_decimal_places(decimal_places)

  # Round to decimal places
  x_rounded <- round(x, decimal_places)

  # Format with specified decimals
  x_formatted <- format(x_rounded, nsmall = decimal_places, trim = TRUE)

  # Replace period with comma if needed
  if (decimal_separator == ",") {
    x_formatted <- gsub("\\.", ",", x_formatted)
  }

  return(x_formatted)
}
```

**Usage**:
```r
format_number(95.5, 1, ".")   # "95.5"
format_number(95.5, 1, ",")   # "95,5"
format_number(95.5, 0, ".")   # "96" (rounded)

# Vectorized
format_number(c(10.1, 20.2, 30.3), 1, ",")
# c("10,1", "20,2", "30,3")
```

### Percentage Formatting

```r
format_percentage <- function(x, decimal_places = 0, decimal_separator = ".",
                              include_percent_sign = FALSE) {
  formatted <- format_number(x, decimal_places, decimal_separator)

  if (include_percent_sign && !is.null(formatted)) {
    formatted <- paste0(formatted, "%")
  }

  return(formatted)
}
```

**Usage**:
```r
format_percentage(95.5, 1, ".", FALSE)   # "95.5"
format_percentage(95.5, 1, ".", TRUE)    # "95.5%"
format_percentage(95.5, 0, ",", TRUE)    # "96%"
```

---

## 9. Weight Utilities

### Weight Efficiency (Effective Sample Size)

**Statistical Background**:

When survey data is weighted, the effective sample size is reduced due to variance inflation. Weight efficiency measures this reduction.

**Formula**:
```
efficiency = (sum of weights)² / sum of squared weights
```

**Interpretation**:
- **Equal weights** (all = 1): efficiency = n (no information loss)
- **Varying weights**: efficiency < n (some information loss)
- **Highly variable weights**: efficiency << n (significant loss)

**Implementation**:
```r
calculate_weight_efficiency <- function(weights) {
  # Remove NA values
  weights <- weights[!is.na(weights)]

  # Handle empty or invalid input
  if (length(weights) == 0) {
    warning("No valid weights provided")
    return(0)
  }

  # Check for negative or zero weights
  if (any(weights <= 0)) {
    warning("Some weights are <= 0 (will be excluded)")
    weights <- weights[weights > 0]
  }

  if (length(weights) == 0) return(0)

  # Calculate efficiency (Kish formula)
  sum_weights <- sum(weights)
  sum_weights_squared <- sum(weights^2)

  if (sum_weights_squared == 0) return(0)

  eff_n <- (sum_weights^2) / sum_weights_squared
  return(eff_n)
}
```

**Example**:
```r
# Equal weights - efficiency equals sample size
weights <- rep(1, 100)
calculate_weight_efficiency(weights)  # 100

# Varying weights - efficiency less than sample size
weights <- c(rep(1, 90), rep(5, 10))
calculate_weight_efficiency(weights)  # ~71.4

# Interpretation: Effective sample size is 71.4, lost 28.6% due to weighting
```

### Design Effect (DEFF)

**Formula**:
```
deff = n / effective_n
```

**Interpretation**:
- **deff = 1**: No design effect (equal weights, simple random sample)
- **deff > 1**: Variance inflation due to weighting or clustering
- **deff = 2**: Standard errors are √2 ≈ 1.41 times larger than unweighted

**Implementation**:
```r
calculate_design_effect <- function(weights) {
  # Remove NA and invalid weights
  weights <- weights[!is.na(weights) & weights > 0]

  if (length(weights) == 0) return(NA_real_)

  n <- length(weights)
  eff_n <- calculate_weight_efficiency(weights)

  if (eff_n == 0) return(NA_real_)

  deff <- n / eff_n
  return(deff)
}
```

**Example**:
```r
weights <- c(rep(0.5, 50), rep(2, 50))
calculate_design_effect(weights)  # 1.25

# Interpretation: Standard errors are √1.25 ≈ 1.12 times larger
```

### Weight Validation

**Comprehensive Validation**:
```r
validation <- validate_weights(weights,
                               min_weight = 0,
                               max_weight = Inf,
                               allow_na = FALSE)

# Returns list:
# $valid - Logical, TRUE if all checks pass
# $n_total - Total number of weights
# $n_na - Number of NA weights
# $n_zero - Number of zero weights
# $n_negative - Number of negative weights
# $n_too_small - Number below min_weight
# $n_too_large - Number above max_weight
# $issues - Character vector of issue descriptions
```

**Usage Pattern**:
```r
weights <- survey_data$weight

# Validate
validation <- validate_weights(weights)

if (!validation$valid) {
  cat("Weight validation failed:\n")
  for (issue in validation$issues) {
    cat(sprintf("  - %s\n", issue))
  }
  stop("Fix weight issues before proceeding")
}

# Calculate efficiency
eff_n <- calculate_weight_efficiency(weights)
deff <- calculate_design_effect(weights)

cat(sprintf("Sample size: %d\n", validation$n_total))
cat(sprintf("Effective n: %.1f (%.1f%% efficiency)\n",
            eff_n, 100 * eff_n / validation$n_total))
cat(sprintf("Design effect: %.2f\n", deff))
```

### Weight Summary Statistics

```r
get_weight_summary <- function(weights) {
  valid_weights <- weights[!is.na(weights) & weights > 0]
  n_valid <- length(valid_weights)

  if (n_valid == 0) {
    return(data.frame(
      n = length(weights), n_valid = 0,
      min = NA, max = NA, mean = NA, median = NA, sum = NA,
      efficiency = NA, design_effect = NA
    ))
  }

  data.frame(
    n = length(weights),
    n_valid = n_valid,
    min = min(valid_weights),
    max = max(valid_weights),
    mean = mean(valid_weights),
    median = median(valid_weights),
    sum = sum(valid_weights),
    efficiency = calculate_weight_efficiency(valid_weights),
    design_effect = calculate_design_effect(valid_weights)
  )
}
```

**Output**:
```
  n  n_valid  min  max  mean  median    sum  efficiency  design_effect
100      100  0.5  2.0  1.00    1.00  100.0       100.0           1.00
```

### Standardize Weight Variable

**Purpose**: Create standardized weight column name across modules

```r
standardize_weight_variable <- function(data_df, weight_var,
                                       target_name = "weight_var",
                                       validate = TRUE,
                                       context_name = "Data") {

  # Check weight variable exists
  if (!weight_var %in% names(data_df)) {
    stop(sprintf(
      "%s: Weight variable '%s' not found in data.\nAvailable columns: %s",
      context_name, weight_var, paste(names(data_df), collapse = ", ")
    ))
  }

  # Extract weights
  weights <- data_df[[weight_var]]

  # Validate if requested
  if (validate) {
    validation <- validate_weights(weights, allow_na = FALSE)

    if (!validation$valid) {
      stop(sprintf("%s: Invalid weights found:\n  %s",
                   context_name, paste(validation$issues, collapse = "\n  ")))
    }
  }

  # Create standardized column
  data_df[[target_name]] <- weights

  return(data_df)
}
```

**Usage**:
```r
# Data has column "myweight"
df <- standardize_weight_variable(df, "myweight", target_name = "weight_var")

# Now df has "weight_var" column (standardized name)
# All modules can use "weight_var" consistently
```

---

## 10. API Reference

### Configuration Functions

#### `load_config_sheet(file_path, sheet_name = "Settings")`
**Source**: `lib/config_utils.R`
**Purpose**: Load Excel config sheet to named list
**Returns**: Named list of configuration values
**Errors**: Invalid file, missing sheet, duplicate settings

#### `get_config_value(config_list, setting_name, default_value = NULL, required = FALSE)`
**Source**: `lib/config_utils.R`
**Purpose**: Safely retrieve config value with default
**Returns**: Config value or default

#### `get_numeric_config(config_list, setting_name, default_value = NULL, min = -Inf, max = Inf, required = FALSE)`
**Source**: `lib/config_utils.R`
**Purpose**: Get numeric config with range validation
**Returns**: Numeric value

#### `get_logical_config(config_list, setting_name, default_value = FALSE)`
**Source**: `lib/config_utils.R`
**Purpose**: Get TRUE/FALSE config (handles Y/N, YES/NO, etc.)
**Returns**: Logical value

#### `get_char_config(config_list, setting_name, default_value = NULL, allowed_values = NULL, required = FALSE)`
**Source**: `lib/config_utils.R`
**Purpose**: Get character config with whitelist validation
**Returns**: Character value

#### `resolve_path(base_path, relative_path)`
**Source**: `lib/config_utils.R`
**Purpose**: Convert relative path to absolute
**Returns**: Normalized absolute path

### Data Functions

#### `load_survey_data(data_file_path, project_root = NULL, convert_labelled = FALSE)`
**Source**: `lib/data_utils.R`
**Purpose**: Load .xlsx, .xls, .csv, .sav files
**Returns**: Data frame
**Performance**: Auto-uses data.table for 10x CSV speedup

#### `safe_equal(a, b)`
**Source**: `lib/data_utils.R`
**Purpose**: Case-sensitive comparison with whitespace trim
**Returns**: Logical vector

#### `safe_numeric(x, na_value = NA_real_)`
**Source**: `lib/data_utils.R`
**Purpose**: Safe conversion to numeric (no warnings)
**Returns**: Numeric vector

#### `safe_logical(x, default = FALSE)`
**Source**: `lib/data_utils.R`
**Purpose**: Convert to logical (handles Y/N, YES/NO, T/F, 1/0)
**Returns**: Logical value

#### `calc_percentage(numerator, denominator, decimal_places = 0)`
**Source**: `lib/data_utils.R`
**Purpose**: Calculate percentage with 0/0 handling
**Returns**: Numeric percentage or NA_real_

### Validation Functions

#### `validate_data_frame(data, required_cols = NULL, min_rows = 1, max_rows = Inf, param_name = "data")`
**Source**: `lib/validation_utils.R`
**Purpose**: Validate data frame structure
**Returns**: Invisible TRUE or stops with error

#### `validate_numeric_param(value, param_name, min = -Inf, max = Inf, allow_na = FALSE)`
**Source**: `lib/validation_utils.R`
**Purpose**: Validate numeric parameter with range
**Returns**: Invisible TRUE or stops with error

#### `validate_logical_param(value, param_name)`
**Source**: `lib/validation_utils.R`
**Purpose**: Validate TRUE/FALSE parameter
**Returns**: Invisible TRUE or stops with error

#### `validate_char_param(value, param_name, allowed_values = NULL, allow_empty = FALSE)`
**Source**: `lib/validation_utils.R`
**Purpose**: Validate character parameter with whitelist
**Returns**: Invisible TRUE or stops with error

#### `validate_file_path(file_path, param_name = "file_path", must_exist = TRUE, required_extensions = NULL, validate_extension_even_if_missing = FALSE)`
**Source**: `lib/validation_utils.R`
**Purpose**: Validate file path existence and extension
**Returns**: Invisible TRUE or stops with error

#### `validate_column_exists(data, column_name, friendly_name = NULL)`
**Source**: `lib/validation_utils.R`
**Purpose**: Check column exists in data frame
**Returns**: Invisible TRUE or stops with error

#### `validate_weights(weights, data_rows, allow_zero = TRUE)`
**Source**: `lib/validation_utils.R`
**Purpose**: Validate weight vector against data
**Returns**: Invisible TRUE or stops with error

#### `has_data(df)`
**Source**: `lib/validation_utils.R`
**Purpose**: Quick check if data frame has rows
**Returns**: Logical

### Logging Functions

#### `log_message(msg, level = "INFO", verbose = TRUE)`
**Source**: `lib/logging_utils.R`
**Purpose**: Timestamped logging
**Returns**: Invisible NULL

#### `log_progress(current, total, item = "", start_time = NULL)`
**Source**: `lib/logging_utils.R`
**Purpose**: Progress bar with ETA
**Returns**: Invisible NULL

#### `create_error_log()`
**Source**: `lib/logging_utils.R`
**Purpose**: Initialize error tracking data frame
**Returns**: Empty error log data frame

#### `log_issue(error_log, component, issue_type, description, question_code = "", severity = "Warning")`
**Source**: `lib/logging_utils.R`
**Purpose**: Add issue to error log
**Returns**: Updated error log data frame

#### `print_toolkit_header(analysis_type = "Analysis", version = "1.0")`
**Source**: `lib/logging_utils.R`
**Purpose**: Display branding header
**Returns**: Nothing (prints to console)

### Formatting Functions

#### `create_excel_number_format(decimal_places = 1, decimal_separator = ".")`
**Source**: `formatting.R`
**Purpose**: Generate Excel numFmt code
**Returns**: Character, Excel format code

#### `create_excel_number_styles(decimal_separator = ".", decimal_places_percent = 0, decimal_places_ratings = 1, ...)`
**Source**: `formatting.R`
**Purpose**: Create openxlsx style objects
**Returns**: List of style objects

#### `format_number(x, decimal_places = 1, decimal_separator = ".")`
**Source**: `formatting.R`
**Purpose**: Format number as string
**Returns**: Character vector

#### `format_percentage(x, decimal_places = 0, decimal_separator = ".", include_percent_sign = FALSE)`
**Source**: `formatting.R`
**Purpose**: Format percentage value
**Returns**: Character vector

#### `format_index(x, decimal_places = 1, decimal_separator = ".")`
**Source**: `formatting.R`
**Purpose**: Format index/rating value
**Returns**: Character vector

### Weight Functions

#### `calculate_weight_efficiency(weights)`
**Source**: `weights.R`
**Purpose**: Calculate effective sample size (Kish formula)
**Returns**: Numeric, effective n

#### `calculate_design_effect(weights)`
**Source**: `weights.R`
**Purpose**: Calculate design effect
**Returns**: Numeric, deff

#### `validate_weights(weights, min_weight = 0, max_weight = Inf, allow_na = FALSE)`
**Source**: `weights.R`
**Purpose**: Comprehensive weight validation
**Returns**: List with validation results and issues

#### `get_weight_summary(weights)`
**Source**: `weights.R`
**Purpose**: Descriptive statistics for weights
**Returns**: Data frame with summary stats

#### `standardize_weight_variable(data_df, weight_var, target_name = "weight_var", validate = TRUE, context_name = "Data")`
**Source**: `weights.R`
**Purpose**: Create standardized weight column
**Returns**: Data frame with standardized weight column

---

## 11. Design Patterns

### 1. Fail Fast Pattern

**Problem**: Errors deep in processing logic are hard to debug.

**Solution**: Validate all inputs at function entry.

```r
analyze_data <- function(data, n_clusters, max_iter) {
  # Validate BEFORE processing
  validate_data_frame(data, required_cols = c("ID", "Response"), min_rows = 10)
  validate_numeric_param(n_clusters, "n_clusters", min = 2, max = 20)
  validate_numeric_param(max_iter, "max_iter", min = 1, max = 10000)

  # Now safe to process...
}
```

### 2. Safe Defaults Pattern

**Problem**: Missing config values cause errors.

**Solution**: Always provide sensible defaults.

```r
# BAD: No default, will error if missing
sig_level <- config$significance_level

# GOOD: Provides default
sig_level <- get_config_value(config, "significance_level", default = 0.95)

# BETTER: Type-safe with validation
sig_level <- get_numeric_config(config, "significance_level",
                                default = 0.95, min = 0, max = 1)
```

### 3. Defensive Type Conversion

**Problem**: `as.numeric("abc")` generates warning.

**Solution**: Use `safe_numeric()`, `safe_logical()`.

```r
# BAD: Generates warning
value <- as.numeric(user_input)

# GOOD: Silent conversion with default
value <- safe_numeric(user_input, na_value = 0)
```

### 4. Structured Error Messages

**Problem**: Generic error messages are not actionable.

**Solution**: Provide context, expected vs actual, troubleshooting steps.

```r
# BAD
stop("File not found")

# GOOD
stop(sprintf(
  "Data file not found\n  Path: %s\n  Directory exists: %s\n\nTroubleshooting:\n  1. Check spelling\n  2. Verify location\n  3. Check permissions",
  file_path, if (dir.exists(dirname(file_path))) "YES" else "NO"
))
```

### 5. Progressive Enhancement Pattern

**Problem**: Want optional performance boost without hard dependency.

**Solution**: Check for optional package, use if available, fallback otherwise.

```r
# CSV loading: data.table if available, base R otherwise
if (requireNamespace("data.table", quietly = TRUE)) {
  cat("Using data.table::fread() for faster loading...\n")
  data <- data.table::fread(file_path, data.table = FALSE)
} else {
  data <- read.csv(file_path, stringsAsFactors = FALSE)
}
```

### 6. Configuration Hierarchy Pattern

**Problem**: Need different config levels (required vs optional).

**Solution**: Use `required` parameter and defaults.

```r
# Required config - will stop if missing
data_file <- get_config_value(config, "data_file", required = TRUE)

# Optional config - uses default
decimal_places <- get_config_value(config, "decimal_places", default = 1)
```

---

## 12. Extension Points

### Adding New File Format Support

**Location**: `lib/data_utils.R` → `load_survey_data()`

```r
# 1. Add to supported formats constant
SUPPORTED_DATA_FORMATS <- c("xlsx", "xls", "csv", "sav", "parquet")  # NEW

# 2. Add to switch statement
survey_data <- switch(file_ext,
  "xlsx" = readxl::read_excel(data_file_path),
  "xls"  = readxl::read_excel(data_file_path),
  "csv"  = { ... },
  "sav"  = { ... },
  "parquet" = {  # NEW
    if (!requireNamespace("arrow", quietly = TRUE)) {
      stop(".parquet files require 'arrow' package\nInstall with: install.packages('arrow')")
    }
    arrow::read_parquet(data_file_path)
  }
)
```

### Adding New Validation Function

**Location**: `lib/validation_utils.R`

**Template**:
```r
#' Validate [What You're Validating]
#'
#' [Brief description of validation rules]
#'
#' @param value [Type], value to validate
#' @param param_name Character, parameter name for errors
#' @param [additional parameters]
#' @return Invisible TRUE if valid, stops with error if invalid
#' @export
validate_[thing] <- function(value, param_name, ...) {
  # 1. Type check
  if (!is.[type](value)) {
    stop(sprintf("%s must be [type], got: %s",
                 param_name, class(value)[1]))
  }

  # 2. Range/content checks
  if ([violation detected]) {
    stop(sprintf(
      "%s [violation description]\n  Expected: [expected]\n  Got: [actual]",
      param_name, ...
    ))
  }

  invisible(TRUE)
}
```

### Adding New Logging Level

**Location**: `lib/logging_utils.R` → `log_message()`

```r
# Add new level to function
log_message <- function(msg, level = "INFO", verbose = TRUE) {
  # Validate level
  allowed_levels <- c("INFO", "WARNING", "ERROR", "DEBUG", "TRACE")  # NEW
  if (!level %in% allowed_levels) {
    warning(sprintf("Unknown log level: %s, using INFO", level))
    level <- "INFO"
  }

  # Color coding (optional)
  color_code <- switch(level,
    "ERROR" = "\033[31m",    # Red
    "WARNING" = "\033[33m",  # Yellow
    "TRACE" = "\033[90m",    # Gray - NEW
    ""  # Default (no color)
  )

  if (!verbose) return(invisible(NULL))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("%s[%s] %s: %s\033[0m\n", color_code, timestamp, level, msg))
  invisible(NULL)
}
```

### Adding New Format Style

**Location**: `formatting.R` → `create_excel_number_styles()`

```r
create_excel_number_styles <- function(..., decimal_places_currency = 2) {  # NEW

  # Generate format code
  fmt_currency <- create_excel_number_format(decimal_places_currency)  # NEW

  styles <- list(
    percentage = ...,
    rating = ...,
    index = ...,
    numeric = ...,
    currency = openxlsx::createStyle(  # NEW
      fontSize = font_size, fontName = font_name,
      halign = "right", valign = "center",
      numFmt = paste0("$", fmt_currency)  # Add currency symbol
    )
  )

  return(styles)
}
```

### Adding New Weight Metric

**Location**: `weights.R`

```r
#' Calculate [New Metric Name]
#'
#' [Statistical description]
#'
#' FORMULA: [mathematical formula]
#'
#' INTERPRETATION:
#' - [interpretation guidance]
#'
#' @param weights Numeric vector of weight values
#' @return Numeric. [what it returns]
#'
#' @export
#' @examples
#' weights <- c(...)
#' calculate_[metric](weights)
calculate_[metric] <- function(weights) {
  # Remove NA and invalid weights
  weights <- weights[!is.na(weights) & weights > 0]

  if (length(weights) == 0) return(NA_real_)

  # Calculate metric
  result <- [calculation]

  return(result)
}
```

---

## Appendix A: Migration Guide

### Migrating from Monolithic `shared_functions.R`

**Old Pattern**:
```r
source("../shared/shared_functions.R")
```

**New Pattern** (modular):
```r
source("../shared/lib/config_utils.R")
source("../shared/lib/data_utils.R")
source("../shared/lib/validation_utils.R")
source("../shared/lib/logging_utils.R")
```

**Backward Compatibility**: Old pattern still works for existing modules. New modules should use modular approach.

---

## Appendix B: Performance Optimization

### CSV Loading Performance

| Method | Speed | When to Use |
|--------|-------|-------------|
| `read.csv()` | ~50 MB/sec | Default, always available |
| `data.table::fread()` | ~500 MB/sec | Auto-enabled if installed |

**Recommendation**: Install `data.table` package for 10x speedup on large CSV files.

```r
install.packages("data.table")
```

### Large File Handling

**Warning Threshold**: 500 MB

**Strategies for Large Files**:
1. Convert Excel to CSV (faster loading)
2. Use `data.table::fread()` for CSV
3. Split into chunks if >1 GB
4. Consider data.table or database backend for >5 GB

---

## Appendix C: Testing Strategy

### Unit Testing

**Recommended Package**: `testthat`

**Test Structure**:
```r
# tests/test_validation_utils.R
library(testthat)
source("../modules/shared/lib/validation_utils.R")

test_that("validate_numeric_param enforces range", {
  expect_silent(validate_numeric_param(5, "test", min = 0, max = 10))
  expect_error(validate_numeric_param(-1, "test", min = 0, max = 10))
  expect_error(validate_numeric_param(11, "test", min = 0, max = 10))
})

test_that("validate_data_frame detects missing columns", {
  df <- data.frame(a = 1:5, b = 6:10)
  expect_silent(validate_data_frame(df, required_cols = c("a", "b")))
  expect_error(validate_data_frame(df, required_cols = c("a", "c")))
})
```

### Integration Testing

**Test with Real Modules**:
1. Run tabs module with test config
2. Run tracker module with test config
3. Verify outputs match expected

---

## Appendix D: Troubleshooting

### Common Issues

**Issue**: "Package 'openxlsx' is required"
**Solution**: `install.packages("openxlsx")`

**Issue**: "Package 'haven' is required for .sav files"
**Solution**: `install.packages("haven")`

**Issue**: "File not found" errors
**Solution**: Use `resolve_path()` for relative paths, verify with `file.exists()`

**Issue**: Weight validation fails with "negative weights"
**Solution**: Check weight column in data, may have NA values coded as negative

**Issue**: Excel formatting shows "08" instead of "8.2"
**Solution**: Don't use comma in Excel format code, use `create_excel_number_format()`

---

## Document Version

**Version**: 1.0
**Date**: 2025-12-06
**Author**: Turas Development Team
**Status**: Final
