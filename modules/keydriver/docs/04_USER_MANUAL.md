---
editor_options:
  markdown:
    wrap: 72
---

# Turas Key Driver Analysis -- User Manual

**Version:** 11.0
**Last Updated:** 4 March 2026
**Target Audience:** Market Researchers, Data Analysts, Survey Managers

------------------------------------------------------------------------

## Table of Contents

1.  [Introduction](#1-introduction)
2.  [Getting Started](#2-getting-started)
3.  [Configuration Deep Dive](#3-configuration-deep-dive)
4.  [Understanding Your Results](#4-understanding-your-results)
5.  [Advanced Features](#5-advanced-features)
6.  [HTML Report Guide](#6-html-report-guide)
7.  [Common Mistakes and Troubleshooting](#7-common-mistakes-and-troubleshooting)
8.  [Frequently Asked Questions](#8-frequently-asked-questions)
9.  [Appendix](#9-appendix)

------------------------------------------------------------------------

## 1. Introduction

### 1.1 What Is Key Driver Analysis?

Key Driver Analysis (KDA) answers the fundamental business question:
**"Which factors matter most?"**

Given an outcome metric (for example, overall satisfaction on a 0--10
scale) and a set of potential drivers (product quality, service,
price, delivery speed), the analysis determines:

1.  **How much** each driver contributes to the outcome (importance
    scores expressed as percentages)
2.  **The direction** of each relationship (positive or negative)
3.  **The relative ranking** of drivers from most to least important
4.  **Model diagnostics** that tell you whether the results are
    trustworthy (R-squared, VIF, model fit)

The technique is built on multiple regression, but goes far beyond a
simple regression table. Turas KeyDriver calculates importance using
**five complementary statistical methods** and presents them in a
single, unified output. Where all five methods agree, you can be
confident in the result. Where they disagree, the diagnostics help you
understand why.

### 1.2 When to Use Key Driver Analysis

**Key Driver Analysis is the right tool when:**

-   You have a **continuous numeric outcome** (a rating scale, a score,
    an amount) and you want to know what drives it
-   Your outcome is measured on at least a 5-point scale (ideally 7- or
    10-point)
-   You have **3 to 15 potential driver variables**, each also numeric
-   You want to **prioritise** which drivers to invest in or improve
-   You need robust, defensible importance rankings that go beyond
    simple correlations

**Common use cases:**

| Business Question                          | Outcome Variable          | Typical Drivers                                                |
|--------------------------------------------|---------------------------|----------------------------------------------------------------|
| What drives customer satisfaction?          | Overall Satisfaction (1-10)| Product quality, service, value, delivery, ease of use         |
| What drives brand perception?              | Brand Rating (0-100)      | Awareness, trust, innovation, value, social responsibility     |
| What drives employee engagement?           | Engagement Score (1-5)    | Management, compensation, growth, culture, work-life balance   |
| What drives NPS?                           | NPS Score (0-10)          | Product, support, onboarding, pricing, reliability             |
| What drives purchase intent?               | Intent to Purchase (1-7)  | Price, features, brand, reviews, availability                  |
| What drives product feature prioritisation?| Overall Product Rating    | Feature A rating, Feature B rating, Feature C rating, ...      |

### 1.3 When NOT to Use Key Driver Analysis

| Situation | Use Instead |
|-----------|-------------|
| Your outcome is **categorical** (Yes/No, Low/Medium/High, Brand A/B/C) | **Categorical Key Driver** (catdriver module) |
| You have **categorical predictors** (demographics, segments) | **Categorical Key Driver** (catdriver module) or use mixed-predictor mode (Section 5.4) |
| You are tracking metrics **over time** | **Tracker** module |
| You need **cross-tabulations** with significance tests | **Tabs** module |
| You are analysing **MaxDiff** or **Conjoint** experiments | Dedicated MaxDiff or Conjoint modules |
| You have only **2 variables** | A simple correlation or t-test is sufficient |

### 1.4 Key Driver Analysis vs Categorical Key Driver Analysis

This is the most common point of confusion. Here is the decision rule:

```
Is your OUTCOME variable continuous (numeric scale)?
|
+-- YES (e.g., satisfaction 1-10, NPS 0-10, spend amount)
|   --> Use Key Driver Analysis (this module)
|
+-- NO (e.g., Yes/No, Low/Medium/High, Brand A/B/C)
    --> Use Categorical Key Driver (catdriver module)
```

**What about the predictor variables?**

-   If all your drivers are **continuous** (numeric scales): Standard
    Key Driver is ideal
-   If you have a **mix** of continuous and categorical drivers (for
    example, satisfaction ratings plus gender and region): Key Driver
    supports mixed predictors (see Section 5.4)
-   If **all** your drivers are categorical: Consider catdriver instead,
    or use mixed-predictor mode with dummy encoding

### 1.5 Quick Start -- Three Steps to Your First Analysis

**Step 1: Prepare your data**

You need a CSV or Excel file with one row per respondent and columns
for your outcome variable, driver variables, and (optionally) a weight
variable. All values should be numeric.

```
resp_id | overall_satisfaction | product_quality | service | price_value | delivery
1       | 8                    | 7               | 9       | 6           | 8
2       | 9                    | 9               | 8       | 8           | 9
3       | 6                    | 5               | 7       | 7           | 6
```

**Step 2: Create a configuration file**

Use the template from `docs/templates/KeyDriver_Config_Template.xlsx`.
At minimum you need two sheets:

**Settings sheet** (two columns: Setting, Value):

| Setting       | Value                    |
|---------------|--------------------------|
| analysis_name | My Driver Analysis       |
| data_file     | survey_data.csv          |
| output_file   | results.xlsx             |

**Variables sheet** (three columns: VariableName, Type, Label):

| VariableName           | Type    | Label                |
|------------------------|---------|----------------------|
| overall_satisfaction   | Outcome | Overall Satisfaction |
| product_quality        | Driver  | Product Quality      |
| service                | Driver  | Customer Service     |
| price_value            | Driver  | Value for Money      |
| delivery               | Driver  | Delivery Speed       |

**Step 3: Run the analysis**

From the Turas GUI:

```r
source("launch_turas.R")
# Click "Key Driver" button
# Browse to your config file
# Click "Run Analysis"
```

Or from an R script:

```r
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

results <- run_keydriver_analysis(config_file = "my_config.xlsx")
```

Your results appear in `results.xlsx` with multiple sheets showing
importance rankings, model diagnostics, correlation matrices, and
charts.

------------------------------------------------------------------------

## 2. Getting Started

### 2.1 Prerequisites

#### R Version

R version 4.0 or higher is required. You can check your version by
running `R.version.string` in the R console.

#### Required Packages

The core analysis requires only `openxlsx` for reading configuration
and writing output:

```r
install.packages("openxlsx")
```

If you use `renv` (recommended), restore the project environment:

```r
renv::restore()
```

#### Optional Packages

| Package   | Purpose                               | When Needed                |
|-----------|---------------------------------------|----------------------------|
| haven     | Read SPSS (.sav) and Stata (.dta) files | If your data is in SPSS/Stata format |
| xgboost   | XGBoost model fitting for SHAP        | If you enable SHAP analysis |
| shapviz   | SHAP value visualisations             | If you enable SHAP analysis |
| ggplot2   | Chart generation for SHAP plots       | If you enable SHAP analysis |
| shiny     | GUI interface                         | If you run via the Turas GUI |
| shinyFiles| File browser in GUI                   | If you run via the Turas GUI |

Install optional packages as needed:

```r
# For SPSS/Stata data
install.packages("haven")

# For SHAP analysis
install.packages(c("xgboost", "shapviz", "ggplot2"))

# For GUI
install.packages(c("shiny", "shinyFiles"))
```

#### System Requirements

-   **Memory:** 4GB minimum; 8GB+ recommended for datasets with more
    than 10,000 respondents or when SHAP analysis is enabled
-   **Disk space:** Minimal -- output files are typically under 5MB
-   **Operating system:** Windows, macOS, or Linux

### 2.2 Setting Up Your Configuration File

The configuration file is an Excel workbook (.xlsx) that tells the
module what to analyse and how. You can copy the template from:

```
modules/keydriver/docs/templates/KeyDriver_Config_Template.xlsx
```

The workbook has 2 required sheets and up to 3 optional sheets:

| Sheet              | Purpose                                 | Required |
|--------------------|-----------------------------------------|----------|
| Settings           | Analysis parameters and feature toggles | **Yes**  |
| Variables          | Variable definitions (outcome, drivers, weight) | **Yes** |
| Segments           | Segment definitions for comparison      | No       |
| StatedImportance   | Self-reported importance ratings        | No       |
| SHAPParameters     | SHAP model tuning (advanced)            | No       |

Section 3 provides a comprehensive reference for every field in every
sheet.

### 2.3 Running Your First Analysis

#### Option 1: Via the Turas GUI

1.  Set your working directory to the Turas root and launch:

    ```r
    setwd("/path/to/Turas")
    source("launch_turas.R")
    ```

2.  Click the **"Key Driver"** button in the main Turas panel.

3.  Browse to your configuration file and select it.

4.  Click **"Run Analysis"**.

5.  Watch the console for progress output. A successful run looks like:

    ```
    ============================================================
      TURAS KEY DRIVER ANALYSIS v10.3
    ============================================================

    1. Loading configuration...
       [OK] Outcome variable: overall_satisfaction
       [OK] Driver variables: 5 variables

    2. Loading and validating data...
       [OK] Loaded 500 respondents
       [OK] Complete cases: 487

    3. Calculating correlations...
       [OK] Correlation matrix calculated

    4. Fitting regression model...
       [OK] Model R-squared = 0.623

    5. Calculating importance scores...
       [OK] Multiple importance methods calculated

    6. Generating output file...
       [OK] Results written to: results.xlsx

    ============================================================
      KEY DRIVER ANALYSIS  |  PASS  |  12.3s
    ============================================================

    TOP 5 DRIVERS:
    (by Shapley value)
      1. Product Quality (32.5%)
      2. Customer Service (24.1%)
      3. Value for Money (19.8%)
      4. Brand Reputation (14.2%)
      5. Delivery Speed (9.4%)
    ```

#### Option 2: Via R Script

For automated or repeatable workflows:

```r
# Source the module files
source("modules/keydriver/R/00_main.R")
source("modules/keydriver/R/01_config.R")
source("modules/keydriver/R/02_validation.R")
source("modules/keydriver/R/03_analysis.R")
source("modules/keydriver/R/04_output.R")

# Basic usage
results <- run_keydriver_analysis(
  config_file = "path/to/keydriver_config.xlsx"
)

# With explicit file overrides
results <- run_keydriver_analysis(
  config_file = "config/keydriver_config.xlsx",
  data_file   = "data/survey_responses.csv",
  output_file = "output/satisfaction_drivers.xlsx"
)
```

#### Option 3: Using the Alias

For convenience, `keydriver()` is an alias for
`run_keydriver_analysis()`:

```r
results <- keydriver("my_config.xlsx")
```

### 2.4 Understanding the Output Files

After a successful run, the module generates an **Excel workbook** with
multiple sheets. If HTML report generation is enabled, an HTML file is
also produced at the same path with an `.html` extension.

#### Excel Workbook Sheets

| Sheet               | What It Contains                                    | Who Uses It             |
|---------------------|-----------------------------------------------------|-------------------------|
| **Importance Summary** | Ranked drivers with all importance metrics        | Everyone                |
| **Method Rankings**    | Rank position from each method side by side       | Analysts                |
| **Model Summary**      | R-squared, F-statistic, VIF diagnostics           | Quality assurance       |
| **Correlations**       | Full correlation matrix of all variables          | Statistical review      |
| **Charts**             | Horizontal bar chart of importance values         | Presentations           |
| **Run Status**         | TRS run status, warnings, degraded outputs        | Troubleshooting         |
| **README**             | In-file methodology documentation                 | Reference               |

If SHAP analysis is enabled, additional sheets appear:

| Sheet                | What It Contains                                   |
|----------------------|----------------------------------------------------|
| **SHAP_Importance**  | Mean absolute SHAP values per driver               |
| **SHAP_Charts**      | Beeswarm, waterfall, and dependence plots          |
| **SHAP_Interactions**| Interaction values between driver pairs (if enabled)|

If quadrant analysis is enabled:

| Sheet               | What It Contains                                    |
|---------------------|-----------------------------------------------------|
| **Quadrant_Summary**| Drivers with quadrant assignments                   |
| **Action_Table**    | Prioritised recommendations by quadrant             |
| **Gap_Analysis**    | Importance minus performance gaps                   |

### 2.5 Accessing Results Programmatically

The `run_keydriver_analysis()` function returns a list that you can
work with directly in R:

```r
results <- run_keydriver_analysis("config.xlsx")

# View the importance table
print(results$importance)

# Access model fit statistics
cat("R-squared:", summary(results$model)$r.squared, "\n")
cat("Adjusted R-squared:", summary(results$model)$adj.r.squared, "\n")

# Get correlations
print(results$correlations)

# Check run status
cat("Status:", results$run_status, "\n")

# SHAP results (if enabled)
if (!is.null(results$shap)) {
  print(results$shap$importance)
}

# Quadrant results (if enabled)
if (!is.null(results$quadrant)) {
  print(results$quadrant$data)
}

# Guard summary (warnings and issues)
print(results$guard_summary)
```

------------------------------------------------------------------------

## 3. Configuration Deep Dive

This section documents every field in every sheet of the configuration
file. Refer to this when setting up or modifying your analysis.

### 3.1 Settings Sheet

The Settings sheet has two columns: `Setting` and `Value`. Each row
defines one parameter.

#### Core Settings (Required)

| Setting         | Required | Description                            | Example                        |
|-----------------|----------|----------------------------------------|--------------------------------|
| `analysis_name` | Yes      | Display name for reports and banners   | `"Q4 Satisfaction Drivers"`    |
| `data_file`     | Yes      | Path to respondent data file           | `"survey_data.csv"`            |
| `output_file`   | No       | Path for results Excel file            | `"results/drivers.xlsx"`       |

**File path notes:**

-   Paths can be **relative** (resolved from the config file's
    directory) or **absolute**
-   Relative paths are recommended for portability between machines
-   Supported data formats: CSV (.csv), Excel (.xlsx, .xls), SPSS
    (.sav, requires `haven`), Stata (.dta, requires `haven`)
-   If `output_file` is omitted, the module writes to
    `keydriver_results.xlsx` in the config file's directory

#### HTML Report Settings

| Setting            | Default     | Description                                    |
|--------------------|-------------|------------------------------------------------|
| `html_report`      | FALSE       | Generate an interactive HTML report            |
| `brand_colour`     | `"#323367"` | Primary colour for HTML report charts (hex)    |
| `accent_colour`    | `"#CC9900"` | Accent colour for HTML report highlights (hex) |
| `researcher_logo_path` | (none) | Path to researcher logo image for report header|

When `html_report = TRUE`, the module generates a self-contained HTML
file alongside the Excel output. The HTML report includes interactive
charts, pinned views for export, and a slide export feature. See
Section 6 for a full guide to the HTML report.

#### SHAP Settings

| Setting                | Default | Description                                       | Valid Range |
|------------------------|---------|---------------------------------------------------|-------------|
| `enable_shap`          | FALSE   | Enable SHAP (machine learning) analysis           | TRUE, FALSE |
| `shap_model`           | xgboost | ML model type for SHAP                            | xgboost     |
| `n_trees`              | 100     | Number of XGBoost trees                           | 50--1000    |
| `max_depth`            | 6       | Maximum tree depth                                | 3--10       |
| `learning_rate`        | 0.1     | XGBoost learning rate                             | 0.01--0.3   |
| `subsample`            | 0.8     | Row subsampling ratio                             | 0.5--1.0    |
| `colsample_bytree`     | 0.8     | Column subsampling ratio                          | 0.5--1.0    |
| `shap_sample_size`     | 1000    | Maximum observations used for SHAP calculation    | 100--10000  |
| `include_interactions` | FALSE   | Calculate SHAP interaction values                 | TRUE, FALSE |
| `interaction_top_n`    | 5       | Number of top interactions to report              | 1--20       |
| `importance_top_n`     | 15      | Number of drivers to include in SHAP output       | 1--30       |
| `shap_on_fail`         | refuse  | What to do if SHAP fails                          | refuse, continue_with_flag |

**SHAP tuning guidance:**

-   **n_trees**: Start with 100. Increase to 500+ for complex
    non-linear patterns. More trees = slower but more accurate.
-   **max_depth**: 6 is a good default. Reduce to 3--4 if overfitting
    (n < 200). Increase to 8--10 for very large samples.
-   **learning_rate**: Lower values (0.01--0.05) require more trees but
    produce smoother models. Higher values (0.1--0.3) are faster but
    may overfit.
-   **shap_sample_size**: SHAP calculation is O(n^2). For datasets
    over 5,000 rows, subsample to 1,000--2,000 for reasonable runtime.

#### Quadrant (IPA) Settings

| Setting              | Default | Description                                      | Valid Values                       |
|----------------------|---------|--------------------------------------------------|------------------------------------|
| `enable_quadrant`    | FALSE   | Enable Importance-Performance Analysis            | TRUE, FALSE                        |
| `importance_source`  | auto    | Which importance method to use for the IPA chart  | auto, shap, relative_weights, shapley, beta |
| `threshold_method`   | mean    | How to set the quadrant boundary lines            | mean, median, midpoint             |
| `normalize_axes`     | TRUE    | Normalize importance and performance to 0--100    | TRUE, FALSE                        |
| `shade_quadrants`    | TRUE    | Apply colour shading to quadrant regions          | TRUE, FALSE                        |
| `label_all_points`   | TRUE    | Label all driver points on the chart              | TRUE, FALSE                        |
| `label_top_n`        | 10      | If label_all_points=FALSE, how many to label      | 1--30                              |
| `show_diagonal`      | FALSE   | Show a 45-degree reference line                   | TRUE, FALSE                        |
| `quadrant_on_fail`   | refuse  | What to do if quadrant analysis fails             | refuse, continue_with_flag         |

**Importance source options:**

| Source            | Uses                                              |
|-------------------|---------------------------------------------------|
| `auto`            | SHAP if available, then Shapley, then Relative Weights |
| `shap`            | SHAP importance (requires enable_shap=TRUE)       |
| `relative_weights`| Johnson's relative weight decomposition           |
| `shapley`         | Shapley value decomposition of R-squared          |
| `beta`            | Standardised beta weight share                    |

**Threshold method options:**

| Method     | How Boundaries Are Set                               |
|------------|------------------------------------------------------|
| `mean`     | Cross-hairs at the mean importance and mean performance |
| `median`   | Cross-hairs at the median importance and median performance |
| `midpoint` | Cross-hairs at the midpoint of each axis range       |

#### Bootstrap Settings

| Setting                 | Default | Description                                      | Valid Range |
|-------------------------|---------|--------------------------------------------------|-------------|
| `enable_bootstrap`      | FALSE   | Calculate bootstrap confidence intervals         | TRUE, FALSE |
| `bootstrap_iterations`  | 1000    | Number of bootstrap resamples                    | 100--10000  |
| `bootstrap_ci_level`    | 0.95    | Confidence level for intervals                   | 0.80--0.99  |

Bootstrap confidence intervals provide uncertainty estimates around
each driver's importance score. This is especially valuable when:

-   Sample sizes are moderate (n = 100--300)
-   You need to determine whether two drivers are "statistically
    distinguishable" in importance
-   You are presenting to audiences that expect confidence intervals

**Runtime impact:** Bootstrap resampling repeats the entire importance
calculation `bootstrap_iterations` times. With 1,000 iterations and
10 drivers, expect 30--120 seconds of additional computation. Reduce
to 200--500 iterations for faster exploratory runs.

#### Feature Failure Policy Settings

| Setting            | Default | Description                                      |
|--------------------|---------|--------------------------------------------------|
| `shap_on_fail`     | refuse  | If SHAP analysis fails: `refuse` (halt) or `continue_with_flag` (partial output) |
| `quadrant_on_fail` | refuse  | If quadrant analysis fails: `refuse` or `continue_with_flag` |

When set to `continue_with_flag`, the analysis continues without the
failed feature. The run status becomes PARTIAL and the affected
outputs are listed in the Run Status sheet. This is useful in
production pipelines where you want results even if optional features
encounter issues.

### 3.2 Variables Sheet

The Variables sheet defines which columns in your data file play which
roles in the analysis. It has three required columns and two optional
columns.

#### Required Columns

| Column         | Description                          | Rules                         |
|----------------|--------------------------------------|-------------------------------|
| `VariableName` | Exact column name from data file     | Must match exactly (case-sensitive) |
| `Type`         | Role of this variable in the analysis| See variable types below      |
| `Label`        | Human-readable display name          | Used in reports and charts    |

#### Optional Columns

| Column        | Description                                   | When Needed                   |
|---------------|-----------------------------------------------|-------------------------------|
| `driver_type` | Declares the data type of the driver          | Required for mixed-predictor mode |
| `aggregation_method` | How categorical driver terms are aggregated | Only for categorical drivers in mixed mode |

#### Variable Types

| Type      | Count Allowed | Description                              |
|-----------|---------------|------------------------------------------|
| `Outcome` | Exactly 1     | The dependent variable you want to explain |
| `Driver`  | 2--15         | Independent variables (potential drivers) |
| `Weight`  | 0 or 1        | Survey case weight (optional)            |

**Rules:**

-   There must be **exactly one** Outcome variable
-   There must be **at least two** Driver variables (the analysis
    requires multiple predictors to calculate relative importance)
-   There can be **at most one** Weight variable
-   `VariableName` must match the column header in your data file
    exactly, including capitalisation and spacing
-   The Outcome and all Drivers must be **numeric** in the data file
    (unless you are using mixed-predictor mode -- see Section 5.4)

#### Driver Type Declarations (v10.3+)

Starting with version 10.3, you can declare each driver's data type
explicitly using the `driver_type` column:

| driver_type  | Description                        | Example                        |
|--------------|------------------------------------|--------------------------------|
| `continuous` | Standard numeric scale variable    | Satisfaction (1-10), NPS (0-10)|
| `categorical`| Categorical variable (will be dummy-encoded) | Region, Gender      |
| `ordinal`    | Ordered categorical variable       | Education level, income band   |

If omitted, the module infers the type from the data. Explicit
declaration is recommended when you have mixed continuous and
categorical predictors.

#### Example Variables Sheet

| VariableName          | Type    | Label                | driver_type |
|-----------------------|---------|----------------------|-------------|
| overall_satisfaction  | Outcome | Overall Satisfaction |             |
| product_quality       | Driver  | Product Quality      | continuous  |
| service_rating        | Driver  | Service Rating       | continuous  |
| price_perception      | Driver  | Price Perception     | continuous  |
| delivery_speed        | Driver  | Delivery Speed       | continuous  |
| region                | Driver  | Region               | categorical |
| survey_weight         | Weight  | Survey Weight        |             |

### 3.3 Segments Sheet (Optional)

The Segments sheet lets you run the same analysis for different
subgroups of your data and compare driver importance across groups.

#### Required Columns

| Column            | Description                                    |
|-------------------|------------------------------------------------|
| `segment_name`    | Display name for the segment                   |
| `segment_variable`| Column name in data that defines the groups    |
| `segment_values`  | Which value(s) to include in this segment      |

#### Example Segments Sheet

| segment_name | segment_variable | segment_values |
|-------------|------------------|----------------|
| Promoters   | nps_group        | Promoter       |
| Passives    | nps_group        | Passive        |
| Detractors  | nps_group        | Detractor      |

Or for comparing regions:

| segment_name | segment_variable | segment_values |
|-------------|------------------|----------------|
| North       | region           | North          |
| South       | region           | South          |
| East        | region           | East           |
| West        | region           | West           |

**Rules:**

-   The `segment_variable` must be a column in your data file
-   Each segment must have enough observations for a valid analysis
    (minimum n >= 10 x number of drivers)
-   The module runs the full analysis pipeline separately for each
    segment, then compares results

### 3.4 StatedImportance Sheet (Optional)

If you asked respondents to **directly rate** the importance of each
driver (self-reported importance), you can include those ratings here.
The module will compare stated importance against derived importance
to identify blind spots -- drivers that respondents say are
unimportant but that actually drive their behaviour.

#### Required Columns

| Column               | Description                                     |
|----------------------|-------------------------------------------------|
| `driver`             | Must match a VariableName with Type = Driver     |
| `stated_importance`  | Numeric importance rating (any scale)            |

#### Example StatedImportance Sheet

| driver          | stated_importance |
|-----------------|-------------------|
| product_quality | 8.5               |
| service_rating  | 7.2               |
| price_perception| 9.1               |
| delivery_speed  | 6.8               |

The module normalises both stated and derived importance to a common
scale for comparison. This is especially useful for the quadrant
analysis (IPA), where stated importance can serve as the "importance"
axis and derived importance or mean performance as the "performance"
axis.

### 3.5 Configuration File Best Practices

1.  **Keep the config file in the same directory as your data file.**
    This makes relative paths simple and portable.

2.  **Use descriptive analysis names.** These appear in console output,
    report headers, and output file names.

3.  **Start simple, then enable features.** Begin with just the
    Settings and Variables sheets. Once you have a working baseline,
    add SHAP, quadrant, bootstrap, and segments one at a time.

4.  **Use the template.** Copy
    `docs/templates/KeyDriver_Config_Template.xlsx` rather than
    building from scratch.

5.  **Double-check VariableNames.** The single most common error is a
    mismatch between the column name in the data file and the
    VariableName in the config. Check capitalisation, spacing, and
    special characters.

------------------------------------------------------------------------

## 4. Understanding Your Results

This is the most important section of this manual. Generating results
is easy; interpreting them correctly requires understanding what each
method measures and when to trust it.

### 4.1 The Five Importance Methods

Turas KeyDriver calculates driver importance using five complementary
statistical methods. No single method is perfect for all situations,
which is why using multiple methods and looking for **consensus** is
the recommended approach.

#### Method 1: Correlation Importance

**What it measures:** The bivariate (zero-order) Pearson correlation
between each driver and the outcome variable. This is the simplest
measure: how strongly does each driver co-vary with the outcome,
ignoring all other drivers?

**How to interpret:**

| Correlation (|r|) | Strength       |
|-------------------|----------------|
| 0.00--0.10        | Negligible     |
| 0.10--0.30        | Weak           |
| 0.30--0.50        | Moderate       |
| 0.50--0.70        | Strong         |
| 0.70+             | Very strong    |

**When it is useful:**

-   As a simple baseline for comparison
-   When drivers are truly independent (low inter-correlations)
-   For explaining results to non-technical audiences

**Limitations:**

-   **Does not account for shared variance.** If "product quality" and
    "brand trust" are correlated with each other and both correlate
    with satisfaction, simple correlation gives credit to both for the
    same variance. This is double-counting.
-   **Inflates importance of correlated drivers.** In the presence of
    multicollinearity, correlation systematically overstates the
    importance of drivers that are correlated with other drivers.
-   **Direction only, not unique contribution.** A driver with r = 0.70
    may actually contribute very little unique variance if other
    drivers already explain most of the outcome.

**Bottom line:** Useful as a starting point, but should never be the
sole basis for prioritisation decisions when drivers are correlated.

#### Method 2: Beta Weight Importance

**What it measures:** The absolute value of the standardised regression
coefficient (beta) for each driver, expressed as a share of the total.
In a standard multiple regression, the beta coefficient represents the
expected change in the outcome (in standard deviations) for a
one-standard-deviation increase in the driver, holding all other
drivers constant.

**How to interpret:**

-   A beta weight of 30% means this driver accounts for 30% of the
    total absolute standardised effect
-   The signed beta coefficient (also provided) shows the direction:
    positive means "more of this driver = higher outcome"
-   Beta weights sum to 100%

**When it is useful:**

-   When multicollinearity is low (VIF < 5 for all drivers)
-   When you want a traditional, widely understood metric
-   When stakeholders are familiar with regression output

**Limitations:**

-   **Highly sensitive to multicollinearity.** When drivers are
    correlated, beta weights can be misleading or even have the wrong
    sign. This is because the regression "distributes" shared variance
    arbitrarily between correlated predictors.
-   **Can produce negative betas for positively correlated drivers.**
    This is a red flag for multicollinearity, not a genuine "negative
    effect".
-   **Suppression effects.** In the presence of correlated predictors,
    one driver may "suppress" another, making it appear more or less
    important than it truly is.

**Bottom line:** Good when drivers are independent; unreliable when
they are correlated. Always check VIF before trusting beta weights.

#### Method 3: Relative Weight Importance (Johnson's Method)

**What it measures:** Each driver's proportional contribution to the
total model R-squared, calculated using an orthogonal transformation
that removes the effects of inter-predictor correlations. This method
was developed by Johnson (2000) and refined by Tonidandel and LeBreton
(2011).

**How it works (simplified):**

1.  The original correlated drivers are transformed into a set of
    uncorrelated (orthogonal) components
2.  The model R-squared is decomposed among these orthogonal components
3.  The contributions are then mapped back to the original drivers
    using the correlations between original and orthogonal variables

**How to interpret:**

-   Values sum to the model R-squared (or 100% when expressed as
    percentages of total importance)
-   All values are non-negative by construction
-   A relative weight of 25% means this driver accounts for 25% of the
    explained variance in the outcome

**When it is useful:**

-   When multicollinearity is present (it handles correlated drivers
    well)
-   When you want a non-negative decomposition of R-squared
-   As a robust alternative to beta weights

**Limitations:**

-   **Assumes linear relationships.** Like all regression-based
    methods, relative weights assume the driver-outcome relationship is
    linear. Non-linear effects are missed.
-   **Does not model interactions.** If two drivers have a synergistic
    effect, relative weights treat them independently.
-   **Can fail with near-singular correlation matrices.** If drivers
    are very highly correlated (|r| > 0.95), the orthogonal
    transformation may be numerically unstable.

**Bottom line:** One of the most robust methods for driver importance.
Recommended as a primary metric alongside Shapley values.

#### Method 4: Shapley Value Decomposition

**What it measures:** Each driver's average marginal contribution to
the model R-squared across all possible subsets of drivers. This is a
game-theoretic approach where each driver's "fair share" of R-squared
is calculated by considering every possible combination of other
drivers.

**How it works (simplified):**

1.  For k drivers, there are 2^k possible subsets
2.  For each driver, we calculate the increase in R-squared when that
    driver is added to every possible subset of other drivers
3.  The Shapley value is the weighted average of these marginal
    contributions

**How to interpret:**

-   Values sum to the model R-squared (or 100% when expressed as
    percentages)
-   All values are non-negative
-   A Shapley value of 32% means this driver contributes 32% of the
    model's explanatory power, fairly distributed

**When it is useful:**

-   When you want the most theoretically principled decomposition of
    R-squared
-   When you need a single "best" importance metric
-   When multicollinearity is present
-   For formal presentations and publications

**Limitations:**

-   **Computational cost scales exponentially.** With k drivers, 2^k
    models must be fitted. At 15 drivers, this is 32,768 models. The
    module enforces a maximum of 15 drivers for exact Shapley
    computation.
-   **Assumes linear, additive effects.** Like relative weights, it
    does not capture non-linear patterns or interactions.
-   **Minor weighting approximation.** When survey weights are used,
    the current implementation applies a weighted regression
    approximation that may differ slightly from a fully
    probability-weighted Shapley decomposition.

**Bottom line:** The most robust method for driver importance ranking.
Recommended as the primary metric for prioritisation decisions. If
Shapley and Relative Weights agree, you can be very confident in the
ranking.

#### Method 5: SHAP (TreeSHAP via XGBoost)

**What it measures:** Each driver's contribution to the outcome
prediction using a machine learning model (XGBoost gradient-boosted
trees) combined with the SHAP (SHapley Additive exPlanations)
framework. Unlike the other four methods, SHAP captures non-linear
relationships and interactions.

**How it works (simplified):**

1.  An XGBoost model is fitted to predict the outcome from the drivers
2.  TreeSHAP is used to efficiently decompose each individual
    prediction into driver-level contributions
3.  The mean absolute SHAP value for each driver becomes its importance
    score

**How to interpret:**

-   SHAP importance is reported as a percentage of total absolute SHAP
    values
-   The **beeswarm plot** shows the distribution of SHAP values for
    each driver, revealing direction, non-linearity, and outliers
-   The **waterfall plot** shows how drivers contribute to a specific
    individual's prediction
-   The **dependence plot** shows the relationship between a driver's
    value and its SHAP value, revealing non-linear patterns

**When it is useful:**

-   When you suspect non-linear relationships (diminishing returns,
    thresholds)
-   When you suspect driver interactions (two drivers together have a
    different effect than either alone)
-   With large samples (n > 200)
-   When you want individual-level explanations, not just averages

**Limitations:**

-   **Requires larger sample sizes.** Machine learning models need
    more data to avoid overfitting. Use with n > 200.
-   **Results depend on model tuning.** Different XGBoost
    hyperparameters may produce different importance rankings.
-   **Less interpretable to non-technical audiences.** SHAP is a
    powerful technique, but explaining "tree-based Shapley values" to
    a marketing director requires care.
-   **Not directly comparable to R-squared decomposition methods.** The
    linear methods decompose a linear R-squared; SHAP decomposes an
    ML prediction. They measure somewhat different things.

**Bottom line:** Use SHAP as a complement to the linear methods. If
SHAP agrees with Shapley and Relative Weights, the drivers truly are
what they appear to be. If SHAP disagrees, there may be non-linear
effects worth investigating.

### 4.2 Decision Tree: Which Method Should I Use?

```
Do you need a single "best" method for reporting?
|
+-- YES
|   |
|   Are your drivers correlated (any |r| > 0.50)?
|   |
|   +-- YES --> Use SHAPLEY VALUE as primary metric
|   |           (most robust to multicollinearity)
|   |
|   +-- NO  --> Use BETA WEIGHTS (simplest, most traditional)
|               or SHAPLEY VALUE (more principled)
|
+-- NO (want comprehensive comparison)
    |
    Do you suspect non-linear effects?
    |
    +-- YES --> Enable SHAP analysis alongside standard methods
    |           Compare all five methods for consensus
    |
    +-- NO  --> Report Shapley and Relative Weights as primary
                Show all methods for transparency
```

**Recommended priority order for most analyses:**

1.  **Shapley Values** -- most robust, theoretically principled
2.  **Relative Weights** -- excellent for correlated drivers, always
    non-negative
3.  **SHAP** -- adds non-linear and interaction detection (when enabled)
4.  **Beta Weights** -- good when VIF is low (< 5), widely understood
5.  **Correlations** -- baseline only, use for simple communication

### 4.3 Reading the Importance Summary Table

The main output table (Importance Summary sheet) contains these columns:

| Column           | Description                                      | How to Use                    |
|------------------|--------------------------------------------------|-------------------------------|
| Driver           | Variable name from your data                     | Identifies the driver         |
| Label            | Human-readable name from config                  | Use in reports                |
| Shapley_Value    | Shapley importance (%)                           | **Primary ranking metric**    |
| Relative_Weight  | Johnson's relative weight (%)                    | Second-best ranking metric    |
| Beta_Weight      | Standardised beta share (%)                      | Good when VIF < 5             |
| Beta_Coefficient | Signed standardised beta                         | Shows direction and magnitude |
| Correlation      | Pearson r with outcome                           | Baseline, bivariate only      |
| Shapley_Rank     | Rank by Shapley value                            | Quick rank comparison         |
| RelWeight_Rank   | Rank by relative weight                          | Quick rank comparison         |
| Beta_Rank        | Rank by beta weight                              | Quick rank comparison         |
| Corr_Rank        | Rank by correlation                              | Quick rank comparison         |
| Average_Rank     | Mean rank across all methods                     | Overall consensus indicator   |
| SHAP_Importance  | SHAP importance (%) -- only if SHAP enabled      | Non-linear importance         |
| SHAP_Rank        | Rank by SHAP -- only if SHAP enabled             | Non-linear rank               |

**How to read the table:**

1.  Sort by `Shapley_Value` (descending) for the recommended
    prioritisation
2.  Check `Average_Rank` for overall method consensus -- a driver
    ranked #1 by Average_Rank is consistently important across all
    methods
3.  Look at `Beta_Coefficient` for the direction of each relationship
    (positive or negative)
4.  If a driver has very different ranks across methods, investigate
    multicollinearity (see Section 4.6)

### 4.4 Method Agreement -- What It Means When Methods Agree or Disagree

**When all methods agree** (ranks within 1--2 positions of each other):
This is the ideal scenario. You can be confident in the importance
ranking and present it without qualification.

**When methods mostly agree** (ranks within 3 positions):
This is typical for most real-world analyses. Minor rank differences
are normal and do not invalidate the results. Focus on the Shapley
and Relative Weight rankings.

**When methods substantially disagree** (rank difference of 4+):
This is a signal that something interesting (or problematic) is
happening. Common causes:

| Disagreement Pattern                          | Likely Cause              | Action                              |
|-----------------------------------------------|---------------------------|-------------------------------------|
| Beta rank is much higher than Shapley/RelWeight | Suppression effect       | Trust Shapley over Beta             |
| Beta rank is much lower than Correlation rank  | Multicollinearity        | Check VIF; trust Shapley            |
| SHAP rank differs from all linear methods      | Non-linear relationship  | Examine SHAP dependence plots       |
| Correlation is high but all model-based ranks are low | Confounding        | Driver may be correlated with a stronger driver |
| All model-based ranks are similar but correlation differs | Correct behaviour | Model-based methods properly partition shared variance |

### 4.5 R-Squared and Model Fit

#### R-Squared

The R-squared value tells you what proportion of the variance in the
outcome is explained by the drivers in the model. It is the total
"pie" that gets divided among the drivers by the importance methods.

| R-Squared | Interpretation              | What It Means for Your Study                      |
|-----------|-----------------------------|---------------------------------------------------|
| > 0.70    | Excellent                   | The drivers explain most of the outcome variation  |
| 0.50--0.70| Good                        | Strong explanatory model, actionable results       |
| 0.30--0.50| Moderate                    | Drivers matter but unmeasured factors also play a role |
| 0.10--0.30| Weak                        | Important drivers may be missing from the model    |
| < 0.10   | Very weak                    | The model explains very little; reconsider your drivers |

**Important context:**

-   In survey research, R-squared values of 0.30--0.60 are typical.
    Human attitudes are inherently noisy, and an R-squared of 0.50
    is considered very good.
-   A low R-squared does NOT mean the model is wrong. It means there
    are important factors not captured in your analysis.
-   R-squared is a measure of the total model, not individual drivers.
    A model with R-squared = 0.40 can still identify the correct
    driver ranking.

#### Adjusted R-Squared

Adjusted R-squared penalises for the number of drivers. It is always
lower than R-squared and gives a more realistic estimate of explained
variance, especially when you have many drivers relative to your
sample size. Use it alongside R-squared for model assessment.

#### F-Statistic and P-Value

The F-statistic tests whether the model as a whole explains a
statistically significant amount of variance.

-   **p < 0.05:** The model is statistically significant -- the drivers
    collectively predict the outcome better than chance.
-   **p >= 0.05:** The model is not significant. Consider whether you
    have too few observations, too little variation, or the wrong
    drivers.

In practice, with reasonable sample sizes (n > 100), the F-test is
almost always significant. A non-significant F-test with a reasonable
sample is a serious warning that the drivers are not predicting the
outcome.

#### RMSE (Root Mean Square Error)

RMSE measures the average prediction error in the original scale of
the outcome variable. Lower is better, but the value only has meaning
relative to the scale of your outcome variable.

For example, if your outcome is satisfaction on a 1--10 scale:

| RMSE | Interpretation                                  |
|------|-------------------------------------------------|
| < 1.0 | Very accurate predictions                      |
| 1.0--1.5 | Good predictions                             |
| 1.5--2.0 | Moderate predictions                         |
| > 2.0 | Poor predictions                                |

### 4.6 VIF and Multicollinearity

#### What Is VIF?

VIF (Variance Inflation Factor) measures how much each driver's
regression coefficient is inflated due to correlations with other
drivers. It is calculated by regressing each driver on all other
drivers and measuring the resulting R-squared.

Formula: VIF = 1 / (1 - R-squared_i), where R-squared_i is the
proportion of driver i that is explained by all other drivers.

#### Interpreting VIF

| VIF       | Interpretation          | Action Required                      |
|-----------|-------------------------|--------------------------------------|
| < 2.5     | No concern              | No action needed                     |
| 2.5--5.0  | Moderate                | Monitor; beta weights may be somewhat unreliable |
| 5.0--10.0 | High                    | Beta weights are unreliable; trust Shapley/RelWeight instead |
| > 10.0    | Very high               | Consider removing or combining correlated drivers |

#### What to Do About High VIF

1.  **Identify the correlated pair.** Check the correlation matrix for
    driver pairs with |r| > 0.70.

2.  **Assess whether both drivers are needed.** If "brand trust" and
    "brand reputation" are correlated at r = 0.85, they are likely
    measuring the same underlying construct. Choose one or create a
    composite.

3.  **Trust the right methods.** Shapley values and Relative Weights
    are designed to handle multicollinearity. Beta weights are not.

4.  **Do not blindly remove high-VIF drivers.** A driver with VIF = 8
    but Shapley rank #1 is still the most important driver -- the
    high VIF simply means beta weights cannot reliably estimate its
    unique effect.

5.  **Report transparently.** If you present beta weights, always
    accompany them with VIF values so the audience can assess
    reliability.

### 4.7 Interpreting Importance Thresholds

Use these thresholds to translate importance percentages into
actionable categories:

| Shapley Value (%) | Interpretation    | Strategic Priority           |
|--------------------|-------------------|------------------------------|
| > 25%             | Dominant driver   | **Top priority** -- concentrate resources here |
| 15--25%           | Major driver      | **High priority** -- invest in improvement |
| 8--15%            | Moderate driver   | **Medium priority** -- worthwhile but secondary |
| 3--8%             | Minor driver      | **Low priority** -- limited impact on the outcome |
| < 3%              | Negligible driver | **Minimal priority** -- not worth focusing on |

**Important caveats:**

-   These are general guidelines. The appropriate thresholds depend on
    the number of drivers. With 5 drivers, 20% each would be "equal"
    importance. With 15 drivers, ~7% each would be "equal".
-   A driver with 8% importance may still be strategically important
    if it is easy and inexpensive to improve.
-   Consider the gap between drivers, not just absolute values. If the
    top driver has 35% and the second has 15%, the gap is more
    informative than the absolute numbers.

------------------------------------------------------------------------

## 5. Advanced Features

### 5.1 SHAP Analysis

SHAP (SHapley Additive exPlanations) adds a machine learning
perspective to the traditional linear methods. It captures non-linear
relationships and interactions that the linear methods miss.

#### Enabling SHAP

Add these settings to the Settings sheet:

| Setting      | Value |
|-------------|-------|
| enable_shap | TRUE  |
| n_trees     | 100   |
| max_depth   | 6     |

#### SHAP Output

**SHAP_Importance sheet:** Lists each driver's mean absolute SHAP
value and its importance percentage. Compare this to the traditional
Shapley values to see if non-linear effects change the ranking.

**SHAP charts (in the Charts sheet or HTML report):**

-   **Importance bar plot:** Horizontal bars showing mean |SHAP| per
    driver. Directly comparable to the traditional importance chart.

-   **Beeswarm plot:** The most information-dense SHAP visualisation.
    Each dot is one respondent. The x-axis shows the SHAP value
    (positive = increases the outcome, negative = decreases). The
    colour shows the driver's actual value (red = high, blue = low).
    Patterns reveal:

    -   **Linear effect:** Dots progress smoothly from blue/negative to
        red/positive
    -   **Non-linear effect:** Dots curve or cluster unexpectedly
    -   **Threshold effect:** A sharp change in SHAP values at a
        particular driver value
    -   **Interaction effects:** Wide spread of SHAP values at similar
        driver values (indicating that the effect depends on other
        drivers)

-   **Waterfall plot:** Shows how a single respondent's prediction
    breaks down into driver contributions. Useful for explaining
    individual cases.

-   **Dependence plot:** Shows the relationship between one driver's
    actual values and its SHAP values, coloured by another driver
    to reveal interactions.

#### When Methods Disagree: SHAP vs Linear Methods

If SHAP ranks a driver differently from Shapley/RelWeight:

-   **SHAP ranks it higher:** The driver likely has a non-linear
    relationship with the outcome. Examine the beeswarm and
    dependence plots.
-   **SHAP ranks it lower:** The linear methods may be picking up a
    spurious or confounded relationship. Or the XGBoost model may not
    have enough data to learn the pattern.
-   **As a general rule:** If your sample is large (n > 500) and SHAP
    and linear methods disagree, investigate the SHAP plots before
    dismissing either.

### 5.2 Quadrant Analysis (Importance-Performance Analysis)

Quadrant analysis (also called IPA -- Importance-Performance Analysis)
combines driver importance with driver performance to create an
actionable strategic map.

#### Enabling Quadrant Analysis

Add to the Settings sheet:

| Setting           | Value |
|-------------------|-------|
| enable_quadrant   | TRUE  |
| importance_source | auto  |
| threshold_method  | mean  |

#### Understanding the Quadrant Chart

```
                    HIGH IMPORTANCE
                         |
           Q1            |           Q2
    CONCENTRATE HERE     |    KEEP UP GOOD WORK
    (High importance,    |    (High importance,
     low performance)    |     high performance)
                         |
    ---------------------+---------------------  PERFORMANCE
                         |
           Q3            |           Q4
    LOW PRIORITY         |    POSSIBLE OVERKILL
    (Low importance,     |    (Low importance,
     low performance)    |     high performance)
                         |
                    LOW IMPORTANCE
```

#### Strategic Interpretation

| Quadrant                | Action                                              |
|-------------------------|-----------------------------------------------------|
| Q1 (Concentrate Here)   | **INVEST** -- These drivers matter most but are performing poorly. Major improvement opportunity. |
| Q2 (Keep Up Good Work)  | **MAINTAIN** -- These drivers matter and you are doing well. Protect current performance. |
| Q3 (Low Priority)       | **MONITOR** -- These drivers have limited impact. Do not over-invest. |
| Q4 (Possible Overkill)  | **REASSESS** -- You may be over-investing in drivers that do not strongly influence the outcome. |

#### Quadrant Output

The quadrant analysis produces three additional sheets in the Excel
output:

-   **Quadrant_Summary:** All drivers with their quadrant assignment,
    importance score, and performance score
-   **Action_Table:** Prioritised action recommendations organised by
    quadrant
-   **Gap_Analysis:** The gap between importance and performance for
    each driver. A positive gap means the driver is more important
    than its current performance suggests (underperforming).

### 5.3 Segment Comparison

Segment comparison runs the full analysis pipeline for each segment
of your data and compares driver importance across segments. This
reveals whether different customer groups are driven by different
factors.

#### Setting Up Segments

Add a **Segments** sheet to your config:

| segment_name | segment_variable | segment_values |
|-------------|------------------|----------------|
| Promoters   | nps_group        | Promoter       |
| Passives    | nps_group        | Passive        |
| Detractors  | nps_group        | Detractor      |

#### Segment Output

The module runs the analysis independently for each segment and
produces a comparison table with:

-   **Importance percentages per segment** (side by side)
-   **Rank per segment** (identifying where rankings differ)
-   **Driver classification:**
    -   **Universal** -- important across all segments (rank <= 3 in all)
    -   **Segment-Specific** -- important in some segments but not others
    -   **Mixed** -- inconsistent pattern
    -   **Low Priority** -- not important in any segment

#### Tips for Segment Comparison

1.  **Start with the overall (Total) analysis.** Always understand the
    aggregate picture before drilling into segments.
2.  **Watch for small segments.** Each segment needs enough
    observations for a stable analysis. The rule of thumb is
    n >= 10 x number of drivers per segment.
3.  **Lead with Universal drivers.** When presenting, start with
    drivers that are important everywhere (these are "table stakes"),
    then highlight Segment-Specific findings as targeting
    opportunities.
4.  **Use bootstrap for unequal groups.** If segments have very
    different sizes, bootstrap confidence intervals help you assess
    whether apparent differences are statistically meaningful.

### 5.4 Mixed Predictors (Continuous + Categorical)

Starting with version 10.3, the keydriver module handles datasets
where some drivers are continuous (numeric scales) and others are
categorical (text or factor variables).

#### How Mixed Predictors Work

1.  Categorical drivers are **dummy-encoded** (one-hot encoding) before
    fitting the regression model
2.  A **term mapping** is built to track which regression terms belong
    to which original driver
3.  Importance scores are **aggregated** from term-level to
    driver-level using partial R-squared or grouped permutation
    methods
4.  The output reports importance at the **driver level**, not the
    term level

#### Configuring Mixed Predictors

In the Variables sheet, use the `driver_type` column to declare each
driver's type:

| VariableName     | Type   | Label           | driver_type |
|------------------|--------|-----------------|-------------|
| satisfaction     | Outcome| Overall Satisfaction |        |
| quality_rating   | Driver | Product Quality | continuous  |
| service_rating   | Driver | Service Rating  | continuous  |
| region           | Driver | Region          | categorical |
| gender           | Driver | Gender          | categorical |

#### Limitations of Mixed-Predictor Mode

-   **Correlations** are only computed for numeric drivers. Categorical
    drivers are excluded from the correlation matrix. This means the
    Correlation importance method is only available for numeric
    drivers.
-   **Shapley value computation** uses partial R-squared aggregation
    for categorical drivers. This is an approximation that works well
    in practice but is not identical to computing Shapley values on
    the original (non-dummy) variables.
-   **Very high-cardinality categorical variables** (16+ categories)
    can create many dummy terms and destabilise the model. Consider
    collapsing categories before analysis.

### 5.5 Weighted Analysis

If your data includes survey weights (to adjust for sampling bias or
non-response), the module applies weights throughout the analysis
pipeline:

-   **Weighted correlations** (between all variables)
-   **Weighted regression** (WLS -- Weighted Least Squares)
-   **Weighted Shapley values** (based on weighted R-squared)
-   **Weighted relative weights** (based on weighted correlations)
-   **Weighted SHAP** (XGBoost supports instance weights natively)

#### Configuring Weights

In the Variables sheet, add a row with `Type = Weight`:

| VariableName  | Type   | Label         |
|---------------|--------|---------------|
| case_weight   | Weight | Survey Weight |

**Rules for weight variables:**

-   The weight column must be numeric and positive
-   Rows with zero or negative weights are excluded
-   Only one weight variable is supported

#### Weighted vs Unweighted: When to Use Each

| Situation                                  | Recommendation            |
|--------------------------------------------|---------------------------|
| Probability sample with design weights     | Use weighted analysis     |
| Post-stratification weights for quota sample| Use weighted analysis    |
| Unweighted convenience sample              | No weight needed          |
| Multiple weight variables available        | Choose the one that matches your target population |

**Best practice:** Run both weighted and unweighted analyses and
compare results. If driver rankings are substantially different,
investigate which population the weighted analysis represents and
report accordingly.

### 5.6 Bootstrap Confidence Intervals

Bootstrap confidence intervals quantify the uncertainty around each
driver's importance score. They answer the question: "How stable are
these importance rankings if we had drawn a different sample?"

#### Enabling Bootstrap

Add to the Settings sheet:

| Setting               | Value |
|-----------------------|-------|
| enable_bootstrap      | TRUE  |
| bootstrap_iterations  | 1000  |
| bootstrap_ci_level    | 0.95  |

#### What Gets Bootstrapped

Three importance methods are bootstrapped:

1.  **Correlation** -- Pearson r between driver and outcome
2.  **Beta Weight** -- Standardised regression coefficient share
3.  **Relative Weight** -- Johnson's relative weight decomposition

Shapley values are not bootstrapped by default (due to the exponential
computational cost of running 2^k models within each of 1,000
bootstrap iterations).

#### Bootstrap Output

The bootstrap returns a data frame with one row per driver-method
combination:

| Column         | Description                               |
|----------------|-------------------------------------------|
| Driver         | Driver variable name                      |
| Method         | Importance method (Correlation, Beta_Weight, Relative_Weight) |
| Point_Estimate | Mean of the bootstrap distribution        |
| CI_Lower       | Lower bound of the confidence interval    |
| CI_Upper       | Upper bound of the confidence interval    |
| SE             | Standard error (SD of bootstrap distribution) |

#### Interpreting Bootstrap Results

-   **Narrow CI (e.g., 28%--36%):** The importance estimate is stable.
    You can be confident this driver's importance is approximately 32%.
-   **Wide CI (e.g., 15%--45%):** The importance estimate is unstable.
    This happens with small samples, high multicollinearity, or
    drivers whose importance is "on the boundary".
-   **Overlapping CIs between drivers:** If the CIs for Driver A
    (25%--35%) and Driver B (22%--33%) overlap, you cannot say with
    confidence that Driver A is more important than Driver B.
-   **Non-overlapping CIs:** If Driver A (28%--36%) and Driver C
    (8%--15%) do not overlap, Driver A is clearly more important.

#### Practical Guidance

-   Start with 500 iterations for exploratory analysis, then increase
    to 1,000--2,000 for final reporting
-   Enable bootstrap when sample size is under 300 to assess stability
-   Use bootstrap when you need to make "Driver A is more important
    than Driver B" claims with statistical backing

### 5.7 Effect Size Interpretation

The module classifies the magnitude of each driver's effect using
established benchmarks from Cohen (1988) and subsequent refinements.

#### Effect Size Benchmarks

**For Cohen's f-squared (partial R-squared based):**

| f-squared    | Classification |
|--------------|----------------|
| < 0.02       | Negligible     |
| 0.02--0.15   | Small          |
| 0.15--0.35   | Medium         |
| > 0.35       | Large          |

**For standardised beta coefficients:**

| |Beta|        | Classification |
|---------------|----------------|
| < 0.05        | Negligible     |
| 0.05--0.10    | Small          |
| 0.10--0.30    | Medium         |
| > 0.30        | Large          |

**For correlations:**

| |r|           | Classification |
|---------------|----------------|
| < 0.10        | Negligible     |
| 0.10--0.30    | Small          |
| 0.30--0.50    | Medium         |
| > 0.50        | Large          |

These classifications help translate statistical results into practical
significance. A driver can be statistically significant (p < 0.05)
but have a negligible effect size, meaning it has no practical
importance.

### 5.8 Executive Summary

The module generates a structured, plain-English executive summary
from the results. This includes:

-   **Headline finding:** A single sentence summarising the key result
    (e.g., "Product Quality dominates driver importance at 32.5%")
-   **Key findings:** 3--6 bullet points covering top drivers, method
    agreement, notable patterns
-   **Method agreement assessment:** Whether the five methods agree on
    the ranking
-   **Model quality assessment:** Plain-English interpretation of
    R-squared and F-statistic
-   **Warnings:** Any data quality or methodological concerns
-   **Recommendations:** 2--3 action-oriented suggestions

The executive summary is written to the Run Status sheet in the Excel
output and (when enabled) to the HTML report.

Access it programmatically:

```r
results <- run_keydriver_analysis("config.xlsx")
summary <- generate_executive_summary(results)

cat(summary$headline, "\n")
for (finding in summary$key_findings) {
  cat("  - ", finding, "\n")
}
```

------------------------------------------------------------------------

## 6. HTML Report Guide

### 6.1 Enabling HTML Output

Add to the Settings sheet:

| Setting       | Value     |
|---------------|-----------|
| html_report   | TRUE      |
| brand_colour  | #323367   |
| accent_colour | #CC9900   |

The HTML report is generated alongside the Excel output. If your
output file is `results.xlsx`, the HTML report is written to
`results.html` in the same directory.

### 6.2 Navigating the Report

The HTML report is a self-contained, single-file document that opens
in any modern web browser. It includes all data, charts, and
interactive features without requiring an internet connection or
external dependencies.

#### Report Sections

| Section               | Content                                        |
|-----------------------|------------------------------------------------|
| **Executive Summary** | Auto-generated headline, findings, model quality|
| **Importance**        | Horizontal bar chart with all methods          |
| **Model Diagnostics** | R-squared, VIF, F-test in card format          |
| **Correlations**      | Correlation matrix heatmap                     |
| **SHAP Analysis**     | Beeswarm and importance plots (if enabled)     |
| **Quadrant Chart**    | IPA quadrant visualisation (if enabled)        |
| **Segment Comparison**| Side-by-side importance by segment (if configured)|

Each section has a **navigation anchor** accessible from the sidebar
or top menu. Click the section name to jump directly to it.

### 6.3 Pinned Views and Slide Export

The HTML report supports **pinned views**: you can pin any chart or
table to a collection area, then export all pinned items as a
slide-ready package.

#### How to Pin

-   Hover over any chart or table section
-   Click the pin icon that appears in the top-right corner
-   The item is added to the "Pinned Views" tab

#### How to Export

-   Navigate to the "Pinned Views" tab
-   Click "Export as Slides"
-   A clean, presentation-ready version is generated

This is useful for extracting specific findings for presentations
without having to take screenshots or recreate charts.

### 6.4 Sharing and Printing

**Sharing:** The HTML file is completely self-contained. Send it as an
email attachment or place it on a shared drive. Recipients need only
a web browser to view it.

**Printing:** Use the browser's print function (Ctrl+P / Cmd+P). The
report includes print-optimised CSS that removes navigation elements
and adjusts layout for paper.

**File size:** A typical HTML report is 200KB--2MB, depending on the
number of charts and the complexity of the analysis.

------------------------------------------------------------------------

## 7. Common Mistakes and Troubleshooting

### 7.1 Common Mistakes

#### Mistake 1: Too Many Drivers (>15)

**Problem:** You include 18+ drivers in the analysis.

**Why it matters:** Shapley value computation requires fitting 2^k
models (where k is the number of drivers). At 15 drivers, this is
32,768 models. At 18 drivers, it would be 262,144 models, which is
impractical.

**Fix:** Reduce to 12--15 drivers. Pre-screen using correlations to
identify redundant pairs. Combine related drivers into composites
(e.g., average "ease of ordering" and "ease of returns" into
"ease of doing business").

#### Mistake 2: High Multicollinearity

**Problem:** Two or more drivers are very highly correlated (|r| >
0.80), resulting in VIF > 10.

**Why it matters:** Beta weights become unreliable and may even have
the wrong sign. Importance scores for the correlated drivers are
unstable.

**Fix:**

1.  Check the correlation matrix for high-correlation pairs
2.  Remove one driver from each highly correlated pair, or
3.  Combine them into a composite score (average of the two)
4.  Trust Shapley and Relative Weights, which handle multicollinearity
    better than beta weights

#### Mistake 3: Small Sample Sizes

**Problem:** You run an analysis with fewer than 10 x k complete cases
(where k is the number of drivers).

**Why it matters:** Parameter estimates are unstable. Importance
rankings may change substantially with different samples. Confidence
intervals will be very wide.

**Minimum sample sizes:**

| Drivers  | Minimum n | Recommended n |
|----------|-----------|---------------|
| 3--5     | 50        | 100+          |
| 6--8     | 80        | 200+          |
| 9--12    | 120       | 300+          |
| 13--15   | 150       | 400+          |

For SHAP analysis, add 50% to the recommended sizes.

#### Mistake 4: Non-Numeric Outcome or Drivers

**Problem:** The outcome variable or a driver contains text values
instead of numbers.

**Why it matters:** The regression model requires numeric inputs. Text
values cannot be used directly.

**Fix:**

-   For the outcome: Ensure it is a numeric scale (1--5, 1--7, 0--10)
-   For drivers: Either use numeric scales or declare them as
    categorical in the Variables sheet (see Section 5.4 on mixed
    predictors)
-   If your outcome is categorical (Yes/No, Low/Medium/High), use the
    catdriver module instead

#### Mistake 5: Including Irrelevant Drivers

**Problem:** You include every available variable as a driver,
including respondent ID, date stamps, and open-ended responses.

**Why it matters:** Irrelevant variables add noise and consume degrees
of freedom, reducing the power to detect the effects of genuinely
important drivers.

**Fix:** Only include variables that:

-   Have a plausible theoretical connection to the outcome
-   Are actionable (you could improve them if they are important)
-   Are distinct (not redundant with other drivers)
-   Are measured on a reasonable scale (not binary 0/1 for continuous
    key driver analysis)

#### Mistake 6: Confusing Correlation with Causation

**Problem:** Reporting results as "improving product quality will
increase satisfaction by X%" rather than "product quality is the
strongest predictor of satisfaction."

**Why it matters:** Key driver analysis identifies **associations**,
not **causes**. A strong association between "product quality" and
"satisfaction" does not prove that improving product quality will
increase satisfaction -- there may be confounding variables or reverse
causality.

**Fix:** Use language like "associated with", "predicts", "is the
strongest driver of" rather than "causes", "leads to", "will
increase".

#### Mistake 7: Ignoring Data Preparation

**Problem:** Running the analysis on raw data without checking for
missing values, outliers, or scale inconsistencies.

**Why it matters:** Missing data reduces your effective sample size
(listwise deletion removes any row with any missing value). Outliers
can disproportionately influence regression results. Mixed scales
(some 1--5, some 1--10) distort relative importance.

**Fix:**

1.  Check for missing data patterns before running the analysis
2.  Consider imputation for missing values if missingness is > 10%
3.  Standardise scales if drivers are on different measurement ranges
4.  Check for outliers using summary statistics

### 7.2 TRS Error Reference

Every error produced by the module includes a code, message, and
fix instruction. Here is a comprehensive reference:

#### Configuration Errors

| Error Code                    | Message                              | How to Fix                                           |
|-------------------------------|--------------------------------------|------------------------------------------------------|
| `IO_CONFIG_NOT_FOUND`         | Configuration file does not exist    | Check the file path; ensure the file exists          |
| `CFG_SETTINGS_SHEET_MISSING`  | Settings sheet not found             | Add a "Settings" sheet with Setting and Value columns |
| `CFG_VARIABLES_SHEET_MISSING` | Variables sheet not found            | Add a "Variables" sheet with VariableName, Type, Label columns |
| `CFG_VARIABLES_COLUMNS_MISSING`| Variables sheet missing required columns | Add the listed missing columns                    |
| `CFG_DATA_FILE_MISSING`       | No data file specified               | Add `data_file` to Settings sheet or pass as parameter |
| `CFG_OUTCOME_MISSING`         | No outcome variable defined          | Set Type="Outcome" for one variable in Variables sheet |
| `CFG_DRIVERS_MISSING`         | No driver variables defined          | Set Type="Driver" for at least 2 variables           |
| `CFG_SEGMENTS_MISSING_COLS`   | Segments sheet missing required columns | Add segment_name, segment_variable, segment_values columns |
| `CFG_SEGMENTS_EMPTY`          | Segments sheet has no rows           | Add at least one segment definition                  |
| `CFG_SEGMENTS_READ_FAILED`    | Cannot read Segments sheet           | Fix the sheet format or remove it                    |
| `CFG_STATED_IMPORTANCE_MISSING_DRIVER` | StatedImportance missing driver column | Add a "driver" column |
| `CFG_STATED_IMPORTANCE_NO_NUMERIC` | StatedImportance has no numeric column | Add a numeric importance column |
| `CFG_INVALID_EFFECT_METHOD`   | Invalid effect size method           | Use cohen_f2, standardized_beta, or correlation      |
| `CFG_UNKNOWN_EFFECT_METHOD`   | Unknown effect size method           | Use cohen_f2, standardized_beta, or correlation      |

#### Data Errors

| Error Code                    | Message                              | How to Fix                                           |
|-------------------------------|--------------------------------------|------------------------------------------------------|
| `DATA_VARIABLE_NOT_FOUND`     | Variable not found in data           | Check spelling (case-sensitive) and whitespace        |
| `DATA_INSUFFICIENT_N`         | Insufficient complete cases          | Reduce drivers, collect more data, or impute missing  |
| `DATA_DRIVERS_ZERO_VARIANCE`  | Zero variance in one or more drivers | Remove the constant driver(s) from your analysis     |
| `DATA_OUTCOME_ZERO_VARIANCE`  | Outcome has zero variance            | Check the outcome variable; all values are identical  |
| `DATA_SEGMENT_RESULTS_EMPTY`  | No segment results provided          | Provide valid segment definitions                    |
| `DATA_SEGMENT_NAMES_MISSING`  | Segment names missing                | Ensure all segments have names                       |
| `DATA_INVALID_RESULTS`        | Invalid results object               | Pass the list returned by run_keydriver_analysis()    |
| `DATA_MISSING_IMPORTANCE`     | Missing importance data              | Ensure the analysis completed successfully            |

#### Model Errors

| Error Code                    | Message                              | How to Fix                                           |
|-------------------------------|--------------------------------------|------------------------------------------------------|
| `MODEL_ALIASED_COEFFICIENTS`  | Aliased/NA coefficients              | Remove one of the perfectly correlated drivers       |
| `MODEL_SINGULAR_MATRIX`       | Singular correlation matrix          | Remove or combine very highly correlated drivers (|r| > 0.95) |

#### Feature Errors

| Error Code                    | Message                              | How to Fix                                           |
|-------------------------------|--------------------------------------|------------------------------------------------------|
| `FEATURE_SHAP_FAILED`         | SHAP analysis failed                 | Fix the underlying error, set shap_on_fail=continue_with_flag, or disable SHAP |
| `FEATURE_QUADRANT_FAILED`     | Quadrant analysis failed             | Fix the underlying error, set quadrant_on_fail=continue_with_flag, or disable quadrant |

#### System Errors

| Error Code                    | Message                              | How to Fix                                           |
|-------------------------------|--------------------------------------|------------------------------------------------------|
| `IO_TURAS_ROOT_NOT_FOUND`     | Cannot locate Turas root directory   | Run from within the Turas project directory          |
| `IO_KD_HTML_SUBMODULE_MISSING`| HTML report submodule files missing  | Restore missing files in lib/html_report/            |

### 7.3 Troubleshooting Specific Scenarios

#### Scenario: "Insufficient complete cases (45). Need at least 60."

**Cause:** After listwise deletion (removing any row with any missing
value across all analysis variables), too few rows remain.

**Solutions (in order of preference):**

1.  **Reduce the number of drivers.** Each additional driver increases
    the chance that a row has a missing value somewhere. Focus on the
    most important 5--8 drivers.
2.  **Investigate which variable has the most missing data.** If one
    driver has 40% missing while others have 2%, removing that driver
    may recover many rows.
3.  **Impute missing values externally.** Use multiple imputation or
    mean imputation before feeding data to the keydriver module. The
    module does not perform imputation itself.
4.  **Collect more data** if feasible.

#### Scenario: "Drivers have aliased coefficients: brand_trust, brand_reputation"

**Cause:** Two drivers are perfectly or near-perfectly correlated.
When the regression model tries to estimate separate effects for
both, it cannot distinguish them.

**Solutions:**

1.  **Examine the correlation** between brand_trust and
    brand_reputation. If |r| > 0.95, they are measuring the same
    thing.
2.  **Remove one.** Choose the one that is less theoretically relevant
    or less actionable.
3.  **Combine them.** Create a composite: `brand_composite <- (brand_trust + brand_reputation) / 2`
4.  **Consider whether they are distinct constructs.** If they truly
    measure different things despite high correlation, consider a
    factor analysis first to extract orthogonal factors.

#### Scenario: "Too many drivers (>15)"

**Cause:** Shapley value computation is exponential (2^k). Beyond 15
drivers, the computation is impractical.

**Solutions:**

1.  **Pre-screen with correlations.** Run a quick correlation analysis
    and remove drivers with |r| < 0.10 with the outcome.
2.  **Combine related drivers.** Average drivers that measure similar
    constructs.
3.  **Use domain knowledge.** Select the 10--12 most theoretically
    relevant and actionable drivers.
4.  **Enable SHAP without Shapley.** SHAP analysis (XGBoost-based) has
    no practical limit on the number of drivers. You can run SHAP
    with 20+ drivers, but the standard methods will not include Shapley
    decomposition.

#### Scenario: "High VIF detected: brand_reputation (VIF=12.4)"

**Impact:** Beta weights for this driver (and drivers correlated with
it) are unreliable. They may overstate or understate importance, and
the sign may even be wrong.

**Solutions:**

1.  **Trust Shapley and Relative Weights** for this driver's importance
    ranking. These methods are designed to handle multicollinearity.
2.  **Consider removing the high-VIF driver** if it is redundant with
    another driver that has lower VIF.
3.  **Combine it** with the correlated driver into a composite.
4.  **Report it transparently.** State that beta weights should be
    interpreted with caution for this driver due to
    multicollinearity.

#### Scenario: "Model did not converge" or very low R-squared

**Cause:** The drivers do not explain meaningful variance in the
outcome. This could be due to:

-   The wrong drivers (they truly do not predict the outcome)
-   Non-linear relationships that the linear model cannot capture
-   Too much noise in the data
-   Scale issues (binary drivers with a continuous outcome)

**Solutions:**

1.  **Check your outcome variable.** Is it truly a measure of what you
    think it is? Does it have sufficient variance?
2.  **Check your drivers.** Are they genuinely expected to influence
    the outcome based on theory?
3.  **Enable SHAP.** It may detect non-linear patterns that the linear
    model misses.
4.  **Check for coding errors.** Ensure scales go in the right
    direction (higher = better, not mixed).
5.  **Consider whether important drivers are missing.** An R-squared
    of 0.10 means 90% of the variance is unexplained. What else might
    be driving the outcome?

#### Scenario: Methods disagree -- Shapley rank = 2, Beta rank = 8

**Cause:** Almost always multicollinearity. When drivers are
correlated, the regression "arbitrarily" distributes shared variance,
causing beta weights to differ from methods that properly decompose
shared variance.

**Solutions:**

1.  **Check VIF** for the affected driver. High VIF confirms
    multicollinearity.
2.  **Trust Shapley** over Beta for this driver's ranking.
3.  **Check the correlation matrix** for the specific pair(s) causing
    the issue.
4.  **Report with nuance.** If presenting to a technical audience,
    show all methods with a note about the discrepancy and its cause.

### 7.4 Errors Visible in the Console

Since Turas runs through a Shiny application, all errors are output
to the R console where the Shiny app is running. Look for boxed
error messages:

```
+--- TURAS ERROR -----------------------------------------------+
| Code: CFG_OUTCOME_MISSING
| Message: No Outcome Variable Defined
| Fix: Set Type='Outcome' for your dependent variable in the
|      Variables sheet
+---------------------------------------------------------------+
```

If you see an error but the Shiny UI does not display it, check the
console. The console always receives the full diagnostic output.

------------------------------------------------------------------------

## 8. Frequently Asked Questions

### Q: How many drivers should I include?

**A:** Aim for 5--12 drivers. This is the sweet spot where you have
enough variables for meaningful comparison but not so many that
computation becomes slow or results become unstable.

| Drivers | Assessment                                       |
|---------|--------------------------------------------------|
| 2--4    | Possible but limited -- little to differentiate  |
| 5--8    | Ideal for most analyses                          |
| 9--12   | Good with adequate sample size                   |
| 13--15  | Acceptable with large samples (n > 300)          |
| 16+     | Not recommended -- Shapley limit is 15           |

### Q: What sample size do I need?

**A:** As a rule of thumb: n >= max(30, 10 x number of drivers). But
"recommended" sample sizes are higher:

| Drivers | Minimum n | Recommended n | With SHAP |
|---------|-----------|---------------|-----------|
| 5       | 50        | 100+          | 150+      |
| 8       | 80        | 200+          | 300+      |
| 10      | 100       | 300+          | 450+      |
| 12      | 120       | 300+          | 450+      |
| 15      | 150       | 400+          | 600+      |

### Q: Should I use weights?

**A:** Yes, if your data has sampling weights or post-stratification
weights. Weights ensure the analysis represents the target population
rather than just your sample composition. If no weights are available,
run unweighted -- this is perfectly valid for quota or convenience
samples.

### Q: What scale should my outcome variable be?

**A:** The wider the scale, the better.

| Scale   | Quality for KDA | Notes                              |
|---------|-----------------|-------------------------------------|
| 0--10   | Excellent       | Good variance, fine-grained          |
| 1--10   | Excellent       | Most common in market research       |
| 1--7    | Good            | Adequate variance                    |
| 1--5    | Acceptable      | Some loss of discriminating power    |
| Binary  | Poor            | Use catdriver module instead          |

### Q: Can I use binary (0/1) drivers?

**A:** Yes, but with caveats. Binary drivers have limited variance,
which means their importance scores tend to be lower than continuous
drivers of the same true importance. If all your drivers are binary,
consider the catdriver module instead. If you have a mix, use
mixed-predictor mode (Section 5.4).

### Q: What if my drivers are on different scales?

**A:** The module handles this automatically. Standardised beta
coefficients, Shapley values, and relative weights are all
scale-invariant (they are based on standardised variables or
R-squared contributions). You do not need to pre-standardise your
data.

### Q: Can I compare importance across different studies?

**A:** Importance percentages are relative to the specific model and
data. A driver with 30% importance in Study A and 30% in Study B is
not necessarily equally important in absolute terms -- it depends on
the other drivers in each study and the total R-squared. Compare
**ranks** rather than percentages across studies.

### Q: What is the difference between Shapley values and SHAP?

**A:** Despite the similar names, they are different methods:

| Feature              | Shapley Values               | SHAP (TreeSHAP)               |
|----------------------|------------------------------|--------------------------------|
| **Model**            | Linear regression (OLS)      | XGBoost (gradient boosted trees)|
| **What it decomposes**| R-squared of a linear model | Predictions of an ML model     |
| **Linearity**        | Assumes linear relationships | Captures non-linear patterns   |
| **Interactions**     | Not modelled                 | Captured automatically         |
| **Computational cost**| Exponential (2^k models)    | Linear in sample size (fast)   |
| **Max drivers**      | 15 (practical limit)         | No practical limit             |
| **Sample size needed**| Standard                    | Larger (200+)                  |

Both are based on the same game-theoretic principle (Shapley 1953) of
"fair allocation", but they apply it to different models.

### Q: What if my R-squared is low (e.g., 0.20)?

**A:** A low R-squared does not invalidate the driver ranking. It
means that the measured drivers explain only 20% of the outcome
variance; the other 80% is driven by factors not in the model.

The driver ranking is still valid for the drivers you included. Think
of it as: "Among the factors I measured, here is their relative
importance." The recommendations are still actionable.

A very low R-squared (< 0.10) is a warning that you may be missing
important drivers or that the relationship is fundamentally
non-linear (try enabling SHAP).

### Q: How do I report results to non-technical stakeholders?

**A:** Focus on:

1.  **Top 3--5 drivers** by Shapley value with clear labels
2.  **The horizontal bar chart** from the output (copy/paste)
3.  **The quadrant chart** if enabled (visual action planning)
4.  **Simple language:** "Product quality is the single most important
    driver of satisfaction, accounting for about a third of the
    variation" rather than "Shapley decomposition assigns 32.5% of
    R-squared to the product quality predictor"

Avoid showing VIF, F-statistics, or method comparison tables to
non-technical audiences. These belong in the technical appendix.

### Q: Can I use Key Driver Analysis for causal inference?

**A:** No. Key driver analysis identifies **associations**, not
**causes**. To establish causality, you need experimental designs
(A/B tests, randomised controlled trials) or specialised causal
inference methods (instrumental variables, difference-in-differences).

However, KDA combined with domain expertise can generate strong
**hypotheses** about causal relationships that can then be tested
experimentally.

### Q: How often should I re-run the analysis?

**A:** For tracking studies, re-run with each new wave to see if
driver importance is stable over time. For one-off studies, a single
run is sufficient. If you are making strategic decisions based on the
results, consider re-running annually to confirm that the driver
landscape has not shifted.

------------------------------------------------------------------------

## 9. Appendix

### 9.1 Statistical Formulas

#### Pearson Correlation

$$r_{xy} = \frac{\sum_{i=1}^{n} (x_i - \bar{x})(y_i - \bar{y})}{\sqrt{\sum_{i=1}^{n}(x_i - \bar{x})^2 \cdot \sum_{i=1}^{n}(y_i - \bar{y})^2}}$$

#### Weighted Correlation

$$r_{xy}^w = \frac{\sum_{i=1}^{n} w_i (x_i - \bar{x}_w)(y_i - \bar{y}_w)}{\sqrt{\sum_{i=1}^{n} w_i(x_i - \bar{x}_w)^2 \cdot \sum_{i=1}^{n} w_i(y_i - \bar{y}_w)^2}}$$

where $\bar{x}_w = \sum w_i x_i / \sum w_i$.

#### Standardised Beta Coefficient

$$\beta_j^* = \beta_j \cdot \frac{s_{x_j}}{s_y}$$

where $\beta_j$ is the unstandardised regression coefficient, $s_{x_j}$
is the standard deviation of driver $j$, and $s_y$ is the standard
deviation of the outcome.

#### Beta Weight Importance (%)

$$\text{BetaWeight}_j = \frac{|\beta_j^*|}{\sum_{k=1}^{p} |\beta_k^*|} \times 100$$

#### Relative Weights (Johnson 2000)

Given predictor correlation matrix $R_{xx}$ with eigendecomposition
$R_{xx} = V \Lambda V^T$:

1.  Orthogonal transformation: $\Phi = V \Lambda^{1/2}$ (correlations
    between original and orthogonal predictors)
2.  Component-level R-squared: $r_{Z_j, Y}^2 = (\Lambda^{-1/2} V^T r_{XY})_j^2$
3.  Relative weight: $\text{RW}_j = \sum_{l=1}^{p} \Phi_{jl}^2 \cdot r_{Z_l,Y}^2$

Relative weights sum to the model $R^2$.

#### Shapley Value Decomposition

For a set of $p$ drivers $D = \{1, 2, \ldots, p\}$, the Shapley value
for driver $j$ is:

$$\phi_j = \sum_{S \subseteq D \setminus \{j\}} \frac{|S|! \cdot (p - |S| - 1)!}{p!} \cdot [R^2(S \cup \{j\}) - R^2(S)]$$

where $R^2(S)$ is the R-squared of the model using only the drivers in
subset $S$.

Shapley values sum to $R^2(D)$ (the full-model R-squared).

#### Variance Inflation Factor

$$\text{VIF}_j = \frac{1}{1 - R_j^2}$$

where $R_j^2$ is the R-squared from regressing driver $j$ on all other
drivers.

### 9.2 Interpretation Guidelines Summary

| Metric            | Negligible | Small     | Medium    | Large     |
|-------------------|------------|-----------|-----------|-----------|
| Cohen's f-squared | < 0.02     | 0.02--0.15| 0.15--0.35| > 0.35    |
| Standardised beta | < 0.05     | 0.05--0.10| 0.10--0.30| > 0.30    |
| Correlation |r|   | < 0.10     | 0.10--0.30| 0.30--0.50| > 0.50    |
| R-squared         | < 0.10     | 0.10--0.30| 0.30--0.50| > 0.50    |
| VIF               | < 2.5 (OK) | 2.5--5.0  | 5.0--10.0 | > 10.0    |

### 9.3 Sample Size Decision Table

| Drivers | Min n | Recommended n | SHAP n | Bootstrap n |
|---------|-------|---------------|--------|-------------|
| 3       | 30    | 100           | 150    | 100         |
| 5       | 50    | 100           | 150    | 100         |
| 8       | 80    | 200           | 300    | 200         |
| 10      | 100   | 300           | 450    | 300         |
| 12      | 120   | 300           | 450    | 300         |
| 15      | 150   | 400           | 600    | 400         |

### 9.4 Quick Reference: Settings Sheet

| Setting                | Required  | Default       | Valid Values                       |
|------------------------|-----------|---------------|------------------------------------|
| analysis_name          | Yes       | --            | Any text                           |
| data_file              | Yes       | --            | File path                          |
| output_file            | No        | keydriver_results.xlsx | File path                   |
| html_report            | No        | FALSE         | TRUE, FALSE                        |
| brand_colour           | No        | #323367       | Hex colour                         |
| accent_colour          | No        | #CC9900       | Hex colour                         |
| researcher_logo_path   | No        | (none)        | File path to image                 |
| enable_shap            | No        | FALSE         | TRUE, FALSE                        |
| shap_model             | No        | xgboost       | xgboost                            |
| n_trees                | No        | 100           | 50--1000                           |
| max_depth              | No        | 6             | 3--10                              |
| learning_rate          | No        | 0.1           | 0.01--0.3                          |
| subsample              | No        | 0.8           | 0.5--1.0                           |
| colsample_bytree       | No        | 0.8           | 0.5--1.0                           |
| shap_sample_size       | No        | 1000          | 100--10000                         |
| include_interactions   | No        | FALSE         | TRUE, FALSE                        |
| interaction_top_n      | No        | 5             | 1--20                              |
| importance_top_n       | No        | 15            | 1--30                              |
| shap_on_fail           | No        | refuse        | refuse, continue_with_flag         |
| enable_quadrant        | No        | FALSE         | TRUE, FALSE                        |
| importance_source      | No        | auto          | auto, shap, relative_weights, shapley, beta |
| threshold_method       | No        | mean          | mean, median, midpoint             |
| normalize_axes         | No        | TRUE          | TRUE, FALSE                        |
| shade_quadrants        | No        | TRUE          | TRUE, FALSE                        |
| label_all_points       | No        | TRUE          | TRUE, FALSE                        |
| label_top_n            | No        | 10            | 1--30                              |
| show_diagonal          | No        | FALSE         | TRUE, FALSE                        |
| quadrant_on_fail       | No        | refuse        | refuse, continue_with_flag         |
| enable_bootstrap       | No        | FALSE         | TRUE, FALSE                        |
| bootstrap_iterations   | No        | 1000          | 100--10000                         |
| bootstrap_ci_level     | No        | 0.95          | 0.80--0.99                         |

### 9.5 Quick Reference: Variables Sheet

| Column             | Required | Valid Values                                     |
|--------------------|----------|--------------------------------------------------|
| VariableName       | Yes      | Must match data column exactly (case-sensitive)  |
| Type               | Yes      | Outcome, Driver, Weight                          |
| Label              | Yes      | Any text                                         |
| driver_type        | No       | continuous, categorical, ordinal                 |
| aggregation_method | No       | partial_r2, grouped_permutation                  |

### 9.6 Quick Reference: Segments Sheet

| Column           | Required | Description                                |
|------------------|----------|--------------------------------------------|
| segment_name     | Yes      | Display name for the segment               |
| segment_variable | Yes      | Column name in data that defines groups    |
| segment_values   | Yes      | Value(s) to include in this segment        |

### 9.7 Quick Reference: StatedImportance Sheet

| Column              | Required | Description                              |
|---------------------|----------|------------------------------------------|
| driver              | Yes      | Must match a VariableName with Type=Driver|
| stated_importance   | Yes      | Numeric importance rating (any scale)     |

### 9.8 References

-   **Cohen, J.** (1988). *Statistical Power Analysis for the
    Behavioral Sciences* (2nd ed.). Lawrence Erlbaum Associates.
-   **Johnson, J. W.** (2000). A heuristic method for estimating the
    relative weight of predictor variables in multiple regression.
    *Multivariate Behavioral Research*, 35(1), 1--19.
-   **Lundberg, S. M., & Lee, S. I.** (2017). A unified approach to
    interpreting model predictions. *Advances in Neural Information
    Processing Systems*, 30.
-   **Shapley, L. S.** (1953). A value for n-person games. In H. W.
    Kuhn & A. W. Tucker (Eds.), *Contributions to the Theory of Games*
    (Vol. 2, pp. 307--317). Princeton University Press.
-   **Tonidandel, S., & LeBreton, J. M.** (2011). Relative importance
    analysis: A useful supplement to regression analysis. *Journal of
    Business and Psychology*, 26(1), 1--9.
-   **Martilla, J. A., & James, J. C.** (1977). Importance-Performance
    Analysis. *Journal of Marketing*, 41(1), 77--79.

### 9.9 Additional Resources

-   [02_KEYDRIVER_OVERVIEW.md](02_KEYDRIVER_OVERVIEW.md) -- High-level
    module overview and capabilities
-   [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) -- Statistical
    methods reference
-   [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) -- Developer
    documentation
-   [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) -- Template
    field reference
-   [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) -- Practical
    workflow examples

------------------------------------------------------------------------

**Part of the Turas Analytics Platform**
**The Research LampPost (Pty) Ltd**
