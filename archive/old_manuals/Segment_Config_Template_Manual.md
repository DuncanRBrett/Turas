# Segment Config Template - User Manual

**Template File:** `templates/Segment_Config_Template.xlsx`
**Version:** 10.0
**Last Updated:** 4 December 2025

---

## Overview

The Segment Config Template configures customer segmentation analysis in TURAS. This module performs clustering analysis to identify distinct customer segments based on attitudes, behaviors, or needs.

**Key Purpose:** Group respondents into segments using k-means clustering with optional variable selection and outlier detection.

**Two-Phase Workflow:**
1. **Exploration Mode:** Test multiple k values to find optimal number of segments
2. **Final Mode:** Run segmentation with chosen k value

---

## Template Structure

The template contains **2 sheets**:

1. **Instructions** - Comprehensive workflow guide and variable selection documentation
2. **Config** - All analysis settings and parameters

---

## Sheet 1: Instructions

**Purpose:** Detailed documentation of the two-phase workflow, variable selection process, and configuration options.

**Action Required:** Review for understanding. This sheet is not read by the analysis code.

**Key Content:**
- Two-phase workflow: Exploration → Final
- How to choose optimal k using silhouette and elbow method
- Variable selection algorithms (when using 20+ variables)
- Outlier detection methods
- Complete configuration examples

**Critical Workflow:**

**Phase 1 - Exploration:**
1. Set `k_fixed` = blank
2. Set `k_min` and `k_max` (e.g., 3 to 6)
3. Run analysis → produces `seg_exploration_report.xlsx`
4. Review Metrics_Comparison sheet
5. Choose optimal k

**Phase 2 - Final:**
1. Set `k_fixed` = chosen k value
2. Run analysis → produces `seg_final_report.xlsx` and `seg_assignments.xlsx`

---

## Sheet 2: Config

**Purpose:** All segmentation settings and parameters.

**Required Columns:** `Setting`, `Value`

### Core Settings

#### Setting: data_file

- **Purpose:** Path to survey data file
- **Required:** YES
- **Data Type:** Text (file path)
- **Valid Values:** Path to .csv, .xlsx, .sav, .dta file
- **Example:** `/Users/duncan/.../data.xlsx`

#### Setting: data_sheet

- **Purpose:** Sheet name in Excel file
- **Required:** NO (only for Excel files)
- **Data Type:** Text
- **Valid Values:** Sheet name
- **Default:** First sheet or `Data`
- **Example:** `Sheet1` or `Data`

#### Setting: id_variable

- **Purpose:** Column name for respondent ID
- **Required:** YES
- **Data Type:** Text (column name)
- **Valid Values:** Must match column in data
- **Default:** `ResponseID`
- **Example:** `ResponseID` or `resp_id`

#### Setting: clustering_vars

- **Purpose:** Variables to use for segmentation
- **Required:** YES
- **Data Type:** Text (comma-separated column names)
- **Valid Values:** Numeric variables from data
- **Logic:**
  - These variables define the segments
  - Must be numeric (rating scales, etc.)
  - Should be attitudes/needs (not demographics)
- **Example:** `Q02,Q03,Q04,Q05,Q06,Q07,Q08,Q09,Q10,Q11`
- **Common Mistakes:**
  - Including demographic variables (these are for profiling, not clustering)
  - Including non-numeric variables

#### Setting: profile_vars

- **Purpose:** Variables for profiling segments (not used in clustering)
- **Required:** NO
- **Data Type:** Text (comma-separated column names)
- **Valid Values:** Any variables from data
- **Default:** All non-clustering variables
- **Logic:** Used to describe segments after clustering (e.g., age, gender, usage)
- **Example:** `age,tenure_years,gender`

### Clustering Algorithm Settings

#### Setting: method

- **Purpose:** Clustering algorithm
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** `kmeans`
- **Default:** `kmeans`
- **Logic:** Only k-means currently supported
- **Example:** `kmeans`

#### Setting: k_fixed

- **Purpose:** Fixed number of segments (blank = exploration mode)
- **Required:** NO
- **Data Type:** Integer or blank
- **Valid Values:** 2 to 10 or blank
- **Logic:**
  - **Blank** = Exploration mode (tests k_min to k_max)
  - **Number** = Final mode (uses this k)
- **Example:** `4` or leave blank

#### Setting: k_min

- **Purpose:** Minimum k to test (exploration mode)
- **Required:** Only for exploration mode
- **Data Type:** Integer
- **Valid Values:** 2 to 10
- **Default:** `3`
- **Example:** `3`

#### Setting: k_max

- **Purpose:** Maximum k to test (exploration mode)
- **Required:** Only for exploration mode
- **Data Type:** Integer
- **Valid Values:** 2 to 10
- **Default:** `6`
- **Example:** `6`

#### Setting: nstart

