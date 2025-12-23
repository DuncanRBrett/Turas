# Turas Tracker - Technical Documentation

**Version:** 10.0
**Last Updated:** 22 December 2025
**Target Audience:** Developers, Technical Contributors, Module Maintainers

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Module Components](#module-components)
3. [API Reference](#api-reference)
4. [Data Structures](#data-structures)
5. [Extension Guide](#extension-guide)
6. [Testing](#testing)
7. [Performance](#performance)
8. [Shared Code Strategy](#shared-code-strategy)
9. [Known Issues](#known-issues)

---

## System Overview

### Technology Stack

**Required R Packages:**
```r
openxlsx  (>= 4.2.5)  # Excel I/O
readxl    (>= 1.4.0)  # Reading Excel configurations
```

**Optional R Packages:**
```r
haven     (>= 2.5.0)  # SPSS .sav support
foreign   (>= 0.8-0)  # Stata .dta support
shiny     (>= 1.7.0)  # GUI interface
shinyFiles (>= 0.9.0) # File selection in GUI
```

### Design Patterns

1. **Pipeline Pattern** - Sequential data processing stages
2. **Strategy Pattern** - Different calculators for different question types
3. **Builder Pattern** - Configuration object construction
4. **Adapter Pattern** - Question mapping adapts different wave structures
5. **Factory Pattern** - Trend calculator selection based on question type

---

## Module Components

### Core Modules (12 files)

#### run_tracker.R (~620 lines)
**Purpose:** Main entry point and orchestration

**Key Function:**
```r
run_tracker(tracking_config_path, question_mapping_path,
            data_dir = NULL, output_path = NULL, use_banners = FALSE)
```

**Responsibilities:**
- Orchestrates entire analysis pipeline
- Error handling and logging
- Progress reporting
- Report type routing
- Timing and performance metrics

#### tracker_config_loader.R (~400 lines)
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

#### wave_loader.R (~500 lines)
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

#### question_mapper.R (~350 lines)
**Purpose:** Map question codes across waves

**Key Functions:**
```r
build_question_map_index(question_mapping, config)
  # Returns: list(standard_to_wave, wave_to_standard, question_metadata)

get_question_metadata(question_map, question_code)
  # Returns: list(QuestionCode, QuestionText, QuestionType, TrackingSpecs, ...)

get_wave_question_code(question_map, std_code, wave_id)
  # Maps standardized code to wave-specific code

extract_question_data(wave_df, wave_id, question_code, question_map)
  # Extracts question data using mapping
```

#### validation_tracker.R (~600 lines)
**Purpose:** Comprehensive validation framework

**Key Functions:**
```r
validate_tracker_setup(config, question_mapping, question_map, wave_data)
  # Master validation function

validate_tracking_specs(specs_str, question_type)
  # Validates TrackingSpecs syntax
```

**Validation Checks:**
- Configuration structure (required sheets, columns)
- Question mapping (tracked questions exist, types valid)
- Wave data (files loadable, weights valid)
- Consistency (sample sizes, naming)

#### trend_calculator.R (~800 lines)
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

**Statistical Testing:**
```r
test_proportion_trend(p1, n1, p2, n2, alpha)  # Z-test
test_mean_trend(mean1, sd1, n1, mean2, sd2, n2, alpha)  # T-test
```

#### banner_trends.R (~400 lines)
**Purpose:** Calculate trends by demographic segments

**Key Functions:**
```r
calculate_trends_with_banners(config, question_map, wave_data)
  # Calculates trends for all segments

get_banner_segments(config, wave_data)
  # Extracts banner segment definitions

filter_wave_data_to_segment(wave_data, segment_def)
  # Filters wave data to specific segment
```

#### tracker_output.R (~500 lines)
**Purpose:** Generate Excel reports

**Key Functions:**
```r
write_tracker_output(trend_results, config, wave_data, output_path, banner_segments)
  # Generates detailed trend report

write_wave_history_output(trend_results, config, wave_data, output_path, banner_segments)
  # Generates wave history report
```

#### tracker_dashboard_reports.R (~800 lines)
**Purpose:** Generate enhanced executive reports

**Key Functions:**
```r
write_dashboard_output(trend_results, config, wave_data, output_path, include_sig_matrices)
  # Generates dashboard with optional sig matrices

write_sig_matrix_output(trend_results, config, wave_data, output_path)
  # Standalone significance matrix report

write_trend_dashboard(wb, trend_results, config, sheet_name)
  # Creates executive summary sheet

write_significance_matrix(wb, q_result, config, wave_ids)
  # Creates per-question significance matrix
```

#### formatting_utils.R (~200 lines)
**Purpose:** Output formatting utilities

**Key Functions:**
```r
format_decimal(value, decimal_places, separator = ".")
format_percentage(value, decimal_places)
format_sample_size(n)
get_decimal_separator(config)
```

#### run_tracker_gui.R (~689 lines)
**Purpose:** Shiny-based GUI interface

**Features:**
- File selection with browse buttons
- Auto-detection of question mapping
- Recent projects functionality
- Banner analysis toggle
- Real-time console output

#### constants.R (Small)
**Purpose:** Centralized constants

**Defines:**
- Default settings
- Valid question types
- Valid TrackingSpecs options
- Error messages

---

## API Reference

### Main Entry Point

```r
run_tracker(
  tracking_config_path,    # Path to tracking_config.xlsx
  question_mapping_path,   # Path to question_mapping.xlsx (or NA)
  data_dir = NULL,         # Directory for relative data file paths
  output_path = NULL,      # Output file path (auto-generated if NULL)
  use_banners = FALSE      # Enable banner analysis
)

# Returns:
#   - Character path (single report type)
#   - Named list (multiple report types): list(detailed = "...", wave_history = "...")
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

# Extract question data
q_data <- extract_question_data(wave_data[["W1"]], "W1", "Q01", question_map)
```

### Trend Calculation Functions

```r
# Calculate all trends
trend_results <- calculate_all_trends(config, question_map, wave_data)

# Calculate with banners
banner_trends <- calculate_trends_with_banners(config, question_map, wave_data)
```

### Output Functions

```r
# Write detailed output
write_tracker_output(trend_results, config, wave_data, "output.xlsx", banner_segments)

# Write wave history output
write_wave_history_output(trend_results, config, wave_data, "wave_history.xlsx", banner_segments)

# Write dashboard output
write_dashboard_output(trend_results, config, wave_data, "dashboard.xlsx", include_sig_matrices = TRUE)
```

---

## Data Structures

### Config Object

```r
list(
  waves = data.frame(
    WaveID, WaveName, DataFile, FieldworkStart, FieldworkEnd, WeightVar
  ),
  settings = list(
    project_name = "...",
    confidence_level = 0.95,
    ...
  ),
  banner = data.frame(
    BreakVariable, BreakLabel
  ),
  tracked_questions = data.frame(
    QuestionCode, QuestionText, QuestionType
  ),
  config_path = "/path/to/config.xlsx"
)
```

### Question Map Object

```r
list(
  standard_to_wave = list(
    Q_SAT = list(W1 = "Q10", W2 = "Q11", W3 = "Q12"),
    ...
  ),
  wave_to_standard = list(
    "W1:Q10" = "Q_SAT",
    "W2:Q11" = "Q_SAT",
    ...
  ),
  question_metadata = data.frame(
    QuestionCode, QuestionText, QuestionType, TrackingSpecs, SourceQuestions
  )
)
```

### Trend Result Structure

```r
list(
  question_code = "Q_SAT",
  question_text = "Overall satisfaction",
  question_type = "Rating",
  metric_type = "mean",
  wave_results = list(
    W1 = list(mean = 7.5, sd = 2.1, n_unweighted = 500, n_weighted = 500, available = TRUE),
    W2 = list(mean = 7.8, sd = 2.0, n_unweighted = 520, n_weighted = 520, available = TRUE),
    ...
  ),
  changes = list(
    W1_to_W2 = list(
      from_wave = "W1", to_wave = "W2",
      from_value = 7.5, to_value = 7.8,
      absolute_change = 0.3, percentage_change = 4.0,
      direction = "up"
    ),
    ...
  ),
  significance = list(
    W1_vs_W2 = list(
      t_stat = 2.15, df = 1018, p_value = 0.032,
      significant = TRUE, alpha = 0.05
    ),
    ...
  )
)
```

---

## Extension Guide

### Adding a New Question Type

**Step 1:** Update normalize_question_type() in trend_calculator.R:
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
    q_data <- extract_question_data(wave_data[[wave_id]], wave_id, q_code, question_map)
    custom_metric <- my_custom_calculation(q_data$values, q_data$weights)
    wave_results[[wave_id]] <- list(
      metric = custom_metric,
      n_unweighted = length(q_data$values),
      available = !is.null(q_data)
    )
  }

  trend_indicators <- calculate_trend_indicators(wave_results, ...)

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

**Step 4:** Add output writer in tracker_output.R

**Step 5:** Add routing in banner_trends.R if needed

### Adding a New Setting

**Step 1:** Document in User Manual

**Step 2:** Use in code:
```r
show_n <- get_setting(config, "show_sample_sizes", default = TRUE)
if (show_n) {
  # Write sample size row
}
```

**Step 3:** Add validation if needed:
```r
if ("show_sample_sizes" %in% names(config$settings)) {
  val <- config$settings$show_sample_sizes
  if (!is.logical(val)) {
    results$warnings <- c(results$warnings, "show_sample_sizes should be Y/N")
  }
}
```

### Adding a New TrackingSpec

**Step 1:** Update parse_tracking_specs() in question_mapper.R

**Step 2:** Update relevant calculator (e.g., calculate_rating_trend_enhanced)

**Step 3:** Update validation in validate_tracking_specs()

**Step 4:** Document in 06_TEMPLATE_REFERENCE.md

---

## Testing

### Test Files

```
tests/regression/
└── test_regression_tracker_dashboard.R  # Dashboard functionality tests
```

### Running Tests

```r
setwd("/path/to/Turas")
source("tests/regression/test_regression_tracker_dashboard.R")
```

### Test Coverage

**Current:** ~15% automated, 85% manual

**Recommended Unit Tests:**
```r
test_that("TrackingSpecs validation catches invalid specs")
test_that("Multi-mention column detection works correctly")
test_that("Top box calculation correct for 1-5 scale")
test_that("Z-test for proportions produces correct p-values")
```

### Manual Testing Checklist

Before each release:
- [ ] Run with existing project configs (backward compatibility)
- [ ] Test each TrackingSpecs combination
- [ ] Test with missing data in some waves
- [ ] Test with very small/large sample sizes
- [ ] Test banner analysis with 1, 3, 5+ segments
- [ ] Test all report formats
- [ ] Test GUI with all features
- [ ] Verify Excel output formatting

---

## Performance

### Expected Execution Times

| Waves | Questions | Segments | Time |
|-------|-----------|----------|------|
| 2 | 2 | Total only | ~1-2 sec |
| 4 | 10 | 3 segments | ~3-5 sec |
| 10 | 50 | 5 segments | ~15-20 sec |

### Scaling

- Linear with number of questions
- Linear with number of waves
- Quadratic with number of banner segments (segments × questions)
- Minimal impact from sample size

### Bottlenecks

**Data Loading:** CSV faster than Excel. Consider data.table::fread() for large files.

**Trend Calculation:** Nested loops. Could parallelize with parallel package.

**Excel Writing:** Auto-width calculation can be slow with many columns.

### Optimization Opportunities

```r
# Parallel processing
library(parallel)
mclapply(questions, calculate_trend, mc.cores = 4)

# Caching
if (!exists("question_map_cache")) {
  question_map_cache <- build_question_map_index(...)
}
```

---

## Shared Code Strategy

### Code Marked for Extraction

Look for comments: `# SHARED CODE NOTE: This should be in /shared/...`

**Files with shared code opportunities:**
1. trend_calculator.R - Significance tests, mean calculations
2. wave_loader.R - Weight calculations
3. tracker_config_loader.R - Config parsing
4. tracker_output.R - Excel styles

### Extraction Priority

**Phase A - High Priority:**
- `/shared/significance_tests.R` - T-tests, Z-tests
- `/shared/weights.R` - Weight efficiency

**Phase B - Post-MVT:**
- `/shared/config_utils.R` - Config parsing
- `/shared/composite_calculator.R` - Composite logic
- `/shared/excel_styles.R` - Excel styles

### Extraction Process

1. Create `/modules/shared/` directory
2. Extract function to shared file
3. Update both Tracker and Tabs to source shared file
4. Run full test suites for both modules
5. Verify identical results
6. Update documentation

---

## Known Issues

### Resolved Issues

**ISSUE-001: Multi_Mention with Selective TrackingSpecs** (v2.1)
- Status: RESOLVED
- Description: `option:Q10_4` caused "missing value where TRUE/FALSE needed"
- Fix: Modified calculate_multi_mention_trend() to parse TrackingSpecs before first pass

**ISSUE-002: Multi_Mention Category Mode Data Loss** (v2.1)
- Status: RESOLVED
- Description: Category mode showed blank values
- Root Cause: Data loader converted sub-columns to numeric
- Fix: Modified wave_loader.R to protect sub-columns from numeric conversion

### Known Limitations

1. **Test Coverage:** ~15% automated
2. **No Confidence Intervals in Wave History:** CIs calculated but not displayed
3. **No Automated Charts:** Users create charts manually
4. **No Seasonality Adjustment:** Important for long-running trackers
5. **Open-End Questions Not Supported:** Must pre-code into categories

---

## Code Style

### Function Documentation

```r
#' Function Title
#'
#' Detailed description.
#'
#' @param param1 Description
#' @param param2 Description
#' @return Description of return value
#'
#' @export
function_name <- function(param1, param2) {
  ...
}
```

### Error Handling

```r
# Validate inputs
if (is.null(values) || length(values) == 0) {
  stop("function_name: values cannot be NULL or empty")
}

# Informative warnings
if (n_boxes > length(unique(values))) {
  warning(paste0("n_boxes exceeds unique values"))
}
```

### Code Organization

```r
# ============================================================================
# SECTION: Top Box Calculations
# ============================================================================

calculate_top_box <- function(...) { }
calculate_bottom_box <- function(...) { }
```

---

## Version Control

### Branch Strategy

- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - Feature branches
- `bugfix/*` - Bug fix branches
- `claude/*` - Claude-assisted development

### Commit Messages

```
feat: Add wave history report format
fix: Resolve Q10 multi-mention TrackingSpecs issue
docs: Update USER_MANUAL with TrackingSpecs examples
test: Add unit tests for top box calculation
refactor: Extract shared validation functions
```

---

## Future Development

### Planned Features

**v3.0:**
- Automated chart generation
- HTML report format
- PowerPoint export
- 80% test coverage

**v3.5:**
- Seasonality adjustment
- Trend forecasting
- Statistical process control (SPC) charts

**v4.0:**
- Real-time data integration
- API endpoints
- Text analysis for open-ends
