# Enhanced Turas Conjoint Analysis - User Manual

**Version:** 2.1.0 (Alchemer Integration + 8-Sheet Output)
**Date:** 2025-12-12
**Status:** Production Ready

---

## Overview

The Enhanced Turas Conjoint Analysis module calculates part-worth utilities and attribute importance from choice-based or rating-based conjoint experimental data.

### Key Features

- **Alchemer CBC Import**: Direct import of Alchemer choice-based conjoint exports (NEW in v2.1)
- **Multi-method estimation**: Auto-selects best method (mlogit → clogit fallback)
- **Comprehensive validation**: 3-tier validation (Critical/Warning/Info)
- **None option handling**: Auto-detects "none of these" options
- **Statistical rigor**: Confidence intervals, p-values, significance testing
- **Professional output**: 8-sheet Excel workbook with interactive Market Simulator
- **User-friendly**: Clear error messages and progress reporting

### What's New in v2.1

- **Direct Alchemer Import**: No more manual data transformation! Import raw Alchemer CBC exports directly
- **Auto Level Cleaning**: Alchemer level names like "Low_071" automatically cleaned to "Low"
- **Enhanced mlogit Support**: Improved diagnostics and better error handling
- **Zero-Centering Options**: Configurable utility centering methods
- **8-Sheet Excel Output**: Market Simulator, Attribute Importance, Part-Worth Utilities, Utility Chart Data, Model Fit, Configuration, Raw Coefficients, Data Summary
- **Market Simulator**: Always generated as primary deliverable for client what-if analysis

### What You Need

- **R** (version 4.0+)
- **Required R packages**: mlogit, survival, openxlsx, dplyr, tidyr
- **Your data**: Choice-based or rating-based conjoint data
- **Configuration file**: Excel file defining your study design

---

## Installation

### 1. Install Required R Packages

```r
# Core packages (required)
install.packages(c(
  "mlogit",      # Primary estimation engine
  "survival",    # Fallback clogit method
  "openxlsx",    # Excel I/O
  "dplyr",       # Data manipulation
  "tidyr"        # Data reshaping
))

# Optional packages (for advanced features)
install.packages(c(
  "haven",       # SPSS/Stata file support
  "boot"         # Bootstrap confidence intervals
))
```

### 2. Load the Module

```r
# Set working directory to Turas root
setwd("/path/to/Turas")

# Source all module files in order
source("modules/conjoint/R/99_helpers.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/09_none_handling.R")
source("modules/conjoint/R/02_data.R")
source("modules/conjoint/R/03_estimation.R")
source("modules/conjoint/R/04_utilities.R")
source("modules/conjoint/R/07_output.R")
source("modules/conjoint/R/00_main.R")
```

**Tip:** Create a startup script to automate this!

---

## Quick Start Example

### Run the Pre-Built Example

We've included a complete example with sample data:

```r
# 1. Load the module (see Installation above)

# 2. Run the example analysis
results <- run_conjoint_analysis(
  config_file = "modules/conjoint/examples/example_config.xlsx"
)

# 3. View results
print(results$importance)      # Attribute importance
print(results$utilities)        # Part-worth utilities
print(results$diagnostics)      # Model diagnostics

# 4. Check the output Excel file
# Located at: modules/conjoint/examples/output/example_results.xlsx
```

This example analyzes a smartphone conjoint study with:
- 5 attributes (Brand, Price, Screen Size, Battery Life, Camera Quality)
- 50 respondents
- 8 choice sets per respondent
- 3 alternatives per choice set

---

## Configuration File Format

The configuration file is an Excel workbook (`.xlsx`) with two required sheets:

### Sheet 1: Settings

| Setting | Value | Description |
|---------|-------|-------------|
| analysis_type | "choice" | Analysis type: "choice" or "rating" |
| estimation_method | "auto" | Method: "auto", "mlogit", "clogit", or "hb" |
| baseline_handling | "first_level_zero" | "first_level_zero" or "all_levels_explicit" |
| choice_type | "single" | "single", "single_with_none", "best_worst", "continuous_sum" |
| data_file | "path/to/data.csv" | Path to your data file (relative or absolute) |
| output_file | "path/to/results.xlsx" | Path for output Excel file |
| respondent_id_column | "resp_id" | Column name for respondent IDs |
| choice_set_column | "choice_set_id" | Column name for choice set IDs |
| chosen_column | "chosen" | Column name for chosen indicator (1/0) |
| confidence_level | "0.95" | Confidence level for CIs (0-1) |

**Optional Settings:**
- `none_as_baseline`: TRUE/FALSE - treat none as baseline
- `none_label`: Label for none option (e.g., "None of these")
- `alternative_id_column`: Column name for alternative IDs
- `generate_market_simulator`: TRUE/FALSE - generate simulator sheet
- `include_diagnostics`: TRUE/FALSE - include detailed diagnostics

**Alchemer-Specific Settings (NEW in v2.1):**
- `data_source`: "alchemer" or "generic" - set to "alchemer" for Alchemer CBC exports
- `clean_alchemer_levels`: TRUE/FALSE - auto-clean level names (e.g., "Low_071" → "Low")
- `zero_center_utilities`: TRUE/FALSE - zero-center utilities within attributes
- `base_level_method`: "first", "last", or "effects" - reference level coding

### Sheet 2: Attributes

| AttributeName | AttributeLabel | NumLevels | Level1 | Level2 | Level3 | Level4 | ... |
|---------------|----------------|-----------|--------|--------|--------|--------|-----|
| Brand | Brand | 4 | Apple | Samsung | Google | OnePlus | |
| Price | Price | 4 | $299 | $399 | $499 | $599 | |
| Screen_Size | Screen Size | 3 | 5.5" | 6.1" | 6.7" | | |

