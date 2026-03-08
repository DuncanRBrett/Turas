# Shared Module - Code Inventory

## Overview

The **Shared** module is the foundational infrastructure layer for the entire Turas analytics platform. Every analytical module (tabs, tracker, conjoint, maxdiff, keydriver, catdriver, confidence, pricing, segment, weighting, AlchemerParser) depends on this module to function.

It implements the **Turas Refusal System (TRS v1.0)** -- the mandatory error handling framework that replaces all `stop()` calls with structured, actionable refusals -- along with validation utilities, config/data loading, formatting, logging, and security features.

**Key capabilities:**

- **TRS v1.0 refusal system** -- Structured error handling with PASS/PARTIAL/REFUSED status codes, ensuring no silent failures across the platform
- **Excel formula injection protection** -- OWASP-compliant sanitisation preventing CVE-class injection attacks via user-supplied data
- **Atomic file saves** -- Write-to-temp-then-rename pattern preventing corrupt output files on crash or interruption
- **Console capture for Shiny** -- Intercepts stdout/warnings/messages so errors are visible in the R console when running behind the Shiny GUI
- **HB/MCMC diagnostics** -- Gelman-Rubin, effective sample size, and Geweke convergence checks for conjoint and maxdiff hierarchical Bayes estimation
- **Multi-format data loading** -- Transparent handling of .xlsx, .csv, and .sav (SPSS) input files with auto-detection

---

## Summary Statistics

| Metric                  | Value       |
|-------------------------|-------------|
| Total R files           | 17          |
| Total lines of R code   | ~5,198      |
| Exported functions      | ~130+       |
| Dependency layers       | 3           |
| Avg quality score       | 90/100      |
| Largest file            | trs_refusal.R (891 lines) |
| Smallest file           | import_all.R (103 lines)  |

---

## Detailed File Inventory

### Root Infrastructure

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `template_styles.R` | 425 | Excel template styling infrastructure for config sheets | 90/100 | ~15 style factory functions and helpers; shared by all modules that generate Excel config templates |

### Foundation Utilities (`lib/`)

These are the lowest-level building blocks. Everything else depends on them.

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `import_all.R` | 103 | Master import orchestrator; sources all utilities in dependency order | 85/100 | Pure orchestrator -- no logic of its own. Source order is critical; changing it can break downstream modules |
| `validation_utils.R` | 491 | Input validation framework (8 functions: `validate_data_frame`, `validate_numeric_param`, `validate_column_exists`, etc.) | 92/100 | Clean interfaces with full TRS integration; used by every module's `00_guard.R` |
| `config_utils.R` | 359 | Config loading and path handling (8 functions: `load_config_sheet`, `find_turas_root`, `resolve_path`, etc.) | 90/100 | Cached root-finding for performance; platform-independent path resolution (Windows/macOS/Linux) |
| `data_utils.R` | 294 | Data loading (multi-format) and type conversion (5 functions) | 88/100 | Auto-detects file format from extension; integrates with `data.table` for large files; handles .xlsx, .csv, .sav |

### Formatting and Domain Utilities (`lib/`)

Specialised utilities for output formatting and domain-specific calculations.

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `formatting_utils.R` | 249 | Number and text formatting for Excel output (7 functions) | 88/100 | Locale-aware formatting; handles percentages, decimals, significance markers |
| `weights_utils.R` | 213 | Weight calculations -- effective sample size (ESS), design effect (DEFF), validation (5 functions) | 88/100 | Mathematically correct formulas; clean interface; used by tabs, tracker, and weighting modules |
| `logging_utils.R` | 132 | Progress tracking and error logging (6 functions) | 85/100 | Simple and functional; provides timestamped console output for long-running operations |
| `hb_diagnostics.R` | 597 | HB/MCMC convergence diagnostics (7 functions: Gelman-Rubin, ESS, Geweke, trace plots) | 90/100 | Specialised but thorough; critical for conjoint and maxdiff modules to verify estimation convergence |

### TRS v1.0 Infrastructure (`lib/`)

The heart of the Turas error handling philosophy. These files implement the structured refusal system that replaces all `stop()` calls platform-wide.

| File | Lines | Purpose | Quality | Notes |
|------|------:|---------|--------:|-------|
| `trs_refusal.R` | 891 | Core TRS refusal system (22 functions) | 95/100 | **Largest file in module.** Defines refusal constructors, validators, combiners, and formatters. Every module depends on this |
| `console_capture.R` | 153 | Stdout/warning/message capture for Shiny GUI | 90/100 | Critical for error visibility -- Shiny can silently swallow errors without this |
| `turas_log.R` | 189 | Unified TRS-formatted logging (9 functions) | 90/100 | Structured log output with timestamps, severity levels, and TRS error codes |
| `trs_run_state.R` | 184 | Execution state tracking -- PASS/PARTIAL/REFUSE (6 functions) | 88/100 | Tracks cumulative run status across multi-step module pipelines |
| `trs_banner.R` | 124 | Standardised start/end banners (3 functions) | 88/100 | Consistent console framing for module execution; aids visual log parsing |
| `trs_run_status_writer.R` | 195 | Run_Status Excel sheet generation (colour-coded) | 90/100 | Writes a summary sheet into output workbooks showing pass/fail status per step |
| `turas_excel_escape.R` | 280 | Excel formula injection protection (6 functions) | 95/100 | OWASP CVE prevention; sanitises all user-supplied strings before writing to Excel cells |
| `turas_save_workbook_atomic.R` | 319 | Atomic file saving -- write to temp, rename on success (2 functions) | 92/100 | Prevents corrupt output files if process crashes mid-write; uses OS-level atomic rename |

