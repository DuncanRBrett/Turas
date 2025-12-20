# TRS Full Compliance Rollout - Handover Document

## Overview

This document provides instructions for implementing full TRS (Turas Reliability Standard) v1.0 compliance across all Turas modules.

**Current Status:**
- KeyDriver: FULLY TRS COMPLIANT
- CatDriver: FULLY TRS COMPLIANT
- All other modules: Pass "no silent fails" test, but lack full TRS infrastructure

**Target Modules for Rollout:**
1. AlchemerParser
2. conjoint
3. confidence
4. maxdiff
5. pricing
6. segment
7. tabs
8. tracker

---

## TRS v1.0 Core Concepts

### Execution States
| State | Meaning |
|-------|---------|
| PASS | All outputs valid and complete |
| PARTIAL | Outputs produced with declared degradation |
| REFUSE | User-fixable issue; no outputs produced |
| ERROR | Internal Turas bug |

### Refusal Code Prefixes
| Prefix | Use Case |
|--------|----------|
| CFG_ | Configuration errors (missing sheets, invalid settings) |
| DATA_ | Data integrity errors (missing columns, insufficient N) |
| IO_ | File or path errors |
| MODEL_ | Model fitting errors |
| MAPPER_ | Mapping/coverage errors |
| PKG_ | Missing dependency errors |
| FEATURE_ | Optional feature failures |
| BUG_ | Internal logic failures |

### Mandatory Refusal Fields
Every `turas_refuse()` call MUST include:
- `code`: TRS-prefixed code (e.g., "CFG_MISSING_SHEET")
- `title`: Short title
- `problem`: One-sentence description
- `why_it_matters`: **MANDATORY** - explains analytical risk to user
- `how_to_fix`: Step-by-step remediation

---

## Implementation Pattern

### Step 1: Create Module Guard File

Create `modules/{module}/R/00_guard.R` following this template:

```r
# ==============================================================================
# {MODULE_NAME} - TRS GUARD LAYER
# ==============================================================================
#
# TRS v1.0 integration for the {Module Name} module.
#
# ==============================================================================

# Source shared TRS infrastructure (if not already loaded)
if (!exists("turas_refuse", mode = "function")) {
  source(file.path(dirname(sys.frame(1)$ofile), "../../shared/lib/trs_refusal.R"))
}

#' Refuse to Run with TRS-Compliant Message ({ModuleName})
#'
#' @keywords internal
{module}_refuse <- function(code,
                            title,
                            problem,
                            why_it_matters,
                            how_to_fix,
                            expected = NULL,
                            observed = NULL,
                            missing = NULL,
                            details = NULL) {

  # Ensure code has valid TRS prefix
  if (!grepl("^(CFG_|DATA_|IO_|MODEL_|MAPPER_|PKG_|FEATURE_|BUG_)", code)) {
    code <- paste0("CFG_", code)
  }

  turas_refuse(
    code = code,
    title = title,
    problem = problem,
    why_it_matters = why_it_matters,
    how_to_fix = how_to_fix,
    expected = expected,
    observed = observed,
    missing = missing,
    details = details,
    module = "{MODULE_NAME}"
  )
}

#' Run {ModuleName} with Refusal Handler
#'
#' @export
{module}_with_refusal_handler <- function(expr) {
  with_refusal_handler(expr, module = "{MODULE_NAME}")
}

#' Initialize {ModuleName} Guard State
#'
#' @export
{module}_guard_init <- function() {
  guard <- guard_init(module = "{MODULE_NAME}")
  # Add module-specific fields here
  guard
}
```

### Step 2: Add Module-Specific Validation Gates

Add validation functions for common failure modes:

```r
#' Validate {ModuleName} Configuration
validate_{module}_config <- function(config) {
  # Check required config elements
  if (is.null(config$some_required_field)) {
    {module}_refuse(
      code = "CFG_MISSING_FIELD",
      title = "Required Configuration Missing",
      problem = "The 'some_required_field' is not specified in config.",
      why_it_matters = "This field is required for the analysis to run correctly.",
      how_to_fix = c(
        "Open your config file",
        "Add the 'some_required_field' setting",
        "Save and re-run"
      )
    )
  }
  invisible(TRUE)
}

#' Validate {ModuleName} Data
validate_{module}_data <- function(data, config, guard) {
  # Check data requirements
  # Return updated guard state
  guard
}
```

### Step 3: Wrap Main Entry Point

Update the module's main function to use the refusal handler:

```r
run_{module}_analysis <- function(config_file, ...) {
  {module}_with_refusal_handler({
    # Load and validate config
    config <- load_{module}_config(config_file)
    validate_{module}_config(config)

    # Initialize guard state
    guard <- {module}_guard_init()

    # Load and validate data
    data <- load_data(config$data_file)
    guard <- validate_{module}_data(data, config, guard)

    # Run analysis...

    # Return results with status
    list(
      results = results,
      guard_summary = guard_summary(guard),
      run_status = if (length(guard$warnings) > 0) "PARTIAL" else "PASS"
    )
  })
}
```

### Step 4: Replace `stop()` with Structured Refusals

Find all `stop()` calls and replace with structured refusals:

