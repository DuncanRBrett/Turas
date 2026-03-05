# Turas Key Driver Analysis Module

**Version:** 10.3
**Last Updated:** 4 March 2026

Identifies which drivers have the greatest impact on key outcomes using multiple statistical methods.

---

## Quick Start

```r
source("modules/keydriver/R/00_main.R")

results <- run_keydriver_analysis(
  config_file = "keydriver_config.xlsx"
)
```

Or use the GUI:
```r
source("launch_turas.R")
# Click "Key Driver" button
```

---

## Features

### Statistical Methods
- **Shapley Value Decomposition** - Game-theoretic fair R-squared allocation
- **Relative Weights** (Johnson 2000) - Handles multicollinearity
- **Beta Weights** - Standardized regression coefficients
- **Standardized Beta** - Effect size interpretation
- **Zero-order Correlations** - Bivariate relationships
- **SHAP Analysis** (XGBoost/TreeSHAP) - Machine learning importance

### Analysis Capabilities
- Survey weights support throughout pipeline
- VIF multicollinearity diagnostics
- Quadrant charts (Importance-Performance Analysis)
- Segment comparison analysis
- Mixed predictors (continuous + categorical)
- Bootstrap confidence intervals (NEW v10.3)
- Effect size interpretation (NEW v10.3)
- Executive summary generation (NEW v10.3)
- Interactive HTML report (NEW v10.3)
- Pinned views and slide export (NEW v10.3)

### Validation
- Smart sample size rules: n >= max(30, 10 x k drivers)
- Zero variance detection
- Aliased predictor handling
- Maximum 15 drivers for exact Shapley
- TRS v1.1 guard layer with structured refusals

---

## Required Files

| File | Purpose |
|------|---------|
| `keydriver_config.xlsx` | Settings, variable definitions, optional segments |
| Data file | Respondent-level survey data (.csv, .xlsx, .sav, .dta) |

See [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) for complete template documentation.

---

## Module Architecture

```
keydriver/
├── R/
│   ├── 00_main.R              # Main orchestration (step functions)
│   ├── 00_guard.R             # TRS v1.1 guard layer
│   ├── 01_config.R            # Configuration loading
│   ├── 02_term_mapping.R      # Mixed predictor term mapping
│   ├── 02_validation.R        # Data validation
│   ├── 03_analysis.R          # Statistical analysis (5 methods)
│   ├── 04_output.R            # Excel output
│   ├── 05_bootstrap.R         # Bootstrap CIs (NEW v10.3)
│   ├── 06_effect_size.R       # Effect size interpretation (NEW v10.3)
│   ├── 07_segment_comparison.R # Enhanced segments (NEW v10.3)
│   ├── 08_executive_summary.R # Executive summary (NEW v10.3)
│   ├── kda_shap/              # SHAP submodule (4 files)
│   └── kda_quadrant/          # Quadrant/IPA submodule (5 files)
├── lib/
│   └── html_report/           # HTML report pipeline (NEW v10.3)
│       ├── 00_html_guard.R    # Input validation
│       ├── 01_data_transformer.R # Data transformation
│       ├── 02_table_builder.R # 9 HTML table builders
│       ├── 03_page_builder.R  # Page assembly (CSS, sections, layout)
│       ├── 04_html_writer.R   # Atomic file writer
│       ├── 05_chart_builder.R # 6 SVG chart builders
│       ├── 06_quadrant_section.R # SVG quadrant plot
│       ├── 99_html_report_main.R # Report orchestrator
│       └── js/                # Client-side interactivity
│           ├── kd_utils.js
│           ├── kd_navigation.js
│           ├── kd_pinned_views.js
│           └── kd_slide_export.js
├── tests/
│   ├── testthat/              # 12 test files (NEW v10.3)
│   ├── fixtures/              # Test data generators
│   └── run_tests.R
├── docs/
│   ├── 01_README.md           # This file
│   ├── 02_KEYDRIVER_OVERVIEW.md
│   ├── 03_REFERENCE_GUIDE.md
│   ├── 04_USER_MANUAL.md
│   ├── 05_TECHNICAL_DOCS.md
│   ├── 06_TEMPLATE_REFERENCE.md
│   ├── 07_EXAMPLE_WORKFLOWS.md
│   ├── 08_BOOTSTRAP_GUIDE.md  # NEW v10.3
│   ├── 09_HTML_REPORT_GUIDE.md # NEW v10.3
│   └── templates/
└── run_keydriver_gui.R        # Shiny GUI
```

---

## Dependencies

**Required:**
- openxlsx (>= 4.2.5) - Excel I/O
- Base R stats - Regression analysis

**Optional:**
- htmltools - HTML report generation
- haven (>= 2.5.0) - SPSS .sav support
- xgboost - SHAP analysis
- shapviz - SHAP visualizations
- ggplot2 - Quadrant charts
- shiny, shinyFiles - GUI interface

---

## Output

### Excel Workbook
1. **Importance Summary** - All metrics in one view
2. **Method Rankings** - Rank positions from each method
3. **Model Summary** - R-squared, VIF diagnostics, coefficients
4. **Correlations** - Full correlation matrix
5. **Effect Sizes** - Effect size classification (NEW v10.3)
6. **Executive Summary** - Plain-English findings (NEW v10.3)
7. **Charts** - Shapley impact bar chart
8. **Run Status** - TRS run status details
9. **README** - Methodology documentation

**When SHAP enabled:**
- SHAP_Importance, SHAP_Charts, SHAP_Interactions

**When Quadrant enabled:**
- Quadrant_Summary, Action_Table, Gap_Analysis

**When Bootstrap enabled (NEW v10.3):**
- Bootstrap_CIs, Bootstrap_Summary

### HTML Report (NEW v10.3)
Self-contained interactive HTML file with:
- All sections with SVG charts and tables
- Sticky section navigation
- Pinned views panel with slide export (1280x720 PNG)
- Report Hub integration

---

## Documentation Pack

| Document | Purpose |
|----------|---------|
| [01_README.md](01_README.md) | This file - quick start |
| [02_KEYDRIVER_OVERVIEW.md](02_KEYDRIVER_OVERVIEW.md) | Module introduction |
| [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) | Statistical methods reference |
| [04_USER_MANUAL.md](04_USER_MANUAL.md) | End-user guide |
| [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) | Developer documentation |
| [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) | Template field reference |
| [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) | Practical examples |
| [08_BOOTSTRAP_GUIDE.md](08_BOOTSTRAP_GUIDE.md) | Bootstrap CI guide (NEW v10.3) |
| [09_HTML_REPORT_GUIDE.md](09_HTML_REPORT_GUIDE.md) | HTML report guide (NEW v10.3) |

---

## Testing

```r
# Run all keydriver tests
testthat::test_dir("modules/keydriver/tests")

# Run specific test file
testthat::test_file("modules/keydriver/tests/testthat/test_core_importance.R")
```

---

## References

- Johnson, J. W. (2000). A heuristic method for estimating relative weights
- Shapley, L. S. (1953). A value for n-person games
- Lundberg, S. M., & Lee, S. I. (2017). SHAP: A unified approach to interpreting model predictions
- Martilla, J. A., & James, J. C. (1977). Importance-performance analysis
- Efron, B., & Tibshirani, R. J. (1993). An introduction to the bootstrap
- Cohen, J. (1988). Statistical power analysis for the behavioral sciences
