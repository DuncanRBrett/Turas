---
editor_options: 
  markdown: 
    wrap: 72
---

# TurasTracker User Manual

**Version 2.3** \| February 2026

------------------------------------------------------------------------

## Table of Contents

1.  [Overview](#1-overview)
2.  [Quick Start](#2-quick-start)
3.  [Configuration Files](#3-configuration-files)
4.  [Tracking Config (tracking_config.xlsx)](#4-tracking-config)
5.  [Question Mapping (question_mapping.xlsx)](#5-question-mapping)
6.  [TrackingSpecs Reference](#6-trackingspecs-reference)
7.  [Survey Structure Files (Optional)](#7-survey-structure-files)
8.  [Running the Tracker](#8-running-the-tracker)
9.  [Output Reports](#9-output-reports)
10. [Examples](#10-examples)
11. [Troubleshooting](#11-troubleshooting)

------------------------------------------------------------------------

## 1. Overview

TurasTracker is a longitudinal survey tracking tool that calculates
trends across multiple waves of survey data. It supports:

-   **Rating questions** (1-5, 1-10 scales) with mean, top/bottom box,
    and custom range metrics
-   **NPS questions** (0-10) with NPS score, promoter/passive/detractor
    percentages
-   **Single-choice questions** with category tracking
-   **Multi-mention questions** (select-all-that-apply) with binary and
    category modes
-   **Composite questions** calculated from multiple source questions
-   **Banner breakouts** by demographic segments (e.g., region, gender,
    age group)
-   **Significance testing** between waves
-   **Excel and interactive HTML reports**

### What You Need

| File | Purpose | Required |
|------------------|--------------------------|----------------------------|
| `tracking_config.xlsx` | Analysis settings, wave definitions, banner setup, tracked questions | Yes |
| `question_mapping.xlsx` | Maps question codes across waves, defines question types | Yes |
| Wave data files (`.csv` or `.xlsx`) | Raw survey response data, one file per wave | Yes |
| Survey structure files (`.xlsx`) | Option metadata for text-to-numeric mapping | Optional |
| Crosstab config files (`.xlsx`) | Per-wave weighting configuration | Optional |

------------------------------------------------------------------------

## 2. Quick Start

### Via the GUI

``` r
source("modules/tracker/run_tracker_gui.R")
run_tracker_gui()
```

The GUI provides file pickers, auto-detection, and project memory. It
remembers your last 5 projects.

### Via R Code

``` r
source("modules/tracker/run_tracker.R")

run_tracker(
  tracking_config_path = "path/to/tracking_config.xlsx",
  question_mapping_path = "path/to/question_mapping.xlsx",
  data_dir = "path/to/wave/data/",
  use_banners = TRUE,
  enable_html = TRUE
)
```

### Parameters

| Parameter | Type | Default | Description |
|------------------|----------------|----------------|----------------------|
| `tracking_config_path` | String | Required | Path to your tracking_config.xlsx |
| `question_mapping_path` | String | Required | Path to your question_mapping.xlsx |
| `data_dir` | String | NULL | Directory containing wave data files (for relative paths) |
| `output_path` | String | NULL | Specific output file path (overrides config) |
| `use_banners` | Logical | FALSE | Calculate trends with banner breakouts |
| `enable_html` | Logical | NULL | Force HTML report on/off (NULL reads from config) |

------------------------------------------------------------------------

## 3. Configuration Files

The tracker requires **two configuration files** that work together:

```         
tracking_config.xlsx          question_mapping.xlsx
┌────────────────────┐       ┌────────────────────┐
│ Waves              │       │ QuestionMap         │
│ Settings           │       │  - QuestionCode     │
│ TrackedQuestions    │──────>│  - QuestionType     │
│ Banner             │       │  - Wave columns     │
└────────────────────┘       │  - SourceQuestions   │
                             └────────────────────┘
```

The **tracking config** defines *what* to analyse (which waves, which
questions, which metrics, which banners). The **question mapping**
defines *how* to find each question in the data (variable names per
wave, question types).

These two files are **not automatically linked**. You must specify both
when running the tracker.

### GUI Auto-Detection

When using the GUI, after selecting your tracking_config.xlsx, the
question mapping is auto-detected if it is in the same directory. The
GUI searches for:

1.  `question_mapping.xlsx`
2.  `Question_Mapping.xlsx`
3.  `QuestionMapping.xlsx`
4.  `{config_name}_question_mapping.xlsx`
5.  Any file matching `*mapping*.xlsx`

------------------------------------------------------------------------

## 4. Tracking Config (tracking_config.xlsx)

This file has **4 sheets**:

### 4.1 Waves Sheet

Defines each wave of survey data.

| Column | Required | Description |
|-------------------|-----------------------|------------------------------|
| `WaveID` | Yes | Unique wave identifier (e.g., `W1`, `W2`, `W3`). Used to link with question mapping columns. |
| `WaveName` | Yes | Display name (e.g., `Q1 2024`, `Apr 2024`). Appears in report headers. |
| `DataFile` | Yes | Path to wave data file. Can be absolute or relative to data_dir. Supports `.csv` and `.xlsx`. |
| `FieldworkStart` | Yes | Start date of fieldwork (YYYYMMDD or Excel date format). |
| `FieldworkEnd` | Yes | End date of fieldwork. Must be \>= FieldworkStart. |
| `WeightVar` | No | Weight variable name in this wave's data. Overrides global weight_variable setting. |
| `StructureFile` | No | Path to Survey_Structure.xlsx for this wave. Enables text-to-numeric mapping and `box:` specs. |
| `ConfigFile` | No | Path to Crosstab_Config.xlsx for this wave. Provides wave-specific weighting settings. |

**Example:**

| WaveID | WaveName | DataFile | FieldworkStart | FieldworkEnd | WeightVar | StructureFile | ConfigFile |
|---------|---------|---------|---------|---------|---------|---------|---------|
| W1 | Q1 2024 | wave_1.csv | 2024-01-01 | 2024-01-31 | weight | structure_w1.xlsx | config_w1.xlsx |
| W2 | Q2 2024 | wave_2.csv | 2024-04-01 | 2024-04-30 | weight | structure_w2.xlsx | config_w2.xlsx |
| W3 | Q3 2024 | wave_3.csv | 2024-07-01 | 2024-07-31 | weight | structure_w3.xlsx | config_w3.xlsx |

**Notes:** - File paths can be absolute (`/Users/me/data/wave_1.csv`) or
relative to data_dir (`wave_1.csv`). - If StructureFile/ConfigFile are
blank or the columns are absent, the tracker works as before (numeric
data only). - StructureFile and ConfigFile paths are resolved relative
to data_dir first, then the config file directory.

### 4.2 Settings Sheet

Controls analysis parameters. Two-column format: `Setting` (or
`SettingName`) and `Value`.

| Setting | Type | Default | Description |
|-----------------|-----------------|-----------------|-----------------------|
| `project_name` | Text | "Tracking Analysis" | Project title displayed in reports and used for output filenames. |
| `report_types` | CSV list | "detailed" | Which reports to generate. See [Output Reports](#9-output-reports). |
| `weight_variable` | Text | *(none)* | Global weight variable name. Used for all waves unless overridden by WeightVar in the Waves sheet. |
| `alpha` | Number | 0.05 | Significance level for statistical testing (0.05 = 95% confidence). |
| `minimum_base` | Number | 30 | Minimum base size for reporting. Cells below this threshold are suppressed. |
| `baseline_wave` | WaveID | *(first wave)* | Wave used for "vs Baseline" comparisons. Must match a WaveID from the Waves sheet. |
| `decimal_places_ratings` | Number | 1 | Decimal places for rating/mean scores in output. |
| `decimal_places_nps` | Number | 2 | Decimal places for NPS scores. |
| `decimal_places_percentages` | Number | 0 | Decimal places for percentage values. |
| `decimal_separator` | Character | "." | Decimal separator for output (`.` or `,`). |
| `show_significance` | Y/N | Y | Include significance testing indicators in output. |
| `output_dir` | Path | *(config file directory)* | Directory for output files. Created if it does not exist. |
| `output_file` | Filename | *(auto-generated)* | Specific output filename. Only used when generating a single report type. |
| `html_report` | Y/N | N | Generate interactive HTML report alongside Excel (only for `tracking_crosstab` report type). |
| `brand_colour` | Hex colour | #323367 | Primary brand colour for HTML report header, charts, and styling. |
| `accent_colour` | Hex colour | #CC9900 | Accent colour for HTML report highlights. |
| `company_name` | Text | *(blank)* | Company name displayed in HTML report header and footer. |
| `researcher_logo_path` | Path | *(none)* | Path to researcher/agency logo image for HTML report header. |
| `client_logo_path` | Path | *(none)* | Path to client logo image for HTML report header. |

**Default TrackingSpecs Settings** (override the built-in defaults for
each question type):

| Setting | Default | Description |
|---------------------|---------------------|------------------------------|
| `default_rating_specs` | "mean" | Default TrackingSpecs applied to Rating questions with no explicit specs. |
| `default_nps_specs` | "nps_score" | Default for NPS questions. |
| `default_single_response_specs` | "all" | Default for Single_Response questions. |
| `default_multi_mention_specs` | "auto" | Default for Multi_Mention questions. |
| `default_composite_specs` | "mean" | Default for Composite questions. |

**Example:**

| Setting              | Value                     |
|----------------------|---------------------------|
| project_name         | Brand Health Tracker 2024 |
| report_types         | tracking_crosstab         |
| weight_variable      | weight                    |
| alpha                | 0.05                      |
| minimum_base         | 30                        |
| html_report          | Y                         |
| brand_colour         | #1A5276                   |
| default_rating_specs | mean,top2_box             |

### 4.3 TrackedQuestions Sheet

Defines which questions to track and how to display them.

| Column | Required | Description |
|-------------------|-----------------------|------------------------------|
| `QuestionCode` | Yes | Must match a QuestionCode in your question_mapping.xlsx. |
| `MetricLabel` | No | Custom display label for this question in reports. Overrides the question text. |
| `TrackingSpecs` | No | Comma-separated metric specifications. See [TrackingSpecs Reference](#6-trackingspecs-reference). |
| `Section` | No | Report section grouping (e.g., "Brand Health", "Loyalty"). Questions in the same section appear together. |
| `SortOrder` | No | Numeric sort order within section. Lower numbers appear first. Defaults to row order. |

**Example:**

| QuestionCode | MetricLabel | TrackingSpecs | Section | SortOrder |
|---------------|---------------|---------------|---------------|---------------|
| Q_SAT | Overall Satisfaction | mean=Average,top2_box=Satisfied | Brand Health | 1 |
| Q_SERVICE | Service Quality | mean,top2_box | Brand Health | 2 |
| Q_NPS | Net Promoter Score | nps_score,promoters_pct,detractors_pct | Loyalty | 3 |
| Q_AWARE | Brand Awareness | category:Yes=Aware | Awareness | 4 |
| Q_INTENT | Purchase Intent | mean=Average,box:Agree=Positive,box:Disagree=Negative | Commercial | 5 |
| Q_COMPOSITE | Customer Experience | mean | Summary | 6 |

### 4.4 Banner Sheet

Defines demographic breakout segments. The tracker always calculates a
Total, plus any segments defined here.

| Column | Required | Description |
|-------------------|-----------------------|------------------------------|
| `BreakVariable` | Yes | Variable name in the data (e.g., `region`, `gender`). Use `Total` for the total sample row. |
| `BreakLabel` | Yes | Display label for this banner group (e.g., `Region`, `Gender`). |
| Wave columns (e.g., `W1`, `W2`) | No | Wave-specific variable names, if the banner variable has a different column name in each wave. |

**How it works:** - The tracker automatically discovers all unique
values in each break variable and creates a segment for each. - For
example, if `region` has values "Cape Town", "Joburg", "Durban", three
segments are created automatically. - Wave-specific columns are needed
only if the banner variable has a different name across waves (e.g.,
`Q24` in Wave 1 vs `Q02` in Wave 2).

**Example:**

| BreakVariable | BreakLabel | W1      | W2      | W3      |
|---------------|------------|---------|---------|---------|
| Total         | Total      |         |         |         |
| region        | Region     | region  | region  | region  |
| age_group     | Age Group  | age_grp | Q02_age | Q02_age |

------------------------------------------------------------------------

## 5. Question Mapping (question_mapping.xlsx)

### 5.1 QuestionMap Sheet

Maps each tracked question to its variable name in each wave's data.

| Column | Required | Description |
|-------------------|-----------------------|------------------------------|
| `QuestionCode` | Yes | Standardised question code (e.g., `Q_SAT`). Must match the codes in TrackedQuestions. |
| `QuestionText` | Yes | Full question wording. Used as display text in reports. |
| `QuestionType` | Yes | Question type. See [Valid Question Types](#52-valid-question-types) below. |
| Wave columns | Yes | One column per wave (matching WaveIDs from the Waves sheet). Contains the variable name in that wave's data. Leave blank if the question was not asked in a wave. |
| `SourceQuestions` | Only for Composite | Comma-separated list of QuestionCodes that make up this composite (e.g., `Q_SAT,Q_SERVICE,Q_VALUE`). |

**Example:**

| QuestionCode | QuestionText | QuestionType | W1 | W2 | W3 | SourceQuestions |
|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| Q_SAT | How satisfied are you overall? (1-10) | Rating | satisfaction | satisfaction | Q12_sat |  |
| Q_NPS | How likely to recommend? (0-10) | NPS | nps_score | nps_score | Q15_nps |  |
| Q_AWARE | Are you aware of our brand? | Single_Response | awareness | awareness | Q20_aware |  |
| Q_CHANNEL | Which channels have you used? | Multi_Mention | channel_online,channel_store,channel_phone | channel_online,channel_store,channel_phone | Q30 |  |
| Q_COMPOSITE | Customer Experience Index | Composite |  |  |  | Q_SAT,Q_SERVICE,Q_VALUE |

**Notes:** - Wave column names must match the WaveIDs from your Waves
sheet exactly (e.g., if your Waves sheet has `W1`, `W2`, `W3`, your
columns here must also be `W1`, `W2`, `W3`). - For **Multi_Mention**
questions in binary mode, the wave column contains a comma-separated
list of the option columns (e.g.,
`channel_online,channel_store,channel_phone`). - For **Composite**
questions, leave wave columns blank — the tracker calculates composites
from their SourceQuestions. - Questions can change variable name across
waves (e.g., `satisfaction` in W1 becomes `Q12_sat` in W3). This is the
primary purpose of the mapping.

### 5.2 Valid Question Types

The tracker accepts these question type names (case-insensitive):

| Internal Type | Accepted Names | Description |
|-------------------------|-------------------------|----------------------|
| **Rating** | `Rating`, `Likert`, `Index`, `Scale`, `Numeric` | Numeric scale questions (1-5, 1-10, etc.) |
| **NPS** | `NPS` | Net Promoter Score (0-10 scale) |
| **Single Response** | `Single_Response`, `SingleChoice`, `Single_Choice`, `CategoricalSingle` | One answer from a list |
| **Multi-Mention** | `Multi_Mention`, `MultiMention`, `Multi_Response`, `Multi_Choice`, `MultiChoice`, `CheckboxList` | Select all that apply |
| **Composite** | `Composite` | Calculated from other questions |
| **Open-Ended** | `Open_End`, `Text`, `Open`, `FreeText` | Free text (cannot be tracked numerically) |

------------------------------------------------------------------------

## 6. TrackingSpecs Reference

TrackingSpecs control which metrics are calculated and how they appear
in reports. They are set in the `TrackingSpecs` column of the
TrackedQuestions sheet.

### 6.1 Syntax

```         
spec1[=Label1],spec2[=Label2],...
```

-   Specs are comma-separated.
-   Each spec can optionally have a custom label after `=`.
-   Labels are display-only and do not affect calculations.

### 6.2 Custom Labels (`=Label`)

Append `=YourLabel` to any spec to override the default display label.

| Spec           | Default Label | With Custom Label    | Display     |
|----------------|---------------|----------------------|-------------|
| `mean`         | (Mean)        | `mean=Average`       | (Average)   |
| `top2_box`     | (Top 2 Box)   | `top2_box=Satisfied` | (Satisfied) |
| `range:4-5`    | (Range 4-5)   | `range:4-5=Agree`    | (Agree)     |
| `box:Agree`    | (% Agree)     | `box:Agree=Top Box`  | (Top Box)   |
| `category:Yes` | (% Yes)       | `category:Yes=Aware` | (Aware)     |

### 6.3 Rating / Composite Specs

These specs work with Rating, Likert, Index, Scale, Numeric, and
Composite question types.

| Spec | Description | Example Output |
|-----------------|--------------------------|------------------------------|
| `mean` | Weighted mean score | 7.8 |
| `top_box` | \% giving the highest value | 15.2% |
| `top2_box` | \% giving the top 2 values | 28.4% |
| `top3_box` | \% giving the top 3 values | 45.1% |
| `bottom_box` | \% giving the lowest value | 3.1% |
| `bottom2_box` | \% giving the bottom 2 values | 8.7% |
| `distribution` | \% for every value | *(full breakdown)* |
| `range:X-Y` | \% giving values from X to Y (inclusive) | 35.6% |
| `box:CategoryName` | \% of values in a BoxCategory group (requires StructureFile) | 42.3% |

**range: examples:**

```         
range:9-10        % giving 9 or 10 (promoter-style)
range:7-8         % giving 7 or 8 (passives-style)
range:1-6         % giving 1 through 6
range:4-5         % in a custom "satisfied" range on a 1-5 scale
```

**box: examples** (requires StructureFile with BoxCategory column):

```         
box:Agree         % of respondents whose answer maps to BoxCategory = "Agree"
box:Disagree      % mapping to "Disagree"
box:Neutral       % mapping to "Neutral"
```

**Combined example:**

```         
mean=Average,top2_box=Satisfied,range:9-10=Highly Satisfied
```

This tracks three metrics: the mean (labelled "Average"), the top 2 box
(labelled "Satisfied"), and a custom 9-10 range (labelled "Highly
Satisfied").

### 6.4 NPS Specs

| Spec | Description | Example Output |
|----|----|----|
| `nps_score` | Net Promoter Score (Promoters% - Detractors%) | +32 |
| `promoters_pct` | \% Promoters (9-10) | 48.5% |
| `passives_pct` | \% Passives (7-8) | 35.2% |
| `detractors_pct` | \% Detractors (0-6) | 16.3% |
| `full` | All four NPS metrics | *(all above)* |

### 6.5 Single-Choice Specs

| Spec                 | Description                                 |
|----------------------|---------------------------------------------|
| `all`                | Track all response options (default)        |
| `top3`               | Track the 3 most frequent responses         |
| `category:TextValue` | Track a specific category by its text value |

**Examples:**

```         
all                                     Track every response option
category:Yes                            Track only "Yes" responses
category:Brand A,category:Brand B       Track two specific brands
category:Yes=Aware                      Track "Yes" and display as "Aware"
```

### 6.6 Multi-Mention Specs

Multi-mention questions support two data formats:

**Binary mode:** Each option is a separate column with 0/1 values (e.g.,
`channel_online`, `channel_store`). **Category mode:** Options are text
values in columns (e.g., column contains "Brand A", "Brand B").

| Spec                  | Description                                       |
|-----------------------|-------------------------------------------------|
| `auto`                | Auto-detect all option columns (default)          |
| `any`                 | \% mentioning at least one option                 |
| `count_mean`          | Average number of options selected per respondent |
| `count_distribution`  | Distribution of mention counts                    |
| `option:VariableName` | Track a specific option column                    |
| `category:TextValue`  | Track a specific text value across option columns |

**Examples:**

```         
auto                                    Auto-detect and track all options
any                                     % who selected anything
option:channel_online,option:channel_app Track specific options
any,count_mean                          Overall % plus average count
category:Brand A,category:Brand B       Track specific text values
```

### 6.7 Defaults (When TrackingSpecs is Blank)

If no TrackingSpecs are provided, the tracker uses these defaults:

| Question Type           | Default Spec |
|-------------------------|--------------|
| Rating / Likert / Index | `mean`       |
| NPS                     | `nps_score`  |
| Single_Response         | `all`        |
| Multi_Mention           | `auto`       |
| Composite               | `mean`       |

You can override these defaults globally in the Settings sheet using
`default_rating_specs`, `default_nps_specs`, etc.

### 6.8 TrackingSpecs Priority

The tracker looks for TrackingSpecs in this order:

1.  **TrackedQuestions sheet** in tracking_config.xlsx (recommended
    location)
2.  **QuestionMap sheet** in question_mapping.xlsx (legacy location,
    still supported)
3.  **Default specs** from Settings sheet (e.g., `default_rating_specs`)
4.  **Built-in defaults** (mean for Rating, nps_score for NPS, etc.)

------------------------------------------------------------------------

## 7. Survey Structure Files (Optional)

Survey structure files enable two advanced features:

1.  **Text-to-numeric mapping** — when wave data contains text responses
    (e.g., "Strongly Agree") instead of numeric values (e.g., 5).
2.  **`box:` spec support** — grouping options by BoxCategory (e.g.,
    "Agree", "Neutral", "Disagree").

### 7.1 When Do You Need Structure Files?

| Scenario | Structure File Needed? |
|-----------------------|-------------------------------------------------|
| Data is numeric (1-5, 1-10) and you use standard specs (mean, top2_box) | No |
| Data has text responses ("Strongly Agree", "Disagree") | Yes |
| You want to use `box:CategoryName` specs | Yes |
| Data is numeric but you want box: groupings from metadata | Yes |

### 7.2 Structure File Format

Each wave can have its own `Survey_Structure.xlsx` (or reuse the same
one). It must contain an **Options** sheet:

| Column | Required | Description |
|-------------------|-----------------------|------------------------------|
| `QuestionCode` | Yes | The variable name as it appears in the wave data (e.g., `purchase_intent`, `Q12`). |
| `OptionText` | Yes | The text value as it appears in the data (e.g., "Strongly Agree"). Used for text-to-numeric lookup. |
| `DisplayText` | No | Override display label. Defaults to OptionText if absent. |
| `Index_Weight` | No | Numeric value this option maps to (e.g., 5 for "Strongly Agree" on a 1-5 scale). Required for text-to-numeric mapping. |
| `BoxCategory` | No | Category grouping (e.g., "Agree", "Neutral", "Disagree"). Required for `box:` specs. |

**Important:** The `QuestionCode` in the structure file must match the
**wave-specific variable name** (the value in your question mapping's
wave column), not the abstract QuestionCode from the TrackedQuestions
sheet.

**Example Options sheet:**

| QuestionCode    | OptionText        | DisplayText       | Index_Weight | BoxCategory |
|---------------|---------------|---------------|---------------|---------------|
| purchase_intent | Strongly Disagree | Strongly Disagree | 1            | Disagree    |
| purchase_intent | Disagree          | Disagree          | 2            | Disagree    |
| purchase_intent | Neutral           | Neutral           | 3            | Neutral     |
| purchase_intent | Agree             | Agree             | 4            | Agree       |
| purchase_intent | Strongly Agree    | Strongly Agree    | 5            | Agree       |
| satisfaction    | 1                 | Very Dissatisfied | 1            |             |
| satisfaction    | 2                 | Dissatisfied      | 2            |             |
| ...             | ...               | ...               | ...          |             |
| satisfaction    | 10                | Very Satisfied    | 10           |             |

### 7.3 How Text-to-Numeric Mapping Works

When a StructureFile is provided:

1.  The tracker extracts raw response data from the wave CSV/Excel.
2.  If the data is text (not numeric), it looks up each value in the
    structure's `OptionText` column (case-insensitive).
3.  Each text value is replaced with the corresponding `Index_Weight`.
4.  Downstream calculations (mean, top2_box, etc.) receive numeric
    values.
5.  If no mapping is found, the tracker attempts direct numeric
    conversion as a fallback.

**If no StructureFile is provided:** The tracker assumes data is already
numeric. Text data without a structure file will produce NA values.

### 7.4 Per-Wave Config Files

Each wave can optionally reference a `Crosstab_Config.xlsx` via the
`ConfigFile` column in the Waves sheet. The tracker reads the
**Settings** sheet for weighting configuration:

| Setting | Values | Description |
|----------------------|--------------------|-------------------------------|
| `apply_weighting` | TRUE/Y/YES/1 or FALSE/N/NO/0 | Whether to apply weights for this wave |
| `weight_variable` | Variable name (e.g., "weight") | Which column contains the weights |

**Weighting priority (first match wins):** 1. ConfigFile settings (if
ConfigFile column exists and file specifies weighting) 2. WeightVar
column in the Waves sheet 3. Global `weight_variable` setting in the
Settings sheet 4. Unweighted (weight = 1 for all respondents)

------------------------------------------------------------------------

## 8. Running the Tracker

### 8.1 Via R Code

``` r
# Source the tracker module
source("modules/tracker/run_tracker.R")

# Run with all options
result <- run_tracker(
  tracking_config_path = "path/to/tracking_config.xlsx",
  question_mapping_path = "path/to/question_mapping.xlsx",
  data_dir = "path/to/data/",
  use_banners = TRUE,
  enable_html = TRUE
)
```

### 8.2 Via the GUI

``` r
source("modules/tracker/run_tracker_gui.R")
run_tracker_gui()
```

The GUI provides: - File pickers for all input files - Auto-detection of
question mapping files - Checkboxes for `use_banners` (default: on) and
`enable_html` (default: on) - Console output with progress and error
details - Recent project memory (last 5 projects)

### 8.3 Banner Breakouts (use_banners)

| Setting | Behaviour |
|---------------------------------|---------------------------------------|
| `use_banners = FALSE` | Calculate trends for Total sample only (faster) |
| `use_banners = TRUE` | Calculate trends for Total + each banner segment (e.g., Region: Cape Town, Joburg, Durban) |

### 8.4 HTML Reports (enable_html)

The HTML report is only generated for the `tracking_crosstab` report
type.

| Setting               | Behaviour                                     |
|-----------------------|-----------------------------------------------|
| `enable_html = NULL`  | Reads from config `html_report` setting (Y/N) |
| `enable_html = TRUE`  | Force HTML generation (overrides config)      |
| `enable_html = FALSE` | Skip HTML generation (overrides config)       |

------------------------------------------------------------------------

## 9. Output Reports

### 9.1 Report Types

Set the `report_types` setting in your Settings sheet. Multiple types
are comma-separated.

| Report Type | Description | Output |
|---------------------------|---------------------------|------------------|
| `detailed` | Full trend analysis with statistics per question | `{ProjectName}_Tracker_{Date}.xlsx` |
| `wave_history` | Wave-by-wave history table | `{ProjectName}_WaveHistory_{Date}.xlsx` |
| `dashboard` | Executive summary with significance matrices | `{ProjectName}_Dashboard_{Date}.xlsx` |
| `sig_matrix` | Standalone significance test matrices | `{ProjectName}_SigMatrix_{Date}.xlsx` |
| `tracking_crosstab` | Crosstab format (recommended) + optional HTML | `{ProjectName}_TrackingCrosstab_{Date}.xlsx` + `.html` |

**Example:**

```         
report_types = tracking_crosstab
```

### 9.2 Output File Naming

Output filenames are auto-generated from your `project_name` setting:

```         
{project_name}_{ReportType}_{YYYYMMDD}.xlsx
```

Special characters in the project name are replaced with underscores.
You can override the filename using the `output_file` setting (only when
generating a single report type) or the `output_path` parameter.

### 9.3 HTML Report Features

The interactive HTML report includes: - Section grouping with
collapsible sections - Banner segment tabs (Total, Region segments,
etc.) - Data tables with wave-over-wave values and changes -
Significance indicators (arrows and colour coding) - Trend line charts
per metric - Export to CSV functionality - Responsive design for screen
and print - Self-contained (no external dependencies, shareable as a
single file)

HTML report appearance is controlled by the `brand_colour`,
`accent_colour`, `company_name`, `researcher_logo_path`, and
`client_logo_path` settings.

------------------------------------------------------------------------

## 10. Examples

### 10.1 Basic Tracking (Numeric Data)

**tracking_config.xlsx — Settings:** \| Setting \| Value \|
\|---------\|-------\| \| project_name \| Employee Satisfaction \| \|
report_types \| tracking_crosstab \| \| weight_variable \| weight \| \|
html_report \| Y \|

**tracking_config.xlsx — Waves:** \| WaveID \| WaveName \| DataFile \|
FieldworkStart \| FieldworkEnd \| WeightVar \|
\|--------\|----------\|----------\|----------------\|--------------\|-----------\|
\| W1 \| Q1 2024 \| wave_1.csv \| 2024-01-15 \| 2024-02-15 \| weight \|
\| W2 \| Q2 2024 \| wave_2.csv \| 2024-04-15 \| 2024-05-15 \| weight \|

**tracking_config.xlsx — TrackedQuestions:** \| QuestionCode \|
MetricLabel \| TrackingSpecs \| Section \|
\|--------------\|-------------\|---------------\|---------\| \| Q_SAT
\| Overall Satisfaction \| mean,top2_box \| Satisfaction \| \| Q_NPS \|
NPS \| nps_score,promoters_pct \| Loyalty \|

**question_mapping.xlsx — QuestionMap:** \| QuestionCode \| QuestionText
\| QuestionType \| W1 \| W2 \|
\|--------------\|-------------\|--------------\|-----\|-----\| \| Q_SAT
\| Overall satisfaction (1-10) \| Rating \| Q10 \| Q12 \| \| Q_NPS \|
Likelihood to recommend (0-10) \| NPS \| Q15 \| Q15 \|

### 10.2 Text Data with Structure Files

When your survey exports text responses instead of numbers:

**wave_1.csv:**

```         
respondent_id,region,weight,purchase_intent
R001,Cape Town,1.2,Strongly Agree
R002,Joburg,0.8,Disagree
R003,Durban,1.1,Neutral
```

**tracking_config.xlsx — Waves (add StructureFile):** \| WaveID \|
WaveName \| DataFile \| StructureFile \| ... \|
\|--------\|----------\|----------\|---------------\|-----\| \| W1 \| Q1
2024 \| wave_1.csv \| structure_w1.xlsx \| ... \|

**structure_w1.xlsx — Options:** \| QuestionCode \| OptionText \|
Index_Weight \| BoxCategory \|
\|--------------\|-----------\|--------------\|-------------\| \|
purchase_intent \| Strongly Disagree \| 1 \| Disagree \| \|
purchase_intent \| Disagree \| 2 \| Disagree \| \| purchase_intent \|
Neutral \| 3 \| Neutral \| \| purchase_intent \| Agree \| 4 \| Agree \|
\| purchase_intent \| Strongly Agree \| 5 \| Agree \|

**tracking_config.xlsx — TrackedQuestions:** \| QuestionCode \|
TrackingSpecs \| \|--------------\|---------------\| \| Q_INTENT \|
mean=Average,box:Agree=Positive,box:Disagree=Negative \|

This produces three metrics: - **Purchase Intent (Average)** — mean
score mapped from text (e.g., 3.45) - **Purchase Intent (Positive)** — %
of Agree + Strongly Agree (e.g., 55.3%) - **Purchase Intent (Negative)**
— % of Disagree + Strongly Disagree (e.g., 15.9%)

### 10.3 Multi-Mention Question (Binary Mode)

**Data format** — each option is a separate 0/1 column:

```         
respondent_id,ch_online,ch_store,ch_phone,ch_app
R001,1,0,1,1
R002,0,1,0,0
```

**question_mapping.xlsx:** \| QuestionCode \| QuestionType \| W1 \|
\|--------------\|-------------\|-----\| \| Q_CHANNEL \| Multi_Mention
\| ch_online,ch_store,ch_phone,ch_app \|

**TrackingSpecs options:**

```         
auto                    Track all 4 channels individually
any                     % using any channel
option:ch_online        Track online only
auto,any,count_mean     All channels + any + average count
```

### 10.4 Banner Breakouts

**tracking_config.xlsx — Banner:** \| BreakVariable \| BreakLabel \| W1
\| W2 \| W3 \| \|---------------\|------------\|-----\|-----\|-----\| \|
Total \| Total \| \| \| \| \| region \| Region \| region \| region \|
region \|

This produces separate output for: - **Total** — all respondents -
**Region_Cape Town** — respondents where region = "Cape Town" -
**Region_Joburg** — respondents where region = "Joburg" -
**Region_Durban** — respondents where region = "Durban"

Wave-specific columns are only needed when the banner variable has a
different column name in different waves.

### 10.5 Composite Questions

A composite combines multiple tracked questions into a single index.

**question_mapping.xlsx:** \| QuestionCode \| QuestionType \| W1 \| W2
\| SourceQuestions \|
\|--------------\|-------------\|-----\|-----\|----------------\| \|
Q_SAT \| Rating \| satisfaction \| satisfaction \| \| \| Q_SERVICE \|
Rating \| service \| service \| \| \| Q_VALUE \| Rating \| value \|
value \| \| \| Q_COMPOSITE \| Composite \| \| \| Q_SAT,Q_SERVICE,Q_VALUE
\|

The composite calculates the mean of each respondent's scores across the
source questions, then applies the requested metrics (mean, top2_box,
etc.) to the composite values. Wave columns for composites should be
left blank.

------------------------------------------------------------------------

## 11. Troubleshooting

### Common Issues

**"Text values found but no structure mapping available"** - Your data
has text responses but no StructureFile is configured. - Add a
StructureFile column to your Waves sheet and provide a
Survey_Structure.xlsx with an Options sheet mapping text to numeric
values.

**"Column 'X' not found in wave data"** - The variable name in your
question mapping does not match a column in the wave data file. - Check
spelling and case. Open the wave CSV and verify the exact column names.

**"Banner variable 'X' not found in wave data"** - The BreakVariable in
your Banner sheet does not match a column in the data. - If the variable
name changes between waves, add wave-specific columns to the Banner
sheet.

**"box:CategoryName spec requires a StructureFile"** - You used a `box:`
spec but no StructureFile is configured for this wave. - Add
StructureFile to your Waves sheet with a structure file that includes
BoxCategory values.

**"No test files found" or empty output** - Check that your
TrackedQuestions has QuestionCodes that match the question_mapping. -
Verify your wave data files exist at the paths specified in the Waves
sheet.

**Blank/NA values in output** - Check that the question exists in the
wave data (variable name matches). - For text data, ensure the
StructureFile maps all text values to numeric Index_Weight values. -
Check the console output for warnings about unmapped values.

### Data Cleaning

The tracker automatically handles these common data quality issues:

| Input                            | Converted To |
|----------------------------------|--------------|
| `7,5` (comma decimal)            | `7.5`        |
| `DK`, `Don't Know`, `Don't know` | NA           |
| `NS`, `NR`, `Prefer not to say`  | NA           |
| `Refused`, `N/A`                 | NA           |
| Empty strings                    | NA           |

### Error Log

When errors occur, the tracker writes a detailed error log to the same
directory as your config file:

```         
tracker_error.log
```

This contains the error message, timestamp, and full call stack for
debugging.

------------------------------------------------------------------------

## Full Test Project

A complete working example is available at:

```         
examples/tracker/full_test/
```

This includes all file types (config, mapping, wave data, structure
files, config files) and demonstrates every feature including text data
mapping, `box:` specs, `=Label` syntax, banner breakouts, and HTML
output.

To run it:

``` r
source("examples/tracker/full_test/run_test.R")
```

Or regenerate the test data:

``` r
source("examples/tracker/full_test/generate_test_data.R")
generate_full_test_project("examples/tracker/full_test")
```
