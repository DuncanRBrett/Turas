# Turas Tabs - Quick Start Guide

**Version:** 1.0
**Estimated Time:** 10-15 minutes
**Difficulty:** Beginner to Intermediate

---

---

## Quick Start (10-15 Minutes)

## What is Turas Tabs?

Turas Tabs generates professional cross-tabulation reports from survey data with:
- **Weighted statistics** (automatically calculates effective sample sizes)
- **Statistical significance testing** (chi-square, t-tests, z-tests)
- **Multiple output formats** (percentages, counts, means, indices)
- **Banner analysis** (cross multiple demographic variables)
- **Professional Excel output** with color-coded significance

---

## Prerequisites

### Required R Packages
```r
install.packages(c("openxlsx", "readxl", "data.table"))
```

### What You Need
1. **Survey data file** (.xlsx, .csv, or .sav format)
   - Each row = one respondent
   - Each column = one question
   - Column names = question codes (Q1, Q2, etc.)

2. **Configuration file** (.xlsx format)
   - Specifies which questions to analyze
   - Defines banner variables (demographics)
   - Sets analysis options

3. **Survey structure file** (optional, from Parser)
   - Question labels and types
   - Response options

---

## Quick Start (10 Minutes)

### Step 1: Prepare Your Data

**Example data structure:**
```
ResponseID | Weight | Q1_Age | Q2_Gender | Q3_Satisfaction | Q4_Purchase
1          | 1.2    | 2      | 1         | 4               | 1
2          | 0.8    | 3      | 2         | 5               | 2
3          | 1.0    | 1      | 1         | 3               | 1
```

### Step 2: Create Configuration File

Create `config.xlsx` with these sheets:

**Sheet 1: Questions**
```
QuestionCode | QuestionText              | QuestionType
Q3           | How satisfied are you?    | Rating
Q4           | Did you purchase?         | Single_Response
```

**Sheet 2: Banner**
```
BannerLabel  | BreakVariable | BreakValue | DisplayOrder
Total        | Total         |            | 1
Male         | Q2_Gender     | 1          | 2
Female       | Q2_Gender     | 2          | 3
18-34        | Q1_Age        | 1,2        | 4
35+          | Q1_Age        | 3,4,5      | 5
```

**Sheet 3: Settings**
```
SettingName           | SettingValue
data_file             | survey_data.xlsx
weight_var            | Weight
output_file           | crosstabs_output.xlsx
confidence_level      | 0.95
show_percentages      | TRUE
show_counts           | TRUE
apply_sig_testing     | TRUE
```

### Step 3: Run Tabs

**Using GUI (Recommended):**
```r
source("modules/tabs/run_tabs_gui.R")
```

Then:
1. Click "Browse..." for configuration file
2. Select your `config.xlsx`
3. Click "Run Analysis"
4. Wait for processing (30 seconds - 2 minutes)
5. Excel file opens automatically

**Using R Script:**
```r
source("modules/tabs/run_tabs.R")

run_crosstabs(
  config_file = "config.xlsx"
)
```

### Step 4: Review Output

Your output Excel file will have:

**Summary Sheet:**
- Project information
- Sample composition
- Weighting statistics
- Question list

**Question Sheets (one per question):**
- Rows = Response options
- Columns = Banner segments
- Cells = Weighted %
- Statistical significance indicated by letters

**Example Q3 Sheet:**
```
                    Total    Male    Female   18-34   35+
Base (unweighted)   1000     450     550      400     600
Base (weighted)     1000     480     520      380     620

Very satisfied      35%A     40%B    31%      38%     34%
Satisfied           45%      42%     47%A     43%     46%
Neutral             15%      13%     17%      14%     16%
Dissatisfied        5%       5%      5%       5%      4%

Significance testing at 95% confidence level
A/B letters indicate significantly higher than compared segment
```

---

## Understanding the Output

### Statistical Significance Letters

**What the letters mean:**
- **A** = Significantly higher than segment A (typically "Total")
- **B** = Significantly higher than segment B (e.g., "Male")
- **C** = Significantly higher than segment C (e.g., "Female")

**Example:**
```
                Total    Male    Female
Very satisfied  35%      40%B    31%

Interpretation:
- Male (40%) is significantly higher than Female
- Female is not significantly different from Total
```

### Cell Colors

- **Green highlight** = Significantly high (if color-coding enabled)
- **Red highlight** = Significantly low
- **No highlight** = Not significant

---

## Common Configurations

### Simple Cross-tabs (No Weights)

**Settings sheet:**
```
data_file          | survey_data.xlsx
weight_var         |                    [Leave blank]
output_file        | crosstabs.xlsx
show_percentages   | TRUE
apply_sig_testing  | FALSE              [No sig testing without weights]
```

### Weighted Analysis with Sig Testing

**Settings sheet:**
```
data_file          | survey_data.xlsx
weight_var         | Weight
output_file        | crosstabs_weighted.xlsx
show_percentages   | TRUE
show_counts        | TRUE
apply_sig_testing  | TRUE
confidence_level   | 0.95
```

### Mean Scores Only

**Settings sheet:**
```
show_percentages   | FALSE
show_counts        | FALSE
show_means         | TRUE
```

---

## Troubleshooting

### ❌ "Data file not found"
**Fix:** Ensure `data_file` path in Settings is correct. Use absolute path if needed:
```
data_file | C:/Projects/survey_data.xlsx
```

### ❌ "Weight variable not found in data"
**Fix:** Check spelling of `weight_var` in Settings matches column name exactly (case-sensitive)

### ❌ "Question Q3 not found in data"
**Fix:** Ensure `QuestionCode` in Questions sheet matches column name in data file