**Rules:**
- `AttributeName`: Must match column names in your data (no spaces)
- `AttributeLabel`: Display name for output
- `NumLevels`: Number of levels for this attribute
- `Level1`, `Level2`, etc.: Level values (must match data exactly)

---

## Data File Format

### Choice-Based Conjoint (CBC) Format

Your data file should have one row per alternative per choice set:

```csv
resp_id,choice_set_id,alternative_id,Brand,Price,Screen_Size,Battery_Life,Camera_Quality,chosen
1,1,1,Apple,$399,6.1 inches,18 hours,Good,1
1,1,2,Samsung,$299,5.5 inches,12 hours,Basic,0
1,1,3,Google,$499,6.7 inches,24 hours,Excellent,0
1,2,1,OnePlus,$599,6.7 inches,24 hours,Excellent,0
1,2,2,Apple,$299,5.5 inches,18 hours,Good,1
1,2,3,Samsung,$399,6.1 inches,12 hours,Basic,0
...
```

**Required Columns:**
- Respondent ID column (configurable name)
- Choice set ID column (configurable name)
- Chosen indicator (1 = chosen, 0 = not chosen)
- One column per attribute (names must match config)

**Rules:**
- Exactly ONE alternative per choice set must have `chosen = 1`
- All alternatives in a choice set share the same choice_set_id
- Attribute values must exactly match levels in config file

### Supported File Formats

- **CSV** (`.csv`)
- **Excel** (`.xlsx`)
- **SPSS** (`.sav`) - requires `haven` package
- **Stata** (`.dta`) - requires `haven` package

---

## Alchemer Data Import (NEW in v2.1)

### Overview

The Turas Conjoint module now supports **direct import of Alchemer CBC exports**. No manual data transformation required!

### Alchemer Export Format

Alchemer exports CBC data with this structure:

| Column | Example | Description |
|--------|---------|-------------|
| ResponseID | 89 | Unique respondent identifier |
| SetNumber | 1, 2, 3... | Choice task number |
| CardNumber | 1, 2, 3 | Alternative within choice set |
| [Attributes] | High_107 | Attribute level shown |
| Score | 0 or 100 | 100 = chosen, 0 = not chosen |

### Automatic Transformations

When you set `data_source = "alchemer"` in your config, the module automatically:

1. **Creates choice_set_id**: Combines ResponseID and SetNumber (e.g., "89_1")
2. **Normalizes Score**: Converts 100 → 1, 0 → 0
3. **Cleans level names**: "Low_071" → "Low", "MSG_Present" → "Present"
4. **Renames columns**: ResponseID → resp_id, CardNumber → alternative_id

### Example: Alchemer Workflow

```r
# 1. Create a simple config file with Alchemer settings
#    In your config.xlsx Settings sheet, include:
#
#    | Setting | Value |
#    |---------|-------|
#    | data_source | alchemer |
#    | data_file | DE_noodle_conjoint_raw.xlsx |
#    | output_file | noodle_results.xlsx |

# 2. Run the analysis - data is automatically transformed!
results <- run_conjoint_analysis(
  config_file = "my_alchemer_config.xlsx"
)

# 3. View results
print(results$importance)
```

### Attribute Level Name Cleaning

Alchemer encodes levels in various formats. Here's how they're cleaned:

| Alchemer Format | Cleaned | Pattern |
|-----------------|---------|---------|
| Low_071 | Low | Price with numeric suffix |
| Mid_089 | Mid | Price with numeric suffix |
| High_107 | High | Price with numeric suffix |
| MSG_Present | Present | Attribute_Level format |
| MSG_Absent | Absent | Attribute_Level format |
| Salt_Reduced | Reduced | Attribute_Level format |
| A, B, C, D, E | A, B, C, D, E | Already clean (unchanged) |

### Standalone Alchemer Import

You can also use the Alchemer import function directly:

```r
# Import Alchemer data without running full analysis
df <- import_alchemer_conjoint("DE_noodle_conjoint_raw.xlsx")

# View the transformed data
head(df)

# Get attribute summary
get_alchemer_attributes(df)

# Auto-generate a config file
config <- create_config_from_alchemer(df, "auto_generated_config.xlsx")
```

---

## Running an Analysis

### Basic Usage

```r
# Using config file with all paths specified in Settings sheet
results <- run_conjoint_analysis(
  config_file = "path/to/config.xlsx"
)
```

### Override Paths

```r
# Override data and output paths from command line
results <- run_conjoint_analysis(
  config_file = "path/to/config.xlsx",
  data_file = "path/to/my_data.csv",
  output_file = "path/to/my_results.xlsx"
)
```

### Silent Mode

```r
# Run without progress messages
results <- run_conjoint_analysis(
  config_file = "config.xlsx",
  verbose = FALSE
)
```

### What Happens During Analysis

The module executes a 7-step workflow:

1. **Load Configuration** - Validates config file and settings
2. **Load and Validate Data** - 3-tier validation (Critical/Warning/Info)
3. **Estimate Model** - Auto-selects best estimation method
4. **Calculate Utilities** - Part-worth utilities with CIs
5. **Calculate Importance** - Attribute importance scores
6. **Run Diagnostics** - Model fit and quality assessment
7. **Generate Output** - Creates Excel workbook with 6 sheets

