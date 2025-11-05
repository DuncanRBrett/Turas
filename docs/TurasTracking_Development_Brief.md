# TurasTracking: R Implementation Brief
## Multi-Wave Longitudinal Survey Analysis System

**Version:** 1.0  
**Date:** 2025-11-05  
**Client:** Duncan Brett  
**Developer:** Claude Code  

---

## EXECUTIVE SUMMARY

### Purpose
Build a production-grade R system for tracking survey data across multiple waves (up to 25+ waves). The system must handle:
- Independent samples (different respondents each wave)
- Panel data (same respondents tracked over time)
- Mixed designs (combination of panel + refreshment samples)
- Respondent dropout and replacement

### Key Principles
1. **Configuration-driven**: Zero hard-coding, all logic in Excel config files
2. **Reusable**: Same code works for any tracking study without modification
3. **Module-independent**: Does not modify or depend on existing Turas single-wave code
4. **Bulletproof**: Extensive validation, graceful error handling
5. **Performance**: Efficient processing of 25+ waves via caching
6. **Statistical rigor**: Proper methods for panel vs independent samples

### Success Criteria
- Analyst can set up new tracking project in <30 minutes by filling Excel templates
- System processes 25 waves in <2 minutes (with caching)
- Outputs professional Excel reports with time series, significance tests, and visualizations
- Handles all edge cases (missing waves, new questions, panel attrition, etc.)

---

## SYSTEM ARCHITECTURE

### Directory Structure

```
TurasTracking/                          # The reusable system (Git repo)
├── R/
│   ├── core/
│   │   ├── config_loader.R             # Load YAML/Excel configs
│   │   ├── validation.R                # Pre-flight checks
│   │   ├── wave_data_loader.R          # Load wave data files
│   │   └── question_mapper.R           # Map questions across waves
│   │
│   ├── panel/
│   │   ├── panel_detector.R            # Detect sample design
│   │   ├── panel_builder.R             # Build respondent-level dataset
│   │   ├── attrition_analyzer.R        # Attrition analysis
│   │   └── trajectory_analyzer.R       # Individual trajectories
│   │
│   ├── analysis/
│   │   ├── time_series_builder.R       # Build time series tables
│   │   ├── wave_comparison.R           # Wave-over-wave changes
│   │   ├── significance_testing.R      # Statistical tests
│   │   ├── base_size_handler.R         # Base size rules
│   │   ├── indexing.R                  # Indexed performance
│   │   └── derived_metrics.R           # Composite calculations
│   │
│   ├── outputs/
│   │   ├── excel_formatter.R           # Format Excel outputs
│   │   ├── visualization.R             # Generate charts
│   │   └── metadata_generator.R        # Create metadata tabs
│   │
│   ├── utils/
│   │   ├── logger.R                    # Logging utilities
│   │   ├── caching.R                   # Performance caching
│   │   ├── string_matching.R           # Fuzzy matching
│   │   └── helpers.R                   # General utilities
│   │
│   └── main_tracking_analysis.R        # Master orchestrator
│
├── templates/
│   ├── tracking_config_template.xlsx
│   ├── question_mapping_template.xlsx
│   ├── analysis_specs_template.xlsx
│   └── derived_metrics_template.xlsx
│
├── tests/
│   └── test_*.R                        # Unit tests
│
└── documentation/
    ├── USER_GUIDE.md
    └── TECHNICAL_DOCS.md


Projects/                               # User's tracking projects
├── CCS_W23/                            # Individual wave project (UNCHANGED)
│   ├── Survey_Structure.xlsx
│   ├── Crosstab_Config.xlsx
│   ├── data/
│   │   └── CCS_W23_data.xlsx
│   └── output/
│
├── CCS_W24/                            # Another wave (UNCHANGED)
│   └── [same structure]
│
└── CCS_Tracking/                       # NEW tracking project
    ├── tracking_config.xlsx            # Master control file
    ├── question_mapping.xlsx           # Question alignment
    ├── analysis_specs.xlsx             # Analysis definitions
    ├── derived_metrics.xlsx            # Composite metrics
    └── output/
        └── tracking/                   # Tracking outputs
            ├── *.xlsx                  # Excel reports
            ├── charts/                 # PNG/HTML charts
            └── logs/                   # Log files
```

### Data Flow

```
1. User creates tracking project folder
2. User fills tracking_config.xlsx (points to wave folders)
3. User fills question_mapping.xlsx (aligns questions)
4. User fills analysis_specs.xlsx (defines analyses)
5. User runs: run_tracking_analysis("tracking_config.xlsx")

System:
6. Loads configs → Validates setup → Detects sample design
7. Loads wave data from independent wave projects
8. Applies question mapping
9. Builds time series for each analysis
10. Calculates statistics (significance, indexing, etc.)
11. Formats Excel outputs with charts
12. Generates metadata and logs
```

---

## FILE SPECIFICATIONS

### 1. tracking_config.xlsx

**Purpose:** Master control file pointing to all waves and settings

#### Sheet: Project_Info

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| Setting | Text | Yes | Setting name |
| Value | Text | Yes | Setting value |

**Rows:**
```
Setting                     | Value
tracking_project_name       | Campus Climate Survey - Tracking
tracking_project_code       | CCS_Tracking
client_name                 | CCPB
analyst_name                | Duncan Brett
```

#### Sheet: Waves

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| WaveCode | Text | Yes | Short code (W23, Q1_2024, etc.) |
| WaveName | Text | Yes | Display name |
| FieldDate | Date | Yes | YYYY-MM-DD format |
| ProjectPath | Text | Yes | Relative path to wave project folder |
| SampleType | Text | Yes | Panel, Independent, Mixed |
| Status | Text | Yes | Complete, InProgress, Planned, Excluded |
| ExpectedReturns | Numeric | No | Expected panel returns (if panel) |
| ActualReturns | Numeric | No | Actual panel returns |
| RefreshmentSample | Numeric | No | New respondents added |
| WeightVariable | Text | No | Weight column name in data |
| Notes | Text | No | User notes |

**Example:**
```
WaveCode | WaveName | FieldDate  | ProjectPath | SampleType  | Status   | WeightVariable | Notes
W23      | Wave 23  | 2023-10-26 | ../CCS_W23  | Panel       | Complete | Weight_Final   | Baseline
W24      | Wave 24  | 2024-10-26 | ../CCS_W24  | Panel       | Complete | Weight_Final   | Current
W25      | Wave 25  | 2025-01-15 | ../CCS_W25  | Mixed       | Complete | Weight_Final   | Added refresh
```