- **Purpose:** Number of random starts for k-means
- **Required:** NO
- **Data Type:** Integer
- **Valid Values:** 1 to 200
- **Default:** `25`
- **Logic:** Higher = more stable results but slower
- **Example:** `25`

#### Setting: seed

- **Purpose:** Random seed for reproducibility
- **Required:** NO
- **Data Type:** Integer
- **Valid Values:** Any integer
- **Default:** `123`
- **Logic:** Same seed = same results
- **Example:** `123`

### Data Handling Settings

#### Setting: missing_data

- **Purpose:** How to handle missing values
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** `listwise_deletion`, `mean_imputation`, `median_imputation`, `refuse`
- **Default:** `listwise_deletion`
- **Logic:**
  - `listwise_deletion` = Remove cases with any missing
  - `mean_imputation` = Replace with variable mean
  - `median_imputation` = Replace with variable median
  - `refuse` = Error if any missing found
- **Example:** `listwise_deletion`

#### Setting: missing_threshold

- **Purpose:** Max % missing allowed per variable
- **Required:** NO
- **Data Type:** Numeric (0-100)
- **Valid Values:** 0 to 100
- **Default:** `15`
- **Logic:** Variables with >X% missing excluded
- **Example:** `15`

#### Setting: standardize

- **Purpose:** Standardize variables before clustering
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:** Recommended TRUE to give equal weight to all variables
- **Example:** `TRUE`

#### Setting: min_segment_size_pct

- **Purpose:** Minimum % of sample per segment
- **Required:** NO
- **Data Type:** Numeric (0-50)
- **Valid Values:** 0 to 50
- **Default:** `10`
- **Logic:** Warns if any segment <X% of sample
- **Example:** `10`

### Outlier Detection Settings

#### Setting: outlier_detection

- **Purpose:** Enable outlier detection
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Example:** `FALSE`

#### Setting: outlier_method

- **Purpose:** Detection algorithm
- **Required:** Only if outlier_detection = TRUE
- **Data Type:** Text
- **Valid Values:** `zscore`, `mahalanobis`
- **Default:** `zscore`
- **Example:** `zscore`

#### Setting: outlier_threshold

- **Purpose:** Z-score threshold
- **Required:** Only if outlier_method = zscore
- **Data Type:** Numeric
- **Valid Values:** 1.0 to 5.0
- **Default:** `3.0`
- **Logic:** 3.0 = 99.7% of normal distribution
- **Example:** `3.0`

#### Setting: outlier_min_vars

- **Purpose:** Min variables to be outlier on
- **Required:** Only if outlier_detection = TRUE
- **Data Type:** Integer
- **Valid Values:** 1+
- **Default:** `1`
- **Example:** `1`

#### Setting: outlier_handling

- **Purpose:** What to do with outliers
- **Required:** Only if outlier_detection = TRUE
- **Data Type:** Text
- **Valid Values:** `none`, `flag`, `remove`
- **Default:** `flag`
- **Logic:**
  - `none` = Detect but don't act
  - `flag` = Mark in output
  - `remove` = Exclude from clustering
- **Example:** `flag`

#### Setting: outlier_alpha

- **Purpose:** Significance level for Mahalanobis
- **Required:** Only if outlier_method = mahalanobis
- **Data Type:** Decimal
- **Valid Values:** 0.0001 to 0.1
- **Default:** `0.001`
- **Example:** `0.001`

### Variable Selection Settings (Advanced)

#### Setting: variable_selection

- **Purpose:** Enable automatic variable reduction
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Logic:** Reduces 20+ variables to optimal subset (8-12)
- **When to Use:** When you have 20+ variables and want automatic selection
- **Example:** `FALSE`

#### Setting: variable_selection_method

- **Purpose:** Selection algorithm
- **Required:** Only if variable_selection = TRUE
- **Data Type:** Text
- **Valid Values:** `variance_correlation`, `factor_analysis`, `both`
- **Default:** `variance_correlation`
- **Example:** `variance_correlation`

#### Setting: max_clustering_vars

- **Purpose:** Target number of variables to keep
- **Required:** Only if variable_selection = TRUE
- **Data Type:** Integer
- **Valid Values:** 5 to 20
- **Default:** `10`
- **Example:** `10`

#### Setting: varsel_min_variance

- **Purpose:** Min variance to keep variable
- **Required:** Only if variable_selection = TRUE
- **Data Type:** Decimal
- **Valid Values:** 0.01 to 1.0
- **Default:** `0.1`
- **Example:** `0.1`

#### Setting: varsel_max_correlation

- **Purpose:** Max correlation before removing
- **Required:** Only if variable_selection = TRUE
- **Data Type:** Decimal
- **Valid Values:** 0.5 to 0.95
- **Default:** `0.8`
- **Example:** `0.8`

### K Selection Settings

