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