**Progress Example:**
```
================================================================================
TURAS CONJOINT ANALYSIS - Enhanced Version 2.0
================================================================================

1. Loading configuration...
   ✓ Loaded 5 attributes with 17 total levels

2. Loading and validating data...
   ✓ Validated 50 respondents with 400 choice sets

3. Estimating choice model...
   → Method: auto (trying mlogit first)
   ✓ mlogit estimation successful

4. Calculating part-worth utilities...
   ✓ Estimated 17 part-worth utilities
   ✓ 12 of 13 levels significant (p < 0.05)

5. Calculating attribute importance...
   ✓ Importance scores calculated:
      1. Price: 35.2%
      2. Brand: 28.7%
      3. Camera_Quality: 16.8%

6. Running model diagnostics...
   ✓ McFadden R² = 0.312 (Good)
   ✓ Hit rate = 54.5% (chance = 33.3%)

7. Generating Excel output...
   ✓ Results written to: example_results.xlsx

================================================================================
ANALYSIS COMPLETE
Total time: 3.2 seconds
================================================================================
```

---

## Understanding the Output

The analysis produces an Excel workbook with **6 professionally formatted sheets**:

### Sheet 1: Executive Summary

High-level overview with:
- Study information (respondents, choice sets, attributes)
- Top 3 attributes by importance
- Model fit quality assessment
- Key statistics

### Sheet 2: Attribute Importance

Ranked attribute importance with:
- Importance percentages (sum to 100%)
- Rank (1 = most important)
- Range of utility values
- Interpretation text

**Example:**
| Rank | Attribute | Importance | Range | Interpretation |
|------|-----------|------------|-------|----------------|
| 1 | Price | 35.2% | 2.50 | Price is the most important factor |
| 2 | Brand | 28.7% | 2.04 | Brand is a very important factor |

### Sheet 3: Part-Worth Utilities

Zero-centered utilities for each level with:
- Utility values (centered within attribute)
- Standard errors
- 95% Confidence intervals
- P-values
- Significance stars (*, **, ***)
- Interpretation text

**Example:**
| Attribute | Level | Utility | Std Error | CI Lower | CI Upper | P-value | Sig | Interpretation |
|-----------|-------|---------|-----------|----------|----------|---------|-----|----------------|
| Price | $299 | 1.25 | 0.08 | 1.09 | 1.41 | <0.001 | *** | Strong positive preference |
| Price | $399 | 0.42 | 0.07 | 0.28 | 0.56 | <0.001 | *** | Moderate positive preference |
| Price | $499 | -0.32 | 0.07 | -0.46 | -0.18 | <0.001 | *** | Moderate negative preference |
| Price | $599 | -1.35 | 0.09 | -1.53 | -1.17 | <0.001 | *** | Strong negative preference |

**Conditional Formatting:**
- Green cells = positive utilities (preferred)
- Red cells = negative utilities (avoided)

### Sheet 4: Model Diagnostics

Comprehensive fit statistics:
- McFadden R² (pseudo R-squared)
- Adjusted McFadden R²
- Hit rate (% correctly predicted)
- AIC / BIC information criteria
- Log-likelihoods
- Convergence information

**Quality Assessment:**
- Excellent: R² > 0.4
- Good: R² = 0.2-0.4
- Fair: R² = 0.1-0.2
- Poor: R² < 0.1

### Sheet 5: Data Summary

Data quality indicators:
- Sample size statistics
- Validation results (warnings, info messages)
- None option details (if applicable)
- Choice set balance

### Sheet 6: Configuration

Reference information:
- All settings used in analysis
- Attribute definitions
- Level names
- Useful for reproducibility

---

## Advanced Features

### None Option Handling

The module automatically detects "none of these" options using 3 methods:

1. **Pattern matching**: Looks for "none", "neither", "no choice" in attribute values
2. **All-unchosen detection**: Finds choice sets where no alternatives were chosen
3. **Alternative ID**: Checks for none indicators in alternative_id column

**Configuration:**
```
none_as_baseline = TRUE          # Treat none as reference level
none_label = "None of these"     # Label to search for
```

### Estimation Methods

**Auto (Recommended):**
- Tries mlogit first (robust, handles complex designs)
- Falls back to clogit if mlogit fails
- Provides best chance of success

**mlogit:**
- Maximum likelihood estimation
- Supports complex choice structures
- Most statistically robust

**clogit:**
- Conditional logit via survival package
- Simpler, more stable
- Good fallback option

**Specify in config:**
```
estimation_method = "auto"    # auto, mlogit, clogit, or hb
```

### Baseline Handling

**first_level_zero (Default):**
- First level of each attribute is reference (utility = 0)
- Standard approach in conjoint analysis
- Easier interpretation

**all_levels_explicit:**
- All levels have explicit coefficients
- Zero-centering applied after estimation
- Better for some research questions

**Specify in config:**
```
baseline_handling = "first_level_zero"
```

### Rating-Based Conjoint

For rating-based designs (not choice-based):

```
analysis_type = "rating"
rating_variable = "rating"    # Name of rating column in your data
```

Uses OLS regression instead of logit models.

---

## Troubleshooting

### Common Errors and Solutions

#### Error: "Required column 'chosen' not found in data"

**Cause:** Your data file doesn't have a column matching the `chosen_column` setting.

**Solution:**
- Check your config file's `chosen_column` setting
- Ensure your data has this column
- Column names are case-sensitive

#### Error: "Attribute levels in data do not match configuration"

**Cause:** Level values in your data don't exactly match the config file.

**Solution:**
- Check for spelling differences
- Check for extra spaces
- Check for case differences (e.g., "apple" vs "Apple")
- Use the same quotes and formatting

#### Warning: "Some choice sets have no chosen alternative"

**Cause:** Some choice sets don't have any alternative with `chosen = 1`.

**Solution:**
- This may indicate a "none chosen" situation
- If intentional, configure none option handling
- If not intentional, fix your data

#### Error: "mlogit estimation failed"

**Cause:** Model convergence issues, often due to:
- Perfect separation (one level always/never chosen)
- Too many attributes relative to sample size
- Multicollinearity

**Solution:**
- Set `estimation_method = "auto"` to try fallback
- Check for levels that are always/never chosen
- Consider combining similar levels
- Increase sample size

