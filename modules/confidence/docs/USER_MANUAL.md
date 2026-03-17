---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Confidence Module - User Manual

**Version:** 2.1.0 **Last Updated:** March 2026 **Template:**
Confidence_Config_Template.xlsx (v10.2)

------------------------------------------------------------------------

## Table of Contents

1.  [Introduction](#introduction)
2.  [Prerequisites](#prerequisites)
3.  [Quick Start](#quick-start)
4.  [Configuration Template](#configuration-template)
5.  [Sheet 1: File_Paths](#sheet-1-file_paths)
6.  [Sheet 2: Study_Settings](#sheet-2-study_settings)
7.  [Sheet 3: Question_Analysis](#sheet-3-question_analysis)
8.  [Sheet 4: Population_Margins
    (Optional)](#sheet-4-population_margins-optional)
9.  [Running the Analysis](#running-the-analysis)
10. [Understanding Output](#understanding-output)
11. [Method Selection Guide](#method-selection-guide)
12. [Working with Weighted Data](#working-with-weighted-data)
13. [Net Promoter Score (NPS)](#net-promoter-score-nps)
14. [Representativeness Checking](#representativeness-checking)
15. [Common Mistakes](#common-mistakes)
16. [Troubleshooting](#troubleshooting)
17. [Examples](#examples)

------------------------------------------------------------------------

## Introduction {#introduction}

The Turas Confidence Module calculates statistical confidence intervals
for survey data. It supports:

-   **Proportions:** Percentage of respondents selecting specific values
-   **Means:** Average values for numeric questions
-   **NPS:** Net Promoter Score with confidence intervals

**Key Purpose:** Validate survey estimates with confidence intervals
using multiple statistical methods.

**Important:** This module uses the same data file as used in Tabs
analysis.

------------------------------------------------------------------------

## Prerequisites {#prerequisites}

### Software Requirements

-   R 4.0 or higher (R 4.2+ recommended)
-   RStudio (optional but recommended)

### Required R Packages

``` r
install.packages(c("readxl", "openxlsx", "data.table"))
```

### Verify Installation

``` r
library(readxl)
library(openxlsx)
library(data.table)
cat("All packages installed successfully\n")
```

------------------------------------------------------------------------

## Quick Start {#quick-start}

### Step 1: Copy the Template

Copy `Confidence_Config_Template.xlsx` to your project folder.

### Step 2: Configure File_Paths Sheet

| Parameter       | Value                                 |
|-----------------|---------------------------------------|
| Data_File       | path/to/your/survey_data.xlsx         |
| Output_File     | path/to/confidence_results.xlsx       |
| Weight_Variable | weight (or leave blank if unweighted) |

### Step 3: Configure Study_Settings Sheet

| Setting               | Value        |
|-----------------------|--------------|
| Calculate_Effective_N | Y            |
| Bootstrap_Iterations  | 5000         |
| Confidence_Level      | 0.95         |
| Decimal_Separator     | .            |
| Sampling_Method       | Online_Panel |

### Step 4: Configure Question_Analysis Sheet

| Question_ID | Statistic_Type | Categories | Run_MOE | Run_Wilson | Run_Bootstrap | Run_Credible |
|----|----|----|----|----|----|----|
| Q1 | proportion | Yes | Y | Y | N | N |
| Q2 | mean |  | Y | N | Y | N |

### Step 5: Run Analysis

``` r
setwd("/path/to/Turas/modules/confidence")
source("R/00_main.R")
run_confidence_analysis("/path/to/your_config.xlsx")
```

------------------------------------------------------------------------

## Configuration Template {#configuration-template}

The configuration file is an Excel workbook with the following sheets:

| Sheet              | Required | Purpose                              |
|--------------------|----------|--------------------------------------|
| Instructions       | No       | Documentation (not read by code)     |
| File_Paths         | Yes      | Data and output locations            |
| Study_Settings     | Yes      | Analysis parameters                  |
| Question_Analysis  | Yes      | Questions to analyze                 |
| Population_Margins | No       | Quota targets for representativeness |

------------------------------------------------------------------------

## Sheet 1: File_Paths {#sheet-1-file_paths}

**Purpose:** Specify data file, output location, and weight variable.

### Parameters

#### Data_File

-   **Purpose:** Path to the survey data file
-   **Required:** YES
-   **Valid Values:** Path to .xlsx, .csv, or .sav file
-   **Example:** `03_Data/project_Data.xlsx`
-   **Notes:**
    -   Must use the same data file as Tabs analysis
    -   Relative paths are relative to project root
    -   Absolute paths work on any system

#### Output_File

-   **Purpose:** Location for the results Excel file
-   **Required:** YES
-   **Valid Values:** Path ending in .xlsx
-   **Example:** `04_Analysis/confidence_results.xlsx`
-   **Notes:**
    -   Directory must exist
    -   File will be overwritten if exists

#### Weight_Variable

-   **Purpose:** Column name for survey weights
-   **Required:** NO
-   **Valid Values:**
    -   Column name from data file (case-sensitive)
    -   Leave blank for unweighted analysis
-   **Example:** `Weight` or `survey_weight`
-   **Notes:**
    -   Must be numeric
    -   Negative/zero values excluded from analysis

------------------------------------------------------------------------

## Sheet 2: Study_Settings {#sheet-2-study_settings}

**Purpose:** Global settings that apply to all questions.

### Parameters

#### Calculate_Effective_N

-   **Purpose:** Calculate effective sample size for weighted data
-   **Values:** `Y` or `N`
-   **Default:** `Y`
-   **When to Use:** Set to `Y` when using weights

#### Multiple_Comparison_Adjustment

-   **Purpose:** Adjust for multiple statistical comparisons
-   **Values:** `Y` or `N`
-   **Default:** `N`
-   **Status:** Future feature

#### Multiple_Comparison_Method

-   **Purpose:** Which correction method to use
-   **Values:** `None`, `Bonferroni`, `Holm`, `BH`
-   **Default:** `None`
-   **Status:** Future feature

#### Bootstrap_Iterations

-   **Purpose:** Number of bootstrap resampling iterations
-   **Values:** 1000 to 10000
-   **Default:** `5000`
-   **Notes:**
    -   5000 is good balance of accuracy and speed
    -   Increase to 10000 for publication-quality results
    -   Values \<1000 may give unstable intervals

#### Confidence_Level

-   **Purpose:** Confidence level for all intervals
-   **Values:** `0.90`, `0.95`, or `0.99`
-   **Default:** `0.95`
-   **Notes:**
    -   Enter as decimal (0.95), not percentage (95)
    -   0.95 = 95% confidence intervals

#### Decimal_Separator

-   **Purpose:** Number display format in output
-   **Values:** `.` or `,`
-   **Default:** `.`
-   **Notes:**
    -   `.` for US/UK format (8.2)
    -   `,` for European format (8,2)

#### Generate_HTML_Report

-   **Purpose:** Generate an interactive HTML report alongside the
    Excel output
-   **Values:** `Y` or `N`
-   **Default:** `N` (Excel only)
-   **Notes:**
    -   Set to `Y` to produce a self-contained HTML file with
        interactive navigation, visual charts, method comparisons,
        and plain-English explanations
    -   The HTML file is saved alongside the Excel output using the
        same filename but `.html` extension
    -   The report includes: summary dashboard, per-question detail
        panels with method comparison tables and charts, methodology
        documentation with assumptions and limitations, and an
        editable comments box for analyst notes

#### Brand_Colour

-   **Purpose:** Primary brand colour for HTML report styling
-   **Values:** Hex colour code (e.g., `#1e3a5f`)
-   **Default:** `#1e3a5f` (dark navy)
-   **Notes:**
    -   Used for the header gradient, active navigation, and
        accent borders
    -   Only applies when `Generate_HTML_Report = Y`

#### Accent_Colour

-   **Purpose:** Secondary accent colour for HTML report
-   **Values:** Hex colour code (e.g., `#2aa198`)
-   **Default:** `#2aa198` (teal)
-   **Notes:**
    -   Used for focus states and secondary highlights
    -   Only applies when `Generate_HTML_Report = Y`

#### Sampling_Method

-   **Purpose:** Describe how respondents were recruited, so the
    HTML report can tailor confidence interval interpretation notes
-   **Values:** One of the following:

| Value          | Description                                            |
|----------------|--------------------------------------------------------|
| `Random`       | Simple random (probability) sample                     |
| `Stratified`   | Stratified random sample (population divided into strata, random selection within each) |
| `Cluster`      | Cluster sample (groups selected, then all/some members surveyed) |
| `Quota`        | Quota sample (structured recruitment to match population targets) |
| `Online_Panel` | Online research panel (recruited, profiled, quality-managed members) |
| `Self_Selected`| Self-selected / opt-in sample (respondents chose to participate) |
| `Census`       | Full population (every member surveyed)                |
| `Not_Specified`| No sampling method declared (generic guidance shown)   |

-   **Default:** `Not_Specified`
-   **Required:** No (optional)
-   **Notes:**
    -   When set, the HTML report adds a tailored sampling note to
        every question's callout panel, explaining what the sampling
        design means for the reliability of the confidence intervals
    -   The language is statistically accurate but written for
        non-statisticians — it acknowledges real-world research
        realities without being dismissive of non-probability designs
    -   A badge showing the sampling method also appears in the
        HTML report header
    -   Has no effect on the Excel output

------------------------------------------------------------------------

## Sheet 3: Question_Analysis {#sheet-3-question_analysis}

**Purpose:** Define which questions to analyze and which methods to
apply.

### Required Columns

| Column         | Description                                   |
|----------------|-----------------------------------------------|
| Question_ID    | Column name from data file (case-sensitive)   |
| Statistic_Type | `proportion`, `mean`, or `nps`                |
| Categories     | For proportions: values to count as "success" |
| Run_MOE        | Y/N - Run Margin of Error method              |
| Run_Wilson     | Y/N - Run Wilson Score interval               |
| Run_Bootstrap  | Y/N - Run Bootstrap resampling                |
| Run_Credible   | Y/N - Run Bayesian credible interval          |

### Optional Columns

| Column          | Description                                           |
|-----------------|-------------------------------------------------------|
| Question_Label  | Human-readable label shown in HTML report             |
| Filter_Variable | Column name to filter on (for subset questions)       |
| Filter_Values   | Comma-separated values to include (for subset filter) |
| Prior_Mean      | Bayesian prior mean                                   |
| Prior_SD        | Bayesian prior SD (for means only)                    |
| Prior_N         | Bayesian prior sample size                            |
| Promoter_Codes  | NPS promoter codes (default: 9,10)                    |
| Detractor_Codes | NPS detractor codes (default: 0,1,2,3,4,5,6)         |
| Notes           | Documentation (not processed)                         |

### Column Details

#### Question_ID

-   Must exactly match column name in data file
-   Case-sensitive
-   Can include same question multiple times with different settings

**Examples:** `Q29`, `Q78`, `satisfaction_rating`

#### Statistic_Type

| Value        | Description                          | Requires          |
|--------------|--------------------------------------|-------------------|
| `proportion` | Calculate % for specified categories | Categories column |
| `mean`       | Calculate average value              | Numeric data      |
| `nps`        | Calculate Net Promoter Score         | 0-10 scale data   |

#### Categories

For proportions only. Specify which values to count as "success":

| Data Type            | Example                    |
|----------------------|----------------------------|
| Single text value    | `Yes`                      |
| Multiple text values | `Satisfied,Very Satisfied` |
| Single number        | `1`                        |
| Multiple numbers     | `9,10` or `4,5`            |

**Notes:** - Values must match data exactly (case-sensitive) - Separate
multiple values with commas - Leave blank for means and NPS

#### Run\_\* Flags

| Flag          | Method                                 | Works With            |
|---------------|----------------------------------------|-----------------------|
| Run_MOE       | Margin of Error (Normal approximation) | proportion, mean, nps |
| Run_Wilson    | Wilson Score Interval                  | proportion only       |
| Run_Bootstrap | Bootstrap resampling                   | proportion, mean, nps |
| Run_Credible  | Bayesian credible interval             | proportion, mean, nps |

**Important:** Run_Wilson only works for proportions. Setting it to Y
for means or NPS will cause an error.

#### Prior Parameters (Bayesian)

| Parameter  | For Proportions             | For Means                        |
|------------|-----------------------------|----------------------------------|
| Prior_Mean | 0 to 1 (e.g., 0.45 for 45%) | Any number on scale              |
| Prior_SD   | Not used                    | Required if Prior_Mean specified |
| Prior_N    | Effective prior sample size | Effective prior sample size      |

#### Subset Filtering (Filter_Variable / Filter_Values)

Use these columns when a question was only answered by a subset
of respondents (e.g., due to survey routing or skip logic).

| Parameter       | Description                                        |
|-----------------|----------------------------------------------------|
| Filter_Variable | Column name in the data to filter on               |
| Filter_Values   | Comma-separated values to include in the filter     |

**Example:** If Q15 was only asked to respondents who selected
"Yes" on Q14:

| Question_ID | Filter_Variable | Filter_Values | ...other columns... |
|-------------|-----------------|---------------|---------------------|
| Q15         | Q14             | Yes           | ...                 |

**Example:** If Q20 was only shown to respondents aged 18-34
(Age_Group codes 1 and 2):

| Question_ID | Filter_Variable | Filter_Values | ...other columns... |
|-------------|-----------------|---------------|---------------------|
| Q20         | Age_Group       | 1,2           | ...                 |

**Important notes:**
- The filter reduces the effective sample size, producing wider
  intervals. The HTML report flags subset questions with a
  warning callout showing the filtered base size.
- If the filter yields zero respondents, the question is skipped
  with a warning.
- Leave both columns blank for full-sample questions.

------------------------------------------------------------------------

## Sheet 4: Population_Margins (Optional) {#sheet-4-population_margins-optional}

**Purpose:** Compare sample composition to population targets.

### Required Columns

| Column         | Description                                   |
|----------------|-----------------------------------------------|
| Variable       | Variable name (or comma-separated for nested) |
| Category_Label | Human-readable label                          |
| Category_Code  | Code as appears in data                       |
| Target_Prop    | Target proportion (0-1, not percentage)       |
| Include        | Y/N to enable this target                     |

### Simple Quota Example

| Variable | Category_Label | Category_Code | Target_Prop | Include |
|----------|----------------|---------------|-------------|---------|
| Gender   | Male           | Male          | 0.48        | Y       |
| Gender   | Female         | Female        | 0.52        | Y       |
| Age      | 18-34          | 1             | 0.30        | Y       |
| Age      | 35-54          | 2             | 0.40        | Y       |
| Age      | 55+            | 3             | 0.30        | Y       |

### Nested Quota Example

| Variable   | Category_Label | Category_Code | Target_Prop | Include |
|------------|----------------|---------------|-------------|---------|
| Gender,Age | Male 18-34     | Male_1        | 0.14        | Y       |
| Gender,Age | Male 35-54     | Male_2        | 0.19        | Y       |
| Gender,Age | Male 55+       | Male_3        | 0.15        | Y       |
| Gender,Age | Female 18-34   | Female_1      | 0.16        | Y       |
| Gender,Age | Female 35-54   | Female_2      | 0.21        | Y       |
| Gender,Age | Female 55+     | Female_3      | 0.15        | Y       |

### Output Flags

| Flag        | Meaning                           |
|-------------|-----------------------------------|
| GREEN       | Difference \< 2 percentage points |
| AMBER       | Difference 2-5 percentage points  |
| RED         | Difference \> 5 percentage points |
| MISSING_VAR | Variable not found in data        |

------------------------------------------------------------------------

## Running the Analysis {#running-the-analysis}

### Option 1: From Turas GUI

``` r
setwd("/path/to/Turas")
source("launch_turas.R")
# Click "Launch Confidence" button
# Browse to config file
# Click "RUN ANALYSIS"
```

### Option 2: From R Console

``` r
setwd("/path/to/Turas/modules/confidence")
source("R/00_main.R")
run_confidence_analysis(
  config_path = "/path/to/config.xlsx",
  verbose = TRUE
)
```

### Expected Output

```
STEP 1/7: Loading configuration...
  ✓ Configuration loaded

STEP 2/7: Loading survey data...
  ✓ Data loaded: 1000 observations

STEP 3/7: Calculating study-level statistics...
  ✓ Actual n: 1000
  ✓ Effective n: 856
  ✓ DEFF: 1.17

STEP 4/7: Processing questions...
  ✓ Processed: 5 proportions, 3 means, 1 NPS

STEP 5/7: Quality checks...
  ✓ No warnings detected

STEP 6/7: Generating Excel output...
  ✓ Output written to: /path/to/results.xlsx

STEP 7/7: Generating HTML report...
  ✓ HTML report written to: /path/to/results.html (42.3 KB)

ANALYSIS COMPLETE
```

**Note:** Step 7 only appears when `Generate_HTML_Report = Y` in
Study_Settings.

------------------------------------------------------------------------

## Understanding Output {#understanding-output}

The output Excel workbook contains these sheets:

### Sheet 1: Summary

Overview of entire analysis: - Analysis date and version - Confidence
level used - Number of questions analyzed - Sample size information

### Sheet 2: Study_Level

Sample and weighting statistics: - Actual n (raw respondent count) -
Effective n (adjusted for weighting) - DEFF (design effect) - Weight
statistics (min, max, CV)

### Sheet 3: Proportions_Detail

Full results for proportion questions: - Point estimate - Confidence
intervals (by method) - Sample size - Method comparison

### Sheet 4: Means_Detail

Full results for mean questions: - Mean value - Standard deviation -
Confidence intervals (by method) - Sample size

### Sheet 5: NPS_Detail

Net Promoter Score results: - NPS value - % Promoters, % Passives, %
Detractors - Confidence intervals

### Sheet 6: Representativeness_Weights

If Population_Margins configured: - Weight concentration metrics -
Margin comparison with flags

### Sheet 7: Methodology

Documentation of statistical methods for reports.

### Sheet 8: Warnings

Data quality issues detected.

### Sheet 9: Inputs

Configuration snapshot for reproducibility.

------------------------------------------------------------------------

## Method Selection Guide {#method-selection-guide}

### For Proportions

| Scenario                            | Recommended Methods |
|-------------------------------------|---------------------|
| Standard analysis                   | Wilson only         |
| Thorough analysis                   | Wilson + Bootstrap  |
| Small sample (n \< 100)             | Wilson              |
| Extreme proportion (\<10% or \>90%) | Wilson              |
| Tracking study with prior           | Wilson + Bayesian   |

### For Means

| Scenario                  | Recommended Methods  |
|---------------------------|----------------------|
| Standard analysis         | MOE (t-distribution) |
| Thorough analysis         | MOE + Bootstrap      |
| Skewed data               | Bootstrap            |
| Tracking study with prior | MOE + Bayesian       |

### For NPS

| Scenario          | Recommended Methods |
|-------------------|---------------------|
| Standard analysis | MOE + Bootstrap     |
| Thorough analysis | All three methods   |

------------------------------------------------------------------------

## Working with Weighted Data {#working-with-weighted-data}

### Setup

1.  Ensure weight column exists in data file
2.  Set `Weight_Variable` in File_Paths sheet
3.  Set `Calculate_Effective_N = Y` in Study_Settings

### Understanding DEFF

| DEFF    | Meaning            | Action                      |
|---------|--------------------|-----------------------------|
| 1.0     | No efficiency loss | Great!                      |
| 1.0-1.2 | Minimal loss       | Acceptable                  |
| 1.2-1.5 | Moderate loss      | Normal for weighted surveys |
| 1.5-2.0 | Substantial loss   | Review if unexpected        |
| \>2.0   | Severe loss        | Check for extreme weights   |

### Effective Sample Size

```         
n_eff = n_actual / DEFF
```

Example: 1000 respondents with DEFF=1.25 → n_eff = 800

------------------------------------------------------------------------

## Net Promoter Score (NPS) {#net-promoter-score-nps}

### Configuration

```         
Question_ID | Statistic_Type | Promoter_Codes | Detractor_Codes | Run_MOE | Run_Bootstrap
NPS_Q       | nps            | 9,10           | 0,1,2,3,4,5,6   | Y       | Y
```

### Default Codes

-   **Promoters:** 9, 10
-   **Passives:** 7, 8
-   **Detractors:** 0, 1, 2, 3, 4, 5, 6

### Output

```         
NPS = %Promoters - %Detractors
Example: 45% - 18% = +27
```

------------------------------------------------------------------------

## Representativeness Checking {#representativeness-checking}

### Setup

1.  Add `Population_Margins` sheet to config
2.  List variables, categories, and target proportions
3.  Ensure Target_Prop values sum to 1.0 per variable

### Interpreting Results

| Flag  | Interpretation        | Action                   |
|-------|-----------------------|--------------------------|
| GREEN | Excellent match       | No action needed         |
| AMBER | Minor deviation       | Document in methodology  |
| RED   | Substantial deviation | Investigate and document |

### Weight Concentration

| Metric       | LOW   | MODERATE | HIGH  |
|--------------|-------|----------|-------|
| Top 5% Share | \<15% | 15-25%   | \>25% |

------------------------------------------------------------------------

## Common Mistakes {#common-mistakes}

### Mistake 1: Wrong Data File

**Problem:** Results don't match Tabs **Solution:** Use exact same data
file as Tabs

### Mistake 2: Question Not Found

**Problem:** Error "Question Q29 not found" **Solution:** Check
Question_ID spelling (case-sensitive)

### Mistake 3: Wilson for Non-Proportions

**Problem:** Error when Run_Wilson = Y for mean **Solution:** Wilson
only works for proportions

### Mistake 4: Missing Categories

**Problem:** Error "Categories required for proportion" **Solution:**
Specify Categories for all proportion questions

### Mistake 5: Wrong Decimal Format

**Problem:** Prior_Mean = 45 gives strange results **Solution:** Use
0.45 for proportions, not 45

### Mistake 6: Target_Prop as Percentage

**Problem:** Representativeness shows 4800% for Male **Solution:** Use
0.48, not 48, for Target_Prop

------------------------------------------------------------------------

## Troubleshooting {#troubleshooting}

### Issue: "File not found"

**Solutions:** 1. Use absolute paths 2. Check file actually exists 3.
Ensure no extra spaces in path

### Issue: "Column not found"

**Solutions:** 1. Check column names match exactly (case-sensitive) 2.
Look for trailing spaces 3. Verify column exists in data file

### Issue: Proportion shows 0.00

**Solutions:** 1. Check Categories match data values exactly 2. Verify
case sensitivity 3. Check for type mismatch (text vs number)

### Issue: CIs not showing

**Solutions:** 1. Verify at least one Run\_\* flag is Y 2. Check
Confidence_Level is numeric (0.95, not "95%") 3. Review console for
errors

### Issue: Analysis very slow

**Solutions:** 1. Reduce Bootstrap_Iterations for testing (use 1000) 2.
Use CSV instead of XLSX for data 3. Reduce number of questions

------------------------------------------------------------------------

## Examples {#examples}

### Example 1: Simple Proportion

Analyze whether respondents received a promotion.

**Config:**

```         
Question_ID: Q29
Statistic_Type: proportion
Categories: Yes
Run_Wilson: Y
Run_Bootstrap: Y
```

**Output:**

```         
Proportion: 0.67 (67%)
Wilson CI: [0.64, 0.70]
Bootstrap CI: [0.63, 0.70]
Sample Size: 980
```

### Example 2: Mean with Prior

Analyze satisfaction rating with prior from previous wave.

**Config:**

```         
Question_ID: Q78
Statistic_Type: mean
Run_MOE: Y
Run_Bootstrap: Y
Run_Credible: Y
Prior_Mean: 7.2
Prior_SD: 1.5
Prior_N: 500
```

**Output:**

```         
Mean: 7.4
t-dist CI: [7.2, 7.6]
Bootstrap CI: [7.2, 7.6]
Bayesian CI: [7.3, 7.5]  ← Shrunk toward prior
```

### Example 3: NPS Analysis

**Config:**

```         
Question_ID: NPS_Q
Statistic_Type: nps
Run_MOE: Y
Run_Bootstrap: Y
Promoter_Codes: 9,10
Detractor_Codes: 0,1,2,3,4,5,6
```

**Output:**

```         
NPS: +27
Normal CI: [+21, +33]
Bootstrap CI: [+22, +32]
% Promoters: 45%
% Detractors: 18%
% Passives: 37%
```

### Example 4: Full Weighted Analysis

**File_Paths:**

```         
Data_File: data/weighted_survey.csv
Output_File: output/confidence_results.xlsx
Weight_Variable: design_weight
```

**Study_Settings:**

```         
Calculate_Effective_N: Y
Bootstrap_Iterations: 5000
Confidence_Level: 0.95
```

**Output Summary:**

```         
Actual n: 1,500
Effective n: 1,275
DEFF: 1.18
Weight CV: 0.42
```

------------------------------------------------------------------------

## Validation Rules

The module validates:

### File Paths

-   Data_File exists and is readable
-   Output_File path is writable
-   Weight_Variable exists in data (if specified)

### Study Settings

-   Confidence_Level between 0.80 and 0.99
-   Bootstrap_Iterations between 1000 and 10000
-   Sampling_Method must be one of: Random, Stratified, Cluster,
    Quota, Online_Panel, Self_Selected, Census, Not_Specified
    (optional — defaults to Not_Specified)

### Question Analysis

-   All Question_ID exist in data
-   Statistic_Type is valid
-   Categories specified for proportions
-   At least one Run\_\* method = Y per question
-   Run_Wilson not used with mean/nps
-   Prior_SD specified if Prior_Mean specified for mean/nps

### Population Margins (if present)

-   All Variable names exist in data
-   Target_Prop values between 0 and 1
-   Target_Prop sums to 1.0 ± 0.01 per Variable

------------------------------------------------------------------------

## HTML Report {#html-report}

### Enabling the HTML Report

Add `Generate_HTML_Report = Y` to the **Study_Settings** sheet.
The HTML report is generated after the Excel output (Step 7) and
saved alongside it with the same filename but `.html` extension.

### What the HTML Report Contains

The report is a single self-contained HTML file (no external
dependencies) with four tabs:

#### Summary Tab

-   **Study-level statistics card** — Actual sample size, effective
    sample size (Kish formula), design effect (DEFF), weighting
    efficiency percentage, and plain-English interpretation
-   **Results overview table** — All questions at a glance with
    estimate, confidence interval, CI width, and quality badge
-   **Forest plot** — Visual comparison of all confidence intervals
-   **Representativeness table** — If population margins were
    provided, shows target vs achieved with traffic-light flags

#### Question Details Tab

-   **Per-question navigation** — Click any question to see its
    detailed results
-   **Plain-English callout** — Interpretation of the result,
    assumptions, and caveats written for non-statisticians
-   **Method comparison table** — Side-by-side comparison of all
    CI methods (Normal, Wilson, Bootstrap, Bayesian) with lower
    bound, upper bound, margin of error, and notes
-   **Method comparison chart** — Visual bar chart comparing CI
    widths across methods

#### Method Notes Tab

-   **Statistical methodology documentation** — How each method
    works, when to trust it, and what assumptions it makes
-   **Understanding limitations** — Critical caveats about what
    confidence intervals can and cannot tell you
-   **Editable comments box** — Free-text area for analyst notes
    (saved when you use Save Report)
-   **Analysis warnings** — Any issues detected during processing

#### Save Report

-   Serializes the entire report including any edits to the comments
    box and downloads it as a self-contained HTML file

### Customising Appearance

| Setting       | Default   | Purpose                        |
|---------------|-----------|--------------------------------|
| Brand_Colour  | `#1e3a5f` | Header gradient, active states |
| Accent_Colour | `#2aa198` | Focus borders, highlights      |

### Example Configuration

```
Setting                  Value
Generate_HTML_Report     Y
Brand_Colour             #003f87
Accent_Colour            #2aa198
Sampling_Method          Online_Panel
```

------------------------------------------------------------------------

## Understanding Confidence Intervals {#understanding-cis}

### What a Confidence Interval Tells You

A 95% confidence interval means: if you drew 100 independent
random samples from the same population and calculated a confidence
interval from each, approximately 95 of those intervals would
contain the true population value. It measures **precision** —
how tightly the data pins down the answer.

### What a Confidence Interval Does NOT Tell You

-   It does not tell you the probability that the true value is in
    the interval (that is the Bayesian credible interval)
-   It does not account for non-sampling errors: question wording
    bias, non-response bias, social desirability effects, or
    interviewer effects
-   It does not fix a biased sample — a narrow interval from a
    biased sample is precise but wrong
-   It assumes the stated sampling method (typically simple random
    sampling) was actually used

### The Most Common Mistake

Many researchers report a margin of error from a convenience sample
or opt-in online panel. This is technically meaningless because the
margin of error formula assumes random sampling. The true
uncertainty from a non-random sample is unknown and likely larger
than the reported margin of error. The Turas HTML report flags this
assumption prominently on every result.

------------------------------------------------------------------------

## Choosing the Right Method {#choosing-methods}

### For Proportions (Percentages)

| Situation | Recommended Method | Why |
|---|---|---|
| Standard survey, n > 100, proportion 10%–90% | Normal Approximation (MOE) | Simple, well-understood, performs well in this range |
| Proportion near 0% or 100% | Wilson Score | Prevents impossible intervals; better coverage near boundaries |
| Small sample (n < 50) | Wilson Score + Bootstrap | Wilson handles boundaries; bootstrap adds distribution-free check |
| Tracking study with prior waves | Bayesian | Incorporates prior knowledge; smooths estimates across waves |
| Skewed or unusual distribution | Bootstrap | Makes no distributional assumptions |
| Publication or regulatory reporting | All four methods | Method agreement strengthens credibility |

### For Means (Averages)

| Situation | Recommended Method | Why |
|---|---|---|
| Approximately normal data, n > 30 | t-Distribution | Standard, well-understood, mathematically optimal for normal data |
| Skewed data or small sample | Bootstrap | No normality assumption; reliable for non-symmetric distributions |
| Tracking study with historical data | Bayesian | Prior centres the estimate; prevents extreme swings between waves |
| Publication quality | t-Distribution + Bootstrap | Agreement between parametric and non-parametric methods is convincing |

### For NPS (Net Promoter Score)

| Situation | Recommended Method | Why |
|---|---|---|
| Standard NPS reporting | Normal Approximation | Uses the delta method for variance of a difference of proportions |
| Small sample or extreme NPS | Bootstrap | NPS is a difference of proportions — bootstrap handles this naturally |
| Tracking NPS over time | Bayesian | Smooths wave-to-wave variation with prior from previous waves |

### Method Agreement as a Quality Signal

When multiple methods produce similar intervals, you can be
confident the result is robust. When they disagree substantially:

-   Check whether the proportion is near 0% or 100% (Wilson will
    differ from Normal in this case — trust Wilson)
-   Check for heavy skew in the data (Bootstrap will differ from
    t-distribution — trust Bootstrap)
-   Check for strong priors (Bayesian will differ if the prior
    dominates — consider whether the prior is justified)

------------------------------------------------------------------------

## Sample Design and What It Means for Your Results

### The Core Question: Can I Trust These Numbers?

The answer depends on two things: **precision** (how wide are
the intervals?) and **accuracy** (is the sample representative?).
Confidence intervals only measure precision. A well-designed
sample addresses accuracy.

### How Different Sample Designs Affect Risk

| Design | Precision Risk | Accuracy Risk | Practical Guidance |
|---|---|---|---|
| Random | Low (formula is exact) | Low if response rate is high | Gold standard; results are directly generalisable |
| Stratified | Low to Moderate | Low | Often more precise than simple random; CIs may be conservative |
| Cluster | **Moderate to High** | Moderate | CIs do NOT adjust for clustering and may be too narrow |
| Quota | Moderate | Moderate if quotas well-matched | Not random, but structured quotas can mitigate bias |
| Online Panel | Moderate | Variable | Panel quality varies; self-selection and coverage gaps exist |
| Self-Selected | High | **High** | CIs are meaningful only as internal consistency checks |
| Census | Low | Depends on response rate | 80%+ response is excellent; below 50% is problematic |

### Quota Samples: A Realistic View

Most commercial market research uses quota samples. These are
not technically random, but a well-designed quota sample with
demographic targets closely matched to the population can
produce reliable results for most business decisions. The key
risks are:

1.  **Within-cell bias** — Even if age/gender quotas match the
    population, respondents within each cell are not randomly
    selected and may differ from non-respondents
2.  **Coverage gaps** — Hard-to-reach groups (e.g., rural,
    elderly, low-income) are often under-represented
3.  **Attitudinal differences** — People who agree to take surveys
    may hold different views from those who refuse

The Turas HTML report uses "Stability Interval" (not "Confidence
Interval") for non-probability designs to honestly communicate
this distinction.

### When Small Sub-Samples Arise

Some questions are only asked to a subset of respondents (e.g.,
product users, people who answered "Yes" to a filter question).
These sub-samples can be much smaller than the full sample,
leading to:

-   Wider confidence intervals
-   Higher sensitivity to outliers
-   Greater risk that a few respondents dominate the result

Use the `Filter_Variable` and `Filter_Values` columns in the
Question_Analysis sheet to flag these questions. The module will
calculate CIs on the filtered sub-sample and prominently flag
the reduced base size in the HTML report.

**Rule of thumb:** Sub-samples below n=100 should be interpreted
with caution. Below n=30, treat results as directional only.

------------------------------------------------------------------------

## Primer: Significant Differences in Tabs and Tracker

While the Confidence module focuses on individual question
precision, the **Tabs** and **Tracker** modules test whether
differences between groups or time periods are statistically
significant. Here is a brief guide to how these connect:

### Tabs: Comparing Groups

The Tabs module applies column-proportion z-tests (for
percentages) and independent t-tests (for means) to compare
banner groups. A result marked with a significance letter (e.g.,
"A") means that group's value is significantly higher than the
group indicated by the letter, at the configured confidence level.

**Connection to confidence intervals:** If two groups' confidence
intervals do not overlap, the difference is almost certainly
significant. If they do overlap, the difference may or may not
be significant (overlapping CIs is a conservative test).

### Tracker: Comparing Time Periods

The Tracker module tests whether a metric has changed
significantly between waves. It uses z-tests for proportions and
t-tests for means, with optional trend analysis.

**Connection to confidence intervals:** A change is significant
when the current wave's estimate falls outside the previous
wave's confidence interval (approximately). The Tracker module
handles this formally using hypothesis tests.

### Multiple Comparisons

When testing many questions or many groups simultaneously, some
"significant" results will be false positives. At 95% confidence,
roughly 1 in 20 tests will show significance by chance alone.
The Confidence module supports Bonferroni, Holm, and FDR
adjustments to control this.

------------------------------------------------------------------------

**End of User Manual**

*Turas Confidence Module v10.3* *Last Updated: March 2026*