#### Sheet: Sample_Design

| Setting | Value | Options | Description |
|---------|-------|---------|-------------|
| sample_design | Mixed | Panel, Independent, Mixed | Overall study design |
| respondent_id_column | RespondentID | Text | Column name for unique ID |
| panel_identifier_logic | Appears_Multiple | Text | How to identify panel |
| minimum_waves_for_panel | 2 | Number | Min waves to qualify |
| handle_dropouts | Include | Include, Exclude, Separate | Dropout handling |
| handle_replacements | Track | Track, Ignore | Replacement handling |

#### Sheet: Base_Rules

| Setting | Value | Description |
|---------|-------|-------------|
| minimum_display | 10 | Suppress if n < this |
| warning_threshold | 30 | Flag with ⚠ if n < this |
| sig_test_minimum | 20 | Don't test if either base < this |
| show_unweighted_n | Y | Show base sizes |
| suppress_text | SUPPRESSED | Text for suppressed cells |
| warning_symbol | ⚠ | Symbol for small base |

#### Sheet: Statistical_Settings

| Setting | Value | Options | Description |
|---------|-------|---------|-------------|
| confidence_level | 0.95 | Numeric | 95% confidence |
| sig_test_method | z_test | z_test, t_test, chi_square | Default test |
| panel_test_method | PairedT | PairedT, Wilcoxon, McNemar | Panel-specific tests |
| independent_test_method | UnpairedT | UnpairedT, MannWhitney | Independent tests |
| show_significance | Y | Y/N | Show sig testing |
| significance_display | Both | Flags, PValues, Both | Display format |
| show_sig_flags | Y | Y/N | Show *, **, *** |
| show_p_values | Y | Y/N | Show p-values |
| p_value_decimals | 3 | Number | Decimal places |
| flag_p05 | * | Text | p<0.05 symbol |
| flag_p01 | ** | Text | p<0.01 symbol |
| flag_p001 | *** | Text | p<0.001 symbol |
| two_tailed_test | Y | Y/N | Two vs one-tailed |
| adjustment_for_attrition | IPW | None, IPW, Heckman | Attrition weighting |

#### Sheet: Output_Settings

| Setting | Value | Description |
|---------|-------|-------------|
| output_folder | output/tracking | Relative path |
| excel_engine | openxlsx | R package: openxlsx or writexl |
| decimal_places_percent | 0 | Percentage decimals |
| decimal_places_mean | 1 | Mean decimals |
| decimal_places_index | 0 | Index decimals |
| show_trend_arrows | Y | Show ↑↓→ |
| include_metadata_tab | Y | Add metadata tab |
| log_level | ERROR | ERROR, WARN, INFO |

#### Sheet: Performance_Settings

| Setting | Value | Description |
|---------|-------|-------------|
| enable_caching | Y | Cache processed data |
| cache_location | cache/ | Cache folder |
| reprocess_threshold | 30 | Days before re-cache |
| process_mode | Incremental | Incremental, Full, Smart |
| parallel_processing | N | Parallel processing |
| max_cores | 4 | CPU cores |
| show_progress | Y | Progress indicators |
| log_performance | Y | Track timing |

---

### 2. question_mapping.xlsx

**Purpose:** Map questions across waves, handle question evolution

#### Sheet: Question_Mapping (PRIMARY - User fills)

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| TrackingCode | Text | Yes | Unique ID (TRK_NPS, TRK_SAT_01, etc.) |
| TrackingLabel | Text | Yes | Descriptive label |
| QuestionType | Text | Yes | Likert, Rating, SingleChoice, MultiChoice, Numeric, OpenEnd, Binary |
| Category | Text | No | Grouping (Satisfaction, Demographics, etc.) |
| W23, W24, W25... | Text | No | QuestionCode in that wave (or NA) |
| Notes | Text | No | User notes |

**Example:**
```
TrackingCode | TrackingLabel                    | QuestionType    | Category      | W23  | W24  | W25  | Notes
TRK_NPS      | Net Promoter Score               | Rating          | Satisfaction  | Q51  | Q51  | Q51  | Core KPI
TRK_MERCH_01 | Merchandiser greets on arrival   | Likert          | Merchandiser  | Q07  | Q07  | Q07  | 
TRK_GROUP    | Store group                      | SingleChoice    | Demographics  | Q03  | Q03  | Q03  | Banner
TRK_NEW_01   | New app satisfaction             | Rating          | Digital       | NA   | NA   | Q70  | Added W25
```

#### Sheet: Option_Mapping (Track response option changes)

| Column | Type | Description |
|--------|------|-------------|
| TrackingCode | Text | Which question |
| OptionCode | Text | Internal code |
| OptionLabel | Text | Display label |
| W23, W24, W25... | Text | Y/N if exists |
| FirstWave | Text | When appeared |
| LastWave | Text | When disappeared (or "current") |
| Notes | Text | User notes |

**Example:**
```
TrackingCode | OptionCode | OptionLabel  | W23 | W24 | W25 | FirstWave | LastWave | Notes
TRK_GROUP    | Liquor     | Liquor       | Y   | Y   | Y   | W23       | current  |
TRK_GROUP    | Online     | Online       | N   | N   | Y   | W25       | current  | NEW
TRK_GROUP    | Wholesale  | Wholesale    | Y   | Y   | N   | W23       | W24      | Discontinued
```

#### Sheet: Question_Groups (For batch processing)

| Column | Type | Description |
|--------|------|-------------|
| GroupID | Text | Unique group ID |
| GroupName | Text | Display name |
| Category | Text | Grouping |
| TrackingCodes | Text | Comma-separated list |

**Example:**
```
GroupID  | GroupName                | Category      | TrackingCodes
GRP_001  | Merchandiser Performance | Merchandiser  | TRK_MERCH_01,TRK_MERCH_02,TRK_MERCH_03
GRP_002  | Satisfaction Battery     | Satisfaction  | TRK_SAT_01,TRK_SAT_02,TRK_SAT_03,TRK_SAT_04
```

---

### 3. analysis_specs.xlsx

**Purpose:** Define what analyses to run

