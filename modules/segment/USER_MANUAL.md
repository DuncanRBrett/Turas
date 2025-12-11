# Turas Segmentation Module - Quick Start Guide

**Get started with customer segmentation in 5 minutes!**

## What is Segmentation?

The Turas Segmentation Module uses k-means clustering to automatically group survey respondents into meaningful segments based on their attitudes, behaviors, or satisfaction levels.

## Before You Start


---

**You need:**
- Survey data (CSV or Excel) with respondents as rows and questions as columns
- A respondent ID column
- 5-20 numeric variables for clustering (e.g., satisfaction ratings 1-10)
- At least 100 respondents (300+ recommended)

## Quick Start: 3 Steps

### Step 1: Launch the Segmentation Module

```r
source("launch_turas.R")
# Click "Launch Segment" button
```

### Step 2: Create Your Configuration

**Option A: Use the GUI**
1. Click "Select Config File" → "New Project"
2. Choose your survey data file
3. Fill in:
   - **ID Variable**: Name of respondent ID column (e.g., "respondent_id")
   - **Clustering Variables**: Questions to segment on (e.g., "q1,q2,q3,q4,q5")
4. Leave other settings at defaults
5. Save configuration

**Option B: Use Template Generator**
```r
source("modules/segment/lib/segment_utils.R")
initialize_segmentation_project(
  project_name = "My_Segmentation",
  data_file = "path/to/survey_data.csv"
)
# Then edit: projects/My_Segmentation/config/segmentation_config.xlsx
```

### Step 3: Run Segmentation

**Option A: Use the GUI (Recommended)**
```r
source("modules/segment/run_segment_gui.R")
run_segment_gui()
```

Then:
1. Click "Select Config File" → browse to your config
2. Click "Validate Configuration"
3. Click "Run Segmentation Analysis"
4. **Watch the console output** for real-time progress
5. View results when complete

**Option B: Use Command Line**
```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("path/to/your_config.xlsx")
```

**That's it!** Results will be saved to the output folder specified in your configuration.

## Understanding Your Results

After running, you'll find these files in your output folder:

| File | What It Contains |
|------|------------------|
| `seg_exploration_report.xlsx` | K-selection metrics (which k is best?) |
| `seg_segment_profiles_k4.xlsx` | Detailed profiles for k=4 solution |
| `seg_assignments_k4.xlsx` | Each respondent's segment assignment |
| `seg_k_selection.png` | Visual charts showing optimal k |
| `seg_segment_sizes.png` | Bar chart of segment sizes |
| `seg_model.rds` | Saved model (for scoring new data later) |

**Start with the exploration report** to choose your optimal number of segments (k).

## Example Workflow

**Using GUI (Easiest):**
```r
# 1. Launch GUI
source("modules/segment/run_segment_gui.R")
run_segment_gui()

# 2. In GUI:
#    - Select your exploration config
#    - Click Validate → Run
#    - Watch console output for progress
#    - Review results to choose k

# 3. Edit config: set k_fixed = 4 (your chosen k)

# 4. In GUI:
#    - Select your final config
#    - Click Validate → Run
#    - Download results

# 5. Score new data with saved model
source("modules/segment/lib/segment_scoring.R")
new_scores <- score_new_data(
  model_file = "output/seg_model.rds",
  new_data = new_survey_data,
  id_variable = "respondent_id"
)
```

**Using Command Line (Advanced):**
```r
# 1. Load module
source("modules/segment/run_segment.R")

# 2. Run segmentation (exploration mode)
result <- turas_segment_from_config("my_config.xlsx")

# 3. Review results, choose k=4
#    Edit config: set k_fixed = 4

# 4. Run final segmentation
final <- turas_segment_from_config("my_config_final.xlsx")

# 5. Score new data with saved model
source("modules/segment/lib/segment_scoring.R")
new_scores <- score_new_data(
  model_file = "output/seg_model.rds",
  new_data = new_survey_data,
  id_variable = "respondent_id"
)
```

## Common Settings

### Exploration vs. Final Mode