#### Warning: "X coefficients are NA (likely due to perfect separation)"

**Cause:** Some levels have perfect prediction (always or never chosen).

**Solution:**
- Review data quality
- Check if some level combinations never appear
- Consider removing problematic levels
- Increase sample size

### Validation Warnings

The module provides 3 tiers of validation messages:

**Critical (Red - Analysis stops):**
- Missing required columns
- Multiple chosen per choice set
- Mismatched attribute levels

**Warning (Yellow - Analysis continues):**
- Low response counts per level
- Unbalanced choice set sizes
- Possible perfect separation

**Info (Blue - Informational):**
- None option detected
- Large dataset size
- Configuration notes

### Getting Help

1. **Check validation messages** - Often tell you exactly what's wrong
2. **Review your config file** - Most errors are configuration issues
3. **Examine your data** - Use `head(data)` and `summary(data)` in R
4. **Check the spec files** - Full documentation in `modules/conjoint/Part*.md`
5. **Contact support** - Provide error messages and config file

---

## Example Workflow

Here's a complete workflow from start to finish:

```r
# ============================================
# COMPLETE CONJOINT ANALYSIS WORKFLOW
# ============================================

# 1. Setup
setwd("/path/to/Turas")
library(mlogit)
library(survival)
library(openxlsx)
library(dplyr)
library(tidyr)

# 2. Load module
source("modules/conjoint/R/99_helpers.R")
source("modules/conjoint/R/01_config.R")
source("modules/conjoint/R/09_none_handling.R")
source("modules/conjoint/R/02_data.R")
source("modules/conjoint/R/03_estimation.R")
source("modules/conjoint/R/04_utilities.R")
source("modules/conjoint/R/07_output.R")
source("modules/conjoint/R/00_main.R")

# 3. Run analysis
results <- run_conjoint_analysis(
  config_file = "my_study/config.xlsx",
  verbose = TRUE
)

# 4. Explore results
print(results$importance)
print(results$utilities)
print(results$diagnostics$fit_statistics)

# 5. Access specific components
top_attribute <- results$importance$Attribute[1]
cat("Most important attribute:", top_attribute, "\n")

mcfadden_r2 <- results$diagnostics$fit_statistics$mcfadden_r2
cat("Model fit (McFadden R²):", round(mcfadden_r2, 3), "\n")

# 6. Export additional outputs if needed
write.csv(results$utilities, "utilities.csv", row.names = FALSE)
write.csv(results$importance, "importance.csv", row.names = FALSE)

# 7. Check output file
cat("Excel output:", results$config$output_file, "\n")
```

---

## Tips and Best Practices

### Data Preparation

1. **Clean your data first** - Remove duplicates, fix typos, standardize formats
2. **Use consistent names** - Attribute names should be simple (no spaces, use underscores)
3. **Test with a subset** - Run analysis on 10-20 respondents first to catch issues
4. **Validate manually** - Check that one alternative per set is chosen

### Configuration

1. **Start with auto method** - Let the module choose the best estimation approach
2. **Use descriptive labels** - AttributeLabel makes output more readable
3. **Set realistic confidence levels** - 0.95 is standard, 0.90 for exploratory
4. **Document your settings** - Add notes in the Instructions sheet

### Interpretation

1. **Focus on importance first** - Tells you which attributes matter most
2. **Look at utility ranges** - Larger range = more impactful attribute
3. **Check significance** - Non-significant levels may not differ from baseline
4. **Consider McFadden R²** - Values of 0.2-0.4 are typical and acceptable
5. **Use hit rate** - Should be well above chance rate

### Common Pitfalls to Avoid

1. **Don't over-interpret small utilities** - Check confidence intervals
2. **Don't ignore warnings** - They often indicate data quality issues
3. **Don't use too many attributes** - 4-6 is optimal, >8 gets problematic
4. **Don't skip validation** - Always review the Data Summary sheet
5. **Don't compare utilities across attributes** - Use importance instead

---

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

---

## Tutorial

# Turas Conjoint Analysis - Step-by-Step Tutorial

**Tutorial:** Complete Conjoint Analysis from Start to Finish
**Time Required:** 30-45 minutes
**Difficulty:** Beginner-friendly

---

## What You'll Learn

By the end of this tutorial, you will:

✅ Set up your R environment for conjoint analysis
✅ Create a configuration file for your study
✅ Prepare your data in the correct format
✅ Run a complete conjoint analysis
✅ Interpret the results
✅ Use the interactive market simulator
✅ Test what-if scenarios

---

## Tutorial Overview

We'll analyze a **smartphone choice study** with:
- **5 attributes**: Brand, Price, Screen Size, Battery Life, Camera Quality
- **50 respondents**
- **8 choice sets per respondent**
- **3 alternatives per choice set**

This is a realistic conjoint study that demonstrates all key features.

---

## Part 1: Environment Setup (10 minutes)

### Step 1.1: Install R

**If you already have R installed, skip to Step 1.2**

**Windows:**
1. Go to https://cloud.r-project.org/
2. Click "Download R for Windows"
3. Click "base"
4. Click "Download R 4.x.x for Windows"
5. Run the installer (.exe file)
6. Accept all defaults

**Mac:**
1. Go to https://cloud.r-project.org/
2. Click "Download R for macOS"
3. Download the appropriate .pkg file for your Mac
4. Run the installer
5. Accept all defaults

**Verify installation:**
- Open R (or R console)
- You should see version information
- Type `quit()` to exit (for now)

### Step 1.2: Install Required Packages

**Open R or RStudio** and run these commands:

```r
# This will take 5-10 minutes the first time
# You only need to do this once

install.packages(c(
  "mlogit",
  "survival",
  "openxlsx",
  "dplyr",
  "tidyr"
))
```

