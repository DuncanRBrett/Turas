# Turas Conjoint Module - Technical Documentation

**Version:** 2.1.0
**Last Updated:** December 2025
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
2. **Robustness:** Multiple estimation fallbacks
3. **Testability:** Functions designed for unit testing
4. **Backward Compatibility:** Handle various config formats

### Module Structure

```
modules/conjoint/
├── R/
│   ├── 00_main.R              # Main orchestration (~400 lines)
│   ├── 01_config.R            # Configuration loading (~400 lines)
│   ├── 02_data.R              # Data loading & validation (~500 lines)
│   ├── 03_estimation.R        # Model estimation (~800 lines)
│   ├── 04_utilities.R         # Utility calculations (~600 lines)
│   ├── 05_alchemer_import.R   # Alchemer CBC import (~500 lines)
│   ├── 05_simulator.R         # Product simulator (~500 lines)
│   ├── 06_interactions.R      # Interaction effects (~400 lines)
│   ├── 07_output.R            # Excel output (~900 lines)
│   ├── 08_market_simulator.R  # Market simulator (~650 lines)
│   ├── 09_none_handling.R     # NONE option logic (~350 lines)
│   ├── 10_best_worst.R        # BWS scaling (~400 lines)
│   ├── 11_hierarchical_bayes.R# HB estimation (~500 lines)
│   └── 99_helpers.R           # Utilities (~500 lines)
├── tests/                      # Test suite
├── examples/                   # Example configs and data
├── docs/                       # This documentation
└── run_conjoint_gui.R         # Shiny GUI launcher
```

**Total:** ~6,500 lines

---

## Code Structure

### File Responsibilities

#### 99_helpers.R

Utility functions loaded first:

```r
format_number()           # Number formatting
parse_comma_list()        # Parse comma-separated values
safe_divide()             # Division with zero handling
is_valid_numeric()        # Numeric validation
```

**Dependencies:** None (base R only)

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

---

#### 02_data.R

Data loading and validation:

```r
load_conjoint_data(data_file, config, verbose = TRUE) -> list
validate_conjoint_data(data, config) -> list

# Returns:
list(
  data = data.frame(...),
  n_respondents = integer,
  n_choice_sets = integer,
  has_none = logical,
  validation = list(...)
)
```

---

#### 03_estimation.R

Model estimation methods:

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

#### 04_utilities.R

Utility calculation and diagnostics:

```r
calculate_utilities(model_result, config, verbose) -> list
calculate_attribute_importance(utilities, config) -> numeric
calculate_hit_rate(model_result, data, config) -> numeric

# Returns:
list(
  utilities = data.frame(Attribute, Level, Utility, SE, CI_L, CI_U),
  importance = data.frame(Attribute, Importance),
  diagnostics = list(r_squared, hit_rate, ...)
)
```

---

#### 05_alchemer_import.R

Alchemer data transformation:

```r
import_alchemer_conjoint(file_path, config, clean_levels, verbose) -> data.frame
clean_alchemer_level(values, attribute_name) -> character
validate_alchemer_data(df, verbose) -> list
create_config_from_alchemer(df, output_file) -> list
```

---

#### 07_output.R

Excel workbook generation:

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

## Data Flow

```
CONFIG FILE (Excel)
    ↓
load_conjoint_config()
    ↓
[Validated Config Object]
    ↓
load_conjoint_data()
    ↓
[Data List with Validation]
    ↓
estimate_choice_model()
    ├─→ estimate_with_mlogit() [Primary]
    └─→ estimate_with_clogit() [Fallback]
    ↓
[Model Result]
    ↓
calculate_utilities()
    ↓
[Utilities + Importance]
    ↓
write_conjoint_output()
    ↓
[Excel Workbook]
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
# Dimension: (n_choice_sets × n_alternatives)

# Verify it's a matrix
if (!is.matrix(fitted_mat)) {
  stop("fitted() did not return expected matrix")
}

# Row sums should all be ~1.0
stopifnot(all(abs(rowSums(fitted_mat) - 1) < 1e-6))

# Predicted choice per choice set
predicted <- max.col(fitted_mat, ties.method = "first")

# Actual choice per choice set
actual <- tapply(data$chosen, data$chid, function(x) which(x)[1])

# Hit rate
hit_rate <- sum(predicted == actual, na.rm = TRUE) / length(actual)
```

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

**Solution:**
```r
# Robust directory detection with fallbacks
.conjoint_module_dir <- tryCatch({
  dir <- getSrcDirectory(function() {})
  if (is.null(dir) || length(dir) == 0 || dir == "") {
    # Fallback 1: sys.frame
    dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "")
  }
  if (is.null(dir) || length(dir) == 0 || dir == "") {
    # Fallback 2: Check working directory structure
    wd <- getwd()
    if (file.exists(file.path(wd, "modules/conjoint/R"))) {
      dir <- file.path(wd, "modules/conjoint/R")
    }
  }
  dir
}, error = function(e) {
  file.path(getwd(), "modules/conjoint/R")
})
```

---

## Multi-Respondent Data Handling

### Key Principle

`(respondent_id, choice_set_id)` uniquely identifies a choice occasion.

### Data Structure

```
resp_id | choice_set_id | alt_id | chosen
--------|---------------|--------|-------
   1    |       1       |   1    |   0
   1    |       1       |   2    |   1      ← Resp 1, Set 1
   1    |       2       |   1    |   1      ← Resp 1, Set 2
   2    |       1       |   1    |   1      ← Resp 2, Set 1 (DIFFERENT)
   2    |       1       |   2    |   0
```