### ❌ "Banner variable Q2_Gender has all NA values"
**Fix:** Check for typos in `BreakVariable` name. Verify data file has this column.

### ❌ "Insufficient base size for significance testing"
**Fix:** Cell has < 30 respondents. Either:
- Combine segments to increase base
- Set `min_base_for_sig_testing = 20` (lower threshold)
- Disable sig testing for that segment

---

## Next Steps

Once you have your basic cross-tabs working:

1. **Add more banner variables** - Age, gender, region, etc.
2. **Include composite scores** - Average of multiple questions
3. **Use filters** - Analyze sub-populations
4. **Create index summaries** - Top 2 box, bottom 2 box
5. **Export to PowerPoint** - For client presentations

See the **User Manual** for comprehensive feature documentation.

---

## Quick Reference

### Minimum Required Files

1. ✅ Survey data (.xlsx/.csv/.sav)
2. ✅ Configuration file with:
   - Questions sheet
   - Banner sheet
   - Settings sheet

### Minimum Required Settings

```
data_file
output_file
```

All other settings have defaults.

### Typical Analysis Time

| Data Size | Questions | Time |
|-----------|-----------|------|
| 500 respondents | 10 questions | 15 seconds |
| 1,000 respondents | 25 questions | 45 seconds |
| 5,000 respondents | 50 questions | 3-5 minutes |

---

## Example Configuration File

Download the template:
```
templates/Crosstab_Config_Template.xlsx
```

Or create manually with the structure shown in Step 2 above.

---

**Congratulations!** You've run your first Turas Tabs analysis.

For advanced features (composite scores, ranking questions, filters, etc.), see the **User Manual**.

For technical details (API, algorithms, customization), see the **Technical Documentation**.

For real-world examples, see the **Example Workflows**.

---

*Version 1.0.0 | Quick Start Guide | Turas Tabs Module*

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

---

## Example Workflows

---

## Workflow 1: Basic Brand Tracking Survey

### Scenario

You've conducted a brand tracking survey with 500 respondents. You want to analyze:
- Brand awareness (unaided and aided)
- Brand preference
- Purchase intent
- Cross-tabulated by gender and age

### Step 1: Prepare Your Data

**data.csv:**
```
RespondentID,Gender,Age_Group,Q01_Unaided_Awareness,Q02_Aided_Awareness,Q03_Brand_Preference,Q04_Purchase_Intent
1,Male,18-34,Brand A,Brand A,Brand A,5
2,Female,35-54,None,Brand B,Brand B,4
3,Male,55+,Brand C,Brand C,Brand C,3
...
```

### Step 2: Create Survey Structure

**Survey_Structure.xlsx - Questions Sheet:**
```
QuestionCode | QuestionText                      | Variable_Type
Q01          | Unaided Brand Awareness           | Single_Response
Q02          | Aided Brand Awareness             | Single_Response
Q03          | Which brand do you prefer?        | Single_Response
Q04          | Purchase Intent (1-5)             | Rating
Gender       | Gender                            | Single_Response
Age_Group    | Age Group                         | Single_Response
```

**Survey_Structure.xlsx - Options Sheet:**
```
QuestionCode | OptionValue | OptionText  | ShowInOutput
Q01          | 1           | Brand A     | TRUE
Q01          | 2           | Brand B     | TRUE
Q01          | 3           | Brand C     | TRUE
Q01          | 4           | None        | TRUE
Q02          | 1           | Brand A     | TRUE
Q02          | 2           | Brand B     | TRUE
Q02          | 3           | Brand C     | TRUE
Q03          | 1           | Brand A     | TRUE
Q03          | 2           | Brand B     | TRUE
Q03          | 3           | Brand C     | TRUE
Q04          | 1           | 1           | TRUE
Q04          | 2           | 2           | TRUE
Q04          | 3           | 3           | TRUE
Q04          | 4           | 4           | TRUE
Q04          | 5           | 5           | TRUE
Gender       | 1           | Male        | TRUE
Gender       | 2           | Female      | TRUE
Age_Group    | 1           | 18-34       | TRUE
Age_Group    | 2           | 35-54       | TRUE
Age_Group    | 3           | 55+         | TRUE
```

### Step 3: Configure Tabs

**Tabs_Config.xlsx - Settings Sheet:**
```
Setting                  | Value
survey_structure_file    | Survey_Structure.xlsx
data_file                | data.csv
output_file              | Brand_Tracking_Results.xlsx
show_significance        | TRUE
significance_level       | 0.05
minimum_base            | 30
stat_test               | chi-square
decimal_places          | 0
decimal_places_average  | 1
show_frequencies        | TRUE
show_percentages        | TRUE
```

**Tabs_Config.xlsx - Banner Sheet:**
```
BannerQuestion
Total
Gender
Age_Group
```

**Tabs_Config.xlsx - Stub Sheet:**
```
StubQuestion | BaseFilter
Q01          |
Q02          |
Q03          |
Q04          |
```

### Step 4: Run Analysis

```r
# Set working directory to project
setwd("/path/to/brand_tracking_project")

# Load Turas
source("/path/to/Turas/turas.R")
turas_load("tabs")

# Run crosstabs
result <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)

# Check for errors
if (result$validation$has_errors) {
  print(result$validation$error_log$errors)
} else {
  cat("Analysis complete! Output:", result$output_file, "\n")
}
```

### Step 5: Interpret Results

**Brand_Tracking_Results.xlsx - Q01 Sheet:**

