---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tracker - Template Reference

**Version:** 10.0 **Last Updated:** 22 December 2025 **Target
Audience:** Analysts, Project Managers, Template Configurers

This document provides complete field-by-field reference for both
Tracker template files.

------------------------------------------------------------------------

## Table of Contents

**Chapter 1: Tracker Config Template** 1.
[Overview](#chapter-1-tracker-config-template) 2. [Waves
Sheet](#waves-sheet) 3. [Settings Sheet](#settings-sheet) 4.
[TrackedQuestions Sheet](#trackedquestions-sheet) 5. [Banner
Sheet](#banner-sheet)

**Chapter 2: Question Mapping Template** 1.
[Overview](#chapter-2-question-mapping-template) 2. [QuestionMap
Sheet](#questionmap-sheet) 3. [TrackingSpecs
Reference](#trackingspecs-reference) 4. [Mapping
Scenarios](#mapping-scenarios)

------------------------------------------------------------------------

# Chapter 1: Tracker Config Template {#chapter-1-tracker-config-template}

**File:** `Tracker_Config_Template.xlsx` **Location:** `docs/templates/`

The Tracker Config Template defines wave definitions, analysis settings,
tracked questions, and banner structure.

------------------------------------------------------------------------

## Template Sheets

| Sheet            | Purpose               | Required |
|------------------|-----------------------|----------|
| Instructions     | Usage instructions    | No       |
| Waves            | Wave definitions      | Yes      |
| Settings         | Analysis parameters   | Yes      |
| TrackedQuestions | Questions to track    | Yes      |
| Banner           | Demographic breakouts | No       |

------------------------------------------------------------------------

## Waves Sheet {#waves-sheet}

Define each survey wave in your tracking study.

### Required Columns

| Column   | Type | Description                         | Example           |
|----------|------|-------------------------------------|-------------------|
| WaveID   | Text | Unique wave identifier (short code) | W1, W2, W23       |
| WaveName | Text | Display name for reports            | Jan 2024, Wave 23 |
| DataFile | Text | Path to wave data file              | wave1_data.csv    |

### Optional Columns

| Column         | Type | Description                 | Default       |
|----------------|------|-----------------------------|---------------|
| FieldworkStart | Date | Survey start date           | Not displayed |
| FieldworkEnd   | Date | Survey end date             | Not displayed |
| WeightVar      | Text | Weight variable column name | Unweighted    |

### Example

```         
WaveID | WaveName    | DataFile         | FieldworkStart | FieldworkEnd | WeightVar
W23    | Oct 2024    | wave23_data.csv  | 2024-10-01     | 2024-10-15   | Weight
W24    | Jan 2025    | wave24_data.csv  | 2025-01-01     | 2025-01-15   | Weight
W25    | Apr 2025    | wave25_data.csv  | 2025-04-01     | 2025-04-15   | Weight
```

### Field Rules

**WaveID:** - Must be unique across all waves - Case-sensitive - No
spaces or special characters (except underscore) - Used internally for
processing

**WaveName:** - Appears in output tables and reports - Can include
spaces and formatting - Should be meaningful to end users

**DataFile:** - Can be relative path (relative to config file
location) - Can be absolute path - Supports: .csv, .xlsx, .xls, .sav,
.dta

**WeightVar:** - Leave blank or NA for unweighted analysis - Column must
exist in wave data file - Same weight variable name recommended across
waves

------------------------------------------------------------------------

## Settings Sheet {#settings-sheet}

Configure analysis parameters and output options.

### Core Settings

| Setting      | Type | Default        | Description               |
|--------------|------|----------------|---------------------------|
| project_name | Text | (required)     | Project title for reports |
| output_file  | Text | auto-generated | Output filename           |
| output_dir   | Path | same as config | Output directory          |

### Report Type Settings

| Setting      | Type | Default  | Description          |
|--------------|------|----------|----------------------|
| report_types | Text | detailed | Comma-separated list |

**report_types Values:** - `detailed` - Full detailed trend report (one
sheet per question) - `wave_history` - Compact format (one row per
metric) - `dashboard` - Executive summary with status indicators -
`sig_matrix` - Significance matrix for all wave-pairs

**Examples:**

```         
report_types | detailed
report_types | detailed,wave_history
report_types | detailed,wave_history,dashboard,sig_matrix
```

### Statistical Settings

| Setting           | Type    | Default | Description                               |
|-----------------|-----------------|-----------------|-----------------------|
| confidence_level  | Numeric | 0.95    | Statistical confidence (0.90, 0.95, 0.99) |
| min_base_size     | Integer | 30      | Minimum n for significance testing        |
| show_significance | Boolean | TRUE    | Show trend indicators (↑↓→)               |

### Formatting Settings

| Setting                 | Type    | Default | Description              |
|-------------------------|---------|---------|--------------------------|
| decimal_places_ratings  | Integer | 1       | Decimals for mean values |
| decimal_places_percents | Integer | 0       | Decimals for percentages |
| decimal_separator       | Text    | .       | Period or comma          |

### Example Settings Sheet

```         
SettingName              | SettingValue
project_name             | Q4 2024 Brand Tracking
report_types             | detailed,wave_history
output_file              | Q4_Brand_Tracking.xlsx
output_dir               | /Users/duncan/Reports
confidence_level         | 0.95
min_base_size            | 30
decimal_places_ratings   | 1
decimal_places_percents  | 0
show_significance        | TRUE
```

------------------------------------------------------------------------

## TrackedQuestions Sheet {#trackedquestions-sheet}

Define which questions to include in trend analysis.

### Required Columns

| Column       | Type | Description         | Example       |
|--------------|------|---------------------|---------------|
| QuestionCode | Text | Question identifier | Q01_Awareness |
| QuestionType | Text | Type of question    | Rating, NPS   |

### Optional Columns

| Column       | Type | Description               |
|--------------|------|---------------------------|
| QuestionText | Text | Display label for reports |

### Supported QuestionType Values

| QuestionType    | Description                  | Default Metric |
|-----------------|------------------------------|----------------|
| Rating          | Numeric scales (1-5, 1-10)   | Mean           |
| NPS             | Net Promoter Score (0-10)    | NPS score      |
| Single_Response | Single choice categorical    | \% by option   |
| SingleChoice    | Same as Single_Response      | \% by option   |
| Multi_Mention   | Select all that apply        | \% per option  |
| Composite       | Derived from other questions | Mean           |

### Example

```         
QuestionCode   | QuestionText                  | QuestionType
Q01_Awareness  | Brand awareness (unaided)     | Single_Response
Q02_Satisfaction | Overall satisfaction (1-10) | Rating
Q03_NPS        | Likelihood to recommend       | NPS
Q04_Features   | Features used (select all)    | Multi_Mention
```

------------------------------------------------------------------------

## Banner Sheet {#banner-sheet}

Define demographic segments for breakout analysis. Optional - omit for
Total-only analysis.

### Required Columns

| Column        | Type | Description               | Example |
|---------------|------|---------------------------|---------|
| BreakVariable | Text | Column name in wave data  | Gender  |
| BreakLabel    | Text | Display label for reports | Gender  |

### Example

```         
BreakVariable | BreakLabel
Total         | Total
Gender        | Gender
AgeGroup      | Age Group
Region        | Region
```

### Notes

-   `Total` row is optional but recommended
-   BreakVariable must exist in wave data files
-   Segments auto-detected from unique values in data
-   Each unique value becomes a separate column in output

------------------------------------------------------------------------

# Chapter 2: Question Mapping Template {#chapter-2-question-mapping-template}

**File:** `Tracker_Question_Mapping_Template.xlsx` **Location:**
`docs/templates/`

The Question Mapping Template maps question codes across waves and
specifies custom metrics via TrackingSpecs.

------------------------------------------------------------------------

## When to Use This Template

**Required when:** - Question codes changed between waves - Using
TrackingSpecs for custom metrics - Tracking composite questions -
Question text/wording changed but concept is same

**Optional when:** - All question codes identical across waves - Using
default metrics only

------------------------------------------------------------------------

## QuestionMap Sheet {#questionmap-sheet}

### Required Columns

| Column       | Type | Description                        |
|--------------|------|------------------------------------|
| QuestionCode | Text | Standardized code (used in output) |
| QuestionType | Text | Question type                      |
| Wave columns | Text | Actual code in each wave's data    |

### Optional Columns

| Column          | Type | Description                          |
|-----------------|------|--------------------------------------|
| QuestionText    | Text | Display label                        |
| TrackingSpecs   | Text | Custom metric specifications         |
| SourceQuestions | Text | For Composite: source question codes |

### Wave Columns

Column names must match WaveID values in Tracker Config: - If Waves
sheet has W1, W2, W3, mapping needs columns named W1, W2, W3 - If Waves
sheet has W23, W24, W25, mapping needs W23, W24, W25

### Example

```         
QuestionCode | QuestionType  | TrackingSpecs   | W23  | W24  | W25  | SourceQuestions
Q_SAT        | Rating        | mean,top2_box   | Q10  | Q11  | Q12  |
Q_NPS        | NPS           | full            | Q20  | Q20  | Q20  |
Q_FEATURES   | Multi_Mention | auto            | Q30  | Q30  | Q30  |
COMP_CX      | Composite     | mean            | NA   | NA   | NA   | Q_SAT,Q_SERVICE
```

------------------------------------------------------------------------

## TrackingSpecs Reference {#trackingspecs-reference}

### Syntax

Comma-separated list of metric specifications (no spaces between items).

**Examples:**

```         
mean,top2_box
mean,top_box,range:9-10
auto,any,count_mean
category:Brand A,category:Brand B
```

### Rating Question Metrics

| Spec           | Description        | Example Output         |
|----------------|--------------------|------------------------|
| `mean`         | Average rating     | 8.2                    |
| `top_box`      | \% highest value   | 45% (rated 10 on 1-10) |
| `top2_box`     | \% top 2 values    | 72% (rated 9-10)       |
| `top3_box`     | \% top 3 values    | 85% (rated 8-10)       |
| `bottom_box`   | \% lowest value    | 5% (rated 1)           |
| `bottom2_box`  | \% bottom 2 values | 8% (rated 1-2)         |
| `range:X-Y`    | \% in custom range | 52% (in range 9-10)    |
| `distribution` | \% for each value  | Full breakdown         |

**Scale Auto-Detection:** - 1-5 scale: top_box = % rating 5 - 1-10
scale: top_box = % rating 10 - 0-10 scale: top_box = % rating 10

### Multi_Mention Metrics

**Binary Mode (0/1 data):**

| Spec                 | Description                                |
|----------------------|--------------------------------------------|
| `auto`               | Auto-detect all Q##\_\* columns            |
| `option:COL`         | Track specific column (e.g., option:Q30_1) |
| `any`                | \% mentioning at least one option          |
| `count_mean`         | Average number of options mentioned        |
| `count_distribution` | Distribution of mention counts             |

**Category Mode (text data):**

| Spec            | Description               |
|-----------------|---------------------------|
| `category:TEXT` | Track specific text value |

**Category Mode Rules:** - Case-insensitive matching - Exact text match
(after trimming whitespace) - Searches across all Q##\_\* columns - Text
must match exactly (punctuation matters)

### NPS Metrics

| Spec             | Description              |
|------------------|--------------------------|
| `nps_score`      | Net Promoter Score only  |
| `promoters_pct`  | \% Promoters (9-10)      |
| `passives_pct`   | \% Passives (7-8)        |
| `detractors_pct` | \% Detractors (0-6)      |
| `full`           | All components (default) |

### Composite Metrics

Same as Rating metrics. Applied after composite score calculation.

**SourceQuestions column:** - Comma-separated list of source question
codes - Uses standardized codes (from QuestionCode column) - Source
questions must be Rating type

------------------------------------------------------------------------

## Mapping Scenarios {#mapping-scenarios}

### Scenario 1: Same Code Across Waves

Question code unchanged:

```         
QuestionCode | QuestionType | W1  | W2  | W3
Q_SAT        | Rating       | Q10 | Q10 | Q10
```

### Scenario 2: Code Changed Between Waves

Question code varies by wave:

```         
QuestionCode | QuestionType | W1   | W2           | W3
Q_SAT        | Rating       | SAT1 | SATISFACTION | Q4
```

Tracker uses SAT1 in Wave 1 data, SATISFACTION in Wave 2, Q4 in Wave 3.

### Scenario 3: Question Added Mid-Study

Question not in earlier waves:

```         
QuestionCode | QuestionType | W1 | W2  | W3
Q_NEW        | Rating       | NA | Q15 | Q15
```

Shows "N/A" for Wave 1, tracks from Wave 2 onward.

### Scenario 4: Question Removed

Question discontinued:

```         
QuestionCode | QuestionType | W1  | W2  | W3
Q_OLD        | Rating       | Q20 | Q20 | NA
```

Tracks through Wave 2, shows "N/A" for Wave 3.

### Scenario 5: Composite Question

Derived from other tracked questions:

```         
QuestionCode | QuestionType | TrackingSpecs | W1 | W2 | W3 | SourceQuestions
Q_SAT        | Rating       | mean          | Q10| Q10| Q10|
Q_SERVICE    | Rating       | mean          | Q11| Q11| Q11|
COMP_CX      | Composite    | mean,top2_box | NA | NA | NA | Q_SAT,Q_SERVICE
```

COMP_CX is calculated as mean of Q_SAT and Q_SERVICE per respondent.

### Scenario 6: Multi_Mention with Binary Data

Data has 0/1 values in columns:

```         
Data Format:
Q30_1 | Q30_2 | Q30_3 | Q30_4
1     | 0     | 1     | 0
0     | 1     | 0     | 1

Mapping:
QuestionCode | QuestionType  | TrackingSpecs
Q30          | Multi_Mention | auto
```

### Scenario 7: Multi_Mention with Category Text

Data has text labels:

```         
Data Format:
Q10_1              | Q10_2          | Q10_3
We rely on CCS     | Personal records|
Internal system    |                | Other
We rely on CCS     | Other          |

Mapping:
QuestionCode | QuestionType  | TrackingSpecs
Q10          | Multi_Mention | category:We rely on CCS,category:Personal records,category:Other
```

------------------------------------------------------------------------

## Validation Rules

### QuestionCode

-   Must be unique
-   Used as identifier in output
-   No spaces (use underscores)

### QuestionType

-   Must be valid type (see list above)
-   Case-insensitive

### Wave Columns

-   Must match WaveID values from config
-   Use NA for waves where question not asked
-   Code must exist in wave data file

### TrackingSpecs

-   Valid syntax for question type
-   Comma-separated, no spaces between items
-   Leave blank for default behavior

### SourceQuestions (Composite only)

-   Comma-separated question codes
-   Must reference other questions in mapping
-   Source questions must be calculated before composite

------------------------------------------------------------------------

## Output Structure

### Report Type: detailed

One Excel sheet per question showing: - Wave values in columns - Sample
sizes (unweighted, weighted, effective) - Wave-to-wave changes -
Significance indicators

### Report Type: wave_history

Compact format:

```         
QuestionCode | Question     | Type      | W23 | W24 | W25
Q_SAT        | Satisfaction | Mean      | 8.2 | 8.4 | 8.6
Q_SAT        | Satisfaction | Top 2 Box | 72  | 75  | 78
Q_NPS        | NPS          | NPS Score | 32  | 35  | 38
```

### Report Type: dashboard

Executive summary with: - Latest value - vs Previous wave (change +
significance) - vs Baseline (change + significance) - Status indicator
(Good/Stable/Watch/Alert)

### Report Type: sig_matrix

Per-question matrix: - Rows = "from" wave - Columns = "to" wave - Cells
= change value + significance indicator - Color-coded (green = up, red =
down)

------------------------------------------------------------------------

## Template Files Location

Both template files are included in: -
`modules/tracker/docs/templates/Tracker_Config_Template.xlsx` -
`modules/tracker/docs/templates/Tracker_Question_Mapping_Template.xlsx`

Copy and rename for your project.