**Exploration Mode** (finding optimal k):
```
k_fixed = [leave blank]
k_min = 3
k_max = 6
```

**Final Mode** (using chosen k):
```
k_fixed = 4
```

### Variable Selection (20+ variables)

If you have many variables, enable automatic selection:
```
variable_selection = TRUE
max_clustering_vars = 10
```

### Outlier Detection

Identify extreme respondents before clustering:
```
outlier_detection = TRUE
outlier_handling = flag    # or "remove"
```

### Question Labels

Show full question text instead of "q1, q2, q3":

1. Create labels file (Excel, 2 columns):
   ```
   Variable | Label
   q1       | Overall satisfaction with product
   q2       | Satisfaction with customer service
   ...
   ```

2. Add to config:
   ```
   question_labels_file = path/to/labels.xlsx
   ```

## Troubleshooting

**"Missing clustering variables"**
→ Check variable names match exactly (case-sensitive)

**"Not enough complete cases"**
→ Too much missing data. Try mean_imputation or remove variables with >20% missing

**"Segments are unstable"**
→ Try fewer clustering variables or different k

**"All segments look the same"**
→ Variables don't differentiate respondents well. Try different variables

## Next Steps

- **Full documentation**: See `USER_MANUAL.md` for comprehensive guide
- **Advanced features**: Variable selection, outlier detection, validation metrics
- **Scoring new data**: Apply segments to ongoing survey responses
- **Visualizations**: Create profile heatmaps and spider charts

## Need Help?

Check the full User Manual (`USER_MANUAL.md`) or Maintenance Manual (`MAINTENANCE_MANUAL.md`) for detailed documentation.

---

**Happy Segmenting!** 🎯

---

# Turas Segmentation Module - User Manual

**Comprehensive Guide to Customer Segmentation with Turas**

Version 10.1 | Last Updated: December 2025

**What's New in v10.1:**
- Quick Run Function for programmatic segmentation
- Respondent Typing Tool with confidence scores
- Golden Questions Identifier
- Auto Segment Naming
- Segment Action Cards
- Classification Rules
- Demographic Profiling
- Simple Stability Check
- Variable Importance Ranking
- Outlier Review Screen
- Latent Class Analysis (LCA)

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

## 7.1 Enhanced Features (v10.1)

The following new features enhance segmentation analysis with practical business-focused outputs.

### Quick Run Function (Programmatic Segmentation)

Run segmentation without creating an Excel config file:

```r
source("modules/segment/lib/segment_utils.R")

# Exploration mode (finds optimal k)
result <- run_segment_quick(
  data = survey_data,
  id_var = "respondent_id",
  clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
  k = NULL,  # NULL = exploration mode
  k_range = 3:6
)

# Final mode (with chosen k)
result <- run_segment_quick(
  data = survey_data,
  id_var = "respondent_id",
  clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
  k = 4
)
```

### Respondent Typing Tool

Classify new respondents using a saved segmentation model:

```r
source("modules/segment/lib/segment_scoring.R")

# Single respondent
result <- type_respondent(
  answers = c(q1 = 8, q2 = 7, q3 = 9, q4 = 8, q5 = 9),
  model_file = "output/seg_model.rds"
)
# Returns: segment, segment_name, confidence, distances

# Multiple respondents
results <- type_respondents_batch(
  data = new_respondents,
  model_file = "output/seg_model.rds",
  id_var = "respondent_id"
)
```

**Output includes**:
- Assigned segment and name
- Confidence score (0-100%)
- Distance to each segment center
- Low-confidence warnings

### Golden Questions Identifier

Find the minimum set of questions that best predict segment membership:

```r
source("modules/segment/lib/segment_profiling_enhanced.R")

golden <- identify_golden_questions(
  data = survey_data,
  clusters = result$clusters,
  clustering_vars = config$clustering_vars,
  n_questions = 3,
  question_labels = config$question_labels
)

# Output:
# Top 3 discriminating variables:
#   1. q3_service: Service satisfaction (importance: 0.42)
#   2. q1_product: Product quality (importance: 0.38)
#   3. q5_recommend: Likelihood to recommend (importance: 0.31)
#
# These 3 questions predict segment membership with 89% accuracy.
```

