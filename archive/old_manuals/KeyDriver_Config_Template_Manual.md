# Key Driver Config Template - User Manual

**Template File:** `templates/KeyDriver_Config_Template.xlsx`
**Version:** 10.1
**Last Updated:** December 2025

---

## Overview

The Key Driver Config Template configures Key Driver Analysis in TURAS. This module determines which drivers (independent variables) have the greatest impact on an outcome variable (dependent variable) using multiple statistical methods.

**Key Purpose:** Identify which factors matter most in driving customer satisfaction, NPS, loyalty, or other key business metrics.

**Methods Used:** 5+ statistical methods rank drivers by importance:
1. **Shapley Values** (game theory) - Most robust, recommended
2. **Relative Weights** (Johnson 2000) - Handles multicollinearity well
3. **Beta Weights** (standardized coefficients) - Traditional, easy to interpret
4. **Correlations** (bivariate) - Simple baseline
5. **SHAP Analysis** (XGBoost/TreeSHAP) - NEW in v10.1

**NEW in v10.1:**
- **SHAP Analysis**: Machine learning-based importance using XGBoost and TreeSHAP
- **Quadrant Charts**: Importance-Performance Analysis (IPA) visualizations
- **Segment Comparison**: Compare driver importance across customer segments
- **Enhanced Visualizations**: Beeswarm plots, waterfall plots, dependence plots

---

## Template Structure

The template contains the following sheets:

### Required Sheets
1. **Instructions** - Comprehensive methodology guide
2. **Settings** - Analysis configuration
3. **Variables** - Definition of outcome, drivers, and optional weight variable

### Optional Sheets (NEW in v10.1)
4. **Segments** - Segment definitions for comparison analysis
5. **StatedImportance** - Self-reported importance for dual-importance analysis

---

## Sheet 1: Instructions

**Purpose:** Provides detailed documentation of methodology, workflow, and how weights work in key driver analysis.

**Action Required:** Review for understanding. This sheet is not read by the analysis code.

**Key Content:**
- Overview of 5 statistical methods
- Workflow: data preparation -> run analysis -> review output
- Example results interpretation
- Model diagnostics (R², VIF)
- Detailed explanation of how weights affect each method
- SHAP analysis explanation (NEW)
- Quadrant chart interpretation (NEW)

**Important Weighting Information:**
- **Correlations:** Properly weighted
- **Regression:** Properly weighted
- **Relative Weights:** Fully correct with weights (MOST TRUSTWORTHY)
- **Beta Weights:** Minor inconsistency (weighted coefficients, unweighted SDs)
- **Shapley Values:** Bug - subset models not weighted
- **SHAP (XGBoost):** Properly weighted (NEW)

**Recommendation:** When using weights, trust **Relative Weights** or **SHAP** methods as your primary importance metrics.

---

## Sheet 2: Settings

**Purpose:** Configure analysis parameters and file paths.

**Required Columns:** 2 columns only (`Setting`, `Value`)

### Core Settings

#### Setting: analysis_name

- **Purpose:** Display name for analysis in output
- **Required:** YES
- **Data Type:** Text
- **Example:** `Brand Health Drivers` or `Q1 2024 Satisfaction Analysis`

#### Setting: data_file

- **Purpose:** Path to respondent-level data file
- **Required:** YES
- **Data Type:** Text (file path)
- **Valid Values:** Path to .csv, .xlsx, .sav, or .dta file
- **Example:** `/Projects/Test/keydriver_test_data.csv`

#### Setting: output_file

- **Purpose:** Path and name for results Excel file
- **Required:** NO (has default)
- **Default:** `keydriver_results.xlsx` in config file directory
- **Example:** `/Projects/Test/keydriver_test_results.xlsx`

### SHAP Analysis Settings (NEW in v10.1)

#### Setting: enable_shap

- **Purpose:** Enable SHAP analysis using XGBoost
- **Required:** NO
- **Default:** FALSE
- **Valid Values:** TRUE, FALSE
- **Logic:** When enabled, fits XGBoost model and calculates SHAP values
- **Example:** `TRUE`

#### Setting: n_trees

- **Purpose:** Number of trees in XGBoost model
- **Required:** NO
- **Default:** 100
- **Valid Values:** 50-1000 (100 recommended for most cases)
- **Example:** `100`

