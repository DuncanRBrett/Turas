# TURAS Testing Infrastructure

**Created:** Phase 1 of Code Quality Improvements
**Framework:** testthat
**Purpose:** Automated testing for TURAS Analytics Platform

---

## Directory Structure

```
tests/
├── README.md                          # This file
├── testthat.R                         # Test runner script
└── testthat/                          # Test files directory
    ├── test_shared_functions.R        # Tests for core shared functions
    ├── test_formatting_baseline.R     # Baseline: decimal separator handling
    ├── test_config_baseline.R         # Baseline: config loading
    ├── test_weights_baseline.R        # Baseline: weight calculations
    └── (more tests added in later phases)
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

---

## Test Categories

### Baseline Tests
These tests document **current behavior** before refactoring:
- `test_formatting_baseline.R` - Documents decimal separator inconsistency
- `test_config_baseline.R` - Documents config loading patterns
- `test_weights_baseline.R` - Documents weight calculation formulas

**Purpose:** Ensure refactoring doesn't break existing functionality

### Unit Tests
Tests for individual functions:
- `test_shared_functions.R` - Core utility functions

### Integration Tests
*(To be added in later phases)*
- End-to-end module tests
- Golden master regression tests

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

**Maintained by:** TURAS Development Team
**Last Updated:** Phase 1 Implementation
**Questions:** See main README.md for contact information
