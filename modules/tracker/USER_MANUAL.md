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
6. [Question Types](#question-types)
7. [Wave Management](#wave-management)
8. [Question Mapping](#question-mapping)
9. [Trend Calculation](#trend-calculation)
10. [Banner Analysis](#banner-analysis)
11. [Output Interpretation](#output-interpretation)
12. [Advanced Features](#advanced-features)
13. [Troubleshooting](#troubleshooting)
14. [Best Practices](#best-practices)
15. [FAQ](#faq)

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

### Multi-Mention Question Support

Multi-mention questions (also called "select all that apply" or checkbox questions) are now automatically detected and tracked.

#### What Are Multi-Mention Questions?

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

#### Advanced Multi-Mention Metrics

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

#### Multi-Mention Specs

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

**Document Version:** 2.0
**Last Updated:** 2025-11-21
**Changes in v2.0:**
- Added TrackingSpecs section with comprehensive documentation
- Documented enhanced rating metrics (top_box, top2_box, etc.)
- Documented Multi-Mention question support
- Documented enhanced composite metrics
- Added output_dir setting documentation
- Updated examples throughout

**Next Review:** Q1 2026