#### Setting: max_depth

- **Purpose:** Maximum tree depth in XGBoost
- **Required:** NO
- **Default:** 6
- **Valid Values:** 3-10 (6 recommended)
- **Example:** `6`

#### Setting: learning_rate

- **Purpose:** XGBoost learning rate
- **Required:** NO
- **Default:** 0.1
- **Valid Values:** 0.01-0.3
- **Example:** `0.1`

#### Setting: shap_sample_size

- **Purpose:** Maximum observations for SHAP calculation
- **Required:** NO
- **Default:** 1000
- **Valid Values:** 500-5000
- **Logic:** Larger samples give more stable results but take longer
- **Example:** `1000`

#### Setting: include_interactions

- **Purpose:** Calculate SHAP interaction values
- **Required:** NO
- **Default:** FALSE
- **Valid Values:** TRUE, FALSE
- **Logic:** When TRUE, shows how drivers interact with each other
- **Example:** `FALSE`

### Quadrant Analysis Settings (NEW in v10.1)

#### Setting: enable_quadrant

- **Purpose:** Enable Importance-Performance Analysis quadrant charts
- **Required:** NO
- **Default:** FALSE
- **Valid Values:** TRUE, FALSE
- **Example:** `TRUE`

#### Setting: importance_source

- **Purpose:** Which importance method to use for quadrant chart
- **Required:** NO
- **Default:** auto
- **Valid Values:** auto, shap, relative_weights, regression, correlation
- **Logic:** "auto" uses SHAP if enabled, otherwise Shapley values
- **Example:** `auto`

#### Setting: threshold_method

- **Purpose:** How to determine quadrant boundary lines
- **Required:** NO
- **Default:** mean
- **Valid Values:** mean, median, midpoint, custom
- **Example:** `mean`

#### Setting: normalize_axes

- **Purpose:** Normalize axes to 0-100 scale
- **Required:** NO
- **Default:** TRUE
- **Valid Values:** TRUE, FALSE
- **Example:** `TRUE`

---

## Sheet 3: Variables

**Purpose:** Define the outcome variable, driver variables, and optional weight variable.

**Required Columns:** `VariableName`, `Type`, `Label`

### Column: VariableName

- **Purpose:** Column name in data file
- **Required:** YES
- **Data Type:** Text (must match data file column name EXACTLY)

### Column: Type

- **Purpose:** Variable role in the analysis
- **Required:** YES
- **Valid Values:** `Outcome`, `Driver`, `Weight`

### Column: Label

- **Purpose:** Human-readable label for reports
- **Required:** NO
- **Default:** Uses VariableName if blank

### Variable Type Requirements

| Type | Count | Description |
|------|-------|-------------|
| Outcome | Exactly 1 | Dependent variable (e.g., overall satisfaction) |
| Driver | 3-15 recommended | Independent variables (predictors) |
| Weight | 0 or 1 | Survey weight variable (optional) |

---

## Sheet 4: Segments (Optional - NEW in v10.1)

**Purpose:** Define customer segments for comparison analysis.

**Required Columns:** `segment_name`, `segment_variable`, `segment_values`

### Column: segment_name

- **Purpose:** Display name for the segment
- **Example:** `Promoters`, `High Value Customers`

### Column: segment_variable

- **Purpose:** Variable name in data file used for segmentation
- **Example:** `nps_group`, `customer_tier`

### Column: segment_values

- **Purpose:** Values to include in this segment (comma-separated if multiple)
- **Example:** `Promoter` or `Gold,Platinum`

### Example Segments Sheet

```
segment_name     | segment_variable | segment_values
-----------------+------------------+----------------
Promoters        | nps_group        | Promoter
Passives         | nps_group        | Passive
Detractors       | nps_group        | Detractor
High Value       | customer_tier    | Gold,Platinum
Standard         | customer_tier    | Standard,Bronze
```

---

## Sheet 5: StatedImportance (Optional - NEW in v10.1)

**Purpose:** Provide self-reported importance scores for dual-importance analysis.

**Required Columns:** `driver`, plus one numeric importance column

### Purpose of Dual-Importance Analysis

Compares:
- **Derived importance** (statistical - what actually drives outcomes)
- **Stated importance** (self-reported - what customers say matters)

This reveals:
- **Hidden Gems**: High derived, low stated (undervalued factors)
- **False Priorities**: High stated, low derived (overvalued factors)

