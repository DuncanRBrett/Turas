# Turas Pricing Research Module

**Version:** 12.0
**Part of:** Turas Survey Analysis Suite

## Overview

The Turas Pricing module provides comprehensive pricing research capabilities through three industry-standard methodologies:

- **Van Westendorp Price Sensitivity Meter (PSM)**: Determine acceptable price ranges through four price perception questions
- **Gabor-Granger Analysis**: Construct demand curves and find revenue-maximizing prices through purchase intent measurement
- **Monadic Price Testing**: Logistic regression on randomised price cells for unbiased demand estimation

All methods work seamlessly together to provide complete pricing insights from acceptable ranges to optimal price points.

## Key Features

- **Three Methodologies**: Run Van Westendorp, Gabor-Granger, Monadic, or any combination
- **Excel Configuration**: User-friendly spreadsheet-based setup requiring no coding
- **A Pricing tab in the interactive report**: the run writes `{output}_pr_island.json`; a tabs run for the same project names it in `pricing_island` and the client's own report gains a Pricing tab with the price points, the demand curve and the recommended price
- **Standalone price simulator**: a self-contained HTML file with a price slider, scenario comparison and PNG export, linked from that tab
- **Advanced Analysis**:
  - Segment Analysis across customer groups
  - Price Ladder Builder (Good/Better/Best tier generation)
  - Recommendation Synthesis with confidence assessment
- **Profit Optimization**: Revenue vs. profit-maximizing price identification
- **Professional Outputs**: a Pricing tab in the interactive report, a standalone simulator, a crosstab export and a comprehensive Excel workbook
- **Bootstrap Confidence Intervals**: Statistical rigor with configurable confidence levels
- **Price Elasticity**: Calculate and interpret demand elasticity
- **Data Validation**: Comprehensive quality checks with TRS-compliant error messages

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

### Monadic Price Testing

The gold standard for unbiased price sensitivity measurement:

- Each respondent sees ONE randomly assigned price and reports purchase intent
- Logistic regression models the price-intent relationship: `glm(intent ~ price, family = binomial)`
- Optional log-logistic variant: `glm(intent ~ log(price), family = binomial)`
- Produces smooth demand curve, revenue/profit optimization, and bootstrap CIs
- Price elasticity computed as arc elasticity at sampled intervals

**Required Data**: One price column (randomly assigned) and one purchase intent column (binary or scale) per respondent.

### NMS Extension (Newton-Miller-Smith)

**Do not use it in this version.** The extension adds purchase-intent questions
at the bargain and expensive price points to give a revenue-optimal price. The
2026-09-03 review of the pricing engine found it broken on both the weighted and
the unweighted path, with nothing in the suite exercising it (finding F3). Its
numbers do not reach the Pricing tab or the standalone simulator, and a refusal
by name is owed on the review follow-up branch. For a revenue-calibrated optimal
price, run Gabor-Granger: the ladder measures acceptance at each price directly.

## Configuration

Create an Excel workbook (.xlsx) with the following sheets:

### Required Sheets

1. **Settings**: Global project parameters
   - `project_name`: Project identifier
   - `analysis_method`: van_westendorp, gabor_granger, monadic, or both
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

3. **Monadic** (if using Monadic):
   - Price and intent column mappings
   - Intent type (binary or scale) and scale threshold
   - Model type (logistic or log_logistic)
   - Bootstrap CI settings

### Optional Sheets

4. **Validation**: Data quality rules
5. **Segmentation**: Customer segment analysis
6. **PriceLadder**: Tier structure settings
7. **Simulator**: Preset scenarios, competitor prices, cost assumptions

## Output

The module generates:

1. **Excel Workbook** with multiple sheets:
   - Summary of analysis
   - Van Westendorp price points and curves
   - Gabor-Granger demand and revenue curves
   - Monadic model summary and demand curve
   - Segment comparisons
   - Price ladder tiers
   - Recommendation synthesis
   - Validation results
   - Configuration used

2. **Interactive-report contribution** (every run):
   - `{output}_pr_island.json`, the frozen results the tabs v2 report reads
   - Point a tabs config's `pricing_island` setting at it and the report gains
     a Pricing tab: the four Van Westendorp price points with their intervals,
     the Gabor-Granger demand and revenue curves, the monadic cells against
     the fitted curve, and the recommended price
   - The tab is frozen and says so: the results were estimated once on the
     whole sample, so the audience filter is hidden while it is open

3. **Standalone price simulator** (if `Generate_Simulator = TRUE`):
   - `{output}_simulator.html`, a self-contained file, no Turas needed
   - Price slider with live purchase intent, revenue and profit
   - Preset scenario cards (configured via the Simulator sheet)
   - Scenario comparison table
   - Segment toggle, each segment drawn on its own prices
   - PNG export for presentations
   - The Pricing tab links to it by name

3b. **Crosstab export** (if `Generate_Tabs_Export = Y`):
   - `{output}_tabs_pricing.xlsx`: the Gabor-Granger acceptance ladder as a
     respondent-level Multi_Mention question, plus a `pricing_valid` flag and
     optionally willingness to pay
   - Paste the QUESTIONMAP_SNIPPET rows into a tabs config and the ladder can
     be read by any banner. `ID_Variable` is required

