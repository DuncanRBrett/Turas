# TURAS Codebase Structure & Patterns - Comprehensive Analysis

**Analysis Date:** 2025-11-18  
**Codebase:** Turas Analytics Platform (R-based)  
**Scope:** Repository structure, module patterns, documentation standards, configuration approaches  

---

## 1. OVERALL DIRECTORY STRUCTURE

```
/home/user/Turas/
├── modules/                           # Core analysis modules
│   ├── parser/                        # Survey questionnaire parsing
│   ├── tabs/                          # Crosstabulation analysis
│   ├── tracker/                       # Multi-wave tracking
│   ├── confidence/                    # Confidence interval analysis
│   ├── segment/                       # K-means clustering
│   ├── conjoint/                      # Conjoint analysis (NEW PATTERN)
│   ├── keydriver/                     # Key driver analysis (NEW PATTERN)
│   └── shared/                        # Shared utilities across modules
│       └── lib/                       # Shared library functions
│
├── shared/                            # DEPRECATED - legacy shared utilities
├── templates/                         # Configuration templates (Excel)
├── docs/                              # Centralized documentation
├── tests/                             # Test suite (testthat)
│   ├── testthat/                      # Unit tests
│   └── testthat.R                     # Test runner
│
├── launch_turas.R                     # Main Shiny GUI launcher
├── README.md                          # Project overview
├── ARCHITECTURE.md                    # System architecture documentation
└── SETUP_AND_TEMPLATES_GUIDE.md       # Setup instructions
```

### Key Statistics:
- **Modules:** 7 active (Parser, Tabs, Tracker, Confidence, Segment, Conjoint, Key Driver)
- **Shared utilities:** Located in `/modules/shared/lib/`
- **Documentation style:** Markdown + Excel templates
- **Templates:** 7+ Excel configuration templates for each module

---

## 2. MODULE ORGANIZATION PATTERNS

### 2.1 Modern Module Structure (Conjoint, Key Driver - RECOMMENDED PATTERN)

**Directory Layout:**
```
modules/conjoint/
├── R/                                 # All source code in R/ subdirectory
│   ├── 00_main.R                      # Main entry point (orchestrator)
│   ├── 01_config.R                    # Configuration loading
│   ├── 02_validation.R                # Data validation & loading
│   ├── 03_analysis.R                  # Core analysis logic
│   ├── 04_output.R                    # Output generation (Excel)
│   └── [other files as needed]
│
├── run_conjoint_gui.R                 # Shiny GUI launcher
├── README.md                          # Module overview
└── [documentation files]
```

**File Naming Convention:**
- Numbered files: `00_main.R`, `01_config.R`, `02_validation.R`, `03_analysis.R`, `04_output.R`
- Execution order: Follows numbering (00 → 01 → 02 → 03 → 04)
- GUI launcher: `run_[module]_gui.R`
- Main function: `run_[module]_analysis()`
- Alias function: `[module]()`

### 2.2 Older Module Structure (Tabs, Segment)

**Directory Layout:**
```
modules/tabs/
├── lib/                               # Library functions
│   ├── config_loader.R
│   ├── validation.R
│   ├── excel_writer.R
│   └── [component1-responsibility].R
│
├── run_tabs.R                         # Entry point
├── run_tabs_gui.R                     # GUI launcher
├── QUICK_START.md
├── USER_MANUAL.md
├── TECHNICAL_DOCUMENTATION.md
├── EXAMPLE_WORKFLOWS.md
└── README.md
```

**File Naming Convention:**
- Descriptive names: `config_loader.R`, `validation.R`, `excel_writer.R`
- Single responsibility per file
- No GUI launcher in some older modules

### 2.3 Evolution of Patterns

The codebase is evolving toward the **numbered file pattern** (00_main.R → 04_output.R):
- **Newer modules** (Conjoint, Key Driver): Use numbered pattern
- **Confidence module**: Also uses numbered pattern (R/ subdirectory)
- **Older modules** (Tabs, Segment): Use descriptive names in lib/

