# Segmentation Module - Testing Checklist

**Before merging to main, test with real data following this checklist.**

---

## Prerequisites

- [ ] Real survey data file ready (CSV or Excel)
- [ ] Data has respondent ID column
- [ ] Data has 5-15 numeric variables for clustering
- [ ] At least 100 respondents in data

---

## Test 1: Basic Segmentation (Exploration Mode)

### 1.1 Inspect Your Data

```r
# Check data structure
your_data <- read.csv("path/to/your/survey.csv")
str(your_data)
summary(your_data)
names(your_data)
```

**Expected**: See column names, data types, summary statistics

### 1.2 Generate Configuration

```r
source("modules/segment/lib/segment_utils.R")

generate_config_template(
  data_file = "path/to/your/survey.csv",
  output_file = "config/test_real.xlsx",
  mode = "exploration"
)
```

**Expected**:
- [ ] Config file created at `config/test_real.xlsx`
- [ ] Console shows detected variables

### 1.3 Edit Configuration

Open `config/test_real.xlsx` and fill in:

- [ ] `id_variable` - your ID column name
- [ ] `clustering_vars` - comma-separated list of 5-10 variables
- [ ] `k_min` - 3 (or your choice)
- [ ] `k_max` - 6 (or your choice)
- [ ] Save and close Excel

### 1.4 Validate Data Quality

```r
source("modules/segment/lib/segment_utils.R")

validation <- validate_input_data(
  data = your_data,
  id_variable = "your_id_column",
  clustering_vars = c("var1", "var2", "var3", "var4", "var5")
)
```

**Expected**:
- [ ] Validation passes (no errors)
- [ ] Warnings are acceptable (< 20% missing data)

### 1.5 Run Segmentation

```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("config/test_real.xlsx")
```

**Expected Output**:
- [ ] Configuration loads successfully
- [ ] Data preparation completes
- [ ] Clustering runs for each k
- [ ] No errors in console
- [ ] Message shows output folder location

**Time**: ~30 seconds to 2 minutes depending on data size

### 1.6 Review Results

Check output folder for files:

- [ ] `seg_exploration_report.xlsx` - Exists and opens
- [ ] `seg_segment_profiles_k3.xlsx` - Exists
- [ ] `seg_segment_profiles_k4.xlsx` - Exists
- [ ] `seg_k_selection.png` - Image shows elbow and silhouette plots
- [ ] `seg_model.rds` - Model file exists

### 1.7 Interpret Results

Open `seg_exploration_report.xlsx`:

**Metrics_Comparison sheet:**
- [ ] See rows for k=3, 4, 5, 6
- [ ] `tot.withinss` decreases as k increases
- [ ] `avg_silhouette_width` has clear maximum
- [ ] Can identify "best" k

**Profile sheets:**
- [ ] Each k has a profile sheet
- [ ] Segments show meaningful differences
- [ ] No segment has < 10% of respondents

---

## Test 2: Final Segmentation (With Chosen k)

### 2.1 Choose Optimal k

From exploration report:
- [ ] Identified optimal k (e.g., k=4)
- [ ] Silhouette score > 0.4

### 2.2 Update Configuration

Copy config, set:
- `k_fixed = 4` (your chosen k)
- Save as `config/test_real_final.xlsx`

### 2.3 Run Final Segmentation

```r
result_final <- turas_segment_from_config("config/test_real_final.xlsx")
```

**Expected**:
- [ ] Runs without errors
- [ ] Completes faster than exploration (single k)

### 2.4 Review Final Results

Check output folder:

- [ ] `seg_final_report.xlsx` - Complete report
- [ ] `seg_assignments.xlsx` - Respondent assignments
- [ ] `seg_segment_sizes.png` - Bar chart
- [ ] `seg_profiles_heatmap.png` - Heatmap exists

**Final Report Contents:**
- [ ] Summary sheet with key stats
- [ ] Profiles sheet with segment means
- [ ] Assignments sheet has all respondent IDs

---

## Test 3: Question Labels (Optional)

### 3.1 Create Question Labels File

Create Excel file with "Labels" sheet:

| Variable | Label |
|----------|-------|
| q1       | Overall satisfaction |
| q2       | Product quality |
| q3       | Service responsiveness |

Save as `config/question_labels.xlsx`

### 3.2 Add to Configuration

In config Excel:
- Add row: `question_labels_file | config/question_labels.xlsx`

### 3.3 Run with Labels

```r
result_labeled <- turas_segment_from_config("config/test_real_final.xlsx")
```

**Expected**:
- [ ] Console shows "✓ Loaded N question labels"
- [ ] Excel reports show labels: "q1: Overall satisfaction"
- [ ] Not just "q1"

