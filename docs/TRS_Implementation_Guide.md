# TRS Implementation Guide

**TURAS Reliability Standard (TRS) v1.0 - Developer Guide**

Version: 1.0
Date: December 2024

---

## Overview

This guide documents how to integrate TRS v1.0 into Turas modules. TRS ensures that Turas:
- Never produces silent wrong output
- Never degrades without disclosure
- Never traps the user in an unfixable refusal state

---

## Architecture

### Shared Infrastructure

Location: `/modules/shared/lib/trs_refusal.R`

This file provides the core TRS functions used by all modules:

| Function | Purpose |
|----------|---------|
| `turas_refuse()` | Issue a TRS-compliant refusal |
| `with_refusal_handler()` | Wrap module execution to catch refusals |
| `is_refusal()` | Check if result was a refusal |
| `is_error()` | Check if result was an unexpected error |
| `trs_status_pass()` | Create PASS status |
| `trs_status_partial()` | Create PARTIAL status (with degradation declaration) |
| `trs_status_refuse()` | Create REFUSE status |
| `guard_init()` | Initialize guard state |
| `guard_warn()` | Add warning to guard state |
| `guard_flag_stability()` | Add stability flag |
| `guard_summary()` | Get guard state summary |
| `validate_mapping_coverage()` | Hard mapping validation gate |
| `trs_banner_start()` | Display start banner |
| `trs_banner_end()` | Display end banner |

### Loading TRS

TRS is loaded automatically via `/modules/shared/lib/import_all.R`.

For modules that source import_all.R, TRS functions are available globally.

---

## Execution States

Every module execution MUST terminate in exactly one state:

| State | Meaning | Outputs | User Action |
|-------|---------|---------|-------------|
| **PASS** | All outputs valid and complete | Yes | None needed |
| **PARTIAL** | Outputs produced with declared degradation | Yes (degraded) | Review warnings |
| **REFUSE** | User-fixable issue; no outputs produced | No | Fix and retry |
| **ERROR** | Internal Turas bug | No | Report to devs |

---

## Refusal Code Prefixes

All refusal codes MUST use one of these prefixes:

| Prefix | Category | Examples |
|--------|----------|----------|
| `CFG_` | Configuration errors | `CFG_MISSING_SHEET`, `CFG_INVALID_TYPE` |
| `DATA_` | Data integrity errors | `DATA_NOT_FOUND`, `DATA_ZERO_VARIANCE` |
| `IO_` | File or path errors | `IO_FILE_NOT_FOUND`, `IO_WRITE_FAILED` |
| `MODEL_` | Model fitting errors | `MODEL_FIT_FAILED`, `MODEL_SEPARATION` |
| `MAPPER_` | Mapping / coverage errors | `MAPPER_UNMAPPED_COEFFICIENTS` |
| `PKG_` | Missing dependency errors | `PKG_HAVEN_REQUIRED` |
| `FEATURE_` | Optional feature failures | `FEATURE_SHAP_UNAVAILABLE` |
| `BUG_` | Internal logic failures | `BUG_INTERNAL_ERROR` |

---

## Implementing TRS in a Module

### Step 1: Create Module Guard File

Create `<module>/R/00_guard.R` with:

```r
# Module-specific refusal wrapper
<module>_refuse <- function(code, title, problem, why_it_matters = NULL,
                            how_to_fix, expected = NULL, observed = NULL,
                            missing = NULL, details = NULL) {
  # Ensure code has valid prefix
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
    module = "<MODULE_NAME>"
  )
}

# Module-specific handler wrapper
<module>_with_refusal_handler <- function(expr) {
  result <- with_refusal_handler(expr, module = "<MODULE_NAME>")
  if (inherits(result, "turas_refusal_result")) {
    class(result) <- c("<module>_refusal_result", class(result))
  }
  result
}

# Module-specific guard init
<module>_guard_init <- function() {
  guard <- guard_init(module = "<MODULE_NAME>")
  # Add module-specific fields
  guard$custom_field <- NULL
  guard
}
```

### Step 2: Update Main Entry Point

