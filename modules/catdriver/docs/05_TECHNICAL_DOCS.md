---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Categorical Key Driver Module - Technical Documentation

**Version:** 12.0 **Last Updated:** 3 March 2026 **Target
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
│   ├── 06c_sheets_subgroup.R   # Subgroup Excel sheets
│   ├── 07_utilities.R         # Helper functions
│   ├── 08_guard.R             # Refusal mechanism
│   ├── 08a_guards_hard.R      # Hard validation guards
│   ├── 08b_guards_soft.R      # Soft warning guards
│   ├── 09_mapper.R            # Term-to-level mapping
│   ├── 10_missing.R           # Missing data handling
│   └── 11_subgroup_comparison.R # Subgroup comparison logic
├── lib/
│   └── html_report/           # HTML report generation pipeline
│       ├── 00_html_guard.R          # Input validation for HTML report
│       ├── 01_data_transformer.R    # Results → HTML-ready data structures
│       ├── 02_table_builder.R       # HTML table generators
│       ├── 03_page_builder.R        # Page layout, sections, CSS
│       ├── 04_html_writer.R         # File writer (self-contained HTML)
│       ├── 05_chart_builder.R       # SVG chart generators (forest, bar)
│       ├── 06_comparison_report.R   # Multi-outcome comparison report
│       ├── 07_unified_report.R      # Unified tabbed multi-analysis report
│       ├── 08_subgroup_report.R    # Subgroup HTML section
│       ├── 99_html_report_main.R    # Entry point for HTML report generation
│       └── js/                      # Client-side JavaScript
│           ├── cd_insights.js       # Insight/annotation pinning
│           ├── cd_navigation.js     # Section nav, scroll, tab switching
│           ├── cd_pinned_views.js   # Pinned section management
│           ├── cd_slide_export.js   # PNG slide export from pinned views
│           ├── cd_unified_tabs.js   # Unified report tab controller
│           └── cd_utils.js          # Shared JS utilities
├── run_catdriver_gui.R        # Shiny GUI (single + multi-config)
├── examples/basic/            # Example files
├── tests/test_data/           # Test datasets
└── docs/                      # Documentation
    ├── 01_README.md
    ├── 03_REFERENCE_GUIDE.md
    ├── 04_USER_MANUAL.md
    ├── 05_TECHNICAL_DOCS.md   # This file
    ├── 06_TEMPLATE_REFERENCE.md
    ├── 07_EXAMPLE_WORKFLOWS.md
    ├── 08_BOOTSTRAP_GUIDE.md
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
| htmltools  | HTML report | HTML tag generation for reports       |

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
│ 10. Prob Lifts  │  calculate_probability_lift()
│   (00_main)     │  → Returns: probability lift df
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 11. Write Output│  write_catdriver_output()
│    (06_output)  │  → Creates: Excel workbook
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 12. HTML Report │  generate_catdriver_html_report()
│ (99_html_report)│  → Creates: self-contained HTML
└─────────────────┘
```

### Subgroup Pipeline Branch (Optional)

When `subgroup_var` is set, the pipeline branches after Step 3:

1. **Subgroup detection** — identifies distinct groups from the subgroup variable
2. **Per-group loop** — Steps 4-10 run independently for each subgroup (plus Total) inside `run_catdriver_steps_4_to_10()`
3. **Comparison** — `build_subgroup_comparison()` produces importance matrix, driver classification, OR comparison, model fit summary, and insights
4. **Output integration** — Subgroup sheets added to Excel; subgroup section added to HTML report

Failed subgroups receive PARTIAL status but do not prevent other groups from completing.

### Model Selection Logic

The model is determined by the **mandatory** `outcome_type` config setting:

```
config$outcome_type
         │
         ├─── "binary"       ──────────► Binary Logistic (glm)
         │
         ├─── "ordinal"      ──────────► Ordinal Logistic (clm/polr)
         │
         └─── "multinomial"  ──────────► Multinomial Logistic (multinom)
