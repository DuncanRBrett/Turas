# Turas Tracker - Quick Start Guide

**Version:** 2.0 (Enhanced with TrackingSpecs)
**Estimated Time:** 15 minutes
**Difficulty:** Intermediate
**New in v2.0:** Custom metrics, top box tracking, multi-mention support

---

## What is Turas Tracker?

---


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

## New in Version 2.0: TrackingSpecs ⭐

**Track custom metrics for deeper insights!**

### Quick Example

Add a `TrackingSpecs` column to your question_mapping.xlsx:

```
QuestionCode | QuestionType | TrackingSpecs   | Wave1 | Wave2 | Wave3
Q4_Satisfaction | Rating    | mean,top2_box   | Q4    | Q4    | Q4
```

**Result:** Track BOTH average satisfaction AND % highly satisfied (top 2 box)

### Available Metrics

**For Rating Questions (1-5, 1-10 scales):**
- `mean` - Average rating
- `top_box` - % giving highest rating
- `top2_box` - % giving top 2 ratings
- `top3_box` - % giving top 3 ratings
- `range:X-Y` - % within custom range (e.g., range:9-10)

**For Multi_Mention Questions:**
- `auto` - Auto-detect and track all options
- `option:COL` - Track specific option
- `any` - % selecting at least one

### Why Use TrackingSpecs?

**Traditional (without TrackingSpecs):**
```
Q4 Satisfaction: Mean = 4.1 (on 1-5 scale)
```
Tells you average satisfaction but not how many are really satisfied.

**Enhanced (with TrackingSpecs="mean,top2_box"):**
```
Q4 Satisfaction:
- Mean = 4.1
- Top 2 Box = 72% (rated 4 or 5)
```
Now you know both average AND % satisfied!

**Example Use Cases:**
- Track mean NPS + % promoters
- Monitor average satisfaction + % highly satisfied
- Track multiple top box metrics (top box, top 2, top 3)
- Auto-detect multi-select question options

**See USER_MANUAL.md Section 5 for complete TrackingSpecs documentation.**

---

## Wave History Report Format ⭐

**New in Version 2.0: Multiple output formats!**

### What is Wave History Format?

**Compact, executive-friendly layout:**
- One row per question (or per metric)
- Columns: QuestionCode | Question | Type | Wave 1 | Wave 2 | ... | Wave N
- All questions on one sheet (vs. one sheet per question)
- Best for: Quick overview, presentations, executive dashboards

### How to Enable

**Add to Settings sheet:**
```
SettingName   | SettingValue
report_types  | detailed,wave_history
```

**Options:**
- `detailed` - Detailed format only (default)
- `wave_history` - Wave History format only
- `detailed,wave_history` - Generate both

### Output Files

**If both formats specified:**
```
ProjectName_Tracker_20251121.xlsx         (detailed - full analysis)
ProjectName_WaveHistory_20251121.xlsx     (wave history - compact)
```

### Example Output

**Wave History Sheet:**
```
QuestionCode | Question           | Type      | W1  | W2  | W3
Q38          | Satisfaction      | Mean      | 8.2 | 8.4 | 8.6
Q38          | Satisfaction      | Top 2 Box | 72  | 75  | 78
Q39          | Recommend         | % Yes     | 68  | 71  | 74
Q20          | NPS               | NPS       | 32  | 35  | 38
```

**With Banners:**
- One sheet per segment (Total, Male, Female, etc.)
- Same layout for each segment

### When to Use

**✅ Use Wave History for:**
- Executive presentations
- Quick trend scanning
- PowerPoint tables
- Client executive summaries

**✅ Use Detailed for:**
- Statistical analysis
- Significance testing
- Technical reports
- Deep investigation

**✅ Generate Both when:**
- Serving multiple audiences
- Need both overview and detail
- Creating comprehensive deliverables

**See USER_MANUAL.md Section 6 for complete Wave History documentation.**

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

**What's Next?**
- Try adding TrackingSpecs to track custom metrics
- See USER_MANUAL.md for comprehensive documentation
- Check EXAMPLE_WORKFLOWS.md for advanced scenarios

*Version 2.0.0 | Quick Start | Turas Tracker Module | Last Updated: 2025-11-21*

---

# Turas Tracker - User Manual

