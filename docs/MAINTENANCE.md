# TURAS Maintenance Guide

**Version:** 2.0
**Last Updated:** 2025-01-12

Developer reference explaining TURAS architecture, R scripts, and dependencies.

---

## System Architecture

### Directory Structure

```
/Turas/
├─ launch_turas.R          # Main launcher GUI
├─ shared/                 # Shared utilities (NEW in Phase 2)
│  ├─ formatting.R         # Number/Excel formatting
│  ├─ config_utils.R       # Config file reading
│  └─ weights.R            # Weight calculations
├─ modules/
│  ├─ parser/              # Questionnaire parser
│  ├─ tabs/                # Cross-tabulation module
│  └─ tracker/             # Multi-wave tracking
├─ templates/              # Config file templates
├─ tests/                  # Unit and integration tests
└─ docs/                   # Documentation
```

### Module Independence

Each module is **self-contained** and can run independently:
- Parser → generates Survey_Structure.xlsx
- Tabs → uses Survey_Structure.xlsx + data
- Tracker → uses own config + data (no Parser dependency)

**Shared dependencies:**
- All modules use `/shared/` utilities
- Tabs and Tracker share formatting and config loading

---

## SHARED MODULES (Core Utilities)

### shared/formatting.R

**Purpose:** Number formatting for text output and Excel

**Key Functions:**
- `create_excel_number_format(decimal_places, decimal_separator)` - Generates Excel format codes
- `format_number(x, decimal_places, decimal_separator)` - Formats numbers as text strings

**Used By:** Tabs excel_writer.R, Tracker tracker_output.R, Tracker formatting_utils.R

**Important:** Always returns `"0.0"` format code for Excel (comma in Excel format means "divide by 1000")

**Dependencies:** None

---

### shared/config_utils.R

**Purpose:** Configuration file reading and validation

**Key Functions:**
- `read_config_sheet(file_path, sheet_name)` - Reads Excel sheet into dataframe
- `parse_settings_to_list(settings_df)` - Converts settings to named list
- `get_setting(config, setting_name, default)` - Safe setting retrieval
- `validate_required_columns(df, required_cols, context)` - Column validation
- `check_duplicates(df, column, context)` - Duplicate checking
- `validate_date_range(start_date, end_date, context)` - Date validation

**Used By:** Tabs config_loader.R, Tracker tracker_config_loader.R

**Dependencies:** openxlsx

---

### shared/weights.R

**Purpose:** Weighting calculations

**Key Functions:**
- `calculate_weight_efficiency(weights)` - Effective sample size (eff_n)
- `calculate_design_effect(weights)` - Design effect (deff)
- `validate_weights(weights)` - Weight value validation

**Formula:** `eff_n = (sum(weights)^2) / sum(weights^2)`

**Used By:** Tabs weighting.R, Tracker wave_loader.R, Tracker trend_calculator.R

**Dependencies:** None

---

## PARSER MODULE

Parser converts Word questionnaires (.docx) to Survey_Structure.xlsx.

### Entry Points

#### modules/parser/run_parser.R
**Purpose:** Main entry point, launches Shiny GUI

**What it does:**
1. Checks for required packages (shiny, officer, openxlsx, stringr, DT)
2. Sources all lib/ modules
3. Launches Shiny app