#### Sheet: Analyses

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| AnalysisID | Text | Yes | Unique ID (AN_001, etc.) |
| AnalysisName | Text | Yes | Display name |
| AnalysisType | Text | Yes | TimeSeries, WaveChange, PanelChange, AttritionAnalysis |
| TrackingCodes | Text | Yes | Comma-separated or GROUP:GRP_001 |
| BannerCode | Text | No | TrackingCode to segment by |
| FilterID | Text | No | Filter to apply (from Filters sheet) |
| SampleScope | Text | No | All, PanelOnly, IndependentOnly, ConsistentPanel |
| WavesInclude | Text | Yes | ALL or comma-separated (W23,W24,W25) |
| Active | Text | Yes | Y/N |
| Priority | Numeric | No | Run order |
| OutputFile | Text | Yes | Filename (no .xlsx) |

**Example:**
```
AnalysisID | AnalysisName              | AnalysisType | TrackingCodes  | BannerCode | FilterID | SampleScope | WavesInclude | Active | OutputFile
AN_001     | NPS Overall               | TimeSeries   | TRK_NPS        |            |          | All         | ALL          | Y      | NPS_Tracking
AN_002     | NPS by Store Group        | TimeSeries   | TRK_NPS        | TRK_GROUP  |          | All         | ALL          | Y      | NPS_ByGroup
AN_050     | NPS Panel Only            | TimeSeries   | TRK_NPS        |            |          | PanelOnly   | ALL          | Y      | NPS_Panel
AN_051     | Individual NPS Change     | PanelChange  | TRK_NPS        |            |          | PanelOnly   | ALL          | Y      | NPS_Change
AN_052     | Attrition Analysis        | AttritionAnalysis | -         |            |          | PanelOnly   | ALL          | Y      | Attrition
```

#### Sheet: Analysis_Options

| Column | Type | Description |
|--------|------|-------------|
| AnalysisID | Text | Links to Analyses |
| MinBase | Numeric | Override base rules |
| ShowWaveChange | Text | Y/N |
| ShowIndex | Text | Y/N (baseline=100) |
| ShowSigTest | Text | Y/N |
| ShowPValues | Text | Y/N |
| ComparisonType | Text | consecutive, baseline, custom |
| BaselineWave | Text | If baseline comparison |
| WeightingOption | Text | Weighted_Only, Unweighted_Only, Both |

#### Sheet: Filters

| Column | Type | Description |
|--------|------|-------------|
| FilterID | Text | Unique ID |
| FilterName | Text | Display name |
| TrackingCode | Text | Variable to filter on |
| Operator | Text | ==, !=, IN, NOT IN, >, >=, <, <= |
| Value | Text | Value(s) to compare |
| Logic | Text | AND, OR |
| Notes | Text | User notes |

**Example:**
```
FilterID | FilterName           | TrackingCode | Operator | Value       | Logic | Notes
FLT_001  | Metro Region Only    | TRK_REGION   | ==       | Metro       | AND   |
FLT_002  | Large Stores Only    | TRK_SIZE     | >=       | 1000        | AND   |
FLT_003  | Liquor Stores Only   | TRK_GROUP    | ==       | Liquor      | AND   |
```

---

### 4. derived_metrics.xlsx

**Purpose:** Define composite/calculated metrics

#### Sheet: Derived_Metrics

| Column | Type | Description |
|--------|------|-------------|
| DerivedCode | Text | Unique code (DRV_SAT_INDEX) |
| DerivedLabel | Text | Display label |
| CalculationType | Text | Mean, WeightedMean, Sum, Percentage, Binary |
| SourceCodes | Text | Comma-separated TrackingCodes |
| Formula | Text | Calculation formula |
| MinimumValid | Numeric | Min non-NA values required |
| Notes | Text | User notes |

**Example:**
```
DerivedCode    | DerivedLabel              | CalculationType | SourceCodes                              | Formula | MinimumValid
DRV_SAT_INDEX  | Overall Satisfaction Index| Mean            | TRK_SAT_01,TRK_SAT_02,TRK_SAT_03,TRK_SAT_04 | MEAN    | 3
DRV_TOP2_SAT   | Satisfaction Top 2 Box    | Percentage      | TRK_SAT_01                               | PROP(>=4)| 1
```

---

## WAVE PROJECT STRUCTURE

Each wave project follows existing Turas structure (UNCHANGED):

```
CCS_W23/
├── Survey_Structure.xlsx       # Questions definition
│   ├── Sheet: Project          # Project metadata
│   ├── Sheet: Questions        # Question list with QuestionCode, QuestionText, Variable_Type
│   └── Sheet: Options          # Response options
├── Crosstab_Config.xlsx        # Optional - single-wave config
├── data/
│   └── CCS_W23_data.xlsx       # Survey data
└── output/
    └── W23_tables.xlsx         # Single-wave outputs (optional)
```

**Survey_Structure.xlsx → Questions sheet must have:**
- `QuestionCode`: Unique code (Q51, Q07, etc.)
- `QuestionText`: Full question text
- `Variable_Type`: Likert, Rating, Single_Response, Multi_Mention, Numeric, Open_End

**Data file must have:**
- Column names matching QuestionCode values
- One row per respondent
- For panel data: Include `RespondentID` column (consistent across waves)

---

## PANEL DATA REQUIREMENTS

### For Panel/Mixed Studies

**Data files must include:**

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| RespondentID | Text/Numeric | Yes | Unique across ALL waves |
| WaveCode | Text | Optional | Wave identifier (if stacked) |
| PanelStatus | Text | Optional | Original, Return, Refreshment, Replacement |

**PanelStatus values:**
- `Original`: In baseline wave
- `Return`: Returning panel member
- `Refreshment`: New respondent added to boost sample
- `Replacement`: Recruited to replace dropout
- `Independent`: From independent sample

### Example Data Structure

```
RespondentID | WaveCode | PanelStatus  | Q51_NPS | Q03_Region
R0001        | W23      | Original     | 8       | Metro
R0001        | W24      | Return       | 9       | Metro
R0001        | W25      | Return       | 10      | Metro
R0002        | W23      | Original     | 6       | Rural
R0002        | W24      | Return       | 7       | Rural
[R0002 drops out - no W25]
R0500        | W25      | Refreshment  | 8       | Metro
```

---

## TECHNICAL REQUIREMENTS

### R Packages

**Required:**
```r
# Core
library(readxl)      # Read Excel files
library(openxlsx)    # Write Excel files (or writexl as alternative)
library(dplyr)       # Data manipulation
library(tidyr)       # Data reshaping

# Statistics
library(broom)       # Tidy statistical output

# Optional (Phase 2+)
library(ggplot2)     # Visualizations
library(stringdist)  # Fuzzy matching
library(progress)    # Progress bars
```

### Performance Requirements

- Process 25 waves with 50 questions in <2 minutes (with caching)
- First run (no cache): <5 minutes
- Incremental run (1 new wave): <30 seconds
- Memory efficient: Handle datasets up to 10,000 respondents × 25 waves

