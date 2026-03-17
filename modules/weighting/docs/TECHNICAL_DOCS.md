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
   Excel       Structured     Validated    Raw Weights   Trimmed Wts   Quality    Data + Reports
                 Config         Data                                   Metrics    (Excel + HTML)
```

### 1.3 Dependencies

**Required:**
- readxl: Excel file reading
- openxlsx: Excel writing
- survey: Rim weighting/calibration (required if method=rim)

**Optional:**
- haven: SPSS file reading
- htmltools: HTML report generation
- base64enc: Logo embedding in HTML report

---

## 2. Module Structure

### 2.1 File Organization

```
modules/weighting/
├── run_weighting.R              # Main entry point (CLI + API)
├── run_weighting_gui.R          # Shiny GUI launcher
├── lib/
│   ├── 00_guard.R               # TRS guard system (loaded first)
│   ├── config_loader.R          # Configuration parsing
│   ├── validation.R             # Input validation
│   ├── design_weights.R         # Design weight calculation
│   ├── rim_weights.R            # Rim weighting (survey::calibrate)
│   ├── cell_weights.R           # Cell/interlocked weights
│   ├── trimming.R               # Weight capping/trimming
│   ├── diagnostics.R            # Quality diagnostics
│   ├── output.R                 # Excel report generation
│   └── html_report/             # HTML report pipeline
│       ├── 00_html_guard.R      # Input validation
│       ├── 01_data_transformer.R # Transform results for HTML
│       ├── 02_table_builder.R   # Plain HTML tables
│       ├── 03_page_builder.R    # Full page assembly (CSS, header, tabs, JS)
│       ├── 04_html_writer.R     # Self-contained HTML writer
│       ├── 05_chart_builder.R   # Inline SVG charts
│       ├── 99_html_report_main.R # Orchestrator
│       └── js/
│           └── weighting_navigation.js  # Tab switching + save
├── docs/
│   ├── TECHNICAL_DOCS.md        # This file (developer reference)
│   ├── TEMPLATE_REFERENCE.md    # Config file specification
│   └── CONFIG_EXAMPLE.md        # Configuration guide with examples
├── templates/
│   ├── create_template.R        # Template generator
│   └── Weight_Config_Template.xlsx  # Generated template
├── examples/
│   ├── example1_design_weights/ # Design weight walkthrough
│   ├── example2_rim_weights/    # Rim weight walkthrough
│   ├── example3_combined_weights/ # Design + Rim combined
│   └── example4_cell_weights/   # Cell/interlocked weights
├── tests/
│   ├── testthat.R               # Test runner
│   ├── testthat/                # 306 tests
│   └── fixtures/                # Synthetic test data
└── README.md                    # Primary user documentation
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
| `build_*` | HTML builders | `build_summary_table()` |
| `generate_*` | Report generators | `generate_weighting_html_report()` |

### 2.3 Source Order

Files must be sourced in dependency order:

1. 00_guard.R (TRS guard system - must load first)
2. validation.R (no dependencies)
3. config_loader.R (uses validation.R)
4. design_weights.R (uses validation.R, config_loader.R)
5. rim_weights.R (uses validation.R, config_loader.R)
6. cell_weights.R (uses validation.R, config_loader.R)
7. trimming.R (standalone)
8. diagnostics.R (standalone)
9. output.R (uses diagnostics.R)
10. html_report/99_html_report_main.R (sources its own submodules)

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
8. Load Cell_Targets if any cell weights
9. Load Advanced_Settings if present
10. Load Notes if present
11. Parse HTML report settings

**Return Value:**
```r
list(
  general = list(
    project_name = "...",
    data_file = "...",
    data_file_resolved = "...",       # Absolute path
    id_column = "ResponseID",         # Respondent ID column name
    output_file_resolved = "...",     # Weight lookup file path
    save_diagnostics = TRUE/FALSE,
    html_report = TRUE/FALSE,
    html_report_file_resolved = "...",
    brand_colour = "#1e3a5f",
    accent_colour = "#2aa198",
    researcher_name = "...",          # or NULL
    client_name = "...",              # or NULL
    logo_file_resolved = "...",       # or NULL
    project_root = "..."
  ),
  weight_specifications = data.frame(...),
  design_targets = data.frame(...),     # or NULL
  rim_targets = data.frame(...),        # or NULL
  cell_targets = data.frame(...),       # or NULL
  advanced_settings = data.frame(...),  # or NULL
  notes = data.frame(...),             # or NULL
  config_file = "..."                  # Absolute path
)
```

### 3.2 Validation (validation.R)

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `validate_weight_spec()` | Validate single weight specification |
| `validate_design_config()` | Validate design targets against data |
| `validate_rim_config()` | Validate rim targets against data |
| `validate_cell_config()` | Validate cell targets against data |
| `validate_calculated_weights()` | Post-calculation quality check |

### 3.3 Design Weights (design_weights.R)

