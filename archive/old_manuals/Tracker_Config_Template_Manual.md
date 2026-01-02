# Tracker Config Template - User Manual

**Template File:** `templates/Tracker_Config_Template.xlsx`
**Version:** 10.1
**Last Updated:** 11 December 2025

---

## Overview

The Tracker Config Template configures tracking analysis in TURAS. This module analyzes trends across multiple survey waves, calculating wave-over-wave changes and statistical significance.

**Key Purpose:** Track metrics over time to identify trends, changes, and patterns across survey waves.

**Important:** This template works together with Tracker_Question_Mapping_Template which maps questions across waves.

---

## Template Structure

The template contains **5 sheets**:

1. **Instructions** - Overview and usage guidance
2. **Waves** - Define each survey wave
3. **Settings** - Analysis configuration parameters
4. **TrackedQuestions** - Questions to track over time
5. **Banner** - Optional segment breakouts

---

## Sheet 1: Instructions

**Purpose:** Overview of template usage.

**Action Required:** Review for understanding. Not read by analysis code.

**Key Points:**
- Configure waves in Waves sheet
- Configure settings in Settings sheet
- Define tracked questions in TrackedQuestions sheet
- All file paths can be relative to config file location

---

## Sheet 2: Waves

**Purpose:** Define each survey wave with data file and fielding dates.

**Required Columns:** `WaveID`, `WaveName`, `DataFile`, `FieldworkStart`, `FieldworkEnd`

**Optional Columns:** `WeightVariable`

### Field Specifications

#### Column: WaveID

- **Purpose:** Code that links wave in config files
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Unique identifier per wave
- **Logic:**
  - Must be unique across all waves
  - Used in Question Mapping template
  - Can set it to whatever you want
- **Example:** `W1`, `W2`, `Q1_2024`, `Q2_2024`

#### Column: WaveName

- **Purpose:** Display label for wave
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Any descriptive text
- **Logic:** Appears in output tables and charts
- **Example:** `Q1 2024`, `Wave 1 (Jan 2024)`

#### Column: DataFile

- **Purpose:** Path to wave data file
- **Required:** YES
- **Data Type:** Text (file path)
- **Valid Values:** Path to .csv, .xlsx, or .sav file
- **Logic:** Include filename and path relative to config file
- **Example:** `/Users/duncan/.../Projects/Wave 1/data.xlsx` or `../data/wave1.xlsx`

#### Column: FieldworkStart

- **Purpose:** Fieldwork start date
- **Required:** YES
- **Data Type:** Numeric (YYYYMMDD format)
- **Valid Values:** 8-digit date
- **Example:** `20230810` (August 10, 2023)

#### Column: FieldworkEnd

- **Purpose:** Fieldwork end date
- **Required:** YES
- **Data Type:** Numeric (YYYYMMDD format)
- **Valid Values:** 8-digit date
- **Example:** `20230828` (August 28, 2023)

#### Column: WeightVariable

- **Purpose:** Weight column name for this wave
- **Required:** NO
- **Data Type:** Text (column name) or blank
- **Valid Values:** Column name from data file
- **Logic:**
  - Only if you want to track weighted data
  - Weight variable can change across waves (different column names OK)
  - Leave blank for unweighted wave
- **Example:** `Weight` or `survey_weight`

---

## Sheet 3: Settings

**Purpose:** Analysis configuration parameters.

**Required Columns:** `SettingName`, `Value`

### Field Specifications

#### Setting: project_name

- **Purpose:** Project name (appears in output)
- **Required:** YES
- **Data Type:** Text
- **Example:** `Brand Tracker 2024`

#### Setting: decimal_places_ratings

- **Purpose:** Decimal places for rating scores
- **Required:** YES
- **Data Type:** Integer (0-3)
- **Valid Values:** 0 to 3
- **Default:** `2`
- **Example:** `2`

#### Setting: decimal_places_nps

- **Purpose:** Decimal places for NPS scores
- **Required:** YES
- **Data Type:** Integer (0-3)
- **Valid Values:** 0 to 3
- **Default:** `2`
- **Example:** `2`

#### Setting: decimal_places_percentages