```
Unaided Brand Awareness
                          Total   Male    Female  18-34   35-54   55+
Base (n=)                 500     250     250     180     200     120
Brand A     Frequency     200     110     90      80      70      50
            Column %      40%     44%     36%     44%     35%     42%
            Sig.                  F              AG
Brand B     Frequency     150     70      80      50      70      30
            Column %      30%     28%     32%     28%     35%     25%
            Sig.                                  F
Brand C     Frequency     100     50      50      30      40      30
            Column %      20%     20%     20%     17%     20%     25%
            Sig.
None        Frequency     50      20      30      20      20      10
            Column %      10%     8%      12%     11%     10%     8%
            Sig.                  M
```

**Key Insights:**
- Brand A has 40% unaided awareness overall
- Males significantly more aware of Brand A than Females (44% vs 36%)
- Brand A awareness highest in 18-34 age group (significantly higher than 35-54)
- Very few "None" responses among males (significantly lower than females)

### Expected Output Files

- `Brand_Tracking_Results.xlsx` with 4 sheets (Q01, Q02, Q03, Q04)
- Each sheet formatted with significance letters

---

## Workflow 2: Customer Satisfaction with NPS

### Scenario

You've surveyed 1,000 customers about their satisfaction. You want to:
- Measure overall satisfaction (1-5 scale)
- Calculate Net Promoter Score (NPS)
- Analyze by customer segment and product line
- Identify areas for improvement

### Step 1: Prepare Data

**customer_satisfaction.csv:**
```
CustomerID,Segment,Product_Line,Q01_Overall_Sat,Q02_NPS,Q03_Recommend,Q04_Support_Sat,Q05_Value_Sat
1,Enterprise,Product A,5,10,5,5,4
2,SMB,Product B,4,9,4,3,4
3,Consumer,Product A,3,7,3,4,3
...
```

### Step 2: Create Survey Structure

**Survey_Structure.xlsx - Questions:**
```
QuestionCode    | QuestionText                              | Variable_Type
Q01             | Overall Satisfaction (1-5)                | Rating
Q02             | How likely to recommend? (0-10)           | NPS
Q03             | Likelihood to Recommend (1-5)             | Rating
Q04             | Support Satisfaction (1-5)                | Rating
Q05             | Value for Money (1-5)                     | Rating
Segment         | Customer Segment                          | Single_Response
Product_Line    | Product Line                              | Single_Response
```

**Options Sheet:**
```
QuestionCode | OptionValue | OptionText      | ShowInOutput
Q01-Q05      | 1-5         | 1-5             | TRUE
Q02          | 0-10        | 0-10            | TRUE
Segment      | 1           | Enterprise      | TRUE
Segment      | 2           | SMB             | TRUE
Segment      | 3           | Consumer        | TRUE
Product_Line | 1           | Product A       | TRUE
Product_Line | 2           | Product B       | TRUE
Product_Line | 3           | Product C       | TRUE
```

### Step 3: Configure Tabs

**Tabs_Config.xlsx - Settings:**
```
Setting                  | Value
survey_structure_file    | Survey_Structure.xlsx
data_file                | customer_satisfaction.csv
output_file              | Satisfaction_Analysis.xlsx
show_significance        | TRUE
significance_level       | 0.05
stat_test               | t-test
minimum_base            | 50
decimal_places          | 0
decimal_places_average  | 2
show_frequencies        | FALSE
show_percentages        | TRUE
calculate_top2box       | TRUE
calculate_bottom2box    | TRUE
```

**Banner Sheet:**
```
BannerQuestion
Total
Segment
Product_Line
```

**Stub Sheet:**
```
StubQuestion | BaseFilter
Q01          |
Q02          |
Q03          |
Q04          |
Q05          |
```

### Step 4: Run Analysis

```r
setwd("/path/to/satisfaction_project")
source("/path/to/Turas/turas.R")
turas_load("tabs")

result <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)
```

### Step 5: Interpret NPS Results

**Satisfaction_Analysis.xlsx - Q02 Sheet (NPS):**

```
How likely to recommend? (0-10)
                          Total   Enterprise  SMB     Consumer  Product A  Product B  Product C
Base (n=)                 1000    300         400     300       350        350        300

Detractors (0-6)  %       25%     15%         20%     40%       18%        25%        35%
Sig.                              C           C       ES        BC         C

Passives (7-8)    %       35%     30%         40%     35%       32%        40%        35%
Sig.                              S           E               A          C

Promoters (9-10)  %       40%     55%         40%     25%       50%        35%        30%
Sig.                              SC          C       ES        BC         C

NPS Score                 15      40          20      -15       32         10         -5
Sig.                              SC          C       ES        BC         C
```

**Key Insights:**
- Overall NPS = 15 (acceptable but room for improvement)
- Enterprise segment has excellent NPS (40) - significantly higher than Consumer (-15)
- Product A performing best (NPS = 32)
- Product C has negative NPS (-5) - needs urgent attention
- Consumer segment has more Detractors (40%) than Promoters (25%)

**Action Items:**
1. Investigate why Consumer segment is dissatisfied
2. Study Product A's success factors and apply to Products B & C
3. Focus improvement efforts on Product C

---

## Workflow 3: Weighted Survey Analysis

### Scenario

You have a survey of 2,000 respondents but your sample over-represents urban areas and younger demographics. You need to weight the data to match the population.

### Step 1: Prepare Data with Weights

**survey_data.csv:**
```
RespondentID,Age,Region,Income,Q01,Q02,Q03,weight
1,25,Urban,50000,4,Yes,Brand A,0.8
2,55,Rural,75000,3,No,Brand B,1.5
3,30,Urban,60000,5,Yes,Brand A,0.9
...
```

**Weight Explanation:**
- Urban respondents (over-sampled) get weight < 1.0
- Rural respondents (under-sampled) get weight > 1.0
- Average weight ≈ 1.0

### Step 2: Configure Weighted Analysis