### Example StatedImportance Sheet

```
driver           | stated_importance
-----------------+-------------------
product_quality  | 85
customer_service | 78
delivery_speed   | 65
price_value      | 92
website_ease     | 45
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

# Access traditional importance
print(results$importance)

# Access SHAP results (if enabled)
print(results$shap$importance)

# View quadrant chart (if enabled)
print(results$quadrant$plots$standard_ipa)
```

---

## Output Structure

The analysis produces Excel file with the following sheets:

### Standard Output (always included)

1. **Importance Summary** - All importance scores by method
2. **Method Rankings** - Rank comparison across methods
3. **Model Summary** - R², VIF diagnostics, coefficients
4. **Correlations** - Full correlation matrix
5. **Charts** - Bar chart of importance
6. **README** - Methodology documentation

### SHAP Output (when enable_shap = TRUE)

7. **SHAP_Importance** - SHAP-based importance scores
8. **SHAP_Model_Diagnostics** - XGBoost model performance
9. **SHAP_Charts** - Beeswarm and waterfall plots
10. **SHAP_Segment_Comparison** - If segments defined
11. **SHAP_Interactions** - If include_interactions = TRUE

### Quadrant Output (when enable_quadrant = TRUE)

12. **Quadrant_Summary** - All drivers with quadrant assignments
13. **Action_Table** - Prioritized recommendations
14. **Gap_Analysis** - Importance-performance gaps
15. **Quadrant_Charts** - IPA quadrant visualization
16. **Segment_Comparison** - If segments defined

---

## Understanding SHAP Analysis (NEW in v10.1)

### What is SHAP?

SHAP (SHapley Additive exPlanations) uses game theory to explain model predictions:
- Based on XGBoost machine learning model
- Captures non-linear relationships
- Handles interactions between drivers
- Provides individual-level explanations

### SHAP Visualizations

1. **Importance Bar Plot**: Mean |SHAP| for each driver
2. **Beeswarm Plot**: Distribution of SHAP values showing:
   - X-axis: Impact on prediction
   - Color: Feature value (high/low)
3. **Waterfall Plot**: Individual prediction breakdown
4. **Dependence Plot**: How driver value affects importance

### When to Use SHAP

- Large datasets (n > 200)
- Suspect non-linear relationships
- Want individual-level explanations
- Need to detect interactions

### SHAP vs Traditional Methods

| Aspect | Traditional | SHAP |
|--------|-------------|------|
| Model | Linear regression | XGBoost (non-linear) |
| Interactions | Not captured | Detected and visualized |
| Individual explanations | No | Yes (waterfall plots) |
| Speed | Fast | Slower (ML model fitting) |
| Sample size | Works with small n | Better with large n |

---

## Understanding Quadrant Charts (NEW in v10.1)

### The IPA Framework

Importance-Performance Analysis places drivers in 4 quadrants:

```
        HIGH IMPORTANCE
             |
   Q1        |        Q2
CONCENTRATE  |   KEEP UP
   HERE      |  GOOD WORK
             |
-------------+-------------  PERFORMANCE
             |
   Q3        |        Q4
   LOW       |   POSSIBLE
 PRIORITY    |   OVERKILL
             |
        LOW IMPORTANCE
```

### Quadrant Interpretation

| Quadrant | Meaning | Action |
|----------|---------|--------|
| Q1 (Red) | Important but underperforming | IMPROVE - Priority investment |
| Q2 (Green) | Important and performing well | MAINTAIN - Protect investment |
| Q3 (Gray) | Low importance, low performance | MONITOR - Low priority |
| Q4 (Yellow) | Low importance, high performance | REASSESS - Potential overkill |

### Gap Analysis

The gap score (Importance - Performance) helps prioritize:
- **Positive gap**: Driver underperforming relative to importance
- **Negative gap**: Driver overperforming relative to importance

Focus on drivers with largest positive gaps for maximum impact.

---

## Complete Configuration Example

### Settings Sheet

```
Setting              | Value
---------------------+----------------------------------
analysis_name        | Customer Satisfaction Drivers Q1
data_file            | survey_data.csv
output_file          | results/satisfaction_drivers.xlsx
enable_shap          | TRUE
enable_quadrant      | TRUE
n_trees              | 100
max_depth            | 6
threshold_method     | mean
```

