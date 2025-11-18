# Turas Tabs - Comprehensive User Manual

**Version:** 1.0.0
**Last Updated:** 2025-11-17
**Module:** Cross-Tabulation Analysis with Statistical Testing
**Difficulty Level:** Intermediate

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Getting Started](#2-getting-started)
3. [Configuration Guide](#3-configuration-guide)
4. [Statistical Methods](#4-statistical-methods)
5. [Advanced Features](#5-advanced-features)
6. [Output Interpretation](#6-output-interpretation)
7. [Troubleshooting](#7-troubleshooting)
8. [Best Practices](#8-best-practices)
9. [Frequently Asked Questions](#9-frequently-asked-questions)

---

## 1. Introduction

### 1.1 What is Turas Tabs?

Turas Tabs is a comprehensive cross-tabulation engine that transforms survey data into professional Excel reports with:

- **Weighted statistics** with automatic DEFF calculations
- **Statistical significance testing** (chi-square, t-tests, z-tests)
- **Multiple output formats** (percentages, counts, means, indices)
- **Banner analysis** across demographic segments
- **Composite scores** from multiple questions
- **Professional Excel formatting** with color-coded significance

### 1.2 Key Features

**Statistical Rigor:**
- Design-adjusted effective sample sizes (DEFF)
- Multiple significance testing methods
- Confidence interval calculations
- Net difference testing

**Flexibility:**
- Support for all question types (single, multi, rating, NPS, numeric, ranking)
- Custom composite scores
- Top/bottom box calculations
- Weighted and unweighted analysis

**Professional Output:**
- Excel workbooks with multiple sheets
- Summary statistics
- Sample composition tables
- Color-coded significance markers
- Customizable formatting

### 1.3 When to Use Tabs

**Use Turas Tabs when you need to:**
- Compare responses across demographic groups
- Test if differences are statistically significant
- Create professional client reports
- Analyze weighted survey data
- Calculate Top 2 Box / Bottom 2 Box metrics
- Profile customer segments

**Don't use Turas Tabs for:**
- Multi-wave tracking (use Tracker module)
- Clustering/segmentation (use Segment module)
- Confidence interval calculations only (use Confidence module)

---

## 2. Getting Started

### 2.1 Prerequisites

**Required:**
```r
install.packages(c("openxlsx", "readxl"))
```

**Optional:**
```r
install.packages(c("data.table", "haven"))  # For faster processing and SPSS files
```

### 2.2 Data Requirements

**Survey Data File:**
- One row per respondent
- One column per question
- Numeric coding (1, 2, 3, not "Yes", "No")
- Optional weight column

**Example:**
```
ResponseID | Weight | Q1_Age | Q2_Gender | Q3_Satisfaction | Q4_Purchase
1          | 1.2    | 2      | 1         | 4               | 1
2          | 0.8    | 3      | 2         | 5               | 1
3          | 1.0    | 1      | 1         | 3               | 0
```

### 2.3 Your First Cross-Tab (5 Minutes)

**Step 1: Prepare configuration file**

Create `config.xlsx` with 3 sheets:

**Questions Sheet:**
```
QuestionCode | QuestionText           | QuestionType
Q3           | Overall satisfaction   | Rating
Q4           | Purchase intent        | Single_Response
```

**Banner Sheet:**
```
BannerLabel | BreakVariable | BreakValue | DisplayOrder
Total       | Total         |            | 1
Male        | Q2_Gender     | 1          | 2
Female      | Q2_Gender     | 2          | 3
```

**Settings Sheet:**
```
SettingName  | SettingValue
data_file    | survey_data.xlsx
output_file  | crosstabs.xlsx
weight_var   | Weight
```

**Step 2: Run analysis**

```r
source("modules/tabs/run_tabs_gui.R")
# Upload config.xlsx
# Click "Run Analysis"
```

**Step 3: Review output**

Your `crosstabs.xlsx` will contain:
- Summary sheet with project info
- One sheet per question with cross-tabs
- Statistical significance markers

---

## 3. Configuration Guide

### 3.1 Questions Sheet

**Required Columns:**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| QuestionCode | Text | Column name in data | Q1_Satisfaction |
| QuestionText | Text | Label for output | Overall satisfaction (1-5) |
| QuestionType | Text | Type of question | Rating, Single_Response, Multi_Mention, etc. |

**Optional Columns:**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| ValueLabels | Text | Labels for numeric codes | 1=Very dissatisfied; 2=Dissatisfied; 3=Neutral; 4=Satisfied; 5=Very satisfied |
| ExcludeFromAnalysis | TRUE/FALSE | Skip this question | FALSE |
| DecimalPlaces | Number | Override default decimals | 1 |

**Question Types:**

| Type | Description | When to Use |
|------|-------------|-------------|
| **Single_Response** | One answer chosen | Gender, age group, yes/no |
| **Multi_Mention** | Multiple answers allowed | Brand awareness, features owned |
| **Rating** | Numeric scale (1-5, 1-7, 1-10) | Satisfaction, agreement scales |
| **NPS** | Net Promoter Score (0-10) | Likelihood to recommend |
| **Numeric** | Continuous number | Age, income, quantity |
| **Open_Ended** | Text response | Comments, verbatim (excluded from tabs) |
| **Ranking** | Rank order (1st, 2nd, 3rd) | Preference ranking |

**Example Questions Sheet:**
```
QuestionCode     | QuestionText                  | QuestionType     | ValueLabels
Q1_Age           | Age group                     | Single_Response  | 1=18-24; 2=25-34; 3=35-44; 4=45-54; 5=55+
Q2_Gender        | Gender                        | Single_Response  | 1=Male; 2=Female; 3=Other
Q3_Satisfaction  | Overall satisfaction          | Rating           | 1=Very dissatisfied; 2=Dissatisfied; 3=Neutral; 4=Satisfied; 5=Very satisfied
Q4_Purchase      | Purchased in last 3 months    | Single_Response  | 1=Yes; 0=No
Q5_Brands        | Brands owned                  | Multi_Mention    | 1=Brand A; 2=Brand B; 3=Brand C; 4=Brand D
Q6_NPS           | Likelihood to recommend       | NPS              | 0-10 scale
Q7_Preference    | Brand preference ranking      | Ranking          | 1=First choice; 2=Second choice; 3=Third choice
```

### 3.2 Banner Sheet

The Banner defines the columns in your cross-tabs (demographic breakouts).

**Required Columns:**

| Column | Description | Example |
|--------|-------------|---------|
| BannerLabel | Display name | Male, Female, 18-34, 35+ |
| BreakVariable | Question code to filter on | Q2_Gender, Q1_Age |
| BreakValue | Value(s) to include | 1 (or 1,2 for multiple) |
| DisplayOrder | Column order (numeric) | 1, 2, 3, 4... |

**Special Banner Values:**

**Total:**
```
BannerLabel | BreakVariable | BreakValue | DisplayOrder
Total       | Total         |            | 1
```
Always include a "Total" row (all respondents).

**Multiple Values:**
Use commas to combine values:
```
BannerLabel | BreakVariable | BreakValue | DisplayOrder
18-34       | Q1_Age        | 1,2        | 4
35+         | Q1_Age        | 3,4,5      | 5
```

**Example Banner Sheet:**
```
BannerLabel | BreakVariable | BreakValue | DisplayOrder
Total       | Total         |            | 1
Male        | Q2_Gender     | 1          | 2
Female      | Q2_Gender     | 2          | 3
18-34       | Q1_Age        | 1,2        | 4
35-54       | Q1_Age        | 3,4        | 5
55+         | Q1_Age        | 5          | 6
North       | Q8_Region     | 1          | 7
South       | Q8_Region     | 2          | 8
East        | Q8_Region     | 3          | 9
West        | Q8_Region     | 4          | 10
```

This creates a 10-column cross-tab (Total + 9 segments).

### 3.3 Settings Sheet

**Format:**
```
SettingName | SettingValue
```

**Essential Settings:**

| Setting | Required | Description | Default | Example |
|---------|----------|-------------|---------|---------|
| data_file | YES | Path to survey data | - | data/survey.xlsx |
| output_file | YES | Output path | - | output/crosstabs.xlsx |
| weight_var | NO | Weight column name | (unweighted) | Weight |

**Display Options:**

| Setting | Description | Default | Options |
|---------|-------------|---------|---------|
| show_percentages | Show % in output | TRUE | TRUE, FALSE |
| show_counts | Show n in output | TRUE | TRUE, FALSE |
| show_means | Show means for rating questions | TRUE | TRUE, FALSE |
| show_effective_n | Show DEFF-adjusted n | TRUE | TRUE, FALSE |
| decimal_places | Decimal places for % | 1 | 0, 1, 2 |

**Statistical Testing:**

| Setting | Description | Default | Options |
|---------|-------------|---------|---------|
| apply_sig_testing | Enable significance testing | TRUE | TRUE, FALSE |
| confidence_level | Confidence level | 0.95 | 0.90, 0.95, 0.99 |
| min_base_for_sig_testing | Minimum n for testing | 30 | 20, 30, 50 |
| sig_test_method | Test method | auto | auto, chi_square, z_test |

**Advanced Settings:**

| Setting | Description | Default |
|---------|-------------|---------|
| calculate_top2box | Calculate Top 2 Box | TRUE |
| calculate_bottom2box | Calculate Bottom 2 Box | FALSE |
| top2box_values | Values for Top 2 | 4,5 (for 1-5 scale) |
| bottom2box_values | Values for Bottom 2 | 1,2 |
| create_summary_sheet | Generate summary | TRUE |
| create_sample_composition | Generate sample comp | TRUE |

**Complete Example Settings Sheet:**
```
SettingName                 | SettingValue
data_file                   | ../data/survey_wave1.xlsx
weight_var                  | Weight
output_file                 | ../output/crosstabs_wave1.xlsx
confidence_level            | 0.95
show_percentages            | TRUE
show_counts                 | TRUE
show_means                  | TRUE
show_effective_n            | TRUE
apply_sig_testing           | TRUE
min_base_for_sig_testing    | 30
decimal_places              | 1
calculate_top2box           | TRUE
top2box_values              | 4,5
create_summary_sheet        | TRUE
create_sample_composition   | TRUE
```

---

## 4. Statistical Methods

### 4.1 Significance Testing Overview

**What is Significance Testing?**

Statistical tests determine if differences between segments are real or due to chance.

**Example:**
- Total satisfaction: 65%
- Male satisfaction: 70%
- Female satisfaction: 60%

**Question:** Is the 10-point difference (Male vs Female) statistically significant?

**Answer:** Depends on sample sizes and variance. Tabs calculates this automatically.

### 4.2 Test Methods

**Chi-Square Test (for proportions):**
- Used for: Single_Response and Multi_Mention questions
- Tests: Whether distribution differs from expected
- Reports: Overall significance across all categories
- Example: Testing if gender distribution differs by age group

**Z-Test (for proportions):**
- Used for: Comparing two proportions
- Tests: Whether % in Segment A differs from % in Segment B
- Reports: Pairwise comparisons
- Example: Testing if Male % differs from Female %

**T-Test (for means):**
- Used for: Rating, Numeric, NPS questions
- Tests: Whether mean in Segment A differs from mean in Segment B
- Reports: Pairwise comparisons
- Example: Testing if Male average satisfaction differs from Female

### 4.3 Design Effect (DEFF)

**What is DEFF?**

DEFF measures the efficiency loss from using weights or complex sample designs.

**Formula:**
```
DEFF = (n × Σw²) / (Σw)²
Effective N = n / DEFF
```

**Interpretation:**

| DEFF | Meaning | Impact | Action |
|------|---------|--------|--------|
| 1.0 | No efficiency loss | None | Great! |
| 1.5 | 50% more sample needed | Moderate | Acceptable |
| 2.0 | Sample worth half | Significant | Review weighting |
| 3.0+ | Severe efficiency loss | Major | Check for extreme weights |

**Example:**
- Raw sample: n = 1,000
- DEFF = 1.35
- Effective n = 1,000 / 1.35 = 741
- **Result:** Sample precision equivalent to 741 unweighted respondents

**Tabs automatically:**
- Calculates DEFF for weighted data
- Uses effective N for significance testing
- Reports both raw and effective N
- Warns if DEFF > 2.0

### 4.4 Significance Markers

**In output tables:**

**Letters (A, B, C, ...):**
- Each column gets a letter (A=Total, B=Male, C=Female, etc.)
- **Example:** 70%B means this value is significantly higher than column B

**Color Coding (if enabled):**
- Green = Significantly high
- Red = Significantly low
- No color = Not significant

**Example Output:**
```
                Total(A)  Male(B)  Female(C)  18-34(D)  35+(E)
Very satisfied  35%       40%C     31%        38%       34%
Satisfied       45%       42%      47%A       43%       46%
Neutral         15%       13%      17%        14%       16%
Dissatisfied    5%        5%       5%         5%        4%

Interpretation:
- Male (40%) significantly higher than Female (31%)
- Female Satisfied (47%) significantly higher than Total (45%)
```

---

## 5. Advanced Features

### 5.1 Composite Scores

**What are Composites?**

Averages of multiple questions to create an index.

**Use Cases:**
- Brand health index (awareness + consideration + preference)
- Customer satisfaction index (product + service + value)
- Engagement score (multiple engagement questions)

**Configuration:**

Add **Composite_Scores** sheet to config:

```
CompositeCode     | CompositeName           | SourceQuestions        | Method
BRAND_HEALTH      | Brand Health Index      | Q1,Q2,Q3,Q4           | mean
CSAT_INDEX        | Satisfaction Index      | Q5_Product,Q5_Service | mean
NET_PROMOTER      | NPS                     | Q10                   | nps
```

**Methods:**
- `mean` - Average of source questions (rescaled to 0-100)
- `sum` - Sum of source questions
- `nps` - Net Promoter Score calculation

**Output:**

Composite scores appear as additional questions in the output with:
- Mean score (0-100 scale)
- Standard deviation
- Sample size
- Significance testing vs other segments

### 5.2 Top Box / Bottom Box Analysis

**Top Box:**
% of respondents selecting highest rating option(s)

**Example (1-5 scale):**
- Top Box = % selecting 4 or 5
- Top 1 Box = % selecting only 5

**Configuration:**
```
calculate_top2box  | TRUE
top2box_values     | 4,5
```

**Output:**

Each rating question gets additional rows:
```
                Total  Male   Female
Mean            3.8    3.9    3.7
Top 2 Box       65%    70%C   60%
Top 1 Box       35%    40%C   30%
Bottom 2 Box    10%    8%     12%A
```

### 5.3 Multi-Mention Questions

**Special Handling:**

Multi-mention questions can be coded two ways:

**Method 1: Separate binary columns (Recommended)**
```
Q5_Brand_A | Q5_Brand_B | Q5_Brand_C | Q5_Brand_D
1          | 0          | 1          | 0
0          | 1          | 1          | 1
```

Each brand analyzed separately, % = proportion who selected it.

**Method 2: Comma-separated values**
```
Q5_Brands
1,3
2,3,4
```

Tabs splits and analyzes each option.

**Output:**

Multi-mention shows % who selected each option (can exceed 100% total):
```
                Total  Male   Female
Brand A         45%    50%C   40%
Brand B         32%    28%    36%A
Brand C         58%    60%    56%
Brand D         25%    30%C   20%
```

### 5.4 Ranking Questions

**Configuration:**

For ranking questions (1st choice, 2nd choice, 3rd choice):

```
QuestionCode  | QuestionType | ProcessingNote
Q7_Rank1      | Ranking      | First preference
Q7_Rank2      | Ranking      | Second preference
Q7_Rank3      | Ranking      | Third preference
```

**Output:**

Shows distribution of rankings:
```
                Total  Male   Female
Brand A
  1st choice    35%    40%C   30%
  2nd choice    25%    22%    28%
  3rd choice    20%    18%    22%

Brand B
  1st choice    25%    20%    30%A
  2nd choice    30%    35%A   25%
  3rd choice    25%    25%    25%
```

**Mean Rank:**

Lower = better (1 = first choice)
```
Brand A: Mean rank 1.8
Brand B: Mean rank 2.1
Brand C: Mean rank 2.3
```

### 5.5 Filters

**Apply filters to analyze sub-populations:**

Add **Filters** sheet to config:

```
FilterName    | FilterVariable | FilterValue
Buyers_Only   | Q4_Purchase    | 1
Aware_Only    | Q1_Awareness   | 1
Urban         | Q9_Urbanicity  | 1,2
```

**Usage:**

In Settings sheet:
```
active_filter | Buyers_Only
```

**Result:** Analysis runs only on respondents matching filter.

**Note:** Banner segments calculated within filtered data.

---

## 6. Output Interpretation

### 6.1 Summary Sheet

**Contents:**

**Project Information:**
- Project name
- Client name
- Survey dates
- Analyst name

**Sample Information:**
- Total respondents (unweighted)
- Total respondents (weighted)
- Overall DEFF
- Effective sample size

**Weighting Summary:**
- Weight variable name
- Weight range (min, max)
- Weight mean (should be ~1.0)
- Weight CV (coefficient of variation)
- DEFF by question (if varies)

**Question List:**
- All questions analyzed
- Question types
- Sample sizes

### 6.2 Sample Composition Sheet

**Shows banner segment sizes:**

```
Segment          | Unweighted N | Weighted N | % of Total
Total            | 1,000        | 1,000      | 100%
Male             | 450          | 480        | 48%
Female           | 550          | 520        | 52%
18-34            | 400          | 380        | 38%
35-54            | 350          | 370        | 37%
55+              | 250          | 250        | 25%
```

**Use this to:**
- Verify weighting worked correctly
- Check segment sizes before analysis
- Identify small base segments (< 30)

### 6.3 Question Sheets

**Each question gets a sheet with:**

**Header:**
- Question code and text
- Question type
- Sample size (unweighted and weighted)

**Base Rows:**
- Base (unweighted)
- Base (weighted)
- Effective N (if weighted)

**Data Rows:**
- Response options with % and/or counts
- Significance markers (letters)

**Summary Rows (for ratings):**
- Mean
- Top Box / Top 2 Box
- Bottom Box / Bottom 2 Box
- Standard deviation

**Footer:**
- Significance testing notes
- Column definitions (A=Total, B=Male, etc.)

**Example:**
```
Q3. Overall Satisfaction (1-5 scale)
                    Total(A)  Male(B)  Female(C)  18-34(D)  35+(E)
Base (unweighted)   1,000     450      550        400       600
Base (weighted)     1,000     480      520        380       620
Effective N         925       445      480        352       573

Very satisfied      35%       40%C     31%        38%       34%
Satisfied           45%       42%      47%A       43%       46%
Neutral             15%       13%      17%A       14%       16%
Dissatisfied        4%        4%       4%         4%        3%
Very dissatisfied   1%        1%       1%         1%        1%

Mean (1-5)          4.1       4.2C     4.0        4.1       4.1
Top 2 Box (4-5)     80%       82%      78%        81%       80%
Top 1 Box (5)       35%       40%C     31%        38%       34%
Bottom 2 Box (1-2)  5%        5%       5%         5%        4%

Significance testing at 95% confidence level
Letters indicate significantly higher than comparison column
```

---

## 7. Troubleshooting

### 7.1 Common Errors

**Error: "Data file not found"**
```
Cause: Incorrect file path in Settings
Fix: Use absolute path or check relative path from working directory
Test: file.exists("data/survey.xlsx")
```

**Error: "Question Q3 not found in data"**
```
Cause: QuestionCode doesn't match column name
Fix: Check spelling and case (R is case-sensitive)
     Column name: Q3_Satisfaction
     Config: Q3_Satisfaction (must match exactly)
```

**Error: "Weight variable 'Weight' not found"**
```
Cause: Weight column name doesn't match
Fix: Check column name in data file
     Or remove weight_var from Settings to run unweighted
```

**Error: "Banner variable Q2_Gender has all NA"**
```
Cause: All values in Q2_Gender are missing
Fix: Check data quality
     Or verify BreakVariable name is correct
```

**Error: "Insufficient base for significance testing"**
```
Cause: Segment has < min_base_for_sig_testing respondents
Fix: Increase sample size, combine segments, or lower threshold:
     min_base_for_sig_testing | 20
```

### 7.2 Data Issues

**Issue: All percentages are 0% or 100%**
```
Cause: No variation in data
Fix: Check data coding - all respondents gave same answer
     Or check filter is not excluding everyone
```

**Issue: Percentages don't add to 100%**
```
For Single_Response: This is an error - check data
For Multi_Mention: This is expected (people select multiple)
```

**Issue: Means are incorrect**
```
Cause: Data coded incorrectly (e.g., 1=Disagree, 5=Agree reversed)
Fix: Recode data before analysis
     Or check QuestionType is correct (Rating vs Single_Response)
```

**Issue: DEFF > 3.0**
```
Cause: Extreme weights in data
Fix: Check weighting - some respondents may have very high/low weights
     Consider weight trimming or raking instead of post-stratification
Action: Review weight variable distribution:
        summary(data$Weight)
        hist(data$Weight)
```

### 7.3 Performance Issues

**Issue: Analysis takes > 10 minutes**
```
Causes:
- Very large dataset (> 10,000 rows)
- Many questions (> 100)
- Many banner segments (> 20)

Solutions:
1. Use data.table package for faster processing:
   install.packages("data.table")

2. Reduce questions to only those needed

3. Reduce banner segments

4. Run in batches (multiple config files)
```

**Issue: Excel file is huge (> 50 MB)**
```
Causes:
- Many questions
- Many banner segments
- Showing both % and counts

Solutions:
1. Set show_counts | FALSE (keep only percentages)
2. Reduce decimal_places | 0
3. Split into multiple output files
```

---

## 8. Best Practices

### 8.1 Data Preparation

**Before running Tabs:**

✅ **DO:**
- Recode all text to numeric (Male=1, Female=2)
- Handle missing data (NA for don't know/refused)
- Verify question codes match between data and config
- Check weight variable is numeric and > 0
- Test with a small sample first

❌ **DON'T:**
- Use text values ("Yes", "No")
- Use -99 or 999 for missing data
- Mix coding schemes (Q1: 1=Yes, Q2: 0=Yes)
- Include open-ended text in numeric questions
- Run full analysis before testing config

### 8.2 Configuration

**Configuration Best Practices:**

✅ **DO:**
- Use meaningful BannerLabels ("Male 18-34" not "Seg1")
- Order banner segments logically (Total first, then demographics)
- Include question text in QuestionText column
- Document ValueLabels for all questions
- Save config versions (config_v1.xlsx, config_v2.xlsx)

❌ **DON'T:**
- Use special characters in column names (@, #, %)
- Create overlapping banner segments (18-34 and 25-45)
- Include too many segments (> 15 gets hard to read)
- Forget to include "Total" in banner

### 8.3 Analysis Workflow

**Recommended workflow:**

1. **Prepare data** (clean, recode, check)
2. **Create basic config** (1-2 questions, 3-4 segments)
3. **Test run** (verify output is correct)
4. **Expand config** (add all questions and segments)
5. **Full run** (generate complete report)
6. **QA output** (verify means, check significance makes sense)
7. **Client deliverable** (copy key tables to PowerPoint)

### 8.4 Interpreting Results

**Statistical vs. Practical Significance:**

With large samples, small differences can be statistically significant but not meaningful.

**Example:**
- Male: 65.2%
- Female: 64.8%
- Difference: 0.4 percentage points
- Significance: p < 0.05 ✓
- **Practical importance:** Negligible

**Rule of thumb:**
- < 3 points difference: Rarely meaningful
- 3-5 points: Possibly meaningful
- 5-10 points: Usually meaningful
- > 10 points: Definitely meaningful

**Consider both:**
- Statistical significance (is it real?)
- Effect size (is it important?)

---

## 9. Frequently Asked Questions

**Q: Can I use Tabs with unweighted data?**
A: Yes! Just leave `weight_var` blank in Settings. Significance testing still works.

**Q: What's the maximum number of questions/segments?**
A: No hard limit, but practical limits:
- Questions: < 100 (performance and file size)
- Segments: < 20 (readability)

**Q: Can I run multiple banner configurations?**
A: Yes, create multiple config files with different Banner sheets.

**Q: How do I handle "Don't know" / "Refused"?**
A: Recode to NA in data. Tabs excludes NA from percentages but reports base.

**Q: Can I export to PowerPoint?**
A: Not automatically. Copy Excel tables to PowerPoint manually, or use R Markdown (future).

**Q: How do I combine multiple waves?**
A: Use Tracker module for multi-wave analysis, or append data and add wave variable.

**Q: What if I have 100+ questions?**
A: Split into multiple analyses (demographics, satisfaction, behavior, etc.)

**Q: Can I test vs. a benchmark?**
A: Add benchmark as a "segment" with single value, or use separate analysis.

**Q: How do I weight data?**
A: Tabs doesn't create weights - use external tool. Tabs applies existing weights.

**Q: Can I run A/B test analysis?**
A: Yes! Create banner segments for Test A and Test B, significance testing shows if different.

---

## Appendix A: Complete Configuration Template

```
=============== SHEET 1: Questions ===============
QuestionCode     | QuestionText                  | QuestionType     | ValueLabels
Q1_Age           | Age group                     | Single_Response  | 1=18-24; 2=25-34; 3=35-44; 4=45-54; 5=55+
Q2_Gender        | Gender                        | Single_Response  | 1=Male; 2=Female; 3=Other
Q3_Satisfaction  | Overall satisfaction          | Rating           | 1=Very dissatisfied; 2=Dissatisfied; 3=Neutral; 4=Satisfied; 5=Very satisfied
Q4_Purchase      | Purchased in last 3 months    | Single_Response  | 1=Yes; 0=No
Q5_NPS           | Likelihood to recommend (0-10)| NPS              | 0-10 scale
Q6_Brands        | Brands owned                  | Multi_Mention    | 1=Brand A; 2=Brand B; 3=Brand C; 4=Brand D

=============== SHEET 2: Banner ===============
BannerLabel | BreakVariable | BreakValue | DisplayOrder
Total       | Total         |            | 1
Male        | Q2_Gender     | 1          | 2
Female      | Q2_Gender     | 2          | 3
18-34       | Q1_Age        | 1,2        | 4
35-54       | Q1_Age        | 3,4        | 5
55+         | Q1_Age        | 5          | 6

=============== SHEET 3: Settings ===============
SettingName                 | SettingValue
data_file                   | data/survey.xlsx
weight_var                  | Weight
output_file                 | output/crosstabs.xlsx
confidence_level            | 0.95
show_percentages            | TRUE
show_counts                 | TRUE
show_means                  | TRUE
apply_sig_testing           | TRUE
min_base_for_sig_testing    | 30
decimal_places              | 1
calculate_top2box           | TRUE
top2box_values              | 4,5
```

---

## Appendix B: Statistical Formulas

**Proportion:**
```
p = Σ(w × I(x=target)) / Σw
where I(x=target) = 1 if x matches target value, 0 otherwise
```

**Mean:**
```
μ = Σ(w × x) / Σw
```

**Weighted Variance:**
```
σ² = Σ(w × (x - μ)²) / Σw
```

**Design Effect:**
```
DEFF = (n × Σw²) / (Σw)²
```

**Effective Sample Size:**
```
n_eff = n / DEFF
```

**Z-Test (proportions):**
```
z = (p₁ - p₂) / √[p(1-p) × (1/n₁ + 1/n₂)]
where p = pooled proportion
```

**T-Test (means):**
```
t = (μ₁ - μ₂) / √[(s₁²/n₁) + (s₂²/n₂)]
```

---

**End of User Manual**

*Version 1.0.0 | Comprehensive Guide | Turas Tabs Module*
