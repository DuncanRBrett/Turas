# Enhanced Turas Conjoint Analysis - Quick Start Guide

**Version:** 2.0.0
**Date:** 2025-11-27
**Status:** Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Quick Start Example](#quick-start-example)
4. [Configuration File Format](#configuration-file-format)
5. [Data File Format](#data-file-format)
6. [Running an Analysis](#running-an-analysis)
7. [Understanding the Output](#understanding-the-output)
8. [Advanced Features](#advanced-features)
9. [Troubleshooting](#troubleshooting)

---

## Overview

The Enhanced Turas Conjoint Analysis module calculates part-worth utilities and attribute importance from choice-based or rating-based conjoint experimental data.

### Key Features

- **Multi-method estimation**: Auto-selects best method (mlogit → clogit fallback)
- **Comprehensive validation**: 3-tier validation (Critical/Warning/Info)
- **None option handling**: Auto-detects "none of these" options
- **Statistical rigor**: Confidence intervals, p-values, significance testing
- **Professional output**: 6-sheet Excel workbook with formatting
- **User-friendly**: Clear error messages and progress reporting

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

## Next Steps

### After Your First Analysis

1. **Review the Excel output** - All 6 sheets provide valuable insights
2. **Check model diagnostics** - Ensure acceptable fit quality
3. **Examine confidence intervals** - Wide CIs may indicate estimation issues
4. **Validate against expectations** - Do results make intuitive sense?

### Enhancing Your Analysis

1. **Add market simulator** (Phase 3 feature - coming soon)
2. **Try different estimation methods** - Compare mlogit vs clogit
3. **Analyze subgroups** - Split data by demographics, run separate analyses
4. **Bootstrap confidence intervals** - For more robust estimates

### Learning More

See the complete specification documents in `modules/conjoint/`:
- **Part 1**: Core technical specification
- **Part 2**: Configuration, testing, validation
- **Part 3**: Excel output and market simulator
- **Part 4**: Alchemer choice types
- **Part 5**: File format structures

---

## Version History

- **2.0.0** (2025-11-27): Enhanced implementation with multi-method estimation
- **1.0.0** (2024-XX-XX): Initial basic implementation

---

## Support

For questions, issues, or feature requests:
1. Check the specification documents
2. Review this guide
3. Examine the example files
4. Contact the Turas development team

---

**Ready to analyze your conjoint data? Start with the example files and adapt them to your study!**