**Before:**
```r
if (!file.exists(data_file)) {
  stop("Data file not found: ", data_file)
}
```

**After:**
```r
if (!file.exists(data_file)) {
  {module}_refuse(
    code = "IO_DATA_FILE_NOT_FOUND",
    title = "Data File Not Found",
    problem = paste0("Cannot find data file: ", data_file),
    why_it_matters = "The analysis requires this data file to proceed.",
    how_to_fix = c(
      "Check that the file path in your config is correct",
      "Verify the file exists at the specified location",
      "Check for typos in the filename"
    ),
    details = paste0("Expected path: ", data_file)
  )
}
```

### Step 5: Ensure tryCatch Handlers Log Properly

All `tryCatch` error handlers must have explicit logging:

```r
tryCatch({
  # risky operation
}, error = function(e) {
  msg <- sprintf("Operation failed: %s", conditionMessage(e))
  cat(sprintf("   [WARN] %s\n", msg))
  warning(msg, call. = FALSE)
  NULL  # or appropriate fallback
})
```

---

## Module-Specific Notes

### AlchemerParser
- Key validation: Word doc exists, data map readable
- Common failures: Parsing errors, invalid question formats
- Suggested refusal codes: `IO_WORD_DOC_NOT_FOUND`, `DATA_INVALID_FORMAT`, `CFG_MISSING_DATA_MAP`

### conjoint
- Key validation: Design matrix, attribute levels, estimation convergence
- Common failures: Insufficient data, design issues, non-convergence
- Suggested refusal codes: `CFG_INVALID_DESIGN`, `MODEL_DID_NOT_CONVERGE`, `DATA_INSUFFICIENT_CHOICES`

### confidence
- Key validation: Sample sizes, proportion bounds, representativeness data
- Common failures: Zero cells, invalid proportions
- Suggested refusal codes: `DATA_ZERO_CELL`, `CFG_INVALID_CONFIDENCE_LEVEL`

### maxdiff
- Key validation: Design balance, HB convergence, item count
- Common failures: Unbalanced design, HB non-convergence
- Suggested refusal codes: `CFG_UNBALANCED_DESIGN`, `MODEL_HB_DID_NOT_CONVERGE`

### pricing
- Key validation: Price points, sample size per price
- Common failures: Insufficient responses, invalid price sequences
- Suggested refusal codes: `DATA_INSUFFICIENT_AT_PRICE`, `CFG_INVALID_PRICE_SEQUENCE`

### segment
- Key validation: Number of clusters, variable selection
- Common failures: Insufficient variation, cluster instability
- Suggested refusal codes: `MODEL_CLUSTER_UNSTABLE`, `DATA_INSUFFICIENT_VARIATION`

### tabs
- Key validation: Question mappings, banner definitions
- Common failures: Missing questions, invalid banner structure
- Suggested refusal codes: `CFG_QUESTION_NOT_FOUND`, `CFG_INVALID_BANNER`

### tracker
- Key validation: Wave files, question consistency across waves
- Common failures: Missing waves, inconsistent coding
- Suggested refusal codes: `IO_WAVE_FILE_NOT_FOUND`, `DATA_WAVE_INCONSISTENT`

---

## Testing Checklist

For each module, verify:

- [ ] Guard file exists at `modules/{module}/R/00_guard.R`
- [ ] `{module}_refuse()` wrapper function defined
- [ ] `{module}_with_refusal_handler()` wrapper defined
- [ ] Main entry point wrapped with refusal handler
- [ ] All `stop()` calls replaced with structured refusals
- [ ] All refusals include `why_it_matters` (mandatory)
- [ ] All tryCatch handlers have explicit logging
- [ ] Guardrail test passes: `testthat::test_file("tests/testthat/test_no_silent_trycatch.R")`
- [ ] Module runs successfully with valid inputs
- [ ] Module produces clean refusal message with invalid inputs

---

## Files Reference

### Shared Infrastructure
- `modules/shared/lib/trs_refusal.R` - Core TRS functions
- `modules/shared/lib/import_all.R` - Shared imports (sources trs_refusal.R)

### Existing TRS Implementations (Reference)
- `modules/keydriver/R/00_guard.R` - KeyDriver guard layer
- `modules/catdriver/R/08_guard.R` - CatDriver guard layer

### CI Guardrail
- `tests/testthat/test_no_silent_trycatch.R` - Prevents silent error handlers

---

## Priority Order

Recommended implementation order based on usage frequency and complexity:

1. **tabs** - High usage, well-structured
2. **tracker** - High usage, pairs with tabs
3. **segment** - Medium complexity
4. **maxdiff** - Similar to conjoint patterns
5. **conjoint** - Complex but well-documented
6. **pricing** - Multiple analysis modes
7. **confidence** - Simpler scope
8. **AlchemerParser** - Utility module, lower priority

---

## Estimated Effort

Per module:
- Create guard file: 30 minutes
- Add validation gates: 1-2 hours
- Replace stop() calls: 1-2 hours
- Test and verify: 30 minutes

**Total estimate: 3-5 hours per module, ~30-40 hours total**

---

*Document created: December 2024*
*Branch for implementation: Create new branch from main after merging current work*
