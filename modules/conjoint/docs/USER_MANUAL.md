# Turas Conjoint Module -- User Manual

**Version:** 3.1.0
**Last Updated:** March 2026
**Template:** `examples/conjoint/Conjoint_Config_Template.xlsx` (6 sheets)

---

## Table of Contents

1. [Introduction to Conjoint Analysis](#1-introduction-to-conjoint-analysis)
2. [Study Design Considerations](#2-study-design-considerations)
3. [Which Estimation Method to Use](#3-which-estimation-method-to-use)
4. [Step-by-Step Guide](#4-step-by-step-guide)
5. [Configuration Reference](#5-configuration-reference)
6. [Interpreting Results](#6-interpreting-results)
7. [HTML Report Guide](#7-html-report-guide)
8. [Market Simulator Guide](#8-market-simulator-guide)
9. [Revenue Simulator](#9-revenue-simulator)
10. [Product Optimizer](#10-product-optimizer)
11. [Willingness to Pay](#11-willingness-to-pay)
12. [Alchemer Data Import](#12-alchemer-data-import)
13. [Pre-flight Validation](#13-pre-flight-validation)
14. [Potential Issues and Troubleshooting](#14-potential-issues-and-troubleshooting)
15. [Package Dependencies](#15-package-dependencies)

---

## What's New in Version 3.1.0

This release adds several features to the HTML report and simulator. Here is a summary of the key changes:

- **Revenue Simulator** -- A new simulator tab that shows revenue per product alongside market share. Configure a customer count and see Revenue = Price x Share% x Customers for each product.
- **Scale factor slider** -- Calibrate simulated shares to real-world market data by adjusting a scale factor (0.1--3.0) in the HTML simulator.
- **Purchase Likelihood method** -- A new simulation method where each product gets an independent purchase probability (they do not sum to 100%). Useful when products are not direct substitutes.
- **Dot plot chart option** -- Toggle between horizontal bar charts and dot plots on the Utilities tab. Your preference persists as you move between attributes.
- **Per-attribute sticky notes** -- Add analysis notes to individual attributes on the Utilities tab. Notes are saved when you navigate away and reappear when you return.
- **Per-mode simulator annotations** -- Write notes that stick to each simulator mode (Market Shares, Revenue, Sensitivity, Source of Volume).
- **WTP auto-detection** -- The module now auto-detects price attributes by looking for attribute names containing "price", "cost", or "fee". You no longer need to set `wtp_price_attribute` manually (though you still can).
- **Snapshot-based pins** -- Pin multiple independent simulator views. Each pin is a full snapshot of the current configuration, so you can compare different scenarios side by side.
- **Pre-flight check** -- Run `conjoint_preflight()` to validate that all module files, packages, and infrastructure are in place before starting an analysis.
- **HB convergence diagnostics in plain language** -- The Diagnostics tab now explains convergence results in non-technical terms, including what to do if the model has not converged.
- **Method Reference Guide** -- An expandable table in the Diagnostics tab comparing all estimation and simulation methods at a glance.
- **Stats primers** -- Each simulator mode includes an expandable "How does it work?" section explaining the method in plain language.
- **Custom slides with image import** -- Insert images from your computer into custom slides. Images are automatically compressed for fast loading.
- **Config template** -- A ready-to-use 6-sheet config template is available at `examples/conjoint/Conjoint_Config_Template.xlsx`.
- **`default_customers` config setting** -- Set the starting customer count for the Revenue Simulator in the Settings sheet.

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
- **Revenue modelling:** Given predicted shares and a customer base, what revenue does each product generate?
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
| **Scale factor** | A multiplier applied to utilities before computing shares, used to calibrate predictions to real market data |

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

Copy `examples/conjoint/Conjoint_Config_Template.xlsx` to your project folder and edit the Settings and Attributes sheets. This 6-sheet template includes Settings, Attributes, Custom_Slides, Custom_Images, Design, and Instructions.

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

### Step 5: Validate Before Running (Recommended)

Before running the full analysis, use the pre-flight check to confirm everything is in order:

```r
source("modules/conjoint/R/00_main.R")
conjoint_preflight(verbose = TRUE)
```

This validates all module files, required packages, and infrastructure. See [Pre-flight Validation](#13-pre-flight-validation) for details.

### Step 6: Run the Analysis

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

### Step 7: Interpret Results

The analysis produces:

- An **Excel workbook** with Utilities, Relative_Importance, Model_Summary, and Market Simulator sheets.
- An **HTML report** (if `generate_html_report = TRUE`) with interactive charts, a built-in market and revenue simulator, and annotation tools.
- A **results object** in R with all computed outputs.

See [Interpreting Results](#6-interpreting-results) for detailed guidance.

### Step 8: Use the Market Simulator

The Market Simulator sheet in the output workbook lets you configure hypothetical products and see predicted market shares. The HTML report includes a richer interactive simulator with revenue modelling, sensitivity analysis, and scenario pinning. See [Market Simulator Guide](#8-market-simulator-guide) and [Revenue Simulator](#9-revenue-simulator) for full instructions.

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

A ready-to-use template with all six sheets is available at `examples/conjoint/Conjoint_Config_Template.xlsx`.

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
| `wtp_price_attribute` | (none) | Name of the price attribute. **Leave blank for auto-detection** -- the module looks for attribute names containing "price", "cost", or "fee". | An attribute name from the Attributes sheet, or blank |
| `wtp_method` | `marginal` | WTP calculation method | `marginal` or `simulation` |
| `currency_symbol` | `$` | Currency symbol for WTP display | Any text (e.g., `$`, `R`, `EUR`) |

#### Market Simulator

| Setting | Default | Description | Valid Values |
|---------|---------|-------------|--------------|
| `generate_market_simulator` | `TRUE` | Include an interactive market simulator sheet in the Excel output | `TRUE` or `FALSE` |
| `simulation_method` | `logit` | Method for computing predicted market shares | `logit`, `first_choice`, or `rfc` |
| `rfc_draws` | `1000` | Number of random draws for the Randomised First Choice method | Integer >= 100 |

#### Revenue Simulator

| Setting | Default | Description | Valid Values |
|---------|---------|-------------|--------------|
| `default_customers` | `1000` | Default hypothetical customer count for the Revenue Simulator tab. Users can change this in the HTML report. | Positive integer |

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
| `include_custom_images` | `FALSE` | Allow image import in custom slides (images are auto-compressed) | `TRUE` or `FALSE` |

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

### Custom_Slides Sheet

For adding custom content panels to the HTML report. This is useful for adding methodology notes, appendices, or supporting charts from other tools.

| Column | Required | Description |
|--------|----------|-------------|
| `Slide Title` | Yes | Title displayed at the top of the slide |
| `Content` | Yes | Body text in Markdown format |
| `Image Path` | No | Path to an image file to embed. Images are automatically compressed (max 800px wide, JPEG quality 0.7). You can also insert images from the file picker in the HTML report itself. |
| `Position` | No | Ordering position (lower numbers appear first) |

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

**Plain-language guidance in the HTML report:** The Diagnostics tab now provides non-technical explanations alongside every convergence metric. If the model has not converged, the report explains what that means in practical terms and recommends specific actions (such as increasing iterations or checking for problematic data). You do not need to be a statistician to understand the diagnostic output.

[Screenshot: HB convergence diagnostics with plain-language trust callout and recommended actions]

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

## 7. HTML Report Guide

When `generate_html_report = TRUE`, Turas produces a single self-contained HTML file with all analysis panels and interactive tools. Open it in any modern browser -- no internet connection or server required.

### Report Panels

The report is organised into tabbed panels. Use the tabs at the top, or navigate with keyboard shortcuts (arrow keys, number keys).

#### Overview

Summary of the analysis: key performance indicators, an attribute importance chart, and a top-level callout highlighting the most and least important attributes.

[Screenshot: Overview panel with KPI cards and importance chart]

#### Utilities

Detailed part-worth utility charts and data tables for each attribute. Two display options are available:

- **Bar chart** (default) -- Horizontal bars showing utility values for each level.
- **Dot plot** -- A cleaner alternative that shows utility values as dots on a number line. Better for attributes with many levels.

Toggle between chart types using the control at the top of the panel. Your preference persists as you move between attributes.

[Screenshot: Utility chart with bar/dot toggle control]

**Per-attribute sticky notes:** Each attribute has a note field where you can record analysis observations. Click the note icon next to the attribute name to open it. Notes are saved automatically and reappear when you return to that attribute. A badge appears on attributes that have notes, so you can see at a glance where you have left comments.

[Screenshot: Sticky note open on an attribute with badge visible on another attribute]

#### Diagnostics

Model fit statistics with trust verdicts (good, acceptable, poor), estimation method explanation, and a breakdown of what each metric means.

**HB convergence diagnostics** are presented with plain-language guidance. Instead of raw numbers, the report tells you whether your model has converged and, if not, what to do about it.

**Method Reference Guide:** An expandable table that compares all estimation methods (MNL, HB, Latent Class, etc.) and all simulation methods (Logit, RFC, Purchase Likelihood, First Choice) at a glance. This is a quick reference when you need to decide which method to use or explain your choice to a stakeholder.

[Screenshot: Diagnostics panel with trust callout and expandable Method Reference Guide]

#### WTP (Willingness to Pay)

A bar chart with confidence interval whiskers showing how much respondents are willing to pay for each attribute level relative to the baseline. This tab appears automatically when a price attribute is detected.

**New in 3.1.0:** WTP auto-detection means this tab will appear even if you did not manually set `wtp_price_attribute`. The module looks for attributes named "Price", "Cost", "Fee", or similar.

#### Latent Class

Appears when `estimation_method = "latent_class"`. Shows BIC comparison across class solutions, class size chart, per-class importance profiles, and comparison tables.

#### Simulator

The interactive market simulator. See [Market Simulator Guide](#8-market-simulator-guide) and [Revenue Simulator](#9-revenue-simulator) for detailed instructions.

#### Custom Slides

Appears when `include_custom_slides = TRUE`. Displays the custom content panels defined in the Custom_Slides sheet. Each slide has a title, body text (Markdown), and an optional image.

**Image import:** If `include_custom_images = TRUE`, you can insert additional images from a file picker directly in the HTML report. Imported images are automatically compressed for fast loading (max 800px wide, JPEG quality 0.7).

[Screenshot: Custom slide with imported image]

#### Pinned Items

Collect important views for a summary or presentation. The pin system works in two ways:

- **Standard pins:** On most panels, clicking the pin icon saves a reference to that panel's current state.
- **Snapshot-based pins (simulator):** On the Simulator tab, each pin is a **full independent snapshot** of your current product configuration and simulation results. You can pin multiple different scenarios and compare them side by side. Changing the simulator after pinning does not affect previously pinned snapshots.

[Screenshot: Pinned Items panel showing two simulator snapshots and one utility chart pin]

#### About

Analyst contact information, closing notes (editable), and branding details.

### Interactive Features

| Feature | How to Use |
|---------|------------|
| **Keyboard navigation** | Arrow keys or number keys to switch tabs |
| **Chart type toggle** | Switch between bar and dot plots on the Utilities tab |
| **Per-attribute sticky notes** | Click the note icon on any attribute to add observations |
| **Per-mode simulator annotations** | Write notes that persist separately for each simulator mode |
| **Export** | PNG, CSV, and Excel export from any panel using the export controls |
| **Pin** | Click the pushpin icon to save a view to the Pinned Items panel |
| **Scale factor** | Adjust the slider on the Market Shares or Revenue tab to calibrate shares |
| **Insight text** | Editable text areas on each panel for analyst commentary |
| **Help overlay** | Press `?` or click the help icon for keyboard shortcut reference |
| **Save report** | Use the Save button (File System Access API with download fallback) |
| **Print** | Print-optimized CSS with targeted print for pinned items and slides |

---

## 8. Market Simulator Guide

The market simulator is one of the most valuable outputs of conjoint analysis. It lets you define hypothetical products and predict their market shares.

### What the Simulator Does

The simulator uses the estimated part-worth utilities to calculate a total utility for each defined product, then converts these utilities into predicted market shares using a choice probability model.

### How to Set Up Products

**In the Excel workbook:**

1. Each column (Product 1 through Product 5) represents one product.
2. Each row represents an attribute.
3. Use the dropdown menus to select the level for each attribute for each product.
4. Leave a product column blank to exclude it from the simulation.

**In the HTML report:**

1. Click the **Simulator** tab, then select the **Market Shares** mode.
2. Configure each product by selecting attribute levels from the dropdowns.
3. Results update instantly as you change selections.

[Screenshot: HTML simulator with product configuration dropdowns and share bar chart]

### Simulation Methods

The simulator supports four methods. You can switch between them in the HTML report using the method dropdown.

| Method | Description | Shares Sum to 100%? |
|--------|-------------|---------------------|
| **Logit (MNL)** | Shares proportional to exp(utility). The standard and most commonly used method. Accounts for similarity between products. | Yes |
| **First Choice** | Each respondent is assigned 100% to the product with the highest utility. Simple but ignores the degree of preference. | Yes |
| **Randomised First Choice (RFC)** | Adds random error to utilities before applying first-choice rule. Produces more realistic shares than pure first choice. | Yes |
| **Purchase Likelihood** | Converts each product's utility to an independent purchase probability. Useful when products are not direct substitutes (e.g., add-on services). | **No** -- each product gets its own probability independently |

**Logit share formula:**

```
Share_j = exp(Utility_j) / Sum(exp(Utility_k)) for all products k
```

**When to use Purchase Likelihood:** Use this method when the products in your scenario are not mutually exclusive. For example, if you are simulating add-on features or complementary services where a customer might choose more than one, Purchase Likelihood gives you the independent probability of each product being selected. Because the probabilities are independent, they will not sum to 100%.

[Screenshot: Purchase Likelihood mode showing independent probabilities]

### Scale Factor

The **scale factor slider** (0.1 to 3.0) lets you calibrate simulated shares to match real-world market data. The scale factor multiplies all utilities before computing shares:

- **At 1.0** (default): No adjustment. Shares reflect the raw model estimates.
- **Above 1.0**: Amplifies differences between products. The leading product gets a larger share, and trailing products get smaller shares.
- **Below 1.0**: Compresses differences. Shares move closer to equal.

**When to use the scale factor:** If you have external market data (e.g., known brand shares), adjust the scale factor until the simulated shares roughly match the observed shares. This calibrates the simulator to be more realistic for "what if" scenarios.

[Screenshot: Scale factor slider set to 1.5 with adjusted share bars]

### Sensitivity Analysis

The **Sensitivity** mode shows how market share changes when you vary one attribute level at a time for a selected product. This helps identify which feature changes have the largest impact on competitive position.

1. Select a product to analyse.
2. Select an attribute to sweep.
3. The chart shows the predicted share for each possible level of that attribute, holding all other products constant.

[Screenshot: Sensitivity chart showing share vs. price level for Product 1]

### Source of Volume

The **Source of Volume** mode shows what happens when a new product enters the market. It compares the "before" shares (without the new product) to the "after" shares (with the new product), showing which competitors lose the most volume.

[Screenshot: Source of Volume before/after comparison bars]

### Per-Mode Annotations

Each simulator mode (Market Shares, Revenue, Sensitivity, Source of Volume) has its own annotation text field. Notes you write in one mode stay with that mode and do not appear in others. Use this to record observations about specific scenarios.

### Pinning Simulator Views

Click the pushpin icon to save the current simulator view as a snapshot. Each pin captures:

- The product configurations
- The selected simulation method and scale factor
- The resulting shares and charts

You can pin multiple views from different modes and compare them in the Pinned Items panel. Each pin is independent -- changing the simulator afterwards does not affect previously pinned snapshots.

---

## 9. Revenue Simulator

The **Revenue** tab in the HTML simulator goes beyond market share to estimate revenue for each product. It appears automatically when a price attribute is detected in your study.

### What It Shows

[Screenshot: Revenue Simulator with stacked horizontal bars showing share and revenue per product]

- **Stacked horizontal bars** for each product, showing both market share and revenue side by side.
- A **summary table** with per-product breakdown: price, share %, estimated customer count, and revenue.
- A **total revenue** row summarising the entire market scenario.

### How Revenue Is Calculated

```
Revenue = Price x Share% x Customers
```

Where:

- **Price** is the price level selected for each product in the simulator.
- **Share%** is the predicted market share from the current simulation method.
- **Customers** is the hypothetical customer base you specify.

### Setting the Customer Count

- **Default value:** Set via `default_customers` in the Settings sheet (default is 1,000).
- **In the HTML report:** Edit the customer count field directly. The revenue figures update instantly.

### Practical Uses

- **Compare product line revenue:** See which product configuration generates the most total revenue, not just the highest share.
- **Price optimisation:** A higher price reduces share but may increase revenue. The Revenue tab lets you see the net effect.
- **Portfolio planning:** Configure all products in a planned portfolio and see total market revenue.

### Example

Suppose you have three products:

| Product | Price | Share | Customers | Revenue |
|---------|-------|-------|-----------|---------|
| Economy | $299 | 45% | 10,000 | $1,345,500 |
| Standard | $499 | 35% | 10,000 | $1,746,500 |
| Premium | $699 | 20% | 10,000 | $1,398,000 |

Even though Economy has the highest share, Standard generates the most revenue due to its higher price. This kind of insight is the purpose of the Revenue Simulator.

---

## 10. Product Optimizer

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

## 11. Willingness to Pay

### What WTP Provides

Willingness to Pay translates utility differences into monetary values. Instead of saying "Apple has 0.45 more utility than the average," you can say "respondents would pay $85 more for an Apple phone."

### Requirements

- A **price attribute** must be defined in your study with numeric levels (e.g., $299, $399, $499).
- The module auto-detects price attributes by looking for attribute names containing **"price"**, **"cost"**, or **"fee"** (case-insensitive). If your price attribute uses a different name, set `wtp_price_attribute` explicitly in the config file.

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
| `wtp_price_attribute` | (none) | Name of the price attribute. Leave blank for auto-detection. |
| `wtp_method` | `marginal` | `marginal` (ratio method) or `simulation` (simulation-based) |
| `currency_symbol` | `$` | Currency symbol for display |

---

## 12. Alchemer Data Import

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

## 13. Pre-flight Validation

Before running a full analysis, you can validate that the module is correctly set up using the pre-flight check. This catches common problems early.

### Running the Pre-flight Check

```r
source("modules/conjoint/R/00_main.R")
conjoint_preflight(verbose = TRUE)
```

Or include it as part of your analysis run:

```r
results <- run_conjoint_analysis(
  config_file = "my_config.xlsx",
  run_preflight = TRUE
)
```

### What It Validates

| Check | What It Looks For |
|-------|-------------------|
| **R source files** | Verifies all 20 expected R files are present |
| **JavaScript files** | Verifies all 7 JS modules for the HTML report |
| **HTML report files** | Verifies all 7 report generator R files |
| **Required packages** | Checks that mlogit, survival, openxlsx, data.table, jsonlite are installed |
| **Optional packages** | Checks bayesm (for HB/Latent Class) and coda, reports status but does not fail |
| **JS syntax** | Runs `node --check` on JavaScript files if Node.js is available |
| **TRS infrastructure** | Confirms the refusal system (conjoint_refuse, refusal handler) is loaded |

### When to Run It

- **Before your first analysis** on a new machine or after updating Turas.
- **After updating packages** to verify nothing was broken.
- **When troubleshooting** an analysis that fails unexpectedly.

The pre-flight check runs in seconds and provides clear pass/fail output for each component.

---

## 14. Potential Issues and Troubleshooting

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

### WTP Not Appearing in Output

**Cause:** No price attribute was detected.

**Solutions:**

1. Check that one of your attributes has "price", "cost", or "fee" in its name (auto-detection is case-insensitive).
2. If your price attribute has an unusual name, set `wtp_price_attribute` explicitly in the config.
3. Ensure the price attribute has numeric level values.

### Scale Factor Has No Effect

**Cause:** Scale factor only applies to the Market Shares and Revenue tabs in the HTML simulator.

**Solutions:**

1. Confirm you are on the Market Shares or Revenue tab.
2. At 1.0 (default), there is no change. Move the slider above or below 1.0 to see an effect.

### HTML Report Not Generated

**Solutions:**

1. Set `generate_html_report = TRUE` in the Settings sheet.
2. Ensure jsonlite is installed: `install.packages("jsonlite")`.
3. Run `conjoint_preflight()` to check for missing files or packages.

### Revenue Tab Not Appearing

**Cause:** The Revenue tab only appears when a price attribute is detected.

**Solutions:**

1. Ensure your study includes a price attribute (auto-detected or set via `wtp_price_attribute`).
2. Price levels must contain numeric values.

---

## 15. Package Dependencies

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
| **base64enc** | Base64 encoding for config-driven slide images | `include_custom_images = TRUE` |

### Installing All Dependencies

```r
# Core packages (required)
install.packages(c("dplyr", "openxlsx", "mlogit", "dfidx", "survival"))

# HB and latent class (optional)
install.packages(c("bayesm", "coda"))

# SPSS/Stata import (optional)
install.packages("haven")

# HTML report (optional)
install.packages(c("jsonlite", "base64enc"))
```

---

## Validation Checklist

Before running your analysis, verify the following:

### Pre-flight

- [ ] Run `conjoint_preflight(verbose = TRUE)` and confirm all checks pass.

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

### HTML Report (if enabled)

- [ ] `generate_html_report` is set to `TRUE`.
- [ ] jsonlite package is installed.
- [ ] If using custom slides with images: `include_custom_slides = TRUE` and `include_custom_images = TRUE`.
- [ ] If you want revenue simulation: verify a price attribute is present.

---

**Turas Conjoint Module v3.1.0**
**The Research LampPost (Pty) Ltd**
