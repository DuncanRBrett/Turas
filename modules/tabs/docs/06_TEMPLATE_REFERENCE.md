---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tabs - Template Reference

**Version:** 10.0 **Date:** 22 December 2025

This document explains every field in both configuration templates. When
you're filling in a template and wondering "what does this field do?",
this is your reference.

The templates are in the `templates/` subfolder: -
`Crosstab_Config_Template.xlsx` - Analysis configuration -
`Survey_Structure_Template.xlsx` - Survey definition

------------------------------------------------------------------------

# Chapter 1: Crosstab Config Template

The Crosstab Config template controls how your analysis runs. It tells
Tabs where to find files, which questions to analyze, and how to format
the output.

## Template Structure

The template has four sheets:

1.  **Instructions** - Usage guidance (not read by Tabs)
2.  **Settings** - Analysis configuration parameters
3.  **Selection** - Which questions to analyze and use as banners
4.  **Base Filters** - Example filter syntax (reference only)

------------------------------------------------------------------------

## Settings Sheet

The Settings sheet uses a simple two-column format: `Setting` and
`Value`. Each row defines one configuration option.

The settings are organized into logical groups. When copying to your
working file, you only need the Setting and Value columns - the section
headers in the template are for your reference only.

### File Path Settings

#### structure_file

**What it does:** Tells Tabs where to find your Survey Structure file.

**Required:** Yes

**What to enter:** The path to your Survey_Structure.xlsx file, relative
to your project folder.

**Examples:** - `Survey_Structure.xlsx` (same folder as config) -
`Config/Survey_Structure.xlsx` (in a subfolder) - `-` (use hyphen if the
structure file is in the same directory with default name)

**If it's wrong:** Tabs will fail with "Survey Structure file not
found".

#### output_subfolder

**What it does:** Names the folder where Tabs will save output files.

**Required:** Yes

**What to enter:** A folder name. Tabs creates it inside your project's
Output folder if it doesn't exist.

**Default:** `Crosstabs`

**Examples:** - `Crosstabs` - `Wave1_Results` - `Client_Deliverable`

#### output_filename

**What it does:** Names your output Excel file.

**Required:** Yes

**What to enter:** A filename ending in .xlsx.

**Default:** `Crosstabs.xlsx`

**Examples:** - `Crosstabs.xlsx` - `Brand_Tracker_Q1_2024.xlsx` -
`Results.xlsx`

#### output_format

**What it does:** Controls the output file format.

**Required:** Yes

**What to enter:** Either `xlsx` or `csv`.

**Default:** `xlsx`

**What each option does:** - `xlsx` creates a single Excel workbook with
multiple sheets (recommended for most uses) - `csv` creates separate CSV
files for each question (useful for importing into other systems)

------------------------------------------------------------------------

### Weighting Settings

#### apply_weighting

**What it does:** Turns weighting on or off for the entire analysis.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `FALSE`

**When to use TRUE:** When your data file contains a weight column and
you want weighted results.

**When to use FALSE:** When you want unweighted counts and percentages
(raw sample data).

**Important:** If you set this to TRUE, you must also specify
weight_variable.

#### weight_variable

**What it does:** Tells Tabs which column in your data contains weight
values.

**Required:** Only if apply_weighting = TRUE

**What to enter:** The exact column name from your data file, or `-` if
not using weights.

**Examples:** - `Weight` - `survey_weight` - `Weight_Final` - `-` (if
apply_weighting = FALSE)

**If it's wrong:** Tabs will fail with "Weight variable not found in
data".

#### show_unweighted_n

**What it does:** Controls whether the output shows the actual
respondent count (before weighting).

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `TRUE`

**Why you'd want TRUE:** Clients often want to see both the weighted
population estimate and the actual sample size. The unweighted count
tells you how many people actually answered.

**Why you'd want FALSE:** If you only want to show weighted figures and
don't want to clutter the output with multiple base rows.

#### show_effective_n

**What it does:** Controls whether the output shows the effective sample
size (accounts for weighting efficiency loss).

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `TRUE`

**What effective N means:** When you weight data, some respondents count
more than others. This reduces your effective statistical power.
Effective N tells you how many unweighted respondents your weighted
sample is equivalent to for statistical purposes.

**Why you'd want TRUE:** Understanding the real precision of your
estimates. If weighted N is 1,000 but effective N is 600, you have less
precision than the raw number suggests.

**Why you'd want FALSE:** If you don't need to communicate this level of
detail.

#### weight_label

**What it does:** Sets the label shown in output to indicate weighted
values.

**Required:** Yes

**What to enter:** Any descriptive text.

**Default:** `Weighted`

