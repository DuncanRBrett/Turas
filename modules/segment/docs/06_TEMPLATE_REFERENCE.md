# Turas Segmentation Module - Template Reference

**Version:** 11.1
**Last Updated:** 19 March 2026
**Target Audience:** Analysts, Project Managers, Template Configurers

This document provides complete field-by-field reference for the Segmentation configuration templates.

---

## Table of Contents

1. [Overview](#overview)
2. [Optional Config Sheets](#optional-config-sheets)
   - [Labels Sheet](#labels-sheet)
   - [Insights Sheet](#insights-sheet)
   - [About Sheet](#about-sheet)
   - [Slides Sheet](#slides-sheet)
3. [Core Settings](#core-settings)
4. [Clustering Algorithm Settings](#clustering-algorithm-settings)
5. [Data Handling Settings](#data-handling-settings)
6. [Outlier Detection Settings](#outlier-detection-settings)
7. [Variable Selection Settings](#variable-selection-settings)
8. [K Selection Settings](#k-selection-settings)
9. [Output Settings](#output-settings)
10. [HTML Report Settings](#html-report-settings)
11. [Enhanced Features Settings](#enhanced-features-settings)
12. [Metadata Settings](#metadata-settings)
13. [Output Structure](#output-structure)
14. [Complete Examples](#complete-examples)
15. [Validation Rules](#validation-rules)

---

## Overview

### Available Templates

| Template | Purpose | Location |
|----------|---------|----------|
| Segment_Config_Template.xlsx | Main segmentation configuration | docs/templates/ |
| VarSel_Config_Template.xlsx | Variable selection configuration | docs/templates/ |

**Note:** There is no separate VarSel_Config sheet within the main config file. All variable selection parameters (`variable_selection`, `variable_selection_method`, `max_clustering_vars`, `varsel_min_variance`, `varsel_max_correlation`) are controlled via the main Config sheet's Settings tab. The VarSel_Config_Template.xlsx is a standalone template for running variable selection independently.

### Template Structure

Both templates use a consistent structure:

| Sheet | Purpose | Required |
|-------|---------|----------|
| Instructions | Usage documentation | No |
| Config | All analysis settings | Yes |
| Labels | Human-readable variable labels for charts and tables | No |
| Insights | Pre-populated analyst insights for HTML report sections | No |
| About | Project metadata for the HTML report About tab | No |
| Slides | Custom presentation slides for the HTML report Slides tab | No |

The Config sheet is the only required sheet. The four optional sheets (Labels, Insights, About, Slides) enrich the HTML report with additional context and are ignored when `html_report = FALSE`.

---

## Optional Config Sheets

The following sections describe the optional sheets that can be included in the Segment_Config_Template.xlsx file. These sheets provide additional metadata and content for the HTML report.

### Labels Sheet

The Labels sheet maps raw variable names (as they appear in the data file) to human-readable labels. These labels are used throughout the HTML report in chart axis labels, table headers, profile heatmaps, and variable importance displays. When a Labels sheet is not provided, raw variable names are displayed as-is.

**Columns:**

| Column | Required | Description |
|--------|----------|-------------|
| variable | Yes | The exact variable name as it appears in the data file (case-sensitive) |
| label | Yes | The human-readable label to display in reports |

**Example:**

```
variable | label
---------|----------------------------------
Q02      | Overall satisfaction
Q03      | Product quality
Q04      | Value for money
Q05      | Customer service
Q06      | Likelihood to recommend
Q07      | Brand trust
Q08      | Purchase intent
age      | Age group
gender   | Gender
tenure   | Years as customer
```

**Notes:**
- Labels apply to both clustering variables and profiling variables.
- Variables not listed in the Labels sheet retain their original column names.
- This sheet provides the same functionality as the `question_labels_file` setting in the Config sheet. If both are provided, the Labels sheet takes precedence.

---

### Insights Sheet

The Insights sheet allows the analyst to pre-populate the insight editor panels in the HTML report. Each row maps an insight to a specific report section. When the report is opened, these insights appear pre-filled in the corresponding section's insight editor, where they can be further edited by the report viewer before exporting slides.

**Columns:**

| Column | Required | Description |
|--------|----------|-------------|
| Section | Yes | The section key identifying which report section the insight belongs to |
| Insight | Yes | The insight text to pre-populate in that section's editor |

**Valid Section Keys:**

| Section Key | Report Section |
|-------------|----------------|
| `exec-summary` | Executive Summary |
| `overview` | Segment Overview (sizes and composition) |
| `validation` | Cluster Validation (silhouette and fit metrics) |
| `overlap` | Segment Overlap (if overlap analysis is enabled) |
| `importance` | Variable Importance (eta-squared analysis) |
| `golden-questions` | Golden Questions (key discriminating variables) |
| `profiles` | Segment Profiles (heatmap and profile table) |
| `vulnerability` | Vulnerability Analysis (if vulnerability analysis is enabled) |
| `comparison-method-choice` | Method Comparison and Choice (multi-method runs only) |

**Example:**

```
Section              | Insight
---------------------|-------------------------------------------------------
exec-summary         | Four distinct customer segments were identified, with
                     | the Premium Advocates segment showing the highest
                     | lifetime value potential.
overview             | The largest segment (Mainstream, 35%) represents the
                     | core customer base with moderate satisfaction scores.
validation           | Silhouette scores indicate well-separated clusters
                     | with minimal overlap between segments.
importance           | Brand trust and product quality are the two strongest
                     | differentiators across segments.
profiles             | The At-Risk segment scores significantly below average
                     | on customer service and value for money.
```

**Notes:**
- Multiple rows can use the same Section key to provide multiple insights for a single section.
- Section keys that do not match any visible report section are silently ignored.
- Insights are editable in the HTML report's built-in insight editor and are included when exporting slides.

---

### About Sheet

The About sheet provides project metadata that populates the About tab in the HTML report. This tab displays analyst details, project information, and any confidentiality notices or methodology notes.

**Columns:**

| Column | Required | Description |
|--------|----------|-------------|
| Setting | Yes | The setting key (case-insensitive) |
| Value | Yes | The value for that setting |

**Valid Settings:**

| Setting | Description | Example |
|---------|-------------|---------|
| `analyst` | Name of the analyst who ran the segmentation | `Jane Smith` |
| `company` | Company or organisation name | `The Research LampPost` |
| `email` | Contact email for queries about the analysis | `jane@example.com` |
| `project` | Project name or identifier | `Brand Health Tracker Q1 2026` |
| `client` | Client name (the party the analysis was prepared for) | `Acme Corporation` |
| `date` | Date of the analysis or report | `March 2026` |
| `confidentiality` | Confidentiality notice or classification | `Confidential - Internal Use Only` |
| `notes` | Methodology notes or additional context | `K-means with ward.D2 validation` |
| `methodology` | Alias for `notes`; either key is accepted | `Hierarchical clustering on 8 attitudinal variables` |

**Example:**

```
Setting          | Value
-----------------|----------------------------------------------
analyst          | Jane Smith
company          | The Research LampPost
email            | jane@lamppost.co.za
project          | Customer Segmentation Study
client           | Acme Corporation
date             | March 2026
confidentiality  | Confidential - Client Use Only
methodology      | K-means clustering on 8 attitudinal variables,
                 | Ward's method validation, n=1,200
```

**Notes:**
- Settings not listed in the About sheet are omitted from the About tab (no defaults are substituted).
- The `notes` and `methodology` settings are interchangeable; if both are provided, `methodology` takes precedence.
- The About tab is always available in the HTML report when at least one setting is provided.

---

### Slides Sheet

The Slides sheet defines custom presentation slides that appear in the Slides tab of the HTML report. This is useful for adding title slides, methodology descriptions, context slides, or any supplementary content that should accompany the analysis.

**Columns:**

| Column | Required | Description |
|--------|----------|-------------|
| Title | Yes | The slide title displayed as a heading |
| Content | Yes | The slide body text (supports plain text; line breaks are preserved) |
| Image | No | File path to an image to embed in the slide (PNG, JPG, or SVG) |

**Example:**

```
Title                  | Content                                    | Image
-----------------------|--------------------------------------------|---------------------------
Project Background     | This segmentation was commissioned to       |
                       | understand distinct customer groups within  |
                       | the South African retail market.            |
Methodology            | Eight attitudinal variables were selected   | methodology_diagram.png
                       | based on factor analysis. K-means clustering|
                       | was applied with k=4.                       |
Key Recommendations    | Focus acquisition spend on the Growth       |
                       | segment, which shows highest intent but     |
                       | lowest current penetration.                 |
```

**Notes:**
- The Image column accepts relative file paths (resolved relative to the config file location) or absolute file paths.
- Images are base64-encoded and embedded directly into the HTML report, so the report remains a self-contained single file.
- Supported image formats are PNG, JPG/JPEG, and SVG.
- If the Image column is left blank for a row, the slide contains only the title and text content.
- If a referenced image file cannot be found, the slide is still created but without the image, and a warning is logged to the console.
- Slides appear in the Slides tab in the same order as the rows in the sheet.

---

## Core Settings

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
- **Default:** Data
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

## Clustering Algorithm Settings

#### method

- **Purpose:** Clustering algorithm
- **Required:** No
- **Default:** `kmeans`
- **Valid Values:** `kmeans`, `hclust`, `gmm`, comma-separated list (e.g., `kmeans,hclust,gmm`), or `all`
- **Notes:**
  - `kmeans` - K-means clustering (default, fast, scalable)
  - `hclust` - Hierarchical agglomerative clustering (dendrogram, limited to ~15k rows)
  - `gmm` - Gaussian Mixture Models via mclust (soft assignments, requires `mclust` package)
  - `all` expands to `kmeans,hclust,gmm`
  - Comma-separated values (e.g., `kmeans,hclust,gmm`) or `all` - Run multiple methods and produce a combined tabbed HTML report with per-method results and a comparison tab
  - **LCA** is not a `method` value. To include LCA, set `use_lca = TRUE` separately.

#### k_fixed

- **Purpose:** Fixed number of segments
- **Required:** No (blank = exploration mode)
- **Data Type:** Integer or blank
- **Valid Values:** 2 or greater, or blank
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
- **Valid Values:** 2-15
- **Default:** `6`

#### nstart

- **Purpose:** Number of random starts for K-means
- **Required:** No
- **Data Type:** Integer
- **Valid Values:** 1-200
- **Default:** `50`
- **Notes:** Higher = more stable but slower. Only applies to K-means.

#### seed

- **Purpose:** Random seed for reproducibility
- **Required:** No
- **Data Type:** Integer
- **Default:** `123`

#### linkage_method

- **Purpose:** Linkage method for hierarchical clustering
- **Required:** No (only used when method = hclust)
- **Data Type:** Text
- **Default:** `ward.D2`
- **Valid Values:** `ward.D`, `ward.D2`, `single`, `complete`, `average`, `mcquitty`, `median`, `centroid`
- **Notes:**
  - `ward.D2` is the most commonly used for survey segmentation
  - `complete` produces compact, well-separated clusters
  - `average` is a balanced compromise
  - Ignored when method is not hclust

#### gmm_model_type

- **Purpose:** Covariance structure for GMM clustering
- **Required:** No (only used when method = gmm)
- **Data Type:** Text or blank
- **Default:** Blank (auto-select by BIC)
- **Valid Values:** `EII`, `VII`, `EEI`, `VEI`, `EVI`, `VVI`, `EEE`, `VEE`, `EVE`, `VVE`, `EEV`, `VEV`, `EVV`, `VVV`, or blank
- **Notes:**
  - Leave blank (recommended) to let mclust automatically select the best model by BIC
  - `VVV` is the most flexible (variable volume, shape, and orientation)
  - `EEE` constrains all components to have the same covariance
  - Ignored when method is not gmm

#### lca_n_classes

- **Purpose:** Number of latent classes for LCA
- **Required:** No (only used when method = lca)
- **Data Type:** Integer or blank
- **Default:** Uses `k_fixed` (final mode) or `k_min:k_max` range (exploration mode)
- **Notes:**
  - If set, overrides k_fixed/k_min/k_max for LCA specifically
  - Ignored when method is not lca

#### lca_max_iter

- **Purpose:** Maximum EM iterations for LCA estimation
- **Required:** No (only used when method = lca)
- **Data Type:** Integer
- **Valid Values:** 100-10000
- **Default:** `1000`
- **Notes:**
  - Increase if model fails to converge
  - Ignored when method is not lca

#### lca_n_rep

- **Purpose:** Number of random starting values for LCA
- **Required:** No (only used when method = lca)
- **Data Type:** Integer
- **Valid Values:** 1-100
- **Default:** `10`
- **Notes:**
  - Higher values reduce risk of local optima but increase runtime
  - Analogous to `nstart` for K-means
  - Ignored when method is not lca

---

## Data Handling Settings

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

#### scale_max

- **Purpose:** Maximum scale value for profile interpretation
- **Required:** No
- **Data Type:** Numeric
- **Default:** Auto-detected from data
- **Example:** `10` (for 1-10 scales)
- **Notes:** Used by auto-naming and action card generators

---

## Outlier Detection Settings

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

## Variable Selection Settings

#### variable_selection

- **Purpose:** Enable automatic variable reduction
- **Required:** No
- **Default:** `FALSE`
- **Notes:** Reduces 20+ variables to optimal subset

#### variable_selection_method

- **Purpose:** Selection algorithm
- **Required:** Only if variable_selection = TRUE
- **Default:** `variance_correlation`
- **Valid Values:**
  - `variance_correlation` - Remove low variance, high correlation
  - `factor_analysis` - Use factor loadings
  - `both` - Two-stage selection

#### max_clustering_vars

- **Purpose:** Target number of variables to keep
- **Required:** Only if variable_selection = TRUE
- **Data Type:** Integer
- **Valid Values:** 2-20
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

## K Selection Settings

#### k_selection_metrics

- **Purpose:** Metrics for choosing optimal k
- **Required:** No
- **Data Type:** Text (comma-separated)
- **Default:** `silhouette,elbow`
- **Valid Values:** `silhouette`, `elbow`, `gap`

---

## Output Settings

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

## HTML Report Settings

#### html_report

- **Purpose:** Enable or disable HTML report generation
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `FALSE`
- **Notes:** Set to TRUE to generate an interactive HTML report in addition to Excel files

#### brand_colour

- **Purpose:** Primary brand colour used for headers, nav bar, chart bars, and section titles
- **Required:** No
- **Data Type:** Hex colour string
- **Default:** `#323367`
- **Example:** `#1A5276`
- **Notes:** Must include the `#` prefix. British spelling (`colour` not `color`).

#### accent_colour

- **Purpose:** Secondary colour used for highlights, recommended-k markers, and warning indicators
- **Required:** No
- **Data Type:** Hex colour string
- **Default:** `#CC9900`
- **Example:** `#E67E22`

#### report_title

- **Purpose:** Title displayed in the report header and browser tab
- **Required:** No
- **Data Type:** Text
- **Default:** Value of `project_name`, or `"Segmentation Analysis"` if neither is set
- **Example:** `Customer Segmentation Q1 2026`

#### html_show_exec_summary

- **Purpose:** Show Executive Summary section in HTML report
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `TRUE`

#### html_show_overview

- **Purpose:** Show Segment Overview section (sizes chart + composition table)
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `TRUE`

#### html_show_validation

- **Purpose:** Show Cluster Validation section (silhouette chart + metrics table)
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `TRUE`

#### html_show_importance

- **Purpose:** Show Variable Importance section (eta-squared bar chart)
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `TRUE`

#### html_show_profiles

- **Purpose:** Show Segment Profiles section (heatmap + profile table)
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `TRUE`

#### html_show_rules

- **Purpose:** Show Classification Rules section
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `TRUE`
- **Notes:** Requires `generate_rules = TRUE` for rules data to be available

#### html_show_cards

- **Purpose:** Show Segment Action Cards section
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `TRUE`

#### html_show_guide

- **Purpose:** Show Interpretation Guide section
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `TRUE`

---

## Enhanced Features Settings

#### generate_rules

- **Purpose:** Generate classification rules using decision trees
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `FALSE`
- **Notes:** Produces plain-English IF-THEN rules. Requires `rpart` package.

#### rules_max_depth

- **Purpose:** Maximum depth of the decision tree for classification rules
- **Required:** No
- **Data Type:** Integer
- **Valid Values:** 1-5
- **Default:** `3`

#### generate_action_cards

- **Purpose:** Generate executive-ready segment action cards
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `FALSE`
- **Notes:** Cards include strengths, pain points, and recommended actions.

#### run_stability_check

- **Purpose:** Run stability assessment across multiple random seeds
- **Required:** No
- **Data Type:** TRUE/FALSE
- **Default:** `FALSE`
- **Notes:** Runs the clustering algorithm multiple times to assess consistency.

#### stability_n_runs

- **Purpose:** Number of runs for stability assessment
- **Required:** No (only used if run_stability_check = TRUE)
- **Data Type:** Integer
- **Valid Values:** 3-20
- **Default:** `5`

#### auto_name_style

- **Purpose:** Style for automatic segment naming
- **Required:** No
- **Data Type:** Text
- **Default:** `descriptive`
- **Valid Values:** `descriptive`, `persona`, `simple`
- **Notes:**
  - `descriptive` - Generate names based on segment characteristics (e.g., "High Satisfaction Advocates")
  - `persona` - Generate persona-style names
  - `simple` - Simple labels

---

## Metadata Settings

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

## Output Structure

### Exploration Mode Output

| File | Content |
|------|---------|
| seg_k_selection_report.xlsx | Metrics_Comparison, Recommendation, Profile_k3, Profile_k4, ... |
| seg_exploration_report.html | Interactive HTML with elbow plot, silhouette chart, solution previews |
| seg_segment_profiles_k3.xlsx | Profiles, Statistics |
| seg_segment_profiles_k4.xlsx | Profiles, Statistics |
| seg_model.rds | Saved model object |

### Final Mode Output

| File | Content |
|------|---------|
| seg_final_report.xlsx | Summary, Profiles, Statistics, Validation |
| seg_final_report.html | Interactive HTML with all configured sections |
| seg_assignments.xlsx | ID + segment_id + segment_name (+ probabilities if GMM or LCA) |
| seg_model.rds | Saved model object |

### Assignments File Detail

**Standard columns (all methods):**

| Column | Type | Description |
|--------|------|-------------|
| (ID column) | Varies | Respondent identifier |
| segment_id | Integer | Numeric segment assignment (1, 2, 3, ...) |
| segment_name | Text | Segment label |

**Additional columns (GMM and LCA):**

| Column | Type | Description |
|--------|------|-------------|
| prob_segment_1 | Decimal | Probability of belonging to segment 1 |
| prob_segment_2 | Decimal | Probability of belonging to segment 2 |
| ... | ... | One column per segment |
| max_probability | Decimal | Highest probability across segments |
| uncertainty | Decimal | 1 - max_probability |

### Output Sheets Detail

**Summary Sheet:**
- Analysis name and date
- Data file and settings
- Clustering method and parameters
- Number of segments and sizes
- Silhouette score
- Method-specific metrics (linkage method, cophenetic correlation, BIC)

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
- Method-specific metrics
- Stability metrics (if enabled)

---

## Complete Examples

### K-Means Exploration Configuration

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
html_report            | TRUE
brand_colour           | #323367
accent_colour          | #CC9900
report_title           | Customer Segmentation Exploration
project_name           | Customer Segmentation
```

### K-Means Final Configuration

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
html_report            | TRUE
brand_colour           | #1A5276
report_title           | Customer Segmentation Final
generate_rules         | TRUE
rules_max_depth        | 3
generate_action_cards  | TRUE
run_stability_check    | TRUE
stability_n_runs       | 10
html_show_exec_summary | TRUE
html_show_rules        | TRUE
project_name           | Customer Segmentation Final
```

### Hierarchical Clustering Configuration

```
Setting                | Value
-----------------------|--------------------------------
data_file              | data/satisfaction_survey.csv
id_variable            | ResponseID
clustering_vars        | Q02,Q03,Q04,Q05,Q06,Q07,Q08
k_fixed                | 4
method                 | hclust
linkage_method         | ward.D2
seed                   | 123
missing_data           | listwise_deletion
standardize            | TRUE
segment_names          | auto
save_model             | TRUE
output_folder          | output/hclust/
output_prefix          | seg_
html_report            | TRUE
brand_colour           | #2C3E50
report_title           | Hierarchical Segmentation
generate_action_cards  | TRUE
project_name           | Hierarchical Clustering Analysis
```

### GMM Configuration

```
Setting                | Value
-----------------------|--------------------------------
data_file              | data/satisfaction_survey.csv
id_variable            | ResponseID
clustering_vars        | Q02,Q03,Q04,Q05,Q06,Q07,Q08
k_fixed                | 4
method                 | gmm
gmm_model_type         | [BLANK]
seed                   | 123
missing_data           | listwise_deletion
standardize            | TRUE
segment_names          | auto
save_model             | TRUE
output_folder          | output/gmm/
output_prefix          | seg_
html_report            | TRUE
brand_colour           | #8E44AD
report_title           | GMM Segmentation
generate_action_cards  | TRUE
project_name           | Gaussian Mixture Model Analysis
```

### LCA Configuration

```
Setting                | Value
-----------------------|--------------------------------
data_file              | data/satisfaction_survey.csv
id_variable            | ResponseID
clustering_vars        | Q02,Q03,Q04,Q05,Q06,Q07,Q08
k_fixed                | 4
method                 | lca
lca_max_iter           | 1000
lca_n_rep              | 10
seed                   | 123
missing_data           | listwise_deletion
standardize            | FALSE
segment_names          | auto
save_model             | TRUE
output_folder          | output/lca/
output_prefix          | seg_
html_report            | TRUE
brand_colour           | #16A085
report_title           | LCA Segmentation
generate_action_cards  | TRUE
project_name           | Latent Class Analysis
```

**Notes:** LCA works best with categorical or ordinal variables (e.g., Likert scales). Set `standardize = FALSE` since LCA operates on raw categorical values, not z-scores.

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
method                    | kmeans
k_min                     | 3
k_max                     | 6
html_report               | TRUE
output_folder             | output/varsel/
project_name              | Variable Selection Test
```

### HTML Report Customisation Configuration

```
Setting                  | Value
-------------------------|--------------------------------
html_report              | TRUE
brand_colour             | #D35400
accent_colour            | #27AE60
report_title             | Brand Perception Segmentation
html_show_exec_summary   | TRUE
html_show_overview       | TRUE
html_show_validation     | TRUE
html_show_importance     | TRUE
html_show_profiles       | TRUE
html_show_rules          | FALSE
html_show_cards          | TRUE
html_show_guide          | FALSE
```

---

## Validation Rules

### Settings Validation

| Setting | Validation |
|---------|------------|
| data_file | File must exist, valid format |
| id_variable | Column must exist in data |
| clustering_vars | All columns must exist, must be numeric |
| k_fixed | Integer 2 or greater, or blank |
| k_min | Integer 2-10, less than k_max |
| k_max | Integer 2-10, greater than k_min |
| method | One of: kmeans, hclust, gmm, comma-separated list, or all |
| nstart | Integer 1-200 |
| linkage_method | One of: ward.D, ward.D2, single, complete, average, mcquitty, median, centroid |
| gmm_model_type | Valid mclust model name or blank |
| missing_data | One of: listwise_deletion, mean_imputation, median_imputation, refuse |
| outlier_method | One of: zscore, mahalanobis |
| outlier_threshold | Numeric 1.0-5.0 |
| variable_selection_method | One of: variance_correlation, factor_analysis, both |
| html_report | TRUE or FALSE |
| brand_colour | Valid hex colour with # prefix |
| accent_colour | Valid hex colour with # prefix |

### Method-Specific Validation

| Method | Constraint | Guard |
|--------|-----------|-------|
| hclust | Dataset must be under ~15,000 rows | `guard_require_hclust_size()` |
| gmm | Package `mclust` must be installed | `guard_require_method_packages()` |
| lca | Package `poLCA` must be installed; variables should be categorical/ordinal | `guard_require_method_packages()` |
| kmeans | No specific constraints | - |

### Sample Size Validation

```
Minimum n = max(100, k * 30, n_vars * 10)

Examples:
- k = 4, n_vars = 7  -> need >= max(100, 120, 70) = 120 complete cases
- k = 6, n_vars = 12 -> need >= max(100, 180, 120) = 180 complete cases
```

### Variable Requirements

| Rule | Message |
|------|---------|
| At least 2 clustering vars | "Need at least 2 clustering variables" |
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