```r
run_<module>_analysis <- function(...) {
  # Wrap with refusal handler
  <module>_with_refusal_handler(
    run_<module>_analysis_impl(...)
  )
}

run_<module>_analysis_impl <- function(...) {
  start_time <- Sys.time()

  # TRS start banner
  trs_banner_start("<MODULE_NAME>", "X.X")

  # Initialize guard state
  guard <- <module>_guard_init()

  # Track degradation
  degraded_reasons <- character(0)
  affected_outputs <- character(0)

  # ... module logic ...

  # Determine final status
  if (length(degraded_reasons) > 0) {
    results$run_status <- "PARTIAL"
    results$status <- trs_status_partial(
      module = "<MODULE_NAME>",
      degraded_reasons = degraded_reasons,
      affected_outputs = affected_outputs
    )
  } else {
    results$run_status <- "PASS"
    results$status <- trs_status_pass(module = "<MODULE_NAME>")
  }

  # TRS end banner
  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))
  trs_banner_end("<MODULE_NAME>", results$run_status, elapsed)

  invisible(results)
}
```

### Step 3: Replace stop() with Refusals

**Before (legacy):**
```r
if (!file.exists(data_file)) {
  stop("Data file not found: ", data_file, call. = FALSE)
}
```

**After (TRS):**
```r
if (!file.exists(data_file)) {
  <module>_refuse(
    code = "IO_DATA_NOT_FOUND",
    title = "Data File Not Found",
    problem = paste0("Data file does not exist: ", data_file),
    why_it_matters = "Analysis requires data to proceed.",
    how_to_fix = c(
      "Check that the file path is correct",
      "Ensure the file exists at the specified location"
    )
  )
}
```

### Step 4: Handle Optional Feature Failures as PARTIAL

```r
if (enable_feature) {
  feature_result <- tryCatch({
    run_feature()
  }, error = function(e) {
    # Degradation, not hard stop
    guard <<- guard_warn(guard, paste0("Feature failed: ", e$message), "feature")
    degraded_reasons <<- c(degraded_reasons, e$message)
    affected_outputs <<- c(affected_outputs, "Feature output")
    NULL
  })
}
```

### Step 5: Add Mapping Validation Gate

For modules with model-to-output mapping:

```r
# After model fitting
validate_mapping_coverage(
  mapping_table = mapping,
  model_terms = names(coef(model)),
  key_col = "coef_name",
  module = "<MODULE_NAME>"
)
```

---

## Refusal Message Format

Every refusal MUST include:

```
================================================================================
  [REFUSE] <CODE>: <TITLE>
================================================================================

Problem:
  <one-sentence description>

Why it matters:
  <one-sentence explanation of analytical risk>

How to fix:
  1. <step 1>
  2. <step 2>
  ...

Diagnostics:
  Expected:  <list>
  Observed:  <list>
  Missing:   <list>
  Unmapped:  <list>

================================================================================
```

---

## Testing Requirements

Each TRS-integrated module MUST have:

1. **Golden-path test**: Verify PASS status on valid input
2. **Refusal test**: Verify appropriate refusal on invalid config/data
3. **Mapping failure test**: Verify refusal when mapping fails
4. **No-silent-partial test**: Verify PARTIAL status declares degradation

Example test:
```r
test_that("module refuses on missing config sheet", {
  expect_error(
    run_module_analysis("bad_config.xlsx"),
    class = "turas_refusal"
  )
})
```

---

## Compliance Checklist

For each module, verify:

- [ ] Wrapped in `with_refusal_handler()` or module-specific wrapper
- [ ] All `stop()` calls replaced with `*_refuse()` for user-fixable issues
- [ ] No `warning()` calls for mapping failures (must refuse)
- [ ] Optional feature failures produce PARTIAL, not crashes
- [ ] Guard state tracks warnings and issues
- [ ] `run_status` included in results (PASS/PARTIAL/REFUSE)
- [ ] TRS banners displayed at start/end
- [ ] Mapping validation gate in place (if applicable)
- [ ] 4 required tests implemented

---

## Module Status

| Module | TRS Status | Notes |
|--------|------------|-------|
| CatDriver | Compliant | Template implementation |
| KeyDriver | Compliant | First rollout |
| Tabs | Pending | |
| Tracker | Pending | |
| Conjoint | Pending | |
| Pricing | Pending | |
| MaxDiff | Pending | |
| Segmentation | Pending | |
| Confidence | Pending | |
| AlchemerParser | Pending | |

---

## Contact

For questions about TRS implementation, consult:
- `TURAS_Mapping_Refusal_Standard_TRS_v1.0.md`
- `TURAS_TRS_Integration_Compliance_v1.0.md`
- `Turas reliability specification.txt`
