# Survey Structure Template - User Manual

**Template File:** `templates/Survey_Structure_Template.xlsx`
**Version:** 10.0
**Last Updated:** 4 December 2025

---

## Overview

The Survey_Structure Template is the **MASTER REFERENCE** for all survey questions, response options, and composite metrics. It is used by multiple TURAS modules (Tabs, Tracker, Confidence, etc.) to understand your survey structure.

**Key Purpose:** Define once, use everywhere - this single file describes your entire survey structure for all analyses.

**Critical:** This file must be accurate and complete. All question codes, types, and options must match your data file exactly.

---

## Template Structure

The template contains **5 sheets**:

1. **Instructions** - Usage guidance
2. **Project** - Project metadata and settings
3. **Questions** - All survey questions and their types
4. **Options** - Response options for each question
5. **Composite_Metrics** - Calculated composite scores

---

## Sheet 1: Instructions

**Purpose:** Overview and common pitfalls.

**Action Required:** Review for understanding. Not read by analysis code.

**Key Points:**
- QuestionCode must be unique across all questions
- Variable_Type must match actual question format
- For Rating questions, always specify Scale_Min and Scale_Max
- Response codes must match between Questions and Options sheets
- Do not use special characters in QuestionCode

---

## Sheet 2: Project

**Purpose:** Project metadata and data file settings.

**Required Columns:** `Setting`, `Value`, `Required`, `Description`

### Field Specifications

#### Setting: project_name

- **Purpose:** Display name for project
- **Required:** YES
- **Data Type:** Text
- **Example:** `Brand Tracker Q1 2024`

#### Setting: project_code

- **Purpose:** Unique identifier (matches folder name)
- **Required:** YES
- **Data Type:** Text
- **Logic:** Should match project root directory name
- **Example:** `BrandTracker_Q1`

#### Setting: client_name

- **Purpose:** Client organization
- **Required:** YES
- **Data Type:** Text
- **Example:** `Acme Corporation`

#### Setting: study_type

- **Purpose:** Type of study
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `Ad-hoc`, `Tracker`, `Panel`, `Longitudinal`
- **Example:** `Tracker`

#### Setting: study_date

- **Purpose:** Study date in YYYYMMDD format
- **Required:** YES
- **Data Type:** Numeric (8 digits)
- **Valid Values:** YYYYMMDD format
- **Example:** `20251018`

#### Setting: data_file

- **Purpose:** Path to survey data file
- **Required:** YES
- **Data Type:** Text (file path)
- **Logic:** Relative path from project folder
- **Example:** `Data/survey_data.xlsx`

#### Setting: output_folder

- **Purpose:** Where to save outputs
- **Required:** YES
- **Data Type:** Text (folder path)
- **Logic:** Relative path from project folder
- **Default:** `Output`
- **Example:** `Output`

#### Setting: total_sample

- **Purpose:** Expected total respondents
- **Required:** YES
- **Data Type:** Integer
- **Example:** `1000`

#### Setting: contact_person

- **Purpose:** Project lead
- **Required:** NO
- **Data Type:** Text
- **Example:** `John Smith`

#### Setting: notes

- **Purpose:** Project description
- **Required:** NO
- **Data Type:** Text
- **Example:** `Q1 2024 brand tracking wave`

#### Setting: weight_column_exists

- **Purpose:** Whether data has weight column(s)
- **Required:** NO
- **Data Type:** Text (Y/N)
- **Valid Values:** `Y` or `N`
- **Default:** `N`
- **Example:** `Y`

#### Setting: weight_columns

- **Purpose:** Weight column names
- **Required:** Only if weight_column_exists = Y
- **Data Type:** Text (comma-separated)
- **Example:** `Weight_Demo,Weight_Final`

#### Setting: default_weight

- **Purpose:** Which weight to use by default
- **Required:** Only if weight_column_exists = Y
- **Data Type:** Text (column name)
- **Example:** `Weight_Final`

#### Setting: weight_description

- **Purpose:** Description of weighting methodology
- **Required:** NO
- **Data Type:** Text
- **Example:** `Weighted to census demographics`

---

## Sheet 3: Questions

**Purpose:** Define all survey questions and their types.

**Required Columns:** `QuestionCode`, `QuestionText`, `Variable_Type`, `Columns`

**Optional Columns:** `Ranking_Format`, `Ranking_Positions`, `Ranking_Direction`, `Category`, `Notes`, `Min_Value`, `Max_Value`

### Field Specifications

#### Column: QuestionCode