**RECOMMENDATION FOR PRICING MODULE:** Follow the newer pattern (numbered files in R/ subdirectory)

---

## 3. CONSISTENT MODULE PATTERNS

### 3.1 Main Entry Point Pattern (00_main.R)

**Structure:**
```r
#' Run [Module] Analysis
#'
#' Main entry point. Calls orchestrator functions in sequence.
#'
#' @param config_file Path to configuration Excel file
#' @param data_file Path to data file (CSV, XLSX, SAV, DTA)
#' @param output_file Path for output Excel file
#' @return List containing results, config, etc.
#'
#' @examples
#' \dontrun{
#'   results <- run_[module]_analysis("config.xlsx")
#' }
#'
#' @export
run_[module]_analysis <- function(config_file, data_file = NULL, output_file = NULL) {

  # Print header with formatting
  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("TURAS [MODULE NAME]\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # STEP 1: Load Configuration
  cat("1. Loading configuration...\n")
  config <- load_[module]_config(config_file)
  cat(sprintf("   ✓ [Success message]\n"))

  # STEP 2: Load and Validate Data
  cat("\n2. Loading and validating data...\n")
  data <- load_[module]_data(data_file, config)
  cat(sprintf("   ✓ [Success message]\n"))

  # STEP 3: Core Analysis
  cat("\n3. Running analysis...\n")
  results <- calculate_[module](data, config)
  cat("   ✓ [Success message]\n")

  # STEP 4: Generate Output
  cat("\n4. Generating output file...\n")
  write_[module]_output(results, config, output_file)
  cat(sprintf("   ✓ Results written to: %s\n", output_file))

  # Print footer
  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("ANALYSIS COMPLETE\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Return results invisibly
  invisible(list(results = results, config = config))
}

# Alias for convenience
[module] <- run_[module]_analysis
```

**Key Characteristics:**
- Prints formatted header/footer with 80-char lines
- Uses `cat()` with `sprintf()` for progress messages
- Checkmarks (✓) for visual feedback
- Sequential numbered steps (1, 2, 3, 4, etc.)
- Returns results invisibly
- Roxygen-documented with `@export`
- Provides convenience alias

### 3.2 Configuration Loading Pattern (01_config.R)

**Structure:**
```r
#' Load [Module] Configuration
#'
#' Loads and validates configuration from Excel file.
#'
#' @param config_file Path to configuration Excel file
#' @param project_root Optional project root (defaults to config directory)
#' @return List with validated configuration
#' @keywords internal
load_[module]_config <- function(config_file, project_root = NULL) {

  # Validate file exists
  if (!file.exists(config_file)) {
    stop("Configuration file not found: ", config_file, call. = FALSE)
  }

  # Set project root
  if (is.null(project_root)) {
    project_root <- dirname(config_file)
  }

  # Load settings sheet
  settings <- openxlsx::read.xlsx(config_file, sheet = "Settings")
  settings_list <- setNames(as.list(settings$Value), settings$Setting)

  # Extract and resolve file paths
  data_file <- settings_list$data_file
  output_file <- settings_list$output_file

  # Resolve relative paths to absolute
  if (!is.null(data_file) && !is.na(data_file)) {
    if (!grepl("^(/|[A-Za-z]:)", data_file)) {
      data_file <- file.path(project_root, data_file)
    }
    data_file <- normalizePath(data_file, winslash = "/", mustWork = FALSE)
  }

  # [Similar for output_file]

  # Load other required sheets
  [required_sheet] <- openxlsx::read.xlsx(config_file, sheet = "[SheetName]")

  # Validate required columns
  required_cols <- c("Col1", "Col2", "Col3")
  missing_cols <- setdiff(required_cols, names([required_sheet]))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }

  # Return as list
  list(
    settings = settings_list,
    [required_sheet_name] = [required_sheet],
    data_file = data_file,
    output_file = output_file,
    project_root = project_root
  )
}
```