### Auto Segment Naming

Generate meaningful segment names automatically:

```r
source("modules/segment/lib/segment_profile.R")

names <- auto_name_segments(
  data = survey_data,
  clusters = result$clusters,
  clustering_vars = config$clustering_vars,
  name_style = "descriptive"  # or "persona"
)

# Output:
#   Segment 1: High Performers (23%)
#   Segment 2: Satisfied (51%)
#   Segment 3: At-Risk (17%)
#   Segment 4: Dissatisfied (9%)
```

### Segment Action Cards

Generate executive-ready summaries for each segment:

```r
source("modules/segment/lib/segment_cards.R")

cards <- generate_segment_cards(
  data = survey_data,
  clusters = result$clusters,
  clustering_vars = config$clustering_vars,
  segment_names = c("Advocates", "Satisfied", "At-Risk", "Detractors")
)

print_segment_cards(cards)

# Output per segment:
# ============================================================
# SEGMENT: Advocates
# ============================================================
# Size: 150 respondents (25%)
#
# HEADLINE: High-satisfaction group with high service quality
#
# DEFINING TRAITS:
#   - Service quality: 9.2 vs 7.1 overall (higher)
#   - Product satisfaction: 8.8 vs 6.9 overall (higher)
#
# STRENGTHS:
#   + Service quality (9.2/10)
#   + Product satisfaction (8.8/10)
#
# PAIN POINTS:
#   No major pain points identified
#
# RECOMMENDED ACTIONS:
#   > Leverage as brand advocates
#   > Gather testimonials/case studies
#   > Offer referral programs

# Export to Excel
export_cards_excel(cards, "output/segment_cards.xlsx")
```

### Classification Rules

Generate plain-English decision rules:

```r
source("modules/segment/lib/segment_rules.R")

rules <- generate_segment_rules(
  data = survey_data,
  clusters = result$clusters,
  clustering_vars = config$clustering_vars,
  max_depth = 3
)

print_segment_rules(rules)

# Output:
# IF service_quality >= 7.5 AND product_satisfaction >= 7.0 THEN Advocates
# IF service_quality < 5.0 AND value_perception < 5.5 THEN Detractors
# ...
# Overall rule accuracy: 85%
```

### Variable Importance Ranking

Determine which variables matter most:

```r
source("modules/segment/lib/segment_profiling_enhanced.R")

importance <- rank_variable_importance(
  data = survey_data,
  clusters = result$clusters,
  clustering_vars = config$clustering_vars
)

# Output:
# ESSENTIAL (eta-squared > 0.30):
#   q3_service: 0.52
#   q1_product: 0.45
#
# USEFUL (eta-squared 0.10-0.30):
#   q5_recommend: 0.22
#   q2_value: 0.18
#
# MINIMAL IMPACT (eta-squared < 0.10):
#   q4_support: 0.08  <- Consider removing
#
# Suggestion: Variable q4_support contributes little.
# Re-run without it for cleaner segments.
```

### Demographic Profiling

Analyze segment composition by demographics:

```r
source("modules/segment/lib/segment_profile.R")

demo_profile <- profile_demographics(
  data = survey_data,
  clusters = result$clusters,
  demo_vars = c("gender", "age_group", "region", "income_bracket")
)

# Output:
# Analyzing: gender
#   Chi-squared test: Significant (p < 0.05)
#
# Analyzing: age_group
#   Chi-squared test: Significant (p < 0.05)
#
# Analyzing: region
#   Not significant (p = 0.234)

export_demographic_profiles(demo_profile, "output/demo_profiles.xlsx")
```

### Simple Stability Check

Quick stability verification (faster than bootstrap):

