# Categorical Key Driver Analysis - User Manual

**Version:** 1.0
**Last Updated:** December 2024

---

## Table of Contents

1. [Introduction](#introduction)
2. [When to Use This Module](#when-to-use-this-module)
3. [Setting Up Your Analysis](#setting-up-your-analysis)
4. [Configuration File Reference](#configuration-file-reference)
5. [Running the Analysis](#running-the-analysis)
6. [Understanding the Output](#understanding-the-output)
7. [Interpreting Results](#interpreting-results)
8. [Common Issues and Solutions](#common-issues-and-solutions)
9. [Technical Details](#technical-details)

---

## Introduction

The Categorical Key Driver module identifies which factors most strongly influence a categorical outcome. Unlike the standard Key Driver module (which handles continuous outcomes like satisfaction scores), this module handles categorical outcomes using logistic regression methods.

### What It Does

- Analyzes what drives binary outcomes (Yes/No, Success/Failure)
- Analyzes what drives ordinal outcomes (Low/Medium/High)
- Analyzes what drives nominal outcomes (Brand A/B/C/D)
- Calculates variable importance using chi-square tests
- Produces odds ratios with confidence intervals
- Generates plain-English executive summaries

---

## When to Use This Module

### Use This Module When:

- Your outcome has discrete categories (not a numeric scale)
- You want to know which factors predict category membership
- You need odds ratios rather than regression coefficients
- Your outcome is naturally categorical (not binned continuous)

### Examples:

| Scenario | Outcome | Type |
|----------|---------|------|
| Customer churn | Retained vs Churned | Binary |
| Employee satisfaction | Low/Medium/High | Ordinal |
| Brand preference | Brand A/B/C/D | Nominal |
| Survey completion | Complete/Partial/Abandoned | Ordinal |
| Product choice | Product 1/2/3/4/5 | Nominal |

### Don't Use This Module When:

- Your outcome is a continuous score (use standard Key Driver)
- You need to predict numeric values
- You have time-series data (use Tracker module)

---

## Setting Up Your Analysis

### Step 1: Prepare Your Data

Your data file should be in CSV, Excel (.xlsx), SPSS (.sav), or Stata (.dta) format.

**Required:**
- One categorical outcome variable
- One or more predictor (driver) variables
- Each row represents one respondent

**Example data structure:**

| respondent_id | satisfaction | grade | campus | course |
|--------------|--------------|-------|--------|--------|
| 1 | High | A | Cape Town | BCom |
| 2 | Neutral | B | Durban | BSocSci |
| 3 | Low | C | Online | BCom |
| ... | ... | ... | ... | ... |

### Step 2: Create Configuration File

Create an Excel workbook with two sheets: Settings and Variables.

**Settings Sheet:**

| Setting | Value |
|---------|-------|
| analysis_name | My Analysis Name |
| data_file | data.csv |
| output_file | results.xlsx |
| outcome_type | auto |

**Variables Sheet:**

| VariableName | Type | Label | Order |
|--------------|------|-------|-------|
| satisfaction | Outcome | Satisfaction Level | Low;Neutral;High |
| grade | Driver | Academic Grade | D;C;B;A |
| campus | Driver | Campus Location | |

### Step 3: Place Files in Project Folder

Organize your project:

```
my_project/
├── catdriver_config.xlsx   <- Configuration file
├── survey_data.csv         <- Your data
└── output/                 <- Results folder (created if needed)
```

---

## Configuration File Reference

### Settings Sheet

| Setting | Required | Default | Valid Values | Description |
|---------|----------|---------|--------------|-------------|
| analysis_name | No | "Key Driver Analysis" | Any text | Title for reports |
| data_file | **Yes** | - | File path | Data file location |
| output_file | **Yes** | - | File path | Where to save results |
| outcome_type | No | auto | auto, binary, ordinal, nominal | Override auto-detection |
| reference_category | No | First alphabetically | Category name | Comparison baseline |
| min_sample_size | No | 30 | Positive integer | Minimum complete cases |
| confidence_level | No | 0.95 | 0.80 to 0.99 | For confidence intervals |
| missing_threshold | No | 50 | 0 to 100 | Warn if % missing exceeds |
| detailed_output | No | TRUE | TRUE or FALSE | Include all sheets |

### Variables Sheet

| Column | Required | Description |
|--------|----------|-------------|
| VariableName | **Yes** | Exact column name in data file |
| Type | **Yes** | One of: Outcome, Driver, Weight |
| Label | **Yes** | Display name for reports |
| Order | No | Semicolon-separated categories (e.g., Low;Medium;High) |

#### Type Values:

- **Outcome**: The dependent variable you're trying to explain (exactly 1)
- **Driver**: Predictor variables (1 or more)
- **Weight**: Survey weight variable (optional, max 1)

#### Order Column:

For ordinal variables, specify the order from lowest to highest:
- `Low;Neutral;High`
- `Strongly Disagree;Disagree;Neutral;Agree;Strongly Agree`
- `1;2;3;4;5`

For nominal or binary variables, leave Order blank or specify reference category first.

---

## Running the Analysis

### Method 1: Using the GUI (Recommended)

1. **Launch Turas Suite**
   ```r
   setwd("/path/to/Turas")
   source("launch_turas.R")
   ```

2. **Click "Launch Categorical Key Driver"**

3. **Select Project Directory**
   - Click "Browse for Project Folder"
   - Navigate to your project folder

4. **Select Configuration File**
   - The GUI will detect config files automatically
   - Or browse to select manually

5. **Click "Run Categorical Key Driver Analysis"**

6. **Review Output**
   - Console shows progress and summary
   - Excel file saved to configured location

### Method 2: Using R Script

```r
# Set working directory to Turas root
setwd("/path/to/Turas")

# Source module files
source("modules/catdriver/R/07_utilities.R")
source("modules/catdriver/R/01_config.R")
source("modules/catdriver/R/02_validation.R")
source("modules/catdriver/R/03_preprocessing.R")
source("modules/catdriver/R/04_analysis.R")
source("modules/catdriver/R/05_importance.R")
source("modules/catdriver/R/06_output.R")
source("modules/catdriver/R/00_main.R")

# Run analysis
results <- run_categorical_keydriver("path/to/config.xlsx")

# Access results programmatically
print(results$importance)
print(results$model_result$fit_statistics)
```

---

## Understanding the Output

### Sheet 1: Executive Summary

Plain-English summary for non-statisticians. Includes:
- Sample information
- Top drivers ranked by importance
- Key insights auto-generated from results
- Model fit interpretation
- Cautions and warnings

### Sheet 2: Importance Summary

| Column | Description |
|--------|-------------|
| Rank | Position by importance |
| Factor | Variable name |
| Label | Display name |
| Importance % | Relative contribution to model |
| Chi-Square | Test statistic |
| P-Value | Statistical significance |
| Sig. | Stars (*** p<0.001, ** p<0.01, * p<0.05) |
| Effect Size | Small/Medium/Large/Very Large |

### Sheet 3: Factor Patterns

For each driver, shows:
- Category breakdown (N and %)
- Outcome distribution per category
- Odds ratio vs reference category
- 95% confidence interval
- Effect size interpretation

Reference category highlighted in green.

### Sheet 4: Model Summary

Technical model statistics:
- Model type used
- Sample sizes (original and complete cases)
- McFadden Pseudo-R2 with interpretation
- AIC (lower is better)
- Likelihood ratio test vs null model

### Sheet 5: Odds Ratios (Detailed)

Full odds ratio table with:
- Factor and comparison category
- Reference category
- Point estimate
- Confidence interval
- P-value
- Effect size label

### Sheet 6: Diagnostics

Data quality checks:
- Sample size adequacy
- Missing data rates per variable
- Small cell warnings
- Convergence status
- Multicollinearity assessment

---

## Interpreting Results

### Odds Ratios

An odds ratio (OR) compares the odds of the outcome between categories.

| OR | Interpretation |
|----|----------------|
| OR = 1.0 | No difference from reference |
| OR > 1.0 | Higher odds than reference |
| OR < 1.0 | Lower odds than reference |

**Example:**
> "Grade A students are 4.2x more likely to report High satisfaction compared to Grade D students (OR = 4.2, 95% CI: 2.8-6.2, p < 0.001)"

### Effect Size Guidelines

| Odds Ratio Range | Effect Size |
|------------------|-------------|
| 0.9 - 1.1 | Negligible |
| 0.67 - 0.9 or 1.1 - 1.5 | Small |
| 0.5 - 0.67 or 1.5 - 2.0 | Medium |
| 0.33 - 0.5 or 2.0 - 3.0 | Large |
| < 0.33 or > 3.0 | Very Large |

### Importance Percentages

| Importance % | Meaning |
|--------------|---------|
| > 30% | Dominant driver - focus here first |
| 15-30% | Major driver - significant influence |
| 5-15% | Moderate driver - worth considering |
| < 5% | Minor driver - limited impact |

### Model Fit (McFadden R2)

| R2 Value | Interpretation |
|----------|----------------|
| 0.4+ | Excellent fit |
| 0.2 - 0.4 | Good fit |
| 0.1 - 0.2 | Moderate fit |
| < 0.1 | Limited explanatory power |

---

## Common Issues and Solutions

### "Config file not found"

**Cause:** File path in Settings is incorrect.
**Solution:** Use relative paths from config file location, or full absolute paths.

### "Outcome variable not found"

**Cause:** Column name in Variables sheet doesn't match data file.
**Solution:** Check exact spelling and case sensitivity.

### "Insufficient complete cases"

**Cause:** Too much missing data.
**Solutions:**
- Check which variables have high missing rates (see Diagnostics sheet)
- Consider removing variables with >50% missing
- Investigate if missingness is systematic

### "Model did not converge"

**Cause:** Usually perfect separation or too many categories.
**Solutions:**
- Collapse rare categories
- Remove predictors with very unbalanced categories
- Use fewer predictors

### "Small cells detected"

**Cause:** Some predictor-outcome combinations have <5 observations.
**Impact:** May cause unstable estimates.
**Solutions:**
- Collapse similar categories
- Remove problematic predictor
- Interpret with caution

### "High multicollinearity"

**Cause:** Predictors are highly correlated.
**Solutions:**
- Remove one of the correlated predictors
- Combine into composite variable
- Use only the most important predictor from correlated set

---

## Technical Details

### Statistical Methods

**Binary Logistic Regression**
- Function: `glm(family = binomial)`
- Output: Log-odds coefficients converted to odds ratios
- Metrics: AIC, pseudo-R2, classification accuracy

**Ordinal Logistic Regression**
- Function: `MASS::polr()` (Proportional Odds)
- Assumption: Cumulative odds ratios equal across thresholds
- Practical check: OR variation <25% across thresholds

**Multinomial Logistic Regression**
- Function: `nnet::multinom()`
- Output: Separate log-odds for each outcome vs reference
- Convergence: Max 500 iterations

### Importance Calculation

Uses Type II Wald chi-square tests via `car::Anova()`:
1. Calculate chi-square for each predictor
2. Sum chi-squares across predictors
3. Importance % = 100 × (predictor chi-square / total chi-square)

### Missing Data Handling

Default: Complete case analysis (listwise deletion)
- All analysis uses only respondents with complete data on all variables
- Missing data summary provided in output
- Patterns flagged if non-random

### Sample Size Requirements

| Model Type | Minimum | Recommended | Events per Predictor |
|------------|---------|-------------|---------------------|
| Binary | 30 | 100+ | 10-15 |
| Ordinal | 50 | 150+ | 10 per threshold |
| Nominal | 50 | 200+ | 10 per category |

---

## Contact

For support, refer to the main Turas documentation or raise an issue in the project repository.
