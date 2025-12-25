---
editor_options: 
  markdown: 
    wrap: 72
---

# TURAS Weighting Module - User Guide

## Table of Contents

1.  [Introduction](#1-introduction)
2.  [Quick Start](#2-quick-start)
3.  [Configuration File Setup](#3-configuration-file-setup)
4.  [Design Weights](#4-design-weights)
5.  [Rim Weights (Raking)](#5-rim-weights-raking)
6.  [Weight Trimming](#6-weight-trimming)
7.  [Understanding Diagnostics](#7-understanding-diagnostics)
8.  [Common Use Cases](#8-common-use-cases)
9.  [Troubleshooting](#9-troubleshooting)
10. [Best Practices](#10-best-practices)

------------------------------------------------------------------------

## 1. Introduction

### What is Survey Weighting?

Survey weighting adjusts for differences between your sample and the
target population. Without proper weighting, survey results may be
biased because:

-   **Under-coverage**: Some groups are harder to reach (e.g., young
    adults)
-   **Non-response**: Some groups are less likely to participate
-   **Stratified sampling**: You intentionally over-sample certain
    groups

### When Do You Need Weights?

| Situation                                     | Weighting Method |
|-----------------------------------------------|------------------|
| Stratified sample with known population sizes | Design weights   |
| Online panel needing demographic adjustment   | Rim weights      |
| Quota sample not matching population          | Rim weights      |
| Customer survey by segment with known counts  | Design weights   |
| Employee survey by department                 | Design weights   |

### What This Module Does

The TURAS Weighting Module calculates survey weights from your
specifications:

1.  **Reads** your Weight_Config.xlsx configuration
2.  **Validates** all inputs before calculation
3.  **Calculates** weights using industry-standard methods
4.  **Diagnoses** weight quality (design effect, efficiency)
5.  **Outputs** weighted data and reports

------------------------------------------------------------------------

## 2. Quick Start

### Step 1: Install Required Packages

``` r
# Install all required packages
install.packages(c("readxl", "dplyr", "openxlsx", "survey"))

# Verify survey package installation
library(survey)
packageVersion("survey")  # Should show 4.x or higher
```

### Step 2: Create Configuration File

Create `Weight_Config.xlsx` with your specifications (see Section 3).

### Step 3: Run Weighting

``` r
# From R
source("modules/weighting/run_weighting.R")
result <- run_weighting("path/to/Weight_Config.xlsx")

# Your weighted data
weighted_data <- result$data
```

Or use the GUI:

``` r
source("modules/weighting/run_weighting_gui.R")
run_weighting_gui()
```

### Step 4: Review Results

Check the diagnostics:

``` r
# View weight summary
result$weight_results[["my_weight"]]$diagnostics

# Save diagnostics to file
# (Configured in Weight_Config.xlsx)
```

------------------------------------------------------------------------

## 3. Configuration File Setup

The Weight_Config.xlsx file has 5 sheets:

### Sheet 1: General

Basic project settings:

| Setting          | Value                  | Description             |
|------------------|------------------------|-------------------------|
| project_name     | Customer_Survey_2025   | Your project name       |
| data_file        | data/responses.csv     | Path to survey data     |
| output_file      | data/weighted.csv      | Where to save output    |
| save_diagnostics | Y                      | Save diagnostic report? |
| diagnostics_file | output/diagnostics.txt | Path for report         |

**Notes:** - Paths can be relative (to config file) or absolute -
Supported data formats: .csv, .xlsx, .xls, .sav

### Sheet 2: Weight_Specifications

Define each weight you want to calculate:

| weight_name | method | description | apply_trimming | trim_method | trim_value |
|------------|------------|------------|------------|------------|------------|
| seg_weight | design | Segment weights | Y | cap | 5 |
| pop_weight | rim | Population adjustment | Y | percentile | 0.95 |

**Column Descriptions:**

-   **weight_name**: Column name for this weight (will be added to your
    data)
-   **method**: "design" or "rim"
-   **description**: Optional description for documentation
-   **apply_trimming**: "Y" or "N" - cap extreme weights?
-   **trim_method**: "cap" (hard max) or "percentile" (e.g., 95th)
-   **trim_value**: Maximum weight (for cap) or percentile threshold
    (0-1)

### Sheet 3: Design_Targets

For design weights, specify population sizes:

| weight_name | stratum_variable | stratum_category | population_size |
|-------------|------------------|------------------|-----------------|
| seg_weight  | segment          | Small            | 5000            |
| seg_weight  | segment          | Medium           | 3500            |
| seg_weight  | segment          | Large            | 1500            |

### Sheet 4: Rim_Targets

For rim weights, specify target percentages:

| weight_name | variable | category | target_percent |
|-------------|----------|----------|----------------|
| pop_weight  | Gender   | Male     | 48             |
| pop_weight  | Gender   | Female   | 52             |
| pop_weight  | Age      | 18-34    | 30             |
| pop_weight  | Age      | 35-54    | 40             |
| pop_weight  | Age      | 55+      | 30             |

**Important:** target_percent must sum to 100 for each variable!

### Sheet 5: Advanced_Settings (Optional)

Fine-tune rim weighting parameters:

| weight_name | max_iterations | convergence_tolerance | calibration_method | weight_bounds |
|-------------|----------------|----------------------|-------------------|---------------|
| pop_weight  | 50             | 1e-7                 | raking            | 0.3,3.0       |

**New in v2.0:**
- **calibration_method**: "raking" (default), "linear", or "logit"
- **weight_bounds**: Lower and upper bounds (e.g., "0.3,3.0" or single value "5")

------------------------------------------------------------------------

## 4. Design Weights

### When to Use

Use design weights when you have a **stratified sample** with known
population sizes.

**Example scenarios:** - Customer survey: You know 5,000 small, 3,500
medium, 1,500 large customers - Employee survey: You know headcount by
department - B2B survey: You sampled from a list with known company
sizes

### How It Works

Design weight = Population size ÷ Sample size

**Example:** - Population: 5,000 small customers - Sample: 100 small
customers - Weight: 5,000 ÷ 100 = 50

Each small customer respondent "represents" 50 customers.

### Setting Up Design Weights

1.  In Weight_Specifications, set `method = "design"`
2.  In Design_Targets, list each stratum with its population size

```         
| weight_name | stratum_variable | stratum_category | population_size |
|-------------|------------------|------------------|-----------------|
| size_weight | company_size     | Small            | 5000            |
| size_weight | company_size     | Medium           | 3500            |
| size_weight | company_size     | Large            | 1500            |
```

### Requirements

-   The stratum_variable must exist in your data
-   All stratum_category values must exist in your data
-   No missing values in the stratum variable
-   At least one respondent per stratum

------------------------------------------------------------------------

## 5. Rim Weights (Raking)

### When to Use

Use rim weights when you need to adjust your sample to match **multiple
demographic targets simultaneously**.

**Example scenarios:** - Online panel: Need to match census on age,
gender, region - Quota sample: Quotas hit but overall distribution is
off - General population: Sample doesn't match population demographics

### How It Works

Rim weighting (also called "raking" or "calibration") iteratively adjusts
weights until all target margins are matched:

1.  Start with all weights = 1
2.  Adjust weights to match Gender targets
3.  Adjust weights to match Age targets
4.  Adjust weights to match Region targets
5.  Repeat until all margins converge

**v2.0 uses survey::calibrate()**: Modern calibration with weight bounds
applied during fitting (not after), preventing extreme weights.

### Setting Up Rim Weights

1.  In Weight_Specifications, set `method = "rim"`
2.  In Rim_Targets, list each variable/category with target percentages

```         
| weight_name | variable | category | target_percent |
|-------------|----------|----------|----------------|
| pop_weight  | Gender   | Male     | 48             |
| pop_weight  | Gender   | Female   | 52             |
| pop_weight  | Age      | 18-34    | 30             |
| pop_weight  | Age      | 35-54    | 40             |
| pop_weight  | Age      | 55+      | 30             |
```

### Requirements

-   All rim variables must exist in your data
-   All categories must exist in your data
-   Target percentages must sum to 100 per variable
-   **No missing values** in rim variables (impute or exclude first)
-   Maximum 5 variables recommended (more may not converge)

### Understanding Convergence

Rim weighting is iterative. It may not always converge (find a
solution).

**Convergence fails when:** - Targets are mathematically impossible
(e.g., 80% male AND 80% young women) - Too many variables with too few
respondents - Categories in targets have no respondents

**If convergence fails:**
1. Increase `max_iterations` (try 100)
2. Try `calibration_method = "logit"` (better for bounded weights)
3. Adjust `weight_bounds` if needed
4. Reduce number of rim variables

------------------------------------------------------------------------

## 6. Weight Trimming

### Why Trim Weights?

Extreme weights can destabilize your results: - A respondent with weight
= 50 has 50× influence - If they're unusual, they can skew results -
High weights increase variance of estimates

### Trimming Methods

**Cap Method:** Set a hard maximum weight.

```         
trim_method = cap
trim_value = 5
```

All weights \> 5 are reduced to 5.

**Percentile Method:** Cap at a percentile of the weight distribution.

```         
trim_method = percentile
trim_value = 0.95
```

Weights above the 95th percentile are capped.

### When to Use Trimming

| Design Effect | Recommendation              |
|---------------|-----------------------------|
| \< 2.0        | Trimming usually not needed |
| 2.0 - 3.0     | Consider trimming           |
| \> 3.0        | Trimming recommended        |

### Trade-offs

-   **Trimming reduces variance** (more stable estimates)
-   **Trimming introduces bias** (targets no longer exactly matched)
-   Generally, modest trimming (cap at 5) is a good compromise

------------------------------------------------------------------------

## 7. Understanding Diagnostics

### Key Metrics

**Effective Sample Size (n_eff)** How many unweighted respondents your
weighted sample is "worth."

-   Formula: n_eff = (Σw)² / Σw²
-   Higher is better
-   n_eff \< n indicates precision loss from weighting

**Design Effect (DEFF)** Factor by which variance is inflated due to
weighting.

-   Formula: DEFF = n / n_eff
-   DEFF = 1.0: No effect (equal weights)
-   DEFF = 2.0: Variance doubled, standard errors ×1.4

**Efficiency** What percentage of your sample is "usable" after
weighting.

-   Formula: Efficiency = n_eff / n × 100%
-   100% = no loss
-   50% = half your sample "wasted" due to weighting

### Quality Thresholds

| Metric        | Good   | Acceptable | Poor   |
|---------------|--------|------------|--------|
| Design Effect | \< 2.0 | 2.0 - 3.0  | \> 3.0 |
| Efficiency    | \> 70% | 50% - 70%  | \< 50% |
| CV of weights | \< 0.5 | 0.5 - 1.0  | \> 1.0 |

### Reading the Diagnostic Report

```         
================================================================================
WEIGHT DIAGNOSTICS: population_weight
================================================================================

METHOD: Rim Weighting
CONVERGENCE: ✓ Converged in 12 iterations     <- Good!

SAMPLE SIZE:
  Total cases:              1,000
  Valid weights:              998             <- 2 excluded
  Zero/NA weights:              2 (0.2%)

WEIGHT DISTRIBUTION:
  Min:                       0.412
  Max:                       4.876             <- Watch for very high max
  Mean:                      1.000             <- Should be ~1.0
  CV:                        0.543             <- < 1.0 is good

EFFECTIVE SAMPLE SIZE:
  Effective N:                 847             <- Your "real" sample size
  Design effect:              1.18             <- Good! (< 2.0)
  Efficiency:                84.7% ✓           <- Excellent

QUALITY ASSESSMENT: ✓ GOOD
```

------------------------------------------------------------------------

## 8. Common Use Cases

### Use Case 1: Customer Survey by Segment

**Scenario:** You surveyed customers and over-sampled large accounts.

**Configuration:**

```         
Weight_Specifications:
| weight_name | method |
| cust_weight | design |

Design_Targets:
| weight_name | stratum_variable | stratum_category | population_size |
| cust_weight | account_size     | Small            | 8000            |
| cust_weight | account_size     | Medium           | 1500            |
| cust_weight | account_size     | Large            | 500             |
```

### Use Case 2: Online Panel Study

**Scenario:** Your panel sample doesn't match census demographics.

**Configuration:**

```         
Weight_Specifications:
| weight_name | method | apply_trimming | trim_method | trim_value |
| census_wt   | rim    | Y              | cap         | 5          |

Rim_Targets:
| weight_name | variable | category | target_percent |
| census_wt   | Age      | 18-34    | 30             |
| census_wt   | Age      | 35-54    | 35             |
| census_wt   | Age      | 55+      | 35             |
| census_wt   | Gender   | Male     | 49             |
| census_wt   | Gender   | Female   | 51             |
| census_wt   | Region   | Urban    | 65             |
| census_wt   | Region   | Rural    | 35             |
```

### Use Case 3: Multiple Weight Columns

**Scenario:** You need different weights for different analyses.

**Configuration:**

```         
Weight_Specifications:
| weight_name    | method | description                    |
| revenue_weight | design | Weight by revenue contribution |
| count_weight   | design | Weight by company count        |
| demo_weight    | rim    | Demographic adjustment         |
```

Each weight becomes a separate column in your output data.

------------------------------------------------------------------------

## 9. Troubleshooting

### Error: "Rim weighting did not converge"

**Causes:** 1. Too many rim variables 2. Impossible target combinations
3. Categories with no respondents

**Solutions:** 1. Reduce to 3-4 rim variables 2. Increase
`max_iterations` to 50 3. Relax `convergence_tolerance` to 0.02 4. Check
for empty cells in your cross-tabs

### Error: "Category not found in data"

**Cause:** Category value in config doesn't match data exactly.

**Solutions:** 1. Check spelling and case (categories are
case-sensitive) 2. Check for extra spaces in data or config 3. Verify
the variable name is correct

### Error: "Missing values in stratum variable"

**Cause:** Your stratification variable has NA values.

**Solutions:** 1. Remove rows with missing values before weighting 2.
Create a "Missing" category and include in targets 3. Impute missing
values

### Warning: "High design effect"

**Cause:** Weights vary too much, reducing precision.

**Solutions:** 1. Apply weight trimming (cap at 5) 2. Review sampling
design 3. Accept reduced effective sample size

### Weights all equal 1

**Cause:** No weighting was applied.

**Check:** 1. Method is set correctly in Weight_Specifications 2.
Targets are defined in correct sheet 3. weight_name matches between
sheets

------------------------------------------------------------------------

## 10. Best Practices

### Before Weighting

1.  **Clean your data first**
    -   Handle missing values before weighting
    -   Remove duplicate records
    -   Verify variable coding
2.  **Understand your population**
    -   Use reliable population data (census, customer database)
    -   Document your population source
3.  **Start simple**
    -   Begin with few rim variables
    -   Add more only if needed

### During Weighting

1.  **Check diagnostics**
    -   Always review effective sample size
    -   Investigate high design effects
2.  **Use trimming wisely**
    -   Start without trimming
    -   Add trimming if design effect \> 2.0
    -   Modest caps (5) are usually sufficient
3.  **Document everything**
    -   Keep your config file with your project
    -   Save diagnostic reports

### After Weighting

1.  **Validate results**
    -   Check weighted margins match targets
    -   Compare weighted vs unweighted results
    -   Look for unusual patterns
2.  **Report appropriately**
    -   Always report effective sample size
    -   Note if weights were trimmed
    -   Include weighting methodology in reports

### Common Mistakes to Avoid

❌ **Don't** use too many rim variables (max 5)

❌ **Don't** weight on post-stratification variables you're analyzing

❌ **Don't** ignore high design effects

❌ **Don't** use weights for small subgroups without checking n_eff

❌ **Don't** create weights with your outcome variable in the model

------------------------------------------------------------------------

## Getting Help

For issues with the TURAS Weighting Module:

1.  Check the error message carefully - it includes specific guidance
2.  Review this User Guide and the Template Reference
3.  Check the Technical Documentation for implementation details
4.  Consult the TURAS support resources

------------------------------------------------------------------------

*TURAS Weighting Module v2.0 \| December 2025*
