# Crosstab Config Template - User Manual

**Template File:** `templates/Crosstab_Config_Template.xlsx`
**Version:** 10.0
**Last Updated:** 4 December 2025

---

## Overview

The Crosstab Config Template configures cross-tabulation analysis in TURAS. It defines settings and parameters for generating weighted cross-tabulation reports with statistical testing.

**Key Purpose:** Configure crosstab analysis settings. This template works with Survey_Structure_Template to define which questions to analyze and how to present results.

**Important:** This template defines settings only. Question codes and banner definitions are in the Selection sheet. All question details are defined in Survey_Structure_Template.

---

## Template Structure

The template contains **4 sheets**:

1. **Instructions** - Overview and usage guidance
2. **Settings** - Analysis configuration parameters
3. **Selection** - Question and banner selection
4. **Base Filters** - Example filter syntax (reference only)

---

## Sheet 1: Instructions

**Purpose:** Provides overview of template usage.

**Action Required:** Review for understanding. This sheet is not read by the analysis code.

**Key Content:**
- Template purpose and workflow
- How to configure settings
- Required vs optional fields
- File path conventions

---

## Sheet 2: Settings

**Purpose:** Configure all analysis parameters including file paths, weighting, display options, significance testing, and performance settings.

**Required Columns:** 2 columns only (`Setting`, `Value`)

**Important:** Headers in the template (like "File Paths", "Weighting", etc.) are for organization only - do NOT copy these header rows to your working config file.

### File Paths Settings

#### Setting: structure_file

- **Purpose:** Path to Survey_Structure file
- **Required:** YES
- **Data Type:** Text (file path)
- **Valid Values:** Path to Survey_Structure_Template.xlsx file
- **Logic:**
  - Relative to project root
  - Contains all question definitions, option labels, and composite metrics
  - Must exist and be readable
- **Example:** `Config/Survey_Structure.xlsx` or `-` if in same directory
- **Common Mistakes:**
  - File doesn't exist
  - Path incorrect

#### Setting: output_subfolder

- **Purpose:** Subfolder within Output/ for crosstab results
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Any folder name
- **Default:** `Crosstabs`
- **Logic:** Creates this subfolder if it doesn't exist
- **Example:** `Crosstabs` or `Wave1_Tabs`

#### Setting: output_filename

- **Purpose:** Name of output Excel file
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Filename ending in .xlsx
- **Default:** `Crosstabs.xlsx`
- **Logic:** Final output file will be in output_subfolder/output_filename
- **Example:** `Crosstabs.xlsx` or `Q1_2024_Results.xlsx`

#### Setting: output_format

- **Purpose:** Format for output file
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `xlsx` or `csv`
- **Default:** `xlsx`
- **Logic:**
  - `xlsx` = Multi-sheet Excel workbook (recommended)
  - `csv` = Separate CSV files per question
- **Example:** `xlsx`

### Weighting Settings

#### Setting: apply_weighting

- **Purpose:** Enable or disable weighting
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Logic:**
  - `TRUE` = Apply weights from weight_variable column
  - `FALSE` = Unweighted analysis
  - Requires weight_variable to be specified if TRUE
- **Example:** `FALSE`
- **Common Mistakes:** Setting TRUE without specifying weight_variable

#### Setting: weight_variable

- **Purpose:** Name of weight column in data
- **Required:** Only if apply_weighting = TRUE
- **Data Type:** Text (column name) or `-`
- **Valid Values:**
  - Column name that exists in data file
  - `-` if not using weights
- **Logic:**
  - Must be numeric column
  - Only positive weights supported
  - NA weights excluded with warning
- **Example:** `Weight` or `survey_weight` or `-`

#### Setting: show_unweighted_n

- **Purpose:** Show unweighted base row in output
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:**
  - `TRUE` = Show actual sample counts
  - `FALSE` = Hide unweighted n (only show weighted if applicable)
- **Example:** `TRUE`

#### Setting: show_effective_n

- **Purpose:** Show effective sample size for weighted data
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:**
  - `TRUE` = Calculate and show Kish's effective n
  - `FALSE` = Don't show effective n
  - Only applies when apply_weighting = TRUE
- **When to Use:** Shows design effect of weighting scheme
- **Example:** `TRUE`

#### Setting: weight_label

- **Purpose:** Label added to weighted tables
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Any text
- **Default:** `Weighted`
- **Logic:** Appears in output to distinguish weighted results
- **Example:** `Weighted` or `Final Weight`

#### Setting: weight_na_threshold

