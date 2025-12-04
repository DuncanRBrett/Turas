# Key Driver Config Template - User Manual

**Template File:** `templates/KeyDriver_Config_Template.xlsx`
**Version:** 10.0
**Last Updated:** 4 December 2025

---

## Overview

The Key Driver Config Template configures Key Driver Analysis in TURAS. This module determines which drivers (independent variables) have the greatest impact on an outcome variable (dependent variable) using multiple statistical methods.

**Key Purpose:** Identify which factors matter most in driving customer satisfaction, NPS, loyalty, or other key business metrics.

**Methods Used:** 4 statistical methods rank drivers by importance:
1. **Shapley Values** (game theory) - Most robust, recommended ⭐
2. **Relative Weights** (Johnson 2000) - Handles multicollinearity well
3. **Beta Weights** (standardized coefficients) - Traditional, easy to interpret
4. **Correlations** (bivariate) - Simple baseline

---

## Template Structure

The template contains **3 sheets**:

1. **Instructions** - Comprehensive methodology guide and weighting documentation
2. **Settings** - Analysis configuration
3. **Variables** - Definition of outcome, drivers, and optional weight variable

---

## Sheet 1: Instructions

**Purpose:** Provides detailed documentation of methodology, workflow, and how weights work in key driver analysis.

**Action Required:** Review for understanding. This sheet is not read by the analysis code.

**Key Content:**
- Overview of 4 statistical methods
- Workflow: data preparation → run analysis → review output
- Example results interpretation
- Model diagnostics (R², VIF)
- Detailed explanation of how weights affect each method
- Known weighting issues and workarounds

**Important Weighting Information:**
- **Correlations:** ✅ Properly weighted
- **Regression:** ✅ Properly weighted
- **Relative Weights:** ✅ Fully correct with weights (MOST TRUSTWORTHY)
- **Beta Weights:** ⚠️ Minor inconsistency (weighted coefficients, unweighted SDs)
- **Shapley Values:** ❌ Bug - subset models not weighted

**Recommendation:** When using weights, trust **Relative Weights** method as your primary importance metric.

---

## Sheet 2: Settings

**Purpose:** Configure analysis parameters and file paths.

**Required Columns:** 2 columns only (`Setting`, `Value`)

### Field Specifications

#### Setting: analysis_name

- **Purpose:** Display name for analysis in output
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Any descriptive text
- **Logic:** **This is just a label for the config file and has no effect on the analysis**
- **Example:** `Brand Health Drivers` or `Q1 2024 Satisfaction Analysis`
- **Common Mistakes:** None - purely cosmetic

#### Setting: data_file

- **Purpose:** Path to respondent-level data file
- **Required:** YES
- **Data Type:** Text (file path)
- **Valid Values:**
  - Path to .csv, .xlsx, .sav, or .dta file
  - Can be relative to config file or absolute path
- **Logic:**
  - Each row = one respondent
  - Must contain all variables listed in Variables sheet
  - Variables must be numeric (scales like 1-10)
- **Example:** `/Projects/Test/keydriver_test_data.csv` or `../data/survey.xlsx`
- **Common Mistakes:**
  - File doesn't exist
  - Variables not numeric
  - Column names don't match Variables sheet

#### Setting: output_file

- **Purpose:** Path and name for results Excel file
- **Required:** YES (but has default)
- **Data Type:** Text (file path)
- **Valid Values:** Path ending in .xlsx
- **Default:** If not specified, creates `keydriver_results.xlsx` in config file directory
- **Logic:** Creates multi-sheet Excel workbook with importance scores, rankings, diagnostics
- **Example:** `/Projects/Test/keydriver_test_results.xlsx`

**Important Notes:**
- To use weights, define a variable with `Type = "Weight"` in the Variables sheet (NOT in Settings)
- If you add other settings to Settings sheet, they will be loaded but ignored by analysis code

---

## Sheet 3: Variables

