# Turas Segmentation Module - Example Workflows

**Version:** 11.0
**Last Updated:** 5 March 2026

This document provides practical step-by-step workflows for common segmentation scenarios.

---

## Table of Contents

1. [K-Means: GUI Exploration to Final](#workflow-1-k-means-gui-exploration-to-final)
2. [K-Means: Command Line Basic](#workflow-2-k-means-command-line-basic)
3. [Hierarchical Clustering Workflow](#workflow-3-hierarchical-clustering)
4. [Gaussian Mixture Model Workflow](#workflow-4-gaussian-mixture-model)
5. [HTML Report Generation](#workflow-5-html-report-generation)
6. [Variable Selection with Many Variables](#workflow-6-variable-selection)
7. [Scoring New Survey Responses](#workflow-7-scoring-new-data)
8. [Outlier Handling](#workflow-8-outlier-handling)
9. [Validation and Quality Checks](#workflow-9-validation)
10. [Segment Interpretation and Naming](#workflow-10-interpretation)
11. [Demo Showcase](#workflow-11-demo-showcase)
12. [Troubleshooting Guide](#troubleshooting-guide)

---

## Workflow 1: K-Means GUI Exploration to Final

**Scenario:** Run complete K-means segmentation analysis using the GUI interface.

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
method                 | kmeans
k_fixed                | [BLANK]
k_min                  | 3
k_max                  | 6
standardize            | TRUE
html_report            | TRUE
output_folder          | output/
output_prefix          | seg_
project_name           | Customer Segmentation
```

### Step 3: Run Exploration

1. Click **"Browse..."** -> Select exploration_config.xlsx
2. Click **"Validate Configuration"** -> Wait for checkmark
3. Click **"Run Segmentation Analysis"**
4. Monitor console output:

```
========================================
TURAS SEGMENTATION ANALYSIS
========================================
Mode: Exploration (testing k = 3 to 6)
Method: KMEANS

[1/7] Loading configuration...
  Configuration loaded

[2/7] Loading and preparing data...
  Data loaded: 500 rows, 10 columns

[4/7] Running clustering...
  Clustering method: KMEANS
  Testing k=3... Silhouette: 0.38
  Testing k=4... Silhouette: 0.52  <- Highest
  Testing k=5... Silhouette: 0.48
  Testing k=6... Silhouette: 0.41

  Analysis complete!
  Recommended k: 4 (Silhouette: 0.52)

[7/7] Generating output...
  HTML report: output/seg_exploration_report.html
```

### Step 4: Review Exploration Report

Open `seg_exploration_report.html` in your browser to interactively review:
- Elbow plot and silhouette chart side by side
- Metrics comparison table
- Solution preview cards for each k value

Or open `seg_exploration_report.xlsx` for the raw data:

**Metrics_Comparison sheet:**
| k | silhouette | tot.withinss | recommendation |
|---|------------|--------------|----------------|
| 3 | 0.38 | 1520 | |
| 4 | 0.52 | 1120 | <- Best |
| 5 | 0.48 | 980 | |
| 6 | 0.41 | 890 | |

**Decision:** Choose k=4 (highest silhouette)

### Step 5: Create Final Configuration

Copy exploration_config.xlsx -> final_config.xlsx

Change:
```
k_fixed                | 4
segment_names          | Advocates,Satisfied,At-Risk,Detractors
generate_action_cards  | TRUE
generate_rules         | TRUE
html_show_rules        | TRUE
```

### Step 6: Run Final Segmentation

1. Click **"Browse..."** -> Select final_config.xlsx
2. Click **"Validate Configuration"**
3. Click **"Run Segmentation Analysis"**

### Step 7: Review Final Results

**Console output:**
```
  Analysis Complete!

  Number of Segments: 4
  Silhouette Score: 0.52

  Segment Sizes:
  - Advocates: 100 (20%)
  - Satisfied: 250 (50%)
  - At-Risk: 100 (20%)
  - Detractors: 50 (10%)

  Output Files:
  Final Report: output/seg_final_report.xlsx
  HTML Report:  output/seg_final_report.html
  Assignments:  output/seg_assignments.xlsx
  Model:        output/seg_model.rds
```

Open `seg_final_report.html` for the interactive report with executive summary, profile heatmap, action cards, and classification rules.

---

## Workflow 2: K-Means Command Line Basic

**Scenario:** Run segmentation from R command line.

### Step 1: Prepare Configuration

Create `config/segmentation.xlsx` with Config sheet:

```
Setting                | Value
-----------------------|--------------------------------
data_file              | data/survey.csv
id_variable            | resp_id
clustering_vars        | satisfaction,loyalty,recommend,quality
method                 | kmeans
k_min                  | 3
k_max                  | 5
standardize            | TRUE
html_report            | TRUE
```

### Step 2: Run Exploration

```r
source("modules/segment/run_segment.R")

# Run exploration
result_exp <- turas_segment_from_config("config/segmentation.xlsx")

# View recommendations
print(result_exp$recommendation)
```

### Step 3: Choose K and Run Final

```r
# Use Quick Run for the final mode
source("modules/segment/R/10_utilities.R")

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

# Already exported to output/ directory
```

---

## Workflow 3: Hierarchical Clustering

**Scenario:** Use hierarchical clustering to explore nested cluster structure.

### Step 1: Configure for Hierarchical Clustering

**Config Excel (hclust_config.xlsx):**
```
Setting                | Value
-----------------------|--------------------------------
data_file              | data/customer_survey.csv
id_variable            | respondent_id
clustering_vars        | q1_product,q2_service,q3_value,q4_support,q5_recommend
method                 | hclust
linkage_method         | ward.D2
k_fixed                | [BLANK]
k_min                  | 3
k_max                  | 6
standardize            | TRUE
html_report            | TRUE
output_folder          | output/hclust/
report_title           | Hierarchical Segmentation Analysis
project_name           | Hierarchical Clustering
```

### Step 2: Run Exploration

```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("hclust_config.xlsx")
```

**Console output:**
```
  Clustering method: HCLUST
    Linkage method: ward.D2
    Computing distance matrix (500 x 500)...
    Fitting hierarchical model...
    Cophenetic correlation: 0.78 (Good)
    Cutting tree at k=3... Silhouette: 0.41
    Cutting tree at k=4... Silhouette: 0.49
    Cutting tree at k=5... Silhouette: 0.45
    Cutting tree at k=6... Silhouette: 0.39
```

### Step 3: Compare Linkage Methods

Try different linkage methods to find the best fit:

```
linkage_method | ward.D2     -> run -> cophenetic: 0.78, sil(k=4): 0.49
linkage_method | complete    -> run -> cophenetic: 0.72, sil(k=4): 0.46
linkage_method | average     -> run -> cophenetic: 0.81, sil(k=4): 0.47
```

Choose the linkage with the best balance of cophenetic correlation and silhouette.

### Step 4: Run Final

Update config:
```
k_fixed                | 4
linkage_method         | ward.D2
segment_names          | Advocates,Satisfied,At-Risk,Detractors
```

Re-run analysis.

### Step 5: Review Hierarchical-Specific Output

The HTML report includes additional metrics:
- **Cophenetic Correlation:** How well the dendrogram preserves distances
- **Linkage Method:** Which linkage was used

---

## Workflow 4: Gaussian Mixture Model

**Scenario:** Use GMM for soft-assignment clustering with membership probabilities.

### Step 1: Install mclust

```r
install.packages("mclust")
```

### Step 2: Configure for GMM

**Config Excel (gmm_config.xlsx):**
```
Setting                | Value
-----------------------|--------------------------------
data_file              | data/customer_survey.csv
id_variable            | respondent_id
clustering_vars        | q1_product,q2_service,q3_value,q4_support,q5_recommend
method                 | gmm
gmm_model_type         | [BLANK]
k_fixed                | 4
standardize            | TRUE
html_report            | TRUE
output_folder          | output/gmm/
brand_colour           | #8E44AD
report_title           | GMM Segmentation Analysis
project_name           | Gaussian Mixture Model
```

### Step 3: Run Analysis

```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("gmm_config.xlsx")
```

**Console output:**
```
  Clustering method: GMM
    Fitting GMM with k = 4...
    Best model type: VVV (selected by BIC)
    BIC: -4521.3
    Average max probability: 0.87
    Borderline assignments (< 0.60): 23 (4.6%)

  Analysis complete!
```

### Step 4: Review GMM-Specific Output

**Assignments file** (`seg_assignments.xlsx`) includes:

| respondent_id | segment_id | segment_name | prob_segment_1 | prob_segment_2 | prob_segment_3 | prob_segment_4 | max_probability | uncertainty |
|---------------|------------|--------------|----------------|----------------|----------------|----------------|-----------------|-------------|
| 1001 | 1 | Advocates | 0.92 | 0.05 | 0.02 | 0.01 | 0.92 | 0.08 |
| 1002 | 3 | At-Risk | 0.08 | 0.12 | 0.73 | 0.07 | 0.73 | 0.27 |
| 1003 | 2 | Satisfied | 0.03 | 0.55 | 0.35 | 0.07 | 0.55 | 0.45 |

**HTML report** includes a GMM Membership section showing:
- Mean probability per segment
- Maximum uncertainty
- Number of borderline assignments

### Step 5: Investigate Borderline Cases

Respondents with low max probability (< 0.60) are "borderline" and may not belong clearly to any segment. Consider:
- Reviewing their profiles manually
- Assigning them to the most similar segment with a flag
- Treating them as a separate "transitional" group

---

## Workflow 5: HTML Report Generation

**Scenario:** Generate a branded, interactive HTML report for stakeholder delivery.

### Step 1: Configure Report Settings

```
Setting                  | Value
-------------------------|--------------------------------
html_report              | TRUE
brand_colour             | #D35400
accent_colour            | #27AE60
report_title             | Q1 2026 Customer Segmentation
html_show_exec_summary   | TRUE
html_show_overview       | TRUE
html_show_validation     | TRUE
html_show_importance     | TRUE
html_show_profiles       | TRUE
html_show_rules          | TRUE
html_show_cards          | TRUE
html_show_guide          | TRUE
generate_rules           | TRUE
generate_action_cards    | TRUE
```

### Step 2: Run Analysis

```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("config.xlsx")
```

### Step 3: Open the HTML Report

The report is a single self-contained `.html` file. Open it in any modern browser (Chrome, Firefox, Edge, Safari).

### Step 4: Navigate the Report

- **Sticky nav bar:** Jump between sections
- **Executive Summary:** High-level quality assessment and key findings
- **Segment Overview:** Sizes chart and composition table
- **Cluster Validation:** Silhouette chart and metrics
- **Variable Importance:** Which variables differentiate segments most
- **Segment Profiles:** Heatmap and detailed profile table
- **Classification Rules:** Plain-English IF-THEN rules
- **Action Cards:** Executive-ready cards with recommendations
- **Interpretation Guide:** How to read the report

### Step 5: Curate Findings with Pinned Views

1. Hover over any chart or table to reveal the pin button
2. Click the pin button to add the view to the Pinned Views workspace
3. Scroll to the bottom to see all pinned views collected together
4. Click "Export All as PNG" to save for presentations
5. Click "Print / PDF" for a formatted print layout

### Step 6: Share the Report

The HTML file has no external dependencies. Share it via email, file share, or upload to the Turas Report Hub.

---

## Workflow 6: Variable Selection

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
method                    | kmeans
k_min                     | 3
k_max                     | 5
html_report               | TRUE
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

Step 3: Ranking variables (19 -> 10)
  Selected top 10 by variance

  Variable selection complete: 30 -> 10 variables

SELECTED VARIABLES:
  Q01, Q03, Q05, Q08, Q11, Q15, Q17, Q21, Q24, Q30
```

### Step 3: Review Selection Report

The analysis automatically uses selected variables. The report includes a variable selection summary sheet in the Excel output.

---

## Workflow 7: Scoring New Data

**Scenario:** Monthly survey with ongoing responses to classify.

### Step 1: Initial Segmentation (One-Time)

Ensure model is saved:
```
save_model | TRUE
```

Run initial segmentation -> Creates `seg_model.rds`

### Step 2: Load New Survey Data

```r
# New month's responses
new_responses <- read.csv("data/march_2026_responses.csv")

# Check structure matches original
head(new_responses)
```

### Step 3: Score New Respondents

```r
source("modules/segment/R/08_scoring.R")

scores <- score_new_data(
  model_file = "output/seg_model.rds",
  new_data = new_responses,
  id_variable = "respondent_id",
  output_file = "output/march_2026_scores.xlsx"
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
Advocates   | 20%      | 15%    | -5%
Satisfied   | 50%      | 55%    | +5%
At-Risk     | 20%      | 22%    | +2%
Detractors  | 10%      | 8%     | -2%

Chi-square test: p = 0.034 (Significant change)
Recommendation: Consider refreshing segmentation
```

---

## Workflow 8: Outlier Handling

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

  Identified 6 outlier respondents (extreme on 2+ variables)
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
- ID 42: All negative -> Consistently dissatisfied (keep)
- ID 157: All positive -> Super satisfied (keep)
- ID 289: Extreme on all -> Data entry error? (investigate)

**If removing outliers:**
```
outlier_handling | remove
```

Re-run analysis.

---

## Workflow 9: Validation

**Scenario:** Ensure segment quality before presenting to stakeholders.

### Step 1: Run with Stability Check

```
run_stability_check | TRUE
stability_n_runs    | 10
```

### Step 2: Review Validation in HTML Report

The HTML report's Cluster Validation section shows:
- Per-cluster silhouette scores (colour-coded by quality)
- Validation metrics table with interpretations
- Method-specific metrics (cophenetic for hclust, BIC for GMM)

### Step 3: Review Executive Summary

The Executive Summary section provides:
- Quality assessment (Excellent/Good/Moderate/Limited) based on silhouette
- Key findings summary
- Contextual insights from profile data

### Step 4: Quick Stability Check

```r
# Run stability assessment separately
source("modules/segment/R/04_validation.R")

stability <- check_stability_simple(
  data = survey_data,
  clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
  k = 4,
  n_runs = 10
)
```

**Output:**
```
Running 10 k-means iterations with different seeds...

STABILITY RESULTS
-----------------
Stability Score: 92%
Interpretation: EXCELLENT - Very stable segmentation
```

---

## Workflow 10: Interpretation

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

### Step 2: Use HTML Report Heatmap

The HTML report's profile heatmap provides a visual representation with colour coding:
- Blue = below average, White = average, Red = above average

### Step 3: Review Action Cards

If `generate_action_cards = TRUE`, the HTML report shows action cards:

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

### Step 4: Review Classification Rules

If `generate_rules = TRUE`, the HTML report shows rules like:

```
IF Q05_recommend > 7.5 AND Q01_product > 7.0 THEN Advocates    (accuracy: 94%)
IF Q05_recommend <= 7.5 AND Q01_product > 5.5 THEN Satisfied   (accuracy: 87%)
IF Q01_product <= 5.5 AND Q03_value > 4.0     THEN At-Risk     (accuracy: 82%)
IF Q01_product <= 5.5 AND Q03_value <= 4.0    THEN Detractors  (accuracy: 91%)
```

### Step 5: Pin Key Findings

Use the HTML report's pinned views to collect the most important charts, tables, and cards, then export as PNGs for your presentation.

---

## Workflow 11: Demo Showcase

**Scenario:** Run the built-in demo to see all three methods with HTML reports.

### Step 1: Navigate to Demo

```r
setwd("examples/segment/demo_showcase")
```

### Step 2: Generate Demo Data

```r
source("generate_demo_data.R")
```

This creates synthetic survey data suitable for demonstrating all three clustering methods.

### Step 3: Create Demo Configs

```r
source("create_demo_configs.R")
```

This generates configuration files for K-means, hierarchical, and GMM analyses.

### Step 4: Run the Demo

```r
source("run_demo.R")
```

This runs all three methods sequentially and generates:
- K-means final report (Excel + HTML)
- Hierarchical final report (Excel + HTML)
- GMM final report (Excel + HTML)

### Step 5: Compare Results

Open the three HTML reports side by side to compare:
- How each method handles the same data
- Differences in segment assignments
- GMM-specific membership probabilities
- Method-specific validation metrics

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
1. Increase nstart: `nstart = 50` (K-means only)
2. Set consistent seed: `seed = 123`
3. Try different k value
4. Check for outliers pulling centroids
5. Try hierarchical clustering (deterministic)

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
3. Try a different method (GMM may find elliptical clusters)
4. Accept that some data doesn't segment cleanly

---

### Issue: "PKG_MCLUST_MISSING"

**Error:** GMM method requires mclust package.

**Solution:**
```r
install.packages("mclust")
```

---

### Issue: "PKG_HTMLTOOLS_MISSING"

**Error:** HTML report requires htmltools package.

**Solution:**
```r
install.packages("htmltools")
```

Or set `html_report = FALSE` to skip HTML output.

---

### Issue: "Hierarchical clustering too slow"

**Cause:** Dataset exceeds ~15,000 rows (distance matrix is O(n^2) memory).

**Solutions:**
1. Switch to K-means for large datasets
2. Subsample the data
3. Install `fastcluster` for speed improvement: `install.packages("fastcluster")`

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

**Basic K-Means Exploration:**
```
method = kmeans, k_min = 3, k_max = 6, standardize = TRUE, html_report = TRUE
```

**Hierarchical with Ward Linkage:**
```
method = hclust, linkage_method = ward.D2, k_fixed = 4, html_report = TRUE
```

**GMM with Auto Model Selection:**
```
method = gmm, gmm_model_type = [BLANK], k_fixed = 4, html_report = TRUE
```

**With Outlier Detection:**
```
outlier_detection = TRUE, outlier_method = zscore, outlier_handling = flag
```

**With Variable Selection:**
```
variable_selection = TRUE, max_clustering_vars = 10
```

**Full Final Run with Enhanced Features:**
```
k_fixed = 4, segment_names = Name1,Name2,Name3,Name4, save_model = TRUE
generate_rules = TRUE, generate_action_cards = TRUE, run_stability_check = TRUE
html_report = TRUE, html_show_rules = TRUE
```

**Branded HTML Report:**
```
html_report = TRUE, brand_colour = #D35400, accent_colour = #27AE60
report_title = Customer Segmentation Q1 2026
```

---

## Additional Resources

- [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods
- [04_USER_MANUAL.md](04_USER_MANUAL.md) - Complete user guide
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Configuration fields
- [08_HTML_REPORT_GUIDE.md](08_HTML_REPORT_GUIDE.md) - HTML report reference

---

**Part of the Turas Analytics Platform**
