# Turas Segmentation Module - Technical Documentation

**Version:** 12.0
**Last Updated:** 8 March 2026
**Target Audience:** Developers, Technical Maintainers, Data Scientists

---

## Table of Contents

1. [Module Overview](#module-overview)
2. [Architecture](#architecture)
3. [File Structure](#file-structure)
4. [Core Components](#core-components)
5. [Method Dispatcher](#method-dispatcher)
6. [Guard System](#guard-system)
7. [Data Processing Pipeline](#data-processing-pipeline)
8. [HTML Report Pipeline](#html-report-pipeline)
9. [API Reference](#api-reference)
10. [Extension Points](#extension-points)
11. [GUI Implementation](#gui-implementation)
12. [Testing](#testing)
13. [Maintenance Guide](#maintenance-guide)

---

## Module Overview

### Purpose

The Segment module provides multi-algorithm clustering for market segmentation analysis. It identifies natural groups within survey respondents based on their attitudes, behaviors, or characteristics using K-means, hierarchical clustering, or Gaussian Mixture Models.

### Key Features

**Clustering:**
- K-means with configurable k range and multiple random starts
- Hierarchical clustering with multiple linkage methods
- Gaussian Mixture Models with soft assignments and BIC model selection
- Method dispatcher for unified API across algorithms
- Automatic optimal k selection
- Reproducible results (seed control)

**Data Preparation:**
- Automatic scaling and normalization
- Outlier detection (Z-score, Mahalanobis)
- Missing data handling (listwise deletion, mean/median imputation)
- Variable selection (variance-correlation, factor analysis)

**Validation:**
- Silhouette coefficient
- Elbow method (WCSS)
- Gap statistic
- Calinski-Harabasz index
- Cophenetic correlation (hierarchical)
- BIC (GMM)
- Stability assessment

**Profiling & Enhanced Features:**
- Basic means/frequencies
- Enhanced profiling with ANOVA and eta-squared
- Variable importance ranking
- Classification rules (decision trees)
- Segment action cards
- Executive summary generation

**Output:**
- Excel reports and assignments
- Interactive HTML reports with SVG charts
- Model persistence (.rds)

### Performance

| Dataset Size | Variables | Time (K-means) | Time (Hclust) | Time (GMM) |
|--------------|-----------|-----------------|----------------|-------------|
| 500 respondents | 10 | 5-10 sec | 5-15 sec | 10-20 sec |
| 2,000 respondents | 20 | 15-30 sec | 30-60 sec | 45-90 sec |
| 10,000 respondents | 30 | 60-120 sec | 3-5 min | 3-5 min |

**Scalability:**
- K-means: Up to 50,000 respondents
- Hierarchical: Up to ~15,000 respondents (distance matrix limit)
- GMM: Up to ~20,000 respondents
- All methods: Up to 50 clustering variables, k range 2-20

---

## Architecture

### Design Pattern

Modular Step-Function Pipeline Architecture following the catdriver/keydriver pattern:

```
Guard Init -> Config -> Data Prep -> Hard Guards -> Clustering -> Validation -> Profiling -> Output
                                                        |
                                                   Method Dispatcher
                                                   /      |       \
                                              K-means  Hclust    GMM
```

### Design Principles

1. **Separation of Concerns** - Each numbered file handles one aspect
2. **Method Dispatch** - Unified interface across clustering algorithms
3. **Two-Mode Operation** - Exploration (find k) vs Final (use k)
4. **TRS Compliance** - Structured refusal system, no stop() calls
5. **Guard Layer** - Hard guards (REFUSE) and soft guards (PARTIAL)
6. **Reproducibility** - Seed control for consistent results
7. **Statistical Rigor** - Multiple validation metrics
8. **Extensibility** - Easy to add new methods or features

### Architecture Diagram

```
+---------------------------------------------------------------+
|                   SEGMENT MODULE v11.0                          |
+---------------------------------------------------------------+
|                                                                 |
|  +----------------------------------------------------------+  |
|  | INPUT LAYER                                                |  |
|  |  +-- Survey Data (CSV/Excel/SPSS)                         |  |
|  |  +-- Configuration (Excel)                                |  |
|  +------------------------+-----------------------------------+  |
|                           |                                      |
|  +------------------------v-----------------------------------+  |
|  | GUARD LAYER                                                 |  |
|  |  +-- 00_guard.R      -> TRS framework, segment_refuse()   |  |
|  |  +-- 00a_guards_hard.R -> REFUSE guards (fatal)           |  |
|  |  +-- 00b_guards_soft.R -> PARTIAL guards (degradation)    |  |
|  +------------------------+-----------------------------------+  |
|                           |                                      |
|  +------------------------v-----------------------------------+  |
|  | CONFIGURATION & DATA LOADING                                |  |
|  |  +-- 01_config.R     -> Load & validate config             |  |
|  |  +-- 02_data_prep.R  -> Load & prepare data                |  |
|  |  +-- 02a_variable_selection.R -> Variable selection         |  |
|  |  +-- 02b_outliers.R  -> Outlier detection & handling        |  |
|  +------------------------+-----------------------------------+  |
|                           |                                      |
|  +------------------------v-----------------------------------+  |
|  | CLUSTERING ENGINE (Method Dispatcher)                       |  |
|  |  +-- 03_clustering.R -> Dispatch to method                  |  |
|  |  +-- 03a_kmeans.R    -> K-means implementation              |  |
|  |  +-- 03b_hclust.R    -> Hierarchical clustering             |  |
|  |  +-- 03c_gmm.R       -> Gaussian Mixture Models             |  |
|  +------------------------+-----------------------------------+  |
|                           |                                      |
|  +------------------------v-----------------------------------+  |
|  | VALIDATION                                                  |  |
|  |  +-- 04_validation.R -> Quality metrics                     |  |
|  |  +-- Silhouette, WCSS, Gap, CH, Cophenetic, BIC            |  |
|  +------------------------+-----------------------------------+  |
|                           |                                      |
|  +------------------------v-----------------------------------+  |
|  | PROFILING & ENHANCED FEATURES                               |  |
|  |  +-- 05_profiling.R    -> Basic profiling                   |  |
|  |  +-- 05a_profiling_stats.R -> ANOVA, effect sizes           |  |
|  |  +-- 06_rules.R       -> Classification rules              |  |
|  |  +-- 07_cards.R       -> Segment action cards               |  |
|  |  +-- 12_executive_summary.R -> Narrative insights           |  |
|  +------------------------+-----------------------------------+  |
|                           |                                      |
|  +------------------------v-----------------------------------+  |
|  | OUTPUT                                                      |  |
|  |  +-- 09_output.R      -> Excel output                      |  |
|  |  +-- HTML Report Pipeline (lib/html_report/)               |  |
|  |  +-- Model object (.rds)                                    |  |
|  +------------------------+-----------------------------------+  |
|                           |                                      |
|  +------------------------v-----------------------------------+  |
|  | SCORING                                                     |  |
|  |  +-- 08_scoring.R     -> Classify new data                  |  |
|  +----------------------------------------------------------+  |
|                                                                 |
+---------------------------------------------------------------+
```

### Dependencies

**R Packages:**
```r
# Core (required)
library(stats)          # kmeans(), hclust(), dist()
library(cluster)        # silhouette(), clusGap()
library(openxlsx)       # Formatted Excel output
library(htmltools)      # HTML report generation

# Data I/O
library(readxl)         # Excel reading
library(writexl)        # Excel writing
library(haven)          # SPSS support (optional)

# Clustering methods (optional)
library(mclust)         # GMM clustering (required for method = gmm)
library(fastcluster)    # Faster hclust (optional speedup)

# Enhanced features (optional)
library(rpart)          # Classification rules
library(MASS)           # Discriminant analysis

# Visualization (optional)
library(ggplot2)        # Charts
```

---

## File Structure

### Directory Layout

```
modules/segment/
├── R/                                  # Core analysis code (v11.0)
│   ├── 00_main.R                      # Main orchestrator
│   ├── 00_guard.R                     # TRS guard framework
│   ├── 00a_guards_hard.R             # Hard guards (REFUSE)
│   ├── 00b_guards_soft.R             # Soft guards (PARTIAL)
│   ├── 01_config.R                    # Configuration loading
│   ├── 02_data_prep.R                # Data preparation
│   ├── 02a_variable_selection.R      # Variable selection
│   ├── 02b_outliers.R                # Outlier detection
│   ├── 03_clustering.R               # Method dispatcher
│   ├── 03a_kmeans.R                  # K-means clustering
│   ├── 03b_hclust.R                  # Hierarchical clustering
│   ├── 03c_gmm.R                     # Gaussian Mixture Models
│   ├── 04_validation.R               # Validation metrics
│   ├── 05_profiling.R                # Basic profiling
│   ├── 05a_profiling_stats.R         # Enhanced profiling (ANOVA)
│   ├── 06_rules.R                    # Classification rules
│   ├── 07_cards.R                    # Segment action cards
│   ├── 08_scoring.R                  # New data scoring
│   ├── 09_output.R                   # Excel export
│   ├── 10_utilities.R                # Utilities & quick run
│   ├── 11_lca.R                      # Latent Class Analysis
│   └── 12_executive_summary.R        # Executive summary generator
├── lib/                               # Supporting libraries
│   ├── html_report/                   # HTML report pipeline
│   │   ├── 00_html_guard.R           # Validate HTML inputs
│   │   ├── 01_data_transformer.R     # Results -> HTML data structure
│   │   ├── 02_table_builder.R        # Build HTML tables
│   │   ├── 03_page_builder.R         # Assemble full HTML page
│   │   ├── 04_html_writer.R          # Atomic file writer
│   │   ├── 05_chart_builder.R        # SVG chart generation
│   │   ├── 06_exploration_report.R   # Exploration mode report
│   │   ├── 99_html_report_main.R     # HTML report entry point
│   │   └── js/                        # JavaScript modules
│   │       ├── seg_utils.js           # Shared utilities
│   │       ├── seg_navigation.js      # Sticky nav & section tracking
│   │       ├── seg_pinned_views.js    # Pin, collect, manage views
│   │       └── seg_slide_export.js    # PNG export
│   └── (legacy lib files)            # Pre-v11 library files
├── run_segment.R                      # Entry point (sources R/00_main.R)
├── run_segment_gui.R                  # Shiny GUI
├── tests/                             # Module tests
├── test_data/                         # Test datasets
└── docs/                              # Documentation
```

### File Responsibilities

| File | Purpose | Key Functions |
|------|---------|---------------|
| 00_main.R | Pipeline orchestrator | `turas_segment_from_config()` |
| 00_guard.R | TRS guard framework | `segment_refuse()`, `segment_guard_init()` |
| 00a_guards_hard.R | Fatal guards | `guard_require_valid_method()`, `guard_require_hclust_size()` |
| 00b_guards_soft.R | Degradation guards | Soft validation with PARTIAL status |
| 01_config.R | Config loading | `load_segment_config()`, `format_variable_label()` |
| 02_data_prep.R | Data preprocessing | `prepare_segment_data()` |
| 02a_variable_selection.R | Variable selection | `run_variable_selection()` |
| 02b_outliers.R | Outlier detection | `detect_outliers_zscore()`, `detect_outliers_mahal()` |
| 03_clustering.R | Method dispatcher | `run_clustering()`, `run_exploration_clustering()` |
| 03a_kmeans.R | K-means engine | `run_kmeans_clustering()`, `run_kmeans_dispatch()` |
| 03b_hclust.R | Hierarchical engine | `run_hclust_clustering()`, `run_hclust_dispatch()` |
| 03c_gmm.R | GMM engine | `run_gmm_clustering()`, `run_gmm_dispatch()` |
| 04_validation.R | Validation metrics | `calculate_silhouette()`, `calculate_gap_stat()` |
| 05_profiling.R | Basic profiling | `create_full_segment_profile()` |
| 05a_profiling_stats.R | Statistical tests | `enhanced_profile()`, `test_anova()` |
| 06_rules.R | Classification rules | `generate_segment_rules()` |
| 07_cards.R | Action cards | `generate_segment_cards()` |
| 08_scoring.R | Score new data | `score_new_data()`, `type_respondent()` |
| 09_output.R | Excel output | `write_segment_results()` |
| 10_utilities.R | Utilities & Quick Run | `run_segment_quick()`, `generate_config_template()` |
| 11_lca.R | Latent Class Analysis | `run_lca_analysis()` |
| 12_executive_summary.R | Narrative insights | `generate_segment_executive_summary()` |

---

## Core Components

### Main Orchestrator (00_main.R)

The main orchestrator follows the catdriver/keydriver step-function pattern. Guard state is threaded through all steps, and PARTIAL status tracks degradation.

**Pipeline Steps:**

```
STEP 1: Load & validate configuration  (01_config.R)
STEP 2: Load & prepare data            (02_data_prep.R)
STEP 3: Run hard guards                (00a_guards_hard.R)
STEP 4: Clustering                     (03_clustering.R -> 03a/03b/03c)
STEP 5: Validation metrics             (04_validation.R)
STEP 6: Profiling & enhanced features  (05_profiling.R, 06_rules.R, 07_cards.R, 12_executive_summary.R)
STEP 7: Output                         (09_output.R + lib/html_report/)
```

**Dependency Loading:**

The orchestrator sources all R/ files and shared infrastructure:

```r
# Shared TRS infrastructure
source("modules/shared/lib/trs_run_state.R")
source("modules/shared/lib/trs_banner.R")
source("modules/shared/lib/trs_run_status_writer.R")
source("modules/shared/lib/turas_log.R")

# Shared utilities
source("modules/shared/lib/validation_utils.R")
source("modules/shared/lib/config_utils.R")
source("modules/shared/lib/data_utils.R")
source("modules/shared/lib/logging_utils.R")

# All segment R/ files (00 through 12)
```

---

## Method Dispatcher

### Architecture (03_clustering.R)

The method dispatcher routes to the appropriate clustering algorithm based on `config$method`. All algorithms return a standard result structure for downstream processing.

**Standard Result Structure:**
```r
list(
  clusters      = integer_vector,      # Cluster assignments (1..k)
  k             = integer,             # Number of clusters
  centers       = matrix,              # Cluster centers (k x p)
  method        = "kmeans"|"hclust"|"gmm",
  method_info   = list(...),           # Method-specific diagnostics
  model         = fitted_model_object
)
```

**Method-Specific Extras:**

| Method | Extra Fields |
|--------|-------------|
| K-means | `tot.withinss`, `betweenss`, `size` |
| Hierarchical | `cophenetic_correlation`, `linkage_method`, `dendrogram` |
| GMM | `probabilities` (n x k matrix), `bic`, `model_type`, `uncertainty` |

**Dispatch Flow:**

```
run_clustering(data_list, config, guard)
    |
    +-- guard_require_valid_method(method)
    +-- guard_require_method_packages(method)
    |
    +-- switch(method)
        +-- "kmeans" -> run_kmeans_dispatch()
        +-- "hclust" -> run_hclust_dispatch()
        +-- "gmm"    -> run_gmm_dispatch()
    |
    +-- validate_clustering_result(result, method)
```

---

## Guard System

### TRS v1.1 Integration

The segment module uses a four-file guard architecture:

| File | Purpose | Severity |
|------|---------|----------|
| `00_guard.R` | TRS framework, `segment_refuse()` wrapper, state management | Infrastructure |
| `00a_guards_hard.R` | Fatal guards that REFUSE execution | REFUSE |
| `00b_guards_soft.R` | Non-fatal guards + pre/post orchestrators | PARTIAL |
| `lib/validation/preflight_validators.R` | 15 cross-referential config/data checks | Error/Warning |

### Guard Orchestrators (v12.0)

Guards are collected into two orchestrator functions that mirror the catdriver pattern:

**`segment_guard_pre_analysis(config, data_list)`** - Runs before clustering:
- All hard guards (config, data, method validation)
- Data quality soft guards (missing data, variance, correlation)
- Outlier tracking
- Returns initialized guard state

**`segment_guard_post_clustering(guard, cluster_result, validation_metrics, config)`** - Runs after clustering:
- Cluster size checks
- Silhouette quality assessment
- Stability metric recording
- Returns updated guard state

### Preflight Validation (v12.0)

The preflight system (`lib/validation/preflight_validators.R`) runs 15 cross-referential checks before analysis begins. Unlike guards that throw TRS refusals, preflight validators accumulate issues in an error log and report all problems at once:

1. Data file exists
2. Clustering variables exist in data
3. Clustering variables are numeric
4. Profile variables exist (if specified)
5. ID variable exists
6. ID variable has unique values
7. Sample size adequate for k and p
8. K range is valid
9. Required packages available
10. Per-variable missing data rates
11. Zero/near-zero variance variables
12. High correlation pairs (|r| > 0.95)
13. Outlier configuration consistency
14. Output directory writable
15. Segment names file exists (if specified)

### Hard Guards (REFUSE)

Hard guards prevent execution when critical requirements are not met:

- `guard_require_data_file()` - Data file must exist
- `guard_require_clustering_vars()` - At least 2 numeric variables
- `guard_require_id_variable()` - ID variable must exist and be unique
- `guard_require_sample_size()` - n >= max(100, 30*k, 10*p)
- `guard_require_valid_method()` - Method must be kmeans, hclust, or gmm
- `guard_require_method_packages()` - Required packages installed
- `guard_require_valid_k()` - Valid k range or k_fixed
- `guard_require_valid_solution()` - No empty clusters, minimum size
- `guard_require_hclust_size()` - Dataset under ~15,000 for hclust

### Soft Guards (PARTIAL)

Soft guards allow execution to continue with warnings:

- `guard_check_low_variance()` - Near-zero variance variables
- `guard_check_small_clusters()` - Small or imbalanced clusters
- `guard_check_silhouette_quality()` - Weak cluster separation
- `guard_check_outlier_proportion()` - High outlier rate
- `guard_check_missing_data()` - High missing data per variable
- `guard_check_high_correlation()` - Multicollinearity
- `guard_check_variable_selection()` - Significant variable reduction

### segment_refuse() Pattern

```r
segment_refuse(
  code = "CFG_INVALID_METHOD",
  title = "Unsupported Clustering Method",
  problem = sprintf("Method '%s' is not implemented.", method),
  why_it_matters = "Only supported methods can produce valid results.",
  how_to_fix = "Use one of: kmeans, hclust, gmm"
)
```

All refusals are logged to console with structured formatting and returned as TRS-compliant list structures.

---

## Data Processing Pipeline

### Complete Flow

```
1. LOAD CONFIG
   +-- Read Excel, parse settings, set defaults
   +-- Validate method, linkage, GMM model type

2. LOAD DATA
   +-- Read survey file, validate columns

3. HANDLE MISSING
   +-- Listwise deletion (default)
   +-- Mean/median imputation

4. SCALE DATA
   +-- Z-score standardization

5. DETECT OUTLIERS (optional)
   +-- Z-score method
   +-- Mahalanobis method

6. VARIABLE SELECTION (optional)
   +-- Variance-correlation filtering
   +-- Factor analysis

7. RUN HARD GUARDS
   +-- Validate method packages, sample size, data types

8. RUN CLUSTERING (via dispatcher)
   +-- K-means: Hartigan-Wong algorithm with nstart restarts
   +-- Hierarchical: Distance matrix + linkage + cut tree
   +-- GMM: EM algorithm via mclust

9. CALCULATE METRICS
   +-- Silhouette
   +-- WCSS (elbow)
   +-- Gap statistic (optional)
   +-- Calinski-Harabasz
   +-- Method-specific metrics (cophenetic, BIC)

10. PROFILE SEGMENTS
    +-- Means and index scores
    +-- ANOVA tests and effect sizes
    +-- Variable importance

11. ENHANCED FEATURES (optional)
    +-- Classification rules
    +-- Segment action cards
    +-- Stability assessment
    +-- Executive summary

12. EXPORT RESULTS
    +-- Assignments Excel (ID + segment_id + segment_name + GMM probs)
    +-- Report Excel (multi-tab)
    +-- HTML Report (interactive)
    +-- Model RDS
```

---

## HTML Report Pipeline

### Pipeline Architecture (6-Step Process)

```
99_html_report_main.R        Entry point / orchestrator
  |
  +-- 00_html_guard.R        Step 1: Validate inputs
  |                            - htmltools package installed?
  |                            - results object valid?
  |                            - output path writable?
  |
  +-- 01_data_transformer.R  Step 2: Transform results
  |                            - Flatten nested results into html_data structure
  |                            - Extract segment sizes, profiles, validation metrics
  |                            - Prepare data for chart and table builders
  |
  +-- 02_table_builder.R     Step 3: Build HTML tables
  |                            - Overview table (segment sizes)
  |                            - Profile table (means with index colouring)
  |                            - Validation metrics table
  |                            - Rules table
  |                            - GMM membership table
  |
  +-- 05_chart_builder.R     Step 4: Build SVG charts
  |                            - Segment sizes bar chart
  |                            - Silhouette per-cluster bar chart
  |                            - Variable importance bar chart
  |                            - Profile heatmap
  |
  +-- 03_page_builder.R      Step 5: Assemble full page
  |                            - Generate CSS (with brand colour injection)
  |                            - Build header, nav, sections, footer
  |                            - Inline all JavaScript
  |                            - Honour section visibility flags
  |
  +-- 04_html_writer.R       Step 6: Write to disk
  |                            - Atomic write (.tmp -> rename)
  |                            - Create output directory if needed
  |
  +-- 06_exploration_report.R  Alternative path
                                - Exploration mode HTML report
                                - Elbow plot, silhouette chart, metrics table
                                - Solution preview cards
```

### Design System

- **CSS namespace:** All classes prefixed with `seg-` to prevent collisions
- **CSS variables:** `--seg-brand`, `--seg-accent` injected from config
- **Self-contained:** All CSS, JS, and SVG inlined in the output HTML file
- **Responsive:** Grid layouts collapse on narrow viewports

### JavaScript Modules

| File | Purpose |
|------|---------|
| `seg_utils.js` | Shared utility functions |
| `seg_navigation.js` | Sticky nav bar with IntersectionObserver |
| `seg_pinned_views.js` | Pin charts/tables to workspace |
| `seg_slide_export.js` | PNG export via canvas rendering |

---

## API Reference

### Main Entry Point

```r
turas_segment_from_config(config_file, data_file = NULL, output_folder = NULL)
```

**Arguments:**
- `config_file`: Path to configuration Excel file
- `data_file`: Override data file path (optional)
- `output_folder`: Override output folder (optional)

**Returns:** List with segmentation results (TRS-compliant)

### Quick Run Function

```r
run_segment_quick(
  data,
  id_var,
  clustering_vars,
  k = NULL,
  k_range = 3:6,
  profile_vars = NULL,
  output_folder = "output/",
  seed = 123,
  question_labels = NULL,
  standardize = TRUE,
  nstart = 50,
  outlier_detection = FALSE,
  missing_data = "listwise_deletion",
  segment_names = "auto"
)
```

**Returns:**

*Exploration Mode (k = NULL):*
```r
list(
  mode = "exploration",
  recommendation = list(recommended_k, ...),
  metrics = list(metrics_df, ...),
  models = list(...),
  output_files = list(report = "path/to/report.xlsx"),
  config = list(...)
)
```

*Final Mode (k = integer):*
```r
list(
  mode = "final",
  k = integer,
  model = model_object,
  clusters = integer_vector,
  segment_names = character_vector,
  validation = list(avg_silhouette, ...),
  profiles = list(...),
  output_files = list(assignments, report, model),
  config = list(...)
)
```

### Scoring Function

```r
score_new_data(model_file, new_data, id_variable, output_file = NULL)
```

**Returns:** Data frame with segment assignments and confidence

### Single Respondent Typing

```r
type_respondent(answers, model_file)
```

**Returns:** List with segment, name, confidence

### HTML Report Generation

```r
generate_segment_html_report(results, config, output_path)
```

**Called automatically from the main pipeline when `html_report = TRUE`.**

---

## Extension Points

### Adding New Clustering Methods

1. Create `R/03d_[method].R` following the pattern in 03a/03b/03c
2. Implement `run_[method]_clustering()` and `run_[method]_dispatch()`
3. Return the standard clustering result structure
4. Add method to the switch statement in `R/03_clustering.R`
5. Add package guard in `R/00a_guards_hard.R` if new dependency needed
6. Update `R/01_config.R` to recognize the new method name

### Adding New Validation Metrics

1. Add function to `R/04_validation.R`
2. Update the metrics collection in the main pipeline
3. Add to HTML report table builder if needed
4. Add to exploration report metrics comparison

### Adding New Profiling Statistics

1. Add function to `R/05a_profiling_stats.R`
2. Update the enhanced profile report builder
3. Add sheet to Excel output in `R/09_output.R`

### Adding New HTML Report Sections

1. Add data extraction in `lib/html_report/01_data_transformer.R`
2. Add table/chart builder functions
3. Add section assembly in `lib/html_report/03_page_builder.R`
4. Add config flag (`html_show_[section]`) in `R/01_config.R`

---

## GUI Implementation

### Architecture

The GUI uses Shiny with a 5-step workflow:

```r
# run_segment_gui.R structure
ui <- fluidPage(
  # Step 1: File selection
  # Step 2: Validation
  # Step 3: Run button (with method/HTML report options)
  # Step 4: Console output (static)
  # Step 5: Results display
)

server <- function(input, output, session) {
  # Reactive values for state
  # Event handlers for buttons
  # Console capture with sink()
}
```

### Console Output System

**R 4.2+ Compatibility:**

```r
# Console output captured with sink() to temporary file
# Display in verbatimTextOutput (static, not reactive)

observe_analysis <- function() {
  temp_output <- tempfile()
  sink(temp_output, split = TRUE)

  tryCatch({
    result <- turas_segment_from_config(config_file)
  }, finally = {
    sink()
  })

  console_text <- readLines(temp_output)
  return(console_text)
}
```

### Known GUI Patterns

1. **Console in static UI** - Not in reactive results panel
2. **Progress outside sink()** - Progress$new must be outside sink blocks
3. **Safe conditional checks** - Use `nchar(output[1])` not `nchar(output)`

---

## Testing

### Test Data

Located in `test_data/`:
- `test_survey.csv` - Standard test data
- `test_varsel.csv` - Variable selection test
- `test_outliers.csv` - Outlier detection test

### Test Scenarios

| Scenario | Config | Expected |
|----------|--------|----------|
| K-means exploration | method=kmeans, k_min=3, k_max=5 | 3 solutions compared |
| Hierarchical final | method=hclust, k_fixed=4, linkage=ward.D2 | Single solution with profiles |
| GMM final | method=gmm, k_fixed=4 | Solution with probabilities |
| Variable selection | 20 vars, selection=TRUE | Reduced to 10 vars |
| Outlier detection | outlier=TRUE | Outliers flagged/removed |
| HTML report | html_report=TRUE | Self-contained HTML file |

### Running Tests

```r
# Run all segment tests
testthat::test_dir("modules/segment/tests")

# Run specific test file
testthat::test_file("modules/segment/tests/testthat/test_clustering.R")
```

### Demo Showcase

A comprehensive demo project is available in `examples/segment/demo_showcase/`:

```r
source("examples/segment/demo_showcase/run_demo.R")
```

This generates synthetic data and runs all three clustering methods with HTML reports.

---

## Maintenance Guide

### Common Maintenance Tasks

**Adding New Config Parameter:**
1. Add parsing and default in `R/01_config.R`
2. Document in `docs/06_TEMPLATE_REFERENCE.md`
3. Update template Excel files in `docs/templates/`
4. Add guard if validation needed

**Updating Validation Thresholds:**
1. Locate in `R/04_validation.R`
2. Update threshold values
3. Update documentation

**Fixing GUI Issues:**
1. Check R version compatibility (4.2+ patterns)
2. Verify sink() blocks don't contain Progress calls
3. Test with fresh R session

### Performance Optimization

**Large Datasets:**
- Use `data.table` for data operations
- Reduce nstart if acceptable (K-means)
- Use `fastcluster` for hierarchical clustering
- Limit k_max range
- Sample for gap statistic calculation

**Memory Management:**
- Remove intermediate objects with `rm()`
- Use `gc()` after large operations
- Hierarchical clustering: distance matrix is O(n^2) memory

### Version History

**v11.0 (March 2026) - Multi-Algorithm + HTML Reports**

Major upgrade adding multi-algorithm support and interactive HTML reporting:

*New Capabilities:*
- Hierarchical clustering with multiple linkage methods (03b_hclust.R)
- Gaussian Mixture Models with soft assignments (03c_gmm.R)
- Method dispatcher for unified API (03_clustering.R)
- Interactive HTML reports with SVG charts (lib/html_report/)
- Executive summary generator (12_executive_summary.R)
- Classification rules (06_rules.R)
- Segment action cards (07_cards.R)
- Stability assessment

*Architecture Changes:*
- Code moved from `lib/` to `R/` directory with numbered files
- Step-function pipeline following catdriver/keydriver pattern
- Three-file guard system (00_guard.R, 00a_guards_hard.R, 00b_guards_soft.R)
- TRS v1.1 compliance throughout

*New Config Parameters:*
- `method` (kmeans/hclust/gmm)
- `linkage_method`, `gmm_model_type`
- `html_report`, `brand_colour`, `accent_colour`, `report_title`
- `html_show_*` visibility flags
- `generate_rules`, `generate_action_cards`, `run_stability_check`
- `auto_name_style`, `scale_max`, `rules_max_depth`, `stability_n_runs`

*Backward Compatibility:*
- `run_segment.R` entry point unchanged
- Quick run API (`run_segment_quick()`) unchanged
- Default method is kmeans, preserving existing behavior
- Legacy lib/ files retained alongside new R/ directory

**v10.1 (December 2024) - segment_utils.R Refactoring**

Refactoring of `segment_utils.R` for improved maintainability. Extracted `run_segment_quick()` from 423 lines to ~60 lines orchestrator with 5 internal helper functions.

---

## Additional Resources

- [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods
- [04_USER_MANUAL.md](04_USER_MANUAL.md) - User guide
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Configuration
- [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) - Examples
- [08_HTML_REPORT_GUIDE.md](08_HTML_REPORT_GUIDE.md) - HTML report reference

---

**Part of the Turas Analytics Platform**
