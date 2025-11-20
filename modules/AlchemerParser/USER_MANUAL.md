# User Manual: Turas AlchemerParser Module

Comprehensive guide to using AlchemerParser for converting Alchemer survey files into Tabs-ready configuration.

## Table of Contents

1. [Overview](#overview)
2. [Installation & Setup](#installation--setup)
3. [Input Files](#input-files)
4. [Using the GUI](#using-the-gui)
5. [Using the CLI](#using-the-cli)
6. [Understanding Output Files](#understanding-output-files)
7. [Question Type Detection](#question-type-detection)
8. [Handling Special Cases](#handling-special-cases)
9. [Validation Flags](#validation-flags)
10. [Troubleshooting](#troubleshooting)

---

## Overview

AlchemerParser automates the tedious process of setting up Tabs configuration files from Alchemer surveys. It:

- **Parses** three export files from Alchemer
- **Detects** question types automatically (NPS, Likert, Rating, Single/Multi-Mention, etc.)
- **Generates** standardized question codes
- **Handles** complex grid questions
- **Creates** three output files ready for Tabs module

**Time Savings:** What typically takes 2-4 hours manually can be done in under 10 minutes.

---

## Installation & Setup

### Required Packages

```r
install.packages(c("readxl", "openxlsx", "officer", "shiny", "shinyFiles", "fs"))
```

**Package Purposes:**
- `readxl`: Read Excel files (data export map, translation export)
- `openxlsx`: Write Excel output files
- `officer`: Read Word documents (questionnaire)
- `shiny`: Interactive GUI
- `shinyFiles`: Graphical folder browser in GUI
- `fs`: Cross-platform file system operations

### Module Location

The module is located in `Turas/modules/AlchemerParser/` with the following structure:

```
AlchemerParser/
├── R/                              # Core parsing functions
│   ├── 00_main.R
│   ├── 01_parse_data_map.R
│   ├── 02_parse_translation.R
│   ├── 03_parse_word_doc.R
│   ├── 04_classify_questions.R
│   ├── 05_generate_codes.R
│   └── 06_output.R
├── run_alchemerparser.R            # CLI mode
├── run_alchemerparser_gui.R        # GUI mode
└── [Documentation files]
```

---

## Input Files

AlchemerParser requires **three files** exported from Alchemer, all with the same project name prefix.

### 1. Questionnaire Document

**File Name:** `{ProjectName}_questionnaire.docx`

**How to Export:**
1. Go to **Survey → Build**
2. Click **Export** → **Print to Word**
3. Save the Word document

**What It Contains:**
- Question numbers and text
- Question type indicators:
  - `( )` = Single choice (radio buttons)
  - `[ ]` = Multiple choice (checkboxes)
  - "rank" keyword = Ranking question
- Full question wording

**Why We Need It:**
- Confirms question types
- Provides full question text
- Identifies ranking questions

### 2. Data Export Map

**File Name:** `{ProjectName}_data_export_map.xlsx`

**How to Export:**
1. Go to **Survey → Results → Data Exports**
2. Create a new export or edit existing
3. Set format to **Question Numbers** (not Question IDs only)
4. Download the **mapping file** (not the actual data)

**What It Contains:**
- Row 1: Question numbers (1:, 2:, 3:...)
- Row 2: Question IDs (2:, 3:, 7:...)
- Column headers showing question structure

**Why We Need It:**
- Maps questions to data columns
- Shows multi-column questions (grids, multi-mention)
- Provides the actual data structure

### 3. Translation Export

**File Name:** `{ProjectName}_translation-export.xlsx`

**How to Export:**
1. Go to **Survey → Build → Translations**
2. Click **Export**
3. Select **Default Language** (usually English)
4. Download the Excel file

**What It Contains:**
- Column A: Keys (q-2, q-3-o-10001, etc.)
- Column B: Question and option text

**Why We Need It:**
- Provides option labels for single/multi-choice questions
- Links question IDs to text

---

## Using the GUI

The GUI provides an interactive interface for parsing Alchemer files.

### Launching the GUI

**Option 1: From Turas Launcher**
```r
setwd("/path/to/Turas")
source("launch_turas.R")
```
Then click **"Launch AlchemerParser"**

**Option 2: Direct Launch**
```r
source("modules/AlchemerParser/run_alchemerparser_gui.R")
```

### GUI Workflow

#### Step 1: Select Project Directory

You have three options for selecting your project folder:

1. **Browse Graphically**: Click the **"Browse..."** button to open a folder picker and navigate visually
2. **Type Path**: Enter the full path directly in the text box
3. **Recent Projects**: Select from the dropdown showing recent projects (displays as "ProjectName (parent/folder)")
   - Example: `HV2025 (W2025/01_Setup)` vs `CCPB_CSAT2025 (CSAT2025/01_Setup)`
   - Prevents confusion when multiple projects are in similarly-named folders

The GUI validates files and displays status:
- ✓ Green = All files found
- ⚠ Yellow = Missing files
- ✗ Red = Invalid directory

#### Step 2: Configure Options

- **Project Name**: Auto-detected, but you can override
- **Output Directory**: Defaults to project directory, or specify custom location

#### Step 3: Parse Files

Click **"Parse Files"** to run the parser. Progress is shown in real-time.

#### Step 4: Review Results

The GUI displays:

**Question Preview Table:**
- Question Code (Q01, Q02a, etc.)
- Question Text (truncated)
- Variable Type (Single_Mention, NPS, etc.)
- Number of data columns

**Validation Flags Table:**
- Issues requiring manual review
- Severity levels (ERROR, WARNING, REVIEW)
- Specific details about each issue

#### Step 5: Download Outputs

Three download buttons provide the output files:
1. **Download Crosstab_Config** - Tabs selection sheet
2. **Download Survey_Structure** - Tabs questions/options
3. **Download Data_Headers** - Column rename template

---

## Using the CLI

For batch processing or scripting, use the CLI mode.

### Basic Usage

```r
# Source the module
setwd("/path/to/Turas")
source("modules/AlchemerParser/run_alchemerparser.R")

# Run parser
results <- run_alchemerparser(
  project_dir = "/path/to/alchemer/exports",
  project_name = "MySurvey",  # Optional
  output_dir = "/path/to/outputs",  # Optional
  verbose = TRUE  # Print progress
)
```

### CLI Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `project_dir` | Yes | - | Directory containing the 3 input files |
| `project_name` | No | Auto-detected | Project name prefix |
| `output_dir` | No | `project_dir` | Where to save output files |
| `verbose` | No | `TRUE` | Print progress messages |

### Return Value

The function returns a list with:

```r
results$questions            # Parsed question structure
results$validation_flags     # List of issues found
results$outputs$crosstab_config      # Path to crosstab file
results$outputs$survey_structure     # Path to survey structure file
results$outputs$data_headers         # Path to headers file
results$summary$n_questions          # Total questions
results$summary$n_columns            # Total data columns
results$summary$n_flags              # Number of validation flags
results$summary$type_distribution    # Question types count
```

### Example: Batch Processing

```r
# Process multiple projects
projects <- c("Survey_A", "Survey_B", "Survey_C")

for (proj in projects) {
  cat(sprintf("\nProcessing %s...\n", proj))

  result <- run_alchemerparser(
    project_dir = file.path("/data/alchemer", proj),
    output_dir = file.path("/data/outputs", proj),
    verbose = FALSE
  )

  # Log results
  cat(sprintf("  Questions: %d | Flags: %d\n",
              result$summary$n_questions,
              result$summary$n_flags))
}
```

---

## Understanding Output Files

### 1. Crosstab_Config.xlsx

**Purpose:** Configuration for Tabs cross-tabulation module

**Sheet: Selection**

| Column | Description | Values |
|--------|-------------|--------|
| QuestionCode | Unique question identifier | Q01, Q02a, Q04_1, etc. |
| Include | Whether to include in output | Blank (user fills in) |
| UseBanner | Use as banner variable | Blank (user fills in) |
| BannerBoxCategory | Banner grouping | Blank (user fills in) |
| BannerLabel | Custom banner label | Blank (user fills in) |
| DisplayOrder | Sort order | Blank (user fills in) |
| CreateIndex | Auto-create index | Y for NPS/Likert/Rating, N otherwise |
| BaseFilter | Filter condition | Blank (user fills in) |
| QuestionText | Full question text | From parsing |

**Special Rows:**
- `ResponseID` with Include=N (system variable)
- `Q##_othermention` with Include=N (other/specify fields)

### 2. Survey_Structure.xlsx

**Purpose:** Question and option definitions for Tabs

**Sheet: Questions**

| Column | Description |
|--------|-------------|
| QuestionCode | Unique identifier |
| QuestionText | Full question text |
| Variable_Type | Single_Mention, Multi_Mention, NPS, Likert, Rating, Ranking, Numeric, Open_End |
| Columns | Number of data columns |
| Ranking_Format | "position" for ranking questions, blank otherwise |
| Ranking_Positions | Blank (user fills if needed) |
| Ranking_Direction | Blank (user fills if needed) |
| Category | Blank (user grouping) |
| Notes | Blank (user notes) |

**Sheet: Options**

| Column | Description |
|--------|-------------|
| QuestionCode | Links to Questions sheet |
| OptionText | Option label from survey |
| DisplayText | Defaults to OptionText (user can override) |
| DisplayOrder | Blank (user fills for custom sorting) |
| ShowInOutput | Y by default, N for othermention fields |
| ExcludeFromIndex | Y for DK/NA in Likert/NPS/Rating |
| Index_Weight | Blank (user fills for weighted indexes) |
| BoxCategory | Blank (user fills for boxed categories) |

### 3. Data_Headers.xlsx

**Purpose:** Column headers to replace Alchemer's default names in your data file

**Format:** Single row with column names in the correct order

**Example:**
```
ResponseID | Q01 | Q02a | Q02b | Q02c | Q03 | Q04_1 | Q04_2 | Q04_3 | Q04_othermention | ...
```

**How to Use:**
1. Open your Alchemer data export
2. Copy the header row from Data_Headers.xlsx
3. Paste it as the first row in your data file
4. Delete Alchemer's original header row
5. Save as CSV

---

## Question Type Detection

AlchemerParser uses a hierarchical detection system to classify questions.

### Detection Hierarchy

Questions are classified in this order:

1. **NPS (Net Promoter Score)**
   - 11 options (0-10)
   - Question text contains "recommend"

2. **Likert**
   - Options contain agreement scales: disagree, neutral, agree

3. **Rating**
   - 5, 7, 10, or 11-point scales
   - Options contain: satisfied, poor, excellent, quality, likely
   - **OR** ≥50% of options are numeric (e.g., 0-10, 1-5, 1-3 + "Don't know")
   - Numeric rating scales are automatically detected and classified as Rating

4. **Ranking**
   - **Detected BEFORE grid classification** to avoid false positives
   - Question text contains: "ranking question", "most to least", "least to most"
   - OR contains "rank", "ranking", "prioritize" keywords
   - Multiple columns represent ranking positions (1st choice, 2nd choice, etc.)
   - **Note:** "multi mention" in question text takes precedence over ranking

5. **Multi_Mention**
   - Question text explicitly says "(multi mention" or "select all"
   - OR Word doc has `[ ]` brackets
   - OR multiple columns with different option labels

6. **Single_Mention**
   - Word doc has `( )` brackets
   - OR single column with options
   - Default for most radio button questions

7. **Numeric**
   - Numeric input box
   - Slider without fixed scale

8. **Open_End**
   - Text box / essay question
   - Excluded from Tabs analysis

### Grid Question Detection

The parser automatically handles three types of grids:

#### Radio Button Grid
**Structure:** Multiple rows, single choice per row

**Example:** Rate satisfaction with:
- Tees (Happy / Neutral / Unhappy)
- Greens (Happy / Neutral / Unhappy)
- Fairways (Happy / Neutral / Unhappy)

**Output:**
- Q02a (Tees) - Single_Mention
- Q02b (Greens) - Single_Mention
- Q02c (Fairways) - Single_Mention

#### Checkbox Grid
**Structure:** Multiple rows, multiple choices per row

**Example:** When do you eat:
- Eggs (Breakfast / Lunch / Dinner)
- Burgers (Breakfast / Lunch / Dinner)
- Salad (Breakfast / Lunch / Dinner)

**Output:**
- Q09a (Eggs) - Multi_Mention with Q09a_1, Q09a_2, Q09a_3
- Q09b (Burgers) - Multi_Mention with Q09b_1, Q09b_2, Q09b_3
- Q09c (Salad) - Multi_Mention with Q09c_1, Q09c_2, Q09c_3

#### Star Rating Grid
**Structure:** Multiple items rated on same scale

**Example:** Rate these hotels (1-5 stars):
- Kelvin Hotel
- Mowbray Inn

**Output:**
- Q13a (Kelvin) - Rating
- Q13b (Mowbray) - Rating

### Grid Options Finding

Alchemer stores grid options inconsistently across different surveys. AlchemerParser uses a smart search strategy:

**Standard Pattern** (most common):
- Options stored at question ID = `base_id + num_rows`
- Example: Q6 (ID 9) with 4 rows → options at ID 13

**When Standard Pattern Fails:**
1. **Try base ID**: Check if options are at the grid's own ID
2. **Search nearby IDs**: Check IDs from `expected - 2` to `expected + 10`
3. **Fallback to shared scale**: Look for common 0-10 + "Don't know" rating scale in translation file

**Why This Matters:**
- Real survey data (e.g., Helderberg Village) had options at ID 260 instead of expected ID 258
- CCPB CSAT had options at ID 23 instead of expected ID 22
- The parser finds them automatically without manual intervention

**Row Order Preservation:**
Grid rows appear in the same order as the data export map (not alphabetically sorted)

---

## Handling Special Cases

### Other/Specify Fields

When AlchemerParser detects an "Other - Write In" or "Please Specify" option:

1. The column is renamed to `Q##_othermention`
2. `ShowInOutput` is set to `N`
3. The field is excluded from analysis

**Manual Override:** If you want to include these fields, edit Survey_Structure.xlsx and set `ShowInOutput=Y`.

### DK/NA Options

For Likert, NPS, and Rating questions, options like:
- "Don't know"
- "DK"
- "Not applicable"
- "NA"
- "Prefer not to answer"

Are automatically flagged with `ExcludeFromIndex=Y` to prevent skewing index calculations.

### Question Code Padding

- **< 100 questions:** Codes use 2 digits (Q01, Q02, Q03, ...)
- **≥ 100 questions:** Codes use 3 digits (Q001, Q002, Q003, ...)

This ensures proper alphabetical sorting.

### Missing or Ambiguous Data

If the parser encounters:
- **Missing translation for a question:** Uses data export map text, flags for review
- **No options for Single_Mention:** Flags as ERROR
- **Ambiguous multi-column:** Flags as REVIEW if Word doc doesn't clarify

---

## Validation Flags

The parser flags issues that may need manual review.

### Severity Levels

| Severity | Meaning | Action Required |
|----------|---------|-----------------|
| ERROR | Critical issue that must be fixed | Must address before using in Tabs |
| WARNING | Potential problem | Review recommended |
| REVIEW | Ambiguous classification | Verify classification is correct |

### Common Flags

#### "Q_ID_NOT_FOUND_IN_TRANSLATION"
**Severity:** WARNING
**Cause:** Question ID from data export map not found in translation file
**Fix:** Check that translation export is complete, or add question text manually

#### "TEXT_MISMATCH"
**Severity:** REVIEW
**Cause:** Question text differs between Word doc and data export
**Fix:** Review both sources and use the correct text

#### "NO_OPTIONS_FOUND"
**Severity:** ERROR
**Cause:** Single_Mention question has no options in translation
**Fix:** Check translation export or verify question type

#### "AMBIGUOUS_MULTI_COLUMN"
**Severity:** REVIEW
**Cause:** Multi-column question classified as Multi_Mention or Ranking without Word doc confirmation
**Fix:** Verify question type in original survey

---

## Known Issues

### Othermention Text Field Naming (Non-Critical)

**Issue:** Multi-mention questions with "Other - Write In" options may create duplicate column labels in the data export map.

**Example:**
- Column 17: "Other - Write In (Required)" (checkbox)
- Column 18: "Other - Write In (Required)" (text field)

**Current Behavior:**
- Detected as duplicate
- Renamed to `Q32_16othertext`
- Column count may show 16 instead of 17

**Ideal Behavior:**
- Checkbox: `Q32_17`
- Text field: `Q32_17text`
- Column count: 17

**Workaround:** Manually rename codes in output files if needed. This is a cosmetic issue and doesn't affect Tabs functionality.

**Status:** Low priority - does not impact analysis

---

## Troubleshooting

### Issue: "Directory not found"
**Cause:** Invalid path entered
**Fix:** Use full absolute path (e.g., `/Users/name/Documents/Alchemer/Survey1`)

### Issue: "Questionnaire file not found"
**Cause:** Missing or incorrectly named Word document
**Fix:**
- Ensure file ends with `_questionnaire.docx`
- Check project name matches other files
- Verify file is in the project directory

### Issue: "Translation file missing required columns"
**Cause:** Translation export format changed
**Fix:**
- Re-export from Alchemer
- Ensure columns are named "Key" and "Default Text"

### Issue: All questions classified as "Single_Mention"
**Cause:** Word questionnaire file not being read correctly
**Fix:**
- Ensure file is .docx format (not .doc)
- Check that question numbers are formatted as "1)" or "1."

### Issue: Grid questions not detected
**Cause:** Data export map structure not recognized
**Fix:**
- Verify you exported the mapping file (not just data)
- Ensure export format is "Question Numbers"

### Issue: Parser runs but creates empty output
**Cause:** No valid questions found
**Fix:**
- Check data export map has data in rows 1-2
- Verify translation export has q-# keys

---

## Best Practices

1. **Consistent Naming:** Use the same project name for all three files
2. **Export Fresh:** Always export files fresh from Alchemer (don't use old versions)
3. **Review Flags:** Always review validation flags before using outputs in Tabs
4. **Test Small First:** Test on a small survey (10-20 questions) before processing large surveys
5. **Keep Originals:** Save your original Alchemer exports in case you need to re-parse

---

## Getting Help

- **Technical Docs:** See `TECHNICAL_DOCUMENTATION.md` for code architecture and detailed parsing logic
- **Examples:** See `EXAMPLE_WORKFLOWS.md` for real-world scenarios

---

**Version:** 1.0
**Last Updated:** 2025-11-20
