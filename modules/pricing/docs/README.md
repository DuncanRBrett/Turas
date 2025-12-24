# Turas Pricing Research Module

**Version:** 11.0
**Part of:** Turas Survey Analysis Suite

## Overview

The Turas Pricing module provides comprehensive pricing research capabilities through two industry-standard methodologies:

- **Van Westendorp Price Sensitivity Meter (PSM)**: Determine acceptable price ranges through four price perception questions
- **Gabor-Granger Analysis**: Construct demand curves and find revenue-maximizing prices through purchase intent measurement

Both methods work seamlessly together to provide complete pricing insights from acceptable ranges to optimal price points.

## Key Features

- **Dual Methodology**: Run Van Westendorp, Gabor-Granger, or both methods
- **Excel Configuration**: User-friendly spreadsheet-based setup requiring no coding
- **Advanced Analysis**:
  - NMS Extension (Newton-Miller-Smith) for Van Westendorp purchase intent calibration
  - Segment Analysis across customer groups
  - Price Ladder Builder (Good/Better/Best tier generation)
  - Recommendation Synthesis with confidence assessment
- **Profit Optimization**: Revenue vs. profit-maximizing price identification
- **Professional Outputs**: Publication-ready visualizations and comprehensive Excel reports
- **Bootstrap Confidence Intervals**: Statistical rigor with configurable confidence levels
- **Price Elasticity**: Calculate and interpret demand elasticity
- **Data Validation**: Comprehensive quality checks with clear error messages

## Quick Start

### From R Console

```r
# Source the module
source("modules/pricing/R/00_main.R")

# Run pricing analysis
results <- run_pricing_analysis(
  config_file = "path/to/pricing_config.xlsx"
)

# View results
print(results$results)
```

### From Turas Launcher

1. Launch Turas: `source("launch_turas.R")`
2. Click "Pricing" button
3. Browse to select your configuration file
4. Click "Run"