### Error Handling

- Validation MUST run before analysis
- Errors: Stop execution, clear message
- Warnings: Continue execution, log warning
- Info: Log only, continue
- All errors/warnings written to log file

---

## IMPLEMENTATION PHASES

### PHASE 1: Core Infrastructure (PRIORITY 1)

**Deliverable:** Basic time series tracking for independent samples

**Components:**

1. **Configuration System** (`R/core/config_loader.R`)
   - Load tracking_config.xlsx (all sheets)
   - Load question_mapping.xlsx (Question_Mapping sheet)
   - Load analysis_specs.xlsx (Analyses, Analysis_Options)
   - Return structured list

2. **Validation** (`R/core/validation.R`)
   - Check all files exist
   - Verify wave folders and data files exist
   - Validate question codes in mapping exist in Survey_Structure
   - Check for duplicate TrackingCodes
   - Return validation report (errors, warnings, info)

3. **Wave Data Loader** (`R/core/wave_data_loader.R`)
   - Load Survey_Structure.xlsx for each wave
   - Load data file for each wave
   - Standardize column names
   - Return list of wave datasets

4. **Question Mapper** (`R/core/question_mapper.R`)
   - Read Question_Mapping sheet
   - Create lookup: TrackingCode → WaveCode → QuestionCode
   - Handle NA values (question not in wave)
   - Return mapping dataframe

5. **Time Series Builder** (`R/analysis/time_series_builder.R`)
   - For given TrackingCode, extract data from all waves
   - Calculate frequencies/percentages/means by question type
   - Handle Likert, Rating, SingleChoice, MultiChoice, Numeric
   - Return dataframe with waves as columns

6. **Wave Comparison** (`R/analysis/wave_comparison.R`)
   - Calculate wave-over-wave changes (absolute, percentage)
   - Support consecutive comparison (W1→W2, W2→W3)
   - Return comparison dataframe

7. **Significance Testing** (`R/analysis/significance_testing.R`)
   - Two-proportion z-test for categorical
   - Two-sample t-test for means
   - Only test if both bases ≥ threshold
   - Return p-values and flags (*, **, ***)

8. **Base Size Handler** (`R/analysis/base_size_handler.R`)
   - Suppress if n < minimum_display
   - Flag warning if n < warning_threshold
   - Skip sig test if n < sig_test_minimum
   - Return flags dataframe

9. **Excel Output** (`R/outputs/excel_formatter.R`)
   - Create Excel workbook
   - Write time series table
   - Add wave-over-wave columns
   - Apply formatting (bold headers, number formats, column widths)
   - Add significance flags and base warnings
   - Create metadata tab
   - Return file path

10. **Master Orchestrator** (`R/main_tracking_analysis.R`)
    - Main function: `run_tracking_analysis(config_path)`
    - Load config → Validate → Load data → Map questions
    - For each analysis: Build time series → Calculate comparisons → Test significance → Apply base rules → Format output
    - Return results list

**Success Criteria:**
- Can produce basic time series table with significance testing
- Handles independent samples only
- Basic Excel output with metadata
- No caching or advanced features yet

---

### PHASE 2: Panel Data Support (PRIORITY 2)

**Deliverable:** Full panel tracking with individual change analysis

**Components:**

1. **Panel Detector** (`R/panel/panel_detector.R`)
   - Detect if data has RespondentID column
   - Identify sample design (Panel, Independent, Mixed)
   - Return design type

2. **Panel Builder** (`R/panel/panel_builder.R`)
   - Stack all waves into single dataset
   - Identify panel members (appears in multiple waves)
   - Flag PanelStatus if not provided
   - Return panel dataset

3. **Panel-Specific Tests** (`R/analysis/significance_testing.R` - enhance)
   - Paired t-test for panel means
   - McNemar's test for panel proportions
   - Wilcoxon signed-rank test
   - Select test based on SampleScope

4. **Attrition Analysis** (`R/panel/attrition_analyzer.R`)
   - Calculate retention rates by wave
   - Identify dropout characteristics
   - Calculate attrition weights (IPW)
   - Return attrition report

5. **Change Matrix** (new function in time_series_builder)
   - For panel data, create movement matrix
   - Who moved from Promoter→Detractor, etc.
   - Return change matrix

6. **Trajectory Analysis** (`R/panel/trajectory_analyzer.R`)
   - Cluster respondents by trajectory patterns
   - Identify improvers, decliners, stable, volatile
   - Return trajectory clusters

**Success Criteria:**
- Handles panel data correctly
- Paired tests working
- Attrition analysis output
- Individual change matrices

---

### PHASE 3: Advanced Features (PRIORITY 3)

**Deliverable:** Filters, derived metrics, visualizations, caching

**Components:**

1. **Filters** (enhance time_series_builder.R)
   - Apply filters from Filters sheet
   - Support operators: ==, !=, IN, >, >=, <, <=
   - Combine filters with AND/OR
   - Report filtered vs total base

2. **Derived Metrics** (`R/analysis/derived_metrics.R`)
   - Calculate composites (Mean, Sum, Weighted)
   - Support formulas: MEAN, PROP, IF statements
   - Treat derived metrics like regular TrackingCodes
   - Return calculated values

3. **Caching** (`R/utils/caching.R`)
   - Cache processed wave data
   - Check modification dates
   - Load from cache if unchanged
   - Incremental processing for new waves

4. **Visualization** (`R/outputs/visualization.R`)
   - Generate line charts (ggplot2)
   - Create heat maps for banners
   - Export PNG/HTML
   - Embed sparklines in Excel

5. **Progress Indicators** (`R/utils/logger.R` - enhance)
   - Progress bars during processing
   - Time estimates
   - Status messages

**Success Criteria:**
- Filters working correctly
- Derived metrics calculated
- Caching speeds up re-runs
- Charts generated

---

## FUNCTION SPECIFICATIONS

### Core Functions

#### run_tracking_analysis()

**Purpose:** Main entry point for analysis

