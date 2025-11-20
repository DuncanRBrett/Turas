# Turas Parser Specification v2.0

## Purpose
Parse Alchemer survey files to generate Turas Tabs configuration files.

---

## Input Files

### Required Files (Project-named)
```
{ProjectName}_questionnaire.docx
{ProjectName}_data_export_map.xlsx
{ProjectName}_translation-export.xls
```

### File Structures

**Data Export Map:**
- Row 1: Q Number headers (1:, 2:, 3:...)
- Row 2: Q ID headers (2:, 3:, 7:...)
- Column A: Row labels ("data export with Question numbers", "data export with Question ID")
- Columns B+: Data columns with both mappings

**Translation Export:**
- Key column: q-{id}, q-{id}-o-{code}
- Default Text column: Question/option text

**Word Doc:**
- ( ) = Single mention indicator
- [ ] = Multi-mention indicator
- "rank" keyword = Ranking question
- Grid layouts visible in tables

---

## Question Type Detection Rules

### Detection Hierarchy

1. **NPS**
   - 11 options (0-10) 
   - Question text contains "recommend"

2. **Likert**
   - Options are agreement scales (disagree, neutral, agree)
   - Labeled endpoints

3. **Rating** 
   - Numeric scales (1-5, 1-7, 1-10)
   - Satisfaction/quality labels
   - Slider questions with fixed scale

4. **Ranking**
   - Word doc contains "rank" keyword
   - OR data shows sequential position values (1, 2, 3)
   - Multiple columns with same Q number

5. **Multi_Mention**
   - Word doc has [ ] brackets
   - OR multiple columns: `Q#: option:question` pattern
   - OR checkbox grid rows

6. **Single_Mention**
   - Word doc has ( ) brackets  
   - OR single column with `Q#: question` pattern
   - OR dropdown menu
   - OR radio grid rows

7. **Numeric**
   - Numeric box in Word doc
   - OR slider question (no fixed scale)
   - Data is continuous numbers

8. **Open_End**
   - Textbox in Word doc
   - Exclude from analysis

---

## Question Code Generation

### Format Rules
- Pad with zeros based on total questions:
  - <100 questions: Q01, Q02, Q03
  - ≥100 questions: Q001, Q002, Q003

### Single Column Questions
```
Q01  (Single_Mention)
Q03  (Single_Mention - dropdown)
Q05  (Open_End)
Q06  (Numeric)
Q07  (NPS)
Q08  (Likert)
Q11  (Numeric - slider)
```

### Multi-Column Questions

**Multi-Mention:**
```
Q04_1, Q04_2, Q04_3, Q04_4
```

**Ranking:**
```
Q12_1, Q12_2, Q12_3
```

**Radio Button Grid:**
```
Q02a (Tees)
Q02b (greens)
Q02c (fairways)
Each row = Single_Mention with 1 column
```

**Checkbox Grid:**
```
Q09a_1, Q09a_2, Q09a_3  (eggs row - breakfast, lunch, dinner)
Q09b_1, Q09b_2, Q09b_3  (burgers row)
Q09c_1, Q09c_2, Q09c_3  (salad row)
Each row = Multi_Mention with N columns
```

**Star Rating Grid:**
```
Q13a (kelvin - 1-5 scale)
Q13b (Mowbray - 1-5 scale)
Each item = Rating with 1 column
```

### Other/Specify Fields
```
Original: Q04_4 (if "Other - Write In" option)
Rename to: Q04_othermention
Set ShowInOutput = N
```

---

## Data Export Map Parsing

### Column Processing
```r
# Skip column A (labels)
# Start from column B (index 2)

for each column from B onwards:
  q_num <- extract first digits before ":" from row 1
  q_id <- extract first digits before ":" from row 2
  
  # Parse header components
  header <- row 1 value
  parts <- split by ":"
  
  if (length(parts) == 2):
    # Simple question: "Q#: Question Text"
    question_text <- parts[2]
    
  if (length(parts) == 3):
    # Grid or multi-mention: "Q#: Row/Option:Question Text"
    row_or_option <- parts[2]
    question_text <- parts[3]
    
  if (length(parts) == 4):
    # Checkbox grid: "Q#: Col:Row:Question Text"
    column_label <- parts[2]
    row_label <- parts[3]
    question_text <- parts[4]
```

### Question Grouping
```r
# Group columns by Q number
questions <- list()

for each column:
  if q_num not in questions:
    questions[[q_num]] <- new_question_group()
  
  questions[[q_num]]$columns <- append(column)
  questions[[q_num]]$q_id <- q_id
```

---

## Translation Export Parsing

### Key Patterns
```
q-{id}              → Question text
q-{id}-o-{code}     → Option text
q-{id}-otherText    → Other field prompt (ignore)
```

