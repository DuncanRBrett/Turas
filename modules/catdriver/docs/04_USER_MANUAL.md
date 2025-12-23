# Turas Categorical Key Driver Module - User Manual

**Version:** 10.0
**Last Updated:** 22 December 2025
**Target Audience:** Market Researchers, Data Analysts, Survey Managers

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Data Preparation](#data-preparation)
3. [Configuration Guide](#configuration-guide)
4. [Running the Analysis](#running-the-analysis)
5. [Understanding Output](#understanding-output)
6. [Interpreting Results](#interpreting-results)
7. [Advanced Features](#advanced-features)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required R Packages

```r
# Core (required)
install.packages(c("MASS", "nnet", "car", "openxlsx"))
```

**Note:** MASS and nnet are typically pre-installed with R.

### Recommended Packages

```r
# Better ordinal regression engine
install.packages("ordinal")

# Handles separation in binary models
install.packages("brglm2")
```

### Optional Packages

```r
# SPSS/Stata file support
install.packages("haven")

# For GUI
install.packages(c("shiny", "shinyFiles"))
```

### System Requirements

- R version 4.0 or higher (4.2+ recommended)
- 4GB+ RAM for standard analyses
- Excel for viewing output files

---

## Data Preparation

### Data Format Requirements

Your survey data must be structured as:
- **Rows:** Individual respondents
- **Columns:** Variables (outcome, drivers, demographics)
- **Format:** CSV, Excel (.xlsx), SPSS (.sav), or Stata (.dta)

### Example Data Structure

| respondent_id | satisfaction | grade | campus | course |
|---------------|--------------|-------|--------|--------|
| 1 | High | A | Cape Town | BCom |
| 2 | Neutral | B | Durban | BSocSci |
| 3 | Low | C | Online | BCom |
| 4 | High | A | Cape Town | LLB |

### Outcome Variable Requirements

**Binary Outcomes (2 categories):**
- Yes/No
- Churned/Retained
- Pass/Fail
- Satisfied/Dissatisfied

**Ordinal Outcomes (3+ ordered categories):**
- Low/Medium/High
- Strongly Disagree → Strongly Agree
- 1/2/3/4/5 (as categories, not numeric)

**Nominal Outcomes (3+ unordered categories):**
- Brand A/B/C/D
- Product 1/2/3/4
- Region North/South/East/West

### Driver Variable Guidelines

**Good Drivers:**
- Categorical variables (demographics, categories)
- Ordinal ratings (1-5 scales treated as ordered)
- Binary flags (Yes/No, Male/Female)

**Avoid:**
- Continuous numeric variables (consider binning)
- High-cardinality variables (50+ categories)
- Variables with many missing values (>50%)

### Sample Size Requirements

| Model Type | Minimum N | Recommended N |
|------------|-----------|---------------|
| Binary | 50 | 100+ |
| Ordinal | 75 | 150+ |
| Nominal | 100 | 200+ |

**Rule of thumb:** At least 10 events per predictor level.

---

## Configuration Guide

### Configuration File Structure

Create an Excel workbook with these sheets:

| Sheet | Purpose | Required |
|-------|---------|----------|
| Settings | Analysis parameters | Yes |
| Variables | Variable definitions | Yes |
| Driver_Settings | Per-driver configuration | Recommended |
| Instructions | Documentation | No |

### Settings Sheet

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| analysis_name | No | "Key Driver Analysis" | Title for reports |
| data_file | **Yes** | - | Path to data file |
| output_file | **Yes** | - | Output Excel path |
| outcome_type | No | auto | auto/binary/ordinal/nominal |
| reference_category | No | First alphabetically | Comparison baseline |
| min_sample_size | No | 30 | Minimum complete cases |
| confidence_level | No | 0.95 | CI level (0.80-0.99) |
| missing_threshold | No | 50 | Warn if % missing exceeds |
| detailed_output | No | TRUE | Include all 6 sheets |

### Variables Sheet

| Column | Required | Description |
|--------|----------|-------------|
| VariableName | **Yes** | Exact column name in data |
| Type | **Yes** | Outcome, Driver, or Weight |
| Label | **Yes** | Human-readable name for reports |
| Order | No | Semicolon-separated ordered categories |

**Type Values:**
- **Outcome:** The variable you're trying to explain (exactly 1)
- **Driver:** Predictor variables (1 or more)
- **Weight:** Survey weight variable (optional, max 1)

### Order Column Examples

| Outcome Type | Order Value |
|--------------|-------------|
| Binary | (leave blank or specify reference first) |
| Ordinal | `Low;Medium;High` |
| Ordinal | `Strongly Disagree;Disagree;Neutral;Agree;Strongly Agree` |
| Nominal | (leave blank) |

### Driver_Settings Sheet (Recommended)

| Column | Required | Description |
|--------|----------|-------------|
| driver | **Yes** | Must match a Driver in Variables sheet |
| type | **Yes** | categorical/ordinal/binary |
| reference_level | No | Specific reference category |
| missing_strategy | No | drop_row/missing_as_level/error_if_missing |

---

## Running the Analysis

### Method 1: Using the GUI (Recommended)

**Step 1: Launch Turas Suite**
```r
setwd("/path/to/Turas")
source("launch_turas.R")
```

**Step 2: Click "Launch Categorical Key Driver"**

**Step 3: Select Project Directory**
- Click "Browse for Project Folder"
- Navigate to your project folder

**Step 4: Select Configuration File**
- The GUI will detect config files automatically
- Or browse to select manually

**Step 5: Click "Run Categorical Key Driver Analysis"**

**Step 6: Review Output**
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

## Understanding Output

### Sheet 1: Executive Summary

Plain-English summary for stakeholders:

- **Sample Information:** N, complete cases, missing data
- **Model Type:** Binary/Ordinal/Multinomial
- **Top Drivers:** Ranked by importance with effect descriptions
- **Key Insights:** Auto-generated findings
- **Model Fit:** R² interpretation
- **Cautions:** Warnings about data quality

### Sheet 2: Importance Summary

| Column | Description |
|--------|-------------|
| Rank | Position by importance |
| Factor | Variable name |
| Label | Display name |
| Importance % | Relative contribution |
| Chi-Square | Test statistic |
| P-Value | Statistical significance |
| Sig. | Stars (*** p<0.001, ** p<0.01, * p<0.05) |
| Effect Size | Small/Medium/Large |

### Sheet 3: Factor Patterns

For each driver:
- Category breakdown (N and %)
- Outcome distribution per category
- Odds ratio vs. reference category
- 95% confidence interval
- Effect size interpretation

Reference category highlighted in green.

### Sheet 4: Model Summary

| Metric | Description |
|--------|-------------|
| Model Type | Binary/Ordinal/Multinomial |
| Original N | Total respondents in data |
| Complete N | Used in analysis |
| McFadden R² | Model explanatory power |
| AIC | Model fit (lower is better) |
| LR Test | Test vs. null model |

### Sheet 5: Odds Ratios (if detailed_output=TRUE)

Full odds ratio table with:
- Factor and comparison category
- Reference category
- Point estimate
- Confidence interval
- P-value
- Effect size label

### Sheet 6: Diagnostics (if detailed_output=TRUE)

| Section | Content |
|---------|---------|
| Sample Size | Adequacy check |
| Missing Data | Rates per variable |
| Small Cells | Category combinations < 5 |
| Convergence | Model estimation status |
| Multicollinearity | VIF values |

---

## Interpreting Results

### Odds Ratios

An odds ratio (OR) compares odds of outcome between groups:

| OR | Interpretation |
|----|----------------|
| OR = 1.0 | No difference from reference |
| OR > 1.0 | Higher odds than reference |
| OR < 1.0 | Lower odds than reference |

**Example Reading:**
> "Grade A students are 4.2x more likely to report High satisfaction compared to Grade D students (OR = 4.2, 95% CI: 2.8-6.2, p < 0.001)"

### Effect Size Guidelines

| Odds Ratio Range | Effect Size |
|------------------|-------------|
| 0.9 - 1.1 | Negligible |
| 0.67-0.9 or 1.1-1.5 | Small |
| 0.5-0.67 or 1.5-2.0 | Medium |
| 0.33-0.5 or 2.0-3.0 | Large |
| <0.33 or >3.0 | Very Large |

### Importance Percentages

| Importance % | Meaning |
|--------------|---------|
| > 30% | Dominant driver - focus here first |
| 15-30% | Major driver - significant influence |
| 5-15% | Moderate driver - worth considering |
| < 5% | Minor driver - limited impact |

### Model Fit (McFadden R²)

| R² Value | Interpretation |
|----------|----------------|
| 0.4+ | Excellent fit |
| 0.2 - 0.4 | Good fit |
| 0.1 - 0.2 | Moderate fit |
| < 0.1 | Limited explanatory power |

**Note:** McFadden R² is typically lower than standard R². Values of 0.2-0.4 are considered very good.

---

## Advanced Features

### Specifying Reference Categories

In the Variables sheet Order column:
- List reference category first
- Example: `Grade D;Grade C;Grade B;Grade A`

Or in Driver_Settings sheet:
- Set `reference_level` to desired category

### Missing Data Strategies

In Driver_Settings sheet, set `missing_strategy`:

| Strategy | Behavior |
|----------|----------|
| drop_row | Remove rows with missing (default) |
| missing_as_level | Create "Missing" category |
| error_if_missing | Refuse if any missing |

### Forcing Outcome Type

Override automatic detection in Settings:

```
outcome_type = ordinal
```

Use when:
- Auto-detection chooses wrong method
- You want ordinal treatment for numeric categories
- Testing different model specifications

### Weighted Analysis

Add a weight variable:

**Variables Sheet:**
| VariableName | Type | Label |
|--------------|------|-------|
| weight_var | Weight | Survey Weight |

**Note:** Only fully supported for binary models.

---

## Troubleshooting

### "Config file not found"

**Cause:** File path in Settings is incorrect.

**Solutions:**
- Use relative paths from config file location
- Or use full absolute paths
- Check for typos in file name

### "Outcome variable not found"

**Cause:** Column name doesn't match data file.

**Solutions:**
- Check exact spelling (case-sensitive)
- Verify variable exists in data
- Check for leading/trailing spaces

### "Insufficient complete cases"

**Cause:** Too much missing data.

**Solutions:**
- Check which variables have high missing rates (see Diagnostics)
- Remove high-missing variables from analysis
- Use `missing_as_level` strategy for drivers
- Investigate systematic missingness

### "Model did not converge"

**Cause:** Too many parameters, small sample, or separation.

**Solutions:**
- Collapse rare categories
- Remove predictors with very unbalanced categories
- Use fewer predictors
- Increase sample size

### "Small cells detected"

**Cause:** Some predictor-outcome combinations have <5 observations.

**Impact:** Unstable estimates, wide confidence intervals.

**Solutions:**
- Collapse similar categories
- Remove problematic predictor
- Interpret results with caution

### "High multicollinearity"

**Cause:** Predictors are highly correlated.

**Solutions:**
- Remove one of correlated predictors
- Combine into composite variable
- Choose most important from correlated set

### "Separation detected"

**Cause:** A predictor perfectly predicts outcome.

**If brglm2 installed:**
- Firth correction applied automatically

**If brglm2 not installed:**
- Analysis refuses (install brglm2 or remove predictor)

---

## Additional Resources

- [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods reference
- [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) - Developer documentation
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Template field reference
- [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) - Practical examples

---

**Part of the Turas Analytics Platform**
