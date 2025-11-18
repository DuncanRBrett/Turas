# Turas Parser - Quick Start Guide

**Version:** 1.0
**Estimated Time:** 5-10 minutes
**Difficulty:** Beginner

---

## What is Turas Parser?

The Turas Parser automatically converts Word document questionnaires into structured survey metadata that can be used by other Turas modules (Tabs, Tracker). It saves hours of manual data entry by intelligently detecting question types, options, and structure.

---

## Prerequisites

### Required R Packages
```r
install.packages(c("shiny", "officer", "openxlsx"))
```

### What You Need
- A survey questionnaire in **.docx format** (Word document)
- The questionnaire should follow standard formatting:
  - Questions numbered (Q1, Q2, etc.) or clearly separated
  - Options labeled (a), b), 1., 2., A., B., etc.)
  - Clear question text

---

## Quick Start (5 Minutes)

### Option 1: Using the Shiny GUI (Recommended for Beginners)

1. **Launch the Parser GUI:**
   ```r
   # From Turas root directory:
   source("modules/parser/shiny_app.R")
   ```

2. **Upload Your Questionnaire:**
   - Click "Browse..." button
   - Select your `.docx` questionnaire file
   - Click "Open"

3. **Configure Settings (Optional):**
   - **Format Hint Detection:** Keep enabled (detects [brackets] vs (parentheses))
   - **Bin Detection:** Keep enabled (detects numeric ranges like 0-10)
   - **Question Code Prefix:** Default "Q" is fine

4. **Parse the Questionnaire:**
   - Click the **"Parse Questionnaire"** button
   - Wait a few seconds (typically 5-10 seconds)
   - Review results in the "Parsing Results" tab

5. **Review & Download:**
   - Check the **Summary tab**: Shows # of questions by type
   - Check the **Questions tab**: Browse detected questions
   - Check the **Review Needed tab**: Questions flagged for manual review
   - Click **"Download Survey Structure (Excel)"** when satisfied

### Option 2: Using R Script (For Advanced Users)

```r
# Load the parser
source("modules/parser/run_parser.R")

# Parse a questionnaire
result <- parse_questionnaire(
  docx_path = "path/to/your/questionnaire.docx",
  output_path = "output/survey_structure.xlsx",
  config = list(
    detect_format_hints = TRUE,
    detect_bins = TRUE,
    question_code_prefix = "Q"
  )
)

# View results
print(result$summary)
```

---

## What You Get

The parser generates an **Excel file** (`Survey_Structure.xlsx`) with 4 sheets:

| Sheet | Description |
|-------|-------------|
| **Questions** | Main survey structure: question codes, text, types, options |
| **Options** | Detailed option list for each question (for single/multi choice) |
| **Othertext** | "Other (please specify)" fields detected |
| **Metadata** | Project information and parsing settings |

This file can be used directly as input to:
- **Turas Tabs** (for cross-tabulation analysis)
- **Turas Tracker** (for multi-wave tracking)

---

## Understanding Question Types

The parser automatically detects:

| Type | Description | Example |
|------|-------------|---------|
| **Single_Response** | Choose one answer | Gender: () Male () Female |
| **Multi_Mention** | Choose multiple answers | [Check all that apply] |
| **Rating** | Numeric scale | Rate 1-10 |
| **NPS** | Net Promoter Score | Rate 0-10 likelihood to recommend |
| **Open_Ended** | Free text | Please explain... |
| **Numeric** | Number entry | How many? _____ |

---

## Common Issues & Quick Fixes

### ❌ "No questions detected"
**Cause:** Questionnaire format not recognized
**Fix:**
- Ensure questions are numbered (Q1, Q2, etc.)
- Add blank lines between questions
- Make sure question text is on a separate line from options

### ❌ "Options not detected for question X"
**Cause:** Option formatting not recognized
**Fix:**
- Use standard formats: a), b), c) or 1., 2., 3. or A., B., C.
- Put each option on a new line
- Ensure consistent formatting within each question

### ❌ "Question type detected as Open_Ended but should be Single_Response"
**Cause:** No options detected
**Fix:**
- Check options are properly formatted
- Use format hints: (parentheses) for single response, [brackets] for multi-mention
- Manually review and correct in the Review Needed tab

### ❌ "Bins detected incorrectly"
**Cause:** Numeric text confused with bins
**Fix:**
- Turn off bin detection in settings if not using binned data
- Manually correct in output Excel file

---

## Tips for Best Results

✅ **DO:**
- Use consistent formatting throughout questionnaire
- Number questions clearly (Q1, Q2, Q3...)
- Use (parentheses) for single response, [brackets] for multi-mention
- Keep question text and options clearly separated
- Use standard option labels (a, b, c or 1, 2, 3)

❌ **DON'T:**
- Mix formats within same questionnaire
- Use complex tables or graphics (convert to simple text first)
- Put multiple questions in one paragraph
- Use unusual numbering schemes

---

## Next Steps

Once you have your `Survey_Structure.xlsx` file:

1. **Review the output** - Check the "Review Needed" sheet for questions flagged
2. **Make manual corrections** - Edit the Excel file directly if needed
3. **Use with Turas Tabs** - Load your survey data + this structure for cross-tabs
4. **Use with Turas Tracker** - Set up multi-wave tracking analysis

---

## Getting Help

- **User Manual:** See `USER_MANUAL.md` for comprehensive documentation
- **Examples:** See `EXAMPLE_WORKFLOWS.md` for real-world use cases
- **Technical Docs:** See `TECHNICAL_DOCUMENTATION.md` for developer information
- **Troubleshooting:** Check main `TROUBLESHOOTING.md` in Turas root

---

## Example Input/Output

### Input Questionnaire (example.docx):
```
Q1. What is your gender?
   a) Male
   b) Female
   c) Other

Q2. Which of the following do you own? [Check all that apply]
   a) Smartphone
   b) Laptop
   c) Tablet
   d) Desktop computer

Q3. On a scale of 0-10, how likely are you to recommend us?
   0 = Not at all likely
   10 = Extremely likely
```

### Output Structure (survey_structure.xlsx):

| QuestionCode | QuestionText | QuestionType | Options |
|--------------|--------------|--------------|---------|
| Q1 | What is your gender? | Single_Response | Male; Female; Other |
| Q2 | Which of the following do you own? | Multi_Mention | Smartphone; Laptop; Tablet; Desktop computer |
| Q3 | On a scale of 0-10, how likely... | NPS | 0; 1; 2; 3; 4; 5; 6; 7; 8; 9; 10 |

---

**Congratulations!** You've completed the Quick Start guide. You're now ready to parse questionnaires with Turas Parser.

For more advanced features and detailed explanations, see the **User Manual**.
