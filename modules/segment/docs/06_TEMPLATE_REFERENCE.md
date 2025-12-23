# Turas Segmentation Module - Template Reference

**Version:** 10.0
**Last Updated:** 22 December 2025
**Target Audience:** Analysts, Project Managers, Template Configurers

This document provides complete field-by-field reference for the Segmentation configuration templates.

---

## Table of Contents

1. [Overview](#overview)
2. [Segment Config Template](#segment-config-template)
3. [Variable Selection Config Template](#variable-selection-config-template)
4. [Output Structure](#output-structure)
5. [Complete Examples](#complete-examples)
6. [Validation Rules](#validation-rules)

---

## Overview

### Available Templates

| Template | Purpose | Location |
|----------|---------|----------|
| Segment_Config_Template.xlsx | Main segmentation configuration | docs/templates/ |
| VarSel_Config_Template.xlsx | Variable selection configuration | docs/templates/ |

### Template Structure

Both templates use a consistent structure:

| Sheet | Purpose | Required |
|-------|---------|----------|
| Instructions | Usage documentation | No |
| Config | All analysis settings | Yes |

---

## Segment Config Template

**File:** `Segment_Config_Template.xlsx`

The main template for configuring customer segmentation analysis.

### Core Settings

#### data_file

- **Purpose:** Path to survey data file
- **Required:** Yes
- **Data Type:** Text (file path)
- **Valid Formats:** .csv, .xlsx, .xls, .sav, .dta
- **Example:** `/Projects/survey_data.csv`

#### data_sheet

- **Purpose:** Sheet name in Excel file
- **Required:** No (only for Excel files)
- **Data Type:** Text
- **Default:** First sheet
- **Example:** `Data`

#### id_variable

- **Purpose:** Column name for respondent ID
- **Required:** Yes
- **Data Type:** Text (column name)
- **Example:** `ResponseID`

#### clustering_vars

- **Purpose:** Variables to use for segmentation
- **Required:** Yes
- **Data Type:** Text (comma-separated column names)
- **Example:** `Q02,Q03,Q04,Q05,Q06,Q07,Q08`
- **Notes:**
  - Must be numeric variables
  - Should be attitudes/needs (not demographics)
  - 5-15 variables recommended

#### profile_vars

- **Purpose:** Variables for profiling segments (not used in clustering)
- **Required:** No
- **Data Type:** Text (comma-separated column names)
- **Default:** All non-clustering variables
- **Example:** `age,tenure_years,gender`

---

### Clustering Algorithm Settings

#### method

- **Purpose:** Clustering algorithm
- **Required:** No
- **Default:** `kmeans`
- **Valid Values:** `kmeans`

#### k_fixed

- **Purpose:** Fixed number of segments
- **Required:** No (blank = exploration mode)
- **Data Type:** Integer or blank
- **Valid Values:** 2-10 or blank
- **Logic:**
  - **Blank** = Exploration mode (tests k_min to k_max)
  - **Number** = Final mode (uses this k)
- **Example:** `4` or leave blank

#### k_min

- **Purpose:** Minimum k to test (exploration mode)
- **Required:** Only for exploration mode
- **Data Type:** Integer
- **Valid Values:** 2-10
- **Default:** `3`

#### k_max

- **Purpose:** Maximum k to test (exploration mode)
- **Required:** Only for exploration mode
- **Data Type:** Integer
- **Valid Values:** 2-10
- **Default:** `6`

#### nstart

- **Purpose:** Number of random starts for k-means
- **Required:** No
- **Data Type:** Integer
- **Valid Values:** 1-200
- **Default:** `25`
- **Notes:** Higher = more stable but slower

#### seed

- **Purpose:** Random seed for reproducibility
- **Required:** No
- **Data Type:** Integer
- **Default:** `123`

---

### Data Handling Settings

#### missing_data

- **Purpose:** How to handle missing values
- **Required:** No
- **Default:** `listwise_deletion`
- **Valid Values:**
  - `listwise_deletion` - Remove cases with any missing
  - `mean_imputation` - Replace with variable mean
  - `median_imputation` - Replace with variable median
  - `refuse` - Error if any missing found

#### missing_threshold

- **Purpose:** Max % missing allowed per variable
- **Required:** No
- **Data Type:** Numeric (0-100)
- **Default:** `15`

#### standardize

- **Purpose:** Standardize variables before clustering
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `TRUE`
- **Notes:** Recommended TRUE for equal weighting

#### min_segment_size_pct

- **Purpose:** Minimum % of sample per segment
- **Required:** No
- **Data Type:** Numeric (0-50)
- **Default:** `10`
- **Notes:** Warns if any segment falls below threshold

---

### Outlier Detection Settings

#### outlier_detection

- **Purpose:** Enable outlier detection
- **Required:** No
- **Default:** `FALSE`
- **Valid Values:** TRUE, FALSE

#### outlier_method

- **Purpose:** Detection algorithm
- **Required:** Only if outlier_detection = TRUE
- **Default:** `zscore`
- **Valid Values:**
  - `zscore` - Flag if |z| > threshold
  - `mahalanobis` - Multivariate distance

#### outlier_threshold

- **Purpose:** Z-score threshold
- **Required:** Only if outlier_method = zscore
- **Data Type:** Numeric
- **Valid Values:** 1.0-5.0
- **Default:** `3.0`

#### outlier_min_vars

- **Purpose:** Minimum variables to be outlier on
- **Required:** Only if outlier_detection = TRUE
- **Data Type:** Integer
- **Default:** `1`

#### outlier_handling

- **Purpose:** What to do with outliers
- **Required:** Only if outlier_detection = TRUE
- **Default:** `flag`
- **Valid Values:**
  - `none` - Detect but don't act
  - `flag` - Mark in output
  - `remove` - Exclude from clustering

#### outlier_alpha

- **Purpose:** Significance level for Mahalanobis
- **Required:** Only if outlier_method = mahalanobis
- **Data Type:** Decimal
- **Valid Values:** 0.0001-0.1
- **Default:** `0.001`

---

### K Selection Settings

#### k_selection_metrics

- **Purpose:** Metrics for choosing optimal k
- **Required:** No
- **Data Type:** Text (comma-separated)
- **Default:** `silhouette,elbow`
- **Valid Values:** `silhouette`, `elbow`, `gap`

---

### Output Settings

#### output_folder

- **Purpose:** Where to save results
- **Required:** No
- **Data Type:** Text (folder path)
- **Default:** `output/`

#### output_prefix

- **Purpose:** Filename prefix
- **Required:** No
- **Data Type:** Text
- **Default:** `seg_`

#### create_dated_folder

- **Purpose:** Create timestamped subfolder
- **Required:** No
- **Default:** `TRUE`
- **Valid Values:** TRUE, FALSE

#### segment_names

- **Purpose:** Custom segment names
- **Required:** No
- **Data Type:** Text (comma-separated) or `auto`
- **Default:** `auto`
- **Example:** `Budget,Premium,Loyal` or `auto`

#### save_model

- **Purpose:** Save model for scoring new data
- **Required:** No
- **Default:** `TRUE`

#### question_labels_file

- **Purpose:** Path to Excel file with variable labels
- **Required:** No
- **Data Type:** Text (file path) or blank
- **Default:** Blank
- **Label File Format:**
  ```
  Variable | Label
  Q01      | Overall satisfaction
  Q02      | Product quality
  ```

---

### Metadata Settings

#### project_name

- **Purpose:** Project name for reports
- **Required:** No
- **Default:** `Segmentation Analysis`

#### analyst_name

- **Purpose:** Analyst name for reports
- **Required:** No
- **Default:** `Analyst`

#### description

- **Purpose:** Analysis description
- **Required:** No
- **Default:** Blank

---

## Variable Selection Config Template

**File:** `VarSel_Config_Template.xlsx`

Template for variable selection when you have many candidate variables.

### Variable Selection Settings

#### variable_selection

- **Purpose:** Enable automatic variable reduction
- **Required:** Yes (for this template)
- **Default:** `TRUE`
- **Notes:** Reduces 20+ variables to optimal subset

#### variable_selection_method

- **Purpose:** Selection algorithm
- **Required:** Yes
- **Default:** `variance_correlation`
- **Valid Values:**
  - `variance_correlation` - Remove low variance, high correlation
  - `factor_analysis` - Use factor loadings
  - `both` - Two-stage selection

#### max_clustering_vars

- **Purpose:** Target number of variables to keep
- **Required:** Yes
- **Data Type:** Integer
- **Valid Values:** 5-20
- **Default:** `10`

#### varsel_min_variance

- **Purpose:** Minimum variance to keep variable
- **Required:** No
- **Data Type:** Decimal
- **Valid Values:** 0.01-1.0
- **Default:** `0.1`
- **Notes:** Applied to standardized data

#### varsel_max_correlation

- **Purpose:** Maximum correlation before removing
- **Required:** No
- **Data Type:** Decimal
- **Valid Values:** 0.5-0.95
- **Default:** `0.8`

---

## Output Structure

### Exploration Mode Output

| File | Sheets |
|------|--------|
| seg_exploration_report.xlsx | Metrics_Comparison, Recommendation, Profile_k3, Profile_k4, ... |
| seg_segment_profiles_k3.xlsx | Profiles, Statistics |
| seg_segment_profiles_k4.xlsx | Profiles, Statistics |
| seg_k_selection.png | Elbow and silhouette plots |
| seg_model.rds | Saved model object |

### Final Mode Output

| File | Sheets |
|------|--------|
| seg_final_report.xlsx | Summary, Profiles, Statistics, Validation |
| seg_assignments.xlsx | Assignments (ID + Segment) |
| seg_profiles_heatmap.png | Visual profile comparison |
| seg_segment_sizes.png | Size distribution |
| seg_model.rds | Saved model object |

### Output Sheets Detail

**Summary Sheet:**
- Analysis name and date
- Data file and settings
- Number of segments and sizes
- Silhouette score

**Profiles Sheet:**
- Mean values by segment
- Index scores (segment vs. overall)
- Sorted by importance

**Statistics Sheet:**
- ANOVA p-values
- Effect sizes (eta-squared)
- Significance flags

**Validation Sheet:**
- Silhouette scores
- WCSS values
- Calinski-Harabasz index
- Stability metrics

---

## Complete Examples

### Exploration Mode Configuration

```
Setting                | Value
-----------------------|--------------------------------
data_file              | data/satisfaction_survey.csv
id_variable            | ResponseID
clustering_vars        | Q02,Q03,Q04,Q05,Q06,Q07,Q08
k_fixed                | [BLANK]
k_min                  | 3
k_max                  | 6
method                 | kmeans
nstart                 | 25
seed                   | 123
missing_data           | listwise_deletion
standardize            | TRUE
min_segment_size_pct   | 10
outlier_detection      | TRUE
outlier_method         | zscore
outlier_threshold      | 3.0
outlier_handling       | flag
output_folder          | output/
output_prefix          | seg_
project_name           | Customer Segmentation Exploration
```

### Final Mode Configuration

```
Setting                | Value
-----------------------|--------------------------------
data_file              | data/satisfaction_survey.csv
id_variable            | ResponseID
clustering_vars        | Q02,Q03,Q04,Q05,Q06,Q07,Q08
k_fixed                | 4
method                 | kmeans
nstart                 | 25
seed                   | 123
missing_data           | listwise_deletion
standardize            | TRUE
segment_names          | Advocates,Satisfied,At-Risk,Detractors
save_model             | TRUE
output_folder          | output/
output_prefix          | seg_
project_name           | Customer Segmentation Final
```

### Variable Selection Configuration

```
Setting                   | Value
--------------------------|--------------------------------
data_file                 | data/large_survey.csv
id_variable               | ResponseID
clustering_vars           | Q01,Q02,Q03,...,Q30
variable_selection        | TRUE
variable_selection_method | variance_correlation
max_clustering_vars       | 10
varsel_min_variance       | 0.1
varsel_max_correlation    | 0.8
k_min                     | 3
k_max                     | 6
output_folder             | output/varsel/
project_name              | Variable Selection Test
```

---

## Validation Rules

### Settings Validation

| Setting | Validation |
|---------|------------|
| data_file | File must exist, valid format |
| id_variable | Column must exist in data |
| clustering_vars | All columns must exist, must be numeric |
| k_fixed | Integer 2-10 or blank |
| k_min | Integer 2-10, less than k_max |
| k_max | Integer 2-10, greater than k_min |
| nstart | Integer 1-200 |
| missing_data | One of: listwise_deletion, mean_imputation, median_imputation, refuse |
| outlier_method | One of: zscore, mahalanobis |
| outlier_threshold | Numeric 1.0-5.0 |
| variable_selection_method | One of: variance_correlation, factor_analysis, both |

### Sample Size Validation

```
Minimum n = max(50, 30 × k_max)

Examples:
- k_max = 4 → need ≥ 120 complete cases
- k_max = 6 → need ≥ 180 complete cases
```

### Variable Requirements

| Rule | Message |
|------|---------|
| At least 3 clustering vars | "Need at least 3 clustering variables" |
| Maximum 50 clustering vars | "Maximum 50 clustering variables" |
| All vars numeric | "Variable 'X' must be numeric" |
| No zero variance | "Variable 'X' has zero variance" |

---

## Template File Location

Templates are located at:
- `modules/segment/docs/templates/Segment_Config_Template.xlsx`
- `modules/segment/docs/templates/VarSel_Config_Template.xlsx`

Copy and rename for your project.

---

**Part of the Turas Analytics Platform**
