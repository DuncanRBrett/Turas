# TURAS Testing Infrastructure

**Created:** Phase 1 of Code Quality Improvements
**Framework:** testthat
**Purpose:** Automated testing for TURAS Analytics Platform
**Updated:** 2025-12-02 (Added regression test harness)

---

## Directory Structure

```
tests/
├── README.md                          # This file
├── testthat.R                         # Test runner script
├── testthat/                          # Unit test files
│   ├── test_shared_functions.R        # Tests for core shared functions
│   ├── test_formatting_baseline.R     # Baseline: decimal separator handling
│   ├── test_config_baseline.R         # Baseline: config loading
│   ├── test_weights_baseline.R        # Baseline: weight calculations
│   └── (more tests added in later phases)
└── regression/                        # NEW: Regression test harness
    ├── golden/                        # Expected output values (JSON)
    │   ├── tabs_basic.json
    │   ├── tracker_basic.json
    │   └── confidence_basic.json
    ├── helpers/                       # Utility functions
    │   ├── assertion_helpers.R
    │   └── path_helpers.R
    ├── test_regression_tabs.R         # Tabs module regression test
    ├── test_regression_tracker.R      # Tracker module regression test
    └── test_regression_confidence.R   # Confidence module regression test
```

---

## Running Tests

### Option 1: Run All Tests (Recommended)
```r
# From R console in Turas root directory:
source("tests/testthat.R")
```

### Option 2: Run Specific Test File
```r
library(testthat)
test_file("tests/testthat/test_shared_functions.R")
```

### Option 3: Run Tests in Directory
```r
library(testthat)
test_dir("tests/testthat")
```

### Option 4: Run with Reporter Options
```r
library(testthat)
test_dir("tests/testthat", reporter = "summary")  # Brief summary
test_dir("tests/testthat", reporter = "progress") # Progress bar
test_dir("tests/testthat", reporter = "check")    # Detailed output
```

### Option 5: Run Regression Tests Only (NEW!)
```r
library(testthat)

# Run all regression tests
test_dir("tests/regression", pattern = "^test_regression_.*\\.R$")

# Run specific module regression test
test_file("tests/regression/test_regression_tabs.R")

# Run from command line
Rscript -e "library(testthat); test_dir('tests/regression')"
```

**Note:** Regression tests may be skipped if module integration is incomplete.
Check test output for skip messages with reasons.

---

## Test Categories

### Unit Tests (testthat/)
Tests for individual functions:
- `test_shared_functions.R` - Core utility functions
- `test_shared_weights.R` - Weight calculation functions
- `test_shared_formatting.R` - Formatting functions
- `test_shared_config.R` - Config loading functions

### Baseline Tests (testthat/)
These tests document **current behavior** before refactoring:
- `test_formatting_baseline.R` - Documents decimal separator inconsistency
- `test_config_baseline.R` - Documents config loading patterns
- `test_weights_baseline.R` - Documents weight calculation formulas

**Purpose:** Ensure refactoring doesn't break existing functionality

### Regression Tests (regression/) - NEW!
End-to-end tests that verify modules produce consistent outputs:
- `test_regression_tabs.R` - Tabs module regression test
- `test_regression_tracker.R` - Tracker module (planned)
- `test_regression_confidence.R` - Confidence module (planned)

**Purpose:** Catch regressions in module outputs after code changes

**How it works:**
1. Small example datasets in `/examples/[module]/basic/`
2. Known "golden" values stored in `/tests/regression/golden/`
3. Tests run module on example data and compare to golden values
4. Any difference triggers a test failure

**Status:**
- ✅ Framework created
- ✅ Helper functions implemented
- ⏳ Tabs integration in progress
- ⏳ Tracker & Confidence modules pending

---

## Test Requirements

### Required Packages
```r
install.packages("testthat")
install.packages("openxlsx")  # For Excel-related tests
install.packages("readxl")    # For config file tests
```

### Running Tests in CI/CD
```bash
# From command line (if Rscript available):
Rscript tests/testthat.R
```

---

## Test Writing Guidelines

### 1. Test File Naming
- Prefix with `test_`
- Descriptive name: `test_<module>_<category>.R`
- Examples: `test_formatting.R`, `test_validation.R`

### 2. Test Structure
```r
test_that("descriptive test name", {
  # Arrange: Set up test data
  input <- c(1, 2, 3)

  # Act: Call function
  result <- my_function(input)

  # Assert: Verify result
  expect_equal(result, expected_value)
})
```

### 3. Use `skip_if_not()` for Optional Functions
```r
test_that("optional function works", {
  skip_if_not(exists("optional_function"),
              message = "optional_function not found")

  result <- optional_function()
  expect_true(result)
})
```

### 4. Test Edge Cases
- NULL values
- NA values
- Empty vectors/data frames
- Invalid inputs
- Boundary conditions

---

## Phase 1 Testing Status

✅ **Completed:**
- testthat framework installed and configured
- Test runner script created
- Baseline tests for shared functions
- Baseline tests for formatting (decimal separator)
- Baseline tests for config loading
- Baseline tests for weight calculations