- **Purpose:** Decimal places for percentages
- **Required:** YES
- **Data Type:** Integer (0-3)
- **Valid Values:** 0 to 3
- **Default:** `0`
- **Example:** `0`

#### Setting: show_significance

- **Purpose:** Show significance testing indicators
- **Required:** YES
- **Data Type:** Text (TRUE/FALSE)
- **Valid Values:** `TRUE` or `FALSE`
- **Default:** `TRUE`
- **Logic:** Shows arrows/indicators for significant changes
- **Example:** `TRUE`

#### Setting: alpha

- **Purpose:** Significance level for testing
- **Required:** YES
- **Data Type:** Decimal
- **Valid Values:** Typically `0.05`
- **Default:** `0.05`
- **Logic:** 0.05 = 95% confidence level
- **Example:** `0.05`

#### Setting: minimum_base

- **Purpose:** Minimum base size for reporting
- **Required:** YES
- **Data Type:** Integer
- **Valid Values:** 1 to 1000
- **Default:** `5`
- **Logic:** Don't report metrics when n < this value
- **Example:** `5`

#### Setting: weight_variable

- **Purpose:** Default weight variable name
- **Required:** NO
- **Data Type:** Text (column name)
- **Valid Values:** Column name
- **Logic:** Can override per wave in Waves sheet
- **Example:** `weight`

#### Setting: decimal_separator

- **Purpose:** Decimal separator for display
- **Required:** YES
- **Data Type:** Text (single character)
- **Valid Values:** `.` or `,`
- **Default:** `,`
- **Logic:**
  - `.` = US/UK format (8.2)
  - `,` = European format (8,2)
- **Example:** `,`

#### Setting: report_types

- **Purpose:** Which reports to generate
- **Required:** YES
- **Data Type:** Text (comma-separated)
- **Valid Values:** `detailed`, `wave_history`, `dashboard`, `sig_matrix`
- **Logic:**
  - `detailed` = Detailed wave-by-wave comparison (one sheet per question)
  - `wave_history` = Historical trends (one row per metric, compact format)
  - `dashboard` = Executive summary with all metrics, trend status, and significance matrices
  - `sig_matrix` = Standalone significance matrices showing all wave-pair comparisons
  - Use comma to select multiple
- **Example:** `detailed,wave_history,dashboard`

---

## Sheet 4: TrackedQuestions

**Purpose:** List questions to track over time.

**Required Columns:** `QuestionCode`

**Optional Columns:** `QuestionText`, `Tracking detail`

### Field Specifications

#### Column: QuestionCode

- **Purpose:** Question codes to track
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Must match codes in Question Mapping template
- **Logic:**
  - Can make new descriptive codes here to avoid confusion
  - Must match up with codes in Question Map
- **Example:** `satisfaction_overall`, `nps`, `brand_awareness`

#### Column: QuestionText

- **Purpose:** Descriptive text
- **Required:** NO
- **Data Type:** Text
- **Logic:** **Not required and purely informational**
- **Example:** `Overall satisfaction rating`

#### Column: Tracking detail

- **Purpose:** Additional notes
- **Required:** NO
- **Data Type:** Text
- **Logic:** **Not required and purely informational**
- **Example:** `Primary KPI`

---

## Sheet 5: Banner

**Purpose:** Define segment breakouts for tracking analysis (optional).

**Required Columns:** `BreakVariable`, `BreakLabel`, and wave columns (W2023, W2024, etc.)

### Field Specifications

#### Column: BreakVariable

- **Purpose:** Variable name for segmentation
- **Required:** YES (if using banner)
- **Data Type:** Text
- **Valid Values:**
  - `Total` for total sample (default)
  - Column name from data for segments
- **Logic:** Used to break out tracking by segments (e.g., by region)
- **Example:** `Total`, `Campus`, `Region`

#### Column: BreakLabel

- **Purpose:** Display label for segment
- **Required:** YES (if using banner)
- **Data Type:** Text
- **Example:** `Total`, `Campus`, `East Region`

#### Wave Columns (W2023, W2024, W2025, etc.)

- **Purpose:** Question ID for this segment in each wave
- **Required:** Only if question ID changes across waves
- **Data Type:** Text (question code)
- **Valid Values:** Question code from Survey_Structure in tabs
- **Logic:**
  - Default is total sample
  - If you want breakout by segment (e.g., region), add variable
  - Module creates separate sheet per segment in report
  - Question may differ in waves - specify correct question ID per wave
  - **Only need to specify if question ID changes across waves**
