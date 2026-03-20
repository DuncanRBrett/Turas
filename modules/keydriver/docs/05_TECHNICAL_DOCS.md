# Turas Key Driver Analysis Module -- Technical Documentation

**Version:** 10.4
**Last Updated:** 20 March 2026
**Target Audience:** Developers, Technical Maintainers, Data Scientists

------------------------------------------------------------------------

## Table of Contents

1.  [Architecture Overview](#architecture-overview)
2.  [File Structure](#file-structure)
3.  [Data Flow Pipeline](#data-flow-pipeline)
4.  [Core Components](#core-components)
5.  [Step Functions (v10.3+)](#step-functions)
6.  [Analytical Features](#analytical-features)
7.  [SHAP Submodule](#shap-submodule)
8.  [Quadrant / IPA Submodule](#quadrant-submodule)
9.  [HTML Report Pipeline](#html-report-pipeline)
10. [Error Handling Strategy](#error-handling-strategy)
11. [Configuration Schema](#configuration-schema)
12. [Extension Guide](#extension-guide)
13. [Testing](#testing)
14. [Performance](#performance)
15. [Maintenance Guide](#maintenance-guide)

------------------------------------------------------------------------

## Architecture Overview {#architecture-overview}

### Design Principles

1.  **Config-Driven:** All analysis parameters come from an Excel
    configuration file. No hardcoded analytical decisions.
2.  **Relative Paths:** Works with OneDrive/cloud-synced folders.
    All file paths are resolved relative to the config file directory.
3.  **Graceful Degradation:** Optional features (SHAP, Quadrant) use
    configurable `on_fail` policies -- either refuse outright or
    continue with PARTIAL status.
4.  **No Silent Failures:** Uses the TRS v1.1 refusal framework.
    Every error produces an actionable, structured refusal message
    printed to the R console.
5.  **Mixed Predictor Support:** v10.3 requires explicit
    `DriverType` declarations per driver. Categorical predictors are
    encoded with treatment contrasts and aggregated at the driver
    level using term mapping.
6.  **Modular Sub-Analyses:** SHAP and Quadrant live in dedicated
    subdirectories with their own source files, sourced on demand.

### Module Independence

The keydriver module uses Turas shared TRS infrastructure
(`modules/shared/lib/trs_*.R`) for run-state tracking, banners, and
the run-status writer. If shared infrastructure is unavailable, the
module falls back to local implementations. The core analytical
logic has no external Turas dependencies.

### High-Level Architecture

```
                     +---------------------+
                     |   Excel Config      |
                     | (Settings,Variables)|
                     +----------+----------+
                                |
                                v
+-------------------------------+-------------------------------+
|                     00_main.R  Orchestrator                   |
|  step_load_config -> step_load_and_validate_data              |
|  -> step_calculate_correlations -> step_fit_model             |
|  -> step_calculate_importance                                 |
|  -> [SHAP]  -> [Quadrant]  -> determine_run_status            |
|  -> write_keydriver_output_enhanced                            |
|  -> [HTML Report]                                             |
+------+------------------+------------------+---------+--------+
       |                  |                  |         |
       v                  v                  v         v
  +---------+      +-----------+      +----------+ +----------+
  |00_guard |      |01_config  |      |02_valid  | |02_term   |
  |TRS layer|      |Config load|      |Data load | |mapping   |
  +---------+      +-----------+      +----------+ +----------+
       |                                    |
       v                                    v
  +---------+      +----------+      +-----------+
  |03_analy |----->|04_output |      |kda_shap/  |
  |5 methods|      |Excel 7sh |      |6 files    |
  +---------+      +----------+      +-----------+
       |                                    |
       v                                    v
  +---------+      +----------+      +-----------+
  |05_boot  |      |06_effect |      |kda_quad/  |
  |strap CI |      |size      |      |6 files    |
  +---------+      +----------+      +-----------+
       |                |
       v                v
  +---------+      +----------+
  |07_segmnt|      |08_exec   |
  |compare  |      |summary   |
  +---------+      +----------+
       |                |
       v                v
  +---------+      +----------+
  |09_elasti|      |10_nca    |
  |c_net    |      |NCA       |
  +---------+      +----------+
       |                |
       v                v
  +---------+      +----------+
  |11_domin |      |12_gam    |
  |ance     |      |nonlinear |
  +---------+      +----------+
                        |
                        v
               +------------------+
               | lib/html_report/ |
               | 8 R + 4 JS files|
               +------------------+
```

------------------------------------------------------------------------

## File Structure {#file-structure}

### Directory Layout

```
modules/keydriver/
├── R/
│   ├── 00_guard.R                 # TRS guard layer, refusal wrapper, guard state
│   ├── 00_main.R                  # Main orchestration, step functions, entry point
│   ├── 01_config.R                # Configuration loading, validation, policy parsing
│   ├── 02_term_mapping.R          # Term-to-driver mapping for mixed predictors
│   ├── 02_validation.R            # Data loading and validation
│   ├── 03_analysis.R              # Core statistical engine (5 importance methods)
│   ├── 04_output.R                # Excel workbook generation (7 sheets)
│   ├── 05_bootstrap.R             # Bootstrap confidence intervals
│   ├── 06_effect_size.R           # Effect size classification / interpretation
│   ├── 07_segment_comparison.R    # Cross-segment driver comparison
│   ├── 08_executive_summary.R     # Plain-English summary generator
│   ├── 09_elastic_net.R           # Elastic Net variable selection via glmnet
│   ├── 10_nca.R                   # Necessary Condition Analysis via NCA package
│   ├── 11_dominance.R             # Dominance Analysis via domir package
│   ├── 12_gam.R                   # GAM nonlinear effects via mgcv
│   ├── kda_methods/
│   │   └── method_shap.R          # SHAP orchestrator (entry point for SHAP pipeline)
│   ├── kda_shap/
│   │   ├── shap_model.R           # XGBoost model fitting
│   │   ├── shap_calculate.R       # TreeSHAP value calculation, data preparation
│   │   ├── shap_visualize.R       # SHAP plots (bar, beeswarm, waterfall, dependence)
│   │   ├── shap_segment.R         # Segment-level SHAP comparison
│   │   ├── shap_interaction.R     # SHAP interaction analysis
│   │   └── shap_export.R          # SHAP results to Excel sheets
│   └── kda_quadrant/
│       ├── quadrant_main.R        # Quadrant/IPA orchestration
│       ├── quadrant_data_prep.R   # Importance/performance extraction, normalization
│       ├── quadrant_calculate.R   # Quadrant assignment, thresholds, gap analysis
│       ├── quadrant_plot.R        # Quadrant chart generation (ggplot2)
│       ├── quadrant_comparison.R  # Segment-level quadrant comparison
│       └── quadrant_export.R      # Quadrant results to Excel sheets
├── lib/
│   └── html_report/
│       ├── 00_html_guard.R        # Input validation for HTML report
│       ├── 01_data_transformer.R  # Results -> HTML-ready data structures
│       ├── 02_table_builder.R     # 9 HTML table generators
│       ├── 03_page_builder.R      # Page layout, CSS, section assembly
│       ├── 04_html_writer.R       # File writer (self-contained HTML)
│       ├── 05_chart_builder.R     # 6 inline SVG chart generators
│       ├── 06_quadrant_section.R  # Quadrant HTML section builder
│       ├── 99_html_report_main.R  # HTML report entry point
│       └── js/
│           ├── kd_navigation.js   # Section nav, scroll spy, anchor links
│           ├── kd_pinned_views.js # Pinned section management
│           ├── kd_slide_export.js # PNG slide export from pinned views
│           └── kd_utils.js        # Shared JS utilities
├── tests/
│   ├── run_tests.R                # Test runner
│   ├── testthat/
│   │   ├── test_guard.R           # Guard layer / refusal tests
│   │   ├── test_config.R          # Config loading tests
│   │   ├── test_core_importance.R # Importance calculation tests
│   │   ├── test_term_mapping.R    # Term mapping tests
│   │   ├── test_edge_cases.R      # Edge case / boundary tests
│   │   ├── test_bootstrap.R       # Bootstrap CI tests
│   │   ├── test_effect_size.R     # Effect size classification tests
│   │   ├── test_segment_comparison.R # Segment comparison tests
│   │   ├── test_executive_summary.R  # Executive summary tests
│   │   ├── test_quadrant.R        # Quadrant analysis tests
│   │   └── test_html_report.R     # HTML report pipeline tests
│   └── fixtures/
│       └── generate_test_data.R   # Synthetic test data generator
├── docs/
│   ├── 01_README.md
│   ├── 02_KEYDRIVER_OVERVIEW.md
│   ├── 03_REFERENCE_GUIDE.md
│   ├── 04_USER_MANUAL.md
│   ├── 05_TECHNICAL_DOCS.md       # This file
│   ├── 06_TEMPLATE_REFERENCE.md
│   ├── 07_EXAMPLE_WORKFLOWS.md
│   └── templates/
│       └── KeyDriver_Config_Template.xlsx
└── examples/
```

### File-by-File Reference

| File | Lines (approx) | Purpose | Key Functions |
|------|--------|---------|---------------|
| `00_guard.R` | ~520 | TRS guard layer, refusal wrapper, guard state tracking | `keydriver_refuse()`, `keydriver_guard_init()`, `validate_keydriver_config()`, `validate_keydriver_data()`, `validate_keydriver_mapping()`, `guard_validate_model_assumptions()` |
| `00_main.R` | ~790 | Main entry point, step functions, orchestration | `run_keydriver_analysis()`, `step_load_config()`, `step_load_and_validate_data()`, `step_calculate_correlations()`, `step_fit_model()`, `step_calculate_importance()`, `handle_optional_feature()`, `determine_run_status()` |
| `01_config.R` | ~700 | Config loading, driver declaration validation, feature policies | `load_keydriver_config()`, `validate_driver_declarations()`, `parse_feature_policies()`, `get_setting()`, `get_driver_type()`, `get_aggregation_method()` |
| `02_term_mapping.R` | ~490 | Term-to-driver coefficient mapping, encoding policy | `build_term_mapping()`, `validate_term_mapping()`, `enforce_encoding_policy()`, `has_categorical_predictors()`, `validate_driver_type_consistency()` |
| `02_validation.R` | ~240 | Data loading, format detection, missing data handling | `load_keydriver_data()`, `coerce_numeric_safe()` |
| `03_analysis.R` | ~980 | Five importance methods, mixed predictor aggregation | `calculate_importance_scores()`, `calculate_shapley_values()`, `calculate_relative_weights()`, `calculate_beta_weights()`, `calculate_correlations()`, `calculate_importance_mixed()`, `calculate_partial_r2()`, `calculate_importance_permutation()` |
| `04_output.R` | ~440 | Excel workbook generation (7 sheets) | `write_keydriver_output()`, `calculate_vif()` |
| `05_bootstrap.R` | ~200 | Bootstrap confidence intervals for importance | `bootstrap_driver_importance()` |
| `06_effect_size.R` | ~150 | Effect size classification (Cohen's f2, beta, r) | `get_effect_size_benchmarks()`, `classify_effect_size()`, `interpret_effect_sizes()` |
| `07_segment_comparison.R` | ~300 | Cross-segment importance comparison | `build_importance_comparison_matrix()`, `classify_drivers()`, `generate_segment_insights()`, `run_segment_importance_comparison()` |
| `08_executive_summary.R` | ~250 | Plain-English summary generation | `generate_executive_summary()` |
| `09_elastic_net.R` | ~200 | Elastic Net variable selection via glmnet | `run_elastic_net()`, `extract_elastic_net_coefs()` |
| `10_nca.R` | ~180 | Necessary Condition Analysis via NCA package | `run_nca_analysis()`, `format_nca_results()` |
| `11_dominance.R` | ~200 | Dominance Analysis via domir package | `run_dominance_analysis()`, `format_dominance_results()` |
| `12_gam.R` | ~220 | GAM nonlinear effects via mgcv | `run_gam_analysis()`, `extract_gam_smooth_terms()` |
| `kda_methods/method_shap.R` | ~150 | SHAP pipeline orchestrator | `run_shap_analysis()` |
| `kda_shap/shap_model.R` | ~120 | XGBoost model fitting with CV | `fit_shap_model()` |
| `kda_shap/shap_calculate.R` | ~100 | TreeSHAP calculation, data prep | `prepare_shap_data()`, `encode_features()`, `create_feature_map()` |
| `kda_shap/shap_visualize.R` | ~200 | SHAP plot generation | `generate_shap_plots()`, `create_importance_bar()`, `create_beeswarm()`, `create_dependence_plots()`, `create_waterfall_plots()` |
| `kda_shap/shap_segment.R` | ~120 | Segment-level SHAP comparison | `run_segment_shap()` |
| `kda_shap/shap_interaction.R` | ~100 | SHAP interaction analysis | `analyze_shap_interactions()`, `calculate_interaction_matrix()` |
| `kda_shap/shap_export.R` | ~150 | SHAP results to Excel | `export_shap_to_excel()`, `insert_shap_charts_to_excel()` |
| `kda_quadrant/quadrant_main.R` | ~120 | IPA orchestration | `create_quadrant_analysis()` |
| `kda_quadrant/quadrant_data_prep.R` | ~120 | Importance/performance extraction | `extract_importance_scores()`, `extract_performance_scores()`, `normalize_importance()` |
| `kda_quadrant/quadrant_calculate.R` | ~120 | Quadrant assignment, thresholds | `prepare_quadrant_data()`, `calculate_thresholds()`, `assign_quadrants()` |
| `kda_quadrant/quadrant_plot.R` | ~150 | Quadrant chart generation | `create_quadrant_plot()`, `create_gap_chart()` |
| `kda_quadrant/quadrant_comparison.R` | ~100 | Segment-level quadrant comparison | `compare_quadrants_by_segment()` |
| `kda_quadrant/quadrant_export.R` | ~120 | Quadrant results to Excel | `export_quadrant_to_excel()`, `insert_quadrant_charts_to_excel()` |

### External Dependencies

| Package | Required | Purpose |
|---------|----------|---------|
| openxlsx | Yes | Excel reading/writing (no Java dependency) |
| stats | Yes (base) | `lm()`, `cor()`, `complete.cases()`, `as.formula()` |
| utils | Yes (base) | `combn()`, `read.csv()` |
| grDevices | Yes (base) | PNG chart generation for Excel |
| graphics | Yes (base) | Bar chart generation for Excel |
| tools | Yes (base) | `file_ext()` for format detection |
| haven | Optional | SPSS (.sav) and Stata (.dta) file support |
| xgboost | SHAP only | Gradient boosted tree models |
| shapviz | SHAP only | TreeSHAP calculation and plots |
| ggplot2 | SHAP/Quadrant | Visualization framework |
| htmltools | HTML report | HTML tag generation |
| parallel | SHAP only | Multi-core model training |
| shiny | GUI only | Web application framework |
| glmnet | >= 4.1.0, Elastic Net | Elastic Net / Lasso / Ridge variable selection |
| NCA | >= 3.2.0, NCA only | Necessary Condition Analysis |
| domir | >= 1.0.0, Dominance | Dominance Analysis decomposition |
| mgcv | Recommended, GAM | Generalized Additive Models for nonlinear effects |
| base64enc | >= 0.1, HTML report | Base64 encoding for embedded images |

------------------------------------------------------------------------

## Data Flow Pipeline {#data-flow-pipeline}

### Main Pipeline

```
+-------------------+
| 1. Load Config    |  step_load_config()
|    (01_config)    |  -> Returns: config list, file paths, feature flags
+--------+----------+
         |
         v
+-------------------+
| 2. Load Data      |  step_load_and_validate_data()
|  (02_validation)  |  -> Returns: data list, encoding report
|  (02_term_mapping)|  -> Detects mixed predictors, applies encoding
+--------+----------+
         |
         v
+-------------------+
| 3. Correlations   |  step_calculate_correlations()
|    (03_analysis)  |  -> Returns: correlation matrix, collinearity warnings
+--------+----------+
         |
         v
+-------------------+
| 4. Fit Model      |  step_fit_model()
|    (03_analysis)  |  -> Returns: lm model, term_mapping (if mixed)
|  (02_term_mapping)|  -> Builds + validates coefficient-to-driver map
+--------+----------+
         |
         v
+-------------------+
| 5. Importance     |  step_calculate_importance()
|    (03_analysis)  |  -> Returns: importance data frame (5 methods)
+--------+----------+
         |
    +----+----+
    |         |
    v         v
+--------+ +--------+
| 6.SHAP | | 7.Quad |  handle_optional_feature()
|(on_fail| |(on_fail|  -> Applies refuse / continue_with_flag policy
| policy)| | policy)|
+---+----+ +---+----+
    |          |
    +----+-----+
         |
         v
+-------------------+
| 8. Run Status     |  determine_run_status()
|                   |  -> PASS or PARTIAL with degraded reasons
+--------+----------+
         |
         v
+-------------------+
| 9. Excel Output   |  write_keydriver_output_enhanced()
|    (04_output)    |  -> 7 sheets + SHAP sheets + Quadrant sheets
+--------+----------+
         |
         v
+-------------------+
| 10. HTML Report   |  generate_kd_html_report()
| (lib/html_report) |  -> Self-contained HTML file
+-------------------+
```

### Mixed Predictor Branch

When `has_categorical_predictors()` detects non-numeric drivers, the
pipeline activates the mixed predictor path:

1.  **Encoding** -- `enforce_encoding_policy()` converts factors and
    characters to treatment-coded dummies. Polynomial contrasts are
    forbidden by default.
2.  **Term Mapping** -- After model fitting, `build_term_mapping()`
    maps every model coefficient back to its originating driver
    variable. `validate_term_mapping()` is a TRS gate: any unmapped
    or missing terms trigger a hard refusal.
3.  **Aggregated Importance** -- `calculate_importance_mixed()` computes
    term-level betas and relative weights, then aggregates to
    driver level using `sum(|beta_term|)`.
4.  **Correlations** -- Only numeric drivers are included in the
    correlation matrix; categorical drivers receive `NA` for
    correlation-based metrics.

### Feature Failure Policies (v10.3)

Optional features (SHAP, Quadrant) declare an `on_fail` policy in
the config Settings sheet:

| Policy | Behaviour |
|--------|-----------|
| `refuse` (default) | Feature failure halts the entire analysis with a TRS refusal |
| `continue_with_flag` | Feature failure is recorded; analysis continues with PARTIAL status |

The `handle_optional_feature()` function enforces this policy
uniformly for both SHAP and Quadrant.

### Advanced Analysis Extensions (v10.4)

Version 10.4 adds four optional advanced analysis steps. Each is
gated by an `enable_*` config flag and runs **after** the core
analysis pipeline (step 5 -- importance). Results are stored in
the main results list under their respective keys.

```
         step_calculate_importance()
                    |
         +----------+----------+----------+
         |          |          |          |
         v          v          v          v
    [Elastic    [NCA]     [Dominance] [GAM]
     Net]       (10_nca)  (11_domin)  (12_gam)
    (09_elast)
         |          |          |          |
         v          v          v          v
  results$     results$   results$   results$
  elastic_net  nca        dominance  gam
```

| Feature | Config Flag | File | Results Key |
|---------|------------|------|-------------|
| Elastic Net | `enable_elastic_net` | `09_elastic_net.R` | `results$elastic_net` |
| NCA | `enable_nca` | `10_nca.R` | `results$nca` |
| Dominance Analysis | `enable_dominance` | `11_dominance.R` | `results$dominance` |
| GAM Nonlinear | `enable_gam` | `12_gam.R` | `results$gam` |

All four features use the same `handle_optional_feature()` mechanism
as SHAP and Quadrant, respecting their respective `on_fail` policies.

------------------------------------------------------------------------

## Core Components {#core-components}

### Guard Layer (00_guard.R)

The guard layer is the first file sourced and provides the TRS
refusal mechanism for the entire module.

**Key Functions:**

```r
keydriver_refuse(code, title, problem, why_it_matters, how_to_fix, ...)
```

Module-specific wrapper around `turas_refuse()`. Ensures all refusal
codes carry a valid TRS prefix (`CFG_`, `DATA_`, `IO_`, `MODEL_`,
`MAPPER_`, `PKG_`, `FEATURE_`, `BUG_`). Calls are non-returning --
they raise a condition that is caught by
`keydriver_with_refusal_handler()`.

```r
keydriver_guard_init()
```

Creates the guard state object. In addition to the standard Turas
guard fields, adds keydriver-specific tracking: `excluded_drivers`,
`zero_variance_drivers`, `collinearity_warnings`, `shap_status`,
`quadrant_status`, `assumption_violations`, `encoding_issues`.

```r
validate_keydriver_config(config)
```

Hard validation gate. Refuses if outcome variable is missing,
fewer than 2 drivers are specified, or other config invariants are
violated.

```r
validate_keydriver_data(data, config, guard)
```

Hard validation gate for data quality. Checks variable existence,
sample size (`n >= max(30, 10k)` where k = number of drivers),
and zero-variance detection.

```r
validate_keydriver_mapping(model, driver_vars, guard)
```

Post-fit validation for numeric-only models. Ensures every model
coefficient maps to a driver and no drivers are missing. This is
a TRS hard refusal on mismatch.

```r
guard_validate_model_assumptions(model, data, config, guard)
```

Soft post-fit checks. Records VIF > 10 and residual non-normality
(Shapiro-Wilk p < 0.01) as guard warnings rather than refusals.

### Configuration Loader (01_config.R)

```r
load_keydriver_config(config_file, project_root = NULL)
```

**Purpose:** Parse the Excel configuration file and return a
validated config list.

**Required Sheets:**

- `Settings` -- Key-value pairs (Setting, Value columns)
- `Variables` -- Variable definitions (VariableName, Type, Label,
  DriverType, AggregationMethod, ReferenceLevel)

**Optional Sheets:**

- `Segments` -- Segment definitions (segment_name,
  segment_variable, segment_values)
- `StatedImportance` -- Stated importance ratings (driver,
  stated_importance)
- `SHAPParameters` -- SHAP-specific settings
- `QuadrantParameters` -- Quadrant-specific settings
- `CustomSlides` -- User-defined qualitative slides for HTML
  report Pinned Views panel (v10.4)

**Returns:**

```r
list(
  config_file     = "/resolved/path/to/config.xlsx",
  settings        = list(analysis_name = "...", data_file = "...", ...),
  outcome_var     = "Q_Overall",
  driver_vars     = c("Q_Service", "Q_Price", "Q_Quality", ...),
  weight_var      = "weight" | NULL,
  variables       = data.frame(...),   # Full Variables sheet
  data_file       = "/resolved/path/to/data.csv",
  output_file     = "/resolved/path/to/output.xlsx",
  project_root    = "/resolved/path/to/project/",
  segments        = data.frame(...) | NULL,
  stated_importance = data.frame(...) | NULL,
  driver_settings = data.frame(driver, driver_type, aggregation_method, reference_level),
  feature_policies = list(
    shap     = list(enabled = TRUE/FALSE, on_fail = "refuse" | "continue_with_flag"),
    quadrant = list(enabled = TRUE/FALSE, on_fail = "refuse" | "continue_with_flag")
  )
)
```

**v10.3 Driver Declarations:**

Each driver in the Variables sheet must have an explicit `DriverType`
column with one of: `continuous`, `ordinal`, `categorical`. Type
inference is no longer permitted. Categorical drivers must also
specify an `AggregationMethod` (defaults to `partial_r2`).

Valid aggregation methods:

| Method | Description |
|--------|-------------|
| `partial_r2` | R-squared contribution of the driver as a whole (default) |
| `grouped_permutation` | Permutation-based importance with grouped shuffling |
| `grouped_shapley` | Shapley decomposition at driver level (requires SHAP enabled) |

### Data Validation (02_validation.R)

```r
load_keydriver_data(data_file, config)
```

**Supported Formats:** CSV, XLSX, SAV (SPSS, requires `haven`),
DTA (Stata, requires `haven`).

**Validation Sequence:**

1.  File existence check
2.  Format detection via file extension
3.  Variable existence check (outcome + drivers + weight)
4.  Numeric coercion with warning for failed conversions
5.  Complete case filtering (outcome + drivers + valid weights)
6.  Sample size check: `n_complete >= max(30, 10 * n_drivers)`
7.  Zero-variance check on all analysis variables

**Returns:**

```r
list(
  data          = data.frame,  # Filtered to complete cases
  n_respondents = integer,
  n_complete    = integer,
  n_missing     = integer
)
```

### Term Mapping (02_term_mapping.R)

This layer handles the critical problem of mapping model
coefficients back to driver variables when the model contains
factor-encoded predictors.

```r
build_term_mapping(formula, data, driver_vars, driver_settings = NULL)
```

Creates a mapping from `model.matrix()` column names to driver
variables. Handles:

-   **Exact matches** -- Continuous drivers (`price` -> `price`)
-   **Prefix matches** -- Factor levels (`genderMale` -> `gender`)
    with level validation against actual data levels
-   **Logical suffixes** -- (`flagTRUE` -> `flag`)

When `driver_settings` is provided (v10.3), predictor types are
read from the config. When NULL, types are inferred from data
(legacy behaviour).

**Returns:**

```r
list(
  term_map       = c(price = "price", genderMale = "gender", ...),
  driver_terms   = list(price = "price", gender = c("genderMale", "genderFemale")),
  predictor_info = data.frame(driver, type, n_terms, reference_level),
  all_terms      = c("price", "genderMale", "genderFemale", ...)
)
```

```r
validate_term_mapping(mapping, driver_vars)
```

TRS gate. Refuses if any driver has zero mapped terms or if any
model term is unmapped. This prevents silently wrong importance
attribution.

```r
enforce_encoding_policy(data, driver_vars, driver_settings, allow_polynomial)
```

Applies treatment contrasts to all factors and ordered factors.
Polynomial contrasts are forbidden by default (trigger a TRS
refusal). Character variables are converted to factors. Logical
variables are converted to `factor(c(FALSE, TRUE))`.

### Analysis Engine (03_analysis.R)

The analysis engine provides five importance methods plus mixed
predictor variants.

#### Method 1: Beta Weights

```r
calculate_beta_weights(model, data, config)
```

Standardized regression coefficients: `beta_std = b * (sd_x / sd_y)`.
Importance is based on `|beta_std|` normalized to sum to 100%.
The signed standardized betas are attached as an attribute for
directional interpretation.

Refuses on aliased (NA) coefficients or zero-variance variables.

#### Method 2: Relative Weights (Johnson 2000)

```r
calculate_relative_weights(model, correlations, config)
```

Decomposes model R-squared into non-negative contributions per
predictor using eigendecomposition of the predictor correlation
matrix. Implementation follows Johnson (2000) and Tonidandel &
LeBreton (2011).

**Algorithm:**

1.  Eigendecompose predictor correlation matrix R_xx
2.  Compute phi = V * sqrt(Lambda) (correlations between X and Z)
3.  Compute r(Z,Y) = Lambda^{-1/2} * V' * r(X,Y)
4.  Relative weight for predictor j = sum over components of
    (phi_jk^2 * r_zk_y^2)
5.  Rescale so weights sum to model R-squared

Refuses on singular or near-singular correlation matrix (eigenvalue
< 1e-6).

#### Method 3: Shapley Value Decomposition

```r
calculate_shapley_values(model, data, config)
```

Game-theoretic R-squared allocation. Evaluates all 2^k subsets of
drivers and calculates each driver's marginal contribution weighted
by coalition size.

**Complexity:** O(2^k) models. Hard limit of k <= 15 drivers (enforced
by TRS refusal).

**Algorithm:**

1.  For each subset of drivers, fit OLS and record R-squared
2.  For each driver i, calculate weighted average of marginal
    contributions across all coalitions not containing i
3.  Weight = |S|! * (k - |S| - 1)! / k!
4.  Normalize to percentages

#### Method 4: Correlations

```r
calculate_correlations(data, config)
```

Zero-order Pearson correlations (or weighted correlations when
weight variable is specified). Returns the signed correlation
between each driver and the outcome.

Weighted correlation uses: `r = cov_w(x,y) / (sd_w(x) * sd_w(y))`

#### Method 5: Partial R-squared (v10.3)

```r
calculate_importance_partial_r2(data, config)
```

Computes the partial R-squared for each driver:
`partial_r2 = (R2_full - R2_reduced) / (1 - R2_reduced)`.
This is the default aggregation method for v10.3 when drivers
have explicit type declarations. Works naturally with both
continuous and categorical drivers.

#### Mixed Predictor Aggregation

```r
calculate_importance_mixed(model, data, config, term_mapping)
```

When mixed predictors are detected, this function replaces the
standard importance calculation. It:

1.  Computes term-level standardized betas and relative weights
2.  Aggregates to driver level: `driver_importance = sum(|beta_term|)`
3.  Determines direction: positive, negative, or mixed (when signs
    differ across terms)
4.  Shapley values are computed at driver level using the original
    formula (factors are naturally handled by `lm()`)

#### Permutation Importance

```r
calculate_importance_permutation(model, data, config, n_permutations = 50)
```

Permutation-based importance for categorical drivers. Shuffles each
driver's values and measures the increase in MSE. For categorical
drivers, all factor levels are permuted together (grouped
permutation).

### Output Generation (04_output.R)

```r
write_keydriver_output(importance, model, correlations, config,
                        output_file, run_status, status_details)
```

Creates a 7-sheet Excel workbook:

| Sheet | Content |
|-------|---------|
| Importance Summary | All importance metrics, labels, rankings |
| Method Rankings | Rank positions from each method + average rank |
| Model Summary | R-squared, adj R-squared, F-stat, p-value, RMSE, N; VIF diagnostics table |
| Correlations | Full correlation matrix |
| Charts | Shapley impact horizontal bar chart (PNG) |
| Run_Status | TRS run status, analysis metadata, driver method notes (v10.3) |
| README | Methodology documentation, interpretation guidelines |

When SHAP or Quadrant results are available,
`write_keydriver_output_enhanced()` appends additional sheets by
loading the workbook and calling `export_shap_to_excel()` or
`export_quadrant_to_excel()`.

------------------------------------------------------------------------

## Step Functions (v10.3) {#step-functions}

Version 10.3 refactored the monolithic orchestrator into named step
functions. Each step is a pure function that receives its inputs
explicitly and returns a structured list. The orchestrator
(`run_keydriver_analysis_impl`) calls each step in sequence and
handles all console output.

### step_load_config()

```r
step_load_config(config_file, data_file, output_file)
```

**Actions:**

1.  Calls `load_keydriver_config()` to parse the Excel config
2.  Calls `validate_keydriver_config()` (TRS hard gate)
3.  Resolves data file and output file paths
4.  Detects `enable_shap` and `enable_quadrant` flags

**Returns:** `list(config, data_file, output_file, enable_shap, enable_quadrant)`

### step_load_and_validate_data()

```r
step_load_and_validate_data(data_file, config)
```

**Actions:**

1.  Calls `load_keydriver_data()` (loads + validates)
2.  Validates driver type consistency (config vs data)
3.  Detects mixed predictors via `has_categorical_predictors()`
4.  Applies encoding policy if mixed predictors detected

**Returns:** `list(data, config, has_mixed)`

### step_calculate_correlations()

```r
step_calculate_correlations(data, config, guard, has_mixed)
```

**Actions:**

1.  If mixed predictors, identifies numeric-only drivers
2.  Computes correlation matrix (numeric drivers only if mixed)
3.  Scans for high collinearity (|r| > 0.9)
4.  Records collinearity warnings in guard state

**Returns:** `list(correlations, guard, degraded_reasons, affected_outputs)`

### step_fit_model()

```r
step_fit_model(data, config, guard, has_mixed)
```

**Actions:**

1.  Fits weighted or unweighted OLS via `fit_keydriver_model()`
2.  If mixed: builds term mapping and validates it
3.  If numeric-only: validates coefficient mapping directly

**Returns:** `list(model, term_mapping, guard)`

### step_calculate_importance()

```r
step_calculate_importance(model, data, config, correlations,
                           term_mapping, has_mixed)
```

**Actions:**

1.  If mixed: calls `calculate_importance_mixed()` (aggregated)
2.  Otherwise: calls `calculate_importance_scores()` (direct)

**Returns:** Importance data frame

### handle_optional_feature()

```r
handle_optional_feature(feature_name, feature_fn, on_fail_policy,
                         refuse_code, guard, guard_tag, affected)
```

Generic handler for optional SHAP or Quadrant features. Wraps
the feature function in `tryCatch()`. On failure:

-   If `on_fail_policy == "refuse"`: raises a TRS refusal
-   If `on_fail_policy == "continue_with_flag"`: records failure
    in guard state, returns NULL, and adds degraded reasons

**Returns:** `list(result, guard, degraded_reasons, affected_outputs)`

### determine_run_status()

```r
determine_run_status(degraded_reasons, affected_outputs, guard)
```

Examines accumulated degraded reasons and guard state to determine
the final TRS run status:

-   **PASS** -- All requested features completed successfully
-   **PARTIAL** -- Some features failed with `continue_with_flag`
    policy; output is degraded but usable

**Returns:** `list(run_status, status, status_details, guard_summary)`

------------------------------------------------------------------------

## Analytical Features {#analytical-features}

### Bootstrap Confidence Intervals (05_bootstrap.R)

```r
bootstrap_driver_importance(data, outcome, drivers, weights = NULL,
                             config = NULL, n_bootstrap = 1000,
                             ci_level = 0.95)
```

Resamples respondent data with replacement (or weighted resampling
when case weights are available) and recalculates importance on
each resample. Returns percentile-based confidence intervals.

**Three methods are bootstrapped:**

1.  **Correlation** -- Pearson correlation between driver and outcome
2.  **Beta_Weight** -- Standardized regression coefficient share
3.  **Relative_Weight** -- Johnson's relative weight decomposition

**Config fields (all optional):**

| Setting | Default | Description |
|---------|---------|-------------|
| `enable_bootstrap` | FALSE | Enable/disable bootstrap CIs |
| `bootstrap_iterations` | 1000 | Number of bootstrap resamples |
| `bootstrap_ci_level` | 0.95 | Confidence level (0-1) |

**Returns:** Data frame with columns: Driver, Method,
Point_Estimate, CI_Lower, CI_Upper, SE, N_Bootstrap.

### Effect Size Interpretation (06_effect_size.R)

```r
get_effect_size_benchmarks(method)
classify_effect_size(value, method)
interpret_effect_sizes(importance_df, model)
```

Classifies driver effects as Negligible, Small, Medium, or Large
using published benchmarks:

| Method | Negligible | Small | Medium | Large |
|--------|-----------|-------|--------|-------|
| Cohen's f2 | < 0.02 | 0.02-0.15 | 0.15-0.35 | > 0.35 |
| Standardized Beta | < 0.05 | 0.05-0.10 | 0.10-0.30 | > 0.30 |
| Correlation | < 0.10 | 0.10-0.30 | 0.30-0.50 | > 0.50 |

### Segment Comparison (07_segment_comparison.R)

```r
run_segment_importance_comparison(results_by_segment)
```

Compares driver importance across customer segments. Provides:

-   **Comparison matrix** -- Wide table with per-segment percentages
    and ranks
-   **Driver classification** -- Labels each driver as Universal,
    Segment-Specific, Mixed, or Low Priority based on rank stability
-   **Segment insights** -- Plain-English insight strings
    (e.g., "Price is the top driver for Budget customers but ranks
    5th for Premium customers")

**Functions:**

| Function | Purpose |
|----------|---------|
| `build_importance_comparison_matrix()` | Builds wide table from per-segment results |
| `classify_drivers()` | Universal / Segment-Specific / Mixed / Low Priority |
| `generate_segment_insights()` | Plain-English insight strings |

### Executive Summary (08_executive_summary.R)

```r
generate_executive_summary(results, config)
```

Generates a structured, human-readable summary from KDA results.

**Returns:**

```r
list(
  headline         = "Service quality is the dominant driver...",
  key_findings     = c("...", "...", "..."),
  method_agreement = "High consensus across all four methods...",
  model_quality    = "Model explains 42% of variance (moderate)...",
  warnings         = c("High VIF for Price and Promotion"),
  recommendations  = c("Focus improvement on Service quality", ...)
)
```

**Configuration:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `top_n` | 3 | Number of top drivers to highlight |
| `dominant_threshold` | 40 | Importance % threshold for "dominant" flag |
| `vif_threshold` | 5 | VIF threshold for multicollinearity warning |
| `r2_thresholds` | low=0.10, moderate=0.30, good=0.50 | R-squared quality bands |

------------------------------------------------------------------------

## SHAP Submodule {#shap-submodule}

### Architecture

The SHAP submodule is spread across 7 files (1 orchestrator + 6
implementation files). Files are sourced on demand when
`enable_shap = TRUE`.

```
kda_methods/method_shap.R       # Orchestrator: run_shap_analysis()
    |
    +-- kda_shap/shap_calculate.R   # Data prep: prepare_shap_data()
    +-- kda_shap/shap_model.R       # Model:     fit_shap_model()
    +-- kda_shap/shap_visualize.R   # Plots:     generate_shap_plots()
    +-- kda_shap/shap_segment.R     # Segments:  run_segment_shap()
    +-- kda_shap/shap_interaction.R # Interact:  analyze_shap_interactions()
    +-- kda_shap/shap_export.R      # Excel:     export_shap_to_excel()
```

### Pipeline

1.  **Data Preparation** (`shap_calculate.R`)
    -   `prepare_shap_data()` extracts outcome, drivers, and weights
    -   `encode_features()` converts factors to numeric (one-hot)
    -   `create_feature_map()` builds a mapping from encoded columns
        back to original driver names

2.  **Model Training** (`shap_model.R`)
    -   `fit_shap_model()` trains an XGBoost model using
        `xgb.cv()` for early stopping
    -   Auto-detects objective: `reg:squarederror` for continuous,
        `binary:logistic` for binary outcomes
    -   Uses multi-core training via `parallel::detectCores()`
    -   Applies configurable hyperparameters (learning rate, depth,
        subsample, colsample)

3.  **SHAP Calculation** (`shap_calculate.R`)
    -   Uses `shapviz::shapviz()` to compute TreeSHAP values
    -   Applies sample size limit (default 1000 rows) for
        computational tractability
    -   Returns a `shapviz` object containing per-observation
        SHAP values

4.  **Visualization** (`shap_visualize.R`)
    -   Generates 6 plot types via `shapviz` + `ggplot2`:
        importance bar, beeswarm, combined importance, dependence
        plots (top drivers), waterfall plots, force plots

5.  **Segment Analysis** (`shap_segment.R`)
    -   `run_segment_shap()` subsets SHAP values by segment
    -   Produces per-segment importance rankings and comparison plots

6.  **Interaction Analysis** (`shap_interaction.R`)
    -   `analyze_shap_interactions()` extracts SHAP interaction values
    -   Builds interaction strength matrix
    -   Identifies top N interaction pairs

7.  **Excel Export** (`shap_export.R`)
    -   `export_shap_to_excel()` writes SHAP_Importance and
        SHAP_Values sheets to the workbook
    -   `insert_shap_charts_to_excel()` inserts plot images

### SHAP Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `shap_model` | "xgboost" | Model type |
| `n_trees` | 100 | Number of boosting rounds (or "auto" for CV) |
| `max_depth` | 6 | Maximum tree depth |
| `learning_rate` | 0.1 | Eta / step size |
| `subsample` | 0.8 | Row subsampling rate |
| `colsample_bytree` | 0.8 | Column subsampling rate |
| `shap_sample_size` | 1000 | Max rows for SHAP calculation |
| `include_interactions` | FALSE | Calculate SHAP interactions |
| `interaction_top_n` | 5 | Top interaction pairs to display |
| `importance_top_n` | 15 | Top drivers for plots |

### SHAP Return Structure

```r
list(
  model        = xgb.Booster,      # Fitted XGBoost model
  shap         = shapviz,           # shapviz object
  importance   = data.frame(        # Driver importance table
    driver, mean_abs_shap, importance_pct, rank
  ),
  plots        = list(              # Named list of ggplot objects
    importance_bar, importance_beeswarm, importance_combined,
    dependence = list(...), waterfalls = list(...), force = list(...)
  ),
  segments     = list(...) | NULL,  # Segment SHAP results
  interactions = list(...) | NULL,  # Interaction analysis
  diagnostics  = list(              # Model diagnostics
    n_trees, best_iteration, train_rmse, cv_rmse
  )
)
```

------------------------------------------------------------------------

## Quadrant / IPA Submodule {#quadrant-submodule}

### Architecture

The Quadrant submodule implements Importance-Performance Analysis (IPA).
It lives in `kda_quadrant/` with 6 files, sourced on demand.

```
kda_quadrant/quadrant_main.R        # Orchestrator
    |
    +-- quadrant_data_prep.R        # Importance/performance extraction
    +-- quadrant_calculate.R        # Quadrant assignment, thresholds
    +-- quadrant_plot.R             # IPA scatter chart (ggplot2)
    +-- quadrant_comparison.R       # Segment-level quadrant comparison
    +-- quadrant_export.R           # Excel export
```

### Pipeline

1.  **Data Preparation** (`quadrant_data_prep.R`)
    -   `extract_importance_scores()` normalizes importance from
        various KDA methods (SHAP, relative weights, beta, correlation)
    -   `extract_performance_scores()` computes mean satisfaction
        scores for each driver from raw data
    -   Both are normalized to 0-100 scale when
        `normalize_axes = TRUE`

2.  **Quadrant Calculation** (`quadrant_calculate.R`)
    -   `prepare_quadrant_data()` merges importance and performance
    -   `calculate_thresholds()` sets quadrant division lines
        using mean, median, midpoint, or custom values
    -   `assign_quadrants()` assigns each driver to a quadrant:

    ```
    High Importance
         |
    Q1   |   Q2
    Concentrate | Keep Up
    Here       | Good Work
    ------+----------+-----> High Performance
    Q3   |   Q4
    Low  | Possible
    Priority | Overkill
         |
    ```

    -   Gap analysis calculates `gap = importance - performance`
        for prioritization

3.  **Visualization** (`quadrant_plot.R`)
    -   `create_quadrant_plot()` generates the IPA scatter chart
        with shaded quadrants, threshold lines, and driver labels
    -   `create_gap_chart()` produces a horizontal bar chart of
        priority gaps

4.  **Segment Comparison** (`quadrant_comparison.R`)
    -   `compare_quadrants_by_segment()` runs IPA for each segment
        and identifies drivers that move between quadrants

5.  **Excel Export** (`quadrant_export.R`)
    -   `export_quadrant_to_excel()` writes Quadrant_Data and
        Quadrant_Actions sheets
    -   `insert_quadrant_charts_to_excel()` inserts chart images

### Quadrant Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `importance_source` | "auto" | Method for importance: auto/shap/relative_weights/regression/correlation |
| `threshold_method` | "mean" | How to set quadrant lines: mean/median/midpoint/custom |
| `normalize_axes` | TRUE | Normalize both axes to 0-100 |
| `shade_quadrants` | TRUE | Add background colour to quadrant areas |
| `label_all_points` | TRUE | Label all drivers (vs top N only) |
| `label_top_n` | 10 | Number to label if not labeling all |
| `show_diagonal` | FALSE | Show iso-priority diagonal line |

### Quadrant Return Structure

```r
list(
  data         = data.frame(        # Per-driver quadrant data
    driver, importance, performance, quadrant, gap, action
  ),
  plots        = list(              # ggplot objects
    quadrant_plot, gap_chart
  ),
  action_table = data.frame(        # Prioritized actions
    driver, quadrant, priority, recommendation
  ),
  gap_analysis = data.frame(        # Gap scores
    driver, gap_score, gap_rank
  ),
  thresholds   = list(x, y),
  segments     = list(...) | NULL   # Segment comparison (if requested)
)
```

------------------------------------------------------------------------

## HTML Report Pipeline {#html-report-pipeline}

### Architecture

The HTML report pipeline lives in `lib/html_report/` and transforms
analysis results into a self-contained, interactive HTML file. The
pipeline follows the same guard -> transform -> build -> write
pattern used by catdriver and tabs modules.

```
99_html_report_main.R               # Entry point, sources all submodules
    |
    +-- 00_html_guard.R             # Input validation
    +-- 01_data_transformer.R       # Results -> HTML-ready structures
    +-- 02_table_builder.R          # 9 HTML table generators
    +-- 05_chart_builder.R          # 6 inline SVG chart generators
    +-- 06_quadrant_section.R       # Quadrant HTML section
    +-- 03_page_builder.R           # Page assembly, CSS, sections
    +-- 04_html_writer.R            # File writer
    |
    +-- js/kd_navigation.js         # Section nav, scroll spy
    +-- js/kd_pinned_views.js       # Pinned section management
    +-- js/kd_slide_export.js       # PNG slide export
    +-- js/kd_utils.js              # Shared utilities
```

### Pipeline Stages

| Stage | File | Input | Output |
|-------|------|-------|--------|
| 1. Guard | `00_html_guard.R` | results, config | Validated inputs (or TRS refusal) |
| 2. Transform | `01_data_transformer.R` | results, config | HTML-ready data structures |
| 3. Build Tables | `02_table_builder.R` | transformed data | htmltools table objects |
| 4. Build Charts | `05_chart_builder.R` | transformed data | Inline SVG strings |
| 5. Build Quadrant | `06_quadrant_section.R` | quadrant data | HTML section |
| 6. Assemble | `03_page_builder.R` | tables, charts, data | Complete HTML page |
| 7. Write | `04_html_writer.R` | HTML page | Self-contained .html file |

### Data Transformer (01_data_transformer.R)

```r
transform_keydriver_for_html(results, config)
```

Converts raw KDA results into a structured format for HTML
rendering. Optional sections are included only when the
corresponding data is present. Returns a list with:

- `importance` -- Per-driver entries with rank, label, pct, method
- `method_comparison` -- Cross-method rank agreement
- `correlations` -- Correlation matrix
- `model_info` -- Model summary statistics
- `vif_values` -- VIF data frame with concern levels
- `effect_sizes` -- Effect size classifications (if available)
- `quadrant_data` -- Quadrant assignments (if available)
- `bootstrap_ci` -- Confidence intervals (if available)
- `segment_comparison` -- Segment results (if available)
- `narrative` -- Auto-generated insights
- `methods_available` -- Which importance methods are present
- `has_shap`, `has_quadrant`, `has_bootstrap` -- Feature flags

### Table Builder (02_table_builder.R)

Generates 9 HTML tables using `htmltools`:

| Table | Function | Description |
|-------|----------|-------------|
| 1. Importance | `build_kd_importance_table()` | Ranked drivers with inline bar visualisations. Top 3 rows highlighted. |
| 2. Method Comparison | `build_kd_method_comparison_table()` | Cross-method rank agreement with consensus assessment |
| 3. Model Summary | `build_kd_model_summary_table()` | Key-value pairs: R-squared, F-stat, RMSE, N |
| 4. Correlation Matrix | `build_kd_correlation_table()` | Colour-coded correlation cells |
| 5. VIF Diagnostics | `build_kd_vif_table()` | Multicollinearity concern flags |
| 6. Effect Size | `build_kd_effect_size_table()` | Badge-style labels (Small / Medium / Large) |
| 7. Quadrant Actions | `build_kd_quadrant_action_table()` | Priority / action mapping per quadrant |
| 8. Bootstrap CI | `build_kd_bootstrap_table()` | Confidence intervals with visual ranges |
| 9. Segment Comparison | `build_kd_segment_table()` | Per-segment ranks with delta indicators |

All table CSS classes and IDs use the `kd-` prefix for Report Hub
namespace isolation.

### Chart Builder (05_chart_builder.R)

Generates 6 inline SVG charts (no external dependencies):

| Chart | Function | Description |
|-------|----------|-------------|
| 1. Importance Bar | `build_kd_importance_bar_chart()` | Horizontal bars ranked by importance |
| 2. Method Comparison | `build_kd_method_comparison_chart()` | Parallel coordinates or radar |
| 3. Correlation Heatmap | `build_kd_correlation_heatmap()` | Colour-coded matrix |
| 4. Effect Size | `build_kd_effect_size_chart()` | Lollipop chart with benchmark bands |
| 5. Bootstrap CI | `build_kd_bootstrap_chart()` | CI range visualisation |
| 6. Quadrant Scatter | `build_kd_quadrant_chart()` | IPA scatter with quadrant shading |

**Design System Compliance:**

- Rounded corners on bars (`rx="4"`)
- Muted colour palette
- Soft charcoal labels (`#64748b`)
- Faint horizontal gridlines (`#e2e8f0`), no outer box
- Font-weight 500 for data values, 400 for axis labels
- No gradients, drop shadows, or hover lift animations

### Page Builder (03_page_builder.R)

```r
build_kd_html_page(html_data, tables, charts, config)
```

Assembles all components into a browsable HTML page. Sections
without data are silently omitted. The page includes:

- Header with analysis name, date, metadata
- Action bar (export, pin views)
- Section navigation sidebar
- Executive summary section
- Importance section (chart + table)
- Method comparison section
- Effect size section
- Correlation section (heatmap + table)
- Quadrant section (if available)
- SHAP section (if available)
- Diagnostics section (model summary + VIF)
- Bootstrap CI section (if available)
- Segment comparison section (if available)
- Elastic Net section (if `enable_elastic_net = TRUE`, v10.4)
- NCA section (if `enable_nca = TRUE`, v10.4)
- Dominance Analysis section (if `enable_dominance = TRUE`, v10.4)
- GAM nonlinear effects section (if `enable_gam = TRUE`, v10.4)
- Interpretation guide
- Pinned views panel (includes CustomSlides if defined, v10.4)
- Footer

**CSS:** Built inline via `build_kd_css()`. Uses the configurable
`brand_colour` (default `#323367`) and `accent_colour` (default
`#CC9900`).

### HTML Writer (04_html_writer.R)

Writes the assembled page as a single self-contained HTML file.
All CSS, SVG, and JavaScript are inlined -- no external dependencies.

### JavaScript Interactivity

| File | Purpose |
|------|---------|
| `kd_navigation.js` | Section navigation sidebar, scroll spy for active section highlighting, smooth anchor scrolling, tab switching |
| `kd_pinned_views.js` | Pin sections for side-by-side comparison. Manages pinned panel visibility and content cloning |
| `kd_slide_export.js` | Export pinned views as PNG slides using html2canvas. Manages export queue and download |
| `kd_utils.js` | Shared utilities: element selection helpers, CSS class toggling, debounce, format helpers |

All JavaScript is inlined into the HTML file. CSS classes and DOM
IDs use the `kd-` prefix to avoid conflicts when embedded in the
Report Hub.

------------------------------------------------------------------------

## Error Handling Strategy {#error-handling-strategy}

### TRS Integration

The keydriver module uses TRS (Turas Refusal System) v1.1 for all
error handling. The key principle: **refuse rather than guess**.

**Refusal Hierarchy:**

```
keydriver_refuse()
    |
    +--> turas_refuse()         # Shared TRS infrastructure
         |
         +--> Raises condition  # Caught by keydriver_with_refusal_handler()
              |
              +--> Console output (boxed format)
              +--> Returns structured refusal list
```

**Refusal Structure:**

```r
list(
  status       = "REFUSED",
  code         = "DATA_INSUFFICIENT_SAMPLE",
  title        = "Insufficient Sample Size",
  problem      = "Only 25 complete cases. Need at least 50.",
  why_it_matters = "Unreliable importance estimates.",
  how_to_fix   = c("Increase sample size", "Reduce drivers"),
  module       = "KEYDRIVER"
)
```

### Error Code Reference

| Code Prefix | Domain | Examples |
|-------------|--------|---------|
| `IO_` | File/input-output | `IO_CONFIG_NOT_FOUND`, `IO_DATA_NOT_FOUND`, `IO_OUTPUT_ERROR`, `IO_TURAS_ROOT_NOT_FOUND` |
| `CFG_` | Configuration | `CFG_OUTCOME_MISSING`, `CFG_DRIVERS_MISSING`, `CFG_INSUFFICIENT_DRIVERS`, `CFG_SETTINGS_SHEET_MISSING`, `CFG_VARIABLES_SHEET_MISSING`, `CFG_DRIVER_TYPE_MISSING`, `CFG_INVALID_DRIVER_TYPE`, `CFG_POLYNOMIAL_CONTRASTS_FORBIDDEN` |
| `DATA_` | Data validation | `DATA_INSUFFICIENT_SAMPLE`, `DATA_ZERO_VARIANCE`, `DATA_VARIABLES_NOT_FOUND`, `DATA_WEIGHT_NOT_FOUND`, `DATA_UNSUPPORTED_FORMAT`, `DATA_DRIVER_TYPE_MISMATCH` |
| `MODEL_` | Model fitting | `MODEL_ALIASED_COEFFICIENTS`, `MODEL_SINGULAR_MATRIX` |
| `MAPPER_` | Term mapping | `MAPPER_COEFFICIENT_MISMATCH`, `MAPPER_TERM_MISMATCH` |
| `PKG_` | Package dependencies | `PKG_HAVEN_REQUIRED` |
| `FEATURE_` | Optional features | `FEATURE_SHAP_FAILED`, `FEATURE_QUADRANT_FAILED`, `FEATURE_SHAP_XGBOOST_MISSING`, `FEATURE_SHAPLEY_TOO_MANY_DRIVERS`, `FEATURE_ELASTIC_NET_FAILED`, `FEATURE_NCA_FAILED`, `FEATURE_DOMINANCE_FAILED`, `FEATURE_GAM_FAILED` |

### Guard State Tracking

The guard state (`keydriver_guard_init()`) accumulates warnings
throughout the pipeline without halting execution:

| Field | Type | Purpose |
|-------|------|---------|
| `excluded_drivers` | character vector | Drivers removed from analysis |
| `zero_variance_drivers` | character vector | Drivers with no variation |
| `collinearity_warnings` | list of lists | High-correlation pairs (var1, var2, r) |
| `shap_status` | character | "not_run", "complete", or "failed" |
| `quadrant_status` | character | "not_run", "complete", or "failed" |
| `assumption_violations` | list of lists | Model assumption issues (VIF, normality) |
| `encoding_issues` | list of lists | Predictor encoding problems |
| `stability_flags` | character vector | Analytical stability concerns |

### Console Output Pattern

Since Turas runs in a Shiny application, all errors must be visible
in the R console:

```
+--- TURAS ERROR -----------------------------------------------+
| Context: KeyDriver Module: Step 2 - Data Validation
| Code: DATA_INSUFFICIENT_SAMPLE
| Message: Only 25 complete cases. Need at least 50.
| Fix: Increase sample size or reduce number of drivers
+---------------------------------------------------------------+
```

------------------------------------------------------------------------

## Configuration Schema {#configuration-schema}

### Settings Sheet

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `analysis_name` | string | "Key Driver Analysis" | Display name for report |
| `data_file` | path | (required) | Path to respondent data file |
| `output_file` | path | auto-generated | Path for Excel output |
| `enable_shap` | boolean | FALSE | Enable SHAP analysis |
| `enable_quadrant` | boolean | FALSE | Enable IPA quadrant analysis |
| `enable_bootstrap` | boolean | FALSE | Enable bootstrap CIs |
| `enable_html_report` | boolean | FALSE | Enable HTML report generation |
| `shap_on_fail` | string | "refuse" | SHAP failure policy: refuse/continue_with_flag |
| `quadrant_on_fail` | string | "refuse" | Quadrant failure policy |
| `bootstrap_iterations` | integer | 1000 | Bootstrap replications |
| `bootstrap_ci_level` | numeric | 0.95 | CI confidence level |
| `n_trees` | integer | 100 | XGBoost boosting rounds |
| `max_depth` | integer | 6 | XGBoost tree depth |
| `learning_rate` | numeric | 0.1 | XGBoost learning rate |
| `shap_sample_size` | integer | 1000 | Max rows for SHAP |
| `include_interactions` | boolean | FALSE | SHAP interaction analysis |
| `importance_source` | string | "auto" | Quadrant importance source |
| `threshold_method` | string | "mean" | Quadrant threshold method |
| `brand_colour` | hex | "#323367" | HTML report brand colour |
| `accent_colour` | hex | "#CC9900" | HTML report accent colour |
| `enable_elastic_net` | boolean | FALSE | Enable Elastic Net variable selection (v10.4) |
| `elastic_net_alpha` | numeric | 0.5 | Elastic Net mixing: 0=ridge, 0.5=elastic net, 1=lasso |
| `elastic_net_nfolds` | integer | 10 | Cross-validation folds for Elastic Net |
| `enable_nca` | boolean | FALSE | Enable Necessary Condition Analysis (v10.4) |
| `enable_dominance` | boolean | FALSE | Enable Dominance Analysis (v10.4) |
| `enable_gam` | boolean | FALSE | Enable GAM nonlinear effects (v10.4) |
| `gam_k` | integer | 5 | Basis dimension for GAM smooth terms |
| `vif_moderate_threshold` | numeric | 5 | VIF threshold for moderate multicollinearity warning |
| `vif_high_threshold` | numeric | 10 | VIF threshold for high multicollinearity warning |

### Variables Sheet

| Column | Required | Valid Values | Description |
|--------|----------|-------------|-------------|
| `VariableName` | Yes | Any string | Column name in data file |
| `Type` | Yes | Outcome, Driver, Weight | Variable role |
| `Label` | Yes | Any string | Human-readable label for output |
| `DriverType` | Yes (drivers) | continuous, ordinal, categorical | v10.3: explicit type declaration |
| `AggregationMethod` | Categorical only | partial_r2, grouped_permutation, grouped_shapley | How to aggregate multi-term importance |
| `ReferenceLevel` | Optional | Any level value | Reference level for categorical encoding |

### Segments Sheet (Optional)

| Column | Required | Description |
|--------|----------|-------------|
| `segment_name` | Yes | Display name for segment |
| `segment_variable` | Yes | Column name in data |
| `segment_values` | Yes | Comma-separated values to include |

### StatedImportance Sheet (Optional)

| Column | Required | Description |
|--------|----------|-------------|
| `driver` | Yes | Driver variable name |
| `stated_importance` | Yes (or any numeric) | Stated importance rating |

### CustomSlides Sheet (Optional, v10.4)

| Column | Required | Description |
|--------|----------|-------------|
| `slide_title` | Yes | Title displayed on the slide |
| `slide_content` | Yes | Slide body text (supports markdown) |
| `slide_image` | No | File path to an image to embed in the slide |
| `slide_order` | No | Integer controlling display order |

Custom slides appear in the HTML report's Pinned Views panel,
allowing analysts to add qualitative commentary, methodology
notes, or contextual slides alongside the auto-generated
analytical sections.

------------------------------------------------------------------------

## Extension Guide {#extension-guide}

### Adding a New Importance Method

1.  **Implement the calculation** in `03_analysis.R`:

    ```r
    #' Calculate Dominance Analysis
    #' @keywords internal
    calculate_dominance_analysis <- function(model, data, config) {
      driver_vars <- config$driver_vars
      # ... implementation ...
      dominance_pct  # Named numeric vector summing to 100
    }
    ```

2.  **Register in `calculate_importance_scores()`**:

    ```r
    # In calculate_importance_scores(), after existing methods:
    importance$Dominance <- calculate_dominance_analysis(model, data, config)
    importance$Dominance_Rank <- rank(-importance$Dominance, ties.method = "average")
    ```

3.  **Update the Average_Rank calculation** to include the new rank
    column.

4.  **Update `04_output.R`** to include the new column in the
    Importance Summary sheet and the README methodology section.

5.  **Update the HTML report** (`01_data_transformer.R` and
    `02_table_builder.R`) to display the new method.

6.  **Add tests** in `tests/testthat/test_core_importance.R`:

    ```r
    test_that("dominance analysis returns valid percentages", {
      result <- calculate_dominance_analysis(model, data, config)
      expect_equal(sum(result), 100, tolerance = 0.01)
      expect_true(all(result >= 0))
    })
    ```

### Adding a New Chart Type to the HTML Report

1.  **Create the chart function** in `05_chart_builder.R`:

    ```r
    #' Build Dominance Analysis Chart
    #' @keywords internal
    build_kd_dominance_chart <- function(html_data) {
      # Use .kd_svg_bar(), .kd_svg_text() helpers
      # Follow design system: rounded corners, muted palette, etc.
      # Return HTML string
    }
    ```

2.  **Call it from the chart builder orchestrator** (or directly from
    `03_page_builder.R`).

3.  **Add a section** in `build_kd_html_page()` in
    `03_page_builder.R`.

4.  **Register the section** in `build_kd_section_nav()` for the
    navigation sidebar.

### Adding a New Table to the HTML Report

1.  **Create the table function** in `02_table_builder.R`:

    ```r
    #' Build Dominance Analysis Table
    #' @keywords internal
    build_kd_dominance_table <- function(data) {
      # Use htmltools::tags$table, tags$tr, tags$th, tags$td
      # Use kd- CSS class prefix
      # Return htmltools tag object
    }
    ```

2.  **Prepare the data** in `01_data_transformer.R` by adding a
    new field to the transformed data list.

3.  **Add the table** to the appropriate section in
    `03_page_builder.R`.

### Adding a New Section to the HTML Report

1.  **Create a section builder** in `03_page_builder.R`:

    ```r
    build_kd_dominance_section <- function(charts, tables) {
      htmltools::tags$section(
        id = "kd-dominance", class = "kd-section",
        htmltools::tags$h2("Dominance Analysis"),
        charts$dominance,
        tables$dominance
      )
    }
    ```

2.  **Register in `build_kd_section_nav()`** by adding an entry to
    the navigation list.

3.  **Add to the page assembly** in `build_kd_html_page()`.

4.  **Add conditional display** -- sections with no data should be
    silently omitted using `if (!is.null(data))` guards.

------------------------------------------------------------------------

## Testing {#testing}

### Test Structure

```
tests/
├── run_tests.R                    # Test runner script
├── testthat/
│   ├── test_guard.R               # TRS guard layer, refusal behaviour
│   ├── test_config.R              # Config loading, validation, driver declarations
│   ├── test_core_importance.R     # 5 importance methods, mixed predictors
│   ├── test_term_mapping.R        # Term mapping, encoding policy
│   ├── test_edge_cases.R          # Boundaries, NAs, single-driver, 15-driver limit
│   ├── test_bootstrap.R           # Bootstrap CI calculation
│   ├── test_effect_size.R         # Effect size classification
│   ├── test_segment_comparison.R  # Segment comparison matrix, insights
│   ├── test_executive_summary.R   # Executive summary generation
│   ├── test_quadrant.R            # Quadrant assignment, thresholds
│   └── test_html_report.R         # HTML report pipeline
└── fixtures/
    └── generate_test_data.R       # Synthetic test data generator
```

### Running Tests

```r
# Run all keydriver tests
testthat::test_dir("modules/keydriver/tests/testthat")

# Run a specific test file
testthat::test_file("modules/keydriver/tests/testthat/test_core_importance.R")

# Run via the test runner script
source("modules/keydriver/tests/run_tests.R")
```

### Test Data Generator

`generate_test_data.R` creates synthetic survey data with configurable:

- Number of respondents (n)
- Number of drivers (k)
- Known importance weights (for validation against truth)
- Optional weight variable
- Optional categorical drivers
- Optional segment variables

### Key Test Categories

**Unit Tests (test_core_importance.R):**
- Shapley values sum to model R-squared
- Relative weights sum to 100%
- Beta weights sum to 100%
- All methods return named vectors matching driver_vars
- Mixed predictor aggregation produces driver-level scores
- Partial R-squared values are in [0, 1]

**Guard Tests (test_guard.R):**
- Missing outcome triggers refusal
- Fewer than 2 drivers triggers refusal
- Missing data file triggers refusal
- Invalid driver type triggers refusal
- Zero-variance variables trigger refusal
- Aliased coefficients trigger refusal

**Edge Case Tests (test_edge_cases.R):**
- 2-driver minimum case
- 15-driver Shapley limit
- Single observation excluded by missing data
- All weights equal (should match unweighted)
- Perfect multicollinearity detection
- Near-singular correlation matrix

**Term Mapping Tests (test_term_mapping.R):**
- Continuous predictors map 1:1
- Factor predictors map k-1 terms to 1 driver
- Mixed predictor mapping covers all terms
- Unmapped terms trigger refusal
- Encoding policy applies treatment contrasts
- Polynomial contrasts trigger refusal

### Test Coverage Goals

- **Current:** ~65% automated
- **Target:** 80%+ for all production code
- **Priority gaps:** SHAP submodule, HTML report pipeline

------------------------------------------------------------------------

## Performance {#performance}

### Execution Times

| Drivers | Sample Size | SHAP | Quadrant | Approximate Time |
|---------|-------------|------|----------|-----------------|
| 5 | 500 | No | No | 1-2 sec |
| 10 | 1,000 | No | No | 5-10 sec |
| 15 | 5,000 | No | No | 30-60 sec |
| 10 | 1,000 | Yes | No | 10-30 sec |
| 10 | 1,000 | Yes | Yes | 15-45 sec |
| 15 | 5,000 | Yes | Yes | 2-3 min |

### Bottlenecks

**Shapley Calculation:**
- Complexity: O(2^k) models
- Hard limit: k <= 15 drivers
- This is the dominant cost for the core pipeline

**SHAP Calculation:**
- XGBoost training time (mitigated by early stopping)
- TreeSHAP calculation (mitigated by sample size limit)
- Plot generation (mitigated by top-N filtering)

**Excel Output:**
- PNG chart generation for embedded images
- VIF calculation (O(k) auxiliary regressions)

### Optimization Opportunities

1.  **Parallel Shapley** -- Coalition R-squared calculations are
    independent and could use `parallel::mclapply()`.
2.  **Approximate Shapley** -- Monte Carlo sampling of permutations
    for k > 15 (planned for future release).
3.  **Cached R-squared** -- The current implementation stores all
    subset R-squared values in a hash table to avoid recalculation.
4.  **SHAP Sampling** -- The `shap_sample_size` parameter (default
    1000) limits the computational cost of TreeSHAP.

------------------------------------------------------------------------

## Maintenance Guide {#maintenance-guide}

### Source Loading Order

When loading the module manually (outside of the Shiny GUI), files
must be sourced in dependency order:

```r
base_dir <- "modules/keydriver/R"

# 1. Guard layer (no dependencies)
source(file.path(base_dir, "00_guard.R"))

# 2. Configuration (uses guard)
source(file.path(base_dir, "01_config.R"))

# 3. Data handling (uses guard)
source(file.path(base_dir, "02_validation.R"))
source(file.path(base_dir, "02_term_mapping.R"))

# 4. Analysis (uses guard)
source(file.path(base_dir, "03_analysis.R"))

# 5. Output (uses guard, analysis)
source(file.path(base_dir, "04_output.R"))

# 6. Optional features (uses guard)
source(file.path(base_dir, "05_bootstrap.R"))
source(file.path(base_dir, "06_effect_size.R"))
source(file.path(base_dir, "07_segment_comparison.R"))
source(file.path(base_dir, "08_executive_summary.R"))

# 6b. v10.4 advanced features (uses guard, analysis)
source(file.path(base_dir, "09_elastic_net.R"))
source(file.path(base_dir, "10_nca.R"))
source(file.path(base_dir, "11_dominance.R"))
source(file.path(base_dir, "12_gam.R"))

# 7. Main orchestrator (uses all above)
source(file.path(base_dir, "00_main.R"))

# SHAP and Quadrant files are sourced on demand by 00_main.R
# HTML report files are sourced on demand by 99_html_report_main.R
```

### Common Maintenance Tasks

**Updating the config template:**

1.  Edit `docs/templates/KeyDriver_Config_Template.xlsx`
2.  Update `01_config.R` to read new settings
3.  Update `06_TEMPLATE_REFERENCE.md`
4.  Add validation in guard layer if the setting is required

**Adding a new config setting:**

1.  Use `get_setting()` with a default value in the code
2.  Document the setting in `06_TEMPLATE_REFERENCE.md` and this file
3.  Add validation if the setting has constraints

**Upgrading a dependency:**

1.  Check `renv.lock` for current version
2.  Install with `renv::install("package@version")`
3.  Test thoroughly (run full test suite)
4.  Update `renv.lock` with `renv::snapshot()`
5.  Document the change

### Known Limitations

1.  **Shapley Limit:** Maximum 15 drivers for exact computation.
    Approximate Shapley (Monte Carlo) is planned but not yet
    implemented.
2.  **Listwise Deletion:** Missing data is handled by removing
    incomplete cases. No imputation option is available.
3.  **Linear Assumption:** The core regression model assumes linear
    relationships. Non-linear effects can only be captured via
    SHAP (XGBoost).
4.  **Weighted Shapley:** Minor inconsistency in subset model
    weighting for the Shapley method. Relative weights and SHAP are
    recommended when weights are used.
5.  **Weighted Beta:** Uses term-level standard deviations from the
    model matrix rather than population-weighted SDs.
6.  **SHAP Dependencies:** Requires `xgboost` and `shapviz` packages
    which may not be available in all environments.

### Weighting Accuracy by Method

| Method | Weighting Status | Recommendation |
|--------|------------------|----------------|
| Correlations | Fully correct | Safe for weighted data |
| Regression (lm) | Fully correct | Safe for weighted data |
| Relative Weights | Fully correct | Recommended for weighted data |
| Beta Weights | Minor inconsistency | Use with caution for weighted data |
| Shapley | Minor inconsistency | Use with caution for weighted data |
| SHAP (XGBoost) | Fully correct | Recommended for weighted data |
| Partial R-squared | Fully correct | Safe for weighted data |

### Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| 10.0 | Dec 2024 | Initial production release. Five importance methods. |
| 10.1 | Dec 2025 | SHAP integration, Quadrant/IPA, Segment comparison, Bootstrap CIs, Effect sizes, Executive summary, HTML report pipeline |
| 10.2 | Dec 2025 | TRS v1.0 integration: refusal framework, guard state, explicit status. No silent failures. |
| 10.3 | Dec 2025 | Explicit driver_type declarations, partial R-squared as primary method, feature on_fail policies, step function refactoring, enhanced output contract |
| 10.4 | Mar 2026 | Elastic Net variable selection (glmnet), Necessary Condition Analysis (NCA), Dominance Analysis (domir), GAM nonlinear effects (mgcv), CustomSlides config sheet, configurable VIF thresholds |

------------------------------------------------------------------------

## References

- Johnson, J. W. (2000). A heuristic method for estimating the
  relative weight of predictor variables in multiple regression.
  *Multivariate Behavioral Research*, 35(1), 1-19.
- Tonidandel, S., & LeBreton, J. M. (2011). Relative importance
  analysis: A useful supplement to regression analysis. *Journal of
  Business and Psychology*, 26(1), 1-9.
- Shapley, L. S. (1953). A value for n-person games. In H. W. Kuhn
  & A. W. Tucker (Eds.), *Contributions to the Theory of Games*
  (Vol. II, pp. 307-317). Princeton University Press.
- Lundberg, S. M., & Lee, S. I. (2017). A unified approach to
  interpreting model predictions. *Advances in Neural Information
  Processing Systems*, 30.
- Martilla, J. A., & James, J. C. (1977). Importance-performance
  analysis. *Journal of Marketing*, 41(1), 77-79.
- Cohen, J. (1988). *Statistical Power Analysis for the Behavioral
  Sciences* (2nd ed.). Lawrence Erlbaum Associates.