- **Purpose:** Warning threshold for % NA weights
- **Required:** YES
- **Data Type:** Numeric (0-100)
- **Valid Values:** 0 to 100
- **Default:** `10`
- **Logic:** Issues warning if >X% of weight values are NA
- **Example:** `10`

#### Setting: weight_zero_threshold

- **Purpose:** Warning threshold for % zero weights
- **Required:** YES
- **Data Type:** Numeric (0-100)
- **Valid Values:** 0 to 100
- **Default:** `5`
- **Logic:** Issues warning if >X% of weights are zero
- **Example:** `5`

#### Setting: weight_deff_warning

- **Purpose:** Design effect warning threshold
- **Required:** YES
- **Data Type:** Numeric
- **Valid Values:** 1 to 10
- **Default:** `3`
- **Logic:**
  - Issues warning if design effect > threshold
  - Design effect = unweighted_n / effective_n
  - High deff indicates inefficient weighting
- **Example:** `3`

### Display Settings

#### Setting: show_frequency

- **Purpose:** Show raw counts in tables
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:**
  - `TRUE` = Show n for each cell
  - `FALSE` = Hide counts
- **Example:** `TRUE`

#### Setting: show_percent_column

- **Purpose:** Show column percentages
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:**
  - `TRUE` = Show % within each banner column
  - `FALSE` = Don't show column %
  - Most common for crosstabs
- **Example:** `TRUE`

#### Setting: show_percent_row

- **Purpose:** Show row percentages
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Logic:**
  - `TRUE` = Show % within each response option (row)
  - `FALSE` = Don't show row %
  - Less common than column %
- **Example:** `FALSE`

#### Setting: decimal_separator

- **Purpose:** Decimal separator for number display
- **Required:** YES
- **Data Type:** Text (single character)
- **Valid Values:** `.` or `,`
- **Default:** `,`
- **Logic:**
  - `.` = US/UK format (8.2)
  - `,` = European format (8,2)
  - Display formatting only
- **Example:** `,`

#### Setting: decimal_places_percent

- **Purpose:** Decimal places for percentages
- **Required:** YES
- **Data Type:** Integer (0-5)
- **Valid Values:** 0 to 5
- **Default:** `0`
- **Logic:**
  - 0 = whole numbers (45%)
  - 1 = one decimal (45.3%)
- **Example:** `0`

#### Setting: decimal_places_ratings

- **Purpose:** Decimal places for rating means
- **Required:** YES
- **Data Type:** Integer (0-5)
- **Valid Values:** 0 to 5
- **Default:** `1`
- **Logic:**
  - Applies to Rating question type means
  - 1 = one decimal (7.5)
- **Example:** `1`

#### Setting: decimal_places_index

- **Purpose:** Decimal places for Likert indices
- **Required:** YES
- **Data Type:** Integer (0-5)
- **Valid Values:** 0 to 5
- **Default:** `1`
- **Logic:**
  - Applies to Likert question index scores
  - 1 = one decimal (67.3)
- **Example:** `1`

#### Setting: zero_division_as_blank

- **Purpose:** How to display 0/0 divisions
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:**
  - `TRUE` = Show blank cell for 0/0
  - `FALSE` = Show "0" for 0/0
- **Example:** `TRUE`

### BoxCategory Settings

#### Setting: boxcategory_frequency

- **Purpose:** Show counts for BoxCategory summaries
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Logic:**
  - BoxCategory groups options (e.g., Top 2 Box)
  - Defined in Survey_Structure Options sheet
- **Example:** `FALSE`

#### Setting: boxcategory_percent_column

- **Purpose:** Show column % for BoxCategory summaries
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:** Most common - show % for grouped categories
- **Example:** `TRUE`

#### Setting: boxcategory_percent_row

- **Purpose:** Show row % for BoxCategory summaries
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Logic:** Less common for BoxCategory
- **Example:** `FALSE`

### Significance Testing Settings

#### Setting: enable_significance_testing

- **Purpose:** Enable statistical significance testing
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:**
  - `TRUE` = Test differences between banner columns
  - `FALSE` = No testing, just descriptive stats
- **Example:** `TRUE`

#### Setting: alpha

- **Purpose:** Significance level for testing
- **Required:** YES
- **Data Type:** Decimal (0.001-0.5)
- **Valid Values:** 0.001 to 0.5
- **Default:** `0.05`
- **Logic:**
  - 0.05 = 95% confidence (most common)
  - 0.01 = 99% confidence
  - Lower = more stringent
- **Example:** `0.05`

#### Setting: significance_min_base

