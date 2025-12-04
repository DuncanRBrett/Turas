# Conjoint Config Template - User Manual

**Template File:** `templates/Conjoint_Config_Template.xlsx`
**Version:** 10.0
**Last Updated:** 4 December 2025

---

## Overview

The Conjoint Config Template configures Choice-Based Conjoint (CBC) analysis in TURAS. This module analyzes consumer choices to determine the relative value (utility) of product attributes and levels.

**Key Purpose:** Estimate part-worth utilities for product attributes and run market simulations to predict market share.

**Production Status:** Choice-Based Conjoint (CBC) is FULLY PRODUCTION READY with 50+ tests passed and real-world validation.

---

## Template Structure

The template contains **3 sheets**:

1. **Instructions** - Comprehensive guide to CBC methodology and implementation status
2. **Settings** - Analysis configuration parameters
3. **Attributes** - Product attributes and their levels

---

## Sheet 1: Instructions

**Purpose:** Provides detailed documentation of CBC methods, data requirements, and implementation status.

**Action Required:** Review for understanding. This sheet is not read by the analysis code.

**Key Content:**
- Data file format requirements (resp_id, choice_set_id, alternative_id, attributes, chosen)
- Level name matching requirements (must match data EXACTLY)
- Data validation requirements
- Implementation status of various conjoint methods
- Sample size recommendations

---

## Sheet 2: Settings

**Purpose:** Configure the conjoint analysis parameters and file locations.

**Required Columns:** 2 columns only (`Setting`, `Value`)

### Required Settings

#### Setting: analysis_type

- **Purpose:** Type of conjoint analysis to run
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `choice`
- **Default:** `choice`
- **Logic:** Only Choice-Based Conjoint (CBC) is currently available and production-ready
- **Example:** `choice`
- **Common Mistakes:** Trying to use `rating` or other types (not implemented)

#### Setting: choice_set_column

- **Purpose:** Name of the column identifying choice tasks
- **Required:** YES
- **Data Type:** Text (column name)
- **Valid Values:** Must match column name in data file
- **Default:** `choice_set_id`
- **Logic:**
  - Each choice set is one choice task shown to respondent
  - May be called `stnumber` in Alchemer data
  - Must be numeric or integer
- **Example:** `choice_set_id` or `stnumber`
- **Common Mistakes:** Column name doesn't match data file

#### Setting: chosen_column

- **Purpose:** Name of the column indicating which alternative was chosen
- **Required:** YES
- **Data Type:** Text (column name)
- **Valid Values:** Must match column name in data file
- **Default:** `chosen`
- **Logic:**
  - Binary indicator: 1 = chosen, 0 = not chosen
  - Each choice set must have EXACTLY one chosen=1
  - All others must be chosen=0
- **Example:** `chosen`
- **Common Mistakes:**
  - Multiple chosen=1 in same choice set
  - No chosen=1 in a choice set
  - Values other than 0/1

#### Setting: respondent_id_column

- **Purpose:** Name of the column identifying respondents
- **Required:** YES
- **Data Type:** Text (column name)
- **Valid Values:** Must match column name in data file
- **Default:** `resp_id`
- **Logic:** Unique identifier for each respondent
- **Example:** `resp_id` or `ResponseID`

#### Setting: data_file

- **Purpose:** Path to conjoint choice data file
- **Required:** YES
- **Data Type:** Text (file path)
- **Valid Values:** Path to .csv, .xlsx, or .sav file
- **Logic:**
  - Relative paths are relative to project root
  - File must contain all required columns
- **Example:** `/data/conjoint_test_data.csv`
- **Common Mistakes:** File path incorrect or file doesn't exist

#### Setting: output_file

- **Purpose:** Path and name for results Excel file
- **Required:** YES
- **Data Type:** Text (file path)
- **Valid Values:** Path ending in .xlsx
- **Logic:** Creates multi-sheet Excel workbook with utilities, market simulator, etc.
- **Example:** `/output/conjoint_test_results.xlsx`
- **Common Mistakes:** Directory doesn't exist

### Optional Settings

#### Setting: none_label

- **Purpose:** Label for "None of these" option in choice sets
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** Any text label
- **Default:** (blank - no none option)
- **Logic:**
  - If specified, analysis detects "None" option automatically
  - Module uses 3 detection methods to find none option
  - Use when your design includes opt-out alternative
