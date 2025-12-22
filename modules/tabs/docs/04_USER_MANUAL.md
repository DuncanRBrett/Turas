# Turas Tabs - User Manual

**Version:** 10.0
**Date:** 22 December 2025

This manual walks you through using Turas Tabs from start to finish. By the end, you'll be able to set up and run cross-tabulation analyses on your survey data.

---

## Before You Start

### What You'll Need

1. **R installed** on your computer (version 4.0 or higher recommended)
2. **Turas** downloaded and accessible
3. **Your survey data** in Excel (.xlsx), CSV, or SPSS (.sav) format
4. **Template files** from the `templates/` folder in this documentation

### Installing Required Packages

Open R and run:

```r
install.packages(c("openxlsx", "readxl"))
```

If you're working with SPSS files or large CSV files, also install:

```r
install.packages(c("haven", "data.table"))
```

---

## Step 1: Prepare Your Survey Structure

The Survey Structure file defines your survey questions and response options. This is the master reference that Tabs uses to understand your data.

### Create the Questions Sheet

Open `Survey_Structure_Template.xlsx` from the templates folder. Go to the Questions sheet.

For each question in your survey, add a row with:

| Column | What to Enter |
|--------|---------------|
| QuestionCode | The column name in your data file (e.g., Q01, Gender, Satisfaction) |
| QuestionText | The question wording as you want it to appear in output |
| Variable_Type | The question type (see below) |
| Columns | Number of data columns (1 for most questions, more for multi-mention) |

**Variable_Type options:**
- `Single_Mention` - Pick one answer
- `Multi_Mention` - Pick multiple answers
- `Rating` - Numeric scale (1-5, 1-10, etc.)
- `Likert` - Agreement scale with index weights
- `NPS` - Net Promoter Score (0-10)
- `Ranking` - Rank items in order
- `Numeric` - Open numeric response
- `Open_End` - Text response (not analyzed in Tabs)

**Example Questions sheet:**

| QuestionCode | QuestionText | Variable_Type | Columns |
|--------------|--------------|---------------|---------|
| Q01 | Overall satisfaction with our service | Rating | 1 |
| Q02 | Which features do you use? | Multi_Mention | 5 |
| Q03 | Gender | Single_Mention | 1 |
| Q04 | Age group | Single_Mention | 1 |
| Q05 | Likelihood to recommend | NPS | 1 |

### Create the Options Sheet

For each question, list all possible response options.

| Column | What to Enter |
|--------|---------------|
| QuestionCode | The question code (must match Questions sheet) |
| OptionText | The value as it appears in your data |
| DisplayText | The label you want shown in output |
| ShowInOutput | Y to include this option in output, blank to exclude |
| DisplayOrder | Numeric order for display (1, 2, 3...) |

**Example Options sheet:**

| QuestionCode | OptionText | DisplayText | ShowInOutput | DisplayOrder |
|--------------|------------|-------------|--------------|--------------|
| Q01 | 1 | Very dissatisfied | Y | 1 |
| Q01 | 2 | Dissatisfied | Y | 2 |
| Q01 | 3 | Neutral | Y | 3 |
| Q01 | 4 | Satisfied | Y | 4 |
| Q01 | 5 | Very satisfied | Y | 5 |
| Q03 | 1 | Male | Y | 1 |
| Q03 | 2 | Female | Y | 2 |
| Q04 | 1 | 18-34 | Y | 1 |
| Q04 | 2 | 35-54 | Y | 2 |
| Q04 | 3 | 55+ | Y | 3 |

**Important:** The OptionText must exactly match what's in your data file. If your data has "1" for Male, enter "1" as OptionText, not "Male".

### For Multi-Mention Questions

Multi-mention questions need special handling. In the Questions sheet, list the root code and the number of columns:

| QuestionCode | QuestionText | Variable_Type | Columns |
|--------------|--------------|---------------|---------|
| Q02 | Which features do you use? | Multi_Mention | 5 |

In the Options sheet, list options for the first column (Q02_1):

| QuestionCode | OptionText | DisplayText | ShowInOutput |
|--------------|------------|-------------|--------------|
| Q02_1 | Feature A | Feature A | Y |
| Q02_1 | Feature B | Feature B | Y |
| Q02_1 | Feature C | Feature C | Y |

Your data file should have columns Q02_1, Q02_2, Q02_3, Q02_4, Q02_5.

### Save the Survey Structure

Save the file with a meaningful name like `Survey_Structure.xlsx` in your project folder.

---

## Step 2: Configure Your Analysis

The Tabs Config file tells Tabs what analysis to run.

### Create the Settings Sheet

Open `Crosstab_Config_Template.xlsx` from the templates folder. Go to the Settings sheet.

Essential settings to configure:

