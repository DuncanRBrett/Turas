# Turas Tracker - Technical Documentation

**Version:** 1.0 (MVT - Minimum Viable Tracker)
**Last Updated:** 2025-11-18
**Target Audience:** Developers, Technical Contributors, Module Maintainers

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Module Structure](#module-structure)
3. [Core Components](#core-components)
4. [Data Flow](#data-flow)
5. [API Reference](#api-reference)
6. [Statistical Algorithms](#statistical-algorithms)
7. [Extension Points](#extension-points)
8. [Known Issues](#known-issues)
9. [Testing Strategy](#testing-strategy)
10. [Integration with Tabs](#integration-with-tabs)

---

## Architecture Overview

### Design Philosophy

Turas Tracker follows a **modular pipeline architecture** optimized for multi-wave time series analysis:

```
Configuration → Wave Loading → Mapping → Validation → Trend Calculation → Output
```

**Key Principles:**
- **Separation of Concerns:** Each module handles one stage of the pipeline
- **Fail-Fast Validation:** Detect issues early before computation
- **Flexible Question Mapping:** Handle evolving questionnaires across waves
- **Statistical Rigor:** Proper significance testing for trend detection
- **Reusable Components:** Share utilities with other Turas modules (future)

### Design Patterns

1. **Pipeline Pattern:** Sequential data processing stages
2. **Strategy Pattern:** Different calculators for different question types (rating, NPS, proportion)
3. **Builder Pattern:** Configuration object construction
4. **Adapter Pattern:** Question mapping adapts different wave structures to unified interface
5. **Factory Pattern:** Trend calculator selection based on question type

### MVT Phases

**Phase 1: Configuration & Loading** ✅ Complete
- Load tracking configuration
- Load question mapping
- Load wave data files
- Validation

**Phase 2: Trend Calculation & Output** ✅ Complete
- Calculate trends for rating and proportion questions
- Statistical significance testing
- Excel output with trend indicators

**Phase 3: Banner Breakouts & Composites** ✅ Complete
- Banner (demographic) analysis
- Composite metric tracking
- Multi-segment trending

**Phase 4: Charting & Advanced Features** 🚧 Planned
- Automated chart generation
- Seasonality adjustment
- Forecasting
- Dashboard integration

---

## Module Structure

### File Organization

```
modules/tracker/
├── run_tracker.R                  # Main entry point (250 lines)
├── run_tracker_gui.R              # Shiny GUI interface (300 lines)
├── tracker_config_loader.R        # Configuration loading (400 lines)
├── wave_loader.R                  # Wave data loading (500 lines)
├── question_mapper.R              # Question mapping logic (350 lines)
├── validation_tracker.R           # Validation functions (600 lines)
├── trend_calculator.R             # Trend calculation (800 lines)
├── banner_trends.R                # Banner analysis (400 lines)
├── formatting_utils.R             # Output formatting (200 lines)
├── tracker_output.R               # Excel output writer (500 lines)
├── create_templates.R             # Template generator (150 lines)
├── run_ccs_tracking.R             # Legacy CCS tracker (deprecated)
├── test_data/                     # Test scripts
│   ├── test_phase1.R
│   ├── test_phase2.R
│   ├── test_phase3.R
│   └── test_mvt.R
├── QUICK_START.md
├── USER_MANUAL.md
├── TECHNICAL_DOCUMENTATION.md     # This file
└── EXAMPLE_WORKFLOWS.md
```

**Total Lines of Code:** ~4,500 lines (excluding tests and deprecated code)

### Module Dependencies

**Required R Packages:**
```r
- openxlsx      # Excel file I/O
- readxl        # Reading Excel configuration
```

**Optional R Packages:**
```r
- haven         # SPSS .sav file support
- foreign       # Stata .dta file support
```

**Internal Dependencies:**
- Currently standalone
- **Future:** Will use shared/statistics/, shared/config/, shared/weights/

---

## Core Components

### 1. Configuration Loader (`tracker_config_loader.R`)

**Purpose:** Load and parse tracking configuration files

**Key Functions:**

```r
load_tracking_config(config_path)
# Returns: list(
#   waves = data.frame(...),
#   settings = list(...),
#   banner = data.frame(...),
#   tracked_questions = data.frame(...),
#   config_path = "..."
# )

load_question_mapping(mapping_path)
# Returns: data.frame with QuestionCode, QuestionType, W1, W2, W3, ...
```

**Configuration Structure:**

```r
config <- list(
  waves = data.frame(
    WaveID = c("W1", "W2", "W3"),
    WaveName = c("Jan 2024", "Apr 2024", "Jul 2024"),
    DataFile = c("wave1.csv", "wave2.csv", "wave3.csv"),
    FieldworkStart = as.Date(c("2024-01-01", "2024-04-01", "2024-07-01")),
    FieldworkEnd = as.Date(c("2024-01-15", "2024-04-15", "2024-07-15"))
  ),

  settings = list(
    project_name = "Brand Tracking",
    output_file = "results.xlsx",
    confidence_level = 0.95,
    min_base_size = 30,
    trend_significance = TRUE
  ),

  banner = data.frame(
    BreakVariable = c("Gender", "Age_Group"),
    BreakLabel = c("Gender", "Age Group")
  ),

  tracked_questions = data.frame(
    QuestionCode = c("Q01_Awareness", "Q02_Satisfaction"),
    QuestionText = c("Brand Awareness", "Satisfaction (1-5)"),
    QuestionType = c("proportion", "rating")
  )
)
```

**Helper Functions:**

```r
get_setting(config, setting_name, default = NULL)
# Safely retrieve setting value with default fallback

parse_settings_to_list(settings_df)
# Convert Settings sheet data frame to named list

get_wave_ids(config)
# Extract vector of wave IDs
```

---

### 2. Wave Loader (`wave_loader.R`)

**Purpose:** Load survey data for each wave

**Key Functions:**

```r
load_all_waves(config, data_dir = NULL)
# Returns: list(
#   W1 = data.frame(...),
#   W2 = data.frame(...),
#   W3 = data.frame(...)
# )

load_wave_data(file_path, wave_id)
# Load single wave data file
# Supports: CSV, XLSX, SAV, DTA
# Returns: data.frame

clean_wave_data(wave_df, wave_id)
# Clean data quality issues:
# - Convert comma decimals (7,5 → 7.5)
# - Convert DK/NS/NA to proper NA
# - Standardize column types
```

**Data Cleaning:**

```r
# Automatic cleaning applied:
# 1. Comma decimal separator → period
"7,5" → 7.5

# 2. Non-response codes → NA
"DK" → NA
"Don't Know" → NA
"Prefer not to say" → NA
"N/A" → NA

# 3. Numeric conversion where appropriate
```

**Weight Application:**

```r
apply_wave_weights(wave_df, weight_var, wave_id)
# Validates and applies weight variable
# Creates standardized "weight_var" column
# Calculates design effect (DEFF)
# Returns: wave_df with weight_var column

get_wave_weight_var(config, wave_id)
# Extract weight variable name for specific wave
```

**File Format Support:**

```r
# CSV
read.csv(file_path)

# Excel (.xlsx, .xls)
readxl::read_excel(file_path)

# SPSS (.sav)
haven::read_sav(file_path)

# Stata (.dta)
haven::read_dta(file_path)
```

---

### 3. Question Mapper (`question_mapper.R`)

**Purpose:** Map question codes across waves when they differ

**Key Functions:**

```r
build_question_map_index(question_mapping, config)
# Build lookup index for fast question code resolution
# Returns: list with nested structure for quick access

get_question_metadata(question_map, question_code)
# Retrieve question type, text, and other metadata
# Returns: list(QuestionCode, QuestionText, QuestionType, ...)

get_wave_question_code(question_map, std_code, wave_id)
# Map standardized code to wave-specific code
# Example: Q01_Awareness → W1:"Q1_Aware", W2:"Q01_BrandAware"
# Returns: Character wave-specific code or NA

extract_question_data(wave_df, wave_id, question_code, question_map)
# Extract question data from wave using mapping
# Returns: list(values, weights, available)
```

**Question Map Structure:**

```r
question_map <- list(
  Q01_Awareness = list(
    QuestionCode = "Q01_Awareness",
    QuestionText = "Brand Awareness",
    QuestionType = "proportion",
    wave_codes = list(
      W1 = "Q1_Awareness",
      W2 = "Q01_BrandAwareness",
      W3 = "Awareness_Q1"
    )
  ),
  Q02_Satisfaction = list(
    QuestionCode = "Q02_Satisfaction",
    QuestionText = "Overall Satisfaction (1-5)",
    QuestionType = "rating",
    wave_codes = list(
      W1 = "Q2_Sat",
      W2 = "Q02_Satisfaction",
      W3 = "Satisfaction_Q2"
    )
  )
)
```

**Type Normalization:**

```r
normalize_question_type(q_type)
# Maps TurasTabs types to internal tracker types
# Single_Response → single_choice
# Rating / Likert → rating
# NPS → nps
# Composite → composite
```

---

### 4. Validation Module (`validation_tracker.R`)

**Purpose:** Comprehensive validation before trend calculation

**Key Functions:**

```r
validate_tracker_setup(config, question_mapping, question_map, wave_data)
# Master validation function
# Returns: list(valid = TRUE/FALSE, messages = c(...))

validate_tracking_config(config, question_mapping)
# Validate configuration structure and content
# Checks:
# - Required sheets present
# - Required columns exist
# - Wave IDs unique
# - Question codes valid

validate_wave_data(wave_data, config, question_mapping)
# Validate loaded wave data
# Checks:
# - All waves loaded successfully
# - Question columns exist in waves
# - Data types appropriate
# - Sample sizes adequate

validate_question_mapping(config, question_map, wave_data)
# Validate question mapping
# Returns: data.frame showing question availability by wave

check_wave_consistency(wave_data)
# Check for consistency issues across waves
# - Sample size changes >50%
# - Column name changes
# - Data type changes
```

**Validation Checks:**

| Check Category | Specific Checks |
|----------------|-----------------|
| **Configuration** | Required sheets exist, Required columns present, Wave IDs unique, Settings valid |
| **Question Mapping** | All tracked questions mapped, Question types valid, Wave codes exist |
| **Wave Data** | Files exist and loadable, Sample sizes adequate (n>=30), Question columns present, Data types appropriate |
| **Consistency** | Sample size stability, Column naming consistency, Data type consistency |
| **Statistical** | Sufficient variance for testing, No constant values, Enough valid responses |

---

### 5. Trend Calculator (`trend_calculator.R`)

**Purpose:** Calculate trends and statistical significance

**Key Functions:**

```r
calculate_all_trends(config, question_map, wave_data)
# Main orchestration function
# Routes to specific calculators based on question type
# Returns: list of trend results by question

calculate_rating_trend(q_code, question_map, wave_data, config)
# Calculate mean trend for rating questions
# Returns: list(
#   question_code, question_text, question_type,
#   wave_results = list(W1 = list(...), W2 = list(...)),
#   trend_indicators = list(...)
# )

calculate_proportion_trend(q_code, question_map, wave_data, config)
# Calculate proportion trend for single choice questions
# Returns: trend result object

calculate_nps_trend(q_code, question_map, wave_data, config)
# Calculate NPS trend
# Returns: trend result with NPS components

calculate_composite_trend(q_code, question_map, wave_data, config)
# Calculate composite metric trend
# Returns: trend result for composite
```

**Wave Result Structure:**

```r
# For rating questions:
wave_result <- list(
  mean = 3.8,
  sd = 1.2,
  n_unweighted = 500,
  n_weighted = 500,
  n_effective = 450,
  deff = 1.11,
  available = TRUE,
  ci_lower = 3.7,
  ci_upper = 3.9
)

# For proportion questions:
wave_result <- list(
  option_results = list(
    "Brand A" = list(
      proportion = 0.45,
      count_weighted = 225,
      n_unweighted = 500,
      n_weighted = 500,
      available = TRUE
    ),
    "Brand B" = list(...)
  )
)

# For NPS questions:
wave_result <- list(
  nps_score = 15,
  pct_promoters = 40,
  pct_passives = 35,
  pct_detractors = 25,
  n_unweighted = 500,
  n_weighted = 500,
  available = TRUE
)
```

**Trend Indicators:**

```r
# Calculated between consecutive waves
trend_indicator <- list(
  from_wave = "W1",
  to_wave = "W2",
  direction = "up",  # "up", "down", "stable"
  significant = TRUE,  # Statistical significance
  p_value = 0.02,
  symbol = "↑"  # "↑", "↓", "→", "—"
)
```

---

### 6. Banner Trends (`banner_trends.R`)

**Purpose:** Calculate trends broken out by demographic segments

**Key Functions:**

```r
calculate_banner_trends(config, question_map, wave_data)
# Calculate trends for all banners and questions
# Returns: nested list by question → banner → segment → wave

calculate_question_banner_trends(q_code, banner_var, question_map, wave_data, config)
# Calculate trends for one question across banner breakouts
# Returns: trend results by banner segment

segment_wave_data(wave_df, banner_var, banner_label)
# Split wave data into segments based on banner variable
# Returns: list of data frames by segment
```

**Banner Result Structure:**

```r
banner_trends <- list(
  Q01_Awareness = list(
    Gender = list(
      Male = list(
        W1 = list(mean = 3.9, ...),
        W2 = list(mean = 4.1, ...),
        trend_W1_W2 = list(direction = "up", significant = TRUE, ...)
      ),
      Female = list(
        W1 = list(mean = 3.7, ...),
        W2 = list(mean = 3.8, ...),
        trend_W1_W2 = list(direction = "stable", significant = FALSE, ...)
      )
    ),
    Age_Group = list(...)
  ),
  Q02_Satisfaction = list(...)
)
```

---

### 7. Output Module (`tracker_output.R`)

**Purpose:** Format and write Excel output

**Key Functions:**

```r
write_tracker_output(trend_results, config, output_path)
# Write complete Excel workbook
# Creates:
# - Summary sheet (all questions overview)
# - Detail sheets (one per question)
# - Metadata sheet

format_summary_sheet(wb, trend_results, config)
# Format summary table with latest wave + trends

format_question_sheet(wb, sheet_name, question_result, config)
# Format detailed trend table for one question
# Includes wave columns, trend indicators, sample sizes

format_metadata_sheet(wb, config, generation_time)
# Document analysis parameters

apply_trend_formatting(wb, sheet_name, trend_col_idx, trend_data)
# Apply conditional formatting for trend indicators
# ↑ = Green
# ↓ = Red
# → = Gray
```

**Excel Formatting:**

```r
# Header row
header_style <- createStyle(
  fontBold = TRUE,
  fillColor = "#4472C4",
  fontColour = "#FFFFFF"
)

# Trend indicators
up_style <- createStyle(fontColour = "#00AA00", fontBold = TRUE)  # Green
down_style <- createStyle(fontColour = "#CC0000", fontBold = TRUE)  # Red
stable_style <- createStyle(fontColour = "#666666")  # Gray

# Number formats
percentage_style <- createStyle(numFmt = "0%")
decimal1_style <- createStyle(numFmt = "0.0")
decimal2_style <- createStyle(numFmt = "0.00")
```

---

## Data Flow

### Complete Pipeline

```
┌────────────────────────────────────────────────────┐
│ 1. CONFIGURATION LOADING                           │
│    - Load tracking_config.xlsx                     │
│    - Load question_mapping.xlsx                    │
│    - Parse waves, settings, questions              │
└────────────────┬───────────────────────────────────┘
                 │
┌────────────────▼───────────────────────────────────┐
│ 2. WAVE DATA LOADING                               │
│    For each wave:                                  │
│      - Load data file (CSV/Excel/SAV/DTA)          │
│      - Clean data (comma decimals, DK→NA)          │
│      - Apply weights (if specified)                │
│      - Store in wave_data list                     │
└────────────────┬───────────────────────────────────┘
                 │
┌────────────────▼───────────────────────────────────┐
│ 3. QUESTION MAPPING                                │
│    - Build question map index                      │
│    - Map standard codes to wave-specific codes     │
│    - Validate all questions available              │
└────────────────┬───────────────────────────────────┘
                 │
┌────────────────▼───────────────────────────────────┐
│ 4. VALIDATION                                      │
│    - Validate configuration                        │
│    - Validate wave data                            │
│    - Check question mapping                        │
│    - Verify sample sizes adequate                  │
└────────────────┬───────────────────────────────────┘
                 │
┌────────────────▼───────────────────────────────────┐
│ 5. TREND CALCULATION                               │
│    For each tracked question:                      │
│      ┌──────────────────────────────────────────┐  │
│      │ 5a. Extract Question Data                │  │
│      │     - Get wave-specific column           │  │
│      │     - Extract values and weights         │  │
│      └─────────────┬────────────────────────────┘  │
│                    │                                │
│      ┌─────────────▼────────────────────────────┐  │
│      │ 5b. Calculate Wave Metrics               │  │
│      │     Rating: mean, sd, CI                 │  │
│      │     Proportion: % by option              │  │
│      │     NPS: promoters, passives, detractors │  │
│      └─────────────┬────────────────────────────┘  │
│                    │                                │
│      ┌─────────────▼────────────────────────────┐  │
│      │ 5c. Calculate Trends                     │  │
│      │     For each consecutive wave pair:      │  │
│      │       - Compare metrics                  │  │
│      │       - Run significance test            │  │
│      │       - Assign trend indicator           │  │
│      └─────────────┬────────────────────────────┘  │
│                    │                                │
│      ┌─────────────▼────────────────────────────┐  │
│      │ 5d. Banner Analysis (if enabled)         │  │
│      │     Repeat 5a-5c for each segment        │  │
│      └──────────────────────────────────────────┘  │
└────────────────┬───────────────────────────────────┘
                 │
┌────────────────▼───────────────────────────────────┐
│ 6. OUTPUT GENERATION                               │
│    - Create Excel workbook                         │
│    - Write summary sheet                           │
│    - Write question detail sheets                  │
│    - Write metadata sheet                          │
│    - Apply formatting                              │
│    - Save workbook                                 │
└────────────────────────────────────────────────────┘
```

### Memory Management

```
Configuration (small) ────────────────┐
    ↓                                 │
Question Mapping (small) ─────────────┤
    ↓                                 │
Wave Data (large) ────────────────────┼──> Kept in memory
    List of data frames               │
    One per wave                      │
    ↓                                 │
Question Map Index (medium) ──────────┘
    ↓
Trend Calculation (wave by wave):
    Extract question data ────────────────> Temporary, discarded
    Calculate metrics ────────────────────> Accumulated in results
    ↓
Trend Results (medium) ───────────────────> Kept in memory
    ↓
Excel Workbook (medium) ──────────────────> Written to disk
```

**Memory Optimization:**
- Load all waves once (avoid reloading)
- Process questions sequentially (don't accumulate intermediate data)
- Use vectorized operations where possible
- Write Excel incrementally for very large outputs

---

## API Reference

### Main Entry Point

```r
run_tracker(
  tracking_config_path,
  question_mapping_path,
  data_dir = NULL,
  output_path = NULL,
  use_banners = FALSE
)
```

**Parameters:**
- `tracking_config_path` — Path to tracking_config.xlsx
- `question_mapping_path` — Path to question_mapping.xlsx (or NA if not needed)
- `data_dir` — Directory containing wave data files (for relative paths)
- `output_path` — Output Excel file path (defaults to config setting)
- `use_banners` — Enable banner analysis (Phase 3)

**Returns:** Character path to generated Excel file

**Example:**

```r
result_path <- run_tracker(
  tracking_config_path = "config/tracking_config.xlsx",
  question_mapping_path = "config/question_mapping.xlsx",
  data_dir = "data/",
  use_banners = FALSE
)

cat("Results written to:", result_path, "\n")
```

### Configuration Functions

```r
# Load configuration
config <- load_tracking_config("tracking_config.xlsx")

# Load question mapping
mapping <- load_question_mapping("question_mapping.xlsx")

# Build question map
question_map <- build_question_map_index(mapping, config)

# Get setting value
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

# Get wave-specific question code
wave1_code <- get_wave_question_code(question_map, "Q01_Awareness", "W1")

# Extract question data from wave
q_data <- extract_question_data(wave_data[["W1"]], "W1", "Q01_Awareness", question_map)
```

### Trend Calculation Functions

```r
# Calculate all trends
trend_results <- calculate_all_trends(config, question_map, wave_data)

# Calculate specific question type trends
rating_trend <- calculate_rating_trend("Q01", question_map, wave_data, config)
nps_trend <- calculate_nps_trend("Q02", question_map, wave_data, config)

# Calculate banner trends
banner_trends <- calculate_banner_trends(config, question_map, wave_data)
```

### Output Functions

```r
# Write tracker output
write_tracker_output(trend_results, config, "output.xlsx")

# Format specific sheets (for custom output)
wb <- createWorkbook()
addWorksheet(wb, "Summary")
format_summary_sheet(wb, trend_results, config)
saveWorkbook(wb, "custom_output.xlsx")
```

---

## Statistical Algorithms

### 1. Z-Test for Proportions

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
  if (p2 > p1) {
    trend <- "up"
    symbol <- "↑"
  } else {
    trend <- "down"
    symbol <- "↓"
  }
} else {
  trend <- "stable"
  symbol <- "→"
}
```

**Assumptions:**
- Independent samples (different respondents each wave)
- Sample sizes large enough (n ≥ 30 per wave)
- Random sampling

### 2. T-Test for Means

**Use Case:** Test if mean rating changed significantly between waves

**Implementation:**

```r
# Wave 1: mean1, sd1, n1
# Wave 2: mean2, sd2, n2

# For weighted data, use effective sample sizes
n1_eff <- n1 / deff1
n2_eff <- n2 / deff2

# Standard error (Welch's t-test - unequal variances)
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

### 3. NPS Trend Testing

**Use Case:** Test if NPS score changed significantly

**NPS Calculation:**

```r
# NPS = % Promoters - % Detractors
# Promoters: scores 9-10
# Passives: scores 7-8
# Detractors: scores 0-6

n_promoters <- sum(scores >= 9)
n_passives <- sum(scores >= 7 & scores <= 8)
n_detractors <- sum(scores <= 6)

pct_promoters <- n_promoters / n_total * 100
pct_detractors <- n_detractors / n_total * 100

nps <- pct_promoters - pct_detractors
```

**Significance Testing:**

```r
# Treat NPS as proportion test
# NPS1 vs NPS2 is equivalent to testing if difference in
# (pct_promoters1 - pct_detractors1) vs (pct_promoters2 - pct_detractors2)
# is significant

# Use Z-test on NPS score difference
# This is conservative but appropriate for typical tracking studies
```

### 4. Design Effect (DEFF)

**Purpose:** Adjust for impact of weighting on statistical tests

**Calculation:**

```r
# DEFF based on coefficient of variation
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
(not n = 500, which would overstate significance)
```

---

## Extension Points

### Adding New Question Types

**Step 1:** Add question type to normalize_question_type():

```r
# In trend_calculator.R
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
# In trend_calculator.R
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

  # Calculate trends between consecutive waves
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

### Integration with External Systems

**JSON Export Example:**

```r
export_trends_json <- function(trend_results, output_path) {

  library(jsonlite)

  # Convert to JSON-friendly structure
  export_data <- lapply(trend_results, function(q_result) {
    list(
      question_code = q_result$question_code,
      question_text = q_result$question_text,
      waves = q_result$wave_results,
      trends = q_result$trend_indicators
    )
  })

  # Write JSON
  writeLines(toJSON(export_data, pretty = TRUE), output_path)
}
```

---

## Known Issues

### Critical Issues

**CR-TRACKER-001: Always-False Condition**
- **File:** `run_tracker.R:244` (legacy code path)
- **Issue:** `if (file.exists(data_file) && !file.exists(data_file))` always evaluates to FALSE
- **Impact:** Dead code - warning never triggered
- **Status:** Low priority (dead code in deprecated legacy path)
- **Fix:** Remove condition or fix logic

**CR-TRACKER-002: Missing Error Handling**
- **File:** Multiple files
- **Issue:** Some file I/O operations lack try-catch wrappers
- **Impact:** Unclear error messages when files missing/corrupt
- **Status:** Medium priority
- **Fix:** Add comprehensive error handling with clear messages

### High-Priority Issues

**Missing Test Coverage**
- Current coverage: <15%
- Need unit tests for all calculator functions
- Need integration tests for full pipeline
- Priority for v2.0

**Limited Documentation**
- Function-level documentation sparse
- Need more inline comments explaining statistical logic
- Need developer setup guide

### Medium-Priority Issues

**No Confidence Intervals in Output**
- CIs calculated internally but not shown in Excel output
- Should add optional CI columns
- Planned for Phase 4

**Limited Chart Support**
- No automated chart generation
- Users must create charts manually in Excel
- Planned for Phase 4

**No Seasonality Adjustment**
- Can't adjust for seasonal patterns
- Important for long-running trackers
- Planned for Phase 5

---

## Testing Strategy

### Current Test Coverage

**Estimated:** 10-15% (manual testing only)

**Test Files:**
- `test_data/test_phase1.R` — Configuration loading tests
- `test_data/test_phase2.R` — Trend calculation tests
- `test_data/test_phase3.R` — Banner analysis tests
- `test_data/test_mvt.R` — End-to-end tests

### Planned Test Structure

```
modules/tracker/tests/
├── test_config_loader.R
├── test_wave_loader.R
├── test_question_mapper.R
├── test_validation.R
├── test_trend_calculator.R
├── test_banner_trends.R
├── test_output.R
├── test_integration.R
└── fixtures/
    ├── test_tracking_config.xlsx
    ├── test_question_mapping.xlsx
    ├── wave1_test.csv
    ├── wave2_test.csv
    └── wave3_test.csv
```

### Unit Test Examples

```r
# test_trend_calculator.R
library(testthat)

test_that("Z-test for proportions calculates correctly", {
  # Setup
  p1 <- 0.45
  n1 <- 500
  p2 <- 0.50
  n2 <- 500

  # Test
  result <- test_proportion_difference(p1, n1, p2, n2, alpha = 0.05)

  # Verify
  expect_true(result$significant)
  expect_equal(result$direction, "up")
})

test_that("Rating trend handles missing data correctly", {
  # Setup test data with NAs
  wave1 <- data.frame(Q01 = c(5, 4, NA, 3, 5), weight = 1)
  wave2 <- data.frame(Q01 = c(4, 5, 3, NA, 4), weight = 1)

  # Test
  trend <- calculate_rating_trend_simple(wave1$Q01, wave2$Q01, ...)

  # Verify NAs excluded
  expect_equal(trend$wave1_n, 4)
  expect_equal(trend$wave2_n, 4)
})
```

---

## Integration with Tabs

### Shared Components (Future)

**Currently:** Tracker and Tabs are independent modules

**Planned Shared Utilities:**

```
shared/
├── statistics/
│   ├── significance_tests.R
│   ├── confidence_intervals.R
│   └── weighting.R
├── config/
│   ├── config_utils.R
│   └── validation.R
└── data/
    ├── loader.R
    └── cleaner.R
```

### Data Compatibility

**Tabs Output → Tracker Input:**

```r
# Tabs produces crosstab for each wave
# Wave 1: tabs_output_wave1.xlsx
# Wave 2: tabs_output_wave2.xlsx
# Wave 3: tabs_output_wave3.xlsx

# Tracker can track the Tabs outputs!
# Track metrics from Tabs tables across waves
```

**Example Workflow:**

```r
# 1. Run Tabs for each wave
for (wave in waves) {
  run_crosstabs(
    config_file = paste0("config_", wave, ".xlsx"),
    output_file = paste0("tabs_", wave, ".xlsx")
  )
}

# 2. Extract metrics from Tabs outputs
# (Manual or scripted extraction)

# 3. Create tracker input from Tabs metrics
# (Combines metrics across waves)

# 4. Run Tracker
run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  ...
)
```

### Unified Survey Structure

Both modules can use same `Survey_Structure.xlsx`:

```r
# In Tabs project:
Survey_Structure.xlsx  # Question definitions

# In Tracker project:
Survey_Structure.xlsx  # Same file!
question_mapping.xlsx   # Maps codes across waves
```

---

## Version History

**v1.0 (2025-11-18) - MVT Release**
- Phase 1: Configuration loading and validation
- Phase 2: Trend calculation for ratings and proportions
- Phase 3: Banner analysis and composite metrics
- Excel output with trend indicators
- Question mapping support

**Future Versions:**

**v1.1 (Planned - Q1 2026)**
- Fix known issues (CR-TRACKER-001, CR-TRACKER-002)
- Improve error messages
- Add confidence intervals to output
- 50% test coverage

**v2.0 (Planned - Q2 2026)**
- Phase 4: Automated charting
- HTML output format
- Dashboard integration
- 80% test coverage
- Shared utilities with Tabs module

**v3.0 (Planned - Q3 2026)**
- Phase 5: Seasonality adjustment
- Forecasting capabilities
- Advanced statistical models
- Real-time data integration

---

## Support and Contribution

### Reporting Issues

Include:
1. Tracker version
2. R version and OS
3. Minimal reproducible example
4. Error message and traceback
5. Configuration files (if applicable)

### Feature Requests

Describe:
1. Use case (what problem does it solve?)
2. Proposed solution
3. Alternatives considered
4. Impact (how many users would benefit?)

---

**Document Version:** 1.0
**Last Updated:** 2025-11-18
**Maintainer:** Turas Analytics Team
