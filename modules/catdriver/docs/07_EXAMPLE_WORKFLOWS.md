# Turas Categorical Key Driver Module - Example Workflows

**Version:** 10.0
**Last Updated:** 22 December 2025

This document provides practical step-by-step workflows for common categorical key driver scenarios.

---

## Table of Contents

1. [Binary Outcome: Customer Churn](#workflow-1-customer-churn-binary)
2. [Ordinal Outcome: Employee Satisfaction](#workflow-2-employee-satisfaction-ordinal)
3. [Nominal Outcome: Brand Preference](#workflow-3-brand-preference-nominal)
4. [Handling Missing Data](#workflow-4-handling-missing-data)
5. [Working with Weighted Data](#workflow-5-weighted-analysis)
6. [Interpreting Results](#workflow-6-interpreting-results)
7. [Troubleshooting Guide](#troubleshooting-guide)

---

## Workflow 1: Customer Churn (Binary)

**Scenario:** Identify what drives customer churn (Yes/No outcome).

### Step 1: Prepare Data

**Data file:** `customers.csv`

| customer_id | churn | service_quality | price_satisfaction | tenure_months |
|-------------|-------|-----------------|-------------------|---------------|
| 1001 | Retained | Good | Satisfied | 24 |
| 1002 | Churned | Poor | Dissatisfied | 6 |
| 1003 | Retained | Excellent | Satisfied | 36 |

### Step 2: Create Configuration

**churn_config.xlsx - Settings Sheet:**
```
Setting              | Value
---------------------|---------------------------
analysis_name        | Customer Churn Analysis
data_file            | customers.csv
output_file          | output/churn_drivers.xlsx
outcome_type         | binary
reference_category   | Retained
min_sample_size      | 50
confidence_level     | 0.95
detailed_output      | TRUE
```

**Variables Sheet:**
```
VariableName        | Type    | Label               | Order
--------------------|---------|---------------------|------------------
churn               | Outcome | Churn Status        |
service_quality     | Driver  | Service Quality     | Poor;Fair;Good;Excellent
price_satisfaction  | Driver  | Price Satisfaction  | Dissatisfied;Neutral;Satisfied
tenure_months       | Driver  | Customer Tenure     |
```

### Step 3: Run Analysis

```r
source("modules/catdriver/R/00_main.R")
results <- run_categorical_keydriver("projects/churn/churn_config.xlsx")
```

### Step 4: Review Output

**Console output:**
```
================================================================================
CATEGORICAL KEY DRIVER ANALYSIS
================================================================================
Analysis: Customer Churn Analysis
Model Type: Binary Logistic Regression

Sample: 500 respondents (485 complete cases)
Outcome: Churn Status (Churned vs Retained)

TOP DRIVERS:
1. Service Quality     42.3%  ***
2. Price Satisfaction  31.5%  ***
3. Customer Tenure     26.2%  ***

Model Fit: McFadden R² = 0.32 (Good)
================================================================================
```

**Key findings from Executive Summary:**
> "Service Quality is the strongest predictor of churn (42% importance). Customers with Poor service quality are 5.2 times more likely to churn compared to those with Excellent service."

---

## Workflow 2: Employee Satisfaction (Ordinal)

**Scenario:** Identify what drives satisfaction levels (Low/Medium/High).

### Step 1: Prepare Data

**Data file:** `employee_survey.xlsx`

| employee_id | satisfaction | manager_support | workload | career_growth |
|-------------|--------------|-----------------|----------|---------------|
| E001 | High | High | Moderate | Good |
| E002 | Low | Low | Heavy | Poor |
| E003 | Medium | Medium | Moderate | Fair |

### Step 2: Create Configuration

**satisfaction_config.xlsx - Settings Sheet:**
```
Setting              | Value
---------------------|---------------------------
analysis_name        | Employee Satisfaction Drivers
data_file            | employee_survey.xlsx
output_file          | output/satisfaction_drivers.xlsx
outcome_type         | ordinal
min_sample_size      | 75
confidence_level     | 0.95
detailed_output      | TRUE
```

**Variables Sheet:**
```
VariableName        | Type    | Label               | Order
--------------------|---------|---------------------|------------------
satisfaction        | Outcome | Job Satisfaction    | Low;Medium;High
manager_support     | Driver  | Manager Support     | Low;Medium;High
workload            | Driver  | Workload            | Light;Moderate;Heavy
career_growth       | Driver  | Career Growth       | Poor;Fair;Good
```

### Step 3: Run Analysis

```r
results <- run_categorical_keydriver("projects/hr/satisfaction_config.xlsx")
```

### Step 4: Interpret Ordinal Results

**Key difference from binary:** Ordinal models give cumulative odds ratios.

**Example interpretation:**
> "For each level increase in Manager Support (Low → Medium → High), the odds of being in a higher satisfaction category are multiplied by 2.8."

**Proportional Odds Check:**
```
Proportional Odds Assumption: PASSED
Max OR ratio across thresholds: 1.18 (< 1.25 threshold)
```

---

## Workflow 3: Brand Preference (Nominal)

**Scenario:** Identify what drives choice among 4 brands.

### Step 1: Prepare Data

**Data file:** `brand_survey.csv`

| respondent_id | preferred_brand | quality | price_sensitivity | awareness |
|---------------|-----------------|---------|-------------------|-----------|
| R001 | Brand A | High | Low | High |
| R002 | Brand C | Medium | High | Medium |
| R003 | Brand B | High | Medium | High |

### Step 2: Create Configuration

**brand_config.xlsx - Settings Sheet:**
```
Setting              | Value
---------------------|---------------------------
analysis_name        | Brand Preference Drivers
data_file            | brand_survey.csv
output_file          | output/brand_drivers.xlsx
outcome_type         | nominal
reference_category   | Brand D
min_sample_size      | 100
confidence_level     | 0.95
detailed_output      | TRUE
```

**Variables Sheet:**
```
VariableName        | Type    | Label               | Order
--------------------|---------|---------------------|------
preferred_brand     | Outcome | Brand Preference    |
quality             | Driver  | Quality Perception  | Low;Medium;High
price_sensitivity   | Driver  | Price Sensitivity   | Low;Medium;High
awareness           | Driver  | Brand Awareness     | Low;Medium;High
```

### Step 3: Interpret Multinomial Results

**Multiple comparisons:** Each brand vs. reference (Brand D).

**Example output:**
```
BRAND A vs BRAND D:
  Quality High:  OR = 4.2, p < 0.001 (Very Large effect)

BRAND B vs BRAND D:
  Quality High:  OR = 2.1, p = 0.015 (Large effect)

BRAND C vs BRAND D:
  Price Sensitivity High: OR = 3.5, p < 0.001 (Very Large effect)
```

**Interpretation:**
> "High quality perception strongly drives preference for Brand A over Brand D (4.2x higher odds). High price sensitivity drives preference for Brand C (3.5x higher odds)."

---

## Workflow 4: Handling Missing Data

**Scenario:** Survey data with significant missing values.

### Step 1: Diagnose Missing Data

First run shows missing data warning:
```
WARNING: High missing data rates detected
  career_growth: 25% missing
  compensation:  18% missing
```

### Step 2: Configure Missing Strategies

**Driver_Settings Sheet:**
```
driver          | type        | reference_level | missing_strategy
----------------|-------------|-----------------|------------------
manager_support | ordinal     | Low             | drop_row
workload        | ordinal     | Moderate        | drop_row
career_growth   | categorical |                 | missing_as_level
compensation    | categorical |                 | missing_as_level
```

### Step 3: Re-run Analysis

Now "Missing / Not answered" becomes a category:
```
Factor Patterns - Career Growth:
  Poor:                    15% (n=45)
  Fair:                    35% (n=105)
  Good:                    25% (n=75)
  Missing / Not answered:  25% (n=75)  ← Now included
```

### Step 4: Interpret Missing Category

**If Missing is significant:**
> "Non-response on career growth is associated with lower satisfaction. Those who didn't answer have 0.6x the odds of high satisfaction compared to those reporting Good growth."

**Consider:** Why are respondents not answering? Systematic pattern?

---

## Workflow 5: Weighted Analysis

**Scenario:** Survey data with sampling weights.

### Step 1: Add Weight Variable

**Variables Sheet:**
```
VariableName    | Type    | Label          | Order
----------------|---------|----------------|------
satisfaction    | Outcome | Satisfaction   | Low;Medium;High
department      | Driver  | Department     |
tenure          | Driver  | Tenure         |
survey_weight   | Weight  | Survey Weight  |
```

### Step 2: Verify Weight Variable

```
Data check:
  Weight variable: survey_weight
  Range: 0.5 to 2.5
  Mean: 1.0 (correctly normalized)
  N with valid weights: 485 (100%)
```

### Step 3: Note Limitations

**Current support:**
- Fully supported for binary models
- Limited support for ordinal/multinomial

**If weights critical for non-binary:**
Consider alternative approaches or consult statistician.

---

## Workflow 6: Interpreting Results

### Reading the Importance Summary

**Example output:**
```
Rank | Factor          | Importance % | Chi-Square | P-Value | Sig.  | Effect
-----|-----------------|--------------|------------|---------|-------|--------
1    | Manager Support | 45.2%        | 52.3       | <0.001  | ***   | Large
2    | Workload        | 28.1%        | 32.5       | <0.001  | ***   | Medium
3    | Career Growth   | 18.4%        | 21.3       | <0.001  | ***   | Medium
4    | Compensation    | 8.3%         | 9.6        | 0.002   | **    | Small
```

**Interpretation:**
1. **Manager Support** is the dominant driver (45%)
2. **Workload** is a major driver (28%)
3. **Career Growth** is moderate (18%)
4. **Compensation** is minor but significant (8%)

### Reading the Factor Patterns

**Example for Manager Support:**
```
Category | N    | %    | Low Sat | Med Sat | High Sat | OR    | 95% CI      | Effect
---------|------|------|---------|---------|----------|-------|-------------|--------
Low      | 100  | 20%  | 45%     | 35%     | 20%      | ref   | -           | -
Medium   | 250  | 50%  | 20%     | 45%     | 35%      | 2.4   | (1.8, 3.2)  | Large
High     | 150  | 30%  | 10%     | 30%     | 60%      | 5.1   | (3.5, 7.4)  | V.Large
```

**Interpretation:**
> "Employees with High manager support have 5.1x the odds of being in a higher satisfaction category compared to those with Low support. This is a Very Large effect."

### Reading the Model Summary

```
Model Type: Ordinal Logistic Regression (Proportional Odds)
Original N: 500
Complete N: 485 (97.0%)
McFadden R²: 0.28 (Good fit)
AIC: 842.3
LR Test: χ² = 115.8, df = 6, p < 0.001
```

**Interpretation:**
- Model explains a good amount of variation (R² = 0.28)
- Model significantly better than null (p < 0.001)
- 3% of cases dropped due to missing data

---

## Troubleshooting Guide

### "Config file not found"

**Error:**
```
REFUSED: CONFIG FILE NOT FOUND
Problem: File does not exist: projects/my_config.xlsx
Fix: Check the path and re-run.
```

**Solutions:**
1. Verify file path is correct
2. Use relative path from R working directory
3. Or use absolute path: `/Users/name/projects/my_config.xlsx`

### "Outcome variable not found"

**Error:**
```
REFUSED: VARIABLE NOT FOUND
Problem: Variable 'Satisfaction' not found in data
Fix: Check spelling (case-sensitive) in Variables sheet
```

**Solutions:**
1. Check exact column name in data file
2. Variable names are case-sensitive
3. Check for leading/trailing spaces

### "Model did not converge"

**Warning:**
```
WARNING: Model did not converge after 500 iterations
```

**Solutions:**
1. Reduce number of predictors
2. Collapse rare categories
3. Increase sample size
4. Check for perfect separation

### "Separation detected"

**Error (if brglm2 not installed):**
```
REFUSED: SEPARATION DETECTED
Problem: Perfect/quasi-separation in binary model
Fix: Install brglm2 package or remove problematic predictor
```

**Solutions:**
1. Install brglm2: `install.packages("brglm2")`
2. Or identify and remove problematic predictor
3. Or collapse categories

### "Proportional odds assumption violated"

**Warning:**
```
WARNING: Proportional odds assumption may be violated
Max OR ratio: 1.8 (threshold: 1.5)
```

**Options:**
1. Proceed with caution (minor violation)
2. Switch to multinomial: `outcome_type = nominal`
3. Investigate which predictor violates
4. Consider partial proportional odds model (advanced)

### "Small cells detected"

**Warning:**
```
WARNING: Small cells detected
  Department=Legal + Satisfaction=Low: n=3
  Department=Legal + Satisfaction=High: n=4
```

**Solutions:**
1. Collapse small categories
2. Remove problematic predictor
3. Interpret with caution
4. Get more data

---

## Quick Reference

### Sample Size Guidelines

| Model | Minimum | Recommended | Per Predictor |
|-------|---------|-------------|---------------|
| Binary | 50 | 100+ | 10 events |
| Ordinal | 75 | 150+ | 10 per threshold |
| Nominal | 100 | 200+ | 10 per category |

### Effect Size Interpretation

| Odds Ratio | Effect |
|------------|--------|
| 0.9 - 1.1 | Negligible |
| 0.67-0.9 / 1.1-1.5 | Small |
| 0.5-0.67 / 1.5-2.0 | Medium |
| 0.33-0.5 / 2.0-3.0 | Large |
| <0.33 / >3.0 | Very Large |

### McFadden R² Interpretation

| Value | Fit Quality |
|-------|-------------|
| 0.4+ | Excellent |
| 0.2 - 0.4 | Good |
| 0.1 - 0.2 | Moderate |
| < 0.1 | Limited |

### Importance Interpretation

| % | Category |
|---|----------|
| > 30% | Dominant |
| 15-30% | Major |
| 5-15% | Moderate |
| < 5% | Minor |

---

## Additional Resources

- [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods
- [04_USER_MANUAL.md](04_USER_MANUAL.md) - Complete user guide
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Configuration fields

---

**Part of the Turas Analytics Platform**
