# Turas Tracker - Technical Documentation

**Version:** 2.1 (TrackingSpecs Enhancement Complete)
**Last Updated:** 2025-12-04
**Target Audience:** Developers, Technical Contributors, Module Maintainers
**Status:** Production-Ready

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Current Version Status](#current-version-status)
3. [Architecture](#architecture)
4. [Module Components](#module-components)
5. [Data Flow](#data-flow)
6. [API Reference](#api-reference)
7. [Configuration System](#configuration-system)
8. [Question Types and Metrics](#question-types-and-metrics)
9. [TrackingSpecs System](#trackingspecs-system)
10. [Statistical Algorithms](#statistical-algorithms)
11. [Output Formats](#output-formats)
12. [Known Issues and Limitations](#known-issues-and-limitations)
13. [Testing and Validation](#testing-and-validation)
14. [Extension Points](#extension-points)
15. [Development Guidelines](#development-guidelines)
16. [File Inventory](#file-inventory)

---

## System Overview

### Purpose

Turas Tracker is a comprehensive R-based system for analyzing multi-wave tracking studies. It:
- Compares metrics across survey waves (time series analysis)
- Calculates statistical significance of trends
- Handles question code mapping when questionnaires change
- Supports demographic breakout analysis (banner trends)
- Generates professional Excel reports in multiple formats
- Tracks custom metrics via TrackingSpecs system

### Key Capabilities

**Core Features (Production-Ready):**
- ✅ Multi-wave trend analysis (2+ waves)
- ✅ Multiple question types: Rating, NPS, Single Choice, Multi-Mention, Composite
- ✅ Question mapping across waves (handles code changes)
- ✅ Weighted data support with design effect calculation
- ✅ Banner analysis (demographic segments)
- ✅ Statistical significance testing (Z-tests, T-tests)
- ✅ TrackingSpecs custom metrics (mean, top_box, ranges, etc.)
- ✅ Multiple report formats (Detailed and Wave History)
- ✅ GUI interface (Shiny-based)
- ✅ Comprehensive validation with actionable error messages

**Future Enhancements (Planned):**
- 🔄 Automated chart generation (Phase 4)
- 🔄 HTML/PowerPoint output formats
- 🔄 Seasonality adjustment
- 🔄 Forecasting capabilities
- 🔄 Real-time data integration

### Technology Stack

**Required R Packages:**
```r
- openxlsx  (>= 4.2.5)  # Excel I/O
- readxl    (>= 1.4.0)  # Reading Excel configurations
```

**Optional R Packages:**
```r
- haven     (>= 2.5.0)  # SPSS .sav support
- foreign   (>= 0.8-0)  # Stata .dta support
- shiny     (>= 1.7.0)  # GUI interface
- shinyFiles (>= 0.9.0) # File selection in GUI
```

---

## Current Version Status

### Version 2.1 Features

**Implemented in v2.1:**
1. **TrackingSpecs Custom Metrics** (Complete)
   - Enhanced rating metrics: mean, top_box, top2_box, top3_box, bottom_box, custom ranges
   - Multi-mention auto-detection and selective tracking
   - Composite metrics with TrackingSpecs support
   - Flexible metric specification per question

2. **Wave History Report Format** (Complete)
   - Compact executive-friendly layout
   - One row per question/metric
   - One column per wave
   - Multiple report types support

3. **Enhanced Question Types** (Complete)
   - Multi_Mention questions fully supported
   - Composite questions with enhanced metrics
   - Rating questions with multiple tracking specs
   - NPS with detailed component tracking

4. **Improved Validation** (Complete)
   - TrackingSpecs validation
   - Multi-mention column detection
   - Enhanced error messages
   - Pre-flight checks

### Version History

| Version | Date | Key Features |
|---------|------|--------------|
| 1.0 (MVT) | 2025-11-18 | Phase 1-3 complete: Config loading, trend calculation, banner analysis |
| 2.0 | 2025-11-21 | TrackingSpecs system, wave history reports, multi-mention support |
| 2.1 | 2025-12-02 | Bug fixes, enhanced validation, production-ready templates |

---

## Architecture

### Design Philosophy

Turas Tracker follows a **modular pipeline architecture**:

```
Configuration → Wave Loading → Mapping → Validation → Calculation → Output
```

**Key Principles:**
1. **Separation of Concerns** - Each module handles one stage
2. **Fail-Fast Validation** - Detect issues before computation
3. **Flexible Mapping** - Handle evolving questionnaires
4. **Statistical Rigor** - Proper significance testing
5. **Multiple Output Formats** - Serve different audiences

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    TURAS TRACKER v2.1                       │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐ │
│  │   Config     │    │   Question   │    │   Wave       │ │
│  │   Loader     │───▶│   Mapper     │───▶│   Loader     │ │
│  └──────────────┘    └──────────────┘    └──────────────┘ │
│         │                    │                    │         │
│         ▼                    ▼                    ▼         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           Validation Module (Enhanced)               │  │
│  └──────────────────────────────────────────────────────┘  │
│                              │                              │
│                              ▼                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          Trend Calculator (TrackingSpecs)            │  │
│  │  ┌──────────┐  ┌──────────┐  ┌────────────────────┐ │  │
│  │  │ Rating   │  │   NPS    │  │  Multi-Mention     │ │  │
│  │  │ Enhanced │  │ Enhanced │  │   (NEW v2.0)       │ │  │
│  │  └──────────┘  └──────────┘  └────────────────────┘ │  │
│  │  ┌──────────┐  ┌──────────┐  ┌────────────────────┐ │  │
│  │  │ Single   │  │Composite │  │  Banner Trends     │ │  │
│  │  │ Choice   │  │ Enhanced │  │   (Phase 3)        │ │  │
│  │  └──────────┘  └──────────┘  └────────────────────┘ │  │
│  └──────────────────────────────────────────────────────┘  │
│                              │                              │
│                              ▼                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Output Writer (Multiple Formats)             │  │
│  │  - Detailed Report (One sheet per question)          │  │
│  │  - Wave History Report (Compact format)              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Design Patterns

1. **Pipeline Pattern** - Sequential data processing stages
2. **Strategy Pattern** - Different calculators for different question types
3. **Builder Pattern** - Configuration object construction
4. **Adapter Pattern** - Question mapping adapts different wave structures
5. **Factory Pattern** - Trend calculator selection based on question type

---

## Module Components

### Core Modules (11 files - All Critical)

#### 1. `run_tracker.R` (472 lines)
**Purpose:** Main entry point and orchestration

**Key Functions:**
```r
run_tracker(tracking_config_path, question_mapping_path,
            data_dir = NULL, output_path = NULL, use_banners = FALSE)
```

**Responsibilities:**
- Orchestrates entire analysis pipeline
- Error handling and logging
- Progress reporting
- Report type routing (detailed vs wave_history)
- Timing and performance metrics

**Quality:** HIGH - Well-structured with comprehensive error handling

#### 2. `tracker_config_loader.R` (~400 lines)
**Purpose:** Load and parse configuration files

**Key Functions:**
```r
load_tracking_config(config_path)
  # Returns: list(waves, settings, banner, tracked_questions, config_path)

load_question_mapping(mapping_path)
  # Returns: data.frame with QuestionCode, QuestionType, TrackingSpecs, Wave columns

get_setting(config, setting_name, default = NULL)
  # Safe setting retrieval with defaults
```

**Configuration Structure:**
- **Waves sheet:** WaveID, WaveName, DataFile, FieldworkStart, FieldworkEnd, WeightVar
- **TrackedQuestions sheet:** QuestionCode, QuestionText, QuestionType
- **Settings sheet:** project_name, output_file, confidence_level, min_base_size, etc.
- **Banner sheet:** BreakVariable, BreakLabel (for demographic breakouts)

**Quality:** HIGH - Robust with validation

#### 3. `wave_loader.R` (~500 lines)
**Purpose:** Load survey data for each wave

**Key Functions:**
```r
load_all_waves(config, data_dir = NULL, question_mapping = NULL)
  # Returns: list(W1 = data.frame(...), W2 = data.frame(...), ...)

load_wave_data(file_path, wave_id)
  # Supports: CSV, XLSX, XLS, SAV, DTA

clean_wave_data(wave_df, wave_id)
  # Cleans: comma decimals, DK/NS/NA values, data types

apply_wave_weights(wave_df, weight_var, wave_id)
  # Applies weights and calculates design effect (DEFF)
```

**Data Cleaning:**
```r
# Automatic transformations:
"7,5" → 7.5                    # Comma to period
"DK", "Don't Know" → NA        # Non-response codes
"Prefer not to say" → NA       # Remove text responses
```

**Quality:** HIGH - Supports multiple formats with robust cleaning

#### 4. `question_mapper.R` (~350 lines)
**Purpose:** Map question codes across waves

**Key Functions:**
```r
build_question_map_index(question_mapping, config)
  # Builds fast lookup index

get_question_metadata(question_map, question_code)
  # Returns: list(QuestionCode, QuestionText, QuestionType, TrackingSpecs, ...)

get_wave_question_code(question_map, std_code, wave_id)
  # Maps standardized code to wave-specific code

extract_question_data(wave_df, wave_id, question_code, question_map)
  # Extracts question data using mapping
```

**TrackingSpecs Functions (v2.0+):**
```r
get_tracking_specs(question_map, question_code)
  # Retrieves TrackingSpecs string for question

parse_tracking_specs(specs_str, question_type)
  # Parses comma-separated specs into structured list
```

**Quality:** HIGH - Critical for tracking across questionnaire changes

#### 5. `validation_tracker.R` (~600 lines)
**Purpose:** Comprehensive validation framework

**Key Functions:**
```r
validate_tracker_setup(config, question_mapping, question_map, wave_data)
  # Master validation function

validate_tracking_config(config, question_mapping)
  # Validates configuration structure

validate_wave_data(wave_data, config, question_mapping)
  # Validates loaded wave data

validate_question_mapping(config, question_map, wave_data)
  # Validates question availability by wave

validate_tracking_specs(specs_str, question_type)
  # NEW v2.0: Validates TrackingSpecs syntax
```

**Validation Checks:**
| Category | Checks |
|----------|--------|
| Configuration | Required sheets, columns, unique IDs, valid settings |
| Question Mapping | Tracked questions exist, types valid, specs valid |
| Wave Data | Files loadable, adequate sample sizes, columns present |
| Consistency | Sample size stability, naming consistency, type consistency |
| Statistical | Sufficient variance, no constants, adequate responses |

**Quality:** HIGH - Comprehensive with actionable error messages

#### 6. `trend_calculator.R` (~800 lines)
**Purpose:** Calculate trends and statistical significance

**Key Functions:**
```r
calculate_all_trends(config, question_map, wave_data)
  # Routes to appropriate calculators

# Question type-specific calculators:
calculate_rating_trend_enhanced(q_code, question_map, wave_data, config)
calculate_nps_trend(q_code, question_map, wave_data, config)
calculate_single_choice_trend_enhanced(q_code, question_map, wave_data, config)
calculate_multi_mention_trend(q_code, question_map, wave_data, config)
calculate_composite_trend_enhanced(q_code, question_map, wave_data, config)
```

**Enhanced Metric Calculators (v2.0+):**
```r
calculate_top_box(values, weights, n_boxes = 1)
  # % in top N values (auto-detects scale)

calculate_custom_range(values, weights, range_spec)
  # % in custom range (e.g., "range:9-10")

calculate_distribution(values, weights)
  # % for each value in scale

detect_multi_mention_columns(wave_df, base_code)
  # Auto-detects Q30_1, Q30_2, ... pattern

parse_multi_mention_specs(tracking_specs, base_code, wave_df)
  # Parses "auto", "option:Q30_1", "any", "count_mean"
```

**Statistical Testing:**
```r
# Z-test for proportions
test_proportion_trend(p1, n1, p2, n2, alpha)

# T-test for means (Welch's)
test_mean_trend(mean1, sd1, n1, mean2, sd2, n2, alpha)

# Design effect adjustment
n_effective = n_weighted / DEFF
DEFF = 1 + cv² where cv = sd(weights) / mean(weights)
```

**Quality:** HIGH - Complex statistical calculations properly implemented

#### 7. `banner_trends.R` (~400 lines)
**Purpose:** Calculate trends by demographic segments (Phase 3)

**Key Functions:**
```r
calculate_trends_with_banners(config, question_map, wave_data)
  # Calculates trends for all segments

calculate_question_banner_trends(q_code, banner_var, question_map, wave_data, config)
  # Trends for one question across banner breakouts

segment_wave_data(wave_df, banner_var, banner_label)
  # Splits wave data into demographic segments

get_banner_segments(config, wave_data)
  # Extracts banner segment definitions
```

**Quality:** HIGH - Enables demographic breakout analysis

#### 8. `formatting_utils.R` (~200 lines)
**Purpose:** Output formatting utilities

**Key Functions:**
```r
format_decimal(value, decimal_places, separator = ".")
  # Formats numbers with specified decimal separator

format_percentage(value, decimal_places)
  # Formats percentages

format_sample_size(n)
  # Formats sample sizes with thousands separator

get_decimal_separator(config)
  # Retrieves decimal separator from config
```

**Quality:** MEDIUM - Supporting functions

#### 9. `tracker_output.R` (~500 lines)
**Purpose:** Generate Excel reports

**Key Functions:**
```r
write_tracker_output(trend_results, config, wave_data, output_path, banner_segments)
  # Generates detailed trend report

write_wave_history_output(trend_results, config, wave_data, output_path, banner_segments)
  # NEW v2.0: Generates wave history report

format_summary_sheet(wb, trend_results, config)
  # Formats summary overview

format_question_sheet(wb, sheet_name, question_result, config)
  # Formats detailed question sheet

write_banner_trend_table(wb, sheet_name, question_result, segment_name, config)
  # Formats banner breakout tables
```

**Report Types (v2.0+):**
- **Detailed:** One sheet per question, full statistical detail
- **Wave History:** Compact format, one row per metric, executive-friendly

**Quality:** HIGH - Complex Excel generation

#### 10. `run_tracker_gui.R` (689 lines)
**Purpose:** Shiny-based GUI interface

**Key Features:**
- File selection with browse buttons
- Auto-detection of question mapping
- Recent projects functionality
- Banner analysis toggle
- Real-time console output
- Error display with stack traces

**Quality:** HIGH - Professional Shiny application

#### 11. `constants.R` (Small)
**Purpose:** Centralized constants

**Defines:**
- Default settings
- Valid question types
- Valid TrackingSpecs options
- Error messages
- Formatting constants

**Quality:** MEDIUM - Simple but important

---

## Data Flow

### Complete Pipeline

```
1. CONFIGURATION LOADING
   ├─ Load tracking_config.xlsx (Waves, Settings, Banner, TrackedQuestions)
   ├─ Load question_mapping.xlsx (QuestionMap with TrackingSpecs)
   └─ Parse settings to list

2. WAVE DATA LOADING
   ├─ For each wave:
   │  ├─ Load data file (CSV/Excel/SAV/DTA)
   │  ├─ Clean data (comma decimals, DK→NA)
   │  ├─ Apply weights (if specified)
   │  └─ Calculate design effect
   └─ Store in wave_data list

3. QUESTION MAPPING
   ├─ Build question map index
   ├─ Map standard codes to wave-specific codes
   ├─ Parse TrackingSpecs for each question
   └─ Validate all questions available

4. VALIDATION
   ├─ Validate configuration structure
   ├─ Validate wave data quality
   ├─ Validate question mapping
   ├─ Validate TrackingSpecs syntax
   └─ Verify adequate sample sizes

5. TREND CALCULATION
   ├─ For each tracked question:
   │  ├─ Extract question data from each wave
   │  ├─ Apply TrackingSpecs to determine metrics
   │  ├─ Calculate wave metrics (mean, %, NPS, etc.)
   │  ├─ Perform significance testing
   │  └─ Generate trend indicators (↑↓→)
   │
   └─ If banner analysis enabled:
      └─ Repeat for each demographic segment

6. OUTPUT GENERATION
   ├─ Determine report types from config
   ├─ If "detailed":
   │  ├─ Create workbook
   │  ├─ Write summary sheet
   │  ├─ Write question detail sheets
   │  ├─ Write metadata sheet
   │  └─ Apply formatting and conditional styles
   │
   └─ If "wave_history":
      ├─ Create workbook
      ├─ Write one sheet per segment
      ├─ Format as compact table
      └─ Save workbook
```

### Memory Management

```
Configuration (small) ─────────────┐
Question Mapping (small) ──────────┤
                                   │
Wave Data (large) ────────────────┤──> Kept in memory
  List of data frames              │    throughout pipeline
  One per wave                     │
                                   │
Question Map Index (medium) ───────┘

Trend Calculation (wave by wave):
  Extract question data ──────────────> Temporary (discarded)
  Calculate metrics ──────────────────> Accumulated in results

Trend Results (medium) ───────────────> Kept in memory

Excel Workbook (medium) ──────────────> Written to disk
```

**Optimization Strategy:**
- Load all waves once (avoid reloading)
- Process questions sequentially
- Use vectorized operations
- Discard intermediate data
- Write Excel incrementally for large outputs

---

## API Reference

### Main Entry Point

```r
run_tracker(
  tracking_config_path,    # Path to tracking_config.xlsx
  question_mapping_path,   # Path to question_mapping.xlsx (or NA)
  data_dir = NULL,         # Directory for relative data file paths
  output_path = NULL,      # Output file path (auto-generated if NULL)
  use_banners = FALSE      # Enable banner analysis (Phase 3)
)

# Returns:
#   - Character path (single report type)
#   - Named list (multiple report types): list(detailed = "...", wave_history = "...")
```

**Example Usage:**
```r
# Simple trend analysis
result <- run_tracker(
  tracking_config_path = "config/tracking_config.xlsx",
  question_mapping_path = "config/question_mapping.xlsx",
  data_dir = "data/",
  use_banners = FALSE
)

# With banner analysis
result <- run_tracker(
  tracking_config_path = "config/tracking_config.xlsx",
  question_mapping_path = "config/question_mapping.xlsx",
  data_dir = "data/",
  use_banners = TRUE
)

# Multiple report types
result <- run_tracker(
  tracking_config_path = "config/tracking_config.xlsx",
  question_mapping_path = "config/question_mapping.xlsx"
)
# Returns: list(detailed = "path1.xlsx", wave_history = "path2.xlsx")
```

### Configuration Functions

```r
# Load configuration
config <- load_tracking_config("tracking_config.xlsx")

# Load question mapping
mapping <- load_question_mapping("question_mapping.xlsx")

# Build question map
question_map <- build_question_map_index(mapping, config)

# Get setting value safely
confidence <- get_setting(config, "confidence_level", default = 0.95)
```

### Wave Data Functions

```r
# Load all waves
wave_data <- load_all_waves(config, data_dir = "data/")

# Load single wave
wave1 <- load_wave_data("wave1.csv", "W1")

# Clean wave data
wave1_clean <- clean_wave_data(wave1, "W1")

# Apply weights
wave1_weighted <- apply_wave_weights(wave1, "Weight", "W1")
```

### Question Mapping Functions

```r
# Get question metadata
metadata <- get_question_metadata(question_map, "Q01_Awareness")

# Get wave-specific code
wave1_code <- get_wave_question_code(question_map, "Q01_Awareness", "W1")

# Extract question data
q_data <- extract_question_data(wave_data[["W1"]], "W1", "Q01_Awareness", question_map)

# Get TrackingSpecs (v2.0+)
specs <- get_tracking_specs(question_map, "Q01_Awareness")
```

### Trend Calculation Functions

```r
# Calculate all trends
trend_results <- calculate_all_trends(config, question_map, wave_data)

# Calculate specific question type
rating_trend <- calculate_rating_trend_enhanced("Q01", question_map, wave_data, config)

# Calculate with banners
banner_trends <- calculate_trends_with_banners(config, question_map, wave_data)
```

### Output Functions

```r
# Write detailed output
write_tracker_output(trend_results, config, wave_data, "output.xlsx", banner_segments)

# Write wave history output (v2.0+)
write_wave_history_output(trend_results, config, wave_data, "wave_history.xlsx", banner_segments)
```

---

## Configuration System

### tracking_config.xlsx Structure

#### Sheet 1: Waves
```
WaveID | WaveName    | DataFile          | FieldworkStart | FieldworkEnd | WeightVar
W1     | Jan 2024    | wave1.csv         | 2024-01-01     | 2024-01-15   | Weight
W2     | Apr 2024    | wave2.csv         | 2024-04-01     | 2024-04-15   | Weight
W3     | Jul 2024    | wave3.csv         | 2024-07-01     | 2024-07-15   | Weight
```

**Required Columns:** WaveID, WaveName, DataFile
**Optional Columns:** FieldworkStart, FieldworkEnd, WeightVar

#### Sheet 2: TrackedQuestions
```
QuestionCode     | QuestionText                  | QuestionType
Q01_Awareness    | Brand awareness (unaided)     | Single_Response
Q02_Satisfaction | Satisfaction (1-10)           | Rating
Q03_NPS          | Recommend to friend (0-10)    | NPS
Q04_Features     | Features used (select all)    | Multi_Mention
COMP_CX          | Customer Experience Index     | Composite
```

**Required Columns:** QuestionCode, QuestionType
**Optional Columns:** QuestionText

#### Sheet 3: Settings
```
SettingName              | SettingValue
project_name             | Q4 2024 Brand Tracking
report_types             | detailed,wave_history
output_dir               | output/
confidence_level         | 0.95
min_base_size            | 30
decimal_places_ratings   | 1
decimal_places_percents  | 0
decimal_separator        | .
show_significance        | TRUE
```

**Common Settings:**
- `project_name`: Project title
- `report_types`: "detailed", "wave_history", or "detailed,wave_history"
- `output_file`: Output filename (default: auto-generated)
- `confidence_level`: Statistical confidence (default: 0.95)
- `min_base_size`: Minimum n for sig testing (default: 30)
- `decimal_separator`: "." or "," (default: ".")

#### Sheet 4: Banner (Optional - for demographic breakouts)
```
BreakVariable | BreakLabel
Total         | Total
Gender        | Gender
AgeGroup      | Age Group
Region        | Region
```

**Required Columns:** BreakVariable, BreakLabel

### question_mapping.xlsx Structure

#### Sheet: QuestionMap
```
QuestionCode | QuestionType  | TrackingSpecs         | Wave1    | Wave2    | Wave3    | SourceQuestions
Q01          | Rating        | mean,top2_box         | Q10      | Q11      | Q12      |
Q02          | Single        | category:Brand A      | Q20      | Q20A     | Q20B     |
Q03          | Multi_Mention | auto,any,count_mean   | Q30      | Q30      | Q30      |
Q04          | NPS           | nps_score             | Q40      | Q40      | Q40      |
COMP_SAT     | Composite     | mean,top2_box         | NA       | NA       | NA       | Q01,Q02,Q05
```

**Required Columns:** QuestionCode, QuestionType, Wave columns
**Optional Columns:** TrackingSpecs, QuestionText, SourceQuestions

**Wave Columns:** Dynamically determined from config (W1, W2, W3, etc.)

---

## Question Types and Metrics

### Supported Question Types

| QuestionType | Description | Default Metric | TrackingSpecs Support |
|--------------|-------------|----------------|----------------------|
| Rating | Numeric scales (1-5, 1-10, etc.) | Mean | ✅ Full |
| NPS | Net Promoter Score (0-10) | NPS score | ✅ Full |
| Single_Response | Single choice questions | % by option | ✅ Selective |
| Multi_Mention | Select all that apply | % per option | ✅ Full |
| Composite | Derived from other questions | Mean | ✅ Full |

### Question Type Normalization

The system normalizes various question type names to internal types:

```r
Type Mappings:
"Single_Response" → "single_choice"
"SingleChoice" → "single_choice"
"Multi_Mention" → "multi_choice"
"MultiChoice" → "multi_choice"
"Rating" / "Likert" → "rating"
"NPS" → "nps"
"Index" / "Numeric" → "rating"
"Open_End" → "open_end" (not tracked)
"Composite" → "composite"
```

---

## TrackingSpecs System

### Overview

TrackingSpecs (v2.0+) allows flexible metric specification per question. Add a `TrackingSpecs` column to question_mapping.xlsx to specify custom metrics.

### Syntax

**Format:** Comma-separated list of metric specifications

**Example:**
```
TrackingSpecs: mean,top2_box,range:9-10
```

### Available Specifications by Question Type

#### Rating Questions

| Spec | Description | Example Output |
|------|-------------|----------------|
| `mean` | Average rating | Mean: 8.2 |
| `top_box` | % giving highest value | Top Box: 45% |
| `top2_box` | % giving top 2 values | Top 2 Box: 72% |
| `top3_box` | % giving top 3 values | Top 3 Box: 85% |
| `bottom_box` | % giving lowest value | Bottom Box: 5% |
| `bottom2_box` | % giving bottom 2 values | Bottom 2 Box: 8% |
| `range:X-Y` | % in custom range | % 9-10: 52% |
| `distribution` | % for each value | [Full distribution table] |

**Auto-Detection:** Scale auto-detected from data (works with any numeric scale)

**Example:**
```
QuestionCode | QuestionType | TrackingSpecs
Q_SAT        | Rating       | mean,top2_box,range:9-10
```

**Result:**
- Mean satisfaction
- % in top 2 ratings
- % rating 9-10

#### Multi-Mention Questions

Multi_Mention supports TWO tracking modes:

**Mode 1: Binary Column Tracking (0/1 values)**

| Spec | Description | Example Output |
|------|-------------|----------------|
| `auto` | Auto-detect all binary columns | % for each detected option |
| `option:COL` | Track specific column | % mentioning Q30_1 |
| `any` | % mentioning at least one | % Mentioning Any: 92% |
| `count_mean` | Mean number mentioned | Mean # Mentions: 2.3 |
| `count_distribution` | Distribution of counts | [Count distribution table] |

**Column Detection:** Auto-detects columns matching pattern `{BaseCode}_{Number}` (e.g., Q30_1, Q30_2, Q30_3)

**Data Format:** Each column contains 1 (mentioned) or 0 (not mentioned)

**Example:**
```
QuestionCode | QuestionType  | TrackingSpecs
Q30          | Multi_Mention | auto,any,count_mean
```

**Result:**
- % mentioning each option (Q30_1, Q30_2, Q30_3, ...)
- % mentioning at least one option
- Average number of options mentioned

**Mode 2: Category Text Tracking (text values)**

| Spec | Description | Example Output |
|------|-------------|----------------|
| `category:TEXT` | Track specific text value | % mentioning "Personal records" |
| `auto` | Auto-detect all text values | % for each discovered category |

**Column Detection:** Auto-detects columns matching pattern `{BaseCode}_{Number}` (e.g., Q10_1, Q10_2, Q10_3)

**Data Format:** Each column contains TEXT LABELS when selected (not 0/1)

**Text Matching:** Case-insensitive, searches across ALL option columns

**Example:**
```
Data:
RespondentID | Q10_1                                  | Q10_2              | Q10_3
1            | Internal store system (merchandiser)  |                    |
2            |                                        | Personal records   |
3            | Internal store system (merchandiser)  |                    | Other

QuestionCode | QuestionType  | TrackingSpecs
Q10          | Multi_Mention | category:Internal store system (merchandiser),category:Personal records,category:Other
```

**Result:**
- % mentioning "Internal store system (merchandiser)": 66.7%
- % mentioning "Personal records": 33.3%
- % mentioning "Other": 33.3%

**How It Works:**
1. System detects all Q10_* columns (Q10_1, Q10_2, Q10_3, etc.)
2. For each category, searches for that text across ALL columns
3. Respondent counts as "mentioning" if text appears in ANY column
4. Calculates weighted % mentioning each category

#### Composite Questions

Composite questions support same specs as Rating questions after composite score calculation:

| Spec | Description |
|------|-------------|
| `mean` | Mean of composite score |
| `top2_box` | % in top 2 values of composite |
| `range:X-Y` | % of composite scores in range |

**Example:**
```
QuestionCode | QuestionType | SourceQuestions | TrackingSpecs
COMP_CX      | Composite    | Q10,Q11,Q12     | mean,top2_box
```

**Calculation:**
1. Compute composite score per respondent: mean(Q10, Q11, Q12)
2. Apply TrackingSpecs to composite scores

#### NPS Questions

| Spec | Description | Example Output |
|------|-------------|----------------|
| `nps_score` | Net Promoter Score | NPS: 32 |
| `promoters_pct` | % Promoters (9-10) | % Promoters: 45% |
| `passives_pct` | % Passives (7-8) | % Passives: 35% |
| `detractors_pct` | % Detractors (0-6) | % Detractors: 20% |
| `full` | All components | [Complete NPS breakdown] |

**Default:** `full` (shows all components)

### TrackingSpecs Parsing

```r
# Parse TrackingSpecs string
specs_list <- parse_tracking_specs("mean,top2_box,range:9-10", "Rating")

# Returns:
# list(
#   metrics = c("mean", "top2_box"),
#   ranges = list(range1 = c(9, 10))
# )
```

### Default Behaviors (TrackingSpecs blank)

| Question Type | Default Behavior |
|---------------|------------------|
| Rating | mean |
| NPS | full |
| Single_Response | All categories |
| Multi_Mention | auto (all detected options) |
| Composite | mean |

---

## Statistical Algorithms

### Z-Test for Proportions

**Use Case:** Test if proportion changed significantly between waves

**Implementation:**
```r
# Wave 1: p1 = 0.45, n1 = 500
# Wave 2: p2 = 0.50, n2 = 500

# Pooled proportion
p_pool <- (p1*n1 + p2*n2) / (n1 + n2)

# Standard error
se <- sqrt(p_pool * (1 - p_pool) * (1/n1 + 1/n2))

# Z statistic
z <- (p2 - p1) / se

# P-value (two-tailed)
p_value <- 2 * pnorm(-abs(z))

# Significant if p_value < alpha (typically 0.05)
if (p_value < alpha) {
  trend <- if (p2 > p1) "up" else "down"
  symbol <- if (p2 > p1) "↑" else "↓"
} else {
  trend <- "stable"
  symbol <- "→"
}
```

**Assumptions:**
- Independent samples (different respondents each wave)
- Sample sizes adequate (n ≥ 30 per wave recommended)
- Random sampling

### T-Test for Means

**Use Case:** Test if mean rating changed significantly between waves

**Implementation (Welch's t-test):**
```r
# Wave 1: mean1, sd1, n1
# Wave 2: mean2, sd2, n2

# For weighted data, use effective sample sizes
n1_eff <- n1 / deff1
n2_eff <- n2 / deff2

# Standard error (Welch's - doesn't assume equal variances)
se <- sqrt(sd1^2/n1_eff + sd2^2/n2_eff)

# T statistic
t <- (mean2 - mean1) / se

# Degrees of freedom (Welch-Satterthwaite)
df <- (sd1^2/n1_eff + sd2^2/n2_eff)^2 /
      ((sd1^2/n1_eff)^2/(n1_eff-1) + (sd2^2/n2_eff)^2/(n2_eff-1))

# P-value (two-tailed)
p_value <- 2 * pt(-abs(t), df)

# Determine trend
if (p_value < alpha) {
  trend <- if (mean2 > mean1) "up" else "down"
  symbol <- if (mean2 > mean1) "↑" else "↓"
} else {
  trend <- "stable"
  symbol <- "→"
}
```

**Why Welch's t-test:**
- Doesn't assume equal variances between waves
- More robust to unequal sample sizes
- Standard approach for comparing independent samples

### Design Effect (DEFF)

**Purpose:** Adjust for impact of weighting on statistical tests

**Calculation:**
```r
# DEFF based on coefficient of variation of weights
weight_mean <- mean(weights)
weight_sd <- sd(weights)
cv <- weight_sd / weight_mean

deff <- 1 + cv^2

# Effective sample size
n_effective <- n_weighted / deff
```

**Why DEFF Matters:**
```
Unweighted analysis: n = 500
Weighted analysis: sum(weights) = 500, DEFF = 1.5
Effective n = 500 / 1.5 = 333

Use n_effective = 333 for significance testing
(Not n = 500, which would overstate significance)
```

**DEFF Interpretation:**
- DEFF = 1.0: No weighting impact (equal weights)
- DEFF = 1.1-1.3: Moderate impact (10-30% reduction)
- DEFF = 1.5-2.0: High impact (33-50% reduction)
- DEFF > 2.0: Very high impact (>50% reduction) - review weighting

---

## Output Formats

### Detailed Report Format

**Structure:**
- **Summary Sheet:** Overview of all questions with latest results
- **Question Sheets:** One sheet per question with full trend table
- **Metadata Sheet:** Analysis parameters and settings

**Question Sheet Layout:**
```
Q01: Brand Awareness (Single_Response)
TrackingSpecs: category:Brand A

                Wave 1      Wave 2      Trend   Wave 3      Trend
                Q1 2024     Q2 2024             Q3 2024
Base (n=)
  Unweighted    500         500                 500
  Weighted      500         500                 500
  Effective     450         455                 448

Brand A    %    45.2        48.1        ↑       52.3        ↑
Brand B    %    30.4        31.2        →       29.8        →
Brand C    %    18.7        16.3        →       14.2        ↓
None       %    5.7         4.4         →       3.7         →
```

**Trend Symbols:**
- ↑ = Significant increase (p < 0.05)
- ↓ = Significant decrease (p < 0.05)
- → = No significant change

### Wave History Report Format (v2.0+)

**Structure:**
- One sheet per segment (Total, then each banner segment)
- One row per question/metric
- Columns: QuestionCode | Question | Type | Wave1 | Wave2 | ... | WaveN

**Layout:**
```
Sheet: Total

QuestionCode | Question                    | Type      | W1   | W2   | W3
Q38          | Overall satisfaction (1-10) | Mean      | 8.2  | 8.4  | 8.6
Q38          | Overall satisfaction (1-10) | Top 2 Box | 72   | 75   | 78
Q20          | Brand awareness             | % Yes     | 45   | 48   | 52
Q30          | Features - App              | % Mention | 68   | 71   | 74
Q30          | Features - Web              | % Mention | 45   | 48   | 50
```

**Features:**
- Compact, scannable format
- Multiple metrics per question (if TrackingSpecs specified)
- Easy to copy into PowerPoint
- Executive-friendly

**When to Use:**
- ✅ Executive presentations
- ✅ Quick trend scanning
- ✅ Client summaries
- ❌ Detailed statistical analysis (use Detailed format)

### Output File Naming

**Single Report Type:**
```
{output_file_from_settings}
# Default: ProjectName_Tracker_YYYYMMDD.xlsx
```

**Multiple Report Types:**
```
{ProjectName}_Tracker_{YYYYMMDD}.xlsx     # Detailed format
{ProjectName}_WaveHistory_{YYYYMMDD}.xlsx # Wave history format
```

---

## Known Issues and Limitations

### Critical Issues

**None currently identified.**

All previously identified critical issues have been resolved. See [Historical Issues](#historical-issues-resolved) section below.

### Known Limitations

1. **Test Coverage:** ~15% automated (primarily manual testing)
   - Unit tests needed for all calculator functions
   - Integration tests needed for full pipeline
   - **Target:** 80% coverage for v3.0

2. **No Confidence Intervals in Wave History:**
   - CIs calculated but not shown in wave history format
   - Only metric values displayed
   - **Planned:** Optional CI columns for v2.2

3. **Limited Chart Support:**
   - No automated chart generation
   - Users create charts manually in Excel
   - **Planned:** Automated charts in Phase 4 (v3.0)

4. **No Seasonality Adjustment:**
   - Cannot adjust for seasonal patterns
   - Important for long-running trackers
   - **Planned:** Phase 5 (v3.5)

5. **Open-End Questions Not Supported:**
   - Qualitative responses cannot be tracked
   - Must pre-code into categories
   - **Planned:** Text analysis integration (v4.0)

### Historical Issues (Resolved)

**ISSUE-001: Multi_Mention with Selective TrackingSpecs** (v2.1)
- **Status:** RESOLVED in v2.1
- **Severity:** MEDIUM (was CRITICAL)
- **Description:** When using `option:Q10_4` for Multi_Mention questions, error occurred: "missing value where TRUE/FALSE needed"
- **Root Cause:** First pass auto-detected ALL columns regardless of TrackingSpecs, but second pass only processed selective columns, creating mismatch
- **Impact:** Tracker failed or skipped question in output
- **Fix:** Modified calculate_multi_mention_trend() to parse TrackingSpecs BEFORE first pass, ensuring all_columns matches tracked columns
- **Resolved:** 2025-12-04 (commit d52a3da)
- **File:** trend_calculator.R lines 2059-2075

**ISSUE-002: Multi_Mention Category Mode Data Loss** (v2.1)
- **Status:** RESOLVED in v2.1
- **Severity:** CRITICAL
- **Description:** When using `category:` syntax for Multi_Mention questions (e.g., `category:We rely on CCS`), question appeared in output but all values were blank/NA
- **Root Cause:** Data loader converted Multi_Mention sub-columns (Q10_1, Q10_2, Q10_4, etc.) to numeric, wiping out text values. Loader only protected exact column name "Q10", not sub-columns like "Q10_4"
- **Symptoms:** Console warnings showed `"WARNING: Q10_4: All 4 values are non-numeric (converted to NA)"`. Text labels like "We rely on CCS" were converted to NA before tracker could process them
- **Impact:** Category mode Multi_Mention completely non-functional - all values showed as 0% or blank
- **Fix:** Modified wave_loader.R clean_wave_data() to extract base code (strip `_[0-9]+$` suffix) when checking categorical protection. Now `is_categorical <- (col_name %in% categorical_cols) || (base_code %in% categorical_cols)`
- **Resolved:** 2025-12-05
- **File:** wave_loader.R line 188-189

**ISSUE-003: TECHNICAL_DOCUMENTATION.md Outdated** (v2.1)
- **Status:** RESOLVED in v2.1
- **Severity:** LOW
- **Description:** Previous TECHNICAL_DOCUMENTATION.md showed v1.0, actual version was v2.1
- **Impact:** Developer confusion about capabilities
- **Resolution:** Complete rewrite to TECHNICAL_DOCUMENTATION_V2.md with full v2.1 documentation
- **Resolved:** 2025-12-04

**RESOLVED-001: TrackingSpecs Not Working in GUI with Banners** (v2.0)
- **Issue:** When "Use Banners" checkbox enabled, TrackingSpecs ignored
- **Root Cause:** GUI banner path called old calculate_single_choice_trend() instead of enhanced version
- **Fix:** Changed banner_trends.R line 204 to use calculate_single_choice_trend_enhanced()
- **Status:** RESOLVED in v2.0

**RESOLVED-002: Wave History Show All Options Instead of Selected** (v2.0)
- **Issue:** Q45 with multiple categories showed ALL response options
- **Root Cause:** Missing proportions handling in write_banner_trend_table()
- **Fix:** Added full proportions support to banner trend table
- **Status:** RESOLVED in v2.0

---

## Testing and Validation

### Current Test Coverage

**Estimated:** 15% automated, 85% manual

**Test Files:**
```
test_data/
├── test_enhancements.R  # TrackingSpecs features
├── test_mvt.R           # End-to-end MVT tests
├── test_phase1.R        # Configuration loading tests
├── test_phase2.R        # Trend calculation tests
└── test_phase3.R        # Banner analysis tests
```

### Test Strategy

**Unit Tests (Needed):**
```r
# Validation tests
test_that("TrackingSpecs validation catches invalid specs")
test_that("Multi-mention column detection works correctly")

# Calculation tests
test_that("Top box calculation correct for 1-5 scale")
test_that("Custom range calculates percentages correctly")
test_that("Z-test for proportions produces correct p-values")

# Edge case tests
test_that("Handles missing data correctly")
test_that("Works with very small sample sizes")
test_that("Handles all-NA columns gracefully")
```

**Integration Tests (Needed):**
```r
# End-to-end tests
test_that("Full tracking analysis with all question types")
test_that("Backward compatibility with configs without TrackingSpecs")
test_that("Multiple report types generate correctly")
test_that("Banner analysis with all segments")
```

**Validation Tests:**
```r
# Real-world scenarios
test_that("Detects missing TrackingSpecs column gracefully")
test_that("Catches invalid TrackingSpecs and provides clear errors")
test_that("Validates Multi_Mention column availability")
test_that("Detects sample size issues")
```

### Manual Testing Checklist

Before each release:
- [ ] Run with existing project configs (backward compatibility)
- [ ] Test each TrackingSpecs combination
- [ ] Test with missing data in some waves
- [ ] Test with very small/large sample sizes
- [ ] Test with different weight distributions
- [ ] Test banner analysis with 1, 3, 5+ segments
- [ ] Test both report formats
- [ ] Test GUI with all features
- [ ] Verify Excel output formatting
- [ ] Check error messages are clear

---

## Extension Points

### Adding New Question Types

**Step 1:** Add to normalize_question_type() in trend_calculator.R:
```r
normalize_question_type <- function(q_type) {
  type_map <- c(
    ...,
    "CustomType" = "custom_type"
  )
  ...
}
```

**Step 2:** Create calculator function:
```r
calculate_custom_type_trend <- function(q_code, question_map, wave_data, config) {
  wave_results <- list()

  for (wave_id in config$waves$WaveID) {
    # Extract data
    q_data <- extract_question_data(wave_data[[wave_id]], wave_id, q_code, question_map)

    # Calculate custom metric
    custom_metric <- my_custom_calculation(q_data$values, q_data$weights)

    # Store result
    wave_results[[wave_id]] <- list(
      metric = custom_metric,
      n_unweighted = length(q_data$values),
      available = !is.null(q_data)
    )
  }

  # Calculate trends
  trend_indicators <- calculate_trend_indicators(wave_results, ...)

  # Return standard result structure
  return(list(
    question_code = q_code,
    question_type = "custom_type",
    wave_results = wave_results,
    trend_indicators = trend_indicators
  ))
}
```

**Step 3:** Add routing in calculate_all_trends():
```r
if (q_type == "custom_type") {
  trend_result <- calculate_custom_type_trend(q_code, question_map, wave_data, config)
}
```

### Custom Output Formats

**HTML Output Example:**
```r
write_tracker_html <- function(trend_results, config, output_path) {
  html <- "<html><head><style>...</style></head><body>"

  # Summary table
  html <- paste0(html, "<h1>Tracking Summary</h1>")
  html <- paste0(html, format_summary_html(trend_results))

  # Question details
  for (q_code in names(trend_results)) {
    html <- paste0(html, "<h2>", q_code, "</h2>")
    html <- paste0(html, format_question_html(trend_results[[q_code]]))
  }

  html <- paste0(html, "</body></html>")
  writeLines(html, output_path)
}
```

### JSON Export

**Example:**
```r
export_trends_json <- function(trend_results, output_path) {
  library(jsonlite)

  export_data <- lapply(trend_results, function(q_result) {
    list(
      question_code = q_result$question_code,
      question_text = q_result$question_text,
      waves = q_result$wave_results,
      trends = q_result$trend_indicators
    )
  })

  writeLines(toJSON(export_data, pretty = TRUE), output_path)
}
```

---

## Development Guidelines

### Code Style

**Function Documentation:**
```r
#' Calculate Top Box Percentage
#'
#' Calculates the percentage of respondents giving top N rating values.
#' Automatically detects scale from data.
#'
#' @param values Numeric vector of response values
#' @param weights Numeric vector of weights (same length as values)
#' @param n_boxes Integer number of top values to include (default: 1)
#'
#' @return List with $proportion (0-100), $scale_detected, $top_values
#'
#' @examples
#' values <- c(1, 2, 3, 4, 5, 4, 5, 3, 4, 5)
#' weights <- rep(1, 10)
#' result <- calculate_top_box(values, weights, n_boxes = 2)
#' # result$proportion = 60 (6 out of 10 rated 4 or 5)
#'
#' @export
calculate_top_box <- function(values, weights, n_boxes = 1) {
  # Implementation...
}
```

**Error Handling:**
```r
# Validate inputs
if (is.null(values) || length(values) == 0) {
  stop("calculate_top_box: values cannot be NULL or empty")
}

if (length(values) != length(weights)) {
  stop("calculate_top_box: values and weights must have same length")
}

# Informative warnings
if (n_boxes > length(unique(values))) {
  warning(paste0(
    "calculate_top_box: n_boxes (", n_boxes, ") exceeds number of unique values (",
    length(unique(values)), "). Using all unique values."
  ))
}
```

**Code Organization:**
```r
# ============================================================================
# SECTION: Top Box Calculations
# ============================================================================

calculate_top_box <- function(...) { }
calculate_bottom_box <- function(...) { }
calculate_custom_range <- function(...) { }

# ============================================================================
# SECTION: Statistical Testing
# ============================================================================

test_proportion_trend <- function(...) { }
test_mean_trend <- function(...) { }
```

### Adding New Features

**Process:**
1. **Design** - Create specification document (see TURAS_TRACKER_ENHANCEMENT.md as example)
2. **Validate** - Review with stakeholders
3. **Implement** - Follow modular architecture
4. **Test** - Write unit and integration tests
5. **Document** - Update USER_MANUAL.md and TECHNICAL_DOCUMENTATION.md
6. **Review** - Code review before merge

**Feature Flags:**
```r
# For experimental features
if (get_setting(config, "enable_experimental_feature", default = FALSE)) {
  # Experimental code
}
```

### Version Control

**Branch Strategy:**
- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - Feature branches
- `bugfix/*` - Bug fix branches

**Commit Messages:**
```
feat: Add wave history report format
fix: Resolve Q10 multi-mention TrackingSpecs issue
docs: Update USER_MANUAL with TrackingSpecs examples
test: Add unit tests for top box calculation
refactor: Extract shared validation functions
```

---

## File Inventory

### Core R Scripts (11 files)

| File | Lines | Status | Quality | Purpose |
|------|-------|--------|---------|---------|
| run_tracker.R | 472 | Active | HIGH | Main orchestration |
| run_tracker_gui.R | 689 | Active | HIGH | Shiny GUI interface |
| tracker_config_loader.R | ~400 | Active | HIGH | Configuration loading |
| wave_loader.R | ~500 | Active | HIGH | Wave data loading |
| question_mapper.R | ~350 | Active | HIGH | Question mapping |
| validation_tracker.R | ~600 | Active | HIGH | Validation framework |
| trend_calculator.R | ~800 | Active | HIGH | Trend calculations |
| banner_trends.R | ~400 | Active | HIGH | Banner analysis |
| formatting_utils.R | ~200 | Active | MEDIUM | Output formatting |
| tracker_output.R | ~500 | Active | HIGH | Excel generation |
| constants.R | Small | Active | MEDIUM | Constants |

**Total Core Code:** ~4,911 lines

### Supporting Scripts (7 files)

| File | Status | Purpose |
|------|--------|---------|
| create_templates.R | Active | Generate template files |
| debug_tracker.R | Supporting | Debugging utility |
| test_wave_history.R | Supporting | Wave history tests |
| test_enhancements.R | Supporting | TrackingSpecs tests |
| test_mvt.R | Supporting | Integration tests |
| test_phase1.R | Supporting | Phase 1 tests |
| test_phase2.R | Supporting | Phase 2 tests |
| test_phase3.R | Supporting | Phase 3 tests |

### Documentation (11 files - Active)

| File | Lines | Purpose | Status |
|------|-------|---------|--------|
| USER_MANUAL.md | 2,237 | Comprehensive user guide v2.1 | CURRENT |
| TECHNICAL_DOCUMENTATION_V2.md | This file | Developer documentation v2.1 | CURRENT |
| README_TEMPLATES.md | 238 | Template usage guide | CURRENT |
| QUICK_START.md | 532 | 15-minute introduction | CURRENT |
| EXAMPLE_WORKFLOWS.md | 1,161 | Eight workflow examples | CURRENT |
| TURAS_TRACKER_ENHANCEMENT.md | 1,854 | TrackingSpecs design spec | REFERENCE |
| TRACKER_ENHANCEMENT_SPEC_Wave_History_Reports.md | 498 | Wave history design spec | REFERENCE |
| TESTING_WALKTHROUGH.md | 224 | Testing guide | CURRENT |
| WAVE_HISTORY_WALKTHROUGH.md | 284 | Wave history walkthrough | CURRENT |
| BUG_FIX_SUMMARY.md | 70 | Historical bug fixes | ARCHIVE |
| ENHANCEMENT_SUMMARY.md | 96 | Historical enhancements | ARCHIVE |

### Templates (5 files - All Essential)

| File | Purpose | Status |
|------|---------|--------|
| tracking_config_template.xlsx | Configuration template | PRODUCTION |
| question_mapping_template.xlsx | Question mapping template | PRODUCTION |
| wave_data_template.csv | Data structure example | PRODUCTION |
| derived_metrics_template.xlsx | Derived metrics template | SUPPORTING |
| master_dictionary_template.csv | Data dictionary template | SUPPORTING |

### Files to Archive (5 files)

| File | Reason |
|------|--------|
| diagnose_wave3_columns.R | Single-purpose diagnostic (resolved) |
| run_ccs_tracking.R | Project-specific legacy code |
| test_quick_fixes.R | Temporary testing script |
| verify_tracker_fix.R | Single-purpose verification (resolved) |
| BUG_FIX_SUMMARY.md | Historical record (consolidated in this doc) |

**Note:** Archive, do not delete - useful for historical reference

---

## Future Development Roadmap

### v2.2 (Q1 2026) - Bug Fixes and Polish
- ✅ Fix Q10 Multi_Mention TrackingSpecs issue
- ✅ Add confidence intervals to wave history output
- ✅ Improve error messages for common misconfigurations
- ✅ Unit test coverage to 50%
- ✅ Performance optimization for large datasets

### v3.0 (Q2 2026) - Phase 4 Features
- 📊 Automated chart generation
- 📊 HTML report format
- 📊 PowerPoint export
- 🧪 80% test coverage
- 🔧 Refactor shared utilities to /shared/

### v3.5 (Q3 2026) - Advanced Analytics
- 📈 Seasonality adjustment
- 📈 Trend forecasting
- 📈 Statistical process control (SPC) charts
- 📈 Multi-year comparison features

### v4.0 (Q4 2026) - Integration and Automation
- 🔗 Real-time data integration
- 🔗 API endpoints for programmatic access
- 🤖 Automated scheduling and distribution
- 💬 Text analysis for open-ends
- 🎯 Dashboard integration

---

## Support and Contribution

### Getting Help

1. **User Manual** - Check USER_MANUAL.md for usage questions
2. **This Document** - Technical and architectural questions
3. **Test Scripts** - Run test scripts to verify setup
4. **Error Logs** - Check tracker_error.log for detailed errors

### Reporting Issues

Include:
1. Tracker version (shown in run output)
2. R version and OS
3. Minimal reproducible example
4. Error message and traceback (from tracker_error.log)
5. Configuration files (if applicable)

### Contributing

1. **Fork** the repository
2. **Create** a feature branch
3. **Implement** with tests
4. **Document** changes
5. **Submit** pull request

---

## Appendix

### Glossary

| Term | Definition |
|------|------------|
| Wave | A single data collection period in a tracking study |
| Banner | Demographic breakout variable (Gender, Age, etc.) |
| TrackingSpecs | Custom metric specifications (v2.0+) |
| Design Effect (DEFF) | Weight variance impact on effective sample size |
| Top Box | Percentage giving highest rating value(s) |
| NPS | Net Promoter Score (% Promoters - % Detractors) |
| Composite | Derived metric combining multiple questions |
| Multi-Mention | Select-all-that-apply question type |
| Wave History | Compact report format (one row per metric) |

### Configuration Templates

See template files for complete examples:
- `tracking_config_template.xlsx`
- `question_mapping_template.xlsx`
- `wave_data_template.csv`

### Statistical Formulas Reference

**Z-Test for Proportions:**
```
H₀: p₁ = p₂
z = (p₂ - p₁) / SE
SE = √(p_pool × (1 - p_pool) × (1/n₁ + 1/n₂))
p_pool = (p₁×n₁ + p₂×n₂) / (n₁ + n₂)
```

**Welch's T-Test:**
```
H₀: μ₁ = μ₂
t = (μ₂ - μ₁) / SE
SE = √(s₁²/n₁ + s₂²/n₂)
df = (s₁²/n₁ + s₂²/n₂)² / ((s₁²/n₁)²/(n₁-1) + (s₂²/n₂)²/(n₂-1))
```

**Design Effect:**
```
DEFF = 1 + cv²
cv = σ(weights) / μ(weights)
n_eff = n_weighted / DEFF
```

---

**Document Version:** 2.1
**Last Updated:** 2025-12-04
**Maintainer:** Turas Analytics Team
**Next Review:** Q1 2026

---

## END OF TECHNICAL DOCUMENTATION