**Examples:** - `Weighted` - `Population Estimate` - `Final Weight`

This label appears in the output so readers know which rows are
weighted.

#### weight_na_threshold

**What it does:** Sets the percentage of NA (missing) weights that
triggers a warning.

**Required:** Yes

**What to enter:** A number from 0 to 100.

**Default:** `10`

**How it works:** If more than this percentage of weight values are
missing, Tabs warns you. A high percentage of missing weights suggests a
problem with your data or weight variable specification.

#### weight_zero_threshold

**What it does:** Sets the percentage of zero weights that triggers a
warning.

**Required:** Yes

**What to enter:** A number from 0 to 100.

**Default:** `5`

**How it works:** Zero weights effectively remove respondents from the
analysis. If too many weights are zero, it might indicate a weighting
problem.

#### weight_deff_warning

**What it does:** Sets the Design Effect (DEFF) threshold that triggers
a warning.

**Required:** Yes

**What to enter:** A number from 1 to 10.

**Default:** `3`

**What DEFF means:** DEFF measures how much your weighting reduces
statistical efficiency. A DEFF of 1.0 means no loss (all weights equal).
A DEFF of 2.0 means your sample is only worth half its nominal size for
statistical purposes.

**Why 3 is the default:** A DEFF above 3 usually indicates problematic
weighting - extreme weight values, high variance in weights, or an
inadequate weighting scheme.

------------------------------------------------------------------------

### Display Settings

#### show_frequency

**What it does:** Controls whether output tables include raw counts.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `TRUE`

**When to use TRUE:** When you want to see both counts and percentages.
Useful for checking base sizes and understanding absolute numbers.

**When to use FALSE:** When you only want percentages and want cleaner,
more compact tables.

#### show_percent_column

**What it does:** Controls whether output shows column percentages (the
most common type of crosstab percentage).

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `TRUE`

**What column percentages mean:** Each cell shows the percentage within
its column. For example, if 200 out of 500 males are "Very Satisfied",
that cell shows 40%.

**When to use TRUE:** Almost always. Column percentages are the standard
for crosstabs.

#### show_percent_row

**What it does:** Controls whether output shows row percentages.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `FALSE`

**What row percentages mean:** Each cell shows the percentage within its
row. For example, if 200 males and 150 females are "Very Satisfied", the
male cell shows 57% (200/350) and the female cell shows 43% (150/350).

**When to use TRUE:** When you want to see how each response option
breaks down across banner columns. Less common than column percentages.

#### decimal_separator

**What it does:** Sets which character separates whole numbers from
decimals.

**Required:** Yes

**What to enter:** Either `.` or `,`

**Default:** `,`

**Examples:** - `.` produces 8.2 (US/UK format) - `,` produces 8,2
(European format)

This only affects display formatting; calculations are unaffected.

#### decimal_places_percent

**What it does:** Sets how many decimal places to show for percentage
values.

**Required:** Yes

**What to enter:** A number from 0 to 5.

**Default:** `0`

**Examples:** - `0` produces 45% - `1` produces 45.3% - `2` produces
45.28%

Most market research uses 0 or 1 decimal place for percentages.

#### decimal_places_ratings

**What it does:** Sets how many decimal places to show for Rating
question means.

**Required:** Yes

**What to enter:** A number from 0 to 5.

**Default:** `1`

**Examples:** - `1` produces 3.8 - `2` produces 3.82

Rating means typically show 1 or 2 decimal places.

#### decimal_places_index

**What it does:** Sets how many decimal places to show for Likert index
scores.

**Required:** Yes

**What to enter:** A number from 0 to 5.

**Default:** `1`

Index scores are usually displayed with 1 decimal place.

#### zero_division_as_blank

**What it does:** Controls how cells with zero base are displayed.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `TRUE`

**What this affects:** When a cell has a zero base (no respondents),
dividing to get a percentage produces an undefined result.

-   `TRUE` shows an empty cell (cleaner look)
-   `FALSE` shows "0" or "0%"

------------------------------------------------------------------------

### BoxCategory Settings

BoxCategory lets you group response options into summary categories
(like "Top 2 Box").

#### boxcategory_frequency

**What it does:** Controls whether BoxCategory summaries show counts.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `FALSE`

Usually you just want the percentage for summary categories, not the
counts.

#### boxcategory_percent_column

**What it does:** Controls whether BoxCategory summaries show column
percentages.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `TRUE`

This is the main way BoxCategory summaries are displayed - as a
percentage of the column.

#### boxcategory_percent_row

**What it does:** Controls whether BoxCategory summaries show row
percentages.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `FALSE`