```r
source("modules/segment/lib/segment_validation.R")

stability <- check_stability_simple(
  data = survey_data,
  clustering_vars = config$clustering_vars,
  k = 4,
  n_runs = 5
)

# Output:
# Running 5 k-means iterations with different seeds...
#   Run 1: tot.withinss = 1250.3
#   Run 2: tot.withinss = 1248.7
#   ...
#
# STABILITY RESULTS
# -----------------
# Stability Score: 92%
# Interpretation: EXCELLENT - Very stable segmentation
#
# Agreement between runs:
#   Average: 92.3%
#   Min: 89.5%
#   Max: 95.1%
```

### Outlier Review Screen

Interactive review of flagged outliers:

```r
source("modules/segment/lib/segment_outliers.R")

review <- review_outliers(
  data = survey_data,
  outlier_result = outlier_detection,
  clustering_vars = config$clustering_vars,
  id_var = "respondent_id",
  output_path = "output/outlier_review.xlsx"
)

# Output:
# Total respondents: 500
# Flagged outliers: 12 (2.4%)
#
# Top 5 most extreme outliers:
#   1. ID 1042: 4 extreme vars, max z=4.8 [REMOVE - Multiple extreme values]
#   2. ID 2315: 3 extreme vars, max z=4.2 [LIKELY REMOVE]
#   ...
```

### Latent Class Analysis (LCA)

Alternative to k-means for categorical/ordinal data:

```r
source("modules/segment/lib/segment_lca.R")

# Exploration mode
lca_result <- run_lca(
  data = survey_data,
  id_var = "respondent_id",
  clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
  n_classes = NULL,  # NULL = exploration
  n_min = 2,
  n_max = 6
)

# Final mode
lca_final <- run_lca(
  data = survey_data,
  id_var = "respondent_id",
  clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
  n_classes = 4
)

# Compare k-means vs LCA
comparison <- compare_kmeans_lca(
  data = survey_data,
  id_var = "respondent_id",
  clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
  k = 4
)
```

**When to use LCA**:
- Data is categorical (Yes/No, A/B/C)
- Likert scales (1-5) treated as ordinal
- Assumptions of k-means (continuous, normal) not met
- Probabilistic class membership preferred

### Configuration Parameters for Enhanced Features

Add these to your config file to enable enhanced features:

```
# Golden Questions
golden_questions_n = 3

# Auto Naming
auto_name_style = descriptive  # or "persona", "simple"

# Demographics
demographic_vars = gender,age_group,region,income

# Stability Check
run_stability_check = TRUE
stability_n_runs = 5

# Classification Rules
generate_rules = TRUE
rules_max_depth = 3

# Action Cards
generate_action_cards = TRUE
scale_max = 10

# LCA (instead of k-means)
use_lca = FALSE
```

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

---

## Example Workflows

### Step 2: Select and Validate Configuration

**In the GUI:**
1. Click **"Browse..."** under Step 1
2. Navigate to your configuration file (e.g., `config/customer_segmentation.xlsx`)
3. Click **"Validate Configuration"** button
4. Wait for green checkmark ✓ or fix any red error messages

### Step 3: Run Exploration Analysis

1. Click **"Run Segmentation Analysis"** button
2. **Watch the Console Output** (Step 4) for real-time progress:

```
========================================
TURAS SEGMENTATION ANALYSIS
========================================
Started: 2025-12-01 14:23:15

[1/6] Loading configuration...
✓ Configuration loaded successfully
Mode: Exploration (testing k = 3 to 6)

[2/6] Loading and preparing data...
✓ Data loaded: 350 rows, 12 columns
✓ All clustering variables present

[3/6] Running k-means clustering...
Testing k=3... Silhouette: 0.42
Testing k=4... Silhouette: 0.51  ← Highest
Testing k=5... Silhouette: 0.48
Testing k=6... Silhouette: 0.39

[4/6] Creating segment profiles...
[5/6] Generating visualizations...
[6/6] Exporting results...

✓ Analysis complete!
Results saved to: output/customer_segments/
```

### Step 4: Review Results in GUI

**Step 5 displays immediately after completion:**

```
✓ Analysis Complete!

Recommended K: 4
Silhouette Score: 0.51

Tested k values: 3, 4, 5, 6

Output Files:
📊 Exploration Report: output/customer_segments/seg_exploration_report.xlsx
📈 K Selection Plot: output/customer_segments/seg_k_selection.png
```