## Typical Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  1. DESIGN SURVEY   Collect Van Westendorp 4-question or   │
│         ↓           Gabor-Granger purchase intent data      │
├─────────────────────────────────────────────────────────────┤
│  2. CREATE CONFIG   Use Excel template to configure         │
│         ↓           analysis settings                       │
├─────────────────────────────────────────────────────────────┤
│  3. RUN ANALYSIS    Execute pricing module                  │
│         ↓                                                   │
├─────────────────────────────────────────────────────────────┤
│  4. REVIEW RESULTS  Analyze price points and curves         │
│         ↓                                                   │
├─────────────────────────────────────────────────────────────┤
│  5. IMPLEMENT       Set prices based on recommendations     │
└─────────────────────────────────────────────────────────────┘
```

## Pricing Methods

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

Analyzes purchase intent at various price points to:

- Construct demand curve showing purchase intent vs price
- Calculate revenue-maximizing price
- Calculate profit-maximizing price (if unit cost provided)
- Compute price elasticity of demand
- Generate confidence intervals

**Required Data**: Purchase intent (yes/no or scale) at multiple price points per respondent.

### NMS Extension (Newton-Miller-Smith)

Enhances Van Westendorp with behavioral calibration:
- Adds purchase intent questions at bargain and expensive price points
- Provides revenue-optimal price recommendation
- More accurate for actual purchase prediction

## Configuration

Create an Excel workbook (.xlsx) with the following sheets:

### Required Sheets

1. **Settings**: Global project parameters
   - `project_name`: Project identifier
   - `analysis_method`: van_westendorp, gabor_granger, or both
   - `data_file`: Path to survey data
   - `output_file`: Path for results
   - `currency_symbol`: Currency for display

2. **VanWestendorp** (if using Van Westendorp):
   - Column mappings for four price questions
   - Monotonicity handling settings
   - Bootstrap configuration

3. **GaborGranger** (if using Gabor-Granger):
   - Data format (wide or long)
   - Price sequence tested
   - Response column mappings
   - Optimization settings

### Optional Sheets

4. **Validation**: Data quality rules
5. **Segmentation**: Customer segment analysis
6. **PriceLadder**: Tier structure settings

## Output

The module generates:

1. **Excel Workbook** with multiple sheets:
   - Summary of analysis
   - Van Westendorp price points
   - Gabor-Granger demand curve
   - NMS results (if applicable)
   - Segment comparisons
   - Price ladder tiers
   - Recommendation synthesis
   - Validation results
   - Configuration used

2. **Visualizations** (PNG files):
   - Van Westendorp PSM plot with curves and intersections
   - Gabor-Granger demand and revenue curves
   - Segment comparison charts
   - Price ladder visualization

## Dependencies

**Required:**
- `readxl`: Excel file reading
- `openxlsx`: Excel file writing
- `ggplot2`: Visualizations

**Optional:**
- `pricesensitivitymeter`: NMS extension
- `haven`: SPSS/Stata file support

## File Structure

```
modules/pricing/
├── R/
│   ├── 00_main.R               # Entry point
│   ├── 01_config.R             # Configuration loading
│   ├── 02_validation.R         # Data validation
│   ├── 03_van_westendorp.R     # Van Westendorp PSM
│   ├── 04_gabor_granger.R      # Gabor-Granger analysis
│   ├── 05_visualization.R      # Plot generation
│   ├── 06_output.R             # Excel output
│   ├── 07_wtp_distribution.R   # Willingness-to-pay analysis
│   ├── 08_competitive_scenarios.R  # Competitive analysis
│   ├── 09_price_volume_optimisation.R  # Optimization
│   ├── 10_segmentation.R       # Segment analysis
│   ├── 11_price_ladder.R       # Tier generation
│   └── 12_recommendation_synthesis.R  # Synthesis
├── docs/
│   ├── README.md                     # This file
│   ├── MARKETING.md                  # Client-facing overview
│   ├── AUTHORITATIVE_GUIDE.md        # Deep methodology guide
│   ├── USER_MANUAL.md                # Complete user guide
│   ├── TECHNICAL_REFERENCE.md        # Developer documentation
│   ├── EXAMPLE_WORKFLOWS.md          # Practical examples
│   └── Pricing_Config_Template.xlsx  # Excel template
├── run_pricing_gui.R           # Shiny GUI
└── examples/                   # Example files
```

## Documentation

This module includes comprehensive documentation:

1. **[Marketing Guide](MARKETING.md)** - Client-facing overview of pricing capabilities
2. **[Authoritative Guide](AUTHORITATIVE_GUIDE.md)** - Deep dive into pricing research methodology
3. **[User Manual](USER_MANUAL.md)** - Complete setup and usage guide
4. **[Template Guide](Pricing_Config_Template.xlsx)** - Excel configuration template
5. **[Technical Reference](TECHNICAL_REFERENCE.md)** - Developer documentation
6. **[Example Workflows](EXAMPLE_WORKFLOWS.md)** - Practical step-by-step examples

## Best Practices

1. **Sample Size**: Minimum 100 respondents recommended, 300+ for segment analysis
2. **Price Range**: Ensure tested prices span expected acceptable range
3. **Data Quality**: Use validation settings to catch outliers and inconsistencies
4. **Method Selection**:
   - Van Westendorp for exploring acceptable ranges
   - Gabor-Granger for finding specific optimal price
   - Both methods together for comprehensive insights
5. **Monotonicity**: Review violation rates; >10% may indicate survey design issues

## Support

For detailed information:
- **Users**: See [User Manual](USER_MANUAL.md) for step-by-step instructions
- **Clients**: See [Marketing Guide](MARKETING.md) for capabilities overview
- **Developers**: See [Technical Reference](TECHNICAL_REFERENCE.md) for API documentation
- **Examples**: See [Example Workflows](EXAMPLE_WORKFLOWS.md) for practical use cases

For issues or questions, consult the documentation or contact the development team.

## Version History

- **11.0** (2025-12): Added NMS extension, segment analysis, price ladder builder, recommendation synthesis
- **2.0** (2025-11): Major update with profit optimization and GUI improvements
- **1.0** (2025-11): Initial release with Van Westendorp and Gabor-Granger methods