---

## Test 4: Advanced Features

### 4.1 Test Outlier Detection

Update config:
```
outlier_detection = TRUE
outlier_handling = flag
```

Run segmentation:

**Expected**:
- [ ] Console shows outlier detection section
- [ ] Reports number of outliers found
- [ ] Outliers sheet in Excel report

### 4.2 Test Variable Selection

Update config:
```
clustering_vars = q1,q2,q3,...,q20  (20 variables)
variable_selection = TRUE
max_clustering_vars = 10
```

Run segmentation:

**Expected**:
- [ ] Console shows "VARIABLE SELECTION" section
- [ ] Reduces 20 → 10 variables
- [ ] Shows which variables removed
- [ ] VarSel sheets in Excel report

### 4.3 Test Model Scoring

```r
source("modules/segment/lib/segment_scoring.R")

# Load new data (or use same data to test)
new_data <- read.csv("path/to/new_responses.csv")

scores <- score_new_data(
  model_file = "output/[your_output_folder]/seg_model.rds",
  new_data = new_data,
  id_variable = "your_id_column",
  output_file = "output/test_scores.xlsx"
)
```

**Expected**:
- [ ] Loads model successfully
- [ ] Validates new data
- [ ] Assigns segments
- [ ] Creates output Excel with assignments
- [ ] Confidence scores included

### 4.4 Test Visualizations

```r
source("modules/segment/lib/segment_visualization.R")

create_all_visualizations(
  result = result_final,
  output_folder = "output/test_charts/",
  prefix = "test_"
)
```

**Expected**:
- [ ] Creates 4 PNG files
- [ ] Segment sizes bar chart
- [ ] Profile heatmap
- [ ] Spider chart (if fmsb installed)
- [ ] Images open correctly

### 4.5 Test Validation Metrics

```r
source("modules/segment/lib/segment_validation.R")

validation <- validate_segmentation(
  data = your_data,
  clusters = result_final$clusters,
  clustering_vars = c("var1", "var2", "var3", "var4", "var5"),
  k = 4,
  n_bootstrap = 50  # Use 50 for faster testing
)
```

**Expected**:
- [ ] Bootstrap stability runs (~30 sec)
- [ ] Discriminant analysis completes
- [ ] Separation metrics calculated
- [ ] Overall quality assessment shown
- [ ] No errors

### 4.6 Test Enhanced Profiling

```r
source("modules/segment/lib/segment_profiling_enhanced.R")

enhanced <- create_enhanced_profile_report(
  data = your_data,
  clusters = result_final$clusters,
  clustering_vars = c("var1", "var2", "var3", "var4", "var5"),
  output_path = "output/test_enhanced.xlsx"
)
```

**Expected**:
- [ ] Creates Excel with 3 sheets
- [ ] Significance_Tests sheet with p-values
- [ ] Index_Scores sheet
- [ ] Effect_Sizes sheet
- [ ] No errors

---

## Test 5: GUI Testing (Optional)

### 5.1 Launch via Turas

```r
source("launch_turas.R")
# Click "Launch Segment"
```

**Expected**:
- [ ] Segment GUI opens
- [ ] Can select config file
- [ ] Shows config summary
- [ ] Run button works
- [ ] Progress shown
- [ ] Results message displayed

---

## Test 6: Error Handling

Test that errors are caught gracefully:

### 6.1 Missing Data File

Config with non-existent file:
- [ ] Clear error message (not crash)

### 6.2 Missing Clustering Variables

Config with wrong variable names:
- [ ] Clear error message
- [ ] Lists missing variables

### 6.3 Too Few Respondents

Data with < 50 rows:
- [ ] Warning message shown

### 6.4 Too Much Missing Data

Data with 50% missing:
- [ ] Warning or error as appropriate

---

## Final Verification

Before merging to main:

- [ ] All basic tests pass
- [ ] At least 2-3 advanced features tested
- [ ] No crashes or unexpected errors
- [ ] Output files readable and sensible
- [ ] Visualizations display correctly
- [ ] Documentation matches behavior
- [ ] Ready for production use

---

## If Issues Found

Document any issues:

1. **What test failed?**
2. **What was the error message?**
3. **Can you reproduce it?**
4. **Is it a blocker for merge?**

Report back before merging.

---

## Success Criteria

**Minimum for merge:**
- ✅ Tests 1, 2 pass completely
- ✅ At least 1 advanced feature works (Test 4)
- ✅ No critical errors
- ✅ Results make sense

**Ideal:**
- ✅ All 6 test sections pass
- ✅ All features work as documented
- ✅ Performance acceptable
- ✅ Ready for end users

---

**Total Testing Time**: 30-60 minutes for complete checklist
