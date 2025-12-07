# User Manual: Turas AlchemerParser Module

Comprehensive guide to using AlchemerParser for converting Alchemer survey files into Tabs-ready configuration.

---

## Quick Start (10 Minutes)

Get your first Alchemer survey parsed and ready for Tabs in under 10 minutes.

### Prerequisites

Ensure you have R installed with the following packages:

```r
install.packages(c("readxl", "openxlsx", "officer", "shiny", "shinyFiles", "fs"))
```

### Step 1: Export Files from Alchemer (5 minutes)

You need to export three files from your Alchemer survey:

#### 1. Questionnaire Document

- Go to Survey → Build
- Click **Export** → **Print to Word**
- Save as: `{ProjectName}_questionnaire.docx`

#### 2. Data Export Map

- Go to Survey → Results → Data Exports
- Create new export with **Question Numbers** format
- Download the export mapping
- Save as: `{ProjectName}_data_export_map.xlsx`

Note this needs 2 rows Row1 = data export with Question number Row2 = data export with Question ID

This can be selected in setting in Alchemer export.

#### 3. Translation Export

- Go to Survey → Build → Translations
- Export **Default Language**
- Save as: `{ProjectName}_translation-export.xlsx`
- delete all rows below the thank you -

**Important:** All three files must use the same project name prefix.

### Step 2: Launch AlchemerParser GUI (1 minute)

**Option A: From Turas Launcher**

```r
setwd("/path/to/Turas")
source("launch_turas.R")
# Click "Launch AlchemerParser" in the GUI
```

**Option B: Direct Launch**

```r
setwd("/path/to/Turas")
source("modules/AlchemerParser/run_alchemerparser_gui.R")
# GUI will launch automatically
```

### Step 3: Select Project Directory (1 minute)

1. In the GUI, either:
   - Click **"Browse..."** to graphically navigate to your project folder, OR
   - Type the full path in the text box, OR
   - Select from recent projects dropdown (shows project names like "HV2025 (W2025/01_Setup)")
2. The parser will automatically detect the project name and validate files
3. You should see: **"✓ All required files found"**

### Step 4: Parse Files (1 minute)

1. Optionally adjust the **Project Name** or **Output Directory**
2. Click **"Parse Files"**
3. Wait for completion (typically 10-30 seconds)

The parser will:
- Detect question types (NPS, Likert, Rating, Single/Multi-Mention, etc.)
- Generate question codes (Q01, Q02a, Q04_1, etc.)
- Handle grid questions automatically
- Flag any ambiguous questions for review

### Step 5: Review Results (1 minute)

After parsing completes, review:

- **Question Preview Table**: Shows all detected questions with codes and types
- **Validation Flags**: Any items needing manual review
- **Summary**: Question type distribution

### Step 6: Download Outputs (1 minute)

Three files are automatically saved to your output directory:

1. **{ProjectName}_Crosstab_Config.xlsx** - For Tabs banner/crosstab setup
2. **{ProjectName}_Survey_Structure.xlsx** - For Tabs question/option mapping
3. **{ProjectName}_Data_Headers.xlsx** - Column headers for your data file

Click the download buttons to get copies, or find them in your output directory.

### Next Steps

You're now ready to use these files with the Tabs module!

1. Rename your data file columns using the `Data_Headers.xlsx` file
2. Load the config files into Tabs
3. Copy the data headers row into your data file and make sure the number of columns match
4. There may be errors so double check
5. Set up the rest of you config and survey structure
6. Run your cross-tabulation analysis

