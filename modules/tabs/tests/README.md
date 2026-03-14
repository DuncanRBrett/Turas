# Tabs Module Tests

These tests cover **tabs-specific business logic** -- crosstab calculations,
significance testing, config loading, and HTML report generation.

## Directory structure

```
modules/tabs/tests/
  test_tabs_core.R              -- Core tabs functionality (outside testthat)
  testthat/
    test_tabs_core.R            -- Unit tests for tabs calculations
    test_calculations.R         -- Critical-path tests for rating mean, cell data, significance
  fixtures/                     -- Synthetic test data (created by test scripts)
```

## What belongs here

- Crosstab calculation tests (counts, percentages, means, medians)
- Significance testing (z-test, chi-square, effective-n)
- Config loading and validation
- HTML report builder logic
- Banner/question orchestration

## What does NOT belong here

Cross-cutting infrastructure tests (TRS, shared utilities, code quality scans)
belong in the project root at `tests/testthat/`.

## How to run

```r
# Run all tabs testthat tests
testthat::test_dir("modules/tabs/tests/testthat")

# Run a specific test file
testthat::test_file("modules/tabs/tests/testthat/test_calculations.R")

# Run the standalone core test
source("modules/tabs/tests/test_tabs_core.R")
```

## Why tests live in two places

The split is intentional:

- **`tests/testthat/`** (project root) = shared infrastructure used by ALL modules
- **`modules/tabs/tests/testthat/`** = tabs-specific business logic

This keeps module tests co-located with their code while avoiding duplication
of shared infrastructure tests across 11 modules.
