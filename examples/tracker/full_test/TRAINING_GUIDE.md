---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tracker — Step-by-Step Training Guide

This guide walks you through setting up, running, and using the Turas
Tracker module from scratch. It uses the included test project as a
hands-on example so you can see every feature in action.

------------------------------------------------------------------------

## Table of Contents

1.  [What Turas Tracker Does](#1-what-turas-tracker-does)
2.  [Folder Structure Overview](#2-folder-structure-overview)
3.  [Step 1: Prepare Your Wave Data
    Files](#step-1-prepare-your-wave-data-files)
4.  [Step 2: Create the Question
    Mapping](#step-2-create-the-question-mapping)
5.  [Step 3: Create the Tracking
    Configuration](#step-3-create-the-tracking-configuration)
6.  [Step 4: Run the Tracker](#step-4-run-the-tracker)
7.  [Step 5: Review the Excel Output](#step-5-review-the-excel-output)
8.  [Step 6: Open and Use the HTML
    Report](#step-6-open-and-use-the-html-report)
9.  [Configuration Reference](#configuration-reference)
10. [Troubleshooting](#troubleshooting)

------------------------------------------------------------------------

## 1. What Turas Tracker Does

Turas Tracker compares survey results **across multiple waves** (time
points). It answers the question: *"How have our metrics changed over
time, and are those changes statistically significant?"*

**What it produces:**

-   A **Tracking Crosstab** — a table where each row is a tracked metric
    (e.g. "Satisfaction Mean") and the columns are waves (Jan 2024, Apr
    2024, etc.), broken out by banner segments (Total, Region, etc.)
-   **Change sub-rows** showing the difference vs the previous wave and
    vs a configurable baseline wave, with significance arrows
-   An **Excel workbook** with the full crosstab data
-   An **interactive HTML report** you can open in any browser — with
    charts, filtering, export, and more

**What you need:**

1.  One CSV (or Excel) data file per wave
2.  A `question_mapping.xlsx` file that maps question codes to column
    names
3.  A `tracking_config.xlsx` file that defines waves, settings, banners,
    and which questions to track

------------------------------------------------------------------------

## 2. Folder Structure Overview

The test project lives at `examples/tracker/full_test/`. Here is what
each file does:

```         
full_test/
  tracking_config.xlsx     ← Analysis configuration (what to track, how)
  question_mapping.xlsx    ← Maps question codes to data columns
  wave_1.csv               ← Wave 1 data (Jan 2024, 100 respondents)
  wave_2.csv               ← Wave 2 data (Apr 2024, 100 respondents)
  wave_3.csv               ← Wave 3 data (Jul 2024, 100 respondents)
  wave_4.csv               ← Wave 4 data (Oct 2024, 100 respondents)
  run_test.R               ← Convenience script to run the analysis
  generate_test_data.R     ← Script that generated all the test files
```

After running the tracker, two output files appear in the same folder:

```         
  Brand_Health_Tracker_2024_TrackingCrosstab_YYYYMMDD.xlsx   ← Excel report
  Brand_Health_Tracker_2024_TrackingCrosstab_YYYYMMDD.html   ← Interactive HTML report
```

------------------------------------------------------------------------

## Step 1: Prepare Your Wave Data Files {#step-1-prepare-your-wave-data-files}

Each wave of your survey needs its own data file (CSV or Excel). Each
file contains one row per respondent.

### What the columns look like

Open `wave_1.csv` to see the structure:

| respondent_id | region | weight | satisfaction | service_rating | nps_score | awareness | brand_preference | channel_online | channel_store | ... |
|-------|-------|-------|-------|-------|-------|-------|-------|-------|-------|-------|
| R0001 | Cape Town | 1.14 | 8 | 7 | 8 | Yes | Brand A | 1 | 0 | ... |
| R0002 | Joburg | 0.85 | 7 | 6 | 7 | Yes | Brand B | 0 | 1 | ... |

### Column types and how the tracker uses them

| Column Type | Example Columns | What They Contain |
|--------------------|------------------------|----------------------------|
| **ID** | `respondent_id` | Unique per respondent (optional, not required) |
| **Banner/Segment** | `region` | Categorical values used for breakouts (e.g. "Cape Town", "Joburg") |
| **Weight** | `weight` | Decimal weight per respondent (e.g. 1.14). Set to 1.0 if unweighted |
| **Rating questions** | `satisfaction`, `service_rating`, `value_rating`, `purchase_intent` | Numeric scales (e.g. 1-10 or 1-5) |
| **NPS question** | `nps_score` | 0-10 scale for Net Promoter Score |
| **Single response** | `awareness`, `brand_preference` | Text categories (e.g. "Yes"/"No" or "Brand A"/"Brand B") |
| **Multi-mention** | `channel_online`, `channel_store`, `channel_phone`, `channel_app` | Binary 0/1 columns, one per option |

### Key rules

-   **Column names must be consistent across waves** — the same question
    should use the same column name in all CSV files (or you can use
    wave-specific mappings in the question mapping)
-   **Rating/NPS columns must be numeric** — the tracker converts them
    automatically
-   **Single response columns stay as text** — "Yes", "No", "Brand A"
    etc.
-   **Multi-mention uses one column per option** — each column is 0 (not
    mentioned) or 1 (mentioned)

------------------------------------------------------------------------

## Step 2: Create the Question Mapping {#step-2-create-the-question-mapping}

The **question mapping** (`question_mapping.xlsx`) tells the tracker
what questions exist, what type each is, and which column in each wave's
data file contains that question.

### The QuestionMap sheet

Open `question_mapping.xlsx`. It has a single sheet called
**QuestionMap**:

| QuestionCode | QuestionText | QuestionType | W1 | W2 | W3 | W4 | SourceQuestions |
|---------|---------|---------|---------|---------|---------|---------|---------|
| Q_SAT | Overall, how satisfied are you with our brand? (1-10) | Rating | satisfaction | satisfaction | satisfaction | satisfaction |  |
| Q_SERVICE | How would you rate the quality of our service? (1-10) | Rating | service_rating | service_rating | service_rating | service_rating |  |
| Q_NPS | How likely are you to recommend us? (0-10) | NPS | nps_score | nps_score | nps_score | nps_score |  |
| Q_AWARE | Are you aware of our brand? | Single_Response | awareness | awareness | awareness | awareness |  |
| Q_PREF | Which brand do you prefer? | Single_Response | brand_preference | brand_preference | brand_preference | brand_preference |  |
| Q_CHANNEL | Which channels have you used? | Multi_Mention | channel_online,channel_store,channel_phone,channel_app | (same) | (same) | (same) |  |
| Q_INTENT | How likely are you to purchase? (1-5) | Rating | purchase_intent | purchase_intent | purchase_intent | purchase_intent |  |
| Q_COMPOSITE | Customer Experience Index | Composite | Q_SAT,Q_SERVICE,Q_VALUE | (same) | (same) | (same) | Q_SAT,Q_SERVICE,Q_VALUE |

### Column explanations

-   **QuestionCode**: A short unique identifier you choose (e.g. Q_SAT).
    Used throughout the system.
-   **QuestionText**: The full question wording. Appears in reports as a
    label.
-   **QuestionType**: Must be one of:
    -   `Rating` — Numeric scale (1-5, 1-7, 1-10, etc.)
    -   `NPS` — Net Promoter Score (0-10 scale, automatically calculates
        Promoters/Passives/Detractors)
    -   `Single_Response` — Categorical with one answer per respondent
        (Yes/No, Brand A/B/C)
    -   `Multi_Mention` — Multiple binary columns (one per option, 0/1
        values)
    -   `Composite` — Calculated from other questions (e.g. average of
        SAT + SERVICE + VALUE)
-   **W1, W2, W3, W4**: The column name(s) in each wave's data file that
    contain this question's data. For multi-mention, list all columns
    separated by commas.
-   **SourceQuestions**: Only used for `Composite` type. Lists the
    QuestionCodes that feed into the composite.

### When column names change between waves

If a question was called `q5_satisfaction` in Wave 1 but
`satisfaction_v2` in Wave 2, put the Wave 1 name in the W1 column and
the Wave 2 name in W2. This is exactly why the wave columns exist.

------------------------------------------------------------------------

## Step 3: Create the Tracking Configuration {#step-3-create-the-tracking-configuration}

The **tracking configuration** (`tracking_config.xlsx`) is the main
control file. It has **4 sheets**.

### Sheet 1: Waves

Defines each wave of the study.

| WaveID | WaveName | DataFile   | FieldworkStart | FieldworkEnd | WeightVar |
|--------|----------|------------|----------------|--------------|-----------|
| W1     | Jan 2024 | wave_1.csv | 2024-01-01     | 2024-01-31   | weight    |
| W2     | Apr 2024 | wave_2.csv | 2024-04-01     | 2024-04-30   | weight    |
| W3     | Jul 2024 | wave_3.csv | 2024-07-01     | 2024-07-31   | weight    |
| W4     | Oct 2024 | wave_4.csv | 2024-10-01     | 2024-10-31   | weight    |

-   **WaveID**: Short identifier (W1, W2...) — must match the column
    names in the QuestionMap
-   **WaveName**: Display label used in reports (e.g. "Jan 2024")
-   **DataFile**: Filename of the CSV data file. Paths are relative to
    the data directory
-   **FieldworkStart/End**: Fieldwork dates (used for display in
    reports)
-   **WeightVar**: Name of the weight column in the data file. Leave
    blank for unweighted

### Sheet 2: Settings

Key-value pairs that control the analysis. The test project uses:

| Setting | Value | What It Does |
|----------------------|------------------|---------------------------------|
| project_name | Brand Health Tracker 2024 | Report title shown in header |
| baseline_wave | W1 | Which wave to compare against for "vs Baseline" changes. Defaults to first wave |
| confidence_level | 0.95 | Statistical confidence level (0.95 = 95%) |
| decimal_places_ratings | 1 | Decimal places for mean values (e.g. 7.2 vs 7.24) |
| show_significance | Y | Whether to calculate and show significance testing |
| report_types | tracking_crosstab | Which report to generate. Use `tracking_crosstab` for the new report |
| html_report | Y | Set to `Y` to also generate an interactive HTML report |
| brand_colour | #323367 | Primary colour for the HTML report (hex code) |
| accent_colour | #CC9900 | Secondary colour (hex code) |
| company_name | The Research LampPost | Shown in the report footer |
| client_name | Test Client Ltd | Optional client name |
| fieldwork_dates | Jan - Oct 2024 | Displayed in report metadata |
| default_rating_specs | mean,top2_box | Default metrics for Rating questions if TrackingSpecs is blank |
| default_nps_specs | nps_score,promoters_pct | Default metrics for NPS questions if TrackingSpecs is blank |

### Sheet 3: Banner

Defines how to break results out by subgroups (segments). The system
automatically discovers the unique values within each banner variable.

| BreakVariable | BreakLabel | W1     | W2     | W3     | W4     |
|---------------|------------|--------|--------|--------|--------|
| Total         | Total      |        |        |        |        |
| region        | Region     | region | region | region | region |

-   **BreakVariable**: The conceptual variable name. `Total` is always
    included.
-   **BreakLabel**: Display name for the group (e.g. "Region"). This
    becomes a prefix: Region_Cape Town, Region_Joburg, etc.
-   **W1-W4**: The actual column name in each wave's data file that
    contains this variable. Leave blank for Total.

**Important**: You need **one row per break variable**, not one row per
value. The tracker automatically finds all unique values (e.g. "Cape
Town", "Joburg", "Durban") from the data.

If the column name changes between waves (e.g. `region_v1` in Wave 1,
`demo_region` in Wave 2), put the different names in the W1 and W2
columns.

### Sheet 4: TrackedQuestions

Specifies which questions to include in the tracking crosstab and what
metrics to compute for each.

| QuestionCode | MetricLabel | TrackingSpecs | Section | SortOrder |
|---------------|---------------|---------------|---------------|---------------|
| Q_SAT | Overall Satisfaction | mean,top2_box,top_box | Brand Health | 1 |
| Q_SERVICE | Service Quality | mean,top2_box | Brand Health | 2 |
| Q_VALUE | Value for Money | mean,bottom2_box | Brand Health | 3 |
| Q_NPS | Net Promoter Score | nps_score,promoters_pct,detractors_pct | Loyalty | 4 |
| Q_AWARE | Brand Awareness | category:Yes | Awareness | 5 |
| Q_PREF | Brand Preference | category:Brand A,category:Brand B | Awareness | 6 |
| Q_CHANNEL | Channel Usage | any | Channels | 7 |
| Q_INTENT | Purchase Intent | mean,top_box | Commercial | 8 |
| Q_COMPOSITE | Customer Experience Index | mean | Summary Metrics | 9 |

-   **QuestionCode**: Must match a code in the QuestionMap sheet
-   **MetricLabel**: Friendly name used in reports. If a question has
    multiple TrackingSpecs (e.g. mean AND top2_box), the label gets a
    suffix like "(Mean)", "(Top 2 Box)"
-   **TrackingSpecs**: Comma-separated list of which metrics to compute.
    Available specs depend on QuestionType:

| QuestionType | Available TrackingSpecs | What Each Produces |
|------------------------|------------------------|------------------------|
| **Rating** | `mean` | Average score |
|  | `top_box` | \% giving highest scale point (e.g. 10 out of 10) |
|  | `top2_box` | \% giving top two scale points (e.g. 9-10 out of 10) |
|  | `top3_box` | \% giving top three |
|  | `bottom_box` | \% giving lowest scale point |
|  | `bottom2_box` | \% giving bottom two |
|  | `range:X-Y` | \% within a specific range (e.g. `range:8-10`) |
| **NPS** | `nps_score` | Net Promoter Score (-100 to +100) |
|  | `promoters_pct` | \% Promoters (9-10) |
|  | `passives_pct` | \% Passives (7-8) |
|  | `detractors_pct` | \% Detractors (0-6) |
| **Single_Response** | `category:VALUE` | \% choosing that specific value (e.g. `category:Yes`) |
| **Multi_Mention** | `any` | \% mentioning any option |
|  | `category:VALUE` | \% mentioning a specific option |
| **Composite** | `mean` | Average of the source questions |

-   **Section**: Groups metrics into sections in the report (e.g. "Brand
    Health", "Loyalty"). Sections appear as headers and group the
    sidebar navigation.
-   **SortOrder**: Controls display order within and across sections.
    Lower numbers appear first.

------------------------------------------------------------------------

## Step 4: Run the Tracker {#step-4-run-the-tracker}

### Option A: Using the convenience script

Open R (or RStudio) and set your working directory to the Turas root:

``` r
setwd("/path/to/Turas")   # adjust to your actual Turas location
source("examples/tracker/full_test/run_test.R")
```

### Option B: Running manually

``` r
setwd("/path/to/Turas")
source("modules/tracker/run_tracker.R")

result <- run_tracker(
  tracking_config_path = "examples/tracker/full_test/tracking_config.xlsx",
  question_mapping_path = "examples/tracker/full_test/question_mapping.xlsx",
  data_dir = "examples/tracker/full_test",
  use_banners = TRUE
)
```

### What happens when you run it

You will see console output showing 8 steps:

```         
[1/6] LOADING CONFIGURATION
  Project: Brand Health Tracker 2024
  Waves: Jan 2024, Apr 2024, Jul 2024, Oct 2024

[2/6] LOADING QUESTION MAPPING
  Building question map index...

[3/6] VALIDATING CONFIGURATION
  (checks all settings, wave files, and question codes)

[4/6] LOADING WAVE DATA
  Loading Wave W1: Jan 2024 — Loaded 100 records
  Loading Wave W2: Apr 2024 — Loaded 100 records
  Loading Wave W3: Jul 2024 — Loaded 100 records
  Loading Wave W4: Oct 2024 — Loaded 100 records

[5/6] VALIDATING WAVE DATA

[7/8] CALCULATING TRENDS
  CALCULATING TRENDS WITH BANNER BREAKOUTS
  Banner segments: 4  (Total, Region_Cape Town, Region_Joburg, Region_Durban)
  Processing question: Q_SAT
  Processing question: Q_SERVICE
  ...all 9 questions processed...

[8/8] GENERATING OUTPUT
  Building tracking crosstab...
  Generating Tracking Crosstab Excel report...
  Tracking Crosstab saved to: ...TrackingCrosstab_YYYYMMDD.xlsx

  Generating Tracker HTML report...
    [1/5] Validating inputs...
    [2/5] Transforming data for HTML...
    [3/5] Building tables and charts...
    [4/5] Assembling page...
    [5/5] Writing HTML file...
  Tracker HTML report saved: ...TrackingCrosstab_YYYYMMDD.html (0.2 MB)

TRACKING ANALYSIS COMPLETE
  Elapsed time: ~15 seconds
  Output files generated:
    tracking_crosstab: ...xlsx
    tracking_crosstab_html: ...html
```

### Parameter reference

| Parameter | Required | Description |
|-----------------------|---------------------|---------------------------|
| `tracking_config_path` | Yes | Path to your `tracking_config.xlsx` |
| `question_mapping_path` | Yes | Path to your `question_mapping.xlsx` |
| `data_dir` | No | Directory where wave CSV files are. If not set, uses the config file's directory |
| `output_path` | No | Explicit output path. If not set, auto-generates a filename |
| `use_banners` | No | Set to `TRUE` to calculate banner breakouts. Default `FALSE` (Total only) |

------------------------------------------------------------------------

## Step 5: Review the Excel Output {#step-5-review-the-excel-output}

Open the generated `.xlsx` file. It contains two sheets.

### Summary sheet

A metadata summary showing: - Project name and generation timestamp -
Waves included and their date labels - Baseline wave (which wave is the
"vs Baseline" reference) - Number of banner segments - Number of tracked
metrics - Confidence level - Section breakdown (how many metrics per
section) - Legend explaining the significance symbols: - **vs Prev** =
change compared to the previous wave - **vs Base** = change compared to
the baseline wave (W1 by default) - ↑ = Significant increase - ↓ =
Significant decrease - → = No significant change

### Tracking Crosstab sheet

This is the main data sheet. The layout is:

```         
              | ---- Total ---- | ---- Region_Cape Town ---- | ---- Region_Joburg ---- | ...
Metric        | Jan  Apr  Jul  Oct | Jan  Apr  Jul  Oct      | Jan  Apr  Jul  Oct      | ...
─────────────────────────────────────────────────────────────────────────────────────────
BRAND HEALTH
─────────────────────────────────────────────────────────────────────────────────────────
Overall Sat.  | 6.9  7.1  7.3  7.7 | 7.3  7.5  7.7  8.1      | 6.6  7.0  7.1  7.5      |
  vs Prev     |      +0.2 +0.2 +0.4|      +0.2 +0.2 +0.4→    |      +0.4 +0.1 +0.4     |
  vs Base     |      +0.2 +0.4 +0.8|      +0.2 +0.4 +0.8↑    |      +0.4 +0.5 +0.9     |
```

Each metric has **3 rows**: 1. **Value row** — the actual metric value
for each wave 2. **vs Prev row** — change from the immediately preceding
wave, with significance arrow 3. **vs Base row** — change from the
baseline wave, with significance arrow

Change values are formatted as: - Ratings: `+0.3` (decimal change) -
Percentages: `+5pp` (percentage point change) - NPS: `+6` (point change)

------------------------------------------------------------------------

## Step 6: Open and Use the HTML Report {#step-6-open-and-use-the-html-report}

Double-click the generated `.html` file to open it in your browser. No
internet connection needed — everything is self-contained in a single
file.

### Report Layout

The HTML report has these areas:

```         
┌─────────────────────────────────────────────────────────┐
│  HEADER (brand colour, project name, stats summary)     │
├──────────┬──────────────────────────────────────────────┤
│          │  SEGMENT TABS (Total | Region_Cape Town | ...)│
│ SIDEBAR  ├──────────────────────────────────────────────┤
│          │  CONTROLS (toggles, view, export)             │
│ (metric  ├──────────────────────────────────────────────┤
│  list)   │                                              │
│          │  MAIN TABLE / CHARTS                          │
│          │  (tracking crosstab data)                     │
│          │                                              │
├──────────┴──────────────────────────────────────────────┤
│  FOOTER (baseline, confidence level, generation date)   │
└─────────────────────────────────────────────────────────┘
```

### The Header

Shows: - **Project name**: "Brand Health Tracker 2024" - **Report
type**: "Tracking Report" - **Stats**: "17 metrics \| 4 waves \| 4
segments"

The header uses your configured `brand_colour` as background.

### The Sidebar (left panel)

A scrollable navigation panel with: - **Search box**: Type to filter the
metric list (e.g. type "NPS" to find just NPS metrics) - **Section
headings**: AWARENESS, BRAND HEALTH, CHANNELS, etc. (from your Section
config) - **Metric links**: Click any metric name to scroll to and
highlight it in the table

### Segment Tabs

Buttons across the top of the content area: - **Total** — Shows only the
Total (all respondents) columns - **Region_Cape Town** — Shows only the
Cape Town columns - **Region_Joburg** — Shows only the Joburg columns -
**Region_Durban** — Shows only the Durban columns - **All Segments** —
Shows all columns side by side for comparison

Click a tab to switch which segment's data is visible. The active tab is
highlighted in the brand colour.

### Controls Bar

A row of interactive controls:

| Control | What It Does |
|----------------------------|-------------------------------------------|
| **Show vs Previous** (checkbox) | Toggles the "vs Prev" change rows visible/hidden. **Hidden by default** — check the box to show them |
| **Show vs Baseline** (checkbox) | Toggles the "vs Base" change rows visible/hidden. **Hidden by default** |
| **Sparklines** (checkbox) | Toggles the tiny trend lines next to each metric label. On by default |
| **Table** / **Charts** (buttons) | Switch between table view and line chart view |
| **Group by** (dropdown) | Reorganise the table by: Section (default), Metric Type, or Question |
| **Export CSV** | Downloads the visible table as a CSV file |
| **Export Excel** | Downloads the visible table as an Excel file |
| **?** (help button) | Opens a help overlay explaining the report features |

### The Main Table

The core of the report. Identical structure to the Excel crosstab:

-   **Section headers** (coloured bands): "BRAND HEALTH", "LOYALTY",
    etc.
-   **Metric rows**: Each tracked metric with its value per wave
    -   The metric label on the left has a **sparkline** — a tiny line
        chart showing the trend
    -   Data cells show the metric value (e.g. "7.3", "52%", "+38")
-   **Change rows** (hidden by default):
    -   **vs Prev**: Shows change from previous wave with significance
        arrows
    -   **vs Base**: Shows change from baseline wave
-   **Base row** at the bottom showing sample sizes (n)

### Significance Indicators (in change rows)

When change rows are visible, each cell shows: - The numeric change
(e.g. "+0.3", "+5pp", "+6") - A coloured significance indicator: -
**Green ↑** = Statistically significant increase (good news) - **Red ↓**
= Statistically significant decrease (warning) - **Grey →** = Not
statistically significant (no real change) - No arrow = Significance not
tested (e.g. insufficient sample)

### Chart View

Click the **Charts** button to switch to line chart view: - One line
chart per metric - X-axis = waves (Jan, Apr, Jul, Oct) - Y-axis = metric
values - Multiple coloured lines when viewing "All Segments" (one line
per region) - Data point values labelled on each point - Legend on the
right side

Each chart has an **Export PNG** button to download it as a
high-resolution image.

### Keyboard and Mouse Interactions

-   **Click a sidebar metric**: Scrolls to and briefly highlights that
    metric row in yellow
-   **Type in search**: Filters the sidebar list instantly
-   **Hover a table row**: Subtle highlight effect
-   **Click segment tabs**: Instantly shows/hides columns for that
    segment
-   **Print** (Ctrl+P / Cmd+P): The report has print-optimised CSS —
    sidebar and controls are hidden, all visible data prints cleanly

------------------------------------------------------------------------

## Configuration Reference {#configuration-reference}

### How to set up your own project

1.  **Create wave data files**: One CSV per wave, columns consistent
    across waves
2.  **Create question_mapping.xlsx**: One row per question, map codes to
    column names
3.  **Create tracking_config.xlsx**: Fill in all 4 sheets (Waves,
    Settings, Banner, TrackedQuestions)
4.  **Run**: Source `run_tracker.R`, call `run_tracker()` with your
    paths

### Settings quick reference

| Setting | Type | Default | Notes |
|--------------------|-----------------|--------------------|-----------------|
| project_name | text | "Tracking Report" | Appears in report title |
| baseline_wave | text | first wave | WaveID to use as baseline (e.g. "W1") |
| confidence_level | number | 0.95 | 0.90, 0.95, or 0.99 |
| report_types | text | "detailed" | Use "tracking_crosstab" for the new crosstab report |
| html_report | Y/N | N | Set to Y to generate the HTML version |
| brand_colour | hex | #323367 | Primary colour for HTML report |
| accent_colour | hex | #CC9900 | Secondary colour |
| show_significance | Y/N | Y | Enable significance testing |
| decimal_places_ratings | number | 1 | Decimal places for means |
| company_name | text |  | Shown in report footer |
| default_rating_specs | text | mean | Fallback specs if TrackingSpecs is blank |
| default_nps_specs | text | nps_score | Fallback specs for NPS questions |

### Multiple report types

You can generate several reports at once by comma-separating
report_types:

```         
report_types = detailed,tracking_crosstab
```

Available types: `detailed`, `wave_history`, `dashboard`, `sig_matrix`,
`tracking_crosstab`

------------------------------------------------------------------------

## Troubleshooting {#troubleshooting}

### "Error: Column not found in wave data"

The column name in your question mapping doesn't match the actual column
name in the CSV. Check for typos, spaces, and case sensitivity. Open the
CSV and verify the exact header names.

### "Error: No trend results for Q_XXX"

The question is listed in TrackedQuestions but either: (a) not in the
QuestionMap, or (b) the data columns contain all NAs. Check that the
QuestionCode matches exactly between TrackedQuestions and QuestionMap.

### HTML report generated but no JavaScript features work

The report must be opened from a local file (double-click the .html
file) or served via a web server. Some browsers restrict JavaScript on
`file://` URLs — try Chrome or Firefox, which handle this well.

### Change rows show no significance arrows

Significance testing requires a minimum sample size (default: 30 per
wave per segment). If a segment has fewer than 30 respondents in a wave,
significance is not calculated. Increase your sample size or adjust
`minimum_base` in settings.

### "Banner segments: 1" when I expected more

You ran with `use_banners = FALSE` (the default). Add
`use_banners = TRUE` to the `run_tracker()` call.

### The HTML report doesn't open in my browser

Check that the file was generated (look for the .html file in the output
directory). If the file is very large (\>10MB), it may take a moment to
load. The file should work in any modern browser (Chrome, Firefox,
Safari, Edge).

------------------------------------------------------------------------

## Quick Start Checklist

-   [ ] Wave CSV files created (one per wave, consistent columns)
-   [ ] `question_mapping.xlsx` created with QuestionMap sheet
-   [ ] `tracking_config.xlsx` created with Waves, Settings, Banner,
    TrackedQuestions sheets
-   [ ] Settings include: `report_types = tracking_crosstab` and
    `html_report = Y`
-   [ ] Run from Turas root: `source("modules/tracker/run_tracker.R")`
-   [ ] Call:
    `run_tracker(config, mapping, data_dir, use_banners = TRUE)`
-   [ ] Open the generated .html file in your browser
-   [ ] Toggle "Show vs Previous" and "Show vs Baseline" to see change
    analysis
-   [ ] Switch between segment tabs to compare groups
-   [ ] Use Export CSV/Excel to download the data