| Setting | Value |
|---------|-------|
| structure_file | Path to your Survey_Structure file |
| output_subfolder | Folder for output (e.g., Crosstabs) |
| output_filename | Output file name (e.g., Results.xlsx) |
| apply_weighting | TRUE if you have weights, FALSE if not |
| weight_variable | Your weight column name (or - if not using) |
| show_frequency | TRUE to show counts, FALSE for percentages only |
| show_percent_column | TRUE to show percentages |
| enable_significance_testing | TRUE to test significance |
| alpha | Significance level (typically 0.05 for 95% confidence) |

See the [Template Reference](06_TEMPLATE_REFERENCE.md) for all available settings.

### Create the Selection Sheet

The Selection sheet controls which questions to analyze and which to use as banner columns.

| Column | What to Enter |
|--------|---------------|
| QuestionCode | The question code |
| Include | Y to analyze this question as a stub, N to skip |
| UseBanner | Y to use this question as a banner column |
| BannerLabel | Label for banner column (e.g., "Gender") |
| DisplayOrder | Order for banner columns (1, 2, 3...) |
| CreateIndex | Y to calculate mean/index for this question |
| BaseFilter | Optional filter expression |

**Example Selection sheet:**

| QuestionCode | Include | UseBanner | BannerLabel | DisplayOrder | CreateIndex |
|--------------|---------|-----------|-------------|--------------|-------------|
| Q01 | Y | N | | | Y |
| Q02 | Y | N | | | N |
| Q03 | Y | Y | Gender | 2 | N |
| Q04 | Y | Y | Age | 3 | N |
| Q05 | Y | N | | | N |
| Total | N | Y | Total | 1 | N |

**Tips:**
- Always include a "Total" banner column (it shows all respondents)
- Put Total first in DisplayOrder
- Questions can be both stubs (Include=Y) and banners (UseBanner=Y)

### Save the Config

Save the file as `Tabs_Config.xlsx` in your project folder.

---

## Step 3: Check Your Data File

Before running the analysis, verify your data file:

1. **Column names match:** The column names in your data should match the QuestionCode values in Survey_Structure
2. **Values match:** The response values should match the OptionText values in the Options sheet
3. **Weight column exists:** If using weighting, confirm the weight column exists
4. **No completely empty columns:** Questions with all missing data will cause warnings

### Common Data Issues

**Issue:** Question not found in data
**Fix:** Check that QuestionCode in Survey_Structure matches the column name in your data exactly (case-sensitive)

**Issue:** Option values not matching
**Fix:** Check that OptionText values match your data exactly. If your data has "1" and you entered "Male", change OptionText to "1"

**Issue:** Multi-mention columns not found
**Fix:** Verify your data has columns like Q02_1, Q02_2, etc. and that Columns in Survey_Structure matches the count

---

## Step 4: Run the Analysis

### Using the GUI

The graphical interface is the easiest way to run Tabs:

```r
# Set your working directory to the Turas folder
setwd("path/to/Turas")

# Launch the GUI
source("modules/tabs/run_tabs_gui.R")
```

In the GUI:
1. Click Browse to select your Tabs_Config.xlsx
2. Click Run Analysis
3. Wait for processing to complete
4. The output file opens automatically

### Using R Script

For scripted or batch processing:

```r
# Load Turas and the Tabs module
setwd("path/to/Turas")
source("turas.R")
turas_load("tabs")

# Run analysis
result <- run_tabs_analysis("path/to/your/project")

# Check for errors
if (result$validation$has_errors) {
  print(result$validation$error_log$errors)
} else {
  cat("Success! Output:", result$output_file, "\n")
}
```

### What Happens During Processing

1. Tabs loads your configuration and structure files
2. It validates everything is properly set up
3. It loads your survey data
4. For each stub question:
   - It calculates frequencies and percentages across banner columns
   - It runs significance tests
   - It builds the output table
5. It writes the Excel workbook
6. It returns the results

Processing time depends on your data size. A typical survey (1,000 respondents, 30 questions, 10 banner columns) takes about 10-15 seconds.

---

## Step 5: Review the Output

Open the output Excel file. You'll find several sheets.

### Index_Summary Sheet

If you set CreateIndex=Y for any questions, this sheet shows a summary of all mean/index scores:

| Question | Total | Male | Female | 18-34 | 35-54 | 55+ |
|----------|-------|------|--------|-------|-------|-----|
| Q01 Satisfaction | 3.8 | 4.0 | 3.6 | 3.9 | 3.7 | 3.8 |
| Q05 NPS | 32 | 38 | 26 | 40 | 28 | 30 |

This gives you a quick view of key metrics across all banner columns.

### Question Sheets

Each analyzed question gets its own sheet. The layout includes:

