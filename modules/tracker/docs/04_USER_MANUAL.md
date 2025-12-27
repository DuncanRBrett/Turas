# Turas Tracker - User Manual

[**This version is out of date - use the word version until updated**]{.underline}

**Version:** 10.0 **Last Updated:** 22 December 2025 **Target Audience:** Market Researchers, Data Analysts, Survey Managers

------------------------------------------------------------------------

## Table of Contents

1.  [Introduction](#introduction)
2.  [Getting Started](#getting-started)
3.  [Configuration Guide](#configuration-guide)
4.  [Running the Tracker](#running-the-tracker)
5.  [TrackingSpecs - Custom Metrics](#trackingspecs---custom-metrics)
6.  [Question Mapping](#question-mapping)
7.  [Banner Analysis](#banner-analysis)
8.  [Report Types](#report-types)
9.  [Output Interpretation](#output-interpretation)
10. [Troubleshooting](#troubleshooting)
11. [Best Practices](#best-practices)

------------------------------------------------------------------------

## Introduction {#introduction}

### What is Turas Tracker?

Turas Tracker analyzes **multi-wave tracking studies** - surveys conducted repeatedly over time to monitor changes in metrics like brand awareness, satisfaction, and NPS.

**Key Capabilities:** - Track metrics across 2+ survey waves - Calculate statistical trends (significantly up, down, or stable) - Handle question code changes between waves - Support multiple question types (ratings, proportions, NPS, composites) - Analyze trends by demographic segments (banner analysis) - Generate professional Excel reports with trend indicators

### When to Use Turas Tracker

**Perfect For:** - Brand tracking studies (awareness, consideration, preference) - Customer satisfaction tracking (NPS, CSAT) - Market share monitoring - Employee engagement tracking - Quarterly business reviews

**Not Suitable For:** - Single-wave surveys (use Turas Tabs instead) - Real-time dashboards (Tracker generates static reports)

------------------------------------------------------------------------

## Getting Started {#getting-started}

### Prerequisites

**Required R Packages:**

``` r
install.packages(c("openxlsx", "readxl"))
```

**Optional (for GUI and data formats):**

``` r
install.packages(c("shiny", "shinyFiles", "haven"))
```

### What You Need

1.  **Wave data files** - One data file per survey wave (CSV, Excel, or SAV)
2.  **Tracking configuration** - tracking_config.xlsx
3.  **Question mapping** (if codes changed) - question_mapping.xlsx

### File Structure

```         
project/
├── data/
│   ├── wave1_jan2024.csv
│   ├── wave2_apr2024.csv
│   └── wave3_jul2024.csv
├── config/
│   ├── tracking_config.xlsx
│   └── question_mapping.xlsx
└── output/
    └── (results will be saved here)
```

------------------------------------------------------------------------

## Configuration Guide {#configuration-guide}

### Configuration File: tracking_config.xlsx

The configuration file has 4 sheets:

#### Sheet 1: Waves

Define each survey wave.

| Column         | Required | Description              | Example        |
|----------------|----------|--------------------------|----------------|
| WaveID         | Yes      | Unique wave identifier   | W1, W2, W3     |
| WaveName       | Yes      | Display name for reports | Jan 2024       |
| DataFile       | Yes      | Path to wave data file   | wave1_data.csv |
| FieldworkStart | No       | Survey start date        | 2024-01-01     |
| FieldworkEnd   | No       | Survey end date          | 2024-01-15     |
| WeightVar      | No       | Weight column name       | Weight         |

**Example:**

```         
WaveID | WaveName  | DataFile       | WeightVar
W1     | Jan 2024  | wave1_data.csv | Weight
W2     | Apr 2024  | wave2_data.csv | Weight
W3     | Jul 2024  | wave3_data.csv | Weight
```

#### Sheet 2: TrackedQuestions

Define which questions to track.

| Column       | Required | Description         | Example                      |
|--------------|----------|---------------------|------------------------------|
| QuestionCode | Yes      | Question identifier | Q01_Awareness                |
| QuestionText | No       | Display text        | Brand awareness              |
| QuestionType | Yes      | Type of question    | Rating, NPS, Single_Response |

**Supported QuestionType Values:** - `Rating` - Rating scale (1-5, 1-10) - `NPS` - Net Promoter Score (0-10) - `Single_Response` - Single choice - `Multi_Mention` - Select all that apply - `Composite` - Derived from multiple questions

#### Sheet 3: Settings

Configure analysis parameters.

| Setting | Default | Description |
|---------------------|---------------------|------------------------------|
| project_name | (required) | Project title for reports |
| output_file | auto | Output filename |
| output_dir | same as config | Output directory |
| report_types | detailed | Comma-separated: detailed,wave_history,dashboard,sig_matrix |
| confidence_level | 0.95 | Statistical confidence |
| min_base_size | 30 | Minimum n for sig testing |
| decimal_places_ratings | 1 | Decimal places for means |
| decimal_places_percents | 0 | Decimal places for percentages |
| show_significance | TRUE | Show trend indicators |

**Example:**

```         
SettingName      | SettingValue
project_name     | Q4 Brand Tracking
report_types     | detailed,wave_history
confidence_level | 0.95
min_base_size    | 30
```

#### Sheet 4: Banner (Optional)

Define demographic segments for breakout analysis.

| Column        | Description         |
|---------------|---------------------|
| BreakVariable | Column name in data |
| BreakLabel    | Display label       |

**Example:**

```         
BreakVariable | BreakLabel
Total         | Total
Gender        | Gender
AgeGroup      | Age Group
Region        | Region
```

------------------------------------------------------------------------

## Running the Tracker {#running-the-tracker}

### Using the GUI

``` r
source("modules/tracker/run_tracker_gui.R")
run_tracker_gui()
```

The GUI provides: - File browser for configuration and mapping files - Banner analysis toggle - Real-time console output - Recent projects functionality

### Using Script

``` r
source("modules/tracker/run_tracker.R")

result <- run_tracker(
  tracking_config_path = "config/tracking_config.xlsx",
  question_mapping_path = "config/question_mapping.xlsx",
  data_dir = "data/",
  use_banners = FALSE
)
```

**Parameters:** - `tracking_config_path` - Path to tracking_config.xlsx (required) - `question_mapping_path` - Path to question_mapping.xlsx (or NA if not needed) - `data_dir` - Directory containing wave data files (or NULL for paths in config) - `output_path` - Custom output path (or NULL for auto-generated) - `use_banners` - Enable banner analysis (TRUE/FALSE)

**Returns:** Path to output file(s) or named list if multiple report types

------------------------------------------------------------------------

## TrackingSpecs - Custom Metrics {#trackingspecs---custom-metrics}

### Overview

TrackingSpecs lets you customize which metrics are tracked for each question. Add a `TrackingSpecs` column to your question_mapping.xlsx.

### Adding TrackingSpecs

**question_mapping.xlsx:**

```         
QuestionCode | QuestionType | TrackingSpecs   | Wave1 | Wave2 | Wave3
Q38          | Rating       | mean,top2_box   | Q38   | Q38   | Q38
Q41          | Rating       | mean,top_box    | Q41   | Q41   | Q41
Q30          | Multi_Mention| auto            | Q30   | Q30   | Q30
```

### Available Metrics

#### For Rating Questions

| Metric         | Description                |
|----------------|----------------------------|
| `mean`         | Average rating             |
| `top_box`      | \% giving highest rating   |
| `top2_box`     | \% giving top 2 ratings    |
| `top3_box`     | \% giving top 3 ratings    |
| `bottom_box`   | \% giving lowest rating    |
| `bottom2_box`  | \% giving bottom 2 ratings |
| `range:X-Y`    | \% within custom range     |
| `distribution` | \% for each value          |

**Scale Auto-Detection:** The tracker detects your scale (1-5, 1-10, 0-10) automatically.

#### For Multi_Mention Questions

**Binary Mode (0/1 data):** \| Metric \| Description \| \|--------\|-------------\| \| `auto` \| Track all detected options \| \| `option:COL` \| Track specific column \| \| `any` \| % mentioning at least one \| \| `count_mean` \| Mean number mentioned \|

**Category Mode (text data):** \| Metric \| Description \| \|--------\|-------------\| \| `category:TEXT` \| Track specific text value \|

#### For NPS Questions

| Metric           | Description              |
|------------------|--------------------------|
| `nps_score`      | Net Promoter Score       |
| `promoters_pct`  | \% Promoters (9-10)      |
| `passives_pct`   | \% Passives (7-8)        |
| `detractors_pct` | \% Detractors (0-6)      |
| `full`           | All components (default) |

### Examples

**Track mean + top 2 box for satisfaction:**

```         
Q38 | Rating | mean,top2_box | Q38 | Q38 | Q38
```

**Track custom range (% rating 7-10):**

```         
Q41 | Rating | mean,range:7-10 | Q41 | Q41 | Q41
```

**Auto-detect multi-mention options:**

```         
Q30 | Multi_Mention | auto | Q30 | Q30 | Q30
```

**Track specific text categories:**

```         
Q10 | Multi_Mention | category:Brand A,category:Brand B | Q10 | Q10 | Q10
```

------------------------------------------------------------------------

## Question Mapping {#question-mapping}

### When You Need Mapping

Use question_mapping.xlsx when: - Question codes changed between waves (Q10 → Q11 → Q12) - Question wording changed but concept is same - Need to track composite questions - Want to use TrackingSpecs

### Mapping File Structure

**question_mapping.xlsx - QuestionMap sheet:**

```         
QuestionCode | QuestionType | TrackingSpecs | Wave1 | Wave2 | Wave3 | SourceQuestions
Q_SAT        | Rating       | mean,top2_box | Q10   | Q11   | Q12   |
Q_NPS        | NPS          | full          | Q20   | Q20   | Q20   |
COMP_CX      | Composite    | mean          | NA    | NA    | NA    | Q_SAT,Q_SERVICE
```

**Column Descriptions:** - `QuestionCode` - Standardized code (used in output) - `QuestionType` - Question type - `TrackingSpecs` - Custom metrics (optional) - `Wave1`, `Wave2`, etc. - Actual code in each wave's data - `SourceQuestions` - For composites: comma-separated source questions

### Mapping Scenarios

**Scenario 1: Same code, same question**

```         
Q_SAT | Rating | | Q10 | Q10 | Q10
```

**Scenario 2: Code changed between waves**

```         
Q_SAT | Rating | | SAT1 | SATISFACTION | Q4
```

Tracker finds SAT1 in Wave 1, SATISFACTION in Wave 2, Q4 in Wave 3.

**Scenario 3: Question added in Wave 2**

```         
Q_NEW | Rating | | NA | Q15 | Q15
```

Shows "N/A" for Wave 1, tracks from Wave 2 onward.

**Scenario 4: Question removed after Wave 2**

```         
Q_OLD | Rating | | Q20 | Q20 | NA
```

Tracks through Wave 2, shows "N/A" for Wave 3.

------------------------------------------------------------------------

## Banner Analysis {#banner-analysis}

### Enabling Banners

**Step 1:** Add Banner sheet to tracking_config.xlsx

```         
BreakVariable | BreakLabel
Total         | Total
Gender        | Gender
AgeGroup      | Age Group
```

**Step 2:** Run with banners enabled

``` r
result <- run_tracker(
  tracking_config_path = "config/tracking_config.xlsx",
  question_mapping_path = "config/question_mapping.xlsx",
  use_banners = TRUE
)
```

### Output with Banners

Each question sheet shows: - Total column - One column per segment value (Male, Female, 18-34, etc.)

**Wave History format with banners:** - One sheet per segment (Total, then each banner segment)

------------------------------------------------------------------------

## Report Types {#report-types}

### Available Formats

Configure in Settings sheet:

```         
report_types | detailed,wave_history,dashboard,sig_matrix
```

### Detailed Report

One sheet per question with full statistics.

**Contents:** - Wave values and sample sizes - Wave-to-wave change calculations - Significance indicators - Confidence intervals (if enabled)

### Wave History Report

Compact format - all questions on one sheet.

**Layout:**

```         
QuestionCode | Question     | Type      | W1  | W2  | W3
Q38          | Satisfaction | Mean      | 8.2 | 8.4 | 8.6
Q38          | Satisfaction | Top 2 Box | 72  | 75  | 78
Q39          | Recommend    | % Yes     | 68  | 71  | 74
```

**Best for:** Executive presentations, quick trend scanning

### Dashboard Report

Executive summary with status indicators.

**Features:** - All metrics in one view - Latest value, vs previous wave, vs baseline - Status indicators: Good / Stable / Watch / Alert - Optional significance matrices

### Significance Matrix Report

All wave-pair comparisons for each question.

**Features:** - Matrix format (rows = from wave, columns = to wave) - Color-coded significance (green = up, red = down) - Change values with direction indicators

------------------------------------------------------------------------

## Output Interpretation {#output-interpretation}

### Trend Indicators

| Symbol | Meaning                                        |
|--------|------------------------------------------------|
| ↑      | Statistically significant increase (p \< 0.05) |
| ↓      | Statistically significant decrease (p \< 0.05) |
| →      | No significant change                          |

### Sample Sizes

| Label        | Description                               |
|--------------|-------------------------------------------|
| Unweighted N | Actual number of respondents              |
| Weighted N   | Sum of weights                            |
| Effective N  | Sample size adjusted for weighting (DEFF) |

### Design Effect (DEFF)

Measures weighting impact on effective sample size.

| DEFF    | Interpretation               |
|---------|------------------------------|
| 1.0     | No impact (equal weights)    |
| 1.1-1.3 | Moderate (10-30% reduction)  |
| 1.5-2.0 | High (33-50% reduction)      |
| \> 2.0  | Very high (review weighting) |

------------------------------------------------------------------------

## Troubleshooting {#troubleshooting}

### Common Errors

**"Question Q1 not found in Wave 2"** - Check spelling/capitalization (case-sensitive) - Use Question_Mapping if codes changed between waves

**"Insufficient base for significance testing"** - Base size \< min_base_size setting - Lower min_base_size or combine segments

**"Weight variable not found"** - Check WeightVar column in Waves sheet - Verify column exists in wave data

**"All values are non-numeric"** - Check data format in wave file - For Multi_Mention with text, use `category:` syntax

### Validation Warnings

**"Large DEFF detected (\>2.0)"** - Review weighting efficiency - Report effective N alongside raw N - Consider weight trimming

**"Small base sizes for segment"** - Interpret results with caution - Consider combining segments

------------------------------------------------------------------------

## Best Practices {#best-practices}

### Data Preparation

**Do:** - Use consistent question codes across waves when possible - Keep same coding scheme (1=Yes, 0=No) - Include weights in same column name across waves - Document questionnaire changes

**Don't:** - Change question codes without mapping - Reverse coding between waves - Mix weighted and unweighted waves - Skip waves in sequence

### Configuration

**Do:** - Use meaningful Wave IDs (Q1_2024 not just W1) - Include fielding dates for context - Set realistic min_base thresholds (30+) - Test with sample data first

**Don't:** - Use special characters in WaveID - Set min_base too low (\< 20 unreliable) - Leave WeightVariable inconsistent across waves

### Interpretation

**Do:** - Consider substantive vs statistical significance - Report confidence intervals - Note effective sample sizes - Check for seasonality effects

**Don't:** - Over-interpret small changes even if significant - Ignore large changes that aren't quite significant - Compare non-comparable questions - Report trends without context

------------------------------------------------------------------------

## Quick Reference

### Minimum Configuration

**3 Required Sheets:** 1. Waves (WaveID, WaveName, DataFile) 2. TrackedQuestions (QuestionCode, QuestionType) 3. Settings (project_name)

### Typical Processing Times

| Waves | Questions | Segments   | Time     |
|-------|-----------|------------|----------|
| 3     | 10        | Total only | \~20 sec |
| 5     | 25        | Total only | \~45 sec |
| 10    | 50        | 5 segments | 3-5 min  |

------------------------------------------------------------------------

## Additional Resources

-   [03_REFERENCE_GUIDE.md](03_REFERENCE_GUIDE.md) - Architecture and statistical methods
-   [05_TECHNICAL_DOCS.md](05_TECHNICAL_DOCS.md) - Developer documentation
-   [06_TEMPLATE_REFERENCE.md](06_TEMPLATE_REFERENCE.md) - Template field reference
-   [07_EXAMPLE_WORKFLOWS.md](07_EXAMPLE_WORKFLOWS.md) - Practical examples
