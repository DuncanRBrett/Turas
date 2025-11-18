# Turas Tracker - Quick Start Guide

**Version:** 1.0
**Estimated Time:** 15 minutes
**Difficulty:** Intermediate

---

## What is Turas Tracker?

Turas Tracker analyzes multi-wave tracking studies by:
- **Comparing metrics across waves** (time series analysis)
- **Calculating trends** (up/down/stable with statistical significance)
- **Handling question mapping** (track questions even when wording/codes change)
- **Supporting banner analysis** (trends by demographic segments)
- **Generating professional Excel reports** with trend tables and charts

---

## Prerequisites

```r
install.packages(c("openxlsx", "readxl"))
```

### What You Need

1. **Multiple wave data files** (one file per wave)
   - Wave 1, Wave 2, Wave 3, etc.
   - Same questions across waves (or mapping provided)

2. **Tracking configuration file** (.xlsx)
   - Which questions to track
   - Wave information (IDs, labels, dates)
   - Analysis settings

3. **Question mapping file** (.xlsx, optional)
   - Maps question codes across waves if they changed

---

## Quick Start (10 Minutes)

### Step 1: Organize Your Wave Data

**Directory structure:**
```
project/
├── wave1_data.xlsx    # Wave 1 (Jan 2024)
├── wave2_data.xlsx    # Wave 2 (Apr 2024)
├── wave3_data.xlsx    # Wave 3 (Jul 2024)
└── config/
    ├── tracking_config.xlsx
    └── question_mapping.xlsx
```

**Each wave file should have:**
```
ResponseID | Q1_Awareness | Q2_Consideration | Q3_Purchase | Q4_Satisfaction | Weight
1          | 1            | 1                | 0           | 4               | 1.2
2          | 1            | 0                | 0           | 5               | 0.9
3          | 0            | 0                | 0           | 3               | 1.1
```

### Step 2: Create Configuration File

**tracking_config.xlsx - Sheet 1: Waves**
```
WaveID | WaveLabel    | DataFile         | FieldingDate | WeightVariable
W1     | Jan 2024     | wave1_data.xlsx  | 2024-01-15   | Weight
W2     | Apr 2024     | wave2_data.xlsx  | 2024-04-15   | Weight
W3     | Jul 2024     | wave3_data.xlsx  | 2024-07-15   | Weight
```

**Sheet 2: Questions**
```
QuestionCode    | QuestionText                  | QuestionType
Q1_Awareness    | Brand awareness (unaided)     | proportion
Q2_Consideration| Brand consideration           | proportion
Q3_Purchase     | Purchased in last 3 months    | proportion
Q4_Satisfaction | Satisfaction (1-5)            | mean
```

**Sheet 3: Settings**
```
SettingName          | SettingValue
output_file          | tracking_report.xlsx
confidence_level     | 0.95
trend_significance   | TRUE
min_base_for_testing | 30
```

### Step 3: Run Tracker

**Using GUI:**
```r
source("modules/tracker/run_tracker_gui.R")
# 1. Browse to tracking_config.xlsx
# 2. Click "Run Analysis"
# 3. Wait 30-90 seconds
```

**Using Script:**
```r
source("modules/tracker/run_tracker.R")

result <- run_tracking_analysis(
  config_path = "tracking_config.xlsx"
)
```

### Step 4: Review Output

Output Excel file contains:

**1. Summary Sheet:**
```
Study Information
─────────────────
Number of Waves: 3
Date Range: Jan 2024 - Jul 2024
Questions Tracked: 4
Total Sample: 3,000 (1,000 per wave)
```

**2. Trend Summary Sheet:**
```
Question          | W1    | W2    | W3    | W1→W2 | W2→W3 | Overall
──────────────────|────---|-------|-------|-------|-------|────────
Q1_Awareness      | 45%   | 48%   | 52%↑  | ↑     | ↑     | ↑↑
Q2_Consideration  | 32%   | 31%   | 33%   | →     | →     | →
Q3_Purchase       | 18%   | 19%   | 20%   | →     | →     | →
Q4_Satisfaction   | 3.8   | 3.9   | 4.1↑  | →     | ↑     | ↑

Legend: ↑ Significant increase | ↓ Significant decrease | → No significant change
```