**Base rows at the top:**
```
Base (unweighted)     1000    480    520    350    400    250
Base (weighted)       1000    500    500    380    370    250
Effective N            925    460    465    352    342    231
```

**Response rows in the middle:**
```
Very satisfied        35%     40%C   31%    38%    34%    32%
Satisfied             40%     38%    42%A   39%    42%    38%
Neutral               15%     13%    17%A   14%    15%    18%
Dissatisfied           7%      6%     8%     6%     7%     9%
Very dissatisfied      3%      3%     2%     3%     2%     3%
```

The letters (A, B, C) indicate significance. A value with "C" is significantly higher than column C.

**Summary rows at the bottom (for Rating/NPS questions):**
```
Mean                  3.97    4.06C  3.89   4.01   3.95   3.92
Top 2 Box             75%     78%C   73%    77%    76%    70%
```

### Understanding Significance Letters

Each banner column gets a letter:
- A = first banner column (usually Total)
- B = second column
- C = third column
- And so on...

When you see "40%C" in the Male column, it means 40% for Males is significantly higher than the value in column C (Female).

If a cell has no letter, it's not significantly different from any other column.

---

## Step 6: Troubleshooting

### "Configuration file not found"

Check the file path. Either:
- Use an absolute path: `C:/Projects/Survey/Tabs_Config.xlsx`
- Make sure your working directory is set correctly

### "Question not found in data"

The QuestionCode in Survey_Structure doesn't match any column in your data. Check:
- Spelling (exact match required)
- Case sensitivity (Q01 is different from q01)
- No extra spaces

### "Weight variable not found"

Your weight_variable setting doesn't match a column in your data. Either:
- Correct the weight_variable name in Settings
- Set apply_weighting to FALSE if you don't need weights

### "Base size too small for significance testing"

A banner column has fewer respondents than the minimum_base threshold. Either:
- This is expected (small segments don't get tested)
- Reduce significance_min_base in Settings (not recommended below 20)
- Combine segments to increase base sizes

### "All values are NA"

The question or banner column has no data. Check:
- Your data file for the problematic column
- Whether a filter might be excluding all respondents

### Output file won't open

The file might be locked from a previous run. Close Excel and try again.

---

## Common Tasks

### Adding a New Banner Column

1. Add the question to Survey_Structure (Questions and Options sheets) if not already there
2. In Tabs_Config Selection sheet:
   - Find or add the question row
   - Set UseBanner = Y
   - Set BannerLabel to your desired header
   - Set DisplayOrder (higher numbers appear to the right)

### Filtering a Question

To analyze only a subset of respondents for a specific question:

1. In the Selection sheet, find the question row
2. In the BaseFilter column, enter a filter expression

Example: To analyze Q01 only among purchasers:
```
Q_Purchased == "Yes"
```

Example: To analyze among females aged 18-34:
```
Q_Gender == "Female" & Q_Age %in% c("18-24", "25-34")
```

### Creating a Composite Score

To calculate an average across multiple questions:

1. In Survey_Structure, go to the Composite_Metrics sheet
2. Add a row:

| CompositeCode | CompositeLabel | CalculationType | SourceQuestions |
|---------------|----------------|-----------------|-----------------|
| COMP_SAT | Overall Satisfaction | Mean | Q01,Q02,Q03 |

3. In Tabs_Config Selection sheet, add the composite:

| QuestionCode | Include | CreateIndex |
|--------------|---------|-------------|
| COMP_SAT | Y | Y |

### Running Multiple Configurations

Create separate config files for different analyses:
- `Tabs_Config_Demographics.xlsx` - By gender and age
- `Tabs_Config_Regions.xlsx` - By region
- `Tabs_Config_Segments.xlsx` - By customer segment

Run each one separately to get different output files.

---

## Tips for Better Results

### Configuration

- **Start simple.** Begin with a few questions and banner columns. Add more once basic analysis works.
- **Check a sample first.** Run on a subset of data before processing everything.
- **Use meaningful labels.** BannerLabel values appear in output, so make them clear.

### Data Preparation

- **Clean your data first.** Handle missing values and outliers before running Tabs.
- **Recode to numeric.** Tabs works best when response values are numeric codes.
- **Validate weights.** Check that weight values are reasonable (most between 0.5 and 2.0).

### Output Review

- **Check base sizes.** Small bases produce unreliable percentages.
- **Look at DEFF.** High design effects (>2.0) indicate weighting efficiency issues.
- **Verify significance makes sense.** If nothing is significant, you may have small bases or low variability.

---

## Next Steps

- See [Example Workflows](07_EXAMPLE_WORKFLOWS.md) for complete worked examples
- See [Template Reference](06_TEMPLATE_REFERENCE.md) for detailed field specifications
- See [Reference Guide](03_REFERENCE_GUIDE.md) for in-depth feature explanations
