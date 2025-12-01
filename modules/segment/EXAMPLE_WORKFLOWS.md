# Turas Segmentation - Example Workflows

**Common Use Cases and Step-by-Step Examples**

---

## Workflow 0: GUI-Based Segmentation (Easiest - Start Here!)

**Scenario**: You want to use the GUI interface with real-time console output for easy interaction.

**Best For**: First-time users, interactive exploration, visual feedback during analysis

### Step 1: Launch the GUI

```r
source("modules/segment/run_segment_gui.R")
run_segment_gui()
```

The GUI window opens in your browser.

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
