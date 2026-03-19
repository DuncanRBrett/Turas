# Turas Conjoint Module -- User Manual

**Version:** 3.0.0
**Last Updated:** March 2026
**Template:** Conjoint_Config_Template.xlsx (v3.1)

---

## Table of Contents

1. [Introduction to Conjoint Analysis](#1-introduction-to-conjoint-analysis)
2. [Study Design Considerations](#2-study-design-considerations)
3. [Which Estimation Method to Use](#3-which-estimation-method-to-use)
4. [Step-by-Step Guide](#4-step-by-step-guide)
5. [Configuration Reference](#5-configuration-reference)
6. [Interpreting Results](#6-interpreting-results)
7. [Market Simulator Guide](#7-market-simulator-guide)
8. [Product Optimizer](#8-product-optimizer)
9. [Willingness to Pay](#9-willingness-to-pay)
10. [Alchemer Data Import](#10-alchemer-data-import)
11. [Potential Issues and Troubleshooting](#11-potential-issues-and-troubleshooting)
12. [Package Dependencies](#12-package-dependencies)

---

## 1. Introduction to Conjoint Analysis

### What Is Conjoint Analysis?

Conjoint analysis is a statistical technique that measures how people make trade-offs between product features. Rather than asking respondents to rate individual features in isolation, conjoint presents them with complete product profiles and asks them to choose. By analysing the pattern of choices across many respondents and many choice tasks, conjoint decomposes overall preferences into the value placed on each individual feature level.

For example, when buying a smartphone, a customer might value the Apple brand highly, but not enough to pay an additional $200 for it. Conjoint quantifies exactly how much each feature contributes to the overall attractiveness of a product.

### What Questions Does Conjoint Answer?

- **Feature valuation:** How much does each feature level contribute to product preference?
- **Attribute importance:** Which features matter most when people make choices? (e.g., is price more important than brand?)
- **Optimal product design:** What combination of features produces the most attractive product?
- **Market share prediction:** If we launch product X against competitors Y and Z, what share of preference will each capture?
- **Price sensitivity:** How much market share do we lose if we raise the price by one level? What is the willingness to pay for a feature upgrade?
- **Segmentation:** Are there distinct groups of customers with fundamentally different preferences?

### When to Use Conjoint

Conjoint is the right tool when:

- You need to understand **trade-offs** between product features (not just individual ratings).
- You are designing or optimising a **product, service, or package**.
- You need to predict **market shares** for hypothetical product configurations.
- You want to estimate **willingness to pay** for specific features.
- You need to identify **preference-based segments** in your market.

Conjoint is not the right tool when:

- You only have one feature to test (use monadic testing or pricing research instead).
- The features are not tradeable (e.g., safety features that everyone wants regardless of cost).
- You have very few respondents (under 30) and no budget for Hierarchical Bayes estimation.

### Terminology

| Term | Meaning |
|------|---------|
| **Attribute** | A product feature dimension (e.g., Brand, Price, Screen Size) |
| **Level** | A specific value an attribute can take (e.g., Apple, Samsung, Google) |
| **Choice task** | A single occasion where a respondent picks one product from a set |
| **Choice set** | The group of product alternatives shown in one choice task |
| **Alternative** | One product profile within a choice set |
| **Part-worth utility** | The numerical value representing preference for a specific level |
| **Attribute importance** | The percentage influence each attribute has on overall choice |
| **None option** | An opt-out alternative ("I would not choose any of these") |

---

## 2. Study Design Considerations

Good conjoint results depend heavily on good study design. This section covers the critical decisions you need to make before collecting data.

### Choosing Attributes and Levels

**Attributes** should be:

- **Actionable** -- features you can actually change or control.
- **Independent** -- changing one attribute should not logically constrain another.
- **Meaningful** -- respondents should understand and care about the differences.
- **Exhaustive** -- the levels should cover the realistic range of options.

**Common mistakes in attribute selection:**

- Including too many attributes (respondent fatigue degrades data quality).
- Including attributes with obvious "best" levels that everyone agrees on (no trade-offs to measure).
- Mixing attribute types that are difficult to compare (e.g., warranty terms alongside colour options).

### Number of Attributes

| Count | Assessment |
|-------|------------|
| 2--3 | Too few for most studies; limited trade-off information |
| **4--6** | **Ideal range for most studies** |
| 7--8 | Acceptable if respondents are knowledgeable about the category |
| 9+ | Not recommended; respondent overload leads to simplification strategies |

### Number of Levels per Attribute

| Count | Assessment |
|-------|------------|
| 2 | Minimum; provides a binary comparison |
| **3--4** | **Ideal for most attributes** |
| 5--6 | Acceptable for continuous attributes like price |
| 7+ | Not recommended; increases design size and reduces statistical power |

**Important:** Try to keep the number of levels roughly balanced across attributes. An attribute with 6 levels will tend to appear more important than one with 2 levels simply because it has a wider utility range. This is known as the "number of levels" effect.

### Number of Choice Tasks per Respondent

Each respondent should complete **8 to 15 choice tasks**. Fewer than 8 provides insufficient data per respondent for individual-level estimation (HB). More than 15 risks fatigue, where respondents begin using simplification strategies (e.g., always picking the cheapest option).

A common design uses **12 choice tasks** per respondent.

### Number of Alternatives per Choice Set

Each choice task typically shows **3 to 5 product alternatives**:

| Alternatives | Assessment |
|--------------|------------|
| 2 | Simple paired comparison; fast but less efficient |
| **3--4** | **Most common and recommended** |
| 5 | Acceptable; slightly more cognitive load |
| 6+ | Not recommended; respondents struggle to compare |

If your study includes a "None of these" option, it counts as an additional alternative.

### Sample Size Requirements

The minimum sample size depends on the complexity of the design. A widely used rule of thumb is:

```
n >= (500 * c) / (t * a)
```

Where:

- **n** = minimum number of respondents
- **c** = largest number of levels for any single attribute
- **t** = number of choice tasks per respondent
- **a** = number of alternatives per choice set (excluding None)

**Examples:**

| Design | c | t | a | Minimum n |
|--------|---|---|---|-----------|
| 4 attributes, 3 levels each, 12 tasks, 3 alts | 3 | 12 | 3 | 42 |
| 5 attributes, 4 levels each, 10 tasks, 3 alts | 4 | 10 | 3 | 67 |
| 6 attributes, 5 levels each, 12 tasks, 4 alts | 5 | 12 | 4 | 53 |
| 4 attributes, 6 levels each, 8 tasks, 3 alts | 6 | 8 | 3 | 125 |

**Practical recommendations:**

- **Minimum viable:** 100 respondents (aggregate MNL only).
- **Standard study:** 200--400 respondents (reliable aggregate + HB).
- **Robust study with segmentation:** 400--800 respondents (reliable for latent class analysis with 3--5 segments).
- **Large-scale quantitative:** 800+ respondents.

For **Hierarchical Bayes** estimation, the absolute minimum is approximately 30 respondents, but 200+ is strongly recommended for stable individual-level utilities.

For **Latent Class** analysis, aim for at least 100 respondents per expected class (e.g., 300+ respondents if you anticipate 3 segments).

### Experimental Design Types

The **experimental design** determines which product profiles are shown together in each choice task. Two common approaches:

- **Orthogonal design:** Ensures that attribute levels appear in combination with equal frequency across the design. Good for attribute-level balance but may not be statistically optimal.
- **D-optimal design:** Maximises the statistical information extracted from each choice task. Produces more precise estimates than orthogonal designs for the same number of tasks. This is the preferred approach for modern CBC studies.

Turas does not generate experimental designs itself. Use external tools such as Sawtooth Software, Ngene, or the R packages `AlgDesign` or `idefix` to create your design before collecting data.

### Common Design Mistakes

| Mistake | Consequence | Prevention |
|---------|-------------|------------|
| Too many attributes (>8) | Respondent overload, simplification strategies | Limit to 4--6 attributes |
| Unbalanced levels across attributes | "Number of levels" bias inflates importance of attributes with more levels | Keep level counts similar (e.g., all 3--4) |
| Dominated alternatives | A product that is clearly best on all attributes provides no trade-off information | Use D-optimal design to avoid dominance |
| Too few choice tasks | Insufficient data for estimation, wide confidence intervals | Use at least 8 tasks per respondent |
| Too many choice tasks | Fatigue, random responding in later tasks | Cap at 12--15 tasks |
| Unrealistic level combinations | Respondents reject the exercise as irrelevant | Screen combinations for face validity |
| Missing "None" option when needed | Forces a choice even when respondents would not buy any option; overestimates demand | Include None if non-purchase is realistic |

---

## 3. Which Estimation Method to Use

The Turas Conjoint Module supports five estimation methods. Use the following decision guide to select the right one for your study.

### Decision Tree

```
Start here
   |
   v
Do you need INDIVIDUAL-LEVEL utilities?
   |               |
   No              Yes
   |               |
   v               v
Is n > 200?     Do you want to find PREFERENCE SEGMENTS?
   |   |           |               |
   Yes  No         No              Yes
   |    |          |               |
   v    v          v               v
  MNL  MNL*     HB              LATENT CLASS
  (auto)        (estimation_method = "hb")   (estimation_method = "latent_class")

* MNL works with n < 200 but confidence intervals will be wider.

Does your data include BEST AND WORST selections per task?
   |
   Yes --> BEST-WORST (estimation_method = "best_worst")
```

### Method Comparison

| Method | Setting | Best When | Individual Utilities | Minimum n | Speed |
|--------|---------|-----------|---------------------|-----------|-------|
| **MNL (auto/mlogit)** | `auto` | Most studies, quick results, aggregate-level preferences | No | ~50 | Fast (seconds) |
| **Conditional Logit** | `clogit` | Automatic fallback if mlogit fails | No | ~50 | Fast (seconds) |
| **Hierarchical Bayes** | `hb` | Need individual-level utilities, preference heterogeneity, small samples | Yes | ~30 | Slow (minutes) |
| **Latent Class** | `latent_class` | Want preference-based segments, hypothesis of distinct preference groups | Per-class | ~100 per class | Moderate (minutes) |
| **Best-Worst** | `best_worst` | Data includes best AND worst selections per choice set | Depends | ~50 | Fast (seconds) |

### Method Details

#### MNL (Multinomial Logit) -- Default

The industry-standard method for choice-based conjoint. Estimates a single set of aggregate part-worth utilities that represent the average preferences across all respondents. Best for most studies where individual-level analysis is not required.

- **Primary engine:** `mlogit` package (purpose-built for discrete choice modelling).
- **Fallback engine:** `clogit` from the `survival` package (automatically used if mlogit fails).
- **When `estimation_method = "auto"`**, Turas tries mlogit first and falls back to clogit if needed.

#### Hierarchical Bayes (HB)

Uses Markov Chain Monte Carlo (MCMC) simulation to estimate individual-level part-worth utilities. Each respondent gets their own set of utilities, borrowing statistical strength from the population distribution. This is the gold standard for individual-level conjoint analysis.

- **Engine:** `bayesm::rhierMnlRwMixture`.
- **Convergence diagnostics:** Rhat, effective sample size (ESS), Geweke test.
- **Key settings:** `hb_iterations` (default 10,000), `hb_burnin` (default 5,000), `hb_thin` (default 1).
- **Runtime:** Minutes to hours depending on sample size and iterations.

#### Latent Class

Discovers discrete preference-based segments (classes) directly from choice data. Each class has its own set of part-worth utilities, and each respondent is assigned a probability of belonging to each class.

- **Engine:** `bayesm` with multiple mixture components.
- **Model selection:** Tests K = `latent_class_min` to K = `latent_class_max`, selects the best K by BIC (default) or AIC.
- **Outputs:** Class-level utilities, class sizes, membership probabilities, entropy R-squared.
- **Key insight:** Unlike external segmentation (e.g., demographics), latent class finds segments based on what people actually prefer.

#### Best-Worst Scaling

For choice tasks where respondents select both the best and worst alternatives (not just the best). This provides more information per choice task and can improve estimation efficiency.

- Supports sequential and simultaneous estimation approaches.
- Set `choice_type = "best_worst"` and `estimation_method = "best_worst"`.

---

## 4. Step-by-Step Guide

### Step 1: Prepare Your Data

Your choice data must be in **long format** -- one row per alternative per choice set per respondent.

**Required columns:**

| Column | Description | Example Values |
|--------|-------------|----------------|
| Respondent ID | Unique identifier for each respondent | 1, 2, 3, ... |
| Choice set ID | Identifies each choice task within a respondent | 1, 2, 3, ... |
| Alternative ID | Identifies each alternative within a choice set (optional but recommended) | 1, 2, 3 |
| Attribute columns | One column per attribute, containing the level shown | Apple, Samsung, Google |
| Chosen indicator | Binary: 1 if this alternative was chosen, 0 otherwise | 0 or 1 |

**Example data structure:**

```
resp_id | choice_set_id | alt_id | Brand   | Price | Storage | chosen
--------|---------------|--------|---------|-------|---------|-------
1       | 1             | 1      | Apple   | $449  | 128GB   | 0
1       | 1             | 2      | Samsung | $599  | 256GB   | 1
1       | 1             | 3      | Google  | $699  | 512GB   | 0
1       | 2             | 1      | Google  | $449  | 256GB   | 0
1       | 2             | 2      | Apple   | $699  | 128GB   | 0
1       | 2             | 3      | Samsung | $599  | 512GB   | 1
2       | 1             | 1      | Samsung | $449  | 512GB   | 1
2       | 1             | 2      | Google  | $599  | 128GB   | 0
2       | 1             | 3      | Apple   | $699  | 256GB   | 0
```

**Critical validation rules:**

1. Each choice set must have **exactly one** row with `chosen = 1`.
2. Level names in the data must match the level names in the config **exactly** (case-sensitive).
3. No missing values in attribute columns.
4. Each choice set should have a consistent number of alternatives.

**Supported file formats:** CSV (.csv), Excel (.xlsx), SPSS (.sav), Stata (.dta).

### Step 2: Create Your Config File

You have two options:

**Option A: Generate a template from R (recommended)**

```r
source("modules/conjoint/R/00_main.R")
generate_conjoint_config_template("my_config.xlsx")
```

This creates a branded Excel template with all settings, descriptions, default values, and dropdown validation.

You can also generate method-specific templates:

```r
generate_conjoint_config_template("hb_config.xlsx", method_template = "cbc_hb")
generate_conjoint_config_template("lc_config.xlsx", method_template = "cbc_latent_class")
```

**Option B: Copy and edit the template manually**

Copy `Conjoint_Config_Template.xlsx` to your project folder and edit the Settings and Attributes sheets.

### Step 3: Set Up Attributes

Open the **Attributes** sheet in your config file. For each attribute in your study, fill in:

| Column | What to Enter | Notes |
|--------|---------------|-------|
| AttributeName | The attribute name | Must match the column name in your data file exactly (case-sensitive) |
| NumLevels | Number of levels | Must match the count of level names you provide |
| LevelNames | Comma-separated level names | Must match the values in your data file exactly (case-sensitive) |

**Example:**

| AttributeName | NumLevels | LevelNames |
|---------------|-----------|------------|
| Brand | 3 | Apple, Samsung, Google |
| Price | 4 | $299, $399, $499, $599 |
| Screen_Size | 3 | 5.5 inch, 6.1 inch, 6.7 inch |
| Battery_Life | 3 | 12 hours, 18 hours, 24 hours |

**The order of levels in LevelNames matters:** the first level is used as the baseline (reference level) in estimation. This is the level whose utility is set to zero, with other levels estimated relative to it.

### Step 4: Configure Estimation Settings

Open the **Settings** sheet and set these key fields:

**Essential settings:**

| Setting | What to Enter |
|---------|---------------|
| `data_file` | Path to your data file (relative to config file location, or absolute) |
| `output_file` | Path for the output Excel file |
| `analysis_type` | `choice` (for CBC) |
| `estimation_method` | `auto`, `mlogit`, `clogit`, `hb`, `latent_class`, or `best_worst` |

**Column mapping (if your column names differ from defaults):**

| Setting | Default | Your Value |
|---------|---------|------------|
| `respondent_id_column` | `resp_id` | (your column name) |
| `choice_set_column` | `choice_set_id` | (your column name) |
| `chosen_column` | `chosen` | (your column name) |
| `alternative_id_column` | `alternative_id` | (your column name) |

See the full [Configuration Reference](#5-configuration-reference) for all available settings.

### Step 5: Run the Analysis

**From the Turas GUI:**

```r
source("launch_turas.R")
# Click "Launch Conjoint" in the GUI
# Browse to your config file
# Click "RUN ANALYSIS"
```

**From the R console:**

```r
setwd("/path/to/Turas")
source("modules/conjoint/R/00_main.R")

results <- run_conjoint_analysis(
  config_file = "/path/to/my_config.xlsx",
  verbose = TRUE
)
```

**With path overrides:**

```r
results <- run_conjoint_analysis(
  config_file = "my_config.xlsx",
  data_file = "my_data.csv",
  output_file = "my_results.xlsx"
)
```

### Step 6: Interpret Results

The analysis produces:

- An **Excel workbook** with Utilities, Relative_Importance, Model_Summary, and Market Simulator sheets.
- An **HTML report** (if `generate_html_report = TRUE`) with interactive charts and a built-in simulator.
- A **results object** in R with all computed outputs.

See [Interpreting Results](#6-interpreting-results) for detailed guidance.

### Step 7: Use the Market Simulator

The Market Simulator sheet in the output workbook lets you configure hypothetical products and see predicted market shares. See [Market Simulator Guide](#7-market-simulator-guide) for full instructions.

---

## 5. Configuration Reference

The configuration file is an Excel workbook with the following sheets:

| Sheet | Required | Purpose |
|-------|----------|---------|
| Settings | Yes | Analysis parameters, file paths, estimation options |
| Attributes | Yes | Product attributes and their levels |
| Custom_Slides | No | Custom content for the HTML report |
| Custom_Images | No | Custom images for the HTML report |
| Design | No | Experimental design matrix (Turas infers from data if omitted) |
| Instructions | No | Documentation (not read by code) |

### Settings Sheet -- All Parameters

The Settings sheet uses a two-column layout: `Setting` and `Value`. Settings are grouped into sections.

#### File Paths and Output

| Setting | Required | Default | Description | Valid Values |
|---------|----------|---------|-------------|--------------|
| `data_file` | **Yes** | (none) | Path to your data file. Relative paths are resolved from the config file directory. | File path ending in `.csv`, `.xlsx`, `.sav`, or `.dta` |
| `output_file` | No | `conjoint_results.xlsx` | Path for the results Excel file. | File path ending in `.xlsx` |
| `data_source` | No | `generic` | Data source format. Use `alchemer` for direct Alchemer CBC exports. | `generic` or `alchemer` |
| `analysis_type` | **Yes** | `choice` | Type of conjoint analysis. | `choice` or `rating` |
| `choice_type` | No | `single` | Type of choice task. | `single`, `single_with_none`, or `best_worst` |

#### Column Mapping

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| `respondent_id_column` | No | `resp_id` | Column name for respondent identifier |
| `choice_set_column` | No | `choice_set_id` | Column name for choice set identifier |
| `chosen_column` | No | `chosen` | Column name for the chosen indicator (0/1) |
| `alternative_id_column` | No | `alternative_id` | Column name for alternative identifier |
| `rating_variable` | No | (none) | Column name for rating scores (rating-based analysis only) |

#### Estimation Method

| Setting | Required | Default | Description | Valid Values |
|---------|----------|---------|-------------|--------------|
| `estimation_method` | **Yes** | `auto` | Primary estimation algorithm | `auto`, `mlogit`, `clogit`, `hb`, `latent_class`, `best_worst` |
| `confidence_level` | No | `0.95` | Confidence level for intervals | Decimal between `0.80` and `0.99` |
| `zero_center_utilities` | No | `TRUE` | Zero-center utilities within each attribute (recommended) | `TRUE` or `FALSE` |
| `base_level_method` | No | `first` | Which level serves as the baseline (utility = 0) | `first` or `last` |

#### Hierarchical Bayes Settings

These settings apply only when `estimation_method = "hb"`.

| Setting | Default | Description | Valid Values |
|---------|---------|-------------|--------------|
| `hb_iterations` | `10000` | Total MCMC iterations. More iterations = better convergence but longer runtime. | Integer >= 1000. Recommended: 10,000--50,000. |
| `hb_burnin` | `5000` | Iterations to discard as burn-in (model warming up). Must be less than `hb_iterations`. | Integer >= 0, < `hb_iterations` |
| `hb_thin` | `1` | Thinning interval. 1 = keep all post-burn-in draws; 2 = keep every other draw. | Integer >= 1 |
| `hb_ncomp` | `1` | Number of mixture components in the prior distribution. 1 = standard HB; >1 = mixture of normals. | Integer >= 1 |
| `hb_prior_variance` | `2` | Prior variance for the beta coefficients. Higher = less informative prior. | Positive number |

#### Latent Class Settings

These settings apply only when `estimation_method = "latent_class"`.

| Setting | Default | Description | Valid Values |
|---------|---------|-------------|--------------|
| `latent_class_min` | `2` | Minimum number of classes to test | Integer >= 2 |
| `latent_class_max` | `5` | Maximum number of classes to test | Integer >= `latent_class_min` |
| `latent_class_criterion` | `bic` | Information criterion for selecting the optimal number of classes | `bic` or `aic` |

#### Interactions

| Setting | Default | Description | Valid Values |
|---------|---------|-------------|--------------|
| `interaction_terms` | (none) | Comma-separated interaction pairs to include in the model | Format: `Brand:Price, Size:Colour` |
| `auto_detect_interactions` | `FALSE` | Automatically detect statistically significant interactions | `TRUE` or `FALSE` |

#### Willingness to Pay

| Setting | Default | Description | Valid Values |
|---------|---------|-------------|--------------|
| `wtp_price_attribute` | (none) | Name of the price attribute. Leave blank to skip WTP calculation. | An attribute name from the Attributes sheet |
| `wtp_method` | `marginal` | WTP calculation method | `marginal` or `simulation` |

#### Market Simulator

| Setting | Default | Description | Valid Values |
|---------|---------|-------------|--------------|
| `generate_market_simulator` | `TRUE` | Include an interactive market simulator sheet in the Excel output | `TRUE` or `FALSE` |
| `simulation_method` | `logit` | Method for computing predicted market shares | `logit`, `first_choice`, or `rfc` |
| `rfc_draws` | `1000` | Number of random draws for the Randomised First Choice method | Integer >= 100 |

#### None Option

| Setting | Default | Description | Valid Values |
|---------|---------|-------------|--------------|
| `none_as_baseline` | `FALSE` | Use the None option as the baseline in estimation | `TRUE` or `FALSE` |
| `none_label` | `None` | Label for the None/no-choice alternative | Free text |

#### Product Optimizer

| Setting | Default | Description | Valid Values |
|---------|---------|-------------|--------------|
| `optimizer_method` | `exhaustive` | Search method for product optimization | `exhaustive` or `greedy` |
| `optimizer_max_products` | `5` | Maximum number of products in optimization scenarios | Integer 1--12 |

#### HTML Report

| Setting | Default | Description | Valid Values |
|---------|---------|-------------|--------------|
| `generate_html_report` | `FALSE` | Generate an interactive HTML analysis report | `TRUE` or `FALSE` |
| `generate_html_simulator` | `FALSE` | Generate a standalone HTML market simulator | `TRUE` or `FALSE` |
| `brand_colour` | `#323367` | Primary brand colour for HTML output | Hex colour code (e.g., `#323367`) |
| `accent_colour` | `#CC9900` | Accent colour for highlights in HTML output | Hex colour code (e.g., `#CC9900`) |
| `project_name` | `Conjoint Analysis` | Project name displayed in report header | Free text |
| `client_name` | (none) | Client name displayed in header and About page | Free text |
| `company_name` | `The Research LampPost` | Company name for the report header | Free text |

#### HTML Report Insights

Pre-populated analyst commentary that appears in the HTML report panels. Supports markdown formatting.

| Setting | Default | Description |
|---------|---------|-------------|
| `insight_overview` | (none) | Insight text for the Overview tab |
| `insight_utilities` | (none) | Insight text for the Utilities tab |
| `insight_diagnostics` | (none) | Insight text for the Diagnostics tab |
| `insight_simulator` | (none) | Insight text for the Simulator tab |
| `insight_wtp` | (none) | Insight text for the WTP tab |

#### Custom Content

| Setting | Default | Description | Valid Values |
|---------|---------|-------------|--------------|
| `include_custom_slides` | `FALSE` | Include custom slides from the Custom_Slides sheet in the HTML report | `TRUE` or `FALSE` |
| `include_custom_images` | `FALSE` | Include custom images from the Custom_Images sheet in the HTML report | `TRUE` or `FALSE` |

#### Analyst and About Page

| Setting | Default | Description |
|---------|---------|-------------|
| `analyst_name` | (none) | Analyst name for the About page |
| `analyst_email` | (none) | Analyst email for the About page |
| `analyst_phone` | (none) | Analyst phone for the About page |
| `closing_notes` | (none) | Closing notes (editable in the HTML report) |
| `researcher_logo_base64` | (none) | Base64-encoded logo image for the report header |

#### Alchemer Import

These settings apply only when `data_source = "alchemer"`.

| Setting | Default | Description |
|---------|---------|-------------|
| `clean_alchemer_levels` | `TRUE` | Automatically strip Alchemer-style prefixes from level names |
| `alchemer_response_id_column` | `ResponseID` | Alchemer response ID column name |
| `alchemer_set_number_column` | `SetNumber` | Alchemer set number column name |
| `alchemer_card_number_column` | `CardNumber` | Alchemer card number column name |
| `alchemer_score_column` | `Score` | Alchemer score column name |

### Attributes Sheet

The Attributes sheet defines the product features and their levels with three columns:

| Column | Required | Description |
|--------|----------|-------------|
| `AttributeName` | Yes | Name of the product attribute. Must match the data column name exactly (case-sensitive). |
| `NumLevels` | Yes | Number of levels for this attribute. Must match the count of names in LevelNames. |
| `LevelNames` | Yes | Comma-separated list of level values. Must match data values exactly. Order matters: the first level is the baseline. |

---

## 6. Interpreting Results

### Part-Worth Utilities

Part-worth utilities are the core output of conjoint analysis. Each attribute level receives a utility score that represents its contribution to the overall attractiveness of a product.

**How to read the Utilities table:**

| Attribute | Level | Utility | Std_Error | CI_Lower | CI_Upper | p_value |
|-----------|-------|---------|-----------|----------|----------|---------|
| Brand | Apple | +0.45 | 0.08 | +0.29 | +0.61 | <0.001 |
| Brand | Samsung | +0.12 | 0.07 | -0.02 | +0.26 | 0.092 |
| Brand | Google | -0.57 | 0.09 | -0.75 | -0.39 | <0.001 |

**Interpretation rules:**

- **Positive utility** = more preferred than the attribute average.
- **Negative utility** = less preferred than the attribute average.
- **Zero utility** = either the baseline level (if not zero-centred) or exactly average preference.
- **Larger magnitude** = stronger preference (positive) or stronger aversion (negative).
- Utilities are **comparable within an attribute** but not directly between attributes.
- When zero-centred, utilities within each attribute sum to zero.

**Statistical significance:**

- Check the `p_value` column. A value below 0.05 indicates that the utility is statistically significantly different from zero.
- If a level's confidence interval crosses zero, the preference is not statistically distinguishable from the baseline.
- Samsung's p-value of 0.092 in the example above means we cannot be confident at the 95% level that Samsung is preferred over the average.

### Attribute Importance

Attribute importance scores tell you how much each attribute influences choice, expressed as a percentage that sums to 100%.

**Calculation method:** Importance is calculated from the range of utilities within each attribute (maximum utility minus minimum utility). The range for each attribute is expressed as a percentage of the total range across all attributes.

```
Importance_i = Range_i / Sum(all ranges) * 100%
```

**Example:**

| Attribute | Importance |
|-----------|------------|
| Price | 48% |
| Brand | 27% |
| Storage | 16% |
| Battery | 9% |

**Interpretation:** Price drives 48% of the choice decision, followed by Brand at 27%. Battery Life has the least influence at 9%.

**Caution:** Importance depends on the specific levels tested. If you tested a very wide price range ($100 to $1,000) but a narrow brand set (two similar brands), price importance will be inflated relative to brand. Always consider the level ranges when interpreting importance.

### Model Diagnostics

The Model_Summary sheet provides fit statistics that indicate how well the model explains the choice data.

#### McFadden R-squared

McFadden's pseudo R-squared measures the improvement in log-likelihood over a null (random choice) model. It does not follow the same scale as ordinary R-squared:

| McFadden R-squared | Interpretation |
|--------------------|----------------|
| < 0.1 | Poor fit -- model barely improves on random guessing |
| 0.1 -- 0.2 | Acceptable fit -- typical for many conjoint studies |
| 0.2 -- 0.3 | Good fit -- model explains choices well |
| 0.3 -- 0.4 | Very good fit -- strong predictive performance |
| > 0.4 | Excellent fit -- sometimes indicates over-fitting |

A McFadden R-squared of 0.2--0.4 corresponds roughly to an ordinary R-squared of 0.7--0.9 in linear regression.

#### Hit Rate

The hit rate is the percentage of choice tasks where the model correctly predicts the chosen alternative.

- **Compare against the chance rate:** With 3 alternatives per task, the chance rate is 33.3%. A good model should substantially exceed this.
- A hit rate of 50--70% is typical for a well-fitting CBC model with 3 alternatives.
- Hit rates above 80% are excellent but rare.
- A hit rate close to or below the chance rate indicates the model has no predictive power.

#### Other Diagnostics

| Metric | Description |
|--------|-------------|
| Log-Likelihood | The log-likelihood of the fitted model. More negative = worse fit. |
| AIC | Akaike Information Criterion. Lower = better. Penalises model complexity. |
| BIC | Bayesian Information Criterion. Lower = better. Stronger complexity penalty than AIC. |

### HB-Specific Diagnostics

When using Hierarchical Bayes estimation, additional diagnostics are available:

| Metric | Description | Good Value |
|--------|-------------|------------|
| **Rhat** | Convergence diagnostic. Values near 1.0 indicate convergence. | < 1.05 for all parameters |
| **Effective Sample Size (ESS)** | Number of effectively independent draws after accounting for autocorrelation. | > 400 per parameter |
| **Geweke z-score** | Tests whether the first and last portions of the chain have the same mean. | Absolute value < 2 |
| **Individual RLH** | Root Likelihood per respondent. Identifies respondents with poor choice consistency. | > 1/a (where a = number of alternatives) |

If Rhat exceeds 1.10 for any parameter, increase `hb_iterations` and re-run.

### Latent Class Diagnostics

When using latent class analysis:

| Metric | Description |
|--------|-------------|
| **BIC / AIC by K** | Information criteria for each number of classes tested. The optimal K minimises BIC (or AIC). |
| **Class sizes** | Percentage of respondents in each class. Very small classes (<5%) may be artefacts. |
| **Entropy R-squared** | Classification quality. Values above 0.7 indicate good class separation. |
| **Class membership probabilities** | For each respondent, the probability of belonging to each class. |

**Interpreting class profiles:** Each class has its own set of part-worth utilities and attribute importances. Compare these across classes to understand how the segments differ. For example, one class might be price-sensitive while another is brand-loyal.

### Willingness to Pay

WTP estimates the monetary value of switching from one attribute level to another:

```
WTP = -(Utility_level / Price_coefficient)
```

**Example:**

| Attribute | Level | WTP Relative to Baseline |
|-----------|-------|--------------------------|
| Brand | Apple | +$85 |
| Brand | Samsung | +$25 |
| Brand | Google | -$110 |

**Interpretation:** Respondents are willing to pay approximately $85 more for an Apple phone compared to the baseline, and would need a $110 discount to accept a Google phone.

**Limitations of WTP:**

- WTP estimates are only meaningful if the price attribute has numeric levels.
- WTP can be unstable when the price coefficient is small (near zero).
- Confidence intervals for WTP are typically wide; treat point estimates as approximate.
- WTP assumes linear price sensitivity within the tested range.

---

## 7. Market Simulator Guide

The market simulator is one of the most valuable outputs of conjoint analysis. It lets you define hypothetical products and predict their market shares.

### What the Simulator Does

The simulator uses the estimated part-worth utilities to calculate a total utility for each defined product, then converts these utilities into predicted market shares using a choice probability model.

### How to Set Up Products

In the **Market Simulator** sheet of the output workbook:

1. Each column (Product 1 through Product 5) represents one product.
2. Each row represents an attribute.
3. Use the dropdown menus to select the level for each attribute for each product.
4. Leave a product column blank to exclude it from the simulation.

### Understanding Share Predictions

Shares are calculated using one of three methods:

| Method | Setting | Description |
|--------|---------|-------------|
| **Logit** | `logit` | Shares proportional to exp(utility). The standard and most commonly used method. Accounts for similarity between products. |
| **First Choice** | `first_choice` | Each respondent is assigned 100% to the product with the highest utility. Simple but ignores the degree of preference. |
| **Randomised First Choice (RFC)** | `rfc` | Adds random error to utilities before applying first-choice rule. Produces more realistic shares than pure first choice. Requires individual-level utilities (HB). |

**Logit share formula:**

```
Share_j = exp(Utility_j) / Sum(exp(Utility_k)) for all products k
```

Shares always sum to 100% across all active products.

### Sensitivity Analysis

The simulator sheet includes a sensitivity analysis section that shows how market share changes when you vary one attribute level at a time. This helps identify which feature changes have the largest impact on competitive position.

### Source of Volume

When you change one product's configuration and its share increases, that share must come from somewhere. Source of volume analysis shows which competing products lose share and by how much. This is critical for understanding competitive dynamics.

### Demand Curves

If your study includes a price attribute, you can construct a demand curve by varying the price level of one product while holding everything else constant. This shows how share declines as price increases, helping identify optimal price points.

---

## 8. Product Optimizer

The product optimizer searches through possible product configurations to find the one that maximises market share (or utility, or revenue).

### Exhaustive Search

Tests every possible combination of attribute levels. Only feasible for small design spaces (fewer than approximately 10,000 combinations).

- Guarantees finding the global optimum.
- Returns the top N products ranked by the objective.

### Greedy Hill-Climbing

For large design spaces, the greedy optimizer starts with a random configuration and iteratively improves one attribute at a time. Faster than exhaustive search but may find a local optimum rather than the global one.

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `optimizer_method` | `exhaustive` | `exhaustive` for small designs, `greedy` for large ones |
| `optimizer_max_products` | `5` | Maximum products in multi-product portfolio optimization |

---

## 9. Willingness to Pay

### What WTP Provides

Willingness to Pay translates utility differences into monetary values. Instead of saying "Apple has 0.45 more utility than the average," you can say "respondents would pay $85 more for an Apple phone."

### Requirements

- A **price attribute** must be defined in your study with numeric levels (e.g., $299, $399, $499).
- Set `wtp_price_attribute` to the name of your price attribute in the config file.

### How It Works

WTP is calculated as the ratio of a level's utility to the price coefficient:

```
WTP = -(Beta_attribute_level / Beta_price)
```

The price coefficient (Beta_price) is estimated by regressing the price utilities on the numeric price values. This converts the "utility per dollar" into a dollar-denominated measure for every non-price level.

### Confidence Intervals

WTP confidence intervals are computed via the delta method (for MNL) or from the posterior distribution (for HB). These intervals are often wide -- this is normal and reflects the inherent uncertainty in translating utilities to money.

### Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `wtp_price_attribute` | (none) | Name of the price attribute. Leave blank to skip WTP. |
| `wtp_method` | `marginal` | `marginal` (ratio method) or `simulation` (simulation-based) |

---

## 10. Alchemer Data Import

The module supports direct import of Alchemer (formerly SurveyGizmo) CBC exports.

### Alchemer Export Format

Alchemer CBC exports have a specific structure:

- `ResponseID` -- Respondent identifier
- `SetNumber` -- Choice set number (1, 2, 3...)
- `CardNumber` -- Alternative number within each set (1, 2, 3...)
- `Score` -- 0 or 100 (not chosen / chosen)
- Attribute columns with prefixed level names (e.g., `Brand_Apple`, `Price_Low_071`)

### Configuration for Alchemer Data

Set these values in the Settings sheet:

| Setting | Value |
|---------|-------|
| `data_source` | `alchemer` |
| `clean_alchemer_levels` | `TRUE` |
| `respondent_id_column` | `ResponseID` |
| `choice_set_column` | `SetNumber` |
| `chosen_column` | `Score` |
| `alternative_id_column` | `CardNumber` |

### Level Name Cleaning

When `clean_alchemer_levels = TRUE`, Turas automatically strips Alchemer-style prefixes from level names:

| Alchemer Format | Cleaned Value |
|-----------------|---------------|
| Low_071 | Low |
| Mid_089 | Mid |
| High_107 | High |
| MSG_Present | Present |
| Brand_Apple | Apple |

Make sure the **cleaned** level names match what you specify in the Attributes sheet.

---

## 11. Potential Issues and Troubleshooting

### Perfect Separation

**Symptom:** Model fails to converge, or produces extremely large coefficient estimates (e.g., utility > 20).

**Cause:** One or more attribute levels perfectly predict the choice outcome. For example, if one level is always chosen when present and never chosen when absent, the model cannot estimate a finite coefficient.

**Solutions:**

1. Check the data for levels that are always or never chosen.
2. Remove the problematic level or merge it with another.
3. Try `estimation_method = "clogit"` which may be more robust.
4. Increase the sample size.

### Convergence Failures

**Symptom:** Console message "Model did not converge" or very large standard errors.

**Cause:** The optimisation algorithm could not find a stable solution, usually due to insufficient data or model mis-specification.

**Solutions:**

1. Try `estimation_method = "clogit"` as a more robust alternative.
2. Reduce the number of attributes or levels.
3. Check for perfect separation (see above).
4. Increase the sample size.
5. For HB: increase `hb_iterations` and `hb_burnin`.

### Low Hit Rates

**Symptom:** Hit rate is close to or only slightly above the chance rate.

**Cause:** The model is not explaining respondent choices well. This could be due to random responding, missing attributes, or poor study design.

**Solutions:**

1. Check data quality -- are there respondents who appear to be choosing randomly?
2. Verify that level names in the config match the data exactly (case-sensitive).
3. Consider whether important attributes were omitted from the study.
4. Look at individual respondent consistency (available with HB estimation).

### Small Sample Sizes

**Symptom:** Wide confidence intervals, many non-significant utilities.

**Cause:** Insufficient data to estimate utilities precisely.

**Solutions:**

1. Use HB estimation (`estimation_method = "hb"`) which borrows strength across respondents.
2. Reduce the number of attributes and levels to decrease the number of parameters.
3. Report confidence intervals alongside point estimates.
4. Consider whether the study design had enough choice tasks per respondent.

### Unbalanced Designs

**Symptom:** Some level combinations appear much more frequently than others in the data.

**Cause:** The experimental design was not properly balanced, or data was lost unevenly across conditions.

**Solutions:**

1. Check level frequencies with a simple cross-tabulation.
2. Unbalanced designs reduce statistical efficiency but do not necessarily bias estimates.
3. For future studies, use D-optimal design software to ensure balance.

### Missing Data

**Symptom:** Error "Missing values found in attribute columns" or unexpected results.

**Cause:** Incomplete data records in the choice data file.

**Solutions:**

1. Remove rows with missing attribute values before running the analysis.
2. Check the source data for export issues (e.g., truncated CSV files).
3. Ensure every choice set has a complete set of alternatives with all attributes filled.

### Level Names Don't Match

**Symptom:** Error "Level 'X' not found in data" or zero utilities for all levels.

**Cause:** The level names in the Attributes sheet do not match the values in the data file. This is case-sensitive and whitespace-sensitive.

**Solutions:**

1. Open your data file and check the exact values (including leading/trailing spaces).
2. Use "Text" format in Excel to see the literal values.
3. Common culprits: extra spaces after commas in LevelNames, different capitalisation, special characters (curly quotes vs. straight quotes).

### Multiple Chosen in Same Set

**Symptom:** Error "Choice set X has 2 chosen alternatives."

**Cause:** More than one alternative is marked as chosen=1 in a single choice set.

**Solution:** Review your data to ensure each choice set has exactly one chosen=1 row.

### "Indexes don't define unique observations"

**Symptom:** This mlogit error occurs during model estimation.

**Cause:** Duplicate combinations of (respondent, choice_set, alternative) in the data.

**Solution:** Check for duplicated rows and ensure each row represents a unique respondent-choice_set-alternative combination.

### Output File Not Created

**Solutions:**

1. Verify the output directory exists (Turas will not create directories).
2. Close any existing file with the same name (Excel locks files when open).
3. Check file system permissions.

### Memory Errors

**Cause:** Very large dataset or HB estimation with many iterations.

**Solutions:**

1. Use CSV instead of XLSX for the data file (lower memory overhead).
2. For HB: reduce `hb_iterations` or increase `hb_thin`.
3. Use `estimation_method = "clogit"` which is less memory-intensive than mlogit.
4. Close other R sessions and memory-intensive applications.

---

## 12. Package Dependencies

The following R packages are required or optional for the Turas Conjoint Module.

### Core Dependencies (Required)

| Package | Purpose |
|---------|---------|
| **dplyr** | Data manipulation and transformation throughout the module |
| **openxlsx** | Reading configuration files and writing Excel output workbooks (no Java dependency) |
| **mlogit** | Primary estimation engine for multinomial logit discrete choice models |
| **dfidx** | Data indexing required by mlogit >= 1.1-0 for panel data structure |
| **survival** | Provides `clogit()` as a fallback estimation method via Cox regression |

### Advanced Analysis (Optional)

| Package | Purpose | When Needed |
|---------|---------|-------------|
| **bayesm** | Hierarchical Bayes MCMC estimation (`rhierMnlRwMixture`) and latent class analysis | `estimation_method = "hb"` or `"latent_class"` |
| **coda** | MCMC convergence diagnostics (Rhat, ESS, Geweke test) for HB estimation | `estimation_method = "hb"` |

### Data Import (Optional)

| Package | Purpose | When Needed |
|---------|---------|-------------|
| **haven** | Import SPSS (.sav) and Stata (.dta) data files | When data file is `.sav` or `.dta` format |

### Output (Optional)

| Package | Purpose | When Needed |
|---------|---------|-------------|
| **jsonlite** | JSON encoding for HTML report data embedding | `generate_html_report = TRUE` |

### Installing All Dependencies

```r
# Core packages (required)
install.packages(c("dplyr", "openxlsx", "mlogit", "dfidx", "survival"))

# HB and latent class (optional)
install.packages(c("bayesm", "coda"))

# SPSS/Stata import (optional)
install.packages("haven")

# HTML report (optional)
install.packages("jsonlite")
```

---

## Validation Checklist

Before running your analysis, verify the following:

### Configuration

- [ ] Settings sheet has `data_file` and `analysis_type` filled in.
- [ ] Attributes sheet has at least 2 attributes, each with at least 2 levels.
- [ ] `NumLevels` matches the count of comma-separated values in `LevelNames` for every row.
- [ ] Column mapping settings match your data file column names exactly.

### Data

- [ ] Data file exists and is readable at the path specified.
- [ ] All required columns are present (respondent ID, choice set, chosen indicator, all attribute columns).
- [ ] Column names match the Settings sheet exactly (case-sensitive).
- [ ] Level values in the data match the Attributes sheet LevelNames exactly (case-sensitive).
- [ ] Each choice set has exactly one `chosen = 1`.
- [ ] No missing values in attribute columns.
- [ ] No duplicate (respondent, choice_set, alternative) combinations.

### Output

- [ ] Output directory exists.
- [ ] No existing output file is locked/open in another application.

---

**Turas Conjoint Module v3.0.0**
**The Research LampPost (Pty) Ltd**