🔜 **Next Phases:**
- Phase 2: Tests for shared formatting module
- Phase 3: Tests for shared config utilities
- Phase 4: Tests for shared weights module
- Phase 5: Integration tests

---

## Golden Master Testing

### Purpose
Ensure that refactoring produces **bit-for-bit identical** outputs.

### Approach
1. Run current code on test dataset → Save output
2. Refactor code
3. Run refactored code on same dataset → Compare outputs
4. Outputs must match exactly

### Implementation
```r
# Save golden master
current_output <- run_current_module(test_data)
saveRDS(current_output, "tests/golden_masters/tabs_output.rds")

# After refactoring, compare
new_output <- run_refactored_module(test_data)
golden_output <- readRDS("tests/golden_masters/tabs_output.rds")

expect_identical(new_output, golden_output)
```

---

## Continuous Integration

### GitHub Actions (Future)
```yaml
name: R Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: r-lib/actions/setup-r@v2
      - name: Install dependencies
        run: Rscript -e 'install.packages(c("testthat", "openxlsx", "readxl"))'
      - name: Run tests
        run: Rscript tests/testthat.R
```

---

## Troubleshooting

### "testthat not found"
```r
install.packages("testthat")
```

### "Working directory wrong"
Make sure to run from Turas root:
```r
setwd("/path/to/Turas")
source("tests/testthat.R")
```

### "Cannot source module files"
Tests expect to run from Turas root. Check:
```r
getwd()  # Should end in "Turas"
file.exists("modules/tabs/lib/shared_functions.R")  # Should be TRUE
```

---

## Success Criteria

Tests pass when:
- ✅ No errors
- ✅ No failures
- ⚠️ Warnings are acceptable if documented
- ⏭️ Skipped tests are acceptable if optional

---

---

## Regression Test Harness (NEW!)

### Overview

The regression test harness provides automated end-to-end testing for TURAS modules.
It ensures that code changes don't break existing functionality by comparing
module outputs against known "golden" values.

### Key Concepts

**Golden Values:**
- Expected outputs stored in JSON files (`tests/regression/golden/`)
- Include specific metrics to check (means, percentages, significance flags, etc.)
- Updated only when module behavior intentionally changes

**Example Data:**
- Small, synthetic datasets in `/examples/[module]/basic/`
- Serve dual purpose: tutorials AND regression test inputs
- Single source of truth (no duplication)

**Helper Functions:**
- `assertion_helpers.R` - Compare actual vs expected values
- `path_helpers.R` - Locate example projects and golden values

### How to Use

**1. Running Regression Tests:**
```r
# From TURAS root directory
library(testthat)
test_file("tests/regression/test_regression_tabs.R")
```

**2. Interpreting Results:**
- ✅ **Pass:** Module output matches golden values
- ❌ **Fail:** Output differs from expected (investigate!)
- ⏭️ **Skip:** Module integration incomplete (see message)

**3. When a Test Fails:**

Ask yourself:
- Did I intentionally change module logic? → Update golden values
- Is this a bug I introduced? → Fix the code
- Is the tolerance too strict? → Adjust tolerance in JSON

**4. Updating Golden Values:**

When you intentionally change module behavior:
1. Run the module on example data
2. Extract new values
3. Update `tests/regression/golden/[module]_basic.json`
4. Re-run test to verify

### Implementation Status

| Module | Example Data | Golden Values | Test File | Status |
|--------|-------------|---------------|-----------|--------|
| **Tabs** | ✅ Created | ✅ Placeholder | ✅ Template | ⏳ Integration needed |
| **Tracker** | ⏳ Planned | ⏳ Planned | ⏳ Planned | Not started |
| **Confidence** | ⏳ Planned | ⏳ Planned | ⏳ Planned | Not started |

### Completing Tabs Integration

To complete the Tabs regression test:

1. **Add Survey_Structure.xlsx** to `examples/tabs/basic/`
2. **Run Tabs manually** on the example data
3. **Capture actual outputs** (means, sig flags, bases, etc.)
4. **Update** `tests/regression/golden/tabs_basic.json` with real values
5. **Implement** `extract_tabs_value()` function in test file
6. **Implement** `run_tabs_for_test()` wrapper function
7. **Remove** `skip()` statement from test
8. **Verify** all checks pass

See detailed instructions in:
- `tests/regression/test_regression_tabs.R` (completion checklist)
- `examples/tabs/basic/README.md` (example usage)
- `REGRESSION_TEST_HARNESS_PLAN.md` (full implementation plan)

### Future Enhancements

**Phase 2: Tracker Module**
- Create `/examples/tracker/basic/` with multi-wave data
- Capture trend, change, and continuity metrics
- Implement regression test

**Phase 3: Confidence Module**
- Create `/examples/confidence/basic/` with survey data
- Capture MOE, Wilson CI, DEFF values
- Implement regression test

**Phase 4: Automation**
- Create `run_all_regression.R` script
- Add to CI/CD pipeline
- Shiny "Run TURAS self-check" button (optional)

---

**Maintained by:** TURAS Development Team
**Last Updated:** 2025-12-02 (Added regression test harness)
**Questions:** See main README.md for contact information