**Tabs_Config.xlsx - Settings:**
```
Setting                  | Value
survey_structure_file    | Survey_Structure.xlsx
data_file                | survey_data.csv
output_file              | Weighted_Results.xlsx
weight_column            | weight
use_effective_base       | TRUE
show_significance        | TRUE
stat_test               | z-test
significance_level       | 0.05
decimal_places          | 0
show_unweighted_base    | TRUE
show_weighted_base      | TRUE
show_effective_base     | TRUE
```

**Note:** Setting `use_effective_base = TRUE` adjusts significance testing for weighting impact (DEFF).

### Step 3: Run Weighted Analysis

```r
result <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)
```

### Step 4: Interpret Weighted Results

**Weighted_Results.xlsx - Q01 Sheet:**

```
Overall Satisfaction
                          Total
Base (unweighted)         2000
Base (weighted)           2000
Effective base            1538
DEFF                      1.30

Very Satisfied    %       35%
Satisfied         %       40%
Neutral           %       15%
Dissatisfied      %       7%
Very Dissatisfied %       3%
```

**Understanding the Bases:**
- **Unweighted:** Actual number of respondents (2000)
- **Weighted:** Sum of weights (2000) - population estimate
- **Effective:** Accounts for weighting variance (1538)
- **DEFF:** Design Effect = 1.30 (moderate weighting impact)

**Impact on Significance Testing:**
- Without DEFF: Uses weighted base (2000) → overstates significance
- With DEFF: Uses effective base (1538) → correct significance
- Effective base is 77% of weighted base (2000 × 1/1.30)

### Step 5: Compare Weighted vs Unweighted

**Create comparison table:**

```r
# Run unweighted analysis
config_unweighted <- config
config_unweighted$weight_column <- NA

result_unweighted <- run_crosstabs(
  config_file = config_unweighted,
  survey_structure_file = "Survey_Structure.xlsx"
)

# Compare results
# Unweighted: Urban over-represented → inflates urban preferences
# Weighted: Corrects for sampling bias → true population estimate
```

---

## Workflow 4: Multi-Banner Crosstabulation

### Scenario

You want to analyze brand preference across multiple demographic cuts simultaneously:
- Gender (Male, Female)
- Age (18-34, 35-54, 55+)
- Region (North, South, East, West)
- Income (<50k, 50-100k, >100k)

### Step 1: Configure Multi-Banner

**Tabs_Config.xlsx - Banner Sheet:**
```
BannerQuestion
Total
Gender
Age_Group
Region
Income_Bracket
```

**This creates banner with 13 columns:**
- Total (1)
- Gender (2): Male, Female
- Age_Group (3): 18-34, 35-54, 55+
- Region (4): North, South, East, West
- Income_Bracket (3): <50k, 50-100k, >100k

### Step 2: Configure Analysis

**Tabs_Config.xlsx - Settings:**
```
Setting                  | Value
show_significance        | TRUE
stat_test               | chi-square
minimum_base            | 50
decimal_places          | 0
```

### Step 3: Run Analysis

```r
result <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)
```

### Step 4: Interpret Multi-Banner Results

**Results.xlsx - Q03_Brand_Preference Sheet:**

```
Which brand do you prefer?
                    Total  Male  Female  18-34  35-54  55+  North  South  East  West  <50k  50-100k  >100k
Base (n=)           1500   750   750     500    600    400  350    400    400   350   600   600      300

Brand A     %       40%    45%   35%     50%    38%    30%  42%    40%    38%   41%   35%   42%      48%
            Sig.           F     M       AG     A      AS                            I     I        I

Brand B     %       35%    30%   40%     28%    37%    40%  33%    35%    37%   35%   40%   33%      30%
            Sig.           M     F       AG     A      A                             GI    I

Brand C     %       25%    25%   25%     22%    25%    30%  25%    25%    25%   24%   25%   25%      22%
            Sig.                         A
```

**Key Insights:**
- Brand A preferred by males (45% vs 35% female, significant)
- Brand A strongest in 18-34 age group (50%), weakest in 55+ (30%)
- Brand A preference increases with income (35% → 42% → 48%)
- Brand B shows opposite pattern - higher among females and lower income
- Region shows little variation (no significant differences)

**Strategic Implications:**
- Brand A: Target younger, affluent males
- Brand B: Target females and value-conscious consumers
- Regional marketing can use same strategy nationwide

---

## Workflow 5: Advanced Filtering and Segmentation

### Scenario

You want to analyze only specific subsets of your data:
- Product satisfaction among purchasers only (exclude non-purchasers)
- Service quality among those who contacted support
- Brand preference among category users

### Step 1: Set Up Base Filters

**Tabs_Config.xlsx - Stub Sheet:**
```
StubQuestion          | BaseFilter
Q05_Product_Sat       | Q01_Purchased == "Yes"
Q06_Service_Quality   | Q02_Contacted_Support == "Yes"
Q07_Brand_Preference  | Q03_Category_User == "Yes"
Q08_Repurchase_Intent | Q01_Purchased == "Yes" & Q04_Satisfied >= 3
```

**Filter Syntax:**
- Single condition: `Variable == "Value"`
- Multiple conditions (AND): `Var1 == "A" & Var2 == "B"`
- Multiple conditions (OR): `Var1 == "A" | Var2 == "B"`
- Numeric comparisons: `Age >= 18 & Age <= 34`
- Not equal: `Status != "Inactive"`
- Missing values: `!is.na(Email)`

### Step 2: Configure Analysis

**Tabs_Config.xlsx - Settings:**
```
Setting                  | Value
show_significance        | TRUE
minimum_base            | 50
decimal_places          | 0
```

### Step 3: Run Analysis