- **When to Use:** When some choice sets include "None of these" option
- **Example:** `None of these` or `No Purchase`

#### Setting: alternative_id_column

- **Purpose:** Column identifying alternatives within each choice set
- **Required:** NO
- **Data Type:** Text (column name)
- **Valid Values:** Must match column name in data file
- **Default:** (blank)
- **Logic:**
  - Identifies which alternative (A, B, C) each row represents
  - May be called `cardnumber` in Alchemer data
  - Not required but helpful for validation
- **Example:** `alternative_id` or `cardnumber`

#### Setting: rating_variable

- **Purpose:** Column with ratings for rating-based conjoint
- **Required:** NO (not used for CBC)
- **Data Type:** Text (column name)
- **Valid Values:** Column name
- **Default:** (blank)
- **Logic:** Only used for analysis_type='rating' (not implemented)
- **When to Use:** Not applicable for CBC

#### Setting: min_responses_per_level

- **Purpose:** Minimum times each level should be selected
- **Required:** NO
- **Data Type:** Integer
- **Valid Values:** 1 to 1000
- **Default:** `10`
- **Logic:**
  - Issues warning if any level selected fewer times
  - Helps identify levels with insufficient data
  - Does not exclude levels, just warns
- **Example:** `10`

#### Setting: confidence_level

- **Purpose:** Confidence level for utility confidence intervals
- **Required:** NO
- **Data Type:** Decimal (0-1)
- **Valid Values:** 0.80 to 0.99
- **Default:** `0.95`
- **Logic:**
  - 0.95 = 95% confidence intervals (most common)
  - Used in Delta method CI calculations
- **Example:** `0.95`
- **Common Mistakes:** Entering 95 instead of 0.95

#### Setting: baseline_handling

- **Purpose:** How to handle baseline levels in estimation
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** `first_level_zero` or `all_levels_explicit`
- **Default:** `first_level_zero`
- **Logic:**
  - `first_level_zero` = First level utility constrained to 0 before zero-centering (standard)
  - `all_levels_explicit` = All levels estimated explicitly
- **Recommended:** `first_level_zero` (standard econometric approach)
- **Example:** `first_level_zero`

#### Setting: choice_type

- **Purpose:** Type of choice task format
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** `single`, `single_with_none`, `best_worst`, `continuous_sum`
- **Default:** `single`
- **Logic:**
  - `single` = Standard CBC (choose best) ✅ PRODUCTION READY
  - `single_with_none` = CBC with none option ✅ PRODUCTION READY
  - `best_worst` = Best-worst scaling ⚠️ Implemented but not fully tested
  - `continuous_sum` = Allocation tasks ⚠️ Not implemented
- **Recommended:** `single` or `single_with_none`
- **Example:** `single`

#### Setting: estimation_method

- **Purpose:** Which estimation algorithm to use
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** `auto`, `mlogit`, `clogit`, `hb`
- **Default:** `auto`
- **Logic:**
  - `auto` = Module selects best method automatically ✅ RECOMMENDED
  - `mlogit` = Force multinomial logit
  - `clogit` = Force conditional logit
  - `hb` = Hierarchical Bayes (not implemented, requires bayesm package)
- **Recommended:** `auto` (let module choose best method)
- **Example:** `auto`

#### Setting: generate_market_simulator

- **Purpose:** Whether to create interactive market simulator sheet
- **Required:** NO
- **Data Type:** Logical (TRUE/FALSE)
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:**
  - `TRUE` = Creates Excel sheet with dropdown menus for market simulation
  - `FALSE` = Skip simulator (faster output)
- **Recommended:** `TRUE` (simulator very useful for what-if scenarios)
- **Example:** `TRUE`

---

## Sheet 3: Attributes

**Purpose:** Define the product attributes and their levels.

**Required Columns:** 3 columns only (`AttributeName`, `NumLevels`, `LevelNames`)

### Field Specifications

#### Column: AttributeName

- **Purpose:** Name of the product attribute
- **Required:** YES
- **Data Type:** Text
- **Valid Values:**
  - Must match column name in data file EXACTLY
  - Case-sensitive
  - Alphanumeric, underscores allowed
- **Logic:** Each attribute is a product feature (Price, Brand, etc.)
- **Example:** `Price`, `Brand`, `Storage`, `Battery`
- **Common Mistakes:**
  - AttributeName in config doesn't match data column name
  - Using spaces (use underscores instead)

