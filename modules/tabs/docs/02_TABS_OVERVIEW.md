---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tabs - Overview

**Version:** 10.0 **Date:** 22 December 2025

## What is Turas Tabs?

Turas Tabs is a cross-tabulation engine designed for market research
professionals. It takes survey data and produces the kind of
professionally formatted tables that clients expect to see, complete
with weighted statistics and significance testing.

If you've ever spent hours manually building crosstabs in Excel or
wrestling with SPSS syntax, Tabs is designed to automate that entire
process while giving you more control over the output.

## Who Is This For?

Tabs is built for research analysts who need to:

-   Generate cross-tabulation reports from survey data
-   Compare responses across demographic segments
-   Apply weights and calculate effective sample sizes
-   Test whether differences between groups are statistically
    significant
-   Deliver polished Excel workbooks to clients

You don't need to be a programmer to use Tabs. If you can fill in an
Excel template and run a few lines of R code, you can use this module.

## What Can It Do?

### Process Multiple Question Types

Tabs handles the full range of survey question formats:

**Standard Questions** - Single-choice questions (Gender, Age Group,
Yes/No) - Multiple-choice questions (select all that apply)

**Rating Questions** - Satisfaction scales (1-5, 1-7, 1-10) - Likert
agreement scales - Net Promoter Score (0-10 with automatic
Promoter/Passive/Detractor calculation)

**Advanced Questions** - Ranking questions (rank your top 3
preferences) - Open-ended numeric questions (What is your age?) -
Composite metrics (averages of multiple questions)

### Apply Proper Weighting

Real survey data is almost always weighted. Tabs handles this properly:

-   Applies your weight variable to all calculations
-   Calculates the design effect (DEFF) automatically
-   Uses effective sample sizes for significance testing
-   Reports both unweighted and weighted base sizes
-   Warns you when extreme weights might be causing problems

### Test Statistical Significance

Tabs includes proper significance testing so you can tell clients which
differences are real:

-   Chi-square tests for categorical comparisons
-   Z-tests for proportion differences
-   T-tests for mean differences
-   Adjustable confidence levels (90%, 95%, 99%)
-   Minimum base size thresholds

Significant differences appear as letter codes in the output (e.g., "45%
A" means this value is significantly higher than column A).

### Produce Professional Output

The Excel output is formatted and ready for delivery:

-   One sheet per question
-   Clear banner headers showing demographic segments
-   Frequency counts and percentages
-   Significance letters integrated into cells
-   Index summary sheet collecting all mean scores
-   Sample composition tables

## How Does It Work?

The workflow is straightforward:

1.  **Prepare your templates.** Fill in the Survey_Structure template
    with your questions and response options. Fill in the Tabs_Config
    template with your analysis settings.

2.  **Point to your data.** Specify your survey data file (Excel, CSV,
    or SPSS format).

3.  **Run the analysis.** Execute either through the GUI or with a
    simple R command.

4.  **Get your output.** Open the Excel workbook and review your
    crosstabs.

The typical analysis runs in under a minute for most surveys. Larger
datasets with hundreds of questions might take a few minutes.

## What Makes Tabs Different?

**Configuration-driven.** Everything is controlled through Excel
templates rather than code. You can set up new projects by copying and
modifying templates, and non-programmers can adjust settings without
touching R.

**Survey Structure as master reference.** You define your questions and
options once in Survey_Structure.xlsx, and this file drives all
analysis. Change a question label there, and it updates everywhere.

**Proper statistical handling.** Tabs uses effective base sizes for
significance testing (not just weighted counts), which gives you correct
p-values when working with weighted data.

**Composite metrics.** You can define calculated scores that combine
multiple questions (like an overall satisfaction index), and these get
processed alongside regular questions with their own significance
testing.

## When Should You Use Something Else?

Tabs is designed for cross-tabulation analysis. For other needs,
consider:

-   **Multi-wave tracking:** Use the Tracker module if you need to
    compare results across survey waves over time
-   **Statistical modeling:** Use standard R packages like lm() or glm()
    for regression analysis
-   **Text analysis:** Tabs doesn't process open-ended verbatim
    responses

## Getting Started

The fastest path to your first analysis:

1.  Read the [User Manual](04_USER_MANUAL.md) for step-by-step setup
    instructions
2.  Look at [Example Workflows](07_EXAMPLE_WORKFLOWS.md) to see common
    use cases
3.  Consult the [Template Reference](06_TEMPLATE_REFERENCE.md) when
    configuring your templates

For a deeper understanding of how Tabs processes data, see the
[Reference Guide](03_REFERENCE_GUIDE.md).

## Technical Requirements

Tabs runs on any system that can run R:

-   R version 4.0 or higher recommended
-   Required packages: openxlsx, readxl
-   Optional packages: haven (for SPSS files), data.table (for faster
    CSV processing)

Typical resource usage:

| Dataset Size       | Questions     | Processing Time |
|--------------------|---------------|-----------------|
| 500 respondents    | 20 questions  | 2-3 seconds     |
| 2,000 respondents  | 50 questions  | 10-15 seconds   |
| 10,000 respondents | 100 questions | 45-60 seconds   |