```r
#' Run complete tracking analysis
#'
#' @param config_path Character. Path to tracking_config.xlsx
#' @param validate_only Logical. If TRUE, only run validation
#' @param analyses Character vector. Specific AnalysisIDs to run (NULL = all)
#' @param waves Character vector. Specific waves to include (NULL = all)
#' @return List containing results and file paths
#' @export
#'
#' @examples
#' run_tracking_analysis("Projects/CCS_Tracking/tracking_config.xlsx")
#' run_tracking_analysis("config.xlsx", analyses = c("AN_001", "AN_002"))
#' run_tracking_analysis("config.xlsx", validate_only = TRUE)
run_tracking_analysis <- function(
  config_path,
  validate_only = FALSE,
  analyses = NULL,
  waves = NULL
) {
  # 1. Load configuration
  # 2. Validate setup
  # 3. If validate_only, return validation report
  # 4. Detect sample design (panel/independent)
  # 5. Load wave data
  # 6. Apply question mapping
  # 7. For each analysis:
  #    - Apply filters
  #    - Build time series
  #    - Calculate comparisons
  #    - Run significance tests
  #    - Apply base size rules
  #    - Format output
  # 8. Generate summary report
  # 9. Return results
}
```

#### load_config()

```r
#' Load tracking configuration
#'
#' @param config_path Path to tracking_config.xlsx
#' @return List with config elements
load_config <- function(config_path) {
  # Load all sheets from tracking_config.xlsx
  # Load question_mapping.xlsx
  # Load analysis_specs.xlsx
  # Load derived_metrics.xlsx (if exists)
  # Return structured list
}
```

#### validate_tracking_setup()

```r
#' Validate tracking project setup
#'
#' @param config Configuration list from load_config()
#' @return List with errors, warnings, info messages
validate_tracking_setup <- function(config) {
  errors <- c()
  warnings <- c()
  info <- c()
  
  # Check file existence
  # Check data integrity
  # Validate question mapping
  # Check for duplicate TrackingCodes
  # Verify wave data files exist
  # Check base sizes meet minimums
  # Validate analysis specs
  
  return(list(errors = errors, warnings = warnings, info = info))
}
```

#### map_questions_across_waves()

```r
#' Map questions across waves
#'
#' @param mapping_df Dataframe from Question_Mapping sheet
#' @param wave_structures List of Survey_Structure dataframes
#' @return Dataframe: TrackingCode, WaveCode, QuestionCode, Validated
map_questions_across_waves <- function(mapping_df, wave_structures) {
  # For each TrackingCode:
  #   For each wave:
  #     Get QuestionCode (NA if not in wave)
  #     Validate QuestionCode exists in Survey_Structure
  # Return mapping dataframe
}
```

#### build_time_series()

```r
#' Build time series table for tracking question
#'
#' @param tracking_code TrackingCode to analyze
#' @param wave_data List of wave datasets
#' @param question_mapping Mapping dataframe
#' @param banner_code Optional TrackingCode for segmentation
#' @param filter_expr Optional filter expression
#' @param sample_scope "All", "PanelOnly", "IndependentOnly", "ConsistentPanel"
#' @return List with time_series dataframe and metadata
build_time_series <- function(
  tracking_code,
  wave_data,
  question_mapping,
  banner_code = NULL,
  filter_expr = NULL,
  sample_scope = "All"
) {
  # 1. Get QuestionCode for this TrackingCode in each wave
  # 2. Extract data from each wave
  # 3. Apply filter if provided
  # 4. Apply sample_scope filter (panel vs independent)
  # 5. Calculate statistics by QuestionType:
  #    - Likert: frequencies, %, mean, top2, bottom2
  #    - Rating: mean, promoters/passives/detractors (if NPS)
  #    - SingleChoice: frequency, %
  #    - MultiChoice: frequency, % for each option
  #    - Numeric: mean, median, sd
  # 6. If banner_code: repeat for each banner value
  # 7. Combine into single dataframe (waves as columns)
  # 8. Return with metadata
}
```

#### calculate_wave_changes()

```r
#' Calculate wave-over-wave changes
#'
#' @param time_series_df Dataframe from build_time_series()
#' @param comparison_type "consecutive", "baseline", "custom"
#' @param baseline_wave Wave code if comparison_type = "baseline"
#' @return Dataframe with change columns
calculate_wave_changes <- function(
  time_series_df,
  comparison_type = "consecutive",
  baseline_wave = NULL
) {
  # Based on comparison_type:
  #   consecutive: W1→W2, W2→W3, etc.
  #   baseline: All vs baseline_wave
  #   custom: Use custom pairs
  # Calculate absolute and percentage changes
  # Return changes dataframe
}
```

#### test_significance()

```r
#' Perform significance testing
#'
#' @param time_series_df Dataframe with values
#' @param changes_df Dataframe with changes
#' @param question_type Question type
#' @param sample_scope Sample scope (affects test selection)
#' @param panel_data Panel dataset if sample_scope = "PanelOnly"
#' @param config Statistical settings from config
#' @return Dataframe with p-values and flags
test_significance <- function(
  time_series_df,
  changes_df,
  question_type,
  sample_scope,
  panel_data = NULL,
  config
) {
  # Select appropriate test based on:
  #   - question_type (categorical vs numeric)
  #   - sample_scope (panel vs independent)
  
  # If sample_scope = "PanelOnly" AND panel_data provided:
  #   Use paired t-test (numeric)
  #   Use McNemar's test (categorical)
  # Else:
  #   Use unpaired t-test (numeric)
  #   Use two-proportion z-test (categorical)
  
  # Only test if both bases >= sig_test_minimum
  # Calculate p-values
  # Assign flags (*, **, ***) based on thresholds
  # Return results dataframe
}
```

#### apply_base_rules()

```r
#' Apply base size rules
#'
#' @param time_series_df Dataframe with base sizes
#' @param config Base rules from config
#' @return Dataframe with flags
apply_base_rules <- function(time_series_df, config) {
  # For each wave/banner combination:
  #   If n < minimum_display: mark as SUPPRESSED
  #   If n < warning_threshold: add warning flag
  #   If n < sig_test_minimum: skip sig testing
  # Return flags dataframe
}
```

#### format_excel_output()

```r
#' Format and write Excel output
#'
#' @param analysis_results Results from analysis
#' @param output_path Output file path
#' @param config Output settings from config
#' @return File path
format_excel_output <- function(analysis_results, output_path, config) {
  # Create workbook
  # Add time series table
  # Add wave-over-wave changes
  # Add significance flags and p-values
  # Apply formatting:
  #   - Bold headers
  #   - Number formats (%, decimals)
  #   - Column widths
  #   - Trend arrows (if enabled)
  # Add metadata tab
  # Save workbook
  # Return path
}
```

### Panel-Specific Functions

#### detect_sample_design()

