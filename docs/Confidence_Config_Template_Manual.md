# Confidence Config Template - User Manual

**Template File:** `templates/Confidence_Config_Template.xlsx`
**Version:** 10.0
**Last Updated:** 4 December 2025

---

## Overview

The Confidence Config Template configures confidence interval analysis in TURAS. This module calculates various types of confidence intervals for survey proportions, means, and NPS scores using multiple statistical methods.

**Key Purpose:** Validate survey estimates with confidence intervals using MOE, Wilson Score, Bootstrap, and Bayesian Credible methods.

**Important:** This module always uses the same data file as used in Tabs analysis.

---

## Template Structure

The template contains **5 sheets**:

1. **Instructions** - Overview and methodology guide
2. **File_Paths** - Data file and output file locations
3. **Study_Settings** - Analysis configuration parameters
4. **Question_Analysis** - Questions to analyze and methods to use
5. **Population_Margins** (Optional) - Population quota comparison

---

## Sheet 1: Instructions

**Purpose:** Provides comprehensive documentation of the confidence interval methods and their appropriate use cases.

**Action Required:** Review for understanding. This sheet is not read by the analysis code.

**Key Content:**
- Methodology reference for all 4 confidence interval methods
- Guidance on which method to use for each statistic type
- Prior parameter explanations and examples
- Quick decision guide for selecting methods

---

## Sheet 2: File_Paths

**Purpose:** Specifies the data file and output file locations.

**Required Columns:** 2 columns only (`Parameter`, `Value`)

### Field Specifications

#### Parameter: Data_File

- **Purpose:** Path to the survey data file
- **Required:** YES
- **Data Type:** Text (file path)
- **Valid Values:** Path to .xlsx, .csv, or .sav file
- **Logic:** Must use the same data file as used in Tabs analysis. Relative paths are relative to the project root.
- **Example:** `03_Data/project_Data.xlsx` or `/Users/username/project/data.xlsx`
- **Common Mistakes:**
  - Using absolute path that won't work on other computers
  - Not matching the exact file used in Tabs
  - File path with spaces not properly handled

#### Parameter: Output_File

- **Purpose:** Location and name for the results Excel file
- **Required:** YES
- **Data Type:** Text (file path)
- **Valid Values:** Path ending in .xlsx
- **Logic:** Creates a multi-sheet Excel workbook with confidence interval results
- **Example:** `04_Analysis/Crosstabs/project_confidence_results.xlsx`
- **Common Mistakes:**
  - Forgetting the .xlsx extension
  - Output directory doesn't exist (create folders first)

#### Parameter: Weight_Variable

- **Purpose:** Name of the weight column in the data file
- **Required:** NO
- **Data Type:** Text (column name) or blank
- **Valid Values:**
  - Column name that exists in data file (case-sensitive)
  - Blank/empty to run unweighted analysis
- **Logic:**
  - If specified, applies weights to all calculations
  - Must be a numeric column
  - Only handles positive weights
  - If blank, analysis runs unweighted
- **Example:** `Weight` or `survey_weight`
- **Common Mistakes:**
  - Misspelling the weight variable name
  - Using a weight column with negative or zero values
  - Weight column contains NA values (these cases will be excluded)

---

## Sheet 3: Study_Settings

**Purpose:** Global settings that apply to all questions in the analysis.

**Required Columns:** 2 columns only (`Setting`, `Value`)

### Field Specifications

#### Setting: Calculate_Effective_N

- **Purpose:** Calculate effective sample size when using weights
- **Required:** YES
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Default:** `N`
- **Logic:**
  - `Y` = Calculate Kish's effective sample size for weighted data
  - `N` = Use actual sample size
  - Only applies when Weight_Variable is specified
- **When to Use:** Set to `Y` when using weights to understand design effect
- **Example:** `N`
- **Common Mistakes:** Setting to Y when not using weights (has no effect)

#### Setting: Multiple_Comparison_Adjustment

- **Purpose:** Apply adjustment for multiple statistical comparisons
- **Required:** YES
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Default:** `N`
- **Logic:**
  - `Y` = Apply correction method specified in Multiple_Comparison_Method
  - `N` = Use unadjusted confidence level
  - Reduces Type I error when testing many questions