### Matching Logic
```r
# Match Q ID from data export to translation key
q_id <- 2  # from data export row 2
translation_key <- paste0("q-", q_id)  # becomes "q-2"

# Get options
option_keys <- grep(paste0("q-", q_id, "-o-"), translation$Key)
options <- translation[option_keys, "Default Text"]
```

---

## Word Doc Parsing

### Question Type Indicators
```r
if text contains "( )":
  type_hint <- "Single_Mention"
  
if text contains "[ ]":
  type_hint <- "Multi_Mention"
  
if text contains "rank":
  type_hint <- "Ranking"
```

### Question Text Extraction
```r
# Match by question number
# Extract full question text for QuestionText field
# Use for validation against data export
```

---

## Variable Type Classification

### Logic Flow
```r
classify_variable_type <- function(question) {
  
  # Check for NPS
  if (length(options) == 11 && all(options == 0:10) && 
      grepl("recommend", question_text, ignore.case = TRUE)) {
    return("NPS")
  }
  
  # Check for Likert
  if (any(grepl("disagree|neutral|agree", options, ignore.case = TRUE))) {
    return("Likert")
  }
  
  # Check for Rating
  if (length(options) %in% c(5, 7, 10) && 
      any(grepl("satisfied|dissatisfied", options, ignore.case = TRUE))) {
    return("Rating")
  }
  
  # Check slider
  if (question_type_from_word == "slider") {
    return("Numeric")
  }
  
  # Check for Ranking
  if (grepl("rank", question_text, ignore.case = TRUE) || 
      columns > 1 && is_sequential_data()) {
    return("Ranking")
  }
  
  # Check for Multi-Mention
  if (word_doc_has_brackets || columns > 1) {
    return("Multi_Mention")
  }
  
  # Check for Numeric
  if (question_type_from_word == "numeric box") {
    return("Numeric")
  }
  
  # Check for Open-End
  if (question_type_from_word == "textbox") {
    return("Open_End")
  }
  
  # Default
  return("Single_Mention")
}
```

---

## Output File 1: Crosstab_Config (Selection Sheet)

### Columns
```
A: QuestionCode        - Q01, Q02a, Q04_1, etc.
B: Include             - [blank]
C: UseBanner           - [blank]
D: BannerBoxCategory   - [blank]
E: BannerLabel         - [blank]
F: DisplayOrder        - [blank]
G: CreateIndex         - Y for NPS/Rating/Likert, N otherwise
H: BaseFilter          - [blank]
I: QuestionText        - Full question text
```

### Special Handling
```r
# Response ID
QuestionCode: "ResponseID"
Include: "N"

# Other mention fields
QuestionCode: "Q04_othermention"
Include: "N"
```

---

## Output File 2: Survey_Structure (Questions Sheet)

### Columns
```
A: QuestionCode        - Matches Crosstab_Config
B: QuestionText        - Matches Crosstab_Config
C: Variable_Type       - Single_Mention, Multi_Mention, etc.
D: Columns             - Number of data columns
E: Ranking_Format      - "position" if Ranking multi-column, else blank
F: Ranking_Positions   - [blank]
G: Ranking_Direction   - [blank]
H: Category            - [blank]
I: Notes               - [blank]
```

### Column Count Rules
```
Single_Mention: 1
Multi_Mention: N (number of options)
Rating: 1
NPS: 1
Numeric: 1
Open_End: 1
Ranking: N (number of positions)
Radio Grid Row: 1 per row
Checkbox Grid Row: N per row
```

### Question Code Mapping
```
Single question:     Q01
Radio grid:          Q02a, Q02b, Q02c (one per row)
Multi-mention:       Q04 (one question, multiple columns)
Checkbox grid:       Q09a, Q09b, Q09c (one per row)
Star rating grid:    Q13a, Q13b (one per item)
```

---

## Output File 3: Survey_Structure (Options Sheet)

### Columns
```
A: QuestionCode          - With column suffix for multi-column
B: OptionText            - Exact text from data
C: DisplayText           - Default to OptionText
D: DisplayOrder          - [blank]
E: ShowInOutput          - Y (default), N for othermention
F: ExcludeFromIndex      - Y for DK/NA in Likert/NPS/Rating
G: Index_Weight          - [blank]
H: BoxCategory           - [blank]
```

### Rules

**Single_Mention:**
```
QuestionCode: Q01
OptionText: Male
OptionText: Female
OptionText: Other
```

**Multi_Mention:**
```
QuestionCode: Q04_1
OptionText: play in sunny

QuestionCode: Q04_2
OptionText: play in cloudy

QuestionCode: Q04_3
OptionText: play in rainy

QuestionCode: Q04_othermention
OptionText: Other - Write In
ShowInOutput: N
```

**Radio Grid:**
```
QuestionCode: Q02a
OptionText: Happy
OptionText: neutral
OptionText: unhappy

QuestionCode: Q02b
OptionText: Happy
OptionText: neutral
OptionText: unhappy
```