```r
result <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)
```

### Step 4: Interpret Filtered Results

**Results.xlsx - Q05_Product_Sat Sheet:**

```
Product Satisfaction (Among Purchasers Only)
Base Filter: Q01_Purchased == "Yes"

                          Total   Male    Female
Base (n=)                 800     450     350
(Total sample: 1500, Purchasers: 800)

Very Satisfied    %       45%     48%     41%
Satisfied         %       35%     33%     38%
Neutral           %       12%     11%     14%
Dissatisfied      %       6%      6%      5%
Very Dissatisfied %       2%      2%      2%
```

**Key Points:**
- Base filter automatically shown in output
- Base sizes smaller due to filtering (800 vs 1500)
- Analysis only includes relevant respondents
- Significance testing uses filtered base sizes

### Step 5: Complex Filter Example

**Analyze brand switchers who are dissatisfied:**

```
StubQuestion              | BaseFilter
Q10_Switch_Reasons        | Q08_Switched == "Yes" & Q05_Product_Sat <= 2
Q11_Competitor_Preference | Q08_Switched == "Yes"
```

This gives you insights into:
- Why dissatisfied customers switched (Q10)
- Which competitors they switched to (Q11)

---

## Workflow 6: Rating Scale Analysis with Significance

### Scenario

You have a product evaluation survey with multiple 1-5 rating scales. You want to:
- Show both frequency distribution and average scores
- Test if differences between segments are significant
- Identify top-performing and bottom-performing attributes

### Step 1: Set Up Rating Questions

**Survey_Structure.xlsx - Questions:**
```
QuestionCode | QuestionText                      | Variable_Type
Q01          | Quality                           | Rating
Q02          | Value for Money                   | Rating
Q03          | Ease of Use                       | Rating
Q04          | Customer Support                  | Rating
Q05          | Likelihood to Recommend           | Rating
```

### Step 2: Configure Analysis

**Tabs_Config.xlsx - Settings:**
```
Setting                  | Value
show_frequencies        | TRUE
show_percentages        | TRUE
show_averages           | TRUE
calculate_top2box       | TRUE
calculate_bottom2box    | TRUE
stat_test              | t-test
significance_level     | 0.05
decimal_places         | 0
decimal_places_average | 2
```

**Banner Sheet:**
```
BannerQuestion
Total
Customer_Segment
Product_Version
```

### Step 3: Run Analysis

```r
result <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)
```

### Step 4: Interpret Rating Results

**Results.xlsx - Q01_Quality Sheet:**

```
Quality Rating
                          Total   New_Customers  Existing  Version_1  Version_2
Base (n=)                 1000    400            600       600        400

5 (Excellent)     Freq    300     100            200       200        100
                  %       30%     25%            33%       33%        25%
                  Sig.            E              N         V          V

4 (Good)          Freq    400     180            220       240        160
                  %       40%     45%            37%       40%        40%
                  Sig.            E

3 (Average)       Freq    200     80             120       100        100
                  %       20%     20%            20%       17%        25%
                  Sig.                                     V          V

2 (Below Avg)     Freq    70      30             40        40         30
                  %       7%      8%             7%        7%         8%

1 (Poor)          Freq    30      10             20        20         10
                  %       3%      3%             3%        3%         3%

Top-2-Box (4-5)   %       70%     70%            70%       73%        65%
                  Sig.                                     V          V

Bottom-2-Box (1-2) %      10%     10%            10%       10%        10%

Average           Score   3.87    3.80           3.92      3.94       3.75
                  Sig.            E              N         V          V
```

**Key Insights:**
- Overall quality average: 3.87 / 5.00
- Existing customers rate significantly higher than new customers (3.92 vs 3.80)
- Version 1 significantly outperforms Version 2 (3.94 vs 3.75)
- 70% top-2-box satisfaction (industry benchmark comparison)
- Only 10% dissatisfied (bottom-2-box)

**Action Items:**
- Investigate why new customers rate lower (onboarding issues?)
- Review Version 2 quality concerns
- Maintain strong quality for existing customers

---

## Workflow 7: Multi-Mention Question Analysis

### Scenario

You asked respondents "Which of these features do you use? (Select all that apply)". Each respondent can select multiple features. You want to analyze:
- Overall feature usage
- Feature combinations
- Usage by customer segment

### Step 1: Data Structure

**survey_data.csv:**
```
RespondentID,Segment,Q10_Features_1,Q10_Features_2,Q10_Features_3,Q10_Features_4,Q10_Features_5
1,Enterprise,Feature A,Feature C,,,
2,SMB,Feature B,Feature D,Feature E,,
3,Consumer,Feature A,,,,
```

**Each row represents one mention. Blanks = not mentioned.**

### Step 2: Survey Structure

**Survey_Structure.xlsx - Questions:**
```
QuestionCode | QuestionText                                | Variable_Type | Columns
Q10          | Which features do you use? (Select all)     | Multi_Mention | 5
Segment      | Customer Segment                            | Single_Response |
```

**Survey_Structure.xlsx - Options:**
```
QuestionCode | OptionValue | OptionText   | ShowInOutput
Q10_1        | 1           | Feature A    | TRUE
Q10_1        | 2           | Feature B    | TRUE
Q10_1        | 3           | Feature C    | TRUE
Q10_1        | 4           | Feature D    | TRUE
Q10_1        | 5           | Feature E    | TRUE
```

**Note:** For multi-mention, options are keyed to Q10_1 (any column).

### Step 3: Configure Analysis

**Tabs_Config.xlsx - Settings:**
```
Setting                  | Value
show_frequencies        | TRUE
show_percentages        | TRUE
show_significance       | TRUE
stat_test              | z-test
```