- **Example:** `Q24`, `Q02`

---

## Complete Configuration Example

### Waves Sheet

```
WaveID  | WaveName      | DataFile                          | FieldworkStart | FieldworkEnd | WeightVariable
W1      | Q1 2024       | /Projects/Wave1/data.xlsx         | 20240115       | 20240131     | Weight
W2      | Q2 2024       | /Projects/Wave2/data.xlsx         | 20240415       | 20240430     | Weight
W3      | Q3 2024       | /Projects/Wave3/data.xlsx         | 20240715       | 20240731     | Weight
```

### Settings Sheet

```
SettingName                  | Value
project_name                 | Brand Tracker 2024
decimal_places_ratings       | 2
decimal_places_nps           | 2
decimal_places_percentages   | 0
show_significance            | TRUE
alpha                        | 0.05
minimum_base                 | 5
decimal_separator            | ,
report_types                 | detailed,wave_history,dashboard
```

### TrackedQuestions Sheet

```
QuestionCode          | QuestionText                  | Tracking detail
satisfaction_overall  | Overall satisfaction          | Primary KPI
nps                   | Net Promoter Score            | Primary KPI
product_quality       | Product quality rating        |
customer_service      | Customer service rating       |
```

### Banner Sheet (Optional)

```
BreakVariable | BreakLabel | W1  | W2  | W3
Total         | Total      |     |     |
Campus        | Campus     | Q24 | Q02 | Q02
```

---

## Common Mistakes

### Mistake 1: Wave Data Files Not Found

**Problem:** Error "Data file not found for wave W1"
**Solution:** Check DataFile paths are correct and files exist

### Mistake 2: Question Not in Question Mapping

**Problem:** Error "Question 'satisfaction' not found in mapping"
**Solution:** All TrackedQuestions codes must exist in Question Mapping template

### Mistake 3: Fieldwork Dates Invalid Format

**Problem:** Error parsing dates
**Solution:** Use YYYYMMDD format (8 digits, no spaces or dashes)

### Mistake 4: Weight Variable Doesn't Exist

**Problem:** Error "Weight variable 'Weight' not found in wave W2"
**Solution:** Check weight column name matches data file for each wave

### Mistake 5: Banner Variable Not in Data

**Problem:** Error when generating banner breakouts
**Solution:** Ensure BreakVariable column exists in all wave data files

---

## Integration with Question Mapping

This config works together with Tracker_Question_Mapping_Template:

**Tracker_Config defines:**
- Which waves to analyze
- Analysis settings (decimals, significance)
- Which questions to track
- Banner segments

**Question_Mapping defines:**
- How question codes map across waves
- Question types and calculation methods
- Response code mappings (if codes change)

**Both files required** - they must reference each other via WaveID.

---

## Output Structure

Analysis produces Excel files based on selected report_types:

### Detailed Report (`detailed`)
- **Summary** - Wave overview with sample sizes
- **Question sheets** - One per tracked question with full trend details
- **Change_Summary** - All changes from baseline (with banners if configured)
- **Metadata** - Analysis settings and data sources

### Wave History Report (`wave_history`)
- **Segment sheets** - One sheet per segment (Total, plus any banner segments)
- Compact format with one row per metric
- Shows values across all waves in columns

### Dashboard Report (`dashboard`) - NEW
Executive summary with visual indicators:
- **Trend_Dashboard** - All metrics in one view with:
  - Latest value, change vs previous wave, change vs baseline
  - Significance indicators (↑ up, ↓ down, → no change)
  - Status indicators (Good/Stable/Watch/Alert)
  - Mini trend values across all waves
- **Significance matrices** - One sheet per question showing all wave-pair comparisons

### Significance Matrix Report (`sig_matrix`) - NEW
Standalone significance analysis:
- **One sheet per tracked question**
- Matrix format showing change from any wave to any other wave
- Color-coded cells: green (significant increase), red (significant decrease), grey (not significant)
- Includes change values with direction indicators

---

**End of Tracker Config Template Manual**
