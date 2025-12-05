# Multi_Mention Tracking Instructions

## Overview

Multi_Mention questions (select-all-that-apply) support **TWO tracking modes**:

1. **Binary Mode**: Tracks 0/1 values in option columns (e.g., Q10_1, Q10_2, Q10_3)
2. **Category Mode**: Tracks text labels in option columns (e.g., "We rely on CCS", "Personal records")

The tracker automatically detects which mode to use based on your TrackingSpecs syntax.

---

## Data Format Requirements

### Binary Mode Data Format

**Columns:** Question code with numeric suffixes (e.g., Q10_1, Q10_2, Q10_3, Q10_4)

**Values:**
- `1` = option selected/mentioned
- `0` or blank/NA = option not selected

**Example:**
```
RespondentID | Q10_1 | Q10_2 | Q10_3 | Q10_4 | Q10_5
-------------|-------|-------|-------|-------|-------
R001         | 1     | 0     | 1     | 1     | 0
R002         | 0     | 1     | 0     | 0     | 1
R003         | 1     | 1     | 0     | 1     | 0
```

### Category Mode Data Format

**Columns:** Question code with numeric suffixes (e.g., Q10_1, Q10_2, Q10_3, Q10_4)

**Values:** Text labels when selected, blank/NA when not selected

**Example:**
```
RespondentID | Q10_1                    | Q10_2              | Q10_3 | Q10_4
-------------|--------------------------|-----------------------|-------|-------
R001         | We rely on CCS           | Personal records      |       | Other
R002         | Internal store system    |                       |       |
R003         | We rely on CCS           | Other                 |       |
```

**IMPORTANT:**
- Each column can contain ANY of the available text labels (not fixed per column)
- Respondents who select multiple options will have text in multiple columns
- The tracker searches for your specified text across ALL option columns

---

## Tracking Template Configuration

### Question Mapping Setup

**Required Columns:**
```
QuestionCode | QuestionText              | QuestionType  | Wave1 | Wave2 | Wave3
-------------|---------------------------|---------------|-------|-------|-------
Q10          | method of tracking        | Multi_Mention | NA    | Q10   | Q10
```

**Wave Mapping:**
- Enter question code for each wave where the question appears
- Use `NA` for waves where question was not asked
- Tracker will automatically find first available wave for mode detection

---

## TrackingSpecs Syntax

### Binary Mode - Track Specific Options

**Syntax:** `option:COLUMN_NAME`

**Use When:** Your data has 0/1 values and you want to track specific options

**Examples:**

| TrackingSpecs | What It Tracks |
|---------------|----------------|
| `option:Q10_4` | Only track Q10_4 column |
| `option:Q10_2,option:Q10_5` | Track Q10_2 and Q10_5 only |
| `auto` | Track ALL columns (Q10_1, Q10_2, Q10_3, etc.) |

**When to Use:**
- Client only cares about specific options (e.g., "track awareness of Option 4")
- Need to reduce clutter in output by excluding low-interest options
- Tracking top mentions only

---

### Binary Mode - Track All Options

**Syntax:** `auto`

**Use When:** You want to track all options automatically

**Example:**

| QuestionCode | TrackingSpecs |
|--------------|---------------|
| Q10          | auto          |

**Output:** Tracker detects all Q10_* columns and tracks each one separately

---

### Category Mode - Track Specific Text Values

**Syntax:** `category:TEXT_VALUE`

**Use When:** Your data has text labels and you want to track specific categories

**Examples:**

| TrackingSpecs | What It Tracks |
|---------------|----------------|
| `category:We rely on CCS` | Tracks % who mentioned "We rely on CCS" |
| `category:Personal records,category:Other` | Tracks "Personal records" and "Other" |
| `category:Internal store system (e.g merchandiser control form/register)` | Exact text match including parenthetical |

**Text Matching Rules:**
- **Case-insensitive:** "we rely on CCS" matches "We rely on CCS"
- **Exact match:** Text must match exactly (after trimming whitespace)
- **Searches all columns:** Tracker searches Q10_1, Q10_2, Q10_3, etc. for the text
- **Parentheticals matter:** "Internal store system" ≠ "Internal store system (e.g. register)"

