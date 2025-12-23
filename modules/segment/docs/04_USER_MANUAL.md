# Turas Segmentation Module - User Manual

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
6. [Advanced Features](#advanced-features)
7. [Scoring New Data](#scoring-new-data)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required R Packages

```r
install.packages(c("readxl", "writexl", "cluster"))
```

### Optional Packages

```r
# For SPSS file support
install.packages("haven")

# For discriminant analysis
install.packages("MASS")

# For enhanced visualizations
install.packages(c("ggplot2", "fmsb"))

# For Latent Class Analysis
install.packages("poLCA")

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

Copy from `docs/templates/segment_config_template.xlsx`

**Option 2: Generate Programmatically**
```r
source("modules/segment/lib/segment_utils.R")
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
| `method` | kmeans | Clustering algorithm |
| `k_fixed` | (blank) | Fixed k for final run |
| `k_min` | 3 | Min k for exploration |
| `k_max` | 6 | Max k for exploration |
| `nstart` | 25 | Algorithm restarts |
| `seed` | 123 | Random seed |

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

See [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) for complete list.

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
- Green checkmark (✓) if valid
- Red error messages if issues found

**Step 3: Run Analysis**
- Click "Run Segmentation Analysis"
- Do not close browser during analysis

**Step 4: Monitor Console**
- Real-time progress in console output box
- Shows stage completion and metrics

**Step 5: View Results**
- Summary displays after completion
- Click file links to open outputs

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
source("modules/segment/lib/segment_utils.R")

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
| `seg_segment_profiles_k3.xlsx` | Profiles for k=3 |
| `seg_segment_profiles_k4.xlsx` | Profiles for k=4 |
| `seg_k_selection.png` | Elbow and silhouette plots |
| `seg_model.rds` | Saved model |

### Final Mode Output

| File | Content |
|------|---------|
| `seg_final_report.xlsx` | Complete segmentation report |
| `seg_assignments.xlsx` | Respondent-to-segment mapping |
| `seg_segment_sizes.png` | Size distribution chart |
| `seg_profiles_heatmap.png` | Visual profile comparison |
| `seg_model.rds` | Saved model |

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

### Enhanced Profiling

Get statistical significance:
```r
source("modules/segment/lib/segment_profiling_enhanced.R")

enhanced <- create_enhanced_profile_report(
  data = your_data,
  clusters = result$clusters,
  clustering_vars = config$clustering_vars,
  output_path = "output/enhanced_profile.xlsx"
)
```

**Output includes:**
- ANOVA p-values
- Effect sizes (eta-squared)
- Index scores (segment vs. overall)

### Segment Validation

Test quality and stability:
```r
source("modules/segment/lib/segment_validation.R")

validation <- validate_segmentation(
  data = your_data,
  clusters = result$clusters,
  clustering_vars = config$clustering_vars,
  k = 4,
  n_bootstrap = 100
)
```

**Metrics:**
- Stability (bootstrap): > 0.8 excellent
- Separation (Calinski-Harabasz): Higher is better
- Discrimination (LDA accuracy): > 90% excellent

### Visualizations

Create all standard plots:
```r
source("modules/segment/lib/segment_visualization.R")

create_all_visualizations(
  result = result,
  output_folder = "output/charts/",
  prefix = "seg_"
)
```

**Creates:**
- Segment sizes bar chart
- K-selection plots
- Profile heatmap
- Spider/radar chart

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
source("modules/segment/lib/segment_scoring.R")

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
- Segment names and sizes
- Key differentiating characteristics
- Recommended actions per segment

**For technical audience:**
- All validation metrics
- Method details
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
- Reduce `nstart` from 25 to 10
- Reduce k_max range
- Disable gap statistic

**Large output files:**
- Set `create_dated_folder = FALSE`
- Delete old run folders

### Methods Disagree

**Symptom:** Different k recommended by different metrics

**Resolution:**
1. Prioritize silhouette score
2. Consider practical interpretability
3. Test sensitivity by running final with k and k±1

---

## Additional Resources

- [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods reference
- [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) - Developer documentation
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Template field reference
- [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) - Practical examples

---

**Part of the Turas Analytics Platform**