**Key Characteristics:**
- Uses `openxlsx` for Excel I/O
- Validates file existence first
- Uses Settings sheet with two columns: "Setting" and "Value"
- Resolves relative paths to absolute using project root
- Validates required columns after loading sheets
- Uses `@keywords internal` for helper functions
- Clear error messages with `stop()` and `call. = FALSE`

### 3.3 Data Validation & Loading Pattern (02_validation.R)

**Structure:**
```r
#' Load [Module] Data
#'
#' Loads and validates data file.
#'
#' @param data_file Path to data file (CSV, XLSX, SAV, DTA)
#' @param config Configuration list
#' @return List with validated data and metadata
#' @keywords internal
load_[module]_data <- function(data_file, config) {

  # Validate file exists
  if (!file.exists(data_file)) {
    stop("Data file not found: ", data_file, call. = FALSE)
  }

  # Detect file type and load appropriately
  file_ext <- tolower(tools::file_ext(data_file))

  data <- switch(file_ext,
    "csv" = utils::read.csv(data_file, stringsAsFactors = FALSE),
    "xlsx" = openxlsx::read.xlsx(data_file),
    "xls" = openxlsx::read.xlsx(data_file),
    "sav" = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' required for SPSS files", call. = FALSE)
      }
      haven::read_sav(data_file)
    },
    "dta" = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' required for Stata files", call. = FALSE)
      }
      haven::read_dta(data_file)
    },
    stop("Unsupported file format: ", file_ext, call. = FALSE)
  )

  # Convert to data frame
  data <- as.data.frame(data)

  # Validate required columns exist
  required_cols <- [get from config]
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing columns: ", paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }

  # Validate data quality
  if (nrow(data) == 0) {
    stop("Data file is empty", call. = FALSE)
  }

  # Check for missing data and filter if needed
  complete_cases <- complete.cases(data)
  n_missing <- nrow(data) - sum(complete_cases)

  if (n_missing > 0) {
    warning(sprintf("%d rows with missing data will be excluded", n_missing))
  }

  if (sum(complete_cases) < 30) {
    stop("Insufficient complete cases. Need at least 30.", call. = FALSE)
  }

  # Return validation results
  list(
    data = data[complete_cases, ],
    n_respondents = nrow(data),
    n_complete = sum(complete_cases),
    n_missing = n_missing
  )
}
```

**Key Characteristics:**
- Uses `tools::file_ext()` for file type detection
- Uses `switch()` for file type routing
- Gracefully handles optional packages (`haven`)
- Validates data quality and completeness
- Returns list with data and metadata
- Uses `@keywords internal` for non-exported functions

### 3.4 Analysis Function Pattern (03_analysis.R)

**Structure:**
```r
#' Calculate [Module] Analysis
#'
#' Core analysis logic.
#'
#' @param data Data list from load_[module]_data()
#' @param config Configuration list
#' @return List with results and fit statistics
#' @keywords internal
calculate_[module] <- function(data, config) {

  df <- data$data

  # Extract configuration parameters
  [param1] <- config$settings$[param1] %||% [default]
  [param2] <- config$settings$[param2] %||% [default]

  # Validate configuration for this analysis
  if (is.null([param1])) {
    stop("Parameter [param1] must be specified", call. = FALSE)
  }

  # Main analysis logic here
  # ...

  # Return results
  list(
    [results] = [results_df],
    [fit] = [fit_metrics],
    [other] = [other_outputs]
  )
}
```

**Key Characteristics:**
- Uses `%||%` operator for default values
- Validates configuration parameters
- Returns list with named components
- Uses `@keywords internal` for non-exported functions

### 3.5 Output Generation Pattern (04_output.R)

