# Turas Conjoint Module - Technical Documentation

**Version:** 3.1.0
**Last Updated:** March 2026
**Audience:** Developers, Technical Maintainers

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Code Structure](#code-structure)
3. [Data Flow](#data-flow)
4. [Core Components](#core-components)
5. [Critical Bug Fixes](#critical-bug-fixes)
6. [Multi-Respondent Data Handling](#multi-respondent-data-handling)
7. [Testing Framework](#testing-framework)
8. [Error Handling](#error-handling)
9. [Performance Considerations](#performance-considerations)
10. [Code Style Guidelines](#code-style-guidelines)
11. [Maintenance Procedures](#maintenance-procedures)
12. [Dependencies](#dependencies)
13. [Extension Points](#extension-points)

---

## Architecture Overview

### Design Principles

1. **Modularity:** Numbered files with single responsibility
2. **Robustness:** Multiple estimation fallbacks, pre-flight validation
3. **Testability:** Functions designed for unit testing with 16 test files
4. **TRS v1.0 Compliance:** All errors go through the Turas Refusal System (no `stop()` calls)
5. **Backward Compatibility:** Handle various config formats, autodetect headers
6. **Version Consistency:** `get_conjoint_version()` returns `"3.1.0"` and is used throughout

### Module Structure

```
modules/conjoint/
├── R/                                # 20 R source files
│   ├── 00_main.R                     # Main orchestration, module loader
│   ├── 00_guard.R                    # TRS guard layer (conjoint_refuse, refusal handler)
│   ├── 00_preflight.R                # Pre-flight module validation (files, packages, JS, TRS)
│   ├── 01_config.R                   # Configuration loading (with autodetect headers)
│   ├── 02_data.R                     # Data loading, validation, choice-set size checks
│   ├── 03_estimation.R               # Multi-method estimation dispatch (MNL, clogit, rating)
│   ├── 04_utilities.R                # Utility calculations, importance, diagnostics
│   ├── 05_alchemer_import.R          # Alchemer CBC direct import and config generation
│   ├── 05_simulator.R                # Market simulation (logit, first_choice, RFC, purchase likelihood, CIs)
│   ├── 06_interactions.R             # Config-driven interaction effects
│   ├── 07_output.R                   # Excel output (8-14 sheets depending on method)
│   ├── 08_market_simulator.R         # Excel simulator builder
│   ├── 09_none_handling.R            # None/opt-out detection and handling
│   ├── 10_best_worst.R               # Best-worst scaling (base R)
│   ├── 11_hierarchical_bayes.R       # HB estimation (bayesm MCMC)
│   ├── 12_config_template.R          # Config template generator (branded, multi-method)
│   ├── 13_latent_class.R             # Latent class analysis (mixture log-likelihood for BIC/AIC)
│   ├── 14_willingness_to_pay.R       # WTP estimation (delta-method CIs)
│   ├── 15_product_optimizer.R        # Product optimization (exhaustive + greedy)
│   └── 99_helpers.R                  # Shared utilities, formatting, get_conjoint_version()
├── lib/
│   ├── html_report/                  # HTML analysis report generator (7 R files + 7 JS files)
│   │   ├── 00_html_guard.R           # Input validation for HTML generation
│   │   ├── 01_data_transformer.R     # Transform conjoint results to HTML data model
│   │   ├── 02_table_builder.R        # HTML tables for each panel
│   │   ├── 03_page_builder.R         # Full page assembly (CSS, header, panels, JS, .html_esc)
│   │   ├── 04_html_writer.R          # Write final HTML to disk (UTF-8, raw byte replacement)
│   │   ├── 05_chart_builder.R        # Inline SVG chart generation (.svg_esc for escaping)
│   │   ├── 99_html_report_main.R     # Top-level orchestrator
│   │   └── js/                       # 7 JavaScript modules
│   │       ├── conjoint_navigation.js  # Tab nav, mode switching, slides, per-mode annotations
│   │       ├── conjoint_export.js      # CSV/Excel/PNG/slide export
│   │       ├── conjoint_pins.js        # Snapshot-based pin system (SVG pin icons)
│   │       ├── conjoint_charts.js      # SVG chart rendering (bar + dot plot toggle)
│   │       ├── simulator_engine.js     # Share prediction (logit, RFC, purchase likelihood, scale factor)
│   │       ├── simulator_ui.js         # Product config, revenue mode, controls render-once pattern
│   │       └── simulator_charts.js     # Simulator SVG bar rendering
│   └── html_simulator/              # Standalone HTML simulator
│       ├── 00_simulator_guard.R
│       ├── 01_simulator_data_transformer.R
│       ├── 02_simulator_page_builder.R
│       ├── 99_simulator_main.R
│       └── js/
│           ├── simulator_engine.js
│           ├── simulator_charts.js
│           └── simulator_ui.js
├── tests/
│   ├── testthat/                     # 16 test files (unit, integration, guard, HB, CI, preflight)
│   └── fixtures/                     # Synthetic test data generators
├── docs/                             # This documentation
└── run_conjoint_gui.R                # Shiny GUI launcher
```

**Total:** ~20,300+ lines across R + JS

---

## Code Structure

### File Responsibilities

#### 99_helpers.R

Utility functions loaded first (sourced before all other component files):

```r
format_number()           # Number formatting
parse_comma_list()        # Parse comma-separated values
safe_divide()             # Division with zero handling
is_valid_numeric()        # Numeric validation
create_error()            # Structured error message builder
get_conjoint_version()    # Returns "3.1.0" — single source of truth for version
`%||%`                    # Null coalescing operator
```

**Dependencies:** Loads shared utilities from `modules/shared/lib/data_utils.R` when available; retains local fallbacks for backward compatibility.

---

#### 00_preflight.R

Pre-flight validation system. Validates module readiness before analysis:

```r
conjoint_preflight(verbose = TRUE, module_dir = NULL) -> list (TRS-compliant)

# Checks performed:
# 1. R source files — verifies all 20 expected files
# 2. JS files — verifies all 7 JavaScript modules
# 3. HTML report R files — verifies all 7 report generator files
# 4. Required packages — mlogit, survival, openxlsx, data.table, jsonlite
# 5. Optional packages — bayesm
# 6. JS syntax — runs node --check if Node.js is available
# 7. TRS infrastructure — confirms conjoint_refuse and conjoint_with_refusal_handler are loaded
```

Can be invoked standalone or via `run_conjoint_analysis(..., run_preflight = TRUE)`.

---

#### 00_guard.R

TRS v1.0 integration layer:

```r
conjoint_refuse()                  # Module-specific TRS refusal wrapper
conjoint_with_refusal_handler()    # Wraps main analysis with TRS handling
conjoint_guard_init()              # Initialize guard state with conjoint fields
guard_check_data_exists()          # Validate data frame exists (renamed from validate_conjoint_data guard)
```

Sources shared TRS infrastructure from `modules/shared/lib/trs_refusal.R`. Falls back to a local implementation if shared lib is not found.

---

#### 01_config.R

Configuration loading and validation:

```r
load_conjoint_config(config_file, verbose = TRUE) -> list
validate_conjoint_config(config) -> list

# Returns:
list(
  settings = data.frame(...),
  attributes = data.frame(...),
  validation = list(passed, errors, warnings)
)
```

Supports autodetect headers (branded templates with title rows above the data).

---

#### 02_data.R

Data loading, validation, and choice-set size validation:

```r
load_conjoint_data(data_file, config, verbose = TRUE) -> list
validate_conjoint_data(data, config) -> list

# Returns:
list(
  data = data.frame(...),
  n_respondents = integer,
  n_choice_sets = integer,
  has_none = logical,
  validation = list(...),
  choice_set_info = list(mean, min, max, mode)  # alternatives per set
)
```

Validates choice-set size consistency and warns on unbalanced designs.

---

#### 03_estimation.R

Model estimation with multi-method dispatch:

```r
estimate_choice_model(data_list, config, verbose = TRUE) -> list
estimate_with_mlogit(data_list, config, verbose) -> list
estimate_with_clogit(data_list, config, verbose) -> list

# Returns:
list(
  model = mlogit/clogit object,
  coefficients = numeric(...),
  vcov = matrix(...),
  convergence = list(converged, message),
  method = "mlogit" or "clogit"
)
```

---

#### 05_simulator.R

Market simulation with four methods plus bootstrap CIs:

```r
predict_shares(products, utilities, method, ...)  -> data.frame
predict_shares_with_ci(products, individual_betas, method,
                       n_bootstrap, confidence_level, ...) -> data.frame
# Bootstrap CIs: resamples respondents with replacement from HB betas,
# re-computes shares per draw, returns percentile intervals.
```

Supports logit, first_choice, RFC, and purchase_likelihood simulation methods.

---

#### 11_hierarchical_bayes.R

Individual-level HB estimation via bayesm MCMC:

```r
estimate_hb(data_list, config, verbose) -> list
# Returns individual betas, convergence diagnostics, respondent quality (RLH)
```

---

#### 13_latent_class.R

Latent class analysis with proper model selection:

```r
estimate_latent_class(data_list, config, verbose) -> list
compute_mixture_log_likelihood(model, data, ...) -> numeric
# Uses mixture log-likelihood (not individual posterior means) for BIC/AIC:
#   LL_mixture = sum_i log( sum_k pi_k * exp(LL_ik) )
# This gives DIFFERENT LL values for different K, enabling proper model selection.
```

---

#### 14_willingness_to_pay.R

WTP estimation with confidence intervals:

```r
calculate_wtp(utilities, config) -> data.frame
# Auto-computed when price attribute detected (via wtp_price_attribute config
# or auto-detected from attribute names containing "price", "cost", or "fee")
# Delta-method CIs
```

WTP is auto-computed in the main analysis flow when a price attribute is detected, not just as a standalone call.

---

#### 07_output.R

Excel workbook generation (8-14 sheets depending on method):

```r
write_conjoint_output(utilities, importance, diagnostics,
                      model_result, config, data_info, output_file) -> NULL
```

---

#### 08_market_simulator.R

Interactive Excel simulator:

```r
create_market_simulator(wb, utilities, config) -> workbook
```

---

#### HTML Report Architecture (lib/html_report/)

Seven R files forming a layered architecture:

| Layer | File | Purpose |
|-------|------|---------|
| Guard | `00_html_guard.R` | Validate inputs before HTML generation |
| Data | `01_data_transformer.R` | Transform conjoint results into HTML data model |
| Tables | `02_table_builder.R` | Build HTML tables for each panel |
| Page | `03_page_builder.R` | Full page assembly: CSS, header, panels, JS injection; defines `.html_esc()` |
| Writer | `04_html_writer.R` | Write final HTML to disk with UTF-8 handling (raw byte replacement for broken locales) |
| Charts | `05_chart_builder.R` | Inline SVG chart generation; defines `.svg_esc()` for special character escaping |
| Orchestrator | `99_html_report_main.R` | Top-level entry point |

Seven JavaScript modules handle client-side interactivity:

| File | Purpose |
|------|---------|
| `conjoint_navigation.js` | Tab navigation, mode switching, slides, per-mode sticky annotations |
| `conjoint_export.js` | CSV, Excel, PNG, and slide export |
| `conjoint_pins.js` | Snapshot-based pin system with SVG pushpin icons |
| `conjoint_charts.js` | SVG chart rendering with bar/dot plot toggle, chart type persistence |
| `simulator_engine.js` | Share prediction (logit, RFC, purchase likelihood), scale factor, sensitivity |
| `simulator_ui.js` | Product config dropdowns, revenue mode, editable customer count; controls render-once pattern |
| `simulator_charts.js` | Simulator SVG bar rendering |

---

## Data Flow

```
CONFIG FILE (Excel)
    |
load_conjoint_config()
    |
[Validated Config Object]
    |
load_conjoint_data()          # with choice-set size validation
    |
[Data List with Validation]
    |
estimate_choice_model()
    |-- estimate_with_mlogit()    [Primary]
    |-- estimate_with_clogit()    [Fallback]
    |-- estimate_hb()             [HB individual-level]
    |-- estimate_latent_class()   [Latent class segmentation]
    +-- estimate_with_ols()       [Rating-based]
    |
[Model Result]
    |
calculate_utilities()
    |
[Utilities + Importance]
    |
+-- calculate_wtp()               [Auto when price attribute detected]
+-- predict_shares_with_ci()       [Bootstrap CIs from HB betas]
+-- optimize_products()            [Exhaustive or greedy]
    |
write_conjoint_output()
    |
[Excel Workbook (8-14 sheets)]
    |
+-- generate_html_report()         [Self-contained HTML with simulator]
+-- generate_html_simulator()      [Standalone HTML simulator]
```

---

## Core Components

### Unique Choice Set Identification

**Critical Pattern:** Always identify choice occasions by BOTH respondent and choice_set:

```r
# CORRECT: Unique choice occasions
unique_sets <- data %>%
  select(!!sym(respondent_id_column), !!sym(choice_set_column)) %>%
  distinct()

# WRONG: Just choice_set (fails for multi-respondent data)
unique_sets <- unique(data[[choice_set_column]])
```

### mlogit Data Preparation

```r
# Create unique chid combining respondent + choice_set
data$chid <- as.numeric(as.factor(
  paste(data[[respondent_id_column]],
        data[[choice_set_column]],
        sep = "_")
))

# Prepare for mlogit
data_mlogit <- dfidx(
  data,
  choice = "chosen",
  idx = list(c("chid", "alt")),
  idnames = c("chid", "alt")
)
```

### Hit Rate Calculation

```r
# Get fitted probability matrix
fitted_mat <- fitted(model, outcome = FALSE)
# Dimension: (n_choice_sets x n_alternatives)

# Verify it's a matrix
if (!is.matrix(fitted_mat)) {
  # TRS refusal instead of stop()
  return(conjoint_refuse(...))
}

# Row sums should all be ~1.0
# Predicted choice per choice set
predicted <- max.col(fitted_mat, ties.method = "first")

# Actual choice per choice set
actual <- tapply(data$chosen, data$chid, function(x) which(x)[1])

# Hit rate
hit_rate <- sum(predicted == actual, na.rm = TRUE) / length(actual)
```

### Simulator Scale Factor

The HTML simulator includes a configurable scale factor (exponent, 0.1-3.0) that multiplies all utilities before computing shares. Values >1.0 amplify differences between products; values <1.0 compress them. This enables calibrating simulated shares to observed market data.

### Simulator Controls Render-Once Pattern

Simulator product configuration controls (dropdowns, sliders) are rendered once on initialization. When the user changes a simulation method or other setting, only the chart area updates -- the controls are not re-rendered. This fixes a bug where dropdown selections and slider positions would reset on every chart update.

### Snapshot-Based Pin System

Simulator pins create unique snapshots of the current state. Multiple views can be pinned simultaneously (e.g., two different market share scenarios). Each pin captures a full snapshot of product configurations, method, scale factor, and results. SVG pushpin icons (not emojis) are used for cross-platform rendering consistency.

### Per-Mode Sticky Annotations

The simulator maintains independent annotation text areas for each mode (Market Shares, Revenue, Sensitivity, Source of Volume). Switching modes preserves each mode's notes independently.

### SVG Text Escaping

`.svg_esc()` (defined in `05_chart_builder.R`) escapes special characters (`&`, `<`, `>`, `"`, `'`) in attribute names and level labels before embedding them in SVG markup. This prevents malformed charts when data contains characters like ampersands.

### UTF-8 HTML Escaping

`.html_esc()` (defined in `03_page_builder.R`) escapes HTML entities. The HTML writer (`04_html_writer.R`) uses raw byte replacement to handle broken locale scenarios where R's encoding functions fail on non-ASCII characters.

### Print CSS

Body classes enable targeted printing of pinned items and custom slides. The print stylesheet hides navigation and interactive controls, showing only the content panels that are relevant for the selected print mode.

---

## Critical Bug Fixes

### Bug 1: mlogit Hit Rate Matrix (Fixed 2025-11-26)

**Problem:** Hit rate stuck at ~34% despite good model fit

**Root Cause:** `fitted(model, outcome = FALSE)` returns a matrix, not vector

**Solution:**
```r
# WRONG
fitted_probs <- fitted(model, outcome = FALSE)  # Treated as vector
predicted <- tapply(fitted_probs, chid, which.max)

# CORRECT
fitted_mat <- fitted(model, outcome = FALSE)  # Matrix
predicted <- max.col(fitted_mat, ties.method = "first")
```

---

### Bug 2: Multi-Respondent Validation (Fixed 2025-11-27)

**Problem:** Validation failing for valid multi-respondent data

**Root Cause:** Grouped by choice_set_column only

**Solution:**
```r
# WRONG
chosen_per_set <- data %>%
  group_by(choice_set_column) %>%
  summarise(n_chosen = sum(chosen))

# CORRECT
chosen_per_set <- data %>%
  group_by(respondent_id_column, choice_set_column) %>%
  summarise(n_chosen = sum(chosen))
```

---

### Bug 3: mlogit Unique chid (Fixed 2025-11-27)

**Problem:** "indexes don't define unique observations"

**Root Cause:** chid only used choice_set_id

**Solution:**
```r
# WRONG
data$chid <- data[[choice_set_column]]

# CORRECT
data$chid <- as.numeric(as.factor(
  paste(data[[respondent_id_column]],
        data[[choice_set_column]],
        sep = "_")
))
```

---

### Bug 4: Market Simulator Blank Products (Fixed 2025-11-27)

**Problem:** Blank products showing non-zero share

**Root Cause:** exp(0) = 1 included in denominator

**Solution:**
```r
# Excel formula excludes zero-utility products
=IF(utility=0, 0, exp(U)/SUMIF(utilities<>0, exp_utilities)*100)
```

---

### Bug 5: GUI Module Loading (Fixed 2025-11-29)

**Problem:** "argument is of length zero" when launching from GUI

**Root Cause:** getSrcDirectory() fails in Shiny context

**Solution:** Robust directory detection with multiple fallback strategies -- walks the source frame stack, tries getSrcDirectory, then falls back to working directory detection with validation.

---

### Bug 6: Simulator Dropdown/Slider Reset (Fixed v3.1.0)

**Problem:** Product configuration dropdowns and sliders resetting when changing simulation method or updating charts.

**Root Cause:** Controls were re-rendered on every chart update.

**Solution:** Controls render once on initialization; chart area updates separately. The render-once pattern in `simulator_ui.js` splits control setup from chart redraw.

---

### Bug 7: conjoint_status_refuse Parameter Mismatch (Fixed v3.1.0)

**Problem:** `conjoint_refuse()` calls failing due to parameter name mismatch between the guard layer and the shared TRS infrastructure.

**Solution:** Corrected parameter names to align with `turas_refuse()` signature.

---

### Bug 8: Guard Function Shadowing (Fixed v3.1.0)

**Problem:** `validate_conjoint_data()` in `00_guard.R` shadowed the same function name in `02_data.R`.

**Solution:** Renamed guard-layer function to `guard_check_data_exists()` to avoid namespace collision. The `02_data.R` version retains the `validate_conjoint_data()` name for its detailed data validation logic.

---

### Bug 9: LC Model Selection with Individual Posterior Means (Fixed v3.1.0)

**Problem:** BIC/AIC comparisons across latent class solutions were unreliable because log-likelihood was computed from individual posterior means, which gives the same value regardless of K.

**Solution:** Implemented mixture log-likelihood (`compute_mixture_log_likelihood()`) that sums `log( sum_k pi_k * exp(LL_ik) )` across respondents. This produces different LL values for different K, enabling proper BIC/AIC model selection.

---

## Multi-Respondent Data Handling

### Key Principle

`(respondent_id, choice_set_id)` uniquely identifies a choice occasion.

### Data Structure

```
resp_id | choice_set_id | alt_id | chosen
--------|---------------|--------|-------
   1    |       1       |   1    |   0
   1    |       1       |   2    |   1      <- Resp 1, Set 1
   1    |       2       |   1    |   1      <- Resp 1, Set 2
   2    |       1       |   1    |   1      <- Resp 2, Set 1 (DIFFERENT)
   2    |       1       |   2    |   0
```

### Critical Operations

All these operations MUST group by both columns:

1. **Validation:** Exactly one chosen per (resp, set)
2. **Hit Rate:** Unique (resp, set) combinations
3. **Chance Rate:** Average alternatives per (resp, set)
4. **mlogit chid:** Paste(resp, set) for unique identifier
5. **Choice-set size validation:** Count alternatives per (resp, set)

---

## Testing Framework

### Test Structure

```
tests/testthat/
├── test_bws.R                 # Best-worst scaling tests
├── test_config.R              # Configuration loading and validation
├── test_edge_cases.R          # Edge cases and boundary conditions
├── test_estimation.R          # MNL/clogit model fitting
├── test_guard_fixes.R         # TRS guard layer and parameter fixes
├── test_hb_estimation.R       # Hierarchical Bayes estimation
├── test_html_report.R         # HTML report generation (207+ assertions)
├── test_html_simulator.R      # Standalone HTML simulator
├── test_integration_mnl.R     # End-to-end MNL integration
├── test_interactions.R        # Interaction effects
├── test_optimizer.R           # Product optimization
├── test_preflight.R           # Pre-flight check system
├── test_simulation.R          # Market simulation methods
├── test_simulator_ci.R        # Bootstrap CI on simulated shares
├── test_utilities.R           # Utility calculation and importance
└── test_wtp.R                 # Willingness-to-pay estimation
```

### Running Tests

```r
# Run all conjoint tests
testthat::test_dir("modules/conjoint/tests/testthat")

# Run specific test file
testthat::test_file("modules/conjoint/tests/testthat/test_estimation.R")

# Run with coverage
covr::package_coverage(
  type = "tests",
  code = "testthat::test_dir('modules/conjoint/tests/testthat')"
)
```

### Test Categories

- **Guard & TRS** -- Refusal system, parameter validation, guard_check_data_exists
- **Pre-flight** -- File presence, package availability, JS syntax, TRS infrastructure
- **Config** -- Loading, validation, autodetect headers
- **Data** -- Validation logic, choice-set size checks
- **Estimation** -- MNL, clogit, HB, latent class model fitting
- **Utilities** -- Calculation, importance, zero-centering
- **Simulation** -- All four methods, scale factor, CIs
- **WTP** -- Delta-method CIs, auto-detection
- **HTML Report** -- Page building, chart generation, SVG escaping (207+ assertions)
- **HTML Simulator** -- Standalone simulator generation
- **Optimizer** -- Exhaustive and greedy product optimization
- **Integration** -- End-to-end MNL pipeline
- **Edge Cases** -- Boundaries, NAs, empty data, single-attribute designs

### Writing Regression Tests

After fixing a bug, add a regression test:

```r
test_that("hit rate uses fitted matrix, not vector", {
  # Setup
  data <- create_test_data()
  model_result <- estimate_with_mlogit(data, config, verbose = FALSE)

  # Calculate hit rate
  hit_rate <- calculate_hit_rate(model_result, data$data, config)

  # Assert
  expect_true(hit_rate > 0.5,
              info = sprintf("Hit rate %.1f%% too low", hit_rate * 100))

  # Verify fitted() returns matrix
  fitted_mat <- fitted(model_result$model, outcome = FALSE)
  expect_true(is.matrix(fitted_mat))
  expect_true(all(abs(rowSums(fitted_mat) - 1) < 1e-6))
})
```

---

## Error Handling

### Strategy (TRS v1.0)

1. **Configuration Errors:** TRS refusal with actionable `how_to_fix` + console output
2. **Data Errors:** TRS refusal with specific row/column info
3. **Estimation Errors:** Try fallback method, TRS refusal if all methods fail
4. **Output Errors:** Log warning, continue where possible
5. **Pre-flight Errors:** TRS refusal with checklist of failing items

### TRS Refusal Pattern

All `stop()` calls have been replaced with TRS-compliant refusals:

```r
# OLD (removed in v3.1.0):
stop(sprintf("[MODULE] Error: %s", error_msg))

# NEW (v3.1.0):
conjoint_refuse(
  code = "DATA_INVALID_CHOICE_SET",
  title = "Invalid Choice Set Configuration",
  problem = sprintf("Choice set %d has %d alternatives, expected %d.",
                    set_id, actual, expected),
  why_it_matters = "mlogit requires consistent choice set structures.",
  how_to_fix = c(
    "Check your data for missing alternatives in the flagged choice sets.",
    "Run validate_conjoint_data() for detailed diagnostics."
  )
)
```

The `conjoint_refuse()` wrapper formats the error for console visibility (critical for Shiny debugging) and then calls the shared `turas_refuse()` infrastructure.

### Fallback Logic

```r
estimate_choice_model <- function(data_list, config, verbose) {
  # Try mlogit first
  result <- tryCatch(
    estimate_with_mlogit(data_list, config, verbose),
    error = function(e) {
      if (verbose) message("[MODEL] mlogit failed, trying clogit...")
      NULL
    }
  )

  if (!is.null(result) && result$convergence$converged) {
    return(result)
  }

  # Fallback to clogit
  result <- tryCatch(
    estimate_with_clogit(data_list, config, verbose),
    error = function(e) {
      conjoint_refuse(
        code = "CALC_ALL_METHODS_FAILED",
        title = "All Estimation Methods Failed",
        problem = "Neither mlogit nor clogit could estimate the model.",
        why_it_matters = "Cannot produce utilities without a fitted model.",
        how_to_fix = c(
          "Check data quality with validate_conjoint_data().",
          "Ensure sufficient variation in choice data."
        )
      )
    }
  )

  return(result)
}
```

### Guard Functions

The `00_guard.R` module provides validation gates:

```r
guard_check_data_exists(data, min_choices = 5)
# Validates that data frame exists and has minimum number of choice observations.
# Named to avoid shadowing validate_conjoint_data() in 02_data.R.
```

---

## Performance Considerations

### Benchmarks

| Task | Dataset Size | Time |
|------|--------------|------|
| Config load | - | <1 sec |
| Data load (CSV) | 50K rows | ~2 sec |
| mlogit estimation | 10K choice sets | ~5 sec |
| clogit estimation | 10K choice sets | ~2 sec |
| HB estimation | 200 respondents, 10K iterations | ~2-5 min |
| Latent class (K=2..5) | 200 respondents | ~3-8 min |
| Output generation | 6 attributes | ~3 sec |
| HTML report generation | Full analysis | ~5-10 sec |
| Bootstrap CIs (1000 draws) | 200 respondents | ~10-30 sec |

### Optimization Tips

1. **CSV over XLSX:** 2-3x faster loading
2. **clogit for large data:** Faster than mlogit
3. **Reduce attributes:** Fewer parameters = faster convergence
4. **Skip simulator:** Set `generate_market_simulator = FALSE`
5. **HB tuning:** Start with 5000 iterations for testing, use 10000-50000 for production
6. **LC range:** Narrow `latent_class_min`/`latent_class_max` to reduce search space

---

## Code Style Guidelines

### Naming Conventions

- **Functions:** `snake_case` (e.g., `calculate_hit_rate`)
- **Variables:** `snake_case` (e.g., `choice_set_id`)
- **Constants:** `SCREAMING_SNAKE` (e.g., `MODULE_VERSION`)
- **Internal helpers:** Prefixed with `.` (e.g., `.html_esc`, `.svg_esc`, `.preflight_find_module_dir`)
- **Guard functions:** Prefixed with `guard_` (e.g., `guard_check_data_exists`)

### Function Structure

```r
function_name <- function(param1, param2, verbose = TRUE) {
  # Validate inputs (TRS refusal, not stop())
  if (invalid) {
    return(conjoint_refuse(
      code = "DATA_INVALID",
      title = "...",
      problem = "...",
      why_it_matters = "...",
      how_to_fix = "..."
    ))
  }

  # Main logic
  result <- ...

  # Verbose output
  if (verbose) message("[STEP] Progress info")

  # Return
  return(result)
}
```

### Section Comments

```r
# ============================================================================
# SECTION NAME
# ============================================================================

# ---------------------------------------------------------------------------
# Subsection name
# ---------------------------------------------------------------------------
```

---

## Maintenance Procedures

### Before Release

- [ ] Run full test suite (16 test files)
- [ ] Run pre-flight check: `conjoint_preflight(verbose = TRUE)`
- [ ] Test with real config files (MNL, HB, LC, BWS)
- [ ] Update version in `get_conjoint_version()` (99_helpers.R)
- [ ] Update README.md
- [ ] Update docs/ files
- [ ] Test GUI and command line
- [ ] Verify JS syntax: `node --check` on all 7 JS files

### Version Updates

Update in:
1. `R/99_helpers.R` -> `get_conjoint_version()` (single source of truth)
2. `README.md`
3. `docs/` files

The version string is retrieved via `get_conjoint_version()` throughout the codebase (banner, preflight, output metadata).

### Adding New Features

1. Create function in appropriate file
2. Add config options if needed (Settings sheet)
3. Update validation in guard and data layers
4. Add tests (aim for 80%+ coverage)
5. Update documentation (README, TECHNICAL_DOCS)
6. Ensure all errors use TRS refusals (no `stop()`)

---

## Dependencies

### Required Packages

| Package | Purpose |
|---------|---------|
| `dplyr` | Data manipulation |
| `openxlsx` | Excel config reading and output writing (no Java dependency) |
| `data.table` | Fast data manipulation |
| `jsonlite` | JSON serialization for HTML reports |

### Required for Estimation (method-dependent)

| Package | Purpose | When Needed |
|---------|---------|-------------|
| `mlogit` | Maximum likelihood MNL estimation | `auto`, `mlogit` methods |
| `dfidx` | Data indexing for mlogit (>= 1.1-0) | `auto`, `mlogit` methods |
| `survival` | Conditional logit (clogit) estimation | `auto`, `clogit` methods |
| `bayesm` | Hierarchical Bayes MCMC and Latent Class | `hb`, `latent_class` methods |

### Optional

| Package | Purpose |
|---------|---------|
| `coda` | Enhanced MCMC convergence diagnostics (Geweke test, ESS) |
| `haven` | Import SPSS (.sav) and Stata (.dta) data files |
| `base64enc` | Base64 encoding for config-driven slide images |

### Shared Dependencies

The conjoint module uses shared utilities from `modules/shared/lib/`:

| File | Purpose |
|------|---------|
| `trs_refusal.R` | Standardized TRS error handling (`turas_refuse()`) |
| `trs_run_state.R` | TRS run state tracking |
| `trs_banner.R` | TRS start/end banners for console output |
| `trs_run_status_writer.R` | TRS run status persistence |
| `hb_diagnostics.R` | MCMC convergence diagnostics for HB estimation |
| `data_utils.R` | Shared data utilities (`safe_numeric`, `safe_logical`, etc.) |
| `config_utils.R` | Configuration utilities |

### Checking Dependencies

Dependencies are validated by the pre-flight system:

```r
conjoint_preflight(verbose = TRUE)
# CHECK 4: Required packages — mlogit, survival, openxlsx, data.table, jsonlite
# CHECK 4b: Optional packages — bayesm
```

---

## Extension Points

### Adding New Estimation Methods

1. Create function in `03_estimation.R`:
```r
estimate_with_newmethod <- function(data_list, config, verbose) {
  # Estimation logic
  return(list(
    model = model_object,
    coefficients = coef(model),
    vcov = vcov(model),
    convergence = list(converged = TRUE, message = ""),
    method = "newmethod"
  ))
}
```

2. Add to method selection in `estimate_choice_model()`
3. Add config option (`estimation_method = "newmethod"`)
4. Add tests
5. Update documentation and pre-flight check if new packages required

### Adding New Simulation Methods

1. Add R-side function in `05_simulator.R`
2. Add JS-side implementation in `simulator_engine.js`
3. Update the simulation method dropdown in `simulator_ui.js`
4. Add tests in `test_simulation.R`

### Adding New Output Sheets

1. Create function in `07_output.R`:
```r
add_new_sheet <- function(wb, data, config) {
  sheet_name <- "New_Sheet"
  addWorksheet(wb, sheet_name)
  writeData(wb, sheet_name, data)
  invisible(wb)
}
```

2. Call from `write_conjoint_output()`
3. Update documentation

### Adding New HTML Report Panels

1. Add data transformation in `01_data_transformer.R`
2. Add table builder in `02_table_builder.R`
3. Add panel HTML in `03_page_builder.R`
4. Add navigation entry in `conjoint_navigation.js`
5. Add tests in `test_html_report.R`

### Adding New Simulator Modes

1. Add mode logic in `simulator_engine.js`
2. Add UI tab in `simulator_ui.js`
3. Add chart rendering in `simulator_charts.js`
4. Add per-mode sticky annotation slot in `conjoint_navigation.js`
5. Update pin snapshot system in `conjoint_pins.js` if mode produces pinnable output

---

## API Reference

### Main Entry Point

```r
run_conjoint_analysis(
  config_file,            # Path to Excel config
  data_file = NULL,       # Optional: override data path
  output_file = NULL,     # Optional: override output path
  verbose = TRUE,         # Print progress
  run_preflight = FALSE   # Run pre-flight checks first
) -> list
```

**Returns:**
```r
list(
  status = "PASS" | "PARTIAL" | "REFUSED",
  config = list(...),
  data_info = list(...),
  model_result = list(...),
  utilities = data.frame(...),
  importance = data.frame(...),
  diagnostics = list(...),
  output_file = "path",
  version = "3.1.0"
)
```

### Key Functions

| Function | File | Purpose |
|----------|------|---------|
| `run_conjoint_analysis()` | 00_main.R | Main entry point |
| `conjoint_preflight()` | 00_preflight.R | Module readiness validation |
| `conjoint_refuse()` | 00_guard.R | TRS refusal wrapper |
| `guard_check_data_exists()` | 00_guard.R | Data existence guard |
| `load_conjoint_config()` | 01_config.R | Load config |
| `load_conjoint_data()` | 02_data.R | Load data |
| `validate_conjoint_data()` | 02_data.R | Detailed data validation |
| `estimate_choice_model()` | 03_estimation.R | Multi-method estimation dispatch |
| `estimate_hb()` | 11_hierarchical_bayes.R | HB individual-level estimation |
| `estimate_latent_class()` | 13_latent_class.R | Latent class segmentation |
| `calculate_utilities()` | 04_utilities.R | Extract utilities |
| `calculate_attribute_importance()` | 04_utilities.R | Calculate importance |
| `calculate_hit_rate()` | 04_utilities.R | Prediction accuracy |
| `calculate_wtp()` | 14_willingness_to_pay.R | WTP with delta-method CIs |
| `predict_shares()` | 05_simulator.R | Market share prediction |
| `predict_shares_with_ci()` | 05_simulator.R | Bootstrap CIs on shares |
| `optimize_products()` | 15_product_optimizer.R | Product optimization |
| `write_conjoint_output()` | 07_output.R | Generate Excel |
| `create_market_simulator()` | 08_market_simulator.R | Build Excel simulator |
| `generate_conjoint_config_template()` | 12_config_template.R | Create config template |
| `get_conjoint_version()` | 99_helpers.R | Returns "3.1.0" |

---

**End of Technical Documentation**

*Turas Conjoint Module v3.1.0*
*Last Updated: March 2026*