**Checkbox Grid:**
```
QuestionCode: Q09a_1
OptionText: breakfast

QuestionCode: Q09a_2
OptionText: lunch

QuestionCode: Q09a_3
OptionText: dinner
```

**ExcludeFromIndex Logic:**
```
if Variable_Type in (Likert, NPS, Rating):
  if OptionText matches (Don't know|DK|Not applicable|NA|Dont know):
    ExcludeFromIndex <- Y
```

---

## Output File 4: Data Headers Row

### Format
```
Single CSV/text file with header row only:

ResponseID, Q01, Q02a, Q02b, Q02c, Q03, Q04_1, Q04_2, Q04_3, Q04_othermention, ...
```

### Purpose
- Drop into data file as column headers
- Replace Alchemer headers with clean codes
- Ensures exact match with Options sheet QuestionCode

---

## Grid Question Handling

### Radio Button Grid
```
Data Export:
  2: Tees:question
  2: greens:question
  2: fairways:question

Output:
  Questions Sheet:
    Q02a | text | Single_Mention | 1
    Q02b | text | Single_Mention | 1
    Q02c | text | Single_Mention | 1
  
  Options Sheet:
    Q02a | Happy
    Q02a | neutral
    Q02a | unhappy
    Q02b | Happy
    Q02b | neutral
    Q02b | unhappy
    Q02c | Happy
    Q02c | neutral
    Q02c | unhappy
```

### Checkbox Grid
```
Data Export:
  9: breakfast:eggs:question
  9: lunch:eggs:question
  9: dinner:eggs:question
  9: breakfast:burgers:question
  ...

Output:
  Questions Sheet:
    Q09a | eggs:question | Multi_Mention | 3
    Q09b | burgers:question | Multi_Mention | 3
    Q09c | salad:question | Multi_Mention | 3
  
  Options Sheet:
    Q09a_1 | breakfast
    Q09a_2 | lunch
    Q09a_3 | dinner
    Q09b_1 | breakfast
    Q09b_2 | lunch
    Q09b_3 | dinner
    Q09c_1 | breakfast
    Q09c_2 | lunch
    Q09c_3 | dinner
```

### Star Rating Grid
```
Data Export:
  13: kelvin:1:question
  13: Mowbray:1:question
  13: kelvin:2:question
  13: Mowbray:2:question
  ...

Output:
  Questions Sheet:
    Q13a | kelvin:question | Rating | 1
    Q13b | Mowbray:question | Rating | 1
  
  Options Sheet:
    Q13a | 1
    Q13a | 2
    Q13a | 3
    Q13a | 4
    Q13a | 5
    Q13b | 1
    Q13b | 2
    Q13b | 3
    Q13b | 4
    Q13b | 5
```

---

## Error Handling & Validation

### Flags for Review
```
- Conflicting type hints from different sources
- Missing option labels
- Duplicate column names (beyond expected othermention)
- Unmatched Q IDs between data export and translation
- Grid structure ambiguity
```

### Conflict Resolution Hierarchy
```
1. Data Export Map (column structure = truth)
2. Translation Export (option labels)
3. Word Doc (question text, type hints)
```

### Validation Checks
```r
# Check all Q numbers sequential
# Check all columns accounted for
# Check option counts match across sources
# Warn if DEFF-related issues (for future)
```

---

## Shiny GUI Requirements

### File Selection
```
1. User selects project directory
2. GUI scans for files: *_questionnaire.docx, *_data_export_map.xlsx, *_translation-export.xls
3. Extract project name from filenames
4. Validate all 3 files present
5. Remember last directory
```

### Preview Display
```
Show table with:
- QuestionCode
- QuestionText (truncated)
- Variable_Type
- Columns
- Flag (if needs review)

Allow sorting/filtering
```

### Download Options
```
Button 1: Download Crosstab_Config.xlsx
Button 2: Download Survey_Structure.xlsx
Button 3: Download Data_Headers.csv

All use project name in filename:
  {ProjectName}_Crosstab_Config.xlsx
  {ProjectName}_Survey_Structure.xlsx
  {ProjectName}_Data_Headers.csv
```

---

## Processing Steps

### Step 1: Load & Parse Data Export Map
```r
1. Read row 1 (Q numbers)
2. Read row 2 (Q IDs)
3. Skip column A
4. Parse each column header
5. Group by Q number
6. Store column structure
```

### Step 2: Load & Parse Translation Export
```r
1. Read Key and Default Text columns
2. Extract question texts (q-X)
3. Extract option texts (q-X-o-XXXXX)
4. Create lookup by Q ID
```

### Step 3: Load & Parse Word Doc
```r
1. Extract question numbers and text
2. Identify ( ) vs [ ] indicators
3. Find "rank" keywords
4. Extract full question text
5. Create lookup by Q number
```

### Step 4: Match & Merge
```r
1. For each Q number:
   - Get Q ID from data export
   - Get options from translation (via Q ID)
   - Get question text from word doc
   - Get type hints from word doc
2. Resolve conflicts using hierarchy
3. Store unified question object
```