**Structure:**
```r
#' Write [Module] Results to Excel
#'
#' Creates formatted Excel workbook with results.
#'
#' @param [components] Analysis results
#' @param config Configuration
#' @param output_file Output file path
#' @keywords internal
write_[module]_output <- function([results], config, output_file) {

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Define styles (reusable)
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    fontColour = "#FFFFFF",
    fgFill = "#4472C4",
    halign = "left",
    valign = "center",
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )

  # Sheet 1: Main Results
  openxlsx::addWorksheet(wb, "Results")
  openxlsx::writeData(wb, "Results", [results_df], startRow = 1)
  openxlsx::addStyle(wb, "Results", header_style, rows = 1,
                     cols = 1:ncol([results_df]), gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Results", cols = 1:ncol([results_df]), widths = "auto")

  # Sheet 2: Model Fit
  openxlsx::addWorksheet(wb, "Model Fit")
  fit_df <- data.frame(
    Metric = names([fit]),
    Value = unlist([fit]),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Model Fit", fit_df, startRow = 1)
  openxlsx::addStyle(wb, "Model Fit", header_style, rows = 1,
                     cols = 1:2, gridExpand = TRUE)

  # Sheet 3: Configuration Summary
  openxlsx::addWorksheet(wb, "Configuration")
  # Write config summary

  # Save workbook
  openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
}
```

**Key Characteristics:**
- Uses `openxlsx` for Excel creation
- Defines reusable styles (not inline)
- Multiple sheets for different outputs
- Uses `addWorksheet()`, `writeData()`, `addStyle()`, `setColWidths()`
- Always uses `overwrite = TRUE`
- Consistent formatting across all sheets

---

## 4. DOCUMENTATION PATTERNS

### 4.1 Module Documentation Structure

Each module includes these documentation files:

```
modules/[module]/
├── README.md                          # Module overview (150-200 lines)
├── QUICK_START.md                     # 10-15 min getting started (250-300 lines)
├── USER_MANUAL.md                     # Comprehensive user guide (500+ lines)
├── TECHNICAL_DOCUMENTATION.md         # Developer reference (1000+ lines)
└── EXAMPLE_WORKFLOWS.md               # Real-world examples (300+ lines)
```

### 4.2 README.md Format

**Structure:**
```markdown
# Turas [Module] Module

## Overview
- What the module does (2-3 sentences)
- Key features (bullet list)

## Quick Start
- Code example showing basic usage (5 lines)
- Expected output format

## Configuration File Format
- Excel sheet structure
- Required columns
- Example data

## Data File Format
- CSV/Excel structure
- One row = ? (respondent/profile/etc)
- Required columns

## Methodology
- Algorithm explanation
- Statistical formulas
- Key assumptions

## Output
- Sheet names and contents
- Interpretation guidelines
- Example output

## Implementation Status
- Completed features (✅)
- Planned features (❌)

## Dependencies
- R packages
- Optional packages

## References
- Academic citations
```

**Examples in codebase:**
- `/home/user/Turas/modules/conjoint/README.md` (196 lines)
- `/home/user/Turas/modules/keydriver/README.md` (174 lines)
- `/home/user/Turas/modules/segment/README.md` (247 lines)

### 4.3 QUICK_START.md Format

**Structure:**
```markdown
# [Module] - Quick Start Guide

**Version:** 1.0
**Estimated Time:** 10-15 minutes
**Difficulty:** Beginner to Intermediate

## What is [Module]?
- Brief explanation
- Key capabilities

## Prerequisites
- Required R packages
- Required data files

## Quick Start (10 Minutes)
### Step 1: Prepare Your Data
- Data format requirements
- Example structure

### Step 2: Create Configuration File
- Sheet names
- Required columns
- Example data

### Step 3: Run Analysis
- GUI approach
- R script approach

### Step 4: Review Output
- What sheets contain
- How to interpret results

## Common Configurations
- Scenario 1: ...
- Scenario 2: ...

## Troubleshooting
- ❌ "Error message"
- **Fix:** Solution

## Next Steps
- What to do after basic analysis
- Advanced features
- Where to learn more

## Quick Reference
- Minimum required files
- Minimum required settings
- Typical analysis time

---

*Version 1.0.0 | Quick Start Guide | Turas [Module] Module*
```

**Example:**
- `/home/user/Turas/modules/tabs/QUICK_START.md` (299 lines)

### 4.4 Configuration Template Files

**Location:** `/home/user/Turas/templates/`