- **Purpose:** Minimum base size for significance testing
- **Required:** YES
- **Data Type:** Integer (1-1000000)
- **Valid Values:** 1 to 1000000
- **Default:** `30`
- **Logic:**
  - Skip testing if n < this threshold
  - 30 is common minimum for reliable tests
- **Example:** `30`

#### Setting: bonferroni_correction

- **Purpose:** Apply Bonferroni correction for multiple comparisons
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:**
  - `TRUE` = Adjust alpha for number of comparisons
  - `FALSE` = Use unadjusted alpha
  - Reduces Type I error when testing many columns
- **Example:** `TRUE`

### Ranking Settings (Optional)

#### Setting: ranking_tie_threshold_pct

- **Purpose:** Warning threshold for tied ranks
- **Required:** YES
- **Data Type:** Numeric (0-100)
- **Valid Values:** 0 to 100
- **Default:** `5`
- **Logic:** Issues warning if >X% of rankings are ties
- **Example:** `5`

#### Setting: ranking_gap_threshold_pct

- **Purpose:** Warning threshold for gaps in rankings
- **Required:** YES
- **Data Type:** Numeric (0-100)
- **Valid Values:** 0 to 100
- **Default:** `5`
- **Logic:** Issues warning if >X% have missing rank positions
- **Example:** `5`

#### Setting: ranking_completeness_threshold_pct

- **Purpose:** Warning threshold for ranking completeness
- **Required:** YES
- **Data Type:** Numeric (0-100)
- **Valid Values:** 0 to 100
- **Default:** `80`
- **Logic:** Issues warning if <X% completed all ranks
- **Example:** `80`

#### Setting: ranking_min_base

- **Purpose:** Minimum base for ranking comparisons
- **Required:** NO
- **Data Type:** Integer (1-1000)
- **Valid Values:** 1 to 1000
- **Default:** `10`
- **Logic:** **NOTE: This setting is not currently implemented and has no effect**
- **Example:** `10`

### Performance Settings

#### Setting: enable_checkpointing

- **Purpose:** Save progress during long analyses
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:**
  - `TRUE` = Save after each question (helpful for large surveys)
  - `FALSE` = No checkpointing (faster but no recovery)
- **Example:** `TRUE`

### Additional Settings

#### Setting: show_standard_deviation

- **Purpose:** Show standard deviation for numeric/rating questions
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Example:** `FALSE`

#### Setting: test_net_differences

- **Purpose:** Test significance of net differences
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Example:** `FALSE`

#### Setting: create_sample_composition

- **Purpose:** Create sample composition summary sheet
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Example:** `FALSE`

#### Setting: enable_chi_square

- **Purpose:** Run chi-square tests
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Example:** `FALSE`

#### Setting: show_net_positive

- **Purpose:** Show net positive scores for Likert questions
- **Required:** NO
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Example:** `TRUE`

### Numeric Question Settings

#### Setting: show_numeric_median

- **Purpose:** Show median for Numeric questions
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Logic:** Unweighted only
- **Example:** `FALSE`

#### Setting: show_numeric_mode

- **Purpose:** Show mode for Numeric questions
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Logic:** Unweighted only
- **Example:** `FALSE`

#### Setting: show_numeric_outliers

- **Purpose:** Show outlier count using IQR method
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Example:** `FALSE`

#### Setting: exclude_outliers_from_stats

- **Purpose:** Remove outliers from mean/SD calculations
- **Required:** YES
- **Data Type:** TRUE/FALSE
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `FALSE`
- **Logic:** Uses outlier_method to detect outliers
- **Example:** `FALSE`

#### Setting: outlier_method

- **Purpose:** Outlier detection method
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** `IQR`
- **Default:** `IQR`
- **Logic:** Only IQR method currently supported
- **Example:** `IQR`

#### Setting: decimal_places_numeric

- **Purpose:** Decimal places for numeric statistics
- **Required:** YES
- **Data Type:** Integer (0-5)
- **Valid Values:** 0 to 5
- **Default:** `1`
- **Example:** `1`

### Summary Sheet Settings

#### Setting: create_index_summary

- **Purpose:** Create the Index_Summary sheet
- **Required:** YES
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Default:** `Y`
- **Logic:**
  - `Y` = Create summary of all index metrics
  - `N` = Skip Index_Summary sheet
- **Example:** `Y`

#### Setting: index_summary_show_sections

- **Purpose:** Group metrics by SectionLabel in summary
- **Required:** YES
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Default:** `Y`
- **Logic:**
  - `Y` = Group by sections
  - `N` = Flat list
- **Example:** `Y`

#### Setting: index_summary_show_base_sizes

- **Purpose:** Show base sizes at bottom of Index_Summary
- **Required:** YES
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Default:** `Y`
- **Example:** `Y`

