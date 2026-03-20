# Turas Key Driver Analysis - Template Reference

**Version:** 10.4
**Last Updated:** 20 March 2026
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
7. [CustomSlides Sheet](#customslides-sheet)
8. [Insights Sheet](#insights-sheet)
9. [Output Structure](#output-structure)
9. [Complete Example](#complete-example)
10. [Validation Rules](#validation-rules)

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
| CustomSlides | Qualitative slides for HTML report | No |
| Insights | Pre-populated analyst insights for HTML sections | No |

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

### Bootstrap Analysis Settings

#### enable_bootstrap

- **Purpose:** Enable bootstrap confidence intervals for importance scores
- **Required:** No
- **Default:** FALSE
- **Valid Values:** TRUE, FALSE
- **NEW in v10.3**

#### bootstrap_iterations

- **Purpose:** Number of bootstrap resamples
- **Required:** No
- **Default:** 1000
- **Valid Range:** 100-10000
- **Recommendation:** 1000 for final analysis; 200 for exploratory work
- **Impact:** Higher = more stable CIs, but slower runtime

#### bootstrap_ci_level

- **Purpose:** Confidence level for the bootstrap interval
- **Required:** No
- **Default:** 0.95
- **Valid Range:** 0.80-0.99
- **Common Values:** 0.90 (90% CI), 0.95 (95% CI), 0.99 (99% CI)

---

### HTML Report Settings

#### enable_html_report

- **Purpose:** Generate an interactive HTML report alongside Excel output
- **Required:** No
- **Default:** FALSE
- **Valid Values:** TRUE, FALSE
- **Dependencies:** Requires htmltools package
- **Note:** Can also be enabled via the Shiny GUI "Generate HTML Report" checkbox, which overrides this config setting
- **NEW in v10.3**

#### brand_colour

- **Purpose:** Primary brand colour for HTML report styling (header bar, chart bars, accents)
- **Required:** No
- **Default:** #323367 (dark navy)
- **Data Type:** Hex colour code (e.g., `#3b82f6`)

#### accent_colour

- **Purpose:** Secondary accent colour for HTML report charts and highlights
- **Required:** No
- **Default:** #f59e0b (amber)
- **Data Type:** Hex colour code

#### report_title

- **Purpose:** Custom title displayed in the HTML report header
- **Required:** No
- **Default:** Analysis name derived from config file
- **Data Type:** Text string

---

### HTML Report Section Visibility

These settings control which sections appear in the HTML report. All default to TRUE. Set to FALSE to hide a section. Sections with no data are automatically hidden regardless of these settings.

#### html_show_exec_summary

- **Purpose:** Show the Executive Summary section
- **Default:** TRUE

#### html_show_importance

- **Purpose:** Show the Driver Importance section (bar chart and table)
- **Default:** TRUE

#### html_show_methods

- **Purpose:** Show the Method Comparison section
- **Default:** TRUE

#### html_show_effect_sizes

- **Purpose:** Show the Effect Sizes section
- **Default:** TRUE

#### html_show_correlations

- **Purpose:** Show the Correlation Matrix section
- **Default:** TRUE

#### html_show_quadrant

- **Purpose:** Show the Quadrant Analysis (IPA) section
- **Default:** TRUE
- **Note:** Also requires `enable_quadrant = TRUE` for quadrant data to be computed

#### html_show_shap

- **Purpose:** Show the SHAP Analysis section
- **Default:** TRUE
- **Note:** Also requires `enable_shap = TRUE` for SHAP data to be computed

#### html_show_diagnostics

- **Purpose:** Show the Model Diagnostics section (VIF, R², residuals)
- **Default:** TRUE

#### html_show_bootstrap

- **Purpose:** Show the Bootstrap Confidence Intervals section
- **Default:** TRUE
- **Note:** Also requires `enable_bootstrap = TRUE` for bootstrap data to be computed

#### html_show_segments

- **Purpose:** Show the Segment Comparison section
- **Default:** TRUE
- **Note:** Also requires segments to be defined in the Segments config sheet

#### html_show_guide

- **Purpose:** Show the built-in Interpretation Guide section
- **Default:** TRUE

#### html_show_elastic_net

- **Purpose:** Show the Elastic Net section
- **Default:** TRUE
- **Note:** Also requires `enable_elastic_net = TRUE` for elastic net data to be computed
- **NEW in v10.4**

#### html_show_nca

- **Purpose:** Show the Necessary Condition Analysis section
- **Default:** TRUE
- **Note:** Also requires `enable_nca = TRUE` for NCA data to be computed
- **NEW in v10.4**

#### html_show_dominance

- **Purpose:** Show the Dominance Analysis section
- **Default:** TRUE
- **Note:** Also requires `enable_dominance = TRUE` for dominance data to be computed
- **NEW in v10.4**

#### html_show_gam

- **Purpose:** Show the GAM Nonlinear Effects section
- **Default:** TRUE
- **Note:** Also requires `enable_gam = TRUE` for GAM data to be computed
- **NEW in v10.4**

---

### HTML Report Display Options

#### correlation_display

- **Purpose:** Control how the correlation matrix is displayed
- **Required:** No
- **Default:** heatmap
- **Valid Values:** heatmap, table, both
- **Note:** "heatmap" shows the colour-coded matrix only; "table" shows the numeric table only; "both" shows both

#### bootstrap_display

- **Purpose:** Control how bootstrap confidence intervals are displayed
- **Required:** No
- **Default:** summary
- **Valid Values:** summary, full, table
- **Note:** "summary" shows the forest plot chart only; "table" shows the CI table only; "full" shows both chart and table

---

### Effect Size Settings

#### effect_size_method

- **Purpose:** Method for calculating effect size benchmarks
- **Required:** No
- **Default:** cohen_f2
- **Valid Values:** cohen_f2, standardized_beta, correlation
- **NEW in v10.3**

---

### Elastic Net Settings (NEW v10.4)

#### enable_elastic_net

- **Purpose:** Enable Elastic Net variable selection via glmnet
- **Required:** No
- **Default:** FALSE
- **Valid Values:** TRUE, FALSE
- **Dependencies:** Requires glmnet >= 4.1.0 package
- **NEW in v10.4**

#### elastic_net_alpha

- **Purpose:** Elastic Net mixing parameter controlling the balance between L1 (lasso) and L2 (ridge) penalties
- **Required:** No
- **Default:** 0.5
- **Valid Range:** 0-1
- **Key Values:**
  - `0` - Pure ridge regression (L2 only)
  - `0.5` - Balanced elastic net (default)
  - `1` - Pure lasso (L1 only)

#### elastic_net_nfolds

- **Purpose:** Number of cross-validation folds for Elastic Net lambda selection
- **Required:** No
- **Default:** 10
- **Valid Range:** 3-20
- **Recommendation:** 10 for most cases; reduce to 5 for small samples

---

### NCA Settings (NEW v10.4)

#### enable_nca

- **Purpose:** Enable Necessary Condition Analysis (NCA)
- **Required:** No
- **Default:** FALSE
- **Valid Values:** TRUE, FALSE
- **Dependencies:** Requires NCA >= 3.2.0 package
- **NEW in v10.4**

---

### Dominance Analysis Settings (NEW v10.4)

#### enable_dominance

- **Purpose:** Enable Dominance Analysis for R-squared decomposition
- **Required:** No
- **Default:** FALSE
- **Valid Values:** TRUE, FALSE
- **Dependencies:** Requires domir >= 1.0.0 package
- **NEW in v10.4**

---

### GAM Settings (NEW v10.4)

#### enable_gam

- **Purpose:** Enable GAM (Generalized Additive Model) nonlinear effects analysis
- **Required:** No
- **Default:** FALSE
- **Valid Values:** TRUE, FALSE
- **Dependencies:** Requires mgcv package (recommended, ships with R)
- **NEW in v10.4**

#### gam_k

- **Purpose:** Basis dimension for GAM smooth terms (controls flexibility of the smoothing spline)
- **Required:** No
- **Default:** 5
- **Valid Range:** 3-20
- **Recommendation:** 5 for most cases; increase for large datasets with complex nonlinear patterns

---

### VIF Threshold Settings (NEW v10.4)

#### vif_moderate_threshold

- **Purpose:** VIF threshold at which a moderate multicollinearity warning is raised
- **Required:** No
- **Default:** 5
- **Data Type:** Numeric
- **NEW in v10.4**

#### vif_high_threshold

- **Purpose:** VIF threshold at which a high multicollinearity warning is raised
- **Required:** No
- **Default:** 10
- **Data Type:** Numeric
- **NEW in v10.4**

---

### XGBoost Tuning (Advanced)

#### cv_nfold

- **Purpose:** Number of cross-validation folds for XGBoost tuning
- **Required:** No
- **Default:** 5
- **Valid Range:** 3-10

#### early_stopping_rounds

- **Purpose:** Early stopping rounds for XGBoost training
- **Required:** No
- **Default:** 20
- **Valid Range:** 5-50

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

## CustomSlides Sheet

**Purpose:** Add qualitative commentary slides to the HTML report's Pinned Views panel.

**Required:** No

**When to Use:** When you want to include analyst notes, methodology descriptions, contextual commentary, or any qualitative content alongside the auto-generated analytical sections in the HTML report.

**NEW in v10.4**

### Required Columns

| Column | Description | Example |
|--------|-------------|---------|
| slide_title | Display title for the slide | `Key Takeaways` |
| slide_content | Slide body text (supports markdown formatting) | `## Summary\n- Finding 1\n- Finding 2` |

### Optional Columns

| Column | Description | Example |
|--------|-------------|---------|
| slide_image | File path to an image to embed in the slide | `images/context_chart.png` |
| slide_order | Integer controlling display order in the Pinned Views panel | `1` |

### Example CustomSlides Sheet

```
slide_title      | slide_content                              | slide_image              | slide_order
Key Takeaways    | Service quality dominates all segments     |                          | 1
Methodology      | Analysis uses 5 complementary methods...   |                          | 2
Market Context   | Q4 saw increased competitive pressure...   | images/market_trend.png  | 3
```

### Notes

- Slides appear in the Pinned Views panel of the HTML report
- If `slide_order` is omitted, slides appear in the order defined in the sheet
- The `slide_content` column supports basic markdown: headings, bullet lists, bold, italic
- Image paths are resolved relative to the config file directory

---

## Insights Sheet

**Purpose:** Pre-populate analyst insights in the HTML report. Each row maps to a report section's insight area, so insights can be prepared in the config file before the report is generated.

**Status:** Optional (NEW v10.4)

### Columns

| Column | Required | Type | Description |
|--------|----------|------|-------------|
| `section` | Yes | Text | Section key matching the HTML report section (see valid keys below) |
| `insight_text` | Yes | Text | The analyst insight text to display in that section |
| `image_path` | No | File path | Path to an image file (PNG, JPG, GIF, SVG) to embed alongside the insight |

### Valid Section Keys

| Key | Report Section |
|-----|---------------|
| `exec-summary` | Executive Summary |
| `importance` | Driver Importance |
| `method-comparison` | Method Comparison |
| `effect-sizes` | Effect Sizes |
| `correlations` | Correlation Matrix |
| `quadrant` | Importance-Performance Quadrant |
| `shap-summary` | SHAP Analysis |
| `diagnostics` | Diagnostics |
| `bootstrap-ci` | Bootstrap Confidence Intervals |
| `segment-comparison` | Segment Comparison |
| `elastic-net` | Elastic Net |
| `nca` | Necessary Condition Analysis |
| `dominance` | Dominance Analysis |
| `gam` | Nonlinear Effects (GAM) |

### Example Insights Sheet

```
section          | insight_text                                           | image_path
exec-summary     | Customer service is the dominant driver at 32%...      |
importance       | Top 3 drivers explain 65% of variance.                 | images/importance_chart.png
quadrant         | Three drivers fall in the Invest quadrant.              |
```

### Notes

- Image paths are resolved relative to the working directory (typically the project root)
- Images are base64-encoded and embedded inline in the HTML report (no external file dependencies)
- Supported image formats: PNG, JPG/JPEG, GIF, SVG
- If an image file is not found, the insight text still appears without the image
- Sections without matching rows in the Insights sheet show the default "+ Add Insight" button
- Sections with pre-populated insights auto-expand and show an "Edit Insight" button instead

---

## Output Structure

### Standard Output (always included)

| Sheet | Content |
|-------|---------|
| Importance Summary | All importance scores by method |
| Method Rankings | Rank comparison across methods |
| Model Summary | R², VIF diagnostics, coefficients |
| Correlations | Full correlation matrix |
| Effect Sizes | Effect size classification and interpretation (NEW v10.3) |
| Executive Summary | Plain-English findings and recommendations (NEW v10.3) |
| Charts | Bar chart of importance |
| Run Status | TRS run status details |
| README | Methodology documentation |

### Bootstrap Output (when enable_bootstrap = TRUE, NEW v10.3)

| Sheet | Content |
|-------|---------|
| Bootstrap_CIs | Confidence intervals per driver per method |
| Bootstrap_Summary | Point estimates, SE, CI bounds |

### HTML Report Output (when enable_html_report = TRUE, NEW v10.3)

| File | Content |
|------|---------|
| keydriver_report.html | Self-contained interactive HTML report |

### Elastic Net Output (when enable_elastic_net = TRUE, NEW v10.4)

| Sheet | Content |
|-------|---------|
| Elastic_Net | Selected variables, coefficients, lambda values |

### NCA Output (when enable_nca = TRUE, NEW v10.4)

| Sheet | Content |
|-------|---------|
| NCA_Results | Necessary condition ceiling, effect sizes per driver |

### Dominance Output (when enable_dominance = TRUE, NEW v10.4)

| Sheet | Content |
|-------|---------|
| Dominance_Analysis | General dominance statistics, R-squared shares |

### GAM Output (when enable_gam = TRUE, NEW v10.4)

| Sheet | Content |
|-------|---------|
| GAM_Effects | Smooth term significance, effective degrees of freedom, nonlinearity flags |

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
Setting                | Value
analysis_name          | Customer Satisfaction Drivers Q4 2024
data_file              | data/survey_q4.csv
output_file            | results/satisfaction_drivers.xlsx
enable_shap            | TRUE
enable_quadrant        | TRUE
enable_bootstrap       | TRUE
enable_html_report     | TRUE
n_trees                | 100
max_depth              | 6
threshold_method       | mean
normalize_axes         | TRUE
bootstrap_iterations   | 1000
bootstrap_ci_level     | 0.95
brand_colour           | #323367
accent_colour          | #f59e0b
enable_elastic_net     | FALSE
enable_nca             | FALSE
enable_dominance       | FALSE
enable_gam             | FALSE
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
| enable_bootstrap | TRUE or FALSE |
| enable_html_report | TRUE or FALSE |
| n_trees | Integer 50-1000 |
| max_depth | Integer 3-10 |
| learning_rate | Numeric 0.01-0.3 |
| shap_sample_size | Integer 500-5000 |
| threshold_method | One of: mean, median, midpoint, custom |
| bootstrap_iterations | Integer 100-10000 |
| bootstrap_ci_level | Numeric 0.80-0.99 |
| brand_colour | Valid hex colour code |
| accent_colour | Valid hex colour code |
| effect_size_method | One of: cohen_f2, standardized_beta, correlation |
| cv_nfold | Integer 3-10 |
| early_stopping_rounds | Integer 5-50 |
| enable_elastic_net | TRUE or FALSE |
| elastic_net_alpha | Numeric 0-1 |
| elastic_net_nfolds | Integer 3-20 |
| enable_nca | TRUE or FALSE |
| enable_dominance | TRUE or FALSE |
| enable_gam | TRUE or FALSE |
| gam_k | Integer 3-20 |
| vif_moderate_threshold | Numeric > 0 |
| vif_high_threshold | Numeric > vif_moderate_threshold |

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