**Format:**
- Excel workbooks (.xlsx)
- Pre-populated with examples
- Color-coded headers (blue)
- Auto-sized columns
- Include instructions

**Examples:**
```
Tabs_Config_Template.xlsx
Tabs_Survey_Structure_Template.xlsx
Confidence_Config_Template.xlsx
Segment_Config_Template.xlsx
Tracker_Config_Template.xlsx
Tracker_Question_Mapping_Template.xlsx
```

---

## 5. CONFIGURATION APPROACH

### 5.1 Excel Configuration Standard

**Universal Pattern (all modules):**

**Sheet 1: Settings**
```
SettingName    | SettingValue
data_file      | survey_data.xlsx
output_file    | results.xlsx
[param1]       | value1
[param2]       | value2
```

**Key Conventions:**
- Two columns: "Setting" (left) and "Value" (right)
- One setting per row
- Variable names in CamelCase: `data_file`, `output_file`, `min_sample_size`
- Blank values = use default
- Relative paths supported (resolved from config file directory)
- Boolean values: `TRUE`/`FALSE` (all caps)

### 5.2 Module-Specific Configuration Sheets

**Conjoint Example:**
```
Sheet 1: Settings
- analysis_type (rating/choice)
- rating_variable
- respondent_id_column
- profile_id_column

Sheet 2: Attributes
- AttributeName
- NumLevels
- LevelNames (comma-separated)

Sheet 3: Design (optional)
```

**Key Driver Example:**
```
Sheet 1: Settings
- analysis_name
- min_sample_size

Sheet 2: Variables
- VariableName
- Type (Outcome/Driver)
- Label
```

**Pattern:**
- Settings sheet always present
- Additional sheets for domain-specific config
- Consistent column naming across modules
- Required columns validated in load_*_config()

### 5.3 Path Resolution Logic

**Pattern from code:**
```r
# In load_*_config():
if (!is.null(data_file) && !is.na(data_file)) {
  if (!grepl("^(/|[A-Za-z]:)", data_file)) {
    # Relative path - resolve from project root
    data_file <- file.path(project_root, data_file)
  }
  data_file <- normalizePath(data_file, winslash = "/", mustWork = FALSE)
}
```

**Behavior:**
- Relative paths: Resolved relative to config file directory
- Absolute paths: Used as-is
- Windows paths: Use forward slashes (/)
- No validation that file exists (`mustWork = FALSE`)

---

## 6. COMMON UTILITIES AND SHARED CODE

### 6.1 Shared Library Location

**Primary Location:** `/home/user/Turas/modules/shared/lib/`

**Files:**
```
config_utils.R          # Excel config loading (generic functions)
data_utils.R            # Data loading and type conversion
logging_utils.R         # Logging, progress tracking, error tracking
validation_utils.R      # Input validation functions
```

### 6.2 Key Shared Functions

**Configuration (config_utils.R):**
- `read_config_sheet(config_path, sheet_name)` - Load Excel sheet with validation
- `get_config_value(config, name, default, required)` - Safely retrieve config value

**Data (data_utils.R):**
- `load_survey_data(file_path)` - Load .xlsx, .xls, .csv, .sav files
- `safe_numeric(x)` - Safe type conversion
- `calc_percentage(num, denom, decimals)` - Percentage with 0/0 handling

**Validation (validation_utils.R):**
- `validate_data_frame(df, required_cols, min_rows)` - Validate structure
- `validate_numeric_param(value, name, min, max)` - Numeric validation
- `validate_file_path(path, must_exist, extensions)` - File validation
- `has_data(df)` - Quick check if non-empty

**Logging (logging_utils.R):**
- `log_message(msg, level, verbose)` - Timestamped logging
- `log_progress(current, total, item, start_time)` - Progress with ETA
- `create_error_log()`, `log_issue()` - Structured error tracking
- `print_toolkit_header(analysis_type, version)` - Branding header

### 6.3 Legacy Shared Utilities

**Location:** `/home/user/Turas/shared/` (DEPRECATED)

**Files:**
- `config_utils.R` - Old config loading (duplicate)
- `formatting.R` - Excel/output formatting
- `weights.R` - Weighting calculations