Click the file links to open Excel reports directly.

### Step 5: Review Exploration Report

Open the exploration report Excel file:
- **Metrics_Comparison** sheet → k=4 has highest silhouette
- **Profile_k4** sheet → See how segments differ
- **Profile_k3**, **Profile_k5**, **Profile_k6** → Compare alternatives

**Decision**: Use k=4 based on highest silhouette and interpretability.

### Step 6: Run Final Segmentation

1. **Edit your config file** (outside GUI):
   - Change `k_fixed` from blank to `4`
   - Save (or save as `customer_segmentation_final.xlsx`)

2. **Back in GUI**:
   - Click "Browse..." to select updated config
   - Click "Validate Configuration"
   - Click "Run Segmentation Analysis"

3. **Watch Console Output** for final run:

```
[3/6] Running k-means clustering...
Running final segmentation with k=4...
✓ Clustering complete

[4/6] Creating segment profiles...
✓ Profiles created
```

4. **View Final Results** (Step 5):

```
✓ Analysis Complete!

Number of Segments: 4
Silhouette Score: 0.51
Observations: 350

Segment Sizes:
- Segment 1: 80 (23%)
- Segment 2: 180 (51%)
- Segment 3: 60 (17%)
- Segment 4: 30 (9%)

Output Files:
📊 Final Report: output/customer_segments/seg_final_report.xlsx
📋 Assignments: output/customer_segments/seg_assignments.xlsx
📈 Charts: output/customer_segments/seg_*.png
💾 Model: output/customer_segments/seg_model.rds
```

### Step 7: Interpret and Name Segments

Open `seg_final_report.xlsx` → Profiles sheet:

| Variable | Seg 1 | Seg 2 | Seg 3 | Seg 4 | Overall |
|----------|-------|-------|-------|-------|---------|
| q1: Product quality | 9.2 | 7.8 | 5.1 | 2.8 | 7.1 |
| q2: Service quality | 9.0 | 7.5 | 4.8 | 3.2 | 7.0 |
| q3: Value for money | 8.8 | 7.2 | 5.5 | 3.5 | 6.8 |
| q4: Support | 8.9 | 7.6 | 4.9 | 2.5 | 6.9 |
| **Size** | **80** | **180** | **60** | **30** | **350** |
| **Percent** | **23%** | **51%** | **17%** | **9%** | **100%** |

**Segment Names:**
- **Segment 1 → "Advocates"** (23%): Highest scores across all dimensions
- **Segment 2 → "Satisfied"** (51%): Above average, largest segment
- **Segment 3 → "At-Risk"** (17%): Below average, need attention
- **Segment 4 → "Detractors"** (9%): Low scores, critical issues

**Complete!** You now have actionable customer segments with all output files ready.

---

## Workflow 1: Command-Line Segmentation (Exploration → Final)

**Scenario**: You prefer command-line workflow or are scripting segmentation runs.

### Step 1: Prepare Your Data

```r
# Check your data structure
survey_data <- read.csv("data/customer_survey.csv")
head(survey_data)
summary(survey_data)

# Validate data quality
source("modules/segment/lib/segment_utils.R")
validation <- validate_input_data(
  data = survey_data,
  id_variable = "customer_id",
  clustering_vars = c("q1_product", "q2_service", "q3_value", "q4_support", "q5_recommend")
)
```

### Step 2: Create Exploration Configuration

```r
# Generate config template
generate_config_template(
  data_file = "data/customer_survey.csv",
  output_file = "config/exploration.xlsx",
  mode = "exploration"
)

# Edit config/exploration.xlsx:
# - id_variable: customer_id
# - clustering_vars: q1_product,q2_service,q3_value,q4_support,q5_recommend
# - k_min: 3
# - k_max: 6
# - outlier_detection: TRUE
```

### Step 3: Run Exploration

```r
source("modules/segment/run_segment.R")
result_exp <- turas_segment_from_config("config/exploration.xlsx")
```

### Step 4: Review Results and Choose k

Open `output/seg_exploration_report.xlsx`:

