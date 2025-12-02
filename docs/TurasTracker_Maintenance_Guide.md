# TurasTracker - Code Maintenance Guide

**Version:** 10.0
**Document Date:** December 2, 2025
**Audience:** Developers and System Maintainers  

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Module Reference](#module-reference)
3. [Data Flow](#data-flow)
4. [Key Functions](#key-functions)
5. [Extension Guide](#extension-guide)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)
8. [Shared Code Strategy](#shared-code-strategy)

---

## Architecture Overview

### Design Principles

**TurasTracker MVT** follows these architectural principles:

1. **Modular Design** - Each module has single responsibility
2. **Separation of Concerns** - Config ≠ Data ≠ Calculation ≠ Output
3. **Reusable Components** - Functions designed for extraction to /shared/
4. **Defensive Coding** - Extensive validation before processing
5. **Clear Data Flow** - Linear progression through analysis stages

### Module Structure

```
/modules/tracker/
├── run_tracker.R              # Main entry point & orchestration
├── tracker_config_loader.R    # Load tracking configuration
├── wave_loader.R              # Load and weight wave data
├── question_mapper.R          # Map questions across waves
├── validation_tracker.R       # Comprehensive validation
├── trend_calculator.R         # Calculate trends & changes
├── banner_trends.R            # Banner breakout trends
├── tracker_output.R           # Excel output generation
└── test_phase[1-3].R          # Test scripts
```

### Dependency Graph

```
run_tracker.R
├─→ tracker_config_loader.R
├─→ wave_loader.R
├─→ question_mapper.R
├─→ validation_tracker.R
│   └─→ question_mapper.R (get_question_metadata)
├─→ trend_calculator.R
│   └─→ question_mapper.R (extract_question_data)
├─→ banner_trends.R
│   └─→ trend_calculator.R (reuses calculation functions)
└─→ tracker_output.R
```

---

## Module Reference

### 1. run_tracker.R

**Purpose:** Main orchestration script

**Key Function:**
```r
run_tracker(tracking_config_path, question_mapping_path, 
            data_dir = NULL, output_path = NULL, use_banners = FALSE)
```

**Workflow:**
1. Load configuration
2. Load question mapping
3. Validate configuration
4. Load wave data
5. Validate wave data
6. Run comprehensive validation
7. Calculate trends (simple or with banners)
8. Write Excel output

**Parameters:**
- `use_banners`: FALSE = Phase 2 (Total only), TRUE = Phase 3 (with banner breakouts)

**Returns:** Path to output Excel file

**Maintenance Notes:**
- Sources all other modules at startup
- No complex logic - delegates to specialized modules
- Error handling wraps entire workflow

---

### 2. tracker_config_loader.R

**Purpose:** Load and parse tracking configuration files

**Key Functions:**

#### load_tracking_config()
```r
load_tracking_config(config_path) → config object
```

**Returns:**
```r
list(
  waves = data.frame,          # Wave definitions
  settings = named list,        # Settings as key-value pairs
  banner = data.frame,          # Banner structure
  tracked_questions = data.frame,  # Questions to track
  config_path = character       # Original path
)
```

#### load_question_mapping()
```r
load_question_mapping(mapping_path) → data.frame
```

**Returns:** Question mapping with columns:
- QuestionCode, QuestionText, QuestionType
- Wave1, Wave2, Wave3, ... (wave-specific codes)
- SourceQuestions (for composites)

#### parse_settings_to_list()
```r
parse_settings_to_list(settings_df) → named list
```

**Logic:**
- Converts Y/N to TRUE/FALSE
- Converts numeric strings to numbers
- Preserves text as-is

**SHARED CODE NOTE:** This function should be extracted to `/shared/config_utils.R` for use with TurasTabs.

---

### 3. wave_loader.R

**Purpose:** Load wave data files and apply weighting

**Key Functions:**

#### load_all_waves()
```r
load_all_waves(config, data_dir = NULL) → named list of data frames
```

**Logic:**
1. Iterate through waves in config
2. Resolve file paths (absolute or relative)
3. Load data (CSV or Excel)
4. Apply weighting
5. Calculate weight efficiency
6. Return named list (WaveID → data frame)

#### apply_wave_weights()
```r
apply_wave_weights(wave_df, weight_var, wave_id) → wave_df with weight_var column
```

**Validates:**
- Weight variable exists
- No NA weights (warns if found)
- No zero/negative weights (warns if found)

**SHARED CODE NOTE:** Weight calculation logic (`calculate_weight_efficiency`) should be extracted to `/shared/weights.R`.

---

### 4. question_mapper.R

**Purpose:** Map questions across waves and build index structures

**Key Functions:**

#### build_question_map_index()
```r
build_question_map_index(question_mapping, config) → question_map
```

**Returns:**
```r
list(
  standard_to_wave = list,     # StandardCode → WaveID → WaveCode
  wave_to_standard = list,     # "WaveID:WaveCode" → StandardCode
  question_metadata = data.frame  # All non-wave columns (includes SourceQuestions)
)
```

**Index Structure:**
```r
# Forward lookup
standard_to_wave$Q_SAT$W1 = "Q10"
standard_to_wave$Q_SAT$W2 = "Q11"

# Reverse lookup
wave_to_standard$"W1:Q10" = "Q_SAT"
wave_to_standard$"W2:Q11" = "Q_SAT"
```

#### get_wave_question_code()
```r
get_wave_question_code(question_map, standard_code, wave_id) → wave_code
```

**Usage:**
```r
# Get Wave 2 code for Q_SAT
wave_code <- get_wave_question_code(q_map, "Q_SAT", "W2")
# Returns: "Q11"
```

#### extract_question_data()
```r
extract_question_data(wave_df, wave_id, standard_code, question_map) → numeric vector
```

**Logic:**
1. Get wave-specific code for question
2. Check if variable exists in data
3. Extract column as vector
4. Return NULL if not found

---

### 5. validation_tracker.R

**Purpose:** Comprehensive validation before analysis

**Key Functions:**

#### validate_tracker_setup()
```r
validate_tracker_setup(config, question_mapping, question_map, wave_data)
→ validation_results
```

**Validates:**
1. Configuration structure (required components exist)
2. Wave definitions (chronological, valid dates)
3. Question mapping (required columns, valid types)
4. Data availability (files loaded, weights valid)
5. Trackable questions (exist in data, mapped correctly)
6. Banner structure (variables exist, sufficient bases)

**Returns:**
```r
list(
  errors = character vector,    # Fatal errors (stop execution)
  warnings = character vector,  # Non-fatal warnings
  info = character vector       # Informational messages
)
```

**Error Handling:**
- Errors → stop execution
- Warnings → display but continue
- Info → progress messages

**Special Handling:**
- Composites skipped in data existence checks (calculated, not in raw data)
- Banner variables checked in first wave (assumes consistent structure)

---

### 6. trend_calculator.R

**Purpose:** Calculate trends, changes, and significance tests

**Key Functions:**

#### calculate_all_trends()
```r
calculate_all_trends(config, question_map, wave_data) → trend_results
```

**Returns:**
```r
list(
  Q_SAT = trend_result,
  Q_NPS = trend_result,
  ...
)
```

#### Trend Result Structure:
```r
list(
  question_code = "Q_SAT",
  question_text = "Overall satisfaction",
  question_type = "Rating",
  metric_type = "mean",  # or "nps", "proportions", "composite"
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
      direction = "up"  # or "down", "stable", "unavailable"
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

#### Question Type Routing:
```r
calculate_all_trends()
├─→ calculate_rating_trend()       # Rating/Index questions
├─→ calculate_nps_trend()          # NPS questions
├─→ calculate_single_choice_trend()  # SingleChoice questions
└─→ calculate_composite_trend()    # Composite questions
```

#### Significance Testing:

**T-Test for Means:**
```r
t_test_for_means(mean1, sd1, n1, mean2, sd2, n2, alpha = 0.05)
```

**Formula:**
```
pooled_variance = ((n1-1)*sd1² + (n2-1)*sd2²) / (n1 + n2 - 2)
SE = pooled_sd * sqrt(1/n1 + 1/n2)
t = (mean2 - mean1) / SE
df = n1 + n2 - 2
p_value = 2 * pt(-abs(t), df)
```

**Z-Test for Proportions:**
```r
z_test_for_proportions(p1, n1, p2, n2, alpha = 0.05)
```

**Formula:**
```
p_pooled = (p1*n1 + p2*n2) / (n1 + n2)
SE = sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))
z = (p2 - p1) / SE
p_value = 2 * pnorm(-abs(z))
```

**SHARED CODE NOTE:** Both test functions should be extracted to `/shared/significance_tests.R`.

---

### 7. banner_trends.R

**Purpose:** Calculate trends with banner segment breakouts

**Key Functions:**

#### calculate_trends_with_banners()
```r
calculate_trends_with_banners(config, question_map, wave_data) → banner_results
```

**Returns:**
```r
list(
  Q_SAT = list(
    Total = trend_result,
    Gender_1 = trend_result,
    Gender_2 = trend_result,
    ...
  ),
  Q_NPS = list(...),
  ...
)
```

**Logic:**
1. Get banner segments from config
2. For each question:
   - For each segment:
     - Filter wave data to segment
     - Calculate trend (reuse Phase 2 functions)
     - Store result
3. Return nested structure (question → segment → trend_result)

#### get_banner_segments()
```r
get_banner_segments(config, wave_data) → list of segment definitions
```

**Returns:**
```r
list(
  Total = list(name = "Total", variable = NULL, is_total = TRUE),
  Gender_1 = list(name = "Gender_1", variable = "Gender", value = 1, is_total = FALSE),
  Gender_2 = list(name = "Gender_2", variable = "Gender", value = 2, is_total = FALSE),
  ...
)
```

**Auto-detection:**
- Reads banner variables from config
- Scans first wave data for unique values
- Creates segment for each value

#### filter_wave_data_to_segment()
```r
filter_wave_data_to_segment(wave_data, segment_def) → filtered_wave_data
```

**Logic:**
- If Total segment: return all data
- If value segment: filter where variable == value
- Returns list of filtered data frames (one per wave)

---

### 8. tracker_output.R

**Purpose:** Generate Excel workbook output

**Key Functions:**

#### write_tracker_output()
```r
write_tracker_output(trend_results, config, wave_data, output_path = NULL, 
                     banner_segments = NULL) → output_file_path
```

**Logic:**
1. Detect result format (simple vs. banner)
2. Create workbook
3. Create styles
4. Write Summary sheet
5. Write trend sheets (format depends on detection)
6. Write Change_Summary sheet (if banners)
7. Write Metadata sheet
8. Save workbook

#### Output Format Detection:
```r
detect_banner_results(trend_results) → logical
```

**Logic:**
- Simple format: `list(question_code = ..., wave_results = ...)`
- Banner format: `list(list(Total = result, Gender_1 = result, ...))`
- Detection: Check if first element has `question_code` at top level

#### Sheet Writers:

**Simple Trends:**
- `write_trend_sheets()` - One column per wave
- Format: Metric | W1 | W2 | W3

**Banner Trends:**
- `write_trend_sheets_with_banners()` - Wave × Segment columns
- Format: Metric | W1_Total | W2_Total | W1_Gender_1 | W2_Gender_1 | ...

**Change Summary:**
- `write_change_summary_sheet()` - Baseline vs. Latest comparison
- Format: Question | Metric | Baseline | Latest | Abs Change | % Change

---

## Data Flow

### Complete Analysis Flow

```
1. CONFIGURATION LOADING
   User provides:
   ├─ tracking_config.xlsx
   └─ question_mapping.xlsx
   
   System loads:
   ├─ Wave definitions
   ├─ Settings
   ├─ Banner structure
   ├─ Tracked questions
   └─ Question mappings

2. VALIDATION (Pre-Flight)
   Checks:
   ├─ Required columns exist
   ├─ No duplicate IDs
   ├─ Dates are valid
   └─ Question types recognized

3. DATA LOADING
   For each wave:
   ├─ Resolve file path
   ├─ Load CSV/Excel
   ├─ Apply weighting
   └─ Calculate efficiency
   
   Result: wave_data list

4. QUESTION MAPPING
   Build index:
   ├─ standard_to_wave (Q_SAT → W1 → Q10)
   ├─ wave_to_standard (W1:Q10 → Q_SAT)
   └─ question_metadata (types, source questions)

5. VALIDATION (Post-Load)
   Checks:
   ├─ All waves loaded
   ├─ Weight variables exist
   ├─ Questions exist in data
   ├─ Banner variables exist
   └─ Sufficient base sizes

6. TREND CALCULATION
   
   Phase 2 (Simple):
   ├─ For each tracked question:
   │  ├─ For each wave:
   │  │  ├─ Extract data
   │  │  ├─ Calculate metric
   │  │  └─ Store result
   │  ├─ Calculate changes
   │  └─ Run sig tests
   
   Phase 3 (Banners):
   ├─ Get banner segments
   ├─ For each tracked question:
   │  ├─ For each segment:
   │  │  ├─ Filter wave data
   │  │  ├─ Calculate trend (Phase 2 logic)
   │  │  └─ Store result
   │  └─ Build nested structure

7. OUTPUT GENERATION
   ├─ Detect format (simple vs. banner)
   ├─ Create workbook
   ├─ Write Summary
   ├─ Write trend sheets (1 per question)
   ├─ Write Change Summary (if banners)
   ├─ Write Metadata
   └─ Save file

8. COMPLETION
   └─ Return output file path
```

---

## Key Functions

### Composite Score Calculation

**Location:** `trend_calculator.R::calculate_composite_score()`

**Algorithm:**
```r
1. Extract data for each source question from wave data
2. Build matrix (rows = respondents, columns = source questions)
3. Calculate row means (composite per respondent)
4. Handle all-NA rows (set to NA)
5. Calculate weighted mean of composite values
6. Return result with SD, n_unweighted, n_weighted
```

**Example:**
```
Respondent | Q_SAT | Q_VALUE | COMP_OVERALL
1          | 8     | 7       | 7.5
2          | 7     | 6       | 6.5
3          | 9     | NA      | 9.0   (uses available)
4          | NA    | NA      | NA    (all missing)
```

**SHARED CODE NOTE:** Should use `/shared/composite_calculator.R::calculate_composite_mean()` (same as TurasTabs).

---

### Weight Efficiency Calculation

**Location:** `wave_loader.R::calculate_weight_efficiency()`

**Formula:**
```
eff_n = (Σ weights)² / Σ (weights²)
```

**Interpretation:**
- Measures "effective" sample size after weighting
- eff_n = n if all weights = 1
- eff_n < n if weights vary (some information loss)
- Typical range: 80-95% of n

**Example:**
```r
weights <- c(1.0, 1.2, 0.8, 1.1, 0.9)
eff_n <- calculate_weight_efficiency(weights)
# n = 5
# eff_n ≈ 4.96 (98% efficiency)
```

---

### Significance Letter Assignment

**Future Enhancement** (not in MVT)

When implemented, will mark differences:
```
         W1  W2  W3
Total    7.5 7.8ᴬ 8.1ᴮ
Male     7.3 7.6 7.9
Female   7.7ᴬ 8.0ᴮ 8.3ᶜ
```

Letters indicate significant differences from previous wave.

---

## Extension Guide

### Adding a New Question Type

**Example:** Add support for Grid questions

**Step 1:** Update `validation_tracker.R`
```r
# Line 219
valid_types <- c("Rating", "SingleChoice", "MultiChoice", "NPS", "Index", 
                 "OpenEnd", "Composite", "Grid")  # Add Grid
```

**Step 2:** Create calculator in `trend_calculator.R`
```r
calculate_grid_trend <- function(q_code, question_map, wave_data, config) {
  # Implementation here
}
```

**Step 3:** Add routing in `calculate_all_trends()`
```r
} else if (q_type == "Grid") {
  calculate_grid_trend(q_code, question_map, wave_data, config)
}
```

**Step 4:** Add routing in `banner_trends.R::calculate_trend_for_segment()`
```r
} else if (q_type == "Grid") {
  calculate_grid_trend(q_code, question_map, wave_data, config)
}
```

**Step 5:** Add output writer in `tracker_output.R`
```r
write_grid_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {
  # Implementation here
}
```

**Step 6:** Test with sample data

---

### Adding a New Setting

**Example:** Add `show_sample_sizes` setting

**Step 1:** Document in User Manual

**Step 2:** Update templates with default value

**Step 3:** Use in code
```r
# In tracker_output.R
show_n <- get_setting(config, "show_sample_sizes", default = TRUE)

if (show_n) {
  # Write sample size row
}
```

**Step 4:** Validate (optional)
```r
# In validation_tracker.R
if ("show_sample_sizes" %in% names(config$settings)) {
  val <- config$settings$show_sample_sizes
  if (!is.logical(val)) {
    results$warnings <- c(results$warnings, "show_sample_sizes should be Y/N")
  }
}
```

---

### Adding Banner Segment Comparison

**Future Enhancement:** Compare segments within waves

**Example Output:**
```
         W1       W2       Male vs Female
         Male  Female  Male  Female  W1    W2
Mean     7.3   7.7     7.6   8.0     -0.4  -0.4
Sig                                  No    Yes
```

**Implementation:**
Would require new functions in `banner_trends.R` and modified output in `tracker_output.R`.

---

## Testing

### Test Suite Structure

```
test_phase1.R  - Foundation testing (config, mapping, data loading)
test_phase2.R  - Trend calculation testing (simple trends)
test_phase3.R  - Banner & composite testing (advanced features)
```

### Running Tests

```r
setwd("/path/to/tracker")
source("test_phase1.R")  # Tests Phase 1 foundation
source("test_phase2.R")  # Tests Phase 2 trends
source("test_phase3.R")  # Tests Phase 3 banners & composites
```

### Test Data

**Synthetic Data:**
- `test_wave1.csv`: 100 records, 2 questions, Gender variable
- `test_wave2.csv`: 120 records, same structure

**Characteristics:**
- Random data (set.seed(42) for reproducibility)
- Q10/Q11: Rating 1-10, mean ~6
- Q25/Q26: NPS 0-10, mixed distribution
- Gender: 1/2 roughly 50/50
- weight: Random 0.8-1.2

### Validation Criteria

**Pass Criteria:**
- 0 errors
- 0 warnings (or only expected warnings)
- Execution time < 5 seconds
- Output file created
- All expected sheets present
- Sample calculations spot-checked

### Unit Testing (Future)

Recommended for shared code extraction:
```r
library(testthat)

test_that("Weight efficiency calculates correctly", {
  weights <- c(1, 1, 1, 1, 1)
  expect_equal(calculate_weight_efficiency(weights), 5)
  
  weights <- c(2, 2, 2, 2, 2)
  expect_equal(calculate_weight_efficiency(weights), 5)
})
```

---

## Troubleshooting

### Common Issues

**Issue:** Trends calculate for 0 segments (composites)

**Debug:**
```r
# Check if SourceQuestions preserved
q_map <- build_question_map_index(mapping, config)
print(names(q_map$question_metadata))  # Should include "SourceQuestions"

# Check specific composite
comp_meta <- q_map$question_metadata[
  q_map$question_metadata$QuestionCode == "COMP_OVERALL", 
]
print(comp_meta$SourceQuestions)  # Should show "Q_SAT,Q_VALUE"
```

**Issue:** Significance tests always "No"

**Possible causes:**
1. Base sizes < minimum_base (default 30)
2. Changes too small relative to variance
3. Alpha level too strict

**Debug:**
```r
# Check base sizes
for (wave_id in names(wave_data)) {
  cat(wave_id, ": n =", nrow(wave_data[[wave_id]]), "\n")
}

# Check alpha setting
cat("Alpha:", get_setting(config, "alpha", default = 0.05), "\n")
```

**Issue:** Banner segments missing

**Debug:**
```r
banner_segs <- get_banner_segments(config, wave_data)
print(names(banner_segs))

# Check data
table(wave_data$W1$Gender)  # Should show counts per value
```

---

## Shared Code Strategy

### Code Marked for Extraction

Throughout the codebase, look for:
```r
# SHARED CODE NOTE: This should be in /shared/...
```

**Files with most shared code opportunities:**
1. `trend_calculator.R` - Significance tests, mean calculations
2. `wave_loader.R` - Weight calculations
3. `tracker_config_loader.R` - Config parsing
4. `tracker_output.R` - Excel styles

### Extraction Priority

**Phase A - Before Production** (Recommended):
- `/shared/significance_tests.R` - T-tests, Z-tests
- `/shared/weights.R` - Weight efficiency

**Phase B - Post-MVT**:
- `/shared/config_utils.R` - Config parsing
- `/shared/composite_calculator.R` - Composite logic
- `/shared/calculations.R` - Mean, proportion calculations
- `/shared/formatting.R` - Number formatting
- `/shared/excel_styles.R` - Excel styles

### Extraction Process

**For each shared module:**

1. **Create `/modules/shared/` directory**
2. **Extract function to shared file**
3. **Update both Tracker and Tabs to source shared file**
4. **Run full test suites for both modules**
5. **Verify identical results**
6. **Update documentation**

**Example - Extract weight efficiency:**

**Before:**
```r
# In tracker/wave_loader.R
calculate_weight_efficiency <- function(weights) { ... }

# In tabs/lib/weights.R
calculate_weight_efficiency <- function(weights) { ... }
```

**After:**
```r
# Create shared/weights.R
calculate_weight_efficiency <- function(weights) { ... }

# In tracker/wave_loader.R
source("../shared/weights.R")

# In tabs/lib/weights.R
source("../../shared/weights.R")
```

---

## Performance Considerations

### Expected Performance

**Typical execution:**
- 2 waves, 2 questions, Total only: ~1-2 seconds
- 4 waves, 10 questions, with 3 banner segments: ~3-5 seconds
- 10 waves, 50 questions, with 5 banner segments: ~15-20 seconds

**Scaling:**
- Linear with number of questions
- Linear with number of waves
- Quadratic with number of banner segments (segments × questions)
- Minimal impact from sample size (weighted calculations are fast)

### Bottlenecks

**Data Loading:**
- CSV reading faster than Excel
- Consider data.table::fread() for very large files

**Trend Calculation:**
- Nested loops (segments × questions × waves)
- Could parallelize with parallel package

**Excel Writing:**
- openxlsx is reasonably fast
- Auto-width calculation can be slow with many columns

### Optimization Opportunities

1. **Parallel Processing:**
```r
library(parallel)
mclapply(questions, calculate_trend, mc.cores = 4)
```

2. **Caching:**
```r
# Cache question_map to avoid rebuilding
if (!exists("question_map_cache")) {
  question_map_cache <- build_question_map_index(...)
}
```

3. **Data Filtering:**
```r
# Filter to tracked questions only before processing
# Reduces memory footprint
```

---

## Code Style and Standards

### Function Documentation

**All exported functions use Roxygen:**
```r
#' Function Title
#'
#' Detailed description of what function does.
#'
#' @param param1 Description of parameter 1
#' @param param2 Description of parameter 2
#' @return Description of return value
#'
#' @export  # or @keywords internal
function_name <- function(param1, param2) {
  ...
}
```

### Error Handling

**User-facing functions:**
```r
tryCatch({
  # Main logic
}, error = function(e) {
  stop(paste0("Descriptive context: ", e$message))
})
```

**Internal functions:**
```r
# Validate inputs
if (missing(param1)) {
  stop("param1 is required")
}

if (!is.numeric(param2)) {
  stop("param2 must be numeric")
}
```

### Validation Pattern

**Three-tier validation:**

1. **Pre-flight** - Before loading data
2. **Post-load** - After data loaded
3. **Runtime** - During calculation

**Return structure:**
```r
list(
  errors = character(),    # Stop execution
  warnings = character(),  # Display but continue
  info = character()       # Progress messages
)
```

---

## Version Control

### Branching Strategy

**main** - Production-ready code
**develop** - Integration branch
**feature/* - New features
**bugfix/* - Bug fixes

### Release Process

1. Complete feature development
2. Test thoroughly
3. Update documentation
4. Merge to develop
5. User acceptance testing
6. Merge to main
7. Tag release

### Version Numbering

**Format:** MVT X.Y.Z
- X = Major version (breaking changes)
- Y = Minor version (new features)
- Z = Patch (bug fixes)

**Current:** MVT 1.0.0

---

## Support and Maintenance

### Logging

**Current:** Console messages only

**Future Enhancement:**
```r
library(log4r)
logger <- create.logger()
info(logger, "Processing Wave W1...")
error(logger, "Failed to load data")
```

### Error Reporting

**For users:**
- Clear, actionable error messages
- Point to relevant documentation
- Suggest solutions when possible

**For developers:**
- Full error messages
- Traceback information
- Data snapshots (sanitized)

---

## Future Enhancements

### Planned Features

1. **Panel Data Support**
   - Track same respondents over time
   - Attrition analysis
   - Individual trajectories

2. **Advanced Significance Testing**
   - Bonferroni correction for multiple comparisons
   - Effect size calculations (Cohen's d)
   - Confidence intervals

3. **Trend Analysis**
   - Linear regression on trend
   - Forecast next wave
   - Identify inflection points

4. **Export Options**
   - CSV export for dashboards
   - JSON export for web apps
   - PowerPoint template population

5. **Visualization**
   - Built-in trend charts
   - Heatmaps for multi-segment trends
   - Automatic insight generation

### Known Limitations

**MVT 1.0:**
- Cross-sectional only (no panel tracking)
- NPS significance uses simple threshold
- No automated commentary generation
- Limited to supported question types

---

**Document Version:** 1.0
**Last Updated:** November 2025
**Status:** Complete - Ready for Production