---

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
11. [Example Workflows](#example-workflows)

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
5. must repeat and for Question ID
6. create a file with data export with Question numbers in cell A1 - and the headers in cell B1 oonwards
then put data export with Question numbers in cell A2 and the headers inB2 onwards


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
- Variable Type (Single_Response, NPS, etc.)
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
| Variable_Type | Single_Response, Multi_Mention, NPS, Likert, Rating, Ranking, Numeric, Open_End |
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

6. **Single_Response**
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
- Q02a (Tees) - Single_Response
- Q02b (Greens) - Single_Response
- Q02c (Fairways) - Single_Response

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
- **No options for Single_Response:** Flags as ERROR
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
**Cause:** Single_Response question has no options in translation
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

### Issue: All questions classified as "Single_Response"
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

## Example Workflows

Real-world examples showing how to use AlchemerParser in different scenarios.

### Example 1: Basic Customer Satisfaction Survey

#### Scenario

You have a simple customer satisfaction survey with:
- 15 questions
- Mix of demographics, satisfaction ratings, and NPS
- No grids or complex structures

#### Input Files

```
CustomerSat2025_questionnaire.docx
CustomerSat2025_data_export_map.xlsx
CustomerSat2025_translation-export.xlsx
```

#### Using the GUI

1. Launch AlchemerParser from Turas launcher
2. Enter project directory: `/data/surveys/CustomerSat2025/`
3. Click "Parse Files"
4. Review results:
   - 15 questions detected
   - 2 NPS questions
   - 5 Rating questions
   - 8 Single_Response questions
   - 0 validation flags
5. Download all 3 output files
6. Proceed to Tabs module

**Time:** ~5 minutes

#### Using CLI

```r
setwd("/path/to/Turas")
source("modules/AlchemerParser/run_alchemerparser.R")

result <- run_alchemerparser(
  project_dir = "/data/surveys/CustomerSat2025/",
  verbose = TRUE
)

# Check results
cat(sprintf("Processed %d questions\n", result$summary$n_questions))
cat(sprintf("Validation flags: %d\n", result$summary$n_flags))

# Type distribution
print(result$summary$type_distribution)
#   NPS          Rating   Single_Response
#   2            5        8
```

### Example 2: Complex Grid Survey

#### Scenario

Employee engagement survey with multiple grid questions:
- Radio button grid: Rate departments (HR, IT, Finance) on multiple attributes
- Checkbox grid: Which benefits do you use? (Health, Dental, Vision) × (Self, Spouse, Children)
- Star rating grid: Rate your managers (5-point scale)

#### Challenge

Grid questions can be tricky to parse. AlchemerParser automatically detects and pivots them.

#### Using CLI with Detailed Review

```r
source("modules/AlchemerParser/run_alchemerparser.R")

result <- run_alchemerparser(
  project_dir = "/data/surveys/EmployeeEngagement/",
  verbose = TRUE
)

# Examine grid questions
for (q_num in names(result$questions)) {
  q <- result$questions[[q_num]]

  if (q$is_grid) {
    cat(sprintf("\nQ%s is a %s with %d sub-questions:\n",
                q_num, q$grid_type, length(q$sub_questions)))

    for (suffix in names(q$sub_questions)) {
      sub_q <- q$sub_questions[[suffix]]
      cat(sprintf("  - %s: %s (%s)\n",
                  sub_q$q_code,
                  substr(sub_q$question_text, 1, 40),
                  sub_q$variable_type))
    }
  }
}

# Output:
# Q05 is a radio_grid with 3 sub-questions:
#   - Q05a: HR Department (Single_Response)
#   - Q05b: IT Department (Single_Response)
#   - Q05c: Finance Department (Single_Response)
```

### Example 3: Batch Processing Multiple Surveys

#### Scenario

You have 12 monthly customer surveys to process at once.

#### Batch Processing Script

```r
source("modules/AlchemerParser/run_alchemerparser.R")

# Define all survey folders
months <- c("Jan2025", "Feb2025", "Mar2025", "Apr2025", "May2025", "Jun2025",
            "Jul2025", "Aug2025", "Sep2025", "Oct2025", "Nov2025", "Dec2025")

base_dir <- "/data/monthly_surveys"
output_dir <- "/data/outputs/parsed_configs"

# Create output directory
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Process each survey
results_log <- list()

for (month in months) {
  cat(sprintf("\n=== Processing %s ===\n", month))

  project_dir <- file.path(base_dir, month)
  month_output_dir <- file.path(output_dir, month)

  # Create month-specific output directory
  if (!dir.exists(month_output_dir)) {
    dir.create(month_output_dir)
  }

  # Run parser
  result <- tryCatch({
    run_alchemerparser(
      project_dir = project_dir,
      output_dir = month_output_dir,
      verbose = FALSE
    )
  }, error = function(e) {
    cat(sprintf("ERROR: %s\n", e$message))
    return(NULL)
  })

  if (!is.null(result)) {
    # Log results
    results_log[[month]] <- list(
      n_questions = result$summary$n_questions,
      n_columns = result$summary$n_columns,
      n_flags = result$summary$n_flags,
      types = result$summary$type_distribution
    )

    cat(sprintf("  ✓ Success: %d questions, %d flags\n",
                result$summary$n_questions,
                result$summary$n_flags))
  } else {
    results_log[[month]] <- list(error = TRUE)
    cat("  ✗ Failed\n")
  }
}

# Save detailed log
saveRDS(results_log, file.path(output_dir, "processing_log.rds"))
```

### Example 4: Handling Validation Flags

#### Scenario

Survey parsing completes with 3 validation flags. Need to review and resolve.

#### Workflow

```r
result <- run_alchemerparser(
  project_dir = "/data/surveys/ProductFeedback/",
  verbose = TRUE
)

# Examine flags in detail
for (i in seq_along(result$validation_flags)) {
  flag <- result$validation_flags[[i]]

  cat(sprintf("\n[Flag %d] %s - %s\n", i, flag$severity, flag$issue))
  cat(sprintf("  Question: %s\n", flag$q_code))
  cat(sprintf("  Details: %s\n", flag$details))
}

# Output:
# [Flag 1] WARNING - Q_ID_NOT_FOUND_IN_TRANSLATION
#   Question: Q08
#   Details: Q ID 15 not found in translation export
#
# [Flag 2] REVIEW - TEXT_MISMATCH
#   Question: Q12
#   Details: Word: 'How satisfied are you...' | Data: 'Please rate your satisfaction...'
#
# [Flag 3] REVIEW - AMBIGUOUS_MULTI_COLUMN
#   Question: Q14
#   Details: Classified as Multi_Mention but no Word doc confirmation
```

**Resolving Flags:**

**Flag 1: Q_ID_NOT_FOUND_IN_TRANSLATION** - Since question text is already populated from data export map, no action needed unless you want exact translation wording.

**Flag 2: TEXT_MISMATCH** - Open both files and compare actual text. If needed, manually edit `QuestionText` in Survey_Structure.xlsx.

**Flag 3: AMBIGUOUS_MULTI_COLUMN** - Check original Alchemer survey. If it's actually ranking, manually update `Variable_Type` in Survey_Structure.xlsx.

### Example 5: Real-World Testing - Helderberg Village HV2025

#### Background

This example demonstrates actual issues encountered during real-world testing with a resident satisfaction survey.

#### Issues Encountered and Solutions

**Issue 1: Open-Ended Question Misclassified**

**Problem:** Q03 (an open-ended question) was being classified as Single_Response instead of Open_End.

**Solution:** Updated classification hierarchy to check `if (n_options > 0)` before returning Single_Response. Questions with zero options now correctly default to Open_End.

**Issue 2: Radio Grid Options Missing**

**Problem:** Q06 sub-questions were showing 0 options in the Options sheet.

**Solution:** Implemented smart search strategy in `find_grid_options()`:
1. First try expected location
2. Try base question ID
3. Search nearby IDs (±2 to +10 range)
4. Fall back to common rating scale options if available

**Issue 3: Numeric Rating Scales Misclassified**

**Problem:** Q60 and Q65 (0-10 rating scales) were being classified as Single_Response instead of Rating.

**Solution:** Added numeric rating scale detection - check if ≥50% of options are numeric, classify as Rating if threshold met.

### Example 6: Real-World Testing - CCPB CSAT2025

#### Background

Customer satisfaction survey highlighting ranking question detection challenges.

#### Issues Encountered and Solutions

**Issue 1: Ranking Question Detected as Grid**

**Problem:** Q119 (a ranking question with 4 columns) was being detected as a radio_grid and split into Q119a, Q119b, Q119c, Q119d.

**Question Text:** "This is a ranking question - please rank the following 4 items from most important to least important."

**Solution:** Moved ranking detection BEFORE grid type detection in classification hierarchy.

**Result:**
```r
# Before fix:
Q119a | Variable_Type: Single_Response | Options: 4
Q119b | Variable_Type: Single_Response | Options: 4

# After fix:
Q119 | Variable_Type: Ranking | Columns: 4 | Options: 4
```

---

## Tips for Real-World Usage

### 1. Test on a Subset First

Before parsing a 200-question survey, test on a smaller subset:
- Export just the first 10-20 questions
- Verify parsing works correctly
- Check question type detection
- Then process the full survey

### 2. Keep Originals

Always keep your original Alchemer exports:
```
/project/
├── originals/          # Never modify these
│   ├── questionnaire.docx
│   ├── data_export_map.xlsx
│   └── translation-export.xlsx
├── parsed_outputs/     # Generated by AlchemerParser
└── final_configs/      # Manually edited versions
```

### 3. Version Control for Configs

If you manually edit parsed outputs:
```
BrandTracker_Survey_Structure_v1.xlsx  # Initial parse
BrandTracker_Survey_Structure_v2.xlsx  # After fixing flags
BrandTracker_Survey_Structure_v3.xlsx  # After client review
```

### 4. Document Custom Changes

If you customize outputs programmatically, save the R script with comments explaining your custom processing.

---

## Getting Help

- **Technical Docs:** See `TECHNICAL_DOCS.md` for code architecture and detailed parsing logic

---

**Version:** 1.0
**Last Updated:** 2025-11-20
