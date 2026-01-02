# TURAS Troubleshooting Guide

## Critical Issues & Solutions

This document explains common issues in TURAS development and how to prevent/fix them.

---

## 1. PATH RESOLUTION ISSUES

### Problem
Modules fail to find shared code or data files with errors like:
```
Error: cannot open the connection
Error in file(filename, "r", encoding = encoding) : cannot open file
```

### Root Cause
R's `sys.frame(1)$ofile` path detection is fragile and fails when:
- Running from Shiny GUI
- Sourcing files from different working directories
- Running tests with testthat

### Solution: Use Robust Path Finding

**All modules now use `find_turas_root()` function** with caching and multiple detection methods:

```r
find_turas_root <- function() {
  # Check cached value first
  if (exists("TURAS_ROOT", envir = .GlobalEnv)) {
    cached <- get("TURAS_ROOT", envir = .GlobalEnv)
    if (!is.null(cached) && nzchar(cached)) {
      return(cached)
    }
  }

  # Search up directory tree for Turas root markers
  current_dir <- getwd()
  while (current_dir != dirname(current_dir)) {
    has_launch <- isTRUE(file.exists(file.path(current_dir, "launch_turas.R")))
    has_turas_r <- isTRUE(file.exists(file.path(current_dir, "turas.R")))
    has_modules_shared <- isTRUE(dir.exists(file.path(current_dir, "modules", "shared")))

    if (has_launch || has_turas_r || has_modules_shared) {
      assign("TURAS_ROOT", current_dir, envir = .GlobalEnv)
      return(current_dir)
    }
    current_dir <- dirname(current_dir)
  }

  stop("Cannot locate Turas root directory.")
}
```

### Best Practices

**DO:**
- ✅ Always use `find_turas_root()` at the start of module files
- ✅ Source shared modules from consolidated location: `source(file.path(turas_root, "modules", "shared", "lib", "formatting_utils.R"))`
- ✅ Use `file.path()` for all path construction (never paste paths with `/` or `\\`)
- ✅ Test modules from different working directories

**DON'T:**
- ❌ Use `sys.frame(1)$ofile` alone
- ❌ Use hardcoded absolute paths
- ❌ Assume current working directory is always the module directory
- ❌ Use paste() or paste0() to build file paths

### Shared Utilities Location
All shared utilities are consolidated in `/modules/shared/lib/`:
- `config_utils.R` - Path resolution and configuration
- `formatting_utils.R` - Number and output formatting
- `weights_utils.R` - Weight calculations
- `validation_utils.R` - Input validation

### Files Using Robust Path Resolution
- `modules/tabs/lib/excel_writer.R`
- `modules/tracker/formatting_utils.R`
- `modules/tracker/tracker_output.R`
- `modules/keydriver/R/00_main.R`
- `modules/conjoint/R/99_helpers.R`
- `modules/maxdiff/R/utils.R`

---

## 2. DECIMAL SEPARATOR & EXCEL FORMATTING ISSUES

### Problem
Numbers display incorrectly in Excel output:
- `8.2` displays as `"08"`
- Numbers show as Custom format instead of Number format
- Decimal separator setting is ignored

### Root Cause: Excel Format Code Syntax

**CRITICAL:** In Excel number format codes, the symbols have FIXED meanings:
- `.` (period) = **ALWAYS means decimal point**
- `,` (comma) = **ALWAYS means thousands separator OR divide by 1000**

**You CANNOT change what these symbols mean through format codes!**

### What Was Wrong

We tried to use European format `# ##0,0` thinking:
- Space would be thousands separator
- Comma would be decimal separator

**But Excel interpreted it as:**
- `# ##0` = number with thousands separator
- `,0` = **divide by 1000**
- Result: `8.2 ÷ 1000 = 0.0082` → displayed as `"08"`

### The Correct Solution

**ALWAYS use period in Excel format codes:**
```r
create_excel_number_format <- function(decimal_places = 1, decimal_separator = ".") {
  if (decimal_places == 0) {
    return("0")
  }

  # ALWAYS use . in format code
  zeros <- paste(rep("0", decimal_places), collapse = "")
  format_code <- paste0("0", ".", zeros)  # e.g., "0.0"

  return(format_code)
}
```

**Excel will automatically display numbers based on the user's system locale:**
- Mac set to European locale: `8.2` → displays as `8,2`
- Mac set to US locale: `8.2` → displays as `8.2`

### How Decimal Separator Config Works

The `decimal_separator` setting in config files has **TWO different uses:**

1. **For TEXT formatting** (converting numbers to strings):
   ```r
   format_number(8.2, decimal_places = 1, decimal_separator = ",")
   # Returns: "8,2" (text string)
   ```

2. **For Excel NUMBER formatting** (internal format codes):
   ```r
   create_excel_number_format(1, ",")
   # Returns: "0.0" (Excel displays based on locale, NOT the config setting)
   ```

### Best Practices

**DO:**
- ✅ Use `create_excel_number_format()` from `shared/formatting.R` for ALL Excel number formatting
- ✅ Use `format_number()` for converting numbers to text strings with specific decimal separator
- ✅ Always return period-based format codes from `create_excel_number_format()`
- ✅ Write NUMERIC values to Excel with `openxlsx::writeData()` (not text strings)
- ✅ Apply number format AFTER writing data using `openxlsx::addStyle()`

**DON'T:**
- ❌ Create custom Excel format codes with commas for decimal separators
- ❌ Convert numbers to text strings before writing to Excel
- ❌ Hardcode format strings like `"0.0"` or `"0,0"` directly in code
- ❌ Assume Excel format codes can change decimal/thousands separator meaning

