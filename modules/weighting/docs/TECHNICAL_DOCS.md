# TURAS Weighting Module - Technical Documentation

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Module Structure](#2-module-structure)
3. [Core Components](#3-core-components)
4. [Mathematical Methods](#4-mathematical-methods)
5. [TRS Compliance](#5-trs-compliance)
6. [Data Flow](#6-data-flow)
7. [Error Handling](#7-error-handling)
8. [Extension Points](#8-extension-points)
9. [Performance Considerations](#9-performance-considerations)
10. [Testing](#10-testing)

---

## 1. Architecture Overview

### 1.1 Design Philosophy

The TURAS Weighting Module follows these design principles:

- **TRS Compliance**: No silent failures; all errors are actionable
- **Configuration-Driven**: All parameters specified in Excel
- **Modular Architecture**: Separate files for distinct functionality
- **Fail-Fast Validation**: Comprehensive input checks before calculation
- **Reproducibility**: Deterministic results with full audit trail

### 1.2 High-Level Data Flow

```
Config File → Config Loader → Validator → Weight Calculator → Trimmer → Diagnostics → Output
     ↓              ↓            ↓              ↓              ↓            ↓           ↓
   Excel       Structured     Validated    Raw Weights   Trimmed Wts   Quality    Data + Report
                 Config         Data                                   Metrics
```

### 1.3 Dependencies

**Required:**
- readxl: Excel file reading
- dplyr: Data manipulation
- openxlsx: Excel writing
- survey: Rim weighting/calibration (required if method=rim)

**Optional:**
- haven: SPSS file reading

---

## 2. Module Structure

### 2.1 File Organization

```
modules/weighting/
├── run_weighting.R              # Main entry point (CLI + API)
├── run_weighting_gui.R          # Shiny GUI launcher
├── lib/
│   ├── config_loader.R          # Configuration parsing
│   ├── validation.R             # Input validation
│   ├── design_weights.R         # Design weight calculation
│   ├── rim_weights.R            # Rim weighting (survey::calibrate)
│   ├── trimming.R               # Weight capping/trimming
│   ├── diagnostics.R            # Quality diagnostics
│   └── output.R                 # Report generation
├── docs/
│   ├── USER_GUIDE.md            # End-user documentation
│   ├── TEMPLATE_REFERENCE.md    # Config file specification
│   └── TECHNICAL_DOCS.md        # This file
├── templates/
│   └── create_template.R        # Template generator
└── README.txt                   # Quick reference
```

### 2.2 Function Naming Conventions

| Pattern | Purpose | Example |
|---------|---------|---------|
| `run_*` | Entry points | `run_weighting()` |
| `load_*` | Data/config loading | `load_weighting_config()` |
| `validate_*` | Validation functions | `validate_rim_config()` |
| `calculate_*` | Core calculations | `calculate_design_weights()` |
| `apply_*` | Transformations | `apply_trimming_from_config()` |
| `get_*` | Accessors | `get_weight_spec()` |
| `print_*` | Output formatting | `print_rim_summary()` |

### 2.3 Source Order

Files must be sourced in dependency order:

1. validation.R (no dependencies)
2. config_loader.R (uses validation.R)
3. design_weights.R (uses validation.R, config_loader.R)
4. rim_weights.R (uses validation.R, config_loader.R)
5. trimming.R (standalone)
6. diagnostics.R (standalone)
7. output.R (uses diagnostics.R)

---

## 3. Core Components

### 3.1 Configuration Loader (config_loader.R)

**Primary Function:** `load_weighting_config(config_file, verbose)`

**Process:**
1. Validate file exists and is readable
2. Check required sheets present (General, Weight_Specifications)
3. Parse General sheet (Setting/Value format)
4. Resolve file paths relative to config location
5. Parse Weight_Specifications with validation
6. Load Design_Targets if any design weights
7. Load Rim_Targets if any rim weights
8. Load Advanced_Settings if present

**Return Value:**
```r
list(
  general = list(
    project_name = "...",
    data_file = "...",
    data_file_resolved = "...",  # Absolute path
    output_file_resolved = "...",
    save_diagnostics = TRUE/FALSE,
    project_root = "..."
  ),
  weight_specifications = data.frame(...),
  design_targets = data.frame(...),  # or NULL
  rim_targets = data.frame(...),     # or NULL
  advanced_settings = data.frame(...),  # or NULL
  config_file = "..."  # Absolute path
)
```

### 3.2 Validation (validation.R)

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `validate_weight_spec()` | Validate single weight specification |
| `validate_design_config()` | Validate design targets against data |
| `validate_rim_config()` | Validate rim targets against data |
| `validate_calculated_weights()` | Post-calculation quality check |

**Validation Pattern:**
```r
validation <- validate_design_config(data, targets, weight_name)
if (!validation$valid) {
  # Use TRS refusal
  turas_refuse(
    code = "CFG_INVALID_DESIGN_TARGETS",
    title = "Invalid Design Weight Configuration",
    problem = validation$errors[1],
    why_it_matters = "Cannot calculate weights without valid targets",
    how_to_fix = "Review and correct the Design_Targets sheet"
  )
}
```

### 3.3 Design Weights (design_weights.R)

**Primary Function:** `calculate_design_weights(data, stratum_variable, population_sizes, verbose)`

**Algorithm:**
```
For each stratum s:
  weight[s] = population_size[s] / sample_size[s]

Where:
  sample_size[s] = count of rows where stratum_variable == s
```

**Return Value:**
```r
list(
  weights = numeric_vector,  # Length = nrow(data)
  validation = list(...),
  stratum_summary = data.frame(
    stratum, population_size, sample_size, weight
  ),
  stratum_variable = "..."
)
```

### 3.4 Rim Weights (rim_weights.R)

**Primary Function:** `calculate_rim_weights(data, target_list, caseid_col = NULL, max_iterations = 50, convergence_tolerance = 1e-7, calibration_method = "raking", weight_bounds = c(0.3, 3.0), verbose = TRUE)`

**Algorithm:** Uses survey package's calibrate() function for modern calibration.

**v2.0 Implementation (survey::calibrate):**
```r
# Create survey design
svy_design <- survey::svydesign(
  ids = ~1,
  data = data,
  weights = rep(1, nrow(data))
)

# Build calibration formula and population margins
formula <- as.formula(paste("~", paste(names(target_list), collapse = " + ")))
population <- lapply(target_list, function(props) round(props * 1000))

# Calibrate with bounds DURING fitting
calibrated <- survey::calibrate(
  design = svy_design,
  formula = formula,
  population = population,
  calfun = calibration_method,  # "raking", "linear", or "logit"
  bounds = weight_bounds,       # Applied DURING calibration!
  maxit = max_iterations,
  epsilon = convergence_tolerance
)

weights <- weights(calibrated)
```

**Key v2.0 Improvements:**
- Weight bounds applied **DURING** calibration (not after)
- Multiple calibration methods: raking, linear, logit
- Returns full survey design object for variance estimation
- Better convergence with logit method for bounded weights

**Return Value:**
```r
list(
  weights = numeric_vector,
  converged = logical,          # survey errors if not converged
  iterations = NA_integer_,     # survey doesn't expose iteration count
  margins = data.frame(
    variable, category, target_pct, achieved_pct, diff_pct
  ),
  design = survey.design         # NEW: Full design object
)
```

### 3.5 Trimming (trimming.R)

**Primary Function:** `trim_weights(weights, method, value, verbose)`

**Methods:**

| Method | Formula | Example |
|--------|---------|---------|
| cap | `weights[weights > value] <- value` | Cap at 5 |
| percentile | `threshold <- quantile(weights, value)` | Cap at 95th %ile |

**Return Value:**
```r
list(
  weights = trimmed_vector,
  n_trimmed = integer,
  original_max = numeric,
  new_max = numeric,
  threshold = numeric,
  method = "cap" or "percentile",
  pct_trimmed = numeric
)
```

### 3.6 Diagnostics (diagnostics.R)

**Primary Function:** `diagnose_weights(weights, label, rim_result, trimming_result, save_to_file, verbose)`

**Metrics Calculated:**

| Metric | Formula | Interpretation |
|--------|---------|----------------|
| Effective N | (Σw)² / Σw² | Usable sample size |
| Design Effect | n / n_eff | Variance inflation factor |
| Efficiency | n_eff / n × 100 | Percent of sample retained |
| CV | SD(w) / mean(w) | Weight variability |

**Quality Assessment:**
```r
status <- "GOOD"

if (design_effect > 3) {
  status <- "POOR"
  issues <- c(issues, "High design effect (>3)")
} else if (design_effect > 2) {
  status <- "ACCEPTABLE"
  issues <- c(issues, "Moderate design effect")
}

if (cv > 1.0) {
  if (status == "GOOD") status <- "ACCEPTABLE"
  issues <- c(issues, "High weight variability")
}
```

---

## 4. Mathematical Methods

### 4.1 Design Weight Calculation

**Purpose:** Adjust for unequal selection probabilities in stratified samples.

**Formula:**
```
w_i = N_s / n_s

Where:
  w_i = weight for respondent i in stratum s
  N_s = population size of stratum s
  n_s = sample size of stratum s
```

**Properties:**
- Weights sum to total population
- Unbiased for population parameters
- Higher weights = underrepresented groups

### 4.2 Rim Weighting (Raking)

**Purpose:** Adjust sample to match multiple marginal distributions simultaneously.

**Algorithm (Iterative Proportional Fitting):**

```
Initialize: w_i = 1 for all i

Repeat until convergence:
  For each target variable v:
    For each category c in v:
      # Current weighted proportion
      p_c = Σ w_i[i in c] / Σ w_i

      # Adjustment factor
      a_c = target_c / p_c

      # Apply adjustment
      w_i[i in c] *= a_c

  Check: max(|achieved - target|) < tolerance
```

**Convergence:**
- Algorithm converges when all margins within tolerance
- May not converge if targets are inconsistent
- More variables = harder to converge

### 4.3 Effective Sample Size

**Purpose:** Measure precision loss from weighting.

**Kish Formula:**
```
n_eff = (Σ w_i)² / Σ w_i²
```

**Intuition:**
- Equal weights: n_eff = n
- Variable weights: n_eff < n
- Extreme weights: n_eff << n

### 4.4 Design Effect

**Formula:**
```
DEFF = n / n_eff = Σ w_i² / (Σ w_i)² × n
```

**Interpretation:**
- DEFF = 1: No effect
- DEFF = 2: Variance doubled, SE × 1.41
- DEFF = 3: Variance tripled, SE × 1.73

---

## 5. TRS Compliance

### 5.1 TRS Principles

The module implements TURAS Reliability Standard (TRS) v1.0:

1. **No Silent Failures**: All errors produce actionable messages
2. **Execution States**: PASS, PARTIAL, REFUSE, ERROR
3. **Refusal Codes**: Standardized error codes with prefixes
4. **Guard State**: Track warnings during execution

### 5.2 Refusal Code Prefixes

| Prefix | Category | Example |
|--------|----------|---------|
| CFG_ | Configuration errors | CFG_MISSING_SHEET |
| DATA_ | Data integrity errors | DATA_MISSING_VALUES |
| IO_ | File/path errors | IO_FILE_NOT_FOUND |
| MODEL_ | Model fitting errors | MODEL_NO_CONVERGENCE |
| PKG_ | Missing dependencies | PKG_SURVEY_MISSING |

### 5.3 TRS Integration Points

**Configuration Loading:**
```r
if (!file.exists(config_file)) {
  turas_refuse(
    code = "IO_CONFIG_NOT_FOUND",
    title = "Configuration File Not Found",
    problem = sprintf("Config file not found: %s", config_file),
    why_it_matters = "Cannot proceed without configuration",
    how_to_fix = c(
      "Check the file path is correct",
      "Ensure the file exists"
    )
  )
}
```

**Rim Convergence:**
```r
# v2.0: survey::calibrate() errors on non-convergence
tryCatch({
  calibrated <- survey::calibrate(...)
}, error = function(e) {
  turas_refuse(
    code = "MODEL_RIM_NO_CONVERGENCE",
    title = "Rim Weighting Did Not Converge",
    problem = sprintf("Calibration failed: %s", e$message),
    why_it_matters = "Target margins cannot be achieved with current settings",
    how_to_fix = c(
      "Increase max_iterations in Advanced_Settings (try 100)",
      "Try calibration_method='logit' (better for bounded weights)",
      "Adjust weight_bounds if needed",
      "Reduce number of rim variables"
    )
  )
})
```

### 5.4 Guard State Usage

```r
guard <- guard_init("WEIGHTING")

# During execution
if (n_missing > 0) {
  guard_warn(guard, sprintf("%d missing values in stratum variable", n_missing))
}

if (design_effect > 2) {
  guard_flag_stability(guard, "High design effect")
}

# At end
summary <- guard_summary(guard)
if (summary$has_issues) {
  # Return PARTIAL status
  return(trs_status_partial(
    module = "WEIGHTING",
    degraded_reasons = guard$warnings,
    affected_outputs = c("weight_column")
  ))
}
```

---

## 6. Data Flow

### 6.1 Main Execution Pipeline

```
run_weighting(config_file)
    │
    ├── load_weighting_config(config_file)
    │       ├── Validate file exists
    │       ├── Parse General sheet
    │       ├── Parse Weight_Specifications
    │       ├── Parse Design_Targets (if needed)
    │       ├── Parse Rim_Targets (if needed)
    │       └── Return config object
    │
    ├── Load survey data
    │       ├── Detect file format
    │       ├── Read data
    │       └── Convert to data.frame
    │
    ├── For each weight in Weight_Specifications:
    │       │
    │       ├── If method == "design":
    │       │   ├── validate_design_config()
    │       │   ├── calculate_design_weights_from_config()
    │       │   └── Store result
    │       │
    │       ├── If method == "rim":
    │       │   ├── validate_rim_config()
    │       │   ├── calculate_rim_weights_from_config()
    │       │   └── Store result
    │       │
    │       ├── apply_trimming_from_config()
    │       │
    │       ├── diagnose_weights()
    │       │
    │       └── Add weight column to data
    │
    ├── write_weighted_data() (if output_file specified)
    │
    ├── generate_weighting_report() (if save_diagnostics)
    │
    └── Return result object
```

### 6.2 Data Structures

**Survey Data:**
```r
data.frame with:
  - Original survey columns
  - Added weight columns (one per weight in config)
```

**Result Object:**
```r
list(
  data = data.frame,           # Weighted data
  weight_names = c("w1", "w2"), # Weight column names
  weight_results = list(       # Per-weight details
    w1 = list(
      weights = numeric,
      diagnostics = list(...),
      design_result = list(...),  # or rim_result
      trimming_result = list(...)
    ),
    w2 = ...
  ),
  config = list(...),          # Parsed config
  output_file = "...",         # Path if written
  diagnostics_file = "..."     # Path if written
)
```

---

## 7. Error Handling

### 7.1 Error Categories

| Category | TRS Code | Example |
|----------|----------|---------|
| Config missing | IO_CONFIG_NOT_FOUND | Config file doesn't exist |
| Sheet missing | CFG_MISSING_SHEET | Required sheet not in config |
| Column missing | DATA_COLUMN_NOT_FOUND | Stratum variable not in data |
| Value missing | DATA_MISSING_VALUES | NAs in rim variables |
| Convergence | MODEL_RIM_NO_CONVERGENCE | Rim weighting failed |
| Package | PKG_ANESRAKE_MISSING | anesrake not installed |

### 7.2 Error Message Format

All errors follow TRS format:

```
================================================================================
  [REFUSE] CFG_MISSING_SHEET: Required Sheet Missing
================================================================================

Problem:
  The 'Design_Targets' sheet is required but not found in config file.

Why it matters:
  Design weights cannot be calculated without population sizes.

How to fix:
  1. Add a 'Design_Targets' sheet to your config file
  2. Include columns: weight_name, stratum_variable, stratum_category, population_size
  3. Add one row per stratum with population size

Diagnostics:
  Expected:  Design_Targets
  Observed:  General, Weight_Specifications

================================================================================
```

### 7.3 Warning Handling

Warnings are collected but don't stop execution:

```r
# Collected during execution
guard_warn(guard, "3 respondents have zero weights")

# Included in diagnostics
if (length(warnings) > 0) {
  cat("Warnings:\n")
  for (w in warnings) cat("  - ", w, "\n")
}
```

---

## 8. Extension Points

### 8.1 Adding New Weighting Methods

1. Create new file `lib/new_method.R`
2. Implement core function:
   ```r
   calculate_new_method_weights <- function(data, targets, ...) {
     # Implementation
     return(list(weights = w, ...))
   }
   ```
3. Add wrapper for config:
   ```r
   calculate_new_method_from_config <- function(data, config, weight_name, verbose) {
     # Get targets from config
     # Validate
     # Call core function
   }
   ```
4. Add dispatch in `run_weighting.R`:
   ```r
   } else if (method == "new_method") {
     result$new_result <- calculate_new_method_from_config(...)
     weights <- result$new_result$weights
   }
   ```
5. Add to config loading if new sheet needed
6. Add validation function

### 8.2 Adding Custom Diagnostics

```r
# In diagnostics.R, add to diagnose_weights():

# Custom metric
results$custom_metric <- list(
  value = calculate_custom_metric(valid_weights),
  threshold = 0.5,
  status = if (value > 0.5) "WARN" else "OK"
)

# Add to quality assessment
if (results$custom_metric$status == "WARN") {
  issues <- c(issues, "Custom metric exceeds threshold")
}
```

### 8.3 Adding Output Formats

```r
# In output.R:

write_weighted_data_json <- function(data, output_file) {
  jsonlite::write_json(data, output_file, pretty = TRUE)
}
```

---

## 9. Performance Considerations

### 9.1 Memory Usage

| Component | Memory Pattern |
|-----------|----------------|
| Data loading | O(rows × cols) |
| Design weights | O(rows) |
| Rim weights | O(rows × iterations) |
| Diagnostics | O(rows) |

### 9.2 Computation Time

Typical execution times (n=1000 respondents):

| Operation | Time |
|-----------|------|
| Config loading | < 1s |
| Data loading | 1-5s |
| Design weights | < 1s |
| Rim weights (3 vars) | 2-5s |
| Rim weights (5 vars) | 5-15s |
| Diagnostics | < 1s |
| Excel output | 1-3s |

### 9.3 Optimization Tips

1. **Large datasets:**
   - Consider sampling for exploratory runs
   - Use CSV instead of Excel for faster loading

2. **Rim convergence:**
   - Start with fewer variables
   - Use relaxed tolerance for exploration

3. **Repeated runs:**
   - Cache loaded config
   - Use `quick_*` functions for simple cases

---

## 10. Testing

### 10.1 Test Categories

| Category | Purpose |
|----------|---------|
| Unit tests | Individual function behavior |
| Integration tests | End-to-end workflows |
| Validation tests | Known answer tests |
| Edge case tests | Boundary conditions |

### 10.2 Key Test Cases

**Configuration:**
- Valid config loads successfully
- Missing required sheets produce REFUSE
- Invalid method produces REFUSE
- Path resolution works correctly

**Design Weights:**
- Equal strata produce equal weights
- Known population/sample produces correct weights
- Missing stratum values produce NA weights
- Empty stratum produces error

**Rim Weights:**
- Converges with valid targets
- Non-convergence handled correctly
- Achieved margins match targets
- Missing values produce error

**Trimming:**
- Cap method caps correctly
- Percentile method caps correctly
- Untrimmed weights unchanged

**Diagnostics:**
- Equal weights produce DEFF=1
- Known weights produce expected n_eff
- Quality thresholds work correctly

### 10.3 Running Tests

```r
# Run all tests
testthat::test_dir("modules/weighting/tests")

# Run specific test file
testthat::test_file("modules/weighting/tests/test-design_weights.R")

# Run with coverage
covr::package_coverage("modules/weighting")
```

---

## References

### Statistical Methods

- Kish, L. (1965). *Survey Sampling*. John Wiley & Sons.
- Deming, W.E. & Stephan, F.F. (1940). On a least squares adjustment of a sampled frequency table when the expected marginal totals are known. *Annals of Mathematical Statistics*, 11(4), 427-444.
- Deville, J.C. & Särndal, C.E. (1992). Calibration estimators in survey sampling. *Journal of the American Statistical Association*, 87(418), 376-382.

### survey Package

- Lumley, T. (2023). *survey: Analysis of complex survey samples*. R package version 4.2+. https://CRAN.R-project.org/package=survey
- Lumley, T. (2010). *Complex Surveys: A Guide to Analysis Using R*. John Wiley & Sons.

### TRS Specification

- TURAS_Mapping_Refusal_Standard_TRS_v1.0.md

---

*TURAS Weighting Module - Technical Documentation v2.0*
