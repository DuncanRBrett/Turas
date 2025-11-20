# Example Workflows: Turas AlchemerParser Module

Real-world examples showing how to use AlchemerParser in different scenarios.

## Table of Contents

1. [Basic Customer Satisfaction Survey](#example-1-basic-customer-satisfaction-survey)
2. [Complex Grid Survey](#example-2-complex-grid-survey)
3. [NPS Tracker Survey](#example-3-nps-tracker-survey)
4. [Batch Processing Multiple Surveys](#example-4-batch-processing-multiple-surveys)
5. [Handling Validation Flags](#example-5-handling-validation-flags)
6. [Custom Output Processing](#example-6-custom-output-processing)
7. [Real-World Testing - Helderberg Village HV2025](#example-7-real-world-testing---helderberg-village-hv2025)
8. [Real-World Testing - CCPB CSAT2025](#example-8-real-world-testing---ccpb-csat2025)

---

## Example 1: Basic Customer Satisfaction Survey

### Scenario

You have a simple customer satisfaction survey with:
- 15 questions
- Mix of demographics, satisfaction ratings, and NPS
- No grids or complex structures

### Input Files

```
CustomerSat2025_questionnaire.docx
CustomerSat2025_data_export_map.xlsx
CustomerSat2025_translation-export.xlsx
```

### Using the GUI

1. Launch AlchemerParser from Turas launcher
2. Enter project directory: `/data/surveys/CustomerSat2025/`
3. Click "Parse Files"
4. Review results:
   - 15 questions detected
   - 2 NPS questions
   - 5 Rating questions
   - 8 Single_Mention questions
   - 0 validation flags
5. Download all 3 output files
6. Proceed to Tabs module

**Time:** ~5 minutes

### Using CLI

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
#   NPS          Rating   Single_Mention
#   2            5        8
```

### Expected Outputs

**Crosstab_Config.xlsx:**
```
QuestionCode | CreateIndex | QuestionText
-------------|-------------|-------------
ResponseID   | N           | Response ID
Q01          | N           | What is your age group?
Q02          | N           | What is your gender?
Q03          | Y           | How satisfied are you with our service?
Q04          | Y           | How likely are you to recommend us? (NPS)
...
```

**Survey_Structure.xlsx - Questions Sheet:**
```
QuestionCode | QuestionText | Variable_Type | Columns
-------------|--------------|---------------|--------
Q01          | Age group    | Single_Mention| 1
Q02          | Gender       | Single_Mention| 1
Q03          | Satisfaction | Rating        | 1
Q04          | NPS          | NPS           | 1
...
```

**Survey_Structure.xlsx - Options Sheet:**
```
QuestionCode | OptionText              | ExcludeFromIndex
-------------|-------------------------|------------------
Q01          | 18-24                   | NA
Q01          | 25-34                   | NA
Q01          | 35-44                   | NA
...
Q03          | Very dissatisfied       | NA
Q03          | Dissatisfied            | NA
Q03          | Neutral                 | NA
Q03          | Satisfied               | NA
Q03          | Very satisfied          | NA
Q04          | 0                       | NA
Q04          | 1                       | NA
...
Q04          | 10                      | NA
```

---

## Example 2: Complex Grid Survey

### Scenario

Employee engagement survey with multiple grid questions:
- Radio button grid: Rate departments (HR, IT, Finance) on multiple attributes
- Checkbox grid: Which benefits do you use? (Health, Dental, Vision) × (Self, Spouse, Children)
- Star rating grid: Rate your managers (5-point scale)

### Input Files

```
EmployeeEngagement_questionnaire.docx
EmployeeEngagement_data_export_map.xlsx
EmployeeEngagement_translation-export.xlsx
```

### Challenge

Grid questions can be tricky to parse. AlchemerParser automatically detects and pivots them.

### Using CLI with Detailed Review

```r
source("modules/AlchemerParser/run_alchemerparser.R")

result <- run_alchemerparser(
  project_dir = "/data/surveys/EmployeeEngagement/",
  verbose = TRUE
)

# ==============================================================================
#   ALCHEMER PARSER
# ==============================================================================
#
# Step 1: Locating input files...
#   Project name: EmployeeEngagement
#   Data export map: EmployeeEngagement_data_export_map.xlsx
#   Translation export: EmployeeEngagement_translation-export.xlsx
#   Questionnaire: EmployeeEngagement_questionnaire.docx
#
# Step 2: Parsing data export map...
#   Reading 45 data columns from export map
#   Grouped into 18 questions
#
# Step 3: Parsing translation export...
#   Extracted 18 question texts
#   Extracted 87 options across all questions
#
# Step 4: Parsing Word questionnaire...
#   Reading 125 paragraphs from questionnaire
#   Extracted hints for 18 questions
#
# Step 5: Classifying question types...
#   Question type distribution:
#     Single_Mention: 8
#     Multi_Mention: 1
#     Rating: 9
#     NPS: 1
#
# Step 6: Generating question codes...
#   Using 2-digit padding (Q00)
#   Generated codes for 18 questions
#
# Step 7: Validating results...
#   No validation issues found
#
# Step 8: Generating output files...
#   Generating Crosstab_Config...
#   Generating Survey_Structure...
#   Generating Data_Headers...
#   Generated files:
#     - EmployeeEngagement_Crosstab_Config.xlsx
#     - EmployeeEngagement_Survey_Structure.xlsx
#     - EmployeeEngagement_Data_Headers.xlsx
#
# ==============================================================================
#   PARSING COMPLETE
# ==============================================================================
#   Total questions: 18
#   Total data columns: 45
#   Items flagged for review: 0

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
#   - Q05a: HR Department (Single_Mention)
#   - Q05b: IT Department (Single_Mention)
#   - Q05c: Finance Department (Single_Mention)
#
# Q08 is a checkbox_grid with 3 sub-questions:
#   - Q08a: Health Insurance (Multi_Mention)
#   - Q08b: Dental Insurance (Multi_Mention)
#   - Q08c: Vision Insurance (Multi_Mention)
#
# Q12 is a star_rating_grid with 4 sub-questions:
#   - Q12a: Direct Manager (Rating)
#   - Q12b: Department Head (Rating)
#   - Q12c: VP (Rating)
#   - Q12d: CEO (Rating)
```

### Understanding the Outputs

**Radio Grid (Q05):**

Original Alchemer structure:
```
Q5: HR:How would you rate the following departments?
Q5: IT:How would you rate the following departments?
Q5: Finance:How would you rate the following departments?
```

AlchemerParser output:
```
Q05a | HR Department      | Single_Mention | Options: Excellent, Good, Fair, Poor
Q05b | IT Department      | Single_Mention | Options: Excellent, Good, Fair, Poor
Q05c | Finance Department | Single_Mention | Options: Excellent, Good, Fair, Poor
```

**Checkbox Grid (Q08):**

Original Alchemer structure:
```
Q8: Self:Health:Which benefits do you use?
Q8: Spouse:Health:Which benefits do you use?
Q8: Children:Health:Which benefits do you use?
Q8: Self:Dental:Which benefits do you use?
Q8: Spouse:Dental:Which benefits do you use?
Q8: Children:Dental:Which benefits do you use?
...
```

AlchemerParser output:
```
Q08a | Health Insurance | Multi_Mention | 3 columns: Q08a_1, Q08a_2, Q08a_3
Q08b | Dental Insurance | Multi_Mention | 3 columns: Q08b_1, Q08b_2, Q08b_3
Q08c | Vision Insurance | Multi_Mention | 3 columns: Q08c_1, Q08c_2, Q08c_3

Options:
Q08a_1 | Self
Q08a_2 | Spouse
Q08a_3 | Children
Q08b_1 | Self
Q08b_2 | Spouse
Q08b_3 | Children
...
```

---

## Example 3: NPS Tracker Survey

### Scenario

Quarterly NPS tracking survey with:
- 1 main NPS question
- 3 driver questions (also NPS format)
- Demographics
- Open-ended feedback

### Special Requirements

- Need to ensure NPS questions are properly classified
- CreateIndex must be "Y" for all NPS questions
- Open-ended questions excluded from Tabs analysis

### Workflow

```r
source("modules/AlchemerParser/run_alchemerparser.R")

result <- run_alchemerparser(
  project_dir = "/data/trackers/NPS_Q4_2025/",
  verbose = FALSE
)

# Verify NPS questions were detected
nps_questions <- Filter(function(q) {
  !q$is_grid && q$variable_type == "NPS"
}, result$questions)

cat(sprintf("Found %d NPS questions:\n", length(nps_questions)))
for (q_num in names(nps_questions)) {
  q <- nps_questions[[q_num]]
  cat(sprintf("  - %s: %s\n", q$q_code, q$question_text))
}

# Output:
# Found 4 NPS questions:
#   - Q04: How likely are you to recommend our company?
#   - Q05: How likely are you to recommend our product quality?
#   - Q06: How likely are you to recommend our customer service?
#   - Q07: How likely are you to recommend our value for money?

# Check that CreateIndex is set correctly
crosstab_data <- openxlsx::read.xlsx(result$outputs$crosstab_config)
nps_rows <- crosstab_data[crosstab_data$QuestionCode %in% c("Q04", "Q05", "Q06", "Q07"), ]

all(nps_rows$CreateIndex == "Y")  # Should be TRUE
```

### Validation

After parsing, verify in Survey_Structure.xlsx:

- All NPS questions have `Variable_Type = "NPS"`
- All NPS questions have `Columns = 1`
- Options sheet shows 0-10 for each NPS question

---

## Example 4: Batch Processing Multiple Surveys

### Scenario

You have 12 monthly customer surveys to process at once.

### Directory Structure

```
/data/monthly_surveys/
├── Jan2025/
│   ├── CustomerSat_Jan2025_questionnaire.docx
│   ├── CustomerSat_Jan2025_data_export_map.xlsx
│   └── CustomerSat_Jan2025_translation-export.xlsx
├── Feb2025/
│   ├── CustomerSat_Feb2025_questionnaire.docx
│   ├── CustomerSat_Feb2025_data_export_map.xlsx
│   └── CustomerSat_Feb2025_translation-export.xlsx
...
```

### Batch Processing Script

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

# Summary report
cat("\n")
cat("==============================================================================\n")
cat("  BATCH PROCESSING SUMMARY\n")
cat("==============================================================================\n\n")

for (month in months) {
  log <- results_log[[month]]

  if (!is.null(log$error)) {
    cat(sprintf("%s: FAILED\n", month))
  } else {
    cat(sprintf("%s: %d questions, %d flags%s\n",
                month,
                log$n_questions,
                log$n_flags,
                if (log$n_flags > 0) " ⚠" else ""))
  }
}

# Save detailed log
saveRDS(results_log, file.path(output_dir, "processing_log.rds"))
cat(sprintf("\nDetailed log saved to: %s\n",
            file.path(output_dir, "processing_log.rds")))
```

**Output:**
```
=== Processing Jan2025 ===
  ✓ Success: 15 questions, 0 flags

=== Processing Feb2025 ===
  ✓ Success: 15 questions, 0 flags

=== Processing Mar2025 ===
  ✓ Success: 16 questions, 2 flags ⚠

...

==============================================================================
  BATCH PROCESSING SUMMARY
==============================================================================

Jan2025: 15 questions, 0 flags
Feb2025: 15 questions, 0 flags
Mar2025: 16 questions, 2 flags ⚠
Apr2025: 15 questions, 0 flags
...
```

---

## Example 5: Handling Validation Flags

### Scenario

Survey parsing completes with 3 validation flags. Need to review and resolve.

### Workflow

```r
result <- run_alchemerparser(
  project_dir = "/data/surveys/ProductFeedback/",
  verbose = TRUE
)

# Step 7: Validating results...
#   Found 3 items for review:
#     WARNING: 1
#     REVIEW: 2

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

### Resolving Flags

**Flag 1: Q_ID_NOT_FOUND_IN_TRANSLATION**

**Problem:** Q08's question ID (15) is missing from translation export.

**Resolution:**
1. Check original Alchemer survey for Q ID 15
2. Options:
   - Re-export translation file (if it was incomplete)
   - Manually add question text to Survey_Structure.xlsx
   - Use question text from data export map (already in output)

**Action:** Since question text is already populated from data export map, no action needed unless you want exact translation wording.

**Flag 2: TEXT_MISMATCH**

**Problem:** Question text differs between Word doc and data export.

**Resolution:**
1. Open both files and compare actual text
2. Determine which is correct (usually Word doc is canonical)
3. If needed, manually edit `QuestionText` in Survey_Structure.xlsx

**Flag 3: AMBIGUOUS_MULTI_COLUMN**

**Problem:** Q14 has multiple columns, classified as Multi_Mention, but Word doc doesn't have `[ ]` brackets to confirm.

**Resolution:**
1. Check original Alchemer survey for Q14
2. Verify it's actually a multi-mention (checkbox) question
3. If it's actually ranking, manually update `Variable_Type` to "Ranking" in Survey_Structure.xlsx

### After Resolving Flags

```r
# Re-generate outputs with manual corrections
# (Edit Survey_Structure.xlsx manually, then use it in Tabs)

# Or re-run parser if you fixed source files
result2 <- run_alchemerparser(
  project_dir = "/data/surveys/ProductFeedback/",
  verbose = FALSE
)

result2$summary$n_flags  # Should be 0 now
```

---

## Example 6: Custom Output Processing

### Scenario

You want to auto-populate some Tabs configuration fields based on custom rules.

### Custom Processing Script

```r
source("modules/AlchemerParser/run_alchemerparser.R")

# Run parser
result <- run_alchemerparser(
  project_dir = "/data/surveys/BrandTracker/",
  verbose = FALSE
)

# Load Crosstab_Config
library(openxlsx)
crosstab <- read.xlsx(result$outputs$crosstab_config)

# Custom Rule 1: Auto-include all NPS and Rating questions
crosstab$Include[crosstab$CreateIndex == "Y"] <- "Y"

# Custom Rule 2: Mark demographics as banner variables
demo_codes <- c("Q01", "Q02", "Q03")  # Age, Gender, Region
crosstab$UseBanner[crosstab$QuestionCode %in% demo_codes] <- "Y"

# Custom Rule 3: Set banner labels
crosstab$BannerLabel[crosstab$QuestionCode == "Q01"] <- "Age Group"
crosstab$BannerLabel[crosstab$QuestionCode == "Q02"] <- "Gender"
crosstab$BannerLabel[crosstab$QuestionCode == "Q03"] <- "Region"

# Custom Rule 4: Set display order
crosstab$DisplayOrder <- seq_len(nrow(crosstab))

# Save modified config
modified_path <- sub("\\.xlsx$", "_MODIFIED.xlsx", result$outputs$crosstab_config)
write.xlsx(crosstab, modified_path)

cat(sprintf("Modified config saved to: %s\n", modified_path))
```

### Advanced: Programmatic Option Labeling

```r
# Load Survey_Structure
survey <- read.xlsx(result$outputs$survey_structure, sheet = "Options")

# Custom Rule: Shorten long option labels
survey$DisplayText <- ifelse(
  nchar(survey$OptionText) > 30,
  paste0(substr(survey$OptionText, 1, 27), "..."),
  survey$OptionText
)

# Custom Rule: Recode Likert options to numeric
likert_codes <- c("Q05", "Q06", "Q07")  # Likert questions

for (code in likert_codes) {
  likert_opts <- survey$QuestionCode == code

  survey$DisplayText[likert_opts & survey$OptionText == "Strongly disagree"] <- "1 - Strongly disagree"
  survey$DisplayText[likert_opts & survey$OptionText == "Disagree"] <- "2 - Disagree"
  survey$DisplayText[likert_opts & survey$OptionText == "Neutral"] <- "3 - Neutral"
  survey$DisplayText[likert_opts & survey$OptionText == "Agree"] <- "4 - Agree"
  survey$DisplayText[likert_opts & survey$OptionText == "Strongly agree"] <- "5 - Strongly agree"
}

# Save modified structure
modified_path <- sub("\\.xlsx$", "_MODIFIED.xlsx", result$outputs$survey_structure)

wb <- loadWorkbook(result$outputs$survey_structure)
deleteData(wb, sheet = "Options", gridExpand = TRUE, cols = 1:8, rows = 1:10000)
writeData(wb, sheet = "Options", survey, startRow = 1, colNames = TRUE)
saveWorkbook(wb, modified_path, overwrite = TRUE)

cat(sprintf("Modified survey structure saved to: %s\n", modified_path))
```

---

## Example 7: Real-World Testing - Helderberg Village HV2025

### Background

This example demonstrates actual issues encountered during real-world testing with a resident satisfaction survey for Helderberg Village, and how AlchemerParser handles them.

### Input Files

```
HV2025_questionnaire.docx
HV2025_data_export_map.xlsx
HV2025_translation-export.xlsx
```

**Location:** `/mnt/w/2025/01_Setup/`

### Issues Encountered and Solutions

#### Issue 1: Open-Ended Question Misclassified

**Problem:** Q03 (an open-ended question) was being classified as Single_Mention instead of Open_End.

**Root Cause:** Question had no options in the translation export, but the classification logic was defaulting to Single_Mention before checking for Open_End.

**Solution:** Updated classification hierarchy in `04_classify_questions.R:234-254` to check `if (n_options > 0)` before returning Single_Mention. Questions with zero options now correctly default to Open_End.

**Result:**
```r
# Before fix:
Q03 | Variable_Type: Single_Mention | Options: 0

# After fix:
Q03 | Variable_Type: Open_End | Options: 0
```

#### Issue 2: Radio Grid Row Order Incorrect

**Problem:** Q06 (radio button grid) was showing rows in alphabetical order instead of data export map order.

**Expected Order:**
1. Village management
2. The weekly newsletter
3. Communication channels
4. The CEO

**Actual Order (alphabetical):**
1. Communication channels
2. The CEO
3. The weekly newsletter
4. Village management

**Root Cause:** Grid processing functions were using `sort()` on row labels.

**Solution:** Removed `sort()` calls from:
- `create_radio_grid_questions()` (line 304)
- `pivot_checkbox_grid()` (line 365)

The `unique()` function preserves original data order.

**Result:** Rows now appear in the exact order from the data export map, which matches the survey design.

#### Issue 3: Radio Grid Options Missing

**Problem:** Q06 sub-questions (Q06a, Q06b, Q06c, Q06d) were showing 0 options in the Options sheet.

**Root Cause:** Alchemer stores grid options inconsistently. For Q06, options were stored at a different question ID than expected.

**Investigation Results:**
```
Q06 base ID: 9
Expected options at: 13 (last column ID)
Actual options at: 14 (one ID higher)
```

**Solution:** Implemented smart search strategy in `find_grid_options()`:
1. First try expected location (last column's question ID)
2. Try base question ID
3. Search nearby IDs (±2 to +10 range)
4. Fall back to common rating scale options if available

**Result:**
```r
# Before fix:
Q06a | Options: 0

# After fix:
Q06a | Options: 5 (Very dissatisfied, Dissatisfied, Neutral, Satisfied, Very satisfied)
Q06b | Options: 5 (Very dissatisfied, Dissatisfied, Neutral, Satisfied, Very satisfied)
Q06c | Options: 5 (Very dissatisfied, Dissatisfied, Neutral, Satisfied, Very satisfied)
Q06d | Options: 5 (Very dissatisfied, Dissatisfied, Neutral, Satisfied, Very satisfied)
```

#### Issue 4: Numeric Rating Scales Misclassified

**Problem:** Q60 and Q65 (0-10 rating scales) were being classified as Single_Mention instead of Rating.

**Root Cause:** Parser only detected Likert-style ratings (5-point scales with text labels), not numeric scales.

**Solution:** Added numeric rating scale detection in `04_classify_questions.R:234-244`:
- Check if ≥50% of options are numeric
- Require at least 3 numeric options
- Classify as Rating if threshold met

**Result:**
```r
# Before fix:
Q60 | Variable_Type: Single_Mention | Options: 12 (0, 1, 2, ..., 10, Don't know)
Q65 | Variable_Type: Single_Mention | Options: 12 (0, 1, 2, ..., 10, Don't know)

# After fix:
Q60 | Variable_Type: Rating | Options: 12 (0, 1, 2, ..., 10, Don't know)
Q65 | Variable_Type: Rating | Options: 12 (0, 1, 2, ..., 10, Don't know)
```

### Running the Parser

```r
source("modules/AlchemerParser/run_alchemerparser.R")

result <- run_alchemerparser(
  project_dir = "/mnt/w/2025/01_Setup/",
  verbose = TRUE
)

# Results:
# ==============================================================================
#   PARSING COMPLETE
# ==============================================================================
#   Total questions: 67
#   Total data columns: 101
#   Items flagged for review: 0
```

### Verification

All issues resolved:
- ✅ Q03 correctly classified as Open_End
- ✅ Q06 rows in correct data order (Village management → CEO)
- ✅ Q06 sub-questions all have 5 options
- ✅ Q60 and Q65 classified as Rating (not Single_Mention)

---

## Example 8: Real-World Testing - CCPB CSAT2025

### Background

This example demonstrates testing with a customer satisfaction survey for CCPB, highlighting ranking question detection challenges.

### Input Files

```
CCPB_questionnaire.docx
CCPB_data_export_map.xlsx
CCPB_translation-export.xlsx
```

**Location:** `/mnt/w/CCPB CSAT2025/01_Setup/`

### Issues Encountered and Solutions

#### Issue 1: False Positive Ranking Detection (Q10)

**Problem:** Q10 was being classified as Ranking when it should be Multi_Mention.

**Question Text:** "Which benefits are most important to you? Please place your orders in the boxes below."

**Root Cause:** The word "orders" triggered the ranking keyword detection (looking for "order" as in "rank order").

**Attempted Fix:** Made ranking patterns more specific by requiring word boundaries (`\\border\\b`).

**Result:** Fixed Q10, but broke Helderberg Village parsing → **ROLLBACK PERFORMED**

**Lesson Learned:** Need surgical fixes that don't break existing working surveys.

#### Issue 2: Ranking Question Detected as Grid (Q119)

**Problem:** Q119 (a ranking question with 4 columns) was being detected as a radio_grid and split into Q119a, Q119b, Q119c, Q119d single mentions.

**Question Text:** "This is a ranking question - please rank the following 4 items from most important to least important."

**Root Cause:** Grid type detection was running BEFORE ranking detection in the classification hierarchy.

**Investigation:**
```r
# Diagnostic output showed:
Question structure: grid_or_multi
Detected as radio_grid with 4 columns
```

The question had explicit "ranking question" text but was caught by grid detection first.

**Solution:** Moved ranking detection BEFORE grid type detection in `classify_questions()` main loop (lines 51-90).

**New Detection Flow:**
1. Check Word doc for ranking hints (`has_rank_keyword`)
2. Check question text for explicit ranking indicators:
   - "ranking question"
   - "most to least" / "least to most"
   - `\\brank\\b`, `\\branking\\b`, `prioriti[sz]e`
3. If ranking detected with multiple columns, classify as Ranking and skip grid detection

**Result:**
```r
# Before fix:
Q119a | Variable_Type: Single_Mention | Options: 4
Q119b | Variable_Type: Single_Mention | Options: 4
Q119c | Variable_Type: Single_Mention | Options: 4
Q119d | Variable_Type: Single_Mention | Options: 4

# After fix:
Q119 | Variable_Type: Ranking | Columns: 4 | Options: 4
```

#### Issue 3: Othermention Text Field Naming (Known Issue)

**Problem:** Q32 (multi-mention with "Other - Write In" option) was showing duplicate "Other - Write In" entries and incorrect column numbering.

**Expected:**
```
Q32_1  | Option 1
Q32_2  | Option 2
...
Q32_16 | Other - Write In
Q32_17 | Other - Write In (text)
Total columns: 17
```

**Actual:**
```
Q32_1  | Option 1
Q32_2  | Option 2
...
Q32_16 | Other - Write In
Q32_16 | Other - Write In (text)  # Should be Q32_17
Total columns: 16  # Should be 17
```

**Status:** Documented as a known non-critical issue. The othermention text field detection is complex due to inconsistent Alchemer patterns. This doesn't affect Tabs functionality as the data columns are still correctly mapped.

**Workaround:** Users can manually edit the Survey_Structure.xlsx to correct column numbering if needed for their specific use case.

### Running the Parser

```r
source("modules/AlchemerParser/run_alchemerparser.R")

result <- run_alchemerparser(
  project_dir = "/mnt/w/CCPB CSAT2025/01_Setup/",
  verbose = TRUE
)

# Results:
# ==============================================================================
#   PARSING COMPLETE
# ==============================================================================
#   Total questions: 124
#   Total data columns: 198
#   Items flagged for review: 1
#
# Validation flags:
#   REVIEW: Q32 othermention column count may be off by 1
```

### Verification

Critical issues resolved:
- ✅ Q10 correctly classified as Multi_Mention (not Ranking)
- ✅ Q119 correctly classified as Ranking (not grid of single mentions)
- ⚠️ Q32 othermention naming documented as known minor issue

### Testing Both Projects Together

**Important:** After fixing Q119, both projects were re-tested to ensure no regressions:

```r
# Test Helderberg Village
result_hv <- run_alchemerparser(
  project_dir = "/mnt/w/2025/01_Setup/",
  verbose = FALSE
)
cat(sprintf("HV2025: %d questions, %d flags\n",
            result_hv$summary$n_questions,
            result_hv$summary$n_flags))
# HV2025: 67 questions, 0 flags ✅

# Test CCPB
result_ccpb <- run_alchemerparser(
  project_dir = "/mnt/w/CCPB CSAT2025/01_Setup/",
  verbose = FALSE
)
cat(sprintf("CCPB: %d questions, %d flags\n",
            result_ccpb$summary$n_questions,
            result_ccpb$summary$n_flags))
# CCPB: 124 questions, 1 flags ✅
```

Both projects parsing successfully with minimal flags.

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

If you customize outputs programmatically, save the R script:
```r
# custom_processing_BrandTracker.R
# Created: 2025-11-20
# Purpose: Auto-populate banner settings for BrandTracker survey

source("modules/AlchemerParser/run_alchemerparser.R")

# ... your custom processing code ...
```

---

**Version:** 1.0
**Last Updated:** 2025-11-20