Row percentages are uncommon for BoxCategory summaries.

------------------------------------------------------------------------

### Significance Testing Settings

#### enable_significance_testing

**What it does:** Turns statistical significance testing on or off.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `TRUE`

**When to use TRUE:** When you want to know if differences between
banner columns are statistically meaningful.

**When to use FALSE:** When you just want descriptive statistics without
testing, or when sample sizes are too small for valid testing.

#### alpha

**What it does:** Sets the significance level for testing.

**Required:** Yes

**What to enter:** A decimal between 0.001 and 0.5.

**Default:** `0.05`

**What it means:** - `0.05` = 95% confidence level (most common) -
`0.10` = 90% confidence level (more lenient, finds more "significant"
differences) - `0.01` = 99% confidence level (stricter, fewer false
positives)

A lower alpha means you need stronger evidence to declare a difference
significant.

#### significance_min_base

**What it does:** Sets the minimum sample size required for significance
testing.

**Required:** Yes

**What to enter:** An integer from 1 to 1000000.

**Default:** `30`

**Why this matters:** Statistical tests become unreliable with very
small samples. If a banner column has fewer respondents than this
threshold, significance tests won't be performed for that column.

**What 30 means:** This is a common statistical rule of thumb. You can
lower it (to 20) if needed, but be aware results become less reliable.

#### bonferroni_correction

**What it does:** Controls whether to adjust for multiple comparisons.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `TRUE`

**What it does when TRUE:** Adjusts the significance threshold to
account for making many comparisons simultaneously. This reduces false
positives but makes it harder to find significant differences.

**What it does when FALSE:** Uses the unadjusted alpha level for each
comparison. You'll find more "significant" differences, but some may be
false positives.

**When to use TRUE:** When you have many banner columns and want to be
conservative about claiming differences are real.

------------------------------------------------------------------------

### Ranking Settings

These settings only affect Ranking question types.

#### ranking_tie_threshold_pct

**What it does:** Sets the percentage of tied rankings that triggers a
warning.

**Required:** Yes

**What to enter:** A number from 0 to 100.

**Default:** `5`

**What it means:** If more than this percentage of respondents gave tied
ranks (same rank to multiple items), Tabs warns you. Ties can indicate
data quality issues or ambiguous instructions.

#### ranking_gap_threshold_pct

**What it does:** Sets the percentage of ranking gaps that triggers a
warning.

**Required:** Yes

**What to enter:** A number from 0 to 100.

**Default:** `5`

**What it means:** A gap occurs when a respondent skips a rank position
(ranks items 1, 2, and 4, skipping 3). High gap percentages may indicate
data problems.

#### ranking_completeness_threshold_pct

**What it does:** Sets the expected completion rate for rankings.

**Required:** Yes

**What to enter:** A number from 0 to 100.

**Default:** `80`

**What it means:** If fewer than this percentage of respondents
completed all ranking positions, Tabs warns you.

#### ranking_min_base

**What it does:** Reserved for future use.

**Note:** This setting is not currently implemented and has no effect.

------------------------------------------------------------------------

### Performance Settings

#### enable_checkpointing

**What it does:** Controls whether Tabs saves progress during long
analyses.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `TRUE`

**When to use TRUE:** For large surveys with many questions. If
something goes wrong partway through, you may be able to recover partial
results.

**When to use FALSE:** For faster processing on small surveys where
recovery isn't needed.

------------------------------------------------------------------------

### Numeric Question Settings

These settings affect Numeric question type output.

#### show_numeric_median

**What it does:** Controls whether Numeric questions show median values.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `FALSE`

**Note:** Median is calculated on unweighted data only.

#### show_numeric_mode

**What it does:** Controls whether Numeric questions show mode (most
frequent value).

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `FALSE`

**Note:** Mode is calculated on unweighted data only.

#### show_numeric_outliers

**What it does:** Controls whether to report outlier counts for Numeric
questions.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `FALSE`

Outliers are detected using the IQR method.

#### exclude_outliers_from_stats

**What it does:** Controls whether outliers are removed before
calculating mean and standard deviation.

**Required:** Yes

**What to enter:** `TRUE` or `FALSE`

**Default:** `FALSE`

**When to use TRUE:** When you want robust statistics that aren't
influenced by extreme values.

#### outlier_method

**What it does:** Specifies the outlier detection method.

**Required:** No

**What to enter:** `IQR`

**Default:** `IQR`

Currently only IQR (Interquartile Range) method is supported.

#### decimal_places_numeric

**What it does:** Sets decimal places for Numeric question statistics.

**Required:** Yes

**What to enter:** A number from 0 to 5.

**Default:** `1`

