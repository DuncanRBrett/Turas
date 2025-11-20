# Example Workflows: Turas AlchemerParser Module

Real-world examples showing how to use AlchemerParser in different scenarios.

## Table of Contents

1. [Basic Customer Satisfaction Survey](#example-1-basic-customer-satisfaction-survey)
2. [Complex Grid Survey](#example-2-complex-grid-survey)
3. [NPS Tracker Survey](#example-3-nps-tracker-survey)
4. [Batch Processing Multiple Surveys](#example-4-batch-processing-multiple-surveys)
5. [Handling Validation Flags](#example-5-handling-validation-flags)
6. [Custom Output Processing](#example-6-custom-output-processing)

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
