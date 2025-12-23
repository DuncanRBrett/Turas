# Turas Categorical Key Driver Module - Template Reference

**Version:** 10.0
**Last Updated:** 22 December 2025
**Target Audience:** Analysts, Project Managers, Template Configurers

This document provides complete field-by-field reference for the CatDriver configuration template.

---

## Table of Contents

1. [Overview](#overview)
2. [Settings Sheet](#settings-sheet)
3. [Variables Sheet](#variables-sheet)
4. [Driver_Settings Sheet](#driver_settings-sheet)
5. [Complete Examples](#complete-examples)
6. [Validation Rules](#validation-rules)

---

## Overview

### Template Location

**File:** `docs/templates/CatDriver_Config_Template.xlsx`

### Sheet Structure

| Sheet | Purpose | Required |
|-------|---------|----------|
| Instructions | Usage documentation | No |
| Settings | Analysis parameters | Yes |
| Variables | Variable definitions | Yes |
| Driver_Settings | Per-driver configuration | Recommended |

---

## Settings Sheet

### Core Settings

#### analysis_name

- **Purpose:** Title for reports and output
- **Required:** No
- **Data Type:** Text
- **Default:** `Key Driver Analysis`
- **Example:** `Customer Churn Drivers Q4 2025`

#### data_file

- **Purpose:** Path to survey data file
- **Required:** Yes
- **Data Type:** Text (file path)
- **Valid Formats:** .csv, .xlsx, .xls, .sav, .dta
- **Example:** `data/survey_responses.csv`
- **Notes:** Relative to config file location or absolute path

#### output_file

- **Purpose:** Path for Excel output file
- **Required:** Yes
- **Data Type:** Text (file path)
- **Example:** `output/churn_drivers.xlsx`
- **Notes:** Directory must exist

---

### Model Settings

#### outcome_type

- **Purpose:** Override automatic outcome type detection
- **Required:** No
- **Default:** `auto`
- **Valid Values:**
  - `auto` - Detect from data
  - `binary` - Force binary logistic
  - `ordinal` - Force ordinal logistic
  - `nominal` - Force multinomial logistic
- **When to Override:**
  - Auto-detection makes wrong choice
  - Testing different model specifications
  - Ordinal treatment of numeric categories

#### reference_category

- **Purpose:** Baseline category for comparisons
- **Required:** No
- **Default:** First category alphabetically
- **Example:** `Grade D` or `Churned`
- **Notes:** Must exist in outcome variable

---

### Statistical Settings

#### min_sample_size

- **Purpose:** Minimum complete cases required
- **Required:** No
- **Data Type:** Integer
- **Default:** `30`
- **Valid Values:** 1 or greater
- **Notes:** Analysis refuses if below threshold

#### confidence_level

- **Purpose:** Confidence level for intervals
- **Required:** No
- **Data Type:** Decimal
- **Default:** `0.95`
- **Valid Values:** 0.80 to 0.99
- **Example:** `0.95` for 95% confidence intervals

#### missing_threshold

- **Purpose:** Warning threshold for missing data
- **Required:** No
- **Data Type:** Integer (percentage)
- **Default:** `50`
- **Valid Values:** 0 to 100
- **Notes:** Warns if any variable exceeds this %

---

### Output Settings

#### detailed_output

- **Purpose:** Include all 6 sheets or just 4
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `TRUE`
- **When FALSE:** Omits Odds Ratios and Diagnostics sheets
- **When TRUE:** Full 6-sheet output

---

## Variables Sheet

### Column Definitions

#### VariableName

- **Purpose:** Column name in data file
- **Required:** Yes
- **Data Type:** Text
- **Validation:** Must exactly match column name (case-sensitive)
- **Example:** `employment_satisfaction`

#### Type

- **Purpose:** Variable role in analysis
- **Required:** Yes
- **Valid Values:**
  - `Outcome` - Dependent variable (exactly 1)
  - `Driver` - Predictor variable (1 or more)
  - `Weight` - Survey weight (0 or 1)

#### Label

- **Purpose:** Display name for reports
- **Required:** Yes
- **Data Type:** Text
- **Example:** `Employment Satisfaction`

#### Order

- **Purpose:** Category ordering for ordinal variables
- **Required:** No (but recommended for ordinal outcomes)
- **Format:** Semicolon-separated, low to high
- **Examples:**
  - `Low;Medium;High`
  - `Strongly Disagree;Disagree;Neutral;Agree;Strongly Agree`
  - `1;2;3;4;5`
  - `Grade D;Grade C;Grade B;Grade A`

---

## Driver_Settings Sheet

### When to Use

- Specify exact variable types
- Set specific reference levels
- Configure missing data handling

### Column Definitions

#### driver

- **Purpose:** Variable name to configure
- **Required:** Yes
- **Validation:** Must match a Driver in Variables sheet
- **Example:** `academic_grade`

#### type

- **Purpose:** How to treat the variable
- **Required:** Yes
- **Valid Values:**
  - `categorical` / `nominal` - Unordered factor
  - `ordinal` - Ordered factor (treatment contrasts)
  - `binary` - Two-level factor

#### reference_level

- **Purpose:** Baseline for comparisons
- **Required:** No
- **Default:** First level alphabetically
- **Example:** `Grade D` or `No`
- **Notes:** Must exist in data

#### missing_strategy

- **Purpose:** How to handle missing values
- **Required:** No
- **Default:** `drop_row`
- **Valid Values:**
  - `drop_row` - Remove rows with missing
  - `missing_as_level` - Create "Missing" category
  - `error_if_missing` - Refuse if any missing

---

## Complete Examples

### Example 1: Binary Outcome (Customer Churn)

**Settings Sheet:**
```
Setting              | Value
---------------------|---------------------------
analysis_name        | Customer Churn Drivers
data_file            | data/customers.csv
output_file          | output/churn_analysis.xlsx
outcome_type         | auto
reference_category   | Retained
min_sample_size      | 50
confidence_level     | 0.95
detailed_output      | TRUE
```

**Variables Sheet:**
```
VariableName         | Type    | Label              | Order
---------------------|---------|--------------------|---------
churn_status         | Outcome | Churn Status       |
service_quality      | Driver  | Service Quality    | Poor;Fair;Good;Excellent
price_satisfaction   | Driver  | Price Satisfaction |
tenure_years         | Driver  | Customer Tenure    |
support_contacts     | Driver  | Support Contacts   |
```

### Example 2: Ordinal Outcome (Employee Satisfaction)

**Settings Sheet:**
```
Setting              | Value
---------------------|---------------------------
analysis_name        | Employee Satisfaction Drivers
data_file            | data/employee_survey.xlsx
output_file          | output/satisfaction_drivers.xlsx
outcome_type         | ordinal
min_sample_size      | 75
confidence_level     | 0.95
detailed_output      | TRUE
```

**Variables Sheet:**
```
VariableName         | Type    | Label              | Order
---------------------|---------|--------------------|---------
satisfaction_level   | Outcome | Job Satisfaction   | Low;Neutral;High
manager_support      | Driver  | Manager Support    | Low;Medium;High
workload             | Driver  | Workload           | Light;Moderate;Heavy
career_growth        | Driver  | Career Growth      |
compensation         | Driver  | Compensation       |
```

**Driver_Settings Sheet:**
```
driver              | type        | reference_level | missing_strategy
--------------------|-------------|-----------------|------------------
manager_support     | ordinal     | Low             | drop_row
workload            | ordinal     | Moderate        | drop_row
career_growth       | categorical |                 | missing_as_level
compensation        | categorical |                 | drop_row
```

### Example 3: Nominal Outcome (Brand Preference)

**Settings Sheet:**
```
Setting              | Value
---------------------|---------------------------
analysis_name        | Brand Preference Drivers
data_file            | data/brand_survey.csv
output_file          | output/brand_drivers.xlsx
outcome_type         | nominal
reference_category   | Brand D
min_sample_size      | 100
confidence_level     | 0.95
detailed_output      | TRUE
```

**Variables Sheet:**
```
VariableName         | Type    | Label              | Order
---------------------|---------|--------------------|---------
preferred_brand      | Outcome | Brand Preference   |
quality_perception   | Driver  | Quality Perception | Low;Medium;High
price_sensitivity    | Driver  | Price Sensitivity  | Low;Medium;High
brand_awareness      | Driver  | Brand Awareness    |
recommendation       | Driver  | Recommendation     |
```

---

## Validation Rules

### Settings Validation

| Setting | Rule |
|---------|------|
| data_file | File must exist |
| output_file | Directory must exist |
| outcome_type | Must be: auto, binary, ordinal, nominal |
| reference_category | Must exist in outcome variable |
| min_sample_size | Integer ≥ 1 |
| confidence_level | 0 < value < 1 |
| missing_threshold | 0 to 100 |
| detailed_output | TRUE or FALSE |

### Variables Validation

| Rule | Error Message |
|------|---------------|
| Exactly 1 Outcome | "Must have exactly one Outcome variable" |
| At least 1 Driver | "Must have at least one Driver variable" |
| At most 1 Weight | "Can have at most one Weight variable" |
| VariableName in data | "Variable 'X' not found in data" |
| Type valid | "Invalid Type 'X', must be Outcome/Driver/Weight" |
| Label non-empty | "Label required for variable 'X'" |

### Driver_Settings Validation

| Rule | Error Message |
|------|---------------|
| driver matches Variables | "Driver 'X' not found in Variables sheet" |
| type valid | "Invalid type 'X', must be categorical/ordinal/binary" |
| reference_level in data | "Reference level 'X' not found in data" |
| missing_strategy valid | "Invalid strategy 'X'" |

### Data Validation

| Rule | Action |
|------|--------|
| Complete cases < min_sample_size | Refuse |
| Missing > missing_threshold | Warning |
| Outcome has < 2 categories | Refuse |
| Outcome has > 10 categories | Warning |
| Driver has > 20 categories | Warning |
| Cell count < 5 | Warning |

---

## Output Structure

### Standard Output (detailed_output = TRUE)

| Sheet | Content |
|-------|---------|
| Executive Summary | Plain-English findings |
| Importance Summary | Driver rankings |
| Factor Patterns | Category breakdowns |
| Model Summary | Fit statistics |
| Odds Ratios | Detailed comparisons |
| Diagnostics | Data quality checks |

### Minimal Output (detailed_output = FALSE)

| Sheet | Content |
|-------|---------|
| Executive Summary | Plain-English findings |
| Importance Summary | Driver rankings |
| Factor Patterns | Category breakdowns |
| Model Summary | Fit statistics |

---

## Template File Location

Template located at: `modules/catdriver/docs/templates/CatDriver_Config_Template.xlsx`

Copy and rename for your project.

---

**Part of the Turas Analytics Platform**