```r
#' Detect sample design from data
#'
#' @param wave_data List of wave datasets
#' @param config Sample design settings
#' @return "Panel", "Independent", or "Mixed"
detect_sample_design <- function(wave_data, config) {
  # Check if RespondentID column exists
  # Check if respondents repeat across waves
  # Return design type
}
```

#### build_panel_dataset()

```r
#' Build respondent-level panel dataset
#'
#' @param wave_data List of wave datasets
#' @param config Panel settings
#' @return Stacked dataset with panel flags
build_panel_dataset <- function(wave_data, config) {
  # Stack all waves
  # Identify panel members (appears in multiple waves)
  # Flag PanelStatus if not provided
  # Calculate waves_participated for each respondent
  # Return panel dataset
}
```

#### analyze_attrition()

```r
#' Analyze panel attrition
#'
#' @param panel_data Panel dataset
#' @param config Attrition settings
#' @return List with attrition report components
analyze_attrition <- function(panel_data, config) {
  # Calculate retention rates by wave
  # Identify who dropped out and when
  # Compare dropouts vs retained on baseline characteristics
  # Calculate attrition weights (IPW) if requested
  # Estimate potential bias
  # Return structured report
}
```

---

## OUTPUT SPECIFICATIONS

### Time Series Table Format

**Structure:**
- Rows: Response options + summary metrics
- Columns: Wave codes + change columns
- Base sizes clearly shown
- Significance flags
- Base size warnings

**Example:**

```
═══════════════════════════════════════════════════════════════
Net Promoter Score - Time Series
TrackingCode: TRK_NPS
═══════════════════════════════════════════════════════════════

                        Wave 23      Wave 24      Wave 25      W23→W24         W24→W25
                        Oct 2023     Oct 2024     Jan 2025     Change   Sig p  Change   Sig p
─────────────────────────────────────────────────────────────────────────────────────────────
Base                    60           65           70           
Promoters (9-10)        45%          52%          58%          +7pp     *  .042  +6pp    *  .038
Passives (7-8)          30%          28%          25%          -2pp        .478  -3pp       .321
Detractors (0-6)        25%          20%          17%          -5pp     *  .041  -3pp       .267

NPS Score               +20          +28          +33          +8       *  .023  +5         .152
Mean Rating (0-10)      7.5          7.9          8.1          +0.4     ** .008  +0.2       .089

* p<0.05, ** p<0.01, *** p<0.001
pp = percentage points
Significance: Two-sample t-test for means, two-proportion z-test for percentages
```

### Metadata Tab Format

```
═══════════════════════════════════════════════════════════════
ANALYSIS METADATA
═══════════════════════════════════════════════════════════════

Project Information
───────────────────
Project Name:           Campus Climate Survey - Tracking
Project Code:           CCS_Tracking
Client:                 CCPB
Analyst:                Duncan Brett
Run Date:               2025-11-05 14:30:15
R Version:              4.3.1
TurasTracking Version:  1.0.0

Analysis Details
────────────────
Analysis ID:            AN_001
Analysis Name:          NPS Overall Trend
Analysis Type:          TimeSeries
Sample Scope:           All
Comparison Type:        Consecutive

Waves Included
──────────────
Wave 23 (Oct 2023):     n=60, Status=Complete
Wave 24 (Oct 2024):     n=65, Status=Complete
Wave 25 (Jan 2025):     n=70, Status=Complete

Question Mapping
────────────────
TrackingCode:           TRK_NPS
TrackingLabel:          Net Promoter Score
Question Type:          Rating
Wave 23:                Q51
Wave 24:                Q51
Wave 25:                Q51

Statistical Settings
────────────────────
Confidence Level:       95%
Significance Test:      Two-sample t-test (means), Two-proportion z-test (%)
Minimum Base for Test:  20
Two-tailed Tests:       Yes

Base Size Rules
───────────────
Suppress if n <:        10
Warning if n <:         30
Skip sig test if n <:   20

Files Used
──────────
Config:                 /Projects/CCS_Tracking/tracking_config.xlsx
Question Mapping:       /Projects/CCS_Tracking/question_mapping.xlsx
Analysis Specs:         /Projects/CCS_Tracking/analysis_specs.xlsx
Wave 23 Data:           /Projects/CCS_W23/data/CCS_W23_data.xlsx
Wave 24 Data:           /Projects/CCS_W24/data/CCS_W24_data.xlsx
Wave 25 Data:           /Projects/CCS_W25/data/CCS_W25_data.xlsx

Validation
──────────
Errors:                 0
Warnings:               2
  - W25 base size below warning threshold (n=28 in Superettes banner)
  - TRK_MERCH_02 missing in W26 (question dropped)
```

---

## TESTING REQUIREMENTS

### Unit Tests

Create test files in `tests/` directory:

**test_config_loader.R**
- Test loading valid config
- Test handling missing files
- Test invalid YAML/Excel syntax

**test_question_mapper.R**
- Test exact matches
- Test NA handling (question not in wave)
- Test invalid QuestionCodes

**test_time_series_builder.R**
- Test each QuestionType (Likert, Rating, etc.)
- Test with/without banners
- Test with filters
- Test panel vs independent

**test_significance_testing.R**
- Test two-proportion z-test
- Test t-test
- Test paired t-test
- Test McNemar's test
- Test base size thresholds

**test_base_size_handler.R**
- Test suppression rules
- Test warning flags
- Test sig test skipping

### Integration Tests

**test_end_to_end.R**
- Create sample tracking project
- Run full analysis
- Verify outputs exist
- Check output format

### Test Data

Create minimal test dataset:
- 2-3 waves
- 5-10 questions (variety of types)
- 20-30 respondents
- Mix of panel and independent

---

## ERROR HANDLING & LOGGING

### Validation Errors (Stop Execution)

- Config file not found
- Invalid YAML/Excel syntax
- Required sheets missing
- Wave data file not found
- Invalid TrackingCode (not in Survey_Structure)
- Duplicate TrackingCodes
- Invalid comparison_type

### Warnings (Continue with Log)

- Base size below warning threshold
- Question missing in some waves
- Sample composition changed significantly
- Attrition above threshold
- Demographic inconsistency in panel

### Info Messages (Log Only)

- Cache hit/miss
- Wave loaded successfully
- Analysis started/completed
- Output written

### Log File Format