#### Setting: k_selection_metrics

- **Purpose:** Metrics for choosing optimal k
- **Required:** NO
- **Data Type:** Text (comma-separated)
- **Valid Values:** `silhouette`, `elbow`, `gap`
- **Default:** `silhouette,elbow`
- **Example:** `silhouette,elbow`

### Output Settings

#### Setting: output_folder

- **Purpose:** Where to save results
- **Required:** NO
- **Data Type:** Text (folder path)
- **Valid Values:** Folder path
- **Default:** `output/`
- **Example:** `/Users/duncan/.../TurasTest/`

#### Setting: output_prefix

- **Purpose:** Filename prefix
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** Any text
- **Default:** `seg_`
- **Example:** `seg_` or `varsel_test_`

#### Setting: create_dated_folder

- **Purpose:** Create timestamped subfolder
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Example:** `FALSE`

#### Setting: segment_names

- **Purpose:** Custom segment names
- **Required:** NO
- **Data Type:** Text (comma-separated names) or `auto`
- **Valid Values:** Names matching number of segments, or `auto`
- **Default:** `auto`
- **Logic:** `auto` = uses Segment 1, Segment 2, etc.
- **Example:** `Budget,Premium,Loyal` or `auto`

#### Setting: save_model

- **Purpose:** Save model for scoring new data
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Example:** `TRUE`

### Metadata Settings

#### Setting: project_name

- **Purpose:** Project name for reports
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** Any text
- **Default:** `Segmentation Analysis`
- **Example:** `Variable Selection Test`

#### Setting: analyst_name

- **Purpose:** Analyst name for reports
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** Any text
- **Default:** `Analyst`
- **Example:** `Test User`

#### Setting: description

- **Purpose:** Analysis description
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** Any text
- **Default:** Blank
- **Example:** `Testing variable selection with 20 satisfaction variables`

#### Setting: question_labels_file

- **Purpose:** Path to Excel file with variable labels
- **Required:** NO
- **Data Type:** Text (file path) or blank
- **Valid Values:** Path to .xlsx file with Variable and Label columns
- **Default:** Blank
- **Logic:** Provides friendly labels for variables in output
- **Example:** `/Users/duncan/.../project_question_labels.xlsx`
- **Label File Format:**
  ```
  Variable | Label
  Q01      | How likely would you be to recommend?
  Q02      | A well-run estate
  ```

---

## Complete Configuration Example

### Exploration Mode

```
data_file              | /data/satisfaction_survey.csv
id_variable            | ResponseID
clustering_vars        | Q02,Q03,Q04,Q05,Q06,Q07,Q08,Q09,Q10,Q11
k_fixed                | [BLANK]
k_min                  | 3
k_max                  | 6
method                 | kmeans
nstart                 | 25
seed                   | 123
missing_data           | listwise_deletion
standardize            | TRUE
min_segment_size_pct   | 10
output_folder          | output/
output_prefix          | seg_
project_name           | Customer Segmentation Exploration
```

### Final Mode (after choosing k=4)

```
data_file              | /data/satisfaction_survey.csv
id_variable            | ResponseID
clustering_vars        | Q02,Q03,Q04,Q05,Q06,Q07,Q08,Q09,Q10,Q11
k_fixed                | 4
method                 | kmeans
nstart                 | 25
seed                   | 123
missing_data           | listwise_deletion
standardize            | TRUE
segment_names          | Price Sensitive,Quality Seekers,Loyal,Switchers
save_model             | TRUE
output_folder          | output/
output_prefix          | seg_
project_name           | Customer Segmentation Final
```

---

## Common Mistakes

### Mistake 1: Using Demographics in Clustering

**Problem:** Poor segmentation results
**Solution:** Use clustering_vars for attitudes/needs only. Use profile_vars for demographics.

### Mistake 2: Not Standardizing

**Problem:** Variables with larger scales dominate
**Solution:** Set standardize = TRUE (recommended)

### Mistake 3: Too Many Variables

**Problem:** Curse of dimensionality, poor segments
**Solution:** Limit to 8-12 variables or use variable_selection = TRUE

### Mistake 4: k_fixed Not Blank in Exploration

**Problem:** Only tests one k value
**Solution:** Leave k_fixed blank for exploration mode

### Mistake 5: Small Segments

**Problem:** Segments with <10% of sample
**Solution:** Reduce k_max or accept smaller segments if meaningful

---

## Output Structure

**Exploration Mode:**
- `seg_exploration_report.xlsx` - Metrics for each k value tested

**Final Mode:**
- `seg_final_report.xlsx` - Complete segment profiles
- `seg_assignments.xlsx` - Each respondent's segment assignment
- `seg_profiles_heatmap.png` - Visual comparison
- `seg_model.rds` - Saved model for scoring new data

---

**End of Segment Config Template Manual**