#### Setting: index_summary_show_composites

- **Purpose:** Include composite scores in Index_Summary
- **Required:** YES
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Default:** `Y`
- **Logic:**
  - `Y` = Include composites from Composite_Metrics sheet
  - `N` = Exclude composites
- **Example:** `Y`

#### Setting: index_summary_decimal_places

- **Purpose:** Decimal places for Index_Summary
- **Required:** YES
- **Data Type:** Integer (0-3)
- **Valid Values:** 0 to 3
- **Default:** `1`
- **Example:** `1`

---

## Sheet 3: Selection

**Purpose:** Define which questions to analyze and banner variables.

**Required Columns:** `QuestionCode`, `Include`, `UseBanner`, `BannerBoxCategory`, `BannerLabel`, `DisplayOrder`, `CreateIndex`, `BaseFilter`, `QuestionText`

**Important:** The yellow highlighted columns are your columns to complete. QuestionText is for reference only.

### Field Specifications

#### Column: QuestionCode

- **Purpose:** Question identifier
- **Required:** YES
- **Data Type:** Text
- **Valid Values:**
  - Must match column header in data file
  - Must match Question sheet in Survey_Structure
  - For multi-mention/ranking: show root code only (e.g., Q01 not Q01_1)
- **Logic:** Links to both data and Survey_Structure
- **Example:** `Q01`, `Q29`, `satisfaction`
- **Common Mistakes:**
  - Including _1, _2 suffix for multi-mention (use root code only)
  - Typo doesn't match data or structure file

#### Column: Include

- **Purpose:** Whether to analyze this question
- **Required:** YES
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Logic:**
  - `Y` = Include in crosstabs output
  - `N` = Skip this question
- **Example:** `Y`

#### Column: UseBanner

- **Purpose:** Use this question as banner variable
- **Required:** NO
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Logic:**
  - `Y` = This question's responses become banner columns
  - `N` = Regular question, not used in banner
  - Banner variables define column breakouts
- **Example:** `Y` for demographic questions like Gender, Age

#### Column: BannerBoxCategory

- **Purpose:** Combine variables in banner using BoxCategory grouping
- **Required:** NO
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Logic:**
  - `Y` = Use BoxCategory combinations from Survey_Structure Options sheet
  - `N` = Show each option separately
  - Only applicable if UseBanner = Y
  - Example: Combine 18-20 and 21-24 into "Under 25"
- **Example:** `Y` if wanting combined age groups in banner

#### Column: BannerLabel

- **Purpose:** Custom banner header label
- **Required:** Only if UseBanner = Y
- **Data Type:** Text
- **Valid Values:** Any descriptive text
- **Logic:** Appears as column group header in output
- **Example:** `Age`, `Gender`, `Region`

#### Column: DisplayOrder

- **Purpose:** Order of banner columns
- **Required:** Only if UseBanner = Y
- **Data Type:** Integer
- **Valid Values:** Any integer
- **Logic:**
  - Lower numbers appear first (left)
  - Determines column order in output tables
- **Example:** `1`, `2`, `3`

#### Column: CreateIndex

- **Purpose:** Generate mean/index score for this question
- **Required:** NO
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Logic:**
  - `Y` = Calculate index score
  - Requires Index_Weight setup in Survey_Structure Options sheet
  - Can exclude DK/NA in Options sheet with ExcludeFromIndex
- **Example:** `Y` for Likert and Rating questions

#### Column: BaseFilter

- **Purpose:** Filter expression for this question
- **Required:** NO
- **Data Type:** Text (R expression)
- **Valid Values:** Valid R logical expression
- **Logic:**
  - Filters data before analyzing this question
  - Uses R syntax
  - See Base Filters sheet for examples
- **Example:** `Q1 == "Male"` or `Q16 %in% c("Store", "Online")`

#### Column: QuestionText

- **Purpose:** Reference information only
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** Any text
- **Logic:** **Has no actual effect** - for your reference only
- **Example:** `Q01: Overall satisfaction`

---

## Sheet 4: Base Filters

**Purpose:** Illustrative examples of filter syntax. This sheet is for reference only and does not need to be carried over to your working config.

**Action Required:** Review for syntax examples. Not read by analysis code.

### Filter Examples

#### Single Value Filter
```
Filter Expression: Q1 == "Male"
Description: Males only
```

#### Multiple Values Filter
```
Filter Expression: Q16 %in% c("Store", "Online", "Phone")
Description: Any of these channels
```

#### Numeric Range Filter
```
Filter Expression: Q30 >= 5 & Q30 <= 20
Description: Purchased 5-20 units
```

