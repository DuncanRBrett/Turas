# Turas Parser - Comprehensive User Manual

**Version:** 1.0.0
**Last Updated:** 2025-11-17
**Module Type:** Survey Questionnaire Parser
**Difficulty Level:** Beginner to Intermediate

---

## Table of Contents

1. [Introduction](#introduction)
2. [Installation & Setup](#installation--setup)
3. [Getting Started](#getting-started)
4. [User Interfaces](#user-interfaces)
5. [Question Type Detection](#question-type-detection)
6. [Configuration Options](#configuration-options)
7. [Output Files](#output-files)
8. [Advanced Features](#advanced-features)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)
11. [Frequently Asked Questions](#frequently-asked-questions)

---

## 1. Introduction

### 1.1 What is Turas Parser?

The Turas Parser is a sophisticated tool that automatically converts Word document questionnaires into structured, machine-readable survey metadata. It eliminates the manual, error-prone process of transcribing questionnaire structures into spreadsheets.

**Key Capabilities:**
- Automatically detects question types (single response, multi-mention, rating, NPS, open-ended, numeric)
- Extracts question codes, text, and response options
- Identifies special features (bins, "other specify" options, numeric ranges)
- Generates Excel output compatible with Turas Tabs and Turas Tracker
- Flags questions that need manual review
- Handles complex questionnaire formats

### 1.2 Why Use the Parser?

**Without Parser (Manual Process):**
- ⏱️ 2-4 hours to manually enter a 50-question survey
- ❌ High error rate (typos, missed options, wrong types)
- 😓 Tedious, repetitive work
- 🔄 Must repeat for every questionnaire

**With Parser (Automated Process):**
- ⏱️ 5-10 minutes to parse and review a 50-question survey
- ✅ Consistent, accurate detection
- 😊 Automated intelligence
- 🚀 Reusable for similar questionnaires

### 1.3 How It Works

```
Word Document (.docx)
        ↓
   [Turas Parser]
    ├─ Read document text
    ├─ Detect question patterns
    ├─ Identify question types
    ├─ Extract options
    ├─ Detect bins & ranges
    ├─ Flag review items
    └─ Generate codes
        ↓
Excel Survey Structure
    └─> [Use in Tabs/Tracker]
```

---

## 2. Installation & Setup

### 2.1 Prerequisites

**R Version:** R 4.0.0 or higher recommended

**Required R Packages:**
```r
# Essential packages
install.packages("shiny")      # For GUI interface
install.packages("officer")    # For reading Word documents
install.packages("openxlsx")   # For writing Excel output

# Optional but recommended
install.packages("shinyjs")    # For enhanced GUI features
```

### 2.2 Installation

The parser is included in the Turas suite. No separate installation needed if you have Turas.

**Verify installation:**
```r
# Check if parser files exist
file.exists("modules/parser/run_parser.R")
file.exists("modules/parser/shiny_app.R")
```

### 2.3 First-Time Setup

No configuration required for basic use. The parser works out-of-the-box with default settings.

**Optional:** Create a workspace directory for your questionnaires:
```r
# Create organized directories
dir.create("questionnaires", showWarnings = FALSE)
dir.create("output/survey_structures", recursive = TRUE, showWarnings = FALSE)
```

---

## 3. Getting Started

### 3.1 Preparing Your Questionnaire

The parser works best with well-formatted Word documents. Follow these guidelines:

**✅ Good Questionnaire Format:**
```
Q1. What is your age?
   a) 18-24
   b) 25-34
   c) 35-44
   d) 45-54
   e) 55+

Q2. Which brands do you recall? [Check all that apply]
   a) Brand A
   b) Brand B
   c) Brand C
   d) Other (please specify): __________
```

**❌ Problematic Format:**
```
1. Age: ___ Gender: ___    [Multiple questions on one line]
```

### 3.2 Launching the Parser

**Method 1: Shiny GUI (Recommended)**
```r
# From Turas root directory
source("modules/parser/shiny_app.R")
# This opens a browser window with the GUI
```

**Method 2: Main Turas Launcher**
```r
source("launch_turas.R")
# Click on "Parser" module card
```

**Method 3: R Script**
```r
source("modules/parser/run_parser.R")
# Then call parsing functions directly
```

### 3.3 Your First Parse

1. Launch the Shiny GUI
2. Click **"Browse..."** and select your questionnaire (.docx file)
3. Leave default settings
4. Click **"Parse Questionnaire"**
5. Review results in tabs
6. Click **"Download Survey Structure (Excel)"**

---

## 4. User Interfaces

### 4.1 Shiny GUI Overview

The Shiny interface has 4 main tabs:

#### Configuration Tab
- **File Upload:** Select your .docx questionnaire
- **Parsing Options:** Configure detection settings
- **Parse Button:** Initiate parsing

#### Parsing Results Tab
- **Summary Statistics:** Question count by type
- **Success/Warning Messages:** Parsing status
- **Download Button:** Export Excel file

#### Questions Tab
- **Data Table:** All detected questions with details
- **Columns:** QuestionCode, QuestionText, QuestionType, Options, etc.
- **Searchable:** Filter questions quickly

#### Review Needed Tab
- **Flagged Questions:** Items requiring manual review
- **Reasons:** Why each question was flagged
- **Actions:** What to check/correct

### 4.2 GUI Controls

**File Upload:**
- Accepts `.docx` files only
- Maximum recommended size: 10 MB
- Displays filename when loaded

**Parsing Options:**

| Option | Default | Purpose |
|--------|---------|---------|
| Detect Format Hints | ✅ ON | Use [brackets] vs (parentheses) to determine type |
| Detect Bins | ✅ ON | Identify numeric bins (0-10, 1-5, etc.) |
| Question Code Prefix | "Q" | Prefix for generated codes (Q1, Q2...) |

**Output Options:**
- Download format: Excel (.xlsx)
- Filename: `Survey_Structure_[timestamp].xlsx`

---

## 5. Question Type Detection

### 5.1 Detection Algorithm

The parser uses a **priority-based detection system**:

1. **Format Hints** (highest priority if enabled)
   - `[brackets]` → Multi_Mention
   - `(parentheses)` → Single_Response

2. **Explicit Patterns**
   - "check all that apply" → Multi_Mention
   - "select all" → Multi_Mention
   - "please specify" → Open_Ended

3. **Numeric Patterns**
   - "0-10" with 11 options → NPS
   - "1-10" with 10 options → Rating
   - "how many" → Numeric

4. **Option Count**
   - < 12 options → Single_Response (unless format hint says otherwise)
   - ≥ 12 options → Multi_Mention

5. **Default**
   - No options detected → Open_Ended

### 5.2 Question Type Descriptions

#### Single_Response
**Description:** Respondent selects exactly ONE answer
**Common Uses:** Demographics, classification questions
**Example:**
```
Q1. What is your gender?
   (a) Male
   (b) Female
   (c) Prefer not to say
```
**Detection Criteria:**
- Parentheses around options: `(a), (b), (c)`
- OR: "select one", "choose one"
- OR: < 12 options and no multi-mention indicators

#### Multi_Mention
**Description:** Respondent can select MULTIPLE answers
**Common Uses:** Brand awareness, behavior checklists
**Example:**
```
Q2. Which of these brands do you own? [Check all that apply]
   [a] Brand A
   [b] Brand B
   [c] Brand C
```
**Detection Criteria:**
- Brackets around options: `[a], [b], [c]`
- OR: "check all", "select all"
- OR: ≥ 12 options

#### Rating
**Description:** Numeric scale, typically 1-5, 1-7, or 1-10
**Common Uses:** Satisfaction, agreement scales
**Example:**
```
Q3. How satisfied are you?
   1 = Very dissatisfied
   2 = Dissatisfied
   3 = Neutral
   4 = Satisfied
   5 = Very satisfied
```
**Detection Criteria:**
- Scale starts at 1 and goes to 5, 7, or 10
- Options are sequential numbers
- Exactly 5, 7, or 10 options

#### NPS (Net Promoter Score)
**Description:** 0-10 likelihood to recommend scale
**Common Uses:** Loyalty measurement
**Example:**
```
Q4. How likely are you to recommend us?
   0 = Not at all likely
   ...
   10 = Extremely likely
```
**Detection Criteria:**
- Scale from 0 to 10 (exactly 11 options)
- Contains "recommend" OR "likely"
- Sequential numeric options

#### Open_Ended
**Description:** Free-text response
**Common Uses:** Comments, explanations, verbatim feedback
**Example:**
```
Q5. What did you like most about the product?
   _________________________________
```
**Detection Criteria:**
- No options detected
- OR: "please specify", "explain", "describe"

#### Numeric
**Description:** Numeric entry field
**Common Uses:** Age, quantity, counts
**Example:**
```
Q6. How many times did you visit?
   _____ times
```
**Detection Criteria:**
- "how many", "number of"
- Blank with units (times, years, etc.)

### 5.3 Special Detections

**Bins (Numeric Ranges):**
Detected when options are numeric ranges:
```
Q7. What is your income?
   a) $0 - $25,000
   b) $25,001 - $50,000
   c) $50,001 - $75,000
```
**Result:** Marked as `IsBin = TRUE`, numeric ranges extracted

**"Other Specify" Options:**
Detected when option includes:
- "Other (please specify)"
- "Other (write in)"
- "Something else"

**Result:** Separate entry in "Othertext" sheet for follow-up field

### 5.4 Format Hints

**What are Format Hints?**
Visual indicators in the questionnaire that signal question type.

| Format | Type | Example |
|--------|------|---------|
| **(parentheses)** | Single_Response | (a) Option A |
| **[brackets]** | Multi_Mention | [a] Option A |

**When to Use:**
- ✅ When questionnaire uses consistent formatting
- ✅ When you want to override option count rules
- ❌ When questionnaire mixes formats inconsistently

**Enable/Disable:**
Toggle "Detect Format Hints" in Configuration tab

---

## 6. Configuration Options

### 6.1 Parsing Configuration

**`detect_format_hints`** (Boolean, default: TRUE)
- Use [brackets] and (parentheses) to determine question type
- Recommended: Keep ON unless format is inconsistent

**`detect_bins`** (Boolean, default: TRUE)
- Detect numeric ranges in options (e.g., 18-24, 25-34)
- Recommended: Keep ON for demographic questions

**`question_code_prefix`** (String, default: "Q")
- Prefix for generated question codes
- Examples: "Q" → Q1, Q2, Q3... / "QUEST" → QUEST1, QUEST2...

### 6.2 Advanced Configuration (R Script Only)

```r
config <- list(
  detect_format_hints = TRUE,
  detect_bins = TRUE,
  question_code_prefix = "Q",

  # Advanced options (for run_parser.R)
  permissive_mode = FALSE,        # Allow shorter question text
  max_option_length = 100,        # Maximum characters per option
  min_question_length = 30,       # Minimum characters for question
  max_question_length = 200       # Maximum characters for question
)
```

---

## 7. Output Files

### 7.1 Survey Structure Excel File

The parser generates a single Excel workbook with 4 sheets:

#### Sheet 1: Questions

**Purpose:** Main survey structure

| Column | Description | Example |
|--------|-------------|---------|
| `QuestionCode` | Unique identifier | Q1, Q2, Q3 |
| `QuestionText` | Full question text | "What is your age?" |
| `QuestionType` | Detected type | Single_Response |
| `Options` | Semicolon-separated options | "18-24; 25-34; 35-44" |
| `OptionCount` | Number of options | 3 |
| `IsBin` | Whether options are numeric ranges | TRUE/FALSE |
| `NumericRange` | Min-max if numeric | "18-44" |
| `ReviewNeeded` | Flag for manual review | TRUE/FALSE |
| `ReviewReason` | Why review is needed | "No options detected" |

**Typical row:**
```
QuestionCode: Q1
QuestionText: What is your age?
QuestionType: Single_Response
Options: 18-24; 25-34; 35-44; 45-54; 55+
OptionCount: 5
IsBin: TRUE
NumericRange: 18-55
ReviewNeeded: FALSE
```

#### Sheet 2: Options

**Purpose:** Detailed option list for use in cross-tabs

| Column | Description |
|--------|-------------|
| `QuestionCode` | Reference to question |
| `OptionCode` | Numeric code (1, 2, 3...) |
| `OptionText` | Full option text |
| `OptionOrder` | Display order |

**Example:**
```
QuestionCode | OptionCode | OptionText | OptionOrder
Q1           | 1          | 18-24      | 1
Q1           | 2          | 25-34      | 2
Q1           | 3          | 35-44      | 3
```

#### Sheet 3: Othertext

**Purpose:** Track "Other (specify)" fields

| Column | Description |
|--------|-------------|
| `QuestionCode` | Parent question |
| `OthertextCode` | Unique code for other field |
| `OthertextLabel` | Label text |

**Example:**
```
QuestionCode | OthertextCode | OthertextLabel
Q2           | Q2_Other      | Other (please specify)
```

#### Sheet 4: Metadata

**Purpose:** Project information and parsing settings

**Contents:**
- `Project_Name`: User-provided or "Untitled"
- `Client_Name`: User-provided or "Unknown"
- `Survey_Name`: Based on filename
- `Parse_Date`: Timestamp
- `Total_Questions`: Count
- `Parser_Version`: Module version
- `Settings_Used`: Configuration JSON

### 7.2 Using Output in Other Turas Modules

**Turas Tabs:**
```r
# Load survey structure
survey_structure <- read_excel("Survey_Structure.xlsx", sheet = "Questions")

# Use in tabs configuration
config <- create_tabs_config(
  survey_file = "data.xlsx",
  structure_file = "Survey_Structure.xlsx"
)
```

**Turas Tracker:**
```r
# Use as question mapping template
question_mapping <- read_excel("Survey_Structure.xlsx", sheet = "Questions") %>%
  select(QuestionCode, QuestionText, QuestionType)
```

---

## 8. Advanced Features

### 8.1 Handling Complex Questionnaires

**Multi-Part Questions:**
If a question has sub-parts:
```
Q10. For each brand, please rate:
   Q10a. Quality (1-10)
   Q10b. Value (1-10)
   Q10c. Service (1-10)
```

The parser treats each line as a separate question. **Manual editing** needed to:
1. Combine into grid question in output file
2. Adjust question codes (Q10_Quality, Q10_Value, Q10_Service)

**Grid Questions:**
Not automatically detected. Convert to:
- Separate questions (Q10a, Q10b, Q10c), OR
- Single multi-mention question with all combinations

**Conditional/Skip Logic:**
Parser doesn't handle routing. Notes like "If Q1=Yes, skip to Q5" are captured as part of question text.

**Recommendation:** Remove routing notes before parsing, or manually delete from output.

### 8.2 Customizing Question Codes

**Auto-generated codes:**
- Default: Q1, Q2, Q3...
- Sequential, based on detection order

**To customize:**
1. Parse with default codes
2. Open Excel output
3. Edit `QuestionCode` column manually
4. Ensure codes are unique

**Best Practice:** Use meaningful codes:
- Demographics: `DEM_AGE`, `DEM_GENDER`
- Brand questions: `BR_AWARE`, `BR_PREF`
- Satisfaction: `SAT_OVERALL`, `SAT_PRICE`

### 8.3 Batch Processing Multiple Questionnaires

```r
# Load parser
source("modules/parser/run_parser.R")

# List of questionnaires
questionnaires <- list.files("questionnaires/", pattern = "\\.docx$", full.names = TRUE)

# Process each
for (docx_file in questionnaires) {
  output_file <- gsub("\\.docx$", "_structure.xlsx", basename(docx_file))

  tryCatch({
    result <- parse_questionnaire(
      docx_path = docx_file,
      output_path = file.path("output", output_file)
    )
    cat("✓ Parsed:", docx_file, "\n")
  }, error = function(e) {
    cat("✗ Failed:", docx_file, "-", e$message, "\n")
  })
}
```

### 8.4 Integrating with Survey Platforms

**Exporting from Qualtrics:**
1. Export questionnaire as Word document
2. Clean up formatting (remove page breaks, unnecessary styling)
3. Parse with Turas Parser

**Exporting from SurveyMonkey:**
1. Copy questionnaire text to Word
2. Format with clear question numbering
3. Parse with Turas Parser

**Exporting from Google Forms:**
1. Not supported directly (no Word export)
2. Manual transcription to Word document needed

---

## 9. Troubleshooting

### 9.1 Common Errors

**Error: "Failed to read Word document"**

**Possible Causes:**
- File is corrupt
- File is password-protected
- File is not .docx format (e.g., .doc, .pdf)

**Solutions:**
1. Re-save file as .docx in Word
2. Remove password protection
3. Ensure file is not open in Word

---

**Error: "No questions detected in document"**

**Possible Causes:**
- Questions not numbered
- Format not recognized
- Empty document

**Solutions:**
1. Add question numbering (Q1, Q2, etc.)
2. Add blank lines between questions
3. Check "permissive_mode" in advanced config

---

**Warning: "Question X has no options - marked as Open_Ended"**

**Cause:** No structured options detected

**Solutions:**
- If question IS open-ended: Ignore warning
- If question SHOULD have options:
  - Check option formatting (use a), b), c) or 1., 2., 3.)
  - Ensure options are on separate lines
  - Manually add options in Excel output

---

**Warning: "Question type detection uncertain - please review"**

**Cause:** Ambiguous question format

**Action:**
- Check "Review Needed" tab in GUI
- Manually verify question type in Excel output
- Correct if needed

### 9.2 Performance Issues

**Symptom:** Parsing takes > 30 seconds

**Possible Causes:**
- Very large document (>100 pages)
- Complex formatting with many tables/images

**Solutions:**
1. Simplify Word document (remove tables, convert to text)
2. Split into multiple smaller documents
3. Increase R memory limit:
   ```r
   memory.limit(size = 8000)  # Windows only
   ```

### 9.3 Quality Checks

**Always verify these after parsing:**

1. **Question Count:** Does it match your expectation?
2. **Question Types:** Spot-check 5-10 questions for correct type
3. **Options:** Ensure all options captured for key questions
4. **Review Needed:** Address all flagged questions

---

## 10. Best Practices

### 10.1 Questionnaire Preparation

**Before Parsing:**
1. ✅ Use consistent numbering (Q1, Q2, Q3...)
2. ✅ Use consistent option labels within question (all a,b,c OR all 1,2,3)
3. ✅ Put each option on a new line
4. ✅ Add blank line between questions
5. ✅ Use format hints: (single) [multi]
6. ✅ Remove complex formatting (tables, columns, images)

**Formatting Standards:**
```
[GOOD EXAMPLE]

Q1. What is your age?
   a) 18-24
   b) 25-34
   c) 35-44

Q2. Which brands have you heard of? [Check all that apply]
   a) Brand A
   b) Brand B
   c) Brand C
```

### 10.2 Post-Parsing Workflow

1. **Parse** → Get initial structure
2. **Review** → Check "Review Needed" questions
3. **Correct** → Edit Excel file if needed
4. **Validate** → Spot-check types and options
5. **Save** → Keep original + corrected version
6. **Document** → Note any manual changes made

### 10.3 Quality Assurance

**Recommended Checks:**

| Check | How | Frequency |
|-------|-----|-----------|
| Question count | Compare to source | Every parse |
| Question types | Spot-check 10% | Every parse |
| Option counts | Check key questions | Every parse |
| Bins detected | Verify numeric ranges | If using bins |
| "Other" fields | Ensure all captured | If present |

**Create a checklist:**
```
□ All questions present (count matches)
□ No missing options on single/multi questions
□ Rating scales correct (1-5, 1-7, 1-10)
□ NPS detected correctly (0-10)
□ Demographics have bins if applicable
□ All "other specify" fields captured
□ Question codes are unique
```

---

## 11. Frequently Asked Questions

**Q: Can the parser handle PDF questionnaires?**
A: No, only .docx (Word) format is supported. Convert PDF to Word first.

**Q: What if my questionnaire uses Roman numerals (I, II, III)?**
A: Not directly supported. Recommendation: Find/Replace Roman numerals with Q1, Q2, Q3 before parsing.

**Q: Can I customize the Excel output format?**
A: The structure is fixed to ensure compatibility with Tabs/Tracker. However, you can edit the output Excel file manually.

**Q: How accurate is the parser?**
A: With well-formatted questionnaires, accuracy is typically 90-95%. Always review "Review Needed" questions.

**Q: Can it detect matrix/grid questions?**
A: Not as grids. They're detected as separate questions. Manual consolidation needed in output.

**Q: What about multi-language questionnaires?**
A: Supported if text is in Word document. The parser works with any language using standard formatting.

**Q: How do I handle questions with images?**
A: The parser extracts text only. Image-based questions will be detected as Open_Ended. Add option text manually.

**Q: Can I parse questionnaires from Qualtrics/SurveyMonkey?**
A: Yes, export to Word first, then parse. May need formatting cleanup.

**Q: What's the maximum questionnaire size?**
A: Tested up to 200 questions. Larger questionnaires may work but parsing time increases.

**Q: Can I reuse the output for similar surveys?**
A: Yes! Save the Excel file as a template and modify for similar questionnaires.

---

## Appendix A: Question Type Decision Tree

```
Start
  ↓
Has "check all that apply" or [brackets]?
  ├─ YES → Multi_Mention
  └─ NO
      ↓
    Has "recommend" and 0-10 scale?
      ├─ YES → NPS
      └─ NO
          ↓
        Has numeric scale 1-5, 1-7, or 1-10?
          ├─ YES → Rating
          └─ NO
              ↓
            Has structured options?
              ├─ YES
              │    ↓
              │  ≥ 12 options?
              │    ├─ YES → Multi_Mention
              │    └─ NO → Single_Response
              └─ NO
                   ↓
                 Has "how many" or numeric?
                   ├─ YES → Numeric
                   └─ NO → Open_Ended
```

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| **Bin** | Numeric range option (e.g., 18-24, 25-34) |
| **Format Hint** | Visual indicator in questionnaire: [brackets] or (parentheses) |
| **Multi_Mention** | Question where respondent can select multiple answers |
| **NPS** | Net Promoter Score - 0-10 recommendation scale |
| **Other Specify** | Option allowing respondent to write in alternative answer |
| **Question Code** | Unique identifier for each question (e.g., Q1, Q2) |
| **Rating** | Numeric scale question, typically 1-5, 1-7, or 1-10 |
| **Single_Response** | Question where respondent selects exactly one answer |
| **Survey Structure** | Structured metadata describing questionnaire (questions, types, options) |

---

## Support & Feedback

For additional help:
- **Technical Documentation:** See `TECHNICAL_DOCUMENTATION.md` for developer details
- **Workflow Examples:** See `EXAMPLE_WORKFLOWS.md` for real-world scenarios
- **Main Troubleshooting:** See `/docs/TROUBLESHOOTING.md` in Turas root

---

**End of User Manual**

*Version 1.0.0 | Turas Analytics Suite | © 2025*