```
k | tot.withinss | avg_silhouette_width | Recommended
--|-------------|----------------------|------------
3 | 1520.3      | 0.38                 |
4 | 1120.5      | 0.52                 | ← Best
5 | 980.2       | 0.48                 |
6 | 890.1       | 0.42                 |
```

**Decision: Choose k=4** (highest silhouette, clear elbow)

### Step 5: Run Final Segmentation

```r
# Copy config, set k_fixed = 4
# Save as config/final_k4.xlsx

result_final <- turas_segment_from_config("config/final_k4.xlsx")
```

### Step 6: Name and Interpret Segments

Review profiles in `output/seg_final_report.xlsx`:

| Variable | Seg1 | Seg2 | Seg3 | Seg4 |
|----------|------|------|------|------|
| Product  | 8.9  | 7.2  | 3.1  | 5.8  |
| Service  | 9.1  | 7.0  | 2.8  | 4.2  |
| Value    | 8.5  | 6.8  | 3.5  | 7.5  |
| Support  | 8.7  | 7.1  | 2.5  | 4.0  |

**Segment Names**:
- Seg1 → "Advocates" (high on all)
- Seg2 → "Satisfied" (above average)
- Seg3 → "Detractors" (low on all)
- Seg4 → "Value Seekers" (high value, lower service)

---

## Workflow 2: Variable Selection (Many Variables)

**Scenario**: Survey has 30 satisfaction questions, unsure which to use for clustering.

**Note**: This works in both GUI and command-line modes. Example shows command-line.

### Step 1: Enable Variable Selection

```r
# config/varsel.xlsx settings:
# clustering_vars: q1,q2,q3,...,q30 (all 30 variables)
# variable_selection: TRUE
# variable_selection_method: variance_correlation
# max_clustering_vars: 10
# varsel_min_variance: 0.1
# varsel_max_correlation: 0.8
```

### Step 2: Run with Variable Selection

```r
result <- turas_segment_from_config("config/varsel.xlsx")
```

**Console Output**:
```
================================================================================
VARIABLE SELECTION
================================================================================

Step 1: Analyzing variance (threshold: 0.10)
  Removed 3 low-variance variables: q12, q18, q25
  Remaining: 27

Step 2: Analyzing correlations (threshold: 0.80)
  Found 8 highly correlated pairs
  Removed 8 correlated variables: q2, q7, q9, q14, q19, q22, q27, q28
  Remaining: 19

Step 3: Ranking variables (19 → 10)
  Using variance ranking: selected top 10 variables

✓ Variable selection complete: 30 → 10 variables

VARIABLE SELECTION SUMMARY
==========================
Selected variables:
  q1, q3, q5, q8, q11, q15, q17, q21, q24, q30
```

### Step 3: Review Selection Report

Check `output/seg_final_report.xlsx` → VarSel_Statistics sheet:

| Variable | Variance | SD | Selected |
|----------|----------|----|----------|
| q1       | 2.45     | 1.56 | TRUE   |
| q3       | 2.31     | 1.52 | TRUE   |
| q2       | 2.28     | 1.51 | FALSE (corr with q1) |

### Step 4: Manual Override (Optional)

If you want to force include q10:

```r
# Edit config, change:
# clustering_vars: q1,q3,q5,q8,q10,q11,q15,q17,q21,q24
# variable_selection: FALSE

# Re-run
result_manual <- turas_segment_from_config("config/manual_vars.xlsx")
```

---

## Workflow 3: Scoring New Survey Responses

**Scenario**: Monthly survey with ongoing responses. Need to assign new respondents to existing segments.

### Step 1: Ensure Model is Saved

Initial segmentation config must have:
```
save_model: TRUE
```

This creates `output/seg_model.rds`

### Step 2: Load New Data

```r
# New month's survey responses
new_responses <- read.csv("data/january_2024_responses.csv")

# Must have same clustering variables as original
# e.g., q1_product, q2_service, q3_value, q4_support, q5_recommend
```

### Step 3: Score New Data

