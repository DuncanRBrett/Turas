# Categorical Key Driver Analysis Module

**Version:** 1.0
**Date:** December 2024

## Overview

The Categorical Key Driver module performs key driver analysis when outcomes are categorical rather than continuous. It identifies which predictor variables (drivers) most strongly influence a categorical outcome using appropriate logistic regression methods.

## Use Cases

- Employee satisfaction (High/Medium/Low)
- Customer retention (Retained/Churned)
- Product preference (Brand A/B/C/D)
- Alumni employment success (Satisfied/Neutral/Dissatisfied)
- Patient outcomes (Improved/Stable/Declined)

## Methods

The module automatically selects the appropriate method based on your outcome:

| Outcome Type | Categories | Method | R Function |
|-------------|------------|--------|------------|
| Binary | 2 | Binary Logistic Regression | `glm()` |
| Ordinal | 3+ ordered | Proportional Odds Model | `MASS::polr()` |
| Nominal | 3+ unordered | Multinomial Logistic | `nnet::multinom()` |

## Quick Start

### 1. Prepare Configuration File

Create an Excel file with two sheets:

**Settings Sheet:**
| Setting | Value |
|---------|-------|
| data_file | path/to/your/data.csv |
| output_file | results.xlsx |
| outcome_type | auto |

**Variables Sheet:**
| VariableName | Type | Label | Order |
|--------------|------|-------|-------|
| satisfaction | Outcome | Employment Satisfaction | Low;Neutral;High |
| grade | Driver | Academic Grade | D;C;B;A |
| campus | Driver | Campus Location | |

### 2. Run Analysis

**Via GUI:**
1. Launch Turas Suite (`source("launch_turas.R")`)
2. Click "Launch Categorical Key Driver"
3. Select your project directory
4. Choose configuration file
5. Click "Run"

**Via R Script:**
```r
source("modules/catdriver/R/00_main.R")
source("modules/catdriver/R/01_config.R")
source("modules/catdriver/R/02_validation.R")
source("modules/catdriver/R/03_preprocessing.R")
source("modules/catdriver/R/04_analysis.R")
source("modules/catdriver/R/05_importance.R")
source("modules/catdriver/R/06_output.R")
source("modules/catdriver/R/07_utilities.R")

results <- run_categorical_keydriver("path/to/config.xlsx")
```

### 3. Review Output

The module generates an Excel workbook with:
- **Executive Summary** - Plain-English findings
- **Importance Summary** - Driver rankings
- **Factor Patterns** - Category breakdowns
- **Model Summary** - Fit statistics
- **Odds Ratios** - Detailed comparisons (if detailed_output=TRUE)
- **Diagnostics** - Data quality checks (if detailed_output=TRUE)

## Configuration Reference

### Settings Sheet

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| analysis_name | No | "Key Driver Analysis" | Analysis title |
| data_file | **Yes** | - | Path to data file |
| output_file | **Yes** | - | Output Excel path |
| outcome_type | No | auto | auto/binary/ordinal/nominal |
| reference_category | No | first alpha | Reference for comparisons |
| min_sample_size | No | 30 | Minimum complete cases |
| confidence_level | No | 0.95 | CI level (0-1) |
| missing_threshold | No | 50 | Warn if % missing exceeds |
| detailed_output | No | TRUE | Include all 6 sheets |

### Variables Sheet

| Column | Required | Description |
|--------|----------|-------------|
| VariableName | **Yes** | Exact column name in data |
| Type | **Yes** | Outcome, Driver, or Weight |
| Label | **Yes** | Human-readable name |
| Order | No | Semicolon-separated ordered categories |

## Interpreting Results

### Odds Ratio Effect Sizes

| Odds Ratio | Effect | Interpretation |
|------------|--------|----------------|
| 0.9 - 1.1 | Negligible | No meaningful difference |
| 0.67 - 0.9 or 1.1 - 1.5 | Small | Minor difference |
| 0.5 - 0.67 or 1.5 - 2.0 | Medium | Worth attention |
| 0.33 - 0.5 or 2.0 - 3.0 | Large | High priority |
| < 0.33 or > 3.0 | Very Large | Investigate thoroughly |

### Importance Percentages

| Importance % | Interpretation |
|--------------|----------------|
| > 30% | Dominant driver |
| 15-30% | Major driver |
| 5-15% | Moderate driver |
| < 5% | Minor driver |

## Required R Packages

```r
# Core (required)
install.packages(c("MASS", "nnet", "car", "openxlsx"))

# For GUI
install.packages(c("shiny", "shinyFiles"))

# Optional (for SPSS/Stata files)
install.packages("haven")
```

## File Structure

```
modules/catdriver/
├── R/
│   ├── 00_main.R           # Entry point
│   ├── 01_config.R         # Configuration loader
│   ├── 02_validation.R     # Data validation
│   ├── 03_preprocessing.R  # Variable preparation
│   ├── 04_analysis.R       # Regression models
│   ├── 05_importance.R     # Importance calculations
│   ├── 06_output.R         # Excel generation
│   └── 07_utilities.R      # Helper functions
├── run_catdriver_gui.R     # Shiny GUI
├── examples/basic/         # Example files
├── tests/test_data/        # Test datasets
└── README.md
```

## Support

For issues or questions, refer to the USER_MANUAL.md for detailed guidance.