```

**Note:** `auto` detection is no longer supported. The analyst must explicitly declare the outcome type in the config file.

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

### HTML Report Pipeline (lib/html_report/)

``` r
generate_catdriver_html_report <- function(results, config, output_file)
```

**Entry point:** `99_html_report_main.R`

The HTML report pipeline transforms analysis results into a self-contained,
interactive HTML report. It supports single-outcome reports, multi-outcome
comparison reports, and unified tabbed reports.

**Pipeline stages:**

| Stage | File | Purpose |
|-------|------|---------|
| Guard | `00_html_guard.R` | Validates results structure before rendering |
| Transform | `01_data_transformer.R` | Converts R results to HTML-ready data structures |
| Tables | `02_table_builder.R` | Generates HTML tables (importance, OR, patterns, lifts) |
| Charts | `05_chart_builder.R` | Generates inline SVG charts (forest plots, bar charts) |
| Layout | `03_page_builder.R` | Assembles sections, navigation, CSS, diagnostics cards |
| Write | `04_html_writer.R` | Writes self-contained HTML with embedded JS/CSS |
| Comparison | `06_comparison_report.R` | Multi-outcome side-by-side comparison |
| Unified | `07_unified_report.R` | Tabbed report combining multiple analyses |

**Client-side JS** (embedded in output):

| File | Purpose |
|------|---------|
| `cd_navigation.js` | Section nav, scroll tracking, tab switching |
| `cd_insights.js` | Insight/annotation pinning per section |
| `cd_pinned_views.js` | Pinned section management (user-curated views) |
| `cd_slide_export.js` | PNG slide export from pinned views |
| `cd_unified_tabs.js` | Analysis-level tab controller for unified reports |
| `cd_utils.js` | Shared JS utilities |

### Subgroup Comparison (`11_subgroup_comparison.R`)

| Function | Purpose |
|----------|---------|
| `build_subgroup_comparison()` | Master comparison function — takes per-group results, returns structured comparison |
| `build_importance_matrix()` | Creates driver-by-group rank/percentage matrix |
| `classify_drivers()` | Assigns Universal / Segment-Specific / Mixed classification |
| `build_or_comparison()` | Compares OR values across groups, flags notable differences |
| `build_model_fit_summary()` | One row per group with n, R², AIC, convergence |
| `generate_subgroup_insights()` | Auto-generates management-ready insight bullets |

### Subgroup Guards (`08a_guards_hard.R`, `08b_guards_soft.R`)

| Guard | Type | Condition |
|-------|------|-----------|
| `guard_subgroup_not_outcome()` | Hard | REFUSE if subgroup_var == outcome_var |
| `guard_subgroup_not_driver()` | Hard | REFUSE if subgroup_var is in driver_vars |
| `guard_subgroup_exists_in_data()` | Hard | REFUSE if subgroup_var column not in data |
| `guard_subgroup_minimum_levels()` | Hard | REFUSE if < 2 distinct non-NA levels |
| `guard_check_subgroup_sample_size()` | Soft | WARN if group n < subgroup_min_n |
| `guard_check_subgroup_model_failed()` | Soft | Record failure for PARTIAL status |

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
| outcome_type | enum | *(required)* | binary/ordinal/multinomial |
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

### Subgroup Settings (Optional)

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `subgroup_var` | character | NULL | Column name for subgroup splitting |
| `subgroup_min_n` | integer | 30 | Minimum observations per subgroup |
| `subgroup_include_total` | logical | TRUE | Include full-dataset Total analysis |

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

-   [01_README.md](01_README.md) - Quick start and overview
-   [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods
-   [04_USER_MANUAL.md](04_USER_MANUAL.md) - User guide
-   [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Configuration
-   [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) - Examples
-   [08_BOOTSTRAP_GUIDE.md](08_BOOTSTRAP_GUIDE.md) - Bootstrap confidence intervals

------------------------------------------------------------------------

**Part of the Turas Analytics Platform**
