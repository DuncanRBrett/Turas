# Tracker Question Mapping Template - User Manual

**Template File:** `templates/Tracker_Question_Mapping_Template.xlsx`
**Version:** 10.0
**Last Updated:** 4 December 2025

---

## Overview

The Tracker Question Mapping Template maps question codes across survey waves when questions move or are renumbered. It allows TurasTracker to follow the same question even when its code changes from wave to wave.

**Key Purpose:** Map questions across waves so tracker can follow the same question even when codes change (e.g., Q10 → Q11 → Q12).

**Important:** This template works together with Tracker_Config_Template. Both files are required for tracking analysis.

---

## Template Structure

The template contains **2 sheets**:

1. **Instructions** - Comprehensive usage guide
2. **QuestionMap** - Question code mappings across waves

---

## Sheet 1: Instructions

**Purpose:** Detailed documentation of question mapping process and file linking.

**Action Required:** Review for understanding. Not read by analysis code.

**Key Content:**
- How to map questions across waves
- Question type guide (Rating, NPS, SingleChoice, Composite)
- Common scenarios (question moved, added, removed, unchanged)
- File linking: Config and Mapping files relationship
- Examples and best practices

**Critical Information:**

**The Two Files DON'T Automatically Find Each Other:**
- Tracker_Config and Question_Mapping are NOT automatically linked
- You must specify BOTH file paths explicitly when running

**Two Ways to Run:**

1. **Via R Code** - Specify both paths:
```r
run_tracker(
  tracking_config_path = "path/to/tracking_config.xlsx",
  question_mapping_path = "path/to/question_mapping.xlsx",
  data_dir = "path/to/data/"
)
```

2. **Via GUI** - Auto-detection:
- When you select tracking_config.xlsx in GUI
- Module auto-detects question mapping file in same directory
- Naming convention: If config is `XXX_tracking_config.xlsx`, looks for `XXX_question_mapping.xlsx`
- Falls back to `question_mapping.xlsx` or `tracking_question_mapping.xlsx`

---

## Sheet 2: QuestionMap

**Purpose:** Map question codes across survey waves.

**Required Columns:** `QuestionCode`, `QuestionLabel`, `QuestionType`, and one column per wave (Wave1, Wave2, Wave3, etc.)

**Optional Columns:** `SourceQuestions` (for composites)

### Field Specifications

#### Column: QuestionCode

- **Purpose:** Standardized tracking code
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Any unique code
- **Logic:**
  - This is YOUR chosen code for tracking
  - Can be different from wave-specific codes
  - Must match TrackedQuestions in Tracker_Config
  - Used consistently across all reports
- **Example:** `satisfaction_overall`, `nps_score`, `q10_brand`

#### Column: QuestionLabel

- **Purpose:** Display text for question
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Any descriptive text
- **Logic:** Appears in output tables and charts
- **Example:** `Overall Satisfaction`, `Net Promoter Score`

#### Column: QuestionType

- **Purpose:** Type of question for calculation method
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `Rating`, `NPS`, `SingleChoice`, `Composite`
- **Logic:**
  - **Rating:** Scale questions (1-5, 1-10, etc.) - reports mean/average
  - **NPS:** Net Promoter Score (0-10 scale) - reports NPS score, % promoters/passives/detractors
  - **SingleChoice:** Single-select categorical - reports % for each option
  - **Composite:** Calculated metric combining multiple questions
- **Example:** `Rating`, `NPS`

#### Wave Columns (Wave1, Wave2, Wave3, etc.)

- **Purpose:** Wave-specific question code
- **Required:** YES for waves where question asked
- **Data Type:** Text (question code from data file)
- **Valid Values:**
  - Question code as it appears in that wave's data file
  - Leave blank if question not asked in that wave
- **Logic:**
  - Links standardized QuestionCode to actual column names in each wave's data
  - Handles renumbering (Q10 → Q11 → Q12)
  - Blank cell = question not asked that wave
- **Example:** `Q10`, `Q11`, `satisfaction_rating`

#### Column: SourceQuestions (Optional)

- **Purpose:** Source questions for composite metrics
- **Required:** Only if QuestionType = Composite
- **Data Type:** Text (comma-separated question codes)
- **Valid Values:** Question codes that exist in data
- **Logic:**
  - Lists the questions combined to create composite
  - Must be wave-specific codes
- **Example:** `Q5,Q6,Q7` or `sat1,sat2,sat3`

---

## Question Mapping Scenarios

### Scenario 1: Question Moved (Same Question, Different Codes)

**Example:** Overall satisfaction asked in all 3 waves but renumbered

```
QuestionCode         | QuestionLabel          | QuestionType | Wave1 | Wave2 | Wave3
satisfaction_overall | Overall Satisfaction   | Rating       | Q10   | Q11   | Q12
```

### Scenario 2: Question Added Mid-Study

**Example:** NPS added in Wave 2 onwards

```
QuestionCode | QuestionLabel       | QuestionType | Wave1 | Wave2 | Wave3
nps_score    | Net Promoter Score  | NPS          |       | Q15   | Q16
```

### Scenario 3: Question Removed

**Example:** Brand awareness asked in Wave 1-2 only