**Status:** Being migrated to `/modules/shared/lib/`

---

## 7. ERROR HANDLING PATTERNS

### 7.1 Error Function Usage

**Pattern:**
```r
# File existence check
if (!file.exists(file_path)) {
  stop("File not found: ", file_path, call. = FALSE)
}

# Missing columns check
missing_cols <- setdiff(required, actual)
if (length(missing_cols) > 0) {
  stop("Missing columns: ", paste(missing_cols, collapse = ", "),
       call. = FALSE)
}

# Parameter validation
if (is.null(param) || is.na(param)) {
  stop("Parameter 'param' cannot be null or NA", call. = FALSE)
}

# Insufficient data
if (nrow(data) < min_size) {
  stop(sprintf("Insufficient data: need %d rows, have %d", min_size, nrow(data)),
       call. = FALSE)
}
```

**Conventions:**
- Always use `call. = FALSE` to avoid function call in error message
- Use `sprintf()` for formatted messages
- Clear, actionable error messages
- Validation happens early (fail fast)

### 7.2 Warning Function Usage

**Pattern:**
```r
if (n_missing > 0) {
  warning(sprintf("%d rows with missing data will be excluded (%.1f%%)",
                  n_missing, 100 * n_missing / nrow(data)))
}
```

**Conventions:**
- Use when error is not fatal
- Analysis can proceed but results may be affected
- Provide percentage/count information where relevant

### 7.3 Default Value Pattern

**Pattern:**
```r
# Using %||% operator (null coalescing)
param <- config$param %||% default_value

# Using ifelse
param <- if (!is.null(x)) x else default
```

**Conventions:**
- Provide sensible defaults where possible
- Document defaults in function documentation

---

## 8. LOGGING AND PROGRESS PATTERNS

### 8.1 Progress Reporting (cat with sprintf)

**Pattern from 00_main.R files:**
```r
cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("TURAS [MODULE NAME]\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")

cat("1. Loading configuration...\n")
config <- load_config(config_file)
cat(sprintf("   ✓ Loaded %d items\n", nrow(config$items)))

cat("\n2. Loading data...\n")
data <- load_data(data_file)
cat(sprintf("   ✓ Loaded %d respondents\n", nrow(data)))

# ... more steps ...

cat("\n")
cat(rep("=", 80), "\n", sep = "")
cat("ANALYSIS COMPLETE\n")
cat(rep("=", 80), "\n", sep = "")
cat("\n")
```

**Conventions:**
- Header/footer with 80-character lines of equals signs
- Numbered steps with colons ("1. ", "2. ")
- Checkmarks (✓) for successful operations
- Use `sprintf()` for formatted output
- Indented success messages with 3 spaces
- Blank lines for visual separation

### 8.2 No Logging Dependency

**Pattern:**
```r
# NO logging packages used (like log4r, futile.logger)
# Uses only base R cat() and sprintf()
# Simpler, lighter, no dependencies
```

**Rationale:**
- Modules don't use logging packages
- Simple `cat()` and `sprintf()` suffice
- Keeps dependencies minimal
- Output goes to console only (not to files)

---

## 9. MODULE INTEGRATION WITH LAUNCHER

### 9.1 Main Launcher File

**Location:** `/home/user/Turas/launch_turas.R`

**Purpose:** Shiny GUI with buttons to launch each module

**Integration Pattern:**
```r
# Parser
actionButton("launch_parser", "Launch Parser",
            class = "launch-btn btn-parser")

# Tabs
actionButton("launch_tabs", "Launch Tabs",
            class = "launch-btn btn-tabs")

# ... other modules ...

# Conjoint
actionButton("launch_conjoint", "Launch Conjoint",
            class = "launch-btn btn-conjoint")

# Key Driver
actionButton("launch_keydriver", "Launch Key Driver",
            class = "launch-btn btn-keydriver")
```

