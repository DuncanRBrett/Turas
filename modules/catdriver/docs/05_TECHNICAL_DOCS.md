---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Categorical Key Driver Module - Technical Documentation

**Version:** 10.0 **Last Updated:** 22 December 2025 **Target
Audience:** Developers, Technical Maintainers, Data Scientists

------------------------------------------------------------------------

## Table of Contents

1.  [Architecture Overview](#architecture-overview)
2.  [File Structure](#file-structure)
3.  [Data Flow Pipeline](#data-flow-pipeline)
4.  [Core Components](#core-components)
5.  [Error Handling Strategy](#error-handling-strategy)
6.  [Configuration Schema](#configuration-schema)
7.  [Extension Points](#extension-points)
8.  [Testing Guidelines](#testing-guidelines)
9.  [Maintenance Guide](#maintenance-guide)

------------------------------------------------------------------------

## Architecture Overview {#architecture-overview}

### Design Principles

1.  **Self-Contained:** Module has no dependencies on Turas shared
    utilities
2.  **Config-Driven:** All analysis parameters from Excel configuration
3.  **Relative Paths:** Works with OneDrive/cloud-synced folders
4.  **Graceful Degradation:** Handles missing data, small samples,
    convergence issues
5.  **No Silent Degradation:** Uses "refuse rather than guess"
    philosophy
6.  **Plain-English Output:** Non-statisticians can understand results

### Module Independence

This module is **fully standalone**. It does NOT use: -
`modules/shared/lib/validation_utils.R` -
`modules/shared/lib/config_utils.R` -
`modules/shared/lib/data_utils.R` - Any other shared Turas
infrastructure

Benefits: - External review can focus solely on `modules/catdriver/` -
Module can be extracted and used independently - No risk of breaking
changes from shared library updates

------------------------------------------------------------------------

## File Structure {#file-structure}

### Directory Layout

```         
modules/catdriver/
├── R/
│   ├── 00_main.R              # Entry point, orchestration
│   ├── 01_config.R            # Configuration loading
│   ├── 02_validation.R        # Data loading and validation
│   ├── 03_preprocessing.R     # Variable type detection, contrasts
│   ├── 04_analysis.R          # Model dispatcher
│   ├── 04a_ordinal.R          # Ordinal logistic (clm/polr)
│   ├── 04b_multinomial.R      # Multinomial logistic (multinom)
│   ├── 05_importance.R        # Chi-square importance calculation
│   ├── 06_output.R            # Excel workbook generation
│   ├── 06a_sheets_summary.R   # Summary sheet formatting
│   ├── 06b_sheets_detail.R    # Detail sheet formatting
│   ├── 07_utilities.R         # Helper functions
│   ├── 08_guard.R             # Refusal mechanism
│   ├── 08a_guards_hard.R      # Hard validation guards
│   ├── 08b_guards_soft.R      # Soft warning guards
│   ├── 09_mapper.R            # Term-to-level mapping
│   └── 10_missing.R           # Missing data handling
├── run_catdriver_gui.R        # Shiny GUI launcher
├── examples/basic/            # Example files
├── tests/test_data/           # Test datasets
└── docs/                      # Documentation
    ├── 01_README.md
    ├── 02_CATDRIVER_OVERVIEW.md
    ├── 03_REFERENCE_GUIDE.md
    ├── 04_USER_MANUAL.md
    ├── 05_TECHNICAL_DOCS.md   # This file
    ├── 06_TEMPLATE_REFERENCE.md
    ├── 07_EXAMPLE_WORKFLOWS.md
    └── templates/
```

### Source Order (Manual Loading)

Files must be loaded in this order:

``` r
source("modules/catdriver/R/07_utilities.R")     # No dependencies
source("modules/catdriver/R/08_guard.R")         # Uses: 07_utilities
source("modules/catdriver/R/08a_guards_hard.R")  # Uses: 08_guard
source("modules/catdriver/R/08b_guards_soft.R")  # Uses: 08_guard
source("modules/catdriver/R/01_config.R")        # Uses: 07, 08
source("modules/catdriver/R/02_validation.R")    # Uses: 07, 08
source("modules/catdriver/R/03_preprocessing.R") # Uses: 07, 08
source("modules/catdriver/R/09_mapper.R")        # Uses: 07, 08
source("modules/catdriver/R/10_missing.R")       # Uses: 07, 08
source("modules/catdriver/R/04_analysis.R")      # Uses: 07, 08
source("modules/catdriver/R/04a_ordinal.R")      # Uses: 07, 08
source("modules/catdriver/R/04b_multinomial.R")  # Uses: 07, 08
source("modules/catdriver/R/05_importance.R")    # Uses: 07, 08
source("modules/catdriver/R/06a_sheets_summary.R") # Uses: 07
source("modules/catdriver/R/06b_sheets_detail.R")  # Uses: 07
source("modules/catdriver/R/06_output.R")        # Uses: 07, 06a, 06b
source("modules/catdriver/R/00_main.R")          # Uses: all above
```

### External Dependencies

| Package    | Required    | Purpose                              |
|------------|-------------|--------------------------------------|
| MASS       | Yes         | `polr()` for ordinal logistic        |
| nnet       | Yes         | `multinom()` for multinomial         |
| car        | Yes         | `Anova()` Type II tests, `vif()`     |
| openxlsx   | Yes         | Excel reading/writing                |
| ordinal    | Recommended | `clm()` for ordinal (primary engine) |
| brglm2     | Recommended | Firth correction for separation      |
| haven      | Optional    | SPSS/Stata file support              |
| shiny      | GUI only    | Web application framework            |
| shinyFiles | GUI only    | File browser widgets                 |

------------------------------------------------------------------------

## Data Flow Pipeline {#data-flow-pipeline}

### Main Pipeline

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
         ├─── order_spec provided ────────► Ordinal Logistic (polr/clm)
         │
         ├─── is.ordered(outcome) ────────► Ordinal Logistic (polr/clm)
         │
         ├─── is.numeric(outcome) ────────► Ordinal Logistic + warning
         │
         └─── else (3+ unordered) ────────► Multinomial Logistic (multinom)
```

------------------------------------------------------------------------

## Core Components {#core-components}

### Configuration Loader (01_config.R)

``` r
load_catdriver_config <- function(config_file, project_root = NULL)
```

**Purpose:** Parse Excel configuration file.

**Validation:** - Required sheets exist (Settings, Variables) - Required
columns present - File paths resolve correctly - Variable types valid

**Returns:** Named list with all config parameters.

### Data Validation (02_validation.R)

``` r
validate_catdriver_data <- function(data, config)
```

**Checks:** - Missing data rates per variable - Outcome category
counts - Driver variable distributions - Small cell detection - Events
per predictor - Weight variable validity

**Returns:** Diagnostics list with `passed` boolean.

### Preprocessing (03_preprocessing.R)

``` r
preprocess_catdriver_data <- function(data, config)
```

**Actions:** - Convert outcome to appropriate factor type - Set
reference levels for factors - Apply treatment contrasts (not
polynomial) - Build model formula - Calculate effective sample sizes

**Returns:** List with prepared data, outcome_info, predictor_info,
formula.

### Model Dispatcher (04_analysis.R)

``` r
run_catdriver_model <- function(prep_data, config, weights)
```

**Dispatches to:** - `run_binary_logistic()` - 2 categories -
`run_ordinal_logistic()` - ordered 3+ - `run_multinomial_logistic()` -
unordered 3+

**Returns:** Model object, coefficients, fit statistics.

### Importance Calculator (05_importance.R)

``` r
calculate_importance <- function(model_result, config)
```

**Method:** Type II Wald chi-square via `car::Anova()`.

**Fallback:** Uses z-values if Anova fails.

**Returns:** Data frame sorted by importance %.

### Output Generator (06_output.R)

``` r
write_catdriver_output <- function(results, config, output_file)
```

**Creates:** 6-sheet Excel workbook (or 4 if detailed_output=FALSE).

------------------------------------------------------------------------

## Error Handling Strategy {#error-handling-strategy}

### The Refusal Mechanism

All user-fixable errors use `catdriver_refuse()` instead of `stop()`:

``` r
catdriver_refuse(
  reason = "CFG_FILE_NOT_FOUND",
  title = "CONFIG FILE NOT FOUND",
  problem = "File does not exist: ...",
  why_it_matters = "Cannot proceed without configuration",
  fix = "Check the path and re-run."
)
```

Refusals are caught by `with_refusal_handler()` at top level.

### Error Categories

| Category               | Handling |
|------------------------|----------|
| Config not found       | Refuse   |
| Missing required sheet | Refuse   |
| Variable not in data   | Refuse   |
| Insufficient sample    | Refuse   |
| Missing package        | Refuse   |
| Separation (no brglm2) | Refuse   |
| Unmapped coefficients  | Refuse   |
| Model non-convergence  | Warning  |
| High missing data      | Warning  |
| Small cells            | Warning  |

### Strict Mapping Validation

The term-to-level mapper (09_mapper.R) uses **positional mapping**:

1.  Uses `attr(model.matrix, "assign")` for column-to-term mapping
2.  No guessing - if coefficient unmapped, refuse
3.  Polynomial contrast detection - refuse if `.L/.Q/.C` patterns found
4.  Column count verification before proceeding

------------------------------------------------------------------------

## Configuration Schema {#configuration-schema}

### Settings Sheet

| Setting | Type | Default | Validation |
|----|----|----|----|
| analysis_name | string | "Key Driver Analysis" | Non-empty |
| data_file | path | \- | Must exist |
| output_file | path | \- | Directory must exist |
| outcome_type | enum | "auto" | auto/binary/ordinal/nominal |
| reference_category | string | First alpha | Must exist in outcome |
| min_sample_size | integer | 30 | ≥ 1 |
| confidence_level | numeric | 0.95 | 0 \< x \< 1 |
| missing_threshold | numeric | 50 | 0-100 |
| detailed_output | boolean | TRUE | TRUE/FALSE |

### Variables Sheet

| Column       | Required | Validation            |
|--------------|----------|-----------------------|
| VariableName | Yes      | Must exist in data    |
| Type         | Yes      | Outcome/Driver/Weight |
| Label        | Yes      | Non-empty             |
| Order        | No       | Semicolon-separated   |

**Constraints:** - Exactly 1 Outcome - At least 1 Driver - At most 1
Weight

### Driver_Settings Sheet

| Column           | Required | Validation                                 |
|------------------|----------|--------------------------------------------|
| driver           | Yes      | Must match Driver in Variables             |
| type             | Yes      | categorical/ordinal/binary                 |
| reference_level  | No       | Must exist in data                         |
| missing_strategy | No       | drop_row/missing_as_level/error_if_missing |

------------------------------------------------------------------------

## Extension Points {#extension-points}

### Adding New Model Types

1.  Create `04c_new_model.R` in R/
2.  Add detection logic in `detect_outcome_type()` (03_preprocessing.R)
3.  Create `run_new_model()` function
4.  Add case to switch in `run_catdriver_model()`
5.  Ensure coefficient extraction matches expected format

### Adding New Output Sheets

1.  Create function in 06_output.R or new file
2.  Call from `write_catdriver_output()`
3.  Update sheet count in documentation

### Adding New Settings

1.  Add to Settings sheet validation in 01_config.R
2.  Extract with default in `load_catdriver_config()`
3.  Document in 06_TEMPLATE_REFERENCE.md

### Supporting New Data Formats

1.  Add format to `load_catdriver_data()` switch (02_validation.R)
2.  Create `load_format_data()` helper
3.  Handle format-specific labelled variables

------------------------------------------------------------------------

## Testing Guidelines {#testing-guidelines}

### Test Scenarios

| Scenario        | Config            | Expected                       |
|-----------------|-------------------|--------------------------------|
| Binary outcome  | 2 categories      | Binary logistic, all sheets    |
| Ordinal outcome | 3+ with Order     | Ordinal logistic, PO check     |
| Nominal outcome | 3+ unordered      | Multinomial logistic           |
| Missing data    | 20%+ missing      | Warning, correct N             |
| Small sample    | N \< 50           | Warning about events/predictor |
| Small cells     | Some \< 5         | Warning in diagnostics         |
| Separation      | Perfect predictor | Firth or refuse                |
| Non-convergence | Many predictors   | Warning, continues             |

### Test Data Files

| File                                       | Type    | Purpose     |
|--------------------------------------------|---------|-------------|
| examples/basic/employment_satisfaction.csv | Ordinal | Main demo   |
| tests/test_data/binary_outcome.csv         | Binary  | Binary path |

### Validation Checklist

-   [ ] Config loads without error
-   [ ] Data loads from CSV, XLSX, SAV
-   [ ] Missing data correctly reported
-   [ ] Outcome type correctly detected
-   [ ] Reference levels correctly set
-   [ ] Model converges
-   [ ] Importance sums to 100%
-   [ ] Odds ratios match coefficients
-   [ ] Excel output opens in Excel
-   [ ] All 6 sheets present (detailed mode)

------------------------------------------------------------------------

## Maintenance Guide {#maintenance-guide}

### Version Update Procedure

1.  Update version in:

    -   `00_main.R` header and console output
    -   All documentation files

2.  Update date in all documentation

3.  Test all happy paths

4.  Update CHANGELOG if maintained

### Dependency Updates

If updating R package dependencies:

1.  Test with minimum supported version
2.  Update version table in documentation
3.  Verify no breaking API changes

### Code Quality Checks

Before release:

-   [ ] No hardcoded paths
-   [ ] All functions documented
-   [ ] Error messages actionable
-   [ ] Console output informative
-   [ ] Excel output formatted correctly

### Known Limitations

**Statistical:** - No weighted ordinal/multinomial (limited) - No robust
standard errors - No interaction terms - No multiple imputation

**Technical:** - Memory-bound for \>100K rows - Multinomial slow with
\>10 categories - GUI has no progress bar or cancellation

------------------------------------------------------------------------

## Additional Resources

-   [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods
-   [04_USER_MANUAL.md](04_USER_MANUAL.md) - User guide
-   [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Configuration
-   [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) - Examples

------------------------------------------------------------------------

**Part of the Turas Analytics Platform**