```
QuestionCode      | QuestionLabel    | QuestionType   | Wave1 | Wave2 | Wave3
brand_awareness   | Brand Awareness  | SingleChoice   | Q3    | Q4    |
```

### Scenario 4: Question Unchanged

**Example:** Age asked consistently with same code

```
QuestionCode | QuestionLabel | QuestionType   | Wave1 | Wave2 | Wave3
age          | Age Group     | SingleChoice   | Q1    | Q1    | Q1
```

### Scenario 5: Composite Metric

**Example:** Customer satisfaction index from 3 questions

```
QuestionCode | QuestionLabel              | QuestionType | Wave1          | Wave2          | SourceQuestions
csat_index   | Customer Satisfaction Index| Composite    | Q5,Q6,Q7       | Q6,Q7,Q8       | Q5,Q6,Q7 (W1) Q6,Q7,Q8 (W2)
```

---

## Complete Configuration Example

### Brand Tracking Study with 3 Waves

```
QuestionCode         | QuestionLabel              | QuestionType | Wave1 | Wave2 | Wave3
satisfaction_overall | Overall Satisfaction       | Rating       | Q10   | Q11   | Q12
product_quality      | Product Quality            | Rating       | Q11   | Q12   | Q13
customer_service     | Customer Service           | Rating       | Q12   | Q13   | Q14
nps_score            | Net Promoter Score         | NPS          | Q20   | Q21   | Q22
brand_awareness      | Brand Awareness (Unaided)  | SingleChoice | Q3    | Q4    | Q5
purchase_intent      | Purchase Intent            | SingleChoice | Q5    | Q6    | Q7
loyalty_index        | Customer Loyalty Index     | Composite    |       | Q10,Q11,Q12 | Q11,Q12,Q13
```

**Interpretation:**
- **satisfaction_overall:** Tracked consistently but renumbered each wave (Q10→Q11→Q12)
- **nps_score:** Tracked all waves with consistent renumbering
- **loyalty_index:** New composite added in Wave 2, source questions also renumbered in Wave 3

---

## Common Mistakes

### Mistake 1: Question Code Doesn't Match Data

**Problem:** Error "Question 'Q10' not found in Wave1 data"
**Solution:** Ensure wave-specific codes match actual column names in data files exactly (case-sensitive)

### Mistake 2: QuestionCode Not in Tracker_Config

**Problem:** Question not appearing in output
**Solution:** Ensure QuestionCode exists in TrackedQuestions sheet of Tracker_Config

### Mistake 3: Wrong QuestionType

**Problem:** Incorrect calculations (e.g., average of NPS instead of NPS score)
**Solution:**
- Use `Rating` for 1-10 scales (calculates mean)
- Use `NPS` for 0-10 likelihood to recommend (calculates NPS = %promoters - %detractors)

### Mistake 4: Blank Cells for Active Waves

**Problem:** Question shows as "not asked" when it was asked
**Solution:** Ensure wave columns are not blank for waves where question was actually asked

### Mistake 5: Composite SourceQuestions Don't Exist

**Problem:** Composite calculation fails
**Solution:** All SourceQuestions must exist in that wave's data file

---

## Validation Rules

The module validates:

1. **QuestionMap Sheet:**
   - QuestionCode is unique
   - QuestionType is valid
   - At least one wave column has value

2. **Wave Columns:**
   - All specified question codes exist in corresponding wave data files

3. **Composites:**
   - SourceQuestions specified when QuestionType = Composite
   - Source questions exist in wave data

4. **Integration with Config:**
   - All QuestionCode in Tracker_Config TrackedQuestions exist in QuestionMap
   - Wave IDs match between files

---

## Best Practices

### 1. Consistent QuestionCode

Use clear, descriptive tracking codes that remain constant:
- ✅ Good: `satisfaction_overall`, `nps_score`, `brand_aware_unaided`
- ❌ Bad: `q10`, `question_1`, `sat`

### 2. Document Changes

Add notes about why questions moved:
- Use Notes column (if added)
- Keep version history of mapping file

### 3. Test Mapping Before Full Analysis

- Run tracker on 2 waves first
- Verify questions map correctly
- Check calculations match expectations
- Then add remaining waves

### 4. Handle Question Wording Changes

If question wording changes significantly:
- Consider treating as new question (new QuestionCode)
- Document wording change in QuestionLabel
- Explain discontinuity in reporting

### 5. Wave Column Naming

Use clear wave identifiers that match Tracker_Config:
- ✅ Good: Wave1, Wave2, Wave3 or Q1_2024, Q2_2024, Q3_2024
- ❌ Bad: W1, W2, W3 (if Tracker_Config uses Quarter1, Quarter2, Quarter3)

---

## File Linking Summary

**Two files required:**

1. **Tracker_Config_Template.xlsx**
   - Defines waves (data files, dates)
   - Specifies analysis settings
   - Lists questions to track
   - Defines banner segments

2. **Tracker_Question_Mapping_Template.xlsx**
   - Maps question codes across waves
   - Defines question types
   - Handles renumbering and changes

**Link them by:**
- Specifying both paths in R code, OR
- Using naming convention for GUI auto-detection
- Ensure WaveID/Wave column names match between files

---

**End of Tracker Question Mapping Template Manual**