**CRITICAL:** The text in TrackingSpecs must **exactly match** the text in your data (case doesn't matter, but spelling, punctuation, and parentheticals do)

---

## Complete Examples

### Example 1: Binary Mode - Track All Options

**Question:** Q15 "Which social media platforms do you use?" (select all that apply)

**Data Format:**
```
Q15_1 = 1/0 (Facebook)
Q15_2 = 1/0 (Instagram)
Q15_3 = 1/0 (Twitter)
Q15_4 = 1/0 (TikTok)
Q15_5 = 1/0 (LinkedIn)
```

**Tracking Template:**
```
QuestionCode: Q15
QuestionText: Social media usage
QuestionType: Multi_Mention
TrackingSpecs: auto
Wave1: Q15
Wave2: Q15
Wave3: Q15
```

**Output:** 5 rows showing % mentioning each platform (Q15_1, Q15_2, Q15_3, Q15_4, Q15_5)

---

### Example 2: Binary Mode - Track Selected Options Only

**Question:** Q20 "Which features are most important?" (select top 3)

**Data Format:** Same as above (Q20_1 through Q20_8 with 0/1 values)

**Tracking Template:**
```
QuestionCode: Q20
QuestionText: Top features
QuestionType: Multi_Mention
TrackingSpecs: option:Q20_1,option:Q20_3,option:Q20_7
Wave1: Q20
Wave2: Q20
Wave3: Q20
```

**Output:** 3 rows showing only Q20_1, Q20_3, and Q20_7

---

### Example 3: Category Mode - Track Specific Text Categories

**Question:** Q10 "What methods do you use for tracking inventory?" (select all that apply)

**Data Format:**
```
RespondentID | Q10_1                    | Q10_2              | Q10_3 | Q10_4
-------------|--------------------------|-----------------------|-------|-------
R001         | We rely on CCS           | Personal records      |       |
R002         | Internal store system    |                       |       | Other
R003         | We rely on CCS           |                       |       | Other
R004         | Personal records         | Other                 |       |
```

**Tracking Template:**
```
QuestionCode: Q10
QuestionText: method of tracking
QuestionType: Multi_Mention
TrackingSpecs: category:We rely on CCS,category:Personal records,category:Other
Wave1: NA
Wave2: Q10
Wave3: Q10
```

**Output:** 3 rows showing:
- % We rely on CCS (searches all Q10_* columns for this text)
- % Personal records
- % Other

---

## Output Format

### Detail Report

Shows wave-over-wave changes with significance testing:

```
method of tracking

Metric                          | Wave1_Total | Wave2_Total | Wave3_Total
--------------------------------|-------------|-------------|-------------
Sample Size (n)                 |             | 60          | 60

Wave-over-Wave Changes (Total - We rely on CCS):
Comparison    | From  | To    | Change | % Change | Significant
--------------|-------|-------|--------|----------|-------------
Wave1 → Wave2 |       | 6.67  |        |          | No
Wave2 → Wave3 | 6.67  | 3.33  | -3.33  | -50.00   | No
```

### Wave History Report

Shows trend across all waves in single row:

```
QuestionCode | Question              | Type              | Wave2_Total | Wave3_Total
-------------|-----------------------|-------------------|-------------|-------------
Q10          | method of tracking    | % We rely on CCS  | 6.67        | 3.33
Q10          | method of tracking    | % Personal records| 12.50       | 15.00
Q10          | method of tracking    | % Other           | 5.00        | 8.33
```

---

## Common Issues and Troubleshooting

### Issue 1: "All values are non-numeric (converted to NA)" Warning

**Symptom:** Console shows warnings like:
```
WARNING: Q10_4: All 4 values are non-numeric (converted to NA). Check data source.
```

**Cause:** You have text data but the tracker is trying to convert it to numeric.

**Solution:** Use `category:` syntax in TrackingSpecs, not `option:` or `auto`

---

### Issue 2: Question Appears But Values Are Blank

**Symptom:** Q10 appears in output but all values show as 0% or blank

**Cause:** Text in TrackingSpecs doesn't match text in data

**Solution:** Check exact spelling, punctuation, and parentheticals. Copy text directly from data.

**Example of mismatch:**
- TrackingSpecs: `category:Internal store system`
- Data contains: `"Internal store system (e.g merchandiser control form/register)"`
- These DON'T match! Include the parenthetical in TrackingSpecs.

---

### Issue 3: Question Missing from Wave History Report

**Symptom:** Q10 appears in detail report but not wave history report

**Cause:** This was a bug in v2.1 (now fixed). Update to latest version.

**Solution:** Pull latest code with wave history category mode support

---

### Issue 4: "missing value where TRUE/FALSE needed" Error

**Symptom:** Tracker crashes with this error when using `option:Q10_4` syntax

**Cause:** This was a bug in v2.1 (now fixed - Issue-001)

**Solution:** Update to latest version

---

## Quick Decision Guide

**Use Binary Mode (`option:` or `auto`) when:**
- ✓ Your data has 0/1 values
- ✓ You want to track which options were selected
- ✓ Each column represents a fixed option

**Use Category Mode (`category:`) when:**
- ✓ Your data has text labels
- ✓ Text can appear in any column (not fixed per column)
- ✓ You want to track specific text values regardless of which column they're in

---

## Template Quick Reference

### Binary Mode - All Options
```
QuestionCode: Q##
QuestionType: Multi_Mention
TrackingSpecs: auto
```

### Binary Mode - Selected Options
```
QuestionCode: Q##
QuestionType: Multi_Mention
TrackingSpecs: option:Q##_1,option:Q##_4,option:Q##_7
```

### Category Mode - Specific Text Values
```
QuestionCode: Q##
QuestionType: Multi_Mention
TrackingSpecs: category:First Category,category:Second Category,category:Third Category
```

**Remember:** Copy text EXACTLY from your data (case doesn't matter, but spelling does!)

---

## Version Notes

- **v2.1 (2025-12-05)**: Category mode fully functional
  - Fixed data loader to preserve text in sub-columns
  - Fixed wave history report support for category mode
  - Fixed validation to allow category: syntax
  - Fixed mode detection for questions not in Wave1

- **v2.1 (2025-12-04)**: Fixed selective TrackingSpecs bug (Issue-001)

- **v2.0**: Added TrackingSpecs support for Multi_Mention

- **v1.x**: Only supported binary mode with auto-detection

---

**Questions?** Check TECHNICAL_DOCUMENTATION_V2.md for detailed implementation notes.