**Server Logic:**
```r
observeEvent(input$launch_conjoint, {
  showModal(modalDialog(
    title = "Launching Conjoint",
    "Closing launcher and starting Conjoint...",
    footer = NULL
  ))
  Sys.sleep(0.5)
  stopApp(returnValue = "conjoint")
})
```

### 9.2 Module GUI Pattern (run_*_gui.R)

**File:** `modules/[module]/run_[module]_gui.R`

**Responsibilities:**
- File/folder browser dialogs
- Configuration file selection
- Recent projects tracking
- Config file detection
- Progress reporting
- Output file opening

**Key Features:**
- Stores recent projects in `.recent_[module]_projects.rds`
- Detects config files by pattern matching
- Shows step-by-step workflow
- Professional UI with CSS styling

---

## 10. FILE NAMING CONVENTIONS

### 10.1 Module File Naming

**Recommended Pattern (NEW):**
```
00_main.R              # Entry point (always 00)
01_config.R            # Configuration loading (always 01)
02_validation.R        # Data validation (always 02)
03_analysis.R          # Core analysis (always 03)
04_output.R            # Output generation (always 04)
05_*.R                 # Additional functionality (if needed)
```

**Module Entry Points:**
```
run_[module].R         # Command-line entry point (if exists)
run_[module]_gui.R     # Shiny GUI entry point
```

**Module Documentation:**
```
README.md              # Module overview
QUICK_START.md         # 10-minute getting started
USER_MANUAL.md         # Comprehensive guide
TECHNICAL_DOCUMENTATION.md  # Developer reference
EXAMPLE_WORKFLOWS.md   # Real-world examples
```

### 10.2 Configuration File Naming

**Pattern:**
```
[ModuleName]_Config.xlsx              # Main config
[ModuleName]_Config_Template.xlsx     # Template copy
[ModuleName]_Survey_Structure.xlsx    # Question metadata (Tabs)
```

**Examples:**
```
Tabs_Config.xlsx
Tabs_Config_Template.xlsx
Tabs_Survey_Structure.xlsx
Tracker_Config.xlsx
Conjoint_Config.xlsx
KeyDriver_Config.xlsx
Segment_Config.xlsx
Confidence_Config.xlsx
```

### 10.3 Output File Naming

**Pattern:**
```
[ModuleName]_results.xlsx
[ModuleName]_output.xlsx
conjoint_results.xlsx
keydriver_results.xlsx
```

---

## 11. TESTING PATTERNS

### 11.1 Test Location

**Location:** `/home/user/Turas/tests/testthat/`

**Files:**
```
test_weights_baseline.R      # Shared functionality
test_shared_weights.R
test_shared_formatting.R
test_shared_functions.R
test_shared_config.R
test_formatting_baseline.R
test_config_baseline.R
```

### 11.2 Golden Master Pattern

**Concept:**
- Run analysis once on known dataset
- Save output as "golden master"
- Future runs compared against golden master
- Ensures regressions are caught

**Examples:**
- Baseline test datasets
- Known good outputs
- Regression testing

---

## 12. PATTERNS TO FOLLOW FOR PRICING MODULE

### 12.1 Recommended Structure

```
modules/pricing/
├── R/
│   ├── 00_main.R                  # Entry point: run_pricing_analysis()
│   ├── 01_config.R                # load_pricing_config()
│   ├── 02_validation.R            # load_pricing_data()
│   ├── 03_analysis.R              # calculate_pricing_[method]()
│   ├── 04_output.R                # write_pricing_output()
│   └── utils.R                    # Helper functions (if needed)
│
├── run_pricing_gui.R              # Shiny GUI launcher
├── README.md                      # Module overview
├── QUICK_START.md                 # 10-min guide
├── USER_MANUAL.md                 # Comprehensive guide
├── TECHNICAL_DOCUMENTATION.md     # Developer reference
└── EXAMPLE_WORKFLOWS.md           # Real examples
```

### 12.2 Configuration Template

**File:** `templates/Pricing_Config_Template.xlsx`