- **Purpose:** Unique column name in data file
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Alphanumeric, no spaces
- **Logic:**
  - For multi-mention/ranking: show root code only (Q01, not Q01_1)
  - Must match data file column name exactly
  - Must match question code in Crosstab Config
- **Example:** `Q01`, `satisfaction_overall`
- **Common Mistakes:**
  - Including _1, _2 suffix for multi-mention
  - Spaces in code
  - Doesn't match data file

#### Column: QuestionText

- **Purpose:** Question wording (displays in output)
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Any text
- **Example:** `How satisfied are you with our service?`

#### Column: Variable_Type

- **Purpose:** Question type
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `Single_Mention`, `Multi_Mention`, `Likert`, `Rating`, `NPS`, `Ranking`, `Open_End`, `Numeric`
- **Example:** `Rating`
- **See Question Types table below for details**

#### Column: Columns

- **Purpose:** Number of columns in data file
- **Required:** YES
- **Data Type:** Integer ≥ 1
- **Logic:**
  - `1` for single mention, rating, NPS, numeric
  - `>1` for ranking and multi-mention
- **Example:** `1` or `5`

#### Column: Ranking_Format

- **Purpose:** Ranking data format
- **Required:** Only if Variable_Type = Ranking
- **Data Type:** Text
- **Valid Values:** `Position` or `Item`
- **Logic:**
  - `Position`: Each item has column with rank (Q_BrandA = 3)
  - `Item`: Each rank has column with item name (Q_Rank1 = "BrandA")
- **Example:** `Position`

#### Column: Ranking_Positions

- **Purpose:** Number of rank positions
- **Required:** Only if Variable_Type = Ranking
- **Data Type:** Integer ≥ 1
- **Example:** `3` (for top 3 ranking)

#### Column: Ranking_Direction

- **Purpose:** Rank direction
- **Required:** Only if Variable_Type = Ranking
- **Data Type:** Text
- **Valid Values:** `BestToWorst` or `WorstToBest`
- **Example:** `BestToWorst`

#### Column: Category

- **Purpose:** Question grouping
- **Required:** NO
- **Data Type:** Text
- **Example:** `Satisfaction`, `Demographics`

#### Column: Notes

- **Purpose:** Internal notes
- **Required:** NO
- **Data Type:** Text
- **Example:** `New in 2024`

#### Column: Min_Value

- **Purpose:** Minimum value for numeric questions
- **Required:** Only if Variable_Type = Numeric
- **Data Type:** Numeric (can be decimal or integer)
- **Example:** `1` or `0`

#### Column: Max_Value

- **Purpose:** Maximum value for numeric questions
- **Required:** Only if Variable_Type = Numeric
- **Data Type:** Numeric (can be decimal or integer)
- **Example:** `50` or `100`

---

### Question Types Reference

#### Single_Mention

- **When:** Single-choice questions (pick one option)
- **Data Type:** Character, factor, or numeric
- **Example:** "Which brand do you prefer?"

#### Multi_Mention

- **When:** Multiple-choice (select all that apply)
- **Columns Required:** Yes (number of response columns)
- **Data Type:** Character, factor, or numeric
- **Data Format:** Q5_1, Q5_2, Q5_3, etc.
- **Example:** "Which features do you use? (select all)"

#### Likert

- **When:** Scaled agreement with index weights
- **Data Type:** Numeric, integer, character, factor, or labelled
- **Index:** Yes (weighted average from Index_Weight in Options)
- **Example:** "Strongly Disagree...Strongly Agree"

#### Rating

- **When:** Numeric rating scales
- **Columns Required:** No
- **Data Type:** Numeric, integer, or labelled
- **Index:** Yes (mean value)
- **Example:** "Rate 1-10"

#### NPS

- **When:** Net Promoter Score (0-10)
- **Data Type:** Numeric, integer, or labelled
- **Index:** Yes (NPS calculation: % promoters - % detractors)
- **Example:** "How likely to recommend?"

#### Ranking

- **When:** Rank items in order
- **Data Type:** Numeric or integer
- **Formats:**
  - **Position:** Each item has column with rank (Q_BrandA = 3)
  - **Item:** Each rank has column with item name (Q_Rank1 = "BrandA")
- **Example:** "Rank your top 3 priorities"

#### Open_End

- **When:** Open-ended text responses
- **Data Type:** Character
- **Note:** Not analyzed numerically
- **Example:** "Please explain why..."
- **Logic:** Would exclude this from tab analysis

