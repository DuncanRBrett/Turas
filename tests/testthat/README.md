# Project-Level Tests (tests/testthat/)

These tests cover **cross-cutting infrastructure** shared by all Turas modules.
They live at the project root because they are not specific to any single module.

## What belongs here

- **TRS compliance** (`test_trs_refusal.R`) -- verifies the Turas Refusal System works correctly
- **Shared utilities** (`test_shared_config.R`, `test_shared_formatting.R`, `test_shared_validation.R`, `test_shared_weights.R`) -- tests for `modules/shared/lib/` functions used by multiple modules
- **HTML infrastructure** (`test_html_guard.R`, `test_html_table_builder.R`, `test_html_transformer.R`) -- shared HTML report building blocks
- **Code quality scans** (`test_no_silent_trycatch.R`) -- automated checks for anti-patterns across the codebase
- **Module smoke tests** (`test_module_smoke.R`) -- basic load/init checks across all modules

## What does NOT belong here

Module-specific business logic tests belong in `modules/{module}/tests/testthat/`.
For example, tabs crosstab calculations go in `modules/tabs/tests/testthat/`.

## How to run

```r
# Run all project-level tests
testthat::test_dir("tests/testthat")

# Run a specific test file
testthat::test_file("tests/testthat/test_trs_refusal.R")
```

## Regression tests

A separate regression suite lives in `tests/regression/` covering all modules with
golden-file comparisons. Run with:

```r
source("tests/regression/run_all_regression_tests.R")
```