**3. Individual Question Sheets:**

Each question gets a detailed sheet with:
- Trend table (metrics by wave)
- Wave-to-wave changes
- Statistical significance flags
- Sample sizes (weighted & unweighted)

**Example - Q1_Awareness sheet:**
```
Metric               | Wave 1  | Wave 2  | Wave 3  | Change W2→W3
─────────────────────|─────────|─────────|─────────|─────────────
Aware (%)            | 45.2    | 48.1    | 52.3    | +4.2↑
Base (unweighted)    | 1,000   | 1,000   | 1,000   |
Base (weighted)      | 1,000   | 1,000   | 1,000   |
Effective N          | 925     | 918     | 932     |
Confidence Interval  | ±3.1%   | ±3.1%   | ±3.0%   |
```

---

## Understanding Trend Indicators

### Symbols

| Symbol | Meaning |
|--------|---------|
| **↑** | Statistically significant increase (p < 0.05) |
| **↓** | Statistically significant decrease (p < 0.05) |
| **→** | No significant change |
| **↑↑** | Strong increase across multiple waves |
| **↓↓** | Strong decrease across multiple waves |

### Statistical Tests Used

**For Proportions:**
- Two-proportion z-test
- Tests null hypothesis: p₁ = p₂
- Accounts for effective sample size (if weighted)

**For Means:**
- Two-sample t-test
- Tests null hypothesis: μ₁ = μ₂
- Uses pooled or Welch's variance depending on equality

---

## Common Configurations

### Configuration 1: Simple 3-Wave Tracking (No Weights)

**Waves sheet:**
```
WaveID | WaveLabel | DataFile         | WeightVariable
W1     | Wave 1    | wave1_data.xlsx  |                [blank - no weights]
W2     | Wave 2    | wave2_data.xlsx  |
W3     | Wave 3    | wave3_data.xlsx  |
```

### Configuration 2: Tracking with Banner Segments

**Add Sheet: Banner**
```
BannerLabel | BreakVariable | BreakValue
Total       | Total         |
Male        | Gender        | 1
Female      | Gender        | 2
18-34       | AgeGroup      | 1,2
35+         | AgeGroup      | 3,4
```

**Result:** Trend analysis for each segment

### Configuration 3: Questions Changed Across Waves

**Add Sheet: Question_Mapping**
```
QuestionCode | Wave1_Code | Wave2_Code | Wave3_Code
Q_Satisfaction | SAT1      | SATISFACTION | Q4
```

**Tracker will:**
1. Find SAT1 in Wave 1 data
2. Find SATISFACTION in Wave 2 data
3. Find Q4 in Wave 3 data
4. Track them as one metric

---

## Troubleshooting

### ❌ "Question Q1 not found in Wave 2"
**Cause:** Question code doesn't match column name in Wave 2 data
**Fix:**
- Check spelling/capitalization (case-sensitive)
- Use Question_Mapping sheet if codes changed

### ❌ "Insufficient overlap for significance testing"
**Cause:** Base size < 30 in one or both waves
**Fix:**
- Lower `min_base_for_testing` (e.g., to 20)
- Combine segments to increase base
- Accept that sig testing won't be possible for small cells

### ❌ "All waves have identical data"
**Cause:** Using same file for all waves (copy-paste error)
**Fix:** Check `DataFile` column in Waves sheet - each should be unique

### ⚠️ "Large DEFF detected (>2.0)"
**Impact:** Effective sample sizes much lower than raw n
**Action:**
- Review weighting efficiency
- Report effective N alongside raw N
- Consider weight trimming

---

## Best Practices

### Data Preparation

