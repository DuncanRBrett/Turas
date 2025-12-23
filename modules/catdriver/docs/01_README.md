# Turas Categorical Key Driver Module

**Version:** 10.0
**Last Updated:** 22 December 2025

Key driver analysis for categorical outcomes using logistic regression methods.

---

## Overview

The Categorical Key Driver module identifies which factors most strongly influence a categorical outcome. Unlike the standard Key Driver module (which handles continuous outcomes), this module handles categorical outcomes using appropriate logistic regression methods.

**Core Capabilities:**
- Binary logistic regression for 2-category outcomes
- Ordinal logistic regression for ordered 3+ categories
- Multinomial logistic regression for unordered 3+ categories
- Automatic outcome type detection
- Chi-square based variable importance
- Odds ratios with confidence intervals
- Plain-English executive summaries

---

## Use Cases

| Scenario | Outcome Type | Example |
|----------|--------------|---------|
| Customer churn | Binary | Retained vs Churned |
| Satisfaction levels | Ordinal | Low/Medium/High |
| Brand preference | Nominal | Brand A/B/C/D |
| Survey completion | Ordinal | Complete/Partial/Abandoned |
| Employee engagement | Ordinal | Disengaged/Neutral/Engaged |

---

## Quick Start

### Using the GUI (Recommended)

```r
source("launch_turas.R")
# Click "Launch Categorical Key Driver"
```

### Using Command Line

```r
# Source module files
source("modules/catdriver/R/00_main.R")

# Run analysis
results <- run_categorical_keydriver("path/to/config.xlsx")
```

---

## Configuration

Create an Excel file with two required sheets:

### Settings Sheet

| Setting | Value |
|---------|-------|
| data_file | survey_data.csv |
| output_file | results.xlsx |
| outcome_type | auto |

### Variables Sheet

| VariableName | Type | Label | Order |
|--------------|------|-------|-------|
| satisfaction | Outcome | Employment Satisfaction | Low;Neutral;High |
| grade | Driver | Academic Grade | D;C;B;A |
| campus | Driver | Campus Location | |

See [06_TEMPLATE_REFERENCE.md](docs/06_TEMPLATE_REFERENCE.md) for complete configuration.

---

## Output

The module generates an Excel workbook with:

| Sheet | Content |
|-------|---------|
| Executive Summary | Plain-English findings for non-statisticians |
| Importance Summary | Driver rankings with chi-square statistics |
| Factor Patterns | Category breakdowns and odds ratios |
| Model Summary | Fit statistics (pseudo-R², AIC) |
| Odds Ratios | Detailed comparisons (if detailed_output=TRUE) |
| Diagnostics | Data quality checks (if detailed_output=TRUE) |

---

## File Structure

```
modules/catdriver/
├── R/
│   ├── 00_main.R           # Entry point
│   ├── 01_config.R         # Configuration loader
│   ├── 02_validation.R     # Data validation
│   ├── 03_preprocessing.R  # Variable preparation
│   ├── 04_analysis.R       # Model dispatcher
│   ├── 04a_ordinal.R       # Ordinal logistic
│   ├── 04b_multinomial.R   # Multinomial logistic
│   ├── 05_importance.R     # Importance calculations
│   ├── 06_output.R         # Excel generation
│   └── 07_utilities.R      # Helper functions
├── run_catdriver_gui.R     # Shiny GUI
└── docs/                   # Documentation
    ├── 01_README.md        # This file
    ├── 02_CATDRIVER_OVERVIEW.md
    ├── 03_REFERENCE_GUIDE.md
    ├── 04_USER_MANUAL.md
    ├── 05_TECHNICAL_DOCS.md
    ├── 06_TEMPLATE_REFERENCE.md
    ├── 07_EXAMPLE_WORKFLOWS.md
    └── templates/
```

---

## Dependencies

**Required:**
```r
install.packages(c("MASS", "nnet", "car", "openxlsx"))
```

**Recommended:**
```r
install.packages(c("ordinal", "brglm2"))
```

**Optional (SPSS/Stata support):**
```r
install.packages("haven")
```

---

## Interpreting Results

### Odds Ratio Effect Sizes

| Odds Ratio | Effect Size |
|------------|-------------|
| 0.9 - 1.1 | Negligible |
| 0.67-0.9 or 1.1-1.5 | Small |
| 0.5-0.67 or 1.5-2.0 | Medium |
| 0.33-0.5 or 2.0-3.0 | Large |
| <0.33 or >3.0 | Very Large |

### Importance Percentages

| Importance % | Interpretation |
|--------------|----------------|
| > 30% | Dominant driver |
| 15-30% | Major driver |
| 5-15% | Moderate driver |
| < 5% | Minor driver |

---

## Documentation

| Document | Purpose |
|----------|---------|
| [02_CATDRIVER_OVERVIEW.md](docs/02_CATDRIVER_OVERVIEW.md) | Capabilities and use cases |
| [03_REFERENCE_GUIDE.md](docs/03_REFERENCE_GUIDE.md) | Statistical methods reference |
| [04_USER_MANUAL.md](docs/04_USER_MANUAL.md) | Complete user guide |
| [05_TECHNICAL_DOCS.md](docs/05_TECHNICAL_DOCS.md) | Developer documentation |
| [06_TEMPLATE_REFERENCE.md](docs/06_TEMPLATE_REFERENCE.md) | Template field reference |
| [07_EXAMPLE_WORKFLOWS.md](docs/07_EXAMPLE_WORKFLOWS.md) | Practical examples |

---

**Part of the Turas Analytics Platform**
