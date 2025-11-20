# Technical Documentation: Turas AlchemerParser Module

Developer-focused documentation covering architecture, algorithms, and implementation details.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [File Structure](#file-structure)
3. [Core Algorithms](#core-algorithms)
4. [Data Structures](#data-structures)
5. [Function Reference](#function-reference)
6. [Extension Points](#extension-points)
7. [Testing](#testing)

---

## Architecture Overview

### Design Philosophy

AlchemerParser follows Turas module conventions:
- **Modular:** Separated into numbered R files by responsibility
- **Configurable:** Works with diverse survey structures
- **Defensive:** Validates inputs and flags ambiguities
- **Lean:** Minimal dependencies, efficient processing

### Processing Pipeline

```
Input Files
    ↓
Parse Data Export Map → Group by Q Number → Detect Grid Types
    ↓
Parse Translation → Extract Options → Match by Q ID
    ↓
Parse Word Doc → Extract Type Hints → Match by Q Number
    ↓
Classify Questions → Apply Detection Hierarchy → Assign Types
    ↓
Generate Codes → Pad Numbers → Handle Grids/Multi-Column
    ↓
Validate → Flag Issues → Return Summary
    ↓
Generate Outputs → Crosstab Config → Survey Structure → Data Headers
```

### Key Design Decisions

**1. Hierarchical Type Detection**
- Order matters: NPS checked before Likert before Rating
- Prevents mis-classification of similar scales
- Explicit precedence rules documented in specification

**2. Grid Pivoting**
- Checkbox grids pivoted by rows (each row becomes a question)
- Radio grids split by rows (each row is a separate Single_Mention)
- Star rating grids split by items (each item is a separate Rating)

**3. Multi-Source Reconciliation**
- Data export map = source of truth for structure
- Translation export = source of truth for labels
- Word doc = source of hints for ambiguous cases
- Conflicts flagged for manual review

---

## File Structure

### Core R Functions

```
R/
├── 00_main.R                  # Orchestration & entry point
├── 01_parse_data_map.R        # Parse Alchemer data export mapping
├── 02_parse_translation.R     # Parse Alchemer translation file
├── 03_parse_word_doc.R        # Parse Word questionnaire
├── 04_classify_questions.R    # Question type detection & grid handling
├── 05_generate_codes.R        # Question code generation & validation
└── 06_output.R                # Output file generation
```

### Responsibility Boundaries

| File | Responsibility | Key Functions |
|------|----------------|---------------|
| 00_main.R | Orchestrates full pipeline, manages flow | `run_alchemerparser()`, `locate_input_files()` |
| 01_parse_data_map.R | Reads Excel, parses headers, groups columns | `parse_data_export_map()`, `parse_column_header()` |
| 02_parse_translation.R | Reads translation, extracts Q/O text | `parse_translation_export()`, `get_options_for_question()` |
| 03_parse_word_doc.R | Reads Word doc, extracts type hints | `parse_word_questionnaire()`, `get_hint_for_question()` |
| 04_classify_questions.R | Applies detection rules, handles grids | `classify_questions()`, `classify_variable_type()` |
| 05_generate_codes.R | Generates codes, validates parsing | `generate_question_codes()`, `validate_parsing()` |
| 06_output.R | Creates 3 output Excel/CSV files | `generate_output_files()`, `generate_crosstab_config()` |

---

## Core Algorithms

### Algorithm 1: Parse Column Header

**Purpose:** Extracts structured information from data export map column headers

**Input:** Header text (e.g., "4: play in rainy:Do you like to play golf in the following conditions?")

**Output:** Parsed column object

```r
{
  col_index: 5
  q_num: "4"
  q_id: "6"
  structure: "grid_or_multi"
  question_text: "Do you like to play golf in the following conditions?"
  row_label: "play in rainy"
  col_label: NA
}
```

**Logic:**
1. Extract leading number before first colon → Q Number
2. Split by colons
3. If 2 parts: Simple question
4. If 3 parts: Grid or multi-mention (middle part = row/option)
5. If 4 parts: Checkbox grid (part 2 = column, part 3 = row)

**Edge Cases:**
- Handles extra colons in question text
- Trims whitespace
- Falls back to "simple" for unexpected formats

### Algorithm 2: Detect Grid Type

**Purpose:** Classifies multi-column questions as grid types

**Input:** Question group with multiple columns

**Output:** Grid type classification

**Decision Tree:**
```
IF all columns have structure = "checkbox_grid"
  → CHECKBOX_GRID

ELSE IF multiple unique row_labels
  IF all row_labels are purely numeric (1,2,3,4,5)
    → STAR_RATING_GRID
  ELSE
    → RADIO_GRID

ELSE
  → MULTI_COLUMN (Multi-Mention or Ranking)
```

**Example:**
```r
# Checkbox grid: Different row labels + col labels
Columns:
  9: breakfast:eggs:question → row="eggs", col="breakfast"
  9: lunch:eggs:question → row="eggs", col="lunch"
  9: breakfast:burgers:question → row="burgers", col="breakfast"

Unique rows: ["eggs", "burgers"]
Unique cols: ["breakfast", "lunch"]
→ CHECKBOX_GRID

# Radio grid: Different row labels, no col labels
Columns:
  2: Tees:question → row="Tees"
  2: greens:question → row="greens"
  2: fairways:question → row="fairways"

Unique rows: ["Tees", "greens", "fairways"]
All non-numeric
→ RADIO_GRID

# Star rating: Row labels are "item:number"
Columns:
  13: kelvin:1:question → row="kelvin:1"
  13: kelvin:2:question → row="kelvin:2"
  13: Mowbray:1:question → row="Mowbray:1"

Extract items: ["kelvin", "Mowbray"]
Numbers: [1, 2]
→ STAR_RATING_GRID
```

### Algorithm 3: Classify Variable Type

**Purpose:** Determines question type using hierarchical rules

**Input:**
- Question group (columns, text, etc.)
- Options from translation
- Hints from Word doc

**Output:** Variable_Type string

**Detection Hierarchy:**
```r
1. NPS
   - 11 options (0-10)
   - Question contains "recommend"

2. Likert
   - Options contain: disagree, neutral, agree, strongly

3. Rating
   - 5/7/10/11 options
   - Options contain: satisfied, poor, excellent, quality, likely
   - **OR** ≥50% of options are numeric (0-10, 1-5, etc.)

4. Numeric (from Word hints)
   - Type = "slider" or "numeric"

5. Open_End (from Word hints)
   - Type = "textbox"

6. Ranking (**checked BEFORE grid detection**)
   - Text contains "ranking question", "most to least", "least to most"
   - OR Text contains "rank", "ranking", "prioritize" (word boundaries)
   - Multiple columns
   - **Note:** "multi mention" in text takes precedence

7. Multi_Mention
   - Text contains "(multi mention" or "select all" (takes precedence)
   - OR Word hint brackets = "[]"
   - OR multiple columns with different row_labels

8. Numeric Rating Scale Detection
   - If ≥50% of options can be converted to numbers → Rating
   - Checked before Single_Mention default

9. Single_Mention (default)
   - Word hint brackets = "()"
   - OR has options but not classified above

10. Open_End (fallback)
    - No options and not classified above
```

**Example:**
```r
# NPS Detection
options: ["0", "1", "2", ..., "10"] (11 options)
question_text: "How likely are you to recommend..."
→ NPS

# Likert Detection
options: ["Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"]
Contains "disagree", "neutral", "agree"
→ Likert

# Multi-Mention Detection
word_hint$brackets: "[]"
→ Multi_Mention
```

### Algorithm 4: Grid Options Finding

**Purpose:** Locate options for grid questions despite inconsistent Alchemer storage patterns

**Problem:** Alchemer stores grid options at varying offsets from base question ID across different surveys

**Solution:** Multi-strategy search with fallbacks

**Logic:**
```r
find_grid_options(base_id, expected_last_qid, translation_data):
  1. Try expected_last_qid (base_id + num_rows) - most common
  2. If not found, try base_id itself
  3. If still not found, search range [expected-2 to expected+10]
  4. If still nothing, look for shared 0-10 rating scale in translation
  5. Return empty list if all strategies fail
```

**Real Examples:**
- **Helderberg Q6**: base=9, rows=4, expected=13, **actual=23** (found by range search)
- **Helderberg Q65**: base=255, rows=3, expected=258, **actual=260** (found by range search)
- **CCPB Q6**: No options in translation, **fallback to shared 0-10 scale** (found by strategy 4)

**Row Order Preservation:**
- Grid rows use `unique()` on row_labels which preserves original data order
- **NO sorting applied** - rows appear in data export map order

### Algorithm 5: Generate Question Codes

**Purpose:** Creates standardized question codes

**Logic:**
1. Determine padding: `n_questions < 100 ? 2 : 3`
2. For each question:
   - **Simple:** Q01
   - **Grid:** Q02a, Q02b, Q02c (letter suffix per row/item)
   - **Multi-Mention:** Q04_1, Q04_2, Q04_3 (number suffix per option)
   - **Ranking:** Q12_1, Q12_2, Q12_3 (number suffix per position)
3. Detect "other" fields → rename to Q##_othermention or Q##_#othertext

**Other Field Detection:**
Patterns matched (case-insensitive):
- "other.*text"
- "other.*write.*in"
- "other.*specify"
- "other.*enter"
- "other.*required"
- Duplicate row_label (indicates text field for previous "other" checkbox)

---

## Data Structures

### Question Group (from parse_data_export_map)

```r
{
  q_num: "4"                      # Question number (character)
  q_id: "6"                       # Question ID from Alchemer
  question_text: "..."            # Question text from header
  columns: [...]                  # List of column objects
  structure: "grid_or_multi"      # Column structure type
}
```

### Classified Question (from classify_questions)

**Non-Grid:**
```r
{
  q_num: "1"
  q_id: "2"
  question_text: "What is your gender?"
  variable_type: "Single_Mention"
  grid_type: "single"
  n_columns: 1
  columns: [...]
  options: [...]                  # From translation
  hints: {...}                    # From Word doc
  is_grid: FALSE
  q_code: "Q01"                   # Generated code
}
```

**Grid:**
```r
{
  q_num: "2"
  q_id: "3"
  grid_type: "radio_grid"
  sub_questions: {
    a: {
      suffix: "a"
      row_label: "Tees"
      question_text: "..."
      variable_type: "Single_Mention"
      n_columns: 1
      options: [...]
      q_code: "Q02a"
    },
    b: {...},
    c: {...}
  }
  is_grid: TRUE
}
```

### Translation Data

```r
{
  questions: {
    "2": "What is your gender?",
    "3": "Rate the following:",
    ...
  }
  options: {
    "2": [
      {code: "10001", text: "Male", key: "q-2-o-10001"},
      {code: "10002", text: "Female", key: "q-2-o-10002"},
      ...
    ],
    ...
  }
  n_questions: 50
  n_options: 342
  raw_data: <data.frame>
}
```

### Word Hints

```r
{
  "1": {
    question_text: "What is your gender?"
    brackets: "()"
    type: NA
    has_rank_keyword: FALSE
    full_text: "1) What is your gender? ( ) Male ( ) Female"
  },
  "4": {
    question_text: "Which weather do you play in?"
    brackets: "[]"
    type: NA
    has_rank_keyword: FALSE
    full_text: "4) Which weather do you play in? [ ] Sunny [ ] Rainy"
  },
  ...
}
```

---

## Function Reference

### Main Entry Point

#### `run_alchemerparser()`

**Parameters:**
- `project_dir`: Directory containing input files
- `project_name`: Optional project name (auto-detected if NULL)
- `output_dir`: Optional output directory (defaults to project_dir)
- `verbose`: Print progress (default TRUE)

**Returns:**
- `questions`: Parsed question structure
- `validation_flags`: List of issues
- `outputs`: Paths to generated files
- `summary`: Summary statistics

**Side Effects:**
- Writes 3 output files to disk
- Prints progress if verbose=TRUE

### File Parsing Functions

#### `parse_data_export_map(file_path, verbose)`

Reads Excel file, parses headers, groups columns.

**Returns:**
- `questions`: Named list of question groups
- `n_columns`: Total columns parsed
- `raw_data`: First 2 rows of Excel

#### `parse_translation_export(file_path, verbose)`

Reads translation Excel, extracts question/option texts.

**Returns:**
- `questions`: Named list of question texts by Q ID
- `options`: Named list of option lists by Q ID
- `n_questions`, `n_options`: Counts
- `raw_data`: Full translation data frame

#### `parse_word_questionnaire(file_path, verbose)`

Reads Word document, extracts type hints.

**Returns:** Named list of hints by question number

### Classification Functions

#### `classify_questions(questions, translation_data, word_hints, verbose)`

Classifies all questions, handles grids.

**Returns:** List of classified questions

#### `classify_variable_type(question, options, hints, verbose)`

Classifies a single question using detection hierarchy.

**Returns:** Variable type string

### Code Generation Functions

#### `generate_question_codes(questions, verbose)`

Generates codes for all questions.

**Side Effects:** Modifies questions list in place (adds q_code, q_codes)

#### `validate_parsing(questions, translation_data, word_hints, verbose)`

Validates parsing results, flags issues.

**Returns:**
- `flags`: List of validation flag objects

### Output Functions

#### `generate_output_files(questions, project_name, output_dir, validation_flags, verbose)`

Creates all 3 output files.

**Returns:** List of file paths

#### `generate_crosstab_config(questions)`

Creates Crosstab_Config Selection sheet data.

**Returns:** Data frame

#### `generate_survey_structure(questions)`

Creates Survey_Structure Questions and Options sheets.

**Returns:**
- `questions`: Data frame
- `options`: Data frame

#### `generate_data_headers(questions)`

Creates Data_Headers row.

**Returns:** Single-row data frame

---

## Extension Points

### Adding New Question Types

To add a new variable type (e.g., "Slider_Range"):

1. **Update Detection Logic** (R/04_classify_questions.R)

```r
classify_variable_type <- function(question, options, hints, verbose) {
  # ... existing checks ...

  # Add new type check
  if (!is.na(hints$type) && hints$type == "slider_range") {
    return("Slider_Range")
  }

  # ... remaining checks ...
}
```

2. **Update Output Generation** (R/06_output.R)

```r
create_crosstab_row <- function(q_code, q_text, var_type) {
  # Add to index creation logic if needed
  create_index <- if (var_type %in% c("NPS", "Rating", "Likert", "Slider_Range")) "Y" else "N"

  # ... rest of function ...
}
```

### Adding New Grid Types

To handle a new grid structure:

1. **Update Grid Detection** (R/01_parse_data_map.R)

```r
detect_grid_type <- function(question_group) {
  # ... existing checks ...

  # Add new grid type check
  if (custom_grid_condition) {
    return("custom_grid")
  }

  # ... rest of function ...
}
```

2. **Add Pivot Function** (R/04_classify_questions.R)

```r
pivot_custom_grid <- function(question, options, hints) {
  # Custom logic to create sub-questions
  # Return list of sub-question objects
}
```

3. **Update Classification** (R/04_classify_questions.R)

```r
classify_questions <- function(...) {
  # ... existing code ...

  if (grid_type == "custom_grid") {
    sub_qs <- pivot_custom_grid(q, options, hints)
    # ... handle sub-questions ...
  }

  # ... rest of function ...
}
```

### Adding Validation Rules

To add a new validation check:

1. **Update Validation Function** (R/05_generate_codes.R)

```r
validate_parsing <- function(questions, translation_data, word_hints, verbose) {
  flags <- list()

  # ... existing checks ...

  # Add new check
  for (q_num in names(questions)) {
    q <- questions[[q_num]]

    if (custom_validation_condition) {
      flags[[length(flags) + 1]] <- list(
        q_num = q_num,
        q_code = q$q_code,
        issue = "CUSTOM_ISSUE",
        severity = "WARNING",
        details = "Description of issue"
      )
    }
  }

  return(list(flags = flags))
}
```

---

## Testing

### Unit Testing Strategy

Each R file should have corresponding tests in `tests/testthat/test_alchemerparser_*.R`

**Test Structure:**
```r
source("modules/AlchemerParser/R/01_parse_data_map.R")

test_that("parse_column_header handles simple questions", {
  result <- parse_column_header("1: What is your gender?", "2:", 1)

  expect_equal(result$q_num, "1")
  expect_equal(result$q_id, "2")
  expect_equal(result$structure, "simple")
})

test_that("parse_column_header handles grid questions", {
  result <- parse_column_header("2: Tees:Rate satisfaction", "3:", 1)

  expect_equal(result$structure, "grid_or_multi")
  expect_equal(result$row_label, "Tees")
})
```

### Integration Testing

**Test with Sample Data:**
1. Use provided sample files in `modules/AlchemerParser/`
2. Run full pipeline: `run_alchemerparser()`
3. Verify outputs match expected structure
4. Check validation flags

**Golden Master Test:**
```r
# Run parser on sample data
result <- run_alchemerparser(
  project_dir = "modules/AlchemerParser",
  project_name = "sample",
  verbose = FALSE
)

# Compare against baseline
expect_equal(result$summary$n_questions, 13)  # Expected question count
expect_equal(result$summary$n_flags, 0)  # Expected no flags
```

### Manual Testing Checklist

- [ ] Simple questions (Single_Mention, Open_End, Numeric)
- [ ] Scale questions (NPS, Likert, Rating)
- [ ] Multi-column questions (Multi_Mention, Ranking)
- [ ] Radio button grids
- [ ] Checkbox grids
- [ ] Star rating grids
- [ ] Questions with "other" fields
- [ ] Questions with DK/NA options
- [ ] Mixed question types in one survey
- [ ] Large surveys (100+ questions)

---

## Performance Considerations

### Typical Performance

- **Small survey (20 questions):** < 5 seconds
- **Medium survey (50 questions):** < 10 seconds
- **Large survey (100+ questions):** < 30 seconds

### Bottlenecks

1. **Word document parsing** (officer package) - slowest step
2. **Excel reading** (readxl) - moderate
3. **Classification logic** - fast

### Optimization Opportunities

- Cache Word doc parsing results
- Parallel processing for multiple surveys
- Pre-compile regex patterns

---

## Dependencies

### Required Packages

| Package | Version | Purpose |
|---------|---------|---------|
| readxl | ≥ 1.0 | Read Excel files (data map, translation) |
| openxlsx | ≥ 4.0 | Write Excel output files |
| officer | ≥ 0.3 | Read Word questionnaire documents |
| shiny | ≥ 1.5 | GUI interface (optional) |

### Base R Functions Used

- String manipulation: `gsub()`, `grep()`, `regexpr()`, `strsplit()`
- List operations: `lapply()`, `sapply()`, `Filter()`
- Data frames: `rbind()`, `do.call()`
- File I/O: `file.exists()`, `list.files()`

---

## Code Style

Follows Turas conventions:
- **Roxygen documentation** for all exported functions
- **Snake_case** for function names
- **Descriptive variable names**
- **Commented sections** with `# ===` separators
- **Error messages** with `call. = FALSE` for user-facing errors
- **Progress messages** with `cat()` when `verbose = TRUE`

---

**Version:** 1.0
**Last Updated:** 2025-11-20
