# TurasTabs - Composite Scores & Index Summary User Manual

**Version:** 10.0
**Last Updated:** December 2, 2025

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [What are Composite Scores?](#2-what-are-composite-scores)
3. [Setting Up Composite Metrics](#3-setting-up-composite-metrics)
4. [Configuration Settings](#4-configuration-settings)
5. [Understanding the Output](#5-understanding-the-output)
6. [Troubleshooting](#6-troubleshooting)
7. [Tips and Best Practices](#7-tips-and-best-practices)
8. [Quick Reference Card](#8-quick-reference-card)
9. [Support and Additional Resources](#9-support-and-additional-resources)

---

## 1. Introduction

This manual explains how to use the **Composite Scores** and **Index Summary** features in TurasTabs. These features allow you to:

- Combine multiple questions into a single composite metric
- Create weighted averages of related questions
- Generate executive summary tables showing all key metrics
- View all ratings, indices, and composites in one place

### 1.1 Who Should Use This Feature?

This feature is ideal for analysts who need to:

- Report on overall satisfaction scores
- Create summary dashboards for executives
- Calculate multi-item indices (e.g., brand health, customer experience)
- Compare composite scores across demographic groups

---

## 2. What are Composite Scores?

A **composite score** combines multiple related questions into a single metric. This is useful when you want to measure an overall concept that is captured by several individual questions.

### 2.1 Example Use Cases

**Example 1: Overall Satisfaction**

You have three satisfaction questions:
- SAT_01: Product Quality (rated 1-10)
- SAT_02: Customer Service (rated 1-10)
- SAT_03: Value for Money (rated 1-10)

You can create a composite called "Overall Satisfaction" that calculates the average of these three questions. If a customer rates them 8, 7, and 9, their Overall Satisfaction score would be 8.0.

**Example 2: Brand Health Index**

You measure brand health with five questions, but some are more important than others. You can create a weighted composite:
- Brand Awareness (weight: 1)
- Brand Trust (weight: 2 - more important)
- Purchase Intent (weight: 2 - more important)

The composite will give twice as much weight to Trust and Purchase Intent compared to Awareness.

### 2.2 Types of Composite Calculations

TurasTabs supports three types of composite calculations:

| Type | Description |
|------|-------------|
| **Mean** | Simple average of all source questions. All questions weighted equally. |
| **Sum** | Total of all source questions. Useful for creating cumulative scores. |
| **WeightedMean** | Weighted average where some questions count more than others. Requires you to specify weights for each question. |

---

## 3. Setting Up Composite Metrics

Composite metrics are defined in your `Survey_Structure.xlsx` file, in a new sheet called **"Composite_Metrics"**.

### 3.1 Step-by-Step Setup

1. **Open your Survey_Structure.xlsx file**
   - This is the file that contains your Questions and Options sheets.

2. **Create a new sheet called "Composite_Metrics"**
   - Right-click on a sheet tab, select "Insert", and name it exactly: `Composite_Metrics` (with underscore, no spaces).

3. **Set up the column headers**

   In row 1 of the Composite_Metrics sheet, add these column headers:

   | Column A | Column B | Column C |
   |----------|----------|----------|
   | CompositeCode | CompositeLabel | CalculationType |

   Continue with these headers in columns D through H:
   - Column D: `SourceQuestions`
   - Column E: `Weights`
   - Column F: `ExcludeFromSummary`
   - Column G: `SectionLabel`
   - Column H: `Notes`

4. **Fill in your composite definitions**
   - See Section 3.2 below for detailed column descriptions and examples.

### 3.2 Column Descriptions

Each column in the Composite_Metrics sheet serves a specific purpose:

#### CompositeCode
- **Required:** Yes
- A unique identifier for this composite
- Must start with `COMP_` (recommended convention)
- Example: `COMP_SAT_OVERALL`

#### CompositeLabel
- **Required:** Yes
- The display name that appears in reports
- Example: `Overall Satisfaction Index`

#### CalculationType
- **Required:** Yes
- Must be one of: `Mean`, `Sum`, or `WeightedMean`
- Example: `Mean`

#### SourceQuestions
- **Required:** Yes
- Comma-separated list of question codes to combine
- All questions must exist in your Questions sheet
- All questions must be the same type (all Rating, or all Likert, or all Numeric)
- Example: `SAT_01,SAT_02,SAT_03`

#### Weights
- **Required:** Only if CalculationType is `WeightedMean`
- Comma-separated numbers matching the number of SourceQuestions
- Higher numbers = more weight in the calculation
- Example: `1,2,1` (gives SAT_02 twice the weight of SAT_01 and SAT_03)

#### ExcludeFromSummary
- **Required:** No
- Enter `Y` to hide this composite from the Index_Summary sheet
- Leave blank to include in summary (default)

#### SectionLabel
- **Required:** No
- Groups related composites in the Index_Summary sheet
- Example: `SATISFACTION METRICS`

#### Notes
- **Required:** No
- Internal documentation for your reference
- Not used by TurasTabs

### 3.3 Complete Example

Here's a complete example showing three composite definitions:

| Composite Code | Composite Label | Calculation Type | Source Questions | Weights |
|----------------|-----------------|------------------|------------------|---------|
| COMP_SAT | Overall Satisfaction | Mean | SAT_01,SAT_02,SAT_03 | |
| COMP_QUALITY | Quality Index | WeightedMean | QUAL_01,QUAL_02 | 2,1 |
| COMP_TOTAL | Total Score | Sum | SCORE_01,SCORE_02,SCORE_03 | |

**Key points about this example:**
- `COMP_SAT` uses Mean - simple average of three questions
- `COMP_QUALITY` uses WeightedMean - QUAL_01 counts twice as much as QUAL_02
- `COMP_TOTAL` uses Sum - adds up all three scores
- Weights column is blank for Mean and Sum (only needed for WeightedMean)

---

## 4. Configuration Settings

You can control how composite scores and the Index Summary appear in your output by adding settings to your `Crosstab_Config.xlsx` file.

### 4.1 Available Settings

Add these rows to the **Settings** sheet in your `Crosstab_Config.xlsx` file:

| Setting | Default | Description |
|---------|---------|-------------|
| `create_index_summary` | Y | Create the Index_Summary sheet. Set to N to skip. |
| `index_summary_show_sections` | Y | Group metrics by SectionLabel. Set to N for flat list. |
| `index_summary_show_base_sizes` | Y | Show base sizes at bottom of summary. Set to N to hide. |
| `index_summary_show_composites` | Y | Include composite scores in summary. Set to N to exclude. |
| `index_summary_decimal_places` | 1 | Number of decimal places for summary (0-3). |

**Note:** All settings are optional. If you don't add them, TurasTabs will use the default values shown above.

---

## 5. Understanding the Output

When you run TurasTabs with composite scores defined, you'll see them in two places:

### 5.1 Crosstabs Sheet

Composite scores appear in the main Crosstabs sheet just like regular questions:
- They have a question header showing the CompositeCode and CompositeLabel
- They show base sizes (unweighted, weighted, effective)
- They display the calculated score across all banner columns
- If significance testing is enabled, they show comparison letters

### 5.2 Index_Summary Sheet (NEW)

This is a new sheet that appears in your Excel output, positioned between the Summary and Crosstabs sheets. It provides an executive dashboard view of all your key metrics.

**What's included:**
- All rating question averages (questions with Variable_Type = Rating)
- All Likert indices (questions with Variable_Type = Likert)
- All NPS scores (questions with Variable_Type = NPS)
- Top/Bottom Box summaries (if you've defined BoxCategory aggregations)
- All composite scores (marked with a → symbol)

**How it's organized:**
- Metrics are grouped by SectionLabel (if you've defined sections)
- Section headers appear in bold with gray background
- Composite scores are marked with → and shown in light yellow
- Column structure matches your banner exactly
- Significance letters appear (if testing is enabled)
- Base sizes shown at the bottom

**Example layout:**

```
Section: SATISFACTION
Product Quality                 8.1    8.0    8.2
Customer Service               6.9    6.7    7.1
→ Overall Satisfaction         7.5    7.3    7.7

Section: LOYALTY
NPS                            +42    +38    +46
Recommend (Top 2 Box)          68%    65%    71%
```

---

## 6. Troubleshooting

Here are solutions to common issues you might encounter:

### Error: "Composite_Metrics sheet not found"
**Solution:** This is just a warning, not an error. It means you haven't defined any composites yet. If you don't need composites, you can ignore this message.

### Error: "Composite references question that does not exist"
- **Problem:** You've listed a question in SourceQuestions that doesn't exist in your Questions sheet.
- **Solution:** Double-check the spelling of all question codes in your SourceQuestions column. They must match exactly with QuestionCode values in your Questions sheet.

### Error: "Composite combines Rating and Likert questions"
- **Problem:** You're trying to combine different types of questions in one composite.
- **Solution:** All source questions must be the same type. Create separate composites for Rating questions and Likert questions.

### Error: "Weight count does not match source question count"
- **Problem:** You're using WeightedMean but the number of weights doesn't match the number of source questions.
- **Solution:** If you have 3 source questions, you must have 3 weights (e.g., 1,2,1). Count the commas - there should be one less comma than questions.

### Issue: "Composite shows NA in output"
- **Problem:** All respondents are missing data for the source questions.
- **Solution:** Check your data file to ensure the source questions have valid responses. Also check if any source questions have ExcludeFromIndex = Y in your Options sheet.

### Issue: "Index_Summary sheet is empty"
- **Problem:** You don't have any Rating, Likert, NPS questions, or composites in your survey.
- **Solution:** The Index_Summary sheet only shows metrics from these question types. If your survey only has single-choice or multi-choice questions, this sheet will be empty.

---

## 7. Tips and Best Practices

### 7.1 Naming Conventions

- Start all composite codes with `COMP_` for easy identification
- Use descriptive labels that clearly explain what's being measured
- Group related composites with consistent SectionLabel values

### 7.2 When to Use Each Calculation Type

**Use Mean when:**
- All source questions are equally important
- You want a simple, easy-to-explain average
- You're combining satisfaction or rating questions

**Use WeightedMean when:**
- Some questions are more important than others
- You want to emphasize certain aspects (e.g., product quality matters more than packaging)
- You have research-backed weights (e.g., from driver analysis)

**Use Sum when:**
- You're creating a cumulative score or total
- Each source question represents a separate item to count
- Example: Total number of features used, total satisfaction points

### 7.3 Working with Missing Data

TurasTabs handles missing data intelligently:
- If a respondent is missing one source question, the composite uses their other responses
- If a respondent is missing all source questions, their composite is NA
- This is called "pairwise deletion" and maximizes your sample size

### 7.4 Using Sections Effectively

Sections help organize your Index_Summary sheet:
- Use uppercase labels for consistency (e.g., SATISFACTION, LOYALTY, QUALITY)
- Group composites that measure related concepts
- Standard questions are automatically grouped with composites in the same section
- Leave SectionLabel blank for composites that don't fit a category

### 7.5 Quality Checks

Before finalizing your composites:
- Run a test with a small dataset to verify calculations
- Manually calculate a few composite scores to confirm they match
- Check that composite scores are in a reasonable range
- Review the Index_Summary sheet to ensure all expected metrics appear
- Verify that significance testing works as expected

---

## 8. Quick Reference Card

### Required Files
- `Survey_Structure.xlsx` → Add "Composite_Metrics" sheet
- `Crosstab_Config.xlsx` → Optionally add index_summary settings

### Required Columns
- `CompositeCode` (unique ID)
- `CompositeLabel` (display name)
- `CalculationType` (Mean/Sum/WeightedMean)
- `SourceQuestions` (comma-separated codes)

### Optional Columns
- `Weights` (required only for WeightedMean)
- `ExcludeFromSummary` (Y to hide from Index_Summary)
- `SectionLabel` (groups in Index_Summary)
- `Notes` (documentation)

### Output Locations
- **Crosstabs sheet:** Full details for each composite
- **Index_Summary sheet:** Dashboard view of all metrics

### Key Rules
- All source questions must be same type (Rating/Likert/Numeric)
- CompositeCodes must be unique and not match any QuestionCode
- Weight count must equal source question count
- Composites appear with → symbol in Index_Summary

---

## 9. Support and Additional Resources

For additional help with TurasTabs composite scores:

### Documentation
- TurasTabs User Manual (main documentation)
- TurasTabs Quick Reference Guide
- Survey Structure Template (with examples)

### Version History

| Version | Changes |
|---------|---------|
| 1.0 | Initial release - November 2025. Added composite scores and Index Summary features. |

---

**End of Manual**