### Step 5: Classify Variable Types
```r
1. Apply detection rules in order
2. Consider all hints from all sources
3. Flag ambiguous cases
```

### Step 6: Generate Question Codes
```r
1. Determine padding (Q01 vs Q001)
2. For each question:
   - Single column: Q##
   - Grid rows: Q##a, Q##b, Q##c
   - Multi-column: Q##_1, Q##_2
   - Grid multi-column: Q##a_1, Q##a_2
3. Handle othermention renaming
```

### Step 7: Generate Outputs
```r
1. Create Crosstab_Config Selection sheet
2. Create Survey_Structure Questions sheet
3. Create Survey_Structure Options sheet
4. Create Data Headers row
5. Write to Excel/CSV
```

---

## Special Cases

### Piped Questions
```
Treat as normal Single/Multi_Mention
Piping metadata not relevant for tabbing
```

### Duplicate Other Fields
```
First occurrence: Regular option
Second occurrence: Rename to _othermention, ShowInOutput=N
Third+ occurrence: Flag for review
```

### Missing Data
```
If translation export missing:
  - Use data export headers as option text
  - Flag for review

If word doc missing question:
  - Use data export question text
  - Flag for review
  
If data export ambiguous:
  - Use best guess
  - Flag for review
```

### Question Sections/Pages
```
Ignore (untitled), Thank You, and other non-question text
Do not create question entries
```

---

## Output File Specifications

### Crosstab_Config.xlsx Structure
```
Sheet: Selection
Columns: 9 (A-I as specified)
No header row formatting needed
```

### Survey_Structure.xlsx Structure
```
Sheet 1: Project (not created by parser - leave empty template)
Sheet 2: Questions (created by parser)
Sheet 3: Options (created by parser)
Sheet 4: Composite_Metrics (not created by parser - leave empty)
```

### Data_Headers.csv Structure
```
Single row
Comma-separated
No quotes unless text contains commas
Order matches column order in data export map
```

---

## Implementation Notes

### R Packages Required
```r
library(openxlsx)
library(readxl)
library(stringr)
library(dplyr)
library(tidyr)
library(officer)  # for Word doc parsing
library(shiny)
```

### Performance Targets
```
Parse 100 question survey in <10 seconds
Support up to 500 questions
Handle files up to 10MB
```

### Code Organization
```
modules/parser/
  ├── parse_data_map.R
  ├── parse_translation.R
  ├── parse_word_doc.R
  ├── classify_questions.R
  ├── generate_codes.R
  ├── create_outputs.R
  ├── gui_parser.R
  └── utils.R
```

---

## Detailed Parsing Algorithms

### Algorithm 1: Parse Data Export Map Column

**Input:** Single column header from data export map  
**Output:** Structured column object

```r
parse_column <- function(q_num_header, q_id_header, col_index) {
  
  # Extract Q numbers
  q_num <- str_extract(q_num_header, "^\\d+")
  q_id <- str_extract(q_id_header, "^\\d+")
  
  # Split header into parts (by colon)
  parts <- str_split(q_num_header, ":")[[1]]
  n_parts <- length(parts)
  
  # Determine structure
  if (n_parts == 2) {
    # Simple: "Q#: Question Text"
    return(list(
      col_index = col_index,
      q_num = q_num,
      q_id = q_id,
      structure = "simple",
      question_text = str_trim(parts[2]),
      row_label = NA,
      col_label = NA
    ))
  }
  
  if (n_parts == 3) {
    # Grid or Multi: "Q#: Row/Option:Question Text"
    return(list(
      col_index = col_index,
      q_num = q_num,
      q_id = q_id,
      structure = "grid_or_multi",
      question_text = str_trim(parts[3]),
      row_label = str_trim(parts[2]),
      col_label = NA
    ))
  }
  
  if (n_parts == 4) {
    # Checkbox Grid: "Q#: Col:Row:Question Text"
    return(list(
      col_index = col_index,
      q_num = q_num,
      q_id = q_id,
      structure = "checkbox_grid",
      question_text = str_trim(parts[4]),
      row_label = str_trim(parts[3]),
      col_label = str_trim(parts[2])
    ))
  }
  
  # Should not reach here
  stop(paste("Unexpected header format:", q_num_header))
}
```

### Algorithm 2: Group Columns by Question

**Input:** List of parsed columns  
**Output:** List of question groups

```r
group_columns <- function(parsed_columns) {
  
  questions <- list()
  
  for (col in parsed_columns) {
    q_num <- col$q_num
    
    if (!(q_num %in% names(questions))) {
      # New question
      questions[[q_num]] <- list(
        q_num = q_num,
        q_id = col$q_id,
        question_text = col$question_text,
        columns = list(),
        structure = col$structure
      )
    }
    
    # Add column to question
    questions[[q_num]]$columns <- append(
      questions[[q_num]]$columns, 
      list(col)
    )
  }
  
  return(questions)
}
```

