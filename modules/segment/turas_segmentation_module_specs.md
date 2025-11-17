# Turas Segmentation Module - Design Specifications

**Version:** 1.0
**Date:** November 13, 2025
**Module:** `turas.segment`
**Status:** Phase 1 - Initial Implementation

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [File Structure](#file-structure)
4. [Configuration Specification](#configuration-specification)
5. [Function Specifications](#function-specifications)
6. [Workflow](#workflow)
7. [Input/Output Specifications](#inputoutput-specifications)
8. [Algorithm Details](#algorithm-details)
9. [Validation & Quality Checks](#validation--quality-checks)
10. [Error Handling](#error-handling)
11. [Testing Requirements](#testing-requirements)
12. [Future Enhancement Hooks](#future-enhancement-hooks)
13. [Dependencies](#dependencies)

---

## 1. Overview

### 1.1 Purpose

The Turas Segmentation Module provides market researchers with a standardized, repeatable approach to clustering survey respondents into meaningful segments based on behavioral, attitudinal, or satisfaction data.

### 1.2 Design Principles

- **Standalone but integrated**: Operates independently but works within the Turas ecosystem
- **Non-destructive**: Never modifies original survey data files
- **Two-stage workflow**: Exploration phase → Final run
- **Configuration-driven**: Excel-based config for repeatability
- **Extensible**: Built for future enhancement without breaking existing functionality

### 1.3 Scope - Phase 1

**In Scope:**
- K-means clustering with automatic k selection
- Excel-based configuration
- Exploration mode (compare multiple k values)
- Final run mode (detailed output for chosen k)
- Basic validation metrics (silhouette, elbow, gap statistic)
- Segment profiling and characterization
- Multiple output formats

**Out of Scope (Future Phases):**
- Alternative clustering algorithms (PAM, hierarchical, latent class)
- Temporal tracking/classification of new waves
- Mixed data types (categorical + continuous)
- Advanced outlier detection
- Predictive classification models

---

## 2. Architecture

### 2.1 Position in Turas Ecosystem

```
Turas Package
├── parser module      (existing - data import/structure)
├── tabs module        (existing - crosstabs)
├── tracker module     (existing - wave tracking)
├── confidence module  (existing - confidence intervals)
└── segment module     (NEW - this specification)
```

### 2.2 Module Independence

**Does NOT depend on:**
- Parser module (reads raw Excel data directly)
- Survey_structure file (not used by segmentation)
- Other Turas modules

**Can integrate with:**
- Tabs module (segment assignments can be joined to data for crosstab analysis)
- Tracker module (future: track segment composition over time)

**Integration pattern:**
```r
# Segmentation runs independently
seg <- turas_segment_from_config("segment_config.xlsx")

# Output can be joined to main data later for tabs
library(dplyr)
survey_data <- read_excel("survey_data.xlsx")
segment_assignments <- read_excel("output/segment_assignments.xlsx")
survey_with_segments <- left_join(survey_data, segment_assignments, by = "respondent_id")

# Now use with tabs module
turas_tabs(survey_with_segments, by = "segment")
```

### 2.3 File Organization

```
R/
├── segment.R                # Main user-facing functions
├── segment_config.R         # Config file reading/validation
├── segment_kmeans.R         # K-means implementation
├── segment_validate.R       # Validation metrics
├── segment_profile.R        # Segment profiling functions
├── segment_export.R         # Output generation
└── segment_utils.R          # Helper functions

tests/
└── testthat/
    └── test-segment.R       # Unit tests

inst/
└── templates/
    └── segment_config_template.xlsx  # Template for users

vignettes/
└── segmentation.Rmd         # User guide
```

---

## 3. File Structure

### 3.1 Input Files

#### 3.1.1 Segment Configuration File (Excel)
**Filename:** User-defined (e.g., `segment_config.xlsx`)
**Required tabs:** `Config`
**Optional tabs:** `Notes`, `Help`

#### 3.1.2 Survey Data File (Excel/CSV)
**Filename:** Specified in config
**Format:** Standard survey data with one row per respondent
**Required:** Must contain `id_variable` specified in config

### 3.2 Output Files

All outputs written to `output_folder` specified in config.

#### 3.2.1 Exploration Mode Output
**Filename:** `{output_prefix}k_selection_report.xlsx`
**Tabs:**
- `Metrics_Comparison`: Statistical metrics for each k
- `Profile_K3`, `Profile_K4`, etc.: Segment profiles for each k value
- `Validation_Charts`: Visual aids (if charts can be embedded)

#### 3.2.2 Final Run Mode Outputs

**Primary output - Segment Assignments:**
**Filename:** `{output_prefix}segment_assignments.xlsx`
**Columns:**
- `respondent_id`: From original data
- `segment`: Numeric segment assignment (1, 2, 3, ...)
- `segment_name`: Descriptive name (if auto-generated or provided)

**Secondary output - Full Report:**
**Filename:** `{output_prefix}segmentation_report.xlsx`
**Tabs:**
- `Summary`: Overview and key findings
- `Segment_Profiles`: Mean values by segment
- `Demographics`: Demographic breakdown by segment
- `Validation`: Quality metrics
- `Variable_Importance`: How much each variable contributes

**Tertiary output - Model Object:**
**Filename:** `{output_prefix}model.rds`
**Content:** R object containing full model for future use

---

## 4. Configuration Specification

### 4.1 Config File Template Structure

**Tab: "Config"**

The config file uses a two-column structure: `parameter | value`

#### 4.1.1 Complete Config Template

```
parameter                    | value                          | notes
-----------------------------|--------------------------------|------------------
# DATA SOURCE
data_file                    | survey_data.xlsx               | Path to survey data
data_sheet                   | Data                           | Sheet name in Excel
id_variable                  | respondent_id                  | Unique identifier column

# SEGMENTATION VARIABLES
clustering_vars              | q1,q2,q3,q4,q5                 | Comma-separated variable names

# PROFILING VARIABLES
profile_vars                 | age,gender,tenure,region       | Variables to describe segments

# MODEL CONFIGURATION
method                       | kmeans                         | Clustering method (kmeans only in Phase 1)
k_fixed                      |                                | Leave blank for exploration; set to number for final run
k_min                        | 3                              | Minimum segments to test
k_max                        | 6                              | Maximum segments to test
nstart                       | 25                             | K-means random starts
seed                         | 123                            | Random seed for reproducibility

# DATA HANDLING
missing_data                 | listwise_deletion              | listwise_deletion | mean_imputation | median_imputation | refuse
missing_threshold            | 15                             | Warn if % missing exceeds this
standardize                  | TRUE                           | TRUE | FALSE
min_segment_size_pct         | 10                             | Minimum segment size as % of sample

# VALIDATION
k_selection_metrics          | silhouette,elbow,gap           | Metrics to calculate (comma-separated)

# OUTPUT SETTINGS
output_folder                | output/                        | Where to write outputs
output_prefix                | seg_                           | Prefix for output files
create_dated_folder          | TRUE                           | Create subfolder with date
segment_names                | auto                           | auto | or comma-separated names
save_model                   | TRUE                           | Save model object for future use

# METADATA (optional)
project_name                 | Resident Survey 2025           | For documentation
analyst_name                 | Your Name                      | For documentation
description                  | Satisfaction-based segmentation| For documentation
```

### 4.2 Parameter Specifications

#### 4.2.1 Data Source Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `data_file` | string | Yes | - | Path to survey data file (Excel or CSV) |
| `data_sheet` | string | No | "Data" | Sheet name if Excel file |
| `id_variable` | string | Yes | - | Column name containing unique respondent ID |

**Validation:**
- `data_file` must exist and be readable
- `data_sheet` must exist if Excel file
- `id_variable` must exist in data and be unique

#### 4.2.2 Variable Selection Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `clustering_vars` | comma-separated string | Yes | - | Variables used to CREATE segments |
| `profile_vars` | comma-separated string | No | all other numeric vars | Variables used to DESCRIBE segments |

**Validation:**
- All `clustering_vars` must exist in data
- All `clustering_vars` must be numeric
- Minimum 2 `clustering_vars` required
- Recommended 3-10 `clustering_vars`
- `profile_vars` must exist in data if specified

**Important distinction:**
- **Clustering variables**: Used by the algorithm to form segments (e.g., satisfaction ratings)
- **Profiling variables**: Used to describe segments after formation (e.g., demographics)

#### 4.2.3 Model Configuration Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `method` | string | No | "kmeans" | Clustering algorithm |
| `k_fixed` | integer or blank | No | blank | Fixed number of segments; blank = exploration mode |
| `k_min` | integer | No | 3 | Minimum k to test in exploration |
| `k_max` | integer | No | 7 | Maximum k to test in exploration |
| `nstart` | integer | No | 25 | Number of random starts for k-means |
| `seed` | integer | No | 123 | Random seed |

**Validation:**
- `method` must be "kmeans" (Phase 1)
- `k_fixed` if specified must be between 2 and min(n/50, 10)
- `k_min` must be >= 2
- `k_max` must be > `k_min`
- `k_max` should be <= 10 (warn if higher)
- `nstart` must be >= 10 (warn if lower)

#### 4.2.4 Data Handling Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `missing_data` | string | No | "listwise_deletion" | How to handle missing values |
| `missing_threshold` | numeric | No | 15 | Warning threshold for % data loss |
| `standardize` | boolean | No | TRUE | Standardize variables before clustering |
| `min_segment_size_pct` | numeric | No | 10 | Minimum segment size as % |

**Valid `missing_data` values:**
- `listwise_deletion`: Remove any respondent with missing data on clustering vars
- `mean_imputation`: Replace missing with variable mean
- `median_imputation`: Replace missing with variable median
- `refuse`: Error if any missing data found

**Validation:**
- `missing_threshold` must be between 0 and 100
- `min_segment_size_pct` must be between 0 and 50

#### 4.2.5 Output Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `output_folder` | string | No | "output/" | Output directory |
| `output_prefix` | string | No | "seg_" | Prefix for output filenames |
| `create_dated_folder` | boolean | No | TRUE | Create date-stamped subfolder |
| `segment_names` | string or comma-separated | No | "auto" | Segment names |
| `save_model` | boolean | No | TRUE | Save model object |

**Validation:**
- `output_folder` created if doesn't exist
- If `segment_names` provided, count must match k (checked in final run only)

### 4.3 Example Configuration Files

#### 4.3.1 Example 1: Housing Estate Resident Survey (Exploration Mode)

```
parameter                    | value
-----------------------------|--------------------------------
# DATA SOURCE
data_file                    | resident_survey_2025.xlsx
data_sheet                   | Data
id_variable                  | resident_id

# SEGMENTATION VARIABLES
clustering_vars              | overall_satisfaction,maintenance_rating,facility_rating,staff_rating,communication_rating

# PROFILING VARIABLES
profile_vars                 | age,tenure_years,gender,apartment_type,household_size,previous_complaints

# MODEL CONFIGURATION
method                       | kmeans
k_fixed                      |
k_min                        | 3
k_max                        | 6
nstart                       | 25
seed                         | 123

# DATA HANDLING
missing_data                 | listwise_deletion
missing_threshold            | 15
standardize                  | TRUE
min_segment_size_pct         | 10

# OUTPUT SETTINGS
output_folder                | output/resident_seg/
output_prefix                | resident_
create_dated_folder          | TRUE
segment_names                | auto
save_model                   | TRUE

# METADATA
project_name                 | Resident Satisfaction Survey 2025
analyst_name                 | Market Research Team
description                  | Segmentation based on satisfaction ratings across key service areas
```

**Expected behavior:**
- Tests k=3, 4, 5, 6
- Outputs comparison report to `output/resident_seg/2025-11-13/resident_k_selection_report.xlsx`
- User reviews, decides k=4 is optimal
- Updates `k_fixed | 4` and reruns

#### 4.3.2 Example 2: Business Client Satisfaction (Final Run)

```
parameter                    | value
-----------------------------|--------------------------------
# DATA SOURCE
data_file                    | client_satisfaction_q4.csv
id_variable                  | client_id

# SEGMENTATION VARIABLES
clustering_vars              | product_satisfaction,service_satisfaction,value_satisfaction,likelihood_recommend

# PROFILING VARIABLES
profile_vars                 | industry,company_size,contract_value,tenure_months,support_tickets,channel_preference

# MODEL CONFIGURATION
method                       | kmeans
k_fixed                      | 4
k_min                        | 3
k_max                        | 6
nstart                       | 25
seed                         | 456

# DATA HANDLING
missing_data                 | mean_imputation
missing_threshold            | 20
standardize                  | TRUE
min_segment_size_pct         | 8

# OUTPUT SETTINGS
output_folder                | output/client_seg/
output_prefix                | client_q4_
create_dated_folder          | FALSE
segment_names                | Champions,Satisfied,At Risk,Detractors
save_model                   | TRUE

# METADATA
project_name                 | Q4 Client Satisfaction Segmentation
analyst_name                 | Analytics Team
description                  | Four-segment solution based on satisfaction and loyalty metrics
```

**Expected behavior:**
- Runs directly with k=4 (no exploration)
- Outputs detailed report to `output/client_seg/`
- Segments named Champions, Satisfied, At Risk, Detractors
- Uses mean imputation for missing data

---

## 5. Function Specifications

### 5.1 User-Facing Functions

#### 5.1.1 `turas_segment_from_config()`

**Description:** Main entry point. Reads config file and executes segmentation.

**Signature:**
```r
turas_segment_from_config(config_file, verbose = TRUE)
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `config_file` | character | Path to Excel config file |
| `verbose` | logical | Print progress messages |

**Returns:** S3 object of class `turas_segment`

**Behavior:**
- Reads and validates config file
- Loads data file
- Determines if exploration or final run based on `k_fixed`
- Executes appropriate workflow
- Exports results
- Returns results object

**Example:**
```r
# Exploration mode
seg_explore <- turas_segment_from_config("segment_config.xlsx")
# Returns exploration object, exports K selection report

# Final run mode (after updating config with k_fixed=4)
seg_final <- turas_segment_from_config("segment_config.xlsx")
# Returns final segmentation, exports all reports
```

#### 5.1.2 `turas_segment()`

**Description:** Programmatic segmentation without config file (for advanced users).

**Signature:**
```r
turas_segment(
  data,
  clustering_vars,
  profile_vars = NULL,
  k = NULL,
  k_range = 3:6,
  method = "kmeans",
  missing_data = "listwise_deletion",
  standardize = TRUE,
  min_segment_size_pct = 10,
  nstart = 25,
  seed = 123,
  ...
)
```

**Parameters:** Same as config parameters but as function arguments

**Returns:** S3 object of class `turas_segment`

**Example:**
```r
data <- read_excel("survey_data.xlsx")
seg <- turas_segment(
  data = data,
  clustering_vars = c("q1", "q2", "q3"),
  k = 4
)
```

#### 5.1.3 S3 Methods

**`print.turas_segment()`**
```r
print.turas_segment(x, ...)
```

Prints summary of segmentation:
- Mode (exploration vs final)
- Number of segments
- Sample size
- Key metrics
- Output file locations

**`summary.turas_segment()`**
```r
summary.turas_segment(object, ...)
```

Detailed summary:
- Data quality report
- Validation metrics
- Segment sizes and profiles
- Recommendations

**`plot.turas_segment()`**
```r
plot.turas_segment(x, type = "cluster", ...)
```

Visualization options:
- `type = "cluster"`: PCA projection with segment colors
- `type = "elbow"`: Elbow plot (exploration mode)
- `type = "silhouette"`: Silhouette plot
- `type = "profile"`: Segment profile heatmap

### 5.2 Internal Functions

#### 5.2.1 Configuration Functions

**`read_segment_config()`**
```r
read_segment_config(config_file)
```
Reads and parses Excel config file into list.

**`validate_segment_config()`**
```r
validate_segment_config(config)
```
Validates config parameters, returns validated config or errors.

#### 5.2.2 Data Preparation Functions

**`prepare_segment_data()`**
```r
prepare_segment_data(data, clustering_vars, config)
```
- Extracts clustering variables
- Handles missing data per config
- Standardizes if requested
- Returns clean matrix and metadata

**`handle_missing_data()`**
```r
handle_missing_data(data, vars, method)
```
Implements missing data strategies.

**`standardize_vars()`**
```r
standardize_vars(data, center = TRUE, scale = TRUE)
```
Z-score standardization, returns scaled data and scaling parameters.

#### 5.2.3 Clustering Functions

**`run_kmeans_exploration()`**
```r
run_kmeans_exploration(data, k_range, nstart, seed)
```
Tests multiple k values, returns list of models with metrics.

**`run_kmeans_final()`**
```r
run_kmeans_final(data, k, nstart, seed)
```
Runs k-means for specified k, returns detailed results.

**`check_segment_sizes()`**
```r
check_segment_sizes(cluster_assignments, min_pct)
```
Validates segment sizes meet minimum threshold.

#### 5.2.4 Validation Functions

**`calculate_silhouette()`**
```r
calculate_silhouette(data, clusters)
```
Returns silhouette scores using `cluster::silhouette()`.

**`calculate_wss()`**
```r
calculate_wss(kmeans_model)
```
Extracts within-cluster sum of squares.

**`calculate_gap_statistic()`**
```r
calculate_gap_statistic(data, k_range, nstart)
```
Computes gap statistic using `cluster::clusGap()`.

**`recommend_k()`**
```r
recommend_k(metrics_df)
```
Analyzes metrics and recommends optimal k with rationale.

#### 5.2.5 Profiling Functions

**`create_segment_profiles()`**
```r
create_segment_profiles(data, clusters, profile_vars)
```
Calculates means/proportions by segment.

**`calculate_segment_differences()`**
```r
calculate_segment_differences(profiles)
```
ANOVA F-statistics and p-values for continuous variables.

**`generate_segment_names()`**
```r
generate_segment_names(profiles, k, method = "auto")
```
Auto-generates descriptive segment names based on characteristics.

#### 5.2.6 Export Functions

**`export_exploration_report()`**
```r
export_exploration_report(exploration_results, output_path, config)
```
Creates k selection comparison Excel workbook.

**`export_final_report()`**
```r
export_final_report(segment_results, output_path, config)
```
Creates comprehensive segmentation report Excel workbook.

**`export_segment_assignments()`**
```r
export_segment_assignments(data, clusters, segment_names, id_var, output_path)
```
Exports simple respondent_id + segment file.

---

## 6. Workflow

### 6.1 Exploration Mode Workflow

**Triggered when:** `k_fixed` is blank in config

```
1. Read and validate config
   ├─ Check file paths
   ├─ Validate parameters
   └─ Check data file exists

2. Load and prepare data
   ├─ Read data file
   ├─ Extract clustering variables
   ├─ Handle missing data
   ├─ Standardize if requested
   └─ Quality checks (variance, sample size)

3. Run k-means for each k in range
   FOR k = k_min to k_max:
     ├─ Run kmeans with nstart random starts
     ├─ Calculate validation metrics
     │   ├─ Silhouette score
     │   ├─ Within-cluster SS
     │   ├─ Between/Total SS ratio
     │   └─ Gap statistic (if selected)
     ├─ Check segment sizes
     └─ Create basic profiles

4. Analyze and recommend
   ├─ Compare metrics across k values
   ├─ Apply recommendation logic
   └─ Flag any quality issues

5. Export exploration report
   ├─ Metrics comparison table
   ├─ Profile tables for each k
   ├─ Visualization data
   └─ Recommendation text

6. Return exploration object
   └─ Contains all models and metrics for review

7. Display guidance
   └─ Instruct user to review report and set k_fixed
```

**Key decision point:** User reviews output and updates config with chosen k value.

### 6.2 Final Run Workflow

**Triggered when:** `k_fixed` is specified in config

```
1. Read and validate config
   ├─ Same as exploration mode
   └─ Plus: validate k_fixed is reasonable

2. Load and prepare data
   └─ Same as exploration mode

3. Run final k-means
   ├─ Use k = k_fixed
   ├─ Use same nstart and seed as exploration
   └─ Obtain cluster assignments

4. Validate solution
   ├─ Calculate all validation metrics
   ├─ Check segment sizes vs minimum
   ├─ Calculate silhouette for each segment
   └─ Flag any quality warnings

5. Profile segments
   ├─ Calculate means for all clustering vars by segment
   ├─ Calculate means for all profile vars by segment
   ├─ Run ANOVA/chi-square tests
   ├─ Identify distinguishing characteristics
   └─ Generate or apply segment names

6. Export outputs
   ├─ Segment assignments file (respondent_id + segment)
   ├─ Full segmentation report (multi-tab Excel)
   ├─ Model object (.rds file)
   └─ Optional: visualizations

7. Return final object
   └─ Contains complete results for further analysis

8. Display summary
   └─ Key findings and output locations
```

### 6.3 Error Handling at Each Stage

**Config validation stage:**
- Missing required parameters → Error with specific parameter name
- Invalid file paths → Error with file path
- Invalid parameter values → Error with valid options

**Data loading stage:**
- File not found → Error with file path
- Sheet not found → Error with sheet name
- ID variable not found → Error with variable name
- ID variable not unique → Error with duplicate count

**Data preparation stage:**
- Clustering variables not found → Error with variable names
- Clustering variables non-numeric → Error with variable names
- Too much missing data → Warning or error based on threshold
- Insufficient variance → Warning

**Clustering stage:**
- Sample size too small → Error with minimum required
- No convergence → Warning, retry with different seed
- Segment size below minimum → Warning or error, suggest fewer segments

**Export stage:**
- Cannot write to output folder → Error with folder path
- Disk space issues → Error

---

## 7. Input/Output Specifications

### 7.1 Input Data Structure

#### 7.1.1 Survey Data File Format

**Required columns:**
- One column matching `id_variable` (unique identifier)
- All columns listed in `clustering_vars` (numeric)

**Optional columns:**
- All columns listed in `profile_vars`
- Any other data (ignored by segmentation)

**Example structure:**
```
respondent_id | q1_overall | q2_maint | q3_facil | q4_staff | age | tenure | gender
1             | 4          | 5        | 4        | 5        | 45  | 8      | M
2             | 2          | 2        | 3        | 2        | 32  | 2      | F
3             | 5          | 5        | 5        | 4        | 67  | 15     | M
4             | 3          | 4        | 3        | 3        | 28  | 1      | F
...
```

**Data type requirements:**
- `id_variable`: Character or numeric, must be unique
- `clustering_vars`: All numeric (integer or double)
- `profile_vars`: Numeric, character, or factor (handled appropriately)

**Missing data:**
- Represented as NA, blank cells, or specified missing code
- Handled according to `missing_data` config parameter

### 7.2 Output File Specifications

#### 7.2.1 Segment Assignments File

**Filename:** `{output_prefix}segment_assignments.xlsx` or `.csv`
**Purpose:** Simple join table for integration with other analyses

**Structure:**
```
respondent_id | segment | segment_name
1             | 2       | Satisfied Regulars
2             | 3       | Dissatisfied Critics
3             | 1       | Loyal Advocates
4             | 2       | Satisfied Regulars
...
```

**Column specifications:**
| Column | Type | Description |
|--------|------|-------------|
| `respondent_id` | Same as input | Matches input data exactly |
| `segment` | Integer | Segment number (1, 2, 3, ..., k) |
| `segment_name` | Character | Descriptive name |

**Key properties:**
- One row per respondent in original data (after handling missing)
- No additional columns
- Can be directly joined to original data on `respondent_id`

#### 7.2.2 K Selection Report (Exploration Mode)

**Filename:** `{output_prefix}k_selection_report.xlsx`

**Tab 1: "Metrics_Comparison"**
```
k | n_segments | sample_size | silhouette_avg | wss    | betweenss_totss | gap_stat | smallest_seg_n | smallest_seg_pct | recommendation
--|------------|-------------|----------------|--------|-----------------|----------|----------------|------------------|---------------
3 | 3          | 450         | 0.52           | 1456.3 | 0.58            | 0.41     | 98             | 21.8%            |
4 | 4          | 450         | 0.58           | 1123.8 | 0.64            | 0.56     | 87             | 19.3%            | ← Best silhouette
5 | 5          | 450         | 0.55           | 945.2  | 0.68            | 0.52     | 65             | 14.4%            |
6 | 6          | 450         | 0.48           | 823.1  | 0.71            | 0.45     | 38             | 8.4%             | ⚠ Small segment
```

**Column descriptions:**
- `k`: Number of clusters tested
- `silhouette_avg`: Average silhouette width (higher = better separation)
- `wss`: Within-cluster sum of squares (lower = tighter clusters)
- `betweenss_totss`: Ratio of between to total SS (higher = better)
- `gap_stat`: Gap statistic value
- `smallest_seg_pct`: Size of smallest segment as percentage
- `recommendation`: Automated guidance or warnings

**Tab 2-N: "Profile_K3", "Profile_K4", etc.**

One tab per k value tested. Structure:

```
Variable            | Overall | Segment_1 | Segment_2 | Segment_3 | F_stat | p_value
--------------------|---------|-----------|-----------|-----------|--------|--------
# Clustering Variables
q1_overall          | 3.5     | 4.7       | 3.2       | 2.1       | 145.2  | <0.001
q2_maintenance      | 3.4     | 4.6       | 3.1       | 2.3       | 132.8  | <0.001
q3_facilities       | 3.6     | 4.7       | 3.8       | 2.0       | 156.3  | <0.001
q4_staff            | 3.7     | 4.8       | 3.5       | 2.5       | 128.9  | <0.001

# Profile Variables
age                 | 48.2    | 55.1      | 44.8      | 42.3      | 12.5   | <0.001
tenure_years        | 7.2     | 12.5      | 6.8       | 4.2       | 15.7   | <0.001

# Segment Characteristics
segment_size_n      | 450     | 140       | 230       | 80        | -      | -
segment_size_pct    | 100%    | 31.1%     | 51.1%     | 17.8%     | -      | -
```

**Last row: "Suggested Description"** (optional)
Brief auto-generated description of each segment based on distinguishing characteristics.

#### 7.2.3 Segmentation Report (Final Run)

**Filename:** `{output_prefix}segmentation_report.xlsx`

**Tab 1: "Summary"**

Narrative summary including:

```
SEGMENTATION SUMMARY
====================

Project: [project_name from config]
Date: [run date]
Analyst: [analyst_name from config]

DATA OVERVIEW
-------------
Total respondents: 450
Valid responses: 445 (5 removed due to missing data)
Clustering variables: q1_overall, q2_maintenance, q3_facilities, q4_staff
Number of segments: 4

SEGMENTATION QUALITY
--------------------
Method: K-means clustering
Average silhouette: 0.58 (Good separation)
Between/Total SS ratio: 0.64
All segments meet minimum size threshold (10%)

SEGMENTS IDENTIFIED
-------------------

Segment 1: Loyal Advocates (31%, n=138)
- Highest satisfaction across all dimensions (avg 4.7/5)
- Older residents (avg age 55)
- Longer tenure (avg 12.5 years)
- Key characteristics: Consistently positive, engaged, stable

Segment 2: Satisfied Regulars (46%, n=205)
- Moderate-to-high satisfaction (avg 3.5/5)
- Represent typical resident profile
- Key characteristics: Generally content, some minor issues

Segment 3: Dissatisfied Critics (16%, n=71)
- Low satisfaction across all areas (avg 2.1/5)
- Younger residents (avg age 42)
- Shorter tenure (avg 4.2 years)
- Key characteristics: Multiple pain points, vocal, at risk

Segment 4: Disengaged (7%, n=31)
- Low satisfaction, minimal facility use
- Key characteristics: Not participating in estate activities

RECOMMENDATIONS
---------------
[Auto-generated or analyst-added recommendations]

VALIDATION NOTES
----------------
- All segments significantly different on clustering variables (p<0.001)
- Silhouette analysis shows clear segment structure
- No quality warnings
```

**Tab 2: "Segment_Profiles"**

Same structure as exploration mode profile tabs, but only for chosen k.

**Tab 3: "Demographics"**

Crosstabulation of categorical profile variables by segment:

```
Characteristic      | Overall | Segment_1 | Segment_2 | Segment_3 | Segment_4 | Chi_sq | p_value
--------------------|---------|-----------|-----------|-----------|-----------|--------|--------
Gender              |         |           |           |           |           | 3.2    | 0.361
  Male              | 45.2%   | 42.0%     | 48.3%     | 43.7%     | 45.2%     |        |
  Female            | 54.8%   | 58.0%     | 51.7%     | 56.3%     | 54.8%     |        |

Apartment Type      |         |           |           |           |           | 15.8   | 0.015
  1-bedroom         | 22.5%   | 15.2%     | 18.5%     | 35.2%     | 38.7%     |        |
  2-bedroom         | 48.3%   | 45.7%     | 52.2%     | 42.3%     | 41.9%     |        |
  3-bedroom         | 29.2%   | 39.1%     | 29.3%     | 22.5%     | 19.4%     |        |
```

**Tab 4: "Validation"**

Detailed validation metrics:

```
OVERALL QUALITY METRICS
-----------------------
Metric                      | Value      | Interpretation
----------------------------|------------|------------------
Average Silhouette          | 0.58       | Good separation
Min Silhouette              | 0.15       | Acceptable
Between SS / Total SS       | 0.64       | Good clustering
Total Within-cluster SS     | 1123.8     | -
Total Between-cluster SS    | 1987.5     | -

SEGMENT-LEVEL QUALITY
---------------------
Segment | Size | Avg_Silhouette | Min_Silhouette | Pct_Well_Classified
--------|------|----------------|----------------|--------------------
1       | 138  | 0.62           | 0.18           | 94.2%
2       | 205  | 0.61           | 0.22           | 91.7%
3       | 71   | 0.55           | 0.15           | 88.7%
4       | 31   | 0.53           | 0.18           | 87.1%

CLUSTERING VARIABLE IMPORTANCE
-------------------------------
Variable        | F_statistic | p_value | Eta_squared | Rank
----------------|-------------|---------|-------------|-----
q3_facilities   | 156.3       | <0.001  | 0.514       | 1
q1_overall      | 145.2       | <0.001  | 0.496       | 2
q2_maintenance  | 132.8       | <0.001  | 0.474       | 3
q4_staff        | 128.9       | <0.001  | 0.466       | 4

QUALITY FLAGS
-------------
[✓] All segments exceed minimum size threshold
[✓] All clustering variables significantly different across segments
[✓] Average silhouette indicates good separation
[⚠] Segment 4 relatively small (consider combining with Segment 3)
```

**Tab 5: "Centroid_Values"** (technical)

Raw centroid values (means) for each segment on standardized scale:

```
Variable       | Segment_1 | Segment_2 | Segment_3 | Segment_4
---------------|-----------|-----------|-----------|----------
q1_overall     | 1.245     | 0.125     | -1.458    | -0.823
q2_maintenance | 1.356     | 0.089     | -1.523    | -0.756
q3_facilities  | 1.289     | 0.234     | -1.687    | -0.912
q4_staff       | 1.312     | 0.156     | -1.234    | -0.589
```

This is useful for technical validation and potential future classification.

#### 7.2.4 Model Object File

**Filename:** `{output_prefix}model.rds`
**Format:** R data file (RDS)

**Contents:**
```r
model_object <- list(
  # Core model
  kmeans_result = kmeans_object,      # From stats::kmeans()

  # Metadata
  k = 4,
  method = "kmeans",
  n_obs = 445,
  date_created = Sys.time(),
  turas_version = "1.0",

  # Variable info
  clustering_vars = c("q1", "q2", "q3", "q4"),
  id_variable = "respondent_id",

  # Preprocessing info
  standardize = TRUE,
  scale_center = c(3.5, 3.4, 3.6, 3.7),  # Original means
  scale_scale = c(1.2, 1.3, 1.1, 1.2),   # Original SDs
  missing_method = "listwise_deletion",

  # Assignments
  cluster_assignments = c(2, 3, 1, 2, ...),
  segment_names = c("Loyal Advocates", "Satisfied Regulars", "Dissatisfied Critics", "Disengaged"),

  # Validation
  silhouette_avg = 0.58,
  betweenss_totss = 0.64,

  # Config used
  config = original_config_list
)

class(model_object) <- "turas_segment"
```

**Purpose:**
- Documentation of exact model used
- Potential future use for classification (Phase 2+)
- Reproducibility

---

## 8. Algorithm Details

### 8.1 K-means Implementation

**Algorithm:** Standard k-means clustering using `stats::kmeans()`

**Key parameters:**
```r
kmeans(
  x = scaled_data,           # Standardized clustering variables
  centers = k,                # Number of clusters
  nstart = 25,               # Number of random starts (default)
  iter.max = 100,            # Max iterations per start
  algorithm = "Hartigan-Wong" # Default algorithm (most common)
)
```

**Why k-means:**
- Well-understood and interpretable
- Computationally efficient for typical survey sample sizes
- Produces hard assignments (each respondent in one segment)
- Industry standard for market research segmentation

**Limitations to document:**
- Assumes spherical clusters
- Sensitive to scale (hence standardization)
- Can find local optima (hence nstart=25)
- Requires numeric variables only (Phase 1)

### 8.2 Standardization

**Method:** Z-score standardization

```r
scaled_value = (original_value - mean) / sd
```

**Implementation:**
```r
scaled_data <- scale(data, center = TRUE, scale = TRUE)
```

**Why standardize:**
- Prevents variables with larger scales from dominating
- Makes all variables contribute equally to distance calculations
- Required when mixing variables with different scales (e.g., 1-5 and 1-10)

**Storage:**
Save `center` and `scale` attributes for potential future use.

### 8.3 Distance Metric

**Metric:** Euclidean distance (default for k-means)

```
distance(a, b) = sqrt(sum((a_i - b_i)^2))
```

Where a and b are vectors of standardized variable values.

### 8.4 Convergence Criteria

K-means iterates until:
1. Cluster assignments don't change, OR
2. `iter.max` reached (default 100)

If convergence not reached, function returns best result from `nstart` attempts.

### 8.5 Optimal K Selection Logic

**Metrics calculated:**

1. **Silhouette Score** (primary)
   - Range: -1 to 1
   - Interpretation: >0.5 = good, 0.3-0.5 = acceptable, <0.3 = poor
   - Recommendation: Choose k with highest average silhouette >0.5

2. **Elbow Method** (supporting)
   - Plot WSS vs k
   - Look for "elbow" where improvement slows
   - Subjective but intuitive

3. **Gap Statistic** (supporting)
   - Compares clustering to random data
   - Choose k where gap is maximized
   - More rigorous but computationally expensive

**Recommendation algorithm:**

```r
recommend_k <- function(metrics) {
  # Primary: Best silhouette > 0.5
  best_sil_k <- metrics$k[which.max(metrics$silhouette)]

  # Check constraints
  valid_k <- metrics$k[
    metrics$silhouette > 0.5 &
    metrics$smallest_seg_pct >= min_segment_size_pct
  ]

  if (length(valid_k) == 0) {
    # No k meets quality thresholds
    warning("No k values meet quality criteria. Review metrics carefully.")
    return(best_sil_k)  # Return best available
  }

  # Return highest silhouette among valid
  recommended <- valid_k[which.max(metrics$silhouette[metrics$k %in% valid_k])]

  return(list(
    recommended_k = recommended,
    rationale = sprintf("k=%d maximizes silhouette (%.2f) while meeting size constraints",
                        recommended,
                        metrics$silhouette[metrics$k == recommended])
  ))
}
```

---

## 9. Validation & Quality Checks

### 9.1 Pre-Clustering Validation

**Sample size check:**
```r
min_required_n <- k_max * 50  # 50 observations per potential cluster
if (nrow(data) < min_required_n) {
  stop(sprintf("Sample size (%d) insufficient for k=%d. Need at least %d.",
               nrow(data), k_max, min_required_n))
}
```

**Variable variance check:**
```r
for (var in clustering_vars) {
  var_sd <- sd(data[[var]], na.rm = TRUE)
  if (var_sd < 0.1) {
    warning(sprintf("Variable %s has very low variance (SD=%.3f). May not contribute to segmentation.",
                    var, var_sd))
  }
}
```

**Correlation check:**
```r
cor_matrix <- cor(data[, clustering_vars], use = "complete.obs")
high_cor_pairs <- which(abs(cor_matrix) > 0.9 & cor_matrix != 1, arr.ind = TRUE)
if (nrow(high_cor_pairs) > 0) {
  warning("Some clustering variables are highly correlated (r > 0.9). Consider removing redundant variables.")
}
```

**Missing data check:**
```r
missing_pct <- sum(!complete.cases(data[, clustering_vars])) / nrow(data) * 100
if (missing_pct > missing_threshold) {
  warning(sprintf("%.1f%% of data has missing values (threshold: %d%%). Review missing data handling.",
                  missing_pct, missing_threshold))
}
```

### 9.2 Post-Clustering Validation

**Silhouette analysis:**
```r
library(cluster)
sil <- silhouette(clusters, dist(scaled_data))
sil_summary <- summary(sil)

# Overall
avg_sil <- mean(sil[, "sil_width"])

# By segment
seg_sil <- aggregate(sil[, "sil_width"],
                     by = list(cluster = sil[, "cluster"]),
                     FUN = mean)
```

**Interpretation:**
- avg_sil > 0.7: Strong structure
- avg_sil > 0.5: Good structure
- avg_sil > 0.3: Acceptable structure
- avg_sil < 0.3: Weak/artificial structure

**Segment size validation:**
```r
seg_sizes <- table(clusters)
seg_pcts <- prop.table(seg_sizes) * 100

if (any(seg_pcts < min_segment_size_pct)) {
  warning(sprintf("Segment(s) below minimum size threshold: %s",
                  paste(which(seg_pcts < min_segment_size_pct), collapse = ", ")))
}
```

**Statistical significance:**
```r
# ANOVA for each clustering variable
for (var in clustering_vars) {
  aov_result <- aov(data[[var]] ~ factor(clusters))
  aov_summary <- summary(aov_result)
  f_stat <- aov_summary[[1]]["F value"][1, 1]
  p_value <- aov_summary[[1]]["Pr(>F)"][1, 1]

  if (p_value > 0.05) {
    warning(sprintf("Variable %s not significantly different across segments (p=%.3f)",
                    var, p_value))
  }
}
```

### 9.3 Quality Flags

Return structured quality assessment:

```r
quality_report <- list(
  overall_quality = ifelse(avg_sil > 0.5, "Good",
                          ifelse(avg_sil > 0.3, "Acceptable", "Poor")),

  flags = c(
    if (avg_sil < 0.3) "⚠ Weak cluster structure",
    if (any(seg_pcts < min_segment_size_pct)) "⚠ Small segment(s)",
    if (missing_pct > missing_threshold) "⚠ High missing data",
    if (max(cor_matrix[cor_matrix != 1]) > 0.9) "ℹ Highly correlated variables",
    "✓ All variables significantly different" # if all p < 0.05
  ),

  metrics = list(
    silhouette_avg = avg_sil,
    betweenss_totss = model$betweenss / model$totss,
    smallest_segment_pct = min(seg_pcts)
  )
)
```

---

## 10. Error Handling

### 10.1 Error Categories

**Critical Errors (stop execution):**
- Config file not found
- Required parameters missing
- Data file not found
- ID variable not found or not unique
- Clustering variables not found
- Clustering variables not numeric
- Sample size too small
- Cannot write to output directory

**Warnings (continue with caution):**
- High missing data (but below threshold)
- Low variable variance
- Highly correlated variables
- Small segment sizes (but above threshold)
- Weak silhouette scores
- Non-convergence in some k-means runs

**Info messages (FYI):**
- Number of respondents removed due to missing
- Standardization applied
- Number of random starts used
- Output files written

### 10.2 Error Message Standards

All error messages should:
1. Be specific and actionable
2. Include relevant values/parameters
3. Suggest resolution where possible

**Examples:**

```r
# Bad
stop("Invalid config")

# Good
stop("Config parameter 'clustering_vars' is missing. Please specify at least 2 numeric variables.")

# Bad
warning("Problem with data")

# Good
warning(sprintf("%.1f%% of observations have missing data on clustering variables. %d respondents removed (threshold: %d%%).",
                missing_pct, n_removed, missing_threshold))
```

### 10.3 Error Handling Implementation

**Config validation:**
```r
validate_segment_config <- function(config) {
  errors <- character()

  # Check required parameters
  required <- c("data_file", "id_variable", "clustering_vars")
  missing <- required[!required %in% names(config)]
  if (length(missing) > 0) {
    errors <- c(errors, sprintf("Required parameter(s) missing: %s",
                                paste(missing, collapse = ", ")))
  }

  # Check file existence
  if ("data_file" %in% names(config) && !file.exists(config$data_file)) {
    errors <- c(errors, sprintf("Data file not found: %s", config$data_file))
  }

  # Check parameter validity
  if ("method" %in% names(config) && config$method != "kmeans") {
    errors <- c(errors, sprintf("Invalid method '%s'. Only 'kmeans' supported in Phase 1.",
                                config$method))
  }

  if (length(errors) > 0) {
    stop(paste("Config validation failed:\n", paste("  -", errors, collapse = "\n")))
  }

  return(config)
}
```

**Try-catch for clustering:**
```r
run_kmeans_safe <- function(data, k, nstart, seed) {
  tryCatch({
    set.seed(seed)
    result <- kmeans(data, centers = k, nstart = nstart, iter.max = 100)

    # Check convergence
    if (result$ifault == 4) {
      warning(sprintf("K-means did not converge for k=%d. Results may be suboptimal. Consider increasing nstart.", k))
    }

    return(result)
  }, error = function(e) {
    stop(sprintf("K-means clustering failed for k=%d: %s", k, e$message))
  })
}
```

---

## 11. Testing Requirements

### 11.1 Unit Tests

**Config reading and validation:**
```r
test_that("read_segment_config handles valid config", {
  config <- read_segment_config("tests/fixtures/valid_config.xlsx")
  expect_type(config, "list")
  expect_true("data_file" %in% names(config))
})

test_that("validate_segment_config catches missing required params", {
  config <- list(data_file = "data.xlsx")  # Missing id_variable
  expect_error(validate_segment_config(config), "Required parameter.*missing")
})
```

**Missing data handling:**
```r
test_that("listwise deletion removes rows with missing", {
  data <- data.frame(
    id = 1:5,
    q1 = c(1, 2, NA, 4, 5),
    q2 = c(1, 2, 3, 4, 5)
  )
  result <- handle_missing_data(data, c("q1", "q2"), "listwise_deletion")
  expect_equal(nrow(result), 4)
})

test_that("mean imputation fills missing values", {
  data <- data.frame(q1 = c(1, 2, NA, 4, 5))
  result <- handle_missing_data(data, "q1", "mean_imputation")
  expect_equal(result$q1[3], 3)  # Mean of 1,2,4,5
})
```

**Segmentation logic:**
```r
test_that("turas_segment runs with valid input", {
  data <- data.frame(
    id = 1:200,
    q1 = rnorm(200, 3, 1),
    q2 = rnorm(200, 3, 1),
    q3 = rnorm(200, 3, 1)
  )

  result <- turas_segment(
    data = data,
    clustering_vars = c("q1", "q2", "q3"),
    k = 3
  )

  expect_s3_class(result, "turas_segment")
  expect_equal(length(unique(result$cluster)), 3)
})
```

**Validation metrics:**
```r
test_that("silhouette calculation returns valid range", {
  data <- matrix(rnorm(300), ncol = 3)
  clusters <- rep(1:3, each = 100)
  sil <- calculate_silhouette(data, clusters)
  expect_true(all(sil >= -1 & sil <= 1))
})
```

### 11.2 Integration Tests

**Full exploration workflow:**
```r
test_that("exploration mode produces expected outputs", {
  # Setup test config
  config_file <- create_test_config(k_fixed = NULL)

  # Run
  result <- turas_segment_from_config(config_file)

  # Check outputs
  expect_true(file.exists("output/test_k_selection_report.xlsx"))
  expect_true(is.null(result$k_fixed))
  expect_true(length(result$models) > 1)
})
```

**Full final run workflow:**
```r
test_that("final run mode produces all expected outputs", {
  # Setup test config
  config_file <- create_test_config(k_fixed = 4)

  # Run
  result <- turas_segment_from_config(config_file)

  # Check outputs
  expect_true(file.exists("output/test_segment_assignments.xlsx"))
  expect_true(file.exists("output/test_segmentation_report.xlsx"))
  expect_true(file.exists("output/test_model.rds"))
  expect_equal(result$k, 4)
})
```

### 11.3 Test Data

**Create synthetic test datasets:**

```r
create_test_survey_data <- function(n = 300, k = 4) {
  # Generate data with known cluster structure
  segments <- rep(1:k, each = n/k)

  data <- data.frame(
    respondent_id = 1:n,
    segment_true = segments  # For validation
  )

  # Generate variables with cluster structure
  for (i in 1:5) {
    data[[paste0("q", i)]] <- rnorm(n, mean = segments, sd = 0.5)
  }

  # Add some demographic variables
  data$age <- sample(25:75, n, replace = TRUE)
  data$gender <- sample(c("M", "F"), n, replace = TRUE)

  return(data)
}
```

### 11.4 Regression Tests

After Phase 1 implementation, create test suite that checks:
- Example configs from docs produce expected outputs
- Results reproducible with same seed
- Output file formats match specification

Store expected outputs in `tests/fixtures/` and compare.

---

## 12. Future Enhancement Hooks

### 12.1 Additional Clustering Methods

**Design consideration:** `method` parameter already exists in config

**Implementation approach:**
```r
run_segmentation <- function(data, method, ...) {
  seg_fun <- switch(method,
    kmeans = run_kmeans,
    pam = run_pam,              # Future
    hierarchical = run_hierarchical,  # Future
    latent_class = run_latent_class,  # Future
    stop("Unknown method")
  )

  seg_fun(data, ...)
}
```

**Methods to add:**
1. **PAM (Partitioning Around Medoids)**: More robust to outliers
   - Use: `cluster::pam()`
   - Config: `method | pam`

2. **Hierarchical clustering**: Exploratory dendrogram
   - Use: `stats::hclust()`
   - Config: `method | hierarchical`
   - Extra param: `linkage | ward.D2`

3. **Latent Class Analysis**: Model-based clustering
   - Use: `poLCA::poLCA()` or similar
   - Config: `method | latent_class`

### 12.2 Mixed Data Types

**Current limitation:** Numeric only

**Future:** Handle categorical variables

**Implementation approach:**
- Use Gower distance for mixed types
- Use `cluster::daisy()` for distance calculation
- PAM instead of k-means (works with distance matrices)

**Config addition:**
```
variable_types | q1:numeric, q2:numeric, region:categorical, channel:categorical
```

### 12.3 Temporal Tracking

**Use case:** Track segment composition across waves

**Implementation approach:**

**Phase 2a - Simple wave comparison:**
```r
compare_waves(wave1_result, wave2_result)
# Shows how segment profiles changed
```

**Phase 2b - Classification:**
```r
# Save model from Wave 1
segment_classify(model, new_data)
# Classifies Wave 2 respondents into Wave 1 segments
```

**Config additions:**
```
tracking_mode        | TRUE
baseline_model       | models/wave1_model.rds
classify_only        | TRUE
```

**New function:**
```r
turas_segment_classify(baseline_model, new_data, config)
```

### 12.4 Advanced Validation

**Stability analysis:**
- Bootstrap resampling
- Check if segments replicate across subsamples

```r
validate_stability(data, k, n_bootstrap = 100)
```

**Consensus clustering:**
- Run multiple clustering methods
- Find consensus across approaches

```r
consensus_segment(data, methods = c("kmeans", "pam", "hierarchical"))
```

### 12.5 Variable Selection

**Automatic feature selection:**
- Test different variable combinations
- Recommend which variables add most value

```r
select_clustering_vars(data, candidate_vars, k)
# Returns ranked variables by contribution
```

### 12.6 Predictive Classification

**Build classification model:**
- Decision tree or discriminant function
- Classify new respondents without re-clustering

```r
build_classifier(segment_result, method = "tree")
# Returns classification function
```

### 12.7 Enhanced Outputs

**Interactive dashboard:**
- Shiny app for exploring segments
- Drag-and-drop interface

**PowerPoint export:**
- Auto-generate presentation deck
- One slide per segment with key visuals

```r
export_segment_presentation(result, template = "corporate")
```

### 12.8 Hooks in Current Code

**Where to add hooks:**

```r
# In run_segmentation()
run_segmentation <- function(data, config) {
  # Hook: Allow method dispatch
  method_function <- get_method_function(config$method)

  # Hook: Allow preprocessing plugins
  data <- apply_preprocessing_plugins(data, config)

  # Run clustering
  result <- method_function(data, config)

  # Hook: Allow validation plugins
  result <- apply_validation_plugins(result, config)

  # Hook: Allow output plugins
  export_results(result, config, plugins = config$output_plugins)

  return(result)
}
```

**Plugin architecture example:**
```r
register_plugin("validation", "bootstrap_stability",
                function(result) { ... })
```

---

## 13. Dependencies

### 13.1 Required R Packages

**Core dependencies (Imports):**
```r
Imports:
    stats,           # kmeans, dist
    cluster,         # silhouette, pam
    dplyr,          # Data manipulation
    readxl,         # Read Excel config and data
    writexl,        # Write Excel outputs
    methods         # S3 classes
```

**Recommended dependencies (Suggests):**
```r
Suggests:
    factoextra,     # Enhanced visualization and optimal k
    NbClust,        # Comprehensive k selection
    ggplot2,        # Plotting
    knitr,          # Vignettes
    rmarkdown,      # Vignettes
    testthat (>= 3.0.0)  # Testing
```

**Why Suggests not Imports:**
- Keep core package lightweight
- Allow users to install only what they need
- factoextra and NbClust are large dependencies

**Handling optional dependencies:**
```r
use_factoextra <- function() {
  if (!requireNamespace("factoextra", quietly = TRUE)) {
    message("Install factoextra for enhanced visualizations: install.packages('factoextra')")
    return(FALSE)
  }
  return(TRUE)
}

plot.turas_segment <- function(x, ...) {
  if (use_factoextra()) {
    factoextra::fviz_cluster(x$model, ...)
  } else {
    # Fallback to base R plot
    plot_base(x, ...)
  }
}
```

### 13.2 R Version Requirements

**Minimum R version:** R >= 4.0.0

**Rationale:**
- dplyr syntax requires R 4.0+
- Pipe operator `|>` available natively in R 4.1+ (optional use)

### 13.3 System Requirements

**None** - Pure R implementation, no compiled code

### 13.4 License Considerations

**All dependencies are FOSS:**
- stats, cluster, methods: Part of R (GPL-2 | GPL-3)
- dplyr: MIT license
- readxl, writexl: MIT license
- factoextra, ggplot2: GPL-2

**Turas segmentation module can use:** GPL-3 or MIT (to be decided)

---

## 14. Development Checklist

### 14.1 Phase 1 - MVP Implementation

**Week 1: Core Infrastructure**
- [ ] Set up package structure (`segment.R`, `segment_config.R`, etc.)
- [ ] Implement config file reading (`read_segment_config()`)
- [ ] Implement config validation (`validate_segment_config()`)
- [ ] Create config template Excel file
- [ ] Write tests for config handling

**Week 2: Data Preparation**
- [ ] Implement data loading from Excel/CSV
- [ ] Implement missing data handling (listwise, mean imputation)
- [ ] Implement standardization
- [ ] Implement pre-clustering quality checks
- [ ] Write tests for data preparation

**Week 3: Clustering Logic**
- [ ] Implement k-means wrapper (`run_kmeans_final()`)
- [ ] Implement exploration mode (`run_kmeans_exploration()`)
- [ ] Implement validation metrics (silhouette, elbow, gap)
- [ ] Implement optimal k recommendation logic
- [ ] Write tests for clustering

**Week 4: Profiling & Outputs**
- [ ] Implement segment profiling (`create_segment_profiles()`)
- [ ] Implement segment naming (auto-generation)
- [ ] Implement exploration report export
- [ ] Implement final report export
- [ ] Implement segment assignments export
- [ ] Write tests for outputs

**Week 5: Integration & Polish**
- [ ] Implement main entry point (`turas_segment_from_config()`)
- [ ] Implement S3 methods (print, summary, plot)
- [ ] Write integration tests
- [ ] Create vignette with examples
- [ ] Write documentation
- [ ] Code review and refactoring

**Week 6: Testing & Release**
- [ ] Run full test suite
- [ ] Test with real survey data
- [ ] Create test fixtures
- [ ] Final documentation pass
- [ ] Prepare for internal release

### 14.2 Phase 2+ Enhancements (Future)

**Phase 2a: Enhanced Validation (2-3 weeks)**
- [ ] Stability analysis (bootstrap)
- [ ] Enhanced quality metrics
- [ ] Better visualization

**Phase 2b: Temporal Tracking (2-3 weeks)**
- [ ] Classification function for new waves
- [ ] Wave comparison tools
- [ ] Transition matrices

**Phase 3: Additional Methods (3-4 weeks)**
- [ ] PAM clustering
- [ ] Hierarchical clustering
- [ ] Latent class analysis

**Phase 4: Mixed Data Types (2-3 weeks)**
- [ ] Gower distance
- [ ] Categorical variable handling

---

## 15. Documentation Requirements

### 15.1 User Documentation

**Vignette: "Introduction to Segmentation"**
- What is segmentation
- When to use it
- How to prepare your data
- Walkthrough with example

**Vignette: "Segmentation Workflow"**
- Creating config file
- Exploration mode
- Interpreting results
- Final run
- Integration with tabs module

**Function documentation:**
- All exported functions fully documented with roxygen2
- Examples for each function
- Parameter descriptions

### 15.2 Developer Documentation

**Architecture document** (this document serves as foundation)

**Code comments:**
- All complex algorithms commented
- Decision rationale documented
- Hook points clearly marked

**Testing documentation:**
- How to run tests
- How to create test fixtures
- Coverage requirements (aim for 80%+)

---

## 16. Success Criteria

### 16.1 Functional Requirements Met

- [ ] Config-driven workflow works end-to-end
- [ ] Exploration mode identifies optimal k
- [ ] Final run produces all specified outputs
- [ ] Output files match specifications exactly
- [ ] Integration with existing Turas modules works
- [ ] All unit tests pass
- [ ] All integration tests pass

### 16.2 Quality Requirements Met

- [ ] Code follows Turas style guide
- [ ] Test coverage >= 80%
- [ ] No breaking changes to existing modules
- [ ] Documentation complete and clear
- [ ] Example configs work as documented
- [ ] Error messages are helpful and actionable

### 16.3 Performance Requirements Met

- [ ] Handles datasets up to 5,000 respondents efficiently
- [ ] Exploration mode completes in < 1 minute for typical config
- [ ] Final run completes in < 30 seconds for typical config
- [ ] Output files written successfully

### 16.4 User Acceptance

- [ ] Run through 3+ real-world datasets
- [ ] Internal user testing with market research team
- [ ] Documentation reviewed and understood by users
- [ ] Config template is intuitive

---

## 17. Appendix

### 17.1 Example Workflows

**Workflow A: Simple Satisfaction Segmentation**

1. Analyst receives resident satisfaction data (450 respondents)
2. Creates `segment_config.xlsx`:
   - Sets clustering vars: 5 satisfaction questions
   - Sets profile vars: demographics
   - Leaves k_fixed blank
3. Runs: `turas_segment_from_config("segment_config.xlsx")`
4. Reviews `k_selection_report.xlsx`
5. Decides k=4 is optimal
6. Updates config: `k_fixed | 4`
7. Re-runs: `turas_segment_from_config("segment_config.xlsx")`
8. Receives `segment_assignments.xlsx` and `segmentation_report.xlsx`
9. Joins assignments to main data
10. Uses tabs module to create crosstabs by segment

**Workflow B: Multi-dimensional Business Segmentation**

1. Client has satisfaction data with 8 rating questions + behavioral data
2. Analyst creates config with:
   - Clustering vars: All 8 ratings
   - Profile vars: Usage metrics, demographics, channel preferences
   - k_range: 3-7
3. Runs exploration
4. Reviews multiple k solutions
5. Discusses with client, chooses k=5 based on business interpretability
6. Runs final segmentation with custom segment names
7. Delivers comprehensive report to client
8. Saves model for potential future wave tracking

### 17.2 Glossary

**Clustering variables:** Variables used by the algorithm to form segments (input to clustering)

**Profile variables:** Variables used to describe segments after formation (not used in clustering)

**Centroid:** Mean value of all variables for a segment

**Silhouette score:** Measure of how well each observation fits its assigned cluster (-1 to 1)

**Within-cluster sum of squares (WSS):** Sum of squared distances from points to their cluster centroid

**Between-cluster sum of squares:** Sum of squared distances between cluster centroids and overall centroid

**Gap statistic:** Comparison of clustering structure to random data

**Elbow method:** Visual identification of optimal k where improvement plateaus

**Standardization:** Scaling variables to have mean=0 and SD=1

**Hard clustering:** Each observation assigned to exactly one cluster (vs probabilistic/soft clustering)

### 17.3 References

**K-means algorithm:**
- Hartigan, J. A. and Wong, M. A. (1979). Algorithm AS 136: A K-means clustering algorithm. Applied Statistics, 28, 100–108.

**Silhouette method:**
- Rousseeuw, P. J. (1987). Silhouettes: A graphical aid to the interpretation and validation of cluster analysis. Journal of Computational and Applied Mathematics, 20, 53–65.

**Gap statistic:**
- Tibshirani, R., Walther, G., and Hastie, T. (2001). Estimating the number of clusters in a data set via the gap statistic. Journal of the Royal Statistical Society: Series B, 63(2), 411–423.

---

## Document Control

**Version History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-13 | Initial | Complete Phase 1 specifications |

**Review and Approval:**

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Lead Developer | | | |
| Technical Reviewer | | | |
| Project Owner | | | |

**Next Review Date:** After Phase 1 implementation complete

---

*End of Specification Document*