**Wait for installation to complete.** You'll see messages like "package 'mlogit' successfully unpacked".

**Troubleshooting:**
- If asked "Do you want to install from sources?", answer **No**
- If asked about CRAN mirror, choose **0-Cloud** or any USA mirror
- If you see errors about permissions, try running R as administrator (Windows) or with sudo (Mac/Linux)

### Step 1.3: Verify Packages Work

```r
# Test that packages load correctly
library(mlogit)
library(survival)
library(openxlsx)
library(dplyr)
library(tidyr)

# If no errors appear, you're good to go!
# You should see some startup messages, that's normal
```

✅ **Checkpoint:** All five packages loaded without errors

---

## Part 2: Run the Example Analysis (5 minutes)

Before creating your own project, let's run the built-in example to make sure everything works.

### Step 2.1: Set Working Directory

```r
# Change this path to where you have Turas installed
setwd("/home/user/Turas")

# Verify you're in the right place
list.files("modules/conjoint/R")
# You should see: 00_main.R, 01_config.R, etc.
```

**Troubleshooting:**
- If you get "cannot change working directory", the path is wrong
- Find where you saved Turas and use that full path
- On Windows, use forward slashes: `setwd("C:/Users/YourName/Documents/Turas")`

### Step 2.2: Load All Module Files

**Copy and paste this entire block:**

```r
# Load all module files (in order)
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

**You should see:** No errors (some messages are OK)

### Step 2.3: Run the Example

```r
# Run the example analysis
results <- run_conjoint_analysis(
  config_file = "modules/conjoint/examples/example_config.xlsx"
)
```

**You should see:**
```
================================================================================
TURAS CONJOINT ANALYSIS - Enhanced Version 2.0
================================================================================

1. Loading configuration...
   ✓ Loaded 5 attributes with 17 total levels

2. Loading and validating data...
   ✓ Validated 50 respondents with 400 choice sets

3. Estimating choice model...
   → Method: auto (trying mlogit first)
   ✓ mlogit estimation successful

4. Calculating part-worth utilities...
   ✓ Estimated 17 part-worth utilities

5. Calculating attribute importance...
   ✓ Importance scores calculated

6. Running model diagnostics...
   ✓ McFadden R² = 0.31 (Good)
   ✓ Hit rate = 54.2%

7. Generating Excel output...
   ✓ Results written to: examples/output/example_results.xlsx

================================================================================
ANALYSIS COMPLETE
Total time: X.X seconds
================================================================================
```

### Step 2.4: View Results

```r
# View attribute importance
print(results$importance)

# You should see something like:
#   Attribute       Importance Rank
# 1 Price              35.2     1
# 2 Brand              28.7     2
# 3 Camera_Quality     16.8     3
# 4 Battery_Life       12.1     4
# 5 Screen_Size         7.2     5
```

### Step 2.5: Open Excel Output

Navigate to: `modules/conjoint/examples/output/example_results.xlsx`

**Open it in Excel and explore:**
- Executive Summary
- Attribute Importance
- Part-Worth Utilities
- Model Diagnostics
- Market Simulator (try changing dropdowns!)

✅ **Checkpoint:** Example analysis completed successfully and Excel file opens

---

## Part 3: Create Your Own Test Project (10 minutes)

Now let's create a project from scratch using a different example: **Coffee Shop Choice Study**

### Step 3.1: Create Project Directory

```r
# Create a new directory for your project
dir.create("my_conjoint_project", showWarnings = FALSE)
dir.create("my_conjoint_project/data", showWarnings = FALSE)
dir.create("my_conjoint_project/output", showWarnings = FALSE)
```

### Step 3.2: Define Your Study

**Our coffee shop study will test:**

| Attribute | Levels |
|-----------|--------|
| **Price** | $3.00, $4.00, $5.00 |
| **Coffee_Type** | Regular, Specialty, Premium |
| **Size** | Small, Medium, Large |
| **Location** | Downtown, Suburban, Mall |

### Step 3.3: Create Configuration File

**Option A: Use Python (if you have it)**

Create file `my_conjoint_project/create_config.py`:

```python
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill

wb = Workbook()
wb.remove(wb.active)

# Settings sheet
ws_settings = wb.create_sheet("Settings")
settings_data = [
    ["Setting", "Value", "Description"],
    ["analysis_type", "choice", "Choice-based conjoint"],
    ["estimation_method", "auto", "Auto-select best method"],
    ["baseline_handling", "first_level_zero", "First level as reference"],
    ["choice_type", "single", "Single choice per set"],
    ["data_file", "data/coffee_data.csv", "Path to data"],
    ["output_file", "output/coffee_results.xlsx", "Path to results"],
    ["respondent_id_column", "resp_id", "Respondent ID column"],
    ["choice_set_column", "choice_set_id", "Choice set ID column"],
    ["chosen_column", "chosen", "Chosen indicator column"],
    ["confidence_level", "0.95", "95% confidence intervals"],
    ["generate_market_simulator", "TRUE", "Create simulator"],
]

for row_idx, row_data in enumerate(settings_data, start=1):
    for col_idx, value in enumerate(row_data, start=1):
        cell = ws_settings.cell(row=row_idx, column=col_idx, value=value)
        if row_idx == 1:
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = PatternFill(start_color="4F81BD", end_color="4F81BD", fill_type="solid")

# Attributes sheet
ws_attributes = wb.create_sheet("Attributes")
attributes_data = [
    ["AttributeName", "AttributeLabel", "NumLevels", "Level1", "Level2", "Level3", "Level4"],
    ["Price", "Price", 3, "$3.00", "$4.00", "$5.00", None],
    ["Coffee_Type", "Coffee Type", 3, "Regular", "Specialty", "Premium", None],
    ["Size", "Size", 3, "Small", "Medium", "Large", None],
    ["Location", "Location", 3, "Downtown", "Suburban", "Mall", None],
]