### Algorithm 3: Detect Grid Type

**Input:** Question group with multiple columns  
**Output:** Grid type classification

```r
detect_grid_type <- function(question_group) {
  
  cols <- question_group$columns
  n_cols <- length(cols)
  
  # Single column = not a grid
  if (n_cols == 1) {
    return("single")
  }
  
  # Check if all columns have structure = "checkbox_grid"
  if (all(sapply(cols, function(c) c$structure == "checkbox_grid"))) {
    return("checkbox_grid")
  }
  
  # Check if all have same row_label pattern (different rows)
  row_labels <- unique(sapply(cols, function(c) c$row_label))
  
  if (length(row_labels) > 1 && all(!is.na(row_labels))) {
    # Different rows = radio grid
    return("radio_grid")
  }
  
  # Check if row_labels contain only numbers (1, 2, 3, 4, 5)
  if (all(!is.na(row_labels)) && 
      all(grepl("^\\d+$", row_labels))) {
    return("star_rating_grid")
  }
  
  # Otherwise multi-column question (multi-mention or ranking)
  return("multi_column")
}
```

### Algorithm 4: Pivot Checkbox Grid

**Input:** Question group with checkbox_grid type  
**Output:** List of sub-questions (one per row)

```r
pivot_checkbox_grid <- function(question_group) {
  
  cols <- question_group$columns
  
  # Extract unique rows and columns
  row_labels <- unique(sapply(cols, function(c) c$row_label))
  col_labels <- unique(sapply(cols, function(c) c$col_label))
  
  # Sort to ensure consistent order
  row_labels <- sort(row_labels)
  col_labels <- sort(col_labels)
  
  # Create sub-questions (one per row)
  sub_questions <- list()
  
  for (i in seq_along(row_labels)) {
    row <- row_labels[i]
    suffix <- letters[i]  # a, b, c, ...
    
    # Find columns for this row
    row_cols <- Filter(function(c) c$row_label == row, cols)
    
    # Sort by column label to ensure order
    row_cols <- row_cols[order(sapply(row_cols, function(c) c$col_label))]
    
    sub_questions[[suffix]] <- list(
      suffix = suffix,
      row_label = row,
      question_text = paste0(row, ":", question_group$question_text),
      columns = row_cols,
      col_labels = col_labels,
      variable_type = "Multi_Mention",
      n_columns = length(col_labels)
    )
  }
  
  return(sub_questions)
}
```

### Algorithm 5: Extract Options from Translation Export

**Input:** Q ID, Translation export data  
**Output:** List of options

```r
extract_options <- function(q_id, translation_data) {
  
  # Build pattern to match option keys
  pattern <- paste0("^q-", q_id, "-o-")
  
  # Find matching rows
  option_rows <- translation_data[grep(pattern, translation_data$Key), ]
  
  # Extract option codes and texts
  options <- list()
  
  for (i in 1:nrow(option_rows)) {
    key <- option_rows$Key[i]
    text <- option_rows$`Default Text`[i]
    
    # Extract option code (the number after -o-)
    code <- str_extract(key, "\\d+$")
    
    options[[i]] <- list(
      code = code,
      text = text,
      key = key
    )
  }
  
  return(options)
}
```

### Algorithm 6: Detect Other/Specify Fields

**Input:** Option text  
**Output:** TRUE if other field

```r
is_other_field <- function(option_text) {
  
  # Patterns that indicate other/specify field
  patterns <- c(
    "other.*write.*in",
    "other.*please.*specify",
    "other.*required",
    "^other.*:",
    "^other \\(.*\\)"
  )
  
  # Check if any pattern matches (case insensitive)
  for (pattern in patterns) {
    if (grepl(pattern, option_text, ignore.case = TRUE)) {
      return(TRUE)
    }
  }
  
  return(FALSE)
}
```

### Algorithm 7: Classify Variable Type

**Input:** Question group with all metadata  
**Output:** Variable type classification

