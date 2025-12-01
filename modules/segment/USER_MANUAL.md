# Turas Segmentation Module - User Manual

**Comprehensive Guide to Customer Segmentation with Turas**

Version 1.0 | Last Updated: 2024

---

## Table of Contents

1. [Introduction](#introduction)
2. [Installation & Setup](#installation--setup)
3. [Data Preparation](#data-preparation)
4. [Configuration Reference](#configuration-reference)
5. [Running Segmentation](#running-segmentation)
6. [Understanding Results](#understanding-results)
7. [Advanced Features](#advanced-features)
8. [Scoring New Data](#scoring-new-data)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

---

## 1. Introduction

### What is Segmentation?

Customer segmentation divides your respondents into distinct groups (segments) based on their similarities in attitudes, behaviors, or satisfaction levels. The Turas Segmentation Module uses **k-means clustering**, a proven statistical method for creating data-driven segments.

###  When to Use Segmentation

**Use segmentation when you want to:**
- Identify distinct customer groups in your survey data
- Tailor marketing strategies to different customer types
- Understand which customer groups are most/least satisfied
- Prioritize product development for specific segments
- Create targeted communication strategies

**You need:**
- Survey data with 100+ respondents (300+ ideal)
- 5-20 numeric variables (satisfaction ratings, behavioral metrics, etc.)
- Variables that you believe differentiate customers

### Key Features

✅ **Automatic k-selection**: Finds optimal number of segments
✅ **Variable selection**: Automatically chooses best clustering variables
✅ **Outlier detection**: Identifies and handles extreme respondents
✅ **Statistical validation**: Tests segment quality and stability
✅ **Model scoring**: Apply segments to new data
✅ **Rich visualizations**: Charts and heatmaps
✅ **Question labeling**: Show full question text in outputs

---

## 2. Installation & Setup

### Requirements

- R 4.0 or higher
- Turas analytics platform installed
- Required R packages (auto-installed):
  - `readxl`, `writexl` - Excel file handling
  - `cluster` - Clustering algorithms
  - `MASS` - Discriminant analysis (optional)
  - `fmsb` - Spider plots (optional)

### Launching the Module

**Method 1: Via Turas Launcher (Recommended)**
```r
source("launch_turas.R")
# Click "Launch Segment" button in the GUI
```

**Method 2: Direct Command**
```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("path/to/config.xlsx")
```

---

## 3. Data Preparation

### Data Format Requirements

Your survey data must be structured as:
- **Rows**: Individual respondents
- **Columns**: Variables (questions, demographics, etc.)
- **Format**: CSV or Excel (.xlsx, .xls)

**Example Data Structure:**

| respondent_id | q1 | q2 | q3 | age | gender |
|---------------|----|----|----|----|--------|
| 1001          | 8  | 7  | 9  | 35 | M      |
| 1002          | 3  | 4  | 2  | 42 | F      |
| 1003          | 9  | 9  | 8  | 28 | M      |

### Variable Selection for Clustering

**Good Clustering Variables:**
- ✅ Satisfaction ratings (1-10 scales)
- ✅ Behavioral frequencies (1-5 scales)
- ✅ Importance ratings
- ✅ Likelihood measures
- ✅ Numeric continuous variables

**Avoid:**
- ❌ Categorical text (use numeric codes instead)
- ❌ Open-ended responses
- ❌ Constants (everyone answered same)
- ❌ Unique identifiers

### Missing Data Considerations

- **< 5% missing**: Usually fine
- **5-20% missing**: Use mean/median imputation
- **> 20% missing**: Consider excluding variable
- **> 50% missing**: Definitely exclude

Check missing data patterns before running:
```r
summary(your_data)  # Shows NA counts
```

---

## 4. Configuration Reference

### Creating a Configuration File

**Option 1: Template Generator**
```r
source("modules/segment/lib/segment_utils.R")

generate_config_template(
  data_file = "data/survey.csv",
  output_file = "config/my_segmentation.xlsx",
  mode = "exploration"  # or "final"
)
```

**Option 2: Manual Creation**
Create Excel file with "Config" sheet, 2 columns: Setting | Value

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `data_file` | Path to survey data | `data/survey.csv` |
| `id_variable` | Respondent ID column name | `respondent_id` |
| `clustering_vars` | Comma-separated variable list | `q1,q2,q3,q4,q5` |

### Core Parameters

#### Model Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `method` | `kmeans` | Clustering method (currently only kmeans) |
| `k_fixed` | [blank] | Fixed number of segments (blank = exploration mode) |
| `k_min` | `3` | Minimum k to test (exploration mode) |
| `k_max` | `6` | Maximum k to test (exploration mode) |
| `nstart` | `25` | Algorithm restarts (higher = more stable) |
| `seed` | `123` | Random seed for reproducibility |

**Exploration Mode**: Leave `k_fixed` blank, set `k_min` and `k_max`
**Final Mode**: Set `k_fixed` to chosen number of segments

#### Data Handling

| Parameter | Default | Options | Description |
|-----------|---------|---------|-------------|
| `missing_data` | `listwise_deletion` | `listwise_deletion`, `mean_imputation`, `median_imputation`, `refuse` | How to handle missing values |
| `missing_threshold` | `15` | 0-100 | Max % missing allowed per variable |
| `standardize` | `TRUE` | TRUE/FALSE | Standardize variables before clustering |
| `min_segment_size_pct` | `10` | 0-50 | Minimum % of respondents per segment |

#### Outlier Detection

| Parameter | Default | Options | Description |
|-----------|---------|---------|-------------|
| `outlier_detection` | `FALSE` | TRUE/FALSE | Enable outlier detection |
| `outlier_method` | `zscore` | `zscore`, `mahalanobis` | Detection method |
| `outlier_threshold` | `3.0` | 1.0-5.0 | Z-score threshold (3.0 = 99.7% rule) |
| `outlier_min_vars` | `1` | 1+ | Minimum variables to be outlier on |
| `outlier_handling` | `flag` | `none`, `flag`, `remove` | What to do with outliers |
| `outlier_alpha` | `0.001` | 0.0001-0.1 | Alpha for Mahalanobis method |

#### Variable Selection

| Parameter | Default | Options | Description |
|-----------|---------|---------|-------------|
| `variable_selection` | `FALSE` | TRUE/FALSE | Enable automatic variable selection |
| `variable_selection_method` | `variance_correlation` | `variance_correlation`, `factor_analysis`, `both` | Selection algorithm |
| `max_clustering_vars` | `10` | 2-20 | Target number of variables |
| `varsel_min_variance` | `0.1` | 0.01-1.0 | Minimum variance threshold |
| `varsel_max_correlation` | `0.8` | 0.5-0.95 | Maximum correlation threshold |

#### Output Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `output_folder` | `output/` | Where to save results |
| `output_prefix` | `seg_` | Filename prefix |
| `create_dated_folder` | `TRUE` | Create timestamped subfolder |
| `segment_names` | `auto` | Comma-separated names or "auto" |
| `save_model` | `TRUE` | Save model for scoring new data |
| `question_labels_file` | [blank] | Path to question labels Excel |

### Question Labels File Format

Create Excel file with "Labels" sheet:

| Variable | Label |
|----------|-------|
| q1 | Overall satisfaction with product quality |
| q2 | Satisfaction with customer service |
| q3 | Satisfaction with value for money |

---

## 5. Running Segmentation

### Using the GUI Interface (Recommended)

**Launching the GUI:**

From the Turas launcher:
```r
source("launch_turas.R")
# Click "Launch Segment" button
```

Or directly:
```r
source("modules/segment/run_segment_gui.R")
run_segment_gui()
```

**GUI Workflow - 5 Simple Steps:**

**Step 1: Select Configuration File**
- Click "Browse..." to locate your configuration Excel file
- File path will display once selected
- Example: `/Users/duncan/projects/hv_config.xlsx`

**Step 2: Validation**
- Click "Validate Configuration"
- Reviews all parameters for completeness and correctness
- Green checkmark (✓) appears if valid
- Red error messages appear if issues found
- Fix any errors in the Excel file before proceeding

**Step 3: Run Analysis**
- Click "Run Segmentation Analysis"
- Analysis begins immediately
- Progress indicator shows current stage
- **Important:** Do not close the browser window during analysis

**Step 4: Console Output**
- Real-time console messages appear in dark-themed output box
- Shows analysis progress with detailed logging:
  ```
  ========================================
  TURAS SEGMENTATION ANALYSIS
  ========================================
  Started: 2025-12-01 14:23:15

  [1/6] Loading configuration...
  ✓ Configuration loaded successfully
  Mode: Exploration (testing k = 3 to 6)

  [2/6] Loading and preparing data...
  ✓ Data loaded: 350 rows, 20 columns
  ✓ Variable selection: 20 variables → 8 selected

  [3/6] Running k-means clustering...
  Testing k=3... Silhouette: 0.276
  Testing k=4... Silhouette: 0.312
  Testing k=5... Silhouette: 0.289
  Testing k=6... Silhouette: 0.245

  [4/6] Creating segment profiles...
  [5/6] Generating visualizations...
  [6/6] Exporting results...

  ✓ Analysis complete!
  ```
- Console updates in real-time during execution
- All console output is automatically captured

**Step 5: Results**
- Displays immediately after analysis completes
- **Exploration Mode** shows:
  - Recommended k value
  - Silhouette score for recommended k
  - All tested k values
  - Link to exploration report
- **Final Mode** shows:
  - Number of segments created
  - Silhouette quality score
  - Segment size distribution
  - Links to assignments and profile files
- Click file path links to open output files

**Tips for GUI Usage:**

✅ **DO:**
- Keep browser window open during analysis
- Monitor console output for progress
- Wait for "Analysis Complete!" message
- Review console for any warnings

❌ **DON'T:**
- Don't click "Run Analysis" multiple times
- Don't close browser during processing
- Don't modify config file during analysis

---

### Command Line Workflows

For advanced users or scripting, use command line:

#### Workflow 1: Exploration Mode (Finding Optimal k)

**Step 1: Create exploration config**
```
k_fixed = [blank]
k_min = 3
k_max = 6
```

**Step 2: Run exploration**
```r
result <- turas_segment_from_config("config/exploration.xlsx")
```

**Step 3: Review results**
- Open `seg_exploration_report.xlsx`
- Look at "Metrics_Comparison" sheet
- Check elbow plot and silhouette scores
- Choose k (typically where elbow bends or silhouette peaks)

**Step 4: Create final config**
```
k_fixed = 4  # Your chosen k
```

**Step 5: Run final segmentation**
```r
final_result <- turas_segment_from_config("config/final.xlsx")
```

#### Workflow 2: Direct Final (Known k)

If you already know how many segments you want:

```r
result <- turas_segment_from_config("config/k4_segmentation.xlsx")
# Config has k_fixed = 4
```

#### Workflow 3: Variable Selection + Segmentation

When you have 20+ clustering variables:

**Config settings:**
```
clustering_vars = q1,q2,q3,... (all 20 variables)
variable_selection = TRUE
max_clustering_vars = 10
```

**Run:**
```r
result <- turas_segment_from_config("config/varsel.xlsx")
```

The module will:
1. Remove low-variance variables
2. Remove highly correlated variables
3. Rank remaining by importance
4. Select top 10 for clustering

---

## 6. Understanding Results

### Output Files

After running, your output folder contains:

#### Exploration Mode
- `seg_exploration_report.xlsx` - K-selection metrics
- `seg_segment_profiles_k3.xlsx` - Profiles for k=3
- `seg_segment_profiles_k4.xlsx` - Profiles for k=4
- `seg_segment_profiles_k5.xlsx` - Profiles for k=5
- `seg_k_selection.png` - Elbow and silhouette plots
- `seg_model.rds` - Saved model

#### Final Mode
- `seg_final_report.xlsx` - Complete segmentation report
- `seg_assignments.xlsx` - Respondent-to-segment mapping
- `seg_segment_sizes.png` - Size distribution chart
- `seg_profiles_heatmap.png` - Visual profile comparison
- `seg_model.rds` - Saved model

### Reading the Exploration Report

**Metrics_Comparison Sheet:**

| k | tot.withinss | betweenss | avg_silhouette_width |
|---|--------------|-----------|----------------------|
| 3 | 1250.5       | 850.2     | 0.42                 |
| 4 | 980.3        | 1120.4    | 0.51                 |
| 5 | 890.1        | 1160.6    | 0.48                 |

**How to choose k:**
- **Elbow method**: Look for "elbow" in tot.withinss (diminishing returns)
- **Silhouette**: Higher is better (>0.5 is good)
- **Practical**: Can you describe/action each segment?

👉 **Best choice here: k=4** (highest silhouette, clear elbow)

### Reading Segment Profiles

**Example Profile Sheet:**

| Variable | Segment_1 | Segment_2 | Segment_3 | Segment_4 | Overall |
|----------|-----------|-----------|-----------|-----------|---------|
| q1: Product quality | 8.5 | 6.2 | 3.1 | 9.2 | 7.1 |
| q2: Service quality | 8.3 | 6.5 | 2.8 | 9.0 | 7.0 |
| q3: Value for money | 7.9 | 5.8 | 3.5 | 8.8 | 6.8 |

**Interpreting:**
- **Segment 1**: "Satisfied" - High across all (8+)
- **Segment 2**: "Neutral" - Mid-range (5-7)
- **Segment 3**: "Detractors" - Low across all (< 4)
- **Segment 4**: "Advocates" - Extremely high (9+)

### Segment Naming Best Practices

Good segment names are:
- **Descriptive**: Captures defining characteristic
- **Action-oriented**: Suggests strategy
- **Memorable**: Easy to reference

**Examples:**
- ❌ "Segment 1, Segment 2"
- ✅ "Advocates, Satisfied, At-Risk, Detractors"
- ✅ "Premium Seekers, Value Hunters, Service-Focused"

---

## 7. Advanced Features

### Outlier Detection

Identifies extreme respondents before clustering:

```
outlier_detection = TRUE
outlier_method = zscore
outlier_threshold = 3.0
outlier_handling = flag
```

**When to use:**
- Data contains data entry errors
- Few respondents answered completely differently
- Want to flag "unusual" respondents

**Methods:**
- `zscore`: Simpler, flags if z-score > threshold on multiple variables
- `mahalanobis`: More sophisticated, considers correlations

**Handling:**
- `flag`: Keep in data, mark in output
- `remove`: Exclude from clustering

### Variable Selection

Automatically reduces 20+ variables to optimal subset:

```
variable_selection = TRUE
variable_selection_method = variance_correlation
max_clustering_vars = 10
varsel_min_variance = 0.1
varsel_max_correlation = 0.8
```

**Process:**
1. Remove low-variance variables (< 0.1)
2. Remove highly correlated pairs (> 0.8)
3. Rank by variance/factor loadings
4. Select top N

**When to use:**
- You have 15+ candidate variables
- Unsure which variables matter most
- Want data-driven variable selection

### Segment Validation

Test segment quality and stability:

```r
source("modules/segment/lib/segment_validation.R")

# Run comprehensive validation
validation <- validate_segmentation(
  data = your_data,
  clusters = result$clusters,
  clustering_vars = result$config$clustering_vars,
  k = 4,
  n_bootstrap = 100
)
```

**Metrics:**
- **Stability** (bootstrap): How consistent are segments? (>0.8 = excellent)
- **Separation** (Calinski-Harabasz, Davies-Bouldin): How distinct? (higher CH = better, lower DB = better)
- **Discrimination** (LDA): Can we predict segment membership? (>90% = excellent)

### Enhanced Profiling Statistics

Get statistical significance tests and effect sizes:

```r
source("modules/segment/lib/segment_profiling_enhanced.R")

# Create enhanced profile with stats
enhanced <- create_enhanced_profile_report(
  data = your_data,
  clusters = result$clusters,
  clustering_vars = result$config$clustering_vars,
  profile_vars = result$config$profile_vars,
  output_path = "output/enhanced_profile.xlsx"
)
```

**Output includes:**
- **Significance tests**: Which variables truly differentiate segments? (ANOVA p-values)
- **Effect sizes**: How large are differences? (Cohen's d, eta-squared)
- **Index scores**: Segment vs. overall (100 = average, >100 = above average)

### Visualizations

Create all standard plots:

```r
source("modules/segment/lib/segment_visualization.R")

create_all_visualizations(
  result = result,
  output_folder = "output/charts/",
  prefix = "seg_",
  question_labels = config$question_labels
)
```

**Creates:**
- Segment sizes bar chart
- K-selection plots (exploration mode)
- Profile heatmap
- Spider/radar chart (if fmsb installed)

---

## 8. Scoring New Data

### Why Score New Data?

After creating your segmentation, you'll want to:
- Assign new survey respondents to existing segments
- Track segment evolution over time
- Apply segments to ongoing data collection

### How to Score

**Step 1: Save model during initial segmentation**
```
save_model = TRUE  # in config
```

**Step 2: Load new data**
```r
new_survey <- read.csv("data/new_responses.csv")
```

**Step 3: Score new data**
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
- `respondent_id`: ID from new data
- `segment`: Assigned segment (1, 2, 3, 4)
- `segment_name`: Segment name
- `distance_to_center`: How far from segment center
- `assignment_confidence`: Confidence score (0-1)

### Monitoring Segment Drift

Check if segment distribution changes over time:

```r
drift <- compare_segment_distributions(
  model_file = "output/seg_model.rds",
  scoring_result = scores
)
```

**Example output:**

| Segment | Original_N | Original_Pct | New_N | New_Pct | Difference_Pct |
|---------|------------|--------------|-------|---------|----------------|
| Advocates | 150 | 25.0 | 80 | 20.0 | -5.0 |
| Satisfied | 300 | 50.0 | 220 | 55.0 | +5.0 |

---

## 9. Best Practices

### Choosing Clustering Variables

**DO:**
- ✅ Use 5-15 variables (sweet spot: 7-10)
- ✅ Choose variables measuring similar concepts (all satisfaction OR all behavior)
- ✅ Use same scale variables (all 1-10 or all 1-5)
- ✅ Include variables you'll act on

**DON'T:**
- ❌ Mix satisfaction (1-10) with demographics (age 18-80) - scale differences matter
- ❌ Use 50 variables without variable selection
- ❌ Include highly correlated duplicates (e.g., "satisfaction" and "overall satisfaction")

### Choosing Number of Segments (k)

**Guidelines:**
- **k=2-3**: Simple, easy to action, but may oversimplify
- **k=4-5**: Sweet spot for most use cases
- **k=6-8**: Complex, hard to action, needs strong justification
- **k=9+**: Too many, likely over-fitting

**Consider:**
- Can you describe each segment distinctly?
- Can you create different strategies for each?
- Do stakeholders understand the segmentation?

### Sample Size Requirements

| Respondents | Number of Segments (k) |
|-------------|----------------------|
| 100-200     | 2-3 only |
| 200-500     | 3-5 comfortable |
| 500-1000    | 4-6 comfortable |
| 1000+       | Up to 8 if needed |

**Rule of thumb**: At least 30-50 respondents per segment

### Data Quality Checklist

Before running segmentation:

- [ ] No duplicate respondent IDs
- [ ] All clustering variables are numeric
- [ ] Missing data < 20% per variable
- [ ] At least 100 complete cases
- [ ] Variables have reasonable variance (not all 8's)
- [ ] Scale consistency (all 1-10 or convert to same scale)

---

## 10. Troubleshooting

### GUI-Specific Issues

**Problem: Grey screen when launching GUI**
- **Cause**: Console output placement in reactive UI component
- **Fix**: This has been fixed in the latest version. Update to latest code.
- **Technical**: Console moved to static main UI (Step 4) instead of reactive results UI

**Problem: Grey screen during analysis execution**
- **Cause**: Incompatible progress indicator pattern with sink() blocks
- **Fix**: This has been fixed - now uses `Progress$new(session)` pattern
- **Technical**: Progress updates must be outside sink() blocks for R 4.2+ compatibility

**Problem: Console output not displaying**
- **Cause**: R 4.2+ compatibility issue with renderText() conditionals
- **Fix**: Automatic - uses safe conditional checking
- **Details**: Checks `nchar(output[1])` instead of `nchar(output)` for single TRUE/FALSE

**Problem: "non-numeric argument to mathematical function" in exploration mode**
- **Cause**: Silhouette score calculation returning non-numeric value
- **Fix**: Automatic - displays "N/A" instead of attempting to round non-numeric values
- **Details**: Results display safely handles edge cases

**Problem: Results not displaying after successful analysis**
- **Check**: Look at console output - did analysis actually complete?
- **Check**: Are there error messages in the R console (not GUI console)?
- **Fix**: Refresh browser page and re-run if needed

**Problem: File path links not working**
- **Cause**: Output files not in expected location
- **Fix**: Check `output_folder` parameter in config
- **Verify**: Look in working directory for actual file location

---

### Common Errors

**Error: "Missing clustering variables in data"**
- **Cause**: Variable names in config don't match data column names
- **Fix**: Check exact spelling and case-sensitivity

**Error: "Not enough complete cases"**
- **Cause**: Too much missing data after listwise deletion
- **Fix**: Use `missing_data = mean_imputation` or remove high-missing variables

**Error: "Segment smaller than minimum size"**
- **Cause**: A segment has < min_segment_size_pct respondents
- **Fix**: Reduce `min_segment_size_pct` or try different k

### Common Warnings

**Warning: "Variable X has low variance"**
- **Meaning**: Everyone answered similarly
- **Action**: Consider removing variable (doesn't differentiate)

**Warning: "High correlation between X and Y"**
- **Meaning**: Two variables measure same thing
- **Action**: Keep only one, or enable variable_selection

**Warning: "Stability < 0.6"**
- **Meaning**: Segment assignments aren't consistent across bootstrap samples
- **Action**: Try fewer variables, different k, or more respondents

### Performance Issues

**Segmentation takes too long:**
- Reduce `nstart` from 25 to 10
- Reduce `k_max` range
- Disable variable selection bootstrap iterations

**Large output files:**
- Set `create_dated_folder = FALSE` to avoid accumulation
- Manually delete old runs

---

## Appendix: Configuration Template

Complete example configuration:

```
Setting,Value
data_file,data/customer_survey.csv
data_sheet,Data
id_variable,respondent_id
clustering_vars,"q1,q2,q3,q4,q5,q6,q7"
profile_vars,"age,tenure_months,spend"
question_labels_file,config/question_labels.xlsx
method,kmeans
k_fixed,
k_min,3
k_max,6
nstart,25
seed,123
missing_data,listwise_deletion
missing_threshold,15
standardize,TRUE
min_segment_size_pct,10
outlier_detection,TRUE
outlier_method,zscore
outlier_threshold,3.0
outlier_min_vars,2
outlier_handling,flag
outlier_alpha,0.001
variable_selection,FALSE
variable_selection_method,variance_correlation
max_clustering_vars,10
varsel_min_variance,0.1
varsel_max_correlation,0.8
k_selection_metrics,"silhouette,elbow"
output_folder,output/segmentation/
output_prefix,seg_
create_dated_folder,TRUE
segment_names,auto
save_model,TRUE
project_name,Customer Segmentation 2024
analyst_name,Your Name
description,Quarterly customer satisfaction segmentation
```

---

**End of User Manual**

For technical documentation and development guide, see `MAINTENANCE_MANUAL.md`.
