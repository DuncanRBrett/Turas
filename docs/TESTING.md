# Turas Testing Guide

**Purpose:** Run regression tests to verify all modules are working correctly after updates.

**When to Run:** After any code changes, before releases, and periodically for quality assurance.

---

## Quick Start

### Run All Tests (Recommended)

**From RStudio:**
```r
# Ensure you're in the Turas root directory
setwd("~/Turas")  # Adjust path as needed

# Run the complete test suite
source("tests/regression/run_all_regression_tests.R")
```

**From Command Line:**
```bash
cd /path/to/Turas
Rscript tests/regression/run_all_regression_tests.R
```

### Expected Output (All Passing)

```
================================================================================
TURAS COMPLETE REGRESSION TEST SUITE
================================================================================

[1/8] Tabs...               ✅ PASS (10/10 checks)
[2/8] Confidence...         ✅ PASS (12/12 checks)
[3/8] KeyDriver...          ✅ PASS (8/8 checks)
[4/8] AlchemerParser...     ✅ PASS (5/5 checks)
[5/8] Segment...            ✅ PASS (6/6 checks)
[6/8] Conjoint...           ✅ PASS (8/8 checks)
[7/8] Pricing...            ✅ PASS (6/6 checks)
[8/8] Tracker...            ✅ PASS (9/9 checks)

================================================================================
✅ ALL IMPLEMENTED MODULES PASSED - TURAS IS STABLE
================================================================================

Modules tested:  8/8
  ✅ Passed:     8
  ❌ Failed:     0
  ⏭️  Planned:    0

Next steps:
  • All done! Complete regression test coverage achieved.
```

---

## Prerequisites

### Required R Packages

```r
# Install if not already installed
install.packages("testthat")
install.packages("jsonlite")
```

### Working Directory

Tests must be run from the Turas root directory (where `Turas.Rproj` is located).

---

## Test Coverage

### Modules Tested

| Module | Test File | Assertions | What's Checked |
|--------|-----------|------------|----------------|
| **Tabs** | `test_regression_tabs_mock.R` | 10 | Mean scores, base sizes, significance flags, effective N, top2box |
| **Confidence** | `test_regression_confidence_mock.R` | 12 | Proportions, CI bounds (normal, Wilson, bootstrap), DEFF |
| **KeyDriver** | `test_regression_keydriver_mock.R` | 8 | R², correlations, importance rankings, driver order |
| **AlchemerParser** | `test_regression_alchemerparser_mock.R` | 5 | Respondent count, question count, structure validation |
| **Segment** | `test_regression_segment_mock.R` | 6 | Cluster count, sizes, centroids, silhouette scores |
| **Conjoint** | `test_regression_conjoint_mock.R` | 8 | Part-worth utilities, attribute importance, model fit |
| **Pricing** | `test_regression_pricing_mock.R` | 6 | Purchase rates, PSM price points, demand curve |
| **Tracker** | `test_regression_tracker_mock.R` | 9 | Wave means, changes, significance, trend direction |

**Total: 64+ regression assertions across 8 modules**

---

## Test Architecture

### Golden Master Pattern

Tests compare current module outputs against known-good "golden" values stored in JSON:

```
tests/
├── regression/
│   ├── run_all_regression_tests.R    # Master test runner
│   ├── test_regression_*_mock.R      # Per-module test files
│   ├── golden/
│   │   ├── tabs_basic.json           # Expected values for Tabs
│   │   ├── confidence_basic.json     # Expected values for Confidence
│   │   ├── conjoint_basic.json       # Expected values for Conjoint
│   │   └── ...                       # One per module
│   └── helpers/
│       ├── assertion_helpers.R       # check_numeric, check_logical, etc.
│       └── path_helpers.R            # File path utilities
└── testthat/                         # Unit tests (testthat framework)
```

### How It Works

1. **Test file** loads module and runs analysis on test data
2. **Golden file** contains expected values with tolerances
3. **Assertion helpers** compare actual vs expected
4. **Pass/Fail** reported for each check

---

## Running Individual Module Tests

### Test a Single Module

```r
# Source helpers first
source("tests/regression/helpers/assertion_helpers.R")
source("tests/regression/helpers/path_helpers.R")

# Run specific module test
library(testthat)
test_file("tests/regression/test_regression_tabs_mock.R")
```

### Available Test Files

