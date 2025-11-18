# Turas Pricing Module: User Manual

## Table of Contents

1. [Introduction](#1-introduction)
2. [Installation and Setup](#2-installation-and-setup)
3. [Pricing Methods Overview](#3-pricing-methods-overview)
4. [Data Preparation](#4-data-preparation)
5. [Configuration Guide](#5-configuration-guide)
6. [Running Analyses](#6-running-analyses)
7. [Understanding Results](#7-understanding-results)
8. [Visualizations](#8-visualizations)
9. [Advanced Features](#9-advanced-features)
10. [Best Practices](#10-best-practices)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Introduction

### 1.1 Module Overview

The Turas Pricing module provides production-ready pricing research capabilities designed for market researchers and analysts who need to determine optimal pricing strategies. The module implements two widely-used pricing research methodologies—Van Westendorp Price Sensitivity Meter and Gabor-Granger—through an intuitive Excel-based configuration system.

The module is designed to handle the complete pricing analysis workflow from data validation through publication-ready outputs. Users can run analyses through either R commands or the included Shiny graphical interface, making it accessible to both programmers and non-technical users.

### 1.2 When to Use Each Method

**Use Van Westendorp PSM when:**
- You need to understand the acceptable price range for a new product
- You want to identify psychological price thresholds
- You're exploring price perception without specific price points in mind
- Sample size is at least 100 respondents

**Use Gabor-Granger when:**
- You need to construct a demand curve
- You want to find the revenue-maximizing price
- You have specific price points to test
- You need price elasticity information
- Sample size is at least 100 respondents

**Use Both Methods when:**
- You want to triangulate your pricing recommendation
- You're conducting comprehensive pricing research
- You have both types of questions in your survey

---

## 2. Installation and Setup

### 2.1 System Requirements

- **R Version**: 4.0.0 or higher
- **Operating System**: Windows, macOS, or Linux
- **Memory**: 4GB RAM minimum (8GB recommended for large datasets)

### 2.2 Package Dependencies

Install required packages:

```r
install.packages(c(
  "readxl",    # Excel file reading
  "openxlsx",  # Excel file writing
  "ggplot2"    # Visualizations
))

# Optional packages
install.packages(c(
  "haven",     # SPSS/Stata file support
  "shiny"      # GUI interface
))
```

### 2.3 Verification

Test that the module loads correctly:

```r
# Source module files
source("modules/pricing/R/00_main.R")
source("modules/pricing/R/01_config.R")
source("modules/pricing/R/02_validation.R")
source("modules/pricing/R/03_van_westendorp.R")
source("modules/pricing/R/04_gabor_granger.R")
source("modules/pricing/R/05_visualization.R")
source("modules/pricing/R/06_output.R")

# Test template creation
create_pricing_config("test_config.xlsx", method = "van_westendorp")
# Should output: "Configuration template created: test_config.xlsx"
```

---

## 3. Pricing Methods Overview

### 3.1 Van Westendorp Price Sensitivity Meter

The Van Westendorp PSM was developed by Dutch economist Peter van Westendorp in 1976. It uses four questions to map consumer price perceptions and identify key price thresholds.

**The Four Questions:**
1. "At what price would you consider this product to be so cheap that you would question its quality?" (Too Cheap)
2. "At what price would you consider this product to be a bargain—a great buy for the money?" (Cheap/Bargain)
3. "At what price would you consider this product to be getting expensive—not out of the question, but you would have to give some thought to buying it?" (Expensive)
4. "At what price would you consider this product to be too expensive to consider?" (Too Expensive)

**Key Price Points:**

| Point | Name | Interpretation |
|-------|------|----------------|
| PMC | Point of Marginal Cheapness | Below this price, quality concerns arise. Intersection of "Too Cheap" and "Not Cheap" curves. |
| OPP | Optimal Price Point | Minimizes price resistance. Intersection of "Too Cheap" and "Too Expensive" curves. |
| IDP | Indifference Price Point | Equal perceptions of cheap vs expensive. Intersection of "Cheap" and "Expensive" curves. |
| PME | Point of Marginal Expensiveness | Above this, most consider too expensive. Intersection of "Not Expensive" and "Too Expensive" curves. |

**Price Ranges:**
- **Range of Acceptable Prices**: PMC to PME
- **Optimal Price Range**: OPP to IDP

### 3.2 Gabor-Granger Method

The Gabor-Granger method, developed by André Gabor and Clive Granger in 1966, measures purchase intent at specific price points to construct a demand curve.

**Methodology:**
Respondents are shown a product at various price points and asked if they would purchase at each price. This creates a direct relationship between price and demand.

**Key Outputs:**
- **Demand Curve**: Shows % of respondents willing to purchase at each price
- **Revenue Curve**: Price × Purchase Intent at each point
- **Optimal Price**: The price that maximizes expected revenue
- **Price Elasticity**: Responsiveness of demand to price changes

### 3.3 Method Comparison

| Aspect | Van Westendorp | Gabor-Granger |
|--------|----------------|---------------|
| Output | Price range | Specific optimal price |
| Data Type | Open-ended prices | Fixed price points |
| Best For | New products, exploration | Established products, optimization |
| Complexity | Lower | Higher |
| Sample Size | 100+ | 100+ |

---

## 4. Data Preparation

### 4.1 Van Westendorp Data Requirements

Your data must include four numeric columns representing the four price questions:

```
respondent_id, q1_too_cheap, q2_bargain, q3_expensive, q4_too_expensive
1001, 5.00, 15.00, 45.00, 75.00
1002, 8.00, 20.00, 50.00, 80.00
1003, 3.00, 12.00, 40.00, 65.00
...
```

**Requirements:**
- All price values should be numeric
- Values should follow logical sequence: too_cheap ≤ bargain ≤ expensive ≤ too_expensive
- Missing values allowed but will be excluded from analysis

### 4.2 Gabor-Granger Data Requirements

#### Wide Format (Most Common)

Each row is one respondent with columns for each price point:

```
respondent_id, buy_499, buy_999, buy_1499, buy_1999, buy_2499
1001, 1, 1, 1, 0, 0
1002, 1, 1, 0, 0, 0
1003, 1, 1, 1, 1, 0
...
```

#### Long Format

Multiple rows per respondent:

```
respondent_id, price, purchase_intent
1001, 4.99, 1
1001, 9.99, 1
1001, 14.99, 1
1001, 19.99, 0
1001, 24.99, 0
1002, 4.99, 1
...
```

### 4.3 Supported File Formats

- **CSV** (.csv): Comma-separated values
- **Excel** (.xlsx, .xls): Microsoft Excel
- **SPSS** (.sav): Requires `haven` package
- **Stata** (.dta): Requires `haven` package
- **R Data** (.rds): Native R format

---

## 5. Configuration Guide

### 5.1 Creating a Configuration File

```r
# Van Westendorp template
create_pricing_config(
  output_file = "vw_config.xlsx",
  method = "van_westendorp"
)

# Gabor-Granger template
create_pricing_config(
  output_file = "gg_config.xlsx",
  method = "gabor_granger"
)

# Both methods
create_pricing_config(
  output_file = "combined_config.xlsx",
  method = "both"
)
```

### 5.2 Settings Sheet

The Settings sheet contains core configuration:

| Setting | Required | Description | Example |
|---------|----------|-------------|---------|
| project_name | No | Project identifier | "Q4 Pricing Study" |
| analysis_method | Yes | van_westendorp, gabor_granger, or both | "van_westendorp" |
| data_file | Yes | Path to data file | "data/survey.csv" |
| output_file | No | Path for results | "results/output.xlsx" |
| id_column | No | Respondent ID column | "resp_id" |
| weight_column | No | Survey weight column | "weight" |
| currency_symbol | No | Currency for display | "$" |
| verbose | No | Show progress messages | "TRUE" |

### 5.3 VanWestendorp Sheet

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| col_too_cheap | Yes | - | Column name for "too cheap" |
| col_cheap | Yes | - | Column name for "bargain" |
| col_expensive | Yes | - | Column name for "expensive" |
| col_too_expensive | Yes | - | Column name for "too expensive" |
| validate_monotonicity | No | TRUE | Check price sequence logic |
| exclude_violations | No | FALSE | Remove illogical responses |
| violation_threshold | No | 0.1 | Max allowed violation rate |
| interpolation_method | No | "linear" | linear or spline |
| calculate_confidence | No | FALSE | Calculate bootstrap CIs |
| confidence_level | No | 0.95 | Confidence level |
| bootstrap_iterations | No | 1000 | Number of bootstrap samples |
| price_decimals | No | 2 | Decimal places in output |

### 5.4 GaborGranger Sheet

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| data_format | Yes | "wide" | wide or long |
| price_sequence | Wide format | - | Prices tested (e.g., "4.99;9.99;14.99") |
| response_columns | Wide format | - | Column names (e.g., "buy_499;buy_999") |
| price_column | Long format | - | Column with prices |
| response_column | Long format | - | Column with responses |
| respondent_column | Long format | - | Respondent ID column |
| response_type | No | "binary" | binary, scale, or auto |
| scale_threshold | No | 3 | Top-box cutoff for scale data |
| check_monotonicity | No | TRUE | Check for monotonic demand |
| calculate_elasticity | No | TRUE | Calculate price elasticity |
| revenue_optimization | No | TRUE | Find optimal price |
| confidence_intervals | No | FALSE | Bootstrap confidence bands |

### 5.5 Validation Sheet

| Setting | Default | Description |
|---------|---------|-------------|
| min_completeness | 0.8 | Minimum response completeness |
| price_min | 0 | Minimum valid price |
| price_max | 10000 | Maximum valid price |
| flag_outliers | TRUE | Identify statistical outliers |
| outlier_method | "iqr" | iqr, zscore, or percentile |
| outlier_threshold | 3 | Threshold for outlier detection |

---

## 6. Running Analyses

### 6.1 Command Line Execution

```r
# Basic usage
results <- run_pricing_analysis(
  config_file = "my_config.xlsx"
)

# Override data file
results <- run_pricing_analysis(
  config_file = "my_config.xlsx",
  data_file = "new_data.csv"
)

# Override output file
results <- run_pricing_analysis(
  config_file = "my_config.xlsx",
  output_file = "custom_output.xlsx"
)
```

### 6.2 Using the GUI

Launch the Shiny interface:

```r
source("modules/pricing/run_pricing_gui.R")
```

The GUI provides:
- Configuration file selection
- Data file override option
- Results display
- Interactive plots
- Template creation

### 6.3 Progress Output

When verbose mode is enabled, you'll see:

```
================================================================================
TURAS PRICING RESEARCH ANALYSIS
================================================================================

1. Loading configuration...
   Analysis method: van_westendorp
   Project: Q4 Product Pricing
2. Loading and validating data...
   Loaded 523 respondents
   ! 3 validation warnings (see diagnostics)
   Excluded 25 invalid cases
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

---

## 7. Understanding Results

### 7.1 Results Object Structure

```r
results <- run_pricing_analysis("config.xlsx")

# Top level
results$method          # "van_westendorp", "gabor_granger", or "both"
results$results         # Analysis results
results$plots           # Plot objects
results$diagnostics     # Validation information
results$config          # Configuration used
```

### 7.2 Van Westendorp Results

```r
# Price points
results$results$price_points
# $PMC: 52.30
# $OPP: 74.50
# $IDP: 89.20
# $PME: 118.40

# Acceptable range
results$results$acceptable_range
# $lower: 52.30
# $upper: 118.40

# Optimal range
results$results$optimal_range
# $lower: 74.50
# $upper: 89.20

# Curve data (for custom plotting)
head(results$results$curves)

# Confidence intervals (if calculated)
results$results$confidence_intervals

# Descriptive statistics
results$results$descriptives
```

### 7.3 Gabor-Granger Results

```r
# Demand curve
results$results$demand_curve
#   price n_respondents n_purchase purchase_intent
# 1  4.99           500        425           0.850
# 2  9.99           500        350           0.700
# 3 14.99           500        260           0.520
# 4 19.99           500        150           0.300
# 5 24.99           500         75           0.150

# Revenue curve
results$results$revenue_curve

# Optimal price
results$results$optimal_price
# $price: 14.99
# $purchase_intent: 0.52
# $revenue_index: 7.79

# Elasticity
results$results$elasticity
```

### 7.4 Interpreting Price Points

**PMC (Point of Marginal Cheapness)**: $52.30
- Below this price, respondents question quality
- Sets the floor for your pricing

**OPP (Optimal Price Point)**: $74.50
- Balances attractiveness and revenue
- Often recommended as the target price

**IDP (Indifference Price Point)**: $89.20
- Equal "cheap" and "expensive" perceptions
- Upper bound of optimal range

**PME (Point of Marginal Expensiveness)**: $118.40
- Above this, most consider too expensive
- Ceiling for your pricing

**Recommendation**: Price between OPP and IDP ($74.50 - $89.20) for optimal balance.

### 7.5 Interpreting Elasticity

| Elasticity Value | Interpretation | Implication |
|------------------|----------------|-------------|
| > -1 (e.g., -0.5) | Inelastic | Price increase won't hurt demand much |
| = -1 | Unit elastic | Revenue stable with price changes |
| < -1 (e.g., -2.0) | Elastic | Price increase will hurt demand significantly |

---

## 8. Visualizations

### 8.1 Van Westendorp Plot

The PSM plot shows four cumulative curves with intersection points:

```r
# Display plot
print(results$plots$van_westendorp)

# Save to file
ggsave("vw_plot.png", results$plots$van_westendorp,
       width = 10, height = 7, dpi = 300)
```

**Plot Elements:**
- **Red curve**: Too Cheap (decreasing)
- **Blue curve**: Not Cheap (increasing)
- **Green curve**: Not Expensive (decreasing)
- **Orange curve**: Too Expensive (increasing)
- **Gray shading**: Acceptable range
- **Blue shading**: Optimal range
- **Dashed lines**: Price point locations

### 8.2 Gabor-Granger Plots

**Demand Curve:**
```r
print(results$plots$demand_curve)
```

Shows purchase intent declining with price. Optimal price marked in red.

**Revenue Curve:**
```r
print(results$plots$revenue_curve)
```

Shows revenue index with peak at optimal price.

---

## 9. Advanced Features

### 9.1 Bootstrap Confidence Intervals

Enable confidence intervals for statistical rigor:

```r
# In config: calculate_confidence = TRUE
```

Results include:
- Standard errors for each price point
- Lower and upper confidence bounds
- Based on percentile method

### 9.2 Price Elasticity Analysis

Gabor-Granger automatically calculates arc elasticity:

```r
results$results$elasticity
#   price_from price_to arc_elasticity elasticity_type
# 1       4.99     9.99          -0.52       Inelastic
# 2       9.99    14.99          -1.23         Elastic
# 3      14.99    19.99          -2.15         Elastic
```

### 9.3 Running Both Methods

```r
# In config: analysis_method = "both"
results <- run_pricing_analysis("combined_config.xlsx")

# Access both results
vw_points <- results$results$van_westendorp$price_points
gg_optimal <- results$results$gabor_granger$optimal_price
```

### 9.4 Exporting to CSV

```r
export_pricing_csv(
  results = results,
  output_dir = "exports",
  config = results$config
)
```

---

## 10. Best Practices

### 10.1 Sample Size Recommendations

| Analysis Type | Minimum | Recommended | For Segments |
|---------------|---------|-------------|--------------|
| Van Westendorp | 100 | 300 | 100 per segment |
| Gabor-Granger | 100 | 300 | 100 per segment |

### 10.2 Survey Design

**Van Westendorp Questions:**
- Ask in consistent order
- Use clear, unbiased wording
- Allow open-ended numeric entry
- Provide context about the product

**Gabor-Granger Questions:**
- Select 5-7 realistic price points
- Space prices evenly or use logarithmic scale
- Include current market prices
- Randomize price order if possible

### 10.3 Data Quality

- Check for monotonicity violations (should be <10%)
- Review outliers before exclusion
- Ensure adequate response completeness
- Validate against known benchmarks

### 10.4 Interpretation

- Consider competitive context
- Account for brand positioning
- Validate with other research
- Test recommendations with A/B testing

---

## 11. Troubleshooting

### 11.1 Common Errors

**"Column not found in data"**
- Verify column names match exactly (case-sensitive)
- Check for leading/trailing spaces
- Open data file to confirm column names

**"Data file not found"**
- Use relative path from config file location
- Or use absolute path
- Check for typos in filename

**"Invalid analysis method"**
- Must be: "van_westendorp", "gabor_granger", or "both"
- Check spelling and case

### 11.2 Warning Messages

**"High monotonicity violations"**
- Review survey design for confusing questions
- Consider excluding violations with `exclude_violations = TRUE`
- Investigate specific violation patterns

**"Low sample size"**
- Results may be unstable
- Consider combining segments
- Use wider confidence intervals

### 11.3 Unexpected Results

**Price points out of logical order**
- Review curve data for calculation issues
- Check for data quality problems
- Verify question wording

**Optimal price at boundary**
- Price range may be too narrow
- Consider expanding tested prices
- Review demand curve shape

### 11.4 Getting Help

1. Check this manual and QUICK_START.md
2. Review EXAMPLE_WORKFLOWS.md for similar cases
3. Examine TECHNICAL_DOCUMENTATION.md for methodology details
4. Contact your organization's analytics support