### Variables Sheet

```
VariableName         | Type    | Label
---------------------+---------+------------------------
overall_satisfaction | Outcome | Overall Satisfaction
product_quality      | Driver  | Product Quality
customer_service     | Driver  | Customer Service
delivery_speed       | Driver  | Delivery Speed
price_value          | Driver  | Price/Value Ratio
website_ease         | Driver  | Website Ease of Use
brand_reputation     | Driver  | Brand Reputation
survey_weight        | Weight  | Survey Weight
```

### Segments Sheet (Optional)

```
segment_name | segment_variable | segment_values
-------------+------------------+---------------
Promoters    | nps_group        | Promoter
Detractors   | nps_group        | Detractor
```

---

## Interpreting Results

### Example Output

```
Driver               Shapley  RelWeight  Beta   SHAP   Correlation  Quadrant
────────────────────────────────────────────────────────────────────────────────
Product Quality      32.5%    31.8%      28.4%  35.2%  0.72        Q1
Customer Service     24.1%    25.3%      26.1%  22.8%  0.68        Q2
Delivery             19.8%    18.9%      22.3%  18.5%  0.58        Q2
Brand Reputation     14.2%    15.1%      13.8%  14.1%  0.51        Q3
Website Ease          9.4%     8.9%       9.4%   9.4%  0.44        Q4
```

**Interpretation:**
- **Product Quality is #1 driver** and in Q1 (needs improvement)
- **Customer Service is #2** and in Q2 (maintain current performance)
- **Website Ease** in Q4 suggests possible over-investment

---

## Troubleshooting

### SHAP Analysis Errors

#### "Package 'xgboost' required"
Install required packages:
```r
install.packages(c("xgboost", "shapviz", "ggplot2"))
```

#### "Small sample size warning"
SHAP works best with n > 200. Consider:
- Using traditional methods for smaller samples
- Collecting more data

#### "SHAP analysis failed"
Common causes:
- Missing values in data
- Non-numeric variables (must be numeric)
- Highly correlated drivers (try removing some)

### Quadrant Chart Issues

#### "Insufficient drivers for quadrant analysis"
Need at least 4 drivers with valid importance and performance scores.

#### "NA values in performance scores"
Performance calculated as mean of driver variables. Ensure:
- Driver variables exist in data
- Variables are numeric
- Not too many missing values

### Common Mistakes

1. **Variable Name Mismatch**: Check spelling and case match data file
2. **No Outcome Variable**: Must have exactly one Type = "Outcome"
3. **Too Many Drivers**: Maximum 15 for Shapley; SHAP handles more
4. **Non-Numeric Variables**: All outcome and drivers must be numeric
5. **Insufficient Sample Size**: Need n >= max(30, 10 x drivers)

---

## Sample Size Guidelines

| Drivers | Minimum n | Recommended n |
|---------|-----------|---------------|
| 3-5     | 50        | 100+          |
| 6-8     | 80        | 200+          |
| 9-12    | 120       | 300+          |
| 13-15   | 150       | 400+          |

For SHAP analysis, add 50% to recommended sample sizes.

---

## Best Practices

### 1. Choose the Right Method

- **Small sample (n < 100)**: Use Relative Weights
- **Large sample (n > 200)**: Enable SHAP
- **Actionable insights**: Enable Quadrant charts

### 2. Review All Methods

If methods disagree substantially:
- Check for multicollinearity (VIF)
- Consider removing highly correlated drivers
- Look for non-linear relationships (use SHAP)

### 3. Use Segment Analysis

Different customer groups may have different drivers:
- Compare Promoters vs Detractors
- Compare high-value vs standard customers
- Tailor strategies by segment

### 4. Validate with Business Knowledge

Statistical importance should align with business logic:
- Hidden gems reveal blind spots
- False priorities may need communication change

---

## References

- Shapley, L. S. (1953). A value for n-person games.
- Johnson, J. W. (2000). A heuristic method for estimating relative weights.
- Tonidandel, S., & LeBreton, J. M. (2011). Relative importance analysis.
- Lundberg, S. M., & Lee, S. I. (2017). A unified approach to interpreting model predictions.
- Martilla, J. A., & James, J. C. (1977). Importance-performance analysis.

---

**End of KeyDriver Config Template Manual**