#### Column: NumLevels

- **Purpose:** Number of levels for this attribute
- **Required:** YES
- **Data Type:** Integer
- **Valid Values:** 2 to 10 (warning if >6)
- **Logic:**
  - Must match the count of comma-separated values in LevelNames
  - Minimum 2 levels per attribute (enforced)
  - Warning issued if >6 levels (too many parameters)
- **Example:** `3` (for 3 price points)
- **Common Mistakes:**
  - NumLevels doesn't match actual count in LevelNames
  - Only 1 level specified (minimum is 2)

#### Column: LevelNames

- **Purpose:** Comma-separated list of level values
- **Required:** YES
- **Data Type:** Text (comma-separated)
- **Valid Values:**
  - Must match data values EXACTLY (case-sensitive)
  - No extra spaces unless in data
  - Count must match NumLevels
- **Logic:**
  - These are the actual values as they appear in your data
  - Used to create utility estimates for each level
  - **CRITICAL:** Must match data EXACTLY
- **Example:** `£449, £599, £699` or `Apple, Samsung, Google`
- **Common Mistakes:**
  - Level names don't match data (e.g., config has "$299" but data has "299")
  - Extra spaces (config has "Apple " but data has "Apple")
  - Wrong case (config has "apple" but data has "Apple")

---

## Data File Requirements

Your conjoint data file MUST contain these columns:

### Required Columns

1. **resp_id** (or your respondent_id_column name)
   - Unique identifier for each respondent
   - Data Type: Numeric, integer, or text

2. **choice_set_id** (or your choice_set_column name)
   - Choice task identifier
   - May be called `stnumber` in Alchemer
   - Data Type: Numeric or integer

3. **alternative_id** (or your alternative_id_column name)
   - Alternative within choice set
   - May be called `cardnumber` in Alchemer
   - Data Type: Numeric, integer, or text

4. **Attribute columns** (one per attribute in Attributes sheet)
   - Column name must match AttributeName exactly
   - Values must match LevelNames exactly

5. **chosen** (or your chosen_column name)
   - Binary indicator: 1 = chosen, 0 = not chosen
   - Data Type: Numeric (0 or 1 only)

### Data Structure Example

```
resp_id | choice_set_id | alternative_id | Price | Brand   | Storage | chosen
1       | 1             | 1              | £449  | Apple   | 128GB   | 0
1       | 1             | 2              | £599  | Samsung | 256GB   | 1
1       | 1             | 3              | £699  | Google  | 512GB   | 0
1       | 2             | 1              | £599  | Google  | 128GB   | 1
1       | 2             | 2              | £449  | Apple   | 512GB   | 0
1       | 2             | 3              | £699  | Samsung | 256GB   | 0
```

### Critical Data Validation Rules

1. **Each choice set must have exactly ONE chosen=1**
   - All other rows in that choice set must have chosen=0

2. **LevelNames must match data EXACTLY**
   - `"$299"` ≠ `"299"` ≠ `"$299.00"`
   - `"Apple"` ≠ `"apple"` (case-sensitive)
   - `"Apple"` ≠ `" Apple"` (watch for extra spaces)

3. **No missing values in attribute columns**
   - All attribute values must be populated

4. **Consistent number of alternatives per choice set**
   - Usually 3-5 alternatives per choice set

---

## Design Recommendations

### Hard Limits (Will Error)

- **Minimum attributes:** 2
- **Maximum attributes:** No hard limit, but warning if >6
- **Minimum levels per attribute:** 2
- **Maximum levels per attribute:** No hard limit, but warning if >6

### Optimal Design

- **Attributes:** 4-6 (optimal range)
- **Levels per attribute:** 3-4
- **Choice sets per respondent:** 8-12
- **Alternatives per choice set:** 3-4

### Not Recommended

- **Attributes >8:** Respondent burden too high
- **Levels >6:** Too many parameters to estimate
- **Choice sets <6:** Insufficient data per respondent

### Sample Size Requirements

Formula: `recommended_n = max(300, 300 × (n_attributes/4) × (max_levels/4))`

Examples:
- 4 attributes, 4 levels max: **300 respondents** minimum
- 6 attributes, 4 levels max: **450 respondents** minimum
- 6 attributes, 6 levels max: **675 respondents** minimum

