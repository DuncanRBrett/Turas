# Turas Conjoint Module - User Manual

**Version:** 2.1.0
**Last Updated:** December 2025
**Template:** Conjoint_Config_Template.xlsx (v10.0)

---

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Configuration Template](#configuration-template)
5. [Sheet 1: Instructions](#sheet-1-instructions)
6. [Sheet 2: Settings](#sheet-2-settings)
7. [Sheet 3: Attributes](#sheet-3-attributes)
8. [Data File Requirements](#data-file-requirements)
9. [Running the Analysis](#running-the-analysis)
10. [Understanding Output](#understanding-output)
11. [Using the Market Simulator](#using-the-market-simulator)
12. [Alchemer Data Import](#alchemer-data-import)
13. [Design Recommendations](#design-recommendations)
14. [Common Mistakes](#common-mistakes)
15. [Troubleshooting](#troubleshooting)

---

## Introduction

The Turas Conjoint Module performs Choice-Based Conjoint (CBC) analysis to estimate consumer preferences. It analyzes discrete choices between product profiles to determine:

- **Part-worth utilities** for each attribute level
- **Attribute importance** percentages
- **Predicted market shares** for product configurations

**Key Use Cases:**
- Product development and feature prioritization
- Pricing optimization
- Brand value quantification
- Competitive analysis

---

## Prerequisites

### Software Requirements

- R 4.0 or higher (R 4.2+ recommended)
- RStudio (optional but recommended)

### Required R Packages

```r
# Install required packages
install.packages(c(
  "readxl",      # Read Excel files
  "openxlsx",    # Write Excel output
  "mlogit",      # Multinomial logit
  "survival",    # Conditional logit
  "dfidx"        # Data indexing for mlogit
))
```

### Verify Installation

```r
library(readxl)
library(openxlsx)
library(mlogit)
library(survival)
cat("All packages installed successfully\n")
```

---

## Quick Start

### Step 1: Prepare Your Data

Ensure your choice data file has:
- Respondent ID column
- Choice set ID column
- Alternative ID column
- Attribute columns
- Chosen indicator (0/1)

### Step 2: Copy the Template

Copy `Conjoint_Config_Template.xlsx` to your project folder.

### Step 3: Configure Settings Sheet

| Setting | Value |
|---------|-------|
| analysis_type | choice |
| choice_set_column | choice_set_id |
| chosen_column | chosen |
| respondent_id_column | resp_id |
| data_file | path/to/your/data.csv |
| output_file | path/to/results.xlsx |

### Step 4: Configure Attributes Sheet

| AttributeName | NumLevels | LevelNames |
|---------------|-----------|------------|
| Price | 3 | £449, £599, £699 |
| Brand | 3 | Apple, Samsung, Google |
| Storage | 3 | 128GB, 256GB, 512GB |

### Step 5: Run Analysis

```r
setwd("/path/to/Turas/modules/conjoint")
source("R/00_main.R")
run_conjoint_analysis("/path/to/your_config.xlsx")
```

---

## Configuration Template

The configuration file is an Excel workbook with 3 sheets:

| Sheet | Required | Purpose |
|-------|----------|---------|
| Instructions | No | Documentation (not read by code) |
| Settings | Yes | Analysis parameters, file paths |
| Attributes | Yes | Product attributes and levels |

---

## Sheet 1: Instructions

**Purpose:** Provides detailed documentation.

**Action Required:** Review for understanding. This sheet is not processed by the code.

**Contents:**
- Data format requirements
- Level name matching requirements
- Implementation status
- Sample size recommendations

---

## Sheet 2: Settings

**Purpose:** Configure the analysis parameters and file locations.

**Structure:** Two columns - `Setting` and `Value`

### Required Settings

#### analysis_type

- **Purpose:** Type of conjoint analysis
- **Required:** YES
- **Valid Values:** `choice`
- **Default:** `choice`
- **Notes:** Only Choice-Based Conjoint is production-ready

#### choice_set_column

- **Purpose:** Column name for choice task identifier
- **Required:** YES
- **Valid Values:** Must match data file column name exactly
- **Default:** `choice_set_id`
- **Notes:** May be called `stnumber` in Alchemer data

#### chosen_column

- **Purpose:** Column indicating which alternative was chosen
- **Required:** YES
- **Valid Values:** Must match data file column name exactly
- **Default:** `chosen`
- **Notes:** Must be binary (0 or 1)

#### respondent_id_column

- **Purpose:** Column identifying respondents
- **Required:** YES
- **Valid Values:** Must match data file column name exactly
- **Default:** `resp_id`

#### data_file

- **Purpose:** Path to conjoint choice data
- **Required:** YES
- **Valid Values:** Path to .csv, .xlsx, or .sav file
- **Notes:** Relative paths are relative to project root

#### output_file

- **Purpose:** Path for results Excel file
- **Required:** YES
- **Valid Values:** Path ending in .xlsx
- **Notes:** Directory must exist

### Optional Settings

#### alternative_id_column

- **Purpose:** Column identifying alternatives within choice sets
- **Required:** NO
- **Default:** (blank)
- **Notes:** May be called `cardnumber` in Alchemer

#### none_label

- **Purpose:** Label for "None of these" option
- **Required:** NO
- **Default:** (blank - no none option)
- **When to Use:** When design includes opt-out alternative

#### estimation_method

- **Purpose:** Which algorithm to use
- **Required:** NO
- **Valid Values:** `auto`, `mlogit`, `clogit`
- **Default:** `auto`
- **Recommended:** `auto` (let module choose)

#### generate_market_simulator

- **Purpose:** Create interactive simulator sheet
- **Required:** NO
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`

#### confidence_level

- **Purpose:** Confidence level for intervals
- **Required:** NO
- **Valid Values:** 0.80 to 0.99
- **Default:** `0.95`

#### baseline_handling

- **Purpose:** How to handle baseline levels
- **Required:** NO
- **Valid Values:** `first_level_zero`, `all_levels_explicit`
- **Default:** `first_level_zero`

#### min_responses_per_level

- **Purpose:** Minimum times each level should be selected
- **Required:** NO
- **Valid Values:** 1 to 1000
- **Default:** `10`

---

## Sheet 3: Attributes

**Purpose:** Define product attributes and their levels.

**Structure:** Three columns - `AttributeName`, `NumLevels`, `LevelNames`

### Column Specifications

#### AttributeName

- **Purpose:** Name of product attribute
- **Required:** YES
- **Valid Values:**
  - Must match data column name EXACTLY
  - Case-sensitive
  - Alphanumeric and underscores allowed

#### NumLevels

- **Purpose:** Number of levels for this attribute
- **Required:** YES
- **Valid Values:** 2 to 10 (warning if >6)
- **Notes:** Must match count in LevelNames

#### LevelNames

- **Purpose:** Comma-separated list of level values
- **Required:** YES
- **Valid Values:**
  - Must match data values EXACTLY
  - Case-sensitive
  - No extra spaces unless in data

### Example Attributes Configuration

```
AttributeName | NumLevels | LevelNames
------------- | --------- | ----------
Price         | 3         | £449, £599, £699
Brand         | 3         | Apple, Samsung, Google
Storage       | 3         | 128GB, 256GB, 512GB
Battery       | 3         | 12 hours, 18 hours, 24 hours
```

---

## Data File Requirements

### Required Columns

1. **Respondent ID** (e.g., `resp_id`)
   - Unique identifier per respondent
   - Data type: Numeric, integer, or text

2. **Choice Set ID** (e.g., `choice_set_id`)
   - Choice task identifier
   - Data type: Numeric or integer

3. **Alternative ID** (optional but recommended)
   - Alternative within choice set
   - Data type: Numeric, integer, or text

4. **Attribute Columns**
   - One column per attribute
   - Column names must match AttributeName exactly
   - Values must match LevelNames exactly

5. **Chosen Indicator** (e.g., `chosen`)
   - Binary: 1 = chosen, 0 = not chosen
   - Each choice set must have exactly ONE chosen=1

### Data Structure Example

```
resp_id | choice_set_id | alt_id | Price | Brand   | Storage | chosen
--------|---------------|--------|-------|---------|---------|-------
1       | 1             | 1      | £449  | Apple   | 128GB   | 0
1       | 1             | 2      | £599  | Samsung | 256GB   | 1
1       | 1             | 3      | £699  | Google  | 512GB   | 0
1       | 2             | 1      | £599  | Google  | 128GB   | 1
1       | 2             | 2      | £449  | Apple   | 512GB   | 0
1       | 2             | 3      | £699  | Samsung | 256GB   | 0
2       | 1             | 1      | £699  | Apple   | 256GB   | 0
2       | 1             | 2      | £449  | Google  | 512GB   | 0
2       | 1             | 3      | £599  | Samsung | 128GB   | 1
```

### Critical Validation Rules

1. **Each choice set must have exactly ONE chosen=1**
2. **Level names must match data EXACTLY** (case-sensitive)
3. **No missing values in attribute columns**
4. **Consistent alternatives per choice set**

---

## Running the Analysis

### Option 1: From Turas GUI

```r
setwd("/path/to/Turas")
source("launch_turas.R")
# Click "Launch Conjoint" button
# Browse to config file
# Click "RUN ANALYSIS"
```

### Option 2: From R Console

```r
setwd("/path/to/Turas/modules/conjoint")
source("R/00_main.R")

run_conjoint_analysis(
  config_file = "/path/to/config.xlsx",
  verbose = TRUE
)
```

### Expected Console Output

```
══════════════════════════════════════════════════════════════════
 TURAS CONJOINT ANALYSIS v2.1.0
══════════════════════════════════════════════════════════════════

[CONFIG] Loading configuration from: config.xlsx
[CONFIG] ✓ Settings validated
[CONFIG] ✓ 4 attributes defined

[DATA] Loading data from: data.csv
[DATA] ✓ 15,000 rows loaded
[DATA] ✓ 500 respondents
[DATA] ✓ 5,000 choice sets

[MODEL] Estimating with mlogit...
[MODEL] ✓ Model converged
[MODEL] ✓ McFadden R² = 0.342
[MODEL] ✓ Hit rate = 64.3%

[OUTPUT] Writing results to: results.xlsx
[OUTPUT] ✓ Utilities sheet created
[OUTPUT] ✓ Importance sheet created
[OUTPUT] ✓ Market simulator created

══════════════════════════════════════════════════════════════════
 ANALYSIS COMPLETE
══════════════════════════════════════════════════════════════════
```

---

## Understanding Output

The output Excel workbook contains these sheets:

### Utilities

Part-worth utilities for each attribute level.

| Attribute | Level | Utility | Std_Error | CI_Lower | CI_Upper |
|-----------|-------|---------|-----------|----------|----------|
| Brand | Apple | +0.45 | 0.08 | +0.29 | +0.61 |
| Brand | Samsung | +0.12 | 0.07 | -0.02 | +0.26 |
| Brand | Google | -0.57 | 0.09 | -0.75 | -0.39 |

**Interpretation:**
- Positive utility = preferred over average
- Negative utility = less preferred than average
- Sum within each attribute = 0

### Relative_Importance

Attribute importance percentages.

| Attribute | Importance |
|-----------|------------|
| Price | 48% |
| Brand | 27% |
| Storage | 16% |
| Battery | 9% |

**Interpretation:**
- Higher percentage = more influence on choice
- Sum = 100%

### Model_Summary

Fit statistics and diagnostics.

| Metric | Value |
|--------|-------|
| McFadden R² | 0.342 |
| Log-Likelihood | -3,245.6 |
| AIC | 6,511.2 |
| BIC | 6,589.4 |
| Hit Rate | 64.3% |
| Chance Rate | 33.3% |

### Market_Simulator

Interactive tool for market share predictions. See next section.

---

## Using the Market Simulator

The market simulator sheet lets you test product configurations.

### How It Works

1. **Configure Products:** Use dropdowns to set attribute levels for each product
2. **View Shares:** Market share percentages update automatically
3. **Test Scenarios:** Change configurations to see share impact

### Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                    MARKET SIMULATOR                              │
├─────────────────────────────────────────────────────────────────┤
│         │ Product 1 │ Product 2 │ Product 3 │ Product 4 │ Prod 5│
├─────────┼───────────┼───────────┼───────────┼───────────┼───────┤
│ Brand   │ [Apple ▼] │ [Samsung▼]│ [Google ▼]│           │       │
│ Price   │ [£599  ▼] │ [£449  ▼] │ [£699  ▼] │           │       │
│ Storage │ [256GB ▼] │ [128GB ▼] │ [512GB ▼] │           │       │
│ Battery │ [18hr  ▼] │ [12hr  ▼] │ [24hr  ▼] │           │       │
├─────────┼───────────┼───────────┼───────────┼───────────┼───────┤
│ Utility │   1.23    │   0.45    │   0.12    │     -     │   -   │
│ Share   │   42%     │   33%     │   25%     │     -     │   -   │
└─────────────────────────────────────────────────────────────────┘
```

### Tips

- Leave products blank (all dropdowns empty) to exclude from simulation
- Shares always sum to 100% for active products
- Test competitor responses by adjusting their configurations
- Save multiple scenarios by copying the sheet

---

## Alchemer Data Import

Version 2.1 supports direct import of Alchemer CBC exports.

### Alchemer Export Format

Alchemer CBC exports include:
- `ResponseID` - Respondent identifier
- `SetNumber` - Choice set (1, 2, 3...)
- `CardNumber` - Alternative (1, 2, 3...)
- `Score` - 0 or 100 (not chosen / chosen)
- Attribute columns with prefixed level names

### Settings for Alchemer

```
Setting              | Value
---------------------|------------------
data_source          | alchemer
clean_alchemer_levels| TRUE
choice_set_column    | SetNumber
chosen_column        | Score
respondent_id_column | ResponseID
alternative_id_column| CardNumber
```

### Level Name Cleaning

Alchemer exports include prefixes. Set `clean_alchemer_levels = TRUE` to auto-clean:

| Alchemer Format | Cleaned |
|-----------------|---------|
| Low_071 | Low |
| Mid_089 | Mid |
| High_107 | High |
| MSG_Present | Present |
| Brand_Apple | Apple |

---

## Design Recommendations

### Optimal Design

| Element | Recommended |
|---------|-------------|
| Attributes | 4-6 |
| Levels per attribute | 3-4 |
| Alternatives per choice set | 3-4 |
| Choice sets per respondent | 8-12 |
| Minimum respondents | 300 |

### Sample Size Formula

```
recommended_n = max(300, 300 × (n_attributes/4) × (max_levels/4))
```

### Examples

| Design | Recommended n |
|--------|---------------|
| 4 attributes, 4 levels max | 300 |
| 6 attributes, 4 levels max | 450 |
| 6 attributes, 6 levels max | 675 |

---

## Common Mistakes

### Mistake 1: Level Names Don't Match

**Problem:** Error "Level '£449' not found in data"

**Solution:**
- Check exact values in data file
- Match case, spaces, special characters
- Use Text format in Excel to see exact values

### Mistake 2: Multiple Chosen in Same Set

**Problem:** Error "Choice set 5 has 2 chosen alternatives"

**Solution:**
- Each choice set must have exactly ONE chosen=1
- Check data for duplicates

### Mistake 3: Missing Chosen Alternative

**Problem:** Error "Choice set 12 has no chosen alternative"

**Solution:**
- Every choice set must have one chosen=1

### Mistake 4: Wrong Column Names

**Problem:** Error "Column 'choice_set_id' not found"

**Solution:**
- Check Settings sheet column names match data
- May be called `stnumber` in Alchemer

### Mistake 5: NumLevels Mismatch

**Problem:** Warning "NumLevels=3 but found 4 levels"

**Solution:**
- Count comma-separated values in LevelNames
- Update NumLevels to match

### Mistake 6: Case Sensitivity

**Problem:** Utility shows 0 for all levels

**Solution:**
- Level names are case-sensitive
- "Apple" ≠ "apple" ≠ "APPLE"

---

## Troubleshooting

### Model Doesn't Converge

**Solutions:**
1. Reduce number of attributes/levels
2. Check for perfect separation (one level always/never chosen)
3. Increase sample size
4. Try `estimation_method = clogit`

### Hit Rate Too Low

**Expected:** Hit rate should be notably higher than chance rate

**Solutions:**
1. Check data quality
2. Verify attribute levels match data
3. Review choice task design

### Output File Not Created

**Solutions:**
1. Verify output directory exists
2. Close any existing output file
3. Check file permissions

### "Indexes don't define unique observations"

**Cause:** Duplicate (respondent, choice_set, alternative) combinations

**Solution:**
- Ensure each row has unique combination
- Check for data duplication issues

### Memory Errors

**Cause:** Very large dataset

**Solutions:**
1. Use CSV instead of XLSX for data
2. Reduce bootstrap iterations
3. Use `estimation_method = clogit` (faster)

---

## Validation Checklist

Before running analysis, verify:

### Configuration
- [ ] Settings sheet has all required fields
- [ ] Attributes sheet has at least 2 attributes
- [ ] Each attribute has at least 2 levels
- [ ] NumLevels matches LevelNames count

### Data
- [ ] File exists and is readable
- [ ] All required columns present
- [ ] Column names match Settings exactly
- [ ] Level values match Attributes exactly
- [ ] Each choice set has exactly one chosen=1
- [ ] No missing values in attribute columns

### Output
- [ ] Output directory exists
- [ ] No existing file is open

---

**End of User Manual**

*Turas Conjoint Module v2.1.0*
*Last Updated: December 2025*