**Purpose:** Define the outcome variable, driver variables, and optional weight variable.

**Required Columns:** `VariableName`, `Type`, `Label`

### Field Specifications

#### Column: VariableName

- **Purpose:** Column name in data file
- **Required:** YES
- **Data Type:** Text
- **Valid Values:**
  - Must match data file column name EXACTLY (case-sensitive)
  - Must be numeric variable in data
- **Logic:** Links config to actual data columns
- **Example:** `overall_satisfaction`, `product_quality`, `survey_weight`
- **Common Mistakes:**
  - Case mismatch (data has `Satisfaction` but config has `satisfaction`)
  - Typo doesn't match data
  - Using non-numeric variable

#### Column: Type

- **Purpose:** Variable role in the analysis
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `Outcome`, `Driver`, `Weight`
- **Logic:**
  - `Outcome` = Dependent variable you're trying to explain (exactly 1 required)
  - `Driver` = Independent variables/predictors (3-15 recommended)
  - `Weight` = Survey weight variable (0 or 1 allowed)
- **Example:** `Outcome`, `Driver`, `Weight`
- **Common Mistakes:**
  - Multiple Outcome variables (only 1 allowed)
  - Too few drivers (minimum 2, but 3+ recommended)
  - Too many drivers (>15 makes Shapley computation slow)

#### Column: Label

- **Purpose:** Human-readable label for reports
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** Any descriptive text
- **Default:** Uses VariableName if blank
- **Logic:** Appears in output for readability
- **Example:** `Overall Satisfaction`, `Product Quality`, `Survey Weight`

---

## Variable Type Requirements

### Type: Outcome

- **Count Required:** Exactly 1
- **What It Does:** Dependent variable you're trying to explain
- **Examples:** `overall_satisfaction`, `nps_score`, `repurchase_intent`
- **Data Requirements:**
  - Must be numeric
  - Typically a rating scale (1-10, 1-5, etc.)
  - No missing values preferred (or will be excluded)

### Type: Driver

- **Count Required:** 3-15 recommended
- **What It Does:** Independent variables (predictors) that may influence the outcome
- **Examples:** `product_quality`, `customer_service`, `delivery_speed`, `price_value`
- **Data Requirements:**
  - Must be numeric
  - Typically same scale as outcome (1-10, 1-5, etc.)
  - Should have reasonable variation (not all same value)

**Driver Count Limits:**
- **Minimum:** 2 drivers (but 3+ strongly recommended)
- **Maximum:** 15 drivers (Shapley computation limit)
- **Optimal:** 8-12 drivers for interpretability and model stability

### Type: Weight

- **Count Required:** 0 or 1 (optional)
- **What It Does:** Survey weight variable for weighted analysis
- **Example:** `survey_weight`, `Weight`, `final_weight`
- **Data Requirements:**
  - Must be numeric
  - Must be >0 (positive weights only)
  - NA weights will cause cases to be excluded
- **Logic:**
  - Only one weight variable allowed
  - If multiple specified, uses first with warning
  - Applies to all methods (with varying degrees of correctness - see Instructions sheet)

---

## Data Requirements

### Row Structure
- **One row per respondent**
- Each row contains outcome, all drivers, and optional weight

### Variable Requirements
- **Numeric variables only** (1-10 scales typical)
- **Sufficient complete cases:** n ≥ max(30, 10 × number of drivers)
  - Example: 6 drivers → need 60+ complete respondents
  - Example: 10 drivers → need 100+ complete respondents

### Example Data Structure

```
respondent_id | overall_satisfaction | product_quality | customer_service | delivery | survey_weight
1             | 8                    | 7               | 9                | 8        | 1.05
2             | 6                    | 5               | 7                | 6        | 0.98
3             | 9                    | 9               | 8                | 9        | 1.12
```

---

## Complete Configuration Example

### Customer Satisfaction Drivers Study

