# Turas Parser - Technical Documentation

**Version:** 1.0.0
**Target Audience:** Developers, Maintainers
**Last Updated:** 2025-11-17

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Module Structure](#module-structure)
3. [Core Components](#core-components)
4. [Data Flow](#data-flow)
5. [API Reference](#api-reference)
6. [Algorithm Details](#algorithm-details)
7. [Extension Points](#extension-points)
8. [Testing](#testing)
9. [Maintenance](#maintenance)
10. [Known Issues](#known-issues)

---

## 1. Architecture Overview

### 1.1 Design Philosophy

The Turas Parser follows a **pipeline architecture** with clear separation of concerns:

```
Input (Word) → Read → Parse → Detect → Generate → Output (Excel)
```

**Key Principles:**
- **Modularity:** Each processing stage is isolated
- **Configurability:** Behavior controlled via config parameters
- **Robustness:** Graceful degradation when patterns don't match
- **Transparency:** Flags items needing human review rather than guessing

### 1.2 Technology Stack

- **Language:** R 4.0+
- **Document Reading:** `officer` package (Word .docx parsing)
- **Excel Writing:** `openxlsx` package
- **GUI:** `shiny` package
- **Pattern Matching:** Base R regex

### 1.3 Design Patterns

- **Strategy Pattern:** Question type detection uses multiple strategies in priority order
- **Builder Pattern:** Excel workbook constructed incrementally
- **Observer Pattern:** Shiny reactive programming for GUI

---

## 2. Module Structure

### 2.1 Directory Layout

```
modules/parser/
├── lib/                          # Core library functions
│   ├── docx_reader.R            # Word document I/O
│   ├── structure_parser.R       # Identify questions vs options
│   ├── pattern_parser.R         # Pattern matching for questions/options
│   ├── type_detector.R          # Question type classification
│   ├── bin_detector.R           # Numeric bin detection
│   ├── text_cleaner.R           # Text normalization
│   ├── parse_orchestrator.R     # Main parsing workflow
│   └── output_generator.R       # Excel output generation
│
├── Documentation/                # Legacy documentation
├── run_parser.R                 # Command-line entry point
├── shiny_app.R                  # GUI entry point
├── turas_launcher_shiny.R       # Alternate launcher
├── turas_launcher_tcltk.R       # Legacy TclTk launcher
│
├── QUICK_START.md               # User: Getting started
├── USER_MANUAL.md               # User: Comprehensive guide
├── TECHNICAL_DOCUMENTATION.md   # Dev: This file
└── EXAMPLE_WORKFLOWS.md         # User: Real-world examples
```

### 2.2 File Responsibilities

| File | Lines | Purpose | Key Functions |
|------|-------|---------|---------------|
| `docx_reader.R` | ~200 | Read Word documents | `read_docx_text()`, `validate_docx_file()` |
| `structure_parser.R` | ~350 | Separate questions from options | `parse_questionnaire_structure()` |
| `pattern_parser.R` | ~300 | Extract text using patterns | `parse_with_patterns()` |
| `type_detector.R` | ~250 | Classify question types | `detect_question_type()` |
| `bin_detector.R` | ~150 | Detect numeric bins | `detect_numeric_bins()` |
| `text_cleaner.R` | ~350 | Clean and normalize text | `clean_text()`, `remove_formatting()` |
| `parse_orchestrator.R` | ~250 | Coordinate parsing pipeline | `orchestrate_parsing()` |
| `output_generator.R` | ~600 | Generate Excel output | `generate_survey_structure()` |

---

## 3. Core Components

### 3.1 Document Reader (`docx_reader.R`)

**Purpose:** Extract raw text from Word documents

**Key Functions:**

```r
#' Read text content from Word document
#' @param docx_path Character. Path to .docx file
#' @return Character vector of paragraphs
read_docx_text <- function(docx_path) {
  # Validates file exists and is .docx
  # Uses officer::read_docx() to parse
  # Extracts paragraph text
  # Returns character vector
}
```

**Technology:**
- Uses `officer` package for .docx parsing
- Extracts paragraph-level text (no styling preserved)
- Handles nested structures (tables converted to text)

**Limitations:**
- Images not extracted (text alternatives used if present)
- Complex formatting lost (bullets, numbering)
- Tables linearized to text

### 3.2 Structure Parser (`structure_parser.R`)

**Purpose:** Identify questions and their associated options

**Algorithm:**
1. Scan document line by line
2. Detect question patterns (Q1, 1., etc.)
3. Detect option patterns (a), 1., etc.)
4. Associate options with preceding question
5. Handle multi-line text continuation

**Key Functions:**

```r
parse_questionnaire_structure <- function(text_lines, config) {
  # Returns: list(questions = data.frame, options = list)
}
```

**Question Detection Patterns:**
```r
# Numbered questions
"^Q\\d+"           # Q1, Q2, Q3
"^\\d+\\."         # 1. 2. 3.
"^Question \\d+"   # Question 1, Question 2

# Criteria:
# - At least 30 characters of text (configurable)
# - Not just a number
# - Followed by question mark or colon (optional)
```

**Option Detection Patterns:**
```r
# Letter-based
"^\\s*[a-z]\\)"    # a) b) c)
"^\\s*[A-Z]\\."    # A. B. C.

# Number-based
"^\\s*\\d+\\."     # 1. 2. 3.
"^\\s*\\d+\\)"     # 1) 2) 3)

# Bracketed
"^\\s*\\[[a-z]\\]" # [a] [b] [c]
```

### 3.3 Type Detector (`type_detector.R`)

**Purpose:** Classify question as Single_Response, Multi_Mention, Rating, NPS, etc.

**Detection Priority:**

```
1. Format Hints (if enabled)
   [brackets] → Multi_Mention
   (parentheses) → Single_Response

2. Explicit Text Patterns
   "check all that apply" → Multi_Mention
   "select one" → Single_Response

3. Numeric Patterns
   "0-10" + 11 options → NPS
   "1-10" + 10 options → Rating
   "1-5" + 5 options → Rating

4. Option Count
   < 12 options → Single_Response
   ≥ 12 options → Multi_Mention

5. Default
   No options → Open_Ended
```

**Implementation:**

```r
detect_question_type <- function(question_data, config) {
  # Check format hints first (highest priority)
  if (config$detect_format_hints) {
    if (has_bracket_hint(question_data)) return("Multi_Mention")
    if (has_paren_hint(question_data)) return("Single_Response")
  }

  # Check explicit patterns
  type_from_text <- detect_from_question_text(question_data$text)
  if (!is.null(type_from_text)) return(type_from_text)

  # Check numeric patterns (NPS, Rating)
  if (is_nps_question(question_data)) return("NPS")
  if (is_rating_question(question_data)) return("Rating")

  # Use option count
  if (question_data$option_count == 0) return("Open_Ended")
  if (question_data$option_count >= 12) return("Multi_Mention")

  return("Single_Response")  # Default
}
```

### 3.4 Bin Detector (`bin_detector.R`)

**Purpose:** Identify when options represent numeric ranges (bins)

**Algorithm:**
1. Extract numeric patterns from options
2. Detect ranges (18-24, 25-34, etc.)
3. Validate bins are sequential and non-overlapping
4. Calculate overall min/max

**Bin Patterns:**
```r
# Hyphen-separated ranges
"18-24"
"25-34"
"$50,000-$75,000"

# "or more" / "or less"
"55+"
"65 or older"
"Under 18"

# Special handling:
# - Commas removed: "$50,000" → "50000"
# - "+" interpreted as open-ended upper bound
# - "Under" interpreted as <
```

**Validation:**
- Checks for gaps (24-25 vs 25-34 is gap-less)
- Warns if bins overlap
- Flags unusual patterns for review

### 3.5 Output Generator (`output_generator.R`)

**Purpose:** Create Excel file with 4 sheets

**Sheet Generation:**

```r
generate_survey_structure <- function(questions, config, output_path) {
  wb <- createWorkbook()

  # Sheet 1: Questions - Main survey structure
  add_questions_sheet(wb, questions)

  # Sheet 2: Options - Detailed option list
  add_options_sheet(wb, questions)

  # Sheet 3: Othertext - "Other specify" fields
  add_othertext_sheet(wb, questions)

  # Sheet 4: Metadata - Project info
  add_metadata_sheet(wb, questions, config)

  saveWorkbook(wb, output_path, overwrite = TRUE)
}
```

**Column Width Optimization:**
- `QuestionText`: 80 characters
- `Options`: 60 characters
- `QuestionCode`: 20 characters

**Formatting:**
- Header row: Bold, frozen
- Review flags: Highlighted in yellow
- Bins: Marked with TRUE in IsBin column

---

## 4. Data Flow

### 4.1 High-Level Pipeline

```
┌─────────────────┐
│  Word Document  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Read Document  │ docx_reader.R
│  Extract Text   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Parse Structure│ structure_parser.R
│  Q's + Options  │ pattern_parser.R
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Detect Types   │ type_detector.R
│  Classify Q's   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Detect Bins    │ bin_detector.R
│  Find Ranges    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Generate Codes │ parse_orchestrator.R
│  Add Metadata   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Create Excel   │ output_generator.R
│  4 Sheets       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Survey Structure│
│    (.xlsx)      │
└─────────────────┘
```

### 4.2 Data Structures

**Questions Data Frame:**
```r
questions <- data.frame(
  QuestionCode = character(),      # "Q1", "Q2", etc.
  QuestionText = character(),      # Full question text
  QuestionType = character(),      # "Single_Response", "Multi_Mention", etc.
  Options = character(),           # "Option1; Option2; Option3"
  OptionCount = integer(),         # Number of options
  IsBin = logical(),               # TRUE if numeric bins
  BinMin = numeric(),              # Minimum bin value (if bins)
  BinMax = numeric(),              # Maximum bin value (if bins)
  NumericRange = character(),      # "18-65" (if bins)
  ReviewNeeded = logical(),        # TRUE if flagged for review
  ReviewReason = character(),      # Why flagged
  stringsAsFactors = FALSE
)
```

**Options List:**
```r
options_list <- list(
  Q1 = c("Option 1", "Option 2", "Option 3"),
  Q2 = c("Option A", "Option B", "Option C", "Option D"),
  ...
)
```

**Configuration Object:**
```r
config <- list(
  detect_format_hints = TRUE,      # Use [brackets] vs (parentheses)
  detect_bins = TRUE,              # Detect numeric ranges
  question_code_prefix = "Q",      # Prefix for codes
  permissive_mode = FALSE,         # Allow shorter questions
  min_question_length = 30,        # Minimum characters
  max_question_length = 200,       # Maximum characters
  max_option_length = 100          # Maximum option length
)
```

---

## 5. API Reference

### 5.1 Main Entry Points

**GUI Mode:**
```r
# Launch Shiny GUI
source("modules/parser/shiny_app.R")
# Opens browser with interactive interface
```

**Script Mode:**
```r
# Load parser
source("modules/parser/run_parser.R")

# Parse questionnaire
result <- parse_questionnaire(
  docx_path = "path/to/questionnaire.docx",
  output_path = "output/survey_structure.xlsx",
  config = list(
    detect_format_hints = TRUE,
    detect_bins = TRUE,
    question_code_prefix = "Q"
  )
)

# Returns:
# result$questions - data.frame of questions
# result$summary - parsing statistics
# result$warnings - any warnings generated
```

### 5.2 Core Functions

**`read_docx_text(docx_path)`**
- **Input:** Path to .docx file
- **Output:** Character vector of text lines
- **Errors:** Stops if file not found or not .docx

**`parse_questionnaire_structure(text_lines, config)`**
- **Input:** Text lines, config object
- **Output:** List with `questions` data.frame and `options` list
- **Side Effects:** Prints progress messages

**`detect_question_type(question_data, config)`**
- **Input:** Single question row, config
- **Output:** Character - question type
- **Logic:** Uses priority-based detection

**`detect_numeric_bins(options)`**
- **Input:** Character vector of options
- **Output:** List with `is_bin`, `min`, `max`, `ranges`
- **Validation:** Checks for gaps and overlaps

**`generate_survey_structure(questions, config, output_path)`**
- **Input:** Questions data.frame, config, output path
- **Output:** None (writes Excel file)
- **Side Effects:** Creates/overwrites Excel file

### 5.3 Helper Functions

**`clean_text(text)`**
- Removes extra whitespace, special characters
- Normalizes line breaks
- Trims leading/trailing spaces

**`generate_smart_question_codes(n, prefix = "Q")`**
- Generates Q1, Q2, Q3... or custom prefix
- Ensures uniqueness

**`is_other_specify(option_text)`**
- Detects "Other (please specify)" patterns
- Returns TRUE/FALSE

---

## 6. Algorithm Details

### 6.1 Question Type Detection Algorithm

**Pseudocode:**
```
function detect_question_type(question, config):

  # Priority 1: Format hints
  if config.detect_format_hints:
    if question.options contain [brackets]:
      return "Multi_Mention"
    if question.options contain (parentheses):
      return "Single_Response"

  # Priority 2: Explicit text patterns
  text_lower = lowercase(question.text)
  if "check all" in text_lower or "select all" in text_lower:
    return "Multi_Mention"
  if "select one" in text_lower or "choose one" in text_lower:
    return "Single_Response"

  # Priority 3: NPS detection
  if option_count == 11 and options are 0-10:
    if "recommend" in text_lower or "likely" in text_lower:
      return "NPS"

  # Priority 4: Rating detection
  if option_count in [5, 7, 10]:
    if options are sequential numbers starting at 1:
      return "Rating"

  # Priority 5: Open-ended detection
  if option_count == 0:
    return "Open_Ended"

  # Priority 6: Multi-mention based on count
  if option_count >= 12:
    return "Multi_Mention"

  # Default: Single response
  return "Single_Response"
```

### 6.2 Bin Detection Algorithm

**Pseudocode:**
```
function detect_numeric_bins(options):

  bins = []

  for each option in options:
    # Extract numbers
    numbers = extract_all_numbers(option)

    if length(numbers) == 2:
      # Range detected: "18-24"
      bins.append({min: numbers[0], max: numbers[1], text: option})

    else if option contains "+":
      # Open-ended upper: "65+"
      bins.append({min: numbers[0], max: Infinity, text: option})

    else if option contains "under" or "less":
      # Open-ended lower: "Under 18"
      bins.append({min: 0, max: numbers[0], text: option})

  # Validation
  if length(bins) < 2:
    return {is_bin: FALSE}

  # Check for sequential bins
  bins = sort_by_min(bins)
  for i in 1 to length(bins)-1:
    if bins[i].max > bins[i+1].min:
      warning("Overlapping bins detected")

  overall_min = min(bins.min)
  overall_max = max(bins.max where max != Infinity)

  return {
    is_bin: TRUE,
    min: overall_min,
    max: overall_max,
    ranges: bins
  }
```

### 6.3 Text Cleaning Algorithm

**Operations:**
1. Remove formatting marks (bold, italic, underline)
2. Normalize whitespace (multiple spaces → single space)
3. Remove excessive punctuation (_____, ....., ----)
4. Trim leading/trailing whitespace
5. Convert smart quotes to straight quotes
6. Remove zero-width characters

---

## 7. Extension Points

### 7.1 Adding New Question Types

To add a new question type (e.g., "Ranking"):

1. **Update type_detector.R:**
```r
detect_question_type <- function(question_data, config) {
  # ... existing code ...

  # Add new detection logic
  if (is_ranking_question(question_data)) {
    return("Ranking")
  }

  # ... rest of code ...
}

# Add helper function
is_ranking_question <- function(question_data) {
  text_lower <- tolower(question_data$text)
  has_rank_keyword <- grepl("rank|order|priority", text_lower)
  has_instructions <- grepl("1st|2nd|3rd|first|second|third", text_lower)

  return(has_rank_keyword && has_instructions)
}
```

2. **Update output_generator.R** (if special handling needed)

3. **Update documentation** (USER_MANUAL.md)

### 7.2 Adding New Detection Patterns

To add new option detection patterns:

**Edit pattern_parser.R:**
```r
# Add to option_patterns list
option_patterns <- c(
  "^\\s*[a-z]\\)",           # Existing: a) b) c)
  "^\\s*\\d+\\.",            # Existing: 1. 2. 3.
  "^\\s*\\([a-z]\\)",        # NEW: (a) (b) (c)
  "^\\s*-\\s*[A-Z]"          # NEW: - A  - B  - C
)
```

### 7.3 Custom Output Formats

To add CSV output in addition to Excel:

**Create new function in output_generator.R:**
```r
generate_csv_output <- function(questions, output_path) {
  write.csv(questions, output_path, row.names = FALSE)
}
```

**Add to parse_questionnaire() in run_parser.R:**
```r
if (config$output_format == "csv") {
  generate_csv_output(result$questions, output_path)
} else {
  generate_survey_structure(result$questions, config, output_path)
}
```

---

## 8. Testing

### 8.1 Current Test Coverage

**Status:** ⚠️ No formal unit tests currently exist

**Recommended Test Suite:**

```r
# tests/testthat/test_type_detector.R

test_that("NPS questions detected correctly", {
  question <- list(
    text = "How likely are you to recommend us?",
    options = as.character(0:10),
    option_count = 11
  )

  config <- list(detect_format_hints = TRUE)

  result <- detect_question_type(question, config)

  expect_equal(result, "NPS")
})

test_that("Multi-mention detected with brackets", {
  question <- list(
    text = "Which brands do you own?",
    options = c("[a] Brand A", "[b] Brand B", "[c] Brand C"),
    option_count = 3
  )

  config <- list(detect_format_hints = TRUE)

  result <- detect_question_type(question, config)

  expect_equal(result, "Multi_Mention")
})
```

### 8.2 Manual Testing Checklist

**Before each release:**

- [ ] Test with well-formatted questionnaire (should parse 95%+ correctly)
- [ ] Test with poorly formatted questionnaire (should flag for review)
- [ ] Test with NPS question (detect as NPS)
- [ ] Test with rating scales 1-5, 1-7, 1-10 (detect as Rating)
- [ ] Test with demographic bins (detect bins correctly)
- [ ] Test with "other specify" options (create Othertext sheet)
- [ ] Test with 100+ question survey (performance check)
- [ ] Test with special characters in text (Unicode, accents)
- [ ] Test GUI upload functionality
- [ ] Test Excel output opens correctly in Excel/Google Sheets

### 8.3 Integration Testing

**With Turas Tabs:**
```r
# Parse questionnaire
parse_result <- parse_questionnaire("questionnaire.docx", "structure.xlsx")

# Load in Tabs
survey_structure <- read_excel("structure.xlsx", sheet = "Questions")

# Verify columns exist
expect_true(all(c("QuestionCode", "QuestionType", "Options") %in% names(survey_structure)))
```

---

## 9. Maintenance

### 9.1 Common Maintenance Tasks

**Update Question Type Detection:**
- Edit `type_detector.R`
- Add new patterns or modify thresholds
- Test with representative questionnaires
- Update USER_MANUAL.md

**Update Option Patterns:**
- Edit `pattern_parser.R`
- Add regex patterns to `option_patterns`
- Test with sample text
- Document in USER_MANUAL.md

**Improve Bin Detection:**
- Edit `bin_detector.R`
- Modify numeric extraction regex
- Handle new formats (e.g., European number format)
- Add validation checks

### 9.2 Performance Optimization

**Current Performance:**
- Small survey (20-30 questions): < 5 seconds
- Medium survey (50-75 questions): 5-10 seconds
- Large survey (100+ questions): 15-30 seconds

**Bottlenecks:**
1. Word document reading (officer package)
2. Regex pattern matching (multiple passes)
3. Excel writing (openxlsx)

**Optimization Opportunities:**
- Cache compiled regex patterns
- Parallelize question type detection (future)
- Use data.table for large questionnaires

### 9.3 Dependency Management

**Critical Dependencies:**
```r
# Minimal required versions
officer >= 0.4.0    # Word document reading
openxlsx >= 4.2.0   # Excel writing
shiny >= 1.7.0      # GUI (optional)
```

**Updating Dependencies:**
1. Test with new versions in isolated environment
2. Check for breaking changes in package documentation
3. Run full manual test suite
4. Update DESCRIPTION file if creating package

---

## 10. Known Issues

### 10.1 Current Limitations

**Issue #1: Complex Tables**
- **Description:** Questionnaires with complex table grids not parsed correctly
- **Workaround:** Convert tables to simple text before parsing
- **Status:** By design (tables are linearized)

**Issue #2: Image-Based Options**
- **Description:** Options shown as images (logos, pictures) not detected
- **Workaround:** Add text descriptions to images before parsing
- **Status:** Won't fix (parser is text-based)

**Issue #3: Conditional Logic**
- **Description:** Skip patterns ("If Q1=Yes, go to Q5") captured as question text
- **Workaround:** Remove routing notes before parsing
- **Status:** By design (parser doesn't model logic)

**Issue #4: Long Server Function**
- **Description:** Shiny server function is 294 lines (CR-PARSER-003)
- **Impact:** Hard to maintain and test
- **Status:** Documented in CODE_REVIEW_SUMMARY.md
- **Fix:** Refactor using Shiny modules pattern

**Issue #5: Automatic Package Installation**
- **Description:** Installs packages without user consent (CR-PARSER-001)
- **Impact:** Security risk
- **Status:** Critical - needs fix
- **Fix:** Replace with error message

### 10.2 Future Enhancements

**Planned:**
- [ ] Support for grid/matrix questions
- [ ] Export to JSON format (for API integration)
- [ ] Batch processing GUI
- [ ] Questionnaire comparison tool (diff two versions)
- [ ] AI-assisted type correction

**Under Consideration:**
- [ ] PDF questionnaire support (via OCR)
- [ ] Integration with survey platforms (Qualtrics, SurveyMonkey)
- [ ] Automatic code generation based on question content

---

## Appendix A: Regular Expression Patterns

### Question Patterns
```r
"^Q\\d+"                # Q1, Q2, Q3...
"^\\d+\\."              # 1. 2. 3.
"^\\d+\\)"              # 1) 2) 3)
"^Question\\s+\\d+"     # Question 1, Question 2
```

### Option Patterns
```r
"^\\s*[a-z]\\)"         # a) b) c)
"^\\s*\\([a-z]\\)"      # (a) (b) (c)
"^\\s*\\[[a-z]\\]"      # [a] [b] [c]
"^\\s*[A-Z]\\."         # A. B. C.
"^\\s*\\d+\\."          # 1. 2. 3.
"^\\s*\\d+\\)"          # 1) 2) 3)
```

### Numeric Bin Patterns
```r
"(\\d+)\\s*-\\s*(\\d+)"           # 18-24, 25-34
"(\\d+)\\s*to\\s*(\\d+)"          # 18 to 24
"(\\d+)\\+"                        # 65+
"Under\\s+(\\d+)"                  # Under 18
"\\$([\\d,]+)\\s*-\\s*\\$([\\d,]+)" # $50,000-$75,000
```

---

## Appendix B: Error Codes

### Parser Errors

| Code | Description | Severity | Solution |
|------|-------------|----------|----------|
| PE001 | File not found | Critical | Check file path |
| PE002 | Invalid .docx format | Critical | Ensure file is .docx |
| PE003 | No questions detected | High | Check formatting |
| PE004 | No options for question | Medium | Review question or mark as Open_Ended |
| PE005 | Type detection uncertain | Low | Manual review |

---

**End of Technical Documentation**

*Version 1.0.0 | For Developers | Turas Analytics Suite*