**Sheets:**
```
1. Settings (all modules have this)
   - analysis_type: (van_westendorp | gabor_granger)
   - data_file: [path to data]
   - output_file: [path to output]
   - method_params: [method-specific parameters]

2. Questions (pricing-specific)
   - QuestionCode
   - QuestionText
   - PriceRange (low-high)
   - QuestionType (toomcheap/tooacexpensive/idealprice/etc)

3. Settings_VanWestendorp (method-specific)
   - [Van Westendorp parameters]

4. Settings_GaborGranger (method-specific)
   - [Gabor-Granger parameters]
```

### 12.3 Entry Function Signature

```r
#' Run Pricing Analysis
#'
#' @param config_file Path to pricing configuration Excel file
#' @param data_file Path to survey data (CSV, XLSX, SAV, DTA)
#' @param output_file Path for results Excel file
#' @return List with pricing analysis results, config, and diagnostics
#' @export
run_pricing_analysis <- function(config_file, data_file = NULL, output_file = NULL) {
  # Implementation follows standard pattern
}

# Convenience alias
pricing <- run_pricing_analysis
```

### 12.4 Output Format

**Excel Workbook Sheets:**
```
1. Summary
   - Analysis type and parameters
   - Sample size and data quality
   - Key findings

2. [Method]-Specific Results
   - Optimal price point
   - Price ladder results
   - Revenue projections

3. Charts
   - Price sensitivity curves
   - Revenue optimizations
   - Comparison charts

4. Data Quality
   - Data validation results
   - Missing data summary
   - Outlier detection

5. Configuration
   - Settings used
   - Question structure
   - Parameter values
```

---

## 13. CODE QUALITY STANDARDS (FROM README.md)

**From Turas README.md:**

- Consistent style (use `styler::style_file()`)
- Roxygen docs for every exported function
- Functions < 100 lines where feasible
- Single-responsibility per file
- No hardcoded paths; config-driven
- Clear error messages; no silent failures
- Logging with levels: INFO, WARN, ERROR
- Pre-commit: run tests, style checks, regression tests
- CI: all checks green before merge
- Pre-release: version bump, CHANGELOG update, config template validation

---

## 14. SUMMARY OF KEY PATTERNS

### Module Creation Checklist:

- [x] Create `modules/[module]/R/` directory
- [x] Create `00_main.R` with formatted header/footer
- [x] Create `01_config.R` for Excel config loading
- [x] Create `02_validation.R` for data loading
- [x] Create `03_analysis.R` for core logic
- [x] Create `04_output.R` for Excel generation
- [x] Create `run_[module]_gui.R` for Shiny GUI
- [x] Create `README.md` (overview)
- [x] Create `QUICK_START.md` (10-min guide)
- [x] Create `USER_MANUAL.md` (comprehensive)
- [x] Create `TECHNICAL_DOCUMENTATION.md` (developer)
- [x] Create `EXAMPLE_WORKFLOWS.md` (examples)
- [x] Create Excel template in `templates/`
- [x] Add button to `launch_turas.R`
- [x] Follow error handling patterns
- [x] Use formatted progress output
- [x] Return results invisibly
- [x] Validate inputs early
- [x] Document with Roxygen
- [x] Test with testthat

---

## 15. IMPORTANT CONVENTIONS

**Always:**
- Use `call. = FALSE` in `stop()` errors
- Use `sprintf()` for formatted messages
- Return results invisibly with `invisible()`
- Provide `@examples` in documentation
- Use `@keywords internal` for helper functions
- Use `@export` for public functions
- Start with header/footer in main function
- Use checkmarks (✓) for progress
- Number steps in progress (1, 2, 3...)
- Indent progress messages with 3 spaces
- Set `overwrite = TRUE` in `saveWorkbook()`

**Never:**
- Hardcode file paths
- Use `library()` inside functions
- Skip validation
- Ignore missing data silently
- Change working directory without restoring
- Use `attach()` or `with()`
- Return visible NULL
- Use package-specific logging

---

**Analysis completed:** 2025-11-18  
**Codebase comprehensiveness:** COMPLETE  
**Pattern consistency:** HIGH  
**Documentation quality:** COMPREHENSIVE  