**Primary Function:** `calculate_design_weights(data, stratum_variable, population_sizes, verbose)`

**Algorithm:**
```
For each stratum s:
  weight[s] = population_size[s] / sample_size[s]
```

### 3.4 Rim Weights (rim_weights.R)

**Primary Function:** `calculate_rim_weights(data, target_list, ...)`

Uses `survey::calibrate()` for modern calibration with weight bounds applied during fitting.

**Return Value:**
```r
list(
  weights = numeric_vector,
  g_weights = numeric_vector,     # Calibration factors
  converged = logical,
  margins = data.frame(variable, category, target_pct, achieved_pct, diff_pct),
  design = survey.design,         # Full design object
  diagnostics = list(...)
)
```

### 3.5 Cell Weights (cell_weights.R)

**Primary Function:** `calculate_cell_weights(data, cell_targets, cell_variables, verbose)`

**Algorithm:**
```
For each cell c (combination of variable levels):
  weight[c] = (target_proportion * N) / cell_count
```

**Return Value:**
```r
list(
  weights = numeric_vector,
  cell_summary = data.frame(cell, target_pct, sample_count, sample_pct, weight),
  cell_variables = character_vector,
  method = "cell",
  n_cells_defined = integer,
  n_cells_empty = integer,
  n_unmatched = integer
)
```

### 3.6 HTML Report Pipeline (lib/html_report/)

**Entry Point:** `generate_weighting_html_report(weighting_results, output_path, config)`

**Pipeline:**
1. **Guard** (00_html_guard.R) - Validate inputs and htmltools availability
2. **Transform** (01_data_transformer.R) - Convert run_weighting() output to HTML-ready structures
3. **Tables** (02_table_builder.R) - Build summary, diagnostics, margins, strata, cell tables
4. **Charts** (05_chart_builder.R) - Build inline SVG histograms and quality gauges
5. **Page** (03_page_builder.R) - Assemble CSS, header, 3-tab layout, footer, JS
6. **Writer** (04_html_writer.R) - Render to self-contained HTML via htmltools

**Report Tabs:**
- **Summary** - All weights overview, quality gauges, key metrics
- **Weight Details** - Per-weight histograms (with explanatory callout), diagnostics (with metric definitions), margins/strata/cells
- **Method Notes** - Auto-generated method documentation + analyst notes from config + editable comments box
- **Save Report** - Tab-bar button to download the HTML report (preserves editable comments)

**Header Features:**
- Custom logo (base64-embedded from `logo_file` config setting)
- "Prepared by [researcher] for [client]" line (from `researcher_name` / `client_name` settings)
- Project name, record count, weight count, generation date badges

**Hub Integration Meta Tags:**
```html
<meta name="turas-report-type" content="weighting">
<meta name="turas-generated" content="ISO-timestamp">
<meta name="turas-weights" content="N">
```

---

## 4. Mathematical Methods

### 4.1 Design Weight Calculation

**Formula:**
```
w_i = N_s / n_s

Where:
  w_i = weight for respondent i in stratum s
  N_s = population size of stratum s
  n_s = sample size of stratum s
```

### 4.2 Rim Weighting (Raking)

**Algorithm (Iterative Proportional Fitting):**
```
Initialize: w_i = 1 for all i

Repeat until convergence:
  For each target variable v:
    For each category c in v:
      p_c = Σ w_i[i in c] / Σ w_i
      a_c = target_c / p_c
      w_i[i in c] *= a_c

  Check: max(|achieved - target|) < tolerance
```

### 4.3 Cell Weighting

**Formula:**
```
w_c = (target_pct_c / 100) * N / n_c

Where:
  w_c = weight for cell c
  target_pct_c = target percentage for cell c
  N = total sample size
  n_c = number of respondents in cell c
```

### 4.4 Effective Sample Size (Kish Formula)

```
n_eff = (Σ w_i)² / Σ w_i²
```

### 4.5 Design Effect

```
DEFF = n / n_eff
```

- DEFF = 1: No effect (equal weights)
- DEFF = 2: Variance doubled, SE x 1.41
- DEFF = 3: Variance tripled, SE x 1.73

---

## 5. TRS Compliance

### 5.1 Refusal Code Prefixes

| Prefix | Category | Example |
|--------|----------|---------|
| CFG_ | Configuration errors | CFG_MISSING_SHEET |
| DATA_ | Data integrity errors | DATA_MISSING_VALUES |
| IO_ | File/path errors | IO_FILE_NOT_FOUND |
| MODEL_ | Model fitting errors | MODEL_NO_CONVERGENCE |
| PKG_ | Missing dependencies | PKG_SURVEY_MISSING |
| CALC_ | Calculation errors | CALC_PAGE_BUILD_FAILED |

### 5.2 Shared Infrastructure Used

