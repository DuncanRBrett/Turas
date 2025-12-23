# Turas Key Driver Analysis Module

**Version:** 10.0
**Last Updated:** 22 December 2025

Identifies which drivers have the greatest impact on key outcomes using multiple statistical methods.

---

## Quick Start

```r
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

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
- **Shapley Value Decomposition** - Game-theoretic fair R² allocation
- **Relative Weights** (Johnson 2000) - Handles multicollinearity
- **Beta Weights** - Standardized regression coefficients
- **Zero-order Correlations** - Bivariate relationships
- **SHAP Analysis** (XGBoost/TreeSHAP) - Machine learning importance

### Analysis Capabilities
- Survey weights support throughout pipeline
- VIF multicollinearity diagnostics
- Quadrant charts (Importance-Performance Analysis)
- Segment comparison analysis
- Excel output with charts and documentation

### Validation
- Smart sample size rules: n ≥ max(30, 10×k drivers)
- Zero variance detection
- Aliased predictor handling
- Maximum 15 drivers for exact Shapley

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
│   ├── 00_main.R           # Main orchestration
│   ├── 01_config.R         # Configuration loading
│   ├── 02_validation.R     # Data validation
│   ├── 03_analysis.R       # Statistical analysis
│   └── 04_output.R         # Excel output
└── docs/
    ├── 01_README.md        # This file
    ├── 02_KEYDRIVER_OVERVIEW.md
    ├── 03_REFERENCE_GUIDE.md
    ├── 04_USER_MANUAL.md
    ├── 05_TECHNICAL_DOCS.md
    ├── 06_TEMPLATE_REFERENCE.md
    ├── 07_EXAMPLE_WORKFLOWS.md
    └── templates/
        └── KeyDriver_Config_Template.xlsx
```

---

## Dependencies

**Required:**
- openxlsx (>= 4.2.5) - Excel I/O
- Base R stats - Regression analysis

**Optional:**
- haven (>= 2.5.0) - SPSS .sav support
- xgboost - SHAP analysis
- shapviz - SHAP visualizations
- shiny, shinyFiles - GUI interface

---

## Output

Excel workbook with sheets:
1. **Importance Summary** - All metrics in one view
2. **Method Rankings** - Rank positions from each method
3. **Model Summary** - R², VIF diagnostics, coefficients
4. **Correlations** - Full correlation matrix
5. **Charts** - Shapley impact bar chart
6. **README** - Methodology documentation

**When SHAP enabled:**
- SHAP_Importance, SHAP_Charts, SHAP_Interactions

**When Quadrant enabled:**
- Quadrant_Summary, Action_Table, Gap_Analysis

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

---

## References

- Johnson, J. W. (2000). A heuristic method for estimating relative weights
- Shapley, L. S. (1953). A value for n-person games
- Lundberg, S. M., & Lee, S. I. (2017). SHAP: A unified approach to interpreting model predictions
- Martilla, J. A., & James, J. C. (1977). Importance-performance analysis
