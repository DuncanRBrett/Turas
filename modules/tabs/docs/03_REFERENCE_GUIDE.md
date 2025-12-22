# Turas Tabs - Reference Guide

**Version:** 10.0
**Date:** 22 December 2025

This guide provides a complete reference for all Tabs features and concepts. For step-by-step instructions, see the [User Manual](04_USER_MANUAL.md). For template field details, see the [Template Reference](06_TEMPLATE_REFERENCE.md).

---

## Core Concepts

### Survey Structure

The Survey Structure file is the master definition of your survey. It tells Tabs what questions exist, what type each question is, what response options are available, and how they should be labelled in output.

This file is used across multiple Turas modules, so you define your survey once and use it everywhere.

The Survey Structure contains:
- **Questions sheet:** Lists every question with its code, text, and type
- **Options sheet:** Lists the response options for each question
- **Composite_Metrics sheet:** Defines calculated scores that combine multiple questions

### Crosstab Configuration

The Crosstab Config file tells Tabs how to run your specific analysis. It specifies:
- Where to find your data and structure files
- Which questions to analyze (the "stubs")
- Which questions to use as banner columns (demographic breakouts)
- Display and formatting preferences
- Statistical testing settings

### Banner and Stub

In crosstab terminology:
- **Stubs** are the questions being analyzed (the rows of your table)
- **Banner** columns are the demographic breakouts (the columns of your table)

For example, if you're analyzing satisfaction ratings broken out by gender and age, the satisfaction question is the stub, and gender/age are the banner.

### Weighting

Survey weighting adjusts for sampling biases. If your sample over-represents young urban respondents, weights correct for this so your results reflect the target population.

Tabs applies weights to all calculations and uses effective sample sizes for significance testing. The effective sample size accounts for the variance in weights, giving you accurate p-values.

---

## Question Types

Tabs supports seven question types. Each type is processed differently and produces different output.

### Single_Mention (Single Response)

For questions where respondents choose exactly one option.

**Examples:** Gender, Age Group, Yes/No questions, Brand preference

**Output includes:**
- Frequency count for each option
- Column percentage for each option
- Significance testing between banner columns

**Data format:** One column containing the response value (numeric code or text)

### Multi_Mention (Multiple Response)

For questions where respondents can select multiple options.

**Examples:** Brand awareness (select all you know), Features used (select all that apply)

**Output includes:**
- Frequency count for each option (how many selected it)
- Column percentage for each option (based on respondents, not mentions)
- Significance testing between banner columns

**Data format:** Multiple columns named with a common root and numeric suffix (Q05_1, Q05_2, Q05_3, etc.). Each column contains the response value if selected, or blank/NA if not.

**Important:** Percentages for multi-mention questions can sum to more than 100% because respondents can select multiple options.

### Rating

For numeric scales where respondents rate something on a scale.

**Examples:** Satisfaction (1-5), Agreement (1-7), Quality rating (1-10)

**Output includes:**
- Frequency and percentage for each scale point
- Mean (average) rating
- Optional: Top-2-Box and Bottom-2-Box percentages
- Significance testing on both percentages and means

**Data format:** One column containing the numeric rating value

### Likert

For agreement scales that produce an index score.

**Examples:** Strongly Disagree to Strongly Agree, Never to Always

Similar to Rating questions, but Likert questions can use custom index weights defined in the Options sheet to calculate a weighted index score.

**Output includes:**
- Frequency and percentage for each option
- Index score (calculated from Index_Weight values)
- Optional: Net positive score (positive minus negative)
- Significance testing

### NPS (Net Promoter Score)

For the standard Net Promoter Score question (0-10 scale).

**Examples:** "How likely are you to recommend us to a friend or colleague?"

**Output includes:**
- Percentage of Detractors (0-6)
- Percentage of Passives (7-8)
- Percentage of Promoters (9-10)
- NPS Score (% Promoters minus % Detractors)
- Significance testing on NPS score

**Data format:** One column containing values 0-10

### Ranking

For questions where respondents rank items in order of preference.

**Examples:** "Rank your top 3 preferred brands"

**Output includes:**
- Percentage receiving each rank position
- Mean rank for each item
- First-choice percentage
- Significance testing

**Data format:** There are two formats:
- **Position format:** Each item has a column containing its rank (Brand_A_Rank = 2 means Brand A was ranked second)
- **Item format:** Each rank position has a column containing the item name (Rank_1 = "Brand A" means Brand A was ranked first)

### Numeric

For open-ended numeric responses.

**Examples:** Age (exact), Income, Number of purchases

**Output includes:**
- Mean value
- Optional: Median, Mode, Standard Deviation
- Optional: Binned frequency distribution (if bins defined in Options)
- Significance testing on means

**Data format:** One column containing numeric values

### Composite

For calculated metrics that combine multiple questions.

**Examples:** Overall Satisfaction Index (average of Q1, Q2, Q3), Brand Health Score