**Banner:**
```
BannerQuestion
Total
Segment
```

**Stub:**
```
StubQuestion | BaseFilter
Q10          |
```

### Step 4: Run Analysis

```r
result <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)
```

### Step 5: Interpret Multi-Mention Results

**Results.xlsx - Q10 Sheet:**

```
Which features do you use? (Select all that apply)
                          Total   Enterprise  SMB     Consumer
Base (n=)                 1000    300         400     300

Feature A     Freq        600     250         220     130
              %           60%     83%         55%     43%
              Sig.                SC          C       ES

Feature B     Freq        450     200         180     70
              %           45%     67%         45%     23%
              Sig.                SC          C       ES

Feature C     Freq        400     180         150     70
              %           40%     60%         38%     23%
              Sig.                SC          C       ES

Feature D     Freq        300     150         100     50
              %           30%     50%         25%     17%
              Sig.                SC          C       E

Feature E     Freq        200     50          80      70
              %           20%     17%         20%     23%
              Sig.                C                   E

Average Mentions          1.95    2.77        1.83    1.30
```

**Key Insights:**
- Feature A most used overall (60%)
- Enterprise customers use significantly more features (2.77 avg vs 1.30 consumer)
- Feature E usage similar across segments (no significant differences)
- Consumer segment uses significantly fewer features across the board

**Important Notes on Multi-Mention:**
- Percentages can sum to > 100% (each feature independent)
- Base = number of respondents (not number of mentions)
- Frequency = number of respondents who selected this feature (weighted)
- Significance testing compares feature usage rates between segments

### Step 6: Advanced Analysis - Feature Combinations

**To analyze which features are used together, create custom filters:**

```
StubQuestion      | BaseFilter
Q20_Other_Features | Q10_Features_1 == "Feature A" | Q10_Features_2 == "Feature A" | Q10_Features_3 == "Feature A" | Q10_Features_4 == "Feature A" | Q10_Features_5 == "Feature A"
```

This shows: "Among Feature A users, what other features do they use?"

---

## Workflow 8: Composite Metrics and Custom Scores

### Scenario

You want to create composite metrics that combine multiple questions:
- Overall Satisfaction Index (average of Q1, Q2, Q3)
- Quality Score (weighted average of attributes)
- Category NPS (NPS for specific product categories)

### Step 1: Define Composite Questions

**Survey_Structure.xlsx - Questions:**
```
QuestionCode | QuestionText                              | Variable_Type | CompositeOf
Q01          | Product Quality                           | Rating        |
Q02          | Service Quality                           | Rating        |
Q03          | Value for Money                           | Rating        |
COMP_SAT     | Overall Satisfaction Index                | Composite     | Q01,Q02,Q03
COMP_QUALITY | Quality Score (Product + Service)         | Composite     | Q01,Q02
```

### Step 2: Configure Composite Settings

**Tabs_Config.xlsx - Settings:**
```
Setting                  | Value
calculate_composites     | TRUE
composite_method        | mean
show_frequencies        | FALSE
show_percentages        | FALSE
show_averages           | TRUE
decimal_places_average  | 2
```

**Stub:**
```
StubQuestion | BaseFilter
Q01          |
Q02          |
Q03          |
COMP_SAT     |
COMP_QUALITY |
```

### Step 3: Run Analysis

```r
result <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)
```

### Step 4: Interpret Composite Results

**Results.xlsx - COMP_SAT Sheet:**

```
Overall Satisfaction Index
Composite of: Product Quality, Service Quality, Value for Money

                          Total   Segment_A  Segment_B  Segment_C
Base (n=)                 1000    350        400        250

Average Score             3.85    4.20       3.75       3.50
Sig.                              BC         C          AB

Component Scores:
  Product Quality (Q01)   4.00    4.30       3.90       3.70
  Service Quality (Q02)   3.80    4.20       3.70       3.40
  Value for Money (Q03)   3.75    4.10       3.65       3.40

Top-2-Box %              68%     82%        65%        54%
Bottom-2-Box %           12%     5%         13%        20%
```

**Key Insights:**
- Overall satisfaction index: 3.85 / 5.00
- Segment A significantly more satisfied than B and C
- Product Quality highest rated component (4.00)
- Value for Money lowest rated component (3.75)
- Segment C has lowest scores across all components

**Custom Weighted Composite:**

If you want different weights for components:

```r
# In composite_processor.R, customize calculation
composite_score <- (q01_score * 0.5) + (q02_score * 0.3) + (q03_score * 0.2)
# Product Quality: 50% weight
# Service Quality: 30% weight
# Value for Money: 20% weight
```

---

## Workflow 9: Large Dataset Processing

### Scenario

You have a very large dataset (50,000+ respondents, 200+ questions) and need to:
- Process efficiently without running out of memory
- Monitor progress during long-running jobs
- Handle potential errors gracefully

### Step 1: Optimize Data Format

**Use CSV instead of Excel for large data:**

```r
# SLOW: Reading Excel
data <- readxl::read_excel("large_data.xlsx")  # 2-5 minutes

# FAST: Reading CSV
data <- read.csv("large_data.csv")  # 10-30 seconds
```

**Convert data if needed:**

```r
# One-time conversion
library(readxl)
library(data.table)

data <- read_excel("large_data.xlsx")
fwrite(data, "large_data.csv")  # Fast CSV writer
```

### Step 2: Configure for Large Datasets

**Tabs_Config.xlsx - Settings:**
```
Setting                  | Value
data_file                | large_data.csv
show_frequencies        | FALSE
calculate_top2box       | FALSE
calculate_bottom2box    | FALSE
batch_processing        | TRUE
batch_size              | 50
checkpoint_frequency    | 10
```