```r
# Tabs
test_file("tests/regression/test_regression_tabs_mock.R")

# Confidence
test_file("tests/regression/test_regression_confidence_mock.R")

# KeyDriver
test_file("tests/regression/test_regression_keydriver_mock.R")

# Conjoint
test_file("tests/regression/test_regression_conjoint_mock.R")

# Segment
test_file("tests/regression/test_regression_segment_mock.R")

# Pricing
test_file("tests/regression/test_regression_pricing_mock.R")

# Tracker
test_file("tests/regression/test_regression_tracker_mock.R")

# AlchemerParser
test_file("tests/regression/test_regression_alchemerparser_mock.R")
```

---

## Interpreting Results

### Pass

```
[1/8] Tabs...               ✅ PASS (10/10 checks)
```

All assertions matched expected values within tolerance.

### Fail

```
[1/8] Tabs...               ❌ FAIL (2/10 checks failed)
```

Some values don't match. Run the individual test for details:

```r
test_file("tests/regression/test_regression_tabs_mock.R", reporter = "summary")
```

### Error

```
[1/8] Tabs...               ❌ ERROR: could not find function "xyz"
```

Code error prevented test from running. Check for missing dependencies or syntax errors.

---

## Troubleshooting

### "Please run from TURAS root directory"

```r
# Fix: Set correct working directory
setwd("~/path/to/Turas")
```

### "Package 'testthat' required"

```r
# Fix: Install required packages
install.packages("testthat")
install.packages("jsonlite")
```

### Test Fails After Code Change

1. **Intentional change?** Update the golden file with new expected values
2. **Bug introduced?** Revert the code change and investigate
3. **Tolerance too tight?** Adjust tolerance in golden JSON if appropriate

### Updating Golden Values

If you intentionally changed module behaviour:

```r
# 1. Run module to get new output
# 2. Update tests/regression/golden/<module>_basic.json
# 3. Re-run tests to confirm pass
```

---

## Adding New Tests

### 1. Create Golden File

```json
{
  "module": "newmodule",
  "example": "basic",
  "version": "10.0",
  "created": "2024-12-13",
  "description": "Golden values for NewModule regression test",
  "status": "WORKING_MOCK",
  "checks": [
    {
      "name": "some_metric",
      "value": 42.5,
      "tolerance": 0.1,
      "type": "numeric",
      "description": "Description of what this checks"
    }
  ]
}
```

### 2. Create Test File

```r
# tests/regression/test_regression_newmodule_mock.R

library(testthat)

source("tests/regression/helpers/assertion_helpers.R")
source("tests/regression/helpers/path_helpers.R")

test_that("NewModule basic example produces expected results", {
  # Load golden values
  golden <- jsonlite::fromJSON("tests/regression/golden/newmodule_basic.json")

  # Run module (or mock)
  result <- run_newmodule(...)

  # Check each assertion
  for (check in golden$checks) {
    actual <- extract_value(result, check$name)

    if (check$type == "numeric") {
      check_numeric(check$description, actual, check$value, check$tolerance)
    } else if (check$type == "integer") {
      check_integer(check$description, actual, check$value)
    }
  }
})
```

### 3. Register in Test Runner

Edit `run_all_regression_tests.R`:

```r
test_modules <- list(
  # ... existing modules ...
  list(name = "NewModule", file = "test_regression_newmodule_mock.R", status = "implemented")
)
```

---

## Continuous Integration

### Pre-Commit Hook (Optional)

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
cd "$(git rev-parse --show-toplevel)"
Rscript tests/regression/run_all_regression_tests.R
if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi
```

### Scheduled Testing

Run weekly or after significant changes:

```bash
# Add to crontab for weekly Sunday runs
0 0 * * 0 cd /path/to/Turas && Rscript tests/regression/run_all_regression_tests.R >> /var/log/turas_tests.log 2>&1
```

---

## Test Data Location

Each module has example data used for testing:

```
examples/
├── tabs/basic/           # Tabs test data
├── confidence/basic/     # Confidence test data
├── keydriver/basic/      # KeyDriver test data
├── conjoint/basic/       # Conjoint test data
├── segment/basic/        # Segment test data
├── pricing/basic/        # Pricing test data
├── tracker/basic/        # Tracker test data (multi-wave)
└── alchemerparser/basic/ # AlchemerParser test data
```

---

## Summary

| Action | Command |
|--------|---------|
| Run all tests | `source("tests/regression/run_all_regression_tests.R")` |
| Run single module | `test_file("tests/regression/test_regression_<module>_mock.R")` |
| Install dependencies | `install.packages(c("testthat", "jsonlite"))` |

**Run tests after every significant code change to catch regressions early.**
