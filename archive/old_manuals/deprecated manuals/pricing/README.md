# Turas Pricing Research Module

Production-ready pricing analysis for market research using Van Westendorp Price Sensitivity Meter (PSM) and Gabor-Granger methodologies.

## Overview

The Turas Pricing module provides comprehensive pricing research capabilities through an Excel-config-driven workflow. It analyzes consumer price perceptions to identify optimal pricing strategies and acceptable price ranges.

## Key Features

- **Van Westendorp PSM**: Determine acceptable price range and optimal price point through four-question price perception analysis
- **Gabor-Granger Analysis**: Construct demand curves and find revenue-maximizing prices through sequential purchase intent questions
- **Excel Configuration**: User-friendly spreadsheet-based setup requiring no coding
- **Professional Outputs**: Publication-ready visualizations and comprehensive Excel reports
- **Bootstrap Confidence Intervals**: Statistical rigor with configurable confidence levels
- **Price Elasticity**: Calculate and interpret demand elasticity
- **Data Validation**: Comprehensive quality checks with clear error messages

## Quick Start

```r
# Source the module
source("modules/pricing/R/00_main.R")
source("modules/pricing/R/01_config.R")
source("modules/pricing/R/02_validation.R")
source("modules/pricing/R/03_van_westendorp.R")
source("modules/pricing/R/04_gabor_granger.R")
source("modules/pricing/R/05_visualization.R")
source("modules/pricing/R/06_output.R")

# Create a configuration template
create_pricing_config(
  output_file = "my_pricing_config.xlsx",
  method = "van_westendorp"
)

# Edit the Excel config with your settings, then run:
results <- run_pricing_analysis(
  config_file = "my_pricing_config.xlsx"
)

# View results
print(results$results$price_points)
```

## Supported Pricing Methods

### Van Westendorp Price Sensitivity Meter

Analyzes four price perception questions to find key price points:

- **PMC (Point of Marginal Cheapness)**: Below this price, quality concerns arise
- **OPP (Optimal Price Point)**: Price that minimizes resistance
- **IDP (Indifference Price Point)**: Price where equal numbers find it cheap vs expensive
- **PME (Point of Marginal Expensiveness)**: Above this price, most consider too expensive

**Required Data**: Four columns with price responses for:
1. "At what price would you consider this product too cheap?"
2. "At what price would you consider this product a bargain?"
3. "At what price would you consider this product getting expensive?"
4. "At what price would you consider this product too expensive?"

### Gabor-Granger Analysis

Analyzes sequential purchase intent at various price points to:

- Construct demand curve showing purchase intent vs price
- Calculate revenue-maximizing price
- Compute price elasticity of demand
- Generate confidence intervals

**Required Data**: Purchase intent (yes/no or scale) at multiple price points per respondent.

## Configuration

### Settings Sheet (Required)

| Setting | Description | Example |
|---------|-------------|---------|
| project_name | Project identifier | "Q4 Product Pricing" |
| analysis_method | van_westendorp, gabor_granger, or both | "van_westendorp" |
| data_file | Path to survey data | "data/survey.csv" |
| output_file | Path for results | "pricing_results.xlsx" |
| currency_symbol | Currency for display | "$" |

### Van Westendorp Sheet

| Setting | Description |
|---------|-------------|
| col_too_cheap | Column name for "too cheap" question |
| col_cheap | Column name for "bargain" question |
| col_expensive | Column name for "expensive" question |
| col_too_expensive | Column name for "too expensive" question |
| validate_monotonicity | Check price sequence logic (TRUE/FALSE) |
| calculate_confidence | Calculate bootstrap CIs (TRUE/FALSE) |

### Gabor-Granger Sheet

| Setting | Description |
|---------|-------------|
| data_format | "wide" or "long" |
| price_sequence | Prices tested (semicolon-separated) |
| response_columns | Response column names (semicolon-separated) |
| calculate_elasticity | Calculate price elasticity (TRUE/FALSE) |
| revenue_optimization | Find optimal price (TRUE/FALSE) |

## Output

The module generates:

1. **Excel Workbook** with multiple sheets:
   - Summary of analysis
   - Price points / Demand curves
   - Confidence intervals (if calculated)
   - Elasticity analysis
   - Validation results
   - Configuration used

2. **Visualizations**:
   - Van Westendorp PSM plot with curves and intersections
   - Gabor-Granger demand and revenue curves

## Dependencies

- `readxl`: Excel file reading
- `openxlsx`: Excel file writing
- `ggplot2`: Visualizations
- `haven` (optional): SPSS/Stata file support

## File Structure

```
modules/pricing/
├── R/
│   ├── 00_main.R           # Entry point
│   ├── 01_config.R         # Configuration loading
│   ├── 02_validation.R     # Data validation
│   ├── 03_van_westendorp.R # Van Westendorp analysis
│   ├── 04_gabor_granger.R  # Gabor-Granger analysis
│   ├── 05_visualization.R  # Plotting functions
│   └── 06_output.R         # Excel output
├── run_pricing_gui.R       # Shiny GUI
├── README.md               # This file
├── QUICK_START.md          # Getting started guide
├── USER_MANUAL.md          # Comprehensive user guide
├── TECHNICAL_DOCUMENTATION.md
└── EXAMPLE_WORKFLOWS.md
```

## Usage Examples

### Basic Van Westendorp Analysis

```r
# Run analysis
results <- run_pricing_analysis("vw_config.xlsx")

# Access price points
results$results$price_points
# $PMC: 52.30
# $OPP: 74.50
# $IDP: 89.20
# $PME: 118.40

# Acceptable price range
results$results$acceptable_range
# $lower: 52.30
# $upper: 118.40
```

### Gabor-Granger with Revenue Optimization

```r
# Run analysis
results <- run_pricing_analysis("gg_config.xlsx")

# Optimal price
results$results$optimal_price
# $price: 14.99
# $purchase_intent: 0.52
# $revenue_index: 7.79

# Demand curve
results$results$demand_curve
```

### Both Methods

```r
# Run both analyses
results <- run_pricing_analysis("combined_config.xlsx")

# Van Westendorp results
results$results$van_westendorp$price_points

# Gabor-Granger results
results$results$gabor_granger$optimal_price
```

## Best Practices

1. **Sample Size**: Minimum 100 respondents recommended, 300+ for segment analysis
2. **Monotonicity**: Review violation rates; >10% may indicate survey design issues
3. **Price Range**: Ensure tested prices span expected acceptable range
4. **Data Quality**: Use validation settings to catch outliers and inconsistencies

## Support

For issues or questions:
- Check QUICK_START.md for common setup issues
- Review USER_MANUAL.md for detailed guidance
- See EXAMPLE_WORKFLOWS.md for real-world use cases

## Version History

- **1.0.0** (2025-11-18): Initial release with Van Westendorp and Gabor-Granger methods
