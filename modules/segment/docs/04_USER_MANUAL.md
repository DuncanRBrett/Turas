# Turas Segmentation Module -- User Manual

**Version:** 11.0 **Last Updated:** 6 March 2026 **Audience:** Market Researchers, Data Analysts, Survey Managers

------------------------------------------------------------------------

## Table of Contents

1.  [Quick Start](#1-quick-start)
2.  [Choosing Variables](#2-choosing-variables)
3.  [Choosing the Number of Segments (k)](#3-choosing-the-number-of-segments-k)
4.  [Choosing a Segmentation Model](#4-choosing-a-segmentation-model)
5.  [Running a Segmentation: Start to Finish](#5-running-a-segmentation-start-to-finish)
6.  [Using Segments in Other Modules](#6-using-segments-in-other-modules)
7.  [Interpreting Results](#7-interpreting-results)
8.  [Pitfalls and Common Mistakes](#8-pitfalls-and-common-mistakes)
9.  [Config Reference](#9-config-reference)

------------------------------------------------------------------------

## 1. Quick Start

This section gets you from zero to a working segmentation as fast as possible. You need two things: a data file and a config file.

### Minimal Config

Create an Excel file (e.g., `my_config.xlsx`) with a sheet named **Config**. The sheet has two columns: `Setting` and `Value`. Only three settings are required:

```         
Setting          | Value
-----------------|----------------------------
data_file        | data/survey_data.csv
id_variable      | respondent_id
clustering_vars  | Q01,Q02,Q03,Q04,Q05
```

That is it. Everything else has sensible defaults.

### Run It

**Option A: Through the Turas GUI**

``` r
source("launch_turas.R")
launch_turas()
```

Select the Segment module, browse to your config file, validate, and run.

**Option B: From the R console**

``` r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("my_config.xlsx")
```

### What Happens

Because `k_fixed` was left blank, the module runs in **exploration mode**. It tests k = 3 through k = 6 (the defaults) and produces:

-   An Excel report with metrics for each k value
-   An HTML report with elbow plots and silhouette charts
-   A recommendation for the best k

You then review the output, choose your k, add `k_fixed = 4` (or whatever you chose) to the config, and re-run. The second run produces the final segmentation with full profiling, action cards, and segment assignments.

### Quick Run (No Config File)

For rapid prototyping without creating a config file:

``` r
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

## 2. Choosing Variables

Variable selection is the single most important decision in segmentation. The variables you cluster on determine what your segments represent.

### What to Include

**Attitudinal variables** -- Satisfaction ratings, brand perceptions, agreement scales, importance ratings. These capture how people think and feel, which is the foundation of most market segmentation.

**Behavioural variables** -- Purchase frequency, usage occasions, channel preference scores. These capture what people do. Best when expressed as numeric scales.

**Needs-based variables** -- Statements about what respondents want or need from a category. These produce actionable segments because needs can be addressed with product and service changes.

### What NOT to Include

**Demographics** (age, gender, income, region) -- These should be used to *profile* your segments after they are created, not to define them. If you cluster on age, you will get age-based segments, which you could have created with a simple cross-tab.

**ID columns** -- Respondent IDs, timestamps, record numbers. These are unique per row and will destroy the clustering.

**Open-ended responses** -- Free text cannot be clustered directly. If you need to include open-end themes, code them as numeric variables first.

**Constants** -- Any variable where every respondent gave the same answer provides zero discrimination. The module will flag these automatically.

**Highly skewed variables** -- If 95% of respondents chose the same answer, that variable adds noise rather than signal.

### How Many Variables?

| Count | Guidance                                                 |
|-------|----------------------------------------------------------|
| 2-4   | Too few -- solution will be over-simplified              |
| 5-12  | Ideal range for most surveys                             |
| 13-15 | Acceptable with variable selection enabled               |
| 16+   | Too many -- enable variable selection or reduce manually |

### Variable Selection Features

When you have more variables than you should cluster on, the module can automatically reduce them. All variable selection is controlled from the main Config sheet -- there is no separate VarSel_Config sheet.

**Variance filtering** removes variables where nearly everyone answered the same way. If a 10-point scale has a variance below 0.1 (on standardised data), it is not differentiating respondents and should be dropped.

**Correlation analysis** finds pairs of variables that are highly correlated (e.g., r \> 0.80). When two variables measure essentially the same thing, one is removed (the one with lower overall variance).

**Factor analysis** identifies the underlying dimensions in your data and selects representative variables from each factor. This is the most sophisticated method and produces the most balanced variable set.

### Config Parameters for Variable Selection

| Parameter | Default | What It Does |
|----|----|----|
| `variable_selection` | `FALSE` | Set to `TRUE` to enable automatic variable selection |
| `variable_selection_method` | `variance_correlation` | Algorithm: `variance_correlation`, `factor_analysis`, or `both` |
| `max_clustering_vars` | `10` | Target number of variables to keep (2-20) |
| `varsel_min_variance` | `0.1` | Minimum variance threshold (0.01-1.0) |
| `varsel_max_correlation` | `0.8` | Maximum allowed correlation before one variable is removed (0.5-0.95) |

**Example config for variable selection:**

```         
Setting                    | Value
---------------------------|----------------------------
data_file                  | data/large_survey.csv
id_variable                | ResponseID
clustering_vars            | Q01,Q02,Q03,Q04,...,Q25
variable_selection         | TRUE
variable_selection_method  | variance_correlation
max_clustering_vars        | 10
varsel_min_variance        | 0.1
varsel_max_correlation     | 0.8
```

The module will reduce your 25 variables to approximately 10, removing those with low variance and those that duplicate information already captured by other variables. The variable selection report is included in the output so you can see exactly which variables were kept and why.

------------------------------------------------------------------------

## 3. Choosing the Number of Segments (k)

How many segments should you have? This is part science, part art. The module gives you the science; you supply the art.

### Step 1: Run Exploration Mode

Leave `k_fixed` blank in your config and set the range you want to test:

```         
Setting    | Value
-----------|-------
k_fixed    |
k_min      | 2
k_max      | 8
```

The module will run the clustering algorithm for every k from 2 to 8 and produce comparison metrics.

### Step 2: Read the Exploration Report

The exploration report (Excel and HTML) gives you several metrics for each k value:

**Silhouette score** (most important) -- Measures how well each respondent fits their assigned segment compared to the next-closest segment. Ranges from -1 to 1.

| Score       | Interpretation                          |
|-------------|-----------------------------------------|
| 0.71 - 1.00 | Excellent separation                    |
| 0.51 - 0.70 | Good separation                         |
| 0.26 - 0.50 | Moderate -- structure present but fuzzy |
| \< 0.25     | Weak -- may not have real segments      |

**Elbow plot (WCSS)** -- Shows the within-cluster sum of squares for each k. Look for the "elbow" where the curve bends -- adding more segments beyond that point gives diminishing returns.

**Calinski-Harabasz index** -- Higher is better. Measures the ratio of between-cluster variance to within-cluster variance.

**Davies-Bouldin index** -- Lower is better. Measures average similarity between each cluster and its most similar neighbour.

### Step 3: Apply Practical Judgement

Statistics alone do not choose k. Ask yourself:

-   **Can you describe each segment?** If you cannot give a meaningful name to every segment, you may have too many.
-   **Can you action each segment differently?** If two segments would receive the same marketing treatment, they should probably be merged.
-   **Will stakeholders remember them?** Four segments named "Advocates, Engaged, Passive, Detractors" is manageable. Eight is not.
-   **Are all segments large enough?** A segment with 3% of respondents is too small to act on in most contexts.

### Rules of Thumb

| Situation                            | Recommended k |
|--------------------------------------|---------------|
| Most consumer surveys (n = 200-1000) | 3-5           |
| Large-scale tracking studies         | 4-6           |
| B2B with small sample                | 2-4           |
| Complex needs-based segmentation     | 4-6           |
| Maximum practical limit              | 8             |

**Never go above 8 segments** unless you have a very specific reason and a very large sample. More than 8 segments is almost always overfitting -- you are finding structure in the noise rather than in the signal.

### Pitfalls

-   **Overfitting**: More segments always improves the statistical metrics, but the extra segments may not be real. If silhouette barely improves from k=5 to k=6, stick with 5.
-   **Tiny clusters**: If any segment has fewer than 30 respondents, the profiles will be unreliable. Set `min_segment_size_pct` to at least 10%.
-   **Metrics disagree**: When silhouette says k=4 and the elbow says k=5, run both as final solutions and compare the profiles. Choose the one that tells a more coherent story.

------------------------------------------------------------------------

## 4. Choosing a Segmentation Model

The module supports four clustering algorithms. In most cases, K-means is the right choice. Use the decision matrix below when you are unsure.

### Decision Matrix

| Factor | K-means | Hierarchical | GMM | LCA |
|----|----|----|----|----|
| **Best for** | Most surveys | Exploring structure | Overlapping segments | Categorical data |
| **Data type** | Continuous (scales, ratings) | Continuous | Continuous | Categorical / ordinal |
| **Speed** | Fast | Moderate | Slower | Moderate |
| **Sample size limit** | 50,000+ | \~15,000 | 10,000 | 5,000 |
| **Cluster shape** | Spherical | Varies by linkage | Elliptical | N/A (model-based) |
| **Assignment type** | Hard | Hard | Soft (probabilities) | Soft (probabilities) |
| **Model selection** | Silhouette, elbow | Dendrogram | BIC/AIC | BIC/AIC |
| **Reproducibility** | Depends on nstart | Deterministic | Depends on init | Depends on init |

### K-means (Default)

Use K-means when: - Your data is numeric ratings or scales (1-5, 1-7, 1-10) - You want the fastest run time - You expect roughly equal-sized, compact segments

Config:

```         
method  | kmeans
nstart  | 50
```

The `nstart` parameter controls how many random starting positions the algorithm tries. Higher values (25-50) produce more stable results. The default is 50. For very large datasets (n \> 10,000), the module automatically switches to mini-batch K-means for speed.

### Hierarchical Clustering

Use hierarchical clustering when: - You want to explore the nested structure of your data before choosing k - A dendrogram visualisation is important for your stakeholders - You want a deterministic result (same data always gives same answer) - Your sample is under 15,000 respondents (memory constraint for the distance matrix)

Config:

```         
method          | hclust
linkage_method  | ward.D2
```

**Linkage methods:** - `ward.D2` (recommended) -- Produces compact, balanced clusters. Best default for survey data. - `complete` -- Creates well-separated clusters, but can produce unequal sizes. - `average` -- A middle ground, useful when cluster sizes vary substantially.

### Gaussian Mixture Models (GMM)

Use GMM when: - You believe segments genuinely overlap (respondents sit between groups) - You need probability-based membership (e.g., "this respondent is 70% Segment A, 30% Segment B") - You want BIC-based model selection rather than heuristic metrics - Your clusters may be elliptical rather than spherical

Config:

```         
method          | gmm
gmm_model_type  |
```

Leave `gmm_model_type` blank to let the algorithm automatically select the best covariance structure via BIC. If you know what you want, valid values include `VVV` (most flexible), `EEE` (all clusters same shape), and others.

Requires the `mclust` package: `install.packages("mclust")`

GMM produces additional output columns in the assignments file: - `prob_segment_1`, `prob_segment_2`, etc. -- probability of belonging to each segment - `max_probability` -- the highest probability - `uncertainty` -- 1 minus the highest probability (higher = more ambiguous)

### Latent Class Analysis (LCA)

Use LCA when: - Your clustering variables are purely categorical (yes/no, multi-choice) - Standard K-means on categorical data produces poor results - You want formal model fit statistics (AIC, BIC)

Config:

```         
use_lca  | TRUE
```

Requires the `poLCA` package: `install.packages("poLCA")`

LCA is best for categorical variables that cannot be meaningfully treated as continuous. For Likert scales (e.g., 1-5 agreement), K-means or GMM are usually preferable.

### Multi-Method Comparison

Not sure which method is best? Run them all side-by-side:

```         
method  | kmeans,hclust,gmm
```

Or use:

```         
method  | all
```

This runs each algorithm independently on the same prepared data and produces: - Per-method assignment files (`seg_kmeans_assignments.xlsx`, `seg_hclust_assignments.xlsx`, `seg_gmm_assignments.xlsx`) - Per-method model files - A combined HTML report with tabs for each method plus a **Comparison** tab showing: - Side-by-side metrics (silhouette, BSS/TSS) - Agreement matrix (Adjusted Rand Index) showing how much the methods agree - A method recommendation based on overall quality

------------------------------------------------------------------------

## 5. Running a Segmentation: Start to Finish

Segmentation is a three-step process. You use **Excel as your workbench** (reviewing metrics, refining variables, editing segment names) and the **HTML report as the deliverable** (the polished output for stakeholders). All three steps run from the Shiny app or R console -- the Excel files are what you review between runs.

```
STEP 1: EXPLORE        →  Excel workbench  →  Pick k, remove weak variables
STEP 2: FINALIZE       →  Excel workbench  →  Review & edit segment names
STEP 3: DELIVER (opt.) →  HTML report      →  Send to stakeholders
```

### Before You Start: Prepare Your Data

Your data file should be:
- **Format:** CSV, Excel (.xlsx), or SPSS (.sav)
- **Structure:** One row per respondent, one column per variable
- **ID column:** A unique identifier (e.g., `respondent_id`)
- **Clustering variables:** Numeric columns with the attitudes/behaviours to segment on

**Data quality checklist:**

-   [ ] No duplicate respondent IDs
-   [ ] All clustering variables are numeric
-   [ ] Missing data under 15% per variable
-   [ ] Variables use consistent scales (all 1--10, or all 1--5, etc.)
-   [ ] No constant variables (everyone gave the same answer)
-   [ ] At least 100 complete cases after removing missing data

### Before You Start: Create the Config File

Copy the template from `modules/segment/docs/templates/Segment_Config_Template.xlsx` and fill in the Settings tab. At minimum, set:

```
Setting          | Value
-----------------|--------------------------------
data_file        | path/to/your/data.csv
id_variable      | respondent_id
clustering_vars  | Q01,Q02,Q03,Q04,Q05,Q06,Q07
```

You can also generate a config template programmatically:

``` r
source("modules/segment/R/10_utilities.R")
generate_config_template(
  data_file = "data/survey.csv",
  output_file = "config/my_segmentation.xlsx",
  mode = "exploration"
)
```

---

### STEP 1: Exploration Run

**Goal:** Find the right number of segments and confirm your variables are contributing.

**Config settings for this step:**

```
Setting          | Value                | Notes
-----------------|----------------------|------------------------------
k_fixed          | (leave blank)        | Triggers exploration mode
k_min            | 3                    | Smallest k to test
k_max            | 6                    | Largest k to test
method           | kmeans               | Or hclust, gmm, lca, or comma-separated for multi-method
```

**Run it** from the Shiny app (browse to config, validate, run) or from R:

``` r
source("modules/segment/run_segment.R")
result <- turas_segment_from_config("config/my_segmentation.xlsx")
```

**Output:** `seg_k_selection_report.xlsx` with these sheets:

| Sheet                    | What It Contains                                                       |
|--------------------------|------------------------------------------------------------------------|
| **Metrics_Comparison**   | All fit metrics (silhouette, BSS/TSS, etc.) across k values            |
| **Profile_K3**           | Segment means for k=3 (one sheet per k tested)                        |
| **Profile_K4**           | Segment means for k=4                                                  |
| **Variable_Contribution**| Eta-squared per variable with ESSENTIAL / USEFUL / MINIMAL IMPACT flags|
| **Run_Status**           | Execution summary                                                      |

**What to do with the output:**

1. **Open `seg_k_selection_report.xlsx`** in Excel.

2. **Check the Metrics_Comparison sheet.** Compare silhouette scores and BSS/TSS across k values. Higher silhouette = better-separated segments. The module highlights its recommended k, but use your judgement -- does the recommended k produce segments that make business sense?

3. **Check the Variable_Contribution sheet.** This is new and important. For the recommended k, each clustering variable is rated:

   | Category            | Eta-Squared | What It Means                            |
   |---------------------|-------------|------------------------------------------|
   | **ESSENTIAL**       | > 0.30      | This variable strongly separates segments |
   | **USEFUL**          | 0.10 -- 0.30| Contributes meaningfully                  |
   | **MINIMAL IMPACT**  | < 0.10      | Not helping -- consider removing           |

   Variables marked "Consider removing" in the Annotation column are candidates for removal. Removing weak variables often improves the solution.

4. **Check the Profile sheets.** Do the segments at your chosen k tell a coherent story? Can you see distinct groups that a stakeholder would recognise?

5. **If you need to refine:** Update your config -- remove weak variables from `clustering_vars`, adjust `k_min`/`k_max`, try a different method -- and re-run Step 1. Repeat until you are satisfied.

> **Tip:** Exploration mode works with all methods (K-Means, Hierarchical, GMM, LCA). You can also test multiple methods at once by setting `method = kmeans,hclust,gmm`. Note that LCA is not a `method` value -- to include LCA, set `use_lca = TRUE` separately.

---

### STEP 2: Final Run

**Goal:** Lock in your chosen k, generate descriptive segment names, and produce assignments.

**Config settings for this step:**

```
Setting          | Value                | Notes
-----------------|----------------------|------------------------------
k_fixed          | 4                    | Your chosen number of segments
auto_name_style  | descriptive          | Auto-generate meaningful names (or "persona", "simple")
html_report      | TRUE                 | Generate HTML report (optional -- see shortcut below)
```

Enable any additional features you want:

```
generate_action_cards   | TRUE
generate_rules          | TRUE
run_stability_check     | TRUE
```

**Run it** the same way as Step 1.

**Output:** `seg_segment_assignments.xlsx` with these sheets:

| Sheet                    | What It Contains                                           |
|--------------------------|------------------------------------------------------------|
| **Segment_Assignments**  | One row per respondent: ID, segment_id, segment_name       |
| **Segment_Names**        | Editable name table (see below)                            |

The **Segment_Names** sheet has three columns:

```
Segment_ID | Suggested_Name              | Custom_Name
-----------|-----------------------------|-----------------
1          | Health-Focused Traditionalists|
2          | Price-Sensitive Pragmatists  |
3          | Brand-Loyal Enthusiasts      |
4          | Disengaged Minimalists       |
```

**What to do with the output:**

1. **Open `seg_segment_assignments.xlsx`** in Excel.
2. **Go to the Segment_Names sheet.** The `Suggested_Name` column contains auto-generated names based on what makes each segment distinctive.
3. **Edit the `Custom_Name` column.** Type your preferred name for each segment. If you leave `Custom_Name` blank, the suggested name is used. Examples:

   ```
   Segment_ID | Suggested_Name              | Custom_Name
   -----------|-----------------------------|-----------------
   1          | Health-Focused Traditionalists| Wellness Warriors
   2          | Price-Sensitive Pragmatists  | Budget Hunters
   3          | Brand-Loyal Enthusiasts      | True Believers
   4          | Disengaged Minimalists       | The Indifferent
   ```

4. **Save the Excel file.** Do not rename it or move it.

> **Shortcut:** If you are happy with the auto-generated names and set `html_report = TRUE` in this step, the HTML report is produced immediately using the suggested names. You can skip Step 3 entirely and go straight to delivering the report.

---

### STEP 3: Finalize HTML Report (Optional)

**Goal:** Produce the final stakeholder-ready HTML report using your edited segment names.

**When to use this step:** Only if you edited segment names in Step 2 and did not set `html_report = TRUE` there, or if you want to regenerate the report with different names.

**Config settings for this step:**

```
Setting              | Value                                    | Notes
---------------------|------------------------------------------|---------
k_fixed              | 4                                        | Same k as Step 2
segment_names_file   | output/seg_segment_assignments.xlsx      | Path to the Excel you edited in Step 2
html_report          | TRUE                                     | Generate the HTML report
```

**Run it** the same way as Steps 1 and 2.

**What happens:** The module reads your edited names from the `Segment_Names` sheet. For each segment, it uses `Custom_Name` if you filled it in, otherwise falls back to `Suggested_Name`. These names appear throughout the HTML report -- in the executive summary, profiles, charts, action cards, and everywhere else.

**Output:** `seg_segmentation_report.html` -- a self-contained HTML file you can email, share, or present. It contains (depending on your settings):

-   Executive summary with quality assessment and pen-sketch descriptions
-   Segment sizes and composition
-   Validation metrics (silhouette, BSS/TSS)
-   Variable importance (eta-squared)
-   Segment profile heatmap and table
-   Overlap heatmap (centroid distances)
-   Golden questions (best discriminating variables)
-   Classification rules (if enabled)
-   Segment action cards (if enabled)
-   Vulnerability analysis
-   Interpretation guide

See Section 7 for how to read each part.

> **What if the file is missing?** If `segment_names_file` points to a file that does not exist, the module prints a warning to the console and falls back to auto-generated names. It does not fail.

---

### Multi-Method Comparison (Optional)

At any point, you can compare how different algorithms segment your data by setting:

```
method  | kmeans,hclust,gmm
```

This produces a combined HTML report with a "Best Fit" recommendation and side-by-side comparison of each algorithm's segments.

### Summary: What You Set in Each Step

| Setting              | Step 1 (Explore) | Step 2 (Finalize) | Step 3 (HTML) |
|----------------------|------------------|-------------------|---------------|
| `k_fixed`            | *(blank)*        | 4                 | 4             |
| `k_min` / `k_max`   | 3 / 6            | --                | --            |
| `auto_name_style`    | --               | descriptive       | --            |
| `segment_names_file` | --               | --                | path/to/xlsx  |
| `html_report`        | --               | TRUE *(optional)* | TRUE          |

------------------------------------------------------------------------

## 6. Using Segments in Other Modules

Once you have a segmentation, you will want to use those segments as banners in cross-tabs, as subgroups in key driver analysis, or in other downstream work. Here is how.

### How the Assignment File Works

The segmentation module produces a file called `seg_segment_assignments.xlsx` (or with your configured prefix). This file has three columns:

```         
respondent_id | segment_id | segment_name
1001          | 1          | Advocates
1002          | 3          | Passive
1003          | 2          | Engaged
1004          | 1          | Advocates
```

This is the bridge between your segmentation and everything else. You merge it onto your original data using the ID column.

### Merging Segments onto Your Data

The module provides a utility function for this:

``` r
source("modules/segment/R/10_utilities.R")

merge_result <- merge_segment_to_data(
  data_path       = "data/survey_data.csv",
  assignment_path = "output/seg_segment_assignments.xlsx",
  id_column       = "respondent_id",
  output_path     = "data/survey_data_with_segments.csv"
)

# Check the result
cat("Matched:", merge_result$n_matched, "respondents\n")
cat("Unmatched:", merge_result$n_unmatched, "respondents\n")
```

This creates a new data file with the `segment_id` and `segment_name` columns appended. If you omit `output_path`, the function returns the merged data frame in memory without writing a file.

### Using Segments as a Banner in the Tabs Module

The Tabs module lets you cross-tabulate survey results by segment. To do this:

1.  Merge your segment onto the data (see above).
2.  In the Tabs config, add `segment_name` as a banner variable:

```         
Setting         | Value
----------------|------------------------------------
data_file       | data/survey_data_with_segments.csv
banner_vars     | segment_name
```

Each tab table will now show results broken out by segment, with significance tests comparing the segments.

### Using Segments as Subgroups in Key Driver Analysis

The Key Driver module can run separate driver analyses for each segment. To do this:

1.  Merge your segment onto the data.
2.  In the Key Driver config file, add a **Segments** sheet with these columns:

| segment_name | segment_variable | segment_values |
|--------------|------------------|----------------|
| Advocates    | segment_name     | Advocates      |
| Engaged      | segment_name     | Engaged        |
| Passive      | segment_name     | Passive        |
| Detractors   | segment_name     | Detractors     |

The key driver module will run its full analysis separately for each segment, producing per-segment driver rankings, quadrant charts, and importance maps.

### Using Segments in Categorical Driver Analysis (catdriver)

The same approach works for catdriver. Merge the segment column onto your data and define the segments in the Segments sheet of the catdriver config.

### Step-by-Step Summary

1.  Run segmentation to get assignment file
2.  Call `merge_segment_to_data()` to add segments to original data
3.  Use the merged data file in downstream modules
4.  Configure segment as a banner (tabs) or subgroup (keydriver/catdriver)

------------------------------------------------------------------------

## 7. Interpreting Results

### Reading the HTML Report Section by Section

**Executive Summary** -- A plain-English overview generated automatically. It tells you how many segments were found, the overall quality of the solution, which segment is largest, which variables differentiate best, and any warnings. Read this first to get the big picture.

The quality assessment uses these thresholds:

| Rating    | Silhouette Score | Meaning                                       |
|-----------|------------------|-----------------------------------------------|
| Excellent | \> 0.50          | Strong, well-separated segments               |
| Good      | 0.35 - 0.50      | Meaningful segments with some overlap         |
| Moderate  | 0.25 - 0.35      | Segments exist but boundaries are fuzzy       |
| Limited   | \< 0.25          | Weak structure -- consider different approach |

**Segment Overview** -- A bar chart and table showing how many respondents are in each segment and their percentage of the total. Look for reasonably balanced sizes. If one segment has 60% and another has 5%, the solution may be picking up on a dominant pattern rather than useful sub-groups.

**Validation Metrics** -- A silhouette chart showing how well each respondent fits their segment. The chart plots individual silhouette values grouped by segment. Respondents with negative silhouette values are "misclassified" -- they are closer to a neighbouring segment than to their own. A few of these are normal; many indicate a problem.

Additional metrics displayed: - **BSS/TSS (Between-SS / Total-SS):** Proportion of variance explained by the segments. Higher is better. Above 0.40 is typical for survey data. - **Calinski-Harabasz index:** Higher is better. No absolute threshold, but useful for comparing solutions. - **Davies-Bouldin index:** Lower is better. Below 1.0 is generally good.

### Segment Profiles

The profile heatmap and table show the mean score for each variable in each segment, alongside the overall mean. This is how you understand *what makes each segment different*.

**Reading the heatmap:** Darker cells indicate higher scores. Look for the pattern -- which segments score high on which variables? The variables are sorted by importance (eta-squared), so the most differentiating variables appear at the top.

**Index scores:** Some outputs show index scores (segment mean / overall mean \* 100). An index of 120 means that segment scores 20% above average on that variable. An index of 80 means 20% below average. Indices above 110 and below 90 are generally noteworthy.

### Variable Importance (Eta-Squared)

The variable importance chart shows how much each variable contributes to distinguishing the segments, measured by eta-squared.

| Eta-squared | Interpretation                                 |
|-------------|------------------------------------------------|
| \> 0.14     | Large effect -- strong differentiator          |
| 0.06 - 0.14 | Medium effect -- meaningful differentiator     |
| 0.01 - 0.06 | Small effect -- weak differentiator            |
| \< 0.01     | Negligible -- not useful for this segmentation |

Variables with low eta-squared could potentially be removed from the clustering variables without changing the solution much.

**Important note:** Because segments are *defined* by these variables, p-values in the statistical tests are descriptive, not inferential. Focus on effect sizes (eta-squared), not p-values.

### Vulnerability Analysis

Every final run includes a vulnerability (switching) analysis that identifies respondents whose segment assignment is borderline -- they sit near the boundary between two segments.

**What it measures:** - **Assignment confidence** (0 to 1): How firmly each respondent belongs to their segment. For K-means/hierarchical, this is based on distance ratios. For GMM, it uses probability margins. - **Vulnerable flag:** Respondents with confidence below 0.3 (configurable). - **Would switch to:** The segment each borderline respondent would join if reassigned. - **Switching matrix:** Counts of potential switches between segment pairs, showing which segments have the most overlap.

**Interpreting the vulnerability rate:**

| \% Vulnerable | Interpretation |
|----|----|
| \< 15% | Strong segmentation with clear boundaries |
| 15-30% | Moderate overlap between some segments |
| \> 30% | Significant overlap -- consider fewer segments or different variables |

**Note on GMM:** GMM naturally produces lower vulnerability rates because its probability-based assignments provide sharper confidence scores. Do not compare vulnerability rates across methods.

### Golden Questions

Golden questions are the 3-5 variables (configurable via `golden_questions_n`) that best discriminate between segments. They are identified using Random Forest variable importance -- a machine learning approach that captures non-linear relationships the eta-squared may miss.

These are your "typing" questions: if you could only ask a few questions to assign a new respondent to a segment, these would be the ones. They are useful for: - Shortening a screening questionnaire - Building a typing tool for ongoing classification - Understanding which variables really drive the segmentation

### Segment Action Cards

Action cards provide executive-ready summaries for each segment: - **Segment name and size** - **Defining characteristics** (what makes this segment unique) - **Strengths** (highest-scoring variables) - **Pain points** (lowest-scoring variables) - **Recommended actions** (auto-generated suggestions based on the profile)

These are designed to be shared directly with stakeholders who need to act on the segments without reading the full technical report.

### Classification Rules

When enabled (`generate_rules = TRUE`), the module uses a decision tree to produce plain-English IF-THEN rules for segment membership. For example:

> IF Product Quality \>= 7.5 AND Service Rating \>= 6.0 THEN Segment = Advocates (accuracy: 82%)

These rules simplify the complex multivariate clustering into a few decision points. They are approximate (the decision tree will not perfectly replicate the clustering) but give stakeholders an intuitive understanding of what defines each segment. The overall classification accuracy is reported alongside the rules.

------------------------------------------------------------------------

## 8. Pitfalls and Common Mistakes

### Too Many Variables

**Symptom:** Segments are hard to interpret, silhouette score is low, solution is unstable across runs.

**Fix:** Enable variable selection (`variable_selection = TRUE`) to automatically reduce your variable set. Alternatively, manually select 5-12 variables based on theory: which attitudes or behaviours do you *expect* to differentiate your market?

### Too Many Segments

**Symptom:** Small segments with fewer than 30 respondents. Segments that are hard to name. Stakeholders cannot remember them all.

**Fix:** Start with fewer segments. In most surveys, 3-5 segments capture the key market structure. You can always test more later.

### Too Few Segments

**Symptom:** Segments are very broad and each contains diverse respondents. Profiles look similar to the overall average. Silhouette score is very high but segments are not actionable.

**Fix:** Try k+1. A two-segment solution often just splits "happy" from "unhappy" without capturing the nuance.

### Ignoring Validation Metrics

**Symptom:** Stakeholders choose k based on "we want 5 segments" without looking at the data.

**Fix:** Always run exploration mode first. If the data does not support 5 segments, forcing 5 will produce a poor solution. Let the data guide the number, then adjust based on practical needs.

### Not Checking Segment Stability

**Symptom:** Re-running the analysis with a different seed produces different segments.

**Fix:** Enable stability checking (`run_stability_check = TRUE`). If stability is below 80%, the solution is fragile. Try: - Reducing the number of variables - Reducing k - Increasing `nstart` for K-means (try 50 or 100) - Switching to hierarchical clustering (deterministic)

### Including Demographics as Clustering Variables

**Symptom:** Segments defined primarily by age, gender, or region rather than attitudes. The segmentation tells you things you already knew.

**Fix:** Remove all demographic variables from `clustering_vars`. Use them as `profile_vars` or `demographic_vars` instead. Demographics should describe your segments, not define them.

### Missing Data Problems

**Symptom:** Too many respondents dropped due to listwise deletion. Sample size falls below minimum.

**Fix:** First, check which variables have the most missing data and consider removing them from the clustering set. If the issue is moderate (5-15% missing), switch to `missing_data = mean_imputation` or `missing_data = median_imputation`. If a variable has more than 30% missing, do not include it.

### Scale Inconsistency

**Symptom:** Variables measured on different scales (some 1-5, some 1-10, some 0-100) dominate or are drowned out in the clustering.

**Fix:** Keep `standardize = TRUE` (the default). The module standardises all variables to mean 0 and standard deviation 1 before clustering, which puts them on equal footing regardless of original scale.

### Interpreting Too Much into Small Segments

**Symptom:** A segment with 15 respondents is described in great detail and treated as a strategic target.

**Fix:** Small segments have unreliable profiles. A mean based on 15 respondents has wide confidence intervals. Set `min_segment_size_pct` to at least 10% to flag segments that are too small to act on.

------------------------------------------------------------------------

## 9. Config Reference

All parameters available in the Config sheet, organised by category. Parameters are listed with their default values -- only set the ones you want to change.

### Core Settings (Required)

| Parameter | Default | Description |
|----|----|----|
| `data_file` | (none) | Path to survey data file (.csv, .xlsx, .xls, .sav) |
| `id_variable` | (none) | Column name for respondent ID |
| `clustering_vars` | (none) | Comma-separated list of variables to cluster on |

### Core Settings (Optional)

| Parameter | Default | Description |
|----|----|----|
| `data_sheet` | `Data` | Sheet name for Excel data files |
| `profile_vars` | (all) | Comma-separated list of profiling variables (not clustering) |

### Mode and K Settings

| Parameter | Default | Description                                          |
|-----------|---------|------------------------------------------------------|
| `k_fixed` | (blank) | Fixed k for final mode. Leave blank for exploration. |
| `k_min`   | `3`     | Minimum k to test in exploration mode (2-10)         |
| `k_max`   | `6`     | Maximum k to test in exploration mode (2-15)         |
| `seed`    | `123`   | Random seed for reproducibility                      |

**Mode detection:** If `k_fixed` is blank, the module runs in exploration mode. If `k_fixed` is set, it runs in final mode.

### Clustering Algorithm

| Parameter | Default | Description |
|----|----|----|
| `method` | `kmeans` | Algorithm: `kmeans`, `hclust`, `gmm`, comma-separated list, or `all` |
| `nstart` | `50` | Random starts for K-means (1-200). Higher = more stable. |
| `linkage_method` | `ward.D2` | Linkage for hierarchical clustering: `ward.D`, `ward.D2`, `single`, `complete`, `average`, `mcquitty`, `median`, `centroid` |
| `gmm_model_type` | (auto) | GMM covariance structure. Blank = auto-select by BIC. |
| `use_lca` | `FALSE` | Enable Latent Class Analysis (requires `poLCA`) |

### Data Handling

| Parameter | Default | Description |
|----|----|----|
| `missing_data` | `listwise_deletion` | Strategy: `listwise_deletion`, `mean_imputation`, `median_imputation`, `refuse` |
| `missing_threshold` | `15` | Maximum % missing allowed per variable (0-100) |
| `standardize` | `TRUE` | Standardise variables before clustering |
| `min_segment_size_pct` | `10` | Minimum % of sample per segment (0-50). Warns if below. |
| `scale_max` | (auto) | Maximum value on your rating scale (e.g., 10 for 1-10). Used by auto-naming and action cards. |

### Outlier Detection

| Parameter | Default | Description |
|----|----|----|
| `outlier_detection` | `FALSE` | Enable outlier detection |
| `outlier_method` | `zscore` | Detection algorithm: `zscore` or `mahalanobis` |
| `outlier_threshold` | `3.0` | Z-score threshold for flagging (1.0-5.0) |
| `outlier_min_vars` | `1` | Minimum variables a respondent must be outlier on |
| `outlier_handling` | `flag` | Action: `none`, `flag`, or `remove` |
| `outlier_alpha` | `0.001` | Significance level for Mahalanobis method (0.0001-0.1) |

### Variable Selection

| Parameter | Default | Description |
|----|----|----|
| `variable_selection` | `FALSE` | Enable automatic variable reduction |
| `variable_selection_method` | `variance_correlation` | Algorithm: `variance_correlation`, `factor_analysis`, or `both` |
| `max_clustering_vars` | `10` | Target number of variables to keep (2-20) |
| `varsel_min_variance` | `0.1` | Minimum variance threshold (0.01-1.0) |
| `varsel_max_correlation` | `0.8` | Maximum allowed correlation (0.5-0.95) |

### K Selection Metrics

| Parameter | Default | Description |
|----|----|----|
| `k_selection_metrics` | `silhouette,elbow` | Comma-separated: `silhouette`, `elbow`, `gap` |

### Output Settings

| Parameter | Default | Description |
|----|----|----|
| `output_folder` | `output/` | Where to save results |
| `output_prefix` | `seg_` | Filename prefix for all output files |
| `create_dated_folder` | `TRUE` | Create timestamped subfolder for each run |
| `save_model` | `TRUE` | Save model object (.rds) for scoring new data |
| `segment_names` | `auto` | Custom names (comma-separated) or `auto` |
| `auto_name_style` | `descriptive` | Auto-naming style: `descriptive`, `persona`, `simple` |
| `question_labels_file` | (blank) | Path to Excel file with variable labels (optional) |
| `segment_names_file` | (blank) | Path to Excel with edited segment names (Step 3 workflow) |

### Enhanced Features

| Parameter | Default | Description |
|----|----|----|
| `generate_rules` | `FALSE` | Generate IF-THEN classification rules (requires `rpart`) |
| `rules_max_depth` | `3` | Decision tree depth for rules (1-5) |
| `generate_action_cards` | `FALSE` | Generate executive-ready segment action cards |
| `run_stability_check` | `FALSE` | Run stability assessment across multiple seeds |
| `stability_n_runs` | `5` | Number of runs for stability check (3-20) |
| `golden_questions_n` | `3` | Number of top discriminating variables to identify (1-10) |
| `demographic_vars` | (blank) | Comma-separated demographic variables for profiling |

### HTML Report

| Parameter       | Default   | Description                                    |
|-----------------|-----------|------------------------------------------------|
| `html_report`   | `FALSE`   | Generate interactive HTML report               |
| `brand_colour`  | `#323367` | Primary colour for headers, nav, charts (hex)  |
| `accent_colour` | `#CC9900` | Accent colour for highlights and markers (hex) |
| `report_title`  | (auto)    | Title displayed in report header               |

### HTML Report Section Visibility

Each section of the HTML report can be shown or hidden independently:

| Parameter                | Default | Section                                 |
|--------------------------|---------|-----------------------------------------|
| `html_show_exec_summary` | `TRUE`  | Executive summary narrative             |
| `html_show_overview`     | `TRUE`  | Segment sizes chart and table           |
| `html_show_validation`   | `TRUE`  | Silhouette chart and validation metrics |
| `html_show_importance`   | `TRUE`  | Variable importance (eta-squared) chart |
| `html_show_profiles`     | `TRUE`  | Profile heatmap and table               |
| `html_show_demographics` | `TRUE`  | Demographic breakdown by segment        |
| `html_show_rules`        | `TRUE`  | Classification rules table              |
| `html_show_cards`        | `TRUE`  | Segment action cards                    |
| `html_show_stability`    | `TRUE`  | Stability assessment                    |
| `html_show_membership`   | `TRUE`  | GMM membership probabilities            |
| `html_show_guide`        | `TRUE`  | Interpretation guide                    |

### Metadata

| Parameter      | Default                 | Description                    |
|----------------|-------------------------|--------------------------------|
| `project_name` | `Segmentation Analysis` | Project name for reports       |
| `analyst_name` | `Analyst`               | Analyst name for reports       |
| `description`  | (blank)                 | Free-text analysis description |

### Complete Example: Exploration Config

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

### Complete Example: Final Config

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

### Complete Example: Multi-Method Comparison Config

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

## Output File Reference

### Exploration Mode

| File | Content |
|----|----|
| `seg_k_selection_report.xlsx` | Metrics comparison, recommendation, profiles per k |
| `seg_k_selection_report.html` | Interactive HTML with elbow and silhouette charts |
| `seg_model.rds` | Saved model object |

### Final Mode

| File | Content |
|----|----|
| `seg_segmentation_report.xlsx` | Summary, profiles, statistics, validation |
| `seg_segmentation_report.html` | Interactive HTML report with all enabled sections |
| `seg_segment_assignments.xlsx` | ID + segment_id + segment_name (+ GMM probs) |
| `seg_model.rds` | Saved model for scoring new data |

### Multi-Method Mode

| File | Content |
|----|----|
| `seg_kmeans_assignments.xlsx` | K-means segment assignments |
| `seg_hclust_assignments.xlsx` | Hierarchical segment assignments |
| `seg_gmm_assignments.xlsx` | GMM segment assignments (with probabilities) |
| `seg_combined_report.html` | Tabbed HTML report with comparison tab |
| `seg_kmeans_model.rds` | K-means model file |
| `seg_hclust_model.rds` | Hierarchical model file |
| `seg_gmm_model.rds` | GMM model file |

------------------------------------------------------------------------

## Scoring New Data

After building a segmentation, you can assign new respondents to the existing segments without re-running the full analysis.

### Requirements

-   The original model was saved (`save_model = TRUE` in the config)
-   The new data contains the same clustering variables as the original

### How to Score

``` r
source("modules/segment/R/08_scoring.R")

scores <- score_new_data(
  model_file  = "output/seg_model.rds",
  new_data    = new_survey_data,
  id_variable = "respondent_id",
  output_file = "output/new_respondent_scores.xlsx"
)
```

Each respondent receives: - `segment` -- Assigned segment number - `segment_name` -- Segment label - `distance_to_center` -- Distance from cluster centroid - `assignment_confidence` -- Confidence score (0-1)

### Monitoring Segment Drift

Over time, the distribution of new respondents across segments may shift. Use:

``` r
drift <- compare_segment_distributions(
  model_file     = "output/seg_model.rds",
  scoring_result = scores
)
```

If any segment changes by more than 10 percentage points, consider re-running the full segmentation on the combined data.

------------------------------------------------------------------------

## Additional Resources

-   [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) -- Statistical methods reference
-   [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) -- Developer documentation
-   [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) -- Complete field-by-field template reference
-   [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) -- Practical example workflows
-   [08_HTML_REPORT_GUIDE.md](08_HTML_REPORT_GUIDE.md) -- HTML report features and usage

------------------------------------------------------------------------

**Part of the Turas Analytics Platform** -- The Research LampPost (Pty) Ltd