```r
classify_variable_type <- function(question_group, options, word_doc_hints) {
  
  q_text <- tolower(question_group$question_text)
  n_cols <- length(question_group$columns)
  
  # 1. Check for NPS
  if (length(options) == 11) {
    option_values <- as.numeric(sapply(options, function(o) o$text))
    if (all(!is.na(option_values)) && 
        all(option_values == 0:10) &&
        grepl("recommend", q_text)) {
      return("NPS")
    }
  }
  
  # 2. Check for Likert
  option_texts <- tolower(sapply(options, function(o) o$text))
  likert_keywords <- c("disagree", "neutral", "agree", "strongly")
  if (any(sapply(likert_keywords, function(kw) any(grepl(kw, option_texts))))) {
    return("Likert")
  }
  
  # 3. Check for Rating
  rating_keywords <- c("satisfied", "dissatisfied", "poor", "excellent", 
                       "quality", "likely", "unlikely")
  if (any(sapply(rating_keywords, function(kw) any(grepl(kw, option_texts))))) {
    if (length(options) %in% c(5, 7, 10)) {
      return("Rating")
    }
  }
  
  # 4. Check for Slider/Numeric from word doc
  if (!is.null(word_doc_hints$type)) {
    if (word_doc_hints$type == "slider") {
      return("Numeric")
    }
    if (word_doc_hints$type == "numeric") {
      return("Numeric")
    }
    if (word_doc_hints$type == "textbox") {
      return("Open_End")
    }
  }
  
  # 5. Check for Ranking
  if (grepl("rank", q_text) || 
      (!is.null(word_doc_hints$has_rank_keyword) && word_doc_hints$has_rank_keyword)) {
    if (n_cols > 1) {
      return("Ranking")
    }
  }
  
  # 6. Check for Multi-Mention from word doc brackets
  if (!is.null(word_doc_hints$brackets)) {
    if (word_doc_hints$brackets == "[]") {
      return("Multi_Mention")
    }
  }
  
  # 7. Check for Multi-Mention from column structure
  if (n_cols > 1 && question_group$structure == "grid_or_multi") {
    # Check if columns have different option labels
    option_labels <- sapply(question_group$columns, function(c) c$row_label)
    if (length(unique(option_labels)) == length(option_labels)) {
      return("Multi_Mention")
    }
  }
  
  # 8. Default to Single-Mention
  return("Single_Mention")
}
```

### Algorithm 8: Generate Question Code

**Input:** Q number, grid type, row suffix, padding  
**Output:** Question code

```r
generate_question_code <- function(q_num, grid_type = "single", 
                                   row_suffix = NULL, padding = 2) {
  
  # Pad Q number
  q_padded <- str_pad(q_num, width = padding, pad = "0")
  base_code <- paste0("Q", q_padded)
  
  # Add suffix for grids
  if (grid_type %in% c("radio_grid", "checkbox_grid", "star_rating_grid")) {
    if (!is.null(row_suffix)) {
      return(paste0(base_code, row_suffix))
    }
  }
  
  return(base_code)
}
```

### Algorithm 9: Generate Option Codes

**Input:** Question code, variable type, options, column labels  
**Output:** List of option records for Options sheet

```r
generate_option_codes <- function(question_code, variable_type, 
                                  options, col_labels = NULL) {
  
  option_records <- list()
  
  if (variable_type == "Multi_Mention") {
    # One record per column
    for (i in seq_along(col_labels)) {
      
      # Check if this is an other field
      is_other <- is_other_field(col_labels[i])
      
      if (is_other) {
        q_code <- paste0(question_code, "_othermention")
        show_output <- "N"
      } else {
        q_code <- paste0(question_code, "_", i)
        show_output <- "Y"
      }
      
      option_records[[i]] <- list(
        QuestionCode = q_code,
        OptionText = col_labels[i],
        DisplayText = col_labels[i],
        DisplayOrder = NA,
        ShowInOutput = show_output,
        ExcludeFromIndex = NA,
        Index_Weight = NA,
        BoxCategory = NA
      )
    }
  } else {
    # Single-Mention, Rating, Likert, NPS
    # One record per option
    for (i in seq_along(options)) {
      opt <- options[[i]]
      
      # Check if should exclude from index
      exclude <- check_exclude_from_index(opt$text, variable_type)
      
      option_records[[i]] <- list(
        QuestionCode = question_code,
        OptionText = opt$text,
        DisplayText = opt$text,
        DisplayOrder = NA,
        ShowInOutput = "Y",
        ExcludeFromIndex = if(exclude) "Y" else NA,
        Index_Weight = NA,
        BoxCategory = NA
      )
    }
  }
  
  return(option_records)
}

check_exclude_from_index <- function(option_text, variable_type) {
  
  if (!(variable_type %in% c("Likert", "NPS", "Rating"))) {
    return(FALSE)
  }
  
  # Patterns for DK/NA options
  exclude_patterns <- c(
    "don't know",
    "dont know",
    "^dk$",
    "not applicable",
    "^na$",
    "prefer not"
  )
  
  opt_lower <- tolower(str_trim(option_text))
  
  for (pattern in exclude_patterns) {
    if (grepl(pattern, opt_lower)) {
      return(TRUE)
    }
  }
  
  return(FALSE)
}
```

### Algorithm 10: Parse Word Doc for Hints

**Input:** Word document  
**Output:** Question hints lookup