------------------------------------------------------------------------

### Summary Sheet Settings

#### create_index_summary

**What it does:** Controls whether to create the Index_Summary sheet.

**Required:** Yes

**What to enter:** `Y` or `N`

**Default:** `Y`

**What the Index_Summary is:** A single sheet showing all mean/index
scores across questions. Useful for quickly comparing averages.

#### index_summary_show_sections

**What it does:** Controls whether to group metrics by section in the
summary.

**Required:** Yes

**What to enter:** `Y` or `N`

**Default:** `Y`

Sections are defined by the SectionLabel field in Composite_Metrics.

#### index_summary_show_base_sizes

**What it does:** Controls whether to show base sizes at the bottom of
Index_Summary.

**Required:** Yes

**What to enter:** `Y` or `N`

**Default:** `Y`

#### index_summary_show_composites

**What it does:** Controls whether to include composite scores in
Index_Summary.

**Required:** Yes

**What to enter:** `Y` or `N`

**Default:** `Y`

#### index_summary_decimal_places

**What it does:** Sets decimal places for the Index_Summary sheet.

**Required:** Yes

**What to enter:** A number from 0 to 3.

**Default:** `1`

------------------------------------------------------------------------

### Additional Settings

#### show_standard_deviation

**What it does:** Controls whether to show standard deviation for
rating/numeric questions.

**Required:** No

**What to enter:** `TRUE` or `FALSE`

**Default:** `FALSE`

#### test_net_differences

**What it does:** Controls whether to test significance of net
difference scores.

**Required:** No

**What to enter:** `TRUE` or `FALSE`

**Default:** `FALSE`

#### create_sample_composition

**What it does:** Controls whether to create a sample composition
summary sheet.

**Required:** No

**What to enter:** `TRUE` or `FALSE`

**Default:** `FALSE`

The sample composition sheet shows how your sample breaks down across
banner columns.

#### enable_chi_square

**What it does:** Controls whether to run chi-square tests.

**Required:** No

**What to enter:** `TRUE` or `FALSE`

**Default:** `FALSE`

#### show_net_positive

**What it does:** Controls whether to show net positive scores for
Likert questions.

**Required:** No

**What to enter:** `TRUE` or `FALSE`

**Default:** `TRUE`

Net positive = percentage positive minus percentage negative.

------------------------------------------------------------------------

## Selection Sheet

The Selection sheet tells Tabs which questions to analyze and how.

### Column: QuestionCode

**What it does:** Identifies the question.

**Required:** Yes

**What to enter:** The question code exactly as it appears in
Survey_Structure and your data file.

**Important for multi-mention:** Use the root code only (Q01, not Q01_1,
Q01_2, etc.).

**Examples:** - `Q01` - `Gender` - `satisfaction_overall`

### Column: Include

**What it does:** Controls whether this question is analyzed as a stub
(row question).

**Required:** Yes

**What to enter:** `Y` or `N`

-   `Y` = Include this question in the crosstabs output
-   `N` = Skip this question

### Column: UseBanner

**What it does:** Controls whether this question is used as a banner
(column) variable.

**Required:** No

**What to enter:** `Y` or `N`

-   `Y` = Use this question's response options as banner columns
-   `N` = Don't use as banner

**A question can be both:** Setting Include=Y and UseBanner=Y means the
question appears both as a stub (analyzed) and as a banner (used for
breakouts).

### Column: BannerBoxCategory

**What it does:** Controls whether to use BoxCategory groupings for
banner display.

**Required:** No

**What to enter:** `Y` or `N`

**What it does when Y:** Instead of showing each response option as a
separate banner column, shows the BoxCategory groups defined in
Survey_Structure Options sheet.

**Example:** An age question might have options 18-24, 25-34, 35-44,
45-54, 55+. With BoxCategory, you could group these as "Under 35",
"35-54", "55+" for a simpler banner.

### Column: BannerLabel

**What it does:** Sets the header label for this banner group.

**Required:** Only if UseBanner = Y

**What to enter:** Descriptive text.

**Examples:** - `Gender` - `Age Group` - `Region` - `Total`

This appears as the column group header in output.

### Column: DisplayOrder

**What it does:** Controls the left-to-right order of banner columns.

**Required:** Only if UseBanner = Y

**What to enter:** A number (1, 2, 3...).

Lower numbers appear further left. Typically: - 1 = Total - 2 = First
demographic (e.g., Gender) - 3 = Second demographic (e.g., Age)

### Column: CreateIndex

**What it does:** Controls whether to calculate a mean or index score
for this question.

**Required:** No

**What to enter:** `Y` or `N`

