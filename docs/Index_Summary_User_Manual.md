# TURAS Index Summary Module - User Manual

**Module Version:** V10.1
**Document Date:** November 2025
**System:** TURAS Crosstabulation Engine

---

## Table of Contents

1. [Overview](#overview)
2. [What is the Index Summary?](#what-is-the-index-summary)
3. [When to Use](#when-to-use)
4. [Enabling the Index Summary](#enabling-the-index-summary)
5. [Configuration Options](#configuration-options)
6. [Understanding the Output](#understanding-the-output)
7. [Working with Composite Scores](#working-with-composite-scores)
8. [Examples](#examples)
9. [Troubleshooting](#troubleshooting)

---

## Overview

The **Index Summary** module creates an executive summary sheet in your crosstab output that consolidates all key metrics (averages, indices, NPS scores, and composite scores) into a single, easy-to-read table.

**Key Benefits:**
- Quick overview of all important metrics at a glance
- Professional presentation for stakeholders
- Automatic grouping of composite scores with their source questions
- Consistent formatting with your standard crosstab output

---

## What is the Index Summary?

The Index_Summary sheet is an automatically generated Excel worksheet that appears in your crosstab output file. It includes:

- **Average/Mean scores** from rating questions
- **Index values** from indexed questions
- **NPS scores** from Net Promoter Score questions
- **Top/Bottom Box percentages** from categorical questions
- **Composite scores** (if defined) - calculated metrics combining multiple questions
- **Base sizes** - unweighted and weighted sample counts

All metrics are displayed across your banner structure (Total and any subgroups).

---

## When to Use

Use the Index Summary when you need:

✓ **Executive reporting** - Quick overview for stakeholders
✓ **Tracking studies** - Monitor key metrics over waves
✓ **Dashboard creation** - Source data for visual dashboards
✓ **Quality control** - Verify all key metrics at a glance
✓ **Composite analysis** - See composite scores alongside their components

**Do not use when:**
- You only need detailed frequency distributions
- File size is a critical concern (adds minimal overhead)
- You want to limit output to specific questions only

---

## Enabling the Index Summary

### Step 1: Update Configuration File

Open your `Crosstab_Config.xlsx` file and navigate to the **Settings** sheet.

Add the following setting (if not already present):

| Setting | Value |
|---------|-------|
| `create_index_summary` | `Y` |

**Options:**
- `Y` = Create Index_Summary sheet
- `N` = Do not create (default if setting missing)

### Step 2: Run Analysis

Execute your crosstab analysis as normal. The system will automatically:
1. Extract all Average, Index, and Score rows from your results
2. Include any defined composite scores
3. Organize by section (if sections are defined)
4. Create the Index_Summary sheet in your output workbook

---

## Configuration Options

All settings are optional and use sensible defaults if not specified.

### Available Settings

| Setting | Default | Options | Description |
|---------|---------|---------|-------------|
| `create_index_summary` | `N` | `Y`/`N` | Master switch to enable/disable |
| `index_summary_show_sections` | `Y` | `Y`/`N` | Group metrics by section headers |
| `index_summary_show_base_sizes` | `Y` | `Y`/`N` | Show base sizes at bottom |
| `index_summary_show_composites` | `Y` | `Y`/`N` | Include composite scores |
| `index_summary_decimal_places` | (uses `decimal_places_ratings`) | `0-3` | Override decimal places for display |

### Example Configuration

```
Setting                          Value
create_index_summary            Y
index_summary_show_sections     Y
index_summary_show_base_sizes   Y
index_summary_show_composites   Y
```

---

## Understanding the Output

### Sheet Structure

The Index_Summary sheet contains:

**1. Header Section**
```
INDEX & RATING SUMMARY
Survey: [Your Project Name]
Base: [Base Description]
```

**2. Metrics Table**

| Metric | Total | Male | Female | Age 18-34 | Age 35-54 | Age 55+ |
|--------|-------|------|--------|-----------|-----------|---------|
| Q23 - Product Quality | 8.1 | 8.0 | 8.2 A | 7.9 | 8.1 | 8.3 B |
| Q25 - Customer Service | 7.5 | 7.4 | 7.6 | 7.3 | 7.5 | 7.8 A |
| → Overall Satisfaction (Q23, Q25) | 7.8 | 7.7 | 7.9 A | 7.6 | 7.8 | 8.0 B |

**3. Base Sizes Section**
```
Base sizes:
Unweighted n:    500   245   255   180   160   160
Weighted n:      500   250   250   167   167   166
```

### Visual Indicators

**Section Headers** - Gray background, bold text
Organizes metrics into logical groups (e.g., "SATISFACTION METRICS")

**Composite Rows** - Cream/tan background, → prefix
Derived metrics calculated from multiple source questions

**Source Questions** - Indented under composites
Individual questions that make up the composite

**Significance Letters** - Blue superscript
Statistical significance indicators (matching your crosstabs)

---

## Working with Composite Scores

### How Composites Appear

Composites are automatically grouped with their source questions:

```
SATISFACTION METRICS
────────────────────────────────────────
→ Overall Satisfaction (Q23, Q25, Q27)   7.8   7.7   7.9
  Q23 - Product Quality                  8.1   8.0   8.2
  Q25 - Customer Service                 7.5   7.4   7.6
  Q27 - Value for Money                  7.6   7.5   7.7
```

**Benefits:**
- See the composite and its components together
- Verify composite calculation logic
- Identify which individual questions drive the composite score

### Defining Composites

Composites are defined in the `Composite_Metrics` sheet of your `Survey_Structure.xlsx` file.

**Key Fields:**
- `CompositeCode` - Unique identifier (e.g., COMP_SAT)
- `CompositeLabel` - Display name
- `CalculationType` - Mean, Sum, or WeightedMean
- `SourceQuestions` - Comma-separated question codes (e.g., Q23,Q25,Q27)
- `SectionLabel` - Optional grouping label

**Example:**
```
CompositeCode: COMP_SAT
CompositeLabel: Overall Satisfaction
CalculationType: Mean
SourceQuestions: Q23,Q25,Q27
SectionLabel: SATISFACTION METRICS
```

For full details, see the Composite Scores User Manual.

---

## Examples

### Example 1: Basic Index Summary

**Configuration:**
```
create_index_summary = Y
```

**Output:**
- All rating/index/score questions appear in alphabetical order
- Base sizes shown at bottom
- Standard formatting applied

**Use Case:** Simple overview of all key metrics

---

### Example 2: Sectioned Summary with Composites

**Configuration:**
```
create_index_summary = Y
index_summary_show_sections = Y
index_summary_show_composites = Y
```

**Output:**
- Metrics organized by section headings
- Composites appear with their source questions grouped beneath
- Professional presentation for executive reporting

**Use Case:** Complex survey with multiple metric categories

---

### Example 3: Summary Without Composites

**Configuration:**
```
create_index_summary = Y
index_summary_show_composites = N
```

**Output:**
- Only original survey questions appear
- Composites are hidden (but still calculated in individual sheets)
- Simplified view

**Use Case:** Focus on raw question data only

---

## Troubleshooting

### Index_Summary sheet is not created

**Possible Causes:**
1. `create_index_summary` not set to `Y` in config
2. No questions with Average/Index/Score row types
3. Error during processing (check error log)

**Solutions:**
- Verify config setting is exactly `Y` (case insensitive)
- Ensure at least one rating or indexed question is being analyzed
- Check Error Log sheet in output file for specific error messages

---

### Decimal separator doesn't match crosstabs

**Cause:** System automatically matches your config `decimal_separator` setting

**Solution:**
- Decimal formatting is inherited from your main config
- No separate setting needed
- Values display as periods (.) or commas (,) based on your regional settings

---

### Composite appears without source questions

**Cause:** Source questions not selected for analysis or don't exist

**Solutions:**
1. Verify source questions are in your `Questions` sheet
2. Ensure source questions are selected in crosstab selection
3. Check question codes match exactly (case sensitive)

---

### Base sizes are blank

**Cause:** Rare - typically indicates a processing error

**Solutions:**
1. Verify at least one question processed successfully
2. Check that banner structure is valid
3. Review Error Log sheet for details

---

### Questions appearing that shouldn't

**Cause:** Any question with Average/Index/Score rows will appear

**Solutions:**
1. The summary includes all metric rows from all processed questions
2. To exclude specific questions, don't include them in your crosstab selection
3. All rating questions produce Average rows and will appear

---

## Technical Notes

**Performance:**
- Minimal overhead (< 1 second for typical surveys)
- Does not slow down standard crosstab processing

**Compatibility:**
- Works with all question types that produce metrics
- Compatible with significance testing
- Supports weighted and unweighted analysis
- Works with complex banner structures

**Limitations:**
- Only displays metric rows (Average, Index, Score, Top/Bottom Box)
- Does not display frequency distributions
- Source questions must exist in the dataset to be grouped with composites

---

## Support

For additional assistance:

1. **Configuration Questions** - Review `Crosstab_Config.xlsx` template
2. **Composite Scores** - See `Composite_Scores_User_Manual.docx`
3. **Technical Issues** - Contact TURAS support with Error Log details
4. **Feature Requests** - Document desired functionality and submit to development team

---

**Document Version:** 1.0
**Last Updated:** November 2025
**Module Version:** V10.1