✅ **DO:**
- Use consistent question codes across waves when possible
- Keep same coding scheme (1=Yes, 0=No)
- Include weights in same column name across waves
- Document any questionnaire changes

❌ **DON'T:**
- Change question codes without mapping
- Reverse coding between waves (e.g., 1=Yes to 1=No)
- Mix weighted and unweighted waves
- Skip waves in sequence (W1, W3, W4 - missing W2)

### Configuration

✅ **DO:**
- Use meaningful Wave IDs (Q1_2024, Q2_2024) not just (W1, W2)
- Include fielding dates for time series charts
- Set realistic min_base thresholds
- Document any data quality issues in notes

❌ **DON'T:**
- Use special characters in WaveID
- Leave WeightVariable blank for some waves but not others
- Set min_base too low (< 20 unreliable)

### Interpretation

✅ **DO:**
- Report confidence intervals alongside point estimates
- Note effective sample sizes for weighted data
- Consider substantive vs. statistical significance
- Check for seasonality effects

❌ **DON'T:**
- Over-interpret small changes even if significant
- Ignore large changes that aren't quite significant
- Compare non-comparable questions
- Report trends without context

---

## Advanced Features

### Feature 1: Derived Metrics

Track computed metrics (e.g., Top 2 Box, NPS):

**Settings sheet:**
```
calculate_top2box | TRUE
top2box_values    | 4,5
```

### Feature 2: Custom Benchmarks

Compare to target/competitor:

**Waves sheet - add column:**
```
WaveID | WaveLabel | Benchmark
W1     | Current   |
COMP   | Competitor| competitor_data.xlsx
TARGET | Target    | [manual entry: 60%]
```

### Feature 3: Automated Reporting

Generate PowerPoint slides:

**Settings sheet:**
```
create_ppt_summary | TRUE
ppt_template       | template.pptx
```

---

## Example Output Interpretation

**Scenario: Brand Health Tracking**

**Trend Summary shows:**
```
                   Q1_2024 | Q2_2024 | Q3_2024 | Trend
Brand Awareness    45%     | 48%     | 52%↑    | Growing ↑↑
Consideration      32%     | 31%     | 33%     | Stable →
Purchase Intent    18%     | 19%     | 20%     | Stable →
Satisfaction (1-5) 3.8     | 3.9     | 4.1↑    | Improving ↑
```

**Interpretation:**
- ✅ **Awareness growing**: +7pp over 6 months, statistically significant
- ⚠️ **Consideration flat**: Up slightly Q2→Q3 but not significant
- ⚠️ **Purchase flat**: Small increases not reaching significance
- ✅ **Satisfaction improving**: +0.3 points, significant Q2→Q3

**Recommendation:**
- Awareness campaigns working well
- Need to convert awareness to consideration
- Satisfaction gains may drive future purchase

---

## Next Steps

1. **Review USER_MANUAL.md** for comprehensive feature documentation
2. **See EXAMPLE_WORKFLOWS.md** for complex tracking scenarios
3. **Check TECHNICAL_DOCUMENTATION.md** for algorithm details
4. **Explore banner trending** for segment-specific insights

---

## Quick Reference Card

### Minimum Configuration

**3 Required Sheets:**
1. Waves (WaveID, WaveLabel, DataFile)
2. Questions (QuestionCode, QuestionType)
3. Settings (output_file)

### Question Types Supported

- `proportion` - % answering specific value(s)
- `mean` - Average score
- `nps` - Net Promoter Score
- `rating` - 1-5, 1-7, or 1-10 scales

### Analysis Time

| Waves | Questions | Segments | Time |
|-------|-----------|----------|------|
| 3     | 10        | 1 (Total)| 20 sec |
| 5     | 25        | 1 (Total)| 45 sec |
| 10    | 50        | 5        | 3-5 min |

---

**Congratulations!** You're now tracking metrics across waves with statistical rigor.

*Version 1.0.0 | Quick Start | Turas Tracker Module*