**What it does when Y:** - For Rating questions: Calculates weighted
mean - For Likert questions: Calculates index using Index_Weight
values - For NPS questions: Calculates NPS score

**When to use Y:** For any question where an average or score is
meaningful.

### Column: BaseFilter

**What it does:** Restricts the analysis to a subset of respondents.

**Required:** No

**What to enter:** An R filter expression, or leave blank for no filter.

**Examples:** - `Q1 == "Male"` (only male respondents) -
`Q16 %in% c("Store", "Online")` (only certain purchase channels) -
`Q30 >= 5 & Q30 <= 20` (purchase quantity between 5 and 20) -
`Q1 == "Female" & Q2 %in% c("18-34", "35-44")` (females aged 18-44) -
`!is.na(Q20)` (only respondents who answered Q20)

### Column: QuestionText

**What it does:** Reference information only - has no effect on
processing.

**Required:** No

**What to enter:** The question text for your reference.

This column is ignored by Tabs. It's there so you can see what each
question is without switching to the Survey_Structure file.

------------------------------------------------------------------------

## Base Filters Sheet

This sheet is for reference only - Tabs doesn't read it. It shows
example filter syntax to help you write BaseFilter expressions.

------------------------------------------------------------------------

# Chapter 2: Survey Structure Template

The Survey Structure template defines your entire survey - questions,
response options, and composite metrics. This is the master reference
used by Tabs (and potentially other Turas modules).

## Template Structure

The template has five sheets:

1.  **Instructions** - Usage guidance (not read by Tabs)
2.  **Project** - Project metadata and settings
3.  **Questions** - All survey questions
4.  **Options** - Response options for each question
5.  **Composite_Metrics** - Calculated composite scores

------------------------------------------------------------------------

## Project Sheet

The Project sheet stores metadata about your project. This information
appears in output and helps document your analysis.

### Setting: project_name

**What it does:** Names your project for display purposes.

**Required:** Yes

**What to enter:** A descriptive name.

**Example:** `Brand Tracker Q1 2024`

### Setting: project_code

**What it does:** Provides a unique identifier for the project.

**Required:** Yes

**What to enter:** A short code, typically matching your project folder
name.

**Example:** `BrandTracker_Q1`

### Setting: client_name

**What it does:** Records the client organization.

**Required:** Yes

**What to enter:** The client's name.

**Example:** `Acme Corporation`

### Setting: study_type

**What it does:** Describes the type of study.

**Required:** Yes

**What to enter:** One of: `Ad-hoc`, `Tracker`, `Panel`, `Longitudinal`

**Example:** `Tracker`

### Setting: study_date

**What it does:** Records the study date.

**Required:** Yes

**What to enter:** Date in YYYYMMDD format.

**Example:** `20251018`

### Setting: data_file

**What it does:** Specifies the path to your survey data file.

**Required:** Yes

**What to enter:** Relative path from your project folder.

**Example:** `Data/survey_data.xlsx`

### Setting: output_folder

**What it does:** Specifies where outputs are saved.

**Required:** Yes

**What to enter:** Folder path relative to project.

**Default:** `Output`

### Setting: total_sample

**What it does:** Records the expected total respondent count.

**Required:** Yes

**What to enter:** An integer.

**Example:** `1000`

### Setting: contact_person

**What it does:** Records the project lead.

**Required:** No

**What to enter:** A name.

**Example:** `John Smith`

### Setting: notes

**What it does:** Stores project notes or description.

**Required:** No

**What to enter:** Any text.

**Example:** `Q1 2024 brand tracking wave`

### Setting: weight_column_exists

**What it does:** Indicates whether your data has weight columns.

**Required:** No

**What to enter:** `Y` or `N`

**Default:** `N`

### Setting: weight_columns

**What it does:** Lists available weight column names.

**Required:** Only if weight_column_exists = Y

**What to enter:** Comma-separated column names.

**Example:** `Weight_Demo,Weight_Final`

### Setting: default_weight

**What it does:** Specifies which weight to use by default.

**Required:** Only if weight_column_exists = Y

**What to enter:** One of the weight column names.

**Example:** `Weight_Final`

### Setting: weight_description

**What it does:** Documents your weighting methodology.

**Required:** No

**What to enter:** Descriptive text.

**Example:** `Weighted to census demographics`

------------------------------------------------------------------------

## Questions Sheet

The Questions sheet lists every question in your survey.

### Column: QuestionCode

**What it does:** Uniquely identifies each question. This must match the
column name in your data file.

**Required:** Yes

**What to enter:** The column name from your data file.