**Settings sheet:**
```
Setting         | Value
analysis_name   | Q1 2024 Customer Satisfaction Drivers
data_file       | /data/satisfaction_survey.csv
output_file     | /output/sat_drivers_Q1.xlsx
```

**Variables sheet:**
```
VariableName          | Type    | Label
overall_satisfaction  | Outcome | Overall Satisfaction
product_quality       | Driver  | Product Quality
customer_service      | Driver  | Customer Service
delivery_speed        | Driver  | Delivery Speed
price_value           | Driver  | Price/Value Ratio
website_ease          | Driver  | Website Ease of Use
brand_reputation      | Driver  | Brand Reputation
survey_weight         | Weight  | Survey Weight
```

---

## Running the Analysis

### Via R Script

```r
# Source module files
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

# Run analysis
results <- run_keydriver_analysis(
  config_file = "path/to/keydriver_config.xlsx"
)
```

---

## Output Structure

The analysis produces Excel file with **6 sheets**:

### 1. Importance Summary
- All importance scores by method (Shapley, Relative Weights, Beta, Correlation)
- Shows percentage contribution of each driver
- Allows comparison across methods

### 2. Method Rankings
- Rank comparison across all 4 methods
- Shows consistency/disagreement
- **Average_Rank** column (use cautiously if weighted - includes buggy Shapley)

### 3. Model Summary
- R² (model fit)
- VIF (multicollinearity diagnostics)
- Coefficients and p-values
- Sample size

### 4. Correlations
- Full correlation matrix
- All drivers vs outcome
- Drivers vs drivers (check multicollinearity)

### 5. Charts
- Bar chart visualization of importance scores
- Visual comparison across methods

### 6. README
- Methodology documentation
- How to interpret results

---

## Interpreting Results

### Example Output

```
Driver               Shapley  RelWeight  Beta   Correlation  Average_Rank
──────────────────────────────────────────────────────────────────────────
Product Quality      32.5%    31.8%      28.4%   0.72        1.0  ← #1 driver
Customer Service     24.1%    25.3%      26.1%   0.68        2.0  ← #2 driver
Delivery             19.8%    18.9%      22.3%   0.58        3.0
Brand Reputation     14.2%    15.1%      13.8%   0.51        4.0
Website Ease          9.4%     8.9%       9.4%   0.44        5.0
```

**Interpretation:**
- **Product Quality is the #1 driver** (32.5% of impact via Shapley)
- **Customer Service is #2** (24.1% of impact)
- Focus improvement efforts on these two areas
- **Method agreement is strong** = robust finding

### Key Diagnostics to Check

#### 1. Model R² (Model Summary sheet)

- **R² > 0.60:** Good model fit - drivers explain outcome well
- **R² 0.40-0.60:** Moderate fit - acceptable
- **R² < 0.40:** Weak fit - may be missing important drivers

#### 2. VIF (Variance Inflation Factor)

- **VIF < 5:** Low multicollinearity ✅
- **VIF 5-10:** Moderate multicollinearity (watch for instability)
- **VIF > 10:** High multicollinearity ⚠️ (consider removing/combining drivers)

**What is multicollinearity?** When drivers are highly correlated with each other, making it hard to separate their individual effects.

#### 3. Method Agreement

- **If all 4 methods rank drivers similarly:** Robust finding - trust the results
- **If methods disagree significantly:** Check for multicollinearity (VIF), consider reducing drivers

---

## Weighting Behavior

### How Weights Work in Key Driver Analysis

**If you specify a Weight variable:**

#### ✅ Correctly Weighted:
- **Correlations** - Uses proper weighted covariance formulas
- **Regression Model** - Uses weighted least squares (WLS)
- **Relative Weights** - Fully correct (MOST TRUSTWORTHY WITH WEIGHTS)

#### ⚠️ Partially Weighted:
- **Beta Weights** - Uses weighted coefficients but unweighted standard deviations
  - Still gives reasonable approximation
  - Rankings likely correct even if percentages slightly off