4. **Stats Pack Workbook** (if `Generate_Stats_Pack = Y`):
   - `{output}_stats_pack.xlsx` — full audit trail for advanced partners and research statisticians
   - Declaration sheet: project name, analyst, research house, and sign-off details
   - Data Receipt sheet: column inventory, missing values, and exclusion log
   - Methods sheet: methodology choices, assumptions, and parameter settings used
   - Reproducibility sheet: software versions, random seeds, and re-run instructions

5. **Visualizations** (PNG files):
   - Van Westendorp PSM plot with curves and intersections
   - Gabor-Granger demand and revenue curves
   - Monadic logistic demand curve with CI band
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
│   ├── 07_wtp_distribution.R   # Willingness-to-pay (direct API only, not in the pipeline)
│   ├── 08_competitive_scenarios.R  # Competitive analysis (direct API only, not in the pipeline)
│   ├── 09_price_volume_optimisation.R  # Optimisation (direct API only, not in the pipeline)
│   ├── 10_segmentation.R       # Segment analysis
│   ├── 11_price_ladder.R       # Tier generation
│   ├── 12_recommendation_synthesis.R  # Synthesis
│   └── 13_monadic.R            # Monadic price testing
├── lib/
│   └── html_simulator/         # The standalone price simulator
│       ├── 01_simulator_parts.R    # Demand extraction, islands, panel markup
│       ├── 99_simulator_main.R     # generate_pricing_simulator()
│       ├── simulator_styles.css
│       └── js/pricing_simulator.js # Demand interpolation, charts, scenarios
├── docs/
│   ├── README.md                     # This file
│   ├── AUTHORITATIVE_GUIDE.md        # Deep methodology guide
│   ├── USER_MANUAL.md                # Complete user guide
│   ├── TECHNICAL_REFERENCE.md        # Developer documentation
│   ├── EXAMPLE_WORKFLOWS.md          # Practical examples
│   └── templates/
│       └── Pricing_Config_Template.xlsx  # Excel template
├── tests/
│   └── testthat/               # Comprehensive test suite (83 tests)
│       ├── setup.R             # Test infrastructure & data generators
│       ├── test_config.R       # Configuration loading tests
│       ├── test_guard.R        # Pre-flight validation tests
│       ├── test_van_westendorp.R   # VW analysis tests
│       ├── test_gabor_granger.R    # GG analysis tests
│       ├── test_monadic.R          # Monadic analysis tests
│       ├── test_segmentation.R     # Segment analysis tests
│       ├── test_price_ladder.R     # Tier generation tests
│       ├── test_synthesis.R        # Recommendation synthesis tests
│       └── test_integration.R      # End-to-end workflow tests
├── run_pricing_gui.R           # Shiny GUI
└── examples/                   # Example files
```

## Documentation

This module includes comprehensive documentation:

2. **[Authoritative Guide](AUTHORITATIVE_GUIDE.md)** - Deep dive into pricing research methodology
3. **[User Manual](USER_MANUAL.md)** - Complete setup and usage guide
4. **[Template Guide](Pricing_Config_Template.xlsx)** - Excel configuration template
5. **[Technical Reference](TECHNICAL_REFERENCE.md)** - Developer documentation
6. **[Example Workflows](EXAMPLE_WORKFLOWS.md)** - Practical step-by-step examples

## Best Practices

1. **Sample Size**: Minimum 100 respondents recommended, 300+ for segment analysis
2. **Price Range**: Ensure tested prices span expected acceptable range
3. **Data Quality**: Use validation settings (completeness, Min_Sample, price range) to catch inconsistencies
4. **Method Selection**:
   - Van Westendorp for exploring acceptable ranges
   - Gabor-Granger for finding specific optimal price from discrete price points
   - Monadic for unbiased demand estimation via randomised cell design
   - Combined methods for comprehensive insights with confidence scoring
5. **Monotonicity**: Review violation rates; >10% may indicate survey design issues

## Support

For detailed information:
- **Users**: See [User Manual](USER_MANUAL.md) for step-by-step instructions
- **Survey Design**: See [Questionnaire Design Guide](QUESTIONNAIRE_DESIGN_GUIDE.md) for question wording, sample sizes, and common mistakes
- **Method Selection**: See the TECHNIQUE_GUIDE for when to use each method
- **Developers**: See [Technical Reference](TECHNICAL_REFERENCE.md) for API documentation
- **Examples**: See [Example Workflows](EXAMPLE_WORKFLOWS.md) for practical use cases

For issues or questions, consult the documentation or contact the development team.

## Version History

- **12.2** (2026-03): Added stats pack output (`Generate_Stats_Pack`) and STUDY IDENTIFICATION fields (`Analyst_Name`, `Research_House`) to config template
- **12.1** (2026-03): Production upgrade — visual overhaul (gradient headers, dashboard gauges, heatmap tables, chart tooltips, keyboard nav, SVG export), simulator CSS/JS fix, comprehensive test suite (463 tests), questionnaire design guide, methodology comparison
- **12.0** (2026-03): Added monadic price testing, interactive HTML reports, simulator dashboard
- **11.0** (2025-12): Added NMS extension, segment analysis, price ladder builder, recommendation synthesis
- **2.0** (2025-11): Major update with profit optimization and GUI improvements
- **1.0** (2025-11): Initial release with Van Westendorp and Gabor-Granger methods