**Rules:** - Must be unique across all questions - Must match the data
column exactly (case-sensitive) - For multi-mention questions: use the
root code only (Q01, not Q01_1) - Avoid special characters and spaces

**Examples:** - `Q01` - `satisfaction_overall` - `NPS_score`

**Common mistakes:** - Including \_1 suffix for multi-mention (use root
code) - Spaces in the code - Case mismatch with data file

### Column: QuestionText

**What it does:** Stores the question wording as it should appear in
output.

**Required:** Yes

**What to enter:** The question text.

**Example:** `How satisfied are you with our service?`

### Column: Variable_Type

**What it does:** Tells Tabs how to process this question.

**Required:** Yes

**What to enter:** One of the valid type names.

**Valid types and when to use them:**

**Single_Mention** - For pick-one questions where respondents choose
exactly one option. - Example: Gender, Yes/No questions, "Which brand do
you prefer?" - Data format: One column with the selected value

**Multi_Mention** - For check-all-that-apply questions where respondents
can select multiple options. - Example: "Which brands are you aware
of?", "Which features do you use?" - Data format: Multiple columns
(Q01_1, Q01_2, Q01_3, etc.)

**Likert** - For agreement scales where you want to calculate an index
score using custom weights. - Example: Strongly Disagree to Strongly
Agree - Data format: One column with the response value - Requires:
Index_Weight in Options sheet

**Rating** - For numeric rating scales where you want to calculate a
mean. - Example: Rate from 1-10, Satisfaction 1-5 - Data format: One
column with the numeric value

**NPS** - For Net Promoter Score questions (0-10 scale). - Example: "How
likely are you to recommend us?" - Data format: One column with values
0-10 - Automatically calculates Promoters, Passives, Detractors, and NPS
score

**Ranking** - For questions where respondents rank items in order. -
Example: "Rank your top 3 preferred brands" - Data format: Depends on
Ranking_Format setting

**Open_End** - For text responses. These are not analyzed numerically. -
Example: "Please explain your answer" - Usually excluded from Tabs
analysis

**Numeric** - For open-ended numeric responses where you want
statistics. - Example: Age (exact number), income, quantity purchased -
Data format: One column with numeric values

### Column: Columns

**What it does:** Specifies how many data columns this question uses.

**Required:** Yes

**What to enter:** An integer, 1 or greater.

**When to use 1:** Single_Mention, Rating, NPS, Numeric, Likert - these
all use one column.

**When to use more than 1:** Multi_Mention and Ranking questions that
span multiple columns.

**Example:** If you have Q01_1, Q01_2, Q01_3, Q01_4, Q01_5 for a
multi-mention question, enter `5`.

### Column: Ranking_Format

**What it does:** Specifies how ranking data is structured.

**Required:** Only if Variable_Type = Ranking

**What to enter:** `Position` or `Item`

**Position format:** Each item has its own column containing the rank
position. - Example: Columns Brand_A_Rank, Brand_B_Rank, Brand_C_Rank -
Values might be 2, 1, 3 (meaning Brand B was first, Brand A second,
Brand C third)

**Item format:** Each rank position has its own column containing the
item name. - Example: Columns Rank_1, Rank_2, Rank_3 - Values might be
"Brand B", "Brand A", "Brand C"

### Column: Ranking_Positions

**What it does:** Specifies how many rank positions respondents
assigned.

**Required:** Only if Variable_Type = Ranking

**What to enter:** An integer.

**Example:** `3` for a "rank your top 3" question.

### Column: Ranking_Direction

**What it does:** Indicates whether rank 1 is best or worst.

**Required:** Only if Variable_Type = Ranking

**What to enter:** `BestToWorst` or `WorstToBest`

**BestToWorst:** Rank 1 is the top preference (most common).

**WorstToBest:** Rank 1 is the least preferred.

### Column: Category

**What it does:** Groups questions for organizational purposes.

**Required:** No

**What to enter:** A category label.

**Examples:** `Satisfaction`, `Demographics`, `Usage`, `Awareness`

This helps organize questions in output or reports.

### Column: Notes

**What it does:** Stores internal notes about the question.

**Required:** No

**What to enter:** Any text.

**Example:** `New question added in 2024`

### Column: Min_Value

**What it does:** Specifies the minimum expected value for Numeric
questions.

**Required:** Only if Variable_Type = Numeric and you want validation or
binning

**What to enter:** A number.

**Example:** `18` for minimum age

### Column: Max_Value

**What it does:** Specifies the maximum expected value for Numeric
questions.

**Required:** Only if Variable_Type = Numeric and you want validation or
binning

**What to enter:** A number.

**Example:** `100` for maximum age

------------------------------------------------------------------------

## Options Sheet