Composites are defined in the Composite_Metrics sheet of Survey_Structure. They don't exist in your data file; they're calculated from source questions.

**Output includes:**
- Composite score
- Significance testing

---

## Statistical Methods

### Significance Testing

Tabs tests whether differences between banner columns are statistically significant. A difference is "significant" when it's unlikely to have occurred by chance.

The output shows significance using letter codes. Each banner column gets a letter (A, B, C, etc.). If a cell contains "B", it means that value is significantly higher than column B at the specified confidence level.

**Example:**
```
              Total(A)  Male(B)  Female(C)
Very Happy    35%       40%C     31%
```
The "C" after 40% means Males (40%) are significantly higher than Females (31%).

### Test Types

**Chi-Square Test:** Used for categorical data (Single_Mention, Multi_Mention). Tests whether the overall distribution of responses differs between groups.

**Z-Test:** Used for comparing two proportions. Tests whether the percentage in one column is significantly different from another column.

**T-Test:** Used for comparing means (Rating, Numeric, NPS). Tests whether the average score in one column is significantly different from another.

Tabs automatically selects the appropriate test based on question type, or you can specify a preference in the configuration.

### Confidence Level

The confidence level (typically 95%) determines how certain you need to be before declaring a difference significant.

- 95% confidence (alpha = 0.05) means there's a 5% chance of finding a "significant" difference when none exists
- 90% confidence (alpha = 0.10) is more lenient, finding more significant differences
- 99% confidence (alpha = 0.01) is more stringent, finding fewer significant differences

### Minimum Base Size

Significance testing becomes unreliable with small sample sizes. Tabs won't test cells where the base falls below the minimum threshold (default: 30).

If a banner column has fewer than 30 respondents, significance markers won't appear for comparisons involving that column.

### Bonferroni Correction

When comparing many columns simultaneously, the chance of finding at least one false positive increases. Bonferroni correction adjusts the significance threshold to account for multiple comparisons.

If enabled, Tabs divides the alpha level by the number of comparisons being made. This is more conservative but reduces false positives.

---

## Weighting Concepts

### Why Weighting Matters

Survey samples rarely match the target population perfectly. Weighting adjusts for these differences so your results represent the population, not just your sample.

For example, if your sample is 60% female but the population is 50% female, weight values correct for this imbalance.

### Weight Variable

The weight column in your data contains a numeric value for each respondent indicating how much their responses should count. Values greater than 1 mean the respondent is under-represented in the sample (count them more). Values less than 1 mean they're over-represented (count them less).

Good weight distributions have:
- Mean weight close to 1.0
- Low variance (most weights between 0.5 and 2.0)
- No extreme values (nothing above 5.0 or below 0.2)

### Design Effect (DEFF)

Weighting reduces the effective statistical power of your sample. DEFF measures this efficiency loss.

DEFF = 1 means no efficiency loss (all weights equal).
DEFF = 1.5 means your sample is worth about 67% of its nominal size.
DEFF = 2.0 means your sample is worth about 50% of its nominal size.
DEFF > 3.0 usually indicates problems with your weighting scheme.

### Effective Sample Size

The effective sample size is the weighted sample size divided by DEFF. This is the sample size Tabs uses for significance testing.

For example, if you have 1,000 weighted respondents and DEFF = 1.3, your effective n is about 770. Significance testing uses 770, not 1,000, giving you correct p-values.

### Base Size Reporting

Tabs reports three types of base sizes:

- **Unweighted n:** The actual count of respondents (useful for knowing your true sample size)
- **Weighted n:** The sum of weights (represents the population estimate)
- **Effective n:** The weighted n adjusted for DEFF (used for significance testing)

---

## Output Structure

### Excel Workbook

The output is an Excel workbook with multiple sheets:

**Index_Summary sheet (optional):** A summary of all index/mean scores across questions. Useful for quickly comparing averages across banner columns.

**Question sheets:** One sheet per question analyzed. Each sheet contains the full crosstab for that question.

**Metadata sheet:** Contains analysis settings, timestamps, and file paths for documentation purposes.

**Sample_Composition sheet (optional):** Shows the demographic breakdown of your sample across banner columns.

### Table Layout

Each question sheet follows this structure:

**Header rows:**
- Question code and text
- Base sizes (unweighted, weighted, effective)

**Data rows:**
- One row per response option (or multiple rows if showing both frequency and percentage)
- Values for each banner column

**Summary rows (for Rating/Likert/NPS):**
- Mean or Index score
- Top-2-Box / Bottom-2-Box percentages
- Net scores

**Significance:**
- Letter codes appear inline with values (e.g., "45%B")
- Or in a separate row below each option

---

## BoxCategory Grouping

BoxCategory lets you group response options for summary statistics or simplified banners.

### For Summary Statistics

Group scale points into meaningful categories:

