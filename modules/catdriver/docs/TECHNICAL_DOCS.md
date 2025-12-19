# Categorical Key Driver Module - Technical Documentation

**Version:** 2.0
**Date:** December 2024
**Author:** Claude Code
**For:** Maintenance and Development Reference

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [File Structure and Dependencies](#file-structure-and-dependencies)
3. [Data Flow Pipeline](#data-flow-pipeline)
4. [Function Reference](#function-reference)
5. [Configuration Schema](#configuration-schema)
6. [Statistical Methods](#statistical-methods)
7. [Error Handling Strategy](#error-handling-strategy)
8. [Testing Guidelines](#testing-guidelines)
9. [Extension Points](#extension-points)
10. [Known Limitations](#known-limitations)
11. [Maintenance Checklist](#maintenance-checklist)

---

## Architecture Overview

### Design Principles

1. **Self-Contained**: Module has no dependencies on Turas shared utilities
2. **Config-Driven**: All analysis parameters come from Excel configuration
3. **Relative Paths**: Works with OneDrive/cloud-synced project folders
4. **Graceful Degradation**: Handles missing data, small samples, convergence issues
5. **Plain-English Output**: Non-statisticians can understand results

### Module Independence

This module is designed to be **fully standalone**. It does NOT use:
- `modules/shared/lib/validation_utils.R`
- `modules/shared/lib/config_utils.R`
- `modules/shared/lib/data_utils.R`
- Any other shared Turas infrastructure

This means:
- External review can focus solely on `modules/catdriver/`
- Module can be extracted and used independently
- No risk of breaking changes from shared library updates

---

## File Structure and Dependencies

### Source File Hierarchy

```
modules/catdriver/
├── R/
│   ├── 00_main.R           # Entry point, orchestration, refusal handler
│   ├── 01_config.R         # Configuration loading (uses catdriver_refuse)
│   ├── 02_validation.R     # Data loading and validation
│   ├── 03_preprocessing.R  # Variable type detection, treatment contrasts
│   ├── 04_analysis.R       # Model dispatcher
│   ├── 04a_ordinal.R       # Ordinal logistic (ordinal::clm → MASS::polr fallback)
│   ├── 04b_multinomial.R   # Multinomial logistic (nnet::multinom)
│   ├── 05_importance.R     # Chi-square importance calculation
│   ├── 06_output.R         # Excel workbook generation
│   ├── 06a_sheets_summary.R # Summary sheet formatting
│   ├── 06b_sheets_detail.R  # Detail sheet formatting
│   ├── 07_utilities.R      # Helper functions (no external deps)
│   ├── 08_guard.R          # Refusal mechanism (catdriver_refuse)
│   ├── 08a_guards_hard.R   # Hard validation guards
│   ├── 08b_guards_soft.R   # Soft warning guards
│   ├── 09_mapper.R         # Canonical term-to-level mapping (no guessing)
│   └── 10_missing.R        # Missing data handling per Driver_Settings
├── run_catdriver_gui.R     # Shiny GUI launcher
├── README.md               # Quick start guide
└── docs/
    ├── USER_MANUAL.md      # End-user documentation
    ├── TECHNICAL_DOCS.md   # This file
    └── R_PACKAGES.md       # Package dependencies
```

### Internal Dependencies (Source Order)

When sourcing manually, files must be loaded in this order:

```r
source("modules/catdriver/R/07_utilities.R")   # No dependencies
source("modules/catdriver/R/01_config.R")       # Uses: 07_utilities
source("modules/catdriver/R/02_validation.R")   # Uses: 07_utilities, 01_config
source("modules/catdriver/R/03_preprocessing.R") # Uses: 07_utilities, 01_config
source("modules/catdriver/R/04_analysis.R")     # Uses: 07_utilities
source("modules/catdriver/R/05_importance.R")   # Uses: 07_utilities, 01_config
source("modules/catdriver/R/06_output.R")       # Uses: 07_utilities, 01_config, 05_importance
source("modules/catdriver/R/00_main.R")         # Uses: all above
```

### External R Package Dependencies

| Package | Version | Required | Purpose |
|---------|---------|----------|---------|
| MASS | Any | Yes | `polr()` for ordinal logistic regression |
| nnet | Any | Yes | `multinom()` for multinomial logistic regression |
| car | Any | Yes | `Anova()` Type II tests, `vif()` for multicollinearity |
| openxlsx | Any | Yes | Excel file reading and writing |
| dplyr | Any | No | Not used (pure base R) |
| haven | Any | No | Optional for SPSS/Stata file support |
| shiny | Any | GUI only | Shiny web application |
| shinyFiles | Any | GUI only | Directory/file browser widgets |

---

## Data Flow Pipeline

### Main Pipeline (`run_categorical_keydriver`)

```
┌─────────────────┐
│ 1. Load Config  │  load_catdriver_config()
│    (01_config)  │  → Returns: config list
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 2. Load Data    │  load_catdriver_data()
│  (02_validation)│  → Returns: raw data frame
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 3. Validate     │  validate_catdriver_data()
│  (02_validation)│  → Returns: diagnostics list
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 4. Prepare Data │  prepare_analysis_data()
│  (02_validation)│  → Returns: complete cases + weights
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 5. Preprocess   │  preprocess_catdriver_data()
│ (03_preprocess) │  → Returns: typed variables + formula
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 6. Fit Model    │  run_catdriver_model()
│   (04_analysis) │  → Returns: model + coefficients
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 7. Importance   │  calculate_importance()
│  (05_importance)│  → Returns: chi-sq importance df
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 8. Extract ORs  │  extract_odds_ratios()
│  (05_importance)│  → Returns: odds ratios df
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 9. Patterns     │  calculate_factor_patterns()
│  (05_importance)│  → Returns: cross-tab patterns
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 10. Write Output│  write_catdriver_output()
│    (06_output)  │  → Creates: Excel workbook
└─────────────────┘
```

### Model Selection Logic

```
detect_outcome_type()
         │
         ├─── n_unique == 2 ──────────────► Binary Logistic (glm)
         │
         ├─── order_spec provided ────────► Ordinal Logistic (polr)
         │
         ├─── is.ordered(outcome) ────────► Ordinal Logistic (polr)
         │
         ├─── is.numeric(outcome) ────────► Ordinal Logistic (polr) + warning
         │
         └─── else (3+ unordered) ────────► Multinomial Logistic (multinom)
```

---

## Function Reference

### Core Functions

#### `run_categorical_keydriver(config_file, data_file, output_file, outcome_type)`
**File:** `00_main.R`
**Purpose:** Main entry point and orchestration
**Parameters:**
- `config_file` (required): Path to Excel config
- `data_file` (optional): Override data path from config
- `output_file` (optional): Override output path from config
- `outcome_type` (optional): Force "binary", "ordinal", or "nominal"

**Returns:** List containing all results (model, importance, odds_ratios, etc.)

#### `load_catdriver_config(config_file, project_root)`
**File:** `01_config.R`
**Purpose:** Parse Excel configuration
**Validation:** Checks for required sheets, columns, file paths
**Returns:** Named list with all config parameters

#### `validate_catdriver_data(data, config)`
**File:** `02_validation.R`
**Purpose:** Comprehensive data quality checks
**Checks:**
- Missing data rates per variable
- Outcome category counts
- Driver variable distributions
- Small cell detection
- Events per predictor (binary)
- Weight variable validity

**Returns:** Diagnostics list with `passed` boolean

#### `preprocess_catdriver_data(data, config)`
**File:** `03_preprocessing.R`
**Purpose:** Prepare variables for modeling
**Actions:**
- Convert outcome to appropriate factor type
- Set reference levels for factors
- Build model formula
- Calculate effective sample sizes

**Returns:** List with prepared data, outcome_info, predictor_info, formula

#### `run_catdriver_model(prep_data, config, weights)`
**File:** `04_analysis.R`
**Purpose:** Fit appropriate logistic regression
**Dispatches to:**
- `run_binary_logistic()` for 2 categories
- `run_ordinal_logistic()` for ordered 3+
- `run_multinomial_logistic()` for unordered 3+

**Returns:** Model object, coefficients, fit statistics, diagnostics

#### `calculate_importance(model_result, config)`
**File:** `05_importance.R`
**Purpose:** Compute relative importance scores
**Method:** Type II Wald chi-square tests via `car::Anova()`
**Fallback:** Uses z-values if Anova fails
**Returns:** Data frame sorted by importance %

#### `write_catdriver_output(results, config, output_file)`
**File:** `06_output.R`
**Purpose:** Generate formatted Excel workbook
**Creates:** 6 sheets (or 4 if detailed_output=FALSE)

### Helper Functions (07_utilities.R)

| Function | Purpose |
|----------|---------|
| `get_setting()` | Safe extraction from settings list |
| `as_logical_setting()` | Convert various formats to TRUE/FALSE |
| `as_numeric_setting()` | Safe numeric conversion |
| `format_pvalue()` | Format p-values for display |
| `get_sig_stars()` | Convert p to significance stars |
| `format_or()` | Format odds ratios |
| `interpret_or_effect()` | OR → effect size label |
| `interpret_importance()` | % → importance category |
| `interpret_pseudo_r2()` | R² → fit interpretation |
| `clean_var_name()` | Sanitize variable names |
| `is_categorical()` | Detect categorical variables |
| `safe_crosstab()` | Cross-tab with proportions |
| `detect_small_cells()` | Find cells < threshold |
| `is_absolute_path()` | Check path type |
| `resolve_path()` | Handle relative paths |
| `log_message()` | Formatted console output |
| `check_separation()` | Detect perfect separation |
| `calc_mcfadden_r2()` | Pseudo R-squared |

---

## Configuration Schema

### Settings Sheet

| Setting | Type | Required | Default | Validation |
|---------|------|----------|---------|------------|
| analysis_name | string | No | "Key Driver Analysis" | Any non-empty |
| data_file | path | **Yes** | - | Must exist |
| output_file | path | **Yes** | - | Directory must exist |
| outcome_type | enum | No | "auto" | auto/binary/ordinal/nominal |
| reference_category | string | No | first alpha | Must exist in outcome |
| min_sample_size | integer | No | 30 | ≥ 1 |
| confidence_level | numeric | No | 0.95 | 0 < x < 1 |
| missing_threshold | numeric | No | 50 | 0-100 |
| detailed_output | boolean | No | TRUE | TRUE/FALSE |
| multinomial_mode | enum | No | "baseline_category" | baseline_category/all_pairwise/one_vs_all |
| target_outcome_level | string | No | - | Required if multinomial_mode="one_vs_all" |

### Variables Sheet

| Column | Type | Required | Validation |
|--------|------|----------|------------|
| VariableName | string | **Yes** | Must exist in data |
| Type | enum | **Yes** | Outcome/Driver/Weight |
| Label | string | **Yes** | Non-empty |
| Order | string | No | Semicolon-separated categories |

**Constraints:**
- Exactly 1 Outcome variable
- At least 1 Driver variable
- At most 1 Weight variable

### Driver_Settings Sheet (Required)

Per-driver configuration for type and missing data handling:

| Column | Type | Required | Validation |
|--------|------|----------|------------|
| driver | string | **Yes** | Must match a Driver in Variables sheet |
| type | enum | **Yes** | categorical/ordinal/binary |
| reference_level | string | No | Must exist in data |
| missing_strategy | enum | No | drop_row/missing_as_level/error_if_missing |

**Type Handling:**
- `categorical` / `nominal`: Unordered factor with treatment contrasts
- `ordinal`: Ordered factor with **treatment contrasts** (not polynomial)
- `binary`: Two-level factor

**Missing Strategies:**
- `drop_row`: Remove rows with missing values (default)
- `missing_as_level`: Recode missing to "Missing / Not answered" level
- `error_if_missing`: Refuse if any missing values present

---

## Statistical Methods

### Binary Logistic Regression

**Model:** `glm(outcome ~ drivers, family = binomial(link = "logit"))`

**Coefficients:** Log-odds, converted to odds ratios via `exp()`

**Confidence Intervals:** Wald-based, `OR ± z * SE`

**Fit Statistics:**
- McFadden Pseudo-R²: `1 - (deviance / null.deviance)`
- AIC: From model
- LR Test: `null.deviance - deviance ~ χ²(df)`

**Classification:** 0.5 probability threshold

### Ordinal Logistic Regression

**Model:** `MASS::polr(outcome ~ drivers, method = "logistic", Hess = TRUE)`

**Assumption:** Proportional odds (parallel regression)

**Proportional Odds Check:** Practical approach
1. Fit binary models at each threshold
2. Compare ORs across thresholds
3. PASS if max(OR)/min(OR) < 1.25
4. WARNING if ratio > 1.5

**Thresholds:** Cumulative log-odds cutpoints (α parameters)

### Multinomial Logistic Regression

**Model:** `nnet::multinom(outcome ~ drivers, trace = FALSE, maxit = 500)`

**Reference:** First level alphabetically (or user-specified)

**Coefficients:** Log-odds relative to reference outcome

**Convergence:** Checked via `model$convergence == 0`

### Variable Importance

**Primary Method:** Type II Wald chi-square via `car::Anova(model, type = "II")`

**Importance %:** `100 × (χ² for variable) / (sum of all χ²)`

**Aggregation:** Dummy variables automatically grouped by original factor

**Fallback (if Anova fails):**
1. Extract z-values from coefficients
2. Square to get χ² approximation
3. Aggregate by original variable

---

## Error Handling Strategy

### Core Principle: No Silent Degradation

CatDriver uses a strict "refuse rather than guess" philosophy. Any situation that could produce misleading output triggers a **controlled refusal** rather than continuing with potentially wrong results.

### The Refusal Mechanism (`catdriver_refuse`)

All user-fixable errors use `catdriver_refuse()` instead of `stop()`. This produces clean, actionable messages:

```r
catdriver_refuse(
  reason = "CFG_FILE_NOT_FOUND",           # Programmatic code
  title = "CONFIG FILE NOT FOUND",          # Display title
  problem = "File does not exist: ...",     # What went wrong
  why_it_matters = "Cannot proceed...",     # Why this matters
  fix = "Check the path and re-run."        # How to fix it
)
```

Refusals are caught by `with_refusal_handler()` at the top level for clean display without stack traces.

### Error Categories

| Category | Handling | Mechanism |
|----------|----------|-----------|
| Config not found | Refuse | `catdriver_refuse()` |
| Missing required sheet | Refuse | `catdriver_refuse()` |
| Variable not in data | Refuse | `catdriver_refuse()` |
| Insufficient sample | Refuse | `catdriver_refuse()` |
| Missing package | Refuse | `catdriver_refuse()` |
| Unmapped coefficients | Refuse | `catdriver_refuse()` |
| Polynomial contrasts detected | Refuse | `catdriver_refuse()` |
| Separation (no brglm2) | Refuse | `catdriver_refuse()` |
| Model non-convergence | Warning | `guard_warn()` |
| High missing data | Warning | `guard_warn()` |
| Small cells | Warning | `guard_warn()` |

### Strict Mapping Validation

The term-to-level mapper (09_mapper.R) enforces strict validation:

1. **No guessing**: If a coefficient cannot be exactly matched to a factor level, refuse
2. **No warnings-only**: If any coefficients are unmapped, refuse (not warn)
3. **Polynomial contrast detection**: If `.L/.Q/.C` patterns detected, refuse (ordinal should use treatment contrasts)
4. **Validation gate**: `validate_mapping()` is called in the main pipeline before OR extraction

### Graceful Degradation (Where Appropriate)

1. **Missing `ordinal` package:** Fall back to MASS::polr for ordinal models
2. **Missing `brglm2` package:** Refuse if separation detected (user must install or override)
3. **Missing `haven` package:** Refuse only if .sav/.dta file loaded
4. **Anova fails:** Use coefficient-based importance as fallback

---

## Testing Guidelines

### Manual Test Cases

1. **Happy Path - Binary**
   - 2-category outcome, clean data
   - Expected: Binary logistic, all sheets generated

2. **Happy Path - Ordinal**
   - 3+ ordered categories with Order column
   - Expected: Ordinal logistic, PO check performed

3. **Happy Path - Nominal**
   - 3+ unordered categories
   - Expected: Multinomial logistic

4. **Missing Data**
   - 20%+ missing on some variables
   - Expected: Warning, correct complete-case N reported

5. **Small Sample**
   - N < 50 complete cases
   - Expected: Warning about events per predictor

6. **Small Cells**
   - Some predictor-outcome combinations < 5
   - Expected: Warning in diagnostics

7. **Perfect Separation**
   - One category perfectly predicts outcome
   - Expected: Warning, large coefficient flagged

8. **Non-Convergence**
   - Many predictors, small sample
   - Expected: Warning, analysis continues

### Test Data Files

| File | Type | N | Purpose |
|------|------|---|---------|
| `examples/basic/employment_satisfaction.csv` | Ordinal | 400 | Main demo |
| `tests/test_data/binary_outcome.csv` | Binary | 400 | Binary path |

### Validation Checklist

- [ ] Config loads without error
- [ ] Data loads from CSV, XLSX, SAV
- [ ] Missing data correctly reported
- [ ] Outcome type correctly detected
- [ ] Reference levels correctly set
- [ ] Model converges
- [ ] Importance sums to 100%
- [ ] Odds ratios match coefficients
- [ ] Excel output opens in Excel
- [ ] All 6 sheets present (detailed mode)
- [ ] Executive summary readable

---

## Extension Points

### Adding New Outcome Types

1. Add detection logic in `detect_outcome_type()` (03_preprocessing.R)
2. Create `run_new_model()` function in 04_analysis.R
3. Add case to switch in `run_catdriver_model()`
4. Ensure coefficient extraction matches expected format

### Adding New Output Sheets

1. Create `add_new_sheet()` function in 06_output.R
2. Call from `write_catdriver_output()`
3. Update sheet count in documentation

### Adding New Settings

1. Add to Settings sheet validation in 01_config.R
2. Extract with default in `load_catdriver_config()`
3. Document in configuration schema

### Supporting New Data Formats

1. Add format to `load_catdriver_data()` switch (02_validation.R)
2. Create `load_format_data()` helper
3. Handle format-specific labelled variables

---

## Known Limitations

### Statistical Limitations

1. **No weighted ordinal/multinomial:** `polr()` supports weights, but `multinom()` support is limited
2. **No robust standard errors:** Uses model-based SEs only
3. **No interaction terms:** Formula is additive only
4. **No multiple imputation:** Uses per-variable missing strategies (drop_row, missing_as_level)
5. **Firth correction requires brglm2:** If package not installed and separation detected, analysis refuses

### Technical Limitations

1. **Large datasets:** Memory-bound for >100K rows with many predictors
2. **Many categories:** Multinomial slow with >10 outcome categories
3. **High cardinality predictors:** Warning issued but analysis continues
4. **Unicode in Excel:** May display incorrectly in some locales

### GUI Limitations

1. **No progress bar:** Long analyses show no intermediate progress
2. **No cancellation:** Analysis cannot be interrupted once started
3. **Single config per run:** Cannot batch multiple analyses

---

## Maintenance Checklist

### Version Update Procedure

1. Update version number in:
   - `00_main.R` header and console output
   - `README.md`
   - `USER_MANUAL.md`
   - `TECHNICAL_DOCS.md`

2. Update date in all documentation

3. Test all happy paths

4. Update CHANGELOG (if maintained)

### Dependency Updates

If updating R package dependencies:

1. Test with minimum supported version
2. Update version table in this document
3. Verify no breaking API changes

### Code Quality Checks

Before release:

- [ ] No hardcoded paths
- [ ] All functions documented with roxygen
- [ ] Error messages actionable
- [ ] Console output informative
- [ ] Excel output formatted correctly

---

## Contact

For maintenance questions, refer to the Turas project documentation or contact the development team.