- **When to Use:** Set to `Y` when analyzing 10+ questions simultaneously
- **Example:** `N`

#### Setting: Multiple_Comparison_Method

- **Purpose:** Which correction method to use for multiple comparisons
- **Required:** Only if Multiple_Comparison_Adjustment = Y
- **Data Type:** Text
- **Valid Values:** `None`, `Bonferroni`, `Holm`, `BH` (Benjamini-Hochberg)
- **Default:** `None`
- **Logic:**
  - `None` = No adjustment
  - `Bonferroni` = Most conservative (α/n)
  - `Holm` = Slightly less conservative step-down method
  - `BH` = Controls false discovery rate (least conservative)
- **When to Use:** Only matters when Multiple_Comparison_Adjustment = Y
- **Example:** `None`

#### Setting: Bootstrap_Iterations

- **Purpose:** Number of resampling iterations for bootstrap method
- **Required:** YES
- **Data Type:** Integer
- **Valid Values:** 1000 to 10000
- **Default:** `5000`
- **Logic:**
  - Higher values = more accurate but slower
  - 5000 is good balance of accuracy and speed
  - Only used when Run_Bootstrap = Y for a question
- **When to Use:** Increase to 10000 for publication-quality results
- **Example:** `5000`
- **Common Mistakes:** Setting too low (<1000) leads to unstable intervals

#### Setting: Confidence_Level

- **Purpose:** Confidence level for all interval calculations
- **Required:** YES
- **Data Type:** Decimal (0-1)
- **Valid Values:** `0.80` to `0.99`
- **Default:** `0.95`
- **Logic:**
  - `0.95` = 95% confidence intervals (most common)
  - `0.90` = 90% confidence intervals
  - `0.99` = 99% confidence intervals
  - Applies to all methods (MOE, Wilson, Bootstrap, Credible)
- **Example:** `0.95`
- **Common Mistakes:**
  - Entering 95 instead of 0.95
  - Using different levels for different questions (not supported - must use single level)

#### Setting: Decimal_Separator

- **Purpose:** Decimal separator for number display in output
- **Required:** YES
- **Data Type:** Text (single character)
- **Valid Values:** `.` or `,`
- **Default:** `,`
- **Logic:**
  - `.` = US/UK format (8.2)
  - `,` = European format (8,2)
  - Controls display formatting only, not calculations
- **Example:** `,`
- **When to Use:** Match your regional number format

---

## Sheet 4: Question_Analysis

**Purpose:** Define which questions to analyze and which confidence interval methods to apply.

**Required Columns:** `Question_ID`, `Statistic_Type`, `Categories`, `Run_MOE`, `Run_Wilson`, `Run_Bootstrap`, `Run_Credible`

**Optional Columns:** `Prior_Mean`, `Prior_SD`, `Prior_N`, `Promoter_Codes`, `Detractor_Codes`, `Notes`

### Field Specifications

#### Column: Question_ID

- **Purpose:** The question variable to analyze
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Must exactly match column name in data file
- **Logic:**
  - Case-sensitive
  - Must exist in data file
  - Can include same question multiple times with different settings
- **Example:** `Q29`, `Q78`, `satisfaction_rating`
- **Common Mistakes:**
  - Typo in question code
  - Using QuestionText instead of QuestionCode
  - Question doesn't exist in data file

#### Column: Statistic_Type

- **Purpose:** Type of statistic to calculate
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `proportion`, `mean`, `nps`
- **Logic:**
  - `proportion` = Calculate % for specified categories (requires Categories column)
  - `mean` = Calculate average value (numeric data)
  - `nps` = Calculate Net Promoter Score from 0-10 scale (requires Promoter_Codes and Detractor_Codes if not using defaults)
- **Example:** `proportion`
- **Common Mistakes:**
  - Using `proportion` without specifying Categories
  - Using `mean` on categorical data

#### Column: Categories

- **Purpose:** Which response values to include in proportion calculation
- **Required:** YES for `Statistic_Type = proportion`, leave blank for others
- **Data Type:** Text (comma-separated values)
- **Valid Values:**
  - Single value: `Yes`, `1`, `Always`
  - Multiple values: `9, 10` or `4,5`
  - Must exactly match data values (case-sensitive)