for row_idx, row_data in enumerate(attributes_data, start=1):
    for col_idx, value in enumerate(row_data, start=1):
        cell = ws_attributes.cell(row=row_idx, column=col_idx, value=value)
        if row_idx == 1:
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = PatternFill(start_color="4F81BD", end_color="4F81BD", fill_type="solid")

wb.save("my_conjoint_project/coffee_config.xlsx")
print("✓ Configuration file created!")
```

Run: `python3 my_conjoint_project/create_config.py`

**Option B: Use Excel Manually**

1. Open Excel
2. Create new workbook
3. Rename Sheet1 to "Settings"
4. Enter the settings table shown above
5. Add Sheet2, rename to "Attributes"
6. Enter the attributes table shown above
7. Save as: `my_conjoint_project/coffee_config.xlsx`

✅ **Checkpoint:** Configuration file created

### Step 3.4: Create Sample Data

**Use Python to create realistic sample data:**

Create file `my_conjoint_project/create_data.py`:

```python
import pandas as pd
import numpy as np
import random

random.seed(42)
np.random.seed(42)

# Define attribute levels
attributes = {
    'Price': ['$3.00', '$4.00', '$5.00'],
    'Coffee_Type': ['Regular', 'Specialty', 'Premium'],
    'Size': ['Small', 'Medium', 'Large'],
    'Location': ['Downtown', 'Suburban', 'Mall']
}

# True utilities (will drive choices)
true_utilities = {
    'Price': {'$3.00': 1.0, '$4.00': 0.0, '$5.00': -1.0},
    'Coffee_Type': {'Regular': -0.5, 'Specialty': 0.5, 'Premium': 0.0},
    'Size': {'Small': -0.3, 'Medium': 0.3, 'Large': 0.0},
    'Location': {'Downtown': 0.4, 'Suburban': -0.2, 'Mall': -0.2}
}

# Study design
n_respondents = 100
n_choice_sets_per_respondent = 10
n_alternatives_per_set = 3

# Generate data
data_rows = []
choice_set_counter = 0

for resp_id in range(1, n_respondents + 1):
    for cs in range(1, n_choice_sets_per_respondent + 1):
        choice_set_counter += 1

        # Generate alternatives
        alternatives = []
        for alt in range(1, n_alternatives_per_set + 1):
            profile = {
                attr: random.choice(levels)
                for attr, levels in attributes.items()
            }

            # Calculate utility
            utility = sum(true_utilities[attr][profile[attr]]
                         for attr in profile.keys())
            utility += np.random.gumbel(0, 1)  # Random error

            alternatives.append({
                'resp_id': resp_id,
                'choice_set_id': choice_set_counter,
                'alternative_id': alt,
                **profile,
                'utility': utility
            })

        # Determine chosen (highest utility)
        chosen_idx = max(range(len(alternatives)),
                        key=lambda i: alternatives[i]['utility'])

        # Create data rows
        for idx, alt in enumerate(alternatives):
            data_rows.append({
                'resp_id': alt['resp_id'],
                'choice_set_id': alt['choice_set_id'],
                'alternative_id': alt['alternative_id'],
                'Price': alt['Price'],
                'Coffee_Type': alt['Coffee_Type'],
                'Size': alt['Size'],
                'Location': alt['Location'],
                'chosen': 1 if idx == chosen_idx else 0
            })

# Create DataFrame
df = pd.DataFrame(data_rows)

# Verify
print(f"✓ Generated {len(df)} rows of data")
print(f"  - {n_respondents} respondents")
print(f"  - {choice_set_counter} choice sets")
print(f"  - {df['chosen'].sum()} choices")

# Check validation
choices_per_set = df.groupby('choice_set_id')['chosen'].sum()
if (choices_per_set == 1).all():
    print("  ✓ Validation passed: exactly one chosen per choice set")

# Save
df.to_csv("my_conjoint_project/data/coffee_data.csv", index=False)
print("✓ Data saved to: my_conjoint_project/data/coffee_data.csv")

# Show sample
print("\nFirst few rows:")
print(df.head(12))
```

Run: `python3 my_conjoint_project/create_data.py`

✅ **Checkpoint:** Sample data file created with 3,000 rows

---

## Part 4: Run Your Analysis (5 minutes)

### Step 4.1: Load Modules (if not already loaded)

```r
# If you closed R, reload modules
setwd("/home/user/Turas")

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

### Step 4.2: Run Your Coffee Shop Analysis

```r
# Run analysis
coffee_results <- run_conjoint_analysis(
  config_file = "my_conjoint_project/coffee_config.xlsx",
  verbose = TRUE
)
```

**Watch the progress:**
```
================================================================================
TURAS CONJOINT ANALYSIS - Enhanced Version 2.0
================================================================================

1. Loading configuration...
2. Loading and validating data...
3. Estimating choice model...
4. Calculating part-worth utilities...
5. Calculating attribute importance...
6. Running model diagnostics...
7. Generating Excel output...

================================================================================
ANALYSIS COMPLETE
================================================================================
```

### Step 4.3: View Your Results

```r
# Attribute importance
print(coffee_results$importance)

# Part-worth utilities
print(coffee_results$utilities)

# Model fit
print(coffee_results$diagnostics$fit_statistics)
```

**Expected results:**
- Price should be most important (~40-50%)
- Utilities should match the true values we used to generate data
- McFadden R² should be around 0.20-0.35 (good fit)

✅ **Checkpoint:** Coffee shop analysis completed successfully

---

## Part 5: Interpret Your Results (10 minutes)