**Dependencies:** All parser/lib/*.R files

**Affects:** None (standalone module)

---

### Library Files

#### modules/parser/lib/docx_reader.R
**Purpose:** Reads Word document paragraphs and tables

**Key Functions:**
- `read_docx_content(file_path)` - Extracts text and tables from .docx

**Dependencies:** officer

---

#### modules/parser/lib/text_cleaner.R
**Purpose:** Cleans and normalizes text

**Key Functions:**
- `clean_text(text)` - Removes extra whitespace, special characters
- `normalize_question_code(code)` - Standardizes Q codes

**Dependencies:** stringr

---

#### modules/parser/lib/pattern_parser.R
**Purpose:** Identifies question patterns (Q1, Q2, etc.)

**Key Functions:**
- `detect_question_pattern(line)` - Finds question codes
- `extract_question_code(line)` - Extracts Q code from line

**Dependencies:** stringr

---

#### modules/parser/lib/type_detector.R
**Purpose:** Detects question type (single, multiple, grid, numeric, text)

**Key Functions:**
- `detect_question_type(question_text, response_options)` - Determines type
- `is_grid_question(text)` - Identifies matrix questions

**Dependencies:** None

---

#### modules/parser/lib/bin_detector.R
**Purpose:** Detects bin/grouping patterns in numeric questions

**Key Functions:**
- `detect_bins(response_options)` - Finds numeric ranges
- `parse_bin_range(text)` - Extracts min/max from "18-24"

**Dependencies:** stringr

---

#### modules/parser/lib/structure_parser.R
**Purpose:** Orchestrates parsing logic

**Key Functions:**
- `parse_questionnaire_structure(docx_content)` - Main parser
- `build_structure_table(parsed_questions)` - Creates dataframe

**Dependencies:** All other parser/lib modules

---

#### modules/parser/lib/output_generator.R
**Purpose:** Generates Survey_Structure.xlsx

**Key Functions:**
- `generate_survey_structure(structure_table, output_path)` - Writes Excel

**Dependencies:** openxlsx

**Output Format:**
| QuestionCode | QuestionText | Type | ResponseCode | ResponseText |
|--------------|--------------|------|--------------|--------------|
| Q1 | Age group | Single | 1 | Under 18 |
| Q1 | Age group | Single | 2 | 18-24 |

---

#### modules/parser/lib/parse_orchestrator.R
**Purpose:** Coordinates entire parsing workflow

**Key Functions:**
- `parse_and_generate(docx_path, output_path)` - End-to-end pipeline

**Dependencies:** All parser/lib modules

---

#### modules/parser/shiny_app.R
**Purpose:** Shiny UI and server logic

**Key Functions:**
- `parser_ui()` - UI definition
- `parser_server()` - Server logic

**Dependencies:** shiny, DT, all parser/lib modules

---

## TABS MODULE

Tabs generates weighted cross-tabulation reports.

### Entry Points

#### modules/tabs/run_tabs_gui.R
**Purpose:** Launches Tabs Shiny GUI

**What it does:**
1. Checks packages (shiny, shinyFiles)
2. Sources run_tabs.R
3. Launches GUI for file selection

**Dependencies:** shinyFiles, run_tabs.R

---

#### modules/tabs/run_tabs.R
**Purpose:** Main Tabs analysis orchestrator

**What it does:**
1. Loads config (via config_loader.R)
2. Loads data files
3. Builds banners
4. Processes each question (via question_orchestrator.R)
5. Writes Excel output (via excel_writer.R)

**Key Function:** `run_tabs(config_path, output_path)`

**Dependencies:** All tabs/lib/*.R files

**Affects:** Generates Excel output file

---

### Library Files

#### modules/tabs/lib/config_loader.R
**Purpose:** Loads and validates crosstab config

**Key Functions:**
- `load_crosstab_config(file_path)` - Reads config Excel
- `validate_config(config)` - Validates required settings

**Dependencies:** shared/config_utils.R, openxlsx

**Config Structure:**
```r
config <- list(
  settings = list(project_name, alpha, minimum_base, ...),
  banners = data.frame(BannerID, BannerLabel, Variable, Filter),
  questions = data.frame(QuestionCode, QuestionText, Type),
  data_file = "path/to/data.csv",
  survey_structure = data.frame(...)
)
```

---

#### modules/tabs/lib/banner.R
**Purpose:** Banner segment creation and filtering

**Key Functions:**
- `create_banner_segments(data, banner_config)` - Builds segments
- `apply_filter(data, filter_expr)` - Filters data for segment

**Dependencies:** None

**Returns:** List of filtered dataframes, one per banner segment

---

#### modules/tabs/lib/weighting.R
**Purpose:** Weight application and validation

**Key Functions:**
- `apply_weights(data, weight_var)` - Adds weight column
- `calculate_effective_n(weights)` - Calls shared/weights.R

**Dependencies:** shared/weights.R

---

#### modules/tabs/lib/question_orchestrator.R
**Purpose:** Main question processing coordinator

**Key Functions:**
- `process_all_questions(questions, data, banners, config)` - Processes question list
- `process_question(q_code, q_type, data, banners, config)` - Single question

**What it does:**
1. Gets question metadata from survey structure
2. Dispatches to appropriate processor (standard, composite, numeric, ranking)
3. Collects results

**Dependencies:** question_dispatcher.R, all processor modules

---

#### modules/tabs/lib/question_dispatcher.R
**Purpose:** Routes questions to correct processor

**Key Functions:**
- `dispatch_question(q_code, q_type, data, banners, config)` - Routing logic

**Routes to:**
- Standard processor (single, multiple, grid)
- Composite processor (combined metrics)
- Numeric processor (open numeric)
- Ranking processor (rank ordering)

**Dependencies:** All processor modules

---

#### modules/tabs/lib/standard_processor.R
**Purpose:** Processes standard categorical questions

**Key Functions:**
- `process_standard_question(q_code, data, banners, config)` - Main processor
- `calculate_crosstabs(q_data, segment_data, response_codes)` - Crosstab logic

**What it does:**
1. For each banner segment:
   - Counts responses (weighted)
   - Calculates percentages
   - Runs significance tests (via cell_calculator.R)
2. Builds output table

**Dependencies:** cell_calculator.R, run_crosstabs.R

---

#### modules/tabs/lib/composite_processor.R
**Purpose:** Processes composite/derived metrics

**Key Functions:**
- `process_composite_question(q_code, data, banners, config)` - Main processor
- `calculate_composite_mean(values, weights)` - Mean composite
- `calculate_composite_sum(values, weights)` - Sum composite

**Used for:** Net scores, combined metrics, custom calculations

**Dependencies:** cell_calculator.R

---

#### modules/tabs/lib/numeric_processor.R
**Purpose:** Processes numeric questions (mean, median, std dev)

**Key Functions:**
- `process_numeric_question(q_code, data, banners, config)` - Main processor
- `calculate_numeric_stats(values, weights)` - Stats calculation

**Returns:** Mean, median, std dev, min, max, n

**Dependencies:** cell_calculator.R

---

#### modules/tabs/lib/ranking.R
**Purpose:** Processes ranking questions (rank 1st, 2nd, 3rd)

**Key Functions:**
- `process_ranking_question(q_code, data, banners, config)` - Main processor
- `calculate_rank_distribution(ranks, weights)` - Rank percentages

**Dependencies:** cell_calculator.R

---

#### modules/tabs/lib/cell_calculator.R
**Purpose:** Core calculation engine for individual cells

**Key Functions:**
- `calculate_cell(values, weights, type)` - Single cell calculation
- `calculate_percentage(values, weights, code)` - Weighted %
- `calculate_mean(values, weights)` - Weighted mean

**Used by:** All processor modules

**Dependencies:** None (pure calculation)

---

#### modules/tabs/lib/run_crosstabs.R
**Purpose:** Significance testing across banner segments

**Key Functions:**
- `run_significance_tests(crosstab_results, alpha, min_base)` - Tests all pairs
- `z_test_proportions(p1, n1, p2, n2)` - Z-test for %
- `t_test_means(mean1, sd1, n1, mean2, sd2, n2)` - T-test for means
- `assign_significance_letters(sig_matrix)` - Converts to A/B/C letters

**Dependencies:** None (statistical formulas)

---

#### modules/tabs/lib/banner_indices.R
**Purpose:** Calculates index values (column vs total)

**Key Functions:**
- `calculate_indices(crosstab_results, base_column)` - Index = (Col / Base) * 100

**Used for:** Index columns showing relative performance vs Total

**Dependencies:** None

---

#### modules/tabs/lib/validation.R
**Purpose:** Data and config validation

**Key Functions:**
- `validate_data_structure(data, survey_structure)` - Check columns exist
- `validate_banner_variables(banners, data)` - Check banner vars exist
- `validate_question_codes(questions, data)` - Check Q codes exist

**Dependencies:** None

---

#### modules/tabs/lib/summary_builder.R
**Purpose:** Builds summary tables and metadata sheets

**Key Functions:**
- `build_summary_sheet(results, config)` - Overview of all questions
- `build_metadata_sheet(config)` - Analysis settings documentation

**Dependencies:** None

---

#### modules/tabs/lib/excel_writer.R
**Purpose:** Writes results to formatted Excel workbook

**Key Functions:**
- `write_tabs_excel(results, config, output_path)` - Main writer
- `create_excel_styles(decimal_separator, decimal_places, ...)` - Style definitions
- `write_question_sheet(wb, q_results, styles)` - Individual question sheet

**What it does:**
1. Creates workbook
2. Defines styles (uses shared/formatting.R)
3. Writes one sheet per question
4. Applies formatting and styles
5. Adds summary and metadata sheets
6. Saves workbook

**Dependencies:** shared/formatting.R, openxlsx

**Output:** Formatted Excel workbook with color coding, significance letters, proper number formats

---

#### modules/tabs/lib/shared_functions.R
**Purpose:** Miscellaneous utility functions

**Key Functions:**
- `safe_divide(numerator, denominator, default)` - Division with zero handling
- `format_p_value(p)` - P-value formatting
- `round_with_ties(x, digits)` - Consistent rounding

**Dependencies:** None

---

## TRACKER MODULE

Tracker analyzes trends across multiple survey waves.

### Entry Points

#### modules/tracker/run_tracker_gui.R
**Purpose:** Launches Tracker Shiny GUI

**What it does:**
1. File selection interface
2. Recent projects tracking
3. Launches run_tracker.R

**Dependencies:** shiny, shinyFiles, run_tracker.R

---

#### modules/tracker/run_tracker.R
**Purpose:** Main Tracker analysis orchestrator

**What it does:**
1. Loads tracking config (via tracker_config_loader.R)
2. Loads question mapping (via question_mapper.R)
3. Validates config (via validation_tracker.R)
4. Loads all wave data (via wave_loader.R)
5. Calculates trends (via trend_calculator.R or banner_trends.R)
6. Writes Excel output (via tracker_output.R)

**Key Function:** `run_tracker(tracking_config_path, question_mapping_path, data_dir, output_path, use_banners)`

**Dependencies:** All tracker/*.R files

**Affects:** Generates Excel tracker output

---

### Core Modules

#### modules/tracker/tracker_config_loader.R
**Purpose:** Loads and validates tracking config

**Key Functions:**
- `load_tracking_config(file_path)` - Reads tracking_config.xlsx
- `validate_tracking_config(config)` - Validates waves, settings

**Dependencies:** shared/config_utils.R, openxlsx

**Config Structure:**
```r
config <- list(
  settings = list(project_name, alpha, minimum_base, ...),
  waves = data.frame(WaveID, WaveName, DataFile, FieldworkStart, FieldworkEnd),
  banners = data.frame(BannerID, BannerLabel, Variable, Filter)  # Optional
)
```

---

#### modules/tracker/question_mapper.R
**Purpose:** Maps questions across waves

**Key Functions:**
- `load_question_mapping(file_path)` - Reads question_mapping.xlsx
- `build_question_map_index(mapping, config)` - Builds lookup structure
- `get_question_code_for_wave(q_code, wave_id, mapping)` - Gets wave-specific code

**What it does:**
- Handles questions with different codes across waves (Q5 in W1 → Q6 in W2)
- Maps response codes if they differ across waves
- Stores metric type (mean, nps, proportions, composite)

**Dependencies:** openxlsx

**Mapping Structure:**
```r
question_map <- list(
  "Satisfaction" = list(
    question_text = "Overall satisfaction",
    metric_type = "mean",
    wave_codes = list(W1 = "Q5", W2 = "Q5", W3 = "Q5"),
    response_codes = data.frame(...)  # If responses differ
  )
)
```

---

#### modules/tracker/wave_loader.R
**Purpose:** Loads and validates wave data files

**Key Functions:**
- `load_all_waves(config, data_dir)` - Loads all wave files
- `load_wave_data(wave_id, file_path, config)` - Single wave loader
- `validate_wave_structure(wave_data, wave_id, config)` - Checks columns

**What it does:**
1. Reads CSV/Excel data files
2. Applies weights (via shared/weights.R)
3. Validates required columns exist
4. Returns list of wave dataframes

**Dependencies:** shared/weights.R, openxlsx

---

#### modules/tracker/validation_tracker.R
**Purpose:** Comprehensive validation of tracker setup

**Key Functions:**
- `validate_tracker_setup(config, question_mapping, question_map, wave_data)` - Full validation
- `validate_tracking_config(config, question_mapping)` - Config validation
- `validate_wave_data(wave_data, config, question_mapping)` - Data validation
- `validate_question_mapping(config, question_map, wave_data)` - Mapping validation

**What it does:**
- Checks all wave files exist
- Verifies question codes in data match mapping
- Validates date ranges
- Checks for duplicate wave IDs
- Reports availability of each question in each wave

**Dependencies:** None

**Output:** Validation report with warnings/errors

---

#### modules/tracker/trend_calculator.R
**Purpose:** Calculates trends across waves (no banners)

**Key Functions:**
- `calculate_all_trends(config, question_map, wave_data)` - All questions
- `calculate_question_trend(q_code, q_info, wave_data, config)` - Single question
- `calculate_mean_metric(values, weights)` - Mean calculation
- `calculate_nps_metric(values, weights)` - NPS calculation
- `calculate_proportions_metric(values, weights, response_codes)` - % calculation
- `calculate_wave_over_wave_changes(wave_results, wave_ids)` - Change calculations
- `perform_significance_tests_means(wave_results, wave_ids, config)` - T-tests
- `perform_significance_tests_proportions(wave_results, wave_ids, config)` - Z-tests

**What it does:**
1. For each question:
   - Calculate metric for each wave
   - Calculate wave-over-wave changes (W2-W1, W3-W2, etc.)
   - Run significance tests comparing waves
2. Returns results structure

**Dependencies:** shared/weights.R

**Results Structure:**
```r
trend_results <- list(
  "Satisfaction" = list(
    question_code = "Satisfaction",
    question_text = "Overall satisfaction",
    metric_type = "mean",
    wave_results = list(
      W1 = list(mean = 7.5, sd = 1.2, n_unweighted = 500, available = TRUE),
      W2 = list(mean = 7.8, sd = 1.1, n_unweighted = 520, available = TRUE)
    ),
    changes = list(
      W1_to_W2 = list(absolute_change = 0.3, percentage_change = 4.0, from_wave = "W1", to_wave = "W2")
    ),
    significance = list(
      W1_vs_W2 = list(significant = TRUE, p_value = 0.023)
    )
  )
)
```

---

#### modules/tracker/banner_trends.R
**Purpose:** Calculates trends with banner segment breakouts

**Key Functions:**
- `calculate_trends_with_banners(config, question_map, wave_data)` - All questions, all segments
- `get_banner_segments(config, wave_data)` - Creates segment filters
- `calculate_segment_trends(q_code, q_info, segment_id, segment_data, config)` - Trends for one segment

**What it does:**
1. Creates banner segments (Total, Male, Female, etc.)
2. For each question, for each segment:
   - Calculate trends (same as trend_calculator.R)
3. Returns nested structure: Question → Segment → Trend results

**Dependencies:** trend_calculator.R, shared/weights.R

**Results Structure:**
```r
banner_results <- list(
  "Satisfaction" = list(
    Total = <trend_result>,
    Male = <trend_result>,
    Female = <trend_result>
  )
)
```

---

#### modules/tracker/formatting_utils.R
**Purpose:** Number formatting wrapper (uses shared module)

**Key Functions:**
- `format_number_with_separator(x, decimal_places, decimal_sep)` - Wraps shared/formatting.R
- `apply_number_format_excel(wb, sheet, rows, cols, ...)` - Applies Excel format

**Dependencies:** shared/formatting.R, openxlsx

**Version:** 2.0.0 - Now wraps shared/formatting.R (Phase 2 refactoring)

---

#### modules/tracker/tracker_output.R
**Purpose:** Writes tracker results to Excel

**Key Functions:**
- `write_tracker_output(trend_results, config, wave_data, output_path, banner_segments)` - Main writer
- `create_tracker_styles()` - Style definitions
- `write_summary_sheet(wb, config, wave_data, trend_results, styles)` - Summary
- `write_trend_sheets(wb, trend_results, config, styles)` - One sheet per question (no banners)
- `write_trend_sheets_with_banners(wb, banner_results, config, styles)` - Sheets with banner breakouts
- `write_mean_trend_table(...)` - Table for mean metrics
- `write_nps_trend_table(...)` - Table for NPS metrics
- `write_proportions_trend_table(...)` - Table for proportion metrics
- `write_change_summary_sheet(...)` - Baseline-to-latest changes
- `write_metadata_sheet(...)` - Analysis settings
- `write_banner_trend_table(...)` - Banner segment trends
- `write_distribution_table(...)` - Response distribution (% for each rating value)

**What it does:**
1. Creates Excel workbook
2. Writes Summary sheet (wave overview)
3. Writes one sheet per question with:
   - Trend table (metrics across waves)
   - Wave-over-wave changes
   - Distribution table (for rating questions)
4. If banners: Writes Change_Summary sheet
5. Writes Metadata sheet
6. Applies formatting (uses shared/formatting.R)
7. Saves workbook

**Path Resolution:** Uses `find_turas_root()` function to robustly locate shared modules

**Dependencies:** shared/formatting.R, openxlsx

**Version:** 2.0.0 - Uses shared formatting, robust path resolution (Phase 2)

---

### Test Files

#### modules/tracker/test_phase1.R, test_phase2.R, test_phase3.R
**Purpose:** Phase-specific testing scripts

**Used for:** Development testing, not production

---

#### modules/tracker/create_templates.R
**Purpose:** Generates blank config templates

**Key Functions:**
- `create_tracking_config_template()` - Creates tracking_config_template.xlsx
- `create_question_mapping_template()` - Creates question_mapping_template.xlsx

---

#### modules/tracker/run_ccs_tracking.R
**Purpose:** Project-specific runner (example)

**Note:** Project-specific files like this should not be in main module

---

## KEY DEPENDENCIES MAP

### Shared Module Usage

```
shared/formatting.R
├─ modules/tabs/lib/excel_writer.R
├─ modules/tracker/formatting_utils.R
└─ modules/tracker/tracker_output.R

shared/config_utils.R
├─ modules/tabs/lib/config_loader.R
└─ modules/tracker/tracker_config_loader.R

shared/weights.R
├─ modules/tabs/lib/weighting.R
├─ modules/tracker/wave_loader.R
└─ modules/tracker/trend_calculator.R
```

### Critical Path Resolution

**Files with `find_turas_root()` function:**
- `modules/tabs/lib/excel_writer.R` (lines 19-46)
- `modules/tracker/formatting_utils.R` (lines 12-42)
- `modules/tracker/tracker_output.R` (lines 20-56)

**Purpose:** Robust directory tree search to locate Turas root and shared modules

**Methods:**
1. Check if `TURAS_ROOT` global variable exists
2. Search up from current working directory for `launch_turas.R` or `shared/` + `modules/`
3. Try relative paths `../..`, `../../..`, `../../../..`

---

## TESTING INFRASTRUCTURE

### tests/testthat.R
**Purpose:** Test runner

**How to run:**
```r
testthat::test_dir("tests/testthat")
```

---

### Test Files

**Shared Module Tests:**
- `tests/testthat/test_shared_formatting.R` - 25 tests for formatting.R
- `tests/testthat/test_shared_config.R` - 25 tests for config_utils.R
- `tests/testthat/test_shared_weights.R` - 29 tests for weights.R

**Baseline Tests:**
- `tests/testthat/test_parser_baseline.R` - Parser module
- `tests/testthat/test_tabs_baseline.R` - Tabs module
- `tests/testthat/test_tracker_baseline.R` - Tracker module

**Total:** 113 tests

---

## CRITICAL IMPLEMENTATION DETAILS

### Excel Number Formatting

**CRITICAL:** In Excel format codes, symbols have **fixed meanings**:
- `.` = decimal point (ALWAYS)
- `,` = thousands separator or "divide by 1000" (ALWAYS)

**You cannot change this.** Using `# ##0,0` format causes 8.2 → 8.2÷1000 = 0.0082 → displays as "08"

**Solution:** `shared/formatting.R::create_excel_number_format()` always returns `"0.0"` format. Excel displays with comma decimal if user's locale uses comma.

**Affected Files:**
- `shared/formatting.R` - Fixed in Phase 2
- `modules/tabs/lib/excel_writer.R` - Uses shared module
- `modules/tracker/tracker_output.R` - Uses shared module

---

### Path Resolution

**Problem:** `sys.frame(1)$ofile` fails when:
- Running from Shiny
- Running from different working directory
- Running tests

**Solution:** `find_turas_root()` function with 3 fallback methods

**Implemented in:**
- `modules/tabs/lib/excel_writer.R`
- `modules/tracker/formatting_utils.R`
- `modules/tracker/tracker_output.R`

---

### R Module Caching

**Problem:** After updating .R files, changes don't take effect even after `source()`

**Solution:** Always restart RStudio when:
- Pulling changes from GitHub
- Editing shared modules
- Testing core functionality changes

**Alternative:**
```r
rm(list = ls(all.names = TRUE))
.rs.restartR()  # RStudio only
```

---

## MODIFYING THE SYSTEM

### Adding New Shared Utilities

1. Create file in `/shared/` directory
2. Add roxygen documentation
3. Create test file in `/tests/testthat/test_shared_*.R`
4. Update module files to use shared function
5. Run tests: `testthat::test_dir("tests/testthat")`
6. Update this documentation

---

### Adding New Question Type Processor (Tabs)

1. Create processor file in `modules/tabs/lib/`
2. Implement `process_<type>_question()` function
3. Add dispatch logic in `question_dispatcher.R`
4. Update `question_orchestrator.R` if needed
5. Add tests
6. Update USER_MANUAL.md with new type

---

### Adding New Metric Type (Tracker)

1. Add calculation in `trend_calculator.R`:
   - `calculate_<metric>_metric(values, weights)`
   - `perform_significance_tests_<metric>()`
2. Add table writer in `tracker_output.R`:
   - `write_<metric>_trend_table()`
3. Update `question_mapper.R` to recognize type
4. Add tests
5. Update templates and USER_MANUAL.md

---

### Modifying Excel Output Formatting

**DON'T:** Hardcode format strings in module files
**DO:** Modify `shared/formatting.R` (affects all modules)

**For module-specific styles:**
- Tabs: Edit `excel_writer.R::create_excel_styles()`
- Tracker: Edit `tracker_output.R::create_tracker_styles()`

**For number formats:** Only edit `shared/formatting.R`

---

## COMMON MAINTENANCE TASKS

### Updating Package Dependencies

Edit `run_*.R` files in each module:
```r
required_pkgs <- c("shiny", "openxlsx", "stringr")  # Add new package
```

### Changing Default Settings

Edit template files in `/templates/`:
- `Crosstab_Config_Template.xlsx`
- `modules/tracker/tracking_config_template.xlsx`

### Fixing Bugs in Calculations

1. **Identify affected file** (use this guide)
2. **Write failing test first** (TDD approach)
3. **Fix bug**
4. **Run all tests** to ensure no regressions
5. **Update documentation** if behavior changed

### Performance Optimization

**Bottleneck locations:**
- `cell_calculator.R` - Called for every cell
- `run_crosstabs.R` - Significance testing loops
- `trend_calculator.R` - Wave calculations

**Profile with:**
```r
Rprof("profile.out")
# Run analysis
Rprof(NULL)
summaryRprof("profile.out")
```

---

## VERSION CONTROL

### Branch Strategy

- `main` - Stable production code
- `claude/*` - AI development branches
- `feature/*` - Human development branches

### Commit Guidelines

**Good commits:**
- Fix bug in Excel formatting - comma separator
- Add NPS metric type to tracker
- Update config validation to check for duplicates

**Bad commits:**
- Fixed stuff
- Updates
- WIP

### What to Commit

**YES:**
- All .R files
- Documentation (.md)
- Templates (.xlsx in /templates/)
- Tests

**NO:**
- `.DS_Store`, `.Rhistory`
- Data files
- Output files
- User config files (unless templates)

---

## TROUBLESHOOTING GUIDE

See `/TROUBLESHOOTING.md` for:
- Path resolution issues
- Excel formatting problems
- R module caching
- GitHub sync issues
- Testing problems

---

## GETTING HELP

**Documentation:**
- User Manual: `/docs/USER_MANUAL.md`
- This guide: `/docs/MAINTENANCE.md`
- Troubleshooting: `/TROUBLESHOOTING.md`
- README: `/README.md`

**Code Comments:**
- All functions have roxygen documentation
- Complex logic has inline comments

**Support:**
- Duncan Brett (The Research LampPost)

---

**Last Updated:** 2025-01-12
**Version:** 2.0 (Phase 2 Refactoring Complete)