#### Numeric

- **When:** Open-ended numeric responses
- **Can set:** Min and max values and create bins (check Options sheet)
- **Example:** "What is your age?" (exact number)

---

## Sheet 4: Options

**Purpose:** Define response options for each question.

**Required Columns:** `QuestionCode`, `OptionText`, `DisplayText`, `ShowInOutput`

**Optional Columns:** `DisplayOrder`, `ExcludeFromIndex`, `Index_Weight`, `BoxCategory`, `Min`, `Max`

### Field Specifications

#### Column: QuestionCode

- **Purpose:** Must match Question code in Questions sheet
- **Required:** YES
- **Data Type:** Text
- **Logic:**
  - Must match QuestionCode in Questions sheet exactly
  - For multi-column questions: add _n suffix (Q01_1, Q01_2)
- **Example:** `Q01` or `Q02_1`

#### Column: OptionText

- **Purpose:** Answer value in data (exact match)
- **Required:** YES
- **Data Type:** Text or Numeric
- **Valid Values:** Must match data exactly
- **Logic:** Case-sensitive, must match data file values precisely
- **Example:** `Very Satisfied`, `1`, `5`

#### Column: DisplayText

- **Purpose:** Custom display label
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Any text
- **Logic:** This is what appears in tables and charts
- **Example:** `Very Satisfied (5)` or `Extremely satisfied`

#### Column: DisplayOrder

- **Purpose:** Custom sort order in tables
- **Required:** NO
- **Data Type:** Integer
- **Logic:** Lower numbers appear first
- **Example:** `1`, `2`, `3`

#### Column: ShowInOutput

- **Purpose:** Include in tables?
- **Required:** YES
- **Data Type:** Text (Y or blank)
- **Valid Values:** `Y` or blank
- **Logic:**
  - `Y` = Include in output
  - Blank = Exclude from output
- **Example:** `Y`

#### Column: ExcludeFromIndex

- **Purpose:** Exclude from mean/index calculations
- **Required:** NO
- **Data Type:** Text (Y or blank)
- **Valid Values:** `Y` or blank
- **Logic:**
  - Only applies to questions with mean ratings or indexes
  - Use to exclude "Don't know" responses from calculations
- **Example:** `Y` for Don't know option

#### Column: Index_Weight

- **Purpose:** Weight for Likert or value for mean rating
- **Required:** Only if CreateIndex = Y in Crosstab Config
- **Data Type:** Numeric
- **Valid Values:** -100 to 100
- **Logic:**
  - For Likert: Weight for calculating index
  - For Rating: The numeric value (1-10, etc.)
- **Example:** `100`, `-50`, `5`

#### Column: BoxCategory

- **Purpose:** Group options for summaries
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** Any text
- **Logic:**
  - Groups 2+ options together
  - Example 1: Group 18-20 and 21-24 as "Under 25" for banner
  - Example 2: Group 1-5 rating as "Dissatisfied" for summary
  - Takes effect if BannerBoxCategory set in Crosstab Config Selection sheet
- **Example:** `Satisfied`, `Under 25`

#### Column: Min

- **Purpose:** Minimum value for numeric binning
- **Required:** Only if binning numeric question
- **Data Type:** Numeric
- **Logic:** Used to create age bands or value ranges
- **Example:** `18` (for 18-24 age band)

#### Column: Max

- **Purpose:** Maximum value for numeric binning
- **Required:** Only if binning numeric question
- **Data Type:** Numeric
- **Logic:** Used to create age bands or value ranges
- **Example:** `24` (for 18-24 age band)

---

### Binning Example

For Q10: "What is your age?" (Numeric question capturing exact age)

```
QuestionCode | OptionText | Min | Max
Q10          | 18 - 24    | 18  | 24
Q10          | 25 - 34    | 25  | 34
Q10          | 35 - 44    | 35  | 44
Q10          | 45 +       | 45  | 100
```

**Note:** Make sure bins don't overlap.

---

## Sheet 5: Composite_Metrics

**Purpose:** Define calculated composite scores that combine multiple questions.

**Required Columns:** `CompositeCode`, `CompositeLabel`, `CalculationType`, `SourceQuestions`

**Optional Columns:** `Weights`, `ExcludeFromSummary`, `SectionLabel`, `Notes`

### Field Specifications

#### Column: CompositeCode

- **Purpose:** Unique identifier for composite
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** Must start with `COMP_` (recommended convention)
- **Example:** `COMP_SAT_OVERALL`

#### Column: CompositeLabel

