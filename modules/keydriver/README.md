# Turas Key Driver Analysis Module

## Overview

The Key Driver Analysis module identifies which independent variables (drivers) have the greatest impact on a dependent variable (outcome). It uses multiple statistical methods to provide robust importance rankings.

## Features

- **Multiple Methods**: 4 complementary importance metrics
  - Shapley Value Decomposition (game theory approach)
  - Relative Weights (Johnson's method)
  - Standardized Coefficients (Beta weights)
  - Zero-order Correlations
- **Robust Rankings**: Consensus ranking across methods
- **Model Diagnostics**: R², RMSE, F-statistics
- **Formatted Output**: Excel workbook with detailed results

## Quick Start

```r
# Source the module
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

# Run analysis
results <- run_keydriver_analysis(
  config_file = "keydriver_config.xlsx",
  data_file = "survey_data.csv",
  output_file = "keydriver_results.xlsx"
)

# View top drivers
print(results$importance)
```

## Configuration File Format

Create an Excel file with the following sheets:

### Sheet 1: Settings
| Setting | Value |
|---------|-------|
| analysis_name | Brand Health Drivers |
| min_sample_size | 30 |

### Sheet 2: Variables
| VariableName | Type | Label |
|--------------|------|-------|
| overall_satisfaction | Outcome | Overall Satisfaction |
| product_quality | Driver | Product Quality |
| customer_service | Driver | Customer Service |
| value_for_money | Driver | Value for Money |
| brand_reputation | Driver | Brand Reputation |

## Data File Format

CSV or Excel with one row per respondent:

| resp_id | overall_satisfaction | product_quality | customer_service | value_for_money | brand_reputation |
|---------|---------------------|-----------------|------------------|----------------|-----------------|
| 1 | 8 | 7 | 9 | 6 | 8 |
| 2 | 9 | 9 | 8 | 8 | 9 |
| 3 | 6 | 5 | 7 | 7 | 6 |

## Methodology

### 1. Shapley Value Decomposition
- **Game theory approach**: Fair allocation of R² contribution
- **Accounts for**: Multicollinearity, variable interactions
- **Pros**: Most robust, fair attribution
- **Calculation**: Averages marginal R² across all variable orderings

### 2. Relative Weights (Johnson, 2000)
- **Orthogonalization**: Transforms correlated predictors to orthogonal space
- **Decomposes**: R² into non-negative contributions
- **Pros**: Always positive, sums to 100%
- **Use case**: When predictors are highly correlated

### 3. Standardized Coefficients (Beta Weights)
- **Traditional approach**: Regression coefficients in standard deviation units
- **Pros**: Easy to interpret, widely understood
- **Limitation**: Can be unstable with multicollinearity

### 4. Zero-order Correlations
- **Simple correlation**: Between each driver and outcome
- **Pros**: Simple, intuitive
- **Limitation**: Doesn't account for other variables

## Output

The module creates an Excel workbook with four sheets:

1. **Importance Summary**: All metrics in one view
2. **Method Rankings**: Rank positions from each method
3. **Model Summary**: R², F-stat, RMSE, p-value
4. **Correlations**: Full correlation matrix

## Interpretation Guidelines

### Importance Scores (%)
- **>20%**: Major driver (high priority for action)
- **10-20%**: Moderate driver (secondary priority)
- **<10%**: Minor driver (limited impact)

### Method Consensus
- **High consensus**: All methods agree → strong evidence
- **Low consensus**: Methods disagree → investigate further
  - Check for suppressor variables
  - Examine multicollinearity (VIF)
  - Consider non-linear relationships

### Model Fit Thresholds
- **R² >0.70**: Excellent explanatory power
- **R² 0.50-0.70**: Good
- **R² 0.30-0.50**: Moderate
- **R² <0.30**: Weak (consider adding variables)

## Example Output

```
TOP 5 DRIVERS (by Shapley value):
  1. Product Quality (32.5%)
  2. Customer Service (26.8%)
  3. Value for Money (21.3%)
  4. Brand Reputation (12.7%)
  5. Delivery Speed (6.7%)
```

## Assumptions & Limitations

### Assumptions
- Linear relationships between drivers and outcome
- Normally distributed residuals (for significance tests)
- Independent observations
- No severe multicollinearity (VIF <10)

### Limitations
- Cannot detect non-linear relationships
- Assumes additive effects (no interactions)
- Correlation ≠ causation (needs experimental design for causality)
- Works best with 3-15 drivers (computational limits for Shapley with >15)

## Advanced Features (Future)

- [ ] Hierarchical driver models (groups of drivers)
- [ ] Non-linear relationships (GAM, polynomial terms)
- [ ] Interaction effects between drivers
- [ ] Bootstrapped confidence intervals for importance
- [ ] Subgroup analysis (by segment)
- [ ] Time-series driver analysis (changing importance over time)
- [ ] Visualization: tornado charts, bubble plots

## References

- Johnson, J. W. (2000). A heuristic method for estimating relative weights
- Shapley, L. S. (1953). A value for n-person games
- Grömping, U. (2006). Relative importance for linear regression in R
- Tonidandel, S., & LeBreton, J. M. (2011). Relative importance analysis

## Dependencies

- `openxlsx`: Excel I/O
- `haven` (optional): SPSS/Stata files
- Base R `stats` for regression

---

**Version**: 1.0.0 (Initial Implementation)
**Status**: Production - All 4 methods implemented
**Last Updated**: 2025-11-18