#### Combined Filter
```
Filter Expression: Q1 == "Female" & Q2 %in% c("18-34", "35-44")
Description: Female 18-44
```

#### Not Null Filter
```
Filter Expression: !is.na(Q20)
Description: Has satisfaction rating
```

---

## Complete Configuration Example

### Satisfaction Study with Demographics

**Settings sheet (partial):**
```
Setting                          | Value
structure_file                   | Config/Survey_Structure.xlsx
output_subfolder                 | Crosstabs
output_filename                  | Results.xlsx
output_format                    | xlsx
apply_weighting                  | TRUE
weight_variable                  | Weight
show_unweighted_n                | TRUE
show_effective_n                 | TRUE
show_frequency                   | TRUE
show_percent_column              | TRUE
show_percent_row                 | FALSE
decimal_separator                | ,
decimal_places_percent           | 0
decimal_places_ratings           | 1
enable_significance_testing      | TRUE
alpha                            | 0.05
significance_min_base            | 30
bonferroni_correction            | TRUE
create_index_summary             | Y
```

**Selection sheet:**
```
QuestionCode | Include | UseBanner | BannerBoxCategory | BannerLabel | DisplayOrder | CreateIndex | BaseFilter
Total        | N       | Y         | N                 | Total       | 1            | N           |
Q01_Gender   | Y       | Y         | N                 | Gender      | 2            | N           |
Q02_Age      | Y       | Y         | Y                 | Age         | 3            | N           |
Q10_Sat      | Y       | N         | N                 |             |              | Y           |
Q11_NPS      | Y       | N         | N                 |             |              | N           |
```

---

## Common Mistakes and Troubleshooting

### Mistake 1: Structure File Not Found

**Problem:** Error "Survey_Structure file not found"
**Solution:**
- Check structure_file path is correct
- Ensure file exists
- Use relative path from project root

### Mistake 2: QuestionCode Mismatch

**Problem:** Error "Question Q01 not found in data"
**Solution:**
- Check QuestionCode matches data column name exactly
- Check QuestionCode exists in Survey_Structure Questions sheet
- For multi-mention: use root code without _1, _2

### Mistake 3: Weight Variable Not Found

**Problem:** Error "Weight variable 'Weight' not in data"
**Solution:**
- Check weight_variable spelling matches data
- Set apply_weighting = FALSE if not using weights
- Use `-` for weight_variable if not applying weights

### Mistake 4: Banner Without Label

**Problem:** Warning "Banner question missing BannerLabel"
**Solution:** When UseBanner = Y, must provide BannerLabel

### Mistake 5: Invalid Filter Syntax

**Problem:** Error in BaseFilter expression
**Solution:**
- Use R syntax: `==` for equals, `%in%` for multiple values
- Use `&` for AND, `|` for OR
- Enclose text in quotes: `"Male"` not `Male`

### Mistake 6: Decimal Places Out of Range

**Problem:** Warning about decimal places
**Solution:** Must be 0-5 for percent, 0-3 for index_summary

---

## Integration with Survey_Structure

This config file works together with Survey_Structure_Template:

**Crosstab_Config defines:**
- Which questions to analyze (Selection sheet)
- Banner variables
- Display settings
- Significance testing parameters

**Survey_Structure defines:**
- Question types (Single_Mention, Multi_Mention, Likert, Rating, NPS, etc.)
- Response option codes and labels
- Index weights for Likert questions
- BoxCategory groupings
- Composite metrics

**Both files required** - they must match on QuestionCode.

---

## Validation Rules

The module validates:

1. **File Paths:**
   - structure_file exists
   - Output directory writable

2. **Settings:**
   - Decimal places in valid range (0-5 or 0-3)
   - Alpha between 0.001 and 0.5
   - Valid TRUE/FALSE values

3. **Selection Sheet:**
   - All QuestionCode exist in data
   - All QuestionCode exist in Survey_Structure
   - Banner questions have BannerLabel
   - DisplayOrder is numeric

4. **Weighting:**
   - weight_variable exists in data if apply_weighting = TRUE
   - Weight values are numeric and positive

5. **Base Filters:**
   - Valid R expression syntax

---

## Output Structure

Analysis produces Excel file with:

1. **Index_Summary** - Summary of all index metrics (if create_index_summary = Y)
2. **[QuestionCode]** - One sheet per question with crosstabs
3. **Metadata** - Analysis settings and timestamp
4. **Sample_Composition** - Demographics summary (if create_sample_composition = TRUE)

---

**End of Crosstab Config Template Manual**
