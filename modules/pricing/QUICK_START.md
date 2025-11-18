# Quick Start Guide: Turas Pricing Module

Get your first pricing analysis running in under 10 minutes.

## Prerequisites

Ensure you have R installed with the following packages:

```r
install.packages(c("readxl", "openxlsx", "ggplot2"))
```

## Step 1: Source the Module (1 minute)

```r
# Set your working directory to the Turas folder
setwd("/path/to/Turas")

# Source all pricing module files
source("modules/pricing/R/00_main.R")
source("modules/pricing/R/01_config.R")
source("modules/pricing/R/02_validation.R")
source("modules/pricing/R/03_van_westendorp.R")
source("modules/pricing/R/04_gabor_granger.R")
source("modules/pricing/R/05_visualization.R")
source("modules/pricing/R/06_output.R")
```

## Step 2: Create Configuration Template (1 minute)

```r
# Create a Van Westendorp configuration template
create_pricing_config(
  output_file = "my_pricing_config.xlsx",
  method = "van_westendorp"
)

# Or for Gabor-Granger:
create_pricing_config(
  output_file = "my_gg_config.xlsx",
  method = "gabor_granger"
)
```

This creates an Excel template with all the settings you need to fill in.

## Step 3: Edit Configuration in Excel (3 minutes)

Open the Excel file and update these key settings:

### Settings Sheet

| Setting | What to Enter |
|---------|---------------|
| project_name | Your project name |
| data_file | Path to your survey data (e.g., "data/survey.csv") |
| output_file | Where to save results (e.g., "results/pricing_results.xlsx") |

### VanWestendorp Sheet (for Van Westendorp analysis)

| Setting | What to Enter |
|---------|---------------|
| col_too_cheap | Your column name for "too cheap" question |
| col_cheap | Your column name for "bargain" question |
| col_expensive | Your column name for "expensive" question |
| col_too_expensive | Your column name for "too expensive" question |

### GaborGranger Sheet (for Gabor-Granger analysis)

| Setting | What to Enter |
|---------|---------------|
| price_sequence | Your tested prices: "4.99;9.99;14.99;19.99" |
| response_columns | Your column names: "buy_499;buy_999;buy_1499;buy_1999" |

Save and close the Excel file.

## Step 4: Run Analysis (1 minute)

```r
# Run the analysis
results <- run_pricing_analysis(
  config_file = "my_pricing_config.xlsx"
)
```

You'll see progress messages as the analysis runs:

```
================================================================================
TURAS PRICING RESEARCH ANALYSIS
================================================================================

1. Loading configuration...
   Analysis method: van_westendorp
2. Loading and validating data...
   Loaded 523 respondents
   Valid cases for analysis: 498
3. Running Van Westendorp PSM analysis...
   Price points calculated:
     PMC (Point of Marginal Cheapness): $52.30
     OPP (Optimal Price Point): $74.50
     IDP (Indifference Price Point): $89.20
     PME (Point of Marginal Expensiveness): $118.40
4. Generating visualizations...
   Generated 1 plot(s)
5. Generating output file...
   Results written to: results/pricing_results.xlsx

================================================================================
ANALYSIS COMPLETE
================================================================================
```

## Step 5: Review Results (4 minutes)

### In R Console

```r
# View price points
results$results$price_points

# View acceptable price range
results$results$acceptable_range
# Lower: $52.30 - Upper: $118.40

# View optimal price range
results$results$optimal_range
# Lower: $74.50 - Upper: $89.20
```

### In Excel Output

Open your results file (e.g., "results/pricing_results.xlsx") to see:

- **Summary**: Project information and sample sizes
- **VW_Price_Points**: All four price points with descriptions
- **VW_Confidence_Intervals**: Statistical confidence bounds (if enabled)
- **VW_Curves**: Raw curve data for custom charting

### View the Plot

```r
# Display the Van Westendorp plot
print(results$plots$van_westendorp)
```

## Understanding Your Results

### Van Westendorp Price Points

| Metric | Meaning | Business Use |
|--------|---------|--------------|
| **PMC** | Point of Marginal Cheapness | Below this, perceived as "too cheap" (quality concerns) |
| **OPP** | Optimal Price Point | Sweet spot balancing value and revenue |
| **IDP** | Indifference Price Point | Equal "cheap" vs "expensive" perceptions |
| **PME** | Point of Marginal Expensiveness | Above this, most find "too expensive" |

### Price Ranges

- **Acceptable Range** (PMC to PME): Prices the market will accept
- **Optimal Range** (OPP to IDP): Best balance of value and revenue

### Gabor-Granger Results

| Metric | Meaning |
|--------|---------|
| Optimal Price | Revenue-maximizing price point |
| Purchase Intent | % willing to buy at optimal price |
| Revenue Index | Price × Purchase Intent |

## Common Issues and Solutions

### "Column not found" Error

**Problem**: Column names in config don't match your data file.

**Solution**: Open your data file, copy the exact column names, and paste them into the configuration.

### "Data file not found" Error

**Problem**: Path to data file is incorrect.

**Solution**: Use a path relative to the config file location, or use an absolute path.

### High Monotonicity Violations

**Problem**: Many respondents gave illogical price sequences.

**Solution**:
1. Review survey design - questions may be confusing
2. Set `exclude_violations = TRUE` to remove invalid responses
3. If >20% violations, reconsider the data quality

### No Intersection Found

**Problem**: Curves don't intersect within the price range.

**Solution**: Your price range may be too narrow. Check that respondents' prices span the full range of interest.

## Next Steps

- **Full User Manual**: See `USER_MANUAL.md` for comprehensive documentation
- **Example Workflows**: See `EXAMPLE_WORKFLOWS.md` for real-world scenarios
- **Technical Details**: See `TECHNICAL_DOCUMENTATION.md` for methodology

## Using the GUI

For a graphical interface, run:

```r
source("modules/pricing/run_pricing_gui.R")
```

This launches a Shiny app where you can:
- Select configuration files
- Run analyses
- View results and plots interactively
- Create configuration templates