```
[2025-11-05 14:30:15] INFO: TurasTracking v1.0.0 starting
[2025-11-05 14:30:15] INFO: Loading configuration from: /Projects/CCS_Tracking/tracking_config.xlsx
[2025-11-05 14:30:16] INFO: Configuration loaded successfully
[2025-11-05 14:30:16] INFO: Running validation checks
[2025-11-05 14:30:17] INFO: Validation passed: 0 errors, 2 warnings
[2025-11-05 14:30:17] WARN: Base size below threshold: W25 Superettes (n=28)
[2025-11-05 14:30:17] WARN: Question TRK_MERCH_02 not found in W26
[2025-11-05 14:30:17] INFO: Detected sample design: Panel
[2025-11-05 14:30:18] INFO: Loading wave data (25 waves)
[2025-11-05 14:30:20] INFO: Cache hit: 24 of 25 waves loaded from cache
[2025-11-05 14:30:21] INFO: Wave W25 loaded from disk
[2025-11-05 14:30:22] INFO: Building time series for AN_001: NPS Overall
[2025-11-05 14:30:23] INFO: Calculating wave-over-wave changes
[2025-11-05 14:30:24] INFO: Running significance tests
[2025-11-05 14:30:25] INFO: Formatting Excel output
[2025-11-05 14:30:26] INFO: Output written: /Projects/CCS_Tracking/output/tracking/NPS_Tracking.xlsx
[2025-11-05 14:30:27] INFO: Analysis complete! Total time: 12 seconds
```

---

## DEVELOPMENT PRIORITIES

### Must Have (Phase 1)
1. Configuration loading ✓
2. Validation ✓
3. Wave data loading ✓
4. Question mapping ✓
5. Time series builder (all question types) ✓
6. Wave comparisons ✓
7. Significance testing (basic) ✓
8. Base size handling ✓
9. Excel output ✓
10. Logging ✓

### Should Have (Phase 2)
11. Panel detection ✓
12. Panel dataset building ✓
13. Panel-specific tests (paired t-test, McNemar) ✓
14. Attrition analysis ✓
15. Change matrices ✓
16. Individual trajectories ✓

### Nice to Have (Phase 3)
17. Filters ✓
18. Derived metrics ✓
19. Caching ✓
20. Visualizations ✓
21. Progress bars ✓

---

## CODE STRUCTURE GUIDELINES

### Naming Conventions

**Files:**
- Snake_case: `time_series_builder.R`
- Descriptive: `attrition_analyzer.R`

**Functions:**
- Snake_case: `build_time_series()`
- Verbs: `calculate_wave_changes()`, `test_significance()`

**Variables:**
- Snake_case: `wave_data`, `tracking_code`
- Descriptive: `time_series_df`, `question_mapping`

### Function Structure

```r
#' Brief description
#'
#' Longer description if needed
#'
#' @param param1 Description
#' @param param2 Description
#' @return Description of return value
#' @export
#' @examples
#' example_function(x = 1, y = 2)
example_function <- function(param1, param2) {
  # Input validation
  stopifnot(is.numeric(param1))
  
  # Main logic
  result <- param1 + param2
  
  # Return
  return(result)
}
```

### Error Handling

```r
# Use tryCatch for graceful error handling
result <- tryCatch({
  # Code that might fail
  risky_operation()
}, error = function(e) {
  # Log error
  log_error(paste("Failed:", e$message))
  # Return NULL or default value
  return(NULL)
})

# Check result
if (is.null(result)) {
  # Handle failure
  warning("Operation failed, using default")
  result <- default_value
}
```

### Logging

```r
# Use consistent logging
log_info("Starting process")
log_warn("Unusual value detected")
log_error("Critical failure occurred")

# Include context
log_info(paste("Processing wave:", wave_code))
log_warn(paste("Small base size:", n, "for", tracking_code))
```

---

## DELIVERABLES

### Phase 1 Deliverables

1. **R Package Structure**
   - All functions in `R/` directory
   - Documented with roxygen2
   - Can be installed with `install.packages()`

2. **Templates**
   - tracking_config_template.xlsx
   - question_mapping_template.xlsx
   - analysis_specs_template.xlsx
   - All with example data

3. **Documentation**
   - USER_GUIDE.md (how to use)
   - TECHNICAL_DOCS.md (how it works)
   - Function reference (auto-generated)

4. **Tests**
   - Unit tests for core functions
   - Integration test
   - Test data

5. **Example Project**
   - Complete working example
   - 3 waves of sample data
   - All config files filled in
   - Expected outputs

### Phase 2 Deliverables

6. **Panel Support**
   - Panel detection working
   - Attrition analysis output
   - Change matrices
   - Updated documentation

### Phase 3 Deliverables

7. **Advanced Features**
   - Filters working
   - Derived metrics
   - Caching implemented
   - Charts generated

---

## SUCCESS CRITERIA

### Technical Success

✓ All unit tests pass  
✓ Example project runs without errors  
✓ Processes 25 waves in <2 minutes (with cache)  
✓ Memory efficient (<2GB for 10K respondents × 25 waves)  
✓ Handles all edge cases gracefully  
✓ Clear error messages  

### User Experience Success

✓ New tracking project setup in <30 minutes  
✓ No coding required by analyst  
✓ Clear Excel outputs  
✓ Helpful validation messages  
✓ Good documentation  

### Statistical Success

✓ Correct test selection (paired vs unpaired)  
✓ Accurate p-values  
✓ Proper handling of small bases  
✓ Attrition weights work correctly  
✓ Panel vs independent comparison valid  

---

## CONTACT & QUESTIONS

**Client:** Duncan Brett  
**Project:** TurasTracking  
**Priority:** High  
**Timeline:** Phase 1 in 2-3 weeks  

**Key Questions to Resolve During Development:**

1. Exact format of Survey_Structure.xlsx from existing Turas?
2. Any existing R functions from Turas that can be reused?
3. Preference between openxlsx vs writexl for Excel writing?
4. Should caching use RDS files or custom format?
5. Default significance level: always 0.05 or configurable per analysis?

---

## APPENDIX A: Question Type Handling

### Likert Scales (5-point Strongly Disagree to Strongly Agree)

**Calculate:**
- Frequency and % for each response level
- Top 2 Box % (Agree + Strongly Agree)
- Bottom 2 Box % (Disagree + Strongly Disagree)
- Mean score (1-5)

**Significance Tests:**
- Two-proportion z-test for Top 2 Box
- Two-sample t-test for mean
- (Panel: Paired t-test)

### Rating Scales (0-10 NPS, 1-5 stars)

**Calculate:**
- Mean rating
- If NPS (0-10): Promoters (9-10), Passives (7-8), Detractors (0-6)
- NPS Score = % Promoters - % Detractors
- % Top box (if applicable)

**Significance Tests:**
- Two-sample t-test for means
- Two-proportion z-test for top box
- (Panel: Paired t-test)

