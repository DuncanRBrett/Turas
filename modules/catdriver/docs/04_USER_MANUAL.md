---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Categorical Key Driver Module — User Manual

**Version:** 12.0 **Last Updated:** 3 March 2026 **Target Audience:**
Market Researchers, Data Analysts, Survey Managers

------------------------------------------------------------------------

## Table of Contents

1.  [What This Module Does](#1-what-this-module-does)
2.  [Before You Start — Know Your
    Data](#2-before-you-start--know-your-data)
3.  [Deciding Which Variables to
    Include](#3-deciding-which-variables-to-include)
4.  [When and How to Collapse
    Categories](#4-when-and-how-to-collapse-categories)
5.  [Setting Up Your Configuration
    File](#5-setting-up-your-configuration-file)
6.  [Running the Analysis from
    Turas](#6-running-the-analysis-from-turas)
7.  [Running Multiple Outcomes (Unified
    Report)](#7-running-multiple-outcomes-unified-report)
8.  [Running Subgroup Comparisons](#8-running-subgroup-comparisons)
9.  [Understanding Your Output](#9-understanding-your-output)
10. [Interpreting the HTML Report](#10-interpreting-the-html-report)
11. [Troubleshooting](#11-troubleshooting)
12. [Decision Flowcharts](#12-decision-flowcharts)
13. [Complete Worked Example](#13-complete-worked-example)
14. [Quick Reference Tables](#14-quick-reference-tables)

------------------------------------------------------------------------

## 1. What This Module Does

The Categorical Key Driver module answers a single question: **"Which
factors most strongly drive a categorical outcome?"**

It uses logistic regression to identify which survey variables (the
"drivers") best predict a categorical outcome variable, and quantifies
the strength and direction of each driver's influence.

### When to Use CatDriver

| Your Outcome Is... | Example | CatDriver Handles It As |
|----|----|----|
| Yes / No | Customer churned? | **Binary** logistic regression |
| Ordered categories | Satisfaction: Low / Medium / High | **Ordinal** logistic regression |
| Unordered categories | Preferred brand: A / B / C / D | **Multinomial** logistic regression |

### When NOT to Use CatDriver

-   **Continuous outcomes** (e.g., spend amount, NPS score 0-10 treated
    as numeric) — use the standard Key Driver module instead
-   **Time-series data** — use the Tracker module
-   **Continuous numeric predictors** — CatDriver requires categorical
    predictors. If you have continuous variables (age, income), bin them
    into categories first (e.g., "18-24", "25-34") in your data file
    before running the analysis

------------------------------------------------------------------------

## 2. Before You Start — Know Your Data

Before configuring anything, answer these questions about your data:

### Question 1: What is your outcome variable?

This is the thing you want to explain. It must be **categorical** (not a
number on a continuous scale).

**Good outcomes:** - Satisfaction (Low / Neutral / High) - Purchased
(Yes / No) - Brand choice (Brand A / Brand B / Brand C)

**Bad outcomes:** - NPS score (0-10) — this is continuous, not
categorical - Spend amount (\$0-\$500) — this is continuous

If your outcome is a scale (1-5 agreement, 0-10 NPS), you must
**collapse it into categories** in your data file first. For example,
NPS 0-6 = "Detractor", 7-8 = "Passive", 9-10 = "Promoter".

### Question 2: Is your outcome ordered or unordered?

This determines which statistical model is used:

| If categories have a natural order... | Use `outcome_type = ordinal` |
|----|----|
| Low \< Medium \< High | ordinal |
| Disagree \< Neutral \< Agree | ordinal |
| If categories have NO natural order... | Use `outcome_type = binary` or `multinomial` |
| Brand A, Brand B, Brand C (no ranking) | multinomial |
| Yes / No | binary |

**You must declare this explicitly.** CatDriver will refuse to run if
you don't set `outcome_type`. This is deliberate — guessing the wrong
model type produces misleading results.

### Question 3: What are your driver variables?

These are the factors you think might influence the outcome.
Typically: - Demographics (age group, gender, region) - Behaviours
(product used, channel preference) - Attitudes (rating categories,
agreement levels) - Experience factors (tenure band, service tier)

### Question 4: How clean is your data?

Open your data file and check: - **Missing values**: How many? Which
variables? - **Category labels**: Are they clean text ("High", "Low") or
messy codes ("1", "2", "0")? - **Rare categories**: Does any category
have fewer than 10 respondents? - **Total sample size**: You need at
least 50 complete cases (100+ recommended)

------------------------------------------------------------------------

## 3. Deciding Which Variables to Include

This is the most important decision you will make. Including the wrong
variables produces misleading results. Excluding the right ones misses
important insights.

### The Variable Selection Decision Framework

For each potential driver variable, work through this checklist:

#### Test 1: Is it theoretically relevant?

Ask: "Could this variable plausibly influence the outcome?"

-   **Include**: Age group as a driver of brand preference (plausible —
    different ages prefer different brands)
-   **Exclude**: Respondent ID (no causal relationship)
-   **Exclude**: Variables that are consequences of the outcome, not
    causes (e.g., "number of complaints" should not drive "satisfaction"
    if complaints happen after the satisfaction rating)

#### Test 2: Is it categorical?

CatDriver only accepts categorical predictors. If the variable is
continuous:

-   **Option A**: Bin it into categories in your data file first (e.g.,
    age → age groups)
-   **Option B**: Exclude it from CatDriver and use the standard Key
    Driver module

#### Test 3: How many categories does it have?

| Categories | Recommendation |
|----|----|
| 2 | Include as binary driver |
| 3-7 | Include — ideal range |
| 8-15 | Consider collapsing similar categories (see Section 4) |
| 16+ | Strongly consider collapsing or excluding — too many categories destabilises the model |

#### Test 4: Are the categories populated?

Check the count per category. If any category has fewer than 10
respondents:

-   The model may produce unreliable estimates for that category
-   CatDriver will warn you about "rare levels"
-   Consider collapsing that category with a similar one (see Section 4)

#### Test 5: Is there excessive missing data?

| Missing % | Recommendation |
|----|----|
| 0-10% | No action needed |
| 10-30% | Use `missing_as_level` strategy — missingness itself may be informative |
| 30-50% | Consider excluding the variable — too much missing data weakens analysis |
| 50%+ | Exclude the variable — it will degrade your model |

#### Test 6: Is it redundant with another variable?

If two variables measure essentially the same thing (e.g., "service
quality rating" and "would recommend service"), including both causes
**multicollinearity** — the model cannot separate their effects. Choose
the more important one.

CatDriver will flag high multicollinearity (VIF \> 5) in diagnostics,
but it is better to prevent it than diagnose it.

### Variables to Always Exclude

-   **Respondent ID / row number** — no analytical value
-   **Open-ended text responses** — not categorical
-   **Date/time stamps** — not categorical (unless binned into periods)
-   **The outcome variable's close variants** — e.g., don't use "overall
    satisfaction (5-point)" to predict "overall satisfaction (3-point)"
    collapsed from the same question
-   **Post-outcome variables** — things that happened after the outcome
    was measured

### How Many Drivers is Too Many?

| Sample Size | Maximum Recommended Drivers |
|-------------|-----------------------------|
| 50-100      | 3-4 drivers                 |
| 100-200     | 4-6 drivers                 |
| 200-500     | 6-10 drivers                |
| 500+        | 10-15 drivers               |

The rule of thumb: you need **at least 10 respondents per category per
driver** for stable estimates. If you have 200 respondents and 5 drivers
with 4 categories each, that is 5 x 4 = 20 parameters — requiring at
least 200 cases (cutting it close).

------------------------------------------------------------------------

## 4. When and How to Collapse Categories

"Collapsing" means combining two or more categories into one. This is
the most common data preparation task for CatDriver.

### When You MUST Collapse (In Your Data File)

These situations require you to edit your data file before running
CatDriver:

1.  **Continuous variables that need binning**: Age (23, 45, 67) → Age
    Group ("18-34", "35-54", "55+")
2.  **Scale variables treated as categorical**: 1-10 scale → "Low
    (1-3)", "Medium (4-6)", "High (7-10)"
3.  **Outcome variable recoding**: 5-point satisfaction → 3-point
    (Dissatisfied, Neutral, Satisfied)
4.  **Messy or inconsistent labels**: "yes", "Yes", "YES", "Y" → all
    become "Yes"
5.  **Numeric codes that need labels**: 0, 1, 2 → "Unemployed",
    "Part-time", "Full-time"

**Why in the data file?** Because CatDriver takes your data as-is. It
treats whatever values it finds in each column as the categories. If
your data says "0" and "1", CatDriver sees two categories called "0" and
"1" — not "No" and "Yes".

### When CatDriver Can Collapse For You (Automatic)

CatDriver has a **rare level policy** that can automatically handle
categories with very few respondents. You configure this per-driver in
the Driver_Settings sheet:

| Policy | What Happens | When to Use |
|----|----|----|
| `warn_only` (default) | Warns but keeps all categories | When you want full control |
| `collapse_to_other` | Merges rare categories into "Other" | When rare categories aren't analytically important |
| `drop_level` | Removes rows with rare categories | When rare categories would distort results |
| `error` | Stops the analysis entirely | When every category must have sufficient data |

A category is "rare" when its count falls below `rare_level_threshold`
(default: 10).

**Example**: Employment Field has categories: Finance (80), Marketing
(60), HR (45), Legal (8), Research (7).

-   With `warn_only`: All categories kept, warning issued for Legal and
    Research
-   With `collapse_to_other`: Legal and Research become "Other" (n=15)
-   With `drop_level`: 15 respondents in Legal/Research are removed from
    analysis

### When You Should Manually Collapse (Judgement Call)

These require your domain knowledge — CatDriver cannot make these
decisions:

#### Scenario A: Too many categories

**Problem**: "Job Title" has 25 categories, many with fewer than 10
respondents.

**Solution**: Group into broader categories in your data file: - "Junior
Developer", "Senior Developer", "Lead Developer" → "Developer" -
"Marketing Analyst", "Marketing Manager", "CMO" → "Marketing"

**Decision rule**: Combine categories that are substantively similar AND
where you don't need to distinguish between them for your research
question.

#### Scenario B: Meaningful but rare categories

**Problem**: Region has "Western Cape" (120), "Gauteng" (95), "KZN"
(60), "Eastern Cape" (15), "Free State" (8), "Limpopo" (2).

**Options**: 1. **Collapse geographically**: Combine "Eastern Cape",
"Free State", "Limpopo" → "Other Provinces" 2. **Collapse by size**:
Keep top 3, merge rest into "Other" 3. **Set `collapse_to_other`** in
Driver_Settings and let CatDriver auto-merge categories below threshold

**Best approach**: Option 1 or 2 — do it manually in your data file with
a grouping that makes substantive sense.

#### Scenario C: Ordinal scale with too many points

**Problem**: Satisfaction measured on 7-point scale (1-7). Categories
"1" and "2" have very few respondents.

**Options**: 1. Collapse to 3 groups: Low (1-3), Neutral (4), High (5-7)
2. Collapse to 5 groups: Very Low (1-2), Low (3), Neutral (4), High (5),
Very High (6-7)

**Decision rule**: Choose the grouping that (a) makes substantive sense
and (b) gives each group at least 10-20 respondents.

### The "Do I Need to Collapse?" Decision Tree

```         
Is the variable continuous or a long numeric scale?
├── YES → Collapse into categories in your data file
│         (CatDriver cannot do this for you)
└── NO (already categorical)
    │
    How many categories?
    ├── 2-7 categories
    │   │
    │   Any category < 10 respondents?
    │   ├── NO → Use as-is. No collapsing needed.
    │   └── YES → Set rare_level_policy = "collapse_to_other"
    │             OR manually merge in data file
    │
    ├── 8-15 categories
    │   │
    │   Can you group into meaningful broader categories?
    │   ├── YES → Collapse in data file to 4-7 groups
    │   └── NO → Set rare_level_policy = "collapse_to_other"
    │             and rare_level_threshold = 15
    │
    └── 16+ categories
        │
        Collapse in data file. Too many categories
        will destabilise the model regardless of
        rare level policy.
```

### Important: CatDriver Never Collapses Your Outcome Variable

The outcome variable is always used exactly as provided. If your outcome
has rare categories, you must fix this in your data file. For example,
if satisfaction has 5 levels but "Very Dissatisfied" only has 3
respondents, collapse it with "Dissatisfied" before running the
analysis.

### Recommended Workflow: Collapsing When You Also Use Other Modules

If the same dataset is used by other Turas modules (e.g., the Tabs
module for crosstabs), you need a clean strategy for collapsing:

**Rule: Always create a new column. Never modify the original.**

1.  **Add a derived column** to your data file with a clear naming
    convention:

    | Original Column | Derived Column | Transformation |
    |----|----|----|
    | `satisfaction` (1-10) | `satisfaction_3pt` | 1-3 → Low, 4-6 → Neutral, 7-10 → High |
    | `job_title` (25 levels) | `job_function` | Grouped into 6 broad functions |
    | `age` (continuous) | `age_group` | Binned into 4 age bands |

2.  **Point your CatDriver config at the derived column**. In the
    Variables sheet, list `satisfaction_3pt` as the Outcome (or Driver),
    not `satisfaction`.

3.  **Leave the original column for other modules**. The Tabs module
    continues to crosstab `satisfaction` (the full 10-point scale). Your
    original data stays intact.

4.  **If you want the derived column in Tabs output too**, add it to the
    Tabs survey structure as a new question. This is optional — only do
    it if stakeholders need the grouped version in crosstabs.

**Why this approach?**

-   Non-destructive: the original data is never modified
-   Each module uses the version that makes sense for its purpose
-   You can iterate on the collapsing (try 3-group vs 5-group) without
    breaking existing configs
-   The Tabs module's survey structure only needs updating if you want
    the collapsed version to appear in crosstab output

**Example workflow for a satisfaction survey:**

```         
Data file columns:
  satisfaction (1-10 scale)          → Tabs: full crosstab
  satisfaction_3pt (Low/Neutral/High) → CatDriver: ordinal outcome
  satisfaction_binary (Sat/Unsat)     → CatDriver: binary outcome

CatDriver config A: outcome = satisfaction_3pt (ordinal)
CatDriver config B: outcome = satisfaction_binary (binary)
Tabs config: uses satisfaction (original 10-point)
```

This pattern works especially well with the multi-config GUI (Section 7)
— you can run both CatDriver configs together and generate a unified
report comparing the ordinal and binary models.

------------------------------------------------------------------------

## 5. Setting Up Your Configuration File

The configuration file is an Excel workbook (.xlsx) with 3 sheets. You
can copy the template from
`modules/catdriver/docs/templates/CatDriver_Config_Template.xlsx`.

### Sheet 1: Settings

Two columns: `Setting` and `Value`.

#### Required Settings

| Setting | Description | Example |
|----|----|----|
| `data_file` | Path to your data file (CSV or Excel) | `my_survey_data.csv` |
| `output_file` | Where to save results | `results/my_analysis.xlsx` |
| `outcome_type` | **Must be one of:** `binary`, `ordinal`, `multinomial` | `ordinal` |

**File paths** can be relative (to the config file location) or
absolute. Relative paths are recommended for portability.

**`outcome_type` is mandatory.** CatDriver will refuse to run without
it. There is no "auto" mode — you must understand your data and declare
the correct model type. See Section 2 for guidance.

#### Recommended Settings

| Setting | Default | Description |
|----|----|----|
| `analysis_name` | "Key Driver Analysis" | Title for reports |
| `html_report` | TRUE | Generate interactive HTML report |
| `bootstrap_ci` | FALSE | Calculate bootstrap confidence intervals (slower but more robust) |
| `bootstrap_reps` | 200 | Number of bootstrap resamples |
| `probability_lifts` | TRUE | Calculate probability lifts (see Section 9) |
| `brand_colour` | "#323367" | Primary colour for HTML report charts |
| `accent_colour` | "#CC9900" | Accent colour for HTML report |

#### Optional Settings

| Setting | Default | Description |
|----|----|----|
| `min_sample_size` | 30 | Refuse if fewer complete cases |
| `confidence_level` | 0.95 | Confidence interval level |
| `missing_threshold` | 50 | Warn if any variable exceeds this % missing |
| `detailed_output` | TRUE | Include all sheets in Excel output |
| `rare_level_threshold` | 10 | Category count below which = "rare" |
| `rare_cell_threshold` | 5 | Cross-tab cell count below which = "sparse" |
| `rare_level_policy` | "warn_only" | Global policy for rare categories |
| `reference_category` | (first alphabetically) | Outcome reference level |
| `researcher_logo_path` | (none) | Path to logo image for HTML report header |

#### Multinomial-Only Settings

If `outcome_type = multinomial`, you must also set:

| Setting | Required | Description |
|----|----|----|
| `multinomial_mode` | **Yes** | One of: `baseline_category`, `per_outcome`, `all_pairwise`, `one_vs_all` |
| `target_outcome_level` | Only if mode = `one_vs_all` | Which outcome level to focus on |

### Sheet 2: Variables

Four columns. Every row defines one variable in the analysis.

| Column | Required | Description |
|----|----|----|
| `VariableName` | Yes | **Exact** column name from your data file (case-sensitive) |
| `Type` | Yes | `Outcome`, `Driver`, or `Weight` |
| `Label` | Yes | Human-readable name for reports |
| `Order` | No | Semicolon-separated category ordering (low to high) |

**Rules:** - Exactly **1** row with Type = `Outcome` - At least **1**
row with Type = `Driver` - At most **1** row with Type = `Weight` -
`VariableName` must match the column header in your data file exactly

**When to use the Order column:** - **Always** for ordinal outcomes:
`Low;Neutral;High` - **Always** for ordinal drivers: `D;C;B;A` -
**Optional** for binary/nominal — leave blank

**Example:**

| VariableName     | Type    | Label                   | Order            |
|------------------|---------|-------------------------|------------------|
| satisfaction     | Outcome | Employment Satisfaction | Low;Neutral;High |
| grade            | Driver  | Academic Grade          | D;C;B;A          |
| campus           | Driver  | Campus Location         |                  |
| course_type      | Driver  | Course Type             |                  |
| employment_field | Driver  | Employment Field        |                  |
| survey_weight    | Weight  | Survey Weight           |                  |

### Sheet 3: Driver_Settings

This sheet gives you fine-grained control over how each driver is
treated. **Every driver listed in the Variables sheet should have a row
here.**

| Column | Required | Description |
|----|----|----|
| `driver` | Yes | Must match a `VariableName` with Type = `Driver` |
| `type` | Yes | `categorical`, `ordinal`, `binary`, or `control_only` |
| `levels_order` | If type = ordinal | Semicolon-separated ordering |
| `reference_level` | No | Which category is the baseline for comparisons |
| `missing_strategy` | No | `missing_as_level` (default), `drop_row`, or `error_if_missing` |
| `rare_level_policy` | No | Per-driver override: `warn_only`, `collapse_to_other`, `drop_level`, `error` |

**Driver type explanations:**

| Type | When to Use | Example |
|----|----|----|
| `categorical` | Unordered categories | Campus (Cape Town, Durban, Online) |
| `ordinal` | Ordered categories — **requires** `levels_order` | Grade (D \< C \< B \< A) |
| `binary` | Exactly 2 categories | Gender (Male, Female) |
| `control_only` | Included in model but NOT reported as a driver | Demographics you want to control for but not interpret |

**`control_only` explained:** Sometimes you want to adjust for a
variable (e.g., age) without reporting it as a driver. Setting
`type = control_only` includes it in the regression model (so it doesn't
confound other drivers) but excludes it from the importance ranking,
odds ratio tables, and all report sections. Use this for demographic
controls.

**Example:**

| driver | type | levels_order | reference_level | missing_strategy | rare_level_policy |
|----|----|----|----|----|----|
| grade | ordinal | D;C;B;A | D | missing_as_level | warn_only |
| campus | categorical |  |  | missing_as_level | warn_only |
| course_type | categorical |  |  | missing_as_level | collapse_to_other |
| employment_field | categorical |  |  | missing_as_level | warn_only |

### Choosing the Reference Level

The **reference level** is the baseline for all comparisons. Every odds
ratio is expressed as "X compared to the reference". Choose a reference
that makes your results easy to interpret:

| Good Reference Choices    | Why                                  |
|---------------------------|--------------------------------------|
| The most common category  | "Compared to the typical respondent" |
| The lowest/first category | "Compared to the baseline"           |
| A control group           | "Compared to the control"            |
| The "default" option      | "Compared to the standard"           |

If you don't specify a reference, CatDriver uses the **first category
alphabetically** — which may not be meaningful. Always set this
explicitly.

------------------------------------------------------------------------

## 6. Running a Single Analysis from Turas

### Step 1: Launch Turas

``` r
setwd("/path/to/Turas")
source("launch_turas.R")
```

This opens the Turas Shiny application.

### Step 2: Click "Launch Categorical Key Driver"

This opens the CatDriver GUI panel.

### Step 3: Select Your Project Folder

Click **"Browse for Project Folder"** and navigate to the folder
containing: - Your data file (CSV or Excel) - Your config file(s)
(Excel)

The GUI will auto-detect config files in the folder. It looks for files
matching patterns like `catdriver*config`, `cat*driver*config`,
`config*.xlsx`.

If your config file isn't auto-detected, use the manual file browser.

### Step 4: Select Your Config File

Detected config files appear as **checkboxes**. For a single analysis,
tick the one config you want to run. (For multi-config runs, see Section
7.)

A **Select All / Deselect All** toggle is available above the checkboxes
when multiple configs are detected.

### Step 5: Click "Run Categorical Key Driver Analysis"

The analysis runs. Progress is shown in the console panel:

```         
------------------------------------------------------------
  CATEGORICAL KEY DRIVER ANALYSIS
------------------------------------------------------------
  Analysis: Employment Satisfaction Analysis
  Model: Ordinal Logistic Regression

  Step 1/7: Loading configuration...          OK
  Step 2/7: Loading data...                   OK (200 rows)
  Step 3/7: Validating...                     OK
  Step 4/7: Handling missing data...          OK (195 complete)
  Step 5/7: Applying rare level policy...     OK (0 collapsed)
  Step 6/7: Preprocessing...                  OK
  Step 7/7: Fitting model...                  OK (converged)

  ...calculating importance...                OK
  ...calculating odds ratios...               OK
  ...calculating probability lifts...         OK
  ...generating Excel output...               OK
  ...generating HTML report...                OK

  STATUS: PASS
  Output: employment_satisfaction_results.xlsx
  Report: employment_satisfaction_results.html
------------------------------------------------------------
```

### Step 6: Review Output

Two files are generated: 1. **Excel workbook** — detailed tabular
results (at the `output_file` path) 2. **HTML report** — interactive
visual report (same path, `.html` extension)

Open the HTML report in any web browser for the best experience.

### What If It Fails?

CatDriver uses a structured refusal system. If something is wrong, you
will see a clear error:

```         
┌─── TURAS ERROR ───────────────────────────────────────┐
│ Code: CFG_OUTCOME_TYPE_REQUIRED
│ Message: outcome_type setting is required
│ Fix: Add outcome_type = binary, ordinal, or multinomial
│      to the Settings sheet of your config file
└───────────────────────────────────────────────────────┘
```

Every error includes a code, a plain-English message, and a specific fix
instruction. See Section 11 for common errors and their solutions.

------------------------------------------------------------------------

## 7. Running Multiple Outcomes (Unified Report)

If you have multiple outcome variables in the same dataset (e.g.,
"Overall Satisfaction", "Would Recommend", "Intent to Return"), you can
run them as separate analyses and combine them into a single unified
HTML report with comparison features — all from the GUI.

### How It Works

1.  Create a **separate config file** for each outcome variable
2.  Each config points to the **same data file** but specifies a
    different outcome
3.  Select all the configs you want in the GUI
4.  Fill in the report settings (title, branding, logos)
5.  Click Run — CatDriver runs each analysis sequentially and generates
    a unified report automatically

### Step-by-Step: Setting Up Multiple Configs

**Config 1: `satisfaction_config.xlsx`**

Settings: `outcome_type = ordinal`, outcome = satisfaction Variables:
satisfaction (Outcome), grade (Driver), campus (Driver), ...

**Config 2: `recommend_config.xlsx`**

Settings: `outcome_type = binary`, outcome = would_recommend Variables:
would_recommend (Outcome), grade (Driver), campus (Driver), ...

**Config 3: `return_config.xlsx`**

Settings: `outcome_type = binary`, outcome = intent_to_return Variables:
intent_to_return (Outcome), grade (Driver), campus (Driver), ...

Place all config files in the same project folder alongside your data
file.

### Step-by-Step: Running from the GUI

#### 1. Select Your Project Folder

Same as Section 6. Browse to the folder containing your data file and
all config files.

#### 2. Select Multiple Configs

Tick the checkboxes for the configs you want to include. You don't have
to select all of them — just the ones you want in this analysis run.

Use **Select All / Deselect All** to quickly toggle all configs.

#### 3. Fill In Report Settings

When you select **2 or more configs**, a **Report Settings** panel
appears automatically. This controls the unified report's appearance:

| Setting | Purpose | Default |
|----|----|----|
| **Report Title** | Title shown in the unified report header | "Categorical Key Driver Analysis" |
| **Client Name** | Optional "for X" line below the title (e.g., "for Acme Corp") | *(empty)* |
| **Brand Colour** | Primary colour for charts and header (hex) | #323367 |
| **Accent Colour** | Secondary colour for highlights and accents (hex) | #CC9900 |
| **Researcher Logo** | Your company/researcher logo (uploaded image) | *(none)* |
| **Client Logo** | Client's logo, shown alongside researcher logo (uploaded image) | *(none)* |

Colour swatches update live as you type hex values, so you can preview
the look before running.

**Note:** These settings apply to the unified report only. They override
any `brand_colour` or `accent_colour` values in individual config files.
Individual HTML reports (generated per config) still use the colours
from their own config.

#### 4. Click "Run N Analyses + Generate Unified Report"

The button label updates automatically to show how many configs will run
(e.g., "Run 3 Analyses + Generate Unified Report").

**What happens behind the scenes:**

1.  Each config runs sequentially — you see standard progress output for
    each analysis in the console
2.  Each config generates its own Excel workbook and individual HTML
    report, as normal
3.  If a config fails, the error is logged and the next config continues
    — one failure does not abort the batch
4.  After all configs complete, the unified report is generated from the
    successful analyses
5.  A summary shows how many succeeded and how many failed

```         
  ============================
  Multi-Config Run Complete
  ============================
  3/3 configs completed successfully

  Individual outputs:
    satisfaction_results.xlsx + .html
    recommend_results.xlsx + .html
    return_results.xlsx + .html

  Unified report:
    CatDriver_Unified_20260303.html
  ============================
```

#### 5. Review the Unified Report

Open `CatDriver_Unified_YYYYMMDD.html` in any web browser. The file is
saved in the same directory as your config files.

### What the Unified Report Shows

-   **Overview tab**: Comparison cards for each outcome, driver
    importance matrix across all outcomes, cross-outcome insights
-   **Individual tabs**: Full analysis for each outcome (importance,
    patterns, probability lifts, odds ratios, diagnostics)
-   **Pinned Views tab**: Any sections you pin for export or
    presentation

### Partial Failures

If some configs fail but at least 2 succeed, the unified report is still
generated from the successful analyses. Failed configs are listed in the
console output with their error details.

If only 1 config succeeds, no unified report is generated (you need at
least 2 analyses for a meaningful comparison). The individual Excel and
HTML report for the successful config is still available.

### Advanced: Running from an R Script

For automated pipelines or CI/CD workflows, you can also run the unified
report from an R script instead of the GUI:

``` r
setwd("/path/to/Turas")

# Source the modules
source("modules/catdriver/R/00_main.R")
assign(".catdriver_lib_dir",
       file.path(getwd(), "modules/catdriver/lib"),
       envir = globalenv())
source("modules/catdriver/lib/html_report/99_html_report_main.R")

# Run each analysis
result1 <- run_categorical_keydriver("project/satisfaction_config.xlsx")
result2 <- run_categorical_keydriver("project/recommend_config.xlsx")
result3 <- run_categorical_keydriver("project/return_config.xlsx")

# Generate unified report
unified <- generate_catdriver_unified_report(
  analyses = list(
    "Satisfaction" = list(results = result1$result,
                          config = result1$config),
    "Recommend"    = list(results = result2$result,
                          config = result2$config),
    "Return"       = list(results = result3$result,
                          config = result3$config)
  ),
  output_path = "project/output/unified_analysis.html",
  report_title = "Multi-Outcome Key Driver Analysis",
  brand_colour = "#323367",
  accent_colour = "#CC9900",
  client_name = "Acme Corp",
  researcher_logo_path = "assets/researcher_logo.png",
  client_logo_path = "assets/client_logo.png",
  company_name = "The Research Lamppost"
)
```

------------------------------------------------------------------------

## 8. Running Subgroup Comparisons

### When to Use Subgroup Analysis

Use subgroup comparison when you suspect that **different segments of
your audience are driven by different factors**. Common scenarios:

-   "Do younger and older customers churn for different reasons?"
-   "Are the drivers of satisfaction different across regions?"
-   "Does brand preference work differently for high-value vs low-value
    customers?"

### Setting Up a Subgroup Analysis

**Step 1:** Choose your subgroup variable — a column in your data that
defines the groups (e.g., `age_group`, `region`, `customer_tier`).

**Important constraints:** - The subgroup variable must **not** be the
outcome variable - The subgroup variable must **not** be listed as a
driver in the Variables sheet - The variable must have at least 2
distinct non-missing values - Each group should ideally have 30+
observations (configurable via `subgroup_min_n`)

If your desired subgroup variable is currently a driver, remove it from
the Variables sheet first. A variable cannot be both a predictor and a
grouping variable — it would have no variation within each group.

**Step 2:** Add subgroup settings to your config file's **Settings**
sheet:

| Setting                | Value     | Notes                                     |
|------------------------|-----------|-------------------------------------------|
| subgroup_var           | age_group | Column name in your data                  |
| subgroup_min_n         | 30        | Minimum observations per group (default)  |
| subgroup_include_total | TRUE      | Include full-dataset analysis as baseline |

**Step 3:** Run the analysis as normal:

``` r
results <- run_categorical_keydriver("my_config.xlsx")
```

Or via the GUI: select your config, expand **Advanced Options**, and
type the subgroup variable name.

### What Happens Behind the Scenes

1.  The full dataset is analysed first (the "Total" result) — this is
    identical to a standard non-subgroup analysis and ensures backward
    compatibility
2.  The data is split by the subgroup variable into separate datasets
3.  The same analysis pipeline (Steps 4-10) runs independently on each
    subgroup
4.  Results are compared using importance rankings, odds ratios, and
    model fit statistics
5.  Drivers are classified as Universal, Segment-Specific, or Mixed

If a subgroup model fails (e.g., too few observations, convergence
issues), that group is marked as PARTIAL but does not prevent other
groups from being analysed.

### Understanding Subgroup Output

**Excel Output** — Three additional sheets:

| Sheet | Content |
|----|----|
| Subgroup Summary | Side-by-side importance ranks with classification (Universal / Segment-Specific / Mixed) |
| Subgroup OR Compare | Odds ratios per group, notable differences highlighted in red |
| Subgroup Model Fit | Per-group n, R², AIC, convergence status |

**HTML Report** — A dedicated "Subgroups" section containing: - Overview
cards showing each group's sample size, R², and top driver - Grouped
horizontal bar chart comparing importance percentages across groups -
Classification table showing which drivers are universal vs
segment-specific - Auto-generated management insights

### Tips for Subgroup Analysis

1.  **Start with the Total**: Always check the overall (Total) analysis
    first to understand the baseline
2.  **Watch for small groups**: Groups with fewer than 30-50
    observations may produce unreliable results. Check the Model Fit
    sheet for warnings
3.  **Don't over-interpret Mixed drivers**: A driver classified as
    "Mixed" simply means it doesn't clearly fit Universal or
    Segment-Specific patterns. It may still be important
4.  **Use with bootstrap**: If your data has unequal group sizes,
    consider enabling `bootstrap_ci = TRUE` for more robust uncertainty
    estimates per subgroup
5.  **Report Universal drivers first**: When presenting to management,
    lead with Universal drivers (important everywhere), then highlight
    Segment-Specific findings as actionable targeting opportunities

------------------------------------------------------------------------

## 9. Understanding Your Output

### Excel Workbook Sheets

| Sheet | What It Contains | Who It Is For |
|----|----|----|
| **Executive Summary** | Plain-English findings, top drivers, key insights | Stakeholders, non-statisticians |
| **Importance Summary** | Ranked drivers with importance %, chi-square, p-values, effect sizes | Analysts |
| **Factor Patterns** | Category-by-outcome crosstabs with odds ratios and CIs | Detailed analysis |
| **Model Summary** | Fit statistics (R-squared, AIC, LR test) | Quality assurance |
| **Odds Ratios** | Full table of every comparison with CIs | Statistical review |
| **Probability Lift** | Predicted probability changes per driver level | Intuitive effect sizes |
| **Diagnostics** | Missing data, rare cells, convergence, multicollinearity | Troubleshooting |

### HTML Report Sections

The interactive HTML report contains these sections:

#### Executive Summary

Auto-generated plain-English findings. Highlights dominant drivers,
dose-response patterns, extreme effects, and model quality notes.

#### Driver Importance

Horizontal bar chart showing each driver's relative contribution. Ranked
from most to least important. Filter chips let you show All, Top 3, Top
5, Top 8, or Significant only.

#### Factor Patterns

Tabbed view (one tab per driver). Each tab shows: - Stacked bar chart of
outcome distribution by category - Table with category counts,
percentages, outcome distribution, odds ratios

#### Probability Lifts

**New in v11.** Shows how each driver level changes the predicted
probability of the outcome compared to the reference category.

This is the most intuitive effect size metric. While odds ratios tell
you "3x more likely" (which people misinterpret), probability lifts tell
you "12 percentage points higher probability" — which is directly
understandable.

Tabbed view per driver with a diverging bar chart (positive lifts go
right in brand colour, negative go left in red) and a detail table.

**Reading probability lifts:**

| Metric | Meaning |
|----|----|
| Predicted Probability | Mean probability of the outcome for respondents in this category |
| Reference Probability | Mean probability for the reference category |
| Lift (pp) | Difference in percentage points (positive = higher than reference) |

**Example**: Grade A has predicted probability 0.75, reference (Grade D)
has 0.50. Lift = +25 pp. This means Grade A respondents are 25
percentage points more likely to report high satisfaction.

#### Odds Ratios

Forest plot showing every comparison with confidence intervals.
Off-scale values (very large ORs) are shown with diamond markers and
arrow notation.

Filter chips let you show/hide individual drivers.

#### Model Diagnostics

-   **Sample information**: Total N, complete cases, missing data
    summary
-   **Model fit statistics**: McFadden R-squared, AIC, Likelihood Ratio
    test — each in a card with plain-English explanation
-   **Warnings**: Any data quality issues

------------------------------------------------------------------------

## 10. Interpreting the HTML Report

### How to Read the Model Fit Cards

#### McFadden R-squared

Tells you what proportion of outcome variation is explained by the
drivers.

| R-squared | Quality   | What It Means                                |
|-----------|-----------|----------------------------------------------|
| 0.4+      | Excellent | Drivers explain most of the variation        |
| 0.2-0.4   | Good      | Strong explanatory model                     |
| 0.1-0.2   | Moderate  | Drivers matter but unmeasured factors exist  |
| \< 0.1    | Limited   | Important drivers are missing from the model |

**Note**: McFadden R-squared is always lower than standard R-squared. A
value of 0.25 in logistic regression is considered very good.

A low R-squared does NOT mean the model is wrong. It means the outcome
is influenced by factors not in your analysis. This is common in survey
data.

#### AIC (Akaike Information Criterion)

**AIC has no absolute good/bad threshold.** The number itself (e.g.,
442) means nothing in isolation. AIC is only useful when comparing two
or more models on the same data — the model with the lower AIC fits
better.

#### Likelihood Ratio Test

Answers: "Do the drivers collectively predict the outcome better than
chance alone?"

-   **Significant (p \< 0.05)**: Yes — the drivers matter. The model is
    better than guessing.
-   **Not significant (p \>= 0.05)**: No — the drivers don't
    collectively improve prediction. Consider different variables.

### How to Read Odds Ratios

| OR Value  | Plain English                       |
|-----------|-------------------------------------|
| OR = 1.0  | No difference from reference        |
| OR = 2.0  | 2x the odds compared to reference   |
| OR = 0.5  | Half the odds compared to reference |
| OR = 5.0+ | Very strong positive effect         |
| OR \< 0.2 | Very strong negative effect         |

**Common misinterpretation**: OR = 2 does NOT mean "twice as likely". It
means "twice the odds". These are only the same when the outcome is rare
(\<10%). For common outcomes, use probability lifts instead — they show
the actual probability change.

### How to Read Probability Lifts

| Lift (pp) | Interpretation |
|----|----|
| +25 pp | Strong positive: 25 percentage points more likely than reference |
| +10 pp | Moderate positive |
| +3 pp | Modest positive |
| -5 pp | Modest negative |
| -15 pp | Strong negative: 15 percentage points less likely |

Probability lifts are the most intuitive metric for non-statistical
audiences. They answer: "If a respondent is in category X instead of the
reference, how much does their probability of the outcome change?"

------------------------------------------------------------------------

## 11. Troubleshooting

### Error: "outcome_type setting is required"

**Code**: `CFG_OUTCOME_TYPE_REQUIRED`

**Cause**: You haven't set `outcome_type` in the Settings sheet, or you
set it to "auto".

**Fix**: Add `outcome_type` to your Settings sheet with value `binary`,
`ordinal`, or `multinomial`. See Section 2 for guidance.

### Error: "Driver_Settings sheet missing"

**Code**: `CFG_DRIVER_SETTINGS_MISSING`

**Cause**: Your config file doesn't have a Driver_Settings sheet.

**Fix**: Add a Driver_Settings sheet with at least `driver` and `type`
columns. Every driver variable needs a row.

### Error: "Ordinal driver requires levels_order"

**Code**: `CFG_ORDINAL_NO_ORDER`

**Cause**: You set a driver's type to `ordinal` but didn't provide
`levels_order`.

**Fix**: Add a `levels_order` column to Driver_Settings with
semicolon-separated ordering (e.g., `Low;Medium;High`).

### Error: "Variable not found in data"

**Code**: `DATA_VARIABLE_NOT_FOUND`

**Cause**: A `VariableName` in your Variables sheet doesn't match any
column in the data file.

**Fix**: Check spelling (case-sensitive) and leading/trailing spaces.
Open the data file and verify the exact column header.

### Error: "Insufficient complete cases"

**Code**: `DATA_INSUFFICIENT_N`

**Cause**: After removing rows with missing data, fewer cases remain
than `min_sample_size`.

**Fix**: Either (a) use `missing_as_level` strategy for drivers with
high missing rates, (b) remove drivers with excessive missing data, or
(c) lower `min_sample_size` (not recommended below 30).

### Warning: "Model did not converge"

**Cause**: Too many parameters relative to sample size, or extreme data
patterns.

**Fix**: Reduce the number of drivers, collapse rare categories, or
increase sample size. Check for drivers where one category perfectly
predicts the outcome (separation).

### Warning: "Small cells detected"

**Cause**: Some driver-category × outcome-category combinations have
fewer than 5 respondents.

**Impact**: Wide confidence intervals, potentially unstable odds ratios
for those categories.

**Fix**: Collapse the affected categories in your data file, or set
`rare_level_policy = collapse_to_other` for the affected driver.

### Warning: "High multicollinearity"

**Cause**: Two or more drivers are highly correlated (VIF \> 5).

**Fix**: Remove one of the correlated drivers. Choose the one that is
less important to your research question.

### Partial Status (PARTIAL)

If the output shows `Status: PARTIAL`, the analysis completed but with
caveats. The `degraded_reasons` field lists what went wrong. Common
reasons:

-   Rare levels were collapsed
-   Fallback model engine was used
-   Convergence was marginal
-   Multicollinearity detected

Results marked PARTIAL should be interpreted with extra caution.

------------------------------------------------------------------------

## 12. Decision Flowcharts

### Choosing Your Outcome Type

```         
How many categories does your outcome have?

├── Exactly 2 (e.g., Yes/No)
│   └── outcome_type = binary
│
├── 3 or more
│   │
│   Do the categories have a natural order?
│   │
│   ├── YES (e.g., Low < Medium < High)
│   │   └── outcome_type = ordinal
│   │       (set Order column: Low;Medium;High)
│   │
│   └── NO (e.g., Brand A, Brand B, Brand C)
│       └── outcome_type = multinomial
│           (also set multinomial_mode)
```

### Choosing Missing Data Strategy

```         
For each driver variable:

What % of values are missing?

├── 0-5% missing
│   └── missing_strategy = drop_row
│       (minimal data loss)
│
├── 5-30% missing
│   │
│   Could the missingness itself be meaningful?
│   (e.g., people who skip "income" question
│    might systematically differ)
│   │
│   ├── YES → missing_strategy = missing_as_level
│   │         (creates "Missing / Not answered" category)
│   │
│   └── NO  → missing_strategy = drop_row
│
├── 30-50% missing
│   │
│   Is this variable critical to your research?
│   ├── YES → missing_strategy = missing_as_level
│   │         (but interpret with caution)
│   └── NO  → Remove variable from analysis entirely
│
└── 50%+ missing
    └── Remove variable from analysis
        (too much missing data to be useful)
```

### Include or Exclude a Variable?

```         
Potential driver variable:

1. Is it theoretically plausible as a driver?
   ├── NO  → EXCLUDE
   └── YES ↓

2. Is it categorical (or can you bin it)?
   ├── NO  → EXCLUDE (use Key Driver module for continuous)
   └── YES ↓

3. How many categories?
   ├── 16+ → COLLAPSE in data file, then re-evaluate
   └── 2-15 ↓

4. What % is missing?
   ├── 50%+ → EXCLUDE
   └── <50% ↓

5. Is it redundant with another driver?
   ├── YES → EXCLUDE the less important one
   └── NO  ↓

6. Does it have enough respondents per category?
   ├── Many categories < 10 → COLLAPSE or set rare_level_policy
   └── All categories >= 10 ↓

7. INCLUDE as a driver
```

------------------------------------------------------------------------

## 13. Complete Worked Example

This walks through a real analysis using the included example data.

### The Data

File: `modules/catdriver/examples/basic/employment_satisfaction.csv`

200 respondents. Columns: - `satisfaction` — Employment satisfaction
(Low, Neutral, High) - `grade` — Academic grade (A, B, C, D) - `campus`
— Campus (Cape Town, Durban, Online) - `course_type` — Degree type
(BCom, BEng, BSocSci, LLB) - `employment_field` — Job field (Finance,
HR, Marketing, Operations, Technology) - `years_experience` — Years of
experience (numeric 1-10) - `survey_weight` — Survey weight

### Step 1: Assess the Data

| Variable | Categories | Missing | Notes |
|----|----|----|----|
| satisfaction | 3 (Low, Neutral, High) | 0% | Outcome — ordinal |
| grade | 4 (A, B, C, D) | 0% | Natural ordering D \< C \< B \< A |
| campus | 3 (Cape Town, Durban, Online) | 0% | Unordered |
| course_type | 4 (BCom, BEng, BSocSci, LLB) | 0% | Unordered |
| employment_field | 5 (Finance, HR, Marketing, Operations, Technology) | 0% | Unordered |
| years_experience | Numeric (1-10) | 0% | **Cannot use directly** — continuous |
| survey_weight | Numeric | 0% | Weight variable |

### Step 2: Make Decisions

-   **outcome_type**: `ordinal` (Low \< Neutral \< High)
-   **years_experience**: Exclude — it is continuous. We could bin it
    into categories (1-3, 4-6, 7-10) in the data file, but for this
    example we leave it out.
-   **All other variables**: Include as drivers
-   **grade**: Ordinal (D \< C \< B \< A)
-   **campus, course_type, employment_field**: Categorical
-   **survey_weight**: Include as weight variable

### Step 3: Create the Config File

See `modules/catdriver/examples/basic/catdriver_config.xlsx` for the
actual file.

**Settings:**

| Setting           | Value                                |
|-------------------|--------------------------------------|
| analysis_name     | Employment Satisfaction Analysis     |
| data_file         | employment_satisfaction.csv          |
| output_file       | employment_satisfaction_results.xlsx |
| outcome_type      | ordinal                              |
| min_sample_size   | 30                                   |
| confidence_level  | 0.95                                 |
| missing_threshold | 50                                   |
| detailed_output   | TRUE                                 |
| bootstrap_ci      | TRUE                                 |
| bootstrap_reps    | 200                                  |

**Variables:**

| VariableName     | Type    | Label                   | Order            |
|------------------|---------|-------------------------|------------------|
| satisfaction     | Outcome | Employment Satisfaction | Low;Neutral;High |
| grade            | Driver  | Academic Grade          | D;C;B;A          |
| campus           | Driver  | Campus Location         |                  |
| course_type      | Driver  | Course Type             |                  |
| employment_field | Driver  | Employment Field        |                  |

**Driver_Settings:**

| driver | type | levels_order | reference_level | missing_strategy | rare_level_policy |
|----|----|----|----|----|----|
| grade | ordinal | D;C;B;A | D | missing_as_level | warn_only |
| campus | categorical |  |  | missing_as_level | warn_only |
| course_type | categorical |  |  | missing_as_level | warn_only |
| employment_field | categorical |  |  | missing_as_level | warn_only |

### Step 4: Run from Turas

1.  Launch Turas: `source("launch_turas.R")`
2.  Click "Launch Categorical Key Driver"
3.  Browse to `modules/catdriver/examples/basic/`
4.  Tick the checkbox for `catdriver_config.xlsx`
5.  Click "Run Categorical Key Driver Analysis"

### Step 5: Review Results

The analysis produces: - `employment_satisfaction_results.xlsx` — Excel
workbook with 7 sheets - `employment_satisfaction_results.html` —
Interactive HTML report

Open the HTML report in your browser. You will see: - **Executive
Summary**: Which drivers matter most - **Importance**: Bar chart ranking
the 4 drivers - **Factor Patterns**: How satisfaction varies across
categories of each driver - **Probability Lifts**: How much each
category changes predicted probability of high satisfaction - **Odds
Ratios**: Forest plot with confidence intervals - **Diagnostics**: Model
fit, sample information, warnings

------------------------------------------------------------------------

## 14. Quick Reference Tables

### Settings Quick Reference

| Setting | Required | Default | Valid Values |
|----|----|----|----|
| data_file | **Yes** | — | File path |
| output_file | **Yes** | — | File path |
| outcome_type | **Yes** | — | binary, ordinal, multinomial |
| analysis_name | No | "Key Driver Analysis" | Any text |
| html_report | No | TRUE | TRUE, FALSE |
| bootstrap_ci | No | FALSE | TRUE, FALSE |
| bootstrap_reps | No | 200 | 100-10000 |
| probability_lifts | No | TRUE | TRUE, FALSE |
| min_sample_size | No | 30 | Integer \>= 1 |
| confidence_level | No | 0.95 | 0.80-0.99 |
| missing_threshold | No | 50 | 0-100 |
| detailed_output | No | TRUE | TRUE, FALSE |
| rare_level_threshold | No | 10 | Integer \>= 1 |
| rare_level_policy | No | warn_only | warn_only, collapse_to_other, drop_level, error |
| brand_colour | No | #323367 | Hex colour |
| accent_colour | No | #CC9900 | Hex colour |
| multinomial_mode | If multinomial | — | baseline_category, per_outcome, all_pairwise, one_vs_all |
| target_outcome_level | If one_vs_all | — | Category value |

### Driver Types Quick Reference

| Type | Ordered? | Requires levels_order? | Use For |
|----|----|----|----|
| categorical | No | No | Campus, Region, Product |
| ordinal | Yes | **Yes** | Grade, Satisfaction, Agreement |
| binary | No | No | Gender, Yes/No |
| control_only | N/A | No | Demographics to adjust for but not report |

### Missing Strategy Quick Reference

| Strategy | What Happens | Default |
|----|----|----|
| missing_as_level | Missing becomes "Missing / Not answered" category | **Yes** (default) |
| drop_row | Row is removed from analysis | No |
| error_if_missing | Analysis refuses to run | No |

### Rare Level Policy Quick Reference

| Policy            | What Happens                                  |
|-------------------|-----------------------------------------------|
| warn_only         | Warning issued, all categories kept (default) |
| collapse_to_other | Rare categories merged into "Other"           |
| drop_level        | Rows with rare categories removed             |
| error             | Analysis refuses to run                       |

### Sample Size Guidelines

| Model Type  | Minimum N | Recommended N | Per Parameter                         |
|-------------|-----------|---------------|---------------------------------------|
| Binary      | 50        | 100+          | 10 events per predictor level         |
| Ordinal     | 75        | 150+          | 10 per threshold per predictor        |
| Multinomial | 100       | 200+          | 10 per outcome category per predictor |

### Effect Size Interpretation

| Odds Ratio | Effect Size | Probability Lift (pp) | Interpretation |
|----|----|----|----|
| 0.9-1.1 | Negligible | 0-1 pp | No meaningful difference |
| 0.67-0.9 or 1.1-1.5 | Small | 1-5 pp | Minor effect |
| 0.5-0.67 or 1.5-2.0 | Medium | 5-10 pp | Moderate effect |
| 0.33-0.5 or 2.0-3.0 | Large | 10-20 pp | Strong effect |
| \<0.33 or \>3.0 | Very Large | 20+ pp | Very strong effect |

### Importance Interpretation

| Importance % | Category        | Action               |
|--------------|-----------------|----------------------|
| \> 30%       | Dominant driver | Primary focus area   |
| 15-30%       | Major driver    | Important to address |
| 5-15%        | Moderate driver | Worth considering    |
| \< 5%        | Minor driver    | Limited impact       |

### McFadden R-squared Interpretation

| Value   | Fit Quality | What It Means             |
|---------|-------------|---------------------------|
| 0.4+    | Excellent   | Comprehensive explanation |
| 0.2-0.4 | Good        | Strong model              |
| 0.1-0.2 | Moderate    | Useful but incomplete     |
| \< 0.1  | Limited     | Important drivers missing |

------------------------------------------------------------------------

**Part of the Turas Analytics Platform** **The Research LampPost (Pty)
Ltd**
