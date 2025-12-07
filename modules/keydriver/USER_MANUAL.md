# Key Driver Analysis - User Manual

**Version**: 2.0.0
**Last Updated**: December 2025
**Module**: Turas Key Driver Analysis

---

## Quick Start (5 Minutes)

## Prerequisites

- R installed (4.0+)
- Required packages: `openxlsx`, `shiny`, `shinyFiles`
- Optional: `haven` (for SPSS/Stata files)

---

## Option 1: Launch from Turas GUI (Easiest)

```r
# In R console
setwd("~/Documents/Turas")  # Or your Turas directory
source("launch_turas.R")
```

Click the **🔑 Key Driver** button and follow the GUI prompts.

---

## Option 2: Run from R Console

### Step 1: Prepare Your Data

**Data file** (CSV, XLSX, SAV, or DTA):
- One row per respondent
- All variables numeric (1-10 scales recommended)
- At least 60 cases for 6 drivers (rule: n ≥ max(30, 10×k))

### Step 2: Create Config File

Create an Excel file with 2 sheets:

**Sheet: Settings**
| Setting | Value |
|---------|-------|
| analysis_name | My Analysis Name |
| data_file | survey_data.csv |
| output_file | results.xlsx |

**Sheet: Variables**
| VariableName | Type | Label |
|--------------|------|-------|
| satisfaction | Outcome | Overall Satisfaction |
| quality | Driver | Product Quality |
| service | Driver | Customer Service |
| price | Driver | Value for Money |
| speed | Driver | Delivery Speed |

### Step 3: Run Analysis

```r
# Source the module
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

# Run
results <- run_keydriver_analysis(
  config_file = "my_config.xlsx"
)

# Or specify paths explicitly
results <- run_keydriver_analysis(
  config_file = "my_config.xlsx",
  data_file = "my_data.csv",
  output_file = "my_results.xlsx"
)
```

### Step 4: View Results

Open the Excel output file. You'll find **6 sheets**:

1. **Importance Summary** - All importance scores
2. **Method Rankings** - Rank by each method
3. **Model Summary** - R², VIF diagnostics
4. **Correlations** - Full correlation matrix
5. **Charts** - Shapley impact bar chart 📊
6. **README** - Methodology documentation

---

## Understanding Your Results

### Top 5 Drivers (Example)

```
1. Product Quality (28.5%)      ← Fix this first!
2. Customer Service (23.1%)     ← High impact
3. Delivery Speed (19.7%)       ← Moderate impact
4. Value for Money (15.2%)      ← Secondary
5. Website Experience (8.9%)    ← Lower priority
```

### What the Numbers Mean

- **>20%** = Major driver (high priority for improvement)
- **10-20%** = Moderate driver (secondary priority)
- **<10%** = Minor driver (limited impact)

### Check VIF (Multicollinearity)

In **Model Summary** sheet:
- **VIF < 5**: Good, low multicollinearity
- **VIF 5-10**: Moderate, watch for instability
- **VIF > 10**: High, consider removing or combining drivers

---

## Common Issues & Fixes

### Error: "Insufficient complete cases"
**Problem**: Not enough data for number of drivers
**Fix**: You need at least `max(30, 10 × #drivers)` complete cases
- 5 drivers → need 50 cases
- 8 drivers → need 80 cases

### Error: "Aliased/NA coefficients"
**Problem**: Perfect multicollinearity (two drivers perfectly correlated)
**Fix**: Remove or combine the correlated drivers

### Error: "Too many drivers (>15)"
**Problem**: Shapley computation becomes impractical with >15 drivers
**Fix**: Reduce to top 12-15 most important drivers first

### Chart doesn't display
**Problem**: Image rendering issue
**Fix**: Make sure you have a graphics device available (should work automatically)

---

## Next Steps

- Read the **USER_MANUAL.md** for detailed methodology
- Check **README.md** for advanced features (weights, etc.)
- See example configs in `test_data/` directory

---

## Quick Tips

✅ **DO:**
- Use at least 60-100 respondents
- Keep drivers to 12 or fewer if possible
- Check VIF for multicollinearity
- Use descriptive labels in config

❌ **DON'T:**
- Use <30 complete cases
- Include perfectly correlated drivers
- Use >15 drivers (Shapley limit)
- Mix categorical and numeric without recoding

---

**Need Help?** See USER_MANUAL.md or contact support.

---

## Table of Contents

