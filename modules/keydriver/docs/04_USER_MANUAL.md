---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Key Driver Analysis - User Manual

**Version:** 10.0 **Last Updated:** 22 December 2025 **Target
Audience:** Market Researchers, Data Analysts, Survey Managers

------------------------------------------------------------------------

## Table of Contents

1.  [Quick Start](#quick-start)
2.  [Prerequisites](#prerequisites)
3.  [Configuration Guide](#configuration-guide)
4.  [Data Requirements](#data-requirements)
5.  [Running the Analysis](#running-the-analysis)
6.  [Understanding Output](#understanding-output)
7.  [SHAP Analysis](#shap-analysis)
8.  [Quadrant Analysis](#quadrant-analysis)
9.  [Segment Comparison](#segment-comparison)
10. [Troubleshooting](#troubleshooting)
11. [Best Practices](#best-practices)

------------------------------------------------------------------------

## Quick Start {#quick-start}

### 5-Minute Setup

**Step 1: Prepare Data File**

CSV or Excel with one row per respondent:

```         
resp_id | overall_satisfaction | product_quality | service | price_value | delivery
1       | 8                    | 7               | 9       | 6           | 8
2       | 9                    | 9               | 8       | 8           | 9
3       | 6                    | 5               | 7       | 7           | 6
```

**Step 2: Create Config File**

Use template from `docs/templates/KeyDriver_Config_Template.xlsx`

**Settings sheet:**

```         
Setting        | Value
analysis_name  | My Driver Analysis
data_file      | survey_data.csv
output_file    | results.xlsx
```

**Variables sheet:**

```         
VariableName           | Type    | Label
overall_satisfaction   | Outcome | Overall Satisfaction
product_quality        | Driver  | Product Quality
service                | Driver  | Customer Service
price_value            | Driver  | Value for Money
delivery               | Driver  | Delivery Speed
```

**Step 3: Run Analysis**

``` r
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

results <- run_keydriver_analysis(config_file = "my_config.xlsx")
```

**Step 4: Review Output**

Open `results.xlsx` and review: - **Importance Summary**: Top drivers by
Shapley value - **Model Summary**: R² and VIF diagnostics - **Charts**:
Visual importance ranking

------------------------------------------------------------------------

## Prerequisites {#prerequisites}

### Required R Packages

``` r
install.packages(c("openxlsx"))
```

### Optional Packages

``` r
# For SPSS/Stata files
install.packages("haven")

# For SHAP analysis
install.packages(c("xgboost", "shapviz", "ggplot2"))

# For GUI
install.packages(c("shiny", "shinyFiles"))
```

### System Requirements

-   R version 4.0 or higher
-   Sufficient memory for large datasets (8GB+ recommended for n \>
    10,000)

------------------------------------------------------------------------

## Configuration Guide {#configuration-guide}

### Configuration File Structure

The config file has 2-4 sheets:

| Sheet            | Purpose                  | Required |
|------------------|--------------------------|----------|
| Settings         | Analysis parameters      | Yes      |
| Variables        | Variable definitions     | Yes      |
| Segments         | Segment definitions      | No       |
| StatedImportance | Self-reported importance | No       |

### Settings Sheet

**Core Settings:**

| Setting       | Required | Description  | Example                   |
|---------------|----------|--------------|---------------------------|
| analysis_name | Yes      | Display name | "Q4 Satisfaction Drivers" |
| data_file     | Yes      | Path to data | "survey_data.csv"         |
| output_file   | No       | Output path  | "results.xlsx"            |

**SHAP Settings:**

| Setting              | Default | Description                  |
|----------------------|---------|------------------------------|
| enable_shap          | FALSE   | Enable SHAP analysis         |
| n_trees              | 100     | XGBoost trees (50-1000)      |
| max_depth            | 6       | Tree depth (3-10)            |
| learning_rate        | 0.1     | Learning rate (0.01-0.3)     |
| shap_sample_size     | 1000    | Max observations for SHAP    |
| include_interactions | FALSE   | Calculate interaction values |

**Quadrant Settings:**

| Setting | Default | Description |
|---------------------|---------------------|------------------------------|
| enable_quadrant | FALSE | Enable quadrant charts |
| importance_source | auto | Method for importance (auto/shap/relative_weights) |
| threshold_method | mean | Quadrant boundaries (mean/median/midpoint) |
| normalize_axes | TRUE | Normalize to 0-100 scale |

### Variables Sheet

**Required Columns:**

| Column       | Description         | Valid Values            |
|--------------|---------------------|-------------------------|
| VariableName | Column name in data | Must match exactly      |
| Type         | Variable role       | Outcome, Driver, Weight |
| Label        | Display label       | Any text                |

**Variable Types:**

| Type    | Count     | Description              |
|---------|-----------|--------------------------|
| Outcome | Exactly 1 | Dependent variable       |
| Driver  | 3-15      | Independent variables    |
| Weight  | 0 or 1    | Survey weight (optional) |

------------------------------------------------------------------------

## Data Requirements {#data-requirements}

### File Formats

Supported: - CSV (.csv) - Excel (.xlsx, .xls) - SPSS (.sav) - requires
haven - Stata (.dta) - requires haven

### Data Structure

-   One row per respondent
-   All variables numeric
-   Higher values = "more" of the construct
-   No missing values in outcome or key drivers (listwise deletion
    applied)

### Sample Size Rules

**Minimum:** n ≥ max(30, 10 × k)

| Drivers | Minimum n | Recommended n |
|---------|-----------|---------------|
| 3-5     | 50        | 100+          |
| 6-8     | 80        | 200+          |
| 9-12    | 120       | 300+          |
| 13-15   | 150       | 400+          |

For SHAP analysis, add 50% to recommended sizes.

### Scale Recommendations

**Best:** 1-10 or 0-10 scales (good variance)

**Acceptable:** 1-5 or 1-7 scales

**Avoid:** - Binary (0/1) - low variance - Highly skewed distributions -
Mixed scales without standardization

------------------------------------------------------------------------

## Running the Analysis {#running-the-analysis}

### Option 1: Via GUI

``` r
source("launch_turas.R")
# Click "Key Driver" button
# Browse to config file
# Click "Run Analysis"
```

### Option 2: Via Script

**Basic usage:**

``` r
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

results <- run_keydriver_analysis(
  config_file = "config.xlsx"
)
```

**With explicit paths:**

``` r
results <- run_keydriver_analysis(
  config_file = "config/keydriver_config.xlsx",
  data_file = "data/survey.csv",
  output_file = "output/results.xlsx"
)
```

### Accessing Results Programmatically

``` r
# View top drivers
print(results$importance)

# Access model fit
cat("R-squared:", results$r_squared, "\n")

# Check VIF
print(results$vif)

# SHAP results (if enabled)
print(results$shap$importance)
```

------------------------------------------------------------------------

## Understanding Output {#understanding-output}

### Sheet 1: Importance Summary

Main results table with all importance metrics:

| Column          | Description                         |
|-----------------|-------------------------------------|
| Driver          | Variable name                       |
| Label           | Descriptive label                   |
| Shapley (%)     | Game-theoretic importance           |
| Rel. Weight (%) | Johnson method importance           |
| Beta Weight (%) | Standardized coefficient importance |
| Beta Coef       | Signed standardized coefficient     |
| Correlation (r) | Zero-order correlation              |
| Avg Rank        | Average rank across methods         |

**Interpretation:** - Sort by Shapley (%) for recommended
prioritization - Check Avg Rank for method consensus - Beta Coef and
Correlation show direction (positive/negative)

### Sheet 2: Method Rankings

Rank positions from each method:

| Column           | Description             |
|------------------|-------------------------|
| Shapley Rank     | Rank by Shapley value   |
| Rel. Weight Rank | Rank by relative weight |
| Beta Rank        | Rank by beta weight     |
| Corr Rank        | Rank by correlation     |
| Average Rank     | Mean rank               |

**Use for:** - Checking method consensus - Identifying drivers with
inconsistent rankings - Investigating multicollinearity effects

### Sheet 3: Model Summary

**Model Metrics:** \| Metric \| Good Value \| Description \|
\|--------\|------------\|-------------\| \| R-Squared \| \> 0.50 \|
Variance explained \| \| Adj R-Squared \| \> 0.45 \| Adjusted for
predictors \| \| F-Statistic \| Higher better \| Overall significance \|
\| P-Value \| \< 0.05 \| Model significant? \| \| RMSE \| Lower better
\| Prediction error \| \| N \| As planned \| Sample size \|

**VIF Diagnostics:** \| VIF \| Interpretation \|
\|-----\|----------------\| \| \< 5 \| OK - low multicollinearity \| \|
5-10 \| Moderate - monitor \| \| \> 10 \| High - remove or combine
drivers \|

### Sheet 4: Correlations

Full correlation matrix of all variables.

**Use for:** - Understanding driver relationships - Identifying highly
correlated pairs (\|r\| \> 0.80) - Diagnosing multicollinearity

### Sheet 5: Charts

Horizontal bar chart of Shapley impact values.

**Use for:** - Presentations - Quick visual prioritization - Copy/paste
to reports

### Sheet 6: README

In-file methodology documentation.

**Use for:** - Explaining methodology to stakeholders - Reference during
interpretation - Documentation transparency

------------------------------------------------------------------------

## SHAP Analysis {#shap-analysis}

### Enabling SHAP

Add to Settings sheet:

```         
enable_shap | TRUE
n_trees     | 100
max_depth   | 6
```

### SHAP Output Sheets

**SHAP_Importance:** - Mean \|SHAP\| for each driver - Compare to
traditional methods

**SHAP_Charts:** - Importance bar plot - Beeswarm plot (shows direction
and distribution) - Waterfall plot (individual explanations)

**SHAP_Interactions (if enabled):** - Interaction values between
drivers - Identifies synergies and redundancies

### Interpreting SHAP Results

**Beeswarm Plot:** - X-axis: SHAP value (positive = increases outcome) -
Color: Feature value (red = high, blue = low) - Pattern: Shows if
relationship is linear or non-linear

**When Methods Disagree:** - SHAP may differ from Shapley if
relationships are non-linear - SHAP captures interactions that linear
methods miss - Use SHAP for large samples; Shapley for small samples

------------------------------------------------------------------------

## Quadrant Analysis {#quadrant-analysis}

### Enabling Quadrant Charts

Add to Settings sheet:

```         
enable_quadrant    | TRUE
importance_source  | auto
threshold_method   | mean
```

### Quadrant Output Sheets

**Quadrant_Summary:** - All drivers with quadrant assignments -
Importance and performance scores

**Action_Table:** - Prioritized recommendations by quadrant - Focus on
Q1 (Concentrate Here) first

**Gap_Analysis:** - Importance - Performance gaps - Positive gap =
underperforming = priority

### Strategic Interpretation

| Quadrant               | Action                                     |
|------------------------|--------------------------------------------|
| Q1 (Concentrate Here)  | **IMPROVE** - Major investment priority    |
| Q2 (Keep Up Good Work) | **MAINTAIN** - Protect current performance |
| Q3 (Low Priority)      | **MONITOR** - Limited impact               |
| Q4 (Possible Overkill) | **REASSESS** - May be over-investing       |

------------------------------------------------------------------------

## Segment Comparison {#segment-comparison}

### Setting Up Segments

Add **Segments** sheet to config:

```         
segment_name | segment_variable | segment_values
Promoters    | nps_group        | Promoter
Passives     | nps_group        | Passive
Detractors   | nps_group        | Detractor
```

### Segment Output

Separate analysis for each segment: - Compare driver importance across
segments - Identify segment-specific priorities - Tailor strategies by
customer type

### Use Cases

-   Compare NPS groups (Promoters vs Detractors)
-   Compare customer tiers (High value vs Standard)
-   Compare regions or demographics

------------------------------------------------------------------------

## Troubleshooting {#troubleshooting}

### Error: "Insufficient complete cases"

**Message:** `Insufficient complete cases (45). Need at least 60.`

**Cause:** Not enough data after removing missing values.

**Solutions:** 1. Reduce number of drivers 2. Collect more data 3.
Impute missing values (external preprocessing)

### Error: "Aliased/NA coefficients"

**Message:**
`Drivers have aliased coefficients: brand_trust, brand_reputation`

**Cause:** Perfect multicollinearity - drivers are perfectly correlated.

**Solutions:** 1. Remove one of the correlated drivers 2. Combine into
composite score 3. Check if measuring same construct

### Error: "Too many drivers (\>15)"

**Message:** `Too many drivers (18) for exact Shapley.`

**Cause:** Shapley computation exponential - 2\^18 models impractical.

**Solutions:** 1. Reduce to 12-15 drivers 2. Pre-screen using
correlations 3. Combine related drivers

### Error: "Zero variance"

**Message:** `Variables have zero variance: delivery_speed`

**Cause:** Variable has only one unique value.

**Solutions:** 1. Check data quality 2. Check missing data patterns 3.
Remove constant variable

### High VIF Warning

**Message:** `High VIF detected: brand_reputation (VIF=12.4)`

**Impact:** Beta weights unreliable for this driver.

**Solutions:** 1. Trust Shapley values instead 2. Remove high-VIF driver
3. Combine with correlated driver

### Methods Disagree

**Symptom:** Shapley rank = 2, Beta rank = 8

**Cause:** Usually multicollinearity.

**Solutions:** 1. Check VIF for high-VIF drivers 2. Trust Shapley values
3. Remove or combine correlated drivers

------------------------------------------------------------------------

## Best Practices {#best-practices}

### 1. Sample Size

-   **Minimum:** n ≥ max(30, 10 × k)
-   **Recommended:** 100+ for stable estimates
-   **SHAP:** 200+ for reliable ML results

### 2. Driver Selection

**How many:** 5-12 optimal (15 maximum)

**Which drivers:** - Theory-driven (conceptual framework) - Actionable
(can you improve it?) - Distinct (not redundant)

**Avoid:** - Perfectly correlated drivers (\|r\| \> 0.95) - Drivers with
no theoretical link - Too many drivers (\> 15)

### 3. Multicollinearity

**Before analysis:** - Check correlation matrix for \|r\| \> 0.80 -
Consider combining highly correlated drivers

**After analysis:** - Check VIF in Model Summary - Remove drivers with
VIF \> 10 - Re-run and compare

### 4. Method Interpretation

**Priority order:** 1. Shapley values - most robust 2. Relative
Weights - handles collinearity 3. SHAP - for non-linear effects 4. Beta
weights - if VIF low 5. Correlations - baseline only

**When consensus low:** - Trust Shapley over Beta - Check VIF for
explanation - Consider SHAP for non-linear effects

### 5. Reporting Results

**For executives:** - Top 5 drivers with Shapley % - Quadrant chart for
action planning - Focus on "what to do" not methodology

**For technical audience:** - All methods for transparency - VIF and
model fit statistics - Discuss limitations

### 6. Weighted Analysis

**When using weights:** - Trust Relative Weights and SHAP - Shapley has
minor weighting issue - Beta has minor normalization issue

**Best practice:** - Compare weighted vs unweighted - Report if
substantial differences

------------------------------------------------------------------------

## Additional Resources

-   [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods
    reference
-   [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) - Developer
    documentation
-   [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Template
    field reference
-   [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) - Practical
    examples