- **Purpose:** Display name in reports
- **Required:** YES
- **Data Type:** Text
- **Example:** `Overall Satisfaction Index`

#### Column: CalculationType

- **Purpose:** How to combine source questions
- **Required:** YES
- **Data Type:** Text
- **Valid Values:** `Mean`, `Sum`, `WeightedMean`
- **Logic:**
  - `Mean`: Simple average
  - `Sum`: Add all values
  - `WeightedMean`: Weighted average using Weights column
- **Example:** `Mean`

#### Column: SourceQuestions

- **Purpose:** Questions to combine
- **Required:** YES
- **Data Type:** Text (comma-separated question codes)
- **Valid Values:**
  - All questions must exist in Questions sheet
  - All questions must be same type (all Rating, all Likert, or all Numeric)
- **Example:** `Q01,Q02,Q03`

#### Column: Weights

- **Purpose:** Weight for each source question
- **Required:** Only if CalculationType = WeightedMean
- **Data Type:** Text (comma-separated numbers)
- **Valid Values:** Numbers matching count of SourceQuestions
- **Logic:** Higher numbers = more weight in calculation
- **Example:** `1,2,1` (gives Q02 twice the weight of Q01 and Q03)

#### Column: ExcludeFromSummary

- **Purpose:** Hide from Index_Summary sheet
- **Required:** NO
- **Data Type:** Text (Y or blank)
- **Valid Values:** `Y` or blank
- **Logic:**
  - `Y` = Hide this composite from Index_Summary
  - Blank = Include in summary (default)
- **Example:** Blank

#### Column: SectionLabel

- **Purpose:** Groups related composites in Index_Summary
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** Any text
- **Example:** `Satisfaction ratings`

#### Column: Notes

- **Purpose:** Internal note
- **Required:** NO
- **Data Type:** Text
- **Valid Values:** Any text
- **Logic:** Not used by Turas
- **Example:** `Updated weighting in 2024`

---

## Complete Example

### Questions Sheet

```
QuestionCode | QuestionText        | Variable_Type | Columns
Q01          | Overall satisfaction| Rating        | 1
Q02          | Product quality     | Rating        | 1
Q03          | Customer service    | Rating        | 1
Q04          | Likelihood to rec   | NPS           | 1
Q05          | Gender              | Single_Mention| 1
```

### Options Sheet

```
QuestionCode | OptionText | DisplayText           | ShowInOutput | Index_Weight
Q01          | 1          | Very dissatisfied (1) | Y            | 1
Q01          | 2          | Dissatisfied (2)      | Y            | 2
Q01          | 3          | Neutral (3)           | Y            | 3
Q01          | 4          | Satisfied (4)         | Y            | 4
Q01          | 5          | Very satisfied (5)    | Y            | 5
Q05          | 1          | Male                  | Y            |
Q05          | 2          | Female                | Y            |
```

### Composite_Metrics Sheet

```
CompositeCode       | CompositeLabel         | CalculationType | SourceQuestions | Weights
COMP_SAT_OVERALL    | Overall Satisfaction   | WeightedMean    | Q01,Q02,Q03    | 1,2,1
```

---

## Common Mistakes

### Mistake 1: QuestionCode Mismatch

**Problem:** Question not found in analysis
**Solution:** Ensure QuestionCode matches data column name exactly (case-sensitive)

### Mistake 2: Including _1 Suffix

**Problem:** Multi-mention question not analyzed correctly
**Solution:** Use root code only (Q01, not Q01_1) in Questions sheet

### Mistake 3: OptionText Doesn't Match Data

**Problem:** Response options not displayed correctly
**Solution:** OptionText must match data values exactly (case-sensitive)

### Mistake 4: Missing Index_Weight for Rating

**Problem:** Mean calculation incorrect
**Solution:** For Rating questions, Index_Weight should match the numeric scale values

### Mistake 5: Composite SourceQuestions Don't Exist

**Problem:** Composite calculation fails
**Solution:** All SourceQuestions must exist in Questions sheet

---

## Validation Rules

The module validates:

1. **Questions Sheet:**
   - QuestionCode is unique
   - Variable_Type is valid
   - Required columns present

2. **Options Sheet:**
   - All QuestionCode exist in Questions sheet
   - OptionText is populated

3. **Composite_Metrics Sheet:**
   - All SourceQuestions exist
   - Weights count matches SourceQuestions count (if WeightedMean)
   - All source questions are same type

---

**End of Survey Structure Template Manual**