The Options sheet lists all response options for each question.

### Column: QuestionCode

**What it does:** Links this option to a question.

**Required:** Yes

**What to enter:** The QuestionCode from the Questions sheet.

**For single-column questions:** Use the exact QuestionCode (Q01).

**For multi-mention questions:** Use the first column's code (Q01_1).

**Important:** Every question that appears in output needs options
defined here, except Numeric and Open_End types.

### Column: OptionText

**What it does:** Specifies the value as it appears in your data file.

**Required:** Yes

**What to enter:** The exact value from your data - must match
precisely.

**Examples:** - If your data has `1` for Male, enter `1` - If your data
has `Male`, enter `Male` - If your data has `very_satisfied`, enter
`very_satisfied`

**Critical:** This is case-sensitive and must be an exact match. If your
data has "1" and you enter "Male", the option won't be recognized.

### Column: DisplayText

**What it does:** Specifies how this option should be labelled in
output.

**Required:** Yes

**What to enter:** The label you want users to see.

**Examples:** - OptionText `1` → DisplayText `Male` - OptionText `5` →
DisplayText `Very satisfied (5)` - OptionText `very_satisfied` →
DisplayText `Very Satisfied`

This is where you make cryptic data codes human-readable.

### Column: DisplayOrder

**What it does:** Controls the order options appear in output.

**Required:** No

**What to enter:** An integer (1, 2, 3...).

Lower numbers appear first. If not specified, options appear in the
order they're listed.

### Column: ShowInOutput

**What it does:** Controls whether this option appears in the output.

**Required:** Yes

**What to enter:** `Y` or leave blank.

-   `Y` = Include in output
-   Blank = Exclude from output

**When to exclude:** You might have internal codes or "Don't know"
responses you don't want to display.

### Column: ExcludeFromIndex

**What it does:** Controls whether this option is excluded from
mean/index calculations.

**Required:** No

**What to enter:** `Y` or leave blank.

**When to use Y:** For "Don't know", "Not applicable", or other
responses that shouldn't be included in average calculations.

**Example:** On a 1-5 satisfaction scale, you might have a code 9 for
"Don't know". Set ExcludeFromIndex = Y so it doesn't affect the mean.

### Column: Index_Weight

**What it does:** Specifies the numeric weight for index calculations.

**Required:** Only if CreateIndex = Y for this question in Selection
sheet

**What to enter:** A number (can be negative or positive, typically -100
to 100).

**For Rating questions:** Usually the scale value (1, 2, 3, 4, 5).

**For Likert questions:** Custom weights for calculating an index.
Example: - Strongly Disagree = -100 - Disagree = -50 - Neutral = 0 -
Agree = 50 - Strongly Agree = 100

### Column: BoxCategory

**What it does:** Groups options into summary categories.

**Required:** No

**What to enter:** A category label.

**How it works:** Options with the same BoxCategory are combined when
displaying summaries.

**Example 1 - Summary statistics:** For a 5-point satisfaction scale: -
Options 1, 2 → BoxCategory = "Dissatisfied" - Option 3 → BoxCategory =
"Neutral" - Options 4, 5 → BoxCategory = "Satisfied"

Output can then show "Satisfied" as a single percentage.

**Example 2 - Banner simplification:** For age bands: - 18-24, 25-34 →
BoxCategory = "Under 35" - 35-44, 45-54 → BoxCategory = "35-54" - 55+ →
BoxCategory = "55+"

When BannerBoxCategory = Y, the banner shows these three groups instead
of five.

### Column: Min

**What it does:** Specifies the minimum value for Numeric binning.

**Required:** Only for Numeric questions when creating bins

**What to enter:** A number.

**How it works with Max:** Together, Min and Max define a bin range for
Numeric questions.

**Example:** For age bins:

| QuestionCode | OptionText | DisplayText | Min | Max |
|--------------|------------|-------------|-----|-----|
| Age          | 18-24      | 18-24       | 18  | 24  |
| Age          | 25-34      | 25-34       | 25  | 34  |
| Age          | 35-44      | 35-44       | 35  | 44  |
| Age          | 45+        | 45+         | 45  | 100 |

Respondents with age values falling within each range get binned
accordingly.

**Important:** Make sure bins don't overlap. Each value should fall into
exactly one bin.

### Column: Max

**What it does:** Specifies the maximum value for Numeric binning.

**Required:** Only for Numeric questions when creating bins

**What to enter:** A number.

See Min column for examples.

------------------------------------------------------------------------

## Composite_Metrics Sheet

The Composite_Metrics sheet defines calculated scores that combine
multiple questions.

### Column: CompositeCode

