# Turas Conjoint Analysis Module - User Manual

**Version:** 2.0.0
**Date:** 2025-11-27
**Status:** Production Ready

---

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Configuration Files](#configuration-files)
5. [Data Files](#data-files)
6. [Running an Analysis](#running-an-analysis)
7. [Understanding Results](#understanding-results)
8. [Market Simulator](#market-simulator)
9. [Advanced Features](#advanced-features)
10. [Troubleshooting](#troubleshooting)
11. [Best Practices](#best-practices)
12. [Reference](#reference)

---

## 1. Introduction

### What is Conjoint Analysis?

Conjoint analysis is a statistical technique used to understand how people value different features of a product or service. It helps answer questions like:

- Which features matter most to customers?
- How much would customers pay for a premium feature?
- What's the optimal product configuration?
- How will a new product perform against competitors?

### What Does This Module Do?

The Turas Conjoint Analysis Module provides:

✅ **Choice-Based Conjoint (CBC) Analysis** - Analyze discrete choice experiments
✅ **Part-Worth Utilities** - Calculate preference values for each feature level
✅ **Attribute Importance** - Determine which features matter most
✅ **Market Simulator** - Interactive Excel tool for what-if scenarios
✅ **Statistical Rigor** - Confidence intervals, significance tests, model diagnostics
✅ **Professional Output** - Formatted Excel workbooks with charts and insights

### Who Should Use This?

- Market researchers
- Product managers
- Marketing analysts
- Business analysts
- Anyone conducting product research or pricing studies

### Prerequisites

- Basic understanding of conjoint analysis concepts
- R version 4.0 or higher installed
- Familiarity with Excel
- Your conjoint study data in the correct format

---

## 2. Installation

### Step 1: Install R

If you don't have R installed:

**Windows:**
1. Download R from https://cloud.r-project.org/
2. Run the installer and follow prompts
3. Accept default settings

**Mac:**
1. Download R from https://cloud.r-project.org/
2. Open the .pkg file and install
3. Accept default settings

**Linux:**
```bash
sudo apt-get update
sudo apt-get install r-base
```

### Step 2: Install Required R Packages

Open R or RStudio and run:

```r
# Core packages (required)
install.packages(c(
  "mlogit",      # Choice model estimation
  "survival",    # Alternative estimation method
  "openxlsx",    # Excel file handling
  "dplyr",       # Data manipulation
  "tidyr"        # Data reshaping
))

# Optional packages (for additional features)
install.packages(c(
  "haven",       # SPSS/Stata file support
  "readxl"       # Excel reading (alternative)
))

# For Hierarchical Bayes (optional)
install.packages("bayesm")
```

**Installation should take 5-10 minutes.**

### Step 3: Verify Installation

Test that packages loaded correctly:

```r
library(mlogit)
library(survival)
library(openxlsx)
library(dplyr)
library(tidyr)

# If no errors, you're good to go!
```

### Step 4: Set Up Your Working Directory

```r
# Navigate to your Turas directory
setwd("/path/to/Turas")

# Verify you're in the right place
list.files("modules/conjoint/R")
# Should show: 00_main.R, 01_config.R, etc.
```

---

## 3. Quick Start

### Run the Example Analysis (5 Minutes)

The fastest way to see the module in action:

```r
# 1. Set working directory
setwd("/path/to/Turas")

# 2. Load all module files
source("modules/conjoint/R/99_helpers.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/09_none_handling.R")
source("modules/conjoint/R/02_data.R")
source("modules/conjoint/R/03_estimation.R")
source("modules/conjoint/R/04_utilities.R")
source("modules/conjoint/R/05_simulator.R")
source("modules/conjoint/R/08_market_simulator.R")
source("modules/conjoint/R/07_output.R")
source("modules/conjoint/R/00_main.R")

# 3. Run example analysis
results <- run_conjoint_analysis(
  config_file = "modules/conjoint/examples/example_config.xlsx"
)

# 4. View results
print(results$importance)
print(results$utilities)

# 5. Open Excel output
# Located at: modules/conjoint/examples/output/example_results.xlsx
```

**You should see:**
- Analysis completes in ~10 seconds
- Console shows 7 steps of progress
- Excel file created with 6-7 sheets
- Results include utilities, importance, and market simulator

**If this works, you're ready to analyze your own data!**

---

## 4. Configuration Files

### What is a Configuration File?

The configuration file (Excel format) tells the module:
- What type of analysis to run
- Where to find your data
- What attributes and levels you're testing
- Where to save results

### Creating a Configuration File

**Required: Excel file (.xlsx) with 2 sheets:**

#### Sheet 1: Settings

| Setting | Value | Description |
|---------|-------|-------------|
| analysis_type | choice | "choice" for CBC, "rating" for rating-based |
| estimation_method | auto | "auto", "mlogit", "clogit", or "hb" |
| data_file | path/to/data.csv | Path to your data file |
| output_file | path/to/results.xlsx | Where to save results |
| respondent_id_column | resp_id | Column name for respondent IDs |
| choice_set_column | choice_set_id | Column name for choice set IDs |
| chosen_column | chosen | Column name for chosen indicator (1/0) |
| confidence_level | 0.95 | For confidence intervals (0-1) |

**Optional Settings:**
- `baseline_handling`: "first_level_zero" (default) or "all_levels_explicit"
- `choice_type`: "single" (default), "single_with_none", "best_worst"
- `none_label`: "None of these" (label for none option)
- `alternative_id_column`: Column name for alternative IDs
- `generate_market_simulator`: TRUE/FALSE - create interactive simulator
- `include_diagnostics`: TRUE/FALSE - include detailed diagnostics

#### Sheet 2: Attributes

| AttributeName | AttributeLabel | NumLevels | Level1 | Level2 | Level3 | Level4 |
|---------------|----------------|-----------|--------|--------|--------|--------|
| Brand | Brand | 3 | Apple | Samsung | Google | |
| Price | Price | 4 | $299 | $399 | $499 | $599 |
| Size | Screen Size | 2 | 5.5" | 6.7" | | |

**Rules:**
- `AttributeName`: Must match column names in your data (no spaces, use underscores)
- `AttributeLabel`: Display name for output (can have spaces)
- `NumLevels`: Number of levels for this attribute
- `Level1`, `Level2`, etc.: Actual level values (must match data exactly)

### Example Configuration Files

The module includes example configs:
- `modules/conjoint/examples/example_config.xlsx` - Smartphone CBC study

You can copy and modify these for your own studies.

---

## 5. Data Files

### Data File Format

Your data file should be in **long format** (one row per alternative per choice set).

### Supported File Types

- **CSV** (.csv) - Recommended for large datasets
- **Excel** (.xlsx) - Easy to prepare
- **SPSS** (.sav) - Requires `haven` package
- **Stata** (.dta) - Requires `haven` package

### Required Columns

Your data MUST have these columns (names can be customized in config):

1. **Respondent ID** - Unique identifier for each respondent
2. **Choice Set ID** - Identifies each choice task
3. **Chosen** - Binary indicator (1 = chosen, 0 = not chosen)
4. **Attribute columns** - One column per attribute (names must match config)

**Optional:**
- **Alternative ID** - Identifies alternatives within choice sets

### Example Data Structure

```csv
resp_id,choice_set_id,alternative_id,Brand,Price,Size,chosen
1,1,1,Apple,$399,6.7",1
1,1,2,Samsung,$299,5.5",0
1,1,3,Google,$499,6.7",0
1,2,1,Samsung,$599,5.5",0
1,2,2,Apple,$299,6.7",1
1,2,3,Google,$399,5.5",0
```

### Data Requirements

✅ **One chosen per choice set** - Exactly 1 row with chosen=1 per choice_set_id
✅ **Consistent alternatives** - Same number of alternatives in each choice set (typically 3-5)
✅ **Matching levels** - Attribute values must exactly match config Level1, Level2, etc.
✅ **No missing values** - All required columns must be complete
✅ **Binary chosen** - Only 0 and 1 allowed in chosen column

### Data Validation

The module automatically checks your data and reports:

- **Critical errors** (analysis stops) - Missing columns, invalid values, etc.
- **Warnings** (analysis continues) - Low sample size, unbalanced design, etc.
- **Info messages** - Data statistics, none option detection, etc.

---

## 6. Running an Analysis

### Basic Workflow

```r
# Set working directory
setwd("/path/to/Turas")

# Load modules (do this once per session)
source("modules/conjoint/R/99_helpers.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/09_none_handling.R")
source("modules/conjoint/R/02_data.R")
source("modules/conjoint/R/03_estimation.R")
source("modules/conjoint/R/04_utilities.R")
source("modules/conjoint/R/05_simulator.R")
source("modules/conjoint/R/08_market_simulator.R")
source("modules/conjoint/R/07_output.R")
source("modules/conjoint/R/00_main.R")

# Run analysis
results <- run_conjoint_analysis(
  config_file = "path/to/your_config.xlsx"
)

# That's it! Results are saved to Excel automatically.
```

### What Happens During Analysis?

The module executes 7 steps:

**Step 1: Load Configuration**
- Reads Settings and Attributes sheets
- Validates configuration
- Reports any issues

**Step 2: Load and Validate Data**
- Reads your data file
- Runs 3-tier validation (Critical/Warning/Info)
- Calculates data statistics
- Detects none options if present

**Step 3: Estimate Choice Model**
- Auto-selects best estimation method (mlogit or clogit)
- Estimates model coefficients
- Checks convergence

**Step 4: Calculate Part-Worth Utilities**
- Converts coefficients to utilities
- Zero-centers within each attribute
- Calculates confidence intervals
- Tests significance

**Step 5: Calculate Attribute Importance**
- Determines relative importance of each attribute
- Ranks attributes
- Assigns importance percentages (sum to 100%)

**Step 6: Run Model Diagnostics**
- Calculates McFadden R², hit rate, AIC/BIC
- Assesses model quality
- Checks for issues

**Step 7: Generate Excel Output**
- Creates formatted Excel workbook
- Generates charts and visualizations
- Creates market simulator (if enabled)

### Typical Run Time

- **Small dataset** (50 respondents, 8 choice sets): ~5-10 seconds
- **Medium dataset** (200 respondents, 10 choice sets): ~20-30 seconds
- **Large dataset** (500+ respondents, 12+ choice sets): ~1-2 minutes

### Command-Line Options

**Override paths:**
```r
results <- run_conjoint_analysis(
  config_file = "my_config.xlsx",
  data_file = "different_data.csv",  # Override data path
  output_file = "custom_results.xlsx"  # Override output path
)
```

**Silent mode:**
```r
results <- run_conjoint_analysis(
  config_file = "my_config.xlsx",
  verbose = FALSE  # No progress messages
)
```

### Viewing Results

After analysis completes:

```r
# View attribute importance
print(results$importance)

# View utilities
print(results$utilities)

# View model diagnostics
print(results$diagnostics$fit_statistics)

# Get specific values
top_attribute <- results$importance$Attribute[1]
mcfadden_r2 <- results$diagnostics$fit_statistics$mcfadden_r2
```

---

## 7. Understanding Results

### Excel Output Structure

The analysis creates an Excel workbook with 6-7 sheets:

#### Sheet 1: Executive Summary

**Purpose:** One-page overview for stakeholders

**Contains:**
- Study information (sample size, method, date)
- Top 3 most important attributes
- Model quality assessment
- Key statistics

**Use this for:** Quick summaries, presentations to non-technical audiences

#### Sheet 2: Attribute Importance

**Purpose:** Shows which attributes matter most to respondents

**Columns:**
- **Attribute**: Attribute name
- **Importance**: Percentage importance (sum = 100%)
- **Rank**: 1 = most important
- **Range**: Utility range for this attribute
- **Interpretation**: Plain-language explanation

**How to read:**
- Higher importance % = more important in choice decisions
- Importance shows *relative* importance only
- A 30% attribute is twice as important as a 15% attribute

**Example:**
```
Rank | Attribute      | Importance | Interpretation
-----|----------------|------------|----------------------------------
1    | Price          | 35.2%      | Price is the most important factor
2    | Brand          | 28.7%      | Brand is a very important factor
3    | Camera_Quality | 16.8%      | Camera quality notably influences choice
```

#### Sheet 3: Part-Worth Utilities

**Purpose:** Shows preference value for each attribute level

**Columns:**
- **Attribute**: Attribute name
- **Level**: Specific level (e.g., "Apple", "$299")
- **Utility**: Zero-centered preference value
- **Std Error**: Standard error of estimate
- **CI Lower/Upper**: 95% confidence interval
- **P-value**: Statistical significance
- **Significance**: Stars (*** = p<0.001, ** = p<0.01, * = p<0.05)
- **Interpretation**: Plain-language explanation

**How to read utilities:**
- **Positive utility** = preferred over baseline
- **Negative utility** = less preferred than baseline
- **Zero** = baseline or neutral
- **Larger absolute value** = stronger preference/aversion
- Utilities are **zero-centered within each attribute**

**Example:**
```
Attribute | Level  | Utility | Std Error | CI Lower | CI Upper | P-value | Sig | Interpretation
----------|--------|---------|-----------|----------|----------|---------|-----|---------------------------
Price     | $299   |  1.25   |   0.08    |   1.09   |   1.41   | <0.001  | *** | Strongly preferred
Price     | $399   |  0.42   |   0.07    |   0.28   |   0.56   | <0.001  | *** | Moderately preferred
Price     | $499   | -0.32   |   0.07    |  -0.46   |  -0.18   | <0.001  | *** | Moderately avoided
Price     | $599   | -1.35   |   0.09    |  -1.53   |  -1.17   | <0.001  | *** | Strongly avoided
```

**Conditional Formatting:**
- Green cells = positive utilities (preferred)
- Red cells = negative utilities (avoided)

#### Sheet 4: Model Diagnostics

**Purpose:** Assess model quality and fit

**Key Metrics:**

**McFadden R² (Pseudo R-squared):**
- Similar to R² in regression
- Measures model fit (0 to 1 scale)
- **Excellent:** >0.4
- **Good:** 0.2-0.4
- **Fair:** 0.1-0.2
- **Poor:** <0.1

**Hit Rate:**
- % of choices correctly predicted
- Compare to chance rate (e.g., 33% for 3 alternatives)
- Good model should be well above chance

**AIC/BIC:**
- Information criteria (lower is better)
- Use for comparing different models
- Not interpretable in absolute terms

**Convergence:**
- Should show "Yes" or "Converged"
- If not converged, results may be unreliable

#### Sheet 5: Market Simulator (if enabled)

**Purpose:** Interactive tool for testing product concepts

See [Market Simulator](#market-simulator) section below.

#### Sheet 6: Data Summary

**Purpose:** Data quality and validation results

**Contains:**
- Sample size statistics
- Validation warnings and info messages
- None option details
- Choice set balance

**Use this for:** Quality control, identifying data issues

#### Sheet 7: Configuration

**Purpose:** Record of analysis settings for reproducibility

**Contains:**
- All settings used
- Attribute definitions
- Level names

**Use this for:** Documentation, reproducing analyses

---

## 8. Market Simulator

### What is the Market Simulator?

An interactive Excel tool that lets you:
- Configure product profiles using dropdown menus
- See predicted market shares instantly
- Test what-if scenarios
- Analyze sensitivity to different features

### How It Works

The simulator uses your estimated utilities to predict market shares via the **multinomial logit (MNL) model**:

```
Market Share(i) = exp(Utility_i) / sum(exp(Utility_j))
```

This is the same model used by industry-standard software like Sawtooth.

### Using the Market Simulator

#### Step 1: Enable the Simulator

In your configuration file Settings sheet:
```
generate_market_simulator = TRUE
```

#### Step 2: Run Your Analysis

The Excel output will include a "Market Simulator" sheet.

#### Step 3: Configure Products

**Product Configuration Section:**
- Use dropdown menus to select levels for each attribute
- Configure up to 5 products
- Changes update market shares instantly

**Example:**
```
Attribute      | Product 1  | Product 2  | Product 3
---------------|------------|------------|------------
Brand          | [Apple ▼]  | [Samsung▼] | [Google ▼]
Price          | [$299  ▼]  | [$399  ▼]  | [$499  ▼]
Screen Size    | [6.7"  ▼]  | [6.1"  ▼]  | [5.5"  ▼]
Battery Life   | [24h   ▼]  | [18h   ▼]  | [12h   ▼]
Camera Quality | [Excellent▼]| [Good  ▼]  | [Basic ▼]
```

#### Step 4: View Market Shares

**Market Share Results:**
```
Metric         | Product 1 | Product 2 | Product 3
---------------|-----------|-----------|------------
Total Utility  | 2.45      | 0.87      | -1.23
exp(Utility)   | 11.59     | 2.39      | 0.29
Market Share % | 81.2%     | 16.7%     | 2.1%
```

Shares always sum to 100%.

#### Step 5: Understand Utilities Breakdown

**Utilities Contributing to Choice:**
```
Attribute      | Product 1 | Product 2 | Product 3
---------------|-----------|-----------|------------
Brand          | 0.80      | 0.40      | 0.20
Price          | 1.20      | 0.40      | -0.30
Screen Size    | 0.60      | 0.00      | -0.60
Battery Life   | 0.80      | 0.00      | -0.80
Camera Quality | 0.70      | 0.00      | -0.70
---------------|-----------|-----------|------------
TOTAL          | 4.10      | 0.80      | -2.20
```

This shows how each attribute contributes to the total utility.

### Common Use Cases

**1. Optimize Your Product**
- Start with your current product (Product 1)
- Add competitors (Products 2-3)
- Test improvements: What if we lower price? Upgrade camera?
- Find the configuration that maximizes share

**2. New Product Concepts**
- Configure Product 4 with different features
- See predicted share against existing products
- Test multiple concepts

**3. Competitive Response**
- Configure Products 2-3 as competitor products
- Test: What if competitor lowers price?
- Find best response to maintain share

**4. Pricing Analysis**
- Keep all features constant
- Vary only price
- See how share changes with price
- Find optimal price point

**5. Feature Trade-offs**
- Test: "Better camera but higher price" vs. "Basic camera, lower price"
- Quantify feature value in terms of market share

### Important Assumptions

⚠️ The simulator assumes:
- All products are equally available
- Respondents know all options
- No outside option (must choose one)
- Preferences don't change over time
- No interaction effects (unless modeled)

These are standard assumptions in conjoint analysis.

### Tips for Using the Simulator

✅ **Do:**
- Test realistic product configurations
- Compare 2-3 products at a time (easier to understand)
- Focus on relative shares, not absolute numbers
- Use for directional insights

❌ **Don't:**
- Trust predictions for unrealistic configurations
- Over-interpret small share differences (<5%)
- Use as exact sales forecasts (use for relative comparisons)
- Forget to account for price, availability, awareness in real market

---

## 9. Advanced Features

### Interaction Effects

**What are interactions?**
When the effect of one attribute depends on another attribute.

**Example:** Price sensitivity might be different for luxury brands vs. budget brands.

**When to use:**
- You suspect non-additive effects
- You want to test if feature combinations create synergies
- Standard model fit is poor

**How to use:**
```r
# Source interaction module
source("modules/conjoint/R/06_interactions.R")

# Specify interactions
interaction_spec <- specify_interactions(
  attributes = c("Price", "Brand", "Size"),
  interactions = list(c("Price", "Brand")),  # Test Price × Brand
  auto_detect = FALSE
)

# Estimate model with interactions
result <- estimate_with_interactions(data_list, config, interaction_spec)

# Analyze specific interaction
interaction_analysis <- analyze_interaction(result, c("Price", "Brand"), config)
```

**Interpreting interactions:**
- Positive coefficient = attributes amplify each other
- Negative coefficient = attributes diminish each other
- Non-significant = effects are additive (no interaction)

### Best-Worst Scaling

**What is BWS?**
Instead of choosing the best alternative, respondents choose BOTH:
- Best alternative in the set
- Worst alternative in the set

**Advantages:**
- More information per choice task (2 choices vs. 1)
- Better discrimination between alternatives
- Can use fewer choice sets

**Data requirements:**
Your data needs `best` and `worst` columns (both binary 0/1).

**How to use:**
```r
# Source BWS module
source("modules/conjoint/R/10_best_worst.R")

# Validate your BWS data
validation <- validate_best_worst_data(data, config)

# Estimate BWS model
bws_result <- estimate_best_worst_model(
  data_list,
  config,
  method = "sequential"  # or "simultaneous"
)

# Calculate utilities
utils <- calculate_best_worst_utilities(bws_result, config)
```

**Methods:**
- **Sequential**: Estimate best and worst models separately, then combine
- **Simultaneous**: Joint estimation (requires more complex model)

### Hierarchical Bayes (HB)

**What is HB?**
Estimates individual-level utilities (not just aggregate) while borrowing strength across respondents.

**Advantages:**
- Individual-level utilities (see each person's preferences)
- Better for heterogeneous populations
- Can incorporate respondent demographics
- More stable with small samples

**Requirements:**
- `bayesm` or `RSGHB` package installed
- 30+ respondents recommended
- 8+ choice sets per respondent
- Longer computation time (minutes to hours)

**Current status:**
Framework implemented. Full implementation requires bayesm package integration.

**How to check readiness:**
```r
source("modules/conjoint/R/11_hierarchical_bayes.R")

# Check if packages available
check_hb_requirements()

# See implementation guidance
print_hb_guidance()
```

---

## 10. Troubleshooting

### Common Errors and Solutions

#### Error: "Required column 'chosen' not found in data"

**Cause:** Your data file doesn't have the column specified in config.

**Solution:**
1. Open your config file
2. Check the `chosen_column` setting
3. Open your data file
4. Ensure column name matches exactly (case-sensitive)

---

#### Error: "Each choice set must have exactly 1 chosen alternative"

**Cause:** Some choice sets have 0 or multiple chosen=1.

**Solution:**
1. Check your data for choice sets with multiple chosen=1
2. Check for choice sets with no chosen=1
3. If none chosen is intentional, configure none option handling

**Find problematic sets in R:**
```r
data %>%
  group_by(choice_set_id) %>%
  summarise(n_chosen = sum(chosen)) %>%
  filter(n_chosen != 1)
```

---

#### Error: "Attribute levels in data do not match configuration"

**Cause:** Level values in data don't match config exactly.

**Solution:**
1. Compare data values to config Level1, Level2, etc.
2. Check for:
   - Spelling differences ("Apple" vs. "apple")
   - Extra spaces (" Apple" vs. "Apple")
   - Different quotes ("$299" vs. "$299")

**Check in R:**
```r
# See unique values in your data
unique(data$Brand)

# Compare to config
config$attributes[config$attributes$AttributeName == "Brand", ]
```

---

#### Warning: "Low response count for level X"

**Cause:** Some level appears very rarely in your data.

**Impact:** Utility estimate may be unstable.

**Solution:**
- If intentional (rare level), accept the warning
- If unintentional, check your experimental design
- Consider combining rare levels with similar ones

---

#### Error: "mlogit estimation failed"

**Cause:** Model convergence issues, often due to:
- Perfect separation (some level always/never chosen)
- Too many parameters relative to sample size
- Multicollinearity

**Solution:**
1. Check for levels that are always or never chosen
2. Simplify model: Reduce attributes or levels
3. Increase sample size
4. Let module try fallback method:
   ```
   estimation_method = auto
   ```

---

#### Warning: "McFadden R² is low (0.08)"

**Cause:** Model doesn't fit data well.

**Possible reasons:**
- Missing important attributes
- Preferences are very heterogeneous
- Random choice behavior
- Interaction effects present but not modeled

**Solution:**
- Review attribute selection (are you testing the right features?)
- Check if respondents understood the task
- Consider interaction effects
- Note: R² of 0.1-0.2 is typical and acceptable in choice models

---

#### File not found errors

**Cause:** Path specified in config doesn't exist.

**Solution:**
1. Check file paths in config Settings sheet
2. Use absolute paths or ensure relative paths are correct
3. Verify working directory in R: `getwd()`

**Example of proper paths:**
```
# Relative (from Turas root)
data_file = modules/conjoint/examples/sample_cbc_data.csv

# Absolute
data_file = /Users/duncan/Documents/Turas/data/my_data.csv
```

---

### Getting Help

If you encounter issues not covered here:

1. **Check validation messages** - Often tell you exactly what's wrong
2. **Review your config file** - Most errors are configuration issues
3. **Examine your data** - Use `head(data)` and `summary(data)` in R
4. **Check the Quick Start Guide** - Step-by-step example
5. **Run the example** - Does `example_config.xlsx` work?
6. **Check specification files** - Full documentation in `modules/conjoint/Part*.md`

---

## 11. Best Practices

### Study Design

✅ **Do:**
- Use 4-6 attributes (optimal range)
- Keep 3-4 levels per attribute
- Test 8-12 choice sets per respondent
- Include 3-4 alternatives per choice set
- Randomize choice set order
- Balance attribute levels across choice sets

❌ **Don't:**
- Use >8 attributes (respondent burden)
- Use >6 levels per attribute (too many parameters)
- Use <6 choice sets (insufficient data)
- Create unrealistic profiles
- Test obviously dominated alternatives

### Data Preparation

✅ **Do:**
- Clean data before analysis (remove duplicates, speeders)
- Use consistent naming (no spaces in column names)
- Match level names exactly between config and data
- Check for missing values
- Verify one chosen per choice set
- Document your data structure

❌ **Don't:**
- Include respondents who failed attention checks
- Mix different studies in one dataset
- Use special characters in attribute/level names
- Leave missing values in required columns

### Configuration

✅ **Do:**
- Start with `estimation_method = auto`
- Use descriptive AttributeLabels
- Set `generate_market_simulator = TRUE`
- Document your settings
- Keep a backup of your config file

❌ **Don't:**
- Hard-code paths that won't work on other computers
- Use same AttributeName for different attributes
- Skip validation checks
- Forget to specify confidence_level

### Analysis

✅ **Do:**
- Review all validation messages
- Check model diagnostics (R², hit rate)
- Examine confidence intervals (wide CIs = unstable estimates)
- Look for non-significant levels
- Save your R console output
- Document any warnings or issues

❌ **Don't:**
- Ignore validation warnings
- Over-interpret small utility differences
- Trust results if model didn't converge
- Compare utilities across different attributes
- Use utilities as absolute measures (they're relative)

### Interpretation

✅ **Do:**
- Focus on attribute importance first
- Use utilities to understand preferences within attributes
- Check statistical significance
- Consider confidence intervals
- Use market simulator for what-if scenarios
- Report McFadden R² and hit rate

❌ **Don't:**
- Compare utilities across attributes directly
- Treat importance as absolute (it's relative)
- Over-interpret non-significant results
- Assume linear price response
- Forget about base rates and market conditions

---

## 12. Reference

### Quick Reference Card

**Load modules (once per session):**
```r
setwd("/path/to/Turas")
source("modules/conjoint/R/99_helpers.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/09_none_handling.R")
source("modules/conjoint/R/02_data.R")
source("modules/conjoint/R/03_estimation.R")
source("modules/conjoint/R/04_utilities.R")
source("modules/conjoint/R/05_simulator.R")
source("modules/conjoint/R/08_market_simulator.R")
source("modules/conjoint/R/07_output.R")
source("modules/conjoint/R/00_main.R")
```

**Run analysis:**
```r
results <- run_conjoint_analysis(
  config_file = "path/to/config.xlsx"
)
```

**View results:**
```r
print(results$importance)  # Attribute importance
print(results$utilities)   # Part-worth utilities
print(results$diagnostics$fit_statistics)  # Model fit
```

### Glossary

**Part-Worth Utility**: Preference value for a specific attribute level

**Attribute Importance**: Relative importance of an attribute in choice decisions (percentage, sum to 100%)

**Zero-Centering**: Adjusting utilities so they average to zero within each attribute

**Baseline**: Reference level within each attribute (utility = 0 before zero-centering)

**McFadden R²**: Pseudo R-squared for choice models (0 to 1, higher = better fit)

**Hit Rate**: Percentage of choices correctly predicted by the model

**Choice-Based Conjoint (CBC)**: Respondents choose from sets of alternatives

**None Option**: "None of these" alternative in choice sets

**Market Share**: Predicted percentage of market choosing each product

**Multinomial Logit (MNL)**: Statistical model for discrete choices

**Confidence Interval**: Range likely to contain true utility value (typically 95%)

**Convergence**: Model estimation reached stable solution

**Perfect Separation**: Some level is always or never chosen (causes estimation problems)

### File Locations

**Module Files:**
- Main entry: `modules/conjoint/R/00_main.R`
- Configuration: `modules/conjoint/R/01_config.R`
- All modules: `modules/conjoint/R/*.R`

**Examples:**
- Example config: `modules/conjoint/examples/example_config.xlsx`
- Example data: `modules/conjoint/examples/sample_cbc_data.csv`
- Test script: `modules/conjoint/examples/test_analysis.R`

**Documentation:**
- This manual: `modules/conjoint/USER_MANUAL.md`
- Tutorial: `modules/conjoint/TUTORIAL.md`
- Quick start: `modules/conjoint/examples/QUICK_START_GUIDE.md`
- Specifications: `modules/conjoint/Part*.md`
- Status: `modules/conjoint/IMPLEMENTATION_STATUS.md`

### Support Resources

- **Example files**: `modules/conjoint/examples/`
- **Test suite**: `modules/conjoint/tests/`
- **Specifications**: `modules/conjoint/Part*.md` (5 parts)
- **Implementation status**: `modules/conjoint/IMPLEMENTATION_STATUS.md`

### Version History

- **2.0.0** (2025-11-27): Enhanced implementation with Phase 3 features
  - Market simulator
  - Comprehensive tests
  - Advanced features (interactions, BWS, HB framework)
- **1.0.0** (2024-XX-XX): Initial basic implementation

---

**End of User Manual**

*For step-by-step tutorials, see TUTORIAL.md*
*For quick reference, see examples/QUICK_START_GUIDE.md*