**Reduce output size:**
- Disable frequencies (percentages sufficient)
- Disable top/bottom box if not needed
- Process in batches

### Step 3: Monitor Memory Usage

```r
# Check memory before running
print(pryr::mem_used())

# Run with monitoring
result <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)

# Memory after
print(pryr::mem_used())

# If memory is an issue:
gc()  # Force garbage collection
```

### Step 4: Process Subset First (Testing)

**Test with sample before running full analysis:**

```r
# Create sample data
set.seed(123)
sample_data <- data[sample(nrow(data), 1000), ]
write.csv(sample_data, "sample_data.csv", row.names = FALSE)

# Test with sample
result_sample <- run_crosstabs(
  config_file = "Tabs_Config_Sample.xlsx",  # Point to sample_data.csv
  survey_structure_file = "Survey_Structure.xlsx"
)

# If successful, run on full data
result_full <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)
```

### Step 5: Batch Processing Strategy

**For extremely large analyses, process in batches:**

```r
# Split stub questions into batches
stub_questions <- c("Q01", "Q02", ..., "Q200")  # 200 questions

batch_size <- 50
n_batches <- ceiling(length(stub_questions) / batch_size)

for (batch_num in 1:n_batches) {
  cat("\n=== Processing Batch", batch_num, "of", n_batches, "===\n")

  # Get batch questions
  batch_start <- (batch_num - 1) * batch_size + 1
  batch_end <- min(batch_num * batch_size, length(stub_questions))
  batch_qs <- stub_questions[batch_start:batch_end]

  # Update config for this batch
  # ... write batch questions to Stub sheet ...

  # Process batch
  result_batch <- run_crosstabs(
    config_file = "Tabs_Config.xlsx",
    survey_structure_file = "Survey_Structure.xlsx",
    output_file = paste0("Results_Batch_", batch_num, ".xlsx")
  )

  # Free memory
  rm(result_batch)
  gc()
}

cat("\n=== All batches complete! ===\n")
```

### Step 6: Performance Benchmarks

**Expected processing times (MacBook Pro M1):**

| Rows    | Questions | Banners | Time          |
|---------|-----------|---------|---------------|
| 1,000   | 50        | 10      | ~5 seconds    |
| 10,000  | 100       | 15      | ~1 minute     |
| 50,000  | 200       | 20      | ~8 minutes    |
| 100,000 | 200       | 20      | ~18 minutes   |

**If slower than expected:**
1. Check data format (use CSV not Excel)
2. Reduce banner columns
3. Disable optional calculations
4. Check for slow filters
5. Use data.table package

---

## Workflow 10: Integration with Turas Parser

### Scenario

You have a survey questionnaire in Excel format. You want to:
1. Parse the questionnaire to create Survey_Structure.xlsx
2. Run crosstabs on the survey data
3. Ensure consistency between parser and tabs outputs

### Step 1: Parse Questionnaire

**Create questionnaire file (Survey_Questionnaire.xlsx):**

```
Q# | Question Text                                          | Type
1  | Which of the following brands are you aware of?        | Multi-mention
2  | Which brand do you prefer?                             | Single choice
3  | How satisfied are you with your current brand? (1-5)   | Rating
4  | How likely are you to recommend to a friend? (0-10)    | NPS
```

**Run Turas Parser:**

```r
# Load Turas
source("/path/to/Turas/turas.R")
turas_load("parser")

# Parse questionnaire
result <- run_parser(
  questionnaire_file = "Survey_Questionnaire.xlsx",
  output_file = "Survey_Structure.xlsx"
)
```

**This creates Survey_Structure.xlsx with:**
- Questions sheet with QuestionCode, QuestionText, Variable_Type
- Options sheet with all detected response options

### Step 2: Verify Parser Output

**Check Survey_Structure.xlsx:**

```r
library(readxl)

questions <- read_excel("Survey_Structure.xlsx", sheet = "Questions")
options <- read_excel("Survey_Structure.xlsx", sheet = "Options")

View(questions)
View(options)

# Verify:
# - All questions detected correctly
# - Variable_Type assigned correctly (Multi_Mention, Single_Response, Rating, NPS)
# - All options captured
```

### Step 3: Configure Tabs to Use Parser Output

**Tabs_Config.xlsx - Settings:**
```
Setting                  | Value
survey_structure_file    | Survey_Structure.xlsx
data_file                | survey_data.csv
output_file              | Results.xlsx
```

**Tabs will automatically use the parser-generated structure!**

### Step 4: Run Integrated Workflow

**Complete workflow script:**

```r
# ========================================
# Integrated Turas Workflow
# ========================================

library(here)
setwd(here("projects", "brand_tracking"))

# Load Turas
source(here("Turas", "turas.R"))

# ========================================
# STEP 1: Parse Questionnaire
# ========================================
cat("\n=== Parsing Questionnaire ===\n")
turas_load("parser")

parser_result <- run_parser(
  questionnaire_file = "Survey_Questionnaire.xlsx",
  output_file = "Survey_Structure.xlsx"
)

if (parser_result$success) {
  cat("✓ Questionnaire parsed successfully\n")
} else {
  stop("✗ Parser failed: ", parser_result$error)
}

# ========================================
# STEP 2: Review and Edit Structure (Manual)
# ========================================
cat("\n=== Manual Review Required ===\n")
cat("Please review Survey_Structure.xlsx:\n")
cat("  1. Verify all questions detected correctly\n")
cat("  2. Check Variable_Type assignments\n")
cat("  3. Verify all options captured\n")
cat("  4. Add/edit options as needed\n")
cat("\nPress Enter when ready to continue...")
readline()

# ========================================
# STEP 3: Run Crosstabulation
# ========================================
cat("\n=== Running Crosstabulation ===\n")
turas_load("tabs")

tabs_result <- run_crosstabs(
  config_file = "Tabs_Config.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)

if (!tabs_result$validation$has_errors) {
  cat("✓ Crosstabs completed successfully\n")
  cat("  Output:", tabs_result$output_file, "\n")
} else {
  cat("✗ Crosstabs failed\n")
  print(tabs_result$validation$error_log$errors)
}

# ========================================
# STEP 4: Results Summary
# ========================================
cat("\n=== Analysis Complete ===\n")
cat("Questions processed:", length(tabs_result$all_results), "\n")
cat("Output file:", tabs_result$output_file, "\n")
```