1. [Introduction](#introduction)
2. [What is Key Driver Analysis?](#what-is-key-driver-analysis)
3. [Statistical Methods](#statistical-methods)
4. [Installation & Setup](#installation--setup)
5. [Configuration File Specification](#configuration-file-specification)
6. [Data File Requirements](#data-file-requirements)
7. [Running the Analysis](#running-the-analysis)
8. [Understanding the Output](#understanding-the-output)
9. [Interpretation Guidelines](#interpretation-guidelines)
10. [Advanced Features](#advanced-features)
11. [Troubleshooting](#troubleshooting)
12. [Assumptions & Limitations](#assumptions--limitations)
13. [Best Practices](#best-practices)
14. [References](#references)

---

## Introduction

The Turas Key Driver Analysis module helps you identify which independent variables (drivers) have the greatest impact on a dependent variable (outcome). This is essential for prioritizing business actions, understanding customer satisfaction drivers, or identifying factors that influence any metric of interest.

**Use Cases:**
- Customer satisfaction drivers (what drives overall satisfaction?)
- Brand health analysis (what drives brand perception?)
- Employee engagement (what drives employee satisfaction?)
- Product performance (what features drive purchase intent?)
- Any regression-based relative importance analysis

---

## What is Key Driver Analysis?

Key driver analysis answers the question: **"Which variables matter most?"**

Given an outcome variable (e.g., overall satisfaction) and multiple potential drivers (e.g., product quality, service, price), the analysis determines:

1. **How much** each driver contributes to the outcome (importance scores)
2. **The direction** of each relationship (positive/negative)
3. **The relative ranking** of drivers (which matters most)
4. **Model diagnostics** (how well the model fits, multicollinearity issues)

### Why Use Multiple Methods?

This module uses **4 complementary methods** because no single method is perfect:

- **Shapley Values**: Most robust, game-theory based, fair R² allocation
- **Relative Weights**: Handles multicollinearity well, always non-negative
- **Beta Weights**: Traditional, easy to interpret, widely understood
- **Correlations**: Simple baseline, shows bivariate relationships

By comparing all four, you get a **robust consensus** on driver importance.

---

## Statistical Methods

### 1. Shapley Value Decomposition

**What it does:** Allocates the model's R² fairly among all drivers using game theory.

**How it works:**
- Considers all possible combinations of drivers (2^k models)
- Calculates each driver's average marginal contribution across all orderings
- Guarantees fair attribution (no driver is "privileged")

**Pros:**
- Most theoretically robust
- Handles multicollinearity well
- Fair allocation (sum of Shapley values = total R²)

**Cons:**
- Computationally expensive (2^k models)
- Limited to ≤15 drivers for exact computation

**When to trust:** Always - this is the recommended method for prioritization.

---

### 2. Relative Weights (Johnson, 2000)

**What it does:** Decomposes R² into non-negative contributions via orthogonal transformation.

**How it works:**
1. Eigendecomposition of predictor correlation matrix
2. Transform predictors to orthogonal components
3. Allocate R² at component level
4. Map back to original predictors

**Pros:**
- Always non-negative and sums to 100%
- Handles multicollinearity well
- Widely used in organizational psychology

**Cons:**
- Complex calculation (eigenvalues/vectors)
- Less intuitive than beta weights

**When to trust:** When predictors are highly correlated (VIF > 5).

---

### 3. Standardized Coefficients (Beta Weights)

**What it does:** Regression coefficients in standard deviation units.

**How it works:**
- Fit OLS regression
- Standardize coefficients: β_std = β_raw × (SD_x / SD_y)
- Convert |β_std| to percentages

**Pros:**
- Easy to interpret
- Widely understood
- Shows direction (positive/negative)

**Cons:**
- Unstable with high multicollinearity (VIF > 10)
- Can have suppressor effects (negative importance)

**When to trust:** When multicollinearity is low (VIF < 5).

---

### 4. Zero-Order Correlations

**What it does:** Simple Pearson correlation between each driver and outcome.

**How it works:**
- Correlate each driver with outcome (bivariate)
- Report signed correlation coefficient

**Pros:**
- Simple and intuitive
- No multicollinearity issues

**Cons:**
- Ignores other variables
- Doesn't control for confounding
- Can be misleading with correlated predictors

**When to trust:** As a baseline or when drivers are uncorrelated.

---

## Installation & Setup

### Prerequisites

**Required:**
- R version 4.0 or higher
- Packages: `openxlsx`, `shiny`, `shinyFiles`

**Optional:**
- `haven` (for SPSS .sav or Stata .dta files)

### Install Dependencies

```r
install.packages(c("openxlsx", "shiny", "shinyFiles", "haven"))
```

### Verify Installation

```r
# Navigate to Turas directory
setwd("~/Documents/Turas")  # Adjust to your path

# Source module files
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

# If no errors, you're ready!
```

---

## Configuration File Specification

The configuration file is an Excel workbook (.xlsx) with **two sheets**:

### Sheet 1: Settings

| Setting | Description | Required | Example |
|---------|-------------|----------|---------|
| `analysis_name` | Name for this analysis | Optional | "Q4 2024 Satisfaction Drivers" |
| `data_file` | Path to data file (CSV, XLSX, SAV, DTA) | Optional* | "data/survey.csv" |
| `output_file` | Path for output Excel file | Optional* | "results/drivers.xlsx" |
| `min_sample_size` | Minimum cases required (overrides default) | Optional | 50 |

*Note: `data_file` and `output_file` can be specified in function call instead.

**Example:**

| Setting | Value |
|---------|-------|
| analysis_name | Brand Health Drivers Q4 |
| data_file | brand_survey.csv |
| output_file | brand_drivers_results.xlsx |

---

### Sheet 2: Variables

| Column | Description | Required | Values |
|--------|-------------|----------|--------|
| `VariableName` | Variable name in data file | Yes | Must match column names exactly |
| `Type` | Variable role | Yes | "Outcome", "Driver", "Weight" |
| `Label` | Descriptive label for reports | Optional | Human-readable text |

**Type values:**
- **Outcome**: Dependent variable (exactly 1 required)
- **Driver**: Independent variables (3-15 recommended)
- **Weight**: Survey weight variable (0-1 allowed)

**Example:**

| VariableName | Type | Label |
|--------------|------|-------|
| overall_sat | Outcome | Overall Satisfaction |
| product_quality | Driver | Product Quality |
| customer_service | Driver | Customer Service |
| value_for_money | Driver | Value for Money |
| delivery_speed | Driver | Delivery Speed |
| brand_reputation | Driver | Brand Reputation |
| survey_weight | Weight | Survey Weight |

---

## Data File Requirements

### File Formats

Supported formats:
- **CSV** (.csv) - comma-separated values
- **Excel** (.xlsx, .xls) - first sheet used
- **SPSS** (.sav) - requires `haven` package
- **Stata** (.dta) - requires `haven` package

---

### Data Structure

**Format:** One row per respondent (wide format)

**Columns:**
- Outcome variable (numeric)
- Driver variables (numeric)
- Optional: Weight variable (numeric, >0)
- Optional: ID or demographic variables (ignored)

**Example:**

| resp_id | overall_sat | product_quality | customer_service | value_for_money | delivery_speed | survey_weight |
|---------|-------------|-----------------|------------------|-----------------|----------------|---------------|
| 1 | 8 | 7 | 9 | 6 | 8 | 1.2 |
| 2 | 9 | 9 | 8 | 8 | 9 | 0.8 |
| 3 | 6 | 5 | 7 | 7 | 6 | 1.0 |
| 4 | 7 | 8 | 6 | 9 | 7 | 1.1 |

---

### Data Requirements

**Scale:**
- All variables must be **numeric**
- Typically 1-10 scales, but any numeric scale works
- Higher values should indicate "more" of the construct

**Sample Size:**
- Minimum: `max(30, 10 × number_of_drivers)`
- Recommended: 100+ for stable estimates
- Examples:
  - 5 drivers → need ≥50 complete cases
  - 10 drivers → need ≥100 complete cases
  - 15 drivers → need ≥150 complete cases

**Missing Data:**
- Listwise deletion (cases with any missing driver/outcome removed)
- Ensure enough complete cases remain after deletion

**Weights (Optional):**
- Must be numeric and >0
- Normalized automatically (don't pre-normalize)
- Applied to correlations, regression, and all importance methods

---

## Running the Analysis

### Option 1: GUI (Recommended for beginners)

```r
# Launch Turas main GUI
setwd("~/Documents/Turas")
source("launch_turas.R")

# Click "🔑 Key Driver" button
# Follow prompts to select project folder and config file
```

---

### Option 2: Console (Recommended for automation)

**Basic usage:**

```r
# Source module
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

# Run analysis (paths in config file)
results <- run_keydriver_analysis(
  config_file = "my_config.xlsx"
)
```

**With explicit paths:**

```r
results <- run_keydriver_analysis(
  config_file = "config/keydriver_config.xlsx",
  data_file = "data/survey.csv",
  output_file = "output/results.xlsx"
)
```

**Notes:**
- Paths can be relative or absolute
- If paths in config Settings sheet, they're used unless overridden in function call
- Function call parameters override config file paths

---

## Understanding the Output

The module creates an **Excel workbook** with **6 sheets**:

### Sheet 1: Importance Summary

**Content:** All importance metrics in one table

**Columns:**
- `Driver`: Variable name
- `Label`: Descriptive label
- `Shapley (%)`: Shapley value importance
- `Rel. Weight (%)`: Relative weight importance
- `Beta Weight (%)`: Beta weight importance (unsigned)
- `Beta Coef`: Standardized beta coefficient (signed)
- `Correlation (r)`: Zero-order correlation (signed)
- `Avg Rank`: Average rank across all methods

**How to use:**
- Sort by Shapley (%) for recommended prioritization
- Look for consensus across methods (high agreement = strong evidence)
- Check signed values (Beta Coef, Correlation) for direction

**Example interpretation:**

| Driver | Label | Shapley (%) | Rel. Weight (%) | Beta Weight (%) | Beta Coef | Correlation (r) | Avg Rank |
|--------|-------|-------------|-----------------|-----------------|-----------|-----------------|----------|
| product_quality | Product Quality | 32.5 | 31.2 | 35.1 | 0.42 | 0.68 | 1.0 |
| customer_service | Customer Service | 26.8 | 27.5 | 28.3 | 0.38 | 0.61 | 2.0 |
| value_for_money | Value for Money | 21.3 | 22.1 | 19.7 | 0.29 | 0.54 | 3.0 |

**Interpretation:** Product Quality is the #1 driver (32.5% Shapley), all methods agree (ranks 1-1), positive relationship (Beta Coef = 0.42, r = 0.68).

---

### Sheet 2: Method Rankings

**Content:** Rank positions from each method

**Columns:**
- `Driver`, `Label`
- `Shapley Rank`
- `Rel. Weight Rank`
- `Beta Rank`
- `Corr Rank`
- `Average Rank`

**How to use:**
- Check for consensus (all ranks similar = strong evidence)
- Investigate disagreements (large rank differences = check VIF)

**Example:**

| Driver | Shapley Rank | Rel. Weight Rank | Beta Rank | Corr Rank | Avg Rank |
|--------|--------------|------------------|-----------|-----------|----------|
| product_quality | 1 | 1 | 1 | 1 | 1.0 |
| customer_service | 2 | 2 | 2 | 2 | 2.0 |
| price | 3 | 3 | 5 | 3 | 3.5 |

**Interpretation:** Strong consensus for top 2 drivers. Price shows beta rank disagreement (5 vs. 3) → check VIF for multicollinearity.

---

### Sheet 3: Model Summary

**Content:** Model diagnostics and VIF

**Model Metrics:**
- `R-Squared`: Proportion of variance explained (0-1)
- `Adj R-Squared`: Adjusted for number of predictors
- `F-Statistic`: Overall model significance test
- `P-Value`: Probability model is due to chance
- `RMSE`: Root mean squared error
- `N`: Sample size

**VIF Diagnostics:**
- `Driver`: Variable name
- `VIF`: Variance Inflation Factor
- `Warning`: Multicollinearity flag

**How to use:**
- **R²**: Higher is better (>0.70 excellent, 0.50-0.70 good, 0.30-0.50 moderate, <0.30 weak)
- **P-Value**: <0.05 indicates significant model
- **VIF**: <5 good, 5-10 moderate, >10 high multicollinearity (consider removing driver)

**Example:**

**Model Metrics:**
| Metric | Value |
|--------|-------|
| R-Squared | 0.782 |
| Adj R-Squared | 0.771 |
| F-Statistic | 68.4 |
| P-Value | <0.001 |
| RMSE | 1.23 |
| N | 245 |

**VIF Diagnostics:**
| Driver | VIF | Warning |
|--------|-----|---------|
| product_quality | 2.3 | OK |
| customer_service | 3.1 | OK |
| value_for_money | 8.7 | Moderate VIF (>5) |
| brand_reputation | 12.4 | High VIF (>10) |

**Interpretation:** Good model fit (R² = 0.78), but brand_reputation has high VIF (12.4) → highly correlated with other drivers, consider removing.

---

### Sheet 4: Correlations

**Content:** Full correlation matrix of all variables

**How to use:**
- Examine relationships between drivers
- Identify highly correlated pairs (|r| > 0.80)
- Diagnose multicollinearity issues

**Example:**

|  | overall_sat | product_quality | customer_service | value_for_money |
|--|-------------|-----------------|------------------|-----------------|
| overall_sat | 1.00 | 0.68 | 0.61 | 0.54 |
| product_quality | 0.68 | 1.00 | 0.42 | 0.38 |
| customer_service | 0.61 | 0.42 | 1.00 | 0.31 |
| value_for_money | 0.54 | 0.38 | 0.31 | 1.00 |

**Interpretation:** All drivers positively correlated with outcome. No excessive multicollinearity (all |r| < 0.80).

---

### Sheet 5: Charts

**Content:** Horizontal bar chart of Shapley impact values

**How to use:**
- Visual representation for presentations
- Quickly identify top drivers
- Copy/paste into PowerPoint or reports

---

### Sheet 6: README

**Content:** Comprehensive methodology documentation

**Includes:**
- Explanation of all importance metrics
- Interpretation guidelines
- VIF thresholds
- Assumptions and limitations
- References

**How to use:**
- Share with stakeholders for transparency
- Reference when explaining methodology
- Understand assumptions and limitations

---

## Interpretation Guidelines

### Importance Score Thresholds

| Shapley Value | Interpretation | Priority |
|---------------|----------------|----------|
| >20% | Major driver | **High priority** - Fix this first! |
| 10-20% | Moderate driver | Secondary priority |
| <10% | Minor driver | Limited impact, lower priority |

---

### Method Consensus

**High Consensus (all methods agree):**
- **Strong evidence** - Trust this driver ranking
- All ranks within ±1 position
- Example: Ranks of 1, 1, 1, 2 → high consensus

**Moderate Consensus:**
- **Good evidence** - Trust with caution
- Ranks within ±2 positions
- Check VIF for multicollinearity

**Low Consensus (methods disagree):**
- **Investigate further**
- Ranks differ by >3 positions
- Possible causes:
  - High multicollinearity (check VIF)
  - Suppressor variable effects
  - Non-linear relationships
  - Outliers or data quality issues

**Action:** When consensus is low, trust Shapley values and investigate VIF.

---

### Model Fit Assessment

**R² Thresholds:**

| R² | Interpretation |
|----|----------------|
| >0.70 | Excellent - drivers explain most variance |
| 0.50-0.70 | Good - drivers capture key effects |
| 0.30-0.50 | Moderate - missing important drivers |
| <0.30 | Weak - add more drivers or reconsider model |

**What to do if R² is low (<0.30):**
1. Add more drivers (you're missing key variables)
2. Check for non-linear relationships
3. Verify data quality (outliers, errors)
4. Consider interaction effects (advanced)

---

### VIF Interpretation

**VIF Thresholds:**

| VIF | Multicollinearity | Action |
|-----|-------------------|--------|
| <5 | Low | No action needed |
| 5-10 | Moderate | Monitor, check for unstable betas |
| >10 | High | **Remove or combine** correlated drivers |

**What high VIF means:**
- Driver is highly correlated with other drivers
- Coefficient estimates become unstable
- Difficult to isolate individual driver effects

**How to fix high VIF:**
1. Remove the high-VIF driver (if it's redundant)
2. Combine correlated drivers into a composite score
3. Use dimension reduction (PCA - advanced)

---

### Signed Coefficients

**Beta Coefficient and Correlation:**
- **Positive (+)**: Driver increases outcome (e.g., higher quality → higher satisfaction)
- **Negative (−)**: Driver decreases outcome (e.g., higher price → lower satisfaction)

**Expected direction:**
- Most satisfaction drivers should be positive
- Price/cost drivers may be negative
- Unexpected signs suggest multicollinearity or suppressor effects

---

## Advanced Features

### Survey Weights Support (NEW in v2.0)

**What it does:** Weights all analyses by survey weight variable.

**When to use:**
- Probability sampling with unequal selection probabilities
- Post-stratification weights
- Any survey requiring weighted analysis

**How to specify:**

In Variables sheet, add a row with `Type = "Weight"`:

| VariableName | Type | Label |
|--------------|------|-------|
| survey_weight | Weight | Survey Weight |

**What gets weighted:**
- Correlations (weighted covariance)
- Regression model (weighted OLS)
- Shapley values (weighted R² decomposition)
- Relative weights (weighted correlation matrix)

**Notes:**
- Weights must be numeric and >0
- Weights are normalized automatically (sum to N)
- Only one weight variable allowed

---

### Handling Missing Data

**Default behavior:** Listwise deletion (complete case analysis)

**What this means:**
- Cases with missing outcome or any driver are removed
- Analysis uses only complete cases
- Sample size may be reduced

**Best practices:**
1. Check proportion of missing data before analysis
2. Ensure enough complete cases remain (see sample size rules)
3. Consider multiple imputation (external preprocessing)

**Sample size after deletion:**
- Minimum: `max(30, 10 × k)` where k = number of drivers
- Example: 6 drivers → need ≥60 complete cases

---

### Working with Categorical Variables

**Problem:** Categorical variables (e.g., gender, region) cannot be used directly.

**Solution:** Recode to numeric before analysis:

**Binary variables (2 levels):**
```r
# Gender: Male/Female → 0/1
data$gender_numeric <- ifelse(data$gender == "Male", 1, 0)
```

**Ordinal variables (ordered levels):**
```r
# Education: High School / College / Graduate → 1/2/3
data$education_numeric <- as.numeric(factor(data$education,
  levels = c("High School", "College", "Graduate"),
  ordered = TRUE
))
```

**Nominal variables (>2 unordered levels):**
- Use dummy coding (create k-1 binary variables)
- Or use alternative methods (not covered here)

---

## Troubleshooting

### Error: "Insufficient complete cases"

**Full error message:**
```
Error: Insufficient complete cases (45). Need at least 60 given 6 driver(s).
```

**Cause:** Not enough data for the number of drivers (rule: n ≥ max(30, 10×k))

**Solutions:**
1. **Reduce drivers:** Focus on top 3-5 most important drivers
2. **Get more data:** Collect additional responses
3. **Handle missing data:** Use imputation (external preprocessing)

**Example:**
- 6 drivers → need ≥60 cases
- 10 drivers → need ≥100 cases
- 15 drivers → need ≥150 cases

---

### Error: "Aliased/NA coefficients"

**Full error message:**
```
Error: The following drivers have aliased/NA coefficients (likely due to
multicollinearity): brand_trust, brand_reputation. Please remove or combine
these variables and rerun the analysis.
```

**Cause:** Two or more drivers are perfectly (or nearly perfectly) correlated.

**Diagnosis:**
1. Check Correlations sheet for |r| > 0.95
2. Examine variable definitions (are they measuring the same thing?)

**Solutions:**
1. **Remove one:** Delete the redundant driver from config
2. **Combine drivers:** Create composite score: `(brand_trust + brand_reputation) / 2`
3. **Rethink measurement:** Are these really distinct constructs?

---

### Error: "Too many drivers (>15)"

**Full error message:**
```
Error: Too many drivers (18) for exact Shapley decomposition. Please reduce
the number of drivers (e.g., to <= 15) or implement an approximate Shapley method.
```

**Cause:** Shapley requires 2^k models; 2^18 = 262,144 models is impractical.

**Solutions:**
1. **Reduce drivers:** Pre-screen with correlation analysis, keep top 12-15
2. **Group drivers:** Combine related drivers into composites
3. **Two-stage analysis:**
   - Stage 1: Run with all drivers, use beta weights to identify top 12
   - Stage 2: Re-run with top 12 drivers for Shapley values

**Computational limits:**
- k=15: 2^15 = 32,768 models (~10 seconds)
- k=18: 2^18 = 262,144 models (~2 minutes)
- k=20: 2^20 = 1,048,576 models (~10 minutes, not recommended)

---

### Error: "Zero variance" after filtering

**Full error message:**
```
Error: The following variables have zero variance: delivery_speed.
Cannot compute key driver analysis.
```

**Cause:** After removing missing data, a variable has only one unique value.

**Diagnosis:**
```r
# Check variable distribution
table(data$delivery_speed, useNA = "always")
# Output: 7  NA
#        150  95
# After listwise deletion, only value 7 remains!
```

**Solutions:**
1. **Check data quality:** Is this a coding error?
2. **Check missingness pattern:** Is missing data informative?
3. **Remove variable:** If genuinely constant, it cannot be a driver

---

### Chart doesn't display in Excel

**Symptom:** Charts sheet shows "Picture cannot be displayed"

**Cause:** Temp file deleted before Excel embedding completed (fixed in v2.0)

**Solution:** Update to v2.0 or later (this bug is fixed)

**Workaround (if using old version):**
- Open Charts sheet
- Note the data table at top
- Manually create chart in Excel from the table

---

### Methods disagree on driver importance

**Symptom:** Driver ranks vary widely across methods (e.g., Shapley rank=2, Beta rank=8)

**Diagnosis:**
1. Check VIF in Model Summary sheet
2. Check correlations between drivers

**Likely cause:** High multicollinearity (VIF >10)

**Solutions:**
1. **Trust Shapley values:** Most robust to multicollinearity
2. **Remove high-VIF drivers:** Check Model Summary VIF column
3. **Combine correlated drivers:** Create composite scores

**Example:**
```
Driver A: Shapley=25%, Rank=2, VIF=12.3
Driver B: Shapley=15%, Rank=8, Beta Weight=35%, VIF=11.8

Interpretation: A and B are highly correlated (VIF>10). Beta weights
are unstable. Trust Shapley values. Consider combining A and B.
```

---

## Assumptions & Limitations

### Statistical Assumptions

**1. Linearity**
- Assumption: Linear relationship between each driver and outcome
- Check: Scatterplots of driver vs. outcome
- Violation: Non-linear relationships will be underestimated

**2. Independence**
- Assumption: Observations are independent (no clustering)
- Check: Research design (is data clustered by store, region, etc.?)
- Violation: Standard errors underestimated, p-values unreliable

**3. Homoscedasticity**
- Assumption: Constant variance of residuals
- Check: Plot residuals vs. fitted values
- Violation: Coefficient estimates unbiased but inefficient

**4. No severe multicollinearity**
- Assumption: Drivers not perfectly correlated (VIF <10)
- Check: VIF in Model Summary sheet
- Violation: Unstable coefficients, unreliable importance estimates

**5. Normality (for inference)**
- Assumption: Residuals normally distributed
- Check: Q-Q plot of residuals
- Violation: Confidence intervals/p-values unreliable (importance estimates still valid)

---

### Key Limitations

**1. Correlation ≠ Causation**
- The analysis identifies **associations**, not **causes**
- Experimental design (randomization) needed for causal claims
- Example: "Product quality drives satisfaction" could be reverse causation or confounding

**2. Additive Effects Only**
- Assumes drivers have independent, additive effects
- Ignores interaction effects (e.g., quality × price)
- Advanced models can include interactions (not implemented)

**3. Linear Relationships Only**
- Cannot detect non-linear effects (e.g., diminishing returns, threshold effects)
- Example: Satisfaction may plateau after quality reaches 8/10

**4. Measured Drivers Only**
- Can only assess included drivers
- Omitted variable bias if key drivers missing
- Low R² (<0.30) suggests missing drivers

**5. Listwise Deletion**
- Missing data handled by removing incomplete cases
- Can introduce bias if data not missing completely at random (MCAR)
- Reduces sample size

**6. Shapley Computational Limit**
- Exact Shapley limited to ≤15 drivers (2^15 = 32,768 models)
- Approximate methods needed for >15 drivers (not implemented)

---

## Best Practices

### 1. Sample Size Planning

**Minimum:** `max(30, 10 × k)` where k = number of drivers

**Recommended:**
- 100+ for stable estimates
- 200+ for subgroup analysis
- 300+ for advanced modeling

**Rule of thumb:** 15-20 observations per driver

---

### 2. Driver Selection

**How many drivers?**
- **Minimum:** 3 drivers (less is just simple regression)
- **Optimal:** 5-12 drivers (manageable, interpretable)
- **Maximum:** 15 drivers (Shapley computational limit)

**Which drivers to include?**
1. **Theory-driven:** Based on conceptual framework
2. **Data-driven:** Pre-screen with correlations (|r| > 0.30)
3. **Practical:** Actionable (can you actually improve this?)

**Avoid:**
- Perfectly correlated drivers (|r| > 0.95)
- Redundant measures of same construct
- Drivers with no theoretical link to outcome

---

### 3. Scale Considerations

**Recommended scales:**
- 1-10 scales (good variance, intuitive)
- 1-7 Likert scales (standard in surveys)
- 0-100 scales (NPS, percentage scales)

**Avoid:**
- Binary scales (0/1) - low variance, non-linear assumptions violated
- Extremely skewed distributions (e.g., 95% at one value)

**Check:**
- All drivers use same or similar scales (1-10, not mixed with 0-100)
- Higher values mean "more" of the construct (reverse-code if needed)

---

### 4. Multicollinearity Management

**Before analysis:**
1. Check correlation matrix for |r| > 0.80
2. Consider combining highly correlated drivers
3. Ensure drivers are conceptually distinct

**After analysis:**
1. Check VIF in Model Summary sheet
2. Remove drivers with VIF >10
3. Re-run analysis and compare results

**Strategy for high VIF:**
- **VIF 5-10:** Monitor, but likely okay (trust Shapley values)
- **VIF >10:** Action required (remove or combine drivers)

---

### 5. Validation and Robustness Checks

**Check method consensus:**
- High consensus → strong evidence
- Low consensus → investigate multicollinearity (VIF)

**Check model fit:**
- R² >0.50 → drivers capture key effects
- R² <0.30 → missing important drivers

**Check VIF:**
- All VIF <10 → reliable estimates
- Any VIF >10 → remove and re-run

**Check signs:**
- Unexpected negative betas → multicollinearity or suppressor effects
- All negative correlations → check data coding (reverse scoring?)

**Sensitivity analysis:**
- Remove one driver at a time, check if rankings change
- Stable rankings → robust results
- Unstable rankings → multicollinearity issues

---

### 6. Reporting Results

**For executive audience:**
- Report top 5 drivers with Shapley values (%)
- Use visual (Charts sheet bar chart)
- Focus on actionable insights ("Fix X first")

**For technical audience:**
- Include all 4 methods for transparency
- Report VIF and model fit (R², RMSE)
- Discuss limitations (correlation ≠ causation)

**For academic audience:**
- Report full model diagnostics (Sheet 3)
- Include correlation matrix (Sheet 4)
- Cite methodology references (Johnson 2000, Shapley 1953)

---

### 7. Weighting Best Practices

**When to use weights:**
- Probability sampling with unequal selection probabilities
- Post-stratification to population benchmarks
- Required by survey methodology

**When NOT to use weights:**
- Convenience samples (weights may distort results)
- Equal probability sampling (weights unnecessary)
- Exploratory analysis (can add noise)

**Check weight distribution:**
```r
summary(data$survey_weight)
# Min should be >0
# Max/Min ratio should be <10 (extreme weights can distort)
```

---

## References

### Statistical Methodology

**Shapley Values:**
- Shapley, L. S. (1953). A value for n-person games. *Contributions to the Theory of Games*, 2(28), 307-317.

**Relative Weights:**
- Johnson, J. W. (2000). A heuristic method for estimating the relative weight of predictor variables in multiple regression. *Multivariate Behavioral Research*, 35(1), 1-19.
- Tonidandel, S., & LeBreton, J. M. (2011). Relative importance analysis: A useful supplement to regression analysis. *Journal of Business and Psychology*, 26(1), 1-9.

**General Relative Importance:**
- Grömping, U. (2006). Relative importance for linear regression in R: The package relaimpo. *Journal of Statistical Software*, 17(1), 1-27.
- Budescu, D. V. (1993). Dominance analysis: A new approach to the problem of relative importance of predictors in multiple regression. *Psychological Bulletin*, 114(3), 542-551.

---

### Software Documentation

**R Packages:**
- `openxlsx`: Schauberger, P., & Walker, A. (2021). openxlsx: Read, Write and Edit xlsx Files. R package version 4.2.4.
- `stats`: R Core Team (2024). R: A language and environment for statistical computing. R Foundation for Statistical Computing.

**Turas Key Driver Module:**
- Version 2.0.0 (2025-12-01)
- GitHub: [Turas repository]
- Author: Duncan Brett

---

### Further Reading

**Books:**
- Tabachnick, B. G., & Fidell, L. S. (2019). *Using Multivariate Statistics* (7th ed.). Pearson.
- Cohen, J., Cohen, P., West, S. G., & Aiken, L. S. (2003). *Applied Multiple Regression/Correlation Analysis for the Behavioral Sciences* (3rd ed.). Routledge.

**Online Resources:**
- UCLA Statistical Consulting: https://stats.oarc.ucla.edu/r/
- Quick-R: https://www.statmethods.net/stats/rdiagnostics.html

---

## Appendix: Example Workflow

### Complete Analysis Example

**Scenario:** You have a customer satisfaction survey with 250 respondents. You want to identify which factors drive overall satisfaction.

**Step 1: Prepare Data**

```r
# Load data
data <- read.csv("customer_survey.csv")

# Check structure
str(data)
# Variables: overall_sat, product_quality, service_quality,
#            value_for_money, delivery_speed, brand_reputation

# Check sample size
nrow(data)  # 250

# Check missing data
colSums(is.na(data))
# All <5% missing - acceptable for listwise deletion
```

**Step 2: Create Configuration File**

Create Excel file `customer_satisfaction_config.xlsx`:

**Sheet: Settings**
| Setting | Value |
|---------|-------|
| analysis_name | Customer Satisfaction Drivers Q4 2024 |
| data_file | customer_survey.csv |
| output_file | satisfaction_drivers_results.xlsx |

**Sheet: Variables**
| VariableName | Type | Label |
|--------------|------|-------|
| overall_sat | Outcome | Overall Satisfaction |
| product_quality | Driver | Product Quality |
| service_quality | Driver | Service Quality |
| value_for_money | Driver | Value for Money |
| delivery_speed | Driver | Delivery Speed |
| brand_reputation | Driver | Brand Reputation |

**Step 3: Run Analysis**

```r
# Source module
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

# Run
results <- run_keydriver_analysis(
  config_file = "customer_satisfaction_config.xlsx"
)
```

**Step 4: Review Results**

Open `satisfaction_drivers_results.xlsx`:

**Importance Summary** (top 3):
| Driver | Label | Shapley (%) | VIF |
|--------|-------|-------------|-----|
| product_quality | Product Quality | 32.5 | 2.3 |
| service_quality | Service Quality | 26.8 | 3.1 |
| value_for_money | Value for Money | 21.3 | 2.8 |

**Model Summary:**
- R² = 0.78 (excellent fit)
- All VIF <5 (low multicollinearity)
- p <0.001 (significant model)

**Step 5: Interpret & Report**

**Key findings:**
1. **Product Quality** is the #1 driver (32.5%) - highest priority for improvement
2. **Service Quality** is #2 (26.8%) - secondary priority
3. **Value for Money** is #3 (21.3%) - moderate impact
4. Model explains 78% of satisfaction variance (excellent)
5. No multicollinearity issues (all VIF <5)

**Business recommendation:**
Focus improvement efforts on product quality first, then service quality.

---

**For more help, see:**
- QUICK_START.md (5-minute guide)
- README.md (technical overview)
- KEYDRIVER_CODE_REVIEW_PACKAGE.md (full source code)

---

**End of User Manual**