**Version:** 2.0 (Enhanced with TrackingSpecs)
**Last Updated:** 2025-11-21
**Target Audience:** Market Researchers, Data Analysts, Survey Managers

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Understanding Tracking Studies](#understanding-tracking-studies)
4. [Configuration Guide](#configuration-guide)
5. [TrackingSpecs - Custom Metrics](#trackingspecs---custom-metrics) **⭐ NEW**
6. [Report Types and Wave History Format](#report-types-and-wave-history-format) **⭐ NEW**
7. [Question Types](#question-types)
8. [Wave Management](#wave-management)
9. [Question Mapping](#question-mapping)
10. [Trend Calculation](#trend-calculation)
11. [Banner Analysis](#banner-analysis)
12. [Output Interpretation](#output-interpretation)
13. [Advanced Features](#advanced-features)
14. [Troubleshooting](#troubleshooting)
15. [Best Practices](#best-practices)
16. [FAQ](#faq)

---

## Introduction

### What is Turas Tracker?

Turas Tracker is a specialized module for analyzing **multi-wave tracking studies** — surveys conducted repeatedly over time to monitor changes in attitudes, awareness, behavior, and other metrics.

**Key Capabilities:**
- Track metrics across multiple survey waves (2+ waves)
- Calculate statistical trends (significantly up, down, or stable)
- Handle question code changes between waves
- Support multiple question types (ratings, proportions, NPS, composites)
- Analyze trends by demographic segments (banner analysis)
- Generate professional Excel reports with trend indicators

### When to Use Turas Tracker

**Perfect For:**
- Brand tracking studies (awareness, consideration, preference)
- Customer satisfaction tracking (NPS, CSAT, service quality)
- Market share monitoring
- Advertising effectiveness tracking
- Employee engagement tracking
- Quarterly business reviews

**Not Suitable For:**
- Single-wave surveys (use Turas Tabs instead)
- Ad-hoc analysis without time series
- Real-time dashboards (Tracker generates static reports)

### Example Use Case

**Brand Health Tracking Study:**
- Measure brand awareness, consideration, and preference quarterly
- Track customer satisfaction metrics (1-5 scale)
- Calculate Net Promoter Score (NPS)
- Analyze trends by age group, gender, and region
- Identify which metrics are improving/declining over time

---

## Getting Started

### Prerequisites

**Required R Packages:**
```r
install.packages(c("openxlsx", "readxl"))
```

**What You Need:**
1. **Wave data files** — One data file per survey wave (CSV, Excel, SAV, DTA)
2. **Tracking configuration** — Excel file defining waves, questions, and settings
3. **Question mapping** (optional) — Map question codes if they changed between waves

### Installation

**Load Turas and Tracker module:**

```r
# Load Turas framework
source("/path/to/Turas/turas.R")

# Load Tracker module
turas_load("tracker")
```

### Your First Tracking Analysis (10 Minutes)

**Scenario:** You have 3 waves of brand tracking data (Jan, Apr, Jul 2024).

**Step 1: Prepare wave files**

```
project/
├── wave1_jan2024.csv
├── wave2_apr2024.csv
├── wave3_jul2024.csv
└── tracking_config.xlsx
```

**Step 2: Create tracking_config.xlsx**

See [Configuration Guide](#configuration-guide) for details.

**Step 3: Run analysis**

```r
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA,  # Not needed if question codes same across waves
  data_dir = getwd()
)

# Output file created: tracking_results.xlsx
```

**Step 4: Open results**

The Excel file contains:
- **Summary Sheet:** Overview of all tracked metrics with trend indicators
- **Question Sheets:** Detailed trend tables for each question
- **Metadata Sheet:** Analysis information

---

## Understanding Tracking Studies

### What is a Wave?

A **wave** is a single data collection period in a tracking study.

**Example:**
- Wave 1: January 2024 (500 respondents)
- Wave 2: April 2024 (500 respondents)
- Wave 3: July 2024 (500 respondents)

Each wave is an independent sample (different respondents each time).

### Trend Analysis Basics

**Trend Types:**
- **↑ Significantly Up:** Metric increased statistically significantly from previous wave
- **↓ Significantly Down:** Metric decreased statistically significantly
- **→ Stable:** No significant change (could be slightly up/down but not significant)

**Statistical Significance:**
- Default confidence level: 95% (alpha = 0.05)
- Tests whether observed change is likely due to real shift vs random sampling variation
- Considers sample sizes and metric variance

**Example:**

```
Brand Awareness
Wave 1: 45% (n=500)
Wave 2: 48% (n=500)  → Trend: Stable (change not significant)

Wave 2: 48% (n=500)
Wave 3: 55% (n=500)  ↑ Trend: Significantly Up (p < 0.05)
```

### Types of Metrics You Can Track

| Metric Type | Example | How It's Measured |
|-------------|---------|-------------------|
| **Proportion** | Brand awareness (% aware) | % of respondents who selected an option |
| **Mean** | Satisfaction rating (1-5) | Average rating across respondents |
| **NPS** | Net Promoter Score | % Promoters - % Detractors |
| **Index** | Brand health index (0-100) | Composite of multiple metrics |

---

## Configuration Guide

### Configuration File Structure

The **tracking_config.xlsx** file has 3 required sheets:

1. **Waves** — Define survey waves
2. **Questions** — Specify which questions to track
3. **Settings** — Analysis parameters

### Waves Sheet

**Purpose:** Define each survey wave

**Required Columns:**

| Column | Description | Example |
|--------|-------------|---------|
| WaveID | Unique wave identifier (short code) | W1, W2, W3 |
| WaveName | Display name for reports | Jan 2024, Apr 2024 |
| DataFile | Path to wave data file | wave1_data.csv |
| FieldingDate | Survey fielding date | 2024-01-15 |
| WeightVariable | Weight column name (or NA if unweighted) | Weight |

**Example:**

```
WaveID | WaveName    | DataFile         | FieldingDate | WeightVariable
W1     | Jan 2024    | wave1_data.csv   | 2024-01-15   | Weight
W2     | Apr 2024    | wave2_data.csv   | 2024-04-15   | Weight
W3     | Jul 2024    | wave3_data.csv   | 2024-07-15   | Weight
W4     | Oct 2024    | wave4_data.csv   | 2024-10-15   | Weight
```

**Notes:**
- WaveID must be unique
- WaveName appears in output tables
- DataFile can be relative (to project folder) or absolute path
- FieldingDate used for x-axis in charts (future feature)
- WeightVariable: set to NA if no weighting

### Questions Sheet

**Purpose:** Define which questions to track

**Required Columns:**

| Column | Description | Example |
|--------|-------------|---------|
| QuestionCode | Question identifier (consistent across waves) | Q01_Awareness |
| QuestionText | Display text for reports | Brand awareness (unaided) |
| QuestionType | Type of question (see below) | proportion, rating, nps |

**Example:**

```
QuestionCode       | QuestionText                        | QuestionType
Q01_Awareness      | Brand awareness (unaided)           | proportion
Q02_Consideration  | Brand consideration                 | proportion
Q03_Preference     | Brand preference                    | proportion
Q04_Satisfaction   | Overall satisfaction (1-5)          | rating
Q05_NPS            | Likelihood to recommend (0-10)      | nps
Q06_PurchaseIntent | Purchase intent next 3 months       | proportion
```

**Supported QuestionType Values:**
- `proportion` — Single choice questions (calculates % for each option)
- `rating` — Rating scale questions (calculates mean score)
- `nps` — Net Promoter Score questions (calculates NPS)
- `composite` — Composite metrics (custom calculated indices)

### Settings Sheet

**Purpose:** Configure analysis parameters

**Required Settings:**

| Setting | Description | Default | Example |
|---------|-------------|---------|---------|
| project_name | Project name for reports | "Tracking Analysis" | "Q4 Brand Tracking" |
| output_file | Output Excel filename | "tracking_results.xlsx" | "Q4_Results.xlsx" |
| confidence_level | Statistical confidence (0.90, 0.95, 0.99) | 0.95 | 0.95 |
| min_base_size | Minimum sample size for testing | 30 | 30 |

**Optional Settings:**

| Setting | Description | Default |
|---------|-------------|---------|
| output_dir | Directory for output file | Same as config file location |
| trend_significance | Show trend indicators (TRUE/FALSE) | TRUE |
| decimal_places_proportion | Decimals for proportions | 0 |
| decimal_places_mean | Decimals for means | 1 |
| show_sample_sizes | Show n= in tables | TRUE |
| banner_questions | Banner questions for segment analysis | NA |

**Example:**

```
SettingName              | SettingValue
project_name             | Q4 2024 Brand Tracking
output_file              | Q4_Brand_Tracking_Results.xlsx
output_dir               | /Users/duncan/Reports
confidence_level         | 0.95
min_base_size            | 30
trend_significance       | TRUE
decimal_places_proportion| 0
decimal_places_mean      | 2
show_sample_sizes        | TRUE
```

**Output Location (New in v2.0):**

By default, the tracker places output files in the same directory as your tracking_config.xlsx file. You can customize this with the `output_dir` setting:

**Examples:**
```
# Default (no output_dir specified)
→ Output goes to same folder as tracking_config.xlsx

# Absolute path
output_dir | /Users/duncan/Reports
→ Output goes to /Users/duncan/Reports/

# Relative path (relative to tracking_config.xlsx location)
output_dir | ../Reports
→ Output goes to Reports folder one level up from config
```

### Complete Configuration Example

**tracking_config.xlsx** with all 3 sheets:

**Sheet 1: Waves**
```
WaveID | WaveName  | DataFile    | FieldingDate | WeightVariable
W1     | Wave 1    | wave1.csv   | 2024-01-15   | Weight
W2     | Wave 2    | wave2.csv   | 2024-04-15   | Weight
W3     | Wave 3    | wave3.csv   | 2024-07-15   | Weight
```

**Sheet 2: Questions**
```
QuestionCode   | QuestionText                  | QuestionType
Q01            | Brand Awareness               | proportion
Q02            | Satisfaction (1-5)            | rating
Q03            | NPS (0-10)                    | nps
```

**Sheet 3: Settings**
```
SettingName        | SettingValue
project_name       | Brand Tracking Study
output_file        | results.xlsx
confidence_level   | 0.95
min_base_size      | 30
```

---

## TrackingSpecs - Custom Metrics

### Overview

**TrackingSpecs** is a powerful enhancement that lets you customize which metrics are tracked for each question, rather than being limited to default metrics.

**Key Benefits:**
- Track multiple metrics for a single question (e.g., both mean AND top 2 box %)
- Calculate "top box" and "bottom box" percentages for rating scales
- Track specific response ranges (e.g., % rating 9-10 on 0-10 scale)
- Auto-detect and track multi-mention questions
- Apply enhanced metrics to composite scores

**Version:** Introduced in Tracker 2.0 (2025-11-21)

### Quick Example

**Before TrackingSpecs** (default behavior):
```
Q38 Satisfaction (1-10 scale)
- Only tracks Mean score (e.g., 8.2)
```

**With TrackingSpecs:**
```
Q38 Satisfaction (1-10 scale)  |  TrackingSpecs: mean,top2_box
- Tracks Mean score (e.g., 8.2)
- PLUS Top 2 Box % (e.g., 67% rating 9-10)
```

This gives you deeper insights into both average satisfaction AND the percentage who are highly satisfied.

---

### Adding TrackingSpecs to Your Configuration

#### Step 1: Add TrackingSpecs Column to Question Mapping

Your question_mapping.xlsx file needs a new column called **TrackingSpecs**.

**Location:** Add it anywhere in the QuestionMap sheet (typically after QuestionType)

**Example Structure:**
```
QuestionCode | QuestionText                  | QuestionType | TrackingSpecs   | Wave1 | Wave2 | Wave3
Q38          | Satisfaction (1-10)           | Rating       | mean,top2_box   | Q38   | Q38   | Q38
Q41          | Service Quality (1-5)         | Rating       | mean,top_box    | Q41   | Q41   | Q41
Q30          | Purchase Motivations          | Multi_Mention| auto            | Q30   | Q30   | Q30
Q05          | Brand Awareness               | SingleChoice |                 | Q05   | Q05   | Q05
```

**Important Notes:**
- Column name must be exactly **TrackingSpecs** (case-sensitive)
- Leave blank for questions where you want default behavior
- Multiple specs separated by commas (no spaces): `mean,top2_box`

#### Step 2: That's It!

No other configuration changes needed. The tracker will automatically:
1. Detect the TrackingSpecs column
2. Parse the specifications for each question
3. Calculate the requested metrics
4. Display all metrics in output sheets

---

### Enhanced Metrics for Rating Questions

Rating questions (1-5 scales, 1-10 scales, etc.) now support these metrics:

#### Available Metrics

| Metric | Description | Example (1-10 scale) |
|--------|-------------|----------------------|
| **mean** | Average rating | 8.2 |
| **top_box** | % giving highest rating | % rating 10 |
| **top2_box** | % giving top 2 ratings | % rating 9-10 |
| **top3_box** | % giving top 3 ratings | % rating 8-10 |
| **bottom_box** | % giving lowest rating | % rating 1 |
| **bottom2_box** | % giving bottom 2 ratings | % rating 1-2 |
| **range:X-Y** | % within custom range | range:9-10 (same as top2_box for 1-10 scale) |
| **distribution** | Full distribution table | Shows % for each rating value |

#### Scale Auto-Detection

The tracker automatically detects your scale from the data:
- **1-5 scale:** top_box = % rating 5, top2_box = % rating 4-5
- **1-10 scale:** top_box = % rating 10, top2_box = % rating 9-10
- **0-10 scale:** top_box = % rating 10, top2_box = % rating 9-10
- **Any scale:** Works with any numeric rating scale

#### Usage Examples

**Example 1: Track mean + top 2 box**
```
QuestionCode | QuestionType | TrackingSpecs
Q38          | Rating       | mean,top2_box
```

**Output:**
```
Q38: How satisfied are you? (1-10 scale)

Metric          W22     W23     W24
Mean            8.20    8.03    8.27
Top 2 Box %     67.0    64.0    70.0
Sample Size     60      60      60
```

**Example 2: Track all top box metrics**
```
QuestionCode | QuestionType | TrackingSpecs
Q41          | Rating       | mean,top_box,top2_box,top3_box
```

**Output:**
```
Q41: Service Quality (1-5 scale)

Metric          Wave 1  Wave 2  Wave 3
Mean            3.8     4.1     4.3
Top Box %       25%     30%     35%
Top 2 Box %     55%     60%     68%
Top 3 Box %     80%     85%     90%
Sample Size     500     500     500
```

**Example 3: Custom range tracking**
```
QuestionCode | QuestionType | TrackingSpecs
Q42          | Rating       | mean,range:4-5
```

For a 1-5 scale, this tracks % rating 4 or 5 (satisfied/very satisfied).

#### When to Use Each Metric

**Use `mean`** when:
- You want overall average performance
- Scale has meaningful intervals (1-10 NPS, 1-5 satisfaction)
- Need to track subtle shifts in average opinion

**Use `top_box` when:**
- Only the highest rating matters ("excellent" vs all others)
- Measuring strong brand advocacy
- Corporate KPIs focus on "% excellent"

**Use `top2_box` when:**
- Measuring general satisfaction (satisfied + very satisfied)
- Industry standard is top 2 box reporting
- Want to capture positive sentiment broadly

**Use `range:X-Y` when:**
- Need custom thresholds (e.g., range:7-10 for "acceptable")
- Different from standard top box definitions
- Specific business requirements

---

### Multi_Mention Question Support

Multi-mention questions (also called "select all that apply" or checkbox questions) are now automatically detected and tracked.

#### What Are Multi_Mention Questions?

**Example:** "What features are important to you? (Select all that apply)"
- Feature A: Price
- Feature B: Quality
- Feature C: Service
- Feature D: Warranty

**Data Structure:**
```
RespondentID | Q30_1 | Q30_2 | Q30_3 | Q30_4
1            | 1     | 1     | 0     | 0
2            | 0     | 1     | 1     | 1
3            | 1     | 0     | 0     | 0
```

Where:
- `Q30_1` = Selected Feature A (Price)
- `Q30_2` = Selected Feature B (Quality)
- etc.
- 1 = selected, 0 = not selected

#### Auto-Detection

The tracker automatically detects multi-mention columns using the pattern: **`{QuestionCode}_{number}`**

**Examples:**
- `Q30_1`, `Q30_2`, `Q30_3`, ... → Auto-detected as Q30 options
- `Q15_1`, `Q15_2`, `Q15_10`, ... → Auto-detected as Q15 options (numeric sorting handles Q15_10 after Q15_2)

#### Configuration

**Option 1: Auto-detect all options (recommended)**
```
QuestionCode | QuestionType  | TrackingSpecs
Q30          | Multi_Mention | auto
```

This automatically finds and tracks ALL Q30_* columns.

**Output:**
```
Q30: Important Features (Select all that apply)

Option              Wave 1  Wave 2  Wave 3
Price (Q30_1)       65%     68%     72%
Quality (Q30_2)     80%     82%     85%
Service (Q30_3)     45%     48%     50%
Warranty (Q30_4)    30%     28%     25%
Sample Size         500     500     500
```

**Option 2: Track specific options**
```
QuestionCode | QuestionType  | TrackingSpecs
Q30          | Multi_Mention | option:Q30_1,option:Q30_2
```

Tracks only Price and Quality, ignoring Service and Warranty.

**Option 3: Track "any" mentions**
```
QuestionCode | QuestionType  | TrackingSpecs
Q30          | Multi_Mention | auto,any
```

Adds an "Any" row showing % who selected at least one option.

#### Advanced Multi_Mention Metrics

**Track average number of mentions per respondent:**
```
QuestionCode | QuestionType  | TrackingSpecs
Q30          | Multi_Mention | auto,count_mean
```

**Output includes:**
```
Mean Count: 2.3 → Respondents selected average of 2.3 options
```

---

### Enhanced Composite Metrics

Composite questions (calculated indices combining multiple questions) now support TrackingSpecs too.

#### Example: Customer Satisfaction Index

**Scenario:** Track composite satisfaction score made from 3 questions:
- Q10: Product Satisfaction (1-5)
- Q11: Service Satisfaction (1-5)
- Q12: Value Satisfaction (1-5)

**Configuration:**
```
QuestionCode   | QuestionType      | SourceQuestions     | TrackingSpecs
Comp_Sat       | Composite         | Q10,Q11,Q12         | mean,top2_box
```

**What Happens:**
1. Tracker calculates composite score (average of Q10, Q11, Q12)
2. Applies TrackingSpecs to the composite:
   - Calculates mean composite score
   - Calculates % with top 2 box on composite (4-5 on rescaled composite)

**Output:**
```
Overall Satisfaction Composite

Metric          Wave 1  Wave 2  Wave 3
Mean            4.1     4.3     4.5
Top 2 Box %     72%     78%     82%
Sample Size     500     500     500
```

#### Supported Composite Metrics

Same as rating questions:
- mean, top_box, top2_box, top3_box
- bottom_box, bottom2_box
- range:X-Y
- distribution

---

### Complete TrackingSpecs Reference

#### Syntax Rules

**Format:** Comma-separated list (no spaces)
```
metric1,metric2,metric3
```

**Examples:**
- `mean` → Single metric
- `mean,top2_box` → Two metrics
- `mean,top_box,top2_box,top3_box` → Four metrics

**Case insensitive:** `mean` = `Mean` = `MEAN` (all work)

#### Rating Question Specs

| Spec | Description |
|------|-------------|
| `mean` | Average rating |
| `top_box` | % in highest rating |
| `top2_box` | % in top 2 ratings |
| `top3_box` | % in top 3 ratings |
| `bottom_box` | % in lowest rating |
| `bottom2_box` | % in bottom 2 ratings |
| `range:X-Y` | % in range X to Y (e.g., range:9-10) |
| `distribution` | Full distribution table |

#### Multi_Mention Specs

| Spec | Description |
|------|-------------|
| `auto` | Auto-detect all options |
| `option:COLNAME` | Track specific column (e.g., option:Q30_1) |
| `any` | % selecting at least one option |
| `count_mean` | Average number of options selected |
| `count_distribution` | Distribution of mention counts |

#### Composite Specs

Same as Rating Question Specs (mean, top_box, etc.)

#### NPS Questions

TrackingSpecs **not supported** for NPS questions - NPS has fixed calculation (% Promoters - % Detractors).

#### Single/Multi Choice

TrackingSpecs **not needed** - these automatically track all options.

---

### Validation and Error Handling

The tracker validates your TrackingSpecs before running:

**Common Errors:**

**Error: Invalid spec for question type**
```
Error: TrackingSpecs 'top2_box' not valid for question type 'NPS'
```

**Solution:** NPS questions don't support custom specs. Remove TrackingSpecs for NPS questions.

**Error: Invalid range format**
```
Error: Invalid range format 'range:10'. Must be 'range:X-Y'
```

**Solution:** Use format `range:9-10` not `range:10`.

**Error: Multi-mention columns not found**
```
Warning: No columns found matching pattern Q30_*
```

**Solution:** Check your data has columns like Q30_1, Q30_2, etc. Verify QuestionCode matches.

---

### Output File Changes

#### Question Sheets

With TrackingSpecs, question sheets show multiple metric rows:

**Before (default):**
```
Q38 Satisfaction

Metric      W22     W23     W24
Mean        8.20    8.03    8.27
Sample      60      60      60
```

**After (with TrackingSpecs="mean,top2_box"):**
```
Q38 Satisfaction

Metric          W22     W23     W24
Mean            8.20    8.03    8.27
Top 2 Box %     67.0    64.0    70.0
Sample Size     60      60      60
```

#### Banner Sheets

Enhanced metrics work with banner breakouts too:

```
Q38 Satisfaction - By Gender

Metric          W22_Total  W22_Male  W22_Female  W23_Total  W23_Male  W23_Female
Mean            8.20       8.30      8.10        8.03       8.15      7.90
Top 2 Box %     67.0       70.0      64.0        64.0       68.0      60.0
Sample Size     60         30        30          60         30        30
```

#### Change Summary Sheet

The Change Summary sheet shows separate rows for each tracked metric:

```
CHANGE SUMMARY - BASELINE COMPARISON

Question            Metric      Baseline  Latest  Change   % Change
Q38 Satisfaction    mean        8.20      8.27    +0.07    +0.9%
Q38 Satisfaction    top2_box    67.0      70.0    +3.0     +4.5%
```

This lets you see which metrics improved most.

---

### TrackingSpecs Best Practices

#### 1. Start Simple

**First time using TrackingSpecs?**
- Start with `mean,top2_box` for key rating questions
- Don't add specs to every question - use defaults where appropriate
- Test with a small config first

#### 2. Choose Meaningful Metrics

**Ask yourself:**
- Does this metric align with business KPIs?
- Will stakeholders understand "top 2 box"?
- Is mean score sufficient, or do we need distribution?

**Example:**
- Corporate KPI is "% highly satisfied" → Use `top2_box`
- Report tracks average scores → Use `mean` only
- Detailed diagnostics needed → Use `mean,top2_box,distribution`

#### 3. Stay Consistent

**Within a study:**
- Use same TrackingSpecs across waves
- Don't change specs mid-study (breaks trend comparison)

**Across studies:**
- Document your TrackingSpecs choices
- Use consistent definitions (e.g., always define "satisfied" as top 2 box)

#### 4. Document Your Choices

Add notes to your question_mapping file:

```
QuestionCode | TrackingSpecs  | Notes
Q38          | mean,top2_box  | Top 2 box = "satisfied" (9-10 on 1-10 scale)
Q41          | mean,top_box   | Top box = "excellent" only (5 on 1-5 scale)
```

#### 5. Validate Output

**First time running with TrackingSpecs:**
1. Check output has expected metrics
2. Verify top box % makes sense (shouldn't exceed 100%)
3. Confirm all metrics shown in Change Summary
4. Test with small dataset first

---

### Migration Guide

**Upgrading existing tracking studies to use TrackingSpecs?**

#### Step 1: Backup Current Setup

Save copies of:
- tracking_config.xlsx
- question_mapping.xlsx
- Last output file (for comparison)

#### Step 2: Add TrackingSpecs Column

1. Open question_mapping.xlsx
2. Insert new column "TrackingSpecs" (after QuestionType recommended)
3. Leave all cells blank initially
4. Save file

#### Step 3: Test with Defaults

Run tracker - should work identically to before (blank TrackingSpecs = default behavior).

#### Step 4: Add Specs Gradually

Add TrackingSpecs to 1-2 key questions:

```
QuestionCode | QuestionType | TrackingSpecs
Q38          | Rating       | mean,top2_box
```

Run tracker, verify output looks correct.

#### Step 5: Expand

Add TrackingSpecs to more questions as needed.

**Important:** Once you add TrackingSpecs to a question, all future waves should use same specs for consistency.

---

### Troubleshooting TrackingSpecs

**Issue: TrackingSpecs ignored**

```
Expected: Mean + Top 2 Box
Actual: Only showing Mean
```

**Solutions:**
- Check column name is exactly "TrackingSpecs" (case-sensitive)
- Verify specs syntax (no spaces in comma-separated list)
- Check QuestionType is "Rating" or "Composite" (doesn't work with NPS)

**Issue: "Invalid spec" error**

```
Error: Invalid TrackingSpecs 'top2box' for question Q38
```

**Solutions:**
- Use underscore: `top2_box` not `top2box`
- Check spelling: `mean` not `avg`
- See [Complete Reference](#complete-trackingspecs-reference) for valid specs

**Issue: Multi-mention not detecting columns**

```
Warning: No multi-mention columns found for Q30
```

**Solutions:**
- Data must have columns named Q30_1, Q30_2, etc.
- Check QuestionCode matches exactly (case-sensitive)
- Verify QuestionType is "Multi_Mention"
- Use TrackingSpecs="auto" to enable auto-detection

**Issue: Top box % looks wrong**

```
Top 2 Box %: 125%  ← WRONG
```

**Solutions:**
- Check your data doesn't have values outside expected range
- Verify scale (1-5 vs 0-5 makes a difference)
- Look at distribution to see actual values in data

---

## Report Types and Wave History Format

### Overview

Turas Tracker supports multiple output formats to serve different audiences and use cases:

**1. Detailed Format (default)**
- One sheet per question with full trend analysis
- Wave-to-wave changes, significance testing, confidence intervals
- Distribution tables, sample sizes, statistical detail
- Best for: Analysts, detailed investigation, technical reports

**2. Wave History Format (new in v2.0)**
- One sheet per segment with all questions
- Compact layout: one row per question/metric
- Columns: QuestionCode | Question | Type | Wave 1 | Wave 2 | ... | Wave N
- Best for: Executives, quick overview, presentations

You can generate **detailed only**, **wave history only**, or **both simultaneously**.

---

### Configuring Report Types

Add to your **Settings** sheet:

```
SettingName   | SettingValue
report_types  | detailed,wave_history
```

**Valid Options:**

| Setting Value | Output Generated | Use When |
|---------------|------------------|----------|
| `detailed` | Detailed format only (default) | Standard analysis, technical reports |
| `wave_history` | Wave History format only | Executive dashboards, presentations |
| `detailed,wave_history` | Both formats | Serve multiple stakeholders |

**If omitted:** Defaults to `detailed` (backward compatible).

---

### Wave History Format Specification

#### Sheet Structure

**Without Banners:**
- Single sheet: "Total"

**With Banners:**
- One sheet per segment
- First sheet: "Total" (total sample)
- Subsequent sheets: Each banner segment (e.g., "Male", "Female", "18-34", "35+")

#### Column Layout

```
QuestionCode | Question                    | Type      | W1   | W2   | W3   | W4
Q02          | Overall satisfaction (1-10) | Mean      | 8.2  | 8.4  | 8.6  | 8.8
Q05          | Would recommend             | % Yes     | 67   | 70   | 72   | 75
Q20          | Net Promoter Score          | NPS       | 32   | 35   | 38   | 41
```

**Column Definitions:**
- **QuestionCode**: Question identifier
- **Question**: Question text
- **Type**: Metric type (Mean, Top Box, % Yes, NPS, etc.)
- **Wave columns**: One per wave showing metric value

#### Numeric Formatting

Wave History respects your configuration settings:
- **decimal_places_ratings**: Number of decimal places (e.g., 1 → 8.2)
- **decimal_separator**: Decimal separator (. or ,)
- Missing data shows as blank cells (not 0 or NA)

---

### How TrackingSpecs Work with Wave History

#### Single Metric Questions

Questions without TrackingSpecs or with single metric show **one row**:

```
QuestionCode | QuestionType | TrackingSpecs
Q02          | Rating       |                (blank - defaults to mean)
```

**Wave History:**
```
QuestionCode | Question           | Type | W1  | W2  | W3
Q02          | Overall satisfaction | Mean | 8.2 | 8.4 | 8.6
```

#### Multiple Metrics Questions

Questions with multiple TrackingSpecs show **one row per metric**:

```
QuestionCode | QuestionType | TrackingSpecs
Q38          | Rating       | mean,top2_box
```

**Wave History:**
```
QuestionCode | Question           | Type      | W1  | W2  | W3
Q38          | Satisfaction      | Mean      | 8.2 | 8.4 | 8.6
Q38          | Satisfaction      | Top 2 Box | 72  | 75  | 78
```

#### Multi_Mention Questions

Multi-mention questions show **one row per tracked option**:

```
QuestionCode | QuestionType  | TrackingSpecs
Q15          | Multi_Mention | auto
```

**Wave History:**
```
QuestionCode | Question      | Type          | W1 | W2 | W3
Q15          | Features used | % Feature_1   | 45 | 48 | 50
Q15          | Features used | % Feature_2   | 32 | 35 | 38
Q15          | Features used | % Feature_3   | 18 | 20 | 22
```

---

### Output File Naming

**Single Report Type:**
```
ProjectName_Tracker_20251121.xlsx          (if report_types = detailed)
ProjectName_WaveHistory_20251121.xlsx      (if report_types = wave_history)
```

**Multiple Report Types:**
```
ProjectName_Tracker_20251121.xlsx          (detailed format)
ProjectName_WaveHistory_20251121.xlsx      (wave history format)
```

Files are saved to:
1. Directory specified in `output_dir` setting, OR
2. Same directory as tracking configuration file (default)

---

### Use Cases

#### Use Case 1: Executive Dashboard

**Setup:**
```
SettingName   | SettingValue
report_types  | detailed,wave_history
```

**Workflow:**
- Analysts use **detailed** report for full investigation
- Share **wave history** with executives for quick overview
- No need to manually create summary - it's automatic

#### Use Case 2: Client Deliverable

**Setup:**
```
SettingName   | SettingValue
report_types  | detailed,wave_history
```

**Deliverable:**
- **Detailed report**: Full technical appendix with methodology
- **Wave history**: Executive summary in clean, scannable format
- Both generated from same analysis ensuring consistency

#### Use Case 3: Presentation Preparation

**Setup:**
```
SettingName   | SettingValue
report_types  | wave_history
```

**Workflow:**
- Generate wave history only for speed
- Copy data directly into PowerPoint tables
- Easy to scan for interesting trends to highlight
- Create simplified charts from wave columns

---

### Comparing Formats

**Example: Q38 Overall Satisfaction with TrackingSpecs="mean,top2_box"**

#### Detailed Format Output

**Sheet: Q38**
```
Q38: Overall satisfaction (1-10)

Metric         | Wave 1 | Wave 2 | Wave 3 | Change W2→W3
─────────────────────────────────────────────────────────
Mean           | 8.2    | 8.4    | 8.6    | +0.2↑
Top 2 Box %    | 72     | 75     | 78     | +3↑
Sample Size(n) | 500    | 500    | 500    |

Wave-over-Wave Changes:
Comparison     | From | To  | Change | % Change | Significant
W1 → W2 (mean) | 8.2  | 8.4 | +0.2   | +2.4%    | Yes
W2 → W3 (mean) | 8.4  | 8.6 | +0.2   | +2.4%    | Yes
...
```

#### Wave History Format Output

**Sheet: Total**
```
QuestionCode | Question           | Type      | Wave 1 | Wave 2 | Wave 3
Q38          | Overall satisfaction | Mean      | 8.2    | 8.4    | 8.6
Q38          | Overall satisfaction | Top 2 Box | 72     | 75     | 78
Q39          | Likelihood to...   | Mean      | 7.5    | 7.8    | 8.0
Q40          | Would recommend    | % Yes     | 68     | 71     | 74
```

**Differences:**
- Wave History: All questions on one sheet vs. one sheet per question
- Wave History: No change indicators, significance flags
- Wave History: More scannable for quick comparison
- Detailed: Full statistical context and methodology

---

### Best Practices

**✅ DO:**
- Generate both formats for comprehensive reporting
- Use wave history for executive presentations
- Use detailed format for technical analysis
- Set consistent decimal_places across both formats
- Review wave history to quickly identify trends for deeper dive

**❌ DON'T:**
- Rely solely on wave history for statistical decisions (use detailed for significance)
- Mix decimal separators between formats (set once in Settings)
- Manually create summaries when wave history can auto-generate them
- Forget to update report_types when switching audiences

---

### Example Configuration

**Complete Settings for Both Report Types:**

```
SettingName              | SettingValue
project_name             | Q4 2024 Brand Tracking
report_types             | detailed,wave_history
output_dir               | /Users/username/Tracking_Reports
decimal_places_ratings   | 1
decimal_places_nps       | 0
decimal_separator        | .
show_significance        | TRUE
confidence_level         | 0.95
```

**Example Question Mapping:**

```
QuestionCode | QuestionType | TrackingSpecs   | Wave1 | Wave2 | Wave3
Q02          | Rating       | mean            | Q02   | Q02   | Q02
Q38          | Rating       | mean,top2_box   | Q38   | Q38A  | Q38B
Q05          | Single       |                 | Q05   | Q05   | Q05C
Q20          | NPS          |                 | Q20   | Q20   | Q20
Comp_Sat     | Composite    | mean            | -     | -     | -
```

**Result:**
- Both detailed and wave history reports generated
- Q38 shows two rows in wave history (mean + top2_box)
- All numeric values formatted with 1 decimal place (except NPS which uses 0)
- Files saved to specified output_dir

---

### Troubleshooting Wave History

**Issue: Wave history file not generated**

```
Only seeing detailed report, no wave history file
```

**Solution:**
- Check Settings sheet has `report_types` setting
- Verify value includes "wave_history" (case-insensitive)
- Check console output for errors during wave history generation

**Issue: Wrong metrics showing in wave history**

```
Expected top2_box but seeing mean
```

**Solution:**
- Verify TrackingSpecs column in question mapping includes "top2_box"
- Check question_metadata has correct specs for that question
- Review console output for TrackingSpecs parsing messages

**Issue: Too many/too few rows for multi-mention question**

```
Q15 should show 5 options but only showing 3
```

**Solution:**
- Verify column naming matches pattern: Q15_1, Q15_2, etc.
- Check data files have all expected columns across all waves
- Ensure QuestionType is "Multi_Mention" with TrackingSpecs="auto"

**Issue: Missing banner segments in wave history**

```
Wave history only has Total sheet, not Male/Female
```

**Solution:**
- Verify you ran with `use_banners = TRUE`
- Check Banner sheet exists in tracking config
- Ensure banner segments calculated correctly (check detailed report first)

---

## Question Types

### Proportion Questions

**Purpose:** Track percentage of respondents selecting each option

**Example:** Brand awareness — "Which brands are you aware of?"

**Data Structure:**
```
RespondentID | Q01_Awareness
1            | Brand A
2            | Brand B
3            | Brand A
4            | None
```

**Output:**
```
Brand Awareness
                Wave 1  Wave 2  Wave 3  Trend
                (Jan)   (Apr)   (Jul)
Base (n=)       500     500     500
Brand A    %    45%     48%     55%     ↑
Brand B    %    30%     32%     31%     →
Brand C    %    15%     13%     10%     ↓
None       %    10%     7%      4%      ↓
```

**Configuration:**
```
QuestionCode   | QuestionText      | QuestionType
Q01_Awareness  | Brand Awareness   | proportion
```

### Rating Questions

**Purpose:** Track mean scores for rating scale questions

**Example:** Satisfaction — "How satisfied are you? (1=Very Dissatisfied, 5=Very Satisfied)"

**Data Structure:**
```
RespondentID | Q02_Satisfaction
1            | 5
2            | 4
3            | 3
4            | 5
```

**Output:**
```
Overall Satisfaction (1-5 scale)
                Wave 1  Wave 2  Wave 3  Trend
Base (n=)       500     500     500
Mean Score      3.8     3.9     4.2     ↑
Std Dev         1.2     1.1     1.0
```

**Configuration:**
```
QuestionCode      | QuestionText               | QuestionType
Q02_Satisfaction  | Overall Satisfaction (1-5) | rating
```

**Supports:**
- Any numeric scale (1-5, 1-7, 1-10, 0-100, etc.)
- Likert scales
- Semantic differential scales
- Custom rating scales

### NPS Questions

**Purpose:** Track Net Promoter Score over time

**Example:** "How likely are you to recommend us to a friend? (0=Not at all, 10=Extremely likely)"

**Data Structure:**
```
RespondentID | Q03_NPS
1            | 10
2            | 9
3            | 7
4            | 5
```

**NPS Calculation:**
- **Promoters:** Score 9-10
- **Passives:** Score 7-8
- **Detractors:** Score 0-6
- **NPS = % Promoters - % Detractors**

**Output:**
```
Net Promoter Score
                    Wave 1  Wave 2  Wave 3  Trend
Base (n=)           500     500     500
% Promoters         40%     45%     50%     ↑
% Passives          35%     35%     30%     →
% Detractors        25%     20%     20%     →
NPS Score           15      25      30      ↑
```

**Configuration:**
```
QuestionCode | QuestionText                     | QuestionType
Q03_NPS      | Likelihood to recommend (0-10)   | nps
```

### Composite Questions

**Purpose:** Track custom calculated indices combining multiple metrics

**Example:** Brand Health Index = Average of (Awareness + Consideration + Preference)

**Configuration:**
```
QuestionCode        | QuestionText           | QuestionType | CompositeFormula
COMP_BrandHealth    | Brand Health Index     | composite    | mean(Q01,Q02,Q03)
```

**Output:**
```
Brand Health Index
                Wave 1  Wave 2  Wave 3  Trend
Base (n=)       500     500     500
Index Score     65      68      72      ↑
```

**Supported Formulas:**
- `mean(Q01,Q02,Q03)` — Average of multiple questions
- `sum(Q01,Q02,Q03)` — Sum of multiple questions
- `custom` — Requires custom calculation function

---

## Wave Management

### Adding New Waves

**To add a new wave to existing tracking study:**

**Step 1:** Collect new wave data with same question structure

**Step 2:** Add row to Waves sheet in tracking_config.xlsx:

```
WaveID | WaveName  | DataFile    | FieldingDate | WeightVariable
W1     | Wave 1    | wave1.csv   | 2024-01-15   | Weight
W2     | Wave 2    | wave2.csv   | 2024-04-15   | Weight
W3     | Wave 3    | wave3.csv   | 2024-07-15   | Weight
W4     | Wave 4    | wave4.csv   | 2024-10-15   | Weight  ← NEW
```

**Step 3:** Re-run analysis:

```r
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA
)
```

**Results now include 4 waves with updated trends.**

### Removing Waves

To exclude a wave from analysis:

**Option 1:** Delete row from Waves sheet
**Option 2:** Comment out row with "#" in WaveID column

```
WaveID  | WaveName  | DataFile
W1      | Wave 1    | wave1.csv
#W2     | Wave 2    | wave2.csv   ← Will be ignored
W3      | Wave 3    | wave3.csv
```

### Wave Ordering

**Waves are processed in the order they appear in the Waves sheet.**

For correct trend calculation:
- **Always list waves chronologically** (oldest first)
- FieldingDate helps track this visually
- Trend indicators show change from wave N to wave N+1

**Incorrect:**
```
W3 → W1 → W2  (Wrong order)
```

**Correct:**
```
W1 → W2 → W3  (Chronological order)
```

---

## Question Mapping

### Why Question Mapping?

**Problem:** Question codes sometimes change between waves

**Example:**
- Wave 1: Question coded as `Q1_Awareness`
- Wave 2: Same question coded as `Q01_BrandAwareness`
- Wave 3: Same question coded as `Awareness_Q1`

**Without mapping:** Tracker thinks these are different questions → cannot track trend

**With mapping:** You tell Tracker "these are all the same question" → trend calculated correctly

### When You Need Question Mapping

**You need mapping if:**
- Question codes changed between waves
- Question column names different across files
- Questions renumbered in later waves
- Questionnaire restructured but content same

**You don't need mapping if:**
- Question codes identical across all waves
- Column names consistent
- Data structure hasn't changed

### Creating Question Mapping File

**Create question_mapping.xlsx with Questions sheet:**

**Required Columns:**
- QuestionCode — Standardized question code (use in tracking_config.xlsx)
- QuestionType — Question type
- W1, W2, W3, ... — Question code in each wave (one column per wave)

**Example:**

```
QuestionCode   | QuestionType | W1              | W2                  | W3
Q01_Awareness  | proportion   | Q1_Awareness    | Q01_BrandAwareness  | Awareness_Q1
Q02_Satisfaction| rating      | Q2_Satisfaction | Q02_Satisfaction    | Q2_Sat
Q03_NPS        | nps          | Q3_NPS          | Q03_NPS_Score       | NPS_Q3
```

**How to Read This:**
- Row 1: QuestionCode "Q01_Awareness" maps to:
  - Wave 1 data: column "Q1_Awareness"
  - Wave 2 data: column "Q01_BrandAwareness"
  - Wave 3 data: column "Awareness_Q1"

### Using Question Mapping

**Include mapping file when running tracker:**

```r
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = "question_mapping.xlsx",  ← Add this
  data_dir = getwd()
)
```

**Tracker will:**
1. Read standardized question codes from tracking_config.xlsx
2. Look up wave-specific column names in question_mapping.xlsx
3. Extract correct columns from each wave data file
4. Calculate trends using matched questions

### Handling Missing Questions

**If a question doesn't exist in a wave:**

```
QuestionCode   | QuestionType | W1              | W2              | W3
Q01_Awareness  | proportion   | Q1_Awareness    | Q1_Awareness    | Q1_Awareness
Q04_NewMetric  | rating       | NA              | NA              | Q4_NewMetric
```

- Q04_NewMetric only asked in Wave 3
- Set earlier waves to NA
- Tracker will show NA for W1 and W2, calculate trend starting W3

---

## Trend Calculation

### How Trends Are Calculated

**For Proportions (e.g., Brand Awareness %):**

Uses **Z-test for proportions**:

```
p1 = proportion in Wave 1
p2 = proportion in Wave 2
n1 = sample size in Wave 1
n2 = sample size in Wave 2

SE = sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))
Z = (p2 - p1) / SE

If |Z| > critical value (1.96 for 95% confidence):
  Trend is significant
```

**For Means (e.g., Satisfaction Rating):**

Uses **T-test for independent samples**:

```
mean1 = mean in Wave 1
mean2 = mean in Wave 2
s1, s2 = standard deviations
n1, n2 = sample sizes

SE = sqrt(s1²/n1 + s2²/n2)
t = (mean2 - mean1) / SE

If |t| > critical value:
  Trend is significant
```

**For NPS:**

Uses **Z-test on NPS score difference**:

```
NPS1 = %Promoters_W1 - %Detractors_W1
NPS2 = %Promoters_W2 - %Detractors_W2

Test if (NPS2 - NPS1) is significantly different from 0
```

### Trend Indicators

**Symbols used in output:**

| Symbol | Meaning | Criteria |
|--------|---------|----------|
| ↑ | Significantly Up | p < alpha AND increase |
| ↓ | Significantly Down | p < alpha AND decrease |
| → | Stable (no significant change) | p >= alpha |
| — | Not available / Not tested | Missing data or base too small |

**Example:**

```
Brand Awareness
           Wave 1  Wave 2  Trend  Wave 3  Trend
Base       500     500            500
Brand A    45%     48%     →      55%     ↑
Brand B    30%     32%     →      31%     →
Brand C    15%     13%     →      10%     ↓
```

Interpretation:
- Brand A: Stable W1→W2, then significantly increased W2→W3
- Brand B: Stable throughout
- Brand C: Stable W1→W2, then significantly decreased W2→W3

### Confidence Levels

**Default:** 95% confidence (alpha = 0.05)

**Interpretation:**
- 95% confident that observed change is real (not due to sampling variation)
- 5% chance of false positive (Type I error)

**Adjusting Confidence Level:**

```
SettingName        | SettingValue
confidence_level   | 0.90        ← 90% confidence (more sensitive)
confidence_level   | 0.95        ← 95% confidence (standard)
confidence_level   | 0.99        ← 99% confidence (more conservative)
```

**Trade-offs:**
- **Higher confidence (0.99):** Fewer false positives, but may miss real changes
- **Lower confidence (0.90):** Detect smaller changes, but more false positives

### Minimum Base Size

**Purpose:** Prevent significance testing on unreliable small samples

**Default:** 30 respondents minimum

**Configuration:**

```
SettingName     | SettingValue
min_base_size   | 30
```

**Behavior:**
- If base < min_base_size: Show "—" instead of trend indicator
- Metric still calculated and shown, but not tested for significance

**Example:**

```
Brand Awareness (Among Category Users)
           Wave 1  Wave 2  Trend
Base       45      48
Brand A    40%     50%     —      ← Base too small, not tested
```

---

## Banner Analysis

**Note:** Banner analysis is Phase 3 functionality (advanced feature).

### What is Banner Analysis?

**Banner analysis** tracks trends separately for different demographic segments.

**Example:**
- Track brand awareness for Males vs Females
- Track satisfaction for different age groups
- Track NPS for different regions

### Enabling Banner Analysis

**Step 1:** Add banner_questions to Settings sheet:

```
SettingName        | SettingValue
banner_questions   | Gender,Age_Group
```

**Step 2:** Ensure banner variables exist in all wave data files:

```
# wave1.csv
RespondentID | Gender | Age_Group | Q01_Awareness
1            | Male   | 18-34     | Brand A
2            | Female | 35-54     | Brand B
...
```

**Step 3:** Run with banner analysis enabled:

```r
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA,
  use_banners = TRUE  ← Enable banner analysis
)
```

### Banner Output Example

**Brand Awareness - By Gender:**

```
                    Wave 1          Wave 2          Wave 3
                Male    Female  Male    Female  Male    Female
Base (n=)       250     250     250     250     250     250

Brand A    %    50%     40%     52%     44%     60%     50%
Trend                           →       →       ↑       ↑

Brand B    %    28%     32%     30%     34%     29%     33%
Trend                           →       →       →       →
```

**Insights:**
- Brand A awareness increased significantly for both males and females in Wave 3
- Brand B awareness stable across all waves and segments
- Males consistently higher awareness of Brand A than females

---

## Output Interpretation

### Output File Structure

**The generated Excel file contains:**

1. **Summary Sheet** — Overview table with latest wave and trends
2. **Question Sheets** — One sheet per tracked question with detailed trend table
3. **Metadata Sheet** — Analysis information (waves, settings, timestamp)

### Summary Sheet

**Purpose:** Quick overview of all metrics

**Example:**

```
TRACKING SUMMARY - Q4 2024 Brand Tracking
Generated: 2024-10-15 14:30:00

Question                    Latest    Previous  Trend  Current Value
                           (Wave 3)  (Wave 2)
Brand Awareness            55%       48%       ↑      55%
Brand Consideration        42%       40%       →      42%
Brand Preference           35%       30%       ↑      35%
Satisfaction (1-5)         4.2       3.9       ↑      4.2
NPS Score                  30        25        ↑      30
Purchase Intent            45%       43%       →      45%
```

**How to Use:**
- Quick scan for which metrics moving up/down
- Identify priorities for action (declining metrics)
- Present high-level trends to stakeholders

### Question Detail Sheets

**Purpose:** Full trend table for each question

**Example Sheet: "Q01_Brand_Awareness"**

```
Brand Awareness (unaided)
Question Type: Proportion

                Wave 1      Wave 2      Trend   Wave 3      Trend
                Jan 2024    Apr 2024            Jul 2024
Base (n=)       500         500                 500

Brand A    %    45%         48%         →       55%         ↑
Brand B    %    30%         32%         →       31%         →
Brand C    %    15%         13%         →       10%         ↓
Other      %    5%          4%          →       3%          →
None       %    5%          3%          →       1%          ↓

Metadata:
- Confidence Level: 95%
- Test: Z-test for proportions
- Minimum Base: 30
```

**How to Read:**
- Each option has its own trend line
- Trend column shows change from previous wave
- Base sizes shown for reference
- Metadata explains statistical methods

### Metadata Sheet

**Purpose:** Document analysis parameters

**Example:**

```
TRACKING ANALYSIS METADATA

Project: Q4 2024 Brand Tracking
Generated: 2024-10-15 14:30:00
Turas Version: 1.0

WAVES:
WaveID | WaveName  | FieldingDate | Records | Weight
W1     | Jan 2024  | 2024-01-15   | 500     | Yes
W2     | Apr 2024  | 2024-04-15   | 500     | Yes
W3     | Jul 2024  | 2024-07-15   | 500     | Yes

SETTINGS:
Confidence Level: 95%
Minimum Base Size: 30
Trend Significance: Enabled

TRACKED QUESTIONS: 6
- Q01_Awareness (proportion)
- Q02_Consideration (proportion)
- Q03_Preference (proportion)
- Q04_Satisfaction (rating)
- Q05_NPS (nps)
- Q06_PurchaseIntent (proportion)
```

---

## Advanced Features

### Weighted Data Analysis

**If your data is weighted** (to match population demographics):

**Step 1:** Ensure weight column exists in data:

```
RespondentID | Gender | Q01  | Weight
1            | Male   | 5    | 1.2
2            | Female | 4    | 0.8
```

**Step 2:** Specify weight column in Waves sheet:

```
WaveID | WaveName | DataFile   | WeightVariable
W1     | Wave 1   | wave1.csv  | Weight
W2     | Wave 2   | wave2.csv  | Weight
```

**Tracker will:**
- Use weighted percentages for proportions
- Use weighted means for ratings
- Adjust significance tests for weighting (Design Effect)

### Custom Composite Metrics

**Example:** Customer Experience Index = 0.3×Satisfaction + 0.3×Quality + 0.4×NPS

**Step 1:** Add composite to Questions sheet:

```
QuestionCode  | QuestionText             | QuestionType | CompositeFormula
COMP_CX_Index | Customer Experience Index| composite    | custom
```

**Step 2:** Implement custom calculation function (requires code modification).

### Exporting Results

**To extract trend data programmatically:**

```r
# Run analysis
result <- run_tracker(...)

# Access trend results
trend_data <- result$trend_results

# Extract specific question
brand_awareness_trend <- trend_data[["Q01_Awareness"]]

# Convert to data frame
library(dplyr)
trend_df <- bind_rows(brand_awareness_trend$wave_results)
```

---

## Troubleshooting

### Common Issues

**Issue: "Wave data file not found"**

```
Error: Cannot find data file: wave1_data.csv
```

**Solution:**
- Check DataFile paths in Waves sheet
- Ensure files exist in specified location
- Use absolute paths if relative paths failing
- Verify spelling and file extensions

**Issue: "Question not found in wave data"**

```
Warning: Question Q01 not found in Wave 2 data
```

**Solution:**
- Check column names in wave data file
- Verify question_mapping.xlsx if using mapping
- Ensure QuestionCode matches data column exactly (case-sensitive)

**Issue: "All trends showing stable (no significance)"**

**Possible Causes:**
1. Sample sizes too small (low power)
2. Changes genuinely not significant
3. High variance in data

**Solutions:**
- Check base sizes (need 50+ per wave for good power)
- Try lower confidence level (0.90 instead of 0.95)
- Verify data quality (check for outliers, data errors)

**Issue: "Different base sizes between waves"**

```
Wave 1: n=500
Wave 2: n=300
Wave 3: n=500
```

**This is OK:** Tracker handles different sample sizes correctly

**But consider:**
- Why base size dropped in Wave 2?
- Fielding issues? Different sampling?
- May affect power to detect trends in/out of Wave 2

**Issue: "Missing data in some waves"**

```
Wave 1: 95% response rate
Wave 2: 85% response rate
Wave 3: 90% response rate
```

**Tracker handles missing data (NAs) automatically:**
- Excludes NAs from calculations
- Reports effective base size
- Tests only on valid responses

**But watch for:**
- Non-random missingness (bias)
- Large differences in missing data rates between waves

---

## Best Practices

### Survey Design for Tracking

**DO:**
- Keep question wording consistent across waves
- Use same response scales (don't change 1-5 to 1-7 mid-study)
- Field waves at regular intervals (monthly, quarterly, etc.)
- Target similar sample sizes each wave (±20% acceptable)
- Use consistent sampling methodology

**DON'T:**
- Change question wording without documentation
- Mix phone and online data collection methods mid-study
- Skip waves irregularly (creates interpretation issues)
- Drastically change sample composition

### Sample Size Planning

**Minimum Recommended:**
- 200+ per wave for stable estimates
- 400+ per wave for detecting small changes
- 1000+ per wave for subgroup (banner) analysis

**Power Calculation Example:**

To detect 5 percentage point change with 80% power at 95% confidence:
- Need ~385 per wave

To detect 10 percentage point change:
- Need ~100 per wave

### Interpreting Trends

**Statistical vs Practical Significance:**

```
Example:
Wave 1: 45.0%
Wave 2: 45.5%  (Trend: ↑ Significantly Up)
```

**This is statistically significant but...**
- Increase is tiny (0.5 percentage points)
- Probably not practically meaningful
- Don't over-react to small but significant changes

**Consider:**
- Effect size (magnitude of change)
- Business context (is 0.5% meaningful?)
- Trend direction over multiple waves

**Look for Patterns:**

```
Wave 1 → Wave 2 → Wave 3 → Wave 4
45%   →  46%   →  48%   →  51%
```

Consistent upward trend across multiple waves = stronger evidence than single spike.

### Reporting Trends

**To Stakeholders:**
1. **Start with summary:** "3 metrics up, 2 stable, 1 down"
2. **Highlight significant changes:** Focus on ↑ and ↓
3. **Provide context:** Why did this change? (Campaign? Seasonality?)
4. **Show time series:** Graph trends over all waves, not just latest
5. **Recommend actions:** What should we do about declining metrics?

**Don't:**
- Report every tiny fluctuation as newsworthy
- Ignore stable metrics (stable can be good!)
- Present numbers without context
- Claim causation from correlation

---

## FAQ

**Q: How many waves do I need?**

A: Minimum 2 waves to calculate trends. 3+ waves recommended to identify patterns. 6+ waves ideal for seasonal adjustments.

**Q: Can I compare non-consecutive waves (e.g., Wave 1 vs Wave 3)?**

A: Tracker calculates trends between consecutive waves only. For custom comparisons, export data and calculate manually.

**Q: What if my question codes changed between waves?**

A: Use question mapping file to map old codes to new codes. See [Question Mapping](#question-mapping) section.

**Q: Can I track open-ended questions?**

A: No. Tracker supports quantitative metrics only (proportions, means, NPS). For open-ended analysis, use text analytics tools separately.

**Q: How do I handle seasonal variation?**

A: Compare same quarter year-over-year (Q1 2024 vs Q1 2023) instead of consecutive quarters. Future Tracker versions will support seasonality adjustment.

**Q: Can I track multiple brands in one study?**

A: Yes. Create separate questions for each brand or use banner analysis to break out by brand.

**Q: What if sample demographics shifted between waves?**

A: Use weighting to adjust for demographic shifts. Ensure weight column included in all wave files.

**Q: How do I know if trend is due to real change vs sampling error?**

A: That's what significance testing tells you! ↑/↓ indicators mean change is unlikely due to chance (at your confidence level).

**Q: Can I use Tracker for cross-sectional (single wave) analysis?**

A: No. Use Turas Tabs for single-wave crosstabulation. Tracker is specifically for multi-wave time series.

**Q: Where are trend charts?**

A: Charts are Phase 4 enhancement (not yet implemented). Current output is tables only. You can create charts manually from the output tables in Excel.

---

## Known Limitations and Considerations

### Statistical Considerations

**Significance Testing Under Weighting**

The tracker uses **effective N** (design-effect adjusted sample size) for significance testing when data is weighted. This provides more accurate p-values than using raw unweighted sample sizes, especially when weights vary substantially.

- **What this means:** If your data has high variation in weights (e.g., some respondents weighted 0.5, others weighted 2.0), the effective sample size will be smaller than the unweighted n
- **Impact:** Significance tests are appropriately conservative and account for the precision loss from weighting
- **Good practice:** Check the "Weight efficiency" message in console output when loading data

**Questionnaire Changes Between Waves**

- **Scale changes:** If a question changes from 5-point to 7-point scale between waves, trends may not be strictly comparable. Consider creating a "v2" trend starting from the wave where the scale changed.
- **Wording changes:** Significant wording changes should trigger a new tracking series
- **Current limitation:** No built-in support for bridging scales or flagging breaks in series

### Question Type Support

**Multi_Mention Questions**

Multi-mention questions (select-all-that-apply) are supported with some considerations:

- **Basic tracking:** Percentage mentioning each option is tracked reliably
- **Complex TrackingSpecs:** Some advanced specs combinations are still experimental
- **Known issue:** Certain combinations of multi-mention + complex TrackingSpecs may require additional testing

**Not Currently Supported:**

- **Open-ended questions:** Cannot be tracked quantitatively
- **Ranking questions:** Planned for future enhancement (currently can track % ranked 1st manually)

### Environment Requirements

**Directory Structure:**

The tracker requires the full Turas directory structure and will fail if:
- Run from outside the `modules/tracker/` directory without setting `TURAS_ROOT` environment variable
- The `shared/formatting.R` file is not accessible
- Required module files are missing

**How to avoid:** Always run from within the Turas project structure, or set the `TURAS_ROOT` environment variable

### Data Cleaning Scope

The tracker automatically cleans numeric question responses (replacing "DK", "Prefer not to say", etc. with NA), but **only** for columns that:
- Match the question code pattern (e.g., Q1, Q2, Q10_1, etc.), OR
- Are explicitly listed in the question mapping

**Impact:** ID columns, custom fields, and other non-question numeric columns are preserved as-is, preventing unintended data conversions

### Future Enhancements

Features identified for future implementation:

- **Scale bridging:** Support for recoding when scales change mid-tracker
- **Multiple comparison correction:** Optional Bonferroni or Holm adjustments for significance tests
- **Exceptions report:** Automated "What changed this wave?" summary sheet
- **Rolling averages:** 3-wave, 6-month rolling windows for smoothing trends
- **Event markers:** Annotation support for promotions, external events
- **Seasonality flags:** Built-in support for seasonal pattern identification

**Note:** These limitations are documented to ensure you use the tracker appropriately. None prevent the tracker from delivering reliable, production-quality tracking analysis for standard MR workflows.

---

## Appendix A: Complete Configuration Template

```
================================================================================
TRACKING_CONFIG.XLSX
================================================================================

SHEET 1: Waves
--------------
WaveID | WaveName     | DataFile        | FieldingDate | WeightVariable
W1     | January 2024 | wave1_data.csv  | 2024-01-15   | Weight
W2     | April 2024   | wave2_data.csv  | 2024-04-15   | Weight
W3     | July 2024    | wave3_data.csv  | 2024-07-15   | Weight
W4     | October 2024 | wave4_data.csv  | 2024-10-15   | Weight

SHEET 2: Questions
------------------
QuestionCode       | QuestionText                        | QuestionType
Q01_Awareness      | Brand awareness (unaided)           | proportion
Q02_Consideration  | Brand consideration                 | proportion
Q03_Preference     | Brand preference                    | proportion
Q04_Satisfaction   | Overall satisfaction (1-5)          | rating
Q05_Quality        | Product quality (1-5)               | rating
Q06_Value          | Value for money (1-5)               | rating
Q07_NPS            | Likelihood to recommend (0-10)      | nps
Q08_PurchaseIntent | Purchase intent next 3 months       | proportion
COMP_BrandHealth   | Brand Health Index                  | composite

SHEET 3: Settings
-----------------
SettingName              | SettingValue
project_name             | Q4 2024 Brand Tracking Study
output_file              | Q4_2024_Tracking_Results.xlsx
confidence_level         | 0.95
min_base_size            | 30
trend_significance       | TRUE
decimal_places_proportion| 0
decimal_places_mean      | 2
show_sample_sizes        | TRUE
banner_questions         | Gender,Age_Group
```

---

## Appendix B: Question Mapping Template

```
================================================================================
QUESTION_MAPPING.XLSX
================================================================================

SHEET: Questions
----------------
QuestionCode       | QuestionType | W1              | W2                  | W3              | W4
Q01_Awareness      | proportion   | Q1_Awareness    | Q01_BrandAwareness  | Awareness_Q1    | Q1_Aware
Q02_Consideration  | proportion   | Q2_Consider     | Q02_Consideration   | Consider_Q2     | Q2_Consider
Q03_Preference     | proportion   | Q3_Preference   | Q03_Preference      | Preference_Q3   | Q3_Pref
Q04_Satisfaction   | rating       | Q4_Sat          | Q04_Satisfaction    | Satisfaction_Q4 | Q4_Satisfaction
Q05_NPS            | nps          | Q5_NPS          | Q05_NPS_Score       | NPS_Q5          | Q5_NPS_Score
```

**Notes:**
- QuestionCode: Use in tracking_config.xlsx Questions sheet
- W1, W2, W3, W4: Actual column names in each wave's data file
- NA: Question not asked in that wave
- Use same QuestionType as in tracking_config.xlsx

---

**Document Version:** 2.1
**Last Updated:** 2025-12-02
**Changes in v2.1:**
- Added "Known Limitations and Considerations" section
- Documented effective N usage in significance testing
- Documented data cleaning scope (question columns only)
- Documented environment requirements
- Listed future enhancement priorities

**Changes in v2.0:**
- Added TrackingSpecs section with comprehensive documentation
- Documented enhanced rating metrics (top_box, top2_box, etc.)
- Documented Multi_Mention question support
- Documented enhanced composite metrics
- Added output_dir setting documentation
- Updated examples throughout

**Next Review:** Q2 2026

---

## Example Workflows

## Workflow 1: Quarterly Brand Tracking (Basic)

### Scenario

You run a quarterly brand tracking study measuring:
- Brand awareness (unaided and aided)
- Brand consideration
- Brand preference
- Purchase intent

You have 4 quarters of data and want to identify trends.

### Step 1: Organize Your Data

**Directory Structure:**
```
brand_tracking/
├── data/
│   ├── Q1_2024.csv
│   ├── Q2_2024.csv
│   ├── Q3_2024.csv
│   └── Q4_2024.csv
├── config/
│   └── tracking_config.xlsx
└── output/
```

**Q1_2024.csv (500 respondents):**
```
RespondentID,Q1_Unaided,Q2_Aided,Q3_Consideration,Q4_Preference,Q5_PurchaseIntent
1,Brand A,Brand A,Brand A,Brand A,1
2,None,Brand B,Brand B,Brand B,0
3,Brand C,Brand C,Brand C,Brand C,1
...
```

**Each Quarter Same Structure:**
- Same question codes
- Same response options
- Similar sample size (~500 per wave)

### Step 2: Create Configuration File

**config/tracking_config.xlsx**

**Sheet 1: Waves**
```
WaveID | WaveName       | DataFile      | FieldworkStart | FieldworkEnd  | WeightVariable
W1     | Q1 2024        | Q1_2024.csv   | 2024-01-01     | 2024-01-15    | NA
W2     | Q2 2024        | Q2_2024.csv   | 2024-04-01     | 2024-04-15    | NA
W3     | Q3 2024        | Q3_2024.csv   | 2024-07-01     | 2024-07-15    | NA
W4     | Q4 2024        | Q4_2024.csv   | 2024-10-01     | 2024-10-15    | NA
```

**Sheet 2: TrackedQuestions**
```
QuestionCode       | QuestionText                  | QuestionType
Q1_Unaided         | Brand Awareness (Unaided)     | proportion
Q2_Aided           | Brand Awareness (Aided)       | proportion
Q3_Consideration   | Brand Consideration           | proportion
Q4_Preference      | Brand Preference              | proportion
Q5_PurchaseIntent  | Purchase Intent (0/1)         | proportion
```

**Sheet 3: Banner**
```
BreakVariable | BreakLabel
Total         | Total
```

**Sheet 4: Settings**
```
SettingName         | SettingValue
project_name        | 2024 Brand Tracking Study
output_file         | output/Brand_Tracking_2024.xlsx
confidence_level    | 0.95
min_base_size       | 30
trend_significance  | TRUE
```

### Step 3: Run Analysis

```r
# Load Turas
source("/path/to/Turas/turas.R")
turas_load("tracker")

# Set working directory
setwd("/path/to/brand_tracking")

# Run tracker (no question mapping needed - codes consistent)
result <- run_tracker(
  tracking_config_path = "config/tracking_config.xlsx",
  question_mapping_path = NA,  # Not needed - same codes across waves
  data_dir = "data/"
)

cat("Analysis complete! Output:", result, "\n")
```

### Step 4: Interpret Results

**Brand_Tracking_2024.xlsx - Summary Sheet:**

```
2024 BRAND TRACKING - SUMMARY
Generated: 2024-10-16 10:30:00

Question                    Q1      Q2      Trend   Q3      Trend   Q4      Trend
                           2024    2024            2024            2024

Brand Awareness (Unaided)
  Brand A              %   42%     45%     →       48%     →       52%     ↑
  Brand B              %   28%     30%     →       32%     →       33%     →
  Brand C              %   18%     16%     →       14%     →       11%     ↓
  None                 %   12%     9%      →       6%      →       4%      →

Brand Preference
  Brand A              %   38%     40%     →       43%     →       47%     ↑
  Brand B              %   32%     33%     →       34%     →       35%     →
  Brand C              %   20%     18%     →       16%     ↓       13%     →

Purchase Intent       %   45%     48%     →       52%     →       56%     ↑
```

**Key Insights:**

1. **Brand A Growing:**
   - Unaided awareness: 42% → 52% over year (significant increase in Q4)
   - Preference: 38% → 47% (significant increase in Q4)
   - Clear upward momentum

2. **Brand C Declining:**
   - Unaided awareness: 18% → 11% (significant drop in Q4)
   - Preference: 20% → 13% (significant drop in Q3)
   - Concerning downward trend

3. **Brand B Stable:**
   - Metrics flat across all quarters
   - Maintaining position but not growing

4. **Purchase Intent Rising:**
   - 45% → 56% over year (significant increase in Q4)
   - Category growth or Brand A effect?

**Action Items:**
- Investigate Brand A success factors (campaigns, product changes?)
- Analyze Brand C decline (competitive pressure, quality issues?)
- Monitor Brand B - risk of stagnation

---

## Workflow 2: Customer Satisfaction Tracking with NPS

### Scenario

Monthly customer satisfaction tracking measuring:
- Overall satisfaction (1-5 scale)
- Net Promoter Score (0-10 scale)
- Service quality (1-5 scale)
- Value for money (1-5 scale)

You have 6 months of data (Jan-Jun 2024).

### Step 1: Prepare Data

**Data Structure (each month same):**

```
# satisfaction_jan.csv
CustomerID,Segment,Q1_OverallSat,Q2_NPS,Q3_ServiceQuality,Q4_Value
1001,Enterprise,5,10,5,4
1002,SMB,4,9,4,4
1003,Consumer,3,7,3,3
...
```

### Step 2: Create Configuration

**tracking_config.xlsx - Waves:**
```
WaveID | WaveName    | DataFile              | FieldworkStart | FieldworkEnd
W1     | January     | satisfaction_jan.csv  | 2024-01-01     | 2024-01-31
W2     | February    | satisfaction_feb.csv  | 2024-02-01     | 2024-02-29
W3     | March       | satisfaction_mar.csv  | 2024-03-01     | 2024-03-31
W4     | April       | satisfaction_apr.csv  | 2024-04-01     | 2024-04-30
W5     | May         | satisfaction_may.csv  | 2024-05-01     | 2024-05-31
W6     | June        | satisfaction_jun.csv  | 2024-06-01     | 2024-06-30
```

**TrackedQuestions:**
```
QuestionCode        | QuestionText                      | QuestionType
Q1_OverallSat       | Overall Satisfaction (1-5)        | rating
Q2_NPS              | Net Promoter Score (0-10)         | nps
Q3_ServiceQuality   | Service Quality (1-5)             | rating
Q4_Value            | Value for Money (1-5)             | rating
```

**Banner (for demographic analysis):**
```
BreakVariable | BreakLabel
Total         | Total
Segment       | Customer Segment
```

**Settings:**
```
SettingName          | SettingValue
project_name         | H1 2024 Customer Satisfaction Tracking
output_file          | Customer_Sat_H1_2024.xlsx
confidence_level     | 0.95
min_base_size        | 50
decimal_places_mean  | 2
```

### Step 3: Run Analysis with Banner

```r
source("/path/to/Turas/turas.R")
turas_load("tracker")

result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA,
  data_dir = "data/",
  use_banners = TRUE  # Enable banner analysis by segment
)
```

### Step 4: Interpret Results

**Customer_Sat_H1_2024.xlsx - Q2_NPS Sheet:**

```
Net Promoter Score (0-10)

TOTAL
            Jan     Feb     Trend   Mar     Trend   Apr     Trend   May     Trend   Jun     Trend
Base (n=)   1000    1000            1000            1000            1000            1000

% Promoters 35%     38%     →       42%     →       45%     →       48%     →       52%     ↑
% Passives  40%     40%     →       38%     →       35%     →       33%     →       30%     →
% Detractors 25%    22%     →       20%     →       20%     →       19%     →       18%     →
NPS Score   10      16      →       22      →       25      →       29      →       34      ↑

BY SEGMENT
                January         February        March           April           May             June
            Ent  SMB  Con   Ent  SMB  Con   Ent  SMB  Con   Ent  SMB  Con   Ent  SMB  Con   Ent  SMB  Con
Base (n=)   300  400  300   300  400  300   300  400  300   300  400  300   300  400  300   300  400  300

NPS Score   25   10   -5    28   12   0     32   15   5     35   18   8     38   22   12    42   25   15
Trend                       →    →    →     →    →    →     →    →    →     →    →    →     →    →    →
```

**Key Insights:**

1. **Overall NPS Improving:**
   - January: 10 → June: 34 (significant increase in June)
   - Consistent month-over-month improvement
   - Promoters increasing (35% → 52%), Detractors decreasing (25% → 18%)

2. **Segment Patterns:**
   - **Enterprise:** Highest NPS (42 in June), steady growth
   - **SMB:** Moderate NPS (25 in June), improving
   - **Consumer:** Lowest NPS (15 in June) but showing biggest improvement rate

3. **Detractor Reduction:**
   - Overall detractors down from 25% to 18%
   - Suggests service quality improvements effective

**Action Items:**
- Understand what drove June surge in promoters
- Focus on converting SMB passives to promoters
- Continue improving consumer experience (highest growth potential)

---

## Workflow 3: Tracking with Question Code Changes

### Scenario

Your brand tracking study restructured questionnaire between Wave 2 and Wave 3:
- Questions renumbered
- Some questions reworded slightly
- New questions added

You need to track metrics despite these changes.

### Step 1: Identify Question Changes

**Wave 1 & 2 Structure:**
```
Q1_BrandAwareness
Q2_Consideration
Q3_Preference
Q4_Satisfaction
```

**Wave 3 & 4 Structure (after restructure):**
```
Q01_Aware_Unaided    # Same as old Q1_BrandAwareness
Q02_Consideration    # Same as old Q2_Consideration
Q03_BrandPref        # Same as old Q3_Preference
Q04_OverallSat       # Same as old Q4_Satisfaction
Q05_NewMetric        # NEW question
```

### Step 2: Create Question Mapping

**question_mapping.xlsx - QuestionMap Sheet:**

```
QuestionCode        | QuestionType | QuestionText                  | W1                | W2                | W3                  | W4
Q01_BrandAwareness  | proportion   | Brand Awareness (Unaided)     | Q1_BrandAwareness | Q1_BrandAwareness | Q01_Aware_Unaided   | Q01_Aware_Unaided
Q02_Consideration   | proportion   | Brand Consideration           | Q2_Consideration  | Q2_Consideration  | Q02_Consideration   | Q02_Consideration
Q03_Preference      | proportion   | Brand Preference              | Q3_Preference     | Q3_Preference     | Q03_BrandPref       | Q03_BrandPref
Q04_Satisfaction    | rating       | Overall Satisfaction (1-5)    | Q4_Satisfaction   | Q4_Satisfaction   | Q04_OverallSat      | Q04_OverallSat
Q05_NewMetric       | rating       | New Quality Metric (1-5)      | NA                | NA                | Q05_NewMetric       | Q05_NewMetric
```

**Key Points:**
- **QuestionCode:** Standardized code used in tracking_config.xlsx
- **W1, W2, W3, W4:** Actual column names in each wave's data file
- **NA:** Question not asked in that wave

### Step 3: Create Tracking Configuration

**tracking_config.xlsx - TrackedQuestions:**

```
QuestionCode        | QuestionText                  | QuestionType
Q01_BrandAwareness  | Brand Awareness (Unaided)     | proportion
Q02_Consideration   | Brand Consideration           | proportion
Q03_Preference      | Brand Preference              | proportion
Q04_Satisfaction    | Overall Satisfaction (1-5)    | rating
Q05_NewMetric       | New Quality Metric (1-5)      | rating
```

**Note:** Use standardized QuestionCode, not wave-specific codes!

### Step 4: Run Analysis with Mapping

```r
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = "question_mapping.xlsx",  # ← Include mapping
  data_dir = "data/"
)
```

### Step 5: Interpret Results

**Results.xlsx - Q01_BrandAwareness Sheet:**

```
Brand Awareness (Unaided)
            Wave 1      Wave 2      Trend   Wave 3      Trend   Wave 4      Trend
            Q1 2024     Q2 2024             Q3 2024             Q4 2024
Base (n=)   500         500                 500                 500

Brand A %   42%         45%         →       48%         →       52%         ↑
Brand B %   30%         32%         →       33%         →       34%         →
Brand C %   18%         16%         →       14%         →       11%         ↓

Source: Wave 1-2 from Q1_BrandAwareness, Wave 3-4 from Q01_Aware_Unaided
```

**Q05_NewMetric Sheet:**

```
New Quality Metric (1-5)
            Wave 1  Wave 2  Wave 3      Trend   Wave 4      Trend
Base (n=)   —       —       500                 500

Mean Score  —       —       3.8                 4.0         →
Std Dev     —       —       1.1                 1.0

Note: Question introduced in Wave 3
```

**Key Benefits of Mapping:**
1. **Continuous Tracking:** Trends calculated despite code changes
2. **Historical Comparison:** Can compare across restructure
3. **Flexibility:** Easy to add/remove questions between waves
4. **Documentation:** Mapping file documents all changes

---

## Workflow 4: Multi-Banner Demographic Tracking

### Scenario

Track brand metrics across multiple demographic segments:
- Gender (Male, Female)
- Age Group (18-34, 35-54, 55+)
- Region (North, South, East, West)

Identify which segments showing growth/decline.

### Step 1: Ensure Data Includes Banner Variables

**wave1.csv:**
```
RespondentID,Gender,Age_Group,Region,Q1_Awareness,Q2_Consideration,Q3_Preference
1,Male,18-34,North,Brand A,Brand A,Brand A
2,Female,35-54,South,Brand B,Brand B,Brand B
3,Male,55+,East,Brand C,Brand C,Brand C
...
```

**All waves must include:** Gender, Age_Group, Region columns with consistent values.

### Step 2: Configure Banner Analysis

**tracking_config.xlsx - Banner Sheet:**

```
BreakVariable | BreakLabel
Total         | Total
Gender        | Gender
Age_Group     | Age Group
Region        | Region
```

**Waves Sheet:**
```
WaveID | WaveName  | DataFile   | FieldworkStart | FieldworkEnd
W1     | Wave 1    | wave1.csv  | 2024-01-15     | 2024-01-30
W2     | Wave 2    | wave2.csv  | 2024-04-15     | 2024-04-30
W3     | Wave 3    | wave3.csv  | 2024-07-15     | 2024-07-30
```

**TrackedQuestions:**
```
QuestionCode     | QuestionText          | QuestionType
Q1_Awareness     | Brand Awareness       | proportion
Q2_Consideration | Brand Consideration   | proportion
Q3_Preference    | Brand Preference      | proportion
```

### Step 3: Run with Banner Analysis

```r
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA,
  data_dir = "data/",
  use_banners = TRUE  # ← Enable banner breakouts
)
```

### Step 4: Interpret Banner Results

**Results.xlsx - Q1_Awareness_Gender Sheet:**

```
Brand Awareness - By Gender

Brand A
                    Wave 1              Wave 2              Wave 3
                Male    Female      Male    Female      Male    Female
Base (n=)       250     250         250     250         250     250

Brand A    %    48%     36%         50%     40%         58%     46%
Trend                               →       →           ↑       ↑

Brand B    %    28%     32%         30%     34%         31%     35%
Trend                               →       →           →       →
```

**Q1_Awareness_Age_Group Sheet:**

```
Brand Awareness - By Age Group

Brand A
                Wave 1                      Wave 2                      Wave 3
            18-34   35-54   55+         18-34   35-54   55+         18-34   35-54   55+
Base (n=)   180     200     120         180     200     120         180     200     120

Brand A %   52%     40%     32%         55%     42%     34%         62%     48%     38%
Trend                                   →       →       →           ↑       ↑       →
```

**Key Insights from Banner Analysis:**

1. **Gender Differences:**
   - Males consistently higher awareness of Brand A (48% vs 36%)
   - Both genders showed significant increase in Wave 3
   - Gap narrowing over time (W1: 12pt gap → W3: 12pt gap maintained)

2. **Age Pattern:**
   - Younger respondents (18-34) highest awareness (62% in W3)
   - Significant increases for 18-34 and 35-54 in Wave 3
   - 55+ segment stable (no significant change)

3. **Strategic Implications:**
   - Brand A strongest among young males
   - Growth opportunity with older demographics
   - Consider targeted campaigns for 55+ segment

---

## Workflow 5: Weighted Tracking Study

### Scenario

Your tracking study data needs weighting to match population demographics. Each wave has different weight distributions due to sampling variations.

### Step 1: Prepare Data with Weights

**wave1.csv:**
```
RespondentID,Gender,Age,Q1_Awareness,Q2_Satisfaction,Weight
1,Male,25,Brand A,5,1.2
2,Female,45,Brand B,4,0.8
3,Male,60,Brand C,3,1.5
...
```

**Weight Explanation:**
- Weight > 1.0: Under-represented in sample (upweight)
- Weight < 1.0: Over-represented in sample (downweight)
- Average weight ≈ 1.0

### Step 2: Configure Weighting

**tracking_config.xlsx - Waves Sheet:**

```
WaveID | WaveName | DataFile   | FieldworkStart | FieldworkEnd | WeightVariable
W1     | Wave 1   | wave1.csv  | 2024-01-15     | 2024-01-30   | Weight
W2     | Wave 2   | wave2.csv  | 2024-04-15     | 2024-04-30   | Weight
W3     | Wave 3   | wave3.csv  | 2024-07-15     | 2024-07-30   | Weight
W4     | Wave 4   | wave4.csv  | 2024-10-15     | 2024-10-30   | Weight
```

**Key:** Specify WeightVariable = "Weight" (column name in data)

### Step 3: Run Analysis

```r
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA
)
```

**Tracker automatically:**
1. Loads weight column from each wave
2. Applies weights to all calculations (means, proportions)
3. Calculates Design Effect (DEFF)
4. Uses effective sample size for significance testing

### Step 4: Understand Weighted Results

**Results.xlsx - Q2_Satisfaction Sheet:**

```
Overall Satisfaction (1-5 scale)

                Wave 1      Wave 2      Trend   Wave 3      Trend   Wave 4      Trend
Base (n=)
  Unweighted    500         500                 500                 500
  Weighted      500         500                 500                 500
  Effective     450         455                 448                 452
  DEFF          1.11        1.10                1.12                1.11

Mean Score      3.8         3.9         →       4.1         ↑       4.2         →
Std Dev         1.2         1.1                 1.0                 1.0
```

**Understanding the Bases:**

- **Unweighted:** Actual number of respondents (500)
- **Weighted:** Sum of weights ≈ sample size (500)
- **Effective:** Accounts for weight variance (450)
  - Effective < Weighted due to weighting impact
  - Used for significance testing
- **DEFF:** Design Effect = Weighted / Effective ≈ 1.11
  - DEFF = 1.0: No weighting impact
  - DEFF = 1.1: Moderate impact (10% reduction in effective n)
  - DEFF > 1.5: High impact (significant efficiency loss)

**Impact on Significance:**

```
Without weighting adjustment (wrong):
  Use n = 500 → overstates significance

With DEFF adjustment (correct):
  Use n_eff = 450 → appropriate significance
```

**Wave 2 → Wave 3 trend:**
- Mean increased 3.9 → 4.1
- Significant (↑) because increase meaningful relative to effective sample sizes
- If used unweighted n=500, would be even more significant (but wrong!)

---

## Workflow 6: Adding New Waves to Existing Tracker

### Scenario

You have a tracking study with 3 waves. Wave 4 data just became available. You want to add it to the existing analysis.

### Step 1: Current Setup

**Existing Configuration:**

```
tracking_config.xlsx - Waves:
W1 | Q1 2024 | wave1.csv | 2024-01-15
W2 | Q2 2024 | wave2.csv | 2024-04-15
W3 | Q3 2024 | wave3.csv | 2024-07-15
```

**Existing Output:**
- Previous results file: Brand_Tracking_Q1-Q3_2024.xlsx
- Shows trends through Q3

### Step 2: Add New Wave

**Update tracking_config.xlsx - Waves Sheet:**

```
WaveID | WaveName | DataFile   | FieldworkStart | FieldworkEnd
W1     | Q1 2024  | wave1.csv  | 2024-01-15     | 2024-01-30
W2     | Q2 2024  | wave2.csv  | 2024-04-15     | 2024-04-30
W3     | Q3 2024  | wave3.csv  | 2024-07-15     | 2024-07-30
W4     | Q4 2024  | wave4.csv  | 2024-10-15     | 2024-10-30  ← NEW ROW
```

**Update Settings if needed:**

```
SettingName  | SettingValue
output_file  | Brand_Tracking_Full_Year_2024.xlsx  ← Updated filename
```

**No other changes needed!**
- TrackedQuestions sheet unchanged
- Banner sheet unchanged
- Question mapping unchanged (if using)

### Step 3: Verify New Wave Data

**Check wave4.csv:**

```r
# Quick validation before running full analysis
library(readr)

wave4 <- read.csv("data/wave4.csv")

# Check sample size
nrow(wave4)  # Should be similar to previous waves (e.g., ~500)

# Check column names match previous waves
names(wave4)

# Check for required questions
required_cols <- c("Q1_Awareness", "Q2_Consideration", "Q3_Preference")
all(required_cols %in% names(wave4))  # Should be TRUE
```

### Step 4: Re-run Analysis

```r
source("/path/to/Turas/turas.R")
turas_load("tracker")

# Run with updated configuration (now includes W4)
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA
)
```

**Processing Output:**

```
================================================================================
TURASTACKER - MVT PHASE 2: TREND CALCULATION & OUTPUT
================================================================================
Started: 2024-10-16 10:30:00

[1/6] LOADING CONFIGURATION
Project: Brand Tracking Study
Waves: Q1 2024, Q2 2024, Q3 2024, Q4 2024  ← Now includes Q4!

[4/6] LOADING WAVE DATA
  Loading Wave W1: Q1 2024
    Loaded 500 records
  Loading Wave W2: Q2 2024
    Loaded 500 records
  Loading Wave W3: Q3 2024
    Loaded 500 records
  Loading Wave W4: Q4 2024  ← NEW
    Loaded 500 records  ← NEW

[7/8] CALCULATING TRENDS
Processing question: Q1_Awareness
  ✓ Trend calculated
...

Analysis complete!
```

### Step 5: Review Updated Results

**Brand_Tracking_Full_Year_2024.xlsx - Summary:**

```
                    Q1      Q2      Trend   Q3      Trend   Q4      Trend
Brand A        %    42%     45%     →       48%     →       52%     ↑      ← NEW
Brand B        %    30%     32%     →       33%     →       34%     →      ← NEW
```

**Now shows:**
- All 4 quarters
- Trends Q1→Q2, Q2→Q3, Q3→Q4
- Latest quarter (Q4) highlighted

**Key Benefits:**
- No data re-entry for old waves
- Consistent methodology across all waves
- Easy to add future waves (Q1 2025, Q2 2025, ...)

---

## Workflow 7: Composite Metric Tracking

### Scenario

You want to track a "Brand Health Index" that combines multiple metrics:
- Brand Health Index = Average of (Awareness + Consideration + Preference)

Track this composite metric alongside individual metrics.

### Step 1: Define Composite in Question Mapping

**question_mapping.xlsx - QuestionMap Sheet:**

```
QuestionCode        | QuestionType | QuestionText                      | CompositeFormula        | W1    | W2    | W3
Q1_Awareness        | proportion   | Brand Awareness                   |                         | Q1    | Q1    | Q1
Q2_Consideration    | proportion   | Brand Consideration               |                         | Q2    | Q2    | Q2
Q3_Preference       | proportion   | Brand Preference                  |                         | Q3    | Q3    | Q3
COMP_BrandHealth    | composite    | Brand Health Index (Composite)    | mean(Q1,Q2,Q3)          | —     | —     | —
```

**CompositeFormula:**
- `mean(Q1,Q2,Q3)` — Average of three proportion questions
- Calculated from raw data, not from percentages in output

### Step 2: Configure Composite Tracking

**tracking_config.xlsx - TrackedQuestions:**

```
QuestionCode        | QuestionText                      | QuestionType
Q1_Awareness        | Brand Awareness                   | proportion
Q2_Consideration    | Brand Consideration               | proportion
Q3_Preference       | Brand Preference                  | proportion
COMP_BrandHealth    | Brand Health Index                | composite
```

### Step 3: Run Analysis

```r
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = "question_mapping.xlsx",
  use_banners = FALSE
)
```

### Step 4: Interpret Composite Results

**Results.xlsx - COMP_BrandHealth Sheet:**

```
Brand Health Index
Composite of: Brand Awareness + Brand Consideration + Brand Preference

                Wave 1      Wave 2      Trend   Wave 3      Trend
Base (n=)       500         500                 500

Index Score     38          40          →       44          ↑

Component Trends:
  Awareness     42%         45%         →       48%         →
  Consideration 38%         40%         →       43%         →
  Preference    34%         35%         →       41%         ↑

Interpretation:
- Overall brand health improved significantly in Wave 3
- Driven primarily by increase in Preference
- Awareness and Consideration also positive but stable
```

**Composite vs Individual Metrics:**

| Metric | Wave 1 | Wave 2 | Wave 3 | Pattern |
|--------|--------|--------|--------|---------|
| **Awareness** | 42% | 45% | 48% | Steady increase |
| **Consideration** | 38% | 40% | 43% | Steady increase |
| **Preference** | 34% | 35% | 41% | Spike in W3 |
| **Composite (Avg)** | 38 | 40 | 44 | Accelerating growth |

**Benefits of Composite Metrics:**
1. **Single Summary Number:** Easy to communicate
2. **Trend Detection:** May be significant when components aren't
3. **Balanced View:** Combines multiple dimensions
4. **Executive Reporting:** Simple KPI for dashboards

---

## Workflow 8: Integration with Turas Tabs

### Scenario

You run Tabs module for cross-tabulation each wave, then want to track specific Tabs metrics over time using Tracker.

**Use Case:**
- Run detailed crosstabs for each wave (brand × demographics)
- Extract key metrics from Tabs output
- Track those metrics across waves

### Step 1: Run Tabs for Each Wave

**Wave 1 Analysis:**

```r
# Load Turas
source("/path/to/Turas/turas.R")
turas_load("tabs")

# Run tabs for Wave 1
setwd("/path/to/wave1_project")
tabs_result_w1 <- run_crosstabs(
  config_file = "Tabs_Config_W1.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)
# Output: Wave1_Crosstabs.xlsx
```

**Repeat for Wave 2, Wave 3, Wave 4:**

```r
# Wave 2
setwd("/path/to/wave2_project")
tabs_result_w2 <- run_crosstabs(...)
# Output: Wave2_Crosstabs.xlsx

# Wave 3
setwd("/path/to/wave3_project")
tabs_result_w3 <- run_crosstabs(...)
# Output: Wave3_Crosstabs.xlsx
```

### Step 2: Extract Metrics from Tabs Outputs

**Create data files for Tracker from Tabs results:**

**Method 1: Manual Extraction**

From each Wave's Tabs output, extract key metrics to CSV:

**tracking_data_wave1.csv:**
```
Metric,Value
BrandA_Awareness,42
BrandB_Awareness,30
BrandC_Awareness,18
BrandA_Preference,38
BrandB_Preference,32
BrandC_Preference,20
OverallSatisfaction,3.8
NPS,15
```

**tracking_data_wave2.csv, wave3.csv, wave4.csv:** Same structure

**Method 2: Programmatic Extraction (Recommended)**

```r
# Function to extract metrics from Tabs output
extract_tabs_metrics <- function(tabs_result, wave_id) {

  # Extract Brand A awareness from Q01 result
  q01 <- tabs_result$all_results[["Q01_Awareness"]]
  brand_a_row <- q01$table[q01$table$RowLabel == "Brand A" & q01$table$RowType == "Column %", ]
  brand_a_awareness <- as.numeric(brand_a_row$Total)

  # Extract other metrics similarly...

  # Create data frame
  metrics <- data.frame(
    Metric = c("BrandA_Awareness", "BrandB_Awareness", ...),
    Value = c(brand_a_awareness, brand_b_awareness, ...)
  )

  # Write to file
  write.csv(metrics, paste0("tracking_data_", wave_id, ".csv"), row.names = FALSE)

  return(metrics)
}

# Extract for all waves
metrics_w1 <- extract_tabs_metrics(tabs_result_w1, "wave1")
metrics_w2 <- extract_tabs_metrics(tabs_result_w2, "wave2")
metrics_w3 <- extract_tabs_metrics(tabs_result_w3, "wave3")
```

### Step 3: Configure Tracker

**tracking_config.xlsx:**

**Waves:**
```
WaveID | WaveName | DataFile                  | FieldworkStart
W1     | Wave 1   | tracking_data_wave1.csv   | 2024-01-15
W2     | Wave 2   | tracking_data_wave2.csv   | 2024-04-15
W3     | Wave 3   | tracking_data_wave3.csv   | 2024-07-15
```

**TrackedQuestions:**
```
QuestionCode         | QuestionText              | QuestionType
BrandA_Awareness     | Brand A Awareness         | rating
BrandB_Awareness     | Brand B Awareness         | rating
BrandA_Preference    | Brand A Preference        | rating
OverallSatisfaction  | Overall Satisfaction      | rating
NPS                  | Net Promoter Score        | rating
```

**Note:** Using "rating" type to track the numeric values extracted from Tabs.

### Step 4: Run Tracker

```r
turas_load("tracker")

result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA
)
```

### Step 5: Unified Reporting

**Now you have:**
1. **Detailed Tabs outputs** — Wave-by-wave cross-tabulation analysis
2. **Tracker summary** — Key metrics trended over time

**Tabs Output (Wave 3):**
- Detailed breakdown: Brand A awareness by Gender, Age, Region
- Significance testing within wave
- Full crosstabs with all response options

**Tracker Output:**
- Brand A awareness trend: W1 (42%) → W2 (45%) → W3 (48%)
- Trend indicators showing significant increases
- Comparison across all waves

**Benefits:**
- **Best of both worlds:** Detail (Tabs) + Trends (Tracker)
- **Consistent methodology:** Same Survey_Structure used by both
- **Efficient workflow:** Run Tabs routinely, consolidate with Tracker

---

## Common Patterns and Tips

### Pattern 1: Quarterly Business Reviews

```r
# Run tracker before each QBR
result <- run_tracker(
  tracking_config_path = "QBR_config.xlsx",
  question_mapping_path = NA
)

# Email results to stakeholders
library(blastula)
email <- compose_email(
  body = md("# Q4 2024 Tracking Results\n\nPlease find attached the latest tracking analysis.")
) %>%
  add_attachment(result)

smtp_send(email, to = "team@company.com", ...)
```

### Pattern 2: Automated Monthly Tracking

```r
# Scheduled script (cron job / Task Scheduler)
library(lubridate)

# Current month
current_month <- format(Sys.Date(), "%Y-%m")

# Add new wave to config
# (Assumes wave data file follows naming convention)

result <- run_tracker(
  tracking_config_path = "monthly_tracking_config.xlsx",
  question_mapping_path = NA,
  output_path = paste0("output/Tracking_", current_month, ".xlsx")
)

# Auto-email results
```

### Pattern 3: Year-over-Year Comparison

```r
# Configure waves for YoY comparison
# Q1 2023, Q2 2023, Q3 2023, Q4 2023
# Q1 2024, Q2 2024, Q3 2024, Q4 2024

# Trends calculated:
# Q1 2023 → Q2 2023 → Q3 2023 → Q4 2023 → Q1 2024 → Q2 2024 ...

# Manually compare:
# Q1 2024 vs Q1 2023
# Q2 2024 vs Q2 2023
# etc.
```

### Pattern 4: Segment Deep-Dive

```r
# Run overall tracking
result_overall <- run_tracker(
  tracking_config_path = "config_overall.xlsx",
  use_banners = FALSE
)

# Run banner analysis for key segments
result_banners <- run_tracker(
  tracking_config_path = "config_banners.xlsx",
  use_banners = TRUE
)

# Compare overall vs segment trends
```

---

## Troubleshooting Workflows

### Issue: Trends Not Significant Despite Large Changes

**Example:**
```
Wave 1: 45%
Wave 2: 50%  (5 percentage point increase)
Trend: → (stable, not significant!)
```

**Cause:** Small sample sizes

**Solution:**

```r
# Check sample sizes
# If n < 100 per wave, hard to detect 5pt change

# Options:
# 1. Increase sample size in future waves
# 2. Lower confidence level (0.90 instead of 0.95)
# 3. Accept that change may not be significant
# 4. Look for trend pattern across multiple waves
```

### Issue: Missing Data in Some Waves

**Example:**
```
Question Q05 exists in Wave 3 and 4, but not Wave 1 and 2
```

**Solution:**

```r
# In question_mapping.xlsx:
QuestionCode | W1  | W2  | W3      | W4
Q05          | NA  | NA  | Q5_New  | Q5_New

# Tracker will show:
# Wave 1: — (not available)
# Wave 2: — (not available)
# Wave 3: 3.8
# Wave 4: 4.0 (trend from W3)
```

### Issue: Different Sample Sizes Across Waves

**Example:**
```
Wave 1: n=500
Wave 2: n=300  (recruitment issues)
Wave 3: n=500
```

**This is OK!** Tracker handles different sample sizes correctly in significance testing.

**But consider:**
- Why did Wave 2 have lower n?
- Fielding issues?
- Seasonal variation?
- May affect power to detect trends in/out of Wave 2

---

## Next Steps

**After mastering these workflows:**

1. **Create Templates** — Save your configurations for reuse
2. **Automate** — Schedule regular tracking runs
3. **Integrate** — Combine with Tabs, Parser, other Turas modules
4. **Customize** — Add custom composite metrics for your business
5. **Scale** — Apply to multiple tracking studies

**Additional Resources:**
- USER_MANUAL.md — Complete feature reference
- TECHNICAL_DOCUMENTATION.md — Developer guide
- QUICK_START.md — 15-minute introduction

---

**Document Version:** 1.0
**Last Updated:** 2025-11-18

---

## Testing Walkthrough

# Tracker Enhancements - Testing Walkthrough

This guide walks you through testing the Phase 1 & 2 enhancements to ensure everything works correctly.

## Quick Start - Basic Functionality Test

Run the basic test script to verify core functions load and work:

```bash
cd /home/user/Turas/modules/tracker
Rscript test_data/test_enhancements.R
```

**Expected Output:**
- ✓ All functions should load successfully
- ✓ TrackingSpecs validation should pass/fail appropriately
- ✓ Multi-mention column detection should work
- ✓ Rating calculations should produce correct percentages

---

## Step-by-Step Testing

### TEST 1: Backward Compatibility (No Breaking Changes)

**Purpose:** Verify existing tracker configs still work without any changes.

**Steps:**
1. Find an existing tracker configuration (or use a template)
2. Run tracker WITHOUT adding TrackingSpecs column
3. Verify output matches previous behavior

**Expected Result:**
- Rating questions show "Mean" (default behavior)
- NPS questions show NPS score
- No errors or warnings about missing TrackingSpecs

**How to verify:**
```r
# In R console
setwd("/home/user/Turas/modules/tracker")
source("run_tracker.R")

# Load existing config (use your own config file)
# Should work exactly as before
```

---

### TEST 2: Enhanced Rating Metrics

**Purpose:** Test new rating question capabilities (top_box, ranges, etc.)

**Setup:**
1. Open your `question_mapping.xlsx`
2. Add a new column called `TrackingSpecs` (if not present)
3. For a rating question, add specs like:
   - `mean,top2_box` - Shows both mean and top 2 box
   - `range:9-10` - Shows % rating 9-10
   - `top_box,bottom_box` - Shows both ends of scale

**Example question_mapping.xlsx:**

| QuestionCode | QuestionText | QuestionType | TrackingSpecs | Wave1 | Wave2 |
|--------------|--------------|--------------|---------------|-------|-------|
| Q_SAT | Overall satisfaction (1-10) | Rating | mean,top2_box,range:9-10 | Q10 | Q11 |
| Q_LIKELY | Likelihood to recommend | Rating | top_box,mean | Q12 | Q13 |

**Expected Output in Excel:**
- Q_SAT sheet shows 3 rows: Mean, Top 2 Box %, % 9-10
- Q_LIKELY sheet shows 2 rows: Top Box %, Mean
- All values calculated correctly across waves

---

### TEST 3: Multi_Mention Questions

**Purpose:** Test multi-select question support with auto-detection.

**Setup:**
1. Create a multi-mention question with columns like:
   - Q30_1, Q30_2, Q30_3, Q30_4 (coded as 1/0)
2. In question_mapping.xlsx:

| QuestionCode | QuestionText | QuestionType | TrackingSpecs | Wave1 | Wave2 |
|--------------|--------------|---------------|---------------|-------|-------|
| Q30 | Features used (select all) | Multi_Mention | auto | Q30 | Q30 |

**Expected Behavior:**
- Tracker auto-detects Q30_1, Q30_2, Q30_3, Q30_4
- Sorts them numerically (Q30_1, Q30_2, ... Q30_10, Q30_11)
- Calculates % mentioning each option
- Shows all options in Excel output

**Advanced TrackingSpecs:**
```
auto,any,count_mean
```
This shows:
- % mentioning each option
- % mentioning at least one option (any)
- Mean number of options mentioned (count_mean)

**Selective tracking:**
```
option:Q30_1,option:Q30_3,any
```
Only tracks Q30_1 and Q30_3, plus "any" metric.

---

### TEST 4: Composite Questions with Enhanced Metrics

**Purpose:** Test that composites can use same metrics as ratings.

**Setup:**
1. Create a composite question with source questions
2. Add TrackingSpecs for the composite:

| QuestionCode | QuestionText | QuestionType | SourceQuestions | TrackingSpecs | Wave1 | Wave2 |
|--------------|--------------|--------------|-----------------|---------------|-------|-------|
| CX_INDEX | Customer Experience Index | Composite | Q10,Q11,Q12 | mean,top2_box,range:9-10 | - | - |

**Expected Output:**
- Composite calculated as mean of Q10, Q11, Q12
- Then enhanced metrics applied to composite scores
- Shows mean, top 2 box %, and % 9-10 of the composite

---

## Validation Checks

The tracker includes enhanced validation. Run tracker and check for:

**✓ Pre-flight Validation Messages:**
```
7. Validating TrackingSpecs...
  Question 'Q_SAT': TrackingSpecs validated (mean,top2_box)
  2 questions have custom TrackingSpecs
```

**✗ Error Detection:**
Try adding an invalid spec to test error handling:
- Add `TrackingSpecs: range:9-10` to an NPS question
- Should show error: "range:9-10 is only valid for Rating or Composite questions"

---

## Common Issues & Solutions

### Issue: "No multi-mention columns found"
**Cause:** Column naming doesn't match pattern or wave code wrong
**Solution:** Ensure columns are named {WaveCode}_{number} (e.g., Q30_1, Q30_2)

### Issue: "TrackingSpecs column not found"
**Cause:** Column name misspelled or missing
**Solution:** Add "TrackingSpecs" column to question_mapping.xlsx (exact spelling, case-sensitive)

### Issue: Top box shows 0%
**Cause:** Scale detection issue or data coding
**Solution:** Check that rating values are numeric (not text), verify scale matches expectations

---

## Verification Checklist

Run through this checklist to confirm everything works:

- [ ] Basic test script runs without errors
- [ ] Existing configs work unchanged (backward compatibility)
- [ ] Rating question with `mean` shows same as before
- [ ] Rating question with `top2_box` calculates correctly
- [ ] Custom range (e.g., `range:9-10`) shows expected %
- [ ] Multi-mention auto-detection finds all columns
- [ ] Multi-mention columns sorted numerically
- [ ] Multi-mention percentages sum correctly
- [ ] Composite with TrackingSpecs works
- [ ] Excel output shows all requested metrics
- [ ] Validation catches invalid TrackingSpecs

---

## Next Steps

Once basic testing passes:

1. **Test with Real Data** - Use actual survey data if available
2. **Test Edge Cases**:
   - Questions missing in some waves
   - Empty/NA responses
   - Very small sample sizes
3. **Banner Breakouts** - Test that enhancements work with banner analysis
4. **Review Documentation** - Update user manual with examples

---

## Getting Help

If you encounter issues:

1. Check validation messages - they're designed to be helpful
2. Verify column names and data types
3. Start with simple TrackingSpecs before adding complexity
4. Compare output to spec document: `TURAS_TRACKER_ENHANCEMENT.md`

## Questions to Answer During Testing

1. **Does backward compatibility work?**
   - Yes/No: Existing configs run without changes?

2. **Do enhanced ratings work?**
   - Yes/No: top_box, bottom_box, ranges calculate correctly?

3. **Does multi-mention work?**
   - Yes/No: Auto-detection finds columns?
   - Yes/No: Percentages look reasonable?

4. **Are error messages helpful?**
   - Yes/No: When you make a mistake, does validation help?

---

**Ready to test!** Start with the basic test script, then move to real data testing.

---

## Wave History Walkthrough

# Wave History Report - Quick Walkthrough

**Version:** 1.0
**Date:** 2025-11-21
**Estimated Time:** 5 minutes

---

## What is Wave History Format?

Wave History is a compact, executive-friendly report format that shows tracking data with:
- **One row per question** (or per metric for questions with multiple TrackingSpecs)
- **One column per wave** for easy time-series viewing
- **Clean layout** that fits many questions on screen

### Comparison with Detailed Format

**Detailed Format (default):**
- One sheet per question
- Shows wave-to-wave changes, significance, confidence intervals
- Full statistical detail
- Best for: Analysts, detailed trend analysis

**Wave History Format (new):**
- One sheet per segment with all questions
- Shows only metric values across waves
- Compact, scannable layout
- Best for: Executives, quick overview, presentations

---

## How to Use

### Step 1: Add report_types Setting

Open your tracking configuration Excel file and go to the **Settings** sheet.

Add one of these settings:

#### Option A: Wave History Only
```
SettingName   | SettingValue
report_types  | wave_history
```

#### Option B: Both Report Types (Recommended)
```
SettingName   | SettingValue
report_types  | detailed,wave_history
```

#### Option C: Detailed Only (Default)
```
SettingName   | SettingValue
report_types  | detailed
```

Or simply omit the setting - defaults to detailed.

---

### Step 2: Run Tracker as Usual

```r
source("modules/tracker/run_tracker.R")

result <- run_tracker(
  tracking_config_path = "path/to/config.xlsx",
  question_mapping_path = "path/to/mapping.xlsx",
  use_banners = TRUE  # or FALSE
)
```

---

### Step 3: Review Output Files

**If you specified wave_history only:**
```
YourProject_WaveHistory_20251121.xlsx
```

**If you specified detailed,wave_history:**
```
YourProject_Tracker_20251121.xlsx       (detailed format)
YourProject_WaveHistory_20251121.xlsx   (wave history format)
```

---

## Wave History Output Format

### Sheet Structure

**Without Banners:**
- Single sheet: "Total"

**With Banners:**
- One sheet per segment: "Total", "Male", "Female", "18-34", etc.

### Column Layout

```
QuestionCode | Question                    | Type      | W1   | W2   | W3
Q38          | Overall satisfaction (1-10) | Mean      | 8.2  | 8.4  | 8.6
Q38          | Overall satisfaction (1-10) | Top 2 Box | 72   | 75   | 78
Q20          | Brand awareness             | % Yes     | 45   | 48   | 52
```

---

## How TrackingSpecs Work in Wave History

### Example 1: Rating Question with Multiple Metrics

**Question Mapping:**
```
QuestionCode | QuestionType | TrackingSpecs
Q38          | Rating       | mean,top2_box
```

**Wave History Output:**
```
QuestionCode | Question                    | Type      | W1  | W2  | W3
Q38          | Overall satisfaction (1-10) | Mean      | 8.2 | 8.4 | 8.6
Q38          | Overall satisfaction (1-10) | Top 2 Box | 72  | 75  | 78
```

Two rows: one for mean, one for top 2 box.

---

### Example 2: Multi_Mention Question

**Question Mapping:**
```
QuestionCode | QuestionType  | TrackingSpecs
Q15          | Multi_Mention | auto
```

**Wave History Output:**
```
QuestionCode | Question                    | Type        | W1 | W2 | W3
Q15          | Features used               | % Feature_1 | 45 | 48 | 50
Q15          | Features used               | % Feature_2 | 32 | 35 | 38
Q15          | Features used               | % Feature_3 | 18 | 20 | 22
```

One row per detected option.

---

### Example 3: Simple Mean Question

**Question Mapping:**
```
QuestionCode | QuestionType | TrackingSpecs
Q07          | Rating       |              (blank - defaults to mean)
```

**Wave History Output:**
```
QuestionCode | Question           | Type | W1  | W2  | W3
Q07          | Likelihood to... | Mean | 7.2 | 7.4 | 7.6
```

Single row showing mean.

---

## Use Cases

### Use Case 1: Executive Dashboard

Generate both formats:
- Share **Wave History** with executives for quick overview
- Keep **Detailed** for your analysis and reference

### Use Case 2: Presentation Prep

Use Wave History to:
- Quickly scan for interesting trends
- Copy data into PowerPoint tables
- Create simplified trend charts

### Use Case 3: Client Deliverable

Some clients prefer:
- **Detailed** for full transparency and statistical rigor
- **Wave History** for executive summary/appendix

Generate both and let client choose.

---

## Testing Your Setup

### Quick Test with Your Data

```r
setwd("~/Documents/Turas/modules/tracker")
source("test_wave_history.R")
```

This will:
1. Run tracker with your CCPB-CCS data
2. Test both with and without banners
3. Display test results

### Manual Verification Checklist

After generating Wave History output, verify:

- [ ] All tracked questions appear
- [ ] Questions with TrackingSpecs show multiple rows (one per metric)
- [ ] Wave columns show correct values (match detailed report)
- [ ] Banner segments each have their own sheet (if use_banners = TRUE)
- [ ] Column widths are readable
- [ ] Numeric formatting respects decimal_places setting

---

## Troubleshooting

### Issue: Only getting detailed report, not wave history

**Solution:** Check Settings sheet has `report_types` setting with value including "wave_history"

---

### Issue: Wave history shows wrong metric for proportion questions

**Solution:** For proportion questions, wave history uses first response code by default. If you want a specific code, add TrackingSpecs to specify it (future enhancement).

---

### Issue: Multi-mention questions missing from wave history

**Solution:** Ensure QuestionType is "Multi_Mention" and columns match pattern `{QuestionCode}_{number}` (e.g., Q15_1, Q15_2)

---

## Next Steps

1. **Try it out** - Add `report_types` setting and run tracker
2. **Compare formats** - Review both detailed and wave history outputs
3. **Share feedback** - Which format do different stakeholders prefer?
4. **Customize** - Add more TrackingSpecs to get the exact metrics you need

---

## Advanced: Configuration Examples

### Example: Full Setup with Both Formats

**Settings sheet:**
```
SettingName              | SettingValue
project_name             | Q4 2024 Brand Tracking
report_types             | detailed,wave_history
output_dir               | /path/to/output
decimal_places_ratings   | 1
decimal_separator        | .
```

**Question Mapping (excerpt):**
```
QuestionCode | QuestionType | TrackingSpecs   | Wave1 | Wave2 | Wave3
Q38          | Rating       | mean,top2_box   | Q38   | Q38   | Q38
Q20          | Single       |                 | Q20   | Q20A  | Q20B
Comp_Sat     | Composite    | mean            | -     | -     | -
```

**Output:**
- Detailed report with full analysis
- Wave History with mean + top2_box for Q38, standard metrics for others
- Both use decimal separator "." and 1 decimal place

---

**Questions?** Check USER_MANUAL.md Section 5 for full TrackingSpecs documentation.

*Version 1.0 | Wave History Walkthrough | Turas Tracker Module | Last Updated: 2025-11-21*

---

## README Templates

# TurasTracker - Template Files

This directory contains production-ready template files to help you set up TurasTracker for your project.

## Template Files

### 1. tracking_config_template.xlsx
**Purpose**: Main configuration file defining waves, settings, banner breakouts, and tracked questions.

**Contents**:
- **Waves sheet**: Define your survey waves (3 example waves included)
  - WaveID, WaveName, DataFile, FieldworkStart, FieldworkEnd, WeightVar
- **Settings sheet**: Configure analysis parameters (8 recommended settings)
  - Project name, decimal places, significance testing, minimum base size
- **Banner sheet**: Define demographic breakouts (4 example breakouts)
  - Total, Gender, Age, Region
- **TrackedQuestions sheet**: List questions to track (6 example questions)
  - Including a composite score example

### 2. question_mapping_template.xlsx
**Purpose**: Map questions across waves and define question properties.

**Contents**:
- **QuestionMap sheet**: Define question mappings (8 example questions)
  - QuestionCode: Your standardized identifier (e.g., Q_SAT)
  - QuestionText: Question wording
  - QuestionType: Rating, NPS, SingleChoice, Composite, etc.
  - Wave1, Wave2, Wave3: Wave-specific question codes from your data
  - SourceQuestions: For composites, list source questions (comma-separated)

**Example mapping**:
```
QuestionCode: Q_SAT
QuestionText: Overall satisfaction with our service
QuestionType: Rating
Wave1: Q10
Wave2: Q11
Wave3: Q12
```

This tells TurasTracker that "Q_SAT" is asked as "Q10" in Wave 1, "Q11" in Wave 2, and "Q12" in Wave 3.

### 3. wave_data_template.csv
**Purpose**: Example data file showing required structure for wave data.

**Contents**:
- 100 sample respondents with synthetic data
- Banner variables: Gender, AgeGroup, Region
- Question variables: Q10-Q13, Q15a-Q15b, Q20
- Weight variable: weight

**Key Points**:
- Column names must match those in question_mapping.xlsx Wave columns
- Banner variables must match BreakVariable names in tracking_config.xlsx Banner sheet
- Weight variable must match WeightVar in tracking_config.xlsx Waves sheet
- Missing values should be coded as NA or blank

## How to Use These Templates

### Step 1: Copy Templates to Your Project
```bash
cp tracking_config_template.xlsx my_project/tracking_config.xlsx
cp question_mapping_template.xlsx my_project/question_mapping.xlsx
cp wave_data_template.csv my_project/wave1_data.csv
```

### Step 2: Customize tracking_config.xlsx

**Waves sheet**:
1. Update WaveID, WaveName to match your project
2. Set DataFile paths to your actual data files
3. Enter FieldworkStart and FieldworkEnd dates
4. Set WeightVar to your weight column name

**Settings sheet**:
1. Update project_name
2. Adjust decimal places if needed
3. Set show_significance (TRUE/FALSE)
4. Set minimum_base (typically 30)

**Banner sheet**:
1. List demographic variables you want to break out
2. BreakVariable must match column names in your data files
3. Keep "Total" as first row

**TrackedQuestions sheet**:
1. List all QuestionCodes you want to track
2. Must match QuestionCode in question_mapping.xlsx

### Step 3: Customize question_mapping.xlsx

**QuestionMap sheet**:
1. For each question you want to track:
   - Create a QuestionCode (standardized identifier)
   - Enter QuestionText (appears in output)
   - Set QuestionType (Rating, NPS, SingleChoice, Composite, etc.)
   - Fill Wave1, Wave2, ... columns with wave-specific variable names
   - Leave Wave columns blank (NA) if question not asked in that wave

2. For composite questions:
   - Set QuestionType = "Composite"
   - Leave all Wave columns as NA (composites are calculated)
   - Fill SourceQuestions with comma-separated question codes
   - Example: "Q_SAT,Q_VALUE,Q_QUALITY"

### Step 4: Prepare Your Data Files

**Required columns**:
- All question variables listed in question_mapping.xlsx
- All banner variables listed in tracking_config.xlsx Banner sheet
- Weight variable (column name must match WeightVar)

**Data format**:
- CSV or Excel (.csv, .xlsx, .xls)
- One row per respondent
- Column headers in first row
- Missing values as NA or blank

**Example**:
```csv
ResponseID,Gender,AgeGroup,Q10,Q11,Q20,weight
1,Male,35-54,8,9,9,1.0
2,Female,18-34,7,8,8,1.2
3,Male,55+,9,10,10,0.9
```

### Step 5: Run TurasTracker

**R code**:
```r
# Load TurasTracker
source("run_tracker.R")

# Phase 2: Simple trends (Total only)
result <- run_tracker(
  tracking_config_path = "my_project/tracking_config.xlsx",
  question_mapping_path = "my_project/question_mapping.xlsx",
  data_dir = "my_project/",
  output_path = "output/trends_simple.xlsx",
  use_banners = FALSE
)

# Phase 3: Banner breakouts
result <- run_tracker(
  tracking_config_path = "my_project/tracking_config.xlsx",
  question_mapping_path = "my_project/question_mapping.xlsx",
  data_dir = "my_project/",
  output_path = "output/trends_banners.xlsx",
  use_banners = TRUE
)
```

## Template Features

### Included Question Types
- **Rating**: Satisfaction scales (1-10, 1-5, etc.)
- **NPS**: Net Promoter Score (0-10 scale, calculates Promoters/Detractors/Net)
- **Composite**: Derived metrics combining multiple questions

### Included Banner Breakouts
- **Total**: All respondents (always included)
- **Gender**: Male, Female, Other
- **AgeGroup**: 18-34, 35-54, 55+
- **Region**: North, South, East, West

### Calculated Metrics
- **Rating questions**: Mean, Std Dev, Base Size
- **NPS questions**: % Promoters, % Detractors, Net Score, Base Size
- **Composite questions**: Mean (of source questions), Std Dev, Base Size
- **Change metrics**: Absolute change, % change
- **Significance testing**: T-tests for means, Z-tests for proportions

## Example Composite Score

The templates include an example composite score:

**COMP_OVERALL = mean(Q_SAT, Q_VALUE, Q_QUALITY)**

This demonstrates how to create derived metrics. Each respondent's composite score is calculated as the mean of their responses to Q_SAT, Q_VALUE, and Q_QUALITY.

**In question_mapping.xlsx**:
```
QuestionCode: COMP_OVERALL
QuestionText: Overall Score (Composite)
QuestionType: Composite
Wave1: NA
Wave2: NA
Wave3: NA
SourceQuestions: Q_SAT,Q_VALUE,Q_QUALITY
```

## Validation

TurasTracker performs comprehensive validation before analysis:

1. **Configuration validation**: Required sheets and columns
2. **Wave validation**: Minimum 2 waves, valid dates
3. **Mapping validation**: No duplicate codes, valid question types
4. **Data validation**: All waves loaded, weights valid
5. **Question validation**: Tracked questions exist in data
6. **Banner validation**: Banner variables exist in data

If validation fails, TurasTracker will report specific errors to fix.

## Documentation

For complete documentation, see:

- **TurasTracker_User_Manual.md**: Comprehensive user guide with examples
- **TurasTracker_Maintenance_Guide.md**: Developer/maintenance documentation

Both files located in: `/Users/duncan/Documents/Turas/docs/`

## Support

For questions or issues:
1. Check TurasTracker_User_Manual.md for examples and troubleshooting
2. Review template files for proper structure
3. Verify your data files match the wave_data_template.csv structure
4. Check validation messages for specific errors

## Quick Start Checklist

- [ ] Copy templates to your project directory
- [ ] Rename files (remove '_template' suffix)
- [ ] Update tracking_config.xlsx Waves sheet with your waves
- [ ] Update tracking_config.xlsx TrackedQuestions sheet with your questions
- [ ] Update question_mapping.xlsx with your question mappings
- [ ] Prepare wave data files matching the template structure
- [ ] Run validation: Check error messages
- [ ] Run analysis: `run_tracker(...)`
- [ ] Review output Excel file

---

**Last Updated**: 2025-11-07
**TurasTracker Version**: 1.0 (Phase 3 Complete)
