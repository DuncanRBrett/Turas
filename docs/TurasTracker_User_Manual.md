# TurasTracker - User Manual

**Version:** 10.0
**Document Date:** December 2, 2025
**System:** TURAS Tracking Analysis Module

---

## Table of Contents

1. [Overview](#overview)
2. [What is TurasTracker?](#what-is-turastacker)
3. [When to Use](#when-to-use)
4. [Getting Started](#getting-started)
5. [Configuration Files](#configuration-files)
6. [Running an Analysis](#running-an-analysis)
7. [Understanding the Output](#understanding-the-output)
8. [Advanced Features](#advanced-features)
9. [Troubleshooting](#troubleshooting)
10. [Examples](#examples)

---

## Overview

**TurasTracker** analyzes survey data **across multiple waves** to identify trends, track changes over time, and perform statistical significance testing. While TurasTabs focuses on analyzing a single wave (within-wave crosstabulation), TurasTracker connects the dots across waves to show how metrics evolve.

### Key Capabilities

✅ **Track trends** - Monitor how metrics change from wave to wave
✅ **Calculate changes** - Absolute and percentage change calculations
✅ **Test significance** - Statistical tests to determine if changes are meaningful
✅ **Banner breakouts** - Trends by demographic segments (Gender, Age, Region, etc.)
✅ **Composite scores** - Track derived metrics combining multiple questions
✅ **Excel output** - Professional formatted workbooks ready for stakeholders

---

## What is TurasTracker?

### The Challenge

Survey questions often change position between waves:
- Wave 1: Q10 = "Overall satisfaction"
- Wave 2: Q11 = "Overall satisfaction" (moved)
- Wave 3: Q12 = "Overall satisfaction" (moved again)

**TurasTracker solves this** by mapping questions across waves so you can track the same question even when it moves or is renumbered.

### What It Does

1. **Loads wave data** - Reads CSV or Excel files for each survey wave
2. **Maps questions** - Connects Q10 → Q11 → Q12 as the same metric
3. **Calculates trends** - Computes metrics for each wave (means, NPS, proportions)
4. **Tests significance** - Determines if wave-over-wave changes are statistically significant
5. **Generates output** - Creates formatted Excel workbook with trend tables

---

## When to Use

### ✅ Use TurasTracker When:

- **Tracking studies** - You run the same survey multiple times (quarterly, annually, etc.)
- **Question renumbering** - Question codes change between waves
- **Trend analysis** - You need to see how metrics evolve over time
- **Wave comparison** - You want to know if changes are significant
- **Banner trends** - You need trends broken out by demographics
- **Executive reporting** - You need clean trend tables for stakeholders

### ❌ Do NOT Use TurasTracker When:

- **Single wave analysis** - Use TurasTabs for within-wave crosstabs
- **Real-time tracking** - Tracker is for completed waves, not live data
- **Panel analysis** - MVT doesn't track individual respondents (cross-sectional only)

---

## Getting Started

### Prerequisites

**Software Required:**
- R (version 4.0 or higher)
- RStudio (recommended)
- Required R packages: `openxlsx`

**Install Required Packages:**
```r
install.packages("openxlsx")
```

### Files You Need

**1. Configuration Files:**
- `tracking_config.xlsx` - Defines waves, settings, banner structure
- `question_mapping.xlsx` - Maps questions across waves

**2. Data Files:**
- One CSV or Excel file per wave
- Files contain survey responses

**3. R Script:**
- `run_tracker.R` - Main execution script (provided)

### Directory Structure

```
/MyTrackingProject/
├── tracking_config.xlsx          # Your tracking configuration
├── question_mapping.xlsx          # Your question mapping
├── Data/
│   ├── Wave1_Jan2024.csv         # Wave 1 data
│   ├── Wave2_Apr2024.csv         # Wave 2 data
│   └── Wave3_Jul2024.csv         # Wave 3 data
└── Output/
    └── (Output files will be created here)
```

---

## Configuration Files

### 1. tracking_config.xlsx

**Purpose:** Define your waves, settings, and banner structure

#### Sheet 1: Waves

Defines each wave in your tracking study.

| Column | Required | Example | Description |
|--------|----------|---------|-------------|
| WaveID | Yes | W1 | Short unique identifier |
| WaveName | Yes | Wave 1 - Jan 2024 | Descriptive name |
| DataFile | Yes | Data/Wave1_Jan2024.csv | Path to data file |
| FieldworkStart | No | 2024-01-15 | Start date of fieldwork |
| FieldworkEnd | No | 2024-01-30 | End date of fieldwork |
| WeightVar | No | weight | Weighting variable name |

**Example:**
```
WaveID | WaveName          | DataFile                | FieldworkStart | FieldworkEnd | WeightVar
W1     | Wave 1 - Jan 2024 | Data/Wave1_Jan2024.csv  | 2024-01-15     | 2024-01-30   | weight
W2     | Wave 2 - Apr 2024 | Data/Wave2_Apr2024.csv  | 2024-04-15     | 2024-04-30   | weight
W3     | Wave 3 - Jul 2024 | Data/Wave3_Jul2024.csv  | 2024-07-15     | 2024-07-30   | weight
```

#### Sheet 2: Settings

Configure analysis parameters.

| Setting | Default | Options | Description |
|---------|---------|---------|-------------|
| project_name | Tracking Analysis | Text | Name for output files |
| decimal_places_ratings | 1 | 0-3 | Decimals for means/ratings |
| show_significance | Y | Y/N | Include sig testing |
| alpha | 0.05 | Numeric | Significance level |
| minimum_base | 30 | Numeric | Min sample for sig tests |

**Example:**
```
Setting                  | Value
project_name            | Customer Satisfaction Tracker
decimal_places_ratings  | 1
show_significance       | Y
alpha                   | 0.05
minimum_base            | 30
```

#### Sheet 3: Banner

Define banner breakouts (Total is automatic).

| Column | Required | Example | Description |
|--------|----------|---------|-------------|
| BreakVariable | Yes | Gender | Variable name in data |
| BreakLabel | Yes | Gender | Display label |

**Example:**
```
BreakVariable | BreakLabel
Total         | Total Sample
Gender        | Gender
AgeGroup      | Age Group
Region        | Region
```

**Note:** System will automatically create segments for each unique value (e.g., Gender=1, Gender=2).

#### Sheet 4: TrackedQuestions

List questions to track across waves.

| Column | Required | Example | Description |
|--------|----------|---------|-------------|
| QuestionCode | Yes | Q_SAT | Standard question identifier |

**Example:**
```
QuestionCode
Q_SAT
Q_NPS
Q_VALUE
COMP_OVERALL
```

---

### 2. question_mapping.xlsx

**Purpose:** Map how questions correspond across waves

#### Sheet: QuestionMap

Maps each tracked question to its wave-specific codes.

| Column | Required | Example | Description |
|--------|----------|---------|-------------|
| QuestionCode | Yes | Q_SAT | Standard tracking code |
| QuestionText | Yes | Overall satisfaction | Question wording |
| QuestionType | Yes | Rating | Rating/NPS/SingleChoice/Composite |
| Wave1 | No | Q10 | Question code in Wave 1 data |
| Wave2 | No | Q11 | Question code in Wave 2 data |
| Wave3 | No | Q12 | Question code in Wave 3 data |
| SourceQuestions | No* | Q_SAT,Q_VALUE | Source questions for composites |

*Required for Composite questions only

**Example:**
```
QuestionCode | QuestionText          | QuestionType | Wave1 | Wave2 | Wave3 | SourceQuestions
Q_SAT        | Overall satisfaction  | Rating       | Q10   | Q11   | Q12   |
Q_NPS        | Likelihood to rec.    | NPS          | Q25   | Q26   | Q27   |
Q_VALUE      | Value for money       | Rating       | Q15   | Q16   | Q17   |
COMP_OVERALL | Overall Score         | Composite    | COMP  | COMP  | COMP  | Q_SAT,Q_VALUE
```

**Key Points:**
- Add one column per wave (Wave1, Wave2, Wave3, ...)
- Leave blank if question not asked in that wave
- For composites, use consistent code across waves (e.g., COMP)
- SourceQuestions is comma-separated list

---

## Running an Analysis

### Step 1: Prepare Your Files

1. **Create tracking_config.xlsx** using the template
2. **Create question_mapping.xlsx** using the template
3. **Place wave data files** in accessible location
4. **Update file paths** in tracking_config.xlsx

### Step 2: Open R/RStudio

Navigate to the TurasTracker directory:
```r
setwd("/Users/yourname/Documents/Turas/modules/tracker")
```

### Step 3: Source the Script

Load the tracker functions:
```r
source("run_tracker.R")
```

### Step 4: Run Analysis

**Basic (Total Sample Only):**
```r
output_file <- run_tracker(
  tracking_config_path = "/path/to/tracking_config.xlsx",
  question_mapping_path = "/path/to/question_mapping.xlsx",
  data_dir = "/path/to/data/folder"
)
```

**Advanced (With Banner Breakouts):**
```r
output_file <- run_tracker(
  tracking_config_path = "/path/to/tracking_config.xlsx",
  question_mapping_path = "/path/to/question_mapping.xlsx",
  data_dir = "/path/to/data/folder",
  use_banners = TRUE  # Enable banner breakouts
)
```

**With Custom Output Path:**
```r
output_file <- run_tracker(
  tracking_config_path = "/path/to/tracking_config.xlsx",
  question_mapping_path = "/path/to/question_mapping.xlsx",
  data_dir = "/path/to/data/folder",
  output_path = "/path/to/output/MyTracker_Results.xlsx",
  use_banners = TRUE
)
```

### Step 5: Review Output

The script will display progress messages:
```
[1/6] LOADING CONFIGURATION
[2/6] LOADING QUESTION MAPPING
[3/6] VALIDATING CONFIGURATION
[4/6] LOADING WAVE DATA
[5/6] VALIDATING WAVE DATA
[6/6] RUNNING COMPREHENSIVE VALIDATION
[7/8] CALCULATING TRENDS
[8/8] GENERATING OUTPUT

✓ Output written to: Customer_Satisfaction_Tracker_20251107.xlsx
```

---

## Understanding the Output

The tracker creates an Excel workbook with multiple sheets:

### 1. Summary Sheet

**Purpose:** Overview of waves and sample sizes

**Contains:**
- Project name and metadata
- Wave information table (dates, sample sizes)
- Number of questions tracked
- Generation timestamp

**Example:**
```
TRACKING ANALYSIS SUMMARY
Customer Satisfaction Tracker

Wave Information:
WaveID | Wave Name          | Fieldwork Start | Fieldwork End | Sample Size
W1     | Wave 1 - Jan 2024  | 2024-01-15      | 2024-01-30    | 500
W2     | Wave 2 - Apr 2024  | 2024-04-15      | 2024-04-30    | 520
W3     | Wave 3 - Jul 2024  | 2024-07-15      | 2024-07-30    | 485

Questions Tracked: 4
Generated: 2025-11-07 10:30:00
```

---

### 2. Question Trend Sheets (One Per Question)

**Purpose:** Detailed trend data for each question

#### For Rating Questions:

**Sheet Structure:**
```
Q_SAT
Overall satisfaction

                    W1_Total | W2_Total | W3_Total | W1_Gender_1 | W2_Gender_1 | ...
Mean                7.5      | 7.8      | 8.1      | 7.3         | 7.6         | ...
Sample Size (n)     500      | 520      | 485      | 245         | 258         | ...
```

**Interpretation:**
- **Mean**: Average score (e.g., on 1-10 scale)
- **Sample Size (n)**: Unweighted base
- Columns organized as: WaveID_SegmentName

#### For NPS Questions:

**Sheet Structure:**
```
Q_NPS
Likelihood to recommend

                    W1_Total | W2_Total | W3_Total
NPS Score           12.5     | 18.3     | 22.1
% Promoters (9-10)  35.2     | 38.5     | 41.2
% Passives (7-8)    42.1     | 43.2     | 40.7
% Detractors (0-6)  22.7     | 18.3     | 18.1
Sample Size (n)     500      | 520      | 485
```

**Interpretation:**
- **NPS Score** = % Promoters - % Detractors
- Score ranges from -100 (all detractors) to +100 (all promoters)
- Positive NPS = more promoters than detractors

#### For Composite Questions:

**Sheet Structure:**
```
COMP_OVERALL
Overall Score (Composite of Q_SAT, Q_VALUE)

                    W1_Total | W2_Total | W3_Total
Mean                7.2      | 7.5      | 7.8
Sample Size (n)     500      | 520      | 485
```

**Interpretation:**
- Mean of source questions (Q_SAT and Q_VALUE)
- Calculated at respondent level, then averaged
- Missing values handled: requires at least one source question

---

### 3. Change Summary Sheet

**Purpose:** Quick view of all changes from baseline to latest wave

**Sheet Structure:**
```
CHANGE SUMMARY - BASELINE COMPARISON

Question             | Metric    | Baseline (W1) | Latest (W3) | Absolute Change | % Change
Overall satisfaction | mean      | 7.5           | 8.1         | +0.6           | +8.0%
NPS                  | nps       | 12.5          | 22.1        | +9.6           | +76.8%
Value for money      | mean      | 7.0           | 7.3         | +0.3           | +4.3%
Overall Score        | composite | 7.2           | 7.8         | +0.6           | +8.3%
```

**Interpretation:**
- **Baseline**: First wave (W1)
- **Latest**: Last wave (W3)
- **Absolute Change**: Latest - Baseline
- **% Change**: (Absolute / Baseline) × 100
- Positive numbers (green) = improvement
- Negative numbers (red) = decline

---

### 4. Metadata Sheet

**Purpose:** Configuration snapshot for reproducibility

**Contains:**
- Analysis settings used
- Data file paths
- Configuration values

---

## Advanced Features

### Banner Breakouts

**What are they?**
Trends broken out by demographic segments (Gender, Age, Region, etc.)

**How to enable:**
1. Add banner variables to Banner sheet in tracking_config.xlsx
2. Ensure variables exist in all wave data files
3. Run with `use_banners = TRUE`

**Output format:**
```
Metric | W1_Total | W2_Total | W1_Male | W2_Male | W1_Female | W2_Female
Mean   | 7.5      | 7.8      | 7.3     | 7.6     | 7.7       | 8.0
```

**Use cases:**
- Compare trends across demographics
- Identify which segments are driving overall changes
- Spot diverging trends (e.g., improving in one group, declining in another)

---

### Composite Scores

**What are they?**
Derived metrics combining multiple questions (e.g., Overall Satisfaction = mean of Q_SAT and Q_VALUE)

**How to create:**

1. **In question_mapping.xlsx:**
```
QuestionCode | QuestionText    | QuestionType | Wave1 | Wave2 | SourceQuestions
COMP_SAT     | Overall Score   | Composite    | COMP  | COMP  | Q_SAT,Q_VALUE
```

2. **Add to TrackedQuestions** in tracking_config.xlsx
3. **Run analysis** - composite calculated automatically

**Calculation:**
```
For each respondent:
  COMP_SAT = mean(Q_SAT, Q_VALUE)

For each wave:
  Overall mean = weighted mean of respondent COMP_SAT values
```

**Use cases:**
- Executive summary metrics
- Holistic scores combining related questions
- Index creation (e.g., Brand Health Index)

---

### Significance Testing

**What is it?**
Statistical tests to determine if wave-over-wave changes are meaningful or just random variation.

**Methods:**
- **T-tests** for rating/mean comparisons
- **Z-tests** for proportion comparisons
- **Two-tailed tests** at configured alpha level (default 0.05)

**When shown:**
- Both waves have sufficient base (default: n ≥ 30)
- No missing data for comparison

**Interpretation:**
- **Significant = Yes**: Change is statistically meaningful (95% confident it's not random)
- **Significant = No**: Change could be due to random variation

**In output:**
```
Wave-over-Wave Changes:
Comparison | Absolute Change | % Change | Significant
W1 → W2    | +0.3           | +4.0%    | Yes
W2 → W3    | +0.2           | +2.6%    | No
```

---

## Troubleshooting

### Issue: "Configuration file not found"

**Cause:** Incorrect file path

**Solution:**
```r
# Use absolute paths or check working directory
getwd()  # Check current directory
setwd("/correct/path")  # Change if needed

# Or use full path
run_tracker(
  tracking_config_path = "/Users/name/Documents/tracking_config.xlsx",
  ...
)
```

---

### Issue: "Missing required columns in Waves sheet"

**Cause:** tracking_config.xlsx missing required columns

**Solution:**
Ensure Waves sheet has: WaveID, WaveName, DataFile, FieldworkStart, FieldworkEnd

---

### Issue: "Data file not found for Wave W1"

**Cause:** Incorrect data file path in tracking_config.xlsx

**Solution:**
1. Check DataFile column in Waves sheet
2. Use paths relative to data_dir parameter:
```r
# If data_dir = "/path/to/data"
# Then DataFile should be just: "Wave1.csv"

run_tracker(
  ...,
  data_dir = "/path/to/data"  # Don't include filename here
)
```

---

### Issue: "Weight variable 'weight' not found"

**Cause:** Specified weight variable doesn't exist in data

**Solution:**
1. Check WeightVar column in Waves sheet
2. Verify variable exists in CSV/Excel data
3. Case-sensitive: "Weight" ≠ "weight"

**Or remove weighting:**
Set WeightVar to blank (system will use weight=1 for all)

---

### Issue: "Question 'Q10' not found in Wave W2 data"

**Cause:** Question code in mapping doesn't match data file

**Solution:**
1. Open Wave W2 data file
2. Check actual column name
3. Update question_mapping.xlsx Wave2 column

---

### Issue: "No tracked questions available across all waves"

**Cause:** Questions don't exist in all waves or mapping is incorrect

**Solution:**
1. Check question_mapping.xlsx for blank cells
2. Verify questions exist in data files
3. It's OK if some questions missing in some waves - they'll show as N/A

---

### Issue: "Trends calculated for 0 segments" (for composite)

**Cause:** SourceQuestions not defined or source questions missing

**Solution:**
1. Verify SourceQuestions column exists in question_mapping.xlsx
2. Ensure source questions are comma-separated: "Q_SAT,Q_VALUE"
3. Verify source questions exist in tracked questions

---

### Issue: Output values seem wrong

**Check:**
1. **Weighting** - Are weights applied correctly?
2. **Question scale** - NPS should be 0-10, ratings as expected
3. **Sample sizes** - Are bases reasonable?
4. **Filtering** - Are banner segments filtering correctly?

**Debug:**
```r
# Load and inspect data
wave_data <- read.csv("Data/Wave1.csv")
summary(wave_data$Q10)  # Check distribution
table(wave_data$Gender)  # Check banner segments
```

---

## Examples

### Example 1: Simple 2-Wave Tracker (Total Only)

**Scenario:** Track 3 key metrics across 2 waves, no banner breakouts

**tracking_config.xlsx - Waves:**
```
WaveID | WaveName    | DataFile     | FieldworkStart | FieldworkEnd | WeightVar
W1     | Baseline    | wave1.csv    | 2024-01-15     | 2024-01-30   | weight
W2     | Follow-up   | wave2.csv    | 2024-04-15     | 2024-04-30   | weight
```

**tracking_config.xlsx - Settings:**
```
Setting                 | Value
project_name           | Simple Tracker
decimal_places_ratings | 1
show_significance      | Y
alpha                  | 0.05
minimum_base           | 30
```

**tracking_config.xlsx - Banner:**
```
BreakVariable | BreakLabel
Total         | Total Sample
```

**tracking_config.xlsx - TrackedQuestions:**
```
QuestionCode
Q_SAT
Q_NPS
Q_VALUE
```

**question_mapping.xlsx:**
```
QuestionCode | QuestionText          | QuestionType | Wave1 | Wave2
Q_SAT        | Overall satisfaction  | Rating       | Q10   | Q10
Q_NPS        | Likelihood to rec.    | NPS          | Q25   | Q25
Q_VALUE      | Value for money       | Rating       | Q15   | Q15
```

**Run:**
```r
setwd("/path/to/tracker")
source("run_tracker.R")

output_file <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = "question_mapping.xlsx",
  data_dir = "."
)
```

**Output:**
- Summary sheet
- Q_SAT sheet (1 column per wave)
- Q_NPS sheet (1 column per wave)
- Q_VALUE sheet (1 column per wave)
- Change_Summary sheet
- Metadata sheet

---

### Example 2: Multi-Wave Tracker with Banners

**Scenario:** Track 4 metrics across 4 waves, broken out by Gender and Age

**tracking_config.xlsx - Banner:**
```
BreakVariable | BreakLabel
Total         | Total Sample
Gender        | Gender
AgeGroup      | Age Group
```

**Run:**
```r
output_file <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = "question_mapping.xlsx",
  data_dir = "Data",
  use_banners = TRUE  # Enable banner breakouts
)
```

**Output - Q_SAT Sheet:**
```
Metric | W1_Total | W2_Total | W1_Gender_1 | W2_Gender_1 | W1_Gender_2 | W2_Gender_2 | ...
Mean   | 7.5      | 7.8      | 7.3         | 7.6         | 7.7         | 8.0         | ...
```

---

### Example 3: Tracker with Composites

**Scenario:** Track individual questions plus composite score

**question_mapping.xlsx:**
```
QuestionCode | QuestionText         | QuestionType | Wave1 | Wave2 | SourceQuestions
Q_SAT        | Overall satisfaction | Rating       | Q10   | Q11   |
Q_VALUE      | Value for money      | Rating       | Q15   | Q16   |
COMP_OVERALL | Overall Score        | Composite    | COMP  | COMP  | Q_SAT,Q_VALUE
```

**Output:**
- Separate sheet for COMP_OVERALL showing composite trend
- Composite calculated as mean of Q_SAT and Q_VALUE

---

### Example 4: Handling Question Renumbering

**Scenario:** Question moves position across waves

**question_mapping.xlsx:**
```
QuestionCode | QuestionText          | QuestionType | Wave1 | Wave2 | Wave3 | Wave4
Q_SAT        | Overall satisfaction  | Rating       | Q10   | Q11   | Q12   | Q15
```

**Interpretation:**
- Wave 1: Find satisfaction score in column Q10
- Wave 2: Find satisfaction score in column Q11 (moved)
- Wave 3: Find satisfaction score in column Q12 (moved again)
- Wave 4: Find satisfaction score in column Q15 (moved again)

Tracker handles this automatically - you see one continuous trend.

---

### Example 5: Question Not Asked in Some Waves

**Scenario:** Question added in Wave 2, not in Wave 1

**question_mapping.xlsx:**
```
QuestionCode | QuestionText      | QuestionType | Wave1 | Wave2 | Wave3
Q_NEW        | New metric added  | Rating       |       | Q20   | Q21
```

**Output:**
```
Metric | W1_Total | W2_Total | W3_Total
Mean   | N/A      | 7.5      | 7.8
```

Wave 1 shows N/A (question wasn't asked)

---

## Data File Requirements

### Format

**Supported:**
- CSV (.csv)
- Excel (.xlsx, .xls)

**Structure:**
- One row per respondent
- One column per question
- Column names = question codes

### Example Wave Data (CSV):

```
respondent_id,Q10,Q15,Q25,Gender,AgeGroup,weight
1,8,7,9,1,1,1.05
2,7,6,8,2,2,0.95
3,9,8,10,1,1,1.10
...
```

**Requirements:**
- Question columns (Q10, Q15, Q25) must match question_mapping.xlsx
- Banner variables (Gender, AgeGroup) must match tracking_config.xlsx Banner sheet
- Weight variable (weight) must match WeightVar in Waves sheet
- Numeric values for ratings, NPS, etc.

---

## Best Practices

### Configuration

✅ **Use consistent naming** - Stick to a naming convention (e.g., W1, W2, W3)
✅ **Document changes** - Note when questions moved or changed in question_mapping
✅ **Test with 2 waves first** - Validate setup before adding more waves
✅ **Keep templates** - Save blank templates for future tracking projects

### Data Preparation

✅ **Standardize scales** - Ensure same scale across waves (1-10, 0-10, etc.)
✅ **Consistent coding** - Gender=1/2 should mean same thing across waves
✅ **Clean data first** - Remove duplicates, handle missing values
✅ **Weight calculation** - Apply weights in data file before tracking

### Analysis

✅ **Review validation output** - Check for warnings before trusting results
✅ **Verify base sizes** - Ensure sufficient sample in each wave/segment
✅ **Check for outliers** - Unusual spikes may indicate data issues
✅ **Document assumptions** - Note any data cleaning or filters applied

---

## Support and Resources

### Documentation

- **This Manual** - End-user guide
- **Maintenance Guide** - Developer/technical documentation
- **Shared Code Refactoring Plan** - Future enhancements roadmap

### Templates

- `tracking_config_template.xlsx` - Configuration template
- `question_mapping_template.xlsx` - Question mapping template
- `wave_data_template.csv` - Data file example

### Getting Help

**Before contacting support:**
1. Check Troubleshooting section
2. Review validation messages carefully
3. Test with example data

**When requesting support, provide:**
- tracking_config.xlsx and question_mapping.xlsx
- Validation output (copy/paste console messages)
- Error messages (complete text)
- Description of expected vs. actual results

---

## Version History

**Version 10.0 (December 2025)**
- ✅ Multi-wave tracking
- ✅ Question mapping across waves
- ✅ Trend calculation (Rating, NPS, SingleChoice)
- ✅ Wave-over-wave changes
- ✅ Significance testing (t-tests, z-tests)
- ✅ Banner breakouts
- ✅ Composite scores
- ✅ Change summary
- ✅ Excel output

**Future Enhancements (Planned):**
- Panel data tracking (same respondents over time)
- Attrition analysis
- Trend forecasting
- Dashboard exports (CSV/JSON)
- Multi-mention question tracking

---

**Document Version:** 1.0
**Last Updated:** November 2025
**Module Version:** TurasTracker MVT 1.0
**Status:** Production Ready