| Function | Source | Purpose |
|----------|--------|---------|
| `turas_refuse()` | shared/lib/trs_refusal.R | Structured refusals |
| `with_refusal_handler()` | shared/lib/trs_refusal.R | Wrap entry points |
| `turas_run_state_new()` | shared/lib/trs_run_state.R | Run tracking |
| `turas_print_start_banner()` | shared/lib/trs_banner.R | Console output |
| `turas_save_workbook_atomic()` | shared/lib/turas_save_workbook_atomic.R | Safe Excel write |
| `turas_excel_escape()` | shared/lib/turas_excel_escape.R | Formula injection prevention |

---

## 6. Data Flow

### 6.1 Main Execution Pipeline

```
run_weighting(config_file)
    │
    ├── load_weighting_config(config_file)
    │       ├── Parse General, Weight_Specifications
    │       ├── Parse Design/Rim/Cell_Targets (as needed)
    │       ├── Parse Advanced_Settings, Notes (if present)
    │       └── Return config object
    │
    ├── Load survey data (CSV/XLSX/SAV)
    │
    ├── For each weight in Weight_Specifications:
    │       ├── If method == "design": calculate_design_weights_from_config()
    │       ├── If method == "rim":    calculate_rim_weights_from_config()
    │       ├── If method == "cell":   calculate_cell_weights_from_config()
    │       ├── apply_trimming_from_config() (if configured)
    │       ├── diagnose_weights()
    │       └── Add weight column to data
    │
    ├── write_weighted_data() (if output_file configured)
    ├── generate_weighting_report() (if save_diagnostics = Y)
    ├── generate_weighting_html_report() (if html_report = Y)
    │
    └── Return result object
```

### 6.2 Result Object

```r
list(
  status = "PASS" | "PARTIAL",
  data = data.frame,               # With weight columns added
  weight_names = c("w1", "w2"),
  weight_results = list(
    w1 = list(
      weights = numeric,
      diagnostics = list(...),
      design_result = list(...),   # or rim_result / cell_result
      trimming_result = list(...)
    )
  ),
  config = list(...),
  output_file = "...",
  diagnostics_file = "...",
  html_report_file = "...",
  run_state = list(...)
)
```

---

## 7. Error Handling

All errors follow TRS format with console visibility for Shiny debugging:

```
================================================================================
  [REFUSE] CFG_MISSING_SHEET: Required Sheet Missing
================================================================================

Problem:
  The 'Cell_Targets' sheet is required but not found in config file.

Why it matters:
  Cell weights cannot be calculated without target percentages.

How to fix:
  1. Add a 'Cell_Targets' sheet to your config file
  2. Include columns for cell variables and target_percent

================================================================================
```

---

## 8. Extension Points

### 8.1 Adding New Weighting Methods

1. Create `lib/new_method.R` with `calculate_new_method_weights()`
2. Add wrapper `calculate_new_method_from_config()`
3. Add validation function
4. Add dispatch case in `run_weighting.R`
5. Update `config_loader.R` if new sheet needed
6. Add tests in `tests/testthat/test_new_method.R`
7. Update HTML report transformer/table builder for new method
8. Update template and documentation

---

## 9. Performance Considerations

Typical execution times (n=1000 respondents):

| Operation | Time |
|-----------|------|
| Config loading | < 1s |
| Data loading | 1-5s |
| Design weights | < 1s |
| Rim weights (3 vars) | 2-5s |
| Cell weights | < 1s |
| Diagnostics | < 1s |
| Excel output | 1-3s |
| HTML report | 1-2s |

---

## 10. Testing

### 10.1 Test Suite: 306 tests

| File | Tests | Coverage |
|------|-------|----------|
| test_guard.R | ~25 | Guard validation |
| test_config_loader.R | ~22 | Config parsing (all sheet types) |
| test_validation.R | ~30 | Data/config validation |
| test_design_weights.R | ~15 | Design weight calculation |
| test_rim_weights.R | ~21 | Rim weight calculation |
| test_cell_weights.R | ~15 | Cell weight calculation |
| test_trimming.R | ~19 | Weight trimming |
| test_diagnostics.R | ~12 | Quality diagnostics |
| test_output.R | ~15 | Excel output |
| test_integration.R | ~12 | End-to-end workflows |
| test_edge_cases.R | ~12 | Boundary conditions |
| test_html_report.R | ~18 | HTML report pipeline |

### 10.2 Running Tests

```r
# All tests
testthat::test_dir("modules/weighting/tests/testthat")

# Specific file
testthat::test_file("modules/weighting/tests/testthat/test_cell_weights.R")
```

---

## References

- Kish, L. (1965). *Survey Sampling*. John Wiley & Sons.
- Deville, J.C. & Sarndal, C.E. (1992). Calibration estimators in survey sampling. *JASA*, 87(418), 376-382.
- Lumley, T. (2010). *Complex Surveys: A Guide to Analysis Using R*. Wiley.

---

*TURAS Weighting Module - Technical Documentation v3.0*
