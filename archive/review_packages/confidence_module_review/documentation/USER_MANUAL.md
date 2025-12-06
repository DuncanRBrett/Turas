# Turas Confidence Analysis Module - User Manual

**Version:** 1.0.0
**Last Updated:** 2025-11-13

---

## Table of Contents

1. [Introduction](#introduction)
2. [What Is This Module?](#what-is-this-module)
3. [When to Use It](#when-to-use-it)
4. [Installation](#installation)
5. [Quick Start Guide](#quick-start-guide)
6. [Preparing Your Data](#preparing-your-data)
7. [Creating a Configuration File](#creating-a-configuration-file)
8. [Running an Analysis](#running-an-analysis)
9. [Understanding the Results](#understanding-the-results)
10. [Method Selection Guide](#method-selection-guide)
11. [Weighted vs Unweighted Analysis](#weighted-vs-unweighted-analysis)
12. [Troubleshooting](#troubleshooting)
13. [FAQs](#faqs)
14. [Glossary](#glossary)

---

## Introduction

The **Turas Confidence Analysis Module** automatically calculates confidence intervals for survey data. It supports both **proportions** (e.g., "% who agree") and **means** (e.g., "average rating"), with multiple statistical methods to choose from.

### Key Features

✅ **Multiple Methods**: Choose from 4 proportion methods and 3 mean methods
✅ **Weighted Data**: Handles survey weights with DEFF calculation
✅ **Flexible Input**: Accepts CSV or Excel data files
✅ **Professional Output**: 7-sheet Excel workbook with formatted results
✅ **No Coding Required**: Configure everything through Excel
✅ **Batch Processing**: Analyze up to 200 questions at once

---

## What Is This Module?

### The Problem It Solves

When analyzing survey data, you often need to report:
- "X% of respondents agree (±Y% margin of error)"
- "Average rating is Z with 95% confidence interval [A, B]"

Calculating these confidence intervals manually is:
- ❌ Time-consuming
- ❌ Error-prone
- ❌ Difficult with weighted data
- ❌ Hard to apply consistent methods

### The Solution

This module:
- ✅ Automates all confidence interval calculations
- ✅ Handles complex weighted surveys
- ✅ Applies best-practice statistical methods
- ✅ Generates publication-ready results

---

## When to Use It

### Perfect For:

- **Survey Analysis**: Customer satisfaction, NPS, employee engagement
- **Research Studies**: Academic research with confidence intervals
- **Market Research**: Consumer surveys, brand tracking
- **Quality Control**: Process capability studies
- **A/B Testing**: Comparing treatment groups

### Typical Questions:

**Proportions:**
- % who recommend (NPS promoters)
- % satisfied (top 2 box)
- % aware of brand
- % who purchased

**Means:**
- Average satisfaction rating
- Mean NPS score
- Average time spent
- Mean purchase amount

---

## Installation

### Prerequisites

1. **R** (version 4.0 or higher)
   - Download from: https://cran.r-project.org/

2. **RStudio** (recommended)
   - Download from: https://posit.co/download/rstudio-desktop/

### Required R Packages

Open R or RStudio and run:

```r
install.packages(c(
  "readxl",      # For reading Excel config files
  "openxlsx",    # For writing Excel output
  "data.table"   # For fast CSV reading
))
```

Optional (but recommended):
```r
install.packages("dplyr")  # Makes analysis faster
```

### Verify Installation

```r
# Check if packages are installed
library(readxl)
library(openxlsx)
library(data.table)

# If no errors, you're ready to go!
```

---

## Quick Start Guide

### 5-Minute Tutorial

**Step 1:** Open RStudio and navigate to the module folder:

```r
setwd("path/to/Turas/modules/confidence")
```

**Step 2:** Load the example setup:

```r
source("examples/create_example_config.R")
create_example_setup()
```

This creates:
- Example config file
- Example survey data (1000 respondents, 5 questions)

**Step 3:** Run the analysis:

```r
source("R/00_main.R")
run_confidence_analysis("examples/confidence_config_example.xlsx")
```

**Step 4:** Open the results:

```
examples/confidence_results_example.xlsx
```

You'll see 7 sheets with complete confidence interval results!

---

## Preparing Your Data

### Data Format Requirements

Your survey data must be in **one row per respondent** format:

| respondent_id | weight | Q1_satisfaction | Q2_recommend | Q3_rating | Q4_age |
|---------------|--------|-----------------|--------------|-----------|--------|
| 1 | 1.2 | Very Satisfied | Yes | 9 | 35 |
| 2 | 0.9 | Satisfied | Yes | 8 | 42 |
| 3 | 1.1 | Neutral | No | 6 | 28 |

### Requirements:

✅ **One row per respondent**
✅ **One column per question**
✅ **Column names** are question IDs
✅ **Optional weight column** (for weighted analysis)

### Supported File Formats:

- **CSV** (`.csv`) - Recommended for large files
- **Excel** (`.xlsx`) - Convenient for smaller files

### Data Preparation Checklist:

- [ ] Remove any header rows above data
- [ ] Ensure consistent response codes (e.g., always "Yes" not sometimes "yes")
- [ ] Check for missing values (NA, blank, "DK" are okay)
- [ ] If weighted: include a weight column with numeric values
- [ ] Save as CSV or XLSX

---

## Creating a Configuration File

The configuration file is an **Excel workbook** with 3 sheets that tell the module what to analyze.

### Option 1: Copy the Example (Easiest)

1. Navigate to `examples/confidence_config_example.xlsx`
2. **Save a copy** with your project name (e.g., `my_survey_config.xlsx`)
3. Edit the 3 sheets as described below

### Option 2: Create from Scratch

Create a new Excel workbook with these 3 sheets:

---

### Sheet 1: File_Paths

**Purpose:** Tell the module where your data is and where to save results.

| Parameter | Value |
|-----------|-------|
| Data_File | /full/path/to/your/survey_data.csv |
| Output_File | /full/path/to/results.xlsx |
| Weight_Variable | weight *(or leave blank if unweighted)* |

**Tips:**
- Use **full file paths** (absolute paths work best)
- Mac/Linux: `/Users/yourname/Documents/data.csv`
- Windows: `C:/Users/yourname/Documents/data.csv`
- Leave `Weight_Variable` blank if your data has no weights

---

### Sheet 2: Study_Settings

**Purpose:** Configure analysis-wide settings.

| Setting | Value | What It Does |
|---------|-------|--------------|
| Calculate_Effective_N | Y or N | Calculate effective sample size (needed if weighted) |
| Multiple_Comparison_Adjustment | N | Future feature: adjust for multiple testing |
| Multiple_Comparison_Method | None | Future feature |
| Bootstrap_Iterations | 1000 | Number of bootstrap iterations (1000-5000) |
| Confidence_Level | 0.95 | Confidence level (0.90, 0.95, or 0.99) |
| Decimal_Separator | , | Use comma (European) or period (US) |

**Recommendations:**
- **Calculate_Effective_N**: Set to Y if you have weights, N if unweighted
- **Bootstrap_Iterations**: Start with 1000 for testing, use 5000 for final results
- **Confidence_Level**: 0.95 is standard (95% confidence intervals)
- **Decimal_Separator**: Use `,` for European locale, `.` for US/UK

---

### Sheet 3: Question_Analysis

**Purpose:** Specify which questions to analyze and which methods to use.

**Columns:**

| Column | What to Put | Example |
|--------|-------------|---------|
| Question_ID | Column name from your data | Q1_satisfaction |
| Statistic_Type | "Proportion" or "Mean" | Proportion |
| Categories | Values to count (proportions only) | Satisfied,Very Satisfied |
| Run_MOE | Y or N | Y |
| Run_Wilson | Y or N | Y |
| Run_Bootstrap | Y or N | N |
| Run_Credible | Y or N | N |
| Prior_Mean | For Bayesian (optional) | 0.7 |
| Prior_SD | For Bayesian means (optional) | 0.1 |
| Prior_N | For Bayesian (optional) | 100 |
| Notes | Your notes | Top 2 box satisfaction |

**Example Rows:**

#### Proportion Example - NPS Promoters (9-10 ratings):

| Question_ID | Statistic_Type | Categories | Run_MOE | Run_Wilson | Run_Bootstrap | Run_Credible | Notes |
|-------------|----------------|------------|---------|------------|---------------|--------------|-------|
| Q2_NPS | Proportion | 9,10 | N | Y | Y | N | % Promoters |

#### Proportion Example - % Who Said "Yes":

| Question_ID | Statistic_Type | Categories | Run_MOE | Run_Wilson | Run_Bootstrap | Run_Credible | Notes |
|-------------|----------------|------------|---------|------------|---------------|--------------|-------|
| Q3_recommend | Proportion | Yes | N | Y | N | N | % Recommend |

#### Mean Example - Average Rating:

| Question_ID | Statistic_Type | Categories | Run_MOE | Run_Wilson | Run_Bootstrap | Run_Credible | Notes |
|-------------|----------------|------------|---------|------------|---------------|--------------|-------|
| Q1_rating | Mean | Q1_rating | N | N | Y | Y | Avg rating 1-10 |

**Important Notes:**

1. **Question_ID** must **exactly match** the column name in your data file
2. **Categories** for proportions: list the values to count as "success"
   - For text: `Yes` or `Satisfied,Very Satisfied`
   - For numbers: `9,10` or `4,5`
   - **Just list the values** - don't use R expressions like `Q1=="Yes"`
3. **Categories** for means: enter the column name (same as Question_ID)
4. You can analyze **up to 200 questions** at once

---

## Running an Analysis

### Step-by-Step Process

**1. Open RStudio (or R)**

**2. Navigate to the module directory:**

```r
setwd("/path/to/Turas/modules/confidence")
```

**3. Load the module:**

```r
source("R/00_main.R")
```

You should see:
```
✓ Turas Confidence Analysis Module loaded (v1.0.0)
```

**4. Run your analysis:**

```r
run_confidence_analysis("/path/to/your/config.xlsx")
```

**5. Watch the progress:**

You'll see output for each step:
```
STEP 1/6: Loading configuration...
STEP 2/6: Loading survey data...
STEP 3/6: Calculating study-level statistics...
STEP 4/6: Processing questions...
STEP 5/6: Quality checks...
STEP 6/6: Generating Excel output...
```

**6. Check for completion:**

```
✓ Output written to: /path/to/your/results.xlsx
ANALYSIS COMPLETE
```

---

### What Happens During Analysis

```
┌─────────────────────────┐
│ Load Configuration      │  Reads your Excel config file
└───────────┬─────────────┘
            ↓
┌─────────────────────────┐
│ Load Survey Data        │  Reads your CSV/Excel data
└───────────┬─────────────┘
            ↓
┌─────────────────────────┐
│ Study-Level Statistics  │  If weighted: calculate DEFF
└───────────┬─────────────┘
            ↓
┌─────────────────────────┐
│ Process Each Question   │  Calculate CIs for all questions
│ - Proportions           │  Using methods you selected
│ - Means                 │
└───────────┬─────────────┘
            ↓
┌─────────────────────────┐
│ Quality Checks          │  Detect any warnings
└───────────┬─────────────┘
            ↓
┌─────────────────────────┐
│ Generate Excel Output   │  Create 7-sheet workbook
└─────────────────────────┘
```

---

## Understanding the Results

Your output Excel file contains **7 sheets**:

### Sheet 1: Summary

**What it shows:** High-level overview of the entire analysis

**Key information:**
- Analysis date and version
- Confidence level used
- Number of questions analyzed
- Sample size information

**Example:**
```
Analysis Information
  Date: 2025-11-13
  Confidence Level: 0.95

Study-Level Statistics
  Actual n: 1000
  Effective n: 915
  DEFF: 1.09

Results Summary
  Proportions analyzed: 3
  Means analyzed: 2
```

---

### Sheet 2: Study_Level

**What it shows:** Sample size and weighting statistics (if applicable)

**For weighted data:**
- **Actual_n**: Number of respondents
- **Effective_n**: Adjusted sample size accounting for weights
- **DEFF**: Design effect (how much weighting increases variance)
- **Weight_CV**: Coefficient of variation for weights
- **Warnings**: Any weight quality issues

**Interpretation:**
- **DEFF = 1.0**: No design effect (unweighted or perfectly uniform weights)
- **DEFF = 1.2**: Weighting increases variance by 20%
- **DEFF > 2.0**: High design effect - review weights
- **Weight_CV > 0.3**: High weight variability (warning generated)

---

### Sheet 3: Proportions_Detail

**What it shows:** Confidence intervals for all proportion questions

**Columns:**

| Column | Meaning | Example |
|--------|---------|---------|
| Question_ID | Question identifier | Q1_satisfaction |
| Category | Values counted | "Satisfied,Very Satisfied" |
| Proportion | % in category | 0.67 (67%) |
| Sample_Size | Valid responses | 980 |
| Effective_n | Adjusted n (if weighted) | 895 |

**CI Columns (depending on methods selected):**

| Column | Method | When to Use |
|--------|--------|-------------|
| MOE_Normal_Lower, Upper, MOE | Normal approximation | Large samples, moderate proportions |
| Wilson_Lower, Wilson_Upper | Wilson score | Best for survey data, extreme proportions |
| Bootstrap_Lower, Bootstrap_Upper | Bootstrap resampling | Complex weighting, non-normal data |
| Bayesian_Lower, Bayesian_Upper | Bayesian credible interval | Incorporating prior knowledge |

**Example Row:**
```
Q1_satisfaction | Satisfied,Very Satisfied | 0.67 | 980 | 895 | 0.64 | 0.70 | ...
```
Interpretation: 67% satisfied, 95% CI: [64%, 70%]

---

### Sheet 4: Means_Detail

**What it shows:** Confidence intervals for all mean questions

**Columns:**

| Column | Meaning | Example |
|--------|---------|---------|
| Question_ID | Question identifier | Q2_rating |
| Mean | Average value | 7.2 |
| SD | Standard deviation | 1.8 |
| Sample_Size | Valid responses | 975 |
| Effective_n | Adjusted n (if weighted) | 890 |

**CI Columns:**

| Column | Method | When to Use |
|--------|--------|-------------|
| tDist_Lower, tDist_Upper, SE, DF | t-distribution | Standard method for means |
| Bootstrap_Lower, Bootstrap_Upper | Bootstrap resampling | Skewed data, complex weights |
| Bayesian_Lower, Bayesian_Upper, Bayesian_Mean | Bayesian | Incorporating prior knowledge |

**Example Row:**
```
Q2_rating | 7.2 | 1.8 | 975 | 890 | 7.0 | 7.4 | 0.06 | 889 | ...
```
Interpretation: Average rating 7.2, 95% CI: [7.0, 7.4]

---

### Sheet 5: Methodology

**What it shows:** Explanation of statistical methods used

**Purpose:** Documentation for your report/publication

**Contents:**
- Description of each CI method
- When to use each method
- Assumptions and limitations
- References to academic papers

**Use this to:**
- Write your methodology section
- Explain results to stakeholders
- Choose appropriate methods

---

### Sheet 6: Warnings

**What it shows:** Data quality issues detected

**Common Warnings:**

| Warning | Meaning | Action |
|---------|---------|--------|
| High DEFF (> 2.0) | Weights very unequal | Review weighting scheme |
| High weight CV | Weights highly variable | Check for extreme weights |
| Small sample (n < 30) | CI may be unreliable | Collect more data or use caution |
| Extreme proportion (p < 0.1 or p > 0.9) | Use Wilson method | Already handled automatically |

**If no warnings:**
```
✓ No warnings detected
```

---

### Sheet 7: Inputs

**What it shows:** Complete record of your configuration

**Purpose:** Documentation and reproducibility

**Contents:**
- All file paths
- All study settings
- All questions analyzed with their specifications

**Use this to:**
- Document your analysis
- Reproduce results later
- Share analysis setup with colleagues

---

## Method Selection Guide

### For Proportions

**Q: Which method should I use?**

**Quick Answer:** Use **Wilson** for most survey work.

**Detailed Guide:**

| Method | Best For | Avoid When |
|--------|----------|------------|
| **MOE (Normal)** | Large samples (n > 100), moderate proportions (0.2 < p < 0.8) | Small samples, extreme proportions |
| **Wilson** ⭐ | **All survey data**, especially extreme proportions | Never - it's always safe |
| **Bootstrap** | Complex weighting, skewed data, when you want non-parametric CI | Small samples (n < 50) |
| **Bayesian** | Prior knowledge available, small samples | When no prior information |

**Recommendation:**
- **Standard analysis**: Wilson only
- **Thorough analysis**: Wilson + Bootstrap
- **With prior knowledge**: Wilson + Bayesian

---

### For Means

**Q: Which method should I use?**

**Quick Answer:** Use **t-distribution** for most cases.

**Detailed Guide:**

| Method | Best For | Avoid When |
|--------|----------|------------|
| **t-distribution** ⭐ | **Most mean calculations**, normally distributed data | Heavily skewed data |
| **Bootstrap** | Skewed data, complex weighting, robust estimation | Very small samples (n < 20) |
| **Bayesian** | Prior knowledge available, regularization needed | No prior information |

**Recommendation:**
- **Standard analysis**: t-distribution only
- **Robust analysis**: t-distribution + Bootstrap
- **With prior knowledge**: t-distribution + Bayesian

---

### Confidence Level Selection

| Level | Use When | Typical Field |
|-------|----------|---------------|
| **90%** | Exploratory analysis, relaxed precision | Early-stage research |
| **95%** ⭐ | **Standard for most work** | Business, social science |
| **99%** | High-stakes decisions, need extra confidence | Medical, safety |

**Default: 0.95 (95% confidence)**

---

## Weighted vs Unweighted Analysis

### When to Use Weights

Use **weighted analysis** when:
- ✅ You have survey weights from a sampling statistician
- ✅ Your sample doesn't match population demographics
- ✅ You want to adjust for non-response
- ✅ You're using post-stratification weights

Use **unweighted analysis** when:
- ✅ Random sample with good response rate
- ✅ Sample matches population
- ✅ No weights provided by statistician
- ✅ Simpler analysis preferred

---

### Understanding Weighted Results

**Key Concepts:**

**1. Design Effect (DEFF)**
- Measures how much weighting increases variance
- Formula: DEFF = 1 + CV²(weights)
- **DEFF = 1.0**: No effect (same as unweighted)
- **DEFF = 1.2**: Variance increased 20%
- **DEFF = 2.0**: Variance doubled

**2. Effective Sample Size (n_eff)**
- Adjusted sample size accounting for weights
- Formula: n_eff = n / DEFF
- Used for calculating standard errors

**Example:**
```
Actual n: 1000
Weights: Mean = 1.0, CV = 0.35
DEFF: 1.12
Effective n: 893
```

**Interpretation:** Your 1000 weighted respondents provide information equivalent to 893 unweighted respondents.

**Impact on CI Width:**
- Weighted CIs are **wider** than unweighted
- The higher the DEFF, the wider the CI
- This correctly reflects the uncertainty from weighting

---

## Troubleshooting

### Common Issues

---

#### Issue 1: "Error: File not found"

**Problem:** Can't find your data file or config file

**Solutions:**
1. Check file path is correct (copy-paste from file browser)
2. Use **full/absolute paths**, not relative paths
3. Mac/Linux: `/Users/name/Documents/data.csv`
4. Windows: `C:/Users/name/Documents/data.csv` (use forward slashes)
5. Check file actually exists at that location

---

#### Issue 2: "Error: Column 'Q1' not found"

**Problem:** Question_ID doesn't match your data

**Solutions:**
1. Check column names in your data file match exactly
2. Case-sensitive: `Q1` ≠ `q1`
3. Check for extra spaces: `Q1 ` ≠ `Q1`
4. Look at actual column names:
   ```r
   data <- read.csv("your_data.csv")
   names(data)
   ```

---

#### Issue 3: Proportion shows as 0.00

**Problem:** Categories don't match any data values

**Solutions:**
1. Check actual values in your data:
   ```r
   table(data$Q1, useNA = "always")
   ```
2. Match exactly: if data says "yes", Categories must be `yes` (not `Yes`)
3. Check for spaces or special characters
4. For numbers: use `9,10` not `"9","10"`

**Example:**
- Data values: `"Yes"`, `"No"`, `"DK"`
- Categories column should be: `Yes`
- NOT: `Q1=="Yes"` or `"Yes"` or `1`

---

#### Issue 4: No confidence intervals showing

**Problem:** CI columns are empty or missing

**Solutions:**
1. Check Run_* flags are set to `Y` (not `y` or `Yes`)
2. Restart R and reload the module:
   ```r
   # Close RStudio completely
   # Reopen, then:
   source("R/00_main.R")
   run_confidence_analysis("your_config.xlsx")
   ```
3. Check for errors in console output
4. Verify Confidence_Level is numeric (0.95, not "95%")

---

#### Issue 5: Numbers show incorrectly in Excel

**Problem:** See "002" instead of "1.67" or numbers appear as text

**Solution:**
- This was a known issue, now fixed in v1.0.0
- Update to latest version:
  ```r
  # Pull latest code from Git
  # Restart R
  # Rerun analysis
  ```
- Numbers are now properly formatted as numeric with locale-aware display

---

#### Issue 6: Analysis very slow

**Problem:** Taking minutes instead of seconds

**Solutions:**
1. Reduce Bootstrap_Iterations:
   - For testing: 100-500
   - For final results: 1000-5000
2. Use CSV instead of XLSX for data (5x faster)
3. Reduce number of questions if testing
4. Don't run Bootstrap for every question (slower than other methods)

**Typical timings:**
- Config + Data load: <1 second
- 10 questions, Wilson only: ~5 seconds
- 10 questions, all methods: ~30 seconds
- 100 questions, Wilson only: ~30 seconds

---

## FAQs

### General Questions

**Q: How many questions can I analyze at once?**

A: Up to **200 questions** per analysis. This limit ensures reasonable processing time.

---

**Q: Can I analyze the same question with different methods?**

A: Yes! Set multiple Run_* flags to Y for the same question. Results will show all methods side-by-side.

---

**Q: What's the difference between Proportion and Mean?**

A:
- **Proportion**: % in a category (e.g., % who said "Yes", % promoters)
- **Mean**: Average of numeric values (e.g., average rating on 1-10 scale)

---

**Q: Do I need to know statistics to use this?**

A: Basic understanding helps, but not required. The module:
- Uses best-practice methods automatically
- Provides clear documentation
- Generates warnings for potential issues

---

### Technical Questions

**Q: Can I use this with Qualtrics/SurveyMonkey data?**

A: Yes! Export your data to CSV or Excel in "one row per respondent" format, then use this module.

---

**Q: Does this handle missing data?**

A: Yes. The module automatically:
- Excludes NA values
- Excludes "DK" (Don't Know) responses
- Calculates valid sample size
- Reports how many responses were valid

---

**Q: Can I use this for A/B testing?**

A: Yes! Create one question for each group:
- Question A: Treatment group mean/proportion
- Question B: Control group mean/proportion
- Compare the confidence intervals

For formal significance testing between groups, see future enhancements.

---

**Q: What's the minimum sample size?**

A:
- **Proportions**: n ≥ 30 recommended, n ≥ 100 ideal
- **Means**: n ≥ 30 recommended
- Smaller samples will work but CIs will be wide and may be unreliable

---

**Q: Can I export results to PowerPoint/Word?**

A: The Excel output can be:
- Copy-pasted into PowerPoint/Word
- Imported into other tools
- Reformatted as needed

Future versions may include direct export.

---

### Method Questions

**Q: What's the difference between credible interval and confidence interval?**

A:
- **Confidence Interval** (frequentist): "If we repeated this survey 100 times, 95 of the intervals would contain the true value"
- **Credible Interval** (Bayesian): "There's a 95% probability the true value is in this interval"

For practical purposes, interpret them similarly.

---

**Q: When should I use Bayesian methods?**

A: Use Bayesian when:
- You have prior knowledge to incorporate
- Sample is small and you need regularization
- You want probabilistic interpretation

---

**Q: Why are my weighted CIs wider than unweighted?**

A: This is correct! Weighting increases variance, so CIs should be wider. The DEFF tells you how much wider:
- DEFF = 1.2 → CIs about 10% wider
- DEFF = 2.0 → CIs about 41% wider

---

## Glossary

**Bayesian Analysis**: Statistical approach that incorporates prior knowledge with observed data.

**Bootstrap**: Resampling method that estimates CI by repeatedly sampling the data.

**Categories**: The values you want to count as "success" in a proportion calculation.

**CI (Confidence Interval)**: Range of values likely to contain the true population parameter.

**Credible Interval**: Bayesian equivalent of confidence interval.

**CV (Coefficient of Variation)**: Standard deviation divided by mean; measures relative variability.

**DEFF (Design Effect)**: Factor by which sampling variance is increased due to complex survey design (mainly weighting).

**Effective Sample Size (n_eff)**: Adjusted sample size accounting for design effect.

**MOE (Margin of Error)**: Half-width of confidence interval (for normal approximation method).

**NPS (Net Promoter Score)**: Customer loyalty metric; promoters are those rating 9-10 on 0-10 scale.

**Prior**: In Bayesian analysis, your knowledge/belief before seeing the data.

**Proportion**: Percentage or fraction of respondents in a category.

**p-value**: (Not calculated by this module) Probability of observing data as extreme as yours if null hypothesis is true.

**Standard Error (SE)**: Standard deviation of the sampling distribution.

**t-distribution**: Probability distribution used for calculating CIs for means.

**Weights**: Numeric values assigned to respondents to adjust for sampling design or non-response.

**Wilson Score**: Modern method for proportion CIs that performs well for all sample sizes and proportions.

---

## Getting Help

### Documentation

1. **This manual** - Covers basic usage
2. **MAINTENANCE_GUIDE.md** - Technical details for developers
3. **README.md** - Quick reference
4. **Design spec** - Full statistical methodology

### Support

**For issues:**
1. Check [Troubleshooting](#troubleshooting) section
2. Review [FAQs](#faqs)
3. Check example files in `examples/` folder
4. Contact [your IT/analytics team]

**When reporting issues, include:**
- Error message (copy-paste from R console)
- Your config file (remove sensitive data)
- Sample of your data structure
- R version and package versions:
  ```r
  sessionInfo()
  ```

---

## Example Walkthrough

Let's walk through a complete analysis from start to finish.

### Scenario

You conducted a customer satisfaction survey with:
- 500 respondents
- 3 questions:
  1. Overall satisfaction (1-10 scale)
  2. Would recommend? (Yes/No)
  3. NPS score (0-10 scale)
- Survey weights provided by statistician

---

### Step 1: Prepare Data

Your data file `satisfaction_survey.csv`:

```csv
respondent_id,weight,overall_satisfaction,recommend,nps
1,1.2,8,Yes,9
2,0.9,7,Yes,8
3,1.1,9,Yes,10
...
500,1.0,6,No,5
```

✅ One row per respondent
✅ Clear column names
✅ Weight column included

---

### Step 2: Create Config

Create `satisfaction_config.xlsx` with 3 sheets:

**Sheet 1: File_Paths**
| Parameter | Value |
|-----------|-------|
| Data_File | /Users/me/surveys/satisfaction_survey.csv |
| Output_File | /Users/me/surveys/satisfaction_results.xlsx |
| Weight_Variable | weight |

**Sheet 2: Study_Settings**
| Setting | Value |
|---------|-------|
| Calculate_Effective_N | Y |
| Multiple_Comparison_Adjustment | N |
| Multiple_Comparison_Method | None |
| Bootstrap_Iterations | 1000 |
| Confidence_Level | 0.95 |
| Decimal_Separator | . |

**Sheet 3: Question_Analysis**

| Question_ID | Statistic_Type | Categories | Run_MOE | Run_Wilson | Run_Bootstrap | Run_Credible | Notes |
|-------------|----------------|------------|---------|------------|---------------|--------------|-------|
| overall_satisfaction | Mean | overall_satisfaction | N | N | Y | Y | Overall rating |
| recommend | Proportion | Yes | N | Y | N | N | % Recommend |
| nps | Proportion | 9,10 | N | Y | Y | N | % Promoters |

---

### Step 3: Run Analysis

```r
setwd("path/to/Turas/modules/confidence")
source("R/00_main.R")
run_confidence_analysis("/Users/me/surveys/satisfaction_config.xlsx")
```

Output:
```
STEP 1/6: Loading configuration...
  ✓ Questions to analyze: 3
  ✓ Confidence level: 0.95

STEP 2/6: Loading survey data...
  ✓ Data loaded: 500 respondents
  ✓ Weighted analysis using: weight

STEP 3/6: Calculating study-level statistics...
  ✓ Actual n: 500
  ✓ Effective n: 456
  ✓ DEFF: 1.10

STEP 4/6: Processing questions...
  ✓ Processed: 2 proportions, 1 means

STEP 5/6: Quality checks...
  ✓ No warnings detected

STEP 6/6: Generating Excel output...
  ✓ Output written to: satisfaction_results.xlsx

ANALYSIS COMPLETE
```

---

### Step 4: Review Results

**Proportions_Detail sheet:**

| Question_ID | Category | Proportion | Sample_Size | Effective_n | Wilson_Lower | Wilson_Upper | Bootstrap_Lower | Bootstrap_Upper |
|-------------|----------|------------|-------------|-------------|--------------|--------------|-----------------|-----------------|
| recommend | Yes | 0.78 | 500 | 456 | 0.74 | 0.82 | | |
| nps | 9,10 | 0.42 | 500 | 456 | 0.38 | 0.46 | 0.37 | 0.47 |

**Interpretation:**
- 78% would recommend [95% CI: 74%-82%]
- 42% are promoters [95% CI: 37%-47%]

**Means_Detail sheet:**

| Question_ID | Mean | SD | Sample_Size | Effective_n | Bootstrap_Lower | Bootstrap_Upper | Bayesian_Lower | Bayesian_Upper |
|-------------|------|----|----|---|---|---|---|---|
| overall_satisfaction | 7.6 | 1.8 | 500 | 456 | 7.3 | 7.9 | 7.4 | 7.8 |

**Interpretation:**
- Average satisfaction: 7.6 out of 10 [95% CI: 7.3-7.9]

---

### Step 5: Report Results

**In your presentation:**

> "Based on a weighted survey of 500 customers (effective n=456):
> - **78%** would recommend our service (95% CI: 74%-82%)
> - **42%** are promoters (95% CI: 37%-47%)
> - Average satisfaction rating is **7.6 out of 10** (95% CI: 7.3-7.9)
>
> All confidence intervals calculated using industry-standard methods accounting for survey weighting (DEFF=1.10)."

---

## Appendix: Config File Template

### Blank Template

You can copy this into Excel to create your own config file:

**Sheet 1: File_Paths**
```
Parameter           | Value
--------------------|----------------------------------
Data_File           |
Output_File         |
Weight_Variable     |
```

**Sheet 2: Study_Settings**
```
Setting                          | Value
---------------------------------|-------
Calculate_Effective_N            | Y
Multiple_Comparison_Adjustment   | N
Multiple_Comparison_Method       | None
Bootstrap_Iterations             | 1000
Confidence_Level                 | 0.95
Decimal_Separator                | .
```

**Sheet 3: Question_Analysis**
```
Question_ID | Statistic_Type | Categories | Run_MOE | Run_Wilson | Run_Bootstrap | Run_Credible | Prior_Mean | Prior_SD | Prior_N | Notes
------------|----------------|------------|---------|------------|---------------|--------------|------------|----------|---------|-------
            | Proportion     |            | N       | Y          | N             | N            |            |          |         |
            | Mean           |            | N       | N          | Y             | N            |            |          |         |
```

---

**End of User Manual**

**Version:** 1.0.0
**Last Updated:** 2025-11-13
**For technical details, see:** MAINTENANCE_GUIDE.md
