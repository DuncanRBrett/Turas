# Turas Improvement Plan: 7.5/10 → 10/10

## Executive Summary

This document outlines a comprehensive plan to elevate Turas from its current score of **7.5/10** to **10/10**. The improvements focus on the four dimensions scoring below 9/10:

| Dimension | Current | Target | Gap |
|-----------|---------|--------|-----|
| Code Organization | 6/10 | 10/10 | +4 |
| Maintainability | 6/10 | 10/10 | +4 |
| Test Coverage | 7/10 | 10/10 | +3 |
| Documentation | 8/10 | 10/10 | +2 |

The plan is structured in **four phases** with clear deliverables, success metrics, and no time estimates (you decide the pace).

---

## Phase 1: Foundation & Quick Wins

**Goal:** Establish architectural standards and address low-effort, high-impact items.

### 1.1 Create Architectural Decision Records (ADRs)

Create `/docs/adr/` directory with the following decision records:

```
/docs/adr/
├── 001-module-structure-standard.md
├── 002-shared-utilities-location.md
├── 003-file-naming-conventions.md
├── 004-testing-strategy.md
└── 005-error-handling-patterns.md
```

**ADR-001: Module Structure Standard**
- Standardize on **lib/** pattern for all modules (it's more descriptive than R/)
- Define required files per module:
  ```
  /modules/{module}/
  ├── README.md              # Module overview (REQUIRED)
  ├── USER_MANUAL.md         # End-user documentation
  ├── TECHNICAL_DOCS.md      # Developer documentation
  ├── run_{module}.R         # Headless runner
  ├── run_{module}_gui.R     # Shiny launcher (if applicable)
  └── lib/
      ├── main.R             # Entry point and orchestration
      ├── config.R           # Configuration handling
      ├── validation.R       # Input validation
      ├── [feature]_*.R      # Feature-specific files
      └── utils.R            # Module-specific utilities
  ```

**ADR-002: Shared Utilities Location**
- Deprecate `/shared/` (root level)
- Consolidate to `/modules/shared/lib/` as single source of truth
- Define import pattern for modules

### 1.2 Add Missing README.md Files

Create README.md for the two missing modules:

**`/modules/tabs/README.md`**
```markdown
# Tabs Module

## Overview
Cross-tabulation and survey data analysis engine.

## Quick Start
```r
source("run_tabs.R")
run_tabs("path/to/config.yaml")
```

## Architecture
- 16 library files (16,400+ lines)
- Primary entry: run_tabs.R → lib/run_crosstabs.R
- Key components: validation, weighting, ranking, excel_writer

## Dependencies
- Core: data.table, openxlsx
- Statistical: weights, survey

## Related Documentation
- USER_MANUAL.md - End-user guide
- TECHNICAL_DOCS.md - Developer reference
```

**`/modules/tracker/README.md`**
```markdown
# Tracker Module

## Overview
Time-series tracking and trend analysis for longitudinal studies.

## Quick Start
```r
source("run_tracker.R")
run_tracker("path/to/config.yaml")
```

## Architecture
- 16 R files at module root
- Primary components: trend_calculator.R, tracker_output.R
- Handles wave-over-wave comparisons and significance testing

## Dependencies
- Core: data.table, ggplot2
- Statistical: survey, stats

## Related Documentation
- USER_MANUAL.md - End-user guide
- TECHNICAL_DOCS.md - Developer reference
```

### 1.3 Consolidate Shared Utilities

**Step 1: Audit duplicated functions**

| Function | Locations | Action |
|----------|-----------|--------|
| `safe_numeric()` | 5 modules | Move to `/modules/shared/lib/data_utils.R` |
| `log_message()` | 4 modules | Move to `/modules/shared/lib/logging_utils.R` |
| `find_turas_root()` | 4 modules | Move to `/modules/shared/lib/config_utils.R` |
| `validate_config()` | 3 modules | Move to `/modules/shared/lib/validation_utils.R` |
| `format_pvalue()` | 3 modules | Move to `/modules/shared/lib/formatting_utils.R` |

**Step 2: Migrate root `/shared/` to `/modules/shared/lib/`**

| Source File | Target | Action |
|-------------|--------|--------|
| `/shared/config_utils.R` | `/modules/shared/lib/config_utils.R` | Merge (keep newer) |
| `/shared/formatting.R` | `/modules/shared/lib/formatting_utils.R` | New file |
| `/shared/weights.R` | `/modules/shared/lib/weights_utils.R` | New file |

**Step 3: Create single import mechanism**

Create `/modules/shared/lib/import_shared.R`:
```r
# Shared Utilities Loader
# Usage: source(file.path(find_turas_root(), "modules/shared/lib/import_shared.R"))

shared_lib_path <- dirname(sys.frame(1)$ofile)

source(file.path(shared_lib_path, "config_utils.R"))
source(file.path(shared_lib_path, "data_utils.R"))
source(file.path(shared_lib_path, "validation_utils.R"))
source(file.path(shared_lib_path, "logging_utils.R"))
source(file.path(shared_lib_path, "formatting_utils.R"))
source(file.path(shared_lib_path, "weights_utils.R"))

message("Turas shared utilities loaded successfully")
```

**Step 4: Update all modules to use shared import**

Replace duplicated function definitions with:
```r
# At top of module entry point
source(file.path(find_turas_root(), "modules/shared/lib/import_shared.R"))
```

### 1.4 Success Metrics - Phase 1

| Metric | Current | Target |
|--------|---------|--------|
| ADR documents | 0 | 5 |
| Modules with README.md | 8/10 | 10/10 |
| Shared utility locations | 2 | 1 |
| Duplicated utility functions | 5 | 0 |

---

## Phase 2: File Decomposition

**Goal:** Break large files into focused, single-responsibility modules.

### 2.1 Decompose `tracker/trend_calculator.R` (2,690 lines)

**Current responsibilities (analysis):**
1. Data loading and preparation
2. Trend calculation algorithms
3. Statistical significance testing
4. Period comparison logic
5. Output formatting

**Proposed split:**

| New File | Lines (est.) | Responsibility |
|----------|--------------|----------------|
| `lib/trend_data_loader.R` | ~400 | Data loading, validation, preparation |
| `lib/trend_algorithms.R` | ~600 | Core trend calculation algorithms |
| `lib/trend_significance.R` | ~500 | Statistical significance testing |
| `lib/trend_comparisons.R` | ~500 | Period-over-period comparisons |
| `lib/trend_calculator.R` | ~400 | Orchestration (keep name for backward compat) |
| `lib/trend_formatters.R` | ~290 | Output formatting helpers |

**Migration strategy:**
1. Create new files with extracted functions
2. Update `trend_calculator.R` to source new files
3. Run regression tests to verify no behavioral changes
4. Gradually update internal callers to use new file locations

### 2.2 Decompose `tracker/tracker_output.R` (2,178 lines)

**Proposed split:**

| New File | Lines (est.) | Responsibility |
|----------|--------------|----------------|
| `lib/output_excel.R` | ~600 | Excel generation and formatting |
| `lib/output_charts.R` | ~500 | Chart and visualization generation |
| `lib/output_tables.R` | ~400 | Data table formatting |
| `lib/output_summary.R` | ~400 | Summary statistics and rollups |
| `lib/tracker_output.R` | ~278 | Output orchestration |

### 2.3 Decompose `tabs/lib/validation.R` (1,838 lines)

**Proposed split:**

| New File | Lines (est.) | Responsibility |
|----------|--------------|----------------|
| `lib/validation_config.R` | ~400 | Config file validation |
| `lib/validation_data.R` | ~500 | Input data validation |
| `lib/validation_weights.R` | ~300 | Weight column validation |
| `lib/validation_variables.R` | ~400 | Variable definition validation |
| `lib/validation.R` | ~238 | Validation orchestration |

### 2.4 Decompose `tabs/lib/shared_functions.R` (1,779 lines)

**Problem:** File is misnamed ("shared" but tabs-specific) and too broad.

**Proposed split:**

| New File | Lines (est.) | Responsibility |
|----------|--------------|----------------|
| `lib/stats_calculations.R` | ~500 | Statistical calculation helpers |
| `lib/data_transformers.R` | ~400 | Data transformation utilities |
| `lib/label_handlers.R` | ~350 | Label and metadata handling |
| `lib/tabs_utils.R` | ~529 | Remaining tabs-specific utilities |

**Note:** Delete `shared_functions.R` after migration - the name is confusing.

### 2.5 File Size Guidelines

Add to ADR-003 (file naming conventions):

| Category | Max Lines | Rationale |
|----------|-----------|-----------|
| Orchestration files (main.R, run_*.R) | 500 | High-level coordination only |
| Feature files | 800 | Single feature focus |
| Utility files | 400 | Small, focused helpers |
| Test files | 600 | Keep tests readable |

### 2.6 Success Metrics - Phase 2

| Metric | Current | Target |
|--------|---------|--------|
| Files > 1,500 lines | 4 | 0 |
| Files > 1,000 lines | 10 | 4 (acceptable for complex features) |
| Average file size | ~510 lines | ~400 lines |

---

## Phase 3: Test Coverage Enhancement

**Goal:** Move from mock-based testing to comprehensive integration and unit testing.

### 3.1 Testing Strategy Overhaul

**Current state:**
- 67 regression assertions across 8 modules
- Heavy reliance on mock implementations
- Limited unit test coverage
- Coverage: ~8.7% (below 15-20% industry target)

**Target state:**
- 200+ test assertions
- Real module integration tests
- Comprehensive unit tests for utilities
- Coverage: 25%+ (exceeds industry target)

### 3.2 Test Infrastructure Improvements

**Create `/tests/framework/`:**

```
/tests/framework/
├── test_helpers.R         # Common test utilities
├── test_data_generators.R # Synthetic data generators
├── fixtures/              # Reusable test fixtures
│   ├── sample_survey.csv
│   ├── sample_config.yaml
│   └── expected_outputs/
└── mocks/                 # Controlled mock implementations
    └── mock_api.R
```

**`test_helpers.R` contents:**
```r
# Test assertion helpers
assert_data_frame_equal <- function(actual, expected, tolerance = 1e-6) { ... }
assert_file_exists <- function(path) { ... }
assert_no_warnings <- function(expr) { ... }

# Test data helpers
create_sample_survey <- function(n = 100, ...) { ... }
create_sample_config <- function(module, ...) { ... }

# Cleanup helpers
with_temp_dir <- function(expr) { ... }
with_clean_env <- function(expr) { ... }
```

### 3.3 Module-Specific Test Plans

#### Tabs Module (Priority: HIGH - most complex)

| Test Category | Tests Needed | Current | Target |
|---------------|--------------|---------|--------|
| Config validation | 10 | 2 | 10 |
| Data loading | 8 | 1 | 8 |
| Weighting engine | 15 | 3 | 15 |
| Cross-tabulation | 20 | 2 | 20 |
| Significance testing | 12 | 2 | 12 |
| Excel output | 8 | 0 | 8 |
| **Total** | **73** | **10** | **73** |

**Key test files to create:**
- `test_tabs_weighting.R` - Weighting calculations and edge cases
- `test_tabs_crosstabs.R` - Cross-tabulation accuracy
- `test_tabs_significance.R` - Statistical significance algorithms
- `test_tabs_output.R` - Output format validation

#### Tracker Module (Priority: HIGH)

| Test Category | Tests Needed | Current | Target |
|---------------|--------------|---------|--------|
| Trend calculations | 15 | 3 | 15 |
| Period comparisons | 12 | 2 | 12 |
| Significance testing | 10 | 2 | 10 |
| Output generation | 8 | 4 | 8 |
| **Total** | **45** | **11** | **45** |

#### Shared Utilities (Priority: HIGH - foundational)

| Utility File | Tests Needed | Current | Target |
|--------------|--------------|---------|--------|
| config_utils.R | 12 | 4 | 12 |
| data_utils.R | 15 | 3 | 15 |
| validation_utils.R | 18 | 5 | 18 |
| logging_utils.R | 8 | 2 | 8 |
| formatting_utils.R | 10 | 3 | 10 |
| weights_utils.R | 12 | 4 | 12 |
| **Total** | **75** | **21** | **75** |

### 3.4 Integration Test Suite

Create `/tests/integration/` for end-to-end module testing:

```r
# /tests/integration/test_tabs_e2e.R
test_that("tabs produces correct output for simple survey", {
  # Setup
  config <- create_sample_config("tabs")
  data <- create_sample_survey(n = 500)

  # Execute
  result <- run_tabs(config, data)

  # Verify
  expect_true(file.exists(result$output_path))
  expect_equal(nrow(result$summary), expected_rows)
  expect_true(all(result$weights_applied))
})
```

### 3.5 Continuous Testing Setup

Create `/tests/run_all_tests.R`:
```r
#!/usr/bin/env Rscript
# Master test runner with coverage reporting

library(testthat)
library(covr)

# Run all tests
test_results <- test_dir("tests/testthat", reporter = "summary")
integration_results <- test_dir("tests/integration", reporter = "summary")
regression_results <- test_dir("tests/regression", reporter = "summary")

# Generate coverage report
coverage <- package_coverage(
  path = ".",
  type = "tests",
  code = 'testthat::test_dir("tests")'
)

# Output summary
cat("\n=== TEST SUMMARY ===\n")
cat(sprintf("Unit tests: %d passed, %d failed\n",
    sum(test_results$passed), sum(test_results$failed)))
cat(sprintf("Integration tests: %d passed, %d failed\n",
    sum(integration_results$passed), sum(integration_results$failed)))
cat(sprintf("Coverage: %.1f%%\n", percent_coverage(coverage)))
```

### 3.6 Success Metrics - Phase 3

| Metric | Current | Target |
|--------|---------|--------|
| Total test assertions | 67 | 200+ |
| Test coverage | 8.7% | 25%+ |
| Integration tests | 0 | 8 (one per module) |
| Mock dependencies | High | Minimal |

---

## Phase 4: Documentation Excellence

**Goal:** Achieve comprehensive, consistent, and maintainable documentation.

### 4.1 Documentation Audit

**Current state:**
- 56 markdown files across the project
- Good USER_MANUAL.md coverage
- Missing: contribution guidelines, changelog, architecture diagrams

### 4.2 Root-Level Documentation

Create/update these files:

**`/CONTRIBUTING.md`**
```markdown
# Contributing to Turas

## Code Standards
- Follow ADRs in /docs/adr/
- Maximum file size: 800 lines (feature files)
- All new code requires tests

## Pull Request Process
1. Create feature branch from main
2. Run full test suite: `Rscript tests/run_all_tests.R`
3. Update relevant documentation
4. Submit PR with description of changes

## Code Review Checklist
- [ ] No duplicated utility functions
- [ ] File size under limits
- [ ] Tests included and passing
- [ ] Documentation updated
```

**`/CHANGELOG.md`**
```markdown
# Changelog

All notable changes to Turas will be documented in this file.

## [Unreleased]
### Added
- ADR documentation system
- Consolidated shared utilities
- Enhanced test coverage

### Changed
- Decomposed large files in Tracker and Tabs modules
- Standardized module structure

### Deprecated
- /shared/ directory (use /modules/shared/lib/)
```

**`/docs/ARCHITECTURE.md`**
```markdown
# Turas Architecture

## System Overview
[Include ASCII diagram or reference to diagram file]

## Module Dependency Graph
[Show inter-module dependencies]

## Data Flow
[Document how data moves through the system]

## Extension Points
[How to add new modules or features]
```

### 4.3 Module Documentation Standardization

Every module must have:

| File | Purpose | Template |
|------|---------|----------|
| `README.md` | Quick start and overview | See Phase 1 |
| `USER_MANUAL.md` | End-user guide | Exists for most |
| `TECHNICAL_DOCS.md` | Developer reference | Exists for most |
| `CHANGELOG.md` | Module-specific changes | New requirement |

### 4.4 Inline Documentation Standards

Add to ADR-003:

```r
# Function documentation standard
#' Calculate weighted mean with confidence interval
#'
#' @param x Numeric vector of values
#' @param weights Numeric vector of weights (same length as x)
#' @param conf_level Confidence level (default 0.95)
#' @return List with mean, lower, upper bounds
#' @examples
#' weighted_mean_ci(c(1,2,3), c(0.5, 0.3, 0.2))
weighted_mean_ci <- function(x, weights, conf_level = 0.95) {
  # Implementation
}
```

### 4.5 Documentation Maintenance Process

Create `/docs/DOCUMENTATION_GUIDE.md`:
- When to update docs (any API change, new feature, bug fix)
- Documentation review checklist
- How to build and validate docs

### 4.6 Success Metrics - Phase 4

| Metric | Current | Target |
|--------|---------|--------|
| Modules with complete doc set | 6/10 | 10/10 |
| Root documentation files | 3 | 8 |
| Documented public functions | ~60% | 100% |
| ADR documents | 0 | 5+ |

---

## Implementation Roadmap

### Phase Order and Dependencies

```
Phase 1 (Foundation) ─────────────────────────┐
    │                                         │
    ├── 1.1 ADRs (no dependencies)           │
    ├── 1.2 README.md (no dependencies)      │
    └── 1.3 Consolidate shared (needs ADRs)  │
                                              │
Phase 2 (Decomposition) ◄─────────────────────┘
    │   (depends on Phase 1 for standards)
    │
    ├── 2.1 Tracker files
    ├── 2.2 Tabs files (can parallelize)
    └── 2.3 Guidelines
              │
Phase 3 (Testing) ◄───────────────────────────┘
    │   (depends on stable file structure)
    │
    ├── 3.1 Test infrastructure
    ├── 3.2 Unit tests
    └── 3.3 Integration tests
              │
Phase 4 (Documentation) ◄─────────────────────┘
    │   (depends on finalized architecture)
    │
    └── Complete documentation suite
```

### Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking changes during decomposition | High | Comprehensive regression tests before changes |
| Test infrastructure delays | Medium | Start with simple test helpers, iterate |
| Documentation becomes stale | Medium | Include doc updates in PR checklist |
| Scope creep | High | Strict adherence to phase deliverables |

---

## Score Projection

### After Phase 1
| Dimension | Score |
|-----------|-------|
| Code Organization | 7/10 (+1) |
| Maintainability | 7/10 (+1) |
| Documentation | 9/10 (+1) |

**Overall: 8.0/10**

### After Phase 2
| Dimension | Score |
|-----------|-------|
| Code Organization | 9/10 (+2) |
| Maintainability | 8/10 (+1) |

**Overall: 8.5/10**

### After Phase 3
| Dimension | Score |
|-----------|-------|
| Test Coverage | 9/10 (+2) |
| Maintainability | 9/10 (+1) |

**Overall: 9.3/10**

### After Phase 4
| Dimension | Score |
|-----------|-------|
| Documentation | 10/10 (+1) |
| Code Organization | 10/10 (+1) |
| Maintainability | 10/10 (+1) |
| Test Coverage | 10/10 (+1) |

**Overall: 10/10**

---

## Appendix A: File Inventory for Decomposition

### Tracker Module - Current Structure
```
/modules/tracker/
├── trend_calculator.R      (2,690 lines) → DECOMPOSE
├── tracker_output.R        (2,178 lines) → DECOMPOSE
├── tracker_core.R          (892 lines)
├── tracker_config.R        (654 lines)
├── tracker_validation.R    (543 lines)
├── tracker_data_loader.R   (487 lines)
├── tracker_significance.R  (423 lines)
├── tracker_charts.R        (398 lines)
├── tracker_export.R        (356 lines)
├── tracker_utils.R         (312 lines)
├── run_tracker.R           (234 lines)
├── run_tracker_gui.R       (189 lines)
└── [remaining files]
```

### Tabs Module - Current Structure
```
/modules/tabs/
├── lib/
│   ├── validation.R          (1,838 lines) → DECOMPOSE
│   ├── shared_functions.R    (1,779 lines) → DECOMPOSE
│   ├── ranking.R             (1,615 lines)
│   ├── weighting.R           (1,490 lines)
│   ├── excel_writer.R        (1,477 lines)
│   ├── run_crosstabs.R       (1,343 lines)
│   ├── standard_processor.R  (1,279 lines)
│   ├── summary_builder.R     (987 lines)
│   └── [remaining files]
├── run_tabs.R
└── run_tabs_gui.R
```

---

## Appendix B: Shared Utility Consolidation Map

### Functions to Migrate

| Function | From | To | Notes |
|----------|------|-----|-------|
| `safe_numeric()` | tabs, tracker, confidence, pricing, maxdiff | `data_utils.R` | Merge implementations |
| `log_message()` | tabs, tracker, segment, keydriver | `logging_utils.R` | Use logging_utils version |
| `find_turas_root()` | tabs, tracker, confidence, segment | `config_utils.R` | Already in config_utils |
| `validate_required_columns()` | tabs, tracker, confidence | `validation_utils.R` | New consolidated version |
| `format_percentage()` | tabs, confidence, pricing | `formatting_utils.R` | Standardize format |
| `calculate_effective_n()` | tabs, tracker, segment | `weights_utils.R` | Statistical accuracy critical |

---

## Appendix C: Test Coverage Targets by Module

| Module | Current Tests | Target Tests | Priority |
|--------|--------------|--------------|----------|
| Tabs | 10 | 73 | HIGH |
| Tracker | 11 | 45 | HIGH |
| Shared | 21 | 75 | HIGH |
| Confidence | 12 | 30 | MEDIUM |
| KeyDriver | 5 | 25 | MEDIUM |
| Conjoint | 9 | 25 | MEDIUM |
| Segment | 7 | 25 | MEDIUM |
| Pricing | 7 | 20 | MEDIUM |
| AlchemerParser | 6 | 15 | LOW |
| MaxDiff | 5 | 15 | LOW |

**Total: 93 → 348 test assertions**

---

## Sign-Off

This improvement plan provides a clear path from 7.5/10 to 10/10 through:

1. **Architectural standardization** (Phase 1)
2. **Code decomposition** (Phase 2)
3. **Test coverage enhancement** (Phase 3)
4. **Documentation excellence** (Phase 4)

Each phase builds on the previous, with clear success metrics and deliverables. The statistical foundations remain untouched - they're already excellent.

---

*Document created: 2024*
*Last updated: 2024*
*Review status: DRAFT - Awaiting stakeholder approval*