#### ❌ Weighting Bug:
- **Shapley Values** - Subset models are NOT weighted
  - Importance scores may be incorrect with weights
  - Don't trust Shapley method when using weights

### Practical Guidance When Using Weights

**✅ Trust these outputs:**
- Model Summary sheet (R², coefficients, VIF) - fully correct
- **Relative Weights importance scores** - fully correct ⭐
- Method Rankings based on Relative Weights - fully correct
- Correlations sheet - fully correct

**⚠️ Use with caution:**
- Beta Weights - approximately correct
- Average Rank - includes buggy Shapley

**❌ Don't trust:**
- Shapley Values importance percentages
- Shapley-based rankings

**RECOMMENDED:** Focus on **Relative Weights** column as your primary importance metric when using weights.

---

## Common Mistakes and Troubleshooting

### Mistake 1: Variable Name Mismatch

**Problem:** Error "Variable 'product_quality' not found in data"
**Solution:**
- Check VariableName spelling matches data exactly
- Check case (Product_Quality ≠ product_quality)
- Open data file and copy exact column name

### Mistake 2: No Outcome Variable

**Problem:** Error "Exactly 1 Outcome variable required"
**Solution:** Must have exactly one row with Type = Outcome in Variables sheet

### Mistake 3: Too Few Drivers

**Problem:** Warning about insufficient drivers
**Solution:**
- Minimum 2 drivers (3+ recommended)
- Need at least 3 drivers for meaningful analysis

### Mistake 4: Too Many Drivers

**Problem:** Analysis very slow or memory error
**Solution:**
- Maximum 15 drivers for Shapley computation
- Optimal 8-12 drivers
- Consider removing less relevant drivers

### Mistake 5: Non-Numeric Variables

**Problem:** Error "Variables must be numeric"
**Solution:**
- All outcome and drivers must be numeric scales
- Cannot use text/categorical variables directly
- Recode categorical to numeric if needed

### Mistake 6: Insufficient Sample Size

**Problem:** Warning about sample size
**Solution:**
- Need n ≥ max(30, 10 × drivers)
- 6 drivers → need 60+ respondents
- 10 drivers → need 100+ respondents
- Collect more data or reduce drivers

### Mistake 7: High Multicollinearity

**Problem:** VIF > 10 for some drivers
**Solution:**
- Drivers are too highly correlated
- Remove or combine correlated drivers
- Example: "Product quality" and "Product excellence" likely measure same thing

### Mistake 8: Low R²

**Problem:** R² < 0.40 (model explains little)
**Solution:**
- Missing important drivers - add more
- Wrong outcome variable - reconsider what you're measuring
- Drivers don't actually drive outcome

---

## Sample Size Guidelines

**Formula:** n ≥ max(30, 10 × number_of_drivers)

**Examples:**
- 3 drivers → minimum 30 respondents
- 5 drivers → minimum 50 respondents
- 6 drivers → minimum 60 respondents
- 8 drivers → minimum 80 respondents
- 10 drivers → minimum 100 respondents
- 12 drivers → minimum 120 respondents

**More is better:** These are minimums. For robust results, aim for 2-3× these values.

---

## Validation Rules

The module validates:

1. **Config File:**
   - Settings sheet has required settings
   - Variables sheet has required columns

2. **Variables:**
   - Exactly 1 Outcome variable
   - At least 2 Driver variables (3+ recommended)
   - At most 1 Weight variable
   - All VariableName exist in data file
   - All variables are numeric

3. **Data File:**
   - File exists and is readable
   - Contains all specified variables
   - Sufficient complete cases (n ≥ max(30, 10 × drivers))

4. **Multicollinearity:**
   - Warning if VIF > 5
   - Error if VIF > 20 (too high to proceed)

5. **Weights (if specified):**
   - Weight variable is numeric
   - All weights are positive (>0)
   - Warning if >10% NA weights

---

**End of KeyDriver Config Template Manual**
