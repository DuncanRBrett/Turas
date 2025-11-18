# Turas Tabs - Quick Start Guide

**Version:** 1.0
**Estimated Time:** 10-15 minutes
**Difficulty:** Beginner to Intermediate

---

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
