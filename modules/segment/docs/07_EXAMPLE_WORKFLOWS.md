# Turas Segmentation Module - Example Workflows

**Version:** 10.0
**Last Updated:** 22 December 2025

This document provides practical step-by-step workflows for common segmentation scenarios.

---

## Table of Contents

1. [GUI Workflow: Complete Exploration to Final](#workflow-1-gui-complete-exploration-to-final)
2. [Command Line: Basic Segmentation](#workflow-2-command-line-basic-segmentation)
3. [Variable Selection with Many Variables](#workflow-3-variable-selection)
4. [Scoring New Survey Responses](#workflow-4-scoring-new-data)
5. [Outlier Handling](#workflow-5-outlier-handling)
6. [Validation and Quality Checks](#workflow-6-validation)
7. [Segment Interpretation and Naming](#workflow-7-interpretation)
8. [Troubleshooting Guide](#troubleshooting-guide)

---

## Workflow 1: GUI Complete Exploration to Final

**Scenario:** Run complete segmentation analysis using the GUI interface.

### Step 1: Launch GUI

```r
source("modules/segment/run_segment_gui.R")
run_segment_gui()
```

### Step 2: Create Exploration Configuration

**Config Excel (exploration_config.xlsx):**
```
Setting                | Value
-----------------------|--------------------------------
data_file              | data/customer_survey.csv
id_variable            | respondent_id
clustering_vars        | q1_product,q2_service,q3_value,q4_support,q5_recommend
k_fixed                | [BLANK]
k_min                  | 3
k_max                  | 6
standardize            | TRUE
output_folder          | output/
output_prefix          | seg_
project_name           | Customer Segmentation
```

### Step 3: Run Exploration

1. Click **"Browse..."** → Select exploration_config.xlsx
2. Click **"Validate Configuration"** → Wait for ✓
3. Click **"Run Segmentation Analysis"**
4. Monitor console output:

```
========================================
TURAS SEGMENTATION ANALYSIS
========================================
Mode: Exploration (testing k = 3 to 6)

[1/6] Loading configuration...
✓ Configuration loaded

[2/6] Loading and preparing data...
✓ Data loaded: 500 rows, 10 columns

[3/6] Running k-means clustering...
Testing k=3... Silhouette: 0.38
Testing k=4... Silhouette: 0.52  ← Highest
Testing k=5... Silhouette: 0.48
Testing k=6... Silhouette: 0.41

✓ Analysis complete!
Recommended k: 4 (Silhouette: 0.52)
```

### Step 4: Review Exploration Report

Open `seg_exploration_report.xlsx`:

**Metrics_Comparison sheet:**
| k | silhouette | tot.withinss | recommendation |
|---|------------|--------------|----------------|
| 3 | 0.38 | 1520 | |
| 4 | 0.52 | 1120 | ← Best |
| 5 | 0.48 | 980 | |
| 6 | 0.41 | 890 | |

**Decision:** Choose k=4 (highest silhouette)

### Step 5: Create Final Configuration

Copy exploration_config.xlsx → final_config.xlsx

Change:
```
k_fixed                | 4
segment_names          | Advocates,Satisfied,At-Risk,Detractors
```

### Step 6: Run Final Segmentation

1. Click **"Browse..."** → Select final_config.xlsx
2. Click **"Validate Configuration"**
3. Click **"Run Segmentation Analysis"**

### Step 7: Review Final Results

**Results display shows:**
```
✓ Analysis Complete!

Number of Segments: 4
Silhouette Score: 0.52

Segment Sizes:
- Advocates: 100 (20%)
- Satisfied: 250 (50%)
- At-Risk: 100 (20%)
- Detractors: 50 (10%)

Output Files:
📊 Final Report: output/seg_final_report.xlsx
📋 Assignments: output/seg_assignments.xlsx
💾 Model: output/seg_model.rds
```

---

## Workflow 2: Command Line Basic Segmentation

**Scenario:** Run segmentation from R command line.

### Step 1: Prepare Configuration

Create `config/segmentation.xlsx` with Config sheet:

```
Setting                | Value
-----------------------|--------------------------------
data_file              | data/survey.csv
id_variable            | resp_id
clustering_vars        | satisfaction,loyalty,recommend,quality
k_min                  | 3
k_max                  | 5
standardize            | TRUE
```

### Step 2: Run Exploration

```r
source("modules/segment/run_segment.R")

# Run exploration
result_exp <- turas_segment_from_config("config/segmentation.xlsx")

# View recommendations
print(result_exp$recommendation)
```

**Output:**
```
K-Means Exploration Results
===========================
Tested k: 3, 4, 5
Best k: 4 (Silhouette: 0.51)

k | Silhouette | WCSS   | Sizes
--|------------|--------|------------------
3 | 0.42       | 1250   | 180, 220, 100
4 | 0.51       | 980    | 120, 200, 130, 50
5 | 0.47       | 850    | 100, 150, 120, 80, 50
```

### Step 3: Choose K and Run Final

```r
# Update config to set k_fixed = 4
# Or use Quick Run

result_final <- run_segment_quick(
  data = survey_data,
  id_var = "resp_id",
  clustering_vars = c("satisfaction", "loyalty", "recommend", "quality"),
  k = 4
)

# View profiles
print(result_final$profiles)
```

### Step 4: Export Results

```r
# Access assignments
assignments <- result_final$assignments
head(assignments)

# Save to Excel
writexl::write_xlsx(assignments, "output/segment_assignments.xlsx")
```

---

## Workflow 3: Variable Selection

**Scenario:** You have 30 survey questions and need to select the best subset.

### Step 1: Configure Variable Selection

**Config Excel:**
```
Setting                   | Value
--------------------------|--------------------------------
data_file                 | data/large_survey.csv
id_variable               | ResponseID
clustering_vars           | Q01,Q02,Q03,Q04,Q05,Q06,Q07,Q08,Q09,Q10,Q11,Q12,Q13,Q14,Q15,Q16,Q17,Q18,Q19,Q20,Q21,Q22,Q23,Q24,Q25,Q26,Q27,Q28,Q29,Q30
variable_selection        | TRUE
variable_selection_method | variance_correlation
max_clustering_vars       | 10
varsel_min_variance       | 0.1
varsel_max_correlation    | 0.8
k_min                     | 3
k_max                     | 5
```

### Step 2: Run Analysis

```r
result <- turas_segment_from_config("config/varsel.xlsx")
```

**Console output:**
```
================================================================================
VARIABLE SELECTION
================================================================================

Step 1: Analyzing variance (threshold: 0.10)
  Removed 3 low-variance variables: Q12, Q18, Q25
  Remaining: 27

Step 2: Analyzing correlations (threshold: 0.80)
  Found 8 highly correlated pairs
  Removed 8 correlated variables: Q02, Q07, Q09, Q14, Q19, Q22, Q27, Q28
  Remaining: 19

Step 3: Ranking variables (19 → 10)
  Selected top 10 by variance

✓ Variable selection complete: 30 → 10 variables

SELECTED VARIABLES:
  Q01, Q03, Q05, Q08, Q11, Q15, Q17, Q21, Q24, Q30
```

### Step 3: Review Selection Report

**seg_final_report.xlsx - VarSel_Statistics sheet:**

| Variable | Variance | Correlation | Selected | Reason |
|----------|----------|-------------|----------|--------|
| Q01 | 2.45 | - | YES | High variance |
| Q02 | 2.28 | 0.92 (Q01) | NO | Correlated with Q01 |
| Q03 | 2.31 | - | YES | High variance |
| Q12 | 0.05 | - | NO | Low variance |

### Step 4: Run Final with Selected Variables

The analysis automatically uses selected variables. Review profiles to confirm meaningful segments.

---

## Workflow 4: Scoring New Data

**Scenario:** Monthly survey with ongoing responses to classify.

### Step 1: Initial Segmentation (One-Time)

Ensure model is saved:
```
save_model | TRUE
```

Run initial segmentation → Creates `seg_model.rds`

### Step 2: Load New Survey Data

```r
# New month's responses
new_responses <- read.csv("data/march_2025_responses.csv")

# Check structure matches original
head(new_responses)
```

### Step 3: Score New Respondents

```r
source("modules/segment/lib/segment_scoring.R")

scores <- score_new_data(
  model_file = "output/seg_model.rds",
  new_data = new_responses,
  id_variable = "respondent_id",
  output_file = "output/march_2025_scores.xlsx"
)

# View results
head(scores)
```

**Output:**
```
  respondent_id  segment  segment_name  confidence
1         5001        1     Advocates       0.89
2         5002        3       At-Risk       0.72
3         5003        2     Satisfied       0.94
4         5004        4    Detractors       0.81
```

### Step 4: Monitor Segment Drift

```r
drift <- compare_segment_distributions(
  model_file = "output/seg_model.rds",
  scoring_result = scores
)

print(drift)
```

**Output:**
```
Segment Distribution Comparison
==============================
Segment     | Original | New    | Change
------------|----------|--------|--------
Advocates   | 20%      | 15%    | -5%  ⚠
Satisfied   | 50%      | 55%    | +5%
At-Risk     | 20%      | 22%    | +2%
Detractors  | 10%      | 8%     | -2%

Chi-square test: p = 0.034 (Significant change)
Recommendation: Consider refreshing segmentation
```

---

## Workflow 5: Outlier Handling

**Scenario:** Data may contain extreme respondents or errors.

### Step 1: Configure Outlier Detection

```
outlier_detection   | TRUE
outlier_method      | zscore
outlier_threshold   | 3.0
outlier_min_vars    | 2
outlier_handling    | flag
```

### Step 2: Run Analysis

```r
result <- turas_segment_from_config("config/outliers.xlsx")
```

**Console output:**
```
================================================================================
OUTLIER DETECTION
================================================================================

Method: Z-score (threshold: 3.0)
Minimum variables: 2

Analyzing 5 clustering variables...
  Variable q1: 3 potential outliers
  Variable q2: 2 potential outliers
  Variable q3: 1 potential outliers
  Variable q4: 0 potential outliers
  Variable q5: 2 potential outliers

✓ Identified 6 outlier respondents (extreme on 2+ variables)
  Handling: FLAG (included in clustering, marked in output)
```

### Step 3: Review Outlier Report

**seg_final_report.xlsx - Outliers sheet:**

| respondent_id | q1_zscore | q2_zscore | q3_zscore | extreme_vars |
|---------------|-----------|-----------|-----------|--------------|
| 42 | -3.8 | -3.2 | -1.1 | 2 |
| 157 | 4.2 | 3.9 | 1.8 | 2 |
| 289 | -3.1 | -3.5 | -2.8 | 3 |

### Step 4: Decision on Outliers

**Review each outlier:**
- ID 42: All negative → Consistently dissatisfied (keep)
- ID 157: All positive → Super satisfied (keep)
- ID 289: Extreme on all → Data entry error? (investigate)

**If removing outliers:**
```
outlier_handling | remove
```

Re-run analysis.

---

## Workflow 6: Validation

**Scenario:** Ensure segment quality before presenting to stakeholders.

### Step 1: Run Comprehensive Validation

```r
source("modules/segment/lib/segment_validation.R")

validation <- validate_segmentation(
  data = survey_data,
  clusters = result$clusters,
  clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
  k = 4,
  n_bootstrap = 100
)
```

### Step 2: Review Metrics

**Output:**
```
================================================================================
SEGMENT VALIDATION RESULTS
================================================================================

SEPARATION METRICS
------------------
Silhouette Score: 0.52 (Good)
Calinski-Harabasz Index: 342.15 (Higher is better)
Davies-Bouldin Index: 0.68 (Lower is better, < 1.0 good)

STABILITY ANALYSIS (100 bootstrap samples)
-----------------------------------------
Average Jaccard Similarity: 0.78
Interpretation: GOOD - Segments reasonably stable

Per-segment stability:
  Segment 1: 0.82 (Excellent)
  Segment 2: 0.79 (Good)
  Segment 3: 0.75 (Good)
  Segment 4: 0.71 (Acceptable)

DISCRIMINANT ANALYSIS
--------------------
LDA Classification Accuracy: 89.2%
Interpretation: EXCELLENT - Segments well separated

OVERALL QUALITY: GOOD
Quality Score: 2.3 / 3.0
```

### Step 3: Quick Stability Check

```r
stability <- check_stability_simple(
  data = survey_data,
  clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
  k = 4,
  n_runs = 5
)
```

**Output:**
```
Running 5 k-means iterations with different seeds...

STABILITY RESULTS
-----------------
Stability Score: 92%
Interpretation: EXCELLENT - Very stable segmentation

Run consistency:
  Average agreement: 92.3%
  Min: 89.5%
  Max: 95.1%
```

---

## Workflow 7: Interpretation

**Scenario:** Interpret segments and create meaningful names.

### Step 1: Review Profile Table

**seg_final_report.xlsx - Profiles sheet:**

| Variable | Seg 1 | Seg 2 | Seg 3 | Seg 4 | Overall |
|----------|-------|-------|-------|-------|---------|
| Product quality | 9.2 | 7.5 | 5.1 | 2.8 | 7.1 |
| Service quality | 9.0 | 7.3 | 4.8 | 3.2 | 6.9 |
| Value for money | 8.8 | 7.0 | 5.5 | 3.5 | 6.8 |
| Support | 8.9 | 7.4 | 4.9 | 2.5 | 6.7 |
| Recommend | 9.5 | 7.8 | 4.5 | 2.2 | 7.0 |
| **Size** | **100** | **250** | **100** | **50** | **500** |
| **Percent** | **20%** | **50%** | **20%** | **10%** | **100%** |

### Step 2: Calculate Index Scores

Index = (Segment Mean / Overall Mean) × 100

| Variable | Seg 1 | Seg 2 | Seg 3 | Seg 4 |
|----------|-------|-------|-------|-------|
| Product | 130 | 106 | 72 | 39 |
| Service | 130 | 106 | 70 | 46 |
| Value | 129 | 103 | 81 | 51 |
| Support | 133 | 110 | 73 | 37 |
| Recommend | 136 | 111 | 64 | 31 |

### Step 3: Identify Defining Characteristics

**Segment 1:** All indices > 125 → High on everything
**Segment 2:** All indices 100-115 → Slightly above average
**Segment 3:** All indices 65-80 → Below average
**Segment 4:** All indices < 50 → Very low on everything

### Step 4: Assign Names

| Segment | Name | Size | Key Characteristic |
|---------|------|------|-------------------|
| 1 | **Advocates** | 20% | High across all dimensions, likely to recommend |
| 2 | **Satisfied** | 50% | Above average, stable majority |
| 3 | **At-Risk** | 20% | Below average, intervention needed |
| 4 | **Detractors** | 10% | Low satisfaction, churn risk |

### Step 5: Create Action Recommendations

```r
source("modules/segment/lib/segment_cards.R")

cards <- generate_segment_cards(
  data = survey_data,
  clusters = result$clusters,
  clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
  segment_names = c("Advocates", "Satisfied", "At-Risk", "Detractors")
)

print_segment_cards(cards)
```

**Output:**
```
============================================================
SEGMENT: Advocates (20%)
============================================================
HEADLINE: High-satisfaction group, strong advocates

STRENGTHS:
  + Recommend intent: 9.5/10
  + Product quality: 9.2/10
  + Service quality: 9.0/10

RECOMMENDED ACTIONS:
  > Leverage as brand advocates
  > Gather testimonials
  > Offer referral programs
  > Maintain current service levels
============================================================
```

---

## Troubleshooting Guide

### Issue: "Insufficient complete cases"

**Error:** `Not enough complete cases (45). Need at least 120.`

**Cause:** Too much missing data after listwise deletion.

**Solutions:**
1. Check which variables have most missingness
2. Use mean imputation: `missing_data = mean_imputation`
3. Remove high-missing variables from clustering_vars
4. Get more data

**Diagnostic:**
```r
# Check missing by variable
colSums(is.na(data[, clustering_vars]))
```

---

### Issue: "Segments too small"

**Warning:** `Segment 4 has only 15 respondents (3%)`

**Cause:** A segment is below minimum size threshold.

**Solutions:**
1. Lower `min_segment_size_pct` if segments are meaningful
2. Reduce k (try k-1)
3. Review if outliers creating artificial segment
4. Accept if small segment is conceptually important

---

### Issue: "High VIF / Correlated variables"

**Warning:** `Variables q1 and q2 highly correlated (r = 0.92)`

**Cause:** Two variables measure essentially the same thing.

**Solutions:**
1. Enable variable selection: `variable_selection = TRUE`
2. Manually remove one variable
3. Combine into composite score

---

### Issue: "Unstable segments"

**Symptom:** Different runs produce different segment sizes

**Cause:** Multiple local optima, not enough random starts.

**Solutions:**
1. Increase nstart: `nstart = 50`
2. Set consistent seed: `seed = 123`
3. Try different k value
4. Check for outliers pulling centroids

---

### Issue: "Low silhouette score"

**Observation:** Silhouette = 0.28

**Meaning:** Segments not well separated.

**Possible Causes:**
1. Data doesn't have natural clusters
2. Wrong variables selected
3. Too many or too few segments

**Solutions:**
1. Try different k values
2. Review variable selection
3. Enable SHAP for non-linear patterns
4. Accept that some data doesn't segment cleanly

---

### Issue: "GUI grey screen"

**Symptom:** GUI loads but shows grey screen

**Cause:** R 4.2+ compatibility issue

**Solutions:**
1. Update to latest code version
2. Restart R session
3. Check R console for error messages
4. Ensure Shiny package is up to date

---

## Quick Reference

### Sample Size Requirements

| Segments (k) | Minimum n | Recommended n |
|--------------|-----------|---------------|
| 3 | 90 | 150+ |
| 4 | 120 | 200+ |
| 5 | 150 | 250+ |
| 6 | 180 | 300+ |

### Silhouette Interpretation

| Score | Quality |
|-------|---------|
| > 0.7 | Excellent |
| 0.5 - 0.7 | Good |
| 0.3 - 0.5 | Acceptable |
| < 0.3 | Weak |

### Common Configuration Patterns

**Basic Exploration:**
```
k_min = 3, k_max = 6, standardize = TRUE
```

**With Outlier Detection:**
```
outlier_detection = TRUE, outlier_method = zscore, outlier_handling = flag
```

**With Variable Selection:**
```
variable_selection = TRUE, max_clustering_vars = 10
```

**Final Run:**
```
k_fixed = 4, segment_names = Name1,Name2,Name3,Name4, save_model = TRUE
```

---

## Additional Resources

- [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods
- [04_USER_MANUAL.md](04_USER_MANUAL.md) - Complete user guide
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Configuration fields

---

**Part of the Turas Analytics Platform**