```r
source("modules/segment/lib/segment_scoring.R")

scores <- score_new_data(
  model_file = "output/2023_segmentation/seg_model.rds",
  new_data = new_responses,
  id_variable = "customer_id",
  output_file = "output/january_2024_scores.xlsx"
)
```

**Output**: `january_2024_scores.xlsx`

| customer_id | segment | segment_name | distance_to_center | assignment_confidence |
|-------------|---------|--------------|-------------------|----------------------|
| 5001        | 1       | Advocates    | 0.45              | 0.89                 |
| 5002        | 3       | Detractors   | 0.62              | 0.78                 |
| 5003        | 2       | Satisfied    | 0.38              | 0.92                 |

### Step 4: Monitor Segment Drift

```r
drift <- compare_segment_distributions(
  model_file = "output/2023_segmentation/seg_model.rds",
  scoring_result = scores
)
```

**Output**:
```
Segment | Original_N | Original_% | New_N | New_% | Difference
--------|------------|------------|-------|-------|------------
Advocates | 120 | 20% | 45 | 15% | -5%  ⚠ Declining
Satisfied | 360 | 60% | 250 | 63% | +3%
Detractors | 120 | 20% | 105 | 26% | +6%  ⚠ Growing
```

**Action**: If significant drift (>10%), consider re-segmenting with combined data.

---

## Workflow 4: Outlier Handling

**Scenario**: Data may contain data entry errors or extreme respondents.

### Configuration

```r
# config/outliers.xlsx:
# outlier_detection: TRUE
# outlier_method: zscore
# outlier_threshold: 3.0
# outlier_min_vars: 2
# outlier_handling: flag  # or "remove"
```

### Running

```r
result <- turas_segment_from_config("config/outliers.xlsx")
```

**Console Output**:
```
================================================================================
OUTLIER DETECTION
================================================================================

Method: Z-score
Threshold: 3.0
Minimum variables: 2

Analyzing 5 clustering variables...
  Variable q1: 2 potential outliers
  Variable q2: 3 potential outliers
  Variable q3: 1 potential outliers
  Variable q4: 0 potential outliers
  Variable q5: 2 potential outliers

✓ Identified 6 outlier respondents (outliers on 2+ variables)
  Handling: flag
  Outliers will be included in clustering but flagged in output
```

### Reviewing Outliers

Check `output/seg_final_report.xlsx` → Outliers sheet:

| respondent_id | q1_zscore | q2_zscore | q3_zscore | num_outlier_vars |
|---------------|-----------|-----------|-----------|------------------|
| 42            | -3.8      | -3.2      | -2.1      | 2                |
| 157           | 4.2       | 3.9       | 1.8       | 2                |

### Decision

- **Keep outliers**: Real extreme customers (very happy/unhappy)
- **Remove outliers**: Data entry errors, inconsistent responses

To remove, change `outlier_handling: remove` and re-run.

---

## Workflow 5: Validation and Quality Checks

**Scenario**: Want to ensure segment quality before presenting to stakeholders.

### Run Comprehensive Validation

```r
source("modules/segment/lib/segment_validation.R")

validation <- validate_segmentation(
  data = survey_data,
  clusters = result$clusters,
  clustering_vars = c("q1","q2","q3","q4","q5"),
  k = 4,
  n_bootstrap = 100
)
```

**Output**:
```
================================================================================
SEGMENT SEPARATION METRICS
================================================================================

Calinski-Harabasz Index: 342.15
  Higher is better. Typical range: 10-1000+

Davies-Bouldin Index: 0.68
  Lower is better. Good segmentation: < 1.0

================================================================================
SEGMENT STABILITY ANALYSIS
================================================================================

Running 100 bootstrap iterations...
  Iteration 20/100
  Iteration 40/100
  ...

✓ Stability analysis complete
  Average Jaccard similarity: 0.78
  Interpretation: Good - segments are reasonably stable

================================================================================
DISCRIMINANT ANALYSIS
================================================================================

Performing Linear Discriminant Analysis (LDA)...

✓ Discriminant analysis complete
  Classification accuracy: 89.2%
  Interpretation: Excellent - segments are very well separated

================================================================================
OVERALL VALIDATION SUMMARY
================================================================================

Overall Quality: GOOD - Acceptable segmentation
Quality Score: 2.3/3.0
```

