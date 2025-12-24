# Turas MaxDiff Module - User Manual

**Version:** 10.0
**Last Updated:** December 2025

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Getting Started](#2-getting-started)
3. [Configuration Workbook Guide](#3-configuration-workbook-guide)
4. [Design Mode](#4-design-mode)
5. [Analysis Mode](#5-analysis-mode)
6. [Understanding the Output](#6-understanding-the-output)
7. [Working with Segments](#7-working-with-segments)
8. [Configuration Template Reference](#8-configuration-template-reference)
9. [Troubleshooting](#9-troubleshooting)
10. [Best Practices](#10-best-practices)
11. [Glossary](#11-glossary)

---

## 1. Introduction

### 1.1 What is MaxDiff?

MaxDiff (Maximum Difference Scaling), also known as Best-Worst Scaling, is a research technique for measuring the relative importance or preference of multiple items. In each task, respondents are shown a subset of items and asked to select:
- The **BEST** (most important/preferred) item
- The **WORST** (least important/preferred) item

This approach forces trade-offs and produces more discriminating results than traditional rating scales.

### 1.2 What Does This Module Do?

The Turas MaxDiff module provides two operational modes:

| Mode | Purpose |
|------|---------|
| **DESIGN** | Generate optimal experimental designs for your MaxDiff study |
| **ANALYSIS** | Analyse survey responses and compute preference scores |

### 1.3 Key Features

- Excel-based configuration (no coding required)
- Multiple scoring methods (counts, logit, Hierarchical Bayes)
- Segment-level analysis
- Publication-ready charts
- Individual-level preference utilities

---

## 2. Getting Started

### 2.1 Prerequisites

Before using the module, ensure you have:
- R version 4.0 or higher
- Required R packages (installed automatically on first run):
  - `openxlsx` - Excel file handling
  - `survival` - Logit models
  - `ggplot2` - Charts
  - `cmdstanr` - Hierarchical Bayes (optional)

### 2.2 Launching the Module

#### Option A: From Turas Launcher

1. Open R/RStudio
2. Set your working directory to the Turas folder
3. Run: `source("launch_turas.R")`
4. Click the **MaxDiff** button
5. Browse to select your configuration file
6. Click **Run**

#### Option B: From R Console

```r
# Navigate to Turas directory
setwd("/path/to/Turas")

# Load the module
source("modules/maxdiff/R/00_main.R")

# Run with your config file
run_maxdiff("path/to/your/maxdiff_config.xlsx")
```

### 2.3 Typical Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  1. CREATE CONFIG    Create Excel workbook with items       │
│         ↓            and settings                           │
├─────────────────────────────────────────────────────────────┤
│  2. DESIGN MODE      Generate experimental design           │
│         ↓            (run module with Mode = DESIGN)        │
├─────────────────────────────────────────────────────────────┤
│  3. PROGRAM SURVEY   Use design file to build survey        │
│         ↓            in your survey platform                │
├─────────────────────────────────────────────────────────────┤
│  4. COLLECT DATA     Field your survey                      │
│         ↓                                                   │
├─────────────────────────────────────────────────────────────┤
│  5. ANALYSIS MODE    Analyse responses                      │
│                      (run module with Mode = ANALYSIS)      │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Configuration Workbook Guide

The module is controlled by a single Excel workbook (.xlsx) containing up to six sheets. You can create this workbook from the template or build it yourself.

### 3.1 Getting the Template

**Option 1: Generate from R**
```r
setwd("path/to/Turas/modules/maxdiff")
source("templates/create_maxdiff_template.R")
```

This creates `templates/maxdiff_config_template.xlsx` with all sheets, instructions, and color-coded examples.

**Option 2: Copy existing template**
Use the pre-generated template at:
`modules/maxdiff/docs/maxdiff_config_template.xlsx`

### 3.2 Template Color Coding

- **Yellow cells** = Required setting - must be filled in
- **Green cells** = Optional setting - has sensible default
- **Blue cells** = Example data - replace with your own

### 3.3 PROJECT_SETTINGS (Required)

Global project parameters in a two-column format:

| Setting_Name | Example Value | Description |
|--------------|---------------|-------------|
| `Project_Name` | `BankX_Benefits_2025` | Unique identifier (no spaces) |
| `Mode` | `ANALYSIS` | `DESIGN` or `ANALYSIS` |
| `Raw_Data_File` | `C:\Data\responses.xlsx` | Path to survey data (absolute or relative) |
| `Data_File_Sheet` | `Sheet1` | Sheet name in data file |
| `Design_File` | `C:\Data\design.xlsx` | Path to design file |
| `Output_Folder` | `C:\Output\MaxDiff\` | Where to save results |
| `Weight_Variable` | `weight` | Column name for weights (blank = unweighted) |
| `Respondent_ID_Variable` | `RespID` | Unique respondent ID column |
| `Filter_Expression` | `Complete==1` | R filter expression (blank = no filter) |
| `Seed` | `12345` | Random seed for reproducibility |

**Path Notes:**
- Use **absolute paths** for files outside the Turas folder (e.g., OneDrive)
- Use **relative paths** for files in the same folder as your config
- Windows example: `C:\Users\duncan\OneDrive\Data\survey.xlsx`
- Mac/Linux example: `/Users/duncan/OneDrive/Data/survey.xlsx`

### 3.4 ITEMS (Required)

Define all items/attributes to be evaluated:

| Column | Required | Description |
|--------|----------|-------------|
| `Item_ID` | Yes | Unique identifier (e.g., `ITEM_01`) |
| `Item_Label` | Yes | Full text shown to respondents |
| `Item_Group` | No | Category for grouping in output |
| `Include` | No | `1` = include, `0` = exclude (default: 1) |
| `Anchor_Item` | No | `1` = use as HB reference item (default: 0) |
| `Display_Order` | No | Order in output tables |

**Example:**

| Item_ID | Item_Label | Item_Group | Include | Anchor_Item |
|---------|------------|------------|---------|-------------|
| ITEM_01 | Low monthly fees | Price | 1 | 0 |
| ITEM_02 | High interest rates | Returns | 1 | 0 |
| ITEM_03 | Mobile app quality | Digital | 1 | 0 |
| ITEM_04 | Branch locations | Access | 1 | 1 |

**Important:** Keep Item_IDs consistent between design and analysis phases!

### 3.5 DESIGN_SETTINGS (Required for DESIGN mode)

Parameters for experimental design generation:

| Parameter_Name | Example | Description |
|----------------|---------|-------------|
| `Items_Per_Task` | `4` | Items shown per task (typically 4-5) |
| `Tasks_Per_Respondent` | `12` | Tasks per respondent (typically 10-15) |
| `Num_Versions` | `3` | Number of design versions |
| `Design_Type` | `BALANCED` | `BALANCED`, `OPTIMAL`, or `RANDOM` |
| `Max_Item_Repeats` | `5` | Max times an item appears per respondent |
| `Force_Min_Pair_Balance` | `YES` | Ensure all item pairs appear equally |

**Design Type Recommendations:**

| Items | Recommended Type | Items_Per_Task | Tasks |
|-------|------------------|----------------|-------|
| 6-10 | BALANCED | 4 | 8-12 |
| 11-15 | BALANCED | 4-5 | 12-15 |
| 16-25 | OPTIMAL | 5 | 15-20 |
| 26+ | OPTIMAL | 5-6 | 15-25 |

### 3.6 SURVEY_MAPPING (Required for ANALYSIS mode)

Maps your survey column names to the module's expectations. There are two approaches:

#### Approach 1: Pattern-Based Mapping (Recommended)

Define patterns for column names using `{task}` placeholder:

| Mapping_Type | Value | Description |
|--------------|-------|-------------|
| `Version_Variable` | `Version` | Column with design version number |
| `Best_Column_Pattern` | `MaxDiff_T{task}_Best` | Pattern for Best columns |
| `Worst_Column_Pattern` | `MaxDiff_T{task}_Worst` | Pattern for Worst columns |
| `Best_Value_Type` | `ITEM_POSITION` | `ITEM_POSITION` (1-5) or `ITEM_ID` |
| `Worst_Value_Type` | `ITEM_POSITION` | `ITEM_POSITION` (1-5) or `ITEM_ID` |

**Column Pattern Example:**
If your survey has: `MD_T1_Best`, `MD_T1_Worst`, `MD_T2_Best`, `MD_T2_Worst`, ...
- Set `Best_Column_Pattern = MD_T{task}_Best`
- Set `Worst_Column_Pattern = MD_T{task}_Worst`

#### Approach 2: Explicit Field Mapping

List each field individually:

| Field_Type | Field_Name | Task_Number | Notes |
|------------|------------|-------------|-------|
| `VERSION` | `MD_Version` | | Design version column |
| `BEST_CHOICE` | `Q1_Best` | 1 | Best choice for task 1 |
| `WORST_CHOICE` | `Q1_Worst` | 1 | Worst choice for task 1 |
| `BEST_CHOICE` | `Q2_Best` | 2 | Best choice for task 2 |
| `WORST_CHOICE` | `Q2_Worst` | 2 | Worst choice for task 2 |
| ... | ... | ... | Repeat for all tasks |

**Field Types:**
- `VERSION`: Which design version the respondent saw
- `BEST_CHOICE`: Column containing the best item choice
- `WORST_CHOICE`: Column containing the worst item choice
- `SHOWN_ITEMS`: (Optional) Comma-separated items shown, overrides design file

**Value Types:**
- `ITEM_POSITION`: Values are 1, 2, 3, 4, 5 (position in task as shown in design)
- `ITEM_ID`: Values are actual Item_IDs like `ITEM_01`, `ITEM_02`

### 3.7 SEGMENT_SETTINGS (Optional)

Define segments for subgroup analysis:

| Segment_ID | Segment_Name | Variable_Name | Variable_Value | Include | Display_Order |
|------------|--------------|---------------|----------------|---------|---------------|
| `GENDER` | `Male` | `Gender` | `1` | 1 | 1 |
| `GENDER` | `Female` | `Gender` | `2` | 1 | 2 |
| `AGE3` | `18-34` | `Age_Cat` | `1` | 1 | 1 |
| `AGE3` | `35-54` | `Age_Cat` | `2` | 1 | 2 |
| `AGE3` | `55+` | `Age_Cat` | `3` | 1 | 3 |

**Tips:**
- `Segment_ID` groups segments together (e.g., all age groups)
- `Segment_Name` is the display name for each level
- `Variable_Name` is the column in your data file
- `Variable_Value` is the value to match (can be numeric or text)
- Multiple segments with same `Segment_ID` create one segmentation

### 3.8 OUTPUT_SETTINGS (Optional)

Control output options (defaults shown):

| Option_Name | Default | Description |
|-------------|---------|-------------|
| `Generate_Count_Scores` | `YES` | Compute Best%, Worst%, Net Score |
| `Generate_Aggregate_Logit` | `YES` | Fit aggregate logit model |
| `Generate_HB_Model` | `YES` | Fit Hierarchical Bayes model |
| `Generate_Segment_Tables` | `YES` | Segment-level analysis |
| `Generate_Charts` | `YES` | Create PNG visualisations |
| `Score_Rescale_Method` | `0_100` | `RAW`, `0_100`, or `PROBABILITY` |
| `Export_Individual_Utils` | `YES` | Individual-level utilities |
| `HB_Iterations` | `5000` | MCMC iterations (after warmup) |
| `HB_Warmup` | `2000` | MCMC warmup iterations |
| `HB_Chains` | `4` | Number of MCMC chains |
| `Min_Respondents_Per_Segment` | `50` | Minimum n to report segment |

---

## 4. Design Mode

### 4.1 Running Design Mode

1. Set `Mode = DESIGN` in PROJECT_SETTINGS
2. Ensure ITEMS and DESIGN_SETTINGS sheets are complete
3. Run the module
4. Review the generated design file and quality metrics

### 4.2 Design Output

The module generates a design file with:

**DESIGN sheet:**

| Version | Task_Number | Item1_ID | Item2_ID | Item3_ID | Item4_ID |
|---------|-------------|----------|----------|----------|----------|
| 1 | 1 | ITEM_01 | ITEM_04 | ITEM_07 | ITEM_09 |
| 1 | 2 | ITEM_02 | ITEM_03 | ITEM_06 | ITEM_10 |
| ... | ... | ... | ... | ... | ... |

**DESIGN_SUMMARY sheet:**
- Item frequency table
- Pair frequency matrix
- Position balance statistics
- D-efficiency score

### 4.3 Design Quality Metrics

| Metric | Good Value | Description |
|--------|------------|-------------|
| D-efficiency | > 0.90 | Information efficiency (0-1) |
| Item balance CV | < 0.10 | Coefficient of variation of item frequencies |
| Pair balance CV | < 0.20 | CV of pair co-occurrence frequencies |

### 4.4 Using the Design in Your Survey

1. **Export design** to your survey platform
2. **Create version variable** to randomly assign respondents
3. **For each task**, program:
   - Display items based on design file
   - Randomize item order (recommended)
   - Collect best and worst choices
4. **Record** the item position or Item_ID for each choice
5. **Test thoroughly** before fielding

---

## 5. Analysis Mode

### 5.1 Running Analysis Mode

1. Set `Mode = ANALYSIS` in PROJECT_SETTINGS
2. Ensure you have:
   - Design file from DESIGN mode or your survey platform
   - Survey data exported as Excel
   - SURVEY_MAPPING sheet completed
3. Run the module
4. Review results in Excel workbook and charts

### 5.2 Scoring Methods

#### Count-Based Scores

Simple descriptive metrics:

| Score | Formula | Interpretation |
|-------|---------|----------------|
| Best% | Times chosen best / Times shown | Higher = more preferred |
| Worst% | Times chosen worst / Times shown | Higher = less preferred |
| Net Score | Best% - Worst% | Range: -100 to +100 |
| BW Score | (#Best - #Worst) / #Shown | Range: -1 to +1 |

#### Aggregate Logit

Conditional logit model estimates utilities on an interval scale. Uses survival::clogit() for computational efficiency.

**Features:**
- Interval-scale utilities
- Statistical significance tests
- Standard errors and confidence intervals
- Model fit statistics (R², log-likelihood)

#### Hierarchical Bayes

Estimates individual-level utilities using MCMC sampling. Requires cmdstanr package.

**Benefits:**
- Individual preference profiles
- Better estimates for small samples
- Accounts for respondent heterogeneity
- Enables advanced segmentation

**Requirements:**
- cmdstanr installed and configured
- Adequate sample size (200+ recommended)
- Computational time (10-30 minutes typical)

### 5.3 Score Rescaling

| Method | Formula | Range | Use Case |
|--------|---------|-------|----------|
| `RAW` | No change | Varies | Technical analysis |
| `0_100` | 100 × (u - min) / (max - min) | 0-100 | Reporting, charts |
| `PROBABILITY` | exp(u) / Σexp(u) | 0-1 | Probability interpretation |

---

## 6. Understanding the Output

### 6.1 Excel Results Workbook

`{Project_Name}_MaxDiff_Results.xlsx` contains:

#### SUMMARY Sheet
- Project metadata
- Sample sizes (total and per version)
- Model fit statistics
- Warnings and notes

#### ITEM_SCORES Sheet

| Column | Description |
|--------|-------------|
| Item_ID | Item identifier |
| Item_Label | Full item text |
| Times_Shown | How often item was displayed |
| Times_Best | How often chosen as best |
| Times_Worst | How often chosen as worst |
| Best_Pct | Percentage chosen as best |
| Worst_Pct | Percentage chosen as worst |
| Net_Score | Best% - Worst% |
| Logit_Utility | Aggregate logit utility |
| Logit_SE | Standard error |
| HB_Utility_Mean | Mean HB utility |
| HB_Utility_SD | SD across respondents |
| Rescaled_Score | Utility on chosen scale |
| Rank | Preference rank |

#### SEGMENT_SCORES Sheet
Same columns as ITEM_SCORES plus segment identifiers.

#### INDIVIDUAL_UTILS Sheet
Respondent-level utilities (if HB enabled):
- One row per respondent
- One column per item
- Can merge with other respondent data for advanced analysis

#### MODEL_DIAGNOSTICS Sheet
- Logit model fit statistics
- HB convergence diagnostics (Rhat, ESS)
- Design quality metrics
- Sample composition

### 6.2 Chart Outputs

All charts saved as PNG (300 DPI):

| File | Description |
|------|-------------|
| `*_utility_bar.png` | Horizontal bar chart of rescaled scores |
| `*_best_worst.png` | Diverging bar chart (Best% left, Worst% right) |
| `*_segment_*.png` | Segment comparison charts |
| `*_utility_distribution.png` | Violin plot of individual utilities (HB only) |

---

## 7. Working with Segments

### 7.1 Defining Segments

In SEGMENT_SETTINGS, define segments by specifying:
- Variable name in your data
- Values that define each segment level
- Display names for reporting

**Example:**

```
Segment: Gender
- Male (Gender = 1)
- Female (Gender = 2)

Segment: Age Groups
- 18-34 (Age_Cat = 1)
- 35-54 (Age_Cat = 2)
- 55+ (Age_Cat = 3)
```

### 7.2 Segment Output

For each segment, the module computes:
- Full scoring metrics per segment level
- Statistical comparison tests
- Segment comparison charts
- Sample sizes per level

### 7.3 Minimum Sample Size

Set `Min_Respondents_Per_Segment` in OUTPUT_SETTINGS to suppress reporting for segments with insufficient sample size (default: 50).

### 7.4 Interpreting Segment Differences

- Compare rescaled utilities across segments
- Look for items that rank differently
- Check statistical significance (if using logit)
- Consider practical significance (not just statistical)
- Always report sample sizes alongside results

---

## 8. Configuration Template Reference

### 8.1 Template Sheets Overview

The configuration template (`maxdiff_config_template.xlsx`) includes:

1. **INSTRUCTIONS** - Overview and workflow guidance
2. **PROJECT_SETTINGS** - Core configuration
3. **ITEMS** - Item definitions with examples
4. **DESIGN_SETTINGS** - Design parameters with recommendations
5. **SURVEY_MAPPING** - Mapping instructions and examples
6. **SEGMENT_SETTINGS** - Segmentation setup
7. **OUTPUT_SETTINGS** - Output options

### 8.2 Quick Start with Template

1. **Generate or copy template**
   ```r
   source("modules/maxdiff/templates/create_maxdiff_template.R")
   ```

2. **Open INSTRUCTIONS sheet** - Read workflow overview

3. **Fill PROJECT_SETTINGS** (yellow cells are required):
   - Set unique Project_Name
   - Choose Mode (DESIGN or ANALYSIS)
   - Add file paths if ANALYSIS mode

4. **Define ITEMS**:
   - Replace example items with your items
   - Use descriptive Item_IDs
   - Write Item_Labels as they'll appear to respondents

5. **Configure mode-specific sheet**:
   - DESIGN mode: Fill DESIGN_SETTINGS
   - ANALYSIS mode: Fill SURVEY_MAPPING

6. **Optional: Add segments** in SEGMENT_SETTINGS

7. **Optional: Adjust output** in OUTPUT_SETTINGS

8. **Save and run**

### 8.3 Common Template Customizations

**For short studies (6-10 items):**
- Items_Per_Task: 4
- Tasks_Per_Respondent: 8-10
- Num_Versions: 1
- Design_Type: BALANCED

**For large item sets (20-30 items):**
- Items_Per_Task: 5-6
- Tasks_Per_Respondent: 15-20
- Num_Versions: 3-5
- Design_Type: OPTIMAL

**For quick analysis (skip HB):**
- Generate_HB_Model: NO
- Keeps analysis under 5 minutes

**For detailed individual analysis:**
- Generate_HB_Model: YES
- Export_Individual_Utils: YES
- HB_Iterations: 5000+

---

## 9. Troubleshooting

### 9.1 Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Config file not found" | Invalid path | Check file path, use absolute path |
| "Required sheet missing" | Missing Excel sheet | Add required sheet to config |
| "Raw_Data_File not found" | Invalid data path | Use absolute path to data file |
| "Invalid Item_ID" | Unrecognised item in data | Check Item_IDs match between config and data |
| "HB model failed" | cmdstanr not installed | Install cmdstanr or set Generate_HB_Model = NO |
| "VERSION column not found" | Mapping error | Check Version_Variable in SURVEY_MAPPING |
| "Design file format error" | Wrong design format | Ensure design has DESIGN sheet with correct columns |

### 9.2 Data Issues

| Warning | Cause | Solution |
|---------|-------|----------|
| "Respondent chose same item for best and worst" | Data error | Check survey logic, filter if needed |
| "Item not shown in task" | Choice doesn't match design | Verify survey programming |
| "Missing values in choice columns" | Incomplete responses | Filter or impute |
| "Very low D-efficiency" | Poor design | Regenerate with OPTIMAL type or more tasks |
| "HB convergence warning" | Rhat > 1.05 | Increase iterations or check data quality |

### 9.3 Installation Issues

**R packages not installing:**
```r
# Install manually
install.packages(c("openxlsx", "survival", "ggplot2"))
```

**cmdstanr installation:**
```r
# Follow official guide
install.packages("cmdstanr", repos = c("https://mc-stan.org/r-packages/", getOption("repos")))
library(cmdstanr)
install_cmdstan()
```

**Path issues on Windows:**
- Use forward slashes `/` or double backslashes `\\`
- Avoid spaces in paths if possible
- Use absolute paths for files outside Turas folder

### 9.4 Getting Help

1. Check the log file: `{Output_Folder}/{Project_Name}_log.txt`
2. Review error messages carefully - they include remediation guidance
3. Consult the [Technical Reference](TECHNICAL_REFERENCE.md) for advanced issues
4. Check [Example Workflows](EXAMPLE_WORKFLOWS.md) for working examples
5. Contact Turas development team with:
   - Error message
   - Configuration file
   - Log file
   - R version and package versions

---

## 10. Best Practices

### 10.1 Study Design

**Item Selection:**
- 8-15 items is ideal for most studies
- All items must be conceptually comparable
- Avoid items that are universally desired/rejected
- Pre-test items qualitatively when possible
- Use clear, concise language

**Task Design:**
- 4 items per task is standard
- 5 items works for experienced/engaged respondents
- 10-15 tasks per respondent balances burden and precision
- More items require more tasks
- Test survey length in pilot

**Design Strategy:**
- Use BALANCED for most studies (8-20 items)
- Use OPTIMAL for large item sets (20+)
- Create multiple versions for large samples (1000+)
- Always set a seed for reproducibility

### 10.2 Configuration

**File Management:**
- Keep config file with project files
- Use version control for config files
- Use descriptive Project_Name
- Document any filter expressions
- Save original unedited template

**Item IDs:**
- Use meaningful IDs (e.g., `PRICE_LOW` not `I1`)
- Keep IDs consistent between design and analysis
- Avoid special characters
- Use uppercase for consistency

**Testing:**
- Test with small sample before full analysis
- Validate design quality metrics
- Check one segment before running all
- Review count scores before complex models

### 10.3 Data Collection

**Survey Programming:**
- Test thoroughly across devices
- Randomize task order
- Randomize item positions within tasks
- Include attention checks
- Prevent same item for best/worst
- Make questions required

**Quality Checks:**
- Monitor speeders (completion time)
- Flag straight-liners (if detectable)
- Check response patterns
- Validate version distribution
- Monitor completion rates

### 10.4 Analysis

**Methodological:**
- Review count scores first (sanity check)
- Compare logit and HB results (should be similar)
- Check model fit statistics
- Review convergence diagnostics for HB
- Test sensitivity to filtering

**Segmentation:**
- Check segment sizes before interpreting
- Require minimum n per segment (50+ recommended)
- Test for statistical significance
- Consider practical vs. statistical significance
- Don't over-segment (risk of spurious findings)

**Reporting:**
- Use 0-100 rescaled scores for clients
- Include confidence intervals
- Show both utility bars and best-worst charts
- Note sample sizes on segment comparisons
- Include methodology appendix

### 10.5 Reproducibility

**Always document:**
- Config file settings
- R version and package versions
- Seed used
- Any filters or data cleaning
- Segment definitions
- Output settings

**Archive:**
- Config file
- Raw data
- Design file
- Output files
- Log file
- Scripts for any post-processing

---

## 11. Glossary

| Term | Definition |
|------|------------|
| **Anchor Item** | Reference item with utility fixed at 0 in HB model for identification |
| **Best-Worst Scaling** | Alternative name for MaxDiff |
| **BIBD** | Balanced Incomplete Block Design - not all items shown to each respondent |
| **BW Score** | (Times Best - Times Worst) / Times Shown |
| **Conditional Logit** | Statistical model for discrete choice data with fixed alternatives |
| **D-efficiency** | Measure of design quality (0-1, higher = better) |
| **Design File** | Excel file containing task assignments (which items shown in each task) |
| **Hierarchical Bayes (HB)** | Bayesian method for individual-level estimation |
| **Item** | An attribute, feature, or option being evaluated |
| **Item_ID** | Unique identifier for an item (must be consistent across design/analysis) |
| **Logit Utility** | Preference score from conditional logit model (interval scale) |
| **MaxDiff** | Maximum Difference Scaling |
| **MCMC** | Markov Chain Monte Carlo (HB sampling method) |
| **Net Score** | Best% minus Worst% |
| **Rhat** | Convergence diagnostic for HB (should be < 1.05) |
| **Rescaling** | Converting utilities to 0-100 or probability scale for interpretation |
| **Task** | One choice scenario showing k items |
| **Utility** | Latent preference score for an item |
| **Version** | One of multiple design variants (for blocking/rotation) |

---

## Appendix A: Quick Reference Card

### Workflow Checklist

**DESIGN Mode:**
- [ ] Define items in ITEMS sheet
- [ ] Set Mode = DESIGN
- [ ] Configure DESIGN_SETTINGS
- [ ] Run module
- [ ] Review design quality metrics
- [ ] Use design file to program survey

**ANALYSIS Mode:**
- [ ] Have design file and data file
- [ ] Define same items as design
- [ ] Set Mode = ANALYSIS
- [ ] Set file paths in PROJECT_SETTINGS
- [ ] Configure SURVEY_MAPPING
- [ ] Add SEGMENT_SETTINGS (optional)
- [ ] Run module
- [ ] Review output Excel and charts

### Minimum Sample Sizes

| Purpose | Minimum N |
|---------|-----------|
| Overall estimates | 200 |
| Per segment | 50 |
| HB model | 100 |
| Stable HB estimates | 200+ |

### Recommended Study Parameters

| Items | Items/Task | Tasks | Versions |
|-------|------------|-------|----------|
| 6-10 | 4 | 8-12 | 1 |
| 11-15 | 4-5 | 12-15 | 1-3 |
| 16-25 | 5 | 15-20 | 3-5 |
| 26-40 | 5-6 | 20-25 | 5+ |

### File Paths by Operating System

**Windows:**
```
C:\Users\duncan\OneDrive\Data\survey.xlsx
C:/Users/duncan/OneDrive/Data/survey.xlsx  (also works)
```

**Mac:**
```
/Users/duncan/OneDrive/Data/survey.xlsx
```

**Linux:**
```
/home/duncan/OneDrive/Data/survey.xlsx
```

---

## Appendix B: Example Configuration

A complete example configuration is available in:
```
modules/maxdiff/examples/basic/
```

Run the example file generator:
```r
source("modules/maxdiff/examples/basic/create_example_files.R")
create_example_files("path/to/output/folder")
```

This creates:
- `example_maxdiff_config.xlsx` - Complete configuration
- `example_design.xlsx` - Design file
- `example_survey_data.xlsx` - Simulated survey responses

---

*For additional help, see the [Example Workflows](EXAMPLE_WORKFLOWS.md) for step-by-step walkthroughs of complete studies.*