### Step 5.1: Open Excel Output

Navigate to: `my_conjoint_project/output/coffee_results.xlsx`

### Step 5.2: Executive Summary

**Look at:**
- Sample size: 100 respondents, 1,000 choice sets
- Top attributes: Price, Location, Coffee_Type, Size
- Model quality: Should show "Good" or "Excellent"

### Step 5.3: Attribute Importance

**Examine the table:**

```
Rank | Attribute    | Importance | Interpretation
-----|--------------|------------|----------------------------------
1    | Price        | 45.2%      | Price is the most important factor
2    | Location     | 22.3%      | Location is a very important factor
3    | Coffee_Type  | 18.1%      | Coffee Type notably influences choice
4    | Size         | 14.4%      | Size moderately influences choice
```

**What this means:**
- Price matters almost 2x more than Location
- Price matters 3x more than Size
- Together, these 4 attributes explain choice behavior

### Step 5.4: Part-Worth Utilities

**Look at Price utilities:**

```
Attribute | Level  | Utility | Std Error | CI Lower | CI Upper | P-value | Sig
----------|--------|---------|-----------|----------|----------|---------|----
Price     | $3.00  |  0.98   |   0.07    |   0.84   |   1.12   | <0.001  | ***
Price     | $4.00  | -0.02   |   0.07    |  -0.16   |   0.12   | 0.776   | ns
Price     | $5.00  | -0.96   |   0.08    |  -1.12   |  -0.80   | <0.001  | ***
```

**Interpretation:**
- **$3.00**: Utility = +0.98 → Strongly preferred
- **$4.00**: Utility = -0.02 → Neutral (close to zero)
- **$5.00**: Utility = -0.96 → Strongly avoided
- All differences are significant (*** = p<0.001)

**This makes sense!** Lower prices are preferred.

**Look at Coffee_Type utilities:**

```
Coffee_Type | Level     | Utility | Interpretation
------------|-----------|---------|-------------------
            | Regular   | -0.48   | Somewhat avoided
            | Specialty |  0.51   | Moderately preferred
            | Premium   | -0.03   | Neutral
```

**Interpretation:**
- Customers prefer Specialty coffee over Regular
- Premium is in the middle (neutral)

### Step 5.5: Model Diagnostics

**Check these metrics:**

```
McFadden R²: 0.28 (Good)
Hit Rate: 51.2% (chance = 33.3%)
Convergence: Yes
```

**What this means:**
- **R² = 0.28**: Good fit for a choice model (0.2-0.4 is typical)
- **Hit Rate = 51.2%**: Model predicts correctly 51% of the time (vs. 33% by chance)
- **Convergence = Yes**: Model estimation successful

✅ **Checkpoint:** Results interpreted correctly

---

## Part 6: Use the Market Simulator (10 minutes)

### Step 6.1: Open Market Simulator Sheet

In Excel, go to the **"Market Simulator"** sheet.

### Step 6.2: Configure Competing Coffee Shops

**Product 1: Your Current Shop**
- Price: $4.00
- Coffee_Type: Specialty
- Size: Medium
- Location: Downtown

**Product 2: Budget Competitor**
- Price: $3.00
- Coffee_Type: Regular
- Size: Small
- Location: Suburban

**Product 3: Premium Competitor**
- Price: $5.00
- Coffee_Type: Premium
- Size: Large
- Location: Mall

### Step 6.3: View Market Shares

**You should see shares like:**
```
Product 1: 48.2%
Product 2: 38.7%
Product 3: 13.1%
```

**Interpretation:**
- Your shop (Product 1) has largest share
- Budget competitor is competitive
- Premium competitor has smallest share

### Step 6.4: Test What-If Scenarios

**Scenario 1: Lower Your Price**
- Change Product 1 Price to $3.00
- Watch share increase to ~55-60%

