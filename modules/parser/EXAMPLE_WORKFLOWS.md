# Turas Parser - Example Workflows

**Version:** 1.0.0
**Last Updated:** 2025-11-17

---

## Table of Contents

1. [Workflow 1: Simple Brand Tracking Survey](#workflow-1-simple-brand-tracking-survey)
2. [Workflow 2: Customer Satisfaction Survey with NPS](#workflow-2-customer-satisfaction-survey-with-nps)
3. [Workflow 3: Demographic Survey with Bins](#workflow-3-demographic-survey-with-bins)
4. [Workflow 4: Mixed Question Types](#workflow-4-mixed-question-types)
5. [Workflow 5: Batch Processing Multiple Surveys](#workflow-5-batch-processing-multiple-surveys)
6. [Workflow 6: Integration with Turas Tabs](#workflow-6-integration-with-turas-tabs)
7. [Workflow 7: Correcting Parser Errors](#workflow-7-correcting-parser-errors)
8. [Workflow 8: Creating Reusable Templates](#workflow-8-creating-reusable-templates)

---

## Workflow 1: Simple Brand Tracking Survey

### Scenario
You have a straightforward brand awareness questionnaire with 10 questions that you need to parse for monthly tracking.

### Input Questionnaire (brand_tracking.docx)

```
Brand Awareness Survey - Wave 12

Q1. What is your age?
   a) 18-24
   b) 25-34
   c) 35-44
   d) 45-54
   e) 55+

Q2. What is your gender?
   (a) Male
   (b) Female
   (c) Prefer not to say

Q3. Which of the following brands have you heard of? [Check all that apply]
   [a] Brand A
   [b] Brand B
   [c] Brand C
   [d] Brand D
   [e] Brand E

Q4. Which brand did you purchase in the last 3 months? (Select one)
   (a) Brand A
   (b) Brand B
   (c) Brand C
   (d) Brand D
   (e) Brand E
   (f) Other (please specify): __________
   (g) None

Q5. How satisfied are you with your purchase?
   1 = Very dissatisfied
   2 = Dissatisfied
   3 = Neutral
   4 = Satisfied
   5 = Very satisfied
```

### Steps

**1. Launch Parser GUI:**
```r
source("modules/parser/shiny_app.R")
```

**2. Configure Settings:**
- ✅ Detect Format Hints: ON (we're using [brackets] and (parentheses))
- ✅ Detect Bins: ON (Q1 has age ranges)
- Question Code Prefix: "Q" (default)

**3. Upload and Parse:**
- Click "Browse..." and select `brand_tracking.docx`
- Click "Parse Questionnaire"
- Wait 5 seconds

**4. Review Results:**

**Summary Tab:**
```
✓ Successfully parsed 5 questions
  - Single_Response: 3 (Q2, Q4, Q5)
  - Multi_Mention: 1 (Q3)
  - Open_Ended: 1 (Q4_Other)

✓ Detected bins in 1 question (Q1)
✓ Detected 1 "other specify" field (Q4)
```

**Questions Tab:**
| QuestionCode | QuestionType | OptionCount | IsBin | ReviewNeeded |
|--------------|--------------|-------------|-------|--------------|
| Q1 | Single_Response | 5 | TRUE | FALSE |
| Q2 | Single_Response | 3 | FALSE | FALSE |
| Q3 | Multi_Mention | 5 | FALSE | FALSE |
| Q4 | Single_Response | 7 | FALSE | FALSE |
| Q5 | Rating | 5 | FALSE | FALSE |

**Review Needed Tab:**
```
No questions flagged for review!
```

**5. Download Output:**
- Click "Download Survey Structure (Excel)"
- Save as: `brand_tracking_structure_wave12.xlsx`

### Expected Output

**Questions Sheet:**
```
Q1 | What is your age? | Single_Response | 18-24; 25-34; 35-44; 45-54; 55+ | 5 | TRUE | 18 | 55 | 18-55 | FALSE |
Q2 | What is your gender? | Single_Response | Male; Female; Prefer not to say | 3 | FALSE | | | | FALSE |
Q3 | Which of the following brands... | Multi_Mention | Brand A; Brand B; Brand C; Brand D; Brand E | 5 | FALSE | | | | FALSE |
Q4 | Which brand did you purchase... | Single_Response | Brand A; Brand B; Brand C; Brand D; Brand E; Other; None | 7 | FALSE | | | | FALSE |
Q5 | How satisfied are you... | Rating | 1; 2; 3; 4; 5 | 5 | FALSE | | | | FALSE |
```

**Othertext Sheet:**
```
Q4 | Q4_Other | Other (please specify)
```

### Time Required
**Total: 3 minutes**
- Setup: 30 seconds
- Parsing: 10 seconds
- Review: 1 minute
- Download: 10 seconds

---

## Workflow 2: Customer Satisfaction Survey with NPS

### Scenario
You're running a customer satisfaction survey that includes an NPS question and you want to ensure it's detected correctly.

### Input Questionnaire (csat_survey.docx)

```
Customer Satisfaction Survey

Q1. How likely are you to recommend our service to a friend or colleague?
   0 = Not at all likely
   1
   2
   3
   4
   5
   6
   7
   8
   9
   10 = Extremely likely

Q2. What is the primary reason for your score?
   _________________________________________________

Q3. How would you rate us on the following?

Quality of service:
   1 = Poor
   2 = Fair
   3 = Good
   4 = Very Good
   5 = Excellent

Value for money:
   1 = Poor
   2 = Fair
   3 = Good
   4 = Very Good
   5 = Excellent
```

### Steps

**1. Parse the questionnaire:**
```r
source("modules/parser/shiny_app.R")
# Upload csat_survey.docx
# Keep default settings
# Click "Parse Questionnaire"
```

**2. Check Results:**

**Questions Tab:**
| QuestionCode | QuestionType | OptionCount | ReviewNeeded | ReviewReason |
|--------------|--------------|-------------|--------------|--------------|
| Q1 | **NPS** | 11 | FALSE | |
| Q2 | Open_Ended | 0 | FALSE | |
| Q3a | Rating | 5 | FALSE | |
| Q3b | Rating | 5 | FALSE | |

✅ **Success!** Q1 correctly detected as NPS (0-10 scale with "recommend")

**3. Handle Q3 Grid Question:**

The parser treats Q3a and Q3b as separate questions. If you want them as a grid:

**Option A - Keep Separate (Recommended for Tabs):**
- Manually rename in Excel:
  - Q3a → Q3_Quality
  - Q3b → Q3_Value

**Option B - Combine (Manual):**
- Delete Q3a and Q3b rows
- Add single row:
  - QuestionCode: Q3
  - QuestionType: Rating_Grid
  - Options: Quality; Value for money

### Expected Output

**Use in Tabs:**
```r
# The NPS question will be recognized for automatic NPS calculation
# Rating questions will use appropriate statistical tests
# Open-ended verbatim will be excluded from cross-tabs
```

---

## Workflow 3: Demographic Survey with Bins

### Scenario
You have a survey with multiple demographic questions that use bins (age, income, company size). You want to ensure all bins are detected correctly.

### Input Questionnaire (demographics.docx)

```
Q1. What is your age?
   a) Under 18
   b) 18-24
   c) 25-34
   d) 35-44
   e) 45-54
   f) 55-64
   g) 65 or older

Q2. What is your annual household income?
   a) Less than $25,000
   b) $25,000 - $49,999
   c) $50,000 - $74,999
   d) $75,000 - $99,999
   e) $100,000 - $149,999
   f) $150,000 or more

Q3. How many employees work at your company?
   a) 1-10
   b) 11-50
   c) 51-100
   d) 101-250
   e) 251-500
   f) 501-1000
   g) 1000+
```

### Steps

**1. Parse with bin detection enabled:**
```r
config <- list(
  detect_format_hints = TRUE,
  detect_bins = TRUE,  # Critical for this use case
  question_code_prefix = "DEM"
)

result <- parse_questionnaire(
  docx_path = "demographics.docx",
  output_path = "demographics_structure.xlsx",
  config = config
)
```

**2. Verify bin detection:**

Open Excel file and check:

**Q1 (Age):**
- IsBin: TRUE ✓
- BinMin: 18
- BinMax: 65
- NumericRange: "18-65"
- Note: "Under 18" and "65 or older" are open-ended

**Q2 (Income):**
- IsBin: TRUE ✓
- BinMin: 25000
- BinMax: 150000
- NumericRange: "$25,000-$150,000"
- Note: Commas removed, $ signs stripped

**Q3 (Company Size):**
- IsBin: TRUE ✓
- BinMin: 1
- BinMax: 1000
- NumericRange: "1-1000"

**3. Use in analysis:**

The bin metadata allows Turas Tabs to:
- Calculate mean/median estimates using bin midpoints
- Apply appropriate statistical tests for ordinal data
- Create visualizations with proper axis labeling

---

## Workflow 4: Mixed Question Types

### Scenario
You have a complex survey with all question types: single, multi, rating, NPS, numeric, and open-ended.

### Input Questionnaire

```
Q1. In which country do you live? (Select one)
   (a) United States
   (b) Canada
   (c) United Kingdom
   (d) Australia
   (e) Other (please specify): __________

Q2. Which of the following devices do you own? [Check all that apply]
   [a] Smartphone
   [b] Tablet
   [c] Laptop
   [d] Desktop computer
   [e] Smartwatch
   [f] Smart TV
   [g] Gaming console
   [h] E-reader
   [i] Smart home device
   [j] Fitness tracker
   [k] VR headset
   [l] Other (please specify): __________

Q3. How satisfied are you with your primary device?
   1 = Very dissatisfied
   2 = Dissatisfied
   3 = Neither satisfied nor dissatisfied
   4 = Satisfied
   5 = Very satisfied

Q4. How likely are you to recommend our brand to others?
   0 = Not at all likely
   ... (full 0-10 scale)
   10 = Extremely likely

Q5. How many hours per day do you use your devices?
   _____ hours

Q6. What do you like most about your primary device?
   _______________________________________
```

### Expected Detection

| Q# | Type | Reason |
|----|------|--------|
| Q1 | Single_Response | (parentheses), < 12 options |
| Q2 | Multi_Mention | [brackets], 12 options |
| Q3 | Rating | 1-5 scale |
| Q4 | NPS | 0-10 + "recommend" |
| Q5 | Numeric | "how many" + blank |
| Q6 | Open_Ended | No options |

### Verification Steps

1. Parse questionnaire
2. Check "Questions" tab:
   - All 6 types represented correctly ✓
3. Check "Othertext" tab:
   - Q1_Other present ✓
   - Q2_Other present ✓
4. Check "Review Needed" tab:
   - Should be empty if formatting is clean

---

## Workflow 5: Batch Processing Multiple Surveys

### Scenario
You have 10 questionnaires from different clients that all need to be parsed.

### Directory Structure
```
questionnaires/
├── client_a_survey.docx
├── client_b_survey.docx
├── client_c_survey.docx
├── ...
└── client_j_survey.docx
```

### Batch Script

```r
# Load parser
source("modules/parser/run_parser.R")

# Create output directory
dir.create("output/survey_structures", recursive = TRUE, showWarnings = FALSE)

# Get list of questionnaires
questionnaires <- list.files(
  "questionnaires/",
  pattern = "\\.docx$",
  full.names = TRUE
)

# Parse each questionnaire
results <- list()

for (docx_file in questionnaires) {
  # Generate output filename
  base_name <- tools::file_path_sans_ext(basename(docx_file))
  output_file <- file.path("output/survey_structures", paste0(base_name, "_structure.xlsx"))

  cat("Processing:", base_name, "...\n")

  # Parse
  tryCatch({
    result <- parse_questionnaire(
      docx_path = docx_file,
      output_path = output_file,
      config = list(
        detect_format_hints = TRUE,
        detect_bins = TRUE,
        question_code_prefix = "Q"
      )
    )

    results[[base_name]] <- list(
      status = "success",
      questions = nrow(result$questions),
      warnings = result$warnings
    )

    cat("  ✓ Success:", nrow(result$questions), "questions\n\n")

  }, error = function(e) {
    results[[base_name]] <- list(
      status = "failed",
      error = e$message
    )

    cat("  ✗ Failed:", e$message, "\n\n")
  })
}

# Generate summary report
summary_df <- data.frame(
  Survey = names(results),
  Status = sapply(results, function(x) x$status),
  Questions = sapply(results, function(x) ifelse(x$status == "success", x$questions, NA)),
  stringsAsFactors = FALSE
)

write.csv(summary_df, "output/batch_parsing_summary.csv", row.names = FALSE)

cat("Batch processing complete!\n")
cat("Summary saved to: output/batch_parsing_summary.csv\n")
```

### Expected Output

```
Processing: client_a_survey ...
  ✓ Success: 25 questions

Processing: client_b_survey ...
  ✓ Success: 18 questions

Processing: client_c_survey ...
  ✗ Failed: No questions detected in document

...

Batch processing complete!
Summary saved to: output/batch_parsing_summary.csv
```

**batch_parsing_summary.csv:**
```
Survey,Status,Questions
client_a_survey,success,25
client_b_survey,success,18
client_c_survey,failed,NA
...
```

---

## Workflow 6: Integration with Turas Tabs

### Scenario
You've parsed a questionnaire and now want to use it for cross-tabulation analysis with survey data.

### Step-by-Step Integration

**1. Parse questionnaire:**
```r
source("modules/parser/run_parser.R")

parse_questionnaire(
  docx_path = "questionnaire.docx",
  output_path = "survey_structure.xlsx"
)
```

**2. Prepare your survey data:**

Your data file (`survey_data.xlsx`) should have columns matching question codes:
```
ResponseID | Q1 | Q2 | Q3 | Q4 | Q5 | ...
1          | 2  | 1  | 1  | 3  | 8  | ...
2          | 3  | 2  | 2  | 5  | 9  | ...
...
```

**3. Create Tabs configuration:**

```r
# Load survey structure
library(readxl)
survey_structure <- read_excel("survey_structure.xlsx", sheet = "Questions")

# Create tabs config (simplified example)
tabs_config <- list(
  data_file = "survey_data.xlsx",
  structure_file = "survey_structure.xlsx",

  # Automatically use all questions from parser output
  questions = survey_structure$QuestionCode,

  # Set banner variables
  banner_vars = c("Q1", "Q2"),  # Age and Gender

  output_file = "crosstabs_output.xlsx"
)

# Run Tabs module
source("modules/tabs/run_tabs.R")
# ... execute tabs analysis ...
```

**4. Verify compatibility:**

The parser output includes all necessary columns for Tabs:
- ✓ QuestionCode
- ✓ QuestionType (for appropriate statistical tests)
- ✓ Options (for labeling)
- ✓ IsBin (for numeric handling)

---

## Workflow 7: Correcting Parser Errors

### Scenario
The parser made some mistakes and you need to manually correct them.

### Common Corrections Needed

**Issue 1: Question detected as Open_Ended but has options**

**Problem:**
```
Q10 | What is your favorite color? | Open_Ended | | 0 | FALSE
```

**Cause:** Options weren't detected due to formatting

**Fix in Excel:**
1. Open `survey_structure.xlsx`
2. Edit Q10 row:
   - QuestionType: Open_Ended → Single_Response
   - Options: (empty) → Red; Blue; Green; Yellow; Other
   - OptionCount: 0 → 5
3. Go to "Options" sheet, add rows:
   ```
   Q10 | 1 | Red | 1
   Q10 | 2 | Blue | 2
   Q10 | 3 | Green | 3
   Q10 | 4 | Yellow | 4
   Q10 | 5 | Other | 5
   ```
4. Save file

---

**Issue 2: Question should be Multi_Mention but detected as Single_Response**

**Problem:**
```
Q5 | Select all that apply | Single_Response | ... | 8 | FALSE
```

**Fix in Excel:**
1. Change QuestionType: Single_Response → Multi_Mention
2. Save file

---

**Issue 3: Question codes need customization**

**Problem:**
Auto-generated codes (Q1, Q2, Q3) aren't meaningful

**Fix in Excel:**
1. Rename codes to be descriptive:
   - Q1 → DEM_AGE
   - Q2 → DEM_GENDER
   - Q3 → BRAND_AWARE
   - Q4 → BRAND_PURCHASE
   - Q5 → SAT_OVERALL
2. Update "Options" sheet to match new codes
3. Update "Othertext" sheet to match new codes
4. Save file

---

## Workflow 8: Creating Reusable Templates

### Scenario
You run the same survey every month with minor changes. You want to create a template to speed up parsing.

### Creating a Template

**1. Parse the first wave:**
```r
parse_questionnaire(
  docx_path = "survey_wave1.docx",
  output_path = "survey_template.xlsx"
)
```

**2. Manual cleanup:**
- Open `survey_template.xlsx`
- Correct any parsing errors
- Customize question codes
- Add any manual notes in new columns
- Save as template

**3. Use template for subsequent waves:**

**For Wave 2:**
```r
# Parse new wave
parse_questionnaire(
  docx_path = "survey_wave2.docx",
  output_path = "survey_wave2_raw.xlsx"
)

# Then manually compare with template:
# - Check if question order changed
# - Check if new questions added
# - Check if options modified
# - Copy customizations from template
```

**4. Create diff script (advanced):**

```r
library(readxl)

# Load template and new parse
template <- read_excel("survey_template.xlsx", sheet = "Questions")
new_parse <- read_excel("survey_wave2_raw.xlsx", sheet = "Questions")

# Compare
differences <- anti_join(new_parse, template, by = "QuestionCode")

if (nrow(differences) > 0) {
  cat("New/modified questions found:\n")
  print(differences$QuestionCode)
} else {
  cat("No changes detected - safe to use template!\n")
}
```

---

## Appendix: Common Patterns Reference

### Format Hints Quick Reference

| Pattern | Type |
|---------|------|
| (a) Option | Single_Response |
| [a] Option | Multi_Mention |

### Question Text Indicators

| Text Contains | Likely Type |
|---------------|-------------|
| "check all that apply" | Multi_Mention |
| "select one" | Single_Response |
| "how likely to recommend" + 0-10 | NPS |
| "satisfied" + 1-5 | Rating |
| "how many" | Numeric |
| "please explain" | Open_Ended |

### Option Count Rules

| Count | Type |
|-------|------|
| 0 | Open_Ended |
| 1-11 | Single_Response (unless format hint says Multi) |
| 12+ | Multi_Mention |
| Exactly 11 (0-10) + "recommend" | NPS |
| Exactly 5, 7, or 10 sequential numbers starting at 1 | Rating |

---

**End of Example Workflows**

*Version 1.0.0 | Practical Examples | Turas Parser Module*
