# Turas Key Driver Analysis - Template Reference

**Version:** 10.0
**Last Updated:** 22 December 2025
**Target Audience:** Analysts, Project Managers, Template Configurers

This document provides complete field-by-field reference for the KeyDriver Config Template.

---

## Table of Contents

1. [Overview](#overview)
2. [Template Structure](#template-structure)
3. [Settings Sheet](#settings-sheet)
4. [Variables Sheet](#variables-sheet)
5. [Segments Sheet](#segments-sheet)
6. [StatedImportance Sheet](#statedimportance-sheet)
7. [Output Structure](#output-structure)
8. [Complete Example](#complete-example)
9. [Validation Rules](#validation-rules)

---

## Overview

**File:** `KeyDriver_Config_Template.xlsx`
**Location:** `docs/templates/`

The KeyDriver Config Template configures Key Driver Analysis in Turas. This module determines which drivers have the greatest impact on an outcome variable using multiple statistical methods.

**Key Purpose:** Identify which factors matter most in driving satisfaction, NPS, loyalty, or other key metrics.

---

## Template Structure

| Sheet | Purpose | Required |
|-------|---------|----------|
| Instructions | Usage documentation | No |
| Settings | Analysis configuration | Yes |
| Variables | Variable definitions | Yes |
| Segments | Segment definitions | No |
| StatedImportance | Self-reported importance | No |

---

## Settings Sheet

Configure analysis parameters and file paths.

**Format:** 2 columns (`Setting`, `Value`)

### Core Settings

#### analysis_name

- **Purpose:** Display name for analysis in output
- **Required:** Yes
- **Data Type:** Text
- **Example:** `Brand Health Drivers Q4 2024`

#### data_file

- **Purpose:** Path to respondent-level data file
- **Required:** Yes
- **Data Type:** Text (file path)
- **Valid Formats:** .csv, .xlsx, .xls, .sav, .dta
- **Example:** `/Projects/survey_data.csv`

#### output_file

- **Purpose:** Path and name for results Excel file
- **Required:** No
- **Default:** `keydriver_results.xlsx` in config directory
- **Example:** `/Projects/results/keydriver_results.xlsx`

---

### SHAP Analysis Settings

#### enable_shap

- **Purpose:** Enable SHAP analysis using XGBoost
- **Required:** No
- **Default:** FALSE
- **Valid Values:** TRUE, FALSE
- **Dependencies:** Requires xgboost and shapviz packages

#### n_trees

- **Purpose:** Number of trees in XGBoost model
- **Required:** No
- **Default:** 100
- **Valid Range:** 50-1000
- **Recommendation:** 100 for most cases; increase for large datasets

#### max_depth

- **Purpose:** Maximum tree depth in XGBoost
- **Required:** No
- **Default:** 6
- **Valid Range:** 3-10
- **Recommendation:** 6 balances complexity and overfitting

#### learning_rate

- **Purpose:** XGBoost learning rate (eta)
- **Required:** No
- **Default:** 0.1
- **Valid Range:** 0.01-0.3
- **Recommendation:** Lower for more trees, higher for fewer

#### shap_sample_size

- **Purpose:** Maximum observations for SHAP calculation
- **Required:** No
- **Default:** 1000
- **Valid Range:** 500-5000
- **Impact:** Larger = more stable, slower

#### include_interactions

- **Purpose:** Calculate SHAP interaction values
- **Required:** No
- **Default:** FALSE
- **Valid Values:** TRUE, FALSE
- **Impact:** Significant increase in computation time

---

### Quadrant Analysis Settings

#### enable_quadrant

- **Purpose:** Enable Importance-Performance Analysis quadrant charts
- **Required:** No
- **Default:** FALSE
- **Valid Values:** TRUE, FALSE

#### importance_source

- **Purpose:** Which importance method to use for quadrant chart
- **Required:** No
- **Default:** auto
- **Valid Values:**
  - `auto` - Uses SHAP if enabled, otherwise Shapley
  - `shap` - SHAP importance
  - `shapley` - Shapley values
  - `relative_weights` - Johnson method
  - `regression` - Beta weights
  - `correlation` - Zero-order correlations

#### threshold_method

- **Purpose:** How to determine quadrant boundary lines
- **Required:** No
- **Default:** mean
- **Valid Values:**
  - `mean` - Thresholds at mean importance and performance
  - `median` - Thresholds at median values
  - `midpoint` - Thresholds at scale midpoints
  - `custom` - User-specified (requires additional settings)

#### normalize_axes

- **Purpose:** Normalize axes to 0-100 scale
- **Required:** No
- **Default:** TRUE
- **Valid Values:** TRUE, FALSE
- **Recommendation:** TRUE for cross-study comparability

---

## Variables Sheet

Define the outcome variable, driver variables, and optional weight variable.

**Required Columns:** `VariableName`, `Type`, `Label`

### Column: VariableName

- **Purpose:** Column name in data file
- **Required:** Yes
- **Data Type:** Text
- **Rules:** Must match data file column name EXACTLY (case-sensitive)

### Column: Type

- **Purpose:** Variable role in the analysis
- **Required:** Yes
- **Valid Values:**
  - `Outcome` - Dependent variable (exactly 1 required)
  - `Driver` - Independent variables (3-15 recommended)
  - `Weight` - Survey weight variable (0 or 1 allowed)

### Column: Label

- **Purpose:** Human-readable label for reports
- **Required:** No
- **Default:** Uses VariableName if blank

---

### Variable Type Requirements

| Type | Count | Description |
|------|-------|-------------|
| Outcome | Exactly 1 | Dependent variable (e.g., overall satisfaction) |
| Driver | 3-15 | Independent variables (predictors) |
| Weight | 0 or 1 | Survey weight variable (optional) |

### Example Variables Sheet

```
VariableName           | Type    | Label
overall_satisfaction   | Outcome | Overall Satisfaction
product_quality        | Driver  | Product Quality
customer_service       | Driver  | Customer Service
delivery_speed         | Driver  | Delivery Speed
price_value            | Driver  | Price/Value Ratio
website_ease           | Driver  | Website Ease of Use
brand_reputation       | Driver  | Brand Reputation
survey_weight          | Weight  | Survey Weight
```

---

## Segments Sheet

**Purpose:** Define customer segments for comparison analysis.

**Required:** No

**When to Use:** When you want to compare driver importance across different customer groups (e.g., NPS groups, customer tiers).

### Required Columns

| Column | Description | Example |
|--------|-------------|---------|
| segment_name | Display name for the segment | `Promoters` |
| segment_variable | Variable name in data file | `nps_group` |
| segment_values | Values to include (comma-separated) | `Promoter` or `Gold,Platinum` |

### Example Segments Sheet

```
segment_name   | segment_variable | segment_values
Promoters      | nps_group        | Promoter
Passives       | nps_group        | Passive
Detractors     | nps_group        | Detractor
High Value     | customer_tier    | Gold,Platinum
Standard       | customer_tier    | Standard,Bronze
```

### Segment Filtering Logic

- **Single value:** `segment_values = Promoter` → Filter where nps_group == "Promoter"
- **Multiple values:** `segment_values = Gold,Platinum` → Filter where customer_tier IN ("Gold", "Platinum")

---

## StatedImportance Sheet

**Purpose:** Provide self-reported importance scores for dual-importance analysis.

**Required:** No

**When to Use:** When you have survey data asking customers "How important is X to you?" and want to compare stated vs. derived importance.

### Required Columns

| Column | Description | Example |
|--------|-------------|---------|
| driver | Driver variable name (must match Variables sheet) | `product_quality` |
| stated_importance | Self-reported importance score | `85` |

### Example StatedImportance Sheet

```
driver           | stated_importance
product_quality  | 85
customer_service | 78
delivery_speed   | 65
price_value      | 92
website_ease     | 45
brand_reputation | 70
```

### Dual-Importance Analysis

Compares:
- **Derived importance** - Statistical (what actually drives outcomes)
- **Stated importance** - Self-reported (what customers say matters)

**Reveals:**
- **Hidden Gems:** High derived, low stated (undervalued factors)
- **False Priorities:** High stated, low derived (overvalued factors)

---

## Output Structure

### Standard Output (always included)

| Sheet | Content |
|-------|---------|
| Importance Summary | All importance scores by method |
| Method Rankings | Rank comparison across methods |
| Model Summary | R², VIF diagnostics, coefficients |
| Correlations | Full correlation matrix |
| Charts | Bar chart of importance |
| README | Methodology documentation |

### SHAP Output (when enable_shap = TRUE)

| Sheet | Content |
|-------|---------|
| SHAP_Importance | SHAP-based importance scores |
| SHAP_Model_Diagnostics | XGBoost model performance |
| SHAP_Charts | Beeswarm and waterfall plots |
| SHAP_Segment_Comparison | If segments defined |
| SHAP_Interactions | If include_interactions = TRUE |

### Quadrant Output (when enable_quadrant = TRUE)

| Sheet | Content |
|-------|---------|
| Quadrant_Summary | All drivers with quadrant assignments |
| Action_Table | Prioritized recommendations |
| Gap_Analysis | Importance-performance gaps |
| Quadrant_Charts | IPA quadrant visualization |
| Segment_Comparison | If segments defined |

---

## Complete Example

### Settings Sheet

```
Setting              | Value
analysis_name        | Customer Satisfaction Drivers Q4 2024
data_file            | data/survey_q4.csv
output_file          | results/satisfaction_drivers.xlsx
enable_shap          | TRUE
enable_quadrant      | TRUE
n_trees              | 100
max_depth            | 6
threshold_method     | mean
normalize_axes       | TRUE
```

### Variables Sheet

```
VariableName           | Type    | Label
overall_satisfaction   | Outcome | Overall Satisfaction
product_quality        | Driver  | Product Quality
customer_service       | Driver  | Customer Service
delivery_speed         | Driver  | Delivery Speed
price_value            | Driver  | Price/Value Ratio
website_ease           | Driver  | Website Ease of Use
survey_weight          | Weight  | Survey Weight
```

### Segments Sheet (Optional)

```
segment_name | segment_variable | segment_values
Promoters    | nps_category     | Promoter
Detractors   | nps_category     | Detractor
```

### StatedImportance Sheet (Optional)

```
driver           | stated_importance
product_quality  | 85
customer_service | 78
delivery_speed   | 65
price_value      | 92
website_ease     | 45
```

---

## Validation Rules

### Settings Validation

| Setting | Validation |
|---------|------------|
| analysis_name | Non-empty text |
| data_file | File must exist, valid format |
| output_file | Valid path, .xlsx extension |
| enable_shap | TRUE or FALSE |
| enable_quadrant | TRUE or FALSE |
| n_trees | Integer 50-1000 |
| max_depth | Integer 3-10 |
| learning_rate | Numeric 0.01-0.3 |
| shap_sample_size | Integer 500-5000 |
| threshold_method | One of: mean, median, midpoint, custom |

### Variables Validation

| Rule | Error |
|------|-------|
| Exactly 1 Outcome | "Must have exactly one Outcome variable" |
| At least 3 Drivers | "Need at least 3 Driver variables" |
| Maximum 15 Drivers | "Maximum 15 drivers for Shapley calculation" |
| At most 1 Weight | "Maximum one Weight variable allowed" |
| Names match data | "Variable 'X' not found in data file" |
| Numeric variables | "Variable 'X' must be numeric" |

### Sample Size Validation

```
Minimum n = max(30, 10 × number_of_drivers)

Example:
- 5 drivers → need ≥ 50 complete cases
- 10 drivers → need ≥ 100 complete cases
- 15 drivers → need ≥ 150 complete cases
```

### Multicollinearity Validation

| VIF | Status | Message |
|-----|--------|---------|
| < 5 | OK | No warning |
| 5-10 | Warning | "Moderate multicollinearity for: X" |
| > 10 | Warning | "High multicollinearity for: X. Consider removing." |

---

## Template File Location

The template file is included at:
- `modules/keydriver/docs/templates/KeyDriver_Config_Template.xlsx`

Copy and rename for your project.