---

## Architecture Diagram

The shared module is organised in a clean 3-layer dependency hierarchy. Higher layers depend on lower layers, never the reverse.

```
 +---------------------------------------------------------------------------+
 |                        import_all.R  (Master Loader)                      |
 |             Sources all files below in strict dependency order            |
 +---------------------------------------------------------------------------+
        |                         |                          |
        v                         v                          v
 +==================+  +====================+  +========================+
 |   LAYER 3        |  |   LAYER 3          |  |   LAYER 3              |
 |   Specialised    |  |   Specialised      |  |   Specialised          |
 +------------------+  +--------------------+  +------------------------+
 | formatting_utils |  | weights_utils      |  | hb_diagnostics         |
 | (249 lines)      |  | (213 lines)        |  | (597 lines)            |
 | 7 functions      |  | 5 functions        |  | 7 functions            |
 +------------------+  +--------------------+  +------------------------+
 | logging_utils    |  | template_styles    |
 | (132 lines)      |  | (425 lines)        |
 | 6 functions      |  | ~15 functions      |
 +==================+  +====================+
        |                         |
        v                         v
 +===================================================================+
 |                       LAYER 2: TRS Infrastructure                  |
 +-------------------------------------------------------------------+
 | console_capture (153)  | turas_log (189)    | trs_run_state (184)  |
 | trs_banner (124)       | trs_run_status_writer (195)              |
 | turas_excel_escape (280) | turas_save_workbook_atomic (319)       |
 +===================================================================+
        |
        v
 +===================================================================+
 |                    LAYER 1: Foundation (Core)                      |
 +-------------------------------------------------------------------+
 |  trs_refusal.R (891)    -->  validation_utils.R (491)             |
 |         |                          |                               |
 |         +-------> data_utils.R (294)   config_utils.R (359)       |
 +===================================================================+
```

**Dependency flow:**

- **Layer 1 (Foundation):** `trs_refusal.R` is the bedrock. `validation_utils.R` builds on TRS to provide input guards. `data_utils.R` and `config_utils.R` handle file I/O and config parsing.
- **Layer 2 (TRS Infrastructure):** These files extend the core TRS system with console capture, structured logging, run-state tracking, banners, status reporting, security (Excel escape), and robust file saving.
- **Layer 3 (Specialised):** Domain-specific utilities for formatting, weighting, MCMC diagnostics, progress logging, and Excel template styling. These are consumed by individual analytical modules as needed.
- **`import_all.R`** sits above all three layers as the single entry point. Every analytical module calls `source("modules/shared/lib/import_all.R")` to load the full shared infrastructure in the correct order.

---

## Quality Scoring Criteria

Each file is scored on a 100-point scale across five dimensions:

| Criterion | Weight | Description |
|-----------|-------:|-------------|
| **Correctness** | 30% | Does the code produce correct results? Are edge cases handled? Are statistical formulas accurate? |
| **TRS Compliance** | 20% | Does the code use structured refusals instead of `stop()`? Are all failure modes covered with actionable messages? |
| **Code Clarity** | 20% | Is the code readable and maintainable? Are functions under 100 lines? Are variable names descriptive? |
| **Documentation** | 15% | Does it have roxygen2 headers? Are parameters and return values documented? Are examples provided? |
| **Test Coverage** | 15% | Are there corresponding tests? Do they cover happy path, edge cases, and error conditions? |

**Score interpretation:**

| Range | Rating | Meaning |
|-------|--------|---------|
| 95-100 | Excellent | Production-hardened, comprehensive tests, exemplary documentation |
| 90-94 | Very Good | Solid production code, good coverage, minor documentation gaps |
| 85-89 | Good | Reliable, functional, some areas could be tightened |
| 80-84 | Adequate | Works correctly but may lack edge-case handling or full documentation |
| < 80 | Needs Work | Functional but requires improvement before production confidence |

**Module average: 90/100** -- The shared module is the most critical infrastructure in Turas and is maintained to a high standard. The two highest-scored files (`trs_refusal.R` at 95 and `turas_excel_escape.R` at 95) reflect their importance as the error handling backbone and security layer respectively.

---

*Last updated: 2026-03-08*
*Total: 17 R files | ~5,198 lines | ~130+ functions | 3 dependency layers*