### Single Choice (Gender, Region, Store Type)

**Calculate:**
- Frequency and % for each option

**Significance Tests:**
- Two-proportion z-test for each category
- Chi-square test for distribution change (optional)

### Multi-Choice (Select all that apply)

**Calculate:**
- Frequency and % selecting each option
- Percentages sum to >100%

**Significance Tests:**
- Two-proportion z-test for EACH option independently

### Numeric (Age, Income, Number of visits)

**Calculate:**
- Mean, median, standard deviation
- Min, max, range

**Significance Tests:**
- Two-sample t-test
- Check normality, use Mann-Whitney if non-normal
- (Panel: Paired t-test)

### Binary (Yes/No, True/False)

**Calculate:**
- % Yes (or % True)

**Significance Tests:**
- Two-proportion z-test
- (Panel: McNemar's test)

---

## APPENDIX B: File Path Examples

### Tracking Project File Paths

```
# Config file (user provides this path)
/Users/duncan/Projects/CCS_Tracking/tracking_config.xlsx

# System resolves relative paths from config location:
# tracking_config.xlsx → Waves sheet → ProjectPath column: "../CCS_W23"
# Resolves to: /Users/duncan/Projects/CCS_W23/

# Then looks for:
/Users/duncan/Projects/CCS_W23/Survey_Structure.xlsx
/Users/duncan/Projects/CCS_W23/data/CCS_W23_data.xlsx

# Output:
/Users/duncan/Projects/CCS_Tracking/output/tracking/NPS_Tracking.xlsx
```

### Relative Path Rules

All paths in config files are relative to the config file location:

```yaml
# In tracking_config.xlsx:
wave_directory: "waves/"              # CCS_Tracking/waves/
output_directory: "output/tracking/"  # CCS_Tracking/output/tracking/
cache_location: "cache/"              # CCS_Tracking/cache/

# In Waves sheet → ProjectPath:
../CCS_W23                            # Go up one level, then to CCS_W23
../../Archive/CCS_W01                 # Two levels up, then Archive/CCS_W01
```

---

## APPENDIX C: Example Usage

### Setup New Tracking Project

```r
# Install TurasTracking
install.packages("TurasTracking")  # Or devtools::install_local()
library(TurasTracking)

# Create project structure from template
create_tracking_project("Projects/NewTracker/")

# This creates:
# Projects/NewTracker/
#   tracking_config_TEMPLATE.xlsx
#   question_mapping_TEMPLATE.xlsx
#   analysis_specs_TEMPLATE.xlsx
#   output/
#   cache/

# User fills in templates, then:

# Validate setup
validation <- validate_tracking_setup("Projects/NewTracker/tracking_config.xlsx")
print(validation)

# If no errors, run analysis
results <- run_tracking_analysis("Projects/NewTracker/tracking_config.xlsx")
```

### Run Specific Analyses

```r
# Run only certain analyses
run_tracking_analysis(
  "tracking_config.xlsx",
  analyses = c("AN_001", "AN_002", "AN_005")
)

# Run only recent waves
run_tracking_analysis(
  "tracking_config.xlsx",
  waves = c("W23", "W24", "W25")
)

# Validation only (no analysis)
run_tracking_analysis(
  "tracking_config.xlsx",
  validate_only = TRUE
)
```

### Add New Wave

```r
# 1. Create wave project as usual (CCS_W26/)
# 2. Add row to tracking_config.xlsx → Waves sheet
# 3. Add W26 column to question_mapping.xlsx
# 4. Re-run analysis

results <- run_tracking_analysis("tracking_config.xlsx")

# System automatically:
# - Detects new wave
# - Processes only W26 (others from cache)
# - Updates all analyses to include W26
# - Outputs now show W23, W24, W25, W26
```

---

## APPENDIX D: Common Patterns

### Pattern 1: Time Series with Banners

```r
# In analysis_specs.xlsx:
AnalysisID   | TrackingCodes | BannerCode
AN_001       | TRK_NPS       |              # Overall
AN_002       | TRK_NPS       | TRK_REGION   # By region
AN_003       | TRK_NPS       | TRK_GROUP    # By store group

# Generates 3 files:
# 1. NPS_Overall.xlsx (one table)
# 2. NPS_ByRegion.xlsx (one table per region + summary)
# 3. NPS_ByGroup.xlsx (one table per group + summary)
```

### Pattern 2: Battery of Questions

```r
# In question_mapping.xlsx → Question_Groups:
GroupID  | GroupName        | TrackingCodes
GRP_001  | Satisfaction     | TRK_SAT_01,TRK_SAT_02,TRK_SAT_03,TRK_SAT_04

# In analysis_specs.xlsx:
TrackingCodes: GROUP:GRP_001

# Generates one table with all 4 satisfaction questions
```

### Pattern 3: Filtered Analysis

```r
# In analysis_specs.xlsx → Filters:
FilterID  | FilterName    | TrackingCode | Operator | Value
FLT_001   | Metro Only    | TRK_REGION   | ==       | Metro

# In Analyses:
FilterID: FLT_001

# Time series shows only Metro region respondents
```

### Pattern 4: Panel-Only Tracking

```r
# In analysis_specs.xlsx:
SampleScope: PanelOnly

# System:
# 1. Identifies panel members (appears in multiple waves)
# 2. Filters to panel only
# 3. Uses paired t-test for significance
# 4. Reports panel-specific statistics
```

### Pattern 5: Composite Metrics

```r
# In derived_metrics.xlsx:
DerivedCode    | CalculationType | SourceCodes
DRV_SAT_INDEX  | Mean            | TRK_SAT_01,TRK_SAT_02,TRK_SAT_03

# In analysis_specs.xlsx:
TrackingCodes: DRV_SAT_INDEX

# System calculates composite automatically
```

---

## FINAL NOTES

### Development Approach

1. **Start with Phase 1** - Get basic independent sample tracking working first
2. **Test thoroughly** - Use example data, verify outputs manually
3. **Add Phase 2** - Panel support is complex, needs careful testing
4. **Phase 3 optional** - Advanced features can come later

### Code Quality

- Write clear, documented code
- Follow R best practices
- Use consistent naming
- Test edge cases
- Handle errors gracefully

### Communication

- Ask questions early if anything unclear
- Show intermediate results for feedback
- Document any deviations from spec
- Keep user informed of progress

---

**END OF DOCUMENT**

Total Pages: 38  
Word Count: ~12,000  
Version: 1.0  
Last Updated: 2025-11-05