**Example for a 5-point satisfaction scale:**
- Options 4 and 5 get BoxCategory = "Satisfied"
- Options 1 and 2 get BoxCategory = "Dissatisfied"
- Option 3 gets BoxCategory = "Neutral"

The output then shows the percentage for each grouped category in addition to individual scale points.

### For Banner Simplification

Group demographic options for simpler banner columns:

**Example for Age:**
- Options 18-24 and 25-34 get BoxCategory = "Under 35"
- Options 35-44 and 45-54 get BoxCategory = "35-54"
- Options 55+ get BoxCategory = "55+"

When you enable BannerBoxCategory for a question, the banner shows these grouped categories instead of individual age bands.

---

## Composite Metrics

Composite metrics are calculated scores that combine multiple questions into a single index.

### Use Cases

**Overall Satisfaction Index:** Average of product satisfaction, service satisfaction, and value satisfaction questions.

**Brand Health Score:** Weighted combination of awareness, consideration, preference, and usage.

**Employee Engagement Index:** Sum or average of multiple engagement questions.

### Calculation Types

**Mean:** Simple average of source question values. If Q1=4, Q2=5, Q3=3, the mean composite = 4.

**Sum:** Total of source question values. Same example: sum = 12.

**WeightedMean:** Weighted average using custom weights. If weights are 1, 2, 1 for the three questions, the calculation is (4×1 + 5×2 + 3×1) / (1+2+1) = 17/4 = 4.25.

### Requirements

All source questions for a composite must:
- Exist in the Questions sheet
- Be the same type (all Rating, all Likert, or all Numeric)
- Have values that can be meaningfully combined

---

## Base Filters

Base filters let you analyze subsets of your data. Each stub question can have its own filter, so you can ask "Among purchasers, what is satisfaction?" while analyzing the full sample for other questions.

### Filter Syntax

Filters use R syntax:

**Single value:** `Q1 == "Male"` (Q1 equals "Male")

**Multiple values:** `Q16 %in% c("Store", "Online")` (Q16 is Store or Online)

**Numeric range:** `Age >= 18 & Age <= 34` (Age between 18 and 34)

**Combined:** `Q1 == "Female" & Q2 %in% c("18-34", "35-44")` (Female aged 18-44)

**Not null:** `!is.na(Q20)` (Q20 is not missing)

### Effect on Output

When a base filter is applied:
- The base size reflects only respondents matching the filter
- Percentages are calculated among filtered respondents
- Significance testing uses the filtered base sizes
- The filter expression is documented in the output

---

## Performance Considerations

### Dataset Size

Tabs performs well with typical survey datasets:

| Size | Processing Time |
|------|-----------------|
| Under 5,000 rows | Under 30 seconds |
| 5,000-20,000 rows | 30 seconds to 2 minutes |
| 20,000-50,000 rows | 2-5 minutes |
| Over 50,000 rows | Consider batch processing |

### Optimization Tips

**Use CSV instead of Excel for large data files.** CSV reads 5-10x faster than Excel for large datasets.

**Reduce banner columns.** Processing time scales with the number of banner columns. If you don't need a demographic breakout, don't include it.

**Disable unused features.** If you don't need frequencies (just percentages), disable them. If you don't need significance testing, disable it.

**Process in batches.** For very large analyses (200+ questions), split into multiple runs and combine outputs afterward.

---

## Error Handling

### Validation

Tabs validates your configuration before processing:

- Checks that referenced files exist
- Verifies question codes match between structure, config, and data
- Validates that banner questions exist in the data
- Checks weight values for issues (NAs, zeros, extreme values)

Validation errors are collected and reported together, so you can fix all issues before re-running.

### Warning Thresholds

Some issues don't stop processing but generate warnings:

- Weight column has more than 10% NA values
- Weight column has more than 5% zero values
- DEFF exceeds 3.0 (indicating inefficient weighting)
- Ranking data has ties or gaps exceeding threshold percentages

### Error Logging

All errors, warnings, and info messages are logged with:
- Source (which component detected the issue)
- Category (what type of issue)
- Message (what went wrong)
- Details (additional context)
- Severity (Error, Warning, Info)

Check the validation output after running to ensure no issues were detected.

---

## Version Compatibility

### Current Version: 10.0

This version uses the current template and configuration formats.

### Migration from Earlier Versions

If you have configuration files from versions before 9.0, they may need updates:

- Question type names may differ (e.g., "Single_Response" vs "SingleChoice")
- Configuration setting names may have changed
- The Survey_Structure format is stable across versions

Check the template files in this documentation for the current expected format.

---

## Related Modules

**Tracker Module:** For multi-wave tracking studies where you compare results across time periods. Use Tracker when you need to show trends and test significance of changes between waves.

**Confidence Module:** For calculating confidence intervals. If you need margin of error rather than significance testing, this module focuses specifically on that.

**Parser Module:** For converting questionnaire documents into Survey_Structure format. If you're starting from a Word document or PDF questionnaire, Parser can help extract the structure.
