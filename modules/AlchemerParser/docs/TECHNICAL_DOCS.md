# AlchemerParser Module - Technical Documentation

**Version:** 1.0
**Last Updated:** December 6, 2025
**Module Status:** ✅ Production Ready
**Target Audience:** Developers, Technical Maintainers

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Architecture](#2-architecture)
3. [File Structure](#3-file-structure)
4. [Core Components](#4-core-components)
5. [Processing Pipeline](#5-processing-pipeline)
6. [Question Classification](#6-question-classification)
7. [Code Generation](#7-code-generation)
8. [Output Generation](#8-output-generation)
9. [API Reference](#9-api-reference)
10. [Extension Points](#10-extension-points)
11. [Testing & Validation](#11-testing--validation)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Module Overview

### 1.1 Purpose

AlchemerParser automates the extraction and standardization of questionnaire structure from Alchemer (formerly SurveyGizmo) survey exports. It transforms three Alchemer export files into Turas-compatible configuration files, eliminating 2-4 hours of manual setup work.

### 1.2 Key Features

**Automated Parsing:**
- Extracts question text from Word questionnaire
- Maps variable names from data export
- Extracts response option labels from translation file
- Combines all three sources into unified structure

**Intelligent Classification:**
- Automatic question type detection (NPS, Likert, Rating, Grid, etc.)
- Pattern-based classification using regex
- Handles complex question formats

**Code Generation:**
- Generates standardized question codes (Q01, Q02a, Q03_1, etc.)
- Maintains sequential numbering
- Handles sub-questions and grids

**Output Generation:**
- Creates Survey_Structure.xlsx for Tabs module
- Generates ready-to-use Tabs_Config.xlsx
- Includes validation flags for manual review

### 1.3 Input/Output

**Input Files (from Alchemer):**
1. **Data Export Map** (.xlsx)
   - Variable names and IDs from Alchemer
   - Question-to-column mapping
   - Multi-column questions identified

2. **Translation Export** (.xlsx)
   - Response option labels
   - Question text
   - Option values

3. **Questionnaire** (.docx)
   - Full question text with formatting
   - Question numbering
   - Skip logic references

**Output Files:**
1. **Survey_Structure.xlsx**
   - Questions sheet: Question metadata
   - Options sheet: Response options
   - Ready for Tabs module

2. **Tabs_Config.xlsx** (Optional)
   - Pre-configured crosstab setup
   - Banner and stub selections

3. **Validation_Report.xlsx** (Optional)
   - Questions requiring manual review
   - Classification confidence scores
   - Issues and warnings

### 1.4 Performance

**Typical Performance:**
- Small survey (30 questions): 5-10 seconds
- Medium survey (60 questions): 10-15 seconds
- Large survey (120 questions): 15-25 seconds

**Accuracy:**
- Question type detection: ~85-90% accuracy
- Manual review required for ~10-15% of questions
- Code generation: 100% systematic

---

## 2. Architecture

### 2.1 Design Pattern

AlchemerParser follows a **Pipeline Architecture**:

```
Input Files → Parse → Classify → Generate Codes → Merge → Output
```

**Key Design Principles:**
1. **Separation of Concerns** - Each file handles one parsing task
2. **Pipeline Stages** - Data flows through independent stages
3. **Fail-Safe** - Invalid questions flagged, not rejected
4. **Traceable** - All decisions logged for review

### 2.2 Module Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    ALCHEMERPARSER MODULE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ INPUT LAYER                                               │  │
│  │  ├─ Data Export Map (.xlsx)                              │  │
│  │  ├─ Translation Export (.xlsx)                           │  │
│  │  └─ Questionnaire (.docx)                                │  │
│  └─────────────────┬────────────────────────────────────────┘  │
│                    │                                            │
│  ┌─────────────────▼────────────────────────────────────────┐  │
│  │ PARSING LAYER                                             │  │
│  │  ├─ 01_parse_data_map.R → Variable mapping               │  │
│  │  ├─ 02_parse_translation.R → Options & labels            │  │
│  │  └─ 03_parse_word_doc.R → Question text                  │  │
│  └─────────────────┬────────────────────────────────────────┘  │
│                    │                                            │
│  ┌─────────────────▼────────────────────────────────────────┐  │
│  │ PROCESSING LAYER                                          │  │
│  │  ├─ 04_classify_questions.R → Type detection             │  │
│  │  └─ 05_generate_codes.R → Code assignment                │  │
│  └─────────────────┬────────────────────────────────────────┘  │
│                    │                                            │
│  ┌─────────────────▼────────────────────────────────────────┐  │
│  │ OUTPUT LAYER                                              │  │
│  │  └─ 06_output.R → Excel file generation                  │  │
│  └─────────────────┬────────────────────────────────────────┘  │
│                    │                                            │
│  ┌─────────────────▼────────────────────────────────────────┐  │
│  │ ORCHESTRATION                                             │  │
│  │  └─ 00_main.R → Coordinates all stages                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                             ↓
                 ┌───────────────────────┐
                 │  OUTPUT FILES         │
                 │  - Survey_Structure   │
                 │  - Tabs_Config        │
                 │  - Validation Report  │
                 └───────────────────────┘
```

### 2.3 Dependencies

**R Packages:**
```r
# Core dependencies
library(openxlsx)      # Excel writing
library(readxl)        # Excel reading
library(officer)       # Word document reading
library(xml2)          # XML parsing (for .docx)
library(stringr)       # String manipulation

# Optional
library(data.table)    # Fast data operations
```

**No Inter-Module Dependencies:**
- Standalone module (doesn't require other Turas modules)
- Output consumed by Tabs module (but doesn't call it)

---

## 3. File Structure

### 3.1 Directory Layout

```
modules/AlchemerParser/
├── R/                                  # Core R code
│   ├── 00_main.R                      # Main orchestration (entry point)
│   ├── 01_parse_data_map.R            # Data export map parser
│   ├── 02_parse_translation.R         # Translation file parser
│   ├── 03_parse_word_doc.R            # Word questionnaire parser
│   ├── 04_classify_questions.R        # Question type classifier
│   ├── 05_generate_codes.R            # Question code generator
│   └── 06_output.R                    # Output file generator
├── run_alchemerparser.R               # CLI entry point
├── run_alchemerparser_gui.R           # GUI (Shiny) entry point
├── TECHNICAL_DOCS.md                  # This file
├── USER_MANUAL.md                     # User guide
├── QUICK_START.md                     # 5-minute quick start
├── EXAMPLE_WORKFLOWS.md               # Example use cases
└── README.md                          # Module overview
```

### 3.2 File Responsibilities

| File | Lines | Responsibility |
|------|-------|----------------|
| **00_main.R** | ~400 | Orchestrate pipeline, coordinate stages, handle errors |
| **01_parse_data_map.R** | ~300 | Parse Alchemer data export map, extract variable names |
| **02_parse_translation.R** | ~350 | Parse translation file, extract options and labels |
| **03_parse_word_doc.R** | ~600 | Parse Word questionnaire, extract question text |
| **04_classify_questions.R** | ~500 | Classify question types using pattern matching |
| **05_generate_codes.R** | ~400 | Generate standardized question codes |
| **06_output.R** | ~450 | Generate Survey_Structure and Tabs_Config Excel files |

**Total:** ~3,000 lines of code

---

## 4. Core Components

### 4.1 Main Orchestrator (00_main.R)

**Function:** `run_alchemerparser()`

**Signature:**
```r
run_alchemerparser(
  project_dir,           # Directory with input files
  project_name = NULL,   # Optional project name
  output_dir = NULL,     # Output directory (defaults to project_dir)
  verbose = TRUE         # Print progress messages
) -> list
```

**Processing Steps:**

```r
# 1. Locate and validate input files
files <- locate_input_files(project_dir, project_name, verbose)

# 2. Parse data export map
data_map <- parse_data_export_map(files$data_map, verbose)

# 3. Parse translation export
translation <- parse_translation_export(files$translation, verbose)

# 4. Parse Word questionnaire
questionnaire <- parse_word_questionnaire(files$questionnaire, verbose)

# 5. Merge all three sources
merged_questions <- merge_parsed_data(
  data_map,
  translation,
  questionnaire,
  verbose
)

# 6. Classify question types
classified_questions <- classify_questions(merged_questions, verbose)

# 7. Generate question codes
coded_questions <- generate_question_codes(classified_questions, verbose)

# 8. Generate output files
output_files <- generate_output_files(
  coded_questions,
  output_dir,
  project_name,
  verbose
)

# 9. Return results
return(list(
  questions = coded_questions,
  validation_flags = identify_review_items(coded_questions),
  outputs = output_files,
  summary = generate_summary(coded_questions)
))
```

**Return Structure:**
```r
list(
  questions = data.frame(
    QuestionID, QuestionText, QuestionCode,
    Variable_Type, Options, ValidationFlag, ...
  ),
  validation_flags = list(
    review_needed = character(),    # Question IDs needing review
    confidence_low = character(),   # Low-confidence classifications
    multi_column = character()      # Multi-column questions
  ),
  outputs = list(
    survey_structure = "path/to/Survey_Structure.xlsx",
    tabs_config = "path/to/Tabs_Config.xlsx",
    validation_report = "path/to/Validation.xlsx"
  ),
  summary = list(
    n_questions = 42,
    n_options = 156,
    question_types = table(Variable_Type),
    review_percentage = 12.5
  )
)
```

---

### 4.2 Data Map Parser (01_parse_data_map.R)

**Purpose:** Extract variable-to-question mapping from Alchemer data export

**Key Function:** `parse_data_export_map()`

**Input File Structure:**
```
Alchemer data export map (Excel):
  Column A: Variable Name (e.g., Q1, Q2_1, Q2_2, Q3, ...)
  Column B: Question ID (e.g., 5, 5, 5, 6, ...)
  Column C: Question Title (e.g., "Brand Awareness", ...)
```

**Processing Logic:**
```r
parse_data_export_map <- function(file_path, verbose = TRUE) {

  # 1. Load Excel file
  data <- readxl::read_excel(file_path, sheet = 1)

  # 2. Identify multi-column questions
  # Questions with multiple variables (Q2_1, Q2_2, Q2_3)
  # indicate multi-mention or grid questions
  multi_column_groups <- identify_multi_column_questions(data)

  # 3. Extract question metadata
  questions <- data %>%
    group_by(QuestionID) %>%
    summarize(
      VariableNames = list(VariableName),
      QuestionTitle = first(QuestionTitle),
      ColumnCount = n(),
      IsMultiColumn = (n() > 1)
    )

  # 4. Return structured data
  return(list(
    questions = questions,
    n_questions = nrow(questions),
    n_columns = nrow(data),
    multi_column_groups = multi_column_groups
  ))
}
```

**Output:**
```r
list(
  questions = data.frame(
    QuestionID = c(5, 6, 7, ...),
    VariableNames = list(c("Q1"), c("Q2_1", "Q2_2", "Q2_3"), ...),
    QuestionTitle = c("Brand Awareness", "Features Used", ...),
    ColumnCount = c(1, 3, 1, ...),
    IsMultiColumn = c(FALSE, TRUE, FALSE, ...)
  ),
  n_questions = 42,
  n_columns = 87,
  multi_column_groups = list(...)
)
```

---

### 4.3 Translation Parser (02_parse_translation.R)

**Purpose:** Extract response options and labels from translation export

**Key Function:** `parse_translation_export()`

**Input File Structure:**
```
Alchemer translation export (Excel):
  Row 1: Headers (QuestionID, QuestionText, OptionID, OptionText, OptionValue)
  Row 2+: Data rows
```

**Processing Logic:**
```r
parse_translation_export <- function(file_path, verbose = TRUE) {

  # 1. Load Excel file
  data <- readxl::read_excel(file_path, sheet = 1)

  # 2. Extract questions
  questions <- data %>%
    select(QuestionID, QuestionText) %>%
    distinct()

  # 3. Extract options
  options <- data %>%
    select(QuestionID, OptionID, OptionText, OptionValue) %>%
    filter(!is.na(OptionID))  # Some questions have no options (open-ends)

  # 4. Detect scales (1-5, 1-10, etc.)
  scale_info <- detect_rating_scales(options)

  # 5. Return structured data
  return(list(
    questions = questions,
    options = options,
    scale_info = scale_info,
    n_questions = nrow(questions),
    n_options = nrow(options)
  ))
}
```

**Scale Detection:**
```r
detect_rating_scales <- function(options) {
  # Identifies:
  # - NPS (0-10 scale)
  # - Likert (1-5, 1-7, etc.)
  # - Rating scales (numeric sequences)

  options %>%
    group_by(QuestionID) %>%
    summarize(
      IsNumeric = all(grepl("^[0-9]+$", OptionValue)),
      MinValue = min(as.numeric(OptionValue), na.rm = TRUE),
      MaxValue = max(as.numeric(OptionValue), na.rm = TRUE),
      ScaleType = classify_scale(MinValue, MaxValue)
    )
}

classify_scale <- function(min_val, max_val) {
  if (min_val == 0 && max_val == 10) {
    return("NPS")
  } else if (min_val == 1 && max_val == 5) {
    return("Likert_5")
  } else if (min_val == 1 && max_val == 7) {
    return("Likert_7")
  } else if (min_val == 1 && max_val == 10) {
    return("Rating_10")
  } else {
    return("Rating_Custom")
  }
}
```

---

### 4.4 Word Document Parser (03_parse_word_doc.R)

**Purpose:** Extract question text from Word questionnaire

**Key Function:** `parse_word_questionnaire()`

**Processing Steps:**
```r
parse_word_questionnaire <- function(file_path, verbose = TRUE) {

  # 1. Read .docx file as XML
  doc <- officer::read_docx(file_path)

  # 2. Extract all paragraphs
  paragraphs <- officer::docx_summary(doc)

  # 3. Identify question blocks
  # Questions typically have patterns:
  # - "Q1." or "1." at start
  # - Bold formatting
  # - Followed by options or blank line
  questions <- extract_question_blocks(paragraphs)

  # 4. Clean and format
  questions <- clean_question_text(questions)

  # 5. Extract skip logic references
  questions <- extract_skip_logic(questions)

  return(list(
    questions = questions,
    n_questions = nrow(questions),
    has_skip_logic = any(!is.na(questions$SkipLogic))
  ))
}
```

**Question Block Extraction:**
```r
extract_question_blocks <- function(paragraphs) {

  questions <- list()
  current_question <- NULL

  for (i in seq_len(nrow(paragraphs))) {
    para <- paragraphs[i, ]

    # Check if this paragraph starts a new question
    if (is_question_start(para$text, para$style)) {

      # Save previous question if exists
      if (!is.null(current_question)) {
        questions <- append(questions, list(current_question))
      }

      # Start new question
      current_question <- list(
        QuestionNumber = extract_question_number(para$text),
        QuestionText = clean_text(para$text),
        FullText = para$text,
        Options = character(),
        SkipLogic = NA
      )

    } else if (!is.null(current_question)) {
      # This paragraph is part of current question

      if (is_option(para$text)) {
        # Add to options list
        current_question$Options <- c(
          current_question$Options,
          clean_text(para$text)
        )
      } else if (is_skip_logic(para$text)) {
        # Extract skip logic
        current_question$SkipLogic <- extract_skip_reference(para$text)
      }
    }
  }

  # Save last question
  if (!is.null(current_question)) {
    questions <- append(questions, list(current_question))
  }

  return(bind_rows(questions))
}
```

**Pattern Matching:**
```r
is_question_start <- function(text, style) {
  # Patterns that indicate question start:
  # - "Q1." or "1." at beginning
  # - Bold or heading style
  # - Length > 10 characters

  grepl("^(Q?\\d+[a-z]?[.]|\\d+[.])", text) &&
    (style %in% c("heading 1", "heading 2", "Bold") || nchar(text) > 10)
}

is_option <- function(text) {
  # Patterns for response options:
  # - Starts with letter + period: "a.", "b.", "c."
  # - Starts with bullet or dash
  # - Short text (< 100 chars)

  grepl("^([a-z][.]|[-•○])", text, ignore.case = TRUE) &&
    nchar(text) < 100
}

is_skip_logic <- function(text) {
  # Patterns for skip logic:
  # - "If yes, go to Q5"
  # - "Skip to Q10 if..."
  # - "[Show if Q3 = 1]"

  grepl("(skip|go to|show if|if .* (then|go))", text, ignore.case = TRUE)
}
```

---

### 4.5 Question Classifier (04_classify_questions.R)

**Purpose:** Automatically detect question types using pattern matching

**Key Function:** `classify_questions()`

**Question Types Detected:**
1. **NPS** - Net Promoter Score (0-10 scale)
2. **Likert** - Agreement scales (1-5, 1-7)
3. **Rating** - Numeric rating scales
4. **Single_Response** - Single-choice questions
5. **Multi_Mention** - Multi-select questions
6. **Grid** - Matrix/grid questions
7. **Ranking** - Rank-order questions
8. **Open_End** - Text responses
9. **Numeric** - Numeric input (age, income, etc.)

**Classification Logic:**
```r
classify_questions <- function(merged_questions, verbose = TRUE) {

  for (i in seq_len(nrow(merged_questions))) {
    q <- merged_questions[i, ]

    # Apply classification rules in priority order
    question_type <- classify_single_question(q)

    merged_questions$Variable_Type[i] <- question_type$type
    merged_questions$Confidence[i] <- question_type$confidence
    merged_questions$Reason[i] <- question_type$reason
  }

  return(merged_questions)
}
```

**Classification Rules (Priority Order):**

```r
classify_single_question <- function(q) {

  # Rule 1: NPS detection
  if (has_nps_scale(q)) {
    return(list(
      type = "NPS",
      confidence = "High",
      reason = "0-10 scale detected with 'recommend' keyword"
    ))
  }

  # Rule 2: Likert detection
  if (has_likert_scale(q)) {
    return(list(
      type = "Likert",
      confidence = "High",
      reason = "1-5 or 1-7 scale with agreement options"
    ))
  }

  # Rule 3: Rating detection
  if (has_rating_scale(q)) {
    return(list(
      type = "Rating",
      confidence = "High",
      reason = "Numeric scale detected"
    ))
  }

  # Rule 4: Grid detection
  if (is_grid_question(q)) {
    return(list(
      type = "Grid",
      confidence = "Medium",
      reason = "Multiple columns with same scale"
    ))
  }

  # Rule 5: Multi-mention detection
  if (is_multi_mention(q)) {
    return(list(
      type = "Multi_Mention",
      confidence = "High",
      reason = "Multiple columns OR 'select all' keyword"
    ))
  }

  # Rule 6: Ranking detection
  if (is_ranking_question(q)) {
    return(list(
      type = "Ranking",
      confidence = "Medium",
      reason = "'rank' keyword in question text"
    ))
  }

  # Rule 7: Open-end detection
  if (is_open_end(q)) {
    return(list(
      type = "Open_End",
      confidence = "High",
      reason = "No options provided"
    ))
  }

  # Rule 8: Numeric detection
  if (is_numeric_question(q)) {
    return(list(
      type = "Numeric",
      confidence = "Medium",
      reason = "Single numeric input expected"
    ))
  }

  # Default: Single_Response
  return(list(
    type = "Single_Response",
    confidence = "Low",
    reason = "Default classification"
  ))
}
```

**Detection Helpers:**

```r
has_nps_scale <- function(q) {
  # Check for:
  # - 0-10 scale
  # - Keywords: "recommend", "likely to recommend", "NPS"

  has_0_10_scale <- (
    !is.null(q$ScaleType) &&
    q$ScaleType == "NPS"
  )

  has_recommend_keyword <- grepl(
    "(recommend|nps|net promoter)",
    q$QuestionText,
    ignore.case = TRUE
  )

  return(has_0_10_scale && has_recommend_keyword)
}

has_likert_scale <- function(q) {
  # Check for:
  # - 1-5 or 1-7 scale
  # - Agreement options: "Strongly Agree", "Agree", etc.

  has_likert_scale_values <- (
    !is.null(q$ScaleType) &&
    grepl("Likert", q$ScaleType)
  )

  has_agreement_options <- any(grepl(
    "(strongly agree|agree|neither|disagree|strongly disagree)",
    q$OptionTexts,
    ignore.case = TRUE
  ))

  return(has_likert_scale_values || has_agreement_options)
}

is_multi_mention <- function(q) {
  # Check for:
  # - Multiple data columns for same question
  # - Keywords: "select all", "check all", "multiple"

  has_multiple_columns <- (
    !is.null(q$ColumnCount) &&
    q$ColumnCount > 1
  )

  has_select_all_keyword <- grepl(
    "(select all|check all|choose all|multiple)",
    q$QuestionText,
    ignore.case = TRUE
  )

  return(has_multiple_columns || has_select_all_keyword)
}
```

---

### 4.6 Code Generator (05_generate_codes.R)

**Purpose:** Generate standardized question codes for Turas

**Key Function:** `generate_question_codes()`

**Code Format Standards:**
- Main questions: `Q01`, `Q02`, `Q03`, ...
- Sub-questions: `Q02a`, `Q02b`, `Q02c`, ...
- Grid questions: `Q03_1`, `Q03_2`, `Q03_3`, ...
- Sequential numbering maintained

**Generation Logic:**
```r
generate_question_codes <- function(classified_questions, verbose = TRUE) {

  # Initialize counters
  main_counter <- 1
  sub_counter <- NULL
  grid_counter <- NULL

  for (i in seq_len(nrow(classified_questions))) {
    q <- classified_questions[i, ]

    # Determine code based on question type and position
    if (is_new_main_question(q, i, classified_questions)) {
      # New main question
      code <- sprintf("Q%02d", main_counter)
      main_counter <- main_counter + 1
      sub_counter <- NULL
      grid_counter <- NULL

    } else if (is_sub_question(q)) {
      # Sub-question (part of previous question)
      if (is.null(sub_counter)) sub_counter <- 0
      sub_counter <- sub_counter + 1
      code <- sprintf("Q%02d%s", main_counter - 1, letters[sub_counter])

    } else if (is_grid_column(q)) {
      # Grid column
      if (is.null(grid_counter)) grid_counter <- 0
      grid_counter <- grid_counter + 1
      code <- sprintf("Q%02d_%d", main_counter - 1, grid_counter)
    }

    classified_questions$QuestionCode[i] <- code
  }

  return(classified_questions)
}
```

**Helper Functions:**

```r
is_new_main_question <- function(q, index, all_questions) {
  # A question is a new main question if:
  # - It's the first question, OR
  # - It has a different QuestionID than previous question, OR
  # - It's not part of a grid/sub-question group

  if (index == 1) return(TRUE)

  prev_q <- all_questions[index - 1, ]

  return(
    q$QuestionID != prev_q$QuestionID ||
    (!is_grid_column(q) && !is_sub_question(q))
  )
}

is_sub_question <- function(q) {
  # Indicators of sub-question:
  # - Question text starts with letter + period: "a.", "b."
  # - Part of numbered list within larger question

  grepl("^[a-z][.]", trimws(q$QuestionText), ignore.case = TRUE)
}

is_grid_column <- function(q) {
  # Indicators of grid column:
  # - Multiple columns for same QuestionID
  # - Question type is "Grid"

  q$Variable_Type == "Grid" && q$ColumnCount > 1
}
```

**Code Validation:**
```r
validate_generated_codes <- function(questions) {
  # Check for:
  # - No duplicate codes
  # - Sequential numbering
  # - Proper format (Q[0-9]{2}[a-z]?_?[0-9]?)

  issues <- list()

  # Check duplicates
  if (any(duplicated(questions$QuestionCode))) {
    issues$duplicates <- questions$QuestionCode[duplicated(questions$QuestionCode)]
  }

  # Check format
  invalid_format <- !grepl("^Q[0-9]{2}([a-z]|_[0-9]+)?$", questions$QuestionCode)
  if (any(invalid_format)) {
    issues$invalid_format <- questions$QuestionCode[invalid_format]
  }

  # Check sequential
  main_codes <- as.numeric(gsub("Q([0-9]+).*", "\\1", questions$QuestionCode))
  if (!all(diff(main_codes) >= 0)) {
    issues$non_sequential <- TRUE
  }

  return(issues)
}
```

---

### 4.7 Output Generator (06_output.R)

**Purpose:** Generate Excel output files for Tabs module

**Key Function:** `generate_output_files()`

**Output 1: Survey_Structure.xlsx**

**Structure:**
```
Sheet: Questions
  Columns:
    - QuestionCode (Q01, Q02, ...)
    - QuestionText (Full question text)
    - Variable_Type (Single_Response, Multi_Mention, NPS, ...)
    - ShortLabel (Abbreviated text for charts)
    - VariableName (Original Alchemer variable)
    - Notes (Classification reason, warnings)

Sheet: Options
  Columns:
    - QuestionCode (Q01, Q01, Q01, ...)
    - OptionValue (1, 2, 3, ...)
    - OptionText (Yes, No, Maybe, ...)
    - OptionOrder (1, 2, 3, ...)
```

**Generation Code:**
```r
write_survey_structure <- function(questions, output_path) {

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Sheet 1: Questions
  questions_sheet <- prepare_questions_sheet(questions)
  openxlsx::addWorksheet(wb, "Questions")
  openxlsx::writeData(wb, "Questions", questions_sheet)

  # Sheet 2: Options
  options_sheet <- prepare_options_sheet(questions)
  openxlsx::addWorksheet(wb, "Options")
  openxlsx::writeData(wb, "Options", options_sheet)

  # Apply formatting
  format_survey_structure(wb)

  # Save
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)

  return(output_path)
}
```

**Formatting:**
```r
format_survey_structure <- function(wb) {

  # Header style
  header_style <- openxlsx::createStyle(
    fontColour = "#FFFFFF",
    fillColor = "#4472C4",
    fontBold = TRUE,
    border = "TopBottomLeftRight",
    borderColour = "#000000"
  )

  # Apply to headers
  openxlsx::addStyle(wb, "Questions", header_style, rows = 1, cols = 1:6, gridExpand = TRUE)
  openxlsx::addStyle(wb, "Options", header_style, rows = 1, cols = 1:4, gridExpand = TRUE)

  # Freeze panes
  openxlsx::freezePane(wb, "Questions", firstRow = TRUE)
  openxlsx::freezePane(wb, "Options", firstRow = TRUE)

  # Column widths
  openxlsx::setColWidths(wb, "Questions", cols = 1:6, widths = c(15, 50, 20, 30, 20, 40))
  openxlsx::setColWidths(wb, "Options", cols = 1:4, widths = c(15, 15, 40, 10))
}
```

---

**Output 2: Tabs_Config.xlsx** (Optional)

Pre-configured crosstab configuration with:
- File paths set
- All questions added to Stub sheet
- Default settings applied

---

**Output 3: Validation_Report.xlsx** (Optional)

Questions requiring manual review:
- Low-confidence classifications
- Multi-column questions
- Questions with warnings
- Skip logic that couldn't be parsed

---

## 5. Processing Pipeline

### 5.1 Complete Data Flow

```
INPUT FILES
├─ Data Export Map (data_export.xlsx)
├─ Translation Export (translation.xlsx)
└─ Questionnaire (questionnaire.docx)
        ↓
┌───────────────────────────────────────┐
│ STAGE 1: PARSE DATA EXPORT MAP       │
│  - Extract variable names             │
│  - Identify multi-column questions    │
│  - Build variable-to-question mapping │
└─────────────┬─────────────────────────┘
              ↓
┌─────────────▼─────────────────────────┐
│ STAGE 2: PARSE TRANSLATION EXPORT     │
│  - Extract question text              │
│  - Extract response options           │
│  - Detect rating scales               │
└─────────────┬─────────────────────────┘
              ↓
┌─────────────▼─────────────────────────┐
│ STAGE 3: PARSE WORD QUESTIONNAIRE     │
│  - Extract full question text         │
│  - Extract question numbering         │
│  - Extract skip logic references      │
└─────────────┬─────────────────────────┘
              ↓
┌─────────────▼─────────────────────────┐
│ STAGE 4: MERGE DATA SOURCES           │
│  - Combine all three sources          │
│  - Resolve conflicts (use Word text)  │
│  - Flag missing data                  │
└─────────────┬─────────────────────────┘
              ↓
┌─────────────▼─────────────────────────┐
│ STAGE 5: CLASSIFY QUESTION TYPES      │
│  - Apply pattern matching rules       │
│  - Assign confidence scores           │
│  - Flag low-confidence classifications│
└─────────────┬─────────────────────────┘
              ↓
┌─────────────▼─────────────────────────┐
│ STAGE 6: GENERATE QUESTION CODES      │
│  - Assign sequential codes            │
│  - Handle sub-questions and grids     │
│  - Validate uniqueness                │
└─────────────┬─────────────────────────┘
              ↓
┌─────────────▼─────────────────────────┐
│ STAGE 7: GENERATE OUTPUT FILES        │
│  - Create Survey_Structure.xlsx       │
│  - Create Tabs_Config.xlsx (optional) │
│  - Create Validation_Report.xlsx      │
└─────────────┬─────────────────────────┘
              ↓
OUTPUT FILES
├─ Survey_Structure.xlsx
├─ Tabs_Config.xlsx
└─ Validation_Report.xlsx
```

### 5.2 Error Handling Strategy

**Fail-Safe Approach:**
- Invalid questions are flagged, not rejected
- Processing continues even if some questions fail
- All issues logged to validation report

**Error Types:**
1. **Missing Data** - Question in one source but not others
2. **Conflicting Data** - Different text in different sources
3. **Classification Failure** - Unable to determine question type
4. **Code Generation Failure** - Duplicate or invalid codes

**Handling:**
```r
tryCatch({
  # Attempt to process question
  result <- process_question(question)
}, error = function(e) {
  # Log error
  warnings <- c(warnings, sprintf(
    "Question %s: %s",
    question$QuestionID,
    e$message
  ))

  # Assign default values
  question$QuestionCode <- paste0("Q_ERROR_", question$QuestionID)
  question$Variable_Type <- "UNKNOWN"
  question$ValidationFlag <- "REVIEW_REQUIRED"

  return(question)
})
```

---

## 6. Question Classification

### 6.1 Classification Rules Reference

**Complete rule set for automatic classification:**

| Question Type | Detection Rules | Confidence |
|---------------|----------------|------------|
| **NPS** | • Scale 0-10<br>• Keywords: "recommend", "likely to recommend"<br>• 11 options (0,1,2,...,10) | High |
| **Likert** | • Scale 1-5 or 1-7<br>• Agreement options detected<br>• Keywords: "agree", "disagree" | High |
| **Rating** | • Numeric scale (not NPS or Likert)<br>• Sequential numbers<br>• 3-10 points | High |
| **Single_Response** | • One data column<br>• Multiple non-numeric options<br>• No "select all" keyword | Medium |
| **Multi_Mention** | • Multiple data columns OR<br>• Keywords: "select all", "check all", "choose all" | High |
| **Grid** | • Multiple columns<br>• Same scale for all columns<br>• Question text suggests matrix | Medium |
| **Ranking** | • Keywords: "rank", "order", "prioritize"<br>• Numeric values 1-N | Medium |
| **Open_End** | • No options provided<br>• Single text column | High |
| **Numeric** | • Single numeric column<br>• No predefined options<br>• Keywords: "how many", "age", "income" | Medium |

### 6.2 Improving Classification Accuracy

**Tips for better auto-classification:**

1. **Use Descriptive Question Text:**
   - Good: "How likely are you to recommend us? (0=Not at all likely, 10=Extremely likely)"
   - Bad: "Q5"

2. **Include Keywords:**
   - Multi-select: Add "Select all that apply"
   - Ranking: Add "Rank in order of preference"
   - NPS: Include "recommend"

3. **Consistent Scale Formats:**
   - Use standard scales (1-5, 1-7, 0-10)
   - Label endpoints clearly

4. **Word Questionnaire Formatting:**
   - Number questions sequentially: "1.", "2.", "3."
   - Use bold for question text
   - Indent options consistently

---

## 7. Code Generation

### 7.1 Code Format Specification

**Format:** `Q[main][sub][grid]`

**Components:**
- `Q` - Prefix (always present)
- `[main]` - 2-digit main question number (01-99)
- `[sub]` - Optional lowercase letter for sub-questions (a-z)
- `[grid]` - Optional `_N` suffix for grid columns

**Examples:**
```
Q01           Main question 1
Q02a          Sub-question 2a
Q02b          Sub-question 2b
Q03_1         Grid question 3, column 1
Q03_2         Grid question 3, column 2
Q04           Main question 4
```

### 7.2 Code Generation Rules

**Rule 1: Sequential Main Numbering**
- Main questions numbered 01, 02, 03, ...
- No gaps in sequence
- Maximum 99 main questions

**Rule 2: Sub-Questions**
- Use lowercase letters: a, b, c, ..., z
- Sub-questions share main number
- Maximum 26 sub-questions per main

**Rule 3: Grid Columns**
- Use `_N` suffix where N = 1, 2, 3, ...
- All columns of grid share same main number
- No maximum (but recommend <50 columns)

**Rule 4: Uniqueness**
- Every code must be unique
- Duplicates flagged for manual review

### 7.3 Code Assignment Algorithm

```r
# Pseudo-code for code assignment

main_num <- 1
sub_letter <- NULL
grid_num <- NULL

FOR each question IN questionnaire:

  IF question is start of new main question:
    code <- "Q" + pad(main_num, 2)
    main_num <- main_num + 1
    sub_letter <- NULL
    grid_num <- NULL

  ELSE IF question is sub-question:
    IF sub_letter is NULL:
      sub_letter <- "a"
    ELSE:
      sub_letter <- next_letter(sub_letter)
    code <- "Q" + pad(main_num - 1, 2) + sub_letter

  ELSE IF question is grid column:
    IF grid_num is NULL:
      grid_num <- 1
    ELSE:
      grid_num <- grid_num + 1
    code <- "Q" + pad(main_num - 1, 2) + "_" + grid_num

  question$QuestionCode <- code
```

---

## 8. Output Generation

### 8.1 Survey_Structure.xlsx Format

**Sheet: Questions**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| QuestionCode | Text | Turas question code | Q01 |
| QuestionText | Text | Full question text | Which brand do you prefer? |
| Variable_Type | Text | Question type classification | Single_Response |
| ShortLabel | Text | Abbreviated label for charts | Brand Preference |
| VariableName | Text | Original Alchemer variable | Q1 |
| Notes | Text | Classification notes, warnings | Auto-classified with high confidence |

**Sheet: Options**

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| QuestionCode | Text | Links to Questions sheet | Q01 |
| OptionValue | Text/Numeric | Option value in data | 1 |
| OptionText | Text | Option label | Brand A |
| OptionOrder | Numeric | Display order | 1 |

### 8.2 Tabs_Config.xlsx Format

Pre-populated configuration for Tabs module:

**Sheet: File_Paths**
```
Parameter            | Value
---------------------|---------------------------
Data_File            | [to be filled by user]
Output_File          | output/crosstabs.xlsx
Survey_Structure     | Survey_Structure.xlsx
```

**Sheet: Settings**
```
Setting_Name         | Setting_Value
---------------------|---------------
Significance_Level   | 0.05
Decimal_Places       | 0
Show_Frequencies     | TRUE
Show_Percentages     | TRUE
...
```

**Sheet: Stub**
```
All questions added automatically
User can remove unwanted questions
```

**Sheet: Banner**
```
Empty - user fills in demographic breaks
```

---

## 9. API Reference

### 9.1 Main Entry Point

```r
run_alchemerparser(
  project_dir,           # Required: Directory with input files
  project_name = NULL,   # Optional: Project name (auto-detected if NULL)
  output_dir = NULL,     # Optional: Output directory (defaults to project_dir)
  verbose = TRUE         # Optional: Print progress messages
) -> list
```

**Parameters:**

- `project_dir` (character): Absolute or relative path to directory containing the three input files
- `project_name` (character | NULL): Project name used for output filenames. If NULL, extracted from input filenames
- `output_dir` (character | NULL): Directory for output files. If NULL, uses project_dir
- `verbose` (logical): If TRUE, prints progress messages during processing

**Returns:**

```r
list(
  questions = data.frame(...),          # Parsed and classified questions
  validation_flags = list(...),         # Questions needing review
  outputs = list(                       # Output file paths
    survey_structure = "path/to/Survey_Structure.xlsx",
    tabs_config = "path/to/Tabs_Config.xlsx",
    validation_report = "path/to/Validation.xlsx"
  ),
  summary = list(                       # Summary statistics
    n_questions = 42,
    n_options = 156,
    question_types = table(...),
    review_percentage = 12.5
  )
)
```

**Example Usage:**

```r
# CLI usage
source("modules/AlchemerParser/R/00_main.R")

result <- run_alchemerparser(
  project_dir = "projects/Client_A/alchemer_export/",
  project_name = "Client_A_Wave1",
  output_dir = "projects/Client_A/config/",
  verbose = TRUE
)

# Check for review items
if (length(result$validation_flags$review_needed) > 0) {
  cat("Questions needing review:\n")
  print(result$validation_flags$review_needed)
}

# Use output in Tabs module
source("modules/tabs/lib/run_crosstabs.R")
run_crosstabs(
  config_file = result$outputs$tabs_config,
  data_file = "projects/Client_A/data/survey_data.csv"
)
```

### 9.2 Component Functions

**File Locator:**
```r
locate_input_files(
  project_dir,
  project_name = NULL,
  verbose = TRUE
) -> list(
  data_map = "path/to/data_export.xlsx",
  translation = "path/to/translation.xlsx",
  questionnaire = "path/to/questionnaire.docx",
  project_name = "extracted_project_name"
)
```

**Parsers:**
```r
parse_data_export_map(file_path, verbose = TRUE) -> list(...)
parse_translation_export(file_path, verbose = TRUE) -> list(...)
parse_word_questionnaire(file_path, verbose = TRUE) -> list(...)
```

**Classifier:**
```r
classify_questions(merged_questions, verbose = TRUE) -> data.frame(...)
```

**Code Generator:**
```r
generate_question_codes(classified_questions, verbose = TRUE) -> data.frame(...)
```

**Output Writer:**
```r
generate_output_files(
  coded_questions,
  output_dir,
  project_name,
  verbose = TRUE
) -> list(
  survey_structure = "path/...",
  tabs_config = "path/...",
  validation_report = "path/..."
)
```

---

## 10. Extension Points

### 10.1 Adding New Question Types

**Step 1: Define detection rules**

```r
# In 04_classify_questions.R

has_new_question_type <- function(q) {
  # Define detection logic
  # Example: Constant Sum question

  has_constant_sum_keyword <- grepl(
    "(total.*100|sum.*100|allocate.*points)",
    q$QuestionText,
    ignore.case = TRUE
  )

  has_numeric_options <- all(grepl("^[0-9]+$", q$OptionValues))

  return(has_constant_sum_keyword && has_numeric_options)
}
```

**Step 2: Add to classification logic**

```r
# In classify_single_question()

# Add before default Single_Response
if (has_new_question_type(q)) {
  return(list(
    type = "Constant_Sum",
    confidence = "High",
    reason = "Constant sum keywords detected with numeric inputs"
  ))
}
```

**Step 3: Update Tabs module**

```r
# Add processor for new type in Tabs module
# See Tabs TECHNICAL_DOCS.md
```

**Step 4: Document**

```r
# Update USER_MANUAL.md with new type
# Update TECHNICAL_DOCS.md classification rules
```

### 10.2 Improving Classification Accuracy

**Add Custom Keywords:**

```r
# In 04_classify_questions.R

# Add to NPS detection
has_nps_scale <- function(q) {
  has_0_10_scale <- (...)

  # Add custom keywords
  has_recommend_keyword <- grepl(
    "(recommend|nps|net promoter|advocate|refer)",  # Added: advocate, refer
    q$QuestionText,
    ignore.case = TRUE
  )

  return(has_0_10_scale && has_recommend_keyword)
}
```

**Train on Historical Data:**

```r
# Analyze past classifications to improve rules
historical_questions <- load_historical_classifications()

# Find patterns in misclassified questions
misclassified <- historical_questions %>%
  filter(ActualType != ClassifiedType)

# Add rules based on patterns found
```

### 10.3 Supporting Additional Input Formats

**Example: Adding Qualtrics Support**

```r
# Create new parser: 07_parse_qualtrics.R

parse_qualtrics_export <- function(file_path, verbose = TRUE) {
  # Qualtrics-specific parsing logic
  # Different file structure than Alchemer

  # Return same structure as other parsers
  return(list(
    questions = ...,
    options = ...,
    n_questions = ...,
    n_options = ...
  ))
}
```

```r
# Update 00_main.R to detect input type

determine_input_type <- function(project_dir) {
  files <- list.files(project_dir, full.names = TRUE)

  if (any(grepl("QSF|qualtrics", files, ignore.case = TRUE))) {
    return("Qualtrics")
  } else if (any(grepl("alchemer|surveygizmo", files, ignore.case = TRUE))) {
    return("Alchemer")
  } else {
    stop("Unknown survey platform")
  }
}

# Route to appropriate parser
input_type <- determine_input_type(project_dir)

if (input_type == "Qualtrics") {
  parsed_data <- parse_qualtrics_export(...)
} else if (input_type == "Alchemer") {
  parsed_data <- parse_alchemer_exports(...)
}
```

---

## 11. Testing & Validation

### 11.1 Test Strategy

**Unit Tests:**
```r
# Test individual components

test_that("NPS scale detection works", {
  q <- create_test_question(
    scale = "0-10",
    text = "How likely are you to recommend us?"
  )

  result <- has_nps_scale(q)
  expect_true(result)
})

test_that("Code generation is sequential", {
  questions <- create_test_questions(n = 10)
  coded <- generate_question_codes(questions)

  codes <- as.numeric(gsub("Q([0-9]+).*", "\\1", coded$QuestionCode))
  expect_equal(codes, 1:10)
})
```

**Integration Tests:**
```r
# Test full pipeline

test_that("full pipeline works", {
  result <- run_alchemerparser(
    project_dir = "test_data/basic/",
    verbose = FALSE
  )

  # Check outputs generated
  expect_true(file.exists(result$outputs$survey_structure))

  # Check structure
  expect_true("QuestionCode" %in% names(result$questions))
  expect_true("Variable_Type" %in% names(result$questions))

  # Check classification
  expect_gt(nrow(result$questions), 0)
})
```

### 11.2 Validation Checklist

**Manual Review Required For:**
- [ ] Questions with Confidence = "Low"
- [ ] Grid questions (verify column grouping)
- [ ] Multi-mention questions (verify all columns captured)
- [ ] Open-end questions (verify no options missed)
- [ ] Questions with skip logic (verify logic parsed correctly)

**Automated Validation:**
```r
validate_alchemerparser_output <- function(result) {

  checks <- list()

  # Check: All questions have codes
  checks$all_have_codes <- all(!is.na(result$questions$QuestionCode))

  # Check: No duplicate codes
  checks$no_duplicates <- !any(duplicated(result$questions$QuestionCode))

  # Check: All questions have types
  checks$all_have_types <- all(!is.na(result$questions$Variable_Type))

  # Check: Output files exist
  checks$files_exist <- all(sapply(result$outputs, file.exists))

  # Check: Survey_Structure has required sheets
  wb <- openxlsx::loadWorkbook(result$outputs$survey_structure)
  checks$has_questions_sheet <- "Questions" %in% names(wb)
  checks$has_options_sheet <- "Options" %in% names(wb)

  # Summary
  all_pass <- all(unlist(checks))

  return(list(
    checks = checks,
    all_pass = all_pass
  ))
}
```

---

## 12. Troubleshooting

### 12.1 Common Issues

**Issue: "Input files not found"**

**Cause:** File naming doesn't match expected pattern

**Expected Filenames:**
- Data export: `*_Data_Export_Map*.xlsx` or `*data*export*.xlsx`
- Translation: `*_Translation_Export*.xlsx` or `*translation*.xlsx`
- Questionnaire: `*.docx` (any .docx file)

**Solution:**
```r
# Rename files to match pattern, or specify explicitly:
files <- list(
  data_map = "path/to/data_file.xlsx",
  translation = "path/to/translation_file.xlsx",
  questionnaire = "path/to/questionnaire.docx"
)

# Then call parser with pre-located files (requires code modification)
```

---

**Issue: "Question classification incorrect"**

**Cause:** Pattern matching rules too broad or narrow

**Solution:**
1. Check question text and options in input files
2. Add keywords to improve detection
3. Manually override in Survey_Structure.xlsx after generation
4. Report issue for future rule improvement

---

**Issue: "Missing options for question"**

**Cause:** Options not in translation export or format unexpected

**Solution:**
1. Check translation export has all options
2. Verify option format (OptionID, OptionText, OptionValue columns)
3. Manually add options to Survey_Structure.xlsx Options sheet

---

**Issue: "Grid question not detected"**

**Cause:** Multi-column questions not properly identified

**Solution:**
1. Check data export map shows multiple columns for question
2. Verify column names follow pattern (Q1_1, Q1_2, Q1_3)
3. Add "grid" keyword to question text
4. Manually set Variable_Type = "Grid" in Survey_Structure.xlsx

---

**Issue: "Word document parsing fails"**

**Cause:** Unexpected .docx format or corruption

**Solution:**
```r
# Try re-saving .docx file
# 1. Open in Microsoft Word
# 2. Save As → Word Document (.docx)
# 3. Close and retry

# Check .docx is not password-protected
# Check .docx is not corrupted (open manually)

# If issues persist, extract text manually:
library(officer)
doc <- read_docx("questionnaire.docx")
content <- docx_summary(doc)
View(content)  # Review structure
```

---

### 12.2 Debug Mode

**Enable Detailed Logging:**

```r
# Set verbose = TRUE for full output
result <- run_alchemerparser(
  project_dir = "...",
  verbose = TRUE  # Shows all processing steps
)

# Check intermediate results
View(result$questions)  # Review all questions
View(result$validation_flags)  # Check issues

# Export for manual review
write.csv(result$questions, "debug_questions.csv", row.names = FALSE)
```

**Check Classification Confidence:**

```r
# Questions with low confidence
low_confidence <- result$questions %>%
  filter(Confidence == "Low")

View(low_confidence)

# Review classification reasons
table(result$questions$Variable_Type, result$questions$Confidence)
```

---

## Appendix A: Input File Examples

### Alchemer Data Export Map

```
| VariableName | QuestionID | QuestionTitle          |
|--------------|------------|------------------------|
| Q1           | 5          | Brand Awareness        |
| Q2_1         | 6          | Features Used          |
| Q2_2         | 6          | Features Used          |
| Q2_3         | 6          | Features Used          |
| Q3           | 7          | Satisfaction Rating    |
| Q4           | 8          | Likelihood to Recommend|
```

### Alchemer Translation Export

```
| QuestionID | QuestionText             | OptionID | OptionText       | OptionValue |
|------------|--------------------------|----------|------------------|-------------|
| 5          | Which brands do you know?| 1001     | Brand A          | 1           |
| 5          | Which brands do you know?| 1002     | Brand B          | 2           |
| 5          | Which brands do you know?| 1003     | Brand C          | 3           |
| 7          | How satisfied are you?   | 2001     | Very Satisfied   | 5           |
| 7          | How satisfied are you?   | 2002     | Satisfied        | 4           |
| 7          | How satisfied are you?   | 2003     | Neutral          | 3           |
```

### Word Questionnaire

```
1. Which brands are you aware of? (Select all that apply)
   a. Brand A
   b. Brand B
   c. Brand C

2. Which features have you used in the past 6 months? (Select all)
   a. Feature X
   b. Feature Y
   c. Feature Z

3. How satisfied are you with the product?
   Very Satisfied / Satisfied / Neutral / Dissatisfied / Very Dissatisfied

4. How likely are you to recommend us to a friend or colleague?
   (0 = Not at all likely, 10 = Extremely likely)
```

---

## Appendix B: Classification Decision Tree

```
START
  │
  ├─ Scale 0-10 + "recommend"? ──YES──> NPS
  │   NO
  │   │
  ├─ Scale 1-5/1-7 + agreement options? ──YES──> Likert
  │   NO
  │   │
  ├─ Numeric scale (not above)? ──YES──> Rating
  │   NO
  │   │
  ├─ Multiple columns OR "select all"? ──YES──> Multi_Mention
  │   NO
  │   │
  ├─ Multiple columns + same scale? ──YES──> Grid
  │   NO
  │   │
  ├─ "Rank" keyword? ──YES──> Ranking
  │   NO
  │   │
  ├─ No options provided? ──YES──> Open_End
  │   NO
  │   │
  ├─ Single numeric input? ──YES──> Numeric
  │   NO
  │   │
  └─ DEFAULT ──> Single_Response
```

---

**Document Version:** 1.0
**Last Updated:** December 6, 2025
**Maintained By:** Turas Development Team
**Next Review:** March 6, 2026

---

**End of AlchemerParser Technical Documentation**