**Scenario 2: Upgrade to Premium**
- Change Product 1 Coffee_Type to Premium
- Keep price at $4.00
- Share might drop slightly (Premium isn't preferred over Specialty)

**Scenario 3: Competitor Response**
- Reset Product 1 to original
- Change Product 2 Coffee_Type to Specialty (matching yours)
- Product 2 share should increase (better coffee at lower price)

### Step 6.5: Find Optimal Configuration

**Goal:** Maximize your share against competitors

**Test combinations:**
1. $3.00 + Specialty + Medium + Downtown = ?% share
2. $4.00 + Specialty + Large + Downtown = ?% share
3. $3.00 + Premium + Medium + Suburban = ?% share

**Find the winner!**

The optimal configuration balances:
- Low price (most important)
- Good location (second most important)
- Preferred coffee type
- Preferred size

✅ **Checkpoint:** Market simulator used successfully

---

## Part 7: Advanced Analysis (Optional - 5 minutes)

### Step 7.1: Test Sensitivity Analysis

**Question:** How sensitive is market share to price changes?

**In R:**
```r
# Load simulator functions
source("modules/conjoint/R/05_simulator.R")

# Define your current product
my_shop <- list(
  Price = "$4.00",
  Coffee_Type = "Specialty",
  Size = "Medium",
  Location = "Downtown"
)

# Define competitors
competitors <- list(
  list(Price = "$3.00", Coffee_Type = "Regular",
       Size = "Small", Location = "Suburban"),
  list(Price = "$5.00", Coffee_Type = "Premium",
       Size = "Large", Location = "Mall")
)

# Test price sensitivity
price_sensitivity <- sensitivity_one_way(
  base_product = my_shop,
  attribute = "Price",
  all_levels = c("$3.00", "$4.00", "$5.00"),
  utilities = coffee_results$utilities,
  other_products = competitors,
  method = "logit"
)

print(price_sensitivity)
```

**Results show:**
```
Level  | Share_Percent | Share_Change | Is_Current
-------|---------------|--------------|------------
$3.00  | 55.2%         | +7.0%        | FALSE
$4.00  | 48.2%         | 0.0%         | TRUE
$5.00  | 35.1%         | -13.1%       | FALSE
```

**Interpretation:**
- Lowering price to $3.00 increases share by 7 percentage points
- Raising price to $5.00 decreases share by 13 percentage points
- Price elasticity is asymmetric (bigger loss from increase than gain from decrease)

### Step 7.2: Compare Multiple Scenarios

```r
# Define scenarios
scenarios <- list(
  "Current" = list(my_shop, competitors[[1]], competitors[[2]]),
  "Price_Drop" = list(
    list(Price = "$3.00", Coffee_Type = "Specialty",
         Size = "Medium", Location = "Downtown"),
    competitors[[1]],
    competitors[[2]]
  ),
  "Go_Premium" = list(
    list(Price = "$4.00", Coffee_Type = "Premium",
         Size = "Large", Location = "Downtown"),
    competitors[[1]],
    competitors[[2]]
  )
)

# Compare
scenario_results <- compare_scenarios(
  scenarios = scenarios,
  utilities = coffee_results$utilities,
  method = "logit"
)

print(scenario_results)
```

**Results show which strategy works best.**

✅ **Checkpoint:** Advanced analysis completed

---

## Part 8: Save and Document (5 minutes)

### Step 8.1: Save Your R Workspace

```r
# Save all results for later
save(coffee_results,
     file = "my_conjoint_project/coffee_analysis.RData")

# Later, you can reload with:
# load("my_conjoint_project/coffee_analysis.RData")
```

### Step 8.2: Export Key Results

```r
# Export importance to CSV
write.csv(coffee_results$importance,
          "my_conjoint_project/output/importance.csv",
          row.names = FALSE)

# Export utilities to CSV
write.csv(coffee_results$utilities,
          "my_conjoint_project/output/utilities.csv",
          row.names = FALSE)
```

### Step 8.3: Create Analysis Summary

Create file: `my_conjoint_project/ANALYSIS_SUMMARY.txt`

```
COFFEE SHOP CONJOINT ANALYSIS
Date: 2025-11-27
Analyst: [Your Name]

STUDY DESIGN:
- 100 respondents
- 10 choice sets per respondent
- 3 alternatives per choice set
- 4 attributes tested

KEY FINDINGS:
1. Price is most important (45% importance)
2. Location is second most important (22%)
3. Customers prefer:
   - Lower prices ($3.00 best)
   - Specialty coffee
   - Medium size
   - Downtown location

MODEL QUALITY:
- McFadden R²: 0.28 (Good)
- Hit rate: 51.2% (vs 33% chance)
- All attributes significant

RECOMMENDATIONS:
1. Price point: $3.00-$4.00 optimal range
2. Focus on Specialty coffee offerings
3. Prioritize Downtown location
4. Medium size is preferred

MARKET SIMULATION:
- Current config: 48% market share
- With $3.00 price: 55% share (+7%)
- With $5.00 price: 35% share (-13%)

FILES:
- Config: coffee_config.xlsx
- Data: data/coffee_data.csv
- Results: output/coffee_results.xlsx
- R workspace: coffee_analysis.RData
```

✅ **Checkpoint:** Analysis documented and saved

---

## Summary: What You've Accomplished

🎉 **Congratulations!** You've completed a full conjoint analysis from start to finish.

**You now know how to:**

✅ Set up R environment with required packages
✅ Create configuration files for your studies
✅ Prepare data in the correct format
✅ Run conjoint analysis with the Turas module
✅ Interpret part-worth utilities and attribute importance
✅ Use the interactive market simulator
✅ Test what-if scenarios and sensitivity analysis
✅ Document and save your results

---

## Next Steps

### For Your Own Studies

1. **Define your research question**
   - What product/service are you studying?
   - What attributes matter to customers?

2. **Design your study**
   - Choose 4-6 attributes
   - Define 3-4 levels per attribute
   - Plan 8-12 choice sets per respondent

3. **Collect data**
   - Use survey platform (Qualtrics, Alchemer, etc.)
   - Export in correct format
   - Clean data (remove speeders, attention check failures)

4. **Create config file**
   - Use `example_config.xlsx` as template
   - Modify for your attributes and levels

5. **Run analysis**
   - Follow this tutorial
   - Check validation messages
   - Review model diagnostics

6. **Interpret and act**
   - Focus on importance first
   - Use utilities to understand preferences
   - Test scenarios in market simulator
   - Make data-driven decisions

### Additional Resources

- **User Manual**: `modules/conjoint/USER_MANUAL.md` - Comprehensive reference
- **Quick Start**: `modules/conjoint/examples/QUICK_START_GUIDE.md` - Quick reference
- **Specifications**: `modules/conjoint/Part*.md` - Technical details
- **Test Scripts**: `modules/conjoint/tests/` - Example code
- **Implementation Status**: `modules/conjoint/IMPLEMENTATION_STATUS.md` - Feature list

### Getting Help

- Review validation messages (they tell you what's wrong)
- Check the Troubleshooting section in USER_MANUAL.md
- Run the example analysis to verify setup
- Examine the specification files for technical details

---

## Quick Reference

**Load modules:**
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
results <- run_conjoint_analysis(config_file = "your_config.xlsx")
```

**View results:**
```r
print(results$importance)
print(results$utilities)
print(results$diagnostics$fit_statistics)
```

**Use market simulator:**
- Open Excel output
- Go to "Market Simulator" sheet
- Use dropdown menus to configure products
- Watch shares update automatically

---

**End of Tutorial**

*You're now ready to run professional conjoint analyses!*

*For detailed reference information, see USER_MANUAL.md*