### Critical Operations

All these operations MUST group by both columns:

1. **Validation:** Exactly one chosen per (resp, set)
2. **Hit Rate:** Unique (resp, set) combinations
3. **Chance Rate:** Average alternatives per (resp, set)
4. **mlogit chid:** Paste(resp, set) for unique identifier

---

## Testing Framework

### Test Structure

```
tests/
├── test_unit_tests.R      # Unit tests
├── test_integration.R     # Integration tests
└── test_data/             # Test datasets
```

### Running Tests

```r
# Run all tests
source("modules/conjoint/tests/test_unit_tests.R")
run_all_tests()

# Run specific category
run_tests_for_category("estimation")
```

### Test Categories

- Helpers (99_helpers.R)
- Config (loading and validation)
- Data (validation logic)
- None handling (detection)
- Estimation (model fitting)
- Utilities (calculation)
- Simulator (market share)
- Output (Excel generation)

### Writing Regression Tests

After fixing a bug, add a regression test:

```r
test_mlogit_hit_rate_matrix <- function() {
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
}
```

---

## Error Handling

### Strategy

1. **Configuration Errors:** Stop with clear message
2. **Data Errors:** Stop with specific row/column info
3. **Estimation Errors:** Try fallback method
4. **Output Errors:** Log warning, continue

### Error Message Template

```r
stop(sprintf(
  "[MODULE] Error: %s\n\n" +
  "Location: %s\n" +
  "Value: %s\n" +
  "Expected: %s\n\n" +
  "Action: %s\n",
  error_type, location, value, expected, action
))
```

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
  result <- estimate_with_clogit(data_list, config, verbose)
  return(result)
}
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
| Output generation | 6 attributes | ~3 sec |

### Optimization Tips

1. **CSV over XLSX:** 2-3x faster loading
2. **clogit for large data:** Faster than mlogit
3. **Reduce attributes:** Fewer parameters = faster convergence
4. **Skip simulator:** Set `generate_market_simulator = FALSE`

---

## Code Style Guidelines

### Naming Conventions

- **Functions:** `snake_case` (e.g., `calculate_hit_rate`)
- **Variables:** `snake_case` (e.g., `choice_set_id`)
- **Constants:** `SCREAMING_SNAKE` (e.g., `MODULE_VERSION`)

### Function Structure

```r
function_name <- function(param1, param2, verbose = TRUE) {
  # Validate inputs
  if (invalid) stop("Clear error message")

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

- [ ] Run full test suite
- [ ] Test with real config files
- [ ] Update version number
- [ ] Update documentation
- [ ] Test GUI and command line

### Version Updates

Update in:
1. `R/00_main.R` → `MODULE_VERSION`
2. `README.md`
3. `docs/` files

### Adding New Features

1. Create function in appropriate file
2. Add config options if needed
3. Update validation
4. Add tests
5. Update documentation

---

## Dependencies

### Required Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `mlogit` | ≥1.1-0 | Multinomial logit |
| `survival` | ≥3.0-0 | Conditional logit |
| `readxl` | ≥1.4.0 | Read Excel config |
| `openxlsx` | ≥4.2.5 | Write Excel output |
| `dfidx` | ≥0.0-5 | Data indexing |

### Optional

| Package | Purpose |
|---------|---------|
| `dplyr` | Data manipulation |
| `bayesm` | Hierarchical Bayes (future) |

### Checking Dependencies

```r
check_dependencies <- function() {
  required <- c("mlogit", "survival", "readxl", "openxlsx", "dfidx")
  missing <- character(0)

  for (pkg in required) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      missing <- c(missing, pkg)
    }
  }

  if (length(missing) > 0) {
    stop(sprintf("Missing packages: %s", paste(missing, collapse = ", ")))
  }
}
```

---

## Extension Points

### Adding New Estimation Methods

1. Create function in 03_estimation.R:
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
3. Add config option if needed
4. Add tests
5. Update documentation

### Adding New Output Sheets

1. Create function in 07_output.R:
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

---

## API Reference

### Main Entry Point

```r
run_conjoint_analysis(
  config_file,            # Path to Excel config
  data_file = NULL,       # Optional: override data path
  output_file = NULL,     # Optional: override output path
  verbose = TRUE          # Print progress
) -> list
```

**Returns:**
```r
list(
  config = list(...),
  data_info = list(...),
  model_result = list(...),
  utilities = data.frame(...),
  importance = data.frame(...),
  diagnostics = list(...),
  output_file = "path"
)
```

### Key Functions

| Function | File | Purpose |
|----------|------|---------|
| `load_conjoint_config()` | 01_config.R | Load config |
| `load_conjoint_data()` | 02_data.R | Load data |
| `estimate_choice_model()` | 03_estimation.R | Estimate model |
| `calculate_utilities()` | 04_utilities.R | Extract utilities |
| `calculate_attribute_importance()` | 04_utilities.R | Calculate importance |
| `calculate_hit_rate()` | 04_utilities.R | Prediction accuracy |
| `write_conjoint_output()` | 07_output.R | Generate Excel |
| `create_market_simulator()` | 08_market_simulator.R | Build simulator |

---

**End of Technical Documentation**

*Turas Conjoint Module v2.1.0*
*Last Updated: December 2025*
