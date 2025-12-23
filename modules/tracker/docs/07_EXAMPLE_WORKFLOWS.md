# Turas Tracker - Example Workflows

**Version:** 10.0
**Last Updated:** 22 December 2025

This document provides practical examples and step-by-step workflows for common tracking scenarios.

---

## Table of Contents

1. [Quick Start: Basic 3-Wave Tracking](#workflow-1-basic-3-wave-tracking)
2. [Tracking with Custom Metrics](#workflow-2-tracking-with-custom-metrics)
3. [Multi_Mention Questions](#workflow-3-multi_mention-questions)
4. [Banner Analysis](#workflow-4-banner-analysis)
5. [Composite Questions](#workflow-5-composite-questions)
6. [Handling Question Code Changes](#workflow-6-handling-question-code-changes)
7. [Multiple Report Types](#workflow-7-multiple-report-types)
8. [Troubleshooting Common Issues](#troubleshooting-guide)

---

## Workflow 1: Basic 3-Wave Tracking

**Scenario:** Track brand metrics across 3 quarterly waves.

### Step 1: Organize Files

```
project/
├── data/
│   ├── wave1_q1.csv
│   ├── wave2_q2.csv
│   └── wave3_q3.csv
└── config/
    └── tracking_config.xlsx
```

### Step 2: Create Configuration

**tracking_config.xlsx - Waves sheet:**
```
WaveID | WaveName | DataFile       | WeightVar
W1     | Q1 2024  | wave1_q1.csv   | Weight
W2     | Q2 2024  | wave2_q2.csv   | Weight
W3     | Q3 2024  | wave3_q3.csv   | Weight
```

**Settings sheet:**
```
SettingName      | SettingValue
project_name     | Brand Tracking Q3 2024
report_types     | detailed
confidence_level | 0.95
```

**TrackedQuestions sheet:**
```
QuestionCode | QuestionText              | QuestionType
Q01          | Brand awareness           | Single_Response
Q02          | Overall satisfaction      | Rating
Q03          | NPS                       | NPS
```

### Step 3: Run Analysis

```r
source("modules/tracker/run_tracker.R")

result <- run_tracker(
  tracking_config_path = "config/tracking_config.xlsx",
  question_mapping_path = NA,
  data_dir = "data/"
)
```

### Expected Output

**Summary sheet shows:**
```
Question               | Q1 2024 | Q2 2024 | Q3 2024 | Trend
Brand awareness (Yes)  | 45%     | 48%     | 52%     | ↑
Overall satisfaction   | 7.8     | 8.0     | 8.2     | ↑
NPS                    | +32     | +35     | +38     | →
```

---

## Workflow 2: Tracking with Custom Metrics

**Scenario:** Track both mean satisfaction AND percentage highly satisfied.

### Step 1: Create Question Mapping

**question_mapping.xlsx - QuestionMap sheet:**
```
QuestionCode | QuestionType | TrackingSpecs       | W1  | W2  | W3
Q_SAT        | Rating       | mean,top2_box       | Q10 | Q10 | Q10
Q_SERVICE    | Rating       | mean,top_box,range:4-5 | Q11 | Q11 | Q11
Q_NPS        | NPS          | nps_score,promoters_pct | Q20 | Q20 | Q20
```

### Step 2: Run Analysis

```r
result <- run_tracker(
  tracking_config_path = "config/tracking_config.xlsx",
  question_mapping_path = "config/question_mapping.xlsx",
  data_dir = "data/"
)
```

### Expected Output

**Q_SAT sheet shows:**
```
Metric          | W1   | W2   | W3   | Trend
Mean            | 8.2  | 8.4  | 8.6  | ↑
Top 2 Box %     | 67   | 70   | 73   | →
Sample Size     | 500  | 500  | 500  |
```

**Q_NPS sheet shows:**
```
Metric          | W1   | W2   | W3   | Trend
NPS Score       | +32  | +35  | +38  | →
Promoters %     | 45   | 48   | 50   | →
Sample Size     | 500  | 500  | 500  |
```

---

## Workflow 3: Multi_Mention Questions

Multi_Mention questions (select all that apply) support two tracking modes.

### Mode A: Binary Data (0/1 values)

**Data format:**
```
RespondentID | Q30_1 | Q30_2 | Q30_3 | Q30_4
1            | 1     | 0     | 1     | 0
2            | 0     | 1     | 0     | 1
3            | 1     | 1     | 0     | 0
```

**Configuration - Track all options:**
```
QuestionCode | QuestionType  | TrackingSpecs
Q30          | Multi_Mention | auto
```

**Configuration - Track specific options only:**
```
QuestionCode | QuestionType  | TrackingSpecs
Q30          | Multi_Mention | option:Q30_1,option:Q30_3
```

**Output:**
```
Q30: Features Used

Option      | W1   | W2   | W3   | Trend
Q30_1       | 65%  | 68%  | 72%  | →
Q30_2       | 80%  | 82%  | 85%  | →
Q30_3       | 45%  | 48%  | 50%  | →
Q30_4       | 30%  | 28%  | 25%  | →
```

### Mode B: Category Text Data

**Data format:**
```
RespondentID | Q10_1              | Q10_2          | Q10_3
1            | We rely on CCS     | Personal records|
2            | Internal system    |                | Other
3            | We rely on CCS     | Other          |
```

**Configuration:**
```
QuestionCode | QuestionType  | TrackingSpecs
Q10          | Multi_Mention | category:We rely on CCS,category:Personal records,category:Other
```

**Important:** Text must match EXACTLY (case-insensitive, but spelling/punctuation must match).

**Output:**
```
Q10: Tracking Method

Category           | W1   | W2   | W3   | Trend
We rely on CCS     | 67%  | 65%  | 60%  | →
Personal records   | 33%  | 35%  | 40%  | →
Other              | 33%  | 30%  | 28%  | →
```

### Quick Decision Guide

**Use Binary Mode (`option:` or `auto`) when:**
- Data has 0/1 values
- Each column represents a fixed option
- Want to track which options were selected

**Use Category Mode (`category:`) when:**
- Data has text labels
- Text can appear in any column
- Want to track specific text values regardless of column

---

## Workflow 4: Banner Analysis

**Scenario:** Track brand metrics by demographic segments.

### Step 1: Add Banner Sheet

**tracking_config.xlsx - Banner sheet:**
```
BreakVariable | BreakLabel
Total         | Total
Gender        | Gender
AgeGroup      | Age Group
Region        | Region
```

### Step 2: Ensure Data Has Banner Variables

**Wave data must have columns:**
```
RespondentID | Q10 | Q20 | Gender | AgeGroup | Region | Weight
1            | 8   | 9   | Male   | 18-34    | North  | 1.2
2            | 7   | 8   | Female | 35-54    | South  | 0.9
```

### Step 3: Run with Banners

```r
result <- run_tracker(
  tracking_config_path = "config/tracking_config.xlsx",
  question_mapping_path = "config/question_mapping.xlsx",
  data_dir = "data/",
  use_banners = TRUE
)
```

### Expected Output

**Detailed format - each question sheet shows:**
```
                | W1          | W2          | W3
                | Total | Male | Female | Total | Male | Female | ...
Mean            | 8.2   | 8.0  | 8.4    | 8.4   | 8.2  | 8.6    |
Sample Size     | 500   | 250  | 250    | 500   | 248  | 252    |
```

**Wave History format - one sheet per segment:**
- Sheet: Total
- Sheet: Male
- Sheet: Female
- Sheet: 18-34
- etc.

---

## Workflow 5: Composite Questions

**Scenario:** Create a Customer Experience index from multiple satisfaction questions.

### Step 1: Define Source Questions

**question_mapping.xlsx:**
```
QuestionCode | QuestionType | TrackingSpecs | W1  | W2  | W3  | SourceQuestions
Q_SAT        | Rating       | mean          | Q10 | Q10 | Q10 |
Q_SERVICE    | Rating       | mean          | Q11 | Q11 | Q11 |
Q_VALUE      | Rating       | mean          | Q12 | Q12 | Q12 |
COMP_CX      | Composite    | mean,top2_box | NA  | NA  | NA  | Q_SAT,Q_SERVICE,Q_VALUE
```

### Step 2: How Composite Calculation Works

For each respondent:
1. Extract values for Q_SAT, Q_SERVICE, Q_VALUE
2. Calculate mean of available values
3. Store as COMP_CX score

**Example:**
```
Respondent | Q_SAT | Q_SERVICE | Q_VALUE | COMP_CX
1          | 8     | 7         | 9       | 8.0
2          | 7     | 6         | NA      | 6.5 (mean of 7,6)
3          | 9     | 9         | 9       | 9.0
```

### Step 3: Expected Output

```
COMP_CX: Customer Experience Index

Metric      | W1   | W2   | W3   | Trend
Mean        | 7.8  | 8.0  | 8.2  | ↑
Top 2 Box % | 65   | 68   | 72   | →
```

---

## Workflow 6: Handling Question Code Changes

**Scenario:** Question codes changed between waves due to questionnaire updates.

### Step 1: Document Changes

| Question | Wave 1 Code | Wave 2 Code | Wave 3 Code |
|----------|-------------|-------------|-------------|
| Satisfaction | SAT1 | SATISFACTION | Q04_SAT |
| NPS | NPS_Q | NPS_SCORE | Q05_NPS |

### Step 2: Create Mapping

**question_mapping.xlsx:**
```
QuestionCode | QuestionType | TrackingSpecs | W1   | W2           | W3
Q_SAT        | Rating       | mean,top2_box | SAT1 | SATISFACTION | Q04_SAT
Q_NPS        | NPS          | full          | NPS_Q| NPS_SCORE    | Q05_NPS
```

### Step 3: Verify Data Files

**Wave 1 data columns:** SAT1, NPS_Q, ...
**Wave 2 data columns:** SATISFACTION, NPS_SCORE, ...
**Wave 3 data columns:** Q04_SAT, Q05_NPS, ...

### Expected Result

Tracker automatically maps codes across waves and produces unified output:
```
Q_SAT: Satisfaction

Metric  | Wave 1 | Wave 2 | Wave 3 | Trend
Mean    | 7.8    | 8.0    | 8.2    | ↑
```

---

## Workflow 7: Multiple Report Types

**Scenario:** Generate both detailed analysis and executive summary.

### Step 1: Configure Report Types

**Settings sheet:**
```
SettingName   | SettingValue
report_types  | detailed,wave_history,dashboard
```

### Step 2: Run Analysis

```r
result <- run_tracker(
  tracking_config_path = "config/tracking_config.xlsx",
  question_mapping_path = "config/question_mapping.xlsx",
  data_dir = "data/"
)

# Result is a named list with paths to each file
print(result)
# $detailed = "/path/to/Project_Tracker_20251222.xlsx"
# $wave_history = "/path/to/Project_WaveHistory_20251222.xlsx"
# $dashboard = "/path/to/Project_Dashboard_20251222.xlsx"
```

### Output Files

**Detailed report:** Full statistical analysis, one sheet per question

**Wave History report:** Compact summary, all metrics on one sheet

**Dashboard report:** Executive summary with status indicators

---

## Troubleshooting Guide

### Issue: "Question Q10 not found in Wave 2"

**Cause:** Question code doesn't match column name in wave data.

**Solutions:**
1. Check spelling and capitalization (case-sensitive)
2. Open wave data file and verify column name
3. Use question_mapping.xlsx if codes changed

### Issue: "All values are non-numeric (converted to NA)"

**Cause:** Multi_Mention question has text data but using binary mode.

**Solution:** Use `category:` syntax instead of `auto` or `option:`

**Wrong:**
```
Q10 | Multi_Mention | auto
```

**Correct:**
```
Q10 | Multi_Mention | category:Option A,category:Option B
```

### Issue: Question appears but values are blank

**Cause:** TrackingSpecs text doesn't match data text exactly.

**Solution:** Copy text EXACTLY from data file.

**Data contains:** `"Internal store system (e.g merchandiser)"`
**TrackingSpecs must be:** `category:Internal store system (e.g merchandiser)`

### Issue: Significance always shows "stable" (→)

**Possible causes:**
1. Base sizes too small (< min_base_size)
2. Changes too small relative to variance
3. Alpha level too strict

**Solutions:**
1. Check sample sizes in output
2. Lower min_base_size setting (but not below 20)
3. Consider using 90% confidence instead of 95%

### Issue: Large DEFF warning

**Cause:** Weights have high variance, reducing effective sample size.

**Impact:** Significance tests use smaller effective n.

**Solutions:**
1. Review weighting scheme
2. Report effective N alongside raw N
3. Consider weight trimming
4. Accept reduced power for significance tests

### Issue: Composite shows NA for all waves

**Cause:** SourceQuestions not found or all source values are NA.

**Solutions:**
1. Verify SourceQuestions codes match other QuestionCode values
2. Check that source questions are Rating type
3. Verify source questions have values in data

---

## Template Quick Reference

### Binary Mode Multi_Mention
```
QuestionCode | QuestionType  | TrackingSpecs
Q##          | Multi_Mention | auto
Q##          | Multi_Mention | option:Q##_1,option:Q##_4
```

### Category Mode Multi_Mention
```
QuestionCode | QuestionType  | TrackingSpecs
Q##          | Multi_Mention | category:Text Value 1,category:Text Value 2
```

### Rating with Multiple Metrics
```
QuestionCode | QuestionType | TrackingSpecs
Q##          | Rating       | mean,top2_box,range:9-10
```

### Composite Question
```
QuestionCode | QuestionType | TrackingSpecs | Wave cols | SourceQuestions
COMP_XX      | Composite    | mean,top2_box | NA | NA   | Q_A,Q_B,Q_C
```

---

## Additional Resources

- [04_USER_MANUAL.md](04_USER_MANUAL.md) - Complete user guide
- [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Template field reference
- [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Statistical methods reference
