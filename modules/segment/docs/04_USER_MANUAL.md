# Turas Segmentation Module - User Manual

**Version:** 11.0
**Last Updated:** 5 March 2026
**Target Audience:** Market Researchers, Data Analysts, Survey Managers

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Data Preparation](#data-preparation)
3. [Configuration Guide](#configuration-guide)
4. [Method Selection Guidance](#method-selection-guidance)
5. [Running the Analysis](#running-the-analysis)
6. [Understanding Output](#understanding-output)
7. [HTML Report](#html-report)
8. [Advanced Features](#advanced-features)
9. [Scoring New Data](#scoring-new-data)
10. [Best Practices](#best-practices)
11. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required R Packages

```r
install.packages(c("readxl", "writexl", "cluster", "openxlsx", "htmltools"))
```

### Optional Packages

```r
# For Gaussian Mixture Models
install.packages("mclust")

# For faster hierarchical clustering
install.packages("fastcluster")

# For SPSS file support
install.packages("haven")

# For discriminant analysis
install.packages("MASS")

# For enhanced visualizations
install.packages(c("ggplot2", "fmsb"))

# For Latent Class Analysis
install.packages("poLCA")

# For classification rules
install.packages("rpart")

# For GUI
install.packages(c("shiny", "shinyFiles"))
```

### System Requirements

- R version 4.0 or higher (4.2+ recommended for GUI)
- 4GB+ RAM for standard analyses
- 8GB+ RAM for large datasets (n > 10,000)

---

## Data Preparation

### Data Format Requirements

Your survey data must be structured as:
- **Rows:** Individual respondents
- **Columns:** Variables (questions, demographics, etc.)
- **Format:** CSV or Excel (.xlsx, .xls) or SPSS (.sav)

**Example Data Structure:**

| respondent_id | q1 | q2 | q3 | age | gender |
|---------------|----|----|----|----|--------|
| 1001          | 8  | 7  | 9  | 35 | M      |
| 1002          | 3  | 4  | 2  | 42 | F      |
| 1003          | 9  | 9  | 8  | 28 | M      |

### Choosing Clustering Variables

**Good Clustering Variables:**
- Satisfaction ratings (1-10 scales)
- Behavioral frequencies (1-5 scales)
- Importance ratings
- Likelihood measures
- Numeric continuous variables

**Avoid:**
- Categorical text (use numeric codes)
- Open-ended responses
- Constants (everyone answered same)
- Unique identifiers
- Demographics (use for profiling, not clustering)

### Sample Size Requirements

| Respondents | Recommended k | Notes |
|-------------|---------------|-------|
| 100-200 | 2-3 | Limited options |
| 200-500 | 3-5 | Comfortable range |
| 500-1000 | 4-6 | Good flexibility |
| 1000+ | Up to 8 | More granular |

**Rule of thumb:** At least 30-50 respondents per segment.

### Missing Data Considerations

- **< 5% missing:** Usually fine with listwise deletion
- **5-15% missing:** Use mean/median imputation
- **> 15% missing:** Consider excluding variable
- **> 30% missing:** Definitely exclude

Check missing data before running:
```r
summary(your_data)  # Shows NA counts
```

---

## Configuration Guide

### Configuration File Structure

The config file has 1-2 sheets:

| Sheet | Purpose | Required |
|-------|---------|----------|
| Config | All analysis settings | Yes |
| Instructions | Documentation | No |

### Creating a Configuration File

**Option 1: Use Template**

Copy from `docs/templates/Segment_Config_Template.xlsx`

**Option 2: Generate Programmatically**
```r
source("modules/segment/R/10_utilities.R")
generate_config_template(
  data_file = "data/survey.csv",
  output_file = "config/my_segmentation.xlsx",
  mode = "exploration"
)
```

### Key Configuration Parameters

#### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `data_file` | Path to survey data | `data/survey.csv` |
| `id_variable` | Respondent ID column | `respondent_id` |
| `clustering_vars` | Variables to cluster on | `q1,q2,q3,q4,q5` |

#### Clustering Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `method` | kmeans | Clustering algorithm: `kmeans`, `hclust`, or `gmm` |
| `k_fixed` | (blank) | Fixed k for final run |
| `k_min` | 3 | Min k for exploration |
| `k_max` | 6 | Max k for exploration |
| `nstart` | 25 | Algorithm restarts (K-means only) |
| `seed` | 123 | Random seed |
| `linkage_method` | ward.D2 | Linkage for hierarchical clustering |
| `gmm_model_type` | (auto) | GMM covariance structure |

#### Data Handling

| Parameter | Default | Description |
|-----------|---------|-------------|
| `missing_data` | listwise_deletion | Missing value strategy |
| `missing_threshold` | 15 | Max % missing per variable |
| `standardize` | TRUE | Standardize before clustering |
| `min_segment_size_pct` | 10 | Minimum segment size |

#### Output Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `output_folder` | output/ | Results location |
| `output_prefix` | seg_ | Filename prefix |
| `segment_names` | auto | Custom names or auto |
| `save_model` | TRUE | Save for scoring |
| `html_report` | TRUE | Generate HTML report |
| `brand_colour` | #323367 | HTML report primary colour |
| `accent_colour` | #CC9900 | HTML report accent colour |
| `report_title` | (auto) | HTML report title |

#### Enhanced Features

| Parameter | Default | Description |
|-----------|---------|-------------|
| `generate_rules` | FALSE | Generate classification rules |
| `generate_action_cards` | TRUE | Generate segment action cards |
| `run_stability_check` | FALSE | Run stability assessment |
| `auto_name_style` | descriptive | Segment naming style |

See [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) for complete list.

---

## Method Selection Guidance

### When to Use K-Means

- **Default choice** for most survey segmentation
- Data is continuous numeric (ratings, scales)
- Sample size from 100 to 50,000+
- You expect roughly spherical, equal-sized clusters
- Speed is important

### When to Use Hierarchical Clustering

- You want to **explore nested structure** before choosing k
- Sample size is under ~15,000 (distance matrix constraint)
- You need a **deterministic** result (no random initialization)
- Dendrogram visualization is important for stakeholders
- You want to experiment with different **linkage methods**

**Choosing a linkage method:**
- `ward.D2` (default): Best for balanced, compact clusters
- `complete`: When you need well-separated clusters
- `average`: When cluster sizes vary substantially

### When to Use GMM

- You expect **overlapping segments** (respondents between groups)
- You need **probability-based** assignments (soft clustering)
- Clusters may be **elliptical** rather than spherical
- You want **uncertainty quantification** per respondent
- BIC-based model selection is preferred over heuristics

---

## Running the Analysis

### Using the GUI (Recommended)

**Launch the GUI:**
```r
source("modules/segment/run_segment_gui.R")
run_segment_gui()
```

**5-Step Workflow:**

**Step 1: Select Configuration File**
- Click "Browse..." to locate your config Excel file
- File path displays once selected

**Step 2: Validate Configuration**
- Click "Validate Configuration"
- Green checkmark if valid
- Red error messages if issues found

**Step 3: Run Analysis**
- Click "Run Segmentation Analysis"
- Do not close browser during analysis

**Step 4: Monitor Console**
- Real-time progress in console output box
- Shows stage completion, method, and metrics

**Step 5: View Results**
- Summary displays after completion
- Click file links to open outputs
- Open the HTML report in your browser for interactive exploration

### Using Command Line

**Basic Usage:**
```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("config.xlsx")
```

**With Explicit Paths:**
```r
result <- turas_segment_from_config(
  config_file = "config/my_config.xlsx"
)
```

### Quick Run (No Config File)

```r
source("modules/segment/R/10_utilities.R")

# Exploration mode
result <- run_segment_quick(
  data = survey_data,
  id_var = "respondent_id",
  clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
  k = NULL,  # NULL = exploration
  k_range = 3:6
)

# Final mode
result <- run_segment_quick(
  data = survey_data,
  id_var = "respondent_id",
  clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
  k = 4
)
```

---

## Understanding Output

### Exploration Mode Output

| File | Content |
|------|---------|
| `seg_exploration_report.xlsx` | K-selection metrics |
| `seg_exploration_report.html` | Interactive HTML exploration report |
| `seg_segment_profiles_k3.xlsx` | Profiles for k=3 |
| `seg_segment_profiles_k4.xlsx` | Profiles for k=4 |
| `seg_k_selection.png` | Elbow and silhouette plots |
| `seg_model.rds` | Saved model |

### Final Mode Output

| File | Content |
|------|---------|
| `seg_final_report.xlsx` | Complete segmentation report |
| `seg_final_report.html` | Interactive HTML report with all sections |
| `seg_assignments.xlsx` | Respondent-to-segment mapping |
| `seg_segment_sizes.png` | Size distribution chart |
| `seg_profiles_heatmap.png` | Visual profile comparison |
| `seg_model.rds` | Saved model |

### Segment Assignments File

The `seg_assignments.xlsx` file contains:

| Column | Description |
|--------|-------------|
| (ID column) | Respondent identifier |
| segment_id | Numeric segment assignment (1, 2, 3, ...) |
| segment_name | Segment label |

**Additional columns for GMM (method = gmm):**

| Column | Description |
|--------|-------------|
| prob_segment_1 | Probability of belonging to segment 1 |
| prob_segment_2 | Probability of belonging to segment 2 |
| ... | ... |
| max_probability | Highest probability across segments |
| uncertainty | 1 - max_probability |

### Reading the Exploration Report

**Metrics_Comparison Sheet:**

| k | tot.withinss | avg_silhouette_width |
|---|--------------|----------------------|
| 3 | 1250.5       | 0.42                 |
| 4 | 980.3        | 0.51                 |
| 5 | 890.1        | 0.48                 |

**How to choose k:**
- **Silhouette:** Higher is better (> 0.5 is good)
- **Elbow:** Look for bend in WCSS plot
- **Practical:** Can you describe each segment?

### Reading Segment Profiles

**Example Profile Sheet:**

| Variable | Segment_1 | Segment_2 | Segment_3 | Overall |
|----------|-----------|-----------|-----------|---------|
| Product quality | 8.5 | 6.2 | 3.1 | 7.1 |
| Service quality | 8.3 | 6.5 | 2.8 | 7.0 |

**Interpreting:**
- Segment 1: "Advocates" - High across all (8+)
- Segment 2: "Satisfied" - Mid-range (6-7)
- Segment 3: "Detractors" - Low across all (< 4)

### Segment Naming Best Practices

**Good names are:**
- Descriptive: Captures defining characteristic
- Action-oriented: Suggests strategy
- Memorable: Easy to reference

**Examples:**
- Advocates, Satisfied, At-Risk, Detractors
- Premium Seekers, Value Hunters, Service-Focused

---

## HTML Report

### Overview

v11.0 generates interactive, self-contained HTML reports alongside the standard Excel outputs. Reports include SVG charts, sticky navigation, pinned views, and slide export capabilities.

### Enabling the Report

Set `html_report = TRUE` in your config (this is the default).

### Customising the Report

| Parameter | Default | Description |
|-----------|---------|-------------|
| `brand_colour` | #323367 | Primary colour for headers, nav, charts |
| `accent_colour` | #CC9900 | Highlight colour for markers, badges |
| `report_title` | (auto) | Title in report header |
| `html_show_exec_summary` | TRUE | Executive summary section |
| `html_show_overview` | TRUE | Segment sizes chart and table |
| `html_show_validation` | TRUE | Silhouette chart and metrics |
| `html_show_importance` | TRUE | Variable importance bar chart |
| `html_show_profiles` | TRUE | Profile heatmap and table |
| `html_show_rules` | FALSE | Classification rules table |
| `html_show_cards` | TRUE | Segment action cards |
| `html_show_guide` | TRUE | Interpretation guide |

### Using the Report

1. Open the `.html` file in any modern browser
2. Use the sticky nav bar to jump between sections
3. Hover over charts and tables to reveal the pin button
4. Pin important views to the Pinned Views workspace at the bottom
5. Use "Export All as PNG" to save pinned views for presentations
6. Use "Print / PDF" for a formatted print layout

See [08_HTML_REPORT_GUIDE.md](08_HTML_REPORT_GUIDE.md) for complete reference.

---

## Advanced Features

### Outlier Detection

Enable in config:
```
outlier_detection = TRUE
outlier_method = zscore
outlier_threshold = 3.0
outlier_handling = flag
```

**Methods:**
- `zscore`: Simple, fast, flags if |z| > threshold
- `mahalanobis`: Multivariate, accounts for correlations

**Handling:**
- `flag`: Keep in data, mark in output
- `remove`: Exclude from clustering

### Variable Selection

Enable when you have 15+ variables:
```
variable_selection = TRUE
variable_selection_method = variance_correlation
max_clustering_vars = 10
```

**Process:**
1. Remove low-variance variables
2. Remove highly correlated pairs
3. Select top N by variance

### Classification Rules

Generate plain-English decision rules:
```
generate_rules = TRUE
rules_max_depth = 3
```

Rules appear in the HTML report (when `html_show_rules = TRUE`) and in the Excel output. They provide stakeholders with simple "IF-THEN" logic for segment assignment.

### Segment Action Cards

Generate executive-ready action cards:
```
generate_action_cards = TRUE
```

Cards include:
- Segment name and size
- Defining characteristics
- Strengths (highest-scoring variables)
- Pain points (lowest-scoring variables)
- Recommended actions

### Stability Assessment

Test solution robustness:
```
run_stability_check = TRUE
stability_n_runs = 10
```

Runs the clustering algorithm multiple times with different random seeds and reports consistency metrics. Higher stability (> 90%) indicates a robust solution.

### Executive Summary

Auto-generated narrative overview of the segmentation solution, including:
- Quality assessment (Excellent/Good/Moderate/Limited)
- Key findings (dominant segment, smallest segment, top differentiators)
- Contextual insights derived from profile data

The executive summary appears in the HTML report and is generated by `generate_segment_executive_summary()` in `R/12_executive_summary.R`.

### Enhanced Profiling

Get statistical significance:
```r
# This is run automatically during the main pipeline
# To run standalone:
source("modules/segment/R/05a_profiling_stats.R")
```

**Output includes:**
- ANOVA p-values
- Effect sizes (eta-squared)
- Index scores (segment vs. overall)
- Variable importance rankings

### Segment Validation

Test quality and stability:
```r
source("modules/segment/R/04_validation.R")
```

**Metrics:**
- Stability (bootstrap): > 0.8 excellent
- Separation (Calinski-Harabasz): Higher is better
- Discrimination (LDA accuracy): > 90% excellent

---

## Scoring New Data

### Why Score New Data?

- Assign new respondents to existing segments
- Track segment evolution over time
- Apply segments to ongoing data collection

### How to Score

**Step 1: Ensure model was saved**
```
save_model = TRUE  # in original config
```

**Step 2: Score new data**
```r
source("modules/segment/R/08_scoring.R")

scores <- score_new_data(
  model_file = "output/seg_model.rds",
  new_data = new_survey,
  id_variable = "respondent_id",
  output_file = "output/new_scores.xlsx"
)
```

**Output:**
- `segment`: Assigned segment number
- `segment_name`: Segment name
- `distance_to_center`: Distance from centroid
- `assignment_confidence`: Confidence score (0-1)

### Single Respondent Typing

```r
result <- type_respondent(
  answers = c(q1 = 8, q2 = 7, q3 = 9),
  model_file = "output/seg_model.rds"
)
# Returns: segment, segment_name, confidence
```

### Monitoring Segment Drift

```r
drift <- compare_segment_distributions(
  model_file = "output/seg_model.rds",
  scoring_result = scores
)
```

If significant drift (> 10% change), consider re-segmenting.

---

## Best Practices

### Variable Selection

**How many:** 5-12 optimal (15 maximum)

**Which variables:**
- Theory-driven (conceptual framework)
- Actionable (can you improve it?)
- Distinct (not redundant)

**Avoid:**
- Perfectly correlated (|r| > 0.95)
- Demographics (use for profiling only)
- Too many (> 15 without selection)

### Choosing Number of Segments

**Guidelines:**
- k = 2-3: Simple but may oversimplify
- k = 4-5: Sweet spot for most cases
- k = 6-8: Complex, needs justification
- k = 9+: Too many, likely overfitting

**Consider:**
- Can you describe each segment?
- Can you action each differently?
- Do stakeholders understand them?

### Data Quality Checklist

Before running:
- [ ] No duplicate respondent IDs
- [ ] All clustering variables numeric
- [ ] Missing data < 20% per variable
- [ ] At least 100 complete cases
- [ ] Variables have reasonable variance
- [ ] Scale consistency (all 1-10 or convert)

### Multicollinearity

**Before analysis:**
- Check correlation matrix for |r| > 0.80
- Consider combining highly correlated variables

**After analysis:**
- If segments unstable, enable variable selection
- Remove one of correlated pairs

### Reporting Results

**For executives:**
- Share the HTML report with executive summary
- Segment names and sizes
- Key differentiating characteristics
- Action cards with recommended actions per segment

**For technical audience:**
- All validation metrics
- Method details (algorithm, linkage, covariance structure)
- Limitations and assumptions

---

## Troubleshooting

### Common Errors

**"Missing clustering variables in data"**
- Variable names don't match (case-sensitive)
- Check exact spelling in config vs. data

**"Not enough complete cases"**
- Too much missing data
- Use `missing_data = mean_imputation`
- Or remove high-missing variables

**"Segment smaller than minimum size"**
- Reduce `min_segment_size_pct`
- Or try different k value

**"Variable has zero variance"**
- Everyone answered the same
- Remove constant variable from clustering_vars

**"PKG_MCLUST_MISSING"**
- GMM method requires mclust package
- Install: `install.packages("mclust")`

**"PKG_HTMLTOOLS_MISSING"**
- HTML report requires htmltools package
- Install: `install.packages("htmltools")`

### GUI-Specific Issues

**Grey screen when launching**
- Update to latest code version
- Check R 4.2+ installed

**Console output not displaying**
- Refresh browser
- Check R console for errors

**Results not displaying**
- Ensure analysis actually completed
- Look for errors in R console

### Performance Issues

**Segmentation takes too long:**
- Reduce `nstart` from 25 to 10 (K-means)
- Reduce k_max range
- Disable gap statistic
- For hierarchical: reduce dataset or switch to K-means (hclust is O(n^2))

**Large output files:**
- Set `create_dated_folder = FALSE`
- Delete old run folders

### Methods Disagree

**Symptom:** Different k recommended by different metrics

**Resolution:**
1. Prioritize silhouette score
2. Consider practical interpretability
3. Test sensitivity by running final with k and k+/-1

---

## Additional Resources

- [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods reference
- [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) - Developer documentation
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Template field reference
- [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) - Practical examples
- [08_HTML_REPORT_GUIDE.md](08_HTML_REPORT_GUIDE.md) - HTML report reference

---

**Part of the Turas Analytics Platform**
