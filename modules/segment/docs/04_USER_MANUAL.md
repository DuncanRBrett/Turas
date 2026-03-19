# Turas Segmentation Module -- User Manual

**Version:** 11.1
**Last Updated:** 19 March 2026
**Audience:** Market Researchers, Data Analysts, Survey Managers
**Module:** `modules/segment/`

------------------------------------------------------------------------

## Table of Contents

1.  [Introduction](#1-introduction)
2.  [Quick Start](#2-quick-start)
3.  [The Segmentation Workflow](#3-the-segmentation-workflow)
4.  [Choosing the Optimal Number of Segments](#4-choosing-the-optimal-number-of-segments)
5.  [Dealing with Partial Answers (Missing Data)](#5-dealing-with-partial-answers-missing-data)
6.  [Choosing the Right Model](#6-choosing-the-right-model)
7.  [Configuration Reference](#7-configuration-reference)
8.  [Interpreting Results](#8-interpreting-results)
9.  [Common Pitfalls](#9-common-pitfalls)
10. [R Package Dependencies](#10-r-package-dependencies)
11. [Troubleshooting](#11-troubleshooting)

------------------------------------------------------------------------

## 1. Introduction

### What Is Segmentation?

Market segmentation is the process of dividing a population of respondents into groups (segments) that are internally similar and externally different. Respondents within a segment share attitudes, needs, or behaviours that distinguish them from respondents in other segments.

In a survey context, segmentation takes a set of numeric variables -- satisfaction ratings, agreement scales, importance scores, brand perceptions -- and finds natural groupings among respondents based on how they answered those questions. The result is a set of segments, each with a distinct profile that can be named, described, and acted upon.

### Why Segmentation Matters for Market Research

**Segmentation turns data into strategy.** Without segmentation, a survey produces averages that describe nobody in particular. With segmentation, the same data reveals distinct groups of customers, each with their own needs, pain points, and behaviours. This enables:

- **Targeted messaging** -- Speak to each segment in language that resonates with their specific concerns.
- **Product prioritisation** -- Focus development on features that matter most to your most valuable segments.
- **Resource allocation** -- Direct marketing spend toward segments with the highest potential return.
- **Tracking over time** -- Monitor whether segments are growing, shrinking, or changing in composition.
- **Customer understanding** -- Move beyond demographics to understand why people behave the way they do.

### How Turas Handles Segmentation

The Turas segment module is a configuration-driven pipeline. You provide a data file and an Excel config file; the module handles data preparation, clustering, validation, profiling, and reporting. The workflow is designed around two modes:

- **Exploration mode** -- Tests multiple numbers of segments (k values) and recommends the best one. Use this first.
- **Final mode** -- Runs the analysis with your chosen k and produces full results including segment assignments, profiles, action cards, and an HTML report.

All output is generated as Excel files (for your workbench) and optionally as a self-contained HTML report (for stakeholder delivery).

------------------------------------------------------------------------

## 2. Quick Start

This section gets you from zero to a working segmentation in the shortest path possible.

### What You Need

1. **A data file** -- CSV, Excel (.xlsx), or SPSS (.sav) format. One row per respondent, one column per variable. Must include a unique respondent ID column and numeric columns for clustering.
2. **A config file** -- An Excel file with a sheet named "Config" containing two columns: `Setting` and `Value`.

### Minimal Config

Create an Excel file (e.g., `my_config.xlsx`) with a sheet named **Config**. Only three settings are required:

```
Setting          | Value
-----------------|----------------------------
data_file        | data/survey_data.csv
id_variable      | respondent_id
clustering_vars  | Q01,Q02,Q03,Q04,Q05
```

Everything else has sensible defaults.

### Run It

**Option A: Through the Turas GUI**

```r
source("launch_turas.R")
launch_turas()
```

Select the Segment module, browse to your config file, validate, and run.

**Option B: From the R console**

```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("my_config.xlsx")
```

**Option C: Command line**

```bash
Rscript modules/segment/run_segment.R my_config.xlsx
```

### What Happens

Because `k_fixed` was left blank, the module runs in **exploration mode**. It tests k = 3 through k = 6 (the defaults) and produces:

- An Excel report with metrics for each k value
- An HTML report (if `html_report = TRUE`) with elbow plots and silhouette charts
- A recommendation for the best k

You then review the output, choose your k, add `k_fixed = 4` (or whatever you chose) to the config, and re-run. The second run produces the final segmentation.

### Quick Run (No Config File)

For rapid prototyping without creating a config file:

```r
source("modules/segment/R/10_utilities.R")

result <- run_segment_quick(
  data = my_data,
  id_var = "respondent_id",
  clustering_vars = c("Q01", "Q02", "Q03", "Q04", "Q05"),
  k = NULL,       # NULL = exploration mode
  k_range = 3:6
)
```

------------------------------------------------------------------------

## 3. The Segmentation Workflow

Segmentation is a multi-step process. You use **Excel as your workbench** (reviewing metrics, refining variables, editing segment names) and the **HTML report as the deliverable** (the polished output for stakeholders).

```
STEP 1: PREPARE DATA      -->  Clean data, choose variables
STEP 2: CREATE CONFIG      -->  Excel config file, exploration mode first
STEP 3: RUN EXPLORATION    -->  Test multiple k values
STEP 4: REVIEW RESULTS     -->  Pick k, remove weak variables
STEP 5: RUN FINAL          -->  Lock in k, generate full output
STEP 6: NAME SEGMENTS      -->  Review and edit auto-generated names
STEP 7: SCORE NEW DATA     -->  Apply model to new respondents (optional)
```

### Step 1: Prepare Your Data

Your data file should be structured as one row per respondent with one column per variable.

**Data quality checklist:**

- [ ] Unique respondent ID column (no duplicates)
- [ ] All clustering variables are numeric
- [ ] Missing data under 15% per variable (configurable)
- [ ] Variables use consistent measurement scales where possible
- [ ] No constant variables (where every respondent gave the same answer)
- [ ] At least 100 complete cases after removing missing data
- [ ] No demographic variables in the clustering set (use them for profiling instead)

**Supported file formats:**

| Format | Extension | Notes |
|--------|-----------|-------|
| CSV | `.csv` | Most portable, recommended |
| Excel | `.xlsx` | Specify sheet name with `data_sheet` if not "Data" |
| SPSS | `.sav` | Requires the `haven` package |

**Choosing clustering variables:**

| Include | Exclude |
|---------|---------|
| Satisfaction ratings | Respondent IDs |
| Agreement scales | Timestamps |
| Brand perceptions | Open-ended text |
| Importance ratings | Demographics (use for profiling) |
| Behavioural frequency | Constants (zero variance) |
| Needs-based statements | Highly skewed variables (95%+ same answer) |

**How many variables?**

| Count | Guidance |
|-------|----------|
| 2-4 | Too few -- solution will be over-simplified |
| 5-12 | Ideal range for most surveys |
| 13-15 | Acceptable if variable selection is enabled |
| 16+ | Too many -- enable variable selection or reduce manually |

### Step 2: Create Your Config File (Exploration Mode First)

Copy the template from `modules/segment/docs/templates/Segment_Config_Template.xlsx` or create a new Excel file with a "Config" sheet.

For your first run, leave `k_fixed` blank to trigger exploration mode. Set the range of k values you want to test:

```
Setting          | Value
-----------------|--------------------------------
data_file        | data/survey_data.csv
id_variable      | respondent_id
clustering_vars  | Q01,Q02,Q03,Q04,Q05,Q06,Q07
k_fixed          |
k_min            | 3
k_max            | 6
method           | kmeans
html_report      | TRUE
output_folder    | output/
```

You can also generate a config template programmatically:

```r
source("modules/segment/R/10_utilities.R")
generate_config_template(
  data_file = "data/survey.csv",
  output_file = "config/my_segmentation.xlsx",
  mode = "exploration"
)
```

### Step 3: Run Exploration to Find Optimal k

Run the analysis:

```r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("config/my_segmentation.xlsx")
```

The module will:

1. Load and validate your data
2. Handle missing values according to your config
3. Standardise variables (z-scores)
4. Run clustering for every k from `k_min` to `k_max`
5. Calculate validation metrics for each k
6. Generate a recommendation

**Output files:**

| File | Content |
|------|---------|
| `seg_k_selection_report.xlsx` | Metrics comparison, profiles per k, variable contribution |
| `seg_k_selection_report.html` | Interactive charts (elbow, silhouette) |

### Step 4: Review Exploration Results and Choose k

Open `seg_k_selection_report.xlsx` in Excel.

1. **Metrics_Comparison sheet** -- Compare silhouette scores and BSS/TSS across k values. The module highlights its recommended k, but use your judgement.

2. **Variable_Contribution sheet** -- Each clustering variable is rated by eta-squared:

   | Category | Eta-Squared | Meaning |
   |----------|-------------|---------|
   | ESSENTIAL | > 0.30 | Strongly separates segments |
   | USEFUL | 0.10 - 0.30 | Contributes meaningfully |
   | MINIMAL IMPACT | < 0.10 | Not helping -- consider removing |

3. **Profile sheets** -- Review segment means at each k. Do the segments tell a coherent story?

4. **Refine if needed** -- Remove weak variables, adjust k range, try a different method, then re-run exploration.

See Section 4 for a detailed guide to choosing k.

### Step 5: Run Final Segmentation with Chosen k

Update your config to set `k_fixed` and enable the features you want:

```
Setting                | Value
-----------------------|------------------------------------------
k_fixed                | 4
auto_name_style        | descriptive
generate_action_cards  | TRUE
generate_rules         | TRUE
run_stability_check    | TRUE
golden_questions_n     | 5
demographic_vars       | age_group,gender,region
html_report            | TRUE
save_model             | TRUE
```

Run it the same way as the exploration.

**Output files:**

| File | Content |
|------|---------|
| `seg_segment_assignments.xlsx` | ID + segment_id + segment_name per respondent |
| `seg_segmentation_report.xlsx` | Profiles, validation, statistics |
| `seg_segmentation_report.html` | Complete HTML report for stakeholders |
| `seg_model.rds` | Saved model for scoring new data |

### Step 6: Review and Name Your Segments

The segment assignments file includes a **Segment_Names** sheet:

```
Segment_ID | Suggested_Name                | Custom_Name
-----------|-------------------------------|-----------------
1          | Health-Focused Traditionalists |
2          | Price-Sensitive Pragmatists    |
3          | Brand-Loyal Enthusiasts        |
4          | Disengaged Minimalists         |
```

**To use your own names:**

1. Fill in the `Custom_Name` column with your preferred names.
2. Save the Excel file (do not rename or move it).
3. Add `segment_names_file = output/seg_segment_assignments.xlsx` to your config.
4. Set `html_report = TRUE` and re-run.

The module reads your edited names and uses them throughout the HTML report.

**Auto-naming styles:**

| Style | Example | When to use |
|-------|---------|-------------|
| `descriptive` | "Health-Focused Traditionalists" | Default; describes what makes the segment distinctive |
| `persona` | "The Wellness Warrior" | More evocative; good for stakeholder presentations |
| `simple` | "Segment A" | Neutral labels; use when you will rename manually |

### Step 7: Score New Respondents (Optional)

After building a segmentation, you can assign new respondents to the existing segments without re-running the full analysis.

**Requirements:**

- The original model was saved (`save_model = TRUE`)
- The new data contains the same clustering variables as the original

**Batch scoring:**

```r
source("modules/segment/R/08_scoring.R")

scores <- score_new_data(
  model_file  = "output/seg_model.rds",
  new_data    = new_survey_data,
  id_variable = "respondent_id",
  output_file = "output/new_respondent_scores.xlsx"
)
```

Each respondent receives:
- `segment` -- Assigned segment number
- `segment_name` -- Segment label
- `distance_to_center` -- Distance from cluster centroid
- `assignment_confidence` -- Confidence score (0-1)

**Single respondent typing:**

```r
result <- type_respondent(
  answers = c(Q01 = 8, Q02 = 7, Q03 = 9, Q04 = 8, Q05 = 9),
  model_file = "output/seg_model.rds"
)
cat("Assigned to:", result$segment_name, "\n")
cat("Confidence:", scales::percent(result$confidence), "\n")
```

**Monitoring segment drift:**

Over time, the distribution of new respondents across segments may shift. Compare distributions to detect drift:

```r
drift <- compare_segment_distributions(
  model_file     = "output/seg_model.rds",
  scoring_result = scores
)
```

If any segment changes by more than 10 percentage points, consider re-running the full segmentation on the combined data.

------------------------------------------------------------------------

## 4. Choosing the Optimal Number of Segments

Choosing the number of segments (k) is the most consequential decision in any segmentation study. It is part science and part art. The module provides the statistical evidence; you supply the business judgement.

### The Exploration Report

Run exploration mode (leave `k_fixed` blank) to test a range of k values. The output includes several complementary metrics, each measuring a different aspect of cluster quality.

### Metric 1: The Elbow Method (Within-Cluster Sum of Squares)

**What it measures:** The total within-cluster sum of squares (WCSS) quantifies how tightly respondents cluster around their assigned segment centres. Lower WCSS means tighter, more homogeneous segments.

**How to read the chart:** The elbow plot shows WCSS on the y-axis and k on the x-axis. As k increases, WCSS always decreases (more segments always produce tighter clusters). Look for the point where the curve bends -- the "elbow" -- where adding more segments yields diminishing improvement.

**Interpretation:**

- WCSS drops sharply from k=2 to k=4, then flattens from k=4 onwards: the elbow is at k=4.
- If the curve decreases smoothly without a clear bend, the data may not have well-defined clusters. Consider the other metrics.

**Limitations:** The elbow is often ambiguous. It is best used as a starting point, not as a definitive answer.

### Metric 2: Silhouette Analysis

**What it measures:** The silhouette score for each respondent quantifies how similar that respondent is to others in their own segment compared to the nearest neighbouring segment. It ranges from -1 to +1. The average silhouette width across all respondents is the single best summary measure of cluster quality.

**Thresholds** (Kaufman & Rousseeuw, 1990):

| Average Silhouette | Interpretation |
|--------------------|----------------|
| 0.71 - 1.00 | Strong structure found |
| 0.51 - 0.70 | Reasonable structure found |
| 0.26 - 0.50 | Structure is weak and could be artificial |
| < 0.26 | No substantial structure found |

**How to use it:** Choose the k with the highest average silhouette width. If multiple k values produce similar silhouettes, prefer the smaller k (simpler model).

**Per-segment silhouettes:** The HTML report shows silhouette values broken down by segment. If one segment has many respondents with negative silhouette values, those respondents may be better assigned to a neighbouring segment. This often indicates that two segments should be merged.

### Metric 3: Gap Statistic

**What it measures:** The gap statistic (Tibshirani, Walther, & Hastie, 2001) compares the observed WCSS to the expected WCSS under a reference distribution with no cluster structure. The optimal k is the smallest value where the gap statistic reaches its maximum, meaning the clustering explains substantially more variance than random data would.

**Interpretation:** Choose the smallest k where the gap statistic is within one standard error of its maximum value. This is a formally principled approach but can be computationally expensive for large datasets.

### Metric 4: Calinski-Harabasz Index

**What it measures:** The ratio of between-cluster variance to within-cluster variance, adjusted for the number of clusters and sample size. Higher values indicate better-defined clusters.

**How to use it:** Choose the k with the highest Calinski-Harabasz index. There is no absolute threshold -- the index is most useful for comparing different k values on the same data.

**Typical range:** 10 to 1000+. The absolute value depends on the data, but higher is always better.

### Metric 5: Davies-Bouldin Index

**What it measures:** The average "similarity" between each cluster and its most similar neighbour, where similarity is defined as the ratio of within-cluster spread to between-cluster separation. Lower values indicate better-separated clusters.

**Threshold:** Below 1.0 is generally considered good.

### Practical Considerations

Statistics alone do not choose k. After reviewing the metrics, apply these practical tests:

1. **Can you describe each segment?** If you cannot give a meaningful, distinct name to every segment, you may have too many.

2. **Can you act on each segment differently?** If two segments would receive the same marketing treatment, they should be merged.

3. **Will stakeholders remember them?** Four segments named "Advocates, Engaged, Passive, Detractors" is manageable. Eight is not.

4. **Are all segments large enough?** A segment with fewer than 30 respondents (or less than 5% of the sample) is too small to produce reliable profiles. Set `min_segment_size_pct` to at least 10%.

5. **Is the solution stable?** Enable `run_stability_check = TRUE` and look for scores above 80%. Unstable solutions change with different random seeds, which means the segments are not robust.

### Decision Framework

Use this flowchart when the metrics do not clearly point to a single k:

```
1. What does silhouette recommend?           --> k_sil
2. What does the elbow suggest?              --> k_elbow
3. Are all segments above minimum size?       --> Filter out k values with tiny segments

IF k_sil == k_elbow:
   Use that k.

IF k_sil != k_elbow AND they differ by 1:
   Run both as final solutions.
   Compare the profiles.
   Choose the one that tells a more coherent story.

IF metrics disagree by more than 1:
   Run both extremes as final solutions.
   If the larger k splits a segment from the smaller k into two
   clearly distinct groups, the larger k is justified.
   If the split produces two similar segments, use the smaller k.

IN ALL CASES:
   Verify stability (>80%).
   Verify minimum segment size (>10%).
   Verify business interpretability.
```

### Rules of Thumb

| Situation | Recommended k |
|-----------|---------------|
| Most consumer surveys (n = 200-1000) | 3-5 |
| Large-scale tracking studies | 4-6 |
| B2B with small sample (n < 200) | 2-4 |
| Complex needs-based segmentation | 4-6 |
| Maximum practical limit | 8 |

Never go above 8 segments unless you have a very specific reason and a very large sample. Beyond 8, you are almost certainly overfitting.

------------------------------------------------------------------------

## 5. Dealing with Partial Answers (Missing Data)

Missing data is common in surveys. How you handle it affects both the sample you analyse and the quality of your segments.

### Understanding Why Data Is Missing

The appropriate strategy depends on why respondents left questions blank. Statisticians distinguish three mechanisms:

**MCAR -- Missing Completely At Random**

The probability of a value being missing is unrelated to both the missing value itself and all other observed values. Example: a respondent's browser crashed mid-survey. The missingness is pure chance.

**Test:** If respondents with missing data look the same as those without (similar demographics, similar response patterns on completed questions), the data is likely MCAR.

**MAR -- Missing At Random**

The probability of a value being missing depends on other observed variables but not on the missing value itself. Example: younger respondents are more likely to skip a question about retirement planning, but among younger respondents, the skipping is unrelated to their actual retirement plans.

**Test:** If you can predict which respondents have missing data from their other answers, the data is MAR.

**MNAR -- Missing Not At Random**

The probability of a value being missing depends on the value itself. Example: dissatisfied customers are more likely to skip a satisfaction question. The missing values are systematically different from the observed values.

**Test:** This is the hardest to detect because the evidence is in the unobserved data. Domain knowledge is your best guide. If a question about a sensitive topic has unusually high non-response, suspect MNAR.

### Available Strategies

The module supports four missing data strategies, configured via the `missing_data` parameter:

| Strategy | Config Value | When to Use |
|----------|-------------|-------------|
| Listwise deletion | `listwise_deletion` | Data is MCAR; missing rate is low (<10%) |
| Mean imputation | `mean_imputation` | Data is MAR; moderate missing rate (5-15%) |
| Median imputation | `median_imputation` | Data is MAR; variables are skewed |
| Refuse | `refuse` | Missing rate exceeds threshold; forces you to clean data first |

### Decision Flowchart

```
START: How much data is missing?

IF missing rate < 5%:
   --> Listwise deletion is safe regardless of mechanism.
       You lose few cases and the impact is minimal.

IF missing rate 5-15%:
   --> Is the data MCAR?
       YES --> Listwise deletion is unbiased but reduces sample size.
              Imputation preserves sample size.
              Either is acceptable; try both and compare.
       NO  --> Is the data MAR?
              YES --> Use mean or median imputation.
                     Mean for symmetric distributions.
                     Median for skewed distributions.
              NO  --> Data may be MNAR.
                     Imputation may introduce bias.
                     Consider removing the variable.
                     Consult a statistician if possible.

IF missing rate > 15%:
   --> Consider removing the variable from clustering_vars.
       A variable with 30%+ missing is unreliable for clustering.
       If you must keep it, use imputation and document the decision.
```

### Impact on Results

| Strategy | Effect on Sample Size | Effect on Segment Structure |
|----------|----------------------|----------------------------|
| Listwise deletion | Reduces sample (potentially substantially) | Unbiased if MCAR; may bias if MAR/MNAR |
| Mean imputation | Preserves full sample | Shrinks variable variance; may pull segments toward centre |
| Median imputation | Preserves full sample | More robust to skew than mean; same variance concern |
| Refuse | Analysis stops | Forces you to address the root cause |

### Recommendation

**Try both deletion and imputation, then compare.** If the segment structure is similar under both approaches, the missing data is not materially affecting your results. If the segments change substantially, investigate which variables have the most missing data and consider removing them.

### Configuring the Threshold

The `missing_threshold` parameter (default: 15) sets the maximum percentage of missing data allowed per variable before the module raises a warning or refuses to proceed:

```
missing_data       | mean_imputation
missing_threshold  | 15
```

If any variable exceeds this threshold and `missing_data = refuse`, the analysis will stop with a clear error message explaining which variables are problematic and how to fix the issue.

------------------------------------------------------------------------

## 6. Choosing the Right Model

The module supports four clustering algorithms. In most cases, K-means is the right choice. Use this section when you are unsure.

### Comparison Table

| Factor | K-means | Hierarchical | GMM | LCA |
|--------|---------|-------------|-----|-----|
| **Best for** | Most surveys | Exploring nested structure | Overlapping segments | Categorical data |
| **Data type** | Continuous (scales, ratings) | Continuous | Continuous | Categorical / ordinal |
| **Speed** | Fast | Moderate | Slower | Moderate |
| **Sample size** | Up to 50,000+ (mini-batch) | Up to ~15,000 | Up to ~10,000 | Up to ~5,000 |
| **Cluster shape** | Spherical (equal-sized) | Varies by linkage | Elliptical (flexible) | N/A (model-based) |
| **Assignment** | Hard (each respondent in exactly one segment) | Hard | Soft (probability per segment) | Soft (probability per class) |
| **Model selection** | Silhouette, elbow | Dendrogram | BIC/AIC | BIC/AIC |
| **Reproducibility** | Depends on nstart/seed | Deterministic | Depends on initialisation | Depends on initialisation |
| **Key advantage** | Simple, fast, widely understood | Reveals hierarchical structure | Captures overlapping groups | Handles non-numeric data |
| **Key limitation** | Assumes spherical clusters | Memory-intensive distance matrix | Slower; can overfit with many parameters | Requires categorical inputs |

### K-means (Default)

**When to use:** Your data consists of numeric ratings or scales (1-5, 1-7, 1-10). You want the fastest run time. You expect roughly compact, well-separated segments. This covers the vast majority of market research segmentation projects.

**How it works:** K-means randomly initialises k cluster centres, assigns each respondent to the nearest centre, then iteratively adjusts the centres to minimise within-cluster variance. The `nstart` parameter controls how many random initialisations are tried; higher values (25-50) produce more stable results.

**Large datasets:** For datasets with more than 10,000 respondents, the module automatically switches to mini-batch K-means, which processes random subsamples at each iteration for dramatically improved performance with minimal quality loss.

**Config example:**

```
method  | kmeans
nstart  | 50
```

### Hierarchical Clustering

**When to use:** You want to explore the nested structure of your data before choosing k. A dendrogram visualisation is important for your audience. You want a deterministic result (same data always gives the same answer). Your sample is under 15,000 respondents.

**How it works:** Hierarchical clustering builds a tree (dendrogram) by iteratively merging the most similar pairs of clusters, starting from individual respondents. You then "cut" the tree at the desired height to produce k segments.

**Linkage methods:**

| Method | Behaviour | Recommendation |
|--------|-----------|----------------|
| `ward.D2` | Produces compact, balanced clusters | Best default for survey data |
| `complete` | Creates well-separated clusters | Can produce unequal sizes |
| `average` | Middle ground | Useful when cluster sizes vary substantially |

**Config example:**

```
method          | hclust
linkage_method  | ward.D2
```

### Gaussian Mixture Models (GMM)

**When to use:** You believe segments genuinely overlap (respondents sit between groups). You need probability-based membership (e.g., "this respondent is 70% Segment A, 30% Segment B"). Your clusters may be elliptical rather than spherical.

**How it works:** GMM assumes the data is generated by a mixture of Gaussian distributions, each representing a segment. It estimates the parameters (mean, covariance) of each distribution and assigns each respondent a probability of belonging to each segment.

**Additional outputs:** GMM produces probability columns in the assignments file: `prob_segment_1`, `prob_segment_2`, etc., plus a `max_probability` and `uncertainty` column.

**Requires:** The `mclust` R package.

**Config example:**

```
method          | gmm
gmm_model_type  |
```

Leave `gmm_model_type` blank to let the algorithm automatically select the best covariance structure via BIC. If you know what you want, valid values include `VVV` (most flexible), `EEE` (all clusters same shape), and others from the mclust documentation.

### Latent Class Analysis (LCA)

**When to use:** Your clustering variables are purely categorical (yes/no, multiple choice, coded open-ends). Standard K-means on categorical data produces poor results because Euclidean distance is not meaningful for category labels.

**How it works:** LCA assumes respondents belong to one of k unobserved ("latent") classes, each characterised by a distinct pattern of response probabilities. It estimates these probabilities using maximum likelihood and assigns each respondent to their most probable class.

**Requires:** The `poLCA` R package.

**Config example:**

```
use_lca  | TRUE
```

**Note:** LCA is not set via the `method` parameter. It is enabled separately because it requires a fundamentally different data format (categorical rather than continuous).

### Multi-Method Comparison

Not sure which method is best? Run them all side-by-side:

```
method  | kmeans,hclust,gmm
```

Or use:

```
method  | all
```

This runs each algorithm independently on the same prepared data and produces:
- Per-method assignment files
- Per-method model files
- A combined HTML report with tabs for each method plus a comparison tab showing side-by-side metrics and a recommendation

### When to Use Each -- Quick Decision Guide

```
Q: Is your data numeric (ratings, scales)?
   YES --> Q: Is your sample under 15,000?
            YES --> K-means (default) or Hierarchical
            NO  --> K-means (auto mini-batch)
   NO  --> Q: Is your data categorical?
            YES --> LCA
            NO  --> Convert to numeric or categorical first

Q: Do you need soft (probabilistic) assignments?
   YES --> GMM or LCA
   NO  --> K-means or Hierarchical

Q: Do you need a deterministic result (no randomness)?
   YES --> Hierarchical
   NO  --> Any method (use seed for reproducibility)
```

------------------------------------------------------------------------

## 7. Configuration Reference

All parameters available in the Config sheet, organised by category. Parameters are listed with their default values -- only set the ones you want to change.

### Core Settings (Required)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `data_file` | text | *(none)* | Path to survey data file (.csv, .xlsx, .xls, .sav) |
| `id_variable` | text | *(none)* | Column name for respondent ID (must be unique) |
| `clustering_vars` | text | *(none)* | Comma-separated list of variables to cluster on |

### Core Settings (Optional)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `data_sheet` | text | `Data` | Sheet name when reading Excel data files |
| `profile_vars` | text | *(all numeric)* | Comma-separated profiling variables (not used for clustering). If blank, all numeric non-clustering variables are used |

### Mode and K Settings

| Parameter | Type | Default | Allowed | Description |
|-----------|------|---------|---------|-------------|
| `k_fixed` | integer | *(blank)* | 2+ | Fixed k for final mode. Leave blank for exploration |
| `k_min` | integer | `3` | 2-10 | Minimum k to test in exploration mode |
| `k_max` | integer | `6` | 2-15 | Maximum k to test in exploration mode |
| `seed` | integer | `123` | 1+ | Random seed for reproducibility |

**Mode detection:** If `k_fixed` is blank or absent, the module runs in exploration mode. If `k_fixed` is set, it runs in final mode.

### Clustering Algorithm

| Parameter | Type | Default | Allowed | Description |
|-----------|------|---------|---------|-------------|
| `method` | text | `kmeans` | `kmeans`, `hclust`, `gmm`, comma-separated list, or `all` | Clustering algorithm(s) |
| `nstart` | integer | `50` | 1-200 | Random starts for K-means. Higher = more stable |
| `linkage_method` | text | `ward.D2` | `ward.D`, `ward.D2`, `single`, `complete`, `average`, `mcquitty`, `median`, `centroid` | Linkage for hierarchical clustering |
| `gmm_model_type` | text | *(auto)* | mclust model names (e.g., `VVV`, `EEE`) | GMM covariance structure. Blank = auto-select by BIC |
| `use_lca` | logical | `FALSE` | `TRUE`, `FALSE` | Enable Latent Class Analysis (requires `poLCA`) |

### Data Handling

| Parameter | Type | Default | Allowed | Description |
|-----------|------|---------|---------|-------------|
| `missing_data` | text | `listwise_deletion` | `listwise_deletion`, `mean_imputation`, `median_imputation`, `refuse` | How to handle missing values in clustering variables |
| `missing_threshold` | numeric | `15` | 0-100 | Maximum % missing allowed per variable |
| `standardize` | logical | `TRUE` | `TRUE`, `FALSE` | Standardise variables to z-scores before clustering |
| `min_segment_size_pct` | numeric | `10` | 0-50 | Minimum % of sample per segment. Warns if any segment is below this |
| `scale_max` | numeric | `10` | 1-100 | Maximum value on rating scale. Used by auto-naming and action cards |

### Outlier Detection

| Parameter | Type | Default | Allowed | Description |
|-----------|------|---------|---------|-------------|
| `outlier_detection` | logical | `FALSE` | `TRUE`, `FALSE` | Enable outlier detection |
| `outlier_method` | text | `zscore` | `zscore`, `mahalanobis` | Detection algorithm |
| `outlier_threshold` | numeric | `3.0` | 1.0-5.0 | Z-score threshold for flagging outliers |
| `outlier_min_vars` | integer | `1` | 1+ | Minimum variables a respondent must be outlier on to be flagged |
| `outlier_handling` | text | `flag` | `none`, `flag`, `remove` | What to do with detected outliers |
| `outlier_alpha` | numeric | `0.001` | 0.0001-0.1 | Significance level for Mahalanobis method |

### Variable Selection

| Parameter | Type | Default | Allowed | Description |
|-----------|------|---------|---------|-------------|
| `variable_selection` | logical | `FALSE` | `TRUE`, `FALSE` | Enable automatic variable reduction |
| `variable_selection_method` | text | `variance_correlation` | `variance_correlation`, `factor_analysis`, `both` | Selection algorithm |
| `max_clustering_vars` | integer | `10` | 2-20 | Target number of variables to keep |
| `varsel_min_variance` | numeric | `0.1` | 0.01-1.0 | Minimum variance threshold |
| `varsel_max_correlation` | numeric | `0.8` | 0.5-0.95 | Maximum allowed pairwise correlation |

### K Selection Metrics

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `k_selection_metrics` | text | `silhouette,elbow` | Comma-separated list of metrics to calculate |

### Output Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `output_folder` | text | `output/` | Directory for output files |
| `output_prefix` | text | `seg_` | Filename prefix for all output files |
| `create_dated_folder` | logical | `TRUE` | Create timestamped subfolder for each run |
| `save_model` | logical | `TRUE` | Save model object (.rds) for scoring new data |
| `segment_names` | text | `auto` | Custom names (comma-separated) or `auto` for auto-generation |
| `auto_name_style` | text | `descriptive` | Auto-naming style: `descriptive`, `persona`, `simple` |
| `question_labels_file` | text | *(blank)* | Path to Excel file with variable labels (two columns: variable, label) |
| `segment_names_file` | text | *(blank)* | Path to Excel with edited segment names (Step 3 workflow) |

### Enhanced Features

| Parameter | Type | Default | Allowed | Description |
|-----------|------|---------|---------|-------------|
| `generate_rules` | logical | `FALSE` | `TRUE`, `FALSE` | Generate IF-THEN classification rules (requires `rpart`) |
| `rules_max_depth` | integer | `3` | 1-5 | Decision tree depth for rules |
| `generate_action_cards` | logical | `FALSE` | `TRUE`, `FALSE` | Generate executive-ready segment action cards |
| `run_stability_check` | logical | `FALSE` | `TRUE`, `FALSE` | Run stability assessment across multiple seeds |
| `stability_n_runs` | integer | `5` | 3-20 | Number of runs for stability check |
| `golden_questions_n` | integer | `3` | 1-10 | Number of top discriminating variables to identify |
| `demographic_vars` | text | *(blank)* | | Comma-separated demographic variables for profiling |

### HTML Report

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `html_report` | logical | `FALSE` | Generate interactive HTML report |
| `brand_colour` | text | `#323367` | Primary colour for headers, nav, charts (hex) |
| `accent_colour` | text | `#CC9900` | Accent colour for highlights and markers (hex) |
| `report_title` | text | *(auto)* | Title displayed in report header |

### HTML Report Section Visibility

Each section of the HTML report can be shown or hidden independently:

| Parameter | Default | Section |
|-----------|---------|---------|
| `html_show_exec_summary` | `TRUE` | Executive summary narrative |
| `html_show_overview` | `TRUE` | Segment sizes chart and table |
| `html_show_validation` | `TRUE` | Silhouette chart and validation metrics |
| `html_show_importance` | `TRUE` | Variable importance (eta-squared) chart |
| `html_show_profiles` | `TRUE` | Profile heatmap and table |
| `html_show_demographics` | `TRUE` | Demographic breakdown by segment |
| `html_show_rules` | `TRUE` | Classification rules table |
| `html_show_cards` | `TRUE` | Segment action cards |
| `html_show_stability` | `TRUE` | Stability assessment |
| `html_show_membership` | `TRUE` | GMM membership probabilities |
| `html_show_guide` | `TRUE` | Interpretation guide |

### Metadata

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `project_name` | text | `Segmentation Analysis` | Project name for reports |
| `analyst_name` | text | `Analyst` | Analyst name for reports |
| `description` | text | *(blank)* | Free-text analysis description |

### Complete Config Examples

**Exploration config:**

```
Setting                | Value
-----------------------|------------------------------------------
data_file              | data/customer_survey_2026.csv
id_variable            | ResponseID
clustering_vars        | Q02,Q03,Q04,Q05,Q06,Q07,Q08
k_fixed                |
k_min                  | 3
k_max                  | 6
method                 | kmeans
nstart                 | 50
seed                   | 42
missing_data           | listwise_deletion
standardize            | TRUE
outlier_detection      | TRUE
outlier_method         | zscore
outlier_threshold      | 3.0
outlier_handling       | flag
output_folder          | output/
output_prefix          | seg_
html_report            | TRUE
brand_colour           | #323367
report_title           | Customer Segmentation Exploration
project_name           | Q1 2026 Customer Segmentation
```

**Final config:**

```
Setting                  | Value
-------------------------|------------------------------------------
data_file                | data/customer_survey_2026.csv
id_variable              | ResponseID
clustering_vars          | Q02,Q03,Q04,Q05,Q06,Q07,Q08
k_fixed                  | 4
method                   | kmeans
nstart                   | 50
seed                     | 42
missing_data             | listwise_deletion
standardize              | TRUE
min_segment_size_pct     | 10
segment_names            | Advocates,Engaged,Passive,Detractors
save_model               | TRUE
generate_rules           | TRUE
rules_max_depth          | 3
generate_action_cards    | TRUE
run_stability_check      | TRUE
stability_n_runs         | 10
golden_questions_n       | 5
demographic_vars         | age_group,gender,region,income_band
output_folder            | output/
output_prefix            | seg_
html_report              | TRUE
brand_colour             | #1A5276
accent_colour            | #E67E22
report_title             | Customer Segmentation Final
html_show_exec_summary   | TRUE
html_show_overview       | TRUE
html_show_validation     | TRUE
html_show_importance     | TRUE
html_show_profiles       | TRUE
html_show_demographics   | TRUE
html_show_rules          | TRUE
html_show_cards          | TRUE
html_show_guide          | TRUE
project_name             | Q1 2026 Customer Segmentation
analyst_name             | Research Team
```

**Multi-method comparison config:**

```
Setting                  | Value
-------------------------|------------------------------------------
data_file                | data/customer_survey_2026.csv
id_variable              | ResponseID
clustering_vars          | Q02,Q03,Q04,Q05,Q06,Q07,Q08
k_fixed                  | 4
method                   | kmeans,hclust,gmm
linkage_method           | ward.D2
seed                     | 42
save_model               | TRUE
generate_action_cards    | TRUE
output_folder            | output/comparison/
output_prefix            | seg_
html_report              | TRUE
report_title             | Method Comparison
project_name             | Multi-Method Comparison
```

------------------------------------------------------------------------

## 8. Interpreting Results

### Reading the HTML Report

The HTML report is a self-contained file you can email, share, or present. Each section provides a different lens on the segmentation.

**Executive Summary** -- A plain-English overview generated automatically. It tells you how many segments were found, the overall quality of the solution, which segment is largest, which variables differentiate best, and any warnings. Read this first to get the big picture.

Quality assessment thresholds:

| Rating | Silhouette Score | Meaning |
|--------|------------------|---------|
| Excellent | > 0.50 | Strong, well-separated segments |
| Good | 0.35 - 0.50 | Meaningful segments with some overlap |
| Moderate | 0.25 - 0.35 | Segments exist but boundaries are fuzzy |
| Limited | < 0.25 | Weak structure -- consider a different approach |

**Segment Overview** -- A bar chart and table showing how many respondents are in each segment and their percentage of the total. Look for reasonably balanced sizes. If one segment has 60% and another has 5%, the solution may be picking up on a dominant pattern rather than useful sub-groups.

**Validation Metrics** -- A silhouette chart showing how well each respondent fits their assigned segment. Respondents with negative silhouette values are closer to a neighbouring segment than to their own. A few are normal; many indicate a problem.

Additional metrics:
- **BSS/TSS:** Proportion of variance explained by the segments. Higher is better. Above 0.40 is typical for survey data.
- **Calinski-Harabasz index:** Higher is better. No absolute threshold; useful for comparing solutions.
- **Davies-Bouldin index:** Lower is better. Below 1.0 is generally good.

### Understanding Segment Profiles

The profile heatmap and table show the mean score for each variable in each segment, alongside the overall mean.

**Reading the heatmap:** Darker cells indicate higher scores. Look for the pattern -- which segments score high on which variables? Variables are sorted by importance (eta-squared), so the most differentiating variables appear at the top.

**Index scores:** Some outputs show index scores (segment mean / overall mean * 100). An index of 120 means that segment scores 20% above average. An index of 80 means 20% below average. Indices above 110 and below 90 are generally noteworthy.

### Variable Importance (Eta-Squared)

The variable importance chart shows how much each variable contributes to distinguishing the segments.

| Eta-squared | Interpretation |
|-------------|----------------|
| > 0.14 | Large effect -- strong differentiator |
| 0.06 - 0.14 | Medium effect -- meaningful differentiator |
| 0.01 - 0.06 | Small effect -- weak differentiator |
| < 0.01 | Negligible -- not useful for this segmentation |

**Important note:** Because segments are *defined* by these variables, p-values in the statistical tests are descriptive, not inferential. Focus on effect sizes (eta-squared), not p-values.

### Using Golden Questions for Prediction

Golden questions are the 3-5 variables (configurable via `golden_questions_n`) that best discriminate between segments. They are identified using Random Forest variable importance, which captures non-linear relationships that eta-squared may miss.

These are your "typing" questions. If you could only ask a few questions to assign a new respondent to a segment, these would be the ones. They are useful for:
- Shortening a screening questionnaire
- Building a typing tool for ongoing classification
- Understanding which variables really drive the segmentation

### Interpreting Vulnerability / Switching Analysis

Every final run includes a vulnerability analysis that identifies respondents whose segment assignment is borderline.

**What it measures:**
- **Assignment confidence** (0 to 1): How firmly each respondent belongs to their segment. For K-means and hierarchical, this is based on distance ratios. For GMM, it uses probability margins.
- **Vulnerable flag:** Respondents with confidence below 0.3 (the default threshold).
- **Would switch to:** The segment each borderline respondent would join if reassigned.
- **Switching matrix:** Counts of potential switches between segment pairs, showing which segments have the most overlap.

**Interpreting the vulnerability rate:**

| % Vulnerable | Interpretation |
|--------------|----------------|
| < 15% | Strong segmentation with clear boundaries |
| 15-30% | Moderate overlap between some segments |
| > 30% | Significant overlap -- consider fewer segments or different variables |

**Note on GMM:** GMM naturally produces lower vulnerability rates because its probability-based assignments provide sharper confidence scores. Do not compare vulnerability rates across methods.

### Using Action Cards

Action cards provide executive-ready summaries for each segment:
- **Segment name and size**
- **Defining characteristics** -- what makes this segment unique
- **Strengths** -- highest-scoring variables relative to the overall mean
- **Pain points** -- lowest-scoring variables relative to the overall mean
- **Recommended actions** -- auto-generated suggestions based on the profile

These are designed to be shared directly with stakeholders who need to act on the segments without reading the full technical report.

### Classification Rules

When enabled (`generate_rules = TRUE`), the module uses a decision tree to produce plain-English IF-THEN rules for segment membership. For example:

> IF Product Quality >= 7.5 AND Service Rating >= 6.0 THEN Segment = Advocates (accuracy: 82%)

These rules simplify the complex multivariate clustering into a few decision points. They are approximate (the decision tree will not perfectly replicate the clustering) but give stakeholders an intuitive understanding of what defines each segment.

------------------------------------------------------------------------

## 9. Common Pitfalls

### Too Many Clustering Variables

**Symptom:** Segments are hard to interpret. Silhouette score is low. Solution is unstable across runs.

**Why it happens:** With too many variables, the high-dimensional space becomes sparse (the "curse of dimensionality"). Distances between respondents become less meaningful, and noise variables dilute the signal.

**Fix:** Aim for 5-12 clustering variables. Enable `variable_selection = TRUE` to automatically reduce your variable set, or manually select variables based on theory. Check the Variable_Contribution sheet to identify variables with minimal impact.

**Recommendation:** Start with variables you expect to differentiate your market based on prior knowledge or business hypotheses. Add more only if the initial set does not produce interpretable segments.

### Highly Correlated Inputs

**Symptom:** Two or more variables that measure essentially the same thing dominate the clustering. Segments are defined by this one dimension rather than a balanced set of attributes.

**Why it happens:** K-means treats each variable equally. If you have three satisfaction measures that are all correlated at r=0.9, they act as a triple-weighted single variable, pulling the segmentation toward satisfaction as the primary axis.

**Fix:** Check the correlation matrix in the pre-clustering checks output. Remove one variable from each highly correlated pair, or enable variable selection with `varsel_max_correlation = 0.8`.

### Unstandardised Data

**Symptom:** Variables measured on different scales (1-5, 1-10, 0-100) produce segments dominated by the high-range variable.

**Why it happens:** K-means uses Euclidean distance. A variable on a 0-100 scale will have 10-20 times the range of a 1-5 scale, making it dominate the distance calculation.

**Fix:** Keep `standardize = TRUE` (the default). This converts all variables to z-scores (mean=0, SD=1) before clustering. Only set it to `FALSE` if all your variables are already on the same scale and you have a specific reason not to standardise.

### Small Segments (< 5% of Sample)

**Symptom:** A segment with 15 respondents is described in great detail and treated as a strategic target.

**Why it happens:** The clustering algorithm optimises statistical fit, not business utility. A tiny cluster may be statistically valid but practically useless -- its profiles have wide confidence intervals and it is too small to target.

**Fix:** Set `min_segment_size_pct` to at least 10%. If small segments persist, try fewer clusters. A two-respondent segment is a pair of outliers, not a market segment.

### Overfitting with Too Many Segments

**Symptom:** Every k you test improves the silhouette score slightly. You end up with 7 or 8 segments, but some pairs are nearly indistinguishable in their profiles.

**Why it happens:** More clusters always produce a tighter fit to the data. With enough clusters, each respondent becomes their own segment -- perfect statistical fit, zero business value.

**Fix:** Apply the practical tests from Section 4. Can you name each segment distinctively? Can you act on each one differently? Would a stakeholder remember them? If any answer is "no," you have too many.

### Including Demographics as Clustering Variables

**Symptom:** Segments are defined primarily by age, gender, or region. The segmentation tells you things you already knew.

**Why it happens:** Demographics are strongly discriminating variables. If you include age in the clustering, you will get age-based segments, which you could have created with a simple cross-tab.

**Fix:** Remove all demographic variables from `clustering_vars`. Use them as `profile_vars` or `demographic_vars` instead. Demographics should describe your segments, not define them.

### Not Checking Stability

**Symptom:** Re-running the analysis with a different seed produces different segments.

**Fix:** Enable stability checking (`run_stability_check = TRUE`). Interpretation:

| Stability Score | Interpretation |
|----------------|----------------|
| >= 90% | Excellent -- very stable |
| 80-89% | Good -- reasonably stable |
| 70-79% | Acceptable -- some instability |
| 60-69% | Marginal -- review variables and k |
| < 60% | Poor -- solution is unreliable |

If stability is below 80%, try: reducing the number of variables, reducing k, increasing `nstart` (try 100), or switching to hierarchical clustering (which is deterministic).

### Scale Inconsistency

**Symptom:** Variables measured on different scales produce distorted clusters.

**Fix:** Keep `standardize = TRUE`. If you have a specific reason to use raw values, ensure all variables are on the same scale.

------------------------------------------------------------------------

## 10. R Package Dependencies

### Required Packages

These packages must be installed for the core module to function:

| Package | Minimum Version | Purpose |
|---------|----------------|---------|
| `stats` | *(base R)* | K-means clustering (`kmeans()`), scaling, basic statistics |
| `cluster` | 2.1.0+ | Silhouette analysis (`silhouette()`), cluster validation metrics |
| `readxl` | 1.4.0+ | Reading Excel config and data files |
| `openxlsx` | 4.2.0+ | Writing Excel output files with formatting |
| `htmltools` | 0.5.0+ | HTML report generation |

### Optional Packages

These packages enable additional features and are loaded on demand:

| Package | Purpose | Required When |
|---------|---------|---------------|
| `mclust` | Gaussian Mixture Models (GMM) | `method = gmm` |
| `poLCA` | Latent Class Analysis (LCA) | `use_lca = TRUE` |
| `rpart` | Decision tree classification rules | `generate_rules = TRUE` |
| `randomForest` | Golden questions (variable importance via Random Forest) | Golden questions feature (always attempted in final mode) |
| `fastcluster` | Faster hierarchical clustering for large datasets | `method = hclust` with large n (auto-detected) |
| `MASS` | Mahalanobis distance for outlier detection; discriminant analysis | `outlier_method = mahalanobis` |
| `psych` | Factor analysis for variable selection | `variable_selection_method = factor_analysis` |
| `haven` | Reading SPSS (.sav) data files | When data file is .sav format |
| `writexl` | Alternative Excel writer (used in some scoring exports) | Scoring functions |
| `jsonlite` | JSON output for programmatic access | JSON export features |

### Minimum R Version

**R 4.0 or later** is required. The module uses features introduced in R 4.0 including the pipe-friendly error handling and updated default random number generation.

### Installing Dependencies

Install all required and commonly used optional packages at once:

```r
install.packages(c(
  "cluster", "readxl", "openxlsx", "htmltools",
  "mclust", "rpart", "randomForest", "MASS", "psych", "haven"
))
```

If you are using `renv` for package management:

```r
renv::install(c(
  "cluster", "readxl", "openxlsx", "htmltools",
  "mclust", "rpart", "randomForest", "MASS", "psych", "haven"
))
renv::snapshot()
```

### Checking Dependencies

The module checks for required packages at startup and for optional packages when the relevant feature is invoked. If a package is missing, you will receive a TRS refusal with a clear error message including the install command:

```
[SEGMENT REFUSED] PKG_CLUSTER_MISSING
  Package 'cluster' is not installed.
  Install the package with: install.packages('cluster')
```

------------------------------------------------------------------------

## 11. Troubleshooting

### "Config file not found"

**Error code:** `IO_*`

**Cause:** The `data_file` or config file path is incorrect, or the file has been moved.

**Fix:**
- Check that the file path is correct. Use `file.exists("path/to/file.csv")` in R to verify.
- Paths are relative to the working directory. Use `getwd()` to check where R is looking.
- Ensure the file extension matches the actual format (.csv, .xlsx, .sav).

### "Clustering variable not found in data"

**Error code:** `DATA_*`

**Cause:** A variable name in `clustering_vars` does not match any column in the data file.

**Fix:**
- Variable names are case-sensitive. `Q01` is not the same as `q01`.
- Open your data file and check the exact column headers.
- Watch for trailing spaces in variable names (common when copying from Excel).

### "Non-numeric clustering variables"

**Error code:** `DATA_NON_NUMERIC_VARS`

**Cause:** One or more clustering variables contain text or mixed data types.

**Fix:**
- Check the identified variables in your data file.
- Common causes: a "Don't know" response coded as text instead of NA, or a column that should be numeric but has been read as character due to a formatting issue.
- Clean the data and ensure all clustering columns are numeric.

### "Duplicate ID values"

**Error code:** `DATA_DUPLICATE_IDS`

**Cause:** The ID column contains duplicate values.

**Fix:**
- Check for and remove duplicate rows in your data.
- If duplicates are intentional (e.g., multiple responses per respondent), you need to restructure the data to one row per respondent before segmenting.

### "Insufficient sample size"

**Error code:** `DATA_INSUFFICIENT_SAMPLE`

**Cause:** The sample is too small for the requested number of segments. The module requires at least 50 respondents per segment.

**Fix:**
- Reduce `k_max` or `k_fixed` to a value your sample can support.
- Check if too many respondents are being removed by missing data handling. Try `missing_data = mean_imputation` instead of `listwise_deletion`.
- Check if outlier removal is reducing the sample excessively.

### "Zero variance variables"

**Error code:** `DATA_ZERO_VARIANCE`

**Cause:** One or more clustering variables have the same value for every respondent. These cannot be standardised (division by zero) and contribute nothing to clustering.

**Fix:**
- Remove the identified variable(s) from `clustering_vars`.
- This often happens with filter questions where a screened sample all gave the same qualifying answer.

### "Low silhouette score"

**Not an error, but a quality warning.**

**Cause:** The segments are not well-separated. Respondents do not cluster neatly into distinct groups on the chosen variables.

**Fix:**
- Try fewer segments (lower k).
- Review your clustering variables. Remove variables with low eta-squared (marked "MINIMAL IMPACT" in the exploration report).
- Try a different clustering method (e.g., GMM if you suspect overlapping clusters).
- Consider whether the data genuinely contains distinct segments. Not all markets segment cleanly.

### "K-means did not converge"

**Cause:** The K-means algorithm reached its maximum iterations without finding stable cluster centres.

**Fix:**
- Increase `nstart` to 100 or higher. More random starts increases the chance of finding a good solution.
- Check for extreme outliers that may be pulling centres around. Enable `outlier_detection = TRUE`.
- Try `method = hclust` as an alternative (deterministic, always converges).

### "Package X is not installed"

**Error code:** `PKG_*`

**Cause:** A required or optional package is missing.

**Fix:**
- The error message includes the exact install command. Run it in R.
- If you are using `renv`, use `renv::install("package_name")` followed by `renv::snapshot()`.

### "Excessive missing data"

**Error code:** `DATA_EXCESSIVE_MISSING`

**Cause:** The percentage of missing data exceeds the `missing_threshold`.

**Fix:**
- Identify which variables have the most missing data and consider removing them from `clustering_vars`.
- Increase `missing_threshold` if you are comfortable with more missing data.
- Switch from `refuse` to `mean_imputation` or `median_imputation`.
- If a variable has more than 30% missing, strongly consider dropping it.

### "Error occurred but I cannot see details in Shiny"

**Cause:** Turas runs through a Shiny application, which can suppress error output in the browser.

**Fix:**
- Check the R console where you launched the Shiny app. All errors are written to the console with boxed formatting.
- Look for `=== TURAS ERROR ===` or `[SEGMENT REFUSED]` in the console output.
- The error message includes a code, description, and a "how to fix" instruction.

### "Model file not found" (when scoring)

**Error code:** `IO_MODEL_FILE_MISSING`

**Cause:** The `.rds` model file is missing when attempting to score new data.

**Fix:**
- Ensure the original segmentation was run with `save_model = TRUE`.
- Check the file path. Model files are saved in the output folder with the configured prefix (e.g., `seg_model.rds`).
- If using dated folders (`create_dated_folder = TRUE`), check inside the timestamped subfolder.

### "Missing variables in new data" (when scoring)

**Error code:** `DATA_MISSING_VARIABLES`

**Cause:** The new data for scoring does not contain all the clustering variables from the original model.

**Fix:**
- Ensure the new data file contains exactly the same clustering variable columns as the original.
- Column names must match exactly (case-sensitive).
- If your survey changed between waves, you may need to rebuild the segmentation model.

### Console Output Is Missing or Truncated

**Cause:** R console buffer may be too small, or the Shiny app is capturing output.

**Fix:**
- Increase console buffer size in RStudio: Tools > Global Options > Console > Limit visible console output.
- When running from the command line, redirect output to a file: `Rscript run_segment.R config.xlsx > output.log 2>&1`

------------------------------------------------------------------------

## Output File Reference

### Exploration Mode

| File | Content |
|------|---------|
| `seg_k_selection_report.xlsx` | Metrics comparison, recommendation, profiles per k, variable contribution |
| `seg_k_selection_report.html` | Interactive HTML with elbow and silhouette charts |

### Final Mode

| File | Content |
|------|---------|
| `seg_segmentation_report.xlsx` | Summary, profiles, statistics, validation |
| `seg_segmentation_report.html` | Interactive HTML report with all enabled sections |
| `seg_segment_assignments.xlsx` | ID + segment_id + segment_name (+ GMM probabilities if applicable) |
| `seg_model.rds` | Saved model for scoring new data |

### Multi-Method Mode

| File | Content |
|------|---------|
| `seg_kmeans_assignments.xlsx` | K-means segment assignments |
| `seg_hclust_assignments.xlsx` | Hierarchical segment assignments |
| `seg_gmm_assignments.xlsx` | GMM segment assignments (with probabilities) |
| `seg_combined_report.html` | Tabbed HTML report with comparison tab |
| `seg_kmeans_model.rds` | K-means model file |
| `seg_hclust_model.rds` | Hierarchical model file |
| `seg_gmm_model.rds` | GMM model file |

------------------------------------------------------------------------

## Using Segments in Other Turas Modules

Once you have a segmentation, you can use those segments as banners in cross-tabs, as subgroups in key driver analysis, or in other downstream work.

### Merging Segments onto Your Data

The module provides a utility function:

```r
source("modules/segment/R/10_utilities.R")

merge_result <- merge_segment_to_data(
  data_path       = "data/survey_data.csv",
  assignment_path = "output/seg_segment_assignments.xlsx",
  id_column       = "respondent_id",
  output_path     = "data/survey_data_with_segments.csv"
)
```

### Using Segments as a Banner in the Tabs Module

1. Merge your segment onto the data.
2. In the Tabs config, add `segment_name` as a banner variable.

### Using Segments in Key Driver or Categorical Driver Analysis

1. Merge your segment onto the data.
2. In the Key Driver or catdriver config file, add a Segments sheet defining each segment by its `segment_name` column value.

------------------------------------------------------------------------

## Additional Resources

- [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) -- Statistical methods reference
- [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) -- Developer documentation
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) -- Complete field-by-field template reference
- [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) -- Practical example workflows
- [08_HTML_REPORT_GUIDE.md](08_HTML_REPORT_GUIDE.md) -- HTML report features and usage

------------------------------------------------------------------------

**Part of the Turas Analytics Platform** -- The Research LampPost (Pty) Ltd