### Step 5: Benefits of Integration

**Consistency:**
- Parser and Tabs use same Survey_Structure format
- No manual transcription errors
- Single source of truth for questionnaire

**Efficiency:**
- Automated structure creation (saves hours)
- Immediate crosstab-ready output
- Reduces setup time by 80%

**Quality:**
- Automatic Variable_Type detection
- Consistent option coding
- Validation at each stage

---

## Common Patterns and Tips

### Pattern 1: Iterative Analysis

```r
# Start with high-level analysis
config$banner_questions <- c("Total", "Gender")
result1 <- run_crosstabs(...)

# Dive deeper into interesting segments
config$banner_questions <- c("Total", "Gender", "Age_Group", "Region")
result2 <- run_crosstabs(...)

# Analyze specific subgroup
config$stub_questions <- list(
  list(question = "Q05", filter = "Gender == 'Male' & Age_Group == '18-34'")
)
result3 <- run_crosstabs(...)
```

### Pattern 2: Comparative Analysis

```r
# Compare two time periods
config1 <- config
config1$data_file <- "survey_wave1.csv"
config1$output_file <- "Results_Wave1.xlsx"
result_w1 <- run_crosstabs(config1, ...)

config2 <- config
config2$data_file <- "survey_wave2.csv"
config2$output_file <- "Results_Wave2.xlsx"
result_w2 <- run_crosstabs(config2, ...)

# Manually compare results in Excel
# (Or use Turas Tracker module for automated tracking!)
```

### Pattern 3: Exploratory Analysis

```r
# Quick exploration without configuration file
quick_crosstab <- function(question_col, banner_col, data) {

  # Create minimal structure
  structure <- create_minimal_structure(question_col, banner_col, data)

  # Create minimal config
  config <- list(
    show_significance = FALSE,
    decimal_places = 0
  )

  # Run analysis
  result <- quick_tabs(data, structure, config)

  # Print to console
  print(result$table)
}

# Use for quick checks
quick_crosstab("Brand_Preference", "Gender", data)
```

### Pattern 4: Automated Reporting

```r
# Generate crosstabs for weekly report
library(lubridate)

week_num <- week(Sys.Date())

result <- run_crosstabs(
  config_file = "Weekly_Report_Config.xlsx",
  data_file = paste0("data_week_", week_num, ".csv"),
  output_file = paste0("Weekly_Report_Week_", week_num, ".xlsx")
)

# Email results (using blastula package)
library(blastula)

email <- compose_email(
  body = md(paste0(
    "# Weekly Report - Week ", week_num, "\n\n",
    "Analysis complete. ", length(result$all_results), " questions processed.\n\n",
    "See attached Excel file for full results."
  ))
) %>%
  add_attachment(result$output_file)

email %>%
  smtp_send(
    to = "team@company.com",
    from = "analytics@company.com",
    subject = paste0("Weekly Report - Week ", week_num),
    credentials = creds_file("email_creds")
  )
```

---

## Troubleshooting Common Issues

### Issue: No Significant Differences Detected

**Possible Causes:**
1. Sample sizes too small (low statistical power)
2. Differences genuinely not significant
3. Significance level too strict (0.05 → try 0.10)
4. Wrong statistical test (chi-square for ratings → use t-test)

**Solutions:**
```r
# Check base sizes
View(result$all_results[[1]]$bases)  # Need 50+ per column

# Try more liberal significance level
config$significance_level <- 0.10

# Use appropriate test
config$stat_test <- "t-test"  # For averages
config$stat_test <- "z-test"  # For proportions
config$stat_test <- "chi-square"  # For categorical
```

### Issue: Excel File Won't Open

**Possible Causes:**
1. File path too long (Windows 260-character limit)
2. Special characters in output filename
3. Excel file already open
4. Insufficient disk space

**Solutions:**
```r
# Use shorter path
config$output_file <- "Results.xlsx"  # Not "Very_Long_Descriptive_Filename.xlsx"

# Close Excel before running
# Ensure sufficient disk space (>100 MB free)
```

### Issue: Wrong Base Sizes

**Possible Causes:**
1. Filter not applied correctly
2. Missing data treated incorrectly
3. Weight column issue

**Solutions:**
```r
# Check filter syntax
config$stub_questions[[1]]$filter  # Verify syntax

# Check for NAs
summary(data$question_col)  # Count NAs

# Verify weight column
summary(data[[config$weight_column]])  # Check weights
```

---

## Next Steps

**After completing these workflows, you should:**

1. **Customize configurations** for your specific needs
2. **Create templates** for recurring analyses
3. **Build libraries** of common filters and segments
4. **Integrate** with other Turas modules (Parser, Tracker)
5. **Automate** routine reporting workflows

**Additional Resources:**
- USER_MANUAL.md - Complete feature reference
- TECHNICAL_DOCUMENTATION.md - Developer guide
- QUICK_START.md - 10-minute introduction

---

**Document Version:** 1.0
**Last Updated:** 2025-11-18