### Enhanced Statistical Profiling

```r
source("modules/segment/lib/segment_profiling_enhanced.R")

enhanced <- create_enhanced_profile_report(
  data = survey_data,
  clusters = result$clusters,
  clustering_vars = c("q1","q2","q3","q4","q5"),
  profile_vars = c("age","spend","tenure"),
  output_path = "output/enhanced_profile.xlsx"
)
```

**Output Excel** → Significance_Tests sheet:

| Variable | Test | P_Value | Significant | Effect_Size |
|----------|------|---------|-------------|-------------|
| q1       | ANOVA | <0.001 | TRUE | 0.82 (Large) |
| q2       | ANOVA | <0.001 | TRUE | 0.75 (Large) |
| age      | ANOVA | 0.234  | FALSE | 0.05 (Small) |
| spend    | ANOVA | 0.018  | TRUE | 0.28 (Small) |

**Interpretation**: q1 and q2 strongly differentiate segments. Age doesn't matter much.

---

## Workflow 6: Creating Visualizations

**Scenario**: Need charts for presentation.

### Generate All Standard Visualizations

```r
source("modules/segment/lib/segment_visualization.R")

create_all_visualizations(
  result = result,
  output_folder = "output/charts/",
  prefix = "customer_seg_",
  question_labels = config$question_labels
)
```

**Output Files**:
- `customer_seg_k_selection.png` - Elbow + silhouette plots
- `customer_seg_segment_sizes.png` - Bar chart
- `customer_seg_profiles_heatmap.png` - Heatmap
- `customer_seg_profiles_spider.png` - Radar chart

### Individual Plots

```r
# Just segment sizes
plot_segment_sizes(
  clusters = result$clusters,
  segment_names = c("Advocates","Satisfied","At-Risk","Detractors"),
  output_file = "presentation/seg_sizes.png"
)

# Just heatmap
plot_segment_profiles(
  profile = result$profile,
  question_labels = config$question_labels,
  output_file = "presentation/profiles.png"
)
```

---

## Workflow 7: Project Initialization

**Scenario**: Starting brand new segmentation project.

### Initialize Project Structure

```r
source("modules/segment/lib/segment_utils.R")

initialize_segmentation_project(
  project_name = "Q1_2024_Customer_Segmentation",
  data_file = "data/q1_survey.csv",
  base_folder = "projects/"
)
```

**Created Structure**:
```
projects/Q1_2024_Customer_Segmentation/
├── config/
│   └── segmentation_config.xlsx  (template generated)
├── output/
├── data/
├── reports/
└── README.txt
```

### Edit Config and Run

```r
# 1. Edit projects/Q1_2024_Customer_Segmentation/config/segmentation_config.xlsx
# 2. Fill in required fields

# 3. Run segmentation
result <- turas_segment_from_config(
  "projects/Q1_2024_Customer_Segmentation/config/segmentation_config.xlsx"
)

# Results automatically saved to projects/Q1_2024_Customer_Segmentation/output/
```

---

## Tips and Tricks

### Quick Test Run

To quickly test configuration without full analysis:

```r
# Set small k range
k_min = 3
k_max = 3  # Only test k=3

# Disable expensive features
outlier_detection = FALSE
variable_selection = FALSE
create_dated_folder = FALSE
```

### Reproducible Results

Always set seed for same results:

```
seed = 123
```

### Batch Processing Multiple Surveys

```r
surveys <- c("jan_2024.csv", "feb_2024.csv", "mar_2024.csv")

for (survey in surveys) {
  # Update config with new data file
  config_month <- paste0("config/", tools::file_path_sans_ext(survey), ".xlsx")

  # Run segmentation
  result <- turas_segment_from_config(config_month)

  cat(sprintf("✓ Completed %s\n", survey))
}
```

---

**End of Example Workflows**

For more details, see `USER_MANUAL.md`