Warning issued if below recommended sample size.

---

## Complete Configuration Example

### Smartphone Choice Study

**Data file structure:**
- 4 attributes: Price, Brand, Storage, Battery
- 3 levels each
- 3 alternatives per choice set
- 10 choice sets per respondent
- 500 respondents

**Settings sheet:**
```
Setting                     | Value
analysis_type               | choice
choice_set_column           | choice_set_id
chosen_column               | chosen
respondent_id_column        | resp_id
data_file                   | /data/smartphone_choices.csv
output_file                 | /output/smartphone_results.xlsx
alternative_id_column       | alternative_id
min_responses_per_level     | 10
confidence_level            | 0.95
baseline_handling           | first_level_zero
choice_type                 | single
estimation_method           | auto
generate_market_simulator   | TRUE
```

**Attributes sheet:**
```
AttributeName | NumLevels | LevelNames
Price         | 3         | £449, £599, £699
Brand         | 3         | Apple, Samsung, Google
Storage       | 3         | 128GB, 256GB, 512GB
Battery       | 3         | 12 hours, 18 hours, 24 hours
```

---

## Common Mistakes and Troubleshooting

### Mistake 1: Level Names Don't Match Data

**Problem:** Error "Level '£449' not found in data"
**Solution:**
- Check data file for exact values
- Match case, spaces, special characters exactly
- In Excel, use Text format to see exact values

### Mistake 2: Multiple Chosen=1 in Same Choice Set

**Problem:** Error "Choice set 5 has 2 chosen alternatives"
**Solution:** Each choice set must have EXACTLY one chosen=1

### Mistake 3: Missing Chosen Alternative

**Problem:** Error "Choice set 12 has no chosen alternative"
**Solution:** Every choice set must have one chosen=1

### Mistake 4: Wrong Column Names

**Problem:** Error "Column 'choice_set_id' not found"
**Solution:**
- Check Settings sheet column names match data file
- May be called `stnumber` in Alchemer data

### Mistake 5: NumLevels Mismatch

**Problem:** Warning "NumLevels=3 but found 4 levels in LevelNames"
**Solution:** Count comma-separated values in LevelNames and update NumLevels

### Mistake 6: Insufficient Sample Size

**Problem:** Warning "Sample size below recommended (300 needed)"
**Solution:**
- Collect more data if possible
- Consider reducing attributes or levels
- Proceed with caution if below minimum

---

## Output Structure

The analysis produces an Excel file with these sheets:

1. **Utilities** - Part-worth utilities for each level
2. **Relative_Importance** - Attribute importance percentages
3. **Market_Simulator** - Interactive dropdown tool for market share prediction
4. **Model_Summary** - Fit statistics and diagnostics
5. **Confidence_Intervals** - Confidence intervals for utilities (if requested)
6. **README** - Interpretation guide

---

## Advanced Features (Phase 2 - Not Fully Tested)

### Best-Worst Scaling

**Status:** ⚠️ Implemented but not production-tested
**To Use:** Set `choice_type = best_worst`
**Requirements:**
- Data must have `best` and `worst` columns
- More testing needed before production use

### Hierarchical Bayes (HB)

**Status:** ⚠️ Framework exists but requires bayesm package
**To Use:** Set `estimation_method = hb`
**Requirements:**
- Install bayesm R package
- Individual-level utilities
- Longer run time (MCMC sampling)
- Not recommended for first-time users

### Continuous Sum / Allocation Tasks

**Status:** ❌ Not implemented
**Future Work:** Requires fractional multinomial logit implementation

---

## Validation Rules

The module validates:

1. **Data File:**
   - File exists and is readable
   - All required columns present
   - Column names match settings

2. **Attributes:**
   - At least 2 attributes
   - At least 2 levels per attribute
   - NumLevels matches LevelNames count
   - All LevelNames found in data

3. **Choice Structure:**
   - Each choice set has exactly one chosen=1
   - Consistent alternatives per choice set
   - No missing attribute values

4. **Sample Size:**
   - Warning if below recommended n
   - Check min_responses_per_level

5. **Settings:**
   - Valid choice_type and estimation_method
   - Confidence_level between 0.80 and 0.99
   - Output directory is writable

---

**End of Conjoint Config Template Manual**
