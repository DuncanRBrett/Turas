# Turas MaxDiff Module -- User Manual

**Version:** 11.1
**Last Updated:** March 2026
**Module:** Turas MaxDiff (part of the Turas Analytics Platform)

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Getting Started](#2-getting-started)
3. [Study Design Guide](#3-study-design-guide)
4. [Configuration Workbook Guide](#4-configuration-workbook-guide)
5. [Design Mode](#5-design-mode)
6. [Analysis Mode](#6-analysis-mode)
7. [Understanding the Output](#7-understanding-the-output)
8. [TURF Analysis](#8-turf-analysis)
9. [Anchored MaxDiff](#9-anchored-maxdiff)
10. [Working with Segments](#10-working-with-segments)
11. [HTML Report Interpretation Guide](#11-html-report-interpretation-guide)
12. [Simulator Guide](#12-simulator-guide)
13. [R Package Dependencies](#13-r-package-dependencies)
14. [Troubleshooting](#14-troubleshooting)
15. [Best Practices](#15-best-practices)
16. [Glossary](#16-glossary)

---

## 1. Introduction

### 1.1 What Is MaxDiff?

MaxDiff (Maximum Difference Scaling), also known as Best-Worst Scaling, is a survey-based research technique for measuring the relative importance or preference of multiple items. In each task, respondents view a small subset of items and select:

- The **BEST** (most important / most preferred) item
- The **WORST** (least important / least preferred) item

By forcing respondents to make trade-offs, MaxDiff produces sharply differentiated results. Where a rating scale often yields a cluster of high scores ("everything is important"), MaxDiff spreads items across the full preference continuum.

### 1.2 Why Use MaxDiff Instead of Rating Scales?

| Criterion | Rating Scale | MaxDiff |
|-----------|-------------|---------|
| Discrimination | Low -- most items rated similarly | High -- forces clear ranking |
| Scale-use bias | Present (acquiescence, central tendency) | Eliminated by design |
| Cross-cultural comparability | Weak -- scale anchors interpreted differently | Strong -- relative comparison is universal |
| Individual-level scores | Not available | Available via Hierarchical Bayes |
| Cognitive load per item | Low per item, high overall for 20+ items | Low -- only 4-5 items per task |
| Suitable for simulation | No | Yes -- utilities feed directly into share models |

### 1.3 When To Use MaxDiff

MaxDiff is the right choice when you need to:

- **Prioritise a list of items** -- features, benefits, messages, concepts, or needs
- **Force trade-offs** -- prevent inflated "everything is important" responses
- **Obtain interval-scale measurements** suitable for simulation and share-of-preference modelling
- **Generate individual-level preference scores** for segmentation, profiling, or personalisation
- **Compare preferences across segments** on a common metric

Common applications include product feature prioritisation, brand benefit testing, message testing, needs assessment, and menu or assortment optimisation.

### 1.4 When Not To Use MaxDiff

- **Fewer than 6 items** -- simple ranking or paired comparisons are more efficient.
- **Price and feature trade-offs together** -- use conjoint analysis instead.
- **Absolute measurement needed** -- MaxDiff measures relative preference, not absolute demand. A top-ranked item may still have low market appeal in absolute terms.
- **Items from fundamentally different categories** -- do not mix product features with brand names or price levels.

### 1.5 What This Module Does

The Turas MaxDiff module provides two operational modes:

| Mode | Purpose |
|------|---------|
| **DESIGN** | Generate balanced experimental designs for your MaxDiff study |
| **ANALYSIS** | Analyse survey responses and compute preference scores, charts, HTML reports, and an interactive simulator |

### 1.6 Key Capabilities

- Excel-based configuration (no coding required for standard workflows)
- Three scoring methods: count-based, aggregate conditional logit, and Hierarchical Bayes
- TURF (Total Unduplicated Reach and Frequency) portfolio optimisation
- Anchored MaxDiff for absolute "must-have" thresholds
- Segment-level analysis with statistical comparisons
- Publication-ready charts (PNG, 300 DPI)
- Self-contained HTML report with interactive charts
- Interactive HTML simulator for preference share scenarios, head-to-head comparisons, and portfolio building
- Individual-level preference utilities for advanced segmentation

---

## 2. Getting Started

### 2.1 Prerequisites

- **R version 4.0 or higher**
- **Required R packages** (see Section 13 for full list):
  - `openxlsx` (>= 4.2.5) -- Excel file handling
  - `survival` (>= 3.5-0) -- Conditional logit models
  - `ggplot2` (>= 3.4.0) -- Chart generation
- **Optional packages** (for advanced features):
  - `cmdstanr` (>= 0.7.0) -- Full Hierarchical Bayes estimation
  - `AlgDesign` (>= 1.2.0) -- Optimal experimental design
  - `base64enc` (>= 0.1-3) -- Logo embedding in HTML reports
  - `jsonlite` (>= 1.8.0) -- JSON output for simulator
  - `data.table` (>= 1.14.0) -- Fast data manipulation

### 2.2 Launching from the Turas GUI

1. Open R or RStudio.
2. Set your working directory to the Turas folder.
3. Run:
   ```r
   source("launch_turas.R")
   launch_turas()
   ```
4. Click the **MaxDiff** button in the launcher.
5. Browse to select your configuration Excel file.
6. Click **Run**.

### 2.3 Launching from the R Console

```r
# Navigate to Turas root
setwd("/path/to/Turas")

# Load the module
source("modules/maxdiff/R/00_main.R")

# Run with your config file
result <- run_maxdiff("path/to/your/maxdiff_config.xlsx")
```

Convenience wrappers are also available:

```r
# Quick run (verbose output)
quick_maxdiff("path/to/config.xlsx")

# Force design mode regardless of config setting
run_maxdiff_design("path/to/config.xlsx")

# Force analysis mode
run_maxdiff_analysis("path/to/config.xlsx")
```

### 2.4 Typical Workflow

```
  1. CREATE CONFIG    --  Build Excel workbook with items and settings
         |
  2. DESIGN MODE      --  Generate experimental design (Mode = DESIGN)
         |
  3. PROGRAM SURVEY   --  Use the design file to build your survey
         |
  4. COLLECT DATA     --  Field your survey
         |
  5. ANALYSIS MODE    --  Analyse responses (Mode = ANALYSIS)
         |
  6. REVIEW OUTPUT    --  Excel workbook, HTML report, simulator, charts
```

---

## 3. Study Design Guide

Good MaxDiff results depend on good study design. This section covers the decisions you need to make before programming your survey.

### 3.1 How Many Items to Test

| Range | Suitability | Notes |
|-------|------------|-------|
| 1-5 | Not recommended | Use simple ranking or paired comparisons instead |
| 6-7 | Possible | MaxDiff works but provides limited advantage over ranking |
| **8-12** | **Good** | Easy to design, low respondent burden |
| **12-20** | **Ideal** | Sweet spot for most studies -- good discrimination with manageable task load |
| 20-30 | Acceptable | Requires more tasks and/or design versions |
| 30+ | Use with caution | Consider a two-stage approach: screen with ratings first, then MaxDiff the top 20-25 |

**Common mistake:** Testing too many items (>30). This increases respondent burden, requires more tasks, and can lead to satisficing behaviour where respondents adopt simplifying shortcuts instead of genuinely evaluating.

### 3.2 Items Per Task

The number of items shown in each task affects information density and cognitive load.

| Items Per Task | Recommendation |
|----------------|----------------|
| 3 | Low information per task; rarely recommended |
| **4** | **Recommended default for most studies.** Good balance of information and simplicity |
| **5** | **Good for experienced or engaged respondents.** Slightly more information per task |
| 6 | Acceptable for professional/expert audiences only |
| 7+ | Not recommended -- cognitive overload |

With 4 items per task, each task yields 2 data points (best + worst) from 4 options -- 50% information density. With 5 items, you get 40% density per task but can test more item pairs per task.

### 3.3 Tasks Per Respondent

The number of tasks determines how much data you collect per person. Each item should appear at least 3 times per respondent for reliable estimation.

**Rule of thumb:**

```
Minimum tasks = 3 x (Number of items) / (Items per task)
Recommended tasks = 4 x (Number of items) / (Items per task)
```

| Items | Items/Task | Minimum Tasks | Recommended Tasks |
|-------|------------|---------------|-------------------|
| 8 | 4 | 6 | 8-10 |
| 10 | 4 | 8 | 10-12 |
| 12 | 4 | 9 | 12-14 |
| 15 | 5 | 9 | 12-15 |
| 20 | 5 | 12 | 15-18 |
| 25 | 5 | 15 | 18-20 |
| 30 | 5 | 18 | 20-24 |

**Common mistakes:**
- **Too few tasks** -- items do not appear often enough, utilities are imprecise.
- **Too many tasks** (>20 for general population) -- respondent fatigue leads to noisy data.

### 3.4 Sample Size Guidelines

| Analysis Goal | Minimum N | Recommended N |
|---------------|-----------|---------------|
| Aggregate scores only (count/logit) | 150 | 200+ |
| Hierarchical Bayes individual utilities | 150 | 300+ |
| Segment comparisons (per segment cell) | 50 | 100+ |
| Latent class segmentation | 300 | 500+ |
| Small subgroup analysis | 30 (interpret with caution) | 75+ |

Larger samples give more precise estimates. For HB estimation, 150 respondents is the practical floor; below that, individual-level shrinkage becomes very strong and individual estimates converge toward the population mean.

### 3.5 Design Types

The module supports three design generation strategies:

| Design Type | Description | When to Use |
|-------------|-------------|-------------|
| **BALANCED** | Ensures each item appears an equal number of times and all item pairs co-occur as evenly as possible. Deterministic algorithm. | **Recommended default** for most studies (8-20 items). Produces reliable, interpretable designs with minimal effort. |
| **OPTIMAL** | Uses D-optimal algorithms (via `AlgDesign` package) to maximise statistical information. Handles complex constraints. | For large item sets (20+) or when you need to impose specific constraints on item co-occurrence. |
| **RANDOM** | Randomly assigns items to tasks. No balance guarantees. | **Testing and debugging only.** Not recommended for production studies. |

### 3.6 Design Versions

A "version" is a distinct set of task assignments. Each respondent is randomly allocated to one version.

- **1 version** is sufficient for small studies (8-12 items, small samples).
- **3 versions** is a good default for studies with 12-20 items.
- **5+ versions** may be needed for 25+ items to maintain pair balance.

More versions improve statistical balance but require larger total samples. If you use 3 versions and need 100 respondents per version, your total sample must be at least 300.

### 3.7 Common Design Mistakes

1. **Too many items for the number of tasks.** If you test 25 items with only 10 tasks of 4 items each, each item appears on average only 1.6 times per respondent. That is not enough for reliable estimation.
2. **Unbalanced designs.** If some items appear much more frequently than others, their utilities are estimated more precisely, making comparisons unfair.
3. **Single version with a large item set.** With 25+ items and one version, achieving positional and pair balance is difficult. Use multiple versions.
4. **No pilot test.** Always pilot your survey with 10-20 respondents to check comprehension, timing, and response patterns.

---

## 4. Configuration Workbook Guide

The module is controlled by a single Excel workbook (.xlsx) containing up to seven sheets. All settings are configured through this workbook -- no R coding is required for standard analyses.

### 4.1 Obtaining the Template

**Option 1: Generate from R**
```r
setwd("path/to/Turas/modules/maxdiff")
source("templates/create_maxdiff_template.R")
```
This creates `templates/maxdiff_config_template.xlsx` with all sheets, instructions, and colour-coded examples.

**Option 2: Copy the pre-built template**
Use the template at: `modules/maxdiff/docs/maxdiff_config_template.xlsx`

### 4.2 Template Colour Coding

- **Yellow cells** = Required -- must be filled in
- **Green cells** = Optional -- has a sensible default
- **Blue cells** = Example data -- replace with your own

### 4.3 Sheet: PROJECT_SETTINGS (Required)

Two-column format (Setting_Name, Setting_Value):

| Setting_Name | Example Value | Required | Description |
|--------------|---------------|----------|-------------|
| `Project_Name` | `BankX_Benefits_2025` | Yes | Unique identifier (no spaces). Used in output filenames |
| `Mode` | `ANALYSIS` | Yes | `DESIGN` or `ANALYSIS` |
| `Raw_Data_File` | `C:\Data\responses.xlsx` | Analysis only | Path to survey data file |
| `Data_File_Sheet` | `Sheet1` | No | Sheet name in data file (default: first sheet) |
| `Design_File` | `C:\Data\design.xlsx` | Analysis only | Path to design file from DESIGN mode |
| `Output_Folder` | `C:\Output\MaxDiff\` | Yes | Where to save all results |
| `Weight_Variable` | `weight` | No | Column name for respondent weights (blank = unweighted) |
| `Respondent_ID_Variable` | `RespID` | Yes | Unique respondent ID column in your data |
| `Filter_Expression` | `Complete==1` | No | R filter expression applied before analysis (blank = no filter) |
| `Seed` | `12345` | No | Random seed for reproducibility (recommended) |

**Path notes:**
- Use **absolute paths** for files outside the Turas folder (e.g., on OneDrive or a shared drive).
- Use **relative paths** for files in the same folder as your config.
- Windows accepts forward slashes (`/`) or double backslashes (`\\`).

### 4.4 Sheet: ITEMS (Required)

Defines all items to be evaluated:

| Column | Required | Description |
|--------|----------|-------------|
| `Item_ID` | Yes | Unique identifier (e.g., `ITEM_01`, `PRICE_LOW`). Must be consistent between design and analysis |
| `Item_Label` | Yes | Full text shown to respondents |
| `Item_Group` | No | Category for grouping in output (e.g., "Price", "Digital", "Service") |
| `Include` | No | `1` = include, `0` = exclude (default: 1). Useful for excluding items post-fielding |
| `Anchor_Item` | No | `1` = use as HB reference item with utility fixed at 0 (default: 0) |
| `Display_Order` | No | Controls the order items appear in output tables |

**Example:**

| Item_ID | Item_Label | Item_Group | Include | Anchor_Item |
|---------|------------|------------|---------|-------------|
| ITEM_01 | Low monthly fees | Price | 1 | 0 |
| ITEM_02 | High savings interest rates | Returns | 1 | 0 |
| ITEM_03 | Mobile app with budgeting tools | Digital | 1 | 0 |
| ITEM_04 | Convenient branch locations | Access | 1 | 1 |

**Tips:**
- Use meaningful Item_IDs (e.g., `FEE_LOW` rather than `I1`).
- Keep Item_IDs identical between design and analysis phases.
- Avoid special characters in Item_IDs. Uppercase with underscores works best.

### 4.5 Sheet: DESIGN_SETTINGS (Required for DESIGN Mode)

| Parameter_Name | Example | Description |
|----------------|---------|-------------|
| `Items_Per_Task` | `4` | Items shown per task. Typically 4 or 5 |
| `Tasks_Per_Respondent` | `12` | Tasks per respondent. See Section 3.3 for guidance |
| `Num_Versions` | `3` | Number of design versions |
| `Design_Type` | `BALANCED` | `BALANCED`, `OPTIMAL`, or `RANDOM` |
| `Max_Item_Repeats` | `5` | Maximum times any single item appears per respondent |
| `Force_Min_Pair_Balance` | `YES` | Ensure all item pairs co-occur as equally as possible |

**Quick reference by item count:**

| Items | Recommended Type | Items/Task | Tasks | Versions |
|-------|------------------|------------|-------|----------|
| 6-10 | BALANCED | 4 | 8-12 | 1 |
| 11-15 | BALANCED | 4-5 | 12-15 | 1-3 |
| 16-25 | OPTIMAL | 5 | 15-20 | 3-5 |
| 26-30 | OPTIMAL | 5-6 | 20-25 | 5+ |

### 4.6 Sheet: SURVEY_MAPPING (Required for ANALYSIS Mode)

Maps your survey column names to what the module expects. Two approaches are available.

#### Approach A: Pattern-Based Mapping (Recommended)

Use column name patterns with `{task}` as a placeholder for the task number:

| Mapping_Type | Value | Description |
|--------------|-------|-------------|
| `Version_Variable` | `Version` | Column holding the design version number |
| `Best_Column_Pattern` | `MaxDiff_T{task}_Best` | Pattern for best-choice columns |
| `Worst_Column_Pattern` | `MaxDiff_T{task}_Worst` | Pattern for worst-choice columns |
| `Best_Value_Type` | `ITEM_POSITION` | What the best-choice values represent |
| `Worst_Value_Type` | `ITEM_POSITION` | What the worst-choice values represent |

If your survey exports columns named `MD_T1_Best`, `MD_T1_Worst`, `MD_T2_Best`, `MD_T2_Worst`, etc., then set:
- `Best_Column_Pattern = MD_T{task}_Best`
- `Worst_Column_Pattern = MD_T{task}_Worst`

#### Approach B: Explicit Field Mapping

List each field individually in a table:

| Field_Type | Field_Name | Task_Number | Notes |
|------------|------------|-------------|-------|
| `VERSION` | `MD_Version` | | Design version column |
| `BEST_CHOICE` | `Q1_Best` | 1 | Best choice for task 1 |
| `WORST_CHOICE` | `Q1_Worst` | 1 | Worst choice for task 1 |
| `BEST_CHOICE` | `Q2_Best` | 2 | Best choice for task 2 |
| `WORST_CHOICE` | `Q2_Worst` | 2 | Worst choice for task 2 |

**Value types:**
- `ITEM_POSITION` -- Values are 1, 2, 3, 4, etc. (position of the chosen item within the task as defined by the design file).
- `ITEM_ID` -- Values are the actual Item_ID strings (e.g., `ITEM_01`).

### 4.7 Sheet: SEGMENT_SETTINGS (Optional)

Define subgroups for segment-level analysis:

| Column | Description |
|--------|-------------|
| `Segment_ID` | Groups segments together (e.g., `GENDER`, `AGE3`) |
| `Segment_Name` | Display name for each level (e.g., "Male", "18-34") |
| `Variable_Name` | Column name in your data file |
| `Variable_Value` | Value to match (numeric or text) |
| `Include` | `1` = include, `0` = exclude |
| `Display_Order` | Order within the segment group |

**Example:**

| Segment_ID | Segment_Name | Variable_Name | Variable_Value | Include | Display_Order |
|------------|--------------|---------------|----------------|---------|---------------|
| GENDER | Male | Gender | 1 | 1 | 1 |
| GENDER | Female | Gender | 2 | 1 | 2 |
| AGE3 | 18-34 | Age_Cat | 1 | 1 | 1 |
| AGE3 | 35-54 | Age_Cat | 2 | 1 | 2 |
| AGE3 | 55+ | Age_Cat | 3 | 1 | 3 |

Multiple rows with the same `Segment_ID` form a single segmentation variable. You can define as many segmentation variables as you need.

### 4.8 Sheet: OUTPUT_SETTINGS (Optional)

Controls what output is generated and how. All settings have sensible defaults.

| Option_Name | Default | Description |
|-------------|---------|-------------|
| `Generate_Count_Scores` | `YES` | Compute Best%, Worst%, Net Score |
| `Generate_Aggregate_Logit` | `YES` | Fit aggregate conditional logit model |
| `Generate_HB_Model` | `YES` | Fit Hierarchical Bayes model |
| `Generate_Segment_Tables` | `YES` | Segment-level analysis |
| `Generate_Charts` | `YES` | Create PNG charts |
| `Generate_HTML_Report` | `YES` | Produce self-contained HTML report |
| `Generate_Simulator` | `YES` | Produce interactive HTML simulator |
| `Generate_TURF` | `YES` | Run TURF portfolio analysis |
| `Score_Rescale_Method` | `0_100` | `RAW`, `0_100`, or `PROBABILITY` |
| `Export_Individual_Utils` | `YES` | Export individual-level utilities sheet |
| `HB_Iterations` | `5000` | MCMC iterations after warmup |
| `HB_Warmup` | `2000` | MCMC warmup iterations |
| `HB_Chains` | `4` | Number of MCMC chains |
| `Min_Respondents_Per_Segment` | `50` | Minimum n to report a segment level |
| `TURF_Max_Items` | `10` | Maximum portfolio size for TURF analysis |
| `TURF_Threshold` | `ABOVE_MEAN` | Appeal threshold method (see Section 8) |
| `Has_Anchor_Question` | `NO` | Whether an external anchor question was asked |
| `Anchor_Variable` | | Column name for anchor responses |
| `Anchor_Threshold` | `0.50` | Proportion threshold for "must-have" classification |
| `Anchor_Format` | `COMMA_SEPARATED` | Format of anchor variable values |

---

## 5. Design Mode

### 5.1 Running Design Mode

1. Set `Mode = DESIGN` in PROJECT_SETTINGS.
2. Complete the ITEMS sheet with all items to be tested.
3. Complete the DESIGN_SETTINGS sheet.
4. Run the module.

```r
run_maxdiff("path/to/config.xlsx")
```

### 5.2 Design Output

The module generates a design Excel file containing:

**DESIGN sheet:**

| Version | Task_Number | Item1_ID | Item2_ID | Item3_ID | Item4_ID |
|---------|-------------|----------|----------|----------|----------|
| 1 | 1 | ITEM_01 | ITEM_04 | ITEM_07 | ITEM_09 |
| 1 | 2 | ITEM_02 | ITEM_03 | ITEM_06 | ITEM_10 |
| ... | ... | ... | ... | ... | ... |

**DESIGN_SUMMARY sheet:**
- Item frequency table (how often each item appears)
- Pair frequency matrix (how often each pair of items co-occurs)
- Position balance statistics
- D-efficiency score

### 5.3 Design Quality Metrics

After generation, review these quality metrics:

| Metric | Good Value | Concern Level | Description |
|--------|------------|---------------|-------------|
| D-efficiency | > 0.90 | < 0.80 | Statistical information efficiency (0-1) |
| Item balance CV | < 0.10 | > 0.15 | Coefficient of variation of item frequencies. Lower = more balanced |
| Pair balance CV | < 0.20 | > 0.30 | CV of pair co-occurrence frequencies. Lower = more balanced |

If D-efficiency is below 0.80, try increasing the number of tasks, adding design versions, or switching from BALANCED to OPTIMAL.

### 5.4 Using the Design in Your Survey Platform

1. **Export the design** to your survey platform. Each version-task combination defines which items to display.
2. **Create a version variable** that randomly assigns each respondent to one version.
3. **For each task**, program your survey to:
   - Display the items specified in the design for that version and task number
   - Randomise item positions within the task (recommended)
   - Collect one best choice and one worst choice
   - Prevent the respondent from choosing the same item for both best and worst
4. **Record** the item position (1-based index within the task) or the Item_ID for each choice. Whichever you use, set the corresponding Value_Type in SURVEY_MAPPING.
5. **Test thoroughly** across desktop and mobile before fielding.

---

## 6. Analysis Mode

### 6.1 Running Analysis Mode

1. Set `Mode = ANALYSIS` in PROJECT_SETTINGS.
2. Ensure you have:
   - The design file from Design mode (or an equivalent file from your survey platform)
   - Survey data exported as Excel or CSV
   - SURVEY_MAPPING completed to match your data columns
3. Run the module.

```r
result <- run_maxdiff("path/to/config.xlsx")
```

### 6.2 Analysis Workflow

The module executes the following steps automatically:

```
STEP 1:  Load configuration
STEP 2:  Load design file
STEP 3:  Load survey data (apply filter if specified)
STEP 4:  Validate data against design
STEP 5:  Reshape data to long format
STEP 6:  Compute count-based scores
STEP 7:  Fit aggregate logit model
STEP 8:  Fit Hierarchical Bayes model (if enabled)
STEP 9:  Compute segment-level scores (if segments defined)
STEP 10: Generate charts (PNG)
STEP 10B: Run TURF analysis (if enabled and HB available)
STEP 10C: Process anchor data (if configured)
STEP 10D: Compute item discrimination metrics
STEP 11: Generate Excel output
STEP 12: Generate HTML report (if enabled)
STEP 13: Generate interactive simulator (if enabled)
```

Progress is printed to the R console at each step. If any non-critical step fails, the module continues with a warning (TRS PARTIAL status) rather than stopping entirely.

### 6.3 Scoring Methods

#### Count-Based Scores

Simple descriptive metrics computed directly from the raw choices:

| Score | Formula | Range | Interpretation |
|-------|---------|-------|----------------|
| Best% | Times chosen best / Times shown | 0-100% | Higher = more preferred |
| Worst% | Times chosen worst / Times shown | 0-100% | Higher = less preferred |
| Net Score | Best% - Worst% | -100 to +100 | Positive = net preferred |
| BW Score | (Best count - Worst count) / Times shown | -1 to +1 | Normalised preference index |

Count scores are always computed first as a baseline. They are easy to interpret and serve as a sanity check before fitting statistical models.

#### Aggregate Conditional Logit

Fits a conditional logit model (via `survival::clogit()`) to estimate population-level utilities on an interval scale.

Key outputs:
- **Logit utilities** -- interval-scale preference scores for each item
- **Standard errors and confidence intervals** -- statistical precision
- **Model fit statistics** -- log-likelihood, R-squared equivalent

Logit utilities represent the average preference structure across all respondents.

#### Hierarchical Bayes (HB)

Estimates **individual-level** utilities for each respondent using Bayesian MCMC sampling. This is the most powerful scoring method.

The model specification:
- Individual utilities are drawn from a multivariate normal population distribution
- Population mean and covariance are estimated simultaneously
- Individual estimates are "shrunk" toward the population mean, reducing noise

If `cmdstanr` is installed and configured, the module uses full Stan-based MCMC sampling. If `cmdstanr` is not available, it falls back to an approximate empirical Bayes method that uses James-Stein shrinkage applied to respondent-level BW scores.

**HB produces:**
- Population-level utility means and standard deviations
- Individual-level utility profiles (one row per respondent, one column per item)
- Convergence diagnostics (R-hat, effective sample size, divergent transitions)

### 6.4 Score Rescaling

After estimation, utilities can be rescaled for easier interpretation:

| Method | Formula | Range | Best For |
|--------|---------|-------|----------|
| `RAW` | No transformation | Varies | Technical analysis, model comparison |
| `0_100` | 100 * (u - min) / (max - min) | 0-100 | Client reporting, charts, presentation |
| `PROBABILITY` | exp(u) / sum(exp(u)) | 0-1 (sum = 1) | Share-of-preference interpretation |

The `0_100` method is recommended for most reporting purposes. The lowest-scoring item receives 0, the highest receives 100, and all others are proportionally placed between.

---

## 7. Understanding the Output

### 7.1 Output Files Overview

After a successful analysis run, the output folder contains:

| File | Description |
|------|-------------|
| `{Project}_MaxDiff_Results.xlsx` | Main Excel results workbook |
| `{Project}_MaxDiff_Results.html` | Self-contained HTML report |
| `{Project}_MaxDiff_Results_simulator.html` | Interactive simulator |
| `{Project}_utility_bar.png` | Horizontal bar chart of rescaled scores |
| `{Project}_best_worst.png` | Diverging bar chart (Best% left, Worst% right) |
| `{Project}_utility_distribution.png` | Violin plot of individual utilities (HB only) |
| `{Project}_segment_*.png` | Segment comparison charts (one per segment variable) |
| `{Project}_log.txt` | Run log with timestamps and diagnostics |

### 7.2 Excel Results Workbook

The Excel workbook contains the following sheets:

#### SUMMARY

- Project name, mode, date, module version
- Total sample size and sample sizes per design version
- Models fitted (count, logit, HB)
- Model fit statistics (log-likelihood, R-squared)
- Warnings and notes from the run

#### ITEM_SCORES

The main results table. One row per item.

| Column | Description |
|--------|-------------|
| Item_ID | Item identifier |
| Item_Label | Full item text |
| Item_Group | Category group |
| Times_Shown | How often this item was displayed across all respondents |
| Times_Best | How often chosen as best |
| Times_Worst | How often chosen as worst |
| Best_Pct | Percentage chosen as best when shown |
| Worst_Pct | Percentage chosen as worst when shown |
| Net_Score | Best% - Worst% |
| Logit_Utility | Utility from aggregate logit model |
| Logit_SE | Standard error of logit utility |
| HB_Utility_Mean | Population mean utility from HB model |
| HB_Utility_SD | Standard deviation of HB utility across respondents |
| Rescaled_Score | Utility on the chosen rescaling (0-100 by default) |
| Rank | Preference rank (1 = most preferred) |

#### SEGMENT_SCORES

Same structure as ITEM_SCORES, with additional columns for Segment_ID, Segment_Name, and segment sample size. One set of rows per segment level.

#### INDIVIDUAL_UTILS

Individual-level utilities from HB estimation (if enabled). One row per respondent, one column per item, plus the Respondent_ID column. This sheet can be merged with other respondent-level data for advanced segmentation or profiling.

#### TURF_RESULTS

Incremental reach table from TURF analysis (if enabled):

| Column | Description |
|--------|-------------|
| Step | Portfolio step (1 = first item added) |
| Item_ID | Item added at this step |
| Item_Label | Full text of item |
| Reach_Pct | Cumulative reach (% of respondents reached) |
| Incremental_Pct | Incremental reach added by this item |
| Frequency | Average number of appealing items in portfolio per respondent |

#### ANCHOR_ANALYSIS

If an anchor question was configured, this sheet shows the proportion of respondents for whom each item exceeds the anchor threshold (the "must-have" percentage).

#### ITEM_DISCRIMINATION

Classification of items by how much their utilities vary across respondents:
- **High discrimination** -- item polarises respondents (some love it, some hate it)
- **Low discrimination** -- respondents agree about this item

#### MODEL_DIAGNOSTICS

- Logit model fit statistics (log-likelihood, AIC, R-squared)
- HB convergence diagnostics: R-hat (should be < 1.05), effective sample size (ESS), divergent transitions
- Design quality metrics
- Sample composition and completion statistics

#### Run_Status

TRS run status summary showing the overall outcome (PASS, PARTIAL, or REFUSED) with any warnings or errors logged during the run.

### 7.3 PNG Charts

All charts are saved at 300 DPI, suitable for reports and presentations:

| Chart | What It Shows |
|-------|---------------|
| **Utility bar chart** | Horizontal bars of rescaled scores (0-100), sorted by preference |
| **Best-Worst diverging chart** | Items ranked by Net Score with Best% bars extending right and Worst% bars extending left |
| **Utility distribution** (HB only) | Violin or box plots showing the distribution of individual-level utilities per item. Reveals heterogeneity -- wide violins indicate polarising items |
| **Segment comparison charts** | Side-by-side bar charts comparing rescaled scores across segment levels |

---

## 8. TURF Analysis

### 8.1 What Is TURF?

TURF stands for **Total Unduplicated Reach and Frequency**. It answers the question: "If I can only offer K items from my list, which K items should I pick to appeal to the maximum number of people?"

TURF is used for portfolio and assortment decisions -- for example:
- Which 5 product features should we highlight in our marketing?
- Which 3 benefits should appear on the packaging?
- Which 8 menu items maximise the number of customers who find at least one item appealing?

### 8.2 How It Works

1. **Classify appeal.** For each respondent, determine which items they find "appealing" based on a threshold method (see below).
2. **Greedy forward selection.** Start with the single item that reaches the most respondents. Then add the item that reaches the most *additional* respondents (those not already reached). Repeat until the portfolio reaches the desired size.
3. **Report reach curve.** At each step, record the cumulative percentage of respondents reached.

### 8.3 Threshold Methods

The threshold method determines how "appealing" is defined for each respondent:

| Method | How It Works | Best For |
|--------|-------------|----------|
| `ABOVE_MEAN` | An item is appealing if its utility is above the respondent's average utility across all items | General-purpose default. Works well for most studies |
| `TOP_3` | The respondent's top 3 items are classified as appealing | When you want a fixed number of "winners" per person |
| `TOP_K` | The respondent's top K items are appealing (K configurable) | Flexible version of TOP_3 |
| `ABOVE_ZERO` | An item is appealing if its utility is positive | Only meaningful if utilities are centred (anchored MaxDiff) |

Set the threshold method via `TURF_Threshold` in OUTPUT_SETTINGS. The default is `ABOVE_MEAN`.

### 8.4 Interpreting the Reach Curve

The reach curve shows cumulative reach (y-axis) against portfolio size (x-axis). Key things to look for:

- **Steep initial slope** -- the first few items reach a large proportion of respondents.
- **Flattening** -- at some point, adding more items yields diminishing returns. This is the practical maximum portfolio size.
- **The "elbow"** -- the point where the curve transitions from steep to flat. This is often the optimal portfolio size for cost-benefit analysis.

For example, if 3 items reach 75% and 5 items reach 85%, the 4th and 5th items each contribute only about 5% incremental reach. Whether that additional reach justifies the cost of two more items is a business decision.

### 8.5 Practical Application

TURF is ideal for:
- **Feature selection** -- which features to build into a product
- **Message testing** -- which messages to include in a campaign
- **Assortment planning** -- which products to stock in a limited display
- **Menu design** -- which items to include on a limited menu

TURF requires individual-level utilities, which means HB estimation must be enabled (`Generate_HB_Model = YES`).

---

## 9. Anchored MaxDiff

### 9.1 What Is Anchored MaxDiff?

Standard MaxDiff produces **relative** preference scores. Item A is preferred over Item B, but you cannot tell whether respondents actually *want* either item in an absolute sense. The top-ranked item might still be unappealing to most respondents.

Anchored MaxDiff adds an external question that establishes an absolute threshold. After the MaxDiff tasks, respondents are asked a follow-up question such as:

> "Which of the following items would you consider a **must-have**? Select all that apply."

This "anchor" question allows the module to estimate the proportion of respondents who find each item acceptable in absolute terms, not just in relative comparison.

### 9.2 How to Add an Anchor Question to Your Survey

1. **After all MaxDiff tasks**, add a question that presents the full list of items (or a key subset).
2. **Ask respondents** to select which items they consider essential, must-have, very important, or similar.
3. **Record responses** as one of the following formats:
   - **Comma-separated Item_IDs** in a single column (e.g., `ITEM_01,ITEM_03,ITEM_07`)
   - **Binary columns** (one per item), where 1 = selected
4. **Configure** in OUTPUT_SETTINGS:
   - `Has_Anchor_Question = YES`
   - `Anchor_Variable = <column name>`
   - `Anchor_Format = COMMA_SEPARATED` (or adjust to match your data)
   - `Anchor_Threshold = 0.50` (the proportion threshold for classifying an item as "must-have")

### 9.3 Interpreting Must-Have Percentages

The anchor analysis output shows, for each item, the percentage of respondents who selected it in the anchor question. Combined with the MaxDiff preference scores, this produces a two-dimensional view:

- **High preference + high must-have** -- truly important items that respondents both prefer and consider essential
- **High preference + low must-have** -- nice-to-have items that respondents prefer but do not consider essential
- **Low preference + high must-have** -- table-stakes items that respondents expect but do not differentiate on
- **Low preference + low must-have** -- low-priority items

This two-dimensional view is much more actionable than relative preference scores alone.

---

## 10. Working with Segments

### 10.1 Defining Segments

Segments are defined in the SEGMENT_SETTINGS sheet of the configuration workbook (see Section 4.7). You can define multiple segmentation variables (e.g., gender, age, region, customer type) and the module analyses each independently.

### 10.2 What the Module Computes per Segment

For each segment level, the module computes:
- Full count-based scores (Best%, Worst%, Net Score)
- Aggregate logit utilities (if logit is enabled)
- Segment sample size
- Comparison charts

### 10.3 Minimum Sample Size

Set `Min_Respondents_Per_Segment` in OUTPUT_SETTINGS (default: 50) to suppress reporting for segment levels with insufficient sample sizes. Segments below this threshold are excluded from output with a warning.

### 10.4 Interpreting Segment Differences

When comparing segments:

1. **Focus on rank-order differences**, not absolute utility values. Items that rank differently across segments are the most actionable findings.
2. **Consider practical significance**, not just statistical significance. A difference of 2 points on a 0-100 scale is rarely actionable, even if statistically significant with a large sample.
3. **Always report sample sizes** alongside segment results. Small segments (n < 75) produce noisy estimates.
4. **Watch for items that polarise segments** -- an item that ranks in the top 3 for one segment and bottom 3 for another is a key differentiator.
5. **Do not over-segment.** Splitting a sample of 400 into 8 segment cells of 50 each produces unreliable estimates. Stick to 2-4 segment levels per variable.

---

## 11. HTML Report Interpretation Guide

The HTML report is a self-contained file that opens in any modern web browser. It uses tab-based navigation to organise the results.

### 11.1 Report Tabs

| Tab | Contents |
|-----|----------|
| **Summary** | Project overview, sample size, methods used, key metrics, callout boxes highlighting top and bottom items |
| **Preference Scores** | Main results: preference share chart (horizontal bars), detailed utility chart, and preference scores table with all metrics |
| **Item Analysis** | Count-based analysis: Best-Worst diverging bar chart, count scores table, item discrimination classification |
| **Portfolio (TURF)** | Reach curve chart and incremental reach table (only appears if TURF is enabled) |
| **Segments** | Segment comparison table (only appears if segments are defined) |
| **Diagnostics** | Model fit statistics, HB convergence diagnostics, design quality metrics |
| **About** | Module version, configuration summary, methodology notes |

### 11.2 Reading the Summary Tab

The Summary tab provides at-a-glance findings:
- **Badge bar** at the top shows sample size, number of items, method used, and overall model quality.
- **Key callouts** highlight the most and least preferred items.
- **Mini chart** shows the overall preference ranking.

### 11.3 Reading the Preference Scores Tab

Two chart views are available:
- **Preference shares** -- items displayed as horizontal bars representing their share of total preference (sums to 100%). This is the "market simulation" view.
- **Utility detail** -- items displayed by their rescaled utility score (0-100). This shows the absolute preference structure.

The preference scores table below the charts includes all computed metrics. Sort by any column by clicking the column header.

### 11.4 Understanding Callouts

The report generates automatic callout boxes to highlight noteworthy findings:
- **Top items callout** -- items in the top tier of preference.
- **Bottom items callout** -- items in the bottom tier.
- **Close competition callout** -- when two or more items have very similar scores, the report notes that the difference may not be meaningful.
- **Polarising items callout** -- items with high HB standard deviation, indicating respondents disagree about them.

### 11.5 When to Be Cautious About Small Differences

- Items within **2-3 points** on the 0-100 scale are effectively tied. Do not over-interpret small ranking differences.
- Items within **1 percentage point** of preference share are not meaningfully different.
- Always check **confidence intervals** when available. Overlapping intervals suggest the difference is not statistically significant.

---

## 12. Simulator Guide

The interactive simulator is a self-contained HTML file that lets you explore MaxDiff results through "what if" scenarios. It runs entirely in the browser -- no server or R session required after generation.

### 12.1 Simulator Tabs

| Tab | Purpose |
|-----|---------|
| **Overview** | Study summary statistics and a mini preference ranking chart |
| **Preference Shares** | Core simulation tab: toggle items on/off, filter by segment, see how shares redistribute |
| **Head-to-Head** | Compare up to 5 items directly -- shows pairwise win probabilities |
| **Portfolio (TURF)** | Interactive portfolio builder -- add and remove items, see reach in real time |
| **Diagnostics** | Sample sizes, data quality indicators, method details |
| **Pinned Views** | Save and compare multiple scenarios side by side |
| **About** | Version information and methodology notes |

### 12.2 Preference Shares Tab

This is the main simulation workspace:

1. **Toggle items.** Click an item to hide it from the simulation. Shares of remaining items are recalculated automatically (using the MNL model). This simulates removing a feature or product from the market.
2. **Segment filter.** Use the dropdown to view shares for a specific segment (e.g., "Males only" or "18-34"). Shares recalculate using only that segment's individual utilities.
3. **Chart and table.** The horizontal bar chart updates in real time. The table below shows exact share values.

**Important:** Preference shares are *not* market shares. They represent the probability of each item being the most preferred choice within the set currently shown. If you remove the top item, its share redistributes to the remaining items proportionally.

### 12.3 Head-to-Head Tab

Compare items directly:

1. **Add items** to comparison slots (up to 5).
2. **View pairwise win probabilities** -- for each pair, the simulator shows the probability that Item A is preferred over Item B, based on individual-level utilities.
3. **Use for** competitor analysis, feature comparisons, or identifying items that are close substitutes.

### 12.4 Portfolio (TURF) Tab

Build portfolios interactively:

1. **Add items** to your portfolio one at a time.
2. **See reach update** in real time -- the percentage of respondents for whom at least one portfolio item is appealing.
3. **See frequency** -- the average number of appealing items per respondent within the portfolio.
4. **Compare** different portfolio compositions to find the combination that maximises reach.

### 12.5 Pinned Views

Pin any scenario (specific item selections, segment filter, portfolio composition) to save it. Switch to the Pinned Views tab to compare multiple saved scenarios side by side.

### 12.6 Exporting Results

The simulator includes export functionality. Depending on the tab, you can export chart images, data tables, or scenario summaries for use in presentations or reports.

---

## 13. R Package Dependencies

### 13.1 Required Packages

These packages must be installed for the module to function:

| Package | Minimum Version | Purpose |
|---------|----------------|---------|
| `openxlsx` | >= 4.2.5 | Reading and writing Excel files (no Java dependency) |
| `survival` | >= 3.5-0 | Conditional logit model estimation (`clogit`) |
| `ggplot2` | >= 3.4.0 | Chart generation (PNG output) |

Install with:
```r
install.packages(c("openxlsx", "survival", "ggplot2"))
```

### 13.2 Optional Packages

These packages enable advanced features but are not required:

| Package | Minimum Version | Purpose | Feature Enabled |
|---------|----------------|---------|-----------------|
| `cmdstanr` | >= 0.7.0 | Stan interface for MCMC sampling | Full Hierarchical Bayes estimation |
| `AlgDesign` | >= 1.2.0 | D-optimal experimental design algorithms | OPTIMAL design type |
| `base64enc` | >= 0.1-3 | Base64 encoding for images | Logo embedding in HTML reports |
| `jsonlite` | >= 1.8.0 | JSON serialisation | Data embedding in simulator |
| `data.table` | >= 1.14.0 | Fast data manipulation | Performance improvement for large datasets |

### 13.3 Installing cmdstanr

`cmdstanr` is not on CRAN. It requires a C++ compiler toolchain and the CmdStan software.

**Step 1: Install the R package**
```r
install.packages("cmdstanr",
  repos = c("https://mc-stan.org/r-packages/", getOption("repos")))
```

**Step 2: Check the C++ toolchain**
```r
library(cmdstanr)
check_cmdstan_toolchain()
```

Platform-specific requirements:
- **Windows:** Requires Rtools. Download from https://cran.r-project.org/bin/windows/Rtools/
- **macOS:** Requires Xcode Command Line Tools. Run `xcode-select --install` in Terminal.
- **Linux:** Requires `g++` and `make`. Install via your package manager.

**Step 3: Install CmdStan**
```r
install_cmdstan()
```

**Step 4: Verify**
```r
cmdstan_path()     # Should return the CmdStan installation path
cmdstan_version()  # Should return a version number
```

If cmdstanr is not installed, the module automatically falls back to the approximate empirical Bayes method. This is faster but produces less accurate individual-level estimates.

---

## 14. Troubleshooting

### 14.1 Configuration and File Errors

| Symptom | Cause | Solution |
|---------|-------|----------|
| "Config file not found" | Invalid file path | Check the path. Use an absolute path if the file is outside the Turas folder |
| "Required sheet missing" | Missing Excel sheet in config | Add the required sheet (PROJECT_SETTINGS, ITEMS, etc.) to your workbook |
| "Raw_Data_File not found" | Invalid data file path | Use an absolute path to your data file. Check for typos |
| "Design file format error" | Wrong design format | Ensure the design file has a DESIGN sheet with Version, Task_Number, and Item columns |
| Excel output errors | Write permissions or file locked | Close any open Excel file at the output path. Check folder write permissions |

### 14.2 Data Validation Errors

| Symptom | Cause | Solution |
|---------|-------|----------|
| "Invalid Item_ID in data" | Item IDs in data do not match config | Check Item_IDs are identical between ITEMS sheet and your data. Case matters |
| "VERSION column not found" | Mapping error | Check `Version_Variable` in SURVEY_MAPPING matches a column in your data |
| "Respondent chose same item for best and worst" | Survey logic error | Review survey programming. Filter affected respondents if needed |
| "Item not shown in task" | Choice does not match design | Verify survey was programmed correctly against the design file |
| "Missing values in choice columns" | Incomplete responses | Filter out incomplete respondents or check survey completion logic |

### 14.3 HB Model Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| HB model will not converge (R-hat > 1.05) | Insufficient iterations, problematic data, or too many items | Increase `HB_Iterations` (try 10000). Check data quality. Consider reducing item count |
| Low effective sample size (ESS < 400) | Insufficient iterations or poor mixing | Increase `HB_Iterations` and `HB_Warmup`. Check for data issues |
| Divergent transitions | Posterior geometry issues | Increase `adapt_delta`. Check for highly correlated or redundant items |
| HB takes very long (>30 minutes) | Large sample or many items | This is normal for large studies. Reduce chains to 2 for faster (but less reliable) estimation. Or use approximate HB |
| "cmdstanr not available" | Package not installed | Install cmdstanr (see Section 13.3) or set `Generate_HB_Model = NO` to use logit only |
| Stan model compilation failed | Toolchain issue | Run `cmdstanr::check_cmdstan_toolchain()` and fix any issues |

### 14.4 Design Generation Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| Design generation fails | Too many items per task relative to total items, or impossible constraints | Reduce `Items_Per_Task`. Ensure Items_Per_Task < total items |
| Very low D-efficiency | Suboptimal design parameters | Increase `Tasks_Per_Respondent`. Try OPTIMAL design type. Add more versions |
| Unbalanced item frequencies | Too few tasks for the number of items | Follow the guidance in Section 3.3 for minimum task counts |

### 14.5 HTML Report and Simulator Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| HTML report is blank | No results to display (all models failed) | Check the console output for error messages. Ensure at least count scores were computed |
| HTML report missing TURF tab | TURF not enabled or HB not available | Set `Generate_TURF = YES` and `Generate_HB_Model = YES` |
| Simulator missing | Not enabled | Set `Generate_Simulator = YES` in OUTPUT_SETTINGS |
| Simulator shows no data | No utility estimates available | Ensure logit or HB model ran successfully |

### 14.6 Low Sample Size Warnings

If the module reports sample size warnings:
- **Total n < 150**: Aggregate estimates are acceptable but individual-level HB estimates will be heavily shrunk. Consider increasing sample.
- **Segment n < 50**: Segment is suppressed from output. Increase the sample or combine segment levels.
- **Per-version n < 30**: Very few respondents per design version. Reduce the number of versions or increase total sample.

### 14.7 Getting Help

1. Check the run log: `{Output_Folder}/{Project_Name}_log.txt`
2. Review error messages in the R console -- they include specific TRS error codes and remediation steps.
3. Check the Diagnostics tab in the HTML report for model-level issues.
4. Contact the development team with:
   - The error message and TRS error code
   - Your configuration file
   - The log file
   - R version (`R.version.string`) and package versions (`sessionInfo()`)

---

## 15. Best Practices

### 15.1 Study Design

**Do:**
- Use 12-20 items for most studies (sweet spot).
- Use 4 items per task as the default.
- Plan for 3-4 times as many tasks as items divided by items per task.
- Pre-test item wording with 5-10 respondents.
- Keep items comparable in length and specificity.
- Randomise item positions within tasks.
- Set a random seed for reproducibility.
- Pilot the full survey before fielding.

**Do not:**
- Test more than 30 items without a screening stage.
- Use fewer than 8 tasks per respondent.
- Mix fundamentally different categories (features vs. price levels) in the same MaxDiff.
- Use double-barrelled items ("Fast and reliable internet").
- Skip the pilot test.

### 15.2 Data Collection

**Do:**
- Test across desktop and mobile devices.
- Prevent respondents from choosing the same item as both best and worst.
- Include attention checks or timing measures.
- Monitor completion rates and speeders during fielding.
- Validate that the version distribution is approximately even.

**Do not:**
- Place other questions between MaxDiff tasks.
- Allow respondents to skip tasks.
- Change item wording after fielding has begun.

### 15.3 Configuration

**Do:**
- Use meaningful Item_IDs (e.g., `FEE_LOW` not `I1`).
- Keep Item_IDs consistent between design and analysis.
- Set a seed for reproducibility.
- Use absolute file paths for data files on shared or cloud drives.
- Save the original template for reference.

**Do not:**
- Use spaces or special characters in Item_IDs.
- Change Item_IDs between design and analysis phases.
- Delete the design file after survey programming.

### 15.4 Analysis and Reporting

**Do:**
- Review count scores first as a sanity check.
- Compare logit and HB results -- they should produce similar rankings.
- Check HB convergence diagnostics (R-hat < 1.05, ESS > 400).
- Use 0-100 rescaled scores for client reporting.
- Report confidence intervals alongside point estimates.
- Note sample sizes on all segment comparisons.
- Include a methodology appendix in your report.

**Do not:**
- Report small differences (< 3 points on 0-100 scale) as meaningful.
- Over-interpret individual HB utilities with very small samples (n < 150).
- Treat preference shares as market shares.
- Present a utility of 2.0 vs 1.0 as "twice as preferred" -- utilities are interval-scale, not ratio-scale.
- Over-segment (splitting 400 respondents into 10 segment cells is unreliable).

### 15.5 Reproducibility

Always archive:
- Configuration Excel file
- Raw data file
- Design file
- All output files (Excel, HTML, charts)
- Log file
- R version and package versions (`sessionInfo()`)
- The random seed used

---

## 16. Glossary

| Term | Definition |
|------|------------|
| **Anchor Item** | Reference item whose utility is fixed at 0 in the HB model for identification. One item must be anchored to set the scale |
| **Anchored MaxDiff** | A MaxDiff study supplemented with an external question that establishes an absolute "acceptable" threshold, allowing absolute (not just relative) interpretation |
| **Appeal** | In TURF analysis, whether a respondent finds an item appealing based on the chosen threshold method |
| **Best-Worst Scaling** | Alternative name for MaxDiff |
| **BW Score** | (Times chosen Best - Times chosen Worst) / Times Shown. A normalised measure of preference ranging from -1 to +1 |
| **Conditional Logit** | A statistical model for discrete choice data. Estimates interval-scale utilities from best/worst choices. Implemented via `survival::clogit()` |
| **D-efficiency** | A measure of experimental design quality, ranging from 0 to 1. Higher values indicate more statistically efficient designs |
| **Design File** | An Excel file containing the task assignments for each version: which items appear in each task |
| **Design Version** | One of several sets of task assignments. Each respondent is randomly allocated to one version. Multiple versions improve statistical balance |
| **Divergent Transitions** | A diagnostic warning from MCMC sampling indicating the sampler encountered problematic regions of the posterior. Should be zero for reliable results |
| **Empirical Bayes** | The approximate HB method used when cmdstanr is not available. Applies James-Stein shrinkage to respondent-level BW scores |
| **ESS (Effective Sample Size)** | A measure of MCMC sampling efficiency. Should be > 400 for reliable posterior summaries |
| **Hierarchical Bayes (HB)** | A Bayesian estimation method that estimates individual-level utilities by partially pooling information across respondents. Produces more stable individual estimates than respondent-level analysis alone |
| **IIA (Independence of Irrelevant Alternatives)** | An assumption of the MNL model: the relative preference between two items is not affected by the presence or absence of other items. Violated when items are close substitutes |
| **Item** | An attribute, feature, benefit, message, or option being evaluated in the MaxDiff study |
| **Item_ID** | A unique identifier string for an item. Must be consistent across the design file, survey data, and configuration workbook |
| **Logit Utility** | The preference score estimated by the conditional logit model. Utilities are on an interval scale: differences are meaningful but ratios are not |
| **MaxDiff** | Maximum Difference Scaling. A survey technique where respondents choose the best and worst items from subsets |
| **MCMC** | Markov Chain Monte Carlo. The sampling algorithm used for HB estimation. Draws samples from the posterior distribution of utilities |
| **MNL (Multinomial Logit)** | The statistical model underlying preference share simulation. Converts utilities to choice probabilities via the softmax function |
| **Net Score** | Best% minus Worst%. A simple summary measure ranging from -100 to +100 |
| **Preference Share** | The probability of an item being chosen as best from the full set, computed via the MNL model. Shares sum to 100% across all items |
| **Reach** | In TURF analysis, the percentage of respondents for whom at least one item in a portfolio is appealing |
| **Rescaling** | Transforming raw utilities to a more interpretable scale: 0-100 (min-max), probability (softmax), or no change (raw) |
| **R-hat** | A convergence diagnostic for MCMC sampling. Compares within-chain and between-chain variance. Should be < 1.05 (ideally < 1.01) for reliable results |
| **Satisficing** | When respondents adopt simplifying heuristics (e.g., always picking the first item) instead of genuinely evaluating each task. Increases with respondent fatigue |
| **Shrinkage** | In HB estimation, the process of pulling individual estimates toward the population mean. Stronger shrinkage occurs with fewer observations per respondent or more respondent-level noise |
| **Task** | One choice scenario in a MaxDiff study. Shows K items and asks the respondent to pick the best and worst |
| **TRS (Turas Refusal System)** | The structured error handling system used across all Turas modules. Errors return structured refusal objects instead of using `stop()` |
| **TURF** | Total Unduplicated Reach and Frequency. An analysis technique for finding the combination of items that maximises population reach |
| **Utility** | A latent preference score for an item, estimated from the choice data. Higher utility = stronger preference |
| **Version** | See Design Version |
| **Warmup** | The initial phase of MCMC sampling where the sampler adapts its step size and mass matrix. Warmup draws are discarded and not used for inference |

---

## Appendix A: Quick Reference Card

### Workflow Checklist

**DESIGN Mode:**
- [ ] Define items in ITEMS sheet
- [ ] Set Mode = DESIGN
- [ ] Configure DESIGN_SETTINGS
- [ ] Run module
- [ ] Review design quality metrics (D-efficiency > 0.90)
- [ ] Use design file to program survey

**ANALYSIS Mode:**
- [ ] Prepare design file and data file
- [ ] Define same items as design
- [ ] Set Mode = ANALYSIS
- [ ] Set file paths in PROJECT_SETTINGS
- [ ] Configure SURVEY_MAPPING
- [ ] Add SEGMENT_SETTINGS (optional)
- [ ] Configure OUTPUT_SETTINGS (optional)
- [ ] Run module
- [ ] Review count scores as sanity check
- [ ] Check HB convergence diagnostics
- [ ] Review output Excel, HTML report, and simulator

### Minimum Sample Sizes

| Purpose | Minimum N |
|---------|-----------|
| Aggregate estimates (count/logit) | 150 |
| HB individual utilities | 150 |
| Stable HB estimates | 300+ |
| Per segment cell | 50 |
| Latent class segmentation | 300 |

### Recommended Study Parameters

| Items | Items/Task | Tasks | Versions |
|-------|------------|-------|----------|
| 6-10 | 4 | 8-12 | 1 |
| 11-15 | 4-5 | 12-15 | 1-3 |
| 16-25 | 5 | 15-20 | 3-5 |
| 26-30 | 5-6 | 20-25 | 5+ |

---

## Appendix B: Example Configuration

A complete working example with all features enabled is available in:
```
examples/maxdiff/demo_showcase/
```

Run the full demo:
```r
source("examples/maxdiff/demo_showcase/run_demo.R")
```

This generates:
- `Demo_MaxDiff_Config.xlsx` -- complete configuration with all features enabled
- `demo_design.xlsx` -- balanced 3-version design for 12 items
- `demo_data.csv` -- simulated survey responses (n = 200, with weights and anchor column)
- `output/` -- HTML report (with embedded simulator) and Excel workbook

---

*Turas MaxDiff Module v11.1 -- The Research LampPost (Pty) Ltd*