### Example: Correct Excel Number Writing

```r
# Get config settings
decimal_sep <- get_setting(config, "decimal_separator", default = ".")
decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

# Create format code (ALWAYS returns "0.0" format regardless of decimal_sep)
number_format <- create_excel_number_format(decimal_places, decimal_sep)

# Write NUMERIC values to Excel
mean_values <- c(8.2, 7.5, 9.1)  # Keep as numbers!
openxlsx::writeData(wb, sheet_name, mean_values,
                    startRow = 5, startCol = 2, colNames = FALSE)

# Apply number format
number_style <- openxlsx::createStyle(numFmt = number_format)
openxlsx::addStyle(wb, sheet_name, number_style,
                  rows = 5, cols = 2:4, gridExpand = TRUE, stack = TRUE)
```

### Files Implementing Correct Formatting
- `shared/formatting.R` - **CANONICAL IMPLEMENTATION**
- `modules/tabs/lib/excel_writer.R` - Uses shared module
- `modules/tracker/formatting_utils.R` - Uses shared module
- `modules/tracker/tracker_output.R` - Uses shared module

---

## 3. R MODULE CACHING ISSUES

### Problem
After updating R code files, changes don't take effect even after running `source()`.

### Root Cause
R caches function definitions in memory. When you update a file and `source()` it again, if the function was already loaded, R might use the cached version.

### Solution

**Always restart RStudio when making changes to core modules:**

1. **Close RStudio completely** (not just close project - quit application)
2. **Reopen RStudio**
3. **Source the updated files**
4. **Test the changes**

### Alternative: Clear Environment

If you can't restart, clear the R environment:
```r
rm(list = ls(all.names = TRUE))  # Clear all objects
.rs.restartR()  # Restart R session (RStudio only)
```

### Best Practices

**DO:**
- ✅ Restart RStudio after pulling changes from GitHub
- ✅ Restart RStudio after editing shared module files
- ✅ Test changes in a fresh R session
- ✅ Close any open Excel files before re-running analysis

**DON'T:**
- ❌ Assume `source()` alone will reload changed functions
- ❌ Test changes without restarting when editing core modules
- ❌ Keep Excel output files open while re-running analysis

---

## 4. GITHUB SYNC ISSUES

### Problem
GitHub Desktop shows uncommitted changes or won't pull updates.

### Common Issues & Solutions

#### Issue: "Unable to pull when changes are present"

**Solution:**
1. In GitHub Desktop, right-click the file
2. Select "Discard Changes..." (if the remote has the correct version)
3. Then click "Pull origin"

#### Issue: Changes won't disappear after commit

**Solution:**
1. Click "Repository" → "Refresh" (Cmd+R)
2. Click "Fetch origin" to sync with remote

#### Issue: System files showing as changes

Files like `.DS_Store` and `.Rhistory` should NOT be committed.

**Solution:**
1. Leave them uncommitted (they're in .gitignore)
2. Or right-click → "Discard Changes"

### Best Practices

**DO:**
- ✅ Fetch and pull regularly to stay in sync
- ✅ Check you're on the correct branch before committing
- ✅ Use descriptive commit messages
- ✅ Push after committing

**DON'T:**
- ❌ Commit `.DS_Store`, `.Rhistory`, or other system files
- ❌ Edit files while GitHub Desktop shows pending pulls
- ❌ Force push to main/master branches

---

## 5. TESTING BEST PRACTICES

### Running Tests

Tests are located in `tests/testthat/`:
```r
# Run all tests
testthat::test_dir("tests/testthat")

# Run specific test file
testthat::test_file("tests/testthat/test_shared_formatting.R")
```

### Common Test Failures

#### Working Directory Issues
Tests run from `tests/testthat/` directory, so relative paths may fail.

**Solution:** Use `find_turas_root()` or set `TURAS_ROOT` in test setup.

#### Baseline Tests Failing
Baseline tests document old behavior and may fail if module structure changed.

**Solution:** Focus on new shared module tests. Baseline tests can be skipped.

---

## Quick Reference: File Locations

### Shared Modules (USE THESE!)
- `shared/formatting.R` - Number formatting, Excel format codes
- `shared/config_utils.R` - Config reading and validation
- `shared/weights.R` - Weight calculations

### Module Files (Updated to use shared/)
- `modules/tabs/lib/excel_writer.R`
- `modules/tabs/lib/config_loader.R`
- `modules/tracker/formatting_utils.R`
- `modules/tracker/tracker_output.R`
- `modules/tracker/tracker_config_loader.R`

### Tests
- `tests/testthat/test_shared_formatting.R` - 25 tests
- `tests/testthat/test_shared_config.R` - 25 tests
- `tests/testthat/test_shared_weights.R` - 29 tests

---

## Getting Help

If you encounter issues:

1. **Check this document first**
2. **Check git commit history** for recent changes
3. **Run diagnostic tests** from relevant sections above
4. **Restart RStudio** (fixes 80% of caching issues)
5. **Pull latest changes** from GitHub

---

## Version History

- **v1.0** (2025-01-12): Initial documentation after Phase 2 refactoring
  - Documented path resolution solution
  - Documented Excel decimal separator fix
  - Added R module caching solutions
  - Added GitHub sync troubleshooting

---

**Last Updated:** 2025-01-12
**Branch:** `claude/review-survey-analysis-repo-011CV2hKyAEcBYp9i1YDo2Ku`