**What it does:** Uniquely identifies the composite metric.

**Required:** Yes

**What to enter:** A unique code, conventionally starting with `COMP_`.

**Examples:** - `COMP_SAT_OVERALL` - `COMP_BRAND_HEALTH` -
`COMP_ENGAGEMENT`

### Column: CompositeLabel

**What it does:** Provides the display name for reports.

**Required:** Yes

**What to enter:** A descriptive label.

**Examples:** - `Overall Satisfaction Index` - `Brand Health Score` -
`Employee Engagement`

### Column: CalculationType

**What it does:** Specifies how source questions are combined.

**Required:** Yes

**What to enter:** `Mean`, `Sum`, or `WeightedMean`

**Mean:** Simple average of source question values. - If Q1=4, Q2=5,
Q3=3, composite = (4+5+3)/3 = 4.0

**Sum:** Total of source question values. - Same example: composite =
4+5+3 = 12

**WeightedMean:** Weighted average using the Weights column. - If
weights are 1, 2, 1 for three questions with values 4, 5, 3: - composite
= (4×1 + 5×2 + 3×1) / (1+2+1) = 17/4 = 4.25

### Column: SourceQuestions

**What it does:** Lists which questions feed into this composite.

**Required:** Yes

**What to enter:** Comma-separated question codes.

**Examples:** - `Q01,Q02,Q03` - `SAT_PRODUCT,SAT_SERVICE,SAT_VALUE`

**Requirements:** - All listed questions must exist in the Questions
sheet - All questions should be the same type (all Rating, all Likert,
or all Numeric) - Values must be combinable in a meaningful way

### Column: Weights

**What it does:** Specifies the weight for each source question in
WeightedMean calculations.

**Required:** Only if CalculationType = WeightedMean

**What to enter:** Comma-separated numbers matching the count of
SourceQuestions.

**Example:** If SourceQuestions = `Q01,Q02,Q03` and you want Q02 to
count twice as much: - Weights = `1,2,1`

### Column: ExcludeFromSummary

**What it does:** Controls whether this composite appears in the
Index_Summary sheet.

**Required:** No

**What to enter:** `Y` or leave blank.

**When to use Y:** For internal composites you don't want clients to
see.

### Column: SectionLabel

**What it does:** Groups related composites in the Index_Summary sheet.

**Required:** No

**What to enter:** A section name.

**Example:** `Satisfaction Metrics`, `Brand Health`

Composites with the same SectionLabel are grouped together in the
summary.

### Column: Notes

**What it does:** Stores internal documentation.

**Required:** No

**What to enter:** Any text.

**Example:** `Updated weighting methodology in 2024`

------------------------------------------------------------------------

## Validation

When Tabs processes your templates, it validates:

**Questions Sheet:** - QuestionCode is unique across all questions -
Variable_Type is one of the valid values - All required columns are
present - Multi-mention questions have matching column counts

**Options Sheet:** - Every QuestionCode exists in the Questions sheet -
OptionText is not empty - For Rating/Likert with CreateIndex:
Index_Weight is present

**Composite_Metrics Sheet:** - All SourceQuestions exist in Questions
sheet - Weights count matches SourceQuestions count (if WeightedMean) -
All source questions are compatible types

Validation errors are collected and reported together, so you can fix
all issues in one pass.

------------------------------------------------------------------------

## Common Mistakes and Solutions

### QuestionCode doesn't match data

**Symptom:** "Question Q01 not found in data"

**Fix:** Check that QuestionCode exactly matches your data column name.
This is case-sensitive - Q01 is different from q01.

### Multi-mention with \_1 suffix

**Symptom:** Multi-mention question not analyzed correctly

**Fix:** In the Questions sheet, use the root code (Q01) without the \_1
suffix. The Columns field tells Tabs how many columns to look for.

### OptionText doesn't match data

**Symptom:** Percentages show 0% or options don't appear

**Fix:** OptionText must exactly match values in your data. If your data
has "1" for Male, use "1" as OptionText, not "Male".

### Missing Index_Weight for Rating

**Symptom:** Mean calculation shows NA or incorrect values

**Fix:** For Rating questions where CreateIndex = Y, each option needs
an Index_Weight value matching the numeric scale (1, 2, 3, 4, 5).

### Composite SourceQuestions don't exist

**Symptom:** Composite calculation fails

**Fix:** All questions listed in SourceQuestions must exist in the
Questions sheet with exactly matching codes.

### Overlapping numeric bins

**Symptom:** Some values counted twice or placed in wrong bin

**Fix:** Ensure your Min and Max values create non-overlapping ranges.
If one bin ends at 34, the next should start at 35.