```r
parse_word_doc <- function(doc_path) {
  
  # Read document
  doc <- read_docx(doc_path)
  paragraphs <- docx_summary(doc)
  
  # Filter to paragraph text
  text_paras <- paragraphs[paragraphs$content_type == "paragraph", ]
  
  hints <- list()
  current_q_num <- NULL
  
  for (i in 1:nrow(text_paras)) {
    text <- text_paras$text[i]
    
    # Try to extract question number
    q_match <- str_match(text, "^\\s*(\\d+)\\)")
    if (!is.na(q_match[1, 2])) {
      current_q_num <- q_match[1, 2]
      hints[[current_q_num]] <- list(
        question_text = str_trim(str_remove(text, "^\\s*\\d+\\)")),
        brackets = NA,
        type = NA,
        has_rank_keyword = FALSE
      )
    }
    
    if (!is.null(current_q_num)) {
      # Check for brackets
      if (grepl("\\( \\)", text)) {
        hints[[current_q_num]]$brackets <- "()"
      }
      if (grepl("\\[ \\]", text)) {
        hints[[current_q_num]]$brackets <- "[]"
      }
      
      # Check for question type keywords
      if (grepl("slider", text, ignore.case = TRUE)) {
        hints[[current_q_num]]$type <- "slider"
      }
      if (grepl("numeric", text, ignore.case = TRUE)) {
        hints[[current_q_num]]$type <- "numeric"
      }
      if (grepl("textbox|text box", text, ignore.case = TRUE)) {
        hints[[current_q_num]]$type <- "textbox"
      }
      
      # Check for ranking keyword
      if (grepl("rank", text, ignore.case = TRUE)) {
        hints[[current_q_num]]$has_rank_keyword <- TRUE
      }
    }
  }
  
  return(hints)
}
```

### Decision Tree: Grid Type Classification

```
INPUT: Question group with multiple columns

├─ All columns have structure = "checkbox_grid"?
│  └─ YES → CHECKBOX_GRID
│      └─ Pivot by rows
│      └─ Each row becomes Multi_Mention question
│      └─ Code format: Q##a_1, Q##a_2, Q##b_1...
│
├─ Multiple unique row_labels AND structure = "grid_or_multi"?
│  └─ YES → Check row_label pattern
│      ├─ All row_labels are purely numeric (1,2,3,4,5)?
│      │  └─ YES → STAR_RATING_GRID
│      │      └─ Each unique non-numeric component = Rating question
│      │      └─ Code format: Q##a, Q##b (one per item)
│      │
│      └─ NO → RADIO_GRID
│          └─ Each row = Single_Mention question
│          └─ Code format: Q##a, Q##b, Q##c (one per row)
│
└─ ELSE → MULTI_COLUMN
    ├─ Check for "rank" keyword → RANKING
    │  └─ Code format: Q##_1, Q##_2, Q##_3
    │
    └─ Check for [ ] brackets or different options → MULTI_MENTION
       └─ Code format: Q##_1, Q##_2, Q##_3
```

### Decision Tree: Option Source Selection

```
INPUT: Question with variable type

├─ Variable Type = Multi_Mention?
│  └─ YES → Options come from column labels
│      ├─ For checkbox grid: col_labels from pivot
│      └─ For regular multi: row_labels from data export
│
├─ Variable Type = Single_Mention, Rating, Likert, NPS?
│  └─ YES → Options come from translation export
│      ├─ Match q-{Q_ID}-o-* keys
│      ├─ Extract Default Text
│      └─ Order by option code
│
├─ Variable Type = Numeric, Open_End?
│  └─ YES → No options sheet entries needed
│
└─ Variable Type = Ranking?
    └─ Options come from row_labels (item names)
        └─ Order by appearance in data export
```

### Decision Tree: Question Text Selection

```
INPUT: Question group with metadata from all sources

├─ Grid type (radio/checkbox/star)?
│  └─ YES → For each sub-question:
│      ├─ Include row label?
│      │  ├─ Checkbox grid: YES → "row:question"
│      │  ├─ Radio grid: NO → "question"
│      │  └─ Star rating: YES → "item:question"
│      │
│      └─ Source: data export question_text
│
└─ Single or Multi-column?
    ├─ Try word doc match first (by Q number)
    │  └─ Found? Use word doc text
    │
    └─ Else use data export question_text
```

### Validation Algorithm