- **Logic:**
  - Calculates proportion of respondents selecting ANY of these values
  - For Top 2 Box: `4,5`
  - For single category: `Yes`
- **Example:** `Yes`, `9, 10`, `4,5`
- **Common Mistakes:**
  - Extra spaces (use `9,10` not `9, 10` unless that's how data is coded)
  - Not matching exact data values

#### Column: Run_MOE

- **Purpose:** Run Margin of Error (classic frequentist) confidence interval
- **Required:** YES
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Logic:**
  - `Y` = Calculate classic CI using normal/t-distribution
  - `N` = Skip this method
  - Works with: `proportion`, `mean`, `nps`
  - For proportions: uses normal approximation
  - For means: uses t-distribution
- **When to Use:**
  - Large samples (n>100)
  - Moderate proportions (0.2-0.8)
  - Normally distributed data for means
- **Example:** `Y`

#### Column: Run_Wilson

- **Purpose:** Run Wilson Score Interval confidence interval
- **Required:** YES
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Logic:**
  - `Y` = Calculate Wilson Score interval
  - `N` = Skip this method
  - **ONLY works with: `proportion`** (not mean, not NPS)
  - Better than MOE for small samples or extreme proportions
- **When to Use:** DEFAULT for all proportions - always safe
- **Example:** `Y`
- **Common Mistakes:** Setting Run_Wilson = Y for means or NPS (will error)

#### Column: Run_Bootstrap

- **Purpose:** Run Bootstrap resampling confidence interval
- **Required:** YES
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Logic:**
  - `Y` = Resample data Bootstrap_Iterations times
  - `N` = Skip this method
  - Works with: `proportion`, `mean`, `nps`
  - Computationally intensive but robust
- **When to Use:**
  - Complex weighting
  - Skewed data
  - Small samples
  - Want non-parametric intervals
- **Example:** `Y`

#### Column: Run_Credible

- **Purpose:** Run Bayesian Credible Interval
- **Required:** YES
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Logic:**
  - `Y` = Calculate Bayesian credible interval
  - `N` = Skip this method
  - Works with: `proportion`, `mean`, `nps`
  - Can incorporate prior information via Prior_Mean, Prior_SD, Prior_N
  - If priors not specified, uses uninformative prior
- **When to Use:**
  - Have prior information from pilot/previous wave
  - Small samples needing regularization
  - Want to blend historical data
- **Example:** `Y`

#### Column: Prior_Mean

- **Purpose:** Prior belief about the true value
- **Required:** NO (only if Run_Credible = Y and you want informed prior)
- **Data Type:** Numeric
- **Valid Values:**
  - For `proportion`: 0 to 1 (e.g., 0.45 for 45%)
  - For `mean`: any number on your scale
  - For `nps`: -100 to +100
  - Leave blank for uninformative prior
- **Logic:**
  - Represents your prior belief from pilot/previous study
  - Blank = use default uninformative prior
- **Example:** `0.45` (for 45% awareness in pilot study)

#### Column: Prior_SD

- **Purpose:** Standard deviation of your prior belief
- **Required:** NO (only for `mean` and `nps` when Prior_Mean specified)
- **Data Type:** Numeric (positive)
- **Valid Values:** Any positive number
- **Logic:**
  - Represents uncertainty around Prior_Mean
  - REQUIRED if Prior_Mean specified for mean/NPS
  - NOT used for proportions
- **Example:** `1.5` (for mean rating with SD of 1.5)

#### Column: Prior_N

- **Purpose:** Effective sample size of prior belief
- **Required:** NO (only if Run_Credible = Y and you want informed prior)
- **Data Type:** Integer (positive)
- **Valid Values:** 1 to 1000+
- **Default:** `100` if not specified
- **Logic:**
  - How much you "trust" the prior
  - 100 = weak prior
  - 500 = strong prior
  - Higher = prior has more influence
- **Example:** `200` (if prior based on n=200 pilot study)

#### Column: Promoter_Codes

- **Purpose:** Which NPS values count as promoters
- **Required:** Only for `Statistic_Type = nps` if not using default
- **Data Type:** Text (comma-separated)
- **Valid Values:** Typically `9,10`
- **Default:** `9,10` if left blank
- **Logic:** Values that count as promoters in NPS calculation
- **Example:** `9,10`

#### Column: Detractor_Codes

- **Purpose:** Which NPS values count as detractors
- **Required:** Only for `Statistic_Type = nps` if not using default
- **Data Type:** Text (comma-separated)
- **Valid Values:** Typically `0,1,2,3,4,5,6`
- **Default:** `0,1,2,3,4,5,6` if left blank
- **Logic:** Values that count as detractors in NPS calculation
- **Example:** `0,1,2,3,4,5,6`

#### Column: Notes

- **Purpose:** Internal documentation
- **Required:** NO
- **Data Type:** Text (any)
- **Valid Values:** Any text
- **Logic:** Not used by analysis - for your reference only
- **Example:** `Satisfaction mean (1-10 scale) with informed prior`

---

## Sheet 5: Population_Margins (OPTIONAL)

**Purpose:** Compare actual sample composition to target population quotas. This entire sheet is optional - if not present, analysis runs without margin comparison.

**Required Columns:** `Variable`, `Category_Label`, `Category_Code`, `Target_Prop`, `Include`

### Field Specifications

#### Column: Variable

- **Purpose:** Variable name for quota checking
- **Required:** YES (if using this sheet)
- **Data Type:** Text
- **Valid Values:**
  - Must match column name in data file exactly (case-sensitive)
  - For nested quotas: comma-separated (e.g., `Gender,Age_Group`)
- **Logic:**
  - Single variable: checks marginal quota (e.g., `Gender`)
  - Nested variables: checks interlocked quota (e.g., `Gender,Age_Group`)
- **Example:** `Gender`, `Age_Group`, `Gender,Age_Group`

#### Column: Category_Label

- **Purpose:** Human-readable label for the category
- **Required:** YES (if using this sheet)
- **Data Type:** Text
- **Valid Values:** Any descriptive text
- **Logic:** Used in output reports for readability
- **Example:** `Male`, `Female`, `18-34`, `Male 18-34`

#### Column: Category_Code

- **Purpose:** Actual value as it appears in data
- **Required:** NO (uses Category_Label if blank)
- **Data Type:** Text or Numeric
- **Valid Values:** Must match exactly how category appears in data
- **Logic:**
  - Matching is done as character strings
  - Numeric codes converted to text for matching
  - Case-sensitive
- **Example:** `1`, `M`, `Male`, `18-34`

#### Column: Target_Prop

- **Purpose:** Target proportion for this category in population
- **Required:** YES (if using this sheet)
- **Data Type:** Decimal (0-1)
- **Valid Values:** 0 to 1 (NOT percentages)
- **Logic:**
  - Must be decimal: 0.48 for 48%, NOT 48
  - Should sum to ~1.0 for each Variable
  - Warning issued if sum ≠ 1.0 ± 0.01
- **Example:** `0.48` (for 48% target)
- **Common Mistakes:**
  - Using 48 instead of 0.48
  - Categories for one variable not summing to 1.0

#### Column: Include

- **Purpose:** Whether to include this margin in comparison
- **Required:** NO
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N` (case insensitive)
- **Default:** `Y`
- **Logic:**
  - `Y` = Include in comparison
  - `N` = Exclude but keep in sheet for documentation
- **Example:** `Y`

### Output Flags

When Population_Margins analysis runs, it generates flags:

- **GREEN**: Good match (difference < 2 percentage points)
- **AMBER**: Moderate deviation (difference 2-5 percentage points)
- **RED**: Large deviation (difference > 5 percentage points)
- **MISSING_VAR**: Variable not found in data

---

## Complete Configuration Examples

### Example 1: Simple Proportion with Wilson Score

**Question:** Q29 - "Did you receive a promotion?" (coded as Yes/No)

```
File_Paths sheet:
Parameter       | Value
Data_File       | data/survey.xlsx
Output_File     | output/confidence_results.xlsx
Weight_Variable | Weight

Study_Settings sheet:
Setting                          | Value
Calculate_Effective_N            | N
Multiple_Comparison_Adjustment   | N
Multiple_Comparison_Method       | None
Bootstrap_Iterations             | 5000
Confidence_Level                 | 0.95
Decimal_Separator                | ,

Question_Analysis sheet:
Question_ID | Statistic_Type | Categories | Run_MOE | Run_Wilson | Run_Bootstrap | Run_Credible
Q29         | proportion     | Yes        | Y       | Y          | Y             | Y
```

### Example 2: Mean with Informed Prior

**Question:** Q78 - "Satisfaction rating" (1-10 scale), with prior of 7.2 from pilot (n=500, SD=1.5)

```
Question_Analysis sheet:
Question_ID | Statistic_Type | Run_MOE | Run_Wilson | Run_Bootstrap | Run_Credible | Prior_Mean | Prior_SD | Prior_N
Q78         | mean           | Y       | N          | Y             | Y            | 7.2        | 1.5      | 500
```

### Example 3: NPS with Custom Codes

**Question:** Q79 - NPS (0-10 scale)

```
Question_Analysis sheet:
Question_ID | Statistic_Type | Run_MOE | Run_Wilson | Run_Bootstrap | Run_Credible | Promoter_Codes | Detractor_Codes
Q79         | nps            | N       | N          | N             | Y            | 9,10          | 0,1,2,3,4,5,6
```

---

## Common Mistakes and Troubleshooting

### Mistake 1: Using Wrong Data File

**Problem:** Results don't match Tabs output
**Solution:** Must use the exact same data file as used in Tabs analysis

### Mistake 2: Question Not Found

**Problem:** Error "Question Q29 not found in data"
**Solution:** Check Question_ID spelling matches data column name exactly (case-sensitive)

### Mistake 3: Wilson Score for Non-Proportions

**Problem:** Error when Run_Wilson = Y for mean or NPS
**Solution:** Wilson Score ONLY works for proportions

### Mistake 4: Missing Categories for Proportions

**Problem:** Error "Categories required for proportion"
**Solution:** When Statistic_Type = proportion, must specify Categories

### Mistake 5: Decimal vs Percentage

**Problem:** Prior_Mean = 45 gives strange results
**Solution:** Use 0.45 not 45 for proportions. Use actual scale values for means.

### Mistake 6: Target_Prop Not Summing to 1

**Problem:** Warning about margins not summing correctly
**Solution:** Ensure all Target_Prop values for each Variable sum to 1.0 (±0.01)

---

## Method Selection Guide

### For Proportions (e.g., % aware, % satisfied)

**Recommended Standard:** `Run_Wilson = Y` only
**Recommended Thorough:** `Run_Wilson = Y`, `Run_Bootstrap = Y`
**Why:** Wilson Score handles small samples and extreme proportions better than MOE

### For Means (e.g., rating scales 1-10)

**Recommended Standard:** `Run_MOE = Y` only
**Recommended Thorough:** `Run_MOE = Y`, `Run_Bootstrap = Y`
**Why:** t-distribution (via MOE) is standard for means, Bootstrap adds robustness

### For NPS

**Recommended Standard:** `Run_MOE = Y`, `Run_Bootstrap = Y`
**Recommended Thorough:** `Run_MOE = Y`, `Run_Bootstrap = Y`, `Run_Credible = Y`
**Why:** NPS benefits from multiple methods due to its composite nature

---

## Validation Rules

The module validates:

1. **File Paths:**
   - Data_File exists and is readable
   - Output_File path is writable
   - Weight_Variable exists in data (if specified)

2. **Study Settings:**
   - Confidence_Level between 0.80 and 0.99
   - Bootstrap_Iterations >= 1000

3. **Question Analysis:**
   - All Question_ID exist in data
   - Statistic_Type is valid
   - Categories specified for proportions
   - At least one Run_* method = Y per question
   - Run_Wilson not used with mean/nps
   - Prior_SD specified if Prior_Mean specified for mean/nps

4. **Population Margins (if present):**
   - All Variable names exist in data
   - Target_Prop values between 0 and 1
   - Target_Prop sums to 1.0 ± 0.01 per Variable

---

## Output Structure

The analysis produces an Excel file with these sheets:

1. **Summary** - Overview of all questions analyzed
2. **[Question_ID]_Results** - One sheet per question with:
   - Point estimate
   - All requested confidence intervals
   - Sample size
   - Method comparison
3. **Population_Margins** - Quota comparison (if configured)
4. **Metadata** - Analysis settings and timestamp

---

**End of Confidence Config Template Manual**