```r
validate_parsing <- function(questions, translation_data, word_doc_hints) {
  
  flags <- list()
  
  for (q_num in names(questions)) {
    q <- questions[[q_num]]
    
    # Check 1: Q ID exists in translation export
    expected_key <- paste0("q-", q$q_id)
    if (!(expected_key %in% translation_data$Key)) {
      flags <- append(flags, list(list(
        q_num = q_num,
        issue = "Q_ID_NOT_FOUND_IN_TRANSLATION",
        severity = "WARNING"
      )))
    }
    
    # Check 2: Question text matches across sources
    if (!is.null(word_doc_hints[[q_num]])) {
      word_text <- word_doc_hints[[q_num]]$question_text
      data_text <- q$question_text
      
      # Fuzzy match (allow minor differences)
      similarity <- string_similarity(word_text, data_text)
      if (similarity < 0.7) {
        flags <- append(flags, list(list(
          q_num = q_num,
          issue = "TEXT_MISMATCH",
          severity = "REVIEW",
          details = paste("Word:", word_text, "| Data:", data_text)
        )))
      }
    }
    
    # Check 3: Option count consistency
    options <- extract_options(q$q_id, translation_data)
    expected_count <- length(options)
    
    if (q$variable_type == "Single_Mention" && expected_count == 0) {
      flags <- append(flags, list(list(
        q_num = q_num,
        issue = "NO_OPTIONS_FOUND",
        severity = "ERROR"
      )))
    }
    
    # Check 4: Grid structure ambiguity
    if (length(q$columns) > 1) {
      grid_type <- detect_grid_type(q)
      if (grid_type == "multi_column") {
        # Could be multi-mention OR ranking
        if (is.null(word_doc_hints[[q_num]]$has_rank_keyword)) {
          flags <- append(flags, list(list(
            q_num = q_num,
            issue = "AMBIGUOUS_MULTI_COLUMN",
            severity = "REVIEW",
            details = "Could be Multi_Mention or Ranking"
          )))
        }
      }
    }
  }
  
  return(flags)
}

string_similarity <- function(s1, s2) {
  # Simple similarity: proportion of matching words
  words1 <- tolower(str_split(s1, "\\s+")[[1]])
  words2 <- tolower(str_split(s2, "\\s+")[[1]])
  
  matches <- sum(words1 %in% words2)
  total <- length(unique(c(words1, words2)))
  
  return(matches / total)
}
```

### Complete Processing Pipeline

```r
# STEP 1: Load all files
data_map <- read_excel(data_map_file)
translation <- read_excel(translation_file)
word_hints <- parse_word_doc(word_doc_file)

# STEP 2: Parse data export map
row1 <- data_map[1, -1]  # Skip column A
row2 <- data_map[2, -1]

parsed_cols <- list()
for (i in 1:length(row1)) {
  parsed_cols[[i]] <- parse_column(row1[[i]], row2[[i]], i)
}

# STEP 3: Group by question
questions <- group_columns(parsed_cols)

# STEP 4: Classify each question
for (q_num in names(questions)) {
  q <- questions[[q_num]]
  
  # Detect grid type
  grid_type <- detect_grid_type(q)
  
  # Get options
  options <- extract_options(q$q_id, translation)
  
  # Get word doc hints
  hints <- word_hints[[q_num]]
  
  # Classify
  if (grid_type == "checkbox_grid") {
    # Pivot and create sub-questions
    sub_qs <- pivot_checkbox_grid(q)
    for (suffix in names(sub_qs)) {
      sub_q <- sub_qs[[suffix]]
      sub_q$variable_type <- "Multi_Mention"
      sub_q$q_code <- generate_question_code(q_num, grid_type, suffix)
    }
    questions[[q_num]]$sub_questions <- sub_qs
    
  } else if (grid_type == "radio_grid") {
    # Create sub-questions for each row
    rows <- unique(sapply(q$columns, function(c) c$row_label))
    sub_qs <- list()
    for (i in seq_along(rows)) {
      sub_qs[[letters[i]]] <- list(
        row_label = rows[i],
        variable_type = "Single_Mention",
        q_code = generate_question_code(q_num, grid_type, letters[i]),
        options = options
      )
    }
    questions[[q_num]]$sub_questions <- sub_qs
    
  } else if (grid_type == "star_rating_grid") {
    # Create sub-questions for each item
    items <- unique(sapply(q$columns, function(c) 
      str_remove(c$row_label, ":\\d+$")))
    sub_qs <- list()
    for (i in seq_along(items)) {
      sub_qs[[letters[i]]] <- list(
        item_label = items[i],
        variable_type = "Rating",
        q_code = generate_question_code(q_num, grid_type, letters[i]),
        options = 1:5  # Assuming 5-point scale
      )
    }
    questions[[q_num]]$sub_questions <- sub_qs
    
  } else {
    # Single or multi-column
    q$variable_type <- classify_variable_type(q, options, hints)
    q$q_code <- generate_question_code(q_num)
    q$options <- options
  }
}

# STEP 5: Validate
flags <- validate_parsing(questions, translation, word_hints)

# STEP 6: Generate outputs
crosstab_config <- generate_crosstab_config(questions)
survey_structure_questions <- generate_questions_sheet(questions)
survey_structure_options <- generate_options_sheet(questions)
data_headers <- generate_data_headers(questions)

# STEP 7: Write files
write.xlsx(crosstab_config, "Crosstab_Config.xlsx")
write.xlsx(list(Questions = survey_structure_questions,
                Options = survey_structure_options),
           "Survey_Structure.xlsx")
write.csv(data_headers, "Data_Headers.csv", row.names = FALSE)
```

---

## End of Specification

**Version:** 2.0  
**Last Updated:** 2025-11-20  
**Ready for:** Claude Code Implementation
